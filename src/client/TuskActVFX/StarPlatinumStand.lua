--[[
	TuskActVFX.StarPlatinumStand  (StarterPlayerScripts.SpinClient.TuskActVFX.StarPlatinumStand)

	STAR PLATINUM (Jotaro Kujo), blocky, matched to the art:
	  * a huge, muscular blue-violet body: broad chest, a six-pack, big arms
	  * a fierce face (glowing pale eyes, a strong jaw) under a GOLD
	    HEADBAND with a gem; long, wild BLACK HAIR streaming back and up
	  * a RED SCARF knotted at the throat, its ends flying out behind
	  * round GOLD SHOULDER GUARDS with a spiral on each
	  * black fingerless gloves with gold cuffs; gold bands at the elbows
	  * a gold belt with a long WHITE LOINCLOTH hanging front and back
	  * bare blue legs with gold knee bands
	Registered with TuskStandModels by JotaroVFX, so TuskStand floats it
	behind Jotaro with a violet aura.
]]

local StarPlatinumStand = {}

local SKIN = Color3.fromRGB(116, 118, 222)
local SKIN_SHADE = Color3.fromRGB(80, 80, 176)
local SKIN_LIGHT = Color3.fromRGB(156, 162, 244)
local GOLD = Color3.fromRGB(240, 196, 70)
local GOLD_SHADE = Color3.fromRGB(196, 148, 40)
local HAIR = Color3.fromRGB(24, 22, 34)
local HAIR_SHINE = Color3.fromRGB(60, 56, 92)
local SCARF = Color3.fromRGB(214, 58, 40)
local SCARF_SHADE = Color3.fromRGB(160, 36, 26)
local CLOTH = Color3.fromRGB(240, 240, 236)
local CLOTH_SHADE = Color3.fromRGB(196, 198, 206)
local GLOVE = Color3.fromRGB(30, 34, 40)
local EYE = Color3.fromRGB(220, 250, 255)
local GEM = Color3.fromRGB(90, 220, 200)

StarPlatinumStand.Aura = Color3.fromRGB(150, 120, 255)
StarPlatinumStand.AuraLight = Color3.fromRGB(220, 210, 255)
StarPlatinumStand.Offset = CFrame.new(2.2, 1.6, 2.8)

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

local function cyl(model, parent, name, length, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(length, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A round gold shoulder guard with a spiral (rings stepping in and up).
local function pauldron(model, torso, side, s)
	local cf = CFrame.new(side * 1.42 * s, 0.82 * s, 0) * CFrame.Angles(0, 0, side * -0.5) * CFrame.Angles(0, 0, math.pi / 2)
	cyl(model, torso, "Pauldron", 0.32 * s, 1.35 * s, GOLD, cf, Enum.Material.Metal)
	for k = 1, 3 do
		cyl(model, torso, "Spiral", 0.06 * s, (1.35 - k * 0.32) * s, k % 2 == 1 and GOLD_SHADE or GOLD, cf * CFrame.new((0.16 + k * 0.03) * s, (k - 2) * 0.05 * s, 0), Enum.Material.Metal)
	end
	cyl(model, torso, "SpiralEye", 0.08 * s, 0.18 * s, GOLD_SHADE, cf * CFrame.new(0.3 * s, 0, 0), Enum.Material.Metal)
end

function StarPlatinumStand.build(scale)
	local s = (scale or 1) * 0.9
	local model = Instance.new("Model")
	model.Name = "StarPlatinum"
	local rig = { Joints = {} }

	-- A broad, heavy torso.
	local torso = newPart(model, "Body", Vector3.new(2.4, 1.9, 1.15) * s, SKIN)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.58 * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Pec", Vector3.new(1.0, 0.62, 0.14) * s, SKIN_LIGHT, CFrame.new(side * 0.52 * s, 0.42 * s, front - 0.04 * s))
		box(model, torso, "PecLine", Vector3.new(1.0, 0.06, 0.15) * s, SKIN_SHADE, CFrame.new(side * 0.52 * s, 0.1 * s, front - 0.045 * s))
		box(model, torso, "Lat", Vector3.new(0.2, 1.3, 0.9) * s, SKIN_SHADE, CFrame.new(side * 1.2 * s, -0.1 * s, 0))
	end
	box(model, torso, "Sternum", Vector3.new(0.05, 0.6, 0.15) * s, SKIN_SHADE, CFrame.new(0, 0.42 * s, front - 0.05 * s))
	-- Six-pack.
	box(model, torso, "Waist", Vector3.new(1.75, 0.85, 0.95) * s, SKIN, CFrame.new(0, -1.3 * s, 0))
	for k = 0, 2 do
		for _, side in ipairs({ -1, 1 }) do
			box(model, torso, "Ab", Vector3.new(0.38, 0.24, 0.08) * s, SKIN_LIGHT, CFrame.new(side * 0.22 * s, (-0.22 - k * 0.32) * s, front - 0.02 * s))
		end
	end
	box(model, torso, "AbLine", Vector3.new(0.05, 1.0, 0.09) * s, SKIN_SHADE, CFrame.new(0, -0.55 * s, front - 0.025 * s))
	-- Gold belt and the long white loincloth, front and back.
	box(model, torso, "Belt", Vector3.new(1.85, 0.3, 1.05) * s, GOLD, CFrame.new(0, -1.7 * s, 0), Enum.Material.Metal)
	box(model, torso, "BeltBuckle", Vector3.new(0.4, 0.34, 0.08) * s, GOLD_SHADE, CFrame.new(0, -1.7 * s, -0.55 * s), Enum.Material.Metal)
	box(model, torso, "Hips", Vector3.new(1.75, 0.5, 0.95) * s, SKIN_SHADE, CFrame.new(0, -2.0 * s, 0))
	box(model, torso, "Loincloth", Vector3.new(0.9, 1.9, 0.06) * s, CLOTH, CFrame.new(0, -2.75 * s, -0.55 * s) * CFrame.Angles(math.rad(-4), 0, 0))
	box(model, torso, "LoinFold", Vector3.new(0.05, 1.8, 0.07) * s, CLOTH_SHADE, CFrame.new(0.2 * s, -2.75 * s, -0.56 * s) * CFrame.Angles(math.rad(-4), 0, 0))
	box(model, torso, "LoinBack", Vector3.new(1.1, 1.6, 0.06) * s, CLOTH, CFrame.new(0, -2.6 * s, 0.55 * s) * CFrame.Angles(math.rad(8), 0, 0))
	box(model, torso, "Neck", Vector3.new(0.65, 0.45, 0.6) * s, SKIN_SHADE, CFrame.new(0, 1.12 * s, 0))
	-- The red scarf: knotted at the throat, the ends flying out behind.
	box(model, torso, "Scarf", Vector3.new(0.95, 0.3, 0.85) * s, SCARF, CFrame.new(0, 1.08 * s, 0))
	box(model, torso, "ScarfKnot", Vector3.new(0.35, 0.3, 0.2) * s, SCARF_SHADE, CFrame.new(0.15 * s, 0.95 * s, -0.45 * s) * CFrame.Angles(0, 0, 0.3))
	box(model, torso, "ScarfEnd", Vector3.new(0.4, 1.1, 0.07) * s, SCARF, CFrame.new(0.3 * s, 0.6 * s, 0.85 * s) * CFrame.Angles(math.rad(55), 0, math.rad(-15)))
	box(model, torso, "ScarfEnd", Vector3.new(0.34, 0.9, 0.07) * s, SCARF_SHADE, CFrame.new(-0.2 * s, 0.65 * s, 0.8 * s) * CFrame.Angles(math.rad(60), 0, math.rad(20)))
	for _, side in ipairs({ -1, 1 }) do
		pauldron(model, torso, side, s)
	end

	-- Head: a fierce face under a gold headband; long wild black hair.
	local headBase = CFrame.new(0, 1.3 * s, 0)
	local headOffset = CFrame.new(0, 0.52 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.8, 0.95, 0.82) * s, SKIN, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.41 * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.2, 0.08, 0.05) * s, EYE, CFrame.new(side * 0.18 * s, 0.08 * s, hf - 0.02 * s) * CFrame.Angles(0, 0, side * -0.18), Enum.Material.Neon)
		box(model, head, "Brow", Vector3.new(0.26, 0.07, 0.07) * s, SKIN_SHADE, CFrame.new(side * 0.18 * s, 0.17 * s, hf - 0.03 * s) * CFrame.Angles(0, 0, side * 0.25))
		box(model, head, "Cheek", Vector3.new(0.05, 0.3, 0.05) * s, SKIN_SHADE, CFrame.new(side * 0.3 * s, -0.15 * s, hf - 0.02 * s))
	end
	box(model, head, "Nose", Vector3.new(0.1, 0.24, 0.1) * s, SKIN_SHADE, CFrame.new(0, -0.04 * s, hf - 0.04 * s))
	box(model, head, "Mouth", Vector3.new(0.26, 0.05, 0.05) * s, SKIN_SHADE, CFrame.new(0, -0.27 * s, hf - 0.02 * s))
	box(model, head, "Jaw", Vector3.new(0.7, 0.22, 0.6) * s, SKIN, CFrame.new(0, -0.48 * s, -0.05 * s))
	-- Gold headband with a gem.
	box(model, head, "Headband", Vector3.new(0.88, 0.14, 0.9) * s, GOLD, CFrame.new(0, 0.3 * s, 0), Enum.Material.Metal)
	box(model, head, "Gem", Vector3.new(0.14, 0.14, 0.06) * s, GEM, CFrame.new(0, 0.3 * s, hf - 0.06 * s) * CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Neon)
	-- Hair: a cap, then long locks streaming back and up.
	box(model, head, "HairCap", Vector3.new(0.92, 0.3, 0.92) * s, HAIR, CFrame.new(0, 0.5 * s, 0.04 * s))
	-- { x, y, z, length, tilt back (degrees), spread sideways (degrees) }
	local locks = {
		{ 0, 0.7, 0.1, 1.2, 35, 0 }, { -0.3, 0.62, 0.15, 1.15, 48, -22 }, { 0.3, 0.62, 0.15, 1.15, 48, 22 },
		{ -0.4, 0.4, 0.3, 1.5, 70, -35 }, { 0.4, 0.4, 0.3, 1.5, 70, 35 }, { 0, 0.35, 0.4, 1.8, 82, 0 },
		{ -0.25, 0.1, 0.42, 1.7, 100, -18 }, { 0.25, 0.1, 0.42, 1.7, 100, 18 }, { 0, -0.1, 0.45, 1.5, 120, 0 },
	}
	for i, l in ipairs(locks) do
		local cf = CFrame.new(l[1] * s, l[2] * s, l[3] * s) * CFrame.Angles(math.rad(l[5]), 0, math.rad(-l[6])) * CFrame.new(0, l[4] * 0.5 * s, 0)
		box(model, head, "Hair", Vector3.new(0.38, l[4], 0.26) * s, i % 3 == 0 and HAIR_SHINE or HAIR, cf)
		box(model, head, "HairTip", Vector3.new(0.18, 0.3, 0.14) * s, HAIR, cf * CFrame.new(0, l[4] * 0.55 * s, 0) * CFrame.Angles(0, 0, 0.3))
	end
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "SideLock", Vector3.new(0.12, 0.6, 0.3) * s, HAIR, CFrame.new(side * 0.45 * s, 0.05 * s, 0.1 * s) * CFrame.Angles(0, 0, side * 0.15))
	end

	-- Huge arms: gold elbow bands, black fingerless gloves with gold cuffs.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.55 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.72, 2.2, 0.72) * s, SKIN, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Delt", Vector3.new(0.9, 0.6, 0.88) * s, SKIN_LIGHT, CFrame.new(0, 0.85 * s, 0))
		box(model, arm, "Bicep", Vector3.new(0.82, 0.65, 0.82) * s, SKIN_LIGHT, CFrame.new(0, 0.35 * s, -0.04 * s))
		box(model, arm, "ElbowBand", Vector3.new(0.8, 0.1, 0.8) * s, GOLD, CFrame.new(0, -0.05 * s, 0), Enum.Material.Metal)
		box(model, arm, "Forearm", Vector3.new(0.8, 0.7, 0.8) * s, SKIN, CFrame.new(0, -0.5 * s, 0))
		box(model, arm, "Cuff", Vector3.new(0.84, 0.16, 0.84) * s, GOLD, CFrame.new(0, -0.9 * s, 0), Enum.Material.Metal)
		local hand = box(model, arm, "Hand", Vector3.new(0.68, 0.6, 0.62) * s, GLOVE, CFrame.new(0, -1.3 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.13, 0.36, 0.14) * s, SKIN, CFrame.new(f * 0.15 * s, -0.38 * s, -0.08 * s))
		end
		box(model, hand, "Knuckles", Vector3.new(0.7, 0.14, 0.18) * s, GOLD_SHADE, CFrame.new(0, -0.15 * s, -0.3 * s), Enum.Material.Metal)
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: bare and blue, gold knee bands.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.5 * s, -2.15 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.76, 2.4, 0.76) * s, SKIN, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Thigh", Vector3.new(0.86, 0.95, 0.86) * s, SKIN_LIGHT, CFrame.new(0, 0.65 * s, 0))
		box(model, leg, "KneeBand", Vector3.new(0.82, 0.12, 0.82) * s, GOLD, CFrame.new(0, 0.02 * s, 0), Enum.Material.Metal)
		box(model, leg, "Calf", Vector3.new(0.72, 0.7, 0.8) * s, SKIN_SHADE, CFrame.new(0, -0.55 * s, 0.03 * s))
		box(model, leg, "Foot", Vector3.new(0.68, 0.3, 1.0) * s, SKIN, CFrame.new(0, -1.3 * s, -0.17 * s))
	end
	return model, rig
end

return StarPlatinumStand
