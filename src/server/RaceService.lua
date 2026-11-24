--[[
	RaceService  (ServerScriptService.SpinServer.RaceService)

	THE STEEL BALL RUN: a horse race round the map, every 10 minutes, and
	your own horse (M) to ride anywhere the rest of the time.
	  * ENTRY: every Race.Every seconds entry opens for EntryTime seconds.
	    Everyone gets a banner with a JOIN button (or press E at the
	    starting grid). The numbered gates go up round the course.
	  * START: riders line up 4 abreast inside the map's fenced race track,
	    behind its START arch, on their own horse (coat and blanket from the
	    STABLE) with its hooves on the ground, held for the countdown.
	    NPC JOCKEYS (Race.NPCRacers) line up with them.
	  * THE RACE is run in STAGES like the real Steel Ball Run (TuskConfig.
	    Race.Stages): 1 San Diego Beach, 2 Arizona Desert, 3 Rocky Mountains,
	    4 Great Plains, 5 Mississippi River, 6 Lake Michigan, 7 Philadelphia,
	    8 New Jersey, 9 New York. Each stage is its own race: everyone lines
	    up where the last stage ended, 3-2-1-GO, ride its gates in order to
	    its finish. Placings score points (StagePoints); after the last stage
	    the most points wins (ties: less total time). Between stages there's
	    a short rest with the stage results and the overall points. You can fight, dash, block and use your Stand on horseback.
	    Going down puts you out. Jockeys find their way with pathfinding (and
	    hop free if they get stuck).
	  * GALLOP (hold Shift): faster, but it uses your horse's stamina; run
	    it dry and the horse is WINDED for a while. CARROT crates on each
	    leg refill stamina (with a burst of speed). LOG HURDLES across the
	    course: jump them or stumble. Lost? H takes you back to your last
	    gate (held a few seconds). Every rider shows on a progress strip.
	  * RECORDS: split times at each gate; your best time and wins are
	    saved (player attributes RaceBest / RaceWins, saved by DataService)
	  * PRIZES: Cash for the top 3 players (and a little for every
	    finisher); a Saint's Corpse part appears at the finish for a winning
	    player. Finishers keep their horse to ride on.
	  * YOUR HORSE (M): call it, ride it anywhere, press M again to get off
	    (not during a race you're in; the race gives you yours).
	The rider sits exactly on the saddle: the horse is welded under their
	root with its hooves on the ground, and every client lifts the rider's
	body up onto the saddle (RideLift). HipHeight is never changed (that let
	Roblox's own HipHeight resets send horses floating off).
	Clients: RaceClient (HUD, beacon, gallop, M key). ReplicatedStorage
	attributes: SpinRacePhase, SpinRaceNext, SpinRaceEntryEnds, SpinRaceGoAt,
	SpinRaceStart. Remote: Net "Race" (client: "Join" / "Leave" / "Horse").
	Numbers: TuskConfig.Race and TuskConfig.Horses.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local PlayersService = Players

local Shared = ReplicatedStorage:WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Net = require(Shared.Net)
local Adapter = require(script.Parent.CombatAdapter)
local HorseModel = require(Shared.HorseModel)
local PathfindingService = game:GetService("PathfindingService")

local RaceService = {}
local cfg = TuskConfig.Race or {}
local Remote
local rng = Random.new()

local phase = nil -- nil (idle) | "Entry" | "Countdown" | "Racing" | "Rest" (between stages)
local stageIndex = 0
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
	for _, r in pairs(racers) do
		if r.Model then
			table.insert(ignore, r.Model)
		end
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
		bannerText(sign, text, Color3.fromRGB(255, 220, 90), Color3.fromRGB(20, 20, 20))
	else
		bannerText(banner, text, RED, CREAM)
	end
	-- The line on the ground.
	block(gate, "Line", Vector3.new(width, 0.2, 1.2), cf * CFrame.new(0, 0.1, 0), kind == "Finish" and Color3.new(1, 1, 1) or CREAM, Enum.Material.SmoothPlastic)
	gate:SetAttribute("GateIndex", tonumber(text) or 0)
	gate.Parent = parent
	return gate, ground
end

-- The course gates (the start is the map's own fenced track and arch).
local function stageCount()
	return cfg.Stages and #cfg.Stages or 1
end

local function buildCourse(stage)
	stage = stage or 1
	if courseFolder then
		courseFolder:Destroy()
	end
	courseFolder = Instance.new("Folder")
	courseFolder.Name = "SteelBallRunCourse"
	courseFolder.Parent = workspace
	local o = origin()
	local st = cfg.Stages and cfg.Stages[stage]
	local start = groundAt(o + (st and st.Start or cfg.Start or Vector3.new(0, 0, 118)))
	local offsets = st and st.Gates or cfg.Checkpoints or {}
	local facing
	if st and offsets[1] then
		facing = (o + offsets[1]) - start
	else
		facing = cfg.StartFacing or Vector3.new(0, 0, -1)
	end
	facing = Vector3.new(facing.X, 0, facing.Z).Unit
	local gates = {}
	local points = { start }
	for _, offset in ipairs(offsets) do
		table.insert(points, groundAt(o + offset))
	end
	local lastStage = stage >= stageCount()
	for i = 2, #points do
		local isFinish = i == #points
		local finishText = lastStage and "FINISH" or ("STAGE " .. stage)
		local _, ground = buildGate(courseFolder, points[i], points[i] - points[i - 1], isFinish and finishText or tostring(i - 1), isFinish and "Finish" or "Gate")
		table.insert(gates, ground)
	end
	-- The starting grid: a painted line across the track, and the entry
	-- prompt on an invisible marker in the middle of it (nothing to bump into).
	local right = facing:Cross(Vector3.new(0, 1, 0)).Unit
	local lineCf = CFrame.lookAt(start, start + facing)
	block(courseFolder, "StartLine", Vector3.new(24, 0.2, 0.8), lineCf * CFrame.new(0, 0.1, 0), CREAM, Enum.Material.SmoothPlastic)
	local marker = block(courseFolder, "EntryMarker", Vector3.new(4, 4, 4), lineCf * CFrame.new(0, 3, 8), CREAM)
	marker.Transparency = 1
	startPrompt = Instance.new("ProximityPrompt")
	startPrompt.ActionText = "Enter the Race"
	startPrompt.ObjectText = "STEEL BALL RUN"
	startPrompt.HoldDuration = 0
	startPrompt.MaxActivationDistance = 16
	startPrompt.RequiresLineOfSight = false
	startPrompt.Enabled = phase == "Entry"
	startPrompt.Parent = marker
	startPrompt.Triggered:Connect(function(player)
		RaceService.join(player)
	end)
	course = { Start = start, StartFacing = facing, Right = right, Gates = gates, Stage = stage, StageName = st and st.Name or "THE STEEL BALL RUN", Tagline = st and st.Tagline }
	RaceService.buildExtras(points)
	return course
end

---------------------------------------------------------------------------
-- Horses (players' own, race horses, jockeys')
---------------------------------------------------------------------------
local hcfg = TuskConfig.Horses or {}

local function catalogue(list, id)
	for _, item in ipairs(list or {}) do
		if item.Id == id then
			return item
		end
	end
	return (list or {})[1]
end

-- The horse a player set up in the stable (the same look the shop previews).
local function lookFor(player)
	local body, mane, opts = HorseModel.lookFrom(hcfg, HorseModel.selectionOf(player))
	return { Body = body, Mane = mane, Opts = opts, Name = player and player:GetAttribute("HorseName") }
end

local function randomLook()
	local coats = cfg.Coats or {}
	local c = coats[rng:NextInteger(1, math.max(#coats, 1))] or {}
	local blankets = hcfg.Blankets or {}
	local b = blankets[rng:NextInteger(1, math.max(#blankets, 1))]
	return { Body = c[1], Mane = c[2], Blanket = b and b.Color, Width = 1.9 }
end

-- Where the rider's seat is (the bottom of their hips), relative to the root,
-- in the rest pose: read from the root joint's C0 / C1 (positions replicated
-- from a player's client include their animation, e.g. the ride lift).
local function seatHeight(character, root)
	local hips = character:FindFirstChild("LowerTorso")
	local joint = hips and hips:FindFirstChild("Root")
	if not hips then
		local torso = character:FindFirstChild("Torso")
		hips = torso
		joint = root:FindFirstChild("RootJoint")
	end
	if hips and joint and joint:IsA("Motor6D") then
		local rest = joint.C0 * joint.C1:Inverse()
		return rest.Position.Y - hips.Size.Y / 2
	end
	if hips then
		return (root.CFrame:Inverse() * hips.Position).Y - hips.Size.Y / 2
	end
	return -1
end

-- Place the horse under a rider: welded to their root with its hooves on the
-- ground at the rider's normal height. The rider's HipHeight is NEVER
-- changed (Roblox can reset it, which made horses float away); instead the
-- clients lift the rider's body onto the saddle (RideLift, TuskAnimation).
-- Re-fitted whenever HipHeight changes.
local function fitHorse(character)
	local horse = character and character:FindFirstChild("RaceHorse")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local body = horse and horse.PrimaryPart
	local w = body and body:FindFirstChild("HorseWeld")
	if not w or not humanoid or not root then
		return
	end
	local bodyY = HorseModel.HoofDepth - (humanoid.HipHeight + root.Size.Y / 2)
	w.C0 = CFrame.new(0, bodyY, -0.4)
	horse:SetAttribute("BodyY", bodyY)
	local seat = character:GetAttribute("RideSeat") or -0.25
	character:SetAttribute("RideLift", math.max(0, bodyY + HorseModel.SaddleTop - seat))
end

local function mount(character, look, speed, kind)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local old = character:FindFirstChild("RaceHorse")
	if old then
		old:Destroy()
	end
	-- (An older version raised HipHeight: put it back if it's still raised.)
	local oldBase = character:GetAttribute("RaceHipBase")
	if oldBase then
		humanoid.HipHeight = oldBase
		character:SetAttribute("RaceHipBase", nil)
	end
	look = look or {}
	local horse = HorseModel.build(look.Body, look.Mane, look.Opts or { Width = look.Width or 1.9, Blanket = look.Blanket, Socks = look.Socks, Material = look.Material })
	horse.Name = "RaceHorse"
	if look.Name then
		horse:SetAttribute("HorseName", look.Name)
	end
	for _, d in ipairs(horse:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	character:SetAttribute("RideSeat", seatHeight(character, root))
	local body = horse.PrimaryPart
	local w = Instance.new("Weld")
	w.Name = "HorseWeld"
	w.Part0 = root
	w.Part1 = body
	w.Parent = body
	horse.Parent = character
	fitHorse(character)
	body.CFrame = root.CFrame * w.C0
	if not character:GetAttribute("HorseFitHooked") then
		character:SetAttribute("HorseFitHooked", true)
		humanoid:GetPropertyChangedSignal("HipHeight"):Connect(function()
			fitHorse(character)
		end)
	end
	CollectionService:AddTag(horse, "SpinHorse")
	Adapter.setMoveModifier(humanoid, "Horse", speed or 3)
	character:SetAttribute("Riding", kind or "Ride")
	return horse
end

local function dismount(character)
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
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and character:GetAttribute("RaceAnchored") then
		root.Anchored = false
	end
	character:SetAttribute("RaceAnchored", nil)
	character:SetAttribute("RaceHipBase", nil)
	character:SetAttribute("Riding", nil)
	character:SetAttribute("RideLift", nil)
end
RaceService.dismount = dismount

-- Put a (mounted) character standing on the ground at `position`, facing `facing`.
local function standAt(character, position, facing)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	local ground = groundAt(position)
	local at = ground + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 + 0.05, 0)
	character:PivotTo(CFrame.lookAt(at, at + facing))
end

-- M: call your horse / send it away.
function RaceService.toggleHorse(player)
	if hcfg.Enabled == false then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local r = racers[player]
	if r and not r.Finished and (phase == "Countdown" or phase == "Racing") then
		send(player, "Denied", { Reason = "You're racing!" })
		return
	end
	local t = now()
	if (player:GetAttribute("HorseReadyAt") or 0) > t then
		return
	end
	player:SetAttribute("HorseReadyAt", t + (hcfg.Cooldown or 2))
	if character:FindFirstChild("RaceHorse") then
		dismount(character)
		send(player, "Horse", { Riding = false })
	else
		if not Adapter.canAct(player) then
			return
		end
		mount(character, lookFor(player), hcfg.RideSpeed or 2.8, "Ride")
		send(player, "Horse", { Riding = true })
	end
end

-- The stable changed: re-saddle anyone riding their own horse.
function RaceService.refreshHorse(player)
	local character = player.Character
	if character and character:FindFirstChild("RaceHorse") then
		local kind = character:GetAttribute("Riding")
		mount(character, lookFor(player), kind == "Race" and (cfg.HorseSpeed or 3.2) or (hcfg.RideSpeed or 2.8), kind)
	end
end

---------------------------------------------------------------------------
-- Racers: players and NPC jockeys. racers[key] = r, where key is the Player
-- (or the jockey's record) and r = { Player?, Jockey?, Name, UserId, Next,
-- Finished, Place, Time }.
---------------------------------------------------------------------------
local function charOf(r)
	return r.Player and r.Player.Character or r.Model
end

local function racerCount(playersOnly)
	local n = 0
	for _, r in pairs(racers) do
		if not playersOnly or r.Player then
			n = n + 1
		end
	end
	return n
end

---------------------------------------------------------------------------
-- Race extras: carrots, hurdles, stamina, records
---------------------------------------------------------------------------
local gcfg = cfg.Gallop or {}
local ccfg = cfg.Carrots or {}
local hucfg = cfg.Hurdles or {}
local ORANGE = Color3.fromRGB(236, 120, 30)
local LEAF = Color3.fromRGB(80, 160, 60)
local HAY = Color3.fromRGB(214, 184, 100)

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- A crate of carrots: a hay bale with carrots sticking out.
local function buildCarrots(parent, at)
	local m = Instance.new("Model")
	m.Name = "Carrots"
	local cf = CFrame.new(at + Vector3.new(0, 1, 0))
	local parts = {}
	table.insert(parts, block(m, "Bale", Vector3.new(4, 2, 3), cf, HAY, Enum.Material.Fabric))
	for k = -1, 1 do
		local c = block(m, "Carrot", Vector3.new(2.4, 0.5, 0.5), cf * CFrame.new(k * 1.1, 1.4, 0) * CFrame.Angles(0, 0, math.rad(80 + k * 10)), ORANGE, Enum.Material.SmoothPlastic)
		c.Shape = Enum.PartType.Cylinder
		table.insert(parts, c)
		table.insert(parts, block(m, "Leaf", Vector3.new(0.3, 0.9, 0.6), cf * CFrame.new(k * 1.25, 2.75, 0), LEAF, Enum.Material.Grass))
	end
	local glow = Instance.new("PointLight")
	glow.Color = ORANGE
	glow.Range = 10
	glow.Brightness = 1
	glow.Parent = parts[1]
	m.Parent = parent
	CollectionService:AddTag(m, "SpinCarrots")
	return m, parts
end

-- A log hurdle across the course: two posts, a log, a little flag each side.
local function buildHurdle(parent, at, dir)
	local m = Instance.new("Model")
	m.Name = "Hurdle"
	local right = dir:Cross(Vector3.new(0, 1, 0)).Unit
	local cf = CFrame.lookAt(at, at + dir)
	local w = hucfg.Width or 30
	local log = block(m, "Log", Vector3.new(w, 1.1, 1.1), cf * CFrame.new(0, 2.3, 0), Color3.fromRGB(120, 80, 46), Enum.Material.Wood)
	log.Shape = Enum.PartType.Cylinder
	log.CFrame = cf * CFrame.new(0, 2.3, 0)
	for _, side in ipairs({ -1, 1 }) do
		block(m, "Post", Vector3.new(0.6, 3.2, 0.6), cf * CFrame.new(side * w / 2, 1.6, 0), WOOD, Enum.Material.Wood)
		block(m, "Flag", Vector3.new(0.1, 1.2, 1.6), cf * CFrame.new(side * w / 2, 3.6, 0.8), RED, Enum.Material.Fabric)
	end
	for k = -2, 2 do
		block(m, "Brush", Vector3.new(w / 5 - 0.5, 0.9, 1.4), cf * CFrame.new(k * w / 5, 0.45, 0), Color3.fromRGB(110, 120, 60), Enum.Material.Grass)
	end
	m:SetAttribute("Width", w)
	m:SetAttribute("Facing", dir)
	m.Parent = parent
	CollectionService:AddTag(m, "SpinHurdle")
	return m, right
end

function RaceService.buildExtras(points)
	course.Points = points
	course.LegLength = {}
	course.Carrots = {}
	course.Hurdles = {}
	course.StageLength = 0
	for i = 2, #points do
		course.StageLength = course.StageLength + flat(points[i] - points[i - 1]).Magnitude
		local a, b = points[i - 1], points[i]
		local len = flat(b - a).Magnitude
		course.LegLength[i - 1] = math.max(len, 1)
		local dir = len > 0.1 and flat(b - a).Unit or course.StartFacing
		local right = dir:Cross(Vector3.new(0, 1, 0)).Unit
		-- Carrots, a little off the line, alternating sides.
		for k = 1, ccfg.PerLeg or 1 do
			local t = (k / ((ccfg.PerLeg or 1) + 1)) * 0.6 + 0.3
			local at = groundAt(a + (b - a) * t + right * ((i % 2 == 0) and 7 or -7))
			local model, parts = buildCarrots(courseFolder, at)
			table.insert(course.Carrots, { Pos = at, Model = model, Parts = parts, ReadyAt = 0 })
		end
		-- A hurdle on every other long leg (never on the first: the start's crowded).
		if i > 2 and (i % (hucfg.Every or 2) == 0) and len >= (hucfg.MinLeg or 70) then
			local at = groundAt(a + (b - a) * 0.5)
			local model = buildHurdle(courseFolder, at, dir)
			table.insert(course.Hurdles, { Pos = at, Dir = dir, Right = right, Half = (hucfg.Width or 30) / 2, Model = model, Leg = i - 1 })
		end
	end
end

local function humanoidOf(r)
	local c = charOf(r)
	return c and c:FindFirstChildOfClass("Humanoid"), c
end

local function setMod(r, key, mult)
	local hum = humanoidOf(r)
	if hum then
		Adapter.setMoveModifier(hum, key, mult)
	end
end

-- Everything the race put on a rider (speed changes, stamina) comes off.
local function clearExtras(r)
	setMod(r, "Gallop", nil)
	setMod(r, "Stumble", nil)
	setMod(r, "Carrot", nil)
	setMod(r, "CatchUp", nil)
	local c = charOf(r)
	if c then
		c:SetAttribute("HorseStamina", nil)
		c:SetAttribute("HorseWinded", nil)
		c:SetAttribute("Galloping", nil)
	end
end
RaceService.clearExtras = clearExtras

local function initRacer(r)
	r.Stamina = 100
	r.Winded = false
	r.Galloping = false
	r.RestAt = 0
	r.Splits = {}
	r.LastPos = nil
	r.JumpPlan = {}
	r.NextReturn = 0
end

-- Hold / let go of gallop (players: from the client; jockeys: their AI).
function RaceService.setGallop(player, on)
	local r = racers[player]
	if r and phase == "Racing" and not r.Finished then
		r.Galloping = on == true
	end
end

-- H: back to the last gate you passed, held there a few seconds.
function RaceService.returnToGate(player)
	local r = racers[player]
	if not r or phase ~= "Racing" or r.Finished or now() < (r.NextReturn or 0) then
		return
	end
	local character = charOf(r)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	r.NextReturn = now() + (cfg.ReturnCooldown or 8)
	local lastIndex = r.Next - 1
	local from = lastIndex >= 1 and course.Gates[lastIndex] or course.Start
	local to = course.Gates[r.Next] or from
	local facing = flat(to - from)
	facing = facing.Magnitude > 0.1 and facing.Unit or course.StartFacing
	standAt(character, from + facing * 4, facing)
	root.Anchored = true
	character:SetAttribute("RaceAnchored", true)
	r.LastPos = nil
	local penalty = cfg.ReturnPenalty or 3
	send(player, "Returned", { Gate = lastIndex, Penalty = penalty })
	task.delay(penalty, function()
		if root.Parent and character:GetAttribute("RaceAnchored") then
			root.Anchored = false
			character:SetAttribute("RaceAnchored", nil)
		end
	end)
end

-- How far round the course a rider is (0 at the start, 1 at the finish).
local function progressOf(r, dist)
	local total = #course.Gates
	if r.Finished then
		return 1
	end
	local legLen = course.LegLength and course.LegLength[r.Next] or 1
	local frac = math.clamp(1 - dist / legLen, 0, 1)
	return math.clamp(((r.Next - 1) + frac) / math.max(total, 1), 0, 1)
end

-- Stamina, gallop, carrots and hurdles for one rider (every tick, dt seconds).
local function stepRider(key, r, dt, t)
	local hum, character = humanoidOf(r)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		return
	end
	local speed = flat(root.AssemblyLinearVelocity).Magnitude
	-- Jockeys ride smart: save their horse's breath, sprint the last
	-- stretch of a stage, turn aside for carrots when tired, and dig in when
	-- they've fallen far behind.
	if r.Jockey then
		local jc = cfg.Jockey or {}
		local total = math.max(#course.Gates, 1)
		local stretch = (r.Next - 1) / total
		if stretch >= (jc.SprintFrom or 0.75) then
			r.Galloping = r.Stamina > 3 -- the final sprint: everything left
		elseif r.Galloping and r.Stamina < (jc.StopBelow or 18) then
			r.Galloping = false
		elseif not r.Galloping and r.Stamina > (jc.GallopAbove or 55) then
			r.Galloping = true
		end
		-- Tired? A carrot crate close by and roughly on the way.
		r.CarrotTarget = nil
		if r.Stamina < (jc.CarrotBelow or 55) then
			local gate = course.Gates[r.Next]
			local ahead = gate and flat(gate - root.Position)
			local best, bestD
			for _, carrot in ipairs(course.Carrots or {}) do
				if t >= carrot.ReadyAt then
					local off = flat(carrot.Pos - root.Position)
					local d = off.Magnitude
					if d <= (jc.CarrotReach or 35) and (not ahead or ahead.Magnitude < 1 or off:Dot(ahead) > 0) and (not bestD or d < bestD) then
						best, bestD = carrot, d
					end
				end
			end
			r.CarrotTarget = best and best.Pos or nil
		end
		-- Far behind the leader? Dig in.
		local lead = 0
		for _, other in pairs(racers) do
			if other ~= r and not other.Finished then
				lead = math.max(lead, other.ProgressNow or 0)
			elseif other.Finished then
				lead = 1
			end
		end
		local behind = (lead - (r.ProgressNow or 0)) * (course.StageLength or 600)
		setMod(r, "CatchUp", behind > (jc.CatchUpBehind or 110) and (jc.CatchUp or 1.08) or nil)
	end
	local galloping = r.Galloping and not r.Winded and r.Stamina > 0 and speed > 4 and not character:GetAttribute("RaceAnchored")
	if galloping then
		r.Stamina = math.max(0, r.Stamina - (gcfg.Drain or 18) * dt)
		r.RestAt = t + (gcfg.RegenDelay or 0.8)
		if r.Stamina <= 0 then
			r.Winded = true
			galloping = false
			if r.Player then
				send(r.Player, "Winded", {})
			end
		end
	elseif t >= (r.RestAt or 0) then
		r.Stamina = math.min(100, r.Stamina + (gcfg.Regen or 11) * dt)
		if r.Winded and r.Stamina >= (gcfg.WindedUntil or 40) then
			r.Winded = false
			if r.Player then
				send(r.Player, "Recovered", {})
			end
		end
	end
	setMod(r, "Gallop", galloping and (gcfg.Speed or 1.35) or nil)
	character:SetAttribute("Galloping", galloping or nil)
	character:SetAttribute("HorseStamina", math.floor(r.Stamina + 0.5))
	character:SetAttribute("HorseWinded", r.Winded or nil)
	-- Carrots.
	for _, carrot in ipairs(course.Carrots or {}) do
		if t >= carrot.ReadyAt and flat(root.Position - carrot.Pos).Magnitude <= (ccfg.Radius or 7) and math.abs(root.Position.Y - carrot.Pos.Y) < 12 then
			carrot.ReadyAt = t + (ccfg.Respawn or 10)
			for _, p in ipairs(carrot.Parts) do
				p.Transparency = 1
			end
			task.delay(ccfg.Respawn or 10, function()
				for _, p in ipairs(carrot.Parts) do
					if p.Parent then
						p.Transparency = 0
					end
				end
			end)
			r.Stamina = math.min(100, r.Stamina + (ccfg.Refill or 45))
			if r.Winded and r.Stamina >= (gcfg.WindedUntil or 40) then
				r.Winded = false
			end
			local token = {}
			r.CarrotToken = token
			setMod(r, "Carrot", ccfg.Boost or 1.2)
			task.delay(ccfg.BoostTime or 1.5, function()
				if r.CarrotToken == token then
					setMod(r, "Carrot", nil)
				end
			end)
			broadcast("Carrot", { Position = carrot.Pos, Name = r.Name })
			if r.Player then
				send(r.Player, "CarrotYou", { Stamina = math.floor(r.Stamina) })
			end
		end
	end
	-- Hurdles: did they cross one since last tick, and were they up in the air?
	local pos = root.Position
	for hi, h in ipairs(course.Hurdles or {}) do
		local along = (pos - h.Pos):Dot(h.Dir)
		local side = math.abs((pos - h.Pos):Dot(h.Right))
		-- Jockeys jump when they're close (now and then they misjudge it).
		if r.Jockey and along < -3 and along > -16 and side <= h.Half + 2 and not r.JumpPlan[hi] then
			r.JumpPlan[hi] = rng:NextNumber() < (hucfg.JockeyMiss or 0.15) and "Miss" or "Jump"
			if r.JumpPlan[hi] == "Jump" then
				hum.Jump = true
			end
		end
		if r.LastPos then
			local before = (r.LastPos - h.Pos):Dot(h.Dir)
			if before < 0 and along >= 0 and side <= h.Half then
				local height = pos.Y - h.Pos.Y
				if height < (hucfg.Clearance or 4.2) then
					r.Stamina = math.max(0, r.Stamina - (hucfg.StumbleStamina or 20))
					local token = {}
					r.StumbleToken = token
					setMod(r, "Stumble", hucfg.StumbleSlow or 0.4)
					task.delay(hucfg.StumbleTime or 1.2, function()
						if r.StumbleToken == token then
							setMod(r, "Stumble", nil)
						end
					end)
					broadcast("Stumble", { Position = h.Pos + h.Right * (pos - h.Pos):Dot(h.Right), Name = r.Name })
					if r.Player then
						send(r.Player, "StumbleYou", {})
					end
				else
					r.Stamina = math.min(100, r.Stamina + (hucfg.ClearStamina or 5))
					if r.Player then
						send(r.Player, "Cleared", {})
					end
				end
			end
		end
	end
	r.LastPos = pos
	local gate = course.Gates[r.Next]
	if gate then
		r.ProgressNow = progressOf(r, flat(gate - pos).Magnitude)
	end
end

-- Records: best time and wins, saved by DataService.
local function recordFinish(r)
	local player = r.Player
	if not player then
		return false, nil
	end
	local best = player:GetAttribute("RaceBest")
	local newRecord = typeof(best) ~= "number" or r.Time < best
	if newRecord then
		player:SetAttribute("RaceBest", math.floor(r.Time * 10 + 0.5) / 10)
	end
	if r.Place == 1 then
		player:SetAttribute("RaceWins", (player:GetAttribute("RaceWins") or 0) + 1)
	end
	return newRecord, best
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
	racers[player] = { Player = player, Name = player.DisplayName, UserId = player.UserId, Next = 1 }
	initRacer(racers[player])
	player:SetAttribute("RaceEntered", true)
	send(player, "Joined", { Ends = entryEnds })
	broadcast("Entrants", { Count = racerCount(true) })
end

local function out(key, reason)
	local r = racers[key]
	if not r then
		return
	end
	racers[key] = nil
	clearExtras(r)
	if r.Player then
		r.Player:SetAttribute("RaceEntered", nil)
		dismount(r.Player.Character)
		send(r.Player, "Out", { Reason = reason })
		broadcast("Entrants", { Count = racerCount(true) })
	elseif r.Model then
		local model = r.Model
		task.delay(3, function()
			model:Destroy()
		end)
	end
end

function RaceService.leave(player)
	local r = racers[player]
	if not r then
		return
	end
	if phase == "Entry" then
		out(player, "You left the race.")
	elseif not r.Finished then
		out(player, "You pulled out of the race.")
	end
end

---------------------------------------------------------------------------
-- NPC jockeys
---------------------------------------------------------------------------
local JOCKEY_SILKS = {
	Color3.fromRGB(200, 50, 50), Color3.fromRGB(50, 90, 200), Color3.fromRGB(240, 200, 60),
	Color3.fromRGB(60, 160, 90), Color3.fromRGB(150, 70, 170), Color3.fromRGB(240, 140, 50),
}

local function spawnJockey(index)
	local names = cfg.NPCNames or { "Jockey" }
	local name = names[((index - 1) % #names) + 1]
	local desc = Instance.new("HumanoidDescription")
	local silk = JOCKEY_SILKS[((index - 1) % #JOCKEY_SILKS) + 1]
	desc.HeadColor = Color3.fromRGB(226, 186, 150)
	desc.LeftArmColor = silk
	desc.RightArmColor = silk
	desc.TorsoColor = silk
	desc.LeftLegColor = Color3.fromRGB(235, 230, 220)
	desc.RightLegColor = Color3.fromRGB(235, 230, 220)
	local ok, model = pcall(function()
		return PlayersService:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return nil
	end
	model.Name = "Jockey: " .. name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = "Jockey: " .. name
	humanoid.MaxHealth = cfg.NPCHealth or 120
	humanoid.Health = humanoid.MaxHealth
	model:SetAttribute("RaceJockey", true)
	model.Parent = workspace
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root.SetNetworkOwner then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	local skill = cfg.NPCSkill or { 0.8, 0.95 }
	local r = { Jockey = true, Model = model, Name = "Jockey: " .. name, UserId = -500 - index, Next = 1, Skill = skill[1] + rng:NextNumber() * (skill[2] - skill[1]) }
	initRacer(r)
	humanoid.Died:Connect(function()
		for key, rr in pairs(racers) do
			if rr == r then
				out(key, "down")
			end
		end
	end)
	return r
end

-- A jockey rides the course: pathfinding to each gate, hopping free if stuck.
local function runJockey(key, r)
	local model = r.Model
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	local path
	pcall(function()
		path = PathfindingService:CreatePath({ AgentRadius = 3, AgentHeight = 9, AgentCanJump = true, WaypointSpacing = 10 })
	end)
	local waypoints, wi, forGate
	local lastPos, lastProgress = root.Position, now()
	local function step()
		if phase ~= "Racing" or racers[key] ~= r or r.Finished or humanoid.Health <= 0 or not model.Parent then
			return
		end
		local gate = course.Gates[r.Next]
		if not gate then
			return
		end
		if forGate ~= r.Next then
			forGate = r.Next
			waypoints, wi = nil, 1
			if path then
				local ok = pcall(function()
					path:ComputeAsync(root.Position, gate)
				end)
				if ok and path.Status == Enum.PathStatus.Success then
					waypoints, wi = path:GetWaypoints(), 2
				end
			end
		end
		local target = gate
		if r.CarrotTarget then
			-- Off the line for a carrot crate.
			humanoid:MoveTo(r.CarrotTarget)
			task.delay(0.25, step)
			return
		end
		if waypoints and waypoints[wi] then
			target = waypoints[wi].Position
			local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
			if flat.Magnitude < 7 then
				if waypoints[wi].Action == Enum.PathWaypointAction.Jump then
					humanoid.Jump = true
				end
				wi = wi + 1
				target = waypoints[wi] and waypoints[wi].Position or gate
			end
		end
		humanoid:MoveTo(target)
		-- Stuck? Jump; still stuck? Hop free towards the gate.
		if (root.Position - lastPos).Magnitude > 4 then
			lastPos, lastProgress = root.Position, now()
		elseif now() - lastProgress > 1.5 then
			humanoid.Jump = true
			if now() - lastProgress > 3.5 then
				local dir = Vector3.new(gate.X - root.Position.X, 0, gate.Z - root.Position.Z)
				dir = dir.Magnitude > 0.1 and dir.Unit or course.StartFacing
				standAt(model, root.Position + dir * 12, dir)
				lastPos, lastProgress = root.Position, now()
				forGate = nil
			end
		end
		task.delay(0.25, step)
	end
	step()
end

---------------------------------------------------------------------------
-- Entry, start, race, results
---------------------------------------------------------------------------
local function openEntry()
	phase = "Entry"
	racers, finishOrder, winnerAt = {}, {}, nil
	buildCourse(1)
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
	for key, r in pairs(racers) do
		clearExtras(r)
		if r.Player then
			r.Player:SetAttribute("RaceEntered", nil)
			local character = r.Player.Character
			-- Riders keep their horse (now theirs to ride around).
			if character and character:FindFirstChild("RaceHorse") then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local root = character:FindFirstChild("HumanoidRootPart")
				if root and character:GetAttribute("RaceAnchored") then
					root.Anchored = false
					character:SetAttribute("RaceAnchored", nil)
				end
				if humanoid then
					Adapter.setMoveModifier(humanoid, "Horse", hcfg.RideSpeed or 2.8)
				end
				character:SetAttribute("Riding", "Ride")
			end
		elseif r.Model then
			local model = r.Model
			task.delay(2, function()
				model:Destroy()
			end)
		end
		racers[key] = nil
	end
	racers, finishOrder, winnerAt = {}, {}, nil
	phase = nil
	setAttr("SpinRacePhase", nil)
	setAttr("SpinRaceGoAt", nil)
	setAttr("SpinRaceStart", nil)
	setAttr("SpinRaceStage", nil)
	setAttr("SpinRaceStageName", nil)
	setAttr("SpinRaceNextStageAt", nil)
	stageIndex = 0
	if courseFolder then
		courseFolder:Destroy()
		courseFolder = nil
	end
	startPrompt = nil
end

local startStage -- (below)

-- Everyone lines up at the stage start, 4 abreast, on their horses, held for the countdown.
local function lineUp()
	local list = {}
	for key, r in pairs(racers) do
		table.insert(list, { Key = key, R = r })
	end
	-- Players at the front; then by points (the leaders start up front, like the real race).
	table.sort(list, function(a, b)
		local pa, pb = a.R.Player and 0 or 1, b.R.Player and 0 or 1
		if pa ~= pb then
			return pa < pb
		end
		return (a.R.Points or 0) > (b.R.Points or 0)
	end)
	local facing, right = course.StartFacing, course.Right
	local cols = cfg.GridColumns or 4
	for i, e in ipairs(list) do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local spot = course.Start - facing * (row * (cfg.GridRowGap or 7) + 3) + right * ((col - (cols - 1) / 2) * (cfg.GridSpacing or 4.5))
		local character = charOf(e.R)
		if character then
			if not character:FindFirstChild("RaceHorse") or character:GetAttribute("Riding") ~= "Race" then
				local look = e.R.Player and lookFor(e.R.Player) or e.R.Look or randomLook()
				e.R.Look = e.R.Look or look
				mount(character, look, (cfg.HorseSpeed or 3.2) * (e.R.Skill or 1), "Race")
			else
				local hum = character:FindFirstChildOfClass("Humanoid")
				if hum then
					Adapter.setMoveModifier(hum, "Horse", (cfg.HorseSpeed or 3.2) * (e.R.Skill or 1))
				end
			end
			standAt(character, spot, facing)
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				root.Anchored = true
				character:SetAttribute("RaceAnchored", true)
			end
		end
	end
	return #list
end

local function startRace()
	if startPrompt then
		startPrompt.Enabled = false
	end
	-- Only riders still alive and in the game.
	for key, r in pairs(racers) do
		local player = r.Player
		local h = player and player.Parent and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not h or h.Health <= 0 then
			racers[key] = nil
			if player then
				player:SetAttribute("RaceEntered", nil)
			end
		end
	end
	if racerCount(true) == 0 then
		broadcast("Cancelled", { Reason = "Nobody entered the Steel Ball Run this time." })
		cleanup()
		return
	end
	-- NPC jockeys join the field.
	for i = 1, cfg.NPCRacers or 0 do
		local r = spawnJockey(i)
		if r then
			racers[r] = r
		end
	end
	for _, r in pairs(racers) do
		r.Points = 0
		r.TotalTime = 0
		r.StagesDone = 0
		r.StageWins = 0
	end
	startStage(1)
end

startStage = function(index)
	stageIndex = index
	if index > 1 then
		buildCourse(index)
	end
	finishOrder, winnerAt = {}, nil
	for _, r in pairs(racers) do
		r.Next = 1
		r.Finished = false
		r.Place = nil
		r.Time = nil
		local keepPoints, keepTime, keepDone, keepWins, keepLook = r.Points, r.TotalTime, r.StagesDone, r.StageWins, r.Look
		initRacer(r)
		r.Points, r.TotalTime, r.StagesDone, r.StageWins, r.Look = keepPoints, keepTime, keepDone, keepWins, keepLook
	end
	phase = "Countdown"
	setAttr("SpinRacePhase", "Countdown")
	setAttr("SpinRaceStage", index)
	setAttr("SpinRaceStageName", course.StageName)
	local goAt = now() + (cfg.Countdown or 4)
	setAttr("SpinRaceGoAt", goAt)
	local riders = lineUp()
	broadcast("Countdown", { GoAt = goAt, Riders = riders, Total = #course.Gates })
	broadcast("Stage", { Index = index, Count = stageCount(), Name = course.StageName, Tagline = course.Tagline, Gates = #course.Gates })
	task.delay(cfg.Countdown or 4, function()
		if phase ~= "Countdown" or stageIndex ~= index then
			return
		end
		phase = "Racing"
		raceStart = now()
		setAttr("SpinRacePhase", "Racing")
		setAttr("SpinRaceStart", raceStart)
		for key, r in pairs(racers) do
			local character = charOf(r)
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				root.Anchored = false
				character:SetAttribute("RaceAnchored", nil)
			end
			if r.Jockey then
				task.spawn(runJockey, key, r)
			end
		end
		broadcast("Go", { Total = #course.Gates, Stage = index })
	end)
end

-- Overall standings: most points, then least total time.
local function overall()
	local list = {}
	for _, r in pairs(racers) do
		table.insert(list, r)
	end
	table.sort(list, function(a, b)
		if (a.Points or 0) ~= (b.Points or 0) then
			return (a.Points or 0) > (b.Points or 0)
		end
		return (a.TotalTime or 1e9) < (b.TotalTime or 1e9)
	end)
	local rows = {}
	for i, r in ipairs(list) do
		rows[i] = { Name = r.Name, UserId = r.UserId, Place = i, Points = r.Points or 0, Time = r.TotalTime or 0, Stages = r.StagesDone or 0, Jockey = r.Jockey }
	end
	return rows, list
end

local function endRace(reason)
	local rows, list = overall()
	-- Prizes go by overall place among the players; the overall winner (if a
	-- player) gets a Saint's Corpse part at the finish.
	local playerPlace = 0
	for i, r in ipairs(list) do
		if r.Player and (r.StagesDone or 0) > 0 then
			playerPlace = playerPlace + 1
			local prizes = cfg.Prizes or { 500, 250, 150 }
			local prize = prizes[playerPlace] or cfg.FinishPrize or 50
			pay(r.Player, prize)
			rows[i].Prize = prize
			if i == 1 then
				r.Player:SetAttribute("RaceWins", (r.Player:GetAttribute("RaceWins") or 0) + 1)
				if cfg.WinnerCorpsePart ~= false then
					local ok, C = pcall(function()
						return require(script.Parent.CorpseService)
					end)
					local root = r.Player.Character and r.Player.Character:FindFirstChild("HumanoidRootPart")
					if ok and C and C.summon and root then
						local _, name = C.summon(root.Position + root.CFrame.LookVector * 6)
						rows[i].Part = name
					end
				end
			end
			-- Best total time: only for riding every stage.
			local newRecord, oldBest = false, r.Player:GetAttribute("RaceBest")
			if (r.StagesDone or 0) >= stageCount() then
				newRecord = typeof(oldBest) ~= "number" or r.TotalTime < oldBest
				if newRecord then
					r.Player:SetAttribute("RaceBest", math.floor(r.TotalTime * 10 + 0.5) / 10)
				end
			end
			send(r.Player, "Record", { Time = r.TotalTime, NewRecord = newRecord, OldBest = oldBest, Wins = r.Player:GetAttribute("RaceWins") or 0, Place = i, Points = r.Points, Prize = prize, Part = rows[i].Part, AllStages = (r.StagesDone or 0) >= stageCount() })
		end
	end
	broadcast("Results", { List = rows, Reason = reason, Final = true })
	cleanup()
end

-- A stage is over: points by placing, the stage results, then the next stage (or the end).
local function endStage(reason)
	if phase ~= "Racing" then
		return
	end
	local pts = cfg.StagePoints or { 100, 70, 50, 40, 30, 25, 20, 15, 10, 5 }
	local stageRows = {}
	for i, r in ipairs(finishOrder) do
		local got = pts[i] or 0
		r.Points = (r.Points or 0) + got
		table.insert(stageRows, { Name = r.Name, UserId = r.UserId, Place = i, Time = r.Time, Points = got, Jockey = r.Jockey })
	end
	local rows = overall()
	broadcast("StageResults", { Index = stageIndex, Count = stageCount(), Name = course.StageName, List = stageRows, Overall = rows, Reason = reason })
	if stageIndex >= stageCount() or racerCount(true) == 0 then
		phase = "Rest"
		setAttr("SpinRacePhase", "Rest")
		task.delay(2.5, function()
			endRace(racerCount(true) == 0 and "Every rider dropped out." or "The Steel Ball Run is over!")
		end)
		return
	end
	phase = "Rest"
	setAttr("SpinRacePhase", "Rest")
	setAttr("SpinRaceNextStageAt", now() + (cfg.StageRest or 6))
	local nextIndex = stageIndex + 1
	task.delay(cfg.StageRest or 6, function()
		if phase == "Rest" and stageIndex == nextIndex - 1 then
			startStage(nextIndex)
		end
	end)
end

local function finish(r)
	table.insert(finishOrder, r)
	r.Finished = true
	r.Place = #finishOrder
	r.Time = now() - raceStart
	r.TotalTime = (r.TotalTime or 0) + r.Time
	r.StagesDone = (r.StagesDone or 0) + 1
	local pts = (cfg.StagePoints or {})[r.Place] or 0
	local prize = 0
	if r.Place == 1 then
		winnerAt = now()
		r.StageWins = (r.StageWins or 0) + 1
		if r.Player then
			prize = cfg.StageWinnerCash or 50
			pay(r.Player, prize)
		end
	end
	clearExtras(r)
	if r.Player then
		-- Done with this stage: ride around while the rest come in.
		local character = r.Player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and character:FindFirstChild("RaceHorse") then
			Adapter.setMoveModifier(humanoid, "Horse", hcfg.RideSpeed or 2.8)
		end
	end
	broadcast("Finished", { Name = r.Name, UserId = r.UserId, Place = r.Place, Time = r.Time, Prize = prize, Points = pts, Stage = stageIndex, StageName = course.StageName, Jockey = r.Jockey })
end

local function standings()
	local list = {}
	for _, r in pairs(racers) do
		local character = charOf(r)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local gate = course.Gates[r.Next]
		local dist = (root and gate) and (Vector3.new(gate.X, 0, gate.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude or 1e6
		table.insert(list, { Name = r.Name, UserId = r.UserId, Next = r.Next, Place = r.Place, Dist = dist, Jockey = r.Jockey, Progress = progressOf(r, dist), Points = r.Points or 0 })
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
		table.insert(rows, { Name = e.Name, UserId = e.UserId, Position = i, Next = e.Next, Finished = e.Place ~= nil, Dist = math.floor(e.Dist), Jockey = e.Jockey, Progress = e.Progress, Points = e.Points })
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
	local activePlayers = 0
	for key, r in pairs(racers) do
		if not r.Finished then
			stepRider(key, r, 0.1, t)
		end
	end
	for key, r in pairs(racers) do
		if not r.Finished then
			local character = charOf(r)
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local gate = course.Gates[r.Next]
			if root and gate then
				if r.Player then
					activePlayers = activePlayers + 1
				end
				local d = (Vector3.new(gate.X, 0, gate.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
				if d <= (cfg.PassRadius or 20) and math.abs(root.Position.Y - gate.Y) < 40 then
					r.Next = r.Next + 1
					if r.Next > total then
						finish(r)
					elseif r.Player then
						local split = t - raceStart
						r.Splits[r.Next - 1] = split
						send(r.Player, "Gate", { Index = r.Next - 1, Total = total, Split = split })
					end
				end
			end
		end
	end
	if t - lastStandings >= 0.5 then
		lastStandings = t
		local list = standings()
		for _, r in pairs(racers) do
			if r.Player then
				send(r.Player, "Standings", { List = list, Total = total, Elapsed = t - raceStart, Stage = stageIndex, Points = r.Points or 0 })
			end
		end
	end
	-- A stage ends when no player is still riding it, StageGrace after its
	-- winner, or at the stage time limit.
	if activePlayers == 0 then
		endStage(#finishOrder > 0 and "Everyone's in." or "Nobody finished the stage.")
	elseif winnerAt and t - winnerAt >= (cfg.StageGrace or cfg.FinishGrace or 15) then
		endStage("Time's up for the stragglers.")
	elseif t - raceStart >= (cfg.StageTimeLimit or cfg.TimeLimit or 75) then
		endStage("Time's up.")
	end
end

function RaceService.init()
	if cfg.Enabled == false and hcfg.Enabled == false then
		return
	end
	Remote = Net.get("Race")
	Remote.OnServerEvent:Connect(function(player, action, on)
		if action == "Join" then
			RaceService.join(player)
		elseif action == "Leave" then
			RaceService.leave(player)
		elseif action == "Horse" then
			RaceService.toggleHorse(player)
		elseif action == "Gallop" then
			RaceService.setGallop(player, on == true)
		elseif action == "Return" then
			RaceService.returnToGate(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		racers[player] = nil
	end)
	-- Going down (or resetting) puts you out of the race; the horse goes with the body.
	local function watchDeath(player, character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				local r = racers[player]
				if r and phase ~= "Entry" and not r.Finished then
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
	if cfg.Enabled == false then
		return -- horses only, no races
	end
	local first = RunService:IsStudio() and (cfg.StudioFirstAfter or 20) or (cfg.FirstAfter or 120)
	nextEntryAt = now() + first
	setAttr("SpinRaceNext", nextEntryAt)
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
