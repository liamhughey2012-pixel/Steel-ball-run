--[[
	GyroEyes  (ServerScriptService.SpinServer.TuskActs.GyroEyes)

	GYRO WITH THE SAINT'S EYES. Registered as "Act" 29 (Character "Gyro").
	Gyro holding the Saint's Corpse EYES puts them to use: one in his own
	eye socket, one set into his steel ball. While he holds them his moves
	change; when he loses them (or goes down) he's back to Act 5.
	  M1        STEEL BALL COMBO (the same as ever)
	  Ability 1 SCAN SHOT: he tosses the eye-ball up, throws a second ball
	            into it at the top, and knocks it DOWN onto the nearest enemy in
	            front (it comes from above, so it goes over cover), steering
	            after them; whoever it hits is left revealed to him for a while
	  Ability 2 SCAN: the eyes see through everything: every enemy near is
	            revealed to him (through walls) and takes more damage from him
	            for a while
	  Ability 3 EYE RICOCHET: the eye-ball picks its path: it hops from one
	            enemy to the next nearest (up to 5), bouncing off the ground
	            between, each hit harder than the last; the last one is sent
	            flying and the ball comes back to his hand
	  Ultimate  SCAN: GOLDEN SPIN: the eyes find the nearest enemy anywhere;
	            a golden-spinning ball goes straight through everything to
	            them and leaves them paralysed by the Spin
	The switch (5 <-> 29) is watched here (Init): CorpseParts holding "Eyes".
	Numbers: TuskConfig.GyroEyes. All damage goes through S.hit (CombatAdapter).
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local Moves = require(script.Parent.Parent.TuskMoves)

local GyroEyes = {}
local cfg = TuskConfig.GyroEyes
local ACT = 29
local GYRO = 5

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

local function aliveModel(model)
	local h = model and model.Parent and model:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end

-- Scanned: revealed to him, and his hits on them land harder (CombatAdapter).
local function scan(char, target, time)
	local untilT = now() + time
	if (target:GetAttribute("ScannedUntil") or 0) < untilT then
		target:SetAttribute("ScannedUntil", untilT)
	end
	if (char:GetAttribute("ScanBonusUntil") or 0) < untilT then
		char:SetAttribute("ScanBonusUntil", untilT)
		char:SetAttribute("ScanBonus", cfg.Scan.BonusDamage)
	end
end

function GyroEyes.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: SCAN SHOT (toss one ball up, knock it down onto them with another)
---------------------------------------------------------------------------
local function scanShot(S, player, state, aim)
	local c = cfg.ScanShot
	if not ready(S, player, state, "ScanShot", 1) then
		return
	end
	S.startCooldown(player, state, "ScanShot", c.Cooldown, 1)
	S.lock(state, c.TossTime + c.StrikeTime + 0.15)
	local character, _, root = alive(S, player)
	local life = state.Life
	local look = Moves.flat(S.aim(aim, root))
	-- The eye-ball goes up above him.
	local hand = S.origin(character, root, Moves.HAND)
	local apex = root.Position + look * c.TossForward + Vector3.new(0, c.TossHeight, 0)
	local id = tostring({})
	S.fx("Ability", { Character = character, Act = ACT, Move = "ScanShot", Phase = "Toss", Id = id, From = hand, Apex = apex, Time = c.TossTime })
	-- At the top, the second ball meets it.
	task.delay(c.TossTime, function()
		if not S.stillValid(player, state, life) then
			S.fx("Ability", { Act = ACT, Move = "ScanShot", Phase = "End", Id = id, Position = apex, Hit = false })
			return
		end
		local char, _, r = alive(S, player)
		local from = S.origin(char, r, Moves.HAND)
		S.fx("Ability", { Character = char, Act = ACT, Move = "ScanShot", Phase = "Strike", Id = id, From = from, Apex = apex, Time = c.StrikeTime })
		task.delay(c.StrikeTime, function()
			if not S.stillValid(player, state, life) then
				S.fx("Ability", { Act = ACT, Move = "ScanShot", Phase = "End", Id = id, Position = apex, Hit = false })
				return
			end
			-- The eye picks its target, and the first ball dives down at them.
			local target = Moves.findTarget(S, char, r, c.LockRange, c.Cone, look)
			local tr = target and target:FindFirstChild("HumanoidRootPart")
			local aimAt = tr and tr.Position or Moves.groundBelow(r.Position + look * 40, { char })
			local pos = apex
			local vel = (aimAt - pos).Unit * c.Speed
			S.fx("Ability", { Character = char, Act = ACT, Move = "ScanShot", Phase = "Dive", Id = id, From = pos, Direction = vel.Unit, Target = target, Speed = c.Speed, Turn = c.Turn, Life = c.Life, Aim = aimAt })
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { char }
			local t, step = 0, 1 / 30
			local function landed(at, victim)
				local hitIt = false
				if victim then
					local vr = victim:FindFirstChild("HumanoidRootPart")
					hitIt = S.hit(player, victim, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = Moves.flat(vel), Position = vr and vr.Position or at, Source = "GyroEyesShot" })
					if hitIt then
						scan(char, victim, c.RevealTime)
					end
				end
				-- The ground where it lands takes a hit too.
				Moves.aoe(S, player, at, c.SplashRadius, { Damage = c.SplashDamage, Stun = 0.3, Knockback = 12, Source = "GyroEyesShot" }, 6, victim and { [victim] = true } or nil)
				S.fx("Ability", { Character = char, Act = ACT, Move = "ScanShot", Phase = "End", Id = id, Position = at, Hit = hitIt, Target = hitIt and victim or nil, Reveal = c.RevealTime, Radius = c.SplashRadius })
			end
			local function tick()
				t = t + step
				local ttr = target and aliveModel(target) and target:FindFirstChild("HumanoidRootPart")
				if ttr then
					local want = (ttr.Position - pos).Unit * c.Speed
					vel = (vel + (want - vel) * math.min(1, c.Turn * step)).Unit * c.Speed
				end
				local move = vel * step
				local wall = workspace:Raycast(pos, move, params)
				if wall and not (wall.Instance.Parent and wall.Instance.Parent:FindFirstChildOfClass("Humanoid")) then
					landed(wall.Position, nil)
					return
				end
				pos = pos + move
				local victim
				if ttr and (ttr.Position - pos).Magnitude <= c.HitRadius then
					victim = target
				else
					for _, other in ipairs(S.Hitbox.inRadius(char, pos, c.HitRadius, 1)) do
						victim = other
					end
				end
				if victim then
					landed(pos, victim)
					return
				end
				if t >= c.Life then
					landed(pos, nil)
					return
				end
				task.delay(step, tick)
			end
			task.delay(step, tick)
		end)
	end)
end

---------------------------------------------------------------------------
-- 2: SCAN
---------------------------------------------------------------------------
local function scanAll(S, player, state)
	local c = cfg.Scan
	if not ready(S, player, state, "Scan", 2) then
		return
	end
	S.startCooldown(player, state, "Scan", c.Cooldown, 2)
	S.lock(state, 0.3)
	local char, _, r = alive(S, player)
	local found = {}
	for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, c.Range, 30)) do
		if aliveModel(target) then
			scan(char, target, c.Time)
			table.insert(found, target)
		end
	end
	char:SetAttribute("ScanBonusUntil", now() + c.Time)
	char:SetAttribute("ScanBonus", c.BonusDamage)
	S.fx("Ability", { Character = char, Act = ACT, Move = "Scan", Phase = "Pulse", Position = r.Position, Range = c.Range, Time = c.Time, Targets = found })
end

---------------------------------------------------------------------------
-- 3: EYE RICOCHET
---------------------------------------------------------------------------
local function ricochet(S, player, state, aim)
	local c = cfg.Ricochet
	if not ready(S, player, state, "Ricochet", 3) then
		return
	end
	S.startCooldown(player, state, "Ricochet", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "Ricochet", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = Moves.flat(S.aim(aim, r))
		local from = S.origin(char, r, Moves.HAND)
		-- Its path: the first in front, then the nearest one not yet hit.
		local path, hitSet = {}, {}
		local current = Moves.findTarget(S, char, r, c.FirstRange, c.Cone, dir)
		local at = from
		while current and #path < c.Bounces do
			local tr = current:FindFirstChild("HumanoidRootPart")
			if not tr then
				break
			end
			table.insert(path, { Target = current, Position = tr.Position })
			hitSet[current] = true
			at = tr.Position
			local best, bestD
			for _, other in ipairs(S.Hitbox.inRadius(char, at, c.Range, 20)) do
				local orr = other:FindFirstChild("HumanoidRootPart")
				if orr and not hitSet[other] and aliveModel(other) then
					local d = (orr.Position - at).Magnitude
					if not bestD or d < bestD then
						best, bestD = other, d
					end
				end
			end
			current = best
		end
		local points = { from }
		for _, p in ipairs(path) do
			table.insert(points, p.Position)
		end
		if #path == 0 then
			table.insert(points, from + dir * c.FirstRange)
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "Ricochet", Phase = "Bounce", Points = points, Gap = c.Gap, Hits = #path, Return = c.ReturnTime })
		for i, p in ipairs(path) do
			task.delay(i * c.Gap, function()
				if p.Target.Parent then
					local d = (p.Position - points[i])
					local last = i == #path
					-- Harder with every hop; the last one is sent flying.
					S.hit(player, p.Target, { Damage = c.Damage + (i - 1) * c.BounceBonus, Stun = c.Stun, Knockback = last and c.FinalKnockback or c.Knockback, Launch = last and c.FinalLaunch or nil, Direction = d.Magnitude > 0.1 and Moves.flat(d) or dir, Position = p.Position, Source = "GyroEyesRicochet" })
				end
			end)
		end
	end)
end

function GyroEyes.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		scanShot(S, player, state, aim)
	elseif slot == 2 then
		scanAll(S, player, state)
	elseif slot == 3 then
		ricochet(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- SCAN: GOLDEN SPIN (ultimate)
---------------------------------------------------------------------------
function GyroEyes.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	local char, _, r = alive(S, player)
	-- The eyes find the nearest enemy anywhere in range (walls don't matter).
	local best, bestD
	for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, u.Range, 40)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and aliveModel(target) then
			local d = (tr.Position - r.Position).Magnitude
			if not bestD or d < bestD then
				best, bestD = target, d
			end
		end
	end
	if not best then
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local life = state.Life
	S.lock(state, u.Windup + 0.3)
	char:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Lock", Target = best, Windup = u.Windup })
	task.delay(u.Windup, function()
		if char.Parent then
			char:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local _, _, root = alive(S, player)
		local tr = best:FindFirstChild("HumanoidRootPart")
		if not tr or not aliveModel(best) then
			S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Lost" })
			return
		end
		local from = root.Position + Vector3.new(0, 1.5, 0)
		local to = tr.Position
		local d = to - from
		local dir = d.Magnitude > 0.1 and d.Unit or root.CFrame.LookVector
		-- Straight through everything: anyone else on the line is hit on the way.
		local mid = (from + to) / 2
		for _, other in ipairs(S.Hitbox.inBox(char, CFrame.lookAt(mid, to), Vector3.new(u.Width, u.Width + 2, d.Magnitude), 10)) do
			if other ~= best then
				local orr = other:FindFirstChild("HumanoidRootPart")
				S.hit(player, other, { Damage = u.PassDamage, Stun = 0.6, Knockback = 20, Direction = dir, Position = orr and orr.Position or mid, Source = "GyroEyesUlt" })
			end
		end
		S.hit(player, best, { Damage = u.Damage, Stun = u.Stun, Knockback = u.Knockback, Direction = dir, Position = to, Source = "GyroEyesUlt", Unblockable = true })
		scan(char, best, 4)
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Spin", From = from, To = to, Target = best, Stun = u.Stun })
	end)
end

function GyroEyes.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
	end
end

---------------------------------------------------------------------------
-- The switch: Gyro holding the Eyes is Act 29; without them, Act 5.
---------------------------------------------------------------------------
local function holdsEyes(character)
	for id in string.gmatch(character:GetAttribute("CorpseParts") or "", "[^,]+") do
		if id == "Eyes" then
			return true
		end
	end
	return false
end

function GyroEyes.Init(S)
	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		timer = timer + dt
		if timer < 0.5 then
			return
		end
		timer = 0
		for who, state in pairs(S.States or {}) do
			local character = state.Character
			local act = state.Act
			if character and character.Parent and (act == GYRO or act == ACT) and not S.isBusy(state) and not state.Charging then
				local want = holdsEyes(character) and ACT or GYRO
				if want ~= act and Registry.isImplemented(want) then
					pcall(S.select, who, want, true)
				end
			end
		end
	end)
end

return GyroEyes
