--[[
	TuskActVFX.KingCrimsonStand  (StarterPlayerScripts.SpinClient.TuskActVFX.KingCrimsonStand)

	KING CRIMSON (Diavolo, Part 5), blocky, matched to the art:
	  * a big, muscular CRIMSON body criss-crossed all over by a white
	    DIAMOND LATTICE (chest, back, arms, legs, helmet)
	  * huge rounded silver-white SHOULDER PADS; a dark grey V down the
	    chest; a pale ribbed waist; dark grey trunks with a rolled top
	  * a crimson helmet round a pale grey FACE: angry green eyes with dark
	    pupils, heavy brows, clenched teeth
	  * EPITAPH: a small pink face on its forehead
	  * pale grey hands with GREEN NAILS; silver knee pads; white-grey boots
	    with a green band
	Registered with TuskStandModels by DiavoloVFX, so TuskStand floats it
	behind him with a crimson aura.
]]

local KingCrimsonStand = {}

local RED = Color3.fromRGB(206, 40, 72)
local RED_DARK = Color3.fromRGB(160, 26, 54)
local LINE = Color3.fromRGB(246, 236, 240)
local SILVER = Color3.fromRGB(226, 226, 236)
local SILVER_SHADE = Color3.fromRGB(176, 176, 192)
local GREY = Color3.fromRGB(88, 86, 104)
local FACE = Color3.fromRGB(206, 204, 214)
local FACE_SHADE = Color3.fromRGB(150, 148, 166)
local EYE = Color3.fromRGB(110, 230, 120)
local PUPIL = Color3.fromRGB(20, 40, 24)
local NAIL = Color3.fromRGB(120, 220, 110)
local EPITAPH = Color3.fromRGB(226, 140, 186)

KingCrimsonStand.Aura = Color3.fromRGB(230, 50, 90)
KingCrimsonStand.AuraLight = Color3.fromRGB(255, 210, 220)
KingCrimsonStand.Offset = CFrame.new(2.2, 1.6, 2.8)

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

-- A white diamond lattice on one face. `face` is the face's centre (its X
-- and Y span the face, -Z points out); w/h its size; `cell` the diamond size.
local function lattice(model, parent, face, w, h, cell, thick)
	thick = thick or 0.05
	local half = cell / 2
	local nx = math.max(1, math.floor(w / half))
	local ny = math.max(1, math.floor(h / half))
	local ox, oy = -nx * half / 2, -ny * half / 2
	local len = math.sqrt(2) * half
	for i = 0, nx - 1 do
		for j = 0, ny - 1 do
			if (i + j) % 2 == 0 then
				-- "/" from (i, j) to (i+1, j+1)
				local x, y = ox + (i + 0.5) * half, oy + (j + 0.5) * half
				box(model, parent, "Lattice", Vector3.new(len + thick, thick, 0.03), LINE, face * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.pi / 4))
			else
				-- "\\" from (i, j+1) to (i+1, j)
				local x, y = ox + (i + 0.5) * half, oy + (j + 0.5) * half
				box(model, parent, "Lattice", Vector3.new(len + thick, thick, 0.03), LINE, face * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, -math.pi / 4))
			end
		end
	end
end

-- Lattice on all four sides of a limb (size = its box size).
local function limbLattice(model, part, size, cell)
	lattice(model, part, CFrame.new(0, 0, -size.Z / 2 - 0.016), size.X, size.Y, cell)
	lattice(model, part, CFrame.new(0, 0, size.Z / 2 + 0.016) * CFrame.Angles(0, math.pi, 0), size.X, size.Y, cell)
	lattice(model, part, CFrame.new(size.X / 2 + 0.016, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), size.Z, size.Y, cell)
	lattice(model, part, CFrame.new(-size.X / 2 - 0.016, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), size.Z, size.Y, cell)
end

function KingCrimsonStand.build(scale)
	local s = (scale or 1) * 0.9
	local model = Instance.new("Model")
	model.Name = "KingCrimson"
	local rig = { Joints = {} }

	-- The big crimson chest, latticed front and back.
	local tsize = Vector3.new(2.3, 1.9, 1.15) * s
	local torso = newPart(model, "Body", tsize, RED)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -tsize.Z / 2
	lattice(model, torso, CFrame.new(0, 0, front - 0.016), tsize.X, tsize.Y, 0.62 * s)
	lattice(model, torso, CFrame.new(0, 0, -front + 0.016) * CFrame.Angles(0, math.pi, 0), tsize.X, tsize.Y, 0.62 * s)
	-- The dark grey V down the chest, a silver collar.
	box(model, torso, "ChestV", Vector3.new(0.55, 0.9, 0.1) * s, GREY, CFrame.new(0, 0.5 * s, front - 0.06 * s))
	box(model, torso, "ChestVTip", Vector3.new(0.4, 0.4, 0.1) * s, GREY, CFrame.new(0, 0.05 * s, front - 0.06 * s) * CFrame.Angles(0, 0, math.pi / 4))
	box(model, torso, "Collar", Vector3.new(1.2, 0.28, 1.0) * s, SILVER, CFrame.new(0, 1.0 * s, 0.02 * s))
	-- The pale ribbed waist.
	box(model, torso, "Waist", Vector3.new(1.75, 0.85, 0.95) * s, FACE, CFrame.new(0, -1.35 * s, 0))
	for k = 0, 2 do
		box(model, torso, "Rib", Vector3.new(1.77, 0.05, 0.97) * s, FACE_SHADE, CFrame.new(0, -1.05 * s - k * 0.24 * s, 0))
	end
	-- Dark grey trunks with a rolled silver top.
	box(model, torso, "TrunksRoll", Vector3.new(1.9, 0.22, 1.05) * s, SILVER_SHADE, CFrame.new(0, -1.82 * s, 0))
	box(model, torso, "Trunks", Vector3.new(1.85, 0.6, 1.0) * s, GREY, CFrame.new(0, -2.15 * s, 0))
	box(model, torso, "Neck", Vector3.new(0.6, 0.4, 0.6) * s, RED_DARK, CFrame.new(0, 1.15 * s, 0))

	-- Huge rounded shoulder pads.
	for _, side in ipairs({ -1, 1 }) do
		local cf = CFrame.new(side * 1.45 * s, 0.75 * s, 0.05 * s) * CFrame.Angles(0, 0, side * -0.3)
		egg(model, torso, "ShoulderPad", Vector3.new(1.35, 1.0, 1.4) * s, SILVER, cf)
		egg(model, torso, "PadRim", Vector3.new(1.38, 0.3, 1.43) * s, SILVER_SHADE, cf * CFrame.new(0, -0.3 * s, 0))
	end

	-- The head: crimson helmet with lattice lines, a pale angry face, Epitaph.
	local hs = s * 1.35
	local headBase = CFrame.new(0, 1.35 * s, 0)
	local headOffset = CFrame.new(0, 0.6 * hs, 0)
	local hsize = Vector3.new(0.9, 1.1, 0.95) * hs
	local head, headWeld = egg(model, torso, "Head", hsize, RED, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -hsize.Z / 2
	-- White lines over the helmet (a few, curving with it).
	for k = -1, 1 do
		box(model, head, "HelmLine", Vector3.new(0.04, 0.9, 0.04) * hs, LINE, CFrame.new(k * 0.22 * hs, 0.1 * hs, (hf + 0.12 * hs) * (1 - math.abs(k) * 0.2)) * CFrame.Angles(0, 0, k * 0.5))
	end
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "HelmLine", Vector3.new(0.04, 0.7, 0.04) * hs, LINE, CFrame.new(side * 0.44 * hs, 0, 0) * CFrame.Angles(0.6, 0, 0))
	end
	-- The face plate.
	local faceAt = CFrame.new(0, -0.12 * hs, hf + 0.06 * hs)
	egg(model, head, "Face", Vector3.new(0.6, 0.62, 0.14) * hs, FACE, faceAt)
	for _, side in ipairs({ -1, 1 }) do
		egg(model, head, "Eye", Vector3.new(0.17, 0.15, 0.05) * hs, EYE, faceAt * CFrame.new(side * 0.14 * hs, 0.1 * hs, -0.07 * hs), Enum.Material.Neon)
		ball(model, head, "Pupil", 0.07 * hs, PUPIL, faceAt * CFrame.new(side * 0.14 * hs, 0.1 * hs, -0.095 * hs))
		box(model, head, "Brow", Vector3.new(0.22, 0.05, 0.04) * hs, FACE_SHADE, faceAt * CFrame.new(side * 0.14 * hs, 0.2 * hs, -0.08 * hs) * CFrame.Angles(0, 0, side * -0.4))
	end
	-- Clenched teeth.
	box(model, head, "Mouth", Vector3.new(0.3, 0.1, 0.04) * hs, GREY, faceAt * CFrame.new(0, -0.16 * hs, -0.07 * hs))
	box(model, head, "Teeth", Vector3.new(0.27, 0.07, 0.045) * hs, LINE, faceAt * CFrame.new(0, -0.16 * hs, -0.075 * hs))
	for k = -2, 2 do
		box(model, head, "ToothGap", Vector3.new(0.01, 0.07, 0.05) * hs, GREY, faceAt * CFrame.new(k * 0.05 * hs, -0.16 * hs, -0.078 * hs))
	end
	-- EPITAPH: a small pink face on its forehead.
	local ep = CFrame.new(0, 0.38 * hs, hf + 0.04 * hs) * CFrame.Angles(-0.35, 0, 0)
	egg(model, head, "Epitaph", Vector3.new(0.3, 0.24, 0.1) * hs, EPITAPH, ep)
	for _, side in ipairs({ -1, 1 }) do
		ball(model, head, "EpitaphEye", 0.05 * hs, PUPIL, ep * CFrame.new(side * 0.06 * hs, 0.03 * hs, -0.05 * hs))
	end
	box(model, head, "EpitaphMouth", Vector3.new(0.08, 0.025, 0.02) * hs, RED_DARK, ep * CFrame.new(0, -0.05 * hs, -0.05 * hs))

	-- Big latticed arms: silver elbows, pale hands with green nails.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.55 * s, 0.35 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local asize = Vector3.new(0.72, 2.2, 0.72) * s
		local arm, weld = box(model, torso, a[1], asize, RED, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		limbLattice(model, arm, asize, 0.5 * s)
		box(model, arm, "Elbow", Vector3.new(0.78, 0.22, 0.78) * s, SILVER, CFrame.new(0, 0, 0))
		box(model, arm, "ElbowSpike", Vector3.new(0.2, 0.3, 0.2) * s, SILVER_SHADE, CFrame.new(0, 0.05 * s, 0.42 * s) * CFrame.Angles(0.5, 0, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.7, 0.6, 0.62) * s, FACE, CFrame.new(0, -1.35 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.14, 0.32, 0.14) * s, FACE, CFrame.new(f * 0.16 * s, -0.42 * s, -0.08 * s))
			box(model, hand, "Nail", Vector3.new(0.12, 0.1, 0.06) * s, NAIL, CFrame.new(f * 0.16 * s, -0.55 * s, -0.16 * s), Enum.Material.Neon)
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Latticed legs: silver knee pads, white-grey boots with a green band.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.5 * s, -2.3 * s, 0)
		local offset = CFrame.new(0, -1.25 * s, 0)
		local lsize = Vector3.new(0.78, 2.5, 0.78) * s
		local leg, weld = box(model, torso, "Leg" .. i, lsize, RED, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		limbLattice(model, leg, lsize, 0.52 * s)
		egg(model, leg, "KneePad", Vector3.new(0.6, 0.55, 0.3) * s, SILVER, CFrame.new(0, 0.05 * s, -0.42 * s))
		box(model, leg, "Boot", Vector3.new(0.84, 0.7, 0.9) * s, SILVER, CFrame.new(0, -1.05 * s, -0.04 * s))
		box(model, leg, "BootBand", Vector3.new(0.86, 0.1, 0.92) * s, NAIL, CFrame.new(0, -1.3 * s, -0.04 * s))
		box(model, leg, "Toe", Vector3.new(0.7, 0.3, 0.4) * s, SILVER_SHADE, CFrame.new(0, -1.25 * s, -0.55 * s))
	end
	return model, rig
end

return KingCrimsonStand
