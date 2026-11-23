--[[
	TestDummies  (ServerScriptService.SpinServer.TestDummies)
	Studio-only practice targets so Spin can be tested solo.
	Never runs in a live server (guarded by RunService:IsStudio()).
	Turn off with SpinConfig.Debug.SpawnTestDummies = false.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SpinConfig = require(game:GetService("ReplicatedStorage").SpinShared.SpinConfig)

local TestDummies = {}

local function findSpawn()
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.CFrame
	end
	return CFrame.new(0, 5, 0)
end

-- Training-dummy look (blocky, built from parts): burlap sack body, straw
-- sticking out of the head and cuffs, a stitched face with button eyes, a
-- red-and-white target on the chest, rope belt, wooden peg feet.
local BURLAP = Color3.fromRGB(196, 160, 108)
local BURLAP_DARK = Color3.fromRGB(150, 116, 74)
local STRAW = Color3.fromRGB(236, 205, 110)
local ROPE = Color3.fromRGB(120, 85, 50)
local RED = Color3.fromRGB(200, 50, 45)
local WHITE = Color3.fromRGB(245, 240, 230)
local INK = Color3.fromRGB(35, 28, 24)
local WOOD = Color3.fromRGB(110, 75, 45)

local function deco(parent, name, size, color, offset)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent.Parent
	return p
end

local function dress(dummy)
	local head = dummy:FindFirstChild("Head")
	local torso = dummy:FindFirstChild("UpperTorso") or dummy:FindFirstChild("Torso")
	local lower = dummy:FindFirstChild("LowerTorso")
	for _, part in ipairs(dummy:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = BURLAP
			part.Material = Enum.Material.Fabric
		end
	end
	if head then
		local face = head:FindFirstChildOfClass("Decal")
		if face then
			face:Destroy()
		end
		local s = head.Size.Y / 1.2
		local front = -head.Size.Z / 2 - 0.02
		-- Button eyes, a stitched mouth, a seam down the middle.
		for _, side in ipairs({ -1, 1 }) do
			deco(head, "Button", Vector3.new(0.26, 0.26, 0.06) * s, INK, CFrame.new(side * 0.24 * s, 0.1 * s, front))
			deco(head, "ButtonHole", Vector3.new(0.06, 0.06, 0.04) * s, BURLAP, CFrame.new(side * 0.24 * s, 0.1 * s, front - 0.04 * s))
		end
		deco(head, "Mouth", Vector3.new(0.6, 0.05, 0.04) * s, INK, CFrame.new(0, -0.26 * s, front))
		for i = -2, 2 do
			deco(head, "Stitch", Vector3.new(0.04, 0.16, 0.04) * s, INK, CFrame.new(i * 0.12 * s, -0.26 * s, front - 0.01 * s))
		end
		deco(head, "Seam", Vector3.new(0.05, head.Size.Y + 0.02, 0.05), BURLAP_DARK, CFrame.new(0, 0, front + 0.01))
		-- Straw sticking out of the top.
		for i = 0, 6 do
			local a = i / 7 * math.pi * 2
			deco(head, "Straw", Vector3.new(0.08, 0.6, 0.08) * s, STRAW, CFrame.new(math.cos(a) * 0.25 * s, head.Size.Y / 2 + 0.15 * s, math.sin(a) * 0.25 * s) * CFrame.Angles(math.sin(a) * 0.6, 0, -math.cos(a) * 0.6))
		end
		deco(head, "Tie", Vector3.new(0.5, 0.1, 0.5) * s, ROPE, CFrame.new(0, head.Size.Y / 2 - 0.02, 0))
	end
	if torso then
		local z = -torso.Size.Z / 2 - 0.03
		-- Target on the chest.
		deco(torso, "Target", Vector3.new(1.3, 1.3, 0.05), RED, CFrame.new(0, 0.1, z))
		deco(torso, "Target", Vector3.new(0.95, 0.95, 0.05), WHITE, CFrame.new(0, 0.1, z - 0.01))
		deco(torso, "Target", Vector3.new(0.6, 0.6, 0.05), RED, CFrame.new(0, 0.1, z - 0.02))
		deco(torso, "Target", Vector3.new(0.25, 0.25, 0.05), WHITE, CFrame.new(0, 0.1, z - 0.03))
		deco(torso, "Patch", Vector3.new(0.5, 0.4, 0.05), BURLAP_DARK, CFrame.new(-0.55, -0.55, z) * CFrame.Angles(0, 0, 0.2))
	end
	local waist = lower or torso
	if waist then
		local y = lower and 0 or -torso.Size.Y / 2 + 0.1
		deco(waist, "Rope", Vector3.new(waist.Size.X + 0.12, 0.2, waist.Size.Z + 0.12), ROPE, CFrame.new(0, y, 0))
		deco(waist, "RopeKnot", Vector3.new(0.3, 0.45, 0.15), ROPE, CFrame.new(0.4, y - 0.15, -waist.Size.Z / 2 - 0.08))
	end
	-- Straw cuffs at the wrists, wooden pegs for feet.
	for _, name in ipairs({ "LeftHand", "RightHand", "Left Arm", "Right Arm" }) do
		local hand = dummy:FindFirstChild(name)
		if hand then
			deco(hand, "Straw", Vector3.new(hand.Size.X + 0.15, 0.2, hand.Size.Z + 0.15), STRAW, CFrame.new(0, hand.Size.Y / 2 - 0.05, 0))
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }) do
		local foot = dummy:FindFirstChild(name)
		if foot then
			deco(foot, "Peg", Vector3.new(foot.Size.X + 0.05, 0.35, foot.Size.Z + 0.05), WOOD, CFrame.new(0, -foot.Size.Y / 2 + 0.15, 0))
		end
	end
	for _, d in ipairs(dummy:GetChildren()) do
		if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end
end

local function spawnDummy(folder, cframe, index)
	local ok, dummy = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not dummy then
		warn("[TestDummies] could not create dummy:", dummy)
		return
	end
	dummy.Name = "SpinDummy" .. index
	dummy:PivotTo(cframe)
	pcall(dress, dummy)
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.DisplayName = "Training Dummy"
	humanoid.MaxHealth = 150
	humanoid.Health = 150
	dummy.Parent = folder
	humanoid.Died:Connect(function()
		task.wait(SpinConfig.Debug.DummyRespawnTime)
		dummy:Destroy()
		spawnDummy(folder, cframe, index)
	end)
end

function TestDummies.init()
	if not RunService:IsStudio() or not SpinConfig.Debug.SpawnTestDummies then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "SpinTestDummies"
	folder.Parent = workspace
	local base = findSpawn()
	for i = 1, SpinConfig.Debug.DummyCount do
		local offset = CFrame.new((i - (SpinConfig.Debug.DummyCount + 1) / 2) * 8, 3, -30 - i * 6)
		spawnDummy(folder, base * offset * CFrame.Angles(0, math.pi, 0), i)
	end
end

return TestDummies
