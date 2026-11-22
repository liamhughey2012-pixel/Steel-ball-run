--[[
	TuskHitbox  (ServerScriptService.SpinServer.TuskHitbox)
	Server-side spatial queries for melee and area attacks.
	Returns unique characters (models with a Humanoid), nearest first.
]]

local TuskHitbox = {}

local function characterFromPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end
TuskHitbox.characterFromPart = characterFromPart

local function collect(parts, attacker, origin, max)
	local seen, list = {}, {}
	for _, part in ipairs(parts) do
		local character = characterFromPart(part)
		if character and character ~= attacker and not seen[character] then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart")
			if humanoid and root and humanoid.Health > 0 then
				seen[character] = true
				table.insert(list, { Character = character, Distance = (root.Position - origin).Magnitude })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Distance < b.Distance
	end)
	local out = {}
	for i = 1, math.min(#list, max or #list) do
		out[i] = list[i].Character
	end
	return out
end

local function overlapParams(attacker)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = attacker and { attacker } or {}
	return params
end

function TuskHitbox.inBox(attacker, cframe, size, max)
	local parts = workspace:GetPartBoundsInBox(cframe, size, overlapParams(attacker))
	return collect(parts, attacker, cframe.Position, max)
end

function TuskHitbox.inRadius(attacker, position, radius, max)
	local parts = workspace:GetPartBoundsInRadius(position, radius, overlapParams(attacker))
	return collect(parts, attacker, position, max)
end

-- True if nothing but characters blocks the line between the two points.
function TuskHitbox.lineOfSight(fromPos, toPos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	params.IgnoreWater = true
	local offset = toPos - fromPos
	local result = workspace:Raycast(fromPos, offset, params)
	if not result then
		return true
	end
	return characterFromPart(result.Instance) ~= nil
end

return TuskHitbox
