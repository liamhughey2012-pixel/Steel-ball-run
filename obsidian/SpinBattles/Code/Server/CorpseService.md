---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# CorpseService

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `CorpseService` (capitals matter) |

**What it does:** SAINT'S CORPSE. Eight parts (TuskConfig.Corpse.Parts), each existing once, lie around the map: a mummified relic glowing gold with a beam of light you can see from far away. Hold E by one to take it. each part gives its own boost until you die (Damage, Resist, Cooldown, UltGain, Speed, MaxHealth), stacking with any others you hold when you die your parts drop where you fell for anyone to grab; one nobody takes moves to a new random spot after a while holding any part unlocks your character's CORPSE MOVE (V), see CorpseMoves holders are worth more on the bounty board (BountyService) Boosts are character attributes the combat code reads: CorpseDamage, CorpseResist, CorpseCooldown, CorpseUltGain (multipliers) CorpseParts ("Heart,Spine") for the HUD and the bounty board Clients are told about pickups and drops over WorldFX ("Corpse...").

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **CorpseService**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
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

-- A mummified part, blocky, built round `at` (the floating centre).
local function shape(model, id, at)
	local c = CFrame.new(at)
	if id == "Heart" then
		piece(model, Vector3.new(1.3, 1.5, 1.1), c * CFrame.Angles(0, 0, 0.3), MUMMY)
		piece(model, Vector3.new(0.3, 0.6, 0.3), c * CFrame.new(-0.3, 0.9, 0), MUMMY_DARK)
		piece(model, Vector3.new(0.3, 0.5, 0.3), c * CFrame.new(0.25, 0.85, 0.1), MUMMY_DARK)
		piece(model, Vector3.new(1.36, 0.16, 1.16), c * CFrame.new(0, -0.2, 0) * CFrame.Angles(0, 0, 0.3), WRAP)
	elseif id == "Head" then
		piece(model, Vector3.new(1.3, 1.4, 1.3), c, MUMMY)
		for _, x in ipairs({ -0.3, 0.3 }) do
			piece(model, Vector3.new(0.3, 0.3, 0.05), c * CFrame.new(x, 0.15, -0.66), MUMMY_DARK)
		end
		piece(model, Vector3.new(0.6, 0.12, 0.05), c * CFrame.new(0, -0.35, -0.66), MUMMY_DARK)
		piece(model, Vector3.new(1.36, 0.16, 1.36), c * CFrame.new(0, 0.45, 0), WRAP)
	elseif id == "Spine" then
		for i = 0, 5 do
			piece(model, Vector3.new(0.5 + (i % 2) * 0.2, 0.32, 0.4), c * CFrame.new(0, -1 + i * 0.4, 0), i % 2 == 0 and MUMMY or WRAP)
		end
	elseif id == "Eyes" then
		piece(model, Vector3.new(1.6, 0.35, 0.3), c, WRAP)
		for _, x in ipairs({ -0.4, 0.4 }) do
			piece(model, Vector3.new(0.45, 0.45, 0.45), c * CFrame.new(x, 0, -0.2), Color3.fromRGB(236, 228, 214), Enum.PartType.Ball)
			piece(model, Vector3.new(0.2, 0.2, 0.2), c * CFrame.new(x, 0, -0.4), Color3.fromRGB(40, 30, 30), Enum.PartType.Ball)
		end
	elseif id == "Ears" then
		for _, x in ipairs({ -0.45, 0.45 }) do
			piece(model, Vector3.new(0.2, 1.0, 0.7), c * CFrame.new(x, 0, 0) * CFrame.Angles(0, 0, x * 0.4), MUMMY)
		end
		piece(model, Vector3.new(1.2, 0.18, 0.3), c * CFrame.new(0, -0.3, 0), WRAP)
	elseif id == "Legs" then
		for _, x in ipairs({ -0.35, 0.35 }) do
			piece(model, Vector3.new(0.5, 2.4, 0.5), c * CFrame.new(x, 0, 0), MUMMY)
			piece(model, Vector3.new(0.56, 0.2, 0.56), c * CFrame.new(x, 0.4, 0), WRAP)
			piece(model, Vector3.new(0.5, 0.3, 0.8), c * CFrame.new(x, -1.2, -0.15), MUMMY_DARK)
		end
	else -- LeftArm / RightArm
		local side = id == "LeftArm" and -1 or 1
		local arm = c * CFrame.Angles(0, 0, side * 0.3)
		piece(model, Vector3.new(0.5, 2.2, 0.5), arm, MUMMY)
		piece(model, Vector3.new(0.56, 0.2, 0.56), arm * CFrame.new(0, 0.5, 0), WRAP)
		piece(model, Vector3.new(0.6, 0.5, 0.35), arm * CFrame.new(0, -1.3, 0), MUMMY_DARK)
		for f = -1.5, 1.5 do
			piece(model, Vector3.new(0.1, 0.4, 0.1), arm * CFrame.new(f * 0.13, -1.7, 0), MUMMY_DARK)
		end
	end
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
```
