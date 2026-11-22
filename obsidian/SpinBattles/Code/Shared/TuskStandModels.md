---
tags: [code, shared]
type: ModuleScript
location: "ReplicatedStorage › SpinShared"
updated: 2026-11-22
---
# TuskStandModels

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ReplicatedStorage › SpinShared` |
| **Exact name** | `TuskStandModels` (capitals matter) |

**What it does:** Builds the Tusk Stand for each Act. Built on each client (visual only), so Stands never cost server physics or replication.

## How to add it
1. In Studio's Explorer, find **SpinShared** (ReplicatedStorage › SpinShared).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **TuskStandModels**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskStandModels  (ReplicatedStorage.SpinShared.TuskStandModels)

	Builds the Tusk Stand for each Act. Built on each client (visual only),
	so Stands never cost server physics or replication.

	TuskStandModels.build(act, scale) -> model, rig
	  rig.Body           root part of the Stand (anchored by the caller)
	  rig.Joints[name]   = { Weld = Weld, Base = CFrame } for animated pieces
	                       (EarL, EarR, Leg1..Leg4). Animate with
	                       Weld.C0 = Base * rotation.
	  rig.NailPoint      Attachment where Tusk's nail energy gathers

	Act 1 (from the owner's reference): small pink egg-shaped body covered
	in gold stars, floppy ears, a big forehead star with a gold pin running
	to a yellow beak, heavy-lidded eyes and four thin legs ending in hearts.

	Using your own model instead: put a Model named "TuskAct1" (PrimaryPart
	set) in ReplicatedStorage.SpinShared.Assets. It is cloned and resized,
	and gets the same idle motion (ears and legs only animate on the
	built-in model).
]]

local TuskConfig = require(script.Parent.TuskConfig)

local TuskStandModels = {}

local colors = TuskConfig.Colors

local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "Ellipsoid" then
			p[k] = v
		end
	end
	if props.Ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere -- fits the part size, so any Size = ellipsoid
		mesh.Parent = p
	end
	p.Parent = model
	return p
end

-- Weld `p` to `body` at local CFrame `cf` (C0 can be animated later).
local function attach(body, p, cf)
	local w = Instance.new("Weld")
	w.Part0 = body
	w.Part1 = p
	w.C0 = cf
	w.Parent = p
	p.CFrame = body.CFrame * cf
	return w
end

local function override(act, scale)
	local assets = script.Parent:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("TuskAct" .. act)
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		local clone = custom:Clone()
		local size = clone:GetExtentsSize()
		local largest = math.max(size.X, size.Y, size.Z)
		if largest > 0 then
			clone:ScaleTo(clone:GetScale() * (2.4 * scale) / largest)
		end
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
				d.Anchored = d == clone.PrimaryPart
			end
		end
		local point = Instance.new("Attachment")
		point.Name = "NailPoint"
		point.Position = Vector3.new(0, 0, -size.Z * 0.5)
		point.Parent = clone.PrimaryPart
		return clone, { Body = clone.PrimaryPart, Joints = {}, NailPoint = point }
	end
	return nil
end

-- Five-point star made of five thin spikes, laid on the surface facing `normal`.
local function star(model, body, center, normal, size, color)
	local up = math.abs(normal.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local base = CFrame.lookAt(center, center + normal, up)
	for i = 0, 4 do
		local spike = part(model, {
			Name = "StarSpike",
			Size = Vector3.new(size * 0.28, size * 0.55, size * 0.04),
			Color = color,
			Ellipsoid = true,
		})
		local cf = base * CFrame.Angles(0, 0, i * math.pi * 2 / 5) * CFrame.new(0, size * 0.22, 0)
		attach(body, spike, cf)
	end
end

local function buildAct1(scale)
	local s = scale
	local model = Instance.new("Model")
	model.Name = "TuskAct1"

	local body = part(model, {
		Name = "Body",
		Size = Vector3.new(1.35, 1.8, 1.25) * s,
		Color = colors.Pink,
		Ellipsoid = true,
		Massless = false,
	})
	body.CFrame = CFrame.new()
	body.Anchored = true
	model.PrimaryPart = body

	local rig = { Body = body, Joints = {} }

	-- Shading belly (darker lower half reads as volume from a distance).
	local belly = part(model, { Name = "Belly", Size = Vector3.new(1.2, 1.1, 1.15) * s, Color = colors.PinkDark, Ellipsoid = true })
	attach(body, belly, CFrame.new(0, -0.35 * s, 0.04 * s))

	-- Eyes: white balls, black pupils, heavy tilted brows (grumpy look).
	for _, side in ipairs({ -1, 1 }) do
		local eye = part(model, { Name = "Eye", Size = Vector3.new(0.32, 0.32, 0.22) * s, Color = Color3.new(1, 1, 1), Ellipsoid = true })
		attach(body, eye, CFrame.new(side * 0.26 * s, 0.12 * s, -0.55 * s))
		local pupil = part(model, { Name = "Pupil", Size = Vector3.new(0.13, 0.13, 0.06) * s, Color = Color3.fromRGB(20, 10, 20), Ellipsoid = true })
		attach(body, pupil, CFrame.new(side * 0.25 * s, 0.1 * s, -0.66 * s))
		local brow = part(model, { Name = "Brow", Size = Vector3.new(0.4, 0.1, 0.12) * s, Color = colors.PinkDark })
		attach(body, brow, CFrame.new(side * 0.26 * s, 0.3 * s, -0.58 * s) * CFrame.Angles(0, 0, side * -0.35))
	end

	-- Beak: elongated yellow ellipsoid pointing forward and down.
	local beak = part(model, { Name = "Beak", Size = Vector3.new(0.2, 0.2, 0.55) * s, Color = colors.Star, Ellipsoid = true })
	attach(body, beak, CFrame.new(0.05 * s, -0.12 * s, -0.75 * s) * CFrame.Angles(-0.55, 0.15, 0))

	-- Forehead star and the gold pin running from it to the beak.
	local starCenter = Vector3.new(-0.18 * s, 0.62 * s, -0.42 * s)
	star(model, body, starCenter, Vector3.new(-0.2, 0.55, -0.8).Unit, 0.5 * s, colors.Star)
	local beakTip = Vector3.new(0.12 * s, -0.32 * s, -0.95 * s)
	local pinLength = (beakTip - starCenter).Magnitude
	local pin = part(model, {
		Name = "Pin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(pinLength, 0.035 * s, 0.035 * s),
		Color = colors.Gold,
		Material = Enum.Material.Metal,
		Reflectance = 0.3,
	})
	-- Cylinder axis is X: build a frame whose RightVector runs star -> beak.
	local mid = (starCenter + beakTip) / 2
	attach(body, pin, CFrame.lookAt(mid, beakTip) * CFrame.Angles(0, math.pi / 2, 0))

	-- Small gold stars scattered over the body.
	local starSpots = {
		Vector3.new(0.55, 0.45, -0.2), Vector3.new(0.6, -0.1, 0.1), Vector3.new(-0.6, 0.0, 0.15),
		Vector3.new(-0.45, -0.55, -0.3), Vector3.new(0.35, -0.6, -0.4), Vector3.new(0.1, 0.75, 0.35),
		Vector3.new(-0.3, 0.4, 0.55), Vector3.new(0.4, 0.1, 0.55), Vector3.new(0.0, -0.75, 0.3),
	}
	for _, spot in ipairs(starSpots) do
		local n = Vector3.new(spot.X / 0.675, spot.Y / 0.9, spot.Z / 0.625).Unit
		local surface = Vector3.new(n.X * 0.675, n.Y * 0.9, n.Z * 0.625) * s * 1.01
		star(model, body, surface, n, 0.22 * s, colors.Star)
	end

	-- Floppy ears (animated).
	local ears = {
		{ Name = "EarL", Base = CFrame.new(-0.45 * s, 0.75 * s, 0) * CFrame.Angles(0, 0, 0.9), Size = Vector3.new(0.38, 1.25, 0.12) },
		{ Name = "EarR", Base = CFrame.new(0.5 * s, 0.65 * s, 0.05 * s) * CFrame.Angles(0.2, 0, -1.35), Size = Vector3.new(0.34, 1.1, 0.12) },
	}
	for _, e in ipairs(ears) do
		local ear = part(model, { Name = e.Name, Size = e.Size * s, Color = colors.Pink, Ellipsoid = true })
		local inner = part(model, { Name = e.Name .. "Inner", Size = e.Size * s * Vector3.new(0.55, 0.75, 0.5), Color = colors.PinkDark, Ellipsoid = true })
		local offset = CFrame.new(0, e.Size.Y * s * 0.45, 0)
		local w = attach(body, ear, e.Base * offset)
		attach(ear, inner, CFrame.new(0, 0, -0.03 * s))
		rig.Joints[e.Name] = { Weld = w, Base = e.Base, Offset = offset }
	end

	-- Little fin spikes around the silhouette.
	local fins = {
		CFrame.new(-0.62 * s, 0.25 * s, 0) * CFrame.Angles(0, 0, 1.2),
		CFrame.new(0.66 * s, 0.2 * s, -0.1 * s) * CFrame.Angles(0, 0, -1.3),
		CFrame.new(-0.55 * s, -0.4 * s, 0) * CFrame.Angles(0, 0, 2.0),
		CFrame.new(0.58 * s, -0.45 * s, 0) * CFrame.Angles(0, 0, -2.1),
	}
	for _, cf in ipairs(fins) do
		local fin = part(model, { Name = "Fin", Size = Vector3.new(0.16, 0.42, 0.08) * s, Color = colors.Pink, Ellipsoid = true })
		attach(body, fin, cf * CFrame.new(0, 0.18 * s, 0))
	end

	-- Four thin legs ending in hearts (animated swing).
	for i = 1, 4 do
		local x = (-1.5 + (i - 1)) * 0.22 * s
		local base = CFrame.new(x, -0.78 * s, (i % 2 == 0 and 0.12 or -0.1) * s)
		local legLength = (0.55 + (i % 2) * 0.12) * s
		local leg = part(model, {
			Name = "Leg" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(legLength, 0.05 * s, 0.05 * s),
			Color = colors.Pink,
		})
		-- Cylinder axis is X; rotate so it hangs down from the joint.
		local offset = CFrame.new(0, -legLength / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local w = attach(body, leg, base * offset)
		rig.Joints["Leg" .. i] = { Weld = w, Base = base, Offset = offset }

		-- Heart foot: two lobes and a point, attached to the leg's bottom end.
		local footCF = CFrame.new(-legLength / 2 - 0.12 * s, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2)
		for _, side in ipairs({ -1, 1 }) do
			local lobe = part(model, { Name = "HeartLobe", Size = Vector3.new(0.2, 0.2, 0.1) * s, Color = colors.Heart, Ellipsoid = true })
			attach(leg, lobe, footCF * CFrame.new(side * 0.075 * s, 0.03 * s, 0))
		end
		local point = part(model, { Name = "HeartPoint", Size = Vector3.new(0.2, 0.2, 0.1) * s, Color = colors.Heart, Ellipsoid = true })
		attach(leg, point, footCF * CFrame.new(0, -0.08 * s, 0) * CFrame.Angles(0, 0, math.pi / 4))
	end

	local nailPoint = Instance.new("Attachment")
	nailPoint.Name = "NailPoint"
	nailPoint.Position = Vector3.new(0, -0.1 * s, -0.9 * s)
	nailPoint.Parent = body
	rig.NailPoint = nailPoint

	return model, rig
end

local builders = {
	[1] = buildAct1,
}

function TuskStandModels.build(act, scale)
	scale = scale or 1
	local model, rig = override(act, scale)
	if model then
		return model, rig
	end
	local builder = builders[act]
	if not builder then
		return nil
	end
	return builder(scale)
end

return TuskStandModels
```
