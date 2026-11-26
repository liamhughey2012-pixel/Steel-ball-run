--[[
	TuskActVFX.CrazyDiamondStand  (StarterPlayerScripts.SpinClient.TuskActVFX.CrazyDiamondStand)

	CRAZY DIAMOND (Josuke Higashikata, Part 4), blocky, matched to the art:
	  * a big, muscular PINK body under pale blue-white ARMOUR plates
	  * a flat-topped pale HELMET round a pink face: glowing cyan eyes, a
	    grilled mouth, and a HEART-shaped chin plate; thick white TUBES run
	    from the back of its head down to its shoulders
	  * heavy armoured shoulders with SPIKES, a split chestplate, a white
	    belly plate with a pink heart, a belt with a heart buckle
	  * armoured forearms and fists with a row of round STUDS across the
	    knuckles and a heart on the back of each hand
	  * pink legs with pale knee and shin guards
	Registered with TuskStandModels by Josuke4VFX, so TuskStand floats it
	behind Josuke with a pink aura.
]]

local CrazyDiamondStand = {}

local PINK = Color3.fromRGB(232, 120, 182)
local PINK_SHADE = Color3.fromRGB(188, 78, 146)
local PINK_LIGHT = Color3.fromRGB(250, 168, 210)
local PLATE = Color3.fromRGB(204, 226, 244)
local PLATE_SHADE = Color3.fromRGB(150, 188, 222)
local PLATE_LIGHT = Color3.fromRGB(242, 250, 255)
local EYE = Color3.fromRGB(130, 240, 255)
local DARK = Color3.fromRGB(60, 40, 70)

CrazyDiamondStand.Aura = Color3.fromRGB(255, 130, 200)
CrazyDiamondStand.AuraLight = Color3.fromRGB(255, 220, 240)
CrazyDiamondStand.Offset = CFrame.new(2.2, 1.6, 2.8)

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

-- A heart facing forward (-Z): two round lobes and a point.
local function heart(model, parent, cf, size, color)
	for _, side in ipairs({ -1, 1 }) do
		local lobe = box(model, parent, "HeartLobe", Vector3.new(0.06, size * 0.56, size * 0.56), color, cf * CFrame.new(side * size * 0.22, size * 0.12, 0) * CFrame.Angles(0, math.pi / 2, 0))
		lobe.Shape = Enum.PartType.Cylinder
	end
	box(model, parent, "HeartPoint", Vector3.new(size * 0.56, size * 0.56, 0.06), color, cf * CFrame.new(0, -size * 0.12, 0) * CFrame.Angles(0, 0, math.pi / 4))
end

function CrazyDiamondStand.build(scale)
	local s = (scale or 1) * 0.9
	local model = Instance.new("Model")
	model.Name = "CrazyDiamond"
	local rig = { Joints = {} }

	-- A broad pink torso under the armour.
	local torso = newPart(model, "Body", Vector3.new(2.35, 1.9, 1.12) * s, PINK)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.56 * s
	-- A split chestplate.
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Chestplate", Vector3.new(1.0, 0.85, 0.2) * s, PLATE, CFrame.new(side * 0.56 * s, 0.38 * s, front - 0.06 * s) * CFrame.Angles(0, side * 0.12, 0))
		box(model, torso, "PlateEdge", Vector3.new(1.0, 0.08, 0.22) * s, PLATE_SHADE, CFrame.new(side * 0.56 * s, -0.04 * s, front - 0.06 * s) * CFrame.Angles(0, side * 0.12, 0))
		box(model, torso, "PlateShine", Vector3.new(0.5, 0.08, 0.21) * s, PLATE_LIGHT, CFrame.new(side * 0.5 * s, 0.68 * s, front - 0.08 * s) * CFrame.Angles(0, side * 0.12, 0))
		box(model, torso, "Lat", Vector3.new(0.2, 1.3, 0.9) * s, PINK_SHADE, CFrame.new(side * 1.2 * s, -0.1 * s, 0))
	end
	box(model, torso, "Sternum", Vector3.new(0.12, 0.9, 0.16) * s, PINK_SHADE, CFrame.new(0, 0.35 * s, front - 0.03 * s))
	-- The belly: a white plate with a pink heart on it.
	box(model, torso, "Waist", Vector3.new(1.75, 0.85, 0.95) * s, PINK, CFrame.new(0, -1.3 * s, 0))
	box(model, torso, "BellyPlate", Vector3.new(1.0, 0.85, 0.14) * s, PLATE_LIGHT, CFrame.new(0, -0.6 * s, front - 0.02 * s))
	heart(model, torso, CFrame.new(0, -0.58 * s, front - 0.11 * s), 0.55 * s, PINK)
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Oblique", Vector3.new(0.3, 0.75, 0.1) * s, PINK_LIGHT, CFrame.new(side * 0.68 * s, -0.75 * s, front + 0.02 * s))
	end
	-- Belt with a heart buckle.
	box(model, torso, "Belt", Vector3.new(1.85, 0.3, 1.05) * s, PLATE, CFrame.new(0, -1.7 * s, 0))
	box(model, torso, "BeltLine", Vector3.new(1.87, 0.06, 1.07) * s, PLATE_SHADE, CFrame.new(0, -1.6 * s, 0))
	heart(model, torso, CFrame.new(0, -1.7 * s, -0.56 * s), 0.38 * s, PINK)
	box(model, torso, "Hips", Vector3.new(1.75, 0.5, 0.95) * s, PINK_SHADE, CFrame.new(0, -2.0 * s, 0))
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "HipPlate", Vector3.new(0.6, 0.55, 0.1) * s, PLATE, CFrame.new(side * 0.6 * s, -2.05 * s, -0.5 * s) * CFrame.Angles(math.rad(-8), 0, side * -0.15))
	end
	box(model, torso, "Neck", Vector3.new(0.65, 0.45, 0.6) * s, PINK_SHADE, CFrame.new(0, 1.12 * s, 0))
	box(model, torso, "Gorget", Vector3.new(1.1, 0.25, 0.9) * s, PLATE_SHADE, CFrame.new(0, 0.98 * s, 0))

	-- Heavy armoured shoulders with spikes.
	for _, side in ipairs({ -1, 1 }) do
		local cf = CFrame.new(side * 1.45 * s, 0.82 * s, 0) * CFrame.Angles(0, 0, side * -0.35)
		box(model, torso, "Pauldron", Vector3.new(1.05, 0.62, 1.15) * s, PLATE, cf)
		box(model, torso, "PauldronRim", Vector3.new(1.08, 0.12, 1.18) * s, PLATE_SHADE, cf * CFrame.new(0, -0.3 * s, 0))
		box(model, torso, "PauldronShine", Vector3.new(0.7, 0.06, 0.9) * s, PLATE_LIGHT, cf * CFrame.new(0, 0.32 * s, 0))
		for k = -1, 1, 2 do
			local spike = box(model, torso, "Spike", Vector3.new(0.18, 0.55, 0.18) * s, PLATE_LIGHT, cf * CFrame.new(side * 0.15 * s, 0.5 * s, k * 0.28 * s) * CFrame.Angles(0, 0, side * -0.35) * CFrame.Angles(0, math.pi / 4, 0))
			box(model, spike, "SpikeTip", Vector3.new(0.1, 0.25, 0.1) * s, PLATE_LIGHT, CFrame.new(0, 0.35 * s, 0))
		end
	end

	-- Head: a flat-topped pale helmet round a pink face, a heart chin.
	local headBase = CFrame.new(0, 1.3 * s, 0)
	local headOffset = CFrame.new(0, 0.55 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.82, 1.0, 0.85) * s, PINK, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.43 * s
	box(model, head, "Helmet", Vector3.new(0.92, 0.55, 0.92) * s, PLATE, CFrame.new(0, 0.34 * s, 0.02 * s))
	box(model, head, "HelmetTop", Vector3.new(0.98, 0.12, 0.98) * s, PLATE_LIGHT, CFrame.new(0, 0.62 * s, 0.02 * s))
	box(model, head, "HelmetBack", Vector3.new(0.92, 0.9, 0.2) * s, PLATE, CFrame.new(0, 0.05 * s, 0.4 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "HelmetSide", Vector3.new(0.12, 0.85, 0.85) * s, PLATE, CFrame.new(side * 0.46 * s, 0.05 * s, 0.03 * s))
		box(model, head, "Brow", Vector3.new(0.34, 0.1, 0.12) * s, PLATE_SHADE, CFrame.new(side * 0.2 * s, 0.1 * s, hf - 0.05 * s) * CFrame.Angles(0, 0, side * 0.22))
		box(model, head, "Eye", Vector3.new(0.22, 0.08, 0.05) * s, EYE, CFrame.new(side * 0.18 * s, 0.0, hf - 0.03 * s) * CFrame.Angles(0, 0, side * -0.15), Enum.Material.Neon)
	end
	box(model, head, "BrowCrest", Vector3.new(0.12, 0.3, 0.14) * s, PLATE_LIGHT, CFrame.new(0, 0.2 * s, hf - 0.06 * s))
	-- A grilled mouth.
	box(model, head, "Mouth", Vector3.new(0.4, 0.16, 0.05) * s, DARK, CFrame.new(0, -0.2 * s, hf - 0.02 * s))
	for k = -2, 2 do
		box(model, head, "Grill", Vector3.new(0.03, 0.17, 0.06) * s, PINK_LIGHT, CFrame.new(k * 0.08 * s, -0.2 * s, hf - 0.03 * s))
	end
	-- The heart-shaped chin plate.
	heart(model, head, CFrame.new(0, -0.42 * s, hf - 0.02 * s), 0.42 * s, PLATE)
	-- Thick tubes from the back of its head down to its shoulders.
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 1 do
			local a = Vector3.new(side * (0.18 + k * 0.14), (1.75 - k * 0.1), 0.48 + k * 0.05) * s
			local m = Vector3.new(side * (0.42 + k * 0.18), 1.25, 0.72 + k * 0.08) * s
			local b = Vector3.new(side * (0.85 + k * 0.2), 0.95, 0.5) * s
			tube(model, torso, a, m, 0.17 * s, k == 0 and PLATE_LIGHT or PLATE_SHADE)
			tube(model, torso, m, b, 0.17 * s, k == 0 and PLATE_LIGHT or PLATE_SHADE)
		end
	end

	-- Big arms: armoured forearms, fists with studs across the knuckles.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.55 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.72, 2.2, 0.72) * s, PINK, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Bicep", Vector3.new(0.84, 0.75, 0.84) * s, PINK_LIGHT, CFrame.new(0, 0.45 * s, -0.03 * s))
		box(model, arm, "Elbow", Vector3.new(0.7, 0.2, 0.7) * s, PINK_SHADE, CFrame.new(0, 0, 0))
		box(model, arm, "Gauntlet", Vector3.new(0.88, 0.85, 0.88) * s, PLATE, CFrame.new(0, -0.55 * s, 0))
		box(model, arm, "GauntletRim", Vector3.new(0.92, 0.1, 0.92) * s, PLATE_SHADE, CFrame.new(0, -0.14 * s, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.78, 0.66, 0.72) * s, PLATE_LIGHT, CFrame.new(0, -1.3 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.16, 0.3, 0.16) * s, PLATE, CFrame.new(f * 0.18 * s, -0.4 * s, -0.12 * s))
			ball(model, hand, "Stud", 0.17 * s, PINK, CFrame.new(f * 0.18 * s, -0.2 * s, -0.38 * s))
		end
		heart(model, hand, CFrame.new(0, 0.02 * s, 0.37 * s) * CFrame.Angles(0, math.pi, 0), 0.3 * s, PINK)
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: pink, pale knee and shin guards.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.5 * s, -2.15 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.76, 2.4, 0.76) * s, PINK, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Thigh", Vector3.new(0.88, 0.95, 0.88) * s, PINK_LIGHT, CFrame.new(0, 0.65 * s, 0))
		box(model, leg, "KneePad", Vector3.new(0.6, 0.45, 0.2) * s, PLATE, CFrame.new(0, 0.02 * s, -0.42 * s))
		box(model, leg, "Shin", Vector3.new(0.82, 0.75, 0.84) * s, PLATE, CFrame.new(0, -0.6 * s, 0))
		box(model, leg, "ShinShine", Vector3.new(0.3, 0.6, 0.06) * s, PLATE_LIGHT, CFrame.new(0, -0.6 * s, -0.44 * s))
		box(model, leg, "Foot", Vector3.new(0.72, 0.32, 1.05) * s, PLATE_SHADE, CFrame.new(0, -1.3 * s, -0.17 * s))
	end
	return model, rig
end

return CrazyDiamondStand
