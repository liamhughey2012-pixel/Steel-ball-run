--[[
	TuskActVFX.ChariotRequiemStand  (StarterPlayerScripts.SpinClient.TuskActVFX.ChariotRequiemStand)

	SILVER CHARIOT REQUIEM: Silver Chariot after the Requiem Arrow, blocky.
	Taller than Silver Chariot, dark and wraith-like:
	  * near-black armour with deep purple shading and thin gold trim
	  * a tall hooded head: a dark rounded hood round a pale, featureless
	    MASK with two hollow eyes
	  * the REQUIEM ARROW's golden scarab set glowing in its chest
	  * a high collar of spikes; long thin arms with clawed hands
	  * no legs: a long, torn ROBE hanging down in strips
	  * a faint ring floating behind its head
	Registered with TuskStandModels by ChariotRequiemVFX; TuskStand floats
	it behind Polnareff (a little further and higher than Silver Chariot)
	with a dark violet aura.
]]

local ChariotRequiemStand = {}

local DARK = Color3.fromRGB(32, 28, 44)
local DARK_LIGHT = Color3.fromRGB(58, 48, 84)
local PURPLE = Color3.fromRGB(90, 60, 140)
local GOLD = Color3.fromRGB(232, 190, 80)
local MASK = Color3.fromRGB(232, 228, 236)
local EYE = Color3.fromRGB(14, 10, 20)
local GLOW = Color3.fromRGB(255, 220, 120)

ChariotRequiemStand.Aura = Color3.fromRGB(130, 80, 200)
ChariotRequiemStand.AuraLight = Color3.fromRGB(220, 200, 255)
ChariotRequiemStand.Offset = CFrame.new(2.6, 2.4, 3.6)

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

local function egg(model, parent, name, size, color, cf, material)
	local p = box(model, parent, name, size, color, cf, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

function ChariotRequiemStand.build(scale)
	local s = (scale or 1) * 1.0
	local model = Instance.new("Model")
	model.Name = "ChariotRequiem"
	local rig = { Joints = {} }

	-- A narrow, armoured chest.
	local torso = newPart(model, "Body", Vector3.new(1.8, 2.0, 1.0) * s, DARK)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.52 * s
	box(model, torso, "Chestplate", Vector3.new(1.6, 1.3, 0.12) * s, DARK_LIGHT, CFrame.new(0, 0.25 * s, front - 0.03 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "GoldLine", Vector3.new(0.06, 1.7, 0.13) * s, GOLD, CFrame.new(side * 0.55 * s, 0, front - 0.04 * s) * CFrame.Angles(0, 0, side * -0.12), Enum.Material.Metal)
		box(model, torso, "Rib", Vector3.new(0.5, 0.08, 0.13) * s, PURPLE, CFrame.new(side * 0.3 * s, -0.55 * s, front - 0.04 * s) * CFrame.Angles(0, 0, side * 0.3))
	end
	-- The Requiem Arrow's golden scarab, set glowing in its chest.
	local scarab = egg(model, torso, "Scarab", Vector3.new(0.5, 0.62, 0.3) * s, GOLD, CFrame.new(0, 0.35 * s, front - 0.12 * s), Enum.Material.Metal)
	box(model, torso, "ScarabGlow", Vector3.new(0.18, 0.18, 0.05) * s, GLOW, CFrame.new(0, 0.38 * s, front - 0.27 * s) * CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Neon)
	box(model, torso, "ArrowPoint", Vector3.new(0.3, 0.3, 0.06) * s, GOLD, CFrame.new(0, -0.05 * s, front - 0.1 * s) * CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Metal)
	-- A high collar of spikes round the neck.
	for k = -3, 3 do
		local a = k / 3 * math.rad(80)
		box(model, torso, "CollarSpike", Vector3.new(0.14, 0.7, 0.14) * s, k % 2 == 0 and DARK_LIGHT or DARK, CFrame.new(math.sin(a) * 0.55 * s, 1.15 * s, math.cos(a) * 0.35 * s + 0.1 * s) * CFrame.Angles(math.rad(-15) * math.cos(a), 0, -a * 0.6))
	end
	box(model, torso, "Neck", Vector3.new(0.45, 0.4, 0.45) * s, DARK, CFrame.new(0, 1.15 * s, 0))

	-- The hooded head round a pale mask with hollow eyes.
	local headBase = CFrame.new(0, 1.3 * s, 0)
	local headOffset = CFrame.new(0, 0.62 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.7, 0.9, 0.7) * s, DARK, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	egg(model, head, "Hood", Vector3.new(1.05, 1.45, 1.05) * s, DARK, CFrame.new(0, 0.2 * s, 0.1 * s))
	egg(model, head, "HoodPeak", Vector3.new(0.6, 0.8, 0.6) * s, DARK_LIGHT, CFrame.new(0, 0.75 * s, 0.3 * s) * CFrame.Angles(math.rad(-25), 0, 0))
	egg(model, head, "Mask", Vector3.new(0.6, 0.8, 0.2) * s, MASK, CFrame.new(0, 0, -0.45 * s))
	for _, side in ipairs({ -1, 1 }) do
		egg(model, head, "EyeHole", Vector3.new(0.14, 0.2, 0.06) * s, EYE, CFrame.new(side * 0.13 * s, 0.08 * s, -0.55 * s), Enum.Material.Neon)
	end
	box(model, head, "MaskLine", Vector3.new(0.03, 0.5, 0.05) * s, GOLD, CFrame.new(0, -0.05 * s, -0.56 * s), Enum.Material.Metal)
	-- A faint ring floating behind its head.
	for k = 0, 15 do
		local ang = k / 16 * math.pi * 2
		local seg = box(model, torso, "Halo", Vector3.new(0.08, 0.08, 0.42) * s, GOLD, CFrame.new(math.cos(ang) * 0.95 * s, 2.0 * s + math.sin(ang) * 0.95 * s, 0.75 * s) * CFrame.Angles(0, 0, ang) * CFrame.Angles(math.pi / 2, 0, 0), Enum.Material.Neon)
		seg.Transparency = 0.35
	end

	-- Long thin arms with clawed hands.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		box(model, torso, "Shoulder", Vector3.new(0.75, 0.5, 0.8) * s, DARK_LIGHT, CFrame.new(side * 1.1 * s, 0.85 * s, 0) * CFrame.Angles(0, 0, side * -0.4))
		box(model, torso, "ShoulderTrim", Vector3.new(0.78, 0.06, 0.83) * s, GOLD, CFrame.new(side * 1.12 * s, 0.66 * s, 0) * CFrame.Angles(0, 0, side * -0.4), Enum.Material.Metal)
		local base = CFrame.new(side * 1.15 * s, 0.5 * s, 0)
		local offset = CFrame.new(0, -1.3 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.4, 2.6, 0.4) * s, DARK, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Vambrace", Vector3.new(0.5, 0.9, 0.5) * s, DARK_LIGHT, CFrame.new(0, -0.6 * s, 0))
		box(model, arm, "Band", Vector3.new(0.52, 0.08, 0.52) * s, GOLD, CFrame.new(0, -0.15 * s, 0), Enum.Material.Metal)
		local hand = box(model, arm, "Hand", Vector3.new(0.4, 0.4, 0.4) * s, DARK, CFrame.new(0, -1.45 * s, 0))
		for f = -1, 1 do
			box(model, hand, "Claw", Vector3.new(0.08, 0.45, 0.08) * s, DARK_LIGHT, CFrame.new(f * 0.12 * s, -0.38 * s, -0.05 * s) * CFrame.Angles(math.rad(-15), 0, f * 0.15))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.4 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- No legs: a long torn robe hanging in strips.
	box(model, torso, "Waist", Vector3.new(1.4, 0.5, 0.9) * s, DARK_LIGHT, CFrame.new(0, -1.2 * s, 0))
	box(model, torso, "WaistTrim", Vector3.new(1.45, 0.07, 0.95) * s, GOLD, CFrame.new(0, -1.0 * s, 0), Enum.Material.Metal)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		local len = (2.2 + (k % 3) * 0.5) * s
		box(model, torso, "Robe", Vector3.new(0.42, len, 0.08) * s / s * s, k % 2 == 0 and DARK or PURPLE, CFrame.new(math.sin(a) * 0.62 * s, -1.45 * s - len / 2, math.cos(a) * 0.45 * s) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(6), 0, 0))
	end
	return model, rig
end

return ChariotRequiemStand
