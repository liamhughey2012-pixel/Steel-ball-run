---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# JohnRodStand

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `JohnRodStand` (capitals matter) |

**What it does:** JOHN ROD, matched to the art: a single bent metal rod tracing the outline of a man. One continuous line: up from the left foot (bent out sideways), up the left leg, out to an akimbo elbow, up to the shoulder, into the neck, round a loop for the head, back down the neck, out to the right shoulder and akimbo elbow, in to the waist, and down the long right leg to a foot bent out the other way. It's bright pale metal with a soft shine; TuskStand gives it a pale blue aura. Registered with TuskStandModels by JohnRodVFX. TuskStand floats it beside its user, or draws it wherever the user is steering it (StandRemotePos).

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **JohnRodStand**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.JohnRodStand  (StarterPlayerScripts.SpinClient.TuskActVFX.JohnRodStand)

	JOHN ROD, matched to the art: a single bent metal rod tracing the
	outline of a man. One continuous line: up from the left foot (bent out
	sideways), up the left leg, out to an akimbo elbow, up to the shoulder,
	into the neck, round a loop for the head, back down the neck, out to the
	right shoulder and akimbo elbow, in to the waist, and down the long
	right leg to a foot bent out the other way. It's bright pale metal with
	a soft shine; TuskStand gives it a pale blue aura.
	Registered with TuskStandModels by JohnRodVFX. TuskStand floats it
	beside its user, or draws it wherever the user is steering it
	(StandRemotePos).
]]

local JohnRodStand = {}

local ROD = Color3.fromRGB(236, 240, 250)
local SHINE = Color3.fromRGB(255, 255, 255)
local DIAMETER = 0.22
local CHEST = 4.2 -- the rig's body sits at this height above the feet

JohnRodStand.Aura = Color3.fromRGB(170, 215, 255)
JohnRodStand.AuraLight = Color3.fromRGB(240, 250, 255)
JohnRodStand.Offset = CFrame.new(2.8, 1.2, 1.5)

-- The outline (x, y) from the left foot round to the right foot; y = 0 is
-- the ground. The head loop is added in between.
local LEFT = {
	{ -2.4, 1.55 }, { -1.35, 1.42 }, { -1.27, 2.6 }, { -1.15, 3.8 }, { -2.1, 4.55 }, { -1.3, 5.5 }, { -0.35, 5.62 }, { -0.3, 6.05 },
}
local RIGHT = {
	{ 0.3, 6.05 }, { 0.35, 5.62 }, { 1.3, 5.5 }, { 2.1, 4.55 }, { 1.2, 3.9 }, { 1.4, 1.2 }, { 1.6, 0.12 }, { 2.6, 0.02 },
}
local HEAD_CENTER, HEAD_RADIUS = { 0, 6.78 }, 0.78

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

local function weld(model, parent, name, size, color, cf, material)
	local p = newPart(model, name, size, color, material)
	local w = Instance.new("Weld")
	w.Part0 = parent
	w.Part1 = p
	w.C0 = cf
	w.Parent = p
	p.CFrame = parent.CFrame * cf
	return p
end

-- The full path, head loop included.
local function outline()
	local pts = {}
	for _, p in ipairs(LEFT) do
		table.insert(pts, p)
	end
	-- Round the head: from its bottom-left, over the top, to its bottom-right.
	local a0, a1 = math.rad(-115), math.rad(-65 - 360)
	local steps = 16
	for i = 1, steps - 1 do
		local a = a0 + (a1 - a0) * i / steps
		table.insert(pts, { HEAD_CENTER[1] + math.cos(a) * HEAD_RADIUS, HEAD_CENTER[2] + math.sin(a) * HEAD_RADIUS })
	end
	for _, p in ipairs(RIGHT) do
		table.insert(pts, p)
	end
	return pts
end

function JohnRodStand.build(scale)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "JohnRod"
	local rig = { Joints = {} }
	-- An invisible core at chest height holds the rod.
	local body = newPart(model, "Body", Vector3.new(0.4, 0.4, 0.4), ROD)
	body.Transparency = 1
	body.Anchored = true
	body.Massless = false
	body.CFrame = CFrame.new()
	model.PrimaryPart = body
	rig.Body = body
	local d = DIAMETER * s
	local pts = outline()
	local function at(p)
		return Vector3.new(p[1] * s, (p[2] - CHEST) * s, 0)
	end
	for i = 1, #pts - 1 do
		local a, b = at(pts[i]), at(pts[i + 1])
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		-- Cylinders run along X: aim X from a to b.
		local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0)
		local seg = weld(model, body, "Rod", Vector3.new(len + d * 0.5, d, d), ROD, cf)
		seg.Shape = Enum.PartType.Cylinder
		seg.Reflectance = 0.25
		-- Round the bends.
		local bend = weld(model, body, "Bend", Vector3.new(d, d, d), ROD, CFrame.new(b))
		bend.Shape = Enum.PartType.Ball
	end
	-- Rounded ends at the feet, with a glint.
	for _, p in ipairs({ pts[1], pts[#pts] }) do
		local tip = weld(model, body, "Tip", Vector3.new(d * 1.3, d * 1.3, d * 1.3), SHINE, CFrame.new(at(p)), Enum.Material.Neon)
		tip.Shape = Enum.PartType.Ball
	end
	-- A little shine high on the head loop.
	local glint = weld(model, body, "Glint", Vector3.new(d * 0.9, d * 0.9, d * 0.9), SHINE, CFrame.new(at({ HEAD_CENTER[1] - 0.45, HEAD_CENTER[2] + 0.55 })) * CFrame.new(0, 0, -d * 0.4), Enum.Material.Neon)
	glint.Shape = Enum.PartType.Ball
	-- Where its strikes come from: the right elbow.
	local point = Instance.new("Attachment")
	point.Name = "NailPoint"
	point.Position = at(RIGHT[4])
	point.Parent = body
	rig.NailPoint = point
	return model, rig
end

return JohnRodStand
```
