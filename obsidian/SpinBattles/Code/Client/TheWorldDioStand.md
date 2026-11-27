---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# TheWorldDioStand

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `TheWorldDioStand` (capitals matter) |

**What it does:** THE WORLD (DIO, Part 3), blocky. A different Stand from Diego's The World (TheWorldStand, the padded knight from Part 7): a tall, muscular GOLDEN body with sharp green trim lines the head: a helmet with a crest sweeping back to a point, a FACEPLATE over the mouth (green seams), narrow white eyes, small fins at the ears two HOSES running from the back of its head down into its back rounded gold shoulder guards rimmed in green; green wrist and ankle bands; a gold belt with a green buckle HEART-shaped guards on both knees, and a heart on its chest Registered with TuskStandModels by DioVFX, so TuskStand floats it behind DIO with a golden aura.

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **TheWorldDioStand**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.TheWorldDioStand  (StarterPlayerScripts.SpinClient.TuskActVFX.TheWorldDioStand)

	THE WORLD (DIO, Part 3), blocky. A different Stand from Diego's The
	World (TheWorldStand, the padded knight from Part 7):
	  * a tall, muscular GOLDEN body with sharp green trim lines
	  * the head: a helmet with a crest sweeping back to a point, a
	    FACEPLATE over the mouth (green seams), narrow white eyes, small
	    fins at the ears
	  * two HOSES running from the back of its head down into its back
	  * rounded gold shoulder guards rimmed in green; green wrist and
	    ankle bands; a gold belt with a green buckle
	  * HEART-shaped guards on both knees, and a heart on its chest
	Registered with TuskStandModels by DioVFX, so TuskStand floats it
	behind DIO with a golden aura.
]]

local TheWorldDioStand = {}

local GOLD = Color3.fromRGB(240, 200, 60)
local GOLD_SHADE = Color3.fromRGB(198, 154, 38)
local GOLD_LIGHT = Color3.fromRGB(255, 228, 120)
local GREEN = Color3.fromRGB(56, 156, 112)
local GREEN_DARK = Color3.fromRGB(30, 100, 72)
local LINE = Color3.fromRGB(110, 80, 20)
local EYE = Color3.fromRGB(255, 252, 235)
local HOSE = Color3.fromRGB(48, 120, 90)

TheWorldDioStand.Aura = Color3.fromRGB(255, 214, 70)
TheWorldDioStand.AuraLight = Color3.fromRGB(255, 244, 190)
TheWorldDioStand.Offset = CFrame.new(2.2, 1.6, 2.8)

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

-- A rod from a to b in the parent's space.
local function rod(model, parent, name, a, b, d, color)
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	local p = box(model, parent, name, Vector3.new(len + d * 0.4, d, d), color, CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A heart facing forward (-Z of `cf`): two lobes and a point, green rim.
local function heart(model, parent, cf, size, s)
	local h = size * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, parent, "HeartLobe", Vector3.new(0.09 * s, h * 0.6, h * 0.6), GOLD_LIGHT, cf * CFrame.new(side * h * 0.2, h * 0.14, -0.01 * s) * CFrame.Angles(0, math.pi / 2, 0)).Shape = Enum.PartType.Cylinder
		box(model, parent, "HeartLobeRim", Vector3.new(0.07 * s, h * 0.72, h * 0.72), GREEN, cf * CFrame.new(side * h * 0.2, h * 0.14, 0.02 * s) * CFrame.Angles(0, math.pi / 2, 0)).Shape = Enum.PartType.Cylinder
	end
	box(model, parent, "HeartPoint", Vector3.new(h * 0.56, h * 0.56, 0.09 * s), GOLD_LIGHT, cf * CFrame.new(0, -h * 0.1, -0.01 * s) * CFrame.Angles(0, 0, math.pi / 4))
	box(model, parent, "HeartRim", Vector3.new(h * 0.74, h * 0.74, 0.06 * s), GREEN, cf * CFrame.new(0, -h * 0.1, 0.02 * s) * CFrame.Angles(0, 0, math.pi / 4))
end

function TheWorldDioStand.build(scale)
	local s = (scale or 1) * 0.9
	local model = Instance.new("Model")
	model.Name = "TheWorldDio"
	local rig = { Joints = {} }

	local torso = newPart(model, "Body", Vector3.new(2.3, 1.9, 1.12) * s, GOLD)
	torso.Reflectance = 0.12
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.56 * s
	-- Chest plates with green trim lines, a heart in the middle.
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Pec", Vector3.new(0.95, 0.6, 0.12) * s, GOLD_LIGHT, CFrame.new(side * 0.5 * s, 0.42 * s, front - 0.03 * s))
		box(model, torso, "Trim", Vector3.new(0.06, 1.5, 0.13) * s, GREEN, CFrame.new(side * 0.98 * s, -0.05 * s, front - 0.04 * s) * CFrame.Angles(0, 0, side * 0.12))
		box(model, torso, "TrimV", Vector3.new(0.06, 0.9, 0.13) * s, GREEN, CFrame.new(side * 0.32 * s, -0.75 * s, front - 0.04 * s) * CFrame.Angles(0, 0, side * -0.35))
	end
	heart(model, torso, CFrame.new(0, 0.1 * s, front - 0.08 * s), 0.5, s)
	box(model, torso, "Waist", Vector3.new(1.6, 0.85, 0.92) * s, GOLD_SHADE, CFrame.new(0, -1.3 * s, 0))
	for k = 0, 2 do
		for _, side in ipairs({ -1, 1 }) do
			box(model, torso, "Ab", Vector3.new(0.36, 0.22, 0.06) * s, GOLD_LIGHT, CFrame.new(side * 0.21 * s, (-0.38 - k * 0.28) * s, front - 0.02 * s))
		end
	end
	box(model, torso, "Belt", Vector3.new(1.72, 0.28, 1.0) * s, GOLD_SHADE, CFrame.new(0, -1.68 * s, 0))
	box(model, torso, "Buckle", Vector3.new(0.42, 0.3, 0.08) * s, GREEN, CFrame.new(0, -1.68 * s, -0.52 * s))
	box(model, torso, "Hips", Vector3.new(1.7, 0.5, 0.95) * s, GOLD, CFrame.new(0, -2.0 * s, 0))
	box(model, torso, "Neck", Vector3.new(0.55, 0.45, 0.55) * s, GOLD_SHADE, CFrame.new(0, 1.12 * s, 0))

	-- Head: crest sweeping back, faceplate over the mouth, narrow eyes.
	local headBase = CFrame.new(0, 1.3 * s, 0)
	local headOffset = CFrame.new(0, 0.52 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.78, 0.95, 0.82) * s, GOLD, headBase * headOffset)
	head.Reflectance = 0.1
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.41 * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.22, 0.07, 0.05) * s, EYE, CFrame.new(side * 0.17 * s, 0.1 * s, hf - 0.02 * s) * CFrame.Angles(0, 0, side * -0.2), Enum.Material.Neon)
		box(model, head, "Brow", Vector3.new(0.28, 0.07, 0.07) * s, LINE, CFrame.new(side * 0.17 * s, 0.17 * s, hf - 0.03 * s) * CFrame.Angles(0, 0, side * -0.2))
		box(model, head, "Fin", Vector3.new(0.08, 0.45, 0.4) * s, GOLD_LIGHT, CFrame.new(side * 0.43 * s, 0.05 * s, 0.05 * s) * CFrame.Angles(0, 0, side * -0.3))
	end
	-- The faceplate: a mask over the lower face with green seams.
	box(model, head, "Faceplate", Vector3.new(0.7, 0.38, 0.1) * s, GOLD_LIGHT, CFrame.new(0, -0.24 * s, hf - 0.04 * s))
	for _, x in ipairs({ -0.18, 0, 0.18 }) do
		box(model, head, "Seam", Vector3.new(0.03, 0.34, 0.11) * s, GREEN_DARK, CFrame.new(x * s, -0.24 * s, hf - 0.045 * s))
	end
	box(model, head, "Nose", Vector3.new(0.1, 0.18, 0.08) * s, GOLD_SHADE, CFrame.new(0, 0.0, hf - 0.04 * s))
	-- Helmet cap and the crest sweeping back to a point.
	box(model, head, "Helmet", Vector3.new(0.86, 0.28, 0.9) * s, GOLD_SHADE, CFrame.new(0, 0.42 * s, 0.02 * s))
	box(model, head, "HelmetRim", Vector3.new(0.88, 0.07, 0.92) * s, GREEN, CFrame.new(0, 0.29 * s, 0.02 * s))
	for k = 0, 3 do
		local f = k / 3
		box(model, head, "Crest", Vector3.new((0.5 - f * 0.3) * s, (0.22 - f * 0.08) * s, (0.5 + f * 0.1) * s), k % 2 == 0 and GOLD_LIGHT or GOLD, CFrame.new(0, (0.58 + f * 0.25) * s, (0.05 + f * 0.45) * s) * CFrame.Angles(math.rad(-25 - f * 15), 0, 0))
	end
	box(model, head, "CrestTip", Vector3.new(0.12, 0.12, 0.4) * s, GREEN, CFrame.new(0, 0.86 * s, 0.75 * s) * CFrame.Angles(math.rad(-40), 0, 0))
	-- Two hoses from the back of the head down into its back.
	for _, side in ipairs({ -1, 1 }) do
		local a = Vector3.new(side * 0.22, 1.8, 0.42) * s
		local m = Vector3.new(side * 0.32, 1.4, 0.85) * s
		local b = Vector3.new(side * 0.45, 0.7, 0.6) * s
		rod(model, torso, "Hose", a, m, 0.14 * s, HOSE)
		rod(model, torso, "Hose", m, b, 0.14 * s, HOSE)
		ball(model, torso, "HoseBend", 0.14 * s, HOSE, CFrame.new(m))
		ball(model, torso, "HosePlug", 0.22 * s, GREEN_DARK, CFrame.new(b))
	end

	-- Arms: rounded shoulder guards rimmed in green, green wrist bands.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		box(model, torso, "ShoulderGuard", Vector3.new(0.95, 0.55, 1.0) * s, GOLD_LIGHT, CFrame.new(side * 1.45 * s, 0.78 * s, 0) * CFrame.Angles(0, 0, side * -0.25))
		box(model, torso, "ShoulderRim", Vector3.new(0.98, 0.08, 1.03) * s, GREEN, CFrame.new(side * 1.47 * s, 0.55 * s, 0) * CFrame.Angles(0, 0, side * -0.25))
		local base = CFrame.new(side * 1.5 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.68, 2.2, 0.68) * s, GOLD, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Bicep", Vector3.new(0.76, 0.7, 0.76) * s, GOLD_LIGHT, CFrame.new(0, 0.5 * s, -0.02 * s))
		box(model, arm, "ArmLine", Vector3.new(0.05, 1.6, 0.05) * s, GREEN, CFrame.new(side * 0.36 * s, 0.1 * s, 0))
		box(model, arm, "Forearm", Vector3.new(0.76, 0.75, 0.76) * s, GOLD_SHADE, CFrame.new(0, -0.5 * s, 0))
		box(model, arm, "WristBand", Vector3.new(0.82, 0.18, 0.82) * s, GREEN, CFrame.new(0, -0.88 * s, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.62, 0.56, 0.58) * s, GOLD, CFrame.new(0, -1.3 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.12, 0.36, 0.12) * s, GOLD_SHADE, CFrame.new(f * 0.14 * s, -0.38 * s, -0.06 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: heart-shaped knee guards, green ankle bands.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.48 * s, -2.15 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.72, 2.4, 0.72) * s, GOLD, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Thigh", Vector3.new(0.82, 0.9, 0.82) * s, GOLD_LIGHT, CFrame.new(0, 0.68 * s, 0))
		heart(model, leg, CFrame.new(0, 0.0, -0.42 * s), 0.6, s)
		box(model, leg, "Shin", Vector3.new(0.7, 0.75, 0.74) * s, GOLD_SHADE, CFrame.new(0, -0.6 * s, 0))
		box(model, leg, "AnkleBand", Vector3.new(0.78, 0.16, 0.78) * s, GREEN, CFrame.new(0, -1.05 * s, 0))
		box(model, leg, "Foot", Vector3.new(0.66, 0.3, 1.0) * s, GOLD_SHADE, CFrame.new(0, -1.3 * s, -0.17 * s))
	end
	return model, rig
end

return TheWorldDioStand
```
