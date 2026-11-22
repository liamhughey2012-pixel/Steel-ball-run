--[[
	TuskActVFX.Gyro  (StarterPlayerScripts.SpinClient.TuskActVFX.Gyro)

	Client visuals for Gyro Zeppeli (Steel Ball moveset):
	  * the green Steel Ball always spinning in Gyro's right hand
	    (hidden while it's thrown, back when it returns)
	  * thrown / returning ball with white-green spin rings and a trail
	  * SPIN TORNADO: a travelling green funnel of spinning rings
	  * Spin Vibration ripples, and shaking sparks on anyone hit by the Spin
	  * Gyro's own animations (pitch, bowl, kick, palm press...) and his
	    ball-in-hand idle stance
	  * BALL BREAKER: spiral build-up, giant ball, spinning vortex, burst
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local VFXQuality = require(Shared.VFXQuality)
local Net = require(Shared.Net)
local SteelBallModel = require(Shared.SteelBallModel)
local WreckingBallModel = require(Shared.WreckingBallModel)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local Common = require(script.Parent.Parent.TuskActCommon)

local Gyro = {}
local pal = Common.palette(5)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer
local GYRO_ACT = 5

local held = {} -- [character] = { Ball, Weld, Grip, Angle, HiddenUntil }
local shakes = {} -- [character] = attachment with sparkles
local balls = {} -- [projectile id] = visual

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
	for _, d in ipairs(entry.Ball:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
	entry.Hidden = hidden
end

---------------------------------------------------------------------------
-- Ball always in Gyro's hand
---------------------------------------------------------------------------
local function updateHeld(dt)
	local seen = {}
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character:GetAttribute("TuskAct") == GYRO_ACT then
			local hand, grip = handOf(character)
			if hand then
				seen[character] = true
				local entry = held[character]
				if not entry then
					local ball = SteelBallModel.build(0.9, VFXQuality.get().Grooves)
					local core = ball.PrimaryPart
					core.Anchored = false
					ball:PivotTo(hand.CFrame * grip)
					local weld = Instance.new("Weld")
					weld.Part0 = hand
					weld.Part1 = core
					weld.C0 = grip
					weld.Parent = core
					ball.Parent = VFXLib.Folder
					entry = { Ball = ball, Weld = weld, Grip = grip, Angle = 0, HiddenUntil = 0, Spin = 8, Character = character }
					held[character] = entry
					TuskAnimation.hold(character, "GyroIdle") -- ball held up at the chest
				end
				entry.Angle = entry.Angle + dt * entry.Spin
				entry.Weld.C0 = entry.Grip * CFrame.Angles(entry.Angle, entry.Angle * 0.3, 0)
				local hide = now < entry.HiddenUntil
				if hide ~= (entry.Hidden == true) then
					setHidden(entry, hide)
				end
			end
		end
	end
	for character, entry in pairs(held) do
		if not seen[character] then
			held[character] = nil
			entry.Ball:Destroy()
			if character.Parent then
				TuskAnimation.stopHold(character, "GyroIdle")
			end
		end
	end
end

-- Sparkly "shaking" on anyone the Spin is vibrating.
local function updateShakes()
	local seen = {}
	local candidates = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(candidates, player.Character)
		end
	end
	local dummies = workspace:FindFirstChild("SpinTestDummies")
	if dummies then
		for _, d in ipairs(dummies:GetChildren()) do
			table.insert(candidates, d)
		end
	end
	for _, model in ipairs(candidates) do
		if model:IsA("Model") and model:GetAttribute("GyroSpinShake") then
			local root = model:FindFirstChild("HumanoidRootPart")
			if root then
				seen[model] = true
				if not shakes[model] then
					local a = Instance.new("Attachment")
					a.Name = "GyroSpinShake"
					a.Parent = root
					local e = Instance.new("ParticleEmitter")
					e.Texture = VFXLib.Textures.Sparkle
					e.Color = ColorSequence.new(pal.Light, pal.Main)
					e.LightEmission = 1
					e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
					e.Lifetime = NumberRange.new(0.2, 0.35)
					e.Speed = NumberRange.new(4, 8)
					e.SpreadAngle = Vector2.new(180, 180)
					e.Rate = 30 * VFXQuality.get().Particles
					e.Parent = a
					shakes[model] = a
				end
			end
		end
	end
	for model, a in pairs(shakes) do
		if not seen[model] then
			shakes[model] = nil
			a:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- Ball projectiles (server Kind "GyroBall")
---------------------------------------------------------------------------
local function spawnBall(data)
	local style = data.Visual and data.Visual.Style or "Throw"
	local ball
	local rings = {}
	if style == "Wrecking" then
		ball = WreckingBallModel.build(0.7, false)
	else
		local size = style == "Breaker" and (data.Visual.Scale or 6) or 1.1
		ball = SteelBallModel.build(size, VFXQuality.get().Grooves)
		local ringCount = style == "Breaker" and 3 or 2
		for i = 1, ringCount do
			rings[i] = VFXLib.ring({ Radius = size * 0.6 + i * (style == "Breaker" and 0.8 or 0.25), Width = style == "Breaker" and 0.35 or 0.1, Color = i % 2 == 1 and pal.Light or pal.Main, Transparency = 0.1 })
		end
	end
	ball.PrimaryPart.Anchored = true
	ball.Parent = VFXLib.Folder
	local core = ball.PrimaryPart
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = core
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = core
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = style == "Wrecking" and ColorSequence.new(Color3.fromRGB(255, 160, 60)) or ColorSequence.new(pal.Light, pal.Main)
	trail.LightEmission = 1
	trail.Lifetime = style == "Breaker" and 0.5 or 0.25
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = core
	-- Steel Ball Throw / return: green glow, spiral Spin trails, afterimages.
	local glow, helix
	if style == "Throw" or style == "Return" then
		glow = VFXLib.part({ Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = pal.Main, Transparency = 0.1, Size = Vector3.new(1.9, 1.9, 1.9) })
		helix = VFXLib.anchor(CFrame.new(data.Origin))
		local strands = VFXQuality.get().RingSegments > 12 and 3 or 2
		for i = 1, strands do
			local th = (i - 1) / strands * math.pi * 2
			local dir = Vector3.new(math.cos(th), math.sin(th), 0)
			local h0 = Instance.new("Attachment")
			h0.Position = dir * 0.9
			h0.Parent = helix
			local h1 = Instance.new("Attachment")
			h1.Position = dir * 1.05
			h1.Parent = helix
			local t = Instance.new("Trail")
			t.Attachment0 = h0
			t.Attachment1 = h1
			t.Color = ColorSequence.new(Color3.new(1, 1, 1), pal.Main)
			t.LightEmission = 1
			t.LightInfluence = 0
			t.FaceCamera = true
			t.Lifetime = 0.3
			t.WidthScale = NumberSequence.new(1, 0.1)
			t.Transparency = NumberSequence.new(0, 1)
			t.Parent = helix
		end
	end
	local whirl
	if style == "Breaker" then
		-- Spinning spiral trailing the giant ball.
		whirl = VFXLib.anchor(CFrame.new(data.Origin))
		local prev
		for i = 0, 16 do
			local t = i / 16
			local angle = t * math.pi * 3
			local r = 1 + t * 4
			local a = Instance.new("Attachment")
			a.Position = Vector3.new(math.cos(angle) * r, math.sin(angle) * r, t * 3)
			a.Parent = whirl
			if prev then
				local b = Instance.new("Beam")
				b.Attachment0 = prev
				b.Attachment1 = a
				b.FaceCamera = true
				b.LightEmission = 1
				b.Width0 = 0.5 * (1 - t * 0.6)
				b.Width1 = 0.5 * (1 - t * 0.6)
				b.Color = ColorSequence.new(pal.Light:Lerp(pal.Main, t))
				b.Transparency = NumberSequence.new(t * 0.7)
				b.Parent = whirl
			end
			prev = a
		end
	end
	balls[data.Id] = {
		Glow = glow,
		Helix = helix,
		Whirl = whirl,
		Model = ball,
		Rings = rings,
		Style = style,
		Origin = data.Origin,
		Direction = data.Direction,
		Speed = data.Speed,
		Range = data.Range,
		ServerTime = data.ServerTime,
		Spin = 0,
		Expire = os.clock() + data.Range / data.Speed + 1.5,
		NextGhost = 0,
	}
	VFXLib.sound(sounds.NailFire, data.Origin, 0.5, style == "Wrecking" and 1.3 or 0.8)
	if style ~= "Return" then
		VFXLib.burst(data.Origin, { Count = 14, Color = pal.Light, Speed = 22, Spread = 30, Direction = data.Direction, Lifetime = 0.3 })
	end
	if style == "Throw" then
		-- Release: a spin ring blasts off the hand along the throw, plus a flash.
		local axis = CFrame.lookAt(data.Origin, data.Origin + data.Direction) * CFrame.Angles(math.pi / 2, 0, 0)
		TuskVFX.CreateRotationalShockwave(axis, { Radius = 3.2, Layers = 2, Color = pal.Light, Color2 = pal.Main, Particles = 0, Width = 0.25, Duration = 0.3, Spin = 6 })
		TuskVFX.CreateImpactStar(data.Origin, { Size = 3, Rays = 6, Color = pal.Main, Color2 = pal.Light, Duration = 0.18 })
		VFXLib.flash(data.Origin, pal.Main, 4, 16, 0.2)
	end
end

local function removeBall(v)
	for _, ring in ipairs(v.Rings) do
		ring:Destroy()
	end
	if v.Whirl then
		v.Whirl:Destroy()
	end
	if v.Glow then
		v.Glow:Destroy()
	end
	if v.Helix then
		Debris:AddItem(v.Helix, 0.4) -- let the spiral trails finish fading
		for _, t in ipairs(v.Helix:GetChildren()) do
			if t:IsA("Trail") then
				t.Enabled = false
			end
		end
	end
	v.Model:Destroy()
end

local function endBall(data)
	local v = balls[data.Id]
	if v then
		balls[data.Id] = nil
		removeBall(v)
	end
	local style = data.Visual and data.Visual.Style or "Throw"
	if style == "Breaker" then
		return -- the vortex event takes over
	end
	if style == "Wrecking" then
		VFXLib.burst(data.Position, { Count = 10, Color = Color3.fromRGB(255, 170, 70), Speed = 25, Lifetime = 0.3, Acceleration = Vector3.new(0, -50, 0) })
		VFXLib.sound(sounds.NailImpact, data.Position, 0.4, 1.3)
	elseif style == "Throw" then
		TuskVFX.CreateImpact(data.Position, data.Normal, { Size = 1.3, Radius = 4.5, Layers = 3, Color = pal.Main, Color2 = pal.Light, Sound = sounds.NailImpact, Pitch = 0.8 })
		-- The Spin keeps drilling: two late ripples spiral out from the hit.
		local normal = data.Normal or Vector3.new(0, 1, 0)
		local axis = CFrame.lookAt(data.Position, data.Position + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
		for i = 1, 2 do
			task.delay(0.08 * i, function()
				TuskVFX.CreateRotationalShockwave(axis, { Radius = 3 + i * 2, Layers = 1, Color = pal.Light, Color2 = pal.Main, Particles = 0.5, Width = 0.2, Duration = 0.35, Spin = 8 })
			end)
		end
		if normal.Y > 0.6 then
			TuskVFX.CreateGroundCracks(data.Position, { Radius = 5, Count = 5, Color = pal.Main, Duration = 1.2 })
		end
		CameraFX.shakeAt(data.Position, 0.4, 50)
	end
end

local function stepBalls(dt)
	local serverNow = workspace:GetServerTimeNow()
	local now = os.clock()
	for id, v in pairs(balls) do
		local distance = math.min(v.Speed * (serverNow - v.ServerTime), v.Range)
		local pos = v.Origin + v.Direction * distance
		v.Spin = v.Spin + dt * (v.Style == "Breaker" and 10 or 25)
		local facing = CFrame.lookAt(pos, pos + v.Direction)
		v.Model:PivotTo(facing * CFrame.Angles(-v.Spin, 0, v.Spin * 0.2))
		local axis = facing * CFrame.Angles(math.pi / 2, 0, 0)
		for i, ring in ipairs(v.Rings) do
			ring:SetCFrame(axis * CFrame.Angles(0.5 * i * math.sin(v.Spin * 0.2), v.Spin * (0.4 + i * 0.2) * (i % 2 == 0 and -1 or 1), 0.3 * i))
		end
		if v.Style == "Breaker" and now >= v.NextGhost then
			v.NextGhost = now + 0.05
			VFXLib.afterimage(facing, 4, pal.Main)
			if math.random() < 0.2 then
				TuskVFX.CreateDistortion(pos, { Radius = 4, Duration = 0.25 })
			end
		end
		if v.Whirl then
			v.Whirl.CFrame = facing * CFrame.new(0, 0, 3.5) * CFrame.Angles(0, 0, v.Spin * 0.5)
		end
		if v.Glow then
			local pulse = 1.8 + math.sin(v.Spin * 0.8) * 0.25
			v.Glow.Size = Vector3.new(pulse, pulse, pulse)
			v.Glow.CFrame = facing
		end
		if v.Helix then
			v.Helix.CFrame = facing * CFrame.Angles(0, 0, v.Spin * 0.6)
			if v.Style == "Throw" and VFXQuality.get().Afterimages and now >= v.NextGhost then
				v.NextGhost = now + 0.05
				VFXLib.afterimage(facing, 1, pal.Light)
			end
		end
		if now > v.Expire then
			balls[id] = nil
			removeBall(v)
		end
	end
end

---------------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------------
local vibrationStartup, vibrationHit -- defined below (they use the spiral helpers)

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local entry = character and held[character]
	if data.Move == "SteelBallThrow" then
		if data.Phase == "Startup" and root then
			TuskAnimation.play(character, "GyroThrow")
			-- Wind-up: the ball spins faster and faster inside two whirling rings.
			for i = 1, 2 do
				TuskVFX.CreateSpinRing({
					Follow = function()
						local hand = handOf(character)
						return hand and hand.Parent and hand.CFrame * CFrame.new(0, -0.6, 0) or nil
					end,
					Tilt = CFrame.Angles(0.9 * i, 0, 0.6 * i),
					Radius = 0.9 + i * 0.3,
					Width = 0.08,
					Color = i == 1 and pal.Light or pal.Main,
					RotationSpeed = 10 + i * 4,
					Duration = data.Startup or 0.3,
				})
			end
			if entry then
				entry.Spin = 30
				task.delay(data.Startup, function()
					entry.HiddenUntil = os.clock() + 4 -- until it's caught again
					entry.Spin = 8
				end)
			end
		elseif data.Phase == "Caught" and entry then
			entry.HiddenUntil = 0
			if root then
				VFXLib.burst(root.Position + Vector3.new(0, 1, 0), { Count = 8, Color = pal.Light, Speed = 6, Lifetime = 0.25 })
			end
		end
	elseif data.Move == "SpinTornado" and data.Phase == "Startup" and root then
		TuskAnimation.play(character, "GyroBowl")
		TuskVFX.CreateMagicCircle(CFrame.new(root.Position - Vector3.new(0, 2.9, 0)), { Radius = 4, Color = pal.Main, Color2 = pal.Light, Duration = (data.Startup or 0.3) + 0.3, RotationSpeed = 5, Points = 5 })
		VFXLib.burst(root.Position - Vector3.new(0, 2.5, 0), { Count = 12, Color = pal.Light, Speed = 10, Spread = 40, Direction = Vector3.new(0, 1, 0), Lifetime = 0.4 })
		if entry then
			entry.Spin = 40
			task.delay(data.Startup, function()
				entry.HiddenUntil = os.clock() + 2.6 -- the ball becomes the tornado
				entry.Spin = 8
			end)
		end
	elseif data.Move == "SpinVibration" then
		if data.Phase == "Startup" and root then
			TuskAnimation.play(character, "GyroPalm")
			if entry then
				entry.Spin = 45
				task.delay(0.6, function()
					entry.Spin = 8
				end)
			end
			vibrationStartup(character, root, data)
		elseif data.Phase == "Hit" then
			vibrationHit(character, root, data)
		end
	end
end

-- Logarithmic spiral of beams (the Spin's "golden ratio" spiral, in green/white).
local function spiral(cframe, size, duration)
	local carrier = VFXLib.anchor(cframe)
	local prev
	local points = VFXQuality.get().RingSegments
	for i = 0, points do
		local t = i / points
		local angle = t * math.pi * 4
		local r = size * 0.08 * math.exp(t * 2.5)
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(math.cos(angle) * r, math.sin(angle) * r, 0)
		a.Parent = carrier
		if prev then
			local b = Instance.new("Beam")
			b.Attachment0 = prev
			b.Attachment1 = a
			b.FaceCamera = true
			b.LightEmission = 1
			b.Width0 = 0.18
			b.Width1 = 0.18
			b.Color = ColorSequence.new(pal.Light:Lerp(pal.Main, t))
			b.Parent = carrier
		end
		prev = a
	end
	VFXLib.animate(duration, function(a, dt)
		carrier.CFrame = carrier.CFrame * CFrame.Angles(0, 0, (dt or 0) * (2 + a * 8))
	end, function()
		carrier:Destroy()
	end)
end

-- The Golden Rectangle: nested golden-ratio rectangles with the spiral
-- drawn through them (green/white Spin energy), growing and turning.
local function goldenRectangle(cframe, size, duration)
	local carrier = VFXLib.anchor(cframe)
	local phi = 1.618
	local function line(a, b, width, color)
		local a0 = Instance.new("Attachment")
		a0.Position = a
		a0.Parent = carrier
		local a1 = Instance.new("Attachment")
		a1.Position = b
		a1.Parent = carrier
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Segments = 1
		beam.Width0 = width
		beam.Width1 = width
		beam.Color = ColorSequence.new(color)
		beam.Parent = carrier
	end
	-- Outer rectangle, then 6 nested squares cut off in turn (golden subdivision).
	local x0, y0, w, h = -size * phi / 2, -size / 2, size * phi, size
	local spiralPoints = {}
	for i = 0, 6 do
		local color = pal.Light:Lerp(pal.Main, i / 6)
		local width = 0.16 * (1 - i * 0.1)
		line(Vector3.new(x0, y0, 0), Vector3.new(x0 + w, y0, 0), width, color)
		line(Vector3.new(x0 + w, y0, 0), Vector3.new(x0 + w, y0 + h, 0), width, color)
		line(Vector3.new(x0 + w, y0 + h, 0), Vector3.new(x0, y0 + h, 0), width, color)
		line(Vector3.new(x0, y0 + h, 0), Vector3.new(x0, y0, 0), width, color)
		-- Cut a square off the rectangle (rotating which side each time).
		local side = i % 4
		local sq = math.min(w, h)
		local cx, cy
		if side == 0 then
			cx, cy = x0 + sq, y0 + sq
			x0, w = x0 + sq, w - sq
		elseif side == 1 then
			cx, cy = x0 + w - sq, y0 + sq
			y0, h = y0 + sq, h - sq
		elseif side == 2 then
			cx, cy = x0 + w - sq, y0 + h - sq
			w = w - sq
		else
			cx, cy = x0 + sq, y0 + h - sq
			h = h - sq
		end
		table.insert(spiralPoints, { cx, cy, sq, side })
	end
	-- Quarter-circle arcs through the squares = the golden spiral.
	local prev
	for _, q in ipairs(spiralPoints) do
		for k = 0, 4 do
			local angle = (q[4] * math.pi / 2) + math.pi + k / 4 * (math.pi / 2)
			local p = Vector3.new(q[1] + math.cos(angle) * q[3], q[2] + math.sin(angle) * q[3], -0.05)
			if prev then
				line(prev, p, 0.22, pal.Light)
			end
			prev = p
		end
	end
	VFXLib.animate(duration, function(a, dt)
		local grow = VFXLib.easeOut(math.min(a * 2.5, 1))
		carrier.CFrame = cframe * CFrame.Angles(0, 0, a * math.pi * 0.6)
		for _, child in ipairs(carrier:GetChildren()) do
			if child:IsA("Beam") then
				child.Transparency = NumberSequence.new(math.clamp(1 - grow + math.max(0, a - 0.85) / 0.15, 0, 1))
			end
		end
	end, function()
		carrier:Destroy()
	end)
end

---------------------------------------------------------------------------
-- SPIN VIBRATION: Gyro presses the spinning ball into the target and the
-- Spin shakes everything around it.
---------------------------------------------------------------------------
-- Zigzag "vibration" lines that jitter every frame while they shoot outward.
local function vibrationLines(axisCF, count, length, duration)
	local carrier = VFXLib.anchor(axisCF)
	local lines = {}
	local points = 7
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local dir = Vector3.new(math.cos(angle), math.sin(angle), -0.6).Unit
		local side = dir:Cross(Vector3.new(0, 0, 1))
		if side.Magnitude < 0.01 then
			side = Vector3.new(1, 0, 0)
		end
		local atts = {}
		for k = 0, points do
			local a = Instance.new("Attachment")
			a.Parent = carrier
			atts[k] = a
			if k > 0 then
				local b = Instance.new("Beam")
				b.Attachment0 = atts[k - 1]
				b.Attachment1 = a
				b.FaceCamera = true
				b.LightEmission = 1
				b.LightInfluence = 0
				b.Segments = 1
				b.Width0 = 0.22 * (1 - (k - 1) / points)
				b.Width1 = 0.22 * (1 - k / points)
				b.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(pal.Main, k / points))
				b.Parent = carrier
			end
		end
		lines[i] = { Atts = atts, Dir = dir, Side = side.Unit }
	end
	VFXLib.animate(duration, function(a)
		local reach = length * VFXLib.easeOut(a)
		local shake = 0.45 * (1 - a)
		for _, line in ipairs(lines) do
			for k = 0, points do
				local t = k / points
				local zig = (k % 2 == 0 and 1 or -1) * shake * (0.6 + math.random() * 0.8)
				line.Atts[k].Position = line.Dir * (0.6 + reach * t) + line.Side * zig
			end
		end
		local fade = NumberSequence.new(math.clamp((a - 0.4) / 0.6, 0, 1))
		for _, b in ipairs(carrier:GetChildren()) do
			if b:IsA("Beam") then
				b.Transparency = fade
			end
		end
	end, function()
		carrier:Destroy()
	end)
end

function vibrationStartup(character, root, data)
	local windup = data.Windup or 0.35
	-- The ball in hand winds up inside tight, fast rings + gathering energy.
	for i = 1, 3 do
		TuskVFX.CreateSpinRing({
			Follow = function()
				local hand = handOf(character)
				return hand and hand.Parent and hand.CFrame * CFrame.new(0, -0.6, 0) or nil
			end,
			Tilt = CFrame.Angles(0.8 * i, 0.4 * i, 0.5 * i),
			Radius = 0.6 + i * 0.22,
			Width = 0.07,
			Color = i % 2 == 1 and pal.Light or pal.Main,
			RotationSpeed = 14 + i * 5,
			Duration = windup + 0.15,
		})
	end
	local charge = TuskVFX.CreateEnergyCharge({
		Follow = function()
			local hand = handOf(character)
			return hand and hand.Parent and hand.CFrame * CFrame.new(0, -0.6, 0) or nil
		end,
		Color = pal.Main,
		Color2 = pal.Light,
		MaxRadius = 0.9,
		Duration = windup,
		Rings = 2,
	})
	task.delay(windup, function()
		charge:Release(root and root.CFrame.LookVector)
	end)
	VFXLib.sound(sounds.ChargeLoop, root, 0.35, 1.8)
end

function vibrationHit(character, root, data)
	local pos = data.Position
	local look = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
	local facing = CFrame.lookAt(pos, pos + look)
	-- 1. contact: flash + starburst + a spinning golden spiral pressed into the air
	VFXLib.flash(pos, pal.Light, 6, 20, 0.25)
	TuskVFX.CreateImpactStar(pos, { Size = data.Hit and 6 or 3.5, Rays = 9, Color = pal.Main, Color2 = pal.Light, Duration = 0.3 })
	spiral(facing, data.Hit and 3.2 or 2.2, 0.45)
	if data.Hit then
		goldenRectangle(facing * CFrame.new(0, 0, -0.4), 2.4, 0.5)
	end
	-- 2. vibration: jittering zigzag lines + layered ripples pushed forward
	vibrationLines(facing, VFXQuality.get().RingSegments > 12 and 10 or 6, data.Hit and 7 or 4.5, 0.4)
	local axis = facing * CFrame.Angles(math.pi / 2, 0, 0)
	for i = 1, 4 do
		task.delay(i * 0.05, function()
			TuskVFX.CreateRotationalShockwave(axis * CFrame.new(0, -i * 0.9, 0), { Radius = 1.5 + i * 1.3, Layers = 1, Color = i % 2 == 1 and pal.Light or pal.Main, Color2 = pal.Main, Particles = i == 1 and 0.6 or 0, Width = 0.22, Duration = 0.28, Spin = (i % 2 == 1 and 7 or -7) })
		end)
	end
	TuskVFX.CreateDistortion(pos, { Radius = data.Hit and 4 or 2.5, Duration = 0.3 })
	-- 3. on hit: the ground trembles under the target
	if data.Hit then
		TuskVFX.CreateGroundCracks(pos, { Radius = 6, Count = 6, Color = pal.Main, Duration = 1.4 })
		VFXLib.burst(pos, { Count = 20, Color = pal.Light, Speed = 26, Lifetime = 0.35, Spread = 60, Direction = look })
	end
	VFXLib.sound(sounds.Hit, pos, 0.7, 0.7)
	VFXLib.sound(sounds.NailImpact, pos, 0.4, 1.4)
	if Common.isLocal(character) then
		CameraFX.shake(data.Hit and 0.55 or 0.25, 0.35)
		if data.Hit then
			CameraFX.fovPunch(6, 0.25)
		end
	end
	CameraFX.shakeAt(pos, 0.35, 40)
end


-- The Ball Breaker spirit: a glowing ghostly skeletal figure (ForceField
-- material shimmers) that rises out of the vortex, spins, then shatters.
local function breakerSpirit(position, duration)
	local quality = VFXQuality.get()
	local bits = {}
	local function bone(size, offset, ellipsoid)
		local p = VFXLib.part({ Material = Enum.Material.ForceField, Color = pal.Light, Size = size, Transparency = 0 })
		if ellipsoid then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		table.insert(bits, { Part = p, Offset = offset, Size = size })
	end
	bone(Vector3.new(2.4, 2.8, 2.4), CFrame.new(0, 7.5, 0), true) -- skull
	bone(Vector3.new(0.5, 0.6, 0.3), CFrame.new(-0.5, 7.4, -1.1), true) -- eye
	bone(Vector3.new(0.5, 0.6, 0.3), CFrame.new(0.5, 7.4, -1.1), true) -- eye
	bone(Vector3.new(0.5, 3.4, 0.5), CFrame.new(0, 4.5, 0.3), false) -- spine
	for i = 0, (quality.RingSegments > 12 and 3 or 1) do -- ribs
		bone(Vector3.new(3.4 - i * 0.35, 0.35, 1.8), CFrame.new(0, 5.6 - i * 0.7, 0), true)
	end
	for _, side in ipairs({ -1, 1 }) do -- arms reaching out
		bone(Vector3.new(0.45, 3.2, 0.45), CFrame.new(side * 2.4, 5.2, -0.4) * CFrame.Angles(0, 0, side * 1.1), false)
		bone(Vector3.new(0.9, 0.9, 0.9), CFrame.new(side * 3.8, 4.4, -0.8), true)
	end
	local light
	if quality.Lights then
		light = Instance.new("PointLight")
		light.Color = pal.Main
		light.Range = 30
		light.Brightness = 4
		light.Parent = bits[1].Part
	end
	local spin = 0
	VFXLib.animate(duration, function(a, dt)
		spin = spin + (dt or 0) * (1.5 + a * 4)
		local rise = VFXLib.easeOut(math.min(a / 0.3, 1))
		local base = CFrame.new(position + Vector3.new(0, -4 + rise * 4, 0)) * CFrame.Angles(0, spin, 0)
		for _, b in ipairs(bits) do
			b.Part.CFrame = base * b.Offset
			b.Part.Size = b.Size * (0.4 + rise * 0.6)
			b.Part.Transparency = 0.15 + math.sin(a * 30) * 0.08
		end
	end, function()
		-- Shatter: every bone bursts into sparks.
		for _, b in ipairs(bits) do
			VFXLib.burst(b.Part.Position, { Count = 6, Color = pal.Light, Speed = 30, Lifetime = 0.5 })
			b.Part:Destroy()
		end
	end)
end


local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Start" and root then
		TuskAnimation.play(character, "GyroBreakerCharge")
		VFXLib.sound(sounds.AwakeningBuild, root, 0.9, 0.9)
		local entry = held[character]
		if entry then
			entry.Spin = 60
		end
		goldenRectangle(root.CFrame * CFrame.new(0, 2.2, -3.5), 3.2, data.Windup + 0.2)
		-- Three rings spin up around the held ball.
		for i = 1, 3 do
			TuskVFX.CreateSpinRing({
				Follow = function()
					local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
					return hand and hand.Parent and hand.CFrame * CFrame.new(0, -0.6, -0.2) or nil
				end,
				Tilt = CFrame.Angles(0.7 * i, 0, 0.5 * i),
				Radius = 0.9 + i * 0.35,
				Width = 0.1,
				Color = i % 2 == 1 and pal.Light or pal.Main,
				RotationSpeed = 6 + i * 3,
				Duration = data.Windup + 0.2,
			})
		end
		VFXLib.burst(root.Position - Vector3.new(0, 2.5, 0), { Count = 30, Color = pal.Light, Speed = 12, Spread = 25, Direction = Vector3.new(0, 1, 0), Lifetime = 1 })
		TuskVFX.CreateMagicCircle(CFrame.new(root.Position - Vector3.new(0, 2.9, 0)), { Radius = 8, Color = pal.Main, Color2 = pal.Light, Duration = data.Windup + 0.3, RotationSpeed = 2, Points = 5 })
		local charge = TuskVFX.CreateEnergyCharge({
			Follow = function()
				return root.Parent and root.CFrame * CFrame.new(0.9, 0.8, -1.8) or nil
			end,
			Color = pal.Main,
			Color2 = pal.Light,
			MaxRadius = 1.6,
			Duration = data.Windup,
			Rings = 3,
		})
		task.delay(data.Windup, function()
			charge:Release()
		end)
		if Common.isLocal(character) then
			CameraFX.setFovHold(-10)
		end
	elseif data.Phase == "Release" then
		local entry = character and held[character]
		if entry then
			entry.Spin = 8
		end
		if character then
			TuskAnimation.play(character, "GyroThrow")
		end
		VFXLib.flash(data.Position, pal.Light, 10, 40, 0.5)
		if Common.isLocal(character) then
			CameraFX.setFovHold(0)
			CameraFX.fovPunch(16, 0.6)
			CameraFX.speedLines(0.45, pal.Light)
		end
	elseif data.Phase == "Vortex" then
		local pos = data.Position
		local ground = CFrame.new(pos - Vector3.new(0, 1, 0))
		for i = 1, 3 do
			TuskVFX.CreateSpinRing({ CFrame = ground * CFrame.new(0, i * 1.6, 0), Tilt = CFrame.Angles(0.15 * i, 0, 0), Radius = data.Radius * (1.05 - i * 0.2), Width = 0.4, Color = i % 2 == 1 and pal.Main or pal.Light, RotationSpeed = (5 + i * 2) * (i % 2 == 0 and -1 or 1), Duration = data.Duration })
		end
		TuskVFX.CreateMagicCircle(ground, { Radius = data.Radius, Color = pal.Main, Color2 = pal.Light, Duration = data.Duration, RotationSpeed = 3, Points = 6 })
		local vortexCore = TuskVFX.CreateEnergyCharge({ CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)), Color = pal.Main, Color2 = pal.Light, MaxRadius = 3, Duration = data.Duration, Rings = 3 })
		task.delay(data.Duration, function()
			vortexCore:Release()
		end)
		spiral(CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(-math.pi / 2, 0, 0), data.Radius * 0.8, data.Duration)
		VFXLib.sound(sounds.ChargeLoop, pos, 0.8, 0.6)
		breakerSpirit(pos, data.Duration)
		-- Rings that shrink inward show the pull.
		local pulses = math.floor(data.Duration / 0.4)
		for i = 0, pulses - 1 do
			task.delay(i * 0.4, function()
				local ring = VFXLib.ring({ CFrame = ground * CFrame.new(0, 0.3, 0), Radius = data.Radius * 1.3, Width = 0.3, Color = pal.Light, Transparency = 0.2 })
				VFXLib.animate(0.4, function(a)
					ring:SetRadius(data.Radius * 1.3 * (1 - a * 0.85))
					ring:SetTransparency(0.2 + a * 0.8)
				end, function()
					ring:Destroy()
				end)
			end)
		end
		-- Dust swirling in.
		local swirl = VFXLib.anchor(CFrame.new(pos), data.Duration + 1)
		swirl.Shape = Enum.PartType.Ball
		swirl.Size = Vector3.new(data.Radius * 2.4, data.Radius * 2.4, data.Radius * 2.4)
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = VFXLib.Textures.Smoke
		dust.Shape = Enum.ParticleEmitterShape.Sphere
		dust.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		dust.Color = ColorSequence.new(Color3.fromRGB(205, 185, 140))
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 1) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(0.6, 0.8)
		dust.Speed = NumberRange.new(data.Radius * 1.8, data.Radius * 2.2)
		dust.RotSpeed = NumberRange.new(200, 300)
		dust.Rate = 25 * VFXQuality.get().Particles
		dust.Parent = swirl
		task.delay(data.Duration, function()
			dust.Enabled = false
		end)
	elseif data.Phase == "Burst" then
		local pos = data.Position
		TuskVFX.CreateRotationalShockwave(CFrame.new(pos - Vector3.new(0, 1, 0)), { Radius = data.Radius * 1.6, Layers = 4, Color = pal.Main, Color2 = pal.Light, Ground = true, Particles = 3, Width = 1, Duration = 0.7 })
		TuskVFX.CreateDistortion(pos, { Radius = 10, Duration = 0.5 })
		TuskVFX.CreateRotationalShockwave(CFrame.new(pos + Vector3.new(0, 5, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = data.Radius, Layers = 2, Color = pal.Light, Color2 = pal.Main, Particles = 0, Width = 0.6 })
		TuskVFX.CreateEnergyPillar(pos - Vector3.new(0, 2, 0), { Radius = data.Radius * 0.8, Height = 70, Color = pal.Light, Color2 = pal.Main, Duration = 0.7 })
		TuskVFX.CreateGroundCracks(pos, { Radius = data.Radius * 1.2, Color = pal.Main, Duration = 2.2 })
		TuskVFX.CreateImpactStar(pos + Vector3.new(0, 1.5, 0), { Size = 16, Rays = 12, Color = pal.Main, Color2 = pal.Light, Duration = 0.45, Width = 1.8 })
		VFXLib.burst(pos, { Count = 60, Color = pal.Light, Speed = 55, Lifetime = 0.7 })
		VFXLib.flash(pos, pal.Light, 14, 60, 0.7)
		VFXLib.sound(sounds.AwakeningBurst, pos, 1, 0.8)
		CameraFX.shakeAt(pos, 1.5, 110)
		local camera = workspace.CurrentCamera
		if Common.isLocal(character) or (camera and (camera.CFrame.Position - pos).Magnitude < 60) then
			CameraFX.impactFrame(pal.Light)
			CameraFX.speedLines(0.35, pal.Light)
		end
	end
end

---------------------------------------------------------------------------
-- SPIN TORNADO visual: a funnel of spinning rings that follows the server's
-- position updates, with a ground swirl, dust and green sparkles.
---------------------------------------------------------------------------
local tornadoes = {}

local function startTornado(data)
	local r = data.Radius
	local t = { Pos = data.Position, Target = data.Position, Rings = {}, Angle = 0, Radius = r }
	local layers = VFXQuality.get().RingSegments > 12 and 7 or 4
	for i = 1, layers do
		local k = (i - 1) / (layers - 1)
		t.Rings[i] = {
			Ring = VFXLib.ring({ Radius = r * (0.25 + k * 0.75), Width = 0.3 + k * 0.25, Color = (i % 2 == 0) and pal.Light or pal.Main, Transparency = 0.1 + k * 0.3 }),
			Height = -2.5 + k * 11,
			Speed = (9 - k * 4) * (i % 2 == 0 and -1 or 1),
			Tilt = (math.random() - 0.5) * 0.3,
		}
	end
	-- Swirling dust + sparkles on a carrier that moves with the tornado.
	local carrier = VFXLib.anchor(CFrame.new(data.Position))
	carrier.Size = Vector3.new(r * 1.2, 10, r * 1.2)
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = VFXLib.Textures.Smoke
	dust.Color = ColorSequence.new(Color3.fromRGB(205, 180, 135))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.6, 1.1)
	dust.Speed = NumberRange.new(6, 10)
	dust.RotSpeed = NumberRange.new(250, 400)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Shape = Enum.ParticleEmitterShape.Cylinder
	dust.Rate = 30 * VFXQuality.get().Particles
	dust.Parent = carrier
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = VFXLib.Textures.Sparkle
	sparks.Color = ColorSequence.new(pal.Light, pal.Main)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.4, 0.7)
	sparks.Speed = NumberRange.new(8, 14)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Shape = Enum.ParticleEmitterShape.Cylinder
	sparks.Rate = 40 * VFXQuality.get().Particles
	sparks.Parent = carrier
	t.Carrier = carrier
	local high = VFXQuality.get().RingSegments > 12
	-- Spiral strands of light winding up the funnel (rotated every frame).
	local helix = VFXLib.anchor(CFrame.new(data.Position))
	local strands = high and 3 or 2
	local points = high and 14 or 8
	for sIdx = 1, strands do
		local prev
		for i = 0, points do
			local k = i / points
			local th = k * math.pi * 3 + (sIdx - 1) / strands * math.pi * 2
			local rad = r * (0.2 + k * 0.85)
			local a = Instance.new("Attachment")
			a.Position = Vector3.new(math.cos(th) * rad, -2.5 + k * 12, math.sin(th) * rad)
			a.Parent = helix
			if prev then
				local b = Instance.new("Beam")
				b.Attachment0 = prev
				b.Attachment1 = a
				b.FaceCamera = true
				b.LightEmission = 1
				b.LightInfluence = 0
				b.Segments = 1
				b.Width0 = 0.35 + k * 0.3
				b.Width1 = 0.35 + k * 0.3
				b.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(pal.Main, k))
				b.Transparency = NumberSequence.new(0.15 + k * 0.45)
				b.Parent = helix
			end
			prev = a
		end
	end
	t.Helix = helix
	-- See-through wind body: stacked force-field rings of air.
	t.Body = {}
	for i = 1, (high and 3 or 2) do
		local k = (i - 1) / 2
		local d = r * (0.6 + k * 1.1)
		t.Body[i] = {
			Part = VFXLib.part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = i == 2 and pal.Light or pal.Main, Transparency = 0.15, Size = Vector3.new(4, d, d) }),
			Height = -1 + k * 8,
			Speed = (i % 2 == 0) and -7 or 9,
		}
	end
	-- Ground swirl: a flat ring of churned dust at the base.
	t.Ground = VFXLib.ring({ Radius = r * 1.3, Width = 0.5, Color = Color3.fromRGB(225, 205, 160), Transparency = 0.35, LightEmission = 0.2 })
	-- Debris sucked up the funnel: rocks and planks that orbit and rise.
	t.Debris = {}
	local debrisCount = high and 8 or 4
	for i = 1, debrisCount do
		local isPlank = i % 3 == 0
		t.Debris[i] = {
			Part = VFXLib.part({ Material = isPlank and Enum.Material.Wood or Enum.Material.Sandstone, Color = isPlank and Color3.fromRGB(120, 84, 52) or Color3.fromRGB(180, 150, 110), Size = isPlank and Vector3.new(0.3, 0.3, 1.6) or Vector3.new(0.7, 0.6, 0.7), CastShadow = true }),
			Phase = i / debrisCount * math.pi * 2,
			Rise = math.random(),
			Speed = 0.35 + math.random() * 0.3,
		}
	end
	t.NextBolt = os.clock() + 0.2
	t.Sound = VFXLib.sound(sounds.ChargeLoop, carrier, 0.6, 0.6, true)
	t.Expire = os.clock() + data.Duration + 1
	tornadoes[data.Id] = t
	VFXLib.burst(data.Position, { Count = 24, Color = pal.Light, Speed = 22, Lifetime = 0.45 })
	TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position - Vector3.new(0, 2.5, 0)), { Radius = r * 1.6, Layers = 2, Color = pal.Light, Color2 = pal.Main, Ground = true, Particles = 0.5, Width = 0.4, Duration = 0.4 })
end

local function endTornado(data)
	local t = tornadoes[data.Id]
	if t then
		tornadoes[data.Id] = nil
		for _, layer in ipairs(t.Rings) do
			layer.Ring:Destroy()
		end
		if t.Sound then
			t.Sound:Destroy()
		end
		t.Carrier:Destroy()
		t.Helix:Destroy()
		t.Ground:Destroy()
		for _, b in ipairs(t.Body) do
			b.Part:Destroy()
		end
		-- Debris is flung outward when the tornado bursts.
		for _, d in ipairs(t.Debris) do
			local part = d.Part
			local from = part.Position
			local out = Vector3.new(from.X - t.Pos.X, 0, from.Z - t.Pos.Z)
			out = (out.Magnitude > 0.01 and out.Unit or Vector3.new(1, 0, 0)) * (18 + math.random() * 10) + Vector3.new(0, 12, 0)
			local spin = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
			VFXLib.animate(0.9, function(a)
				local p = from + out * a + Vector3.new(0, -30 * a * a, 0)
				part.CFrame = CFrame.new(p) * CFrame.Angles(spin.X * a, spin.Y * a, spin.Z * a)
				part.Transparency = math.max(0, (a - 0.6) / 0.4)
			end, function()
				part:Destroy()
			end)
		end
	end
	local pos = data.Position
	TuskVFX.CreateRotationalShockwave(CFrame.new(pos - Vector3.new(0, 2.5, 0)), { Radius = data.Radius * 1.6, Layers = 3, Color = pal.Main, Color2 = pal.Light, Ground = true, Particles = 2, Width = 0.7 })
	VFXLib.burst(pos, { Count = 30, Color = pal.Light, Speed = 40, Lifetime = 0.5 })
	TuskVFX.CreateImpactStar(pos, { Size = 9, Rays = 10, Color = pal.Main, Color2 = pal.Light, Duration = 0.35, Width = 1 })
	TuskVFX.CreateEnergyPillar(pos - Vector3.new(0, 2.5, 0), { Radius = data.Radius * 0.9, Height = 35, Color = pal.Light, Color2 = pal.Main, Duration = 0.5 })
	TuskVFX.CreateGroundCracks(pos, { Radius = data.Radius * 1.4, Color = pal.Main, Duration = 1.6 })
	VFXLib.flash(pos, pal.Light, 8, 30, 0.4)
	VFXLib.sound(sounds.Finisher, pos, 0.8, 0.9)
	CameraFX.shakeAt(pos, 0.8, 70)
end

local function stepTornadoes(dt)
	local now = os.clock()
	for id, t in pairs(tornadoes) do
		t.Pos = t.Pos:Lerp(t.Target, math.min(1, dt * 10))
		t.Angle = t.Angle + dt
		for _, layer in ipairs(t.Rings) do
			local sway = math.sin(now * 3 + layer.Height) * 0.6
			layer.Ring:SetCFrame(CFrame.new(t.Pos + Vector3.new(sway, layer.Height, 0)) * CFrame.Angles(layer.Tilt, t.Angle * layer.Speed, 0))
		end
		t.Carrier.CFrame = CFrame.new(t.Pos + Vector3.new(0, 2, 0))
		t.Helix.CFrame = CFrame.new(t.Pos) * CFrame.Angles(0, -t.Angle * 7, 0)
		t.Ground:SetCFrame(CFrame.new(t.Pos - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, t.Angle * 5, 0))
		for _, b in ipairs(t.Body) do
			-- Upright cylinder (axis X -> world up), spun around its axis for a shimmer.
			b.Part.CFrame = CFrame.new(t.Pos + Vector3.new(0, b.Height, 0)) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(t.Angle * b.Speed, 0, 0)
		end
		for _, d in ipairs(t.Debris) do
			d.Rise = (d.Rise + dt * d.Speed) % 1
			local th = d.Phase + t.Angle * (8 - d.Rise * 3)
			local rad = t.Radius * (0.3 + d.Rise * 0.8)
			d.Part.CFrame = CFrame.new(t.Pos + Vector3.new(math.cos(th) * rad, -2 + d.Rise * 11, math.sin(th) * rad)) * CFrame.Angles(th * 2, th, 0)
		end
		-- Green Spin sparks crackling inside the funnel.
		if now >= t.NextBolt then
			t.NextBolt = now + 0.18 + math.random() * 0.2
			local th = math.random() * math.pi * 2
			local p = t.Pos + Vector3.new(math.cos(th) * t.Radius * 0.5, math.random() * 8 - 1, math.sin(th) * t.Radius * 0.5)
			TuskVFX.CreateImpactStar(p, { Size = 2, Rays = 4, Color = pal.Main, Color2 = Color3.new(1, 1, 1), Duration = 0.15 })
		end
		if now > t.Expire then
			endTornado({ Id = id, Position = t.Pos, Radius = t.Radius })
		end
	end
end

function Gyro.handle(name, data)
	if name == "Tornado" then
		if data.Phase == "Start" then
			startTornado(data)
		elseif data.Phase == "Move" then
			local t = tornadoes[data.Id]
			if t then
				t.Target = data.Position
			end
		elseif data.Phase == "Burst" then
			endTornado(data)
		end
		return
	end
	if name == "M1" then
		Common.m1(data, pal, { AnimPrefix = "G_M1_" })
	elseif name == "M1Finisher" then
		Common.finisher(data, pal)
		local entry = data.Character and held[data.Character]
		if entry then
			entry.Spin = 50
			task.delay(0.4, function()
				entry.Spin = 8
			end)
		end
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

local shakeTimer = 0
function Gyro.step(dt)
	dt = dt or 1 / 60
	updateHeld(dt)
	stepBalls(dt)
	stepTornadoes(dt)
	shakeTimer = shakeTimer + dt
	if shakeTimer > 0.25 then
		shakeTimer = 0
		updateShakes()
	end
end

-- Ball projectiles come through the shared SpinFX channel.
Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
	if typeof(data) ~= "table" or data.Kind ~= "GyroBall" then
		return
	end
	if name == "ProjectileSpawn" then
		spawnBall(data)
	elseif name == "ProjectileEnd" then
		endBall(data)
	end
end)

return Gyro
