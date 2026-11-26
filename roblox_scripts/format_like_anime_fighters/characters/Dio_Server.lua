--[[
	Dio_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	DIO (Part 3): The World, knives and a road roller.
	Its other half is Dio_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: Dio
-- ======================================================================
__modules["Dio"] = function()
--[[
	Dio  (ServerScriptService.SpinServer.TuskActs.Dio)

	DIO (a visitor from another world: Part 3): THE WORLD. Not Diego's
	The World: a vampire with a golden Stand, knives and a road roller.
	Registered as "Act" 21 so it reuses the Tusk ability system.
	  M1        MUDA COMBO: The World punches with him; the 4th is a heavy
	            hook that launches
	  Ability 1 VAMPIRE DRAIN: he grabs the nearest enemy in front and
	            drinks their blood: they're held and hurt for 1.5 s, he heals,
	            then he throws them off
	  Ability 2 SPACE RIPPER STINGY EYES: two thin beams of fluid from his
	            eyes, long and fast (stopped by walls)
	  Ability 3 KNIFE VOLLEY: a fan of five knives. In his own stopped time:
	            a wall of ten, quick to throw again; they hang in the air and
	            fly when time moves
	  Ultimate  ZA WARUDO: ROAD ROLLER: time stops in a zone round him (5 s;
	            everyone inside, and anyone who walks in, freezes; projectiles
	            hang). Just before it moves again, a ROAD ROLLER crashes down
	            on the nearest frozen enemy ("ROAD ROLLER DA!")
	Numbers: TuskConfig.Dio. All damage goes through S.hit (CombatAdapter).
	Frozen characters carry the "TimeStopped" attribute (CombatAdapter.canAct
	refuses them) and have their root anchored by the server.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Dio = {}
local cfg = TuskConfig.Dio
local ACT = 21

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

function Dio.M1(S, player, state, aim)
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

local roadRoller -- (below)

local function inStoppedTime(character)
	return (character:GetAttribute("TimeStopper") or 0) > now()
end

---------------------------------------------------------------------------
-- 1: VAMPIRE DRAIN
---------------------------------------------------------------------------
local function vampireDrain(S, player, state, aim)
	local c = cfg.VampireDrain
	if not ready(S, player, state, "VampireDrain", 1) then
		return
	end
	local character, humanoid, root = alive(S, player)
	local target = Moves.findTarget(S, character, root, c.Range, c.Cone, S.aim(aim, root))
	if not target then
		S.startCooldown(player, state, "VampireDrain", c.MissCooldown, 1)
		S.fx("Ability", { Character = character, Act = ACT, Move = "VampireDrain", Phase = "Miss" })
		return
	end
	S.startCooldown(player, state, "VampireDrain", c.Cooldown, 1)
	S.lock(state, c.Windup + c.Time + 0.2)
	local life = state.Life
	local tr = target:FindFirstChild("HumanoidRootPart")
	S.fx("Ability", { Character = character, Act = ACT, Move = "VampireDrain", Phase = "Grab", Target = target, Time = c.Time + c.Windup })
	-- Held in front of him while he feeds.
	local hold = root.CFrame * CFrame.new(0, 0, -2.6)
	target:PivotTo(CFrame.lookAt(hold.Position, root.Position))
	pin(tr)
	local released = false
	local function release(push)
		if released then
			return
		end
		released = true
		unpin(tr)
		local _, _, r = alive(S, player)
		if push and r and target.Parent then
			local away = Vector3.new(tr.Position.X - r.Position.X, 0, tr.Position.Z - r.Position.Z)
			S.hit(player, target, { Damage = 1, Stun = c.EndStun, Knockback = c.EndKnockback, Direction = away.Magnitude > 0.1 and away.Unit or r.CFrame.LookVector, Position = tr.Position, Source = "DioDrain" })
		end
		S.fx("Ability", { Character = character, Act = ACT, Move = "VampireDrain", Phase = "End", Target = target })
	end
	local ticks = math.max(1, math.floor(c.Time / c.Tick))
	for i = 1, ticks do
		task.delay(c.Windup + i * c.Tick, function()
			if released then
				return
			end
			if not S.stillValid(player, state, life) or not target.Parent then
				release(false)
				return
			end
			local hum = target:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then
				release(false)
				return
			end
			local before = hum.Health
			if S.hit(player, target, { Damage = c.TickDamage, Stun = c.Tick + 0.15, Knockback = 0, Direction = Vector3.new(0, 1, 0), Position = tr.Position, Source = "DioDrain" }) then
				local taken = math.max(0, before - hum.Health)
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + taken * c.HealPerDamage)
				S.fx("Ability", { Character = character, Act = ACT, Move = "VampireDrain", Phase = "Tick", Target = target, Heal = taken * c.HealPerDamage })
			end
			if i == ticks then
				release(true)
			end
		end)
	end
	-- Never left pinned.
	task.delay(c.Windup + c.Time + 0.5, function()
		release(false)
	end)
end

---------------------------------------------------------------------------
-- 2: SPACE RIPPER STINGY EYES
---------------------------------------------------------------------------
local function stingyEyes(S, player, state, aim)
	local c = cfg.StingyEyes
	if not ready(S, player, state, "StingyEyes", 2) then
		return
	end
	S.startCooldown(player, state, "StingyEyes", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.25)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "StingyEyes", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local head = char:FindFirstChild("Head")
		local from = head and head.Position or (r.Position + Vector3.new(0, 1.5, 0))
		local dir = S.aim(aim, r)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local wall = workspace:Raycast(from, dir * c.Length, params)
		local length = c.Length
		if wall and not (wall.Instance.Parent and wall.Instance.Parent:FindFirstChildOfClass("Humanoid")) then
			length = (wall.Position - from).Magnitude
		end
		local mid = from + dir * (length / 2)
		Moves.boxHit(S, player, CFrame.lookAt(mid, mid + dir), Vector3.new(c.Width, c.Width + 1, length), { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Source = "DioEyes" }, 6)
		S.fx("Ability", { Character = char, Act = ACT, Move = "StingyEyes", Phase = "Fire", From = from, Direction = dir, Length = length })
	end)
end

---------------------------------------------------------------------------
-- 3: KNIFE VOLLEY (a wall of them in stopped time)
---------------------------------------------------------------------------
local function knives(S, player, state, aim)
	local c = cfg.Knives
	if not ready(S, player, state, "Knives", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local stopped = inStoppedTime(character)
	S.startCooldown(player, state, "Knives", stopped and c.StoppedCooldown or c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "Knives", Phase = "Throw", Windup = c.Windup, Stopped = stopped })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local base = S.aim(aim, r)
		local count = stopped and c.StoppedCount or c.Count
		local spread = stopped and c.StoppedSpread or c.Spread
		for i = 1, count do
			local yaw = math.rad((i - (count + 1) / 2) * spread * (stopped and 0.5 or 1))
			local pitch = stopped and math.rad(((i % 2) - 0.5) * spread * 0.6) or 0
			local dir = (CFrame.lookAt(Vector3.new(), base) * CFrame.Angles(pitch, yaw, 0)).LookVector
			S.fireDioKnife(player, state, {
				Origin = S.origin(char, r, Moves.HAND),
				Direction = dir,
				Speed = c.Speed,
				Radius = c.Radius,
				Range = c.Range,
				OnHit = function(target, position)
					S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Position = position, Source = "DioKnife" })
				end,
			})
		end
	end)
end

function Dio.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		vampireDrain(S, player, state, aim)
	elseif slot == 2 then
		stingyEyes(S, player, state, aim)
	elseif slot == 3 then
		knives(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- ZA WARUDO: ROAD ROLLER (ultimate)
---------------------------------------------------------------------------
-- ROAD ROLLER DA!: it comes down on the nearest frozen enemy.
roadRoller = function(S, player, state, char, stop)
	local u = cfg.Ultimate
	local r = char:FindFirstChild("HumanoidRootPart")
	if not r then
		return
	end
	local best, bestD, bestPos
	for _, target in ipairs(stop.Frozen) do
		local tr = target.Parent and target:FindFirstChild("HumanoidRootPart")
		if tr then
			local d = (tr.Position - r.Position).Magnitude
			if d <= u.RollerRange and (not bestD or d < bestD) then
				best, bestD, bestPos = target, d, tr.Position
			end
		end
	end
	local at = bestPos or (r.Position + Moves.flat(r.CFrame.LookVector) * 12)
	at = Moves.groundBelow(at, { char, best })
	local fall = 0.55
	S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Roller", Position = at, Radius = u.RollerRadius, Fall = fall })
	task.delay(fall, function()
		if not char.Parent then
			return
		end
		for _, target in ipairs(S.Hitbox.inRadius(char, at + Vector3.new(0, 2.5, 0), u.RollerRadius, 10)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr then
				local away = Vector3.new(tr.Position.X - at.X, 0, tr.Position.Z - at.Z)
				S.hit(player, target, { Damage = u.RollerDamage, Stun = u.RollerStun, Knockback = u.RollerKnockback, Direction = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1), Position = tr.Position, Unblockable = true, Source = "DioRoller" })
			end
		end
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Crash", Position = at, Radius = u.RollerRadius })
	end)
end

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

function Dio.Ultimate(S, player, state, aim)
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
		local slots = { VampireDrain = 1, StingyEyes = 2, Knives = 3 }
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
		-- ROAD ROLLER DA!: just before time moves again.
		task.delay(math.max(0.3, duration - u.RollerAt), function()
			local stop = stops[char]
			if stop and stop.Token == token and state.Life == life then
				roadRoller(S, player, state, char, stop)
			end
		end)
		task.delay(duration, function()
			resume(S, char, token)
		end)
	end)
end

function Dio.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		-- He went down (or switched): time moves again.
		local stop = stops[character]
		if stop then
			resume(S, character, stop.Token)
		end
	end
end

return Dio
end

-- ======================================================================
-- MODULE: DioOutfit
-- ======================================================================
__modules["DioOutfit"] = function()
--[[
	DioOutfit  (ServerScriptService.SpinServer.DioOutfit)

	Gives a character the look of DIO (Part 3) while they play him
	(TuskAct 21), built from blocky parts (no catalog asset ids):
	  * swept-up BLOND hair with spiky points and a few strands down the
	    forehead; a GREEN HEADBAND with a gold heart; green lips
	  * a YELLOW sleeveless jacket, open over a tight black top, with
	    flared shoulders and a high collar; bare arms with green wristbands
	  * a black belt with a green buckle
	  * YELLOW trousers with gold HEART knee pads, and yellow boots with
	    green trim
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local DioOutfit = {}
DioOutfit.Act = 21

local C = {
	Hair = Color3.fromRGB(246, 218, 120),
	HairShade = Color3.fromRGB(214, 176, 80),
	Band = Color3.fromRGB(50, 140, 96),
	Lips = Color3.fromRGB(60, 140, 90),
	Jacket = Color3.fromRGB(236, 194, 58),
	JacketShade = Color3.fromRGB(196, 150, 36),
	Top = Color3.fromRGB(28, 28, 32),
	Gold = Color3.fromRGB(246, 210, 90),
	Green = Color3.fromRGB(50, 140, 96),
	Belt = Color3.fromRGB(24, 24, 28),
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

local function heart(parent, outfit, cf, h)
	for _, side in ipairs({ -1, 1 }) do
		local lobe = piece(parent, outfit, "HeartLobe", Vector3.new(0.06, h * 0.6, h * 0.6), C.Gold, cf * CFrame.new(side * h * 0.2, h * 0.14, 0) * CFrame.Angles(0, math.pi / 2, 0))
		lobe.Shape = Enum.PartType.Cylinder
	end
	piece(parent, outfit, "HeartPoint", Vector3.new(h * 0.56, h * 0.56, 0.06), C.Gold, cf * CFrame.new(0, -h * 0.1, 0) * CFrame.Angles(0, 0, math.pi / 4))
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Blond hair swept up and back in spiky points.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.1 * s, 0.35 * s, head.Size.Z + 0.12 * s), C.Hair, CFrame.new(0, h - 0.08 * s, 0.03 * s))
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.1 * s, 0.75 * s, 0.22 * s), C.Hair, CFrame.new(0, h - 0.4 * s, d + 0.06 * s))
	for k = -2, 2 do
		local spike = CFrame.new(k * 0.22 * s, h + 0.12 * s, 0.1 * s + math.abs(k) * 0.05 * s) * CFrame.Angles(math.rad(-35), 0, math.rad(-k * 18))
		piece(head, outfit, "Spike", Vector3.new(0.24 * s, 0.6 * s, 0.2 * s), k % 2 == 0 and C.Hair or C.HairShade, spike * CFrame.new(0, 0.25 * s, 0))
	end
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "SideHair", Vector3.new(0.12 * s, 0.6 * s, head.Size.Z * 0.75), C.Hair, CFrame.new(side * (w + 0.04 * s), h - 0.42 * s, 0.08 * s))
		piece(head, outfit, "Strand", Vector3.new(0.08 * s, 0.4 * s, 0.05 * s), C.Hair, CFrame.new(side * 0.12 * s, h - 0.35 * s, -d - 0.03 * s) * CFrame.Angles(0, 0, side * 0.25))
	end
	-- The green headband with a gold heart.
	piece(head, outfit, "Headband", Vector3.new(head.Size.X + 0.12 * s, 0.14 * s, head.Size.Z + 0.12 * s), C.Band, CFrame.new(0, h - 0.24 * s, 0))
	heart(head, outfit, CFrame.new(0, h - 0.24 * s, -d - 0.08 * s), 0.26 * s)
	-- Green lips.
	piece(head, outfit, "Lips", Vector3.new(0.34 * s, 0.1 * s, 0.05 * s), C.Lips, CFrame.new(0, -0.3 * s, -d - 0.02 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	local head = character:FindFirstChild("Head")
	local skin = head and head.Color or Color3.fromRGB(236, 206, 176)
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Top", s + Vector3.new(0.06, 0.02, 0.06), C.Top, CFrame.new())
		-- The yellow jacket: sides, back and shoulders; open at the front.
		piece(upper, outfit, "JacketBack", Vector3.new(s.X + 0.14, s.Y + 0.04, 0.12), C.Jacket, CFrame.new(0, 0, -front + 0.02))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "JacketSide", Vector3.new(0.14, s.Y + 0.04, s.Z + 0.14), C.Jacket, CFrame.new(side * (s.X / 2 + 0.02), 0, 0))
			piece(upper, outfit, "JacketFront", Vector3.new(s.X * 0.3, s.Y + 0.04, 0.12), C.Jacket, CFrame.new(side * s.X * 0.36, 0, front - 0.04))
			piece(upper, outfit, "JacketEdge", Vector3.new(0.06, s.Y, 0.13), C.JacketShade, CFrame.new(side * s.X * 0.21, 0, front - 0.045))
			-- Flared shoulders.
			piece(upper, outfit, "Shoulder", Vector3.new(0.7, 0.3, s.Z + 0.3), C.Jacket, CFrame.new(side * (s.X / 2 + 0.15), top - 0.05, 0) * CFrame.Angles(0, 0, side * -0.35))
			piece(upper, outfit, "ShoulderEdge", Vector3.new(0.72, 0.06, s.Z + 0.32), C.JacketShade, CFrame.new(side * (s.X / 2 + 0.17), top - 0.2, 0) * CFrame.Angles(0, 0, side * -0.35))
		end
		-- A high collar.
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.7, 0.45, 0.16), C.Jacket, CFrame.new(0, top + 0.2, -front))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "CollarSide", Vector3.new(0.14, 0.45, s.Z * 0.8), C.Jacket, CFrame.new(side * s.X * 0.32, top + 0.2, 0) * CFrame.Angles(0, side * -0.25, 0))
		end
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.Jacket, CFrame.new())
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.16, 0.18, ls.Z + 0.16), C.Belt, CFrame.new(0, ls.Y / 2 - 0.08, 0))
		piece(lower, outfit, "Buckle", Vector3.new(0.3, 0.2, 0.06), C.Green, CFrame.new(0, ls.Y / 2 - 0.08, -ls.Z / 2 - 0.1))
	end
	-- Bare arms, green wristbands.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Skin", arm.Size + Vector3.new(0.04, 0, 0.04), skin, CFrame.new())
			if name:find("Lower") then
				piece(arm, outfit, "Wristband", Vector3.new(arm.Size.X + 0.14, 0.22, arm.Size.Z + 0.14), C.Green, CFrame.new(0, -arm.Size.Y / 2 + 0.14, 0))
			end
		end
	end
	-- Yellow trousers, gold heart knee pads.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.Jacket, CFrame.new())
			if name:find("Lower") or name == "Left Leg" or name == "Right Leg" then
				local ky = name:find("Lower") and ls.Y / 2 - 0.15 or 0
				heart(leg, outfit, CFrame.new(0, ky, -ls.Z / 2 - 0.06), 0.55)
				piece(leg, outfit, "BootTop", Vector3.new(ls.X + 0.14, 0.14, ls.Z + 0.14), C.Green, CFrame.new(0, -ls.Y / 2 + 0.4, 0))
				piece(leg, outfit, "Boot", Vector3.new(ls.X + 0.1, 0.4, ls.Z + 0.1), C.Jacket, CFrame.new(0, -ls.Y / 2 + 0.2, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "BootFoot", foot.Size + Vector3.new(0.1, 0.04, 0.16), C.Jacket, CFrame.new(0, 0, -0.04))
			piece(foot, outfit, "BootSole", Vector3.new(foot.Size.X + 0.12, 0.08, foot.Size.Z + 0.18), C.Green, CFrame.new(0, -foot.Size.Y / 2, -0.04))
		end
	end
end

function DioOutfit.apply(character)
	if character:FindFirstChild("DioOutfit") then
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
	outfit.Name = "DioOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function DioOutfit.remove(character)
	local outfit = character:FindFirstChild("DioOutfit")
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
		if character:GetAttribute("TuskAct") == DioOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == DioOutfit.Act then
					DioOutfit.apply(character)
				end
			end)
		else
			DioOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function DioOutfit.init()
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

return DioOutfit
end
end
