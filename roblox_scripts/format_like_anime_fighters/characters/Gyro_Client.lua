--[[
	Gyro_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Gyro Zeppeli: Steel Balls and Ball Breaker.
	Its other half is Gyro_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: Gyro
-- ======================================================================
__modules["Gyro"] = function()
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
local Fighters = __require("Fighters")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local VFXQuality = __require("VFXQuality")
local Net = __require("Net")
local SteelBallModel = __require("SteelBallModel")
local WreckingBallModel = __require("WreckingBallModel")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Common = __require("TuskActCommon")

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
	for _, player in ipairs(Fighters.list()) do
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
	for _, player in ipairs(Fighters.list()) do
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
		local bounce = data.Visual and data.Visual.Bounce or 0
		glow = VFXLib.part({ Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = pal.Main:Lerp(pal.Light, math.min(bounce * 0.3, 0.8)), Transparency = 0.1, Size = Vector3.new(1.9, 1.9, 1.9) })
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
		local distance = math.min(v.Speed * VFXLib.flight(id, v.ServerTime), v.Range)
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
		if now > v.Expire + VFXLib.held(id, v.ServerTime) then
			balls[id] = nil
			removeBall(v)
		end
	end
end

---------------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------------
local vibrationStartup, vibrationHit -- defined below (they use the spiral helpers)

-- STEEL BALL THROW bounce: the ball ricochets off a wall.
local function ricochet(data)
	local pos, n = data.Position, data.Normal or Vector3.new(0, 1, 0)
	local bounce = data.Bounce or 1
	local hot = pal.Main:Lerp(Color3.new(1, 1, 1), math.min(bounce * 0.2, 0.6))
	-- Ring flat against the wall + sparks spraying along the new direction.
	local wallAxis = CFrame.lookAt(pos, pos + n) * CFrame.Angles(-math.pi / 2, 0, 0)
	TuskVFX.CreateRotationalShockwave(wallAxis, { Radius = 3 + bounce, Layers = 2, Color = hot, Color2 = pal.Main, Particles = 0, Width = 0.3, Duration = 0.3, Spin = 9 })
	TuskVFX.CreateImpactStar(pos, { Size = 4 + bounce, Rays = 7, Color = pal.Main, Color2 = Color3.new(1, 1, 1), Duration = 0.22 })
	VFXLib.burst(pos, { Count = 14 + bounce * 4, Color = hot, Speed = 38, Spread = 35, Direction = data.Direction or n, Lifetime = 0.3, Acceleration = Vector3.new(0, -30, 0) })
	VFXLib.burst(pos, { Count = 6, Texture = VFXLib.Textures.Smoke, Color = Color3.fromRGB(190, 170, 140), LightEmission = 0, Speed = 6, Lifetime = 0.7, Direction = n, Spread = 50 })
	VFXLib.flash(pos, hot, 5 + bounce, 18, 0.2)
	VFXLib.sound(sounds.NailImpact, pos, 0.55, 1.1 + bounce * 0.12)
	CameraFX.shakeAt(pos, 0.25 + bounce * 0.05, 45)
	-- Little "x2" popup so bank shots read clearly.
	local carrier = VFXLib.anchor(CFrame.new(pos + n * 1.5), 0.8)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(90, 40)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = carrier
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.Text = "BOUNCE x" .. bounce
	label.TextColor3 = hot
	label.TextStrokeTransparency = 0
	label.Parent = billboard
	local start = carrier.Position
	VFXLib.animate(0.75, function(a)
		carrier.Position = start + Vector3.new(0, a * 2.5, 0)
		label.TextTransparency = math.max(0, (a - 0.55) / 0.45)
		label.TextStrokeTransparency = label.TextTransparency
		local pop = a < 0.12 and (1 + (0.12 - a) * 5) or 1
		billboard.Size = UDim2.fromOffset(90 * pop, 40 * pop)
	end)
end

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
		elseif data.Phase == "Bounce" then
			ricochet(data)
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

-- Golden ratio spiral / Golden Rectangle in Gyro's green (shared in TuskVFX).
local function spiral(cframe, size, duration)
	TuskVFX.CreateGoldenSpiral(cframe, { Size = size, Duration = duration, Color = pal.Main, Color2 = pal.Light })
end

local function goldenRectangle(cframe, size, duration)
	TuskVFX.CreateGoldenRectangle(cframe, { Size = size, Duration = duration, Color = pal.Main, Color2 = pal.Light })
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


-- BALL BREAKER (the Stand, from the owner's picture, blocky): a green ribbed
-- figure with long arms and legs, a flat round "lid" head, pink bulbs all
-- over it and gold lightning crackling around it. Rises out of the vortex,
-- sways, then shatters into sparks.
local BB_GREEN = Color3.fromRGB(140, 215, 60)
local BB_DARK = Color3.fromRGB(70, 140, 40)
local BB_PINK = Color3.fromRGB(235, 150, 200)
local BB_GOLD = Color3.fromRGB(255, 220, 70)

local function breakerSpirit(position, duration)
	local quality = VFXQuality.get()
	local bits = {}
	-- Blocky like every Stand: round pieces become stepped "voxel-round" boxes
	-- (a core box plus crossing boxes), discs become stepped plates.
	local function block(size, offset, color, material)
		local p = VFXLib.part({ Material = material or Enum.Material.SmoothPlastic, Color = color, Size = size, Transparency = 0.1 })
		table.insert(bits, { Part = p, Offset = offset, Size = size })
		return p
	end
	local function piece(size, offset, color, shape, material)
		if shape == "Ball" then
			if math.max(size.X, size.Y, size.Z) < 0.7 then
				return block(size * 0.82, offset, color, material)
			end
			local core = block(size * 0.86, offset, color, material)
			block(Vector3.new(size.X, size.Y * 0.62, size.Z * 0.62), offset, color, material)
			block(Vector3.new(size.X * 0.62, size.Y, size.Z * 0.62), offset, color, material)
			block(Vector3.new(size.X * 0.62, size.Y * 0.62, size.Z), offset, color, material)
			return core
		elseif shape == "Cylinder" then
			-- Disc: thickness along X, round face in Y/Z.
			local core = block(Vector3.new(size.X, size.Y * 0.86, size.Z * 0.86), offset, color, material)
			block(Vector3.new(size.X, size.Y, size.Z * 0.62), offset, color, material)
			block(Vector3.new(size.X, size.Y * 0.62, size.Z), offset, color, material)
			return core
		end
		return block(size, offset, color, material)
	end
	local flat = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis -> up
	-- Body: ribbed green torso and hips.
	piece(Vector3.new(3.0, 3.6, 2.0), CFrame.new(0, 6.0, 0), BB_GREEN, "Ball")
	piece(Vector3.new(2.4, 1.6, 1.8), CFrame.new(0, 3.9, 0), BB_GREEN, "Ball")
	for i = 0, (quality.RingSegments > 12 and 4 or 2) do
		piece(Vector3.new(3.05 - i * 0.12, 0.18, 2.05 - i * 0.08), CFrame.new(0, 7.2 - i * 0.6, 0), BB_DARK, "Ball")
	end
	-- Head: short neck, wide flat lid with a raised cap and a second smaller lid.
	piece(Vector3.new(0.5, 1.2, 1.2), CFrame.new(0, 7.85, -0.2) * flat, BB_DARK, "Cylinder")
	piece(Vector3.new(0.35, 3.6, 3.6), CFrame.new(0, 8.25, -0.2) * CFrame.Angles(0.15, 0, 0) * flat, BB_GREEN, "Cylinder")
	piece(Vector3.new(0.9, 1.9, 1.9), CFrame.new(-0.3, 8.75, -0.2) * flat, BB_GREEN, "Cylinder")
	piece(Vector3.new(0.3, 2.2, 2.2), CFrame.new(1.7, 8.6, 0.4) * CFrame.Angles(0.1, 0, -0.2) * flat, BB_GREEN, "Cylinder")
	-- Long arms and legs.
	for _, side in ipairs({ -1, 1 }) do
		piece(Vector3.new(0.9, 2.6, 0.9), CFrame.new(side * 1.9, 6.4, -0.3) * CFrame.Angles(0.3, 0, side * 0.35), BB_GREEN, "Ball")
		piece(Vector3.new(0.75, 2.4, 0.75), CFrame.new(side * 2.6, 4.4, -0.9) * CFrame.Angles(0.6, 0, side * 0.15), BB_GREEN, "Ball")
		piece(Vector3.new(0.6, 0.5, 0.7), CFrame.new(side * 2.8, 3.2, -1.5), BB_PINK, "Ball") -- pink fingertips
		piece(Vector3.new(1.0, 2.6, 1.0), CFrame.new(side * 0.75, 2.4, 0.1) * CFrame.Angles(-0.1, 0, side * 0.1), BB_GREEN, "Ball")
		piece(Vector3.new(0.85, 2.4, 0.85), CFrame.new(side * 0.9, 0.5, 0.3) * CFrame.Angles(0.2, 0, -side * 0.05), BB_GREEN, "Ball")
		piece(Vector3.new(0.8, 0.5, 1.2), CFrame.new(side * 0.95, -0.7, -0.1), BB_PINK, "Ball") -- pink toes
	end
	-- Pink bulbs studded over the body.
	local bulbs = quality.RingSegments > 12 and 14 or 7
	for i = 1, bulbs do
		local a = i * 2.4
		local y = 4.4 + (i % 7) * 0.55
		piece(Vector3.new(0.34, 0.34, 0.34), CFrame.new(math.cos(a) * 1.35, y, math.sin(a) * 0.9 - 0.1), BB_PINK, "Ball")
		piece(Vector3.new(0.08, 0.35, 0.08), CFrame.new(math.cos(a) * 1.35, y - 0.25, math.sin(a) * 0.9 - 0.1), BB_DARK)
	end
	-- Gold lightning: zigzag beams crackling around the figure, re-drawn every frame.
	local carrier = VFXLib.anchor(CFrame.new(position))
	local bolts = {}
	for b = 1, (quality.RingSegments > 12 and 4 or 2) do
		local atts = {}
		for k = 0, 6 do
			local att = Instance.new("Attachment")
			att.Parent = carrier
			atts[k] = att
			if k > 0 then
				local beam = Instance.new("Beam")
				beam.Attachment0 = atts[k - 1]
				beam.Attachment1 = att
				beam.FaceCamera = true
				beam.LightEmission = 1
				beam.LightInfluence = 0
				beam.Segments = 1
				beam.Width0 = 0.3
				beam.Width1 = 0.3
				beam.Color = ColorSequence.new(BB_GOLD, Color3.fromRGB(255, 250, 200))
				beam.Parent = carrier
			end
		end
		bolts[b] = { Atts = atts, Side = (b % 2 == 0) and 1 or -1, Height = 2 + b * 1.6 }
	end
	local light
	if quality.Lights then
		light = Instance.new("PointLight")
		light.Color = BB_GREEN
		light.Range = 30
		light.Brightness = 4
		light.Parent = bits[1].Part
	end
	local sway = 0
	VFXLib.animate(duration, function(a, dt)
		sway = sway + (dt or 0)
		local rise = VFXLib.easeOut(math.min(a / 0.3, 1))
		local base = CFrame.new(position + Vector3.new(0, -4 + rise * 4, 0)) * CFrame.Angles(0, math.sin(sway * 1.3) * 0.4 + a * 1.2, math.sin(sway * 2) * 0.05)
		local fade = a > 0.85 and (a - 0.85) / 0.15 or 0
		for _, b in ipairs(bits) do
			b.Part.CFrame = base * b.Offset
			b.Part.Size = b.Size * (0.4 + rise * 0.6)
			b.Part.Transparency = 0.1 + fade * 0.9
		end
		carrier.CFrame = base
		-- New lightning shape every frame: jagged lines arcing around the body.
		for _, bolt in ipairs(bolts) do
			for k = 0, 6 do
				local t = k / 6
				local angle = bolt.Side * (t * 2.4 - 1.2) + sway * 2
				local r = 3.2 + (k % 2 == 0 and 0.6 or -0.4) + (math.random() - 0.5) * 0.8
				bolt.Atts[k].Position = Vector3.new(math.cos(angle) * r, bolt.Height + t * 3 + (math.random() - 0.5) * 0.8, math.sin(angle) * r) * (0.4 + rise * 0.6)
			end
		end
		for _, beam in ipairs(carrier:GetChildren()) do
			if beam:IsA("Beam") then
				beam.Transparency = NumberSequence.new(math.max(fade, math.random() < 0.15 and 0.8 or 0))
			end
		end
	end, function()
		-- Shatter: every piece bursts into sparks.
		for i, b in ipairs(bits) do
			if i % 6 == 1 then
				VFXLib.burst(b.Part.Position, { Count = 5, Color = i % 12 == 1 and BB_GREEN or BB_PINK, Speed = 30, Lifetime = 0.5 })
			end
			b.Part:Destroy()
		end
		VFXLib.burst(position + Vector3.new(0, 5, 0), { Count = 20, Color = BB_GOLD, Speed = 40, Lifetime = 0.4 })
		carrier:Destroy()
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
end

-- ======================================================================
-- MODULE: GyroEyesVFX
-- ======================================================================
__modules["GyroEyesVFX"] = function()
--[[
	TuskActVFX.GyroEyesVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.GyroEyesVFX)

	Client visuals for GYRO WITH THE SAINT'S EYES (Act 29). Blocky.
	  * his steel ball now has the corpse's EYE set into it (a white eyeball,
	    brown iris), spinning in his hand; the other eye is in his face
	    (GyroOutfit)
	  * STEEL BALL COMBO: as ever (green swipes)
	  * SCAN SHOT: the eye-ball flies out, green spiral trails, curving after
	    its target; whoever it hits glows for him (seen through walls)
	  * SCAN: a green ring sweeps out; VIBRATION LINES ripple across the
	    ground (a big wave, then wavy rings and jittering dashes round him
	    for as long as it lasts); for him the world dims and every enemy in
	    range glows green through walls, an eye over its head and small
	    vibration rings pulsing under its feet
	  * EYE RICOCHET: the eye-ball bounces from enemy to enemy, a green spark
	    at each one
	  * SCAN: GOLDEN SPIN: the target is locked (a golden rectangle round
	    them, for him), then a golden-spinning ball streaks straight through
	    everything to them; golden spirals hold them paralysed
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local VFXQuality = __require("VFXQuality")
local SteelBallModel = __require("SteelBallModel")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Common = __require("TuskActCommon")
local Fighters = __require("Fighters")

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
	add("Eyeball", Vector3.new(0.55, 0.55, 0.3) * size, CFrame.new(0, 0, -0.42 * size), WHITE)
	add("Iris", Vector3.new(0.26, 0.26, 0.08) * size, CFrame.new(0, 0, -0.56 * size), IRIS)
	add("Pupil", Vector3.new(0.12, 0.12, 0.05) * size, CFrame.new(0, 0, -0.6 * size), Color3.fromRGB(16, 12, 10))
	return ball
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
					entry = { Ball = ball, Weld = weld, Grip = grip, Angle = 0, Character = character }
					held[character] = entry
					TuskAnimation.hold(character, "GyroIdle")
				end
				-- The eye keeps turning to look out (slow spin round, then faces forward).
				entry.Angle = entry.Angle + dt * 1.5
				entry.Weld.C0 = entry.Grip * CFrame.Angles(0, math.sin(entry.Angle) * 0.8, 0)
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

---------------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------------
local function flyShot(data)
	local model = eyeBall(1.1)
	model.PrimaryPart.Anchored = true
	model.Parent = VFXLib.Folder
	trails(model.PrimaryPart, GREEN)
	local job = { Model = model }
	shots[data.Id] = job
	local pos, vel = data.From, (data.Direction or Vector3.new(0, 0, -1)) * (data.Speed or 95)
	local turn, target = data.Turn or 6, data.Target
	VFXLib.animate(data.Life or 2.5, function(_, dt)
		if shots[data.Id] ~= job then
			return
		end
		dt = dt or 1 / 60
		local tr = typeof(target) == "Instance" and target.Parent and target:FindFirstChild("HumanoidRootPart")
		if tr then
			local want = (tr.Position - pos).Unit * vel.Magnitude
			vel = (vel + (want - vel) * math.min(1, turn * dt)).Unit * vel.Magnitude
		end
		pos = pos + vel * dt
		-- The eye looks where it's going.
		model:PivotTo(CFrame.lookAt(pos, pos + vel))
	end, function()
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
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "GyroThrow")
		elseif phase == "Fly" and data.From then
			if character then
				hideHeld(character, 1.0)
			end
			flyShot(data)
		elseif phase == "End" then
			local job = data.Id and shots[data.Id]
			if job then
				shots[data.Id] = nil
				job.Model:Destroy()
			end
			if data.Position then
				if data.Hit then
					TuskVFX.CreateImpact(data.Position, Vector3.new(0, 1, 0), { Size = 1.2, Radius = 4, Layers = 2, Color = GREEN, Color2 = WHITE, Sound = sounds.NailImpact, Pitch = 0.85 })
				else
					VFXLib.burst(data.Position, { Count = 8, Color = GREEN, Speed = 12, Lifetime = 0.3 })
				end
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
			-- Vibration lines across the ground: a big wave out, then
			-- smaller ones round him for as long as the scan lasts.
			vibrationRing(data.Position, math.min(data.Range or 130, 60), GREEN, 1.4, 14)
			vibrationDashes(data.Position, 14, GREEN)
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
					vibrationRing(r.Position, 22, GREEN, 1.0, 11)
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
			local pts, gap = data.Points, data.Gap or 0.16
			local legs = #pts - 1
			VFXLib.animate(legs * gap, function(a)
				local f = a * legs
				local i = math.min(legs, math.floor(f) + 1)
				local k = f - (i - 1)
				local p = pts[i]:Lerp(pts[i + 1], math.clamp(k, 0, 1))
				model:PivotTo(CFrame.lookAt(p, pts[i + 1]))
			end, function()
				model:Destroy()
			end)
			for i = 2, #pts do
				task.delay((i - 1) * gap, function()
					TuskVFX.CreateImpactStar(pts[i], { Size = 2.2, Rays = 6, Color = GREEN, Color2 = WHITE, Duration = 0.12 })
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
		if isMe(character) and typeof(data.Target) == "Instance" then
			reveal(data.Target, (data.Windup or 1) + 1.5, GOLD)
			CameraFX.fovPunch(-12, 0.6)
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
		local len = (to - from).Magnitude
		local beam = VFXLib.part({ Size = Vector3.new(0.5, 0.5, len), CFrame = CFrame.lookAt((from + to) / 2, to), Color = GOLD, Transparency = 0.3 })
		VFXLib.animate(0.25, function(a)
			local p = from:Lerp(to, a)
			ball:PivotTo(CFrame.lookAt(p, to) * CFrame.Angles(0, 0, a * 20))
		end, function()
			ball:Destroy()
		end)
		VFXLib.animate(0.6, function(a)
			beam.Transparency = 0.3 + 0.7 * a
		end, function()
			beam:Destroy()
		end)
		task.delay(0.25, function()
			TuskVFX.CreateImpact(to, Vector3.new(0, 1, 0), { Size = 1.8, Radius = 7, Layers = 3, Color = GOLD, Color2 = WHITE, Sound = sounds.NailImpact, Pitch = 0.7 })
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
	elseif name == "M1Finisher" then
		Common.finisher(data, pal)
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
	slow = slow + dt
	if slow > 0.2 then
		slow = 0
		stepReveals()
	end
end

return GyroEyesVFX
end

-- ======================================================================
-- MODULE: SteelBallModel
-- ======================================================================
__modules["SteelBallModel"] = function()
--[[
	SteelBallModel  (ReplicatedStorage.SpinShared.SteelBallModel)

	Procedurally builds the Steel Ball from the owner's reference images:
	a glossy green metal sphere with raised hexagon panels (dark outer edge
	plus a bright inner edge, so they read as raised plates), round
	panels, and curved parallel grooves sweeping around the surface.

	SteelBallModel.build(diameter, detailed) -> Model (PrimaryPart = "Core")
	  detailed = false (Low quality) keeps only the hexagon outer edges.

	All parts are visual only: no collision, no queries, no touch events,
	massless, and welded to the Core. Anchor the Core to move it with
	PivotTo, or weld the Core to a hand.

	Swapping in a real mesh later: put a Model named "SteelBall" (with a
	PrimaryPart) in ReplicatedStorage.SpinShared.Assets and build() will
	clone and resize it instead of generating one.
]]

local SpinConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("SpinConfig"))

local SteelBallModel = {}

-- Panel layout (unit directions on the ball, angular radius in radians).
-- Kept as data so the look can be tuned without touching the builder.
SteelBallModel.Layout = {
	Hexagons = {
		{ Dir = Vector3.new(-0.45, 0.35, 0.82), Radius = 0.55, Spin = 0.2 },
		{ Dir = Vector3.new(0.6, -0.2, -0.77), Radius = 0.5, Spin = 0.5 },
		{ Dir = Vector3.new(-0.3, -0.85, -0.4), Radius = 0.45, Spin = 0.0 },
	},
	Circles = {
		{ Dir = Vector3.new(0.45, -0.4, 0.8), Radius = 0.3 },
		{ Dir = Vector3.new(0.2, 0.85, -0.45), Radius = 0.35 },
	},
	-- Grooves: arcs of a circle around Axis at angular radius Radius,
	-- from angle From to To (radians).
	Grooves = {
		{ Axis = Vector3.new(0.95, 0.25, 0.15), Radius = 0.5, From = -1.2, To = 1.3 },
		{ Axis = Vector3.new(0.95, 0.25, 0.15), Radius = 0.78, From = -1.0, To = 1.1 },
		{ Axis = Vector3.new(-0.75, 0.15, -0.6), Radius = 0.6, From = 0.6, To = 3.2 },
	},
}

local function visualPart(props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function weld(core, part)
	local w = Instance.new("WeldConstraint")
	w.Part0 = core
	w.Part1 = part
	w.Parent = part
end

-- Two unit vectors perpendicular to dir.
local function basis(dir)
	local helper = math.abs(dir.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local u = dir:Cross(helper).Unit
	local v = dir:Cross(u).Unit
	return u, v
end

-- Point on the unit sphere at angular distance `radius` from `center`, around angle `theta`.
local function around(center, radius, theta)
	local u, v = basis(center)
	return (center * math.cos(radius) + (u * math.cos(theta) + v * math.sin(theta)) * math.sin(radius)).Unit
end

local function fromOverride(diameter)
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
	local custom = assets and assets:FindFirstChild("SteelBall")
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		local clone = custom:Clone()
		local size = clone:GetExtentsSize()
		local largest = math.max(size.X, size.Y, size.Z)
		if largest > 0 then
			clone:ScaleTo(clone:GetScale() * diameter / largest)
		end
		clone.PrimaryPart.Name = "Core"
		return clone
	end
	return nil
end

function SteelBallModel.build(diameter, detailed)
	diameter = diameter or 1
	if detailed == nil then
		detailed = true
	end

	local override = fromOverride(diameter)
	if override then
		return override
	end

	local colors = SpinConfig.Colors
	local r = diameter / 2

	local model = Instance.new("Model")
	model.Name = "SteelBall"

	local core = visualPart({
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		Color = colors.Ball,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.18,
		Massless = false,
	})
	core.CFrame = CFrame.new()
	core.Parent = model
	model.PrimaryPart = core

	-- Attachments other systems hook effects onto.
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = core
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, r * 0.9, 0)
	top.Parent = core
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -r * 0.9, 0)
	bottom.Parent = core

	-- One straight raised line between two directions on the surface.
	local function line(a, b, width, color, name)
		local lift = r * 1.012
		local pa, pb = a * lift, b * lift
		local mid = (pa + pb) / 2
		local seg = visualPart({
			Name = name,
			Size = Vector3.new(width, width * 0.5, (pb - pa).Magnitude + width * 0.6),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0.1,
		})
		seg.CFrame = CFrame.lookAt(mid, pb, mid.Unit)
		seg.Parent = model
		weld(core, seg)
	end

	local function polygon(dirCenter, radius, sides, spin, width, color, name)
		local c = dirCenter.Unit
		for i = 0, sides - 1 do
			local a = around(c, radius, spin + i / sides * math.pi * 2)
			local b = around(c, radius, spin + (i + 1) / sides * math.pi * 2)
			line(a, b, width, color, name)
		end
	end

	local layout = SteelBallModel.Layout

	-- Hexagon plates: dark outer edge, bright inner edge.
	for _, hex in ipairs(layout.Hexagons) do
		polygon(hex.Dir, hex.Radius, 6, hex.Spin, diameter * 0.04, colors.BallDark, "HexEdge")
		if detailed then
			polygon(hex.Dir, hex.Radius * 0.84, 6, hex.Spin, diameter * 0.025, colors.BallLight, "HexHighlight")
		end
	end

	if detailed then
		-- Round panels.
		for _, circle in ipairs(layout.Circles) do
			polygon(circle.Dir, circle.Radius, 10, 0, diameter * 0.035, colors.BallDark, "RoundPanel")
		end
		-- Curved grooves.
		for _, groove in ipairs(layout.Grooves) do
			local axis = groove.Axis.Unit
			local steps = 6
			for i = 0, steps - 1 do
				local t0 = groove.From + (groove.To - groove.From) * i / steps
				local t1 = groove.From + (groove.To - groove.From) * (i + 1) / steps
				line(around(axis, groove.Radius, t0), around(axis, groove.Radius, t1), diameter * 0.03, colors.BallDark, "Groove")
			end
		end
	end

	return model
end

return SteelBallModel
end

-- ======================================================================
-- MODULE: WreckingBallModel
-- ======================================================================
__modules["WreckingBallModel"] = function()
--[[
	WreckingBallModel  (ReplicatedStorage.SpinShared.WreckingBallModel)

	Procedurally builds a Wrecking Ball from the owner's reference image:
	a glossy orange metal sphere, ten raised gold studs sitting in darker
	gold collars, and a dark seam groove wrapping around the surface.
	Not used yet: kept for the Wrecking Ball phase.

	WreckingBallModel.build(diameter, withGrooves) -> Model (PrimaryPart = "Core")

	All parts are visual only: no collision, no queries, no touch events,
	massless, and welded to the Core. Anchor the Core to move it with
	PivotTo, or weld the Core to a hand.

	Swapping in a real mesh later: put a Model named "WreckingBall" (with a
	PrimaryPart) in ReplicatedStorage.SpinShared.Assets and build() will
	clone it instead of generating one.
]]

local WreckingBallModel = {}

WreckingBallModel.Colors = {
	Ball = Color3.fromRGB(226, 96, 24),
	BallDark = Color3.fromRGB(150, 52, 12),
	Stud = Color3.fromRGB(255, 205, 70),
}

local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))
local STUD_COUNT = 10
local SEAM_SEGMENTS = 22

local function visualPart(props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function weld(core, part)
	local w = Instance.new("WeldConstraint")
	w.Part0 = core
	w.Part1 = part
	w.Parent = part
end

local function fromOverride(diameter)
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
	local custom = assets and assets:FindFirstChild("WreckingBall")
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		local clone = custom:Clone()
		local size = clone:GetExtentsSize()
		local largest = math.max(size.X, size.Y, size.Z)
		if largest > 0 then
			clone:ScaleTo(clone:GetScale() * diameter / largest)
		end
		clone.PrimaryPart.Name = "Core"
		return clone
	end
	return nil
end

function WreckingBallModel.build(diameter, withGrooves)
	diameter = diameter or 1
	if withGrooves == nil then
		withGrooves = true
	end

	local override = fromOverride(diameter)
	if override then
		return override
	end

	local colors = WreckingBallModel.Colors
	local r = diameter / 2

	local model = Instance.new("Model")
	model.Name = "WreckingBall"

	local core = visualPart({
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		Color = colors.Ball,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.2,
		Massless = false,
	})
	core.CFrame = CFrame.new()
	core.Parent = model
	model.PrimaryPart = core

	-- Attachments other systems hook effects onto.
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = core
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, r * 0.9, 0)
	top.Parent = core
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -r * 0.9, 0)
	bottom.Parent = core

	-- Gold studs on a Fibonacci sphere so they spread evenly.
	for i = 0, STUD_COUNT - 1 do
		local y = 1 - (i + 0.5) / STUD_COUNT * 2
		local ring = math.sqrt(1 - y * y)
		local theta = i * GOLDEN_ANGLE
		local dir = Vector3.new(math.cos(theta) * ring, y, math.sin(theta) * ring)
		local up = math.abs(dir.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)

		local collar = visualPart({
			Name = "StudCollar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(diameter * 0.05, diameter * 0.2, diameter * 0.2),
			Color = colors.BallDark:Lerp(colors.Stud, 0.35),
			Material = Enum.Material.Metal,
			Reflectance = 0.1,
		})
		-- Cylinder axis is X, so point RightVector along the surface normal.
		local right = dir
		local back = right:Cross(up).Unit
		local realUp = back:Cross(right).Unit
		collar.CFrame = CFrame.fromMatrix(dir * r * 0.985, right, realUp)
		collar.Parent = model
		weld(core, collar)

		local stud = visualPart({
			Name = "Stud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(diameter * 0.15, diameter * 0.15, diameter * 0.15),
			Color = colors.Stud,
			Material = Enum.Material.Metal,
			Reflectance = 0.35,
		})
		stud.CFrame = CFrame.new(dir * r * 1.01)
		stud.Parent = model
		weld(core, stud)
	end

	-- Seam groove: a wave wrapping the ball like a tennis-ball seam.
	if withGrooves then
		local function seamPoint(t)
			local lon = t * math.pi * 2
			local lat = 0.55 * math.sin(2 * lon)
			return Vector3.new(math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon)) * r * 1.003
		end
		for i = 0, SEAM_SEGMENTS - 1 do
			local a = seamPoint(i / SEAM_SEGMENTS)
			local b = seamPoint((i + 1) / SEAM_SEGMENTS)
			local mid = (a + b) / 2
			local len = (b - a).Magnitude
			local seg = visualPart({
				Name = "Groove",
				Size = Vector3.new(diameter * 0.035, diameter * 0.012, len * 1.08),
				Color = colors.BallDark,
				Material = Enum.Material.SmoothPlastic,
			})
			seg.CFrame = CFrame.lookAt(mid, b, mid.Unit)
			seg.Parent = model
			weld(core, seg)
		end
	end

	-- Everything was laid out around the origin; move the model as one piece from here on.
	return model
end

return WreckingBallModel
end
end
