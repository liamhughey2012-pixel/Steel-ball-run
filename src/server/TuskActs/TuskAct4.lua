--[[
	TuskAct4  (ServerScriptService.SpinServer.TuskActs.TuskAct4)

	Tusk Act 4: Infinite Rotation. Gold and deep blue, heavy and majestic.
	  M1        INFINITE BARRAGE: heavy punch, golden spin strike, rapid Stand
	            triple-hit, massive golden rotational finisher (area)
	  Ability 1 GOLDEN SPIN NAIL: big rotating projectile, golden impact blast
	  Ability 2 INFINITE ROTATION (hold): 3 charge stages, bigger projectile and
	            blast per stage
	  Ability 3 GOLDEN PURSUIT: golden rush to the first enemy ahead, rotational
	            strikes, huge golden shockwave
	  Ultimate  INFINITE ROTATION: 10-step cinematic, giant golden rotational
	            projectile, battlefield-wide golden shockwave (final form)
	Numbers: TuskConfig.Act4.
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Act4 = {}
local cfg = TuskConfig.Act4

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Act4.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 4)
end

-- Projectile with an area blast where it lands (direct target excluded from the blast).
local function blastNail(S, player, state, spec, blastRadius, blastDamage, source)
	local directHit = {}
	local base = spec.OnHit
	spec.OnEnd = function(position, _, hitCharacter)
		if hitCharacter then
			directHit[hitCharacter] = true
		end
		Moves.aoe(S, player, position, blastRadius, { Damage = blastDamage, Stun = 0.35, Knockback = 25, Launch = 10, Source = source }, 6, directHit)
	end
	return Moves.nail(S, player, state, spec), base
end

local function goldenSpinNail(S, player, state, aim)
	local c = cfg.GoldenSpinNail
	if not ready(S, player, state, "GoldenSpinNail", 1) then
		return
	end
	S.startCooldown(player, state, "GoldenSpinNail", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.25)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 4, Move = "GoldenSpinNail", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		blastNail(S, player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Golden",
			Damage = c.Damage,
			Stun = c.Stun,
			Knockback = c.Knockback,
			Source = "TuskGoldenSpinNail",
		}, c.ImpactRadius, c.ImpactDamage, "TuskGoldenSpinNail")
	end)
end

local function infiniteRotationRelease(S, player, state, aim)
	local c = cfg.InfiniteRotation
	local charge = S.endCharge(player, state)
	if not charge or charge.Move ~= "InfiniteRotation" then
		return
	end
	local character, _, root = alive(S, player)
	if not character then
		return
	end
	local held = os.clock() - charge.Start
	local stage = 1
	for i, t in ipairs(c.Stages) do
		if held >= t then
			stage = i
		end
	end
	local direction = S.aim(aim, root)
	S.startCooldown(player, state, "InfiniteRotation", c.Cooldown, 2)
	S.lock(state, 0.4)
	S.fx("Ability", { Character = character, Act = 4, Move = "InfiniteRotation", Phase = "Release", Stage = stage, Direction = direction })
	blastNail(S, player, state, {
		Origin = S.origin(character, root, CFrame.new(0, 1.2, -2.5)),
		Direction = direction,
		Speed = c.Speed[stage],
		Radius = c.Radius[stage],
		Range = c.Range,
		Style = "Rotation",
		Charge = stage / 3,
		Damage = c.Damage[stage],
		Stun = c.Stun,
		Knockback = c.Knockback * (0.5 + stage / 6),
		Source = "TuskInfiniteRotation",
	}, c.ImpactRadius[stage], c.ImpactDamage[stage], "TuskInfiniteRotation")
end

local function infiniteRotationPress(S, player, state)
	local c = cfg.InfiniteRotation
	if not ready(S, player, state, "InfiniteRotation", 2) then
		return
	end
	local charge = S.beginCharge(player, state, "InfiniteRotation", 2, c.WalkSpeedMultiplier)
	local token = charge.Token
	task.delay(c.MaxHold, function()
		if state.Charging and state.Charging.Token == token then
			infiniteRotationRelease(S, player, state, nil)
		end
	end)
end

local function goldenPursuit(S, player, state, aim)
	local c = cfg.GoldenPursuit
	if not ready(S, player, state, "GoldenPursuit", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	-- Stop just short of the first enemy along the rush line.
	local distance = c.Distance
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, c.Distance + 4, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			local offset = tr.Position - root.Position
			local along = offset:Dot(direction)
			local side = (offset - direction * along).Magnitude
			if along > 0 and side < 5 and along - 3 < distance then
				distance = math.max(along - 3, 3)
			end
		end
	end
	local destination = Moves.safeStep(character, root, direction, distance)
	if not destination then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "GoldenPursuit", c.Cooldown, 3)
	local gather = 0.2
	S.lock(state, gather + c.Hits * c.HitInterval + 0.45)
	local life = state.Life
	local from = root.Position
	S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Gather", Direction = direction })
	task.delay(gather, function()
		if not S.stillValid(player, state, life) then
			return
		end
		character:SetAttribute(S.Adapter.Settings.IFrameAttribute, true)
		character:PivotTo(CFrame.lookAt(destination, destination + direction))
		S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Dash", From = from, To = destination })
		task.delay(0.15, function()
			if character.Parent then
				character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
			end
		end)
		local front = destination + direction * 3
		for i = 1, c.Hits do
			task.delay(i * c.HitInterval, function()
				if state.Life ~= life then
					return
				end
				Moves.aoe(S, player, front, 6, { Damage = c.HitDamage, Stun = 0.4, Knockback = 3, Direction = direction, Source = "TuskGoldenPursuit" }, 3)
				S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Hit", Position = front, Index = i })
			end)
		end
		task.delay((c.Hits + 1) * c.HitInterval, function()
			if state.Life ~= life then
				return
			end
			Moves.aoe(S, player, front, c.FinalRadius, { Damage = c.FinalDamage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = direction, Source = "TuskGoldenPursuit" }, 6)
			S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Final", Position = front, Radius = c.FinalRadius })
		end)
	end)
end

function Act4.Ability(S, player, state, slot, phase, aim)
	if slot == 1 and phase == "Press" then
		goldenSpinNail(S, player, state, aim)
	elseif slot == 2 then
		if phase == "Press" then
			infiniteRotationPress(S, player, state)
		else
			infiniteRotationRelease(S, player, state, aim)
		end
	elseif slot == 3 and phase == "Press" then
		goldenPursuit(S, player, state, aim)
	end
end

function Act4.CancelCharge(S, player, state)
	local charge = S.endCharge(player, state)
	if charge then
		S.startCooldown(player, state, charge.Move, 2, charge.Slot)
		S.fx("Ability", { Character = state.Character, Act = 4, Move = charge.Move, Phase = "Cancel" })
	end
end

-- INFINITE ROTATION (ultimate)
function Act4.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.lock(state, u.Windup + 0.6)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = 4, Phase = "Start", Windup = u.Windup, Direction = direction })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local _, _, r = alive(S, player)
		S.fx("Ultimate", { Character = character, Act = 4, Phase = "Release", Position = r.Position, Direction = direction })
		blastNail(S, player, state, {
			Origin = S.origin(character, r, CFrame.new(0, 2, -4)),
			Direction = direction,
			Speed = u.Speed,
			Radius = u.ProjectileRadius,
			Range = u.Range,
			Style = "InfiniteUlt",
			Charge = 1,
			Damage = u.Damage,
			Stun = u.Stun,
			Knockback = u.Knockback,
			Launch = u.Launch,
			Source = "TuskInfiniteRotationUlt",
		}, u.BlastRadius, u.BlastDamage, "TuskInfiniteRotationUlt")
		S.finishUltimate(player, state) -- final form: no evolution (Studio refills the meter)
	end)
end

function Act4.Cleanup(S, player, state)
	if state.Charging then
		S.endCharge(player, state)
	end
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
	end
end

return Act4
