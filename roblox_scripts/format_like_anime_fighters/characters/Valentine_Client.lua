--[[
	Valentine_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Funny Valentine: D4C (Dirty Deeds Done Dirt Cheap), and D4C -Love Train- with the complete Saint's Corpse.
	Its other half is Valentine_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "valentine" or __expect.Side ~= "client") then
		error("this is the code for Valentine_Client, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Valentine_Client and put it in ReplicatedStorage > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: D4CStand
-- ======================================================================
__modules["D4CStand"] = function()
--[[
	TuskActVFX.D4CStand  (StarterPlayerScripts.SpinClient.TuskActVFX.D4CStand)

	The D4C (Dirty Deeds Done Dirt Cheap) Stand model (Funny Valentine),
	blocky, matched to the art:
	  * a sleek, shiny ice-blue humanoid
	  * two long flat rabbit ears swept up and back from the head
	  * a narrow face with a ridge down the middle and dark eyes
	  * big pink balls on the shoulders, pink briefs at the hips
	  * white crosses on the chest, thin pink lines down the arms and legs
	Registered with TuskStandModels by ValentineVFX, so TuskStand floats it
	behind Valentine (players and NPCs) with an ice-blue aura. A custom model
	at ReplicatedStorage.SpinAssets.TuskAct13 replaces it.
]]

local D4CStand = {}

local BODY = Color3.fromRGB(176, 228, 240)
local BODY_SHADE = Color3.fromRGB(130, 194, 214)
local SHINE = Color3.fromRGB(236, 250, 255)
local PINK = Color3.fromRGB(234, 124, 166)
local WHITE = Color3.fromRGB(250, 252, 255)
local DARK = Color3.fromRGB(40, 60, 80)

D4CStand.Aura = Color3.fromRGB(140, 220, 240)
D4CStand.AuraLight = Color3.fromRGB(230, 240, 255)
D4CStand.Offset = CFrame.new(2.3, 1.6, 2.8)

local function newPart(model, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	p.Parent = model
	return p
end

local function box(model, parent, name, size, color, cf, material)
	local p = newPart(model, name, size, color, material)
	local w = Instance.new("Weld")
	w.Part0 = parent
	w.Part1 = p
	w.C0 = cf
	w.Parent = p
	p.CFrame = parent.CFrame * cf
	return p, w
end

-- Thin pink lines down both sides of a limb.
local function pinkLines(model, parent, size, s)
	for _, side in ipairs({ -1, 1 }) do
		box(model, parent, "PinkLine", Vector3.new(0.05 * s, size.Y * 0.9, 0.08 * s), PINK, CFrame.new(side * (size.X / 2 + 0.01 * s), 0, 0))
	end
end

-- A white cross (+) on a face.
local function cross(model, parent, cf, size)
	box(model, parent, "Cross", Vector3.new(size, size * 0.28, 0.05), WHITE, cf)
	box(model, parent, "Cross", Vector3.new(size * 0.28, size, 0.05), WHITE, cf)
end

function D4CStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "D4C"
	local rig = { Joints = {} }

	-- Sleek torso (the anchored root the Stand is moved by), narrowing to the waist.
	local torso = newPart(model, "Body", Vector3.new(2.0, 1.7, 1.0) * s, BODY, Enum.Material.SmoothPlastic)
	torso.Reflectance = 0.12
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.51 * s
	box(model, torso, "Chest", Vector3.new(1.7, 0.9, 0.1) * s, BODY_SHADE, CFrame.new(0, 0.3 * s, front - 0.02 * s))
	cross(model, torso, CFrame.new(-0.4 * s, 0.35 * s, front - 0.08 * s), 0.5 * s)
	cross(model, torso, CFrame.new(0.4 * s, 0.35 * s, front - 0.08 * s), 0.5 * s)
	box(model, torso, "Waist", Vector3.new(1.4, 0.7, 0.8) * s, BODY_SHADE, CFrame.new(0, -1.1 * s, 0))
	for k = 0, 1 do
		box(model, torso, "Ab", Vector3.new(0.9, 0.22, 0.06) * s, BODY, CFrame.new(0, (-0.95 - k * 0.28) * s, -0.42 * s))
	end
	-- Pink briefs at the hips.
	box(model, torso, "Briefs", Vector3.new(1.5, 0.5, 0.86) * s, PINK, CFrame.new(0, -1.6 * s, 0))
	box(model, torso, "Neck", Vector3.new(0.45, 0.45, 0.45) * s, BODY_SHADE, CFrame.new(0, 1.05 * s, 0))

	-- Head: narrow, a ridge down the face, dark eyes, long flat rabbit ears swept back.
	local headBase = CFrame.new(0, 1.15 * s, 0)
	local headOffset = CFrame.new(0, 0.55 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.8, 1.1, 0.9) * s, BODY, headBase * headOffset)
	head.Reflectance = 0.12
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.45 * s
	box(model, head, "Ridge", Vector3.new(0.1, 0.9, 0.08) * s, SHINE, CFrame.new(0, 0, hf - 0.03 * s))
	box(model, head, "Jaw", Vector3.new(0.6, 0.3, 0.8) * s, BODY_SHADE, CFrame.new(0, -0.5 * s, -0.04 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.24, 0.12, 0.06) * s, DARK, CFrame.new(side * 0.2 * s, 0.1 * s, hf - 0.02 * s) * CFrame.Angles(0, 0, side * 0.2))
		-- Long flat ear: three tapering plates, swept up and back.
		local earBase = CFrame.new(side * 0.22 * s, 0.5 * s, 0.1 * s) * CFrame.Angles(-0.35, 0, side * -0.08)
		for k = 0, 2 do
			local w = (0.34 - k * 0.07) * s
			box(model, head, "Ear", Vector3.new(w, 0.75 * s, 0.12 * s), BODY, earBase * CFrame.new(0, (0.37 + k * 0.72) * s, 0))
		end
		box(model, head, "EarInner", Vector3.new(0.08, 1.7, 0.04) * s, PINK, earBase * CFrame.new(0, 1.05 * s, -0.08 * s))
	end

	-- Big pink shoulder balls and sleek arms with pink lines.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		box(model, torso, "ShoulderBall", Vector3.new(1.0, 1.0, 1.0) * s, PINK, CFrame.new(side * 1.3 * s, 0.65 * s, 0), Enum.Material.SmoothPlastic).Shape = Enum.PartType.Ball
		local base = CFrame.new(side * 1.35 * s, 0.35 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local size = Vector3.new(0.5, 2.2, 0.5) * s
		local arm, weld = box(model, torso, a[1], size, BODY, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		pinkLines(model, arm, size, s)
		box(model, arm, "Forearm", Vector3.new(0.58, 0.9, 0.58) * s, BODY_SHADE, CFrame.new(0, -0.5 * s, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.5, 0.5, 0.45) * s, BODY, CFrame.new(0, -1.3 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.09, 0.4, 0.09) * s, BODY_SHADE, CFrame.new(f * 0.11 * s, -0.4 * s, -0.05 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Long legs with pink lines.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.42 * s, -1.75 * s, 0)
		local offset = CFrame.new(0, -1.25 * s, 0)
		local size = Vector3.new(0.6, 2.5, 0.6) * s
		local leg, weld = box(model, torso, "Leg" .. i, size, BODY, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		pinkLines(model, leg, size, s)
		box(model, leg, "Knee", Vector3.new(0.5, 0.3, 0.1) * s, SHINE, CFrame.new(0, 0.2 * s, -0.32 * s))
		box(model, leg, "Foot", Vector3.new(0.5, 0.25, 0.9) * s, BODY_SHADE, CFrame.new(0, -1.35 * s, -0.15 * s))
	end
	return model, rig
end

return D4CStand
end

-- ======================================================================
-- MODULE: LoveTrainVFX
-- ======================================================================
__modules["LoveTrainVFX"] = function()
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

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local TuskStandModels = __require("TuskStandModels")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Common = __require("TuskActCommon")
local Fighters = __require("Fighters")
local TuskStand = __require("TuskStand")
local Cutscenes = __require("Cutscenes")
local D4CStand = __require("D4CStand")

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
end

-- ======================================================================
-- MODULE: ValentineVFX
-- ======================================================================
__modules["ValentineVFX"] = function()
--[[
	TuskActVFX.ValentineVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.ValentineVFX)

	Client visuals for Funny Valentine / D4C. Blocky.
	  * the D4C Stand (D4CStand) floats behind him with a pale-blue aura and
	    strikes with his moves
	  * DIMENSION HOP: a striped flag sweeps round him and he's gone; where he
	    steps out, a flag unfurls and falls away; a flag on a pole stays
	    planted where he left from while he can hop back to it
	  * PARALLEL VALENTINE: a shimmering Valentine from another world (pink
	    coat, blond ringlets) steps out of a flag, chases the nearest enemy
	    and punches, then leaves; when they SWAP or TRADE places, flags
	    flash at both spots
	  * flags: the 4th M1 hit wraps them in one; D4C's second chop after a
	    hop; hopping back slams the left flag shut with a ring of light
	  * the Menger cubes fly on to the next enemy and crumble them too
	  * MENGER SPONGE: the target's other-world double stands where it
	    appeared, flickering; near it their body crumbles into little cubes
	    (Menger sponges orbit them), then bursts; get away and the double
	    shatters
	  * D4C LOVE TRAIN: a column of light falls on him and a shell of light
	    surrounds him; every hit on him bounces off as a bolt of light into
	    someone else; it ends with a ring of light
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local TuskStandModels = __require("TuskStandModels")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Common = __require("TuskActCommon")
local Fighters = __require("Fighters")
local TuskStand = __require("TuskStand")
local D4CStand = __require("D4CStand")

local ValentineVFX = {}
local ACT = 13
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds

-- D4C floats behind him (players and NPCs), like Tusk does.
TuskStandModels.register(ACT, D4CStand.build, { Aura = D4CStand.Aura, AuraLight = D4CStand.AuraLight, Offset = D4CStand.Offset })

local RED = Color3.fromRGB(190, 40, 50)
local WHITE = Color3.fromRGB(245, 245, 240)
local BLUE = Color3.fromRGB(40, 60, 140)
local LIGHT = Color3.fromRGB(255, 250, 225)
local SHIMMER = Color3.fromRGB(170, 200, 255)
local CUBE = Color3.fromRGB(200, 196, 190)

local clones = {} -- [id] = a parallel Valentine
local anchors = {} -- [character] = flag planted where he hopped from
local crumbling = {} -- [character] = cubes and double
local trains = {} -- [character] = light shell
local stanced = {}

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function box(model, size, cf, color, material, transparency)
	local p = VFXLib.part({ Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, Transparency = transparency or 0 })
	p.Parent = model
	return p
end

local function newModel(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = VFXLib.Folder
	return m
end

local function finish(m)
	local item = { Model = m, Parts = {}, Offsets = {} }
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			table.insert(item.Parts, p)
			item.Offsets[p] = p.CFrame
		end
	end
	return item
end

local function place(item, cf)
	for _, p in ipairs(item.Parts) do
		p.CFrame = cf * item.Offsets[p]
	end
end

local function fade(item, a)
	for _, p in ipairs(item.Parts) do
		p.Transparency = math.max(p.Transparency, a)
	end
end

-- A striped flag (7 stripes, a blue canton with white stars), built round its centre.
local function buildFlag(w, h)
	local m = newModel("Flag")
	local stripeH = h / 7
	for i = 0, 6 do
		box(m, Vector3.new(w, stripeH, 0.08), CFrame.new(0, h / 2 - stripeH * (i + 0.5), 0), i % 2 == 0 and RED or WHITE, Enum.Material.Fabric)
	end
	local cw, ch = w * 0.4, stripeH * 4
	box(m, Vector3.new(cw, ch, 0.1), CFrame.new(-w / 2 + cw / 2, h / 2 - ch / 2, -0.01), BLUE, Enum.Material.Fabric)
	for i = 0, 2 do
		for j = 0, 1 do
			box(m, Vector3.new(0.18, 0.18, 0.12), CFrame.new(-w / 2 + cw * (0.2 + i * 0.3), h / 2 - ch * (0.3 + j * 0.4), -0.02), WHITE, Enum.Material.Neon)
		end
	end
	return finish(m)
end

-- A Valentine from another world: his look (pink coat, blond ringlets,
-- magenta trousers), shimmering.
local function buildValentine()
	local m = newModel("ParallelValentine")
	local coat, coatShade = Color3.fromRGB(232, 150, 196), Color3.fromRGB(200, 116, 166)
	local hair, hairDark = Color3.fromRGB(238, 218, 130), Color3.fromRGB(204, 180, 96)
	local skin, pants, grey = Color3.fromRGB(240, 210, 190), Color3.fromRGB(196, 96, 210), Color3.fromRGB(120, 116, 124)
	box(m, Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), coat)
	box(m, Vector3.new(1.2, 0.45, 1.1), CFrame.new(0, 4.15, 0), grey) -- high collar
	box(m, Vector3.new(0.08, 2.1, 0.05), CFrame.new(0.15, 3, -0.52) * CFrame.Angles(0, 0, -0.18), coatShade)
	-- Long coat skirt flaring to the calves, open at the front.
	box(m, Vector3.new(2.5, 2.4, 0.14), CFrame.new(0, 1, 0.62) * CFrame.Angles(0.06, 0, 0), coat)
	for _, side in ipairs({ -1, 1 }) do
		box(m, Vector3.new(0.7, 2.3, 0.14), CFrame.new(side * 0.95, 1, -0.58) * CFrame.Angles(0, side * 0.35, 0), coat)
		box(m, Vector3.new(0.14, 2.3, 1.3), CFrame.new(side * 1.16, 1, 0.05), coatShade)
	end
	box(m, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 4.9, 0), skin)
	box(m, Vector3.new(1.4, 0.4, 1.4), CFrame.new(0, 5.55, 0), hair)
	box(m, Vector3.new(1.5, 1.6, 0.3), CFrame.new(0, 4.5, 0.65), hair)
	for _, side in ipairs({ -1, 1 }) do
		box(m, Vector3.new(0.2, 1.2, 1.1), CFrame.new(side * 0.7, 4.6, 0.05), hair)
		-- Spiral ringlets at the sides.
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			box(m, Vector3.new(0.14, 0.2, 0.2), CFrame.new(side * 0.95, 4.9 + math.sin(a) * 0.3, math.cos(a) * 0.3), k % 2 == 0 and hair or hairDark)
		end
		box(m, Vector3.new(1, 2, 1), CFrame.new(side * 1.5, 3, 0), coat)
		box(m, Vector3.new(1.1, 0.25, 1.1), CFrame.new(side * 1.5, 2.1, 0), grey)
		box(m, Vector3.new(1, 0.4, 1), CFrame.new(side * 1.5, 1.8, 0), Color3.fromRGB(214, 110, 196))
		box(m, Vector3.new(1, 2, 1), CFrame.new(side * 0.5, 1, 0), pants)
	end
	local item = finish(m)
	local hl = Instance.new("Highlight")
	hl.FillColor = SHIMMER
	hl.FillTransparency = 0.6
	hl.OutlineColor = SHIMMER
	hl.Adornee = m
	hl.Parent = m
	return item
end

-- A level-1 Menger sponge: a cube of 20 little cubes (the centre and face centres missing).
local function buildSponge(size)
	local m = newModel("MengerSponge")
	local c = size / 3
	for x = -1, 1 do
		for y = -1, 1 do
			for z = -1, 1 do
				local zeros = (x == 0 and 1 or 0) + (y == 0 and 1 or 0) + (z == 0 and 1 or 0)
				if zeros < 2 then
					box(m, Vector3.new(c, c, c) * 0.96, CFrame.new(x * c, y * c, z * c), (x + y + z) % 2 == 0 and CUBE or CUBE:Lerp(SHIMMER, 0.4))
				end
			end
		end
	end
	return finish(m)
end

local function flash(position, size)
	TuskVFX.CreateImpactStar(position, { Size = size or 3, Rays = 8, Color = LIGHT, Color2 = SHIMMER, Duration = 0.15 })
end

---------------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------------
local function onM1(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local index = data.Index
	TuskAnimation.play(character, "V_M1_" .. index)
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1, -3.1), Duration = 0.28 })
	VFXLib.sound(sounds.Swing, root, 0.5, 1.0 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or pal.Second)
end

-- The flag sweeps round him and he slips away.
local function flagWrap(position)
	local flag = buildFlag(6, 4)
	VFXLib.animate(0.35, function(a)
		local angle = a * math.pi * 2.2
		local r = 1.6 * (1 - a * 0.6)
		place(flag, CFrame.new(position) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.5, -r) * CFrame.Angles(0, 0, math.sin(a * 8) * 0.15))
		fade(flag, a * a)
	end, function()
		flag.Model:Destroy()
	end)
	flash(position + Vector3.new(0, 1, 0), 3.5)
end

-- Where he steps out, a flag unfurls and drops away.
local function flagUnfurl(position)
	local flag = buildFlag(6, 4)
	VFXLib.animate(0.5, function(a)
		local open = math.min(a / 0.3, 1)
		place(flag, CFrame.new(position + Vector3.new(0, 0.5 - a * a * 3, 0)) * CFrame.Angles(0, (1 - open) * math.pi, 0) * CFrame.new(0, 0, -1.2))
		fade(flag, math.max(0, (a - 0.5) * 2))
	end, function()
		flag.Model:Destroy()
	end)
	flash(position + Vector3.new(0, 1, 0), 3.5)
end

local function onFinisher(data)
	Common.finisher(data, pal)
	-- The 4th hit wraps them in a flag.
	if data.Position then
		flagWrap(data.Position)
	end
end

local function cloneStep(dt)
	local now = os.clock()
	for id, c in pairs(clones) do
		if now > c.Until then
			clones[id] = nil
			flagWrap(c.Pos + Vector3.new(0, 1.5, 0))
			c.Item.Model:Destroy()
		else
			local tr = c.Target and Common.rootOf(c.Target)
			local goal = tr and tr.Position or (c.Owner and Common.rootOf(c.Owner) and (Common.rootOf(c.Owner).CFrame * CFrame.new(-3, 0, 2)).Position) or c.Pos
			local to = goal - c.Pos
			local reach = tr and 4 or 2
			if to.Magnitude > reach then
				c.Pos = c.Pos + to.Unit * math.min(c.Speed * dt, to.Magnitude - reach * 0.8)
			end
			local look = Vector3.new(to.X, 0, to.Z)
			local cf = CFrame.lookAt(c.Pos, c.Pos + (look.Magnitude > 0.1 and look or Vector3.new(0, 0, -1)))
			local punch = math.max(0, 1 - (now - c.PunchAt) / 0.25)
			place(c.Item, cf * CFrame.new(0, -3 + math.abs(math.sin(now * 9)) * 0.2, -punch * 1.2))
			-- Shimmers between worlds.
			for _, p in ipairs(c.Item.Parts) do
				p.Transparency = 0.15 + 0.15 * math.abs(math.sin(now * 6 + id))
			end
		end
	end
end

-- The target's other-world double flickers beside them; their body crumbles into cubes.
local function startCrumble(target, duration, doublePos, leash, noDouble)
	local tr = Common.rootOf(target)
	if not tr then
		return
	end
	local old = crumbling[target]
	if old then
		for _, sp in ipairs(old.Sponges) do
			sp.Model:Destroy()
		end
		old.Double.Model:Destroy()
	end
	local torso = target:FindFirstChild("UpperTorso") or target:FindFirstChild("Torso")
	local color = torso and torso.Color or Color3.fromRGB(150, 150, 160)
	local dm = newModel("OtherWorldDouble")
	if not noDouble then
		box(dm, Vector3.new(2, 2, 1), CFrame.new(0, 0, 0), color, Enum.Material.Glass, 0.4)
		box(dm, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 1.6, 0), color:Lerp(WHITE, 0.4), Enum.Material.Glass, 0.4)
		for _, side in ipairs({ -1, 1 }) do
			box(dm, Vector3.new(1, 2, 1), CFrame.new(side * 1.5, 0, 0), color, Enum.Material.Glass, 0.4)
			box(dm, Vector3.new(1, 2, 1), CFrame.new(side * 0.5, -2, 0), color:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Glass, 0.4)
		end
	end
	local sponges = {}
	for i = 1, 4 do
		sponges[i] = buildSponge(0.9)
	end
	crumbling[target] = { Double = finish(dm), Sponges = sponges, Born = os.clock(), Duration = duration or 3, Next = 0, DoublePos = doublePos, Leash = leash or 10 }
	flash(tr.Position, 3)
end

local function crumbleStep(dt)
	local now = os.clock()
	for target, c in pairs(crumbling) do
		local tr = Common.rootOf(target)
		if not tr or now - c.Born > c.Duration + 0.3 then
			crumbling[target] = nil
			for _, sp in ipairs(c.Sponges) do
				sp.Model:Destroy()
			end
			c.Double.Model:Destroy()
		else
			local t = now - c.Born
			-- The double stands where it appeared, facing them, flickering.
			local at = c.DoublePos or (tr.CFrame * CFrame.new(3.2, 0, 0)).Position
			local face = Vector3.new(tr.Position.X, at.Y, tr.Position.Z)
			place(c.Double, (face - at).Magnitude > 0.1 and CFrame.lookAt(at, face) or CFrame.new(at))
			local near = (tr.Position - at).Magnitude <= c.Leash
			local flick = (math.floor(t * 14) % 3 == 0) and 0.75 or 0.4
			for _, p in ipairs(c.Double.Parts) do
				p.Transparency = flick
			end
			-- Menger sponges orbit them.
			for i, sp in ipairs(c.Sponges) do
				local a = t * 2.5 + i / #c.Sponges * math.pi * 2
				place(sp, CFrame.new(tr.Position + Vector3.new(math.cos(a) * 2.4, math.sin(t * 3 + i) * 1.2, math.sin(a) * 2.4)) * CFrame.Angles(t * 2, t * 3, 0))
			end
			-- Little cubes break off the body and drift away (only near the double).
			c.Next = near and c.Next - dt or 0.06
			while c.Next <= 0 and near do
				c.Next = c.Next + 0.06
				local from = tr.Position + Vector3.new((math.random() - 0.5) * 2, (math.random() - 0.5) * 4, (math.random() - 0.5) * 1.4)
				local cube = VFXLib.part({ Size = Vector3.new(0.35, 0.35, 0.35), Color = CUBE, Material = Enum.Material.SmoothPlastic })
				local drift = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5) * 6
				VFXLib.animate(0.6, function(a)
					cube.CFrame = CFrame.new(from + drift * a) * CFrame.Angles(a * 5, a * 3, 0)
					cube.Transparency = a
				end, function()
					cube:Destroy()
				end)
			end
		end
	end
end

-- A flag on a pole planted where he hopped from (he can hop back to it).
local function plantAnchor(character, position, duration)
	local old = anchors[character]
	if old then
		old.Flag.Model:Destroy()
		old.Pole:Destroy()
	end
	local pole = VFXLib.part({ Size = Vector3.new(0.2, 7, 0.2), CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)), Color = Color3.fromRGB(220, 220, 225), Material = Enum.Material.Metal })
	local flag = buildFlag(3.2, 2)
	anchors[character] = { Flag = flag, Pole = pole, Pos = position, Until = os.clock() + (duration or 4) }
end

local function removeAnchor(character)
	local a = anchors[character]
	if a then
		anchors[character] = nil
		flagWrap(a.Pos)
		a.Flag.Model:Destroy()
		a.Pole:Destroy()
	end
end

local function anchorStep()
	local now = os.clock()
	for character, a in pairs(anchors) do
		if now > a.Until or not character.Parent then
			anchors[character] = nil
			a.Flag.Model:Destroy()
			a.Pole:Destroy()
		else
			-- The flag waves at the top of the pole.
			place(a.Flag, CFrame.new(a.Pos + Vector3.new(1.7, 3, 0)) * CFrame.Angles(0, math.sin(now * 3) * 0.25, math.sin(now * 5) * 0.05))
			-- Blinks in its last second.
			local blink = (a.Until - now) < 1 and (math.floor(now * 8) % 2 == 0)
			for _, p in ipairs(a.Flag.Parts) do
				p.Transparency = blink and 0.6 or 0
			end
		end
	end
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "DimensionHop" then
		if phase == "Wrap" then
			TuskAnimation.play(character, "VHop")
			flagWrap(data.Position or (root and root.Position))
		elseif phase == "Anchor" and character then
			plantAnchor(character, data.Position, data.Duration)
		elseif phase == "AnchorGone" and character then
			removeAnchor(character)
		elseif phase == "Chop" and data.Position then
			-- D4C's second chop.
			TuskStand.action(character, "Lunge", { Target = CFrame.new(-0.8, 1.2, -3.2), Duration = 0.22 })
			TuskVFX.CreateImpactStar(data.Position, { Size = 3, Rays = 7, Color = pal.Main, Color2 = WHITE, Duration = 0.12 })
		elseif phase == "FlagSlam" and data.Position then
			-- Hopping back: the flag slams shut, a ring of light where it stood.
			flagWrap(data.Position)
			flash(data.Position + Vector3.new(0, 1, 0), 5)
			local ring = VFXLib.part({ Size = Vector3.new(0.3, 1, 1), Color = LIGHT, Material = Enum.Material.Neon, Transparency = 0.2, Shape = Enum.PartType.Cylinder })
			VFXLib.animate(0.35, function(a)
				local d = (data.Radius or 7) * 2 * a
				ring.Size = Vector3.new(0.3, d, d)
				ring.CFrame = CFrame.new(data.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				ring.Transparency = 0.2 + 0.8 * a
			end, function()
				ring:Destroy()
			end)
			CameraFX.shakeAt(data.Position, 0.4, 40)
		elseif phase == "Unwrap" then
			flagUnfurl(data.Position)
			TuskStand.action(character, "Lunge", { Duration = 0.35 })
			if Common.isLocal(character) then
				CameraFX.fovPunch(6, 0.2)
			end
		end
	elseif move == "ParallelClone" then
		if phase == "Call" and character then
			TuskAnimation.play(character, "VCall")
			TuskStand.action(character, "Manifest", { Duration = 0.5 })
		elseif phase == "Arrive" then
			local item = buildValentine()
			clones[data.Id] = { Item = item, Pos = data.From, Speed = data.Speed or 20, Until = os.clock() + (data.Duration or 6) + 0.6, Owner = character, PunchAt = 0 }
			flagUnfurl(data.From + Vector3.new(0, 1.5, 0))
		elseif phase == "Chase" then
			local c = clones[data.Id]
			if c then
				c.Target = data.Target
			end
		elseif phase == "Punch" then
			local c = clones[data.Id]
			if c then
				c.PunchAt = os.clock()
			end
			if data.Position then
				TuskVFX.CreateImpactStar(data.Position, { Size = 2.6, Rays = 6, Color = pal.Main, Color2 = WHITE, Duration = 0.12 })
			end
		elseif phase == "Trade" then
			-- Pressed 2 again: he and his other self trade places in a flash of flags.
			local c = clones[data.Id]
			if c and data.From then
				c.Pos = data.From
			end
			flagWrap(data.From)
			flagWrap(data.To)
			flagUnfurl(data.To)
			flash(data.To + Vector3.new(0, 1, 0), 4)
			if character and Common.isLocal(character) then
				CameraFX.fovPunch(5, 0.2)
			end
		elseif phase == "Swap" then
			-- They trade places: flags at both spots, and the other one is gone.
			local c = clones[data.Id]
			if c then
				clones[data.Id] = nil
				c.Item.Model:Destroy()
			end
			flagWrap(data.From)
			flagUnfurl(data.To)
			flash(data.To + Vector3.new(0, 1, 0), 5)
			if character and Common.isLocal(character) then
				CameraFX.impactFrame(SHIMMER)
			end
		elseif phase == "Leave" then
			local c = clones[data.Id]
			if c then
				c.Until = 0 -- wraps itself in a flag and goes next frame
			end
		end
	elseif move == "MengerSponge" then
		if phase == "Cast" and character then
			TuskAnimation.play(character, "VMenger")
			TuskStand.action(character, "Lunge", { Duration = 0.45 })
		elseif phase == "Crumble" and data.Target then
			startCrumble(data.Target, data.Duration, data.DoublePos, data.Leash)
		elseif phase == "Escape" and data.Target then
			-- They got away from their double: it shatters into cubes.
			local c = crumbling[data.Target]
			if c then
				crumbling[data.Target] = nil
				local at = c.DoublePos or data.Position
				for _, sp in ipairs(c.Sponges) do
					sp.Model:Destroy()
				end
				c.Double.Model:Destroy()
				VFXLib.burst(at, { Count = 24, Color = CUBE, Speed = 16, Lifetime = 0.45 })
			end
		elseif phase == "Spread" and data.Target and data.From then
			-- The cubes fly over to the next enemy and start crumbling them.
			local tr = Common.rootOf(data.Target)
			if tr then
				for k = 1, 10 do
					local cube = VFXLib.part({ Size = Vector3.new(0.4, 0.4, 0.4), Color = CUBE, Material = Enum.Material.SmoothPlastic })
					local from = data.From + Vector3.new((math.random() - 0.5) * 2, math.random() * 2, (math.random() - 0.5) * 2)
					VFXLib.animate(0.35 + k * 0.02, function(a)
						local to = tr.Parent and tr.Position or from
						cube.CFrame = CFrame.new(from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * 3, 0)) * CFrame.Angles(a * 6, a * 4, 0)
					end, function()
						cube:Destroy()
					end)
				end
				startCrumble(data.Target, data.Duration or 1.6, tr.Position, 1000, true)
			end
		elseif phase == "Burst" and data.Position then
			VFXLib.burst(data.Position, { Count = 30, Color = CUBE, Speed = 22, Lifetime = 0.5 })
			flash(data.Position, 5)
			if data.Target and crumbling[data.Target] then
				crumbling[data.Target].Duration = 0
			end
		elseif phase == "Miss" and root then
			flash((root.CFrame * CFrame.new(0, 0, -6)).Position, 2)
		end
	end
end

-- Love Train: a column of light, then a shell of light that follows him.
local function startTrain(character, duration)
	local m = newModel("LoveTrain")
	local shell = box(m, Vector3.new(5, 7, 5), CFrame.new(), LIGHT, Enum.Material.ForceField, 0.2)
	local rays = {}
	for i = 1, 6 do
		rays[i] = box(m, Vector3.new(0.25, 9, 0.25), CFrame.new(), LIGHT, Enum.Material.Neon, 0.35)
	end
	local light = Instance.new("PointLight")
	light.Color = LIGHT
	light.Range = 16
	light.Brightness = 2
	light.Parent = shell
	trains[character] = { Model = m, Shell = shell, Rays = rays, Until = os.clock() + duration + 0.5 }
end

local function trainStep()
	local now = os.clock()
	for character, tr in pairs(trains) do
		local root = Common.rootOf(character)
		-- Ends on time, or once the server has switched it off.
		if not root or now > tr.Until or (tr.Started and now > tr.Started + 1 and not character:GetAttribute("LoveTrain")) then
			trains[character] = nil
			tr.Model:Destroy()
		else
			tr.Started = tr.Started or now
			local pulse = 1 + math.sin(now * 6) * 0.04
			tr.Shell.Size = Vector3.new(5, 7, 5) * pulse
			tr.Shell.CFrame = root.CFrame
			for i, ray in ipairs(tr.Rays) do
				local a = now * 1.6 + i / #tr.Rays * math.pi * 2
				ray.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(a) * 3, 0.5, math.sin(a) * 3)) * CFrame.Angles(0, -a, 0.15)
			end
		end
	end
end

-- A bolt of light from him to whoever gets the misfortune.
local function bolt(from, to)
	local segments = 6
	local prev = from + Vector3.new(0, 1, 0)
	for i = 1, segments do
		local t = i / segments
		local p = (from + Vector3.new(0, 1, 0)):Lerp(to + Vector3.new(0, 1, 0), t) + (i < segments and Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 or Vector3.new())
		local seg = VFXLib.part({ Size = Vector3.new(0.3, 0.3, (p - prev).Magnitude), CFrame = CFrame.lookAt((prev + p) / 2, p), Color = LIGHT, Material = Enum.Material.Neon })
		VFXLib.animate(0.25, function(a)
			seg.Transparency = a
		end, function()
			seg:Destroy()
		end)
		prev = p
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Board" then
		TuskAnimation.play(character, "VLoveTrain")
		TuskStand.action(character, "Manifest", { Duration = 0.8 })
		if root then
			-- A column of light comes down on him.
			local column = VFXLib.part({ Size = Vector3.new(6, 60, 6), Color = LIGHT, Material = Enum.Material.Neon, Transparency = 0.4 })
			local at = root.Position
			VFXLib.animate(data.Windup or 0.7, function(a)
				column.CFrame = CFrame.new(at + Vector3.new(0, 30 - a * 2, 0))
				column.Size = Vector3.new(6 - a * 2, 60, 6 - a * 2)
				column.Transparency = 0.4 + 0.6 * a
			end, function()
				column:Destroy()
			end)
			flash(at + Vector3.new(0, 2, 0), 6)
		end
		task.delay(data.Windup or 0.7, function()
			if character and character.Parent then
				startTrain(character, data.Duration or 6)
			end
		end)
		if Common.isLocal(character) then
			TuskVFX.ScreenTint((data.Windup or 0.7) + (data.Duration or 6), { Tint = Color3.fromRGB(255, 250, 230), Saturation = 0.1, Brightness = 0.06 })
		end
		if root then
			VFXLib.sound(sounds.AwakeningBuild, root, 0.5, 1.2)
		end
	elseif data.Phase == "Redirect" then
		if data.From then
			flash(data.From + Vector3.new(0, 1, 0), 3)
		end
		if data.From and data.To then
			bolt(data.From, data.To)
			TuskVFX.CreateImpactStar(data.To, { Size = 3.5, Rays = 7, Color = LIGHT, Color2 = pal.Second, Duration = 0.15 })
		end
	elseif data.Phase == "Pulse" then
		local tr = trains[character]
		if tr then
			trains[character] = nil
			tr.Model:Destroy()
		end
		local ring = VFXLib.part({ Size = Vector3.new(0.6, 1, 1), Color = LIGHT, Material = Enum.Material.Neon, Transparency = 0.2, Shape = Enum.PartType.Cylinder })
		local at = data.Position
		local r = data.Radius or 14
		VFXLib.animate(0.45, function(a)
			ring.Size = Vector3.new(0.6, r * 2 * a, r * 2 * a)
			ring.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
			ring.Transparency = 0.2 + 0.8 * a
		end, function()
			ring:Destroy()
		end)
		Common.finisher({ Character = character, Position = at, Hit = true }, pal, { Size = 1.3, Layers = 2, Shake = 0.6 })
	end
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local function stepStance()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character then
			local want = character:GetAttribute("TuskAct") == ACT
			if want and not stanced[character] then
				stanced[character] = true
				TuskAnimation.hold(character, "VStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				-- (D4C -Love Train- keeps the same stance.)
				if character:GetAttribute("TuskAct") ~= 33 then
					TuskAnimation.stopHold(character, "VStance")
				end
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function ValentineVFX.handle(name, data)
	if name == "M1" then
		onM1(data)
	elseif name == "M1Finisher" then
		onFinisher(data)
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

local slowTimer = 0
function ValentineVFX.step(dt)
	dt = dt or 1 / 60
	cloneStep(dt)
	crumbleStep(dt)
	anchorStep()
	trainStep()
	slowTimer = slowTimer + dt
	if slowTimer > 0.2 then
		slowTimer = 0
		stepStance()
	end
end

return ValentineVFX
end
end
