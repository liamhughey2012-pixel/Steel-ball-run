--[[
	SpinCore_Server_5  (ModuleScript)  -- part 5 of 5
	PUT IT IN: ServerScriptService > SpinCore   (make a Folder named SpinCore there if it doesn't exist)

	Part of the Spin Battlegrounds server core, split up so pasting is quick.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: TuskService
-- ======================================================================
__modules["TuskService"] = function()
--[[
	TuskService  (ServerScriptService.SpinServer.TuskService)

	Server brain for Tusk (the "TuskController" of the design doc):
	  * equips / switches Acts (validated against TuskActRegistry and
	    TuskConfig.Progression)
	  * routes every TuskRequest to the active Act module or TuskSneakService
	  * owns per-player state, action locks, cooldowns, the ultimate meter
	  * gives Act modules safe helpers: hit(), fireNail(), aim(), origin()...

	Request protocol (client -> server, TuskRequest:FireServer):
	  "Select", act          equip Act n (0 = unequip)
	  "M1", aim              basic attack (sneak attack while sneaking)
	  "Ability", slot, phase, aim   slot 1..3, phase "Press" | "Release"
	  "Ultimate", aim
	  "Sneak", on

	Attributes it sets (replicated; clients render from them):
	  Player.TuskUlt (0..Max)  Character.TuskAct  Character.TuskCharge
	  Character.TuskAwakened   Character.Armored  (Sneak ones: see TuskSneakService)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local Net = __require("Net")
local Adapter = __require("CombatAdapter")
local Cooldowns = __require("CooldownService")
local Projectiles = __require("ProjectileService")
local Hitbox = __require("TuskHitbox")

local Request = Net.get("TuskRequest")
local FX = Net.get("TuskFX")

local TuskService = {}
TuskService.Hitbox = Hitbox
TuskService.Adapter = Adapter
TuskService.Projectiles = Projectiles

local states = {} -- [player] = state
TuskService.States = states -- (read-only use: who owns a character, e.g. NPC perfect dodges)
local rate = {}
local actModules = {}
local Defense -- DefenseService (block / dash), loaded in init
local Sneak -- set in init (circular dependency)

local RATE_LIMIT = 24 -- requests per second

---------------------------------------------------------------------------
-- Helpers for Act modules
---------------------------------------------------------------------------
function TuskService.getState(player)
	return states[player]
end

function TuskService.fx(name, data)
	FX:FireAllClients(name, data)
end

function TuskService.tell(player, kind, data)
	if typeof(player) ~= "Instance" then
		return -- a Stand-user NPC (StandBots): nobody to tell
	end
	data = data or {}
	data.Kind = kind
	FX:FireClient(player, "TuskState", data)
end

function TuskService.isBusy(state)
	return os.clock() < state.LockUntil
end

function TuskService.lock(state, seconds)
	state.LockUntil = math.max(state.LockUntil, os.clock() + seconds)
end

local function cooldownKey(state, name)
	return "Tusk" .. state.Act .. "_" .. name
end

-- Returns true if ready; otherwise tells the client how long is left.
function TuskService.cooldownReady(player, state, name, slot)
	local remaining = Cooldowns.remaining(player, cooldownKey(state, name))
	if remaining > 0 then
		TuskService.tell(player, "Denied", { Reason = "Cooldown", Slot = slot, Remaining = remaining })
		return false
	end
	return true
end

function TuskService.startCooldown(player, state, name, seconds, slot)
	-- Saint's Corpse (Eyes): abilities recharge faster.
	local character = player.Character
	seconds = seconds * (character and character:GetAttribute("CorpseCooldown") or 1)
	Cooldowns.start(player, cooldownKey(state, name), seconds)
	TuskService.tell(player, "Cooldown", { Slot = slot, Duration = seconds })
end

-- A token that changes on death / Act switch, so delayed actions can
-- check they still belong to the same "life".
function TuskService.stillValid(player, state, life, allowStunned)
	if states[player] ~= state or state.Life ~= life then
		return false
	end
	if allowStunned then
		return Adapter.getAlive(player) ~= nil
	end
	return Adapter.canAct(player)
end

function TuskService.aim(aim, root)
	local fallback = root.CFrame.LookVector
	if typeof(aim) ~= "Vector3" or aim ~= aim or aim.Magnitude < 1e-3 or aim.Magnitude > 1e4 then
		return fallback
	end
	if aim.X ~= aim.X or aim.Y ~= aim.Y or aim.Z ~= aim.Z then
		return fallback
	end
	local unit = aim.Unit
	local y = math.clamp(unit.Y, -0.8, 0.8)
	local flat = Vector3.new(unit.X, 0, unit.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(fallback.X, 0, fallback.Z)
	end
	flat = flat.Unit * math.sqrt(1 - y * y)
	return Vector3.new(flat.X, y, flat.Z).Unit
end

-- Spawn point for attacks, pulled back to the root if a wall is in the way.
function TuskService.origin(character, root, offset)
	local desired = (root.CFrame * offset).Position
	if Hitbox.lineOfSight(root.Position, desired, { character }) then
		return desired
	end
	return root.Position
end

function TuskService.addUlt(player, amount)
	local max = TuskConfig.Ultimate.MaxMeter
	local state = states[player]
	local byAct = TuskConfig.Ultimate.GainByAct
	if state and state.Act and byAct and byAct[state.Act] then
		amount = amount * byAct[state.Act]
	end
	-- Saint's Corpse (Ears): the ultimate charges faster.
	local character = player.Character
	amount = amount * (character and character:GetAttribute("CorpseUltGain") or 1)
	-- Bounty board shop (Lucky Horseshoe).
	if character and (character:GetAttribute("ShopUltUntil") or 0) > workspace:GetServerTimeNow() then
		amount = amount * (character:GetAttribute("ShopUltGain") or 1)
	end
	local current = player:GetAttribute("TuskUlt") or 0
	player:SetAttribute("TuskUlt", math.clamp(current + amount, 0, max))
end

function TuskService.spendUlt(player)
	local max = TuskConfig.Ultimate.MaxMeter
	if (player:GetAttribute("TuskUlt") or 0) < max then
		TuskService.tell(player, "Denied", { Reason = "UltNotReady" })
		return false
	end
	-- Each Act must be played for a while before the next awakening.
	local state = states[player]
	local wait = TuskConfig.Ultimate.MinSecondsPerAct or 0
	if state and state.ActSince and os.clock() - state.ActSince < wait then
		TuskService.tell(player, "Denied", { Reason = "TooSoon", Remaining = wait - (os.clock() - state.ActSince) })
		return false
	end
	player:SetAttribute("TuskUlt", 0)
	return true
end

-- All Tusk damage goes through here: CombatAdapter + ultimate meter.
function TuskService.hit(player, targetCharacter, info)
	local ok, damage = Adapter.dealHit(player, targetCharacter, info)
	if ok then
		TuskService.addUlt(player, (damage or 0) * TuskConfig.Ultimate.GainPerDamage)
	end
	return ok
end

-- Server projectile with a Tusk nail visual.
function TuskService.fireNail(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "TuskNail",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = {
			Act = state.Act,
			Style = spec.Style or "Shot",
			Charge = spec.Charge or 0,
			Awakened = state.Awakened == true,
			Stage = spec.Stage,
		},
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Server projectile with a Steel Ball visual (Gyro).
function TuskService.fireBall(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "GyroBall",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = { Style = spec.Style or "Throw", Scale = spec.Scale, Bounce = spec.Bounce },
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Server projectile with a Wired fish-hook visual (Pork Pie Hat Kid).
function TuskService.fireHook(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "WiredHook",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = { Style = spec.Style or "Hook" },
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Server projectile with a written-sound visual (Sandman: In a Silent Way).
function TuskService.fireWord(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "SoundWord",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = { Text = spec.Text or "ZBAAK!", Style = spec.Style or "Slash" },
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Server projectile with a lasso visual (Mountain Tim).
function TuskService.fireLasso(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "TimLasso",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = { Style = spec.Style or "Lasso", Character = spec.Character },
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Server projectile with a frozen-raindrop visual (Blackmore).
function TuskService.fireRain(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "RainDrop",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = { Style = spec.Style or "Drop" },
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Server projectile with a piece of abandoned junk as the visual (Axl RO).
function TuskService.fireJunk(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "GuiltJunk",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = { Style = spec.Style or "Crate" },
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Server projectile with a thrown-knife visual (Diego from another world).
function TuskService.fireKnife(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "WorldKnife",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = { Style = spec.Style or "Knife" },
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Some characters walk faster or slower (Registry WalkSpeed, e.g. Sandman).
function TuskService.applyCharacterSpeed(state)
	local character = state and state.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local info = state.Act and Registry.get(state.Act)
	local mult = info and info.WalkSpeed or 1
	Adapter.setMoveModifier(humanoid, "CharacterSpeed", mult ~= 1 and mult or nil)
end

-- Charge helpers (hold abilities): sets the replicated TuskCharge attribute.
function TuskService.beginCharge(player, state, move, slot, multiplier)
	local character, humanoid = Adapter.getAlive(player)
	state.Charging = { Move = move, Slot = slot, Start = os.clock(), Token = {} }
	Adapter.setMoveModifier(humanoid, "TuskCharge", multiplier or 1)
	character:SetAttribute("TuskCharge", workspace:GetServerTimeNow())
	character:SetAttribute("TuskChargeMove", move)
	return state.Charging
end

function TuskService.endCharge(player, state)
	local charge = state.Charging
	state.Charging = nil
	local character = state.Character
	if character then
		character:SetAttribute("TuskCharge", nil)
		character:SetAttribute("TuskChargeMove", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Adapter.setMoveModifier(humanoid, "TuskCharge", nil)
		end
	end
	return charge
end

---------------------------------------------------------------------------
-- Equip / switch
---------------------------------------------------------------------------
local function cleanupAct(player, state)
	state.Life = state.Life + 1
	if Defense then
		Defense.release(player, state)
	end
	local module = state.Act and actModules[state.Act]
	if module and module.Cleanup then
		pcall(module.Cleanup, TuskService, player, state)
	end
	TuskService.endCharge(player, state)
	if Sneak then
		Sneak.exit(player, state, false)
	end
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute("TuskAwakened", nil)
	end
	state.Awakened = false
	state.Combo = 0
	state.LockUntil = 0
end

local function isUnlocked(player, act)
	local p = TuskConfig.Progression
	if p.Mode == "Awaken" then
		-- Acts are reached through ultimates; the menu is a Studio testing aid only.
		return RunService:IsStudio() and p.StudioMenu == true
	end
	if p.Mode == "Unlock" then
		return p.IsUnlocked ~= nil and p.IsUnlocked(player, act) == true
	end
	return true
end

function TuskService.select(player, act, internal)
	if typeof(act) ~= "number" or act ~= math.floor(act) then
		return
	end
	local state = states[player]
	if not state then
		return
	end
	if act == 0 then
		cleanupAct(player, state)
		state.Act = nil
		if state.Character then
			state.Character:SetAttribute("TuskAct", nil)
		end
		TuskService.tell(player, "Equipped", { Act = 0 })
		return
	end
	if not Registry.isImplemented(act) or not actModules[act] then
		TuskService.tell(player, "Denied", { Reason = "NotAvailable" })
		return
	end
	if not internal and not isUnlocked(player, act) then
		TuskService.tell(player, "Denied", { Reason = "Locked" })
		return
	end
	if state.Act == act then
		return
	end
	if not internal and (os.clock() - state.LastSwitch < TuskConfig.Progression.SwitchCooldown or TuskService.isBusy(state)) then
		TuskService.tell(player, "Denied", { Reason = "SwitchCooldown" })
		return
	end
	cleanupAct(player, state)
	state.Act = act
	state.LastSwitch = os.clock()
	TuskService.markActStart(player, state)
	player:SetAttribute("TuskSelectedAct", act)
	if state.Character then
		state.Character:SetAttribute("TuskAct", act)
	end
	TuskService.applyCharacterSpeed(state)
	TuskService.tell(player, "Equipped", { Act = act })
end

-- Remember when the current Act began (the HUD shows the lock timer).
function TuskService.markActStart(player, state)
	state.ActSince = os.clock()
	player:SetAttribute("TuskActSince", workspace:GetServerTimeNow())
end

-- Awakening: move straight to another Act (no menu rules, no switch cooldown).
function TuskService.evolve(player, state, toAct)
	if not Registry.isImplemented(toAct) or not actModules[toAct] then
		return
	end
	local from = state.Act
	cleanupAct(player, state)
	state.Act = toAct
	TuskService.markActStart(player, state)
	player:SetAttribute("TuskSelectedAct", toAct)
	if state.Character then
		state.Character:SetAttribute("TuskAct", toAct)
	end
	TuskService.applyCharacterSpeed(state)
	TuskService.fx("Evolve", { Character = state.Character, From = from, To = toAct })
	TuskService.tell(player, "Evolved", { Act = toAct })
end

-- Called by every Act's ultimate when its attack has finished.
function TuskService.finishUltimate(player, state)
	local info = Registry.get(state.Act)
	if TuskConfig.Progression.Mode == "Awaken" and info and info.Next then
		TuskService.evolve(player, state, info.Next)
	end
	if RunService:IsStudio() and TuskConfig.Ultimate.StudioRefill then
		player:SetAttribute("TuskUlt", TuskConfig.Ultimate.MaxMeter)
	end
end

---------------------------------------------------------------------------
-- Request routing
---------------------------------------------------------------------------
local function rateLimited(player)
	local r = rate[player]
	local now = os.clock()
	if not r or now - r.Start >= 1 then
		rate[player] = { Start = now, Count = 1 }
		return false
	end
	r.Count = r.Count + 1
	return r.Count > RATE_LIMIT
end

local function onRequest(player, action, a, b, c)
	if rateLimited(player) or typeof(action) ~= "string" then
		return
	end
	if action == "Select" then
		TuskService.select(player, a)
		return
	end
	if action == "Character" then
		-- Character dropdown: "Johnny" (Tusk, starts at Act 1) or "Gyro" (Ball Breaker).
		local st = states[player]
		local start = typeof(a) == "string" and Registry.StartAct[a]
		if not st or not start then
			return
		end
		if st.Act and Registry.characterOf(st.Act) == a then
			return -- already playing that character
		end
		if TuskService.isBusy(st) or st.Charging or st.Burrowed then
			return
		end
		TuskService.select(player, start, true)
		return
	end
	if action == "CorpseMove" then
		-- The character's own move, unlocked by holding a Saint's Corpse part.
		local st = states[player]
		if st and TuskService.CorpseMove then
			TuskService.CorpseMove(player, st, a)
		end
		return
	end
	if action == "RainFloat" then
		-- Blackmore standing on frozen raindrops in mid-air (the movement is the
		-- client's; this only shows the drops to everyone).
		local st = states[player]
		local character = player.Character
		if not st or not character or st.Act ~= 11 then
			return
		end
		local raining = game:GetService("ReplicatedStorage"):GetAttribute("SpinRaining") == true
			or (character:GetAttribute("RainStormUntil") or 0) > workspace:GetServerTimeNow()
		if a == true and raining then
			local cfg = TuskConfig.Blackmore and TuskConfig.Blackmore.RainWalk
			local token = tostring({})
			character:SetAttribute("RainFloating", token)
			task.delay((cfg and cfg.FloatTime or 6) + 0.5, function()
				if character:GetAttribute("RainFloating") == token then
					character:SetAttribute("RainFloating", nil)
				end
			end)
		else
			character:SetAttribute("RainFloating", nil)
		end
		return
	end
	local state = states[player]
	if not state or not state.Act or not state.Character then
		return
	end
	local module = actModules[state.Act]

	local isJohnny = Registry.characterOf(state.Act) == "Johnny"
	if action == "Sneak" then
		-- Every character can sneak (only Johnny's Tusk can burrow out of it).
		Sneak.toggle(player, state, a == true)
		return
	end
	if state.Burrowed then
		return
	end
	-- Block and Dash work for every character.
	if action == "Block" then
		Defense.block(player, state, a == true)
		return
	elseif action == "Dash" then
		Defense.dash(player, state, a)
		return
	end
	-- Attacking drops the block.
	if action == "M1" or action == "Ultimate" or (action == "Ability" and b ~= "Release") then
		Defense.release(player, state)
	end

	-- Releasing a held ability is allowed even mid-lock; everything else needs a free player.
	if action == "Ability" and b == "Release" then
		if typeof(a) == "number" and module.Ability then
			module.Ability(TuskService, player, state, a, "Release", c)
		end
		return
	end
	if not Adapter.canAct(player) then
		return
	end

	if action == "M1" then
		if state.Sneaking and isJohnny then
			Sneak.attack(player, state)
		elseif state.Sneaking then
			-- Everyone else ambushes: out of sneak, the first hit does extra damage.
			Sneak.ambush(player, state)
			module.M1(TuskService, player, state, a)
		else
			module.M1(TuskService, player, state, a)
		end
	elseif action == "Ability" then
		if typeof(a) ~= "number" or (a ~= 1 and a ~= 2 and a ~= 3) then
			return
		end
		if state.Sneaking then
			Sneak.ambush(player, state)
		end
		module.Ability(TuskService, player, state, a, "Press", c)
	elseif action == "Ultimate" then
		if state.Sneaking then
			Sneak.exit(player, state, true)
		end
		module.Ultimate(TuskService, player, state, a)
	end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local function onCharacter(player, character)
	local state = states[player]
	if not state then
		return
	end
	cleanupAct(player, state)
	state.Character = character
	state.Burrowed = false
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or states[player] ~= state or state.Character ~= character then
		return
	end
	local progression = TuskConfig.Progression
	if state.Act and progression.Mode == "Awaken" and progression.ResetOnDeath then
		-- Back to the character's first Act after dying (Johnny -> Act 1; Gyro stays Gyro).
		state.Act = Registry.StartAct[Registry.characterOf(state.Act)] or progression.DefaultAct
		TuskService.markActStart(player, state)
	end
	if state.Act then
		character:SetAttribute("TuskAct", state.Act)
	end
	TuskService.applyCharacterSpeed(state)
	humanoid.Died:Connect(function()
		if state.Character == character then
			cleanupAct(player, state)
		end
	end)
	-- Getting stunned interrupts charges and breaks sneak (counterplay).
	character:GetAttributeChangedSignal(Adapter.Settings.StunAttribute):Connect(function()
		if not Adapter.isStunned(character) or state.Character ~= character then
			return
		end
		if Defense then
			Defense.release(player, state) -- a stun knocks you out of your block
		end
		if state.Charging then
			local module = state.Act and actModules[state.Act]
			if module and module.CancelCharge then
				module.CancelCharge(TuskService, player, state)
			else
				TuskService.endCharge(player, state)
			end
			TuskService.tell(player, "Interrupted", {})
		end
		if state.Sneaking then
			Sneak.exit(player, state, true)
		end
	end)
end

local function onPlayer(player)
	states[player] = {
		Act = nil,
		Character = nil,
		Life = 0,
		Combo = 0,
		LastM1 = 0,
		LockUntil = 0,
		LastSwitch = -math.huge,
		Charging = nil,
		Sneaking = false,
		Burrowed = false,
		Awakened = false,
	}
	player:SetAttribute("TuskUlt", (RunService:IsStudio() and TuskConfig.Ultimate.StudioStartFull) and TuskConfig.Ultimate.MaxMeter or 0)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	if TuskConfig.Progression.AutoEquip then
		task.defer(TuskService.select, player, TuskConfig.Progression.DefaultAct, true)
	end
end

-- Stand-user NPCs (StandBots): a bot is a table that looks enough like a
-- Player for the move code ({ Name, UserId < 0, Character, Neutral,
-- GetAttribute, SetAttribute }). It gets a normal state and plays an Act.
function TuskService.hasAct(act)
	return actModules[act] ~= nil
end

function TuskService.actModule(act)
	return actModules[act]
end

function TuskService.addBot(bot, act)
	local state = {
		Act = nil,
		Character = bot.Character,
		Life = 0,
		Combo = 0,
		LastM1 = 0,
		LockUntil = 0,
		LastSwitch = -math.huge,
		Charging = nil,
		Sneaking = false,
		Burrowed = false,
		Awakened = false,
		IsBot = true,
	}
	states[bot] = state
	bot:SetAttribute("TuskUlt", 0)
	TuskService.select(bot, act, true)
	local humanoid = bot.Character and bot.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			if states[bot] == state then
				cleanupAct(bot, state)
			end
		end)
	end
	return state
end

function TuskService.removeBot(bot)
	local state = states[bot]
	if state then
		cleanupAct(bot, state)
		states[bot] = nil
	end
end

function TuskService.init()
	for act, info in pairs(Registry.Acts) do
		local name = info.Module or ("TuskAct" .. act)
		if Registry.isImplemented(act) and __hasModule(name) then
			-- One broken character script must not take the whole game down.
			local ok, result = pcall(__require, name)
			if ok then
				actModules[act] = result
			else
				warn("[Spin] Couldn't load " .. name .. " (character " .. tostring(info.Character) .. "): " .. tostring(result))
			end
		end
	end
	Sneak = __require("TuskSneakService")
	Sneak.init(TuskService)
	Defense = __require("DefenseService")
	Defense.init(TuskService)
	TuskService.Defense = Defense
	-- Tell every client which characters this server can actually play (each
	-- non-Johnny character is an optional script), so the menu can say so.
	local installed, seen = {}, {}
	for act in pairs(actModules) do
		local who = Registry.characterOf(act)
		if not seen[who] then
			seen[who] = true
			table.insert(installed, who)
		end
	end
	table.sort(installed)
	game:GetService("ReplicatedStorage"):SetAttribute("SpinInstalledCharacters", table.concat(installed, ","))
	print("[Spin] Characters installed: " .. table.concat(installed, ", "))

	Request.OnServerEvent:Connect(onRequest)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		if state then
			cleanupAct(player, state)
		end
		states[player] = nil
		rate[player] = nil
	end)
end

return TuskService
end

-- ======================================================================
-- MODULE: TuskSneakService
-- ======================================================================
__modules["TuskSneakService"] = function()
--[[
	TuskSneakService  (ServerScriptService.SpinServer.TuskSneakService)

	Tusk Sneak (every Act): a crouched, slowed stalking state, plus the
	Sneak Attack (M1 while sneaking):
	  1. Tusk sinks into the ground (Burrow): invisible and briefly untargetable
	  2. a distortion warning appears under the target (WarningTime before emergence)
	  3. Tusk emerges behind the target at a server-validated safe spot
	  4. surprise hit + launch, finished with a blue shockwave

	Counterplay: the warning is visible and audible, a target that moves
	MaxTargetDrift studs away is missed, getting hit breaks sneak, and both
	sneak and the attack have cooldowns.

	Every character can sneak: NPCs don't notice a sneaking player until
	they're close (StandBots), other players see them fade with distance and
	can't see their name (TuskSneakController), and bounty hunters lose
	track of them (BountyUI). Attacking out of sneak as anyone but Johnny is
	an AMBUSH: the first hit within a moment does extra damage (CombatAdapter).

	Character attributes: TuskSneaking, TuskBurrowed, AmbushUntil, SpottedUntil.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Adapter = __require("CombatAdapter")
local Cooldowns = __require("CooldownService")
local Hitbox = __require("TuskHitbox")

local TuskSneakService = {}
local S -- TuskService

local cfg = TuskConfig.Sneak

function TuskSneakService.init(service)
	S = service
end

function TuskSneakService.exit(player, state, applyCooldown)
	if not state.Sneaking then
		return
	end
	state.Sneaking = false
	state.SneakToken = nil
	local character = state.Character
	if character then
		character:SetAttribute("TuskSneaking", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Adapter.setMoveModifier(humanoid, "TuskSneak", nil)
			if state.SneakDisplay then
				humanoid.DisplayDistanceType = state.SneakDisplay
				state.SneakDisplay = nil
			end
		end
	end
	if applyCooldown then
		Cooldowns.start(player, "TuskSneak", cfg.Cooldown)
		S.tell(player, "SneakCooldown", { Duration = cfg.Cooldown })
	end
end

-- Attacking out of sneak (anyone but Johnny): leave sneak, and the first
-- hit in the next moment is an ambush (extra damage; CombatAdapter).
function TuskSneakService.ambush(player, state)
	local character = state.Character
	TuskSneakService.exit(player, state, true)
	if character then
		character:SetAttribute("AmbushUntil", workspace:GetServerTimeNow() + (cfg.AmbushWindow or 1))
	end
end

function TuskSneakService.toggle(player, state, on)
	if not on then
		TuskSneakService.exit(player, state, true)
		return
	end
	if state.Sneaking or state.Charging or S.isBusy(state) or not Adapter.canAct(player) then
		return
	end
	local remaining = Cooldowns.remaining(player, "TuskSneak")
	if remaining > 0 then
		S.tell(player, "Denied", { Reason = "SneakCooldown", Remaining = remaining })
		return
	end
	local character, humanoid = Adapter.getAlive(player)
	state.Sneaking = true
	local token = {}
	state.SneakToken = token
	character:SetAttribute("TuskSneaking", true)
	Adapter.setMoveModifier(humanoid, "TuskSneak", cfg.WalkSpeedMultiplier)
	-- Your name and health bar disappear while you sneak.
	state.SneakDisplay = humanoid.DisplayDistanceType
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	task.delay(cfg.MaxDuration, function()
		if state.SneakToken == token then
			TuskSneakService.exit(player, state, true)
		end
	end)
end

-- Nearest enemy in front, in range, with line of sight.
local function findTarget(character, root, range, coneDegrees)
	range = range or cfg.Attack.Range
	coneDegrees = coneDegrees or cfg.Attack.ConeDegrees
	local best, bestDistance
	local cosLimit = math.cos(math.rad(coneDegrees / 2))
	for _, target in ipairs(Hitbox.inRadius(character, root.Position, range)) do
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if targetRoot and Adapter.canBeHit(nil, target) then
			local offset = targetRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			if flat.Magnitude > 0.1 and flat.Unit:Dot(look.Unit) >= cosLimit then
				if Hitbox.lineOfSight(root.Position, targetRoot.Position, { character, target }) then
					if not bestDistance or offset.Magnitude < bestDistance then
						best, bestDistance = target, offset.Magnitude
					end
				end
			end
		end
	end
	return best
end

-- Safe emergence point near the target: behind first, then the sides, then in front.
-- Must have clear line of sight from the target, solid ground below and free space.
TuskSneakService.findTarget = findTarget

local function emergePoint(attacker, target, distance)
	local targetRoot = target.HumanoidRootPart
	local d = distance or cfg.Attack.EmergeDistance
	local candidates = {
		targetRoot.CFrame * CFrame.new(0, 0, d),
		targetRoot.CFrame * CFrame.new(d, 0, 0),
		targetRoot.CFrame * CFrame.new(-d, 0, 0),
		targetRoot.CFrame * CFrame.new(0, 0, -d),
	}
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { attacker, target }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { attacker, target }
	for _, cf in ipairs(candidates) do
		local pos = cf.Position
		if Hitbox.lineOfSight(targetRoot.Position, pos, { attacker, target }) then
			local ground = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), rayParams)
			if ground then
				local standPos = ground.Position + Vector3.new(0, 3, 0)
				local blocking = workspace:GetPartBoundsInBox(CFrame.new(standPos), Vector3.new(2, 4.5, 2), overlap)
				local solid = false
				for _, part in ipairs(blocking) do
					if part.CanCollide then
						solid = true
						break
					end
				end
				if not solid then
					return standPos
				end
			end
		end
	end
	return nil
end

function TuskSneakService.attack(player, state)
	local a = cfg.Attack
	if S.isBusy(state) or state.Charging then
		return
	end
	local remaining = Cooldowns.remaining(player, "TuskSneakAttack")
	if remaining > 0 then
		S.tell(player, "Denied", { Reason = "SneakAttackCooldown", Remaining = remaining })
		return
	end
	local character, _, root = Adapter.getAlive(player)
	local target = findTarget(character, root)
	if not target then
		Cooldowns.start(player, "TuskSneakAttack", a.FailCooldown)
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end

	TuskSneakService.exit(player, state, true)
	Cooldowns.start(player, "TuskSneakAttack", a.Cooldown)
	S.tell(player, "SneakAttackCooldown", { Duration = a.Cooldown })
	TuskSneakService.burrowStrike(player, state, target, a, "TuskSneakAttack")
end

--[[
	Burrow -> warning -> emerge behind the target -> hit + shockwave.
	Shared by the Sneak Attack and Act 2's Underground Pursuit.
	a = { BurrowTime, WarningTime, EmergeDistance, MaxTargetDrift, Range,
	      HitRadius, Damage, Stun, Knockback, Launch }
]]
function TuskSneakService.burrowStrike(player, state, target, a, source)
	local character, _, root = Adapter.getAlive(player)
	if not character then
		return
	end
	a = setmetatable(table.clone(a), { __index = cfg.Attack })
	S.lock(state, a.BurrowTime + 0.45)

	local life = state.Life
	local startPos = root.Position
	local targetStart = target.HumanoidRootPart.Position
	state.Burrowed = true
	character:SetAttribute("TuskBurrowed", true)
	character:SetAttribute(Adapter.Settings.IFrameAttribute, true)
	-- Anchor in place while underground so the hidden body can't wander.
	root.Anchored = true

	S.fx("SneakAttack", { Phase = "Burrow", Character = character, Position = startPos - Vector3.new(0, 2.8, 0), Target = target, BurrowTime = a.BurrowTime })

	local function surface()
		state.Burrowed = false
		if character.Parent then
			character:SetAttribute("TuskBurrowed", nil)
			character:SetAttribute(Adapter.Settings.IFrameAttribute, nil)
			if root.Parent then
				root.Anchored = false
			end
		end
	end

	task.delay(a.BurrowTime - a.WarningTime, function()
		if state.Life ~= life or not target.Parent then
			return
		end
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			S.fx("SneakAttack", { Phase = "Warning", Character = character, Target = target, Position = targetRoot.Position - Vector3.new(0, 2.8, 0), Duration = a.WarningTime })
		end
	end)

	task.delay(a.BurrowTime, function()
		if state.Life ~= life or not Adapter.getAlive(player) then
			surface()
			return
		end
		local targetRoot = target.Parent and target:FindFirstChild("HumanoidRootPart")
		local valid = targetRoot
			and Adapter.canBeHit(player, target)
			and (targetRoot.Position - targetStart).Magnitude <= a.MaxTargetDrift
			and (targetRoot.Position - startPos).Magnitude <= a.Range * 1.4
		local pos = valid and emergePoint(character, target, a.EmergeDistance) or nil

		surface()
		if not pos then
			-- Whiff: surface where we went under.
			S.fx("SneakAttack", { Phase = "Emerge", Character = character, Position = startPos - Vector3.new(0, 2.8, 0), Hit = false })
			return
		end
		local facing = Vector3.new(targetRoot.Position.X, pos.Y, targetRoot.Position.Z)
		character:PivotTo(CFrame.lookAt(pos, facing))
		S.fx("SneakAttack", { Phase = "Emerge", Character = character, Position = pos - Vector3.new(0, 2.8, 0), Hit = true })

		local hitAny = false
		for _, victim in ipairs(Hitbox.inRadius(character, pos, a.HitRadius, 3)) do
			local victimRoot = victim:FindFirstChild("HumanoidRootPart")
			if victimRoot and Hitbox.lineOfSight(pos, victimRoot.Position, { character, victim }) then
				local hit = S.hit(player, victim, {
					Damage = a.Damage,
					Stun = a.Stun,
					Knockback = a.Knockback,
					Launch = a.Launch,
					Direction = victimRoot.Position - pos,
					Position = victimRoot.Position,
					Source = source or "TuskSneakAttack",
				})
				hitAny = hitAny or hit
			end
		end
		S.fx("SneakAttack", { Phase = "Shockwave", Character = character, Position = pos - Vector3.new(0, 2.8, 0), Hit = hitAny })
	end)
end

return TuskSneakService
end

-- ======================================================================
-- MODULE: WeatherService
-- ======================================================================
__modules["WeatherService"] = function()
--[[
	WeatherService  (ServerScriptService.SpinServer.WeatherService)

	Rain for the whole server: every TuskConfig.Weather.RainEvery seconds it
	rains for RainDuration seconds. Sets these ReplicatedStorage attributes:
	  SpinRaining   true while it rains
	  SpinRainEnds  server time the rain stops
	  SpinNextRain  server time the next rain starts
	Clients draw the rain (WeatherClient). Blackmore can walk on raindrops
	while it rains (TuskActs/Blackmore + BlackmoreVFX).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local WeatherService = {}

local function now()
	return workspace:GetServerTimeNow()
end

function WeatherService.isRaining()
	return ReplicatedStorage:GetAttribute("SpinRaining") == true
end

function WeatherService.setRain(on, seconds)
	ReplicatedStorage:SetAttribute("SpinRaining", on and true or nil)
	ReplicatedStorage:SetAttribute("SpinRainEnds", on and (now() + (seconds or 60)) or nil)
end

function WeatherService.init()
	local cfg = TuskConfig.Weather
	if not cfg or cfg.Enabled == false then
		return
	end
	local first = RunService:IsStudio() and (cfg.StudioFirstRainAfter or cfg.FirstRainAfter) or cfg.FirstRainAfter
	task.spawn(function()
		local nextRain = now() + (first or cfg.RainEvery)
		while true do
			ReplicatedStorage:SetAttribute("SpinNextRain", nextRain)
			task.wait(math.max(nextRain - now(), 0.1))
			WeatherService.setRain(true, cfg.RainDuration)
			task.wait(cfg.RainDuration)
			WeatherService.setRain(false)
			nextRain = nextRain + math.max(cfg.RainEvery, cfg.RainDuration + 1)
			if nextRain < now() then
				nextRain = now() + cfg.RainEvery
			end
		end
	end)
end

return WeatherService
end
end
