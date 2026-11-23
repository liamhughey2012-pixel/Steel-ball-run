---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient"
updated: 2026-11-22
---
# WeatherClient

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| **Exact name** | `WeatherClient` (capitals matter) |

**What it does:** Draws the server's rain (WeatherService sets ReplicatedStorage SpinRaining): falling streaks around your camera, a grey-blue tint and fog, an optional looping rain sound (TuskConfig.Sounds.Rain), and a banner when it starts and stops. Everything fades in and out. Blackmore players get a hint: double-jump to walk on the raindrops.

## How to add it
1. In Studio's Explorer, find **SpinClient** (StarterPlayer › StarterPlayerScripts › SpinClient).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **WeatherClient**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	WeatherClient  (StarterPlayerScripts.SpinClient.WeatherClient)

	Draws the server's rain (WeatherService sets ReplicatedStorage
	SpinRaining): falling streaks around your camera, a grey-blue tint and
	fog, an optional looping rain sound (TuskConfig.Sounds.Rain), and a
	banner when it starts and stops. Everything fades in and out.
	Blackmore players get a hint: double-jump to walk on the raindrops.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)

local WeatherClient = {}

local player = Players.LocalPlayer
local STREAKS = 160
local AREA = 70 -- streaks fall within this many studs of the camera
local FALL = 95 -- studs per second
local RAIN_COLOR = Color3.fromRGB(200, 215, 235)

local folder
local pool = {}
local intensity = 0 -- 0 = clear, 1 = full rain
local tint, sound
local clear -- the lighting before the rain (restored after)
local banner, bannerTitle, bannerSub
local bannerToken

function WeatherClient.isRaining()
	return ReplicatedStorage:GetAttribute("SpinRaining") == true
end

local function newStreak()
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Glass
	p.Color = RAIN_COLOR
	p.Transparency = 1
	p.Size = Vector3.new(0.07, 2.2, 0.07)
	p.Parent = folder
	return p
end

local function reset(s, center, fresh)
	local a = math.random() * math.pi * 2
	local r = math.sqrt(math.random()) * AREA
	s.Offset = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	s.Y = center.Y + (fresh and (math.random() * 70 - 25) or (30 + math.random() * 15))
end

local function showBanner(title, sub)
	if not banner then
		return
	end
	local token = {}
	bannerToken = token
	bannerTitle.Text = title
	bannerSub.Text = sub or ""
	banner.Visible = true
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if bannerToken ~= token then
			conn:Disconnect()
			return
		end
		local t = os.clock() - start
		local alpha
		if t < 0.4 then
			alpha = t / 0.4
		elseif t < 3.6 then
			alpha = 1
		else
			alpha = math.max(0, 1 - (t - 3.6) / 0.6)
		end
		bannerTitle.TextTransparency = 1 - alpha
		bannerTitle.TextStrokeTransparency = 1 - alpha * 0.6
		bannerSub.TextTransparency = 1 - alpha
		banner.Position = UDim2.new(0.5, 0, 0, 70 - 12 * (1 - math.min(t / 0.4, 1)))
		if t > 4.2 then
			banner.Visible = false
			conn:Disconnect()
		end
	end)
end

local function isBlackmore()
	local c = player.Character
	return c and c:GetAttribute("TuskAct") == 11
end

local function onRainChanged()
	if WeatherClient.isRaining() then
		showBanner("IT'S RAINING", isBlackmore() and "BLACKMORE: double-jump to walk on the raindrops" or "")
	else
		showBanner("THE RAIN STOPS", "")
	end
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

function WeatherClient.step(dt)
	local target = WeatherClient.isRaining() and 1 or 0
	-- Fade over about 3 seconds.
	if intensity ~= target then
		if intensity == 0 then
			clear = { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor }
		end
		intensity = math.clamp(intensity + (target > intensity and dt or -dt) / 3, 0, 1)
	end
	if intensity <= 0 then
		if clear then
			Lighting.FogEnd, Lighting.FogStart, Lighting.FogColor = clear.FogEnd, clear.FogStart, clear.FogColor
			clear = nil
		end
		tint.Enabled = false
		if sound then
			sound.Volume = 0
			if sound.Playing then
				sound:Stop()
			end
		end
		for _, s in ipairs(pool) do
			if s.Part.Transparency ~= 1 then
				s.Part.Transparency = 1
			end
		end
		return
	end
	-- Grey-blue sky and fog.
	tint.Enabled = true
	tint.Saturation = -0.3 * intensity
	tint.Brightness = -0.07 * intensity
	tint.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(205, 215, 235), intensity)
	if clear then
		Lighting.FogColor = clear.FogColor:Lerp(Color3.fromRGB(150, 160, 175), intensity)
		Lighting.FogEnd = lerp(clear.FogEnd, math.min(clear.FogEnd, 420), intensity)
		Lighting.FogStart = lerp(clear.FogStart, math.min(clear.FogStart, 40), intensity)
	end
	if sound then
		if not sound.Playing then
			sound:Play()
		end
		sound.Volume = 0.5 * intensity
	end
	-- The streaks follow the camera; how many show depends on the intensity.
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local center = camera.CFrame.Position
	local active = math.floor(STREAKS * intensity)
	local parts, cframes = {}, {}
	for i, s in ipairs(pool) do
		if i <= active then
			s.Y = s.Y - FALL * dt
			if s.Y < center.Y - 30 then
				reset(s, center, false)
			end
			local pos = Vector3.new(center.X + s.Offset.X, s.Y, center.Z + s.Offset.Z)
			-- Keep them around the camera as it moves.
			if (Vector3.new(pos.X - center.X, 0, pos.Z - center.Z)).Magnitude > AREA then
				reset(s, center, true)
			end
			if s.Part.Transparency ~= 0.45 then
				s.Part.Transparency = 0.45
			end
			table.insert(parts, s.Part)
			table.insert(cframes, CFrame.new(pos) * CFrame.Angles(0, 0, 0.06))
		elseif s.Part.Transparency ~= 1 then
			s.Part.Transparency = 1
		end
	end
	if workspace.BulkMoveTo then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	else
		for i, p in ipairs(parts) do
			p.CFrame = cframes[i]
		end
	end
end

function WeatherClient.init()
	local cfg = TuskConfig.Weather
	if cfg and cfg.Enabled == false then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "SpinRain"
	folder.Parent = workspace
	local center = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or Vector3.new()
	for i = 1, STREAKS do
		local s = { Part = newStreak() }
		reset(s, center, true)
		pool[i] = s
	end
	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "SpinRainTint"
	tint.Enabled = false
	tint.Parent = Lighting
	local id = TuskConfig.Sounds and TuskConfig.Sounds.Rain
	if id and id ~= "" then
		sound = Instance.new("Sound")
		sound.Name = "SpinRain"
		sound.SoundId = id
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = game:GetService("SoundService")
	end

	-- Banner at the top of the screen.
	local gui = Instance.new("ScreenGui")
	gui.Name = "WeatherBanner"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")
	banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 70)
	banner.Size = UDim2.fromOffset(460, 60)
	banner.BackgroundTransparency = 1
	banner.Visible = false
	banner.Parent = gui
	bannerTitle = Instance.new("TextLabel")
	bannerTitle.BackgroundTransparency = 1
	bannerTitle.Size = UDim2.new(1, 0, 0, 36)
	bannerTitle.Font = Enum.Font.Bangers
	bannerTitle.TextSize = 36
	bannerTitle.TextColor3 = Color3.fromRGB(190, 220, 255)
	bannerTitle.TextStrokeColor3 = Color3.fromRGB(20, 30, 50)
	bannerTitle.Parent = banner
	bannerSub = Instance.new("TextLabel")
	bannerSub.BackgroundTransparency = 1
	bannerSub.Position = UDim2.fromOffset(0, 36)
	bannerSub.Size = UDim2.new(1, 0, 0, 18)
	bannerSub.Font = Enum.Font.GothamBold
	bannerSub.TextSize = 13
	bannerSub.TextColor3 = Color3.fromRGB(225, 235, 255)
	bannerSub.TextStrokeTransparency = 0.5
	bannerSub.Parent = banner

	ReplicatedStorage:GetAttributeChangedSignal("SpinRaining"):Connect(onRainChanged)
	if WeatherClient.isRaining() then
		onRainChanged()
	end
	RunService.RenderStepped:Connect(WeatherClient.step)
end

return WeatherClient
```
