---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer › TuskActs"
updated: 2026-11-22
---
# Polnareff

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer › TuskActs` |
| **Exact name** | `Polnareff` (capitals matter) |

**What it does:** Jean Pierre Polnareff (a visitor from another world: Part 3): SILVER CHARIOT, a knight with a rapier. Registered as "Act" 23. M1        RAPIER COMBO: quick thrusts; the 4th is a lunge (faster with the armour off) Ability 1 HORA HORA RUSH: a storm of rapier thrusts in front of him, holding them in place; a last big thrust sends them flying Ability 2 ARMOR OFF: Silver Chariot sheds its armour for 8 s: he's 35% faster and the rapier combo is much quicker Ability 3 RAPIER SHOT: the Chariot fires its blade like a bullet (instant, long range, stopped by walls) Ultimate  AFTERIMAGE STORM: the Chariot splits into a ring of afterimages round the nearest enemy in front; they all stab at once for 2 s (everyone in the ring is hit), then one final thrust launches them Numbers: TuskConfig.Polnareff. All damage goes through S.hit.

## How to add it
1. In Studio's Explorer, find **TuskActs** (ServerScriptService › SpinServer › TuskActs).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **Polnareff**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	Polnareff  (ServerScriptService.SpinServer.TuskActs.Polnareff)

	Jean Pierre Polnareff (a visitor from another world: Part 3): SILVER
	CHARIOT, a knight with a rapier. Registered as "Act" 23.
	  M1        RAPIER COMBO: quick thrusts; the 4th is a lunge (faster with
	            the armour off)
	  Ability 1 HORA HORA RUSH: a storm of rapier thrusts in front of him,
	            holding them in place; a last big thrust sends them flying
	  Ability 2 ARMOR OFF: Silver Chariot sheds its armour for 8 s: he's 35%
	            faster and the rapier combo is much quicker
	  Ability 3 RAPIER SHOT: the Chariot fires its blade like a bullet
	            (instant, long range, stopped by walls)
	  Ultimate  AFTERIMAGE STORM: the Chariot splits into a ring of
	            afterimages round the nearest enemy in front; they all stab
	            at once for 2 s (everyone in the ring is hit), then one final
	            thrust launches them
	Numbers: TuskConfig.Polnareff. All damage goes through S.hit.
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Polnareff = {}
local cfg = TuskConfig.Polnareff
local ACT = 23

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

local function armorOff(character)
	return (character:GetAttribute("ChariotArmorOffUntil") or 0) > now()
end

function Polnareff.M1(S, player, state, aim)
	local character = state.Character
	Moves.m1(S, player, state, aim, (character and armorOff(character)) and cfg.M1ArmorOff or cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: HORA HORA RUSH
---------------------------------------------------------------------------
local function horaRush(S, player, state, aim)
	local c = cfg.HoraRush
	if not ready(S, player, state, "HoraRush", 1) then
		return
	end
	S.startCooldown(player, state, "HoraRush", c.Cooldown, 1)
	S.lock(state, c.Windup + c.Duration + 0.15)
	local character, humanoid = alive(S, player)
	local life = state.Life
	local untilT = now() + c.Windup + c.Duration
	character:SetAttribute("HoraRushUntil", untilT)
	S.Adapter.setMoveModifier(humanoid, "HoraRush", c.WalkMultiplier)
	S.fx("Ability", { Character = character, Act = ACT, Move = "HoraRush", Phase = "Start", Windup = c.Windup, Duration = c.Duration })
	local ticks = math.max(1, math.floor(c.Duration / c.Tick))
	local function stop()
		if humanoid.Parent then
			S.Adapter.setMoveModifier(humanoid, "HoraRush", nil)
		end
		if character.Parent and character:GetAttribute("HoraRushUntil") == untilT then
			character:SetAttribute("HoraRushUntil", nil)
		end
	end
	for i = 1, ticks do
		task.delay(c.Windup + (i - 1) * c.Tick, function()
			if character:GetAttribute("HoraRushUntil") ~= untilT then
				return -- already over
			end
			if not S.stillValid(player, state, life) then
				-- Stunned (or gone) out of it: The World goes back.
				stop()
				S.fx("Ability", { Character = character, Act = ACT, Move = "HoraRush", Phase = "Stop" })
				return
			end
			local _, _, r = alive(S, player)
			local boxCF = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
			local last = i == ticks
			if last then
				Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.FinalDamage, Stun = c.FinalStun, Knockback = c.FinalKnockback, Launch = c.FinalLaunch, Direction = r.CFrame.LookVector, Source = "PolnareffRush" }, c.MaxTargets)
				-- The last punch's shockwave catches everyone in front.
				local waveAt = (r.CFrame * CFrame.new(0, 0, -c.HitboxForward - 3)).Position
				Moves.aoe(S, player, waveAt, c.ShockwaveRadius, { Damage = c.ShockwaveDamage, Stun = 0.4, Knockback = 30, Direction = r.CFrame.LookVector, Source = "PolnareffRush" }, 6)
				S.fx("Ability", { Character = character, Act = ACT, Move = "HoraRush", Phase = "Finish", Position = boxCF.Position, Direction = r.CFrame.LookVector, Radius = c.ShockwaveRadius })
				stop()
			else
				local count, hitSet = Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = r.CFrame.LookVector, Source = "PolnareffRush" }, c.MaxTargets)
				-- Drag whoever's caught back in front of The World (they can't slip out).
				for target in pairs(hitSet or {}) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr and not tr.Anchored then
						local to = boxCF.Position - tr.Position
						to = Vector3.new(to.X, 0, to.Z)
						tr.AssemblyLinearVelocity = Vector3.new(to.X * c.Drag, tr.AssemblyLinearVelocity.Y, to.Z * c.Drag) + r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
					end
				end
				if count > 0 and i % 2 == 0 then
					S.fx("Ability", { Act = ACT, Move = "HoraRush", Phase = "Hit", Position = boxCF.Position })
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- 2: ARMOR OFF
---------------------------------------------------------------------------
local function shedArmor(S, player, state)
	local c = cfg.ArmorOff
	if not ready(S, player, state, "ArmorOff", 2) then
		return
	end
	S.startCooldown(player, state, "ArmorOff", c.Cooldown, 2)
	S.lock(state, 0.3)
	local character, humanoid = alive(S, player)
	local untilT = now() + c.Time
	character:SetAttribute("ChariotArmorOffUntil", untilT)
	S.Adapter.setMoveModifier(humanoid, "ArmorOff", c.Speed)
	S.fx("Ability", { Character = character, Act = ACT, Move = "ArmorOff", Phase = "Shed", Time = c.Time })
	task.delay(c.Time, function()
		if character.Parent and character:GetAttribute("ChariotArmorOffUntil") == untilT then
			character:SetAttribute("ChariotArmorOffUntil", nil)
			S.fx("Ability", { Character = character, Act = ACT, Move = "ArmorOff", Phase = "Back" })
		end
		if humanoid.Parent and not armorOff(character) then
			S.Adapter.setMoveModifier(humanoid, "ArmorOff", nil)
		end
	end)
end

---------------------------------------------------------------------------
-- 3: RAPIER SHOT
---------------------------------------------------------------------------
local function rapierShot(S, player, state, aim)
	local c = cfg.RapierShot
	if not ready(S, player, state, "RapierShot", 3) then
		return
	end
	S.startCooldown(player, state, "RapierShot", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "RapierShot", Phase = "Aim", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = S.aim(aim, r)
		local origin = S.origin(char, r, Moves.HAND)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local wall = workspace:Raycast(origin, dir * c.Range, params)
		local reach = c.Range
		if wall and not (wall.Instance.Parent and wall.Instance.Parent:FindFirstChildOfClass("Humanoid")) then
			reach = (wall.Position - origin).Magnitude
		end
		local mid = origin + dir * (reach / 2)
		local best, bestD, bestPos
		for _, target in ipairs(S.Hitbox.inBox(char, CFrame.lookAt(mid, mid + dir), Vector3.new(c.Width, c.Width + 2, reach), 8)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr then
				local d = (tr.Position - origin):Dot(dir)
				if d > 0 and (not bestD or d < bestD) then
					best, bestD, bestPos = target, d, tr.Position
				end
			end
		end
		local landed = false
		if best then
			landed = S.hit(player, best, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Position = bestPos, Source = "PolnareffShot" })
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "RapierShot", Phase = "Fire", From = origin, To = bestPos or (origin + dir * reach), Hit = landed })
	end)
end

function Polnareff.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		horaRush(S, player, state, aim)
	elseif slot == 2 then
		shedArmor(S, player, state)
	elseif slot == 3 then
		rapierShot(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- AFTERIMAGE STORM (ultimate)
---------------------------------------------------------------------------
function Polnareff.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.3)
	character:SetAttribute("Armored", true)
	local target = Moves.findTarget(S, character, root, u.Range, u.Cone, S.aim(aim, root))
	local tr = target and target:FindFirstChild("HumanoidRootPart")
	local center = tr and tr.Position or (root.Position + Moves.flat(root.CFrame.LookVector) * 8)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Split", Windup = u.Windup, Position = center, Radius = u.Radius, Images = u.Images })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		-- The ring follows the target if there is one.
		local function centerNow()
			local p = tr and tr.Parent and tr.Position
			return p or center
		end
		S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Storm", Position = centerNow(), Target = target, Radius = u.Radius, Images = u.Images, Duration = u.Duration })
		local ticks = math.max(1, math.floor(u.Duration / u.Tick))
		for k = 1, ticks do
			task.delay(k * u.Tick, function()
				if state.Life ~= life or not character.Parent then
					return
				end
				local at = centerNow()
				for _, t in ipairs(S.Hitbox.inRadius(character, at, u.Radius, 8)) do
					local r2 = t:FindFirstChild("HumanoidRootPart")
					if r2 then
						S.hit(player, t, { Damage = u.TickDamage, Stun = u.TickStun, Knockback = 0, Direction = Vector3.new(0, 1, 0), Position = r2.Position, Source = "PolnareffStorm" })
					end
				end
			end)
		end
		task.delay(u.Duration + 0.05, function()
			if state.Life ~= life or not character.Parent then
				S.fx("Ultimate", { Character = character, Act = ACT, Phase = "End" })
				return
			end
			local at = centerNow()
			local _, _, r = alive(S, player)
			for _, t in ipairs(S.Hitbox.inRadius(character, at, u.Radius, 8)) do
				local r2 = t:FindFirstChild("HumanoidRootPart")
				if r2 then
					local dir = r and Vector3.new(r2.Position.X - r.Position.X, 0, r2.Position.Z - r.Position.Z) or Vector3.new(0, 0, 1)
					S.hit(player, t, { Damage = u.FinalDamage, Stun = u.FinalStun, Knockback = u.FinalKnockback, Launch = u.FinalLaunch, Direction = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, 1), Position = r2.Position, Unblockable = true, Source = "PolnareffFinal" })
				end
			end
			S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Final", Position = at, Radius = u.Radius })
		end)
	end)
end

function Polnareff.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("HoraRushUntil", nil)
		character:SetAttribute("ChariotArmorOffUntil", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "HoraRush", nil)
			S.Adapter.setMoveModifier(humanoid, "ArmorOff", nil)
		end
	end
end

return Polnareff
```
