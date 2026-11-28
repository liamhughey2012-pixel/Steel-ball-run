---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# GoldExperienceStand

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `GoldExperienceStand` (capitals matter) |

**What it does:** GOLD EXPERIENCE (Giorno Giovanna, Part 5), blocky, matched to the art: a slim golden figure with purple joints: a smooth golden HELMET head with a SPIRAL CURL on the forehead, narrow pale eyes and PURPLE LIPS big swept-up SHOULDER WINGS (pale silver fins with a spiral on each) two purple LADYBUG studs on the chest; a lean, ribbed golden body a belt with silver STRAPS curving across the hips and a big purple buckle on one side purple balls at the elbows, wrists and knees; purple ankle bands Registered with TuskStandModels by GiornoVFX, so TuskStand floats it with a gold aura.

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **GoldExperienceStand**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.GoldExperienceStand  (StarterPlayerScripts.SpinClient.TuskActVFX.GoldExperienceStand)

	GOLD EXPERIENCE (Giorno Giovanna, Part 5), blocky, matched to the art:
	a slim golden figure with purple joints:
	  * a smooth golden HELMET head with a SPIRAL CURL on the forehead,
	    narrow pale eyes and PURPLE LIPS
	  * big swept-up SHOULDER WINGS (pale silver fins with a spiral on each)
	  * two purple LADYBUG studs on the chest; a lean, ribbed golden body
	  * a belt with silver STRAPS curving across the hips and a big purple
	    buckle on one side
	  * purple balls at the elbows, wrists and knees; purple ankle bands
	Registered with TuskStandModels by GiornoVFX, so TuskStand floats it
	with a gold aura.
]]

local GoldExperienceStand = {}

local GOLD = Color3.fromRGB(232, 198, 112)
local GOLD_LIGHT = Color3.fromRGB(250, 228, 150)
local GOLD_SHADE = Color3.fromRGB(198, 154, 72)
local ORANGE = Color3.fromRGB(222, 150, 70)
local PURPLE = Color3.fromRGB(140, 76, 200)
local PURPLE_DARK = Color3.fromRGB(90, 44, 140)
local SILVER = Color3.fromRGB(214, 218, 230)
local SILVER_SHADE = Color3.fromRGB(170, 176, 196)
local EYE = Color3.fromRGB(190, 240, 230)
local LIP = Color3.fromRGB(150, 70, 190)

GoldExperienceStand.Aura = Color3.fromRGB(255, 214, 90)
GoldExperienceStand.AuraLight = Color3.fromRGB(255, 246, 210)
GoldExperienceStand.Offset = CFrame.new(2.1, 1.5, 2.6)

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

-- A flat spiral (rings of beads), facing along -Z of `cf`.
local function spiral(model, parent, cf, radius, color, bead)
	local n = 14
	for k = 0, n - 1 do
		local a = k / n * math.pi * 3.2
		local r = radius * (1 - k / n * 0.8)
		ball(model, parent, "Spiral", bead, color, cf * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0))
	end
end

function GoldExperienceStand.build(scale)
	local s = (scale or 1) * 0.86
	local model = Instance.new("Model")
	model.Name = "GoldExperience"
	local rig = { Joints = {} }

	-- A lean golden chest.
	local torso = newPart(model, "Body", Vector3.new(1.9, 1.8, 1.0) * s, GOLD)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.5 * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Pec", Vector3.new(0.85, 0.65, 0.14) * s, GOLD_LIGHT, CFrame.new(side * 0.45 * s, 0.4 * s, front - 0.04 * s) * CFrame.Angles(0, side * 0.12, 0))
		-- Purple ladybug studs on the chest.
		egg(model, torso, "Ladybug", Vector3.new(0.34, 0.34, 0.18) * s, PURPLE, CFrame.new(side * 0.5 * s, 0.42 * s, front - 0.12 * s))
		for _, d in ipairs({ { -0.07, 0.06 }, { 0.07, 0.06 }, { 0, -0.08 } }) do
			ball(model, torso, "LadybugDot", 0.07 * s, PURPLE_DARK, CFrame.new(side * 0.5 * s + d[1] * s, 0.42 * s + d[2] * s, front - 0.2 * s))
		end
		-- Ribs.
		for k = 0, 2 do
			box(model, torso, "Rib", Vector3.new(0.45, 0.06, 0.06) * s, GOLD_SHADE, CFrame.new(side * 0.5 * s, -0.1 * s - k * 0.18 * s, front - 0.02 * s) * CFrame.Angles(0, 0, side * 0.25))
		end
	end
	box(model, torso, "Sternum", Vector3.new(0.08, 1.1, 0.08) * s, GOLD_SHADE, CFrame.new(0, 0.05 * s, front - 0.03 * s))
	-- A narrow waist, segmented belly.
	box(model, torso, "Waist", Vector3.new(1.3, 0.9, 0.82) * s, GOLD, CFrame.new(0, -1.3 * s, 0))
	for k = 0, 2 do
		box(model, torso, "Abs", Vector3.new(0.6, 0.05, 0.06) * s, GOLD_SHADE, CFrame.new(0, -1.0 * s - k * 0.22 * s, -0.42 * s))
	end
	-- The belt: silver straps curving across the hips, a purple buckle on one side.
	box(model, torso, "Belt", Vector3.new(1.45, 0.2, 0.9) * s, ORANGE, CFrame.new(0, -1.78 * s, 0))
	for k = 0, 2 do
		for _, side in ipairs({ -1, 1 }) do
			box(model, torso, "Strap", Vector3.new(0.7, 0.07, 0.07) * s, k % 2 == 0 and SILVER or SILVER_SHADE, CFrame.new(side * 0.36 * s, -1.9 * s - k * 0.14 * s, -0.5 * s - k * 0.03 * s) * CFrame.Angles(0, 0, side * (0.18 + k * 0.08)))
		end
	end
	egg(model, torso, "Buckle", Vector3.new(0.5, 0.5, 0.3) * s, PURPLE, CFrame.new(0.72 * s, -1.85 * s, -0.2 * s))
	ball(model, torso, "BuckleDot", 0.14 * s, PURPLE_DARK, CFrame.new(0.82 * s, -1.85 * s, -0.36 * s))
	box(model, torso, "Hips", Vector3.new(1.35, 0.5, 0.86) * s, GOLD_SHADE, CFrame.new(0, -2.05 * s, 0))
	box(model, torso, "Neck", Vector3.new(0.45, 0.4, 0.45) * s, GOLD_SHADE, CFrame.new(0, 1.05 * s, 0))

	-- The shoulder wings: pale fins sweeping up and out, a spiral on each.
	for _, side in ipairs({ -1, 1 }) do
		local cf = CFrame.new(side * 1.15 * s, 0.85 * s, 0.05 * s) * CFrame.Angles(0, 0, side * -0.3)
		egg(model, torso, "ShoulderPad", Vector3.new(0.8, 0.5, 0.8) * s, GOLD_LIGHT, cf)
		for k = 0, 2 do
			box(model, torso, "Wing", Vector3.new(0.12, 0.95 - k * 0.2, 0.36 - k * 0.06) * s, k == 1 and SILVER_SHADE or SILVER, cf * CFrame.new(side * (0.2 + k * 0.12) * s, (0.55 + k * 0.1) * s, (0.02 + k * 0.03) * s) * CFrame.Angles(math.rad(-6), 0, side * (-0.45 - k * 0.15)))
		end
		spiral(model, torso, cf * CFrame.new(side * 0.42 * s, 0.05 * s, 0) * CFrame.Angles(0, side * math.pi / 2, 0), 0.18 * s, GOLD_SHADE, 0.06 * s)
	end

	-- The head: a smooth golden helmet, a spiral curl on the forehead,
	-- narrow pale eyes, purple lips.
	local hs = s * 1.3
	local headBase = CFrame.new(0, 1.15 * s, 0)
	local headOffset = CFrame.new(0, 0.55 * hs, 0)
	local head, headWeld = egg(model, torso, "Head", Vector3.new(0.8, 1.05, 0.85) * hs, GOLD, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.42 * hs
	egg(model, head, "HelmetCrown", Vector3.new(0.86, 0.6, 0.92) * hs, GOLD_LIGHT, CFrame.new(0, 0.26 * hs, 0.03 * hs))
	box(model, head, "HelmetRidge", Vector3.new(0.1, 0.12, 0.9) * hs, GOLD_SHADE, CFrame.new(0, 0.53 * hs, 0.05 * hs))
	spiral(model, head, CFrame.new(0, 0.3 * hs, hf - 0.04 * hs), 0.16 * hs, GOLD_SHADE, 0.065 * hs)
	box(model, head, "Visor", Vector3.new(0.62, 0.14, 0.06) * hs, GOLD_SHADE, CFrame.new(0, 0.06 * hs, hf + 0.01 * hs))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.2, 0.06, 0.04) * hs, EYE, CFrame.new(side * 0.15 * hs, 0.05 * hs, hf - 0.025 * hs) * CFrame.Angles(0, 0, side * -0.12), Enum.Material.Neon)
		box(model, head, "Cheek", Vector3.new(0.06, 0.3, 0.05) * hs, GOLD_SHADE, CFrame.new(side * 0.26 * hs, -0.17 * hs, hf + 0.05 * hs) * CFrame.Angles(0, 0, side * 0.2))
		egg(model, head, "Ear", Vector3.new(0.1, 0.24, 0.2) * hs, GOLD_LIGHT, CFrame.new(side * 0.4 * hs, 0, 0.02 * hs))
	end
	egg(model, head, "Lips", Vector3.new(0.22, 0.09, 0.05) * hs, LIP, CFrame.new(0, -0.27 * hs, hf + 0.03 * hs))

	-- Slender arms: purple elbow and wrist balls, golden hands.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.2 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.05 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.5, 2.1, 0.5) * s, GOLD, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Bicep", Vector3.new(0.58, 0.7, 0.58) * s, GOLD_LIGHT, CFrame.new(0, 0.5 * s, -0.02 * s))
		ball(model, arm, "Elbow", 0.42 * s, PURPLE, CFrame.new(0, 0, 0))
		box(model, arm, "Forearm", Vector3.new(0.56, 0.7, 0.56) * s, GOLD, CFrame.new(0, -0.5 * s, 0))
		box(model, arm, "Wrist", Vector3.new(0.6, 0.16, 0.6) * s, PURPLE, CFrame.new(0, -0.9 * s, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.48, 0.48, 0.42) * s, GOLD_LIGHT, CFrame.new(0, -1.2 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.09, 0.26, 0.1) * s, GOLD, CFrame.new(f * 0.11 * s, -0.3 * s, -0.06 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.25 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: golden, purple knee balls and ankle bands.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.42 * s, -2.2 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.55, 2.4, 0.55) * s, GOLD, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Thigh", Vector3.new(0.66, 0.95, 0.66) * s, GOLD_LIGHT, CFrame.new(0, 0.62 * s, 0))
		ball(model, leg, "Knee", 0.46 * s, PURPLE, CFrame.new(0, 0, -0.1 * s))
		box(model, leg, "Shin", Vector3.new(0.6, 0.85, 0.6) * s, GOLD_SHADE, CFrame.new(0, -0.6 * s, 0))
		box(model, leg, "Ankle", Vector3.new(0.64, 0.14, 0.64) * s, PURPLE, CFrame.new(0, -1.05 * s, 0))
		box(model, leg, "Foot", Vector3.new(0.56, 0.3, 0.9) * s, ORANGE, CFrame.new(0, -1.3 * s, -0.16 * s))
	end
	return model, rig
end

return GoldExperienceStand
```
