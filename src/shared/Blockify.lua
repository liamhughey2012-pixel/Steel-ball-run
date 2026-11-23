--[[
	Blockify  (ReplicatedStorage.SpinShared.Blockify)

	Turns a part-built model into a blocky (classic Roblox) look while
	keeping each model recognisable:
	  * small round pieces (eyes, studs, tips) become single boxes
	  * BIG round pieces (Tusk's egg body, heads, shoulder balls) become a
	    "voxel-round" shape: a core box plus three crossing boxes, so the
	    outline is a stepped, pixel-art circle instead of a plain cube
	  * flat discs (Act 2's rings) stay circular the same stepped way
	  * long cylinders become square rods
	Part centres don't move. The extra boxes are welded to the original part,
	so welds, rigs, fades and animations keep working. Models whose parts are
	moved one by one (the raptor) pass { Voxel = false } for single boxes.
	Used by the Tusk Stands and the Scary Monsters raptor when
	TuskConfig.BlockyModels is true. A part with the attribute KeepRound
	is left alone.
]]

local Blockify = {}

local ROUND = 0.82 -- single box vs. sphere diameter (similar silhouette)
local ROD = 0.88 -- square rod vs. cylinder diameter
local BIG = 0.7 -- studs: round pieces at least this big get the voxel-round shape
local CORE, ARM = 0.86, 0.62 -- voxel-round: core box and the thin side of the crossing boxes

-- A box welded on top of `part`, copying its look.
local function extraBox(part, size)
	local p = Instance.new("Part")
	p.Name = part.Name .. "Block"
	p.Size = size
	p.Color = part.Color
	p.Material = part.Material
	p.Reflectance = part.Reflectance
	p.Transparency = part.Transparency
	p.CastShadow = part.CastShadow
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = part.CFrame
	local weld = Instance.new("Weld")
	weld.Part0 = part
	weld.Part1 = p
	weld.C0 = CFrame.new()
	weld.Parent = p
	p.Parent = part.Parent
	return p
end

-- Stepped round shape for a piece of size s (core + crossing boxes on the axes in `axes`).
local function voxelRound(part, s, axes)
	part.Size = s * CORE
	for _, axis in ipairs(axes) do
		local x = axis == "X" and s.X or s.X * ARM
		local y = axis == "Y" and s.Y or s.Y * ARM
		local z = axis == "Z" and s.Z or s.Z * ARM
		extraBox(part, Vector3.new(x, y, z))
	end
end

local function convert(part, opts)
	if part:GetAttribute("KeepRound") or (opts.KeepRound and opts.KeepRound[part.Name]) then
		return
	end
	local canAdd = opts.Voxel ~= false and part.Parent ~= nil
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.Sphere then
		mesh:Destroy()
		local s = part.Size
		if canAdd and math.max(s.X, s.Y, s.Z) >= BIG then
			voxelRound(part, s, { "X", "Y", "Z" })
		else
			part.Size = s * ROUND
		end
		return
	end
	if part:IsA("Part") then
		if part.Shape == Enum.PartType.Ball then
			part.Shape = Enum.PartType.Block
			local s = part.Size
			if canAdd and s.X >= BIG then
				voxelRound(part, s, { "X", "Y", "Z" })
			else
				part.Size = s * ROUND
			end
		elseif part.Shape == Enum.PartType.Cylinder then
			-- Cylinder length runs along X; its round face is in Y/Z.
			part.Shape = Enum.PartType.Block
			local s = part.Size
			local diameter = math.min(s.Y, s.Z)
			if canAdd and diameter >= BIG and s.X < diameter * 0.6 then
				-- A disc / wheel / ring: keep it round (stepped) in its face.
				part.Size = Vector3.new(s.X, s.Y * CORE, s.Z * CORE)
				extraBox(part, Vector3.new(s.X, s.Y, s.Z * ARM))
				extraBox(part, Vector3.new(s.X, s.Y * ARM, s.Z))
			else
				part.Size = Vector3.new(s.X, s.Y * ROD, s.Z * ROD)
			end
		end
	end
end

-- opts.Voxel = false: single boxes only (for models whose parts are moved one
-- by one, like the raptor rig).
-- opts.KeepRound = { [partName] = true }: signature round pieces left smooth.
function Blockify.apply(model, opts)
	opts = opts or {}
	local parts = {}
	if model:IsA("BasePart") then
		table.insert(parts, model)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	-- (collected first so the boxes added along the way aren't converted again)
	for _, p in ipairs(parts) do
		convert(p, opts)
	end
	return model
end

-- True when the game wants blocky models (TuskConfig.BlockyModels, default on).
function Blockify.enabled(config)
	return not (config and config.BlockyModels == false)
end

return Blockify
