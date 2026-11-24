---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer › TuskActs"
updated: 2026-11-22
---
# Tooru

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer › TuskActs` |
| **Exact name** | `Tooru` (capitals matter) |

**What it does:** Tooru (JoJolion): WONDER OF U. Its power is the "calamity": whoever pursues him is struck by misfortune. Registered as "Act" 16 so it reuses the Tusk ability system. M1        WONDER OF U COMBO: the old man swings his cane with him Ability 1 CALAMITY: DEBRIS: a shadow follows the nearest enemy, locks where they are, and something heavy falls out of the sky on it (a girder, a flowerpot, a road sign, a branch). Move! Ability 2 THE PURSUER'S CURSE: enemies in front are cursed for a few seconds: every time one MOVES TOWARD him, something falls on them. Back off and nothing happens Ability 3 WONDER OF U: the old man appears right beside the nearest enemy (it can be anywhere) and sweeps their legs with his cane Ultimate  THE FLOW OF CALAMITY: for a while nobody can hit him: anyone whose attack would land is struck by calamity instead, and anyone close who moves toward him has debris dropped on them Numbers: TuskConfig.Tooru. All damage goes through S.hit (CombatAdapter). Falling things take FallTime to land and only hit whoever is still under them, so they can be dodged.

## How to add it
1. In Studio's Explorer, find **TuskActs** (ServerScriptService › SpinServer › TuskActs).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **Tooru**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	Tooru  (ServerScriptService.SpinServer.TuskActs.Tooru)

	Tooru (JoJolion): WONDER OF U. Its power is the "calamity": whoever
	pursues him is struck by misfortune. Registered as "Act" 16 so it reuses
	the Tusk ability system.
	  M1        WONDER OF U COMBO: the old man swings his cane with him
	  Ability 1 CALAMITY: DEBRIS: a shadow follows the nearest enemy, locks
	            where they are, and something heavy falls out of the sky on
	            it (a girder, a flowerpot, a road sign, a branch). Move!
	  Ability 2 THE PURSUER'S CURSE: enemies in front are cursed for a few
	            seconds: every time one MOVES TOWARD him, something falls on
	            them. Back off and nothing happens
	  Ability 3 WONDER OF U: the old man appears right beside the nearest
	            enemy (it can be anywhere) and sweeps their legs with his cane
	  Ultimate  THE FLOW OF CALAMITY: for a while nobody can hit him: anyone
	            whose attack would land is struck by calamity instead, and
	            anyone close who moves toward him has debris dropped on them
	Numbers: TuskConfig.Tooru. All damage goes through S.hit (CombatAdapter).
	Falling things take FallTime to land and only hit whoever is still under
	them, so they can be dodged.
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Tooru = {}
local cfg = TuskConfig.Tooru
local ACT = 16
local FALL_TIME = 0.3 -- seconds from "it's falling" to it landing
local KINDS = { "Girder", "Pot", "Sign", "Branch" }

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Is `target` moving toward `root` faster than `speed` studs/s?
local function pursuing(target, root, speed)
	local tr = target:FindFirstChild("HumanoidRootPart")
	if not tr then
		return false
	end
	local toHim = flat(root.Position - tr.Position)
	if toHim.Magnitude < 0.5 then
		return false
	end
	return flat(tr.AssemblyLinearVelocity):Dot(toHim.Unit) > speed
end

-- Something falls on `spot`: it lands FALL_TIME later and hits whoever is
-- still under it (everyone in `radius`, or only `only` if given).
local function fall(S, player, spot, radius, info, only)
	local kind = KINDS[math.random(1, #KINDS)]
	S.fx("Ability", { Act = ACT, Move = "Calamity", Phase = "Fall", Position = spot, Kind = kind, Radius = radius, FallTime = FALL_TIME })
	task.delay(FALL_TIME, function()
		local char = player.Character
		if not char then
			return
		end
		local hits = 0
		-- Measured from body height, not the ground (roots stand ~3 studs up).
		for _, target in ipairs(S.Hitbox.inRadius(char, spot + Vector3.new(0, 2.5, 0), radius, 6)) do
			if not only or target == only then
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr then
					local away = flat(tr.Position - spot)
					local hitInfo = table.clone(info)
					hitInfo.Direction = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
					hitInfo.Position = tr.Position
					if S.hit(player, target, hitInfo) then
						hits = hits + 1
					end
				end
			end
		end
		S.fx("Ability", { Act = ACT, Move = "Calamity", Phase = "Land", Position = spot, Kind = kind, Radius = radius, Hits = hits })
	end)
end
Tooru.fall = fall

function Tooru.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: CALAMITY: DEBRIS
---------------------------------------------------------------------------
local function debris(S, player, state, aim)
	local c = cfg.Debris
	if not ready(S, player, state, "Debris", 1) then
		return
	end
	S.startCooldown(player, state, "Debris", c.Cooldown, 1)
	S.lock(state, c.Windup + 0.15)
	local character, _, root = alive(S, player)
	local life = state.Life
	local direction = S.aim(aim, root)
	local target = Moves.findTarget(S, character, root, c.Range, c.Cone, direction)
	local troot = target and target:FindFirstChild("HumanoidRootPart")
	local spot = troot and troot.Position or root.Position + flat(direction).Unit * 30
	spot = Moves.groundBelow(spot, { character })
	S.fx("Ability", { Character = character, Act = ACT, Move = "Debris", Phase = "Mark", Target = target, Position = spot, Follow = c.Follow, Lock = c.Lock })
	-- The shadow follows them, then stops where they are.
	task.delay(c.Follow, function()
		if state.Life ~= life then
			return
		end
		local tr = target and target.Parent and target:FindFirstChild("HumanoidRootPart")
		if tr then
			spot = Moves.groundBelow(tr.Position, { character, target })
		end
		S.fx("Ability", { Act = ACT, Move = "Debris", Phase = "Lock", Position = spot, Lock = c.Lock })
		task.delay(math.max(0, c.Lock - FALL_TIME), function()
			if state.Life ~= life then
				return
			end
			fall(S, player, spot, c.Radius, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Source = "TooruDebris" })
		end)
	end)
end

---------------------------------------------------------------------------
-- 2: THE PURSUER'S CURSE
---------------------------------------------------------------------------
local function curse(S, player, state, aim)
	local c = cfg.Curse
	if not ready(S, player, state, "Curse", 2) then
		return
	end
	S.startCooldown(player, state, "Curse", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.2)
	local character, _, root = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "Curse", Phase = "Cast", Windup = c.Windup, Range = c.Range })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life, true) then
			return
		end
		local char, _, r = alive(S, player)
		local look = flat(S.aim(aim, r))
		look = look.Magnitude > 0 and look.Unit or Vector3.new(0, 0, -1)
		local cosLimit = math.cos(math.rad(c.Cone / 2))
		local cursed = {}
		local untilT = now() + c.Time
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, c.Range, 12)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and #cursed < c.MaxTargets then
				local off = flat(tr.Position - r.Position)
				if off.Magnitude < 1 or off.Unit:Dot(look) >= cosLimit then
					table.insert(cursed, { Target = target, Next = 0 })
					target:SetAttribute("CalamityCurseUntil", untilT)
				end
			end
		end
		local list = {}
		for i, entry in ipairs(cursed) do
			list[i] = entry.Target
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "Curse", Phase = "Cursed", Targets = list, Duration = c.Time })
		if #cursed == 0 then
			-- Nobody to curse: most of the cooldown back.
			S.startCooldown(player, state, "Curse", c.Cooldown * 0.35, 2)
			return
		end
		local function tick()
			local _, _, me = alive(S, player)
			local t = now()
			if not me or state.Life ~= life or t >= untilT then
				for _, entry in ipairs(cursed) do
					if entry.Target.Parent and entry.Target:GetAttribute("CalamityCurseUntil") == untilT then
						entry.Target:SetAttribute("CalamityCurseUntil", nil)
					end
				end
				return
			end
			for _, entry in ipairs(cursed) do
				local target = entry.Target
				if target.Parent and t >= entry.Next and target:GetAttribute("CalamityCurseUntil") == untilT and pursuing(target, me, c.ApproachSpeed) then
					entry.Next = t + c.Every
					local tr = target:FindFirstChild("HumanoidRootPart")
					-- It lands where they're heading.
					local spot = tr.Position + flat(tr.AssemblyLinearVelocity) * FALL_TIME * 0.8
					fall(S, player, Moves.groundBelow(spot, { target }), 4.5, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Source = "TooruCurse" }, target)
				end
			end
			task.delay(0.15, tick)
		end
		tick()
	end)
end

---------------------------------------------------------------------------
-- 3: WONDER OF U (it appears beside them)
---------------------------------------------------------------------------
local function appear(S, player, state, aim)
	local c = cfg.Appear
	if not ready(S, player, state, "Appear", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local target = Moves.findTarget(S, character, root, c.Range, 360, S.aim(aim, root))
	if not target then
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	S.startCooldown(player, state, "Appear", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local life = state.Life
	local tr = target:FindFirstChild("HumanoidRootPart")
	if not tr then
		return
	end
	-- Beside them, a little behind.
	local side = flat(tr.CFrame.RightVector)
	local at = tr.Position + (side.Magnitude > 0 and side.Unit or Vector3.new(1, 0, 0)) * 3 - flat(tr.CFrame.LookVector) * 1.5
	S.fx("Ability", { Character = character, Act = ACT, Move = "Appear", Phase = "Appear", Target = target, Position = at, Delay = c.Delay })
	task.delay(c.Delay, function()
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local spot = tr.Parent and tr.Position or at
		local hit = false
		if tr.Parent and (tr.Position - at).Magnitude <= c.Radius + 3 then
			local dir = flat(tr.Position - at)
			hit = S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, 1), Position = spot, Source = "TooruCane" })
		end
		S.fx("Ability", { Act = ACT, Move = "Appear", Phase = "Sweep", Position = at, Target = target, Hit = hit })
	end)
end

function Tooru.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		debris(S, player, state, aim)
	elseif slot == 2 then
		curse(S, player, state, aim)
	elseif slot == 3 then
		appear(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- THE FLOW OF CALAMITY (ultimate)
---------------------------------------------------------------------------
local guards = setmetatable({}, { __mode = "k" }) -- [character] = { Player, Until, Last = {} }

local function installGuard(S)
	if S.Adapter.DodgeHandlers.CalamityGuard then
		return
	end
	-- Any hit on a guarded Tooru is cancelled; the attacker meets calamity.
	S.Adapter.DodgeHandlers.CalamityGuard = function(attackerPlayer, target)
		local g = guards[target]
		local u = cfg.Ultimate
		local attacker = attackerPlayer and attackerPlayer.Character
		local ar = attacker and attacker:FindFirstChild("HumanoidRootPart")
		if not g or now() > g.Until or not ar then
			return
		end
		local t = now()
		if (g.Last[attacker] or 0) > t then
			return
		end
		g.Last[attacker] = t + u.ReflectEvery
		S.fx("Ability", { Act = ACT, Move = "Calamity", Phase = "Reflect", Position = ar.Position, Target = attacker, Kind = KINDS[math.random(1, #KINDS)] })
		local tr = target:FindFirstChild("HumanoidRootPart")
		local away = tr and flat(ar.Position - tr.Position) or Vector3.new(0, 0, 1)
		S.hit(g.Player, attacker, { Damage = u.ReflectDamage, Stun = u.ReflectStun, Knockback = 10, Direction = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1), Position = ar.Position, Source = "TooruReflect" })
	end
end

local function endGuard(character)
	if character then
		guards[character] = nil
		character:SetAttribute("CalamityGuard", nil)
	end
end

function Tooru.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	installGuard(S)
	local character = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.2)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Charge", Windup = u.Windup, Duration = u.Duration })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local untilT = now() + u.Duration
		guards[character] = { Player = player, Until = untilT, Last = {} }
		character:SetAttribute("CalamityGuard", untilT)
		S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Active", Duration = u.Duration, Range = u.Range })
		local nextFor = {}
		local function tick()
			local char, _, r = alive(S, player)
			if not r or state.Life ~= life or now() >= untilT or char ~= character then
				endGuard(character)
				S.fx("Ultimate", { Character = character, Act = ACT, Phase = "End" })
				return
			end
			local t = now()
			for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, u.Range, 12)) do
				if t >= (nextFor[target] or 0) and pursuing(target, r, u.ApproachSpeed) then
					nextFor[target] = t + u.Every
					local tr = target:FindFirstChild("HumanoidRootPart")
					local spot = tr.Position + flat(tr.AssemblyLinearVelocity) * FALL_TIME * 0.8
					fall(S, player, Moves.groundBelow(spot, { target }), 5, { Damage = u.Damage, Stun = u.Stun, Knockback = u.Knockback, Source = "TooruFlow" }, target)
				end
			end
			task.delay(0.2, tick)
		end
		tick()
	end)
end

function Tooru.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		endGuard(character)
	end
end

return Tooru
```
