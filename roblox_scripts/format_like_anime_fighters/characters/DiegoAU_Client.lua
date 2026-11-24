--[[
	DiegoAU_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Diego Brando from another world: The World.
	Its other half is DiegoAU_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: DiegoAUVFX
-- ======================================================================
__modules["DiegoAUVFX"] = function()
--[[
	TuskActVFX.DiegoAUVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.DiegoAUVFX)

	Client visuals for Diego Brando from another world / THE WORLD. Blocky.
	  * The World (TheWorldStand) floats behind him with a golden aura and
	    punches with his moves; he stands with two fingers at his temple
	  * STAND GRAB: The World lunges out and grabs; the victim is held up in
	    a golden grip, then hurled with a streak; a dust ring where they crash
	  * STAND BARRAGE: The World rushes ahead, a storm of golden fists
	    flying forward, impact stars on the hits, a big last punch
	  * KNIFE THROW: three silver knives with gold guards, fanned out. Thrown
	    while time is stopped, they stop dead in the air and wait
	  * THE WORLD: TIME STOP: "THE WORLD!" over his head, a dome bursts out
	    from him and the world goes grey; everyone frozen stops dead (their
	    animations freeze too); a countdown for him, TIME HAS STOPPED for
	    them; when it ends the colour floods back, TIME MOVES AGAIN, and
	    the hanging knives fly
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
local TheWorldStand = __require("TheWorldStand")

local DiegoAUVFX = {}
local ACT = 14
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

-- The World floats behind him (players and NPCs), like Tusk does.
TuskStandModels.register(ACT, TheWorldStand.build, { Aura = TheWorldStand.Aura, AuraLight = TheWorldStand.AuraLight, Offset = TheWorldStand.Offset })

local GOLD = Color3.fromRGB(238, 196, 64)
local GOLD_LIGHT = Color3.fromRGB(255, 236, 150)
local STEEL = Color3.fromRGB(220, 226, 236)
local HANDLE = Color3.fromRGB(60, 44, 36)
local DUST = Color3.fromRGB(200, 180, 140)
local DOME = Color3.fromRGB(120, 80, 200)

local knives = {} -- [projectile id] = flying knife
local hanging = {} -- [knife id] = knife stopped in mid-air
local barrages = {} -- [character] = { Until, NextFist }
local grips = {} -- [target] = grip ring while held
local stops = {} -- [stopper character] = { Until, Gui, Cc, Dome }
local frozenTracks = {} -- [character] = { [track] = speed }
local stanced = {}

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function newModel(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = VFXLib.Folder
	return m
end

local function box(model, size, cf, color, material, transparency)
	local p = VFXLib.part({ Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, Transparency = transparency or 0 })
	p.Parent = model
	return p
end

local function finish(m)
	local item = { Model = m, Parts = {}, Offsets = {} }
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			table.insert(item.Parts, p)
			item.Offsets[p] = p.CFrame
		end
	end
	return item
end

local function place(item, cf)
	for _, p in ipairs(item.Parts) do
		p.CFrame = cf * item.Offsets[p]
	end
end

-- A throwing knife, point along -Z: a silver blade, a gold guard, a dark handle.
local function buildKnife(withTrail)
	local m = newModel("WorldKnife")
	local blade = box(m, Vector3.new(0.1, 0.24, 1.2), CFrame.new(0, 0, -0.55), STEEL, Enum.Material.Metal)
	blade.Reflectance = 0.3
	box(m, Vector3.new(0.06, 0.12, 0.3), CFrame.new(0, -0.04, -1.22), STEEL, Enum.Material.Metal)
	box(m, Vector3.new(0.12, 0.08, 1.0), CFrame.new(0, 0.1, -0.5), Color3.fromRGB(250, 252, 255), Enum.Material.Neon)
	box(m, Vector3.new(0.5, 0.12, 0.12), CFrame.new(0, 0, 0.08), GOLD, Enum.Material.Metal)
	box(m, Vector3.new(0.14, 0.16, 0.5), CFrame.new(0, 0, 0.38), HANDLE)
	box(m, Vector3.new(0.18, 0.18, 0.08), CFrame.new(0, 0, 0.66), GOLD, Enum.Material.Metal)
	local item = finish(m)
	if withTrail then
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.12, 0)
		a1.Position = Vector3.new(0, -0.12, 0)
		a0.Parent, a1.Parent = blade, blade
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Lifetime = 0.15
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), GOLD_LIGHT)
		trail.Transparency = NumberSequence.new(0.3, 1)
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Parent = blade
	end
	return item
end

-- A golden fist flying forward (the barrage).
local function fist(from, direction)
	local m = newModel("WorldFist")
	box(m, Vector3.new(0.7, 0.6, 0.7), CFrame.new(), GOLD, Enum.Material.SmoothPlastic, 0.2)
	box(m, Vector3.new(0.5, 0.5, 1.3), CFrame.new(0, 0, 0.9), GOLD_LIGHT, Enum.Material.Neon, 0.5)
	local item = finish(m)
	local travel = 3 + math.random() * 1.5
	VFXLib.animate(0.12, function(a)
		place(item, CFrame.lookAt(from, from + direction) * CFrame.new(0, 0, -travel * a))
		for _, p in ipairs(item.Parts) do
			p.Transparency = math.max(p.Transparency, a * 0.9)
		end
	end, function()
		m:Destroy()
	end)
end

local function bigText(text, color, duration, size)
	local gui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return nil
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "TheWorldText"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 20
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.fromScale(0.8, size or 0.09)
	label.Font = Enum.Font.Bodoni
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(40, 20, 0)
	label.Parent = screen
	screen.Parent = gui
	if duration then
		VFXLib.animate(duration, function(a)
			label.TextTransparency = math.max(0, (a - 0.7) / 0.3)
			label.TextStrokeTransparency = 0.2 + 0.8 * math.max(0, (a - 0.7) / 0.3)
			label.Size = UDim2.fromScale(0.8 + a * 0.05, size or 0.09)
		end, function()
			screen:Destroy()
		end)
	end
	return screen, label
end

-- "THE WORLD!" shouted over his head (everyone sees it).
local function shout(character, text)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Adornee = head
	bb.Size = UDim2.fromOffset(260, 70)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 200
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bodoni
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = GOLD_LIGHT
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(70, 40, 0)
	label.Parent = bb
	bb.Parent = VFXLib.Folder
	VFXLib.animate(1.4, function(a)
		bb.StudsOffset = Vector3.new(0, 3.2 + a * 0.8, 0)
		label.TextTransparency = math.max(0, (a - 0.75) * 4)
		label.TextStrokeTransparency = math.max(0, (a - 0.75) * 4)
	end, function()
		bb:Destroy()
	end)
end

local function ringAt(position, radius, color, time)
	local ring = VFXLib.part({ Size = Vector3.new(0.4, 1, 1), Color = color, Material = Enum.Material.Neon, Transparency = 0.2, Shape = Enum.PartType.Cylinder })
	VFXLib.animate(time or 0.4, function(a)
		local r = radius * 2 * VFXLib.easeOut(a)
		ring.Size = Vector3.new(0.4, r, r)
		ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Transparency = 0.2 + 0.8 * a
	end, function()
		ring:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Knives (server Kind "WorldKnife")
---------------------------------------------------------------------------
local function spawnKnife(data)
	local item = buildKnife(true)
	knives[data.Id] = { Item = item, Origin = data.Origin, Direction = data.Direction, Speed = data.Speed, Range = data.Range, ServerTime = data.ServerTime, Expire = os.clock() + data.Range / math.max(data.Speed, 1) + 0.5 }
end

local function endKnife(data)
	local v = knives[data.Id]
	if v then
		knives[data.Id] = nil
		v.Item.Model:Destroy()
	end
	if data.HitCharacter then
		TuskVFX.CreateImpactStar(data.Position, { Size = 2.2, Rays = 5, Color = GOLD, Color2 = Color3.new(1, 1, 1), Duration = 0.12 })
	else
		VFXLib.burst(data.Position, { Count = 5, Color = STEEL, Speed = 12, Lifetime = 0.25 })
	end
end

local function stepKnives()
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for id, v in pairs(knives) do
		local t = serverNow - (v.ServerTime or serverNow)
		local distance = math.clamp(v.Speed * t, 0, v.Range)
		local pos = v.Origin + v.Direction * distance
		place(v.Item, CFrame.lookAt(pos, pos + v.Direction))
		if now > v.Expire then
			knives[id] = nil
			v.Item.Model:Destroy()
		end
	end
end

-- Thrown while time is stopped: it flies a few studs and stops dead.
local function hangKnife(data)
	local item = buildKnife(false)
	local from, to, dir = data.From or data.Position, data.Position, data.Direction or Vector3.new(0, 0, -1)
	hanging[data.Id] = item
	VFXLib.animate(0.08, function(a)
		local p = from:Lerp(to, a)
		place(item, CFrame.lookAt(p, p + dir))
	end)
end

local function dropHanging(ids)
	for _, id in ipairs(ids or {}) do
		local item = hanging[id]
		if item then
			hanging[id] = nil
			item.Model:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- Time stop: grey world, frozen fighters
---------------------------------------------------------------------------
local function freezeTracks(character, on)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if on then
		local store = frozenTracks[character] or {}
		frozenTracks[character] = store
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				if store[track] == nil then
					store[track] = track.Speed
					track:AdjustSpeed(0)
				end
			end
		end
	else
		local store = frozenTracks[character]
		frozenTracks[character] = nil
		if store then
			for track, speed in pairs(store) do
				pcall(function()
					track:AdjustSpeed(speed ~= 0 and speed or 1)
				end)
			end
		end
	end
end

local function stepFrozen()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character then
			if character:GetAttribute("TimeStopped") then
				freezeTracks(character, true)
			elseif frozenTracks[character] then
				freezeTracks(character, false)
			end
		end
	end
	for character in pairs(frozenTracks) do
		if not character.Parent then
			frozenTracks[character] = nil
		end
	end
end

local function grey(on, stop)
	if on then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "TheWorldTimeStop"
		cc.Parent = Lighting
		VFXLib.animate(0.35, function(a)
			-- A flash of inverted colour, then grey.
			if a < 0.4 then
				cc.TintColor = Color3.fromRGB(255, 255, 255):Lerp(Color3.fromRGB(150, 110, 255), a / 0.4)
				cc.Contrast = a * 1.5
			else
				cc.TintColor = Color3.fromRGB(150, 110, 255):Lerp(Color3.fromRGB(225, 220, 240), (a - 0.4) / 0.6)
				cc.Contrast = 0.6 - (a - 0.4) * 0.6
			end
			cc.Saturation = -a
		end)
		stop.Cc = cc
	elseif stop.Cc then
		local cc = stop.Cc
		stop.Cc = nil
		local fromSat, fromTint = cc.Saturation, cc.TintColor
		VFXLib.animate(0.45, function(a)
			cc.Saturation = fromSat * (1 - a)
			cc.Contrast = 0.24 * (1 - a)
			cc.TintColor = fromTint:Lerp(Color3.new(1, 1, 1), a)
		end, function()
			cc:Destroy()
		end)
	end
end

local function endStop(character, ids)
	local stop = stops[character]
	if not stop then
		dropHanging(ids)
		return
	end
	stops[character] = nil
	grey(false, stop)
	if stop.Gui then
		stop.Gui:Destroy()
	end
	if stop.Dome then
		stop.Dome:Destroy()
	end
	dropHanging(ids)
end

local function stepStops()
	for character, stop in pairs(stops) do
		if os.clock() > stop.Expire then
			endStop(character)
		elseif stop.Label then
			local left = math.max(0, stop.Until - workspace:GetServerTimeNow())
			stop.Label.Text = string.format(stop.Format, left)
		end
	end
end

local function startStop(character, data)
	endStop(character)
	local duration = data.Duration or 6
	local stop = { Until = workspace:GetServerTimeNow() + duration, Expire = os.clock() + duration + 2 }
	stops[character] = stop
	local camera = workspace.CurrentCamera
	local me = localPlayer and localPlayer.Character
	local isMe = Common.isLocal(character)
	local frozenMe = false
	for _, c in ipairs(data.Frozen or {}) do
		if c == me then
			frozenMe = true
		end
		freezeTracks(c, true)
	end
	local near = camera and data.Position and (camera.CFrame.Position - data.Position).Magnitude <= (data.Range or 150) + 30
	-- The dome bursts out from him and fades.
	if data.Position then
		local dome = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(data.Position), Color = DOME, Material = Enum.Material.ForceField, Transparency = 0 })
		stop.Dome = dome
		local range = math.min(data.Range or 150, 120)
		VFXLib.animate(0.7, function(a)
			local d = range * 2 * VFXLib.easeOut(a)
			dome.Size = Vector3.new(d, d, d)
			dome.Transparency = a * a
		end, function()
			if stop.Dome == dome then
				stop.Dome = nil
			end
			dome:Destroy()
		end)
		VFXLib.flash(data.Position, GOLD_LIGHT, 6, 40, 0.4)
	end
	if near or isMe or frozenMe then
		grey(true, stop)
		CameraFX.fovPunch(-8, 0.4)
		CameraFX.shake(0.4, 0.25)
		VFXLib.sound(sounds.AwakeningBurst, camera, 0.6, 0.7)
	end
	if isMe then
		local gui, label = bigText("", GOLD_LIGHT, nil, 0.06)
		if gui and label then
			label.Position = UDim2.fromScale(0.5, 0.14)
			stop.Gui, stop.Label, stop.Format = gui, label, "TIME STOPPED  %.1f"
		end
	elseif frozenMe then
		local gui, label = bigText("", Color3.fromRGB(230, 230, 240), nil, 0.07)
		if gui and label then
			label.Position = UDim2.fromScale(0.5, 0.22)
			stop.Gui, stop.Label, stop.Format = gui, label, "TIME HAS STOPPED  %.1f"
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
	local index = data.Index
	TuskAnimation.play(character, "DW_M1_" .. index)
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1, -3.2), Duration = 0.28 })
	VFXLib.sound(sounds.Swing, root, 0.5, 1.0 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or pal.Second)
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "StandGrab" then
		if phase == "Reach" and character and root then
			TuskAnimation.play(character, "DWGrab")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 1.4, -4.8), Duration = (data.Windup or 0.2) + 0.7 })
			VFXLib.sound(sounds.Swing, root, 0.6, 0.8)
		elseif phase == "Hold" and data.Target then
			local tr = Common.rootOf(data.Target)
			if tr then
				local ring = VFXLib.part({ Size = Vector3.new(0.3, 3.2, 3.2), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.35, Shape = Enum.PartType.Cylinder })
				grips[data.Target] = ring
				local started = os.clock()
				VFXLib.animate((data.Duration or 0.55) + 0.1, function()
					local t = Common.rootOf(data.Target)
					if t and ring.Parent then
						ring.CFrame = t.CFrame * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles((os.clock() - started) * 8, 0, 0)
					end
				end, function()
					if grips[data.Target] == ring then
						grips[data.Target] = nil
					end
					ring:Destroy()
				end)
				TuskVFX.CreateImpactStar(tr.Position, { Size = 2.4, Rays = 6, Color = GOLD, Color2 = Color3.new(1, 1, 1), Duration = 0.12 })
			end
		elseif phase == "Throw" then
			if data.Position then
				TuskVFX.CreateImpactStar(data.Position, { Size = 3.4, Rays = 8, Color = GOLD, Color2 = Color3.new(1, 1, 1), Duration = 0.16 })
				VFXLib.burst(data.Position, { Count = 14, Color = GOLD_LIGHT, Speed = 26, Lifetime = 0.3, Direction = data.Direction, Spread = 40 })
			end
			if character and Common.isLocal(character) then
				CameraFX.shake(0.4, 0.15)
			end
		elseif phase == "Crash" and data.Position then
			ringAt(data.Position, data.Radius or 7, DUST, 0.45)
			VFXLib.burst(data.Position, { Count = 20, Color = DUST, Speed = 18, Lifetime = 0.5 })
			CameraFX.shakeAt(data.Position, 0.5, 40)
		elseif (phase == "Miss" or phase == "Drop") and root then
			VFXLib.burst((root.CFrame * CFrame.new(0, 1, -4)).Position, { Count = 6, Color = GOLD_LIGHT, Speed = 8, Lifetime = 0.25 })
		end
	elseif move == "StandBarrage" then
		if phase == "Start" and character then
			TuskAnimation.play(character, "DWBarrage")
			barrages[character] = { Until = os.clock() + (data.Windup or 0.15) + (data.Duration or 1.6), NextFist = os.clock() + (data.Windup or 0.15), Side = 1 }
			if Common.isLocal(character) then
				CameraFX.fovPunch(4, 0.2)
			end
		elseif phase == "Hit" and data.Position then
			TuskVFX.CreateImpactStar(data.Position + Vector3.new((math.random() - 0.5) * 2, (math.random() - 0.5) * 2, 0), { Size = 1.8, Rays = 5, Color = GOLD, Color2 = Color3.new(1, 1, 1), Duration = 0.08 })
		elseif phase == "Finish" and character then
			barrages[character] = nil
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 1, -5), Duration = 0.3 })
			Common.finisher({ Character = character, Position = data.Position, Hit = true }, pal, { Size = 1.2, Layers = 2, Shake = 0.5 })
		elseif phase == "Stop" and character then
			barrages[character] = nil
		end
	elseif move == "KnifeThrow" then
		if phase == "Wind" and character then
			TuskAnimation.play(character, "DWKnife")
		elseif phase == "Throw" and root then
			VFXLib.sound(sounds.NailFire, root, 0.5, 1.4)
		elseif phase == "Hang" and data.Id then
			hangKnife(data)
		end
	end
end

local function stepBarrages()
	local now = os.clock()
	for character, b in pairs(barrages) do
		local root = Common.rootOf(character)
		if not root or now > b.Until or not character.Parent then
			barrages[character] = nil
		elseif now >= b.NextFist then
			b.NextFist = now + 0.05
			b.Side = -b.Side
			TuskStand.action(character, "Lunge", { Target = CFrame.new(b.Side * 0.7, 1 + (math.random() - 0.5) * 0.6, -3.6), Duration = 0.09 })
			local from = (root.CFrame * CFrame.new(b.Side * (0.4 + math.random() * 1.4), 0.8 + (math.random() - 0.3) * 1.6, -2.2)).Position
			fist(from, root.CFrame.LookVector)
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character then
		TuskAnimation.play(character, "DWTimeStop")
		TuskStand.action(character, "Manifest", { Duration = 0.8 })
		shout(character, "THE WORLD!")
		if root then
			VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 0.9)
			VFXLib.burst(root.Position, { Count = 20, Color = GOLD_LIGHT, Speed = 10, Lifetime = 0.6 })
		end
		if Common.isLocal(character) then
			CameraFX.fovPunch(6, 0.4)
		end
	elseif data.Phase == "Stop" and character then
		startStop(character, data)
	elseif data.Phase == "Resume" and character then
		local hadStop = stops[character] ~= nil
		local me = localPlayer and localPlayer.Character
		endStop(character, data.Knives)
		for _, c in ipairs(Fighters.list()) do
			local ch = c.Character
			if ch and frozenTracks[ch] and not ch:GetAttribute("TimeStopped") then
				freezeTracks(ch, false)
			end
		end
		if data.Position then
			ringAt(data.Position, 10, GOLD_LIGHT, 0.4)
		end
		if hadStop and (Common.isLocal(character) or (me and data.Position and Common.rootOf(me) and (Common.rootOf(me).Position - data.Position).Magnitude < 170)) then
			bigText("TIME MOVES AGAIN", GOLD_LIGHT, 1.2, 0.06)
			CameraFX.fovPunch(4, 0.25)
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
				TuskAnimation.hold(character, "DWStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "DWStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function DiegoAUVFX.handle(name, data)
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
function DiegoAUVFX.step(dt)
	dt = dt or 1 / 60
	stepKnives()
	stepBarrages()
	stepStops()
	slowTimer = slowTimer + dt
	if slowTimer > 0.15 then
		slowTimer = 0
		stepStance()
		stepFrozen()
	end
end

Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
	if typeof(data) ~= "table" or data.Kind ~= "WorldKnife" then
		return
	end
	if name == "ProjectileSpawn" then
		spawnKnife(data)
	elseif name == "ProjectileEnd" then
		endKnife(data)
	end
end)

return DiegoAUVFX
end

-- ======================================================================
-- MODULE: TheWorldStand
-- ======================================================================
__modules["TheWorldStand"] = function()
--[[
	TuskActVFX.TheWorldStand  (StarterPlayerScripts.SpinClient.TuskActVFX.TheWorldStand)

	THE WORLD (Diego Brando from another world), blocky, matched to the art:
	  * a muscular, shiny golden body
	  * a tall helmet: a flat crest rising to a point above the head, the
	    sides framing the face; narrow eyes and full lips
	  * thick padded cream rolls (segmented) running over both shoulders,
	    down the chest and round the back
	  * round clock-like dials on the wrists, a belt of round studs
	  * a "D" on each shin
	Registered with TuskStandModels by DiegoAUVFX, so TuskStand floats it
	behind Diego (players and NPCs) with a golden aura. A custom model at
	ReplicatedStorage.SpinAssets.TuskAct14 replaces it.
]]

local TheWorldStand = {}

local GOLD = Color3.fromRGB(238, 196, 64)
local GOLD_SHADE = Color3.fromRGB(204, 154, 40)
local GOLD_LIGHT = Color3.fromRGB(255, 232, 140)
local PAD = Color3.fromRGB(228, 210, 146)
local PAD_SHADE = Color3.fromRGB(186, 160, 96)
local LINE = Color3.fromRGB(110, 72, 22)
local LIP = Color3.fromRGB(196, 120, 56)
local EYE = Color3.fromRGB(255, 250, 230)

TheWorldStand.Aura = Color3.fromRGB(255, 210, 80)
TheWorldStand.AuraLight = Color3.fromRGB(255, 240, 190)
TheWorldStand.Offset = CFrame.new(2.2, 1.6, 2.8)

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

-- A clock-like dial on a wrist: a round face with two hands.
local function dial(model, parent, cf, s)
	local face = box(model, parent, "Dial", Vector3.new(0.12, 0.62, 0.62) * s, GOLD_LIGHT, cf)
	face.Shape = Enum.PartType.Cylinder
	box(model, parent, "DialRim", Vector3.new(0.1, 0.72, 0.72) * s, GOLD_SHADE, cf * CFrame.new(0.02 * s, 0, 0)).Shape = Enum.PartType.Cylinder
	box(model, parent, "DialHand", Vector3.new(0.05, 0.24, 0.04) * s, LINE, cf * CFrame.new(-0.07 * s, 0.1 * s, 0))
	box(model, parent, "DialHand", Vector3.new(0.05, 0.04, 0.2) * s, LINE, cf * CFrame.new(-0.07 * s, 0, 0.08 * s))
end

-- A "D" in blocks on a flat face (facing -Z of `cf`).
local function letterD(model, parent, cf, h, s)
	local t = 0.07 * s
	box(model, parent, "D", Vector3.new(t, h, 0.04), LINE, cf * CFrame.new(-h * 0.3, 0, 0))
	box(model, parent, "D", Vector3.new(h * 0.4, t, 0.04), LINE, cf * CFrame.new(-h * 0.12, h / 2 - t / 2, 0))
	box(model, parent, "D", Vector3.new(h * 0.4, t, 0.04), LINE, cf * CFrame.new(-h * 0.12, -h / 2 + t / 2, 0))
	box(model, parent, "D", Vector3.new(t, h * 0.62, 0.04), LINE, cf * CFrame.new(h * 0.17, 0, 0))
	box(model, parent, "D", Vector3.new(t, h * 0.24, 0.04), LINE, cf * CFrame.new(h * 0.1, h * 0.36, 0) * CFrame.Angles(0, 0, 0.7))
	box(model, parent, "D", Vector3.new(t, h * 0.24, 0.04), LINE, cf * CFrame.new(h * 0.1, -h * 0.36, 0) * CFrame.Angles(0, 0, -0.7))
end

-- A padded roll: a row of cream segments from a to b (torso space).
local function roll(model, torso, a, b, thick, s)
	local count = math.max(2, math.floor((b - a).Magnitude / (0.42 * s)))
	for i = 0, count - 1 do
		local p = a:Lerp(b, (i + 0.5) / count)
		box(model, torso, "Pad", Vector3.new(thick, thick, (b - a).Magnitude / count * 0.86), i % 2 == 0 and PAD or PAD_SHADE, CFrame.lookAt(p, b))
	end
end

function TheWorldStand.build(scale)
	local s = (scale or 1) * 0.88
	local model = Instance.new("Model")
	model.Name = "TheWorld"
	local rig = { Joints = {} }

	-- Broad, muscular torso (the anchored root the Stand is moved by).
	local torso = newPart(model, "Body", Vector3.new(2.3, 1.9, 1.15) * s, GOLD, Enum.Material.SmoothPlastic)
	torso.Reflectance = 0.15
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.58 * s
	-- Pecs and abs.
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Pec", Vector3.new(0.95, 0.6, 0.1) * s, GOLD_LIGHT, CFrame.new(side * 0.5 * s, 0.45 * s, front - 0.03 * s))
	end
	box(model, torso, "Waist", Vector3.new(1.6, 0.8, 0.9) * s, GOLD_SHADE, CFrame.new(0, -1.25 * s, 0))
	for k = 0, 2 do
		for _, side in ipairs({ -1, 1 }) do
			box(model, torso, "Ab", Vector3.new(0.4, 0.24, 0.06) * s, GOLD_LIGHT, CFrame.new(side * 0.23 * s, (-0.2 - k * 0.3) * s, front - 0.02 * s))
		end
	end
	-- A belt of round studs.
	box(model, torso, "Belt", Vector3.new(1.7, 0.3, 0.98) * s, GOLD_SHADE, CFrame.new(0, -1.62 * s, 0))
	for k = -2, 2 do
		box(model, torso, "Stud", Vector3.new(0.12, 0.26, 0.26) * s, GOLD_LIGHT, CFrame.new(k * 0.34 * s, -1.62 * s, -0.5 * s) * CFrame.Angles(0, math.pi / 2, 0)).Shape = Enum.PartType.Cylinder
	end
	box(model, torso, "Hips", Vector3.new(1.7, 0.5, 0.95) * s, GOLD, CFrame.new(0, -1.95 * s, 0))
	box(model, torso, "Neck", Vector3.new(0.55, 0.45, 0.55) * s, GOLD_SHADE, CFrame.new(0, 1.12 * s, 0))

	-- The padded rolls: over each shoulder, down the chest, and round the back.
	local t = 0.5 * s
	for _, side in ipairs({ -1, 1 }) do
		local neck = Vector3.new(side * 0.45, 1.05, 0) * s
		local shoulder = Vector3.new(side * 1.2, 1.0, 0) * s
		roll(model, torso, neck, shoulder, t, s)
		roll(model, torso, shoulder + Vector3.new(0, 0, -0.35 * s), Vector3.new(side * 0.85, -0.9, -0.62) * s, t, s)
		roll(model, torso, shoulder + Vector3.new(0, 0, 0.35 * s), Vector3.new(side * 0.85, -0.9, 0.62) * s, t, s)
	end

	-- Head: a tall helmet with a flat crest rising to a point; face below.
	local headBase = CFrame.new(0, 1.25 * s, 0)
	local headOffset = CFrame.new(0, 0.6 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.9, 1.1, 0.95) * s, GOLD, headBase * headOffset)
	head.Reflectance = 0.15
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.48 * s
	-- Helmet sides framing the face, and the cap over the brow.
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "HelmSide", Vector3.new(0.14, 1.15, 0.9) * s, GOLD_SHADE, CFrame.new(side * 0.5 * s, 0.02 * s, 0.05 * s))
	end
	box(model, head, "Brow", Vector3.new(1.05, 0.28, 0.18) * s, GOLD_SHADE, CFrame.new(0, 0.32 * s, hf - 0.04 * s))
	-- The crest: stacked plates narrowing to a point, slightly swept back.
	for k = 0, 4 do
		local w = (0.95 - k * 0.17) * s
		box(model, head, "Crest", Vector3.new(w, 0.32 * s, 0.7 * s - k * 0.06 * s), k % 2 == 0 and GOLD or GOLD_LIGHT, CFrame.new(0, (0.68 + k * 0.3) * s, (0.04 + k * 0.05) * s))
	end
	box(model, head, "CrestLine", Vector3.new(0.06, 1.5, 0.06) * s, LINE, CFrame.new(0, 1.2 * s, hf + 0.06 * s))
	-- Narrow eyes, a nose ridge, full lips.
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Eye", Vector3.new(0.26, 0.08, 0.05) * s, EYE, CFrame.new(side * 0.2 * s, 0.14 * s, hf - 0.02 * s) * CFrame.Angles(0, 0, side * -0.18), Enum.Material.Neon)
	end
	box(model, head, "Nose", Vector3.new(0.1, 0.3, 0.1) * s, GOLD_SHADE, CFrame.new(0, -0.04 * s, hf - 0.04 * s))
	box(model, head, "Lips", Vector3.new(0.36, 0.12, 0.08) * s, LIP, CFrame.new(0, -0.3 * s, hf - 0.02 * s))
	box(model, head, "Chin", Vector3.new(0.5, 0.2, 0.2) * s, GOLD_SHADE, CFrame.new(0, -0.5 * s, hf + 0.08 * s))

	-- Thick arms with dials on the wrists.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		box(model, torso, "Shoulder", Vector3.new(0.9, 0.8, 0.9) * s, GOLD_LIGHT, CFrame.new(side * 1.45 * s, 0.6 * s, 0))
		local base = CFrame.new(side * 1.5 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local size = Vector3.new(0.65, 2.2, 0.65) * s
		local arm, weld = box(model, torso, a[1], size, GOLD, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Bicep", Vector3.new(0.72, 0.7, 0.72) * s, GOLD_LIGHT, CFrame.new(0, 0.55 * s, -0.02 * s))
		box(model, arm, "Forearm", Vector3.new(0.74, 0.8, 0.74) * s, GOLD_SHADE, CFrame.new(0, -0.5 * s, 0))
		dial(model, arm, CFrame.new(side * 0.4 * s, -0.55 * s, 0), s)
		local hand = box(model, arm, "Hand", Vector3.new(0.6, 0.55, 0.55) * s, GOLD, CFrame.new(0, -1.35 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.11, 0.38, 0.11) * s, GOLD_SHADE, CFrame.new(f * 0.13 * s, -0.4 * s, -0.06 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: a "D" on each shin, heavy feet.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.48 * s, -2.1 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local size = Vector3.new(0.72, 2.4, 0.72) * s
		local leg, weld = box(model, torso, "Leg" .. i, size, GOLD, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Thigh", Vector3.new(0.8, 0.9, 0.8) * s, GOLD_LIGHT, CFrame.new(0, 0.7 * s, 0))
		box(model, leg, "Knee", Vector3.new(0.6, 0.36, 0.12) * s, GOLD_SHADE, CFrame.new(0, 0.05 * s, -0.4 * s))
		local shin = box(model, leg, "Shin", Vector3.new(0.66, 0.8, 0.1) * s, GOLD_LIGHT, CFrame.new(0, -0.55 * s, -0.4 * s))
		letterD(model, shin, CFrame.new(0, 0, -0.06 * s), 0.6 * s, s)
		box(model, leg, "Foot", Vector3.new(0.66, 0.3, 1.0) * s, GOLD_SHADE, CFrame.new(0, -1.3 * s, -0.17 * s))
	end
	return model, rig
end

return TheWorldStand
end
end
