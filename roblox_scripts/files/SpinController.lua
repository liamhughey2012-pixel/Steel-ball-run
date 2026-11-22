--[[
	SpinController  (StarterPlayerScripts.SpinClient.SpinController)

	Local input for the Golden Spin. Hold to charge, release to throw.
	  PC:         hold R (aims at the mouse)
	  Controller: hold RT (aims where the camera looks)
	  Mobile:     hold the on-screen SPIN button (aims where the camera looks)

	Sends only "Start", "Release" + aim direction, or "Cancel".
	The server decides everything else and answers with SpinState.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local SpinConfig = require(Shared.SpinConfig)
local Net = require(Shared.Net)
local CameraFX = require(script.Parent.CameraFX)
local VFXLib = require(script.Parent.VFXLib)
local SpinMeter = require(script.Parent.UI.SpinMeter)

local SpinController = {}

local player = Players.LocalPlayer
local Request
local charging = false
local chargeStart = 0

local function aliveCharacter()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return character, root
	end
	return nil
end

local function usesCameraAim()
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Touch or string.find(last.Name, "Gamepad") ~= nil
end

local function aimDirection()
	local character, root = aliveCharacter()
	local camera = workspace.CurrentCamera
	if not character or not camera then
		return nil
	end
	local origin = (root.CFrame * SpinConfig.Projectile.SpawnOffset).Position
	if usesCameraAim() then
		return camera.CFrame.LookVector
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, VFXLib.Folder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local target = hit and hit.Position or (ray.Origin + ray.Direction * 600)
	local direction = target - origin
	if direction.Magnitude < 1 then
		return root.CFrame.LookVector
	end
	return direction.Unit
end

local function stopLocal()
	charging = false
	SpinMeter.hideCharge()
	CameraFX.setFovHold(0)
end

local function begin()
	if charging or not aliveCharacter() then
		return
	end
	charging = true
	chargeStart = os.clock()
	Request:FireServer("Start")
	SpinMeter.showCharge()
	CameraFX.setFovHold(-3)
end

local function finish()
	if not charging then
		return
	end
	stopLocal()
	Request:FireServer("Release", aimDirection())
end

local function cancel()
	if not charging then
		return
	end
	stopLocal()
	Request:FireServer("Cancel")
end

local function onState(data)
	local status = data.Status
	if status == "Denied" then
		stopLocal()
		if data.Reason == "Cooldown" then
			SpinMeter.flashDenied(string.format("COOLDOWN %.1fs", data.Remaining or 0))
		else
			SpinMeter.flashDenied("STUNNED")
		end
	elseif status == "Cancelled" then
		stopLocal()
		if data.Reason == "Interrupted" then
			SpinMeter.flashDenied("INTERRUPTED!")
		end
		SpinMeter.startCooldown(data.Cooldown or 0)
	elseif status == "Released" then
		if charging then
			stopLocal() -- server auto-released at max hold
		end
		local level = SpinConfig.Levels[data.Level]
		if data.Perfect then
			SpinMeter.popup("PERFECT SPIN!", SpinConfig.Colors.Perfect, true)
		else
			SpinMeter.popup(level.Name, SpinConfig.Colors.GoldLight, false)
		end
		SpinMeter.startCooldown(data.Cooldown or 0)
	end
end

function SpinController.init()
	Request = Net.get("SpinRequest")
	local FX = Net.get("SpinFX")
	FX.OnClientEvent:Connect(function(name, data)
		if name == "SpinState" then
			onState(data)
		end
	end)

	local input = SpinConfig.Input
	ContextActionService:BindAction(input.ActionName, function(_, state)
		if state == Enum.UserInputState.Begin then
			begin()
		elseif state == Enum.UserInputState.End then
			finish()
		elseif state == Enum.UserInputState.Cancel then
			cancel()
		end
		return Enum.ContextActionResult.Sink
	end, true, input.Keyboard, input.Gamepad)
	ContextActionService:SetTitle(input.ActionName, input.MobileButtonTitle)
	ContextActionService:SetPosition(input.ActionName, input.MobileButtonPosition)

	RunService.RenderStepped:Connect(function()
		if charging then
			SpinMeter.updateCharge(os.clock() - chargeStart)
		end
	end)

	player.CharacterAdded:Connect(function()
		stopLocal()
	end)
end

return SpinController
