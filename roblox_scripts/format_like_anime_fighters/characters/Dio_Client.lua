--[[
	Dio_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	DIO (Part 3): The World, knives and a road roller.
	Its other half is Dio_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "dio" or __expect.Side ~= "client") then
		error("this is the code for Dio_Client, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Dio_Client and put it in ReplicatedStorage > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: DioVFX
-- ======================================================================
__modules["DioVFX"] = function()
--[[
	TuskActVFX.DioVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.DioVFX)

	Client visuals for DIO (Part 3) / THE WORLD. Blocky. (Diego (AU)'s
	The World is DiegoAUVFX; this one is DIO's own.)
	  * The World (TheWorldDioStand) floats behind him with a golden aura;
	    DIO leans back, one hand at his chest, the other held out
	  * MUDA COMBO: golden fists fly out with him; "MUDA!" on the 4th
	  * VAMPIRE DRAIN: he grabs them; red blood streams from them into his
	    hand, red flashes, "WRYYY"
	  * SPACE RIPPER STINGY EYES: two thin white-hot beams from his eyes
	  * KNIFE VOLLEY: silver knives (server Kind "DioKnife"); thrown in
	    stopped time they hang in the air, then fly
	  * ZA WARUDO: the colours invert, a golden dome spreads, the world
	    inside turns grey and still and frozen fighters go grey. Then a
	    ROAD ROLLER drops out of the sky ("ROAD ROLLER DA!") and crashes
	    down; "TOKI WA UGOKIDASU" and the colour floods back
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

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
local TheWorldDioStand = __require("TheWorldDioStand")

local DioVFX = {}
local ACT = 21
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, TheWorldDioStand.build, { Aura = TheWorldDioStand.Aura, AuraLight = TheWorldDioStand.AuraLight, Offset = TheWorldDioStand.Offset })

local GOLD = Color3.fromRGB(255, 210, 70)
local FIST = Color3.fromRGB(240, 200, 60)
local GREEN = Color3.fromRGB(56, 156, 112)
local BLOOD = Color3.fromRGB(170, 14, 20)
local BLOOD_LIGHT = Color3.fromRGB(230, 50, 50)
local STEEL = Color3.fromRGB(220, 224, 232)
local VIOLET = GOLD -- (shared time-stop code below uses this name)

local stanced = {}
local stops = {}
local knives = {} -- [projectile id] = flying knife
local roller, crash -- (below)

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
	label(anchor, text, color or GOLD, big and 1.2 or 0.6, big and 300 or 140, Vector3.new((math.random() - 0.5) * 3, math.random() * 2, 0))
	task.delay(1.3, function()
		anchor:Destroy()
	end)
end

local function fist(from, dir, size)
	size = size or 1
	local f = VFXLib.part({ Size = Vector3.new(0.75, 0.75, 0.9) * size, Color = FIST, Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
	local band = VFXLib.part({ Size = Vector3.new(0.8, 0.2, 0.8) * size, Color = GREEN, Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
	local trail = VFXLib.part({ Size = Vector3.new(0.4, 0.4, 2.2) * size, Color = GOLD, Transparency = 0.5 })
	VFXLib.animate(0.16, function(a)
		local p = from + dir * (a * 3.2)
		local cf = CFrame.lookAt(p, p + dir)
		f.CFrame = cf
		band.CFrame = cf * CFrame.new(0, 0, 0.5 * size)
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

---------------------------------------------------------------------------
-- Knives (server Kind "DioKnife")
---------------------------------------------------------------------------
local function spawnKnife(data)
	local blade = VFXLib.part({ Size = Vector3.new(0.12, 0.05, 1.1), Color = STEEL, Material = Enum.Material.Metal, Transparency = 0 })
	local handle = VFXLib.part({ Size = Vector3.new(0.14, 0.1, 0.5), Color = Color3.fromRGB(60, 50, 44), Material = Enum.Material.SmoothPlastic, Transparency = 0 })
	local glint = VFXLib.part({ Size = Vector3.new(0.06, 0.06, 0.9), Color = Color3.new(1, 1, 1), Transparency = 0.4 })
	knives[data.Id] = { Blade = blade, Handle = handle, Glint = glint, Origin = data.Origin, Direction = data.Direction, Speed = data.Speed, Range = data.Range, ServerTime = data.ServerTime, Expire = os.clock() + data.Range / math.max(data.Speed, 1) + 0.5 }
end

local function dropKnife(v)
	v.Blade:Destroy()
	v.Handle:Destroy()
	v.Glint:Destroy()
end

local function endKnife(data)
	local v = knives[data.Id]
	if v then
		knives[data.Id] = nil
		dropKnife(v)
	end
	if data.Position then
		VFXLib.burst(data.Position, { Count = data.HitCharacter and 8 or 4, Color = data.HitCharacter and BLOOD_LIGHT or STEEL, Speed = 10, Lifetime = 0.3 })
		if data.HitCharacter then
			TuskVFX.CreateImpactStar(data.Position, { Size = 1.8, Rays = 5, Color = STEEL, Color2 = GOLD, Duration = 0.1 })
		end
	end
end

local function stepKnives()
	local now = os.clock()
	for id, v in pairs(knives) do
		local t = VFXLib.flight(id, v.ServerTime)
		local dist = math.clamp(v.Speed * t, 0, v.Range)
		local pos = v.Origin + v.Direction * dist
		local cf = CFrame.lookAt(pos, pos + v.Direction)
		v.Blade.CFrame = cf
		v.Handle.CFrame = cf * CFrame.new(0, 0, 0.75)
		v.Glint.CFrame = cf * CFrame.new(0, 0.03, 0)
		if now > v.Expire + VFXLib.held(id, v.ServerTime) then
			knives[id] = nil
			dropKnife(v)
		end
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
	TuskAnimation.play(character, "DIO_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1, -3.4), Duration = 0.28 })
	VFXLib.sound(sounds.Swing, root, 0.5, 1.0 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or pal.Second)
	fist((root.CFrame * CFrame.new(index % 2 == 0 and -0.6 or 0.6, 0.8, -1.8)).Position, root.CFrame.LookVector, 1.1)
	if index == 4 then
		word((root.CFrame * CFrame.new(0, 2, -3)).Position, "MUDA!", GOLD, true)
	end
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local drains = {} -- [character] = token

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "VampireDrain" then
		if phase == "Grab" and character and root then
			TuskAnimation.play(character, "DIODrain")
			TuskStand.action(character, "Loom", { Target = CFrame.new(1.4, 2.2, 1.6), Duration = data.Time or 1.6 })
			label(character:FindFirstChild("Head"), "WRYYYYY!", BLOOD_LIGHT, 1.4, 280)
			local token = {}
			drains[character] = token
			local target = data.Target
			-- Blood streams from them into his hand.
			local nextDrop = 0
			VFXLib.animate(data.Time or 1.6, function()
				local r = Common.rootOf(character)
				local tr = target and Common.rootOf(target)
				if drains[character] ~= token or not r or not tr then
					return
				end
				local now = os.clock()
				if now >= nextDrop then
					nextDrop = now + 0.04
					local from = tr.Position + Vector3.new((math.random() - 0.5) * 0.8, 0.5 + math.random() * 0.8, (math.random() - 0.5) * 0.8)
					local to = (r.CFrame * CFrame.new(0.9, 0.5, -1.2)).Position
					local drop = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.25, 0.25, 0.25), Color = BLOOD, Transparency = 0.05 })
					VFXLib.animate(0.28, function(a)
						local arc = from:Lerp(to, a) + Vector3.new(0, math.sin(a * math.pi) * 0.8, 0)
						drop.CFrame = CFrame.new(arc)
						drop.Transparency = a > 0.8 and (a - 0.8) / 0.2 or 0.05
					end, function()
						drop:Destroy()
					end)
				end
			end)
			if target then
				local h = Instance.new("Highlight")
				h.FillColor = BLOOD
				h.FillTransparency = 0.6
				h.OutlineColor = BLOOD_LIGHT
				h.OutlineTransparency = 0.3
				h.Adornee = target
				h.Parent = VFXLib.Folder
				task.delay((data.Time or 1.6) + 0.1, function()
					h:Destroy()
				end)
			end
		elseif phase == "Tick" and data.Target then
			local tr = Common.rootOf(data.Target)
			if tr then
				VFXLib.burst(tr.Position + Vector3.new(0, 0.8, 0), { Count = 6, Color = BLOOD_LIGHT, Speed = 6, Lifetime = 0.35, Acceleration = Vector3.new(0, -30, 0) })
			end
			if character and Common.isLocal(character) then
				CameraFX.impactFrame(Color3.fromRGB(255, 200, 200))
			end
		elseif phase == "End" and character then
			drains[character] = nil
		elseif phase == "Miss" and character and root then
			TuskAnimation.play(character, "DIODrain")
		end
	elseif move == "StingyEyes" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "DIOEyes")
			local head = character:FindFirstChild("Head")
			if head then
				label(head, "SPACE RIPPER STINGY EYES", STEEL, 1.4, 340)
				for _, side in ipairs({ -1, 1 }) do
					local glow = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.25, 0.25, 0.25), Color = Color3.new(1, 1, 1), Transparency = 0.2 })
					VFXLib.animate(data.Windup or 0.35, function(a)
						if head.Parent then
							glow.CFrame = head.CFrame * CFrame.new(side * 0.2, 0.1, -0.62)
							local d = 0.2 + a * 0.3
							glow.Size = Vector3.new(d, d, d)
						end
					end, function()
						glow:Destroy()
					end)
				end
			end
		elseif phase == "Fire" and data.From and data.Direction then
			local dir, length = data.Direction, data.Length or 60
			local right = dir:Cross(Vector3.new(0, 1, 0))
			right = right.Magnitude > 1e-3 and right.Unit or Vector3.new(1, 0, 0)
			for _, side in ipairs({ -1, 1 }) do
				local from = data.From + right * side * 0.2
				local beam = VFXLib.part({ Size = Vector3.new(0.14, 0.14, 1), Color = Color3.fromRGB(235, 250, 255), Transparency = 0 })
				local core = VFXLib.part({ Size = Vector3.new(0.3, 0.3, 1), Color = Color3.fromRGB(150, 220, 255), Transparency = 0.5 })
				VFXLib.animate(0.4, function(a)
					local out = math.min(a / 0.2, 1)
					local l = math.max(length * out, 0.3)
					local cf = CFrame.lookAt(from + dir * (l / 2), from + dir * l)
					beam.Size = Vector3.new(0.14 * (1 - a * 0.6), 0.14 * (1 - a * 0.6), l)
					beam.CFrame = cf
					core.Size = Vector3.new(0.3, 0.3, l)
					core.CFrame = cf
					beam.Transparency = a > 0.6 and (a - 0.6) / 0.4 or 0
					core.Transparency = 0.5 + 0.5 * a
				end, function()
					beam:Destroy()
					core:Destroy()
				end)
			end
			task.delay(0.08, function()
				VFXLib.burst(data.From + dir * length, { Count = 10, Color = Color3.fromRGB(220, 240, 255), Speed = 14, Lifetime = 0.3 })
			end)
			VFXLib.sound(sounds.NailFire, data.From, 0.6, 1.8)
			if character and Common.isLocal(character) then
				CameraFX.shake(0.25, 0.15)
			end
		end
	elseif move == "Knives" and phase == "Throw" and character and root then
		TuskAnimation.play(character, "DIOThrow")
		if data.Stopped then
			label(character:FindFirstChild("Head"), "MUDA MUDA!", GOLD, 1.0, 220)
		end
	end
end

---------------------------------------------------------------------------
-- ZA WARUDO: ROAD ROLLER
---------------------------------------------------------------------------
local function invertFlash()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "TheWorldInvert"
	cc.Parent = Lighting
	VFXLib.animate(0.45, function(a)
		local k = a < 0.5 and 1 or 1 - (a - 0.5) / 0.5
		cc.Saturation = -1 * k
		cc.Contrast = 0.6 * k
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(200, 255, 160), k)
		cc.Brightness = 0.15 * k
	end, function()
		cc:Destroy()
	end)
end

local function stillTint(duration)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "TheWorldStill"
	cc.Parent = Lighting
	VFXLib.animate(duration, function(a)
		local k = a < 0.08 and a / 0.08 or (a > 0.92 and (1 - a) / 0.08 or 1)
		cc.Saturation = -0.85 * k
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(235, 225, 190), k)
		cc.Contrast = 0.1 * k
	end, function()
		cc:Destroy()
	end)
	return cc
end

-- A road roller (blocky): a yellow body, a big grey drum in front, a cab.
local function rollerModel()
	local parts = {}
	local function add(props)
		local p = VFXLib.part(props)
		p.Material = props.Material or Enum.Material.SmoothPlastic
		table.insert(parts, { Part = p, Offset = props.Offset })
		return p
	end
	add({ Size = Vector3.new(7, 4, 9), Color = Color3.fromRGB(236, 190, 40), Offset = CFrame.new(0, 1.5, 1.5) })
	add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(7.4, 5, 5), Color = Color3.fromRGB(120, 124, 130), Material = Enum.Material.Metal, Offset = CFrame.new(0, 0, -4.5) })
	add({ Size = Vector3.new(7.6, 1, 4), Color = Color3.fromRGB(200, 150, 30), Offset = CFrame.new(0, 2.6, -4.5) })
	add({ Size = Vector3.new(4.5, 3.5, 4), Color = Color3.fromRGB(60, 60, 66), Offset = CFrame.new(0, 5, 3) })
	add({ Size = Vector3.new(5, 0.5, 4.6), Color = Color3.fromRGB(236, 190, 40), Offset = CFrame.new(0, 6.9, 3) })
	for _, x in ipairs({ -3.4, 3.4 }) do
		add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 3.6, 3.6), Color = Color3.fromRGB(30, 30, 34), Offset = CFrame.new(x, -0.6, 4) })
	end
	add({ Size = Vector3.new(6.5, 0.6, 0.2), Color = Color3.fromRGB(40, 40, 40), Offset = CFrame.new(0, 2.2, -2.3) })
	return parts
end

roller = function(character, at, fall)
	local parts = rollerModel()
	local sky = at + Vector3.new(0, 45, 0)
	local spin = math.random() * math.pi * 2
	if character and character:FindFirstChild("Head") then
		label(character:FindFirstChild("Head"), "ROAD ROLLER DA!", GOLD, 2.0, 380)
	end
	-- Its shadow on the ground, growing as it falls.
	local shadow = VFXLib.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 2, 2), Color = Color3.new(0, 0, 0), Material = Enum.Material.SmoothPlastic, Transparency = 0.5, CFrame = CFrame.new(at + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
	VFXLib.animate(fall + 1.0, function(a)
		local t = math.min(a * (fall + 1.0) / fall, 1)
		local pos = sky:Lerp(at + Vector3.new(0, 3, 0), t * t)
		local cf = CFrame.new(pos) * CFrame.Angles(0, spin, 0) * CFrame.Angles(math.rad(-20 * (1 - t)), 0, math.rad(12 * (1 - t)))
		for _, p in ipairs(parts) do
			p.Part.CFrame = cf * p.Offset
			if t >= 1 then
				local fade = (a * (fall + 1.0) - fall) / 1.0
				p.Part.Transparency = math.clamp(fade, 0, 1)
			end
		end
		local d = 4 + 10 * t
		shadow.Size = Vector3.new(0.1, d, d)
		shadow.Transparency = 0.7 - 0.3 * t
	end, function()
		for _, p in ipairs(parts) do
			p.Part:Destroy()
		end
		shadow:Destroy()
	end)
end

crash = function(character, at, radius)
	TuskVFX.CreateRotationalShockwave(CFrame.new(at), { Radius = radius * 1.4, Layers = 3, Color = GOLD, Color2 = Color3.fromRGB(150, 120, 80), Ground = true, Particles = 2, Width = 0.7 })
	TuskVFX.CreateGroundCracks(at, { Radius = radius, Color = Color3.fromRGB(120, 90, 50), Duration = 2 })
	VFXLib.burst(at + Vector3.new(0, 1, 0), { Count = 30, Color = Color3.fromRGB(180, 160, 120), Speed = 30, Lifetime = 0.8, Acceleration = Vector3.new(0, -50, 0) })
	word(at + Vector3.new(0, 6, 0), "WRYYY!", GOLD, true)
	if nearLocal(at, 80) then
		CameraFX.shake(1.2, 0.6)
	end
	VFXLib.sound(sounds.AwakeningBurst or sounds.Swing, at, 0.8, 0.6)
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character and root then
		TuskAnimation.play(character, "DIOZaWarudo")
		TuskStand.action(character, "Loom", { Target = CFrame.new(1.4, 2.6, 2.2), Duration = (data.Windup or 0.7) + 0.6 })
		label(character:FindFirstChild("Head"), "ZA WARUDO!", GOLD, 2.0, 360)
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 0.9)
	elseif data.Phase == "Stop" and data.Position then
		local center, range, duration = data.Position, data.Range or 55, data.Duration or 5
		local stop = { Frozen = {} }
		if character then
			stops[character] = stop
		end
		-- The dome spreads out from him.
		local dome = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(center), Color = GOLD, Material = Enum.Material.ForceField, Transparency = 0.3 })
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
				h.Name = "TheWorldFrozen"
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
	elseif data.Phase == "Roller" and data.Position then
		roller(character, data.Position, data.Fall or 0.55)
	elseif data.Phase == "Crash" and data.Position then
		crash(character, data.Position, data.Radius or 9)
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
			local ring = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(data.Position), Color = Color3.fromRGB(255, 244, 200), Material = Enum.Material.ForceField, Transparency = 0.4 })
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
			label(character:FindFirstChild("Head"), "TOKI WA UGOKIDASU", Color3.new(1, 1, 1), 1.4, 300)
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
				TuskAnimation.hold(character, "DIOStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "DIOStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function DioVFX.handle(name, data)
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
function DioVFX.step(dt)
	dt = dt or 1 / 60
	stepKnives()
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
	end
end

Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
	if typeof(data) ~= "table" or data.Kind ~= "DioKnife" then
		return
	end
	if name == "ProjectileSpawn" then
		spawnKnife(data)
	elseif name == "ProjectileEnd" then
		endKnife(data)
	end
end)

return DioVFX
end

-- ======================================================================
-- MODULE: TheWorldDioStand
-- ======================================================================
__modules["TheWorldDioStand"] = function()
--[[
	TuskActVFX.TheWorldDioStand  (StarterPlayerScripts.SpinClient.TuskActVFX.TheWorldDioStand)

	THE WORLD (DIO, Part 3), blocky. A different Stand from Diego's The
	World (TheWorldStand, the padded knight from Part 7):
	  * a tall, muscular GOLDEN body with sharp green trim lines
	  * the head: a helmet with a crest sweeping back to a point, a
	    FACEPLATE over the mouth (green seams), narrow white eyes, small
	    fins at the ears
	  * two HOSES running from the back of its head down into its back
	  * rounded gold shoulder guards rimmed in green; green wrist and
	    ankle bands; a gold belt with a green buckle
	  * HEART-shaped guards on both knees, and a heart on its chest
	Registered with TuskStandModels by DioVFX, so TuskStand floats it
	behind DIO with a golden aura.
]]

local TheWorldDioStand = {}

local GOLD = Color3.fromRGB(240, 200, 60)
local GOLD_SHADE = Color3.fromRGB(198, 154, 38)
local GOLD_LIGHT = Color3.fromRGB(255, 228, 120)
local GREEN = Color3.fromRGB(56, 156, 112)
local GREEN_DARK = Color3.fromRGB(30, 100, 72)
local LINE = Color3.fromRGB(110, 80, 20)
local EYE = Color3.fromRGB(255, 252, 235)
local HOSE = Color3.fromRGB(48, 120, 90)

TheWorldDioStand.Aura = Color3.fromRGB(255, 214, 70)
TheWorldDioStand.AuraLight = Color3.fromRGB(255, 244, 190)
TheWorldDioStand.Offset = CFrame.new(2.2, 1.6, 2.8)

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

-- A rod from a to b in the parent's space.
local function rod(model, parent, name, a, b, d, color)
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	local p = box(model, parent, name, Vector3.new(len + d * 0.4, d, d), color, CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A heart facing forward (-Z of `cf`): two lobes and a point, green rim.
local function heart(model, parent, cf, size, s)
	local h = size * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, parent, "HeartLobe", Vector3.new(0.09 * s, h * 0.6, h * 0.6), GOLD_LIGHT, cf * CFrame.new(side * h * 0.2, h * 0.14, -0.01 * s) * CFrame.Angles(0, math.pi / 2, 0)).Shape = Enum.PartType.Cylinder
		box(model, parent, "HeartLobeRim", Vector3.new(0.07 * s, h * 0.72, h * 0.72), GREEN, cf * CFrame.new(side * h * 0.2, h * 0.14, 0.02 * s) * CFrame.Angles(0, math.pi / 2, 0)).Shape = Enum.PartType.Cylinder
	end
	box(model, parent, "HeartPoint", Vector3.new(h * 0.56, h * 0.56, 0.09 * s), GOLD_LIGHT, cf * CFrame.new(0, -h * 0.1, -0.01 * s) * CFrame.Angles(0, 0, math.pi / 4))
	box(model, parent, "HeartRim", Vector3.new(h * 0.74, h * 0.74, 0.06 * s), GREEN, cf * CFrame.new(0, -h * 0.1, 0.02 * s) * CFrame.Angles(0, 0, math.pi / 4))
end

function TheWorldDioStand.build(scale)
	local s = (scale or 1) * 0.9
	local model = Instance.new("Model")
	model.Name = "TheWorldDio"
	local rig = { Joints = {} }

	local torso = newPart(model, "Body", Vector3.new(2.3, 1.9, 1.12) * s, GOLD)
	torso.Reflectance = 0.12
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.56 * s
	-- Chest plates with green trim lines, a heart in the middle.
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Pec", Vector3.new(0.95, 0.6, 0.12) * s, GOLD_LIGHT, CFrame.new(side * 0.5 * s, 0.42 * s, front - 0.03 * s))
		box(model, torso, "Trim", Vector3.new(0.06, 1.5, 0.13) * s, GREEN, CFrame.new(side * 0.98 * s, -0.05 * s, front - 0.04 * s) * CFrame.Angles(0, 0, side * 0.12))
		box(model, torso, "TrimV", Vector3.new(0.06, 0.9, 0.13) * s, GREEN, CFrame.new(side * 0.32 * s, -0.75 * s, front - 0.04 * s) * CFrame.Angles(0, 0, side * -0.35))
	end
	heart(model, torso, CFrame.new(0, 0.1 * s, front - 0.08 * s), 0.5, s)
	box(model, torso, "Waist", Vector3.new(1.6, 0.85, 0.92) * s, GOLD_SHADE, CFrame.new(0, -1.3 * s, 0))
	for k = 0, 2 do
		for _, side in ipairs({ -1, 1 }) do
			box(model, torso, "Ab", Vector3.new(0.36, 0.22, 0.06) * s, GOLD_LIGHT, CFrame.new(side * 0.21 * s, (-0.38 - k * 0.28) * s, front - 0.02 * s))
		end
	end
	box(model, torso, "Belt", Vector3.new(1.72, 0.28, 1.0) * s, GOLD_SHADE, CFrame.new(0, -1.68 * s, 0))
	box(model, torso, "Buckle", Vector3.new(0.42, 0.3, 0.08) * s, GREEN, CFrame.new(0, -1.68 * s, -0.52 * s))
	box(model, torso, "Hips", Vector3.new(1.7, 0.5, 0.95) * s, GOLD, CFrame.new(0, -2.0 * s, 0))
	box(model, torso, "Neck", Vector3.new(0.55, 0.45, 0.55) * s, GOLD_SHADE, CFrame.new(0, 1.12 * s, 0))

	-- Head: crest sweeping back, faceplate over the mouth, narrow eyes.
	local headBase = CFrame.new(0, 1.3 * s, 0)
	local headOffset = CFrame.new(0, 0.52 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.78, 0.95, 0.82) * s, GOLD, headBase * headOffset)
	head.Reflectance = 0.1
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.41 * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.22, 0.07, 0.05) * s, EYE, CFrame.new(side * 0.17 * s, 0.1 * s, hf - 0.02 * s) * CFrame.Angles(0, 0, side * -0.2), Enum.Material.Neon)
		box(model, head, "Brow", Vector3.new(0.28, 0.07, 0.07) * s, LINE, CFrame.new(side * 0.17 * s, 0.17 * s, hf - 0.03 * s) * CFrame.Angles(0, 0, side * -0.2))
		box(model, head, "Fin", Vector3.new(0.08, 0.45, 0.4) * s, GOLD_LIGHT, CFrame.new(side * 0.43 * s, 0.05 * s, 0.05 * s) * CFrame.Angles(0, 0, side * -0.3))
	end
	-- The faceplate: a mask over the lower face with green seams.
	box(model, head, "Faceplate", Vector3.new(0.7, 0.38, 0.1) * s, GOLD_LIGHT, CFrame.new(0, -0.24 * s, hf - 0.04 * s))
	for _, x in ipairs({ -0.18, 0, 0.18 }) do
		box(model, head, "Seam", Vector3.new(0.03, 0.34, 0.11) * s, GREEN_DARK, CFrame.new(x * s, -0.24 * s, hf - 0.045 * s))
	end
	box(model, head, "Nose", Vector3.new(0.1, 0.18, 0.08) * s, GOLD_SHADE, CFrame.new(0, 0.0, hf - 0.04 * s))
	-- Helmet cap and the crest sweeping back to a point.
	box(model, head, "Helmet", Vector3.new(0.86, 0.28, 0.9) * s, GOLD_SHADE, CFrame.new(0, 0.42 * s, 0.02 * s))
	box(model, head, "HelmetRim", Vector3.new(0.88, 0.07, 0.92) * s, GREEN, CFrame.new(0, 0.29 * s, 0.02 * s))
	for k = 0, 3 do
		local f = k / 3
		box(model, head, "Crest", Vector3.new((0.5 - f * 0.3) * s, (0.22 - f * 0.08) * s, (0.5 + f * 0.1) * s), k % 2 == 0 and GOLD_LIGHT or GOLD, CFrame.new(0, (0.58 + f * 0.25) * s, (0.05 + f * 0.45) * s) * CFrame.Angles(math.rad(-25 - f * 15), 0, 0))
	end
	box(model, head, "CrestTip", Vector3.new(0.12, 0.12, 0.4) * s, GREEN, CFrame.new(0, 0.86 * s, 0.75 * s) * CFrame.Angles(math.rad(-40), 0, 0))
	-- Two hoses from the back of the head down into its back.
	for _, side in ipairs({ -1, 1 }) do
		local a = Vector3.new(side * 0.22, 1.8, 0.42) * s
		local m = Vector3.new(side * 0.32, 1.4, 0.85) * s
		local b = Vector3.new(side * 0.45, 0.7, 0.6) * s
		rod(model, torso, "Hose", a, m, 0.14 * s, HOSE)
		rod(model, torso, "Hose", m, b, 0.14 * s, HOSE)
		ball(model, torso, "HoseBend", 0.14 * s, HOSE, CFrame.new(m))
		ball(model, torso, "HosePlug", 0.22 * s, GREEN_DARK, CFrame.new(b))
	end

	-- Arms: rounded shoulder guards rimmed in green, green wrist bands.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		box(model, torso, "ShoulderGuard", Vector3.new(0.95, 0.55, 1.0) * s, GOLD_LIGHT, CFrame.new(side * 1.45 * s, 0.78 * s, 0) * CFrame.Angles(0, 0, side * -0.25))
		box(model, torso, "ShoulderRim", Vector3.new(0.98, 0.08, 1.03) * s, GREEN, CFrame.new(side * 1.47 * s, 0.55 * s, 0) * CFrame.Angles(0, 0, side * -0.25))
		local base = CFrame.new(side * 1.5 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.68, 2.2, 0.68) * s, GOLD, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Bicep", Vector3.new(0.76, 0.7, 0.76) * s, GOLD_LIGHT, CFrame.new(0, 0.5 * s, -0.02 * s))
		box(model, arm, "ArmLine", Vector3.new(0.05, 1.6, 0.05) * s, GREEN, CFrame.new(side * 0.36 * s, 0.1 * s, 0))
		box(model, arm, "Forearm", Vector3.new(0.76, 0.75, 0.76) * s, GOLD_SHADE, CFrame.new(0, -0.5 * s, 0))
		box(model, arm, "WristBand", Vector3.new(0.82, 0.18, 0.82) * s, GREEN, CFrame.new(0, -0.88 * s, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.62, 0.56, 0.58) * s, GOLD, CFrame.new(0, -1.3 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.12, 0.36, 0.12) * s, GOLD_SHADE, CFrame.new(f * 0.14 * s, -0.38 * s, -0.06 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: heart-shaped knee guards, green ankle bands.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.48 * s, -2.15 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.72, 2.4, 0.72) * s, GOLD, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Thigh", Vector3.new(0.82, 0.9, 0.82) * s, GOLD_LIGHT, CFrame.new(0, 0.68 * s, 0))
		heart(model, leg, CFrame.new(0, 0.0, -0.42 * s), 0.6, s)
		box(model, leg, "Shin", Vector3.new(0.7, 0.75, 0.74) * s, GOLD_SHADE, CFrame.new(0, -0.6 * s, 0))
		box(model, leg, "AnkleBand", Vector3.new(0.78, 0.16, 0.78) * s, GREEN, CFrame.new(0, -1.05 * s, 0))
		box(model, leg, "Foot", Vector3.new(0.66, 0.3, 1.0) * s, GOLD_SHADE, CFrame.new(0, -1.3 * s, -0.17 * s))
	end
	return model, rig
end

return TheWorldDioStand
end
end
