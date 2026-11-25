--[[
	Ringo  (ServerScriptService.SpinServer.TuskActs.Ringo)

	Ringo Roadagain: MANDOM. Turning his watch rewinds time by exactly 6
	seconds ("not a second more, not a second less"), and only he
	remembers what happened. Registered as "Act" 19 so it reuses the Tusk
	ability system.
	  M1        REVOLVER COMBO: three blows and a point-blank shot
	  Ability 1 SIX SECONDS: he turns his watch and goes back 6 seconds:
	            to where he was, with the health he had (never less than
	            now). Enemies close by lose the 6 seconds too: they're
	            snapped back to where they were and dazed.
	  Ability 2 QUICK DRAW: a revolver shot (instant, long range)
	  Ability 3 MANDOM COUNTER: he waits with his hand on the watch; hit
	            him and time rewinds: the hit never lands, he's behind you
	            and shoots
	  Ultimate  THE PATH OF JUSTICE: 6 seconds that happen twice. When
	            they end, time rewinds: his health goes back to where it
	            was, and every hit he landed in them lands AGAIN.
	Every fighter's position and health are remembered for a few seconds
	(Init), so the rewind knows where everyone was.
	Numbers: TuskConfig.Ringo. All damage goes through S.hit (CombatAdapter).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Ringo = {}
local cfg = TuskConfig.Ringo
local ACT = 19
local REWIND = cfg.Rewind or 6
local SAMPLE = 0.2 -- seconds between history samples

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

---------------------------------------------------------------------------
-- History: where everyone was, and their health, for the last few seconds
---------------------------------------------------------------------------
local history = setmetatable({}, { __mode = "k" }) -- [character] = { {T, CFrame, Health}, ... } oldest first

local function record(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		history[character] = nil
		return
	end
	local list = history[character]
	if not list then
		list = {}
		history[character] = list
	end
	local t = now()
	table.insert(list, { T = t, CFrame = root.CFrame, Health = hum.Health })
	while #list > 0 and t - list[1].T > REWIND + 1.5 do
		table.remove(list, 1)
	end
end

-- Where (and how healthy) they were `seconds` ago: the sample closest to
-- that time, or their oldest one if they haven't been around that long.
local function pastOf(character, seconds)
	local list = history[character]
	if not list or #list == 0 then
		return nil
	end
	local want = now() - seconds
	local best = list[1]
	for _, s in ipairs(list) do
		if s.T <= want then
			best = s
		else
			break
		end
	end
	return best
end
Ringo.pastOf = pastOf
Ringo.record = record

-- Riders and anyone on the race map aren't moved (the horse would be left behind).
local function canRewind(character)
	local hum = character:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and hum.SeatPart == nil
end

local function moveTo(character, cf)
	local root = character:FindFirstChild("HumanoidRootPart")
	character:PivotTo(cf)
	if root then
		root.AssemblyLinearVelocity = Vector3.new()
	end
end

local function daze(S, target, seconds)
	local hum = target:FindFirstChildOfClass("Humanoid")
	if hum and seconds > 0 then
		S.Adapter.applyStun(hum, seconds)
	end
	target:SetAttribute("MandomDazedUntil", now() + seconds)
end

---------------------------------------------------------------------------
-- M1
---------------------------------------------------------------------------
function Ringo.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: SIX SECONDS
---------------------------------------------------------------------------
local function sixSeconds(S, player, state)
	local c = cfg.SixSeconds
	if not ready(S, player, state, "SixSeconds", 1) then
		return
	end
	local character, humanoid, root = alive(S, player)
	if not canRewind(character) then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	local past = pastOf(character, REWIND)
	if not past then
		S.tell(player, "Denied", { Reason = "NotReady" })
		return
	end
	S.startCooldown(player, state, "SixSeconds", c.Cooldown, 1)
	S.lock(state, c.Windup + 0.2)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "SixSeconds", Phase = "Wind", Windup = c.Windup, Position = root.Position })
	task.delay(c.Windup, function()
		if state.Life ~= life or not S.Adapter.getAlive(player) or not canRewind(character) then
			return
		end
		local from = root.Position
		local was = pastOf(character, REWIND + c.Windup) or past
		local to = was.CFrame
		if (to.Position - from).Magnitude > c.MaxDistance then
			to = root.CFrame -- (somewhere he can't be put back to: only the health)
		end
		-- Everyone close by loses the 6 seconds too.
		local snapped = {}
		for _, target in ipairs(S.Hitbox.inRadius(character, from, c.DazeRadius, 10)) do
			if canRewind(target) then
				local theirs = pastOf(target, REWIND + c.Windup)
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr then
					local before = tr.Position
					if theirs and (theirs.CFrame.Position - before).Magnitude <= c.EnemyMaxDistance then
						moveTo(target, theirs.CFrame)
					end
					daze(S, target, c.DazeTime)
					table.insert(snapped, { Target = target, From = before, To = tr.Position })
				end
			end
		end
		moveTo(character, to)
		humanoid.Health = math.min(humanoid.MaxHealth, math.max(humanoid.Health, was.Health))
		S.fx("Ability", { Character = character, Act = ACT, Move = "SixSeconds", Phase = "Rewind", From = from, To = to.Position, Snapped = snapped })
	end)
end

---------------------------------------------------------------------------
-- 2: QUICK DRAW (instant shot)
---------------------------------------------------------------------------
local function wallDistance(origin, direction, range, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(origin, direction * range, params)
	if hit and not (hit.Instance.Parent and hit.Instance.Parent:FindFirstChildOfClass("Humanoid")) then
		return (hit.Position - origin).Magnitude
	end
	return range
end

-- The first enemy along a line from `origin`.
local function shoot(S, character, origin, direction, range, width)
	local reach = wallDistance(origin, direction, range, { character })
	local mid = origin + direction * (reach / 2)
	local box = CFrame.lookAt(mid, mid + direction)
	local best, bestDist, bestPos
	for _, target in ipairs(S.Hitbox.inBox(character, box, Vector3.new(width, width + 2, reach), 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			local d = (tr.Position - origin):Dot(direction)
			if d > 0 and (not bestDist or d < bestDist) then
				best, bestDist, bestPos = target, d, tr.Position
			end
		end
	end
	local endPos = bestPos or origin + direction * reach
	return best, endPos
end
Ringo.shoot = shoot

local function quickDraw(S, player, state, aim)
	local c = cfg.QuickDraw
	if not ready(S, player, state, "QuickDraw", 2) then
		return
	end
	S.startCooldown(player, state, "QuickDraw", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "QuickDraw", Phase = "Draw", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local direction = S.aim(aim, r)
		local origin = S.origin(char, r, Moves.HAND)
		local target, endPos = shoot(S, char, origin, direction, c.Range, c.Width)
		local landed = false
		if target then
			landed = S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = direction, Position = endPos, Source = "RingoShot" })
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "QuickDraw", Phase = "Bang", From = origin, To = endPos, Hit = landed })
	end)
end

---------------------------------------------------------------------------
-- 3: MANDOM COUNTER
---------------------------------------------------------------------------
local counters = setmetatable({}, { __mode = "k" }) -- [character] = function(attackerPlayer, info)

local function registerCounter(S)
	if S.Adapter.DodgeHandlers and not S.Adapter.DodgeHandlers.MandomCounter then
		S.Adapter.DodgeHandlers.MandomCounter = function(attackerPlayer, target, info)
			local counter = counters[target]
			if counter then
				counter(attackerPlayer, info)
			end
		end
	end
end

local function counterStance(S, player, state)
	local c = cfg.Counter
	if not ready(S, player, state, "Counter", 3) then
		return
	end
	registerCounter(S)
	S.startCooldown(player, state, "Counter", c.Cooldown, 3)
	S.lock(state, c.Window + c.WhiffLag)
	local character, humanoid = alive(S, player)
	local life = state.Life
	local used = false
	S.Adapter.setMoveModifier(humanoid, "MandomCounter", 0.01) -- (never exactly 0)
	character:SetAttribute("MandomCounter", true)
	S.fx("Ability", { Character = character, Act = ACT, Move = "Counter", Phase = "Ready", Window = c.Window })
	local function finish()
		counters[character] = nil
		if character.Parent then
			character:SetAttribute("MandomCounter", nil)
		end
		if humanoid.Parent then
			S.Adapter.setMoveModifier(humanoid, "MandomCounter", nil)
		end
	end
	counters[character] = function(attackerPlayer)
		if used or state.Life ~= life then
			return
		end
		used = true
		finish()
		local attacker = attackerPlayer and attackerPlayer.Character
		local ar = attacker and attacker:FindFirstChild("HumanoidRootPart")
		local _, _, r = alive(S, player)
		if not r then
			return
		end
		local from = r.Position
		if ar and canRewind(character) then
			-- Behind them (or as close as a wall allows).
			local behind = ar.CFrame * CFrame.new(0, 0, c.Behind)
			local spot = behind.Position
			if not S.Hitbox.lineOfSight(ar.Position, spot, { attacker, character }) then
				spot = ar.Position + (from - ar.Position).Unit * 3
			end
			moveTo(character, CFrame.lookAt(spot, Vector3.new(ar.Position.X, spot.Y, ar.Position.Z)))
		end
		S.lock(state, 0.35)
		S.fx("Ability", { Character = character, Act = ACT, Move = "Counter", Phase = "Rewind", From = from, To = r.Position, Attacker = attacker })
		task.delay(0.12, function()
			if state.Life ~= life or not attacker or not attacker.Parent or not ar.Parent then
				return
			end
			local _, _, rr = alive(S, player)
			if not rr then
				return
			end
			local dir = unitOr(ar.Position - rr.Position, rr.CFrame.LookVector)
			local landed = S.hit(player, attacker, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Position = ar.Position, Unblockable = true, Source = "RingoCounter" })
			S.fx("Ability", { Character = character, Act = ACT, Move = "QuickDraw", Phase = "Bang", From = rr.Position + Vector3.new(0, 0.5, 0), To = ar.Position, Hit = landed })
		end)
	end
	task.delay(c.Window, function()
		if not used then
			finish()
			if state.Life == life then
				S.fx("Ability", { Character = character, Act = ACT, Move = "Counter", Phase = "Whiff" })
			end
		end
	end)
end

function Ringo.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		sixSeconds(S, player, state)
	elseif slot == 2 then
		quickDraw(S, player, state, aim)
	elseif slot == 3 then
		counterStance(S, player, state)
	end
end

---------------------------------------------------------------------------
-- THE PATH OF JUSTICE (ultimate)
---------------------------------------------------------------------------
local echoes = setmetatable({}, { __mode = "k" }) -- [player] = { Until, Hits = { {Target, Damage, Stun, Knockback, Direction} } }

function Ringo.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, humanoid = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.2)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Wind", Windup = u.Windup })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local startHealth = humanoid.Health
		local record = { Until = now() + u.Duration, Hits = {}, Life = life }
		echoes[player] = record
		character:SetAttribute("MandomPathUntil", record.Until)
		S.Adapter.setMoveModifier(humanoid, "MandomPath", u.Speed)
		S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Path", Duration = u.Duration })
		task.delay(u.Duration, function()
			if echoes[player] == record then
				echoes[player] = nil
			end
			if character.Parent then
				character:SetAttribute("MandomPathUntil", nil)
			end
			if humanoid.Parent then
				S.Adapter.setMoveModifier(humanoid, "MandomPath", nil)
			end
			if state.Life ~= life or humanoid.Health <= 0 then
				S.fx("Ultimate", { Character = character, Act = ACT, Phase = "End" })
				return
			end
			-- Time rewinds: his health is back, and every hit lands again.
			humanoid.Health = math.min(humanoid.MaxHealth, math.max(humanoid.Health, startHealth))
			local targets, seen = {}, {}
			for _, h in ipairs(record.Hits) do
				if not seen[h.Target] then
					seen[h.Target] = true
					table.insert(targets, h.Target)
				end
			end
			S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Rewind", Targets = targets, Count = #record.Hits })
			for i, h in ipairs(record.Hits) do
				task.delay(0.35 + (i - 1) * u.EchoGap, function()
					local tr = h.Target.Parent and h.Target:FindFirstChild("HumanoidRootPart")
					if not tr or state.Life ~= life then
						return
					end
					S.hit(player, h.Target, {
						Damage = h.Damage * u.EchoMultiplier,
						Stun = math.max(h.Stun or 0, u.EchoDazeTime),
						Knockback = h.Knockback or 0,
						Direction = h.Direction,
						Position = tr.Position,
						Unblockable = true,
						Source = "RingoEcho",
					})
				end)
			end
		end)
	end)
end

function Ringo.Cleanup(S, player, state)
	local character = state.Character
	echoes[player] = nil
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("MandomCounter", nil)
		character:SetAttribute("MandomPathUntil", nil)
		counters[character] = nil
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum then
			S.Adapter.setMoveModifier(hum, "MandomCounter", nil)
			S.Adapter.setMoveModifier(hum, "MandomPath", nil)
		end
	end
end

---------------------------------------------------------------------------
-- Init: remember everyone's last few seconds; note the ultimate's hits
---------------------------------------------------------------------------
local started = false
function Ringo.Init(S)
	if started then
		return
	end
	started = true
	S.Adapter.on("Hit", function(attackerPlayer, target, damage, info)
		local rec = attackerPlayer and echoes[attackerPlayer]
		if not rec or not target or now() > rec.Until or #rec.Hits >= cfg.Ultimate.MaxEchoes then
			return
		end
		if info and info.Source == "RingoEcho" then
			return
		end
		table.insert(rec.Hits, {
			Target = target,
			Damage = (info and info.Damage) or damage or 0,
			Stun = info and info.Stun,
			Knockback = info and info.Knockback,
			Direction = (info and typeof(info.Direction) == "Vector3") and info.Direction or Vector3.new(0, 0, 1),
		})
	end)
	task.spawn(function()
		while true do
			task.wait(SAMPLE)
			-- Only worth it while a Mandom user is around.
			local anyRingo = false
			for _, state in pairs(S.States) do
				if state.Act == ACT then
					anyRingo = true
					break
				end
			end
			if anyRingo then
				for _, state in pairs(S.States) do
					local character = state.Character
					if character and character.Parent then
						record(character)
					end
				end
			end
		end
	end)
end

return Ringo
