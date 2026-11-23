--[[
	DefenseClient  (StarterPlayerScripts.SpinClient.DefenseClient)

	Block and Dash on the client, for every character:
	  * input: hold F (controller L2) to block, Q (controller R2) to dash,
	    on-screen buttons on mobile. Intents only: the server decides.
	  * DASH: when the server grants it, this client moves its own character
	    (smooth, and it replicates). Everyone sees a dust burst, afterimages
	    and a dash pose (forward / back / left / right).
	  * BLOCK: anyone blocking holds a guard pose with a blue shield in front.
	  * PERFECT BLOCK: gold flash and "PERFECT!" on the defender, the attacker
	    reels. GUARD BREAK: the shield shatters, "GUARD BREAK" and a stagger.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)
local CameraFX = require(script.Parent.CameraFX)
local TuskVFX = require(script.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.TuskAnimation)
local Fighters = require(script.Parent.Fighters)

local DefenseClient = {}
local player = Players.LocalPlayer
local sounds = TuskConfig.Sounds
local SHIELD = Color3.fromRGB(110, 180, 255)
local SHIELD_LIGHT = Color3.fromRGB(210, 235, 255)
local GOLD = Color3.fromRGB(255, 210, 80)

local Request
local blocking = {} -- [character] = { Shield, Previous hold }
local blockHeld = false

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
local function moveDirection()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
		return humanoid.MoveDirection
	end
	return root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
end

local function onBlock(_, state)
	if state == Enum.UserInputState.Begin then
		blockHeld = true
		Request:FireServer("Block", true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if blockHeld then
			blockHeld = false
			Request:FireServer("Block", false)
		end
	end
	return Enum.ContextActionResult.Sink
end

local function onDashInput(_, state)
	if state == Enum.UserInputState.Begin then
		Request:FireServer("Dash", moveDirection())
	end
	return Enum.ContextActionResult.Sink
end

---------------------------------------------------------------------------
-- Dash
---------------------------------------------------------------------------
local function dashPose(root, direction)
	local look, right = root.CFrame.LookVector, root.CFrame.RightVector
	local f, r = direction:Dot(look), direction:Dot(right)
	if math.abs(f) >= math.abs(r) then
		return f >= 0 and "DashF" or "DashB"
	end
	return r >= 0 and "DashR" or "DashL"
end

local function onDashFX(data)
	local character = data.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local dir = data.Direction
	TuskAnimation.play(character, dashPose(root, dir))
	VFXLib.burst(root.Position - Vector3.new(0, 2.6, 0), { Count = 12, Texture = VFXLib.Textures.Smoke, Color = Color3.fromRGB(215, 190, 150), LightEmission = 0, Speed = 14, Lifetime = 0.6, Spread = 60, Direction = -dir })
	VFXLib.sound(sounds.Swing, root, 0.5, 0.8)
	local steps = 4
	for i = 1, steps do
		task.delay(i * (data.Time or 0.2) / steps, function()
			if root.Parent then
				VFXLib.afterimage(root.CFrame, 2.2, SHIELD_LIGHT)
			end
		end)
	end
	if character ~= player.Character then
		return
	end
	-- Our own character: move it ourselves (we own its physics).
	local speed, time = data.Speed or 75, data.Time or 0.2
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	VFXLib.animate(time, function()
		if not root.Parent or (humanoid and humanoid.Health <= 0) then
			return
		end
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, math.min(v.Y, 0), dir.Z * speed)
	end, function()
		if root.Parent then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(dir.X * 12, v.Y, dir.Z * 12)
		end
	end)
	CameraFX.fovPunch(5, 0.2)
end

---------------------------------------------------------------------------
-- Block visuals
---------------------------------------------------------------------------
local function makeShield()
	local m = Instance.new("Model")
	m.Name = "BlockShield"
	m.Parent = VFXLib.Folder
	-- A blocky shield of glowing panes in front of the body.
	for _, pane in ipairs({ { 0, 0, 3.2, 3.6 }, { -1.9, 0, 0.9, 3 }, { 1.9, 0, 0.9, 3 } }) do
		local p = VFXLib.part({ Material = Enum.Material.ForceField, Color = SHIELD, Size = Vector3.new(pane[3], pane[4], 0.2), Transparency = 0.15 })
		p.Parent = m
		p:SetAttribute("Offset", CFrame.new(pane[1], pane[2], -1.9) * CFrame.Angles(0, pane[1] * -0.35, 0))
	end
	return m
end

local function placeShield(entry, root, t)
	local meter = entry.Character:GetAttribute("BlockMeter") or (TuskConfig.Defense and TuskConfig.Defense.MaxMeter) or 100
	local k = math.clamp(meter / ((TuskConfig.Defense and TuskConfig.Defense.MaxMeter) or 100), 0, 1)
	for _, p in ipairs(entry.Shield:GetChildren()) do
		p.CFrame = root.CFrame * p:GetAttribute("Offset") * CFrame.new(0, math.sin(t * 6) * 0.05, 0)
		-- The shield reddens as the guard bar runs out.
		p.Color = SHIELD:Lerp(Color3.fromRGB(255, 80, 70), 1 - k)
	end
end

local function startBlock(character)
	local entry = { Character = character, Shield = makeShield(), Previous = TuskAnimation.currentHold(character) }
	blocking[character] = entry
	TuskAnimation.hold(character, "BlockPose")
	return entry
end

local function stopBlock(character, entry)
	blocking[character] = nil
	entry.Shield:Destroy()
	TuskAnimation.stopHold(character, "BlockPose")
	if entry.Previous and entry.Previous ~= "BlockPose" and character.Parent then
		TuskAnimation.hold(character, entry.Previous) -- back to the character's stance
	end
end

local function stepBlocks()
	local t = os.clock()
	local seen = {}
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and character:GetAttribute("Blocking") then
			seen[character] = true
			local entry = blocking[character] or startBlock(character)
			placeShield(entry, root, t)
		end
	end
	for character, entry in pairs(blocking) do
		if not seen[character] then
			stopBlock(character, entry)
		end
	end
end

local function popText(position, text, color)
	local carrier = VFXLib.anchor(CFrame.new(position + Vector3.new(0, 3, 0)), 1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = carrier
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local start = carrier.Position
	VFXLib.animate(0.9, function(a)
		carrier.Position = start + Vector3.new(0, a * 2, 0)
		label.TextTransparency = math.max(0, (a - 0.6) / 0.4)
		label.TextStrokeTransparency = label.TextTransparency
		local pop = a < 0.12 and 1 + (0.12 - a) * 5 or 1
		gui.Size = UDim2.fromOffset(220 * pop, 60 * pop)
	end)
end

local function onParry(data)
	local defender = data.Defender
	local root = defender and defender:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	TuskAnimation.play(defender, "Parry")
	local pos = (root.CFrame * CFrame.new(0, 0.5, -1.8)).Position
	TuskVFX.CreateImpactStar(pos, { Size = 7, Rays = 10, Color = GOLD, Color2 = Color3.new(1, 1, 1), Duration = 0.3 })
	VFXLib.burst(pos, { Count = 24, Color = GOLD, Speed = 40, Lifetime = 0.4 })
	VFXLib.flash(pos, GOLD, 5, 20, 0.25)
	TuskVFX.CreateRotationalShockwave(CFrame.lookAt(pos, pos + root.CFrame.LookVector) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = 4, Layers = 2, Color = GOLD, Color2 = Color3.new(1, 1, 1), Particles = 0.5, Width = 0.2, Duration = 0.3 })
	popText(root.Position, "PERFECT!", GOLD)
	VFXLib.sound(sounds.Finisher, pos, 0.6, 1.4)
	if data.Attacker then
		TuskAnimation.play(data.Attacker, "GuardBreak")
	end
	if defender == player.Character or data.Attacker == player.Character then
		CameraFX.impactFrame(GOLD)
		CameraFX.shake(0.4, 0.25)
	end
end

local function onGuardBreak(data)
	local victim = data.Victim
	local root = victim and victim:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	TuskAnimation.play(victim, "GuardBreak")
	local pos = (root.CFrame * CFrame.new(0, 0.5, -1.8)).Position
	-- The shield shatters into blue shards.
	VFXLib.burst(pos, { Count = 30, Color = SHIELD, Speed = 35, Lifetime = 0.6, Acceleration = Vector3.new(0, -40, 0) })
	VFXLib.burst(pos, { Count = 10, Color = SHIELD_LIGHT, Speed = 12, Lifetime = 0.25, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) }) })
	popText(root.Position, "GUARD BREAK", Color3.fromRGB(255, 90, 80))
	VFXLib.sound(sounds.NailImpact, pos, 0.6, 0.7)
	if victim == player.Character then
		CameraFX.shake(0.6, 0.4)
	end
end

---------------------------------------------------------------------------
function DefenseClient.init()
	Request = Net.get("TuskRequest")
	local keys = TuskConfig.Keys
	ContextActionService:BindAction("SpinBlock", onBlock, true, keys.Block.Keyboard, keys.Block.Gamepad)
	ContextActionService:SetTitle("SpinBlock", "BLOCK")
	ContextActionService:SetPosition("SpinBlock", UDim2.new(1, -170, 1, -70))
	ContextActionService:BindAction("SpinDash", onDashInput, true, keys.Dash.Keyboard, keys.Dash.Gamepad)
	ContextActionService:SetTitle("SpinDash", "DASH")
	ContextActionService:SetPosition("SpinDash", UDim2.new(1, -95, 1, -165))
	player.CharacterAdded:Connect(function()
		blockHeld = false
	end)
	Net.get("TuskFX").OnClientEvent:Connect(function(name, data)
		if name == "Dash" and typeof(data) == "table" then
			onDashFX(data)
		end
	end)
	Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
		if typeof(data) ~= "table" then
			return
		end
		if name == "Parry" then
			onParry(data)
		elseif name == "GuardBreak" then
			onGuardBreak(data)
		end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc = acc + dt
		for character, entry in pairs(blocking) do
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				placeShield(entry, root, os.clock())
			end
		end
		if acc >= 0.1 then
			acc = 0
			stepBlocks()
		end
	end)
end

return DefenseClient
