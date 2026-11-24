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
local StandBots = require(script.StandBots)
local BountyService = require(script.BountyService)
local WeatherService = require(script.WeatherService)
local CorpseService = require(script.CorpseService)
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
StandBots.init(TuskService)
BountyService.init()
DataService.init()
WeatherService.init()
CorpseService.init(TuskService)
RaceService.init()
NPCService.init()
TestDummies.init()
