--[[
	Polnareff_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Jean Pierre Polnareff (Part 3): Silver Chariot.
	Its other half is Polnareff_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: ChariotRequiemStand
-- ======================================================================
__modules["ChariotRequiemStand"] = function()
--[[
	TuskActVFX.ChariotRequiemStand  (StarterPlayerScripts.SpinClient.TuskActVFX.ChariotRequiemStand)

	SILVER CHARIOT REQUIEM, blocky, matched to the anime / manga art:
	  * a tall, slim figure, glossy near-black with a navy tint, picked out
	    with thin pale lavender SHEEN lines (collar, chest, ribs, pants)
	  * a faceless dark head under a wide, tilted brimmed HAT: a round brim
	    with a pale edge, a pointed front, a tall crown with a band
	  * two big round DISC shoulder pads, each with concentric rings and a
	    hollow centre
	  * a belt with a row of white FANGS hanging from it
	  * baggy pants puffed out to below the knee, tapering into boots
	  * long arms with open clawed gloves; the REQUIEM ARROW (gold, with its
	    scarab) held low in its right hand
	Registered with TuskStandModels by ChariotRequiemVFX; TuskStand floats
	it behind Polnareff with a dark violet aura.
]]

local ChariotRequiemStand = {}

local DARK = Color3.fromRGB(22, 20, 36)
local MID = Color3.fromRGB(44, 42, 70)
local SHEEN = Color3.fromRGB(176, 176, 218)
local FANG = Color3.fromRGB(226, 224, 238)
local GOLD = Color3.fromRGB(222, 182, 72)
local SHAFT = Color3.fromRGB(150, 112, 50)

ChariotRequiemStand.Aura = Color3.fromRGB(120, 80, 190)
ChariotRequiemStand.AuraLight = Color3.fromRGB(214, 200, 255)
ChariotRequiemStand.Offset = CFrame.new(2.6, 2.4, 3.4)

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

local function egg(model, parent, name, size, color, cf, material)
	local p, w = box(model, parent, name, size, color, cf, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p, w
end

-- A cylinder whose round faces point along the local X axis of cf.
local function disc(model, parent, name, length, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(length, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A thin pale sheen line from a to b (in parent space), sat on the surface.
local function line(model, parent, a, b, w)
	local len = (b - a).Magnitude
	return box(model, parent, "Sheen", Vector3.new(w, w, len + w), SHEEN, CFrame.lookAt((a + b) / 2, b))
end

function ChariotRequiemStand.build(scale)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "ChariotRequiem"
	local rig = { Joints = {} }
	local V = function(x, y, z)
		return Vector3.new(x, y, z) * s
	end
	local lw = 0.05 * s

	-- A slim chest tapering to a narrow waist.
	local torso = newPart(model, "Body", V(1.5, 1.3, 0.82), DARK)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	egg(model, torso, "Chest", V(1.7, 1.45, 0.98), DARK, CFrame.new(0, 0.12 * s, -0.04 * s))
	box(model, torso, "Abdomen", V(1.12, 0.95, 0.72), DARK, CFrame.new(0, -1.0 * s, 0))
	egg(model, torso, "Ribs", V(1.25, 1.0, 0.8), DARK, CFrame.new(0, -0.75 * s, -0.02 * s))
	local f = -0.5 * s
	-- Sheen lines: a collar curve, a V at the sternum, pec and rib curves.
	line(model, torso, V(-0.75, 0.62, -0.34), V(-0.32, 0.4, -0.47), lw)
	line(model, torso, V(-0.32, 0.4, -0.47), V(0.32, 0.4, -0.47), lw)
	line(model, torso, V(0.32, 0.4, -0.47), V(0.75, 0.62, -0.34), lw)
	line(model, torso, V(-0.2, 0.22, -0.5), V(0, 0.08, -0.51), lw)
	line(model, torso, V(0, 0.08, -0.51), V(0.2, 0.22, -0.5), lw)
	for _, side in ipairs({ -1, 1 }) do
		line(model, torso, V(side * 0.1, -0.22, -0.5), V(side * 0.45, -0.12, -0.46), lw)
		line(model, torso, V(side * 0.45, -0.12, -0.46), V(side * 0.7, 0.08, -0.36), lw)
		line(model, torso, V(side * 0.22, -0.62, -0.42), V(side * 0.5, -0.5, -0.36), lw)
	end
	line(model, torso, V(0, -0.45, -0.43), V(0, -1.2, -0.38), lw)
	box(model, torso, "Neck", V(0.42, 0.4, 0.42), DARK, CFrame.new(0, 0.85 * s, 0))
	line(model, torso, V(-0.22, 0.75, -0.2), V(0.22, 0.75, -0.2), lw)

	-- A faceless dark head under a wide, tilted brimmed hat.
	local headBase = CFrame.new(0, 1.0 * s, 0)
	local headOffset = CFrame.new(0, 0.42 * s, 0)
	local head, headWeld = egg(model, torso, "Head", V(0.66, 0.88, 0.72), DARK, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	line(model, head, V(-0.14, -0.28, -0.33), V(0.14, -0.28, -0.33), lw * 0.8)
	local hat = CFrame.new(0, 0.32 * s, 0) * CFrame.Angles(math.rad(-12), 0, math.rad(9))
	disc(model, head, "Brim", 0.08 * s, 2.3 * s, DARK, hat * CFrame.Angles(0, 0, math.pi / 2))
	-- The brim's pale edge.
	local n = 22
	for k = 0, n - 1 do
		local a0, a1 = k / n * math.pi * 2, (k + 1) / n * math.pi * 2
		local r = 1.13 * s
		local pa = (hat * CFrame.new(math.cos(a0) * r, 0.05 * s, math.sin(a0) * r)).Position
		local pb = (hat * CFrame.new(math.cos(a1) * r, 0.05 * s, math.sin(a1) * r)).Position
		line(model, head, pa, pb, lw * 1.2)
	end
	-- A pointed front to the brim, dipping down.
	local tip = hat * CFrame.new(0, -0.02 * s, -0.95 * s) * CFrame.Angles(math.rad(-10), math.pi / 4, 0)
	box(model, head, "BrimPoint", V(0.7, 0.07, 0.7), DARK, tip)
	line(model, head, (hat * CFrame.new(-0.42 * s, 0.03 * s, -0.95 * s)).Position, (hat * CFrame.new(0, -0.06 * s, -1.42 * s)).Position, lw * 1.2)
	line(model, head, (hat * CFrame.new(0, -0.06 * s, -1.42 * s)).Position, (hat * CFrame.new(0.42 * s, 0.03 * s, -0.95 * s)).Position, lw * 1.2)
	-- A tall crown with a band and a pinched front.
	disc(model, head, "Crown", 0.65 * s, 0.98 * s, DARK, hat * CFrame.new(0, 0.35 * s, 0.05 * s) * CFrame.Angles(0, 0, math.pi / 2))
	egg(model, head, "CrownTop", V(0.98, 0.4, 0.98), DARK, hat * CFrame.new(0, 0.68 * s, 0.05 * s))
	disc(model, head, "HatBand", 0.12 * s, 1.03 * s, MID, hat * CFrame.new(0, 0.1 * s, 0.05 * s) * CFrame.Angles(0, 0, math.pi / 2))
	line(model, head, (hat * CFrame.new(-0.52 * s, 0.17 * s, 0.05 * s)).Position, (hat * CFrame.new(-0.3 * s, 0.17 * s, -0.38 * s)).Position, lw)
	line(model, head, (hat * CFrame.new(-0.3 * s, 0.17 * s, -0.38 * s)).Position, (hat * CFrame.new(0.3 * s, 0.17 * s, -0.38 * s)).Position, lw)
	line(model, head, (hat * CFrame.new(-0.16 * s, 0.78 * s, -0.42 * s)).Position, (hat * CFrame.new(0, 0.42 * s, -0.48 * s)).Position, lw)
	line(model, head, (hat * CFrame.new(0, 0.42 * s, -0.48 * s)).Position, (hat * CFrame.new(0.16 * s, 0.78 * s, -0.42 * s)).Position, lw)
	line(model, head, (hat * CFrame.new(0, 0.42 * s, -0.48 * s)).Position, (hat * CFrame.new(0, 0.22 * s, -0.48 * s)).Position, lw)

	-- Big round disc shoulder pads with ringed faces and a hollow centre.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local padCF = CFrame.new(side * 1.05 * s, 0.62 * s, 0) * CFrame.Angles(0, side * math.rad(-15), side * math.rad(-28))
		local pad = disc(model, torso, "ShoulderDisc", 0.6 * s, 1.32 * s, DARK, padCF)
		local out = side
		disc(model, pad, "DiscRim", 0.05 * s, 1.3 * s, SHEEN, CFrame.new(out * 0.3 * s, 0, 0))
		disc(model, pad, "DiscFace", 0.06 * s, 1.1 * s, DARK, CFrame.new(out * 0.32 * s, 0, 0))
		disc(model, pad, "DiscRing", 0.05 * s, 0.88 * s, MID, CFrame.new(out * 0.35 * s, 0, 0))
		disc(model, pad, "DiscInner", 0.06 * s, 0.8 * s, DARK, CFrame.new(out * 0.37 * s, 0, 0))
		disc(model, pad, "Boss", 0.18 * s, 0.6 * s, DARK, CFrame.new(out * 0.44 * s, 0, 0))
		disc(model, pad, "BossRim", 0.19 * s, 0.6 * s * 1.02, SHEEN, CFrame.new(out * 0.44 * s, 0, 0))
		disc(model, pad, "BossFace", 0.2 * s, 0.5 * s, DARK, CFrame.new(out * 0.45 * s, 0, 0))
		disc(model, pad, "Hollow", 0.21 * s, 0.24 * s, MID, CFrame.new(out * 0.46 * s, 0, 0))
		disc(model, pad, "HollowRim", 0.22 * s, 0.14 * s, DARK, CFrame.new(out * 0.46 * s, 0, 0))
		-- A pale edge round the back of the disc too.
		disc(model, pad, "BackRim", 0.04 * s, 1.34 * s, SHEEN, CFrame.new(-out * 0.27 * s, 0, 0))

		-- A long thin arm with an open clawed glove.
		local base = CFrame.new(side * 1.0 * s, 0.32 * s, 0)
		local offset = CFrame.new(0, -1.4 * s, 0)
		local arm, weld = box(model, torso, a[1], V(0.36, 2.8, 0.36), DARK, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		egg(model, arm, "Bicep", V(0.5, 1.25, 0.5), DARK, CFrame.new(0, 0.62 * s, 0))
		egg(model, arm, "Forearm", V(0.48, 1.25, 0.48), DARK, CFrame.new(0, -0.6 * s, 0))
		line(model, arm, V(side * 0.18, 1.0, -0.12), V(side * 0.22, 0.2, -0.16), lw)
		line(model, arm, V(-0.2, -0.05, -0.18), V(0.2, -0.05, -0.18), lw)
		line(model, arm, V(side * 0.2, -0.25, -0.15), V(side * 0.16, -1.05, -0.12), lw)
		line(model, arm, V(-0.2, -1.12, -0.2), V(0.2, -1.12, -0.2), lw)
		local hand = box(model, arm, "Hand", V(0.36, 0.4, 0.26), DARK, CFrame.new(0, -1.48 * s, 0))
		for k = -1.5, 1.5 do
			local fx = k * 0.085 * s
			local finger = box(model, hand, "Finger", V(0.07, 0.34, 0.07), DARK, CFrame.new(fx, -0.34 * s, -0.02 * s) * CFrame.Angles(math.rad(-22), 0, k * 0.12))
			box(model, finger, "Claw", V(0.06, 0.16, 0.06), MID, CFrame.new(0, -0.22 * s, -0.04 * s) * CFrame.Angles(math.rad(-30), 0, 0))
		end
		box(model, hand, "Thumb", V(0.08, 0.26, 0.08), DARK, CFrame.new(-side * 0.2 * s, -0.12 * s, -0.08 * s) * CFrame.Angles(math.rad(-30), 0, side * 0.5))
		line(model, hand, V(-0.19, 0.18, -0.14), V(0.19, 0.18, -0.14), lw)

		if a[1] == "ArmR" then
			-- The Requiem Arrow, held low: a gold shaft, the scarab, a broad head.
			local grip = CFrame.new(0, -0.1 * s, -0.05 * s)
			disc(model, hand, "ArrowShaft", 2.6 * s, 0.07 * s, SHAFT, grip * CFrame.new(0, 0, -0.55 * s) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Metal)
			egg(model, hand, "ArrowScarab", V(0.2, 0.14, 0.28), GOLD, grip * CFrame.new(0, 0, -1.72 * s), Enum.Material.Metal)
			box(model, hand, "ArrowHead", V(0.42, 0.05, 0.42), GOLD, grip * CFrame.new(0, 0, -2.0 * s) * CFrame.Angles(0, math.pi / 4, 0), Enum.Material.Metal)
			box(model, hand, "ArrowBarb", V(0.5, 0.06, 0.08), GOLD, grip * CFrame.new(0, 0, -1.86 * s), Enum.Material.Metal)
			box(model, hand, "ArrowNock", V(0.16, 0.05, 0.16), GOLD, grip * CFrame.new(0, 0, 0.72 * s) * CFrame.Angles(0, math.pi / 4, 0), Enum.Material.Metal)
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.1 * s, -2.35 * s)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- The belt with a row of white fangs hanging from it.
	local beltY = -1.55 * s
	box(model, torso, "Belt", V(1.32, 0.26, 0.86), MID, CFrame.new(0, beltY, 0))
	line(model, torso, V(-0.66, -1.42, -0.44), V(0.66, -1.42, -0.44), lw)
	line(model, torso, V(-0.66, -1.68, -0.44), V(0.66, -1.68, -0.44), lw)
	for k = -2, 2 do
		box(model, torso, "BeltLoop", V(0.1, 0.32, 0.06), DARK, CFrame.new(k * 0.28 * s, beltY, -0.45 * s))
	end
	for k = -4, 4 do
		local ang = k / 4 * math.rad(95)
		local pos = CFrame.new(math.sin(ang) * 0.7 * s, beltY - 0.2 * s, -math.cos(ang) * 0.47 * s)
		local fang = egg(model, torso, "Fang", V(0.1, 0.34, 0.1), FANG, pos * CFrame.Angles(0, -ang, 0) * CFrame.Angles(math.rad(14), 0, 0))
		egg(model, fang, "FangTip", V(0.06, 0.18, 0.06), FANG, CFrame.new(0, -0.18 * s, 0.03 * s) * CFrame.Angles(math.rad(25), 0, 0))
	end
	egg(model, torso, "Hips", V(1.45, 0.7, 0.95), DARK, CFrame.new(0, -1.9 * s, 0))

	-- Baggy pants puffed out to below the knee, tapering into boots.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.4 * s, -2.0 * s, 0)
		local offset = CFrame.new(0, -1.3 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, V(0.45, 2.6, 0.45), DARK, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		egg(model, leg, "Pants", V(0.92, 2.15, 0.94), DARK, CFrame.new(side * 0.05 * s, 0.25 * s, 0))
		egg(model, leg, "Knee", V(0.84, 0.9, 0.9), DARK, CFrame.new(side * 0.04 * s, -0.3 * s, -0.04 * s))
		box(model, leg, "Cuff", V(0.5, 0.14, 0.5), MID, CFrame.new(0, -0.75 * s, 0))
		line(model, leg, V(side * 0.25, 1.05, -0.36), V(side * 0.1, 0.25, -0.43), lw)
		line(model, leg, V(-side * 0.18, 0.2, -0.4), V(-side * 0.05, -0.55, -0.4), lw)
		line(model, leg, V(side * 0.32, -0.1, -0.2), V(side * 0.22, -0.65, -0.3), lw)
		box(model, leg, "Shin", V(0.42, 0.6, 0.42), DARK, CFrame.new(0, -0.95 * s, 0))
		box(model, leg, "Boot", V(0.48, 0.42, 0.78), DARK, CFrame.new(0, -1.22 * s, -0.13 * s))
		egg(model, leg, "Toe", V(0.46, 0.34, 0.4), DARK, CFrame.new(0, -1.27 * s, -0.5 * s))
		line(model, leg, V(-0.25, -0.98, -0.25), V(0.25, -0.98, -0.25), lw)
	end
	return model, rig
end

return ChariotRequiemStand
end

-- ======================================================================
-- MODULE: ChariotRequiemVFX
-- ======================================================================
__modules["ChariotRequiemVFX"] = function()
--[[
	TuskActVFX.ChariotRequiemVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.ChariotRequiemVFX)

	Client visuals for SILVER CHARIOT REQUIEM (Polnareff after the Requiem
	Arrow, Act 24). Dark, slow and strange:
	  * Chariot Requiem (ChariotRequiemStand) looms behind him, a dark
	    wraith with a pale mask, with a violet aura
	  * REQUIEM STRIKES: heavy dark slashes edged in gold
	  * SOUL SWAP: two pale souls cross between him and the target as they
	    swap places; a flash at both ends
	  * REQUIEM'S SLEEP: a violet mist spreads out round him; sleepers get
	    a drifting "Z z z" (and if it's you, the screen goes dark)
	  * SHADOW STEP: a dark afterimage left behind, a trail of black smoke
	  * SOUL REVERSAL: everyone's soul (a pale see-through copy of them)
	    rises out of them and hangs there, then slams back down
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
local ChariotRequiemStand = __require("ChariotRequiemStand")

local ChariotRequiemVFX = {}
local ACT = 24
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, ChariotRequiemStand.build, { Aura = ChariotRequiemStand.Aura, AuraLight = ChariotRequiemStand.AuraLight, Offset = ChariotRequiemStand.Offset })

local DARK = Color3.fromRGB(40, 30, 60)
local VIOLET = Color3.fromRGB(150, 100, 230)
local GOLD = Color3.fromRGB(240, 200, 90)
local SOUL = Color3.fromRGB(210, 230, 255)

local stanced = {}
local souls = {} -- [character] = { parts } the ultimate's lifted souls

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function nearLocal(pos, range)
	local r = localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	return r ~= nil and (r.Position - pos).Magnitude <= range
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

-- A heavy dark slash: a wide dark blade-streak with a gold edge.
local function slash(root, side)
	local arc = VFXLib.part({ Size = Vector3.new(6, 0.3, 1.2), Color = DARK, Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
	local edge = VFXLib.part({ Size = Vector3.new(6, 0.08, 0.2), Color = GOLD, Transparency = 0.2 })
	local base = root.CFrame * CFrame.new(0, 0.8, -3.2) * CFrame.Angles(0, 0, side * 0.6)
	VFXLib.animate(0.22, function(a)
		local cf = base * CFrame.Angles(0, side * (-0.9 + a * 1.8), 0)
		arc.CFrame = cf
		edge.CFrame = cf * CFrame.new(0, 0.15, -0.55)
		arc.Transparency = 0.15 + 0.85 * a
		edge.Transparency = 0.2 + 0.8 * a
	end, function()
		arc:Destroy()
		edge:Destroy()
	end)
end

-- A pale see-through copy of someone (their soul).
local function soulOf(character)
	local parts = {}
	for _, d in ipairs(character:GetChildren()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
			table.insert(parts, { Part = VFXLib.part({ Size = d.Size, CFrame = d.CFrame, Color = SOUL, Material = Enum.Material.Neon, Transparency = 0.55 }), Offset = d.CFrame })
		end
	end
	return parts
end

local function orb(from, to, time, color)
	local o = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1), Color = color or SOUL, Transparency = 0.2 })
	VFXLib.animate(time, function(a)
		local p = from:Lerp(to, VFXLib.easeInOut(a)) + Vector3.new(0, math.sin(a * math.pi) * 4, 0)
		o.CFrame = CFrame.new(p)
		VFXLib.burst(p, { Count = 1, Color = color or SOUL, Speed = 2, Lifetime = 0.3 })
	end, function()
		o:Destroy()
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
	TuskAnimation.play(character, "PN_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1.2, -3.8), Duration = 0.34 })
	VFXLib.sound(sounds.Swing, root, 0.5, 0.7)
	task.delay(0.08, function()
		local r = Common.rootOf(character)
		if r then
			slash(r, index % 2 == 1 and 1 or -1)
		end
	end)
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "SoulSwap" then
		if phase == "Reach" and character and root then
			TuskAnimation.play(character, "PNPoint")
			TuskStand.action(character, "Loom", { Target = CFrame.new(1.6, 3, 2.6), Duration = (data.Windup or 0.35) + 0.4 })
			local tr = data.Target and Common.rootOf(data.Target)
			if tr then
				VFXLib.burst(tr.Position, { Count = 10, Color = SOUL, Speed = 4, Lifetime = 0.5 })
			end
		elseif phase == "Swap" and data.A and data.B then
			orb(data.A, data.B, 0.4, SOUL)
			orb(data.B, data.A, 0.4, VIOLET)
			for _, p in ipairs({ data.A, data.B }) do
				VFXLib.flash(p, VIOLET, 4, 14, 0.2)
				TuskVFX.CreateImpactStar(p, { Size = 3, Rays = 6, Color = SOUL, Color2 = VIOLET, Duration = 0.15 })
			end
			if data.Target then
				label(data.Target:FindFirstChild("Head"), "SOULS SWAPPED", SOUL, 1.4, 240)
			end
			if (character and Common.isLocal(character)) or (data.Target and Common.isLocal(data.Target)) then
				CameraFX.impactFrame(Color3.fromRGB(200, 180, 255))
				CameraFX.fovPunch(-10, 0.4)
			end
		end
	elseif move == "Sleep" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "PNArmorOff")
			TuskStand.action(character, "Loom", { Target = CFrame.new(0, 4, 2.6), Duration = (data.Windup or 0.5) + 0.6 })
			label(character:FindFirstChild("Head"), "REQUIEM", VIOLET, 1.2, 240)
		elseif phase == "Sleep" and data.Position then
			local mist = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(data.Position), Color = VIOLET, Material = Enum.Material.ForceField, Transparency = 0.4 })
			VFXLib.animate(1.0, function(a)
				local d = (data.Radius or 26) * 2 * VFXLib.easeOut(math.min(a * 1.6, 1))
				mist.Size = Vector3.new(d, d * 0.5, d)
				mist.Transparency = 0.4 + 0.6 * a
			end, function()
				mist:Destroy()
			end)
			local time = data.Time or 2.2
			for _, t in ipairs(data.Targets or {}) do
				local head = t:FindFirstChild("Head")
				for k = 0, 2 do
					task.delay(k * (time / 3), function()
						label(head, "Z z z", Color3.fromRGB(200, 190, 255), time / 3 + 0.2, 140)
					end)
				end
				if Common.isLocal(t) then
					TuskVFX.ScreenTint(time, { Tint = Color3.fromRGB(120, 100, 170), Brightness = -0.35, Saturation = -0.5, Contrast = 0.1, Release = 0, FadeOut = 0.4 })
				end
			end
		end
	elseif move == "ShadowStep" and phase == "Step" and data.From and data.To then
		local ghost = VFXLib.part({ Size = Vector3.new(2, 5, 1), CFrame = CFrame.new(data.From), Color = DARK, Material = Enum.Material.SmoothPlastic, Transparency = 0.3 })
		VFXLib.animate(0.5, function(a)
			ghost.Transparency = 0.3 + 0.7 * a
		end, function()
			ghost:Destroy()
		end)
		for k = 0, 8 do
			local p = data.From:Lerp(data.To, k / 8)
			VFXLib.burst(p - Vector3.new(0, 1.5, 0), { Count = 3, Color = DARK, Speed = 3, Lifetime = 0.6 })
		end
		if character and Common.isLocal(character) then
			CameraFX.speedLines(0.25, VIOLET)
		end
	end
end

---------------------------------------------------------------------------
-- SOUL REVERSAL
---------------------------------------------------------------------------
local function dropSouls(character)
	local list = souls[character]
	souls[character] = nil
	for _, s in ipairs(list or {}) do
		VFXLib.cancel(s.Job)
		for _, p in ipairs(s.Parts) do
			p.Part:Destroy()
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character and root then
		TuskAnimation.play(character, "PNArmorOff")
		TuskStand.action(character, "Loom", { Target = CFrame.new(0, 5, 3), Duration = (data.Windup or 0.8) + 0.8 })
		label(character:FindFirstChild("Head"), "SILVER CHARIOT REQUIEM", VIOLET, 2.0, 380)
		if nearLocal(root.Position, 50) then
			TuskVFX.ScreenTint(1.2, { Tint = Color3.fromRGB(150, 120, 210), Brightness = -0.2, Saturation = -0.4, Contrast = 0.2, Release = 0.1, FadeOut = 0.5 })
		end
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 0.7)
	elseif data.Phase == "Souls" and character then
		dropSouls(character)
		local list = {}
		souls[character] = list
		local time = (data.Time or 2.2) + 0.2
		for i, t in ipairs(data.Targets or {}) do
			local tr = Common.rootOf(t)
			if tr then
				local parts = soulOf(t)
				local base = tr.CFrame
				local entry = { Parts = parts }
				entry.Job = VFXLib.animate(time, function(a)
					local lift = math.min(a * time / 0.5, 1) * 4
					local bob = math.sin(os.clock() * 3 + i) * 0.3
					local spin = CFrame.Angles(0, os.clock() * 0.8, 0)
					for _, p in ipairs(parts) do
						local rel = base:Inverse() * p.Offset
						p.Part.CFrame = CFrame.new(base.Position + Vector3.new(0, lift + bob, 0)) * spin * (base - base.Position) * rel
					end
				end)
				table.insert(list, entry)
				-- A thin cord from body to soul.
				VFXLib.burst(tr.Position, { Count = 12, Color = SOUL, Speed = 6, Lifetime = 0.6 })
			end
		end
	elseif data.Phase == "Return" and character then
		local list = souls[character]
		souls[character] = nil
		for _, s in ipairs(list or {}) do
			VFXLib.cancel(s.Job)
			local start = {}
			for _, p in ipairs(s.Parts) do
				start[p] = p.Part.CFrame
			end
			VFXLib.animate(0.18, function(a)
				for _, p in ipairs(s.Parts) do
					p.Part.CFrame = start[p]:Lerp(p.Offset, a)
					p.Part.Transparency = 0.55 + 0.45 * a
				end
			end, function()
				for _, p in ipairs(s.Parts) do
					p.Part:Destroy()
				end
			end)
		end
		for _, t in ipairs(data.Targets or {}) do
			local tr = Common.rootOf(t)
			if tr then
				task.delay(0.18, function()
					TuskVFX.CreateImpactStar(tr.Position, { Size = 4, Rays = 8, Color = SOUL, Color2 = VIOLET, Duration = 0.2 })
				end)
			end
			if Common.isLocal(t) then
				CameraFX.shake(0.6, 0.3)
				CameraFX.impactFrame(SOUL)
			end
		end
	elseif data.Phase == "End" and character then
		dropSouls(character)
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
				TuskAnimation.hold(character, "PNStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				-- (Polnareff's own stance takes over again if he's back to Silver Chariot.)
				if character:GetAttribute("TuskAct") ~= 23 then
					TuskAnimation.stopHold(character, "PNStance")
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

function ChariotRequiemVFX.handle(name, data)
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
function ChariotRequiemVFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
	end
end

return ChariotRequiemVFX
end

-- ======================================================================
-- MODULE: PolnareffVFX
-- ======================================================================
__modules["PolnareffVFX"] = function()
--[[
	TuskActVFX.PolnareffVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.PolnareffVFX)

	Client visuals for Jean Pierre Polnareff / SILVER CHARIOT. Blocky.
	  * Silver Chariot (SilverChariotStand), a silver knight with a rapier,
	    floats behind him with a pale silver-blue aura
	  * RAPIER COMBO: bright thrust streaks; "HORA!" on the 4th
	  * HORA HORA RUSH: dozens of thrust streaks stabbing the space in front
	    of him, "HORA HORA" spilling out, a final thrust and a shockwave
	  * ARMOR OFF: the armour plates burst off and fly away; while it's off
	    he leaves silver afterimages as he moves
	  * RAPIER SHOT: the blade flies out like a bullet, a streak behind it
	  * AFTERIMAGE STORM: a ring of see-through Silver Chariots round the
	    target, circling and stabbing in; then they all thrust at once
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
local SilverChariotStand = __require("SilverChariotStand")

local PolnareffVFX = {}
local ACT = 23
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, SilverChariotStand.build, { Aura = SilverChariotStand.Aura, AuraLight = SilverChariotStand.AuraLight, Offset = SilverChariotStand.Offset })

local SILVER = Color3.fromRGB(210, 218, 232)
local BLADE = Color3.fromRGB(240, 246, 255)
local BLUE = Color3.fromRGB(120, 180, 240)

local stanced = {}
local rushes = {}
local storms = {}
local trailNext = {}

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function nearLocal(pos, range)
	local r = localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	return r ~= nil and (r.Position - pos).Magnitude <= range
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

local function word(at, text, color, big)
	local anchor = VFXLib.part({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(at), Transparency = 1 })
	label(anchor, text, color or SILVER, big and 1.0 or 0.5, big and 260 or 120, Vector3.new((math.random() - 0.5) * 3, math.random() * 2, 0))
	task.delay(1.1, function()
		anchor:Destroy()
	end)
end

-- A rapier thrust: a bright thin streak shooting forward and fading.
local function thrust(from, dir, length, width)
	length, width = length or 5, width or 0.12
	local line = VFXLib.part({ Size = Vector3.new(width, width, 0.5), Color = BLADE, Transparency = 0 })
	local glow = VFXLib.part({ Size = Vector3.new(width * 3, width * 3, 0.5), Color = BLUE, Transparency = 0.6 })
	VFXLib.animate(0.12, function(a)
		local l = math.max(length * math.min(a * 2.5, 1), 0.3)
		local cf = CFrame.lookAt(from + dir * (l / 2), from + dir * l)
		line.Size = Vector3.new(width * (1 - a * 0.6), width * (1 - a * 0.6), l)
		line.CFrame = cf
		glow.Size = Vector3.new(width * 3, width * 3, l)
		glow.CFrame = cf
		line.Transparency = a > 0.6 and (a - 0.6) / 0.4 or 0
		glow.Transparency = 0.6 + 0.4 * a
	end, function()
		line:Destroy()
		glow:Destroy()
	end)
end

-- A see-through silver copy of a character's pose (afterimage).
local function afterimage(character, color)
	local parts = {}
	for _, d in ipairs(character:GetChildren()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
			table.insert(parts, VFXLib.part({ Size = d.Size, CFrame = d.CFrame, Color = color or SILVER, Material = Enum.Material.Neon, Transparency = 0.6 }))
		end
	end
	VFXLib.animate(0.35, function(a)
		for _, p in ipairs(parts) do
			p.Transparency = 0.6 + 0.4 * a
		end
	end, function()
		for _, p in ipairs(parts) do
			p:Destroy()
		end
	end)
end

-- A see-through Silver Chariot (blocky silhouette with a rapier), facing `look`.
local function chariotGhost()
	local g = {}
	local function add(size, offset)
		table.insert(g, { Part = VFXLib.part({ Size = size, Color = SILVER, Material = Enum.Material.Neon, Transparency = 0.45 }), Offset = offset })
	end
	add(Vector3.new(1.6, 1.6, 0.9), CFrame.new(0, 0, 0))
	add(Vector3.new(0.7, 0.8, 0.7), CFrame.new(0, 1.3, 0))
	add(Vector3.new(0.12, 0.6, 0.6), CFrame.new(0, 1.85, 0.2))
	add(Vector3.new(0.5, 1.8, 0.5), CFrame.new(-1.05, -0.3, 0))
	add(Vector3.new(0.5, 1.8, 0.5), CFrame.new(1.05, -0.1, -0.5) * CFrame.Angles(math.rad(70), 0, 0))
	add(Vector3.new(0.6, 2.0, 0.6), CFrame.new(-0.4, -1.9, 0))
	add(Vector3.new(0.6, 2.0, 0.6), CFrame.new(0.4, -1.9, 0))
	add(Vector3.new(0.08, 0.08, 3.6), CFrame.new(1.05, 0.4, -2.6))
	return g
end

local function placeGhost(g, cf, t)
	for _, p in ipairs(g) do
		p.Part.CFrame = cf * p.Offset
		p.Part.Transparency = t
	end
end

local function dropGhost(g)
	for _, p in ipairs(g) do
		p.Part:Destroy()
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
	TuskAnimation.play(character, "PN_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.6 or 0.6, 0.8, -3.4), Duration = 0.24 })
	VFXLib.sound(sounds.Swing, root, 0.45, 1.3 + index * 0.05)
	task.delay(0.05, function()
		local r = Common.rootOf(character)
		if r then
			local from = (r.CFrame * CFrame.new((math.random() - 0.5) * 1.2, 0.5 + (math.random() - 0.5) * 0.8, -1.5)).Position
			thrust(from, r.CFrame.LookVector, index == 4 and 9 or 6, index == 4 and 0.2 or 0.12)
		end
	end)
	if index == 4 then
		word((root.CFrame * CFrame.new(0, 2, -3)).Position, "HORA!", SILVER, true)
	end
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function rush(character, duration)
	local token = {}
	rushes[character] = token
	TuskAnimation.play(character, "PNRush")
	TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 0.8, -3.8), Duration = duration })
	local start = os.clock()
	local nextThrust, nextWord = 0, 0
	VFXLib.animate(duration, function()
		local r = Common.rootOf(character)
		if rushes[character] ~= token or not r then
			return
		end
		local t = os.clock() - start
		if t >= nextThrust then
			nextThrust = t + 0.02
			local from = (r.CFrame * CFrame.new((math.random() - 0.5) * 3, 0.4 + (math.random() - 0.5) * 2.6, -1.5)).Position
			local dir = (r.CFrame * CFrame.Angles((math.random() - 0.5) * 0.2, (math.random() - 0.5) * 0.3, 0)).LookVector
			thrust(from, dir, 6 + math.random() * 3, 0.1)
		end
		if t >= nextWord then
			nextWord = t + 0.18
			word((r.CFrame * CFrame.new((math.random() - 0.5) * 4, 2 + math.random(), -3)).Position, "HORA", SILVER, false)
		end
	end, function()
		if rushes[character] == token then
			rushes[character] = nil
		end
	end)
	if Common.isLocal(character) then
		CameraFX.speedLines(duration, SILVER)
	end
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "HoraRush" then
		if phase == "Start" and character and root then
			rush(character, (data.Windup or 0.12) + (data.Duration or 1.4))
		elseif phase == "Hit" and data.Position then
			TuskVFX.CreateImpactStar(data.Position, { Size = 2, Rays = 5, Color = SILVER, Color2 = BLUE, Duration = 0.08 })
		elseif phase == "Finish" and data.Position then
			if character then
				rushes[character] = nil
			end
			local dir = data.Direction or Vector3.new(0, 0, -1)
			thrust(data.Position - dir * 3, dir, 12, 0.3)
			word(data.Position + Vector3.new(0, 2, 0), "HORA!", SILVER, true)
			TuskVFX.CreateRotationalShockwave(CFrame.lookAt(data.Position, data.Position + dir) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = data.Radius or 7, Layers = 2, Color = SILVER, Color2 = BLUE, Particles = 1, Width = 0.4 })
			CameraFX.shakeAt(data.Position, 0.6, 50)
		elseif phase == "Stop" and character then
			rushes[character] = nil
		end
	elseif move == "ArmorOff" then
		if phase == "Shed" and character and root then
			TuskAnimation.play(character, "PNArmorOff")
			label(character:FindFirstChild("Head"), "ARMOR OFF!", SILVER, 1.4, 260)
			-- The plates burst off and fly away.
			for k = 1, 14 do
				local plate = VFXLib.part({ Size = Vector3.new(0.6 + math.random() * 0.4, 0.15, 0.5 + math.random() * 0.4), Color = SILVER, Material = Enum.Material.Metal, Transparency = 0 })
				local from = (root.CFrame * CFrame.new(2.2, 1.5, 2.6)).Position
				local vel = Vector3.new((math.random() - 0.5) * 30, 15 + math.random() * 15, (math.random() - 0.5) * 30)
				local spin = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
				VFXLib.animate(0.8, function(a)
					local t = a * 0.8
					local p = from + vel * t + Vector3.new(0, -50 * t * t, 0)
					plate.CFrame = CFrame.new(p) * spin * CFrame.Angles(t * 8, t * 6, 0)
					plate.Transparency = a > 0.7 and (a - 0.7) / 0.3 or 0
				end, function()
					plate:Destroy()
				end)
			end
			VFXLib.flash(root.Position, BLUE, 4, 14, 0.2)
			if Common.isLocal(character) then
				CameraFX.fovPunch(8, 0.4)
			end
		elseif phase == "Back" and character then
			label(character:FindFirstChild("Head"), "ARMOR BACK ON", SILVER, 1.0, 220)
		end
	elseif move == "RapierShot" then
		if phase == "Aim" and character and root then
			TuskAnimation.play(character, "PNPoint")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0.6, 1, -2.6), Duration = (data.Windup or 0.25) + 0.3 })
		elseif phase == "Fire" and data.From and data.To then
			local from, to = data.From, data.To
			local dir = (to - from).Magnitude > 0.1 and (to - from).Unit or Vector3.new(0, 0, -1)
			local blade = VFXLib.part({ Size = Vector3.new(0.1, 0.18, 3.4), Color = BLADE, Material = Enum.Material.Metal, Transparency = 0 })
			local len = (to - from).Magnitude
			VFXLib.animate(math.max(0.08, len / 400), function(a)
				local p = from + dir * (len * a)
				blade.CFrame = CFrame.lookAt(p, p + dir)
			end, function()
				blade:Destroy()
				if data.Hit then
					TuskVFX.CreateImpactStar(to, { Size = 3, Rays = 6, Color = BLADE, Color2 = BLUE, Duration = 0.14 })
				else
					VFXLib.burst(to, { Count = 6, Color = SILVER, Speed = 10, Lifetime = 0.3 })
				end
			end)
			thrust(from, dir, math.min(len, 40), 0.08)
			VFXLib.sound(sounds.NailFire, from, 0.6, 1.4)
		end
	end
end

---------------------------------------------------------------------------
-- AFTERIMAGE STORM
---------------------------------------------------------------------------
local function endStorm(character)
	local st = storms[character]
	storms[character] = nil
	if st then
		VFXLib.cancel(st.Job)
		for _, g in ipairs(st.Ghosts) do
			dropGhost(g)
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Split" and character and root then
		TuskAnimation.play(character, "PNPoint")
		label(character:FindFirstChild("Head"), "SILVER CHARIOT!", SILVER, 1.6, 300)
		TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 1, -4), Duration = (data.Windup or 0.5) + 0.3 })
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.2)
	elseif data.Phase == "Storm" and character and data.Position then
		endStorm(character)
		local target, center = data.Target, data.Position
		local count, radius, duration = data.Images or 7, (data.Radius or 10) * 0.7, data.Duration or 2.2
		local st = { Ghosts = {} }
		for i = 1, count do
			st.Ghosts[i] = chariotGhost()
		end
		storms[character] = st
		local start = os.clock()
		local nextStab = 0
		st.Job = VFXLib.animate(duration + 0.1, function()
			local tr = target and Common.rootOf(target)
			local at = tr and tr.Position or center
			local t = os.clock() - start
			for i, g in ipairs(st.Ghosts) do
				local ang = i / count * math.pi * 2 + t * 2.4
				local pos = at + Vector3.new(math.cos(ang) * radius, 0.5, math.sin(ang) * radius)
				local lunge = math.max(0, math.sin(t * 18 + i * 1.7)) * 1.2
				local look = CFrame.lookAt(pos, Vector3.new(at.X, pos.Y, at.Z))
				placeGhost(g, look * CFrame.new(0, 0, -lunge), 0.45 + 0.1 * math.sin(t * 9 + i))
			end
			if t >= nextStab then
				nextStab = t + 0.05
				local i = math.random(1, count)
				local ang = i / count * math.pi * 2 + t * 2.4
				local from = at + Vector3.new(math.cos(ang) * radius, 0.9, math.sin(ang) * radius)
				thrust(from, (at + Vector3.new(0, 0.5, 0) - from).Unit, radius, 0.1)
			end
		end)
		if nearLocal(center, 40) then
			CameraFX.speedLines(duration, SILVER)
		end
	elseif data.Phase == "Final" and character then
		local st = storms[character]
		local at = data.Position
		if st and at then
			-- They all thrust in at once, then vanish.
			for i, g in ipairs(st.Ghosts) do
				local p = g[1].Part.Position
				thrust(p, (at - p).Magnitude > 0.1 and (at - p).Unit or Vector3.new(0, 0, -1), (at - p).Magnitude + 2, 0.25)
			end
		end
		endStorm(character)
		if at then
			label(character:FindFirstChild("Head"), "HORA HORA HORA!", SILVER, 1.4, 300)
			TuskVFX.CreateRotationalShockwave(CFrame.new(at), { Radius = (data.Radius or 10) * 1.2, Layers = 3, Color = SILVER, Color2 = BLUE, Ground = true, Particles = 1.5, Width = 0.5 })
			TuskVFX.CreateImpactStar(at, { Size = 6, Rays = 10, Color = BLADE, Color2 = BLUE, Duration = 0.25 })
			if nearLocal(at, 60) then
				CameraFX.shake(0.7, 0.35)
			end
		end
	elseif data.Phase == "End" and character then
		endStorm(character)
	end
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local function stepStance()
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character then
			local want = character:GetAttribute("TuskAct") == ACT
			if want and not stanced[character] then
				stanced[character] = true
				TuskAnimation.hold(character, "PNStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				-- (Chariot Requiem keeps the same stance.)
				if character:GetAttribute("TuskAct") ~= 24 then
					TuskAnimation.stopHold(character, "PNStance")
				end
			end
			-- Armour off: silver afterimages as he moves.
			if want and (character:GetAttribute("ChariotArmorOffUntil") or 0) > serverNow and now >= (trailNext[character] or 0) then
				local r = Common.rootOf(character)
				if r and Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z).Magnitude > 4 then
					trailNext[character] = now + 0.12
					afterimage(character, SILVER)
				end
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
			trailNext[character] = nil
		end
	end
end

function PolnareffVFX.handle(name, data)
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
function PolnareffVFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.05 then
		slowTimer = 0
		stepStance()
	end
end

return PolnareffVFX
end

-- ======================================================================
-- MODULE: SilverChariotStand
-- ======================================================================
__modules["SilverChariotStand"] = function()
--[[
	TuskActVFX.SilverChariotStand  (StarterPlayerScripts.SpinClient.TuskActVFX.SilverChariotStand)

	SILVER CHARIOT (Jean Pierre Polnareff), blocky: a slim KNIGHT in
	silver armour.
	  * a helmet with a visor (two narrow glowing eye slits) and a crest of
	    blades sweeping back over the top
	  * a breastplate with a round emblem, layered shoulder plates, a skirt
	    of plates at the hips, greaves and pointed sabatons
	  * dark joints between the plates
	  * a long, thin RAPIER in its right hand: a cup guard and a fine blade
	Registered with TuskStandModels by PolnareffVFX, so TuskStand floats it
	behind him with a pale silver-blue aura.
]]

local SilverChariotStand = {}

local SILVER = Color3.fromRGB(200, 208, 222)
local SILVER_LIGHT = Color3.fromRGB(232, 238, 248)
local SILVER_DARK = Color3.fromRGB(130, 138, 158)
local JOINT = Color3.fromRGB(50, 54, 66)
local ACCENT = Color3.fromRGB(110, 170, 230)
local EYE = Color3.fromRGB(170, 230, 255)
local BLADE = Color3.fromRGB(236, 242, 252)

SilverChariotStand.Aura = Color3.fromRGB(170, 200, 240)
SilverChariotStand.AuraLight = Color3.fromRGB(236, 244, 255)
SilverChariotStand.Offset = CFrame.new(2.2, 1.5, 2.6)

local function newPart(model, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = material or Enum.Material.Metal
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

local function cyl(model, parent, name, length, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(length, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function SilverChariotStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "SilverChariot"
	local rig = { Joints = {} }

	-- A slim torso under a breastplate.
	local torso = newPart(model, "Body", Vector3.new(1.9, 1.8, 1.0) * s, JOINT, Enum.Material.SmoothPlastic)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	box(model, torso, "Breastplate", Vector3.new(2.0, 1.2, 1.1) * s, SILVER, CFrame.new(0, 0.3 * s, 0))
	box(model, torso, "PlateRidge", Vector3.new(0.08, 1.1, 0.08) * s, SILVER_LIGHT, CFrame.new(0, 0.3 * s, -0.58 * s))
	cyl(model, torso, "Emblem", 0.08 * s, 0.42 * s, ACCENT, CFrame.new(0, 0.45 * s, -0.59 * s) * CFrame.Angles(0, math.pi / 2, 0))
	cyl(model, torso, "EmblemRim", 0.06 * s, 0.52 * s, SILVER_LIGHT, CFrame.new(0, 0.45 * s, -0.57 * s) * CFrame.Angles(0, math.pi / 2, 0))
	for k = 0, 1 do
		box(model, torso, "Faulds", Vector3.new(1.7 - k * 0.1, 0.22, 1.0) * s, k == 0 and SILVER_DARK or SILVER, CFrame.new(0, (-0.42 - k * 0.24) * s, 0))
	end
	box(model, torso, "Waist", Vector3.new(1.3, 0.6, 0.85) * s, JOINT, CFrame.new(0, -1.05 * s, 0), Enum.Material.SmoothPlastic)
	box(model, torso, "Belt", Vector3.new(1.45, 0.18, 0.95) * s, SILVER_DARK, CFrame.new(0, -1.3 * s, 0))
	-- A skirt of plates at the hips.
	for k = -2, 2 do
		box(model, torso, "Tasset", Vector3.new(0.3, 0.65, 0.08) * s, k % 2 == 0 and SILVER or SILVER_LIGHT, CFrame.new(k * 0.3 * s, -1.68 * s, -0.5 * s) * CFrame.Angles(math.rad(-8), 0, 0))
	end
	box(model, torso, "TassetBack", Vector3.new(1.5, 0.6, 0.08) * s, SILVER_DARK, CFrame.new(0, -1.65 * s, 0.5 * s) * CFrame.Angles(math.rad(8), 0, 0))
	box(model, torso, "Neck", Vector3.new(0.45, 0.4, 0.45) * s, JOINT, CFrame.new(0, 1.05 * s, 0), Enum.Material.SmoothPlastic)

	-- Helmet: a visor with two glowing slits, a crest of blades sweeping back.
	local headBase = CFrame.new(0, 1.2 * s, 0)
	local headOffset = CFrame.new(0, 0.5 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.75, 0.9, 0.8) * s, SILVER, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.41 * s
	box(model, head, "Visor", Vector3.new(0.72, 0.5, 0.08) * s, SILVER_DARK, CFrame.new(0, -0.05 * s, hf - 0.03 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "EyeSlit", Vector3.new(0.22, 0.05, 0.05) * s, EYE, CFrame.new(side * 0.16 * s, 0.06 * s, hf - 0.08 * s) * CFrame.Angles(0, 0, side * -0.15), Enum.Material.Neon)
		box(model, head, "Cheek", Vector3.new(0.1, 0.55, 0.6) * s, SILVER_LIGHT, CFrame.new(side * 0.4 * s, -0.12 * s, -0.05 * s))
	end
	box(model, head, "Grill", Vector3.new(0.04, 0.3, 0.09) * s, JOINT, CFrame.new(0, -0.2 * s, hf - 0.04 * s))
	for k = 0, 4 do
		local f = k / 4
		box(model, head, "Crest", Vector3.new(0.12, (0.5 - f * 0.12) * s, (0.32 + f * 0.1) * s), k % 2 == 0 and SILVER_LIGHT or SILVER, CFrame.new(0, (0.5 + f * 0.15) * s, (-0.25 + f * 0.65) * s) * CFrame.Angles(math.rad(-35 - f * 25), 0, 0))
	end
	box(model, head, "CrestBlade", Vector3.new(0.06, 0.12, 0.9) * s, ACCENT, CFrame.new(0, 0.72 * s, 0.75 * s) * CFrame.Angles(math.rad(-20), 0, 0), Enum.Material.Neon)

	-- Arms: layered shoulder plates, armoured forearms; the rapier in its right hand.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		for k = 0, 2 do
			box(model, torso, "Pauldron", Vector3.new(0.8 - k * 0.08, 0.2, 0.85 - k * 0.05) * s, k % 2 == 0 and SILVER or SILVER_LIGHT, CFrame.new(side * (1.15 + k * 0.05) * s, (0.82 - k * 0.18) * s, 0) * CFrame.Angles(0, 0, side * (-0.35 - k * 0.1)))
		end
		local base = CFrame.new(side * 1.25 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.05 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.5, 2.1, 0.5) * s, JOINT, base * offset, Enum.Material.SmoothPlastic)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Rerebrace", Vector3.new(0.6, 0.7, 0.6) * s, SILVER, CFrame.new(0, 0.45 * s, 0))
		box(model, arm, "Couter", Vector3.new(0.58, 0.22, 0.62) * s, SILVER_LIGHT, CFrame.new(0, -0.05 * s, -0.02 * s))
		box(model, arm, "Vambrace", Vector3.new(0.62, 0.75, 0.62) * s, SILVER, CFrame.new(0, -0.55 * s, 0))
		local hand = box(model, arm, "Gauntlet", Vector3.new(0.5, 0.45, 0.5) * s, SILVER_DARK, CFrame.new(0, -1.2 * s, 0))
		if a[1] == "ArmR" then
			-- The rapier: hilt in the hand, a cup guard, a long fine blade forward.
			cyl(model, hand, "Hilt", 0.6 * s, 0.12 * s, JOINT, CFrame.new(0, -0.05 * s, 0) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.SmoothPlastic)
			local guard = box(model, hand, "Guard", Vector3.new(0.5, 0.5, 0.18) * s, SILVER_LIGHT, CFrame.new(0, -0.05 * s, -0.35 * s))
			guard.Shape = Enum.PartType.Ball
			box(model, hand, "Quillon", Vector3.new(0.7, 0.06, 0.06) * s, SILVER_LIGHT, CFrame.new(0, -0.05 * s, -0.42 * s))
			box(model, hand, "Blade", Vector3.new(0.06, 0.12, 4.2) * s, BLADE, CFrame.new(0, -0.05 * s, -2.55 * s), Enum.Material.Metal)
			box(model, hand, "BladeShine", Vector3.new(0.02, 0.04, 4.0) * s, Color3.new(1, 1, 1), CFrame.new(0, -0.02 * s, -2.55 * s), Enum.Material.Neon)
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.05 * s, -4.6 * s)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: greaves, knee plates, pointed sabatons.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.42 * s, -1.95 * s, 0)
		local offset = CFrame.new(0, -1.15 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.55, 2.3, 0.55) * s, JOINT, base * offset, Enum.Material.SmoothPlastic)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Cuisse", Vector3.new(0.66, 0.85, 0.66) * s, SILVER, CFrame.new(0, 0.6 * s, 0))
		box(model, leg, "Poleyn", Vector3.new(0.5, 0.3, 0.15) * s, SILVER_LIGHT, CFrame.new(0, 0.05 * s, -0.36 * s))
		box(model, leg, "Greave", Vector3.new(0.64, 0.85, 0.66) * s, SILVER, CFrame.new(0, -0.55 * s, 0))
		box(model, leg, "Sabaton", Vector3.new(0.55, 0.26, 0.9) * s, SILVER_DARK, CFrame.new(0, -1.22 * s, -0.15 * s))
		box(model, leg, "Toe", Vector3.new(0.3, 0.2, 0.35) * s, SILVER_LIGHT, CFrame.new(0, -1.25 * s, -0.7 * s) * CFrame.Angles(0, math.pi / 4, 0))
	end
	return model, rig
end

return SilverChariotStand
end
end
