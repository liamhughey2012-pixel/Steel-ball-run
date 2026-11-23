---
tags: [code, server]
type: Script
location: "ServerScriptService"
updated: 2026-11-22
---
# SpinServer

| | |
|---|---|
| **Type** | Script |
| **Put it in** | `ServerScriptService` |
| **Exact name** | `SpinServer` (capitals matter) |

**What it does:** Boots every server system: characters (Johnny/Tusk, Gyro/Ball Breaker, Diego/Scary Monsters), custom Stand models, NPCs and Studio test dummies.

## How to add it
1. In Studio's Explorer, find **ServerScriptService** (ServerScriptService).
2. Right-click it › **Insert Object** › **Script**.
3. Rename it to **SpinServer**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	SpinServer  (ServerScriptService.SpinServer — Script)
	Boots every server system: characters (Johnny/Tusk, Gyro/Ball Breaker,
	Diego/Scary Monsters),
	custom Stand models, NPCs and Studio test dummies.
]]

local ProjectileService = require(script.ProjectileService)
local TuskService = require(script.TuskService)
local NPCService = require(script.NPCService)
local TestDummies = require(script.TestDummies)
local StandAssetLoader = require(script.StandAssetLoader)
local GyroOutfit = require(script.GyroOutfit)
local DiegoOutfit = require(script.DiegoOutfit)

-- Shared projectile budget (barrages and wrecking balls fire several at once).
ProjectileService.MaxActivePerPlayer = 20

StandAssetLoader.init()
TuskService.init()
GyroOutfit.init()
DiegoOutfit.init()
NPCService.init()
TestDummies.init()
```
