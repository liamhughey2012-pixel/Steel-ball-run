--[[
	DiegoBrando  (ServerScriptService.SpinServer.TuskActs.DiegoBrando)

	Diego Brando: SCARY MONSTERS (dinosaur Stand). Registered as "Act" 6 so it
	reuses the Tusk ability system (cooldowns, HUD, ultimate meter, input).
	  M1        CLAW COMBO: claw, claw, tail whip, bite (area). Stronger and
	            faster while transformed.
	  Ability 1 RAPTOR POUNCE: crouch, then leap at the nearest enemy in front
	            and land on them (bite + area hit). Hits harder transformed.
	  Ability 2 DINO INFECTION: a bite that infects: the target is slowed and
	            takes damage over time while dinosaur scales spread on them
	  Ability 3 SCARY MONSTERS: turn into a full raptor for a while: faster,
	            stronger claws, and KINETIC VISION (moving enemies glow for
	            Diego). Press again to change back early.
	  Ultimate  RAPTOR PACK: a roar that stuns everyone close, then a pack of
	            raptors charges out in a fan, mauling everything in their path
	Numbers: TuskConfig.Diego. All damage goes through S.hit (CombatAdapter).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Diego = {}
local cfg = TuskConfig.Diego
local ACT = 6

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Diego.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, state.DinoMode and cfg.DinoM1 or cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- SCARY MONSTERS (transformation)
---------------------------------------------------------------------------
local function revert(S, player, state, startCooldown)
	if not state.DinoMode then
		return
	end
	state.DinoMode = nil
	local character = state.Character
	if character then
		character:SetAttribute("DinoMode", nil)
		character:SetAttribute("DinoModeUntil", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "ScaryMonsters", nil)
		end
		S.fx("Ability", { Character = character, Act = ACT, Move = "ScaryMonsters", Phase = "Revert" })
	end
	if startCooldown then
		S.startCooldown(player, state, "ScaryMonsters", cfg.ScaryMonsters.Cooldown, 3)
	end
end

local function scaryMonsters(S, player, state)
	local c = cfg.ScaryMonsters
	if state.DinoMode then
		revert(S, player, state, true) -- press again: change back early
		return
	end
	if not ready(S, player, state, "ScaryMonsters", 3) then
		return
	end
	local character, humanoid = alive(S, player)
	local token = {}
	state.DinoMode = token
	S.lock(state, c.Transform)
	character:SetAttribute("Armored", true)
	S.fx("Ability", { Character = character, Act = ACT, Move = "ScaryMonsters", Phase = "Transform", Duration = c.Transform })
	task.delay(c.Transform * 0.6, function()
		if state.DinoMode ~= token or not character.Parent then
			return
		end
		character:SetAttribute("DinoMode", true)
		character:SetAttribute("DinoModeUntil", workspace:GetServerTimeNow() + c.Duration)
		S.Adapter.setMoveModifier(humanoid, "ScaryMonsters", c.SpeedMultiplier)
	end)
	task.delay(c.Transform, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
	end)
	task.delay(c.Duration + c.Transform * 0.6, function()
		if state.DinoMode == token then
			revert(S, player, state, true)
		end
	end)
end

---------------------------------------------------------------------------
-- RAPTOR POUNCE
---------------------------------------------------------------------------
local function raptorPounce(S, player, state, aim)
	local c = cfg.RaptorPounce
	if not ready(S, player, state, "RaptorPounce", 1) then
		return
	end
	S.startCooldown(player, state, "RaptorPounce", c.Cooldown, 1)
	S.lock(state, c.Windup + c.LeapTime + 0.2)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "RaptorPounce", Phase = "Startup", Windup = c.Windup, Direction = direction })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		-- Leap at the nearest enemy in front, or straight ahead.
		local distance = c.Distance
		local target = Moves.findTarget(S, char, r, c.Distance, c.TargetCone, direction)
		local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			local offset = targetRoot.Position - r.Position
			local flatOffset = Vector3.new(offset.X, 0, offset.Z)
			if flatOffset.Magnitude > 0.5 then
				direction = flatOffset.Unit
				distance = math.max(4, flatOffset.Magnitude - 2.5)
			end
		end
		local destination = Moves.safeStep(char, r, direction, distance)
		local from = r.Position
		local travel = destination and Vector3.new(destination.X - from.X, 0, destination.Z - from.Z) or Vector3.new()
		-- Arc: rise for the first half, fall for the second (LinearVelocity, like knockback).
		local attachment = Instance.new("Attachment")
		attachment.Name = "DiegoPounce"
		attachment.Parent = r
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.MaxForce = math.huge
		local horizontal = travel / c.LeapTime
		local up = c.LeapHeight / (c.LeapTime / 2)
		velocity.VectorVelocity = horizontal + Vector3.new(0, up, 0)
		velocity.Parent = attachment
		r.CFrame = CFrame.lookAt(r.Position, r.Position + direction)
		S.fx("Ability", { Character = char, Act = ACT, Move = "RaptorPounce", Phase = "Leap", From = from, To = destination or from, Time = c.LeapTime, Direction = direction })
		task.delay(c.LeapTime / 2, function()
			if velocity.Parent then
				velocity.VectorVelocity = horizontal + Vector3.new(0, -up, 0)
			end
		end)
		task.delay(c.LeapTime, function()
			attachment:Destroy()
			if state.Life ~= life then
				return
			end
			local _, _, rr = alive(S, player)
			if not rr then
				return
			end
			rr.AssemblyLinearVelocity = Vector3.new(0, rr.AssemblyLinearVelocity.Y, 0)
			local damage = c.Damage * (state.DinoMode and cfg.ScaryMonsters.PounceMultiplier or 1)
			local landAt = rr.Position + direction * 1.5
			local count = Moves.aoe(S, player, landAt, c.HitRadius, { Damage = damage, Stun = c.Stun, Knockback = c.Knockback, Direction = direction, Source = "DiegoPounce" }, 4)
			S.fx("Ability", { Character = char, Act = ACT, Move = "RaptorPounce", Phase = "Land", Position = rr.Position, Direction = direction, Radius = c.HitRadius, Hit = count > 0 })
		end)
	end)
end

---------------------------------------------------------------------------
-- DINO INFECTION
---------------------------------------------------------------------------
local function infect(S, player, target, c)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local token = tostring({})
	target:SetAttribute("DinoInfected", token)
	S.Adapter.setMoveModifier(humanoid, "DinoInfection", c.InfectSlow)
	local ticks = math.floor(c.InfectTime / c.InfectTick)
	for i = 1, ticks do
		task.delay(i * c.InfectTick, function()
			if target:GetAttribute("DinoInfected") == token and humanoid.Health > 0 then
				local tr = target:FindFirstChild("HumanoidRootPart")
				S.hit(player, target, { Damage = c.InfectDamage, Stun = 0, Knockback = 0, Direction = Vector3.new(0, 0, 0), Position = tr and tr.Position or nil, Source = "DiegoInfection" })
			end
		end)
	end
	task.delay(c.InfectTime, function()
		if target:GetAttribute("DinoInfected") == token then
			target:SetAttribute("DinoInfected", nil)
			if humanoid.Parent then
				S.Adapter.setMoveModifier(humanoid, "DinoInfection", nil)
			end
		end
	end)
end

local function dinoInfection(S, player, state, aim)
	local c = cfg.DinoInfection
	if not ready(S, player, state, "DinoInfection", 2) then
		return
	end
	S.startCooldown(player, state, "DinoInfection", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.35)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "DinoInfection", Phase = "Startup", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local _, _, r = alive(S, player)
		local cf = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
		local count, hitSet = Moves.boxHit(S, player, cf, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Source = "DiegoInfection" }, 2)
		for target in pairs(hitSet) do
			infect(S, player, target, c)
		end
		S.fx("Ability", { Character = character, Act = ACT, Move = "DinoInfection", Phase = "Hit", Position = cf.Position, Hit = count > 0 })
	end)
end

function Diego.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		raptorPounce(S, player, state, aim)
	elseif slot == 2 then
		dinoInfection(S, player, state, aim)
	elseif slot == 3 then
		scaryMonsters(S, player, state)
	end
end

---------------------------------------------------------------------------
-- RAPTOR PACK (ultimate)
---------------------------------------------------------------------------
function Diego.Ultimate(S, player, state, aim)
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
	S.lock(state, u.Windup + 0.3)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Roar", Position = root.Position, Radius = u.RoarRadius, Windup = u.Windup, Direction = direction })
	-- The roar: stuns everyone close.
	task.delay(u.Windup * 0.35, function()
		if state.Life ~= life then
			return
		end
		local _, _, r = alive(S, player)
		if r then
			Moves.aoe(S, player, r.Position, u.RoarRadius, { Damage = u.RoarDamage, Stun = u.RoarStun, Knockback = 6, Source = "DiegoRoar" }, 8)
		end
	end)
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local char, _, r = alive(S, player)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local raptors = {}
		local bitten = {} -- target -> how many raptors have bitten it
		local maxBites = u.MaxHitsPerTarget or 2
		local baseId = tostring(os.clock()) .. player.UserId
		for i = 1, u.Count do
			local angle = math.rad((i - (u.Count + 1) / 2) * u.Spread)
			local dir = (CFrame.Angles(0, angle, 0) * CFrame.lookAt(Vector3.new(), direction)).LookVector
			dir = Moves.flat(dir)
			local origin = Moves.groundBelow(r.Position + dir * 2, { char })
			raptors[i] = { Id = baseId .. "_" .. i, Origin = origin, Direction = dir, Pos = origin, Traveled = 0, Hit = {}, Done = false }
		end
		local payload = {}
		for i, rp in ipairs(raptors) do
			payload[i] = { Id = rp.Id, Origin = rp.Origin, Direction = rp.Direction }
		end
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Release", Raptors = payload, Speed = u.Speed, Range = u.Range })
		local ticks = math.ceil(u.Range / (u.Speed * u.Tick))
		for t = 1, ticks do
			task.delay(t * u.Tick, function()
				for _, rp in ipairs(raptors) do
					if not rp.Done then
						local step = rp.Direction * u.Speed * u.Tick
						local wall = workspace:Raycast(rp.Pos + Vector3.new(0, 2.5, 0), step * 1.2, params)
						rp.Traveled = rp.Traveled + step.Magnitude
						if wall or rp.Traveled >= u.Range then
							rp.Done = true
							S.fx("Ultimate", { Act = ACT, Phase = "RaptorEnd", Id = rp.Id, Position = rp.Pos })
						else
							rp.Pos = Moves.groundBelow(rp.Pos + step, { char })
							for _, target in ipairs(S.Hitbox.inRadius(player.Character, rp.Pos + Vector3.new(0, 2.5, 0), u.HitRadius, 4)) do
								if not rp.Hit[target] and (bitten[target] or 0) < maxBites and S.Adapter.canBeHit(player, target) then
									rp.Hit[target] = true
									bitten[target] = (bitten[target] or 0) + 1
									local tr = target:FindFirstChild("HumanoidRootPart")
									S.hit(player, target, { Damage = u.Damage, Stun = u.Stun, Knockback = u.Knockback, Launch = u.Launch, Direction = rp.Direction, Position = tr and tr.Position or rp.Pos, Source = "DiegoRaptorPack" })
									S.fx("Ultimate", { Act = ACT, Phase = "RaptorBite", Id = rp.Id, Position = tr and tr.Position or rp.Pos })
								end
							end
						end
					end
				end
			end)
		end
		S.finishUltimate(player, state)
	end)
end

function Diego.Cleanup(S, player, state)
	revert(S, player, state, false)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
	end
end

return Diego
