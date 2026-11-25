--[[
	Ringo_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Ringo Roadagain: Mandom (six seconds back).
	Its other half is Ringo_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: Ringo
-- ======================================================================
__modules["Ringo"] = function()
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

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

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
end

-- ======================================================================
-- MODULE: RingoOutfit
-- ======================================================================
__modules["RingoOutfit"] = function()
--[[
	RingoOutfit  (ServerScriptService.SpinServer.RingoOutfit)

	Gives a character the look of Ringo Roadagain while they play him
	(TuskAct 19), built from blocky parts (no catalog asset ids), matched
	to his art:
	  * grey hair swept up and back, a grey moustache and chin beard
	  * a sleeveless grey top with a huge high collar (a folded-back hood),
	    open down the chest; orange "60" and "5" marks and Mandom's yellow
	    WATCH HAND across his chest (a triangle at the top, a ring at the
	    bottom, small yellow squares beside it)
	  * pink tubes plugged into his right arm and chest, gold rings where
	    they go in
	  * purple gloves, a gold bracelet, a brown gun belt with a holster
	  * grey trousers
	Mandom itself (MandomStand) rides on his right shoulder.
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local RingoOutfit = {}
RingoOutfit.Act = 19

local C = {
	Hair = Color3.fromRGB(176, 180, 188),
	HairShade = Color3.fromRGB(130, 134, 144),
	Top = Color3.fromRGB(150, 156, 166),
	TopShade = Color3.fromRGB(112, 118, 130),
	CollarIn = Color3.fromRGB(196, 200, 208),
	Mark = Color3.fromRGB(226, 120, 50),
	Hand = Color3.fromRGB(246, 204, 40),
	Tube = Color3.fromRGB(190, 74, 124),
	Ring = Color3.fromRGB(226, 182, 76),
	Glove = Color3.fromRGB(150, 128, 176),
	Gold = Color3.fromRGB(230, 186, 70),
	Belt = Color3.fromRGB(150, 96, 46),
	BeltDark = Color3.fromRGB(104, 64, 30),
	Buckle = Color3.fromRGB(220, 190, 110),
	Pants = Color3.fromRGB(132, 138, 150),
	Shoe = Color3.fromRGB(70, 52, 40),
}

local saved = setmetatable({}, { __mode = "k" })

local function piece(parent, outfit, name, size, color, offset)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.Color = color
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = outfit
	return p
end

-- A flat disc facing forward (-Z).
local function disc(parent, outfit, name, d, depth, color, offset)
	local p = piece(parent, outfit, name, Vector3.new(depth, d, d), color, offset * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function cyl(parent, outfit, name, a, b, d, color)
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	local p = piece(parent, outfit, name, Vector3.new(len + d * 0.3, d, d), color, CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Grey hair swept up and back: a cap, a tall quiff leaning back, sides.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.08 * s, 0.3 * s, head.Size.Z + 0.1 * s), C.Hair, CFrame.new(0, h - 0.1 * s, 0.02 * s))
	piece(head, outfit, "Quiff", Vector3.new(head.Size.X * 0.9, 0.4 * s, head.Size.Z * 0.85), C.Hair, CFrame.new(0, h + 0.15 * s, 0.12 * s) * CFrame.Angles(math.rad(14), 0, 0))
	piece(head, outfit, "QuiffBack", Vector3.new(head.Size.X * 0.8, 0.3 * s, 0.4 * s), C.HairShade, CFrame.new(0, h + 0.1 * s, d + 0.08 * s) * CFrame.Angles(math.rad(30), 0, 0))
	piece(head, outfit, "QuiffFront", Vector3.new(head.Size.X * 0.7, 0.12 * s, 0.14 * s), C.HairShade, CFrame.new(0.1 * s, h + 0.28 * s, -d + 0.12 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HairSide", Vector3.new(0.1 * s, 0.5 * s, head.Size.Z * 0.7), C.Hair, CFrame.new(side * (w + 0.03 * s), h - 0.35 * s, 0.1 * s))
	end
	-- Moustache and chin beard.
	piece(head, outfit, "Moustache", Vector3.new(0.42 * s, 0.08 * s, 0.05 * s), C.Hair, CFrame.new(0, -0.22 * s, -d - 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "MoustacheEnd", Vector3.new(0.06 * s, 0.22 * s, 0.05 * s), C.Hair, CFrame.new(side * 0.2 * s, -0.33 * s, -d - 0.02 * s))
	end
	piece(head, outfit, "Beard", Vector3.new(0.14 * s, 0.24 * s, 0.06 * s), C.Hair, CFrame.new(0, -h + 0.04 * s, -d - 0.02 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	local head = character:FindFirstChild("Head")
	local skin = head and head.Color or Color3.fromRGB(196, 136, 92)
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Top", s + Vector3.new(0.1, 0.02, 0.1), C.Top, CFrame.new())
		-- Open down the chest: a V of skin.
		piece(upper, outfit, "Chest", Vector3.new(0.34, s.Y * 0.55, 0.04), skin, CFrame.new(-0.08, top - s.Y * 0.3, front - 0.06))
		piece(upper, outfit, "ChestTip", Vector3.new(0.22, 0.22, 0.04), skin, CFrame.new(-0.08, top - s.Y * 0.58, front - 0.06) * CFrame.Angles(0, 0, math.pi / 4))
		-- The huge high collar (a folded-back hood), open at the front.
		piece(upper, outfit, "CollarBack", Vector3.new(s.X * 0.85, 0.95, 0.25), C.Top, CFrame.new(0, top + 0.4, -front - 0.05) * CFrame.Angles(math.rad(-12), 0, 0))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Collar", Vector3.new(0.22, 0.9, s.Z * 0.9), C.Top, CFrame.new(side * s.X * 0.36, top + 0.36, 0.02) * CFrame.Angles(0, 0, side * -0.22))
			piece(upper, outfit, "CollarIn", Vector3.new(0.06, 0.8, s.Z * 0.75), C.CollarIn, CFrame.new(side * (s.X * 0.36 - 0.12), top + 0.36, 0.0) * CFrame.Angles(0, 0, side * -0.22))
			piece(upper, outfit, "Lapel", Vector3.new(0.3, 0.7, 0.06), C.TopShade, CFrame.new(side * 0.28 - 0.08, top - 0.3, front - 0.05) * CFrame.Angles(0, 0, side * 0.35))
		end
		-- "60" and "5" marks.
		piece(upper, outfit, "Mark60", Vector3.new(0.26, 0.16, 0.04), C.Mark, CFrame.new(0.2, 0.05, front - 0.06))
		piece(upper, outfit, "Mark5", Vector3.new(0.12, 0.16, 0.04), C.Mark, CFrame.new(-0.6, 0.3, front - 0.06))
		-- Mandom's watch hand across his chest: from up by his left
		-- shoulder down towards his right hip, a triangle at the top, a ring below.
		local a = Vector3.new(-0.55, top - 0.12, front - 0.1)
		local b = Vector3.new(0.35, -top + 0.08, front - 0.1)
		local mid = (a + b) / 2
		piece(upper, outfit, "WatchHand", Vector3.new(0.07, (b - a).Magnitude, 0.05), C.Hand, CFrame.lookAt(mid, mid + Vector3.new(0, 0, -1), (a - b).Unit))
		piece(upper, outfit, "HandTip", Vector3.new(0.22, 0.22, 0.05), C.Hand, CFrame.new(a) * CFrame.Angles(0, 0, math.pi / 4))
		local ring = piece(upper, outfit, "HandRing", Vector3.new(0.05, 0.24, 0.24), C.Hand, CFrame.new(b) * CFrame.Angles(0, math.pi / 2, 0))
		ring.Shape = Enum.PartType.Cylinder
		piece(upper, outfit, "Mark", Vector3.new(0.13, 0.13, 0.05), C.Hand, CFrame.new(0.05, top - 0.2, front - 0.1) * CFrame.Angles(0, 0, math.pi / 4))
		piece(upper, outfit, "Mark", Vector3.new(0.12, 0.12, 0.05), C.Hand, CFrame.new(-0.7, 0.5, front - 0.1) * CFrame.Angles(0, 0, math.pi / 4))
		-- Pink tubes into his chest (right side), gold rings where they go in.
		for k, y in ipairs({ 0.35, -0.05, -0.4 }) do
			local into = Vector3.new(0.7 - k * 0.06, y, front - 0.04)
			local from = Vector3.new(s.X / 2 + 0.35, y + 0.35, front + 0.25)
			cyl(upper, outfit, "Tube", from, into, 0.13, C.Tube)
			local r = piece(upper, outfit, "TubeRing", Vector3.new(0.05, 0.2, 0.2), C.Ring, CFrame.new(into) * CFrame.Angles(0, math.pi / 2, 0))
			r.Shape = Enum.PartType.Cylinder
		end
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Pants", ls + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
		-- The brown gun belt, buckle, and a holster on his right hip.
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.16, 0.24, ls.Z + 0.16), C.Belt, CFrame.new(0, ls.Y / 2 - 0.1, 0))
		piece(lower, outfit, "BeltEdge", Vector3.new(ls.X + 0.18, 0.05, ls.Z + 0.18), C.BeltDark, CFrame.new(0, ls.Y / 2 - 0.22, 0))
		piece(lower, outfit, "Buckle", Vector3.new(0.3, 0.2, 0.06), C.Buckle, CFrame.new(0, ls.Y / 2 - 0.1, -ls.Z / 2 - 0.1))
		piece(lower, outfit, "Holster", Vector3.new(0.24, 0.6, 0.4), C.BeltDark, CFrame.new(ls.X / 2 + 0.14, -0.05, 0.05) * CFrame.Angles(0, 0, 0.12))
		piece(lower, outfit, "Grip", Vector3.new(0.12, 0.3, 0.16), Color3.fromRGB(60, 50, 44), CFrame.new(ls.X / 2 + 0.16, 0.3, 0.12) * CFrame.Angles(0, 0, -0.3))
	end
	-- Bare arms (sleeveless), purple gloves, a gold bracelet on the right wrist.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Skin", arm.Size + Vector3.new(0.04, 0, 0.04), skin, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftHand", "RightHand" }) do
		local hand = character:FindFirstChild(name)
		if hand then
			piece(hand, outfit, "Glove", hand.Size + Vector3.new(0.1, 0.06, 0.1), C.Glove, CFrame.new())
			piece(hand, outfit, "Cuff", Vector3.new(hand.Size.X + 0.2, 0.16, hand.Size.Z + 0.2), C.Glove, CFrame.new(0, hand.Size.Y / 2 + 0.02, 0))
		end
	end
	local rightLower = character:FindFirstChild("RightLowerArm") or character:FindFirstChild("Right Arm")
	if rightLower then
		local as = rightLower.Size
		piece(rightLower, outfit, "Bracelet", Vector3.new(as.X + 0.14, 0.14, as.Z + 0.14), C.Gold, CFrame.new(0, -as.Y / 2 + 0.12, 0))
	end
	-- Pink tubes plugged into his right arm, gold rings where they go in.
	local rightUpper = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm")
	if rightUpper then
		local as = rightUpper.Size
		for k, y in ipairs({ 0.25, -0.15 }) do
			local into = Vector3.new(as.X / 2 + 0.02, y, -0.05 * k)
			local from = Vector3.new(as.X / 2 + 0.45, y + 0.4, 0.3)
			cyl(rightUpper, outfit, "Tube", from, into, 0.13, C.Tube)
			local r = piece(rightUpper, outfit, "TubeRing", Vector3.new(0.05, 0.2, 0.2), C.Ring, CFrame.new(into) * CFrame.Angles(0, 0, math.pi / 2))
			r.Shape = Enum.PartType.Cylinder
		end
	end
	if rightLower then
		local as = rightLower.Size
		local into = Vector3.new(as.X / 2 + 0.02, 0.1, 0)
		cyl(rightLower, outfit, "Tube", Vector3.new(as.X / 2 + 0.5, 0.7, 0.2), into, 0.13, C.Tube)
		local r = piece(rightLower, outfit, "TubeRing", Vector3.new(0.05, 0.2, 0.2), C.Ring, CFrame.new(into) * CFrame.Angles(0, 0, math.pi / 2))
		r.Shape = Enum.PartType.Cylinder
	end
	-- Grey trousers, brown boots.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Pants", leg.Size + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.08, 0.04, 0.12), C.Shoe, CFrame.new())
		end
	end
end

function RingoOutfit.apply(character)
	if character:FindFirstChild("RingoOutfit") then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local store = { Hidden = {} }
	saved[character] = store
	for _, d in ipairs(character:GetChildren()) do
		if d:IsA("Accessory") then
			local handle = d:FindFirstChild("Handle")
			local kind = d.AccessoryType
			if handle and (kind == Enum.AccessoryType.Hat or kind == Enum.AccessoryType.Hair or kind == Enum.AccessoryType.Unknown) then
				store.Hidden[handle] = handle.Transparency
				handle.Transparency = 1
			end
		end
	end
	local outfit = Instance.new("Model")
	outfit.Name = "RingoOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function RingoOutfit.remove(character)
	local outfit = character:FindFirstChild("RingoOutfit")
	if outfit then
		outfit:Destroy()
	end
	local store = saved[character]
	if not store then
		return
	end
	saved[character] = nil
	for thing, transparency in pairs(store.Hidden) do
		if thing.Parent then
			thing.Transparency = transparency
		end
	end
end

local function watch(character)
	local function update()
		if character:GetAttribute("TuskAct") == RingoOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == RingoOutfit.Act then
					RingoOutfit.apply(character)
				end
			end)
		else
			RingoOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function RingoOutfit.init()
	local function onPlayer(player)
		player.CharacterAppearanceLoaded:Connect(watch)
		if player.Character then
			watch(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	-- Stand-user NPCs (StandBots) wear the outfit too.
	local CollectionService = game:GetService("CollectionService")
	for _, model in ipairs(CollectionService:GetTagged("SpinFighter")) do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("SpinFighter"):Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
end

return RingoOutfit
end
end
