--[[
	SpinServer  (ServerScriptService.SpinServer — Script)
	Boots every server system: Golden Spin, Tusk, NPCs and Studio test dummies.
]]

local ProjectileService = require(script.ProjectileService)
local SpinService = require(script.SpinService)
local TuskService = require(script.TuskService)
local NPCService = require(script.NPCService)
local TestDummies = require(script.TestDummies)

-- Shared projectile budget (Tusk's barrage fires several nails at once).
ProjectileService.MaxActivePerPlayer = 12

SpinService.init()
TuskService.init()
NPCService.init()
TestDummies.init()
