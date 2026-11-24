--[[
	Jodio_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Jodio Joestar (The JOJOLands): November Rain.
	Its other half is Jodio_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: Jodio
-- ======================================================================
__modules["Jodio"] = function()
--[[
	Jodio  (ServerScriptService.SpinServer.TuskActs.Jodio)

	Jodio Joestar (The JOJOLands): NOVEMBER RAIN. Heavy raindrops that
	strike with crushing pressure. Registered as "Act" 17 so it reuses the
	Tusk ability system.
	  Passive   SOAKED: his rain soaks whoever it hits for a few seconds, and
	            his rain hits a soaked enemy harder
	  M1        NOVEMBER RAIN COMBO: the stand punches with him
	  Ability 1 HEAVY RAIN: a storm cloud forms over the nearest enemy in
	            front; for a few seconds the rain under it pounds everyone
	            there and presses them down (they walk at half speed)
	  Ability 2 RAIN BULLETS: a burst of heavy raindrops fired like bullets
	  Ability 3 RAIN JET: November Rain blasts him forward on a jet of rain;
	            anyone in the way is slammed aside (he can't be hit mid-jet)
	  Ultimate  NOVEMBER RAIN: TORRENT: a huge storm follows him; everyone
	            under it is pounded and pressed down, and when it ends the
	            rain comes down all at once and CRUSHES them
	Numbers: TuskConfig.Jodio. All damage goes through S.hit (CombatAdapter).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Jodio = {}
local cfg = TuskConfig.Jodio
local ACT = 17

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

-- A hit from his rain: soaked enemies take more, and it soaks them.
local function rainHit(S, player, target, info)
	local hitInfo = table.clone(info)
	if (target:GetAttribute("SoakedUntil") or 0) > now() then
		hitInfo.Damage = hitInfo.Damage * (cfg.SoakBonus or 1.25)
	end
	local ok = S.hit(player, target, hitInfo)
	if ok then
		target:SetAttribute("SoakedUntil", now() + (cfg.SoakTime or 5))
	end
	return ok
end
Jodio.rainHit = rainHit

-- Rain pressing them down: slowed while it keeps falling on them.
local pressedUntil = setmetatable({}, { __mode = "k" })
local function press(S, target, multiplier, seconds)
	local hum = target:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local untilT = now() + seconds
	pressedUntil[target] = untilT
	S.Adapter.setMoveModifier(hum, "RainPressure", multiplier)
	task.delay(seconds + 0.02, function()
		if pressedUntil[target] == untilT then
			pressedUntil[target] = nil
			S.Adapter.setMoveModifier(hum, "RainPressure", nil)
		end
	end)
end

function Jodio.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: HEAVY RAIN (a storm cloud over them)
---------------------------------------------------------------------------
local function heavyRain(S, player, state, aim)
	local c = cfg.HeavyRain
	if not ready(S, player, state, "HeavyRain", 1) then
		return
	end
	S.startCooldown(player, state, "HeavyRain", c.Cooldown, 1)
	S.lock(state, c.Windup + 0.15)
	local character, _, root = alive(S, player)
	local life = state.Life
	local direction = S.aim(aim, root)
	local target = Moves.findTarget(S, character, root, c.Range, c.Cone, direction)
	local troot = target and target:FindFirstChild("HumanoidRootPart")
	local f = flat(direction)
	local center = troot and troot.Position or root.Position + (f.Magnitude > 0 and f.Unit or Vector3.new(0, 0, -1)) * 25
	center = Moves.groundBelow(center, { character, target })
	S.fx("Ability", { Character = character, Act = ACT, Move = "HeavyRain", Phase = "Cloud", Position = center, Radius = c.Radius, Time = c.Time + c.Windup, Windup = c.Windup })
	local ticks = math.floor(c.Time / c.Tick)
	for i = 1, ticks do
		task.delay(c.Windup + i * c.Tick, function()
			if state.Life ~= life or not player.Character then
				return
			end
			for _, t in ipairs(S.Hitbox.inRadius(player.Character, center + Vector3.new(0, 2.5, 0), c.Radius, 8)) do
				local tr = t:FindFirstChild("HumanoidRootPart")
				if tr then
					press(S, t, c.Pressure, c.Tick + 0.1)
					rainHit(S, player, t, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = Vector3.new(0, -1, 0), Position = tr.Position, Source = "JodioRain" })
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- 2: RAIN BULLETS
---------------------------------------------------------------------------
local function rainBullets(S, player, state, aim)
	local c = cfg.RainBullets
	if not ready(S, player, state, "RainBullets", 2) then
		return
	end
	S.startCooldown(player, state, "RainBullets", c.Cooldown, 2)
	S.lock(state, c.Windup + c.Count * c.Gap)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "RainBullets", Phase = "Aim", Windup = c.Windup, Time = c.Count * c.Gap })
	for i = 1, c.Count do
		task.delay(c.Windup + (i - 1) * c.Gap, function()
			if not S.stillValid(player, state, life) then
				return
			end
			local char, _, r = alive(S, player)
			local base = S.aim(aim, r)
			local yaw = math.rad((math.random() - 0.5) * 2 * c.Spread)
			local pitch = math.rad((math.random() - 0.5) * c.Spread)
			local dir = (CFrame.lookAt(Vector3.new(), base) * CFrame.Angles(pitch, yaw, 0)).LookVector
			S.fireRain(player, state, {
				Origin = S.origin(char, r, Moves.HAND),
				Direction = dir,
				Speed = c.Speed,
				Radius = c.Radius,
				Range = c.Range,
				OnHit = function(target, position)
					rainHit(S, player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Position = position, Source = "JodioBullet" })
				end,
			})
		end)
	end
end

---------------------------------------------------------------------------
-- 3: RAIN JET
---------------------------------------------------------------------------
local function rainJet(S, player, state, aim)
	local c = cfg.RainJet
	if not ready(S, player, state, "RainJet", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = flat(S.aim(aim, root))
	direction = direction.Magnitude > 0 and direction.Unit or flat(root.CFrame.LookVector).Unit
	local destination = Moves.safeStep(character, root, direction, c.Distance)
	if not destination then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "RainJet", c.Cooldown, 3)
	S.lock(state, c.Windup + c.Travel + 0.1)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "RainJet", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local from = r.Position
		local to = Moves.safeStep(char, r, direction, c.Distance) or destination
		local iframes = S.Adapter.Settings.IFrameAttribute
		char:SetAttribute(iframes, true)
		S.fx("Ability", { Character = char, Act = ACT, Move = "RainJet", Phase = "Jet", From = from, To = to, Direction = direction, Travel = c.Travel })
		-- Carried along the jet in steps.
		local steps = 6
		for i = 1, steps do
			task.delay(c.Travel * i / steps, function()
				if char.Parent and state.Life == life then
					local p = from:Lerp(to, i / steps)
					char:PivotTo(CFrame.lookAt(p, p + direction))
				end
				if i == steps then
					char:SetAttribute(iframes, nil)
				end
			end)
		end
		-- Anyone along the way is slammed aside.
		local mid = (from + to) / 2
		local box = CFrame.lookAt(mid, mid + direction)
		local size = Vector3.new(c.Width, 6, (to - from).Magnitude + 3)
		task.delay(c.Travel * 0.5, function()
			if not player.Character then
				return
			end
			for _, target in ipairs(S.Hitbox.inBox(player.Character, box, size, 6)) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr then
					local side = (box:Inverse() * tr.Position).X
					local away = box.RightVector * (side >= 0 and 1 or -1) + direction * 0.4
					rainHit(S, player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = away, Position = tr.Position, Source = "JodioJet" })
				end
			end
		end)
	end)
end

function Jodio.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		heavyRain(S, player, state, aim)
	elseif slot == 2 then
		rainBullets(S, player, state, aim)
	elseif slot == 3 then
		rainJet(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- NOVEMBER RAIN: TORRENT (ultimate)
---------------------------------------------------------------------------
function Jodio.Ultimate(S, player, state, aim)
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
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Charge", Windup = u.Windup })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Storm", Duration = u.Duration, Radius = u.Radius })
		local untilT = now() + u.Duration
		local function tick()
			local char, _, r = alive(S, player)
			if not r or state.Life ~= life or char ~= character then
				S.fx("Ultimate", { Character = character, Act = ACT, Phase = "End" })
				return
			end
			local victims = S.Hitbox.inRadius(char, r.Position, u.Radius, 12)
			if now() >= untilT then
				-- The rain comes down all at once.
				local hit = {}
				for _, target in ipairs(victims) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr and rainHit(S, player, target, { Damage = u.CrushDamage, Stun = u.CrushStun, Knockback = u.CrushKnockback, Direction = Vector3.new(0, -1, 0), Position = tr.Position, Source = "JodioCrush" }) then
						table.insert(hit, tr.Position)
					end
				end
				S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Crush", Position = r.Position, Radius = u.Radius, Hits = hit })
				return
			end
			for _, target in ipairs(victims) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr then
					press(S, target, u.Pressure, u.Tick + 0.1)
					rainHit(S, player, target, { Damage = u.Damage, Stun = u.Stun, Knockback = 0, Direction = Vector3.new(0, -1, 0), Position = tr.Position, Source = "JodioRain" })
				end
			end
			task.delay(u.Tick, tick)
		end
		tick()
	end)
end

function Jodio.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
	end
end

return Jodio
end

-- ======================================================================
-- MODULE: JodioOutfit
-- ======================================================================
__modules["JodioOutfit"] = function()
--[[
	JodioOutfit  (ServerScriptService.SpinServer.JodioOutfit)

	Gives a character the look of Jodio Joestar (The JOJOLands) while they
	play him (TuskAct 17), built from blocky parts (no catalog asset ids),
	matched to his art:
	  * a dark blue hood up over his head, orange toggles at its edges, a
	    high white collar
	  * silver hair with a jagged fringe across his eyes and a long lock
	    down one side; yellow lips; a green star earring
	  * a dark top with his emblem: yellow horns, a green heart with a bow
	    tie, a grey bib under it; a pink strap round his chest
	  * pink shoulder pads, light-blue short sleeves
	  * navy trousers with orange buttons down the outside of each leg
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local JodioOutfit = {}
JodioOutfit.Act = 17

local C = {
	Hood = Color3.fromRGB(36, 52, 150),
	HoodRim = Color3.fromRGB(60, 90, 190),
	Toggle = Color3.fromRGB(236, 130, 40),
	Hair = Color3.fromRGB(206, 210, 222),
	HairShade = Color3.fromRGB(160, 166, 182),
	Lips = Color3.fromRGB(238, 190, 40),
	Earring = Color3.fromRGB(60, 190, 90),
	Collar = Color3.fromRGB(236, 236, 240),
	CollarText = Color3.fromRGB(200, 50, 60),
	Top = Color3.fromRGB(26, 28, 54),
	Horn = Color3.fromRGB(246, 210, 40),
	Heart = Color3.fromRGB(120, 200, 70),
	Bow = Color3.fromRGB(60, 64, 80),
	Bib = Color3.fromRGB(176, 176, 184),
	BibEdge = Color3.fromRGB(200, 50, 60),
	Strap = Color3.fromRGB(220, 60, 160),
	Pad = Color3.fromRGB(230, 70, 150),
	Sleeve = Color3.fromRGB(110, 170, 220),
	Pants = Color3.fromRGB(36, 42, 84),
	Button = Color3.fromRGB(240, 140, 40),
	Shoe = Color3.fromRGB(40, 40, 52),
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
	-- Silver hair: a cap under the hood, a jagged fringe across his eyes,
	-- a long lock down his right cheek.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.08 * s, 0.35 * s, head.Size.Z + 0.08 * s), C.Hair, CFrame.new(0, h - 0.15 * s, 0))
	for k = -2, 1 do
		piece(head, outfit, "Fringe", Vector3.new(0.3 * s, 0.3 * s, 0.08 * s), C.Hair, CFrame.new((k + 0.5) * 0.27 * s, h - 0.36 * s, -d - 0.04 * s) * CFrame.Angles(0, 0, math.pi / 4))
		piece(head, outfit, "FringeEdge", Vector3.new(0.05 * s, 0.22 * s, 0.085 * s), C.HairShade, CFrame.new((k + 0.5) * 0.27 * s + 0.08 * s, h - 0.4 * s, -d - 0.045 * s) * CFrame.Angles(0, 0, -math.pi / 4))
	end
	piece(head, outfit, "FringeBand", Vector3.new(head.Size.X + 0.06 * s, 0.16 * s, 0.08 * s), C.Hair, CFrame.new(0, h - 0.22 * s, -d - 0.03 * s))
	piece(head, outfit, "Lock", Vector3.new(0.16 * s, 0.75 * s, 0.1 * s), C.Hair, CFrame.new(w - 0.06 * s, -0.05 * s, -d - 0.02 * s))
	-- Yellow lips; a green star earring (his left) and a little green ring (his right).
	piece(head, outfit, "Lips", Vector3.new(0.38 * s, 0.12 * s, 0.05 * s), C.Lips, CFrame.new(0, -0.32 * s, -d - 0.02 * s))
	for k = 0, 1 do
		piece(head, outfit, "StarEarring", Vector3.new(0.05 * s, 0.17 * s, 0.17 * s), C.Earring, CFrame.new(-w - 0.05 * s, -0.12 * s, 0.05 * s) * CFrame.Angles(k * math.pi / 4, 0, 0))
	end
	piece(head, outfit, "RingEarring", Vector3.new(0.05 * s, 0.1 * s, 0.1 * s), C.Earring, CFrame.new(w + 0.05 * s, -0.15 * s, 0.05 * s))
	-- The hood: up over his head, open at the front, a lighter rim.
	piece(head, outfit, "HoodTop", Vector3.new(head.Size.X + 0.4 * s, 0.3 * s, head.Size.Z + 0.45 * s), C.Hood, CFrame.new(0, h + 0.1 * s, 0.08 * s))
	piece(head, outfit, "HoodBack", Vector3.new(head.Size.X + 0.4 * s, head.Size.Y + 0.4 * s, 0.25 * s), C.Hood, CFrame.new(0, -0.05 * s, d + 0.18 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HoodSide", Vector3.new(0.2 * s, head.Size.Y + 0.3 * s, head.Size.Z + 0.4 * s), C.Hood, CFrame.new(side * (w + 0.12 * s), 0, 0.06 * s))
		piece(head, outfit, "HoodRim", Vector3.new(0.12 * s, head.Size.Y + 0.3 * s, 0.1 * s), C.HoodRim, CFrame.new(side * (w + 0.12 * s), 0, -d - 0.12 * s))
		piece(head, outfit, "Toggle", Vector3.new(0.16 * s, 0.24 * s, 0.1 * s), C.Toggle, CFrame.new(side * (w + 0.1 * s), -h + 0.05 * s, -d - 0.16 * s))
	end
	piece(head, outfit, "HoodRimTop", Vector3.new(head.Size.X + 0.36 * s, 0.12 * s, 0.1 * s), C.HoodRim, CFrame.new(0, h + 0.15 * s, -d - 0.12 * s))
end

-- His emblem: yellow horns, a green heart with a bow tie, a grey bib below.
local function emblem(upper, outfit, front)
	local y = 0.25
	for _, side in ipairs({ -1, 1 }) do
		piece(upper, outfit, "Horn", Vector3.new(0.44, 0.26, 0.05), C.Horn, CFrame.new(side * 0.42, y + 0.12, front - 0.08) * CFrame.Angles(0, 0, side * -0.5))
		piece(upper, outfit, "HornTip", Vector3.new(0.18, 0.26, 0.05), C.Horn, CFrame.new(side * 0.6, y + 0.32, front - 0.08) * CFrame.Angles(0, 0, side * 0.3))
		local lobe = piece(upper, outfit, "HeartLobe", Vector3.new(0.05, 0.34, 0.34), C.Heart, CFrame.new(side * 0.13, y + 0.05, front - 0.1) * CFrame.Angles(0, math.pi / 2, 0))
		lobe.Shape = Enum.PartType.Cylinder
	end
	piece(upper, outfit, "HeartPoint", Vector3.new(0.36, 0.36, 0.05), C.Heart, CFrame.new(0, y - 0.1, front - 0.1) * CFrame.Angles(0, 0, math.pi / 4))
	piece(upper, outfit, "BowTie", Vector3.new(0.3, 0.08, 0.06), C.Bow, CFrame.new(0, y, front - 0.13))
	piece(upper, outfit, "Bib", Vector3.new(0.62, 0.6, 0.05), C.Bib, CFrame.new(0, y - 0.62, front - 0.07))
	piece(upper, outfit, "BibEdge", Vector3.new(0.68, 0.06, 0.06), C.BibEdge, CFrame.new(0, y - 0.93, front - 0.07))
	for _, side in ipairs({ -1, 1 }) do
		piece(upper, outfit, "BibEdge", Vector3.new(0.06, 0.62, 0.06), C.BibEdge, CFrame.new(side * 0.33, y - 0.62, front - 0.07))
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Top", s + Vector3.new(0.1, 0.02, 0.1), C.Top, CFrame.new())
		-- The high white collar, a strip of red lettering on it.
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.5, 0.28, s.Z * 0.75), C.Collar, CFrame.new(0, top + 0.12, 0))
		piece(upper, outfit, "CollarText", Vector3.new(s.X * 0.3, 0.08, 0.04), C.CollarText, CFrame.new(-0.05, top + 0.12, -s.Z * 0.38 - 0.02))
		emblem(upper, outfit, front)
		-- The pink strap round his chest, buckle at the front.
		piece(upper, outfit, "Strap", Vector3.new(s.X + 0.16, 0.12, s.Z + 0.16), C.Strap, CFrame.new(0, -0.5, 0))
		piece(upper, outfit, "Buckle", Vector3.new(0.22, 0.2, 0.06), C.Strap, CFrame.new(0.15, -0.5, front - 0.1))
		piece(upper, outfit, "BuckleBar", Vector3.new(0.06, 0.16, 0.07), C.Heart, CFrame.new(0.28, -0.5, front - 0.11))
	end
	local waist = lower or upper
	if waist and lower then
		piece(lower, outfit, "Pants", lower.Size + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
	end
	-- Bare forearms (his skin, taken from his head).
	local head = character:FindFirstChild("Head")
	local skin = head and head.Color or Color3.fromRGB(236, 200, 166)
	for _, name in ipairs({ "LeftLowerArm", "RightLowerArm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Skin", arm.Size + Vector3.new(0.04, 0.0, 0.04), skin, CFrame.new())
		end
	end
	-- Pink shoulder pads, light-blue short sleeves.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local sleeveH = name:find("Upper") and as.Y or as.Y * 0.45
			piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.1, sleeveH, as.Z + 0.1), C.Sleeve, CFrame.new(0, as.Y / 2 - sleeveH / 2, 0))
			piece(arm, outfit, "Pad", Vector3.new(as.X + 0.2, 0.22, as.Z + 0.2), C.Pad, CFrame.new(0, as.Y / 2 + 0.04, 0))
		end
	end
	-- Navy trousers, orange buttons down the outside of each leg.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Pants", ls + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
			local side = name:find("Left") and -1 or 1
			for k = -1, 1 do
				local b = piece(leg, outfit, "Button", Vector3.new(0.12, 0.12, 0.12), C.Button, CFrame.new(side * (ls.X / 2 + 0.04), k * ls.Y * 0.28, 0))
				b.Shape = Enum.PartType.Ball
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.08, 0.04, 0.12), C.Shoe, CFrame.new())
		end
	end
end

function JodioOutfit.apply(character)
	if character:FindFirstChild("JodioOutfit") then
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
	outfit.Name = "JodioOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function JodioOutfit.remove(character)
	local outfit = character:FindFirstChild("JodioOutfit")
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
		if character:GetAttribute("TuskAct") == JodioOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == JodioOutfit.Act then
					JodioOutfit.apply(character)
				end
			end)
		else
			JodioOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function JodioOutfit.init()
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

return JodioOutfit
end
end
