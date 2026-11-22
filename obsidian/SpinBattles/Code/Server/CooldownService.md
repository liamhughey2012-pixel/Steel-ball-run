---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# CooldownService

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `CooldownService` (capitals matter) |

**What it does:** Server-owned cooldowns. Clients only ever display what the server says. Reusable by any ability: CooldownService.start(player, "AbilityKey", seconds)

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **CooldownService**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	CooldownService  (ServerScriptService.SpinServer.CooldownService)
	Server-owned cooldowns. Clients only ever display what the server says.
	Reusable by any ability: CooldownService.start(player, "AbilityKey", seconds)
]]

local Players = game:GetService("Players")

local CooldownService = {}
local readyAt = {} -- [player] = { [key] = os.clock() time when ready }

function CooldownService.remaining(player, key)
	local list = readyAt[player]
	local t = list and list[key]
	if not t then
		return 0
	end
	return math.max(0, t - os.clock())
end

function CooldownService.isReady(player, key)
	return CooldownService.remaining(player, key) <= 0
end

function CooldownService.start(player, key, duration)
	local list = readyAt[player]
	if not list then
		list = {}
		readyAt[player] = list
	end
	list[key] = os.clock() + duration
end

function CooldownService.reset(player, key)
	if readyAt[player] then
		readyAt[player][key] = nil
	end
end

Players.PlayerRemoving:Connect(function(player)
	readyAt[player] = nil
end)

return CooldownService
```
