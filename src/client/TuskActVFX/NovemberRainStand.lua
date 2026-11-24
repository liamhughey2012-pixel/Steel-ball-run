--[[
	TuskActVFX.NovemberRainStand  (StarterPlayerScripts.SpinClient.TuskActVFX.NovemberRainStand)

	NOVEMBER RAIN (Jodio Joestar, The JOJOLands), blocky, matched to the
	art: a sleek white figure.
	  * a rounded white helmet with a dark visor and two cyan lights, a fin
	    down the middle
	  * long light-blue streamers flowing back from its head like a mane
	  * two long hoses arching out of its back and curving down past its
	    feet, banded in grey
	  * a blue raindrop on its chest, blue bands on its forearms and knees
	Registered with TuskStandModels by JodioVFX, so TuskStand floats it
	behind Jodio (players and NPCs) with a pale blue aura.
]]

local NovemberRainStand = {}

local BODY = Color3.fromRGB(236, 240, 248)
local PANEL = Color3.fromRGB(196, 206, 222)
local BLUE = Color3.fromRGB(120, 190, 245)
local BLUE_DEEP = Color3.fromRGB(70, 140, 220)
local VISOR = Color3.fromRGB(40, 50, 80)
local LIGHT = Color3.fromRGB(140, 240, 255)
local HOSE_BAND = Color3.fromRGB(150, 160, 180)

NovemberRainStand.Aura = Color3.fromRGB(150, 210, 255)
NovemberRainStand.AuraLight = Color3.fromRGB(220, 240, 255)
NovemberRainStand.Offset = CFrame.new(2.2, 1.6, 2.8)

local ALONG_Y = CFrame.Angles(0, 0, math.pi / 2)

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

local function cyl(model, parent, name, length, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(length, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A hose along a list of points (in the parent's space): a tube between
-- each pair, a grey band at each joint.
local function hose(model, parent, points, d)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		-- Cylinders run along X: aim X from a to b.
		local look = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0)
		cyl(model, parent, "Hose", len + d * 0.4, d, BODY, look)
		ball(model, parent, "HoseBand", d * 1.25, HOSE_BAND, CFrame.new(b))
	end
end

function NovemberRainStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "NovemberRain"
	local rig = { Joints = {} }

	local torso = newPart(model, "Body", Vector3.new(1.7, 1.7, 0.9) * s, BODY)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.46 * s
	box(model, torso, "ChestPlate", Vector3.new(1.4, 0.8, 0.08) * s, PANEL, CFrame.new(0, 0.35 * s, front - 0.02 * s))
	-- A blue raindrop on its chest.
	box(model, torso, "Drop", Vector3.new(0.36, 0.36, 0.06) * s, BLUE, CFrame.new(0, 0.32 * s, front - 0.07 * s) * CFrame.Angles(0, 0, math.pi / 4))
	ball(model, torso, "DropBulb", 0.42 * s, BLUE, CFrame.new(0, 0.18 * s, front - 0.02 * s))
	box(model, torso, "Abdomen", Vector3.new(1.1, 0.8, 0.75) * s, PANEL, CFrame.new(0, -1.15 * s, 0))
	box(model, torso, "Hips", Vector3.new(1.3, 0.45, 0.8) * s, BODY, CFrame.new(0, -1.7 * s, 0))
	box(model, torso, "Belt", Vector3.new(1.34, 0.12, 0.84) * s, BLUE_DEEP, CFrame.new(0, -1.5 * s, 0))
	cyl(model, torso, "Neck", 0.5 * s, 0.4 * s, PANEL, CFrame.new(0, 1.05 * s, 0) * ALONG_Y)
	for _, side in ipairs({ -1, 1 }) do
		ball(model, torso, "Shoulder", 0.7 * s, BODY, CFrame.new(side * 1.0 * s, 0.6 * s, 0))
		-- A hose arching up out of its back and curving down past its feet.
		local pts = {
			Vector3.new(side * 0.5, 0.6, 0.5) * s,
			Vector3.new(side * 1.3, 1.9, 1.2) * s,
			Vector3.new(side * 2.4, 2.3, 1.4) * s,
			Vector3.new(side * 3.3, 1.5, 1.0) * s,
			Vector3.new(side * 3.7, 0.0, 0.4) * s,
			Vector3.new(side * 3.6, -1.8, -0.3) * s,
			Vector3.new(side * 3.2, -3.4, -0.9) * s,
		}
		hose(model, torso, pts, 0.22 * s)
		ball(model, torso, "HoseTip", 0.34 * s, BLUE, CFrame.new(pts[#pts]))
	end

	-- Head: a rounded helmet, a dark visor with two lights, a fin.
	local headBase = CFrame.new(0, 1.3 * s, 0)
	local headOffset = CFrame.new(0, 0.5 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.85, 0.8, 0.85) * s, BODY, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	ball(model, head, "Dome", 0.9 * s, BODY, CFrame.new(0, 0.25 * s, 0.02 * s))
	box(model, head, "Chin", Vector3.new(0.6, 0.25, 0.7) * s, PANEL, CFrame.new(0, -0.45 * s, -0.04 * s))
	box(model, head, "Visor", Vector3.new(0.9, 0.24, 0.1) * s, VISOR, CFrame.new(0, 0.05 * s, -0.43 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Light", Vector3.new(0.16, 0.08, 0.04) * s, LIGHT, CFrame.new(side * 0.2 * s, 0.05 * s, -0.49 * s), Enum.Material.Neon)
	end
	box(model, head, "Fin", Vector3.new(0.1, 0.35, 0.9) * s, PANEL, CFrame.new(0, 0.62 * s, 0.05 * s))
	-- Long blue streamers flowing back from its head.
	for k = -2, 2 do
		local len = (2.6 - math.abs(k) * 0.35) * s
		local tilt = CFrame.Angles(-0.55 + math.abs(k) * 0.06, k * 0.18, k * 0.14)
		box(model, head, "Streamer", Vector3.new(0.26 * s, len, 0.07 * s), k % 2 == 0 and BLUE or BLUE_DEEP,
			CFrame.new(k * 0.14 * s, 0.35 * s, 0.4 * s) * tilt * CFrame.new(0, -len / 2, 0))
	end

	-- Arms: slim, blue bands on the forearms.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.1 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.45, 2.2, 0.45) * s, BODY, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		ball(model, arm, "Elbow", 0.45 * s, PANEL, CFrame.new(0, 0, 0))
		box(model, arm, "Band", Vector3.new(0.52, 0.14, 0.52) * s, BLUE, CFrame.new(0, -0.55 * s, 0))
		box(model, arm, "Band", Vector3.new(0.52, 0.14, 0.52) * s, BLUE, CFrame.new(0, -0.8 * s, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.5, 0.45, 0.45) * s, BODY, CFrame.new(0, -1.3 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.09, 0.38, 0.1) * s, PANEL, CFrame.new(f * 0.11 * s, -0.38 * s, -0.04 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: slim, blue knee pads, pointed feet.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.4 * s, -1.85 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.5, 2.4, 0.5) * s, BODY, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Knee", Vector3.new(0.56, 0.4, 0.2) * s, BLUE, CFrame.new(0, 0.05 * s, -0.25 * s))
		box(model, leg, "Foot", Vector3.new(0.5, 0.3, 1.0) * s, PANEL, CFrame.new(0, -1.3 * s, -0.2 * s))
		box(model, leg, "Toe", Vector3.new(0.3, 0.2, 0.3) * s, BLUE_DEEP, CFrame.new(0, -1.32 * s, -0.75 * s) * CFrame.Angles(0, math.pi / 4, 0))
	end
	return model, rig
end

return NovemberRainStand
