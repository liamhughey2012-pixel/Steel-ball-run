---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# GyroEyesVFX

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `GyroEyesVFX` (capitals matter) |

**What it does:** Client visuals for GYRO WITH THE SAINT'S EYES (Act 29). Blocky. his steel ball now has the corpse's EYE set into it, matched to the art: a green ball with darker streaks, a big white eyeball bulging out, a gold-brown iris ringed with dark flecks, ORANGE SPIN ARCS whirling round it and gold-white sparkles shedding off it; the other eye is in his face (GyroOutfit) the eye-ball in his hand has a thin green Spin ring circling it, and every few seconds the eye "looks": a thin green beam sweeps out from it STEEL BALL COMBO: green swipes; the eye-ball whirls with each swing, the 4th throws off a spin ring, the finisher sends a vibration ring out SCAN SHOT: he tosses the eye-ball straight up; it spins at the top, the eye looking down; he throws a second steel ball into it (CRACK: an orange star and spin ring, the second ball glancing off and falling away) and the eye-ball streaks down onto the target with green afterimages and a lock-on beam, steering after them; it lands in cracked ground, an orange spin ring and thrown-up sand; the hit drills spiral ripples and a vibration ring, and an eye opens over them; they glow for him (seen through walls) SCAN: a big eye opens over his head; green scan lines sweep down his screen; a green ring sweeps out; VIBRATION LINES ripple across the ground (a big wave, then wavy rings and jittering dashes round him for as long as it lasts); for him the world dims and every enemy in range glows green through walls, an eye over its head and small vibration rings pulsing under its feet EYE RICOCHET: the eye-ball bounces from enemy to enemy with spin rings round it, leaving a fading green zigzag of its path; a spark, a spin ripple and a vibration ring at each one SCAN: GOLDEN SPIN: a turning GOLDEN RECTANGLE (nested golden-ratio frames) locks onto the target, a gold eye opens over Gyro and a gold spin gathers in his hand ("SCAN / GOLDEN SPIN" title for him); the ball streaks straight through everything, a golden helix unwinding along its path; golden rectangles burst out where it hits, a gold vibration ring, and golden spirals hold them paralysed

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **GyroEyesVFX**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.GyroEyesVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.GyroEyesVFX)

	Client visuals for GYRO WITH THE SAINT'S EYES (Act 29). Blocky.
	  * his steel ball now has the corpse's EYE set into it, matched to the
	    art: a green ball with darker streaks, a big white eyeball bulging
	    out, a gold-brown iris ringed with dark flecks, ORANGE SPIN ARCS
	    whirling round it and gold-white sparkles shedding off it; the
	    other eye is in his face (GyroOutfit)
	  * the eye-ball in his hand has a thin green Spin ring circling it, and
	    every few seconds the eye "looks": a thin green beam sweeps out from it
	  * STEEL BALL COMBO: green swipes; the eye-ball whirls with each swing,
	    the 4th throws off a spin ring, the finisher sends a vibration ring out
	  * SCAN SHOT: he tosses the eye-ball straight up; it spins at the top,
	    the eye looking down; he throws a second steel ball into it (CRACK:
	    an orange star and spin ring, the second ball glancing off and
	    falling away) and the eye-ball streaks down onto the target with
	    green afterimages and a lock-on beam, steering after them; it lands
	    in cracked ground, an orange spin ring and thrown-up sand; the hit drills spiral ripples and a vibration ring, and an eye
	    opens over them; they glow for him (seen through walls)
	  * SCAN: a big eye opens over his head; green scan lines sweep down his
	    screen; a green ring sweeps out; VIBRATION LINES ripple across the
	    ground (a big wave, then wavy rings and jittering dashes round him
	    for as long as it lasts); for him the world dims and every enemy in
	    range glows green through walls, an eye over its head and small
	    vibration rings pulsing under its feet
	  * EYE RICOCHET: the eye-ball bounces from enemy to enemy with spin
	    rings round it, leaving a fading green zigzag of its path; a spark,
	    a spin ripple and a vibration ring at each one
	  * SCAN: GOLDEN SPIN: a turning GOLDEN RECTANGLE (nested golden-ratio
	    frames) locks onto the target, a gold eye opens over Gyro and a gold
	    spin gathers in his hand ("SCAN / GOLDEN SPIN" title for him); the
	    ball streaks straight through everything, a golden helix unwinding
	    along its path; golden rectangles burst out where it hits, a gold
	    vibration ring, and golden spirals hold them paralysed
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local VFXQuality = require(Shared.VFXQuality)
local SteelBallModel = require(Shared.SteelBallModel)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local Common = require(script.Parent.Parent.TuskActCommon)
local Fighters = require(script.Parent.Parent.Fighters)
local Cinematic = require(script.Parent.Parent.Cinematic)

local GyroEyesVFX = {}
local ACT = 29
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

local GREEN = Color3.fromRGB(120, 230, 90)
local GOLD = Color3.fromRGB(255, 210, 80)
local WHITE = Color3.fromRGB(246, 242, 236)
local IRIS = Color3.fromRGB(130, 80, 40)

local held = {} -- [character] = { Ball, Weld, Grip, Angle, Hidden }
local shots = {} -- [id] = { Model }
local reveals = {} -- [target] = { Highlight, Until }

---------------------------------------------------------------------------
-- The eye-ball
---------------------------------------------------------------------------
-- A steel ball with the corpse's eye set into its surface.
local function eyeBall(size)
	local ball = SteelBallModel.build(size, VFXQuality.get().Grooves)
	local core = ball.PrimaryPart
	local function add(name, sz, cf, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.CFrame = core.CFrame * cf
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		local w = Instance.new("WeldConstraint")
		w.Part0 = core
		w.Part1 = p
		w.Parent = p
		p.Parent = ball
	end
	-- Darker green streaks across the ball (the art's swirled steel).
	for k = 0, 2 do
		local a = k * 2.1
		add("Streak", Vector3.new(0.1, 0.42, 0.03) * size, CFrame.Angles(0, a, 0.5 + k * 0.3) * CFrame.new(0, 0, 0.495 * size), Color3.fromRGB(50, 110, 40))
	end
	-- The eye: a big white eyeball bulging out of the ball, a gold-brown iris
	-- ringed with little dark flecks, a dark pupil.
	add("Eyeball", Vector3.new(0.66, 0.66, 0.42) * size, CFrame.new(0, 0, -0.4 * size), WHITE)
	add("EyeShade", Vector3.new(0.68, 0.68, 0.3) * size, CFrame.new(0, -0.02 * size, -0.36 * size), Color3.fromRGB(200, 196, 188))
	add("Iris", Vector3.new(0.34, 0.34, 0.1) * size, CFrame.new(0, 0, -0.6 * size), IRIS)
	add("IrisRing", Vector3.new(0.38, 0.38, 0.08) * size, CFrame.new(0, 0, -0.585 * size), Color3.fromRGB(90, 56, 26))
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		add("Fleck", Vector3.new(0.04, 0.04, 0.03) * size, CFrame.new(math.cos(a) * 0.1 * size, math.sin(a) * 0.1 * size, -0.655 * size), Color3.fromRGB(60, 36, 18))
	end
	add("Pupil", Vector3.new(0.11, 0.11, 0.05) * size, CFrame.new(0, 0, -0.665 * size), Color3.fromRGB(16, 12, 10))
	add("Glint", Vector3.new(0.05, 0.05, 0.03) * size, CFrame.new(0.06 * size, 0.06 * size, -0.68 * size), WHITE)
	-- Gold-white sparkles shedding off it.
	local q = VFXQuality.get()
	local at = Instance.new("Attachment")
	at.Parent = core
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkles"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), Color3.fromRGB(255, 200, 90))
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.12 * size, 0)
	e.Transparency = NumberSequence.new(0, 1)
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new(1, 4)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 22 * ((q and q.Particles) or 1)
	e.Parent = at
	return ball
end

---------------------------------------------------------------------------
-- The ORANGE SPIN ARCS (as in the art): broken orange rings whirling round
-- a ball. arcsOn(core, size) adds them; stepArcs() moves them every frame;
-- they go when the ball does.
---------------------------------------------------------------------------
local ORANGE = Color3.fromRGB(255, 150, 40)
local ORANGE_LIGHT = Color3.fromRGB(255, 210, 110)
local arcs = {} -- [core] = { Parts, Size, Tilts }

local function arcsOn(core, size, count)
	if not core or arcs[core] then
		return
	end
	local list = {}
	for i = 1, count or 3 do
		local segs = {}
		for k = 1, 6 do
			segs[k] = VFXLib.part({ Size = Vector3.new(0.09, 0.09, 0.3), Color = i % 2 == 0 and ORANGE_LIGHT or ORANGE, Transparency = 0.05 })
		end
		table.insert(list, { Segs = segs, Tilt = (i - 1) * 0.7 + math.random() * 0.3, Speed = 9 + i * 2.5, Phase = math.random() * 6, Radius = size * (0.62 + i * 0.07) })
	end
	arcs[core] = { Arcs = list, Size = size }
end

local function stepArcs()
	local t = os.clock()
	for core, entry in pairs(arcs) do
		-- (Gone once its ball model is destroyed or taken out of the world.)
		local alive = core.Parent ~= nil and core.Parent.Parent ~= nil
		local hidden = alive and (core.LocalTransparencyModifier or 0) >= 1
		for _, arc in ipairs(entry.Arcs) do
			local base = alive and core.CFrame * CFrame.Angles(arc.Tilt, arc.Tilt * 0.6, 0) or nil
			for k, seg in ipairs(arc.Segs) do
				if not alive then
					seg:Destroy()
				else
					-- Each arc covers about a third of the circle, spinning round.
					local a0 = arc.Phase + t * arc.Speed + (k - 1) * 0.36
					local a1 = a0 + 0.36
					local p0 = (base * CFrame.new(math.cos(a0) * arc.Radius, 0, math.sin(a0) * arc.Radius)).Position
					local p1 = (base * CFrame.new(math.cos(a1) * arc.Radius, 0, math.sin(a1) * arc.Radius)).Position
					seg.Size = Vector3.new(0.09, 0.09, (p1 - p0).Magnitude + 0.04)
					seg.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
					seg.Transparency = hidden and 1 or (0.05 + (k - 1) * 0.12)
				end
			end
		end
		if not alive then
			arcs[core] = nil
		end
	end
end

local function handOf(character)
	local hand = character:FindFirstChild("RightHand")
	if hand then
		return hand, CFrame.new(0, -0.5, -0.15)
	end
	local arm = character:FindFirstChild("Right Arm")
	if arm then
		return arm, CFrame.new(0, -1.15, -0.15)
	end
	return nil
end

local function setHidden(entry, hidden)
	if entry.Ring then
		entry.Ring.Transparency = hidden and 1 or 0.35
	end
	for _, d in ipairs(entry.Ball:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
	entry.Hidden = hidden
end

local function hideHeld(character, time)
	local entry = held[character]
	if entry then
		setHidden(entry, true)
		entry.ShowAt = os.clock() + (time or 0.8)
	end
end

local function updateHeld(dt)
	local seen = {}
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character and character:GetAttribute("TuskAct") == ACT then
			local hand, grip = handOf(character)
			if hand then
				seen[character] = true
				local entry = held[character]
				if not entry then
					local ball = eyeBall(0.95)
					local core = ball.PrimaryPart
					core.Anchored = false
					ball:PivotTo(hand.CFrame * grip)
					local weld = Instance.new("Weld")
					weld.Part0 = hand
					weld.Part1 = core
					weld.C0 = grip
					weld.Parent = core
					ball.Parent = VFXLib.Folder
					-- Orange Spin arcs whirling round it.
					arcsOn(core, 0.95, 3)
					entry = { Ball = ball, Weld = weld, Grip = grip, Angle = 0, Character = character, NextLook = os.clock() + 2, Spin = 0 }
					held[character] = entry
					TuskAnimation.hold(character, "GyroIdle")
				end
				-- The eye keeps turning to look out (slow sweep round, then faces forward);
				-- after a combo hit it whirls.
				entry.Angle = entry.Angle + dt * 1.5
				entry.Spin = entry.Spin + dt * ((entry.FastUntil or 0) > os.clock() and 40 or 0)
				entry.Weld.C0 = entry.Grip * CFrame.Angles(entry.Spin, math.sin(entry.Angle) * 0.8, 0)
				local core = entry.Ball.PrimaryPart
				if core and entry.Ring then
					entry.Ring.CFrame = core.CFrame * CFrame.Angles(os.clock() * 3, 0, os.clock() * 2)
					entry.Ring.Transparency = entry.Hidden and 1 or 0.35
				end
				-- Now and then the eye "looks": a thin green beam sweeps out from it.
				if core and not entry.Hidden and os.clock() >= entry.NextLook then
					entry.NextLook = os.clock() + 2.5 + math.random() * 2
					local from = core.Position
					local look = (core.CFrame * CFrame.new(0, 0, -1)).Position - from
					local beam = VFXLib.part({ Size = Vector3.new(0.06, 0.06, 7), Color = GREEN, Transparency = 0.3 })
					VFXLib.animate(0.45, function(a)
						if not core.Parent then
							return
						end
						local dir = (CFrame.lookAt(core.Position, core.Position + look) * CFrame.Angles(0, (a - 0.5) * 1.2, 0)).LookVector
						beam.CFrame = CFrame.lookAt(core.Position + dir * 3.6, core.Position + dir * 8)
						beam.Transparency = 0.3 + 0.7 * math.abs(a - 0.5) * 2
					end, function()
						beam:Destroy()
					end)
				end
				if entry.ShowAt and os.clock() >= entry.ShowAt then
					entry.ShowAt = nil
					setHidden(entry, false)
				end
			end
		end
	end
	for character, entry in pairs(held) do
		if not seen[character] then
			held[character] = nil
			entry.Ball:Destroy()
			if entry.Ring then
				entry.Ring:Destroy()
			end
			if character.Parent and character:GetAttribute("TuskAct") ~= 5 then
				TuskAnimation.stopHold(character, "GyroIdle")
			end
		end
	end
end

-- Green helix trails round a moving model.
local function trails(core, color)
	for i = 1, 2 do
		local th = (i - 1) * math.pi
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(math.cos(th), math.sin(th), 0) * 0.7
		a0.Parent = core
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(math.cos(th), math.sin(th), 0) * 0.85
		a1.Parent = core
		local t = Instance.new("Trail")
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
		t.LightEmission = 1
		t.FaceCamera = true
		t.Lifetime = 0.3
		t.Transparency = NumberSequence.new(0, 1)
		t.Parent = core
	end
end

-- Show someone glowing (through walls) for the local player only.
local function reveal(target, time, color)
	if typeof(target) ~= "Instance" or not target.Parent then
		return
	end
	local r = reveals[target]
	if r and r.Highlight.Parent then
		r.Until = math.max(r.Until, os.clock() + time)
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "SaintsEyesScan"
	h.FillColor = color or GREEN
	h.FillTransparency = 0.7
	h.OutlineColor = color or GREEN
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee = target
	h.Parent = VFXLib.Folder
	reveals[target] = { Highlight = h, Until = os.clock() + time }
	-- An eye over their head.
	local head = target:FindFirstChild("Head")
	if head then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(40, 40)
		bb.StudsOffset = Vector3.new(0, 2.4, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = head
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Text = "👁"
		t.TextColor3 = color or GREEN
		t.Parent = bb
		bb.Parent = h
	end
end

-- The ground right under a point (or the point itself).
local function groundAt(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { VFXLib.Folder }
	for _, fighter in ipairs(Fighters.list()) do
		if fighter.Character then
			table.insert(ignore, fighter.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), params)
	return hit and hit.Position or (pos - Vector3.new(0, 3, 0))
end

-- VIBRATION LINES: a wavy ring of thin glowing lines spreading out across
-- the ground and fading, like the vibration the eyes read.
local function vibrationRing(center, maxR, color, duration, waves)
	local at = groundAt(center) + Vector3.new(0, 0.08, 0)
	local n = math.clamp(math.floor(maxR * 1.2), 20, 56)
	waves = waves or 10
	local segs = {}
	for i = 1, n do
		segs[i] = VFXLib.part({ Size = Vector3.new(0.1, 0.05, 1), Color = color, Transparency = 0.15 })
	end
	local phase = math.random() * 6
	VFXLib.animate(duration or 1.2, function(a)
		local r = 1.5 + (maxR - 1.5) * VFXLib.easeOut(a)
		local amp = 0.25 + r * 0.025
		local function point(k)
			local ang = k / n * math.pi * 2
			local rr = r + math.sin(ang * waves + phase + a * 18) * amp
			return at + Vector3.new(math.cos(ang) * rr, 0, math.sin(ang) * rr)
		end
		for i, seg in ipairs(segs) do
			local p0, p1 = point(i - 1), point(i)
			local len = (p1 - p0).Magnitude
			seg.Size = Vector3.new(0.12, 0.05, len + 0.05)
			seg.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
			seg.Transparency = 0.15 + 0.85 * a
		end
	end, function()
		for _, seg in ipairs(segs) do
			seg:Destroy()
		end
	end)
end

-- Short jittering dashes on the ground round a point (things the eyes "hear").
local function vibrationDashes(center, radius, color)
	local at = groundAt(center) + Vector3.new(0, 0.08, 0)
	for _ = 1, 8 do
		local ang = math.random() * math.pi * 2
		local r = radius * (0.3 + math.random() * 0.7)
		local p = at + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
		local dash = VFXLib.part({ Size = Vector3.new(0.08, 0.05, 0.9), CFrame = CFrame.new(p) * CFrame.Angles(0, ang + math.pi / 2, 0), Color = color, Transparency = 0.2 })
		local base = dash.CFrame
		VFXLib.animate(0.5, function(a)
			dash.CFrame = base * CFrame.new((math.random() - 0.5) * 0.25, 0, 0)
			dash.Transparency = 0.2 + 0.8 * a
		end, function()
			dash:Destroy()
		end)
	end
end

local function stepReveals()
	local now = os.clock()
	for target, r in pairs(reveals) do
		if now >= r.Until or not target.Parent then
			r.Highlight:Destroy()
			reveals[target] = nil
		elseif now >= (r.NextPulse or 0) then
			-- Small vibration rings under everyone the eyes have found.
			r.NextPulse = now + 0.8
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr then
				vibrationRing(tr.Position, 5, r.Highlight.OutlineColor, 0.7, 7)
			end
		end
	end
end

local function isMe(character)
	return character ~= nil and character == (localPlayer and localPlayer.Character)
end

local function roundCorner(frame)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = frame
end

-- An EYE drawn in the air (always facing the camera) that opens, looks, and
-- closes: white almond, green iris, dark pupil, a glow round it.
local function eyeGlyph(adornee, offset, size, color, duration)
	if not adornee then
		return
	end
	duration = duration or 1.2
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size, size * 0.6)
	bb.StudsOffset = offset or Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Adornee = adornee
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.15, 1.15)
	glow.BackgroundColor3 = color
	glow.BackgroundTransparency = 0.6
	glow.Parent = bb
	roundCorner(glow)
	local white = Instance.new("Frame")
	white.AnchorPoint = Vector2.new(0.5, 0.5)
	white.Position = UDim2.fromScale(0.5, 0.5)
	white.Size = UDim2.fromScale(1, 0)
	white.BackgroundColor3 = WHITE
	white.ClipsDescendants = true
	white.Parent = bb
	roundCorner(white)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = white
	local iris = Instance.new("Frame")
	iris.AnchorPoint = Vector2.new(0.5, 0.5)
	iris.Position = UDim2.fromScale(0.5, 0.5)
	iris.Size = UDim2.fromOffset(size * 0.36, size * 0.36)
	iris.BackgroundColor3 = color
	iris.Parent = white
	roundCorner(iris)
	local pupil = Instance.new("Frame")
	pupil.AnchorPoint = Vector2.new(0.5, 0.5)
	pupil.Position = UDim2.fromScale(0.5, 0.5)
	pupil.Size = UDim2.fromScale(0.45, 0.45)
	pupil.BackgroundColor3 = Color3.fromRGB(14, 20, 12)
	pupil.Parent = iris
	roundCorner(pupil)
	bb.Parent = VFXLib.Folder
	VFXLib.animate(duration, function(a)
		-- Opens fast, looks left and right, then closes.
		local open = a < 0.2 and VFXLib.easeOut(a / 0.2) or (a > 0.8 and (1 - a) / 0.2 or 1)
		white.Size = UDim2.fromScale(1, open)
		iris.Position = UDim2.fromScale(0.5 + math.sin(a * math.pi * 3) * 0.18, 0.5)
		glow.BackgroundTransparency = 0.6 + 0.4 * (1 - open)
	end, function()
		bb:Destroy()
	end)
end

-- Your screen, scanned: green lines sweeping down and a green edge.
local function scanOverlay(duration)
	local pg = localPlayer and localPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SaintsEyesScan"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 3
	local lines = {}
	for i = 1, 8 do
		local l = Instance.new("Frame")
		l.Size = UDim2.new(1, 0, 0, 2)
		l.BackgroundColor3 = GREEN
		l.BorderSizePixel = 0
		l.BackgroundTransparency = 0.6
		l.Parent = gui
		lines[i] = l
	end
	local edge = Instance.new("Frame")
	edge.Size = UDim2.fromScale(1, 1)
	edge.BackgroundTransparency = 1
	edge.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = GREEN
	stroke.Thickness = 18
	stroke.Transparency = 0.5
	stroke.Parent = edge
	gui.Parent = pg
	VFXLib.animate(duration or 1.2, function(a)
		for i, l in ipairs(lines) do
			l.Position = UDim2.fromScale(0, ((i - 1) / 8 + a * 0.6) % 1)
			l.BackgroundTransparency = 0.6 + 0.4 * a
		end
		stroke.Transparency = 0.5 + 0.5 * a
	end, function()
		gui:Destroy()
	end)
end

-- Two thin rings orbiting something that moves (getCF returns its CFrame or nil).
local function orbitRings(getCF, color, duration, size)
	local rings = {}
	for i = 1, 2 do
		rings[i] = VFXLib.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, size or 2.2, size or 2.2), Color = color, Material = Enum.Material.ForceField, Transparency = 0.25 })
	end
	VFXLib.animate(duration, function(a)
		local cf = getCF()
		for i, ring in ipairs(rings) do
			if cf then
				local tc = os.clock() * (8 + i * 3)
				ring.CFrame = cf * CFrame.Angles(tc, i * 1.2, tc * 0.5)
			end
			ring.Transparency = cf and (0.25 + 0.75 * math.max(0, a * 3 - 2)) or 1
		end
	end, function()
		for _, ring in ipairs(rings) do
			ring:Destroy()
		end
	end)
end

-- The GOLDEN RECTANGLE: nested gold frames in the golden ratio, turning,
-- locked onto someone.
local function goldenReticle(target, duration)
	local root = typeof(target) == "Instance" and target:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(170, 105)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Adornee = root
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = bb
	-- (The billboard is itself golden-ratio shaped; each frame is 0.618 of the last.)
	local frames = {}
	local k = 1
	for i = 1, 4 do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(k, k)
		f.BackgroundTransparency = 1
		f.Parent = holder
		local s = Instance.new("UIStroke")
		s.Color = GOLD
		s.Thickness = 3 - i * 0.5
		s.Parent = f
		frames[i] = { Frame = f, Stroke = s }
		k = k * 0.618
	end
	bb.Parent = VFXLib.Folder
	VFXLib.animate(duration, function(a)
		holder.Rotation = a * 90
		local pulse = 1 + math.sin(os.clock() * 10) * 0.05
		holder.Size = UDim2.fromScale((1.6 - a * 0.6) * pulse, (1.6 - a * 0.6) * pulse)
		for _, fr in ipairs(frames) do
			fr.Stroke.Transparency = a > 0.9 and (a - 0.9) / 0.1 or 0
		end
	end, function()
		bb:Destroy()
	end)
end

-- A golden rectangle bursting outward at a point (four gold bars).
local function goldenBurst(at, size)
	local bars = {}
	for i = 1, 4 do
		bars[i] = VFXLib.part({ Size = Vector3.new(0.2, 0.2, 1), Color = GOLD, Transparency = 0.1 })
	end
	local cam = workspace.CurrentCamera
	local face = cam and CFrame.lookAt(at, cam.CFrame.Position) or CFrame.new(at)
	VFXLib.animate(0.5, function(a)
		local w = (1 + a * (size or 8)) * 1.618
		local h = 1 + a * (size or 8)
		local spin = face * CFrame.Angles(0, 0, a * 1.2)
		bars[1].CFrame = spin * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, math.pi / 2, 0)
		bars[2].CFrame = spin * CFrame.new(0, -h / 2, 0) * CFrame.Angles(0, math.pi / 2, 0)
		bars[3].CFrame = spin * CFrame.new(w / 2, 0, 0) * CFrame.Angles(math.pi / 2, 0, 0)
		bars[4].CFrame = spin * CFrame.new(-w / 2, 0, 0) * CFrame.Angles(math.pi / 2, 0, 0)
		bars[1].Size = Vector3.new(0.2, 0.2, w)
		bars[2].Size = Vector3.new(0.2, 0.2, w)
		bars[3].Size = Vector3.new(0.2, 0.2, h)
		bars[4].Size = Vector3.new(0.2, 0.2, h)
		for _, b in ipairs(bars) do
			b.Transparency = 0.1 + 0.9 * a
		end
	end, function()
		for _, b in ipairs(bars) do
			b:Destroy()
		end
	end)
end

---------------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------------
local function newShotBall(id)
	local model = eyeBall(1.2)
	model.PrimaryPart.Anchored = true
	model.Parent = VFXLib.Folder
	trails(model.PrimaryPart, GREEN)
	arcsOn(model.PrimaryPart, 1.2, 3)
	local job = { Model = model }
	shots[id] = job
	return job
end

local function flyShot(data)
	-- (The ball he tossed up dives; a fresh one if this client missed the toss.)
	local job = shots[data.Id] or newShotBall(data.Id)
	job.Tossing = false
	local model = job.Model
	local pos, vel = data.From, (data.Direction or Vector3.new(0, 0, -1)) * (data.Speed or 95)
	local turn, target = data.Turn or 6, data.Target
	-- A thin lock-on beam from the eye to its target (the orange arcs ride along).
	local beam = VFXLib.part({ Size = Vector3.new(0.05, 0.05, 1), Color = GREEN, Transparency = 0.5 })
	local nextGhost = 0
	VFXLib.animate(data.Life or 2.5, function(_, dt)
		if shots[data.Id] ~= job then
			beam.Transparency = 1
			return
		end
		dt = dt or 1 / 60
		local tr = typeof(target) == "Instance" and target.Parent and target:FindFirstChild("HumanoidRootPart")
		if tr then
			local want = (tr.Position - pos).Unit * vel.Magnitude
			vel = (vel + (want - vel) * math.min(1, turn * dt)).Unit * vel.Magnitude
			local len = (tr.Position - pos).Magnitude
			beam.Size = Vector3.new(0.05, 0.05, len)
			beam.CFrame = CFrame.lookAt((pos + tr.Position) / 2, tr.Position)
			beam.Transparency = 0.45 + 0.25 * math.sin(os.clock() * 30)
		else
			beam.Transparency = 1
		end
		pos = pos + vel * dt
		-- The eye looks where it's going.
		model:PivotTo(CFrame.lookAt(pos, pos + vel))
		-- Green afterimages behind it.
		if os.clock() >= nextGhost then
			nextGhost = os.clock() + 0.04
			local ghost = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1), CFrame = CFrame.new(pos), Color = GREEN, Transparency = 0.5, Material = Enum.Material.ForceField })
			VFXLib.animate(0.25, function(a)
				ghost.Transparency = 0.5 + 0.5 * a
				ghost.Size = Vector3.new(1.1, 1.1, 1.1) * (1 - a * 0.6)
			end, function()
				ghost:Destroy()
			end)
		end
	end, function()
		beam:Destroy()
		if shots[data.Id] == job then
			shots[data.Id] = nil
			model:Destroy()
		end
	end)
	VFXLib.sound(sounds.NailFire, data.From, 0.5, 0.85)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "ScanShot" then
		if phase == "Toss" and data.From and data.Apex then
			-- He tosses the eye-ball straight up; it spins at the top, the eye looking down.
			if character then
				TuskAnimation.play(character, "GyroBowl")
				hideHeld(character, (data.Time or 0.5) + 0.5)
			end
			local job = newShotBall(data.Id)
			job.Tossing = true
			local from, apex, time = data.From, data.Apex, data.Time or 0.5
			VFXLib.animate(time + 0.2, function(a)
				if shots[data.Id] ~= job or not job.Tossing then
					return
				end
				local k = math.min(1, a * (time + 0.2) / time)
				local p = from:Lerp(apex, 1 - (1 - k) ^ 2.2) + Vector3.new(0, math.sin(k * math.pi) * 1.5, 0)
				job.Model:PivotTo(CFrame.new(p) * CFrame.Angles(-math.pi / 2 * k, os.clock() * 6, 0))
			end)
			VFXLib.sound(sounds.Swing, from, 0.4, 1.4)
		elseif phase == "Strike" and data.From and data.Apex then
			-- A second steel ball, thrown hard straight into the first.
			if character then
				TuskAnimation.play(character, "GyroThrow")
			end
			local second = SteelBallModel.build(1.0, VFXQuality.get().Grooves)
			second.PrimaryPart.Anchored = true
			second.Parent = VFXLib.Folder
			trails(second.PrimaryPart, GREEN)
			arcsOn(second.PrimaryPart, 1.0, 2)
			local from, apex, time = data.From, data.Apex, data.Time or 0.14
			VFXLib.animate(time, function(a)
				local p = from:Lerp(apex, a)
				second:PivotTo(CFrame.lookAt(p, apex) * CFrame.Angles(0, 0, a * 30))
			end, function()
				-- CRACK: they meet. The second ball glances off and falls away.
				TuskVFX.CreateImpactStar(apex, { Size = 3.4, Rays = 8, Color = ORANGE, Color2 = WHITE, Duration = 0.18 })
				TuskVFX.CreateRotationalShockwave(CFrame.lookAt(apex, apex + (apex - from)) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = 4, Layers = 2, Color = ORANGE, Color2 = GREEN, Particles = 1, Width = 0.3, Duration = 0.3, Spin = 10 })
				VFXLib.flash(apex, ORANGE_LIGHT, 6, 18, 0.12)
				VFXLib.burst(apex, { Count = 16, Color = ORANGE_LIGHT, Speed = 20, Lifetime = 0.4 })
				VFXLib.sound(sounds.NailImpact, apex, 0.7, 0.75)
				local away = (apex - from)
				away = Vector3.new(away.X, 0, away.Z).Magnitude > 0.1 and Vector3.new(away.X, 0, away.Z).Unit or Vector3.new(1, 0, 0)
				local side = away:Cross(Vector3.new(0, 1, 0))
				VFXLib.animate(0.6, function(a)
					local t2 = a * 0.6
					local p = apex + (side * 10 + Vector3.new(0, 8, 0)) * t2 + Vector3.new(0, -40 * t2 * t2, 0)
					second:PivotTo(CFrame.new(p) * CFrame.Angles(a * 12, a * 8, 0))
				end, function()
					second:Destroy()
				end)
				if Common.isLocal(character) then
					CameraFX.shakeAt(apex, 0.4, 40)
				end
			end)
		elseif phase == "Dive" and data.From then
			-- Knocked down onto them: a streak from the top, the eye fixed on its target.
			flyShot(data)
			local streakLen = 6
			local dir = data.Direction or Vector3.new(0, -1, 0)
			local line = VFXLib.part({ Size = Vector3.new(0.3, 0.3, streakLen), CFrame = CFrame.lookAt(data.From + dir * streakLen / 2, data.From + dir * streakLen), Color = ORANGE_LIGHT, Transparency = 0.2 })
			VFXLib.animate(0.3, function(a)
				line.Transparency = 0.2 + 0.8 * a
			end, function()
				line:Destroy()
			end)
		elseif phase == "End" then
			local job = data.Id and shots[data.Id]
			if job then
				shots[data.Id] = nil
				job.Model:Destroy()
			end
			if data.Position then
				if data.Hit then
					TuskVFX.CreateImpact(data.Position, Vector3.new(0, 1, 0), { Size = 1.2, Radius = 4, Layers = 2, Color = GREEN, Color2 = WHITE, Sound = sounds.NailImpact, Pitch = 0.85 })
					-- The Spin keeps drilling: spiral ripples, and the vibration spreads.
					for i = 1, 2 do
						task.delay(0.07 * i, function()
							TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = 2.5 + i * 1.5, Layers = 1, Color = GREEN, Color2 = WHITE, Particles = 0.5, Width = 0.2, Duration = 0.3, Spin = 8 })
						end)
					end
					vibrationRing(data.Position, 9, GREEN, 0.8, 9)
					if typeof(data.Target) == "Instance" then
						eyeGlyph(data.Target:FindFirstChild("Head"), Vector3.new(0, 2.6, 0), 70, GREEN, 1.0)
					end
					CameraFX.shakeAt(data.Position, 0.4, 40)
				else
					VFXLib.burst(data.Position, { Count = 8, Color = GREEN, Speed = 12, Lifetime = 0.3 })
				end
				-- Where it comes down: cracked ground, an orange spin ring, sand thrown up.
				local ground = groundAt(data.Position + Vector3.new(0, 1, 0))
				TuskVFX.CreateGroundCracks(ground, { Radius = data.Radius or 6, Count = 6, Color = GREEN, Duration = 1.4 })
				TuskVFX.CreateRotationalShockwave(CFrame.new(ground + Vector3.new(0, 0.2, 0)), { Radius = data.Radius or 6, Layers = 2, Color = ORANGE, Color2 = GREEN, Particles = 1, Width = 0.4, Duration = 0.4, Spin = 6 })
				VFXLib.burst(ground, { Count = 14, Color = Color3.fromRGB(220, 190, 140), Speed = 16, Lifetime = 0.5, Acceleration = Vector3.new(0, -40, 0) })
			end
			if data.Hit and data.Target and isMe(character) then
				reveal(data.Target, data.Reveal or 6, GREEN)
			end
		end
	elseif move == "Scan" then
		if phase == "Pulse" and data.Position then
			local ring = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(data.Position), Color = GREEN, Material = Enum.Material.ForceField, Transparency = 0.4 })
			VFXLib.animate(0.8, function(a)
				local d = (data.Range or 130) * 2 * VFXLib.easeOut(a)
				ring.Size = Vector3.new(d, d, d)
				ring.Transparency = 0.4 + 0.6 * a
			end, function()
				ring:Destroy()
			end)
			-- The eye opens over him.
			if character then
				eyeGlyph(character:FindFirstChild("Head"), Vector3.new(0, 4.2, 0), 150, GREEN, 1.6)
				TuskAnimation.play(character, "GyroPalm")
			end
			if isMe(character) then
				scanOverlay(1.3)
			end
			VFXLib.sound(sounds.AwakeningBuild, data.Position, 0.4, 1.6)
			-- Vibration lines across the ground: a big wave out, then
			-- smaller ones round him for as long as the scan lasts.
			-- Wave after wave of vibration rolling out from him, each a little
			-- further, the later ones paler.
			local far = math.min(data.Range or 130, 60)
			for w = 0, 4 do
				task.delay(w * 0.22, function()
					local shade = GREEN:Lerp(Color3.fromRGB(220, 255, 200), w / 5)
					vibrationRing(data.Position, far * (0.55 + w * 0.12), shade, 1.2 + w * 0.08, 12 + w * 2)
					vibrationDashes(data.Position, 10 + w * 4, shade)
				end)
			end
			if character then
				local head = character:FindFirstChild("Head")
				if head then
					VFXLib.flash(head.Position, GREEN, 6, 18, 0.2)
				end
				local nextWave = 0
				VFXLib.animate(data.Time or 8, function()
					local r = Common.rootOf(character)
					if not r or os.clock() < nextWave then
						return
					end
					nextWave = os.clock() + 0.55
					-- Two rings at a time, one close and one wider.
					vibrationRing(r.Position, 12, GREEN, 0.8, 9)
					vibrationRing(r.Position, 24, Color3.fromRGB(170, 245, 130), 1.1, 12)
					if math.random() < 0.6 then
						vibrationDashes(r.Position, 10, Color3.fromRGB(200, 255, 170))
					end
				end)
			end
			if isMe(character) then
				for _, target in ipairs(data.Targets or {}) do
					reveal(target, data.Time or 8, GREEN)
				end
				-- The world dims a moment; only the eyes' targets stand out.
				local cc = Instance.new("ColorCorrectionEffect")
				cc.Name = "SaintsEyes"
				cc.Parent = Lighting
				VFXLib.animate(1.2, function(a)
					local k = a < 0.2 and a / 0.2 or 1 - (a - 0.2) / 0.8
					cc.Saturation = -0.6 * k
					cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(200, 255, 190), k)
				end, function()
					cc:Destroy()
				end)
				CameraFX.fovPunch(-6, 0.4)
			end
		end
	elseif move == "Ricochet" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "GyroThrow")
		elseif phase == "Bounce" and data.Points and #data.Points >= 2 then
			if character then
				hideHeld(character, #data.Points * (data.Gap or 0.16) + 0.4)
			end
			local model = eyeBall(1.0)
			model.PrimaryPart.Anchored = true
			model.Parent = VFXLib.Folder
			trails(model.PrimaryPart, GREEN)
			arcsOn(model.PrimaryPart, 1.0, 3)
			local pts, gap = data.Points, data.Gap or 0.16
			local legs = #pts - 1
			local alive = true
			orbitRings(function()
				return alive and model.PrimaryPart and model.PrimaryPart.CFrame or nil
			end, GREEN, legs * gap, 2.2)
			VFXLib.animate(legs * gap, function(a)
				local f = a * legs
				local i = math.min(legs, math.floor(f) + 1)
				local k = f - (i - 1)
				local p = pts[i]:Lerp(pts[i + 1], math.clamp(k, 0, 1))
				model:PivotTo(CFrame.lookAt(p, pts[i + 1]))
			end, function()
				alive = false
				model:Destroy()
			end)
			for i = 2, #pts do
				task.delay((i - 1) * gap, function()
					-- The path it took stays drawn a moment: a green zigzag.
					local a0, b0 = pts[i - 1], pts[i]
					local len = (b0 - a0).Magnitude
					if len > 0.5 then
						local line = VFXLib.part({ Size = Vector3.new(0.14, 0.14, len), CFrame = CFrame.lookAt((a0 + b0) / 2, b0), Color = GREEN, Transparency = 0.2 })
						VFXLib.animate(0.8, function(a)
							line.Transparency = 0.2 + 0.8 * a
							line.Size = Vector3.new(0.14 * (1 - a), 0.14 * (1 - a), len)
						end, function()
							line:Destroy()
						end)
					end
					TuskVFX.CreateImpactStar(pts[i], { Size = 2.4, Rays = 6, Color = GREEN, Color2 = WHITE, Duration = 0.14 })
					TuskVFX.CreateRotationalShockwave(CFrame.lookAt(b0, b0 + (b0 - a0)) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = 2.6, Layers = 1, Color = GREEN, Color2 = WHITE, Particles = 0.5, Width = 0.2, Duration = 0.25, Spin = 10 })
					vibrationRing(b0, 5, GREEN, 0.6, 7)
					VFXLib.sound(sounds.NailImpact, pts[i], 0.4, 1.2 + i * 0.05)
				end)
			end
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Lock" and character and root then
		TuskAnimation.play(character, "GyroBreakerCharge")
		-- The golden rectangle locks onto them (everyone sees it), a gold eye over Gyro.
		if typeof(data.Target) == "Instance" then
			goldenReticle(data.Target, (data.Windup or 1) + 0.3)
		end
		eyeGlyph(character:FindFirstChild("Head"), Vector3.new(0, 5.6, 0), 130, GOLD, (data.Windup or 1) + 0.3)
		-- A golden spin gathers in his hand.
		local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
		if hand then
			orbitRings(function()
				return hand.Parent and hand.CFrame * CFrame.new(0, -0.8, 0) or nil
			end, GOLD, data.Windup or 1, 2.6)
		end
		if isMe(character) and typeof(data.Target) == "Instance" then
			reveal(data.Target, (data.Windup or 1) + 1.5, GOLD)
			CameraFX.fovPunch(-12, 0.6)
			Cinematic.title("SCAN", "GOLDEN SPIN", GOLD, "THE EYES HAVE FOUND THEM", 1.2)
		end
		local head = character:FindFirstChild("Head")
		if head then
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(360, 60)
			bb.StudsOffset = Vector3.new(0, 3.5, 0)
			bb.AlwaysOnTop = true
			bb.Adornee = head
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Font = Enum.Font.Bangers
			t.TextScaled = true
			t.Text = "SCAN: GOLDEN SPIN"
			t.TextColor3 = GOLD
			t.TextStrokeTransparency = 0.1
			t.Parent = bb
			bb.Parent = VFXLib.Folder
			task.delay((data.Windup or 1) + 0.8, function()
				bb:Destroy()
			end)
		end
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.0)
	elseif data.Phase == "Spin" and data.From and data.To then
		if character then
			TuskAnimation.play(character, "GyroThrow")
			hideHeld(character, 0.8)
		end
		local from, to = data.From, data.To
		local ball = eyeBall(1.4)
		ball.PrimaryPart.Anchored = true
		ball.Parent = VFXLib.Folder
		trails(ball.PrimaryPart, GOLD)
		arcsOn(ball.PrimaryPart, 1.4, 4)
		local len = (to - from).Magnitude
		local beam = VFXLib.part({ Size = Vector3.new(0.5, 0.5, len), CFrame = CFrame.lookAt((from + to) / 2, to), Color = GOLD, Transparency = 0.3 })
		local alive = true
		orbitRings(function()
			return alive and ball.PrimaryPart and ball.PrimaryPart.CFrame or nil
		end, GOLD, 0.3, 3.2)
		-- A golden helix wound round its path, unwinding as it goes.
		local axis = CFrame.lookAt(from, to)
		local helix = {}
		local count = math.clamp(math.floor(len / 1.5), 8, 60)
		for i = 1, count do
			local f = i / count
			local ang = f * len * 0.9
			local p = (axis * CFrame.new(math.cos(ang) * 1.2, math.sin(ang) * 1.2, -f * len)).Position
			local dot = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.35, 0.35, 0.35), CFrame = CFrame.new(p), Color = GOLD, Transparency = 1 })
			helix[i] = { Part = dot, F = f }
		end
		VFXLib.animate(0.25, function(a)
			local p = from:Lerp(to, a)
			ball:PivotTo(CFrame.lookAt(p, to) * CFrame.Angles(0, 0, a * 20))
			for _, h in ipairs(helix) do
				if h.F <= a then
					h.Part.Transparency = 0.05
				end
			end
		end, function()
			alive = false
			ball:Destroy()
		end)
		VFXLib.animate(0.9, function(a)
			for _, h in ipairs(helix) do
				h.Part.Transparency = math.max(h.Part.Transparency, 0.05 + 0.95 * math.max(0, a * 1.4 - 0.3))
			end
		end, function()
			for _, h in ipairs(helix) do
				h.Part:Destroy()
			end
		end)
		VFXLib.animate(0.6, function(a)
			beam.Transparency = 0.3 + 0.7 * a
		end, function()
			beam:Destroy()
		end)
		task.delay(0.25, function()
			TuskVFX.CreateImpact(to, Vector3.new(0, 1, 0), { Size = 1.8, Radius = 7, Layers = 3, Color = GOLD, Color2 = WHITE, Sound = sounds.NailImpact, Pitch = 0.7 })
			goldenBurst(to, 9)
			task.delay(0.12, function()
				goldenBurst(to, 6)
			end)
			vibrationRing(to, 14, GOLD, 1.0, 12)
			CameraFX.shakeAt(to, 0.9, 80)
			-- Golden spirals hold them paralysed.
			local target = data.Target
			local tr = typeof(target) == "Instance" and target:FindFirstChild("HumanoidRootPart")
			if tr then
				local rings = {}
				for i = 1, 3 do
					rings[i] = VFXLib.part({ Size = Vector3.new(0.15, 4, 4), Shape = Enum.PartType.Cylinder, Color = GOLD, Material = Enum.Material.ForceField, Transparency = 0.3 })
				end
				VFXLib.animate(data.Stun or 2, function(a)
					if not tr.Parent then
						return
					end
					for i, ring in ipairs(rings) do
						ring.CFrame = tr.CFrame * CFrame.new(0, -2 + i * 1.2, 0) * CFrame.Angles(0, os.clock() * (4 + i), math.pi / 2)
						ring.Transparency = 0.3 + 0.7 * math.max(0, a * 2 - 1)
					end
				end, function()
					for _, ring in ipairs(rings) do
						ring:Destroy()
					end
				end)
			end
			if isMe(character) then
				CameraFX.impactFrame(GOLD)
			end
		end)
	end
end

function GyroEyesVFX.handle(name, data)
	if name == "M1" then
		Common.m1(data, pal, { AnimPrefix = "G_M1_" })
		-- The eye-ball whirls with each swing; the 4th throws off a spin ring.
		local entry = data.Character and held[data.Character]
		if entry then
			entry.FastUntil = os.clock() + 0.3
		end
		local root = Common.rootOf(data.Character)
		if root and (data.Index or 1) == 4 then
			local at = (root.CFrame * CFrame.new(0.6, 0.8, -2.4)).Position
			TuskVFX.CreateRotationalShockwave(CFrame.lookAt(at, at + root.CFrame.LookVector) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = 3, Layers = 2, Color = GREEN, Color2 = WHITE, Particles = 0.5, Width = 0.25, Duration = 0.3, Spin = 8 })
		end
	elseif name == "M1Finisher" then
		Common.finisher(data, pal)
		if data.Position then
			vibrationRing(data.Position, 7, GREEN, 0.6, 8)
		end
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

local slow = 0
function GyroEyesVFX.step(dt)
	dt = dt or 1 / 60
	updateHeld(dt)
	stepArcs()
	slow = slow + dt
	if slow > 0.2 then
		slow = 0
		stepReveals()
	end
end

-- (For previews and tests.)
GyroEyesVFX.Preview = { eyeBall = eyeBall, arcsOn = arcsOn, stepArcs = stepArcs }

return GyroEyesVFX
```
