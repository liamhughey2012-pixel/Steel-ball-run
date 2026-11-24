--[[
	SpinCore_Client_4  (ModuleScript)  -- part 4 of 8
	PUT IT IN: ReplicatedStorage > SpinCore   (make a Folder named SpinCore there if it doesn't exist)

	Part of the Spin Battlegrounds client core, split up so pasting is quick.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: RaceClient
-- ======================================================================
__modules["RaceClient"] = function()
--[[
	RaceClient  (StarterPlayerScripts.SpinClient.RaceClient)

	The Steel Ball Run on the client (RaceService runs it):
	  * ENTRY: a wanted-poster style banner at the top, "THE STEEL BALL RUN
	    · ENTRY OPEN 0:38" with a JOIN button (LEAVE once you're in) and how
	    many riders have entered. A minute before entry opens, a small chip
	    counts down to it
	  * COUNTDOWN: a big 3, 2, 1, GO!
	  * RACING (riders): a race card top-right (your position, gate x / N,
	    the time, the top five) with a LEAVE button; a tall golden beacon
	    on your next gate with its number and distance, and a gold arrow
	    ahead of your horse pointing at it
	  * the winner and the results for everyone
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

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskAnimation = __require("TuskAnimation")

local RaceClient = {}
local player = Players.LocalPlayer
local cfg = TuskConfig.Race or {}
local Remote

local PAPER = Color3.fromRGB(234, 205, 160)
local INK = Color3.fromRGB(60, 36, 20)
local RED = Color3.fromRGB(176, 40, 36)
local GREEN = Color3.fromRGB(60, 150, 70)
local GOLD = Color3.fromRGB(255, 205, 90)
local WOOD_DARK = Color3.fromRGB(78, 50, 30)

local gui, entryPanel, entryTitle, entryInfo, entryButton, soonChip, countdownLabel, card, cardRows, banner
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
	local l = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextColor3 = INK, TextScaled = true }, parent)
	for k, v in pairs(props) do
		l[k] = v
	end
	return l
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
	gui = new("ScreenGui", { Name = "SteelBallRun", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 7 }, player:WaitForChild("PlayerGui"))
	-- Entry banner.
	entryPanel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(420, 92), BackgroundColor3 = PAPER, Visible = false }, gui)
	corner(entryPanel, 8)
	new("UIStroke", { Color = WOOD_DARK, Thickness = 3 }, entryPanel)
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(205, 172, 125)), ColorSequenceKeypoint.new(0.4, PAPER), ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 172, 125)) }), Rotation = 80 }, entryPanel)
	new("UISizeConstraint", { MaxSize = Vector2.new(420, 92) }, entryPanel)
	local strip = new("Frame", { Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = RED, BorderSizePixel = 0 }, entryPanel)
	corner(strip, 8)
	entryTitle = label(entryPanel, { Position = UDim2.fromOffset(18, 6), Size = UDim2.new(1, -150, 0, 30), Text = "THE STEEL BALL RUN", Font = Enum.Font.Bangers, TextXAlignment = Enum.TextXAlignment.Left })
	entryInfo = label(entryPanel, { Position = UDim2.fromOffset(18, 38), Size = UDim2.new(1, -150, 0, 18), Text = "", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left })
	label(entryPanel, { Position = UDim2.fromOffset(18, 60), Size = UDim2.new(1, -150, 0, 24), Text = "Race round the map on horseback. Top 3 win Cash; the winner gets a Saint's Corpse part.", Font = Enum.Font.GothamMedium, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = INK:Lerp(PAPER, 0.25) })
	entryButton = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(118, 56), BackgroundColor3 = GREEN, Text = "JOIN", Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, entryPanel)
	corner(entryButton, 8)
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, entryButton)
	new("UIStroke", { Color = GREEN:Lerp(Color3.new(0, 0, 0), 0.4), Thickness = 2 }, entryButton)
	entryButton.Activated:Connect(function()
		Remote:FireServer(entered and "Leave" or "Join")
	end)
	-- "STEEL BALL RUN IN 0:45" chip.
	soonChip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(230, 26), BackgroundColor3 = WOOD_DARK, BackgroundTransparency = 0.15, Visible = false }, gui)
	corner(soonChip, 8)
	label(soonChip, { Name = "Text", Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = GOLD, Font = Enum.Font.GothamBlack })
	-- Countdown.
	countdownLabel = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.35), Size = UDim2.fromOffset(400, 150), Text = "", Font = Enum.Font.Bangers, TextColor3 = GOLD, TextStrokeTransparency = 0, Visible = false })
	new("UIScale", { Scale = 1 }, countdownLabel)
	-- Race card (top right).
	card = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 64), Size = UDim2.fromOffset(230, 200), BackgroundColor3 = PAPER, Visible = false }, gui)
	corner(card, 8)
	new("UIStroke", { Color = WOOD_DARK, Thickness = 3 }, card)
	label(card, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -60, 0, 22), Text = "STEEL BALL RUN", Font = Enum.Font.Bangers, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Left })
	label(card, { Name = "Pos", Position = UDim2.fromOffset(10, 28), Size = UDim2.fromOffset(90, 40), Text = "-", Font = Enum.Font.Bangers, TextXAlignment = Enum.TextXAlignment.Left })
	label(card, { Name = "Gate", Position = UDim2.fromOffset(104, 30), Size = UDim2.fromOffset(116, 18), Text = "", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right })
	label(card, { Name = "Time", Position = UDim2.fromOffset(104, 50), Size = UDim2.fromOffset(116, 16), Text = "", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = INK:Lerp(PAPER, 0.3) })
	cardRows = new("Frame", { Position = UDim2.fromOffset(10, 74), Size = UDim2.new(1, -20, 0, 100), BackgroundTransparency = 1 }, card)
	local leave = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(46, 18), BackgroundColor3 = RED, Text = "LEAVE", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, card)
	corner(leave, 5)
	leave.Activated:Connect(function()
		Remote:FireServer("Leave")
	end)
	label(card, { Name = "Hint", Position = UDim2.new(0, 10, 1, -22), Size = UDim2.new(1, -20, 0, 16), Text = "Ride through the gates in order", Font = Enum.Font.GothamMedium, TextColor3 = INK:Lerp(PAPER, 0.35) })
	-- Big banner.
	banner = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.24), Size = UDim2.fromOffset(640, 70), Text = "", Font = Enum.Font.Bangers, TextColor3 = GOLD, TextStrokeTransparency = 0, Visible = false })
	new("UIScale", { Scale = 1 }, banner)
end

local function setEntered(on)
	entered = on
	entryButton.Text = on and "LEAVE" or "JOIN"
	entryButton.BackgroundColor3 = on and RED or GREEN
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
			local line = new("Frame", { Position = UDim2.fromOffset(0, (i - 1) * 20), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = me and GOLD or PAPER, BackgroundTransparency = me and 0.2 or 1 }, cardRows)
			corner(line, 4)
			label(line, { Position = UDim2.fromOffset(4, 1), Size = UDim2.new(0.7, -4, 1, -2), Text = i .. ". " .. string.upper(row.Name or "?"), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
			label(line, { Position = UDim2.new(0.7, 0, 0, 1), Size = UDim2.new(0.3, -4, 1, -2), Text = row.Finished and "DONE" or ("GATE " .. math.min(row.Next or 1, totalGates)), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = row.Finished and GREEN or INK })
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
		bb.Size = UDim2.fromOffset(160, 44)
		bb.StudsOffset = Vector3.new(0, 20, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Adornee = pillar
		local text = label(bb, { Size = UDim2.fromScale(1, 1), Text = "", Font = Enum.Font.Bangers, TextColor3 = GOLD, TextStrokeTransparency = 0 })
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
					bb.Size = UDim2.fromOffset(160, 26)
					bb.StudsOffset = Vector3.new(0, 2.2, 0)
					bb.MaxDistance = 80
					bb.LightInfluence = 0
					local text = Instance.new("TextLabel")
					text.BackgroundTransparency = 1
					text.Size = UDim2.fromScale(1, 1)
					text.Font = Enum.Font.Bangers
					text.TextScaled = true
					text.Text = string.upper(name)
					text.TextColor3 = Color3.fromRGB(255, 225, 150)
					text.TextStrokeTransparency = 0.2
					text.Parent = bb
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
			showBanner("GATE " .. tostring(data.Index) .. " / " .. tostring(totalGates), GOLD, 1.2)
		elseif kind == "Standings" then
			standings = data.List or {}
			totalGates = data.Total or totalGates
			fillStandings()
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
		elseif kind == "Horse" then
			showBanner(data.Riding and "YOUR HORSE  (M TO GET OFF)" or "SENT YOUR HORSE AWAY", PAPER, 1.6)
		elseif kind == "Denied" then
			showBanner(string.upper(data.Reason or "CAN'T DO THAT"), Color3.fromRGB(255, 150, 130), 1.6)
		elseif kind == "Results" then
			setEntered(false)
			clearGuide()
			local lines = {}
			for i, r in ipairs(data.List or {}) do
				if i <= 3 then
					table.insert(lines, ordinal(r.Place or i) .. " " .. string.upper(r.Name or "?") .. string.format(" %.1fs", r.Time or 0))
				end
			end
			showBanner(#lines > 0 and ("STEEL BALL RUN:  " .. table.concat(lines, "   ")) or "THE STEEL BALL RUN IS OVER", GOLD, 5)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		stepUI()
		stepGuide()
		stepHorses(dt)
		stepRiders()
	end)
end

return RaceClient
end

-- ======================================================================
-- MODULE: SettingsUI
-- ======================================================================
__modules["SettingsUI"] = function()
--[[
	SettingsUI  (StarterPlayerScripts.SpinClient.UI.SettingsUI)
	The small "VFX: MEDIUM" button (top right) that cycles Low / Medium / High.
	Phones start on Low to keep the frame rate smooth.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = nil -- (bundled: modules are inlined)
local VFXQuality = __require("VFXQuality")

local SettingsUI = {}
local DARK = Color3.fromRGB(22, 16, 10)
local FONT = Enum.Font.GothamBlack
local colors = { GoldLight = Color3.fromRGB(255, 238, 160), Gold = Color3.fromRGB(255, 196, 56) }

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function SettingsUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpinSettings"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- VFX quality toggle (top right, small).
	local qualityButton = Instance.new("TextButton")
	qualityButton.Name = "VFXQuality"
	qualityButton.AnchorPoint = Vector2.new(1, 0)
	qualityButton.Position = UDim2.new(1, -12, 0, 12)
	qualityButton.Size = UDim2.fromOffset(130, 28)
	qualityButton.BackgroundColor3 = DARK
	qualityButton.BackgroundTransparency = 0.2
	qualityButton.Font = FONT
	qualityButton.TextSize = 13
	qualityButton.TextColor3 = colors.GoldLight
	qualityButton.Parent = gui
	corner(qualityButton, 6)
	stroke(qualityButton, colors.Gold, 1.5)
	local function refresh()
		local _, name = VFXQuality.get()
		qualityButton.Text = "VFX: " .. string.upper(name)
	end
	refresh()
	qualityButton.Activated:Connect(function()
		VFXQuality.cycle()
	end)
	VFXQuality.Changed:Connect(refresh)

	-- Touch devices start on Low to protect frame rate; players can raise it.
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		VFXQuality.set("Low")
	end
end

return SettingsUI
end

-- ======================================================================
-- MODULE: TuskActCommon
-- ======================================================================
__modules["TuskActCommon"] = function()
--[[
	TuskActCommon  (StarterPlayerScripts.SpinClient.TuskActCommon)

	Shared client choreography used by every Act's visual module:
	  Palette(act)          each Act's colour identity
	  m1(data, palette)     poses, Stand lunges, swipes, mini-portals
	  finisher(data, pal)   combo-ender shockwave
	  portal(...)           wormhole that opens, holds and collapses
	  golden(...)           golden rectangle + spiral (Act 2), same arguments
	  portalNail(...)       portals for nails fired through them
	  evolve(data)          the "next Act" transformation + banner
	  charge helpers        attribute-driven hold charges
]]

local Players = game:GetService("Players")
local Fighters = __require("Fighters")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local TuskStand = __require("TuskStand")

local Common = {}
local colors = TuskConfig.Colors
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

Common.Palettes = {
	[1] = { Main = colors.Cyan, Second = colors.Blue, Light = colors.Ice },
	[2] = { Main = Color3.fromRGB(80, 210, 255), Second = Color3.fromRGB(110, 70, 255), Light = colors.Ice },
	[3] = { Main = Color3.fromRGB(70, 130, 255), Second = Color3.fromRGB(30, 20, 120), Light = Color3.fromRGB(190, 210, 255) },
	[4] = { Main = colors.Gold, Second = colors.DeepBlue, Light = colors.GoldLight },
	[5] = { Main = Color3.fromRGB(120, 225, 95), Second = Color3.fromRGB(40, 120, 50), Light = Color3.fromRGB(225, 255, 205) }, -- Gyro
	[6] = { Main = Color3.fromRGB(80, 210, 220), Second = Color3.fromRGB(35, 60, 190), Light = Color3.fromRGB(215, 255, 250) }, -- Diego
	[7] = { Main = Color3.fromRGB(165, 215, 80), Second = Color3.fromRGB(95, 105, 125), Light = Color3.fromRGB(225, 232, 245) }, -- Pork Pie Hat Kid (bamboo green + steel)
	[8] = { Main = Color3.fromRGB(245, 185, 80), Second = Color3.fromRGB(50, 140, 160), Light = Color3.fromRGB(255, 240, 205) }, -- Sandman (sand + turquoise)
	[9] = { Main = Color3.fromRGB(214, 156, 84), Second = Color3.fromRGB(96, 62, 38), Light = Color3.fromRGB(255, 232, 196) }, -- Mountain Tim (leather + rope)
	[10] = { Main = Color3.fromRGB(242, 140, 172), Second = Color3.fromRGB(120, 60, 92), Light = Color3.fromRGB(255, 220, 230) }, -- Hot Pants (Cream Starter pink)
	[11] = { Main = Color3.fromRGB(110, 180, 255), Second = Color3.fromRGB(40, 50, 90), Light = Color3.fromRGB(225, 245, 255) }, -- Blackmore (rain blue)
	[12] = { Main = Color3.fromRGB(214, 60, 70), Second = Color3.fromRGB(226, 196, 110), Light = Color3.fromRGB(255, 200, 200) }, -- Axl RO (Civil War red)
	[13] = { Main = Color3.fromRGB(120, 170, 255), Second = Color3.fromRGB(236, 120, 170), Light = Color3.fromRGB(240, 246, 255) }, -- Funny Valentine (D4C blue + pink)
	[14] = { Main = Color3.fromRGB(236, 196, 70), Second = Color3.fromRGB(70, 170, 160), Light = Color3.fromRGB(255, 244, 200) }, -- Diego from another world (The World gold + teal)
}

function Common.palette(act)
	return Common.Palettes[act] or Common.Palettes[1]
end

function Common.rootOf(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

function Common.isLocal(character)
	return character ~= nil and character == localPlayer.Character
end

function Common.swipe(root, side, color, scale)
	scale = scale or 1
	local cf = root.CFrame * CFrame.new(side * 0.3, 0.3, -1.2) * CFrame.Angles(0, 0, side * 0.5)
	-- A thick coloured arc, a thin bright inner arc a beat later, and sparks
	-- flung off the tip of the swing.
	TuskVFX.CreateCrescent(cf, { Radius = 2.4 * scale, Width = 0.6 * scale, Color = color, Color2 = Color3.new(1, 1, 1), Sweep = side * 1.9, Duration = 0.2 })
	task.delay(0.03, function()
		if root.Parent then
			TuskVFX.CreateCrescent(cf * CFrame.new(0, 0, -0.3), { Radius = 1.8 * scale, Width = 0.18 * scale, Color = Color3.new(1, 1, 1), Color2 = color, Sweep = side * 2.1, Duration = 0.14 })
		end
	end)
	local tip = (root.CFrame * CFrame.new(-side * 1.6 * scale, 0.4, -2.2 * scale)).Position
	VFXLib.burst(tip, { Count = 5, Color = color, Speed = 18, Lifetime = 0.22, Spread = 50, Direction = root.CFrame.RightVector * -side, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }) })
end

---------------------------------------------------------------------------
-- Portals
---------------------------------------------------------------------------
-- A wormhole facing `lookAt`. Opens, holds `duration`, collapses.
function Common.portal(position, lookAt, radius, duration, palette, delay)
	palette = palette or Common.palette(2)
	local function open()
		local facing = (lookAt and (lookAt - position).Magnitude > 0.1) and CFrame.lookAt(position, lookAt) or CFrame.new(position)
		TuskVFX.CreateWormhole(facing, {
			Radius = radius or 2.5,
			Color = palette.Main,
			Color2 = palette.Second,
			OpenTime = 0.22,
			Duration = duration or 0.6,
			CloseTime = 0.2,
		})
		VFXLib.sound(sounds.Warning, position, 0.25, 1.6)
	end
	if delay and delay > 0 then
		task.delay(delay, open)
	else
		open()
	end
end

-- Golden ratio (Act 2): a Golden Rectangle with its spiral facing `lookAt`,
-- a spinning golden spiral in front and a soft gold flash. Same arguments
-- as Common.portal so the two can be swapped.
function Common.golden(position, lookAt, radius, duration, palette, delay)
	palette = palette or Common.palette(2)
	local function open()
		local facing = (lookAt and (lookAt - position).Magnitude > 0.1) and CFrame.lookAt(position, lookAt) or CFrame.new(position)
		local size = (radius or 2.5) * 1.1
		TuskVFX.CreateGoldenRectangle(facing, { Size = size, Duration = (duration or 0.6) + 0.25, Color = colors.Gold, Color2 = colors.GoldLight, Turn = math.pi * 0.4 })
		TuskVFX.CreateGoldenSpiral(facing * CFrame.new(0, 0, -0.1), { Size = size * 0.9, Duration = (duration or 0.6) + 0.2, Color = palette.Main, Color2 = colors.GoldLight, Width = 0.14 })
		VFXLib.flash(position, colors.Gold, 3, 10 + size * 2, 0.25)
		VFXLib.sound(sounds.Warning, position, 0.2, 1.8)
	end
	if delay and delay > 0 then
		task.delay(delay, open)
	else
		open()
	end
end

---------------------------------------------------------------------------
-- M1
---------------------------------------------------------------------------
local LUNGES = {
	CFrame.new(0.4, 0.6, -3),
	CFrame.new(-0.6, 0.4, -3.2),
	CFrame.new(0.9, 1, -2.4),
	CFrame.new(0, 1.4, -3.4),
}

function Common.m1(data, palette, opts)
	opts = opts or {}
	local character = data.Character
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local index = data.Index
	TuskAnimation.play(character, (opts.AnimPrefix or "M1_") .. index)
	VFXLib.sound(sounds.Swing, root, 0.5, (opts.Pitch or 1) * (0.95 + index * 0.06))
	TuskStand.action(character, "Lunge", { Target = LUNGES[index], Duration = index == 4 and 0.5 or 0.26 })
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and palette.Main or palette.Light, opts.Scale)
	if data.Portal then
		-- Short portal (or golden rectangle) flash beside the strike.
		local pos = (root.CFrame * CFrame.new(index % 2 == 1 and 1.6 or -1.6, 1, -2.6)).Position
		local open = opts.Golden and Common.golden or Common.portal
		open(pos, (root.CFrame * CFrame.new(0, 1, -6)).Position, 1.1, 0.18, palette)
	end
	if (data.Repeat or 1) > 1 then
		for i = 2, data.Repeat do
			task.delay((i - 1) * 0.08, function()
				if root.Parent then
					Common.swipe(root, i % 2 == 0 and -1 or 1, palette.Light, opts.Scale)
					VFXLib.burst((root.CFrame * CFrame.new(0, 0.5, -3)).Position, { Count = 5, Color = palette.Main, Speed = 10, Lifetime = 0.2 })
				end
			end)
		end
	end
end

function Common.finisher(data, palette, opts)
	opts = opts or {}
	local character = data.Character
	local root = Common.rootOf(character)
	local pos = data.Position
	if data.Hit and Common.isLocal(character) then
		CameraFX.impactFrame(palette.Light)
	end
	TuskVFX.CreateRotationalShockwave(CFrame.new(pos - Vector3.new(0, 2.6, 0)), {
		Radius = data.Radius or 7,
		Layers = opts.Layers or 3,
		Color = palette.Main,
		Color2 = palette.Second,
		Ground = true,
		Particles = 1.5,
		Width = opts.Width or 0.5,
	})
	TuskVFX.CreateImpact(pos, root and -root.CFrame.LookVector or Vector3.new(0, 1, 0), { Size = opts.Size or 1.2, Radius = 3, Layers = 2, Color = palette.Light, Color2 = palette.Main, Ground = false })
	TuskVFX.CreateImpactStar(pos, { Size = 6 * (opts.Size or 1.2), Rays = 9, Color = palette.Main, Color2 = palette.Light, Duration = 0.3 })
	if data.Hit then
		TuskVFX.CreateGroundCracks(pos, { Radius = (data.Radius or 7) * 0.8, Color = palette.Main, Duration = 1.3 })
	end
	VFXLib.sound(sounds.Finisher, pos, 0.8, opts.Pitch or 1)
	CameraFX.shakeAt(pos, opts.Shake or 0.6, 50)
end

---------------------------------------------------------------------------
-- Evolution: Act N -> Act N+1
---------------------------------------------------------------------------
function Common.evolve(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local palette = Common.palette(data.To)
	local ground = root.Position - Vector3.new(0, 2.9, 0)
	TuskVFX.CreateMagicCircle(CFrame.new(ground), { Radius = 9, Color = palette.Main, Color2 = palette.Light, Duration = 1.4, RotationSpeed = 2, Points = data.To + 4 })
	TuskVFX.CreateRotationalShockwave(CFrame.new(ground), { Radius = 16, Layers = 3, Color = palette.Main, Color2 = palette.Light, Ground = true, Particles = 2, Width = 0.7, Duration = 0.6 })
	VFXLib.burst(root.Position, { Count = 40, Color = palette.Light, Speed = 40, Lifetime = 0.6 })
	VFXLib.flash(root.Position, palette.Main, 9, 30, 0.6)
	TuskVFX.CreateEnergyPillar(ground, { Radius = 5, Height = 45, Color = palette.Light, Color2 = palette.Main, Duration = 0.6 })
	TuskVFX.CreateImpactStar(root.Position, { Size = 10, Rays = 10, Color = palette.Main, Color2 = palette.Light, Duration = 0.35 })
	VFXLib.sound(sounds.AwakeningBurst, root.Position, 0.9, 1 + data.To * 0.05)
	TuskStand.action(character, "Manifest", { Duration = 0.7 })
	if Common.isLocal(character) then
		CameraFX.speedLines(0.5, palette.Light)
		CameraFX.fovPunch(14, 0.6)
	end
end

---------------------------------------------------------------------------
-- Hold-charge visuals (shared driver)
---------------------------------------------------------------------------
--[[ Common.chargeDriver(act, move, makeEffect(character, root) -> effect,
     update(effect, progress, character), finish(effect, character)) ]]
function Common.chargeDriver(act, move, makeEffect, update, finish)
	local active = {}
	return function()
		local seen = {}
		for _, player in ipairs(Fighters.list()) do
			local character = player.Character
			local start = character and character:GetAttribute("TuskCharge")
			if start and character:GetAttribute("TuskAct") == act and character:GetAttribute("TuskChargeMove") == move then
				seen[character] = true
				local root = Common.rootOf(character)
				if not active[character] and root then
					active[character] = { Effect = makeEffect(character, root), Start = start }
				end
				local entry = active[character]
				if entry then
					update(entry.Effect, workspace:GetServerTimeNow() - start, character)
				end
			end
		end
		for character, entry in pairs(active) do
			if not seen[character] then
				active[character] = nil
				finish(entry.Effect, character)
			end
		end
	end
end

function Common.actName(act)
	local info = Registry.get(act)
	return info and info.Name or ("TUSK ACT " .. tostring(act))
end

return Common
end

-- ======================================================================
-- MODULE: TuskActRegistry
-- ======================================================================
__modules["TuskActRegistry"] = function()
--[[
	TuskActRegistry  (ReplicatedStorage.SpinShared.TuskActRegistry)

	The list of Tusk Acts: names, slot labels, themes and whether each
	Act is implemented. The server refuses to equip an Act whose
	Implemented flag is false, and the menu shows it as IN DEVELOPMENT
	(locked, not a fake button).

	To add an Act: create ServerScriptService.SpinServer.TuskActs.TuskActN,
	add its client choreography in SpinClient.TuskActVFX.ActN, then set
	Implemented = true here.
]]

local TuskActRegistry = {}

TuskActRegistry.Acts = {
	[1] = {
		Name = "TUSK ACT 1",
		Tagline = "The beginning of Spin",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(90, 230, 255), Secondary = Color3.fromRGB(40, 120, 255) },
		M1 = "NAIL COMBO",
		Abilities = { "NAIL SHOT", "NAIL BARRAGE", "SPINNING NAIL" },
		AbilityKinds = { "Press", "Press", "Hold" }, -- Hold = charge on press, fire on release
		Ultimate = "AWAKEN: INFINITE ROTATION",
		Next = 2, -- the ultimate awakens Tusk to this Act
	},
	[2] = {
		Name = "TUSK ACT 2",
		Tagline = "The Golden Ratio",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(70, 200, 255), Secondary = Color3.fromRGB(30, 80, 220) },
		M1 = "GOLDEN COMBO",
		Abilities = { "GOLDEN RATIO NAIL", "UNDERGROUND PURSUIT", "GOLDEN SPIRAL" },
		AbilityKinds = { "Press", "Press", "Press" },
		Next = 3,
		Ultimate = "AWAKEN: INFINITE ROTATION",
	},
	[3] = {
		Name = "TUSK ACT 3",
		Tagline = "Master of spatial movement",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(60, 140, 255), Secondary = Color3.fromRGB(20, 40, 160) },
		M1 = "WORMHOLE STRIKES",
		Abilities = { "DIMENSIONAL STEP", "SPATIAL PURSUIT", "DIMENSIONAL BREAK" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "AWAKEN: INFINITE ROTATION",
		Next = 4,
	},
	[4] = {
		Name = "TUSK ACT 4",
		Tagline = "Infinite Rotation",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(255, 200, 70), Secondary = Color3.fromRGB(20, 40, 160) },
		M1 = "INFINITE BARRAGE",
		Abilities = { "GOLDEN SPIN NAIL", "INFINITE ROTATION", "GOLDEN PURSUIT" },
		AbilityKinds = { "Press", "Hold", "Press" },
		Ultimate = "INFINITE ROTATION",
		Next = nil, -- final form
	},
	-- Gyro Zeppeli: a separate character that reuses the same ability system.
	[5] = {
		Name = "GYRO ZEPPELI",
		Character = "Gyro",
		Tagline = "Steel Ball master",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(120, 220, 95), Secondary = Color3.fromRGB(40, 120, 50) },
		M1 = "STEEL BALL COMBO",
		Abilities = { "STEEL BALL THROW", "SPIN TORNADO", "SPIN VIBRATION" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "BALL BREAKER",
		Next = nil,
		Module = "GyroZeppeli", -- server moves
		ClientModule = "Gyro", -- client visuals (TuskActVFX.Gyro)
		CardTitle = "STAND  ·  BALL BREAKER",
	},
	-- Diego Brando: Scary Monsters (dinosaur Stand). Same ability system.
	[6] = {
		Name = "SCARY MONSTERS",
		Character = "Diego",
		Tagline = "Dinosaur Stand",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(80, 210, 220), Secondary = Color3.fromRGB(35, 60, 190) },
		M1 = "CLAW COMBO",
		Abilities = { "RAPTOR POUNCE", "DINO INFECTION", "SCARY MONSTERS" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "RAPTOR PACK",
		Next = nil,
		Module = "DiegoBrando", -- server moves
		ClientModule = "Diego", -- client visuals (TuskActVFX.Diego)
		CardTitle = "STAND  ·  SCARY MONSTERS",
		-- The HUD shows a timer on these slots while the attribute (server time) is in the future.
		Buffs = {
			{ Slot = 3, Attribute = "DinoModeUntil", Text = "ACTIVE" },
			{ Slot = 2, Attribute = "ThrallUntil", Text = "COMMAND" },
		},
	},
	-- Pork Pie Hat Kid: WIRED (fish hooks and steel cables from a winch in his mouth).
	[7] = {
		Name = "WIRED",
		Character = "PorkPie",
		Tagline = "Hooks from the water",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(165, 215, 80), Secondary = Color3.fromRGB(95, 105, 125) },
		M1 = "HOOK COMBO",
		Abilities = { "WIRED HOOK", "BAIT PAN", "DOUBLE HOOK LIFT" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "WIRED WINCH",
		Next = nil,
		Module = "PorkPieHatKid", -- server moves
		ClientModule = "PorkPie", -- client visuals (TuskActVFX.PorkPie)
		CardTitle = "STAND  ·  WIRED",
		Buffs = {
			{ Slot = 2, Attribute = "BaitPanUntil", Text = "BAITED" },
		},
	},
	-- Sandman (Soundman): IN A SILENT WAY (sounds written as solid words that
	-- cut, burn and explode when touched).
	[8] = {
		Name = "IN A SILENT WAY",
		Character = "Sandman",
		Tagline = "Sounds made solid",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(245, 185, 80), Secondary = Color3.fromRGB(50, 140, 160) },
		M1 = "SOUND CUT COMBO",
		Abilities = { "SOUND SLASH", "SOUND TRAP", "SAND RUN" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "SILENT SYMPHONY",
		Next = nil,
		Module = "Sandman", -- server moves
		WalkSpeed = 1.25, -- he's a runner: 25% faster than everyone else
		ClientModule = "SandmanVFX", -- client visuals (TuskActVFX.SandmanVFX)
		CardTitle = "STAND  ·  IN A SILENT WAY",
	},
	-- Mountain Tim: OH! LONESOME ME (splits his body into pieces that slide
	-- along his lasso rope).
	[9] = {
		Name = "OH! LONESOME ME",
		Character = "MountainTim",
		Tagline = "Split along the rope",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(214, 156, 84), Secondary = Color3.fromRGB(96, 62, 38) },
		M1 = "LASSO COMBO",
		Abilities = { "LASSO SNARE", "SPLIT DODGE", "SPLIT BARRAGE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "LONESOME ROUNDUP",
		Next = nil,
		Module = "MountainTim", -- server moves
		ClientModule = "MountainTimVFX", -- client visuals (TuskActVFX.MountainTimVFX)
		CardTitle = "STAND  ·  OH! LONESOME ME",
	},
	-- Hot Pants: CREAM STARTER (a spray can that sprays flesh: seals wounds,
	-- coats and smothers enemies).
	[10] = {
		Name = "CREAM STARTER",
		Character = "HotPants",
		Tagline = "Flesh spray",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(242, 140, 172), Secondary = Color3.fromRGB(120, 60, 92) },
		M1 = "SPRAY COMBO",
		Abilities = { "FLESH SPRAY", "FLESH SEAL", "FLESH MEND" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "FLESH STORM",
		Next = nil,
		Module = "HotPants", -- server moves
		ClientModule = "HotPantsVFX", -- client visuals (TuskActVFX.HotPantsVFX)
		CardTitle = "STAND  ·  CREAM STARTER",
		Buffs = {
			{ Slot = 3, Attribute = "FleshMendUntil", Text = "HEALING" },
		},
	},
	-- Blackmore: CATCH THE RAINBOW (freezes raindrops in mid-air: cuts with
	-- them, walks on them, scatters into them).
	[11] = {
		Name = "CATCH THE RAINBOW",
		Character = "Blackmore",
		Tagline = "Raindrops frozen in the air",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(110, 180, 255), Secondary = Color3.fromRGB(40, 50, 90) },
		M1 = "RAINDROP COMBO",
		Abilities = { "RAINDROP BLADES", "RAINDROP STEP", "RAINDROP CAGE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "CATCH THE RAINBOW",
		Next = nil,
		Module = "Blackmore", -- server moves
		ClientModule = "BlackmoreVFX", -- client visuals (TuskActVFX.BlackmoreVFX)
		CardTitle = "STAND  ·  CATCH THE RAINBOW",
	},
	-- Axl RO: CIVIL WAR (makes a target's guilt real: specters and the things
	-- they abandoned rise up and engulf them in a crushing membrane; water,
	-- like the rain, washes it away).
	[12] = {
		Name = "CIVIL WAR",
		Character = "Axl",
		Tagline = "Guilt made real",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(214, 60, 70), Secondary = Color3.fromRGB(226, 196, 110) },
		M1 = "GUILT COMBO",
		Abilities = { "GUILT SPECTERS", "ABANDONED JUNK", "GUILT MEMBRANE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "CIVIL WAR",
		Next = nil,
		Module = "Axl", -- server moves
		ClientModule = "AxlVFX", -- client visuals (TuskActVFX.AxlVFX)
		CardTitle = "STAND  ·  CIVIL WAR",
		Passive = "GUILT: your hits mark them; your moves feed on it",
	},
	-- Funny Valentine: D4C (Dirty Deeds Done Dirt Cheap): slips between
	-- parallel worlds when sandwiched between things (a flag), brings
	-- people from other worlds, and Love Train turns misfortune away.
	[13] = {
		Name = "D4C",
		Character = "Valentine",
		Tagline = "Dirty Deeds Done Dirt Cheap",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(120, 170, 255), Secondary = Color3.fromRGB(236, 120, 170) },
		M1 = "DIRTY DEEDS COMBO",
		Abilities = { "DIMENSION HOP", "PARALLEL VALENTINE", "MENGER SPONGE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "D4C LOVE TRAIN",
		Next = nil,
		Module = "Valentine", -- server moves
		ClientModule = "ValentineVFX", -- client visuals (TuskActVFX.ValentineVFX)
		CardTitle = "STAND  ·  D4C",
		Buffs = {
			{ Slot = 2, Attribute = "ParallelCloneUntil", Text = "PARALLEL" },
		},
	},
	-- Diego Brando from another world (AU): THE WORLD (stops time).
	[14] = {
		Name = "THE WORLD",
		Character = "DiegoAU",
		Tagline = "Diego from another world",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(236, 196, 70), Secondary = Color3.fromRGB(70, 170, 160) },
		M1 = "MUDA COMBO",
		Abilities = { "STAND GRAB", "STAND BARRAGE", "KNIFE THROW" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "THE WORLD: TIME STOP",
		Next = nil,
		Module = "DiegoAU", -- server moves
		ClientModule = "DiegoAUVFX", -- client visuals (TuskActVFX.DiegoAUVFX)
		CardTitle = "STAND  ·  THE WORLD",
		Buffs = {
			{ Slot = 2, Attribute = "WorldBarrageUntil", Text = "MUDA" },
		},
	},
}

-- Which character an Act belongs to ("Johnny" for Tusk Acts 1-4).
function TuskActRegistry.characterOf(act)
	local info = TuskActRegistry.Acts[act]
	return info and info.Character or "Johnny"
end

-- The Act a character starts on.
TuskActRegistry.StartAct = { Johnny = 1, Gyro = 5, Diego = 6, PorkPie = 7, Sandman = 8, MountainTim = 9, HotPants = 10, Blackmore = 11, Axl = 12, Valentine = 13, DiegoAU = 14 }

function TuskActRegistry.get(act)
	return TuskActRegistry.Acts[act]
end

function TuskActRegistry.isImplemented(act)
	local info = TuskActRegistry.Acts[act]
	return info ~= nil and info.Implemented == true
end

return TuskActRegistry
end
end
