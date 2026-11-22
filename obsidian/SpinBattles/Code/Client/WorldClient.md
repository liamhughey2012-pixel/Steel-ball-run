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

**What it does:** Client side of the SBR map: NPC speech bubbles (from NPCService "NPCSay"), shown within 60 studs drifting desert dust around the camera when the SBRMap is present (particle count follows VFXQuality) map life (client-only, no server cost): spinning windmills (tag "SpinWindmill"), circling vultures, rolling tumbleweeds, dust devils

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
	  * map life (client-only, no server cost): spinning windmills (tag
	    "SpinWindmill"), circling vultures, rolling tumbleweeds, dust devils
]]

local CollectionService = game:GetService("CollectionService")
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

---------------------------------------------------------------------------
-- Map life
---------------------------------------------------------------------------
local function startLife(map)
	local origin = map:GetAttribute("Origin") or Vector3.new()
	local quality = VFXQuality.get()

	-- Vultures circling high over the desert.
	local vultures = {}
	for i = 1, (quality.Particles >= 0.6 and 5 or 2) do
		local bird = Instance.new("Model")
		bird.Name = "Vulture"
		local body = VFXLib.part({ Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(35, 30, 30), Size = Vector3.new(0.8, 0.6, 2) })
		body.Parent = bird
		for _, side in ipairs({ -1, 1 }) do
			local wing = VFXLib.part({ Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(25, 22, 22), Size = Vector3.new(3.2, 0.12, 1.2) })
			wing.Name = side < 0 and "WingL" or "WingR"
			wing.Parent = bird
		end
		bird.Parent = VFXLib.Folder
		vultures[i] = { Model = bird, Center = origin + Vector3.new(math.random(-200, 200), 0, math.random(-200, 200)), Radius = math.random(30, 70), Height = math.random(90, 130), Speed = 0.15 + math.random() * 0.1, Phase = math.random() * 6 }
	end

	-- Tumbleweeds rolling with the wind near the camera.
	local weeds = {}
	local function newWeed()
		local camera = workspace.CurrentCamera
		local base = camera and camera.CFrame.Position or origin
		local size = 1.6 + math.random() * 1.4
		local weed = VFXLib.part({ Shape = Enum.PartType.Ball, Material = Enum.Material.Grass, Color = Color3.fromRGB(150, 120, 75), Size = Vector3.new(size, size, size), Transparency = 0.15 })
		return { Part = weed, Pos = Vector3.new(base.X - 90, 0, base.Z + math.random(-70, 70)), Size = size, Speed = 10 + math.random() * 8, Spin = 0, Life = 0 }
	end
	for i = 1, (quality.Particles >= 0.6 and 6 or 2) do
		weeds[i] = newWeed()
		weeds[i].Pos = weeds[i].Pos + Vector3.new(math.random(0, 160), 0, 0)
	end

	-- Dust devils: a swirling smoke column drifting slowly.
	local devils = {}
	if quality.Particles >= 0.6 then
		for i = 1, 2 do
			local carrier = VFXLib.part({ Transparency = 1, Size = Vector3.new(4, 18, 4) })
			local e = Instance.new("ParticleEmitter")
			e.Texture = VFXLib.Textures.Smoke
			e.Color = ColorSequence.new(Color3.fromRGB(215, 190, 145))
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.7), NumberSequenceKeypoint.new(1, 1) })
			e.Lifetime = NumberRange.new(2, 3)
			e.Speed = NumberRange.new(3, 6)
			e.RotSpeed = NumberRange.new(200, 300)
			e.Rate = 14
			e.EmissionDirection = Enum.NormalId.Top
			e.Shape = Enum.ParticleEmitterShape.Cylinder
			e.Parent = carrier
			devils[i] = { Part = carrier, Pos = origin + Vector3.new(math.random(-350, 350), 9, math.random(-350, 350)), Dir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit }
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		-- Windmills
		for _, hub in ipairs(CollectionService:GetTagged("SpinWindmill")) do
			if hub:IsA("BasePart") and hub:IsDescendantOf(workspace) then
				hub.CFrame = hub.CFrame * CFrame.Angles(0, 0, dt * 1.4)
			end
		end
		-- Vultures
		for _, v in ipairs(vultures) do
			local a = t * v.Speed + v.Phase
			local pos = v.Center + Vector3.new(math.cos(a) * v.Radius, v.Height + math.sin(t * 0.7 + v.Phase) * 4, math.sin(a) * v.Radius)
			local ahead = v.Center + Vector3.new(math.cos(a + 0.05) * v.Radius, v.Height, math.sin(a + 0.05) * v.Radius)
			local cf = CFrame.lookAt(pos, ahead) * CFrame.Angles(0, 0, 0.35)
			local flap = math.sin(t * 3 + v.Phase) * 0.25
			local parts = v.Model:GetChildren()
			for _, p in ipairs(parts) do
				if p.Name == "WingL" then
					p.CFrame = cf * CFrame.new(-1.7, 0, 0) * CFrame.Angles(0, 0, flap)
				elseif p.Name == "WingR" then
					p.CFrame = cf * CFrame.new(1.7, 0, 0) * CFrame.Angles(0, 0, -flap)
				else
					p.CFrame = cf
				end
			end
		end
		-- Tumbleweeds
		for i, w in ipairs(weeds) do
			w.Life = w.Life + dt
			w.Pos = w.Pos + Vector3.new(w.Speed * dt, 0, math.sin(t + i) * dt * 2)
			local ground = workspace:Raycast(w.Pos + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0), params)
			local y = (ground and ground.Position.Y or 0) + w.Size / 2 + math.abs(math.sin(w.Life * 3)) * 1.2
			w.Spin = w.Spin + dt * w.Speed / w.Size
			w.Part.CFrame = CFrame.new(w.Pos.X, y, w.Pos.Z) * CFrame.Angles(0, 0, -w.Spin)
			local camera = workspace.CurrentCamera
			if w.Life > 22 or (camera and (camera.CFrame.Position - w.Pos).Magnitude > 220) then
				w.Part:Destroy()
				weeds[i] = newWeed()
			end
		end
		-- Dust devils
		for _, d in ipairs(devils) do
			d.Pos = d.Pos + d.Dir * dt * 4
			if (d.Pos - origin).Magnitude > 450 then
				d.Dir = -d.Dir
			end
			d.Part.CFrame = CFrame.new(d.Pos)
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
		local map = workspace:WaitForChild("SBRMap", 60)
		if map then
			startDust()
			startLife(map)
		end
	end)
end

return WorldClient
```
