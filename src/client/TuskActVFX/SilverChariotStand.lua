--[[
	TuskActVFX.SilverChariotStand  (StarterPlayerScripts.SpinClient.TuskActVFX.SilverChariotStand)

	SILVER CHARIOT (Jean Pierre Polnareff), blocky: a slim KNIGHT in
	silver armour.
	  * a helmet with a visor (two narrow glowing eye slits) and a crest of
	    blades sweeping back over the top
	  * a breastplate with a round emblem, layered shoulder plates, a skirt
	    of plates at the hips, greaves and pointed sabatons
	  * dark joints between the plates
	  * a long, thin RAPIER in its right hand: a cup guard and a fine blade
	Registered with TuskStandModels by PolnareffVFX, so TuskStand floats it
	behind him with a pale silver-blue aura.
]]

local SilverChariotStand = {}

local SILVER = Color3.fromRGB(200, 208, 222)
local SILVER_LIGHT = Color3.fromRGB(232, 238, 248)
local SILVER_DARK = Color3.fromRGB(130, 138, 158)
local JOINT = Color3.fromRGB(50, 54, 66)
local ACCENT = Color3.fromRGB(110, 170, 230)
local EYE = Color3.fromRGB(170, 230, 255)
local BLADE = Color3.fromRGB(236, 242, 252)

SilverChariotStand.Aura = Color3.fromRGB(170, 200, 240)
SilverChariotStand.AuraLight = Color3.fromRGB(236, 244, 255)
SilverChariotStand.Offset = CFrame.new(2.2, 1.5, 2.6)

local function newPart(model, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = material or Enum.Material.Metal
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

function SilverChariotStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "SilverChariot"
	local rig = { Joints = {} }

	-- A slim torso under a breastplate.
	local torso = newPart(model, "Body", Vector3.new(1.9, 1.8, 1.0) * s, JOINT, Enum.Material.SmoothPlastic)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	box(model, torso, "Breastplate", Vector3.new(2.0, 1.2, 1.1) * s, SILVER, CFrame.new(0, 0.3 * s, 0))
	box(model, torso, "PlateRidge", Vector3.new(0.08, 1.1, 0.08) * s, SILVER_LIGHT, CFrame.new(0, 0.3 * s, -0.58 * s))
	cyl(model, torso, "Emblem", 0.08 * s, 0.42 * s, ACCENT, CFrame.new(0, 0.45 * s, -0.59 * s) * CFrame.Angles(0, math.pi / 2, 0))
	cyl(model, torso, "EmblemRim", 0.06 * s, 0.52 * s, SILVER_LIGHT, CFrame.new(0, 0.45 * s, -0.57 * s) * CFrame.Angles(0, math.pi / 2, 0))
	for k = 0, 1 do
		box(model, torso, "Faulds", Vector3.new(1.7 - k * 0.1, 0.22, 1.0) * s, k == 0 and SILVER_DARK or SILVER, CFrame.new(0, (-0.42 - k * 0.24) * s, 0))
	end
	box(model, torso, "Waist", Vector3.new(1.3, 0.6, 0.85) * s, JOINT, CFrame.new(0, -1.05 * s, 0), Enum.Material.SmoothPlastic)
	box(model, torso, "Belt", Vector3.new(1.45, 0.18, 0.95) * s, SILVER_DARK, CFrame.new(0, -1.3 * s, 0))
	-- A skirt of plates at the hips.
	for k = -2, 2 do
		box(model, torso, "Tasset", Vector3.new(0.3, 0.65, 0.08) * s, k % 2 == 0 and SILVER or SILVER_LIGHT, CFrame.new(k * 0.3 * s, -1.68 * s, -0.5 * s) * CFrame.Angles(math.rad(-8), 0, 0))
	end
	box(model, torso, "TassetBack", Vector3.new(1.5, 0.6, 0.08) * s, SILVER_DARK, CFrame.new(0, -1.65 * s, 0.5 * s) * CFrame.Angles(math.rad(8), 0, 0))
	box(model, torso, "Neck", Vector3.new(0.45, 0.4, 0.45) * s, JOINT, CFrame.new(0, 1.05 * s, 0), Enum.Material.SmoothPlastic)

	-- Helmet: a visor with two glowing slits, a crest of blades sweeping back.
	local headBase = CFrame.new(0, 1.2 * s, 0)
	local headOffset = CFrame.new(0, 0.5 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.75, 0.9, 0.8) * s, SILVER, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.41 * s
	box(model, head, "Visor", Vector3.new(0.72, 0.5, 0.08) * s, SILVER_DARK, CFrame.new(0, -0.05 * s, hf - 0.03 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "EyeSlit", Vector3.new(0.22, 0.05, 0.05) * s, EYE, CFrame.new(side * 0.16 * s, 0.06 * s, hf - 0.08 * s) * CFrame.Angles(0, 0, side * -0.15), Enum.Material.Neon)
		box(model, head, "Cheek", Vector3.new(0.1, 0.55, 0.6) * s, SILVER_LIGHT, CFrame.new(side * 0.4 * s, -0.12 * s, -0.05 * s))
	end
	box(model, head, "Grill", Vector3.new(0.04, 0.3, 0.09) * s, JOINT, CFrame.new(0, -0.2 * s, hf - 0.04 * s))
	for k = 0, 4 do
		local f = k / 4
		box(model, head, "Crest", Vector3.new(0.12, (0.5 - f * 0.12) * s, (0.32 + f * 0.1) * s), k % 2 == 0 and SILVER_LIGHT or SILVER, CFrame.new(0, (0.5 + f * 0.15) * s, (-0.25 + f * 0.65) * s) * CFrame.Angles(math.rad(-35 - f * 25), 0, 0))
	end
	box(model, head, "CrestBlade", Vector3.new(0.06, 0.12, 0.9) * s, ACCENT, CFrame.new(0, 0.72 * s, 0.75 * s) * CFrame.Angles(math.rad(-20), 0, 0), Enum.Material.Neon)

	-- Arms: layered shoulder plates, armoured forearms; the rapier in its right hand.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		for k = 0, 2 do
			box(model, torso, "Pauldron", Vector3.new(0.8 - k * 0.08, 0.2, 0.85 - k * 0.05) * s, k % 2 == 0 and SILVER or SILVER_LIGHT, CFrame.new(side * (1.15 + k * 0.05) * s, (0.82 - k * 0.18) * s, 0) * CFrame.Angles(0, 0, side * (-0.35 - k * 0.1)))
		end
		local base = CFrame.new(side * 1.25 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.05 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.5, 2.1, 0.5) * s, JOINT, base * offset, Enum.Material.SmoothPlastic)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Rerebrace", Vector3.new(0.6, 0.7, 0.6) * s, SILVER, CFrame.new(0, 0.45 * s, 0))
		box(model, arm, "Couter", Vector3.new(0.58, 0.22, 0.62) * s, SILVER_LIGHT, CFrame.new(0, -0.05 * s, -0.02 * s))
		box(model, arm, "Vambrace", Vector3.new(0.62, 0.75, 0.62) * s, SILVER, CFrame.new(0, -0.55 * s, 0))
		local hand = box(model, arm, "Gauntlet", Vector3.new(0.5, 0.45, 0.5) * s, SILVER_DARK, CFrame.new(0, -1.2 * s, 0))
		if a[1] == "ArmR" then
			-- The rapier: hilt in the hand, a cup guard, a long fine blade forward.
			cyl(model, hand, "Hilt", 0.6 * s, 0.12 * s, JOINT, CFrame.new(0, -0.05 * s, 0) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.SmoothPlastic)
			local guard = box(model, hand, "Guard", Vector3.new(0.5, 0.5, 0.18) * s, SILVER_LIGHT, CFrame.new(0, -0.05 * s, -0.35 * s))
			guard.Shape = Enum.PartType.Ball
			box(model, hand, "Quillon", Vector3.new(0.7, 0.06, 0.06) * s, SILVER_LIGHT, CFrame.new(0, -0.05 * s, -0.42 * s))
			box(model, hand, "Blade", Vector3.new(0.06, 0.12, 4.2) * s, BLADE, CFrame.new(0, -0.05 * s, -2.55 * s), Enum.Material.Metal)
			box(model, hand, "BladeShine", Vector3.new(0.02, 0.04, 4.0) * s, Color3.new(1, 1, 1), CFrame.new(0, -0.02 * s, -2.55 * s), Enum.Material.Neon)
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.05 * s, -4.6 * s)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: greaves, knee plates, pointed sabatons.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.42 * s, -1.95 * s, 0)
		local offset = CFrame.new(0, -1.15 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.55, 2.3, 0.55) * s, JOINT, base * offset, Enum.Material.SmoothPlastic)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Cuisse", Vector3.new(0.66, 0.85, 0.66) * s, SILVER, CFrame.new(0, 0.6 * s, 0))
		box(model, leg, "Poleyn", Vector3.new(0.5, 0.3, 0.15) * s, SILVER_LIGHT, CFrame.new(0, 0.05 * s, -0.36 * s))
		box(model, leg, "Greave", Vector3.new(0.64, 0.85, 0.66) * s, SILVER, CFrame.new(0, -0.55 * s, 0))
		box(model, leg, "Sabaton", Vector3.new(0.55, 0.26, 0.9) * s, SILVER_DARK, CFrame.new(0, -1.22 * s, -0.15 * s))
		box(model, leg, "Toe", Vector3.new(0.3, 0.2, 0.35) * s, SILVER_LIGHT, CFrame.new(0, -1.25 * s, -0.7 * s) * CFrame.Angles(0, math.pi / 4, 0))
	end
	return model, rig
end

return SilverChariotStand
