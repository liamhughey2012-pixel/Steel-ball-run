--[[
	SpinServer  (ServerScriptService.SpinServer — Script)
	Boots every server system: characters (Johnny/Tusk, Gyro/Steel Balls),
	custom Stand models, NPCs and Studio test dummies.
]]

local ProjectileService = require(script.ProjectileService)
local TuskService = require(script.TuskService)
local NPCService = require(script.NPCService)
local TestDummies = require(script.TestDummies)
local StandAssetLoader = require(script.StandAssetLoader)
local GyroOutfit = require(script.GyroOutfit)

-- Shared projectile budget (barrages and wrecking balls fire several at once).
ProjectileService.MaxActivePerPlayer = 20

StandAssetLoader.init()
TuskService.init()
GyroOutfit.init()
NPCService.init()
TestDummies.init()
