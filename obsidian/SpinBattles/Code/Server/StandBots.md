---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# StandBots

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `StandBots` (capitals matter) |

**What it does:** Enemy NPCs that fight you with a Stand. Each one plays a real character (Johnny / Tusk, Gyro, Diego, Pork Pie Hat Kid, Sandman: whichever are installed) through exactly the same move code as players, so their M1s, abilities and ultimates hit, stun and look the same. they're scattered round the map (TuskConfig.StandBots.Spots), chase any player who comes within AggroRange and walk back to their spot when the player gets away each respawn picks a new free spot, so they move around over time M1 combo up close, abilities on cooldown, ultimate when their meter is full hold abilities are charged and released automatically they respawn RespawnTime seconds after dying, as a random character Settings: TuskConfig.StandBots (Enabled = false turns them off). Tagged "SpinFighter" so every client draws their Stand, outfit and effects.

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **StandBots**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	StandBots  (ServerScriptService.SpinServer.StandBots)

	Enemy NPCs that fight you with a Stand. Each one plays a real character
	(Johnny / Tusk, Gyro, Diego, Pork Pie Hat Kid, Sandman: whichever are
	installed) through exactly the same move code as players, so their M1s,
	abilities and ultimates hit, stun and look the same.
	  * they're scattered round the map (TuskConfig.StandBots.Spots), chase
	    any player who comes within AggroRange and walk back to their spot
	    when the player gets away
	  * each respawn picks a new free spot, so they move around over time
	  * M1 combo up close, abilities on cooldown, ultimate when their meter is full
	  * hold abilities are charged and released automatically
	  * they respawn RespawnTime seconds after dying, as a random character
	Settings: TuskConfig.StandBots (Enabled = false turns them off).
	Tagged "SpinFighter" so every client draws their Stand, outfit and effects.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)

local StandBots = {}
local S -- TuskService
local cfg
local folder
local bots = {}
local nextId = 0

-- Body colours per character so you can tell them apart before they attack.
local LOOKS = {
	Johnny = { Skin = Color3.fromRGB(234, 190, 150), Torso = Color3.fromRGB(60, 110, 190), Legs = Color3.fromRGB(40, 40, 60) },
	Gyro = { Skin = Color3.fromRGB(226, 180, 140), Torso = Color3.fromRGB(102, 64, 150), Legs = Color3.fromRGB(70, 46, 110) },
	Diego = { Skin = Color3.fromRGB(240, 200, 165), Torso = Color3.fromRGB(60, 120, 90), Legs = Color3.fromRGB(40, 50, 45) },
	PorkPie = { Skin = Color3.fromRGB(205, 150, 110), Torso = Color3.fromRGB(95, 115, 45), Legs = Color3.fromRGB(95, 115, 45) },
	Sandman = { Skin = Color3.fromRGB(170, 115, 80), Torso = Color3.fromRGB(200, 160, 100), Legs = Color3.fromRGB(120, 85, 55) },
}

local usedSpots = {} -- [spot index] = slot using it

local function groundAt(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
	return hit and hit.Position + Vector3.new(0, 3, 0) or pos
end

-- A free spot round the map (or, with no map, a camp near the spawn).
local function findHome(slot, count)
	local map = workspace:FindFirstChild("SBRMap")
	local spots = cfg.Spots
	if map and spots and #spots > 0 then
		local origin = map:GetAttribute("Origin") or Vector3.new()
		local free = {}
		for i in ipairs(spots) do
			if not usedSpots[i] then
				table.insert(free, i)
			end
		end
		if #free > 0 then
			local i = free[math.random(1, #free)]
			usedSpots[i] = slot
			return groundAt(origin + spots[i]), i
		end
	end
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = spawn and spawn.CFrame or CFrame.new(0, 5, 0)
	local spread = (slot - (count + 1) / 2) * (cfg.Spacing or 14)
	return groundAt((base * CFrame.new(spread, 0, cfg.Distance or 70)).Position), nil
end

-- Characters this server can actually play, as their start Acts.
local function playableActs()
	local list = {}
	for _, who in ipairs(cfg.Characters or {}) do
		local act = Registry.StartAct[who]
		if act and S.hasAct(act) then
			table.insert(list, { Who = who, Act = act })
		end
	end
	return list
end

-- A table that looks enough like a Player for the move code.
local function newBotPlayer(name, model)
	nextId = nextId + 1
	local attrs = {}
	return {
		Name = name,
		DisplayName = name,
		UserId = -1000 - nextId,
		Character = model,
		Neutral = true,
		IsBot = true,
		GetAttribute = function(_, k)
			return attrs[k]
		end,
		SetAttribute = function(_, k, v)
			attrs[k] = v
		end,
	}
end

local function buildModel(who)
	local look = LOOKS[who] or LOOKS.Johnny
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = look.Skin
	desc.LeftArmColor = look.Skin
	desc.RightArmColor = look.Skin
	desc.TorsoColor = look.Torso
	desc.LeftLegColor = look.Legs
	desc.RightLegColor = look.Legs
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[StandBots] couldn't create an NPC body: " .. tostring(model))
		return nil
	end
	return model
end

local spawnBot -- (defined below; respawn calls it)

local function removeBot(bot)
	bots[bot.Slot] = nil
	if bot.Spot and usedSpots[bot.Spot] == bot.Slot then
		usedSpots[bot.Spot] = nil
	end
	S.removeBot(bot.Player)
	if bot.Model then
		bot.Model:Destroy()
	end
end

function spawnBot(slot)
	local choices = playableActs()
	if #choices == 0 then
		return
	end
	local pick = choices[math.random(1, #choices)]
	local model = buildModel(pick.Who)
	if not model then
		return
	end
	local roster
	for _, entry in ipairs(TuskConfig.Roster or {}) do
		if entry.Id == pick.Who then
			roster = entry
		end
	end
	local name = "Stand User: " .. (roster and roster.Name or pick.Who)
	model.Name = name
	local home, spot = findHome(slot, cfg.Count)
	model:PivotTo(CFrame.new(home))
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 80
	humanoid.HealthDisplayDistance = 80
	humanoid.MaxHealth = cfg.Health or 200
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = cfg.WalkSpeed or 15
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		pcall(function()
			root:SetNetworkOwner(nil) -- the server drives NPCs
		end)
	end
	local botPlayer = newBotPlayer(name, model)
	local bot = { Slot = slot, Spot = spot, Player = botPlayer, Model = model, Humanoid = humanoid, Home = home, Who = pick.Who, NextThink = 0, NextAbility = os.clock() + 2, NextUlt = 0 }
	bots[slot] = bot
	bot.State = S.addBot(botPlayer, pick.Act)
	CollectionService:AddTag(model, "SpinFighter")
	humanoid.Died:Connect(function()
		task.delay(cfg.RespawnTime or 10, function()
			if bots[slot] == bot then
				removeBot(bot)
				spawnBot(slot)
			end
		end)
	end)
end

-- Nearest player in range.
local function findTarget(bot, root)
	local best, bestDist
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local tr = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if tr and hum and hum.Health > 0 and S.Adapter.canBeHit(bot.Player, character) then
			local d = (tr.Position - root.Position).Magnitude
			local fromHome = (tr.Position - bot.Home).Magnitude
			if d <= (cfg.AggroRange or 70) and fromHome <= (cfg.LeashRange or 120) and (not bestDist or d < bestDist) then
				best, bestDist = character, d
			end
		end
	end
	return best, bestDist
end

local function useAbility(bot, module, slot, aim)
	local info = Registry.get(bot.State.Act)
	local kind = info and info.AbilityKinds and info.AbilityKinds[slot] or "Press"
	module.Ability(S, bot.Player, bot.State, slot, "Press", aim)
	if kind == "Hold" then
		local hold = 0.5 + math.random() * 0.9
		task.delay(hold, function()
			if bots[bot.Slot] == bot then
				module.Ability(S, bot.Player, bot.State, slot, "Release", aim)
			end
		end)
	end
end

local function think(bot, now)
	local model, humanoid = bot.Model, bot.Humanoid
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not root or humanoid.Health <= 0 then
		return
	end
	local state = bot.State
	local module = state.Act and S.actModule(state.Act)
	if not module then
		return
	end
	local target, dist = findTarget(bot, root)
	if not target then
		if (root.Position - bot.Home).Magnitude > 6 then
			humanoid:MoveTo(bot.Home)
		end
		return
	end
	local tr = target:FindFirstChild("HumanoidRootPart")
	local flatTarget = Vector3.new(tr.Position.X, root.Position.Y, tr.Position.Z)
	local reach = cfg.AttackRange or 6
	if dist > reach - 1 then
		humanoid:MoveTo(tr.Position - (tr.Position - root.Position).Unit * (reach - 2))
	else
		humanoid:MoveTo(root.Position)
	end
	if not S.Adapter.canAct(bot.Player) or S.isBusy(state) or state.Charging then
		return
	end
	-- Face the target and attack.
	if (flatTarget - root.Position).Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, flatTarget)
	end
	local aim = (tr.Position - root.Position).Unit
	if bot.Player:GetAttribute("TuskUlt") and bot.Player:GetAttribute("TuskUlt") >= TuskConfig.Ultimate.MaxMeter and dist < 22 and now >= bot.NextUlt then
		bot.NextUlt = now + 5
		module.Ultimate(S, bot.Player, state, aim)
		return
	end
	if now >= bot.NextAbility and dist < (cfg.AbilityRange or 35) then
		bot.NextAbility = now + (cfg.AbilityEvery or 2.5) * (0.7 + math.random() * 0.6)
		useAbility(bot, module, math.random(1, 3), aim)
		return
	end
	if dist <= reach then
		module.M1(S, bot.Player, state, aim)
	end
end

function StandBots.init(TuskService)
	S = TuskService
	cfg = TuskConfig.StandBots or {}
	if cfg.Enabled == false or (cfg.Count or 0) <= 0 then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "SpinStandBots"
	folder.Parent = workspace
	task.delay(cfg.StartDelay or 3, function()
		for slot = 1, cfg.Count do
			spawnBot(slot)
		end
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator = accumulator + dt
		if accumulator < (cfg.ThinkEvery or 0.15) then
			return
		end
		accumulator = 0
		local now = os.clock()
		for _, bot in pairs(bots) do
			local ok, err = pcall(think, bot, now)
			if not ok then
				warn("[StandBots] " .. tostring(err))
			end
		end
	end)
end

return StandBots
```
