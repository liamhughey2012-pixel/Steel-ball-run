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

SpinMeter.init()
SpinVFX.init()
SpinController.init()
TuskStand.init()
TuskProjectiles.init()
TuskSneakController.init()
TuskController.init()
WorldClient.init()
