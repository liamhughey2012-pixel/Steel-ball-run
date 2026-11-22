--[[
	SpinClient  (StarterPlayer.StarterPlayerScripts.SpinClient — LocalScript)
	Boots the client half of the Golden Spin / Steel Ball system.
]]

local SpinMeter = require(script.UI.SpinMeter)
local SpinVFX = require(script.SpinVFX)
local SpinController = require(script.SpinController)

SpinMeter.init()
SpinVFX.init()
SpinController.init()
