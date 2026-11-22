---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient"
updated: 2026-11-22
---
# JointCache

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| **Exact name** | `JointCache` (capitals matter) |

**What it does:** Remembers each Motor6D's original C0 the first time any pose system touches it, so Spin poses and Tusk poses can both restore the true rest pose instead of each other's leftovers.

## How to add it
1. In Studio's Explorer, find **SpinClient** (StarterPlayer › StarterPlayerScripts › SpinClient).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **JointCache**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
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
```
