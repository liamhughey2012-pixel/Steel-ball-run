--[[
	Maid  (ReplicatedStorage.SpinShared.Maid)
	Tracks connections, instances and cleanup functions so effects always end.
]]

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(task)
	table.insert(self._tasks, task)
	return task
end

function Maid:Clean()
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		local t = tasks[i]
		local kind = typeof(t)
		if kind == "RBXScriptConnection" then
			t:Disconnect()
		elseif kind == "Instance" then
			t:Destroy()
		elseif kind == "function" then
			local ok, err = pcall(t)
			if not ok then
				warn("[Maid] cleanup error:", err)
			end
		elseif kind == "table" and t.Destroy then
			t:Destroy()
		end
	end
end

Maid.Destroy = Maid.Clean

return Maid
