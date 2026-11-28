--[[
	Giorno_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Giorno Giovanna (Part 5): Gold Experience, and Gold Experience Requiem from the Requiem Arrow.
	Its other half is Giorno_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "giorno" or __expect.Side ~= "client") then
		error("this is the code for Giorno_Client, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Giorno_Client and put it in ReplicatedStorage > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: GERStand
-- ======================================================================
__modules["GERStand"] = function()
--[[
	TuskActVFX.GERStand  (StarterPlayerScripts.SpinClient.TuskActVFX.GERStand)

	GOLD EXPERIENCE REQUIEM (Giorno Giovanna, Part 5), blocky, matched to
	the art: brighter and grander than Gold Experience:
	  * a tall golden HELMET with two great swept-back CRESTS, round
	    orange-red SPOTS down its sides, and a big red DISC on each cheek
	  * a PURPLE face with orange dots, narrow glowing eyes, and THE
	    REQUIEM ARROW's head stuck in its forehead, its beetle EYE staring out
	  * a high golden collar; a golden body dotted with orange spots
	  * huge angular shoulder wings, a belt with silver straps and a purple
	    buckle, purple joints; a faint violet starry shimmer round it
	Registered with TuskStandModels by GERVFX, so TuskStand floats it with a
	gold-and-violet aura.
]]

local GERStand = {}

local GOLD = Color3.fromRGB(250, 220, 110)
local GOLD_LIGHT = Color3.fromRGB(255, 240, 170)
local GOLD_SHADE = Color3.fromRGB(214, 170, 70)
local SPOT = Color3.fromRGB(236, 96, 60)
local SPOT_LIGHT = Color3.fromRGB(255, 150, 90)
local PURPLE = Color3.fromRGB(150, 80, 220)
local PURPLE_DARK = Color3.fromRGB(96, 46, 150)
local FACE = Color3.fromRGB(176, 110, 210)
local SILVER = Color3.fromRGB(220, 224, 236)
local SILVER_SHADE = Color3.fromRGB(176, 182, 204)
local EYE = Color3.fromRGB(255, 250, 220)
local ARROW = Color3.fromRGB(226, 186, 90)
local BEETLE = Color3.fromRGB(250, 200, 220)

GERStand.Aura = Color3.fromRGB(255, 220, 110)
GERStand.AuraLight = Color3.fromRGB(220, 190, 255)
GERStand.Offset = CFrame.new(2.2, 1.7, 2.8)

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

local function egg(model, parent, name, size, color, cf, material)
	local p, w = box(model, parent, name, size, color, cf, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p, w
end

local function cyl(model, parent, name, length, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(length, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A round flat spot (disc) facing out along -Z of `cf`.
local function spot(model, parent, cf, d, color)
	return cyl(model, parent, "Spot", 0.05 * d / 0.2, d, color, cf * CFrame.Angles(0, math.pi / 2, 0))
end

function GERStand.build(scale)
	local s = (scale or 1) * 0.92
	local model = Instance.new("Model")
	model.Name = "GoldExperienceRequiem"
	local rig = { Joints = {} }

	local torso = newPart(model, "Body", Vector3.new(2.0, 1.9, 1.05) * s, GOLD)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.53 * s
	-- A high golden collar rising round the neck.
	box(model, torso, "Collar", Vector3.new(1.3, 0.55, 1.0) * s, GOLD_LIGHT, CFrame.new(0, 1.0 * s, 0.05 * s))
	box(model, torso, "CollarRim", Vector3.new(1.34, 0.08, 1.04) * s, GOLD_SHADE, CFrame.new(0, 1.26 * s, 0.05 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "CollarFlare", Vector3.new(0.12, 0.7, 0.8) * s, GOLD_LIGHT, CFrame.new(side * 0.68 * s, 1.15 * s, 0.1 * s) * CFrame.Angles(0, 0, side * -0.35))
		box(model, torso, "Pec", Vector3.new(0.9, 0.7, 0.14) * s, GOLD_LIGHT, CFrame.new(side * 0.48 * s, 0.38 * s, front - 0.04 * s) * CFrame.Angles(0, side * 0.12, 0))
		-- Orange-red spots on the chest and flanks.
		spot(model, torso, CFrame.new(side * 0.5 * s, 0.4 * s, front - 0.12 * s), 0.34 * s, SPOT)
		spot(model, torso, CFrame.new(side * 0.5 * s, 0.4 * s, front - 0.14 * s), 0.18 * s, SPOT_LIGHT)
		spot(model, torso, CFrame.new(side * 0.72 * s, -0.35 * s, front - 0.02 * s), 0.18 * s, SPOT)
		for k = 0, 2 do
			box(model, torso, "Rib", Vector3.new(0.45, 0.06, 0.06) * s, GOLD_SHADE, CFrame.new(side * 0.42 * s, -0.12 * s - k * 0.18 * s, front - 0.02 * s) * CFrame.Angles(0, 0, side * 0.25))
		end
	end
	box(model, torso, "Sternum", Vector3.new(0.1, 1.2, 0.1) * s, PURPLE, CFrame.new(0, 0.1 * s, front - 0.04 * s))
	box(model, torso, "Waist", Vector3.new(1.35, 0.9, 0.85) * s, GOLD, CFrame.new(0, -1.35 * s, 0))
	for k = 0, 2 do
		box(model, torso, "Abs", Vector3.new(0.6, 0.05, 0.06) * s, GOLD_SHADE, CFrame.new(0, -1.05 * s - k * 0.22 * s, -0.44 * s))
	end
	box(model, torso, "Belt", Vector3.new(1.5, 0.22, 0.92) * s, GOLD_SHADE, CFrame.new(0, -1.82 * s, 0))
	for k = 0, 2 do
		for _, side in ipairs({ -1, 1 }) do
			box(model, torso, "Strap", Vector3.new(0.72, 0.07, 0.07) * s, k % 2 == 0 and SILVER or SILVER_SHADE, CFrame.new(side * 0.37 * s, -1.95 * s - k * 0.14 * s, -0.5 * s - k * 0.03 * s) * CFrame.Angles(0, 0, side * (0.18 + k * 0.08)))
		end
	end
	egg(model, torso, "Buckle", Vector3.new(0.5, 0.5, 0.3) * s, PURPLE, CFrame.new(-0.74 * s, -1.9 * s, -0.2 * s))
	box(model, torso, "Hips", Vector3.new(1.4, 0.5, 0.88) * s, GOLD_SHADE, CFrame.new(0, -2.1 * s, 0))

	-- Huge angular shoulder wings.
	for _, side in ipairs({ -1, 1 }) do
		local cf = CFrame.new(side * 1.2 * s, 0.9 * s, 0.05 * s) * CFrame.Angles(0, 0, side * -0.3)
		egg(model, torso, "ShoulderPad", Vector3.new(0.9, 0.6, 0.9) * s, GOLD_LIGHT, cf)
		spot(model, torso, cf * CFrame.new(side * 0.46 * s, 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0), 0.26 * s, SPOT)
		for k = 0, 3 do
			box(model, torso, "Wing", Vector3.new(0.12, 1.25 - k * 0.22, 0.42 - k * 0.07) * s, k % 2 == 1 and SILVER_SHADE or SILVER, cf * CFrame.new(side * (0.22 + k * 0.13) * s, (0.7 + k * 0.12) * s, (0.04 + k * 0.04) * s) * CFrame.Angles(math.rad(-8), 0, side * (-0.4 - k * 0.15)))
		end
	end

	-- The head: tall golden helmet, swept-back crests, red discs, a purple
	-- face, and the arrow in its forehead.
	local hs = s * 1.22
	local headBase = CFrame.new(0, 1.3 * s, 0)
	local headOffset = CFrame.new(0, 0.62 * hs, 0)
	local head, headWeld = egg(model, torso, "Head", Vector3.new(0.9, 1.2, 0.95) * hs, GOLD, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.47 * hs
	egg(model, head, "Dome", Vector3.new(0.98, 0.75, 1.05) * hs, GOLD_LIGHT, CFrame.new(0, 0.3 * hs, 0.06 * hs))
	-- Two great crests sweeping back off the helmet.
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			box(model, head, "Crest", Vector3.new(0.12, 0.3 - k * 0.06, 0.8 - k * 0.15) * hs, k == 1 and GOLD_SHADE or GOLD_LIGHT, CFrame.new(side * 0.26 * hs, (0.6 + k * 0.16) * hs, (0.35 + k * 0.32) * hs) * CFrame.Angles(math.rad(35 + k * 12), side * 0.12, 0))
		end
		box(model, head, "CrestTip", Vector3.new(0.08, 0.12, 0.4) * hs, GOLD_SHADE, CFrame.new(side * 0.26 * hs, 1.08 * hs, 1.18 * hs) * CFrame.Angles(math.rad(60), side * 0.12, 0))
		-- Orange spots in a line down the helmet's side, a big red disc on the cheek.
		for k = 0, 3 do
			spot(model, head, CFrame.new(side * 0.47 * hs, (0.4 - k * 0.15) * hs, (0.25 - k * 0.04) * hs) * CFrame.Angles(0, side * -math.pi / 2, 0), 0.1 * hs, SPOT_LIGHT)
		end
		spot(model, head, CFrame.new(side * 0.43 * hs, -0.12 * hs, -0.1 * hs) * CFrame.Angles(0, side * -1.2, 0), 0.36 * hs, SPOT)
		spot(model, head, CFrame.new(side * 0.44 * hs, -0.12 * hs, -0.11 * hs) * CFrame.Angles(0, side * -1.2, 0), 0.2 * hs, SPOT_LIGHT)
	end
	-- The purple face, orange dots, narrow glowing eyes.
	egg(model, head, "Face", Vector3.new(0.6, 0.75, 0.12) * hs, FACE, CFrame.new(0, -0.12 * hs, hf + 0.04 * hs))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.2, 0.06, 0.04) * hs, EYE, CFrame.new(side * 0.14 * hs, 0.02 * hs, hf - 0.03 * hs) * CFrame.Angles(0, 0, side * -0.15), Enum.Material.Neon)
		ball(model, head, "FaceDot", 0.07 * hs, SPOT_LIGHT, CFrame.new(side * 0.17 * hs, -0.24 * hs, hf - 0.02 * hs))
		ball(model, head, "FaceDot", 0.05 * hs, SPOT_LIGHT, CFrame.new(side * 0.12 * hs, -0.36 * hs, hf - 0.01 * hs))
	end
	box(model, head, "Mouth", Vector3.new(0.16, 0.035, 0.04) * hs, PURPLE_DARK, CFrame.new(0, -0.32 * hs, hf - 0.01 * hs))
	-- The Requiem Arrow's head, stuck in the forehead, its beetle eye open.
	local arrowAt = CFrame.new(0.12 * hs, 0.3 * hs, hf - 0.06 * hs) * CFrame.Angles(0, 0, math.rad(-20))
	box(model, head, "ArrowHead", Vector3.new(0.3, 0.3, 0.08) * hs, ARROW, arrowAt * CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Metal)
	box(model, head, "ArrowShaft", Vector3.new(0.06, 0.22, 0.06) * hs, ARROW, arrowAt * CFrame.new(0, -0.24 * hs, 0.02 * hs), Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "ArrowWing", Vector3.new(0.18, 0.06, 0.06) * hs, ARROW, arrowAt * CFrame.new(side * 0.14 * hs, -0.04 * hs, 0) * CFrame.Angles(0, 0, side * -0.6), Enum.Material.Metal)
	end
	egg(model, head, "BeetleEye", Vector3.new(0.18, 0.12, 0.05) * hs, BEETLE, arrowAt * CFrame.new(0, 0.02 * hs, -0.05 * hs))
	ball(model, head, "BeetlePupil", 0.07 * hs, PURPLE_DARK, arrowAt * CFrame.new(0, 0.02 * hs, -0.08 * hs))

	-- Arms: golden, purple joints, spots on the forearms.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.28 * s, 0.45 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.55, 2.2, 0.55) * s, GOLD, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Bicep", Vector3.new(0.64, 0.75, 0.64) * s, GOLD_LIGHT, CFrame.new(0, 0.52 * s, -0.02 * s))
		ball(model, arm, "Elbow", 0.46 * s, PURPLE, CFrame.new(0, 0, 0))
		box(model, arm, "Forearm", Vector3.new(0.62, 0.75, 0.62) * s, GOLD, CFrame.new(0, -0.52 * s, 0))
		spot(model, arm, CFrame.new(0, -0.5 * s, -0.32 * s), 0.18 * s, SPOT)
		box(model, arm, "Wrist", Vector3.new(0.66, 0.16, 0.66) * s, PURPLE, CFrame.new(0, -0.95 * s, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.52, 0.5, 0.45) * s, GOLD_LIGHT, CFrame.new(0, -1.25 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.1, 0.28, 0.1) * s, GOLD, CFrame.new(f * 0.12 * s, -0.32 * s, -0.06 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.25 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.45 * s, -2.25 * s, 0)
		local offset = CFrame.new(0, -1.25 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.6, 2.5, 0.6) * s, GOLD, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Thigh", Vector3.new(0.7, 1.0, 0.7) * s, GOLD_LIGHT, CFrame.new(0, 0.65 * s, 0))
		spot(model, leg, CFrame.new(0, 0.65 * s, -0.36 * s), 0.2 * s, SPOT)
		ball(model, leg, "Knee", 0.5 * s, PURPLE, CFrame.new(0, 0, -0.1 * s))
		box(model, leg, "Shin", Vector3.new(0.64, 0.9, 0.64) * s, GOLD_SHADE, CFrame.new(0, -0.62 * s, 0))
		box(model, leg, "Ankle", Vector3.new(0.68, 0.14, 0.68) * s, PURPLE, CFrame.new(0, -1.1 * s, 0))
		box(model, leg, "Foot", Vector3.new(0.6, 0.32, 0.95) * s, GOLD_SHADE, CFrame.new(0, -1.35 * s, -0.17 * s))
	end
	return model, rig
end

return GERStand
end

-- ======================================================================
-- MODULE: GERVFX
-- ======================================================================
__modules["GERVFX"] = function()
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
local Cutscenes = __require("Cutscenes")
local Cinematic = __require("Cinematic")
local GERStand = __require("GERStand")
local GiornoVFX = __require("GiornoVFX")

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
end

-- ======================================================================
-- MODULE: GiornoVFX
-- ======================================================================
__modules["GiornoVFX"] = function()
--[[
	TuskActVFX.GiornoVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.GiornoVFX)

	Client visuals for Giorno Giovanna / GOLD EXPERIENCE. Blocky.
	  * Gold Experience (GoldExperienceStand) floats behind him with a gold
	    aura; Giorno stands with his hand at his chin, hip cocked
	  * MUDA COMBO: Gold Experience's golden fists fly out with him; "MUDA!"
	    on the 4th
	  * MUDA MUDA RUSH: a blur of golden fists, "MUDA MUDA" spilling out,
	    then one huge "MUDA!" and a burst of leaves
	  * LIFE GIVER: TREE: he punches the ground; green roots race along it,
	    and a tree bursts up (trunk, branches, a leafy crown, flowers), stays
	    a moment, then sinks back into the ground
	  * SENSE OVERLOAD: a golden punch; the target glows, leaves slow
	    afterimages as they crawl ("TOO SLOW..."), then the pain lands
	    all at once ("!!!")
	  * LIFE BURST: a ring of trees bursts up round him, vines coil up
	    everyone caught, snakes bite them, golden life sparkles flow into
	    Giorno; then the trees burst and throw them
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
local GoldExperienceStand = __require("GoldExperienceStand")

local GiornoVFX = {}
local ACT = 30
local REQUIEM_ACT = 31
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, GoldExperienceStand.build, { Aura = GoldExperienceStand.Aura, AuraLight = GoldExperienceStand.AuraLight, Offset = GoldExperienceStand.Offset })

local GOLD = Color3.fromRGB(255, 214, 90)
local GOLD_LIGHT = Color3.fromRGB(255, 244, 190)
local FIST = Color3.fromRGB(240, 206, 120)
local PURPLE = Color3.fromRGB(170, 90, 220)
local BARK = Color3.fromRGB(120, 84, 52)
local BARK_DARK = Color3.fromRGB(86, 58, 36)
local LEAF = Color3.fromRGB(90, 190, 80)
local LEAF_DARK = Color3.fromRGB(56, 140, 60)
local FLOWER = Color3.fromRGB(255, 130, 180)
local SNAKE = Color3.fromRGB(110, 170, 70)

local stanced = {}
local rushes = {} -- [character] = token
local overloads = {} -- [target] = token
local jungles = {} -- [character] = { parts }

---------------------------------------------------------------------------
-- Pieces (shared with GERVFX through GiornoVFX.Pieces)
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

-- "MUDA" text popping out at a world spot.
local function muda(at, big, color)
	local anchor = VFXLib.part({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(at), Transparency = 1 })
	label(anchor, big and "MUDA!" or "MUDA", color or (big and GOLD or GOLD_LIGHT), big and 1.0 or 0.5, big and 280 or 130, Vector3.new((math.random() - 0.5) * 3, math.random() * 2, 0))
	task.delay(1.1, function()
		anchor:Destroy()
	end)
end

-- One golden fist flying forward from `from` along `dir`, then fading.
local function fist(from, dir, size, color, trailColor)
	size = size or 1
	local f = VFXLib.part({ Size = Vector3.new(0.75, 0.7, 0.85) * size, Color = color or FIST, Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
	local band = VFXLib.part({ Size = Vector3.new(0.78, 0.16, 0.3) * size, Color = PURPLE, Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
	local trail = VFXLib.part({ Size = Vector3.new(0.4, 0.4, 2.2) * size, Color = trailColor or GOLD, Transparency = 0.5 })
	VFXLib.animate(0.16, function(a)
		local p = from + dir * (a * 3.2)
		local cf = CFrame.lookAt(p, p + dir)
		f.CFrame = cf
		band.CFrame = cf * CFrame.new(0, 0, 0.45 * size)
		trail.CFrame = cf * CFrame.new(0, 0, 1.3 * size)
		local t = a < 0.6 and 0.15 or 0.15 + (a - 0.6) / 0.4 * 0.85
		f.Transparency = t
		band.Transparency = t
		trail.Transparency = 0.5 + 0.5 * a
	end, function()
		f:Destroy()
		band:Destroy()
		trail:Destroy()
	end)
end

-- Leaves (and a few petals) bursting out from a point.
local function leaves(at, count, speed)
	for _ = 1, count do
		local leaf = VFXLib.part({ Size = Vector3.new(0.35, 0.05, 0.25), Color = math.random() < 0.15 and FLOWER or (math.random() < 0.5 and LEAF or LEAF_DARK), CFrame = CFrame.new(at) })
		local v = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit * (speed or 10) * (0.5 + math.random() * 0.5)
		local spin = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
		local life = 0.7 + math.random() * 0.5
		VFXLib.animate(life, function(a)
			local t = a * life
			leaf.CFrame = CFrame.new(at + v * t + Vector3.new(0, -8 * t * t, 0)) * CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t)
			leaf.Transparency = math.max(0, a * 1.5 - 0.5)
		end, function()
			leaf:Destroy()
		end)
	end
end

-- Golden life sparkles drifting from `from` into `to`.
local function lifeFlow(from, to, count, color)
	for k = 1, count do
		local start = from + Vector3.new((math.random() - 0.5) * 2, math.random() * 2, (math.random() - 0.5) * 2)
		local sp = VFXLib.part({ Size = Vector3.new(0.25, 0.25, 0.25), Color = color or GOLD, Material = Enum.Material.Neon, Transparency = 0.1, CFrame = CFrame.new(start) })
		local life = 0.45 + k * 0.02
		VFXLib.animate(life, function(a)
			local p = start:Lerp(to, VFXLib.easeInOut(a)) + Vector3.new(0, math.sin(a * math.pi) * 2, 0)
			sp.CFrame = CFrame.new(p) * CFrame.Angles(a * 6, a * 4, 0)
			sp.Transparency = 0.1 + 0.9 * a * a
		end, function()
			sp:Destroy()
		end)
	end
end

-- Roots racing along the ground from `from` to `to` over `time`.
local function roots(from, to, time)
	local dir = to - from
	local len = dir.Magnitude
	if len < 0.5 then
		return
	end
	local segs = math.clamp(math.floor(len / 1.6), 3, 30)
	local parts = {}
	for i = 1, segs do
		local a0 = (i - 1) / segs
		local a1 = i / segs
		local wob = Vector3.new(math.sin(i * 1.7), 0, math.cos(i * 1.3)) * 0.5
		local p0 = from + dir * a0 + wob
		local p1 = from + dir * a1 + Vector3.new(math.sin((i + 1) * 1.7), 0, math.cos((i + 1) * 1.3)) * 0.5
		local seg = VFXLib.part({ Size = Vector3.new(0.35, 0.35, (p1 - p0).Magnitude + 0.2), Color = i % 2 == 0 and BARK or LEAF_DARK, CFrame = CFrame.lookAt((p0 + p1) / 2, p1), Transparency = 1 })
		table.insert(parts, seg)
		task.delay(a0 * time, function()
			if seg.Parent then
				seg.Transparency = 0
				VFXLib.burst(p0 + Vector3.new(0, 0.3, 0), { Count = 2, Color = LEAF, Speed = 4, Lifetime = 0.3 })
			end
		end)
	end
	task.delay(time + 0.8, function()
		for _, seg in ipairs(parts) do
			if seg.Parent then
				VFXLib.animate(0.4, function(a)
					seg.Transparency = a
				end, function()
					seg:Destroy()
				end)
			end
		end
	end)
end

-- A tree bursting up at `at`: trunk, branches, a leafy crown, flowers.
-- Stands for `life` seconds, then sinks back into the ground.
local function growTree(at, height, life)
	height = height or 9
	local parts = {}
	local function add(p, base)
		table.insert(parts, { Part = p, Base = base })
		return p
	end
	local trunk = add(VFXLib.part({ Size = Vector3.new(1.3, height, 1.3), Color = BARK }), CFrame.new(0, height / 2, 0))
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(height, 1.3, 1.3)
	parts[1].Base = CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	for k = 0, 3 do
		local yaw = k / 4 * math.pi * 2 + 0.4
		local b = add(VFXLib.part({ Size = Vector3.new(0.45, 0.45, 3.2), Color = BARK_DARK }), CFrame.new(0, height * (0.55 + k * 0.08), 0) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, 0, -1.4))
		b.Material = Enum.Material.Wood
	end
	for k = 0, 6 do
		local yaw = k / 7 * math.pi * 2
		local r = k == 0 and 0 or 2.2
		local d = k == 0 and 4.4 or 3.2
		local leafBall = add(VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), Color = k % 2 == 0 and LEAF or LEAF_DARK, Material = Enum.Material.Grass }), CFrame.new(math.cos(yaw) * r, height + (k == 0 and 1.2 or 0.2), math.sin(yaw) * r))
		leafBall.Shape = Enum.PartType.Ball
	end
	for k = 0, 7 do
		local yaw = k / 8 * math.pi * 2 + 0.2
		add(VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), Color = k % 3 == 0 and GOLD_LIGHT or FLOWER, Material = Enum.Material.Neon }), CFrame.new(math.cos(yaw) * 3.0, height + 0.5 + math.sin(k) * 0.8, math.sin(yaw) * 3.0))
	end
	local origin = CFrame.new(at) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local function place(grow)
		for _, e in ipairs(parts) do
			if e.Part.Parent then
				e.Part.CFrame = origin * CFrame.new(0, -height * (1 - grow), 0) * e.Base
			end
		end
	end
	place(0)
	VFXLib.animate(0.25, function(a)
		place(VFXLib.easeOut(a))
	end)
	leaves(at + Vector3.new(0, height * 0.8, 0), 18, 14)
	task.delay(life or 4, function()
		VFXLib.animate(0.6, function(a)
			place(1 - VFXLib.easeInOut(a))
			for _, e in ipairs(parts) do
				if e.Part.Parent then
					e.Part.Transparency = a * 0.6
				end
			end
		end, function()
			for _, e in ipairs(parts) do
				e.Part:Destroy()
			end
		end)
	end)
	return parts
end

-- Vines coiling up round someone for `time` seconds.
local function vinesOn(target, time, color)
	local tr = typeof(target) == "Instance" and target:FindFirstChild("HumanoidRootPart")
	if not tr then
		return {}
	end
	local coil = {}
	local turns = 14
	for k = 1, turns do
		local seg = VFXLib.part({ Size = Vector3.new(0.3, 0.3, 1.6), Color = k % 3 == 0 and FLOWER or (color or LEAF_DARK), Transparency = 1 })
		table.insert(coil, seg)
	end
	VFXLib.animate(time, function(a)
		if not tr.Parent then
			return
		end
		local grow = math.min(1, a * time / 0.35)
		local fade = a > 0.9 and (a - 0.9) / 0.1 or 0
		for k, seg in ipairs(coil) do
			local f = (k - 1) / turns
			if f <= grow then
				local ang = f * math.pi * 6 + os.clock() * 0.5
				local y = -2.8 + f * 4.6
				local r = 1.3 - f * 0.25
				seg.CFrame = CFrame.new(tr.Position + Vector3.new(math.cos(ang) * r, y, math.sin(ang) * r)) * CFrame.Angles(0, -ang, 0) * CFrame.Angles(0.5, 0, 0)
				seg.Transparency = fade
			else
				seg.Transparency = 1
			end
		end
	end, function()
		for _, seg in ipairs(coil) do
			seg:Destroy()
		end
	end)
	return coil
end

-- A snake rising up next to someone and lunging at them.
local function snakeBite(target)
	local tr = typeof(target) == "Instance" and target:FindFirstChild("HumanoidRootPart")
	if not tr then
		return
	end
	local side = math.random() * math.pi * 2
	local base = tr.Position + Vector3.new(math.cos(side) * 2.4, -2.6, math.sin(side) * 2.4)
	local body = {}
	for k = 1, 7 do
		local p = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5) * (1 - k * 0.05), Color = k % 2 == 0 and SNAKE or LEAF_DARK, CFrame = CFrame.new(base) })
		p.Shape = Enum.PartType.Ball
		table.insert(body, p)
	end
	local head = VFXLib.part({ Size = Vector3.new(0.55, 0.35, 0.8), Color = SNAKE, CFrame = CFrame.new(base) })
	VFXLib.animate(0.35, function(a)
		if not tr.Parent then
			return
		end
		local strike = a < 0.6 and a / 0.6 * 0.5 or 0.5 + (a - 0.6) / 0.4 * 0.5
		local tip = base:Lerp(tr.Position + Vector3.new(0, 0.4, 0), strike) + Vector3.new(0, math.sin(strike * math.pi) * 1.2, 0)
		for k, p in ipairs(body) do
			local f = (k - 1) / #body
			p.CFrame = CFrame.new(base:Lerp(tip, 1 - f) + Vector3.new(math.sin(f * 6 + a * 10) * 0.3, 0, 0))
		end
		head.CFrame = CFrame.lookAt(tip, tr.Position)
	end, function()
		for _, p in ipairs(body) do
			p:Destroy()
		end
		head:Destroy()
		VFXLib.burst(tr.Position + Vector3.new(0, 0.5, 0), { Count = 5, Color = Color3.fromRGB(200, 40, 50), Speed = 6, Lifetime = 0.3 })
	end)
end

GiornoVFX.Pieces = { label = label, muda = muda, fist = fist, leaves = leaves, lifeFlow = lifeFlow, growTree = growTree, vinesOn = vinesOn }

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
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.6 or 0.6, 0.8, -3.2), Duration = 0.26 })
	VFXLib.sound(sounds.Swing, root, 0.45, 1.15 + index * 0.05)
	fist((root.CFrame * CFrame.new(index % 2 == 0 and -0.6 or 0.6, 0.8, -1.8)).Position, root.CFrame.LookVector, index == 4 and 1.5 or 1)
	if index == 4 then
		muda((root.CFrame * CFrame.new(0, 2, -3)).Position, true)
	end
end

local function rush(character, duration)
	local token = {}
	rushes[character] = token
	TuskAnimation.play(character, "GIRush")
	TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 0.8, -3.6), Duration = duration })
	local start = os.clock()
	local nextFist, nextMuda = 0, 0
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
		if t >= nextMuda then
			nextMuda = t + 0.16
			muda((root.CFrame * CFrame.new((math.random() - 0.5) * 4, 2 + math.random(), -3)).Position, false)
		end
	end, function()
		if rushes[character] == token then
			rushes[character] = nil
		end
	end)
	if Common.isLocal(character) then
		CameraFX.speedLines(duration, GOLD)
	end
end

local function overloadGlow(target, time)
	local token = {}
	overloads[target] = token
	local tr = target:FindFirstChild("HumanoidRootPart")
	local hl = Instance.new("Highlight")
	hl.FillColor = GOLD
	hl.OutlineColor = GOLD_LIGHT
	hl.FillTransparency = 0.7
	hl.Adornee = target
	hl.Parent = VFXLib.Folder
	label(target:FindFirstChild("Head"), "TOO... SLOW...", GOLD_LIGHT, 1.6, 220, Vector3.new(0, 3.4, 0))
	local nextGhost = 0
	VFXLib.animate(time, function(a)
		if overloads[target] ~= token or not tr or not tr.Parent then
			return
		end
		hl.FillTransparency = 0.6 + math.sin(os.clock() * 12) * 0.15
		-- Slow golden afterimages of them as they crawl.
		local now = os.clock()
		if now >= nextGhost then
			nextGhost = now + 0.18
			local g = VFXLib.part({ Size = Vector3.new(2, 4.6, 1), CFrame = tr.CFrame, Color = GOLD, Transparency = 0.6 })
			VFXLib.animate(0.6, function(b)
				g.Transparency = 0.6 + 0.4 * b
			end, function()
				g:Destroy()
			end)
		end
	end, function()
		hl:Destroy()
		if overloads[target] == token then
			overloads[target] = nil
		end
	end)
	if Players:GetPlayerFromCharacter(target) == localPlayer then
		TuskVFX.ScreenTint(time, { Tint = Color3.fromRGB(255, 236, 170), Brightness = 0.05, Saturation = -0.2, Contrast = 0.1, Release = 0.2, FadeOut = 0.4 })
	end
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "MudaRush" then
		if phase == "Start" and character and root then
			rush(character, (data.Windup or 0.15) + (data.Duration or 1.4))
		elseif phase == "Hit" and data.Position then
			TuskVFX.CreateImpactStar(data.Position, { Size = 2.2, Rays = 5, Color = GOLD, Color2 = Color3.new(1, 1, 1), Duration = 0.08 })
		elseif phase == "Finish" and data.Position then
			if character then
				rushes[character] = nil
				TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 0.8, -4.2), Duration = 0.35 })
			end
			muda(data.Position + Vector3.new(0, 2, 0), true)
			local dir = data.Direction or Vector3.new(0, 0, -1)
			fist(data.Position - dir * 1.5, dir, 2.2)
			leaves(data.Position + Vector3.new(0, 1, 0), 16, 16)
			CameraFX.shakeAt(data.Position, 0.8, 50)
			if character and Common.isLocal(character) then
				CameraFX.impactFrame(pal.Light)
			end
		elseif phase == "Stop" and character then
			rushes[character] = nil
		end
	elseif move == "Tree" then
		if phase == "Punch" and character and root then
			TuskAnimation.play(character, "GITree")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0, -0.6, -2.6), Duration = (data.Windup or 0.3) + 0.4 })
			label(character:FindFirstChild("Head"), "GOLD EXPERIENCE!", GOLD, 1.0, 240)
		elseif phase == "Roots" and data.From and data.To then
			roots(data.From, data.To, data.Time or 0.45)
			TuskVFX.CreateImpactStar(data.From + Vector3.new(0, 0.3, 0), { Size = 2.4, Rays = 6, Color = GOLD, Color2 = LEAF, Duration = 0.12 })
		elseif phase == "Burst" and data.Position then
			growTree(data.Position, 9, data.Life or 5)
			TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position + Vector3.new(0, 0.2, 0)), { Radius = data.Radius or 6, Layers = 2, Color = LEAF, Color2 = GOLD, Ground = true, Particles = 1, Width = 0.4 })
			CameraFX.shakeAt(data.Position, 0.6, 40)
			VFXLib.sound(sounds.Swing, data.Position, 0.6, 0.6)
		end
	elseif move == "Overload" then
		if phase == "Punch" and character and root then
			TuskAnimation.play(character, "GIPunch")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0.4, 0.8, -3.4), Duration = (data.Windup or 0.2) + 0.3 })
			fist((root.CFrame * CFrame.new(0.5, 0.8, -1.6)).Position, root.CFrame.LookVector, 1.4)
		elseif phase == "Overload" and typeof(data.Target) == "Instance" then
			local tr = data.Target:FindFirstChild("HumanoidRootPart")
			if tr then
				TuskVFX.CreateImpactStar(tr.Position, { Size = 3, Rays = 8, Color = GOLD, Color2 = GOLD_LIGHT, Duration = 0.18 })
				lifeFlow(tr.Position, tr.Position + Vector3.new(0, 2, 0), 10)
			end
			overloadGlow(data.Target, data.Time or 3)
		elseif phase == "Pain" and typeof(data.Target) == "Instance" then
			local tr = data.Target:FindFirstChild("HumanoidRootPart")
			overloads[data.Target] = nil
			if tr then
				label(data.Target:FindFirstChild("Head"), "!!!", Color3.fromRGB(255, 90, 90), 1.0, 160, Vector3.new(0, 3.4, 0))
				TuskVFX.CreateImpactStar(tr.Position, { Size = 5, Rays = 10, Color = Color3.fromRGB(255, 90, 90), Color2 = GOLD, Duration = 0.2 })
				CameraFX.shakeAt(tr.Position, 0.7, 40)
			end
		end
	end
end

local function clearJungle(character)
	local list = jungles[character]
	jungles[character] = nil
	if list then
		for _, e in ipairs(list) do
			if e.Part and e.Part.Parent then
				e.Part:Destroy()
			end
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character and root then
		TuskAnimation.play(character, "GIUlt")
		TuskStand.action(character, "Loom", { Target = CFrame.new(1.2, 2.4, 1.6), Duration = (data.Windup or 0.8) + 0.6 })
		label(character:FindFirstChild("Head"), "GOLD EXPERIENCE: LIFE BURST", GOLD, 2.0, 360)
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.2)
		lifeFlow(root.Position + Vector3.new(0, -2, 0), root.Position + Vector3.new(0, 2, 0), 14)
	elseif data.Phase == "Jungle" and data.Position then
		-- A ring of trees bursting up round him.
		local list = {}
		local radius = data.Radius or 28
		for k = 1, 8 do
			local a = k / 8 * math.pi * 2
			local at = data.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * radius * 0.75
			task.delay(k * 0.04, function()
				for _, e in ipairs(growTree(at, 8 + math.random() * 4, data.Time or 2.4)) do
					table.insert(list, e)
				end
			end)
		end
		if character then
			jungles[character] = list
		end
		TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position + Vector3.new(0, 0.2, 0)), { Radius = radius, Layers = 3, Color = LEAF, Color2 = GOLD, Ground = true, Particles = 2, Width = 0.6 })
		for _, target in ipairs(data.Targets or {}) do
			vinesOn(target, data.Time or 2.4)
			local tr = typeof(target) == "Instance" and target:FindFirstChild("HumanoidRootPart")
			if tr and root then
				lifeFlow(tr.Position, root.Position, 6)
			end
		end
		CameraFX.shakeAt(data.Position, 0.8, 60)
		if character and Common.isLocal(character) then
			CameraFX.impactFrame(pal.Light)
		end
	elseif data.Phase == "Bite" then
		for _, target in ipairs(data.Targets or {}) do
			snakeBite(target)
		end
	elseif data.Phase == "Burst" and data.Position then
		for _, target in ipairs(data.Targets or {}) do
			local tr = typeof(target) == "Instance" and target:FindFirstChild("HumanoidRootPart")
			if tr then
				leaves(tr.Position, 14, 18)
				TuskVFX.CreateImpactStar(tr.Position, { Size = 3.5, Rays = 8, Color = LEAF, Color2 = GOLD, Duration = 0.15 })
			end
		end
		leaves(data.Position + Vector3.new(0, 3, 0), 30, 24)
		CameraFX.shakeAt(data.Position, 1, 60)
	elseif data.Phase == "End" and character then
		clearJungle(character)
	end
end

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
				-- (Gold Experience Requiem keeps the same stance.)
				if act ~= REQUIEM_ACT then
					TuskAnimation.stopHold(character, "GiornoStance")
				end
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
	for target in pairs(overloads) do
		if not target.Parent then
			overloads[target] = nil
		end
	end
end

function GiornoVFX.handle(name, data)
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
function GiornoVFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
	end
end

return GiornoVFX
end

-- ======================================================================
-- MODULE: GoldExperienceStand
-- ======================================================================
__modules["GoldExperienceStand"] = function()
--[[
	TuskActVFX.GoldExperienceStand  (StarterPlayerScripts.SpinClient.TuskActVFX.GoldExperienceStand)

	GOLD EXPERIENCE (Giorno Giovanna, Part 5), blocky, matched to the art:
	a slim golden figure with purple joints:
	  * a smooth golden HELMET head with a SPIRAL CURL on the forehead,
	    narrow pale eyes and PURPLE LIPS
	  * big swept-up SHOULDER WINGS (pale silver fins with a spiral on each)
	  * two purple LADYBUG studs on the chest; a lean, ribbed golden body
	  * a belt with silver STRAPS curving across the hips and a big purple
	    buckle on one side
	  * purple balls at the elbows, wrists and knees; purple ankle bands
	Registered with TuskStandModels by GiornoVFX, so TuskStand floats it
	with a gold aura.
]]

local GoldExperienceStand = {}

local GOLD = Color3.fromRGB(232, 198, 112)
local GOLD_LIGHT = Color3.fromRGB(250, 228, 150)
local GOLD_SHADE = Color3.fromRGB(198, 154, 72)
local ORANGE = Color3.fromRGB(222, 150, 70)
local PURPLE = Color3.fromRGB(140, 76, 200)
local PURPLE_DARK = Color3.fromRGB(90, 44, 140)
local SILVER = Color3.fromRGB(214, 218, 230)
local SILVER_SHADE = Color3.fromRGB(170, 176, 196)
local EYE = Color3.fromRGB(190, 240, 230)
local LIP = Color3.fromRGB(150, 70, 190)

GoldExperienceStand.Aura = Color3.fromRGB(255, 214, 90)
GoldExperienceStand.AuraLight = Color3.fromRGB(255, 246, 210)
GoldExperienceStand.Offset = CFrame.new(2.1, 1.5, 2.6)

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

local function egg(model, parent, name, size, color, cf, material)
	local p, w = box(model, parent, name, size, color, cf, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p, w
end

local function cyl(model, parent, name, length, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(length, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A flat spiral (rings of beads), facing along -Z of `cf`.
local function spiral(model, parent, cf, radius, color, bead)
	local n = 14
	for k = 0, n - 1 do
		local a = k / n * math.pi * 3.2
		local r = radius * (1 - k / n * 0.8)
		ball(model, parent, "Spiral", bead, color, cf * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0))
	end
end

function GoldExperienceStand.build(scale)
	local s = (scale or 1) * 0.86
	local model = Instance.new("Model")
	model.Name = "GoldExperience"
	local rig = { Joints = {} }

	-- A lean golden chest.
	local torso = newPart(model, "Body", Vector3.new(1.9, 1.8, 1.0) * s, GOLD)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.5 * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Pec", Vector3.new(0.85, 0.65, 0.14) * s, GOLD_LIGHT, CFrame.new(side * 0.45 * s, 0.4 * s, front - 0.04 * s) * CFrame.Angles(0, side * 0.12, 0))
		-- Purple ladybug studs on the chest.
		egg(model, torso, "Ladybug", Vector3.new(0.34, 0.34, 0.18) * s, PURPLE, CFrame.new(side * 0.5 * s, 0.42 * s, front - 0.12 * s))
		for _, d in ipairs({ { -0.07, 0.06 }, { 0.07, 0.06 }, { 0, -0.08 } }) do
			ball(model, torso, "LadybugDot", 0.07 * s, PURPLE_DARK, CFrame.new(side * 0.5 * s + d[1] * s, 0.42 * s + d[2] * s, front - 0.2 * s))
		end
		-- Ribs.
		for k = 0, 2 do
			box(model, torso, "Rib", Vector3.new(0.45, 0.06, 0.06) * s, GOLD_SHADE, CFrame.new(side * 0.5 * s, -0.1 * s - k * 0.18 * s, front - 0.02 * s) * CFrame.Angles(0, 0, side * 0.25))
		end
	end
	box(model, torso, "Sternum", Vector3.new(0.08, 1.1, 0.08) * s, GOLD_SHADE, CFrame.new(0, 0.05 * s, front - 0.03 * s))
	-- A narrow waist, segmented belly.
	box(model, torso, "Waist", Vector3.new(1.3, 0.9, 0.82) * s, GOLD, CFrame.new(0, -1.3 * s, 0))
	for k = 0, 2 do
		box(model, torso, "Abs", Vector3.new(0.6, 0.05, 0.06) * s, GOLD_SHADE, CFrame.new(0, -1.0 * s - k * 0.22 * s, -0.42 * s))
	end
	-- The belt: silver straps curving across the hips, a purple buckle on one side.
	box(model, torso, "Belt", Vector3.new(1.45, 0.2, 0.9) * s, ORANGE, CFrame.new(0, -1.78 * s, 0))
	for k = 0, 2 do
		for _, side in ipairs({ -1, 1 }) do
			box(model, torso, "Strap", Vector3.new(0.7, 0.07, 0.07) * s, k % 2 == 0 and SILVER or SILVER_SHADE, CFrame.new(side * 0.36 * s, -1.9 * s - k * 0.14 * s, -0.5 * s - k * 0.03 * s) * CFrame.Angles(0, 0, side * (0.18 + k * 0.08)))
		end
	end
	egg(model, torso, "Buckle", Vector3.new(0.5, 0.5, 0.3) * s, PURPLE, CFrame.new(0.72 * s, -1.85 * s, -0.2 * s))
	ball(model, torso, "BuckleDot", 0.14 * s, PURPLE_DARK, CFrame.new(0.82 * s, -1.85 * s, -0.36 * s))
	box(model, torso, "Hips", Vector3.new(1.35, 0.5, 0.86) * s, GOLD_SHADE, CFrame.new(0, -2.05 * s, 0))
	box(model, torso, "Neck", Vector3.new(0.45, 0.4, 0.45) * s, GOLD_SHADE, CFrame.new(0, 1.05 * s, 0))

	-- The shoulder wings: pale fins sweeping up and out, a spiral on each.
	for _, side in ipairs({ -1, 1 }) do
		local cf = CFrame.new(side * 1.15 * s, 0.85 * s, 0.05 * s) * CFrame.Angles(0, 0, side * -0.3)
		egg(model, torso, "ShoulderPad", Vector3.new(0.8, 0.5, 0.8) * s, GOLD_LIGHT, cf)
		for k = 0, 2 do
			box(model, torso, "Wing", Vector3.new(0.12, 0.95 - k * 0.2, 0.36 - k * 0.06) * s, k == 1 and SILVER_SHADE or SILVER, cf * CFrame.new(side * (0.2 + k * 0.12) * s, (0.55 + k * 0.1) * s, (0.02 + k * 0.03) * s) * CFrame.Angles(math.rad(-6), 0, side * (-0.45 - k * 0.15)))
		end
		spiral(model, torso, cf * CFrame.new(side * 0.42 * s, 0.05 * s, 0) * CFrame.Angles(0, side * math.pi / 2, 0), 0.18 * s, GOLD_SHADE, 0.06 * s)
	end

	-- The head: a smooth golden helmet, a spiral curl on the forehead,
	-- narrow pale eyes, purple lips.
	local hs = s * 1.3
	local headBase = CFrame.new(0, 1.15 * s, 0)
	local headOffset = CFrame.new(0, 0.55 * hs, 0)
	local head, headWeld = egg(model, torso, "Head", Vector3.new(0.8, 1.05, 0.85) * hs, GOLD, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.42 * hs
	egg(model, head, "HelmetCrown", Vector3.new(0.86, 0.6, 0.92) * hs, GOLD_LIGHT, CFrame.new(0, 0.26 * hs, 0.03 * hs))
	box(model, head, "HelmetRidge", Vector3.new(0.1, 0.12, 0.9) * hs, GOLD_SHADE, CFrame.new(0, 0.53 * hs, 0.05 * hs))
	spiral(model, head, CFrame.new(0, 0.3 * hs, hf - 0.04 * hs), 0.16 * hs, GOLD_SHADE, 0.065 * hs)
	box(model, head, "Visor", Vector3.new(0.62, 0.14, 0.06) * hs, GOLD_SHADE, CFrame.new(0, 0.06 * hs, hf + 0.01 * hs))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.2, 0.06, 0.04) * hs, EYE, CFrame.new(side * 0.15 * hs, 0.05 * hs, hf - 0.025 * hs) * CFrame.Angles(0, 0, side * -0.12), Enum.Material.Neon)
		box(model, head, "Cheek", Vector3.new(0.06, 0.3, 0.05) * hs, GOLD_SHADE, CFrame.new(side * 0.26 * hs, -0.17 * hs, hf + 0.05 * hs) * CFrame.Angles(0, 0, side * 0.2))
		egg(model, head, "Ear", Vector3.new(0.1, 0.24, 0.2) * hs, GOLD_LIGHT, CFrame.new(side * 0.4 * hs, 0, 0.02 * hs))
	end
	egg(model, head, "Lips", Vector3.new(0.22, 0.09, 0.05) * hs, LIP, CFrame.new(0, -0.27 * hs, hf + 0.03 * hs))

	-- Slender arms: purple elbow and wrist balls, golden hands.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.2 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.05 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.5, 2.1, 0.5) * s, GOLD, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Bicep", Vector3.new(0.58, 0.7, 0.58) * s, GOLD_LIGHT, CFrame.new(0, 0.5 * s, -0.02 * s))
		ball(model, arm, "Elbow", 0.42 * s, PURPLE, CFrame.new(0, 0, 0))
		box(model, arm, "Forearm", Vector3.new(0.56, 0.7, 0.56) * s, GOLD, CFrame.new(0, -0.5 * s, 0))
		box(model, arm, "Wrist", Vector3.new(0.6, 0.16, 0.6) * s, PURPLE, CFrame.new(0, -0.9 * s, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.48, 0.48, 0.42) * s, GOLD_LIGHT, CFrame.new(0, -1.2 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.09, 0.26, 0.1) * s, GOLD, CFrame.new(f * 0.11 * s, -0.3 * s, -0.06 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.25 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: golden, purple knee balls and ankle bands.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.42 * s, -2.2 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.55, 2.4, 0.55) * s, GOLD, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Thigh", Vector3.new(0.66, 0.95, 0.66) * s, GOLD_LIGHT, CFrame.new(0, 0.62 * s, 0))
		ball(model, leg, "Knee", 0.46 * s, PURPLE, CFrame.new(0, 0, -0.1 * s))
		box(model, leg, "Shin", Vector3.new(0.6, 0.85, 0.6) * s, GOLD_SHADE, CFrame.new(0, -0.6 * s, 0))
		box(model, leg, "Ankle", Vector3.new(0.64, 0.14, 0.64) * s, PURPLE, CFrame.new(0, -1.05 * s, 0))
		box(model, leg, "Foot", Vector3.new(0.56, 0.3, 0.9) * s, ORANGE, CFrame.new(0, -1.3 * s, -0.16 * s))
	end
	return model, rig
end

return GoldExperienceStand
end
end
