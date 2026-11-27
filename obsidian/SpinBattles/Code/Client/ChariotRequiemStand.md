---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# ChariotRequiemStand

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `ChariotRequiemStand` (capitals matter) |

**What it does:** SILVER CHARIOT REQUIEM, blocky, matched to the anime / manga art: a tall, slim figure, glossy near-black with a navy tint, picked out with thin pale lavender SHEEN lines (collar, chest, ribs, pants) a faceless dark head under a wide, tilted brimmed HAT: a round brim with a pale edge, a pointed front, a tall crown with a band two big round DISC shoulder pads, each with concentric rings and a hollow centre a belt with a row of white FANGS hanging from it baggy pants puffed out to below the knee, tapering into boots long arms with open clawed gloves; the REQUIEM ARROW (gold, with its scarab) held low in its right hand Registered with TuskStandModels by ChariotRequiemVFX; TuskStand floats it behind Polnareff with a dark violet aura.

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **ChariotRequiemStand**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.ChariotRequiemStand  (StarterPlayerScripts.SpinClient.TuskActVFX.ChariotRequiemStand)

	SILVER CHARIOT REQUIEM, blocky, matched to the anime / manga art:
	  * a tall, slim figure, glossy near-black with a navy tint, picked out
	    with thin pale lavender SHEEN lines (collar, chest, ribs, pants)
	  * a faceless dark head under a wide, tilted brimmed HAT: a round brim
	    with a pale edge, a pointed front, a tall crown with a band
	  * two big round DISC shoulder pads, each with concentric rings and a
	    hollow centre
	  * a belt with a row of white FANGS hanging from it
	  * baggy pants puffed out to below the knee, tapering into boots
	  * long arms with open clawed gloves; the REQUIEM ARROW (gold, with its
	    scarab) held low in its right hand
	Registered with TuskStandModels by ChariotRequiemVFX; TuskStand floats
	it behind Polnareff with a dark violet aura.
]]

local ChariotRequiemStand = {}

local DARK = Color3.fromRGB(22, 20, 36)
local MID = Color3.fromRGB(44, 42, 70)
local SHEEN = Color3.fromRGB(176, 176, 218)
local FANG = Color3.fromRGB(226, 224, 238)
local GOLD = Color3.fromRGB(222, 182, 72)
local SHAFT = Color3.fromRGB(150, 112, 50)

ChariotRequiemStand.Aura = Color3.fromRGB(120, 80, 190)
ChariotRequiemStand.AuraLight = Color3.fromRGB(214, 200, 255)
ChariotRequiemStand.Offset = CFrame.new(2.6, 2.4, 3.4)

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
	local p, w = box(model, parent, name, size, color, cf, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p, w
end

-- A cylinder whose round faces point along the local X axis of cf.
local function disc(model, parent, name, length, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(length, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A thin pale sheen line from a to b (in parent space), sat on the surface.
local function line(model, parent, a, b, w)
	local len = (b - a).Magnitude
	return box(model, parent, "Sheen", Vector3.new(w, w, len + w), SHEEN, CFrame.lookAt((a + b) / 2, b))
end

function ChariotRequiemStand.build(scale)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "ChariotRequiem"
	local rig = { Joints = {} }
	local V = function(x, y, z)
		return Vector3.new(x, y, z) * s
	end
	local lw = 0.05 * s

	-- A slim chest tapering to a narrow waist.
	local torso = newPart(model, "Body", V(1.5, 1.3, 0.82), DARK)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	egg(model, torso, "Chest", V(1.7, 1.45, 0.98), DARK, CFrame.new(0, 0.12 * s, -0.04 * s))
	box(model, torso, "Abdomen", V(1.12, 0.95, 0.72), DARK, CFrame.new(0, -1.0 * s, 0))
	egg(model, torso, "Ribs", V(1.25, 1.0, 0.8), DARK, CFrame.new(0, -0.75 * s, -0.02 * s))
	local f = -0.5 * s
	-- Sheen lines: a collar curve, a V at the sternum, pec and rib curves.
	line(model, torso, V(-0.75, 0.62, -0.34), V(-0.32, 0.4, -0.47), lw)
	line(model, torso, V(-0.32, 0.4, -0.47), V(0.32, 0.4, -0.47), lw)
	line(model, torso, V(0.32, 0.4, -0.47), V(0.75, 0.62, -0.34), lw)
	line(model, torso, V(-0.2, 0.22, -0.5), V(0, 0.08, -0.51), lw)
	line(model, torso, V(0, 0.08, -0.51), V(0.2, 0.22, -0.5), lw)
	for _, side in ipairs({ -1, 1 }) do
		line(model, torso, V(side * 0.1, -0.22, -0.5), V(side * 0.45, -0.12, -0.46), lw)
		line(model, torso, V(side * 0.45, -0.12, -0.46), V(side * 0.7, 0.08, -0.36), lw)
		line(model, torso, V(side * 0.22, -0.62, -0.42), V(side * 0.5, -0.5, -0.36), lw)
	end
	line(model, torso, V(0, -0.45, -0.43), V(0, -1.2, -0.38), lw)
	box(model, torso, "Neck", V(0.42, 0.4, 0.42), DARK, CFrame.new(0, 0.85 * s, 0))
	line(model, torso, V(-0.22, 0.75, -0.2), V(0.22, 0.75, -0.2), lw)

	-- A faceless dark head under a wide, tilted brimmed hat.
	local headBase = CFrame.new(0, 1.0 * s, 0)
	local headOffset = CFrame.new(0, 0.42 * s, 0)
	local head, headWeld = egg(model, torso, "Head", V(0.66, 0.88, 0.72), DARK, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	line(model, head, V(-0.14, -0.28, -0.33), V(0.14, -0.28, -0.33), lw * 0.8)
	local hat = CFrame.new(0, 0.32 * s, 0) * CFrame.Angles(math.rad(-12), 0, math.rad(9))
	disc(model, head, "Brim", 0.08 * s, 2.3 * s, DARK, hat * CFrame.Angles(0, 0, math.pi / 2))
	-- The brim's pale edge.
	local n = 22
	for k = 0, n - 1 do
		local a0, a1 = k / n * math.pi * 2, (k + 1) / n * math.pi * 2
		local r = 1.13 * s
		local pa = (hat * CFrame.new(math.cos(a0) * r, 0.05 * s, math.sin(a0) * r)).Position
		local pb = (hat * CFrame.new(math.cos(a1) * r, 0.05 * s, math.sin(a1) * r)).Position
		line(model, head, pa, pb, lw * 1.2)
	end
	-- A pointed front to the brim, dipping down.
	local tip = hat * CFrame.new(0, -0.02 * s, -0.95 * s) * CFrame.Angles(math.rad(-10), math.pi / 4, 0)
	box(model, head, "BrimPoint", V(0.7, 0.07, 0.7), DARK, tip)
	line(model, head, (hat * CFrame.new(-0.42 * s, 0.03 * s, -0.95 * s)).Position, (hat * CFrame.new(0, -0.06 * s, -1.42 * s)).Position, lw * 1.2)
	line(model, head, (hat * CFrame.new(0, -0.06 * s, -1.42 * s)).Position, (hat * CFrame.new(0.42 * s, 0.03 * s, -0.95 * s)).Position, lw * 1.2)
	-- A tall crown with a band and a pinched front.
	disc(model, head, "Crown", 0.65 * s, 0.98 * s, DARK, hat * CFrame.new(0, 0.35 * s, 0.05 * s) * CFrame.Angles(0, 0, math.pi / 2))
	egg(model, head, "CrownTop", V(0.98, 0.4, 0.98), DARK, hat * CFrame.new(0, 0.68 * s, 0.05 * s))
	disc(model, head, "HatBand", 0.12 * s, 1.03 * s, MID, hat * CFrame.new(0, 0.1 * s, 0.05 * s) * CFrame.Angles(0, 0, math.pi / 2))
	line(model, head, (hat * CFrame.new(-0.52 * s, 0.17 * s, 0.05 * s)).Position, (hat * CFrame.new(-0.3 * s, 0.17 * s, -0.38 * s)).Position, lw)
	line(model, head, (hat * CFrame.new(-0.3 * s, 0.17 * s, -0.38 * s)).Position, (hat * CFrame.new(0.3 * s, 0.17 * s, -0.38 * s)).Position, lw)
	line(model, head, (hat * CFrame.new(-0.16 * s, 0.78 * s, -0.42 * s)).Position, (hat * CFrame.new(0, 0.42 * s, -0.48 * s)).Position, lw)
	line(model, head, (hat * CFrame.new(0, 0.42 * s, -0.48 * s)).Position, (hat * CFrame.new(0.16 * s, 0.78 * s, -0.42 * s)).Position, lw)
	line(model, head, (hat * CFrame.new(0, 0.42 * s, -0.48 * s)).Position, (hat * CFrame.new(0, 0.22 * s, -0.48 * s)).Position, lw)

	-- Big round disc shoulder pads with ringed faces and a hollow centre.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local padCF = CFrame.new(side * 1.05 * s, 0.62 * s, 0) * CFrame.Angles(0, side * math.rad(-15), side * math.rad(-28))
		local pad = disc(model, torso, "ShoulderDisc", 0.6 * s, 1.32 * s, DARK, padCF)
		local out = side
		disc(model, pad, "DiscRim", 0.05 * s, 1.3 * s, SHEEN, CFrame.new(out * 0.3 * s, 0, 0))
		disc(model, pad, "DiscFace", 0.06 * s, 1.1 * s, DARK, CFrame.new(out * 0.32 * s, 0, 0))
		disc(model, pad, "DiscRing", 0.05 * s, 0.88 * s, MID, CFrame.new(out * 0.35 * s, 0, 0))
		disc(model, pad, "DiscInner", 0.06 * s, 0.8 * s, DARK, CFrame.new(out * 0.37 * s, 0, 0))
		disc(model, pad, "Boss", 0.18 * s, 0.6 * s, DARK, CFrame.new(out * 0.44 * s, 0, 0))
		disc(model, pad, "BossRim", 0.19 * s, 0.6 * s * 1.02, SHEEN, CFrame.new(out * 0.44 * s, 0, 0))
		disc(model, pad, "BossFace", 0.2 * s, 0.5 * s, DARK, CFrame.new(out * 0.45 * s, 0, 0))
		disc(model, pad, "Hollow", 0.21 * s, 0.24 * s, MID, CFrame.new(out * 0.46 * s, 0, 0))
		disc(model, pad, "HollowRim", 0.22 * s, 0.14 * s, DARK, CFrame.new(out * 0.46 * s, 0, 0))
		-- A pale edge round the back of the disc too.
		disc(model, pad, "BackRim", 0.04 * s, 1.34 * s, SHEEN, CFrame.new(-out * 0.27 * s, 0, 0))

		-- A long thin arm with an open clawed glove.
		local base = CFrame.new(side * 1.0 * s, 0.32 * s, 0)
		local offset = CFrame.new(0, -1.4 * s, 0)
		local arm, weld = box(model, torso, a[1], V(0.36, 2.8, 0.36), DARK, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		egg(model, arm, "Bicep", V(0.5, 1.25, 0.5), DARK, CFrame.new(0, 0.62 * s, 0))
		egg(model, arm, "Forearm", V(0.48, 1.25, 0.48), DARK, CFrame.new(0, -0.6 * s, 0))
		line(model, arm, V(side * 0.18, 1.0, -0.12), V(side * 0.22, 0.2, -0.16), lw)
		line(model, arm, V(-0.2, -0.05, -0.18), V(0.2, -0.05, -0.18), lw)
		line(model, arm, V(side * 0.2, -0.25, -0.15), V(side * 0.16, -1.05, -0.12), lw)
		line(model, arm, V(-0.2, -1.12, -0.2), V(0.2, -1.12, -0.2), lw)
		local hand = box(model, arm, "Hand", V(0.36, 0.4, 0.26), DARK, CFrame.new(0, -1.48 * s, 0))
		for k = -1.5, 1.5 do
			local fx = k * 0.085 * s
			local finger = box(model, hand, "Finger", V(0.07, 0.34, 0.07), DARK, CFrame.new(fx, -0.34 * s, -0.02 * s) * CFrame.Angles(math.rad(-22), 0, k * 0.12))
			box(model, finger, "Claw", V(0.06, 0.16, 0.06), MID, CFrame.new(0, -0.22 * s, -0.04 * s) * CFrame.Angles(math.rad(-30), 0, 0))
		end
		box(model, hand, "Thumb", V(0.08, 0.26, 0.08), DARK, CFrame.new(-side * 0.2 * s, -0.12 * s, -0.08 * s) * CFrame.Angles(math.rad(-30), 0, side * 0.5))
		line(model, hand, V(-0.19, 0.18, -0.14), V(0.19, 0.18, -0.14), lw)

		if a[1] == "ArmR" then
			-- The Requiem Arrow, held low: a gold shaft, the scarab, a broad head.
			local grip = CFrame.new(0, -0.1 * s, -0.05 * s)
			disc(model, hand, "ArrowShaft", 2.6 * s, 0.07 * s, SHAFT, grip * CFrame.new(0, 0, -0.55 * s) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Metal)
			egg(model, hand, "ArrowScarab", V(0.2, 0.14, 0.28), GOLD, grip * CFrame.new(0, 0, -1.72 * s), Enum.Material.Metal)
			box(model, hand, "ArrowHead", V(0.42, 0.05, 0.42), GOLD, grip * CFrame.new(0, 0, -2.0 * s) * CFrame.Angles(0, math.pi / 4, 0), Enum.Material.Metal)
			box(model, hand, "ArrowBarb", V(0.5, 0.06, 0.08), GOLD, grip * CFrame.new(0, 0, -1.86 * s), Enum.Material.Metal)
			box(model, hand, "ArrowNock", V(0.16, 0.05, 0.16), GOLD, grip * CFrame.new(0, 0, 0.72 * s) * CFrame.Angles(0, math.pi / 4, 0), Enum.Material.Metal)
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.1 * s, -2.35 * s)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- The belt with a row of white fangs hanging from it.
	local beltY = -1.55 * s
	box(model, torso, "Belt", V(1.32, 0.26, 0.86), MID, CFrame.new(0, beltY, 0))
	line(model, torso, V(-0.66, -1.42, -0.44), V(0.66, -1.42, -0.44), lw)
	line(model, torso, V(-0.66, -1.68, -0.44), V(0.66, -1.68, -0.44), lw)
	for k = -2, 2 do
		box(model, torso, "BeltLoop", V(0.1, 0.32, 0.06), DARK, CFrame.new(k * 0.28 * s, beltY, -0.45 * s))
	end
	for k = -4, 4 do
		local ang = k / 4 * math.rad(95)
		local pos = CFrame.new(math.sin(ang) * 0.7 * s, beltY - 0.2 * s, -math.cos(ang) * 0.47 * s)
		local fang = egg(model, torso, "Fang", V(0.1, 0.34, 0.1), FANG, pos * CFrame.Angles(0, -ang, 0) * CFrame.Angles(math.rad(14), 0, 0))
		egg(model, fang, "FangTip", V(0.06, 0.18, 0.06), FANG, CFrame.new(0, -0.18 * s, 0.03 * s) * CFrame.Angles(math.rad(25), 0, 0))
	end
	egg(model, torso, "Hips", V(1.45, 0.7, 0.95), DARK, CFrame.new(0, -1.9 * s, 0))

	-- Baggy pants puffed out to below the knee, tapering into boots.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.4 * s, -2.0 * s, 0)
		local offset = CFrame.new(0, -1.3 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, V(0.45, 2.6, 0.45), DARK, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		egg(model, leg, "Pants", V(0.92, 2.15, 0.94), DARK, CFrame.new(side * 0.05 * s, 0.25 * s, 0))
		egg(model, leg, "Knee", V(0.84, 0.9, 0.9), DARK, CFrame.new(side * 0.04 * s, -0.3 * s, -0.04 * s))
		box(model, leg, "Cuff", V(0.5, 0.14, 0.5), MID, CFrame.new(0, -0.75 * s, 0))
		line(model, leg, V(side * 0.25, 1.05, -0.36), V(side * 0.1, 0.25, -0.43), lw)
		line(model, leg, V(-side * 0.18, 0.2, -0.4), V(-side * 0.05, -0.55, -0.4), lw)
		line(model, leg, V(side * 0.32, -0.1, -0.2), V(side * 0.22, -0.65, -0.3), lw)
		box(model, leg, "Shin", V(0.42, 0.6, 0.42), DARK, CFrame.new(0, -0.95 * s, 0))
		box(model, leg, "Boot", V(0.48, 0.42, 0.78), DARK, CFrame.new(0, -1.22 * s, -0.13 * s))
		egg(model, leg, "Toe", V(0.46, 0.34, 0.4), DARK, CFrame.new(0, -1.27 * s, -0.5 * s))
		line(model, leg, V(-0.25, -0.98, -0.25), V(0.25, -0.98, -0.25), lw)
	end
	return model, rig
end

return ChariotRequiemStand
```
