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
local GyroOutfit = require(script.GyroOutfit)
local DiegoOutfit = require(script.DiegoOutfit)
local PorkPieOutfit = require(script.PorkPieOutfit)
local SandmanOutfit = require(script.SandmanOutfit)
local MountainTimOutfit = require(script.MountainTimOutfit)
local HotPantsOutfit = require(script.HotPantsOutfit)
local StandBots = require(script.StandBots)
local BountyService = require(script.BountyService)

-- Shared projectile budget (barrages and wrecking balls fire several at once).
ProjectileService.MaxActivePerPlayer = 20

StandAssetLoader.init()
TuskService.init()
GyroOutfit.init()
DiegoOutfit.init()
PorkPieOutfit.init()
SandmanOutfit.init()
MountainTimOutfit.init()
HotPantsOutfit.init()
StandBots.init(TuskService)
BountyService.init()
NPCService.init()
TestDummies.init()
