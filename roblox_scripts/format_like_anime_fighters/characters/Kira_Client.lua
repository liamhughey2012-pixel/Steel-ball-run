--[[
	Kira_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Yoshikage Kira (Part 4): Killer Queen.
	Its other half is Kira_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: KillerQueenStand
-- ======================================================================
__modules["KillerQueenStand"] = function()
--[[
	TuskActVFX.KillerQueenStand  (StarterPlayerScripts.SpinClient.TuskActVFX.KillerQueenStand)

	KILLER QUEEN (Yoshikage Kira, Part 4), blocky:
	  * a slim, athletic PINK body with dark purple accent lines (a V at the
	    collar, a line down the stomach, stripes on the arms and shins)
	  * a cat-like head: pointed CAT EARS, big slanted pale eyes with slit
	    pupils, a dark crest down the middle, a small grilled mouth
	  * white SKULLS: on the studded belt's buckle and on the back of its
	    right hand; studded wristbands and a studded collar
	  * pink legs with dark-rimmed knee pads
	Registered with TuskStandModels by KiraVFX, so TuskStand floats it behind
	Kira with a lilac aura.
]]

local KillerQueenStand = {}

local PINK = Color3.fromRGB(236, 162, 206)
local PINK_SHADE = Color3.fromRGB(196, 118, 168)
local PINK_LIGHT = Color3.fromRGB(250, 198, 228)
local DARK = Color3.fromRGB(72, 38, 88)
local SKULL = Color3.fromRGB(244, 240, 246)
local STUD = Color3.fromRGB(226, 226, 238)
local EYE = Color3.fromRGB(226, 214, 255)

KillerQueenStand.Aura = Color3.fromRGB(214, 150, 230)
KillerQueenStand.AuraLight = Color3.fromRGB(250, 226, 255)
KillerQueenStand.Offset = CFrame.new(2.2, 1.5, 2.6)

local function newPart(model, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	p.Parent = model
	return p
end

local function box(model, parent, name, size, color, cf, material)
	local p = newPart(model, name, size, color, material)
	local w = Instance.new("Weld")
	w.Part0 = parent
	w.Part1 = p
	w.C0 = cf
	w.Parent = p
	p.CFrame = parent.CFrame * cf
	return p, w
end

local function ball(model, parent, name, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(d, d, d), color, cf, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A tube from a to b (in parent space).
local function tube(model, parent, a, b, d, color)
	local len = (b - a).Magnitude
	local p = box(model, parent, "Tube", Vector3.new(len + d * 0.4, d, d), color, CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function egg(model, parent, name, size, color, cf, material)
	local p, w = box(model, parent, name, size, color, cf, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p, w
end

-- A little white skull facing forward (-Z).
local function skull(model, parent, cf, size)
	egg(model, parent, "Skull", Vector3.new(size, size * 0.9, size * 0.4), SKULL, cf)
	box(model, parent, "SkullJaw", Vector3.new(size * 0.55, size * 0.3, size * 0.35), SKULL, cf * CFrame.new(0, -size * 0.45, 0))
	for _, side in ipairs({ -1, 1 }) do
		egg(model, parent, "SkullEye", Vector3.new(size * 0.26, size * 0.28, 0.05), DARK, cf * CFrame.new(side * size * 0.2, size * 0.02, -size * 0.2))
	end
	box(model, parent, "SkullNose", Vector3.new(size * 0.1, size * 0.14, 0.05), DARK, cf * CFrame.new(0, -size * 0.2, -size * 0.2))
	box(model, parent, "SkullTeeth", Vector3.new(size * 0.4, size * 0.04, 0.05), DARK, cf * CFrame.new(0, -size * 0.45, -size * 0.18))
end

-- A band of studs round a limb.
local function studBand(model, parent, y, w, d, count)
	box(model, parent, "Band", Vector3.new(w, 0.16, d), DARK, CFrame.new(0, y, 0))
	for k = 0, count - 1 do
		local a = k / count * math.pi * 2
		ball(model, parent, "Stud", 0.09, STUD, CFrame.new(math.sin(a) * w * 0.52, y, math.cos(a) * d * 0.52), Enum.Material.Metal)
	end
end

function KillerQueenStand.build(scale)
	local s = (scale or 1) * 0.9
	local model = Instance.new("Model")
	model.Name = "KillerQueen"
	local rig = { Joints = {} }

	-- A slim, athletic torso.
	local torso = newPart(model, "Body", Vector3.new(2.0, 1.8, 1.0) * s, PINK)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.5 * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Pec", Vector3.new(0.85, 0.55, 0.1) * s, PINK_LIGHT, CFrame.new(side * 0.45 * s, 0.4 * s, front - 0.03 * s))
		-- The dark V from the shoulders down to the sternum.
		box(model, torso, "CollarV", Vector3.new(0.08, 0.95, 0.12) * s, DARK, CFrame.new(side * 0.32 * s, 0.42 * s, front - 0.05 * s) * CFrame.Angles(0, 0, side * -0.62))
		box(model, torso, "Side", Vector3.new(0.16, 1.2, 0.8) * s, PINK_SHADE, CFrame.new(side * 1.0 * s, -0.1 * s, 0))
	end
	box(model, torso, "StomachLine", Vector3.new(0.07, 0.9, 0.08) * s, DARK, CFrame.new(0, -0.45 * s, front - 0.02 * s))
	box(model, torso, "Waist", Vector3.new(1.5, 0.8, 0.88) * s, PINK, CFrame.new(0, -1.25 * s, 0))
	-- The studded belt with a skull buckle.
	box(model, torso, "Belt", Vector3.new(1.62, 0.3, 0.98) * s, DARK, CFrame.new(0, -1.62 * s, 0))
	for k = -3, 3 do
		if k ~= 0 then
			ball(model, torso, "Stud", 0.12 * s, STUD, CFrame.new(k * 0.2 * s, -1.62 * s, -0.5 * s), Enum.Material.Metal)
		end
	end
	skull(model, torso, CFrame.new(0, -1.6 * s, -0.53 * s), 0.38 * s)
	box(model, torso, "Hips", Vector3.new(1.55, 0.5, 0.9) * s, DARK, CFrame.new(0, -1.95 * s, 0))
	box(model, torso, "Neck", Vector3.new(0.5, 0.45, 0.5) * s, PINK_SHADE, CFrame.new(0, 1.1 * s, 0))
	studBand(model, torso, 1.0 * s, 0.62 * s, 0.62 * s, 8)

	-- A cat-like head: pointed ears, big slanted eyes, a dark crest.
	local headBase = CFrame.new(0, 1.25 * s, 0)
	local headOffset = CFrame.new(0, 0.5 * s, 0)
	local head, headWeld = egg(model, torso, "Head", Vector3.new(0.82, 0.98, 0.86) * s, PINK, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.42 * s
	box(model, head, "Crest", Vector3.new(0.08, 0.5, 0.86) * s, DARK, CFrame.new(0, 0.3 * s, 0.04 * s))
	for _, side in ipairs({ -1, 1 }) do
		local ear = CFrame.new(side * 0.28 * s, 0.5 * s, 0.05 * s) * CFrame.Angles(0, 0, side * -0.35)
		box(model, head, "Ear", Vector3.new(0.3, 0.38, 0.12) * s, PINK, ear * CFrame.Angles(0, 0, math.pi / 4))
		box(model, head, "EarInner", Vector3.new(0.17, 0.22, 0.13) * s, DARK, ear * CFrame.new(0, -0.02 * s, -0.01 * s) * CFrame.Angles(0, 0, math.pi / 4))
		local eye = CFrame.new(side * 0.19 * s, 0.05 * s, hf + 0.03 * s) * CFrame.Angles(0, 0, side * -0.3)
		egg(model, head, "Eye", Vector3.new(0.26, 0.16, 0.08) * s, EYE, eye, Enum.Material.Neon)
		box(model, head, "Pupil", Vector3.new(0.035, 0.13, 0.09) * s, DARK, eye)
		box(model, head, "EyeLine", Vector3.new(0.3, 0.04, 0.09) * s, DARK, eye * CFrame.new(0, 0.09 * s, 0))
	end
	box(model, head, "Mouth", Vector3.new(0.26, 0.1, 0.06) * s, DARK, CFrame.new(0, -0.28 * s, hf + 0.04 * s))
	for k = -1, 1 do
		box(model, head, "MouthLine", Vector3.new(0.025, 0.11, 0.065) * s, PINK_LIGHT, CFrame.new(k * 0.07 * s, -0.28 * s, hf + 0.035 * s))
	end
	box(model, head, "Cheek", Vector3.new(0.6, 0.06, 0.06) * s, PINK_SHADE, CFrame.new(0, -0.14 * s, hf + 0.05 * s))

	-- Slim arms: dark stripes, studded wristbands, a skull on the right hand.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		egg(model, torso, "Shoulder", Vector3.new(0.75, 0.62, 0.75) * s, PINK_LIGHT, CFrame.new(side * 1.12 * s, 0.72 * s, 0))
		box(model, torso, "ShoulderLine", Vector3.new(0.06, 0.06, 0.7) * s, DARK, CFrame.new(side * 1.2 * s, 0.9 * s, 0))
		local base = CFrame.new(side * 1.2 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.05 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.5, 2.1, 0.5) * s, PINK, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "ArmStripe", Vector3.new(0.06, 1.5, 0.14) * s, DARK, CFrame.new(side * 0.24 * s, 0.15 * s, -0.08 * s))
		studBand(model, arm, -0.75 * s, 0.6 * s, 0.6 * s, 6)
		local hand = box(model, arm, "Hand", Vector3.new(0.5, 0.48, 0.42) * s, PINK, CFrame.new(0, -1.25 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.1, 0.3, 0.12) * s, PINK_SHADE, CFrame.new(f * 0.12 * s, -0.34 * s, -0.06 * s))
		end
		if a[1] == "ArmR" then
			skull(model, hand, CFrame.new(0, 0.02 * s, 0.24 * s) * CFrame.Angles(0, math.pi, 0), 0.3 * s)
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Pink legs, dark-rimmed knee pads, a stripe down each shin.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.42 * s, -2.1 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.58, 2.4, 0.58) * s, PINK, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Thigh", Vector3.new(0.66, 1.0, 0.66) * s, PINK_LIGHT, CFrame.new(0, 0.62 * s, 0))
		box(model, leg, "KneePad", Vector3.new(0.48, 0.42, 0.14) * s, PINK_LIGHT, CFrame.new(0, 0.0, -0.33 * s))
		box(model, leg, "KneeRim", Vector3.new(0.52, 0.06, 0.16) * s, DARK, CFrame.new(0, 0.2 * s, -0.33 * s))
		box(model, leg, "ShinStripe", Vector3.new(0.07, 0.8, 0.07) * s, DARK, CFrame.new(0, -0.65 * s, -0.3 * s))
		box(model, leg, "Foot", Vector3.new(0.58, 0.28, 0.9) * s, PINK_SHADE, CFrame.new(0, -1.3 * s, -0.15 * s))
	end
	return model, rig
end

return KillerQueenStand
end

-- ======================================================================
-- MODULE: KiraVFX
-- ======================================================================
__modules["KiraVFX"] = function()
--[[
	TuskActVFX.KiraVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.KiraVFX)

	Client visuals for Yoshikage Kira / KILLER QUEEN. Blocky.
	  * Killer Queen (KillerQueenStand) floats behind him with a lilac aura;
	    Kira stands calm and composed
	  * KILLER QUEEN COMBO: pink strikes; the 4th is a reaching chop
	  * FIRST BOMB: Killer Queen's hand reaches out; whoever it touches gets
	    a pulsing pink outline and a skull over their head ("KILLER QUEEN
	    HAS ALREADY TOUCHED IT"). The "click": his thumb comes up, "CLICK",
	    and they explode (a flash, a fireball, smoke, debris)
	  * SHEER HEART ATTACK: a little grey tank with a skull face and treads
	    rolls after its target, "LOOK HERE!" popping up as it goes, then
	    explodes
	  * STRAY CAT AIR BOMBS: three faint, wobbling air bubbles drift out and
	    burst
	  * BITES THE DUST: "BITES THE DUST" over his head; everyone marked gets
	    a skull; they explode; then the world tints, a clock ring sweeps
	    backwards and he's back where he stood
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local TuskStandModels = __require("TuskStandModels")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Common = __require("TuskActCommon")
local Fighters = __require("Fighters")
local TuskStand = __require("TuskStand")
local KillerQueenStand = __require("KillerQueenStand")

local KiraVFX = {}
local ACT = 26
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, KillerQueenStand.build, { Aura = KillerQueenStand.Aura, AuraLight = KillerQueenStand.AuraLight, Offset = KillerQueenStand.Offset })

local PINK = Color3.fromRGB(240, 150, 210)
local LILAC = Color3.fromRGB(200, 150, 240)
local FIRE = Color3.fromRGB(255, 150, 60)
local FIRE_HOT = Color3.fromRGB(255, 236, 160)
local SMOKE = Color3.fromRGB(90, 84, 92)
local TANK = Color3.fromRGB(150, 156, 170)
local TANK_DARK = Color3.fromRGB(70, 74, 86)

local stanced = {}
local bombs = {} -- [target] = { Highlight, Label }
local tanks = {} -- [id] = { Model parts, Target cframe }
local bubbles = {} -- [id] = { Part }
local marks = {} -- [target] = billboard

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function label(adornee, text, color, duration, size, offset, font)
	if not adornee then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size or 240, (size or 240) / 5)
	bb.StudsOffset = offset or Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = adornee
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = font or Enum.Font.Bangers
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.1
	t.Parent = bb
	bb.Parent = VFXLib.Folder
	local base = bb.StudsOffset
	VFXLib.animate(duration or 1.2, function(a)
		bb.StudsOffset = base + Vector3.new(0, a * 1.2, 0)
		t.TextTransparency = math.max(0, a * 1.6 - 0.6)
		t.TextStrokeTransparency = 0.1 + 0.9 * a
	end, function()
		bb:Destroy()
	end)
	return bb
end

-- A Killer Queen explosion: a white flash, an orange fireball, smoke, debris.
local function explosion(at, radius)
	radius = radius or 6
	VFXLib.flash(at, FIRE_HOT, radius * 1.5, 20, 0.12)
	local ball = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(at), Color = FIRE, Transparency = 0.1 })
	local core = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(at), Color = FIRE_HOT, Transparency = 0 })
	VFXLib.animate(0.45, function(a)
		local d = radius * 1.6 * VFXLib.easeOut(a)
		ball.Size = Vector3.new(d, d, d)
		core.Size = Vector3.new(d * 0.6, d * 0.6, d * 0.6)
		ball.Transparency = 0.1 + 0.9 * a
		core.Transparency = a
		ball.Color = FIRE:Lerp(SMOKE, a)
	end, function()
		ball:Destroy()
		core:Destroy()
	end)
	for _ = 1, 8 do
		local puff = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(at), Color = SMOKE, Transparency = 0.3, Material = Enum.Material.SmoothPlastic })
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
		local dist = radius * (0.5 + math.random() * 0.6)
		VFXLib.animate(0.9 + math.random() * 0.4, function(a)
			local e = VFXLib.easeOut(a)
			puff.CFrame = CFrame.new(at + dir * dist * e + Vector3.new(0, a * 2, 0))
			local d = 2 + a * radius * 0.6
			puff.Size = Vector3.new(d, d, d)
			puff.Transparency = 0.3 + 0.7 * a
		end, function()
			puff:Destroy()
		end)
	end
	VFXLib.burst(at, { Count = 14, Color = FIRE, Speed = 22, Lifetime = 0.5 })
	TuskVFX.CreateRotationalShockwave(CFrame.new(at) * CFrame.Angles(0, 0, 0), { Radius = radius, Layers = 2, Color = FIRE, Color2 = PINK, Particles = 1, Width = 0.5 })
	VFXLib.sound(sounds.AwakeningBurst or sounds.Swing, at, 0.8, 0.8)
	CameraFX.shakeAt(at, 1.0, 60)
end

-- Clear a primed bomb's markings.
local function unmark(target)
	local b = bombs[target]
	bombs[target] = nil
	if b then
		if b.Highlight.Parent then
			b.Highlight:Destroy()
		end
		if b.Label and b.Label.Parent then
			b.Label:Destroy()
		end
	end
end

-- A skull hanging over someone's head until removed (or `time` runs out).
local function skullOver(target, time, color)
	local head = target:FindFirstChild("Head")
	if not head then
		return nil
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(60, 60)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = "☠"
	t.TextColor3 = color or PINK
	t.TextStrokeTransparency = 0.2
	t.Parent = bb
	bb.Parent = VFXLib.Folder
	VFXLib.animate(time or 8, function()
		if t.Parent then
			t.TextTransparency = 0.15 + 0.25 * math.sin(os.clock() * 6)
		end
	end, function()
		if bb.Parent then
			bb:Destroy()
		end
	end)
	return bb
end

---------------------------------------------------------------------------
-- Sheer Heart Attack: a little tank with a skull face and treads
---------------------------------------------------------------------------
local function buildTank()
	local parts = {}
	local function add(name, size, offset, color, material)
		local p = VFXLib.part({ Size = size, Color = color, Material = material or Enum.Material.Metal })
		p.Name = name
		table.insert(parts, { Part = p, Offset = offset })
	end
	add("Hull", Vector3.new(1.5, 0.9, 1.7), CFrame.new(0, 0.75, 0), TANK)
	add("Dome", Vector3.new(1.1, 0.6, 1.1), CFrame.new(0, 1.35, 0.1), TANK)
	for _, side in ipairs({ -1, 1 }) do
		add("Tread", Vector3.new(0.4, 0.6, 1.9), CFrame.new(side * 0.88, 0.32, 0), TANK_DARK, Enum.Material.SmoothPlastic)
		for k = -1, 1 do
			add("Wheel", Vector3.new(0.42, 0.3, 0.3), CFrame.new(side * 0.88, 0.32, k * 0.6), Color3.fromRGB(40, 42, 50), Enum.Material.SmoothPlastic)
		end
	end
	-- The skull face on the front.
	add("Face", Vector3.new(0.9, 0.7, 0.1), CFrame.new(0, 0.85, -0.88), Color3.fromRGB(236, 232, 238), Enum.Material.SmoothPlastic)
	for _, side in ipairs({ -1, 1 }) do
		add("Eye", Vector3.new(0.22, 0.22, 0.12), CFrame.new(side * 0.2, 0.95, -0.9), Color3.fromRGB(40, 20, 50), Enum.Material.SmoothPlastic)
	end
	add("Teeth", Vector3.new(0.5, 0.06, 0.12), CFrame.new(0, 0.62, -0.9), Color3.fromRGB(40, 20, 50), Enum.Material.SmoothPlastic)
	add("Antenna", Vector3.new(0.06, 0.6, 0.06), CFrame.new(0.3, 1.8, 0.2), TANK_DARK)
	return parts
end

local function placeTank(job)
	local cf = job.CFrame
	for _, e in ipairs(job.Parts) do
		e.Part.CFrame = cf * e.Offset
	end
end

local function spawnTank(data)
	local dir = data.Direction or Vector3.new(0, 0, -1)
	local job = { Parts = buildTank(), CFrame = CFrame.lookAt(data.Position, data.Position + dir), Goal = CFrame.lookAt(data.Position, data.Position + dir), NextShout = os.clock() + 1.2 }
	tanks[data.Id] = job
	placeTank(job)
	local anchor = job.Parts[1].Part
	label(anchor, "LOOK HERE!", FIRE_HOT, 1.2, 200, Vector3.new(0, 2.5, 0))
	-- Never left behind.
	task.delay(12, function()
		if tanks[data.Id] == job then
			tanks[data.Id] = nil
			for _, e in ipairs(job.Parts) do
				e.Part:Destroy()
			end
		end
	end)
end

local function stepTanks(dt)
	for _, job in pairs(tanks) do
		job.CFrame = job.CFrame:Lerp(job.Goal, math.min(1, dt * 10))
		placeTank(job)
		if os.clock() >= job.NextShout then
			job.NextShout = os.clock() + 1.6
			label(job.Parts[1].Part, "LOOK HERE!", FIRE_HOT, 1.0, 170, Vector3.new(0, 2.5, 0))
		end
	end
end

---------------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------------
local function onM1(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local index = data.Index or 1
	TuskAnimation.play(character, "KR_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1, -3.2), Duration = 0.28 })
	VFXLib.sound(sounds.Swing, root, 0.5, 1.05 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or pal.Second)
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "FirstBomb" then
		if phase == "Reach" and character and root then
			TuskAnimation.play(character, "KRReach")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0.5, 1, -3.2), Duration = (data.Windup or 0.2) + 0.35 })
		elseif phase == "Touch" and typeof(data.Target) == "Instance" then
			local target = data.Target
			unmark(target)
			local h = Instance.new("Highlight")
			h.Name = "KillerQueenBomb"
			h.FillColor = PINK
			h.FillTransparency = 0.8
			h.OutlineColor = PINK
			h.Adornee = target
			h.Parent = target
			local bb = skullOver(target, data.Time or 8, PINK)
			bombs[target] = { Highlight = h, Label = bb }
			VFXLib.animate(data.Time or 8, function()
				if h.Parent then
					h.OutlineTransparency = 0.2 + 0.4 * (0.5 + 0.5 * math.sin(os.clock() * 7))
				end
			end, function()
				if bombs[target] and bombs[target].Highlight == h then
					unmark(target)
				end
			end)
			if data.Position then
				TuskVFX.CreateImpactStar(data.Position, { Size = 2, Rays = 5, Color = PINK, Color2 = Color3.new(1, 1, 1), Duration = 0.12 })
			end
			label(target:FindFirstChild("Head"), "KILLER QUEEN HAS ALREADY TOUCHED IT", PINK, 1.8, 360, Vector3.new(0, 4, 0))
		elseif phase == "Click" and character and root then
			TuskAnimation.play(character, "KRClick")
			label(character:FindFirstChild("Head"), "CLICK", Color3.new(1, 1, 1), 0.8, 140, Vector3.new(1.5, 1.5, 0))
		elseif phase == "Boom" and data.Position then
			for target in pairs(bombs) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr and (tr.Position - data.Position).Magnitude < 6 then
					unmark(target)
				end
			end
			explosion(data.Position, data.Radius or 7)
		elseif phase == "Fizzle" and typeof(data.Target) == "Instance" then
			unmark(data.Target)
		elseif phase == "Miss" and data.Position then
			VFXLib.burst(data.Position, { Count = 5, Color = PINK, Speed = 8, Lifetime = 0.25 })
		end
	elseif move == "SheerHeartAttack" then
		if phase == "Summon" and character and root then
			TuskAnimation.play(character, "KRSummon")
			label(character:FindFirstChild("Head"), "SHEER HEART ATTACK", LILAC, 1.4, 300)
		elseif phase == "Spawn" and data.Position and data.Id then
			spawnTank(data)
		elseif phase == "Move" and data.Id and tanks[data.Id] and data.Position then
			local dir = data.Direction or Vector3.new(0, 0, -1)
			tanks[data.Id].Goal = CFrame.lookAt(data.Position, data.Position + dir)
		elseif phase == "Explode" and data.Position then
			local job = data.Id and tanks[data.Id]
			if job then
				tanks[data.Id] = nil
				for _, e in ipairs(job.Parts) do
					e.Part:Destroy()
				end
			end
			explosion(data.Position + Vector3.new(0, 1, 0), data.Radius or 9)
		end
	elseif move == "StrayCat" then
		if phase == "Blow" and character and root then
			TuskAnimation.play(character, "KRBlow")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0.6, 1, -2.6), Duration = (data.Windup or 0.25) + 0.3 })
		elseif phase == "Fire" and data.From then
			for k, dir in ipairs(data.Directions or {}) do
				local id = data.Ids and data.Ids[k]
				local b = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(data.From), Color = Color3.fromRGB(220, 235, 255), Material = Enum.Material.Glass, Transparency = 0.75 })
				local job = { Part = b }
				if id then
					bubbles[id] = job
				end
				local from, speed = data.From, data.Speed or 18
				VFXLib.animate(data.Life or 3, function(a)
					if not b.Parent then
						return
					end
					local t = a * (data.Life or 3)
					local wobble = 1 + 0.08 * math.sin(os.clock() * 9 + k)
					b.Size = Vector3.new(2 * wobble, 2 / wobble, 2 * wobble)
					b.CFrame = CFrame.new(from + dir * speed * t + Vector3.new(0, math.sin(t * 3 + k) * 0.3, 0))
				end, function()
					if b.Parent then
						b:Destroy()
					end
					if id and bubbles[id] == job then
						bubbles[id] = nil
					end
				end)
			end
		elseif phase == "Pop" then
			local job = data.Id and bubbles[data.Id]
			if job then
				bubbles[data.Id] = nil
				if job.Part.Parent then
					job.Part:Destroy()
				end
			end
			if data.Position then
				if data.Hit then
					explosion(data.Position, 6)
				else
					VFXLib.burst(data.Position, { Count = 6, Color = Color3.fromRGB(220, 235, 255), Speed = 8, Lifetime = 0.25 })
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- BITES THE DUST
---------------------------------------------------------------------------
local function clockRing(at, backwards)
	local ring = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(at), Color = LILAC, Material = Enum.Material.ForceField, Transparency = 0.4 })
	VFXLib.animate(0.7, function(a)
		local k = backwards and (1 - a) or a
		local d = 80 * VFXLib.easeOut(k)
		ring.Size = Vector3.new(d, d, d)
		ring.Transparency = 0.4 + 0.6 * a
	end, function()
		ring:Destroy()
	end)
	-- A clock hand sweeping anticlockwise.
	local hand = VFXLib.part({ Size = Vector3.new(0.3, 0.1, 8), Color = Color3.fromRGB(240, 220, 255), Transparency = 0.2 })
	VFXLib.animate(0.9, function(a)
		local ang = (backwards and -1 or 1) * a * math.pi * 4
		hand.CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -4)
		hand.Transparency = 0.2 + 0.8 * a
	end, function()
		hand:Destroy()
	end)
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character and root then
		TuskAnimation.play(character, "KRBTD")
		TuskStand.action(character, "Loom", { Target = CFrame.new(1.4, 2.4, 2.2), Duration = (data.Windup or 0.8) + 0.6 })
		label(character:FindFirstChild("Head"), "KILLER QUEEN: BITES THE DUST", LILAC, 2.2, 400)
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 0.85)
	elseif data.Phase == "Set" then
		for _, target in ipairs(data.Marked or {}) do
			if typeof(target) == "Instance" and target.Parent then
				local old = marks[target]
				if old and old.Parent then
					old:Destroy()
				end
				marks[target] = skullOver(target, (data.Delay or 3) + 0.3, Color3.fromRGB(255, 120, 150))
			end
		end
		if data.Position then
			clockRing(data.Position, false)
		end
	elseif data.Phase == "Boom" then
		for target, bb in pairs(marks) do
			if bb.Parent then
				bb:Destroy()
			end
			marks[target] = nil
		end
		for _, at in ipairs(data.Positions or {}) do
			explosion(at, 6)
		end
	elseif data.Phase == "Rewind" and data.Position then
		-- Time goes back (for him).
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "BitesTheDust"
		cc.Parent = Lighting
		VFXLib.animate(0.8, function(a)
			local k = 1 - a
			cc.Saturation = -0.7 * k
			cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(220, 190, 255), k)
		end, function()
			cc:Destroy()
		end)
		clockRing(data.Position, true)
		if character then
			label(character:FindFirstChild("Head"), "TIME REWINDS", Color3.new(1, 1, 1), 1.4, 240)
			if character == (localPlayer and localPlayer.Character) then
				CameraFX.fovPunch(-10, 0.5)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local function stepStance()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character then
			local want = character:GetAttribute("TuskAct") == ACT
			if want and not stanced[character] then
				stanced[character] = true
				TuskAnimation.hold(character, "KiraStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "KiraStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
	for target in pairs(bombs) do
		if not target.Parent then
			unmark(target)
		end
	end
end

function KiraVFX.handle(name, data)
	if name == "M1" then
		onM1(data)
	elseif name == "M1Finisher" then
		onFinisher(data)
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

local slowTimer = 0
function KiraVFX.step(dt)
	dt = dt or 1 / 60
	stepTanks(dt)
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
	end
end

return KiraVFX
end
end
