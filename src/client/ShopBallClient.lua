--[[
	ShopBallClient  (StarterPlayerScripts.SpinClient.ShopBallClient)

	Client side of the bounty board's THROWABLES (server: ShopBalls).
	  * whoever is holding one (character attribute "HeldThrowable") has the
	    ball in their right hand: a green Zeppeli steel ball or an orange
	    wrecking ball, seen by everyone
	  * your own: a small wooden chip at the bottom of the screen, "STEEL
	    BALL · PRESS X TO THROW"; X (or R3 on a controller) throws it at the
	    mouse / where the camera looks
	  * Gyro's SPIN BOOST: a faint green spiral round him while it lasts
	  * the wrecking ball's burst: an orange blast ring and debris
	The ball in flight is the "GyroBall" projectile, drawn by Gyro.lua.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)
local CameraFX = require(script.Parent.CameraFX)
local TuskVFX = require(script.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.TuskAnimation)
local Fighters = require(script.Parent.Fighters)
local UITheme = require(script.Parent.UI.UITheme)
local C = UITheme.C

local ShopBallClient = {}
local player = Players.LocalPlayer
local ORANGE = Color3.fromRGB(255, 150, 60)
local GREEN = Color3.fromRGB(110, 220, 90)

local held = {} -- [character] = { Kind, Model }
local boosts = {} -- [character] = spiral part
local chip, chipText

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
	local dir = target - root.Position
	return dir.Magnitude > 1 and dir.Unit or root.CFrame.LookVector
end

local function throw()
	local c = player.Character
	if not c or not c:GetAttribute("HeldThrowable") then
		return
	end
	Net.get("TuskRequest"):FireServer("ThrowItem", aim())
end

---------------------------------------------------------------------------
-- The chip on your screen
---------------------------------------------------------------------------
local function buildChip()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopBall"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	chip = Instance.new("TextButton")
	chip.AnchorPoint = Vector2.new(0.5, 1)
	chip.Position = UDim2.new(0.5, 0, 1, -150)
	chip.Size = UDim2.fromOffset(300, 38)
	chip.BackgroundColor3 = C and C.Wood or Color3.fromRGB(92, 58, 32)
	chip.AutoButtonColor = true
	chip.Text = ""
	chip.Visible = false
	chip.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = chip
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(40, 24, 12)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = chip
	chipText = Instance.new("TextLabel")
	chipText.BackgroundTransparency = 1
	chipText.Size = UDim2.fromScale(1, 1)
	chipText.Font = Enum.Font.Bangers
	chipText.TextScaled = true
	chipText.TextColor3 = Color3.fromRGB(255, 236, 200)
	chipText.Parent = chip
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = chipText
	-- Tap it to throw (touch screens).
	chip.Activated:Connect(throw)
	gui.Parent = player:WaitForChild("PlayerGui")
end

---------------------------------------------------------------------------
-- The ball in the hand, and Gyro's boost spiral
---------------------------------------------------------------------------
local function handOf(character)
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

local function dropHeld(character)
	local h = held[character]
	held[character] = nil
	if h and h.Model then
		h.Model:Destroy()
	end
end

-- The ball models come with Gyro's pack; without it, a plain ball.
local models = {}
local function ballModel(kind)
	local name = kind == "Wrecking" and "WreckingBallModel" or "SteelBallModel"
	if models[name] == nil then
		local ok, mod = pcall(function()
			if name == "WreckingBallModel" then
				return require(Shared.WreckingBallModel)
			end
			return require(Shared.SteelBallModel)
		end)
		models[name] = ok and mod or false
	end
	if models[name] then
		return models[name].build(0.9, false)
	end
	local m = Instance.new("Model")
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(0.9, 0.9, 0.9)
	core.Color = kind == "Wrecking" and ORANGE or GREEN
	core.Material = Enum.Material.Metal
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Massless = true
	core.Parent = m
	m.PrimaryPart = core
	return m
end

local function showHeld(character, kind)
	local hand = handOf(character)
	if not hand then
		return
	end
	dropHeld(character)
	local model = ballModel(kind)
	model.Name = "HeldBall"
	local core = model.PrimaryPart
	core.Anchored = false
	model:PivotTo(hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.35, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = core
	weld.Parent = core
	model.Parent = VFXLib.Folder
	held[character] = { Kind = kind, Model = model }
end

local function step()
	local t = workspace:GetServerTimeNow()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character then
			local kind = character:GetAttribute("HeldThrowable")
			local h = held[character]
			if kind and (not h or h.Kind ~= kind) then
				showHeld(character, kind)
			elseif not kind and h then
				dropHeld(character)
			end
			-- Gyro's Spin boost: a faint green spiral.
			local boosted = (character:GetAttribute("SpinBoostUntil") or 0) > t
			local root = character:FindFirstChild("HumanoidRootPart")
			if boosted and root and not boosts[character] then
				local ring = VFXLib.part({ Size = Vector3.new(0.2, 4.6, 4.6), Shape = Enum.PartType.Cylinder, Color = GREEN, Material = Enum.Material.ForceField, Transparency = 0.5 })
				boosts[character] = ring
			elseif not boosted and boosts[character] then
				boosts[character]:Destroy()
				boosts[character] = nil
			end
			local ring = boosts[character]
			if ring and root then
				ring.CFrame = root.CFrame * CFrame.new(0, -2.2 + (os.clock() * 2 % 4.4), 0) * CFrame.Angles(0, os.clock() * 4, math.pi / 2)
			end
		end
	end
	for character in pairs(held) do
		if not character.Parent then
			dropHeld(character)
		end
	end
	for character, ring in pairs(boosts) do
		if not character.Parent then
			ring:Destroy()
			boosts[character] = nil
		end
	end
	-- Your own chip.
	local mine = player.Character and player.Character:GetAttribute("HeldThrowable")
	if chip then
		chip.Visible = mine ~= nil
		if mine then
			chipText.Text = (mine == "Wrecking" and "WRECKING BALL" or "STEEL BALL") .. "  ·  PRESS X TO THROW"
			chipText.TextColor3 = mine == "Wrecking" and Color3.fromRGB(255, 196, 140) or Color3.fromRGB(200, 255, 180)
		end
	end
end

function ShopBallClient.init()
	buildChip()
	local keys = TuskConfig.Keys.ThrowItem or { Keyboard = Enum.KeyCode.X, Gamepad = Enum.KeyCode.ButtonR3 }
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == keys.Keyboard or input.KeyCode == keys.Gamepad then
			throw()
		end
	end)
	Net.get("WorldFX").OnClientEvent:Connect(function(name, data)
		if name ~= "ShopBall" or typeof(data) ~= "table" then
			return
		end
		if data.Phase == "Throw" and typeof(data.Character) == "Instance" then
			TuskAnimation.play(data.Character, "JTFlick")
			dropHeld(data.Character)
		elseif data.Phase == "Burst" and data.Position then
			local r = data.Radius or 11
			TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position), { Radius = r, Layers = 3, Color = ORANGE, Color2 = Color3.fromRGB(255, 220, 120), Particles = 1, Width = 0.6 })
			VFXLib.burst(data.Position, { Count = 20, Color = ORANGE, Speed = 26, Lifetime = 0.5, Acceleration = Vector3.new(0, -50, 0) })
			VFXLib.flash(data.Position, Color3.fromRGB(255, 220, 160), r, 20, 0.12)
			CameraFX.shakeAt(data.Position, 0.8, 60)
		end
	end)
	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		timer = timer + dt
		local ring
		for _, r in pairs(boosts) do
			ring = r
		end
		-- (Spirals move every frame; the rest is checked ten times a second.)
		if timer >= 0.1 or ring then
			if timer >= 0.1 then
				timer = 0
			end
			step()
		end
	end)
end

return ShopBallClient
