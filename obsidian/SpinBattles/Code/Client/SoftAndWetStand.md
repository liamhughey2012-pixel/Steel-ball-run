---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# SoftAndWetStand

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `SoftAndWetStand` (capitals matter) |

**What it does:** SOFT & WET (Josuke Higashikata, JoJolion), blocky, matched to the art: glossy icy white-teal all over, slim and jointed like a doll a tall capsule head with a narrow chin, a striped purple line down the middle, two round eyes with a slit in each, and a horn sticking out of each side (a little yellow star on one tip) a big HEART-shaped chest; the line runs down the neck to a ring, then into the anchor / trident: a stem with two arms curving up to arrowheads dark purple ball joints, green coiled springs at elbows, wrists and knees, pointed fins on the shoulders and hips a maroon waist with a blue band, blue shoes with lime soles soap bubbles with stars in them floating round it Registered with TuskStandModels by JosukeVFX, so TuskStand floats it behind Josuke (players and NPCs) with a soft blue aura.

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **SoftAndWetStand**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.SoftAndWetStand  (StarterPlayerScripts.SpinClient.TuskActVFX.SoftAndWetStand)

	SOFT & WET (Josuke Higashikata, JoJolion), blocky, matched to the art:
	  * glossy icy white-teal all over, slim and jointed like a doll
	  * a tall capsule head with a narrow chin, a striped purple line
	    down the middle, two round eyes with a slit in each, and a horn
	    sticking out of each side (a little yellow star on one tip)
	  * a big HEART-shaped chest; the line runs down the neck to a ring,
	    then into the anchor / trident: a stem with two arms curving up
	    to arrowheads
	  * dark purple ball joints, green coiled springs at elbows, wrists
	    and knees, pointed fins on the shoulders and hips
	  * a maroon waist with a blue band, blue shoes with lime soles
	  * soap bubbles with stars in them floating round it
	Registered with TuskStandModels by JosukeVFX, so TuskStand floats it
	behind Josuke (players and NPCs) with a soft blue aura.
]]

local SoftAndWetStand = {}

local BODY = Color3.fromRGB(228, 248, 246)
local SHADE = Color3.fromRGB(168, 222, 220)
local LINE = Color3.fromRGB(96, 84, 176)
local HATCH = Color3.fromRGB(170, 160, 230)
local JOINT = Color3.fromRGB(92, 52, 120)
local SPRING = Color3.fromRGB(150, 196, 70)
local WAIST = Color3.fromRGB(140, 40, 78)
local BAND = Color3.fromRGB(70, 120, 205)
local SOLE = Color3.fromRGB(196, 232, 60)
local STAR = Color3.fromRGB(255, 220, 60)
local BUBBLE = Color3.fromRGB(215, 240, 255)
local BUBBLE_STAR = Color3.fromRGB(90, 190, 200)
local EYE_DARK = Color3.fromRGB(40, 60, 70)

SoftAndWetStand.Aura = Color3.fromRGB(150, 220, 255)
SoftAndWetStand.AuraLight = Color3.fromRGB(230, 250, 255)
SoftAndWetStand.Offset = CFrame.new(2.2, 1.6, 2.8)

local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0) -- turns a cylinder's axis (X) to face forward
local ALONG_Y = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder's axis upright

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
	p.Reflectance = 0.12
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

-- A cylinder: `length` along its axis, `d` across. cf sets where its axis points.
local function cyl(model, parent, name, length, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(length, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A flat strip from a to b (2D points in the XY plane) at depth z.
local function strip(model, parent, name, a, b, width, z, color)
	local dx, dy = b.X - a.X, b.Y - a.Y
	local len = math.sqrt(dx * dx + dy * dy)
	local mid = (a + b) / 2
	return box(model, parent, name, Vector3.new(len + width * 0.6, width, 0.05), color, CFrame.new(mid.X, mid.Y, z) * CFrame.Angles(0, 0, math.atan(dy, dx)))
end

-- A little star (two crossed squares), facing -Z of cf.
local function star(model, parent, cf, size, color)
	box(model, parent, "Star", Vector3.new(size, size, 0.05), color, cf * CFrame.Angles(0, 0, math.pi / 4))
	box(model, parent, "Star", Vector3.new(size * 0.7, size * 0.7, 0.06), color, cf)
end

-- A green coiled spring round a limb (two thin rings).
local function spring(model, parent, y, d, s)
	for k = 0, 1 do
		cyl(model, parent, "Spring", 0.07 * s, d, SPRING, CFrame.new(0, y + k * 0.12 * s, 0) * ALONG_Y)
	end
end

-- A pointed fin: a flat diamond sticking out.
local function fin(model, parent, cf, length, s)
	local p = box(model, parent, "Fin", Vector3.new(length, 0.42 * s, 0.14 * s), BODY, cf)
	box(model, p, "FinTip", Vector3.new(0.42 * s, 0.42 * s, 0.13 * s), SHADE, CFrame.new(length / 2, 0, 0) * CFrame.Angles(0, 0, math.pi / 4))
	return p
end

function SoftAndWetStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "SoftAndWet"
	local rig = { Joints = {} }

	-- Core (the rig's body): everything else hangs off it.
	local torso = newPart(model, "Body", Vector3.new(1.4, 1.6, 0.9) * s, BODY)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso

	-- HEART chest: two round lobes on top, tapering to a point at the waist.
	for _, side in ipairs({ -1, 1 }) do
		cyl(model, torso, "HeartLobe", 1.0 * s, 1.55 * s, BODY, CFrame.new(side * 0.68 * s, 0.5 * s, 0) * ALONG_Z)
	end
	box(model, torso, "Heart1", Vector3.new(2.7, 0.8, 1.0) * s, BODY, CFrame.new(0, 0.25 * s, 0))
	box(model, torso, "Heart2", Vector3.new(2.15, 0.5, 0.98) * s, BODY, CFrame.new(0, -0.38 * s, 0))
	box(model, torso, "Heart3", Vector3.new(1.55, 0.45, 0.95) * s, BODY, CFrame.new(0, -0.82 * s, 0))
	box(model, torso, "Heart4", Vector3.new(0.9, 0.4, 0.9) * s, SHADE, CFrame.new(0, -1.22 * s, 0))
	-- The emblem: ring, stem and two arms curving up to arrowheads.
	local z = -0.53 * s
	local P = function(x, y)
		return Vector3.new(x * s, y * s, 0)
	end
	cyl(model, torso, "EmblemRing", 0.05 * s, 0.46 * s, LINE, CFrame.new(0, 0.62 * s, z) * ALONG_Z)
	cyl(model, torso, "EmblemHole", 0.06 * s, 0.24 * s, BODY, CFrame.new(0, 0.62 * s, z - 0.01 * s) * ALONG_Z)
	strip(model, torso, "Stem", P(0, 0.4), P(0, -1.0), 0.12 * s, z, LINE)
	strip(model, torso, "Crossbar", P(-0.22, 0.2), P(0.22, 0.2), 0.08 * s, z, LINE)
	for _, side in ipairs({ -1, 1 }) do
		strip(model, torso, "Arm", P(0, -0.98), P(side * 0.45, -0.75), 0.11 * s, z, LINE)
		strip(model, torso, "Arm", P(side * 0.45, -0.75), P(side * 0.72, -0.25), 0.11 * s, z, LINE)
		strip(model, torso, "Arm", P(side * 0.72, -0.25), P(side * 0.8, 0.12), 0.11 * s, z, LINE)
		box(model, torso, "Arrowhead", Vector3.new(0.3, 0.3, 0.05) * s, LINE, CFrame.new(side * 0.8 * s, 0.2 * s, z) * CFrame.Angles(0, 0, math.pi / 4))
	end
	-- Hatching across the stripes, like the ink in the art.
	for k = 0, 6 do
		box(model, torso, "Hatch", Vector3.new(0.13, 0.035, 0.055) * s, HATCH, CFrame.new(0, (0.3 - k * 0.18) * s, z - 0.005 * s))
	end

	-- Neck: thin, with a ring at its base where the line starts.
	cyl(model, torso, "Neck", 0.7 * s, 0.36 * s, SHADE, CFrame.new(0, 1.25 * s, 0) * ALONG_Y)
	cyl(model, torso, "NeckRing", 0.08 * s, 0.34 * s, LINE, CFrame.new(0, 1.0 * s, -0.42 * s) * ALONG_Z)
	cyl(model, torso, "NeckRingHole", 0.09 * s, 0.16 * s, BODY, CFrame.new(0, 1.0 * s, -0.44 * s) * ALONG_Z)
	strip(model, torso, "NeckLine", P(0, 1.55), P(0, 1.1), 0.1 * s, -0.2 * s, LINE)

	-- Head: a tall capsule with a narrow chin.
	local headBase = CFrame.new(0, 1.55 * s, 0)
	local headOffset = CFrame.new(0, 0.75 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.9, 1.1, 0.85) * s, BODY, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	ball(model, head, "Dome", 0.9 * s, BODY, CFrame.new(0, 0.55 * s, 0))
	box(model, head, "Chin", Vector3.new(0.62, 0.45, 0.72) * s, BODY, CFrame.new(0, -0.75 * s, 0.02 * s))
	box(model, head, "Mouth", Vector3.new(0.4, 0.1, 0.05) * s, SHADE, CFrame.new(0, -0.58 * s, -0.36 * s))
	local hz = -0.44 * s
	-- The striped line down the middle of the face, over the dome.
	box(model, head, "Line", Vector3.new(0.13, 1.6, 0.04) * s, LINE, CFrame.new(0, -0.15 * s, hz))
	box(model, head, "LineTop", Vector3.new(0.13, 0.5, 0.04) * s, LINE, CFrame.new(0, 0.78 * s, -0.33 * s) * CFrame.Angles(-0.75, 0, 0))
	for k = 0, 6 do
		box(model, head, "Hatch", Vector3.new(0.14, 0.03, 0.045) * s, HATCH, CFrame.new(0, (0.5 - k * 0.2) * s, hz - 0.005 * s))
	end
	-- Round eyes with a slit.
	for _, side in ipairs({ -1, 1 }) do
		cyl(model, head, "EyeRim", 0.04 * s, 0.34 * s, EYE_DARK, CFrame.new(side * 0.25 * s, 0.12 * s, hz) * ALONG_Z)
		cyl(model, head, "Eye", 0.05 * s, 0.28 * s, BODY, CFrame.new(side * 0.25 * s, 0.12 * s, hz - 0.01 * s) * ALONG_Z)
		box(model, head, "Slit", Vector3.new(0.045, 0.24, 0.06) * s, EYE_DARK, CFrame.new(side * 0.25 * s, 0.12 * s, hz - 0.02 * s))
		-- A horn out of each side, tapering to a point.
		cyl(model, head, "Horn", 0.55 * s, 0.3 * s, BODY, CFrame.new(side * 0.68 * s, 0.32 * s, 0))
		cyl(model, head, "Horn", 0.5 * s, 0.18 * s, SHADE, CFrame.new(side * 1.18 * s, 0.32 * s, 0))
		ball(model, head, "HornTip", 0.13 * s, SHADE, CFrame.new(side * 1.45 * s, 0.32 * s, 0))
	end
	star(model, head, CFrame.new(1.55 * s, 0.4 * s, -0.08 * s), 0.18 * s, STAR)

	-- Shoulders: purple ball joints and pointed fins.
	for _, side in ipairs({ -1, 1 }) do
		ball(model, torso, "ShoulderJoint", 0.55 * s, JOINT, CFrame.new(side * 1.38 * s, 0.35 * s, 0))
		local f = fin(model, torso, CFrame.new(side * 1.55 * s, 0.85 * s, 0.1 * s) * CFrame.Angles(0, 0, side > 0 and 0.35 or math.pi - 0.35), 1.2 * s, s)
		box(model, f, "FinPatch", Vector3.new(0.35, 0.2, 0.16) * s, SPRING, CFrame.new(0.2 * s, 0, 0))
	end

	-- Arms: thin, jointed, springs at the elbow and wrist.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.42 * s, 0.3 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.36, 2.2, 0.36) * s, BODY, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		ball(model, arm, "Elbow", 0.44 * s, JOINT, CFrame.new(0, 0.05 * s, 0))
		spring(model, arm, -0.15 * s, 0.5 * s, s)
		box(model, arm, "Forearm", Vector3.new(0.46, 0.85, 0.46) * s, BODY, CFrame.new(0, -0.6 * s, 0))
		ball(model, arm, "Wrist", 0.34 * s, JOINT, CFrame.new(0, -1.08 * s, 0))
		spring(model, arm, -1.0 * s, 0.42 * s, s)
		local hand = box(model, arm, "Hand", Vector3.new(0.5, 0.45, 0.42) * s, BODY, CFrame.new(0, -1.35 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.09, 0.36, 0.1) * s, SHADE, CFrame.new(f * 0.11 * s, -0.36 * s, -0.04 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Waist: thin and maroon, a blue band, then the hips with fins.
	box(model, torso, "Waist", Vector3.new(0.7, 0.55, 0.6) * s, WAIST, CFrame.new(0, -1.55 * s, 0))
	box(model, torso, "Band", Vector3.new(1.35, 0.24, 0.85) * s, BAND, CFrame.new(0, -1.86 * s, 0))
	box(model, torso, "Hips", Vector3.new(1.25, 0.45, 0.8) * s, BODY, CFrame.new(0, -2.15 * s, 0))
	box(model, torso, "Crotch", Vector3.new(0.5, 0.3, 0.7) * s, WAIST, CFrame.new(0, -2.45 * s, 0))
	for _, side in ipairs({ -1, 1 }) do
		fin(model, torso, CFrame.new(side * 0.85 * s, -2.25 * s, 0.1 * s) * CFrame.Angles(0, 0, side > 0 and -1.1 or math.pi + 1.1), 0.9 * s, s)
		ball(model, torso, "HipJoint", 0.46 * s, JOINT, CFrame.new(side * 0.45 * s, -2.4 * s, 0))
	end

	-- Legs: thin, a purple knee with a spring, blue shoes with lime soles.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.45 * s, -2.4 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.42, 2.4, 0.42) * s, BODY, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		ball(model, leg, "Knee", 0.48 * s, JOINT, CFrame.new(0, 0.05 * s, -0.06 * s))
		spring(model, leg, -0.18 * s, 0.56 * s, s)
		box(model, leg, "Shin", Vector3.new(0.5, 0.9, 0.5) * s, BODY, CFrame.new(0, -0.6 * s, 0))
		local shoe = box(model, leg, "Shoe", Vector3.new(0.58, 0.36, 1.05) * s, BAND, CFrame.new(0, -1.25 * s, -0.2 * s))
		box(model, shoe, "Sole", Vector3.new(0.6, 0.12, 1.1) * s, SOLE, CFrame.new(0, -0.2 * s, -0.01 * s))
		box(model, shoe, "Toe", Vector3.new(0.4, 0.14, 0.3) * s, SOLE, CFrame.new(0, 0.05 * s, -0.42 * s))
	end

	-- Soap bubbles with stars in them, floating round it.
	for _, b in ipairs({ { -1.9, 1.7, -0.3, 0.7 }, { -2.0, 0.6, -0.5, 0.55 }, { -1.5, 2.7, 0.1, 0.48 }, { 1.95, 2.3, -0.2, 0.6 }, { 2.1, 1.3, -0.5, 0.42 } }) do
		local cf = CFrame.new(b[1] * s, b[2] * s, b[3] * s)
		local bub = ball(model, torso, "Bubble", b[4] * s, BUBBLE, cf, Enum.Material.Glass)
		bub.Transparency = 0.55
		bub.Reflectance = 0.3
		star(model, torso, cf * CFrame.new(0, 0, -0.05 * s), b[4] * 0.45 * s, BUBBLE_STAR)
	end
	return model, rig
end

return SoftAndWetStand
```
