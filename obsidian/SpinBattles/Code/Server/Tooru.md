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

**What it does:** Tooru (JoJolion): WONDER OF U. Its power is the "calamity": whoever pursues him is struck by misfortune. Registered as "Act" 16 so it reuses the Tusk ability system. Passive   CALAMITY: anyone running at him (closing in fast from range) has something fall on them now and then M1        WONDER OF U COMBO: the old man swings his cane with him; hits on a CURSED enemy bring something down on them too Ability 1 CALAMITY: DEBRIS: three shadows in a row chase the nearest enemy; each one stops where they are and something heavy falls on it (a girder, a flowerpot, a road sign, a branch). The last is the big one. Keep moving! Ability 2 THE PURSUER'S CURSE: enemies in front are cursed for a few seconds and slowed: every time one MOVES TOWARD him, something falls on them. Back off and nothing happens Ability 3 WONDER OF U: the old man appears right beside the nearest enemy (it can be anywhere) and sweeps their legs with his cane. Press 3 AGAIN soon after to SWAP: Tooru steps out where the old man stood (a moment of untouchable) Ultimate  THE FLOW OF CALAMITY: for a while nobody can hit him: anyone whose attack would land is struck by calamity instead, and anyone close who moves toward him has debris dropped on them. When it ends, CALAMITY STORM: a big one falls on every enemy near him Numbers: TuskConfig.Tooru. All damage goes through S.hit (CombatAdapter). Falling things take FallTime to land and only hit whoever is still under them, so they can be dodged.

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
	  Passive   CALAMITY: anyone running at him (closing in fast from
	            range) has something fall on them now and then
	  M1        WONDER OF U COMBO: the old man swings his cane with him; hits
	            on a CURSED enemy bring something down on them too
	  Ability 1 CALAMITY: DEBRIS: three shadows in a row chase the nearest
	            enemy; each one stops where they are and something heavy
	            falls on it (a girder, a flowerpot, a road sign, a branch).
	            The last is the big one. Keep moving!
	  Ability 2 THE PURSUER'S CURSE: enemies in front are cursed for a few
	            seconds and slowed: every time one MOVES TOWARD him,
	            something falls on them. Back off and nothing happens
	  Ability 3 WONDER OF U: the old man appears right beside the nearest
	            enemy (it can be anywhere) and sweeps their legs with his
	            cane. Press 3 AGAIN soon after to SWAP: Tooru steps out where
	            the old man stood (a moment of untouchable)
	  Ultimate  THE FLOW OF CALAMITY: for a while nobody can hit him: anyone
	            whose attack would land is struck by calamity instead, and
	            anyone close who moves toward him has debris dropped on them.
	            When it ends, CALAMITY STORM: a big one falls on every enemy
	            near him
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
	local first = troot and troot.Position or root.Position + flat(direction).Unit * 30
	local drops = c.Drops or 1
	for i = 1, drops do
		task.delay((i - 1) * (c.Gap or 0.45), function()
			if state.Life ~= life then
				return
			end
			local tr = target and target.Parent and target:FindFirstChild("HumanoidRootPart")
			local spot = Moves.groundBelow(tr and tr.Position or first, { character, target })
			local last = i == drops
			S.fx("Ability", { Character = i == 1 and character or nil, Act = ACT, Move = "Debris", Phase = "Mark", Target = target, Position = spot, Follow = c.Follow, Lock = c.Lock, Index = i, Last = last })
			-- The shadow follows them, then stops where they are.
			task.delay(c.Follow, function()
				if state.Life ~= life then
					return
				end
				local tr2 = target and target.Parent and target:FindFirstChild("HumanoidRootPart")
				if tr2 then
					spot = Moves.groundBelow(tr2.Position, { character, target })
				end
				S.fx("Ability", { Act = ACT, Move = "Debris", Phase = "Lock", Position = spot, Lock = c.Lock, Last = last })
				task.delay(math.max(0, c.Lock - FALL_TIME), function()
					if state.Life ~= life then
						return
					end
					if last then
						fall(S, player, spot, c.Radius + 1, { Damage = c.LastDamage, Stun = c.LastStun, Knockback = c.LastKnockback, Launch = c.LastLaunch, Source = "TooruDebris" })
					else
						fall(S, player, spot, c.Radius, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Source = "TooruDebris" })
					end
				end)
			end)
		end)
	end
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
					local hum = target:FindFirstChildOfClass("Humanoid")
					if hum and c.Slow then
						S.Adapter.setMoveModifier(hum, "CalamityCurse", c.Slow)
					end
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
						local hum = entry.Target:FindFirstChildOfClass("Humanoid")
						if hum then
							S.Adapter.setMoveModifier(hum, "CalamityCurse", nil)
						end
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
-- Press 3 again soon after: Tooru steps out where the old man stood.
local function swap(S, player, state)
	local c = cfg.Appear
	local sw = state.TooruSwap
	state.TooruSwap = nil
	local character, _, root = alive(S, player)
	if not root then
		return
	end
	local from = root.Position
	local target = sw.Target
	local tr = target and target.Parent and target:FindFirstChild("HumanoidRootPart")
	local face = tr and Vector3.new(tr.Position.X, sw.At.Y, tr.Position.Z) or (sw.At + flat(root.CFrame.LookVector))
	if (face - sw.At).Magnitude < 0.1 then
		face = sw.At + Vector3.new(0, 0, -1)
	end
	root.CFrame = CFrame.lookAt(sw.At, face)
	root.AssemblyLinearVelocity = Vector3.zero
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	task.delay(c.SwapIFrames or 0.35, function()
		if character.Parent then
			character:SetAttribute(iframes, nil)
		end
	end)
	S.fx("Ability", { Character = character, Act = ACT, Move = "Appear", Phase = "Swap", From = from, To = sw.At })
end

local function appear(S, player, state, aim)
	local c = cfg.Appear
	local sw = state.TooruSwap
	if sw and sw.Life == state.Life and now() <= sw.Until and not S.isBusy(state) then
		swap(S, player, state)
		return
	end
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
	state.TooruSwap = { At = at, Target = target, Life = life, Until = now() + c.Delay + (c.SwapWindow or 2.5) }
	S.fx("Ability", { Character = character, Act = ACT, Move = "Appear", Phase = "Appear", Target = target, Position = at, Delay = c.Delay, SwapWindow = c.SwapWindow })
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
				-- CALAMITY STORM: a big one on every enemy still near him.
				local st = u.Storm
				if st and r and state.Life == life and char == character then
					local victims = S.Hitbox.inRadius(char, r.Position, u.Range, 12)
					if #victims > 0 then
						S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Storm", Count = #victims })
					end
					for _, target in ipairs(victims) do
						local tr = target:FindFirstChild("HumanoidRootPart")
						if tr then
							local spot = Moves.groundBelow(tr.Position, { target })
							S.fx("Ability", { Act = ACT, Move = "Debris", Phase = "Lock", Position = spot, Lock = st.Delay, Last = true })
							task.delay(math.max(0, st.Delay - FALL_TIME), function()
								fall(S, player, spot, st.Radius, { Damage = st.Damage, Stun = st.Stun, Knockback = st.Knockback, Launch = st.Launch, Source = "TooruStorm" })
							end)
						end
					end
				end
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
	state.TooruSwap = nil
end

---------------------------------------------------------------------------
-- PASSIVE: CALAMITY (and M1 hits on cursed enemies). Started once by
-- TuskService for everyone playing Tooru, players and NPCs alike.
---------------------------------------------------------------------------
local started = false
function Tooru.Init(S)
	if started then
		return
	end
	started = true
	local p = cfg.Passive
	local nextFor = setmetatable({}, { __mode = "k" })
	local function passiveTick()
		local t = now()
		for player, state in pairs(S.States) do
			if state.Act == ACT then
				local char, _, r = S.Adapter.getAlive(player)
				if r and not char:GetAttribute("TimeStopped") then
					for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, p.Range, 8)) do
						local tr = target:FindFirstChild("HumanoidRootPart")
						if tr and t >= (nextFor[target] or 0) and flat(tr.Position - r.Position).Magnitude > p.MinDistance and pursuing(target, r, p.ApproachSpeed) then
							nextFor[target] = t + p.Every
							local spot = tr.Position + flat(tr.AssemblyLinearVelocity) * FALL_TIME * 0.8
							fall(S, player, Moves.groundBelow(spot, { target }), p.Radius, { Damage = p.Damage, Stun = p.Stun, Knockback = p.Knockback, Source = "TooruPassive" }, target)
						end
					end
				end
			end
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(passiveTick)
			if not ok then
				warn("[Tooru] passive: " .. tostring(err))
			end
		end
	end)
	-- His M1 on a cursed enemy: something comes down on them too.
	local bonusNext = setmetatable({}, { __mode = "k" })
	S.Adapter.on("Hit", function(attackerPlayer, target, _, info)
		local b = cfg.M1.CursedBonus
		if not b or not info or info.Source ~= "TuskM1" or not attackerPlayer or not target then
			return
		end
		local state = S.States[attackerPlayer]
		if not state or state.Act ~= ACT or (target:GetAttribute("CalamityCurseUntil") or 0) <= now() then
			return
		end
		if (bonusNext[target] or 0) > now() then
			return
		end
		bonusNext[target] = now() + b.Every
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			fall(S, attackerPlayer, Moves.groundBelow(tr.Position, { target }), 4.5, { Damage = b.Damage, Stun = b.Stun, Knockback = 4, Source = "TooruCurse" }, target)
		end
	end)
end

return Tooru
```
