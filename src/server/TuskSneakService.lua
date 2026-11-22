--[[
	TuskSneakService  (ServerScriptService.SpinServer.TuskSneakService)

	Tusk Sneak (every Act): a crouched, slowed stalking state, plus the
	Sneak Attack (M1 while sneaking):
	  1. Tusk sinks into the ground (Burrow): invisible and briefly untargetable
	  2. a distortion warning appears under the target (WarningTime before emergence)
	  3. Tusk emerges behind the target at a server-validated safe spot
	  4. surprise hit + launch, finished with a blue shockwave

	Counterplay: the warning is visible and audible, a target that moves
	MaxTargetDrift studs away is missed, getting hit breaks sneak, and both
	sneak and the attack have cooldowns.

	Character attributes: TuskSneaking, TuskBurrowed.
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Adapter = require(script.Parent.CombatAdapter)
local Cooldowns = require(script.Parent.CooldownService)
local Hitbox = require(script.Parent.TuskHitbox)

local TuskSneakService = {}
local S -- TuskService

local cfg = TuskConfig.Sneak

function TuskSneakService.init(service)
	S = service
end

function TuskSneakService.exit(player, state, applyCooldown)
	if not state.Sneaking then
		return
	end
	state.Sneaking = false
	state.SneakToken = nil
	local character = state.Character
	if character then
		character:SetAttribute("TuskSneaking", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Adapter.setMoveModifier(humanoid, "TuskSneak", nil)
		end
	end
	if applyCooldown then
		Cooldowns.start(player, "TuskSneak", cfg.Cooldown)
		S.tell(player, "SneakCooldown", { Duration = cfg.Cooldown })
	end
end

function TuskSneakService.toggle(player, state, on)
	if not on then
		TuskSneakService.exit(player, state, true)
		return
	end
	if state.Sneaking or state.Charging or S.isBusy(state) or not Adapter.canAct(player) then
		return
	end
	local remaining = Cooldowns.remaining(player, "TuskSneak")
	if remaining > 0 then
		S.tell(player, "Denied", { Reason = "SneakCooldown", Remaining = remaining })
		return
	end
	local character, humanoid = Adapter.getAlive(player)
	state.Sneaking = true
	local token = {}
	state.SneakToken = token
	character:SetAttribute("TuskSneaking", true)
	Adapter.setMoveModifier(humanoid, "TuskSneak", cfg.WalkSpeedMultiplier)
	task.delay(cfg.MaxDuration, function()
		if state.SneakToken == token then
			TuskSneakService.exit(player, state, true)
		end
	end)
end

-- Nearest enemy in front, in range, with line of sight.
local function findTarget(character, root)
	local best, bestDistance
	local cosLimit = math.cos(math.rad(cfg.Attack.ConeDegrees / 2))
	for _, target in ipairs(Hitbox.inRadius(character, root.Position, cfg.Attack.Range)) do
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if targetRoot and Adapter.canBeHit(nil, target) then
			local offset = targetRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			if flat.Magnitude > 0.1 and flat.Unit:Dot(look.Unit) >= cosLimit then
				if Hitbox.lineOfSight(root.Position, targetRoot.Position, { character, target }) then
					if not bestDistance or offset.Magnitude < bestDistance then
						best, bestDistance = target, offset.Magnitude
					end
				end
			end
		end
	end
	return best
end

-- Safe emergence point near the target: behind first, then the sides, then in front.
-- Must have clear line of sight from the target, solid ground below and free space.
local function emergePoint(attacker, target)
	local targetRoot = target.HumanoidRootPart
	local d = cfg.Attack.EmergeDistance
	local candidates = {
		targetRoot.CFrame * CFrame.new(0, 0, d),
		targetRoot.CFrame * CFrame.new(d, 0, 0),
		targetRoot.CFrame * CFrame.new(-d, 0, 0),
		targetRoot.CFrame * CFrame.new(0, 0, -d),
	}
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { attacker, target }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { attacker, target }
	for _, cf in ipairs(candidates) do
		local pos = cf.Position
		if Hitbox.lineOfSight(targetRoot.Position, pos, { attacker, target }) then
			local ground = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), rayParams)
			if ground then
				local standPos = ground.Position + Vector3.new(0, 3, 0)
				local blocking = workspace:GetPartBoundsInBox(CFrame.new(standPos), Vector3.new(2, 4.5, 2), overlap)
				local solid = false
				for _, part in ipairs(blocking) do
					if part.CanCollide then
						solid = true
						break
					end
				end
				if not solid then
					return standPos
				end
			end
		end
	end
	return nil
end

function TuskSneakService.attack(player, state)
	local a = cfg.Attack
	if S.isBusy(state) or state.Charging then
		return
	end
	local remaining = Cooldowns.remaining(player, "TuskSneakAttack")
	if remaining > 0 then
		S.tell(player, "Denied", { Reason = "SneakAttackCooldown", Remaining = remaining })
		return
	end
	local character, _, root = Adapter.getAlive(player)
	local target = findTarget(character, root)
	if not target then
		Cooldowns.start(player, "TuskSneakAttack", a.FailCooldown)
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end

	TuskSneakService.exit(player, state, true)
	Cooldowns.start(player, "TuskSneakAttack", a.Cooldown)
	S.tell(player, "SneakAttackCooldown", { Duration = a.Cooldown })
	S.lock(state, a.BurrowTime + 0.45)

	local life = state.Life
	local startPos = root.Position
	local targetStart = target.HumanoidRootPart.Position
	state.Burrowed = true
	character:SetAttribute("TuskBurrowed", true)
	character:SetAttribute(Adapter.Settings.IFrameAttribute, true)
	-- Anchor in place while underground so the hidden body can't wander.
	root.Anchored = true

	S.fx("SneakAttack", { Phase = "Burrow", Character = character, Position = startPos - Vector3.new(0, 2.8, 0), Target = target })

	local function surface()
		state.Burrowed = false
		if character.Parent then
			character:SetAttribute("TuskBurrowed", nil)
			character:SetAttribute(Adapter.Settings.IFrameAttribute, nil)
			if root.Parent then
				root.Anchored = false
			end
		end
	end

	task.delay(a.BurrowTime - a.WarningTime, function()
		if state.Life ~= life or not target.Parent then
			return
		end
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			S.fx("SneakAttack", { Phase = "Warning", Character = character, Target = target, Position = targetRoot.Position - Vector3.new(0, 2.8, 0), Duration = a.WarningTime })
		end
	end)

	task.delay(a.BurrowTime, function()
		if state.Life ~= life or not Adapter.getAlive(player) then
			surface()
			return
		end
		local targetRoot = target.Parent and target:FindFirstChild("HumanoidRootPart")
		local valid = targetRoot
			and Adapter.canBeHit(player, target)
			and (targetRoot.Position - targetStart).Magnitude <= a.MaxTargetDrift
			and (targetRoot.Position - startPos).Magnitude <= a.Range * 1.4
		local pos = valid and emergePoint(character, target) or nil

		surface()
		if not pos then
			-- Whiff: surface where we went under.
			S.fx("SneakAttack", { Phase = "Emerge", Character = character, Position = startPos - Vector3.new(0, 2.8, 0), Hit = false })
			return
		end
		local facing = Vector3.new(targetRoot.Position.X, pos.Y, targetRoot.Position.Z)
		character:PivotTo(CFrame.lookAt(pos, facing))
		S.fx("SneakAttack", { Phase = "Emerge", Character = character, Position = pos - Vector3.new(0, 2.8, 0), Hit = true })

		local hitAny = false
		for _, victim in ipairs(Hitbox.inRadius(character, pos, a.HitRadius, 3)) do
			local victimRoot = victim:FindFirstChild("HumanoidRootPart")
			if victimRoot and Hitbox.lineOfSight(pos, victimRoot.Position, { character, victim }) then
				local hit = S.hit(player, victim, {
					Damage = a.Damage,
					Stun = a.Stun,
					Knockback = a.Knockback,
					Launch = a.Launch,
					Direction = victimRoot.Position - pos,
					Position = victimRoot.Position,
					Source = "TuskSneakAttack",
				})
				hitAny = hitAny or hit
			end
		end
		S.fx("SneakAttack", { Phase = "Shockwave", Character = character, Position = pos - Vector3.new(0, 2.8, 0), Hit = hitAny })
	end)
end

return TuskSneakService
