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

	Using your own model instead: set its asset id in TuskConfig.StandModels
	(StandAssetLoader loads it into ReplicatedStorage.SpinAssets), or put a
	Model named "TuskAct1" in ReplicatedStorage.SpinAssets by hand. It is
	cloned, cleaned of scripts, welded, resized to the configured Height and
	gets the same floating motion (ears/legs only animate on built-in models).
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

-- Custom Stand model: ReplicatedStorage.SpinAssets.TuskActN (loaded by
-- StandAssetLoader or placed by hand) or SpinShared.Assets.TuskActN.
local function findCustom(act)
	local name = "TuskAct" .. act
	local rs = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
	local custom = rs and rs:FindFirstChild(name)
	if not custom then
		local assets = script.Parent:FindFirstChild("Assets")
		custom = assets and assets:FindFirstChild(name)
	end
	return custom
end

local function override(act, scale)
	local custom = findCustom(act)
	if not custom then
		return nil
	end
	local clone = custom:Clone()
	if not clone:IsA("Model") then
		local wrapper = Instance.new("Model")
		clone.Parent = wrapper
		clone = wrapper
	end
	-- Safety + visual-only: no scripts, no collisions, no sounds playing.
	local parts = {}
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.Anchored = false
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		return nil
	end
	-- Root = the PrimaryPart, or the biggest part.
	local root = clone.PrimaryPart
	if not root or not root:IsDescendantOf(clone) then
		root = parts[1]
		for _, p in ipairs(parts) do
			if p.Size.Magnitude > root.Size.Magnitude then
				root = p
			end
		end
		clone.PrimaryPart = root
	end
	-- Weld every loose part to the root so the model moves as one piece.
	for _, p in ipairs(parts) do
		if p ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
		end
	end
	root.Anchored = true

	-- Size and facing from TuskConfig.StandModels.
	local settings = TuskConfig.StandModels and TuskConfig.StandModels[act] or {}
	local extents = clone:GetExtentsSize()
	local height = (settings.Height or 3) * scale
	if extents.Y > 0 then
		clone:ScaleTo(clone:GetScale() * height / extents.Y)
	end
	local rot = settings.Rotation or Vector3.new()
	local boxCF = clone:GetBoundingBox()
	-- Pivot at the model's centre, facing -Z, plus the configured rotation.
	clone.WorldPivot = CFrame.new(boxCF.Position) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))

	local point = Instance.new("Attachment")
	point.Name = "NailPoint"
	point.Parent = root
	point.WorldPosition = boxCF.Position + Vector3.new(0, 0, -clone:GetExtentsSize().Z * 0.5)
	return clone, { Body = root, Joints = {}, NailPoint = point, Custom = true }
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

---------------------------------------------------------------------------
-- ACT 2: Act 1 grown up. Bigger, magenta, a crest of spikes, two small arms.
---------------------------------------------------------------------------
local function limb(model, parent, rig, name, base, length, thickness, color, handColor)
	local arm = part(model, { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, thickness, thickness), Color = color })
	-- Cylinder axis is X; hang it down from the joint.
	local offset = CFrame.new(0, -length / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local w = attach(parent, arm, base * offset)
	rig.Joints[name] = { Weld = w, Base = base, Offset = offset }
	local hand = part(model, { Name = name .. "Hand", Size = Vector3.new(thickness * 1.6, thickness * 1.6, thickness * 1.6), Color = handColor or color, Ellipsoid = true })
	attach(arm, hand, CFrame.new(-length / 2 - thickness * 0.4, 0, 0))
	return arm, hand
end

local function buildAct2(scale)
	local s = scale * 1.25
	local model, rig = buildAct1(s)
	model.Name = "TuskAct2"
	-- (Color3 values can't be table keys, so compare directly.)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Color == colors.Pink then
				d.Color = Color3.fromRGB(214, 84, 196)
			elseif d.Color == colors.PinkDark then
				d.Color = Color3.fromRGB(118, 40, 150)
			end
		end
	end
	local body = rig.Body
	-- Crest of three spikes.
	for i = -1, 1 do
		local spike = part(model, { Name = "Crest", Size = Vector3.new(0.14, 0.7 - math.abs(i) * 0.2, 0.3) * s, Color = Color3.fromRGB(240, 200, 255), Ellipsoid = true })
		attach(body, spike, CFrame.new(i * 0.22 * s, 0.95 * s, 0.1 * s) * CFrame.Angles(0, 0, -i * 0.4))
	end
	-- Glowing chest star.
	local core = part(model, { Name = "Core", Size = Vector3.new(0.3, 0.3, 0.08) * s, Color = colors.Cyan, Material = Enum.Material.Neon, Ellipsoid = true })
	attach(body, core, CFrame.new(0, -0.35 * s, -0.62 * s))
	-- Arms.
	limb(model, body, rig, "ArmL", CFrame.new(-0.62 * s, -0.05 * s, -0.1 * s) * CFrame.Angles(0, 0, -0.5), 0.6 * s, 0.13 * s, Color3.fromRGB(214, 84, 196), colors.Star)
	local _, hand = limb(model, body, rig, "ArmR", CFrame.new(0.62 * s, -0.05 * s, -0.1 * s) * CFrame.Angles(0, 0, 0.5), 0.6 * s, 0.13 * s, Color3.fromRGB(214, 84, 196), colors.Star)
	rig.NailPoint.Parent = hand
	rig.NailPoint.Position = Vector3.new()
	return model, rig
end

---------------------------------------------------------------------------
-- Humanoid Stands (Act 3, Act 4)
---------------------------------------------------------------------------
local function buildHumanoid(name, scale, look)
	local s = scale
	local model = Instance.new("Model")
	model.Name = name
	local rig = { Joints = {} }

	local torso = part(model, { Name = "Body", Size = look.Torso * s, Color = look.Body, Ellipsoid = true, Massless = false })
	torso.CFrame = CFrame.new()
	torso.Anchored = true
	model.PrimaryPart = torso
	rig.Body = torso
	local ty = look.Torso.Y * s / 2

	-- Chest trim and star.
	local plate = part(model, { Name = "Chest", Size = Vector3.new(look.Torso.X * 0.75, look.Torso.Y * 0.45, 0.12) * s, Color = look.Trim, Material = look.TrimMaterial or Enum.Material.SmoothPlastic, Ellipsoid = true })
	attach(torso, plate, CFrame.new(0, ty * 0.3, -look.Torso.Z * s * 0.44))
	star(model, torso, Vector3.new(0, ty * 0.3, -look.Torso.Z * s * 0.52), Vector3.new(0, 0, -1), 0.55 * s, look.Star)

	-- Head with eyes, forehead star and the gold pin.
	local head = part(model, { Name = "Head", Size = look.Head * s, Color = look.HeadColor or look.Body, Ellipsoid = true })
	attach(torso, head, CFrame.new(0, ty + look.Head.Y * s * 0.45, -0.05 * s))
	local hy = look.Head.Y * s
	for _, side in ipairs({ -1, 1 }) do
		local eye = part(model, { Name = "Eye", Size = Vector3.new(0.22, 0.14, 0.08) * s, Color = look.Eye, Material = Enum.Material.Neon, Ellipsoid = true })
		attach(head, eye, CFrame.new(side * 0.2 * s, 0.02 * s, -look.Head.Z * s * 0.47) * CFrame.Angles(0, 0, side * -0.25))
	end
	star(model, head, Vector3.new(0, hy * 0.32, -look.Head.Z * s * 0.42), Vector3.new(0, 0.5, -1).Unit, 0.4 * s, look.Star)
	-- Head fins (animated like Act 1's ears).
	for _, e in ipairs({ { "EarL", -1 }, { "EarR", 1 } }) do
		local base = CFrame.new(e[2] * look.Head.X * s * 0.45, hy * 0.25, 0.05 * s) * CFrame.Angles(0, 0, -e[2] * 1.1)
		local fin = part(model, { Name = e[1], Size = Vector3.new(0.22, 0.8, 0.08) * s, Color = look.Trim, Ellipsoid = true })
		local offset = CFrame.new(0, 0.35 * s, 0)
		local w = attach(head, fin, base * offset)
		rig.Joints[e[1]] = { Weld = w, Base = base, Offset = offset }
	end

	-- Shoulders and arms.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local shoulderPos = CFrame.new(a[2] * (look.Torso.X * s * 0.5 + 0.1 * s), ty * 0.7, 0)
		local pad = part(model, { Name = "Shoulder", Size = Vector3.new(0.6, 0.5, 0.6) * s * look.ArmThickness * 3, Color = look.Trim, Material = look.TrimMaterial or Enum.Material.SmoothPlastic, Ellipsoid = true })
		attach(torso, pad, shoulderPos)
		local _, hand = limb(model, torso, rig, a[1], shoulderPos * CFrame.Angles(0, 0, a[2] * 0.15), look.ArmLength * s, look.ArmThickness * s, look.Body, look.Trim)
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Lower body: legs (Act 4) or a swirling tail (Act 3).
	if look.Legs then
		for i, side in ipairs({ -1, 1 }) do
			local base = CFrame.new(side * look.Torso.X * s * 0.25, -ty * 0.85, 0)
			limb(model, torso, rig, "Leg" .. i, base, look.LegLength * s, look.ArmThickness * 1.3 * s, look.Body, look.Trim)
		end
	else
		local y = -ty * 0.9
		for i = 1, 4 do
			local size = Vector3.new(look.Torso.X * (0.8 - i * 0.16), 0.9, look.Torso.Z * (0.8 - i * 0.16)) * s
			local seg = part(model, { Name = "Tail", Size = size, Color = i % 2 == 0 and look.Trim or look.Body, Ellipsoid = true })
			attach(torso, seg, CFrame.new(math.sin(i * 1.3) * 0.25 * s, y, math.cos(i * 1.3) * 0.2 * s) * CFrame.Angles(0, i * 0.6, 0.15 * i))
			y = y - 0.55 * s
		end
	end

	-- Scattered stars on the torso.
	for _, spot in ipairs({ Vector3.new(0.45, -0.3, -0.35), Vector3.new(-0.45, 0.1, -0.35), Vector3.new(0.3, 0.4, 0.4), Vector3.new(-0.35, -0.4, 0.4) }) do
		star(model, torso, Vector3.new(spot.X * look.Torso.X, spot.Y * look.Torso.Y, spot.Z * look.Torso.Z) * s * 1.05, Vector3.new(spot.X, 0, spot.Z).Unit, 0.22 * s, look.Star)
	end
	return model, rig
end

local function buildAct3(scale)
	return buildHumanoid("TuskAct3", scale, {
		Torso = Vector3.new(1.3, 1.7, 0.9),
		Head = Vector3.new(0.95, 1.05, 0.95),
		Body = Color3.fromRGB(196, 96, 190),
		HeadColor = Color3.fromRGB(236, 170, 220),
		Trim = Color3.fromRGB(40, 50, 130),
		Star = colors.Star,
		Eye = Color3.fromRGB(120, 200, 255),
		ArmLength = 1.1,
		ArmThickness = 0.2,
		Legs = false,
	})
end

local function buildAct4(scale)
	return buildHumanoid("TuskAct4", scale * 1.15, {
		Torso = Vector3.new(1.8, 2.1, 1.1),
		Head = Vector3.new(1, 1.1, 1),
		Body = Color3.fromRGB(70, 56, 150),
		HeadColor = Color3.fromRGB(200, 120, 210),
		Trim = colors.Gold,
		TrimMaterial = Enum.Material.Metal,
		Star = colors.GoldLight,
		Eye = Color3.fromRGB(110, 230, 255),
		ArmLength = 1.4,
		ArmThickness = 0.3,
		Legs = true,
		LegLength = 1.6,
	})
end

local builders = {
	[1] = buildAct1,
	[2] = buildAct2,
	[3] = buildAct3,
	[4] = buildAct4,
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
