--[[
	SpinVFX  (StarterPlayerScripts.SpinClient.SpinVFX)

	Draws everything the Golden Spin does, for every player, on every client:
	  * Charge: Steel Ball spinning in the hand, golden rings that multiply
	    per level, rising particles, ground dust, perfect-window flash
	  * Release: muzzle shockwave, throw pose
	  * Projectile: spinning ball, tilted rotating rings, spiral + streak
	    trails, afterimages (High)
	  * Impact / Hit: layered shockwaves, sparks, dust, light, shake,
	    impact frame on Perfect, floating damage numbers for the attacker

	Visual only. The server decides every hit and every number.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local SpinConfig = require(Shared.SpinConfig)
local VFXQuality = require(Shared.VFXQuality)
local SteelBallModel = require(Shared.SteelBallModel)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)
local CameraFX = require(script.Parent.CameraFX)
local ProceduralPose = require(script.Parent.ProceduralPose)

local SpinVFX = {}

local localPlayer = Players.LocalPlayer
local colors = SpinConfig.Colors
local sounds = SpinConfig.Sounds

local chargeStates = {} -- [character] = state
local projectiles = {} -- [id] = visual
local ballPool = {}

---------------------------------------------------------------------------
-- Ball pool (projectile balls are reused instead of rebuilt every throw)
---------------------------------------------------------------------------
local function takeBall(scale)
	local ball = table.remove(ballPool)
	if not ball then
		ball = SteelBallModel.build(1, VFXQuality.get().Grooves)
		local core = ball.PrimaryPart
		core.Anchored = true
		-- Spiral trail: attachments rotate with the ball, so the ribbon twists.
		local trail = Instance.new("Trail")
		trail.Name = "SpiralTrail"
		trail.Attachment0 = core:FindFirstChild("TrailTop")
		trail.Attachment1 = core:FindFirstChild("TrailBottom")
		trail.Color = ColorSequence.new(colors.Gold, colors.Orange)
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.Lifetime = 0.18
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		trail.FaceCamera = false
		trail.Parent = core
	end
	ball:ScaleTo(scale)
	return ball
end

local function returnBall(ball)
	ball.Parent = nil
	if #ballPool < 8 then
		table.insert(ballPool, ball)
	else
		ball:Destroy()
	end
end

VFXQuality.Changed:Connect(function()
	for _, ball in ipairs(ballPool) do
		ball:Destroy()
	end
	ballPool = {}
end)

---------------------------------------------------------------------------
-- Charge visuals
---------------------------------------------------------------------------
local function createCharge(character)
	local hand, grip = ProceduralPose.getHand(character)
	if not hand then
		return nil
	end
	local quality = VFXQuality.get()
	local ball = SteelBallModel.build(1, quality.Grooves)
	local core = ball.PrimaryPart
	core.Anchored = false
	ball:PivotTo(hand.CFrame * grip)
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = core
	weld.C0 = grip
	weld.Parent = core
	ball.Parent = VFXLib.Folder

	local rings = {}
	for i = 1, 3 do
		rings[i] = VFXLib.ring({
			Radius = 0.75 + i * 0.28,
			Width = 0.1,
			Color = colors.Gold,
			Transparency = 1,
		})
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Sparkle
	emitter.Color = ColorSequence.new(colors.GoldLight, colors.Gold)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 6, 0)
	emitter.Rate = 0
	emitter.Parent = core:FindFirstChild("Center") or core

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = colors.Gold
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = character
	highlight.Parent = VFXLib.Folder

	ProceduralPose.play(character, "Charge", 0.18)

	return {
		Character = character,
		Ball = ball,
		Core = core,
		Weld = weld,
		Grip = grip,
		Rings = rings,
		Emitter = emitter,
		Highlight = highlight,
		Sound = VFXLib.sound(sounds.Charge, core, 0.45, 0.8, true),
		Angle = 0,
		Level = 0,
		InPerfect = false,
		NextDust = 0,
	}
end

local function destroyCharge(state, released)
	state.Ball:Destroy()
	for _, ring in ipairs(state.Rings) do
		ring:Destroy()
	end
	state.Highlight:Destroy()
	if state.Sound then
		state.Sound:Destroy()
	end
	if not released then
		ProceduralPose.reset(state.Character, 0.25)
	end
end

local function updateCharge(state, startTime, dt, now)
	local chargeTime = workspace:GetServerTimeNow() - startTime
	local level, perfect = SpinConfig.getLevel(chargeTime)
	local quality = VFXQuality.get()
	local core = state.Core

	-- Ball spin speeds up with each level.
	state.Angle = state.Angle + dt * (10 + level * 7)
	state.Weld.C0 = state.Grip * CFrame.Angles(state.Angle, state.Angle * 0.35, 0)

	-- Rings: one per level, each on its own tilted, precessing axis.
	local center = core.Position
	for i, ring in ipairs(state.Rings) do
		if i <= level then
			local tilt = 0.5 + i * 0.7
			ring:SetCFrame(CFrame.new(center) * CFrame.Angles(tilt + now * 0.8 * i, now * (3 + i), tilt * 0.5))
			ring:SetTransparency(perfect and 0 or 0.25)
			ring:SetWidth(perfect and 0.18 or 0.1)
		else
			ring:SetTransparency(1)
		end
	end

	state.Emitter.Rate = (perfect and 60 or level * 14) * quality.Particles
	if state.Sound then
		state.Sound.PlaybackSpeed = 0.8 + math.min(chargeTime, 2) * 0.3
	end

	-- Level up pulse.
	if level > state.Level then
		if state.Level > 0 then
			VFXLib.shockwave(CFrame.new(center), { Radius = 3 + level, Width = 0.2, Duration = 0.3, Color = colors.Gold })
			VFXLib.burst(center, { Count = 10 * level, Color = colors.GoldLight, Speed = 10, Lifetime = 0.4, Size = NumberSequence.new(0.25, 0) })
			VFXLib.sound(sounds.LevelUp, core, 0.5, 0.9 + level * 0.15)
		end
	end
	state.Level = level

	-- Perfect window: bright outline flash + chime.
	if perfect and not state.InPerfect then
		state.Highlight.OutlineTransparency = 0
		VFXLib.burst(center, { Count = 24, Color = colors.Perfect, Speed = 16, Lifetime = 0.35 })
		VFXLib.flash(center, colors.GoldLight, 5, 14, 0.25)
		VFXLib.sound(sounds.Perfect, core, 0.7, 1)
	elseif not perfect and state.InPerfect then
		state.Highlight.OutlineTransparency = 1
	end
	state.InPerfect = perfect

	-- Ground dust swirl at Power level and above.
	if level >= 2 and now >= state.NextDust then
		state.NextDust = now + 0.3
		local root = state.Character:FindFirstChild("HumanoidRootPart")
		if root then
			VFXLib.shockwave(CFrame.new(root.Position - Vector3.new(0, 2.8, 0)), {
				StartRadius = 1.5,
				Radius = 5 + level,
				Width = 0.25,
				Duration = 0.5,
				Color = colors.Gold,
				Spin = 2,
			})
		end
	end
end

local function chargeLoop(dt)
	local now = os.clock()
	local seen = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local startTime = character and character:GetAttribute("SpinChargeStart")
		if startTime then
			seen[character] = true
			local state = chargeStates[character]
			if not state then
				state = createCharge(character)
				chargeStates[character] = state
			end
			if state then
				updateCharge(state, startTime, dt, now)
			end
		end
	end
	for character, state in pairs(chargeStates) do
		if not seen[character] then
			chargeStates[character] = nil
			destroyCharge(state, state.Released)
		end
	end
end

---------------------------------------------------------------------------
-- Release / projectile / impact
---------------------------------------------------------------------------
local function ringAxisAlong(position, direction)
	-- Ring axis (UpVector) along the travel direction.
	return CFrame.lookAt(position, position + direction) * CFrame.Angles(math.pi / 2, 0, 0)
end

local function onRelease(data)
	local character = data.Character
	local state = character and chargeStates[character]
	if state then
		state.Released = true
	end
	if character then
		ProceduralPose.play(character, "Throw", 0.06)
		task.delay(0.3, function()
			ProceduralPose.reset(character, 0.3)
		end)
	end

	local level = SpinConfig.Levels[data.Level]
	local axis = ringAxisAlong(data.Origin, data.Direction)
	VFXLib.shockwave(axis, { Radius = 2 + data.Level * 1.5, Width = 0.35, Duration = 0.3, Color = colors.Gold })
	VFXLib.burst(data.Origin, {
		Count = 12 * data.Level,
		Color = colors.Gold,
		Speed = 25,
		Spread = 25,
		Direction = data.Direction,
		Lifetime = 0.35,
	})
	VFXLib.sound(sounds.Release, data.Origin, 0.7, 1.15 - data.Level * 0.1)

	if data.Perfect then
		for i = 1, 3 do
			task.delay(i * 0.04, function()
				VFXLib.shockwave(axis * CFrame.new(0, -i * 1.2, 0), {
					Radius = 3 + i * 1.5,
					Width = 0.3,
					Duration = 0.35,
					Color = colors.Perfect,
				})
			end)
		end
		VFXLib.flash(data.Origin, colors.GoldLight, 8, 24, 0.35)
	end

	if character and character == localPlayer.Character then
		CameraFX.shake(level.CameraShake * 0.6, 0.25)
		if data.Perfect then
			CameraFX.speedLines(0.35, colors.GoldLight)
			CameraFX.fovPunch(10, 0.4)
		else
			CameraFX.fovPunch(3 + data.Level * 2, 0.3)
		end
	end
end

local function spawnProjectile(data)
	local visualData = data.Visual or {}
	local levelIndex = visualData.Level or 1
	local level = SpinConfig.Levels[levelIndex]
	local perfect = visualData.Perfect == true

	local ball = takeBall(level.BallScale)
	local core = ball.PrimaryPart
	local start = CFrame.lookAt(data.Origin, data.Origin + data.Direction)
	ball:PivotTo(start)
	ball.Parent = VFXLib.Folder
	local spiral = core:FindFirstChild("SpiralTrail")
	if spiral then
		spiral:Clear()
	end

	-- Flat golden streak trail on a carrier that doesn't spin.
	local carrier = VFXLib.anchor(start)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-level.TrailWidth / 2, 0, 0)
	a0.Parent = carrier
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(level.TrailWidth / 2, 0, 0)
	a1.Parent = carrier
	local streak = Instance.new("Trail")
	streak.Attachment0 = a0
	streak.Attachment1 = a1
	streak.Color = ColorSequence.new(perfect and colors.Perfect or colors.GoldLight, colors.Gold)
	streak.LightEmission = 1
	streak.LightInfluence = 0
	streak.Lifetime = 0.25 + levelIndex * 0.08
	streak.WidthScale = NumberSequence.new(1, 0)
	streak.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	streak.FaceCamera = true
	streak.Parent = carrier

	local rings = {}
	for i = 1, level.Rings do
		rings[i] = VFXLib.ring({
			Radius = level.BallScale * 0.7 + i * 0.25,
			Width = 0.12 + (perfect and 0.06 or 0),
			Color = perfect and colors.Perfect or colors.Gold,
		})
	end

	local visual = {
		Id = data.Id,
		Ball = ball,
		Core = core,
		Carrier = carrier,
		Streak = streak,
		Rings = rings,
		Origin = data.Origin,
		Direction = data.Direction,
		Speed = data.Speed,
		Range = data.Range,
		ServerTime = data.ServerTime,
		Level = levelIndex,
		Perfect = perfect,
		Spin = 0,
		NextGhost = 0,
		Expire = os.clock() + data.Range / data.Speed + 1.5,
	}
	projectiles[data.Id] = visual
end

local function removeProjectile(visual)
	projectiles[visual.Id] = nil
	returnBall(visual.Ball)
	for _, ring in ipairs(visual.Rings) do
		ring:Destroy()
	end
	visual.Streak.Enabled = false -- let the streak fade out on its own
	game:GetService("Debris"):AddItem(visual.Carrier, visual.Streak.Lifetime + 0.1)
end

local function projectileLoop(dt)
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for _, v in pairs(projectiles) do
		local distance = math.min(v.Speed * (serverNow - v.ServerTime), v.Range)
		local position = v.Origin + v.Direction * distance
		v.Spin = v.Spin + dt * (18 + v.Level * 6)
		local facing = CFrame.lookAt(position, position + v.Direction)
		v.Ball:PivotTo(facing * CFrame.Angles(-v.Spin, 0, v.Spin * 0.15))
		v.Carrier.CFrame = facing
		for i, ring in ipairs(v.Rings) do
			local tilt = 0.35 * i
			ring:SetCFrame(ringAxisAlong(position, v.Direction) * CFrame.Angles(tilt * math.sin(now * 6 + i), v.Spin * (0.4 + i * 0.2), tilt))
		end
		if now >= v.NextGhost then
			v.NextGhost = now + 0.05
			VFXLib.afterimage(v.Core.CFrame, SpinConfig.Levels[v.Level].BallScale, v.Perfect and colors.Perfect or colors.Gold)
		end
		if now > v.Expire then
			removeProjectile(v) -- safety: server end event never arrived
		end
	end
end

local function impact(position, normal, levelIndex, perfect, ownerIsLocal)
	local level = SpinConfig.Levels[levelIndex]
	local axis = CFrame.lookAt(position, position + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
	local color = perfect and colors.Perfect or colors.Gold

	for i = 1, levelIndex do
		task.delay((i - 1) * 0.05, function()
			VFXLib.shockwave(axis, {
				Radius = level.ShockwaveRadius * (1 - (i - 1) * 0.28),
				Width = 0.5 + levelIndex * 0.15,
				Duration = 0.4 + i * 0.05,
				Color = i == 1 and color or colors.Orange,
				Spin = 1.5 * i,
			})
		end)
	end
	if normal.Y > 0.5 then
		VFXLib.groundDisc(position, normal, { Radius = level.ShockwaveRadius * 0.6, Color = colors.Gold, Duration = 0.35 })
	end
	VFXLib.burst(position, { Count = 18 * levelIndex, Color = colors.GoldLight, Speed = 30, Lifetime = 0.5 })
	-- Metal sparks that fall with gravity.
	VFXLib.burst(position, {
		Count = 14 * levelIndex,
		Color = colors.Orange,
		Speed = 45,
		Lifetime = 0.6,
		Drag = 1,
		Acceleration = Vector3.new(0, -70, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) }),
		Direction = normal,
		Spread = 70,
	})
	-- Desert dust.
	VFXLib.burst(position, {
		Count = 6 * levelIndex,
		Texture = VFXLib.Textures.Smoke,
		Color = Color3.fromRGB(196, 168, 120),
		LightEmission = 0,
		Speed = 8,
		Lifetime = 1.1,
		Drag = 3,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) }),
		TransparencySeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
	})
	VFXLib.flash(position, colors.Gold, 3 + levelIndex * 2, 12 + levelIndex * 6, 0.35)
	VFXLib.sound(sounds.Impact, position, 0.6 + levelIndex * 0.15, 1.1 - levelIndex * 0.1)
	CameraFX.shakeAt(position, level.CameraShake * 2, 60 + levelIndex * 20)
	if perfect and ownerIsLocal then
		CameraFX.impactFrame(colors.GoldLight)
	end
end

local function endProjectile(data)
	local visual = projectiles[data.Id]
	local levelIndex = (data.Visual and data.Visual.Level) or (visual and visual.Level) or 1
	local perfect = data.Visual and data.Visual.Perfect == true
	if visual then
		visual.Ball:PivotTo(CFrame.new(data.Position))
		removeProjectile(visual)
	end
	-- Impact frame only for the thrower, and only when the ball hit someone.
	local ownerIsLocal = data.HitCharacter and data.OwnerId == localPlayer.UserId
	impact(data.Position, data.Normal, levelIndex, perfect, ownerIsLocal)
end

local function onHit(data)
	if not data.Victim then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Adornee = data.Victim
	highlight.FillColor = data.Blocked and Color3.fromRGB(140, 200, 255) or Color3.new(1, 1, 1)
	highlight.OutlineColor = data.Blocked and Color3.fromRGB(80, 160, 255) or colors.Gold
	highlight.FillTransparency = 0.3
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = VFXLib.Folder
	VFXLib.animate(0.18, function(a)
		highlight.FillTransparency = 0.3 + 0.7 * a
		highlight.OutlineTransparency = a
	end, function()
		highlight:Destroy()
	end)
	if data.Blocked then
		VFXLib.burst(data.Position, { Count = 12, Color = Color3.fromRGB(150, 210, 255), Speed = 25, Lifetime = 0.3 })
	end
	if localPlayer.Character and data.Victim == localPlayer.Character then
		CameraFX.shake(0.4 + (data.Level or 1) * 0.2, 0.3)
		if data.Perfect then
			CameraFX.impactFrame(colors.GoldLight)
		end
	end
end

-- Floating damage number, only for the attacker.
local function onDamage(data)
	local carrier = VFXLib.anchor(CFrame.new(data.Position + Vector3.new(math.random() - 0.5, 2, math.random() - 0.5)), 1.2)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 60)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = carrier
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = data.Blocked and ("BLOCKED " .. data.Amount) or (tostring(data.Amount) .. (data.Perfect and "!" or ""))
	label.TextColor3 = data.Blocked and Color3.fromRGB(170, 200, 230) or (data.Perfect and colors.Perfect or colors.Gold)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(60, 25, 0)
	label.Parent = billboard
	local start = carrier.Position
	VFXLib.animate(1, function(a)
		carrier.Position = start + Vector3.new(0, a * 3, 0)
		label.TextTransparency = math.max(0, (a - 0.6) / 0.4)
		label.TextStrokeTransparency = label.TextTransparency
		local pop = a < 0.1 and (1 + (0.1 - a) * 4) or 1
		billboard.Size = UDim2.fromOffset(160 * pop * (data.Perfect and 1.3 or 1), 60 * pop * (data.Perfect and 1.3 or 1))
	end)
end

function SpinVFX.init()
	local FX = Net.get("SpinFX")
	FX.OnClientEvent:Connect(function(name, data)
		if name == "SpinRelease" then
			onRelease(data)
		elseif name == "ProjectileSpawn" and data.Kind == "SteelBall" then
			spawnProjectile(data)
		elseif name == "ProjectileEnd" and data.Kind == "SteelBall" then
			endProjectile(data)
		elseif name == "Hit" then
			onHit(data)
		elseif name == "Damage" then
			onDamage(data)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		chargeLoop(dt)
		projectileLoop(dt)
	end)
end

return SpinVFX
