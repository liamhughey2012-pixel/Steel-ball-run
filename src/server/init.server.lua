--[[
	SpinServer  (ServerScriptService.SpinServer — Script)
	Boots the server half of the Golden Spin / Steel Ball system.
]]

local SpinService = require(script.SpinService)
local TestDummies = require(script.TestDummies)
local ProjectileService = require(script.ProjectileService)
local SpinConfig = require(game:GetService("ReplicatedStorage").SpinShared.SpinConfig)

ProjectileService.MaxActivePerPlayer = SpinConfig.Projectile.MaxActivePerPlayer
SpinService.init()
TestDummies.init()
