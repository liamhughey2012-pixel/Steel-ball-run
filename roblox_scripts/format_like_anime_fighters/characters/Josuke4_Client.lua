--[[
	Josuke4_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Josuke Higashikata (Part 4): Crazy Diamond.
	Its other half is Josuke4_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: CrazyDiamondStand
-- ======================================================================
__modules["CrazyDiamondStand"] = function()
--[[
	TuskActVFX.CrazyDiamondStand  (StarterPlayerScripts.SpinClient.TuskActVFX.CrazyDiamondStand)

	CRAZY DIAMOND (Josuke Higashikata, Part 4), blocky, matched to the art:
	  * a big, muscular PINK body under pale blue-white ARMOUR plates
	  * a flat-topped pale HELMET round a pink face: glowing cyan eyes, a
	    grilled mouth, and a HEART-shaped chin plate; thick white TUBES run
	    from the back of its head down to its shoulders
	  * heavy armoured shoulders with SPIKES, a split chestplate, a white
	    belly plate with a pink heart, a belt with a heart buckle
	  * armoured forearms and fists with a row of round STUDS across the
	    knuckles and a heart on the back of each hand
	  * pink legs with pale knee and shin guards
	Registered with TuskStandModels by Josuke4VFX, so TuskStand floats it
	behind Josuke with a pink aura.
]]

local CrazyDiamondStand = {}

local PINK = Color3.fromRGB(232, 120, 182)
local PINK_SHADE = Color3.fromRGB(188, 78, 146)
local PINK_LIGHT = Color3.fromRGB(250, 168, 210)
local PLATE = Color3.fromRGB(204, 226, 244)
local PLATE_SHADE = Color3.fromRGB(150, 188, 222)
local PLATE_LIGHT = Color3.fromRGB(242, 250, 255)
local EYE = Color3.fromRGB(130, 240, 255)
local DARK = Color3.fromRGB(60, 40, 70)

CrazyDiamondStand.Aura = Color3.fromRGB(255, 130, 200)
CrazyDiamondStand.AuraLight = Color3.fromRGB(255, 220, 240)
CrazyDiamondStand.Offset = CFrame.new(2.2, 1.6, 2.8)

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

-- A tube from a to b (in parent space).
local function tube(model, parent, a, b, d, color)
	local len = (b - a).Magnitude
	local p = box(model, parent, "Tube", Vector3.new(len + d * 0.4, d, d), color, CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A heart facing forward (-Z): two round lobes and a point.
local function heart(model, parent, cf, size, color)
	for _, side in ipairs({ -1, 1 }) do
		local lobe = box(model, parent, "HeartLobe", Vector3.new(0.06, size * 0.56, size * 0.56), color, cf * CFrame.new(side * size * 0.22, size * 0.12, 0) * CFrame.Angles(0, math.pi / 2, 0))
		lobe.Shape = Enum.PartType.Cylinder
	end
	box(model, parent, "HeartPoint", Vector3.new(size * 0.56, size * 0.56, 0.06), color, cf * CFrame.new(0, -size * 0.12, 0) * CFrame.Angles(0, 0, math.pi / 4))
end

function CrazyDiamondStand.build(scale)
	local s = (scale or 1) * 0.9
	local model = Instance.new("Model")
	model.Name = "CrazyDiamond"
	local rig = { Joints = {} }

	-- A broad pink torso under the armour.
	local torso = newPart(model, "Body", Vector3.new(2.35, 1.9, 1.12) * s, PINK)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.56 * s
	-- A split chestplate.
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Chestplate", Vector3.new(1.0, 0.85, 0.2) * s, PLATE, CFrame.new(side * 0.56 * s, 0.38 * s, front - 0.06 * s) * CFrame.Angles(0, side * 0.12, 0))
		box(model, torso, "PlateEdge", Vector3.new(1.0, 0.08, 0.22) * s, PLATE_SHADE, CFrame.new(side * 0.56 * s, -0.04 * s, front - 0.06 * s) * CFrame.Angles(0, side * 0.12, 0))
		box(model, torso, "PlateShine", Vector3.new(0.5, 0.08, 0.21) * s, PLATE_LIGHT, CFrame.new(side * 0.5 * s, 0.68 * s, front - 0.08 * s) * CFrame.Angles(0, side * 0.12, 0))
		box(model, torso, "Lat", Vector3.new(0.2, 1.3, 0.9) * s, PINK_SHADE, CFrame.new(side * 1.2 * s, -0.1 * s, 0))
	end
	box(model, torso, "Sternum", Vector3.new(0.12, 0.9, 0.16) * s, PINK_SHADE, CFrame.new(0, 0.35 * s, front - 0.03 * s))
	-- The belly: a white plate with a pink heart on it.
	box(model, torso, "Waist", Vector3.new(1.75, 0.85, 0.95) * s, PINK, CFrame.new(0, -1.3 * s, 0))
	box(model, torso, "BellyPlate", Vector3.new(1.0, 0.85, 0.14) * s, PLATE_LIGHT, CFrame.new(0, -0.6 * s, front - 0.02 * s))
	heart(model, torso, CFrame.new(0, -0.58 * s, front - 0.11 * s), 0.55 * s, PINK)
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Oblique", Vector3.new(0.3, 0.75, 0.1) * s, PINK_LIGHT, CFrame.new(side * 0.68 * s, -0.75 * s, front + 0.02 * s))
	end
	-- Belt with a heart buckle.
	box(model, torso, "Belt", Vector3.new(1.85, 0.3, 1.05) * s, PLATE, CFrame.new(0, -1.7 * s, 0))
	box(model, torso, "BeltLine", Vector3.new(1.87, 0.06, 1.07) * s, PLATE_SHADE, CFrame.new(0, -1.6 * s, 0))
	heart(model, torso, CFrame.new(0, -1.7 * s, -0.56 * s), 0.38 * s, PINK)
	box(model, torso, "Hips", Vector3.new(1.75, 0.5, 0.95) * s, PINK_SHADE, CFrame.new(0, -2.0 * s, 0))
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "HipPlate", Vector3.new(0.6, 0.55, 0.1) * s, PLATE, CFrame.new(side * 0.6 * s, -2.05 * s, -0.5 * s) * CFrame.Angles(math.rad(-8), 0, side * -0.15))
	end
	box(model, torso, "Neck", Vector3.new(0.65, 0.45, 0.6) * s, PINK_SHADE, CFrame.new(0, 1.12 * s, 0))
	box(model, torso, "Gorget", Vector3.new(1.1, 0.25, 0.9) * s, PLATE_SHADE, CFrame.new(0, 0.98 * s, 0))

	-- Heavy armoured shoulders with spikes.
	for _, side in ipairs({ -1, 1 }) do
		local cf = CFrame.new(side * 1.45 * s, 0.82 * s, 0) * CFrame.Angles(0, 0, side * -0.35)
		box(model, torso, "Pauldron", Vector3.new(1.05, 0.62, 1.15) * s, PLATE, cf)
		box(model, torso, "PauldronRim", Vector3.new(1.08, 0.12, 1.18) * s, PLATE_SHADE, cf * CFrame.new(0, -0.3 * s, 0))
		box(model, torso, "PauldronShine", Vector3.new(0.7, 0.06, 0.9) * s, PLATE_LIGHT, cf * CFrame.new(0, 0.32 * s, 0))
		for k = -1, 1, 2 do
			local spike = box(model, torso, "Spike", Vector3.new(0.18, 0.55, 0.18) * s, PLATE_LIGHT, cf * CFrame.new(side * 0.15 * s, 0.5 * s, k * 0.28 * s) * CFrame.Angles(0, 0, side * -0.35) * CFrame.Angles(0, math.pi / 4, 0))
			box(model, spike, "SpikeTip", Vector3.new(0.1, 0.25, 0.1) * s, PLATE_LIGHT, CFrame.new(0, 0.35 * s, 0))
		end
	end

	-- Head: a flat-topped pale helmet round a pink face, a heart chin.
	local headBase = CFrame.new(0, 1.3 * s, 0)
	local headOffset = CFrame.new(0, 0.55 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.82, 1.0, 0.85) * s, PINK, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.43 * s
	box(model, head, "Helmet", Vector3.new(0.92, 0.55, 0.92) * s, PLATE, CFrame.new(0, 0.34 * s, 0.02 * s))
	box(model, head, "HelmetTop", Vector3.new(0.98, 0.12, 0.98) * s, PLATE_LIGHT, CFrame.new(0, 0.62 * s, 0.02 * s))
	box(model, head, "HelmetBack", Vector3.new(0.92, 0.9, 0.2) * s, PLATE, CFrame.new(0, 0.05 * s, 0.4 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "HelmetSide", Vector3.new(0.12, 0.85, 0.85) * s, PLATE, CFrame.new(side * 0.46 * s, 0.05 * s, 0.03 * s))
		box(model, head, "Brow", Vector3.new(0.34, 0.1, 0.12) * s, PLATE_SHADE, CFrame.new(side * 0.2 * s, 0.1 * s, hf - 0.05 * s) * CFrame.Angles(0, 0, side * 0.22))
		box(model, head, "Eye", Vector3.new(0.22, 0.08, 0.05) * s, EYE, CFrame.new(side * 0.18 * s, 0.0, hf - 0.03 * s) * CFrame.Angles(0, 0, side * -0.15), Enum.Material.Neon)
	end
	box(model, head, "BrowCrest", Vector3.new(0.12, 0.3, 0.14) * s, PLATE_LIGHT, CFrame.new(0, 0.2 * s, hf - 0.06 * s))
	-- A grilled mouth.
	box(model, head, "Mouth", Vector3.new(0.4, 0.16, 0.05) * s, DARK, CFrame.new(0, -0.2 * s, hf - 0.02 * s))
	for k = -2, 2 do
		box(model, head, "Grill", Vector3.new(0.03, 0.17, 0.06) * s, PINK_LIGHT, CFrame.new(k * 0.08 * s, -0.2 * s, hf - 0.03 * s))
	end
	-- The heart-shaped chin plate.
	heart(model, head, CFrame.new(0, -0.42 * s, hf - 0.02 * s), 0.42 * s, PLATE)
	-- Thick tubes from the back of its head down to its shoulders.
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 1 do
			local a = Vector3.new(side * (0.18 + k * 0.14), (1.75 - k * 0.1), 0.48 + k * 0.05) * s
			local m = Vector3.new(side * (0.42 + k * 0.18), 1.25, 0.72 + k * 0.08) * s
			local b = Vector3.new(side * (0.85 + k * 0.2), 0.95, 0.5) * s
			tube(model, torso, a, m, 0.17 * s, k == 0 and PLATE_LIGHT or PLATE_SHADE)
			tube(model, torso, m, b, 0.17 * s, k == 0 and PLATE_LIGHT or PLATE_SHADE)
		end
	end

	-- Big arms: armoured forearms, fists with studs across the knuckles.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.55 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.72, 2.2, 0.72) * s, PINK, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Bicep", Vector3.new(0.84, 0.75, 0.84) * s, PINK_LIGHT, CFrame.new(0, 0.45 * s, -0.03 * s))
		box(model, arm, "Elbow", Vector3.new(0.7, 0.2, 0.7) * s, PINK_SHADE, CFrame.new(0, 0, 0))
		box(model, arm, "Gauntlet", Vector3.new(0.88, 0.85, 0.88) * s, PLATE, CFrame.new(0, -0.55 * s, 0))
		box(model, arm, "GauntletRim", Vector3.new(0.92, 0.1, 0.92) * s, PLATE_SHADE, CFrame.new(0, -0.14 * s, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.78, 0.66, 0.72) * s, PLATE_LIGHT, CFrame.new(0, -1.3 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.16, 0.3, 0.16) * s, PLATE, CFrame.new(f * 0.18 * s, -0.4 * s, -0.12 * s))
			ball(model, hand, "Stud", 0.17 * s, PINK, CFrame.new(f * 0.18 * s, -0.2 * s, -0.38 * s))
		end
		heart(model, hand, CFrame.new(0, 0.02 * s, 0.37 * s) * CFrame.Angles(0, math.pi, 0), 0.3 * s, PINK)
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: pink, pale knee and shin guards.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.5 * s, -2.15 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.76, 2.4, 0.76) * s, PINK, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Thigh", Vector3.new(0.88, 0.95, 0.88) * s, PINK_LIGHT, CFrame.new(0, 0.65 * s, 0))
		box(model, leg, "KneePad", Vector3.new(0.6, 0.45, 0.2) * s, PLATE, CFrame.new(0, 0.02 * s, -0.42 * s))
		box(model, leg, "Shin", Vector3.new(0.82, 0.75, 0.84) * s, PLATE, CFrame.new(0, -0.6 * s, 0))
		box(model, leg, "ShinShine", Vector3.new(0.3, 0.6, 0.06) * s, PLATE_LIGHT, CFrame.new(0, -0.6 * s, -0.44 * s))
		box(model, leg, "Foot", Vector3.new(0.72, 0.32, 1.05) * s, PLATE_SHADE, CFrame.new(0, -1.3 * s, -0.17 * s))
	end
	return model, rig
end

return CrazyDiamondStand
end

-- ======================================================================
-- MODULE: Josuke4VFX
-- ======================================================================
__modules["Josuke4VFX"] = function()
--[[
	TuskActVFX.Josuke4VFX  (StarterPlayerScripts.SpinClient.TuskActVFX.Josuke4VFX)

	Client visuals for Josuke Higashikata (Part 4) / CRAZY DIAMOND. Blocky.
	  * Crazy Diamond (CrazyDiamondStand) floats behind him with a pink aura;
	    Josuke stands with his fists up, loose
	  * DORA COMBO: Crazy Diamond's pale fists fly out with him; "DORA!" on
	    the 4th
	  * DORARARA RUSH: a blur of fists hammering the space in front of him,
	    "DORARARA" spilling out, then one huge "DORA!" and a shockwave
	  * BREAK & RESTORE: a punch, then chunks of rock fly in from all round
	    and fuse into a lump round the target (pink restoration sparkles);
	    when it's over the rock bursts apart
	  * HOMING SHARD: a red-edged glass shard flicked from his hand that
	    curves after its target, trailing pink sparkles
	  * "WHAT DID YOU SAY ABOUT MY HAIR?!": he touches his pompadour, then
	    snaps: the line over his head, an anger mark, a red-pink shockwave,
	    and a red outline round him for as long as the rage lasts
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
local CrazyDiamondStand = __require("CrazyDiamondStand")

local Josuke4VFX = {}
local ACT = 25
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, CrazyDiamondStand.build, { Aura = CrazyDiamondStand.Aura, AuraLight = CrazyDiamondStand.AuraLight, Offset = CrazyDiamondStand.Offset })

local PINK = Color3.fromRGB(255, 120, 196)
local FIST = Color3.fromRGB(214, 232, 248)
local STUD = Color3.fromRGB(232, 120, 182)
local CYAN = Color3.fromRGB(140, 230, 255)
local RED = Color3.fromRGB(255, 70, 90)
local ROCK = Color3.fromRGB(150, 130, 110)
local ROCK_DARK = Color3.fromRGB(110, 94, 80)

local stanced = {}
local rushes = {} -- [character] = rush job token
local rocks = {} -- [target character] = { parts }
local shards = {} -- [id] = shard job
local rages = {} -- [character] = Highlight

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function label(adornee, text, color, duration, size, offset, font)
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
	t.Font = font or Enum.Font.Bangers
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

-- "DORA" text popping out at a world spot.
local function dora(at, big)
	local anchor = VFXLib.part({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(at), Transparency = 1 })
	label(anchor, big and "DORA!" or "DORA", big and PINK or CYAN, big and 1.0 or 0.5, big and 260 or 120, Vector3.new((math.random() - 0.5) * 3, math.random() * 2, 0))
	task.delay(1.1, function()
		anchor:Destroy()
	end)
end

-- One pale fist (pink studs) flying forward from `from` along `dir`, then fading.
local function fist(from, dir, size)
	size = size or 1
	local f = VFXLib.part({ Size = Vector3.new(0.8, 0.75, 0.9) * size, Color = FIST, Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
	local studs = VFXLib.part({ Size = Vector3.new(0.78, 0.18, 0.2) * size, Color = STUD, Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
	local trail = VFXLib.part({ Size = Vector3.new(0.4, 0.4, 2.2) * size, Color = PINK, Transparency = 0.5 })
	VFXLib.animate(0.16, function(a)
		local p = from + dir * (a * 3.2)
		local cf = CFrame.lookAt(p, p + dir)
		f.CFrame = cf
		studs.CFrame = cf * CFrame.new(0, 0.18 * size, -0.42 * size)
		trail.CFrame = cf * CFrame.new(0, 0, 1.3 * size)
		local t = a < 0.6 and 0.15 or 0.15 + (a - 0.6) / 0.4 * 0.85
		f.Transparency = t
		studs.Transparency = t
		trail.Transparency = 0.5 + 0.5 * a
	end, function()
		f:Destroy()
		studs:Destroy()
		trail:Destroy()
	end)
end

-- Pink "restoration" sparkles drifting in to a point.
local function restoreSparkles(at, count, radius)
	for _ = 1, count do
		local from = at + Vector3.new((math.random() - 0.5) * 2, (math.random() - 0.3), (math.random() - 0.5) * 2).Unit * (radius or 4)
		local sp = VFXLib.part({ Size = Vector3.new(0.25, 0.25, 0.25), Color = math.random() < 0.5 and PINK or CYAN, Transparency = 0.1, CFrame = CFrame.new(from) * CFrame.Angles(math.random() * 3, math.random() * 3, 0) })
		VFXLib.animate(0.35 + math.random() * 0.2, function(a)
			sp.CFrame = CFrame.new(from:Lerp(at, VFXLib.easeOut(a))) * CFrame.Angles(a * 6, a * 4, 0)
			sp.Transparency = 0.1 + 0.9 * a
		end, function()
			sp:Destroy()
		end)
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
	TuskAnimation.play(character, "JK4_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1, -3.4), Duration = 0.28 })
	VFXLib.sound(sounds.Swing, root, 0.5, 1.0 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or pal.Second)
	fist((root.CFrame * CFrame.new(index % 2 == 0 and -0.6 or 0.6, 0.8, -1.8)).Position, root.CFrame.LookVector, 1.1)
	if index == 4 then
		dora((root.CFrame * CFrame.new(0, 2, -3)).Position, true)
	end
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function rush(character, duration)
	local token = {}
	rushes[character] = token
	TuskAnimation.play(character, "JK4Rush")
	TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 0.8, -3.6), Duration = duration })
	local start = os.clock()
	local nextFist, nextDora = 0, 0
	VFXLib.animate(duration, function()
		local root = Common.rootOf(character)
		if rushes[character] ~= token or not root then
			return
		end
		local t = os.clock() - start
		if t >= nextFist then
			nextFist = t + 0.025
			local off = CFrame.new((math.random() - 0.5) * 2.6, 0.4 + (math.random() - 0.5) * 2.2, -2.4)
			fist((root.CFrame * off).Position, root.CFrame.LookVector, 0.9 + math.random() * 0.3)
		end
		if t >= nextDora then
			nextDora = t + 0.16
			dora((root.CFrame * CFrame.new((math.random() - 0.5) * 4, 2 + math.random(), -3)).Position, false)
		end
	end, function()
		if rushes[character] == token then
			rushes[character] = nil
		end
	end)
	if Common.isLocal(character) then
		CameraFX.speedLines(duration, PINK)
	end
end

-- Chunks of rock fly in from all round and fuse into a lump round them.
local function clearRocks(target, burst)
	local list = rocks[target]
	rocks[target] = nil
	if not list then
		return
	end
	for _, r in ipairs(list) do
		if r.Parent then
			if burst then
				local from = r.Position
				local out = (from - (list.Center or from)).Unit
				if out ~= out then
					out = Vector3.new(0, 1, 0)
				end
				local spin = math.random() * 4
				VFXLib.animate(0.5, function(a)
					r.CFrame = CFrame.new(from + out * (a * 9) + Vector3.new(0, a * 4 - a * a * 6, 0)) * CFrame.Angles(a * spin, a * spin * 0.7, 0)
					r.Transparency = math.max(0, a * 1.5 - 0.5)
				end, function()
					r:Destroy()
				end)
			else
				r:Destroy()
			end
		end
	end
end

local function encase(target, at, time)
	clearRocks(target)
	local list = { Center = at }
	rocks[target] = list
	restoreSparkles(at, 18, 7)
	for k = 1, 16 do
		local ang = k / 16 * math.pi * 2 + math.random() * 0.3
		local y = -2.2 + (k % 4) * 1.35 + math.random() * 0.4
		local rad = 1.1 + math.random() * 0.4
		local final = at + Vector3.new(math.cos(ang) * rad, y, math.sin(ang) * rad)
		local start = at + Vector3.new(math.cos(ang) * 12, y + 3 + math.random() * 3, math.sin(ang) * 12)
		local size = Vector3.new(1.2 + math.random() * 0.6, 1.0 + math.random() * 0.6, 1.2 + math.random() * 0.6)
		local rock = VFXLib.part({ Size = size, Color = k % 3 == 0 and ROCK_DARK or ROCK, Material = Enum.Material.Slate, CFrame = CFrame.new(start) })
		table.insert(list, rock)
		local spin = Vector3.new(math.random() * 6, math.random() * 6, math.random() * 6)
		local delayT = k * 0.015
		task.delay(delayT, function()
			if not rock.Parent then
				return
			end
			VFXLib.animate(0.3, function(a)
				local e = VFXLib.easeOut(a)
				rock.CFrame = CFrame.new(start:Lerp(final, e)) * CFrame.Angles(spin.X * (1 - e), spin.Y * (1 - e), spin.Z * (1 - e))
			end)
		end)
	end
	-- The top of the lump.
	local cap = VFXLib.part({ Size = Vector3.new(2.6, 1.2, 2.6), Color = ROCK, Material = Enum.Material.Slate, CFrame = CFrame.new(at + Vector3.new(0, 3.3, 0)), Transparency = 1 })
	table.insert(list, cap)
	task.delay(0.3, function()
		if cap.Parent then
			cap.Transparency = 0
			VFXLib.burst(at, { Count = 12, Color = ROCK, Speed = 12, Lifetime = 0.35 })
		end
	end)
	-- Never left behind.
	task.delay((time or 2.2) + 1, function()
		if rocks[target] == list then
			clearRocks(target, true)
		end
	end)
end

-- The homing shard: a glass sliver steering after its target.
local function flyShard(data)
	local id = data.Id
	local pos = data.From
	local vel = (data.Direction or Vector3.new(0, 0, -1)) * (data.Speed or 75)
	local turn = data.Turn or 7
	local target = data.Target
	local shard = VFXLib.part({ Size = Vector3.new(0.12, 0.4, 1.1), Color = Color3.fromRGB(220, 240, 255), Material = Enum.Material.Glass, Transparency = 0.25, CFrame = CFrame.lookAt(pos, pos + vel) })
	local blood = VFXLib.part({ Size = Vector3.new(0.13, 0.12, 0.5), Color = RED, CFrame = shard.CFrame })
	local job = { Shard = shard, Blood = blood }
	shards[id] = job
	local nextSpark = 0
	VFXLib.animate(data.Life or 2.2, function(_, dt)
		if shards[id] ~= job then
			return
		end
		dt = dt or 1 / 60
		local tr = target and typeof(target) == "Instance" and target.Parent and target:FindFirstChild("HumanoidRootPart")
		if tr then
			local want = (tr.Position - pos).Unit * vel.Magnitude
			vel = (vel + (want - vel) * math.min(1, turn * dt)).Unit * vel.Magnitude
		end
		pos = pos + vel * dt
		local cf = CFrame.lookAt(pos, pos + vel) * CFrame.Angles(0, 0, os.clock() * 20)
		shard.CFrame = cf
		blood.CFrame = cf * CFrame.new(0, 0.14, 0.25)
		if os.clock() >= nextSpark then
			nextSpark = os.clock() + 0.04
			local sp = VFXLib.part({ Size = Vector3.new(0.18, 0.18, 0.18), Color = PINK, CFrame = CFrame.new(pos), Transparency = 0.2 })
			VFXLib.animate(0.3, function(a)
				sp.Transparency = 0.2 + 0.8 * a
			end, function()
				sp:Destroy()
			end)
		end
	end, function()
		if shards[id] == job then
			shards[id] = nil
			shard:Destroy()
			blood:Destroy()
		end
	end)
end

local function endShard(data)
	local job = data.Id and shards[data.Id]
	if job then
		shards[data.Id] = nil
		job.Shard:Destroy()
		job.Blood:Destroy()
	end
	if data.Position then
		if data.Hit then
			TuskVFX.CreateImpactStar(data.Position, { Size = 2.4, Rays = 6, Color = PINK, Color2 = Color3.new(1, 1, 1), Duration = 0.14 })
			VFXLib.burst(data.Position, { Count = 8, Color = RED, Speed = 10, Lifetime = 0.3 })
		else
			VFXLib.burst(data.Position, { Count = 6, Color = Color3.fromRGB(220, 240, 255), Speed = 8, Lifetime = 0.3 })
		end
	end
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "DoraRush" then
		if phase == "Start" and character and root then
			rush(character, (data.Windup or 0.15) + (data.Duration or 1.4))
		elseif phase == "Hit" and data.Position then
			TuskVFX.CreateImpactStar(data.Position, { Size = 2.2, Rays = 5, Color = PINK, Color2 = Color3.new(1, 1, 1), Duration = 0.08 })
		elseif phase == "Finish" and data.Position then
			if character then
				rushes[character] = nil
				TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 0.8, -4.2), Duration = 0.35 })
			end
			dora(data.Position + Vector3.new(0, 2, 0), true)
			local dir = data.Direction or Vector3.new(0, 0, -1)
			fist(data.Position - dir * 1.5, dir, 2.2)
			TuskVFX.CreateRotationalShockwave(CFrame.lookAt(data.Position, data.Position + dir) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = data.Radius or 8, Layers = 3, Color = PINK, Color2 = CYAN, Particles = 1, Width = 0.5 })
			CameraFX.shakeAt(data.Position, 0.8, 50)
			if character and Common.isLocal(character) then
				CameraFX.impactFrame(pal.Light)
			end
		elseif phase == "Stop" and character then
			rushes[character] = nil
		end
	elseif move == "RockFusion" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "JK4Fuse")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0.6, 1, -3.4), Duration = (data.Windup or 0.25) + 0.4 })
		elseif phase == "Encase" and data.Position then
			fist(data.Position + Vector3.new(0, 0.5, 0) - (root and root.CFrame.LookVector or Vector3.new(0, 0, -1)) * 2, root and root.CFrame.LookVector or Vector3.new(0, 0, -1), 1.6)
			dora(data.Position + Vector3.new(0, 2.5, 0), true)
			TuskVFX.CreateImpactStar(data.Position, { Size = 3, Rays = 7, Color = PINK, Color2 = Color3.new(1, 1, 1), Duration = 0.14 })
			if typeof(data.Target) == "Instance" then
				encase(data.Target, data.Position, data.Time)
				local head = data.Target:FindFirstChild("Head")
				label(head, "RESTORED... INTO ROCK", Color3.fromRGB(230, 210, 180), 1.6, 260, Vector3.new(0, 4, 0))
			end
			CameraFX.shakeAt(data.Position, 0.5, 40)
		elseif phase == "Burst" and data.Position then
			if typeof(data.Target) == "Instance" then
				clearRocks(data.Target, true)
			end
			VFXLib.burst(data.Position, { Count = 16, Color = ROCK, Speed = 16, Lifetime = 0.45 })
			CameraFX.shakeAt(data.Position, 0.6, 40)
		elseif phase == "Miss" and data.Position then
			VFXLib.burst(data.Position, { Count = 5, Color = PINK, Speed = 8, Lifetime = 0.25 })
		end
	elseif move == "HomingShard" then
		if phase == "Flick" and character and root then
			TuskAnimation.play(character, "JK4Flick")
		elseif phase == "Fly" and data.From then
			flyShard(data)
			VFXLib.sound(sounds.NailFire, data.From, 0.5, 1.8)
		elseif phase == "End" then
			endShard(data)
		end
	end
end

---------------------------------------------------------------------------
-- "WHAT DID YOU SAY ABOUT MY HAIR?!"
---------------------------------------------------------------------------
local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Snap" and character and root then
		TuskAnimation.play(character, "JK4Snap")
		TuskStand.action(character, "Loom", { Target = CFrame.new(1.4, 2.6, 2.2), Duration = (data.Windup or 0.9) + 0.6 })
		local head = character:FindFirstChild("Head")
		label(head, "WHAT DID YOU SAY ABOUT MY HAIR?!", RED, 2.4, 420)
		task.delay(0.35, function()
			label(head, "💢", RED, 1.4, 90, Vector3.new(1.4, 1.6, 0), Enum.Font.GothamBlack)
		end)
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.1)
	elseif data.Phase == "Rage" and data.Position then
		TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position) , { Radius = data.Radius or 14, Layers = 3, Color = RED, Color2 = PINK, Particles = 1, Width = 0.6 })
		VFXLib.burst(data.Position, { Count = 20, Color = PINK, Speed = 20, Lifetime = 0.5 })
		CameraFX.shakeAt(data.Position, 1.0, 50)
		if character then
			if character == (localPlayer and localPlayer.Character) then
				CameraFX.impactFrame(RED)
				CameraFX.fovPunch(10, 0.4)
			end
			local old = rages[character]
			if old and old.Parent then
				old:Destroy()
			end
			local h = Instance.new("Highlight")
			h.Name = "HairRage"
			h.FillColor = RED
			h.FillTransparency = 0.85
			h.OutlineColor = Color3.fromRGB(255, 90, 140)
			h.OutlineTransparency = 0
			h.Adornee = character
			h.Parent = character
			rages[character] = h
			local untilT = os.clock() + (data.Duration or 10)
			task.delay((data.Duration or 10) + 0.5, function()
				if rages[character] == h then
					rages[character] = nil
				end
				if h.Parent then
					h:Destroy()
				end
			end)
			-- A pulsing outline while he's angry.
			VFXLib.animate(data.Duration or 10, function()
				if h.Parent then
					h.OutlineTransparency = 0.2 + 0.3 * math.sin(os.clock() * 8)
				end
				if os.clock() > untilT then
					return
				end
			end)
		end
	elseif data.Phase == "Calm" and character then
		local h = rages[character]
		rages[character] = nil
		if h and h.Parent then
			h:Destroy()
		end
		label(character:FindFirstChild("Head"), "...GREAT.", Color3.new(1, 1, 1), 1.2, 200)
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
				TuskAnimation.hold(character, "JK4Stance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "JK4Stance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
	for target in pairs(rocks) do
		if not target.Parent then
			clearRocks(target)
		end
	end
end

function Josuke4VFX.handle(name, data)
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
function Josuke4VFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
	end
end

return Josuke4VFX
end
end
