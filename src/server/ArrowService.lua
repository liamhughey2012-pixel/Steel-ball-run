--[[
	ArrowService  (ServerScriptService.SpinServer.ArrowService)

	THE REQUIEM ARROW. Every few minutes (TuskConfig.RequiemArrow.Every) an
	arrow turns up at a random spot in the desert: on open, low ground,
	never on the mountains or in water. For its first few seconds
	(HighlightTime) a purple Highlight shows it through walls, then it fades
	and it's an ordinary-looking arrow stuck in the sand: no glow, no beam,
	no light, no map marker. Everyone is told one has appeared (WorldFX "RequiemArrow"), and the
	bounty board posts a contract for it (BountyService).
	Hold E next to it to take it:
	  * playing POLNAREFF (Silver Chariot): it pierces Silver Chariot and it
	    becomes SILVER CHARIOT REQUIEM (Act 24) until he goes down; Giorno's
	    Gold Experience becomes GOLD EXPERIENCE REQUIEM (Act 31)
	  * anyone else: THE ARROW'S BLESSING (hit harder, take less, faster,
	    quicker ultimate) for a while
	An arrow nobody takes vanishes when the next one turns up somewhere else.
	Hooks: ArrowService.OnTaken = { function(player) ... },
	       ArrowService.OnSpawned / OnVanished = { function() ... }.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local Net = require(Shared.Net)
local Adapter = require(script.Parent.CombatAdapter)

local ArrowService = {}
ArrowService.OnTaken = {}
ArrowService.OnSpawned = {}
ArrowService.OnVanished = {}
local cfg = TuskConfig.RequiemArrow or {}
local S -- TuskService
local current -- { Model, Position, Spawned }
local rng = Random.new()
local WorldFX

local function now()
	return workspace:GetServerTimeNow()
end

local function fx(data)
	WorldFX = WorldFX or Net.get("WorldFX")
	WorldFX:FireAllClients("RequiemArrow", data)
end

function ArrowService.current()
	return current
end

function ArrowService.isOut()
	return current ~= nil and current.Model ~= nil and current.Model.Parent ~= nil
end

---------------------------------------------------------------------------
-- The arrow (like the Stand Arrows in the series): an ornate GOLD
-- leaf-shaped head with barbs and a raised ridge, its tip just in the sand;
-- a gold SCARAB clasped at its base (wing cases, legs, a violet gem on its
-- back); a dark wooden shaft with gold bands and a bound grip; three
-- striped feathers; a little mound of disturbed sand and pebbles round it.
-- Nothing glows.
---------------------------------------------------------------------------
local GOLD = Color3.fromRGB(222, 178, 66)
local GOLD_DARK = Color3.fromRGB(164, 120, 38)
local GOLD_LIGHT = Color3.fromRGB(246, 214, 120)
local WOOD = Color3.fromRGB(92, 58, 34)
local BIND = Color3.fromRGB(56, 36, 24)
local GEM = Color3.fromRGB(120, 60, 176)
local FEATHER = Color3.fromRGB(236, 230, 214)
local STRIPE = Color3.fromRGB(120, 84, 52)
local SAND = Color3.fromRGB(206, 176, 128)

local function part(model, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.CastShadow = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function egg(model, name, size, cf, color, material)
	local p = part(model, name, size, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A ring round the shaft (local Y) at height y.
local function band(model, base, y, d, h, color, material)
	return part(model, "Band", Vector3.new(h, d, d), base * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), color, material or Enum.Material.Metal, Enum.PartType.Cylinder)
end

local function buildArrow(at)
	local model = Instance.new("Model")
	model.Name = "RequiemArrow"
	-- Stuck in the sand, leaning; a random way round. Local Y runs up the arrow.
	local base = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(math.rad(-26), 0, 0) * CFrame.new(0, 0.5, 0)
	local metal = Enum.Material.Metal

	-- The shaft: dark wood, gold bands, a bound grip.
	local shaft = part(model, "Shaft", Vector3.new(0.14, 3.3, 0.14), base * CFrame.new(0, 2.55, 0), WOOD, Enum.Material.Wood, nil)
	model.PrimaryPart = shaft
	band(model, base, 1.0, 0.26, 0.22, GOLD) -- socket
	band(model, base, 1.14, 0.3, 0.05, GOLD_LIGHT)
	band(model, base, 1.5, 0.2, 0.06, GOLD)
	for k = 0, 5 do
		band(model, base, 2.3 + k * 0.1, 0.18, 0.06, BIND, Enum.Material.Fabric)
	end
	band(model, base, 3.35, 0.2, 0.06, GOLD)

	-- The head: a leaf-shaped gold blade (slices, narrow at the tip), a
	-- raised ridge down the middle, two barbs at the back.
	local widths = { 0.1, 0.26, 0.42, 0.56, 0.66, 0.7, 0.64, 0.54 }
	for k, w in ipairs(widths) do
		part(model, "Blade", Vector3.new(w, 0.15, 0.08), base * CFrame.new(0, -0.5 + (k - 1) * 0.14, 0), k % 2 == 0 and GOLD or GOLD_LIGHT, metal)
	end
	part(model, "Ridge", Vector3.new(0.07, 1.0, 0.11), base * CFrame.new(0, 0.05, 0), GOLD_DARK, metal)
	for _, side in ipairs({ -1, 1 }) do
		part(model, "Barb", Vector3.new(0.12, 0.42, 0.08), base * CFrame.new(side * 0.36, 0.58, 0) * CFrame.Angles(0, 0, side * 0.55), GOLD, metal)
		part(model, "Engraving", Vector3.new(0.03, 0.55, 0.075), base * CFrame.new(side * 0.13, 0.12, 0) * CFrame.Angles(0, 0, side * -0.18), GOLD_DARK, metal)
	end

	-- The scarab clasped at the base of the head, on both faces.
	for _, face in ipairs({ -1, 1 }) do
		local f = base * CFrame.new(0, 0.74, face * 0.1)
		egg(model, "ScarabBody", Vector3.new(0.34, 0.46, 0.2), f, GOLD_DARK, metal)
		for _, side in ipairs({ -1, 1 }) do
			egg(model, "WingCase", Vector3.new(0.17, 0.38, 0.12), f * CFrame.new(side * 0.085, -0.03, face * 0.06), GOLD, metal)
			for leg = -1, 1 do
				part(model, "Leg", Vector3.new(0.18, 0.035, 0.035), f * CFrame.new(side * 0.2, leg * 0.12, face * 0.02) * CFrame.Angles(0, 0, side * (0.4 + leg * 0.35)), GOLD_DARK, metal)
			end
		end
		part(model, "WingLine", Vector3.new(0.025, 0.36, 0.13), f * CFrame.new(0, -0.03, face * 0.07), GOLD_DARK, metal)
		part(model, "ScarabHead", Vector3.new(0.16, 0.16, 0.16), f * CFrame.new(0, 0.27, face * 0.02), GOLD_DARK, metal, Enum.PartType.Ball)
		part(model, "Gem", Vector3.new(0.11, 0.11, 0.11), f * CFrame.new(0, 0.08, face * 0.13), GEM, Enum.Material.Glass, Enum.PartType.Ball)
	end

	-- Three striped feathers at the top, and the nock.
	for k = 0, 2 do
		local spin = base * CFrame.new(0, 3.45, 0) * CFrame.Angles(0, k * math.pi * 2 / 3, 0)
		local profile = { 0.12, 0.2, 0.26, 0.28, 0.26, 0.2 }
		for i, w in ipairs(profile) do
			part(model, "Feather", Vector3.new(0.03, 0.15, w), spin * CFrame.new(0, (i - 1) * 0.14, 0.06 + w / 2), i % 3 == 0 and STRIPE or FEATHER, Enum.Material.Fabric)
		end
	end
	part(model, "Nock", Vector3.new(0.18, 0.14, 0.18), base * CFrame.new(0, 4.25, 0), GOLD, metal)

	-- Disturbed sand and a few pebbles round where it went in.
	part(model, "Sand", Vector3.new(0.08, 1.8, 1.8), CFrame.new(at + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.pi / 2), SAND, Enum.Material.Sand, Enum.PartType.Cylinder)
	egg(model, "Mound", Vector3.new(0.9, 0.3, 0.7), CFrame.new(at + Vector3.new(0, 0.02, 0)), Color3.fromRGB(194, 165, 120), Enum.Material.Sand)
	for k = 1, 5 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.6, 1.2)
		part(model, "Pebble", Vector3.new(0.14, 0.1, 0.12) * rng:NextNumber(0.8, 1.4), CFrame.new(at + Vector3.new(math.cos(a) * r, 0.1, math.sin(a) * r)) * CFrame.Angles(0, a, 0.3), Color3.fromRGB(150, 126, 96), Enum.Material.Slate)
	end
	-- Hold E to take it (only shows up close).
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take the arrow"
	prompt.ObjectText = "Arrow"
	prompt.HoldDuration = cfg.HoldTime or 1.5
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = shaft
	return model, prompt
end

---------------------------------------------------------------------------
-- Where: random open, low ground in the desert
---------------------------------------------------------------------------
local function findSpot()
	local map = workspace:FindFirstChild("SBRMap")
	local origin = map and map:GetAttribute("Origin") or Vector3.new()
	local radius = cfg.Radius or 360
	local ignore = {}
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
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber(0.05, 1)) * radius
		local x, z = origin.X + math.cos(a) * r, origin.Z + math.sin(a) * r
		local hit = workspace:Raycast(Vector3.new(x, origin.Y + 250, z), Vector3.new(0, -400, 0), params)
		if hit and hit.Normal.Y > 0.85 and hit.Position.Y < origin.Y + (cfg.MaxHeight or 10) and hit.Material ~= Enum.Material.Water then
			local open = hit.Instance:IsA("Terrain") or (hit.Instance:IsA("BasePart") and hit.Instance.Size.X * hit.Instance.Size.Z >= 400)
			if open then
				return hit.Position
			end
		end
	end
	-- Fallback: one of the corpse spots.
	local spots = TuskConfig.Corpse and TuskConfig.Corpse.Spots
	if spots and #spots > 0 then
		local s = spots[rng:NextInteger(1, #spots)]
		local hit = workspace:Raycast(origin + s + Vector3.new(0, 250, 0), Vector3.new(0, -400, 0), params)
		return hit and hit.Position or (origin + s)
	end
	return origin
end

---------------------------------------------------------------------------
-- Taking it
---------------------------------------------------------------------------
local function bless(player, character)
	local b = cfg.Blessing or {}
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local untilT = now() + (b.Time or 90)
	character:SetAttribute("ArrowBlessUntil", untilT)
	character:SetAttribute("ArrowDamage", b.Damage or 1.2)
	character:SetAttribute("ArrowResist", b.Resist or 0.8)
	character:SetAttribute("ArrowUltGain", b.UltGain or 1.5)
	if humanoid then
		Adapter.setMoveModifier(humanoid, "ArrowBlessing", b.Speed or 1.15)
	end
	task.delay(b.Time or 90, function()
		if character.Parent and character:GetAttribute("ArrowBlessUntil") == untilT then
			character:SetAttribute("ArrowBlessUntil", nil)
			if humanoid and humanoid.Parent then
				Adapter.setMoveModifier(humanoid, "ArrowBlessing", nil)
			end
			fx({ Phase = "BlessingOver", Player = player.UserId })
		end
	end)
end

-- Who the arrow pierces, and what their Stand becomes (until they go down).
local REQUIEM_OF = {
	Polnareff = { Act = 24, Stand = "SILVER CHARIOT", Becomes = "SILVER CHARIOT REQUIEM", Delay = 1.2 },
	Giorno = { Act = 31, Stand = "GOLD EXPERIENCE", Becomes = "GOLD EXPERIENCE REQUIEM", Delay = 1.2 },
}

local function take(player)
	if not current or not current.Model or not current.Model.Parent then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local at = current.Position
	current.Model:Destroy()
	current = nil
	for _, f in ipairs(ArrowService.OnTaken) do
		pcall(f, player)
	end
	local state = S and S.States and S.States[player]
	local act = state and state.Act
	local who = act and Registry.characterOf(act)
	local requiem = who and REQUIEM_OF[who]
	if requiem and act ~= requiem.Act and S.select then
		-- The arrow pierces their Stand.
		fx({ Phase = "Requiem", Player = player.UserId, Name = player.DisplayName, Character = character, Position = at, Who = who, Stand = requiem.Stand, Becomes = requiem.Becomes, Act = requiem.Act })
		task.delay(requiem.Delay, function()
			if player.Character == character and humanoid.Health > 0 then
				S.select(player, requiem.Act, true)
			end
		end)
	else
		bless(player, character)
		fx({ Phase = "Blessing", Player = player.UserId, Name = player.DisplayName, Character = character, Position = at, Time = (cfg.Blessing or {}).Time or 90 })
	end
end

local function spawnArrow()
	if current and current.Model and current.Model.Parent then
		current.Model:Destroy()
		fx({ Phase = "Vanished" })
		for _, f in ipairs(ArrowService.OnVanished) do
			pcall(f)
		end
	end
	local at = findSpot()
	local model, prompt = buildArrow(at)
	model.Parent = workspace:FindFirstChild("SBRMap") or workspace
	current = { Model = model, Position = at, Spawned = now() }
	prompt.Triggered:Connect(take)
	-- A purple highlight, seen through walls, for a few seconds; then it fades.
	local showFor = cfg.HighlightTime or 5
	if showFor > 0 then
		local hl = Instance.new("Highlight")
		hl.Name = "ArrowFlash"
		hl.Adornee = model
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillColor = Color3.fromRGB(150, 70, 230)
		hl.OutlineColor = Color3.fromRGB(225, 190, 255)
		hl.FillTransparency = 0.35
		hl.OutlineTransparency = 0
		hl.Parent = model
		task.delay(math.max(0, showFor - 1), function()
			if hl.Parent then
				game:GetService("TweenService"):Create(hl, TweenInfo.new(1), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
			end
		end)
		task.delay(showFor, function()
			hl:Destroy()
		end)
	end
	-- Everyone's told.
	fx({ Phase = "Spawned" })
	for _, f in ipairs(ArrowService.OnSpawned) do
		pcall(f)
	end
end
ArrowService.spawnNow = spawnArrow
ArrowService.buildArrow = buildArrow -- (for previews and tests)

function ArrowService.init(service)
	S = service
	if cfg.Enabled == false then
		return
	end
	task.spawn(function()
		task.wait(cfg.FirstAfter or 60)
		while true do
			pcall(spawnArrow)
			task.wait(cfg.Every or 300)
		end
	end)
end

return ArrowService
