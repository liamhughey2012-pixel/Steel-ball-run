--[[
	Gyro_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Gyro Zeppeli: Steel Balls and Ball Breaker.
	Its other half is Gyro_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "gyro" or __expect.Side ~= "client") then
		error("this is the code for Gyro_Client, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Gyro_Client and put it in ReplicatedStorage > SpinCharacters).", 0)
	end

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
	  * EYE RICOCHET: the eye-ball hops in arcs from enemy to enemy,
	    bouncing off the ground between on the longer hops (a spin ring in
	    the sand, a puff, small cracks); each hit throws a star, a spin
	    ripple and a vibration ring, greener to golder as the count climbs
	    ("1 HIT", "2 HITS", ... "5 HITS!"), the last one a big impact; the
	    hops stay drawn a moment; then the ball flies back to his hand
	  * VARIANTS (a name pops up over him): SKY SCAN (1 in the air: straight
	    down from him with a flash); SPLIT SHOT (1 while scanning: the
	    struck ball splits in a golden burst into several eye-balls); SKY
	    EYE (2 in the air: a green beam slams down, cracks and rings in the
	    ground); DOWNWARD RICOCHET (3 in the air: the ball cracks into the
	    ground in front first); TRACKING RICOCHET (3 while scanning); FULL
	    SCAN (G on a scanned target: rectangles keep bursting)
	  * THE CUTSCENE, when you take the Eyes as Gyro: kneeling in the sand
	    with the eye glistening in his palm; close on his hand; straight down
	    on his hat, tilting down over the brim and goggles to his face; the
	    eye in his cheek, manga panels flashing; "GO! GO! ZEPPELI"
	  * SCAN: GOLDEN SPIN: a turning GOLDEN RECTANGLE (nested golden-ratio
	    frames) locks onto the target, a gold eye opens over Gyro and a gold
	    spin gathers in his hand ("SCAN / GOLDEN SPIN" title for him); the
	    ball streaks straight through everything, a golden helix unwinding
	    along its path; golden rectangles burst out where it hits, a gold
	    vibration ring, and golden spirals hold them paralysed
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
local Cinematic = __require("Cinematic")
local Cutscenes = __require("Cutscenes")

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

-- A variant's name popping up over him.
local function variantName(character, text, color)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(300, 54)
	bb.StudsOffset = Vector3.new(0, 3.4, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Font = Enum.Font.Bangers
	tl.TextScaled = true
	tl.Text = text
	tl.TextColor3 = color
	tl.TextStrokeTransparency = 0.1
	tl.Parent = bb
	bb.Parent = VFXLib.Folder
	VFXLib.animate(1.3, function(a)
		bb.StudsOffset = Vector3.new(0, 3.4 + a * 1.2, 0)
		local pop = a < 0.12 and 0.6 + a / 0.12 * 0.4 or 1
		bb.Size = UDim2.fromOffset(300 * pop, 54 * pop)
		tl.TextTransparency = math.max(0, a * 1.8 - 0.8)
	end, function()
		bb:Destroy()
	end)
end

local splitBurst = {} -- [base id] = true once its split flash has played

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "ScanShot" then
		if phase == "Sky" and data.From then
			-- SKY SCAN: no toss, straight down from where he is.
			variantName(character, "SKY SCAN", ORANGE_LIGHT)
			if character then
				TuskAnimation.play(character, "GyroThrow")
				hideHeld(character, 0.9)
			end
			newShotBall(data.Id).Model:PivotTo(CFrame.new(data.From))
			VFXLib.flash(data.From, ORANGE_LIGHT, 5, 16, 0.12)
			TuskVFX.CreateRotationalShockwave(CFrame.new(data.From), { Radius = 3, Layers = 2, Color = ORANGE, Color2 = GREEN, Particles = 0.5, Width = 0.25, Duration = 0.25, Spin = 10 })
		elseif phase == "Toss" and data.From and data.Apex then
			if data.Variant == "Split" then
				variantName(character, "SPLIT SHOT", GOLD)
			end
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
			if data.Variant == "Split" then
				local base = string.match(tostring(data.Id), "^[^:]+")
				if base and not splitBurst[base] then
					splitBurst[base] = true
					-- The struck ball splits apart in a golden burst.
					VFXLib.flash(data.From, GOLD, 7, 20, 0.14)
					goldenBurst(data.From, 5)
					VFXLib.burst(data.From, { Count = 20, Color = GOLD, Speed = 22, Lifetime = 0.4 })
				end
			end
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
			if data.Variant == "Sky" then
				-- SKY EYE: from the air the vibration slams down into the ground.
				variantName(character, "SKY EYE", Color3.fromRGB(170, 245, 130))
				local g = groundAt(data.Position)
				local r = data.SlamRadius or 11
				TuskVFX.CreateRotationalShockwave(CFrame.new(g + Vector3.new(0, 0.2, 0)), { Radius = r, Layers = 3, Color = GREEN, Color2 = WHITE, Particles = 1, Width = 0.5, Duration = 0.4, Spin = 4 })
				TuskVFX.CreateGroundCracks(g, { Radius = r, Count = 8, Color = GREEN, Duration = 1.6 })
				local beam = VFXLib.part({ Size = Vector3.new(0.6, (data.Position - g).Magnitude + 0.1, 0.6), CFrame = CFrame.new((data.Position + g) / 2), Color = GREEN, Transparency = 0.2 })
				VFXLib.animate(0.35, function(a)
					beam.Transparency = 0.2 + 0.8 * a
				end, function()
					beam:Destroy()
				end)
				for w = 0, 2 do
					task.delay(w * 0.1, function()
						vibrationRing(g, r * (0.6 + w * 0.3), GREEN, 0.8, 10)
					end)
				end
				CameraFX.shakeAt(g, 0.7, 50)
			end
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
		elseif phase == "Smash" and data.Position then
			-- DOWNWARD RICOCHET: the eye-ball cracks into the ground in front first.
			variantName(character, "DOWNWARD RICOCHET", ORANGE_LIGHT)
			local g = data.Position
			if data.From then
				local len = (g - data.From).Magnitude
				local line = VFXLib.part({ Size = Vector3.new(0.3, 0.3, len), CFrame = CFrame.lookAt((data.From + g) / 2, g), Color = ORANGE_LIGHT, Transparency = 0.2 })
				VFXLib.animate(0.4, function(a)
					line.Transparency = 0.2 + 0.8 * a
				end, function()
					line:Destroy()
				end)
			end
			TuskVFX.CreateImpact(g, Vector3.new(0, 1, 0), { Size = 1.4, Radius = data.Radius or 7, Layers = 3, Color = ORANGE, Color2 = GREEN, Sound = sounds.NailImpact, Pitch = 0.7 })
			TuskVFX.CreateGroundCracks(g, { Radius = data.Radius or 7, Count = 7, Color = ORANGE, Duration = 1.4 })
			VFXLib.burst(g, { Count = 18, Color = Color3.fromRGB(220, 190, 140), Speed = 20, Lifetime = 0.5, Acceleration = Vector3.new(0, -40, 0) })
			vibrationRing(g, (data.Radius or 7) + 3, ORANGE, 0.7, 9)
			CameraFX.shakeAt(g, 0.6, 50)
		elseif phase == "Bounce" and data.Points and #data.Points >= 2 then
			if data.Variant == "Tracking" then
				variantName(character, "TRACKING RICOCHET", GOLD)
			end
			local pts, gap = data.Points, data.Gap or 0.22
			local hits = data.Hits or (#pts - 1)
			local back = data.Return or 0.35
			-- Its route: hop to each target, bouncing off the ground halfway on
			-- the longer hops; then back to his hand.
			local segs = {}
			for i = 1, #pts - 1 do
				local a0, b0 = pts[i], pts[i + 1]
				local len = (b0 - a0).Magnitude
				local isHit = i <= hits
				if len > 12 then
					local mid = groundAt((a0 + b0) / 2 + Vector3.new(0, 2, 0)) + Vector3.new(0, 0.6, 0)
					table.insert(segs, { From = a0, To = mid, Time = gap * 0.5, Height = math.min(4, len * 0.15), Kind = "Ground" })
					table.insert(segs, { From = mid, To = b0, Time = gap * 0.5, Height = math.min(4, len * 0.15), Kind = isHit and "Hit" or "Ground", Index = i })
				else
					table.insert(segs, { From = a0, To = b0, Time = gap, Height = math.min(3, 1 + len * 0.2), Kind = isHit and "Hit" or "Ground", Index = i })
				end
			end
			local total = 0
			for _, s in ipairs(segs) do
				s.Start = total
				total = total + s.Time
			end
			if character then
				hideHeld(character, total + back + 0.1)
			end
			local model = eyeBall(1.1)
			model.PrimaryPart.Anchored = true
			model.Parent = VFXLib.Folder
			trails(model.PrimaryPart, GREEN)
			arcsOn(model.PrimaryPart, 1.1, 3)
			local function arcPoint(s, k)
				return s.From:Lerp(s.To, k) + Vector3.new(0, math.sin(k * math.pi) * s.Height, 0)
			end
			local done = {}
			local function landed(s)
				local at = s.To
				if s.Kind == "Hit" then
					local n = s.Index or 1
					local last = n == hits
					local tint = GREEN:Lerp(GOLD, math.min(1, (n - 1) / 4))
					TuskVFX.CreateImpactStar(at, { Size = 2.2 + n * 0.3, Rays = 6 + n, Color = tint, Color2 = WHITE, Duration = 0.14 })
					TuskVFX.CreateRotationalShockwave(CFrame.lookAt(at, at + (at - s.From)) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = 2.4 + n * 0.4, Layers = 2, Color = ORANGE, Color2 = tint, Particles = 0.6, Width = 0.22, Duration = 0.28, Spin = 10 })
					vibrationRing(at, 4 + n, tint, 0.6, 7)
					-- The count climbs with every hit.
					local anchor = VFXLib.part({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(at + Vector3.new(0, 2.5, 0)), Transparency = 1 })
					local bb = Instance.new("BillboardGui")
					bb.Size = UDim2.fromOffset(110 + n * 18, 34 + n * 5)
					bb.AlwaysOnTop = true
					bb.Adornee = anchor
					local tl = Instance.new("TextLabel")
					tl.BackgroundTransparency = 1
					tl.Size = UDim2.fromScale(1, 1)
					tl.Font = Enum.Font.Bangers
					tl.TextScaled = true
					tl.Text = n == 1 and "1 HIT" or (n .. " HITS" .. (last and "!" or ""))
					tl.TextColor3 = tint
					tl.TextStrokeTransparency = 0.1
					tl.Parent = bb
					bb.Parent = VFXLib.Folder
					VFXLib.animate(0.8, function(a)
						bb.StudsOffset = Vector3.new(0, a * 1.5, 0)
						tl.TextTransparency = math.max(0, a * 1.6 - 0.6)
					end, function()
						bb:Destroy()
						anchor:Destroy()
					end)
					VFXLib.sound(sounds.NailImpact, at, 0.45, 1.1 + n * 0.08)
					if last then
						TuskVFX.CreateImpact(at, Vector3.new(0, 1, 0), { Size = 1.4, Radius = 5, Layers = 3, Color = GOLD, Color2 = GREEN, Sound = sounds.NailImpact, Pitch = 0.8 })
						CameraFX.shakeAt(at, 0.6, 50)
					end
				else
					-- Off the ground: a spin ring in the sand, a puff, small cracks.
					local g = groundAt(at + Vector3.new(0, 1, 0))
					TuskVFX.CreateRotationalShockwave(CFrame.new(g + Vector3.new(0, 0.15, 0)), { Radius = 2.6, Layers = 1, Color = ORANGE, Color2 = GREEN, Particles = 0.5, Width = 0.2, Duration = 0.3, Spin = 8 })
					TuskVFX.CreateGroundCracks(g, { Radius = 2.5, Count = 4, Color = GREEN, Duration = 0.8 })
					VFXLib.burst(g, { Count = 8, Color = Color3.fromRGB(220, 190, 140), Speed = 10, Lifetime = 0.4, Acceleration = Vector3.new(0, -40, 0) })
					VFXLib.sound(sounds.NailImpact, g, 0.3, 1.4)
				end
				-- The hop it just made stays drawn a moment.
				local steps = 6
				for k = 1, steps do
					local p0, p1 = arcPoint(s, (k - 1) / steps), arcPoint(s, k / steps)
					local len = (p1 - p0).Magnitude
					if len > 0.1 then
						local line = VFXLib.part({ Size = Vector3.new(0.12, 0.12, len), CFrame = CFrame.lookAt((p0 + p1) / 2, p1), Color = s.Kind == "Hit" and GREEN or ORANGE_LIGHT, Transparency = 0.25 })
						VFXLib.animate(0.7, function(a)
							line.Transparency = 0.25 + 0.75 * a
						end, function()
							line:Destroy()
						end)
					end
				end
			end
			-- Hop by hop...
			VFXLib.animate(total, function(a)
				local now = a * total
				for i, s in ipairs(segs) do
					if now >= s.Start and now <= s.Start + s.Time then
						local k = math.clamp((now - s.Start) / s.Time, 0, 1)
						local p = arcPoint(s, k)
						model:PivotTo(CFrame.lookAt(p, arcPoint(s, math.min(1, k + 0.05)) + Vector3.new(0, 0.001, 0)))
					end
					if not done[i] and now >= s.Start + s.Time - 1e-3 then
						done[i] = true
						landed(s)
					end
				end
			end, function()
				for i, s in ipairs(segs) do
					if not done[i] then
						done[i] = true
						landed(s)
					end
				end
				-- ...then back to his hand.
				local from = segs[#segs] and segs[#segs].To or pts[#pts]
				VFXLib.animate(back, function(a)
					local r = character and Common.rootOf(character)
					local to = r and (r.CFrame * CFrame.new(0.8, 0.5, -1)).Position or from
					local p = from:Lerp(to, VFXLib.easeOut(a)) + Vector3.new(0, math.sin(a * math.pi) * 3, 0)
					model:PivotTo(CFrame.lookAt(p, to + Vector3.new(0, 0.001, 0)))
				end, function()
					model:Destroy()
				end)
			end)
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Lock" and character and root then
		if data.Variant == "Full" then
			variantName(character, "FULL SCAN", GOLD)
		end
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
		if data.Variant == "Full" then
			-- The full Golden Spin: rectangles keep bursting.
			for k = 0, 2 do
				task.delay(0.25 + k * 0.12, function()
					goldenBurst(data.To, 7 + k * 3)
				end)
			end
		end
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

---------------------------------------------------------------------------
-- THE CUTSCENE (you, picking up the Saint's Eyes as Gyro): he kneels in
-- the sand with the eye glistening in his palm; close on his hand; the
-- camera looks straight down on his hat and tilts down over the brim and
-- goggles to his face; the eye is in his cheek (manga panels flash: his
-- eye, a slit green eye, a wide eye); he grins.
---------------------------------------------------------------------------
local function weldTo(parent, holder, name, size, color, cf, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = parent.CFrame * cf
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent
	w.Part1 = p
	w.Parent = p
	p.Parent = holder
	return p
end

---------------------------------------------------------------------------
-- THE SAINT'S EYES CUTSCENE (frame-matched to the user's anime clip, 10.75 s)
--   0.00-0.40  wide, high in front: kneeling in the dunes (fades in from dark)
--   0.40-1.57  his cupped palm: glowing liquid pooled in it, thin streams
--              running out between his fingers
--   1.57-3.13  straight down on his bowed hat, hair and cape whipping in
--              the wind
--   3.13-5.45  right on the goggles; the camera tilts slowly down until the
--              brim's edge shows his shadowed face, eyes glowing
--   5.45-7.80  darker, under the brim: tilting down past his glowing eye to
--              the great eyeball now set in his cheek
--   7.80-9.40  three slanted panels slide in over it: right, left, middle
--   9.40-10.75 the grin, washed pale: teal lips, gold teeth
---------------------------------------------------------------------------
local function cutPart(holder, name, size, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = holder
	return p
end

-- Where the liquid sits: cupped just in front of his fingers.
function GyroEyesVFX.palmSpot(character)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local body = character:FindFirstChild("HumanoidRootPart")
	if not hand or not body then
		return nil
	end
	return hand.Position + body.CFrame.LookVector * (hand.Size.Z / 2 + 0.2) + Vector3.new(0, 0.05, 0)
end

-- The Saint's eyes, melted to glowing liquid in his cupped palm, running
-- out between his fingers in thin streams (as in the clip: no eyeball).
local function palmEye(character, duration)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then
		return nil
	end
	local holder = Instance.new("Model")
	holder.Name = "SaintsEyePalm"
	local LIQUID = Color3.fromRGB(200, 250, 255)
	local pool = cutPart(holder, "Pool", Vector3.new(0.62, 0.16, 0.5), LIQUID, Enum.Material.Neon, 0.25)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = pool
	local core = cutPart(holder, "PoolCore", Vector3.new(0.34, 0.12, 0.26), Color3.new(1, 1, 1), Enum.Material.Neon, 0.1)
	local mesh2 = mesh:Clone()
	mesh2.Parent = core
	local streams = {}
	for k = 1, 3 do
		streams[k] = { Part = cutPart(holder, "Stream", Vector3.new(0.035, 1, 0.035), LIQUID, Enum.Material.Neon, 0.2), X = (k - 2) * 0.17, Phase = k * 1.7 }
	end
	-- It lights his hand from below, cyan.
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 240, 255)
	light.Range = 4
	light.Brightness = 2
	light.Shadows = false
	light.Parent = pool
	local glitter = {}
	for k = 1, 5 do
		glitter[k] = { Part = cutPart(holder, "Glitter", Vector3.new(0.05, 0.05, 0.05), Color3.new(1, 1, 1), Enum.Material.Neon, 1), Phase = k * 1.3, X = (math.random() - 0.5) * 0.4, Z = (math.random() - 0.5) * 0.3 }
	end
	holder.Parent = VFXLib.Folder
	local nextDrop = 0
	VFXLib.animate(duration or 3, function()
		if not holder.Parent or not hand.Parent then
			return
		end
		-- Lying flat in the cup of his hand, whatever way the hand is turned.
		local body = character:FindFirstChild("HumanoidRootPart")
		local at = GyroEyesVFX.palmSpot(character) or hand.Position
		local flat = body and CFrame.new(at) * (body.CFrame - body.CFrame.Position) or CFrame.new(at)
		local wobble = 1 + math.sin(os.clock() * 7) * 0.05
		pool.Size = Vector3.new(0.62 * wobble, 0.16, 0.5 / wobble)
		pool.CFrame = flat
		core.CFrame = flat * CFrame.new(0.05, 0.04, -0.03)
		light.Brightness = 1.8 + math.sin(os.clock() * 9) * 0.4
		for _, g in ipairs(glitter) do
			local tw = math.sin(os.clock() * 6 + g.Phase)
			g.Part.Transparency = tw > 0.6 and 0 or 1
			g.Part.CFrame = flat * CFrame.new(g.X, 0.09, g.Z) * CFrame.Angles(0, os.clock() * 4, math.pi / 4)
		end
		for _, s in ipairs(streams) do
			local len = 0.7 + 0.45 * (0.5 + 0.5 * math.sin(os.clock() * 5 + s.Phase))
			s.Part.Size = Vector3.new(0.035, len, 0.035)
			s.Part.CFrame = flat * CFrame.new(s.X, -0.06 - len / 2, 0.12)
		end
		local now = os.clock()
		if now >= nextDrop then
			nextDrop = now + 0.09
			local s = streams[math.random(1, 3)]
			local from = (flat * CFrame.new(s.X, -0.06 - s.Part.Size.Y, 0.12)).Position
			local drop = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.07, 0.11, 0.07), CFrame = CFrame.new(from), Color = LIQUID, Material = Enum.Material.Neon, Transparency = 0.2 })
			VFXLib.animate(0.35, function(a)
				local t = a * 0.35
				drop.CFrame = CFrame.new(from + Vector3.new(0, -10 * t * t, 0))
				drop.Transparency = 0.2 + 0.7 * a
			end, function()
				drop:Destroy()
			end)
		end
	end, function()
		holder:Destroy()
	end)
	return holder
end

-- The eye in his cheek, as in the clip: a big round eyeball bulging out
-- under his right eye, lavender in the shadow, a pale blue iris, a dark
-- pupil, a crescent of light on it and creases round the socket. It stares.
local function cheekEye(character)
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end
	-- (Sized to sit between his right eye and the corner of his mouth.)
	local s = head.Size.Y / 1.2 * 0.68
	local holder = Instance.new("Model")
	holder.Name = "SaintsEyeCheek"
	local at = CFrame.new(0.23 * head.Size.Y / 1.2, -0.1 * head.Size.Y / 1.2, -head.Size.Z / 2 - 0.015 * s)
	weldTo(head, holder, "Socket", Vector3.new(0.5, 0.48, 0.12) * s, Color3.fromRGB(70, 66, 120), at * CFrame.new(0, 0, 0.02 * s))
	weldTo(head, holder, "Eyeball", Vector3.new(0.42, 0.42, 0.26) * s, Color3.fromRGB(196, 190, 236), at * CFrame.new(0, 0, -0.06 * s))
	-- The crescent of light on its upper right (it stays put as the eye turns).
	weldTo(head, holder, "Crescent", Vector3.new(0.08, 0.2, 0.03) * s, Color3.fromRGB(250, 240, 200), at * CFrame.new(0.13 * s, 0.07 * s, -0.19 * s) * CFrame.Angles(0, 0, -0.5), Enum.Material.Neon)
	for c = -1, 1 do
		weldTo(head, holder, "Crease", Vector3.new(0.18, 0.02, 0.02) * s, Color3.fromRGB(40, 36, 80), at * CFrame.new(-0.24 * s, c * 0.1 * s, -0.04 * s) * CFrame.Angles(0, 0, c * 0.6))
	end
	weldTo(head, holder, "UnderLine", Vector3.new(0.3, 0.025, 0.02) * s, Color3.fromRGB(40, 36, 80), at * CFrame.new(0, -0.25 * s, -0.04 * s))
	-- The parts that turn: drawn on the eyeball's surface each frame.
	local function disc(name, size, color, material)
		local p = cutPart(holder, name, size, color, material)
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
		return p
	end
	local ring = disc("IrisRing", Vector3.new(0.22, 0.22, 0.04) * s, Color3.fromRGB(70, 80, 150))
	local iris = disc("Iris", Vector3.new(0.2, 0.2, 0.05) * s, Color3.fromRGB(150, 176, 240))
	local pupil = disc("Pupil", Vector3.new(0.07, 0.07, 0.03) * s, Color3.fromRGB(16, 14, 40))
	holder.Parent = VFXLib.Folder
	local ctl = { Holder = holder, Lock = nil }
	local radius = 0.13 * s
	-- Rolled up and away to start with (only the white showing, nearly).
	local away = Vector3.new(0.45, 0.85, -0.3).Unit
	local dir = away
	VFXLib.animate(30, function()
		if not holder.Parent or not head.Parent then
			return
		end
		local base = head.CFrame * at * CFrame.new(0, 0, -0.06 * s)
		local want = away + Vector3.new(math.sin(os.clock() * 2.3) * 0.08, 0, 0)
		local cam = workspace.CurrentCamera
		local pupilSize = 0.07
		if ctl.Lock and cam then
			-- Locked on: it stares straight down the camera.
			local d = cam.CFrame.Position - base.Position
			local r, u, l = base.RightVector, base.UpVector, base.LookVector
			local toCam = Vector3.new(d.X * r.X + d.Y * r.Y + d.Z * r.Z, d.X * u.X + d.Y * u.Y + d.Z * u.Z, -(d.X * l.X + d.Y * l.Y + d.Z * l.Z))
			toCam = toCam.Magnitude > 0 and toCam.Unit or Vector3.new(0, 0, -1)
			if toCam.Z > -0.35 then
				toCam = Vector3.new(toCam.X, toCam.Y, -0.35).Unit
			end
			local k = math.clamp((os.clock() - ctl.Lock) / 0.3, 0, 1)
			want = away:Lerp(toCam, VFXLib.easeOut(k)).Unit
			-- The pupil shrinks to a pinpoint as it focuses.
			pupilSize = 0.07 - 0.03 * math.clamp((os.clock() - ctl.Lock - 0.15) / 0.25, 0, 1)
		end
		dir = dir:Lerp(want, 0.35).Unit
		-- (On the eyeball's oval surface: wider than it is deep.)
		local surface = base * CFrame.new(dir.X * 0.21 * s, dir.Y * 0.21 * s, dir.Z * radius)
		local face = CFrame.lookAt(surface.Position, surface.Position + (base:VectorToWorldSpace(dir)))
		ring.CFrame = face * CFrame.new(0, 0, 0.004 * s)
		iris.CFrame = face
		pupil.Size = Vector3.new(pupilSize, pupilSize, 0.03) * s
		pupil.CFrame = face * CFrame.new(0, 0, -0.022 * s)
	end)
	function ctl.lockOn()
		ctl.Lock = os.clock()
	end
	return holder, ctl
end

-- His own eyes, glowing cyan in the shadow of the brim.
local function glowEyes(character)
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local s = head.Size.Y / 1.2
	local holder = Instance.new("Model")
	holder.Name = "SaintsEyeGlow"
	local f = -head.Size.Z / 2 - 0.02 * s
	local lit = {}
	for _, side in ipairs({ -1, 1 }) do
		local at = CFrame.new(side * 0.22 * s, 0.1 * s, f)
		table.insert(lit, weldTo(head, holder, "Glow", Vector3.new(0.26, 0.11, 0.03) * s, Color3.fromRGB(90, 230, 255), at, Enum.Material.Neon))
		table.insert(lit, weldTo(head, holder, "Core", Vector3.new(0.11, 0.08, 0.035) * s, Color3.new(1, 1, 1), at * CFrame.new(0, 0, -0.005 * s), Enum.Material.Neon))
		weldTo(head, holder, "Lid", Vector3.new(0.3, 0.03, 0.04) * s, Color3.fromRGB(20, 24, 50), at * CFrame.new(0, 0.07 * s, -0.004 * s) * CFrame.Angles(0, 0, side * -0.15))
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(110, 230, 255)
	light.Range = 3
	light.Brightness = 0
	light.Shadows = false
	light.Parent = lit[1]
	holder.Parent = VFXLib.Folder
	-- They come on with a flicker: on, off, on... then steady.
	local pattern = { 1, 0, 1, 1, 0, 1, 1, 1 }
	VFXLib.animate(0.4, function(a)
		local on = pattern[math.clamp(math.floor(a * #pattern) + 1, 1, #pattern)] == 1
		for _, p in ipairs(lit) do
			p.Transparency = on and 0 or 1
		end
		light.Brightness = on and 2.5 or 0
	end, function()
		for _, p in ipairs(lit) do
			p.Transparency = 0
		end
		light.Brightness = 2.5
	end)
	return holder
end

-- The grin: thick teal lips, two rows of gold teeth engraved
-- "GO! GO! ZEPPELI".
local function grinMouth(character)
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local s = head.Size.Y / 1.2
	local holder = Instance.new("Model")
	holder.Name = "SaintsEyeGrin"
	local f = -head.Size.Z / 2 - 0.015 * s
	local LIP = Color3.fromRGB(80, 210, 220)
	local LIP_SHADE = Color3.fromRGB(40, 150, 170)
	local GOLDT = Color3.fromRGB(236, 200, 96)
	-- (Flat boxes here, not the rounded eye pieces, so the engraving shows.)
	local function weldTo(parent, holder2, name, size, color, cf, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.CFrame = parent.CFrame * cf
		local w = Instance.new("WeldConstraint")
		w.Part0 = parent
		w.Part1 = p
		w.Parent = p
		p.Parent = holder2
		return p
	end
	weldTo(head, holder, "Mouth", Vector3.new(0.5, 0.16, 0.03) * s, Color3.fromRGB(30, 30, 40), CFrame.new(0, -0.33 * s, f))
	for row = 0, 1 do
		local y = -0.3 * s - row * 0.065 * s
		local teeth = weldTo(head, holder, row == 0 and "TeethTop" or "TeethBottom", Vector3.new(0.44, 0.06, 0.035) * s, GOLDT, CFrame.new(0, y, f - 0.006 * s), Enum.Material.Metal)
		-- The engraving, readable in the close-up.
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(440, 60)
		gui.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.Text = row == 0 and "GO! GO!" or "ZEPPELI"
		t.TextColor3 = Color3.fromRGB(110, 80, 20)
		t.Parent = gui
		gui.Parent = teeth
		for k = -3, 3 do
			weldTo(head, holder, "ToothLine", Vector3.new(0.008, 0.06, 0.04) * s, Color3.fromRGB(120, 90, 30), CFrame.new(k * 0.0625 * s, y, f - 0.008 * s))
		end
	end
	-- The lips: a full upper lip with a dip in the middle, a heavy lower lip,
	-- corners pulled up.
	for _, side in ipairs({ -1, 1 }) do
		weldTo(head, holder, "UpperLip", Vector3.new(0.27, 0.06, 0.05) * s, LIP, CFrame.new(side * 0.13 * s, -0.255 * s, f - 0.012 * s) * CFrame.Angles(0, 0, side * -0.12))
		weldTo(head, holder, "LipCorner", Vector3.new(0.09, 0.06, 0.05) * s, LIP, CFrame.new(side * 0.27 * s, -0.29 * s, f - 0.012 * s) * CFrame.Angles(0, 0, side * 0.7))
	end
	weldTo(head, holder, "LowerLip", Vector3.new(0.46, 0.08, 0.055) * s, LIP, CFrame.new(0, -0.405 * s, f - 0.012 * s))
	weldTo(head, holder, "LowerLipShade", Vector3.new(0.36, 0.025, 0.06) * s, LIP_SHADE, CFrame.new(0, -0.43 * s, f - 0.014 * s))
	holder.Parent = VFXLib.Folder
	-- A glint sweeping across the gold teeth, then a sparkle off the end.
	local glint = cutPart(holder, "Glint", Vector3.new(0.03, 0.15, 0.01) * s, Color3.new(1, 1, 1), Enum.Material.Neon, 1)
	task.delay(0.35, function()
		if not holder.Parent then
			return
		end
		VFXLib.animate(0.3, function(a)
			if not head.Parent then
				return
			end
			glint.Transparency = 0.1 + 0.9 * math.abs(a - 0.5) * 2
			glint.CFrame = head.CFrame * CFrame.new((-0.24 + 0.48 * a) * s, -0.33 * s, f - 0.03 * s) * CFrame.Angles(0, 0, 0.35)
		end, function()
			glint.Transparency = 1
			if head.Parent then
				local at = (head.CFrame * CFrame.new(0.26 * s, -0.3 * s, f - 0.04 * s)).Position
				VFXLib.burst(at, { Count = 6, Color = Color3.fromRGB(255, 240, 180), Speed = 3, Lifetime = 0.35 })
			end
		end)
	end)
	return holder
end

-- The desert wind (blowing toward the camera's right in every shot that
-- shows it): pale streaks, sand, and his long hair and green cape whipping.
local function wind(character, duration)
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not root or not head then
		return nil
	end
	local holder = Instance.new("Model")
	holder.Name = "SaintsEyeWind"
	local HAIR = Color3.fromRGB(240, 232, 150)
	local HAIR_SHADE = Color3.fromRGB(196, 210, 120)
	local CAPE = Color3.fromRGB(40, 210, 110)
	local CAPE_IN = Color3.fromRGB(230, 196, 60)
	local strands = {}
	for k = 1, 7 do
		local segs = {}
		for j = 1, 5 do
			segs[j] = cutPart(holder, "Hair", Vector3.new(0.16, 0.035, 0.6), k % 2 == 0 and HAIR or HAIR_SHADE)
		end
		strands[k] = { Segs = segs, Y = 0.35 - k * 0.1, Z = 0.1 + (k % 3) * 0.12, Phase = k * 0.9 }
	end
	local cape = {}
	for j = 1, 6 do
		cape[j] = { Outer = cutPart(holder, "Cape", Vector3.new(1.6, 0.05, 1.0), CAPE), Inner = cutPart(holder, "CapeLining", Vector3.new(1.5, 0.04, 0.95), CAPE_IN) }
	end
	holder.Parent = VFXLib.Folder
	local nextStreak = 0
	VFXLib.animate(duration, function()
		if not root.Parent or not head.Parent then
			return
		end
		local t = os.clock()
		local away = -root.CFrame.RightVector -- toward the camera's right (it faces him)
		local back = -root.CFrame.LookVector
		-- Hair: chains streaming off the back and sides of his head.
		for _, st in ipairs(strands) do
			local p = (head.CFrame * CFrame.new(0, st.Y * head.Size.Y, head.Size.Z * 0.4 + st.Z)).Position
			local dir = (away * 0.9 + back * 0.3 + Vector3.new(0, -0.15, 0)).Unit
			for j, seg in ipairs(st.Segs) do
				local wave = math.sin(t * 9 + st.Phase + j * 0.9) * 0.18 * j
				local d = (dir + Vector3.new(0, wave, 0) + back * wave * 0.4).Unit
				local q = p + d * 0.55
				seg.CFrame = CFrame.lookAt((p + q) / 2, q)
				p = q
			end
		end
		-- Cape: from his shoulders, out to the side and behind, rippling.
		local base = torso and torso.CFrame or root.CFrame
		local p = (base * CFrame.new(0, torso and 0.6 or 1, 0.55)).Position
		for j, c in ipairs(cape) do
			local wave = math.sin(t * 7 - j * 0.8) * 0.35
			local d = (away * 0.75 + back * 0.55 + Vector3.new(0, -0.25 + wave * 0.6, 0)).Unit
			local q = p + d * 0.95
			local cf = CFrame.lookAt((p + q) / 2, q) * CFrame.Angles(0, 0, wave * 0.5)
			c.Outer.CFrame = cf
			c.Inner.CFrame = cf * CFrame.new(0, -0.04, 0)
			p = q
		end
		if t >= nextStreak then
			nextStreak = t + 0.04
			local start = root.Position - away * 14 + Vector3.new((math.random() - 0.5) * 4, (math.random() - 0.3) * 5, 0) + root.CFrame.LookVector * ((math.random() - 0.5) * 10)
			local len = 2 + math.random() * 3
			local streak = VFXLib.part({ Size = Vector3.new(0.06, 0.06, len), CFrame = CFrame.lookAt(start, start + away), Color = Color3.fromRGB(220, 255, 250), Transparency = 0.45 })
			VFXLib.animate(0.6, function(a)
				local q = start + away * (28 * a)
				streak.CFrame = CFrame.lookAt(q, q + away)
				streak.Transparency = 0.45 + 0.55 * math.abs(a - 0.5) * 2
			end, function()
				streak:Destroy()
			end)
			if math.random() < 0.35 then
				VFXLib.burst(root.Position - Vector3.new(0, 2.6, 0) - away * 2, { Count = 3, Color = Color3.fromRGB(200, 236, 230), Speed = 8, Direction = away, Spread = 30, Lifetime = 0.5 })
			end
		end
	end, function()
		holder:Destroy()
	end)
	return holder
end

-- The clip's colour, shot by shot: bright cyan-teal in the desert, deep
-- indigo under the brim, washed-out pale blue for the grin.
local GRADES = {
	Desert = { Tint = Color3.fromRGB(170, 255, 240), Saturation = 0.35, Contrast = 0.15, Brightness = 0.02 },
	Shadow = { Tint = Color3.fromRGB(120, 130, 225), Saturation = -0.2, Contrast = 0.2, Brightness = -0.12 },
	Pale = { Tint = Color3.fromRGB(214, 236, 255), Saturation = -0.35, Contrast = 0.05, Brightness = 0.16 },
}
local function grade()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SaintsEyesGrade"
	cc.TintColor = GRADES.Desert.Tint
	cc.Saturation = GRADES.Desert.Saturation
	cc.Contrast = GRADES.Desert.Contrast
	cc.Brightness = -0.5 -- (it fades in from dark, as the clip does)
	cc.Parent = game:GetService("Lighting")
	return cc
end

local function gradeTo(cc, name, time)
	local g = GRADES[name]
	if not cc or not cc.Parent or not g then
		return
	end
	local t0, s0, c0, b0 = cc.TintColor, cc.Saturation, cc.Contrast, cc.Brightness
	VFXLib.animate(time, function(a)
		if not cc.Parent then
			return
		end
		cc.TintColor = t0:Lerp(g.Tint, a)
		cc.Saturation = s0 + (g.Saturation - s0) * a
		cc.Contrast = c0 + (g.Contrast - c0) * a
		cc.Brightness = b0 + (g.Brightness - b0) * a
	end)
end

-- Three slanted panels with thick white borders slide in over the shot, as
-- in the clip: RIGHT (a pale face, green hair, a wide-open eye, purple
-- lips), then LEFT (cyan skin, a yellow-green slit eye), then MIDDLE (a big
-- black-ringed eye with lashes and cracked skin, a yellow curve at its top).
local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function eyeShape(parent, pos, size, rot, sclera, iris, pupil, opts)
	opts = opts or {}
	local INK = Color3.fromRGB(8, 10, 18)
	local white = frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = size, Rotation = rot or 0, BackgroundColor3 = sclera, ClipsDescendants = true })
	roundCorner(white)
	local outline = Instance.new("UIStroke")
	outline.Color = INK
	outline.Thickness = opts.Thick or 4
	outline.Parent = white
	local ir = frame(white, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(opts.LookX or 0.5, 0.5), Size = opts.Slit and UDim2.fromScale(0.42, 1.25) or UDim2.fromScale(opts.IrisW or 0.4, 1.1), BackgroundColor3 = iris })
	roundCorner(ir)
	local ring = Instance.new("UIStroke")
	ring.Color = INK
	ring.Thickness = 3
	ring.Parent = ir
	local pu = frame(ir, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = opts.Slit and UDim2.fromScale(0.12, 0.92) or UDim2.fromScale(0.36, 0.36), Rotation = opts.Slit and 18 or 0, BackgroundColor3 = pupil or INK })
	if not opts.Slit then
		roundCorner(pu)
		local glint = frame(ir, { Position = UDim2.fromScale(0.58, 0.16), Size = UDim2.fromScale(0.2, 0.2), BackgroundColor3 = Color3.new(1, 1, 1) })
		roundCorner(glint)
	end
	return white
end

local function mangaFlash(duration)
	local pg = localPlayer and localPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return nil
	end
	local INK = Color3.fromRGB(8, 10, 18)
	local gui = Instance.new("ScreenGui")
	gui.Name = "SaintsEyesPanels"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	local root = frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local SLANT = 11
	-- { centre X, width, background, slide from (-1 left, 1 right, 0 pop), appears at (s) }
	local defs = {
		{ X = 0.86, W = 0.32, Bg = Color3.fromRGB(196, 240, 232), From = 1, At = 0 },
		{ X = 0.11, W = 0.27, Bg = Color3.fromRGB(70, 232, 240), From = -1, At = 0.6 },
		{ X = 0.5, W = 0.44, Bg = Color3.fromRGB(150, 240, 246), From = 0, At = 1.05 },
	}
	local panels = {}
	for i, d in ipairs(defs) do
		local panel = frame(root, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(d.W, 1.6), Position = UDim2.fromScale(d.X, 0.5), Rotation = SLANT, BackgroundColor3 = d.Bg, ClipsDescendants = true, Visible = false })
		local border = Instance.new("UIStroke")
		border.Color = Color3.new(1, 1, 1)
		border.Thickness = 10
		border.Parent = panel
		-- Everything inside is drawn upright (undo the slant).
		local art = frame(panel, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.3, 0.75), Rotation = -SLANT, BackgroundTransparency = 1 })
		if i == 1 then
			-- A pale face: lime-green hair across the top, a wide-open eye,
			-- sweat drops, purple lips at the bottom.
			for k = 0, 6 do
				frame(art, { Position = UDim2.fromScale(0.15 + k * 0.11, -0.05), Size = UDim2.fromScale(0.09, 0.42 - (k % 3) * 0.06), Rotation = 14 + k * 2, BackgroundColor3 = k % 2 == 0 and Color3.fromRGB(170, 236, 60) or Color3.fromRGB(110, 200, 50) })
			end
			eyeShape(art, UDim2.fromScale(0.5, 0.42), UDim2.fromScale(0.62, 0.12), -4, Color3.fromRGB(250, 252, 255), Color3.fromRGB(90, 200, 230), INK, { IrisW = 0.3 })
			frame(art, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.012), BackgroundColor3 = INK, Rotation = -4 })
			for k = 0, 2 do
				local drop = frame(art, { Position = UDim2.fromScale(0.62 + k * 0.05, 0.62 + k * 0.04), Size = UDim2.fromOffset(6, 10), BackgroundColor3 = Color3.fromRGB(120, 180, 220) })
				roundCorner(drop)
			end
			local lips = frame(art, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.62, 0.9), Size = UDim2.fromScale(0.34, 0.09), BackgroundColor3 = Color3.fromRGB(130, 50, 150) })
			roundCorner(lips)
		elseif i == 2 then
			-- Cyan skin, a darker band of shadow, a yellow-green slit eye.
			frame(art, { Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(0.35, 1), BackgroundColor3 = Color3.fromRGB(40, 170, 200) })
			eyeShape(art, UDim2.fromScale(0.55, 0.62), UDim2.fromScale(0.62, 0.17), -18, Color3.fromRGB(200, 240, 50), Color3.fromRGB(190, 240, 40), INK, { Slit = true, Thick = 5 })
		else
			-- A big black-ringed eye with lashes, cracks in the skin round it,
			-- the yellow curve of something at the top left.
			local curve = frame(art, { Position = UDim2.fromScale(-0.05, -0.02), Size = UDim2.fromScale(0.3, 0.16), BackgroundColor3 = Color3.fromRGB(236, 220, 40) })
			roundCorner(curve)
			local ringFrame = frame(art, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromScale(0.62, 0.26), Rotation = -6, BackgroundColor3 = INK })
			roundCorner(ringFrame)
			eyeShape(art, UDim2.fromScale(0.5, 0.44), UDim2.fromScale(0.44, 0.17), -6, Color3.fromRGB(40, 150, 230), Color3.fromRGB(40, 160, 240), Color3.fromRGB(20, 60, 110), { IrisW = 0.5, Thick = 2 })
			for k = 0, 6 do
				frame(art, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.42 + k * 0.06, 0.33 - math.abs(k - 3) * 0.006), Size = UDim2.fromOffset(6, 26), Rotation = (k - 3) * 12 + 10, BackgroundColor3 = INK })
			end
			for k = 0, 3 do
				frame(art, { Position = UDim2.fromScale(0.2 + k * 0.12, 0.6 + (k % 2) * 0.05), Size = UDim2.fromScale(0.16, 0.006), Rotation = 20 + k * 25, BackgroundColor3 = Color3.fromRGB(30, 60, 80) })
			end
		end
		panels[i] = { Frame = panel, Def = d }
	end
	gui.Parent = pg
	duration = duration or 1.6
	VFXLib.animate(duration, function(a)
		local t = a * duration
		for _, e in ipairs(panels) do
			local d = e.Def
			if t >= d.At then
				e.Frame.Visible = true
				local k = VFXLib.easeOut(math.clamp((t - d.At) / 0.14, 0, 1))
				if d.From == 0 then
					-- The middle one pops in, a little big, and settles.
					local sc = 1 + (1 - k) * 0.25
					e.Frame.Size = UDim2.fromScale(d.W * sc, 1.6 * sc)
					e.Frame.Position = UDim2.fromScale(d.X, 0.5)
				else
					e.Frame.Position = UDim2.fromScale(d.X + d.From * (1 - k) * 0.5, 0.5)
				end
			end
		end
	end, function()
		gui:Destroy()
	end)
	return gui
end

-- The film look on top: depth of field (the subject sharp, the rest soft)
-- and bloom (so the glowing liquid and eyes really glow).
local function cinemaLayer()
	local lighting = game:GetService("Lighting")
	local dof = Instance.new("DepthOfFieldEffect")
	dof.Name = "SaintsEyesFocus"
	dof.FarIntensity = 0.55
	dof.NearIntensity = 0.35
	dof.FocusDistance = 10
	dof.InFocusRadius = 6
	dof.Parent = lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "SaintsEyesBloom"
	bloom.Intensity = 0.7
	bloom.Size = 24
	bloom.Threshold = 0.9
	bloom.Parent = lighting
	return dof, bloom
end

-- Anime emphasis lines: thin white streaks rushing in toward the centre
-- of the screen (the moment the eye locks on).
local function focusLines(duration)
	local pg = localPlayer and localPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SaintsEyesFocusLines"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 39
	local lines = {}
	for k = 1, 36 do
		local ang = k / 36 * math.pi * 2 + (math.random() - 0.5) * 0.08
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BackgroundTransparency = 1
		line.Rotation = math.deg(ang)
		line.Size = UDim2.fromScale(0.28 + math.random() * 0.12, 0.004 + math.random() * 0.004)
		line.Parent = gui
		lines[k] = { Frame = line, Ang = ang, R = 0.62 + math.random() * 0.1 }
	end
	gui.Parent = pg
	VFXLib.animate(duration, function(a)
		local fade = a < 0.15 and a / 0.15 or (1 - a) / 0.85
		for _, l in ipairs(lines) do
			-- Rushing inward, never reaching the middle.
			local r = l.R - 0.06 * a
			l.Frame.Position = UDim2.fromScale(0.5 + math.cos(l.Ang) * r * 0.75, 0.5 + math.sin(l.Ang) * r)
			l.Frame.BackgroundTransparency = 1 - 0.55 * math.clamp(fade, 0, 1)
		end
	end, function()
		gui:Destroy()
	end)
	return gui
end

-- A thin ring of light bursting out round the cheek eye as it locks on.
local function stareRing(character)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local s = head.Size.Y / 1.2
	local ring = VFXLib.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.01, 0.3, 0.3) * s, Color = Color3.fromRGB(200, 240, 255), Material = Enum.Material.Neon, Transparency = 0.2 })
	ring.Shape = Enum.PartType.Cylinder
	VFXLib.animate(0.35, function(a)
		if not head.Parent then
			return
		end
		local d = (0.3 + 0.9 * VFXLib.easeOut(a)) * s
		ring.Size = Vector3.new(0.01, d, d)
		ring.CFrame = head.CFrame * CFrame.new(0.23 * s, -0.1 * s, -head.Size.Z / 2 - 0.06 * s) * CFrame.Angles(0, math.pi / 2, 0)
		ring.Transparency = 0.2 + 0.8 * a
	end, function()
		ring:Destroy()
	end)
end

local lastEyesCutscene -- (not again within 20 s)
local function playEyesCutscene(character)
	local cc = TuskConfig.Cutscenes or {}
	if cc.Enabled == false or cc.GyroEyes == false or (lastEyesCutscene and os.clock() - lastEyesCutscene < 20) then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not root or not head or not hand then
		return
	end
	lastEyesCutscene = os.clock()
	TuskAnimation.play(character, "GyroEyesKneel")
	-- Shot lengths (seconds), measured from the clip.
	local T = { 0.4, 1.17, 1.56, 2.32, 2.35, 1.6, 1.35 }
	local starts, acc = {}, 0
	for i, d in ipairs(T) do
		starts[i] = acc
		acc = acc + d
	end
	local palm = palmEye(character, starts[3] + 0.2)
	local cheek, mouth, look, glow, gust, dof, bloom, cheekCtl
	local ended = false
	local up = Vector3.new(0, 1, 0)
	local s = head.Size.Y / 1.2
	local function headAt()
		return head.Parent and head.Position or root.Position + Vector3.new(0, 1.5, 0)
	end
	local function rel(x, y, z)
		return (root.CFrame * CFrame.new(x, y, z)).Position
	end
	local fwd = function()
		return root.CFrame.LookVector
	end
	local right = function()
		return root.CFrame.RightVector
	end
	local function onHead(x, y, z)
		return (head.CFrame * CFrame.new(x * s, y * s, z * s)).Position
	end
	local function alive()
		return root.Parent ~= nil and head.Parent ~= nil
	end
	-- A slow handheld drift (the From/To functions run every frame).
	local function hand(amount, fn)
		return function()
			local cf = fn()
			if not cf then
				return nil
			end
			local c = os.clock()
			return cf * CFrame.Angles(math.sin(c * 1.7) * amount, math.sin(c * 1.3 + 1) * amount, math.sin(c * 0.9 + 2) * amount * 0.5)
		end
	end
	local shots = {
		-- 1. Wide and high, in front: kneeling in the dunes.
		{ From = hand(0.004, function()
			return alive() and CFrame.lookAt(rel(1.2, 6.5, -11.5), rel(0, -1.4, 0)) or nil
		end), To = hand(0.004, function()
			return alive() and CFrame.lookAt(rel(1.1, 6.2, -11), rel(0, -1.4, 0)) or nil
		end), Time = T[1], FOV = { 50, 50 }, Linear = true },
		-- 2. His cupped palm, close, from in front and above.
		{ From = hand(0.0025, function()
			local p = GyroEyesVFX.palmSpot(character)
			return p and CFrame.lookAt(p + fwd() * 1.5 + up * 1.2 - right() * 0.35, p - up * 0.15) or nil
		end), To = hand(0.0025, function()
			local p = GyroEyesVFX.palmSpot(character)
			return p and CFrame.lookAt(p + fwd() * 1.4 + up * 1.15 - right() * 0.3, p - up * 0.15) or nil
		end), Time = T[2], FOV = { 30, 30 }, Linear = true },
		-- 3. Straight down on his bowed hat from in front.
		{ From = hand(0.003, function()
			return alive() and CFrame.lookAt(headAt() + fwd() * 2.6 + up * 5.4, headAt() + fwd() * 0.3) or nil
		end), To = hand(0.003, function()
			return alive() and CFrame.lookAt(headAt() + fwd() * 2.5 + up * 5.2, headAt() + fwd() * 0.3) or nil
		end), Time = T[3], FOV = { 42, 42 }, Linear = true },
		-- 4. Right on the goggles, tilting slowly down to the brim's edge.
		{ From = hand(0.0015, function()
			return alive() and CFrame.lookAt(onHead(0, 1.9, -2.0), onHead(0, 0.85, -0.7)) or nil
		end), To = hand(0.0015, function()
			return alive() and CFrame.lookAt(onHead(0, 1.5, -2.2), onHead(0, 0.0, -0.6)) or nil
		end), Time = T[4], FOV = { 26, 26 }, Linear = true },
		-- 5. Under the brim, darker: past his glowing eye down to the cheek.
		{ From = hand(0.0012, function()
			return alive() and CFrame.lookAt(onHead(0.05, 0.75, -2.3), onHead(0.05, 0.75, -0.4)) or nil
		end), To = hand(0.0012, function()
			return alive() and CFrame.lookAt(onHead(0.04, -0.1, -2.4), onHead(0.1, 0.12, 0)) or nil
		end), Time = T[5], FOV = { 24, 24 }, Linear = true },
		-- 6. Held there while the panels slide in.
		{ From = hand(0.001, function()
			return alive() and CFrame.lookAt(onHead(0.04, -0.1, -2.4), onHead(0.1, 0.12, 0)) or nil
		end), To = hand(0.001, function()
			return alive() and CFrame.lookAt(onHead(0.04, -0.11, -2.35), onHead(0.1, 0.11, 0)) or nil
		end), Time = T[6], FOV = { 24, 24 }, Linear = true },
		-- 7. The grin, from in front and a little below.
		{ From = hand(0.0015, function()
			return alive() and CFrame.lookAt(onHead(0.05, -0.32, -2.1), onHead(0.05, -0.02, 0)) or nil
		end), To = hand(0.0015, function()
			return alive() and CFrame.lookAt(onHead(0.05, -0.3, -2.0), onHead(0.05, -0.02, 0)) or nil
		end), Time = T[7], FOV = { 38, 38 }, Linear = true },
	}
	local function cleanup()
		ended = true
		-- (Each one separately: any of them may already be gone.)
		local things = { palm, cheek, mouth, look, glow, gust, dof, bloom }
		for k = 1, 8 do
			local thing = things[k]
			if thing and thing.Parent then
				thing:Destroy()
			end
		end
		palm, cheek, mouth, look, glow, gust, dof, bloom = nil, nil, nil, nil, nil, nil, nil, nil
	end
	look = grade()
	dof, bloom = cinemaLayer()
	local started = Cutscenes.play(shots, { Priority = 3, Skippable = true, OnEnd = cleanup })
	if not started then
		cleanup()
		return
	end
	-- Focus and glow follow each shot's subject.
	local t0 = os.clock()
	VFXLib.animate(acc + 0.5, function()
		if ended or not dof or not dof.Parent then
			return
		end
		local now = os.clock() - t0
		local shot = 1
		for k = #starts, 1, -1 do
			if now >= starts[k] then
				shot = k
				break
			end
		end
		local subject
		if shot == 2 then
			subject = GyroEyesVFX.palmSpot(character)
		elseif shot == 1 then
			subject = root.Parent and root.Position
		elseif shot >= 5 then
			subject = head.Parent and onHead(0.15, -0.05, -0.5)
		else
			subject = head.Parent and onHead(0, 0.7, -0.6)
		end
		local cam = workspace.CurrentCamera
		if subject and cam then
			dof.FocusDistance = (cam.CFrame.Position - subject).Magnitude
		end
		dof.InFocusRadius = shot == 1 and 6 or (shot == 3 and 2 or 0.8)
		dof.FarIntensity = shot == 1 and 0.25 or 0.6
		local wantBloom = (shot == 2 and 1.3) or ((shot == 5 or shot == 6) and 1.6) or (shot == 7 and 1.0) or 0.7
		bloom.Intensity = bloom.Intensity + (wantBloom - bloom.Intensity) * 0.15
		bloom.Threshold = (shot == 5 or shot == 6) and 0.72 or 0.88
	end)
	gradeTo(look, "Desert", 0.25)
	VFXLib.sound(sounds.AwakeningBuild, root, 0.45, 0.8)
	gust = wind(character, starts[4])
	local function at(time, fn)
		task.delay(time, function()
			if not ended then
				fn()
			end
		end)
	end
	-- The liquid's gone into him by the time we're on his hat.
	at(starts[3] + 0.2, function()
		if palm then
			palm:Destroy()
			palm = nil
		end
	end)
	-- The eye takes its place in his cheek while the hat hides his face.
	at(starts[4], function()
		cheek, cheekCtl = cheekEye(character)
	end)
	-- THE STARE: as the camera reaches it, the eye rolls down out of his
	-- head and locks onto you; the pupil shrinks to a point.
	at(starts[5] + T[5] * 0.72, function()
		if cheekCtl then
			cheekCtl.lockOn()
		end
		stareRing(character)
		focusLines(0.9)
		if bloom then
			bloom.Intensity = 2.6
		end
	end)
	-- As the brim's edge comes down, his eyes are glowing under it.
	at(starts[4] + T[4] * 0.6, function()
		glow = glowEyes(character)
	end)
	-- Under the brim: deep indigo.
	at(starts[5], function()
		gradeTo(look, "Shadow", 0.12)
	end)
	-- The panels slide in.
	at(starts[6], function()
		mangaFlash(T[6])
		VFXLib.sound(sounds.AwakeningBurst or sounds.Swing, root, 0.5, 1.2)
	end)
	-- The grin, washed out pale.
	at(starts[7], function()
		mouth = grinMouth(character)
		gradeTo(look, "Pale", 0.1)
	end)
end

local watchedAct -- your own act last frame (to see 5 -> 29)
local function watchMine()
	local c = localPlayer and localPlayer.Character
	local act = c and c:GetAttribute("TuskAct")
	if act == ACT and watchedAct == 5 then
		playEyesCutscene(c)
	end
	watchedAct = act
end
GyroEyesVFX.playEyesCutscene = playEyesCutscene

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
	watchMine()
	slow = slow + dt
	if slow > 0.2 then
		slow = 0
		stepReveals()
	end
end

-- (For previews and tests.)
GyroEyesVFX.Preview = { eyeBall = eyeBall, arcsOn = arcsOn, stepArcs = stepArcs }

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
