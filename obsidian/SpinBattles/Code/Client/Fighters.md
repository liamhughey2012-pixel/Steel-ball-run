---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient"
updated: 2026-11-22
---
# Fighters

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| **Exact name** | `Fighters` (capitals matter) |

**What it does:** Everyone who can use a Stand: the players plus the Stand-user NPCs (StandBots, tagged "SpinFighter" on the server). Returned in the same shape as Players:GetPlayers() ({ Character = model }), so visual code that loops over players draws the NPCs' Stands and effects too.

## How to add it
1. In Studio's Explorer, find **SpinClient** (StarterPlayer › StarterPlayerScripts › SpinClient).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **Fighters**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	Fighters  (StarterPlayerScripts.SpinClient.Fighters)

	Everyone who can use a Stand: the players plus the Stand-user NPCs
	(StandBots, tagged "SpinFighter" on the server). Returned in the same
	shape as Players:GetPlayers() ({ Character = model }), so visual code
	that loops over players draws the NPCs' Stands and effects too.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Fighters = {}
Fighters.Tag = "SpinFighter"

function Fighters.list()
	local out = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(out, player)
	end
	for _, model in ipairs(CollectionService:GetTagged(Fighters.Tag)) do
		if model.Parent then
			table.insert(out, { Character = model })
		end
	end
	return out
end

return Fighters
```
