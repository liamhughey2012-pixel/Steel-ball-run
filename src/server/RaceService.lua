--[[
	RaceService  (ServerScriptService.SpinServer.RaceService)

	THE STEEL BALL RUN: a horse race round the map, every 10 minutes.
	  * ENTRY: every Race.Every seconds entry opens for EntryTime seconds.
	    Everyone gets a banner with a JOIN button (or walk up to the start
	    gate and press E). The course gates go up round the map.
	  * START: everyone who entered is put on a horse on the start line
	    (a random coat), held there for the countdown: 3, 2, 1, GO!
	  * THE RACE: ride through the numbered gates in order to the FINISH.
	    Horses are fast (Race.HorseSpeed); everything else works as normal,
	    so you can fight, dash, block and use your Stand while you ride.
	    Going down puts you out of the race.
	  * PRIZES: Cash for the top 3 (and a little for every finisher), and a
	    Saint's Corpse part appears at the finish for the winner (if one is
	    lying out in the desert). It ends when everyone's finished, FinishGrace
	    seconds after the winner, or at TimeLimit.
	Clients draw the HUD, the next-gate beacon and the gallop (RaceClient).
	ReplicatedStorage attributes for the clients:
	  SpinRacePhase ("Entry" | "Countdown" | "Racing" | nil), SpinRaceNext
	  (when entry next opens), SpinRaceEntryEnds, SpinRaceGoAt, SpinRaceStart
	Remote: Net "Race" (client: "Join" / "Leave"; server: events below).
	Numbers: TuskConfig.Race.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Net = require(Shared.Net)
local Adapter = require(script.Parent.CombatAdapter)
local HorseModel = require(script.Parent.HorseModel)

local RaceService = {}
local cfg = TuskConfig.Race or {}
local Remote
local rng = Random.new()

local phase = nil -- nil (idle) | "Entry" | "Countdown" | "Racing"
local nextEntryAt = 0
local entryEnds = 0
local raceStart = 0
local winnerAt
local racers = {} -- [player] = { Next, Finished, Place, Time }
local finishOrder = {}
local course -- { Start = Vector3, StartFacing = Vector3, Gates = { Vector3 ... } }
local courseFolder
local startPrompt

local function now()
	return workspace:GetServerTimeNow()
end

local function setAttr(k, v)
	ReplicatedStorage:SetAttribute(k, v)
end

local function origin()
	local map = workspace:FindFirstChild("SBRMap")
	return map and map:GetAttribute("Origin") or Vector3.new()
end

-- The ground under a point (ignoring characters and the course itself).
local function groundAt(position)
	local ignore = { courseFolder }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	for _, m in ipairs(CollectionService:GetTagged("SpinFighter")) do
		table.insert(ignore, m)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), params)
	return hit and hit.Position or position
end

local function send(player, kind, data)
	if Remote then
		Remote:FireClient(player, kind, data or {})
	end
end

local function broadcast(kind, data)
	if Remote then
		Remote:FireAllClients(kind, data or {})
	end
end

local function pay(player, amount)
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	if cash and amount > 0 then
		cash.Value = cash.Value + amount
	end
end

---------------------------------------------------------------------------
-- The course: numbered gates round the map, a start gate with the entry prompt
---------------------------------------------------------------------------
local WOOD = Color3.fromRGB(112, 74, 44)
local RED = Color3.fromRGB(176, 40, 36)
local CREAM = Color3.fromRGB(240, 228, 200)

local function block(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function bannerText(part, text, color, bg)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		gui.LightInfluence = 0.4
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = bg
		label.BackgroundTransparency = 0
		label.Font = Enum.Font.Bangers
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.5
		label.Parent = gui
		gui.Parent = part
	end
end

-- A gate across the course at `position`, facing along `facing`.
local function buildGate(parent, position, facing, text, kind)
	local width = cfg.GateWidth or 30
	local ground = groundAt(position)
	local cf = CFrame.lookAt(ground, ground + Vector3.new(facing.X, 0, facing.Z))
	local gate = Instance.new("Model")
	gate.Name = "Gate_" .. text
	local postColor = kind == "Finish" and Color3.fromRGB(30, 30, 30) or WOOD
	for _, side in ipairs({ -1, 1 }) do
		block(gate, "Post", Vector3.new(1.2, 16, 1.2), cf * CFrame.new(side * width / 2, 8, 0), postColor)
		block(gate, "PostCap", Vector3.new(1.8, 0.6, 1.8), cf * CFrame.new(side * width / 2, 16.2, 0), RED)
		-- A pennant on each post.
		block(gate, "Pennant", Vector3.new(0.1, 1.4, 2.4), cf * CFrame.new(side * width / 2, 17.4, 1.2), kind == "Finish" and Color3.new(1, 1, 1) or RED, Enum.Material.Fabric)
	end
	local banner = block(gate, "Banner", Vector3.new(width - 2, 3.4, 0.3), cf * CFrame.new(0, 13.5, 0), kind == "Finish" and Color3.new(1, 1, 1) or CREAM, Enum.Material.Fabric)
	if kind == "Finish" then
		-- Chequered.
		for i = 0, 13 do
			for j = 0, 1 do
				if (i + j) % 2 == 0 then
					block(gate, "Check", Vector3.new((width - 2) / 14, 1.7, 0.34), cf * CFrame.new(-(width - 2) / 2 + (i + 0.5) * (width - 2) / 14, 13.5 + (j - 0.5) * 1.7, 0), Color3.fromRGB(20, 20, 20), Enum.Material.Fabric)
				end
			end
		end
		local sign = block(gate, "Sign", Vector3.new(12, 3, 0.4), cf * CFrame.new(0, 17.2, 0), Color3.fromRGB(20, 20, 20))
		bannerText(sign, "FINISH", Color3.fromRGB(255, 220, 90), Color3.fromRGB(20, 20, 20))
	else
		bannerText(banner, text, RED, CREAM)
	end
	-- The line on the ground.
	block(gate, "Line", Vector3.new(width, 0.2, 1.2), cf * CFrame.new(0, 0.1, 0), kind == "Finish" and Color3.new(1, 1, 1) or CREAM, Enum.Material.SmoothPlastic)
	gate:SetAttribute("GateIndex", tonumber(text) or 0)
	gate.Parent = parent
	return gate, ground
end

local function buildCourse()
	if courseFolder then
		courseFolder:Destroy()
	end
	courseFolder = Instance.new("Folder")
	courseFolder.Name = "SteelBallRunCourse"
	courseFolder.Parent = workspace
	local o = origin()
	local start = groundAt(o + (cfg.Start or Vector3.new(25, 0, 112)))
	local gates = {}
	local points = { start }
	for _, offset in ipairs(cfg.Checkpoints or {}) do
		table.insert(points, groundAt(o + offset))
	end
	for i = 2, #points do
		local from, to = points[i - 1], points[i]
		local facing = (to - from)
		local isFinish = i == #points
		local _, ground = buildGate(courseFolder, to, facing, isFinish and "FINISH" or tostring(i - 1), isFinish and "Finish" or "Gate")
		table.insert(gates, ground)
	end
	-- The start gate: STEEL BALL RUN, with the entry prompt on a post.
	local startFacing = (points[2] or (start + Vector3.new(0, 0, -1))) - start
	local startGate = buildGate(courseFolder, start, startFacing, "STEEL BALL RUN", "Start")
	startGate.Name = "StartGate"
	local post = startGate:FindFirstChild("Post")
	startPrompt = Instance.new("ProximityPrompt")
	startPrompt.ActionText = "Enter the Race"
	startPrompt.ObjectText = "STEEL BALL RUN"
	startPrompt.HoldDuration = 0
	startPrompt.MaxActivationDistance = 14
	startPrompt.RequiresLineOfSight = false
	startPrompt.Enabled = phase == "Entry"
	startPrompt.Parent = post
	startPrompt.Triggered:Connect(function(player)
		RaceService.join(player)
	end)
	course = { Start = start, StartFacing = Vector3.new(startFacing.X, 0, startFacing.Z).Unit, Gates = gates }
	return course
end

---------------------------------------------------------------------------
-- Horses
---------------------------------------------------------------------------
local function mount(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 or character:FindFirstChild("RaceHorse") then
		return
	end
	local coats = cfg.Coats or {}
	local coat = coats[rng:NextInteger(1, math.max(#coats, 1))] or {}
	local horse = HorseModel.build(coat[1], coat[2])
	horse.Name = "RaceHorse"
	local raise = cfg.HipRaise or 2.8
	character:SetAttribute("RaceHipBase", humanoid.HipHeight)
	humanoid.HipHeight = humanoid.HipHeight + raise
	-- Hooves on the ground under the raised rider.
	local groundBelowRoot = humanoid.HipHeight + root.Size.Y / 2
	local body = horse.PrimaryPart
	local w = Instance.new("Weld")
	w.Name = "HorseWeld"
	w.Part0 = root
	w.Part1 = body
	w.C0 = CFrame.new(0, HorseModel.HoofDepth - groundBelowRoot, -0.4)
	w.Parent = body
	body.CFrame = root.CFrame * w.C0
	horse.Parent = character
	CollectionService:AddTag(horse, "SpinHorse")
	Adapter.setMoveModifier(humanoid, "Horse", cfg.HorseSpeed or 3.2)
	character:SetAttribute("Riding", true)
end

local function dismount(player)
	local character = player and player.Character
	if not character then
		return
	end
	local horse = character:FindFirstChild("RaceHorse")
	if horse then
		horse:Destroy()
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local base = character:GetAttribute("RaceHipBase")
		if base then
			humanoid.HipHeight = base
		end
		Adapter.setMoveModifier(humanoid, "Horse", nil)
	end
	character:SetAttribute("RaceHipBase", nil)
	character:SetAttribute("Riding", nil)
end
RaceService.dismount = dismount

---------------------------------------------------------------------------
-- Entry, start, race, results
---------------------------------------------------------------------------
local function racerCount()
	local n = 0
	for _ in pairs(racers) do
		n = n + 1
	end
	return n
end

function RaceService.join(player)
	if phase ~= "Entry" or racers[player] then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	racers[player] = { Next = 1 }
	player:SetAttribute("RaceEntered", true)
	send(player, "Joined", { Ends = entryEnds })
	broadcast("Entrants", { Count = racerCount() })
end

local function out(player, reason)
	local r = racers[player]
	if not r then
		return
	end
	racers[player] = nil
	player:SetAttribute("RaceEntered", nil)
	dismount(player)
	send(player, "Out", { Reason = reason })
	broadcast("Entrants", { Count = racerCount() })
end

function RaceService.leave(player)
	if phase == "Entry" then
		out(player, "You left the race.")
	elseif racers[player] and not racers[player].Finished then
		out(player, "You pulled out of the race.")
	end
end

local function openEntry()
	phase = "Entry"
	racers, finishOrder, winnerAt = {}, {}, nil
	buildCourse()
	entryEnds = now() + (cfg.EntryTime or 45)
	nextEntryAt = now() + (cfg.Every or 600)
	if startPrompt then
		startPrompt.Enabled = true
	end
	setAttr("SpinRacePhase", "Entry")
	setAttr("SpinRaceEntryEnds", entryEnds)
	setAttr("SpinRaceNext", nextEntryAt)
	broadcast("EntryOpen", { Ends = entryEnds })
end

local function cleanup()
	for player in pairs(racers) do
		player:SetAttribute("RaceEntered", nil)
		dismount(player)
	end
	racers, finishOrder, winnerAt = {}, {}, nil
	phase = nil
	setAttr("SpinRacePhase", nil)
	setAttr("SpinRaceGoAt", nil)
	setAttr("SpinRaceStart", nil)
	if courseFolder then
		courseFolder:Destroy()
		courseFolder = nil
	end
	startPrompt = nil
end

local function startRace()
	if startPrompt then
		startPrompt.Enabled = false
	end
	-- Only riders still alive and in the game.
	for player in pairs(racers) do
		local h = player.Parent and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not h or h.Health <= 0 then
			racers[player] = nil
			player:SetAttribute("RaceEntered", nil)
		end
	end
	if racerCount() == 0 then
		broadcast("Cancelled", { Reason = "Nobody entered the Steel Ball Run this time." })
		cleanup()
		return
	end
	phase = "Countdown"
	setAttr("SpinRacePhase", "Countdown")
	local goAt = now() + (cfg.Countdown or 4)
	setAttr("SpinRaceGoAt", goAt)
	-- Line them up behind the start gate, side by side, and put them on horses.
	local list = {}
	for player in pairs(racers) do
		table.insert(list, player)
	end
	local facing = course.StartFacing
	local right = facing:Cross(Vector3.new(0, 1, 0)).Unit
	local perRow = 6
	for i, player in ipairs(list) do
		local col = (i - 1) % perRow
		local row = math.floor((i - 1) / perRow)
		local spot = course.Start - facing * (6 + row * 8) + right * ((col - (math.min(#list, perRow) - 1) / 2) * 5)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local at = groundAt(spot) + Vector3.new(0, 7, 0)
			character:PivotTo(CFrame.lookAt(at, at + facing))
			mount(player)
			root.Anchored = true
		end
	end
	broadcast("Countdown", { GoAt = goAt, Riders = #list, Total = #course.Gates })
	task.delay(cfg.Countdown or 4, function()
		if phase ~= "Countdown" then
			return
		end
		phase = "Racing"
		raceStart = now()
		setAttr("SpinRacePhase", "Racing")
		setAttr("SpinRaceStart", raceStart)
		for player in pairs(racers) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				root.Anchored = false
			end
		end
		broadcast("Go", { Total = #course.Gates })
	end)
end

local function endRace(reason)
	local results = {}
	for _, player in ipairs(finishOrder) do
		local r = racers[player]
		table.insert(results, { Name = player.DisplayName, Place = r and r.Place, Time = r and r.Time })
	end
	broadcast("Results", { List = results, Reason = reason })
	cleanup()
end

local function finish(player, r)
	table.insert(finishOrder, player)
	r.Finished = true
	r.Place = #finishOrder
	r.Time = now() - raceStart
	local prizes = cfg.Prizes or { 500, 250, 150 }
	local prize = prizes[r.Place] or cfg.FinishPrize or 50
	pay(player, prize)
	local partName
	if r.Place == 1 then
		winnerAt = now()
		-- A Saint's Corpse part appears at the finish for the winner.
		if cfg.WinnerCorpsePart ~= false then
			local ok, C = pcall(function()
				return require(script.Parent.CorpseService)
			end)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if ok and C and C.summon and root then
				local _, name = C.summon(root.Position + course.StartFacing * 6)
				partName = name
			end
		end
	end
	broadcast("Finished", { Name = player.DisplayName, UserId = player.UserId, Place = r.Place, Time = r.Time, Prize = prize, Part = partName })
	-- Off the horse a moment after crossing the line.
	task.delay(2.5, function()
		if racers[player] == r then
			dismount(player)
		end
	end)
end

local function standings()
	local list = {}
	for player, r in pairs(racers) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local gate = course.Gates[r.Next]
		local dist = (root and gate) and (Vector3.new(gate.X, 0, gate.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude or 1e6
		table.insert(list, { Player = player, Name = player.DisplayName, UserId = player.UserId, Next = r.Next, Place = r.Place, Dist = dist })
	end
	table.sort(list, function(a, b)
		if a.Place or b.Place then
			return (a.Place or 1e6) < (b.Place or 1e6)
		end
		if a.Next ~= b.Next then
			return a.Next > b.Next
		end
		return a.Dist < b.Dist
	end)
	local rows = {}
	for i, e in ipairs(list) do
		table.insert(rows, { Name = e.Name, UserId = e.UserId, Position = i, Next = e.Next, Finished = e.Place ~= nil, Dist = math.floor(e.Dist) })
	end
	return rows
end

local lastStandings = 0
local function tick()
	local t = now()
	if not phase then
		if t >= nextEntryAt then
			openEntry()
		end
		return
	end
	if phase == "Entry" then
		if t >= entryEnds then
			startRace()
		end
		return
	end
	if phase ~= "Racing" then
		return
	end
	local total = #course.Gates
	local active = 0
	for player, r in pairs(racers) do
		if not r.Finished then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local gate = course.Gates[r.Next]
			if root and gate then
				active = active + 1
				local d = (Vector3.new(gate.X, 0, gate.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
				if d <= (cfg.PassRadius or 20) and math.abs(root.Position.Y - gate.Y) < 40 then
					r.Next = r.Next + 1
					if r.Next > total then
						finish(player, r)
					else
						send(player, "Gate", { Index = r.Next - 1, Total = total })
					end
				end
			end
		end
	end
	if t - lastStandings >= 0.5 then
		lastStandings = t
		local list = standings()
		for player in pairs(racers) do
			send(player, "Standings", { List = list, Total = total, Elapsed = t - raceStart })
		end
	end
	if active == 0 then
		endRace(#finishOrder > 0 and "Everyone's crossed the line." or "Nobody finished.")
	elseif winnerAt and t - winnerAt >= (cfg.FinishGrace or 25) then
		endRace("Time's up for the stragglers.")
	elseif t - raceStart >= (cfg.TimeLimit or 240) then
		endRace("Time's up.")
	end
end

local function watchPlayer(player)
	player.CharacterAdded:Connect(function()
		-- A new character means the old one went down (or reset): out of the race.
		if racers[player] and phase ~= "Entry" then
			racers[player] = nil
			player:SetAttribute("RaceEntered", nil)
			send(player, "Out", { Reason = "You went down: out of the race." })
		end
	end)
end

function RaceService.init()
	if cfg.Enabled == false then
		return
	end
	Remote = Net.get("Race")
	local first = RunService:IsStudio() and (cfg.StudioFirstAfter or 20) or (cfg.FirstAfter or 120)
	nextEntryAt = now() + first
	setAttr("SpinRaceNext", nextEntryAt)
	Remote.OnServerEvent:Connect(function(player, action)
		if action == "Join" then
			RaceService.join(player)
		elseif action == "Leave" then
			RaceService.leave(player)
		end
	end)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		watchPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		racers[player] = nil
	end)
	-- Going down puts you out of the race (the horse goes with the body).
	local function watchDeath(player, character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				if racers[player] and phase ~= "Entry" and not racers[player].Finished then
					out(player, "You went down: out of the race.")
				end
			end)
		end
	end
	local function hook(player)
		player.CharacterAdded:Connect(function(c)
			task.spawn(watchDeath, player, c)
		end)
		if player.Character then
			task.spawn(watchDeath, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc >= 0.1 then
			acc = 0
			tick()
		end
	end)
end

-- For tests / admin: open entry right now.
function RaceService.openNow()
	if not phase then
		openEntry()
	end
end

return RaceService
