---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer › TuskActs"
updated: 2026-11-22
---
# DiegoAU

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer › TuskActs` |
| **Exact name** | `DiegoAU` (capitals matter) |

**What it does:** Diego Brando from another world (AU): THE WORLD. Registered as "Act" 14 so it reuses the Tusk ability system. M1        MUDA COMBO: The World punches with him Ability 1 STAND GRAB: The World lunges out, grabs the nearest enemy in front, lifts them up and hurls them the way he's aiming; whoever they crash into is hit too Ability 2 STAND BARRAGE: The World rushes ahead of him with a storm of punches (he can still walk, slowly); a last big punch sends them flying Ability 3 KNIFE THROW: three knives at once, fanned out Ultimate  THE WORLD: TIME STOP: a zone (shown as a dome) round where he stands: everyone inside, and anyone who walks in, freezes for about 6 seconds (can't move, act, block or dodge) while Diego moves freely. Knives, bullets and every other projectile in the zone stop in the air (his own a few studs out) and fly on when time moves again. It ends early if he goes down Numbers: TuskConfig.DiegoAU. All damage goes through S.hit (CombatAdapter). Frozen characters carry the "TimeStopped" attribute (CombatAdapter.canAct refuses them) and have their root anchored by the server.

## How to add it
1. In Studio's Explorer, find **TuskActs** (ServerScriptService › SpinServer › TuskActs).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **DiegoAU**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	DiegoAU  (ServerScriptService.SpinServer.TuskActs.DiegoAU)

	Diego Brando from another world (AU): THE WORLD. Registered as "Act" 14
	so it reuses the Tusk ability system.
	  M1        MUDA COMBO: The World punches with him
	  Ability 1 STAND GRAB: The World lunges out, grabs the nearest enemy in
	            front, lifts them up and hurls them the way he's aiming;
	            whoever they crash into is hit too
	  Ability 2 STAND BARRAGE: The World rushes ahead of him with a storm of
	            punches (he can still walk, slowly); a last big punch sends
	            them flying
	  Ability 3 KNIFE THROW: three knives at once, fanned out
	  Ultimate  THE WORLD: TIME STOP: a zone (shown as a dome) round where he
	            stands: everyone inside, and anyone who walks in, freezes for
	            about 6 seconds (can't move, act, block or dodge) while Diego
	            moves freely. Knives, bullets and every other projectile in
	            the zone stop in the air (his own a few studs out) and fly on
	            when time moves again. It ends early if he goes down
	Numbers: TuskConfig.DiegoAU. All damage goes through S.hit (CombatAdapter).
	Frozen characters carry the "TimeStopped" attribute (CombatAdapter.canAct
	refuses them) and have their root anchored by the server.
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local DiegoAU = {}
local cfg = TuskConfig.DiegoAU
local ACT = 14

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

function DiegoAU.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- Pinning (anchoring) a character in place. Counted, so a grab during a
-- time stop doesn't let them go when the grab ends.
---------------------------------------------------------------------------
local pins = setmetatable({}, { __mode = "k" }) -- [root] = { Count, WasAnchored }

local function pin(root)
	local p = pins[root]
	if not p then
		p = { Count = 0, WasAnchored = root.Anchored }
		pins[root] = p
	end
	p.Count = p.Count + 1
	root.Anchored = true
end

local function unpin(root)
	local p = pins[root]
	if not p then
		return
	end
	p.Count = p.Count - 1
	if p.Count <= 0 then
		pins[root] = nil
		if root.Parent then
			root.Anchored = p.WasAnchored
		end
	end
end

-- Frozen in stopped time (counted: two time stops can overlap).
local frozenCount = setmetatable({}, { __mode = "k" }) -- [character] = count

local function freeze(target)
	local tr = target:FindFirstChild("HumanoidRootPart")
	if not tr then
		return false
	end
	frozenCount[target] = (frozenCount[target] or 0) + 1
	target:SetAttribute("TimeStopped", true)
	pin(tr)
	return true
end

local function thaw(target)
	local count = frozenCount[target]
	if not count then
		return
	end
	count = count - 1
	frozenCount[target] = count > 0 and count or nil
	if count <= 0 and target.Parent then
		target:SetAttribute("TimeStopped", nil)
	end
	local tr = target:FindFirstChild("HumanoidRootPart")
	if tr then
		unpin(tr)
	end
end

-- Nearest enemy (optionally only in a cone in front).
local function nearest(S, character, root, range, direction, cone)
	local look = direction and Moves.flat(direction)
	local cosLimit = cone and math.cos(math.rad(cone / 2))
	local best, bestD
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, range, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		local hum = target:FindFirstChildOfClass("Humanoid")
		if tr and hum and hum.Health > 0 and S.Adapter.canBeHit(nil, target) then
			local offset = tr.Position - root.Position
			local f = Vector3.new(offset.X, 0, offset.Z)
			if not look or f.Magnitude < 1 or f.Unit:Dot(look) >= cosLimit then
				if S.Hitbox.lineOfSight(root.Position, tr.Position, { character, target }) then
					if not bestD or offset.Magnitude < bestD then
						best, bestD = target, offset.Magnitude
					end
				end
			end
		end
	end
	return best
end

local stops = setmetatable({}, { __mode = "k" }) -- [character] = the time stop he's holding

---------------------------------------------------------------------------
-- STAND GRAB: grab, lift, throw
---------------------------------------------------------------------------
local function standGrab(S, player, state, aim)
	local c = cfg.StandGrab
	if not ready(S, player, state, "StandGrab", 1) then
		return
	end
	S.startCooldown(player, state, "StandGrab", c.Cooldown, 1)
	S.lock(state, c.Windup + c.HoldTime + 0.25)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "StandGrab", Phase = "Reach", Direction = direction, Windup = c.Windup, Range = c.Range })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local target = nearest(S, char, r, c.Range, direction, c.Cone)
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		if not tr or not S.hit(player, target, { Damage = c.GrabDamage, Stun = c.Stun, Knockback = 0, Direction = direction, Position = tr.Position, Source = "DiegoAUGrab" }) then
			S.startCooldown(player, state, "StandGrab", c.MissCooldown, 1)
			S.fx("Ability", { Character = char, Act = ACT, Move = "StandGrab", Phase = "Miss", Direction = direction })
			return
		end
		-- Lifted up in front of Diego, held there.
		pin(tr)
		S.fx("Ability", { Character = char, Act = ACT, Move = "StandGrab", Phase = "Hold", Target = target, Duration = c.HoldTime })
		local started = now()
		local function hold()
			local _, _, myRoot = alive(S, player)
			if not tr.Parent or not myRoot or not S.stillValid(player, state, life) then
				-- Diego was knocked out of it: they drop.
				unpin(tr)
				S.fx("Ability", { Act = ACT, Move = "StandGrab", Phase = "Drop", Character = character, Target = target })
				return
			end
			if now() - started < c.HoldTime then
				local lift = math.min((now() - started) / c.HoldTime, 1)
				local at = (myRoot.CFrame * CFrame.new(0, 1.5 + lift * 2, -4.5)).Position
				tr.CFrame = CFrame.lookAt(at, myRoot.Position + Vector3.new(0, 1.5 + lift * 2, 0))
				task.delay(0.03, hold)
				return
			end
			-- Hurled the way he's aiming now.
			local throwDir = Moves.flat(myRoot.CFrame.LookVector)
			unpin(tr)
			S.hit(player, target, { Damage = c.ThrowDamage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = throwDir, Position = tr.Position, Source = "DiegoAUThrow" })
			S.fx("Ability", { Character = char, Act = ACT, Move = "StandGrab", Phase = "Throw", Target = target, Direction = throwDir, Position = tr.Position })
			-- Whoever they crash into gets hit too.
			task.delay(c.SplashDelay, function()
				if tr.Parent then
					Moves.aoe(S, player, tr.Position, c.SplashRadius, { Damage = c.SplashDamage, Stun = 0.5, Knockback = 25, Source = "DiegoAUThrow" }, 5, { [target] = true })
					S.fx("Ability", { Act = ACT, Move = "StandGrab", Phase = "Crash", Position = tr.Position, Radius = c.SplashRadius })
				end
			end)
		end
		hold()
	end)
end

---------------------------------------------------------------------------
-- STAND BARRAGE
---------------------------------------------------------------------------
local function standBarrage(S, player, state, aim)
	local c = cfg.StandBarrage
	if not ready(S, player, state, "StandBarrage", 2) then
		return
	end
	S.startCooldown(player, state, "StandBarrage", c.Cooldown, 2)
	S.lock(state, c.Windup + c.Duration + 0.15)
	local character, humanoid = alive(S, player)
	local life = state.Life
	local untilT = now() + c.Windup + c.Duration
	character:SetAttribute("WorldBarrageUntil", untilT)
	S.Adapter.setMoveModifier(humanoid, "WorldBarrage", c.WalkMultiplier)
	S.fx("Ability", { Character = character, Act = ACT, Move = "StandBarrage", Phase = "Start", Windup = c.Windup, Duration = c.Duration })
	local ticks = math.max(1, math.floor(c.Duration / c.Tick))
	local function stop()
		if humanoid.Parent then
			S.Adapter.setMoveModifier(humanoid, "WorldBarrage", nil)
		end
		if character.Parent and character:GetAttribute("WorldBarrageUntil") == untilT then
			character:SetAttribute("WorldBarrageUntil", nil)
		end
	end
	for i = 1, ticks do
		task.delay(c.Windup + (i - 1) * c.Tick, function()
			if character:GetAttribute("WorldBarrageUntil") ~= untilT then
				return -- already over
			end
			if not S.stillValid(player, state, life) then
				-- Stunned (or gone) out of it: The World goes back.
				stop()
				S.fx("Ability", { Character = character, Act = ACT, Move = "StandBarrage", Phase = "Stop" })
				return
			end
			local _, _, r = alive(S, player)
			local boxCF = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
			local last = i == ticks
			if last then
				Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.FinalDamage, Stun = c.FinalStun, Knockback = c.FinalKnockback, Launch = c.FinalLaunch, Direction = r.CFrame.LookVector, Source = "DiegoAUBarrage" }, c.MaxTargets)
				S.fx("Ability", { Character = character, Act = ACT, Move = "StandBarrage", Phase = "Finish", Position = boxCF.Position })
				stop()
			else
				local count = Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = r.CFrame.LookVector, Source = "DiegoAUBarrage" }, c.MaxTargets)
				if count > 0 and i % 2 == 0 then
					S.fx("Ability", { Act = ACT, Move = "StandBarrage", Phase = "Hit", Position = boxCF.Position })
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- KNIFE THROW
---------------------------------------------------------------------------
local function throwKnife(S, player, state, origin, direction, source)
	local c = cfg.KnifeThrow
	return S.fireKnife(player, state, {
		Origin = origin,
		Direction = direction,
		Speed = c.Speed,
		Radius = c.Radius,
		Range = c.Range,
		OnHit = function(target, position)
			S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = direction, Position = position, Source = source or "DiegoAUKnife" })
		end,
	})
end
DiegoAU.throwKnife = throwKnife

-- The fan of directions (rotated round the vertical) for `count` knives.
local function fan(direction, count, spread)
	local list = {}
	for i = 1, count do
		local angle = math.rad((i - (count + 1) / 2) * spread)
		table.insert(list, (CFrame.Angles(0, angle, 0) * CFrame.new(Vector3.zero, direction)).LookVector)
	end
	return list
end

local function knifeThrow(S, player, state, aim)
	local c = cfg.KnifeThrow
	if not ready(S, player, state, "KnifeThrow", 3) then
		return
	end
	S.startCooldown(player, state, "KnifeThrow", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local character, _, root = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "KnifeThrow", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local direction = S.aim(aim, r)
		local origin = S.origin(char, r, Moves.HAND)
		S.fx("Ability", { Character = char, Act = ACT, Move = "KnifeThrow", Phase = "Throw", Direction = direction })
		-- (Inside stopped time they fly a few studs and hang there: ProjectileService.)
		for _, dir in ipairs(fan(direction, c.Count, c.Spread)) do
			throwKnife(S, player, state, origin, dir)
		end
	end)
end

function DiegoAU.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		standGrab(S, player, state, aim)
	elseif slot == 2 then
		standBarrage(S, player, state, aim)
	elseif slot == 3 then
		knifeThrow(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- THE WORLD: TIME STOP (ultimate)
---------------------------------------------------------------------------
local function resume(S, character, token)
	local stop = stops[character]
	if not stop or stop.Token ~= token then
		return
	end
	stops[character] = nil
	for _, target in ipairs(stop.Frozen) do
		thaw(target)
	end
	if character.Parent then
		character:SetAttribute("TimeStopper", nil)
	end
	-- Every knife, bullet and projectile hanging in the zone flies on.
	if S.Projectiles and S.Projectiles.resumeTime then
		S.Projectiles.resumeTime(token)
	end
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Resume", Position = stop.Center })
end

function DiegoAU.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.2)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Call", Windup = u.Windup })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local char, _, r = alive(S, player)
		local duration = (typeof(player) == "table" and player.IsBot) and u.BotDuration or u.Duration
		local token = tostring({})
		local center, radius = r.Position, u.Range
		local frozen, isFrozen = {}, {}
		-- Everyone inside the zone freezes, and so does anyone who walks in.
		local function sweep()
			for _, target in ipairs(S.Hitbox.inRadius(char, center, radius, 40)) do
				local hum = target:FindFirstChildOfClass("Humanoid")
				if not isFrozen[target] and hum and hum.Health > 0 and target ~= char and freeze(target) then
					isFrozen[target] = true
					table.insert(frozen, target)
				end
			end
		end
		sweep()
		stops[char] = { Token = token, Frozen = frozen, Center = center }
		char:SetAttribute("TimeStopper", now() + duration)
		if S.Projectiles and S.Projectiles.stopTime then
			S.Projectiles.stopTime(token, center, radius, player)
		end
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Stop", Position = center, Range = radius, Duration = duration, Frozen = frozen })
		local function tick()
			local stop = stops[char]
			if not stop or stop.Token ~= token then
				return
			end
			sweep()
			task.delay(0.2, tick)
		end
		task.delay(0.2, tick)
		task.delay(duration, function()
			resume(S, char, token)
		end)
	end)
end

function DiegoAU.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("WorldBarrageUntil", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "WorldBarrage", nil)
		end
		-- He went down (or switched): time moves again.
		local stop = stops[character]
		if stop then
			resume(S, character, stop.Token)
		end
	end
end

return DiegoAU
```
