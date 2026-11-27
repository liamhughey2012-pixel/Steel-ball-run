---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# TheHandStand

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `TheHandStand` (capitals matter) |

**What it does:** THE HAND (Okuyasu Nijimura, Part 4), blocky: a big, muscular NAVY-BLUE body with paler blue panels and thin gold trim lines a rounded helmet-like head with a crest down the middle, small fins at the sides and a pale mask face with narrow eyes heavy shoulders: a gold DOLLAR sign on the left, a gold YEN sign on the right an oversized RIGHT HAND with a glowing palm (the hand that erases) a belt with a gold $ buckle; armoured knees Registered with TuskStandModels by OkuyasuVFX, so TuskStand floats it behind Okuyasu with a blue aura.

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **TheHandStand**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.TheHandStand  (StarterPlayerScripts.SpinClient.TuskActVFX.TheHandStand)

	THE HAND (Okuyasu Nijimura, Part 4), blocky:
	  * a big, muscular NAVY-BLUE body with paler blue panels and thin gold
	    trim lines
	  * a rounded helmet-like head with a crest down the middle, small fins
	    at the sides and a pale mask face with narrow eyes
	  * heavy shoulders: a gold DOLLAR sign on the left, a gold YEN sign on
	    the right
	  * an oversized RIGHT HAND with a glowing palm (the hand that erases)
	  * a belt with a gold $ buckle; armoured knees
	Registered with TuskStandModels by OkuyasuVFX, so TuskStand floats it
	behind Okuyasu with a blue aura.
]]

local TheHandStand = {}

local BLUE = Color3.fromRGB(64, 92, 168)
local BLUE_DARK = Color3.fromRGB(38, 52, 106)
local BLUE_LIGHT = Color3.fromRGB(130, 164, 226)
local MASK = Color3.fromRGB(214, 226, 244)
local GOLD = Color3.fromRGB(236, 190, 70)
local EYE = Color3.fromRGB(150, 230, 255)
local PALM = Color3.fromRGB(190, 246, 255)

TheHandStand.Aura = Color3.fromRGB(110, 160, 255)
TheHandStand.AuraLight = Color3.fromRGB(210, 230, 255)
TheHandStand.Offset = CFrame.new(2.2, 1.6, 2.8)

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

-- Gold glyphs facing forward (-Z), built from bars (seen from the front,
-- +X is on the viewer's left, so the S of the $ is built mirrored).
local function bar(model, parent, cf, w, h)
	return box(model, parent, "Glyph", Vector3.new(w, h, 0.06), GOLD, cf, Enum.Material.Metal)
end

local function dollar(model, parent, cf, size)
	local t = size * 0.18
	bar(model, parent, cf * CFrame.new(0, size * 0.4, 0), size * 0.6, t)
	bar(model, parent, cf, size * 0.6, t)
	bar(model, parent, cf * CFrame.new(0, -size * 0.4, 0), size * 0.6, t)
	bar(model, parent, cf * CFrame.new(size * 0.25, size * 0.2, 0), t, size * 0.4)
	bar(model, parent, cf * CFrame.new(-size * 0.25, -size * 0.2, 0), t, size * 0.4)
	bar(model, parent, cf * CFrame.new(0, 0, -0.02), t * 0.6, size * 1.2)
end

local function yen(model, parent, cf, size)
	local t = size * 0.18
	for _, side in ipairs({ -1, 1 }) do
		bar(model, parent, cf * CFrame.new(side * size * 0.17, size * 0.28, 0) * CFrame.Angles(0, 0, side * -0.6), t, size * 0.5)
	end
	bar(model, parent, cf * CFrame.new(0, -size * 0.25, 0), t, size * 0.6)
	bar(model, parent, cf * CFrame.new(0, -size * 0.05, -0.01), size * 0.55, t * 0.8)
	bar(model, parent, cf * CFrame.new(0, -size * 0.28, -0.01), size * 0.55, t * 0.8)
end

function TheHandStand.build(scale)
	local s = (scale or 1) * 0.9
	local model = Instance.new("Model")
	model.Name = "TheHand"
	local rig = { Joints = {} }

	local torso = newPart(model, "Body", Vector3.new(2.4, 1.9, 1.15) * s, BLUE)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.58 * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Pec", Vector3.new(1.0, 0.65, 0.14) * s, BLUE_LIGHT, CFrame.new(side * 0.52 * s, 0.4 * s, front - 0.04 * s))
		box(model, torso, "PecTrim", Vector3.new(1.0, 0.05, 0.15) * s, GOLD, CFrame.new(side * 0.52 * s, 0.06 * s, front - 0.045 * s), Enum.Material.Metal)
		box(model, torso, "Lat", Vector3.new(0.2, 1.3, 0.9) * s, BLUE_DARK, CFrame.new(side * 1.2 * s, -0.1 * s, 0))
	end
	box(model, torso, "Sternum", Vector3.new(0.08, 0.65, 0.15) * s, BLUE_DARK, CFrame.new(0, 0.4 * s, front - 0.05 * s))
	box(model, torso, "Waist", Vector3.new(1.75, 0.85, 0.95) * s, BLUE, CFrame.new(0, -1.3 * s, 0))
	for k = 0, 2 do
		for _, side in ipairs({ -1, 1 }) do
			box(model, torso, "Ab", Vector3.new(0.38, 0.24, 0.08) * s, BLUE_LIGHT, CFrame.new(side * 0.22 * s, (-0.22 - k * 0.32) * s, front - 0.02 * s))
		end
	end
	box(model, torso, "Belt", Vector3.new(1.85, 0.3, 1.05) * s, BLUE_DARK, CFrame.new(0, -1.7 * s, 0))
	box(model, torso, "BeltTrim", Vector3.new(1.87, 0.05, 1.07) * s, GOLD, CFrame.new(0, -1.58 * s, 0), Enum.Material.Metal)
	box(model, torso, "Buckle", Vector3.new(0.5, 0.4, 0.06) * s, BLUE_DARK, CFrame.new(0, -1.7 * s, -0.55 * s))
	dollar(model, torso, CFrame.new(0, -1.7 * s, -0.6 * s), 0.34 * s)
	box(model, torso, "Hips", Vector3.new(1.75, 0.5, 0.95) * s, BLUE_DARK, CFrame.new(0, -2.0 * s, 0))
	box(model, torso, "Neck", Vector3.new(0.65, 0.45, 0.6) * s, BLUE_DARK, CFrame.new(0, 1.12 * s, 0))

	-- Heavy shoulders: $ on the left, yen on the right.
	for _, side in ipairs({ -1, 1 }) do
		local cf = CFrame.new(side * 1.45 * s, 0.82 * s, 0) * CFrame.Angles(0, 0, side * -0.3)
		box(model, torso, "Pauldron", Vector3.new(1.0, 0.6, 1.1) * s, BLUE_LIGHT, cf)
		box(model, torso, "PauldronTrim", Vector3.new(1.02, 0.06, 1.12) * s, GOLD, cf * CFrame.new(0, -0.3 * s, 0), Enum.Material.Metal)
		local face = cf * CFrame.new(0, 0, -0.57 * s)
		if side == -1 then
			dollar(model, torso, face, 0.42 * s)
		else
			yen(model, torso, face, 0.42 * s)
		end
	end

	-- A rounded helmet-like head: a crest, side fins, a pale mask face.
	local headBase = CFrame.new(0, 1.3 * s, 0)
	local headOffset = CFrame.new(0, 0.52 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.82, 0.98, 0.86) * s, BLUE, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.43 * s
	box(model, head, "Mask", Vector3.new(0.62, 0.6, 0.08) * s, MASK, CFrame.new(0, -0.08 * s, hf - 0.02 * s))
	box(model, head, "Crest", Vector3.new(0.12, 0.35, 0.95) * s, BLUE_DARK, CFrame.new(0, 0.55 * s, 0.02 * s))
	box(model, head, "CrestTrim", Vector3.new(0.13, 0.05, 0.96) * s, GOLD, CFrame.new(0, 0.71 * s, 0.02 * s), Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Fin", Vector3.new(0.1, 0.4, 0.4) * s, BLUE_LIGHT, CFrame.new(side * 0.46 * s, 0.1 * s, 0.05 * s) * CFrame.Angles(0, 0, side * -0.2))
		box(model, head, "Eye", Vector3.new(0.18, 0.05, 0.05) * s, EYE, CFrame.new(side * 0.15 * s, 0.05 * s, hf - 0.07 * s) * CFrame.Angles(0, 0, side * -0.15), Enum.Material.Neon)
		box(model, head, "FaceLine", Vector3.new(0.03, 0.3, 0.05) * s, BLUE_DARK, CFrame.new(side * 0.2 * s, -0.22 * s, hf - 0.065 * s))
	end
	box(model, head, "Mouth", Vector3.new(0.2, 0.04, 0.05) * s, BLUE_DARK, CFrame.new(0, -0.27 * s, hf - 0.065 * s))

	-- Arms; the RIGHT hand is oversized, its palm glowing.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.55 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.72, 2.2, 0.72) * s, BLUE, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Bicep", Vector3.new(0.84, 0.7, 0.84) * s, BLUE_LIGHT, CFrame.new(0, 0.42 * s, -0.03 * s))
		box(model, arm, "Forearm", Vector3.new(0.86, 0.8, 0.86) * s, BLUE_DARK, CFrame.new(0, -0.55 * s, 0))
		box(model, arm, "Cuff", Vector3.new(0.9, 0.08, 0.9) * s, GOLD, CFrame.new(0, -0.95 * s, 0), Enum.Material.Metal)
		if a[1] == "ArmR" then
			local hand = box(model, arm, "Hand", Vector3.new(1.0, 0.85, 0.5) * s, BLUE_LIGHT, CFrame.new(0, -1.45 * s, -0.1 * s))
			for f = -1.5, 1.5 do
				box(model, hand, "Finger", Vector3.new(0.2, 0.45, 0.22) * s, BLUE_LIGHT, CFrame.new(f * 0.24 * s, -0.58 * s, 0))
			end
			box(model, hand, "Thumb", Vector3.new(0.2, 0.4, 0.22) * s, BLUE_LIGHT, CFrame.new(-0.58 * s, -0.05 * s, -0.05 * s) * CFrame.Angles(0, 0, 0.5))
			local palm = box(model, hand, "Palm", Vector3.new(0.06, 0.6, 0.6) * s, PALM, CFrame.new(0, -0.05 * s, -0.27 * s) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Neon)
			palm.Shape = Enum.PartType.Cylinder
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.05 * s, -0.3 * s)
			point.Parent = hand
			rig.NailPoint = point
		else
			local hand = box(model, arm, "Hand", Vector3.new(0.68, 0.6, 0.62) * s, BLUE_LIGHT, CFrame.new(0, -1.3 * s, 0))
			for f = -1.5, 1.5 do
				box(model, hand, "Finger", Vector3.new(0.13, 0.36, 0.14) * s, BLUE_LIGHT, CFrame.new(f * 0.15 * s, -0.38 * s, -0.08 * s))
			end
		end
	end

	-- Legs with armoured knees.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.5 * s, -2.15 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.76, 2.4, 0.76) * s, BLUE, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Thigh", Vector3.new(0.86, 0.95, 0.86) * s, BLUE_LIGHT, CFrame.new(0, 0.65 * s, 0))
		box(model, leg, "KneePad", Vector3.new(0.6, 0.42, 0.2) * s, BLUE_DARK, CFrame.new(0, 0.02 * s, -0.42 * s))
		box(model, leg, "KneeTrim", Vector3.new(0.62, 0.05, 0.21) * s, GOLD, CFrame.new(0, 0.22 * s, -0.42 * s), Enum.Material.Metal)
		box(model, leg, "Shin", Vector3.new(0.8, 0.7, 0.82) * s, BLUE_DARK, CFrame.new(0, -0.6 * s, 0))
		box(model, leg, "Foot", Vector3.new(0.72, 0.32, 1.05) * s, BLUE_DARK, CFrame.new(0, -1.3 * s, -0.17 * s))
	end
	return model, rig
end

return TheHandStand
```
