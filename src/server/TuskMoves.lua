--[[
	TuskMoves  (ServerScriptService.SpinServer.TuskMoves)

	Shared server building blocks for every Tusk Act, so each Act module
	only describes what makes it different:
	  m1(...)          generic 4-hit combo (portals, multi-hits, AoE finisher, nail hits)
	  findTarget(...)  nearest valid enemy in a cone with line of sight
	  aoe(...)         radius hit with line-of-sight checks
	  boxHit(...)      oriented box hit
	  safeStep(...)    validated short teleport / dash destination
	  nail(...)        fire a nail with standard damage handling
	All damage still goes through TuskService.hit -> CombatAdapter.
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)

local TuskMoves = {}
TuskMoves.HAND = CFrame.new(0.9, 0.55, -1.5)

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 1e-3 and f.Unit or Vector3.new(0, 0, -1)
end
TuskMoves.flat = flat

---------------------------------------------------------------------------
-- Targeting and area damage
---------------------------------------------------------------------------
function TuskMoves.findTarget(S, character, root, range, coneDegrees, direction)
	local look = flat(direction or root.CFrame.LookVector)
	local cosLimit = math.cos(math.rad((coneDegrees or 360) / 2))
	local best, bestDistance
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, range)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and S.Adapter.canBeHit(nil, target) then
			local offset = tr.Position - root.Position
			local f = Vector3.new(offset.X, 0, offset.Z)
			if f.Magnitude < 0.5 or f.Unit:Dot(look) >= cosLimit then
				if S.Hitbox.lineOfSight(root.Position, tr.Position, { character, target }) then
					if not bestDistance or offset.Magnitude < bestDistance then
						best, bestDistance = target, offset.Magnitude
					end
				end
			end
		end
	end
	return best
end

-- Damage everyone in a radius (line of sight from `center`). Returns hit count.
function TuskMoves.aoe(S, player, center, radius, info, maxTargets, exclude)
	local character = player.Character
	local count = 0
	for _, target in ipairs(S.Hitbox.inRadius(character, center, radius, maxTargets or 8)) do
		if not (exclude and exclude[target]) then
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.Hitbox.lineOfSight(center, tr.Position, { character, target }) then
				local hitInfo = table.clone(info)
				hitInfo.Direction = info.Direction or (tr.Position - center)
				hitInfo.Position = tr.Position
				if S.hit(player, target, hitInfo) then
					count = count + 1
				end
			end
		end
	end
	return count
end

function TuskMoves.boxHit(S, player, cframe, size, info, maxTargets)
	local character, _, root = alive(S, player)
	local count, hitSet = 0, {}
	if not character then
		return 0, hitSet
	end
	for _, target in ipairs(S.Hitbox.inBox(character, cframe, size, maxTargets or 3)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and S.Hitbox.lineOfSight(root.Position, tr.Position, { character, target }) then
			local hitInfo = table.clone(info)
			hitInfo.Direction = info.Direction or (tr.Position - root.Position)
			hitInfo.Position = tr.Position
			if S.hit(player, target, hitInfo) then
				count = count + 1
				hitSet[target] = true
			end
		end
	end
	return count, hitSet
end

---------------------------------------------------------------------------
-- Movement
---------------------------------------------------------------------------
-- Validated destination for a short teleport/dash along a flat direction.
-- Stops before walls, needs ground below, and free space to stand in.
function TuskMoves.safeStep(character, root, direction, distance)
	local dir = flat(direction)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild("SpinClientFX") }
	local wall = workspace:Raycast(root.Position, dir * distance, params)
	local travel = wall and (wall.Distance - 2.5) or distance
	if travel < 3 then
		return nil
	end
	local groundHere = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	local height = groundHere and (root.Position.Y - groundHere.Position.Y) or 3
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	-- Walk back from the furthest point until a valid spot is found.
	local d = travel
	while d >= 3 do
		local probe = root.Position + dir * d
		local ground = workspace:Raycast(probe + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), params)
		if ground then
			local stand = Vector3.new(probe.X, ground.Position.Y + height, probe.Z)
			local blocked = false
			for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(stand), Vector3.new(2, 4.5, 2), overlap)) do
				if part.CanCollide then
					blocked = true
					break
				end
			end
			if not blocked then
				return stand
			end
		end
		d = d - 2
	end
	return nil
end

function TuskMoves.groundBelow(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position or position
end

---------------------------------------------------------------------------
-- Nails
---------------------------------------------------------------------------
--[[ spec: Origin, Direction, Speed, Radius, Range, Style, Charge,
          Damage, Stun, Knockback, Launch, Source, OnEnd ]]
function TuskMoves.nail(S, player, state, spec)
	return S.fireNail(player, state, {
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius or 0.7,
		Range = spec.Range,
		Style = spec.Style,
		Charge = spec.Charge,
		OnHit = function(target, position)
			S.hit(player, target, {
				Damage = spec.Damage,
				Stun = spec.Stun,
				Knockback = spec.Knockback,
				Launch = spec.Launch,
				Direction = spec.Direction,
				Position = position,
				Source = spec.Source or "TuskNail",
			})
		end,
		OnEnd = spec.OnEnd,
	})
end

---------------------------------------------------------------------------
-- Generic M1 combo
---------------------------------------------------------------------------
--[[ m1cfg.Hits[i] fields: Damage, Stun, Knockback, Launch,
     Portal (cosmetic), Repeat + RepeatInterval (multi-hit), AoeRadius
     (finisher hits a radius instead of the box), ShockwaveRadius (visual),
     Projectile = { Speed, Radius, Range } (nail instead of melee) ]]
function TuskMoves.m1(S, player, state, aim, m1cfg, act)
	if S.isBusy(state) or state.Charging then
		return
	end
	local now = os.clock()
	if now - state.LastM1 > m1cfg.ResetAfter then
		state.Combo = 0
	end
	local index = state.Combo + 1
	state.Combo = index >= 4 and 0 or index
	state.LastM1 = now
	local hit = m1cfg.Hits[index]
	local repeatTime = (hit.Repeat or 1) > 1 and (hit.Repeat - 1) * (hit.RepeatInterval or 0.08) or 0
	S.lock(state, (index == 4 and m1cfg.EndLag or m1cfg.Interval) + repeatTime)

	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("M1", { Character = character, Act = act, Index = index, Portal = hit.Portal == true, Repeat = hit.Repeat })

	local function strike(isLast)
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		if hit.Projectile then
			TuskMoves.nail(S, player, state, {
				Origin = S.origin(char, r, TuskMoves.HAND),
				Direction = direction,
				Speed = hit.Projectile.Speed,
				Radius = hit.Projectile.Radius,
				Range = hit.Projectile.Range,
				Style = "M1",
				Damage = hit.Damage,
				Stun = hit.Stun,
				Knockback = hit.Knockback,
				Source = "TuskM1",
			})
			return
		end
		local boxCF = r.CFrame * CFrame.new(0, 0, -m1cfg.HitboxForward)
		local info = { Damage = hit.Damage, Stun = hit.Stun, Knockback = hit.Knockback, Launch = hit.Launch, Source = "TuskM1" }
		local landed
		if hit.AoeRadius and isLast then
			landed = TuskMoves.aoe(S, player, boxCF.Position, hit.AoeRadius, info, 5) > 0
		else
			landed = TuskMoves.boxHit(S, player, boxCF, m1cfg.HitboxSize, info, m1cfg.MaxTargets) > 0
		end
		if index == 4 and isLast then
			S.fx("M1Finisher", { Character = char, Act = act, Position = boxCF.Position, Radius = hit.ShockwaveRadius or 7, Hit = landed })
		end
	end

	local count = hit.Repeat or 1
	for i = 1, count do
		task.delay(m1cfg.Windup + (i - 1) * (hit.RepeatInterval or 0.08), function()
			strike(i == count)
		end)
	end
end

-- Ring of points around a center (portal placement shared by server and client payloads).
function TuskMoves.ring(center, count, radius, yaw, heightA, heightB)
	local points = {}
	for i = 1, count do
		local angle = (yaw or 0) + (i - 1) / count * math.pi * 2
		local h = (i % 2 == 0) and (heightB or 6) or (heightA or 4)
		table.insert(points, center + Vector3.new(math.cos(angle) * radius, h, math.sin(angle) * radius))
	end
	return points
end

TuskMoves.Config = TuskConfig
return TuskMoves
