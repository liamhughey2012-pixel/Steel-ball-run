--[[
	Josuke_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Josuke Higashikata (JoJolion): Soft & Wet.
	Its other half is Josuke_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "josuke" or __expect.Side ~= "server") then
		error("this is the code for Josuke_Server, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Josuke_Server and put it in ServerScriptService > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: Josuke
-- ======================================================================
__modules["Josuke"] = function()
--[[
	Josuke  (ServerScriptService.SpinServer.TuskActs.Josuke)

	Josuke Higashikata (JoJolion): SOFT & WET. Its plunder bubbles steal
	something from whatever they pop on. Registered as "Act" 15 so it reuses
	the Tusk ability system.
	  M1        SOFT & WET COMBO: Soft & Wet punches with him
	  Ability 1 PLUNDER: FRICTION: a bubble that steals their friction: the
	            pop shoves them and they slide about like on ice for a few
	            seconds (they can barely change direction)
	  Ability 2 PLUNDER: SIGHT: a bubble that steals their sight: their
	            screen goes dark for a few seconds (NPCs lose track of you)
	  Ability 3 BUBBLE MINES: bubbles drift out round him and float there;
	            an enemy who touches one pops it (damage, stun)
	  Ultimate  GO BEYOND: a tiny bubble spinning infinitely, made of a
	            "nothing": slow, but it can't be blocked, and it hits hard
	Numbers: TuskConfig.Josuke. All damage goes through S.hit (CombatAdapter).
	Frictionless NPCs slide here on the server; players slide on their own
	client (JosukeVFX), which also darkens a blinded player's screen.
]]

local Players = game:GetService("Players")
local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Josuke = {}
local cfg = TuskConfig.Josuke
local ACT = 15

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

function Josuke.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- PLUNDER: FRICTION (NPCs slide on the server; players on their client)
---------------------------------------------------------------------------
local function slideNpc(target, untilT, grip)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	local root = target:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	local old = root:FindFirstChild("JosukeSlide")
	if old then
		old:Destroy()
	end
	-- A LinearVelocity takes over from the walk controller, so they only
	-- steer as fast as the stolen grip allows.
	local attach = Instance.new("Attachment")
	attach.Name = "JosukeSlideAttach"
	attach.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Name = "JosukeSlide"
	mover.Attachment0 = attach
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	mover.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	mover.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.MaxForce = 1e6
	local v0 = root.AssemblyLinearVelocity
	mover.PlaneVelocity = Vector2.new(v0.X, v0.Z)
	mover.Parent = root
	local step = 0.05
	local function tick()
		if not root.Parent or humanoid.Health <= 0 or now() >= untilT or target:GetAttribute("NoFrictionUntil") ~= untilT then
			mover:Destroy()
			attach:Destroy()
			return
		end
		local want = humanoid.MoveDirection * humanoid.WalkSpeed
		mover.PlaneVelocity = mover.PlaneVelocity:Lerp(Vector2.new(want.X, want.Z), math.clamp(grip * step, 0, 1))
		task.delay(step, tick)
	end
	tick()
end

local function plunderFriction(S, player, state, aim)
	local c = cfg.PlunderFriction
	if not ready(S, player, state, "PlunderFriction", 1) then
		return
	end
	S.startCooldown(player, state, "PlunderFriction", c.Cooldown, 1)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "PlunderFriction", Phase = "Blow", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local direction = S.aim(aim, r)
		S.fireBubble(player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Friction",
			OnHit = function(target, position)
				if S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = direction, Position = position, Source = "JosukeFriction" }) then
					local untilT = now() + c.Time
					target:SetAttribute("NoFrictionUntil", untilT)
					target:SetAttribute("NoFrictionGrip", c.Grip)
					S.fx("Ability", { Act = ACT, Move = "PlunderFriction", Phase = "Stolen", Target = target, Position = position, Duration = c.Time })
					if not Players:GetPlayerFromCharacter(target) then
						slideNpc(target, untilT, c.Grip)
					end
				end
			end,
		})
	end)
end

---------------------------------------------------------------------------
-- PLUNDER: SIGHT
---------------------------------------------------------------------------
local function plunderSight(S, player, state, aim)
	local c = cfg.PlunderSight
	if not ready(S, player, state, "PlunderSight", 2) then
		return
	end
	S.startCooldown(player, state, "PlunderSight", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "PlunderSight", Phase = "Blow", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local direction = S.aim(aim, r)
		S.fireBubble(player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Sight",
			OnHit = function(target, position)
				if S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 4, Direction = direction, Position = position, Source = "JosukeSight" }) then
					target:SetAttribute("BlindUntil", now() + c.Time)
					S.fx("Ability", { Act = ACT, Move = "PlunderSight", Phase = "Stolen", Target = target, Position = position, Duration = c.Time })
				end
			end,
		})
	end)
end

---------------------------------------------------------------------------
-- BUBBLE MINES
---------------------------------------------------------------------------
local nextMines = 0

local function bubbleMines(S, player, state)
	local c = cfg.BubbleMines
	if not ready(S, player, state, "BubbleMines", 3) then
		return
	end
	S.startCooldown(player, state, "BubbleMines", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local character, _, root = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "BubbleMines", Phase = "Blow", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life, true) then
			return
		end
		local char, _, r = alive(S, player)
		nextMines = nextMines + 1
		local id = nextMines
		local mines = {}
		local yaw = math.atan2(r.CFrame.LookVector.X, r.CFrame.LookVector.Z)
		for i = 1, c.Count do
			local a = yaw + (i - 1) / c.Count * math.pi * 2
			local dist = c.Spread * (0.6 + 0.4 * ((i % 2) + 0.5))
			table.insert(mines, { Pos = r.Position + Vector3.new(math.sin(a) * dist, 1 + (i % 3) * 0.8, math.cos(a) * dist), Alive = true })
		end
		local positions = {}
		for i, m in ipairs(mines) do
			positions[i] = m.Pos
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "BubbleMines", Phase = "Spawn", Id = id, From = r.Position, Positions = positions, Life = c.Life })
		local born = now()
		local function tick()
			local left = 0
			for i, m in ipairs(mines) do
				if m.Alive then
					left = left + 1
					local hits = S.Hitbox.inRadius(char, m.Pos, c.Trigger, 1)
					local target = hits[1]
					local tr = target and target:FindFirstChild("HumanoidRootPart")
					if tr then
						m.Alive = false
						S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = tr.Position - m.Pos, Position = m.Pos, Source = "JosukeMine" })
						S.fx("Ability", { Act = ACT, Move = "BubbleMines", Phase = "Pop", Id = id, Index = i, Position = m.Pos })
					end
				end
			end
			if left == 0 then
				return
			end
			if now() - born >= c.Life then
				S.fx("Ability", { Act = ACT, Move = "BubbleMines", Phase = "Fade", Id = id })
				return
			end
			task.delay(0.1, tick)
		end
		tick()
	end)
end

function Josuke.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		plunderFriction(S, player, state, aim)
	elseif slot == 2 then
		plunderSight(S, player, state, aim)
	elseif slot == 3 then
		bubbleMines(S, player, state)
	end
end

---------------------------------------------------------------------------
-- GO BEYOND (ultimate)
---------------------------------------------------------------------------
function Josuke.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.3)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Charge", Windup = u.Windup })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local char, _, r = alive(S, player)
		local direction = S.aim(aim, r)
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Release", Direction = direction })
		S.fireBubble(player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = u.Speed,
			Radius = u.Radius,
			Range = u.Range,
			Style = "GoBeyond",
			OnHit = function(target, position)
				S.hit(player, target, { Damage = u.Damage, Stun = u.Stun, Knockback = u.Knockback, Launch = u.Launch, Direction = direction, Position = position, Source = "JosukeGoBeyond", Unblockable = true })
				S.fx("Ultimate", { Act = ACT, Phase = "Impact", Position = position, Target = target })
			end,
		})
	end)
end

function Josuke.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
	end
end

return Josuke
end

-- ======================================================================
-- MODULE: JosukeOutfit
-- ======================================================================
__modules["JosukeOutfit"] = function()
--[[
	JosukeOutfit  (ServerScriptService.SpinServer.JosukeOutfit)

	Gives a character the look of Josuke Higashikata (JoJolion) while they
	play him (TuskAct 15), built from blocky parts (no catalog asset ids),
	matched to his art:
	  * a white sailor cap with navy stripes round the band and a little
	    capsule on top; short dark curly hair under it
	  * a white sailor top, cropped (his midriff shows), with the big square
	    sailor collar (navy stripes) hanging down his back and a V of
	    stripes at the front; a dark green neckerchief through a pink ring
	  * a teal anchor patch on the left of his chest, an orange badge with a
	    green star on the right; the star birthmark on his neck
	  * navy-striped cuffs, white trousers, a light-blue belt, gold buckle
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local JosukeOutfit = {}
JosukeOutfit.Act = 15

local C = {
	White = Color3.fromRGB(244, 244, 240),
	Shade = Color3.fromRGB(214, 216, 220),
	Navy = Color3.fromRGB(40, 70, 150),
	Hair = Color3.fromRGB(30, 44, 48),
	HairShine = Color3.fromRGB(50, 70, 76),
	Skin = Color3.fromRGB(214, 168, 130),
	Scarf = Color3.fromRGB(30, 90, 80),
	Ring = Color3.fromRGB(226, 150, 190),
	Teal = Color3.fromRGB(60, 160, 150),
	Badge = Color3.fromRGB(236, 150, 60),
	Star = Color3.fromRGB(50, 150, 80),
	Belt = Color3.fromRGB(120, 200, 220),
	Gold = Color3.fromRGB(220, 180, 70),
	Mark = Color3.fromRGB(200, 90, 110),
	Shoe = Color3.fromRGB(220, 220, 214),
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

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Short dark curly hair: a cap of hair with little curls at the sides and back.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.1 * s, 0.3 * s, head.Size.Z + 0.12 * s), C.Hair, CFrame.new(0, h - 0.12 * s, 0.03 * s))
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.12 * s, 0.7 * s, 0.14 * s), C.Hair, CFrame.new(0, 0.05 * s, d + 0.05 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Sideburn", Vector3.new(0.1 * s, 0.5 * s, 0.35 * s), C.Hair, CFrame.new(side * (w + 0.03 * s), 0.12 * s, 0.1 * s))
		for k = 0, 1 do
			piece(head, outfit, "Curl", Vector3.new(0.2 * s, 0.2 * s, 0.2 * s), k == 0 and C.HairShine or C.Hair, CFrame.new(side * (w + 0.05 * s), (0.3 - k * 0.25) * s, (0.3 + k * 0.15) * s))
		end
	end
	piece(head, outfit, "Fringe", Vector3.new(head.Size.X * 0.7, 0.16 * s, 0.1 * s), C.Hair, CFrame.new(0.05 * s, h - 0.3 * s, -d - 0.03 * s))
	-- White sailor cap: a round-ish crown, navy stripes round the band, a capsule on top.
	piece(head, outfit, "Cap", Vector3.new(head.Size.X + 0.22 * s, 0.45 * s, head.Size.Z + 0.22 * s), C.White, CFrame.new(0, h + 0.12 * s, 0))
	piece(head, outfit, "CapTop", Vector3.new(head.Size.X * 0.85, 0.16 * s, head.Size.Z * 0.85), C.White, CFrame.new(0, h + 0.4 * s, 0))
	for k = 0, 1 do
		piece(head, outfit, "CapStripe", Vector3.new(head.Size.X + 0.26 * s, 0.07 * s, head.Size.Z + 0.26 * s), C.Navy, CFrame.new(0, h + (0.02 + k * 0.16) * s, 0))
	end
	piece(head, outfit, "CapBrim", Vector3.new(head.Size.X + 0.3 * s, 0.08 * s, head.Size.Z + 0.3 * s), C.Shade, CFrame.new(0, h - 0.1 * s, 0))
	piece(head, outfit, "Capsule", Vector3.new(0.5 * s, 0.18 * s, 0.18 * s), C.Gold, CFrame.new(0.15 * s, h + 0.56 * s, -0.05 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front, back = s.Y / 2, -s.Z / 2, s.Z / 2
		-- Cropped white top: covers all but a band of midriff at the bottom.
		local crop = lower and 0.3 or 0.25
		local topH = s.Y - crop
		piece(upper, outfit, "Top", Vector3.new(s.X + 0.1, topH, s.Z + 0.1), C.White, CFrame.new(0, s.Y / 2 - topH / 2, 0))
		piece(upper, outfit, "Midriff", Vector3.new(s.X + 0.02, crop, s.Z + 0.02), C.Skin, CFrame.new(0, -s.Y / 2 + crop / 2, 0))
		piece(upper, outfit, "Hem", Vector3.new(s.X + 0.14, 0.12, s.Z + 0.14), C.Shade, CFrame.new(0, s.Y / 2 - topH, 0))
		-- The big square sailor collar hanging down the back, two navy stripes round it.
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.9, s.Y * 0.55, 0.08), C.White, CFrame.new(0, top - s.Y * 0.27, back + 0.1))
		for k = 0, 1 do
			local inset = 0.08 + k * 0.14
			piece(upper, outfit, "CollarStripe", Vector3.new(s.X * 0.9 - inset * 2, 0.06, 0.1), C.Navy, CFrame.new(0, top - s.Y * 0.55 + inset, back + 0.12))
			for _, side in ipairs({ -1, 1 }) do
				piece(upper, outfit, "CollarStripe", Vector3.new(0.06, s.Y * 0.55 - inset * 2, 0.1), C.Navy, CFrame.new(side * (s.X * 0.45 - inset), top - s.Y * 0.27, back + 0.12))
			end
		end
		-- The front: a V of navy stripes, the neckerchief and its ring.
		for _, side in ipairs({ -1, 1 }) do
			for k = 0, 1 do
				piece(upper, outfit, "CollarV", Vector3.new(0.06, s.Y * 0.5, 0.06), C.Navy, CFrame.new(side * (0.32 + k * 0.12), top - 0.38, front - 0.07) * CFrame.Angles(0, 0, side * -0.55))
			end
			piece(upper, outfit, "Shoulder", Vector3.new(s.X * 0.35, 0.08, s.Z + 0.12), C.White, CFrame.new(side * s.X * 0.3, top + 0.02, 0))
		end
		piece(upper, outfit, "Scarf", Vector3.new(0.6, 0.5, 0.06), C.Scarf, CFrame.new(0.05, top - 0.75, front - 0.09) * CFrame.Angles(0, 0, 0.6))
		piece(upper, outfit, "ScarfTail", Vector3.new(0.3, 0.6, 0.06), C.Scarf, CFrame.new(0.25, top - 1.05, front - 0.09) * CFrame.Angles(0, 0, -0.3))
		local ring = piece(upper, outfit, "Ring", Vector3.new(0.08, 0.32, 0.32), C.Ring, CFrame.new(0, top - 0.6, front - 0.12) * CFrame.Angles(0, math.pi / 2, 0))
		ring.Shape = Enum.PartType.Cylinder
		-- Anchor patch (his left) and the orange star badge (his right).
		local ax = 0.55
		piece(upper, outfit, "Anchor", Vector3.new(0.08, 0.5, 0.05), C.Teal, CFrame.new(ax, -0.05, front - 0.07))
		piece(upper, outfit, "AnchorBar", Vector3.new(0.3, 0.07, 0.05), C.Teal, CFrame.new(ax, 0.12, front - 0.07))
		piece(upper, outfit, "AnchorRing", Vector3.new(0.14, 0.12, 0.05), C.Teal, CFrame.new(ax, 0.24, front - 0.07))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "AnchorFluke", Vector3.new(0.18, 0.07, 0.05), C.Teal, CFrame.new(ax + side * 0.1, -0.27, front - 0.07) * CFrame.Angles(0, 0, side * 0.6))
		end
		local badge = piece(upper, outfit, "Badge", Vector3.new(0.06, 0.4, 0.4), C.Badge, CFrame.new(-0.55, 0.02, front - 0.06) * CFrame.Angles(0, math.pi / 2, 0))
		badge.Shape = Enum.PartType.Cylinder
		for k = 0, 1 do
			piece(upper, outfit, "BadgeStar", Vector3.new(0.18, 0.18, 0.05), C.Star, CFrame.new(-0.55, 0.02, front - 0.1) * CFrame.Angles(0, 0, k * math.pi / 4))
		end
		-- The star birthmark on the left of his neck.
		piece(upper, outfit, "StarMark", Vector3.new(0.14, 0.14, 0.05), C.Mark, CFrame.new(-0.3, top + 0.08, front + 0.2) * CFrame.Angles(0, 0, math.pi / 4))
	end
	-- White trousers, a light-blue belt with a gold buckle.
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.25
		if lower then
			piece(lower, outfit, "Pants", ws + Vector3.new(0.06, 0.02, 0.06), C.White, CFrame.new())
		end
		piece(waist, outfit, "Belt", Vector3.new(ws.X + 0.1, 0.16, ws.Z + 0.1), C.Belt, CFrame.new(0, waistTop - 0.1, 0))
		for k = -2, 2 do
			piece(waist, outfit, "BeltLoop", Vector3.new(0.12, 0.18, ws.Z + 0.12), C.White, CFrame.new(k * 0.4, waistTop - 0.1, 0))
		end
		piece(waist, outfit, "Buckle", Vector3.new(0.34, 0.2, 0.06), C.Gold, CFrame.new(0, waistTop - 0.1, -ws.Z / 2 - 0.08))
	end
	-- White sleeves with navy-striped cuffs.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			piece(arm, outfit, "Sleeve", as + Vector3.new(0.1, 0.02, 0.1), C.White, CFrame.new())
			if name:find("Lower") or as.Y > 1.8 then
				local y = -as.Y / 2 + 0.25
				for k = 0, 1 do
					piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.14, 0.07, as.Z + 0.14), C.Navy, CFrame.new(0, y + k * 0.14, 0))
				end
			end
		end
	end
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Pants", leg.Size + Vector3.new(0.06, 0.02, 0.06), C.White, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.08, 0.04, 0.1), C.Shoe, CFrame.new())
		end
	end
end

function JosukeOutfit.apply(character)
	if character:FindFirstChild("JosukeOutfit") then
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
	outfit.Name = "JosukeOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function JosukeOutfit.remove(character)
	local outfit = character:FindFirstChild("JosukeOutfit")
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
		if character:GetAttribute("TuskAct") == JosukeOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == JosukeOutfit.Act then
					JosukeOutfit.apply(character)
				end
			end)
		else
			JosukeOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function JosukeOutfit.init()
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

return JosukeOutfit
end
end
