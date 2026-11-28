--[[
	Jotaro_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Jotaro Kujo: Star Platinum (and its time stop).
	Its other half is Jotaro_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "jotaro" or __expect.Side ~= "server") then
		error("this is the code for Jotaro_Server, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Jotaro_Server and put it in ServerScriptService > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: Jotaro
-- ======================================================================
__modules["Jotaro"] = function()
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

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

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
end

-- ======================================================================
-- MODULE: JotaroOutfit
-- ======================================================================
__modules["JotaroOutfit"] = function()
--[[
	JotaroOutfit  (ServerScriptService.SpinServer.JotaroOutfit)

	Gives a character the look of Jotaro Kujo while they play him
	(TuskAct 20), built from blocky parts (no catalog asset ids), matched
	to his art:
	  * his black CAP: a dark crown and visor, a gold button and the gold
	    hand-shaped badge on the front, and his black hair running into
	    the back of it in jagged spikes
	  * a long black GAKURAN coat: a tall stand-up collar with gold buttons,
	    hanging open over a grey-green shirt; gold buttons down the front
	    and on the cuffs; long tails flaring out to his knees
	  * the gold CHAIN hanging from his left collar
	  * two belts: a plain one and one with a red / white / teal pattern
	  * black trousers and black loafers
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local JotaroOutfit = {}
JotaroOutfit.Act = 20

local C = {
	Coat = Color3.fromRGB(36, 36, 42),
	CoatShade = Color3.fromRGB(22, 22, 26),
	CoatLight = Color3.fromRGB(58, 58, 66),
	Lining = Color3.fromRGB(214, 200, 150),
	Shirt = Color3.fromRGB(112, 122, 100),
	ShirtShade = Color3.fromRGB(86, 96, 78),
	Gold = Color3.fromRGB(232, 186, 70),
	GoldShade = Color3.fromRGB(184, 140, 44),
	Hair = Color3.fromRGB(26, 24, 30),
	Belt = Color3.fromRGB(46, 40, 36),
	Red = Color3.fromRGB(196, 56, 46),
	Teal = Color3.fromRGB(70, 170, 160),
	White = Color3.fromRGB(236, 230, 214),
	Shoe = Color3.fromRGB(18, 18, 22),
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
	-- Hair at the sides and back, spiking out behind the cap.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Sideburn", Vector3.new(0.1 * s, 0.55 * s, head.Size.Z * 0.6), C.Hair, CFrame.new(side * (w + 0.03 * s), h - 0.45 * s, 0.12 * s))
	end
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.1 * s, 0.7 * s, 0.2 * s), C.Hair, CFrame.new(0, h - 0.35 * s, d + 0.06 * s))
	for k = -2, 2 do
		piece(head, outfit, "Spike", Vector3.new(0.22 * s, 0.6 * s, 0.18 * s), C.Hair, CFrame.new(k * 0.24 * s, h - 0.05 * s, d + 0.22 * s) * CFrame.Angles(math.rad(55 + math.abs(k) * 8), 0, math.rad(k * 14)))
	end
	-- The cap: a tall dark crown, a visor out front.
	piece(head, outfit, "Cap", Vector3.new(head.Size.X + 0.16 * s, 0.5 * s, head.Size.Z + 0.16 * s), C.Coat, CFrame.new(0, h + 0.12 * s, 0))
	piece(head, outfit, "CapTop", Vector3.new(head.Size.X + 0.24 * s, 0.12 * s, head.Size.Z + 0.3 * s), C.CoatLight, CFrame.new(0, h + 0.4 * s, -0.04 * s))
	piece(head, outfit, "CapBand", Vector3.new(head.Size.X + 0.18 * s, 0.1 * s, head.Size.Z + 0.18 * s), C.CoatShade, CFrame.new(0, h - 0.08 * s, 0))
	piece(head, outfit, "Visor", Vector3.new(head.Size.X + 0.1 * s, 0.08 * s, 0.45 * s), C.CoatShade, CFrame.new(0, h - 0.12 * s, -d - 0.2 * s) * CFrame.Angles(math.rad(-12), 0, 0))
	piece(head, outfit, "VisorEdge", Vector3.new(head.Size.X + 0.12 * s, 0.05 * s, 0.06 * s), C.Gold, CFrame.new(0, h - 0.07 * s, -d - 0.02 * s))
	-- The gold button and the hand-shaped badge.
	local button = piece(head, outfit, "CapButton", Vector3.new(0.06 * s, 0.24 * s, 0.24 * s), C.Gold, CFrame.new(-0.18 * s, h + 0.15 * s, -d - 0.1 * s) * CFrame.Angles(0, math.pi / 2, 0))
	button.Shape = Enum.PartType.Cylinder
	piece(head, outfit, "Badge", Vector3.new(0.2 * s, 0.26 * s, 0.05 * s), C.Gold, CFrame.new(0.2 * s, h + 0.15 * s, -d - 0.1 * s))
	for f = 0, 2 do
		piece(head, outfit, "BadgeFinger", Vector3.new(0.04 * s, 0.1 * s, 0.05 * s), C.GoldShade, CFrame.new((0.14 + f * 0.05) * s, h + 0.31 * s, -d - 0.1 * s))
	end
	-- Heavy brows.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Brow", Vector3.new(0.3 * s, 0.07 * s, 0.05 * s), C.Hair, CFrame.new(side * 0.22 * s, 0.12 * s, -d - 0.02 * s) * CFrame.Angles(0, 0, side * 0.15))
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Coat", s + Vector3.new(0.12, 0.02, 0.12), C.Coat, CFrame.new())
		-- Hanging open over the grey-green shirt.
		piece(upper, outfit, "Shirt", Vector3.new(0.62, s.Y - 0.1, 0.04), C.Shirt, CFrame.new(-0.05, -0.05, front - 0.07))
		for k = 0, 3 do
			piece(upper, outfit, "ShirtFold", Vector3.new(0.5, 0.03, 0.045), C.ShirtShade, CFrame.new(-0.05, top - 0.35 - k * 0.3, front - 0.075))
		end
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Lapel", Vector3.new(0.22, s.Y - 0.05, 0.06), C.CoatLight, CFrame.new(side * 0.42 - 0.05, -0.02, front - 0.08) * CFrame.Angles(0, 0, side * 0.05))
			piece(upper, outfit, "LiningEdge", Vector3.new(0.04, s.Y - 0.1, 0.065), C.Lining, CFrame.new(side * 0.31 - 0.05, -0.02, front - 0.085))
		end
		-- Gold buttons down the right edge.
		for k = 0, 3 do
			local b = piece(upper, outfit, "Button", Vector3.new(0.05, 0.13, 0.13), C.Gold, CFrame.new(0.55, top - 0.3 - k * 0.36, front - 0.12) * CFrame.Angles(0, math.pi / 2, 0))
			b.Shape = Enum.PartType.Cylinder
		end
		-- The tall stand-up collar, gold buttons at its corners.
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.75, 0.6, 0.18), C.Coat, CFrame.new(0, top + 0.28, -front + 0.0))
		for _, side in ipairs({ -1, 1 }) do
			local cf = CFrame.new(side * s.X * 0.33, top + 0.28, -0.05) * CFrame.Angles(0, side * -0.3, 0)
			piece(upper, outfit, "CollarSide", Vector3.new(0.16, 0.6, s.Z * 0.95), C.Coat, cf)
			local b = piece(upper, outfit, "CollarButton", Vector3.new(0.05, 0.14, 0.14), C.Gold, cf * CFrame.new(0, 0.12, -s.Z * 0.48) * CFrame.Angles(0, math.pi / 2, 0))
			b.Shape = Enum.PartType.Cylinder
		end
		-- The gold chain from his left collar, swinging down and back up.
		local a = Vector3.new(-s.X * 0.36, top + 0.2, front - 0.1)
		local pts = { a, a + Vector3.new(0.05, -0.35, -0.02), a + Vector3.new(0.18, -0.6, -0.03), a + Vector3.new(0.35, -0.7, -0.03), a + Vector3.new(0.5, -0.55, -0.02) }
		for i = 1, #pts - 1 do
			local mid = (pts[i] + pts[i + 1]) / 2
			for k = 0, 1 do
				local link = piece(upper, outfit, "Chain", Vector3.new(0.04, 0.12, 0.08), C.Gold, CFrame.lookAt(pts[i]:Lerp(pts[i + 1], 0.25 + k * 0.5), mid + (pts[i + 1] - pts[i])) * CFrame.Angles(0, 0, k * math.pi / 2))
				link.Material = Enum.Material.Metal
			end
		end
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.Coat, CFrame.new())
		-- Two belts: one plain, one patterned (red / white / teal).
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.16, 0.14, ls.Z + 0.16), C.Belt, CFrame.new(0, ls.Y / 2 - 0.06, 0))
		local pattern = piece(lower, outfit, "BeltPattern", Vector3.new(ls.X + 0.2, 0.14, ls.Z + 0.2), C.White, CFrame.new(0, ls.Y / 2 - 0.22, 0) * CFrame.Angles(0, 0, -0.06))
		pattern.Name = "BeltPattern"
		for k = -4, 4 do
			piece(lower, outfit, "Zig", Vector3.new(0.12, 0.12, 0.04), k % 2 == 0 and C.Red or C.Teal, CFrame.new(k * 0.2, ls.Y / 2 - 0.22 - k * 0.012, -ls.Z / 2 - 0.11) * CFrame.Angles(0, 0, math.pi / 4))
		end
		-- Long coat tails: sides and back, flaring out down to the knees.
		piece(lower, outfit, "TailBack", Vector3.new(ls.X + 0.2, 2.4, 0.1), C.Coat, CFrame.new(0, -1.2, ls.Z / 2 + 0.18) * CFrame.Angles(math.rad(10), 0, 0))
		piece(lower, outfit, "TailLining", Vector3.new(ls.X, 2.2, 0.04), C.Lining, CFrame.new(0, -1.15, ls.Z / 2 + 0.11) * CFrame.Angles(math.rad(10), 0, 0))
		for _, side in ipairs({ -1, 1 }) do
			piece(lower, outfit, "TailSide", Vector3.new(0.1, 2.3, ls.Z + 0.3), C.Coat, CFrame.new(side * (ls.X / 2 + 0.16), -1.15, 0.05) * CFrame.Angles(0, 0, side * -0.14))
			piece(lower, outfit, "TailFront", Vector3.new(0.4, 2.2, 0.1), C.Coat, CFrame.new(side * (ls.X / 2 - 0.1), -1.1, -ls.Z / 2 - 0.12) * CFrame.Angles(math.rad(-6), 0, side * -0.12))
		end
	end
	-- Long black sleeves, gold buttons at the cuffs.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			piece(arm, outfit, "Sleeve", as + Vector3.new(0.1, 0.02, 0.1), C.Coat, CFrame.new())
			if name:find("Lower") or name == "Left Arm" or name == "Right Arm" then
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.14, 0.2, as.Z + 0.14), C.CoatShade, CFrame.new(0, -as.Y / 2 + 0.12, 0))
				for k = 0, 1 do
					local b = piece(arm, outfit, "CuffButton", Vector3.new(0.04, 0.1, 0.1), C.Gold, CFrame.new((name:find("Left") and -1 or 1) * (as.X / 2 + 0.08), -as.Y / 2 + 0.2 + k * 0.16, 0.2) * CFrame.Angles(0, 0, 0))
					b.Shape = Enum.PartType.Cylinder
				end
			end
		end
	end
	-- Black trousers, black loafers.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Trousers", leg.Size + Vector3.new(0.06, 0.02, 0.06), C.Coat, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			local fs = foot.Size
			piece(foot, outfit, "Loafer", fs + Vector3.new(0.08, 0.04, 0.16), C.Shoe, CFrame.new(0, 0, -0.04))
			piece(foot, outfit, "LoaferStrap", Vector3.new(fs.X + 0.1, 0.06, 0.1), C.CoatLight, CFrame.new(0, fs.Y / 2, -fs.Z / 2 + 0.1))
		end
	end
end

function JotaroOutfit.apply(character)
	if character:FindFirstChild("JotaroOutfit") then
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
	outfit.Name = "JotaroOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function JotaroOutfit.remove(character)
	local outfit = character:FindFirstChild("JotaroOutfit")
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
		if character:GetAttribute("TuskAct") == JotaroOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == JotaroOutfit.Act then
					JotaroOutfit.apply(character)
				end
			end)
		else
			JotaroOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function JotaroOutfit.init()
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

return JotaroOutfit
end
end
