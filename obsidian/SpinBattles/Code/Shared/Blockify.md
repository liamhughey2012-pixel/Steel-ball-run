---
tags: [code, shared]
type: ModuleScript
location: "ReplicatedStorage › SpinShared"
updated: 2026-11-22
---
# Blockify

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ReplicatedStorage › SpinShared` |
| **Exact name** | `Blockify` (capitals matter) |

**What it does:** Turns a part-built model into a blocky (classic Roblox) look: egg/sphere shapes (SpecialMesh Sphere, Ball parts) become boxes cylinders become square rods Sizes are trimmed so the boxes keep roughly the same silhouette as the round shapes they replace. Part centres don't move, so welds, rigs and animations keep working. Used by the Tusk Stands and the Scary Monsters raptor when TuskConfig.BlockyModels is true. A part with the attribute KeepRound is left alone.

## How to add it
1. In Studio's Explorer, find **SpinShared** (ReplicatedStorage › SpinShared).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **Blockify**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	Blockify  (ReplicatedStorage.SpinShared.Blockify)

	Turns a part-built model into a blocky (classic Roblox) look:
	  * egg/sphere shapes (SpecialMesh Sphere, Ball parts) become boxes
	  * cylinders become square rods
	Sizes are trimmed so the boxes keep roughly the same silhouette as the
	round shapes they replace. Part centres don't move, so welds, rigs and
	animations keep working.
	Used by the Tusk Stands and the Scary Monsters raptor when
	TuskConfig.BlockyModels is true. A part with the attribute KeepRound
	is left alone.
]]

local Blockify = {}

local ROUND = 0.82 -- box edge vs. sphere diameter (similar volume / silhouette)
local ROD = 0.88 -- square rod vs. cylinder diameter

local function convert(part)
	if part:GetAttribute("KeepRound") then
		return
	end
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.Sphere then
		mesh:Destroy()
		part.Size = part.Size * ROUND
		return
	end
	if part:IsA("Part") then
		if part.Shape == Enum.PartType.Ball then
			part.Shape = Enum.PartType.Block
			part.Size = part.Size * ROUND
		elseif part.Shape == Enum.PartType.Cylinder then
			-- Cylinder length runs along X; the round sides become square.
			part.Shape = Enum.PartType.Block
			part.Size = Vector3.new(part.Size.X, part.Size.Y * ROD, part.Size.Z * ROD)
		end
	end
end

function Blockify.apply(model)
	if model:IsA("BasePart") then
		convert(model)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			convert(d)
		end
	end
	return model
end

-- True when the game wants blocky models (TuskConfig.BlockyModels, default on).
function Blockify.enabled(config)
	return not (config and config.BlockyModels == false)
end

return Blockify
```
