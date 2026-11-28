---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient"
updated: 2026-11-22
---
# Cutscenes

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| **Exact name** | `Cutscenes` (capitals matter) |

**What it does:** Short cinematic camera moves, with black letterbox bars and a title card in the bounty board's style (Bangers on a nailed wooden sign). Every cutscene can be skipped (SKIP button, Enter, or the controller's Select). Settings: TuskConfig.Cutscenes (each one can be turned off).

## How to add it
1. In Studio's Explorer, find **SpinClient** (StarterPlayer › StarterPlayerScripts › SpinClient).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **Cutscenes**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	Cutscenes  (StarterPlayerScripts.SpinClient.Cutscenes)

	Short cinematic camera moves, with black letterbox bars and a title card
	in the bounty board's style (Bangers on a nailed wooden sign). Every
	cutscene can be skipped (SKIP button, Enter, or the controller's Select).
	Settings: TuskConfig.Cutscenes (each one can be turned off).

	The cutscenes:
	  * WELCOME (once per session, when you first spawn): a fly-over of the
	    desert, the ghost town and the race track, then down to you
	  * STEEL BALL RUN STAGE INTROS: during each stage's countdown, the camera
	    sweeps from high over the stage start down to behind your horse, with
	    "STAGE 3 · ROCKY MOUNTAINS" and its tagline
	  * RACE WINNER: at the end of the race the camera circles the overall
	    winner ("WINNER", their name and points)
	  * ULTIMATES: a quick close-up push-in on you with your ultimate's name
	    (under a second, so you're never out of the fight for long)
	  * THE COMPLETE SAINT'S CORPSE: a slow golden orbit round you

	Engine: Cutscenes.play(shots, opts). A shot is { From, To, Time, FOV =
	{ start, finish }, Title, Subtitle, Color }; From / To are CFrames or
	functions returning one (to follow something that moves). opts.Priority:
	a cutscene only interrupts a lower-priority one. The camera always goes
	back to exactly what it was following before (you, a horse, John Rod...).

	SHIFT LOCK: with shift lock on, Roblox turns your character to face
	wherever the camera looks, so an orbiting cutscene camera used to spin
	you round and round. While a cutscene plays, shift lock is switched off
	(and the mouse freed); it's switched back on afterwards if you had it on.
	The camera is moved after Roblox's own camera each frame, so it doesn't
	fight it (no jitter).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local Net = require(Shared.Net)
local UITheme = require(script.Parent.UI.UITheme)

local Cutscenes = {}
local player = Players.LocalPlayer
local cfg = TuskConfig.Cutscenes or {}
local C = UITheme.C

local gui, topBar, bottomBar, titleSign, titleText, subText, skipButton
local playing -- the cutscene running now

local function enabled(kind)
	return cfg.Enabled ~= false and (kind == nil or cfg[kind] ~= false)
end

local function easeInOut(a)
	return a < 0.5 and 4 * a * a * a or 1 - ((-2 * a + 2) ^ 3) / 2
end

local function resolve(cf)
	if type(cf) == "function" then
		local ok, v = pcall(cf)
		return ok and v or nil
	end
	return cf
end

---------------------------------------------------------------------------
-- The overlay: letterbox bars, a title sign, a skip button
---------------------------------------------------------------------------
local function buildUI()
	gui = UITheme.new("ScreenGui", { Name = "SpinCutscene", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, Enabled = false }, player:WaitForChild("PlayerGui"))
	topBar = UITheme.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0) }, gui)
	bottomBar = UITheme.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0) }, gui)
	titleSign = UITheme.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.13, 6), Size = UDim2.fromOffset(440, 74), Visible = false, ZIndex = 2 }, gui)
	UITheme.wood(titleSign, { Planks = 2, Border = 4, Brackets = true, BracketSize = 14 })
	UITheme.new("UISizeConstraint", { MaxSize = Vector2.new(440, 74) }, titleSign)
	titleText = UITheme.label(titleSign, { Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -28, 0, 44), Text = "", Font = UITheme.Font.Title, TextColor3 = C.GOLD, TextStrokeTransparency = 0.3, TextStrokeColor3 = C.WOOD_EDGE, ZIndex = 4 })
	subText = UITheme.label(titleSign, { Position = UDim2.fromOffset(14, 48), Size = UDim2.new(1, -28, 0, 18), Text = "", Font = UITheme.Font.Body, TextColor3 = C.PAPER, ZIndex = 4 })
	UITheme.new("UIScale", { Scale = 1 }, titleSign)
	skipButton = UITheme.button(gui, "SKIP  ▶", C.WOOD_LIGHT, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -16), Size = UDim2.fromOffset(110, 38), ZIndex = 5 })
	skipButton.Activated:Connect(function()
		Cutscenes.stop()
	end)
end

local function showTitle(title, subtitle, color)
	if not title then
		titleSign.Visible = false
		return
	end
	titleText.Text = title
	titleText.TextColor3 = color or C.GOLD
	subText.Text = subtitle or ""
	subText.Visible = subtitle ~= nil
	titleSign.Size = UDim2.fromOffset(440, subtitle and 74 or 56)
	titleSign.Visible = true
	UITheme.pop(titleSign, 0.6)
end

local function bars(on)
	local size = on and UDim2.fromScale(1, 0.11) or UDim2.fromScale(1, 0)
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(topBar, info, { Size = size }):Play()
	TweenService:Create(bottomBar, info, { Size = size }):Play()
end

---------------------------------------------------------------------------
-- The engine
---------------------------------------------------------------------------
local function restoreCamera(saved)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local subject = saved.Subject
	if not (subject and subject.Parent) then
		subject = hum
	end
	-- Hand back from behind your character (not wherever the last shot
	-- ended, e.g. facing you), so the normal camera picks up naturally.
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and subject == hum then
		local behind = (root.CFrame * CFrame.new(0, 3, 11)).Position
		camera.CFrame = CFrame.lookAt(behind, root.Position + Vector3.new(0, 1.5, 0))
	end
	camera.CameraSubject = subject
	camera.CameraType = saved.Type == Enum.CameraType.Scriptable and Enum.CameraType.Custom or (saved.Type or Enum.CameraType.Custom)
	camera.FieldOfView = saved.FOV or 70
end

-- Shift lock off for the cutscene (it would turn you to face the camera).
local gameSettings
pcall(function()
	gameSettings = UserSettings():GetService("UserGameSettings")
end)

local function holdStill()
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	if gameSettings then
		pcall(function()
			if gameSettings.RotationType ~= Enum.RotationType.MovementRelative then
				gameSettings.RotationType = Enum.RotationType.MovementRelative
			end
		end)
	end
end

local function releaseMouseLock(run)
	run.MouseLock = player.DevEnableMouseLock
	run.WasLocked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	pcall(function()
		player.DevEnableMouseLock = false
	end)
	holdStill()
end

local function restoreMouseLock(run)
	if run.MouseLock ~= nil then
		pcall(function()
			player.DevEnableMouseLock = run.MouseLock
		end)
	end
	-- Shift lock was on: turn it back on (the camera scripts' own toggle).
	if run.WasLocked and run.MouseLock then
		task.defer(function()
			-- (Only if Roblox's PlayerModule is there: a custom camera setup may
			-- not have one, and require(nil) stops Studio's debugger.)
			local scripts = player:FindFirstChild("PlayerScripts")
			local module = scripts and scripts:FindFirstChild("PlayerModule")
			if not module or not module:IsA("ModuleScript") then
				return
			end
			pcall(function()
				local pm = require(module)
				local cams = pm.GetCameras and pm:GetCameras()
				local mlc = cams and cams.activeMouseLockController
				if mlc and mlc.GetIsMouseLocked and not mlc:GetIsMouseLocked() and mlc.OnMouseLockToggled then
					mlc:OnMouseLockToggled()
				end
			end)
		end)
	end
end

local function finish(run, skipped)
	if playing ~= run then
		return
	end
	playing = nil
	pcall(function()
		RunService:UnbindFromRenderStep("SpinCutscene")
	end)
	if run.Conn then
		run.Conn:Disconnect()
	end
	restoreMouseLock(run)
	ContextActionService:UnbindAction("SpinCutsceneSkip")
	restoreCamera(run.Saved)
	showTitle(nil)
	bars(false)
	task.delay(0.4, function()
		if not playing and gui then
			gui.Enabled = false
		end
	end)
	if run.OnEnd then
		pcall(run.OnEnd, skipped)
	end
end

function Cutscenes.isPlaying()
	return playing ~= nil
end

function Cutscenes.stop()
	if playing then
		finish(playing, true)
	end
end

function Cutscenes.play(shots, opts)
	opts = opts or {}
	local camera = workspace.CurrentCamera
	if not camera or not gui or #shots == 0 then
		return false
	end
	local priority = opts.Priority or 1
	if playing then
		if playing.Priority >= priority then
			return false
		end
		finish(playing, true)
	end
	local run = {
		Priority = priority,
		OnEnd = opts.OnEnd,
		Saved = { Type = camera.CameraType, Subject = camera.CameraSubject, FOV = camera.FieldOfView },
		Shot = 0,
	}
	playing = run
	gui.Enabled = true
	skipButton.Visible = opts.Skippable ~= false
	bars(opts.Letterbox ~= false)
	if opts.Skippable ~= false then
		ContextActionService:BindActionAtPriority("SpinCutsceneSkip", function(_, state)
			if state == Enum.UserInputState.Begin then
				Cutscenes.stop()
			end
			return Enum.ContextActionResult.Sink
		end, false, 4000, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonSelect)
	end
	releaseMouseLock(run)
	camera.CameraType = Enum.CameraType.Scriptable
	local index, started = 1, os.clock()
	local function begin(i)
		local shot = shots[i]
		run.Shot = i
		started = os.clock()
		showTitle(shot.Title, shot.Subtitle, shot.Color)
	end
	begin(1)
	-- After Roblox's own camera each frame, so nothing fights the move.
	RunService:BindToRenderStep("SpinCutscene", Enum.RenderPriority.Camera.Value + 2, function()
		if playing ~= run then
			return
		end
		camera = workspace.CurrentCamera or camera
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		holdStill()
		local shot = shots[index]
		local a = math.clamp((os.clock() - started) / math.max(shot.Time or 2, 0.05), 0, 1)
		local from, to = resolve(shot.From), resolve(shot.To or shot.From)
		if from and to then
			local e = shot.Linear and a or easeInOut(a)
			camera.CFrame = from:Lerp(to, e)
			if shot.FOV then
				camera.FieldOfView = shot.FOV[1] + (shot.FOV[2] - shot.FOV[1]) * e
			end
		end
		if a >= 1 then
			index = index + 1
			if index > #shots then
				finish(run, false)
			else
				begin(index)
			end
		end
	end)
	return true
end

---------------------------------------------------------------------------
-- The cutscenes
---------------------------------------------------------------------------
local function myRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function look(fromPos, atPos)
	return CFrame.lookAt(fromPos, atPos)
end

-- Welcome: a fly-over of the main map, then down to you.
local function intro()
	local map = workspace:FindFirstChild("SBRMap")
	local root = myRoot()
	if not map or not root then
		return
	end
	local o = map:GetAttribute("Origin") or Vector3.new()
	local ghost = o + Vector3.new(-170, 0, -40)
	local track = o + Vector3.new(0, 0, 118)
	Cutscenes.play({
		{ From = look(o + Vector3.new(-380, 170, 380), o), To = look(o + Vector3.new(380, 170, 380), o), Time = 4.2, FOV = { 70, 62 },
			Title = "SPIN BATTLEGROUNDS", Subtitle = "THE STEEL BALL RUN" },
		{ From = look(ghost + Vector3.new(-70, 14, 40), ghost), To = look(ghost + Vector3.new(50, 10, 40), ghost + Vector3.new(0, 4, 0)), Time = 3.2,
			Title = "THE SAINT'S CORPSE", Subtitle = "ITS PARTS ARE SCATTERED ACROSS THE DESERT. FIGHT FOR THEM." },
		{ From = look(track + Vector3.new(0, 40, 80), track + Vector3.new(0, 0, -60)), To = look(track + Vector3.new(0, 14, -20), track + Vector3.new(0, 4, -160)), Time = 3,
			Title = "THE RACE", Subtitle = "EVERY 10 MINUTES: SAN DIEGO TO NEW YORK, NINE STAGES" },
		{ From = function()
			local r = myRoot()
			return r and look(r.Position + Vector3.new(0, 40, 40), r.Position) or nil
		end, To = function()
			local r = myRoot()
			return r and look((r.CFrame * CFrame.new(0, 5, 13)).Position, r.Position + Vector3.new(0, 2, 0)) or nil
		end, Time = 1.8, Title = "CHOOSE YOUR STAND", Subtitle = "PRESS T FOR THE CHARACTER MENU" },
	}, { Priority = 1 })
end

-- A stage of the Steel Ball Run: high over the start, down to behind your horse.
local function stageIntro(data)
	local root = myRoot()
	local course = workspace:FindFirstChild("SteelBallRunCourse")
	if not root or not course then
		return
	end
	local line = course:FindFirstChild("StartLine")
	local gate = course:FindFirstChild("Gate_1")
	local start = line and line.Position or root.Position
	local ahead = gate and gate:GetPivot().Position or (start + root.CFrame.LookVector * 100)
	local dir = Vector3.new(ahead.X - start.X, 0, ahead.Z - start.Z)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, -1)
	local title = "STAGE " .. tostring(data.Index or "?") .. " · " .. string.upper(data.Name or "")
	Cutscenes.play({
		{ From = look(start - dir * 60 + Vector3.new(0, 70, 0), start + dir * 120), To = look(start + dir * 30 + Vector3.new(0, 34, 0), start + dir * 160), Time = 1.6, FOV = { 72, 64 },
			Title = title, Subtitle = data.Tagline and string.upper(data.Tagline) or nil },
		{ From = function()
			local r = myRoot()
			return r and look(r.Position + dir * 10 + Vector3.new(0, 20, 0), r.Position) or nil
		end, To = function()
			local r = myRoot()
			return r and look(r.Position - dir * 13 + Vector3.new(0, 6, 0), r.Position + dir * 20) or nil
		end, Time = 1.1, FOV = { 64, 70 }, Title = title, Subtitle = data.Tagline and string.upper(data.Tagline) or nil },
	}, { Priority = 3 })
end

-- The race winner: circle them.
local function winnerOrbit(row)
	local target
	if row.UserId and row.UserId > 0 then
		local p = Players:GetPlayerByUserId(row.UserId)
		target = p and p.Character
	end
	if not target and row.Name then
		target = workspace:FindFirstChild(row.Name, true)
	end
	local root = target and target:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local startAngle = math.random() * math.pi * 2
	local function orbit(k)
		return function()
			if not root.Parent then
				return nil
			end
			local a = startAngle + k
			return look(root.Position + Vector3.new(math.cos(a) * 15, 6, math.sin(a) * 15), root.Position + Vector3.new(0, 2, 0))
		end
	end
	Cutscenes.play({
		{ From = orbit(0), To = orbit(1.4), Time = 3.4, Linear = true, FOV = { 60, 55 },
			Title = "WINNER: " .. string.upper(row.Name or "?"), Subtitle = tostring(row.Points or 0) .. " POINTS · THE STEEL BALL RUN" },
	}, { Priority = 4 })
end

-- Your ultimate: a quick close-up push-in with its name.
local lastUlt = -math.huge
local function ultimateCloseUp(character, act)
	if os.clock() - lastUlt < 4 then
		return
	end
	lastUlt = os.clock()
	local info = Registry.get(act)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not info then
		return
	end
	local who
	for _, entry in ipairs(TuskConfig.Roster or {}) do
		if entry.Id == info.Character then
			who = entry.Name
		end
	end
	local theme = info.Theme and info.Theme.Primary or C.GOLD
	Cutscenes.play({
		{ From = function()
			return root.Parent and look((root.CFrame * CFrame.new(1.5, 2, -8)).Position, root.Position + Vector3.new(0, 1.6, 0)) or nil
		end, To = function()
			return root.Parent and look((root.CFrame * CFrame.new(0.8, 2.1, -5.2)).Position, root.Position + Vector3.new(0, 1.8, 0)) or nil
		end, Time = 0.9, FOV = { 55, 42 }, Title = string.upper(info.Ultimate or "ULTIMATE"), Subtitle = who, Color = theme:Lerp(Color3.new(1, 1, 1), 0.3) },
	}, { Priority = 2, Skippable = true })
end

-- The complete Saint's Corpse: a slow golden orbit.
local function corpseOrbit()
	local root = myRoot()
	if not root then
		return
	end
	local function orbit(k)
		return function()
			if not root.Parent then
				return nil
			end
			return look(root.Position + Vector3.new(math.cos(k) * 12, 5, math.sin(k) * 12), root.Position + Vector3.new(0, 2, 0))
		end
	end
	Cutscenes.play({
		{ From = orbit(0), To = orbit(math.pi), Time = 3.5, Linear = true, FOV = { 62, 52 },
			Title = "THE SAINT'S CORPSE", Subtitle = "IS COMPLETE · PRESS V: THE SAINT'S MIRACLE", Color = Color3.fromRGB(255, 225, 120) },
	}, { Priority = 4 })
end

function Cutscenes.init()
	buildUI()
	-- Welcome, once a session, a moment after you first spawn.
	if enabled("Intro") then
		task.spawn(function()
			local character = player.Character or player.CharacterAdded:Wait()
			character:WaitForChild("HumanoidRootPart", 15)
			task.wait(cfg.IntroDelay or 2)
			intro()
		end)
	end
	-- The race.
	local racing = false
	Net.get("Race").OnClientEvent:Connect(function(kind, data)
		data = typeof(data) == "table" and data or {}
		if kind == "Stage" and player:GetAttribute("RaceEntered") then
			racing = true
			if enabled("RaceStages") then
				-- (The riders are being lined up: start a beat later.)
				task.delay(0.25, function()
					stageIntro(data)
				end)
			end
		elseif kind == "Results" then
			local wasRacing = racing
			racing = false
			if wasRacing and data.Final and enabled("RaceWinner") and data.List and data.List[1] then
				winnerOrbit(data.List[1])
			end
		elseif kind == "Out" or kind == "Cancelled" then
			racing = false
		end
	end)
	-- Your ultimate.
	Net.get("TuskFX").OnClientEvent:Connect(function(name, data)
		if name == "Ultimate" and typeof(data) == "table" and data.Character and data.Character == player.Character and data.Act and enabled("Ultimates") then
			ultimateCloseUp(data.Character, data.Act)
		end
	end)
	-- The complete Saint's Corpse.
	Net.get("WorldFX").OnClientEvent:Connect(function(name, data)
		if name == "CorpseComplete" and typeof(data) == "table" and data.Player == player.UserId and enabled("CorpseComplete") then
			corpseOrbit()
		end
	end)
	-- Respawning mid-cutscene: just stop it.
	player.CharacterAdded:Connect(function()
		Cutscenes.stop()
	end)
end

return Cutscenes
```
