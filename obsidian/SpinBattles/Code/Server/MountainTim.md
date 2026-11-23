---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer › TuskActs"
updated: 2026-11-22
---
# MountainTim

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer › TuskActs` |
| **Exact name** | `MountainTim` (capitals matter) |

**What it does:** Mountain Tim: OH! LONESOME ME. The cowboy's Stand splits his body into pieces that slide along his lasso rope. Registered as "Act" 9 so it reuses the Tusk ability system. M1        LASSO COMBO: jab, jab, rope whip, overhead rope slam Ability 1 LASSO SNARE: throw the lasso; a catch SPLITS THEIR BODY apart along the rope for a moment (slowed) and drags them in Ability 2 SPLIT DODGE: he bursts into pieces hanging on rope loops. If anyone attacks him in that moment, the pieces zip along a rope to behind the attacker and he reforms with a rope-slam counter. If nobody does, he slides forward along the rope instead. Ability 3 SPLIT BARRAGE: his arm splits along the rope (shoulder, forearm, fist) and flies out punching down a line; the last punch hooks them and reels them back to him Ultimate  LONESOME ROUNDUP: ropes shoot to everyone nearby and split them apart, his pieces ride the ropes in hitting over and over, then he yanks everyone together and slams the rope down Numbers: TuskConfig.MountainTim. All damage goes through S.hit (CombatAdapter).

## How to add it
1. In Studio's Explorer, find **TuskActs** (ServerScriptService › SpinServer › TuskActs).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **MountainTim**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	MountainTim  (ServerScriptService.SpinServer.TuskActs.MountainTim)

	Mountain Tim: OH! LONESOME ME. The cowboy's Stand splits his body into
	pieces that slide along his lasso rope. Registered as "Act" 9 so it
	reuses the Tusk ability system.
	  M1        LASSO COMBO: jab, jab, rope whip, overhead rope slam
	  Ability 1 LASSO SNARE: throw the lasso; a catch SPLITS THEIR BODY apart
	            along the rope for a moment (slowed) and drags them in
	  Ability 2 SPLIT DODGE: he bursts into pieces hanging on rope loops. If
	            anyone attacks him in that moment, the pieces zip along a rope
	            to behind the attacker and he reforms with a rope-slam counter.
	            If nobody does, he slides forward along the rope instead.
	  Ability 3 SPLIT BARRAGE: his arm splits along the rope (shoulder,
	            forearm, fist) and flies out punching down a line; the last
	            punch hooks them and reels them back to him
	  Ultimate  LONESOME ROUNDUP: ropes shoot to everyone nearby and split
	            them apart, his pieces ride the ropes in hitting over and over,
	            then he yanks everyone together and slams the rope down
	Numbers: TuskConfig.MountainTim. All damage goes through S.hit (CombatAdapter).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Tim = {}
local cfg = TuskConfig.MountainTim
local ACT = 9
local HAND = CFrame.new(0.9, 0.6, -1.4)

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Tim.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

-- Rope pull toward `point` (one tick; the knockback lasts ~0.18 s).
local function pull(S, target, point, stopDistance)
	local tr = target:FindFirstChild("HumanoidRootPart")
	if not tr then
		return true
	end
	local offset = point - tr.Position
	local distance = offset.Magnitude
	if distance <= (stopDistance or 4) then
		return true
	end
	-- Mostly sideways; only lift when they're below the rope end (no bouncing).
	S.Adapter.applyKnockback(target, offset, math.min(distance / 0.18 * 0.6, 90), math.clamp(offset.Y * 3, 1, 20))
	return false
end

-- Oh! Lonesome Me on someone else: their body comes apart along the rope
-- for a moment (clients draw it) and they're slowed.
local function splitVictim(S, target, seconds, slow, slowTime)
	target:SetAttribute("TimSplitUntil", workspace:GetServerTimeNow() + seconds)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if humanoid and slow then
		S.Adapter.setMoveModifier(humanoid, "TimSplit", slow)
		local token = {}
		target:SetAttribute("TimSlowToken", tostring(token))
		task.delay(slowTime or seconds, function()
			if humanoid.Parent and target:GetAttribute("TimSlowToken") == tostring(token) then
				S.Adapter.setMoveModifier(humanoid, "TimSplit", nil)
				target:SetAttribute("TimSlowToken", nil)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- LASSO SNARE
---------------------------------------------------------------------------
local function lassoSnare(S, player, state, aim)
	local c = cfg.LassoSnare
	if not ready(S, player, state, "LassoSnare", 1) then
		return
	end
	S.startCooldown(player, state, "LassoSnare", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.3)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "LassoSnare", Phase = "Startup", Startup = c.Startup })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local caught = false
		S.fireLasso(player, state, {
			Character = char,
			Origin = S.origin(char, r, HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			OnHit = function(target, position)
				if caught then
					return
				end
				caught = true
				if not S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = direction, Position = position, Source = "MountainTimLasso" }) then
					return
				end
				splitVictim(S, target, c.SplitTime, c.SplitSlow, c.SlowTime)
				S.fx("Ability", { Character = char, Act = ACT, Move = "LassoSnare", Phase = "Snag", Target = target, Duration = c.ReelTime, SplitTime = c.SplitTime })
				local done = false
				for i = 0, math.max(1, math.floor(c.ReelTime / c.ReelTick)) - 1 do
					task.delay(i * c.ReelTick, function()
						local _, _, rr = alive(S, player)
						if done or not rr or state.Life ~= life then
							return
						end
						done = pull(S, target, rr.Position + rr.CFrame.LookVector * 2, c.ReelStopDistance)
					end)
				end
			end,
		})
	end)
end

---------------------------------------------------------------------------
-- SPLIT DODGE
---------------------------------------------------------------------------
local counters = setmetatable({}, { __mode = "k" }) -- [character] = counter function while the dodge is up

local function registerCounter(S)
	if S.Adapter.DodgeHandlers and not S.Adapter.DodgeHandlers.SplitCounter then
		S.Adapter.DodgeHandlers.SplitCounter = function(attackerPlayer, target, info)
			local counter = counters[target]
			if counter then
				counter(attackerPlayer, info)
			end
		end
	end
end

local function slide(S, player, state, life, direction)
	local c = cfg.SplitDodge
	local char, _, r = alive(S, player)
	if not char or state.Life ~= life then
		return
	end
	local from = r.Position
	local to = Moves.safeStep(char, r, direction, c.Distance)
	if not to then
		S.fx("Ability", { Character = char, Act = ACT, Move = "SplitDodge", Phase = "Rejoin", Position = from })
		return
	end
	local iframes = S.Adapter.Settings.IFrameAttribute
	char:SetAttribute(iframes, true)
	S.fx("Ability", { Character = char, Act = ACT, Move = "SplitDodge", Phase = "Slide", From = from, To = to, Direction = direction, Travel = c.Travel })
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	Moves.boxHit(S, player, CFrame.lookAt(mid, mid + direction), Vector3.new(c.Width, 6, length + 2), { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = direction, Source = "MountainTimSplit" }, 5)
	task.delay(c.Travel, function()
		char:SetAttribute(iframes, nil)
		if char.Parent and state.Life == life then
			char:PivotTo(CFrame.lookAt(to, to + direction))
			S.fx("Ability", { Character = char, Act = ACT, Move = "SplitDodge", Phase = "Rejoin", Position = to })
		end
	end)
end

local function splitDodge(S, player, state, aim)
	local c = cfg.SplitDodge
	if not ready(S, player, state, "SplitDodge", 2) then
		return
	end
	registerCounter(S)
	S.startCooldown(player, state, "SplitDodge", c.Cooldown, 2)
	S.lock(state, c.Window + c.Travel + 0.25)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	local used = false
	-- He's in pieces: no walking off during the window.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		S.Adapter.setMoveModifier(humanoid, "SplitDodge", 0.01) -- (never exactly 0: the multipliers divide back out)
		task.delay(c.Window + 0.05, function()
			if humanoid.Parent then
				S.Adapter.setMoveModifier(humanoid, "SplitDodge", nil)
			end
		end)
	end
	character:SetAttribute("SplitCounter", true)
	S.fx("Ability", { Character = character, Act = ACT, Move = "SplitDodge", Phase = "Scatter", Window = c.Window, Position = root.Position })
	counters[character] = function(attackerPlayer)
		if used or state.Life ~= life then
			return
		end
		used = true
		counters[character] = nil
		character:SetAttribute("SplitCounter", nil)
		local attacker = attackerPlayer and attackerPlayer.Character
		local ar = attacker and attacker:FindFirstChild("HumanoidRootPart")
		local _, _, r = alive(S, player)
		if not ar or not r then
			S.fx("Ability", { Character = character, Act = ACT, Move = "SplitDodge", Phase = "Rejoin", Position = r and r.Position or ar.Position })
			return
		end
		-- Reform right behind whoever swung at him.
		local from = r.Position
		-- Behind them if there's room, otherwise beside them; never inside a wall.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, attacker }
		local behind
		for _, offset in ipairs({ CFrame.new(0, 0, 3.5), CFrame.new(3, 0, 1), CFrame.new(-3, 0, 1), CFrame.new(0, 0, -3) }) do
			local spot = (ar.CFrame * offset).Position
			if not workspace:Raycast(ar.Position, spot - ar.Position, params) then
				behind = spot
				break
			end
		end
		behind = behind or from
		local iframes = S.Adapter.Settings.IFrameAttribute
		character:SetAttribute(iframes, true)
		character:PivotTo(CFrame.lookAt(behind, Vector3.new(ar.Position.X, behind.Y, ar.Position.Z)))
		S.fx("Ability", { Character = character, Act = ACT, Move = "SplitDodge", Phase = "Counter", From = from, To = behind, Attacker = attacker })
		task.delay(0.14, function()
			if attacker.Parent and ar.Parent then
				S.hit(player, attacker, { Damage = c.CounterDamage, Stun = c.CounterStun, Knockback = c.CounterKnockback, Launch = c.CounterLaunch, Direction = ar.Position - behind, Position = ar.Position, Source = "MountainTimCounter" })
			end
		end)
		task.delay(0.4, function()
			character:SetAttribute(iframes, nil)
		end)
	end
	task.delay(c.Window, function()
		if used then
			return
		end
		counters[character] = nil
		character:SetAttribute("SplitCounter", nil)
		if state.Life == life then
			slide(S, player, state, life, direction) -- nobody bit: slide forward along the rope
		end
	end)
end

---------------------------------------------------------------------------
-- SPLIT BARRAGE
---------------------------------------------------------------------------
local function splitBarrage(S, player, state, aim)
	local c = cfg.SplitBarrage
	if not ready(S, player, state, "SplitBarrage", 3) then
		return
	end
	S.startCooldown(player, state, "SplitBarrage", c.Cooldown, 3)
	S.lock(state, c.Windup + c.Hits * c.HitEvery + c.ReelTime + 0.2)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "SplitBarrage", Phase = "Startup", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		S.fx("Ability", { Character = character, Act = ACT, Move = "SplitBarrage", Phase = "Fly", Direction = direction, Range = c.Range, Hits = c.Hits, HitEvery = c.HitEvery, ReelTime = c.ReelTime })
		for i = 1, c.Hits do
			task.delay((i - 1) * c.HitEvery, function()
				local char, _, r = alive(S, player)
				if not char or state.Life ~= life then
					return
				end
				local mid = r.Position + direction * (c.Range / 2)
				local last = i == c.Hits
				local _, hitSet = Moves.boxHit(S, player, CFrame.lookAt(mid, mid + direction), Vector3.new(c.Width, 5, c.Range), { Damage = last and c.FinalDamage or c.Damage, Stun = c.Stun, Knockback = last and 0 or 2, Direction = direction, Source = "MountainTimBarrage" }, 4)
				if last then
					-- The last punch hooks them: the rope reels them back to him.
					for target in pairs(hitSet) do
						for k = 0, math.floor(c.ReelTime / c.ReelTick) - 1 do
							task.delay(k * c.ReelTick, function()
								local _, _, rr = alive(S, player)
								if rr and state.Life == life and target.Parent then
									pull(S, target, rr.Position + rr.CFrame.LookVector * 3, 4)
								end
							end)
						end
					end
				end
			end)
		end
	end)
end

function Tim.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		lassoSnare(S, player, state, aim)
	elseif slot == 2 then
		splitDodge(S, player, state, aim)
	elseif slot == 3 then
		splitBarrage(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- LONESOME ROUNDUP (ultimate)
---------------------------------------------------------------------------
function Tim.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + u.RideHits * u.RideEvery + u.ReelTime + 0.4)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Start", Windup = u.Windup, Radius = u.Radius })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local char, _, r = alive(S, player)
		local roped = {}
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, u.Radius, u.MaxTargets)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.Adapter.canBeHit(player, target) and S.Hitbox.lineOfSight(r.Position + Vector3.new(0, 2, 0), tr.Position, { char, target }) then
				table.insert(roped, target)
			end
		end
		S.finishUltimate(player, state)
		for _, target in ipairs(roped) do
			splitVictim(S, target, u.SplitTime, 0.5, u.SplitTime)
		end
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Rope", Targets = roped, SplitTime = u.SplitTime, RideHits = u.RideHits, RideEvery = u.RideEvery, ReelTime = u.ReelTime })
		-- His pieces ride the ropes and hit, again and again.
		for i = 1, u.RideHits do
			task.delay((i - 1) * u.RideEvery, function()
				if state.Life ~= life then
					return
				end
				for _, target in ipairs(roped) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr then
						S.hit(player, target, { Damage = u.RideDamage, Stun = u.RideStun, Knockback = 0, Direction = tr.Position - r.Position, Position = tr.Position, Source = "MountainTimRoundup" })
					end
				end
			end)
		end
		-- Then the rope yanks everyone together in front of him...
		local reelStart = u.RideHits * u.RideEvery
		for i = 0, math.floor(u.ReelTime / u.ReelTick) - 1 do
			task.delay(reelStart + i * u.ReelTick, function()
				local _, _, rr = alive(S, player)
				if not rr or state.Life ~= life then
					return
				end
				local point = rr.Position + rr.CFrame.LookVector * 5
				for _, target in ipairs(roped) do
					if target.Parent then
						pull(S, target, point, 3)
					end
				end
			end)
		end
		-- ...and slams the rope down on them.
		task.delay(reelStart + u.ReelTime + 0.05, function()
			local _, _, rr = alive(S, player)
			if not rr or state.Life ~= life then
				return
			end
			local pos = rr.Position + rr.CFrame.LookVector * 5
			Moves.aoe(S, player, pos, u.SlamRadius, { Damage = u.SlamDamage, Stun = u.SlamStun, Knockback = u.SlamKnockback, Launch = u.SlamLaunch, Source = "MountainTimRoundup" }, 8)
			S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Slam", Position = pos, Radius = u.SlamRadius })
		end)
	end)
end

function Tim.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute("RopeSplit", nil)
		state.Character:SetAttribute("SplitCounter", nil)
		counters[state.Character] = nil
		state.Character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
	end
end

return Tim
```
