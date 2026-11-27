--[[
	Kira  (ServerScriptService.SpinServer.TuskActs.Kira)

	Yoshikage Kira (Part 4): KILLER QUEEN. Registered as "Act" 26.
	Anything Killer Queen touches becomes a bomb.
	  M1        KILLER QUEEN COMBO: Killer Queen strikes with him; the 4th is
	            a chop that launches
	  Ability 1 FIRST BOMB: Killer Queen touches the nearest enemy in front:
	            they're a bomb. Press 1 again (the "click") to set it off: a
	            big blast on them and a smaller one on anyone beside them.
	            Left too long (PrimeTime) it fizzles
	  Ability 2 SHEER HEART ATTACK: a little tank rolls out after the
	            nearest enemy ("LOOK HERE!"), turning to follow them, and
	            explodes when it reaches them (or when its time's up)
	  Ability 3 STRAY CAT AIR BOMBS: three air bubbles drift out in a fan;
	            each bursts on whoever it touches
	  Ultimate  BITES THE DUST: everyone near him is marked; a moment later
	            every one of them blows up, and then time rewinds for Kira:
	            his health and where he stood go back to when he called it
Numbers: TuskConfig.Kira. All damage goes through S.hit (CombatAdapter).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Kira = {}
local cfg = TuskConfig.Kira
local ACT = 26

local primed = setmetatable({}, { __mode = "k" }) -- [state] = { Target, Until }

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

function Kira.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: FIRST BOMB (touch, then click)
---------------------------------------------------------------------------
local function unprime(state)
	local p = primed[state]
	primed[state] = nil
	if p and p.Target.Parent and p.Target:GetAttribute("KiraBombUntil") == p.Until then
		p.Target:SetAttribute("KiraBombUntil", nil)
	end
	return p
end

local function firstBomb(S, player, state, aim)
	local c = cfg.FirstBomb
	local p = primed[state]
	-- Already touched someone: click.
	if p and p.Until > now() and aliveModel(p.Target) then
		if S.isBusy(state) then
			return
		end
		unprime(state)
		S.startCooldown(player, state, "FirstBomb", c.Cooldown, 1)
		S.lock(state, 0.25)
		local character, _, root = alive(S, player)
		local target = p.Target
		local tr = target:FindFirstChild("HumanoidRootPart")
		S.fx("Ability", { Character = character, Act = ACT, Move = "FirstBomb", Phase = "Click" })
		local at = tr and tr.Position or root.Position
		local away = at - root.Position
		away = Vector3.new(away.X, 0, away.Z)
		away = away.Magnitude > 0.1 and away.Unit or root.CFrame.LookVector
		S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = away, Position = at, Source = "KiraBomb", Unblockable = true })
		Moves.aoe(S, player, at, c.SplashRadius, { Damage = c.SplashDamage, Stun = 0.4, Knockback = 25, Source = "KiraBomb" }, 6, { [target] = true })
		S.fx("Ability", { Act = ACT, Move = "FirstBomb", Phase = "Boom", Position = at, Radius = c.SplashRadius })
		return
	end
	if p then
		unprime(state)
	end
	if not ready(S, player, state, "FirstBomb", 1) then
		return
	end
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "FirstBomb", Phase = "Reach", Windup = c.Windup })
	S.startCooldown(player, state, "FirstBomb", c.Windup + 0.3, 1)
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = Moves.flat(S.aim(aim, r))
		local target = Moves.findTarget(S, char, r, c.Range, c.Cone, dir)
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		if not tr or not S.hit(player, target, { Damage = c.TouchDamage, Stun = c.TouchStun, Knockback = 0, Direction = dir, Position = tr.Position, Source = "KiraTouch" }) then
			S.startCooldown(player, state, "FirstBomb", c.MissCooldown, 1)
			S.fx("Ability", { Character = char, Act = ACT, Move = "FirstBomb", Phase = "Miss", Position = (r.CFrame * CFrame.new(0, 0, -3)).Position })
			return
		end
		local untilT = now() + c.PrimeTime
		primed[state] = { Target = target, Until = untilT }
		target:SetAttribute("KiraBombUntil", untilT)
		S.startCooldown(player, state, "FirstBomb", 0.35, 1)
		S.fx("Ability", { Character = char, Act = ACT, Move = "FirstBomb", Phase = "Touch", Target = target, Position = tr.Position, Time = c.PrimeTime })
		-- Not set off in time: it fizzles.
		task.delay(c.PrimeTime, function()
			local still = primed[state]
			if still and still.Until == untilT then
				unprime(state)
				S.startCooldown(player, state, "FirstBomb", c.FizzleCooldown, 1)
				S.fx("Ability", { Act = ACT, Move = "FirstBomb", Phase = "Fizzle", Target = target })
			end
		end)
	end)
end

---------------------------------------------------------------------------
-- 2: SHEER HEART ATTACK (a homing tank)
---------------------------------------------------------------------------
local function nearestEnemy(S, char, pos, range)
	local best, bestD
	for _, target in ipairs(S.Hitbox.inRadius(char, pos, range, 20)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and aliveModel(target) then
			local d = (tr.Position - pos).Magnitude
			if not bestD or d < bestD then
				best, bestD = target, d
			end
		end
	end
	return best
end

local function sheerHeartAttack(S, player, state, aim)
	local c = cfg.SheerHeartAttack
	if not ready(S, player, state, "SheerHeartAttack", 2) then
		return
	end
	S.startCooldown(player, state, "SheerHeartAttack", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "SheerHeartAttack", Phase = "Summon", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = Moves.flat(S.aim(aim, r))
		local pos = Moves.groundBelow(r.Position + dir * 3, { char })
		local id = tostring({})
		local target = nearestEnemy(S, char, pos, c.SeekRange)
		S.fx("Ability", { Character = char, Act = ACT, Move = "SheerHeartAttack", Phase = "Spawn", Id = id, Position = pos, Direction = dir })
		local t, step, sendEvery, sinceSend, repick = 0, 1 / 20, 0.15, 0, 0
		local function explode(at)
			Moves.aoe(S, player, at + Vector3.new(0, 1.5, 0), c.ExplodeRadius, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Source = "KiraSHA", Unblockable = true }, 8)
			S.fx("Ability", { Act = ACT, Move = "SheerHeartAttack", Phase = "Explode", Id = id, Position = at, Radius = c.ExplodeRadius })
		end
		local function tick()
			t = t + step
			repick = repick + step
			-- It goes after whoever's nearest (re-checked as it rolls).
			if repick >= 0.5 or not aliveModel(target) then
				repick = 0
				target = nearestEnemy(S, char, pos, c.SeekRange)
			end
			local tr = target and target:FindFirstChild("HumanoidRootPart")
			if tr then
				local to = tr.Position - pos
				to = Vector3.new(to.X, 0, to.Z)
				if to.Magnitude > 0.1 then
					dir = dir:Lerp(to.Unit, math.min(1, 6 * step))
					dir = Vector3.new(dir.X, 0, dir.Z).Unit
				end
				if (tr.Position - (pos + Vector3.new(0, 1.5, 0))).Magnitude <= c.HitRadius + 1.5 then
					explode(pos)
					return
				end
			end
			pos = Moves.groundBelow(pos + dir * c.Speed * step, { char })
			sinceSend = sinceSend + step
			if sinceSend >= sendEvery then
				sinceSend = 0
				S.fx("Ability", { Act = ACT, Move = "SheerHeartAttack", Phase = "Move", Id = id, Position = pos, Direction = dir })
			end
			if t >= c.Life then
				explode(pos)
				return
			end
			task.delay(step, tick)
		end
		task.delay(step, tick)
	end)
end

---------------------------------------------------------------------------
-- 3: STRAY CAT AIR BOMBS
---------------------------------------------------------------------------
local function strayCat(S, player, state, aim)
	local c = cfg.StrayCat
	if not ready(S, player, state, "StrayCat", 3) then
		return
	end
	S.startCooldown(player, state, "StrayCat", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "StrayCat", Phase = "Blow", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local look = Moves.flat(S.aim(aim, r))
		local from = r.Position + look * 2 + Vector3.new(0, 0.5, 0)
		local bubbles = {}
		for k = 1, c.Count do
			local yaw = math.rad((k - (c.Count + 1) / 2) * c.Spread)
			local d = (CFrame.Angles(0, yaw, 0) * look)
			table.insert(bubbles, { Id = tostring({}), Pos = from, Dir = d, Alive = true })
		end
		local dirs, ids = {}, {}
		for _, b in ipairs(bubbles) do
			table.insert(dirs, b.Dir)
			table.insert(ids, b.Id)
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "StrayCat", Phase = "Fire", From = from, Directions = dirs, Ids = ids, Speed = c.Speed, Life = c.Life })
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local t, step = 0, 1 / 20
		local function pop(b, hitSomeone)
			b.Alive = false
			if hitSomeone then
				Moves.aoe(S, player, b.Pos, c.ExplodeRadius, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Source = "KiraStrayCat" }, 6)
			end
			S.fx("Ability", { Act = ACT, Move = "StrayCat", Phase = "Pop", Id = b.Id, Position = b.Pos, Hit = hitSomeone })
		end
		local function tick()
			t = t + step
			local any = false
			for _, b in ipairs(bubbles) do
				if b.Alive then
					local move = b.Dir * c.Speed * step
					local wall = workspace:Raycast(b.Pos, move, params)
					if wall and not (wall.Instance.Parent and wall.Instance.Parent:FindFirstChildOfClass("Humanoid")) then
						b.Pos = wall.Position
						pop(b, false)
					else
						b.Pos = b.Pos + move
						if #S.Hitbox.inRadius(char, b.Pos, c.HitRadius, 1) > 0 then
							pop(b, true)
						elseif t >= c.Life then
							pop(b, false)
						else
							any = true
						end
					end
				end
			end
			if any then
				task.delay(step, tick)
			end
		end
		task.delay(step, tick)
	end)
end

function Kira.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		firstBomb(S, player, state, aim)
	elseif slot == 2 then
		sheerHeartAttack(S, player, state, aim)
	elseif slot == 3 then
		strayCat(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- BITES THE DUST (ultimate)
---------------------------------------------------------------------------
function Kira.Ultimate(S, player, state, aim)
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
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Call", Windup = u.Windup })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local char, hum, r = alive(S, player)
		-- Where (and how well) he is now: time comes back to this.
		local savedHealth, savedCFrame = hum.Health, r.CFrame
		local marked = {}
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, u.Range, 30)) do
			if aliveModel(target) then
				table.insert(marked, target)
				target:SetAttribute("BitesTheDust", true)
			end
		end
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Set", Position = r.Position, Marked = marked, Delay = u.Delay })
		task.delay(u.Delay, function()
			local booms = {}
			for _, target in ipairs(marked) do
				if target.Parent then
					target:SetAttribute("BitesTheDust", nil)
				end
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr and aliveModel(target) then
					S.hit(player, target, { Damage = u.Damage, Stun = u.Stun, Knockback = u.Knockback, Launch = u.Launch, Direction = Vector3.new(0, 1, 0), Position = tr.Position, Source = "KiraBTD", Unblockable = true })
					table.insert(booms, tr.Position)
				end
			end
			S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Boom", Positions = booms })
			-- ...and time rewinds (for him).
			local nowChar, nowHum, nowRoot = alive(S, player)
			if state.Life == life and nowChar == char and nowHum and nowHum.Health > 0 then
				if u.RewindHealth then
					nowHum.Health = math.max(nowHum.Health, savedHealth)
				end
				if u.RewindPosition and nowRoot then
					char:PivotTo(savedCFrame)
				end
				S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Rewind", Position = savedCFrame.Position })
			end
		end)
	end)
end

function Kira.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
	end
	unprime(state)
end

return Kira
