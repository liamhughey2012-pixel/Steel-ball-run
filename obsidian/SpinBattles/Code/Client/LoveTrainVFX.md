---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# LoveTrainVFX

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `LoveTrainVFX` (capitals matter) |

**What it does:** Client visuals for D4C -LOVE TRAIN- (Funny Valentine with the complete Saint's Corpse, Act 33). Blocky. Gold-white light with D4C's pink. D4C (D4CStand) behind him, glowing, a halo of light at its back THE GAP OF LIGHT (always on, everyone sees it): two tall thin walls of light either side of him, light falling between them, gold motes; when a hit is shed, a beam of light carries the misfortune off to whoever it lands on THE TRANSFORMATION (a cutscene, when YOU become Love Train; about 9.4 s, skippable; TuskConfig.Cutscenes.LoveTrain): 1. wide and low: the eight corpse parts circling him, glowing, the sky darkening ("THE SAINT'S CORPSE") 2. the parts fly into him one by one, a flash of gold with each 3. looking up: the walls of light come down out of the sky either side of him; D4C lights up behind him 4. his face in the gold light: "ALL MISFORTUNE GOES ELSEWHERE" 5. wide: Valentine in the gap of light with D4C: "D4C -LOVE TRAIN-" LOVE TRAIN COMBO: chops trailed with light LIGHT RAIL: a rail of light along his path; he's a streak of light MISFORTUNE TRANSFER: dark orbs of misfortune drain out of him into a ball and hit the target ("MISFORTUNE ×N"); gold sparkles heal him LIGHT SPEARS: five spears of light form in a fan and fire LOVE TRAIN: THE CHOSEN ONE: a column of light round him, pulses of light rolling out, then a blinding burst

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **LoveTrainVFX**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.LoveTrainVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.LoveTrainVFX)

	Client visuals for D4C -LOVE TRAIN- (Funny Valentine with the complete
	Saint's Corpse, Act 33). Blocky. Gold-white light with D4C's pink.
	  * D4C (D4CStand) behind him, glowing, a halo of light at its back
	  * THE GAP OF LIGHT (always on, everyone sees it): two tall thin walls
	    of light either side of him, light falling between them, gold motes;
	    when a hit is shed, a beam of light carries the misfortune off to
	    whoever it lands on
	  * THE TRANSFORMATION (a cutscene, when YOU become Love Train; about
	    9.4 s, skippable; TuskConfig.Cutscenes.LoveTrain):
	      1. wide and low: the eight corpse parts circling him, glowing,
	         the sky darkening ("THE SAINT'S CORPSE")
	      2. the parts fly into him one by one, a flash of gold with each
	      3. looking up: the walls of light come down out of the sky either
	         side of him; D4C lights up behind him
	      4. his face in the gold light: "ALL MISFORTUNE GOES ELSEWHERE"
	      5. wide: Valentine in the gap of light with D4C:
	         "D4C -LOVE TRAIN-"
	  * LOVE TRAIN COMBO: chops trailed with light
	  * LIGHT RAIL: a rail of light along his path; he's a streak of light
	  * MISFORTUNE TRANSFER: dark orbs of misfortune drain out of him into a
	    ball and hit the target ("MISFORTUNE ×N"); gold sparkles heal him
	  * LIGHT SPEARS: five spears of light form in a fan and fire
	  * LOVE TRAIN: THE CHOSEN ONE: a column of light round him, pulses of
	    light rolling out, then a blinding burst
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local TuskStandModels = require(Shared.TuskStandModels)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local Common = require(script.Parent.Parent.TuskActCommon)
local Fighters = require(script.Parent.Parent.Fighters)
local TuskStand = require(script.Parent.Parent.TuskStand)
local Cutscenes = require(script.Parent.Parent.Cutscenes)
local D4CStand = require(script.Parent.D4CStand)

local LoveTrainVFX = {}
local ACT = 33
local D4C_ACT = 13
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

local LIGHT = Color3.fromRGB(255, 246, 210)
local GOLD = Color3.fromRGB(255, 214, 110)
local PINK = Color3.fromRGB(236, 120, 170)
local DARK = Color3.fromRGB(40, 20, 50)

-- D4C, glowing, with a halo of light at its back.
local function buildLoveTrainD4C(scale)
	local model, rig = D4CStand.build(scale)
	if not model then
		return model, rig
	end
	local body = rig and rig.Body or model.PrimaryPart
	if body then
		local halo = Instance.new("Part")
		halo.Name = "Halo"
		halo.Shape = Enum.PartType.Cylinder
		halo.Size = Vector3.new(0.08, 3.2, 3.2) * (scale or 1)
		halo.Color = LIGHT
		halo.Material = Enum.Material.Neon
		halo.Transparency = 0.35
		halo.CanCollide = false
		halo.CanQuery = false
		halo.CanTouch = false
		halo.Massless = true
		halo.CastShadow = false
		halo.CFrame = body.CFrame * CFrame.new(0, 1.2 * (scale or 1), 0.8 * (scale or 1)) * CFrame.Angles(0, math.pi / 2, 0)
		local w = Instance.new("WeldConstraint")
		w.Part0 = body
		w.Part1 = halo
		w.Parent = halo
		halo.Parent = model
		local light = Instance.new("PointLight")
		light.Color = GOLD
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = body
	end
	return model, rig
end
TuskStandModels.register(ACT, buildLoveTrainD4C, { Aura = GOLD, AuraLight = LIGHT, Offset = D4CStand.Offset })

local stanced = {}
local gaps = {} -- [character] = { parts }
local lastCutscene
local inCutscene = {} -- [character] = true: its everyday walls are hidden
local watchedAct

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function isMe(character)
	return character ~= nil and localPlayer ~= nil and character == localPlayer.Character
end

local function label(adornee, text, color, duration, size, offset)
	if not adornee then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size or 240, (size or 240) / 5)
	bb.StudsOffset = offset or Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = adornee
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.Bangers
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.1
	t.Parent = bb
	bb.Parent = VFXLib.Folder
	local base = bb.StudsOffset
	VFXLib.animate(duration or 1.2, function(a)
		bb.StudsOffset = base + Vector3.new(0, a * 1.2, 0)
		t.TextTransparency = math.max(0, a * 1.6 - 0.6)
		t.TextStrokeTransparency = 0.1 + 0.9 * a
	end, function()
		bb:Destroy()
	end)
end

local function beam(from, to, color, width, time)
	local len = (to - from).Magnitude
	if len < 0.1 then
		return
	end
	local p = VFXLib.part({ Size = Vector3.new(width or 0.2, width or 0.2, len), CFrame = CFrame.lookAt((from + to) / 2, to), Color = color or LIGHT, Material = Enum.Material.Neon, Transparency = 0.1 })
	VFXLib.animate(time or 0.3, function(a)
		p.Transparency = 0.1 + 0.9 * a
	end, function()
		p:Destroy()
	end)
end

local function motes(at, count, spread, color)
	for _ = 1, count do
		local from = at + Vector3.new((math.random() - 0.5) * spread, (math.random() - 0.5) * spread, (math.random() - 0.5) * spread)
		local m = VFXLib.part({ Size = Vector3.new(0.18, 0.18, 0.18), Color = color or GOLD, Material = Enum.Material.Neon, CFrame = CFrame.new(from) * CFrame.Angles(0, 0, math.pi / 4) })
		local life = 0.6 + math.random() * 0.5
		VFXLib.animate(life, function(t)
			m.CFrame = CFrame.new(from + Vector3.new(0, t * 1.4, 0)) * CFrame.Angles(0, t * 4, math.pi / 4)
			m.Transparency = math.abs(t - 0.4) * 1.6
		end, function()
			m:Destroy()
		end)
	end
end

-- The gap of light round a character (two thin walls, light falling
-- between them). Returns the parts; they're placed every frame.
local function makeGap(character)
	local parts = {}
	for k = 1, 2 do
		local wall = VFXLib.part({ Size = Vector3.new(0.12, 14, 5), Color = LIGHT, Material = Enum.Material.Neon, Transparency = 0.7 })
		parts[k] = wall
	end
	return parts
end

local function placeGap(character, parts, strength)
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local base = root.CFrame * CFrame.new(0, 4, 0)
	local t = os.clock()
	for k, wall in ipairs(parts) do
		local side = k == 1 and -1 or 1
		wall.CFrame = base * CFrame.new(side * (2.4 + math.sin(t * 1.5 + k) * 0.1), 0, 0)
		wall.Transparency = 1 - (0.25 + 0.1 * math.sin(t * 3 + k)) * strength
	end
end

-- The eight corpse parts as glowing relics (for the cutscene).
local function relics(count)
	local list = {}
	for k = 1, count do
		local core = VFXLib.part({ Size = Vector3.new(0.5, 0.8, 0.4), Color = Color3.fromRGB(150, 120, 90), Material = Enum.Material.SmoothPlastic })
		local glow = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.6 })
		glow.Shape = Enum.PartType.Ball
		list[k] = { Core = core, Glow = glow, A = k / count * math.pi * 2 }
	end
	return list
end

-- Words across the bottom of the screen.
local function screenLine(text, time)
	local pg = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "LoveTrainLine"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.AnchorPoint = Vector2.new(0.5, 1)
	tl.Position = UDim2.fromScale(0.5, 0.86)
	tl.Size = UDim2.fromScale(0.8, 0.1)
	tl.Font = Enum.Font.GothamBlack
	tl.RichText = true
	tl.TextScaled = true
	tl.Text = text
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.TextStrokeColor3 = Color3.fromRGB(80, 50, 20)
	tl.TextStrokeTransparency = 0.2
	tl.TextTransparency = 1
	tl.Parent = gui
	gui.Parent = pg
	VFXLib.animate(time, function(a)
		local fade = a < 0.12 and 1 - a / 0.12 or (a > 0.85 and (a - 0.85) / 0.15 or 0)
		tl.TextTransparency = fade
		tl.TextStrokeTransparency = 0.2 + 0.8 * fade
	end, function()
		gui:Destroy()
	end)
end

---------------------------------------------------------------------------
-- THE TRANSFORMATION (cutscene)
---------------------------------------------------------------------------
local function playCutscene(character)
	local cc = TuskConfig.Cutscenes or {}
	if cc.Enabled == false or cc.LoveTrain == false or (lastCutscene and os.clock() - lastCutscene < 20) then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if not root or not head then
		return false
	end
	lastCutscene = os.clock()
	inCutscene[character] = true
	TuskAnimation.play(character, "VLoveTrain")
	local up = Vector3.new(0, 1, 0)
	local T = { 1.6, 2.2, 2.0, 1.8, 1.8 }
	local starts, acc = {}, 0
	for i, d in ipairs(T) do
		starts[i] = acc
		acc = acc + d
	end
	local function rel(x, y, z)
		return (root.CFrame * CFrame.new(x, y, z)).Position
	end
	local function headAt()
		return head.Parent and head.Position or root.Position + up * 1.5
	end
	local shots = {
		-- 1. Wide and low: the parts circling him.
		{ From = function()
			return root.Parent and CFrame.lookAt(rel(-5, -1.5, -11), rel(0, 1.5, 0)) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(rel(-3.5, -1.2, -10), rel(0, 1.8, 0)) or nil
		end, Time = T[1], FOV = { 55, 52 }, Title = "THE SAINT'S CORPSE", Subtitle = "FUNNY VALENTINE", Color = GOLD },
		-- 2. Circling closer as they fly into him.
		{ From = function()
			return root.Parent and CFrame.lookAt(rel(6, 1.5, -6), rel(0, 1, 0)) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(rel(7, 1.2, 2), rel(0, 1, 0)) or nil
		end, Time = T[2], FOV = { 48, 48 } },
		-- 3. Looking up: the walls of light come down.
		{ From = function()
			return root.Parent and CFrame.lookAt(rel(0.5, -2.4, -7), rel(0, 8, 0)) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(rel(0.5, -2.4, -7.5), rel(0, 4, 0)) or nil
		end, Time = T[3], FOV = { 62, 58 } },
		-- 4. His face in the gold light.
		{ From = function()
			return root.Parent and CFrame.lookAt(headAt() + root.CFrame.LookVector * 3 + root.CFrame.RightVector * 0.8, headAt()) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(headAt() + root.CFrame.LookVector * 2.4 + root.CFrame.RightVector * 0.6, headAt()) or nil
		end, Time = T[4], FOV = { 34, 30 }, Linear = true },
		-- 5. Wide: in the gap of light with D4C.
		{ From = function()
			return root.Parent and CFrame.lookAt(rel(0, 0.5, -12), rel(0, 3, 1)) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(rel(0, 0, -14), rel(0, 3.5, 1)) or nil
		end, Time = T[5], FOV = { 55, 60 }, Title = "D4C -LOVE TRAIN-", Subtitle = "WHILE YOU HOLD THE CORPSE", Color = LIGHT },
	}
	local ended = false
	local made = {}
	local look = Instance.new("ColorCorrectionEffect")
	look.Name = "LoveTrainGrade"
	look.TintColor = Color3.fromRGB(200, 190, 230)
	look.Brightness = -0.15
	look.Saturation = -0.2
	look.Contrast = 0.15
	look.Parent = game:GetService("Lighting")
	table.insert(made, look)
	local parts = relics(8)
	for _, r in ipairs(parts) do
		table.insert(made, r.Core)
		table.insert(made, r.Glow)
	end
	local walls = {}
	local started = Cutscenes.play(shots, { Priority = 3, Skippable = true, OnEnd = function()
		ended = true
		inCutscene[character] = nil
		for _, thing in ipairs(made) do
			if thing and thing.Parent then
				thing:Destroy()
			end
		end
		for _, w in ipairs(walls) do
			if w.Parent then
				w:Destroy()
			end
		end
	end })
	if not started then
		inCutscene[character] = nil
		for _, thing in ipairs(made) do
			thing:Destroy()
		end
		return false
	end
	local t0 = os.clock()
	VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 0.8)
	-- The parts circle him, then fly into him one by one (shot 2).
	VFXLib.animate(starts[3] + 0.2, function()
		if ended or not root.Parent then
			return
		end
		local t = os.clock() - t0
		for k, r in ipairs(parts) do
			if r.Core.Parent then
				local flyAt = starts[2] + (k - 1) * (T[2] - 0.3) / #parts
				local k01 = math.clamp((t - flyAt) / 0.25, 0, 1)
				local ang = r.A + t * 1.2
				local orbit = root.Position + Vector3.new(math.cos(ang) * 4, 1.5 + math.sin(t * 2 + k) * 0.4, math.sin(ang) * 4)
				local p = orbit:Lerp(root.Position + up * 0.6, k01 * k01)
				r.Core.CFrame = CFrame.new(p) * CFrame.Angles(t * 2, t * 1.5, 0)
				r.Glow.CFrame = CFrame.new(p)
				if k01 >= 1 then
					r.Core:Destroy()
					r.Glow:Destroy()
					VFXLib.flash(root.Position + up * 0.6, GOLD, 4, 14, 0.2)
					motes(root.Position + up * 0.6, 6, 2)
				end
			end
		end
		look.Brightness = -0.15 + 0.2 * math.clamp((t - starts[2]) / T[2], 0, 1)
	end)
	-- 3. The walls of light come down from the sky.
	task.delay(starts[3], function()
		if ended then
			return
		end
		walls = makeGap(character)
		VFXLib.animate(acc - starts[3] + 0.2, function(a)
			if ended or not root.Parent then
				return
			end
			local t = os.clock() - t0 - starts[3]
			local drop = math.clamp(t / 0.6, 0, 1)
			placeGap(character, walls, 1.2)
			for _, w in ipairs(walls) do
				w.CFrame = w.CFrame * CFrame.new(0, (1 - drop) * 30, 0)
			end
			if math.random() < 0.5 then
				local p = root.Position + Vector3.new((math.random() - 0.5) * 4, 10, (math.random() - 0.5) * 3)
				beam(p, p - up * 12, LIGHT, 0.06, 0.35)
			end
		end)
		look.TintColor = Color3.fromRGB(255, 240, 200)
		look.Brightness = 0.12
		look.Saturation = 0.05
		TuskStand.action(character, "Loom", { Target = CFrame.new(0, 2.4, 2.4), Duration = acc - starts[3] })
		CameraFX.shake(0.4, 0.5)
	end)
	task.delay(starts[4], function()
		if not ended then
			screenLine('ALL <font color="#FFD66E">MISFORTUNE</font> GOES <font color="#F07AAA">ELSEWHERE</font>', T[4] + 0.2)
		end
	end)
	task.delay(starts[5], function()
		if not ended and root.Parent then
			TuskVFX.CreateRotationalShockwave(CFrame.new(root.Position - Vector3.new(0, 2.8, 0)), { Radius = 16, Layers = 3, Color = GOLD, Color2 = PINK, Ground = true, Particles = 2, Width = 0.5 })
			motes(root.Position + up * 2, 24, 6)
		end
	end)
	return true
end
LoveTrainVFX.playCutscene = playCutscene

---------------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------------
local function onM1(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local index = data.Index or 1
	TuskAnimation.play(character, "V_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.6 or 0.6, 0.8, -3.2), Duration = 0.26 })
	VFXLib.sound(sounds.Swing, root, 0.5, 1.1 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index == 4 and LIGHT or GOLD, index == 4 and 1.4 or 1)
	if index == 4 then
		motes((root.CFrame * CFrame.new(0, 1, -3)).Position, 10, 2)
	end
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "Gap" and phase == "Redirect" and data.From and data.To then
		-- The misfortune carried off on a beam of light.
		beam(data.From + Vector3.new(0, 1, 0), data.To + Vector3.new(0, 1, 0), LIGHT, 0.14, 0.35)
		TuskVFX.CreateImpactStar(data.To + Vector3.new(0, 1, 0), { Size = 2.4, Rays = 6, Color = DARK, Color2 = LIGHT, Duration = 0.15 })
		if typeof(data.Victim) == "Instance" then
			label(data.Victim:FindFirstChild("Head"), "MISFORTUNE", Color3.fromRGB(190, 150, 230), 0.9, 180, Vector3.new(0, 3.2, 0))
		end
	elseif move == "Rail" then
		if phase == "Glide" and data.From and data.To then
			if character then
				TuskAnimation.play(character, "VHop")
			end
			local mid = (data.From + data.To) / 2
			local rail = VFXLib.part({ Size = Vector3.new(2.2, 0.08, (data.To - data.From).Magnitude), CFrame = CFrame.lookAt(mid - Vector3.new(0, 2.8, 0), data.To - Vector3.new(0, 2.8, 0)), Color = LIGHT, Material = Enum.Material.Neon, Transparency = 0.2 })
			local wall = VFXLib.part({ Size = Vector3.new(0.1, 6, (data.To - data.From).Magnitude), CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.5, 0), data.To + Vector3.new(0, 0.5, 0)), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.5 })
			VFXLib.animate(0.9, function(a)
				rail.Transparency = 0.2 + 0.8 * a
				wall.Transparency = 0.5 + 0.5 * a
			end, function()
				rail:Destroy()
				wall:Destroy()
			end)
			if character and isMe(character) then
				CameraFX.speedLines(data.Time or 0.45, LIGHT)
			end
		elseif phase == "Arrive" then
			for _, target in ipairs(data.Targets or {}) do
				local tr = typeof(target) == "Instance" and target:FindFirstChild("HumanoidRootPart")
				if tr then
					TuskVFX.CreateImpactStar(tr.Position, { Size = 3, Rays = 8, Color = LIGHT, Color2 = DARK, Duration = 0.15 })
				end
			end
			if data.Position then
				motes(data.Position, 10, 3)
			end
		end
	elseif move == "Transfer" then
		if phase == "Gather" and character and root then
			TuskAnimation.play(character, "VLoveTrain")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 1, -3.4), Duration = (data.Windup or 0.35) + 0.4 })
			-- Dark orbs of misfortune drain out of him into a ball.
			local ballAt = (root.CFrame * CFrame.new(0, 1.2, -2.2)).Position
			for _ = 1, 10 do
				local from = root.Position + Vector3.new((math.random() - 0.5) * 3, math.random() * 3 - 1, (math.random() - 0.5) * 3)
				local orb = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.35, 0.35, 0.35), Color = DARK, Material = Enum.Material.Neon, CFrame = CFrame.new(from) })
				orb.Shape = Enum.PartType.Ball
				VFXLib.animate(data.Windup or 0.35, function(a)
					orb.CFrame = CFrame.new(from:Lerp(ballAt, a * a))
				end, function()
					orb:Destroy()
				end)
			end
			label(character:FindFirstChild("Head"), "MISFORTUNE TRANSFER", Color3.fromRGB(200, 160, 240), 1.0, 280)
		elseif phase == "Land" and typeof(data.Target) == "Instance" then
			local tr = data.Target:FindFirstChild("HumanoidRootPart")
			if tr and root then
				beam(root.Position + Vector3.new(0, 1.2, 0), tr.Position, DARK, 0.5, 0.3)
				TuskVFX.CreateImpactStar(tr.Position, { Size = 4 + math.min(4, (data.Amount or 0) / 10), Rays = 10, Color = DARK, Color2 = Color3.fromRGB(200, 160, 240), Duration = 0.2 })
				label(data.Target:FindFirstChild("Head"), "MISFORTUNE ×" .. tostring(math.floor((data.Amount or 0) + 0.5)), Color3.fromRGB(200, 160, 240), 1.4, 260, Vector3.new(0, 3.6, 0))
				CameraFX.shakeAt(tr.Position, 0.7, 50)
			end
			if data.Hit and root then
				motes(root.Position, 14, 3, LIGHT)
			end
		end
	elseif move == "Spears" then
		if phase == "Form" and character and root then
			TuskAnimation.play(character, "VLoveTrain")
			local n = data.Count or 5
			for k = 1, n do
				local ang = math.rad(-(data.Spread or 50) / 2 + (data.Spread or 50) * (k - 1) / math.max(1, n - 1))
				local spear = VFXLib.part({ Size = Vector3.new(0.12, 0.12, 3), Color = LIGHT, Material = Enum.Material.Neon, Transparency = 1 })
				VFXLib.animate(data.Windup or 0.3, function(a)
					if root.Parent then
						spear.CFrame = root.CFrame * CFrame.new(0, 2.5, 1) * CFrame.Angles(0, -ang, 0) * CFrame.new(0, 0, -1.5 - a)
						spear.Transparency = 1 - a
					end
				end, function()
					spear:Destroy()
				end)
			end
		elseif phase == "Fire" then
			for _, l in ipairs(data.Lines or {}) do
				beam(l.From, l.To, LIGHT, 0.2, 0.3)
				if l.Hit then
					TuskVFX.CreateImpactStar(l.To, { Size = 2.6, Rays = 6, Color = LIGHT, Color2 = GOLD, Duration = 0.12 })
				end
			end
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character and root then
		TuskAnimation.play(character, "VLoveTrain")
		TuskStand.action(character, "Loom", { Target = CFrame.new(0, 2.6, 2.4), Duration = (data.Windup or 0.7) + 0.6 })
		label(character:FindFirstChild("Head"), "LOVE TRAIN: THE CHOSEN ONE", LIGHT, 1.8, 360)
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.1)
	elseif data.Phase == "Chosen" and character and root then
		-- A column of light round him for as long as it lasts.
		local column = VFXLib.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(40, 7, 7), Color = LIGHT, Material = Enum.Material.Neon, Transparency = 1 })
		column.Shape = Enum.PartType.Cylinder
		VFXLib.animate(data.Time or 7, function(a)
			local r = Common.rootOf(character)
			if not r then
				return
			end
			column.CFrame = CFrame.new(r.Position + Vector3.new(0, 16, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			column.Transparency = 0.75 + 0.1 * math.sin(os.clock() * 6) + (a > 0.9 and (a - 0.9) * 2.5 or 0)
			if math.random() < 0.3 then
				motes(r.Position + Vector3.new(0, 1, 0), 1, 4)
			end
		end, function()
			column:Destroy()
		end)
		if isMe(character) then
			CameraFX.impactFrame(pal.Light)
		end
	elseif data.Phase == "Pulse" and data.Position then
		TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position - Vector3.new(0, 2.8, 0)), { Radius = data.Radius or 22, Layers = 2, Color = LIGHT, Color2 = GOLD, Ground = true, Particles = 0.5, Width = 0.3, Duration = 0.5 })
		for _, target in ipairs(data.Targets or {}) do
			local tr = typeof(target) == "Instance" and target:FindFirstChild("HumanoidRootPart")
			if tr then
				TuskVFX.CreateImpactStar(tr.Position, { Size = 2, Rays = 5, Color = DARK, Color2 = LIGHT, Duration = 0.1 })
			end
		end
	elseif data.Phase == "Burst" and data.Position then
		VFXLib.flash(data.Position, LIGHT, 12, 40, 0.5)
		TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position - Vector3.new(0, 2.8, 0)), { Radius = data.Radius or 22, Layers = 4, Color = LIGHT, Color2 = PINK, Ground = true, Particles = 2, Width = 0.7 })
		motes(data.Position + Vector3.new(0, 2, 0), 30, 8)
		CameraFX.shakeAt(data.Position, 1, 70)
	end
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local function stepAll()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character then
			local act = character:GetAttribute("TuskAct")
			local want = act == ACT
			if want and not stanced[character] then
				stanced[character] = true
				TuskAnimation.hold(character, "VStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				-- (Back to D4C keeps the same stance.)
				if act ~= D4C_ACT then
					TuskAnimation.stopHold(character, "VStance")
				end
			end
			-- The gap of light.
			if want and not gaps[character] then
				gaps[character] = makeGap(character)
			elseif not want and gaps[character] then
				for _, p in ipairs(gaps[character]) do
					p:Destroy()
				end
				gaps[character] = nil
			end
		end
	end
	for character, parts in pairs(gaps) do
		if not character.Parent then
			for _, p in ipairs(parts) do
				p:Destroy()
			end
			gaps[character] = nil
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

local function watchMine()
	local c = localPlayer and localPlayer.Character
	local act = c and c:GetAttribute("TuskAct")
	if act == ACT and watchedAct == D4C_ACT then
		playCutscene(c)
	end
	watchedAct = act
end

function LoveTrainVFX.handle(name, data)
	if name == "M1" then
		onM1(data)
	elseif name == "M1Finisher" then
		Common.finisher(data, pal)
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

local slowTimer = 0
function LoveTrainVFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepAll()
		watchMine()
	end
	-- The walls of light follow him every frame; a few motes drift up.
	for character, parts in pairs(gaps) do
		placeGap(character, parts, inCutscene[character] and 0 or 1)
		if math.random() < 0.05 then
			local r = Common.rootOf(character)
			if r then
				motes(r.Position + Vector3.new(0, 1, 0), 1, 4)
			end
		end
	end
end

return LoveTrainVFX
```
