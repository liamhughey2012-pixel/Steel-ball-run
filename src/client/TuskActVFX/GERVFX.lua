--[[
	TuskActVFX.GERVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.GERVFX)

	Client visuals for GOLD EXPERIENCE REQUIEM (Giorno, Act 31, from the
	Requiem Arrow). Blocky. Bright gold with violet: the colours of the art.
	  * Gold Experience Requiem (GERStand) looms behind him; violet star
	    sparkles drift round him the whole time
	  * THE TRANSFORMATION (a cutscene, when YOU take the arrow as Giorno):
	      1. the arrow streaks down out of the sky at Gold Experience
	      2. close on its chest: the arrow pierces it ("ズキュゥゥン")
	      3. a pillar of gold and violet light swallows it, lightning
	         cracking round it
	      4. Giorno in profile with Requiem's head beside his, a cosmic
	         violet sky behind them, white lightning: "WHAT YOU ARE SEEING
	         IS CERTAINLY THE TRUTH." (as in the image)
	      5. Requiem towers over him: "GOLD EXPERIENCE REQUIEM"
	    (Anyone else near sees the pillar of light.)
	  * REQUIEM MUDA COMBO / MUDA RUSH: REQUIEM: golden fists with violet
	    trails, "MUDA", a huge "MUDAAA!" and a violet shockwave
	  * RETURN TO ZERO: a golden clock face turns round him while he waits;
	    an attacker is wound back along a trail of afterimages to where they
	    started, the clock spinning backwards ("RETURN TO ZERO")
	  * ZERO PUNCH: he's suddenly there (a streak of afterimages), a big
	    golden fist, "ZERO" over whoever it cancels
	  * INFINITE DEATH: "INFINITE DEATH"; the target glows violet, and each
	    death is a flash, a glitch and a jump; whoever's caught sees the
	    world go violet: "YOU WILL NEVER ARRIVE AT THE TRUTH"
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local TuskStandModels = require(Shared.TuskStandModels)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local Common = require(script.Parent.Parent.TuskActCommon)
local Fighters = require(script.Parent.Parent.Fighters)
local TuskStand = require(script.Parent.Parent.TuskStand)
local Cutscenes = require(script.Parent.Parent.Cutscenes)
local Cinematic = require(script.Parent.Parent.Cinematic)
local GERStand = require(script.Parent.GERStand)
local GiornoVFX = require(script.Parent.GiornoVFX)

local GERVFX = {}
local ACT = 31
local BASE_ACT = 30
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer
local P = GiornoVFX.Pieces

TuskStandModels.register(ACT, GERStand.build, { Aura = GERStand.Aura, AuraLight = GERStand.AuraLight, Offset = GERStand.Offset })

local GOLD = Color3.fromRGB(255, 222, 110)
local GOLD_LIGHT = Color3.fromRGB(255, 246, 200)
local VIOLET = Color3.fromRGB(160, 90, 240)
local VIOLET_DEEP = Color3.fromRGB(70, 30, 140)
local COSMIC = Color3.fromRGB(110, 70, 210)
local CYAN = Color3.fromRGB(110, 240, 230)
local WHITE = Color3.new(1, 1, 1)
local ARROW = Color3.fromRGB(226, 186, 90)
local BEETLE = Color3.fromRGB(250, 200, 220)

local stanced = {}
local rushes = {} -- [character] = token
local clocks = {} -- [character] = token
local deaths = {} -- [target] = token
local lastCutscene -- os.clock() of the last transformation cutscene (nil: never)

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function standOf(character)
	local stand = TuskStand.get(character)
	return stand and stand.Model and stand.Model.Parent and stand.Model or nil
end

-- Where the Stand is (its body), or where it would float.
local function standAt(character)
	local model = standOf(character)
	if model then
		local ok, cf = pcall(function()
			return model:GetPivot()
		end)
		if ok and cf then
			return cf
		end
	end
	local root = Common.rootOf(character)
	return root and root.CFrame * GERStand.Offset or CFrame.new()
end

local function standHead(character)
	local model = standOf(character)
	local head = model and model:FindFirstChild("Head", true)
	if head then
		return head.CFrame
	end
	return standAt(character) * CFrame.new(0, 2.2, 0)
end

-- A jagged bolt of white lightning from a to b (gone in a blink).
local function bolt(a, b, color, width)
	local points = { a }
	local n = 6
	for k = 1, n - 1 do
		local f = k / n
		points[k + 1] = a:Lerp(b, f) + Vector3.new((math.random() - 0.5) * 1.6, (math.random() - 0.5) * 1.6, (math.random() - 0.5) * 1.6)
	end
	points[n + 1] = b
	for k = 1, n do
		local p0, p1 = points[k], points[k + 1]
		local seg = VFXLib.part({ Size = Vector3.new(width or 0.12, width or 0.12, (p1 - p0).Magnitude + 0.1), CFrame = CFrame.lookAt((p0 + p1) / 2, p1), Color = color or WHITE, Material = Enum.Material.Neon })
		VFXLib.animate(0.12, function(t)
			seg.Transparency = t
		end, function()
			seg:Destroy()
		end)
	end
end

-- Violet star sparkles drifting up round a point.
local function stars(at, count, spread, color)
	for _ = 1, count do
		local from = at + Vector3.new((math.random() - 0.5) * spread, (math.random() - 0.5) * spread, (math.random() - 0.5) * spread)
		local sp = VFXLib.part({ Size = Vector3.new(0.22, 0.22, 0.22), Color = color or (math.random() < 0.5 and VIOLET or GOLD_LIGHT), Material = Enum.Material.Neon, CFrame = CFrame.new(from) * CFrame.Angles(0, 0, math.pi / 4) })
		local life = 0.6 + math.random() * 0.4
		VFXLib.animate(life, function(t)
			sp.CFrame = CFrame.new(from + Vector3.new(0, t * 1.5, 0)) * CFrame.Angles(0, t * 4, math.pi / 4)
			sp.Transparency = math.abs(t - 0.4) * 1.6
		end, function()
			sp:Destroy()
		end)
	end
end

-- A golden clock face lying round someone, turning (backwards when `back`).
local function clockFace(root, time, back, token, owner)
	local parts = {}
	local radius = 4.5
	for k = 0, 11 do
		local mark = VFXLib.part({ Size = Vector3.new(0.25, 0.08, k % 3 == 0 and 1.0 or 0.5), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.2 })
		table.insert(parts, { Part = mark, A = k / 12 * math.pi * 2, R = radius })
	end
	local ring = VFXLib.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, radius * 2.2, radius * 2.2), Color = VIOLET, Transparency = 0.75, Material = Enum.Material.Neon })
	ring.Shape = Enum.PartType.Cylinder
	local hand = VFXLib.part({ Size = Vector3.new(0.2, 0.08, radius * 0.9), Color = GOLD_LIGHT, Material = Enum.Material.Neon })
	VFXLib.animate(time, function(a)
		if (owner and clocks[owner] ~= token) or not root.Parent then
			for _, e in ipairs(parts) do
				e.Part.Transparency = 1
			end
			ring.Transparency = 1
			hand.Transparency = 1
			return
		end
		local spin = (back and -1 or 1) * a * time * (back and 9 or 1.2)
		local base = CFrame.new(root.Position - Vector3.new(0, 2.8, 0))
		for _, e in ipairs(parts) do
			e.Part.CFrame = base * CFrame.Angles(0, e.A + spin * 0.15, 0) * CFrame.new(0, 0, -e.R)
			e.Part.Transparency = 0.2 + 0.8 * math.max(0, a * 2 - 1.4)
		end
		ring.CFrame = base * CFrame.Angles(0, 0, math.pi / 2)
		hand.CFrame = base * CFrame.Angles(0, spin, 0) * CFrame.new(0, 0.05, -radius * 0.45)
	end, function()
		for _, e in ipairs(parts) do
			e.Part:Destroy()
		end
		ring:Destroy()
		hand:Destroy()
	end)
end

-- Afterimages along a line (someone wound back, or appearing suddenly).
local function afterimages(from, to, count, color)
	for k = 0, count - 1 do
		local f = k / math.max(1, count - 1)
		local p = from:Lerp(to, f)
		local g = VFXLib.part({ Size = Vector3.new(2, 4.6, 1), CFrame = CFrame.lookAt(p, p + (to - from) * Vector3.new(1, 0, 1) + Vector3.new(0, 0, 0.001)), Color = color or VIOLET, Transparency = 0.5 })
		task.delay(k * 0.02, function()
			VFXLib.animate(0.45, function(t)
				g.Transparency = 0.5 + 0.5 * t
			end, function()
				g:Destroy()
			end)
		end)
	end
end

-- Big words across the screen (the cutscene's line, or the death loop's).
local function screenLine(richText, time, size)
	local pg = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpinRequiemLine"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	gui.ResetOnSpawn = false
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 1)
	t.Position = UDim2.fromScale(0.5, 0.86)
	t.Size = UDim2.fromScale(0.86, size or 0.14)
	t.Font = Enum.Font.GothamBlack
	t.RichText = true
	t.TextScaled = true
	t.TextWrapped = true
	t.Text = richText
	t.TextColor3 = WHITE
	t.TextStrokeColor3 = Color3.fromRGB(30, 10, 60)
	t.TextStrokeTransparency = 0.2
	t.TextTransparency = 1
	t.Parent = gui
	gui.Parent = pg
	VFXLib.animate(time, function(a)
		local fade = a < 0.12 and 1 - a / 0.12 or (a > 0.85 and (a - 0.85) / 0.15 or 0)
		t.TextTransparency = fade
		t.TextStrokeTransparency = 0.2 + 0.8 * fade
		t.Position = UDim2.fromScale(0.5, 0.86 - a * 0.01)
	end, function()
		gui:Destroy()
	end)
	return gui
end
GERVFX.screenLine = screenLine

-- The pillar of gold and violet light (the arrow's change), at `at`.
local function pillar(getAt, time)
	local beam = VFXLib.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(60, 4, 4), Color = GOLD_LIGHT, Material = Enum.Material.Neon, Transparency = 1 })
	beam.Shape = Enum.PartType.Cylinder
	local outer = VFXLib.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(60, 8, 8), Color = VIOLET, Material = Enum.Material.Neon, Transparency = 1 })
	outer.Shape = Enum.PartType.Cylinder
	local nextBolt = 0
	VFXLib.animate(time, function(a)
		local at = getAt()
		local swell = a < 0.2 and a / 0.2 or (a > 0.8 and (1 - a) / 0.2 or 1)
		local wob = 1 + math.sin(os.clock() * 30) * 0.08
		beam.Size = Vector3.new(60, 4 * swell * wob, 4 * swell * wob)
		outer.Size = Vector3.new(60, 8 * swell, 8 * swell)
		beam.CFrame = CFrame.new(at + Vector3.new(0, 26, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		outer.CFrame = beam.CFrame * CFrame.Angles(os.clock() * 3, 0, 0)
		beam.Transparency = 1 - swell * 0.85
		outer.Transparency = 1 - swell * 0.45
		local now = os.clock()
		if now >= nextBolt then
			nextBolt = now + 0.07
			local a0 = math.random() * math.pi * 2
			bolt(at + Vector3.new(math.cos(a0) * 2, math.random() * 6 - 2, math.sin(a0) * 2), at + Vector3.new(math.cos(a0 + 1) * 6, math.random() * 8 - 2, math.sin(a0 + 1) * 6), math.random() < 0.6 and WHITE or VIOLET, 0.14)
			stars(at, 2, 6)
		end
	end, function()
		beam:Destroy()
		outer:Destroy()
	end)
end

-- The Requiem Arrow flying from `from` into `getTo()` over `time`.
local function flyingArrow(from, getTo, time, onHit)
	local head = VFXLib.part({ Size = Vector3.new(0.9, 0.9, 0.2), Color = ARROW, Material = Enum.Material.Metal })
	local shaft = VFXLib.part({ Size = Vector3.new(0.18, 0.18, 2.6), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood })
	local eye = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.35, 0.35, 0.35), Color = BEETLE, Material = Enum.Material.Neon })
	eye.Shape = Enum.PartType.Ball
	local trail = VFXLib.part({ Size = Vector3.new(0.3, 0.3, 6), Color = VIOLET, Material = Enum.Material.Neon, Transparency = 0.4 })
	VFXLib.animate(time, function(a)
		local to = getTo()
		local p = from:Lerp(to, a * a)
		local dir = (to - from).Unit
		local cf = CFrame.lookAt(p, p + dir)
		head.CFrame = cf * CFrame.Angles(0, 0, math.pi / 4)
		shaft.CFrame = cf * CFrame.new(0, 0, 1.4)
		eye.CFrame = cf * CFrame.new(0, 0, 0.1)
		trail.CFrame = cf * CFrame.new(0, 0, 4)
	end, function()
		head:Destroy()
		shaft:Destroy()
		eye:Destroy()
		trail:Destroy()
		if onHit then
			onHit()
		end
	end)
end

-- A cosmic violet sky set up behind a spot, facing a camera spot (shot 4).
local function cosmicBackdrop(getBack, getFace, time)
	local parts = {}
	local sky = VFXLib.part({ Size = Vector3.new(70, 44, 0.2), Color = COSMIC, Material = Enum.Material.Neon, Transparency = 0.1 })
	table.insert(parts, { Part = sky, Off = CFrame.new() })
	for k = 1, 5 do
		local nebula = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1) * (10 + k * 3), Color = k % 2 == 0 and Color3.fromRGB(90, 140, 255) or Color3.fromRGB(200, 120, 240), Material = Enum.Material.Neon, Transparency = 0.6 })
		nebula.Shape = Enum.PartType.Ball
		table.insert(parts, { Part = nebula, Off = CFrame.new((math.random() - 0.5) * 50, (math.random() - 0.5) * 30, 2) })
	end
	for k = 1, 40 do
		local st = VFXLib.part({ Size = Vector3.new(0.3, 0.3, 0.3), Color = k % 4 == 0 and CYAN or WHITE, Material = Enum.Material.Neon, Transparency = 0.1 })
		table.insert(parts, { Part = st, Off = CFrame.new((math.random() - 0.5) * 64, (math.random() - 0.5) * 40, -0.4) * CFrame.Angles(0, 0, math.pi / 4), Twinkle = math.random() * 6 })
	end
	VFXLib.animate(time, function(a)
		local back, face = getBack(), getFace()
		local base = CFrame.lookAt(back, face)
		local fade = a < 0.1 and 1 - a / 0.1 or (a > 0.9 and (a - 0.9) / 0.1 or 0)
		for _, e in ipairs(parts) do
			e.Part.CFrame = base * e.Off * CFrame.Angles(0, 0, a * 0.2)
			if e.Twinkle then
				e.Part.Transparency = math.max(fade, 0.1 + 0.5 * (0.5 + 0.5 * math.sin(os.clock() * 5 + e.Twinkle)))
			elseif e.Part == sky then
				e.Part.Transparency = math.max(fade, 0.1)
			else
				e.Part.Transparency = math.max(fade, 0.6)
			end
		end
	end, function()
		for _, e in ipairs(parts) do
			e.Part:Destroy()
		end
	end)
end

---------------------------------------------------------------------------
-- THE TRANSFORMATION (cutscene)
---------------------------------------------------------------------------
local function playRequiemCutscene(character)
	local cc = TuskConfig.Cutscenes or {}
	if cc.Enabled == false or cc.GER == false or (lastCutscene and os.clock() - lastCutscene < 20) then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if not root or not head then
		return false
	end
	lastCutscene = os.clock()
	TuskAnimation.play(character, "GIRequiem")
	local ended = false
	local up = Vector3.new(0, 1, 0)
	local function rel(x, y, z)
		return (root.CFrame * CFrame.new(x, y, z)).Position
	end
	local function headAt()
		return head.Parent and head.Position or root.Position + Vector3.new(0, 1.5, 0)
	end
	local function chest()
		return (standAt(character) * CFrame.new(0, 0.3, -0.5)).Position
	end
	local function sHead()
		return standHead(character).Position
	end
	local T = { 1.1, 0.9, 1.6, 2.2, 1.9 }
	local shots = {
		-- 1. Wide from in front: Giorno and Gold Experience; something falls from the sky.
		{ From = function()
			return root.Parent and CFrame.lookAt(rel(-4, 1.5, -13), rel(1, 2.5, 1)) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(rel(-3, 1.2, -11), rel(1.5, 3, 1.5)) or nil
		end, Time = T[1], FOV = { 55, 50 }, Title = "THE REQUIEM ARROW", Subtitle = "GIORNO GIOVANNA", Color = Color3.fromRGB(214, 180, 255) },
		-- 2. Close on Gold Experience's chest: the arrow goes in.
		{ From = function()
			local c = chest()
			return root.Parent and CFrame.lookAt(c + root.CFrame.LookVector * 5 + up * 0.6, c) or nil
		end, To = function()
			local c = chest()
			return root.Parent and CFrame.lookAt(c + root.CFrame.LookVector * 3.4 + up * 0.3, c) or nil
		end, Time = T[2], FOV = { 40, 34 } },
		-- 3. Pull back: the pillar of light swallows it.
		{ From = function()
			local c = chest()
			return root.Parent and CFrame.lookAt(c + root.CFrame.LookVector * 7 - root.CFrame.RightVector * 3 + up * 1, c + up * 2) or nil
		end, To = function()
			local c = chest()
			return root.Parent and CFrame.lookAt(c + root.CFrame.LookVector * 14 - root.CFrame.RightVector * 6 + up * 4, c + up * 4) or nil
		end, Time = T[3], FOV = { 50, 62 } },
		-- 4. In profile: Giorno's face, Requiem's head beside it, the cosmos behind.
		{ From = function()
			local h, sh = headAt(), sHead()
			local mid = h:Lerp(sh, 0.45)
			local side = -root.CFrame.RightVector
			return root.Parent and CFrame.lookAt(mid + side * 4.2 + root.CFrame.LookVector * 1.6 + up * 0.2, mid) or nil
		end, To = function()
			local h, sh = headAt(), sHead()
			local mid = h:Lerp(sh, 0.45)
			local side = -root.CFrame.RightVector
			return root.Parent and CFrame.lookAt(mid + side * 3.5 + root.CFrame.LookVector * 1.3 + up * 0.1, mid) or nil
		end, Time = T[4], FOV = { 42, 38 }, Linear = true },
		-- 5. Low and wide: Requiem towers over him.
		{ From = function()
			return root.Parent and CFrame.lookAt(rel(1, -2, -9), rel(1.5, 4, 1)) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(rel(2, -2.4, -11), rel(1.5, 5, 1)) or nil
		end, Time = T[5], FOV = { 58, 64 }, Title = "GOLD EXPERIENCE REQUIEM", Subtitle = "UNTIL YOU GO DOWN", Color = Color3.fromRGB(255, 226, 120) },
	}
	local starts, acc = {}, 0
	for i, d in ipairs(T) do
		starts[i] = acc
		acc = acc + d
	end
	local started = Cutscenes.play(shots, { Priority = 3, Skippable = true, OnEnd = function()
		ended = true
	end })
	if not started then
		return false
	end
	local function at(time, fn)
		task.delay(time, function()
			if not ended then
				fn()
			end
		end)
	end
	VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 0.7)
	TuskVFX.ScreenTint(acc, { Tint = Color3.fromRGB(230, 214, 255), Brightness = 0, Saturation = -0.1, Contrast = 0.15, Release = 0.3, FadeOut = 0.6 })
	-- 1-2. The arrow streaks down out of the sky into Gold Experience.
	at(0.25, function()
		local from = rel(-10, 40, -26)
		flyingArrow(from, chest, starts[2] + 0.45 - 0.25, function()
			if ended then
				return
			end
			local c = chest()
			P.label(VFXLib.part({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(c), Transparency = 1 }), "ズキュゥゥン", VIOLET, 1.2, 320, Vector3.new(-1.5, 1.5, 0))
			TuskVFX.CreateImpactStar(c, { Size = 6, Rays = 12, Color = VIOLET, Color2 = WHITE, Duration = 0.3 })
			CameraFX.impactFrame(Color3.fromRGB(220, 200, 255))
			CameraFX.shake(0.8, 0.4)
			VFXLib.sound(sounds.AwakeningBurst or sounds.Swing, root, 0.8, 1.0)
		end)
	end)
	-- 3. The pillar of light (the Stand changes inside it).
	at(starts[3] - 0.15, function()
		pillar(function()
			return standAt(character).Position
		end, T[3] + 0.4)
		VFXLib.flash(standAt(character).Position, GOLD_LIGHT, 10, 30, 0.4)
	end)
	-- 4. Profile, the cosmos, and the line.
	at(starts[4], function()
		local side = function()
			return -root.CFrame.RightVector
		end
		cosmicBackdrop(function()
			return headAt() - side() * 9
		end, function()
			return headAt() + side() * 4
		end, T[4])
		screenLine('WHAT YOU ARE <font color="#6EF0E6">SEEING</font> IS <font color="#6EF0E6">CERTAINLY</font> THE <font color="#6EF0E6">TRUTH.</font>', T[4] + 0.3)
		VFXLib.animate(T[4], function()
			if math.random() < 0.25 then
				local h = headAt()
				bolt(h + side() * -2 + Vector3.new(0, 3, (math.random() - 0.5) * 4), h + side() * -2 + Vector3.new((math.random() - 0.5) * 3, -2, (math.random() - 0.5) * 4), WHITE, 0.1)
			end
		end)
	end)
	-- 5. Requiem towers over him in a burst of gold.
	at(starts[5], function()
		local s = standAt(character).Position
		TuskVFX.CreateRotationalShockwave(CFrame.new(root.Position - Vector3.new(0, 2.8, 0)), { Radius = 18, Layers = 3, Color = GOLD, Color2 = VIOLET, Ground = true, Particles = 2, Width = 0.6 })
		stars(s, 30, 8)
		CameraFX.shake(0.6, 0.5)
	end)
	return true
end
GERVFX.playRequiemCutscene = playRequiemCutscene

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
	TuskAnimation.play(character, "GI_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.6 or 0.6, 0.9, -3.6), Duration = 0.28 })
	VFXLib.sound(sounds.Swing, root, 0.5, 1.0 + index * 0.05)
	P.fist((root.CFrame * CFrame.new(index % 2 == 0 and -0.6 or 0.6, 0.8, -1.8)).Position, root.CFrame.LookVector, index == 4 and 1.8 or 1.2, GOLD, VIOLET)
	if index == 4 then
		P.muda((root.CFrame * CFrame.new(0, 2, -3)).Position, true, VIOLET)
	end
end

local function rush(character, duration)
	local token = {}
	rushes[character] = token
	TuskAnimation.play(character, "GIRushLong")
	TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 0.9, -4), Duration = duration })
	local start = os.clock()
	local nextFist, nextMuda = 0, 0
	VFXLib.animate(duration, function()
		local root = Common.rootOf(character)
		if rushes[character] ~= token or not root then
			return
		end
		local t = os.clock() - start
		if t >= nextFist then
			nextFist = t + 0.02
			local off = CFrame.new((math.random() - 0.5) * 3, 0.4 + (math.random() - 0.5) * 2.6, -2.6)
			P.fist((root.CFrame * off).Position, root.CFrame.LookVector, 1.0 + math.random() * 0.4, GOLD, math.random() < 0.5 and VIOLET or GOLD)
		end
		if t >= nextMuda then
			nextMuda = t + 0.14
			P.muda((root.CFrame * CFrame.new((math.random() - 0.5) * 4, 2 + math.random(), -3)).Position, false, math.random() < 0.5 and VIOLET or GOLD_LIGHT)
		end
	end, function()
		if rushes[character] == token then
			rushes[character] = nil
		end
	end)
	if Common.isLocal(character) then
		CameraFX.speedLines(duration, VIOLET)
	end
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "Rush" then
		if phase == "Start" and character and root then
			rush(character, (data.Windup or 0.12) + (data.Duration or 1.6))
		elseif phase == "Hit" and data.Position then
			TuskVFX.CreateImpactStar(data.Position, { Size = 2.4, Rays = 6, Color = GOLD, Color2 = VIOLET, Duration = 0.08 })
		elseif phase == "Finish" and data.Position then
			if character then
				rushes[character] = nil
				TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 0.9, -4.6), Duration = 0.4 })
			end
			local anchor = VFXLib.part({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(data.Position + Vector3.new(0, 2.5, 0)), Transparency = 1 })
			P.label(anchor, "MUDAAA!", VIOLET, 1.2, 340)
			task.delay(1.3, function()
				anchor:Destroy()
			end)
			local dir = data.Direction or Vector3.new(0, 0, -1)
			P.fist(data.Position - dir * 1.5, dir, 2.6, GOLD, VIOLET)
			TuskVFX.CreateRotationalShockwave(CFrame.lookAt(data.Position, data.Position + dir) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = data.Radius or 9, Layers = 3, Color = VIOLET, Color2 = GOLD, Particles = 1, Width = 0.5 })
			stars(data.Position, 16, 4)
			CameraFX.shakeAt(data.Position, 0.9, 50)
			if character and Common.isLocal(character) then
				CameraFX.impactFrame(pal.Light)
			end
		elseif phase == "Stop" and character then
			rushes[character] = nil
		end
	elseif move == "Zero" then
		if phase == "Ready" and character and root then
			TuskAnimation.play(character, "GIZero")
			TuskStand.action(character, "Loom", { Target = CFrame.new(0, 2.2, 1.8), Duration = data.Window or 1.3 })
			local token = {}
			clocks[character] = token
			clockFace(root, data.Window or 1.3, false, token, character)
			P.label(character:FindFirstChild("Head"), "GOLD EXPERIENCE REQUIEM", GOLD, 1.0, 280)
		elseif phase == "Return" then
			if character then
				clocks[character] = nil
			end
			if data.From and data.To then
				afterimages(data.From, data.To, 7, VIOLET)
			end
			local target = typeof(data.Target) == "Instance" and data.Target or nil
			local tr = target and target:FindFirstChild("HumanoidRootPart")
			if tr then
				clockFace(tr, 0.8, true)
				P.label(target:FindFirstChild("Head"), "RETURN TO ZERO", GOLD_LIGHT, 1.4, 280, Vector3.new(0, 3.6, 0))
				TuskVFX.CreateImpactStar(tr.Position, { Size = 4, Rays = 10, Color = GOLD, Color2 = VIOLET, Duration = 0.2 })
				if Players:GetPlayerFromCharacter(target) == localPlayer then
					TuskVFX.ScreenTint(0.8, { Tint = Color3.fromRGB(200, 170, 255), Brightness = 0.1, Saturation = -0.5, Contrast = 0.2, Release = 0.1, FadeOut = 0.4 })
					screenLine("WHAT YOU TRIED TO DO <font color=\"#6EF0E6\">NEVER HAPPENED</font>", 1.6, 0.09)
				end
			end
			if character and Common.isLocal(character) then
				CameraFX.impactFrame(pal.Light)
			end
		elseif phase == "Whiff" and character then
			clocks[character] = nil
		end
	elseif move == "ZeroPunch" then
		if phase == "Appear" and character and root then
			TuskAnimation.play(character, "GIPunch")
			if data.From and data.To and (data.From - data.To).Magnitude > 1 then
				afterimages(data.From, data.To, 5, GOLD)
			end
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0.4, 0.9, -3.6), Duration = (data.Windup or 0.12) + 0.3 })
		elseif phase == "Punch" and data.Position then
			local dir = data.Direction or Vector3.new(0, 0, -1)
			P.fist(data.Position - dir * 2, dir, 2.2, GOLD, VIOLET)
			TuskVFX.CreateImpactStar(data.Position, { Size = data.Hit and 4 or 2, Rays = 8, Color = GOLD, Color2 = VIOLET, Duration = 0.15 })
			for _, target in ipairs(data.Targets or {}) do
				if typeof(target) == "Instance" then
					P.label(target:FindFirstChild("Head"), "ZERO", VIOLET, 1.2, 160, Vector3.new(0, 3.4, 0))
				end
			end
			if data.Hit then
				CameraFX.shakeAt(data.Position, 0.6, 40)
			end
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character and root then
		TuskAnimation.play(character, "GIDeath")
		TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 1, -5), Duration = (data.Windup or 0.6) + 0.5 })
		P.label(character:FindFirstChild("Head"), "INFINITE DEATH", VIOLET, 1.8, 320)
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.4)
		if Common.isLocal(character) then
			Cinematic.title("GOLD EXPERIENCE REQUIEM", "INFINITE DEATH", VIOLET, "WHAT YOU ARE SEEING IS CERTAINLY THE TRUTH", 1.6)
		end
	elseif data.Phase == "Loop" and typeof(data.Target) == "Instance" then
		local target = data.Target
		local token = {}
		deaths[target] = token
		local hl = Instance.new("Highlight")
		hl.FillColor = VIOLET
		hl.OutlineColor = GOLD_LIGHT
		hl.FillTransparency = 0.55
		hl.Adornee = target
		hl.Parent = VFXLib.Folder
		local tr = target:FindFirstChild("HumanoidRootPart")
		VFXLib.animate(data.Time or 4.6, function()
			if deaths[target] ~= token then
				hl.FillTransparency = 1
				hl.OutlineTransparency = 1
				return
			end
			hl.FillTransparency = 0.45 + math.sin(os.clock() * 16) * 0.15
			if tr and tr.Parent and math.random() < 0.2 then
				stars(tr.Position, 1, 4)
			end
		end, function()
			hl:Destroy()
			if deaths[target] == token then
				deaths[target] = nil
			end
		end)
		if Players:GetPlayerFromCharacter(target) == localPlayer then
			TuskVFX.ScreenTint(data.Time or 4.6, { Tint = Color3.fromRGB(170, 120, 255), Brightness = -0.1, Saturation = -0.5, Contrast = 0.3, Release = 0.2, FadeOut = 0.5 })
			screenLine("YOU WILL <font color=\"#6EF0E6\">NEVER</font> ARRIVE AT THE <font color=\"#6EF0E6\">TRUTH</font>", (data.Time or 4.6), 0.11)
		end
	elseif data.Phase == "Death" and typeof(data.Target) == "Instance" then
		local target = data.Target
		if data.From then
			VFXLib.flash(data.From, VIOLET, 5, 16, 0.2)
		end
		if data.To then
			VFXLib.flash(data.To, GOLD_LIGHT, 5, 16, 0.2)
			TuskVFX.CreateImpactStar(data.To, { Size = 3.5, Rays = 10, Color = VIOLET, Color2 = WHITE, Duration = 0.12 })
			if data.From then
				bolt(data.From, data.To, VIOLET, 0.16)
			end
		end
		if Players:GetPlayerFromCharacter(target) == localPlayer then
			CameraFX.impactFrame(Color3.fromRGB(220, 200, 255))
			CameraFX.shake(0.6, 0.25)
		end
	elseif data.Phase == "Final" and typeof(data.Target) == "Instance" then
		deaths[data.Target] = nil
		local tr = data.Target:FindFirstChild("HumanoidRootPart")
		if tr then
			TuskVFX.CreateImpactStar(tr.Position, { Size = 6, Rays = 12, Color = GOLD, Color2 = VIOLET, Duration = 0.25 })
			TuskVFX.CreateRotationalShockwave(CFrame.new(tr.Position - Vector3.new(0, 2.5, 0)), { Radius = 10, Layers = 3, Color = VIOLET, Color2 = GOLD, Ground = true, Particles = 1, Width = 0.5 })
			CameraFX.shakeAt(tr.Position, 1, 60)
		end
		if character and Common.isLocal(character) then
			CameraFX.impactFrame(pal.Light)
		end
	end
end

---------------------------------------------------------------------------
-- The arrow (WorldFX "RequiemArrow"), and your own act changing 30 -> 31
---------------------------------------------------------------------------
local function onArrow(data)
	if data.Phase ~= "Requiem" or data.Who ~= "Giorno" or typeof(data.Character) ~= "Instance" then
		return
	end
	local character = data.Character
	if data.Player == (localPlayer and localPlayer.UserId) then
		if playRequiemCutscene(character) then
			return
		end
	end
	-- Everyone else (or with the cutscene off): the pillar of light.
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		task.delay(0.9, function()
			if character.Parent then
				pillar(function()
					return standAt(character).Position
				end, 1.8)
			end
		end)
	end
end
GERVFX.onArrow = onArrow

local watchedAct -- your own act last check (to catch 30 -> 31 without the arrow event)
local function watchMine()
	local c = localPlayer and localPlayer.Character
	local act = c and c:GetAttribute("TuskAct")
	if act == ACT and watchedAct == BASE_ACT and not (lastCutscene and os.clock() - lastCutscene < 20) then
		playRequiemCutscene(c)
	end
	watchedAct = act
end

pcall(function()
	Net.get("WorldFX").OnClientEvent:Connect(function(name, data)
		if name == "RequiemArrow" and typeof(data) == "table" then
			onArrow(data)
		end
	end)
end)

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local function stepStance()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character then
			local act = character:GetAttribute("TuskAct")
			local want = act == ACT
			if want and not stanced[character] then
				stanced[character] = true
				TuskAnimation.hold(character, "GiornoStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				if act ~= BASE_ACT then
					TuskAnimation.stopHold(character, "GiornoStance")
				end
			end
			-- Violet star sparkles round him (and round Requiem).
			if want and math.random() < 0.5 then
				local r = Common.rootOf(character)
				if r then
					stars(r.Position + Vector3.new(0, 0.5, 0), 1, 3.5)
					stars(standAt(character).Position, 1, 3)
				end
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
	for target in pairs(deaths) do
		if not target.Parent then
			deaths[target] = nil
		end
	end
end

function GERVFX.handle(name, data)
	if name == "M1" then
		onM1(data)
	elseif name == "M1Finisher" then
		Common.finisher(data, pal)
		if data.Position then
			stars(data.Position, 10, 3)
		end
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

local slowTimer = 0
function GERVFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.15 then
		slowTimer = 0
		stepStance()
		watchMine()
	end
end

return GERVFX
