---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# D4CStand

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `D4CStand` (capitals matter) |

**What it does:** The D4C (Dirty Deeds Done Dirt Cheap) Stand model (Funny Valentine), blocky. Built from the Stand's description until there's reference art: a pale-blue humanoid with dark-navy stripes two long rabbit-like horns rising from its head, pink inside big round eyes and a dark mouth plate with vertical slits a navy cross band over the chest, a pink diamond at the belt pink-rimmed shoulder pads and knuckle guards Registered with TuskStandModels by ValentineVFX, so TuskStand floats it behind Valentine (players and NPCs) with a pale-blue aura. A custom model at ReplicatedStorage.SpinAssets.TuskAct13 replaces it.

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **D4CStand**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.D4CStand  (StarterPlayerScripts.SpinClient.TuskActVFX.D4CStand)

	The D4C (Dirty Deeds Done Dirt Cheap) Stand model (Funny Valentine),
	blocky. Built from the Stand's description until there's reference art:
	  * a pale-blue humanoid with dark-navy stripes
	  * two long rabbit-like horns rising from its head, pink inside
	  * big round eyes and a dark mouth plate with vertical slits
	  * a navy cross band over the chest, a pink diamond at the belt
	  * pink-rimmed shoulder pads and knuckle guards
	Registered with TuskStandModels by ValentineVFX, so TuskStand floats it
	behind Valentine (players and NPCs) with a pale-blue aura. A custom model
	at ReplicatedStorage.SpinAssets.TuskAct13 replaces it.
]]

local D4CStand = {}

local BODY = Color3.fromRGB(156, 194, 236)
local BODY_SHADE = Color3.fromRGB(120, 160, 210)
local NAVY = Color3.fromRGB(36, 52, 110)
local PINK = Color3.fromRGB(236, 120, 170)
local WHITE = Color3.fromRGB(245, 246, 250)
local PUPIL = Color3.fromRGB(30, 26, 40)

D4CStand.Aura = Color3.fromRGB(120, 170, 255)
D4CStand.AuraLight = Color3.fromRGB(230, 240, 255)
D4CStand.Offset = CFrame.new(2.3, 1.6, 2.8)

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

-- Navy stripes round a limb (local Y) at the given heights.
local function stripes(model, parent, size, ys, s)
	for _, y in ipairs(ys) do
		box(model, parent, "Stripe", Vector3.new(size.X + 0.06 * s, 0.14 * s, size.Z + 0.06 * s), NAVY, CFrame.new(0, y, 0))
	end
end

function D4CStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "D4C"
	local rig = { Joints = {} }

	-- Torso (the anchored root the Stand is moved by).
	local torso = newPart(model, "Body", Vector3.new(2.2, 2.0, 1.1) * s, BODY)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.56 * s
	-- Navy cross band over the chest, abs, belt with a pink diamond.
	for _, a in ipairs({ 0.6, -0.6 }) do
		box(model, torso, "CrossBand", Vector3.new(0.26, 2.3, 0.06) * s, NAVY, CFrame.new(0, 0.2 * s, front - 0.02 * s) * CFrame.Angles(0, 0, a))
	end
	for _, x in ipairs({ -0.3, 0.3 }) do
		for k = 0, 1 do
			box(model, torso, "Ab", Vector3.new(0.45, 0.3, 0.06) * s, BODY_SHADE, CFrame.new(x * s, (-0.45 - k * 0.36) * s, front - 0.03 * s))
		end
	end
	box(model, torso, "Belt", Vector3.new(2.26, 0.26, 1.16) * s, NAVY, CFrame.new(0, -1.0 * s, 0))
	box(model, torso, "Emblem", Vector3.new(0.4, 0.4, 0.08) * s, PINK, CFrame.new(0, -1.0 * s, front - 0.05 * s) * CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Neon)
	box(model, torso, "Hips", Vector3.new(1.9, 0.6, 1.0) * s, BODY_SHADE, CFrame.new(0, -1.4 * s, 0))
	box(model, torso, "Neck", Vector3.new(0.6, 0.4, 0.6) * s, BODY_SHADE, CFrame.new(0, 1.15 * s, 0))

	-- Head: big round eyes, a slitted mouth plate, two long rabbit-like horns.
	local headBase = CFrame.new(0, 1.2 * s, 0)
	local headOffset = CFrame.new(0, 0.6 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(1.05, 1.15, 1.05) * s, BODY, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.53 * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.36, 0.36, 0.06) * s, WHITE, CFrame.new(side * 0.24 * s, 0.14 * s, hf - 0.02 * s))
		box(model, head, "Pupil", Vector3.new(0.16, 0.16, 0.06) * s, PUPIL, CFrame.new(side * 0.22 * s, 0.12 * s, hf - 0.05 * s))
		box(model, head, "Brow", Vector3.new(0.4, 0.08, 0.06) * s, NAVY, CFrame.new(side * 0.24 * s, 0.36 * s, hf - 0.03 * s) * CFrame.Angles(0, 0, side * -0.2))
		-- Horn: three tapering blocks, tilted out a little, pink stripe inside.
		local hornBase = CFrame.new(side * 0.3 * s, 0.55 * s, 0) * CFrame.Angles(0, 0, side * -0.12)
		for k = 0, 2 do
			local w = (0.28 - k * 0.06) * s
			box(model, head, "Horn", Vector3.new(w, 0.62 * s, w * 0.8), BODY, hornBase * CFrame.new(0, (0.3 + k * 0.58) * s, 0))
		end
		box(model, head, "HornInner", Vector3.new(0.08, 1.4, 0.04) * s, PINK, hornBase * CFrame.new(0, 0.85 * s, -0.12 * s))
		box(model, head, "HornTip", Vector3.new(0.12, 0.2, 0.12) * s, NAVY, hornBase * CFrame.new(0, 2.0 * s, 0))
	end
	box(model, head, "Mouth", Vector3.new(0.6, 0.3, 0.06) * s, NAVY, CFrame.new(0, -0.3 * s, hf - 0.02 * s))
	for i = -2, 2 do
		box(model, head, "MouthSlit", Vector3.new(0.04, 0.26, 0.04) * s, BODY, CFrame.new(i * 0.1 * s, -0.3 * s, hf - 0.06 * s))
	end

	-- Shoulders and striped arms with pink knuckle guards.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		box(model, torso, "ShoulderPad", Vector3.new(0.9, 0.6, 1.1) * s, BODY_SHADE, CFrame.new(side * 1.4 * s, 0.82 * s, 0))
		box(model, torso, "PadRim", Vector3.new(0.96, 0.12, 1.16) * s, PINK, CFrame.new(side * 1.4 * s, 0.55 * s, 0))
		local base = CFrame.new(side * 1.45 * s, 0.5 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local size = Vector3.new(0.6, 2.2, 0.6) * s
		local arm, weld = box(model, torso, a[1], size, BODY, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		stripes(model, arm, size, { 0.6 * s, 0.1 * s, -0.4 * s }, s)
		local hand = box(model, arm, "Hand", Vector3.new(0.6, 0.5, 0.55) * s, BODY_SHADE, CFrame.new(0, -1.3 * s, 0))
		box(model, hand, "Knuckles", Vector3.new(0.64, 0.16, 0.2) * s, PINK, CFrame.new(0, -0.1 * s, -0.22 * s))
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Striped legs.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.5 * s, -1.6 * s, 0)
		local offset = CFrame.new(0, -1.15 * s, 0)
		local size = Vector3.new(0.7, 2.3, 0.7) * s
		local leg, weld = box(model, torso, "Leg" .. i, size, BODY, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		stripes(model, leg, size, { 0.5 * s, 0 * s, -0.5 * s }, s)
		box(model, leg, "Knee", Vector3.new(0.5, 0.3, 0.1) * s, PINK, CFrame.new(0, 0.25 * s, -0.37 * s))
		box(model, leg, "Foot", Vector3.new(0.7, 0.3, 1.0) * s, NAVY, CFrame.new(0, -1.25 * s, -0.15 * s))
	end
	return model, rig
end

return D4CStand
```
