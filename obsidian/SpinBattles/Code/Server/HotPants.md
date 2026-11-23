---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer › TuskActs"
updated: 2026-11-22
---
# HotPants

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer › TuskActs` |
| **Exact name** | `HotPants` (capitals matter) |

**What it does:** Hot Pants: CREAM STARTER, a spray can that sprays flesh. It can seal wounds, coat things in flesh and smother people by sealing their mouth and nose. Registered as "Act" 10 so it reuses the Tusk ability system. M1        SPRAY COMBO: jab, kick, a short spray burst, roundhouse Ability 1 FLESH SPRAY: a cone of flesh for a moment; everyone in it is coated (slowed) and takes ticks of damage Ability 2 FLESH SEAL: flesh over the nearest enemy's mouth and nose: they suffocate (damage over time) and are slowed Ability 3 FLESH MEND: she sprays her own wounds shut (heals, clears seals / coatings on herself) Ultimate  FLESH STORM: a cloud of flesh in front hardens into cocoons round everyone caught, crushes them, then bursts apart Numbers: TuskConfig.HotPants. All damage goes through S.hit (CombatAdapter).

## How to add it
1. In Studio's Explorer, find **TuskActs** (ServerScriptService › SpinServer › TuskActs).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **HotPants**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	HotPants  (ServerScriptService.SpinServer.TuskActs.HotPants)

	Hot Pants: CREAM STARTER, a spray can that sprays flesh. It can seal
	wounds, coat things in flesh and smother people by sealing their mouth
	and nose. Registered as "Act" 10 so it reuses the Tusk ability system.
	  M1        SPRAY COMBO: jab, kick, a short spray burst, roundhouse
	  Ability 1 FLESH SPRAY: a cone of flesh for a moment; everyone in it is
	            coated (slowed) and takes ticks of damage
	  Ability 2 FLESH SEAL: flesh over the nearest enemy's mouth and nose:
	            they suffocate (damage over time) and are slowed
	  Ability 3 FLESH MEND: she sprays her own wounds shut (heals, clears
	            seals / coatings on herself)
	  Ultimate  FLESH STORM: a cloud of flesh in front hardens into cocoons
	            round everyone caught, crushes them, then bursts apart
	Numbers: TuskConfig.HotPants. All damage goes through S.hit (CombatAdapter).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local HotPants = {}
local cfg = TuskConfig.HotPants
local ACT = 10

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function HotPants.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

local function now()
	return workspace:GetServerTimeNow()
end

-- A slow that's always removed (stackable by key, refreshed by a token).
local function slow(S, target, key, multiplier, seconds)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	S.Adapter.setMoveModifier(humanoid, key, multiplier)
	local token = tostring({})
	target:SetAttribute(key .. "Token", token)
	task.delay(seconds, function()
		if humanoid.Parent and target:GetAttribute(key .. "Token") == token then
			S.Adapter.setMoveModifier(humanoid, key, nil)
			target:SetAttribute(key .. "Token", nil)
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
-- FLESH SPRAY
---------------------------------------------------------------------------
local function fleshSpray(S, player, state, aim)
	local c = cfg.FleshSpray
	if not ready(S, player, state, "FleshSpray", 1) then
		return
	end
	S.startCooldown(player, state, "FleshSpray", c.Cooldown, 1)
	S.lock(state, c.Startup + c.Duration + 0.15)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "FleshSpray", Phase = "Spray", Startup = c.Startup, Duration = c.Duration, Direction = direction, Range = c.Range, Cone = c.Cone })
	local ticks = math.floor(c.Duration / c.Tick)
	for i = 1, ticks do
		task.delay(c.Startup + (i - 1) * c.Tick, function()
			if not S.stillValid(player, state, life) then
				return
			end
			local char, _, r = alive(S, player)
			for _, target in ipairs(targetsInCone(S, char, r, direction, c.Range, c.Cone, c.MaxTargets)) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr and S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = direction, Position = tr.Position, Source = "HotPantsSpray" }) then
					target:SetAttribute("FleshCoatedUntil", now() + c.CoatTime)
					slow(S, target, "FleshCoat", c.CoatSlow, c.CoatTime)
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- FLESH SEAL
---------------------------------------------------------------------------
local function fleshSeal(S, player, state, aim)
	local c = cfg.FleshSeal
	if not ready(S, player, state, "FleshSeal", 2) then
		return
	end
	S.startCooldown(player, state, "FleshSeal", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.3)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "FleshSeal", Phase = "Startup", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local target = targetsInCone(S, char, r, direction, c.Range, c.Cone, 1)[1]
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		if not tr or not S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = direction, Position = tr.Position, Source = "HotPantsSeal" }) then
			S.startCooldown(player, state, "FleshSeal", c.MissCooldown, 2)
			S.fx("Ability", { Character = char, Act = ACT, Move = "FleshSeal", Phase = "Miss", Direction = direction, Range = c.Range })
			return
		end
		-- Mouth and nose sealed: they suffocate.
		local untilT = now() + c.SealTime
		target:SetAttribute("FleshSealedUntil", untilT)
		slow(S, target, "FleshSeal", c.SealSlow, c.SealTime)
		S.fx("Ability", { Character = char, Act = ACT, Move = "FleshSeal", Phase = "Seal", Target = target, Duration = c.SealTime })
		for i = 1, math.floor(c.SealTime / c.SealTick) do
			task.delay(i * c.SealTick, function()
				local t = target:FindFirstChild("HumanoidRootPart")
				-- (Flesh Mend or a new life clears it early.)
				if t and (target:GetAttribute("FleshSealedUntil") or 0) >= untilT - 0.01 then
					S.hit(player, target, { Damage = c.SealDamage, Stun = 0, Knockback = 0, Direction = direction, Position = t.Position, Source = "HotPantsSeal" })
				end
			end)
		end
	end)
end

---------------------------------------------------------------------------
-- FLESH MEND
---------------------------------------------------------------------------
local function fleshMend(S, player, state)
	local c = cfg.FleshMend
	if not ready(S, player, state, "FleshMend", 3) then
		return
	end
	S.startCooldown(player, state, "FleshMend", c.Cooldown, 3)
	S.lock(state, 0.35)
	local character, humanoid = alive(S, player)
	local life = state.Life
	-- Clears flesh tricks used on her.
	character:SetAttribute("FleshSealedUntil", nil)
	character:SetAttribute("FleshCoatedUntil", nil)
	character:SetAttribute("FleshMendUntil", now() + c.Duration)
	S.fx("Ability", { Character = character, Act = ACT, Move = "FleshMend", Phase = "Mend", Duration = c.Duration, Heal = c.Heal })
	for i = 1, c.Ticks do
		task.delay(i * c.Duration / c.Ticks, function()
			if state.Life ~= life or not humanoid.Parent or humanoid.Health <= 0 then
				return
			end
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + c.Heal / c.Ticks)
		end)
	end
	task.delay(c.Duration, function()
		if character.Parent then
			character:SetAttribute("FleshMendUntil", nil)
		end
	end)
end

function HotPants.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		fleshSpray(S, player, state, aim)
	elseif slot == 2 then
		fleshSeal(S, player, state, aim)
	elseif slot == 3 then
		fleshMend(S, player, state)
	end
end

---------------------------------------------------------------------------
-- FLESH STORM (ultimate)
---------------------------------------------------------------------------
function HotPants.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	local center = Moves.groundBelow(root.Position + direction * u.Distance, { character })
	S.lock(state, u.Windup + u.EncaseTime + 0.4)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Cloud", Windup = u.Windup, Position = center, Radius = u.Radius, Direction = direction })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local up = center + Vector3.new(0, 2.5, 0)
		local caught = {}
		for _, target in ipairs(S.Hitbox.inRadius(character, up, u.Radius, 8)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.hit(player, target, { Damage = u.EncaseDamage, Stun = u.EncaseStun, Knockback = 0, Direction = tr.Position - center, Position = tr.Position, Source = "HotPantsStorm" }) then
				target:SetAttribute("FleshEncasedUntil", now() + u.EncaseTime)
				slow(S, target, "FleshEncase", 0.05, u.EncaseTime)
				table.insert(caught, target)
			end
		end
		S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Encase", Targets = caught, Duration = u.EncaseTime, Position = center, Radius = u.Radius })
		-- The cocoons crush...
		for i = 1, math.floor(u.EncaseTime / u.CrushEvery) do
			task.delay(i * u.CrushEvery, function()
				if state.Life ~= life then
					return
				end
				for _, target in ipairs(caught) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr then
						S.hit(player, target, { Damage = u.CrushDamage, Stun = 0.6, Knockback = 0, Direction = Vector3.new(0, -1, 0), Position = tr.Position, Source = "HotPantsStorm" })
					end
				end
			end)
		end
		-- ...then burst.
		task.delay(u.EncaseTime, function()
			for _, target in ipairs(caught) do
				target:SetAttribute("FleshEncasedUntil", nil)
			end
			if state.Life ~= life then
				return
			end
			Moves.aoe(S, player, up, u.Radius + 1, { Damage = u.BurstDamage, Stun = u.BurstStun, Knockback = u.BurstKnockback, Launch = u.BurstLaunch, Source = "HotPantsStorm" }, 8)
			S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Burst", Position = center, Radius = u.Radius + 1, Targets = caught })
		end)
	end)
end

function HotPants.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute("FleshMendUntil", nil)
	end
end

return HotPants
```
