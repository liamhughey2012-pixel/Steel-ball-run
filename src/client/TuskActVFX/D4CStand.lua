--[[
	TuskActVFX.D4CStand  (StarterPlayerScripts.SpinClient.TuskActVFX.D4CStand)

	The D4C (Dirty Deeds Done Dirt Cheap) Stand model (Funny Valentine),
	blocky, matched to the art:
	  * a sleek, shiny ice-blue humanoid
	  * two long flat rabbit ears swept up and back from the head
	  * a narrow face with a ridge down the middle and dark eyes
	  * big pink balls on the shoulders, pink briefs at the hips
	  * white crosses on the chest, thin pink lines down the arms and legs
	Registered with TuskStandModels by ValentineVFX, so TuskStand floats it
	behind Valentine (players and NPCs) with an ice-blue aura. A custom model
	at ReplicatedStorage.SpinAssets.TuskAct13 replaces it.
]]

local D4CStand = {}

local BODY = Color3.fromRGB(176, 228, 240)
local BODY_SHADE = Color3.fromRGB(130, 194, 214)
local SHINE = Color3.fromRGB(236, 250, 255)
local PINK = Color3.fromRGB(234, 124, 166)
local WHITE = Color3.fromRGB(250, 252, 255)
local DARK = Color3.fromRGB(40, 60, 80)

D4CStand.Aura = Color3.fromRGB(140, 220, 240)
D4CStand.AuraLight = Color3.fromRGB(230, 240, 255)
D4CStand.Offset = CFrame.new(2.3, 1.6, 2.8)

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

-- Thin pink lines down both sides of a limb.
local function pinkLines(model, parent, size, s)
	for _, side in ipairs({ -1, 1 }) do
		box(model, parent, "PinkLine", Vector3.new(0.05 * s, size.Y * 0.9, 0.08 * s), PINK, CFrame.new(side * (size.X / 2 + 0.01 * s), 0, 0))
	end
end

-- A white cross (+) on a face.
local function cross(model, parent, cf, size)
	box(model, parent, "Cross", Vector3.new(size, size * 0.28, 0.05), WHITE, cf)
	box(model, parent, "Cross", Vector3.new(size * 0.28, size, 0.05), WHITE, cf)
end

function D4CStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "D4C"
	local rig = { Joints = {} }

	-- Sleek torso (the anchored root the Stand is moved by), narrowing to the waist.
	local torso = newPart(model, "Body", Vector3.new(2.0, 1.7, 1.0) * s, BODY, Enum.Material.SmoothPlastic)
	torso.Reflectance = 0.12
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.51 * s
	box(model, torso, "Chest", Vector3.new(1.7, 0.9, 0.1) * s, BODY_SHADE, CFrame.new(0, 0.3 * s, front - 0.02 * s))
	cross(model, torso, CFrame.new(-0.4 * s, 0.35 * s, front - 0.08 * s), 0.5 * s)
	cross(model, torso, CFrame.new(0.4 * s, 0.35 * s, front - 0.08 * s), 0.5 * s)
	box(model, torso, "Waist", Vector3.new(1.4, 0.7, 0.8) * s, BODY_SHADE, CFrame.new(0, -1.1 * s, 0))
	for k = 0, 1 do
		box(model, torso, "Ab", Vector3.new(0.9, 0.22, 0.06) * s, BODY, CFrame.new(0, (-0.95 - k * 0.28) * s, -0.42 * s))
	end
	-- Pink briefs at the hips.
	box(model, torso, "Briefs", Vector3.new(1.5, 0.5, 0.86) * s, PINK, CFrame.new(0, -1.6 * s, 0))
	box(model, torso, "Neck", Vector3.new(0.45, 0.45, 0.45) * s, BODY_SHADE, CFrame.new(0, 1.05 * s, 0))

	-- Head: narrow, a ridge down the face, dark eyes, long flat rabbit ears swept back.
	local headBase = CFrame.new(0, 1.15 * s, 0)
	local headOffset = CFrame.new(0, 0.55 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.8, 1.1, 0.9) * s, BODY, headBase * headOffset)
	head.Reflectance = 0.12
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.45 * s
	box(model, head, "Ridge", Vector3.new(0.1, 0.9, 0.08) * s, SHINE, CFrame.new(0, 0, hf - 0.03 * s))
	box(model, head, "Jaw", Vector3.new(0.6, 0.3, 0.8) * s, BODY_SHADE, CFrame.new(0, -0.5 * s, -0.04 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.24, 0.12, 0.06) * s, DARK, CFrame.new(side * 0.2 * s, 0.1 * s, hf - 0.02 * s) * CFrame.Angles(0, 0, side * 0.2))
		-- Long flat ear: three tapering plates, swept up and back.
		local earBase = CFrame.new(side * 0.22 * s, 0.5 * s, 0.1 * s) * CFrame.Angles(-0.35, 0, side * -0.08)
		for k = 0, 2 do
			local w = (0.34 - k * 0.07) * s
			box(model, head, "Ear", Vector3.new(w, 0.75 * s, 0.12 * s), BODY, earBase * CFrame.new(0, (0.37 + k * 0.72) * s, 0))
		end
		box(model, head, "EarInner", Vector3.new(0.08, 1.7, 0.04) * s, PINK, earBase * CFrame.new(0, 1.05 * s, -0.08 * s))
	end

	-- Big pink shoulder balls and sleek arms with pink lines.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		box(model, torso, "ShoulderBall", Vector3.new(1.0, 1.0, 1.0) * s, PINK, CFrame.new(side * 1.3 * s, 0.65 * s, 0), Enum.Material.SmoothPlastic).Shape = Enum.PartType.Ball
		local base = CFrame.new(side * 1.35 * s, 0.35 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local size = Vector3.new(0.5, 2.2, 0.5) * s
		local arm, weld = box(model, torso, a[1], size, BODY, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		pinkLines(model, arm, size, s)
		box(model, arm, "Forearm", Vector3.new(0.58, 0.9, 0.58) * s, BODY_SHADE, CFrame.new(0, -0.5 * s, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.5, 0.5, 0.45) * s, BODY, CFrame.new(0, -1.3 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.09, 0.4, 0.09) * s, BODY_SHADE, CFrame.new(f * 0.11 * s, -0.4 * s, -0.05 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Long legs with pink lines.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.42 * s, -1.75 * s, 0)
		local offset = CFrame.new(0, -1.25 * s, 0)
		local size = Vector3.new(0.6, 2.5, 0.6) * s
		local leg, weld = box(model, torso, "Leg" .. i, size, BODY, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		pinkLines(model, leg, size, s)
		box(model, leg, "Knee", Vector3.new(0.5, 0.3, 0.1) * s, SHINE, CFrame.new(0, 0.2 * s, -0.32 * s))
		box(model, leg, "Foot", Vector3.new(0.5, 0.25, 0.9) * s, BODY_SHADE, CFrame.new(0, -1.35 * s, -0.15 * s))
	end
	return model, rig
end

return D4CStand
