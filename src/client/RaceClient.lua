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

local Shared = ReplicatedStorage:WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)
local CameraFX = require(script.Parent.CameraFX)
local TuskAnimation = require(script.Parent.TuskAnimation)

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
