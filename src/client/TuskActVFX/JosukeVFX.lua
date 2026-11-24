--[[
	TuskActVFX.JosukeVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.JosukeVFX)

	Client visuals for Josuke Higashikata (JoJolion) / SOFT & WET. Blocky.
	  * Soft & Wet (SoftAndWetStand) floats behind him with a soft blue
	    aura and throws his punches; he stands relaxed, hands behind his head
	  * PLUNDER BUBBLES (server Kind "PlunderBubble"): see-through soap
	    bubbles with a shine, wobbling as they fly. FRICTION ones are pale
	    blue, SIGHT ones violet; they pop with a splash of droplets
	  * FRICTION STOLEN: the victim slides about like on ice (yours on your
	    own screen: you can barely steer), with a frosty sheen under them
	  * SIGHT STOLEN: a blinded player's screen goes nearly black
	  * BUBBLE MINES: a ring of bubbles drifts out round him and bobs there
	  * GO BEYOND (like the manga panel): he points straight at them,
	    Soft & Wet rises up behind him with its hand raised, and an orange
	    "GO BEYOND" speech bubble with green lettering and a star pops out
	    beside him. Anyone close gets a pink-purple manga tint and speed
	    lines. A tiny white bubble spins up on his fingertip, rings whirling
	    round it, and flies; a shockwave and flash when it lands
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

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
local SoftAndWetStand = require(script.Parent.SoftAndWetStand)

local JosukeVFX = {}
local ACT = 15
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, SoftAndWetStand.build, { Aura = SoftAndWetStand.Aura, AuraLight = SoftAndWetStand.AuraLight, Offset = SoftAndWetStand.Offset })

local STYLE = {
	Friction = { Color = Color3.fromRGB(150, 215, 255), Size = 2.4 },
	Sight = { Color = Color3.fromRGB(190, 150, 255), Size = 2.4 },
	GoBeyond = { Color = Color3.fromRGB(255, 255, 255), Size = 1.2 },
	Bubble = { Color = Color3.fromRGB(180, 230, 255), Size = 2.2 },
}
local SHINE = Color3.fromRGB(255, 255, 255)
local ICE = Color3.fromRGB(200, 235, 255)

local bubbles = {} -- [projectile id] = flying bubble
local mineSets = {} -- [id] = { Items, Born, Life }
local stanced = {}
local slide -- the local player's ice slide
local blind -- the local player's blind screen

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
-- A soap bubble: a see-through ball, a glint, a thin rim.
local function newBubble(style, scale)
	local st = STYLE[style] or STYLE.Bubble
	local size = st.Size * (scale or 1)
	local ballPart = VFXLib.part({ Size = Vector3.new(size, size, size), Shape = Enum.PartType.Ball, Color = st.Color, Material = Enum.Material.Glass, Transparency = 0.55, Reflectance = 0.25 })
	local rim = VFXLib.part({ Size = Vector3.new(size * 1.04, size * 1.04, size * 1.04), Shape = Enum.PartType.Ball, Color = st.Color, Material = Enum.Material.ForceField, Transparency = 0.2 })
	local glint = VFXLib.part({ Size = Vector3.new(size * 0.22, size * 0.22, size * 0.22), Shape = Enum.PartType.Ball, Color = SHINE, Material = Enum.Material.Neon, Transparency = 0.1 })
	local b = { Ball = ballPart, Rim = rim, Glint = glint, Size = size, Style = style, Seed = math.random() * 10 }
	if style == "GoBeyond" then
		b.Rings = {}
		for i = 1, 3 do
			b.Rings[i] = VFXLib.part({ Size = Vector3.new(0.08, size * 2.2, size * 2.2), Shape = Enum.PartType.Cylinder, Color = i == 2 and Color3.fromRGB(150, 215, 255) or SHINE, Material = Enum.Material.Neon, Transparency = 0.35 })
		end
	end
	return b
end

local function placeBubble(b, pos, t)
	local wob = 1 + math.sin(t * 9 + b.Seed) * 0.06
	local s = b.Size
	b.Ball.Size = Vector3.new(s * wob, s / wob, s * wob)
	b.Ball.CFrame = CFrame.new(pos)
	b.Rim.CFrame = CFrame.new(pos)
	b.Glint.CFrame = CFrame.new(pos + Vector3.new(-s * 0.22, s * 0.25, -s * 0.2))
	if b.Rings then
		for i, ring in ipairs(b.Rings) do
			local spin = t * (14 + i * 5)
			ring.CFrame = CFrame.new(pos) * CFrame.Angles(spin * (i == 1 and 1 or 0.3), spin * (i == 2 and 1 or 0.5), spin * (i == 3 and 1 or 0.2))
		end
	end
end

local function destroyBubble(b)
	b.Ball:Destroy()
	b.Rim:Destroy()
	b.Glint:Destroy()
	for _, ring in ipairs(b.Rings or {}) do
		ring:Destroy()
	end
end

-- The pop: a quick ring and a splash of droplets.
local function pop(position, color, big)
	local r = big and 10 or 4
	local ringPart = VFXLib.part({ Size = Vector3.new(0.2, 1, 1), Shape = Enum.PartType.Cylinder, Color = color, Material = Enum.Material.Neon, Transparency = 0.3 })
	local cam = workspace.CurrentCamera
	local face = cam and CFrame.lookAt(position, cam.CFrame.Position) * CFrame.Angles(0, math.pi / 2, 0) or CFrame.new(position)
	VFXLib.animate(0.25, function(a)
		local d = r * VFXLib.easeOut(a)
		ringPart.Size = Vector3.new(0.2, d, d)
		ringPart.CFrame = face
		ringPart.Transparency = 0.3 + 0.7 * a
	end, function()
		ringPart:Destroy()
	end)
	VFXLib.burst(position, { Count = big and 30 or 12, Color = color, Speed = big and 34 or 16, Lifetime = 0.45, Acceleration = Vector3.new(0, -30, 0) })
	VFXLib.sound(sounds.Swing, position, 0.4, 1.8)
end

local function label(target, text, color, duration)
	local head = target and target:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 40)
	bb.StudsOffset = Vector3.new(0, 2.8, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.2
	t.Parent = bb
	bb.Parent = VFXLib.Folder
	VFXLib.animate(math.min(duration or 1.4, 2), function(a)
		bb.StudsOffset = Vector3.new(0, 2.8 + a * 0.8, 0)
		t.TextTransparency = math.max(0, a * 1.4 - 0.4)
		t.TextStrokeTransparency = 0.2 + 0.8 * a
	end, function()
		bb:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Flying bubbles (server Kind "PlunderBubble")
---------------------------------------------------------------------------
local function spawnBubble(data)
	local style = data.Visual and data.Visual.Style or "Bubble"
	bubbles[data.Id] = { B = newBubble(style), Origin = data.Origin, Direction = data.Direction, Speed = data.Speed, Range = data.Range, ServerTime = data.ServerTime, Expire = os.clock() + data.Range / math.max(data.Speed, 1) + 0.5 }
end

local function endBubble(data)
	local v = bubbles[data.Id]
	local style = "Bubble"
	if v then
		bubbles[data.Id] = nil
		style = v.B.Style
		destroyBubble(v.B)
	end
	local st = STYLE[style] or STYLE.Bubble
	pop(data.Position, st.Color, style == "GoBeyond")
	if data.HitCharacter then
		TuskVFX.CreateImpactStar(data.Position, { Size = 2.4, Rays = 6, Color = st.Color, Color2 = SHINE, Duration = 0.14 })
	end
end

local function stepBubbles()
	local now = os.clock()
	for id, v in pairs(bubbles) do
		local t = VFXLib.flight(id, v.ServerTime)
		local distance = math.clamp(v.Speed * t, 0, v.Range)
		local pos = v.Origin + v.Direction * distance + Vector3.new(0, math.sin(t * 6 + v.B.Seed) * 0.25, 0)
		placeBubble(v.B, pos, now)
		if now > v.Expire + VFXLib.held(id, v.ServerTime) then
			bubbles[id] = nil
			destroyBubble(v.B)
		end
	end
end

---------------------------------------------------------------------------
-- Bubble mines
---------------------------------------------------------------------------
local function spawnMines(data)
	local set = { Items = {}, Born = os.clock(), Life = data.Life or 8, From = data.From }
	for i, pos in ipairs(data.Positions or {}) do
		set.Items[i] = { B = newBubble("Friction", 1.1), Pos = pos }
	end
	mineSets[data.Id] = set
end

local function popMine(data)
	local set = mineSets[data.Id]
	local m = set and set.Items[data.Index]
	if m then
		destroyBubble(m.B)
		set.Items[data.Index] = nil
	end
	pop(data.Position, STYLE.Friction.Color, false)
end

local function fadeMines(id)
	local set = mineSets[id]
	if not set then
		return
	end
	mineSets[id] = nil
	for _, m in pairs(set.Items) do
		pop(m.Pos, STYLE.Friction.Color, false)
		destroyBubble(m.B)
	end
end

local function stepMines()
	local now = os.clock()
	for id, set in pairs(mineSets) do
		local age = now - set.Born
		local out = VFXLib.easeOut(math.min(age / 0.6, 1))
		for i, m in pairs(set.Items) do
			local pos = (set.From or m.Pos):Lerp(m.Pos, out) + Vector3.new(0, math.sin(now * 2 + i) * 0.35, 0)
			placeBubble(m.B, pos, now)
		end
		if age > set.Life + 1 then
			fadeMines(id)
		end
	end
end

---------------------------------------------------------------------------
-- Friction stolen: the local player slides like on ice
---------------------------------------------------------------------------
local function stopSlide()
	if slide then
		slide.Mover:Destroy()
		slide.Attach:Destroy()
		slide.Sheen:Destroy()
		slide = nil
	end
end

local function stepSlide(dt)
	local character = localPlayer and localPlayer.Character
	local untilT = character and character:GetAttribute("NoFrictionUntil")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (untilT and untilT > workspace:GetServerTimeNow() and humanoid and root and humanoid.Health > 0) then
		stopSlide()
		return
	end
	if not slide or slide.Root ~= root then
		stopSlide()
		local attach = Instance.new("Attachment")
		attach.Name = "JosukeSlideAttach"
		attach.Parent = root
		-- A LinearVelocity takes over from the walk controller, so he only
		-- steers as fast as the stolen grip allows.
		local mover = Instance.new("LinearVelocity")
		mover.Name = "JosukeSlide"
		mover.Attachment0 = attach
		mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		mover.PrimaryTangentAxis = Vector3.new(1, 0, 0)
		mover.SecondaryTangentAxis = Vector3.new(0, 0, 1)
		mover.RelativeTo = Enum.ActuatorRelativeTo.World
		mover.MaxForce = 1e6
		local v = root.AssemblyLinearVelocity
		mover.PlaneVelocity = Vector2.new(v.X, v.Z)
		mover.Parent = root
		local sheen = VFXLib.part({ Size = Vector3.new(0.1, 6, 6), Shape = Enum.PartType.Cylinder, Color = ICE, Material = Enum.Material.Ice, Transparency = 0.45 })
		slide = { Root = root, Attach = attach, Mover = mover, Sheen = sheen }
	end
	local grip = character:GetAttribute("NoFrictionGrip") or 0.8
	local want = humanoid.MoveDirection * humanoid.WalkSpeed
	local cur = slide.Mover.PlaneVelocity
	local target = Vector2.new(want.X, want.Z)
	slide.Mover.PlaneVelocity = cur:Lerp(target, math.clamp(grip * dt, 0, 1))
	slide.Sheen.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.pi / 2)
end

---------------------------------------------------------------------------
-- Sight stolen: the local player's screen goes dark
---------------------------------------------------------------------------
local function stepBlind()
	local character = localPlayer and localPlayer.Character
	local untilT = character and character:GetAttribute("BlindUntil")
	local left = untilT and (untilT - workspace:GetServerTimeNow()) or 0
	if left <= 0 then
		if blind then
			local b = blind
			blind = nil
			VFXLib.animate(0.4, function(a)
				b.Dark.BackgroundTransparency = 0.04 + 0.96 * a
				b.Note.TextTransparency = a
			end, function()
				b.Gui:Destroy()
			end)
		end
		return
	end
	if not blind then
		local gui = Instance.new("ScreenGui")
		gui.Name = "JosukeBlind"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 40
		local dark = Instance.new("Frame")
		dark.Name = "Dark"
		dark.Size = UDim2.fromScale(1, 1)
		dark.BackgroundColor3 = Color3.fromRGB(4, 6, 14)
		dark.BackgroundTransparency = 1
		dark.BorderSizePixel = 0
		dark.Parent = gui
		local note = Instance.new("TextLabel")
		note.Name = "Note"
		note.BackgroundTransparency = 1
		note.Size = UDim2.fromScale(1, 0.08)
		note.Position = UDim2.fromScale(0, 0.7)
		note.Font = Enum.Font.GothamBlack
		note.TextScaled = true
		note.Text = "YOUR SIGHT WAS STOLEN"
		note.TextColor3 = STYLE.Sight.Color
		note.TextTransparency = 0.2
		note.Parent = dark
		gui.Parent = localPlayer:FindFirstChildOfClass("PlayerGui")
		blind = { Gui = gui, Dark = dark, Note = note }
		VFXLib.animate(0.15, function(a)
			dark.BackgroundTransparency = 1 - 0.96 * a
		end)
	end
	-- Flickers back near the end.
	if left < 0.6 then
		blind.Dark.BackgroundTransparency = 0.04 + (0.6 - left) * 0.8
	end
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
	local index = data.Index or 1
	TuskAnimation.play(character, "J_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1, -3.2), Duration = 0.28 })
	VFXLib.sound(sounds.Swing, root, 0.5, 1.05 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or pal.Second)
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local STOLEN_TEXT = { PlunderFriction = "FRICTION STOLEN!", PlunderSight = "SIGHT STOLEN!" }

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if phase == "Blow" and character and root then
		TuskAnimation.play(character, move == "BubbleMines" and "JMines" or "JBubble")
		TuskStand.action(character, "Lunge", { Target = CFrame.new(0.6, 1.2, -2.4), Duration = (data.Windup or 0.2) + 0.2 })
		VFXLib.burst((root.CFrame * CFrame.new(0.8, 1, -2.5)).Position, { Count = 8, Color = STYLE.Friction.Color, Speed = 6, Lifetime = 0.5 })
	elseif phase == "Stolen" then
		local st = move == "PlunderSight" and STYLE.Sight or STYLE.Friction
		label(data.Target, STOLEN_TEXT[move] or "STOLEN!", st.Color, data.Duration)
		if move == "PlunderFriction" and data.Position then
			VFXLib.burst(data.Position - Vector3.new(0, 2, 0), { Count = 16, Color = ICE, Speed = 10, Lifetime = 0.6 })
		end
		if data.Target and Common.isLocal(data.Target) then
			CameraFX.shake(0.4, 0.25)
		end
	elseif move == "BubbleMines" then
		if phase == "Spawn" then
			spawnMines(data)
		elseif phase == "Pop" then
			popMine(data)
		elseif phase == "Fade" then
			fadeMines(data.Id)
		end
	end
end

---------------------------------------------------------------------------
-- GO BEYOND: the manga panel
---------------------------------------------------------------------------
local BUBBLE_ORANGE = Color3.fromRGB(255, 176, 48)
local TEXT_GREEN = Color3.fromRGB(120, 220, 80)
local TEXT_EDGE = Color3.fromRGB(24, 90, 40)
local PANEL_PINK = Color3.fromRGB(255, 200, 250)

local function uiCorner(parent, scale)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = parent
end

local function uiStroke(parent, color, thickness)
	local st = Instance.new("UIStroke")
	st.Color = color
	st.Thickness = thickness
	st.Parent = parent
	return st
end

-- The orange speech bubble beside his head: "GO BEYOND" in green, a star.
local function speechBubble(character, duration)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "GoBeyondBubble"
	bb.Size = UDim2.new(6, 0, 3.6, 0)
	bb.StudsOffset = Vector3.new(3.6, 1.6, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Adornee = head
	local scaler = Instance.new("UIScale")
	scaler.Scale = 0
	scaler.Parent = bb
	-- The tail, pointing down-left at him.
	local tail = Instance.new("Frame")
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Size = UDim2.fromScale(0.2, 0.3)
	tail.Position = UDim2.fromScale(0.16, 0.82)
	tail.Rotation = 35
	tail.BackgroundColor3 = BUBBLE_ORANGE
	tail.BorderSizePixel = 0
	uiStroke(tail, Color3.fromRGB(90, 50, 10), 2)
	tail.Parent = bb
	local body = Instance.new("Frame")
	body.Size = UDim2.fromScale(1, 0.85)
	body.BackgroundColor3 = BUBBLE_ORANGE
	body.BorderSizePixel = 0
	uiCorner(body, 0.5)
	uiStroke(body, Color3.fromRGB(90, 50, 10), 2)
	body.Parent = bb
	local function words(text, pos, size, rot)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = pos
		t.Size = size
		t.Rotation = rot
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = TEXT_GREEN
		uiStroke(t, TEXT_EDGE, 2)
		t.Parent = body
		return t
	end
	words("GO", UDim2.fromScale(0.62, 0.3), UDim2.fromScale(0.5, 0.42), -6)
	words("BEYOND", UDim2.fromScale(0.45, 0.68), UDim2.fromScale(0.78, 0.4), -10)
	local starLabel = words("★", UDim2.fromScale(0.86, 0.3), UDim2.fromScale(0.18, 0.3), 0)
	starLabel.TextColor3 = Color3.fromRGB(255, 240, 120)
	bb.Parent = VFXLib.Folder
	VFXLib.animate(duration, function(a)
		local t = a * duration
		-- Pops in with a bounce, wobbles, then bursts away at the end.
		local pop = t < 0.25 and math.sin(t / 0.25 * math.pi * 0.75) / math.sin(math.pi * 0.75) * (1 + 0.15 * (1 - t / 0.25)) or 1
		if a > 0.85 then
			pop = 1 + (a - 0.85) / 0.15 * 0.5
			body.BackgroundTransparency = (a - 0.85) / 0.15
			tail.BackgroundTransparency = body.BackgroundTransparency
		end
		scaler.Scale = math.max(0, pop) * (1 + math.sin(t * 9) * 0.03)
		starLabel.Rotation = t * 120
	end, function()
		bb:Destroy()
	end)
end

-- A pink-purple manga tint and speed lines on the screens of anyone close.
local function panelTint(position, duration)
	local myRoot = localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not myRoot or (myRoot.Position - position).Magnitude > 70 then
		return
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "JosukeGoBeyond"
	cc.TintColor = Color3.new(1, 1, 1)
	cc.Parent = Lighting
	VFXLib.animate(duration, function(a)
		local k = a < 0.15 and a / 0.15 or (a > 0.8 and (1 - a) / 0.2 or 1)
		cc.TintColor = Color3.new(1, 1, 1):Lerp(PANEL_PINK, k)
		cc.Saturation = 0.25 * k
		cc.Contrast = 0.12 * k
	end, function()
		cc:Destroy()
	end)
	CameraFX.speedLines(duration * 0.6, Color3.fromRGB(200, 120, 230))
end

local function fingertip(character, root)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand then
		return (hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.4, 0)).Position
	end
	return (root.CFrame * CFrame.new(1, 1.2, -2.2)).Position
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Charge" and character and root then
		local windup = data.Windup or 1
		TuskAnimation.play(character, "JGoBeyond")
		-- Soft & Wet rises up behind him, its right hand raised open.
		TuskStand.action(character, "Loom", { Target = CFrame.new(1.6, 2.4, 2.2), Duration = windup + 0.9 })
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.1)
		speechBubble(character, windup + 0.9)
		panelTint(root.Position, windup + 0.6)
		CameraFX.fovPunch(-6, 0.4)
		-- A tiny bubble spins up on his fingertip, tighter and brighter.
		local b = newBubble("GoBeyond", 0.7)
		VFXLib.animate(windup, function(a)
			if root.Parent then
				placeBubble(b, fingertip(character, root), os.clock() * (1 + a * 3))
			end
			b.Rim.Transparency = 0.6 - 0.4 * a
		end, function()
			destroyBubble(b)
		end)
		-- Stars drift off Soft & Wet while it looms.
		for i = 1, 6 do
			task.delay(i * windup / 6, function()
				if root.Parent then
					VFXLib.burst((root.CFrame * CFrame.new(1.6, 3.4, 2.2)).Position, { Count = 3, Color = Color3.fromRGB(255, 230, 90), Speed = 6, Lifetime = 0.8 })
				end
			end)
		end
	elseif data.Phase == "Release" and root then
		VFXLib.flash(fingertip(character, root), SHINE, 5, 26, 0.3)
		CameraFX.shakeAt(root.Position, 0.5, 40)
		if Common.isLocal(character) then
			CameraFX.fovPunch(8, 0.3)
		end
	elseif data.Phase == "Impact" and data.Position then
		VFXLib.flash(data.Position, SHINE, 8, 40, 0.5)
		CameraFX.shakeAt(data.Position, 1.2, 60)
		for i = 1, 3 do
			local wave = VFXLib.part({ Size = Vector3.new(0.3, 1, 1), Shape = Enum.PartType.Cylinder, Color = i == 2 and STYLE.Friction.Color or SHINE, Material = Enum.Material.Neon, Transparency = 0.2 })
			local tilt = CFrame.Angles(math.random() * math.pi, math.random() * math.pi, 0)
			VFXLib.animate(0.4 + i * 0.08, function(a)
				local d = 18 * VFXLib.easeOut(a)
				wave.Size = Vector3.new(0.3, d, d)
				wave.CFrame = CFrame.new(data.Position) * tilt
				wave.Transparency = 0.2 + 0.8 * a
			end, function()
				wave:Destroy()
			end)
		end
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
				TuskAnimation.hold(character, "JStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "JStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function JosukeVFX.handle(name, data)
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
function JosukeVFX.step(dt)
	dt = dt or 1 / 60
	stepBubbles()
	stepMines()
	stepSlide(dt)
	slowTimer = slowTimer + dt
	if slowTimer > 0.15 then
		slowTimer = 0
		stepStance()
		stepBlind()
	end
end

Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
	if typeof(data) ~= "table" or data.Kind ~= "PlunderBubble" then
		return
	end
	if name == "ProjectileSpawn" then
		spawnBubble(data)
	elseif name == "ProjectileEnd" then
		endBubble(data)
	end
end)

return JosukeVFX
