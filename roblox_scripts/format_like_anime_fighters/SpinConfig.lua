--[[
	SpinConfig  (ModuleScript)
	PUT IT IN: ReplicatedStorage

	Every tunable value for the Golden Spin / Steel Ball system.
	The server reads this for damage, timing and validation; the client reads
	it for the charge meter and visuals. Change numbers here, not in code.

	Future Spin-based characters can copy this table and pass their own
	config to SpinService.registerKit(...).
]]

local SpinConfig = {}

SpinConfig.Input = {
	ActionName = "SpinCharge",
	Keyboard = Enum.KeyCode.R,
	Gamepad = Enum.KeyCode.ButtonR2,
	MobileButtonTitle = "SPIN",
	MobileButtonPosition = UDim2.new(1, -175, 1, -175),
}

SpinConfig.Charge = {
	MaxHoldTime = 3.0, -- auto-release after holding this long
	WalkSpeedMultiplier = 0.5, -- movement slow while charging (counterplay)
	CancelCooldown = 0.75, -- cooldown if the charge is interrupted

	-- PERFECT SPIN: release between Start and Start + Duration (seconds of charge).
	PerfectWindowStart = 1.35,
	PerfectWindowDuration = 0.22,
	ServerTimingTolerance = 0.05, -- extra slack each side for network jitter

	-- Holding past the perfect window drops the throw back to this level,
	-- so the reward comes from timing, not from holding forever.
	OverchargeLevel = 2,
}

--[[
	Levels: ChargeTime = seconds of charge needed to reach the level.
	Level 3 can only be reached inside the Perfect window.
]]
SpinConfig.Levels = {
	{
		Name = "QUICK SPIN",
		ChargeTime = 0,
		Damage = 7,
		Speed = 120,
		Radius = 1.1,
		Range = 150,
		Knockback = 14,
		Stun = 0.2,
		Cooldown = 2.5,
		BallScale = 1.0,
		Rings = 1,
		TrailWidth = 0.6,
		ShockwaveRadius = 6,
		CameraShake = 0.15,
	},
	{
		Name = "POWER SPIN",
		ChargeTime = 0.6,
		Damage = 13,
		Speed = 135,
		Radius = 1.4,
		Range = 180,
		Knockback = 32,
		Stun = 0.4,
		Cooldown = 4.5,
		BallScale = 1.25,
		Rings = 2,
		TrailWidth = 1.0,
		ShockwaveRadius = 10,
		CameraShake = 0.3,
	},
	{
		Name = "PERFECT SPIN",
		ChargeTime = 1.35, -- keep equal to Charge.PerfectWindowStart
		Damage = 22,
		Speed = 165,
		Radius = 1.9,
		Range = 220,
		Knockback = 55,
		Stun = 0.65,
		Cooldown = 7,
		BallScale = 1.6,
		Rings = 3,
		TrailWidth = 1.6,
		ShockwaveRadius = 16,
		CameraShake = 0.6,
	},
}

SpinConfig.Projectile = {
	MaxActivePerPlayer = 4,
	-- Offset from HumanoidRootPart where the throw starts (right hand side).
	SpawnOffset = CFrame.new(1, 0.8, -1.5),
	MaxAimPitch = 0.75, -- clamp of the aim direction's Y component
}

SpinConfig.Colors = {
	-- Steel Ball (green, from the owner's reference art)
	Ball = Color3.fromRGB(66, 142, 30),
	BallDark = Color3.fromRGB(18, 56, 12),
	BallLight = Color3.fromRGB(196, 236, 92),
	-- Rotation lines drawn around the spinning ball (pink-white in the art)
	SpinLine = Color3.fromRGB(255, 205, 225),
	SpinGlow = Color3.fromRGB(170, 255, 120),
	-- Golden Spin energy (Perfect Spin, shockwaves)
	Gold = Color3.fromRGB(255, 196, 56),
	GoldLight = Color3.fromRGB(255, 238, 160),
	Orange = Color3.fromRGB(255, 130, 30),
	Perfect = Color3.fromRGB(255, 250, 210),
}

--[[
	Sounds: upload the files from /assets/audio (Creator Hub > Asset Manager >
	Import) and paste the ids here as "rbxassetid://123...". Empty = silent.
]]
SpinConfig.Sounds = {
	Charge = "", -- spin_charge.ogg (loop)
	LevelUp = "", -- spin_levelup.ogg
	Perfect = "", -- spin_perfect.ogg
	Release = "", -- spin_release.ogg
	Impact = "", -- spin_impact.ogg
}

SpinConfig.Debug = {
	SpawnTestDummies = true, -- only ever runs inside Roblox Studio
	DummyCount = 3,
	DummyRespawnTime = 3,
}

-- Returns level index (1..3) and whether it was a Perfect release.
function SpinConfig.getLevel(chargeTime, tolerance)
	tolerance = tolerance or 0
	local c = SpinConfig.Charge
	local windowStart = c.PerfectWindowStart - tolerance
	local windowEnd = c.PerfectWindowStart + c.PerfectWindowDuration + tolerance
	if chargeTime >= windowStart and chargeTime <= windowEnd then
		return 3, true
	elseif chargeTime > windowEnd then
		return c.OverchargeLevel, false
	elseif chargeTime >= SpinConfig.Levels[2].ChargeTime then
		return 2, false
	end
	return 1, false
end

return SpinConfig
