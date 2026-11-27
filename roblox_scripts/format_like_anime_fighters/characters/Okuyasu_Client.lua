--[[
	Okuyasu_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Okuyasu Nijimura (Part 4): The Hand.
	Its other half is Okuyasu_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: OkuyasuVFX
-- ======================================================================
__modules["OkuyasuVFX"] = function()
--[[
	TuskActVFX.OkuyasuVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.OkuyasuVFX)

	Client visuals for Okuyasu Nijimura / THE HAND. Blocky.
	  * The Hand (TheHandStand) floats behind him with a blue aura; Okuyasu
	    stands in a tough slouch
	  * HAND COMBO: blue swings; the 4th is a big backhand
	  * SPACE ERASE: The Hand winds up and swipes its glowing palm; a black
	    rip opens in the air where it passed (a thin pale edge round a void),
	    then snaps shut; "GAOON"
	  * ERASE PULL: a swipe at empty air; a void streak runs from the target
	    to him, an afterimage is left where they stood, "GAOON"
	  * ERASE DASH: a swipe; he blinks forward, an afterimage and a void
	    streak left behind
	  * ZA HANDO: GREAT ERASURE: "ZA HANDO!", then rip after rip in front of
	    him (GAOON, GAOON...), the last one huge
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
local TheHandStand = __require("TheHandStand")

local OkuyasuVFX = {}
local ACT = 27
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, TheHandStand.build, { Aura = TheHandStand.Aura, AuraLight = TheHandStand.AuraLight, Offset = TheHandStand.Offset })

local BLUE = Color3.fromRGB(110, 160, 255)
local EDGE = Color3.fromRGB(200, 240, 255)
local VOID = Color3.fromRGB(6, 4, 12)
local GOLD = Color3.fromRGB(236, 190, 70)

local stanced = {}

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
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

-- "GAOON" at a world spot.
local function gaoon(at, big)
	local anchor = VFXLib.part({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(at), Transparency = 1 })
	label(anchor, "GAOON", big and GOLD or EDGE, big and 1.2 or 0.8, big and 300 or 180, Vector3.new((math.random() - 0.5) * 2, 1, 0))
	task.delay(1.3, function()
		anchor:Destroy()
	end)
end

-- A rip in space: a black void with a pale edge, opening along the swipe and
-- snapping shut. `cf` faces where the swipe went; `width` across, `height` tall.
local function rip(cf, width, height, life)
	life = life or 0.5
	local void = VFXLib.part({ Size = Vector3.new(0.1, height, 0.3), CFrame = cf, Color = VOID, Material = Enum.Material.SmoothPlastic, Transparency = 0 })
	local edgeA = VFXLib.part({ Size = Vector3.new(0.1, height, 0.12), CFrame = cf, Color = EDGE, Transparency = 0.1 })
	local edgeB = VFXLib.part({ Size = Vector3.new(0.1, height, 0.12), CFrame = cf, Color = EDGE, Transparency = 0.1 })
	VFXLib.animate(life, function(a)
		-- Opens fast, hangs, then snaps shut.
		local open = a < 0.25 and VFXLib.easeOut(a / 0.25) or (a < 0.7 and 1 or 1 - (a - 0.7) / 0.3)
		local w = math.max(0.1, width * open)
		void.Size = Vector3.new(w, height * (0.6 + 0.4 * open), 0.3)
		void.CFrame = cf
		edgeA.CFrame = cf * CFrame.new(-w / 2, 0, -0.1)
		edgeB.CFrame = cf * CFrame.new(w / 2, 0, -0.1)
		edgeA.Size = Vector3.new(0.12, void.Size.Y, 0.12)
		edgeB.Size = edgeA.Size
	end, function()
		void:Destroy()
		edgeA:Destroy()
		edgeB:Destroy()
	end)
end

-- The glowing palm sweeping across in front.
local function palmSweep(cf, width)
	local palm = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), Color = EDGE, Transparency = 0.2 })
	local trail = VFXLib.part({ Size = Vector3.new(0.2, 2.4, 0.2), Color = BLUE, Transparency = 0.4 })
	VFXLib.animate(0.18, function(a)
		local x = (0.5 - a) * width
		palm.CFrame = cf * CFrame.new(x, 0.6 - a * 1.2, 0)
		trail.CFrame = cf * CFrame.new(x + width * 0.08, 0.6 - a * 1.2, 0)
		trail.Transparency = 0.4 + 0.6 * a
	end, function()
		palm:Destroy()
		trail:Destroy()
	end)
end

-- A void streak between two points (space erased between them).
local function streak(from, to)
	local len = (to - from).Magnitude
	if len < 0.5 then
		return
	end
	local line = VFXLib.part({ Size = Vector3.new(0.6, 0.6, len), CFrame = CFrame.lookAt((from + to) / 2, to), Color = VOID, Material = Enum.Material.SmoothPlastic, Transparency = 0.1 })
	local glow = VFXLib.part({ Size = Vector3.new(0.9, 0.9, len), CFrame = line.CFrame, Color = EDGE, Transparency = 0.6 })
	VFXLib.animate(0.35, function(a)
		local k = 1 - a
		line.Size = Vector3.new(0.6 * k, 0.6 * k, len)
		glow.Size = Vector3.new(0.9 * k + 0.05, 0.9 * k + 0.05, len)
		glow.Transparency = 0.6 + 0.4 * a
	end, function()
		line:Destroy()
		glow:Destroy()
	end)
end

-- A pale afterimage of someone where they just were.
local function afterimage(character, at)
	if typeof(character) ~= "Instance" then
		return
	end
	local ghost = VFXLib.part({ Size = Vector3.new(2, 5, 1), CFrame = CFrame.new(at), Color = EDGE, Transparency = 0.5 })
	VFXLib.animate(0.4, function(a)
		ghost.Transparency = 0.5 + 0.5 * a
		ghost.Size = Vector3.new(2 * (1 - a * 0.5), 5, 1)
	end, function()
		ghost:Destroy()
	end)
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
	TuskAnimation.play(character, "OK_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1, -3.4), Duration = 0.3 })
	VFXLib.sound(sounds.Swing, root, 0.55, 0.95 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or pal.Second, index == 4 and 1.4 or 1)
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "Erase" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "OKErase")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(1.2, 1.6, -2.4), Duration = (data.Windup or 0.35) + 0.4 })
		elseif phase == "Swipe" and data.CFrame then
			local size = data.Size or Vector3.new(8, 6, 7)
			palmSweep(data.CFrame, size.X)
			rip(data.CFrame * CFrame.Angles(0, 0, math.rad(-20)), size.X * 0.9, size.Y * 0.9, 0.6)
			gaoon(data.CFrame.Position + Vector3.new(0, 2.5, 0), data.Hit)
			VFXLib.sound(sounds.Swing, data.CFrame.Position, 0.8, 0.6)
			if data.Hit then
				CameraFX.shakeAt(data.CFrame.Position, 0.6, 40)
			end
		end
	elseif move == "ErasePull" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "OKPull")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(1.2, 1.6, -2.4), Duration = (data.Windup or 0.3) + 0.4 })
		elseif phase == "Pull" and data.From and data.To then
			afterimage(data.Target, data.From)
			streak(data.From, data.To)
			gaoon(data.To + Vector3.new(0, 2, 0), true)
			if root then
				rip(CFrame.lookAt(root.Position + root.CFrame.LookVector * 2, root.Position + root.CFrame.LookVector * 4), 3, 5, 0.4)
			end
			VFXLib.sound(sounds.Swing, data.To, 0.8, 0.55)
			if typeof(data.Target) == "Instance" and data.Target == (localPlayer and localPlayer.Character) then
				CameraFX.fovPunch(14, 0.35)
			end
		elseif phase == "Miss" and data.From and data.To then
			streak(data.From, data.To)
			gaoon(data.From + Vector3.new(0, 3, 0), false)
		end
	elseif move == "EraseDash" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "OKDash")
		elseif phase == "Step" and data.From and data.To then
			afterimage(character, data.From)
			streak(data.From, data.To)
			rip(CFrame.lookAt(data.From, data.To) * CFrame.new(0, 0, -1.5), 2.5, 5, 0.35)
			gaoon(data.From + Vector3.new(0, 2.5, 0), false)
			if character and Common.isLocal(character) then
				CameraFX.speedLines(0.25, BLUE)
			end
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character and root then
		TuskAnimation.play(character, "OKUlt")
		TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 1.4, -3), Duration = (data.Windup or 0.6) + (data.Swipes or 6) * (data.Gap or 0.24) + 0.2 })
		label(character:FindFirstChild("Head"), "ZA HANDO!", GOLD, 1.8, 320)
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.0)
		if Common.isLocal(character) then
			CameraFX.speedLines((data.Windup or 0.6) + (data.Swipes or 6) * (data.Gap or 0.24), BLUE)
		end
	elseif data.Phase == "Swipe" and data.CFrame then
		local size = data.Size or Vector3.new(14, 7, 14)
		local tilt = (data.Index or 1) % 2 == 0 and 25 or -25
		palmSweep(data.CFrame, size.X * 0.8)
		rip(data.CFrame * CFrame.Angles(0, 0, math.rad(tilt)), size.X * (data.Last and 1.0 or 0.6), size.Y * (data.Last and 1.2 or 0.8), data.Last and 0.9 or 0.45)
		gaoon(data.CFrame.Position + Vector3.new((math.random() - 0.5) * 4, 2.5, 0), data.Last)
		if data.Last then
			TuskVFX.CreateRotationalShockwave(data.CFrame * CFrame.Angles(math.pi / 2, 0, 0), { Radius = 10, Layers = 3, Color = BLUE, Color2 = GOLD, Particles = 1, Width = 0.6 })
			CameraFX.shakeAt(data.CFrame.Position, 1.0, 60)
			if character and Common.isLocal(character) then
				CameraFX.impactFrame(pal.Light)
			end
		else
			CameraFX.shakeAt(data.CFrame.Position, 0.3, 40)
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
				TuskAnimation.hold(character, "OKStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "OKStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function OkuyasuVFX.handle(name, data)
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
function OkuyasuVFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
	end
end

return OkuyasuVFX
end

-- ======================================================================
-- MODULE: TheHandStand
-- ======================================================================
__modules["TheHandStand"] = function()
--[[
	TuskActVFX.TheHandStand  (StarterPlayerScripts.SpinClient.TuskActVFX.TheHandStand)

	THE HAND (Okuyasu Nijimura, Part 4), blocky:
	  * a big, muscular NAVY-BLUE body with paler blue panels and thin gold
	    trim lines
	  * a rounded helmet-like head with a crest down the middle, small fins
	    at the sides and a pale mask face with narrow eyes
	  * heavy shoulders: a gold DOLLAR sign on the left, a gold YEN sign on
	    the right
	  * an oversized RIGHT HAND with a glowing palm (the hand that erases)
	  * a belt with a gold $ buckle; armoured knees
	Registered with TuskStandModels by OkuyasuVFX, so TuskStand floats it
	behind Okuyasu with a blue aura.
]]

local TheHandStand = {}

local BLUE = Color3.fromRGB(64, 92, 168)
local BLUE_DARK = Color3.fromRGB(38, 52, 106)
local BLUE_LIGHT = Color3.fromRGB(130, 164, 226)
local MASK = Color3.fromRGB(214, 226, 244)
local GOLD = Color3.fromRGB(236, 190, 70)
local EYE = Color3.fromRGB(150, 230, 255)
local PALM = Color3.fromRGB(190, 246, 255)

TheHandStand.Aura = Color3.fromRGB(110, 160, 255)
TheHandStand.AuraLight = Color3.fromRGB(210, 230, 255)
TheHandStand.Offset = CFrame.new(2.2, 1.6, 2.8)

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

-- Gold glyphs facing forward (-Z), built from bars (seen from the front,
-- +X is on the viewer's left, so the S of the $ is built mirrored).
local function bar(model, parent, cf, w, h)
	return box(model, parent, "Glyph", Vector3.new(w, h, 0.06), GOLD, cf, Enum.Material.Metal)
end

local function dollar(model, parent, cf, size)
	local t = size * 0.18
	bar(model, parent, cf * CFrame.new(0, size * 0.4, 0), size * 0.6, t)
	bar(model, parent, cf, size * 0.6, t)
	bar(model, parent, cf * CFrame.new(0, -size * 0.4, 0), size * 0.6, t)
	bar(model, parent, cf * CFrame.new(size * 0.25, size * 0.2, 0), t, size * 0.4)
	bar(model, parent, cf * CFrame.new(-size * 0.25, -size * 0.2, 0), t, size * 0.4)
	bar(model, parent, cf * CFrame.new(0, 0, -0.02), t * 0.6, size * 1.2)
end

local function yen(model, parent, cf, size)
	local t = size * 0.18
	for _, side in ipairs({ -1, 1 }) do
		bar(model, parent, cf * CFrame.new(side * size * 0.17, size * 0.28, 0) * CFrame.Angles(0, 0, side * -0.6), t, size * 0.5)
	end
	bar(model, parent, cf * CFrame.new(0, -size * 0.25, 0), t, size * 0.6)
	bar(model, parent, cf * CFrame.new(0, -size * 0.05, -0.01), size * 0.55, t * 0.8)
	bar(model, parent, cf * CFrame.new(0, -size * 0.28, -0.01), size * 0.55, t * 0.8)
end

function TheHandStand.build(scale)
	local s = (scale or 1) * 0.9
	local model = Instance.new("Model")
	model.Name = "TheHand"
	local rig = { Joints = {} }

	local torso = newPart(model, "Body", Vector3.new(2.4, 1.9, 1.15) * s, BLUE)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.58 * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Pec", Vector3.new(1.0, 0.65, 0.14) * s, BLUE_LIGHT, CFrame.new(side * 0.52 * s, 0.4 * s, front - 0.04 * s))
		box(model, torso, "PecTrim", Vector3.new(1.0, 0.05, 0.15) * s, GOLD, CFrame.new(side * 0.52 * s, 0.06 * s, front - 0.045 * s), Enum.Material.Metal)
		box(model, torso, "Lat", Vector3.new(0.2, 1.3, 0.9) * s, BLUE_DARK, CFrame.new(side * 1.2 * s, -0.1 * s, 0))
	end
	box(model, torso, "Sternum", Vector3.new(0.08, 0.65, 0.15) * s, BLUE_DARK, CFrame.new(0, 0.4 * s, front - 0.05 * s))
	box(model, torso, "Waist", Vector3.new(1.75, 0.85, 0.95) * s, BLUE, CFrame.new(0, -1.3 * s, 0))
	for k = 0, 2 do
		for _, side in ipairs({ -1, 1 }) do
			box(model, torso, "Ab", Vector3.new(0.38, 0.24, 0.08) * s, BLUE_LIGHT, CFrame.new(side * 0.22 * s, (-0.22 - k * 0.32) * s, front - 0.02 * s))
		end
	end
	box(model, torso, "Belt", Vector3.new(1.85, 0.3, 1.05) * s, BLUE_DARK, CFrame.new(0, -1.7 * s, 0))
	box(model, torso, "BeltTrim", Vector3.new(1.87, 0.05, 1.07) * s, GOLD, CFrame.new(0, -1.58 * s, 0), Enum.Material.Metal)
	box(model, torso, "Buckle", Vector3.new(0.5, 0.4, 0.06) * s, BLUE_DARK, CFrame.new(0, -1.7 * s, -0.55 * s))
	dollar(model, torso, CFrame.new(0, -1.7 * s, -0.6 * s), 0.34 * s)
	box(model, torso, "Hips", Vector3.new(1.75, 0.5, 0.95) * s, BLUE_DARK, CFrame.new(0, -2.0 * s, 0))
	box(model, torso, "Neck", Vector3.new(0.65, 0.45, 0.6) * s, BLUE_DARK, CFrame.new(0, 1.12 * s, 0))

	-- Heavy shoulders: $ on the left, yen on the right.
	for _, side in ipairs({ -1, 1 }) do
		local cf = CFrame.new(side * 1.45 * s, 0.82 * s, 0) * CFrame.Angles(0, 0, side * -0.3)
		box(model, torso, "Pauldron", Vector3.new(1.0, 0.6, 1.1) * s, BLUE_LIGHT, cf)
		box(model, torso, "PauldronTrim", Vector3.new(1.02, 0.06, 1.12) * s, GOLD, cf * CFrame.new(0, -0.3 * s, 0), Enum.Material.Metal)
		local face = cf * CFrame.new(0, 0, -0.57 * s)
		if side == -1 then
			dollar(model, torso, face, 0.42 * s)
		else
			yen(model, torso, face, 0.42 * s)
		end
	end

	-- A rounded helmet-like head: a crest, side fins, a pale mask face.
	local headBase = CFrame.new(0, 1.3 * s, 0)
	local headOffset = CFrame.new(0, 0.52 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.82, 0.98, 0.86) * s, BLUE, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.43 * s
	box(model, head, "Mask", Vector3.new(0.62, 0.6, 0.08) * s, MASK, CFrame.new(0, -0.08 * s, hf - 0.02 * s))
	box(model, head, "Crest", Vector3.new(0.12, 0.35, 0.95) * s, BLUE_DARK, CFrame.new(0, 0.55 * s, 0.02 * s))
	box(model, head, "CrestTrim", Vector3.new(0.13, 0.05, 0.96) * s, GOLD, CFrame.new(0, 0.71 * s, 0.02 * s), Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Fin", Vector3.new(0.1, 0.4, 0.4) * s, BLUE_LIGHT, CFrame.new(side * 0.46 * s, 0.1 * s, 0.05 * s) * CFrame.Angles(0, 0, side * -0.2))
		box(model, head, "Eye", Vector3.new(0.18, 0.05, 0.05) * s, EYE, CFrame.new(side * 0.15 * s, 0.05 * s, hf - 0.07 * s) * CFrame.Angles(0, 0, side * -0.15), Enum.Material.Neon)
		box(model, head, "FaceLine", Vector3.new(0.03, 0.3, 0.05) * s, BLUE_DARK, CFrame.new(side * 0.2 * s, -0.22 * s, hf - 0.065 * s))
	end
	box(model, head, "Mouth", Vector3.new(0.2, 0.04, 0.05) * s, BLUE_DARK, CFrame.new(0, -0.27 * s, hf - 0.065 * s))

	-- Arms; the RIGHT hand is oversized, its palm glowing.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.55 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.72, 2.2, 0.72) * s, BLUE, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Bicep", Vector3.new(0.84, 0.7, 0.84) * s, BLUE_LIGHT, CFrame.new(0, 0.42 * s, -0.03 * s))
		box(model, arm, "Forearm", Vector3.new(0.86, 0.8, 0.86) * s, BLUE_DARK, CFrame.new(0, -0.55 * s, 0))
		box(model, arm, "Cuff", Vector3.new(0.9, 0.08, 0.9) * s, GOLD, CFrame.new(0, -0.95 * s, 0), Enum.Material.Metal)
		if a[1] == "ArmR" then
			local hand = box(model, arm, "Hand", Vector3.new(1.0, 0.85, 0.5) * s, BLUE_LIGHT, CFrame.new(0, -1.45 * s, -0.1 * s))
			for f = -1.5, 1.5 do
				box(model, hand, "Finger", Vector3.new(0.2, 0.45, 0.22) * s, BLUE_LIGHT, CFrame.new(f * 0.24 * s, -0.58 * s, 0))
			end
			box(model, hand, "Thumb", Vector3.new(0.2, 0.4, 0.22) * s, BLUE_LIGHT, CFrame.new(-0.58 * s, -0.05 * s, -0.05 * s) * CFrame.Angles(0, 0, 0.5))
			local palm = box(model, hand, "Palm", Vector3.new(0.06, 0.6, 0.6) * s, PALM, CFrame.new(0, -0.05 * s, -0.27 * s) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Neon)
			palm.Shape = Enum.PartType.Cylinder
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.05 * s, -0.3 * s)
			point.Parent = hand
			rig.NailPoint = point
		else
			local hand = box(model, arm, "Hand", Vector3.new(0.68, 0.6, 0.62) * s, BLUE_LIGHT, CFrame.new(0, -1.3 * s, 0))
			for f = -1.5, 1.5 do
				box(model, hand, "Finger", Vector3.new(0.13, 0.36, 0.14) * s, BLUE_LIGHT, CFrame.new(f * 0.15 * s, -0.38 * s, -0.08 * s))
			end
		end
	end

	-- Legs with armoured knees.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.5 * s, -2.15 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.76, 2.4, 0.76) * s, BLUE, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Thigh", Vector3.new(0.86, 0.95, 0.86) * s, BLUE_LIGHT, CFrame.new(0, 0.65 * s, 0))
		box(model, leg, "KneePad", Vector3.new(0.6, 0.42, 0.2) * s, BLUE_DARK, CFrame.new(0, 0.02 * s, -0.42 * s))
		box(model, leg, "KneeTrim", Vector3.new(0.62, 0.05, 0.21) * s, GOLD, CFrame.new(0, 0.22 * s, -0.42 * s), Enum.Material.Metal)
		box(model, leg, "Shin", Vector3.new(0.8, 0.7, 0.82) * s, BLUE_DARK, CFrame.new(0, -0.6 * s, 0))
		box(model, leg, "Foot", Vector3.new(0.72, 0.32, 1.05) * s, BLUE_DARK, CFrame.new(0, -1.3 * s, -0.17 * s))
	end
	return model, rig
end

return TheHandStand
end
end
