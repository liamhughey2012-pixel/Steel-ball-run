--[[
	TuskActVFX.TheWorldStand  (StarterPlayerScripts.SpinClient.TuskActVFX.TheWorldStand)

	THE WORLD (Diego Brando from another world), blocky, matched to the art:
	  * a muscular, shiny golden body
	  * a tall wedge helmet: wide at the brow, tapering up to a flat top, a
	    sharp ridge down the front, the sides coming down round a small face
	    like a hood (narrow eyes, full lips)
	  * big pillow-like padded rolls looping over both shoulders, down the
	    chest to the hips and round the back
	  * round clock-like dials on the wrists and hips, a belt of round studs
	  * boots with a "D" on each shin
	Registered with TuskStandModels by DiegoAUVFX, so TuskStand floats it
	behind Diego (players and NPCs) with a golden aura. A custom model at
	ReplicatedStorage.SpinAssets.TuskAct14 replaces it.
]]

local TheWorldStand = {}

local GOLD = Color3.fromRGB(244, 204, 48)
local GOLD_SHADE = Color3.fromRGB(214, 160, 34)
local GOLD_LIGHT = Color3.fromRGB(255, 230, 120)
local PAD = Color3.fromRGB(226, 204, 120)
local PAD_SHADE = Color3.fromRGB(190, 160, 80)
local LINE = Color3.fromRGB(110, 72, 22)
local LIP = Color3.fromRGB(196, 120, 56)
local EYE = Color3.fromRGB(255, 250, 230)

TheWorldStand.Aura = Color3.fromRGB(255, 210, 80)
TheWorldStand.AuraLight = Color3.fromRGB(255, 240, 190)
TheWorldStand.Offset = CFrame.new(2.2, 1.6, 2.8)

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

-- A clock-like dial on a wrist: a round face with two hands.
local function dial(model, parent, cf, s)
	local face = box(model, parent, "Dial", Vector3.new(0.12, 0.62, 0.62) * s, GOLD_LIGHT, cf)
	face.Shape = Enum.PartType.Cylinder
	box(model, parent, "DialRim", Vector3.new(0.1, 0.72, 0.72) * s, GOLD_SHADE, cf * CFrame.new(0.02 * s, 0, 0)).Shape = Enum.PartType.Cylinder
	box(model, parent, "DialHand", Vector3.new(0.05, 0.24, 0.04) * s, LINE, cf * CFrame.new(-0.07 * s, 0.1 * s, 0))
	box(model, parent, "DialHand", Vector3.new(0.05, 0.04, 0.2) * s, LINE, cf * CFrame.new(-0.07 * s, 0, 0.08 * s))
end

-- A "D" in blocks on a flat face (facing -Z of `cf`).
local function letterD(model, parent, cf, h, s)
	local t = 0.07 * s
	box(model, parent, "D", Vector3.new(t, h, 0.04), LINE, cf * CFrame.new(-h * 0.3, 0, 0))
	box(model, parent, "D", Vector3.new(h * 0.4, t, 0.04), LINE, cf * CFrame.new(-h * 0.12, h / 2 - t / 2, 0))
	box(model, parent, "D", Vector3.new(h * 0.4, t, 0.04), LINE, cf * CFrame.new(-h * 0.12, -h / 2 + t / 2, 0))
	box(model, parent, "D", Vector3.new(t, h * 0.62, 0.04), LINE, cf * CFrame.new(h * 0.17, 0, 0))
	box(model, parent, "D", Vector3.new(t, h * 0.24, 0.04), LINE, cf * CFrame.new(h * 0.1, h * 0.36, 0) * CFrame.Angles(0, 0, 0.7))
	box(model, parent, "D", Vector3.new(t, h * 0.24, 0.04), LINE, cf * CFrame.new(h * 0.1, -h * 0.36, 0) * CFrame.Angles(0, 0, -0.7))
end

-- A padded roll: a row of fat pillow segments from a to b (torso space),
-- each with a darker seam between it and the next.
local function roll(model, torso, a, b, thick, s)
	local length = (b - a).Magnitude
	local count = math.max(2, math.floor(length / (0.5 * s)))
	local seg = length / count
	for i = 0, count - 1 do
		local p = a:Lerp(b, (i + 0.5) / count)
		local cf = CFrame.lookAt(p, b)
		box(model, torso, "Pad", Vector3.new(thick, thick, seg * 0.84), i % 2 == 0 and PAD or GOLD_LIGHT, cf)
		box(model, torso, "PadCore", Vector3.new(thick * 0.82, thick * 0.82, seg * 1.02), PAD_SHADE, cf)
	end
end

function TheWorldStand.build(scale)
	local s = (scale or 1) * 0.88
	local model = Instance.new("Model")
	model.Name = "TheWorld"
	local rig = { Joints = {} }

	-- Broad, muscular torso (the anchored root the Stand is moved by).
	local torso = newPart(model, "Body", Vector3.new(2.3, 1.9, 1.15) * s, GOLD, Enum.Material.SmoothPlastic)
	torso.Reflectance = 0.15
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.58 * s
	-- Pecs and abs.
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Pec", Vector3.new(0.95, 0.6, 0.1) * s, GOLD_LIGHT, CFrame.new(side * 0.5 * s, 0.45 * s, front - 0.03 * s))
	end
	box(model, torso, "Waist", Vector3.new(1.6, 0.8, 0.9) * s, GOLD_SHADE, CFrame.new(0, -1.25 * s, 0))
	for k = 0, 2 do
		for _, side in ipairs({ -1, 1 }) do
			box(model, torso, "Ab", Vector3.new(0.4, 0.24, 0.06) * s, GOLD_LIGHT, CFrame.new(side * 0.23 * s, (-0.2 - k * 0.3) * s, front - 0.02 * s))
		end
	end
	-- A belt of round studs.
	box(model, torso, "Belt", Vector3.new(1.7, 0.3, 0.98) * s, GOLD_SHADE, CFrame.new(0, -1.62 * s, 0))
	for k = -2, 2 do
		box(model, torso, "Stud", Vector3.new(0.12, 0.26, 0.26) * s, GOLD_LIGHT, CFrame.new(k * 0.34 * s, -1.62 * s, -0.5 * s) * CFrame.Angles(0, math.pi / 2, 0)).Shape = Enum.PartType.Cylinder
	end
	box(model, torso, "Hips", Vector3.new(1.7, 0.5, 0.95) * s, GOLD, CFrame.new(0, -1.95 * s, 0))
	for _, side in ipairs({ -1, 1 }) do
		dial(model, torso, CFrame.new(side * 0.9 * s, -1.85 * s, 0) * CFrame.Angles(0, side > 0 and 0 or math.pi, 0), s)
	end
	box(model, torso, "Neck", Vector3.new(0.55, 0.45, 0.55) * s, GOLD_SHADE, CFrame.new(0, 1.12 * s, 0))

	-- The padded rolls: a fat loop over each shoulder, down the front of the
	-- chest to the hips, and down the back; joined behind the neck.
	local t = 0.62 * s
	for _, side in ipairs({ -1, 1 }) do
		local neck = Vector3.new(side * 0.5, 1.15, 0.1) * s
		local shoulder = Vector3.new(side * 1.25, 1.1, 0) * s
		roll(model, torso, neck, shoulder, t, s)
		roll(model, torso, shoulder + Vector3.new(0, -0.05, -0.4) * s, Vector3.new(side * 0.95, -0.3, -0.7) * s, t, s)
		roll(model, torso, Vector3.new(side * 0.95, -0.3, -0.7) * s, Vector3.new(side * 0.75, -1.55, -0.62) * s, t, s)
		roll(model, torso, shoulder + Vector3.new(0, -0.05, 0.4) * s, Vector3.new(side * 0.8, -1.4, 0.68) * s, t, s)
	end
	roll(model, torso, Vector3.new(-0.5, 1.2, 0.45) * s, Vector3.new(0.5, 1.2, 0.45) * s, t, s)

	-- Head: a tall wedge helmet, wide at the brow and tapering up to a flat
	-- top, with a sharp ridge down the front; its sides come down round a
	-- small face like a hood.
	local headBase = CFrame.new(0, 1.3 * s, 0)
	local headOffset = CFrame.new(0, 0.55 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.75, 0.9, 0.8) * s, GOLD, headBase * headOffset)
	head.Reflectance = 0.12
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.4 * s
	-- The face: narrow eyes, a nose, full lips, a strong chin.
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.22, 0.07, 0.05) * s, EYE, CFrame.new(side * 0.17 * s, 0.1 * s, hf - 0.02 * s) * CFrame.Angles(0, 0, side * -0.22), Enum.Material.Neon)
		box(model, head, "Lid", Vector3.new(0.26, 0.06, 0.06) * s, LINE, CFrame.new(side * 0.17 * s, 0.16 * s, hf - 0.03 * s) * CFrame.Angles(0, 0, side * -0.22))
	end
	box(model, head, "Nose", Vector3.new(0.09, 0.26, 0.1) * s, GOLD_SHADE, CFrame.new(0, -0.04 * s, hf - 0.04 * s))
	box(model, head, "Lips", Vector3.new(0.3, 0.12, 0.08) * s, LIP, CFrame.new(0, -0.27 * s, hf - 0.02 * s))
	box(model, head, "Chin", Vector3.new(0.42, 0.18, 0.2) * s, GOLD_SHADE, CFrame.new(0, -0.44 * s, hf + 0.08 * s))
	-- The hood sides, down past the jaw.
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Hood", Vector3.new(0.18, 1.1, 0.95) * s, GOLD_SHADE, CFrame.new(side * 0.46 * s, -0.05 * s, 0.06 * s) * CFrame.Angles(0, 0, side * 0.08))
	end
	box(model, head, "HoodBack", Vector3.new(1.0, 1.2, 0.2) * s, GOLD_SHADE, CFrame.new(0, 0, 0.48 * s))
	-- The wedge: slabs from a wide brim narrowing to a flat top, leaning back.
	local layers = 6
	for k = 0, layers - 1 do
		local f = k / (layers - 1)
		local w = (1.25 - f * 0.7) * s
		local d = (1.1 - f * 0.45) * s
		box(model, head, "Wedge", Vector3.new(w, 0.3 * s, d), k % 2 == 0 and GOLD or GOLD_LIGHT, CFrame.new(0, (0.5 + k * 0.27) * s, (0.08 + f * 0.25) * s))
	end
	box(model, head, "WedgeTop", Vector3.new(0.6, 0.12, 0.7) * s, GOLD_LIGHT, CFrame.new(0, (0.5 + layers * 0.27) * s, 0.36 * s))
	-- The brim over the eyes and the sharp ridge up the front.
	box(model, head, "Brim", Vector3.new(1.2, 0.16, 0.3) * s, GOLD_SHADE, CFrame.new(0, 0.36 * s, hf - 0.1 * s))
	box(model, head, "Ridge", Vector3.new(0.14, 1.5, 0.14) * s, GOLD_LIGHT, CFrame.new(0, 1.17 * s, -0.25 * s) * CFrame.Angles(0.34, 0, 0) * CFrame.Angles(0, math.pi / 4, 0))
	for _, side in ipairs({ -1, 1 }) do
		-- Shading on the two slanted faces either side of the ridge.
		box(model, head, "WedgeShade", Vector3.new(0.05, 1.3, 0.5) * s, GOLD_SHADE, CFrame.new(side * (0.5 - 0.15) * s, 1.1 * s, 0.05 * s) * CFrame.Angles(0.34, 0, side * 0.22))
	end

	-- Thick arms with dials on the wrists.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		box(model, torso, "Shoulder", Vector3.new(0.9, 0.8, 0.9) * s, GOLD_LIGHT, CFrame.new(side * 1.45 * s, 0.6 * s, 0))
		local base = CFrame.new(side * 1.5 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local size = Vector3.new(0.65, 2.2, 0.65) * s
		local arm, weld = box(model, torso, a[1], size, GOLD, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Bicep", Vector3.new(0.72, 0.7, 0.72) * s, GOLD_LIGHT, CFrame.new(0, 0.55 * s, -0.02 * s))
		box(model, arm, "Forearm", Vector3.new(0.74, 0.8, 0.74) * s, GOLD_SHADE, CFrame.new(0, -0.5 * s, 0))
		dial(model, arm, CFrame.new(side * 0.4 * s, -0.55 * s, 0), s)
		local hand = box(model, arm, "Hand", Vector3.new(0.6, 0.55, 0.55) * s, GOLD, CFrame.new(0, -1.35 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.11, 0.38, 0.11) * s, GOLD_SHADE, CFrame.new(f * 0.13 * s, -0.4 * s, -0.06 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: a "D" on each shin, heavy feet.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.48 * s, -2.1 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local size = Vector3.new(0.72, 2.4, 0.72) * s
		local leg, weld = box(model, torso, "Leg" .. i, size, GOLD, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Thigh", Vector3.new(0.8, 0.9, 0.8) * s, GOLD_LIGHT, CFrame.new(0, 0.7 * s, 0))
		box(model, leg, "Knee", Vector3.new(0.6, 0.36, 0.12) * s, GOLD_SHADE, CFrame.new(0, 0.05 * s, -0.4 * s))
		local shin = box(model, leg, "Shin", Vector3.new(0.66, 0.8, 0.1) * s, GOLD_LIGHT, CFrame.new(0, -0.55 * s, -0.4 * s))
		letterD(model, shin, CFrame.new(0, 0, -0.06 * s), 0.6 * s, s)
		box(model, leg, "Foot", Vector3.new(0.66, 0.3, 1.0) * s, GOLD_SHADE, CFrame.new(0, -1.3 * s, -0.17 * s))
	end
	return model, rig
end

return TheWorldStand
