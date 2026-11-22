---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# TestDummies

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `TestDummies` (capitals matter) |

**What it does:** Studio-only practice targets so Spin can be tested solo. Never runs in a live server (guarded by RunService:IsStudio()). Turn off with SpinConfig.Debug.SpawnTestDummies = false.

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **TestDummies**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
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
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
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
```
