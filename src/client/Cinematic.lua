--[[
	Cinematic  (StarterPlayerScripts.SpinClient.Cinematic)

	Makes the whole game feel more like a film. All client-side, and scaled
	by the VFX setting (Low / Medium / High). Numbers: TuskConfig.Cinematic.
	  * GRADE: a film look on top of the map's own lighting: a touch more
	    contrast and warmth; on High, distant things soften (depth of field)
	  * VIGNETTE: darker screen edges (under the HUD)
	  * DUST: fine desert dust drifting in the air round the camera (High)
	  * LOW HEALTH: the edges pulse red, the world drains of colour
	  * TAKEN DOWN: when you finish someone, letterbox bars slide in, the
	    picture punches in and "TAKEN DOWN" + their name hits the screen
	  * DEATH CAM: when you go down, the world fades to grey behind bars:
	    "YOU WERE TAKEN DOWN · BY <name>" until you respawn
	  * TITLE CARDS: Cinematic.title(top, main, color) for big moments
	    (the bounty board uses it: "THE HUNT BEGINS", "BOUNTY CLAIMED")
	It never takes the camera away from you (cutscenes do that), and it
	stays out of the way while a cutscene is playing.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local VFXQuality = require(Shared.VFXQuality)
local Net = require(Shared.Net)
local CameraFX = require(script.Parent.CameraFX)

local Cinematic = {}
local cfg = TuskConfig.Cinematic or {}
local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 205, 90)
local PAPER = Color3.fromRGB(234, 205, 160)
local BLOOD = Color3.fromRGB(170, 20, 16)

local grade, dof, dust, dustEmitter
local gui, vignette, redEdges, bars, cardTop, cardMain, cardSub
local mood -- a ColorCorrection the moments (KO, death, low health) push on
local recentHits = setmetatable({}, { __mode = "k" }) -- [victim model] = os.clock() of your last hit on them
local watching = setmetatable({}, { __mode = "k" })
local cardToken = 0
local dead = false
local lastKO = -math.huge

local function level()
	local _, name = VFXQuality.get()
	return name == "High" and 3 or (name == "Medium" and 2 or 1)
end

local function on(key)
	return cfg.Enabled ~= false and cfg[key] ~= false
end

local function cutscenePlaying()
	local cam = workspace.CurrentCamera
	return cam ~= nil and cam.CameraType == Enum.CameraType.Scriptable
end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

---------------------------------------------------------------------------
-- Grade, depth of field, dust
---------------------------------------------------------------------------
local function applyQuality()
	local lv = level()
	if grade then
		grade.Enabled = on("Grade")
	end
	if dof then
		dof.Enabled = on("DepthOfField") and lv >= 3
	end
	if dustEmitter then
		dustEmitter.Enabled = on("Dust") and lv >= 3
	end
	if vignette then
		vignette.Visible = on("Vignette") and lv >= 2
	end
end

local function buildWorld()
	grade = new("ColorCorrectionEffect", { Name = "SpinCinematicGrade", Contrast = cfg.Contrast or 0.08, Saturation = cfg.Saturation or 0.06, Brightness = 0, TintColor = cfg.Tint or Color3.fromRGB(255, 247, 234) }, Lighting)
	mood = new("ColorCorrectionEffect", { Name = "SpinCinematicMood", Contrast = 0, Saturation = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }, Lighting)
	dof = new("DepthOfFieldEffect", { Name = "SpinCinematicDOF", FarIntensity = cfg.FarBlur or 0.12, NearIntensity = 0, FocusDistance = 70, InFocusRadius = 90 }, Lighting)
	-- Dust drifting round the camera (a local part, so only you see yours).
	dust = new("Part", { Name = "SpinDust", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(50, 18, 50) }, workspace.CurrentCamera or workspace)
	dustEmitter = new("ParticleEmitter", {
		Name = "Dust",
		Rate = cfg.DustRate or 14,
		Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(0.3, 1.2),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.5, 0.12), NumberSequenceKeypoint.new(1, 0.05) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(240, 214, 170)),
		LightEmission = 0.3,
		LightInfluence = 0.6,
		Acceleration = Vector3.new(1.2, -0.1, 0.4),
		RotSpeed = NumberRange.new(-30, 30),
	}, dust)
	pcall(function()
		dustEmitter.Shape = Enum.ParticleEmitterShape.Box
		dustEmitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	end)
end

---------------------------------------------------------------------------
-- Screen: vignette, red edges, letterbox and title cards
---------------------------------------------------------------------------
-- Four soft edges of one colour (a vignette).
local function edges(parent, color, depth, name)
	local frame = new("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
	local sides = {
		{ UDim2.fromScale(0, 0), UDim2.fromScale(1, depth), 90 },
		{ UDim2.fromScale(0, 1 - depth), UDim2.fromScale(1, depth), -90 },
		{ UDim2.fromScale(0, 0), UDim2.fromScale(depth * 0.7, 1), 0 },
		{ UDim2.fromScale(1 - depth * 0.7, 0), UDim2.fromScale(depth * 0.7, 1), 180 },
	}
	for _, s in ipairs(sides) do
		local f = new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Position = s[1], Size = s[2] }, frame)
		new("UIGradient", { Rotation = s[3], Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, f)
	end
	return frame
end

local function buildScreen()
	local pg = player:WaitForChild("PlayerGui")
	-- The vignette sits under the HUD.
	local back = new("ScreenGui", { Name = "SpinCinematicBack", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = -5 }, pg)
	vignette = edges(back, Color3.new(0, 0, 0), 0.22, "Vignette")
	vignette.BackgroundTransparency = 1
	for _, f in ipairs(vignette:GetChildren()) do
		f.BackgroundTransparency = cfg.VignetteStrength and (1 - cfg.VignetteStrength) or 0.55
	end
	redEdges = edges(back, BLOOD, 0.28, "LowHealth")
	for _, f in ipairs(redEdges:GetChildren()) do
		f.BackgroundTransparency = 1
	end
	-- Letterbox and title cards sit above most things.
	gui = new("ScreenGui", { Name = "SpinCinematic", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 15 }, pg)
	bars = {}
	for i, y in ipairs({ 0, 1 }) do
		bars[i] = new("Frame", { AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, gui)
	end
	cardTop = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.6, 0.05), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = PAPER, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" }, gui)
	cardMain = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.8, 0.13), BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = GOLD, TextTransparency = 1, TextStrokeTransparency = 1, TextStrokeColor3 = Color3.fromRGB(40, 22, 10), Text = "" }, gui)
	new("UIScale", { Scale = 1 }, cardMain)
	cardSub = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.fromScale(0.6, 0.045), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = PAPER, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" }, gui)
	for _, l in ipairs({ cardTop, cardMain, cardSub }) do
		new("UITextSizeConstraint", { MaxTextSize = l == cardMain and 80 or 28 }, l)
	end
end

local QUICK = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLAM = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function letterbox(show, size)
	for _, b in ipairs(bars) do
		TweenService:Create(b, QUICK, { Size = UDim2.new(1, 0, show and (size or 0.11) or 0, 0) }):Play()
	end
end

local function hideCard(token)
	if token ~= cardToken then
		return
	end
	letterbox(false)
	for _, l in ipairs({ cardTop, cardMain, cardSub }) do
		TweenService:Create(l, QUICK, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end
end

-- A title card: letterbox bars, a small line on top, a big slammed word,
-- a line under it. `hold` nil keeps it up until the next card / clear.
local function card(top, main, sub, color, hold, barSize)
	if not gui then
		return
	end
	cardToken = cardToken + 1
	local token = cardToken
	letterbox(true, barSize)
	cardTop.Text = string.upper(top or "")
	cardMain.Text = string.upper(main or "")
	cardSub.Text = string.upper(sub or "")
	cardMain.TextColor3 = color or GOLD
	local scale = cardMain:FindFirstChildOfClass("UIScale")
	scale.Scale = 1.8
	TweenService:Create(scale, SLAM, { Scale = 1 }):Play()
	for _, l in ipairs({ cardTop, cardMain, cardSub }) do
		l.TextTransparency = 1
		TweenService:Create(l, QUICK, { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
	end
	if hold then
		task.delay(hold, function()
			hideCard(token)
		end)
	end
	return token
end

-- Push the mood colour for a moment (or hold it with `hold` = nil).
local function moodTo(props, time)
	if not mood then
		return
	end
	TweenService:Create(mood, TweenInfo.new(time or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function moodClear(time)
	moodTo({ Contrast = 0, Saturation = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }, time or 0.6)
end

---------------------------------------------------------------------------
-- Public: title cards for other systems
---------------------------------------------------------------------------
function Cinematic.title(top, main, color, sub, hold)
	if not on("TitleCards") or cutscenePlaying() or dead then
		return
	end
	card(top, main, sub, color, hold or 2.2, 0.08)
end

---------------------------------------------------------------------------
-- TAKEN DOWN / death cam
---------------------------------------------------------------------------
local function nameOf(model)
	local p = Players:GetPlayerFromCharacter(model)
	if p then
		return p.DisplayName
	end
	local h = model:FindFirstChildOfClass("Humanoid")
	local n = h and h.DisplayName ~= "" and h.DisplayName or model.Name
	return (n:gsub("^Stand User: ", ""))
end

local function takenDown(victim)
	if not on("KOCam") or dead or cutscenePlaying() or os.clock() - lastKO < (cfg.KOCooldown or 2.5) then
		return
	end
	lastKO = os.clock()
	local lv = level()
	card("", "TAKEN DOWN", nameOf(victim), GOLD, cfg.KOHold or 1.5, lv >= 2 and 0.1 or 0.06)
	CameraFX.fovPunch(-10, 0.6)
	if lv >= 2 then
		moodTo({ Contrast = 0.25, Saturation = -0.35, TintColor = Color3.fromRGB(255, 236, 210) }, 0.08)
		task.delay(0.7, function()
			if not dead then
				moodClear(0.8)
			end
		end)
	end
end

local function watchVictim(model)
	if watching[model] then
		return
	end
	local h = model:FindFirstChildOfClass("Humanoid")
	if not h then
		return
	end
	watching[model] = true
	h.Died:Connect(function()
		local t = recentHits[model]
		if t and os.clock() - t <= (cfg.KillCredit or 6) then
			takenDown(model)
		end
	end)
end

local function onDeath(character)
	if not on("DeathCam") then
		return
	end
	dead = true
	local by
	local id = character:GetAttribute("LastAttackerId")
	local when = character:GetAttribute("LastAttackTime") or -math.huge
	if id and workspace:GetServerTimeNow() - when <= 6 then
		local p = Players:GetPlayerByUserId(id)
		by = p and p.DisplayName
	end
	cardToken = cardToken + 1
	card("", "YOU WERE TAKEN DOWN", by and ("BY " .. by) or "THE DESERT TAKES ANOTHER", Color3.fromRGB(230, 90, 70), nil, 0.13)
	moodTo({ Saturation = -1, Contrast = 0.2, Brightness = -0.05, TintColor = Color3.fromRGB(235, 225, 215) }, 1.4)
end

local function onCharacter(character)
	dead = false
	cardToken = cardToken + 1
	hideCard(cardToken)
	moodClear(0.6)
	local h = character:WaitForChild("Humanoid", 10)
	if h then
		h.Died:Connect(function()
			onDeath(character)
		end)
	end
end

---------------------------------------------------------------------------
-- Every frame: dust follows the camera; low-health pulse
---------------------------------------------------------------------------
local lowOn = false
local function step()
	local cam = workspace.CurrentCamera
	if dust and cam then
		if dust.Parent ~= cam then
			dust.Parent = cam
		end
		dust.CFrame = CFrame.new(cam.CFrame.Position + cam.CFrame.LookVector * 14)
	end
	-- Low health: red edges pulse, the colour drains.
	local character = player.Character
	local h = character and character:FindFirstChildOfClass("Humanoid")
	local k = 0
	if on("LowHealth") and h and h.Health > 0 and h.MaxHealth > 0 then
		local frac = h.Health / h.MaxHealth
		local threshold = cfg.LowHealth or 0.3
		if frac < threshold then
			k = 1 - frac / threshold
		end
	end
	if redEdges then
		local pulse = k > 0 and (0.55 + 0.45 * math.abs(math.sin(os.clock() * (3 + k * 3)))) or 0
		for _, f in ipairs(redEdges:GetChildren()) do
			f.BackgroundTransparency = 1 - k * 0.75 * pulse
		end
	end
	if not dead and mood then
		if k > 0 then
			lowOn = true
			mood.Saturation = -0.5 * k
		elseif lowOn then
			lowOn = false
			mood.Saturation = 0
		end
	end
end

---------------------------------------------------------------------------
function Cinematic.init()
	if cfg.Enabled == false then
		return
	end
	if _G.__SpinCinematic then
		return
	end
	_G.__SpinCinematic = true
	buildWorld()
	buildScreen()
	applyQuality()
	VFXQuality.Changed:Connect(applyQuality)
	-- Your hits (to know when YOU took someone down).
	Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
		if name == "Hit" and typeof(data) == "table" and data.AttackerId == player.UserId and typeof(data.Victim) == "Instance" then
			recentHits[data.Victim] = os.clock()
			watchVictim(data.Victim)
		end
	end)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService.RenderStepped:Connect(step)
end

return Cinematic
