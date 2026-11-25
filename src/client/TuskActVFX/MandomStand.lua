--[[
	TuskActVFX.MandomStand  (StarterPlayerScripts.SpinClient.TuskActVFX.MandomStand)

	MANDOM, matched to the art: it rides on Ringo's right shoulder.
	  * a big pink egg, tipped forward, covered in a diamond net of darker
	    pink cords with a gold stud (dark centre) at every crossing
	  * under it, a chunky padded shoulder-pack in dusty rose: stacked
	    blocks and pouches with flaps and seams
	  * pink tubes curling out from under the pack, each ending in a gold
	    ring (the outfit plugs the same tubes into his arm and chest)
	TuskStand gives it a soft pink aura. Registered by RingoVFX.
]]

local MandomStand = {}

local EGG = Color3.fromRGB(200, 96, 146)
local CORD = Color3.fromRGB(128, 44, 92)
local STUD = Color3.fromRGB(226, 182, 76)
local STUD_DARK = Color3.fromRGB(70, 40, 30)
local PACK = Color3.fromRGB(186, 108, 116)
local PACK_DARK = Color3.fromRGB(140, 72, 84)
local PACK_LIGHT = Color3.fromRGB(214, 140, 140)
local TUBE = Color3.fromRGB(190, 74, 124)
local RING = Color3.fromRGB(226, 182, 76)

MandomStand.Aura = Color3.fromRGB(240, 130, 180)
MandomStand.AuraLight = Color3.fromRGB(255, 220, 236)
-- On his right shoulder, a little behind.
MandomStand.Offset = CFrame.new(1.75, 1.55, 0.7)

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

-- A rod from a to b (in the parent's space).
local function rod(model, parent, name, a, b, d, color)
	local len = (b - a).Magnitude
	if len < 1e-3 then
		return nil
	end
	local mid = (a + b) / 2
	local p = box(model, parent, name, Vector3.new(len + d * 0.4, d, d), color, CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- The egg's surface: theta from the top (0) to the bottom (pi).
local function eggPoint(theta, phi, a, b, push)
	local r = 1 + (push or 0)
	-- A little fuller at the bottom, like an egg.
	local fat = 1 + 0.08 * math.cos(theta)
	return Vector3.new(a * fat * r * math.sin(theta) * math.cos(phi), b * r * math.cos(theta), a * fat * r * math.sin(theta) * math.sin(phi))
end

function MandomStand.build(scale)
	local s = (scale or 1) * 0.8
	local model = Instance.new("Model")
	model.Name = "Mandom"
	local rig = { Joints = {} }
	local function V(x, y, z)
		return Vector3.new(x, y, z) * s
	end

	-- The shoulder-pack is the body.
	local pack = newPart(model, "Body", V(2.3, 1.5, 1.9), PACK)
	pack.Anchored = true
	pack.Massless = false
	pack.CFrame = CFrame.new()
	model.PrimaryPart = pack
	rig.Body = pack
	-- Stacked blocks and pouches, seams and flaps.
	box(model, pack, "Block", V(1.9, 0.9, 1.6), PACK_LIGHT, CFrame.new(-0.25 * s, 0.95 * s, 0.1 * s) * CFrame.Angles(0, 0, 0.12))
	box(model, pack, "BlockSeam", V(1.95, 0.08, 1.65), PACK_DARK, CFrame.new(-0.25 * s, 0.55 * s, 0.1 * s) * CFrame.Angles(0, 0, 0.12))
	box(model, pack, "Pouch", V(1.0, 1.1, 0.55), PACK, CFrame.new(0.35 * s, -0.2 * s, -1.15 * s))
	box(model, pack, "PouchFlap", V(1.08, 0.38, 0.62), PACK_LIGHT, CFrame.new(0.35 * s, 0.3 * s, -1.17 * s))
	box(model, pack, "PouchSeam", V(1.02, 0.06, 0.58), PACK_DARK, CFrame.new(0.35 * s, -0.75 * s, -1.15 * s))
	box(model, pack, "SidePouch", V(0.55, 1.0, 1.1), PACK, CFrame.new(1.35 * s, -0.25 * s, -0.2 * s))
	box(model, pack, "SideFlap", V(0.62, 0.34, 1.16), PACK_LIGHT, CFrame.new(1.37 * s, 0.25 * s, -0.2 * s))
	box(model, pack, "Strap", V(0.3, 1.7, 2.0), PACK_DARK, CFrame.new(-0.8 * s, 0, 0))
	box(model, pack, "LowerBlock", V(2.0, 0.6, 1.6), PACK_DARK, CFrame.new(0, -1.0 * s, 0.1 * s))
	for _, x in ipairs({ -0.7, 0, 0.7 }) do
		box(model, pack, "Rivet", V(0.14, 0.14, 0.06), STUD, CFrame.new(x * s, -1.0 * s, -0.72 * s))
	end

	-- The egg, on a joint so it can tip and turn.
	local a, b = 1.15 * s, 1.55 * s
	local headBase = CFrame.new(-0.1 * s, 1.6 * s, 0.2 * s) * CFrame.Angles(math.rad(-28), 0, math.rad(-10))
	local headOffset = CFrame.new(0, b * 0.9, 0)
	local egg, eggWeld = box(model, pack, "Head", Vector3.new(a * 2, b * 2, a * 2), EGG, headBase * headOffset)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	rig.Joints.Head = { Weld = eggWeld, Base = headBase, Offset = headOffset }
	-- The net: a diamond lattice of cords, a gold stud at each crossing.
	local rows, cols = 6, 8
	local points = {}
	for i = 1, rows do
		points[i] = {}
		local theta = math.pi * (0.16 + 0.7 * (i - 1) / (rows - 1))
		for j = 1, cols do
			local phi = (j + (i % 2) * 0.5) / cols * math.pi * 2
			points[i][j] = eggPoint(theta, phi, a, b, 0.015)
		end
	end
	local cord = 0.1 * s
	for i = 1, rows do
		for j = 1, cols do
			local p = points[i][j]
			-- Stud: gold, dark centre, facing out.
			local out = p.Magnitude > 0 and p.Unit or Vector3.new(0, 1, 0)
			ball(model, egg, "Stud", 0.22 * s, STUD, CFrame.new(p + out * 0.02 * s), Enum.Material.Metal)
			ball(model, egg, "StudEye", 0.11 * s, STUD_DARK, CFrame.new(p + out * 0.11 * s))
			if i < rows then
				-- Down-left and down-right to the next row (a diamond net).
				local shift = (i % 2 == 1) and 0 or 1
				local left = points[i + 1][((j - 1 + shift - 1) % cols) + 1]
				local right = points[i + 1][((j + shift - 1) % cols) + 1]
				rod(model, egg, "Cord", p, left, cord, CORD)
				rod(model, egg, "Cord", p, right, cord, CORD)
			end
		end
	end
	-- Top stud.
	ball(model, egg, "Stud", 0.26 * s, STUD, CFrame.new(0, b * 1.0, 0), Enum.Material.Metal)

	-- Tubes curling out from under the pack, each ending in a gold ring.
	-- (They loop out towards Ringo, on the pack's left, and forward.)
	local tubes = {
		{ Vector3.new(-1.0, -0.9, -0.5), Vector3.new(-1.7, -1.3, -0.9), Vector3.new(-2.0, -0.8, -1.4), Vector3.new(-1.7, -0.2, -1.5) },
		{ Vector3.new(-0.9, -1.2, 0.1), Vector3.new(-1.8, -1.8, 0.0), Vector3.new(-2.3, -1.4, -0.5) },
		{ Vector3.new(-0.3, -1.3, -0.7), Vector3.new(-0.6, -2.0, -1.3), Vector3.new(-1.3, -2.1, -1.6), Vector3.new(-1.6, -1.6, -1.9) },
		{ Vector3.new(0.5, -1.3, -0.6), Vector3.new(0.6, -1.9, -1.2), Vector3.new(0.1, -2.3, -1.6) },
		{ Vector3.new(-1.1, 0.2, -0.8), Vector3.new(-1.8, 0.4, -1.3), Vector3.new(-2.1, -0.1, -1.8) },
		{ Vector3.new(1.2, -0.9, 0.3), Vector3.new(1.7, -1.5, 0.1), Vector3.new(1.5, -2.0, -0.4) },
	}
	local td = 0.2 * s
	for _, t in ipairs(tubes) do
		local last = t[1] * s
		for k = 2, #t do
			local nxt = t[k] * s
			rod(model, pack, "Tube", last, nxt, td, TUBE)
			ball(model, pack, "TubeBend", td, TUBE, CFrame.new(nxt))
			last = nxt
		end
		local dir = (t[#t] - t[#t - 1]).Unit
		local ringCF = CFrame.lookAt(last, last + dir) * CFrame.Angles(0, math.pi / 2, 0)
		local ring = box(model, pack, "Ring", Vector3.new(0.12 * s, 0.34 * s, 0.34 * s), RING, ringCF, Enum.Material.Metal)
		ring.Shape = Enum.PartType.Cylinder
	end

	-- Where its effects come from: the egg's top.
	local point = Instance.new("Attachment")
	point.Name = "NailPoint"
	point.Position = Vector3.new(-0.1 * s, 3.2 * s, -0.4 * s)
	point.Parent = pack
	rig.NailPoint = point
	return model, rig
end

return MandomStand
