---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer › TuskActs"
updated: 2026-11-22
---
# Josuke

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer › TuskActs` |
| **Exact name** | `Josuke` (capitals matter) |

**What it does:** Josuke Higashikata (JoJolion): SOFT & WET. Its plunder bubbles steal something from whatever they pop on. Registered as "Act" 15 so it reuses the Tusk ability system. M1        SOFT & WET COMBO: Soft & Wet punches with him Ability 1 PLUNDER: FRICTION: a bubble that steals their friction: the pop shoves them and they slide about like on ice for a few seconds (they can barely change direction) Ability 2 PLUNDER: SIGHT: a bubble that steals their sight: their screen goes dark for a few seconds (NPCs lose track of you) Ability 3 BUBBLE MINES: bubbles drift out round him and float there; an enemy who touches one pops it (damage, stun) Ultimate  GO BEYOND: a tiny bubble spinning infinitely, made of a "nothing": slow, but it can't be blocked, and it hits hard Numbers: TuskConfig.Josuke. All damage goes through S.hit (CombatAdapter). Frictionless NPCs slide here on the server; players slide on their own client (JosukeVFX), which also darkens a blinded player's screen.

## How to add it
1. In Studio's Explorer, find **TuskActs** (ServerScriptService › SpinServer › TuskActs).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **Josuke**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	Josuke  (ServerScriptService.SpinServer.TuskActs.Josuke)

	Josuke Higashikata (JoJolion): SOFT & WET. Its plunder bubbles steal
	something from whatever they pop on. Registered as "Act" 15 so it reuses
	the Tusk ability system.
	  M1        SOFT & WET COMBO: Soft & Wet punches with him
	  Ability 1 PLUNDER: FRICTION: a bubble that steals their friction: the
	            pop shoves them and they slide about like on ice for a few
	            seconds (they can barely change direction)
	  Ability 2 PLUNDER: SIGHT: a bubble that steals their sight: their
	            screen goes dark for a few seconds (NPCs lose track of you)
	  Ability 3 BUBBLE MINES: bubbles drift out round him and float there;
	            an enemy who touches one pops it (damage, stun)
	  Ultimate  GO BEYOND: a tiny bubble spinning infinitely, made of a
	            "nothing": slow, but it can't be blocked, and it hits hard
	Numbers: TuskConfig.Josuke. All damage goes through S.hit (CombatAdapter).
	Frictionless NPCs slide here on the server; players slide on their own
	client (JosukeVFX), which also darkens a blinded player's screen.
]]

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Josuke = {}
local cfg = TuskConfig.Josuke
local ACT = 15

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

function Josuke.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- PLUNDER: FRICTION (NPCs slide on the server; players on their client)
---------------------------------------------------------------------------
local function slideNpc(target, untilT, grip)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	local root = target:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	local old = root:FindFirstChild("JosukeSlide")
	if old then
		old:Destroy()
	end
	-- A LinearVelocity takes over from the walk controller, so they only
	-- steer as fast as the stolen grip allows.
	local attach = Instance.new("Attachment")
	attach.Name = "JosukeSlideAttach"
	attach.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Name = "JosukeSlide"
	mover.Attachment0 = attach
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	mover.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	mover.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.MaxForce = 1e6
	local v0 = root.AssemblyLinearVelocity
	mover.PlaneVelocity = Vector2.new(v0.X, v0.Z)
	mover.Parent = root
	local step = 0.05
	local function tick()
		if not root.Parent or humanoid.Health <= 0 or now() >= untilT or target:GetAttribute("NoFrictionUntil") ~= untilT then
			mover:Destroy()
			attach:Destroy()
			return
		end
		local want = humanoid.MoveDirection * humanoid.WalkSpeed
		mover.PlaneVelocity = mover.PlaneVelocity:Lerp(Vector2.new(want.X, want.Z), math.clamp(grip * step, 0, 1))
		task.delay(step, tick)
	end
	tick()
end

local function plunderFriction(S, player, state, aim)
	local c = cfg.PlunderFriction
	if not ready(S, player, state, "PlunderFriction", 1) then
		return
	end
	S.startCooldown(player, state, "PlunderFriction", c.Cooldown, 1)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "PlunderFriction", Phase = "Blow", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local direction = S.aim(aim, r)
		S.fireBubble(player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Friction",
			OnHit = function(target, position)
				if S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = direction, Position = position, Source = "JosukeFriction" }) then
					local untilT = now() + c.Time
					target:SetAttribute("NoFrictionUntil", untilT)
					target:SetAttribute("NoFrictionGrip", c.Grip)
					S.fx("Ability", { Act = ACT, Move = "PlunderFriction", Phase = "Stolen", Target = target, Position = position, Duration = c.Time })
					if not Players:GetPlayerFromCharacter(target) then
						slideNpc(target, untilT, c.Grip)
					end
				end
			end,
		})
	end)
end

---------------------------------------------------------------------------
-- PLUNDER: SIGHT
---------------------------------------------------------------------------
local function plunderSight(S, player, state, aim)
	local c = cfg.PlunderSight
	if not ready(S, player, state, "PlunderSight", 2) then
		return
	end
	S.startCooldown(player, state, "PlunderSight", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "PlunderSight", Phase = "Blow", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local direction = S.aim(aim, r)
		S.fireBubble(player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Sight",
			OnHit = function(target, position)
				if S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 4, Direction = direction, Position = position, Source = "JosukeSight" }) then
					target:SetAttribute("BlindUntil", now() + c.Time)
					S.fx("Ability", { Act = ACT, Move = "PlunderSight", Phase = "Stolen", Target = target, Position = position, Duration = c.Time })
				end
			end,
		})
	end)
end

---------------------------------------------------------------------------
-- BUBBLE MINES
---------------------------------------------------------------------------
local nextMines = 0

local function bubbleMines(S, player, state)
	local c = cfg.BubbleMines
	if not ready(S, player, state, "BubbleMines", 3) then
		return
	end
	S.startCooldown(player, state, "BubbleMines", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local character, _, root = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "BubbleMines", Phase = "Blow", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life, true) then
			return
		end
		local char, _, r = alive(S, player)
		nextMines = nextMines + 1
		local id = nextMines
		local mines = {}
		local yaw = math.atan2(r.CFrame.LookVector.X, r.CFrame.LookVector.Z)
		for i = 1, c.Count do
			local a = yaw + (i - 1) / c.Count * math.pi * 2
			local dist = c.Spread * (0.6 + 0.4 * ((i % 2) + 0.5))
			table.insert(mines, { Pos = r.Position + Vector3.new(math.sin(a) * dist, 1 + (i % 3) * 0.8, math.cos(a) * dist), Alive = true })
		end
		local positions = {}
		for i, m in ipairs(mines) do
			positions[i] = m.Pos
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "BubbleMines", Phase = "Spawn", Id = id, From = r.Position, Positions = positions, Life = c.Life })
		local born = now()
		local function tick()
			local left = 0
			for i, m in ipairs(mines) do
				if m.Alive then
					left = left + 1
					local hits = S.Hitbox.inRadius(char, m.Pos, c.Trigger, 1)
					local target = hits[1]
					local tr = target and target:FindFirstChild("HumanoidRootPart")
					if tr then
						m.Alive = false
						S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = tr.Position - m.Pos, Position = m.Pos, Source = "JosukeMine" })
						S.fx("Ability", { Act = ACT, Move = "BubbleMines", Phase = "Pop", Id = id, Index = i, Position = m.Pos })
					end
				end
			end
			if left == 0 then
				return
			end
			if now() - born >= c.Life then
				S.fx("Ability", { Act = ACT, Move = "BubbleMines", Phase = "Fade", Id = id })
				return
			end
			task.delay(0.1, tick)
		end
		tick()
	end)
end

function Josuke.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		plunderFriction(S, player, state, aim)
	elseif slot == 2 then
		plunderSight(S, player, state, aim)
	elseif slot == 3 then
		bubbleMines(S, player, state)
	end
end

---------------------------------------------------------------------------
-- GO BEYOND (ultimate)
---------------------------------------------------------------------------
function Josuke.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.3)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Charge", Windup = u.Windup })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local char, _, r = alive(S, player)
		local direction = S.aim(aim, r)
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Release", Direction = direction })
		S.fireBubble(player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = u.Speed,
			Radius = u.Radius,
			Range = u.Range,
			Style = "GoBeyond",
			OnHit = function(target, position)
				S.hit(player, target, { Damage = u.Damage, Stun = u.Stun, Knockback = u.Knockback, Launch = u.Launch, Direction = direction, Position = position, Source = "JosukeGoBeyond", Unblockable = true })
				S.fx("Ultimate", { Act = ACT, Phase = "Impact", Position = position, Target = target })
			end,
		})
	end)
end

function Josuke.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
	end
end

return Josuke
```
