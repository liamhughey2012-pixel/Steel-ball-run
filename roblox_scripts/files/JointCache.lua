--[[
	JointCache  (StarterPlayerScripts.SpinClient.JointCache)
	Remembers each Motor6D's original C0 the first time any pose system
	touches it, so Spin poses and Tusk poses can both restore the true
	rest pose instead of each other's leftovers.
]]

local JointCache = {}
local originals = setmetatable({}, { __mode = "k" })

function JointCache.original(motor)
	local c0 = originals[motor]
	if not c0 then
		c0 = motor.C0
		originals[motor] = c0
	end
	return c0
end

return JointCache
