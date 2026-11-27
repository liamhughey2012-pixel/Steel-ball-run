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
