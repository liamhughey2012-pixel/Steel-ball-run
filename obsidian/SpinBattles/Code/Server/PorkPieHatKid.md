---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer › TuskActs"
updated: 2026-11-22
---
# PorkPieHatKid

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer › TuskActs` |
| **Exact name** | `PorkPieHatKid` (capitals matter) |

**What it does:** Pork Pie Hat Kid: WIRED. Two fish hooks on steel cables that roll out of a winch in the back of his mouth; the hooks come out of water to snag whoever goes for the bait, and together they can lift a horse. Registered as "Act" 7 so it reuses the Tusk ability system (cooldowns, HUD, ultimate meter, input). M1        HOOK COMBO: slap, slap, a hook lash out of his mouth, flying kick Ability 1 WIRED HOOK: a hook shoots out of his mouth; a hit snags the enemy and the winch reels them in to him Ability 2 BAIT PAN: puts down a pan of water with a feather bait. The first enemies to come near get hooked out of the water, hoisted up and yanked back down Ability 3 DOUBLE HOOK LIFT: both hooks snag up to two enemies in front, hoist them high in the air, then slam them down Ultimate  WIRED WINCH: puddles of water all around him, hooks erupt from every one, the winch reels everyone in through the air, slam Numbers: TuskConfig.PorkPie. All damage goes through S.hit (CombatAdapter).

## How to add it
1. In Studio's Explorer, find **TuskActs** (ServerScriptService › SpinServer › TuskActs).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **PorkPieHatKid**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	PorkPieHatKid  (ServerScriptService.SpinServer.TuskActs.PorkPieHatKid)

	Pork Pie Hat Kid: WIRED. Two fish hooks on steel cables that roll out of a
	winch in the back of his mouth; the hooks come out of water to snag
	whoever goes for the bait, and together they can lift a horse.
	Registered as "Act" 7 so it reuses the Tusk ability system (cooldowns,
	HUD, ultimate meter, input).
	  M1        HOOK COMBO: slap, slap, a hook lash out of his mouth, flying kick
	  Ability 1 WIRED HOOK: a hook shoots out of his mouth; a hit snags the
	            enemy and the winch reels them in to him
	  Ability 2 BAIT PAN: puts down a pan of water with a feather bait. The
	            first enemies to come near get hooked out of the water,
	            hoisted up and yanked back down
	  Ability 3 DOUBLE HOOK LIFT: both hooks snag up to two enemies in front,
	            hoist them high in the air, then slam them down
	  Ultimate  WIRED WINCH: puddles of water all around him, hooks erupt from
	            every one, the winch reels everyone in through the air, slam
	Numbers: TuskConfig.PorkPie. All damage goes through S.hit (CombatAdapter).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local PorkPie = {}
local cfg = TuskConfig.PorkPie
local ACT = 7
local MOUTH = CFrame.new(0, 1.3, -1.2) -- roughly where his mouth is (root space)

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function PorkPie.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

-- The winch pulls `target` toward `point` (one tick; the knockback lasts ~0.18 s).
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
	local strength = math.min(distance / 0.18 * 0.6, 90)
	S.Adapter.applyKnockback(target, offset, strength, math.clamp(offset.Y * 3, 4, 40))
	return false
end

-- Yank a hoisted enemy straight back down into the ground.
local function slamDown(S, player, target, damage, source)
	if not target.Parent then
		return
	end
	S.Adapter.applyKnockback(target, Vector3.new(0, 0, 1), 1, -90)
	task.delay(0.25, function()
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			S.hit(player, target, { Damage = damage, Stun = 0.5, Knockback = 0, Direction = Vector3.new(0, -1, 0), Position = tr.Position, Source = source })
		end
	end)
end

-- Up to `max` enemies in a cone in front, nearest first.
local function targetsInCone(S, character, root, direction, range, cone, max)
	local look = Moves.flat(direction)
	local cosLimit = math.cos(math.rad(cone / 2))
	local list = {}
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, range, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and S.Adapter.canBeHit(nil, target) then
			local offset = tr.Position - root.Position
			local f = Vector3.new(offset.X, 0, offset.Z)
			if (f.Magnitude < 1 or f.Unit:Dot(look) >= cosLimit) and S.Hitbox.lineOfSight(root.Position, tr.Position, { character, target }) then
				table.insert(list, { Target = target, Distance = offset.Magnitude })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Distance < b.Distance
	end)
	local out = {}
	for i = 1, math.min(max, #list) do
		out[i] = list[i].Target
	end
	return out
end

---------------------------------------------------------------------------
-- WIRED HOOK
---------------------------------------------------------------------------
local function wiredHook(S, player, state, aim)
	local c = cfg.WiredHook
	if not ready(S, player, state, "WiredHook", 1) then
		return
	end
	S.startCooldown(player, state, "WiredHook", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.3)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "WiredHook", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local snagged = false
		S.fireHook(player, state, {
			Origin = S.origin(char, r, MOUTH),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			OnHit = function(target, position)
				if snagged then
					return
				end
				snagged = true
				if not S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = direction, Position = position, Source = "PorkPieHook" }) then
					return
				end
				S.fx("Ability", { Character = char, Act = ACT, Move = "WiredHook", Phase = "Snag", Target = target, Duration = c.ReelTime })
				-- The winch reels them in.
				local ticks = math.max(1, math.floor(c.ReelTime / c.ReelTick))
				local done = false
				for i = 0, ticks - 1 do
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
-- BAIT PAN
---------------------------------------------------------------------------
local function clearPan(S, state, reason)
	local pan = state.BaitPan
	if not pan then
		return
	end
	state.BaitPan = nil
	if state.Character then
		state.Character:SetAttribute("BaitPanUntil", nil)
	end
	S.fx("Ability", { Act = ACT, Move = "BaitPan", Phase = reason or "Expire", Id = pan.Id, Position = pan.Position })
end

local function baitPan(S, player, state, aim)
	local c = cfg.BaitPan
	if not ready(S, player, state, "BaitPan", 2) then
		return
	end
	S.startCooldown(player, state, "BaitPan", c.Cooldown, 2)
	S.lock(state, c.Startup + 0.2)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "BaitPan", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		clearPan(S, state, "Expire") -- one pan at a time
		local spot = Moves.safeStep(char, r, direction, c.Distance) or (r.Position + direction * 3)
		local ground = Moves.groundBelow(spot, { char })
		local pan = { Id = tostring(os.clock()) .. player.UserId, Position = ground, Until = os.clock() + c.Duration }
		state.BaitPan = pan
		char:SetAttribute("BaitPanUntil", workspace:GetServerTimeNow() + c.Duration)
		S.fx("Ability", { Character = char, Act = ACT, Move = "BaitPan", Phase = "Place", Id = pan.Id, Position = ground, From = r.Position, Duration = c.Duration, Radius = c.TriggerRadius })

		local function check()
			if state.BaitPan ~= pan or state.Life ~= life then
				return
			end
			if os.clock() >= pan.Until then
				clearPan(S, state, "Expire")
				return
			end
			local center = pan.Position + Vector3.new(0, 2.5, 0)
			local caught = {}
			for _, target in ipairs(S.Hitbox.inRadius(player.Character, center, c.TriggerRadius, c.MaxTargets)) do
				if S.Adapter.canBeHit(player, target) then
					table.insert(caught, target)
				end
			end
			if #caught == 0 then
				task.delay(c.CheckEvery, check)
				return
			end
			-- Hooks burst out of the water and hoist them.
			S.fx("Ability", { Act = ACT, Move = "BaitPan", Phase = "Trigger", Id = pan.Id, Position = pan.Position, Targets = caught, SlamAfter = c.SlamAfter })
			state.BaitPan = nil
			if state.Character then
				state.Character:SetAttribute("BaitPanUntil", nil)
			end
			for _, target in ipairs(caught) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr and S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Launch = c.Lift, Direction = tr.Position - pan.Position, Position = tr.Position, Source = "PorkPieBait" }) then
					task.delay(c.SlamAfter, function()
						slamDown(S, player, target, c.SlamDamage, "PorkPieBait")
					end)
				end
			end
		end
		task.delay(c.CheckEvery, check)
	end)
end

---------------------------------------------------------------------------
-- DOUBLE HOOK LIFT
---------------------------------------------------------------------------
local function doubleHookLift(S, player, state, aim)
	local c = cfg.DoubleHookLift
	if not ready(S, player, state, "DoubleHookLift", 3) then
		return
	end
	S.startCooldown(player, state, "DoubleHookLift", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.5)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "DoubleHookLift", Phase = "Startup", Windup = c.Windup, Direction = direction })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local targets = targetsInCone(S, char, r, direction, c.Range, c.Cone, c.MaxTargets)
		local hooked = {}
		for _, target in ipairs(targets) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Launch = c.Lift, Direction = direction, Position = tr.Position, Source = "PorkPieLift" }) then
				table.insert(hooked, target)
			end
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "DoubleHookLift", Phase = "Hoist", Targets = hooked, Direction = direction, Range = c.Range, SlamAfter = c.SlamAfter })
		if #hooked == 0 then
			-- Missed: shorter cooldown.
			S.startCooldown(player, state, "DoubleHookLift", c.MissCooldown, 3)
			return
		end
		task.delay(c.SlamAfter, function()
			for _, target in ipairs(hooked) do
				slamDown(S, player, target, c.SlamDamage, "PorkPieLift")
			end
			task.delay(0.3, function()
				for _, target in ipairs(hooked) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr then
						S.fx("Ability", { Act = ACT, Move = "DoubleHookLift", Phase = "Slam", Position = tr.Position, Radius = c.SlamRadius })
					end
				end
			end)
		end)
	end)
end

function PorkPie.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		wiredHook(S, player, state, aim)
	elseif slot == 2 then
		baitPan(S, player, state, aim)
	elseif slot == 3 then
		doubleHookLift(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- WIRED WINCH (ultimate)
---------------------------------------------------------------------------
function PorkPie.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + u.ReelTime + 0.5)
	character:SetAttribute("Armored", true)
	-- Puddles of water in a ring around him.
	local puddles = {}
	for i = 1, u.Puddles do
		local a = (i - 1) / u.Puddles * math.pi * 2
		local spot = root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * u.PuddleRadius
		puddles[i] = Moves.groundBelow(spot, { character })
	end
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Start", Windup = u.Windup, Puddles = puddles, Radius = u.Radius })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local char, _, r = alive(S, player)
		-- Hooks erupt from the puddles and snag everyone around.
		local snagged, from = {}, {}
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, u.Radius, 8)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.Hitbox.lineOfSight(r.Position + Vector3.new(0, 2, 0), tr.Position, { char, target }) then
				if S.hit(player, target, { Damage = u.SnagDamage, Stun = u.SnagStun, Knockback = 0, Launch = u.SnagLift, Direction = r.Position - tr.Position, Position = tr.Position, Source = "PorkPieWinch" }) then
					table.insert(snagged, target)
					local best, bestD = 1, math.huge
					for i, p in ipairs(puddles) do
						local d = (p - tr.Position).Magnitude
						if d < bestD then
							best, bestD = i, d
						end
					end
					table.insert(from, best)
				end
			end
		end
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Snag", Targets = snagged, From = from, Puddles = puddles, ReelTime = u.ReelTime })
		S.finishUltimate(player, state)
		-- The winch reels them all in through the air.
		local ticks = math.floor(u.ReelTime / u.ReelTick)
		local nextDamage = u.TickEvery
		for i = 1, ticks do
			task.delay(i * u.ReelTick, function()
				local _, _, rr = alive(S, player)
				if not rr or state.Life ~= life then
					return
				end
				local point = rr.Position + rr.CFrame.LookVector * 4 + Vector3.new(0, 4, 0)
				local damageTick = i * u.ReelTick >= nextDamage
				if damageTick then
					nextDamage = nextDamage + u.TickEvery
				end
				for _, target in ipairs(snagged) do
					if target.Parent then
						pull(S, target, point, 3)
						local tr = target:FindFirstChild("HumanoidRootPart")
						if damageTick and tr then
							S.hit(player, target, { Damage = u.TickDamage, Stun = 0.6, Knockback = 0, Direction = point - tr.Position, Position = tr.Position, Source = "PorkPieWinch" })
						end
					end
				end
			end)
		end
		task.delay(u.ReelTime + 0.05, function()
			local _, _, rr = alive(S, player)
			if not rr or state.Life ~= life then
				return
			end
			local pos = rr.Position + rr.CFrame.LookVector * 4
			Moves.aoe(S, player, pos, u.SlamRadius, { Damage = u.SlamDamage, Stun = u.SlamStun, Knockback = u.SlamKnockback, Launch = u.SlamLaunch, Source = "PorkPieWinch" }, 8)
			S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Slam", Position = pos, Radius = u.SlamRadius })
		end)
	end)
end

function PorkPie.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
	end
	clearPan(S, state, "Expire")
end

return PorkPie
```
