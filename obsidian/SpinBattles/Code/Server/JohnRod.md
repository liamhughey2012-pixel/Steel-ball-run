---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer › TuskActs"
updated: 2026-11-22
---
# JohnRod

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer › TuskActs` |
| **Exact name** | `JohnRod` (capitals matter) |

**What it does:** JOHN ROD: a Stand that is a single bent metal rod tracing the outline of a man. Its user can send it off and steer it from far away. Registered as "Act" 18 so it reuses the Tusk ability system. M1        ROD STRIKES: John Rod strikes from wherever it is Ability 1 REMOTE CONTROL: send John Rod off and steer it (WASD / thumbstick, up to Pilot.Range studs from you) while you stand still; your camera follows it. Press 1 again to bring it back. If YOU get hit while steering, it snaps back and you reel Ability 2 ROD LASH: the rod whips out straight ahead of John Rod Ability 3 WIRE SNARE: the rod wraps round the nearest enemy near John Rod: they can't move for a moment Ultimate  OUTLINE CAGE: the rod bends into a cage round everyone near John Rod, holds them, then squeezes The server owns John Rod's position: the user's client only sends its movement input ("Steer", many times a second); the server moves the rod (speed limit, range limit, stops at walls, follows the ground) and publishes it on the user's character as StandRemotePos / StandRemoteYaw, which every client's TuskStand uses to draw it there. NPCs can't steer: their John Rod flies at their target on its own. Numbers: TuskConfig.JohnRod. All damage goes through S.hit (CombatAdapter).

## How to add it
1. In Studio's Explorer, find **TuskActs** (ServerScriptService › SpinServer › TuskActs).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **JohnRod**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	JohnRod  (ServerScriptService.SpinServer.TuskActs.JohnRod)

	JOHN ROD: a Stand that is a single bent metal rod tracing the outline of
	a man. Its user can send it off and steer it from far away. Registered
	as "Act" 18 so it reuses the Tusk ability system.
	  M1        ROD STRIKES: John Rod strikes from wherever it is
	  Ability 1 REMOTE CONTROL: send John Rod off and steer it (WASD /
	            thumbstick, up to Pilot.Range studs from you) while you stand
	            still; your camera follows it. Press 1 again to bring it back.
	            If YOU get hit while steering, it snaps back and you reel
	  Ability 2 ROD LASH: the rod whips out straight ahead of John Rod
	  Ability 3 WIRE SNARE: the rod wraps round the nearest enemy near John
	            Rod: they can't move for a moment
	  Ultimate  OUTLINE CAGE: the rod bends into a cage round everyone near
	            John Rod, holds them, then squeezes
	The server owns John Rod's position: the user's client only sends its
	movement input ("Steer", many times a second); the server moves the
	rod (speed limit, range limit, stops at walls, follows the ground) and
	publishes it on the user's character as StandRemotePos / StandRemoteYaw,
	which every client's TuskStand uses to draw it there.
	NPCs can't steer: their John Rod flies at their target on its own.
	Numbers: TuskConfig.JohnRod. All damage goes through S.hit (CombatAdapter).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local JohnRod = {}
local cfg = TuskConfig.JohnRod
local ACT = 18
local STAND_HEIGHT = 4.2 -- John Rod's body sits this far above the ground
local SIDE = CFrame.new(2.8, 0, 1.5) -- where it stands beside its user

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

local function unitOr(v, fallback)
	return v.Magnitude > 1e-3 and v.Unit or fallback
end

local function rayParams(ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

-- Where John Rod is now (its body, at chest height) and the way it faces.
local function rodCFrame(state, root)
	local rod = state.Rod
	if rod and rod.Piloting then
		return CFrame.new(rod.Pos) * CFrame.Angles(0, rod.Yaw, 0)
	end
	local cf = root.CFrame * SIDE
	return CFrame.new(cf.Position + Vector3.new(0, STAND_HEIGHT - 3, 0)) * (root.CFrame - root.CFrame.Position)
end
JohnRod.rodCFrame = rodCFrame

-- A spot at body height on the ground under `pos`.
local function groundAt(pos, ignore)
	local hit = workspace:Raycast(pos + Vector3.new(0, 10, 0), Vector3.new(0, -60, 0), rayParams(ignore))
	return hit and Vector3.new(pos.X, hit.Position.Y + STAND_HEIGHT, pos.Z) or pos
end

local function publish(character, rod)
	if rod and rod.Piloting then
		character:SetAttribute("StandRemotePos", rod.Pos)
		character:SetAttribute("StandRemoteYaw", rod.Yaw)
	else
		character:SetAttribute("StandRemotePos", nil)
		character:SetAttribute("StandRemoteYaw", nil)
	end
end

---------------------------------------------------------------------------
-- REMOTE CONTROL
---------------------------------------------------------------------------
local function endPilot(S, player, state, reason)
	local rod = state.Rod
	if not rod or not rod.Piloting then
		return
	end
	rod.Piloting = false
	rod.Auto = nil
	local character = state.Character
	if character then
		publish(character, nil)
		character:SetAttribute("RodPiloting", nil)
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum then
			S.Adapter.setMoveModifier(hum, "RodPilot", nil)
		end
		S.fx("Ability", { Character = character, Act = ACT, Move = "Pilot", Phase = "Return", From = rod.Pos, Reason = reason })
	end
	S.startCooldown(player, state, "Pilot", cfg.Pilot.Cooldown, 1)
end
JohnRod.endPilot = endPilot

-- One movement step (server time dt): speed, range, walls and ground.
local function stepRod(S, player, state, dt)
	local rod = state.Rod
	local character, _, root = alive(S, player)
	if not root or state.Character ~= character then
		endPilot(S, player, state, "Gone")
		return false
	end
	local p = cfg.Pilot
	if now() >= rod.Until then
		endPilot(S, player, state, "Time")
		return false
	end
	local move = rod.Move
	if rod.Auto then
		-- NPC autopilot: fly at the target, strike when close.
		local tr = rod.Auto.Parent and rod.Auto:FindFirstChild("HumanoidRootPart")
		if not tr then
			endPilot(S, player, state, "Lost")
			return false
		end
		local to = flat(tr.Position - rod.Pos)
		move = to.Magnitude > (cfg.BotAuto.StrikeRange - 1) and to.Unit or Vector3.new()
		if to.Magnitude <= cfg.BotAuto.StrikeRange and now() >= (rod.NextAutoStrike or 0) then
			rod.NextAutoStrike = now() + 0.6
			rod.Yaw = math.atan2(-to.X, -to.Z)
			JohnRod.M1(S, player, state, (tr.Position - rod.Pos).Unit)
		end
	end
	if move and move.Magnitude > 0.05 then
		local dir = unitOr(flat(move), Vector3.new())
		local want = rod.Pos + dir * p.Speed * dt
		-- Keep within range of the user.
		local fromUser = flat(want - root.Position)
		if fromUser.Magnitude > p.Range then
			want = Vector3.new(root.Position.X, want.Y, root.Position.Z) + fromUser.Unit * p.Range
		end
		-- Stop at walls.
		local ignore = { character, workspace:FindFirstChild("SpinClientFX") }
		local wall = workspace:Raycast(rod.Pos, flat(want - rod.Pos), rayParams(ignore))
		if wall then
			want = rod.Pos + flat(want - rod.Pos).Unit * math.max(0, wall.Distance - 1.5)
		end
		local grounded = groundAt(want, ignore)
		-- Don't climb sheer walls: a big step up is a wall too.
		if grounded.Y - rod.Pos.Y < 6 then
			rod.Pos = grounded
		end
		rod.Yaw = math.atan2(-dir.X, -dir.Z)
	end
	publish(character, rod)
	return true
end

local function startPilot(S, player, state, auto)
	local character, _, root = alive(S, player)
	local p = cfg.Pilot
	local start = rodCFrame(state, root)
	local look = start.LookVector
	state.Rod = { Piloting = true, Pos = start.Position, Yaw = math.atan2(-look.X, -look.Z), Move = Vector3.new(), Until = now() + (auto and cfg.BotAuto.Time or p.MaxTime), Auto = auto }
	character:SetAttribute("RodPiloting", true)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		-- You stand still while you steer it.
		S.Adapter.setMoveModifier(hum, "RodPilot", 0)
	end
	publish(character, state.Rod)
	S.fx("Ability", { Character = character, Act = ACT, Move = "Pilot", Phase = "Send", Position = state.Rod.Pos, Range = p.Range })
	local rod = state.Rod
	local last = now()
	local function tick()
		if state.Rod ~= rod or not rod.Piloting then
			return
		end
		local t = now()
		local dt = math.clamp(t - last, 0, 0.2)
		last = t
		if stepRod(S, player, state, dt) then
			task.delay(0.05, tick)
		end
	end
	tick()
end

-- Movement input from the user's client: a flat world-space direction.
function JohnRod.Steer(S, player, state, move)
	local rod = state.Rod
	if not rod or not rod.Piloting or rod.Auto then
		return
	end
	if typeof(move) ~= "Vector3" or move ~= move or move.Magnitude > 2 then
		return
	end
	rod.Move = flat(move)
end

local function pilot(S, player, state)
	local rod = state.Rod
	if rod and rod.Piloting then
		endPilot(S, player, state, "Recall")
		return
	end
	if not ready(S, player, state, "Pilot", 1) then
		return
	end
	local character, _, root = alive(S, player)
	if state.IsBot then
		-- NPCs can't steer: it flies at their target on its own.
		local target = Moves.findTarget(S, character, root, cfg.Pilot.Range * 0.7, 360)
		if not target then
			return
		end
		startPilot(S, player, state, target)
		return
	end
	startPilot(S, player, state, nil)
end

---------------------------------------------------------------------------
-- Hits from John Rod (not from the user)
---------------------------------------------------------------------------
local function hitBox(S, player, cf, size, info, maxTargets)
	local character = player.Character
	if not character then
		return 0
	end
	local count = 0
	for _, target in ipairs(S.Hitbox.inBox(character, cf, size, maxTargets or 4)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			local hitInfo = table.clone(info)
			hitInfo.Direction = info.Direction or flat(tr.Position - cf.Position)
			hitInfo.Position = tr.Position
			if S.hit(player, target, hitInfo) then
				count = count + 1
			end
		end
	end
	return count
end

-- The way John Rod should face for a move: toward the aim, else its own facing.
local function facing(S, state, root, aim)
	local cf = rodCFrame(state, root)
	local dir = typeof(aim) == "Vector3" and flat(aim) or Vector3.new()
	dir = unitOr(dir, flat(cf.LookVector))
	if state.Rod and state.Rod.Piloting then
		state.Rod.Yaw = math.atan2(-dir.X, -dir.Z)
	end
	return CFrame.lookAt(cf.Position, cf.Position + dir), dir
end

function JohnRod.M1(S, player, state, aim)
	local c = cfg.M1
	local character, _, root = alive(S, player)
	if not root or S.isBusy(state) then
		return
	end
	local t = os.clock()
	if t - (state.LastM1 or 0) < c.Interval then
		return
	end
	if t - (state.LastM1 or 0) > c.ResetAfter then
		state.Combo = 0
	end
	state.Combo = (state.Combo or 0) % #c.Hits + 1
	state.LastM1 = t
	local index = state.Combo
	local hit = c.Hits[index]
	if index == #c.Hits then
		S.lock(state, c.EndLag)
	end
	local cf, dir = facing(S, state, root, aim)
	local box = cf * CFrame.new(0, -1, -c.Reach / 2 - 1)
	local n = hitBox(S, player, box, c.Size, { Damage = hit.Damage, Stun = hit.Stun, Knockback = hit.Knockback, Launch = hit.Launch, Direction = dir, Source = "JohnRodStrike" }, 3)
	S.fx("M1", { Character = character, Act = ACT, Index = index, Position = cf.Position, Direction = dir, Hit = n > 0, Remote = state.Rod and state.Rod.Piloting or nil })
end

---------------------------------------------------------------------------
-- 2: ROD LASH
---------------------------------------------------------------------------
local function lash(S, player, state, aim)
	local c = cfg.Lash
	if not ready(S, player, state, "Lash", 2) then
		return
	end
	S.startCooldown(player, state, "Lash", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.15)
	local character, _, root = alive(S, player)
	local life = state.Life
	local cf, dir = facing(S, state, root, aim)
	S.fx("Ability", { Character = character, Act = ACT, Move = "Lash", Phase = "Wind", Position = cf.Position, Direction = dir, Windup = c.Windup })
	task.delay(c.Windup, function()
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local _, _, r = alive(S, player)
		local from = rodCFrame(state, r)
		local box = CFrame.lookAt(from.Position, from.Position + dir) * CFrame.new(0, -1, -c.Length / 2)
		hitBox(S, player, box, Vector3.new(c.Width, 6, c.Length), { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Source = "JohnRodLash" }, 5)
		S.fx("Ability", { Character = character, Act = ACT, Move = "Lash", Phase = "Strike", Position = from.Position, Direction = dir, Length = c.Length })
	end)
end

---------------------------------------------------------------------------
-- 3: WIRE SNARE
---------------------------------------------------------------------------
local snaredUntil = setmetatable({}, { __mode = "k" })

local function snare(S, player, target, seconds, slow)
	local hum = target:FindFirstChildOfClass("Humanoid")
	local untilT = now() + seconds
	snaredUntil[target] = untilT
	target:SetAttribute("SnaredUntil", untilT)
	if hum then
		S.Adapter.setMoveModifier(hum, "RodSnare", slow or 0)
	end
	task.delay(seconds + 0.02, function()
		if snaredUntil[target] == untilT then
			snaredUntil[target] = nil
			if target.Parent then
				target:SetAttribute("SnaredUntil", nil)
			end
			if hum then
				S.Adapter.setMoveModifier(hum, "RodSnare", nil)
			end
		end
	end)
end

local function wireSnare(S, player, state, aim)
	local c = cfg.Snare
	if not ready(S, player, state, "Snare", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local cf = rodCFrame(state, root)
	-- The nearest enemy near John Rod.
	local best, bestD
	for _, t in ipairs(S.Hitbox.inRadius(character, cf.Position, c.Range, 8)) do
		local tr = t:FindFirstChild("HumanoidRootPart")
		local d = tr and (tr.Position - cf.Position).Magnitude
		if d and (not bestD or d < bestD) then
			best, bestD = t, d
		end
	end
	if not best then
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	S.startCooldown(player, state, "Snare", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.1)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "Snare", Phase = "Throw", Position = cf.Position, Target = best, Windup = c.Windup })
	task.delay(c.Windup, function()
		if state.Life ~= life or not best.Parent then
			return
		end
		local tr = best:FindFirstChild("HumanoidRootPart")
		if tr and S.hit(player, best, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = Vector3.new(0, 0, 1), Position = tr.Position, Source = "JohnRodSnare" }) then
			snare(S, player, best, c.Time, 0)
			S.fx("Ability", { Act = ACT, Move = "Snare", Phase = "Bound", Target = best, Duration = c.Time })
		end
	end)
end

function JohnRod.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		pilot(S, player, state)
	elseif slot == 2 then
		lash(S, player, state, aim)
	elseif slot == 3 then
		wireSnare(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- OUTLINE CAGE (ultimate)
---------------------------------------------------------------------------
function JohnRod.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local life = state.Life
	local center = rodCFrame(state, root).Position
	S.lock(state, u.Windup + 0.2)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Bend", Position = center, Radius = u.Radius, Windup = u.Windup })
	task.delay(u.Windup, function()
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local caged = {}
		for _, t in ipairs(S.Hitbox.inRadius(character, center, u.Radius, 10)) do
			table.insert(caged, t)
			snare(S, player, t, u.Time, u.Slow)
		end
		S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Cage", Position = center, Radius = u.Radius, Duration = u.Time, Targets = caged })
		local ticks = math.floor(u.Time / u.Tick)
		for i = 1, ticks do
			task.delay(i * u.Tick, function()
				if state.Life ~= life then
					return
				end
				for _, t in ipairs(caged) do
					local tr = t.Parent and t:FindFirstChild("HumanoidRootPart")
					if tr then
						if i < ticks then
							S.hit(player, t, { Damage = u.TickDamage, Stun = 0, Knockback = 0, Direction = Vector3.new(0, 0, 1), Position = tr.Position, Source = "JohnRodCage" })
						else
							local away = flat(tr.Position - center)
							S.hit(player, t, { Damage = u.SqueezeDamage, Stun = u.SqueezeStun, Knockback = u.SqueezeKnockback, Direction = unitOr(away, Vector3.new(0, 0, 1)), Position = tr.Position, Source = "JohnRodSqueeze" })
						end
					end
				end
				if i == ticks then
					S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Squeeze", Position = center, Radius = u.Radius })
				end
			end)
		end
	end)
end

function JohnRod.Cleanup(S, player, state)
	endPilot(S, player, state, "Switch")
	state.Rod = nil
end

---------------------------------------------------------------------------
-- If YOU are hit while steering it, it snaps back and you reel.
---------------------------------------------------------------------------
local started = false
function JohnRod.Init(S)
	if started then
		return
	end
	started = true
	S.Adapter.on("Hit", function(_, target, _, info)
		if not cfg.Pilot.HitBreaks or not target or not target:GetAttribute("RodPiloting") then
			return
		end
		if info and info.Source and string.sub(info.Source, 1, 7) == "JohnRod" then
			return
		end
		for player, state in pairs(S.States) do
			if state.Character == target and state.Rod and state.Rod.Piloting then
				endPilot(S, player, state, "Hit")
				local hum = target:FindFirstChildOfClass("Humanoid")
				if hum and cfg.Pilot.FeedbackStun > 0 then
					S.Adapter.applyStun(hum, cfg.Pilot.FeedbackStun)
					S.fx("Ability", { Character = target, Act = ACT, Move = "Pilot", Phase = "Feedback" })
				end
			end
		end
	end)
end

return JohnRod
```
