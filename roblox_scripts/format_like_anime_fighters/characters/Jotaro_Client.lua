--[[
	Jotaro_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Jotaro Kujo: Star Platinum (and its time stop).
	Its other half is Jotaro_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "jotaro" or __expect.Side ~= "client") then
		error("this is the code for Jotaro_Client, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Jotaro_Client and put it in ReplicatedStorage > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: JotaroVFX
-- ======================================================================
__modules["JotaroVFX"] = function()
--[[
	TuskActVFX.JotaroVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.JotaroVFX)

	Client visuals for Jotaro Kujo / STAR PLATINUM. Blocky.
	  * Star Platinum (StarPlatinumStand) floats behind him with a violet
	    aura; Jotaro stands with a hand in his pocket
	  * ORA COMBO: Star Platinum's fists fly out with him; "ORA!" on the 4th
	  * ORA RUSH: a blur of violet fists hammering the space in front of
	    him, "ORA ORA ORA" spilling out, then one huge "ORA!" and a shockwave
	  * STAR FINGER: two long violet fingers shoot out in a line and snap back
	  * BEARING SHOT: a flick; a silver streak and a spark where it lands
	  * STAR PLATINUM: THE WORLD: the colours invert for a beat, a dome
	    spreads out round him and the world inside goes grey and still;
	    frozen fighters turn grey; when time moves again the colour floods
	    back in a ripple
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

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
local StarPlatinumStand = __require("StarPlatinumStand")

local JotaroVFX = {}
local ACT = 20
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, StarPlatinumStand.build, { Aura = StarPlatinumStand.Aura, AuraLight = StarPlatinumStand.AuraLight, Offset = StarPlatinumStand.Offset })

local VIOLET = Color3.fromRGB(150, 120, 255)
local FIST = Color3.fromRGB(116, 118, 222)
local GLOVE = Color3.fromRGB(30, 34, 40)
local GOLD = Color3.fromRGB(240, 196, 70)
local SILVER = Color3.fromRGB(220, 226, 236)

local stanced = {}
local rushes = {} -- [character] = rush job token
local stops = {} -- [character] = { Dome, Frozen = { [character] = Highlight }, Tint }

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

-- "ORA" text popping out at a world spot.
local function ora(at, big)
	local anchor = VFXLib.part({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(at), Transparency = 1 })
	label(anchor, big and "ORA!" or "ORA", big and GOLD or VIOLET, big and 1.0 or 0.5, big and 260 or 120, Vector3.new((math.random() - 0.5) * 3, math.random() * 2, 0))
	task.delay(1.1, function()
		anchor:Destroy()
	end)
end

-- One violet fist flying forward from `from` along `dir`, then fading.
local function fist(from, dir, size)
	size = size or 1
	local f = VFXLib.part({ Size = Vector3.new(0.75, 0.75, 0.9) * size, Color = FIST, Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
	local glove = VFXLib.part({ Size = Vector3.new(0.78, 0.4, 0.5) * size, Color = GLOVE, Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
	local trail = VFXLib.part({ Size = Vector3.new(0.4, 0.4, 2.2) * size, Color = VIOLET, Transparency = 0.5 })
	VFXLib.animate(0.16, function(a)
		local p = from + dir * (a * 3.2)
		local cf = CFrame.lookAt(p, p + dir)
		f.CFrame = cf
		glove.CFrame = cf * CFrame.new(0, 0.2 * size, 0.1 * size)
		trail.CFrame = cf * CFrame.new(0, 0, 1.3 * size)
		local t = a < 0.6 and 0.15 or 0.15 + (a - 0.6) / 0.4 * 0.85
		f.Transparency = t
		glove.Transparency = t
		trail.Transparency = 0.5 + 0.5 * a
	end, function()
		f:Destroy()
		glove:Destroy()
		trail:Destroy()
	end)
end

local function tracer(from, to, hit)
	local len = (to - from).Magnitude
	if len > 0.5 then
		local line = VFXLib.part({ Size = Vector3.new(0.15, 0.15, len), CFrame = CFrame.lookAt((from + to) / 2, to), Color = SILVER, Transparency = 0.05 })
		VFXLib.animate(0.18, function(a)
			line.Transparency = 0.05 + 0.95 * a
			line.Size = Vector3.new(0.15 * (1 - a), 0.15 * (1 - a), len)
		end, function()
			line:Destroy()
		end)
	end
	VFXLib.flash(from, VIOLET, 4, 10, 0.08)
	if hit then
		TuskVFX.CreateImpactStar(to, { Size = 2.6, Rays = 6, Color = SILVER, Color2 = VIOLET, Duration = 0.14 })
	else
		VFXLib.burst(to, { Count = 5, Color = SILVER, Speed = 10, Lifetime = 0.3 })
	end
	VFXLib.sound(sounds.NailFire, from, 0.6, 1.6)
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
	TuskAnimation.play(character, "JT_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1, -3.4), Duration = 0.28 })
	VFXLib.sound(sounds.Swing, root, 0.5, 1.0 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or pal.Second)
	fist((root.CFrame * CFrame.new(index % 2 == 0 and -0.6 or 0.6, 0.8, -1.8)).Position, root.CFrame.LookVector, 1.1)
	if index == 4 then
		ora((root.CFrame * CFrame.new(0, 2, -3)).Position, true)
	end
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function rush(character, duration)
	local token = {}
	rushes[character] = token
	TuskAnimation.play(character, "JTRush")
	TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 0.8, -3.6), Duration = duration })
	local start = os.clock()
	local nextFist, nextOra = 0, 0
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
		if t >= nextOra then
			nextOra = t + 0.16
			ora((root.CFrame * CFrame.new((math.random() - 0.5) * 4, 2 + math.random(), -3)).Position, false)
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
	if move == "OraRush" then
		if phase == "Start" and character and root then
			rush(character, (data.Windup or 0.15) + (data.Duration or 1.5))
		elseif phase == "Hit" and data.Position then
			TuskVFX.CreateImpactStar(data.Position, { Size = 2.2, Rays = 5, Color = VIOLET, Color2 = Color3.new(1, 1, 1), Duration = 0.08 })
		elseif phase == "Finish" and data.Position then
			if character then
				rushes[character] = nil
				TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 0.8, -4.2), Duration = 0.35 })
			end
			ora(data.Position + Vector3.new(0, 2, 0), true)
			local dir = data.Direction or Vector3.new(0, 0, -1)
			fist(data.Position - dir * 1.5, dir, 2.2)
			TuskVFX.CreateRotationalShockwave(CFrame.lookAt(data.Position, data.Position + dir) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = data.Radius or 8, Layers = 3, Color = VIOLET, Color2 = GOLD, Particles = 1, Width = 0.5 })
			CameraFX.shakeAt(data.Position, 0.8, 50)
			if character and Common.isLocal(character) then
				CameraFX.impactFrame(pal.Light)
			end
		elseif phase == "Stop" and character then
			rushes[character] = nil
		end
	elseif move == "StarFinger" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "JTPoint")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0.6, 1, -2.6), Duration = (data.Windup or 0.2) + 0.4 })
		elseif phase == "Strike" and data.From and data.Direction then
			local dir, length = data.Direction, data.Length or 20
			local from = data.From + Vector3.new(0, 1.2, 0)
			for k, side in ipairs({ -0.18, 0.18 }) do
				local finger = VFXLib.part({ Size = Vector3.new(0.3, 0.3, 1), Color = FIST, Material = Enum.Material.SmoothPlastic })
				local tip = VFXLib.part({ Size = Vector3.new(0.34, 0.34, 0.4), Color = VIOLET, Transparency = 0.1 })
				local right = dir:Cross(Vector3.new(0, 1, 0))
				local base = from + right * side + Vector3.new(0, k * 0.05, 0)
				VFXLib.animate(0.45, function(a)
					local out = a < 0.3 and VFXLib.easeOut(a / 0.3) or (a < 0.6 and 1 or 1 - (a - 0.6) / 0.4)
					local l = math.max(length * out, 0.3)
					finger.Size = Vector3.new(0.3, 0.3, l)
					finger.CFrame = CFrame.lookAt(base + dir * (l / 2), base + dir * l)
					tip.CFrame = CFrame.lookAt(base + dir * l, base + dir * (l + 1))
				end, function()
					finger:Destroy()
					tip:Destroy()
				end)
			end
			task.delay(0.12, function()
				VFXLib.burst(from + dir * length, { Count = 10, Color = VIOLET, Speed = 14, Lifetime = 0.3 })
			end)
			VFXLib.sound(sounds.Swing, from, 0.6, 1.5)
		end
	elseif move == "BearingShot" then
		if phase == "Flick" and character and root then
			TuskAnimation.play(character, "JTFlick")
		elseif phase == "Shot" and data.From and data.To then
			tracer(data.From, data.To, data.Hit)
		end
	end
end

---------------------------------------------------------------------------
-- STAR PLATINUM: THE WORLD
---------------------------------------------------------------------------
local function invertFlash()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "StarPlatinumInvert"
	cc.Parent = Lighting
	VFXLib.animate(0.45, function(a)
		local k = a < 0.5 and 1 or 1 - (a - 0.5) / 0.5
		cc.Saturation = -1 * k
		cc.Contrast = 0.6 * k
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(180, 160, 255), k)
		cc.Brightness = 0.15 * k
	end, function()
		cc:Destroy()
	end)
end

local function stillTint(duration)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "StarPlatinumStill"
	cc.Parent = Lighting
	VFXLib.animate(duration, function(a)
		local k = a < 0.08 and a / 0.08 or (a > 0.92 and (1 - a) / 0.08 or 1)
		cc.Saturation = -0.85 * k
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(205, 200, 235), k)
		cc.Contrast = 0.1 * k
	end, function()
		cc:Destroy()
	end)
	return cc
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character and root then
		TuskAnimation.play(character, "JTCap")
		TuskStand.action(character, "Loom", { Target = CFrame.new(1.4, 2.6, 2.2), Duration = (data.Windup or 0.7) + 0.6 })
		label(character:FindFirstChild("Head"), "STAR PLATINUM: THE WORLD", VIOLET, 2.0, 380)
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 0.9)
	elseif data.Phase == "Stop" and data.Position then
		local center, range, duration = data.Position, data.Range or 55, data.Duration or 5
		local stop = { Frozen = {} }
		if character then
			stops[character] = stop
		end
		-- The dome spreads out from him.
		local dome = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(center), Color = VIOLET, Material = Enum.Material.ForceField, Transparency = 0.3 })
		stop.Dome = dome
		VFXLib.animate(0.6, function(a)
			local d = range * 2 * VFXLib.easeOut(a)
			dome.Size = Vector3.new(d, d, d)
			dome.Transparency = 0.3 + 0.5 * a
		end)
		VFXLib.animate(duration, function(a)
			if a > 0.9 then
				dome.Transparency = 0.8 + (a - 0.9) / 0.1 * 0.2
			end
		end, function()
			dome:Destroy()
		end)
		-- Everyone frozen turns grey.
		for _, target in ipairs(data.Frozen or {}) do
			if typeof(target) == "Instance" and target.Parent then
				local h = Instance.new("Highlight")
				h.Name = "StarPlatinumFrozen"
				h.FillColor = Color3.fromRGB(150, 150, 160)
				h.FillTransparency = 0.35
				h.OutlineColor = Color3.fromRGB(90, 90, 110)
				h.OutlineTransparency = 0.4
				h.Adornee = target
				h.Parent = target
				stop.Frozen[target] = h
				task.delay(duration + 0.5, function()
					if h.Parent then
						h:Destroy()
					end
				end)
			end
		end
		if nearLocal(center, range + 10) or (character and Common.isLocal(character)) then
			invertFlash()
			task.delay(0.4, function()
				stop.Tint = stillTint(math.max(0.2, duration - 0.4))
			end)
			CameraFX.fovPunch(-12, 0.6)
		end
		VFXLib.sound(sounds.AwakeningBurst or sounds.Swing, center, 0.7, 0.7)
	elseif data.Phase == "Resume" then
		local stop = character and stops[character]
		if character then
			stops[character] = nil
		end
		if stop then
			for _, h in pairs(stop.Frozen) do
				if h.Parent then
					h:Destroy()
				end
			end
			if stop.Tint and stop.Tint.Parent then
				stop.Tint:Destroy()
			end
			if stop.Dome and stop.Dome.Parent then
				stop.Dome:Destroy()
			end
		end
		-- Colour floods back in a ripple.
		if data.Position then
			local ring = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(data.Position), Color = Color3.fromRGB(230, 220, 255), Material = Enum.Material.ForceField, Transparency = 0.4 })
			VFXLib.animate(0.5, function(a)
				local d = 120 * VFXLib.easeOut(a)
				ring.Size = Vector3.new(d, d, d)
				ring.Transparency = 0.4 + 0.6 * a
			end, function()
				ring:Destroy()
			end)
			if nearLocal(data.Position, 70) then
				CameraFX.shake(0.4, 0.3)
			end
		end
		if character and character:FindFirstChild("Head") then
			label(character:FindFirstChild("Head"), "TIME RESUMES", Color3.new(1, 1, 1), 1.2, 240)
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
				TuskAnimation.hold(character, "JTStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "JTStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function JotaroVFX.handle(name, data)
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
function JotaroVFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
	end
end

return JotaroVFX
end

-- ======================================================================
-- MODULE: StarPlatinumStand
-- ======================================================================
__modules["StarPlatinumStand"] = function()
--[[
	TuskActVFX.StarPlatinumStand  (StarterPlayerScripts.SpinClient.TuskActVFX.StarPlatinumStand)

	STAR PLATINUM (Jotaro Kujo), blocky, matched to the art:
	  * a huge, muscular blue-violet body: broad chest, a six-pack, big arms
	  * a fierce face (glowing pale eyes, a strong jaw) under a GOLD
	    HEADBAND with a gem; long, wild BLACK HAIR streaming back and up
	  * a RED SCARF knotted at the throat, its ends flying out behind
	  * round GOLD SHOULDER GUARDS with a spiral on each
	  * black fingerless gloves with gold cuffs; gold bands at the elbows
	  * a gold belt with a long WHITE LOINCLOTH hanging front and back
	  * bare blue legs with gold knee bands
	Registered with TuskStandModels by JotaroVFX, so TuskStand floats it
	behind Jotaro with a violet aura.
]]

local StarPlatinumStand = {}

local SKIN = Color3.fromRGB(116, 118, 222)
local SKIN_SHADE = Color3.fromRGB(80, 80, 176)
local SKIN_LIGHT = Color3.fromRGB(156, 162, 244)
local GOLD = Color3.fromRGB(240, 196, 70)
local GOLD_SHADE = Color3.fromRGB(196, 148, 40)
local HAIR = Color3.fromRGB(24, 22, 34)
local HAIR_SHINE = Color3.fromRGB(60, 56, 92)
local SCARF = Color3.fromRGB(214, 58, 40)
local SCARF_SHADE = Color3.fromRGB(160, 36, 26)
local CLOTH = Color3.fromRGB(240, 240, 236)
local CLOTH_SHADE = Color3.fromRGB(196, 198, 206)
local GLOVE = Color3.fromRGB(30, 34, 40)
local EYE = Color3.fromRGB(220, 250, 255)
local GEM = Color3.fromRGB(90, 220, 200)

StarPlatinumStand.Aura = Color3.fromRGB(150, 120, 255)
StarPlatinumStand.AuraLight = Color3.fromRGB(220, 210, 255)
StarPlatinumStand.Offset = CFrame.new(2.2, 1.6, 2.8)

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

local function cyl(model, parent, name, length, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(length, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A round gold shoulder guard with a spiral (rings stepping in and up).
local function pauldron(model, torso, side, s)
	local cf = CFrame.new(side * 1.42 * s, 0.82 * s, 0) * CFrame.Angles(0, 0, side * -0.5) * CFrame.Angles(0, 0, math.pi / 2)
	cyl(model, torso, "Pauldron", 0.32 * s, 1.35 * s, GOLD, cf, Enum.Material.Metal)
	for k = 1, 3 do
		cyl(model, torso, "Spiral", 0.06 * s, (1.35 - k * 0.32) * s, k % 2 == 1 and GOLD_SHADE or GOLD, cf * CFrame.new((0.16 + k * 0.03) * s, (k - 2) * 0.05 * s, 0), Enum.Material.Metal)
	end
	cyl(model, torso, "SpiralEye", 0.08 * s, 0.18 * s, GOLD_SHADE, cf * CFrame.new(0.3 * s, 0, 0), Enum.Material.Metal)
end

function StarPlatinumStand.build(scale)
	local s = (scale or 1) * 0.9
	local model = Instance.new("Model")
	model.Name = "StarPlatinum"
	local rig = { Joints = {} }

	-- A broad, heavy torso.
	local torso = newPart(model, "Body", Vector3.new(2.4, 1.9, 1.15) * s, SKIN)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.58 * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Pec", Vector3.new(1.0, 0.62, 0.14) * s, SKIN_LIGHT, CFrame.new(side * 0.52 * s, 0.42 * s, front - 0.04 * s))
		box(model, torso, "PecLine", Vector3.new(1.0, 0.06, 0.15) * s, SKIN_SHADE, CFrame.new(side * 0.52 * s, 0.1 * s, front - 0.045 * s))
		box(model, torso, "Lat", Vector3.new(0.2, 1.3, 0.9) * s, SKIN_SHADE, CFrame.new(side * 1.2 * s, -0.1 * s, 0))
	end
	box(model, torso, "Sternum", Vector3.new(0.05, 0.6, 0.15) * s, SKIN_SHADE, CFrame.new(0, 0.42 * s, front - 0.05 * s))
	-- Six-pack.
	box(model, torso, "Waist", Vector3.new(1.75, 0.85, 0.95) * s, SKIN, CFrame.new(0, -1.3 * s, 0))
	for k = 0, 2 do
		for _, side in ipairs({ -1, 1 }) do
			box(model, torso, "Ab", Vector3.new(0.38, 0.24, 0.08) * s, SKIN_LIGHT, CFrame.new(side * 0.22 * s, (-0.22 - k * 0.32) * s, front - 0.02 * s))
		end
	end
	box(model, torso, "AbLine", Vector3.new(0.05, 1.0, 0.09) * s, SKIN_SHADE, CFrame.new(0, -0.55 * s, front - 0.025 * s))
	-- Gold belt and the long white loincloth, front and back.
	box(model, torso, "Belt", Vector3.new(1.85, 0.3, 1.05) * s, GOLD, CFrame.new(0, -1.7 * s, 0), Enum.Material.Metal)
	box(model, torso, "BeltBuckle", Vector3.new(0.4, 0.34, 0.08) * s, GOLD_SHADE, CFrame.new(0, -1.7 * s, -0.55 * s), Enum.Material.Metal)
	box(model, torso, "Hips", Vector3.new(1.75, 0.5, 0.95) * s, SKIN_SHADE, CFrame.new(0, -2.0 * s, 0))
	box(model, torso, "Loincloth", Vector3.new(0.9, 1.9, 0.06) * s, CLOTH, CFrame.new(0, -2.75 * s, -0.55 * s) * CFrame.Angles(math.rad(-4), 0, 0))
	box(model, torso, "LoinFold", Vector3.new(0.05, 1.8, 0.07) * s, CLOTH_SHADE, CFrame.new(0.2 * s, -2.75 * s, -0.56 * s) * CFrame.Angles(math.rad(-4), 0, 0))
	box(model, torso, "LoinBack", Vector3.new(1.1, 1.6, 0.06) * s, CLOTH, CFrame.new(0, -2.6 * s, 0.55 * s) * CFrame.Angles(math.rad(8), 0, 0))
	box(model, torso, "Neck", Vector3.new(0.65, 0.45, 0.6) * s, SKIN_SHADE, CFrame.new(0, 1.12 * s, 0))
	-- The red scarf: knotted at the throat, the ends flying out behind.
	box(model, torso, "Scarf", Vector3.new(0.95, 0.3, 0.85) * s, SCARF, CFrame.new(0, 1.08 * s, 0))
	box(model, torso, "ScarfKnot", Vector3.new(0.35, 0.3, 0.2) * s, SCARF_SHADE, CFrame.new(0.15 * s, 0.95 * s, -0.45 * s) * CFrame.Angles(0, 0, 0.3))
	box(model, torso, "ScarfEnd", Vector3.new(0.4, 1.1, 0.07) * s, SCARF, CFrame.new(0.3 * s, 0.6 * s, 0.85 * s) * CFrame.Angles(math.rad(55), 0, math.rad(-15)))
	box(model, torso, "ScarfEnd", Vector3.new(0.34, 0.9, 0.07) * s, SCARF_SHADE, CFrame.new(-0.2 * s, 0.65 * s, 0.8 * s) * CFrame.Angles(math.rad(60), 0, math.rad(20)))
	for _, side in ipairs({ -1, 1 }) do
		pauldron(model, torso, side, s)
	end

	-- Head: a fierce face under a gold headband; long wild black hair.
	local headBase = CFrame.new(0, 1.3 * s, 0)
	local headOffset = CFrame.new(0, 0.52 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.8, 0.95, 0.82) * s, SKIN, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.41 * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.2, 0.08, 0.05) * s, EYE, CFrame.new(side * 0.18 * s, 0.08 * s, hf - 0.02 * s) * CFrame.Angles(0, 0, side * -0.18), Enum.Material.Neon)
		box(model, head, "Brow", Vector3.new(0.26, 0.07, 0.07) * s, SKIN_SHADE, CFrame.new(side * 0.18 * s, 0.17 * s, hf - 0.03 * s) * CFrame.Angles(0, 0, side * 0.25))
		box(model, head, "Cheek", Vector3.new(0.05, 0.3, 0.05) * s, SKIN_SHADE, CFrame.new(side * 0.3 * s, -0.15 * s, hf - 0.02 * s))
	end
	box(model, head, "Nose", Vector3.new(0.1, 0.24, 0.1) * s, SKIN_SHADE, CFrame.new(0, -0.04 * s, hf - 0.04 * s))
	box(model, head, "Mouth", Vector3.new(0.26, 0.05, 0.05) * s, SKIN_SHADE, CFrame.new(0, -0.27 * s, hf - 0.02 * s))
	box(model, head, "Jaw", Vector3.new(0.7, 0.22, 0.6) * s, SKIN, CFrame.new(0, -0.48 * s, -0.05 * s))
	-- Gold headband with a gem.
	box(model, head, "Headband", Vector3.new(0.88, 0.14, 0.9) * s, GOLD, CFrame.new(0, 0.3 * s, 0), Enum.Material.Metal)
	box(model, head, "Gem", Vector3.new(0.14, 0.14, 0.06) * s, GEM, CFrame.new(0, 0.3 * s, hf - 0.06 * s) * CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Neon)
	-- Hair: a cap, then long locks streaming back and up.
	box(model, head, "HairCap", Vector3.new(0.92, 0.3, 0.92) * s, HAIR, CFrame.new(0, 0.5 * s, 0.04 * s))
	-- { x, y, z, length, tilt back (degrees), spread sideways (degrees) }
	local locks = {
		{ 0, 0.7, 0.1, 1.2, 35, 0 }, { -0.3, 0.62, 0.15, 1.15, 48, -22 }, { 0.3, 0.62, 0.15, 1.15, 48, 22 },
		{ -0.4, 0.4, 0.3, 1.5, 70, -35 }, { 0.4, 0.4, 0.3, 1.5, 70, 35 }, { 0, 0.35, 0.4, 1.8, 82, 0 },
		{ -0.25, 0.1, 0.42, 1.7, 100, -18 }, { 0.25, 0.1, 0.42, 1.7, 100, 18 }, { 0, -0.1, 0.45, 1.5, 120, 0 },
	}
	for i, l in ipairs(locks) do
		local cf = CFrame.new(l[1] * s, l[2] * s, l[3] * s) * CFrame.Angles(math.rad(l[5]), 0, math.rad(-l[6])) * CFrame.new(0, l[4] * 0.5 * s, 0)
		box(model, head, "Hair", Vector3.new(0.38, l[4], 0.26) * s, i % 3 == 0 and HAIR_SHINE or HAIR, cf)
		box(model, head, "HairTip", Vector3.new(0.18, 0.3, 0.14) * s, HAIR, cf * CFrame.new(0, l[4] * 0.55 * s, 0) * CFrame.Angles(0, 0, 0.3))
	end
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "SideLock", Vector3.new(0.12, 0.6, 0.3) * s, HAIR, CFrame.new(side * 0.45 * s, 0.05 * s, 0.1 * s) * CFrame.Angles(0, 0, side * 0.15))
	end

	-- Huge arms: gold elbow bands, black fingerless gloves with gold cuffs.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.55 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.72, 2.2, 0.72) * s, SKIN, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Delt", Vector3.new(0.9, 0.6, 0.88) * s, SKIN_LIGHT, CFrame.new(0, 0.85 * s, 0))
		box(model, arm, "Bicep", Vector3.new(0.82, 0.65, 0.82) * s, SKIN_LIGHT, CFrame.new(0, 0.35 * s, -0.04 * s))
		box(model, arm, "ElbowBand", Vector3.new(0.8, 0.1, 0.8) * s, GOLD, CFrame.new(0, -0.05 * s, 0), Enum.Material.Metal)
		box(model, arm, "Forearm", Vector3.new(0.8, 0.7, 0.8) * s, SKIN, CFrame.new(0, -0.5 * s, 0))
		box(model, arm, "Cuff", Vector3.new(0.84, 0.16, 0.84) * s, GOLD, CFrame.new(0, -0.9 * s, 0), Enum.Material.Metal)
		local hand = box(model, arm, "Hand", Vector3.new(0.68, 0.6, 0.62) * s, GLOVE, CFrame.new(0, -1.3 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.13, 0.36, 0.14) * s, SKIN, CFrame.new(f * 0.15 * s, -0.38 * s, -0.08 * s))
		end
		box(model, hand, "Knuckles", Vector3.new(0.7, 0.14, 0.18) * s, GOLD_SHADE, CFrame.new(0, -0.15 * s, -0.3 * s), Enum.Material.Metal)
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: bare and blue, gold knee bands.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.5 * s, -2.15 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.76, 2.4, 0.76) * s, SKIN, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Thigh", Vector3.new(0.86, 0.95, 0.86) * s, SKIN_LIGHT, CFrame.new(0, 0.65 * s, 0))
		box(model, leg, "KneeBand", Vector3.new(0.82, 0.12, 0.82) * s, GOLD, CFrame.new(0, 0.02 * s, 0), Enum.Material.Metal)
		box(model, leg, "Calf", Vector3.new(0.72, 0.7, 0.8) * s, SKIN_SHADE, CFrame.new(0, -0.55 * s, 0.03 * s))
		box(model, leg, "Foot", Vector3.new(0.68, 0.3, 1.0) * s, SKIN, CFrame.new(0, -1.3 * s, -0.17 * s))
	end
	return model, rig
end

return StarPlatinumStand
end
end
