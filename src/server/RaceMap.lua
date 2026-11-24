--[[
	RaceMap  (ServerScriptService.SpinServer.RaceMap)

	A whole separate, GIANT world just for the Steel Ball Run, built far
	away from the main map (TuskConfig.Race.Map.Origin) when the server
	starts. About 12,000 studs of trail through the nine stages of the real
	race, each with its own scenery:
	  1 SAN DIEGO BEACH    sand, the ocean, palms, a grandstand at the start
	  2 ARIZONA DESERT     red sand, layered mesas, cacti, rocks, bones
	  3 ROCKY MOUNTAINS    a pass between snow-capped peaks, pines, boulders
	  4 GREAT PLAINS       grass, wheat fields, farmhouses, barns, windmills
	  5 MISSISSIPPI RIVER  a wide river, a long covered bridge, a riverboat
	  6 LAKE MICHIGAN      a great lake, a lighthouse, docks and sailboats
	  7 PHILADELPHIA       cobbled street, brick rows, the clock tower
	  8 NEW JERSEY         deep forest, log cabins
	  9 NEW YORK           an avenue of skyscrapers to the finish at the church
	The trail is laid down first (a dirt road on a band of the stage's
	ground); every bit of scenery is kept well back from it, so nothing ever
	blocks the route. Water slows riders (RaceMap.inWater); invisible walls
	keep everyone on the map. The race (RaceService) teleports riders here
	for the stages and back to the main map's spawn afterwards.
	Built in batches with short waits, so the server never hitches.
]]

local RaceMap = {}

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)

local cfg = (TuskConfig.Race and TuskConfig.Race.Map) or {}
local ORIGIN = cfg.Origin or Vector3.new(6000, 0, 0)
local rng = Random.new(cfg.Seed or 1907)

RaceMap.ready = false
RaceMap.building = false
local folder
local made = 0

-- The route: each stage's corners (relative to the origin). Gates are put
-- along it every GateEvery studs.
local STAGES = {
	{ Theme = "Beach", Path = { { 0, 0 }, { 500, 20 }, { 1000, 90 } } },
	{ Theme = "Desert", Path = { { 1000, 90 }, { 1450, 300 }, { 1800, 700 }, { 2300, 820 }, { 2700, 620 } } },
	{ Theme = "Rockies", Path = { { 2700, 620 }, { 3100, 820 }, { 3300, 1200 }, { 3200, 1600 }, { 3420, 2000 } } },
	{ Theme = "Plains", Path = { { 3420, 2000 }, { 3020, 2300 }, { 2420, 2360 }, { 1900, 2200 } } },
	{ Theme = "River", Path = { { 1900, 2200 }, { 1500, 2020 }, { 1100, 2120 }, { 720, 2300 } } },
	{ Theme = "Lake", Path = { { 720, 2300 }, { 420, 2620 }, { 520, 3000 }, { 1000, 3220 } } },
	{ Theme = "Town", Path = { { 1000, 3220 }, { 1500, 3260 }, { 2000, 3120 } } },
	{ Theme = "Forest", Path = { { 2000, 3120 }, { 2500, 3320 }, { 3000, 3220 }, { 3420, 3420 } } },
	{ Theme = "City", Path = { { 3420, 3420 }, { 3820, 3320 }, { 4120, 3020 }, { 4220, 2620 } } },
}
local GATE_EVERY = cfg.GateEvery or 260
local ROAD_WIDTH = 24
local BAND_WIDTH = 340

local GROUND = {
	Beach = { Color3.fromRGB(236, 214, 160), Enum.Material.Sand },
	Desert = { Color3.fromRGB(214, 160, 104), Enum.Material.Sand },
	Rockies = { Color3.fromRGB(118, 128, 104), Enum.Material.Slate },
	Plains = { Color3.fromRGB(116, 164, 72), Enum.Material.Grass },
	River = { Color3.fromRGB(100, 150, 70), Enum.Material.Grass },
	Lake = { Color3.fromRGB(150, 170, 110), Enum.Material.Grass },
	Town = { Color3.fromRGB(150, 140, 128), Enum.Material.Cobblestone },
	Forest = { Color3.fromRGB(84, 116, 58), Enum.Material.Grass },
	City = { Color3.fromRGB(96, 96, 102), Enum.Material.Concrete },
}
local ROAD = Color3.fromRGB(150, 116, 80)
local WOOD = Color3.fromRGB(112, 74, 44)
local WOOD_DARK = Color3.fromRGB(78, 50, 30)
local WATER = Color3.fromRGB(58, 132, 196)

local segments = {} -- every leg of the route: { A, B } (Vector2, relative)
local water = {} -- { CFrame, Size } boxes (relative) that slow riders

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function v2(p)
	return Vector2.new(p[1], p[2])
end

local function world(x, y, z)
	return ORIGIN + Vector3.new(x, y, z)
end

local function pause()
	made = made + 1
	if made % 150 == 0 then
		task.wait()
	end
end

local function part(parent, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = true
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	pause()
	return p
end

local function deco(parent, size, cf, color, material, props)
	local p = part(parent, size, cf, color, material, props)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or folder
	return m
end

-- Distance (flat) from a relative point to the nearest leg of the route.
local function distToRoute(x, z)
	local p = Vector2.new(x, z)
	local best = math.huge
	for _, s in ipairs(segments) do
		local ab = s.B - s.A
		local t = math.clamp((p - s.A):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
		best = math.min(best, (s.A + ab * t - p).Magnitude)
	end
	return best
end
RaceMap.distToRoute = distToRoute

-- A random spot beside a stage's route, between `near` and `far` studs out,
-- never closer than `clear` studs to ANY part of the route.
local function besideStage(stage, near, far, clear)
	local path = STAGES[stage].Path
	for _ = 1, 30 do
		local i = rng:NextInteger(1, #path - 1)
		local a, b = v2(path[i]), v2(path[i + 1])
		local along = a:Lerp(b, rng:NextNumber())
		local dir = (b - a).Unit
		local side = Vector2.new(-dir.Y, dir.X) * (rng:NextNumber() < 0.5 and -1 or 1)
		local p = along + side * rng:NextNumber(near, far)
		if distToRoute(p.X, p.Y) >= (clear or near) then
			return p
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Ground, road, walls
---------------------------------------------------------------------------
local function buildGround()
	local f = model("Ground")
	for si, st in ipairs(STAGES) do
		local g = GROUND[st.Theme]
		for i = 1, #st.Path - 1 do
			local a, b = v2(st.Path[i]), v2(st.Path[i + 1])
			local mid = (a + b) / 2
			local len = (b - a).Magnitude
			local cf = CFrame.lookAt(world(mid.X, -1, mid.Y), world(b.X, -1, b.Y))
			-- The stage's ground: a wide band along the leg (a little lower each
			-- stage, so overlaps never flicker), and a round patch at each corner.
			part(f, Vector3.new(BAND_WIDTH, 2, len + BAND_WIDTH * 0.2), cf * CFrame.new(0, -si * 0.01, 0), g[1], g[2])
			local corner = part(f, Vector3.new(2, BAND_WIDTH, BAND_WIDTH), CFrame.new(world(b.X, -1 - si * 0.01, b.Y)) * CFrame.Angles(0, 0, math.pi / 2), g[1], g[2])
			corner.Shape = Enum.PartType.Cylinder
			-- The dirt road.
			part(f, Vector3.new(ROAD_WIDTH, 0.2, len + 2), CFrame.lookAt(world(mid.X, 0.1, mid.Y), world(b.X, 0.1, b.Y)), ROAD, Enum.Material.Ground)
			local bend = part(f, Vector3.new(0.2, ROAD_WIDTH, ROAD_WIDTH), CFrame.new(world(b.X, 0.1, b.Y)) * CFrame.Angles(0, 0, math.pi / 2), ROAD, Enum.Material.Ground)
			bend.Shape = Enum.PartType.Cylinder
			table.insert(segments, { A = a, B = b, Stage = si })
		end
	end
	-- One big plain of base ground under everything (so there are no holes
	-- between the bands), and invisible walls round the edge.
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, s in ipairs(segments) do
		for _, p in ipairs({ s.A, s.B }) do
			minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
			minZ, maxZ = math.min(minZ, p.Y), math.max(maxZ, p.Y)
		end
	end
	local pad = 420
	minX, maxX, minZ, maxZ = minX - pad, maxX + pad, minZ - pad, maxZ + pad
	local tile = 2000
	for x = minX, maxX, tile do
		for z = minZ, maxZ, tile do
			local w, d = math.min(tile, maxX - x), math.min(tile, maxZ - z)
			part(f, Vector3.new(w, 2, d), CFrame.new(world(x + w / 2, -1.2, z + d / 2)), Color3.fromRGB(150, 140, 100), Enum.Material.Ground)
		end
	end
	local walls = model("Walls")
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local W, D = maxX - minX, maxZ - minZ
	for _, w in ipairs({
		{ Vector3.new(W, 300, 4), Vector3.new(cx, 150, minZ) },
		{ Vector3.new(W, 300, 4), Vector3.new(cx, 150, maxZ) },
		{ Vector3.new(4, 300, D), Vector3.new(minX, 150, cz) },
		{ Vector3.new(4, 300, D), Vector3.new(maxX, 150, cz) },
	}) do
		part(walls, w[1], CFrame.new(world(w[2].X, w[2].Y, w[2].Z)), Color3.new(1, 1, 1), nil, { Transparency = 1 })
	end
	RaceMap.Bounds = { MinX = minX, MaxX = maxX, MinZ = minZ, MaxZ = maxZ }
end

---------------------------------------------------------------------------
-- Scenery pieces
---------------------------------------------------------------------------
local function palm(p)
	local m = model("Palm")
	local lean = rng:NextNumber(-0.25, 0.25)
	local h = 0
	for k = 0, 5 do
		deco(m, Vector3.new(1.6 - k * 0.1, 3.2, 1.6 - k * 0.1), CFrame.new(world(p.X + lean * h, h + 1.6, p.Y)) * CFrame.Angles(0, 0, -lean * 0.6), Color3.fromRGB(140, 104, 64), Enum.Material.Wood)
		h = h + 3
	end
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		deco(m, Vector3.new(1, 0.4, 8), CFrame.new(world(p.X + lean * h, h + 0.6, p.Y)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -3.6) * CFrame.Angles(-0.35, 0, 0), Color3.fromRGB(70, 150, 60), Enum.Material.Grass)
	end
end

local function cactus(p)
	local m = model("Cactus")
	local h = rng:NextNumber(6, 11)
	local green = Color3.fromRGB(70, 130, 70)
	deco(m, Vector3.new(1.6, h, 1.6), CFrame.new(world(p.X, h / 2, p.Y)), green, Enum.Material.Grass)
	for _, side in ipairs({ -1, 1 }) do
		if rng:NextNumber() < 0.7 then
			local y = rng:NextNumber(h * 0.35, h * 0.6)
			deco(m, Vector3.new(2, 1, 1), CFrame.new(world(p.X + side * 1.5, y, p.Y)), green, Enum.Material.Grass)
			deco(m, Vector3.new(1, 3.5, 1), CFrame.new(world(p.X + side * 2.2, y + 1.6, p.Y)), green, Enum.Material.Grass)
		end
	end
end

local function rock(p, size, color)
	local s = size or rng:NextNumber(4, 12)
	local r = part(model("Rock"), Vector3.new(s, s * rng:NextNumber(0.5, 0.9), s * rng:NextNumber(0.7, 1.2)), CFrame.new(world(p.X, s * 0.3, p.Y)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)), color or Color3.fromRGB(140, 120, 100), Enum.Material.Slate)
	return r
end

local function mesa(p)
	local m = model("Mesa")
	local r = rng:NextNumber(40, 80)
	local y = 0
	local colors = { Color3.fromRGB(176, 96, 60), Color3.fromRGB(196, 124, 80), Color3.fromRGB(160, 84, 52), Color3.fromRGB(206, 150, 100) }
	for l = 1, 4 do
		local h = rng:NextNumber(10, 18)
		local rr = r * (1 - (l - 1) * 0.1)
		local c = part(m, Vector3.new(h, rr * 2, rr * 2), CFrame.new(world(p.X, y + h / 2, p.Y)) * CFrame.Angles(0, 0, math.pi / 2), colors[l], Enum.Material.Sandstone)
		c.Shape = Enum.PartType.Cylinder
		y = y + h
	end
end

local function mountain(p)
	local terrain = workspace.Terrain
	local r = rng:NextNumber(90, 170)
	terrain:FillBall(world(p.X, -r * 0.35, p.Y), r, Enum.Material.Rock)
	terrain:FillBall(world(p.X, r * 0.45, p.Y), r * 0.38, Enum.Material.Snow)
	pause()
end

local function pine(p)
	local m = model("Pine")
	local h = rng:NextNumber(14, 24)
	deco(m, Vector3.new(1.4, h * 0.4, 1.4), CFrame.new(world(p.X, h * 0.2, p.Y)), Color3.fromRGB(90, 60, 36), Enum.Material.Wood)
	for k = 0, 2 do
		local w = (3 - k) * h * 0.12
		deco(m, Vector3.new(w, h * 0.26, w), CFrame.new(world(p.X, h * (0.38 + k * 0.2), p.Y)) * CFrame.Angles(0, k * 0.6, 0), Color3.fromRGB(40, 90 + k * 10, 50), Enum.Material.Grass)
	end
end

local function leafTree(p)
	local m = model("Tree")
	local h = rng:NextNumber(12, 20)
	deco(m, Vector3.new(1.6, h * 0.55, 1.6), CFrame.new(world(p.X, h * 0.27, p.Y)), Color3.fromRGB(96, 66, 40), Enum.Material.Wood)
	local leaf = Color3.fromRGB(rng:NextInteger(50, 80), rng:NextInteger(110, 150), rng:NextInteger(40, 70))
	local b = deco(m, Vector3.new(h * 0.6, h * 0.6, h * 0.6), CFrame.new(world(p.X, h * 0.7, p.Y)), leaf, Enum.Material.Grass)
	b.Shape = Enum.PartType.Ball
end

local function house(p, color, roof, w, d, h, facing)
	local m = model("House")
	w, d, h = w or 20, d or 16, h or 12
	local cf = CFrame.new(world(p.X, 0, p.Y)) * CFrame.Angles(0, facing or rng:NextNumber(0, 6.28), 0)
	part(m, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), color, Enum.Material.Brick)
	for _, side in ipairs({ -1, 1 }) do
		local r = part(m, Vector3.new(w + 2, 1, d * 0.62), cf * CFrame.new(0, h + d * 0.2, side * d * 0.25) * CFrame.Angles(side * 0.7, 0, 0), roof, Enum.Material.WoodPlanks)
		r.CanCollide = false
	end
	deco(m, Vector3.new(4, 7, 0.4), cf * CFrame.new(0, 3.5, -d / 2 - 0.2), WOOD_DARK, Enum.Material.Wood)
	for _, x in ipairs({ -w * 0.3, w * 0.3 }) do
		deco(m, Vector3.new(3, 3, 0.4), cf * CFrame.new(x, h * 0.6, -d / 2 - 0.2), Color3.fromRGB(230, 220, 160), Enum.Material.Glass)
	end
end

local function windmill(p)
	local m = model("Windmill")
	local cf = CFrame.new(world(p.X, 0, p.Y)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		deco(m, Vector3.new(0.6, 30, 0.6), cf * CFrame.new(s[1] * 2.5, 15, s[2] * 2.5) * CFrame.Angles(s[2] * 0.08, 0, -s[1] * 0.08), Color3.fromRGB(150, 150, 156), Enum.Material.Metal)
	end
	local hub = cf * CFrame.new(0, 30, -1.5)
	for k = 0, 5 do
		deco(m, Vector3.new(1, 9, 0.2), hub * CFrame.Angles(0, 0, k / 6 * math.pi * 2) * CFrame.new(0, 4.5, 0), Color3.fromRGB(230, 230, 226), Enum.Material.Metal)
	end
	deco(m, Vector3.new(1.6, 1.6, 6), hub * CFrame.new(0, 0, 3), Color3.fromRGB(120, 40, 36), Enum.Material.Metal)
end

local function wheat(p)
	local w, d = rng:NextNumber(50, 90), rng:NextNumber(40, 70)
	local cf = CFrame.new(world(p.X, 0.6, p.Y)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	deco(model("Wheat"), Vector3.new(w, 1.2, d), cf, Color3.fromRGB(224, 190, 90), Enum.Material.Grass)
end

local function lampPost(p)
	local m = model("Lamp")
	deco(m, Vector3.new(0.5, 10, 0.5), CFrame.new(world(p.X, 5, p.Y)), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	local lamp = deco(m, Vector3.new(1.4, 1.6, 1.4), CFrame.new(world(p.X, 10.6, p.Y)), Color3.fromRGB(255, 230, 160), Enum.Material.Neon)
	return lamp
end

local function skyscraper(p, h)
	local m = model("Skyscraper")
	local w, d = rng:NextNumber(26, 46), rng:NextNumber(26, 46)
	h = h or rng:NextNumber(60, 200)
	local tone = rng:NextInteger(110, 190)
	local cf = CFrame.new(world(p.X, 0, p.Y))
	part(m, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), Color3.fromRGB(tone, tone, tone + 8), Enum.Material.Concrete)
	-- Bands of windows.
	for y = 8, h - 6, 14 do
		deco(m, Vector3.new(w + 0.4, 4, d + 0.4), cf * CFrame.new(0, y, 0), Color3.fromRGB(60, 90, 130), Enum.Material.Glass, { Transparency = 0.15 })
	end
	if rng:NextNumber() < 0.4 then
		deco(m, Vector3.new(1, 24, 1), cf * CFrame.new(0, h + 12, 0), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
	end
end

local function sign(at, facing, text, color)
	local m = model("Sign")
	local cf = CFrame.lookAt(world(at.X, 0, at.Y), world(at.X + facing.X, 0, at.Y + facing.Y))
	for _, x in ipairs({ -5, 5 }) do
		deco(m, Vector3.new(0.8, 12, 0.8), cf * CFrame.new(x, 6, 0), WOOD_DARK, Enum.Material.Wood)
	end
	local board = deco(m, Vector3.new(14, 4.5, 0.6), cf * CFrame.new(0, 10, 0), WOOD, Enum.Material.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 220, 120)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = board
	local back = gui:Clone()
	back.Face = Enum.NormalId.Front
	back.Parent = board
end

-- A crowd stand: tiered benches with little blocky spectators.
local function grandstand(at, facing)
	local m = model("Grandstand")
	local cf = CFrame.lookAt(world(at.X, 0, at.Y), world(at.X + facing.X, 0, at.Y + facing.Y))
	for row = 0, 3 do
		part(m, Vector3.new(60, 1.2, 4), cf * CFrame.new(0, 1 + row * 1.6, row * 4), WOOD, Enum.Material.WoodPlanks)
		for k = -6, 6 do
			if rng:NextNumber() < 0.75 then
				local c = Color3.fromHSV(rng:NextNumber(), 0.5, 0.85)
				deco(m, Vector3.new(1.6, 2, 1), cf * CFrame.new(k * 4.3, 2.6 + row * 1.6, row * 4), c)
				deco(m, Vector3.new(1, 1, 1), cf * CFrame.new(k * 4.3, 4.1 + row * 1.6, row * 4), Color3.fromRGB(230, 190, 150))
			end
		end
	end
	deco(m, Vector3.new(62, 0.6, 18), cf * CFrame.new(0, 10, 6) * CFrame.Angles(-0.1, 0, 0), Color3.fromRGB(190, 40, 36), Enum.Material.Fabric)
end

local function waterBox(cfRel, size)
	-- (Relative CFrame -> world.) Water is a solid sheet a hair above the
	-- ground; riders in it are slowed (RaceMap.inWater).
	local cf = CFrame.new(ORIGIN) * cfRel
	part(folder, size, cf, WATER, Enum.Material.Glass, { Transparency = 0.15, Reflectance = 0.2, CanCollide = false, CanQuery = false })
	table.insert(water, { CF = cfRel, Size = size })
end

---------------------------------------------------------------------------
-- The stages' scenery
---------------------------------------------------------------------------
local function scatter(stage, count, near, far, clear, fn)
	for _ = 1, count do
		local p = besideStage(stage, near, far, clear)
		if p then
			fn(p)
		end
	end
end

local function stageFrom(i)
	return v2(STAGES[i].Path[1]), v2(STAGES[i].Path[2])
end

local function buildScenery()
	-- 1 SAN DIEGO BEACH: the ocean to the south, palms, the start grandstands.
	waterBox(CFrame.new(500, 0.05, -330), Vector3.new(1700, 0.2, 380))
	scatter(1, 24, 30, 150, 28, palm)
	for k = 1, 8 do
		local x = rng:NextNumber(50, 950)
		local umbrellaAt = Vector2.new(x, rng:NextNumber(-130, -60))
		if distToRoute(umbrellaAt.X, umbrellaAt.Y) > 40 then
			local m = model("Umbrella")
			deco(m, Vector3.new(0.4, 7, 0.4), CFrame.new(world(umbrellaAt.X, 3.5, umbrellaAt.Y)), Color3.new(1, 1, 1))
			local top = deco(m, Vector3.new(1, 9, 9), CFrame.new(world(umbrellaAt.X, 7.2, umbrellaAt.Y)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromHSV(rng:NextNumber(), 0.6, 0.95), Enum.Material.Fabric)
			top.Shape = Enum.PartType.Cylinder
		end
	end
	grandstand(Vector2.new(-10, 60), Vector2.new(0, -1))
	grandstand(Vector2.new(-10, -60), Vector2.new(0, 1))
	-- 2 ARIZONA DESERT: mesas, cacti, rocks, a few bones.
	scatter(2, 12, 110, 300, 100, mesa)
	scatter(2, 50, 30, 220, 26, cactus)
	scatter(2, 30, 30, 260, 26, function(p)
		rock(p, nil, Color3.fromRGB(176, 120, 80))
	end)
	-- 3 ROCKY MOUNTAINS: snow-capped peaks either side of the pass, pines, boulders.
	scatter(3, 14, 200, 380, 190, mountain)
	scatter(3, 60, 30, 190, 28, pine)
	scatter(3, 20, 30, 160, 26, function(p)
		rock(p, rng:NextNumber(6, 14), Color3.fromRGB(120, 120, 124))
	end)
	-- 4 GREAT PLAINS: wheat, farms, barns, windmills.
	scatter(4, 16, 60, 260, 50, wheat)
	scatter(4, 6, 60, 220, 50, function(p)
		house(p, Color3.fromRGB(230, 222, 200), Color3.fromRGB(110, 60, 40))
	end)
	scatter(4, 5, 60, 220, 50, function(p)
		house(p, Color3.fromRGB(170, 40, 36), Color3.fromRGB(70, 60, 56), 28, 20, 16)
	end)
	scatter(4, 6, 50, 240, 45, windmill)
	-- 5 MISSISSIPPI RIVER: a wide river across the route, the bridge over it, a riverboat.
	do
		local a, b = v2(STAGES[5].Path[2]), v2(STAGES[5].Path[3])
		local cross = a:Lerp(b, 0.5)
		local dir = (b - a).Unit
		local riverDir = Vector2.new(-dir.Y, dir.X)
		local cf = CFrame.lookAt(Vector3.new(cross.X, 0.05, cross.Y), Vector3.new(cross.X + riverDir.X, 0.05, cross.Y + riverDir.Y))
		waterBox(cf, Vector3.new(80, 0.2, 1400))
		-- The covered bridge (the road runs straight over it: no slowdown on it).
		local bcf = CFrame.lookAt(world(cross.X, 0, cross.Y), world(cross.X + dir.X, 0, cross.Y + dir.Y))
		local m = model("Bridge")
		part(m, Vector3.new(30, 1, 110), bcf * CFrame.new(0, 0.6, 0), Color3.fromRGB(130, 90, 56), Enum.Material.WoodPlanks)
		for _, x in ipairs({ -14.5, 14.5 }) do
			deco(m, Vector3.new(1, 10, 110), bcf * CFrame.new(x, 6, 0), Color3.fromRGB(170, 50, 40), Enum.Material.WoodPlanks)
		end
		deco(m, Vector3.new(32, 1, 112), bcf * CFrame.new(0, 13, 0), WOOD_DARK, Enum.Material.WoodPlanks)
		RaceMap.BridgeCF = bcf
		-- A paddle steamer moored downstream.
		local boatAt = cross + riverDir * 260
		local boat = model("Riverboat")
		local bc = CFrame.lookAt(world(boatAt.X, 0, boatAt.Y), world(boatAt.X + riverDir.X, 0, boatAt.Y + riverDir.Y))
		deco(boat, Vector3.new(20, 5, 60), bc * CFrame.new(0, 2.5, 0), Color3.new(1, 1, 1), Enum.Material.WoodPlanks)
		deco(boat, Vector3.new(16, 6, 36), bc * CFrame.new(0, 8, 0), Color3.fromRGB(240, 236, 226), Enum.Material.WoodPlanks)
		for _, z in ipairs({ -8, 8 }) do
			deco(boat, Vector3.new(2, 14, 2), bc * CFrame.new(0, 18, z), Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
		end
		deco(boat, Vector3.new(4, 12, 12), bc * CFrame.new(0, 6, 34), Color3.fromRGB(170, 40, 36), Enum.Material.Wood)
	end
	scatter(5, 40, 30, 200, 28, leafTree)
	-- 6 LAKE MICHIGAN: a great lake to the west, a lighthouse, docks, sailboats.
	waterBox(CFrame.new(-60, 0.05, 2860), Vector3.new(560, 0.2, 1200))
	do
		local lh = model("Lighthouse")
		local at = Vector2.new(250, 2760)
		for k = 0, 5 do
			local c = deco(lh, Vector3.new(6, 10 - k * 0.6, 10 - k * 0.6), CFrame.new(world(at.X, 3 + k * 6, at.Y)) * CFrame.Angles(0, 0, math.pi / 2), k % 2 == 0 and Color3.new(1, 1, 1) or Color3.fromRGB(190, 40, 36), Enum.Material.Concrete)
			c.Shape = Enum.PartType.Cylinder
		end
		deco(lh, Vector3.new(5, 5, 5), CFrame.new(world(at.X, 39, at.Y)), Color3.fromRGB(255, 230, 140), Enum.Material.Neon)
		for k = 0, 2 do
			deco(model("Dock"), Vector3.new(60, 1, 8), CFrame.new(world(230 - 30, 0.8, 2900 + k * 140)), Color3.fromRGB(130, 96, 60), Enum.Material.WoodPlanks)
			local sail = model("Sailboat")
			local sp = Vector2.new(rng:NextNumber(-250, 120), 2500 + k * 300)
			deco(sail, Vector3.new(6, 3, 18), CFrame.new(world(sp.X, 1.5, sp.Y)), Color3.new(1, 1, 1), Enum.Material.WoodPlanks)
			deco(sail, Vector3.new(0.5, 18, 0.5), CFrame.new(world(sp.X, 12, sp.Y)), WOOD_DARK)
			deco(sail, Vector3.new(0.3, 14, 10), CFrame.new(world(sp.X, 12, sp.Y + 5)), Color3.fromRGB(240, 236, 226), Enum.Material.Fabric)
		end
	end
	scatter(6, 30, 30, 200, 28, function(p)
		if p.X > 260 then
			leafTree(p)
		end
	end)
	-- 7 PHILADELPHIA: brick rows along the street, lamp posts, the clock tower.
	do
		local path = STAGES[7].Path
		for i = 1, #path - 1 do
			local a, b = v2(path[i]), v2(path[i + 1])
			local dir = (b - a).Unit
			local side = Vector2.new(-dir.Y, dir.X)
			local len = (b - a).Magnitude
			for d = 40, len - 40, 46 do
				for _, s in ipairs({ -1, 1 }) do
					local at = a + dir * d + side * s * rng:NextNumber(48, 70)
					if distToRoute(at.X, at.Y) > 36 then
						local yaw = math.atan2(-(side.X * -s), -(side.Y * -s))
						house(at, Color3.fromRGB(rng:NextInteger(150, 180), rng:NextInteger(60, 80), rng:NextInteger(50, 64)), Color3.fromRGB(60, 56, 56), 34, 24, rng:NextNumber(16, 26), yaw)
					end
					local lampAt = a + dir * (d + 23) + side * s * 18
					if distToRoute(lampAt.X, lampAt.Y) > 15 then
						lampPost(lampAt)
					end
				end
			end
		end
		local mid = v2(path[2]) + Vector2.new(0, 110)
		if distToRoute(mid.X, mid.Y) > 60 then
			local hall = model("ClockTower")
			part(hall, Vector3.new(60, 24, 30), CFrame.new(world(mid.X, 12, mid.Y)), Color3.fromRGB(160, 70, 56), Enum.Material.Brick)
			part(hall, Vector3.new(14, 30, 14), CFrame.new(world(mid.X, 39, mid.Y)), Color3.fromRGB(160, 70, 56), Enum.Material.Brick)
			deco(hall, Vector3.new(10, 14, 10), CFrame.new(world(mid.X, 61, mid.Y)), Color3.new(1, 1, 1), Enum.Material.WoodPlanks)
			deco(hall, Vector3.new(6, 10, 6), CFrame.new(world(mid.X, 73, mid.Y)), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
			local clock = deco(hall, Vector3.new(0.4, 6, 6), CFrame.new(world(mid.X, 48, mid.Y - 7.2)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(250, 246, 230), Enum.Material.SmoothPlastic)
			clock.Shape = Enum.PartType.Cylinder
		end
	end
	-- 8 NEW JERSEY: deep forest and log cabins.
	scatter(8, 140, 26, 240, 24, function(p)
		if rng:NextNumber() < 0.5 then
			pine(p)
		else
			leafTree(p)
		end
	end)
	scatter(8, 5, 60, 200, 50, function(p)
		house(p, Color3.fromRGB(120, 80, 48), Color3.fromRGB(80, 56, 36), 22, 16, 10)
	end)
	-- 9 NEW YORK: an avenue of skyscrapers, then the church at the finish.
	do
		local path = STAGES[9].Path
		for i = 1, #path - 1 do
			local a, b = v2(path[i]), v2(path[i + 1])
			local dir = (b - a).Unit
			local side = Vector2.new(-dir.Y, dir.X)
			local len = (b - a).Magnitude
			for d = 30, len - 30, 54 do
				for _, s in ipairs({ -1, 1 }) do
					local at = a + dir * d + side * s * rng:NextNumber(56, 90)
					if distToRoute(at.X, at.Y) > 44 then
						skyscraper(at)
					end
				end
			end
		end
		local fin = v2(path[#path])
		local prev = v2(path[#path - 1])
		local dir = (fin - prev).Unit
		local churchAt = fin + dir * 90
		local church = model("Church")
		local cf = CFrame.lookAt(world(churchAt.X, 0, churchAt.Y), world(fin.X, 0, fin.Y))
		part(church, Vector3.new(40, 30, 70), cf * CFrame.new(0, 15, 0), Color3.fromRGB(120, 100, 90), Enum.Material.Brick)
		part(church, Vector3.new(16, 60, 16), cf * CFrame.new(0, 30, -30), Color3.fromRGB(120, 100, 90), Enum.Material.Brick)
		deco(church, Vector3.new(10, 40, 10), cf * CFrame.new(0, 80, -30), Color3.fromRGB(90, 80, 76), Enum.Material.Slate)
		grandstand(fin + Vector2.new(-dir.Y, dir.X) * 50, Vector2.new(dir.Y, -dir.X))
		grandstand(fin - Vector2.new(-dir.Y, dir.X) * 50, Vector2.new(-dir.Y, dir.X))
	end
	-- A sign at every stage start.
	for i, st in ipairs(STAGES) do
		local a, b = stageFrom(i)
		local dir = (b - a).Unit
		local side = Vector2.new(-dir.Y, dir.X)
		local name = (TuskConfig.Race and TuskConfig.Race.Stages and TuskConfig.Race.Stages[i] and TuskConfig.Race.Stages[i].Name) or st.Theme
		sign(a + side * 26 + dir * 6, -dir, "STAGE " .. i .. ": " .. name)
	end
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
-- Is a world position in water (and not on the bridge)?
function RaceMap.inWater(pos)
	if not RaceMap.ready then
		return false
	end
	local rel = pos - ORIGIN
	if RaceMap.BridgeCF then
		local b = RaceMap.BridgeCF:Inverse() * pos
		if math.abs(b.X) <= 15 and math.abs(b.Z) <= 55 then
			return false
		end
	end
	for _, w in ipairs(water) do
		local local_ = w.CF:Inverse() * rel
		if math.abs(local_.X) <= w.Size.X / 2 and math.abs(local_.Z) <= w.Size.Z / 2 then
			return true
		end
	end
	return false
end

-- Is a world position on the race map at all?
function RaceMap.contains(pos)
	local b = RaceMap.Bounds
	if not b then
		return false
	end
	local rel = pos - ORIGIN
	return rel.X >= b.MinX - 50 and rel.X <= b.MaxX + 50 and rel.Z >= b.MinZ - 50 and rel.Z <= b.MaxZ + 50 and math.abs(rel.Y) < 600
end

function RaceMap.origin()
	return ORIGIN
end

-- The stages for RaceService: { Name, Tagline, Start, Gates } with
-- positions relative to RaceMap.origin(), a gate every GATE_EVERY studs.
function RaceMap.stages()
	local list = {}
	local names = TuskConfig.Race and TuskConfig.Race.Stages or {}
	for i, st in ipairs(STAGES) do
		local gates = {}
		local path = st.Path
		for k = 1, #path - 1 do
			local a, b = v2(path[k]), v2(path[k + 1])
			local len = (b - a).Magnitude
			local n = math.max(1, math.floor(len / GATE_EVERY + 0.5))
			for j = 1, n do
				local p = a:Lerp(b, j / n)
				table.insert(gates, Vector3.new(p.X, 0, p.Y))
			end
		end
		local named = names[i] or {}
		list[i] = { Name = named.Name or st.Theme, Tagline = named.Tagline, Start = Vector3.new(path[1][1], 0, path[1][2]), Gates = gates }
	end
	return list
end

-- The length of the whole route (studs).
function RaceMap.length()
	local total = 0
	for _, s in ipairs(segments) do
		total = total + (s.B - s.A).Magnitude
	end
	return total
end

function RaceMap.build()
	if RaceMap.ready or RaceMap.building then
		return
	end
	RaceMap.building = true
	folder = Instance.new("Folder")
	folder.Name = "SteelBallRunMap"
	folder.Parent = workspace
	local ok, err = pcall(function()
		buildGround()
		buildScenery()
	end)
	if not ok then
		warn("[RaceMap] building the race map failed: " .. tostring(err))
	end
	RaceMap.building = false
	RaceMap.ready = ok
	return ok
end

return RaceMap
