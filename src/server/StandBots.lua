--[[
	StandBots  (ServerScriptService.SpinServer.StandBots)

	Enemy NPCs that fight you with a Stand. Each one plays a real character
	(Johnny / Tusk, Gyro, Diego, Pork Pie Hat Kid, Sandman, Mountain Tim, Hot Pants, Blackmore, Axl RO, Funny Valentine, Diego (AU), Josuke (8), Tooru, Jodio, John Rod, Ringo Roadagain, Jotaro, DIO, Joseph, Polnareff, Josuke (4), Kira, Okuyasu, Rohan, Giorno:
	whichever are installed) through exactly the same move code as players, so their M1s,
	abilities and ultimates hit, stun and look the same.
	  * they're scattered round the map (TuskConfig.StandBots.Spots), chase
	    any player who comes within AggroRange and walk back to their spot
	    when the player gets away
	  * each NPC has its OWN fixed camp (slot 1 always camps at Spots[1], and
	    so on) and respawns there; camps are kept well away from the Saint's
	    Corpse spots and the race course
	  * M1 combo up close, abilities on cooldown, ultimate when their meter is full
	  * hold abilities are charged and released automatically
	  * they block now and then, dash in to close the gap, and dash away when hurt
	  * a remote Stand (John Rod) steered near them sends them after its USER
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
	MountainTim = { Skin = Color3.fromRGB(226, 180, 140), Torso = Color3.fromRGB(70, 90, 130), Legs = Color3.fromRGB(60, 50, 70) },
	HotPants = { Skin = Color3.fromRGB(238, 196, 164), Torso = Color3.fromRGB(96, 60, 120), Legs = Color3.fromRGB(238, 196, 164) },
	Blackmore = { Skin = Color3.fromRGB(220, 196, 176), Torso = Color3.fromRGB(36, 44, 70), Legs = Color3.fromRGB(30, 30, 40) },
	Valentine = { Skin = Color3.fromRGB(240, 210, 190), Torso = Color3.fromRGB(236, 230, 220), Legs = Color3.fromRGB(40, 44, 70) },
	Axl = { Skin = Color3.fromRGB(230, 196, 160), Torso = Color3.fromRGB(110, 116, 128), Legs = Color3.fromRGB(46, 42, 50) },
	DiegoAU = { Skin = Color3.fromRGB(240, 205, 170), Torso = Color3.fromRGB(110, 200, 185), Legs = Color3.fromRGB(196, 170, 110) },
	Josuke = { Skin = Color3.fromRGB(214, 168, 130), Torso = Color3.fromRGB(240, 240, 236), Legs = Color3.fromRGB(236, 236, 232) },
	Polnareff = { Skin = Color3.fromRGB(236, 200, 170), Torso = Color3.fromRGB(30, 32, 44), Legs = Color3.fromRGB(228, 222, 202) },
	Joseph = { Skin = Color3.fromRGB(226, 186, 150), Torso = Color3.fromRGB(40, 52, 84), Legs = Color3.fromRGB(178, 152, 110) },
	Dio = { Skin = Color3.fromRGB(240, 210, 180), Torso = Color3.fromRGB(26, 26, 30), Legs = Color3.fromRGB(214, 164, 72) },
	Jotaro = { Skin = Color3.fromRGB(214, 170, 130), Torso = Color3.fromRGB(36, 36, 42), Legs = Color3.fromRGB(36, 36, 42) },
	Rohan = { Skin = Color3.fromRGB(240, 210, 184), Torso = Color3.fromRGB(214, 232, 196), Legs = Color3.fromRGB(40, 70, 52) },
	Giorno = { Skin = Color3.fromRGB(240, 206, 176), Torso = Color3.fromRGB(196, 96, 196), Legs = Color3.fromRGB(196, 96, 196) },
	Okuyasu = { Skin = Color3.fromRGB(226, 184, 150), Torso = Color3.fromRGB(34, 40, 70), Legs = Color3.fromRGB(34, 40, 70) },
	Kira = { Skin = Color3.fromRGB(236, 206, 176), Torso = Color3.fromRGB(150, 116, 180), Legs = Color3.fromRGB(150, 116, 180) },
	Josuke4 = { Skin = Color3.fromRGB(226, 186, 150), Torso = Color3.fromRGB(38, 38, 82), Legs = Color3.fromRGB(38, 38, 82) },
	Ringo = { Skin = Color3.fromRGB(206, 146, 100), Torso = Color3.fromRGB(240, 240, 244), Legs = Color3.fromRGB(240, 240, 244) },
	JohnRod = { Skin = Color3.fromRGB(226, 190, 160), Torso = Color3.fromRGB(90, 96, 110), Legs = Color3.fromRGB(52, 54, 64) },
	Jodio = { Skin = Color3.fromRGB(236, 200, 166), Torso = Color3.fromRGB(34, 34, 64), Legs = Color3.fromRGB(36, 42, 84) },
	Tooru = { Skin = Color3.fromRGB(232, 196, 166), Torso = Color3.fromRGB(120, 60, 170), Legs = Color3.fromRGB(222, 190, 70) },
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
		-- Each slot always camps at its own spot (the same place every respawn).
		local i = (spots[slot] and not usedSpots[slot]) and slot or free[1]
		if i then
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
	-- Sight plundered (Soft & Wet): they can't see anyone.
	if bot.Model and (bot.Model:GetAttribute("BlindUntil") or 0) > workspace:GetServerTimeNow() then
		return nil
	end
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
			-- A remote Stand (John Rod) being steered near them: they go after
			-- its USER, wherever they're standing (within the Stand's range).
			local remote = character:GetAttribute("RodPiloting") and character:GetAttribute("StandRemotePos")
			if typeof(remote) == "Vector3" and (remote - root.Position).Magnitude <= (cfg.AggroRange or 70) then
				local pilotRange = (TuskConfig.JohnRod and TuskConfig.JohnRod.Pilot and TuskConfig.JohnRod.Pilot.Range) or 100
				if fromHome <= (cfg.LeashRange or 120) + pilotRange and (not bestDist or d < bestDist or best ~= character) then
					best, bestDist = character, d
					bot.HuntUntil = os.clock() + 6
				end
			elseif bot.HuntUntil and os.clock() < bot.HuntUntil and best == nil then
				-- Keep hunting the user a few seconds after the Stand's gone.
				local pilotRange = (TuskConfig.JohnRod and TuskConfig.JohnRod.Pilot and TuskConfig.JohnRod.Pilot.Range) or 100
				if fromHome <= (cfg.LeashRange or 120) + pilotRange and character == bot.LastTarget then
					best, bestDist = character, d
				end
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
			return require(script.Parent.CorpseService)
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
	bot.LastTarget = target or (bot.HuntUntil and os.clock() < bot.HuntUntil and bot.LastTarget) or nil
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
	local silenced = S.isSilenced and S.isSilenced(model)
	if not silenced and bot.Player:GetAttribute("TuskUlt") and bot.Player:GetAttribute("TuskUlt") >= TuskConfig.Ultimate.MaxMeter and dist < 22 and now >= bot.NextUlt then
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
		if not silenced then
			useAbility(bot, module, math.random(1, 3), aim)
		end
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
