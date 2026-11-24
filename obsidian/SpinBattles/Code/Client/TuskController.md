---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient"
updated: 2026-11-22
---
# TuskController

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| **Exact name** | `TuskController` (capitals matter) |

**What it does:** ("TuskAbilityController" in the design doc)

## How to add it
1. In Studio's Explorer, find **SpinClient** (StarterPlayer › StarterPlayerScripts › SpinClient).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **TuskController**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskController  (StarterPlayerScripts.SpinClient.TuskController)
	("TuskAbilityController" in the design doc)

	Local input for Tusk, and the router for Tusk visual events.
	  PC:         M1 = left click (hold to keep attacking), 1 / 2 / 3 = abilities,
	              G = ultimate, C = sneak, T = Act menu
	  Controller: RB, X / Y / B, D-pad up, LB, D-pad down
	  Mobile:     HUD buttons (slots, ultimate bar, sneak chip) + on-screen M1

	Sends only intents + aim direction. The server validates everything.
	Inputs are bound only while the local character has Tusk equipped, so
	other movesets keep their keys.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)
local TuskAnimation = require(script.Parent.TuskAnimation)
local TuskSneakController = require(script.Parent.TuskSneakController)
local TuskActCommon = require(script.Parent.TuskActCommon)
local TuskUI = require(script.Parent.UI.TuskUI)

local TuskController = {}

local player = Players.LocalPlayer
local Request
local actVFX = {}
local bound = false
local m1Held = false
local nextM1 = 0

local function aim()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return nil
	end
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch or string.find(last.Name, "Gamepad") then
		return camera.CFrame.LookVector
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, VFXLib.Folder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local target = hit and hit.Position or ray.Origin + ray.Direction * 600
	local origin = (root.CFrame * CFrame.new(0.9, 0.55, -1.5)).Position
	-- Steering a remote Stand (John Rod): aim from it, not from you.
	local remote = character:GetAttribute("StandRemotePos")
	if typeof(remote) == "Vector3" then
		origin = remote
	end
	local dir = target - origin
	return dir.Magnitude > 1 and dir.Unit or root.CFrame.LookVector
end

local function currentAct()
	local character = player.Character
	return character and character:GetAttribute("TuskAct")
end

function TuskController.ability(slot, began)
	local act = currentAct()
	local info = act and Registry.get(act)
	if not info then
		return
	end
	local kind = info.AbilityKinds[slot]
	if began then
		Request:FireServer("Ability", slot, "Press", aim())
	elseif kind == "Hold" then
		Request:FireServer("Ability", slot, "Release", aim())
	end
end

function TuskController.ultimate()
	Request:FireServer("Ultimate", aim())
end

function TuskController.toggleSneak()
	local character = player.Character
	local sneaking = character and character:GetAttribute("TuskSneaking") == true
	Request:FireServer("Sneak", not sneaking)
end

function TuskController.select(act)
	Request:FireServer("Select", act)
end

local function m1()
	Request:FireServer("M1", aim())
end

local ACTIONS = {
	TuskM1 = function(state)
		if state == Enum.UserInputState.Begin then
			m1Held = true
			nextM1 = 0
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			m1Held = false
		end
	end,
	TuskAbility1 = function(state)
		TuskController.ability(1, state == Enum.UserInputState.Begin)
	end,
	TuskAbility2 = function(state)
		TuskController.ability(2, state == Enum.UserInputState.Begin)
	end,
	TuskAbility3 = function(state)
		TuskController.ability(3, state == Enum.UserInputState.Begin)
	end,
	TuskUltimate = function(state)
		if state == Enum.UserInputState.Begin then
			TuskController.ultimate()
		end
	end,
	TuskSneak = function(state)
		if state == Enum.UserInputState.Begin then
			TuskController.toggleSneak()
		end
	end,
}

local KEYMAP = {
	TuskM1 = "M1",
	TuskAbility1 = "Ability1",
	TuskAbility2 = "Ability2",
	TuskAbility3 = "Ability3",
	TuskUltimate = "Ultimate",
	TuskSneak = "Sneak",
}

local function bindAll()
	if bound then
		return
	end
	bound = true
	for actionName, handler in pairs(ACTIONS) do
		local keys = TuskConfig.Keys[KEYMAP[actionName]]
		ContextActionService:BindAction(actionName, function(_, state)
			if state == Enum.UserInputState.End and actionName ~= "TuskM1" and not string.find(actionName, "Ability") then
				return Enum.ContextActionResult.Sink
			end
			handler(state)
			return Enum.ContextActionResult.Sink
		end, actionName == "TuskM1", keys.Keyboard, keys.Gamepad)
	end
	ContextActionService:SetTitle("TuskM1", "M1")
	ContextActionService:SetPosition("TuskM1", UDim2.new(1, -95, 1, -95))
	TuskAnimation.applyLocomotion(player.Character, true)
end

local function unbindAll()
	if not bound then
		return
	end
	bound = false
	m1Held = false
	for actionName in pairs(ACTIONS) do
		ContextActionService:UnbindAction(actionName)
	end
	TuskAnimation.applyLocomotion(player.Character, false)
end

function TuskController.init()
	Request = Net.get("TuskRequest")
	local FX = Net.get("TuskFX")

	local actsFolder = script.Parent:WaitForChild("TuskActVFX")
	for act, info in pairs(Registry.Acts) do
		local m = actsFolder:FindFirstChild(info.ClientModule or ("Act" .. act))
		if m then
			actVFX[act] = require(m)
		end
	end

	TuskUI.init({
		Ability = TuskController.ability,
		Ultimate = TuskController.ultimate,
		Sneak = TuskController.toggleSneak,
		Select = TuskController.select,
	})

	FX.OnClientEvent:Connect(function(name, data)
		if typeof(data) ~= "table" then
			return
		end
		if name == "TuskState" then
			TuskUI.onState(data)
		elseif name == "SneakAttack" then
			TuskSneakController.handle(name, data)
		elseif name == "Evolve" then
			TuskActCommon.evolve(data)
			TuskUI.onEvolve(data)
		else
			local m = actVFX[data.Act]
			if m then
				m.handle(name, data)
			end
		end
	end)

	-- Act menu key works whether or not Tusk is equipped.
	ContextActionService:BindAction("TuskActMenu", function(_, state)
		if state == Enum.UserInputState.Begin and TuskConfig.Progression.ShowSelectionMenu then
			TuskUI.toggleMenu()
		end
		return Enum.ContextActionResult.Sink
	end, false, TuskConfig.Keys.ActMenu.Keyboard, TuskConfig.Keys.ActMenu.Gamepad)

	RunService.RenderStepped:Connect(function(dt)
		local act = currentAct()
		if act and not bound then
			bindAll()
		elseif not act and bound then
			unbindAll()
		end
		if m1Held and bound and os.clock() >= nextM1 then
			nextM1 = os.clock() + 0.12
			m1()
		end
		for _, m in pairs(actVFX) do
			if m.step then
				m.step(dt)
			end
		end
		TuskUI.step(act)
	end)

	player.CharacterAdded:Connect(function()
		bound = false
		m1Held = false
	end)
end

return TuskController
```
