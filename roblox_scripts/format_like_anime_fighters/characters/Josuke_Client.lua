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
	  * glossy icy white-teal all over, slim and jointed like a doll
	  * a tall capsule head with a narrow chin, a striped purple line
	    down the middle, two round eyes with a slit in each, and a horn
	    sticking out of each side (a little yellow star on one tip)
	  * a big HEART-shaped chest; the line runs down the neck to a ring,
	    then into the anchor / trident: a stem with two arms curving up
	    to arrowheads
	  * dark purple ball joints, green coiled springs at elbows, wrists
	    and knees, pointed fins on the shoulders and hips
	  * a maroon waist with a blue band, blue shoes with lime soles
	  * soap bubbles with stars in them floating round it
	Registered with TuskStandModels by JosukeVFX, so TuskStand floats it
	behind Josuke (players and NPCs) with a soft blue aura.
]]

local SoftAndWetStand = {}

local BODY = Color3.fromRGB(228, 248, 246)
local SHADE = Color3.fromRGB(168, 222, 220)
local LINE = Color3.fromRGB(96, 84, 176)
local HATCH = Color3.fromRGB(170, 160, 230)
local JOINT = Color3.fromRGB(92, 52, 120)
local SPRING = Color3.fromRGB(150, 196, 70)
local WAIST = Color3.fromRGB(140, 40, 78)
local BAND = Color3.fromRGB(70, 120, 205)
local SOLE = Color3.fromRGB(196, 232, 60)
local STAR = Color3.fromRGB(255, 220, 60)
local BUBBLE = Color3.fromRGB(215, 240, 255)
local BUBBLE_STAR = Color3.fromRGB(90, 190, 200)
local EYE_DARK = Color3.fromRGB(40, 60, 70)

SoftAndWetStand.Aura = Color3.fromRGB(150, 220, 255)
SoftAndWetStand.AuraLight = Color3.fromRGB(230, 250, 255)
SoftAndWetStand.Offset = CFrame.new(2.2, 1.6, 2.8)

local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0) -- turns a cylinder's axis (X) to face forward
local ALONG_Y = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder's axis upright

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
	p.Reflectance = 0.12
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

-- A cylinder: `length` along its axis, `d` across. cf sets where its axis points.
local function cyl(model, parent, name, length, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(length, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A flat strip from a to b (2D points in the XY plane) at depth z.
local function strip(model, parent, name, a, b, width, z, color)
	local dx, dy = b.X - a.X, b.Y - a.Y
	local len = math.sqrt(dx * dx + dy * dy)
	local mid = (a + b) / 2
	return box(model, parent, name, Vector3.new(len + width * 0.6, width, 0.05), color, CFrame.new(mid.X, mid.Y, z) * CFrame.Angles(0, 0, math.atan(dy, dx)))
end

-- A little star (two crossed squares), facing -Z of cf.
local function star(model, parent, cf, size, color)
	box(model, parent, "Star", Vector3.new(size, size, 0.05), color, cf * CFrame.Angles(0, 0, math.pi / 4))
	box(model, parent, "Star", Vector3.new(size * 0.7, size * 0.7, 0.06), color, cf)
end

-- A green coiled spring round a limb (two thin rings).
local function spring(model, parent, y, d, s)
	for k = 0, 1 do
		cyl(model, parent, "Spring", 0.07 * s, d, SPRING, CFrame.new(0, y + k * 0.12 * s, 0) * ALONG_Y)
	end
end

-- A pointed fin: a flat diamond sticking out.
local function fin(model, parent, cf, length, s)
	local p = box(model, parent, "Fin", Vector3.new(length, 0.42 * s, 0.14 * s), BODY, cf)
	box(model, p, "FinTip", Vector3.new(0.42 * s, 0.42 * s, 0.13 * s), SHADE, CFrame.new(length / 2, 0, 0) * CFrame.Angles(0, 0, math.pi / 4))
	return p
end

function SoftAndWetStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "SoftAndWet"
	local rig = { Joints = {} }

	-- Core (the rig's body): everything else hangs off it.
	local torso = newPart(model, "Body", Vector3.new(1.4, 1.6, 0.9) * s, BODY)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso

	-- HEART chest: two round lobes on top, tapering to a point at the waist.
	for _, side in ipairs({ -1, 1 }) do
		cyl(model, torso, "HeartLobe", 1.0 * s, 1.55 * s, BODY, CFrame.new(side * 0.68 * s, 0.5 * s, 0) * ALONG_Z)
	end
	box(model, torso, "Heart1", Vector3.new(2.7, 0.8, 1.0) * s, BODY, CFrame.new(0, 0.25 * s, 0))
	box(model, torso, "Heart2", Vector3.new(2.15, 0.5, 0.98) * s, BODY, CFrame.new(0, -0.38 * s, 0))
	box(model, torso, "Heart3", Vector3.new(1.55, 0.45, 0.95) * s, BODY, CFrame.new(0, -0.82 * s, 0))
	box(model, torso, "Heart4", Vector3.new(0.9, 0.4, 0.9) * s, SHADE, CFrame.new(0, -1.22 * s, 0))
	-- The emblem: ring, stem and two arms curving up to arrowheads.
	local z = -0.53 * s
	local P = function(x, y)
		return Vector3.new(x * s, y * s, 0)
	end
	cyl(model, torso, "EmblemRing", 0.05 * s, 0.46 * s, LINE, CFrame.new(0, 0.62 * s, z) * ALONG_Z)
	cyl(model, torso, "EmblemHole", 0.06 * s, 0.24 * s, BODY, CFrame.new(0, 0.62 * s, z - 0.01 * s) * ALONG_Z)
	strip(model, torso, "Stem", P(0, 0.4), P(0, -1.0), 0.12 * s, z, LINE)
	strip(model, torso, "Crossbar", P(-0.22, 0.2), P(0.22, 0.2), 0.08 * s, z, LINE)
	for _, side in ipairs({ -1, 1 }) do
		strip(model, torso, "Arm", P(0, -0.98), P(side * 0.45, -0.75), 0.11 * s, z, LINE)
		strip(model, torso, "Arm", P(side * 0.45, -0.75), P(side * 0.72, -0.25), 0.11 * s, z, LINE)
		strip(model, torso, "Arm", P(side * 0.72, -0.25), P(side * 0.8, 0.12), 0.11 * s, z, LINE)
		box(model, torso, "Arrowhead", Vector3.new(0.3, 0.3, 0.05) * s, LINE, CFrame.new(side * 0.8 * s, 0.2 * s, z) * CFrame.Angles(0, 0, math.pi / 4))
	end
	-- Hatching across the stripes, like the ink in the art.
	for k = 0, 6 do
		box(model, torso, "Hatch", Vector3.new(0.13, 0.035, 0.055) * s, HATCH, CFrame.new(0, (0.3 - k * 0.18) * s, z - 0.005 * s))
	end

	-- Neck: thin, with a ring at its base where the line starts.
	cyl(model, torso, "Neck", 0.7 * s, 0.36 * s, SHADE, CFrame.new(0, 1.25 * s, 0) * ALONG_Y)
	cyl(model, torso, "NeckRing", 0.08 * s, 0.34 * s, LINE, CFrame.new(0, 1.0 * s, -0.42 * s) * ALONG_Z)
	cyl(model, torso, "NeckRingHole", 0.09 * s, 0.16 * s, BODY, CFrame.new(0, 1.0 * s, -0.44 * s) * ALONG_Z)
	strip(model, torso, "NeckLine", P(0, 1.55), P(0, 1.1), 0.1 * s, -0.2 * s, LINE)

	-- Head: a tall capsule with a narrow chin.
	local headBase = CFrame.new(0, 1.55 * s, 0)
	local headOffset = CFrame.new(0, 0.75 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.9, 1.1, 0.85) * s, BODY, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	ball(model, head, "Dome", 0.9 * s, BODY, CFrame.new(0, 0.55 * s, 0))
	box(model, head, "Chin", Vector3.new(0.62, 0.45, 0.72) * s, BODY, CFrame.new(0, -0.75 * s, 0.02 * s))
	box(model, head, "Mouth", Vector3.new(0.4, 0.1, 0.05) * s, SHADE, CFrame.new(0, -0.58 * s, -0.36 * s))
	local hz = -0.44 * s
	-- The striped line down the middle of the face, over the dome.
	box(model, head, "Line", Vector3.new(0.13, 1.6, 0.04) * s, LINE, CFrame.new(0, -0.15 * s, hz))
	box(model, head, "LineTop", Vector3.new(0.13, 0.5, 0.04) * s, LINE, CFrame.new(0, 0.78 * s, -0.33 * s) * CFrame.Angles(-0.75, 0, 0))
	for k = 0, 6 do
		box(model, head, "Hatch", Vector3.new(0.14, 0.03, 0.045) * s, HATCH, CFrame.new(0, (0.5 - k * 0.2) * s, hz - 0.005 * s))
	end
	-- Round eyes with a slit.
	for _, side in ipairs({ -1, 1 }) do
		cyl(model, head, "EyeRim", 0.04 * s, 0.34 * s, EYE_DARK, CFrame.new(side * 0.25 * s, 0.12 * s, hz) * ALONG_Z)
		cyl(model, head, "Eye", 0.05 * s, 0.28 * s, BODY, CFrame.new(side * 0.25 * s, 0.12 * s, hz - 0.01 * s) * ALONG_Z)
		box(model, head, "Slit", Vector3.new(0.045, 0.24, 0.06) * s, EYE_DARK, CFrame.new(side * 0.25 * s, 0.12 * s, hz - 0.02 * s))
		-- A horn out of each side, tapering to a point.
		cyl(model, head, "Horn", 0.55 * s, 0.3 * s, BODY, CFrame.new(side * 0.68 * s, 0.32 * s, 0))
		cyl(model, head, "Horn", 0.5 * s, 0.18 * s, SHADE, CFrame.new(side * 1.18 * s, 0.32 * s, 0))
		ball(model, head, "HornTip", 0.13 * s, SHADE, CFrame.new(side * 1.45 * s, 0.32 * s, 0))
	end
	star(model, head, CFrame.new(1.55 * s, 0.4 * s, -0.08 * s), 0.18 * s, STAR)

	-- Shoulders: purple ball joints and pointed fins.
	for _, side in ipairs({ -1, 1 }) do
		ball(model, torso, "ShoulderJoint", 0.55 * s, JOINT, CFrame.new(side * 1.38 * s, 0.35 * s, 0))
		local f = fin(model, torso, CFrame.new(side * 1.55 * s, 0.85 * s, 0.1 * s) * CFrame.Angles(0, 0, side > 0 and 0.35 or math.pi - 0.35), 1.2 * s, s)
		box(model, f, "FinPatch", Vector3.new(0.35, 0.2, 0.16) * s, SPRING, CFrame.new(0.2 * s, 0, 0))
	end

	-- Arms: thin, jointed, springs at the elbow and wrist.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.42 * s, 0.3 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.36, 2.2, 0.36) * s, BODY, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		ball(model, arm, "Elbow", 0.44 * s, JOINT, CFrame.new(0, 0.05 * s, 0))
		spring(model, arm, -0.15 * s, 0.5 * s, s)
		box(model, arm, "Forearm", Vector3.new(0.46, 0.85, 0.46) * s, BODY, CFrame.new(0, -0.6 * s, 0))
		ball(model, arm, "Wrist", 0.34 * s, JOINT, CFrame.new(0, -1.08 * s, 0))
		spring(model, arm, -1.0 * s, 0.42 * s, s)
		local hand = box(model, arm, "Hand", Vector3.new(0.5, 0.45, 0.42) * s, BODY, CFrame.new(0, -1.35 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.09, 0.36, 0.1) * s, SHADE, CFrame.new(f * 0.11 * s, -0.36 * s, -0.04 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Waist: thin and maroon, a blue band, then the hips with fins.
	box(model, torso, "Waist", Vector3.new(0.7, 0.55, 0.6) * s, WAIST, CFrame.new(0, -1.55 * s, 0))
	box(model, torso, "Band", Vector3.new(1.35, 0.24, 0.85) * s, BAND, CFrame.new(0, -1.86 * s, 0))
	box(model, torso, "Hips", Vector3.new(1.25, 0.45, 0.8) * s, BODY, CFrame.new(0, -2.15 * s, 0))
	box(model, torso, "Crotch", Vector3.new(0.5, 0.3, 0.7) * s, WAIST, CFrame.new(0, -2.45 * s, 0))
	for _, side in ipairs({ -1, 1 }) do
		fin(model, torso, CFrame.new(side * 0.85 * s, -2.25 * s, 0.1 * s) * CFrame.Angles(0, 0, side > 0 and -1.1 or math.pi + 1.1), 0.9 * s, s)
		ball(model, torso, "HipJoint", 0.46 * s, JOINT, CFrame.new(side * 0.45 * s, -2.4 * s, 0))
	end

	-- Legs: thin, a purple knee with a spring, blue shoes with lime soles.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.45 * s, -2.4 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.42, 2.4, 0.42) * s, BODY, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		ball(model, leg, "Knee", 0.48 * s, JOINT, CFrame.new(0, 0.05 * s, -0.06 * s))
		spring(model, leg, -0.18 * s, 0.56 * s, s)
		box(model, leg, "Shin", Vector3.new(0.5, 0.9, 0.5) * s, BODY, CFrame.new(0, -0.6 * s, 0))
		local shoe = box(model, leg, "Shoe", Vector3.new(0.58, 0.36, 1.05) * s, BAND, CFrame.new(0, -1.25 * s, -0.2 * s))
		box(model, shoe, "Sole", Vector3.new(0.6, 0.12, 1.1) * s, SOLE, CFrame.new(0, -0.2 * s, -0.01 * s))
		box(model, shoe, "Toe", Vector3.new(0.4, 0.14, 0.3) * s, SOLE, CFrame.new(0, 0.05 * s, -0.42 * s))
	end

	-- Soap bubbles with stars in them, floating round it.
	for _, b in ipairs({ { -1.9, 1.7, -0.3, 0.7 }, { -2.0, 0.6, -0.5, 0.55 }, { -1.5, 2.7, 0.1, 0.48 }, { 1.95, 2.3, -0.2, 0.6 }, { 2.1, 1.3, -0.5, 0.42 } }) do
		local cf = CFrame.new(b[1] * s, b[2] * s, b[3] * s)
		local bub = ball(model, torso, "Bubble", b[4] * s, BUBBLE, cf, Enum.Material.Glass)
		bub.Transparency = 0.55
		bub.Reflectance = 0.3
		star(model, torso, cf * CFrame.new(0, 0, -0.05 * s), b[4] * 0.45 * s, BUBBLE_STAR)
	end
	return model, rig
end

return SoftAndWetStand
end
end
