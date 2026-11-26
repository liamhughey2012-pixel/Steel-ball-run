--[[
	Josuke4  (ServerScriptService.SpinServer.TuskActs.Josuke4)

	Josuke Higashikata (Part 4, Diamond is Unbreakable): CRAZY DIAMOND.
	Not the JoJolion Josuke (Act 15). Registered as "Act" 25.
	  M1        DORA COMBO: Crazy Diamond punches with him; the 4th is a
	            heavy straight that launches
	  Ability 1 DORARARA RUSH: a storm of punches in front of him that drags
	            them along (he can still walk); the last big "DORA!" sends
	            them flying with a shockwave
	  Ability 2 BREAK & RESTORE: Crazy Diamond punches the nearest enemy in
	            front, then "fixes" them into a lump of rock: stuck, unable to
	            move or act, until the rock breaks off and knocks them away
	            (a miss only costs a short cooldown)
	  Ability 3 HOMING SHARD: he flicks a bloodied glass shard; Crazy
	            Diamond restores it, so it flies back to where the blood came
	            from, steering after the nearest enemy in front
	  Ultimate  "WHAT DID YOU SAY ABOUT MY HAIR?!": he snaps. The outburst
	            blows everyone near him back; for a while he hits harder,
	            moves faster, and the rush and fusion are ready at once
Numbers: TuskConfig.Josuke4. All damage goes through S.hit (CombatAdapter).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Josuke4 = {}
local cfg = TuskConfig.Josuke4
local ACT = 25

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

function Josuke4.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: DORARARA RUSH
---------------------------------------------------------------------------
local function doraRush(S, player, state, aim)
	local c = cfg.DoraRush
	if not ready(S, player, state, "DoraRush", 1) then
		return
	end
	S.startCooldown(player, state, "DoraRush", c.Cooldown, 1)
	S.lock(state, c.Windup + c.Duration + 0.15)
	local character, humanoid = alive(S, player)
	local life = state.Life
	local untilT = now() + c.Windup + c.Duration
	character:SetAttribute("DoraRushUntil", untilT)
	S.Adapter.setMoveModifier(humanoid, "DoraRush", c.WalkMultiplier)
	S.fx("Ability", { Character = character, Act = ACT, Move = "DoraRush", Phase = "Start", Windup = c.Windup, Duration = c.Duration })
	local ticks = math.max(1, math.floor(c.Duration / c.Tick))
	local function stop()
		if humanoid.Parent then
			S.Adapter.setMoveModifier(humanoid, "DoraRush", nil)
		end
		if character.Parent and character:GetAttribute("DoraRushUntil") == untilT then
			character:SetAttribute("DoraRushUntil", nil)
		end
	end
	for i = 1, ticks do
		task.delay(c.Windup + (i - 1) * c.Tick, function()
			if character:GetAttribute("DoraRushUntil") ~= untilT then
				return
			end
			if not S.stillValid(player, state, life) then
				stop()
				S.fx("Ability", { Character = character, Act = ACT, Move = "DoraRush", Phase = "Stop" })
				return
			end
			local _, _, r = alive(S, player)
			local boxCF = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
			if i == ticks then
				Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.FinalDamage, Stun = c.FinalStun, Knockback = c.FinalKnockback, Launch = c.FinalLaunch, Direction = r.CFrame.LookVector, Source = "Josuke4Dora" }, c.MaxTargets)
				local waveAt = (r.CFrame * CFrame.new(0, 0, -c.HitboxForward - 3)).Position
				Moves.aoe(S, player, waveAt, c.ShockwaveRadius, { Damage = c.ShockwaveDamage, Stun = 0.4, Knockback = 30, Direction = r.CFrame.LookVector, Source = "Josuke4Dora" }, 6)
				S.fx("Ability", { Character = character, Act = ACT, Move = "DoraRush", Phase = "Finish", Position = boxCF.Position, Direction = r.CFrame.LookVector, Radius = c.ShockwaveRadius })
				stop()
			else
				local count, hitSet = Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = r.CFrame.LookVector, Source = "Josuke4Dora" }, c.MaxTargets)
				-- Drag whoever's caught back in front of Crazy Diamond.
				for target in pairs(hitSet or {}) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr and not tr.Anchored then
						local to = boxCF.Position - tr.Position
						tr.AssemblyLinearVelocity = Vector3.new(to.X * c.Drag, tr.AssemblyLinearVelocity.Y, to.Z * c.Drag) + r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
					end
				end
				if count > 0 and i % 2 == 0 then
					S.fx("Ability", { Act = ACT, Move = "DoraRush", Phase = "Hit", Position = boxCF.Position })
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- 2: BREAK & RESTORE (rock fusion)
---------------------------------------------------------------------------
-- Encased in rock: anchored (counted, so two at once don't free them early)
-- and stunned for the whole time.
local encased = setmetatable({}, { __mode = "k" }) -- [root] = { Count, WasAnchored }

local function encase(root)
	local e = encased[root]
	if not e then
		e = { Count = 0, WasAnchored = root.Anchored }
		encased[root] = e
	end
	e.Count = e.Count + 1
	root.Anchored = true
end

local function release(root)
	local e = encased[root]
	if not e then
		return
	end
	e.Count = e.Count - 1
	if e.Count <= 0 then
		encased[root] = nil
		-- (Left anchored if a time stop still holds them.)
		local model = root.Parent
		if model and not model:GetAttribute("TimeStopped") then
			root.Anchored = e.WasAnchored
		end
	end
end

local function rockFusion(S, player, state, aim)
	local c = cfg.RockFusion
	if not ready(S, player, state, "RockFusion", 2) then
		return
	end
	S.lock(state, c.Windup + 0.3)
	local character, _, root = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "RockFusion", Phase = "Wind", Windup = c.Windup })
	S.startCooldown(player, state, "RockFusion", c.Cooldown, 2)
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = Moves.flat(S.aim(aim, r))
		local target = Moves.findTarget(S, char, r, c.Range, c.Cone, dir)
		if not target then
			-- Missed: only a short wait.
			S.startCooldown(player, state, "RockFusion", c.MissCooldown, 2)
			S.fx("Ability", { Character = char, Act = ACT, Move = "RockFusion", Phase = "Miss", Position = (r.CFrame * CFrame.new(0, 0, -4)).Position })
			return
		end
		local tr = target:FindFirstChild("HumanoidRootPart")
		local landed = S.hit(player, target, { Damage = c.Damage, Stun = c.EncaseTime, Knockback = 0, Direction = dir, Position = tr.Position, Source = "Josuke4Fusion" })
		if not landed then
			S.startCooldown(player, state, "RockFusion", c.MissCooldown, 2)
			S.fx("Ability", { Character = char, Act = ACT, Move = "RockFusion", Phase = "Miss", Position = tr.Position })
			return
		end
		local untilT = now() + c.EncaseTime
		target:SetAttribute("RockEncasedUntil", untilT)
		encase(tr)
		S.fx("Ability", { Character = char, Act = ACT, Move = "RockFusion", Phase = "Encase", Target = target, Position = tr.Position, Time = c.EncaseTime })
		task.delay(c.EncaseTime, function()
			release(tr)
			if target.Parent and target:GetAttribute("RockEncasedUntil") == untilT then
				target:SetAttribute("RockEncasedUntil", nil)
			end
			if not target.Parent then
				return
			end
			-- The rock breaks off and knocks them away.
			local away = tr.Position - (r.Parent and r.Position or tr.Position - dir)
			away = Vector3.new(away.X, 0, away.Z)
			away = away.Magnitude > 0.1 and away.Unit or dir
			S.hit(player, target, { Damage = c.BurstDamage, Stun = 0.5, Knockback = c.BurstKnockback, Launch = c.BurstLaunch, Direction = away, Position = tr.Position, Source = "Josuke4Fusion", Unblockable = true })
			S.fx("Ability", { Act = ACT, Move = "RockFusion", Phase = "Burst", Target = target, Position = tr.Position })
		end)
	end)
end

---------------------------------------------------------------------------
-- 3: HOMING SHARD
---------------------------------------------------------------------------
local function homingShard(S, player, state, aim)
	local c = cfg.HomingShard
	if not ready(S, player, state, "HomingShard", 3) then
		return
	end
	S.startCooldown(player, state, "HomingShard", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "HomingShard", Phase = "Flick", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = S.aim(aim, r)
		local target = Moves.findTarget(S, char, r, c.LockRange, c.Cone, dir)
		local pos = S.origin(char, r, Moves.HAND)
		local vel = dir * c.Speed
		local id = tostring({})
		S.fx("Ability", { Character = char, Act = ACT, Move = "HomingShard", Phase = "Fly", Id = id, From = pos, Direction = dir, Target = target, Speed = c.Speed, Turn = c.Turn, Life = c.Life })
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local t, step = 0, 1 / 30
		local function tick()
			t = t + step
			-- Steer after the target (restored back to the blood).
			local tr = target and target.Parent and target:FindFirstChild("HumanoidRootPart")
			local hum = target and target:FindFirstChildOfClass("Humanoid")
			if tr and hum and hum.Health > 0 then
				local want = (tr.Position - pos).Unit * c.Speed
				vel = (vel + (want - vel) * math.min(1, c.Turn * step)).Unit * c.Speed
			end
			local move = vel * step
			local wall = workspace:Raycast(pos, move, params)
			if wall and not (wall.Instance.Parent and wall.Instance.Parent:FindFirstChildOfClass("Humanoid")) then
				S.fx("Ability", { Act = ACT, Move = "HomingShard", Phase = "End", Id = id, Position = wall.Position, Hit = false })
				return
			end
			pos = pos + move
			-- Anyone it passes close to (the target first).
			local victim
			if tr and (tr.Position - pos).Magnitude <= c.HitRadius then
				victim = target
			else
				for _, other in ipairs(S.Hitbox.inRadius(char, pos, c.HitRadius, 1)) do
					victim = other
				end
			end
			if victim then
				local vr = victim:FindFirstChild("HumanoidRootPart")
				local landed = S.hit(player, victim, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = vel.Unit, Position = vr and vr.Position or pos, Source = "Josuke4Shard" })
				S.fx("Ability", { Act = ACT, Move = "HomingShard", Phase = "End", Id = id, Position = pos, Hit = landed })
				return
			end
			if t >= c.Life then
				S.fx("Ability", { Act = ACT, Move = "HomingShard", Phase = "End", Id = id, Position = pos, Hit = false })
				return
			end
			task.delay(step, tick)
		end
		task.delay(step, tick)
	end)
end

function Josuke4.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		doraRush(S, player, state, aim)
	elseif slot == 2 then
		rockFusion(S, player, state, aim)
	elseif slot == 3 then
		homingShard(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- "WHAT DID YOU SAY ABOUT MY HAIR?!" (ultimate)
---------------------------------------------------------------------------
local function calmDown(S, character, untilT)
	if not character.Parent or character:GetAttribute("HairRageUntil") ~= untilT then
		return
	end
	character:SetAttribute("HairRageUntil", nil)
	character:SetAttribute("HairRageDamage", nil)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		S.Adapter.setMoveModifier(humanoid, "HairRage", nil)
	end
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Calm" })
end

function Josuke4.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.2)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Snap", Windup = u.Windup })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local char, hum, r = alive(S, player)
		local duration = (typeof(player) == "table" and player.IsBot) and u.BotDuration or u.Duration
		local untilT = now() + duration
		char:SetAttribute("HairRageUntil", untilT)
		char:SetAttribute("HairRageDamage", u.DamageMultiplier)
		S.Adapter.setMoveModifier(hum, "HairRage", u.SpeedMultiplier)
		local slots = { DoraRush = 1, RockFusion = 2, HomingShard = 3 }
		for _, name in ipairs(u.ResetCooldowns or {}) do
			S.startCooldown(player, state, name, 0, slots[name])
		end
		-- The outburst blows everyone near him back.
		Moves.aoe(S, player, r.Position, u.ShoutRadius, { Damage = u.ShoutDamage, Stun = 0.6, Knockback = u.ShoutKnockback, Launch = 8, Source = "Josuke4Rage" }, 10)
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Rage", Position = r.Position, Radius = u.ShoutRadius, Duration = duration })
		task.delay(duration, function()
			calmDown(S, char, untilT)
		end)
	end)
end

function Josuke4.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("DoraRushUntil", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "DoraRush", nil)
		end
		local untilT = character:GetAttribute("HairRageUntil")
		if untilT then
			calmDown(S, character, untilT)
		end
	end
end

return Josuke4
