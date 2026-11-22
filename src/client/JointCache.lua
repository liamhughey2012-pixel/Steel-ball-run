--[[
	JointCache  (StarterPlayerScripts.SpinClient.JointCache)
	Reads and writes a joint's offset for the pose system, and remembers
	each joint's original offset the first time it is touched.

	Works with both kinds of Roblox character joints:
	  * Motor6D              -> offset is joint.C0
	  * AnimationConstraint  -> offset is joint.Attachment0.CFrame
	    (newer places using the "Avatar Joint Upgrade")
]]

local JointCache = {}
local originals = setmetatable({}, { __mode = "k" })

function JointCache.isJoint(j)
	if not j then
		return false
	end
	if j:IsA("Motor6D") then
		return true
	end
	return j:IsA("AnimationConstraint") and j.Attachment0 ~= nil
end

function JointCache.read(j)
	if j:IsA("Motor6D") then
		return j.C0
	end
	return j.Attachment0.CFrame
end

function JointCache.write(j, cf)
	if j:IsA("Motor6D") then
		j.C0 = cf
	elseif j.Attachment0 then
		j.Attachment0.CFrame = cf
	end
end

function JointCache.original(j)
	local c0 = originals[j]
	if not c0 then
		c0 = JointCache.read(j)
		originals[j] = c0
	end
	return c0
end

return JointCache
