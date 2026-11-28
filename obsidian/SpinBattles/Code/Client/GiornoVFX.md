---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# GiornoVFX

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `GiornoVFX` (capitals matter) |

**What it does:** Client visuals for Giorno Giovanna / GOLD EXPERIENCE. Blocky. Gold Experience (GoldExperienceStand) floats behind him with a gold aura; Giorno stands with his hand at his chin, hip cocked MUDA COMBO: Gold Experience's golden fists fly out with him; "MUDA!" on the 4th MUDA MUDA RUSH: a blur of golden fists, "MUDA MUDA" spilling out, then one huge "MUDA!" and a burst of leaves LIFE GIVER: TREE: he punches the ground; green roots race along it, and a tree bursts up (trunk, branches, a leafy crown, flowers), stays a moment, then sinks back into the ground SENSE OVERLOAD: a golden punch; the target glows, leaves slow afterimages as they crawl ("TOO SLOW..."), then the pain lands all at once ("!!!") LIFE BURST: a ring of trees bursts up round him, vines coil up everyone caught, snakes bite them, golden life sparkles flow into Giorno; then the trees burst and throw them

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **GiornoVFX**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
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
local GoldExperienceStand = require(script.Parent.GoldExperienceStand)

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
```
