---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# MandomStand

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `MandomStand` (capitals matter) |

**What it does:** MANDOM, matched to the reference render (2026-11-25). It is fixed onto Ringo's RIGHT shoulder (Attached: it doesn't float or bob): a big deep-red EGG, longer than it is wide, leaning back and out over the shoulder; its shell is covered in overlapping red scales, with a black stud ringed in gold set in every gap, row after row under it, a layered PAULDRON of rust-orange plates, each one a little lower and further out than the last, with dark seams a smoky red aura (TuskStand) Mandom's tubes and gold clamps are on Ringo's body (RingoOutfit). Registered by RingoVFX.

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **MandomStand**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.MandomStand  (StarterPlayerScripts.SpinClient.TuskActVFX.MandomStand)

	MANDOM, matched to the reference render (2026-11-25). It is fixed onto
	Ringo's RIGHT shoulder (Attached: it doesn't float or bob):
	  * a big deep-red EGG, longer than it is wide, leaning back and out
	    over the shoulder; its shell is covered in overlapping red scales,
	    with a black stud ringed in gold set in every gap, row after row
	  * under it, a layered PAULDRON of rust-orange plates, each one a
	    little lower and further out than the last, with dark seams
	  * a smoky red aura (TuskStand)
	Mandom's tubes and gold clamps are on Ringo's body (RingoOutfit).
	Registered by RingoVFX.
]]

local MandomStand = {}

local SHELL = Color3.fromRGB(150, 30, 52)
local SCALE_A = Color3.fromRGB(178, 44, 68)
local SCALE_B = Color3.fromRGB(136, 26, 46)
local RIM = Color3.fromRGB(214, 168, 70)
local STUD = Color3.fromRGB(22, 14, 16)
local PLATE = Color3.fromRGB(196, 100, 52)
local PLATE_MID = Color3.fromRGB(170, 80, 40)
local PLATE_DARK = Color3.fromRGB(112, 50, 26)

MandomStand.Aura = Color3.fromRGB(220, 30, 80)
MandomStand.AuraLight = Color3.fromRGB(255, 130, 170)
-- On top of his right shoulder, a little behind (from the root).
MandomStand.Offset = CFrame.new(1.15, 1.78, 0.3)
MandomStand.Attached = true

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

local function ball(model, parent, name, d, color, cf, material)
	local p = weld(model, parent, name, Vector3.new(d, d, d), color, cf, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A flat disc whose face looks along `normal`, at `pos`.
local function disc(model, parent, name, d, depth, color, pos, normal, material)
	local cf = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, math.pi / 2, 0)
	local p = weld(model, parent, name, Vector3.new(depth, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function MandomStand.build(scale)
	local s = (scale or 1) * 0.8
	local model = Instance.new("Model")
	model.Name = "Mandom"
	local rig = { Joints = {} } -- (no joints: it sits still on the shoulder)

	-- The pauldron: the top plate is the body; plates below step out and down.
	local body = newPart(model, "Body", Vector3.new(1.5, 0.34, 1.7) * s, PLATE)
	body.Anchored = true
	body.Massless = false
	body.CFrame = CFrame.new()
	model.PrimaryPart = body
	rig.Body = body
	weld(model, body, "Seam", Vector3.new(1.54, 0.05, 1.74) * s, PLATE_DARK, CFrame.new(0, -0.17 * s, 0))
	local plates = {
		-- { x, y, width, depth, tilt }: overlapping like roof tiles over the shoulder
		{ 0.3, -0.24, 1.4, 1.7, -0.28 },
		{ 0.58, -0.48, 1.25, 1.65, -0.42 },
		{ 0.8, -0.74, 1.05, 1.5, -0.56 },
	}
	for i, p in ipairs(plates) do
		local cf = CFrame.new(p[1] * s, p[2] * s, 0.05 * s) * CFrame.Angles(0, 0, p[5])
		weld(model, body, "Plate", Vector3.new(p[3], 0.3, p[4]) * s, i % 2 == 0 and PLATE_MID or PLATE, cf)
		weld(model, body, "PlateEdge", Vector3.new(p[3] + 0.03, 0.06, p[4] + 0.03) * s, PLATE_DARK, cf * CFrame.new(0, -0.15 * s, 0))
		-- A notch and a rivet on each plate's front.
		weld(model, body, "Notch", Vector3.new(0.22, 0.12, 0.06) * s, PLATE_DARK, cf * CFrame.new(-0.2 * s, 0.02 * s, -p[4] / 2 * s - 0.02 * s))
		ball(model, body, "Rivet", 0.1 * s, PLATE_DARK, cf * CFrame.new(0.3 * s, 0.05 * s, -p[4] / 2 * s - 0.02 * s))
	end
	-- A block on top that the egg sits in, and a strap block behind.
	weld(model, body, "Cradle", Vector3.new(1.1, 0.4, 1.2) * s, PLATE_MID, CFrame.new(0.1 * s, 0.32 * s, 0.15 * s) * CFrame.Angles(0.15, 0, -0.1))
	weld(model, body, "Strap", Vector3.new(0.5, 0.9, 0.35) * s, PLATE_DARK, CFrame.new(-0.4 * s, -0.25 * s, 0.85 * s))

	-- The egg: leaning back and out over the shoulder.
	local a, b = 0.98 * s, 1.32 * s -- half-width, half-length
	local tilt = CFrame.new(0.2 * s, 0.45 * s, 0.25 * s) * CFrame.Angles(math.rad(34), 0, math.rad(-26))
	local eggCF = tilt * CFrame.new(0, b * 0.88, 0)
	local egg = weld(model, body, "Egg", Vector3.new(a * 2, b * 2, a * 2), SHELL, eggCF)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg

	-- Its shell: rows of studs, scales in the gaps between them.
	local function surface(theta, phi, push)
		local fat = 1 + 0.07 * math.cos(theta) -- a little fuller at the bottom
		local r = 1 + (push or 0)
		local p = Vector3.new(a * fat * r * math.sin(theta) * math.cos(phi), b * r * math.cos(theta), a * fat * r * math.sin(theta) * math.sin(phi))
		local n = Vector3.new(p.X / (a * a), p.Y / (b * b), p.Z / (a * a))
		return p, n.Magnitude > 0 and n.Unit or Vector3.new(0, 1, 0)
	end
	local rows, cols = 8, 11
	for i = 1, rows do
		local theta = math.pi * (0.1 + 0.8 * (i - 1) / (rows - 1))
		local count = math.max(5, math.floor(cols * math.sin(theta) + 0.5))
		for j = 1, count do
			local phi = (j + (i % 2) * 0.5) / count * math.pi * 2
			-- Stud: a gold ring with a black centre.
			local p, n = surface(theta, phi, -0.01)
			disc(model, egg, "StudRim", 0.27 * s, 0.07 * s, RIM, p + n * 0.02 * s, n, Enum.Material.Metal)
			disc(model, egg, "Stud", 0.17 * s, 0.08 * s, STUD, p + n * 0.045 * s, n)
			-- A scale in the gap (half a step round, half a row down).
			if i < rows then
				local t2 = theta + math.pi * 0.8 / (rows - 1) * 0.5
				local q = surface(t2, phi + math.pi / count, -0.06)
				ball(model, egg, "Scale", 0.34 * s, (i + j) % 2 == 0 and SCALE_A or SCALE_B, CFrame.new(q))
			end
		end
	end
	-- A stud right on the top.
	local top = Vector3.new(0, b, 0)
	disc(model, egg, "StudRim", 0.27 * s, 0.07 * s, RIM, top, Vector3.new(0, 1, 0), Enum.Material.Metal)
	disc(model, egg, "Stud", 0.17 * s, 0.08 * s, STUD, top + Vector3.new(0, 0.03 * s, 0), Vector3.new(0, 1, 0))

	-- Where its effects come from: the egg's top.
	local point = Instance.new("Attachment")
	point.Name = "NailPoint"
	point.Position = (eggCF * CFrame.new(0, b, 0)).Position
	point.Parent = body
	rig.NailPoint = point
	return model, rig
end

return MandomStand
```
