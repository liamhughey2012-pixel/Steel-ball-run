---
tags: [code, client]
type: LocalScript
location: "StarterPlayer › StarterPlayerScripts"
updated: 2026-11-22
---
# SpinClient

| | |
|---|---|
| **Type** | LocalScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts` |
| **Exact name** | `SpinClient` (capitals matter) |

**What it does:** Boots every client system: Golden Spin, Tusk, NPC bubbles and map ambience.

## How to add it
1. In Studio's Explorer, find **StarterPlayerScripts** (StarterPlayer › StarterPlayerScripts).
2. Right-click it › **Insert Object** › **LocalScript**.
3. Rename it to **SpinClient**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	SpinClient  (StarterPlayer.StarterPlayerScripts.SpinClient — LocalScript)
	Boots every client system: Golden Spin, Tusk, NPC bubbles and map ambience.
]]

local SpinMeter = require(script.UI.SpinMeter)
local SpinVFX = require(script.SpinVFX)
local SpinController = require(script.SpinController)
local TuskStand = require(script.TuskStand)
local TuskProjectiles = require(script.TuskProjectiles)
local TuskSneakController = require(script.TuskSneakController)
local TuskController = require(script.TuskController)
local WorldClient = require(script.WorldClient)
local CharacterCard = require(script.UI.CharacterCard)

SpinMeter.init()
SpinVFX.init()
SpinController.init()
TuskStand.init()
TuskProjectiles.init()
TuskSneakController.init()
TuskController.init()
WorldClient.init()
CharacterCard.init()
```
