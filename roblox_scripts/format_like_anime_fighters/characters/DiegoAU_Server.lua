--[[
	DiegoAU_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Diego Brando from another world: The World.
	Its other half is DiegoAU_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: DiegoAU
-- ======================================================================
__modules["DiegoAU"] = function()
--[[
	DiegoAU  (ServerScriptService.SpinServer.TuskActs.DiegoAU)

	Diego Brando from another world (AU): THE WORLD. Registered as "Act" 14
	so it reuses the Tusk ability system.
	  M1        MUDA COMBO: The World punches with him
	  Ability 1 STAND GRAB: The World lunges out, grabs the nearest enemy in
	            front, lifts them up and hurls them the way he's aiming;
	            whoever they crash into is hit too
	  Ability 2 STAND BARRAGE: The World rushes ahead of him with a storm of
	            punches (he can still walk, slowly); a last big punch sends
	            them flying
	  Ability 3 KNIFE THROW: three knives at once, fanned out. Thrown while
	            time is stopped, they stop in mid-air a few studs out and all
	            fly the moment time moves again
	  Ultimate  THE WORLD: TIME STOP: everyone else nearby freezes for about
	            6 seconds (can't move, act, block or dodge) while Diego moves
	            freely. Time stops early if he goes down
	Numbers: TuskConfig.DiegoAU. All damage goes through S.hit (CombatAdapter).
	Frozen characters carry the "TimeStopped" attribute (CombatAdapter.canAct
	refuses them) and have their root anchored by the server.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local DiegoAU = {}
local cfg = TuskConfig.DiegoAU
local ACT = 14

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

function DiegoAU.M1(S, player, state, aim)
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

-- Nearest enemy (optionally only in a cone in front).
local function nearest(S, character, root, range, direction, cone)
	local look = direction and Moves.flat(direction)
	local cosLimit = cone and math.cos(math.rad(cone / 2))
	local best, bestD
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, range, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		local hum = target:FindFirstChildOfClass("Humanoid")
		if tr and hum and hum.Health > 0 and S.Adapter.canBeHit(nil, target) then
			local offset = tr.Position - root.Position
			local f = Vector3.new(offset.X, 0, offset.Z)
			if not look or f.Magnitude < 1 or f.Unit:Dot(look) >= cosLimit then
				if S.Hitbox.lineOfSight(root.Position, tr.Position, { character, target }) then
					if not bestD or offset.Magnitude < bestD then
						best, bestD = target, offset.Magnitude
					end
				end
			end
		end
	end
	return best
end

local stops = setmetatable({}, { __mode = "k" }) -- [character] = the time stop he's holding

---------------------------------------------------------------------------
-- STAND GRAB: grab, lift, throw
---------------------------------------------------------------------------
local function standGrab(S, player, state, aim)
	local c = cfg.StandGrab
	if not ready(S, player, state, "StandGrab", 1) then
		return
	end
	S.startCooldown(player, state, "StandGrab", c.Cooldown, 1)
	S.lock(state, c.Windup + c.HoldTime + 0.25)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "StandGrab", Phase = "Reach", Direction = direction, Windup = c.Windup, Range = c.Range })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local target = nearest(S, char, r, c.Range, direction, c.Cone)
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		if not tr or not S.hit(player, target, { Damage = c.GrabDamage, Stun = c.Stun, Knockback = 0, Direction = direction, Position = tr.Position, Source = "DiegoAUGrab" }) then
			S.startCooldown(player, state, "StandGrab", c.MissCooldown, 1)
			S.fx("Ability", { Character = char, Act = ACT, Move = "StandGrab", Phase = "Miss", Direction = direction })
			return
		end
		-- Lifted up in front of Diego, held there.
		pin(tr)
		S.fx("Ability", { Character = char, Act = ACT, Move = "StandGrab", Phase = "Hold", Target = target, Duration = c.HoldTime })
		local started = now()
		local function hold()
			local _, _, myRoot = alive(S, player)
			if not tr.Parent or not myRoot or not S.stillValid(player, state, life) then
				-- Diego was knocked out of it: they drop.
				unpin(tr)
				S.fx("Ability", { Act = ACT, Move = "StandGrab", Phase = "Drop", Character = character, Target = target })
				return
			end
			if now() - started < c.HoldTime then
				local lift = math.min((now() - started) / c.HoldTime, 1)
				local at = (myRoot.CFrame * CFrame.new(0, 1.5 + lift * 2, -4.5)).Position
				tr.CFrame = CFrame.lookAt(at, myRoot.Position + Vector3.new(0, 1.5 + lift * 2, 0))
				task.delay(0.03, hold)
				return
			end
			-- Hurled the way he's aiming now.
			local throwDir = Moves.flat(myRoot.CFrame.LookVector)
			unpin(tr)
			S.hit(player, target, { Damage = c.ThrowDamage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = throwDir, Position = tr.Position, Source = "DiegoAUThrow" })
			S.fx("Ability", { Character = char, Act = ACT, Move = "StandGrab", Phase = "Throw", Target = target, Direction = throwDir, Position = tr.Position })
			-- Whoever they crash into gets hit too.
			task.delay(c.SplashDelay, function()
				if tr.Parent then
					Moves.aoe(S, player, tr.Position, c.SplashRadius, { Damage = c.SplashDamage, Stun = 0.5, Knockback = 25, Source = "DiegoAUThrow" }, 5, { [target] = true })
					S.fx("Ability", { Act = ACT, Move = "StandGrab", Phase = "Crash", Position = tr.Position, Radius = c.SplashRadius })
				end
			end)
		end
		hold()
	end)
end

---------------------------------------------------------------------------
-- STAND BARRAGE
---------------------------------------------------------------------------
local function standBarrage(S, player, state, aim)
	local c = cfg.StandBarrage
	if not ready(S, player, state, "StandBarrage", 2) then
		return
	end
	S.startCooldown(player, state, "StandBarrage", c.Cooldown, 2)
	S.lock(state, c.Windup + c.Duration + 0.15)
	local character, humanoid = alive(S, player)
	local life = state.Life
	local untilT = now() + c.Windup + c.Duration
	character:SetAttribute("WorldBarrageUntil", untilT)
	S.Adapter.setMoveModifier(humanoid, "WorldBarrage", c.WalkMultiplier)
	S.fx("Ability", { Character = character, Act = ACT, Move = "StandBarrage", Phase = "Start", Windup = c.Windup, Duration = c.Duration })
	local ticks = math.max(1, math.floor(c.Duration / c.Tick))
	local function stop()
		if humanoid.Parent then
			S.Adapter.setMoveModifier(humanoid, "WorldBarrage", nil)
		end
		if character.Parent and character:GetAttribute("WorldBarrageUntil") == untilT then
			character:SetAttribute("WorldBarrageUntil", nil)
		end
	end
	for i = 1, ticks do
		task.delay(c.Windup + (i - 1) * c.Tick, function()
			if character:GetAttribute("WorldBarrageUntil") ~= untilT then
				return -- already over
			end
			if not S.stillValid(player, state, life) then
				-- Stunned (or gone) out of it: The World goes back.
				stop()
				S.fx("Ability", { Character = character, Act = ACT, Move = "StandBarrage", Phase = "Stop" })
				return
			end
			local _, _, r = alive(S, player)
			local boxCF = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
			local last = i == ticks
			if last then
				Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.FinalDamage, Stun = c.FinalStun, Knockback = c.FinalKnockback, Launch = c.FinalLaunch, Direction = r.CFrame.LookVector, Source = "DiegoAUBarrage" }, c.MaxTargets)
				S.fx("Ability", { Character = character, Act = ACT, Move = "StandBarrage", Phase = "Finish", Position = boxCF.Position })
				stop()
			else
				local count = Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = r.CFrame.LookVector, Source = "DiegoAUBarrage" }, c.MaxTargets)
				if count > 0 and i % 2 == 0 then
					S.fx("Ability", { Act = ACT, Move = "StandBarrage", Phase = "Hit", Position = boxCF.Position })
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- KNIFE THROW
---------------------------------------------------------------------------
local nextKnife = 0

local function throwKnife(S, player, state, origin, direction, source)
	local c = cfg.KnifeThrow
	return S.fireKnife(player, state, {
		Origin = origin,
		Direction = direction,
		Speed = c.Speed,
		Radius = c.Radius,
		Range = c.Range,
		OnHit = function(target, position)
			S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = direction, Position = position, Source = source or "DiegoAUKnife" })
		end,
	})
end
DiegoAU.throwKnife = throwKnife

-- The fan of directions (rotated round the vertical) for `count` knives.
local function fan(direction, count, spread)
	local list = {}
	for i = 1, count do
		local angle = math.rad((i - (count + 1) / 2) * spread)
		table.insert(list, (CFrame.Angles(0, angle, 0) * CFrame.new(Vector3.zero, direction)).LookVector)
	end
	return list
end

local function knifeThrow(S, player, state, aim)
	local c = cfg.KnifeThrow
	if not ready(S, player, state, "KnifeThrow", 3) then
		return
	end
	S.startCooldown(player, state, "KnifeThrow", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local character, _, root = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "KnifeThrow", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local direction = S.aim(aim, r)
		local origin = S.origin(char, r, Moves.HAND)
		local stop = stops[char]
		S.fx("Ability", { Character = char, Act = ACT, Move = "KnifeThrow", Phase = "Throw", Direction = direction })
		for _, dir in ipairs(fan(direction, c.Count, c.Spread)) do
			if stop then
				-- Time is stopped: the knife stops a few studs out and waits.
				nextKnife = nextKnife + 1
				local at = origin + dir * c.HangDistance
				table.insert(stop.Knives, { Id = nextKnife, Origin = at, Direction = dir })
				S.fx("Ability", { Act = ACT, Move = "KnifeThrow", Phase = "Hang", Id = nextKnife, From = origin, Position = at, Direction = dir })
			else
				throwKnife(S, player, state, origin, dir)
			end
		end
	end)
end

function DiegoAU.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		standGrab(S, player, state, aim)
	elseif slot == 2 then
		standBarrage(S, player, state, aim)
	elseif slot == 3 then
		knifeThrow(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- THE WORLD: TIME STOP (ultimate)
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
	local ids = {}
	for _, k in ipairs(stop.Knives) do
		table.insert(ids, k.Id)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Resume", Position = root and root.Position, Knives = ids })
	-- Every knife he left hanging flies now.
	if stop.Player and stop.State then
		for _, k in ipairs(stop.Knives) do
			throwKnife(S, stop.Player, stop.State, k.Origin, k.Direction)
		end
	end
end

function DiegoAU.Ultimate(S, player, state, aim)
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
		local frozen = {}
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, u.Range, 40)) do
			local hum = target:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and target ~= char and freeze(target) then
				table.insert(frozen, target)
			end
		end
		stops[char] = { Token = token, Frozen = frozen, Knives = {}, Player = player, State = state }
		char:SetAttribute("TimeStopper", now() + duration)
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Stop", Position = r.Position, Range = u.Range, Duration = duration, Frozen = frozen })
		task.delay(duration, function()
			resume(S, char, token)
		end)
	end)
end

function DiegoAU.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("WorldBarrageUntil", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "WorldBarrage", nil)
		end
		-- He went down (or switched): time moves again.
		local stop = stops[character]
		if stop then
			stop.Player, stop.State = nil, nil -- hanging knives just fall
			resume(S, character, stop.Token)
		end
	end
end

return DiegoAU
end

-- ======================================================================
-- MODULE: DiegoAUOutfit
-- ======================================================================
__modules["DiegoAUOutfit"] = function()
--[[
	DiegoAUOutfit  (ServerScriptService.SpinServer.DiegoAUOutfit)

	Gives a character the look of Diego Brando from another world while
	they play him (TuskAct 14), built from blocky parts (no catalog asset
	ids), matched to his art:
	  * a teal jockey cap with a dark brim and "DIO" on the front
	  * blond hair to the jaw, a long lock falling over one eye
	  * a teal turtleneck sweater, quilted in a dark diamond lattice, with a
	    thick rolled neck
	  * brown leather gloves with cuffs
	  * khaki riding trousers with a dark belt and buckle
	  * tall dark-brown riding boots with silver spurs
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local DiegoAUOutfit = {}
DiegoAUOutfit.Act = 14

local C = {
	Hair = Color3.fromRGB(236, 206, 120),
	HairDark = Color3.fromRGB(196, 160, 80),
	Cap = Color3.fromRGB(96, 184, 176),
	CapDark = Color3.fromRGB(40, 104, 104),
	Sweater = Color3.fromRGB(112, 204, 188),
	SweaterShade = Color3.fromRGB(84, 170, 158),
	Lattice = Color3.fromRGB(36, 96, 92),
	Glove = Color3.fromRGB(128, 80, 44),
	GloveDark = Color3.fromRGB(92, 56, 30),
	Pants = Color3.fromRGB(198, 172, 112),
	PantsShade = Color3.fromRGB(168, 142, 88),
	Belt = Color3.fromRGB(70, 46, 30),
	Buckle = Color3.fromRGB(200, 196, 180),
	Boot = Color3.fromRGB(78, 52, 36),
	BootDark = Color3.fromRGB(52, 34, 24),
	Spur = Color3.fromRGB(200, 204, 212),
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

-- The dark diamond lattice of the quilted sweater on one flat face (w x h,
-- centred on cf): two sets of diagonal lines, each clipped to the face.
local function lattice(part, outfit, w, h, cf)
	local step = 0.6
	local hw, hh = w / 2, h / 2
	local n = math.ceil((w + h) / step)
	for i = -n, n do
		local c = i * step
		-- x - y = c (rising lines) and x + y = c (falling lines).
		for _, rising in ipairs({ true, false }) do
			local x0, x1
			if rising then
				x0, x1 = math.max(-hw, c - hh), math.min(hw, c + hh)
			else
				x0, x1 = math.max(-hw, c - hh), math.min(hw, c + hh)
			end
			if x1 - x0 > 0.08 then
				local x = (x0 + x1) / 2
				local y = rising and (x - c) or (c - x)
				local len = (x1 - x0) * math.sqrt(2)
				piece(part, outfit, "Lattice", Vector3.new(0.05, len, 0.03), C.Lattice, cf * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, rising and -0.785 or 0.785))
			end
		end
	end
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Blond hair: over the ears down to the jaw, longer at the back, a lock over one eye.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.16 * s, 0.3 * s, head.Size.Z + 0.16 * s), C.Hair, CFrame.new(0, h - 0.1 * s, 0.02 * s))
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.24 * s, 1.0 * s, 0.24 * s), C.Hair, CFrame.new(0, -0.15 * s, d + 0.08 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.18 * s, 1.0 * s, head.Size.Z * 0.9), C.Hair, CFrame.new(side * (w + 0.06 * s), -0.12 * s, 0.05 * s))
		piece(head, outfit, "HairTip", Vector3.new(0.16 * s, 0.3 * s, 0.3 * s), C.HairDark, CFrame.new(side * (w + 0.1 * s), -0.66 * s, 0.25 * s) * CFrame.Angles(0, 0, side * 0.3))
	end
	-- The lock over his left eye.
	piece(head, outfit, "Lock", Vector3.new(0.34 * s, 0.85 * s, 0.1 * s), C.Hair, CFrame.new(-0.2 * s, 0.05 * s, -d - 0.04 * s) * CFrame.Angles(0, 0, -0.25))
	piece(head, outfit, "LockShade", Vector3.new(0.1 * s, 0.7 * s, 0.11 * s), C.HairDark, CFrame.new(-0.08 * s, 0.02 * s, -d - 0.05 * s) * CFrame.Angles(0, 0, -0.25))
	-- Teal jockey cap: a rounded crown, a dark band and a short brim.
	piece(head, outfit, "Cap", Vector3.new(head.Size.X + 0.2 * s, 0.5 * s, head.Size.Z + 0.2 * s), C.Cap, CFrame.new(0, h + 0.12 * s, 0.02 * s))
	piece(head, outfit, "CapTop", Vector3.new(head.Size.X * 0.8, 0.16 * s, head.Size.Z * 0.8), C.Cap, CFrame.new(0, h + 0.42 * s, 0.04 * s))
	piece(head, outfit, "CapBand", Vector3.new(head.Size.X + 0.24 * s, 0.1 * s, head.Size.Z + 0.24 * s), C.CapDark, CFrame.new(0, h - 0.1 * s, 0.02 * s))
	piece(head, outfit, "Brim", Vector3.new(head.Size.X + 0.1 * s, 0.08 * s, 0.5 * s), C.CapDark, CFrame.new(0, h - 0.12 * s, -d - 0.22 * s) * CFrame.Angles(-0.12, 0, 0))
	-- "DIO" on the front of the cap.
	local plate = piece(head, outfit, "CapPlate", Vector3.new(head.Size.X * 0.9, 0.36 * s, 0.04), C.Cap, CFrame.new(0, h + 0.14 * s, -d - 0.12 * s))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.6
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bodoni
	label.TextScaled = true
	label.Text = "DIO"
	label.TextColor3 = C.Lattice
	label.TextStrokeColor3 = Color3.fromRGB(220, 250, 245)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = plate
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Sweater", s + Vector3.new(0.1, 0.02, 0.1), C.Sweater, CFrame.new())
		lattice(upper, outfit, s.X, s.Y, CFrame.new(0, 0, front - 0.06))
		lattice(upper, outfit, s.X, s.Y, CFrame.new(0, 0, -front + 0.06))
		-- Thick rolled turtleneck.
		piece(upper, outfit, "Turtleneck", Vector3.new(s.X * 0.55, 0.5, s.Z * 0.85), C.SweaterShade, CFrame.new(0, top + 0.2, 0))
		piece(upper, outfit, "NeckRoll", Vector3.new(s.X * 0.6, 0.16, s.Z * 0.9), C.Sweater, CFrame.new(0, top + 0.34, 0))
	end
	-- Khaki trousers with a dark belt and a buckle.
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.3
		if lower then
			piece(lower, outfit, "Pants", ws + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
		else
			piece(upper, outfit, "SweaterHem", Vector3.new(upper.Size.X + 0.12, 0.2, upper.Size.Z + 0.12), C.SweaterShade, CFrame.new(0, waistTop + 0.1, 0))
		end
		piece(waist, outfit, "Belt", Vector3.new(ws.X + 0.1, 0.18, ws.Z + 0.1), C.Belt, CFrame.new(0, waistTop - 0.12, 0))
		piece(waist, outfit, "Buckle", Vector3.new(0.34, 0.22, 0.06), C.Buckle, CFrame.new(0, waistTop - 0.12, -ws.Z / 2 - 0.08))
	end
	-- Quilted sleeves with a ribbed cuff.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local tall = as.Y > 1.8
			local h = tall and as.Y - 0.3 or as.Y
			piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.1, h + 0.02, as.Z + 0.1), C.Sweater, CFrame.new(0, as.Y / 2 - h / 2, 0))
			local side = name:find("Left") and -1 or 1
			local cy = as.Y / 2 - h / 2
			lattice(arm, outfit, as.X, h, CFrame.new(0, cy, -as.Z / 2 - 0.07))
			lattice(arm, outfit, as.Z, h, CFrame.new(side * (as.X / 2 + 0.07), cy, 0) * CFrame.Angles(0, math.pi / 2, 0))
			if name:find("Lower") or tall then
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.16, 0.22, as.Z + 0.16), C.SweaterShade, CFrame.new(0, as.Y / 2 - h + 0.08, 0))
			end
		end
	end
	-- Brown leather gloves (R15 hands; on R6 the bottom of the arm).
	for _, name in ipairs({ "LeftHand", "RightHand" }) do
		local hand = character:FindFirstChild(name)
		if hand then
			piece(hand, outfit, "Glove", hand.Size + Vector3.new(0.08, 0.06, 0.08), C.Glove, CFrame.new())
			piece(hand, outfit, "GloveCuff", Vector3.new(hand.Size.X + 0.16, 0.16, hand.Size.Z + 0.16), C.GloveDark, CFrame.new(0, hand.Size.Y / 2, 0))
		end
	end
	for _, name in ipairs({ "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Glove", Vector3.new(arm.Size.X + 0.12, 0.32, arm.Size.Z + 0.12), C.Glove, CFrame.new(0, -arm.Size.Y / 2 + 0.15, 0))
		end
	end
	-- Khaki trousers into tall riding boots with spurs.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Pants", ls + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
			piece(leg, outfit, "Crease", Vector3.new(0.05, ls.Y * 0.8, 0.05), C.PantsShade, CFrame.new(0, 0, -ls.Z / 2 - 0.04))
			if name:find("Lower") or ls.Y > 1.8 then
				local bh = ls.Y > 1.8 and 1.2 or ls.Y + 0.05
				piece(leg, outfit, "Boot", Vector3.new(ls.X + 0.14, bh, ls.Z + 0.14), C.Boot, CFrame.new(0, -ls.Y / 2 + bh / 2, 0))
				piece(leg, outfit, "BootTop", Vector3.new(ls.X + 0.2, 0.16, ls.Z + 0.2), C.BootDark, CFrame.new(0, -ls.Y / 2 + bh, 0))
				if ls.Y > 1.8 then
					piece(leg, outfit, "Spur", Vector3.new(0.08, 0.08, 0.36), C.Spur, CFrame.new(0, -ls.Y / 2 + 0.25, ls.Z / 2 + 0.2))
					piece(leg, outfit, "SpurWheel", Vector3.new(0.06, 0.2, 0.2), C.Spur, CFrame.new(0, -ls.Y / 2 + 0.25, ls.Z / 2 + 0.4))
				end
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			local fs = foot.Size
			piece(foot, outfit, "Boot", fs + Vector3.new(0.1, 0.06, 0.14), C.BootDark, CFrame.new(0, 0, -0.03))
			piece(foot, outfit, "Spur", Vector3.new(0.08, 0.08, 0.34), C.Spur, CFrame.new(0, 0, fs.Z / 2 + 0.16))
			piece(foot, outfit, "SpurWheel", Vector3.new(0.06, 0.2, 0.2), C.Spur, CFrame.new(0, 0, fs.Z / 2 + 0.36))
		end
	end
end

function DiegoAUOutfit.apply(character)
	if character:FindFirstChild("DiegoAUOutfit") then
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
	outfit.Name = "DiegoAUOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function DiegoAUOutfit.remove(character)
	local outfit = character:FindFirstChild("DiegoAUOutfit")
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
		if character:GetAttribute("TuskAct") == DiegoAUOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == DiegoAUOutfit.Act then
					DiegoAUOutfit.apply(character)
				end
			end)
		else
			DiegoAUOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function DiegoAUOutfit.init()
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

return DiegoAUOutfit
end
end
