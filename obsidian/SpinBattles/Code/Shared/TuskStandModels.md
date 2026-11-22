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

-- Thin isosceles triangle from two mirrored WedgeParts. Lies in the plane
-- whose normal is `normal`; apex points along `dir`.
local function triangle(model, parent, base, normal, dir, height, width, thickness, color)
	local n = normal.Unit
	local up = (dir - n * dir:Dot(n)).Unit
	local frame = CFrame.fromMatrix(base, n, up) -- X = normal, Y = toward the apex
	for _, side in ipairs({ -1, 1 }) do
		local w = Instance.new("WedgePart")
		w.Name = "StarPoint"
		w.Anchored = false
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.CastShadow = false
		w.Massless = true
		w.Material = Enum.Material.SmoothPlastic
		w.Color = color
		w.Size = Vector3.new(thickness, height, width / 2)
		local cf = frame * CFrame.new(0, height / 2, side * width / 4)
		if side > 0 then
			cf = cf * CFrame.Angles(0, math.pi, 0) -- mirror so both halves meet on the centre line
		end
		w.Parent = model
		attach(parent, w, parent.CFrame:Inverse() * cf)
	end
end

-- Proper five-pointed star (pentagon centre + five triangle points) on a surface.
local function star5(model, parent, center, normal, size, color, spin)
	local n = normal.Unit
	local helper = math.abs(n.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local u = (helper - n * helper:Dot(n)).Unit
	local v = n:Cross(u)
	local world = parent.CFrame * center
	local worldN = parent.CFrame:VectorToWorldSpace(n)
	local worldU = parent.CFrame:VectorToWorldSpace(u)
	local worldV = parent.CFrame:VectorToWorldSpace(v)
	local core = part(model, { Name = "StarCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(size * 0.06, size * 0.42, size * 0.42), Color = color })
	attach(parent, core, parent.CFrame:Inverse() * CFrame.fromMatrix(world, worldN, worldU))
	for i = 0, 4 do
		local a = (spin or 0) + i * math.pi * 2 / 5
		local dir = worldU * math.cos(a) + worldV * math.sin(a)
		triangle(model, parent, world + dir * size * 0.17, worldN, dir, size * 0.36, size * 0.26, size * 0.06, color)
	end
end

-- Tapered cone made of stacked cylinders, pointing along `dir` (parent space).
local function cone(model, parent, base, dir, length, radius, color, material)
	dir = dir.Unit
	local steps = 4
	for i = 0, steps - 1 do
		local segLen = length / steps
		local r = radius * (1 - i / steps)
		local c = base + dir * (segLen * (i + 0.5))
		local seg = part(model, { Name = "Cone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(segLen * 1.05, r * 2, r * 2), Color = color, Material = material or Enum.Material.SmoothPlastic })
		local up = math.abs(dir.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
		attach(parent, seg, CFrame.fromMatrix(c, dir, dir:Cross(up).Unit:Cross(dir)))
	end
	local tip = part(model, { Name = "ConeTip", Size = Vector3.new(radius * 0.5, radius * 0.5, radius * 0.5), Color = color, Ellipsoid = true })
	attach(parent, tip, CFrame.new(base + dir * length))
end

-- Point on the surface of an axis-aligned ellipsoid (half sizes `h`) toward `dir`.
local function onSurface(h, dir, push)
	local d = dir.Unit
	local k = 1 / math.sqrt((d.X / h.X) ^ 2 + (d.Y / h.Y) ^ 2 + (d.Z / h.Z) ^ 2)
	return d * k * (push or 1)
end

---------------------------------------------------------------------------
-- ACT 1 (from the owner's two reference images)
---------------------------------------------------------------------------
local function buildAct1Classic(scale)
	local s = scale
	local pink = Color3.fromRGB(236, 120, 200)
	local pinkLight = Color3.fromRGB(250, 170, 225)
	local pinkDark = Color3.fromRGB(176, 60, 140)
	local starColor = Color3.fromRGB(255, 182, 52)
	local gold = Color3.fromRGB(240, 190, 70)
	local heart = Color3.fromRGB(190, 36, 96)

	local model = Instance.new("Model")
	model.Name = "TuskAct1"
	local bodySize = Vector3.new(1.65, 2.5, 1.5) * s
	local h = bodySize / 2
	local body = part(model, { Name = "Body", Size = bodySize, Color = pink, Ellipsoid = true, Massless = false })
	-- Leans to its right and tips forward a little, like the drawings.
	body.CFrame = CFrame.Angles(0.12, 0, -0.2)
	body.Anchored = true
	model.PrimaryPart = body
	local rig = { Body = body, Joints = {} }

	-- Two-tone shading: lighter forehead, darker lower half.
	local cap = part(model, { Name = "Highlight", Size = bodySize * Vector3.new(0.78, 0.55, 0.72), Color = pinkLight, Ellipsoid = true })
	attach(body, cap, CFrame.new(0.12 * s, 0.42 * s, -0.22 * s))
	local belly = part(model, { Name = "Belly", Size = bodySize * Vector3.new(0.92, 0.6, 0.94), Color = pinkDark, Ellipsoid = true })
	attach(body, belly, CFrame.new(0.04 * s, -0.42 * s, 0.02 * s))
	-- Pointed bottom: the egg narrows down toward the heart legs.
	local tip = part(model, { Name = "LowerTip", Size = Vector3.new(0.9, 1.0, 0.85) * s, Color = pinkDark, Ellipsoid = true })
	attach(body, tip, CFrame.new(-0.05 * s, -1.05 * s, 0.05 * s))

	-- Long chin / snout below the face, with little gold spikes.
	local chin = part(model, { Name = "Chin", Size = Vector3.new(0.95, 1.15, 0.95) * s, Color = pink, Ellipsoid = true })
	attach(body, chin, CFrame.new(-0.22 * s, -0.78 * s, -0.28 * s) * CFrame.Angles(0.35, 0, -0.25))
	for i = 1, 3 do
		cone(model, body, Vector3.new(-(0.22 + i * 0.12) * s, (-1.05 - i * 0.04) * s, (-0.55 + i * 0.05) * s), Vector3.new(-0.6, -0.5, -0.6), 0.22 * s, 0.05 * s, gold, Enum.Material.Metal)
	end
	local mouth = part(model, { Name = "Mouth", Size = Vector3.new(0.55, 0.22, 0.2) * s, Color = Color3.fromRGB(90, 20, 50), Ellipsoid = true })
	attach(body, mouth, CFrame.new(-0.15 * s, -0.42 * s, -0.66 * s) * CFrame.Angles(0, 0, 0.25))

	-- Big forehead star with spiky dark fur around it.
	local starDir = Vector3.new(0.42, 0.62, -0.66)
	local starPos = onSurface(h, starDir, 1.02)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local n = starDir.Unit
		local helper = Vector3.new(0, 1, 0)
		local u = (helper - n * helper:Dot(n)).Unit
		local v = n:Cross(u)
		local dir = u * math.cos(a) + v * math.sin(a)
		local fur = part(model, { Name = "Fur", Size = Vector3.new(0.03, 0.03, 0.34) * s, Color = Color3.fromRGB(60, 20, 45) })
		local p = starPos + dir * 0.3 * s
		attach(body, fur, CFrame.lookAt(p, p + dir))
	end
	star5(model, body, starPos + starDir.Unit * 0.02 * s, starDir, 1.15 * s, starColor, 0.3)

	-- Eyes: white, black pupil, heavy pink lid, lashes, and wavy tendrils.
	local eyes = { { Vector3.new(0.38, 0.02, -1), -1 }, { Vector3.new(-0.3, -0.06, -1), 1 } }
	for _, e in ipairs(eyes) do
		local pos = onSurface(h, e[1], 0.98)
		local eye = part(model, { Name = "Eye", Size = Vector3.new(0.34, 0.3, 0.2) * s, Color = Color3.fromRGB(250, 248, 240), Ellipsoid = true })
		attach(body, eye, CFrame.new(pos))
		local pupil = part(model, { Name = "Pupil", Size = Vector3.new(0.15, 0.15, 0.06) * s, Color = Color3.fromRGB(25, 15, 20), Ellipsoid = true })
		attach(body, pupil, CFrame.new(pos + Vector3.new(0, -0.03 * s, -0.1 * s)))
		local shine = part(model, { Name = "Shine", Size = Vector3.new(0.05, 0.05, 0.02) * s, Color = Color3.new(1, 1, 1), Ellipsoid = true })
		attach(body, shine, CFrame.new(pos + Vector3.new(0.03 * s, 0.01 * s, -0.13 * s)))
		local lid = part(model, { Name = "Lid", Size = Vector3.new(0.44, 0.22, 0.26) * s, Color = pinkDark, Ellipsoid = true })
		attach(body, lid, CFrame.new(pos + Vector3.new(0, 0.1 * s, -0.02 * s)) * CFrame.Angles(0, 0, e[2] * 0.3))
		for l = -1, 1 do
			local lash = part(model, { Name = "Lash", Size = Vector3.new(0.025, 0.16, 0.025) * s, Color = Color3.fromRGB(40, 10, 30) })
			attach(body, lash, CFrame.new(pos + Vector3.new(l * 0.11 * s, 0.2 * s, -0.08 * s)) * CFrame.Angles(0, 0, l * 0.5))
		end
		-- Wavy pink tendril from the outer corner of each eye.
		local outward = -e[2]
		local prev = pos + Vector3.new(outward * 0.2 * s, 0, 0)
		for k = 1, 3 do
			local nextP = prev + Vector3.new(outward * 0.18 * s, (k % 2 == 0 and 0.08 or -0.06) * s, 0.02 * s)
			local seg = part(model, { Name = "Tendril", Size = Vector3.new(0.09, 0.09, 0.24) * s, Color = pinkLight, Ellipsoid = true })
			attach(body, seg, CFrame.lookAt((prev + nextP) / 2, nextP))
			prev = nextP
		end
	end

	-- Gold beak (a cone) pointing forward-down, and the gold pin from the star to its tip.
	local beakBase = onSurface(h, Vector3.new(-0.06, -0.12, -1), 0.95)
	local beakDir = Vector3.new(-0.35, -0.5, -0.8).Unit
	local beakLen = 0.6 * s
	cone(model, body, beakBase, beakDir, beakLen, 0.13 * s, gold, Enum.Material.Metal)
	local beakTip = beakBase + beakDir * beakLen
	local pinVec = beakTip - starPos
	local pin = part(model, { Name = "Pin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(pinVec.Magnitude, 0.035 * s, 0.035 * s), Color = gold, Material = Enum.Material.Metal, Reflectance = 0.3 })
	local mid = (starPos + beakTip) / 2
	attach(body, pin, CFrame.lookAt(mid, beakTip) * CFrame.Angles(0, math.pi / 2, 0))
	local pinHead = part(model, { Name = "PinHead", Size = Vector3.new(0.09, 0.09, 0.09) * s, Color = gold, Material = Enum.Material.Metal, Ellipsoid = true })
	attach(body, pinHead, CFrame.new(starPos + starDir.Unit * 0.04 * s))

	-- Orange stars all over the body.
	local spots = {
		Vector3.new(0.7, 0.55, -0.3), Vector3.new(0.85, 0.05, -0.2), Vector3.new(-0.9, 0.15, -0.1), Vector3.new(-0.7, -0.45, -0.35),
		Vector3.new(0.6, -0.55, -0.5), Vector3.new(0.15, 0.95, 0.2), Vector3.new(-0.35, 0.45, 0.8), Vector3.new(0.45, 0.2, 0.85),
		Vector3.new(-0.1, -0.7, 0.7), Vector3.new(-0.55, -0.15, -0.8), Vector3.new(0.3, 0.7, -0.6), Vector3.new(-0.8, 0.6, 0.3),
		Vector3.new(0.9, -0.35, 0.2), Vector3.new(-0.5, -0.8, -0.2), Vector3.new(0.65, 0.9, 0.1), Vector3.new(-0.95, -0.4, 0.3),
		Vector3.new(0.2, -0.9, -0.4), Vector3.new(0.95, 0.4, 0.4),
	}
	for i, d in ipairs(spots) do
		local p = onSurface(h, d, 1.01)
		star5(model, body, p, d, (0.26 + (i % 3) * 0.04) * s, starColor, i)
	end

	-- Ears: a huge floppy ear sweeping up (its left), a smaller one drooping (its right). Animated.
	local ears = {
		-- Right ear sweeps up and out; left ear droops down beside the face.
		{ Name = "EarL", Base = CFrame.new(-0.5 * s, 0.9 * s, 0.1 * s) * CFrame.Angles(0.25, -0.3, 1.15), Size = Vector3.new(0.6, 1.8, 0.13) },
		{ Name = "EarR", Base = CFrame.new(0.7 * s, 0.75 * s, 0.05 * s) * CFrame.Angles(-0.1, 0.25, -1.35), Size = Vector3.new(0.5, 1.4, 0.13) },
	}
	for _, e in ipairs(ears) do
		local ear = part(model, { Name = e.Name, Size = e.Size * s, Color = pink, Ellipsoid = true })
		local inner = part(model, { Name = e.Name .. "Inner", Size = e.Size * s * Vector3.new(0.6, 0.8, 0.5), Color = pinkDark, Ellipsoid = true })
		local offset = CFrame.new(0, e.Size.Y * s * 0.45, 0)
		local w = attach(body, ear, e.Base * offset)
		attach(ear, inner, CFrame.new(0, 0, -0.035 * s))
		rig.Joints[e.Name] = { Weld = w, Base = e.Base, Offset = offset }
	end
	-- Small spike on top of the head.
	local topSpike = part(model, { Name = "TopSpike", Size = Vector3.new(0.18, 0.45, 0.14) * s, Color = pink, Ellipsoid = true })
	attach(body, topSpike, CFrame.new(-0.05 * s, 1.15 * s, 0.1 * s))

	-- Tattered pink fins around the silhouette.
	local fins = {
		CFrame.new(-0.82 * s, 0.25 * s, -0.2 * s) * CFrame.Angles(0, 0, 1.3),
		CFrame.new(0.86 * s, 0.32 * s, -0.25 * s) * CFrame.Angles(0, 0, -1.2),
		CFrame.new(-0.78 * s, -0.35 * s, -0.25 * s) * CFrame.Angles(0, 0, 2.0),
		CFrame.new(0.7 * s, -0.7 * s, -0.4 * s) * CFrame.Angles(0, 0, -2.2),
		CFrame.new(-0.4 * s, -0.95 * s, -0.4 * s) * CFrame.Angles(0, 0, 2.7),
	}
	for _, cf in ipairs(fins) do
		for k = 0, 1 do
			local fin = part(model, { Name = "Fin", Size = Vector3.new(0.14, 0.42 - k * 0.12, 0.07) * s, Color = k == 0 and pink or pinkLight, Ellipsoid = true })
			attach(body, fin, cf * CFrame.new(k * 0.07 * s, (0.18 + k * 0.1) * s, 0) * CFrame.Angles(0, 0, k * 0.4))
		end
	end

	-- Side appendage (its left) with a gold horn and a star.
	local side = part(model, { Name = "SideHand", Size = Vector3.new(0.75, 0.5, 0.45) * s, Color = pink, Ellipsoid = true })
	attach(body, side, CFrame.new(-1.0 * s, -0.2 * s, -0.1 * s) * CFrame.Angles(0, 0, 0.4))
	cone(model, body, Vector3.new(-1.32 * s, -0.08 * s, -0.1 * s), Vector3.new(-1, 0.5, -0.2), 0.3 * s, 0.07 * s, gold, Enum.Material.Metal)
	star5(model, body, Vector3.new(-1.02 * s, -0.12 * s, -0.33 * s), Vector3.new(-0.2, 0.1, -1), 0.22 * s, starColor, 0.5)

	-- Five thin legs ending in hearts (four animated).
	local legX = { -0.34, -0.15, 0.04, 0.22, 0.4 }
	for i = 1, 5 do
		local base = CFrame.new(legX[i] * s, -1.4 * s, (i % 2 == 0 and 0.12 or -0.12) * s)
		local legLength = (0.55 + ((i * 7) % 4) * 0.1) * s
		local leg = part(model, { Name = "Leg" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(legLength, 0.06 * s, 0.06 * s), Color = pinkDark })
		local offset = CFrame.new(0, -legLength / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local w = attach(body, leg, base * offset)
		if i <= 4 then
			rig.Joints["Leg" .. i] = { Weld = w, Base = base, Offset = offset }
		end
		-- Heart: two lobes and a point, facing forward.
		local footCF = CFrame.new(-legLength / 2 - 0.16 * s, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2)
		for _, sx in ipairs({ -1, 1 }) do
			local lobe = part(model, { Name = "HeartLobe", Size = Vector3.new(0.24, 0.24, 0.12) * s, Color = heart, Ellipsoid = true })
			attach(leg, lobe, footCF * CFrame.new(sx * 0.09 * s, 0.05 * s, 0))
		end
		local point = part(model, { Name = "HeartPoint", Size = Vector3.new(0.22, 0.22, 0.1) * s, Color = heart })
		attach(leg, point, footCF * CFrame.new(0, -0.07 * s, 0) * CFrame.Angles(0, 0, math.pi / 4))
	end

	local nailPoint = Instance.new("Attachment")
	nailPoint.Name = "NailPoint"
	nailPoint.Position = beakTip
	nailPoint.Parent = body
	rig.NailPoint = nailPoint
	return model, rig
end

---------------------------------------------------------------------------
-- ACT 2 (from the owner's reference images): a pink mechanical Stand with
-- a ribbed visor face, a blue star, a big dotted pod, a pincer claw and two
-- gold rods ending in purple drums.
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
	local s = scale * 1.1
	local pink = Color3.fromRGB(240, 150, 214)
	local pinkDark = Color3.fromRGB(196, 100, 176)
	local gold = Color3.fromRGB(232, 182, 70)
	local purple = Color3.fromRGB(86, 64, 132)
	local purpleRim = Color3.fromRGB(160, 140, 200)
	local blueStar = Color3.fromRGB(120, 200, 245)
	local yellow = Color3.fromRGB(255, 210, 70)

	local model = Instance.new("Model")
	model.Name = "TuskAct2"
	local torso = part(model, { Name = "Body", Size = Vector3.new(1.2, 1.3, 0.95) * s, Color = pink, Ellipsoid = true, Massless = false })
	torso.CFrame = CFrame.Angles(0.15, 0, -0.15)
	torso.Anchored = true
	model.PrimaryPart = torso
	local rig = { Body = torso, Joints = {} }

	-- Ribbed chest (gills).
	for i = -2, 2 do
		local rib = part(model, { Name = "Rib", Size = Vector3.new(0.08, 0.75, 0.1) * s, Color = pinkDark })
		attach(torso, rib, CFrame.new(i * 0.16 * s, -0.05 * s, -0.44 * s) * CFrame.Angles(0, i * 0.15, 0))
	end
	local belt = part(model, { Name = "Belt", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 1.05, 1.05) * s, Color = gold, Material = Enum.Material.Metal })
	attach(torso, belt, CFrame.new(0, -0.55 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))

	-- Head: round, with a ribbed visor face and a blue star.
	local head = part(model, { Name = "Head", Size = Vector3.new(1.15, 1.1, 1.1) * s, Color = pink, Ellipsoid = true })
	attach(torso, head, CFrame.new(-0.05 * s, 1.05 * s, -0.05 * s))
	local hcf = CFrame.new(-0.05 * s, 1.05 * s, -0.05 * s)
	local visor = part(model, { Name = "Visor", Size = Vector3.new(0.5, 0.72, 0.2) * s, Color = Color3.fromRGB(70, 30, 70), Ellipsoid = true })
	attach(torso, visor, hcf * CFrame.new(0, -0.05 * s, -0.47 * s))
	for i = -1, 1 do
		local bar = part(model, { Name = "VisorBar", Size = Vector3.new(0.07, 0.68, 0.08) * s, Color = pinkDark })
		attach(torso, bar, hcf * CFrame.new(i * 0.13 * s, -0.05 * s, -0.56 * s))
	end
	for _, side in ipairs({ -1, 1 }) do
		local cheek = part(model, { Name = "Cheek", Size = Vector3.new(0.28, 0.28, 0.16) * s, Color = pinkDark, Ellipsoid = true })
		attach(torso, cheek, hcf * CFrame.new(side * 0.36 * s, -0.18 * s, -0.4 * s))
		local earDisc = part(model, { Name = "EarDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.45, 0.45) * s, Color = gold, Material = Enum.Material.Metal })
		attach(torso, earDisc, hcf * CFrame.new(side * 0.57 * s, 0.05 * s, 0))
	end
	star5(model, torso, (hcf * CFrame.new(0.3 * s, 0.3 * s, -0.38 * s)).Position, Vector3.new(0.4, 0.4, -1), 0.4 * s, blueStar, 0.2)

	-- Two gold rods from the back, each ending in a purple drum (animated like ears).
	for _, d in ipairs({ { "EarL", -1 }, { "EarR", 1 } }) do
		local base = CFrame.new(d[2] * 0.35 * s, 0.55 * s, 0.4 * s) * CFrame.Angles(-0.35, 0, -d[2] * 0.75)
		local rodLength = 1.5 * s
		local rod = part(model, { Name = d[1], Shape = Enum.PartType.Cylinder, Size = Vector3.new(rodLength, 0.1 * s, 0.1 * s), Color = gold, Material = Enum.Material.Metal })
		local offset = CFrame.new(0, rodLength / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local w = attach(torso, rod, base * offset)
		rig.Joints[d[1]] = { Weld = w, Base = base, Offset = offset }
		-- Drum at the far end of the rod (rod axis = its X axis, pointing "up").
		local drum = part(model, { Name = "Drum", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.28, 0.75, 0.75) * s, Color = purple, Material = Enum.Material.Metal })
		attach(rod, drum, CFrame.new(rodLength / 2 + 0.1 * s, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))
		local rim = part(model, { Name = "DrumRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.82, 0.82) * s, Color = purpleRim, Material = Enum.Material.Metal })
		attach(rod, rim, CFrame.new(rodLength / 2 + 0.1 * s, 0, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(-0.02 * s, 0, 0))
		local hole = part(model, { Name = "DrumHole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.32, 0.32, 0.32) * s, Color = Color3.fromRGB(30, 20, 40) })
		attach(rod, hole, CFrame.new(rodLength / 2 + 0.1 * s, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))
	end

	-- Arms: right arm reaches out with a pincer claw; left arm tucked.
	local shoulderR = CFrame.new(0.68 * s, 0.35 * s, -0.05 * s) * CFrame.Angles(1.1, 0, 0.5)
	local _, handR = limb(model, torso, rig, "ArmR", shoulderR, 1.1 * s, 0.2 * s, pink, gold)
	for _, side in ipairs({ -1, 1 }) do
		local prong = part(model, { Name = "Claw", Size = Vector3.new(0.09, 0.4, 0.12) * s, Color = pinkDark })
		attach(handR, prong, CFrame.new(side * 0.1 * s, -0.25 * s, 0) * CFrame.Angles(0, 0, side * 0.35))
	end
	local shoulderL = CFrame.new(-0.68 * s, 0.35 * s, 0) * CFrame.Angles(0.4, 0, -0.35)
	limb(model, torso, rig, "ArmL", shoulderL, 0.95 * s, 0.2 * s, pink, gold)
	for _, side in ipairs({ -1, 1 }) do
		local pad = part(model, { Name = "ShoulderPad", Size = Vector3.new(0.45, 0.4, 0.45) * s, Color = pinkDark, Ellipsoid = true })
		attach(torso, pad, CFrame.new(side * 0.66 * s, 0.4 * s, 0))
	end

	-- Big dotted pod (lower body) with a yellow-and-blue star.
	local podCF = CFrame.new(0.2 * s, -1.25 * s, -0.15 * s)
	local pod = part(model, { Name = "Pod", Size = Vector3.new(1.55, 1.35, 1.45) * s, Color = pink, Ellipsoid = true })
	attach(torso, pod, podCF)
	local golden = math.pi * (3 - math.sqrt(5))
	for i = 0, 13 do
		local y = 1 - (i + 0.5) / 14 * 2
		local ring = math.sqrt(1 - y * y)
		local dir = Vector3.new(math.cos(i * golden) * ring, y, math.sin(i * golden) * ring)
		if dir.Z < 0.4 then
			local p = podCF.Position + onSurface(Vector3.new(0.775, 0.675, 0.725) * s, dir, 0.99)
			local hole = part(model, { Name = "PodHole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 0.13, 0.13) * s, Color = Color3.fromRGB(120, 50, 100) })
			local up = math.abs(dir.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
			attach(torso, hole, CFrame.fromMatrix(p, dir.Unit, dir.Unit:Cross(up).Unit:Cross(dir.Unit)))
		end
	end
	local starAt = podCF.Position + onSurface(Vector3.new(0.775, 0.675, 0.725) * s, Vector3.new(0.6, -0.1, -0.8), 1.01)
	star5(model, torso, starAt, Vector3.new(0.6, -0.1, -0.8), 0.6 * s, yellow, 0.3)
	star5(model, torso, starAt + Vector3.new(0.6, -0.1, -0.8).Unit * 0.02 * s, Vector3.new(0.6, -0.1, -0.8), 0.38 * s, blueStar, 0.3)

	rig.NailPoint = Instance.new("Attachment")
	rig.NailPoint.Name = "NailPoint"
	rig.NailPoint.Parent = handR
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

-- Extend a limb: segment hanging further "down" the limb from `from` (a part
-- whose local -X runs along the limb, like limb()'s hand). Returns the end joint.
local function segment(model, from, length, thickness, color, bend, jointColor)
	local joint = part(model, { Name = "Joint", Size = Vector3.new(thickness * 1.35, thickness * 1.35, thickness * 1.35), Color = jointColor or color, Material = jointColor and Enum.Material.Metal or Enum.Material.SmoothPlastic, Ellipsoid = true })
	attach(from, joint, CFrame.new())
	local seg = part(model, { Name = "Segment", Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, thickness, thickness), Color = color })
	local cf = CFrame.Angles(0, 0, bend or 0) * CFrame.new(-length / 2, 0, 0)
	attach(from, seg, cf)
	local tip = part(model, { Name = "Tip", Size = Vector3.new(thickness, thickness, thickness), Color = color, Ellipsoid = true })
	attach(from, tip, CFrame.Angles(0, 0, bend or 0) * CFrame.new(-length, 0, 0))
	return tip
end

-- Three long metal spikes fanning out from a part, along its local -X.
local function spikes(model, from, length, color)
	for i = -1, 1 do
		cone(model, from, Vector3.new(0, 0, i * 0.06), Vector3.new(-1, 0, i * 0.18), length, 0.045, color, Enum.Material.Metal)
	end
end

---------------------------------------------------------------------------
-- ACT 3 (from the owner's reference images): big pink bean body with a
-- dark crest, antennae, a slotted face mask, blue shoulder balls with red
-- stars, a purple belly lens, thin limbs with ball joints and spiked claws.
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- ACT 1 "Mascot" (owner's written description): a small, toy-like blue and
-- cyan humanoid with a big round head, big eyes, mechanical seams, pink
-- accents, short arms and legs, and cyan Spin sparkles on its hands.
---------------------------------------------------------------------------
local function sparkles(parent, color)
	local a = Instance.new("Attachment")
	a.Name = "SpinSparkles"
	a.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 7
	e.Parent = a
	return e
end

local function buildAct1Mascot(scale)
	local s = scale
	local blue = Color3.fromRGB(46, 120, 214)
	local cyan = Color3.fromRGB(90, 214, 250)
	local light = Color3.fromRGB(196, 240, 255)
	local navy = Color3.fromRGB(26, 52, 120)
	local pink = Color3.fromRGB(246, 120, 190)
	local steel = Color3.fromRGB(170, 185, 200)

	local model = Instance.new("Model")
	model.Name = "TuskAct1"
	-- Small torso is the root; the big head sits on top (animated).
	local torso = part(model, { Name = "Body", Size = Vector3.new(0.85, 0.9, 0.7) * s, Color = blue, Ellipsoid = true, Massless = false })
	torso.CFrame = CFrame.new()
	torso.Anchored = true
	model.PrimaryPart = torso
	local rig = { Body = torso, Joints = {} }

	local chest = part(model, { Name = "ChestPlate", Size = Vector3.new(0.6, 0.55, 0.2) * s, Color = light, Ellipsoid = true })
	attach(torso, chest, CFrame.new(0, 0.05 * s, -0.27 * s))
	star5(model, torso, Vector3.new(0, 0.06 * s, -0.38 * s), Vector3.new(0, 0, -1), 0.32 * s, pink, 0)
	local belt = part(model, { Name = "Belt", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.78, 0.78) * s, Color = navy, Material = Enum.Material.Metal })
	attach(torso, belt, CFrame.new(0, -0.3 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))

	-- Head: a separate welded group so it can tilt and look around.
	local headBase = CFrame.new(0, 0.95 * s, -0.02 * s)
	local head = part(model, { Name = "Head", Size = Vector3.new(1.45, 1.35, 1.35) * s, Color = cyan, Ellipsoid = true })
	local headWeld = attach(torso, head, headBase)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = CFrame.new() }
	local face = part(model, { Name = "Face", Size = Vector3.new(1.15, 0.95, 0.5) * s, Color = light, Ellipsoid = true })
	attach(head, face, CFrame.new(0, -0.08 * s, -0.47 * s))
	-- Mechanical seam ring and side bolts.
	local seam = part(model, { Name = "Seam", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 1.47, 1.47) * s, Color = navy, Material = Enum.Material.Metal })
	attach(head, seam, CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0))
	for _, side in ipairs({ -1, 1 }) do
		local bolt = part(model, { Name = "Bolt", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 0.3, 0.3) * s, Color = steel, Material = Enum.Material.Metal })
		attach(head, bolt, CFrame.new(side * 0.72 * s, 0.02 * s, 0))
		local cheek = part(model, { Name = "Cheek", Size = Vector3.new(0.18, 0.11, 0.05) * s, Color = pink, Ellipsoid = true })
		attach(head, cheek, CFrame.new(side * 0.36 * s, -0.3 * s, -0.66 * s))
	end
	-- Antenna with a pink star ball.
	local antenna = part(model, { Name = "Antenna", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 0.05, 0.05) * s, Color = navy, Material = Enum.Material.Metal })
	attach(head, antenna, CFrame.new(0.15 * s, 0.82 * s, 0) * CFrame.Angles(0, 0, math.pi / 2 - 0.3))
	local bulb = part(model, { Name = "AntennaBall", Size = Vector3.new(0.18, 0.18, 0.18) * s, Color = pink, Material = Enum.Material.Neon, Ellipsoid = true })
	attach(head, bulb, CFrame.new(0.21 * s, 1.02 * s, 0))
	-- Big, slightly mismatched toy eyes.
	for _, e in ipairs({ { -1, 0.42 }, { 1, 0.38 } }) do
		local eyePos = CFrame.new(e[1] * 0.3 * s, 0.08 * s, -0.62 * s)
		local white = part(model, { Name = "Eye", Size = Vector3.new(0.4, e[2] * 1.15, 0.2) * s, Color = Color3.new(1, 1, 1), Ellipsoid = true })
		attach(head, white, eyePos)
		local pupil = part(model, { Name = "Pupil", Size = Vector3.new(0.25, e[2] * 0.75, 0.08) * s, Color = Color3.fromRGB(15, 20, 45), Ellipsoid = true })
		attach(head, pupil, eyePos * CFrame.new(e[1] * -0.03 * s, -0.02 * s, -0.08 * s))
		local glint = part(model, { Name = "Glint", Size = Vector3.new(0.08, 0.08, 0.03) * s, Color = Color3.new(1, 1, 1), Ellipsoid = true })
		attach(head, glint, eyePos * CFrame.new(0.05 * s, 0.07 * s, -0.12 * s))
		local rim = part(model, { Name = "EyeRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 0.46, 0.46) * s, Color = navy, Material = Enum.Material.Metal })
		attach(head, rim, eyePos * CFrame.new(0, 0, 0.02 * s) * CFrame.Angles(0, math.pi / 2, 0))
	end
	local mouth = part(model, { Name = "Mouth", Size = Vector3.new(0.2, 0.07, 0.04) * s, Color = pink, Ellipsoid = true })
	attach(head, mouth, CFrame.new(0, -0.38 * s, -0.66 * s))

	-- Short arms (animated) with round hands and cyan Spin sparkles.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local shoulder = CFrame.new(a[2] * 0.45 * s, 0.22 * s, 0) * CFrame.Angles(0, 0, a[2] * 0.45)
		local _, hand = limb(model, torso, rig, a[1], shoulder, 0.5 * s, 0.2 * s, cyan, light)
		hand.Size = Vector3.new(0.3, 0.3, 0.3) * s
		local pad = part(model, { Name = "ElbowPad", Size = Vector3.new(0.22, 0.22, 0.22) * s, Color = pink, Ellipsoid = true })
		attach(torso, pad, shoulder)
		sparkles(hand, cyan)
		if a[1] == "ArmR" then
			rig.NailPoint = Instance.new("Attachment")
			rig.NailPoint.Name = "NailPoint"
			rig.NailPoint.Parent = hand
		end
	end
	-- Short stubby legs (animated) with navy boots.
	for i, side in ipairs({ -1, 1 }) do
		local hip = CFrame.new(side * 0.2 * s, -0.4 * s, 0)
		local _, foot = limb(model, torso, rig, "Leg" .. i, hip, 0.4 * s, 0.22 * s, blue, navy)
		foot.Size = Vector3.new(0.3, 0.26, 0.4) * s
	end
	return model, rig
end

-- Act 1 has two looks: "Mascot" (default) or "Classic" (the pink star
-- creature from the drawings). Switch in TuskConfig.StandModels[1].Style.
local function buildAct1(scale)
	local settings = TuskConfig.StandModels and TuskConfig.StandModels[1] or {}
	if settings.Style == "Classic" then
		return buildAct1Classic(scale)
	end
	return buildAct1Mascot(scale)
end

local function buildAct3(scale)
	local s = scale * 1.15
	local pink = Color3.fromRGB(226, 110, 178)
	local pinkDark = Color3.fromRGB(170, 70, 135)
	local navy = Color3.fromRGB(44, 52, 120)
	local blue = Color3.fromRGB(70, 90, 190)
	local lens = Color3.fromRGB(96, 92, 190)
	local steel = Color3.fromRGB(150, 155, 165)
	local red = Color3.fromRGB(210, 60, 40)
	local yellow = Color3.fromRGB(255, 200, 60)
	local starGold = Color3.fromRGB(240, 170, 60)

	local model = Instance.new("Model")
	model.Name = "TuskAct3"
	local bodySize = Vector3.new(2.0, 1.8, 2.3) * s
	local h = bodySize / 2
	local body = part(model, { Name = "Body", Size = bodySize, Color = pink, Ellipsoid = true, Massless = false })
	body.CFrame = CFrame.Angles(0.35, 0, 0) -- leans forward like it's about to pounce
	body.Anchored = true
	model.PrimaryPart = body
	local rig = { Body = body, Joints = {} }

	local back = part(model, { Name = "BackShade", Size = bodySize * Vector3.new(0.9, 0.7, 0.8), Color = pinkDark, Ellipsoid = true })
	attach(body, back, CFrame.new(0, -0.3 * s, 0.25 * s))

	-- Dark mohawk crest running front to back over the top.
	local crest = part(model, { Name = "Crest", Size = Vector3.new(0.16, 1.1, 2.0) * s, Color = navy, Ellipsoid = true })
	attach(body, crest, CFrame.new(0, 0.85 * s, -0.15 * s))
	-- Antennae with grey balls.
	for _, side in ipairs({ -1, 1 }) do
		local base = Vector3.new(side * 0.55 * s, 0.6 * s, -0.7 * s)
		local tipPos = base + Vector3.new(side * 0.45, 0.45, -0.2) * s
		local rod = part(model, { Name = "Antenna", Shape = Enum.PartType.Cylinder, Size = Vector3.new((tipPos - base).Magnitude, 0.04 * s, 0.04 * s), Color = pinkDark })
		attach(body, rod, CFrame.lookAt((base + tipPos) / 2, tipPos) * CFrame.Angles(0, math.pi / 2, 0))
		local ball = part(model, { Name = "AntennaBall", Size = Vector3.new(0.14, 0.14, 0.14) * s, Color = steel, Material = Enum.Material.Metal, Ellipsoid = true })
		attach(body, ball, CFrame.new(tipPos))
	end

	-- Face mask at the front: plate, two eye slits, slotted mouth.
	local facePos = onSurface(h, Vector3.new(0, -0.15, -1), 0.96)
	local mask = part(model, { Name = "Mask", Size = Vector3.new(0.85, 0.8, 0.3) * s, Color = Color3.fromRGB(236, 130, 190), Ellipsoid = true })
	attach(body, mask, CFrame.new(facePos))
	for _, side in ipairs({ -1, 1 }) do
		local slit = part(model, { Name = "EyeSlit", Size = Vector3.new(0.06, 0.24, 0.06) * s, Color = Color3.fromRGB(40, 20, 40) })
		attach(body, slit, CFrame.new(facePos + Vector3.new(side * 0.09 * s, 0.12 * s, -0.14 * s)))
	end
	for i = -2, 2 do
		local tooth = part(model, { Name = "MouthSlot", Size = Vector3.new(0.09, 0.14, 0.06) * s, Color = Color3.fromRGB(60, 25, 55) })
		attach(body, tooth, CFrame.new(facePos + Vector3.new(i * 0.13 * s, -0.2 * s, -0.12 * s)))
	end
	-- Little gold stars over the body.
	for i, d in ipairs({ Vector3.new(0.6, 0.6, -0.5), Vector3.new(-0.55, 0.5, -0.6), Vector3.new(0.75, 0.1, 0.4), Vector3.new(-0.7, 0.2, 0.4), Vector3.new(0.3, 0.85, 0.3), Vector3.new(-0.35, 0.8, -0.2), Vector3.new(0.5, -0.3, -0.8) }) do
		star5(model, body, onSurface(h, d, 1.01), d, 0.22 * s, starGold, i)
	end

	-- Purple-blue belly lens underneath.
	local lensPart = part(model, { Name = "BellyLens", Size = Vector3.new(1.0, 1.25, 0.6) * s, Color = lens, Material = Enum.Material.Glass, Reflectance = 0.2, Ellipsoid = true })
	attach(body, lensPart, CFrame.new(0, -0.95 * s, -0.25 * s) * CFrame.Angles(-0.5, 0, 0))
	local lensRim = part(model, { Name = "LensRim", Size = Vector3.new(1.1, 1.35, 0.5) * s, Color = pinkDark, Ellipsoid = true })
	attach(body, lensRim, CFrame.new(0, -0.92 * s, -0.17 * s) * CFrame.Angles(-0.5, 0, 0))
	-- Hip pistons (springs) from body to hips.
	for _, side in ipairs({ -1, 1 }) do
		local piston = part(model, { Name = "Piston", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 0.08, 0.08) * s, Color = steel, Material = Enum.Material.Metal })
		attach(body, piston, CFrame.new(side * 0.55 * s, -0.95 * s, 0.15 * s) * CFrame.Angles(0, 0, math.pi / 2 + side * 0.3))
	end

	-- Blue shoulder balls with red stars.
	for _, side in ipairs({ -1, 1 }) do
		local center = Vector3.new(side * 1.08 * s, 0.1 * s, -0.15 * s)
		local ball = part(model, { Name = "ShoulderBall", Size = Vector3.new(0.95, 0.95, 0.95) * s, Color = blue, Material = Enum.Material.SmoothPlastic, Reflectance = 0.1, Ellipsoid = true })
		attach(body, ball, CFrame.new(center))
		local starDir = Vector3.new(side * 0.8, 0.1, -0.6)
		star5(model, body, center + starDir.Unit * 0.47 * s, starDir, 0.62 * s, yellow, 0.2)
		star5(model, body, center + starDir.Unit * 0.49 * s, starDir, 0.48 * s, red, 0.2)
	end

	-- Arms: grey joints, long thin pink segments, three-spike claws.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local shoulder = CFrame.new(a[2] * 1.15 * s, -0.25 * s, -0.25 * s) * CFrame.Angles(0.25, 0, a[2] * 0.25)
		local _, hand = limb(model, body, rig, a[1], shoulder, 1.0 * s, 0.22 * s, pink, steel)
		local wrist = segment(model, hand, 0.95 * s, 0.2 * s, pink, a[2] * -0.5, steel)
		local claw = part(model, { Name = "ClawDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 0.4, 0.4) * s, Color = navy, Material = Enum.Material.Metal })
		attach(wrist, claw, CFrame.new(-0.05 * s, 0, 0))
		spikes(model, wrist, 0.7 * s, steel)
		if a[1] == "ArmR" then
			rig.NailPoint = Instance.new("Attachment")
			rig.NailPoint.Name = "NailPoint"
			rig.NailPoint.Parent = wrist
		end
	end

	-- Legs: thighs, knee joints, shins with little stars, pointed spiked feet.
	for i, side in ipairs({ -1, 1 }) do
		local hip = CFrame.new(side * 0.5 * s, -1.25 * s, 0.25 * s) * CFrame.Angles(-0.25, 0, side * 0.12)
		local _, knee = limb(model, body, rig, "Leg" .. i, hip, 0.95 * s, 0.25 * s, pink, steel)
		local ankle = segment(model, knee, 1.0 * s, 0.22 * s, pink, side * 0.35, steel)
		local foot = part(model, { Name = "Foot", Size = Vector3.new(0.3, 0.5, 0.3) * s, Color = pinkDark, Ellipsoid = true })
		attach(ankle, foot, CFrame.new(-0.12 * s, 0, 0))
		spikes(model, ankle, 0.55 * s, steel)
	end
	return model, rig
end

---------------------------------------------------------------------------
-- ACT 4 (from the owner's reference images): an armoured pink humanoid
-- with a slotted helmet, layered shoulder armour, blue gloves and boots,
-- yellow stars on the legs and a long skirt of hanging pink scales.
---------------------------------------------------------------------------
local function buildAct4(scale)
	local s = scale * 1.3
	local pink = Color3.fromRGB(240, 150, 200)
	local pinkLight = Color3.fromRGB(252, 190, 222)
	local pinkDark = Color3.fromRGB(196, 100, 160)
	local glove = Color3.fromRGB(70, 110, 170)
	local yellow = Color3.fromRGB(255, 210, 60)
	local gold = Color3.fromRGB(235, 185, 70)

	local model = Instance.new("Model")
	model.Name = "TuskAct4"
	local torso = part(model, { Name = "Body", Size = Vector3.new(1.7, 1.6, 1.15) * s, Color = pink, Ellipsoid = true, Massless = false })
	torso.CFrame = CFrame.new()
	torso.Anchored = true
	model.PrimaryPart = torso
	local rig = { Body = torso, Joints = {} }

	-- Chest armour plates and a small emblem.
	for _, side in ipairs({ -1, 1 }) do
		local plate = part(model, { Name = "ChestPlate", Size = Vector3.new(0.8, 0.75, 0.3) * s, Color = pinkLight, Ellipsoid = true })
		attach(torso, plate, CFrame.new(side * 0.38 * s, 0.25 * s, -0.48 * s) * CFrame.Angles(0, side * 0.2, 0))
	end
	local emblem = part(model, { Name = "Emblem", Size = Vector3.new(0.18, 0.18, 0.05) * s, Color = gold, Material = Enum.Material.Metal, Ellipsoid = true })
	attach(torso, emblem, CFrame.new(-0.4 * s, 0.35 * s, -0.66 * s))
	local waist = part(model, { Name = "Waist", Size = Vector3.new(1.2, 0.6, 0.9) * s, Color = pinkDark, Ellipsoid = true })
	attach(torso, waist, CFrame.new(0, -0.85 * s, 0))

	-- Helmet: dome, slotted visor, side ridges.
	local head = part(model, { Name = "Head", Size = Vector3.new(0.85, 1.0, 0.9) * s, Color = pink, Ellipsoid = true })
	attach(torso, head, CFrame.new(0, 1.15 * s, -0.08 * s))
	local hcf = CFrame.new(0, 1.15 * s, -0.08 * s)
	local visor = part(model, { Name = "Visor", Size = Vector3.new(0.55, 0.55, 0.2) * s, Color = pinkLight, Ellipsoid = true })
	attach(torso, visor, hcf * CFrame.new(0, -0.08 * s, -0.4 * s))
	for i = -2, 2 do
		local slot = part(model, { Name = "VisorSlot", Size = Vector3.new(0.05, 0.36, 0.05) * s, Color = Color3.fromRGB(80, 30, 70) })
		attach(torso, slot, hcf * CFrame.new(i * 0.09 * s, -0.08 * s, -0.5 * s))
	end
	local ridge = part(model, { Name = "HelmetRidge", Size = Vector3.new(0.12, 0.6, 0.9) * s, Color = pinkDark, Ellipsoid = true })
	attach(torso, ridge, hcf * CFrame.new(0, 0.35 * s, 0.05 * s))
	-- Head fins animate like ears.
	for _, e in ipairs({ { "EarL", -1 }, { "EarR", 1 } }) do
		local base = hcf * CFrame.new(e[2] * 0.4 * s, 0.05 * s, 0.05 * s) * CFrame.Angles(0, 0, -e[2] * 1.2)
		local fin = part(model, { Name = e[1], Size = Vector3.new(0.18, 0.45, 0.35) * s, Color = pinkDark, Ellipsoid = true })
		local offset = CFrame.new(0, 0.18 * s, 0)
		local w = attach(torso, fin, base * offset)
		rig.Joints[e[1]] = { Weld = w, Base = base, Offset = offset }
	end

	-- Layered shoulder armour, armoured arms, blue gloves.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		for layer = 0, 2 do
			local pad = part(model, { Name = "ShoulderPad", Size = Vector3.new(0.8 - layer * 0.12, 0.35, 0.85 - layer * 0.1) * s, Color = layer % 2 == 0 and pink or pinkLight, Ellipsoid = true })
			attach(torso, pad, CFrame.new(a[2] * (0.95 + layer * 0.05) * s, (0.62 - layer * 0.2) * s, 0) * CFrame.Angles(0, 0, -a[2] * (0.35 + layer * 0.1)))
		end
		-- Arms held out from the sides so the blue gloves clear the scale skirt.
		local shoulder = CFrame.new(a[2] * 1.05 * s, 0.3 * s, 0) * CFrame.Angles(0, 0, a[2] * 0.5)
		local _, elbow = limb(model, torso, rig, a[1], shoulder, 1.05 * s, 0.34 * s, pink, pinkLight)
		local wrist = segment(model, elbow, 1.0 * s, 0.3 * s, pink, a[2] * -0.3)
		local hand = part(model, { Name = "Glove", Size = Vector3.new(0.48, 0.42, 0.34) * s, Color = glove, Ellipsoid = true })
		attach(wrist, hand, CFrame.new(-0.2 * s, 0, 0))
		if a[1] == "ArmR" then
			rig.NailPoint = Instance.new("Attachment")
			rig.NailPoint.Name = "NailPoint"
			rig.NailPoint.Parent = hand
		end
	end

	-- Armoured legs, blue boots, yellow stars.
	for i, side in ipairs({ -1, 1 }) do
		local hip = CFrame.new(side * 0.4 * s, -1.05 * s, 0) * CFrame.Angles(0, 0, side * 0.05)
		local _, knee = limb(model, torso, rig, "Leg" .. i, hip, 1.2 * s, 0.42 * s, pink, pinkLight)
		local ankle = segment(model, knee, 1.15 * s, 0.38 * s, pink, 0)
		local boot = part(model, { Name = "Boot", Size = Vector3.new(0.5, 0.45, 0.8) * s, Color = glove, Ellipsoid = true })
		attach(ankle, boot, CFrame.new(-0.15 * s, 0, -0.15 * s))
		star5(model, knee, Vector3.new(-0.45 * s, 0, -0.2 * s), Vector3.new(0, 0, -1), 0.4 * s, yellow, i)
	end

	-- The skirt: rows of hanging pink scales from the chest down to the knees.
	local rows = 5
	for row = 0, rows - 1 do
		local y = (-0.35 - row * 0.42) * s
		local radius = (0.95 + row * 0.12) * s
		local count = 12 + row * 2
		for k = 0, count - 1 do
			local a = (k + (row % 2) * 0.5) / count * math.pi * 2
			local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
			local pos = Vector3.new(dir.X * radius, y, dir.Z * radius * 0.85)
			local scaleSize = Vector3.new(0.34, 0.5, 0.06) * s
			local scalePart = part(model, { Name = "Scale", Size = scaleSize, Color = (k + row) % 3 == 0 and pinkLight or pink, Ellipsoid = true })
			-- Face outward, hang down and flare out a little at the bottom.
			attach(torso, scalePart, CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-0.25 - row * 0.04, 0, 0))
		end
	end
	return model, rig
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
