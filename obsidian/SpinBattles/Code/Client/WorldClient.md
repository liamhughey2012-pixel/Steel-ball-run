---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient"
updated: 2026-11-22
---
# WorldClient

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| **Exact name** | `WorldClient` (capitals matter) |

**What it does:** Client side of the SBR map: NPC speech bubbles (from NPCService "NPCSay"), shown within 60 studs drifting desert dust around the camera when the SBRMap is present (particle count follows VFXQuality)

## How to add it
1. In Studio's Explorer, find **SpinClient** (StarterPlayer › StarterPlayerScripts › SpinClient).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **WorldClient**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	WorldClient  (StarterPlayerScripts.SpinClient.WorldClient)
	Client side of the SBR map:
	  * NPC speech bubbles (from NPCService "NPCSay"), shown within 60 studs
	  * drifting desert dust around the camera when the SBRMap is present
	    (particle count follows VFXQuality)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local VFXQuality = require(Shared.VFXQuality)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)

local WorldClient = {}
local bubbles = {} -- [npc model] = BillboardGui

local function showBubble(npc, text)
	local head = npc and npc:FindFirstChild("Head")
	local camera = workspace.CurrentCamera
	if not head or not camera or (camera.CFrame.Position - head.Position).Magnitude > 60 then
		return
	end
	if bubbles[npc] then
		bubbles[npc]:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(260, 70)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local frame = Instance.new("TextLabel")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(250, 240, 220)
	frame.TextColor3 = Color3.fromRGB(40, 25, 15)
	frame.Font = Enum.Font.GothamMedium
	frame.TextWrapped = true
	frame.TextSize = 15
	frame.Text = text
	frame.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = frame
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(120, 80, 40)
	s.Thickness = 2
	s.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = frame
	bubbles[npc] = gui
	VFXLib.animate(4.5, function(a)
		local fade = a > 0.85 and (a - 0.85) / 0.15 or 0
		frame.BackgroundTransparency = fade
		frame.TextTransparency = fade
		s.Transparency = fade
	end, function()
		if bubbles[npc] == gui then
			bubbles[npc] = nil
		end
		gui:Destroy()
	end)
end

local function startDust()
	local carrier = VFXLib.anchor(CFrame.new())
	carrier.Size = Vector3.new(80, 20, 80)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Smoke
	emitter.Color = ColorSequence.new(Color3.fromRGB(220, 195, 150))
	emitter.LightInfluence = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.88), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(5, 8)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.EmissionDirection = Enum.NormalId.Right -- drift with the wind
	emitter.Acceleration = Vector3.new(2, 0, 0)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Parent = carrier
	local function rate()
		emitter.Rate = 6 * VFXQuality.get().Particles
	end
	rate()
	VFXQuality.Changed:Connect(rate)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera then
			local p = camera.CFrame.Position
			carrier.CFrame = CFrame.new(p.X, math.max(p.Y - 4, 4), p.Z)
		end
	end)
end

function WorldClient.init()
	Net.get("WorldFX").OnClientEvent:Connect(function(name, data)
		if name == "NPCSay" and typeof(data) == "table" then
			showBubble(data.NPC, tostring(data.Text))
		end
	end)
	task.spawn(function()
		if workspace:WaitForChild("SBRMap", 15) then
			startDust()
		end
	end)
end

return WorldClient
```
