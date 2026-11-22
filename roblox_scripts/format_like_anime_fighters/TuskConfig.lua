--[[
	TuskConfig  (ModuleScript)
	PUT IT IN: ReplicatedStorage

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
	-- "Awaken": everyone starts at Act 1; each ULTIMATE awakens Tusk to the
	--           next Act (1 -> 2 -> 3 -> 4) with a new Stand and new moves.
	-- "Menu":   any implemented Act can be picked from the Act menu (T).
	-- "Unlock": only Acts that IsUnlocked(player, act) approves.
	--           Point IsUnlocked at your existing unlock / quest system.
	Mode = "Awaken",
	ResetOnDeath = true, -- Awaken mode: dying sends you back to Act 1
	StudioMenu = true, -- the Act menu (T) still works inside Studio for testing
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
	GainPerDamage = 0.9, -- meter gained per point of damage dealt with Tusk
	-- Higher Acts fill the meter slower, so Act 4 takes real effort:
	-- Act 1 ~110 damage, Act 2 ~160, Act 3 ~220 to awaken the next Act.
	GainByAct = { 1, 0.7, 0.5, 0.45 },
	-- After awakening, the ultimate stays locked this long (seconds),
	-- so you can't chain straight from Act 1 to Act 4.
	MinSecondsPerAct = 45,
	-- Studio testing helpers (OFF by default; turn on to test every Act quickly):
	StudioStartFull = false, -- start with a full meter
	StudioRefill = false, -- refill after each ultimate
}

---------------------------------------------------------------------------
-- Stand models from the Roblox Creator Store / your inventory.
-- AssetId = 0 keeps the built-in procedural Stand for that Act.
-- Height = how tall the Stand is in studs. Rotation fixes a model that
-- faces the wrong way (degrees, e.g. Vector3.new(0, 180, 0)).
-- Any Scripts inside a loaded model are removed for safety.
---------------------------------------------------------------------------
TuskConfig.StandModels = {
	[1] = {
		AssetId = 0, -- set 8768080824 to use the "Tusk1" store model instead
		Style = "Classic", -- built-in look: "Classic" (pink star creature from the drawings) or "Mascot" (small blue/cyan toy-like humanoid)
		Height = 3.2,
		Rotation = Vector3.new(0, 0, 0),
	},
	[2] = { AssetId = 0, Height = 3.6, Rotation = Vector3.new(0, 0, 0) },
	[3] = { AssetId = 0, Height = 4.6, Rotation = Vector3.new(0, 0, 0) },
	[4] = { AssetId = 0, Height = 6, Rotation = Vector3.new(0, 0, 0) },
}

---------------------------------------------------------------------------
-- Character roster (shown in the top-left dropdown)
-- Available = false shows the character as IN DEVELOPMENT (not selectable).
---------------------------------------------------------------------------
TuskConfig.Roster = {
	{ Id = "Johnny", Name = "JOHNNY JOESTAR", Stand = "TUSK (ACT 1-4)", Available = true, Color = Color3.fromRGB(90, 230, 255) },
	{ Id = "Gyro", Name = "GYRO ZEPPELI", Stand = "STEEL BALLS", Available = false, Color = Color3.fromRGB(110, 200, 80), Note = "Golden Spin (R) already works for everyone" },
}

---------------------------------------------------------------------------
-- Character card (top-left)
---------------------------------------------------------------------------
TuskConfig.Character = {
	Name = "JOHNNY JOESTAR",
	Title = "STAND USER",
	-- Optional: upload a portrait image and paste "rbxassetid://..." here.
	-- Empty = a live 3D view of your own avatar.
	PortraitImage = "",
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
	Ultimate = { -- TUSK AWAKENING -> evolves to Act 2
		Windup = 1.7, -- cinematic buildup (armored, can't be stunned)
		Radius = 18,
		Damage = 15,
		Stun = 0.6,
		Knockback = 55,
		Launch = 25,
		Duration = 20, -- (Menu mode only) Awakened buff length
		CooldownMultiplier = 0.6,
		DamageMultiplier = 1.25,
	},
}

---------------------------------------------------------------------------
-- ACT 2 — wormhole combat
---------------------------------------------------------------------------
TuskConfig.Act2 = {
	M1 = {
		Interval = 0.28, ResetAfter = 1.1, EndLag = 0.85, Windup = 0.1,
		HitboxSize = Vector3.new(5.5, 5, 6), HitboxForward = 3.4, MaxTargets = 3,
		Hits = {
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.45, Knockback = 4, Portal = true },
			{ Damage = 3.5, Stun = 0.45, Knockback = 5 },
			{ Damage = 7, Stun = 0.5, Knockback = 45, Launch = 14, Portal = true, ShockwaveRadius = 8 },
		},
	},
	WormholeNail = { Cooldown = 6, Startup = 0.16, Damage = 8, ExitDamage = 7, Speed = 160, Radius = 0.75, Range = 170, ExitDelay = 0.4, ExitSearch = 12, Stun = 0.4, Knockback = 14 },
	UndergroundPursuit = { Cooldown = 11, Range = 45, ConeDegrees = 100, BurrowTime = 0.55, WarningTime = 0.35, Damage = 11, Stun = 0.55, Knockback = 20, Launch = 30, HitRadius = 7 },
	NailDimension = { Cooldown = 13, Range = 70, ConeDegrees = 50, Portals = 3, PortalRadius = 11, OpenTime = 0.4, Damage = 5, Speed = 140, Stun = 0.35, Knockback = 8, FinalRadius = 9, FinalDamage = 6 },
	Ultimate = { -- DIMENSIONAL STORM -> evolves to Act 3
		Windup = 1.5, Radius = 24, Portals = 6, Waves = 3, WaveInterval = 0.35,
		NailDamage = 3, NailSpeed = 150, BurstRadius = 22, BurstDamage = 14, Stun = 0.6, Knockback = 55, Launch = 25,
	},
}

---------------------------------------------------------------------------
-- ACT 3 — master of spatial movement
---------------------------------------------------------------------------
TuskConfig.Act3 = {
	M1 = {
		Interval = 0.24, ResetAfter = 1.0, EndLag = 0.8, Windup = 0.08,
		HitboxSize = Vector3.new(5.5, 5, 6), HitboxForward = 3.4, MaxTargets = 3,
		Hits = {
			{ Damage = 3.5, Stun = 0.42, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.42, Knockback = 3, Portal = true },
			{ Damage = 4, Stun = 0.42, Knockback = 4, Portal = true },
			{ Damage = 7.5, Stun = 0.5, Knockback = 30, Launch = 42, Portal = true, ShockwaveRadius = 9 },
		},
	},
	DimensionalStep = { Cooldown = 5, Distance = 28, IFrames = 0.25 },
	SpatialPursuit = { Cooldown = 12, Range = 75, ConeDegrees = 60, Portals = 4, PortalRadius = 12, OpenTime = 0.35, Stagger = 0.14, Damage = 4.5, Speed = 170, Stun = 0.35, Knockback = 8 },
	DimensionalBreak = { Cooldown = 14, Charge = 0.75, Length = 34, Width = 12, Damage = 16, Stun = 0.6, Knockback = 60, Launch = 18 },
	Ultimate = { -- INFINITE DIMENSION -> evolves to Act 4
		Windup = 1.9, Radius = 26, Portals = 8, Damage = 20, Stun = 0.65, Knockback = 65, Launch = 35,
	},
}

---------------------------------------------------------------------------
-- ACT 4 — Infinite Rotation (gold + deep blue)
---------------------------------------------------------------------------
TuskConfig.Act4 = {
	M1 = {
		Interval = 0.33, ResetAfter = 1.2, EndLag = 1.0, Windup = 0.13,
		HitboxSize = Vector3.new(6.5, 6, 7), HitboxForward = 3.8, MaxTargets = 3,
		Hits = {
			{ Damage = 5, Stun = 0.5, Knockback = 6 },
			{ Damage = 5, Stun = 0.5, Knockback = 6 },
			{ Damage = 2.5, Stun = 0.5, Knockback = 2, Repeat = 3, RepeatInterval = 0.08 },
			{ Damage = 10, Stun = 0.55, Knockback = 60, Launch = 22, ShockwaveRadius = 13, AoeRadius = 9 },
		},
	},
	GoldenSpinNail = { Cooldown = 7, Startup = 0.3, Damage = 16, Speed = 175, Radius = 1.4, Range = 210, Stun = 0.5, Knockback = 40, ImpactRadius = 6, ImpactDamage = 5 },
	InfiniteRotation = {
		Cooldown = 15, WalkSpeedMultiplier = 0.4, MaxHold = 3.5,
		Stages = { 0.6, 1.3, 2.0 }, -- seconds of charge for stage 1 / 2 / 3
		Damage = { 12, 20, 30 }, Radius = { 1.6, 2.4, 3.4 }, Speed = { 140, 150, 160 },
		ImpactRadius = { 6, 10, 16 }, ImpactDamage = { 4, 8, 12 }, Range = 220, Stun = 0.6, Knockback = 55,
	},
	GoldenPursuit = { Cooldown = 12, Distance = 32, Hits = 3, HitInterval = 0.13, HitDamage = 4, FinalDamage = 12, Stun = 0.5, Knockback = 65, Launch = 25, FinalRadius = 12 },
	Ultimate = { -- INFINITE ROTATION (Act 4 stays Act 4)
		Windup = 2.6, ProjectileRadius = 4, Speed = 95, Range = 180, Damage = 32,
		BlastRadius = 18, BlastDamage = 14, Stun = 0.8, Knockback = 80, Launch = 40,
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
