--[[
	Josuke_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Josuke Higashikata (JoJolion): Soft & Wet.
	Its other half is Josuke_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: JosukeVFX
-- ======================================================================
__modules["JosukeVFX"] = function()
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
	  * GO BEYOND: a tiny white bubble spinning infinitely, rings whirling
	    round it, a shockwave and flash when it lands
]]

local Players = game:GetService("Players")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local TuskStandModels = __require("TuskStandModels")
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Common = __require("TuskActCommon")
local Fighters = __require("Fighters")
local TuskStand = __require("TuskStand")
local SoftAndWetStand = __require("SoftAndWetStand")

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

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Charge" and character and root then
		TuskAnimation.play(character, "JGoBeyond")
		TuskStand.action(character, "Lunge", { Target = CFrame.new(0.4, 1.2, -2.2), Duration = (data.Windup or 1) + 0.2 })
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.1)
		-- A tiny bubble spins up in Soft & Wet's hand.
		local b = newBubble("GoBeyond", 0.8)
		VFXLib.animate(data.Windup or 1, function(a)
			if root.Parent then
				placeBubble(b, (root.CFrame * CFrame.new(0.9, 1.2, -2.4)).Position, os.clock())
			end
			b.Rim.Transparency = 0.6 - 0.4 * a
		end, function()
			destroyBubble(b)
		end)
		label(character, "GO BEYOND", SHINE, 1.4)
	elseif data.Phase == "Release" and root then
		VFXLib.flash(root.Position, SHINE, 4, 24, 0.3)
		CameraFX.shakeAt(root.Position, 0.5, 40)
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
end

-- ======================================================================
-- MODULE: SoftAndWetStand
-- ======================================================================
__modules["SoftAndWetStand"] = function()
--[[
	TuskActVFX.SoftAndWetStand  (StarterPlayerScripts.SpinClient.TuskActVFX.SoftAndWetStand)

	SOFT & WET (Josuke Higashikata, JoJolion), blocky, matched to the art:
	  * a sleek pale-gold body
	  * a smooth round head with big blue domes on each side, a white star
	    set in each
	  * a ring of dark beads round its neck and wrists
	  * an anchor on its chest, a star on each shoulder
	  * a magenta band round its hips
	Registered with TuskStandModels by JosukeVFX, so TuskStand floats it
	behind Josuke (players and NPCs) with a soft blue aura.
]]

local SoftAndWetStand = {}

local GOLD = Color3.fromRGB(232, 204, 120)
local GOLD_SHADE = Color3.fromRGB(196, 164, 84)
local GOLD_LIGHT = Color3.fromRGB(250, 230, 160)
local BLUE = Color3.fromRGB(70, 150, 220)
local WHITE = Color3.fromRGB(250, 252, 255)
local BEAD = Color3.fromRGB(40, 70, 90)
local MAGENTA = Color3.fromRGB(190, 60, 120)
local LINE = Color3.fromRGB(120, 90, 30)

SoftAndWetStand.Aura = Color3.fromRGB(150, 210, 255)
SoftAndWetStand.AuraLight = Color3.fromRGB(230, 245, 255)
SoftAndWetStand.Offset = CFrame.new(2.2, 1.6, 2.8)

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

local function ball(model, parent, name, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(d, d, d), color, cf, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A little 4-point star (two crossed squares) on a face, facing -Z of cf.
local function star(model, parent, cf, size, color)
	box(model, parent, "Star", Vector3.new(size, size, 0.05), color, cf * CFrame.Angles(0, 0, math.pi / 4))
	box(model, parent, "Star", Vector3.new(size * 0.7, size * 0.7, 0.06), color, cf)
end

function SoftAndWetStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "SoftAndWet"
	local rig = { Joints = {} }

	local torso = newPart(model, "Body", Vector3.new(2.0, 1.8, 1.0) * s, GOLD, Enum.Material.SmoothPlastic)
	torso.Reflectance = 0.1
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.51 * s
	box(model, torso, "Chest", Vector3.new(1.6, 0.9, 0.08) * s, GOLD_LIGHT, CFrame.new(0, 0.35 * s, front - 0.02 * s))
	-- An anchor on its chest.
	box(model, torso, "Anchor", Vector3.new(0.12, 0.9, 0.05) * s, LINE, CFrame.new(0, 0.2 * s, front - 0.08 * s))
	box(model, torso, "AnchorBar", Vector3.new(0.5, 0.1, 0.05) * s, LINE, CFrame.new(0, 0.5 * s, front - 0.08 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "AnchorFluke", Vector3.new(0.32, 0.1, 0.05) * s, LINE, CFrame.new(side * 0.16 * s, -0.2 * s, front - 0.08 * s) * CFrame.Angles(0, 0, side * 0.6))
	end
	box(model, torso, "Waist", Vector3.new(1.4, 0.7, 0.85) * s, GOLD_SHADE, CFrame.new(0, -1.15 * s, 0))
	box(model, torso, "HipBand", Vector3.new(1.55, 0.45, 0.95) * s, MAGENTA, CFrame.new(0, -1.6 * s, 0))
	box(model, torso, "Neck", Vector3.new(0.45, 0.45, 0.45) * s, GOLD_SHADE, CFrame.new(0, 1.1 * s, 0))
	-- A ring of dark beads round its neck.
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		ball(model, torso, "Bead", 0.18 * s, BEAD, CFrame.new(math.sin(a) * 0.45 * s, 0.95 * s, math.cos(a) * 0.4 * s))
	end

	-- Head: smooth and round, blue domes with white stars on each side.
	local headBase = CFrame.new(0, 1.2 * s, 0)
	local headOffset = CFrame.new(0, 0.55 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.95, 1.05, 1.0) * s, GOLD, headBase * headOffset)
	head.Reflectance = 0.12
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.5 * s
	box(model, head, "Crown", Vector3.new(0.85, 0.25, 0.9) * s, GOLD_LIGHT, CFrame.new(0, 0.6 * s, 0.02 * s))
	box(model, head, "Visor", Vector3.new(0.75, 0.2, 0.06) * s, GOLD_SHADE, CFrame.new(0, 0.18 * s, hf - 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.2, 0.09, 0.05) * s, BEAD, CFrame.new(side * 0.2 * s, 0.05 * s, hf - 0.03 * s))
		ball(model, head, "EarDome", 0.75 * s, BLUE, CFrame.new(side * 0.55 * s, 0.1 * s, 0.05 * s), Enum.Material.SmoothPlastic)
		star(model, head, CFrame.new(side * 0.93 * s, 0.1 * s, 0.05 * s) * CFrame.Angles(0, side * math.pi / 2, 0), 0.28 * s, WHITE)
	end
	box(model, head, "Mouth", Vector3.new(0.3, 0.05, 0.05) * s, LINE, CFrame.new(0, -0.3 * s, hf - 0.02 * s))

	-- Arms: stars on the shoulders, bead bracelets.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local shoulder = ball(model, torso, "Shoulder", 0.85 * s, GOLD_LIGHT, CFrame.new(side * 1.3 * s, 0.6 * s, 0))
		star(model, shoulder, CFrame.new(0, 0, -0.44 * s), 0.3 * s, BLUE)
		local base = CFrame.new(side * 1.35 * s, 0.35 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local size = Vector3.new(0.55, 2.2, 0.55) * s
		local arm, weld = box(model, torso, a[1], size, GOLD, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Forearm", Vector3.new(0.62, 0.85, 0.62) * s, GOLD_SHADE, CFrame.new(0, -0.5 * s, 0))
		for k = 0, 5 do
			local ang = k / 6 * math.pi * 2
			ball(model, arm, "Bead", 0.14 * s, BEAD, CFrame.new(math.sin(ang) * 0.33 * s, -0.95 * s, math.cos(ang) * 0.33 * s))
		end
		local hand = box(model, arm, "Hand", Vector3.new(0.55, 0.5, 0.5) * s, GOLD, CFrame.new(0, -1.3 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.1, 0.38, 0.1) * s, GOLD_SHADE, CFrame.new(f * 0.12 * s, -0.4 * s, -0.05 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.42 * s, -1.8 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local size = Vector3.new(0.62, 2.4, 0.62) * s
		local leg, weld = box(model, torso, "Leg" .. i, size, GOLD, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		ball(model, leg, "Knee", 0.5 * s, GOLD_LIGHT, CFrame.new(0, 0.1 * s, -0.2 * s))
		box(model, leg, "Foot", Vector3.new(0.6, 0.3, 0.95) * s, GOLD_SHADE, CFrame.new(0, -1.3 * s, -0.15 * s))
	end
	return model, rig
end

return SoftAndWetStand
end
end
