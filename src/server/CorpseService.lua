--[[
	CorpseService  (ServerScriptService.SpinServer.CorpseService)

	SAINT'S CORPSE. Eight parts (TuskConfig.Corpse.Parts), each existing
	once, lie around the map: a mummified relic glowing gold with a beam of
	light you can see from far away. Hold E by one to take it.
	  * each part gives its own boost until you die (Damage, Resist, Cooldown,
	    UltGain, Speed, MaxHealth), stacking with any others you hold
	  * when you die your parts drop where you fell for anyone to grab; one
	    nobody takes moves to a new random spot after a while
	  * holding any part unlocks your character's CORPSE MOVE (V), see
	    CorpseMoves
	  * holders are worth more on the bounty board (BountyService)
	  * Stand-user NPCs pick parts up too, use their corpse move, and drop
	    their parts when they die (StandBots uses take / dropFor)
	Boosts are character attributes the combat code reads:
	  CorpseDamage, CorpseResist, CorpseCooldown, CorpseUltGain (multipliers)
	  CorpseParts ("Heart,Spine") for the HUD and the bounty board
	Clients are told about pickups and drops over WorldFX ("Corpse...").
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Net = require(Shared.Net)

local CorpseService = {}
CorpseService.OnTaken = {} -- functions(player, partId) called when someone takes a part

local cfg
local S -- TuskService
local folder
local WorldFX
local partInfo = {} -- [id] = config entry
local relics = {} -- [id] = relic model lying in the world
local held = {} -- [player] = { Ids = { ... }, BaseMax = number }
local rng = Random.new()

local MUMMY = Color3.fromRGB(122, 90, 60)
local MUMMY_DARK = Color3.fromRGB(84, 60, 40)
local WRAP = Color3.fromRGB(222, 204, 164)
local GLOW = Color3.fromRGB(255, 214, 110)

local function origin()
	local map = workspace:FindFirstChild("SBRMap")
	return map and map:GetAttribute("Origin") or Vector3.new()
end

local function groundAt(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { folder }
	for _, m in ipairs(CollectionService:GetTagged("SpinFighter")) do
		table.insert(ex, m)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ex, p.Character)
		end
	end
	params.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(pos + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), params)
	return hit and hit.Position or pos
end

---------------------------------------------------------------------------
-- The relics
---------------------------------------------------------------------------
local function piece(model, size, cf, color, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local WRAP_DARK = Color3.fromRGB(184, 164, 124)
local BONE = Color3.fromRGB(226, 214, 186)
local SINEW = Color3.fromRGB(96, 52, 40)
local GOLD = Color3.fromRGB(226, 182, 70)

-- A bandage band round a box-shaped piece.
local function band(model, cf, w, d)
	piece(model, Vector3.new(w + 0.06, 0.14, d + 0.06), cf, WRAP)
	piece(model, Vector3.new(w + 0.07, 0.04, d + 0.07), cf * CFrame.new(0, 0.05, 0), WRAP_DARK)
end

-- A mummified part, blocky but detailed, built round `at` (the floating centre).
local function shape(model, id, at)
	local c = CFrame.new(at)
	if id == "Heart" then
		local h = c * CFrame.Angles(0, 0, 0.25)
		piece(model, Vector3.new(1.2, 1.4, 1.0), h, MUMMY)
		piece(model, Vector3.new(0.7, 0.8, 0.9), h * CFrame.new(-0.45, 0.25, 0), MUMMY) -- left lobe
		piece(model, Vector3.new(0.6, 0.7, 0.8), h * CFrame.new(0.42, 0.3, 0.05), MUMMY_DARK) -- right lobe
		piece(model, Vector3.new(0.5, 0.5, 0.6), h * CFrame.new(0.05, -0.75, 0) * CFrame.Angles(0, 0, 0.6), MUMMY_DARK) -- apex
		-- The aorta arching over the top, and two vessels.
		piece(model, Vector3.new(0.28, 0.5, 0.28), h * CFrame.new(-0.15, 0.9, 0), SINEW)
		piece(model, Vector3.new(0.5, 0.24, 0.24), h * CFrame.new(0.05, 1.15, 0) * CFrame.Angles(0, 0, -0.2), SINEW)
		piece(model, Vector3.new(0.22, 0.4, 0.22), h * CFrame.new(0.32, 0.95, 0), SINEW)
		piece(model, Vector3.new(0.2, 0.35, 0.2), h * CFrame.new(-0.45, 0.8, 0.15), SINEW)
		-- Veins over the front.
		for i = -1, 1 do
			piece(model, Vector3.new(0.05, 0.7, 0.04), h * CFrame.new(i * 0.25, 0, -0.52) * CFrame.Angles(0, 0, i * 0.4), SINEW)
		end
		-- Crossed bandages.
		piece(model, Vector3.new(1.5, 0.16, 1.1), h * CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, 0.5), WRAP)
		piece(model, Vector3.new(1.4, 0.14, 1.08), h * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, -0.6), WRAP_DARK)
	elseif id == "Head" then
		piece(model, Vector3.new(1.3, 1.3, 1.35), c * CFrame.new(0, 0.1, 0), BONE) -- cranium
		piece(model, Vector3.new(1.36, 0.16, 0.3), c * CFrame.new(0, 0.32, -0.6), MUMMY) -- brow ridge
		for _, x in ipairs({ -0.3, 0.3 }) do
			piece(model, Vector3.new(0.34, 0.34, 0.12), c * CFrame.new(x, 0.08, -0.66), MUMMY_DARK) -- eye socket
			piece(model, Vector3.new(0.16, 0.16, 0.06), c * CFrame.new(x, 0.08, -0.7), Color3.fromRGB(30, 20, 16))
			piece(model, Vector3.new(0.3, 0.2, 0.2), c * CFrame.new(x * 1.7, -0.15, -0.5), MUMMY) -- cheekbones
		end
		piece(model, Vector3.new(0.2, 0.3, 0.1), c * CFrame.new(0, -0.15, -0.68), MUMMY_DARK) -- nose
		-- Jaw hanging slightly open, a row of teeth.
		piece(model, Vector3.new(1.0, 0.3, 0.9), c * CFrame.new(0, -0.68, -0.15) * CFrame.Angles(0.2, 0, 0), MUMMY)
		for i = -2, 2 do
			piece(model, Vector3.new(0.12, 0.16, 0.08), c * CFrame.new(i * 0.16, -0.48, -0.62), BONE)
		end
		-- Bandages wound round the top and under the chin.
		band(model, c * CFrame.new(0, 0.55, 0), 1.3, 1.35)
		piece(model, Vector3.new(0.18, 1.5, 1.4), c * CFrame.new(0.55, -0.05, 0) * CFrame.Angles(0, 0, 0.15), WRAP)
		piece(model, Vector3.new(0.5, 0.12, 0.08), c * CFrame.new(0.6, -0.9, -0.3) * CFrame.Angles(0, 0, -0.8), WRAP_DARK) -- loose end
	elseif id == "Spine" then
		for i = 0, 6 do
			local v = c * CFrame.new(math.sin(i * 0.7) * 0.08, -1.3 + i * 0.43, 0)
			piece(model, Vector3.new(0.5, 0.3, 0.45), v, BONE) -- vertebra
			piece(model, Vector3.new(1.0, 0.12, 0.2), v * CFrame.new(0, 0, 0.12), MUMMY) -- side wings
			piece(model, Vector3.new(0.14, 0.2, 0.4), v * CFrame.new(0, -0.05, 0.35) * CFrame.Angles(-0.5, 0, 0), MUMMY_DARK) -- spike
			if i < 6 then
				piece(model, Vector3.new(0.42, 0.12, 0.38), v * CFrame.new(0, 0.22, 0), SINEW) -- disc
			end
		end
		band(model, c * CFrame.new(0, 0.1, 0), 0.5, 0.45)
		band(model, c * CFrame.new(0, -0.8, 0), 0.5, 0.45)
	elseif id == "Eyes" then
		piece(model, Vector3.new(1.9, 0.45, 0.4), c * CFrame.new(0, 0, 0.1), WRAP) -- cloth band
		piece(model, Vector3.new(1.92, 0.06, 0.42), c * CFrame.new(0, 0.12, 0.1), WRAP_DARK)
		for _, x in ipairs({ -0.45, 0.45 }) do
			piece(model, Vector3.new(0.5, 0.5, 0.5), c * CFrame.new(x, 0, -0.2), Color3.fromRGB(236, 228, 214), Enum.PartType.Ball)
			piece(model, Vector3.new(0.24, 0.24, 0.24), c * CFrame.new(x, 0, -0.42), Color3.fromRGB(70, 110, 140), Enum.PartType.Ball) -- iris
			piece(model, Vector3.new(0.12, 0.12, 0.12), c * CFrame.new(x, 0, -0.52), Color3.fromRGB(20, 16, 16), Enum.PartType.Ball) -- pupil
			-- Nerves trailing back.
			piece(model, Vector3.new(0.08, 0.08, 0.7), c * CFrame.new(x * 0.8, -0.05, 0.4) * CFrame.Angles(0, x * 0.6, 0), SINEW)
		end
	elseif id == "Ears" then
		for _, side in ipairs({ -1, 1 }) do
			local e = c * CFrame.new(side * 0.5, 0, 0) * CFrame.Angles(0, side * 0.3, 0)
			-- The outer rim: a C of blocks.
			piece(model, Vector3.new(0.2, 0.25, 0.6), e * CFrame.new(0, 0.5, 0), MUMMY)
			piece(model, Vector3.new(0.2, 0.8, 0.25), e * CFrame.new(0, 0.1, 0.28), MUMMY)
			piece(model, Vector3.new(0.2, 0.25, 0.45), e * CFrame.new(0, -0.35, 0.05), MUMMY)
			piece(model, Vector3.new(0.18, 0.3, 0.3), e * CFrame.new(0, -0.55, -0.1), MUMMY_DARK) -- lobe
			piece(model, Vector3.new(0.16, 0.45, 0.3), e * CFrame.new(0.02, 0.1, 0.02), MUMMY_DARK) -- inner fold
		end
		piece(model, Vector3.new(1.4, 0.14, 0.3), c * CFrame.new(0, -0.75, 0), WRAP) -- tied together
	elseif id == "Legs" then
		for _, side in ipairs({ -1, 1 }) do
			local l = c * CFrame.new(side * 0.38, 0, 0) * CFrame.Angles(0, 0, side * 0.06)
			piece(model, Vector3.new(0.55, 1.2, 0.55), l * CFrame.new(0, 0.7, 0), MUMMY) -- thigh
			piece(model, Vector3.new(0.5, 0.3, 0.55), l * CFrame.new(0, 0.05, -0.05), BONE) -- knee
			piece(model, Vector3.new(0.45, 1.2, 0.45), l * CFrame.new(0, -0.65, 0), MUMMY) -- shin
			piece(model, Vector3.new(0.5, 0.25, 0.85), l * CFrame.new(0, -1.35, -0.2), MUMMY_DARK) -- foot
			for t = -1.5, 1.5 do
				piece(model, Vector3.new(0.1, 0.12, 0.16), l * CFrame.new(t * 0.11, -1.38, -0.68), MUMMY_DARK) -- toes
			end
			band(model, l * CFrame.new(0, 0.9, 0), 0.55, 0.55)
			band(model, l * CFrame.new(0, -0.4, 0), 0.45, 0.45)
		end
	else -- LeftArm / RightArm: bent at the elbow
		local side = id == "LeftArm" and -1 or 1
		local upper = c * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, side * 0.3)
		piece(model, Vector3.new(0.5, 1.2, 0.5), upper, MUMMY)
		local elbow = upper * CFrame.new(0, -0.65, 0)
		piece(model, Vector3.new(0.45, 0.3, 0.45), elbow, BONE)
		local fore = elbow * CFrame.Angles(0, 0, side * -0.7) * CFrame.new(0, -0.6, 0)
		piece(model, Vector3.new(0.42, 1.1, 0.42), fore, MUMMY)
		local hand = fore * CFrame.new(0, -0.7, 0)
		piece(model, Vector3.new(0.55, 0.45, 0.25), hand, MUMMY_DARK)
		for f = -1.5, 1.5 do
			piece(model, Vector3.new(0.09, 0.42, 0.09), hand * CFrame.new(f * 0.13, -0.4, 0) * CFrame.Angles(0.25, 0, 0), MUMMY_DARK)
		end
		piece(model, Vector3.new(0.09, 0.3, 0.09), hand * CFrame.new(side * -0.32, -0.1, -0.05) * CFrame.Angles(0, 0, side * 0.6), MUMMY_DARK) -- thumb
		band(model, upper * CFrame.new(0, 0.3, 0), 0.5, 0.5)
		band(model, fore * CFrame.new(0, 0.2, 0), 0.42, 0.42)
		piece(model, Vector3.new(0.1, 0.8, 0.06), fore * CFrame.new(0.2, -0.2, 0.22) * CFrame.Angles(0.2, 0, 0.2), WRAP) -- loose strip
	end
	-- A floating gold halo over every relic.
	local halo = piece(model, Vector3.new(0.12, 2.2, 2.2), CFrame.new(at + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, 0, math.pi / 2), GOLD, Enum.PartType.Cylinder)
	halo.Name = "Halo"
	halo.Material = Enum.Material.Neon
	halo.Transparency = 0.3
	piece(model, Vector3.new(0.14, 1.7, 1.7), CFrame.new(at + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, 0, math.pi / 2), GLOW, Enum.PartType.Cylinder).Transparency = 1
end

local collect -- (defined below)

local function placeRelic(id, position, dropped)
	local old = relics[id]
	if old then
		old:Destroy()
	end
	local info = partInfo[id]
	local ground = groundAt(position)
	local model = Instance.new("Model")
	model.Name = "Corpse" .. id
	local holder = piece(model, Vector3.new(3, 3, 3), CFrame.new(ground + Vector3.new(0, 2.5, 0)), GLOW)
	holder.Name = "Holder"
	holder.Transparency = 1
	model.PrimaryPart = holder
	shape(model, id, ground + Vector3.new(0, 2.5, 0))
	-- A pillar of light you can see from far away.
	local beam = piece(model, Vector3.new(60, 1.6, 1.6), CFrame.new(ground + Vector3.new(0, 31, 0)) * CFrame.Angles(0, 0, math.pi / 2), GLOW, Enum.PartType.Cylinder)
	beam.Name = "Beam"
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.65
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = holder
	-- Golden motes drifting up from it.
	local motes = Instance.new("ParticleEmitter")
	motes.Color = ColorSequence.new(GLOW)
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	motes.Lifetime = NumberRange.new(1, 1.8)
	motes.Speed = NumberRange.new(1, 2.5)
	motes.SpreadAngle = Vector2.new(40, 40)
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Rate = 8
	motes.Parent = holder
	local highlight = Instance.new("Highlight")
	highlight.FillColor = GLOW
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = GLOW
	highlight.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take"
	prompt.ObjectText = "Saint's Corpse: " .. info.Name
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = holder
	prompt.Triggered:Connect(function(player)
		collect(player, id)
	end)
	model:SetAttribute("PartId", id)
	model:SetAttribute("Dropped", dropped == true)
	model:SetAttribute("LaidAt", workspace:GetServerTimeNow())
	model.Parent = folder
	CollectionService:AddTag(model, "SpinCorpse")
	relics[id] = model
	if dropped then
		-- Nobody takes it: it goes back out into the desert somewhere else.
		local stamp = os.clock()
		model:SetAttribute("DroppedAt", stamp)
		task.delay(cfg.DropDespawn or 60, function()
			if relics[id] == model and model.Parent and model:GetAttribute("DroppedAt") == stamp then
				CorpseService.scatter(id)
			end
		end)
	end
	return model
end

-- Put a part on a random spot (not one another part is already on).
function CorpseService.scatter(id)
	local used = {}
	for otherId, m in pairs(relics) do
		if otherId ~= id and m.Parent then
			used[m:GetAttribute("Spot") or -1] = true
		end
	end
	local free = {}
	for i = 1, #cfg.Spots do
		if not used[i] then
			table.insert(free, i)
		end
	end
	local i = #free > 0 and free[rng:NextInteger(1, #free)] or rng:NextInteger(1, #cfg.Spots)
	local model = placeRelic(id, origin() + cfg.Spots[i], false)
	model:SetAttribute("Spot", i)
end

---------------------------------------------------------------------------
-- Holding parts: boosts
---------------------------------------------------------------------------
local function apply(player)
	local h = held[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local sum = { Damage = 0, Resist = 0, Cooldown = 0, UltGain = 0, Speed = 0, MaxHealth = 0 }
	local ids = h and h.Ids or {}
	for _, id in ipairs(ids) do
		local info = partInfo[id]
		if info then
			sum[info.Buff] = (sum[info.Buff] or 0) + info.Amount
		end
	end
	local any = #ids > 0
	character:SetAttribute("CorpseParts", any and table.concat(ids, ",") or nil)
	character:SetAttribute("CorpseComplete", (#ids >= #cfg.Parts) or nil)
	character:SetAttribute("CorpseDamage", sum.Damage > 0 and 1 + sum.Damage or nil)
	character:SetAttribute("CorpseResist", sum.Resist > 0 and math.max(0.5, 1 - sum.Resist) or nil)
	character:SetAttribute("CorpseCooldown", sum.Cooldown > 0 and math.max(0.5, 1 - sum.Cooldown) or nil)
	character:SetAttribute("CorpseUltGain", sum.UltGain > 0 and 1 + sum.UltGain or nil)
	S.Adapter.setMoveModifier(humanoid, "Corpse", sum.Speed > 0 and 1 + sum.Speed or nil)
	if h then
		h.BaseMax = h.BaseMax or humanoid.MaxHealth
		local want = h.BaseMax + sum.MaxHealth
		if humanoid.MaxHealth ~= want then
			local gained = want - humanoid.MaxHealth
			humanoid.MaxHealth = want
			if gained > 0 then
				humanoid.Health = math.min(want, humanoid.Health + gained)
			end
		end
	end
end

function collect(player, id)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local model = relics[id]
	if not humanoid or humanoid.Health <= 0 or not model or not model.Parent then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - model:GetPivot().Position).Magnitude > 14 then
		return
	end
	relics[id] = nil
	model:Destroy()
	held[player] = held[player] or { Ids = {} }
	table.insert(held[player].Ids, id)
	apply(player)
	WorldFX:FireAllClients("CorpseTaken", { Player = player.UserId, Name = player.DisplayName, Part = id, Position = root.Position })
	for _, fn in ipairs(CorpseService.OnTaken) do
		task.spawn(fn, player, id)
	end
	-- All of it: everyone hears about it.
	if #held[player].Ids >= #cfg.Parts then
		WorldFX:FireAllClients("CorpseComplete", { Player = player.UserId, Name = player.DisplayName, Character = character })
	end
end

-- Where a part is: { Holder = player } if someone carries it, or
-- { Relic = model } if it's lying in the world (nil if neither).
function CorpseService.where(id)
	for p, h in pairs(held) do
		for _, heldId in ipairs(h.Ids) do
			if heldId == id then
				return { Holder = p }
			end
		end
	end
	local relic = relics[id]
	if relic and relic.Parent then
		return { Relic = relic }
	end
	return nil
end

function CorpseService.parts()
	return cfg and cfg.Parts or {}
end

-- Dies (or leaves): their parts fall where they were.
local function dropAll(player, position)
	local h = held[player]
	held[player] = nil
	if not h then
		return
	end
	for i, id in ipairs(h.Ids) do
		if position then
			local a = i / #h.Ids * math.pi * 2
			placeRelic(id, position + Vector3.new(math.cos(a) * 3, 0, math.sin(a) * 3), true)
			WorldFX:FireAllClients("CorpseDropped", { Part = id, Position = position, Name = player.DisplayName })
		else
			CorpseService.scatter(id)
		end
	end
end

-- After THE SAINT'S MIRACLE: the corpse leaves them; every part scatters.
function CorpseService.release(player)
	local h = held[player]
	if not h then
		return
	end
	local ids = h.Ids
	h.Ids = {}
	apply(player)
	held[player] = nil
	for _, id in ipairs(ids) do
		CorpseService.scatter(id)
	end
	WorldFX:FireAllClients("CorpseScattered", { Name = player.DisplayName })
end

-- For Stand-user NPCs (StandBots): take a part, and drop theirs when they die.
function CorpseService.take(botPlayer, id)
	collect(botPlayer, id)
end

function CorpseService.dropFor(botPlayer, position)
	dropAll(botPlayer, position)
end

function CorpseService.holding(player)
	local h = held[player]
	return h and #h.Ids or 0
end

local function watch(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		local root = character:FindFirstChild("HumanoidRootPart")
		dropAll(player, root and root.Position or nil)
	end)
end

function CorpseService.init(TuskService)
	cfg = TuskConfig.Corpse
	if not cfg or cfg.Enabled == false then
		return
	end
	S = TuskService
	WorldFX = Net.get("WorldFX")
	for _, info in ipairs(cfg.Parts) do
		partInfo[info.Id] = info
	end
	folder = Instance.new("Folder")
	folder.Name = "SaintsCorpse"
	folder.Parent = workspace
	for _, info in ipairs(cfg.Parts) do
		CorpseService.scatter(info.Id)
	end
	local function onPlayer(player)
		player.CharacterAdded:Connect(function(character)
			watch(player, character)
		end)
		if player.Character then
			task.spawn(watch, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		dropAll(player, nil)
	end)
	-- The CORPSE MOVE goes through TuskService's request handler.
	local Moves = require(script.Parent.CorpseMoves)
	TuskService.CorpseMove = function(player, state, aim)
		if CorpseService.holding(player) < 1 then
			TuskService.tell(player, "Denied", { Reason = "NeedCorpse" })
			return
		end
		Moves.use(TuskService, player, state, aim, cfg.Move)
	end
end

return CorpseService
