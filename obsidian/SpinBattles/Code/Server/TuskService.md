---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# TuskService

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `TuskService` (capitals matter) |

**What it does:** Server brain for Tusk (the "TuskController" of the design doc): equips / switches Acts (validated against TuskActRegistry and TuskConfig.Progression) routes every TuskRequest to the active Act module or TuskSneakService owns per-player state, action locks, cooldowns, the ultimate meter gives Act modules safe helpers: hit(), fireNail(), aim(), origin()...

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **TuskService**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
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

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local Net = require(Shared.Net)
local Adapter = require(script.Parent.CombatAdapter)
local Cooldowns = require(script.Parent.CooldownService)
local Projectiles = require(script.Parent.ProjectileService)
local Hitbox = require(script.Parent.TuskHitbox)

local Request = Net.get("TuskRequest")
local FX = Net.get("TuskFX")

local TuskService = {}
TuskService.Hitbox = Hitbox
TuskService.Adapter = Adapter

local states = {} -- [player] = state
local rate = {}
local actModules = {}
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
	local state = states[player]
	if not state or not state.Act or not state.Character then
		return
	end
	local module = actModules[state.Act]

	local isJohnny = Registry.characterOf(state.Act) == "Johnny"
	if action == "Sneak" then
		if isJohnny then -- Tusk Sneak is Johnny's
			Sneak.toggle(player, state, a == true)
		end
		return
	end
	if state.Burrowed then
		return
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
		if state.Sneaking then
			Sneak.attack(player, state)
		else
			module.M1(TuskService, player, state, a)
		end
	elseif action == "Ability" then
		if typeof(a) ~= "number" or (a ~= 1 and a ~= 2 and a ~= 3) then
			return
		end
		if state.Sneaking then
			Sneak.exit(player, state, true)
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
	local actsFolder = script.Parent:WaitForChild("TuskActs")
	for act, info in pairs(Registry.Acts) do
		local moduleScript = actsFolder:FindFirstChild(info.Module or ("TuskAct" .. act))
		if moduleScript and Registry.isImplemented(act) then
			actModules[act] = require(moduleScript)
		end
	end
	Sneak = require(script.Parent.TuskSneakService)
	Sneak.init(TuskService)
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
```
