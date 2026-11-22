--[[
	GyroZeppeli  (ServerScriptService.SpinServer.TuskActs.GyroZeppeli)

	Gyro Zeppeli: Steel Ball moveset (registered as "Act" 5 so it reuses the
	Tusk ability system: cooldowns, HUD, ultimate meter, input).
	  M1        STEEL BALL COMBO: jab, hook, kick, spinning-ball smash (area)
	  Ability 1 STEEL BALL THROW: the ball flies out, then returns to Gyro's hand
	            (it can hit on the way back)
	  Ability 2 SPIN TORNADO: bowl the spinning ball along the ground; it
	            becomes a travelling tornado that pulls enemies in, juggles
	            them and bursts (stops at walls)
	  Ability 3 SPIN VIBRATION: press the spinning ball into the enemy in front:
	            paralysis (long stun) and a small launch
	  Ultimate  BALL BREAKER: spiral build-up, a huge ball opens a spinning
	            vortex that pulls enemies in, then bursts
	Numbers: TuskConfig.Gyro. All damage goes through S.hit (CombatAdapter).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Gyro = {}
local cfg = TuskConfig.Gyro
local HAND = CFrame.new(0.9, 0.6, -1.6)

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Gyro.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 5)
end

-- Short body "shake" slow from the Spin (stackable, always removed).
local function spinSlow(S, target, multiplier, seconds)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local key = "GyroSpin"
	S.Adapter.setMoveModifier(humanoid, key, multiplier)
	target:SetAttribute("GyroSpinShake", true)
	local token = {}
	target:SetAttribute("GyroSpinToken", tostring(token))
	task.delay(seconds, function()
		if humanoid.Parent and target:GetAttribute("GyroSpinToken") == tostring(token) then
			S.Adapter.setMoveModifier(humanoid, key, nil)
			target:SetAttribute("GyroSpinShake", nil)
		end
	end)
end

local function steelBallThrow(S, player, state, aim)
	local c = cfg.SteelBallThrow
	if not ready(S, player, state, "SteelBallThrow", 1) then
		return
	end
	S.startCooldown(player, state, "SteelBallThrow", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.25)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 5, Move = "SteelBallThrow", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local hitOut = {}
		S.fireBall(player, state, {
			Origin = S.origin(char, r, HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Throw",
			OnHit = function(target, position)
				hitOut[target] = true
				S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = direction, Position = position, Source = "GyroSteelBall" })
			end,
			OnEnd = function(position)
				-- The ball spins its way back to Gyro's hand.
				local _, _, rr = alive(S, player)
				if not rr or state.Life ~= life then
					S.fx("Ability", { Character = char, Act = 5, Move = "SteelBallThrow", Phase = "Caught" })
					return
				end
				local back = rr.Position + Vector3.new(0, 1, 0) - position
				if back.Magnitude < 2 then
					S.fx("Ability", { Character = char, Act = 5, Move = "SteelBallThrow", Phase = "Caught" })
					return
				end
				S.fireBall(player, state, {
					Origin = position,
					Direction = back.Unit,
					Speed = c.ReturnSpeed,
					Radius = c.Radius,
					Range = back.Magnitude,
					Style = "Return",
					OnHit = function(target, pos)
						if not hitOut[target] then
							S.hit(player, target, { Damage = c.ReturnDamage, Stun = 0.3, Knockback = 8, Direction = back.Unit, Position = pos, Source = "GyroSteelBall" })
						end
					end,
					OnEnd = function()
						S.fx("Ability", { Character = char, Act = 5, Move = "SteelBallThrow", Phase = "Caught" })
					end,
				})
			end,
		})
	end)
end

-- SPIN TORNADO: the spinning ball is bowled along the ground and becomes a
-- travelling tornado that pulls enemies in, juggles them, then bursts.
local function spinTornado(S, player, state, aim)
	local c = cfg.SpinTornado
	if not ready(S, player, state, "SpinTornado", 2) then
		return
	end
	S.startCooldown(player, state, "SpinTornado", c.Cooldown, 2)
	S.lock(state, c.Startup + 0.3)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	local id = tostring(os.clock()) .. player.UserId
	S.fx("Ability", { Character = character, Act = 5, Move = "SpinTornado", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local pos = Moves.groundBelow(r.Position + direction * 4, { char }) + Vector3.new(0, 3, 0)
		S.fx("Tornado", { Act = 5, Id = id, Phase = "Start", Position = pos, Radius = c.Radius, Duration = c.Duration })
		local ticks = math.floor(c.Duration / c.Tick)
		local stopped = false
		for i = 1, ticks do
			task.delay(i * c.Tick, function()
				if stopped then
					return
				end
				-- Move forward; stop at walls; follow the ground.
				local step = direction * c.Speed * c.Tick
				if workspace:Raycast(pos, step * 1.5, params) then
					stopped = true
				else
					pos = Moves.groundBelow(pos + step, { char }) + Vector3.new(0, 3, 0)
				end
				S.fx("Tornado", { Act = 5, Id = id, Phase = "Move", Position = pos })
				for _, target in ipairs(S.Hitbox.inRadius(player.Character, pos, c.Radius, 6)) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr and S.Adapter.canBeHit(player, target) then
						local inward = pos - tr.Position
						S.Adapter.applyKnockback(target, inward, c.Pull, c.Lift)
						S.hit(player, target, { Damage = c.TickDamage, Stun = 0.3, Knockback = 0, Direction = inward, Position = tr.Position, Source = "GyroSpinTornado" })
					end
				end
			end)
		end
		task.delay(c.Duration + 0.05, function()
			Moves.aoe(S, player, pos, c.Radius + 1.5, { Damage = c.BurstDamage, Stun = 0.4, Knockback = c.BurstKnockback, Launch = c.BurstLaunch, Source = "GyroSpinTornado" }, 6)
			S.fx("Tornado", { Act = 5, Id = id, Phase = "Burst", Position = pos, Radius = c.Radius + 1.5 })
		end)
	end)
end

local function spinVibration(S, player, state, aim)
	local c = cfg.SpinVibration
	if not ready(S, player, state, "SpinVibration", 3) then
		return
	end
	S.startCooldown(player, state, "SpinVibration", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.4)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 5, Move = "SpinVibration", Phase = "Startup", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local _, _, r = alive(S, player)
		local cf = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
		local count, hitSet = Moves.boxHit(S, player, cf, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Source = "GyroSpinVibration" }, 2)
		for target in pairs(hitSet) do
			spinSlow(S, target, 0.4, 1.5)
		end
		S.fx("Ability", { Character = character, Act = 5, Move = "SpinVibration", Phase = "Hit", Position = cf.Position, Hit = count > 0 })
	end)
end

function Gyro.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		steelBallThrow(S, player, state, aim)
	elseif slot == 2 then
		spinTornado(S, player, state, aim)
	elseif slot == 3 then
		spinVibration(S, player, state, aim)
	end
end

-- BALL BREAKER
function Gyro.Ultimate(S, player, state, aim)
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
	S.lock(state, u.Windup + 0.5)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = 5, Phase = "Start", Windup = u.Windup, Direction = direction })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local _, _, r = alive(S, player)
		S.fx("Ultimate", { Character = character, Act = 5, Phase = "Release", Position = r.Position, Direction = direction })
		S.fireBall(player, state, {
			Origin = S.origin(character, r, CFrame.new(0, 1.5, -3)),
			Direction = direction,
			Speed = u.Speed,
			Radius = u.Radius,
			Range = u.Range,
			Style = "Breaker",
			Scale = u.Radius * 2,
			OnHit = function(target, position)
				S.hit(player, target, { Damage = u.Damage, Stun = 0.5, Knockback = 10, Direction = direction, Position = position, Source = "GyroBallBreaker" })
			end,
			OnEnd = function(position)
				-- The spinning vortex: pulls enemies in, then bursts.
				S.fx("Ultimate", { Character = character, Act = 5, Phase = "Vortex", Position = position, Radius = u.VortexRadius, Duration = u.VortexTime })
				local ticks = math.floor(u.VortexTime / u.TickInterval)
				for i = 1, ticks do
					task.delay(i * u.TickInterval, function()
						for _, target in ipairs(S.Hitbox.inRadius(player.Character, position, u.VortexRadius, 8)) do
							local tr = target:FindFirstChild("HumanoidRootPart")
							if tr and S.Adapter.canBeHit(player, target) then
								local inward = position - tr.Position
								S.Adapter.applyKnockback(target, inward, u.PullStrength, 2)
								S.hit(player, target, { Damage = u.TickDamage, Stun = 0.25, Knockback = 0, Direction = inward, Position = tr.Position, Source = "GyroBallBreaker" })
							end
						end
					end)
				end
				task.delay(u.VortexTime + 0.05, function()
					Moves.aoe(S, player, position, u.VortexRadius + 2, { Damage = u.BurstDamage, Stun = u.Stun, Knockback = u.BurstKnockback, Launch = u.Launch, Source = "GyroBallBreaker" }, 8)
					S.fx("Ultimate", { Character = character, Act = 5, Phase = "Burst", Position = position, Radius = u.VortexRadius + 2 })
				end)
			end,
		})
		S.finishUltimate(player, state)
	end)
end

function Gyro.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
	end
end

return Gyro
