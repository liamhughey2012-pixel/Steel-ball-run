--[[
	SpinCore_Server_4  (ModuleScript)  -- part 4 of 5
	PUT IT IN: ServerScriptService > SpinCore   (make a Folder named SpinCore there if it doesn't exist)

	Part of the Spin Battlegrounds server core, split up so pasting is quick.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: StandAssetLoader
-- ======================================================================
__modules["StandAssetLoader"] = function()
--[[
	StandAssetLoader  (ServerScriptService.SpinServer.StandAssetLoader)

	Loads the Stand models listed in TuskConfig.StandModels (by asset id)
	into ReplicatedStorage.SpinAssets as "TuskAct1", "TuskAct2"...
	Every client then uses that model instead of the built-in one.

	Safety: every Script, LocalScript and ModuleScript inside a loaded
	model is deleted before anyone can see it (free models sometimes hide
	harmful scripts).

	If Roblox refuses to load an asset (InsertService can only load models
	your account owns, or free models depending on Roblox's rules), the
	Output says so. Then insert the model yourself: Toolbox > search the id
	> drag it into ReplicatedStorage > put it in a Folder named SpinAssets
	> rename it TuskAct1.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local StandAssetLoader = {}

local function assetsFolder()
	local folder = ReplicatedStorage:FindFirstChild("SpinAssets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SpinAssets"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local function sanitize(model)
	local removed = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
			removed = removed + 1
		end
	end
	return removed
end

local function load(act, entry)
	local name = "TuskAct" .. act
	local folder = assetsFolder()
	if folder:FindFirstChild(name) then
		return -- already placed by hand: keep it
	end
	local ok, container = pcall(function()
		return InsertService:LoadAsset(entry.AssetId)
	end)
	if not ok or not container then
		warn(("[Spin] Could not load Stand model %d for Act %d (%s). Insert it by hand: Toolbox > drag into ReplicatedStorage.SpinAssets > rename %s."):format(entry.AssetId, act, tostring(container), name))
		return
	end
	local model = container:FindFirstChildWhichIsA("Model", true) or container
	local removed = sanitize(model)
	model.Name = name
	if not model:IsA("Model") then
		local wrapper = Instance.new("Model")
		for _, child in ipairs(model:GetChildren()) do
			child.Parent = wrapper
		end
		model = wrapper
		model.Name = name
	end
	model.Parent = folder
	container:Destroy()
	print(("[Spin] Loaded Stand model %d as %s%s"):format(entry.AssetId, name, removed > 0 and (" (removed " .. removed .. " scripts for safety)") or ""))
end

function StandAssetLoader.init()
	for act, entry in pairs(TuskConfig.StandModels or {}) do
		if entry.AssetId and entry.AssetId ~= 0 then
			task.spawn(load, act, entry)
		end
	end
end

return StandAssetLoader
end

-- ======================================================================
-- MODULE: StandBots
-- ======================================================================
__modules["StandBots"] = function()
--[[
	StandBots  (ServerScriptService.SpinServer.StandBots)

	Enemy NPCs that fight you with a Stand. Each one plays a real character
	(Johnny / Tusk, Gyro, Diego, Pork Pie Hat Kid, Sandman, Mountain Tim, Hot Pants, Blackmore, Axl RO, Funny Valentine, Diego (AU):
	whichever are installed) through exactly the same move code as players, so their M1s,
	abilities and ultimates hit, stun and look the same.
	  * they're scattered round the map (TuskConfig.StandBots.Spots), chase
	    any player who comes within AggroRange and walk back to their spot
	    when the player gets away
	  * each respawn picks a new free spot, so they move around over time
	  * M1 combo up close, abilities on cooldown, ultimate when their meter is full
	  * hold abilities are charged and released automatically
	  * they block now and then, dash in to close the gap, and dash away when hurt
	  * a sneaking player isn't noticed until they're close (TuskConfig.Sneak
	    NoticeRange), or they hit the bot; a bot that saw them keeps track for
	    a few seconds
	  * every installed character has an NPC out: a new NPC is whichever
	    character has the fewest right now (TuskConfig.StandBots.Characters)
	  * Blackmore NPCs rain walk while it rains: they step up onto frozen
	    raindrops (an invisible step only NPCs collide with) and climb
	    toward players above them
	  * idle bots walk over and pick up Saint's Corpse parts lying near their
	    camp; bots holding parts use their corpse move and drop them on death
	  * they respawn RespawnTime seconds after dying, as whoever is missing
	Settings: TuskConfig.StandBots (Enabled = false turns them off).
	Tagged "SpinFighter" so every client draws their Stand, outfit and effects.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")

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
	MountainTim = { Skin = Color3.fromRGB(226, 180, 140), Torso = Color3.fromRGB(70, 90, 130), Legs = Color3.fromRGB(60, 50, 70) },
	HotPants = { Skin = Color3.fromRGB(238, 196, 164), Torso = Color3.fromRGB(96, 60, 120), Legs = Color3.fromRGB(238, 196, 164) },
	Blackmore = { Skin = Color3.fromRGB(220, 196, 176), Torso = Color3.fromRGB(36, 44, 70), Legs = Color3.fromRGB(30, 30, 40) },
	Valentine = { Skin = Color3.fromRGB(240, 210, 190), Torso = Color3.fromRGB(236, 230, 220), Legs = Color3.fromRGB(40, 44, 70) },
	Axl = { Skin = Color3.fromRGB(230, 196, 160), Torso = Color3.fromRGB(110, 116, 128), Legs = Color3.fromRGB(46, 42, 50) },
	DiegoAU = { Skin = Color3.fromRGB(240, 205, 170), Torso = Color3.fromRGB(110, 200, 185), Legs = Color3.fromRGB(196, 170, 110) },
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
local corpseService -- (defined below with the corpse helpers)

local endRainWalk -- (rain walk, below)

local function removeBot(bot)
	endRainWalk(bot, false)
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
	-- Whoever has the fewest NPCs out right now, so every character shows up.
	local counts = {}
	for _, other in pairs(bots) do
		if other.Slot ~= slot then
			counts[other.Who] = (counts[other.Who] or 0) + 1
		end
	end
	local fewest = math.huge
	for _, c in ipairs(choices) do
		fewest = math.min(fewest, counts[c.Who] or 0)
	end
	local pool = {}
	for _, c in ipairs(choices) do
		if (counts[c.Who] or 0) == fewest then
			table.insert(pool, c)
		end
	end
	local pick = pool[math.random(1, #pool)]
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
	local bot = { Slot = slot, Spot = spot, Player = botPlayer, Model = model, Humanoid = humanoid, Home = home, Who = pick.Who, NextThink = 0, NextAbility = os.clock() + 2, NextUlt = 0, SpawnedAt = os.clock() }
	bots[slot] = bot
	bot.State = S.addBot(botPlayer, pick.Act)
	CollectionService:AddTag(model, "SpinFighter")
	humanoid.Died:Connect(function()
		endRainWalk(bot, false)
		local C = corpseService()
		if C then
			local r = model:FindFirstChild("HumanoidRootPart")
			C.dropFor(botPlayer, r and r.Position or nil)
		end
		task.delay(cfg.RespawnTime or 10, function()
			if bots[slot] == bot then
				removeBot(bot)
				spawnBot(slot)
			end
		end)
	end)
end

---------------------------------------------------------------------------
-- Blackmore NPCs: RAIN WALK (the server moves NPCs, so the server does it).
-- An invisible step under his feet that only Stand-user NPCs collide with.
---------------------------------------------------------------------------
local STEP_GROUP, BOT_GROUP = "SpinRainStep", "SpinStandBot"
local groupsReady = false

local function setupGroups()
	if groupsReady then
		return true
	end
	groupsReady = pcall(function()
		for _, g in ipairs({ STEP_GROUP, BOT_GROUP }) do
			if not PhysicsService:IsCollisionGroupRegistered(g) then
				PhysicsService:RegisterCollisionGroup(g)
			end
		end
		for _, g in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
			PhysicsService:CollisionGroupSetCollidable(STEP_GROUP, g.name, g.name == BOT_GROUP)
		end
	end)
	return groupsReady
end

local function rainingFor(model)
	if game:GetService("ReplicatedStorage"):GetAttribute("SpinRaining") == true then
		return true
	end
	return (model:GetAttribute("RainStormUntil") or 0) > workspace:GetServerTimeNow()
end

local function feetY(bot, root)
	return root.Position.Y - (bot.Humanoid.HipHeight + root.Size.Y / 2)
end

local function walkCfg()
	return (TuskConfig.Blackmore and TuskConfig.Blackmore.RainWalk) or { FloatTime = 6, MaxSteps = 8, Cooldown = 3 }
end

function endRainWalk(bot, cooldown)
	local rw = bot.RainWalk
	if not rw then
		return
	end
	bot.RainWalk = nil
	if rw.Step then
		rw.Step:Destroy()
	end
	if bot.Model and bot.Model.Parent then
		bot.Model:SetAttribute("RainFloating", nil)
	end
	if cooldown then
		bot.RainWalkReady = os.clock() + walkCfg().Cooldown + 2
	end
end

-- Jump, then a frozen raindrop catches his feet near the top of the jump.
local function rainHop(bot)
	local rw = bot.RainWalk
	if not rw or rw.Steps >= walkCfg().MaxSteps then
		return
	end
	rw.Steps = rw.Steps + 1
	rw.Hopping = true
	bot.Humanoid.Jump = true
	task.delay(0.32, function()
		if bot.RainWalk ~= rw then
			return
		end
		rw.Hopping = false
		local root = bot.Model:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		rw.Y = math.max(feetY(bot, root), rw.Y or -math.huge)
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
	end)
end

local function startRainWalk(bot, root)
	if not setupGroups() then
		return
	end
	for _, d in ipairs(bot.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = BOT_GROUP
		end
	end
	local step = Instance.new("Part")
	step.Name = "RainStep"
	step.Anchored = true
	step.CanCollide = true
	step.CanQuery = false
	step.CanTouch = false
	step.Transparency = 1
	step.Size = Vector3.new(5, 0.4, 5)
	step.CollisionGroup = STEP_GROUP
	step.CFrame = CFrame.new(root.Position.X, -10000, root.Position.Z)
	step.Parent = folder
	local token = tostring({})
	bot.RainWalk = { Step = step, Start = os.clock(), Steps = 0, Token = token }
	bot.Model:SetAttribute("RainFloating", token)
	rainHop(bot)
end

-- Every frame: keep the step under his feet.
local function stepRainWalks()
	for _, bot in pairs(bots) do
		local rw = bot.RainWalk
		if rw and rw.Step and rw.Y then
			local root = bot.Model and bot.Model:FindFirstChild("HumanoidRootPart")
			if root then
				rw.Step.CFrame = CFrame.new(root.Position.X, rw.Y - 0.2, root.Position.Z)
			end
		end
	end
end

-- Each think: start, climb toward a target above him, or end.
local function thinkRainWalk(bot, root, target)
	if bot.Who ~= "Blackmore" then
		return
	end
	local now = os.clock()
	local rw = bot.RainWalk
	if rw then
		if now - rw.Start > walkCfg().FloatTime or not rainingFor(bot.Model) or bot.Model:GetAttribute("Stunned") or bot.Humanoid.Health <= 0 then
			endRainWalk(bot, true)
			return
		end
		-- Climb toward someone above him.
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		if tr and not rw.Hopping and rw.Y and tr.Position.Y - 1 > feetY(bot, root) + 2 then
			rainHop(bot)
		end
		return
	end
	if not target or now < (bot.RainWalkReady or 0) or not rainingFor(bot.Model) then
		return
	end
	local tr = target:FindFirstChild("HumanoidRootPart")
	local above = tr and tr.Position.Y > root.Position.Y + 4
	if above or math.random() < (cfg.RainWalkChance or 0.05) then
		startRainWalk(bot, root)
	end
end

-- Can this bot see `player`? Sneaking players are only noticed up close,
-- or if they just hit the bot, or the bot saw them a moment ago.
local function notices(bot, player, character, d)
	local sneak = TuskConfig.Sneak or {}
	bot.Noticed = bot.Noticed or {}
	local now = os.clock()
	local hitMe = bot.Model and bot.Model:GetAttribute("LastAttackerId") == player.UserId
		and workspace:GetServerTimeNow() - (bot.Model:GetAttribute("LastAttackTime") or -math.huge) < 4
	if not character:GetAttribute("TuskSneaking") or d <= (sneak.NoticeRange or 12) or hitMe then
		bot.Noticed[player] = now + (sneak.NoticeMemory or 3)
	end
	return (bot.Noticed[player] or 0) > now
end

-- Nearest player in range (that the bot has noticed).
local function findTarget(bot, root)
	local best, bestDist
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local tr = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if tr and hum and hum.Health > 0 and S.Adapter.canBeHit(bot.Player, character) then
			local d = (tr.Position - root.Position).Magnitude
			local fromHome = (tr.Position - bot.Home).Magnitude
			if d <= (cfg.AggroRange or 70) and fromHome <= (cfg.LeashRange or 120) and notices(bot, player, character, d) and (not bestDist or d < bestDist) then
				best, bestDist = character, d
			end
		end
	end
	-- Tell a sneaking target they've been spotted (the HUD shows it).
	if best and best:GetAttribute("TuskSneaking") then
		best:SetAttribute("SpottedUntil", workspace:GetServerTimeNow() + 1)
	end
	return best, bestDist
end

---------------------------------------------------------------------------
-- Saint's Corpse: idle bots go and pick up parts lying near their camp; in a
-- fight, bots holding parts use their corpse move; their parts drop on death.
---------------------------------------------------------------------------
local Corpse
corpseService = function()
	if Corpse == nil then
		-- (Wrapped in a function so the bundler can rewrite the require.)
		local ok, mod = pcall(function()
			return __require("CorpseService")
		end)
		Corpse = ok and mod or false
	end
	return Corpse or nil
end

-- How many parts a model holds (CorpseParts is a comma list of ids).
local function partsHeld(model)
	local list = model and model:GetAttribute("CorpseParts")
	if type(list) ~= "string" or list == "" then
		return 0
	end
	local n = 0
	for _ in string.gmatch(list, "[^,]+") do
		n = n + 1
	end
	return n
end

local function botsHolding()
	local n = 0
	for _, other in pairs(bots) do
		n = n + partsHeld(other.Model)
	end
	return n
end

local function seekCorpse(bot, root)
	local C = corpseService()
	if not C then
		return false
	end
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	-- Not straight after spawning, not when already holding enough, and NPCs
	-- together never hoard the corpse.
	if now - (bot.SpawnedAt or 0) < (cfg.CorpseSeekDelay or 120)
		or partsHeld(bot.Model) >= (cfg.CorpseMaxPerBot or 1)
		or botsHolding() >= (cfg.CorpseMaxForBots or 3) then
		bot.CorpseGoal, bot.PickupStart = nil, nil
		return false
	end
	local goal = bot.CorpseGoal
	if not (goal and goal.Parent) then
		goal = nil
		bot.PickupStart = nil
		if now >= (bot.NextCorpseLook or 0) then
			bot.NextCorpseLook = now + (cfg.CorpseSeekEvery or 15) * (0.7 + math.random() * 0.6)
			if math.random() < (cfg.CorpseSeekChance or 0.3) then
				local best, bestD
				for _, relic in ipairs(CollectionService:GetTagged("SpinCorpse")) do
					local at = relic.Parent and relic:GetPivot().Position
					local fresh = serverNow - (relic:GetAttribute("LaidAt") or 0) < (cfg.CorpseFreshTime or 90)
					if at and not fresh and (at - bot.Home).Magnitude <= (cfg.CorpseSeekRange or 60) then
						local d = (at - root.Position).Magnitude
						if not bestD or d < bestD then
							best, bestD = relic, d
						end
					end
				end
				goal = best
			end
		end
		bot.CorpseGoal = goal
	end
	if not goal then
		return false
	end
	local at = goal:GetPivot().Position
	if (at - root.Position).Magnitude <= 7 then
		-- Kneel by it for a moment: a player can still snatch it first.
		bot.Humanoid:MoveTo(root.Position)
		bot.PickupStart = bot.PickupStart or now
		if now - bot.PickupStart >= (cfg.CorpsePickupTime or 2.5) then
			C.take(bot.Player, goal:GetAttribute("PartId"))
			bot.CorpseGoal, bot.PickupStart = nil, nil
		end
	else
		bot.PickupStart = nil
		bot.Humanoid:MoveTo(at)
	end
	return true
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
	if target then
		bot.PickupStart = nil -- a fight interrupts picking up a part
	end
	if not target then
		if bot.RainWalk then
			endRainWalk(bot, false)
		end
		if seekCorpse(bot, root) then
			return
		end
		if (root.Position - bot.Home).Magnitude > 6 then
			humanoid:MoveTo(bot.Home)
		end
		return
	end
	thinkRainWalk(bot, root, target)
	local tr = target:FindFirstChild("HumanoidRootPart")
	local flatTarget = Vector3.new(tr.Position.X, root.Position.Y, tr.Position.Z)
	local reach = cfg.AttackRange or 6
	if dist > reach - 1 then
		humanoid:MoveTo(tr.Position - (tr.Position - root.Position).Unit * (reach - 2))
	else
		humanoid:MoveTo(root.Position)
	end
	local Defense = S.Defense
	-- Holding a block: wait it out.
	if Defense and model:GetAttribute("Blocking") then
		if now >= (bot.BlockUntil or 0) then
			Defense.block(bot.Player, state, false)
		end
		return
	end
	if not S.Adapter.canAct(bot.Player) or S.isBusy(state) or state.Charging then
		return
	end
	if Defense then
		local hurt = humanoid.Health < humanoid.MaxHealth * 0.35
		-- Close in with a dash, or dash away when hurt.
		if dist > 14 and dist < 30 and math.random() < (cfg.DashChance or 0.06) then
			Defense.dash(bot.Player, state, tr.Position - root.Position)
			return
		elseif hurt and dist < 8 and math.random() < (cfg.DashChance or 0.06) then
			Defense.dash(bot.Player, state, root.Position - tr.Position)
			return
		end
		-- Block now and then when someone's right in front of them.
		if dist < reach + 2 and math.random() < (cfg.BlockChance or 0.05) then
			bot.BlockUntil = now + 0.4 + math.random() * 0.5
			Defense.block(bot.Player, state, true)
			return
		end
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
	-- Holding a corpse part: use the corpse move now and then.
	if model:GetAttribute("CorpseParts") and dist < 22 and (model:GetAttribute("CorpseReadyAt") or 0) <= workspace:GetServerTimeNow() and math.random() < (cfg.CorpseMoveChance or 0.12) and S.CorpseMove then
		S.CorpseMove(bot.Player, state, aim)
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
		stepRainWalks()
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
end

-- ======================================================================
-- MODULE: TestDummies
-- ======================================================================
__modules["TestDummies"] = function()
--[[
	TestDummies  (ServerScriptService.SpinServer.TestDummies)
	Studio-only practice targets so Spin can be tested solo.
	Never runs in a live server (guarded by RunService:IsStudio()).
	Turn off with SpinConfig.Debug.SpawnTestDummies = false.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SpinConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("SpinConfig"))

local TestDummies = {}

local function findSpawn()
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.CFrame
	end
	return CFrame.new(0, 5, 0)
end

-- Training-dummy look (blocky, built from parts): burlap sack body, straw
-- sticking out of the head and cuffs, a stitched face with button eyes, a
-- red-and-white target on the chest, rope belt, wooden peg feet.
local BURLAP = Color3.fromRGB(196, 160, 108)
local BURLAP_DARK = Color3.fromRGB(150, 116, 74)
local STRAW = Color3.fromRGB(236, 205, 110)
local ROPE = Color3.fromRGB(120, 85, 50)
local RED = Color3.fromRGB(200, 50, 45)
local WHITE = Color3.fromRGB(245, 240, 230)
local INK = Color3.fromRGB(35, 28, 24)
local WOOD = Color3.fromRGB(110, 75, 45)

local function deco(parent, name, size, color, offset)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent.Parent
	return p
end

local function dress(dummy)
	local head = dummy:FindFirstChild("Head")
	local torso = dummy:FindFirstChild("UpperTorso") or dummy:FindFirstChild("Torso")
	local lower = dummy:FindFirstChild("LowerTorso")
	for _, part in ipairs(dummy:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = BURLAP
			part.Material = Enum.Material.Fabric
		end
	end
	if head then
		local face = head:FindFirstChildOfClass("Decal")
		if face then
			face:Destroy()
		end
		local s = head.Size.Y / 1.2
		local front = -head.Size.Z / 2 - 0.02
		-- Button eyes, a stitched mouth, a seam down the middle.
		for _, side in ipairs({ -1, 1 }) do
			deco(head, "Button", Vector3.new(0.26, 0.26, 0.06) * s, INK, CFrame.new(side * 0.24 * s, 0.1 * s, front))
			deco(head, "ButtonHole", Vector3.new(0.06, 0.06, 0.04) * s, BURLAP, CFrame.new(side * 0.24 * s, 0.1 * s, front - 0.04 * s))
		end
		deco(head, "Mouth", Vector3.new(0.6, 0.05, 0.04) * s, INK, CFrame.new(0, -0.26 * s, front))
		for i = -2, 2 do
			deco(head, "Stitch", Vector3.new(0.04, 0.16, 0.04) * s, INK, CFrame.new(i * 0.12 * s, -0.26 * s, front - 0.01 * s))
		end
		deco(head, "Seam", Vector3.new(0.05, head.Size.Y + 0.02, 0.05), BURLAP_DARK, CFrame.new(0, 0, front + 0.01))
		-- Straw sticking out of the top.
		for i = 0, 6 do
			local a = i / 7 * math.pi * 2
			deco(head, "Straw", Vector3.new(0.08, 0.6, 0.08) * s, STRAW, CFrame.new(math.cos(a) * 0.25 * s, head.Size.Y / 2 + 0.15 * s, math.sin(a) * 0.25 * s) * CFrame.Angles(math.sin(a) * 0.6, 0, -math.cos(a) * 0.6))
		end
		deco(head, "Tie", Vector3.new(0.5, 0.1, 0.5) * s, ROPE, CFrame.new(0, head.Size.Y / 2 - 0.02, 0))
	end
	if torso then
		local z = -torso.Size.Z / 2 - 0.03
		-- Target on the chest.
		deco(torso, "Target", Vector3.new(1.3, 1.3, 0.05), RED, CFrame.new(0, 0.1, z))
		deco(torso, "Target", Vector3.new(0.95, 0.95, 0.05), WHITE, CFrame.new(0, 0.1, z - 0.01))
		deco(torso, "Target", Vector3.new(0.6, 0.6, 0.05), RED, CFrame.new(0, 0.1, z - 0.02))
		deco(torso, "Target", Vector3.new(0.25, 0.25, 0.05), WHITE, CFrame.new(0, 0.1, z - 0.03))
		deco(torso, "Patch", Vector3.new(0.5, 0.4, 0.05), BURLAP_DARK, CFrame.new(-0.55, -0.55, z) * CFrame.Angles(0, 0, 0.2))
	end
	local waist = lower or torso
	if waist then
		local y = lower and 0 or -torso.Size.Y / 2 + 0.1
		deco(waist, "Rope", Vector3.new(waist.Size.X + 0.12, 0.2, waist.Size.Z + 0.12), ROPE, CFrame.new(0, y, 0))
		deco(waist, "RopeKnot", Vector3.new(0.3, 0.45, 0.15), ROPE, CFrame.new(0.4, y - 0.15, -waist.Size.Z / 2 - 0.08))
	end
	-- Straw cuffs at the wrists, wooden pegs for feet.
	for _, name in ipairs({ "LeftHand", "RightHand", "Left Arm", "Right Arm" }) do
		local hand = dummy:FindFirstChild(name)
		if hand then
			deco(hand, "Straw", Vector3.new(hand.Size.X + 0.15, 0.2, hand.Size.Z + 0.15), STRAW, CFrame.new(0, hand.Size.Y / 2 - 0.05, 0))
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }) do
		local foot = dummy:FindFirstChild(name)
		if foot then
			deco(foot, "Peg", Vector3.new(foot.Size.X + 0.05, 0.35, foot.Size.Z + 0.05), WOOD, CFrame.new(0, -foot.Size.Y / 2 + 0.15, 0))
		end
	end
	for _, d in ipairs(dummy:GetChildren()) do
		if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end
end

local function spawnDummy(folder, cframe, index)
	local ok, dummy = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not dummy then
		warn("[TestDummies] could not create dummy:", dummy)
		return
	end
	dummy.Name = "SpinDummy" .. index
	dummy:PivotTo(cframe)
	pcall(dress, dummy)
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.DisplayName = "Training Dummy"
	humanoid.MaxHealth = 150
	humanoid.Health = 150
	dummy.Parent = folder
	humanoid.Died:Connect(function()
		task.wait(SpinConfig.Debug.DummyRespawnTime)
		dummy:Destroy()
		spawnDummy(folder, cframe, index)
	end)
end

function TestDummies.init()
	if not RunService:IsStudio() or not SpinConfig.Debug.SpawnTestDummies then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "SpinTestDummies"
	folder.Parent = workspace
	local base = findSpawn()
	for i = 1, SpinConfig.Debug.DummyCount do
		local offset = CFrame.new((i - (SpinConfig.Debug.DummyCount + 1) / 2) * 8, 3, -30 - i * 6)
		spawnDummy(folder, base * offset * CFrame.Angles(0, math.pi, 0), i)
	end
end

return TestDummies
end

-- ======================================================================
-- MODULE: TuskAct1
-- ======================================================================
__modules["TuskAct1"] = function()
--[[
	TuskAct1  (ServerScriptService.SpinServer.TuskActs.TuskAct1)

	Server logic for Tusk Act 1, "the beginning of Spin".
	  M1        NAIL COMBO: jab, nail strike, spinning nail assist, shock finisher
	  Ability 1 NAIL SHOT: one spinning nail
	  Ability 2 NAIL BARRAGE: five nails fanned out
	  Ability 3 SPINNING NAIL: hold to charge, release (golden-blue at full charge)
	  Ultimate  TUSK AWAKENING: armored cinematic burst, then evolves to Act 2
	            (in Menu mode: 20 s Awakened buff instead)

	Every number is in TuskConfig.Act1. All hits go through S.hit()
	(CombatAdapter), all timing and cooldowns live here on the server.
	Visual events are sent with S.fx(); clients choreograph them in
	SpinClient.TuskActVFX.Act1.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local Awakening = __require("TuskAwakening")
local Act1 = {}
local cfg = TuskConfig.Act1

local HAND_OFFSET = CFrame.new(0.9, 0.55, -1.5) -- right-hand fingertip area

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function nailDamage(state, base)
	return state.Awakened and base * cfg.Ultimate.DamageMultiplier or base
end

local function cooldown(state, base)
	return state.Awakened and base * cfg.Ultimate.CooldownMultiplier or base
end

---------------------------------------------------------------------------
-- M1: NAIL COMBO
---------------------------------------------------------------------------
function Act1.M1(S, player, state, aim)
	local m = cfg.M1
	if S.isBusy(state) or state.Charging then
		return
	end
	local now = os.clock()
	if now - state.LastM1 > m.ResetAfter then
		state.Combo = 0
	end
	local index = state.Combo + 1
	state.Combo = index >= 4 and 0 or index
	state.LastM1 = now
	S.lock(state, index == 4 and m.EndLag or m.Interval)

	local character, _, root = alive(S, player)
	local hit = m.Hits[index]
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("M1", { Character = character, Act = 1, Index = index })

	task.delay(m.Windup, function()
		-- Getting stunned during the wind-up cancels the hit (trades are fair).
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		if hit.Projectile then
			local p = hit.Projectile
			S.fireNail(player, state, {
				Origin = S.origin(char, r, HAND_OFFSET),
				Direction = direction,
				Speed = p.Speed,
				Radius = p.Radius,
				Range = p.Range,
				Style = "M1",
				OnHit = function(target, position)
					S.hit(player, target, {
						Damage = hit.Damage,
						Stun = hit.Stun,
						Knockback = hit.Knockback,
						Direction = direction,
						Position = position,
						Source = "TuskM1",
					})
				end,
			})
			return
		end

		local boxCF = r.CFrame * CFrame.new(0, 0, -m.HitboxForward)
		local targets = S.Hitbox.inBox(char, boxCF, m.HitboxSize, m.MaxTargets)
		local landed = false
		for _, target in ipairs(targets) do
			local targetRoot = target:FindFirstChild("HumanoidRootPart")
			if targetRoot and S.Hitbox.lineOfSight(r.Position, targetRoot.Position, { char, target }) then
				local ok = S.hit(player, target, {
					Damage = hit.Damage,
					Stun = hit.Stun,
					Knockback = hit.Knockback,
					Launch = hit.Launch,
					Direction = targetRoot.Position - r.Position,
					Position = targetRoot.Position,
					Source = "TuskM1",
				})
				landed = landed or ok
			end
		end
		if index == 4 then
			S.fx("M1Finisher", { Character = char, Act = 1, Position = boxCF.Position, Radius = hit.ShockwaveRadius, Hit = landed })
		end
	end)
end

---------------------------------------------------------------------------
-- Abilities
---------------------------------------------------------------------------
local function nailShot(S, player, state, aim)
	local c = cfg.NailShot
	if S.isBusy(state) or state.Charging or not S.cooldownReady(player, state, "NailShot", 1) then
		return
	end
	S.startCooldown(player, state, "NailShot", cooldown(state, c.Cooldown), 1)
	S.lock(state, c.Startup + 0.2)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 1, Move = "NailShot", Phase = "Startup", Direction = direction, Startup = c.Startup })

	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		S.fireNail(player, state, {
			Origin = S.origin(char, r, HAND_OFFSET),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Shot",
			OnHit = function(target, position)
				S.hit(player, target, {
					Damage = nailDamage(state, c.Damage),
					Stun = c.Stun,
					Knockback = c.Knockback,
					Direction = direction,
					Position = position,
					Source = "TuskNailShot",
				})
			end,
		})
	end)
end

-- Fixed fan pattern (not random) so the barrage is readable and dodgeable.
local BARRAGE_PATTERN = { { 0, 0 }, { -1, 0.3 }, { 1, -0.2 }, { -0.5, -0.4 }, { 0.6, 0.5 }, { 0, 0.2 }, { -1, -0.3 } }

local function nailBarrage(S, player, state, aim)
	local c = cfg.NailBarrage
	if S.isBusy(state) or state.Charging or not S.cooldownReady(player, state, "NailBarrage", 2) then
		return
	end
	S.startCooldown(player, state, "NailBarrage", cooldown(state, c.Cooldown), 2)
	S.lock(state, c.Startup + c.Count * c.Interval + 0.15)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 1, Move = "NailBarrage", Phase = "Startup", Direction = direction, Startup = c.Startup, Count = c.Count, Interval = c.Interval })

	for i = 1, c.Count do
		task.delay(c.Startup + (i - 1) * c.Interval, function()
			if not S.stillValid(player, state, life) then
				return
			end
			local char, _, r = alive(S, player)
			local pattern = BARRAGE_PATTERN[(i - 1) % #BARRAGE_PATTERN + 1]
			local spread = math.rad(c.SpreadDegrees)
			local look = CFrame.lookAt(Vector3.new(), direction)
			local dir = (look * CFrame.Angles(pattern[2] * spread * 0.5, pattern[1] * spread, 0)).LookVector
			S.fireNail(player, state, {
				Origin = S.origin(char, r, HAND_OFFSET),
				Direction = dir,
				Speed = c.Speed,
				Radius = c.Radius,
				Range = c.Range,
				Style = "Barrage",
				OnHit = function(target, position)
					S.hit(player, target, {
						Damage = nailDamage(state, c.Damage),
						Stun = c.Stun,
						Knockback = c.Knockback,
						Direction = dir,
						Position = position,
						Source = "TuskNailBarrage",
					})
				end,
			})
		end)
	end
end

local function spinningNailRelease(S, player, state, aim)
	local c = cfg.SpinningNail
	local charge = S.endCharge(player, state)
	if not charge or charge.Move ~= "SpinningNail" then
		return
	end
	local character, _, root = alive(S, player)
	if not character then
		return
	end
	local t = math.clamp((os.clock() - charge.Start) / c.FullChargeAt, 0, 1)
	local full = t >= 1
	local direction = S.aim(aim, root)
	local function lerp(a, b)
		return a + (b - a) * t
	end
	S.startCooldown(player, state, "SpinningNail", cooldown(state, c.Cooldown), 3)
	S.lock(state, 0.3)
	S.fx("Ability", { Character = character, Act = 1, Move = "SpinningNail", Phase = "Release", Charge = t, Full = full, Direction = direction })
	S.fireNail(player, state, {
		Origin = S.origin(character, root, HAND_OFFSET),
		Direction = direction,
		Speed = lerp(c.MinSpeed, c.MaxSpeed),
		Radius = lerp(c.MinRadius, c.MaxRadius),
		Range = c.Range,
		Style = "Spinning",
		Charge = t,
		OnHit = function(target, position)
			S.hit(player, target, {
				Damage = nailDamage(state, lerp(c.MinDamage, c.MaxDamage)),
				Stun = c.Stun * (0.5 + t * 0.5),
				Knockback = c.Knockback * (0.4 + t * 0.6),
				Direction = direction,
				Position = position,
				Source = "TuskSpinningNail",
			})
		end,
	})
end

local function spinningNailPress(S, player, state)
	local c = cfg.SpinningNail
	if S.isBusy(state) or state.Charging or not S.cooldownReady(player, state, "SpinningNail", 3) then
		return
	end
	local charge = S.beginCharge(player, state, "SpinningNail", 3, c.WalkSpeedMultiplier)
	local token = charge.Token
	task.delay(c.MaxHold, function()
		if state.Charging and state.Charging.Token == token then
			spinningNailRelease(S, player, state, nil) -- auto-release forward
		end
	end)
end

function Act1.Ability(S, player, state, slot, phase, aim)
	if slot == 1 and phase == "Press" then
		nailShot(S, player, state, aim)
	elseif slot == 2 and phase == "Press" then
		nailBarrage(S, player, state, aim)
	elseif slot == 3 then
		if phase == "Press" then
			spinningNailPress(S, player, state)
		else
			spinningNailRelease(S, player, state, aim)
		end
	end
end

function Act1.CancelCharge(S, player, state)
	local charge = S.endCharge(player, state)
	if charge then
		S.startCooldown(player, state, charge.Move, 1.5, charge.Slot)
		S.fx("Ability", { Character = state.Character, Act = 1, Move = charge.Move, Phase = "Cancel" })
	end
end

---------------------------------------------------------------------------
-- Ultimate: TUSK AWAKENING
---------------------------------------------------------------------------
local function endAwakening(S, player, state)
	state.Awakened = false
	state.AwakenToken = nil
	if state.Character then
		state.Character:SetAttribute("TuskAwakened", nil)
	end
	S.tell(player, "AwakenEnded", {})
end

-- G: AWAKENING. Infinite Rotation (TuskAwakening), then Tusk awakens to Act 2.
function Act1.Ultimate(S, player, state, aim)
	return Awakening.use(S, player, state, aim)
end

function Act1.Cleanup(S, player, state)
	if state.Charging then
		S.endCharge(player, state)
	end
	if state.Awakened then
		endAwakening(S, player, state)
	end
end

return Act1
end

-- ======================================================================
-- MODULE: TuskAct2
-- ======================================================================
__modules["TuskAct2"] = function()
--[[
	TuskAct2  (ServerScriptService.SpinServer.TuskActs.TuskAct2)

	Tusk Act 2: wormhole combat.
	  M1        DIMENSIONAL COMBO: Tusk-assisted hits, portal flashes, dimensional finisher
	  Ability 1 WORMHOLE NAIL: nail opens a wormhole where it lands; a second nail
	            bursts out of an exit portal behind the nearest enemy
	  Ability 2 UNDERGROUND PURSUIT: burrow, travel under the ground, emerge behind the target
	  Ability 3 NAIL DIMENSION: three portals around the target fire converging nails,
	            then a dimensional shockwave
	  Ultimate  DIMENSIONAL STORM: six portals rain nail waves, giant blue burst,
	            then Tusk evolves to Act 3
	Numbers: TuskConfig.Act2.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")
local Awakening = __require("TuskAwakening")
local Sneak = __require("TuskSneakService")

local Act2 = {}
local cfg = TuskConfig.Act2

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Act2.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 2)
end

local function wormholeNail(S, player, state, aim)
	local c = cfg.WormholeNail
	if not ready(S, player, state, "WormholeNail", 1) then
		return
	end
	S.startCooldown(player, state, "WormholeNail", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.2)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 2, Move = "WormholeNail", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		Moves.nail(S, player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Wormhole",
			Damage = c.Damage,
			Stun = c.Stun,
			Knockback = c.Knockback,
			Source = "TuskWormholeNail",
			OnEnd = function(position, normal)
				-- Entrance wormhole where the nail landed.
				S.fx("Portal", { Act = 2, Position = position + normal * 0.5, LookAt = position + normal * 5, Radius = 2.4, Duration = c.ExitDelay + 0.35 })
				-- Exit portal behind the nearest enemy near the impact.
				local victims = S.Hitbox.inRadius(char, position, c.ExitSearch, 1)
				local victim = victims[1]
				local vr = victim and victim:FindFirstChild("HumanoidRootPart")
				if not vr then
					return
				end
				local exitPos = (vr.CFrame * CFrame.new(0, 1.5, 6)).Position
				if not S.Hitbox.lineOfSight(vr.Position, exitPos, { char, victim }) then
					exitPos = vr.Position + Vector3.new(0, 7, 0)
				end
				S.fx("Portal", { Act = 2, Position = exitPos, LookAt = vr.Position, Radius = 2.2, Duration = c.ExitDelay + 0.45 })
				task.delay(c.ExitDelay, function()
					if state.Life ~= life or not vr.Parent then
						return
					end
					local dir = (vr.Position - exitPos)
					if dir.Magnitude < 0.5 then
						return
					end
					Moves.nail(S, player, state, {
						Origin = exitPos,
						Direction = dir.Unit,
						Speed = c.Speed,
						Radius = c.Radius,
						Range = dir.Magnitude + 6,
						Style = "Wormhole",
						Damage = c.ExitDamage,
						Stun = c.Stun,
						Knockback = c.Knockback,
						Source = "TuskWormholeNail",
					})
				end)
			end,
		})
	end)
end

local function undergroundPursuit(S, player, state, aim)
	local c = cfg.UndergroundPursuit
	if not ready(S, player, state, "UndergroundPursuit", 2) then
		return
	end
	local character, _, root = alive(S, player)
	local target = Moves.findTarget(S, character, root, c.Range, c.ConeDegrees, S.aim(aim, root))
	if not target then
		S.startCooldown(player, state, "UndergroundPursuit", 1.5, 2)
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	S.startCooldown(player, state, "UndergroundPursuit", c.Cooldown, 2)
	Sneak.burrowStrike(player, state, target, {
		Range = c.Range,
		BurrowTime = c.BurrowTime,
		WarningTime = c.WarningTime,
		EmergeDistance = 3.5,
		MaxTargetDrift = 16,
		HitRadius = c.HitRadius,
		Damage = c.Damage,
		Stun = c.Stun,
		Knockback = c.Knockback,
		Launch = c.Launch,
	}, "TuskUndergroundPursuit")
end

-- Portals around a point fire converging nails, then a shockwave.
local function nailDimension(S, player, state, aim)
	local c = cfg.NailDimension
	if not ready(S, player, state, "NailDimension", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local target = Moves.findTarget(S, character, root, c.Range, c.ConeDegrees, direction)
	local center
	if target then
		center = target.HumanoidRootPart.Position
	else
		center = Moves.groundBelow(root.Position + Moves.flat(direction) * 35, { character }) + Vector3.new(0, 3, 0)
	end
	S.startCooldown(player, state, "NailDimension", c.Cooldown, 3)
	S.lock(state, 0.6)
	local yaw = math.atan2(direction.Z, direction.X)
	local portals = Moves.ring(center, c.Portals, c.PortalRadius, yaw, 4, 8)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 2, Move = "NailDimension", Phase = "Open", Portals = portals, Center = center, OpenTime = c.OpenTime })
	task.delay(c.OpenTime, function()
		if state.Life ~= life then
			return
		end
		local aimAt = (target and target.Parent and target:FindFirstChild("HumanoidRootPart")) and target.HumanoidRootPart.Position or center
		for _, pos in ipairs(portals) do
			local dir = aimAt - pos
			Moves.nail(S, player, state, {
				Origin = pos,
				Direction = dir.Unit,
				Speed = c.Speed,
				Radius = 0.8,
				Range = dir.Magnitude + 8,
				Style = "Portal",
				Damage = c.Damage,
				Stun = c.Stun,
				Knockback = c.Knockback,
				Source = "TuskNailDimension",
			})
		end
		local travel = (portals[1] - aimAt).Magnitude / c.Speed
		task.delay(travel + 0.05, function()
			if state.Life ~= life then
				return
			end
			Moves.aoe(S, player, aimAt, c.FinalRadius, { Damage = c.FinalDamage, Stun = 0.3, Knockback = 20, Launch = 12, Source = "TuskNailDimension" }, 5)
			S.fx("AbilityImpact", { Act = 2, Move = "NailDimension", Position = aimAt, Radius = c.FinalRadius })
		end)
	end)
end

function Act2.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		wormholeNail(S, player, state, aim)
	elseif slot == 2 then
		undergroundPursuit(S, player, state, aim)
	elseif slot == 3 then
		nailDimension(S, player, state, aim)
	end
end

-- DIMENSIONAL STORM
-- G: AWAKENING. Infinite Rotation (TuskAwakening), then Tusk awakens to Act 3.
function Act2.Ultimate(S, player, state, aim)
	return Awakening.use(S, player, state, aim)
end

function Act2.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
	end
end

return Act2
end

-- ======================================================================
-- MODULE: TuskAct3
-- ======================================================================
__modules["TuskAct3"] = function()
--[[
	TuskAct3  (ServerScriptService.SpinServer.TuskActs.TuskAct3)

	Tusk Act 3: master of spatial movement.
	  M1        WORMHOLE STRIKES: fast combo with portal flashes, portal uppercut finisher
	  Ability 1 DIMENSIONAL STEP: short validated portal teleport (entrance + exit portals)
	  Ability 2 SPATIAL PURSUIT: four portals around the target fire nails one after
	            another, each re-aimed at where the target is now
	  Ability 3 DIMENSIONAL BREAK: energy gathers, a large portal opens, a long
	            dimensional shockwave tears forward
	  Ultimate  INFINITE DIMENSION: layered portals around the battlefield, a giant
	            dimensional collapse, then Tusk evolves to Act 4
	Numbers: TuskConfig.Act3.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")
local Awakening = __require("TuskAwakening")

local Act3 = {}
local cfg = TuskConfig.Act3

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Act3.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 3)
end

local function dimensionalStep(S, player, state, aim)
	local c = cfg.DimensionalStep
	if not ready(S, player, state, "DimensionalStep", 1) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local destination = Moves.safeStep(character, root, direction, c.Distance)
	if not destination then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "DimensionalStep", c.Cooldown, 1)
	S.lock(state, 0.25)
	local from = root.Position
	character:SetAttribute(S.Adapter.Settings.IFrameAttribute, true)
	character:PivotTo(CFrame.lookAt(destination, destination + direction))
	S.fx("Ability", { Character = character, Act = 3, Move = "DimensionalStep", From = from, To = destination, Direction = direction })
	task.delay(c.IFrames, function()
		if character.Parent then
			character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
		end
	end)
end

local function spatialPursuit(S, player, state, aim)
	local c = cfg.SpatialPursuit
	if not ready(S, player, state, "SpatialPursuit", 2) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local target = Moves.findTarget(S, character, root, c.Range, c.ConeDegrees, direction)
	if not target then
		S.startCooldown(player, state, "SpatialPursuit", 1.5, 2)
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	S.startCooldown(player, state, "SpatialPursuit", c.Cooldown, 2)
	S.lock(state, 0.5)
	local tr = target.HumanoidRootPart
	local portals = Moves.ring(tr.Position, c.Portals, c.PortalRadius, math.random() * math.pi * 2, 3, 7)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 3, Move = "SpatialPursuit", Phase = "Open", Portals = portals, Target = target, OpenTime = c.OpenTime, Stagger = c.Stagger })
	for i, pos in ipairs(portals) do
		task.delay(c.OpenTime + (i - 1) * c.Stagger, function()
			if state.Life ~= life or not tr.Parent then
				return
			end
			local dir = tr.Position - pos -- re-aimed at the target's current position
			Moves.nail(S, player, state, {
				Origin = pos,
				Direction = dir.Unit,
				Speed = c.Speed,
				Radius = 0.8,
				Range = dir.Magnitude + 10,
				Style = "Portal",
				Damage = c.Damage,
				Stun = c.Stun,
				Knockback = c.Knockback,
				Source = "TuskSpatialPursuit",
			})
		end)
	end
end

local function dimensionalBreak(S, player, state, aim)
	local c = cfg.DimensionalBreak
	if not ready(S, player, state, "DimensionalBreak", 3) then
		return
	end
	S.startCooldown(player, state, "DimensionalBreak", c.Cooldown, 3)
	S.lock(state, c.Charge + 0.5)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 3, Move = "DimensionalBreak", Phase = "Charge", Charge = c.Charge, Direction = direction })
	task.delay(c.Charge, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local _, _, r = alive(S, player)
		local origin = r.Position
		local cf = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -(c.Length / 2 + 1))
		Moves.boxHit(S, player, cf, Vector3.new(c.Width, 9, c.Length), { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = direction, Source = "TuskDimensionalBreak" }, 6)
		S.fx("Ability", { Character = character, Act = 3, Move = "DimensionalBreak", Phase = "Release", Origin = origin, Direction = direction, Length = c.Length, Width = c.Width })
	end)
end

function Act3.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		dimensionalStep(S, player, state, aim)
	elseif slot == 2 then
		spatialPursuit(S, player, state, aim)
	elseif slot == 3 then
		dimensionalBreak(S, player, state, aim)
	end
end

-- INFINITE DIMENSION
-- G: AWAKENING. Infinite Rotation (TuskAwakening), then Tusk awakens to Act 4.
function Act3.Ultimate(S, player, state, aim)
	return Awakening.use(S, player, state, aim)
end

function Act3.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
	end
end

return Act3
end

-- ======================================================================
-- MODULE: TuskAct4
-- ======================================================================
__modules["TuskAct4"] = function()
--[[
	TuskAct4  (ServerScriptService.SpinServer.TuskActs.TuskAct4)

	Tusk Act 4: Infinite Rotation. Gold and deep blue, heavy and majestic.
	  M1        INFINITE BARRAGE: heavy punch, golden spin strike, rapid Stand
	            triple-hit, massive golden rotational finisher (area)
	  Ability 1 GOLDEN SPIN NAIL: big rotating projectile, golden impact blast
	  Ability 2 INFINITE ROTATION (hold): 3 charge stages, bigger projectile and
	            blast per stage
	  Ability 3 GOLDEN PURSUIT: golden rush to the first enemy ahead, rotational
	            strikes, huge golden shockwave
	  Ultimate  INFINITE ROTATION: 10-step cinematic, giant golden rotational
	            projectile, battlefield-wide golden shockwave (final form)
	Numbers: TuskConfig.Act4.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Act4 = {}
local cfg = TuskConfig.Act4

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Act4.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 4)
end

-- Projectile with an area blast where it lands (direct target excluded from the blast).
local function blastNail(S, player, state, spec, blastRadius, blastDamage, source)
	local directHit = {}
	local base = spec.OnHit
	spec.OnEnd = function(position, _, hitCharacter)
		if hitCharacter then
			directHit[hitCharacter] = true
		end
		Moves.aoe(S, player, position, blastRadius, { Damage = blastDamage, Stun = 0.35, Knockback = 25, Launch = 10, Source = source }, 6, directHit)
	end
	return Moves.nail(S, player, state, spec), base
end

local function goldenSpinNail(S, player, state, aim)
	local c = cfg.GoldenSpinNail
	if not ready(S, player, state, "GoldenSpinNail", 1) then
		return
	end
	S.startCooldown(player, state, "GoldenSpinNail", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.25)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 4, Move = "GoldenSpinNail", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		blastNail(S, player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Golden",
			Damage = c.Damage,
			Stun = c.Stun,
			Knockback = c.Knockback,
			Source = "TuskGoldenSpinNail",
		}, c.ImpactRadius, c.ImpactDamage, "TuskGoldenSpinNail")
	end)
end

local function infiniteRotationRelease(S, player, state, aim)
	local c = cfg.InfiniteRotation
	local charge = S.endCharge(player, state)
	if not charge or charge.Move ~= "InfiniteRotation" then
		return
	end
	local character, _, root = alive(S, player)
	if not character then
		return
	end
	local held = os.clock() - charge.Start
	local stage = 1
	for i, t in ipairs(c.Stages) do
		if held >= t then
			stage = i
		end
	end
	local direction = S.aim(aim, root)
	S.startCooldown(player, state, "InfiniteRotation", c.Cooldown, 2)
	S.lock(state, 0.4)
	S.fx("Ability", { Character = character, Act = 4, Move = "InfiniteRotation", Phase = "Release", Stage = stage, Direction = direction })
	blastNail(S, player, state, {
		Origin = S.origin(character, root, CFrame.new(0, 1.2, -2.5)),
		Direction = direction,
		Speed = c.Speed[stage],
		Radius = c.Radius[stage],
		Range = c.Range,
		Style = "Rotation",
		Charge = stage / 3,
		Damage = c.Damage[stage],
		Stun = c.Stun,
		Knockback = c.Knockback * (0.5 + stage / 6),
		Source = "TuskInfiniteRotation",
	}, c.ImpactRadius[stage], c.ImpactDamage[stage], "TuskInfiniteRotation")
end

local function infiniteRotationPress(S, player, state)
	local c = cfg.InfiniteRotation
	if not ready(S, player, state, "InfiniteRotation", 2) then
		return
	end
	local charge = S.beginCharge(player, state, "InfiniteRotation", 2, c.WalkSpeedMultiplier)
	local token = charge.Token
	task.delay(c.MaxHold, function()
		if state.Charging and state.Charging.Token == token then
			infiniteRotationRelease(S, player, state, nil)
		end
	end)
end

local function goldenPursuit(S, player, state, aim)
	local c = cfg.GoldenPursuit
	if not ready(S, player, state, "GoldenPursuit", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	-- Stop just short of the first enemy along the rush line.
	local distance = c.Distance
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, c.Distance + 4, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			local offset = tr.Position - root.Position
			local along = offset:Dot(direction)
			local side = (offset - direction * along).Magnitude
			if along > 0 and side < 5 and along - 3 < distance then
				distance = math.max(along - 3, 3)
			end
		end
	end
	local destination = Moves.safeStep(character, root, direction, distance)
	if not destination then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "GoldenPursuit", c.Cooldown, 3)
	local gather = 0.2
	S.lock(state, gather + c.Hits * c.HitInterval + 0.45)
	local life = state.Life
	local from = root.Position
	S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Gather", Direction = direction })
	task.delay(gather, function()
		if not S.stillValid(player, state, life) then
			return
		end
		character:SetAttribute(S.Adapter.Settings.IFrameAttribute, true)
		character:PivotTo(CFrame.lookAt(destination, destination + direction))
		S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Dash", From = from, To = destination })
		task.delay(0.15, function()
			if character.Parent then
				character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
			end
		end)
		local front = destination + direction * 3
		for i = 1, c.Hits do
			task.delay(i * c.HitInterval, function()
				if state.Life ~= life then
					return
				end
				Moves.aoe(S, player, front, 6, { Damage = c.HitDamage, Stun = 0.4, Knockback = 3, Direction = direction, Source = "TuskGoldenPursuit" }, 3)
				S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Hit", Position = front, Index = i })
			end)
		end
		task.delay((c.Hits + 1) * c.HitInterval, function()
			if state.Life ~= life then
				return
			end
			Moves.aoe(S, player, front, c.FinalRadius, { Damage = c.FinalDamage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = direction, Source = "TuskGoldenPursuit" }, 6)
			S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Final", Position = front, Radius = c.FinalRadius })
		end)
	end)
end

function Act4.Ability(S, player, state, slot, phase, aim)
	if slot == 1 and phase == "Press" then
		goldenSpinNail(S, player, state, aim)
	elseif slot == 2 then
		if phase == "Press" then
			infiniteRotationPress(S, player, state)
		else
			infiniteRotationRelease(S, player, state, aim)
		end
	elseif slot == 3 and phase == "Press" then
		goldenPursuit(S, player, state, aim)
	end
end

function Act4.CancelCharge(S, player, state)
	local charge = S.endCharge(player, state)
	if charge then
		S.startCooldown(player, state, charge.Move, 2, charge.Slot)
		S.fx("Ability", { Character = state.Character, Act = 4, Move = charge.Move, Phase = "Cancel" })
	end
end

-- INFINITE ROTATION (ultimate)
function Act4.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.lock(state, u.Windup + 0.6)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = 4, Phase = "Start", Windup = u.Windup, Direction = direction })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local _, _, r = alive(S, player)
		S.fx("Ultimate", { Character = character, Act = 4, Phase = "Release", Position = r.Position, Direction = direction })
		blastNail(S, player, state, {
			Origin = S.origin(character, r, CFrame.new(0, 2, -4)),
			Direction = direction,
			Speed = u.Speed,
			Radius = u.ProjectileRadius,
			Range = u.Range,
			Style = "InfiniteUlt",
			Charge = 1,
			Damage = u.Damage,
			Stun = u.Stun,
			Knockback = u.Knockback,
			Launch = u.Launch,
			Source = "TuskInfiniteRotationUlt",
		}, u.BlastRadius, u.BlastDamage, "TuskInfiniteRotationUlt")
		S.finishUltimate(player, state) -- final form: no evolution (Studio refills the meter)
	end)
end

function Act4.Cleanup(S, player, state)
	if state.Charging then
		S.endCharge(player, state)
	end
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
	end
end

return Act4
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

-- ======================================================================
-- MODULE: TuskAwakening
-- ======================================================================
__modules["TuskAwakening"] = function()
--[[
	TuskAwakening  (ServerScriptService.SpinServer.TuskAwakening)

	Johnny's AWAKENING (G on Tusk Acts 1-3): INFINITE ROTATION. A golden
	spinning nail charged with the Golden Rotation fires (stronger each Act),
	blasts where it lands, and Tusk AWAKENS one Act higher (1 -> 2 -> 3 -> 4).
	Act 4's own ultimate is the full Infinite Rotation (TuskAct4).
	You can't pick your Act: awakening is the only way up, and dying sends
	you back to Act 1 (TuskConfig.Progression).
	Numbers: TuskConfig.Awakening (one value per Act 1-3).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local TuskAwakening = {}

local function pick(list, act)
	if type(list) ~= "table" then
		return list
	end
	return list[math.clamp(act, 1, #list)]
end

function TuskAwakening.use(S, player, state, aim)
	local cfg = TuskConfig.Awakening
	local act = state.Act or 1
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = S.Adapter.getAlive(player)
	local direction = S.aim(aim, root)
	local life = state.Life
	local windup = pick(cfg.Windup, act)
	S.lock(state, windup + 0.6)
	character:SetAttribute("Armored", true)
	-- The Infinite Rotation visuals (Act 4's), scaled by the Act.
	S.fx("Ultimate", { Character = character, Act = 4, Phase = "Start", Windup = windup, Direction = direction, Awakening = act })
	task.delay(windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not S.Adapter.getAlive(player) then
			return
		end
		local _, _, r = S.Adapter.getAlive(player)
		S.fx("Ultimate", { Character = character, Act = 4, Phase = "Release", Position = r.Position, Direction = direction, Awakening = act })
		local directHit = {}
		local blastRadius, blastDamage = pick(cfg.BlastRadius, act), pick(cfg.BlastDamage, act)
		Moves.nail(S, player, state, {
			Origin = S.origin(character, r, CFrame.new(0, 2, -4)),
			Direction = direction,
			Speed = cfg.Speed,
			Radius = pick(cfg.ProjectileRadius, act),
			Range = cfg.Range,
			Style = "InfiniteUlt",
			Charge = 1,
			Damage = pick(cfg.Damage, act),
			Stun = cfg.Stun,
			Knockback = cfg.Knockback,
			Launch = cfg.Launch,
			Source = "TuskAwakening",
			OnEnd = function(position, _, hitCharacter)
				if hitCharacter then
					directHit[hitCharacter] = true
				end
				Moves.aoe(S, player, position, blastRadius, { Damage = blastDamage, Stun = 0.4, Knockback = 30, Launch = 12, Source = "TuskAwakening" }, 6, directHit)
			end,
		})
		-- ...and Tusk awakens one Act higher.
		S.finishUltimate(player, state)
	end)
end

return TuskAwakening
end

-- ======================================================================
-- MODULE: TuskHitbox
-- ======================================================================
__modules["TuskHitbox"] = function()
--[[
	TuskHitbox  (ServerScriptService.SpinServer.TuskHitbox)
	Server-side spatial queries for melee and area attacks.
	Returns unique characters (models with a Humanoid), nearest first.
]]

local TuskHitbox = {}

local function characterFromPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end
TuskHitbox.characterFromPart = characterFromPart

local function collect(parts, attacker, origin, max)
	local seen, list = {}, {}
	for _, part in ipairs(parts) do
		local character = characterFromPart(part)
		if character and character ~= attacker and not seen[character] then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart")
			if humanoid and root and humanoid.Health > 0 then
				seen[character] = true
				table.insert(list, { Character = character, Distance = (root.Position - origin).Magnitude })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Distance < b.Distance
	end)
	local out = {}
	for i = 1, math.min(#list, max or #list) do
		out[i] = list[i].Character
	end
	return out
end

local function overlapParams(attacker)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = attacker and { attacker } or {}
	return params
end

function TuskHitbox.inBox(attacker, cframe, size, max)
	local parts = workspace:GetPartBoundsInBox(cframe, size, overlapParams(attacker))
	return collect(parts, attacker, cframe.Position, max)
end

function TuskHitbox.inRadius(attacker, position, radius, max)
	local parts = workspace:GetPartBoundsInRadius(position, radius, overlapParams(attacker))
	return collect(parts, attacker, position, max)
end

-- True if nothing but characters blocks the line between the two points.
function TuskHitbox.lineOfSight(fromPos, toPos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	params.IgnoreWater = true
	local offset = toPos - fromPos
	local result = workspace:Raycast(fromPos, offset, params)
	if not result then
		return true
	end
	return characterFromPart(result.Instance) ~= nil
end

return TuskHitbox
end

-- ======================================================================
-- MODULE: TuskMoves
-- ======================================================================
__modules["TuskMoves"] = function()
--[[
	TuskMoves  (ServerScriptService.SpinServer.TuskMoves)

	Shared server building blocks for every Tusk Act, so each Act module
	only describes what makes it different:
	  m1(...)          generic 4-hit combo (portals, multi-hits, AoE finisher, nail hits)
	  findTarget(...)  nearest valid enemy in a cone with line of sight
	  aoe(...)         radius hit with line-of-sight checks
	  boxHit(...)      oriented box hit
	  safeStep(...)    validated short teleport / dash destination
	  nail(...)        fire a nail with standard damage handling
	All damage still goes through TuskService.hit -> CombatAdapter.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local TuskMoves = {}
TuskMoves.HAND = CFrame.new(0.9, 0.55, -1.5)

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 1e-3 and f.Unit or Vector3.new(0, 0, -1)
end
TuskMoves.flat = flat

---------------------------------------------------------------------------
-- Targeting and area damage
---------------------------------------------------------------------------
function TuskMoves.findTarget(S, character, root, range, coneDegrees, direction)
	local look = flat(direction or root.CFrame.LookVector)
	local cosLimit = math.cos(math.rad((coneDegrees or 360) / 2))
	local best, bestDistance
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, range)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and S.Adapter.canBeHit(nil, target) then
			local offset = tr.Position - root.Position
			local f = Vector3.new(offset.X, 0, offset.Z)
			if f.Magnitude < 0.5 or f.Unit:Dot(look) >= cosLimit then
				if S.Hitbox.lineOfSight(root.Position, tr.Position, { character, target }) then
					if not bestDistance or offset.Magnitude < bestDistance then
						best, bestDistance = target, offset.Magnitude
					end
				end
			end
		end
	end
	return best
end

-- Damage everyone in a radius (line of sight from `center`). Returns hit count.
function TuskMoves.aoe(S, player, center, radius, info, maxTargets, exclude)
	local character = player.Character
	local count = 0
	for _, target in ipairs(S.Hitbox.inRadius(character, center, radius, maxTargets or 8)) do
		if not (exclude and exclude[target]) then
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.Hitbox.lineOfSight(center, tr.Position, { character, target }) then
				local hitInfo = table.clone(info)
				hitInfo.Direction = info.Direction or (tr.Position - center)
				hitInfo.Position = tr.Position
				if S.hit(player, target, hitInfo) then
					count = count + 1
				end
			end
		end
	end
	return count
end

function TuskMoves.boxHit(S, player, cframe, size, info, maxTargets)
	local character, _, root = alive(S, player)
	local count, hitSet = 0, {}
	if not character then
		return 0, hitSet
	end
	for _, target in ipairs(S.Hitbox.inBox(character, cframe, size, maxTargets or 3)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and S.Hitbox.lineOfSight(root.Position, tr.Position, { character, target }) then
			local hitInfo = table.clone(info)
			hitInfo.Direction = info.Direction or (tr.Position - root.Position)
			hitInfo.Position = tr.Position
			if S.hit(player, target, hitInfo) then
				count = count + 1
				hitSet[target] = true
			end
		end
	end
	return count, hitSet
end

---------------------------------------------------------------------------
-- Movement
---------------------------------------------------------------------------
-- Validated destination for a short teleport/dash along a flat direction.
-- Stops before walls, needs ground below, and free space to stand in.
function TuskMoves.safeStep(character, root, direction, distance)
	local dir = flat(direction)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild("SpinClientFX") }
	local wall = workspace:Raycast(root.Position, dir * distance, params)
	local travel = wall and (wall.Distance - 2.5) or distance
	if travel < 3 then
		return nil
	end
	local groundHere = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	local height = groundHere and (root.Position.Y - groundHere.Position.Y) or 3
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	-- Walk back from the furthest point until a valid spot is found.
	local d = travel
	while d >= 3 do
		local probe = root.Position + dir * d
		local ground = workspace:Raycast(probe + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), params)
		if ground then
			local stand = Vector3.new(probe.X, ground.Position.Y + height, probe.Z)
			local blocked = false
			for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(stand), Vector3.new(2, 4.5, 2), overlap)) do
				if part.CanCollide then
					blocked = true
					break
				end
			end
			if not blocked then
				return stand
			end
		end
		d = d - 2
	end
	return nil
end

function TuskMoves.groundBelow(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position or position
end

---------------------------------------------------------------------------
-- Nails
---------------------------------------------------------------------------
--[[ spec: Origin, Direction, Speed, Radius, Range, Style, Charge,
          Damage, Stun, Knockback, Launch, Source, OnEnd ]]
function TuskMoves.nail(S, player, state, spec)
	return S.fireNail(player, state, {
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius or 0.7,
		Range = spec.Range,
		Style = spec.Style,
		Charge = spec.Charge,
		OnHit = function(target, position)
			S.hit(player, target, {
				Damage = spec.Damage,
				Stun = spec.Stun,
				Knockback = spec.Knockback,
				Launch = spec.Launch,
				Direction = spec.Direction,
				Position = position,
				Source = spec.Source or "TuskNail",
			})
		end,
		OnEnd = spec.OnEnd,
	})
end

---------------------------------------------------------------------------
-- Generic M1 combo
---------------------------------------------------------------------------
--[[ m1cfg.Hits[i] fields: Damage, Stun, Knockback, Launch,
     Portal (cosmetic), Repeat + RepeatInterval (multi-hit), AoeRadius
     (finisher hits a radius instead of the box), ShockwaveRadius (visual),
     Projectile = { Speed, Radius, Range } (nail instead of melee) ]]
function TuskMoves.m1(S, player, state, aim, m1cfg, act)
	if S.isBusy(state) or state.Charging then
		return
	end
	local now = os.clock()
	if now - state.LastM1 > m1cfg.ResetAfter then
		state.Combo = 0
	end
	local index = state.Combo + 1
	state.Combo = index >= 4 and 0 or index
	state.LastM1 = now
	local hit = m1cfg.Hits[index]
	local repeatTime = (hit.Repeat or 1) > 1 and (hit.Repeat - 1) * (hit.RepeatInterval or 0.08) or 0
	S.lock(state, (index == 4 and m1cfg.EndLag or m1cfg.Interval) + repeatTime)
	state.M1LockUntil = state.LockUntil -- (a dash can cancel this recovery)

	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("M1", { Character = character, Act = act, Index = index, Portal = hit.Portal == true, Repeat = hit.Repeat })

	local function strike(isLast)
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		if hit.Projectile then
			TuskMoves.nail(S, player, state, {
				Origin = S.origin(char, r, TuskMoves.HAND),
				Direction = direction,
				Speed = hit.Projectile.Speed,
				Radius = hit.Projectile.Radius,
				Range = hit.Projectile.Range,
				Style = "M1",
				Damage = hit.Damage,
				Stun = hit.Stun,
				Knockback = hit.Knockback,
				Source = "TuskM1",
			})
			return
		end
		local boxCF = r.CFrame * CFrame.new(0, 0, -m1cfg.HitboxForward)
		local info = { Damage = hit.Damage, Stun = hit.Stun, Knockback = hit.Knockback, Launch = hit.Launch, Source = "TuskM1" }
		local landed
		if hit.AoeRadius and isLast then
			landed = TuskMoves.aoe(S, player, boxCF.Position, hit.AoeRadius, info, 5) > 0
		else
			landed = TuskMoves.boxHit(S, player, boxCF, m1cfg.HitboxSize, info, m1cfg.MaxTargets) > 0
		end
		if index == 4 and isLast then
			S.fx("M1Finisher", { Character = char, Act = act, Position = boxCF.Position, Radius = hit.ShockwaveRadius or 7, Hit = landed })
		end
	end

	local count = hit.Repeat or 1
	for i = 1, count do
		task.delay(m1cfg.Windup + (i - 1) * (hit.RepeatInterval or 0.08), function()
			strike(i == count)
		end)
	end
end

-- Ring of points around a center (portal placement shared by server and client payloads).
function TuskMoves.ring(center, count, radius, yaw, heightA, heightB)
	local points = {}
	for i = 1, count do
		local angle = (yaw or 0) + (i - 1) / count * math.pi * 2
		local h = (i % 2 == 0) and (heightB or 6) or (heightA or 4)
		table.insert(points, center + Vector3.new(math.cos(angle) * radius, h, math.sin(angle) * radius))
	end
	return points
end

TuskMoves.Config = TuskConfig
return TuskMoves
end
end
