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

local Fighters = require(script.Parent.Parent.Fighters)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local Common = require(script.Parent.Parent.TuskActCommon)
local TuskStand = require(script.Parent.Parent.TuskStand)
local SilentWayStand = require(script.Parent.SilentWayStand)
local TuskStandModels = require(Shared.TuskStandModels)

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
