--[[
	ArrowService  (ServerScriptService.SpinServer.ArrowService)

	THE REQUIEM ARROW. Every few minutes (TuskConfig.RequiemArrow.Every) an
	arrow turns up at a random spot in the desert: on open, low ground,
	never on the mountains or in water. It is NOT marked: no glow, no beam,
	no light, no map marker. It's an ordinary-looking arrow stuck in the
	sand. Everyone is told one has appeared (WorldFX "RequiemArrow"), and the
	bounty board posts a contract for it (BountyService).
	Hold E next to it to take it:
	  * playing POLNAREFF (Silver Chariot): it pierces Silver Chariot and it
	    becomes SILVER CHARIOT REQUIEM (Act 24) until he goes down
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
-- The arrow: a wooden shaft stuck in the sand at a slant, a gold arrowhead
-- with a scarab on it, feathered fletching. Nothing glows.
---------------------------------------------------------------------------
local function part(model, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
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

local function buildArrow(at)
	local model = Instance.new("Model")
	model.Name = "RequiemArrow"
	-- Stuck in the sand, leaning; a random way round.
	local base = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(math.rad(-28), 0, 0)
	local shaft = part(model, "Shaft", Vector3.new(0.16, 3.2, 0.16), base * CFrame.new(0, 1.2, 0), Color3.fromRGB(120, 82, 46), Enum.Material.Wood)
	model.PrimaryPart = shaft
	-- The head, half buried: a gold point with a scarab on it.
	part(model, "Head", Vector3.new(0.5, 0.5, 0.12), base * CFrame.new(0, -0.35, 0) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(214, 170, 64), Enum.Material.Metal)
	part(model, "Scarab", Vector3.new(0.34, 0.42, 0.22), base * CFrame.new(0, -0.15, -0.06), Color3.fromRGB(150, 112, 40), Enum.Material.Metal, Enum.PartType.Ball)
	part(model, "Socket", Vector3.new(0.22, 0.3, 0.22), base * CFrame.new(0, 0.05, 0), Color3.fromRGB(184, 140, 50), Enum.Material.Metal)
	-- Fletching at the top.
	for k = 0, 2 do
		part(model, "Feather", Vector3.new(0.04, 0.6, 0.3), base * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, k * math.pi * 2 / 3, 0) * CFrame.new(0, 0, 0.14), Color3.fromRGB(230, 226, 214))
	end
	part(model, "Nock", Vector3.new(0.18, 0.12, 0.18), base * CFrame.new(0, 2.82, 0), Color3.fromRGB(90, 60, 34), Enum.Material.Wood)
	-- A little disturbed sand round it.
	part(model, "Sand", Vector3.new(0.3, 1.6, 1.6), CFrame.new(at + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(206, 176, 128), Enum.Material.Sand, Enum.PartType.Cylinder)
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
	if act and Registry.characterOf(act) == "Polnareff" and act ~= 24 and S.select then
		-- The arrow pierces Silver Chariot.
		fx({ Phase = "Requiem", Player = player.UserId, Name = player.DisplayName, Character = character, Position = at })
		task.delay(1.2, function()
			if player.Character == character and humanoid.Health > 0 then
				S.select(player, 24, true)
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
	-- Everyone's told, but not where.
	fx({ Phase = "Spawned" })
	for _, f in ipairs(ArrowService.OnSpawned) do
		pcall(f)
	end
end
ArrowService.spawnNow = spawnArrow

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
