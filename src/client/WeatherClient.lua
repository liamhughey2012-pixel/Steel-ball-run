--[[
	WeatherClient  (StarterPlayerScripts.SpinClient.WeatherClient)

	Draws the server's rain (WeatherService sets ReplicatedStorage
	SpinRaining): falling streaks around your camera, a grey-blue tint and
	fog, an optional looping rain sound (TuskConfig.Sounds.Rain), and a
	banner when it starts and stops: a nailed wooden sign in the bounty
	board's style (UI.UITheme) that pops in and fades out. Everything fades
	in and out. Blackmore players get a hint on a pinned parchment strip
	under it: double-jump to walk on the raindrops.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local UITheme = require(script.Parent.UI.UITheme)

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
local banner, bannerTitle, bannerSub, bannerHint
local bannerToken
local bannerParts = {} -- { Object, Property, Base } faded together

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
	bannerHint.Visible = (sub or "") ~= ""
	banner.Visible = true
	UITheme.pop(banner, 0.7)
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
		-- The whole sign (wood, parchment, text, strokes) fades as one.
		for _, e in ipairs(bannerParts) do
			e[1][e[2]] = e[3] + (1 - e[3]) * (1 - alpha)
		end
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

	-- Banner at the top of the screen: a nailed wooden sign with the news,
	-- and (for Blackmore) a pinned parchment hint under it.
	local new = UITheme.new
	local gui = Instance.new("ScreenGui")
	gui.Name = "WeatherBanner"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	banner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(460, 72), BackgroundTransparency = 1, Visible = false }, gui)
	local sign = new("Frame", { Name = "Sign", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(280, 42) }, banner)
	UITheme.wood(sign, { Planks = 1, Border = 4, Radius = 7, Brackets = true, BracketSize = 12 })
	bannerTitle = UITheme.label(sign, { Name = "Title", Position = UDim2.fromOffset(18, 4), Size = UDim2.new(1, -36, 1, -8), Text = "", Font = UITheme.Font.Title, TextColor3 = Color3.fromRGB(190, 220, 255), TextStrokeColor3 = UITheme.C.WOOD_EDGE, TextStrokeTransparency = 0.3, ZIndex = 3 })
	bannerHint = new("Frame", { Name = "Hint", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(380, 22), Visible = false }, banner)
	UITheme.paper(bannerHint, { Radius = 3 })
	local pin = new("Frame", { BackgroundColor3 = UITheme.C.RED, Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 8, 0, -3), ZIndex = 3 }, bannerHint)
	UITheme.corner(pin, 99)
	bannerSub = UITheme.label(bannerHint, { Name = "Text", Position = UDim2.fromOffset(22, 3), Size = UDim2.new(1, -30, 1, -6), Text = "", Font = UITheme.Font.Body, TextColor3 = UITheme.C.INK, ZIndex = 2 })
	-- Remember every visible bit's resting transparency, to fade them together.
	for _, d in ipairs(banner:GetDescendants()) do
		if d:IsA("TextLabel") then
			table.insert(bannerParts, { d, "TextTransparency", d.TextTransparency or 0 })
			table.insert(bannerParts, { d, "TextStrokeTransparency", d.TextStrokeTransparency or 0 })
		elseif d:IsA("Frame") then
			table.insert(bannerParts, { d, "BackgroundTransparency", d.BackgroundTransparency or 0 })
		elseif d:IsA("UIStroke") then
			table.insert(bannerParts, { d, "Transparency", d.Transparency or 0 })
		end
	end

	ReplicatedStorage:GetAttributeChangedSignal("SpinRaining"):Connect(onRainChanged)
	if WeatherClient.isRaining() then
		onRainChanged()
	end
	RunService.RenderStepped:Connect(WeatherClient.step)
end

return WeatherClient
