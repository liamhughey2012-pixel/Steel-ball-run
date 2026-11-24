---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# DiegoAUVFX

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `DiegoAUVFX` (capitals matter) |

**What it does:** Client visuals for Diego Brando from another world / THE WORLD. Blocky. The World (TheWorldStand) floats behind him with a golden aura and punches with his moves; he stands with two fingers at his temple STAND GRAB: The World lunges out and grabs; the victim is held up in a golden grip, then hurled with a streak; a dust ring where they crash STAND BARRAGE: The World rushes ahead, a storm of golden fists flying forward, impact stars on the hits, a big last punch KNIFE THROW: three silver knives with gold guards, fanned out THE WORLD: TIME STOP: "THE WORLD!" over his head; a dome bursts out to the zone's edge and STAYS UP for the whole stop (a glowing ring on the ground marks the radius). Inside it the world is grey; outside it isn't. Everyone frozen stops dead (animations too); a countdown for him, TIME HAS STOPPED for whoever's frozen; knives, bullets and other projectiles in it hang in the air (VFXLib projectile clock); when it ends the dome collapses, TIME MOVES AGAIN, and they fly REVOLVER (his corpse move): brass bullets with bright tracers

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **DiegoAUVFX**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.DiegoAUVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.DiegoAUVFX)

	Client visuals for Diego Brando from another world / THE WORLD. Blocky.
	  * The World (TheWorldStand) floats behind him with a golden aura and
	    punches with his moves; he stands with two fingers at his temple
	  * STAND GRAB: The World lunges out and grabs; the victim is held up in
	    a golden grip, then hurled with a streak; a dust ring where they crash
	  * STAND BARRAGE: The World rushes ahead, a storm of golden fists
	    flying forward, impact stars on the hits, a big last punch
	  * KNIFE THROW: three silver knives with gold guards, fanned out
	  * THE WORLD: TIME STOP: "THE WORLD!" over his head; a dome bursts out
	    to the zone's edge and STAYS UP for the whole stop (a glowing ring on
	    the ground marks the radius). Inside it the world is grey; outside
	    it isn't. Everyone frozen stops dead (animations too); a countdown
	    for him, TIME HAS STOPPED for whoever's frozen; knives, bullets and
	    other projectiles in it hang in the air (VFXLib projectile clock);
	    when it ends the dome collapses, TIME MOVES AGAIN, and they fly
	  * REVOLVER (his corpse move): brass bullets with bright tracers
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local TuskStandModels = require(Shared.TuskStandModels)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local Common = require(script.Parent.Parent.TuskActCommon)
local Fighters = require(script.Parent.Parent.Fighters)
local TuskStand = require(script.Parent.Parent.TuskStand)
local TheWorldStand = require(script.Parent.TheWorldStand)

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
-- A revolver bullet: a small brass slug with a bright tracer.
local function buildBullet()
	local m = newModel("WorldBullet")
	box(m, Vector3.new(0.16, 0.16, 0.34), CFrame.new(), Color3.fromRGB(214, 170, 80), Enum.Material.Metal)
	box(m, Vector3.new(0.1, 0.1, 2.2), CFrame.new(0, 0, 1.2), Color3.fromRGB(255, 236, 170), Enum.Material.Neon, 0.35)
	return finish(m)
end

local function spawnKnife(data)
	local item = (data.Visual and data.Visual.Style == "Bullet") and buildBullet() or buildKnife(true)
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
		local t = VFXLib.flight(id, v.ServerTime)
		local distance = math.clamp(v.Speed * t, 0, v.Range)
		local pos = v.Origin + v.Direction * distance
		place(v.Item, CFrame.lookAt(pos, pos + v.Direction))
		if now > v.Expire + VFXLib.held(id, v.ServerTime) then
			knives[id] = nil
			v.Item.Model:Destroy()
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

-- The time-stop zone: a dome that stays up, showing its edge, for as long
-- as time is stopped. Inside it the world is grey.
local function buildDome(center, radius)
	local m = newModel("TimeStopZone")
	local shell = box(m, Vector3.new(1, 1, 1), CFrame.new(center), DOME, Enum.Material.ForceField, 0)
	shell.Shape = Enum.PartType.Ball
	local tint = box(m, Vector3.new(1, 1, 1), CFrame.new(center), Color3.fromRGB(200, 196, 220), Enum.Material.SmoothPlastic, 0.93)
	tint.Shape = Enum.PartType.Ball
	-- A glowing ring on the ground marks the edge.
	local ring = box(m, Vector3.new(0.3, 1, 1), CFrame.new(center - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), GOLD_LIGHT, Enum.Material.Neon, 0.2)
	ring.Shape = Enum.PartType.Cylinder
	local inner = box(m, Vector3.new(0.32, 1, 1), ring.CFrame, Color3.fromRGB(60, 50, 90), Enum.Material.SmoothPlastic, 0)
	inner.Shape = Enum.PartType.Cylinder
	return { Model = m, Shell = shell, Tint = tint, Ring = ring, Inner = inner, Center = center, Radius = radius }
end

local function sizeDome(dome, r, fade)
	local d = r * 2
	dome.Shell.Size = Vector3.new(d, d, d)
	dome.Tint.Size = Vector3.new(d * 0.995, d * 0.995, d * 0.995)
	dome.Ring.Size = Vector3.new(0.3, d, d)
	dome.Inner.Size = Vector3.new(0.32, math.max(d - 1.6, 0.1), math.max(d - 1.6, 0.1))
	dome.Shell.Transparency = 0.35 + 0.65 * fade
	dome.Tint.Transparency = 0.93 + 0.07 * fade
	dome.Ring.Transparency = 0.2 + 0.8 * fade
	dome.Inner.Transparency = 1
end

local function endStop(character)
	local stop = stops[character]
	if not stop then
		return
	end
	stops[character] = nil
	if stop.Gui then
		stop.Gui:Destroy()
	end
	local cc = stop.Cc
	if cc then
		local fromSat, fromTint, fromCon = cc.Saturation, cc.TintColor, cc.Contrast
		VFXLib.animate(0.45, function(a)
			cc.Saturation = fromSat * (1 - a)
			cc.Contrast = fromCon * (1 - a)
			cc.TintColor = fromTint:Lerp(Color3.new(1, 1, 1), a)
		end, function()
			cc:Destroy()
		end)
	end
	local dome = stop.Dome
	if dome then
		VFXLib.animate(0.4, function(a)
			sizeDome(dome, dome.Radius * (1 - 0.9 * a * a), a)
		end, function()
			dome.Model:Destroy()
		end)
	end
end

local function stepStops(dt)
	local camera = workspace.CurrentCamera
	local me = localPlayer and localPlayer.Character
	for character, stop in pairs(stops) do
		if os.clock() > stop.Expire then
			endStop(character)
		else
			-- Grey inside the zone (and for him), colour outside it.
			local inside = stop.IsMe or (camera and (camera.CFrame.Position - stop.Center).Magnitude <= stop.Radius)
			local k = stop.Grey or 0
			k = k + ((inside and 1 or 0) - k) * math.min(1, (dt or 1 / 60) * 6)
			stop.Grey = k
			if stop.Cc then
				stop.Cc.Saturation = -k
				stop.Cc.Contrast = 0.24 * k
				stop.Cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(225, 220, 240), k)
			end
			if stop.Dome and stop.Settled then
				-- The edge shimmers slowly.
				stop.Dome.Ring.Transparency = 0.25 + 0.15 * math.sin(os.clock() * 4)
			end
			-- Countdown for him; TIME HAS STOPPED for anyone frozen in it.
			local frozenMe = not stop.IsMe and me and me:GetAttribute("TimeStopped")
			if (stop.IsMe or frozenMe) and not stop.Gui then
				local gui, label = bigText("", stop.IsMe and GOLD_LIGHT or Color3.fromRGB(230, 230, 240), nil, stop.IsMe and 0.06 or 0.07)
				if gui and label then
					label.Position = UDim2.fromScale(0.5, stop.IsMe and 0.14 or 0.22)
					stop.Gui, stop.Label, stop.Format = gui, label, stop.IsMe and "TIME STOPPED  %.1f" or "TIME HAS STOPPED  %.1f"
				end
			elseif stop.Gui and not stop.IsMe and not frozenMe then
				stop.Gui:Destroy()
				stop.Gui, stop.Label = nil, nil
			end
			if stop.Label then
				stop.Label.Text = string.format(stop.Format, math.max(0, stop.Until - workspace:GetServerTimeNow()))
			end
		end
	end
end

local function startStop(character, data)
	endStop(character)
	local duration = data.Duration or 6
	local center = data.Position or (Common.rootOf(character) and Common.rootOf(character).Position) or Vector3.zero
	local radius = data.Range or 60
	local stop = { Until = workspace:GetServerTimeNow() + duration, Expire = os.clock() + duration + 2, Center = center, Radius = radius, IsMe = Common.isLocal(character) }
	stops[character] = stop
	for _, c in ipairs(data.Frozen or {}) do
		freezeTracks(c, true)
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "TheWorldTimeStop"
	cc.Parent = Lighting
	stop.Cc = cc
	-- The dome bursts out to the zone's edge and stays there.
	local dome = buildDome(center, radius)
	stop.Dome = dome
	VFXLib.animate(0.5, function(a)
		sizeDome(dome, radius * VFXLib.easeOut(a), 0)
		dome.Shell.Transparency = 0.35 * a -- a bright flash as it bursts out
	end, function()
		if stops[character] == stop then
			stop.Settled = true
			sizeDome(dome, radius, 0)
		end
	end)
	VFXLib.flash(center, GOLD_LIGHT, 6, 40, 0.4)
	local camera = workspace.CurrentCamera
	if stop.IsMe or (camera and (camera.CFrame.Position - center).Magnitude <= radius + 10) then
		CameraFX.fovPunch(-8, 0.4)
		CameraFX.shake(0.4, 0.25)
		VFXLib.sound(sounds.AwakeningBurst, camera, 0.6, 0.7)
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
		endStop(character)
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
	stepStops(dt)
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
```
