--[[
	RaceClient  (StarterPlayerScripts.SpinClient.RaceClient)

	RACING EXTRAS: hold Shift (L3 / GALLOP button) to gallop; a STAMINA meter
	(WINDED! when it runs dry); a PROGRESS STRIP across the top with every
	rider on it (you in gold); "JUMP!" when a log hurdle is ahead; H (D-pad
	up / BACK button) to go back to your last gate; split times at each
	gate; NEW RECORD! and your best time and wins at the finish; a results
	board at the end; dust behind galloping horses; carrot crates bob.

	The Steel Ball Run on the client (RaceService runs it):
	  * Look: the bounty board's style (UI.UITheme) - dark wood boards with
	    planks, nails and steel corner brackets, pinned parchment, Bangers
	    titles, chunky buttons that bounce on hover/press.
	  * ENTRY: a wooden board at the top with a pinned parchment notice,
	    "THE STEEL BALL RUN · ENTRY OPEN 0:38", a JOIN button (LEAVE once
	    you're in) and how many riders have entered. A minute before entry
	    opens, a small nailed plank counts down to it
	  * COUNTDOWN: a big outlined gold 3, 2, 1, GO!
	  * RACING (riders): a framed race card top-right (a parchment sheet with
	    your position, gate x / N, the time, the top five) with a LEAVE
	    button; a tall golden beacon (with a wooden distance plaque)
	    on your next gate with its number and distance, and a gold arrow
	    ahead of your horse pointing at it
	  * the winner and the results for everyone
	  * horse names float over them on little wooden plaques
	  * every horse gallops: legs in a four-beat stride that speeds up with
	    the horse, the neck nods, the tail streams out, the body bobs; riders
	    (and NPC jockeys) sit astride, legs round its sides, hands on the reins
	  * M (controller D-pad left, or the HORSE button on mobile): call your
	    own horse and ride it anywhere; press again to get off
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage:WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)
local CameraFX = require(script.Parent.CameraFX)
local UITheme = require(script.Parent.UI.UITheme)
local TuskAnimation = require(script.Parent.TuskAnimation)

local RaceClient = {}
local player = Players.LocalPlayer
local cfg = TuskConfig.Race or {}
local Remote

local C = UITheme.C
local PAPER = C.PAPER
local INK = C.INK
local RED = C.RED
local GREEN = C.GREEN
local GOLD = C.GOLD

local gui, entryPanel, entryTitle, entryInfo, entryButton, soonChip, countdownLabel, card, cardRows, banner
local staminaPanel, staminaFill, staminaText, raceStrip, stripTrack, stripDots, jumpLabel, resultsBoard
local controlsBound = false
local entered = false
local nextGate = 1
local totalGates = 0
local standings = {}
local elapsedAt, elapsedBase = 0, 0
local beacon, arrow

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function corner(p, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p)
end

local function label(parent, props)
	return UITheme.label(parent, props)
end

-- A chunky dark outline round text (a UIStroke on the glyphs, thicker and
-- cleaner than TextStroke), plus a light-to-shade gradient for depth.
local function inkOutline(l, thickness, color)
	l.TextStrokeTransparency = 1
	new("UIStroke", { Color = color or C.WOOD_EDGE, Thickness = thickness or 2, LineJoinMode = Enum.LineJoinMode.Round }, l)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 205, 190)), Rotation = 90 }, l)
end

-- A red map pin with a shine (as on the bounty posters).
local function pin(parent, position)
	local p = new("Frame", { BackgroundColor3 = C.RED, Size = UDim2.fromOffset(12, 12), Position = position, ZIndex = (parent.ZIndex or 1) + 2 }, parent)
	corner(p, 99)
	new("Frame", { BackgroundColor3 = C.WHITE, BackgroundTransparency = 0.4, Size = UDim2.fromOffset(4, 4), Position = UDim2.fromOffset(3, 3), ZIndex = p.ZIndex }, p)
	return p
end

-- A small nailed wooden plaque filling a BillboardGui, with Bangers text.
local function plaque(bb, color)
	local f = new("Frame", { Name = "Plaque", Size = UDim2.fromScale(1, 1) }, bb)
	UITheme.wood(f, { Planks = 1, Border = 2, Radius = 5 })
	local text = label(f, { Name = "Text", Position = UDim2.new(0, 10, 0, 2), Size = UDim2.new(1, -20, 1, -4), Text = "", Font = UITheme.Font.Title, TextColor3 = color or C.GOLD, TextStrokeTransparency = 0.5, TextStrokeColor3 = C.WOOD_EDGE, ZIndex = 3 })
	return text
end

local function mmss(seconds)
	seconds = math.max(0, seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

local function ordinal(n)
	local suffix = "TH"
	if n % 100 < 11 or n % 100 > 13 then
		suffix = ({ "ST", "ND", "RD" })[n % 10] or "TH"
	end
	return n .. suffix
end

local function showBanner(text, color, time)
	banner.Text = text
	banner.TextColor3 = color or GOLD
	banner.Visible = true
	local scale = banner:FindFirstChildOfClass("UIScale")
	scale.Scale = 0.5
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local token = {}
	banner:SetAttribute("Token", tostring(token))
	task.delay(time or 3, function()
		if banner:GetAttribute("Token") == tostring(token) then
			banner.Visible = false
		end
	end)
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local function buildUI()
	gui = new("ScreenGui", { Name = "SteelBallRun", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 7, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
	-- Entry banner: a wooden board with a parchment notice and a JOIN button.
	entryPanel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(420, 92), Visible = false }, gui)
	UITheme.wood(entryPanel, { Planks = 2, Border = 5, Brackets = true, BracketSize = 14 })
	new("UISizeConstraint", { MaxSize = Vector2.new(420, 92) }, entryPanel)
	local notice = new("Frame", { Name = "Notice", Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -158, 1, -20), ZIndex = 3 }, entryPanel)
	UITheme.paper(notice, { Radius = 3 })
	pin(notice, UDim2.new(0, 6, 0, -4))
	local strip = new("Frame", { Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = C.RED, BorderSizePixel = 0, ZIndex = 4 }, notice)
	corner(strip, 3)
	entryTitle = label(notice, { Position = UDim2.fromOffset(12, 2), Size = UDim2.new(1, -16, 0, 28), Text = "THE STEEL BALL RUN", Font = UITheme.Font.Title, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 })
	entryInfo = label(notice, { Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -16, 0, 16), Text = "", Font = UITheme.Font.Body, TextColor3 = C.RED, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 })
	label(notice, { Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -16, 0, 22), Text = "Race round the map on horseback. Top 3 win Cash; the winner gets a Saint's Corpse part.", Font = UITheme.Font.Plain, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.INK:Lerp(C.PAPER, 0.25), ZIndex = 4 })
	entryButton = UITheme.button(entryPanel, "JOIN", C.GREEN, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(112, 54), ZIndex = 4 })
	entryButton.Activated:Connect(function()
		Remote:FireServer(entered and "Leave" or "Join")
	end)
	-- "STEEL BALL RUN IN 0:45": a small nailed plank.
	soonChip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(230, 28), Visible = false }, gui)
	UITheme.wood(soonChip, { Planks = 1, Border = 3, Radius = 6 })
	label(soonChip, { Name = "Text", Position = UDim2.fromOffset(12, 3), Size = UDim2.new(1, -24, 1, -6), Text = "", TextColor3 = C.GOLD, Font = UITheme.Font.Title, ZIndex = 3 })
	-- Countdown: huge gold Bangers with a chunky dark outline.
	countdownLabel = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.35), Size = UDim2.fromOffset(400, 150), Text = "", Font = UITheme.Font.Title, TextColor3 = C.GOLD, Visible = false })
	inkOutline(countdownLabel, 5)
	new("UIScale", { Scale = 1 }, countdownLabel)
	-- Race card (top right): a framed board with a parchment standings sheet.
	card = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 64), Size = UDim2.fromOffset(230, 200), Visible = false }, gui)
	UITheme.wood(card, { Planks = 4, Border = 5, Brackets = true, BracketSize = 14 })
	label(card, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -84, 0, 22), Text = "STEEL BALL RUN", Font = UITheme.Font.Title, TextColor3 = C.GOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	local sheet = new("Frame", { Name = "Sheet", Position = UDim2.fromOffset(9, 32), Size = UDim2.new(1, -18, 1, -46), ZIndex = 2 }, card)
	UITheme.paper(sheet, { Radius = 3 })
	label(card, { Name = "Pos", Position = UDim2.fromOffset(16, 34), Size = UDim2.fromOffset(90, 38), Text = "-", Font = UITheme.Font.Title, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	label(card, { Name = "Gate", Position = UDim2.fromOffset(104, 37), Size = UDim2.fromOffset(110, 17), Text = "", Font = UITheme.Font.Body, TextColor3 = C.RED, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3 })
	label(card, { Name = "Time", Position = UDim2.fromOffset(104, 55), Size = UDim2.fromOffset(110, 15), Text = "", Font = UITheme.Font.Body, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.INK:Lerp(C.PAPER, 0.3), ZIndex = 3 })
	new("Frame", { Position = UDim2.fromOffset(16, 74), Size = UDim2.new(1, -32, 0, 2), BackgroundColor3 = C.BURNT, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 3 }, card)
	cardRows = new("Frame", { Position = UDim2.fromOffset(14, 77), Size = UDim2.new(1, -28, 0, 95), BackgroundTransparency = 1, ZIndex = 3 }, card)
	local leave = UITheme.button(card, "LEAVE", C.RED, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 7), Size = UDim2.fromOffset(54, 22), ZIndex = 4 })
	leave.Activated:Connect(function()
		Remote:FireServer("Leave")
	end)
	label(card, { Name = "Hint", Position = UDim2.new(0, 14, 1, -28), Size = UDim2.new(1, -28, 0, 13), Text = "Ride through the gates in order", Font = UITheme.Font.Plain, TextColor3 = C.INK:Lerp(C.PAPER, 0.35), ZIndex = 3 })
	-- Big banner: Bangers with a chunky dark outline (like the bounty banner).
	banner = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.24), Size = UDim2.fromOffset(640, 70), Text = "", Font = UITheme.Font.Title, TextColor3 = C.GOLD, Visible = false })
	inkOutline(banner, 3)
	new("UIScale", { Scale = 1 }, banner)
	-- Stamina: a nailed plank with a wood-framed meter (bottom middle).
	staminaPanel = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(260, 46), Visible = false }, gui)
	UITheme.wood(staminaPanel, { Planks = 1, Border = 3, Radius = 6 })
	staminaText = label(staminaPanel, { Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -20, 0, 16), Text = "STAMINA  ·  SHIFT: GALLOP", Font = UITheme.Font.Title, TextColor3 = C.GOLD, ZIndex = 3 })
	local _, fill = UITheme.bar(staminaPanel, GREEN, { Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 16), ZIndex = 3 })
	staminaFill = fill
	-- Progress strip: a plank across the top with a track, gate ticks, a finish
	-- flag and every rider as a dot (you in gold).
	raceStrip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(460, 34), Visible = false }, gui)
	UITheme.wood(raceStrip, { Planks = 1, Border = 3, Radius = 6 })
	stripTrack = new("Frame", { Position = UDim2.fromOffset(20, 15), Size = UDim2.new(1, -52, 0, 4), BackgroundColor3 = C.PAPER_DARK, BorderSizePixel = 0, ZIndex = 3 }, raceStrip)
	corner(stripTrack, 2)
	label(raceStrip, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(24, 22), Text = "🏁", Font = UITheme.Font.Heavy, TextColor3 = C.WHITE, ZIndex = 3 })
	stripDots = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, stripTrack)
	-- "JUMP!" over the middle of the screen when a hurdle's coming.
	jumpLabel = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(260, 60), Text = "JUMP!", Font = UITheme.Font.Title, TextColor3 = C.GOLD, Visible = false })
	inkOutline(jumpLabel, 3)
end

-- The results board at the end: a wooden board with a parchment list.
local function showResults(list, reason)
	if resultsBoard then
		resultsBoard:Destroy()
	end
	local rows = math.min(#list, 8)
	resultsBoard = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(340, 96 + math.max(rows, 1) * 24) }, gui)
	UITheme.wood(resultsBoard, { Planks = 4, Border = 6, Brackets = true, BracketSize = 16 })
	UITheme.sign(resultsBoard, "STEEL BALL RUN", "RESULTS", { Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(240, 46), ZIndex = 3 })
	local sheet = new("Frame", { Position = UDim2.fromOffset(14, 60), Size = UDim2.new(1, -28, 1, -74), ZIndex = 3 }, resultsBoard)
	UITheme.paper(sheet, { Radius = 3 })
	if rows == 0 then
		label(sheet, { Size = UDim2.fromScale(1, 1), Text = string.upper(reason or "NOBODY FINISHED"), Font = UITheme.Font.Title, ZIndex = 4 })
	end
	for i = 1, rows do
		local r = list[i]
		local color = i == 1 and C.GOLD or (i == 2 and Color3.fromRGB(200, 200, 210) or (i == 3 and Color3.fromRGB(205, 130, 70) or nil))
		local y = 4 + (i - 1) * 24
		if color then
			local medal = new("Frame", { Position = UDim2.fromOffset(6, y + 3), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = color, ZIndex = 4 }, sheet)
			corner(medal, 99)
			UITheme.stroke(medal, C.WOOD_EDGE, 1.5)
		end
		label(sheet, { Position = UDim2.fromOffset(30, y), Size = UDim2.new(0.68, -30, 0, 22), Text = ordinal(r.Place or i) .. "  " .. string.upper(r.Name or "?"), Font = i <= 3 and UITheme.Font.Title or UITheme.Font.Body, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = i == 1 and C.RED or INK, ZIndex = 4 })
		label(sheet, { Position = UDim2.new(0.68, 0, 0, y), Size = UDim2.new(0.32, -8, 0, 22), Text = mmss(r.Time or 0) .. string.format(".%d", math.floor(((r.Time or 0) % 1) * 10)), Font = UITheme.Font.Body, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
	end
	UITheme.pop(resultsBoard, 0.5)
	local board = resultsBoard
	task.delay(9, function()
		if board.Parent then
			board:Destroy()
		end
	end)
end

-- The progress strip: every rider as a dot along the track.
local function fillStrip()
	for _, c in ipairs(stripDots:GetChildren()) do
		c:Destroy()
	end
	for i = 1, math.max(totalGates - 1, 0) do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(i / totalGates, 0.5), Size = UDim2.fromOffset(2, 10), BackgroundColor3 = C.WOOD_EDGE, BorderSizePixel = 0, ZIndex = 4 }, stripDots)
	end
	for _, row in ipairs(standings) do
		local me = row.UserId == player.UserId
		local size = me and 16 or 11
		local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(math.clamp(row.Progress or 0, 0, 1), 0.5), Size = UDim2.fromOffset(size, size), BackgroundColor3 = me and C.GOLD or (row.Jockey and Color3.fromRGB(170, 170, 180) or C.RED), ZIndex = me and 6 or 5 }, stripDots)
		corner(dot, 99)
		UITheme.stroke(dot, C.WOOD_EDGE, me and 2 or 1.5)
		if me then
			label(dot, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -1), Size = UDim2.fromOffset(40, 12), Text = "YOU", Font = UITheme.Font.Title, TextColor3 = C.GOLD, TextStrokeTransparency = 0.3, ZIndex = 6 })
		end
	end
end

local function setEntered(on)
	entered = on
	entryButton.Text = on and "LEAVE" or "JOIN"
	local color = on and RED or GREEN
	entryButton.BackgroundColor3 = color
	local edge = entryButton:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = color:Lerp(Color3.new(0, 0, 0), 0.45)
	end
	UITheme.pop(entryButton, 0.8)
end

local function fillStandings()
	for _, c in ipairs(cardRows:GetChildren()) do
		c:Destroy()
	end
	local mine
	for i, row in ipairs(standings) do
		if row.UserId == player.UserId then
			mine = row
		end
		if i <= 5 then
			local me = row.UserId == player.UserId
			local line = new("Frame", { Position = UDim2.fromOffset(0, (i - 1) * 19), Size = UDim2.new(1, 0, 0, 17), BackgroundColor3 = me and GOLD or PAPER, BackgroundTransparency = me and 0.15 or 1, ZIndex = 3 }, cardRows)
			corner(line, 4)
			if me then
				UITheme.stroke(line, C.BURNT, 1.5, 0.2)
			end
			label(line, { Position = UDim2.fromOffset(4, 1), Size = UDim2.new(0.7, -4, 1, -2), Text = i .. ". " .. string.upper(row.Name or "?"), Font = i <= 3 and UITheme.Font.Heavy or UITheme.Font.Body, TextColor3 = i == 1 and C.RED or INK, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
			label(line, { Position = UDim2.new(0.7, 0, 0, 1), Size = UDim2.new(0.3, -4, 1, -2), Text = row.Finished and "DONE" or ("GATE " .. math.min(row.Next or 1, totalGates)), Font = UITheme.Font.Body, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = row.Finished and GREEN or INK, ZIndex = 4 })
		end
	end
	if mine then
		card:FindFirstChild("Pos").Text = ordinal(mine.Position) .. " / " .. #standings
	end
end

---------------------------------------------------------------------------
-- The next gate: a beacon on it and an arrow ahead of your horse
---------------------------------------------------------------------------
local function gatePosition(index)
	local course = workspace:FindFirstChild("SteelBallRunCourse")
	if not course then
		return nil
	end
	for _, gate in ipairs(course:GetChildren()) do
		local isFinish = gate.Name == "Gate_FINISH"
		if (isFinish and index == totalGates) or (not isFinish and gate:GetAttribute("GateIndex") == index) then
			local line = gate:FindFirstChild("Line")
			return line and line.Position
		end
	end
	return nil
end

local function clearGuide()
	if beacon then
		beacon.Model:Destroy()
		beacon = nil
	end
	if arrow then
		arrow.Model:Destroy()
		arrow = nil
	end
end

local function stepGuide()
	local racing = entered and ReplicatedStorage:GetAttribute("SpinRacePhase") == "Racing" and nextGate <= totalGates
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local at = racing and gatePosition(nextGate)
	if not at or not root then
		clearGuide()
		return
	end
	if not beacon then
		local m = Instance.new("Model")
		m.Name = "RaceBeacon"
		m.Parent = VFXLib.Folder
		local pillar = VFXLib.part({ Size = Vector3.new(80, 3, 3), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.5, Shape = Enum.PartType.Cylinder })
		pillar.Parent = m
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(160, 36)
		bb.StudsOffset = Vector3.new(0, 20, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Adornee = pillar
		local text = plaque(bb, GOLD)
		bb.Parent = m
		beacon = { Model = m, Pillar = pillar, Text = text }
	end
	if not arrow then
		local m = Instance.new("Model")
		m.Name = "RaceArrow"
		m.Parent = VFXLib.Folder
		local shaft = VFXLib.part({ Size = Vector3.new(0.35, 0.35, 2.6), Color = GOLD, Material = Enum.Material.Neon })
		shaft.Parent = m
		local head = VFXLib.part({ Size = Vector3.new(1.3, 0.35, 1.1), Color = Color3.fromRGB(255, 240, 170), Material = Enum.Material.Neon })
		head.Parent = m
		arrow = { Model = m, Shaft = shaft, Head = head }
	end
	beacon.Pillar.CFrame = CFrame.new(at + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beacon.Pillar.Transparency = 0.45 + 0.15 * math.sin(os.clock() * 4)
	local dist = (Vector3.new(at.X, 0, at.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
	beacon.Text.Text = (nextGate == totalGates and "FINISH" or ("GATE " .. nextGate)) .. "  " .. math.floor(dist) .. "m"
	local flat = Vector3.new(at.X - root.Position.X, 0, at.Z - root.Position.Z)
	flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
	local pos = root.Position + flat * 5 + Vector3.new(0, 3 + math.sin(os.clock() * 3) * 0.2, 0)
	local cf = CFrame.lookAt(pos, pos + flat)
	arrow.Shaft.CFrame = cf
	arrow.Head.CFrame = cf * CFrame.new(0, 0, -1.5) * CFrame.Angles(0, math.pi / 4, 0)
end

---------------------------------------------------------------------------
-- Horses gallop, riders sit astride
---------------------------------------------------------------------------
local LEG_PHASE = { LegFL = 0, LegFR = 0.25, LegBL = 0.5, LegBR = 0.75 }
local horses = setmetatable({}, { __mode = "k" }) -- [horse] = { Phase, Joints, Weld, Base }
local riders = setmetatable({}, { __mode = "k" }) -- [character] = previous hold

local function horseState(horse)
	local h = horses[horse]
	if h then
		return h
	end
	h = { Phase = math.random(), Joints = {} }
	for _, p in ipairs(horse:GetChildren()) do
		local joint = p:IsA("BasePart") and p:GetAttribute("Joint")
		local w = joint and p:FindFirstChildOfClass("Weld")
		if w then
			table.insert(h.Joints, { Part = p, Weld = w, Joint = joint, Drop = p:GetAttribute("Drop") or 0, Rest = p:GetAttribute("Rest") or 0 })
		end
	end
	local body = horse.PrimaryPart or horse:FindFirstChild("Body")
	h.Weld = body and body:FindFirstChild("HorseWeld")
	horses[horse] = h
	return h
end

local function clearPlates()
	for horse, h in pairs(horses) do
		if h.Plate and not horse.Parent then
			h.Plate:Destroy()
			h.Plate = nil
			horses[horse] = nil
		end
	end
end

local function stepHorses(dt)
	clearPlates()
	for _, horse in ipairs(CollectionService:GetTagged("SpinHorse")) do
		local character = horse.Parent
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and horse.Parent then
			local h = horseState(horse)
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local amp = math.clamp(speed / 40, 0, 1)
			h.Phase = (h.Phase + dt * (0.6 + speed * 0.045)) % 1
			for _, j in ipairs(h.Joints) do
				local a = j.Rest
				local name = j.Part.Name
				if LEG_PHASE[name] then
					a = a + math.sin((h.Phase + LEG_PHASE[name]) * math.pi * 2) * 0.75 * amp
				elseif name == "Neck" then
					a = a + math.sin(h.Phase * math.pi * 4) * 0.1 * amp
				elseif name == "Tail" then
					a = a - 0.6 * amp + math.sin(os.clock() * 3 + h.Phase) * 0.12
				end
				j.Weld.C0 = CFrame.new(j.Joint) * CFrame.Angles(a, 0, 0) * CFrame.new(0, -j.Drop, 0)
			end
			-- Its name, over its head.
			local name = horse:GetAttribute("HorseName")
			if name and h.PlateName ~= name then
				h.PlateName = name
				if h.Plate then
					h.Plate:Destroy()
				end
				local headPart = horse:FindFirstChild("Head")
				if headPart then
					local bb = Instance.new("BillboardGui")
					bb.Name = "HorseNameplate"
					bb.Adornee = headPart
					bb.Size = UDim2.fromOffset(150, 26)
					bb.StudsOffset = Vector3.new(0, 2.2, 0)
					bb.MaxDistance = 80
					bb.LightInfluence = 0
					local text = plaque(bb, Color3.fromRGB(255, 225, 150))
					text.Text = string.upper(name)
					bb.Parent = VFXLib.Folder
					h.Plate = bb
				end
			elseif not name and h.Plate then
				h.Plate:Destroy()
				h.Plate, h.PlateName = nil, nil
			end
			-- Body bob, always from where the server put the horse (BodyY),
			-- never from last frame's position (so it can't creep).
			local bodyY = horse:GetAttribute("BodyY")
			if h.Weld and bodyY then
				h.Weld.C0 = CFrame.new(0, bodyY, -0.4) * CFrame.new(0, math.abs(math.sin(h.Phase * math.pi * 2)) * 0.25 * amp, 0) * CFrame.Angles(math.sin(h.Phase * math.pi * 2) * 0.04 * amp, 0, 0)
			end
		end
	end
end

local function stepRiders()
	local seen = {}
	for _, horse in ipairs(CollectionService:GetTagged("SpinHorse")) do
		local character = horse.Parent
		if character and character:IsA("Model") and character:FindFirstChildOfClass("Humanoid") then
			seen[character] = true
			if riders[character] == nil then
				riders[character] = TuskAnimation.currentHold(character) or false
				TuskAnimation.hold(character, "Ride")
			end
			-- Up onto the saddle (the server says how high), camera too.
			local lift = character:GetAttribute("RideLift") or 2.4
			if TuskAnimation.setLift then
				TuskAnimation.setLift(character, lift)
			end
			if character == player.Character then
				local hum = character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.CameraOffset = Vector3.new(0, lift, 0)
				end
			end
			-- Hide the walk / run animation's legs while riding.
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					if track.WeightTarget > 0.01 then
						track:AdjustWeight(0.001, 0)
					end
				end
			end
		end
	end
	for character, previous in pairs(riders) do
		if not seen[character] then
			riders[character] = nil
			if TuskAnimation.setLift then
				TuskAnimation.setLift(character, nil)
			end
			if character == player.Character then
				local hum = character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.CameraOffset = Vector3.new()
				end
			end
			if character.Parent then
				TuskAnimation.stopHold(character, "Ride")
				if previous then
					TuskAnimation.hold(character, previous)
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Every frame: entry banner, countdown, race card
---------------------------------------------------------------------------
local lastCount = nil
-- Dust behind galloping horses (everyone sees it); your view widens when you gallop.
local dustAt = 0
local fovOn = false
local function stepGallop()
	local t = os.clock()
	if t >= dustAt then
		dustAt = t + 0.12
		for _, horse in ipairs(CollectionService:GetTagged("SpinHorse")) do
			local character = horse.Parent
			if character and character:GetAttribute("Galloping") then
				local root = character:FindFirstChild("HumanoidRootPart")
				if root then
					VFXLib.burst((root.CFrame * CFrame.new(0, -3, 3)).Position, { Count = 3, Color = Color3.fromRGB(196, 176, 140), Speed = 6, Lifetime = 0.5 })
				end
			end
		end
	end
	local mine = player.Character and player.Character:GetAttribute("Galloping") == true
	if mine ~= fovOn then
		fovOn = mine
		if CameraFX.setFovHold then
			CameraFX.setFovHold(mine and 8 or 0)
		end
	end
end

-- Gallop (hold) and back-to-last-gate: bound only while you're racing.
function RaceClient.bindControls(on)
	if on == controlsBound then
		return
	end
	controlsBound = on
	local keys = TuskConfig.Keys or {}
	if on then
		local g = keys.Gallop or {}
		ContextActionService:BindActionAtPriority("SpinGallop", function(_, state)
			if state == Enum.UserInputState.Begin then
				Remote:FireServer("Gallop", true)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				Remote:FireServer("Gallop", false)
			end
			return Enum.ContextActionResult.Sink
		end, true, 3000, g.Keyboard or Enum.KeyCode.LeftShift, g.Gamepad or Enum.KeyCode.ButtonL3)
		ContextActionService:SetTitle("SpinGallop", "GALLOP")
		ContextActionService:SetPosition("SpinGallop", UDim2.new(1, -95, 1, -235))
		local rk = keys.RaceReturn or {}
		ContextActionService:BindAction("SpinRaceReturn", function(_, state)
			if state == Enum.UserInputState.Begin then
				Remote:FireServer("Return")
			end
			return Enum.ContextActionResult.Sink
		end, true, rk.Keyboard or Enum.KeyCode.H, rk.Gamepad or Enum.KeyCode.DPadUp)
		ContextActionService:SetTitle("SpinRaceReturn", "BACK")
		ContextActionService:SetPosition("SpinRaceReturn", UDim2.new(1, -250, 1, -165))
	else
		ContextActionService:UnbindAction("SpinGallop")
		ContextActionService:UnbindAction("SpinRaceReturn")
		if Remote then
			Remote:FireServer("Gallop", false)
		end
	end
end

local function stepUI()
	local t = workspace:GetServerTimeNow()
	local phase = ReplicatedStorage:GetAttribute("SpinRacePhase")
	-- Entry.
	if phase == "Entry" then
		entryPanel.Visible = true
		soonChip.Visible = false
		entryInfo.Text = "ENTRY OPEN  " .. mmss((ReplicatedStorage:GetAttribute("SpinRaceEntryEnds") or t) - t) .. (lastCount and ("  ·  " .. lastCount .. " RIDER" .. (lastCount == 1 and "" or "S")) or "")
	else
		entryPanel.Visible = false
		local nextAt = ReplicatedStorage:GetAttribute("SpinRaceNext")
		local left = nextAt and nextAt - t
		soonChip.Visible = phase == nil and left ~= nil and left > 0 and left <= 60
		if soonChip.Visible then
			soonChip:FindFirstChild("Text").Text = "STEEL BALL RUN IN " .. mmss(left)
		end
	end
	-- Countdown: 3, 2, 1, GO!
	local goAt = ReplicatedStorage:GetAttribute("SpinRaceGoAt")
	if entered and goAt and (phase == "Countdown" or (phase == "Racing" and t - goAt < 0.8)) then
		local left = goAt - t
		local text = left > 0 and tostring(math.ceil(left)) or "GO!"
		if countdownLabel.Text ~= text then
			countdownLabel.Text = text
			countdownLabel.TextColor3 = left > 0 and GOLD or Color3.fromRGB(120, 230, 120)
			local scale = countdownLabel:FindFirstChildOfClass("UIScale")
			scale.Scale = 1.8
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			if text == "GO!" then
				CameraFX.fovPunch(10, 0.4)
			end
		end
		countdownLabel.Visible = true
	else
		countdownLabel.Visible = false
	end
	-- Racing extras: stamina, the strip, "JUMP!", gallop / return controls.
	local racing = entered and phase == "Racing" and nextGate <= totalGates
	RaceClient.bindControls(racing)
	raceStrip.Visible = entered and (phase == "Countdown" or phase == "Racing")
	local character = player.Character
	local stamina = character and character:GetAttribute("HorseStamina")
	staminaPanel.Visible = racing and stamina ~= nil
	if staminaPanel.Visible then
		local k = math.clamp(stamina / 100, 0, 1)
		staminaFill.Size = UDim2.fromScale(k, 1)
		local winded = character:GetAttribute("HorseWinded") == true
		staminaFill.BackgroundColor3 = winded and RED or (k > 0.5 and GREEN or C.GOLD)
		staminaText.Text = winded and "WINDED!  LET HIM BREATHE" or (character:GetAttribute("Galloping") and "GALLOPING!" or "STAMINA  ·  SHIFT: GALLOP  ·  H: LAST GATE")
		staminaText.TextColor3 = winded and RED or C.GOLD
	end
	-- A hurdle just ahead?
	local showJump = false
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if racing and root then
		for _, h in ipairs(CollectionService:GetTagged("SpinHurdle")) do
			local facing = h:GetAttribute("Facing")
			local pivot = h:GetPivot().Position
			if typeof(facing) == "Vector3" then
				local along = (root.Position - pivot):Dot(facing)
				local side = math.abs((root.Position - pivot):Dot(facing:Cross(Vector3.new(0, 1, 0))))
				if along < -2 and along > -30 and side < (h:GetAttribute("Width") or 30) / 2 + 4 then
					showJump = true
				end
			end
		end
	end
	if showJump ~= jumpLabel.Visible then
		jumpLabel.Visible = showJump
		if showJump then
			UITheme.pop(jumpLabel, 0.6)
		end
	end
	-- Race card.
	card.Visible = entered and (phase == "Countdown" or phase == "Racing")
	if card.Visible then
		card:FindFirstChild("Gate").Text = nextGate > totalGates and "FINISHED" or ("GATE " .. nextGate .. " / " .. totalGates)
		local start = ReplicatedStorage:GetAttribute("SpinRaceStart")
		card:FindFirstChild("Time").Text = start and mmss(t - start) or "0:00"
	end
end

function RaceClient.init()
	local horses = TuskConfig.Horses or {}
	if cfg.Enabled == false and horses.Enabled == false then
		return
	end
	Remote = Net.get("Race")
	buildUI()
	-- M: call your horse / get off it.
	if horses.Enabled ~= false then
		local keys = TuskConfig.Keys and TuskConfig.Keys.Horse
		ContextActionService:BindAction("SpinHorse", function(_, state)
			if state == Enum.UserInputState.Begin then
				Remote:FireServer("Horse")
			end
			return Enum.ContextActionResult.Sink
		end, true, keys and keys.Keyboard or Enum.KeyCode.M, keys and keys.Gamepad or Enum.KeyCode.DPadLeft)
		ContextActionService:SetTitle("SpinHorse", "HORSE")
		ContextActionService:SetPosition("SpinHorse", UDim2.new(1, -170, 1, -165))
	end
	Remote.OnClientEvent:Connect(function(kind, data)
		data = typeof(data) == "table" and data or {}
		if kind == "EntryOpen" then
			setEntered(false)
			lastCount = 0
			showBanner("THE STEEL BALL RUN: ENTRY OPEN!", GOLD, 3)
		elseif kind == "Joined" then
			setEntered(true)
			showBanner("YOU'RE IN THE STEEL BALL RUN!", Color3.fromRGB(150, 235, 150), 2.5)
		elseif kind == "Entrants" then
			lastCount = data.Count
		elseif kind == "Out" then
			setEntered(false)
			clearGuide()
			showBanner(string.upper(data.Reason or "OUT OF THE RACE"), Color3.fromRGB(255, 150, 130), 3)
		elseif kind == "Cancelled" then
			setEntered(false)
			showBanner(string.upper(data.Reason or "RACE CANCELLED"), PAPER, 3)
		elseif kind == "Countdown" then
			nextGate, totalGates, standings = 1, data.Total or 0, {}
		elseif kind == "Go" then
			totalGates = data.Total or totalGates
		elseif kind == "Gate" then
			nextGate = (data.Index or 0) + 1
			totalGates = data.Total or totalGates
			VFXLib.sound(TuskConfig.Sounds.Swing, workspace.CurrentCamera, 0.5, 1.4)
			showBanner("GATE " .. tostring(data.Index) .. " / " .. tostring(totalGates) .. (data.Split and ("   " .. mmss(data.Split)) or ""), GOLD, 1.2)
		elseif kind == "Standings" then
			standings = data.List or {}
			totalGates = data.Total or totalGates
			fillStandings()
			fillStrip()
		elseif kind == "Finished" then
			if data.UserId == player.UserId then
				nextGate = totalGates + 1
				clearGuide()
				showBanner("YOU FINISHED " .. ordinal(data.Place or 0) .. "!  +$" .. tostring(data.Prize or 0) .. (data.Part and ("  +  " .. data.Part) or ""), GOLD, 4)
			elseif data.Place == 1 and entered then
				showBanner(string.upper(data.Name or "SOMEONE") .. " WINS THE STEEL BALL RUN!", GOLD, 3.5)
			elseif data.Place == 1 and not data.Jockey then
				showBanner(string.upper(data.Name or "SOMEONE") .. " WINS THE STEEL BALL RUN!", GOLD, 3.5)
			end
		elseif kind == "Winded" then
			showBanner("YOUR HORSE IS WINDED!", RED, 1.6)
		elseif kind == "Recovered" then
			showBanner("GOT HIS BREATH BACK: GALLOP!", Color3.fromRGB(150, 235, 150), 1.2)
		elseif kind == "CarrotYou" then
			showBanner("CARROTS!  +STAMINA", Color3.fromRGB(255, 170, 70), 1.2)
			CameraFX.fovPunch(6, 0.3)
		elseif kind == "Carrot" and data.Position then
			VFXLib.burst(data.Position + Vector3.new(0, 2, 0), { Count = 14, Color = Color3.fromRGB(236, 130, 40), Speed = 10, Lifetime = 0.5 })
		elseif kind == "StumbleYou" then
			showBanner("STUMBLED!", RED, 1.2)
			CameraFX.shake(0.6, 0.3)
		elseif kind == "Stumble" and data.Position then
			VFXLib.burst(data.Position + Vector3.new(0, 1, 0), { Count = 20, Color = Color3.fromRGB(190, 170, 140), Speed = 14, Lifetime = 0.6 })
		elseif kind == "Cleared" then
			showBanner("NICE JUMP!", Color3.fromRGB(150, 235, 150), 0.9)
		elseif kind == "Returned" then
			showBanner("BACK AT " .. ((data.Gate or 0) >= 1 and ("GATE " .. data.Gate) or "THE START") .. "  (-" .. tostring(data.Penalty or 3) .. "s)", PAPER, 2)
		elseif kind == "Record" then
			task.delay(4.2, function()
				if data.NewRecord then
					showBanner("NEW RECORD!  " .. mmss(data.Time or 0) .. "   ·   WINS: " .. tostring(data.Wins or 0), GOLD, 3.5)
				else
					showBanner("BEST: " .. mmss(data.OldBest or 0) .. "   ·   WINS: " .. tostring(data.Wins or 0), PAPER, 3)
				end
			end)
		elseif kind == "Horse" then
			showBanner(data.Riding and "YOUR HORSE  (M TO GET OFF)" or "SENT YOUR HORSE AWAY", PAPER, 1.6)
		elseif kind == "Denied" then
			showBanner(string.upper(data.Reason or "CAN'T DO THAT"), Color3.fromRGB(255, 150, 130), 1.6)
		elseif kind == "Results" then
			local wasIn = entered
			setEntered(false)
			clearGuide()
			if wasIn then
				showResults(data.List or {}, data.Reason)
			else
				local first = (data.List or {})[1]
				showBanner(first and (string.upper(first.Name or "?") .. " WON THE STEEL BALL RUN!") or "THE STEEL BALL RUN IS OVER", GOLD, 3.5)
			end
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		stepUI()
		stepGallop()
		stepGuide()
		stepHorses(dt)
		stepRiders()
	end)
end

return RaceClient
