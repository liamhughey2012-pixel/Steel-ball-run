--[[
	Joseph_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Joseph Joestar (Part 3): Hermit Purple and Hamon.
	Its other half is Joseph_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "joseph" or __expect.Side ~= "server") then
		error("this is the code for Joseph_Server, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Joseph_Server and put it in ServerScriptService > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: Joseph
-- ======================================================================
__modules["Joseph"] = function()
--[[
	Joseph  (ServerScriptService.SpinServer.TuskActs.Joseph)

	Joseph Joestar (a visitor from another world: Part 3): HERMIT PURPLE.
	Thorny purple vines, Hamon running through them, and his greatest
	technique: running away. Registered as "Act" 22.
	  M1        HAMON COMBO: Hamon-charged punches; the 4th is a SUNLIGHT
	            YELLOW OVERDRIVE that launches
	  Ability 1 HERMIT GRAB: vines shoot out in a line, snag the first enemy,
	            drag them back to him and jolt them with Hamon
	  Ability 2 HAMON VINES: a fan of vines whips out in front; Hamon surges
	            through them into everyone they touch
	  Ability 3 NIGERUNDAYO!: "run away!": 70% faster for 3.5 s, and he
	            can't be hit for the first half second
	  Ultimate  HERMIT WEB OVERDRIVE: vines burst up out of the ground and
	            bind everyone near him (they can't move); Hamon pulses
	            through them, then SUNLIGHT YELLOW OVERDRIVE blasts them away
	Numbers: TuskConfig.Joseph. All damage goes through S.hit (CombatAdapter).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Joseph = {}
local cfg = TuskConfig.Joseph
local ACT = 22

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

function Joseph.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- Pinning (bound by vines). Counted, so two binds don't free them early.
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

local function away(from, to, fallback)
	local v = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return v.Magnitude > 0.1 and v.Unit or fallback
end

---------------------------------------------------------------------------
-- 1: HERMIT GRAB
---------------------------------------------------------------------------
local function hermitGrab(S, player, state, aim)
	local c = cfg.HermitGrab
	if not ready(S, player, state, "HermitGrab", 1) then
		return
	end
	local character, _, root = alive(S, player)
	local life = state.Life
	S.lock(state, c.Windup + c.PullTime + 0.2)
	S.fx("Ability", { Character = character, Act = ACT, Move = "HermitGrab", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = Moves.flat(S.aim(aim, r))
		local from = r.Position
		-- Stops at a wall.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local wall = workspace:Raycast(from, dir * c.Range, params)
		local reach = c.Range
		if wall and not (wall.Instance.Parent and wall.Instance.Parent:FindFirstChildOfClass("Humanoid")) then
			reach = (wall.Position - from).Magnitude
		end
		-- The first enemy along the line.
		local mid = from + dir * (reach / 2)
		local best, bestD, bestRoot
		for _, target in ipairs(S.Hitbox.inBox(char, CFrame.lookAt(mid, mid + dir), Vector3.new(c.Width, 6, reach), 8)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr then
				local d = (tr.Position - from):Dot(dir)
				if d > 0 and (not bestD or d < bestD) then
					best, bestD, bestRoot = target, d, tr
				end
			end
		end
		if not best then
			S.startCooldown(player, state, "HermitGrab", c.MissCooldown, 1)
			S.fx("Ability", { Character = char, Act = ACT, Move = "HermitGrab", Phase = "Miss", From = from, To = from + dir * reach })
			return
		end
		S.startCooldown(player, state, "HermitGrab", c.Cooldown, 1)
		if not S.hit(player, best, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = -dir, Position = bestRoot.Position, Source = "JosephGrab" }) then
			S.fx("Ability", { Character = char, Act = ACT, Move = "HermitGrab", Phase = "Miss", From = from, To = bestRoot.Position })
			return
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "HermitGrab", Phase = "Snag", Target = best, From = from, PullTime = c.PullTime })
		-- Dragged back to just in front of him.
		local start = bestRoot.Position
		local steps = 7
		for k = 1, steps do
			task.delay(c.PullTime * k / steps, function()
				local _, _, rr = alive(S, player)
				if not rr or not best.Parent or not bestRoot.Parent or bestRoot.Anchored then
					return
				end
				local stopAt = rr.Position + Moves.flat(rr.CFrame.LookVector) * c.StopDistance
				local p = start:Lerp(Vector3.new(stopAt.X, start.Y, stopAt.Z), k / steps)
				best:PivotTo(CFrame.lookAt(p, Vector3.new(rr.Position.X, p.Y, rr.Position.Z)))
				bestRoot.AssemblyLinearVelocity = Vector3.new()
				if k == steps then
					S.hit(player, best, { Damage = c.ShockDamage, Stun = 0.5, Knockback = 0, Direction = dir, Position = bestRoot.Position, Unblockable = true, Source = "JosephHamon" })
					S.fx("Ability", { Character = char, Act = ACT, Move = "HermitGrab", Phase = "Shock", Target = best })
				end
			end)
		end
	end)
end

---------------------------------------------------------------------------
-- 2: HAMON VINES
---------------------------------------------------------------------------
local function hamonVines(S, player, state, aim)
	local c = cfg.HamonVines
	if not ready(S, player, state, "HamonVines", 2) then
		return
	end
	S.startCooldown(player, state, "HamonVines", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.3)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "HamonVines", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = Moves.flat(S.aim(aim, r))
		local cosLimit = math.cos(math.rad(c.Cone / 2))
		local hits = {}
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, c.Range, 10)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr then
				local f = Vector3.new(tr.Position.X - r.Position.X, 0, tr.Position.Z - r.Position.Z)
				if (f.Magnitude < 2 or f.Unit:Dot(dir) >= cosLimit) and S.Hitbox.lineOfSight(r.Position, tr.Position, { char, target }) then
					if S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = away(r.Position, tr.Position, dir), Position = tr.Position, Source = "JosephVines" }) then
						table.insert(hits, target)
					end
				end
			end
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "HamonVines", Phase = "Lash", From = r.Position, Direction = dir, Range = c.Range, Cone = c.Cone, Hits = hits })
	end)
end

---------------------------------------------------------------------------
-- 3: NIGERUNDAYO!
---------------------------------------------------------------------------
local function nigerundayo(S, player, state)
	local c = cfg.Nigerundayo
	if not S.cooldownReady(player, state, "Nigerundayo", 3) or state.Charging then
		return
	end
	-- (Usable even mid-combo: running away is always an option.)
	S.startCooldown(player, state, "Nigerundayo", c.Cooldown, 3)
	local character, humanoid = alive(S, player)
	local token = tostring({})
	character:SetAttribute("JosephRunToken", token)
	character:SetAttribute("JosephRunUntil", workspace:GetServerTimeNow() + c.Time)
	S.Adapter.setMoveModifier(humanoid, "Nigerundayo", c.Speed)
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	S.fx("Ability", { Character = character, Act = ACT, Move = "Nigerundayo", Phase = "Run", Time = c.Time })
	task.delay(c.IFrames, function()
		if character.Parent and character:GetAttribute("JosephRunToken") == token then
			character:SetAttribute(iframes, nil)
		end
	end)
	task.delay(c.Time, function()
		if character.Parent and character:GetAttribute("JosephRunToken") == token then
			character:SetAttribute("JosephRunToken", nil)
			character:SetAttribute("JosephRunUntil", nil)
			S.Adapter.setMoveModifier(humanoid, "Nigerundayo", nil)
		end
	end)
end

function Joseph.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		hermitGrab(S, player, state, aim)
	elseif slot == 2 then
		hamonVines(S, player, state, aim)
	elseif slot == 3 then
		nigerundayo(S, player, state)
	end
end

---------------------------------------------------------------------------
-- HERMIT WEB OVERDRIVE (ultimate)
---------------------------------------------------------------------------
function Joseph.Ultimate(S, player, state, aim)
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
		local center = r.Position
		local bound = {}
		for _, target in ipairs(S.Hitbox.inRadius(char, center, u.Radius, 12)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr then
				pin(tr)
				table.insert(bound, target)
			end
		end
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Bind", Position = center, Radius = u.Radius, Targets = bound, Time = u.BindTime })
		local ticks = math.max(1, math.floor(u.BindTime / u.Tick))
		for k = 1, ticks do
			task.delay(k * u.Tick, function()
				if state.Life ~= life then
					return
				end
				for _, target in ipairs(bound) do
					local tr = target.Parent and target:FindFirstChild("HumanoidRootPart")
					if tr then
						S.hit(player, target, { Damage = u.TickDamage, Stun = u.Tick + 0.1, Knockback = 0, Direction = Vector3.new(0, 1, 0), Position = tr.Position, Source = "JosephWeb" })
					end
				end
				S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Pulse", Targets = bound })
			end)
		end
		task.delay(u.BindTime, function()
			for _, target in ipairs(bound) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr then
					unpin(tr)
				end
			end
			if state.Life ~= life or not char.Parent then
				S.fx("Ultimate", { Character = char, Act = ACT, Phase = "End" })
				return
			end
			local _, _, rr = alive(S, player)
			local at = rr and rr.Position or center
			for _, target in ipairs(bound) do
				local tr = target.Parent and target:FindFirstChild("HumanoidRootPart")
				if tr then
					S.hit(player, target, { Damage = u.BlastDamage, Stun = u.BlastStun, Knockback = u.BlastKnockback, Launch = u.BlastLaunch, Direction = away(at, tr.Position, Vector3.new(0, 0, 1)), Position = tr.Position, Unblockable = true, Source = "JosephOverdrive" })
				end
			end
			S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Blast", Position = at, Radius = u.Radius, Targets = bound })
		end)
	end)
end

function Joseph.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("JosephRunToken", nil)
		character:SetAttribute("JosephRunUntil", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "Nigerundayo", nil)
		end
	end
end

return Joseph
end

-- ======================================================================
-- MODULE: JosephOutfit
-- ======================================================================
__modules["JosephOutfit"] = function()
--[[
	JosephOutfit  (ServerScriptService.SpinServer.JosephOutfit)

	Gives a character the look of old Joseph Joestar (Part 3) while they
	play him (TuskAct 22), built from blocky parts (no catalog asset ids):
	  * a tan FEDORA with a dark band and a wide brim; short grey hair
	    under it
	  * a full white BEARD and moustache
	  * a dark navy button-up shirt, open at the collar, sleeves rolled up
	    to the elbows (bare, strong forearms)
	  * a black glove on his left hand (his prosthetic)
	  * a brown belt, khaki trousers, brown shoes
	(Hermit Purple, HermitPurpleStand, winds round his right arm.)
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local JosephOutfit = {}
JosephOutfit.Act = 22

local C = {
	Hat = Color3.fromRGB(196, 166, 112),
	HatShade = Color3.fromRGB(160, 130, 84),
	HatBand = Color3.fromRGB(70, 48, 30),
	Hair = Color3.fromRGB(196, 196, 200),
	Beard = Color3.fromRGB(236, 236, 238),
	BeardShade = Color3.fromRGB(196, 196, 202),
	Shirt = Color3.fromRGB(40, 52, 84),
	ShirtShade = Color3.fromRGB(28, 36, 60),
	Button = Color3.fromRGB(220, 220, 226),
	Glove = Color3.fromRGB(26, 26, 30),
	Belt = Color3.fromRGB(96, 62, 34),
	Buckle = Color3.fromRGB(210, 180, 100),
	Pants = Color3.fromRGB(178, 152, 110),
	PantsShade = Color3.fromRGB(150, 126, 90),
	Shoe = Color3.fromRGB(84, 54, 32),
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

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Short grey hair at the sides and back.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "SideHair", Vector3.new(0.1 * s, 0.5 * s, head.Size.Z * 0.7), C.Hair, CFrame.new(side * (w + 0.03 * s), h - 0.4 * s, 0.1 * s))
	end
	piece(head, outfit, "BackHair", Vector3.new(head.Size.X + 0.06 * s, 0.5 * s, 0.12 * s), C.Hair, CFrame.new(0, h - 0.38 * s, d + 0.04 * s))
	-- The fedora: a pinched crown, a dark band, a wide brim dipping at the front.
	piece(head, outfit, "Crown", Vector3.new(head.Size.X * 0.95, 0.5 * s, head.Size.Z * 0.95), C.Hat, CFrame.new(0, h + 0.2 * s, 0.02 * s))
	piece(head, outfit, "Pinch", Vector3.new(0.1 * s, 0.14 * s, head.Size.Z * 0.6), C.HatShade, CFrame.new(0, h + 0.44 * s, 0.05 * s))
	piece(head, outfit, "Band", Vector3.new(head.Size.X * 0.97, 0.14 * s, head.Size.Z * 0.97), C.HatBand, CFrame.new(0, h + 0.02 * s, 0.02 * s))
	piece(head, outfit, "Brim", Vector3.new(head.Size.X + 0.6 * s, 0.06 * s, head.Size.Z + 0.6 * s), C.Hat, CFrame.new(0, h - 0.04 * s, 0.02 * s))
	piece(head, outfit, "BrimFront", Vector3.new(head.Size.X + 0.5 * s, 0.06 * s, 0.4 * s), C.HatShade, CFrame.new(0, h - 0.08 * s, -d - 0.2 * s) * CFrame.Angles(math.rad(-10), 0, 0))
	-- A full white beard and moustache, heavy brows.
	piece(head, outfit, "Beard", Vector3.new(head.Size.X * 0.9, 0.42 * s, 0.12 * s), C.Beard, CFrame.new(0, -h + 0.2 * s, -d - 0.03 * s))
	piece(head, outfit, "BeardChin", Vector3.new(head.Size.X * 0.6, 0.2 * s, 0.3 * s), C.Beard, CFrame.new(0, -h - 0.02 * s, -d + 0.06 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "BeardSide", Vector3.new(0.1 * s, 0.5 * s, head.Size.Z * 0.6), C.Beard, CFrame.new(side * (w + 0.03 * s), -h + 0.35 * s, -0.05 * s))
		piece(head, outfit, "Moustache", Vector3.new(0.26 * s, 0.1 * s, 0.06 * s), C.Beard, CFrame.new(side * 0.13 * s, -0.22 * s, -d - 0.05 * s) * CFrame.Angles(0, 0, side * -0.2))
		piece(head, outfit, "Brow", Vector3.new(0.28 * s, 0.07 * s, 0.05 * s), C.Hair, CFrame.new(side * 0.22 * s, 0.14 * s, -d - 0.02 * s) * CFrame.Angles(0, 0, side * 0.12))
	end
	piece(head, outfit, "BeardLine", Vector3.new(0.04 * s, 0.36 * s, 0.13 * s), C.BeardShade, CFrame.new(0, -h + 0.2 * s, -d - 0.035 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	local head = character:FindFirstChild("Head")
	local skin = head and head.Color or Color3.fromRGB(226, 186, 150)
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Shirt", s + Vector3.new(0.08, 0.02, 0.08), C.Shirt, CFrame.new())
		-- Open at the collar: a little V of skin, the collar points.
		piece(upper, outfit, "Neck", Vector3.new(0.34, 0.34, 0.04), skin, CFrame.new(0, top - 0.17, front - 0.05))
		piece(upper, outfit, "NeckTip", Vector3.new(0.24, 0.24, 0.04), skin, CFrame.new(0, top - 0.33, front - 0.05) * CFrame.Angles(0, 0, math.pi / 4))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Collar", Vector3.new(0.36, 0.16, 0.06), C.ShirtShade, CFrame.new(side * 0.26, top - 0.08, front - 0.06) * CFrame.Angles(0, 0, side * -0.5))
			piece(upper, outfit, "Pocket", Vector3.new(0.4, 0.34, 0.04), C.ShirtShade, CFrame.new(side * 0.5, top - 0.55, front - 0.06))
		end
		piece(upper, outfit, "Placket", Vector3.new(0.12, s.Y * 0.6, 0.05), C.ShirtShade, CFrame.new(0, -s.Y * 0.18, front - 0.06))
		for k = 0, 3 do
			local b = piece(upper, outfit, "Button", Vector3.new(0.04, 0.09, 0.09), C.Button, CFrame.new(0, top - 0.6 - k * 0.24, front - 0.09) * CFrame.Angles(0, math.pi / 2, 0))
			b.Shape = Enum.PartType.Cylinder
		end
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.16, 0.16, ls.Z + 0.16), C.Belt, CFrame.new(0, ls.Y / 2 - 0.06, 0))
		piece(lower, outfit, "Buckle", Vector3.new(0.24, 0.16, 0.06), C.Buckle, CFrame.new(0, ls.Y / 2 - 0.06, -ls.Z / 2 - 0.1))
	end
	-- Sleeves rolled up to the elbows; bare forearms; a black glove on his left hand.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local h = name:find("Upper") and as.Y or as.Y * 0.45
			piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.1, h, as.Z + 0.1), C.Shirt, CFrame.new(0, as.Y / 2 - h / 2, 0))
			piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.16, 0.16, as.Z + 0.16), C.ShirtShade, CFrame.new(0, as.Y / 2 - h + 0.06, 0))
		end
	end
	for _, name in ipairs({ "LeftLowerArm", "RightLowerArm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Skin", arm.Size + Vector3.new(0.04, 0, 0.04), skin, CFrame.new())
		end
	end
	local leftHand = character:FindFirstChild("LeftHand")
	if leftHand then
		piece(leftHand, outfit, "Glove", leftHand.Size + Vector3.new(0.08, 0.06, 0.08), C.Glove, CFrame.new())
	end
	local leftLower = character:FindFirstChild("LeftLowerArm")
	if leftLower then
		piece(leftLower, outfit, "GloveCuff", Vector3.new(leftLower.Size.X + 0.1, 0.24, leftLower.Size.Z + 0.1), C.Glove, CFrame.new(0, -leftLower.Size.Y / 2 + 0.12, 0))
	end
	-- Khaki trousers, brown shoes.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Trousers", leg.Size + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
			piece(leg, outfit, "Crease", Vector3.new(0.04, leg.Size.Y * 0.9, 0.04), C.PantsShade, CFrame.new(0, 0, -leg.Size.Z / 2 - 0.04))
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.08, 0.04, 0.14), C.Shoe, CFrame.new(0, 0, -0.04))
		end
	end
end

function JosephOutfit.apply(character)
	if character:FindFirstChild("JosephOutfit") then
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
	outfit.Name = "JosephOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function JosephOutfit.remove(character)
	local outfit = character:FindFirstChild("JosephOutfit")
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
		if character:GetAttribute("TuskAct") == JosephOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == JosephOutfit.Act then
					JosephOutfit.apply(character)
				end
			end)
		else
			JosephOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function JosephOutfit.init()
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

return JosephOutfit
end
end
