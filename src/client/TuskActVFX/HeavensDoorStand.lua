--[[
	TuskActVFX.HeavensDoorStand  (StarterPlayerScripts.SpinClient.TuskActVFX.HeavensDoorStand)

	HEAVEN'S DOOR (Rohan Kishibe, Part 4), blocky: a small figure like the
	hero of Rohan's own manga, built from memory (no reference images yet):
	  * a slim, boyish body, pale cream skin, big dark eyes with a glint
	  * a tall TOP HAT with a gold band and a little feather
	  * a short green CAPE over a cream vest with gold buttons and a pink
	    bow at the throat
	  * puffy shorts, white socks and tall boots; white gloves
	  * an open BOOK floating at its side, its pages fluttering
	Small: it floats at Rohan's shoulder. Registered with TuskStandModels by
	RohanVFX, so TuskStand floats it with a soft green aura.
]]

local HeavensDoorStand = {}

local SKIN = Color3.fromRGB(250, 228, 206)
local SKIN_SHADE = Color3.fromRGB(226, 196, 172)
local HAT = Color3.fromRGB(46, 50, 64)
local GOLD = Color3.fromRGB(236, 192, 72)
local CAPE = Color3.fromRGB(86, 160, 104)
local CAPE_DARK = Color3.fromRGB(56, 116, 74)
local VEST = Color3.fromRGB(244, 236, 214)
local BOW = Color3.fromRGB(240, 120, 160)
local SHORTS = Color3.fromRGB(70, 90, 140)
local BOOT = Color3.fromRGB(90, 60, 40)
local WHITE = Color3.fromRGB(250, 250, 246)
local EYE = Color3.fromRGB(30, 28, 40)
local PAGE = Color3.fromRGB(250, 246, 232)

HeavensDoorStand.Aura = Color3.fromRGB(150, 230, 160)
HeavensDoorStand.AuraLight = Color3.fromRGB(236, 255, 236)
HeavensDoorStand.Offset = CFrame.new(1.9, 1.4, 1.4)

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

function HeavensDoorStand.build(scale)
	local s = (scale or 1) * 0.6
	local model = Instance.new("Model")
	model.Name = "HeavensDoor"
	local rig = { Joints = {} }

	local torso = newPart(model, "Body", Vector3.new(1.5, 1.7, 0.9) * s, VEST)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.46 * s
	for k = 0, 2 do
		local b = box(model, torso, "Button", Vector3.new(0.05, 0.14, 0.14) * s, GOLD, CFrame.new(0, (0.3 - k * 0.35) * s, front - 0.02 * s) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Metal)
		b.Shape = Enum.PartType.Cylinder
	end
	-- A pink bow at the throat.
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Bow", Vector3.new(0.28, 0.2, 0.1) * s, BOW, CFrame.new(side * 0.14 * s, 0.72 * s, front - 0.05 * s) * CFrame.Angles(0, 0, side * 0.3))
	end
	box(model, torso, "BowKnot", Vector3.new(0.1, 0.12, 0.12) * s, BOW, CFrame.new(0, 0.72 * s, front - 0.07 * s))
	-- The short green cape, from the shoulders down the back.
	box(model, torso, "CapeCollar", Vector3.new(1.7, 0.3, 1.05) * s, CAPE, CFrame.new(0, 0.75 * s, 0.02 * s))
	box(model, torso, "Cape", Vector3.new(1.8, 1.7, 0.1) * s, CAPE, CFrame.new(0, -0.05 * s, 0.55 * s) * CFrame.Angles(math.rad(10), 0, 0))
	box(model, torso, "CapeLining", Vector3.new(1.7, 1.6, 0.05) * s, CAPE_DARK, CFrame.new(0, -0.03 * s, 0.49 * s) * CFrame.Angles(math.rad(10), 0, 0))
	-- Puffy shorts.
	egg(model, torso, "Shorts", Vector3.new(1.6, 0.8, 1.0) * s, SHORTS, CFrame.new(0, -1.05 * s, 0))
	box(model, torso, "Neck", Vector3.new(0.4, 0.3, 0.4) * s, SKIN_SHADE, CFrame.new(0, 0.98 * s, 0))

	-- A boyish head, big eyes, a tall top hat.
	local headBase = CFrame.new(0, 1.1 * s, 0)
	local headOffset = CFrame.new(0, 0.55 * s, 0)
	local head, headWeld = egg(model, torso, "Head", Vector3.new(1.0, 1.1, 0.95) * s, SKIN, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.45 * s
	for _, side in ipairs({ -1, 1 }) do
		egg(model, head, "Eye", Vector3.new(0.2, 0.28, 0.06) * s, EYE, CFrame.new(side * 0.2 * s, 0.0, hf + 0.01 * s))
		egg(model, head, "Glint", Vector3.new(0.07, 0.08, 0.03) * s, WHITE, CFrame.new(side * 0.2 * s + 0.04 * s, 0.06 * s, hf - 0.02 * s), Enum.Material.Neon)
		egg(model, head, "Cheek", Vector3.new(0.14, 0.08, 0.03) * s, BOW, CFrame.new(side * 0.3 * s, -0.2 * s, hf + 0.04 * s))
	end
	box(model, head, "Smile", Vector3.new(0.2, 0.04, 0.04) * s, SKIN_SHADE, CFrame.new(0, -0.3 * s, hf + 0.04 * s))
	-- Hair poking out under the hat.
	for k = -2, 2 do
		box(model, head, "Hair", Vector3.new(0.2, 0.25, 0.2) * s, CAPE_DARK, CFrame.new(k * 0.2 * s, 0.32 * s, -0.25 * s) * CFrame.Angles(math.rad(-20), 0, k * 0.2))
	end
	local hatBase = CFrame.new(0, 0.5 * s, 0.02 * s) * CFrame.Angles(0, 0, math.rad(-8))
	local brim = box(model, head, "HatBrim", Vector3.new(0.08, 1.35, 1.35) * s, HAT, hatBase * CFrame.Angles(0, 0, math.pi / 2))
	brim.Shape = Enum.PartType.Cylinder
	local crown = box(model, head, "HatCrown", Vector3.new(0.9, 0.85, 0.85) * s, HAT, hatBase * CFrame.new(0, 0.45 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
	crown.Shape = Enum.PartType.Cylinder
	local band = box(model, head, "HatBand", Vector3.new(0.16, 0.88, 0.88) * s, GOLD, hatBase * CFrame.new(0, 0.12 * s, 0) * CFrame.Angles(0, 0, math.pi / 2), Enum.Material.Metal)
	band.Shape = Enum.PartType.Cylinder
	box(model, head, "Feather", Vector3.new(0.08, 0.6, 0.18) * s, WHITE, hatBase * CFrame.new(0.4 * s, 0.4 * s, 0.1 * s) * CFrame.Angles(0, 0, -0.4))

	-- Slim arms in white gloves.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 0.95 * s, 0.5 * s, 0)
		local offset = CFrame.new(0, -0.8 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.38, 1.6, 0.38) * s, VEST, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Cuff", Vector3.new(0.44, 0.12, 0.44) * s, CAPE, CFrame.new(0, -0.55 * s, 0))
		local hand = egg(model, arm, "Glove", Vector3.new(0.42, 0.42, 0.42) * s, WHITE, CFrame.new(0, -0.9 * s, 0))
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.2 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: white socks and tall boots.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.38 * s, -1.35 * s, 0)
		local offset = CFrame.new(0, -0.8 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.4, 1.6, 0.4) * s, WHITE, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Boot", Vector3.new(0.5, 0.75, 0.55) * s, BOOT, CFrame.new(0, -0.45 * s, 0))
		box(model, leg, "BootTop", Vector3.new(0.54, 0.1, 0.58) * s, GOLD, CFrame.new(0, -0.05 * s, 0), Enum.Material.Metal)
		box(model, leg, "Toe", Vector3.new(0.48, 0.25, 0.4) * s, BOOT, CFrame.new(0, -0.75 * s, -0.25 * s))
	end

	-- An open book floating at its side, pages fanned.
	local bookCF = CFrame.new(-1.6 * s, 0.1 * s, -0.4 * s) * CFrame.Angles(math.rad(-30), math.rad(20), 0)
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "BookCover", Vector3.new(0.7, 0.05, 0.95) * s, CAPE_DARK, bookCF * CFrame.new(side * 0.36 * s, 0, 0) * CFrame.Angles(0, 0, side * -0.18))
		for k = 0, 2 do
			box(model, torso, "Page", Vector3.new(0.64, 0.02, 0.9) * s, PAGE, bookCF * CFrame.new(side * 0.33 * s, (0.04 + k * 0.025) * s, 0) * CFrame.Angles(0, 0, side * (-0.18 + k * 0.12)))
		end
	end
	return model, rig
end

return HeavensDoorStand
