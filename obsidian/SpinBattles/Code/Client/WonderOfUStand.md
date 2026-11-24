---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# WonderOfUStand

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `WonderOfUStand` (capitals matter) |

**What it does:** WONDER OF U (Tooru, JoJolion), blocky, matched to the art: a tall old man in a long maroon suit. a dark red bowler hat a mask for a face: stacked ribbed bands of maroon and purple, yellow slats down each side, and one round glowing red eye a long yellow knit scarf round his neck, its ends hanging down two red sunflower brooches (gold petals) on the front of his coat maroon gloves, brown shoes, and a long cane in his right hand Registered with TuskStandModels by TooruVFX, so TuskStand floats it behind Tooru (players and NPCs). TooruVFX also builds spare copies to make it "appear" anywhere.

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **WonderOfUStand**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.WonderOfUStand  (StarterPlayerScripts.SpinClient.TuskActVFX.WonderOfUStand)

	WONDER OF U (Tooru, JoJolion), blocky, matched to the art: a tall old
	man in a long maroon suit.
	  * a dark red bowler hat
	  * a mask for a face: stacked ribbed bands of maroon and purple, yellow
	    slats down each side, and one round glowing red eye
	  * a long yellow knit scarf round his neck, its ends hanging down
	  * two red sunflower brooches (gold petals) on the front of his coat
	  * maroon gloves, brown shoes, and a long cane in his right hand
	Registered with TuskStandModels by TooruVFX, so TuskStand floats it
	behind Tooru (players and NPCs). TooruVFX also builds spare copies to
	make it "appear" anywhere.
]]

local WonderOfUStand = {}

local SUIT = Color3.fromRGB(112, 34, 38)
local SUIT_DARK = Color3.fromRGB(78, 22, 28)
local SUIT_LIGHT = Color3.fromRGB(140, 48, 50)
local HAT = Color3.fromRGB(96, 34, 36)
local BAND_A = Color3.fromRGB(120, 40, 60)
local BAND_B = Color3.fromRGB(96, 60, 120)
local SLAT = Color3.fromRGB(226, 186, 70)
local EYE = Color3.fromRGB(255, 50, 40)
local SCARF = Color3.fromRGB(222, 190, 90)
local SCARF_RIB = Color3.fromRGB(190, 156, 64)
local BROOCH = Color3.fromRGB(220, 40, 40)
local PETAL = Color3.fromRGB(236, 176, 50)
local GLOVE = Color3.fromRGB(90, 30, 34)
local SHOE = Color3.fromRGB(110, 70, 44)
local CANE = Color3.fromRGB(120, 40, 36)
local KNOB = Color3.fromRGB(210, 170, 70)

WonderOfUStand.Aura = Color3.fromRGB(170, 60, 70)
WonderOfUStand.AuraLight = Color3.fromRGB(255, 210, 150)
WonderOfUStand.Offset = CFrame.new(2.2, 1.4, 2.8)

local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)
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

-- A sunflower brooch: a red centre ringed with gold petals, facing -Z.
local function brooch(model, parent, cf, s)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		box(model, parent, "Petal", Vector3.new(0.1, 0.16, 0.05) * s, PETAL, cf * CFrame.new(math.sin(a) * 0.17 * s, math.cos(a) * 0.17 * s, 0.01 * s) * CFrame.Angles(0, 0, -a))
	end
	cyl(model, parent, "Brooch", 0.07 * s, 0.26 * s, BROOCH, cf * ALONG_Z, Enum.Material.Neon)
	cyl(model, parent, "BroochRim", 0.06 * s, 0.32 * s, SUIT_DARK, cf * CFrame.new(0, 0, 0.02 * s) * ALONG_Z)
end

function WonderOfUStand.build(scale)
	local s = (scale or 1) * 0.9
	local model = Instance.new("Model")
	model.Name = "WonderOfU"
	local rig = { Joints = {} }

	-- A long coat: chest and the skirt of the coat below it.
	local torso = newPart(model, "Body", Vector3.new(1.9, 2.0, 1.0) * s, SUIT)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.5 * s
	box(model, torso, "CoatSkirt", Vector3.new(1.95, 1.3, 1.05) * s, SUIT, CFrame.new(0, -1.55 * s, 0))
	box(model, torso, "CoatSplit", Vector3.new(0.06, 1.3, 0.05) * s, SUIT_DARK, CFrame.new(0, -1.55 * s, front - 0.03 * s))
	box(model, torso, "Placket", Vector3.new(0.08, 1.9, 0.05) * s, SUIT_DARK, CFrame.new(0, 0, front - 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		-- Lapels and the shoulders of the coat.
		box(model, torso, "Lapel", Vector3.new(0.3, 0.9, 0.06) * s, SUIT_LIGHT, CFrame.new(side * 0.3 * s, 0.5 * s, front - 0.03 * s) * CFrame.Angles(0, 0, side * 0.35))
		box(model, torso, "ShoulderPad", Vector3.new(0.55, 0.3, 1.05) * s, SUIT, CFrame.new(side * 0.95 * s, 0.9 * s, 0))
		-- A sunflower brooch either side of the front.
		brooch(model, torso, CFrame.new(side * 0.66 * s, -0.35 * s, front - 0.06 * s), s)
		box(model, torso, "Pocket", Vector3.new(0.5, 0.06, 0.05) * s, SUIT_DARK, CFrame.new(side * 0.5 * s, -1.25 * s, front - 0.06 * s))
	end

	-- The yellow knit scarf: wound round the neck, both ends hanging down.
	box(model, torso, "ScarfWrap", Vector3.new(1.1, 0.5, 1.15) * s, SCARF, CFrame.new(0, 1.2 * s, 0))
	box(model, torso, "ScarfFold", Vector3.new(1.2, 0.3, 1.2) * s, SCARF_RIB, CFrame.new(0, 1.0 * s, 0))
	for i, end_ in ipairs({ { -0.25, 1.7 }, { 0.22, 1.3 } }) do
		local len = end_[2] * s
		local x = end_[1] * s
		box(model, torso, "ScarfEnd", Vector3.new(0.34 * s, len, 0.1 * s), SCARF, CFrame.new(x, 0.9 * s - len / 2, front - 0.1 * s - i * 0.02 * s))
		for k = 1, math.floor(end_[2] / 0.2) do
			box(model, torso, "ScarfRib", Vector3.new(0.36, 0.03, 0.11) * s, SCARF_RIB, CFrame.new(x, 0.9 * s - k * 0.2 * s, front - 0.1 * s - i * 0.02 * s))
		end
	end

	-- Head: a ribbed mask, yellow slats down the sides, one red eye.
	local headBase = CFrame.new(0, 1.45 * s, 0)
	local headOffset = CFrame.new(0, 0.6 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.85, 1.15, 0.85) * s, BAND_A, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.43 * s
	for k = 0, 6 do
		box(model, head, "Band", Vector3.new(0.9, 0.08, 0.9) * s, k % 2 == 0 and BAND_B or SUIT_DARK, CFrame.new(0, (-0.48 + k * 0.16) * s, 0))
	end
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			box(model, head, "Slat", Vector3.new(0.07, 0.95, 0.06) * s, SLAT, CFrame.new(side * (0.2 + k * 0.08) * s, -0.05 * s, hf - 0.03 * s))
		end
	end
	box(model, head, "Nose", Vector3.new(0.14, 0.5, 0.1) * s, BAND_A, CFrame.new(0, -0.05 * s, hf - 0.05 * s))
	cyl(model, head, "EyeRim", 0.08 * s, 0.34 * s, SUIT_DARK, CFrame.new(0.18 * s, 0.18 * s, hf - 0.05 * s) * ALONG_Z)
	cyl(model, head, "Eye", 0.1 * s, 0.24 * s, EYE, CFrame.new(0.18 * s, 0.18 * s, hf - 0.07 * s) * ALONG_Z, Enum.Material.Neon)
	-- The bowler hat: a round crown, a band, a curled brim.
	ball(model, head, "HatCrown", 1.0 * s, HAT, CFrame.new(0, 0.62 * s, 0))
	box(model, head, "HatCrownBase", Vector3.new(0.95, 0.3, 0.95) * s, HAT, CFrame.new(0, 0.6 * s, 0))
	box(model, head, "HatBand", Vector3.new(0.98, 0.1, 0.98) * s, SUIT_DARK, CFrame.new(0, 0.52 * s, 0))
	cyl(model, head, "HatBrim", 0.08 * s, 1.45 * s, HAT, CFrame.new(0, 0.44 * s, 0) * ALONG_Y)

	-- Arms: long suit sleeves, maroon gloves. The right hand holds the cane.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.2 * s, 0.75 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.55, 2.2, 0.55) * s, SUIT, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Cuff", Vector3.new(0.62, 0.2, 0.62) * s, SUIT_DARK, CFrame.new(0, -0.95 * s, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.5, 0.45, 0.48) * s, GLOVE, CFrame.new(0, -1.3 * s, 0))
		if a[1] == "ArmR" then
			-- The cane: long, held point-down, a gold knob on top.
			cyl(model, hand, "Cane", 3.6 * s, 0.14 * s, CANE, CFrame.new(0, -1.5 * s, -0.25 * s) * ALONG_Y)
			ball(model, hand, "CaneKnob", 0.24 * s, KNOB, CFrame.new(0, 0.25 * s, -0.25 * s))
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: suit trousers, brown shoes.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.45 * s, -2.1 * s, 0)
		local offset = CFrame.new(0, -1.05 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.65, 2.1, 0.65) * s, SUIT_DARK, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Shoe", Vector3.new(0.66, 0.3, 1.0) * s, SHOE, CFrame.new(0, -1.1 * s, -0.17 * s))
	end
	return model, rig
end

return WonderOfUStand
```
