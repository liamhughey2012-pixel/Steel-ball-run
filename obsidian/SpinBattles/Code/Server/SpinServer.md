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

**What it does:** Boots every server system: characters (Johnny/Tusk, Gyro/Ball Breaker, Diego/Scary Monsters, Pork Pie Hat Kid/Wired, Sandman/In a Silent Way), Stand-user NPCs that fight you, custom Stand models, NPCs and Studio test dummies.

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
	Diego/Scary Monsters, Pork Pie Hat Kid/Wired, Sandman/In a Silent Way),
	Stand-user NPCs that fight you,
	custom Stand models, NPCs and Studio test dummies.
]]

local ProjectileService = require(script.ProjectileService)
local TuskService = require(script.TuskService)
local NPCService = require(script.NPCService)
local TestDummies = require(script.TestDummies)
local StandAssetLoader = require(script.StandAssetLoader)
local JohnnyOutfit = require(script.JohnnyOutfit)
local GyroOutfit = require(script.GyroOutfit)
local DiegoOutfit = require(script.DiegoOutfit)
local PorkPieOutfit = require(script.PorkPieOutfit)
local SandmanOutfit = require(script.SandmanOutfit)
local MountainTimOutfit = require(script.MountainTimOutfit)
local HotPantsOutfit = require(script.HotPantsOutfit)
local BlackmoreOutfit = require(script.BlackmoreOutfit)
local AxlOutfit = require(script.AxlOutfit)
local ValentineOutfit = require(script.ValentineOutfit)
local DiegoAUOutfit = require(script.DiegoAUOutfit)
local JosukeOutfit = require(script.JosukeOutfit)
local TooruOutfit = require(script.TooruOutfit)
local JodioOutfit = require(script.JodioOutfit)
local RingoOutfit = require(script.RingoOutfit)
local JotaroOutfit = require(script.JotaroOutfit)
local DioOutfit = require(script.DioOutfit)
local JosephOutfit = require(script.JosephOutfit)
local PolnareffOutfit = require(script.PolnareffOutfit)
local Josuke4Outfit = require(script.Josuke4Outfit)
local KiraOutfit = require(script.KiraOutfit)
local OkuyasuOutfit = require(script.OkuyasuOutfit)
local RohanOutfit = require(script.RohanOutfit)
local StandBots = require(script.StandBots)
local BountyService = require(script.BountyService)
local WeatherService = require(script.WeatherService)
local CorpseService = require(script.CorpseService)
local ArrowService = require(script.ArrowService)
local ShopBalls = require(script.ShopBalls)
local RaceService = require(script.RaceService)
local DataService = require(script.DataService)

-- Shared projectile budget (barrages and wrecking balls fire several at once).
ProjectileService.MaxActivePerPlayer = 20

StandAssetLoader.init()
TuskService.init()
JohnnyOutfit.init()
GyroOutfit.init()
DiegoOutfit.init()
PorkPieOutfit.init()
SandmanOutfit.init()
MountainTimOutfit.init()
HotPantsOutfit.init()
BlackmoreOutfit.init()
AxlOutfit.init()
ValentineOutfit.init()
DiegoAUOutfit.init()
JosukeOutfit.init()
TooruOutfit.init()
JodioOutfit.init()
RingoOutfit.init()
JotaroOutfit.init()
DioOutfit.init()
JosephOutfit.init()
PolnareffOutfit.init()
Josuke4Outfit.init()
KiraOutfit.init()
OkuyasuOutfit.init()
RohanOutfit.init()
StandBots.init(TuskService)
BountyService.init()
DataService.init()
WeatherService.init()
CorpseService.init(TuskService)
ArrowService.init(TuskService)
ShopBalls.init(TuskService)
RaceService.init()
NPCService.init()
TestDummies.init()
```
