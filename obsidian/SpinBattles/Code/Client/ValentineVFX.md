---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# ValentineVFX

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `ValentineVFX` (capitals matter) |

**What it does:** Client visuals for Funny Valentine / D4C. Blocky. the D4C Stand (D4CStand) floats behind him with a pale-blue aura and strikes with his moves DIMENSION HOP: a striped flag sweeps round him and he's gone; where he steps out, a flag unfurls and falls away; a flag on a pole stays planted where he left from while he can hop back to it PARALLEL VALENTINE: a shimmering Valentine from another world (pink coat, blond ringlets) steps out of a flag, chases the nearest enemy and punches, then leaves; when they SWAP, flags flash at both spots MENGER SPONGE: the target's other-world double stands where it appeared, flickering; near it their body crumbles into little cubes (Menger sponges orbit them), then bursts; get away and the double shatters D4C LOVE TRAIN: a column of light falls on him and a shell of light surrounds him; every hit on him bounces off as a bolt of light into someone else; it ends with a ring of light

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **ValentineVFX**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.ValentineVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.ValentineVFX)

	Client visuals for Funny Valentine / D4C. Blocky.
	  * the D4C Stand (D4CStand) floats behind him with a pale-blue aura and
	    strikes with his moves
	  * DIMENSION HOP: a striped flag sweeps round him and he's gone; where he
	    steps out, a flag unfurls and falls away; a flag on a pole stays
	    planted where he left from while he can hop back to it
	  * PARALLEL VALENTINE: a shimmering Valentine from another world (pink
	    coat, blond ringlets) steps out of a flag, chases the nearest enemy
	    and punches, then leaves; when they SWAP, flags flash at both spots
	  * MENGER SPONGE: the target's other-world double stands where it
	    appeared, flickering; near it their body crumbles into little cubes
	    (Menger sponges orbit them), then bursts; get away and the double
	    shatters
	  * D4C LOVE TRAIN: a column of light falls on him and a shell of light
	    surrounds him; every hit on him bounces off as a bolt of light into
	    someone else; it ends with a ring of light
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local TuskStandModels = require(Shared.TuskStandModels)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local Common = require(script.Parent.Parent.TuskActCommon)
local Fighters = require(script.Parent.Parent.Fighters)
local TuskStand = require(script.Parent.Parent.TuskStand)
local D4CStand = require(script.Parent.D4CStand)

local ValentineVFX = {}
local ACT = 13
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds

-- D4C floats behind him (players and NPCs), like Tusk does.
TuskStandModels.register(ACT, D4CStand.build, { Aura = D4CStand.Aura, AuraLight = D4CStand.AuraLight, Offset = D4CStand.Offset })

local RED = Color3.fromRGB(190, 40, 50)
local WHITE = Color3.fromRGB(245, 245, 240)
local BLUE = Color3.fromRGB(40, 60, 140)
local LIGHT = Color3.fromRGB(255, 250, 225)
local SHIMMER = Color3.fromRGB(170, 200, 255)
local CUBE = Color3.fromRGB(200, 196, 190)

local clones = {} -- [id] = a parallel Valentine
local anchors = {} -- [character] = flag planted where he hopped from
local crumbling = {} -- [character] = cubes and double
local trains = {} -- [character] = light shell
local stanced = {}

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function box(model, size, cf, color, material, transparency)
	local p = VFXLib.part({ Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, Transparency = transparency or 0 })
	p.Parent = model
	return p
end

local function newModel(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = VFXLib.Folder
	return m
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

local function fade(item, a)
	for _, p in ipairs(item.Parts) do
		p.Transparency = math.max(p.Transparency, a)
	end
end

-- A striped flag (7 stripes, a blue canton with white stars), built round its centre.
local function buildFlag(w, h)
	local m = newModel("Flag")
	local stripeH = h / 7
	for i = 0, 6 do
		box(m, Vector3.new(w, stripeH, 0.08), CFrame.new(0, h / 2 - stripeH * (i + 0.5), 0), i % 2 == 0 and RED or WHITE, Enum.Material.Fabric)
	end
	local cw, ch = w * 0.4, stripeH * 4
	box(m, Vector3.new(cw, ch, 0.1), CFrame.new(-w / 2 + cw / 2, h / 2 - ch / 2, -0.01), BLUE, Enum.Material.Fabric)
	for i = 0, 2 do
		for j = 0, 1 do
			box(m, Vector3.new(0.18, 0.18, 0.12), CFrame.new(-w / 2 + cw * (0.2 + i * 0.3), h / 2 - ch * (0.3 + j * 0.4), -0.02), WHITE, Enum.Material.Neon)
		end
	end
	return finish(m)
end

-- A Valentine from another world: his look (pink coat, blond ringlets,
-- magenta trousers), shimmering.
local function buildValentine()
	local m = newModel("ParallelValentine")
	local coat, coatShade = Color3.fromRGB(232, 150, 196), Color3.fromRGB(200, 116, 166)
	local hair, hairDark = Color3.fromRGB(238, 218, 130), Color3.fromRGB(204, 180, 96)
	local skin, pants, grey = Color3.fromRGB(240, 210, 190), Color3.fromRGB(196, 96, 210), Color3.fromRGB(120, 116, 124)
	box(m, Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), coat)
	box(m, Vector3.new(1.2, 0.45, 1.1), CFrame.new(0, 4.15, 0), grey) -- high collar
	box(m, Vector3.new(0.08, 2.1, 0.05), CFrame.new(0.15, 3, -0.52) * CFrame.Angles(0, 0, -0.18), coatShade)
	-- Long coat skirt flaring to the calves, open at the front.
	box(m, Vector3.new(2.5, 2.4, 0.14), CFrame.new(0, 1, 0.62) * CFrame.Angles(0.06, 0, 0), coat)
	for _, side in ipairs({ -1, 1 }) do
		box(m, Vector3.new(0.7, 2.3, 0.14), CFrame.new(side * 0.95, 1, -0.58) * CFrame.Angles(0, side * 0.35, 0), coat)
		box(m, Vector3.new(0.14, 2.3, 1.3), CFrame.new(side * 1.16, 1, 0.05), coatShade)
	end
	box(m, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 4.9, 0), skin)
	box(m, Vector3.new(1.4, 0.4, 1.4), CFrame.new(0, 5.55, 0), hair)
	box(m, Vector3.new(1.5, 1.6, 0.3), CFrame.new(0, 4.5, 0.65), hair)
	for _, side in ipairs({ -1, 1 }) do
		box(m, Vector3.new(0.2, 1.2, 1.1), CFrame.new(side * 0.7, 4.6, 0.05), hair)
		-- Spiral ringlets at the sides.
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			box(m, Vector3.new(0.14, 0.2, 0.2), CFrame.new(side * 0.95, 4.9 + math.sin(a) * 0.3, math.cos(a) * 0.3), k % 2 == 0 and hair or hairDark)
		end
		box(m, Vector3.new(1, 2, 1), CFrame.new(side * 1.5, 3, 0), coat)
		box(m, Vector3.new(1.1, 0.25, 1.1), CFrame.new(side * 1.5, 2.1, 0), grey)
		box(m, Vector3.new(1, 0.4, 1), CFrame.new(side * 1.5, 1.8, 0), Color3.fromRGB(214, 110, 196))
		box(m, Vector3.new(1, 2, 1), CFrame.new(side * 0.5, 1, 0), pants)
	end
	local item = finish(m)
	local hl = Instance.new("Highlight")
	hl.FillColor = SHIMMER
	hl.FillTransparency = 0.6
	hl.OutlineColor = SHIMMER
	hl.Adornee = m
	hl.Parent = m
	return item
end

-- A level-1 Menger sponge: a cube of 20 little cubes (the centre and face centres missing).
local function buildSponge(size)
	local m = newModel("MengerSponge")
	local c = size / 3
	for x = -1, 1 do
		for y = -1, 1 do
			for z = -1, 1 do
				local zeros = (x == 0 and 1 or 0) + (y == 0 and 1 or 0) + (z == 0 and 1 or 0)
				if zeros < 2 then
					box(m, Vector3.new(c, c, c) * 0.96, CFrame.new(x * c, y * c, z * c), (x + y + z) % 2 == 0 and CUBE or CUBE:Lerp(SHIMMER, 0.4))
				end
			end
		end
	end
	return finish(m)
end

local function flash(position, size)
	TuskVFX.CreateImpactStar(position, { Size = size or 3, Rays = 8, Color = LIGHT, Color2 = SHIMMER, Duration = 0.15 })
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
	TuskAnimation.play(character, "V_M1_" .. index)
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1, -3.1), Duration = 0.28 })
	VFXLib.sound(sounds.Swing, root, 0.5, 1.0 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or pal.Second)
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

-- The flag sweeps round him and he slips away.
local function flagWrap(position)
	local flag = buildFlag(6, 4)
	VFXLib.animate(0.35, function(a)
		local angle = a * math.pi * 2.2
		local r = 1.6 * (1 - a * 0.6)
		place(flag, CFrame.new(position) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.5, -r) * CFrame.Angles(0, 0, math.sin(a * 8) * 0.15))
		fade(flag, a * a)
	end, function()
		flag.Model:Destroy()
	end)
	flash(position + Vector3.new(0, 1, 0), 3.5)
end

-- Where he steps out, a flag unfurls and drops away.
local function flagUnfurl(position)
	local flag = buildFlag(6, 4)
	VFXLib.animate(0.5, function(a)
		local open = math.min(a / 0.3, 1)
		place(flag, CFrame.new(position + Vector3.new(0, 0.5 - a * a * 3, 0)) * CFrame.Angles(0, (1 - open) * math.pi, 0) * CFrame.new(0, 0, -1.2))
		fade(flag, math.max(0, (a - 0.5) * 2))
	end, function()
		flag.Model:Destroy()
	end)
	flash(position + Vector3.new(0, 1, 0), 3.5)
end

local function cloneStep(dt)
	local now = os.clock()
	for id, c in pairs(clones) do
		if now > c.Until then
			clones[id] = nil
			flagWrap(c.Pos + Vector3.new(0, 1.5, 0))
			c.Item.Model:Destroy()
		else
			local tr = c.Target and Common.rootOf(c.Target)
			local goal = tr and tr.Position or (c.Owner and Common.rootOf(c.Owner) and (Common.rootOf(c.Owner).CFrame * CFrame.new(-3, 0, 2)).Position) or c.Pos
			local to = goal - c.Pos
			local reach = tr and 4 or 2
			if to.Magnitude > reach then
				c.Pos = c.Pos + to.Unit * math.min(c.Speed * dt, to.Magnitude - reach * 0.8)
			end
			local look = Vector3.new(to.X, 0, to.Z)
			local cf = CFrame.lookAt(c.Pos, c.Pos + (look.Magnitude > 0.1 and look or Vector3.new(0, 0, -1)))
			local punch = math.max(0, 1 - (now - c.PunchAt) / 0.25)
			place(c.Item, cf * CFrame.new(0, -3 + math.abs(math.sin(now * 9)) * 0.2, -punch * 1.2))
			-- Shimmers between worlds.
			for _, p in ipairs(c.Item.Parts) do
				p.Transparency = 0.15 + 0.15 * math.abs(math.sin(now * 6 + id))
			end
		end
	end
end

-- The target's other-world double flickers beside them; their body crumbles into cubes.
local function startCrumble(target, duration, doublePos, leash)
	local tr = Common.rootOf(target)
	if not tr then
		return
	end
	local old = crumbling[target]
	if old then
		for _, sp in ipairs(old.Sponges) do
			sp.Model:Destroy()
		end
		old.Double.Model:Destroy()
	end
	local torso = target:FindFirstChild("UpperTorso") or target:FindFirstChild("Torso")
	local color = torso and torso.Color or Color3.fromRGB(150, 150, 160)
	local dm = newModel("OtherWorldDouble")
	box(dm, Vector3.new(2, 2, 1), CFrame.new(0, 0, 0), color, Enum.Material.Glass, 0.4)
	box(dm, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 1.6, 0), color:Lerp(WHITE, 0.4), Enum.Material.Glass, 0.4)
	for _, side in ipairs({ -1, 1 }) do
		box(dm, Vector3.new(1, 2, 1), CFrame.new(side * 1.5, 0, 0), color, Enum.Material.Glass, 0.4)
		box(dm, Vector3.new(1, 2, 1), CFrame.new(side * 0.5, -2, 0), color:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Glass, 0.4)
	end
	local sponges = {}
	for i = 1, 4 do
		sponges[i] = buildSponge(0.9)
	end
	crumbling[target] = { Double = finish(dm), Sponges = sponges, Born = os.clock(), Duration = duration or 3, Next = 0, DoublePos = doublePos, Leash = leash or 10 }
	flash(tr.Position, 3)
end

local function crumbleStep(dt)
	local now = os.clock()
	for target, c in pairs(crumbling) do
		local tr = Common.rootOf(target)
		if not tr or now - c.Born > c.Duration + 0.3 then
			crumbling[target] = nil
			for _, sp in ipairs(c.Sponges) do
				sp.Model:Destroy()
			end
			c.Double.Model:Destroy()
		else
			local t = now - c.Born
			-- The double stands where it appeared, facing them, flickering.
			local at = c.DoublePos or (tr.CFrame * CFrame.new(3.2, 0, 0)).Position
			local face = Vector3.new(tr.Position.X, at.Y, tr.Position.Z)
			place(c.Double, (face - at).Magnitude > 0.1 and CFrame.lookAt(at, face) or CFrame.new(at))
			local near = (tr.Position - at).Magnitude <= c.Leash
			local flick = (math.floor(t * 14) % 3 == 0) and 0.75 or 0.4
			for _, p in ipairs(c.Double.Parts) do
				p.Transparency = flick
			end
			-- Menger sponges orbit them.
			for i, sp in ipairs(c.Sponges) do
				local a = t * 2.5 + i / #c.Sponges * math.pi * 2
				place(sp, CFrame.new(tr.Position + Vector3.new(math.cos(a) * 2.4, math.sin(t * 3 + i) * 1.2, math.sin(a) * 2.4)) * CFrame.Angles(t * 2, t * 3, 0))
			end
			-- Little cubes break off the body and drift away (only near the double).
			c.Next = near and c.Next - dt or 0.06
			while c.Next <= 0 and near do
				c.Next = c.Next + 0.06
				local from = tr.Position + Vector3.new((math.random() - 0.5) * 2, (math.random() - 0.5) * 4, (math.random() - 0.5) * 1.4)
				local cube = VFXLib.part({ Size = Vector3.new(0.35, 0.35, 0.35), Color = CUBE, Material = Enum.Material.SmoothPlastic })
				local drift = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5) * 6
				VFXLib.animate(0.6, function(a)
					cube.CFrame = CFrame.new(from + drift * a) * CFrame.Angles(a * 5, a * 3, 0)
					cube.Transparency = a
				end, function()
					cube:Destroy()
				end)
			end
		end
	end
end

-- A flag on a pole planted where he hopped from (he can hop back to it).
local function plantAnchor(character, position, duration)
	local old = anchors[character]
	if old then
		old.Flag.Model:Destroy()
		old.Pole:Destroy()
	end
	local pole = VFXLib.part({ Size = Vector3.new(0.2, 7, 0.2), CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)), Color = Color3.fromRGB(220, 220, 225), Material = Enum.Material.Metal })
	local flag = buildFlag(3.2, 2)
	anchors[character] = { Flag = flag, Pole = pole, Pos = position, Until = os.clock() + (duration or 4) }
end

local function removeAnchor(character)
	local a = anchors[character]
	if a then
		anchors[character] = nil
		flagWrap(a.Pos)
		a.Flag.Model:Destroy()
		a.Pole:Destroy()
	end
end

local function anchorStep()
	local now = os.clock()
	for character, a in pairs(anchors) do
		if now > a.Until or not character.Parent then
			anchors[character] = nil
			a.Flag.Model:Destroy()
			a.Pole:Destroy()
		else
			-- The flag waves at the top of the pole.
			place(a.Flag, CFrame.new(a.Pos + Vector3.new(1.7, 3, 0)) * CFrame.Angles(0, math.sin(now * 3) * 0.25, math.sin(now * 5) * 0.05))
			-- Blinks in its last second.
			local blink = (a.Until - now) < 1 and (math.floor(now * 8) % 2 == 0)
			for _, p in ipairs(a.Flag.Parts) do
				p.Transparency = blink and 0.6 or 0
			end
		end
	end
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "DimensionHop" then
		if phase == "Wrap" then
			TuskAnimation.play(character, "VHop")
			flagWrap(data.Position or (root and root.Position))
		elseif phase == "Anchor" and character then
			plantAnchor(character, data.Position, data.Duration)
		elseif phase == "AnchorGone" and character then
			removeAnchor(character)
		elseif phase == "Unwrap" then
			flagUnfurl(data.Position)
			TuskStand.action(character, "Lunge", { Duration = 0.35 })
			if Common.isLocal(character) then
				CameraFX.fovPunch(6, 0.2)
			end
		end
	elseif move == "ParallelClone" then
		if phase == "Call" and character then
			TuskAnimation.play(character, "VCall")
			TuskStand.action(character, "Manifest", { Duration = 0.5 })
		elseif phase == "Arrive" then
			local item = buildValentine()
			clones[data.Id] = { Item = item, Pos = data.From, Speed = data.Speed or 20, Until = os.clock() + (data.Duration or 6) + 0.6, Owner = character, PunchAt = 0 }
			flagUnfurl(data.From + Vector3.new(0, 1.5, 0))
		elseif phase == "Chase" then
			local c = clones[data.Id]
			if c then
				c.Target = data.Target
			end
		elseif phase == "Punch" then
			local c = clones[data.Id]
			if c then
				c.PunchAt = os.clock()
			end
			if data.Position then
				TuskVFX.CreateImpactStar(data.Position, { Size = 2.6, Rays = 6, Color = pal.Main, Color2 = WHITE, Duration = 0.12 })
			end
		elseif phase == "Swap" then
			-- They trade places: flags at both spots, and the other one is gone.
			local c = clones[data.Id]
			if c then
				clones[data.Id] = nil
				c.Item.Model:Destroy()
			end
			flagWrap(data.From)
			flagUnfurl(data.To)
			flash(data.To + Vector3.new(0, 1, 0), 5)
			if character and Common.isLocal(character) then
				CameraFX.impactFrame(SHIMMER)
			end
		elseif phase == "Leave" then
			local c = clones[data.Id]
			if c then
				c.Until = 0 -- wraps itself in a flag and goes next frame
			end
		end
	elseif move == "MengerSponge" then
		if phase == "Cast" and character then
			TuskAnimation.play(character, "VMenger")
			TuskStand.action(character, "Lunge", { Duration = 0.45 })
		elseif phase == "Crumble" and data.Target then
			startCrumble(data.Target, data.Duration, data.DoublePos, data.Leash)
		elseif phase == "Escape" and data.Target then
			-- They got away from their double: it shatters into cubes.
			local c = crumbling[data.Target]
			if c then
				crumbling[data.Target] = nil
				local at = c.DoublePos or data.Position
				for _, sp in ipairs(c.Sponges) do
					sp.Model:Destroy()
				end
				c.Double.Model:Destroy()
				VFXLib.burst(at, { Count = 24, Color = CUBE, Speed = 16, Lifetime = 0.45 })
			end
		elseif phase == "Burst" and data.Position then
			VFXLib.burst(data.Position, { Count = 30, Color = CUBE, Speed = 22, Lifetime = 0.5 })
			flash(data.Position, 5)
			if data.Target and crumbling[data.Target] then
				crumbling[data.Target].Duration = 0
			end
		elseif phase == "Miss" and root then
			flash((root.CFrame * CFrame.new(0, 0, -6)).Position, 2)
		end
	end
end

-- Love Train: a column of light, then a shell of light that follows him.
local function startTrain(character, duration)
	local m = newModel("LoveTrain")
	local shell = box(m, Vector3.new(5, 7, 5), CFrame.new(), LIGHT, Enum.Material.ForceField, 0.2)
	local rays = {}
	for i = 1, 6 do
		rays[i] = box(m, Vector3.new(0.25, 9, 0.25), CFrame.new(), LIGHT, Enum.Material.Neon, 0.35)
	end
	local light = Instance.new("PointLight")
	light.Color = LIGHT
	light.Range = 16
	light.Brightness = 2
	light.Parent = shell
	trains[character] = { Model = m, Shell = shell, Rays = rays, Until = os.clock() + duration + 0.5 }
end

local function trainStep()
	local now = os.clock()
	for character, tr in pairs(trains) do
		local root = Common.rootOf(character)
		-- Ends on time, or once the server has switched it off.
		if not root or now > tr.Until or (tr.Started and now > tr.Started + 1 and not character:GetAttribute("LoveTrain")) then
			trains[character] = nil
			tr.Model:Destroy()
		else
			tr.Started = tr.Started or now
			local pulse = 1 + math.sin(now * 6) * 0.04
			tr.Shell.Size = Vector3.new(5, 7, 5) * pulse
			tr.Shell.CFrame = root.CFrame
			for i, ray in ipairs(tr.Rays) do
				local a = now * 1.6 + i / #tr.Rays * math.pi * 2
				ray.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(a) * 3, 0.5, math.sin(a) * 3)) * CFrame.Angles(0, -a, 0.15)
			end
		end
	end
end

-- A bolt of light from him to whoever gets the misfortune.
local function bolt(from, to)
	local segments = 6
	local prev = from + Vector3.new(0, 1, 0)
	for i = 1, segments do
		local t = i / segments
		local p = (from + Vector3.new(0, 1, 0)):Lerp(to + Vector3.new(0, 1, 0), t) + (i < segments and Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 or Vector3.new())
		local seg = VFXLib.part({ Size = Vector3.new(0.3, 0.3, (p - prev).Magnitude), CFrame = CFrame.lookAt((prev + p) / 2, p), Color = LIGHT, Material = Enum.Material.Neon })
		VFXLib.animate(0.25, function(a)
			seg.Transparency = a
		end, function()
			seg:Destroy()
		end)
		prev = p
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Board" then
		TuskAnimation.play(character, "VLoveTrain")
		TuskStand.action(character, "Manifest", { Duration = 0.8 })
		if root then
			-- A column of light comes down on him.
			local column = VFXLib.part({ Size = Vector3.new(6, 60, 6), Color = LIGHT, Material = Enum.Material.Neon, Transparency = 0.4 })
			local at = root.Position
			VFXLib.animate(data.Windup or 0.7, function(a)
				column.CFrame = CFrame.new(at + Vector3.new(0, 30 - a * 2, 0))
				column.Size = Vector3.new(6 - a * 2, 60, 6 - a * 2)
				column.Transparency = 0.4 + 0.6 * a
			end, function()
				column:Destroy()
			end)
			flash(at + Vector3.new(0, 2, 0), 6)
		end
		task.delay(data.Windup or 0.7, function()
			if character and character.Parent then
				startTrain(character, data.Duration or 6)
			end
		end)
		if Common.isLocal(character) then
			TuskVFX.ScreenTint((data.Windup or 0.7) + (data.Duration or 6), { Tint = Color3.fromRGB(255, 250, 230), Saturation = 0.1, Brightness = 0.06 })
		end
		if root then
			VFXLib.sound(sounds.AwakeningBuild, root, 0.5, 1.2)
		end
	elseif data.Phase == "Redirect" then
		if data.From then
			flash(data.From + Vector3.new(0, 1, 0), 3)
		end
		if data.From and data.To then
			bolt(data.From, data.To)
			TuskVFX.CreateImpactStar(data.To, { Size = 3.5, Rays = 7, Color = LIGHT, Color2 = pal.Second, Duration = 0.15 })
		end
	elseif data.Phase == "Pulse" then
		local tr = trains[character]
		if tr then
			trains[character] = nil
			tr.Model:Destroy()
		end
		local ring = VFXLib.part({ Size = Vector3.new(0.6, 1, 1), Color = LIGHT, Material = Enum.Material.Neon, Transparency = 0.2, Shape = Enum.PartType.Cylinder })
		local at = data.Position
		local r = data.Radius or 14
		VFXLib.animate(0.45, function(a)
			ring.Size = Vector3.new(0.6, r * 2 * a, r * 2 * a)
			ring.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
			ring.Transparency = 0.2 + 0.8 * a
		end, function()
			ring:Destroy()
		end)
		Common.finisher({ Character = character, Position = at, Hit = true }, pal, { Size = 1.3, Layers = 2, Shake = 0.6 })
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
				TuskAnimation.hold(character, "VStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "VStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function ValentineVFX.handle(name, data)
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
function ValentineVFX.step(dt)
	dt = dt or 1 / 60
	cloneStep(dt)
	crumbleStep(dt)
	anchorStep()
	trainStep()
	slowTimer = slowTimer + dt
	if slowTimer > 0.2 then
		slowTimer = 0
		stepStance()
	end
end

return ValentineVFX
```
