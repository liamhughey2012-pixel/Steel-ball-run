--[[
	TuskActVFX.SilentWayStand  (StarterPlayerScripts.SpinClient.TuskActVFX.SilentWayStand)

	The IN A SILENT WAY Stand model (Sandman), blocky, matched to the art:
	  * a golden armoured body with six orange roses down the chest
	  * a skull face under a gold helmet with round orange goggle eyes and a
	    spiral emblem on the forehead
	  * a huge feather headdress: white feathers with dark red tips
	  * big gold shoulder pads, gold arms with zigzag bands, bony white hands
	  * a gold skirt with zigzags and spirals, patterned gold legs
	Registered with TuskStandModels by SandmanVFX, so TuskStand floats it
	behind Sandman (players and NPCs) with a golden aura, exactly like Tusk.
	A custom model at ReplicatedStorage.SpinAssets.TuskAct8 replaces it.
]]

local SilentWayStand = {}

local GOLD = Color3.fromRGB(232, 182, 52)
local GOLD_DARK = Color3.fromRGB(170, 116, 30)
local ORANGE = Color3.fromRGB(236, 120, 44)
local ROSE = Color3.fromRGB(214, 84, 44)
local ROSE_DARK = Color3.fromRGB(140, 40, 28)
local BONE = Color3.fromRGB(238, 230, 212)
local BONE_DARK = Color3.fromRGB(190, 178, 156)
local DARK = Color3.fromRGB(46, 28, 22)
local FEATHER = Color3.fromRGB(242, 238, 228)
local FEATHER_TIP = Color3.fromRGB(122, 38, 30)
local EYE = Color3.fromRGB(255, 120, 40)

SilentWayStand.Aura = Color3.fromRGB(255, 196, 70)
SilentWayStand.AuraLight = Color3.fromRGB(255, 240, 180)
SilentWayStand.Offset = CFrame.new(2.7, 1.7, 3.3) -- big: floats further back

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

-- A box welded to `parent` at local `cf` (the Weld's C0 can be animated).
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

-- A blocky rose facing -Z at `cf`.
local function rose(model, parent, cf, s)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		box(model, parent, "Petal", Vector3.new(0.3, 0.3, 0.12) * s, i % 2 == 0 and ROSE or ORANGE, cf * CFrame.new(math.cos(a) * 0.13 * s, math.sin(a) * 0.13 * s, 0) * CFrame.Angles(0, 0, a))
	end
	box(model, parent, "Petal", Vector3.new(0.26, 0.26, 0.12) * s, ORANGE, cf * CFrame.new(0, 0, -0.05 * s) * CFrame.Angles(0, 0, math.pi / 4))
	box(model, parent, "RoseCore", Vector3.new(0.13, 0.13, 0.1) * s, ROSE_DARK, cf * CFrame.new(0, 0, -0.1 * s))
end

-- A square spiral (ring + centre) facing -Z at `cf`.
local function spiral(model, parent, cf, size, color)
	local t = size * 0.18
	box(model, parent, "Spiral", Vector3.new(size, t, 0.05), color, cf * CFrame.new(0, size / 2 - t / 2, 0))
	box(model, parent, "Spiral", Vector3.new(size, t, 0.05), color, cf * CFrame.new(0, -size / 2 + t / 2, 0))
	box(model, parent, "Spiral", Vector3.new(t, size, 0.05), color, cf * CFrame.new(size / 2 - t / 2, 0, 0))
	box(model, parent, "Spiral", Vector3.new(t, size * 0.6, 0.05), color, cf * CFrame.new(-size / 2 + t / 2, -size * 0.2, 0))
	box(model, parent, "Spiral", Vector3.new(t * 1.4, t * 1.4, 0.05), color, cf)
end

-- A row of zigzag diamonds across a face.
local function zigzag(model, parent, cf, width, count, color, s)
	for i = 0, count - 1 do
		local x = (i - (count - 1) / 2) * width / count
		box(model, parent, "Zigzag", Vector3.new(0.16, 0.16, 0.04) * s, color, cf * CFrame.new(x, 0, 0) * CFrame.Angles(0, 0, math.pi / 4))
	end
end

function SilentWayStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "InASilentWay"
	local rig = { Joints = {} }

	-- Torso (the anchored root the Stand is moved by).
	local torso = newPart(model, "Body", Vector3.new(2.4, 2.2, 1.2) * s, GOLD)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.6 * s
	box(model, torso, "Collar", Vector3.new(2.6, 0.32, 1.32) * s, GOLD_DARK, CFrame.new(0, 1.0 * s, 0))
	box(model, torso, "Chest", Vector3.new(1.9, 1.5, 0.12) * s, GOLD_DARK, CFrame.new(0, 0.1 * s, front - 0.04 * s))
	-- Six roses down the chest.
	for _, x in ipairs({ -0.5, 0.5 }) do
		for _, y in ipairs({ 0.6, 0.05, -0.5 }) do
			rose(model, torso, CFrame.new(x * s, y * s, front - 0.14 * s), s * 1.1)
		end
	end
	box(model, torso, "Belt", Vector3.new(2.5, 0.3, 1.3) * s, GOLD_DARK, CFrame.new(0, -1.0 * s, 0))
	-- Skirt with zigzags and spirals.
	box(model, torso, "Skirt", Vector3.new(2.5, 1.5, 1.36) * s, GOLD, CFrame.new(0, -1.85 * s, 0))
	box(model, torso, "SkirtHem", Vector3.new(2.6, 0.18, 1.44) * s, GOLD_DARK, CFrame.new(0, -2.55 * s, 0))
	zigzag(model, torso, CFrame.new(0, -1.4 * s, -0.7 * s), 2.2 * s, 9, ORANGE, s)
	zigzag(model, torso, CFrame.new(0, -2.25 * s, -0.7 * s), 2.2 * s, 9, DARK, s)
	for _, x in ipairs({ -0.7, 0.7 }) do
		spiral(model, torso, CFrame.new(x * s, -1.85 * s, -0.71 * s), 0.42 * s, DARK)
	end

	-- Head: a skull under a gold helmet.
	local headBase = CFrame.new(0, 1.15 * s, 0)
	local headOffset = CFrame.new(0, 0.62 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(1.1, 1.2, 1.1) * s, BONE, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.55 * s
	box(model, head, "Helmet", Vector3.new(1.26, 0.6, 1.26) * s, GOLD, CFrame.new(0, 0.38 * s, 0))
	box(model, head, "Visor", Vector3.new(1.24, 0.46, 0.12) * s, GOLD, CFrame.new(0, 0.12 * s, hf - 0.06 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.34, 0.34, 0.08) * s, EYE, CFrame.new(side * 0.28 * s, 0.1 * s, hf - 0.14 * s), Enum.Material.Neon)
		box(model, head, "EyeRim", Vector3.new(0.42, 0.06, 0.06) * s, GOLD_DARK, CFrame.new(side * 0.28 * s, 0.3 * s, hf - 0.14 * s))
		box(model, head, "Pupil", Vector3.new(0.12, 0.12, 0.06) * s, DARK, CFrame.new(side * 0.28 * s, 0.1 * s, hf - 0.19 * s))
		-- Cheekbones.
		box(model, head, "Cheek", Vector3.new(0.28, 0.14, 0.06) * s, BONE_DARK, CFrame.new(side * 0.32 * s, -0.16 * s, hf - 0.03 * s))
	end
	spiral(model, head, CFrame.new(0, 0.5 * s, hf - 0.14 * s), 0.3 * s, GOLD_DARK)
	-- Skull: nose hole and a grin of teeth.
	box(model, head, "Nose", Vector3.new(0.14, 0.16, 0.05) * s, DARK, CFrame.new(0, -0.14 * s, hf - 0.03 * s))
	box(model, head, "Mouth", Vector3.new(0.78, 0.24, 0.05) * s, DARK, CFrame.new(0, -0.4 * s, hf - 0.03 * s))
	for i = -2, 2 do
		box(model, head, "Tooth", Vector3.new(0.11, 0.2, 0.06) * s, BONE, CFrame.new(i * 0.15 * s, -0.4 * s, hf - 0.05 * s))
	end
	-- Feather headdress: a big fan behind the helmet, a shorter inner row.
	box(model, head, "Band", Vector3.new(1.34, 0.16, 1.34) * s, GOLD_DARK, CFrame.new(0, 0.2 * s, 0))
	local fanRoot = CFrame.new(0, 0.45 * s, 0.4 * s) * CFrame.Angles(-0.35, 0, 0)
	local count = 13
	for i = 0, count - 1 do
		local a = math.rad(-84 + i * 168 / (count - 1))
		local dir = fanRoot * CFrame.Angles(0, 0, a)
		box(model, head, "Feather", Vector3.new(0.26, 1.5, 0.06) * s, FEATHER, dir * CFrame.new(0, 1.15 * s, 0))
		box(model, head, "FeatherTip", Vector3.new(0.28, 0.5, 0.07) * s, FEATHER_TIP, dir * CFrame.new(0, 2.05 * s, 0))
	end
	for i = 0, 8 do
		local a = math.rad(-64 + i * 16)
		local dir = fanRoot * CFrame.new(0, 0, -0.08 * s) * CFrame.Angles(0, 0, a)
		box(model, head, "Feather", Vector3.new(0.22, 0.9, 0.06) * s, FEATHER, dir * CFrame.new(0, 0.85 * s, 0))
		box(model, head, "FeatherTip", Vector3.new(0.24, 0.3, 0.07) * s, ORANGE, dir * CFrame.new(0, 1.38 * s, 0))
	end

	-- Shoulders and arms (bony hands).
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		box(model, torso, "ShoulderPad", Vector3.new(1.0, 0.7, 1.3) * s, GOLD, CFrame.new(side * 1.5 * s, 0.95 * s, 0))
		box(model, torso, "ShoulderTrim", Vector3.new(1.06, 0.14, 1.36) * s, GOLD_DARK, CFrame.new(side * 1.5 * s, 0.62 * s, 0))
		for k = -1, 1 do
			box(model, torso, "Spike", Vector3.new(0.16, 0.3, 0.16) * s, GOLD_DARK, CFrame.new(side * 1.55 * s, 1.38 * s, k * 0.38 * s) * CFrame.Angles(0, 0, side * -0.3))
		end
		local base = CFrame.new(side * 1.55 * s, 0.6 * s, 0)
		local offset = CFrame.new(0, -1.15 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.72, 2.3, 0.72) * s, GOLD, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "ArmBand", Vector3.new(0.8, 0.22, 0.8) * s, ORANGE, CFrame.new(0, 0.1 * s, 0))
		box(model, arm, "Cuff", Vector3.new(0.82, 0.3, 0.82) * s, GOLD_DARK, CFrame.new(0, -0.95 * s, 0))
		zigzag(model, arm, CFrame.new(0, -0.5 * s, -0.37 * s), 0.6 * s, 3, DARK, s)
		local hand = box(model, arm, "Hand", Vector3.new(0.6, 0.42, 0.5) * s, BONE, CFrame.new(0, -1.35 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.11, 0.42, 0.11) * s, BONE, CFrame.new(f * 0.14 * s, -0.36 * s, -0.08 * s))
			box(model, hand, "Knuckle", Vector3.new(0.13, 0.08, 0.13) * s, BONE_DARK, CFrame.new(f * 0.14 * s, -0.24 * s, -0.08 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.4 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: gold with zigzag knee bands and gold feet.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.6 * s, -2.3 * s, 0)
		local offset = CFrame.new(0, -1.0 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.85, 2.0, 0.85) * s, GOLD, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "KneeBand", Vector3.new(0.92, 0.36, 0.92) * s, GOLD_DARK, CFrame.new(0, 0.1 * s, 0))
		zigzag(model, leg, CFrame.new(0, 0.1 * s, -0.47 * s), 0.7 * s, 3, ORANGE, s)
		box(model, leg, "Foot", Vector3.new(0.9, 0.3, 1.2) * s, GOLD_DARK, CFrame.new(0, -1.05 * s, -0.15 * s))
	end
	return model, rig
end

return SilentWayStand
