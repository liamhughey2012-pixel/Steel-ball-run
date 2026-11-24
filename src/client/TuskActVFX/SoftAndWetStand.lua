--[[
	TuskActVFX.SoftAndWetStand  (StarterPlayerScripts.SpinClient.TuskActVFX.SoftAndWetStand)

	SOFT & WET (Josuke Higashikata, JoJolion), blocky, matched to the art:
	  * a sleek pale-gold body
	  * a smooth round head with big blue domes on each side, a white star
	    set in each
	  * a ring of dark beads round its neck and wrists
	  * an anchor on its chest, a star on each shoulder
	  * a magenta band round its hips
	Registered with TuskStandModels by JosukeVFX, so TuskStand floats it
	behind Josuke (players and NPCs) with a soft blue aura.
]]

local SoftAndWetStand = {}

local GOLD = Color3.fromRGB(232, 204, 120)
local GOLD_SHADE = Color3.fromRGB(196, 164, 84)
local GOLD_LIGHT = Color3.fromRGB(250, 230, 160)
local BLUE = Color3.fromRGB(70, 150, 220)
local WHITE = Color3.fromRGB(250, 252, 255)
local BEAD = Color3.fromRGB(40, 70, 90)
local MAGENTA = Color3.fromRGB(190, 60, 120)
local LINE = Color3.fromRGB(120, 90, 30)

SoftAndWetStand.Aura = Color3.fromRGB(150, 210, 255)
SoftAndWetStand.AuraLight = Color3.fromRGB(230, 245, 255)
SoftAndWetStand.Offset = CFrame.new(2.2, 1.6, 2.8)

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

-- A little 4-point star (two crossed squares) on a face, facing -Z of cf.
local function star(model, parent, cf, size, color)
	box(model, parent, "Star", Vector3.new(size, size, 0.05), color, cf * CFrame.Angles(0, 0, math.pi / 4))
	box(model, parent, "Star", Vector3.new(size * 0.7, size * 0.7, 0.06), color, cf)
end

function SoftAndWetStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "SoftAndWet"
	local rig = { Joints = {} }

	local torso = newPart(model, "Body", Vector3.new(2.0, 1.8, 1.0) * s, GOLD, Enum.Material.SmoothPlastic)
	torso.Reflectance = 0.1
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.51 * s
	box(model, torso, "Chest", Vector3.new(1.6, 0.9, 0.08) * s, GOLD_LIGHT, CFrame.new(0, 0.35 * s, front - 0.02 * s))
	-- An anchor on its chest.
	box(model, torso, "Anchor", Vector3.new(0.12, 0.9, 0.05) * s, LINE, CFrame.new(0, 0.2 * s, front - 0.08 * s))
	box(model, torso, "AnchorBar", Vector3.new(0.5, 0.1, 0.05) * s, LINE, CFrame.new(0, 0.5 * s, front - 0.08 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "AnchorFluke", Vector3.new(0.32, 0.1, 0.05) * s, LINE, CFrame.new(side * 0.16 * s, -0.2 * s, front - 0.08 * s) * CFrame.Angles(0, 0, side * 0.6))
	end
	box(model, torso, "Waist", Vector3.new(1.4, 0.7, 0.85) * s, GOLD_SHADE, CFrame.new(0, -1.15 * s, 0))
	box(model, torso, "HipBand", Vector3.new(1.55, 0.45, 0.95) * s, MAGENTA, CFrame.new(0, -1.6 * s, 0))
	box(model, torso, "Neck", Vector3.new(0.45, 0.45, 0.45) * s, GOLD_SHADE, CFrame.new(0, 1.1 * s, 0))
	-- A ring of dark beads round its neck.
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		ball(model, torso, "Bead", 0.18 * s, BEAD, CFrame.new(math.sin(a) * 0.45 * s, 0.95 * s, math.cos(a) * 0.4 * s))
	end

	-- Head: smooth and round, blue domes with white stars on each side.
	local headBase = CFrame.new(0, 1.2 * s, 0)
	local headOffset = CFrame.new(0, 0.55 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.95, 1.05, 1.0) * s, GOLD, headBase * headOffset)
	head.Reflectance = 0.12
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.5 * s
	box(model, head, "Crown", Vector3.new(0.85, 0.25, 0.9) * s, GOLD_LIGHT, CFrame.new(0, 0.6 * s, 0.02 * s))
	box(model, head, "Visor", Vector3.new(0.75, 0.2, 0.06) * s, GOLD_SHADE, CFrame.new(0, 0.18 * s, hf - 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.2, 0.09, 0.05) * s, BEAD, CFrame.new(side * 0.2 * s, 0.05 * s, hf - 0.03 * s))
		ball(model, head, "EarDome", 0.75 * s, BLUE, CFrame.new(side * 0.55 * s, 0.1 * s, 0.05 * s), Enum.Material.SmoothPlastic)
		star(model, head, CFrame.new(side * 0.93 * s, 0.1 * s, 0.05 * s) * CFrame.Angles(0, side * math.pi / 2, 0), 0.28 * s, WHITE)
	end
	box(model, head, "Mouth", Vector3.new(0.3, 0.05, 0.05) * s, LINE, CFrame.new(0, -0.3 * s, hf - 0.02 * s))

	-- Arms: stars on the shoulders, bead bracelets.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local shoulder = ball(model, torso, "Shoulder", 0.85 * s, GOLD_LIGHT, CFrame.new(side * 1.3 * s, 0.6 * s, 0))
		star(model, shoulder, CFrame.new(0, 0, -0.44 * s), 0.3 * s, BLUE)
		local base = CFrame.new(side * 1.35 * s, 0.35 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local size = Vector3.new(0.55, 2.2, 0.55) * s
		local arm, weld = box(model, torso, a[1], size, GOLD, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Forearm", Vector3.new(0.62, 0.85, 0.62) * s, GOLD_SHADE, CFrame.new(0, -0.5 * s, 0))
		for k = 0, 5 do
			local ang = k / 6 * math.pi * 2
			ball(model, arm, "Bead", 0.14 * s, BEAD, CFrame.new(math.sin(ang) * 0.33 * s, -0.95 * s, math.cos(ang) * 0.33 * s))
		end
		local hand = box(model, arm, "Hand", Vector3.new(0.55, 0.5, 0.5) * s, GOLD, CFrame.new(0, -1.3 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.1, 0.38, 0.1) * s, GOLD_SHADE, CFrame.new(f * 0.12 * s, -0.4 * s, -0.05 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.42 * s, -1.8 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local size = Vector3.new(0.62, 2.4, 0.62) * s
		local leg, weld = box(model, torso, "Leg" .. i, size, GOLD, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		ball(model, leg, "Knee", 0.5 * s, GOLD_LIGHT, CFrame.new(0, 0.1 * s, -0.2 * s))
		box(model, leg, "Foot", Vector3.new(0.6, 0.3, 0.95) * s, GOLD_SHADE, CFrame.new(0, -1.3 * s, -0.15 * s))
	end
	return model, rig
end

return SoftAndWetStand
