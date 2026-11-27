--[[
	TuskActVFX.KillerQueenStand  (StarterPlayerScripts.SpinClient.TuskActVFX.KillerQueenStand)

	KILLER QUEEN (Yoshikage Kira, Part 4), blocky, matched to the art:
	  * a lean, muscular light PINK body: segmented arms, a six-pack, a
	    crease running diagonally across the chest
	  * a cat-like head: tall pointed CAT EARS, big pink eyes, a plain face
	    with a small mouth
	  * studded NAVY BRACERS on both forearms with a GOLD SKULL on each, and
	    a gold skull-in-a-SUN emblem on its left upper arm
	  * a wide navy belt with silver studs and a big oval GOLD SKULL BUCKLE,
	    over navy shorts
	  * pink legs
	Registered with TuskStandModels by KiraVFX, so TuskStand floats it behind
	Kira with a pink aura.
]]

local KillerQueenStand = {}

local PINK = Color3.fromRGB(238, 172, 226)
local PINK_SHADE = Color3.fromRGB(204, 130, 196)
local PINK_LIGHT = Color3.fromRGB(252, 210, 244)
local DARK = Color3.fromRGB(42, 38, 74) -- navy
local GOLD = Color3.fromRGB(236, 184, 60)
local GOLD_DARK = Color3.fromRGB(170, 116, 30)
local STUD = Color3.fromRGB(214, 216, 232)
local EYE = Color3.fromRGB(246, 196, 250)

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

-- A gold medallion with a skull on it, facing forward (-Z).
local function skull(model, parent, cf, size)
	local disc = box(model, parent, "Medallion", Vector3.new(0.06, size * 1.25, size), GOLD, cf * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Metal)
	disc.Shape = Enum.PartType.Cylinder
	box(model, parent, "MedallionRim", Vector3.new(0.05, size * 1.35, size * 1.1), GOLD_DARK, cf * CFrame.new(0, 0, 0.02) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Metal).Shape = Enum.PartType.Cylinder
	egg(model, parent, "Skull", Vector3.new(size * 0.6, size * 0.6, 0.08), GOLD_DARK, cf * CFrame.new(0, size * 0.08, -0.04), Enum.Material.Metal)
	box(model, parent, "SkullJaw", Vector3.new(size * 0.34, size * 0.2, 0.08), GOLD_DARK, cf * CFrame.new(0, -size * 0.25, -0.04), Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		egg(model, parent, "SkullEye", Vector3.new(size * 0.16, size * 0.18, 0.05), GOLD, cf * CFrame.new(side * size * 0.12, size * 0.1, -0.08), Enum.Material.Metal)
	end
end

-- A gold sun (a ring of rays) with a skull in the middle, facing forward (-Z).
local function sunSkull(model, parent, cf, size)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		box(model, parent, "SunRay", Vector3.new(size * 0.18, size * 0.3, 0.05), GOLD, cf * CFrame.Angles(0, 0, a) * CFrame.new(0, size * 0.55, 0) * CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Metal)
	end
	skull(model, parent, cf * CFrame.new(0, 0, -0.01), size * 0.8)
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
		box(model, torso, "Side", Vector3.new(0.16, 1.2, 0.8) * s, PINK_SHADE, CFrame.new(side * 1.0 * s, -0.1 * s, 0))
	end
	-- The crease running diagonally across the chest, and a six-pack.
	box(model, torso, "Crease", Vector3.new(2.0, 0.06, 0.12) * s, PINK_SHADE, CFrame.new(0, 0.3 * s, front - 0.06 * s) * CFrame.Angles(0, 0, -0.4))
	for k = 0, 2 do
		for _, side in ipairs({ -1, 1 }) do
			box(model, torso, "Ab", Vector3.new(0.34, 0.22, 0.08) * s, PINK_LIGHT, CFrame.new(side * 0.2 * s, (-0.25 - k * 0.3) * s, front - 0.01 * s))
		end
	end
	box(model, torso, "AbLine", Vector3.new(0.05, 0.9, 0.09) * s, PINK_SHADE, CFrame.new(0, -0.55 * s, front - 0.02 * s))
	box(model, torso, "Waist", Vector3.new(1.5, 0.8, 0.88) * s, PINK, CFrame.new(0, -1.25 * s, 0))
	-- The studded belt with a skull buckle.
	box(model, torso, "Belt", Vector3.new(1.66, 0.36, 1.0) * s, DARK, CFrame.new(0, -1.62 * s, 0))
	for k = -3, 3 do
		if math.abs(k) > 1 then
			ball(model, torso, "Stud", 0.11 * s, STUD, CFrame.new(k * 0.2 * s, -1.62 * s, -0.5 * s), Enum.Material.Metal)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			ball(model, torso, "Stud", 0.11 * s, STUD, CFrame.new(side * 0.83 * s, -1.62 * s, (-0.3 + k * 0.3) * s), Enum.Material.Metal)
		end
	end
	skull(model, torso, CFrame.new(0, -1.66 * s, -0.53 * s), 0.5 * s)
	box(model, torso, "Shorts", Vector3.new(1.6, 0.55, 0.94) * s, DARK, CFrame.new(0, -2.0 * s, 0))
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "ShortsLeg", Vector3.new(0.72, 0.35, 0.82) * s, DARK, CFrame.new(side * 0.42 * s, -2.3 * s, 0))
		for k = 0, 2 do
			ball(model, torso, "Stud", 0.08 * s, STUD, CFrame.new(side * (0.18 + k * 0.22) * s, -2.42 * s, -0.42 * s), Enum.Material.Metal)
		end
	end
	box(model, torso, "Neck", Vector3.new(0.5, 0.45, 0.5) * s, PINK_SHADE, CFrame.new(0, 1.1 * s, 0))

	-- A cat-like head: pointed ears, big slanted eyes, a dark crest.
	local headBase = CFrame.new(0, 1.25 * s, 0)
	local headOffset = CFrame.new(0, 0.5 * s, 0)
	local head, headWeld = egg(model, torso, "Head", Vector3.new(0.82, 0.98, 0.86) * s, PINK, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.42 * s
	for _, side in ipairs({ -1, 1 }) do
		-- Tall, pointed cat ears.
		local ear = CFrame.new(side * 0.24 * s, 0.55 * s, 0.05 * s) * CFrame.Angles(0, 0, side * -0.12)
		box(model, head, "Ear", Vector3.new(0.36, 0.3, 0.14) * s, PINK, ear)
		box(model, head, "EarMid", Vector3.new(0.24, 0.2, 0.14) * s, PINK, ear * CFrame.new(side * 0.03 * s, 0.2 * s, 0))
		box(model, head, "EarTip", Vector3.new(0.12, 0.14, 0.14) * s, PINK, ear * CFrame.new(side * 0.06 * s, 0.34 * s, 0))
		box(model, head, "EarInner", Vector3.new(0.16, 0.3, 0.15) * s, PINK_SHADE, ear * CFrame.new(side * 0.02 * s, 0.08 * s, -0.01 * s))
		-- Big pink eyes.
		local eye = CFrame.new(side * 0.19 * s, 0.06 * s, hf + 0.03 * s) * CFrame.Angles(0, 0, side * -0.22)
		egg(model, head, "Eye", Vector3.new(0.28, 0.2, 0.08) * s, EYE, eye, Enum.Material.Neon)
		egg(model, head, "Pupil", Vector3.new(0.1, 0.12, 0.09) * s, PINK_SHADE, eye)
		box(model, head, "EyeLine", Vector3.new(0.32, 0.035, 0.09) * s, PINK_SHADE, eye * CFrame.new(0, 0.1 * s, 0))
	end
	box(model, head, "Mouth", Vector3.new(0.16, 0.04, 0.06) * s, PINK_SHADE, CFrame.new(0, -0.3 * s, hf + 0.05 * s))
	box(model, head, "Nose", Vector3.new(0.05, 0.14, 0.06) * s, PINK_SHADE, CFrame.new(0, -0.1 * s, hf + 0.03 * s))

	-- Slim arms: dark stripes, studded wristbands, a skull on the right hand.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		egg(model, torso, "Shoulder", Vector3.new(0.75, 0.62, 0.75) * s, PINK_LIGHT, CFrame.new(side * 1.12 * s, 0.72 * s, 0))
		box(model, torso, "ShoulderLine", Vector3.new(0.06, 0.06, 0.7) * s, DARK, CFrame.new(side * 1.2 * s, 0.9 * s, 0))
		local base = CFrame.new(side * 1.2 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.05 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.5, 2.1, 0.5) * s, PINK, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		-- Segmented upper arm.
		for k = 0, 2 do
			box(model, arm, "Segment", Vector3.new(0.54, 0.04, 0.54) * s, PINK_SHADE, CFrame.new(0, (0.75 - k * 0.25) * s, 0))
		end
		-- A studded navy bracer with a gold skull.
		box(model, arm, "Bracer", Vector3.new(0.62, 0.8, 0.62) * s, DARK, CFrame.new(0, -0.6 * s, 0))
		for row = 0, 1 do
			studBand(model, arm, (-0.32 - row * 0.56) * s, 0.64 * s, 0.64 * s, 6)
		end
		skull(model, arm, CFrame.new(0, -0.6 * s, -0.33 * s), 0.3 * s)
		if a[1] == "ArmL" then
			sunSkull(model, arm, CFrame.new(-0.27 * s, 0.55 * s, 0) * CFrame.Angles(0, math.pi / 2, 0), 0.36 * s)
		end
		local hand = box(model, arm, "Hand", Vector3.new(0.5, 0.48, 0.42) * s, PINK, CFrame.new(0, -1.25 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.1, 0.3, 0.12) * s, PINK_SHADE, CFrame.new(f * 0.12 * s, -0.34 * s, -0.06 * s))
		end
		if a[1] == "ArmR" then
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
		box(model, leg, "Shin", Vector3.new(0.6, 0.8, 0.6) * s, PINK_SHADE, CFrame.new(0, -0.65 * s, 0.02 * s))
		box(model, leg, "Foot", Vector3.new(0.58, 0.28, 0.9) * s, PINK_SHADE, CFrame.new(0, -1.3 * s, -0.15 * s))
	end
	return model, rig
end

return KillerQueenStand
