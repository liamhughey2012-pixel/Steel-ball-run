--[[
	Jotaro  (ServerScriptService.SpinServer.TuskActs.Jotaro)

	Jotaro Kujo: STAR PLATINUM (a visitor from another world: Part 3).
	Registered as "Act" 20 so it reuses the Tusk ability system.
	  M1        ORA COMBO: Star Platinum punches with him; the 4th is a
	            straight that launches
	  Ability 1 ORA RUSH: "ORA ORA ORA": a storm of punches in front of him
	            that drags them along (he can still walk); the last big
	            "ORA!" sends them flying with a shockwave
	  Ability 2 STAR FINGER: Star Platinum's two fingers shoot out in a
	            long, fast line, piercing everyone in it
	  Ability 3 BEARING SHOT: a ball bearing flicked like a bullet (instant,
	            long range)
	  Ultimate  STAR PLATINUM: THE WORLD: time stops in a zone round him
	            (5 s). Everyone inside, and anyone who walks in, freezes;
	            projectiles hang in the air; he's a little faster, and ORA
	            RUSH and STAR FINGER are ready the moment it starts
	Numbers: TuskConfig.Jotaro. All damage goes through S.hit (CombatAdapter).
	Frozen characters carry the "TimeStopped" attribute (CombatAdapter.canAct
	refuses them) and have their root anchored by the server (shared idea
	with Diego (AU)'s THE WORLD).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Jotaro = {}
local cfg = TuskConfig.Jotaro
local ACT = 20

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

function Jotaro.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- Pinning (anchoring) a character in place. Counted, so a grab during a
-- time stop doesn't let them go when the grab ends.
---------------------------------------------------------------------------
local pins = setmetatable({}, { __mode = "k" }) -- [root] = { Count, WasAnchored }

local function pin(root)
	local p = pins[root]
	if not p then
		p = { Count = 0, WasAnchored = root.Anchored }
		pins[root] = p
	end
	p.Count = p.Count + 1
	root.Anchored = true
end

local function unpin(root)
	local p = pins[root]
	if not p then
		return
	end
	p.Count = p.Count - 1
	if p.Count <= 0 then
		pins[root] = nil
		if root.Parent then
			root.Anchored = p.WasAnchored
		end
	end
end

-- Frozen in stopped time (counted: two time stops can overlap).
local frozenCount = setmetatable({}, { __mode = "k" }) -- [character] = count

local function freeze(target)
	local tr = target:FindFirstChild("HumanoidRootPart")
	if not tr then
		return false
	end
	frozenCount[target] = (frozenCount[target] or 0) + 1
	target:SetAttribute("TimeStopped", true)
	pin(tr)
	return true
end

local function thaw(target)
	local count = frozenCount[target]
	if not count then
		return
	end
	count = count - 1
	frozenCount[target] = count > 0 and count or nil
	if count <= 0 and target.Parent then
		target:SetAttribute("TimeStopped", nil)
	end
	local tr = target:FindFirstChild("HumanoidRootPart")
	if tr then
		unpin(tr)
	end
end

local stops = setmetatable({}, { __mode = "k" }) -- [character] = the time stop he's holding

---------------------------------------------------------------------------
-- 1: ORA RUSH
---------------------------------------------------------------------------
local function oraRush(S, player, state, aim)
	local c = cfg.OraRush
	if not ready(S, player, state, "OraRush", 1) then
		return
	end
	S.startCooldown(player, state, "OraRush", c.Cooldown, 1)
	S.lock(state, c.Windup + c.Duration + 0.15)
	local character, humanoid = alive(S, player)
	local life = state.Life
	local untilT = now() + c.Windup + c.Duration
	character:SetAttribute("OraRushUntil", untilT)
	S.Adapter.setMoveModifier(humanoid, "OraRush", c.WalkMultiplier)
	S.fx("Ability", { Character = character, Act = ACT, Move = "OraRush", Phase = "Start", Windup = c.Windup, Duration = c.Duration })
	local ticks = math.max(1, math.floor(c.Duration / c.Tick))
	local function stop()
		if humanoid.Parent then
			S.Adapter.setMoveModifier(humanoid, "OraRush", nil)
		end
		if character.Parent and character:GetAttribute("OraRushUntil") == untilT then
			character:SetAttribute("OraRushUntil", nil)
		end
	end
	for i = 1, ticks do
		task.delay(c.Windup + (i - 1) * c.Tick, function()
			if character:GetAttribute("OraRushUntil") ~= untilT then
				return -- already over
			end
			if not S.stillValid(player, state, life) then
				-- Stunned (or gone) out of it: The World goes back.
				stop()
				S.fx("Ability", { Character = character, Act = ACT, Move = "OraRush", Phase = "Stop" })
				return
			end
			local _, _, r = alive(S, player)
			local boxCF = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
			local last = i == ticks
			if last then
				Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.FinalDamage, Stun = c.FinalStun, Knockback = c.FinalKnockback, Launch = c.FinalLaunch, Direction = r.CFrame.LookVector, Source = "JotaroOra" }, c.MaxTargets)
				-- The last punch's shockwave catches everyone in front.
				local waveAt = (r.CFrame * CFrame.new(0, 0, -c.HitboxForward - 3)).Position
				Moves.aoe(S, player, waveAt, c.ShockwaveRadius, { Damage = c.ShockwaveDamage, Stun = 0.4, Knockback = 30, Direction = r.CFrame.LookVector, Source = "JotaroOra" }, 6)
				S.fx("Ability", { Character = character, Act = ACT, Move = "OraRush", Phase = "Finish", Position = boxCF.Position, Direction = r.CFrame.LookVector, Radius = c.ShockwaveRadius })
				stop()
			else
				local count, hitSet = Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = r.CFrame.LookVector, Source = "JotaroOra" }, c.MaxTargets)
				-- Drag whoever's caught back in front of The World (they can't slip out).
				for target in pairs(hitSet or {}) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr and not tr.Anchored then
						local to = boxCF.Position - tr.Position
						to = Vector3.new(to.X, 0, to.Z)
						tr.AssemblyLinearVelocity = Vector3.new(to.X * c.Drag, tr.AssemblyLinearVelocity.Y, to.Z * c.Drag) + r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
					end
				end
				if count > 0 and i % 2 == 0 then
					S.fx("Ability", { Act = ACT, Move = "OraRush", Phase = "Hit", Position = boxCF.Position })
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- 2: STAR FINGER
---------------------------------------------------------------------------
local function starFinger(S, player, state, aim)
	local c = cfg.StarFinger
	if not ready(S, player, state, "StarFinger", 2) then
		return
	end
	S.startCooldown(player, state, "StarFinger", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.25)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "StarFinger", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = Moves.flat(S.aim(aim, r))
		local from = r.Position + dir * 1.5
		-- Stops at a wall.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local hit = workspace:Raycast(from, dir * c.Length, params)
		local length = c.Length
		if hit and not (hit.Instance.Parent and hit.Instance.Parent:FindFirstChildOfClass("Humanoid")) then
			length = (hit.Position - from).Magnitude
		end
		local mid = from + dir * (length / 2)
		Moves.boxHit(S, player, CFrame.lookAt(mid, mid + dir), Vector3.new(c.Width, 5, length), { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Source = "JotaroFinger" }, 6)
		S.fx("Ability", { Character = char, Act = ACT, Move = "StarFinger", Phase = "Strike", From = from, Direction = dir, Length = length })
	end)
end

---------------------------------------------------------------------------
-- 3: BEARING SHOT (instant)
---------------------------------------------------------------------------
local function bearingShot(S, player, state, aim)
	local c = cfg.BearingShot
	if not ready(S, player, state, "BearingShot", 3) then
		return
	end
	S.startCooldown(player, state, "BearingShot", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "BearingShot", Phase = "Flick", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = S.aim(aim, r)
		local origin = S.origin(char, r, Moves.HAND)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local wall = workspace:Raycast(origin, dir * c.Range, params)
		local reach = c.Range
		if wall and not (wall.Instance.Parent and wall.Instance.Parent:FindFirstChildOfClass("Humanoid")) then
			reach = (wall.Position - origin).Magnitude
		end
		local mid = origin + dir * (reach / 2)
		local box = CFrame.lookAt(mid, mid + dir)
		local best, bestD, bestPos
		for _, target in ipairs(S.Hitbox.inBox(char, box, Vector3.new(c.Width, c.Width + 2, reach), 8)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr then
				local dd = (tr.Position - origin):Dot(dir)
				if dd > 0 and (not bestD or dd < bestD) then
					best, bestD, bestPos = target, dd, tr.Position
				end
			end
		end
		local landed = false
		if best then
			landed = S.hit(player, best, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Position = bestPos, Source = "JotaroBearing" })
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "BearingShot", Phase = "Shot", From = origin, To = bestPos or (origin + dir * reach), Hit = landed })
	end)
end

function Jotaro.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		oraRush(S, player, state, aim)
	elseif slot == 2 then
		starFinger(S, player, state, aim)
	elseif slot == 3 then
		bearingShot(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- STAR PLATINUM: THE WORLD (ultimate)
---------------------------------------------------------------------------
local function resume(S, character, token)
	local stop = stops[character]
	if not stop or stop.Token ~= token then
		return
	end
	stops[character] = nil
	for _, target in ipairs(stop.Frozen) do
		thaw(target)
	end
	if character.Parent then
		character:SetAttribute("TimeStopper", nil)
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		S.Adapter.setMoveModifier(humanoid, "TimeStop", nil)
	end
	-- Every knife, bullet and projectile hanging in the zone flies on.
	if S.Projectiles and S.Projectiles.resumeTime then
		S.Projectiles.resumeTime(token)
	end
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Resume", Position = stop.Center })
end

function Jotaro.Ultimate(S, player, state, aim)
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
		local char, _, r = alive(S, player)
		local duration = (typeof(player) == "table" and player.IsBot) and u.BotDuration or u.Duration
		local token = tostring({})
		local center, radius = r.Position, u.Range
		local frozen, isFrozen = {}, {}
		-- Everyone inside the zone freezes, and so does anyone who walks in.
		local function sweep()
			for _, target in ipairs(S.Hitbox.inRadius(char, center, radius, 40)) do
				local hum = target:FindFirstChildOfClass("Humanoid")
				if not isFrozen[target] and hum and hum.Health > 0 and target ~= char and freeze(target) then
					isFrozen[target] = true
					table.insert(frozen, target)
				end
			end
		end
		sweep()
		stops[char] = { Token = token, Frozen = frozen, Center = center }
		char:SetAttribute("TimeStopper", now() + duration)
		-- In stopped time he's quicker, and his grab and knives are ready at once.
		local _, hum = alive(S, player)
		if hum then
			S.Adapter.setMoveModifier(hum, "TimeStop", u.SpeedMultiplier)
		end
		local slots = { OraRush = 1, StarFinger = 2, BearingShot = 3 }
		for _, name in ipairs(u.ResetCooldowns or {}) do
			S.startCooldown(player, state, name, 0, slots[name])
		end
		if S.Projectiles and S.Projectiles.stopTime then
			S.Projectiles.stopTime(token, center, radius, player)
		end
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Stop", Position = center, Range = radius, Duration = duration, Frozen = frozen })
		local function tick()
			local stop = stops[char]
			if not stop or stop.Token ~= token then
				return
			end
			sweep()
			task.delay(0.2, tick)
		end
		task.delay(0.2, tick)
		task.delay(duration, function()
			resume(S, char, token)
		end)
	end)
end

function Jotaro.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("OraRushUntil", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "OraRush", nil)
		end
		-- He went down (or switched): time moves again.
		local stop = stops[character]
		if stop then
			resume(S, character, stop.Token)
		end
	end
end

return Jotaro
