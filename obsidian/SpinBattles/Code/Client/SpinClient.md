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

**What it does:** Boots every client system: hit feedback, settings, Stands, characters, HUD, character card, NPC bubbles and map ambience.

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
	Boots every client system: hit feedback, settings, Stands, characters,
	HUD, character card, NPC bubbles and map ambience.
]]

local SettingsUI = require(script.UI.SettingsUI)
local HitFX = require(script.HitFX)
local TuskStand = require(script.TuskStand)
local TuskProjectiles = require(script.TuskProjectiles)
local TuskSneakController = require(script.TuskSneakController)
local TuskController = require(script.TuskController)
local WorldClient = require(script.WorldClient)
local CharacterCard = require(script.UI.CharacterCard)
local CombatUI = require(script.UI.CombatUI)
local DefenseClient = require(script.DefenseClient)
local BountyUI = require(script.UI.BountyUI)

SettingsUI.init()
HitFX.init()
TuskStand.init()
TuskProjectiles.init()
TuskSneakController.init()
TuskController.init()
WorldClient.init()
CharacterCard.init()
CombatUI.init()
DefenseClient.init()
BountyUI.init()
```
