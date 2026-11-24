---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer › TuskActs"
updated: 2026-11-22
---
# TuskAct2

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer › TuskActs` |
| **Exact name** | `TuskAct2` (capitals matter) |

**What it does:** Tusk Act 2: wormhole combat. M1        DIMENSIONAL COMBO: Tusk-assisted hits, portal flashes, dimensional finisher Ability 1 WORMHOLE NAIL: nail opens a wormhole where it lands; a second nail bursts out of an exit portal behind the nearest enemy Ability 2 UNDERGROUND PURSUIT: burrow, travel under the ground, emerge behind the target Ability 3 NAIL DIMENSION: three portals around the target fire converging nails, then a dimensional shockwave Ultimate  DIMENSIONAL STORM: six portals rain nail waves, giant blue burst, then Tusk evolves to Act 3 Numbers: TuskConfig.Act2.

## How to add it
1. In Studio's Explorer, find **TuskActs** (ServerScriptService › SpinServer › TuskActs).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **TuskAct2**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskAct2  (ServerScriptService.SpinServer.TuskActs.TuskAct2)

	Tusk Act 2: wormhole combat.
	  M1        DIMENSIONAL COMBO: Tusk-assisted hits, portal flashes, dimensional finisher
	  Ability 1 WORMHOLE NAIL: nail opens a wormhole where it lands; a second nail
	            bursts out of an exit portal behind the nearest enemy
	  Ability 2 UNDERGROUND PURSUIT: burrow, travel under the ground, emerge behind the target
	  Ability 3 NAIL DIMENSION: three portals around the target fire converging nails,
	            then a dimensional shockwave
	  Ultimate  DIMENSIONAL STORM: six portals rain nail waves, giant blue burst,
	            then Tusk evolves to Act 3
	Numbers: TuskConfig.Act2.
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)
local Awakening = require(script.Parent.Parent.TuskAwakening)
local Sneak = require(script.Parent.Parent.TuskSneakService)

local Act2 = {}
local cfg = TuskConfig.Act2

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Act2.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 2)
end

local function wormholeNail(S, player, state, aim)
	local c = cfg.WormholeNail
	if not ready(S, player, state, "WormholeNail", 1) then
		return
	end
	S.startCooldown(player, state, "WormholeNail", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.2)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 2, Move = "WormholeNail", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		Moves.nail(S, player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Wormhole",
			Damage = c.Damage,
			Stun = c.Stun,
			Knockback = c.Knockback,
			Source = "TuskWormholeNail",
			OnEnd = function(position, normal)
				-- Entrance wormhole where the nail landed.
				S.fx("Portal", { Act = 2, Position = position + normal * 0.5, LookAt = position + normal * 5, Radius = 2.4, Duration = c.ExitDelay + 0.35 })
				-- Exit portal behind the nearest enemy near the impact.
				local victims = S.Hitbox.inRadius(char, position, c.ExitSearch, 1)
				local victim = victims[1]
				local vr = victim and victim:FindFirstChild("HumanoidRootPart")
				if not vr then
					return
				end
				local exitPos = (vr.CFrame * CFrame.new(0, 1.5, 6)).Position
				if not S.Hitbox.lineOfSight(vr.Position, exitPos, { char, victim }) then
					exitPos = vr.Position + Vector3.new(0, 7, 0)
				end
				S.fx("Portal", { Act = 2, Position = exitPos, LookAt = vr.Position, Radius = 2.2, Duration = c.ExitDelay + 0.45 })
				task.delay(c.ExitDelay, function()
					if state.Life ~= life or not vr.Parent then
						return
					end
					local dir = (vr.Position - exitPos)
					if dir.Magnitude < 0.5 then
						return
					end
					Moves.nail(S, player, state, {
						Origin = exitPos,
						Direction = dir.Unit,
						Speed = c.Speed,
						Radius = c.Radius,
						Range = dir.Magnitude + 6,
						Style = "Wormhole",
						Damage = c.ExitDamage,
						Stun = c.Stun,
						Knockback = c.Knockback,
						Source = "TuskWormholeNail",
					})
				end)
			end,
		})
	end)
end

local function undergroundPursuit(S, player, state, aim)
	local c = cfg.UndergroundPursuit
	if not ready(S, player, state, "UndergroundPursuit", 2) then
		return
	end
	local character, _, root = alive(S, player)
	local target = Moves.findTarget(S, character, root, c.Range, c.ConeDegrees, S.aim(aim, root))
	if not target then
		S.startCooldown(player, state, "UndergroundPursuit", 1.5, 2)
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	S.startCooldown(player, state, "UndergroundPursuit", c.Cooldown, 2)
	Sneak.burrowStrike(player, state, target, {
		Range = c.Range,
		BurrowTime = c.BurrowTime,
		WarningTime = c.WarningTime,
		EmergeDistance = 3.5,
		MaxTargetDrift = 16,
		HitRadius = c.HitRadius,
		Damage = c.Damage,
		Stun = c.Stun,
		Knockback = c.Knockback,
		Launch = c.Launch,
	}, "TuskUndergroundPursuit")
end

-- Portals around a point fire converging nails, then a shockwave.
local function nailDimension(S, player, state, aim)
	local c = cfg.NailDimension
	if not ready(S, player, state, "NailDimension", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local target = Moves.findTarget(S, character, root, c.Range, c.ConeDegrees, direction)
	local center
	if target then
		center = target.HumanoidRootPart.Position
	else
		center = Moves.groundBelow(root.Position + Moves.flat(direction) * 35, { character }) + Vector3.new(0, 3, 0)
	end
	S.startCooldown(player, state, "NailDimension", c.Cooldown, 3)
	S.lock(state, 0.6)
	local yaw = math.atan2(direction.Z, direction.X)
	local portals = Moves.ring(center, c.Portals, c.PortalRadius, yaw, 4, 8)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 2, Move = "NailDimension", Phase = "Open", Portals = portals, Center = center, OpenTime = c.OpenTime })
	task.delay(c.OpenTime, function()
		if state.Life ~= life then
			return
		end
		local aimAt = (target and target.Parent and target:FindFirstChild("HumanoidRootPart")) and target.HumanoidRootPart.Position or center
		for _, pos in ipairs(portals) do
			local dir = aimAt - pos
			Moves.nail(S, player, state, {
				Origin = pos,
				Direction = dir.Unit,
				Speed = c.Speed,
				Radius = 0.8,
				Range = dir.Magnitude + 8,
				Style = "Portal",
				Damage = c.Damage,
				Stun = c.Stun,
				Knockback = c.Knockback,
				Source = "TuskNailDimension",
			})
		end
		local travel = (portals[1] - aimAt).Magnitude / c.Speed
		task.delay(travel + 0.05, function()
			if state.Life ~= life then
				return
			end
			Moves.aoe(S, player, aimAt, c.FinalRadius, { Damage = c.FinalDamage, Stun = 0.3, Knockback = 20, Launch = 12, Source = "TuskNailDimension" }, 5)
			S.fx("AbilityImpact", { Act = 2, Move = "NailDimension", Position = aimAt, Radius = c.FinalRadius })
		end)
	end)
end

function Act2.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		wormholeNail(S, player, state, aim)
	elseif slot == 2 then
		undergroundPursuit(S, player, state, aim)
	elseif slot == 3 then
		nailDimension(S, player, state, aim)
	end
end

-- DIMENSIONAL STORM
-- G: AWAKENING. Infinite Rotation (TuskAwakening), then Tusk awakens to Act 3.
function Act2.Ultimate(S, player, state, aim)
	return Awakening.use(S, player, state, aim)
end

function Act2.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
	end
end

return Act2
```
