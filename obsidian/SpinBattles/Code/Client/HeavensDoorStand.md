---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# HeavensDoorStand

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `HeavensDoorStand` (capitals matter) |

**What it does:** HEAVEN'S DOOR (Rohan Kishibe, Part 4), blocky, matched to the art: a small, boyish figure, all white and gold: a pale, smooth face with big GREEN eyes and thin gold lines framing it like a mask a white HAT with a wide, gold-edged brim and a tall open crown made of a GOLD LATTICE (a grid of gold bars) a long, loose WHITE COAT with gold trim down the edges and round the hem, and big GOLD CUFFS on its wide sleeves white hands; green-and-orange shoes Small: it floats at Rohan's shoulder. Registered with TuskStandModels by RohanVFX, so TuskStand floats it with a soft gold aura.

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **HeavensDoorStand**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.HeavensDoorStand  (StarterPlayerScripts.SpinClient.TuskActVFX.HeavensDoorStand)

	HEAVEN'S DOOR (Rohan Kishibe, Part 4), blocky, matched to the art: a
	small, boyish figure, all white and gold:
	  * a pale, smooth face with big GREEN eyes and thin gold lines framing
	    it like a mask
	  * a white HAT with a wide, gold-edged brim and a tall open crown made
	    of a GOLD LATTICE (a grid of gold bars)
	  * a long, loose WHITE COAT with gold trim down the edges and round the
	    hem, and big GOLD CUFFS on its wide sleeves
	  * white hands; green-and-orange shoes
	Small: it floats at Rohan's shoulder. Registered with TuskStandModels by
	RohanVFX, so TuskStand floats it with a soft gold aura.
]]

local HeavensDoorStand = {}

local WHITE = Color3.fromRGB(240, 240, 244)
local WHITE_SHADE = Color3.fromRGB(206, 206, 216)
local FACE = Color3.fromRGB(232, 236, 230)
local GOLD = Color3.fromRGB(240, 196, 60)
local GOLD_DARK = Color3.fromRGB(196, 150, 40)
local EYE = Color3.fromRGB(110, 210, 120)
local PUPIL = Color3.fromRGB(30, 60, 36)
local SHOE = Color3.fromRGB(90, 170, 70)
local SHOE_TOE = Color3.fromRGB(230, 130, 40)

HeavensDoorStand.Aura = Color3.fromRGB(250, 220, 120)
HeavensDoorStand.AuraLight = Color3.fromRGB(255, 248, 220)
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

function HeavensDoorStand.build(scale)
	local s = (scale or 1) * 0.62
	local model = Instance.new("Model")
	model.Name = "HeavensDoor"
	local rig = { Joints = {} }

	-- A slim body in a long, loose white coat with gold trim.
	local torso = newPart(model, "Body", Vector3.new(1.5, 1.7, 0.95) * s, WHITE)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.48 * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Lapel", Vector3.new(0.3, 1.5, 0.08) * s, WHITE_SHADE, CFrame.new(side * 0.2 * s, 0.05 * s, front - 0.02 * s) * CFrame.Angles(0, 0, side * 0.12))
		box(model, torso, "Trim", Vector3.new(0.06, 1.7, 0.09) * s, GOLD, CFrame.new(side * 0.06 * s, 0, front - 0.04 * s), Enum.Material.Metal)
	end
	box(model, torso, "Collar", Vector3.new(1.0, 0.3, 0.8) * s, WHITE, CFrame.new(0, 0.9 * s, 0.05 * s))
	box(model, torso, "CollarTrim", Vector3.new(1.02, 0.05, 0.82) * s, GOLD, CFrame.new(0, 1.05 * s, 0.05 * s), Enum.Material.Metal)
	-- The coat's long skirt, flaring out, gold round the hem.
	box(model, torso, "CoatSkirt", Vector3.new(1.75, 1.6, 1.15) * s, WHITE, CFrame.new(0, -1.55 * s, 0.04 * s))
	box(model, torso, "SkirtFold", Vector3.new(0.05, 1.5, 1.17) * s, WHITE_SHADE, CFrame.new(0.4 * s, -1.55 * s, 0.04 * s))
	box(model, torso, "Hem", Vector3.new(1.79, 0.1, 1.19) * s, GOLD, CFrame.new(0, -2.32 * s, 0.04 * s), Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "SkirtTrim", Vector3.new(0.06, 1.6, 0.06) * s, GOLD, CFrame.new(side * 0.06 * s, -1.55 * s, -0.55 * s), Enum.Material.Metal)
	end
	box(model, torso, "Neck", Vector3.new(0.4, 0.3, 0.4) * s, FACE, CFrame.new(0, 0.98 * s, 0))

	-- The head: a pale face, big green eyes, thin gold lines framing it.
	local headBase = CFrame.new(0, 1.1 * s, 0)
	local headOffset = CFrame.new(0, 0.55 * s, 0)
	local head, headWeld = egg(model, torso, "Head", Vector3.new(0.95, 1.1, 0.95) * s, FACE, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.45 * s
	for _, side in ipairs({ -1, 1 }) do
		egg(model, head, "Eye", Vector3.new(0.24, 0.24, 0.06) * s, EYE, CFrame.new(side * 0.2 * s, 0.02 * s, hf + 0.02 * s), Enum.Material.Neon)
		egg(model, head, "Pupil", Vector3.new(0.1, 0.12, 0.04) * s, PUPIL, CFrame.new(side * 0.2 * s, 0.02 * s, hf - 0.01 * s))
		-- Gold lines framing the face like a mask.
		box(model, head, "FaceLine", Vector3.new(0.04, 0.7, 0.04) * s, GOLD, CFrame.new(side * 0.38 * s, -0.05 * s, hf + 0.12 * s) * CFrame.Angles(0, side * 0.5, side * -0.15), Enum.Material.Metal)
		box(model, head, "EyeLine", Vector3.new(0.3, 0.035, 0.04) * s, GOLD, CFrame.new(side * 0.2 * s, 0.18 * s, hf + 0.03 * s) * CFrame.Angles(0, 0, side * 0.12), Enum.Material.Metal)
	end
	box(model, head, "ChinLine", Vector3.new(0.4, 0.035, 0.04) * s, GOLD, CFrame.new(0, -0.42 * s, hf + 0.15 * s), Enum.Material.Metal)
	box(model, head, "Mouth", Vector3.new(0.14, 0.03, 0.03) * s, WHITE_SHADE, CFrame.new(0, -0.26 * s, hf + 0.03 * s))

	-- The hat: a wide white brim edged in gold, a tall crown of gold lattice.
	local hat = CFrame.new(0, 0.48 * s, 0.03 * s) * CFrame.Angles(math.rad(-10), 0, math.rad(-12))
	cyl(model, head, "Brim", 0.08 * s, 1.75 * s, WHITE, hat * CFrame.Angles(0, 0, math.pi / 2))
	local n = 20
	for k = 0, n - 1 do
		local a0 = k / n * math.pi * 2
		box(model, head, "BrimEdge", Vector3.new(0.1, 0.1, 0.3) * s, GOLD, hat * CFrame.new(math.cos(a0) * 0.86 * s, 0.02 * s, math.sin(a0) * 0.86 * s) * CFrame.Angles(0, -a0, 0), Enum.Material.Metal)
	end
	cyl(model, head, "CrownBase", 0.12 * s, 1.0 * s, WHITE, hat * CFrame.new(0, 0.06 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
	-- Upright bars round the crown...
	for k = 0, 11 do
		local a0 = k / 12 * math.pi * 2
		box(model, head, "LatticeBar", Vector3.new(0.05, 0.75, 0.05) * s, GOLD, hat * CFrame.new(math.cos(a0) * 0.46 * s, 0.45 * s, math.sin(a0) * 0.46 * s), Enum.Material.Metal)
	end
	-- ...and rings across them.
	for r = 0, 3 do
		local y = (0.12 + r * 0.24) * s
		for k = 0, 11 do
			local a0 = (k + 0.5) / 12 * math.pi * 2
			box(model, head, "LatticeRing", Vector3.new(0.05, 0.05, 0.25) * s, r == 3 and GOLD_DARK or GOLD, hat * CFrame.new(math.cos(a0) * 0.46 * s, y, math.sin(a0) * 0.46 * s) * CFrame.Angles(0, -a0, 0), Enum.Material.Metal)
		end
	end

	-- Wide white sleeves with big gold cuffs; white hands.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 0.95 * s, 0.5 * s, 0)
		local offset = CFrame.new(0, -0.8 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.48, 1.6, 0.48) * s, WHITE, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Cuff", Vector3.new(0.66, 0.42, 0.66) * s, GOLD, CFrame.new(0, -0.6 * s, 0), Enum.Material.Metal)
		box(model, arm, "CuffRim", Vector3.new(0.68, 0.06, 0.68) * s, GOLD_DARK, CFrame.new(0, -0.4 * s, 0), Enum.Material.Metal)
		local hand = box(model, arm, "Hand", Vector3.new(0.34, 0.38, 0.22) * s, WHITE, CFrame.new(0, -0.98 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.06, 0.22, 0.07) * s, WHITE_SHADE, CFrame.new(f * 0.08 * s, -0.27 * s, 0))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.2 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs under the coat: green-and-orange shoes peeking out.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.35 * s, -1.6 * s, 0)
		local offset = CFrame.new(0, -0.8 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.36, 1.6, 0.36) * s, WHITE_SHADE, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Shoe", Vector3.new(0.42, 0.3, 0.6) * s, SHOE, CFrame.new(0, -0.72 * s, -0.1 * s))
		box(model, leg, "ShoeToe", Vector3.new(0.4, 0.26, 0.2) * s, SHOE_TOE, CFrame.new(0, -0.74 * s, -0.42 * s))
		box(model, leg, "ShoeBand", Vector3.new(0.44, 0.08, 0.62) * s, GOLD, CFrame.new(0, -0.58 * s, -0.1 * s), Enum.Material.Metal)
	end
	return model, rig
end

return HeavensDoorStand
```
