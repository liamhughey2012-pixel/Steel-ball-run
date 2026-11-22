--[[
	TuskConfig  (ReplicatedStorage.SpinShared.TuskConfig)

	Every tunable number for Tusk. The server uses it for damage, timing,
	ranges and validation; the client uses it for UI and visuals.
	Balance changes go here, never in ability code.
]]

local TuskConfig = {}

---------------------------------------------------------------------------
-- Controls (PC / controller). Mobile uses the on-screen HUD buttons.
---------------------------------------------------------------------------
TuskConfig.Keys = {
	M1 = { Keyboard = Enum.UserInputType.MouseButton1, Gamepad = Enum.KeyCode.ButtonR1 },
	Ability1 = { Keyboard = Enum.KeyCode.One, Gamepad = Enum.KeyCode.ButtonX },
	Ability2 = { Keyboard = Enum.KeyCode.Two, Gamepad = Enum.KeyCode.ButtonY },
	Ability3 = { Keyboard = Enum.KeyCode.Three, Gamepad = Enum.KeyCode.ButtonB },
	Ultimate = { Keyboard = Enum.KeyCode.G, Gamepad = Enum.KeyCode.DPadUp },
	Sneak = { Keyboard = Enum.KeyCode.C, Gamepad = Enum.KeyCode.ButtonL1 },
	ActMenu = { Keyboard = Enum.KeyCode.T, Gamepad = Enum.KeyCode.DPadDown },
}

---------------------------------------------------------------------------
-- Act selection / progression
---------------------------------------------------------------------------
TuskConfig.Progression = {
	-- "Menu":   any implemented Act can be picked from the Act menu (T).
	-- "Unlock": only Acts that IsUnlocked(player, act) approves.
	--           Point IsUnlocked at your existing unlock / quest system.
	Mode = "Menu",
	DefaultAct = 1,
	AutoEquip = true, -- players spawn as Tusk (set false if your game picks movesets elsewhere)
	ShowSelectionMenu = true,
	IsUnlocked = nil, -- function(player, actNumber) -> boolean
	SwitchCooldown = 3, -- seconds between Act switches
}

---------------------------------------------------------------------------
-- Ultimate meter (shared by every Act)
---------------------------------------------------------------------------
TuskConfig.Ultimate = {
	MaxMeter = 100,
	GainPerDamage = 1.6, -- meter gained per point of damage dealt with Tusk
	StudioStartFull = true, -- Studio only: start full so ultimates can be tested
}

---------------------------------------------------------------------------
-- Tusk Sneak (shared by every Act)
---------------------------------------------------------------------------
TuskConfig.Sneak = {
	WalkSpeedMultiplier = 0.45,
	MaxDuration = 8, -- auto-exit after this long
	Cooldown = 4, -- after leaving sneak
	CameraDrop = 1.4, -- studs the camera lowers
	Attack = { -- press M1 while sneaking
		Cooldown = 12,
		FailCooldown = 2, -- no valid target found
		Range = 35,
		ConeDegrees = 75, -- target must be within this cone in front
		BurrowTime = 0.7, -- time underground before emerging
		WarningTime = 0.45, -- the target sees a warning this long before emergence
		EmergeDistance = 3.5, -- studs behind the target
		MaxTargetDrift = 14, -- if the target ran further than this, the attack whiffs
		HitRadius = 7,
		Damage = 12,
		Stun = 0.6,
		Knockback = 18,
		Launch = 38, -- upward velocity
	},
}

---------------------------------------------------------------------------
-- ACT 1 — the beginning of Spin
---------------------------------------------------------------------------
TuskConfig.Act1 = {
	M1 = {
		Interval = 0.3, -- min time between hits
		ResetAfter = 1.1, -- combo resets after this long without hitting
		EndLag = 0.9, -- recovery after the 4th hit
		Windup = 0.11, -- hitbox delay after the swing starts
		HitboxSize = Vector3.new(5, 5, 5.5),
		HitboxForward = 3.2,
		MaxTargets = 3,
		Hits = {
			{ Name = "Tusk Jab", Damage = 3, Stun = 0.45, Knockback = 3 },
			{ Name = "Nail Strike", Damage = 3.5, Stun = 0.45, Knockback = 4 },
			{ Name = "Spinning Assist", Damage = 3, Stun = 0.45, Knockback = 5, Projectile = { Speed = 160, Radius = 0.9, Range = 22 } },
			{ Name = "Shock Finisher", Damage = 6, Stun = 0.5, Knockback = 42, Launch = 10, ShockwaveRadius = 7 },
		},
	},
	NailShot = {
		Cooldown = 4,
		Startup = 0.18,
		Damage = 8,
		Speed = 150,
		Radius = 0.7,
		Range = 160,
		Stun = 0.35,
		Knockback = 10,
	},
	NailBarrage = {
		Cooldown = 9,
		Startup = 0.15,
		Count = 5,
		Interval = 0.09,
		SpreadDegrees = 7,
		Damage = 3,
		Speed = 170,
		Radius = 0.6,
		Range = 140,
		Stun = 0.25,
		Knockback = 4,
	},
	SpinningNail = {
		Cooldown = 10,
		FullChargeAt = 1.2, -- seconds to full charge (golden-blue trail)
		MaxHold = 3, -- auto-release
		WalkSpeedMultiplier = 0.6,
		MinDamage = 8,
		MaxDamage = 19,
		MinSpeed = 120,
		MaxSpeed = 190,
		MinRadius = 0.8,
		MaxRadius = 1.6,
		Range = 200,
		Stun = 0.55,
		Knockback = 38,
	},
	Ultimate = { -- TUSK AWAKENING
		Windup = 1.7, -- cinematic buildup (armored, can't be stunned)
		Radius = 18,
		Damage = 15,
		Stun = 0.6,
		Knockback = 55,
		Launch = 25,
		Duration = 20, -- Awakened state length
		CooldownMultiplier = 0.6, -- ability cooldowns while Awakened
		DamageMultiplier = 1.25, -- nail damage while Awakened
	},
}

---------------------------------------------------------------------------
-- Sound ids. Upload assets/audio/tusk_*.ogg (Creator Hub > Asset Manager)
-- and paste "rbxassetid://..." here. Empty string = silent.
---------------------------------------------------------------------------
TuskConfig.Sounds = {
	Swing = "", -- tusk_swing.ogg
	Hit = "", -- tusk_hit.ogg
	Finisher = "", -- tusk_finisher.ogg
	NailFire = "", -- tusk_nail_fire.ogg
	NailImpact = "", -- tusk_nail_impact.ogg
	ChargeLoop = "", -- tusk_charge_loop.ogg
	ChargeFull = "", -- tusk_charge_full.ogg
	AwakeningBuild = "", -- tusk_awakening_build.ogg
	AwakeningBurst = "", -- tusk_awakening_burst.ogg
	SneakIn = "", -- tusk_sneak_in.ogg
	Burrow = "", -- tusk_burrow.ogg
	Warning = "", -- tusk_warning.ogg
	Emerge = "", -- tusk_emerge.ogg
}

---------------------------------------------------------------------------
-- Optional uploaded animations. Leave "" to use the built-in procedural
-- poses. Paste an id to have that move play your real animation instead.
---------------------------------------------------------------------------
TuskConfig.AnimationIds = {
	Idle = "", -- replaces the character's idle while Tusk is equipped
	Walk = "",
	Run = "",
	Sneak = "",
	M1_1 = "",
	M1_2 = "",
	M1_3 = "",
	M1_4 = "",
	NailShot = "",
	NailBarrage = "",
	SpinningNailCharge = "",
	SpinningNailRelease = "",
	Awakening = "",
	Burrow = "",
	Emerge = "",
}

TuskConfig.Colors = {
	Cyan = Color3.fromRGB(90, 230, 255),
	Blue = Color3.fromRGB(40, 120, 255),
	DeepBlue = Color3.fromRGB(20, 40, 160),
	Ice = Color3.fromRGB(210, 250, 255),
	Gold = Color3.fromRGB(255, 200, 70),
	GoldLight = Color3.fromRGB(255, 240, 170),
	Pink = Color3.fromRGB(236, 110, 196),
	PinkDark = Color3.fromRGB(170, 52, 132),
	Star = Color3.fromRGB(255, 196, 60),
	Heart = Color3.fromRGB(196, 40, 98),
	Metal = Color3.fromRGB(170, 175, 185),
}

return TuskConfig
