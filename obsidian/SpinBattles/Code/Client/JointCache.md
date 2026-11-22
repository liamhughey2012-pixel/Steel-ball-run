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

**What it does:** Reads and writes a joint's offset for the pose system, and remembers each joint's original offset the first time it is touched.

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
```
