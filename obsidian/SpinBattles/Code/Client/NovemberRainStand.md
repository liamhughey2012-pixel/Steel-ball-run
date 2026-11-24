---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# NovemberRainStand

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `NovemberRainStand` (capitals matter) |

**What it does:** NOVEMBER RAIN (Jodio Joestar, The JOJOLands), blocky, matched to the art. It hangs in the air above him like a huge insect: a tall narrow white mask, blue ribbed panels down each side, two pink eyes, a stripe down the middle, little knobs at the sides a big fan of blue feather-blades spraying up and out behind its shoulders (deep blue at the root, pale at the tips) a white body that tapers down to a nozzle point (no legs), a ring round it like a showerhead two huge white-lilac scythe blades arching up from its shoulders and sweeping down to the ground either side of him long thin dark-red hoses hanging down from under it small white arms folded in front Registered with TuskStandModels by JodioVFX, so TuskStand floats it above and behind Jodio (players and NPCs) with a pale blue aura.

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **NovemberRainStand**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.NovemberRainStand  (StarterPlayerScripts.SpinClient.TuskActVFX.NovemberRainStand)

	NOVEMBER RAIN (Jodio Joestar, The JOJOLands), blocky, matched to the
	art. It hangs in the air above him like a huge insect:
	  * a tall narrow white mask, blue ribbed panels down each side, two
	    pink eyes, a stripe down the middle, little knobs at the sides
	  * a big fan of blue feather-blades spraying up and out behind its
	    shoulders (deep blue at the root, pale at the tips)
	  * a white body that tapers down to a nozzle point (no legs), a ring
	    round it like a showerhead
	  * two huge white-lilac scythe blades arching up from its shoulders
	    and sweeping down to the ground either side of him
	  * long thin dark-red hoses hanging down from under it
	  * small white arms folded in front
	Registered with TuskStandModels by JodioVFX, so TuskStand floats it
	above and behind Jodio (players and NPCs) with a pale blue aura.
]]

local NovemberRainStand = {}

local BODY = Color3.fromRGB(236, 240, 250)
local LILAC = Color3.fromRGB(206, 200, 236)
local PANEL = Color3.fromRGB(196, 206, 228)
local BLUE = Color3.fromRGB(70, 130, 220)
local BLUE_DEEP = Color3.fromRGB(40, 70, 170)
local BLUE_PALE = Color3.fromRGB(150, 205, 250)
local RIB = Color3.fromRGB(60, 100, 200)
local EYE = Color3.fromRGB(255, 90, 150)
local HOSE = Color3.fromRGB(120, 30, 50)
local HOSE_BAND = Color3.fromRGB(70, 20, 34)

NovemberRainStand.Aura = Color3.fromRGB(150, 210, 255)
NovemberRainStand.AuraLight = Color3.fromRGB(220, 240, 255)
-- It hangs high above and behind him.
NovemberRainStand.Offset = CFrame.new(1.4, 4.6, 3.2)

local ALONG_Y = CFrame.Angles(0, 0, math.pi / 2)

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

local function cyl(model, parent, name, length, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(length, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A chain of segments along points (in the parent's space). Cylinders for
-- hoses; flat blades (width tapering from w0 to w1) for the scythes.
local function chain(model, parent, points, opts)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local t = (i - 1) / math.max(#points - 2, 1)
		if opts.Flat then
			-- Long axis along a->b, wide across the front (seen broad from the front), thin in depth.
			local w = opts.W0 + (opts.W1 - opts.W0) * t
			local cf = CFrame.lookAt(mid, b, Vector3.new(0, 0, 1))
			box(model, parent, opts.Name or "Blade", Vector3.new(w, opts.Thick, len + 0.05), opts.Color, cf)
			if opts.Edge then
				box(model, parent, "BladeEdge", Vector3.new(w * 0.2, opts.Thick + 0.02, len + 0.05), opts.Edge, cf * CFrame.new(w * 0.42, 0, 0))
			end
		else
			local look = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0)
			cyl(model, parent, opts.Name or "Hose", len + opts.D * 0.4, opts.D, opts.Color, look)
			if opts.Band and i % 2 == 0 then
				ball(model, parent, "HoseBand", opts.D * 1.3, opts.Band, CFrame.new(b))
			end
		end
	end
end

function NovemberRainStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "NovemberRain"
	local rig = { Joints = {} }
	local function V(x, y, z)
		return Vector3.new(x, y, z) * s
	end

	-- Body: a white chest tapering down to a nozzle point.
	local torso = newPart(model, "Body", V(1.6, 1.3, 1.0), BODY)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	box(model, torso, "ChestPlate", V(1.3, 0.9, 0.08), LILAC, CFrame.new(0, 0.1 * s, -0.53 * s))
	box(model, torso, "Collar", V(1.2, 0.3, 1.05), PANEL, CFrame.new(0, 0.65 * s, 0))
	-- Tapering down: a ring like a showerhead, then a cone to a point.
	cyl(model, torso, "Ring", 0.22 * s, 1.5 * s, PANEL, CFrame.new(0, -0.75 * s, 0) * ALONG_Y)
	cyl(model, torso, "RingInner", 0.26 * s, 1.1 * s, BLUE_DEEP, CFrame.new(0, -0.75 * s, 0) * ALONG_Y)
	for k, d in ipairs({ 1.15, 0.9, 0.68, 0.48, 0.3, 0.15 }) do
		cyl(model, torso, "Cone", 0.42 * s, d * s, k % 2 == 0 and LILAC or BODY, CFrame.new(0, (-1.05 - k * 0.38) * s, 0) * ALONG_Y)
	end
	ball(model, torso, "Point", 0.14 * s, BLUE_PALE, CFrame.new(0, -3.5 * s, 0), Enum.Material.Neon)

	-- Head: a tall narrow mask, blue ribbed sides, pink eyes.
	local headBase = CFrame.new(0, 0.85 * s, -0.05 * s)
	local headOffset = CFrame.new(0, 0.85 * s, 0)
	local head, headWeld = box(model, torso, "Head", V(0.75, 1.5, 0.7), BODY, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	ball(model, head, "Crown", 0.75 * s, BODY, CFrame.new(0, 0.72 * s, 0))
	box(model, head, "Stripe", V(0.1, 1.5, 0.05), PANEL, CFrame.new(0, 0, -0.37 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "SidePanel", V(0.22, 1.2, 0.05), BLUE, CFrame.new(side * 0.23 * s, -0.05 * s, -0.37 * s))
		for k = 0, 5 do
			box(model, head, "Rib", V(0.24, 0.04, 0.06), RIB, CFrame.new(side * 0.23 * s, (0.45 - k * 0.2) * s, -0.38 * s))
		end
		box(model, head, "Eye", V(0.16, 0.12, 0.05), EYE, CFrame.new(side * 0.2 * s, 0.25 * s, -0.4 * s) * CFrame.Angles(0, 0, side * -0.3), Enum.Material.Neon)
		ball(model, head, "Knob", 0.24 * s, PANEL, CFrame.new(side * 0.4 * s, 0.2 * s, 0))
	end

	-- A fan of blue feather-blades spraying up and out behind its shoulders.
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 6 do
			local spread = 0.25 + k * 0.2 -- radians out from vertical
			local len = (2.4 + (k % 3) * 0.5 - math.max(0, k - 4) * 0.4) * s
			local root = CFrame.new(side * 0.45 * s, 0.75 * s, 0.45 * s) * CFrame.Angles(0.35 + k * 0.03, 0, -side * spread)
			box(model, torso, "Feather", Vector3.new(0.34 * s, len * 0.6, 0.07 * s), BLUE_DEEP, root * CFrame.new(0, len * 0.3, 0))
			box(model, torso, "FeatherTip", Vector3.new(0.28 * s, len * 0.45, 0.07 * s), k % 2 == 0 and BLUE or BLUE_PALE, root * CFrame.new(0, len * 0.78, 0) * CFrame.Angles(0, 0, side * 0.12))
		end
	end

	-- Two huge scythe blades: up from the shoulders, out, and sweeping down
	-- to the ground either side.
	for _, side in ipairs({ -1, 1 }) do
		local pts = {
			V(side * 0.8, 0.5, 0.1),
			V(side * 1.7, 2.0, 0.4),
			V(side * 2.8, 2.6, 0.5),
			V(side * 3.8, 2.0, 0.3),
			V(side * 4.4, 0.4, 0.0),
			V(side * 4.5, -1.8, -0.3),
			V(side * 4.2, -4.0, -0.6),
			V(side * 3.7, -6.0, -0.8),
		}
		chain(model, torso, pts, { Flat = true, W0 = 0.75 * s, W1 = 0.25 * s, Thick = 0.12 * s, Color = BODY, Edge = LILAC, Name = "Scythe" })
		ball(model, torso, "ScytheJoint", 0.5 * s, PANEL, CFrame.new(pts[1]))
	end

	-- Long thin dark-red hoses hanging down from under it.
	for _, side in ipairs({ -1, 1 }) do
		local pts = {
			V(side * 0.4, -0.7, 0.2),
			V(side * 1.2, -1.4, 0.3),
			V(side * 1.6, -3.0, 0.2),
			V(side * 1.7, -5.0, 0.0),
			V(side * 1.6, -7.0, -0.2),
		}
		chain(model, torso, pts, { D = 0.1 * s, Color = HOSE, Band = HOSE_BAND })
	end

	-- Small white arms folded in front.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 0.9 * s, 0.35 * s, -0.1 * s)
		local offset = CFrame.new(0, -0.65 * s, 0)
		local arm, weld = box(model, torso, a[1], V(0.32, 1.3, 0.32), BODY, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		ball(model, arm, "Shoulder", 0.42 * s, PANEL, CFrame.new(0, 0.6 * s, 0))
		box(model, arm, "Band", V(0.36, 0.1, 0.36), BLUE, CFrame.new(0, -0.3 * s, 0))
		local hand = box(model, arm, "Hand", V(0.34, 0.3, 0.3), LILAC, CFrame.new(0, -0.78 * s, 0))
		for f = -1, 1 do
			box(model, hand, "Finger", V(0.07, 0.26, 0.08), BODY, CFrame.new(f * 0.1 * s, -0.24 * s, -0.03 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.2 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end
	return model, rig
end

return NovemberRainStand
```
