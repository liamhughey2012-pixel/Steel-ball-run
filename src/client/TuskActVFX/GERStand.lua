--[[
	TuskActVFX.GERStand  (StarterPlayerScripts.SpinClient.TuskActVFX.GERStand)

	GOLD EXPERIENCE REQUIEM (Giorno Giovanna, Part 5), blocky, matched to
	the art: brighter and grander than Gold Experience:
	  * a tall golden HELMET with two great swept-back CRESTS, round
	    orange-red SPOTS down its sides, and a big red DISC on each cheek
	  * a PURPLE face with orange dots, narrow glowing eyes, and THE
	    REQUIEM ARROW's head stuck in its forehead, its beetle EYE staring out
	  * a high golden collar; a golden body dotted with orange spots
	  * huge angular shoulder wings, a belt with silver straps and a purple
	    buckle, purple joints; a faint violet starry shimmer round it
	Registered with TuskStandModels by GERVFX, so TuskStand floats it with a
	gold-and-violet aura.
]]

local GERStand = {}

local GOLD = Color3.fromRGB(250, 220, 110)
local GOLD_LIGHT = Color3.fromRGB(255, 240, 170)
local GOLD_SHADE = Color3.fromRGB(214, 170, 70)
local SPOT = Color3.fromRGB(236, 96, 60)
local SPOT_LIGHT = Color3.fromRGB(255, 150, 90)
local PURPLE = Color3.fromRGB(150, 80, 220)
local PURPLE_DARK = Color3.fromRGB(96, 46, 150)
local FACE = Color3.fromRGB(176, 110, 210)
local SILVER = Color3.fromRGB(220, 224, 236)
local SILVER_SHADE = Color3.fromRGB(176, 182, 204)
local EYE = Color3.fromRGB(255, 250, 220)
local ARROW = Color3.fromRGB(226, 186, 90)
local BEETLE = Color3.fromRGB(250, 200, 220)

GERStand.Aura = Color3.fromRGB(255, 220, 110)
GERStand.AuraLight = Color3.fromRGB(220, 190, 255)
GERStand.Offset = CFrame.new(2.2, 1.7, 2.8)

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

local function egg(model, parent, name, size, color, cf, material)
	local p, w = box(model, parent, name, size, color, cf, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p, w
end

local function cyl(model, parent, name, length, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(length, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A round flat spot (disc) facing out along -Z of `cf`.
local function spot(model, parent, cf, d, color)
	return cyl(model, parent, "Spot", 0.05 * d / 0.2, d, color, cf * CFrame.Angles(0, math.pi / 2, 0))
end

function GERStand.build(scale)
	local s = (scale or 1) * 0.92
	local model = Instance.new("Model")
	model.Name = "GoldExperienceRequiem"
	local rig = { Joints = {} }

	local torso = newPart(model, "Body", Vector3.new(2.0, 1.9, 1.05) * s, GOLD)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.53 * s
	-- A high golden collar rising round the neck.
	box(model, torso, "Collar", Vector3.new(1.3, 0.55, 1.0) * s, GOLD_LIGHT, CFrame.new(0, 1.0 * s, 0.05 * s))
	box(model, torso, "CollarRim", Vector3.new(1.34, 0.08, 1.04) * s, GOLD_SHADE, CFrame.new(0, 1.26 * s, 0.05 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "CollarFlare", Vector3.new(0.12, 0.7, 0.8) * s, GOLD_LIGHT, CFrame.new(side * 0.68 * s, 1.15 * s, 0.1 * s) * CFrame.Angles(0, 0, side * -0.35))
		box(model, torso, "Pec", Vector3.new(0.9, 0.7, 0.14) * s, GOLD_LIGHT, CFrame.new(side * 0.48 * s, 0.38 * s, front - 0.04 * s) * CFrame.Angles(0, side * 0.12, 0))
		-- Orange-red spots on the chest and flanks.
		spot(model, torso, CFrame.new(side * 0.5 * s, 0.4 * s, front - 0.12 * s), 0.34 * s, SPOT)
		spot(model, torso, CFrame.new(side * 0.5 * s, 0.4 * s, front - 0.14 * s), 0.18 * s, SPOT_LIGHT)
		spot(model, torso, CFrame.new(side * 0.72 * s, -0.35 * s, front - 0.02 * s), 0.18 * s, SPOT)
		for k = 0, 2 do
			box(model, torso, "Rib", Vector3.new(0.45, 0.06, 0.06) * s, GOLD_SHADE, CFrame.new(side * 0.42 * s, -0.12 * s - k * 0.18 * s, front - 0.02 * s) * CFrame.Angles(0, 0, side * 0.25))
		end
	end
	box(model, torso, "Sternum", Vector3.new(0.1, 1.2, 0.1) * s, PURPLE, CFrame.new(0, 0.1 * s, front - 0.04 * s))
	box(model, torso, "Waist", Vector3.new(1.35, 0.9, 0.85) * s, GOLD, CFrame.new(0, -1.35 * s, 0))
	for k = 0, 2 do
		box(model, torso, "Abs", Vector3.new(0.6, 0.05, 0.06) * s, GOLD_SHADE, CFrame.new(0, -1.05 * s - k * 0.22 * s, -0.44 * s))
	end
	box(model, torso, "Belt", Vector3.new(1.5, 0.22, 0.92) * s, GOLD_SHADE, CFrame.new(0, -1.82 * s, 0))
	for k = 0, 2 do
		for _, side in ipairs({ -1, 1 }) do
			box(model, torso, "Strap", Vector3.new(0.72, 0.07, 0.07) * s, k % 2 == 0 and SILVER or SILVER_SHADE, CFrame.new(side * 0.37 * s, -1.95 * s - k * 0.14 * s, -0.5 * s - k * 0.03 * s) * CFrame.Angles(0, 0, side * (0.18 + k * 0.08)))
		end
	end
	egg(model, torso, "Buckle", Vector3.new(0.5, 0.5, 0.3) * s, PURPLE, CFrame.new(-0.74 * s, -1.9 * s, -0.2 * s))
	box(model, torso, "Hips", Vector3.new(1.4, 0.5, 0.88) * s, GOLD_SHADE, CFrame.new(0, -2.1 * s, 0))

	-- Huge angular shoulder wings.
	for _, side in ipairs({ -1, 1 }) do
		local cf = CFrame.new(side * 1.2 * s, 0.9 * s, 0.05 * s) * CFrame.Angles(0, 0, side * -0.3)
		egg(model, torso, "ShoulderPad", Vector3.new(0.9, 0.6, 0.9) * s, GOLD_LIGHT, cf)
		spot(model, torso, cf * CFrame.new(side * 0.46 * s, 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0), 0.26 * s, SPOT)
		for k = 0, 3 do
			box(model, torso, "Wing", Vector3.new(0.12, 1.25 - k * 0.22, 0.42 - k * 0.07) * s, k % 2 == 1 and SILVER_SHADE or SILVER, cf * CFrame.new(side * (0.22 + k * 0.13) * s, (0.7 + k * 0.12) * s, (0.04 + k * 0.04) * s) * CFrame.Angles(math.rad(-8), 0, side * (-0.4 - k * 0.15)))
		end
	end

	-- The head: tall golden helmet, swept-back crests, red discs, a purple
	-- face, and the arrow in its forehead.
	local hs = s * 1.22
	local headBase = CFrame.new(0, 1.3 * s, 0)
	local headOffset = CFrame.new(0, 0.62 * hs, 0)
	local head, headWeld = egg(model, torso, "Head", Vector3.new(0.9, 1.2, 0.95) * hs, GOLD, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.47 * hs
	egg(model, head, "Dome", Vector3.new(0.98, 0.75, 1.05) * hs, GOLD_LIGHT, CFrame.new(0, 0.3 * hs, 0.06 * hs))
	-- Two great crests sweeping back off the helmet.
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			box(model, head, "Crest", Vector3.new(0.12, 0.3 - k * 0.06, 0.8 - k * 0.15) * hs, k == 1 and GOLD_SHADE or GOLD_LIGHT, CFrame.new(side * 0.26 * hs, (0.6 + k * 0.16) * hs, (0.35 + k * 0.32) * hs) * CFrame.Angles(math.rad(35 + k * 12), side * 0.12, 0))
		end
		box(model, head, "CrestTip", Vector3.new(0.08, 0.12, 0.4) * hs, GOLD_SHADE, CFrame.new(side * 0.26 * hs, 1.08 * hs, 1.18 * hs) * CFrame.Angles(math.rad(60), side * 0.12, 0))
		-- Orange spots in a line down the helmet's side, a big red disc on the cheek.
		for k = 0, 3 do
			spot(model, head, CFrame.new(side * 0.47 * hs, (0.4 - k * 0.15) * hs, (0.25 - k * 0.04) * hs) * CFrame.Angles(0, side * -math.pi / 2, 0), 0.1 * hs, SPOT_LIGHT)
		end
		spot(model, head, CFrame.new(side * 0.43 * hs, -0.12 * hs, -0.1 * hs) * CFrame.Angles(0, side * -1.2, 0), 0.36 * hs, SPOT)
		spot(model, head, CFrame.new(side * 0.44 * hs, -0.12 * hs, -0.11 * hs) * CFrame.Angles(0, side * -1.2, 0), 0.2 * hs, SPOT_LIGHT)
	end
	-- The purple face, orange dots, narrow glowing eyes.
	egg(model, head, "Face", Vector3.new(0.6, 0.75, 0.12) * hs, FACE, CFrame.new(0, -0.12 * hs, hf + 0.04 * hs))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.2, 0.06, 0.04) * hs, EYE, CFrame.new(side * 0.14 * hs, 0.02 * hs, hf - 0.03 * hs) * CFrame.Angles(0, 0, side * -0.15), Enum.Material.Neon)
		ball(model, head, "FaceDot", 0.07 * hs, SPOT_LIGHT, CFrame.new(side * 0.17 * hs, -0.24 * hs, hf - 0.02 * hs))
		ball(model, head, "FaceDot", 0.05 * hs, SPOT_LIGHT, CFrame.new(side * 0.12 * hs, -0.36 * hs, hf - 0.01 * hs))
	end
	box(model, head, "Mouth", Vector3.new(0.16, 0.035, 0.04) * hs, PURPLE_DARK, CFrame.new(0, -0.32 * hs, hf - 0.01 * hs))
	-- The Requiem Arrow's head, stuck in the forehead, its beetle eye open.
	local arrowAt = CFrame.new(0.12 * hs, 0.3 * hs, hf - 0.06 * hs) * CFrame.Angles(0, 0, math.rad(-20))
	box(model, head, "ArrowHead", Vector3.new(0.3, 0.3, 0.08) * hs, ARROW, arrowAt * CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Metal)
	box(model, head, "ArrowShaft", Vector3.new(0.06, 0.22, 0.06) * hs, ARROW, arrowAt * CFrame.new(0, -0.24 * hs, 0.02 * hs), Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "ArrowWing", Vector3.new(0.18, 0.06, 0.06) * hs, ARROW, arrowAt * CFrame.new(side * 0.14 * hs, -0.04 * hs, 0) * CFrame.Angles(0, 0, side * -0.6), Enum.Material.Metal)
	end
	egg(model, head, "BeetleEye", Vector3.new(0.18, 0.12, 0.05) * hs, BEETLE, arrowAt * CFrame.new(0, 0.02 * hs, -0.05 * hs))
	ball(model, head, "BeetlePupil", 0.07 * hs, PURPLE_DARK, arrowAt * CFrame.new(0, 0.02 * hs, -0.08 * hs))

	-- Arms: golden, purple joints, spots on the forearms.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.28 * s, 0.45 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.55, 2.2, 0.55) * s, GOLD, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Bicep", Vector3.new(0.64, 0.75, 0.64) * s, GOLD_LIGHT, CFrame.new(0, 0.52 * s, -0.02 * s))
		ball(model, arm, "Elbow", 0.46 * s, PURPLE, CFrame.new(0, 0, 0))
		box(model, arm, "Forearm", Vector3.new(0.62, 0.75, 0.62) * s, GOLD, CFrame.new(0, -0.52 * s, 0))
		spot(model, arm, CFrame.new(0, -0.5 * s, -0.32 * s), 0.18 * s, SPOT)
		box(model, arm, "Wrist", Vector3.new(0.66, 0.16, 0.66) * s, PURPLE, CFrame.new(0, -0.95 * s, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.52, 0.5, 0.45) * s, GOLD_LIGHT, CFrame.new(0, -1.25 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.1, 0.28, 0.1) * s, GOLD, CFrame.new(f * 0.12 * s, -0.32 * s, -0.06 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.25 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.45 * s, -2.25 * s, 0)
		local offset = CFrame.new(0, -1.25 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.6, 2.5, 0.6) * s, GOLD, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Thigh", Vector3.new(0.7, 1.0, 0.7) * s, GOLD_LIGHT, CFrame.new(0, 0.65 * s, 0))
		spot(model, leg, CFrame.new(0, 0.65 * s, -0.36 * s), 0.2 * s, SPOT)
		ball(model, leg, "Knee", 0.5 * s, PURPLE, CFrame.new(0, 0, -0.1 * s))
		box(model, leg, "Shin", Vector3.new(0.64, 0.9, 0.64) * s, GOLD_SHADE, CFrame.new(0, -0.62 * s, 0))
		box(model, leg, "Ankle", Vector3.new(0.68, 0.14, 0.68) * s, PURPLE, CFrame.new(0, -1.1 * s, 0))
		box(model, leg, "Foot", Vector3.new(0.6, 0.32, 0.95) * s, GOLD_SHADE, CFrame.new(0, -1.35 * s, -0.17 * s))
	end
	return model, rig
end

return GERStand
