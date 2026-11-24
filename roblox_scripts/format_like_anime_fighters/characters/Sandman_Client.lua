--[[
	Sandman_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Sandman (Soundman): In a Silent Way.
	Its other half is Sandman_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: SandmanVFX
-- ======================================================================
__modules["SandmanVFX"] = function()
--[[
	TuskActVFX.SandmanVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.SandmanVFX)

	Client visuals for Sandman (Soundman) / IN A SILENT WAY: sounds become
	solid, written sound effects (blocky 3D words) that do what they say.
	  * M1: chops and a kick, each hit pops a written sound ("ZAN!", "DOGO!")
	  * SOUND SLASH: "ZBAAK!" skims along the ground, cutting what it touches
	  * SOUND TRAP: "DOGOOON" lies on the ground, pulsing; it explodes when stepped near
	  * SAND RUN: a sprint with a sand trail, "ZAZAZA" along the path
	  * the IN A SILENT WAY Stand (SilentWayStand) floats behind him and
	    strikes with his moves
	  * SILENT SYMPHONY: sounds gather around him, rain down, then "DOOOOM!!"
]]

local Fighters = __require("Fighters")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Common = __require("TuskActCommon")
local TuskStand = __require("TuskStand")
local SilentWayStand = __require("SilentWayStand")
local TuskStandModels = __require("TuskStandModels")

-- IN A SILENT WAY floats behind him (players and NPCs), like Tusk does.
TuskStandModels.register(8, SilentWayStand.build, { Aura = SilentWayStand.Aura, AuraLight = SilentWayStand.AuraLight, Offset = SilentWayStand.Offset })

local SandmanVFX = {}
local ACT = 8
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds

local SAND = Color3.fromRGB(225, 190, 130)
local INK = Color3.fromRGB(30, 25, 35)
local FIRE = Color3.fromRGB(255, 120, 50)

local words = {} -- [projectile id] = flying word
local traps = {} -- [trap id] = word lying on the ground
local stanced = {}

---------------------------------------------------------------------------
-- Written sounds: a blocky 3D word (front face + a darker "extruded" back)
---------------------------------------------------------------------------
local function face(part, normal, text, color, stroke)
	local gui = Instance.new("SurfaceGui")
	gui.Face = normal
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = stroke
	label.TextStrokeTransparency = 0
	label.Parent = gui
	return label
end

local function newWord(text, height, color)
	color = color or pal.Main
	local m = Instance.new("Model")
	m.Name = "SoundWord"
	m.Parent = VFXLib.Folder
	local size = Vector3.new(math.max(#text, 2) * height * 0.62, height, 0.1)
	local front = VFXLib.part({ Size = size, Transparency = 1 })
	front.Parent = m
	local labels = { face(front, Enum.NormalId.Front, text, color, INK), face(front, Enum.NormalId.Back, text, color, INK) }
	-- The "solid" depth: the same word, darker, a little behind.
	for k = 1, 2 do
		local depth = VFXLib.part({ Size = size, Transparency = 1, CFrame = front.CFrame * CFrame.new(0, -0.06 * k * height, 0.12 * k * height) })
		depth.Parent = m
		local dark = color:Lerp(INK, 0.35 + k * 0.2)
		table.insert(labels, face(depth, Enum.NormalId.Front, text, dark, dark))
		table.insert(labels, face(depth, Enum.NormalId.Back, text, dark, dark))
	end
	m.PrimaryPart = front
	return { Model = m, Labels = labels, Height = height }
end

local function setWordFade(w, t)
	for _, l in ipairs(w.Labels) do
		l.TextTransparency = t
		l.TextStrokeTransparency = math.max(t, 0)
	end
end

-- A word that pops out at `position`, grows, floats up and fades.
local function popWord(text, position, height, color, facing, duration)
	local w = newWord(text, height or 1.6, color)
	local look = facing or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position) or position + Vector3.new(0, 0, -1)
	local tilt = (math.random() - 0.5) * 0.5
	VFXLib.animate(duration or 0.55, function(a)
		local grow = a < 0.2 and VFXLib.easeOut(a / 0.2) * 1.15 or 1.15 - (a - 0.2) * 0.2
		local p = position + Vector3.new(0, a * 1.6, 0)
		w.Model:PivotTo(CFrame.lookAt(p, Vector3.new(look.X, p.Y, look.Z)) * CFrame.Angles(0, 0, tilt) * CFrame.new(0, 0, 0))
		w.Model:ScaleTo(math.max(grow, 0.05))
		setWordFade(w, a > 0.65 and (a - 0.65) / 0.35 or 0)
	end, function()
		w.Model:Destroy()
	end)
end

local function sandBurst(position, count, speed)
	VFXLib.burst(position, { Count = count or 12, Texture = VFXLib.Textures.Smoke, Color = SAND, LightEmission = 0, Speed = speed or 14, Lifetime = 0.7, Acceleration = Vector3.new(0, -10, 0) })
end

---------------------------------------------------------------------------
-- Flying words (server Kind "SoundWord")
---------------------------------------------------------------------------
local function spawnWord(data)
	local text = data.Visual and data.Visual.Text or "ZBAAK!"
	words[data.Id] = {
		Word = newWord(text, 2.2, pal.Main),
		Origin = data.Origin,
		Direction = data.Direction,
		Speed = data.Speed,
		Range = data.Range,
		ServerTime = data.ServerTime,
		Expire = os.clock() + data.Range / math.max(data.Speed, 1) + 1,
		NextDust = 0,
	}
end

local function endWord(data)
	local v = words[data.Id]
	if v then
		words[data.Id] = nil
		v.Word.Model:Destroy()
	end
	local pos = data.Position
	TuskVFX.CreateCrescent(CFrame.lookAt(pos, pos + (v and v.Direction or Vector3.new(0, 0, -1))), { Radius = 3, Width = 0.35, Color = pal.Main, Color2 = Color3.new(1, 1, 1), Sweep = 2.4, Duration = 0.22 })
	popWord(data.HitCharacter and "ZAN!!" or "ZAK", pos + Vector3.new(0, 1.5, 0), data.HitCharacter and 1.8 or 1.2, data.HitCharacter and pal.Main or SAND)
	sandBurst(pos, 10, 16)
	VFXLib.sound(sounds.NailImpact, pos, 0.4, 1.2)
	if data.HitCharacter then
		CameraFX.shakeAt(pos, 0.35, 40)
	end
end

local function stepWords()
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for id, v in pairs(words) do
		local distance = math.min(v.Speed * VFXLib.flight(id, v.ServerTime), v.Range)
		local pos = v.Origin + v.Direction * math.max(distance, 0)
		local wobble = math.sin(distance * 0.6) * 0.15
		-- Skims along edge-on like a blade, tilted slightly.
		v.Word.Model:PivotTo(CFrame.lookAt(pos, pos + v.Direction) * CFrame.Angles(0, math.pi / 2, wobble))
		if now >= v.NextDust then
			v.NextDust = now + 0.06
			sandBurst(pos - Vector3.new(0, 1, 0), 3, 6)
		end
		if now > v.Expire + VFXLib.held(id, v.ServerTime) then
			words[id] = nil
			v.Word.Model:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------------
local M1_WORDS = { "ZAN!", "ZASH!", "DOGO!", "DOGOOO!" }

local function onM1(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local index = data.Index
	TuskAnimation.play(character, "S_M1_" .. index)
	-- The Stand strikes with him.
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1, -3), Duration = 0.3 })
	VFXLib.sound(sounds.Swing, root, 0.5, 1.05 + index * 0.06)
	local side = index % 2 == 1 and 1 or -1
	if index <= 2 then
		Common.swipe(root, side, index == 1 and pal.Main or pal.Light)
	elseif index == 3 then
		TuskVFX.CreateCrescent(root.CFrame * CFrame.new(0, -1.4, 0), { Radius = 4, Width = 0.4, Arc = math.rad(220), Sweep = 3, Color = pal.Main, Color2 = SAND, Duration = 0.26 })
		sandBurst(root.Position - Vector3.new(0, 2.6, 0), 10, 12)
	end
	task.delay(0.1, function()
		if root.Parent and index < 4 then
			popWord(M1_WORDS[index], (root.CFrame * CFrame.new(side * 0.8, 1, -3)).Position, 1.1, index == 3 and SAND or pal.Main)
		end
	end)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "SoundSlash" and phase == "Startup" and character then
		TuskAnimation.play(character, "SandSlash")
		TuskStand.action(character, "Lunge", { Duration = 0.4 })
		if root then
			popWord("SHH...", (root.CFrame * CFrame.new(0, 2.5, -1)).Position, 0.9, pal.Light, nil, 0.4)
		end
	elseif move == "SoundTrap" then
		if phase == "Startup" and character then
			TuskAnimation.play(character, "SandTrap")
			TuskStand.action(character, "Lunge", { Duration = 0.45 })
		elseif phase == "Place" then
			local w = newWord("DOGOOON", 1.6, FIRE)
			local spin = math.random() * math.pi * 2
			traps[data.Id] = { Word = w, Position = data.Position, Spin = spin, T = 0, Expire = os.clock() + (data.Lifetime or 15) + 1 }
			sandBurst(data.Position, 8, 8)
			VFXLib.sound(sounds.Warning, data.Position, 0.25, 0.8)
		elseif phase == "Boom" or phase == "Expire" then
			local trap = traps[data.Id]
			if trap then
				traps[data.Id] = nil
				trap.Word.Model:Destroy()
			end
			if phase == "Boom" then
				local pos = data.Position + Vector3.new(0, 1, 0)
				TuskVFX.CreateImpact(pos, Vector3.new(0, 1, 0), { Size = 1.8, Radius = data.Radius or 8, Layers = 3, Color = FIRE, Color2 = pal.Light, Sound = sounds.Finisher, Pitch = 0.8 })
				VFXLib.burst(pos, { Count = 30, Color = FIRE, Speed = 40, Lifetime = 0.6 })
				VFXLib.burst(pos, { Count = 16, Texture = VFXLib.Textures.Smoke, Color = Color3.fromRGB(70, 60, 55), LightEmission = 0, Speed = 18, Lifetime = 1.2, Acceleration = Vector3.new(0, 8, 0) })
				TuskVFX.CreateGroundCracks(data.Position, { Radius = (data.Radius or 8) * 0.9, Count = 7, Color = FIRE, Duration = 1.4 })
				VFXLib.flash(pos, FIRE, 6, 30, 0.3)
				popWord("DOGOOON!!", pos + Vector3.new(0, 3, 0), 3, FIRE, nil, 0.8)
				CameraFX.shakeAt(pos, 0.7, 60)
			end
		end
	elseif move == "SandRun" then
		if phase == "Startup" and character then
			TuskAnimation.play(character, "SandRun")
			TuskStand.action(character, "Lunge", { Duration = 0.5 })
			if root then
				sandBurst(root.Position - Vector3.new(0, 2.6, 0), 14, 18)
			end
		elseif phase == "Run" then
			local from, to = data.From, data.To
			local steps = math.max(3, math.floor((to - from).Magnitude / 4))
			for i = 0, steps do
				local p = from:Lerp(to, i / steps)
				task.delay(i * 0.015, function()
					sandBurst(p - Vector3.new(0, 2.4, 0), 6, 10)
					VFXLib.afterimage(CFrame.lookAt(p, p + data.Direction), 2, SAND)
				end)
			end
			popWord("ZAZAZAZA", from:Lerp(to, 0.5) + Vector3.new(0, 3, 0), 1.6, SAND, nil, 0.7)
			for _, target in ipairs(data.Targets or {}) do
				local tr = Common.rootOf(target)
				if tr then
					popWord("DOM!", tr.Position + Vector3.new(0, 2, 0), 1.4, pal.Main)
					TuskVFX.CreateImpactStar(tr.Position, { Size = 4, Rays = 7, Color = pal.Main, Color2 = SAND, Duration = 0.2 })
				end
			end
			VFXLib.sound(sounds.Swing, to, 0.6, 0.8)
			if Common.isLocal(character) then
				CameraFX.speedLines(0.3, SAND)
				CameraFX.fovPunch(8, 0.25)
			end
		end
	end
end

local GATHER = { "GOGOGO", "ZZZ", "DOOO", "KIN", "BAAN", "ZAA" }

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Start" then
		TuskAnimation.play(character, "SandSymphony")
		TuskStand.action(character, "Manifest", { Duration = 0.9 })
		if root then
			-- Sounds gather round him, orbiting.
			local list = {}
			for i, text in ipairs(GATHER) do
				list[i] = newWord(text, 1.2, i % 2 == 0 and pal.Main or pal.Light)
			end
			VFXLib.animate(data.Windup or 1, function(a)
				if not root.Parent then
					return
				end
				for i, w in ipairs(list) do
					local ang = i / #list * math.pi * 2 + a * 6
					local r = 6 - a * 3
					local p = root.Position + Vector3.new(math.cos(ang) * r, 1 + math.sin(a * 8 + i) * 0.6, math.sin(ang) * r)
					w.Model:PivotTo(CFrame.lookAt(p, root.Position + Vector3.new(0, 1, 0)))
					setWordFade(w, a > 0.85 and (a - 0.85) / 0.15 or 0)
				end
			end, function()
				for _, w in ipairs(list) do
					w.Model:Destroy()
				end
			end)
			TuskVFX.CreateGroundCracks(data.Position, { Radius = data.Radius or 13, Count = 4, Color = pal.Second, Duration = (data.Windup or 1) + 1.5 })
		end
		if Common.isLocal(character) then
			TuskVFX.ScreenTint(data.Windup or 1, { Tint = Color3.fromRGB(255, 230, 190), Saturation = -0.5 })
		end
	elseif data.Phase == "Wave" then
		-- Written sounds rain down on the area.
		local center, radius = data.Position, data.Radius or 13
		for k = 1, 3 do
			local a = math.random() * math.pi * 2
			local d = math.random() * radius * 0.8
			local spot = center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
			local w = newWord(GATHER[math.random(1, #GATHER)], 1.8, k % 2 == 0 and pal.Main or FIRE)
			VFXLib.animate(0.22, function(t)
				local p = spot + Vector3.new(0, 14 * (1 - t), 0)
				w.Model:PivotTo(CFrame.new(p) * CFrame.Angles(-math.pi / 2 * t, a, 0))
			end, function()
				w.Model:Destroy()
				VFXLib.burst(spot + Vector3.new(0, 0.5, 0), { Count = 10, Color = k % 2 == 0 and pal.Main or FIRE, Speed = 24, Lifetime = 0.35 })
				sandBurst(spot, 6, 10)
			end)
		end
		CameraFX.shakeAt(center, 0.35, 50)
	elseif data.Phase == "Final" then
		local pos = data.Position + Vector3.new(0, 1, 0)
		Common.finisher({ Character = character, Position = pos, Radius = data.Radius, Hit = true }, pal, { Size = 1.8, Layers = 3, Shake = 1 })
		VFXLib.burst(pos, { Count = 40, Color = FIRE, Speed = 50, Lifetime = 0.7 })
		popWord("DOOOOM!!", pos + Vector3.new(0, 5, 0), 4, FIRE, nil, 1.1)
		if Common.isLocal(character) then
			CameraFX.impactFrame(pal.Light)
		end
	end
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local function stepTraps(dt)
	local now = os.clock()
	for id, trap in pairs(traps) do
		if now > trap.Expire then
			traps[id] = nil
			trap.Word.Model:Destroy()
		else
			trap.T = trap.T + dt
			-- Lies flat on the ground, breathing like it's about to go off.
			local p = trap.Position + Vector3.new(0, 0.25, 0)
			trap.Word.Model:PivotTo(CFrame.new(p) * CFrame.Angles(0, trap.Spin, 0) * CFrame.Angles(-math.pi / 2, 0, 0))
			trap.Word.Model:ScaleTo(1 + math.sin(trap.T * 6) * 0.08)
		end
	end
end

local function stepStance()
	for _, player in ipairs(Fighters.list()) do
		local character = player.Character
		if character then
			local want = character:GetAttribute("TuskAct") == ACT
			if want and not stanced[character] then
				stanced[character] = true
				TuskAnimation.hold(character, "SandStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "SandStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function SandmanVFX.handle(name, data)
	if name == "M1" then
		onM1(data)
	elseif name == "M1Finisher" then
		Common.finisher(data, pal)
		popWord("DOGOOO!", data.Position + Vector3.new(0, 2, 0), 2, pal.Main, nil, 0.7)
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

local slowTimer = 0
function SandmanVFX.step(dt)
	dt = dt or 1 / 60
	stepWords()
	stepTraps(dt)
	slowTimer = slowTimer + dt
	if slowTimer > 0.2 then
		slowTimer = 0
		stepStance()
	end
end

Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
	if typeof(data) ~= "table" or data.Kind ~= "SoundWord" then
		return
	end
	if name == "ProjectileSpawn" then
		spawnWord(data)
	elseif name == "ProjectileEnd" then
		endWord(data)
	end
end)

return SandmanVFX
end

-- ======================================================================
-- MODULE: SilentWayStand
-- ======================================================================
__modules["SilentWayStand"] = function()
--[[
	TuskActVFX.SilentWayStand  (StarterPlayerScripts.SpinClient.TuskActVFX.SilentWayStand)

	The IN A SILENT WAY Stand model (Sandman), blocky, matched to the art:
	  * a golden armoured body with six orange roses down the chest
	  * a skull face under a gold helmet with round orange goggle eyes and a
	    spiral emblem on the forehead
	  * a huge feather headdress: white feathers with dark red tips
	  * big gold shoulder pads, gold arms with zigzag bands, bony white hands
	  * a gold skirt with zigzags and spirals, patterned gold legs
	Registered with TuskStandModels by SandmanVFX, so TuskStand floats it
	behind Sandman (players and NPCs) with a golden aura, exactly like Tusk.
	A custom model at ReplicatedStorage.SpinAssets.TuskAct8 replaces it.
]]

local SilentWayStand = {}

local GOLD = Color3.fromRGB(232, 182, 52)
local GOLD_DARK = Color3.fromRGB(170, 116, 30)
local ORANGE = Color3.fromRGB(236, 120, 44)
local ROSE = Color3.fromRGB(214, 84, 44)
local ROSE_DARK = Color3.fromRGB(140, 40, 28)
local BONE = Color3.fromRGB(238, 230, 212)
local BONE_DARK = Color3.fromRGB(190, 178, 156)
local DARK = Color3.fromRGB(46, 28, 22)
local FEATHER = Color3.fromRGB(242, 238, 228)
local FEATHER_TIP = Color3.fromRGB(122, 38, 30)
local EYE = Color3.fromRGB(255, 120, 40)

SilentWayStand.Aura = Color3.fromRGB(255, 196, 70)
SilentWayStand.AuraLight = Color3.fromRGB(255, 240, 180)
SilentWayStand.Offset = CFrame.new(2.7, 1.7, 3.3) -- big: floats further back

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

-- A box welded to `parent` at local `cf` (the Weld's C0 can be animated).
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

-- A blocky rose facing -Z at `cf`.
local function rose(model, parent, cf, s)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		box(model, parent, "Petal", Vector3.new(0.3, 0.3, 0.12) * s, i % 2 == 0 and ROSE or ORANGE, cf * CFrame.new(math.cos(a) * 0.13 * s, math.sin(a) * 0.13 * s, 0) * CFrame.Angles(0, 0, a))
	end
	box(model, parent, "Petal", Vector3.new(0.26, 0.26, 0.12) * s, ORANGE, cf * CFrame.new(0, 0, -0.05 * s) * CFrame.Angles(0, 0, math.pi / 4))
	box(model, parent, "RoseCore", Vector3.new(0.13, 0.13, 0.1) * s, ROSE_DARK, cf * CFrame.new(0, 0, -0.1 * s))
end

-- A square spiral (ring + centre) facing -Z at `cf`.
local function spiral(model, parent, cf, size, color)
	local t = size * 0.18
	box(model, parent, "Spiral", Vector3.new(size, t, 0.05), color, cf * CFrame.new(0, size / 2 - t / 2, 0))
	box(model, parent, "Spiral", Vector3.new(size, t, 0.05), color, cf * CFrame.new(0, -size / 2 + t / 2, 0))
	box(model, parent, "Spiral", Vector3.new(t, size, 0.05), color, cf * CFrame.new(size / 2 - t / 2, 0, 0))
	box(model, parent, "Spiral", Vector3.new(t, size * 0.6, 0.05), color, cf * CFrame.new(-size / 2 + t / 2, -size * 0.2, 0))
	box(model, parent, "Spiral", Vector3.new(t * 1.4, t * 1.4, 0.05), color, cf)
end

-- A row of zigzag diamonds across a face.
local function zigzag(model, parent, cf, width, count, color, s)
	for i = 0, count - 1 do
		local x = (i - (count - 1) / 2) * width / count
		box(model, parent, "Zigzag", Vector3.new(0.16, 0.16, 0.04) * s, color, cf * CFrame.new(x, 0, 0) * CFrame.Angles(0, 0, math.pi / 4))
	end
end

function SilentWayStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "InASilentWay"
	local rig = { Joints = {} }

	-- Torso (the anchored root the Stand is moved by).
	local torso = newPart(model, "Body", Vector3.new(2.4, 2.2, 1.2) * s, GOLD)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.6 * s
	box(model, torso, "Collar", Vector3.new(2.6, 0.32, 1.32) * s, GOLD_DARK, CFrame.new(0, 1.0 * s, 0))
	box(model, torso, "Chest", Vector3.new(1.9, 1.5, 0.12) * s, GOLD_DARK, CFrame.new(0, 0.1 * s, front - 0.04 * s))
	-- Six roses down the chest.
	for _, x in ipairs({ -0.5, 0.5 }) do
		for _, y in ipairs({ 0.6, 0.05, -0.5 }) do
			rose(model, torso, CFrame.new(x * s, y * s, front - 0.14 * s), s * 1.1)
		end
	end
	box(model, torso, "Belt", Vector3.new(2.5, 0.3, 1.3) * s, GOLD_DARK, CFrame.new(0, -1.0 * s, 0))
	-- Skirt with zigzags and spirals.
	box(model, torso, "Skirt", Vector3.new(2.5, 1.5, 1.36) * s, GOLD, CFrame.new(0, -1.85 * s, 0))
	box(model, torso, "SkirtHem", Vector3.new(2.6, 0.18, 1.44) * s, GOLD_DARK, CFrame.new(0, -2.55 * s, 0))
	zigzag(model, torso, CFrame.new(0, -1.4 * s, -0.7 * s), 2.2 * s, 9, ORANGE, s)
	zigzag(model, torso, CFrame.new(0, -2.25 * s, -0.7 * s), 2.2 * s, 9, DARK, s)
	for _, x in ipairs({ -0.7, 0.7 }) do
		spiral(model, torso, CFrame.new(x * s, -1.85 * s, -0.71 * s), 0.42 * s, DARK)
	end

	-- Head: a skull under a gold helmet.
	local headBase = CFrame.new(0, 1.15 * s, 0)
	local headOffset = CFrame.new(0, 0.62 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(1.1, 1.2, 1.1) * s, BONE, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.55 * s
	box(model, head, "Helmet", Vector3.new(1.26, 0.6, 1.26) * s, GOLD, CFrame.new(0, 0.38 * s, 0))
	box(model, head, "Visor", Vector3.new(1.24, 0.46, 0.12) * s, GOLD, CFrame.new(0, 0.12 * s, hf - 0.06 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.34, 0.34, 0.08) * s, EYE, CFrame.new(side * 0.28 * s, 0.1 * s, hf - 0.14 * s), Enum.Material.Neon)
		box(model, head, "EyeRim", Vector3.new(0.42, 0.06, 0.06) * s, GOLD_DARK, CFrame.new(side * 0.28 * s, 0.3 * s, hf - 0.14 * s))
		box(model, head, "Pupil", Vector3.new(0.12, 0.12, 0.06) * s, DARK, CFrame.new(side * 0.28 * s, 0.1 * s, hf - 0.19 * s))
		-- Cheekbones.
		box(model, head, "Cheek", Vector3.new(0.28, 0.14, 0.06) * s, BONE_DARK, CFrame.new(side * 0.32 * s, -0.16 * s, hf - 0.03 * s))
	end
	spiral(model, head, CFrame.new(0, 0.5 * s, hf - 0.14 * s), 0.3 * s, GOLD_DARK)
	-- Skull: nose hole and a grin of teeth.
	box(model, head, "Nose", Vector3.new(0.14, 0.16, 0.05) * s, DARK, CFrame.new(0, -0.14 * s, hf - 0.03 * s))
	box(model, head, "Mouth", Vector3.new(0.78, 0.24, 0.05) * s, DARK, CFrame.new(0, -0.4 * s, hf - 0.03 * s))
	for i = -2, 2 do
		box(model, head, "Tooth", Vector3.new(0.11, 0.2, 0.06) * s, BONE, CFrame.new(i * 0.15 * s, -0.4 * s, hf - 0.05 * s))
	end
	-- Feather headdress: a big fan behind the helmet, a shorter inner row.
	box(model, head, "Band", Vector3.new(1.34, 0.16, 1.34) * s, GOLD_DARK, CFrame.new(0, 0.2 * s, 0))
	local fanRoot = CFrame.new(0, 0.45 * s, 0.4 * s) * CFrame.Angles(-0.35, 0, 0)
	local count = 13
	for i = 0, count - 1 do
		local a = math.rad(-84 + i * 168 / (count - 1))
		local dir = fanRoot * CFrame.Angles(0, 0, a)
		box(model, head, "Feather", Vector3.new(0.26, 1.5, 0.06) * s, FEATHER, dir * CFrame.new(0, 1.15 * s, 0))
		box(model, head, "FeatherTip", Vector3.new(0.28, 0.5, 0.07) * s, FEATHER_TIP, dir * CFrame.new(0, 2.05 * s, 0))
	end
	for i = 0, 8 do
		local a = math.rad(-64 + i * 16)
		local dir = fanRoot * CFrame.new(0, 0, -0.08 * s) * CFrame.Angles(0, 0, a)
		box(model, head, "Feather", Vector3.new(0.22, 0.9, 0.06) * s, FEATHER, dir * CFrame.new(0, 0.85 * s, 0))
		box(model, head, "FeatherTip", Vector3.new(0.24, 0.3, 0.07) * s, ORANGE, dir * CFrame.new(0, 1.38 * s, 0))
	end

	-- Shoulders and arms (bony hands).
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		box(model, torso, "ShoulderPad", Vector3.new(1.0, 0.7, 1.3) * s, GOLD, CFrame.new(side * 1.5 * s, 0.95 * s, 0))
		box(model, torso, "ShoulderTrim", Vector3.new(1.06, 0.14, 1.36) * s, GOLD_DARK, CFrame.new(side * 1.5 * s, 0.62 * s, 0))
		for k = -1, 1 do
			box(model, torso, "Spike", Vector3.new(0.16, 0.3, 0.16) * s, GOLD_DARK, CFrame.new(side * 1.55 * s, 1.38 * s, k * 0.38 * s) * CFrame.Angles(0, 0, side * -0.3))
		end
		local base = CFrame.new(side * 1.55 * s, 0.6 * s, 0)
		local offset = CFrame.new(0, -1.15 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.72, 2.3, 0.72) * s, GOLD, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "ArmBand", Vector3.new(0.8, 0.22, 0.8) * s, ORANGE, CFrame.new(0, 0.1 * s, 0))
		box(model, arm, "Cuff", Vector3.new(0.82, 0.3, 0.82) * s, GOLD_DARK, CFrame.new(0, -0.95 * s, 0))
		zigzag(model, arm, CFrame.new(0, -0.5 * s, -0.37 * s), 0.6 * s, 3, DARK, s)
		local hand = box(model, arm, "Hand", Vector3.new(0.6, 0.42, 0.5) * s, BONE, CFrame.new(0, -1.35 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.11, 0.42, 0.11) * s, BONE, CFrame.new(f * 0.14 * s, -0.36 * s, -0.08 * s))
			box(model, hand, "Knuckle", Vector3.new(0.13, 0.08, 0.13) * s, BONE_DARK, CFrame.new(f * 0.14 * s, -0.24 * s, -0.08 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.4 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: gold with zigzag knee bands and gold feet.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.6 * s, -2.3 * s, 0)
		local offset = CFrame.new(0, -1.0 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.85, 2.0, 0.85) * s, GOLD, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "KneeBand", Vector3.new(0.92, 0.36, 0.92) * s, GOLD_DARK, CFrame.new(0, 0.1 * s, 0))
		zigzag(model, leg, CFrame.new(0, 0.1 * s, -0.47 * s), 0.7 * s, 3, ORANGE, s)
		box(model, leg, "Foot", Vector3.new(0.9, 0.3, 1.2) * s, GOLD_DARK, CFrame.new(0, -1.05 * s, -0.15 * s))
	end
	return model, rig
end

return SilentWayStand
end
end
