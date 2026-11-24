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
	Block = { Keyboard = Enum.KeyCode.F, Gamepad = Enum.KeyCode.ButtonL2 }, -- hold
	Dash = { Keyboard = Enum.KeyCode.Q, Gamepad = Enum.KeyCode.ButtonR2 },
	CorpseMove = { Keyboard = Enum.KeyCode.V, Gamepad = Enum.KeyCode.DPadRight }, -- needs a corpse part
	Horse = { Keyboard = Enum.KeyCode.M, Gamepad = Enum.KeyCode.DPadLeft }, -- call / send away your horse
	Gallop = { Keyboard = Enum.KeyCode.LeftShift, Gamepad = Enum.KeyCode.ButtonL3 }, -- (hold) gallop while racing
	RaceReturn = { Keyboard = Enum.KeyCode.H, Gamepad = Enum.KeyCode.DPadUp }, -- back to your last gate (racing)
}

---------------------------------------------------------------------------
-- Block and Dash (every character)
---------------------------------------------------------------------------
TuskConfig.Defense = {
	-- BLOCK (hold F): blocked hits do 35% damage, no stun, less knockback.
	BlockWalkSpeed = 0.45, -- walk speed multiplier while blocking
	FrontOnly = true, -- only hits from in front are blocked
	MaxMeter = 100, -- the guard bar
	MeterPerDamage = 4, -- guard lost per point of (unblocked) damage
	MeterRegen = 30, RegenDelay = 1.2, -- guard per second, after this long without a blocked hit
	GuardBreakStun = 1.0, GuardBreakLockout = 3, -- guard runs out: stunned, can't block for a bit
	-- PERFECT BLOCK: start blocking just before a hit lands.
	ParryWindow = 0.22, -- seconds
	ParryStun = 1.0, -- the attacker is stunned
	ParryRetry = 0.6, -- block spam doesn't count: needs this long since the last release
	-- DASH (Q): a quick burst in the direction you're moving (forward if standing still).
	DashCharges = 2, -- dashes stored up: chain them
	DashCooldown = 2.2, -- seconds for each charge to come back (one at a time)
	DashGap = 0.3, -- seconds between two dashes in a row
	DashSpeed = 80, DashTime = 0.21, -- about 17 studs
	DashIFrames = 0.22, -- can't be hit during the dash
	DashCancelM1 = true, -- a dash cancels the recovery after an M1 hit
	-- PERFECT DODGE: an attack that would have hit you lands while you dash.
	PerfectDodgeWindow = 0.22, -- seconds from the start of the dash
	PerfectDodgeRefund = true, -- gives the dash charge back
	PerfectDodgeUlt = 8, -- ultimate meter
	PerfectDodgeSlow = 0.5, PerfectDodgeSlowTime = 0.8, -- the attacker is slowed
	CounterTime = 1.5, CounterMultiplier = 1.4, -- your next hit within this long does +40%
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
	StudioMenu = false, -- true: the Act menu (T) works inside Studio for testing (off: awakening is the only way up)
	DefaultAct = 1,
	AutoEquip = true, -- players spawn as Tusk (set false if your game picks movesets elsewhere)
	ShowSelectionMenu = true,
	IsUnlocked = nil, -- function(player, actNumber) -> boolean
	SwitchCooldown = 3, -- seconds between Act switches
}

---------------------------------------------------------------------------
-- AWAKENING (G on Tusk Acts 1-3): INFINITE ROTATION. A golden spinning nail
-- (stronger each Act) that blasts where it lands; then Tusk awakens one Act
-- higher. One value per Act 1, 2, 3. (Act 4's G is the full Infinite Rotation.)
---------------------------------------------------------------------------
TuskConfig.Awakening = {
	Windup = { 1.4, 1.6, 1.8 },
	Damage = { 14, 19, 24 },
	ProjectileRadius = { 2, 2.6, 3.2 },
	BlastRadius = { 10, 13, 16 },
	BlastDamage = { 6, 8, 11 },
	Speed = 110, Range = 180,
	Stun = 0.7, Knockback = 55, Launch = 25,
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
-- Blocky (classic Roblox) look for the Tusk Stands and the Scary Monsters
-- raptor: boxes instead of rounded shapes. false = smooth rounded models.
TuskConfig.BlockyModels = true

TuskConfig.StandModels = {
	[1] = {
		AssetId = 0, -- set 8768080824 to use the "Tusk1" store model instead
		Style = "Model", -- built-in look: "Model" (smooth lilac Tusk from the owner's Studio screenshots), "Classic" (pink star creature from the drawings) or "Mascot" (small blue/cyan toy-like humanoid)
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
	{ Id = "Johnny", Name = "JOHNNY JOESTAR", Stand = "TUSK", Available = true, Color = Color3.fromRGB(90, 230, 255) },
	{ Id = "Gyro", Name = "GYRO ZEPPELI", Stand = "BALL BREAKER", Available = true, Color = Color3.fromRGB(110, 210, 90) },
	{ Id = "Diego", Name = "DIEGO BRANDO", Stand = "SCARY MONSTERS", Available = true, Color = Color3.fromRGB(80, 210, 220) },
	{ Id = "PorkPie", Name = "PORK PIE HAT KID", Stand = "WIRED", Available = true, Color = Color3.fromRGB(165, 215, 80) },
	{ Id = "Sandman", Name = "SANDMAN", Stand = "IN A SILENT WAY", Available = true, Color = Color3.fromRGB(245, 185, 80) },
	{ Id = "MountainTim", Name = "MOUNTAIN TIM", Stand = "OH! LONESOME ME", Available = true, Color = Color3.fromRGB(214, 156, 84) },
	{ Id = "HotPants", Name = "HOT PANTS", Stand = "CREAM STARTER", Available = true, Color = Color3.fromRGB(242, 140, 172) },
	{ Id = "Blackmore", Name = "BLACKMORE", Stand = "CATCH THE RAINBOW", Available = true, Color = Color3.fromRGB(110, 180, 255) },
	{ Id = "Axl", Name = "AXL RO", Stand = "CIVIL WAR", Available = true, Color = Color3.fromRGB(214, 60, 70) },
	{ Id = "Valentine", Name = "FUNNY VALENTINE", Stand = "D4C", Available = true, Color = Color3.fromRGB(120, 170, 255) },
	{ Id = "DiegoAU", Name = "DIEGO BRANDO (AU)", Stand = "THE WORLD", Available = true, Color = Color3.fromRGB(236, 196, 70) },
	{ Id = "Josuke", Name = "JOSUKE HIGASHIKATA (8)", Stand = "SOFT & WET", Available = true, Color = Color3.fromRGB(120, 190, 240) },
	{ Id = "Tooru", Name = "TOORU", Stand = "WONDER OF U", Available = true, Color = Color3.fromRGB(150, 70, 190) },
	{ Id = "JohnRod", Name = "JOHN ROD", Stand = "JOHN ROD", Available = true, Color = Color3.fromRGB(200, 215, 235) },
	{ Id = "Jodio", Name = "JODIO JOESTAR", Stand = "NOVEMBER RAIN", Available = true, Color = Color3.fromRGB(90, 170, 240) },
}

---------------------------------------------------------------------------
-- Bounty board (by the spawn): pick a wanted poster, hunt that player or
-- Stand-user NPC down, get paid in Cash.
---------------------------------------------------------------------------
TuskConfig.Bounty = {
	Enabled = true,
	BoardOffset = Vector3.new(-20, 0, 140), -- from the map origin (the spawn is at 0, 0, 150)
	BoardFacing = Vector3.new(1, 0, 0.5), -- which way the posters face (towards the spawn)
	BaseReward = 100, -- Cash for a player
	StreakReward = 50, -- + this per kill on their current streak
	NPCReward = 75, -- Cash for a Stand-user NPC
	KillCreditTime = 6, -- seconds: your hit must be this recent for the kill to count
	Duration = 300, -- seconds before an accepted bounty runs out
	MaxPosters = 12,
	StartingCash = 0,
	-- PUT A PRICE ON THEIR HEAD: pay to raise another player's bounty. Whoever
	-- takes them down next gets it (contract or not); it's gone when they die.
	PlaceAmount = 100, PlaceMax = 2000,
	-- JOBS: a few paid tasks on the board, the same for everyone, swapped for
	-- new ones every RefreshEvery seconds. Progress counts on its own (no
	-- need to accept); you're paid the moment one's done.
	Jobs = {
		Count = 3, RefreshEvery = 600,
		Types = {
			{ Id = "NPCKills", Text = "Take down %d Stand-user NPCs", Goal = { 2, 4 }, PayEach = 60 },
			{ Id = "PlayerKills", Text = "Defeat %d players", One = "Defeat a player", Goal = { 1, 3 }, PayEach = 90 },
			{ Id = "Damage", Text = "Deal %d damage", Goal = { 300, 600 }, PayEach = 0.35 },
			{ Id = "PerfectBlocks", Text = "Land %d perfect blocks", Goal = { 2, 4 }, PayEach = 50 },
			{ Id = "PerfectDodges", Text = "Perfect-dodge %d attacks (dash through them)", Goal = { 2, 4 }, PayEach = 50 },
			{ Id = "Bounties", Text = "Claim %d bounties", One = "Claim a bounty", Goal = { 1, 2 }, PayEach = 120 },
			{ Id = "Corpse", Text = "Take %d Saint's Corpse parts", One = "Take a Saint's Corpse part", Goal = { 1, 1 }, PayEach = 150 },
		},
	},
	-- SHOP: spend Cash. Effects last until they run out or you die.
	Shop = {
		{ Id = "Bandages", Name = "BANDAGES", Price = 60, Text = "Heal 40 health right now", Icon = "+", Heal = 40 },
		{ Id = "Tonic", Name = "SNAKE-OIL TONIC", Price = 90, Text = "+15% speed for 2 minutes", Icon = "~", Speed = 1.15, Time = 120 },
		{ Id = "Horseshoe", Name = "LUCKY HORSESHOE", Price = 120, Text = "+25% ultimate charge for 2 minutes", Icon = "U", UltGain = 1.25, Time = 120 },
		{ Id = "Compass", Name = "CORPSE COMPASS", Price = 100, Text = "Points you to the nearest Saint's Corpse part for 60 s", Icon = "N", Time = 60 },
		{ Id = "ClearName", Name = "CLEAR YOUR NAME", Price = 0, Text = "Wipe your kill streak and any price on your head", Icon = "X", BaseCost = 50, PerStreak = 50 },
	},
}

---------------------------------------------------------------------------
-- Stand-user NPCs that fight you (StandBots). They wait at a camp away from
-- the spawn, chase players who come close and use a real character's moves.
---------------------------------------------------------------------------
TuskConfig.StandBots = {
	Enabled = true,
	Count = 15, -- how many at once (each takes a free spot below)
	-- Every installed character gets an NPC: each new NPC is whichever of these
	-- has the fewest NPCs out right now (ties picked at random).
	Characters = { "Johnny", "Gyro", "Diego", "PorkPie", "Sandman", "MountainTim", "HotPants", "Blackmore", "Axl", "Valentine", "DiegoAU", "Josuke", "Tooru", "Jodio", "JohnRod" },
	CorpseSeekRange = 60, -- idle bots pick up corpse parts lying this close to their camp
	CorpseSeekDelay = 120, -- seconds after an NPC spawns before it goes looking for parts
	CorpseFreshTime = 90, -- a part that just appeared is left alone by NPCs this long (players get first go)
	CorpseSeekEvery = 15, -- seconds between an idle NPC's looks for a part...
	CorpseSeekChance = 0.3, -- ...and the chance it bothers each time
	CorpseMaxPerBot = 1, -- an NPC holding this many parts stops collecting
	CorpseMaxForBots = 3, -- NPCs together never hold more than this many parts
	CorpsePickupTime = 2.5, -- an NPC kneels by a part this long before it has it (grab it first!)
	CorpseMoveChance = 0.12, -- per think tick in a fight, if they hold a part and it's ready
	RainWalkChance = 0.05, -- Blackmore NPCs: chance per think tick to start a rain walk while it rains
	Health = 200,
	WalkSpeed = 15,
	-- Where they camp (offsets from the map's origin). NPC 1 always camps
	-- at the first spot, NPC 2 at the second, and so on: the same place every
	-- time they respawn. Every camp is at least 90 studs from every Saint's
	-- Corpse spot (TuskConfig.Corpse.Spots) and 35 from the race course, on
	-- open ground. Without the map they gather Distance studs from the spawn.
	Spots = {
		Vector3.new(280, 0, 180), -- north-east flats
		Vector3.new(-260, 0, 110), -- west, beyond the oasis road
		Vector3.new(-140, 0, -310), -- south-west of the race track
		Vector3.new(110, 0, 40), -- east of the race track
		Vector3.new(-30, 0, 280), -- north of the spawn
		Vector3.new(230, 0, -370), -- far south-east desert
		Vector3.new(-340, 0, -130), -- far west desert
		Vector3.new(260, 0, 380), -- north-east corner
		Vector3.new(-120, 0, -160), -- western desert
		Vector3.new(380, 0, -230), -- east edge
		Vector3.new(-300, 0, 380), -- north-west corner
		Vector3.new(-380, 0, 220), -- west edge
		Vector3.new(-190, 0, -380), -- far south-west
		Vector3.new(110, 0, 380), -- far north
		Vector3.new(380, 0, 290), -- north-east edge
	},
	Distance = 70, -- (no map) studs from the spawn to their camp
	Spacing = 14, -- (no map) studs between them at the camp
	AggroRange = 60, -- they chase players this close
	LeashRange = 120, -- and give up past this far from their camp
	AttackRange = 6, -- M1 range
	AbilityRange = 35, AbilityEvery = 2.5, -- seconds between abilities (roughly)
	BlockChance = 0.05, DashChance = 0.06, -- per think tick (0.15 s)
	RespawnTime = 10,
	StartDelay = 3,
	ThinkEvery = 0.15,
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
	-- SNEAK (C, every character): crouched and slow, but hard to notice.
	--   * NPCs don't notice you unless you're this close (or you just hit them)
	--   * other players see you fade out with distance; your name and health bar are hidden
	--   * bounty hunters' marker and distance read HIDDEN past HiddenFromBounty studs
	--   * attacking out of sneak: Johnny's Tusk burrows (Sneak Attack, below);
	--     everyone else AMBUSHES: the first hit within AmbushWindow does extra damage
	NoticeRange = 12,
	NoticeMemory = 3, -- seconds an NPC keeps tracking you after it last saw you
	AmbushMultiplier = 1.5, AmbushWindow = 1.0,
	FadeStart = 12, FadeEnd = 40, MaxFade = 0.85, -- how see-through you look to others (by distance)
	HiddenFromBounty = 30,
	WalkSpeedMultiplier = 0.45,
	MaxDuration = 15, -- auto-exit after this long
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
			{ Name = "Tusk Jab", Damage = 3.5, Stun = 0.45, Knockback = 3 },
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
-- GYRO ZEPPELI — Steel Ball moveset (a separate character, "Act" 5 internally)
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Diego Brando: SCARY MONSTERS (dinosaur Stand)
---------------------------------------------------------------------------
TuskConfig.Diego = {
	M1 = { -- CLAW COMBO: claw, claw, tail whip, bite
		Interval = 0.28, ResetAfter = 1.1, EndLag = 0.85, Windup = 0.09,
		HitboxSize = Vector3.new(5.5, 5, 5.5), HitboxForward = 3.2, MaxTargets = 3,
		Hits = {
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 4.5, Stun = 0.45, Knockback = 8 },
			{ Damage = 7, Stun = 0.5, Knockback = 40, Launch = 10, ShockwaveRadius = 7, AoeRadius = 6.5 },
		},
	},
	-- Same combo with bigger numbers while transformed (Scary Monsters).
	DinoM1 = {
		Interval = 0.24, ResetAfter = 1.1, EndLag = 0.75, Windup = 0.08,
		HitboxSize = Vector3.new(7, 6, 7), HitboxForward = 4, MaxTargets = 4,
		Hits = {
			{ Damage = 4.5, Stun = 0.45, Knockback = 4 },
			{ Damage = 4.5, Stun = 0.45, Knockback = 4 },
			{ Damage = 6, Stun = 0.5, Knockback = 14 },
			{ Damage = 9, Stun = 0.55, Knockback = 50, Launch = 14, ShockwaveRadius = 9, AoeRadius = 8 },
		},
	},
	RaptorPounce = {
		Cooldown = 7, Windup = 0.18, Distance = 32, LeapTime = 0.36, LeapHeight = 7,
		TargetCone = 70, -- leaps at the nearest enemy inside this cone
		Damage = 9, Stun = 0.6, Knockback = 14, HitRadius = 6.5,
	},
	DinoInfection = { -- the bite turns the victim into a dinosaur Diego commands
		Cooldown = 25, -- after a hit
		MissCooldown = 4, -- after a miss
		Windup = 0.2, Damage = 7, Stun = 0.5, Knockback = 6,
		HitboxSize = Vector3.new(5, 6, 6), HitboxForward = 3,
		SpreadTime = 0.8, -- scales spread over the victim before they turn
		ThrallTime = 10, -- seconds Diego commands the dinosaur
		ThrallSpeed = 1.3, -- dinosaur walk speed multiplier
		ThrallTick = 0.15, ThrallAggroRange = 14, ThrallBiteRange = 4.5, ThrallBiteInterval = 0.9,
		ThrallDamage = 5, -- bites on nearby enemies
		CommandDamage = 7, CommandRange = 60, CommandCone = 50, CommandTime = 4, -- press again: "sic 'em"
	},
	ScaryMonsters = { -- turn into a full raptor
		Cooldown = 14, -- starts when the transformation ends
		Duration = 8, Transform = 0.5,
		SpeedMultiplier = 1.35, -- walk speed while transformed
		PounceMultiplier = 1.3, -- Raptor Pounce damage while transformed
		KineticVision = 90, -- studs: moving enemies glow for Diego while transformed
	},
	Ultimate = { -- RAPTOR PACK: roar, then a pack of raptors charges out
		Windup = 1.2, RoarRadius = 16, RoarDamage = 3, RoarStun = 0.9,
		Count = 5, Spread = 14, -- raptors, degrees between them
		Speed = 48, Range = 75, Tick = 0.08, HitRadius = 5,
		Damage = 12, Stun = 0.5, Knockback = 35, Launch = 14,
		MaxHitsPerTarget = 2, -- one enemy can be bitten by at most this many raptors
	},
}

---------------------------------------------------------------------------
-- Pork Pie Hat Kid: WIRED (fish hooks on steel cables from his mouth)
---------------------------------------------------------------------------
TuskConfig.PorkPie = {
	M1 = { -- HOOK COMBO: slap, slap, hook lash from the mouth, flying kick
		Interval = 0.29, ResetAfter = 1.1, EndLag = 0.85, Windup = 0.09,
		HitboxSize = Vector3.new(5, 5, 6), HitboxForward = 3.4, MaxTargets = 3,
		Hits = {
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 4, Stun = 0.45, Knockback = 6 },
			{ Damage = 7, Stun = 0.5, Knockback = 42, Launch = 12, ShockwaveRadius = 7, AoeRadius = 6.5 },
		},
	},
	WiredHook = { -- a hook shoots out of his mouth; a hit snags the enemy and reels them in
		Cooldown = 7, Startup = 0.25,
		Speed = 120, Radius = 1.2, Range = 75,
		Damage = 7, Stun = 1.0,
		ReelTime = 0.6, ReelTick = 0.15, ReelStopDistance = 5, -- pulled in until this close
	},
	BaitPan = { -- a pan of water with a feather bait; hooks burst out at anyone who comes near
		Cooldown = 12, Startup = 0.3,
		Distance = 10, -- placed this far in front
		Duration = 10, -- how long the trap waits
		TriggerRadius = 7, CheckEvery = 0.15, MaxTargets = 2,
		Damage = 8, Stun = 1.0, Lift = 70, -- hooks hoist the victim high
		SlamAfter = 0.5, SlamDamage = 4, -- then yank them back down into the ground
	},
	DoubleHookLift = { -- both hooks: snag up to two enemies in front and hoist them like a horse
		Cooldown = 10, MissCooldown = 3, Windup = 0.3,
		Range = 22, Cone = 50, MaxTargets = 2,
		Damage = 6, Stun = 1.0, Lift = 75,
		SlamAfter = 0.55, SlamDamage = 7, SlamRadius = 6,
	},
	Ultimate = { -- WIRED WINCH: puddles all around, hooks erupt from every one, the winch reels everyone in, slam
		Windup = 1.0, Radius = 24, Puddles = 6, PuddleRadius = 14,
		SnagDamage = 6, SnagStun = 1.0, SnagLift = 55,
		ReelTime = 1.35, ReelTick = 0.15, TickDamage = 1.5, TickEvery = 0.3,
		SlamDamage = 16, SlamRadius = 10, SlamKnockback = 60, SlamLaunch = 30, SlamStun = 0.8,
	},
}

---------------------------------------------------------------------------
-- Sandman (Soundman): IN A SILENT WAY
---------------------------------------------------------------------------
TuskConfig.Sandman = {
	M1 = { -- SOUND CUT COMBO: chop, chop, spinning kick, a written sound that bursts
		Interval = 0.27, ResetAfter = 1.1, EndLag = 0.8, Windup = 0.08,
		HitboxSize = Vector3.new(5, 5, 6), HitboxForward = 3.4, MaxTargets = 3,
		Hits = {
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 4, Stun = 0.45, Knockback = 6 },
			{ Damage = 7, Stun = 0.5, Knockback = 42, Launch = 12, ShockwaveRadius = 7, AoeRadius = 6.5 },
		},
	},
	SoundSlash = { -- a written sound ("ZBAAK!") flies along the ground and cuts
		Cooldown = 6, Startup = 0.2,
		Speed = 95, Radius = 1.8, Range = 65,
		Damage = 9, Stun = 0.55, Knockback = 16,
	},
	SoundTrap = { -- plant a written explosion ("DOGOOON") on the ground; stepping on it sets it off
		Cooldown = 7, Startup = 0.25,
		Distance = 12, MaxTraps = 3, Lifetime = 15,
		TriggerRadius = 5, CheckEvery = 0.15,
		Radius = 8, Damage = 10, Stun = 0.6, Knockback = 30, Launch = 25,
		ChainBonus = 2, -- traps in the blast go off together: one hit, +2 damage each
	},
	SandRun = { -- sprint straight through enemies, leaving sand and sound behind
		Cooldown = 7, Windup = 0.12,
		Distance = 38, Width = 6,
		Damage = 7, Stun = 0.6, Knockback = 12,
	},
	Ultimate = { -- SILENT SYMPHONY: gathers sound, then rains written sounds down, last one explodes
		Windup = 1.0, Distance = 16, Radius = 13,
		Waves = 4, WaveEvery = 0.3, WaveDamage = 5, WaveStun = 0.6,
		FinalDamage = 14, FinalKnockback = 55, FinalLaunch = 30, FinalStun = 0.8,
	},
}

---------------------------------------------------------------------------
-- Mountain Tim: OH! LONESOME ME
---------------------------------------------------------------------------
TuskConfig.MountainTim = {
	M1 = { -- LASSO COMBO: jab, jab, rope whip, overhead rope slam
		Interval = 0.29, ResetAfter = 1.1, EndLag = 0.85, Windup = 0.09,
		HitboxSize = Vector3.new(5, 5, 6.5), HitboxForward = 3.6, MaxTargets = 3,
		Hits = {
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 4, Stun = 0.45, Knockback = 6 },
			{ Damage = 7, Stun = 0.5, Knockback = 40, Launch = 14, ShockwaveRadius = 7, AoeRadius = 6.5 },
		},
	},
	LassoSnare = { -- throw the lasso: a catch splits their body apart along the rope and drags them in
		Cooldown = 7, Startup = 0.28,
		Speed = 105, Radius = 1.6, Range = 60,
		Damage = 6, Stun = 1.0,
		ReelTime = 0.6, ReelTick = 0.15, ReelStopDistance = 5,
		SplitTime = 0.9, -- their body is split apart along the rope this long
		SplitSlow = 0.5, SlowTime = 1.6, -- and they move at half speed for a bit
	},
	SplitDodge = { -- burst into pieces on the rope: get attacked and you reform behind them with a counter, otherwise slide forward
		Cooldown = 8, Window = 0.6,
		CounterDamage = 9, CounterStun = 0.9, CounterKnockback = 24, CounterLaunch = 10,
		Distance = 30, Travel = 0.3, Width = 5, -- the slide if nobody attacks
		Damage = 6, Stun = 0.5, Knockback = 10,
	},
	SplitBarrage = { -- his arm splits along the rope and flies out punching; the last punch reels them in
		Cooldown = 8, Windup = 0.18,
		Range = 26, Width = 4.5, Hits = 5, HitEvery = 0.1,
		Damage = 2.5, Stun = 0.5, FinalDamage = 5, ReelTime = 0.45, ReelTick = 0.15,
	},
	Ultimate = { -- LONESOME ROUNDUP: ropes to everyone nearby, his pieces ride them in, then he yanks everyone together
		Windup = 0.9, Radius = 24, MaxTargets = 6,
		RideHits = 4, RideEvery = 0.18, RideDamage = 3, RideStun = 0.6,
		ReelTime = 0.8, ReelTick = 0.15,
		SplitTime = 1.4, -- everyone roped is split apart along their rope while his pieces ride in
		SlamDamage = 12, SlamRadius = 9, SlamKnockback = 55, SlamLaunch = 28, SlamStun = 0.8,
	},
}

---------------------------------------------------------------------------
-- Hot Pants: CREAM STARTER (flesh spray)
---------------------------------------------------------------------------
TuskConfig.HotPants = {
	M1 = { -- SPRAY COMBO: jab, kick, a spray burst, roundhouse
		Interval = 0.27, ResetAfter = 1.1, EndLag = 0.8, Windup = 0.08,
		HitboxSize = Vector3.new(5, 5, 6), HitboxForward = 3.4, MaxTargets = 3,
		Hits = {
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.45, Knockback = 4 },
			{ Damage = 4, Stun = 0.45, Knockback = 4 },
			{ Damage = 7, Stun = 0.5, Knockback = 42, Launch = 12, ShockwaveRadius = 7, AoeRadius = 6.5 },
		},
	},
	FleshSpray = { -- a cone of flesh: everyone in it is coated (slowed) and takes ticks of damage
		Cooldown = 7, Startup = 0.12, Duration = 0.6, Tick = 0.15,
		Range = 15, Cone = 55, MaxTargets = 5,
		Damage = 2, Stun = 0.35,
		CoatTime = 2.5, CoatSlow = 0.6,
	},
	FleshSeal = { -- flesh over their mouth and nose: they suffocate for a few seconds
		Cooldown = 12, MissCooldown = 3, Windup = 0.25,
		Range = 11, Cone = 50,
		Damage = 4, Stun = 0.6,
		SealTime = 3, SealTick = 0.5, SealDamage = 2, SealSlow = 0.75,
	},
	FleshMend = { -- spray her own wounds shut
		Cooldown = 16, Duration = 1.2, Ticks = 4, Heal = 18,
	},
	Ultimate = { -- FLESH STORM: a flesh cloud hardens into cocoons round everyone caught, crushes them, bursts
		Windup = 0.7, Distance = 12, Radius = 13,
		EncaseDamage = 5, EncaseStun = 1.0, EncaseTime = 1.6, CrushEvery = 0.4, CrushDamage = 2,
		BurstDamage = 12, BurstKnockback = 50, BurstLaunch = 25, BurstStun = 0.7,
	},
}

---------------------------------------------------------------------------
-- Blackmore: CATCH THE RAINBOW (frozen raindrops)
---------------------------------------------------------------------------
TuskConfig.Blackmore = {
	M1 = { -- RAINDROP COMBO: shard strikes, the finisher fans out hardened drops
		Interval = 0.28, ResetAfter = 1.1, EndLag = 0.8, Windup = 0.08,
		HitboxSize = Vector3.new(5, 5, 6.5), HitboxForward = 3.6, MaxTargets = 3,
		Hits = {
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 4, Stun = 0.45, Knockback = 5 },
			{ Damage = 7, Stun = 0.5, Knockback = 40, Launch = 10, ShockwaveRadius = 7, AoeRadius = 7 },
		},
	},
	RaindropBlades = { -- drops freeze in a fan, then fire as a volley
		Cooldown = 6, Startup = 0.3,
		Drops = 7, Spread = 34, -- degrees across the fan
		Speed = 140, Radius = 0.8, Range = 55,
		Damage = 3, Stun = 0.35, Knockback = 4, MaxHitsPerTarget = 3,
	},
	RaindropStep = { -- dash along a stair of frozen drops; the hanging drops cut anyone who walks through
		Cooldown = 7, Windup = 0.08, Distance = 28, Travel = 0.25,
		TrailTime = 3, TrailWidth = 4, TrailTick = 0.25, TrailDamage = 2, TrailStun = 0.3, TrailHitEvery = 0.5,
	},
	RaindropCage = { -- a dome of frozen drops round the nearest enemy: moving cuts them
		Cooldown = 11, MissCooldown = 3, Windup = 0.22,
		Range = 16, Cone = 60,
		Damage = 5, Stun = 0.6,
		CageTime = 2.5, Slow = 0.45, Tick = 0.3, MoveDamage = 2, MoveThreshold = 0.8,
	},
	RainWalk = { -- while it rains (or in his own storm): double-jump to step on frozen raindrops in mid-air
		FloatTime = 6, -- seconds he can stay up per float
		MaxSteps = 8, -- jump again in the air to step higher, this many times
		Cooldown = 3, -- after the float ends
	},
	Ultimate = { -- CATCH THE RAINBOW: a downpour round him; the rain slices everyone, he scatters from the first hit, then every drop fires inward
		Windup = 0.8, Radius = 18, Duration = 5, Tick = 0.5, TickDamage = 1.5, TickStun = 0.4,
		ScatterDistance = 8,
		BurstDamage = 12, BurstKnockback = 45, BurstLaunch = 20, BurstStun = 0.7,
	},
}

---------------------------------------------------------------------------
-- Axl RO: CIVIL WAR (guilt made real; water / rain washes it away)
---------------------------------------------------------------------------
TuskConfig.Axl = {
	M1 = { -- GUILT COMBO: Civil War's long arms strike with him
		Interval = 0.29, ResetAfter = 1.1, EndLag = 0.85, Windup = 0.09,
		HitboxSize = Vector3.new(5, 5, 6.5), HitboxForward = 3.6, MaxTargets = 3,
		Hits = {
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 4, Stun = 0.45, Knockback = 6 },
			{ Damage = 7, Stun = 0.5, Knockback = 40, Launch = 12, ShockwaveRadius = 7, AoeRadius = 6.5 },
		},
	},
	Guilt = { -- PASSIVE: every hit he lands marks the target with guilt; his moves feed on it
		Max = 5, FadeAfter = 8, -- stacks fade this long after the last one
	},
	GuiltSpecter = { -- ghosts rise from his shadow and hunt the nearest enemy, grabbing on contact
		Cooldown = 8, MissCooldown = 3, Windup = 0.25,
		Range = 45, -- picks the nearest enemy this close (any direction)
		Count = 1, GuiltPerExtra = 2, MaxCount = 3, -- +1 specter per 2 guilt on the target
		Speed = 24, Life = 3.2, GrabRadius = 3.5, Spread = 4,
		Damage = 5, Stun = 0.6, Knockback = 4, Launch = 8,
	},
	AbandonedJunk = { -- things they threw away fly at them and stick to their body
		Cooldown = 7, Startup = 0.3,
		Count = 6, Spread = 40,
		Speed = 110, Radius = 1.1, Range = 60,
		Damage = 2.5, Stun = 0.35, Knockback = 4, MaxHitsPerTarget = 3,
		StickTime = 4, SlowPerPiece = 0.1, -- each stuck piece slows them a bit more
	},
	GuiltMembrane = { -- their guilt wraps them in a membrane that shrinks and crushes; uses up their guilt
		Cooldown = 13, MissCooldown = 3, Windup = 0.3,
		Range = 16, Cone = 60,
		Damage = 4, Stun = 0.6,
		Time = 3, Tick = 0.5, TickDamage = 1, TickGrowth = 0.25, -- each squeeze hurts more
		Slow = 0.5, FinalDamage = 4,
		PerGuilt = 0.15, -- +15% squeeze damage per guilt used up
		FlattenStun = 1.2, FlattenLaunch = 16, -- at max guilt they're flattened
		RainMultiplier = 0.5, -- water washes guilt away: in the rain it lasts half as long
	},
	Ultimate = { -- CIVIL WAR: the junkyard rises; specters engulf everyone near; he breaks apart when hit
		Windup = 1.0, Radius = 20, Specters = 7,
		SpecterDamage = 4, SpecterStun = 0.8,
		Time = 3, Tick = 0.5, TickDamage = 1.5, Slow = 0.4,
		FinalDamage = 10, FinalKnockback = 45, FinalLaunch = 22, FinalStun = 0.7, -- the crush grows with their guilt
		ScatterDistance = 9, -- Civil War breaks apart and he reforms this far away
		GuiltAdded = 3, -- everyone caught is loaded with guilt; the crush uses it up
		RainMultiplier = 0.5,
	},
}

---------------------------------------------------------------------------
-- Funny Valentine: D4C (Dirty Deeds Done Dirt Cheap)
---------------------------------------------------------------------------
TuskConfig.Valentine = {
	M1 = { -- DIRTY DEEDS COMBO: D4C's chops with him; the 4th wraps them in a flag (a long stun, little knockback: follow up!)
		Interval = 0.28, ResetAfter = 1.1, EndLag = 0.85, Windup = 0.08,
		HitboxSize = Vector3.new(5, 5, 6), HitboxForward = 3.4, MaxTargets = 3,
		Hits = {
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 4, Stun = 0.45, Knockback = 5 },
			{ Damage = 6, Stun = 0.95, Knockback = 6, ShockwaveRadius = 6, AoeRadius = 6 },
		},
	},
	DimensionHop = { -- a flag sweeps over him; he steps out of another world behind the nearest enemy
		Cooldown = 7, Windup = 0.3, -- can't be hit while between worlds
		Range = 40, Cone = 80, -- finds an enemy in front this close
		Distance = 26, -- with nobody to hop to, he goes this far ahead
		Damage = 4, Stun = 0.6, Knockback = 4, StrikeRange = 7,
		SecondDamage = 4, SecondDelay = 0.18, SecondKnockback = 16, -- D4C follows up with a second chop
		ReturnWindow = 4, -- press again within this long to hop back through the flag he left
		FlagSlamRadius = 7, FlagSlamDamage = 6, FlagSlamStun = 0.6, -- hopping back slams the flag shut on whoever's near it
	},
	ParallelClone = { -- a Valentine from another world joins the fight for a while
		Cooldown = 12, Windup = 0.3,
		Duration = 7, Speed = 20, Range = 50,
		PunchRange = 4.5, PunchEvery = 0.75, MaxPunches = 6,
		Damage = 3.5, Stun = 0.45, Knockback = 4,
		SwapAt = 0.25, SwapHeal = 0.3, -- nearly beaten while it's out: they swap places and he's healed (once)
		ManualSwapIFrames = 0.25, -- press 2 again while it's out: trade places with it (once)
	},
	MengerSponge = { -- their other-world self appears beside them: they crumble into cubes
		Cooldown = 13, MissCooldown = 3, Windup = 0.3,
		Range = 18, Cone = 60,
		Damage = 4, Stun = 0.6,
		Time = 3, Tick = 0.4, TickDamage = 1, TickGrowth = 0.08, Slow = 0.55,
		FinalDamage = 6, FinalKnockback = 25, FinalStun = 0.7,
		DoubleOffset = 3.5, Leash = 10, -- they only crumble near their double: run from it to escape
		BurstRadius = 7, BurstDamage = 5, -- the burst hits enemies right next to them too
		SpreadRange = 12, SpreadTime = 1.6, SpreadTickDamage = 1.2, SpreadFinal = 4, -- ...and the cubes start crumbling the nearest other enemy
	},
	Ultimate = { -- D4C LOVE TRAIN: a wall of light; hits on him are cancelled and the misfortune lands on someone else
		Windup = 0.7, Duration = 6,
		RedirectRange = 30, RedirectShare = 0.8, RedirectMin = 3, RedirectEvery = 0.15,
		RedirectHeal = 2, -- each redirected hit heals him
		SpeedMultiplier = 1.2,
		PulseRadius = 14, PulseDamage = 8, PulseKnockback = 40, PulseStun = 0.6,
		PulsePerRedirect = 1.5, PulseBonusMax = 12, -- the end pulse grows with every hit it turned away
	},
}

---------------------------------------------------------------------------
-- Diego Brando from another world (AU): THE WORLD
---------------------------------------------------------------------------
TuskConfig.DiegoAU = {
	M1 = { -- MUDA COMBO: The World punches with him; the 4th hit is an uppercut that launches
		Interval = 0.27, ResetAfter = 1.1, EndLag = 0.85, Windup = 0.08,
		HitboxSize = Vector3.new(5, 5, 6), HitboxForward = 3.4, MaxTargets = 3,
		Hits = {
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 4, Stun = 0.45, Knockback = 5 },
			{ Damage = 7, Stun = 0.55, Knockback = 30, Launch = 26, ShockwaveRadius = 7, AoeRadius = 6.5 },
		},
	},
	StandGrab = { -- 1: The World grabs the nearest enemy in front, punches them while holding them up, then hurls them
		Cooldown = 9, MissCooldown = 3, Windup = 0.2,
		Range = 14, Cone = 70,
		GrabDamage = 3, HoldTime = 0.9, -- held up in front of Diego this long...
		HoldPunches = 3, PunchDamage = 2, -- ...while The World punches them this many times
		ThrowDamage = 7, Knockback = 80, Launch = 30, Stun = 1,
		SplashDelay = 0.4, SplashRadius = 7, SplashDamage = 5, -- whoever they're thrown into gets hit too
		WallCheck = 20, WallDamage = 5, WallStun = 0.8, -- thrown into a wall this close: WALL SLAM
	},
	StandBarrage = { -- 2: The World rushes ahead of him with a storm of punches, dragging them along
		Cooldown = 12, Windup = 0.15,
		Duration = 1.6, Tick = 0.1,
		Damage = 0.9, Stun = 0.35, Knockback = 0,
		HitboxSize = Vector3.new(6, 6, 7), HitboxForward = 4, MaxTargets = 4,
		Drag = 6, -- enemies caught in it are pulled back in front of it (they can't slip out)
		WalkMultiplier = 0.6, -- Diego can still walk while it punches (and it follows)
		FinalDamage = 6, FinalKnockback = 50, FinalLaunch = 12, FinalStun = 0.6,
		ShockwaveRadius = 8, ShockwaveDamage = 3, -- the last punch's shockwave hits everyone in front
	},
	KnifeThrow = { -- 3: three knives at once, fanned out; press again soon for a second volley
		Cooldown = 7, Windup = 0.18,
		Count = 3, Spread = 8, -- degrees between knives
		FollowUpWindow = 1.5, -- press again within this long for one more volley
		Speed = 150, Radius = 0.7, Range = 110,
		Damage = 4, Stun = 0.4, Knockback = 6,
		StoppedCount = 8, StoppedSpread = 7, StoppedCooldown = 2.5, -- KNIFE WALL while time is stopped
	},
	Ultimate = { -- THE WORLD: TIME STOP. Everyone else in the zone freezes; Diego moves freely
		Windup = 0.8,
		Duration = 6, -- seconds time stays stopped
		BotDuration = 4, -- shorter when an NPC Diego does it
		Range = 60, -- radius of the time-stop zone (shown as a dome); anyone inside freezes
		SpeedMultiplier = 1.2, -- Diego moves faster in stopped time
		ResetCooldowns = { "StandGrab", "KnifeThrow" }, -- ready the moment time stops
	},
	Revolver = { -- corpse move: a six-shooter
		Draw = 0.35, Shots = 6, Every = 0.14,
		Damage = 5, Stun = 0.3, Knockback = 4, Speed = 260, Range = 140,
		LastShotDamage = 9, -- the sixth round hits harder
	},
}

---------------------------------------------------------------------------
-- Josuke Higashikata (JoJolion): SOFT & WET
---------------------------------------------------------------------------
TuskConfig.Josuke = {
	M1 = { -- SOFT & WET COMBO
		Interval = 0.27, ResetAfter = 1.1, EndLag = 0.85, Windup = 0.08,
		HitboxSize = Vector3.new(5, 5, 6), HitboxForward = 3.4, MaxTargets = 3,
		Hits = {
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 4, Stun = 0.45, Knockback = 5 },
			{ Damage = 7, Stun = 0.5, Knockback = 40, Launch = 12, ShockwaveRadius = 7, AoeRadius = 6.5 },
		},
	},
	PlunderFriction = { -- 1: a bubble steals their friction: they slide about like on ice
		Cooldown = 8, Windup = 0.2,
		Speed = 75, Radius = 1.3, Range = 85,
		Damage = 5, Stun = 0.3, Knockback = 28, -- the pop shoves them, and they keep sliding
		Time = 3.5, -- seconds without friction
		Grip = 0.8, -- how quickly a frictionless body can change direction (lower = more slippery)
	},
	PlunderSight = { -- 2: a bubble steals their sight: their screen goes dark (NPCs lose you)
		Cooldown = 14, Windup = 0.2,
		Speed = 60, Radius = 1.3, Range = 70,
		Damage = 4, Stun = 0.3,
		Time = 3,
	},
	BubbleMines = { -- 3: bubbles drift out round him and float there; touch one and it pops
		Cooldown = 12, Windup = 0.25,
		Count = 6, Spread = 9, -- studs out from him
		Life = 8, Trigger = 3.5,
		Damage = 6, Stun = 0.6, Knockback = 20,
	},
	Ultimate = { -- GO BEYOND: a tiny bubble spinning infinitely: it can't be blocked
		Windup = 1.0,
		Speed = 55, Radius = 1.6, Range = 150,
		Damage = 30, Stun = 1.0, Knockback = 45, Launch = 15,
	},
	CorpseSilence = { Radius = 20, Time = 3.5, Damage = 5 }, -- corpse move PLUNDER: SOUND: no abilities for a while
}

---------------------------------------------------------------------------
-- Tooru (JoJolion): WONDER OF U. Whoever pursues him meets calamity.
---------------------------------------------------------------------------
TuskConfig.Tooru = {
	-- PASSIVE: CALAMITY. Anyone running at him (closing in fast) has
	-- something fall on them now and then. A shadow shows first: dodge it.
	Passive = {
		Range = 32, MinDistance = 6, -- they're this far away and closing in...
		ApproachSpeed = 11, -- ...faster than this (studs/s): running or dashing at him
		Every = 5, -- seconds between calamities on one pursuer
		Radius = 4.5, Damage = 3, Stun = 0.4, Knockback = 8,
	},
	M1 = { -- WONDER OF U COMBO: the old man's cane
		Interval = 0.28, ResetAfter = 1.1, EndLag = 0.85, Windup = 0.09,
		HitboxSize = Vector3.new(5, 5, 6.5), HitboxForward = 3.6, MaxTargets = 3,
		Hits = {
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 4, Stun = 0.45, Knockback = 5 },
			{ Damage = 7, Stun = 0.55, Knockback = 38, Launch = 10, ShockwaveRadius = 7, AoeRadius = 6.5 },
		},
		CursedBonus = { Every = 1.2, Damage = 3, Stun = 0.3 }, -- M1 hits on a cursed enemy bring something down on them too
	},
	Debris = { -- 1: three shadows in a row chase the nearest enemy; each locks and something falls
		Cooldown = 8, Windup = 0.15,
		Range = 70, Cone = 100, -- who it picks (else a spot ahead of him)
		Drops = 3, Gap = 0.45, -- one after another, this far apart
		Follow = 0.55, -- seconds each shadow follows them
		Lock = 0.4, -- then it stops where they are: get out!
		Radius = 6, Damage = 5, Stun = 0.5, Knockback = 6,
		LastDamage = 9, LastStun = 0.9, LastKnockback = 20, LastLaunch = 10, -- the last one is the big one
	},
	Curse = { -- 2: enemies in front are cursed: moving TOWARD him brings calamity
		Cooldown = 13, Windup = 0.25,
		Range = 45, Cone = 140, MaxTargets = 4,
		Time = 6, -- seconds the curse lasts
		Slow = 0.8, -- cursed enemies walk at 80% (misfortune weighs on them)
		ApproachSpeed = 5, -- studs/s toward him that counts as pursuing
		Every = 0.9, -- seconds between calamities on one target
		Damage = 4, Stun = 0.5, Knockback = 14,
	},
	Appear = { -- 3: Wonder of U appears beside them and sweeps their legs with its cane
		Cooldown = 10, Windup = 0.2,
		Range = 50, -- (line of sight)
		Delay = 0.45, -- from appearing to the swing
		Radius = 6, Damage = 8, Stun = 1.0, Knockback = 8, Launch = 6,
		SwapWindow = 2.5, -- press 3 again within this long: Tooru swaps places with the old man
		SwapIFrames = 0.35,
	},
	Ultimate = { -- THE FLOW OF CALAMITY: attacking or chasing him is calamity
		Windup = 0.7, Duration = 7,
		ReflectDamage = 6, ReflectStun = 0.8, ReflectEvery = 0.8, -- anyone whose attack would hit him is struck instead
		Range = 45, ApproachSpeed = 4, -- anyone this close moving toward him...
		Damage = 7, Stun = 0.6, Knockback = 16, Every = 1.2, -- ...gets debris dropped on them
		Storm = { Delay = 0.7, Radius = 6, Damage = 12, Stun = 1.0, Knockback = 30, Launch = 18 }, -- when it ends: a big one on every enemy in range
	},
	CorpseCalamity = { Radius = 24, Delay = 0.6, Damage = 8, Stun = 0.7, Knockback = 12 }, -- corpse move: debris on everyone round him
}

---------------------------------------------------------------------------
-- Jodio Joestar (The JOJOLands): NOVEMBER RAIN. Heavy, crushing rain.
---------------------------------------------------------------------------
TuskConfig.Jodio = {
	-- PASSIVE: SOAKED. His rain soaks whoever it hits for SoakTime seconds;
	-- his rain hits a soaked enemy SoakBonus times harder.
	SoakTime = 5, SoakBonus = 1.25,
	M1 = { -- NOVEMBER RAIN COMBO
		Interval = 0.27, ResetAfter = 1.1, EndLag = 0.85, Windup = 0.08,
		HitboxSize = Vector3.new(5, 5, 6), HitboxForward = 3.4, MaxTargets = 3,
		Hits = {
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 4, Stun = 0.45, Knockback = 5 },
			{ Damage = 7, Stun = 0.5, Knockback = 36, Launch = 10, ShockwaveRadius = 7, AoeRadius = 6.5 },
		},
	},
	HeavyRain = { -- 1: a storm cloud over them; the rain under it pins and pounds
		Cooldown = 11, Windup = 0.25,
		Range = 55, Cone = 100, -- who it's put over (else a spot ahead of him)
		Radius = 10, Time = 3, Tick = 0.3,
		Damage = 1.2, Stun = 0, -- per tick, to everyone under it (no stun: the pressure slows them instead)
		Pressure = 0.5, -- they walk at 50% under it (the rain presses them down)
	},
	RainBullets = { -- 2: a burst of heavy raindrops fired like bullets
		Cooldown = 7, Windup = 0.15,
		Count = 6, Gap = 0.07, Spread = 4, -- degrees
		Speed = 160, Radius = 0.9, Range = 90,
		Damage = 3, Stun = 0.25, Knockback = 3,
	},
	RainJet = { -- 3: November Rain blasts him forward on a jet of rain
		Cooldown = 9, Windup = 0.12,
		Distance = 30, Travel = 0.3, Width = 7,
		Damage = 6, Stun = 0.6, Knockback = 24,
	},
	Ultimate = { -- NOVEMBER RAIN: TORRENT: a huge storm that follows him, then crushes
		Windup = 0.8, Duration = 6, Radius = 35, Tick = 0.4,
		Damage = 2, Stun = 0, Pressure = 0.6,
		CrushDamage = 14, CrushStun = 1.2, CrushKnockback = 6, -- when it ends: everyone under it
	},
	CorpseRain = { Radius = 20, Delay = 0.5, Damage = 9, Stun = 0.8 }, -- corpse move: a crushing burst of rain round him
}

---------------------------------------------------------------------------
-- JOHN ROD: a bent metal rod in the outline of a man, steered from afar.
---------------------------------------------------------------------------
TuskConfig.JohnRod = {
	-- REMOTE CONTROL (ability 1): send John Rod off and steer it (WASD /
	-- thumbstick) while you stand still; your camera follows it. Its moves
	-- come from wherever it is. Press 1 again to bring it back.
	Pilot = {
		Range = 100, -- how far from you it can go (studs)
		Speed = 30, -- how fast it moves while you steer it
		MaxTime = 25, -- seconds before it comes back on its own
		Cooldown = 4, -- after it comes back
		HitBreaks = true, -- if YOU are hit while steering it, it snaps back (and you're stunned a moment)
		FeedbackStun = 0.6,
	},
	M1 = { -- ROD STRIKES: from John Rod, wherever it is
		Interval = 0.27, ResetAfter = 1.1, EndLag = 0.85,
		Reach = 5, Size = Vector3.new(6, 6, 7),
		Hits = {
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 4, Stun = 0.45, Knockback = 5 },
			{ Damage = 7, Stun = 0.55, Knockback = 36, Launch = 10 },
		},
	},
	Lash = { -- 2: the rod whips out straight ahead of John Rod
		Cooldown = 6, Windup = 0.15,
		Length = 16, Width = 4,
		Damage = 8, Stun = 0.6, Knockback = 22,
	},
	Snare = { -- 3: the rod wraps round the nearest enemy near John Rod: they can't move
		Cooldown = 11, Windup = 0.2,
		Range = 16, -- from John Rod
		Time = 1.6, Damage = 5, Stun = 0.3,
	},
	Ultimate = { -- OUTLINE CAGE: the rod bends into a cage round everyone near it, then squeezes
		Windup = 0.6, Radius = 14, Time = 3, Tick = 0.5,
		TickDamage = 2, Slow = 0.15,
		SqueezeDamage = 13, SqueezeStun = 1.1, SqueezeKnockback = 8,
	},
	-- NPCs can't steer: their John Rod flies at their target on its own.
	BotAuto = { Time = 5, StrikeRange = 6 },
	CorpseSnap = { Radius = 18, Damage = 8, Stun = 0.7 }, -- corpse move ROD SNAP: lashes everyone round John Rod
}

TuskConfig.Gyro = {
	M1 = {
		Interval = 0.3, ResetAfter = 1.1, EndLag = 0.9, Windup = 0.1,
		HitboxSize = Vector3.new(5, 5, 5.5), HitboxForward = 3.2, MaxTargets = 3,
		Hits = {
			{ Damage = 3.5, Stun = 0.45, Knockback = 3 },
			{ Damage = 3.5, Stun = 0.45, Knockback = 4 },
			{ Damage = 4, Stun = 0.45, Knockback = 5 },
			{ Damage = 7, Stun = 0.5, Knockback = 45, Launch = 12, ShockwaveRadius = 8, AoeRadius = 7 },
		},
	},
	SteelBallThrow = {
		Cooldown = 6, Startup = 0.22, Damage = 10, ReturnDamage = 4, Speed = 140, ReturnSpeed = 120, Radius = 1.1, Range = 120, Stun = 0.4, Knockback = 18,
		MaxBounces = 3, -- bounces off walls this many times before returning (0 = no bounces)
		BounceBonusDamage = 1.5, -- extra damage per bounce (bank shots hit harder)
	},
	SpinTornado = {
		Cooldown = 11, Startup = 0.28,
		Speed = 22, -- studs per second along the ground
		Duration = 2.2, -- how long the tornado travels
		Radius = 6.5, Tick = 0.2, -- pull / hit every Tick seconds
		TickDamage = 1.2, Pull = 16, Lift = 20, -- sucks enemies in and juggles them
		BurstDamage = 6, BurstKnockback = 45, BurstLaunch = 25,
	},
	SpinVibration = { Cooldown = 8, Windup = 0.2, Damage = 9, Stun = 0.9, Knockback = 10, Launch = 16, HitboxSize = Vector3.new(5, 6, 6), HitboxForward = 3 },
	Ultimate = { -- BALL BREAKER
		Windup = 1.8, Speed = 85, Radius = 3, Range = 170, Damage = 14,
		VortexRadius = 14, VortexTime = 2.4, PullStrength = 22, TickDamage = 1.5, TickInterval = 0.3,
		BurstDamage = 12, BurstKnockback = 70, Launch = 30, Stun = 0.7,
	},
}

---------------------------------------------------------------------------
-- Sound ids. Upload assets/audio/tusk_*.ogg (Creator Hub > Asset Manager)
-- and paste "rbxassetid://..." here. Empty string = silent.
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- SAINT'S CORPSE: parts lie around the map. Take one (E) for a boost that
-- lasts until you die (then it drops where you fell). Holding any part
-- unlocks your character's CORPSE MOVE (V). Holders are worth more on the
-- bounty board, the Heart and the Head most of all.
---------------------------------------------------------------------------
TuskConfig.Corpse = {
	Enabled = true,
	DropDespawn = 60, -- a dropped part nobody takes moves to a new spot after this long
	-- Each part exists once. Buff: Damage / Resist / Cooldown / UltGain (fractions),
	-- Speed (fraction), MaxHealth (points).
	Parts = {
		{ Id = "Heart", Name = "HEART", Buff = "MaxHealth", Amount = 25, Text = "+25 max HP" },
		{ Id = "Head", Name = "HEAD", Buff = "Damage", Amount = 0.12, Text = "+12% damage" },
		{ Id = "LeftArm", Name = "LEFT ARM", Buff = "Damage", Amount = 0.08, Text = "+8% damage" },
		{ Id = "RightArm", Name = "RIGHT ARM", Buff = "Damage", Amount = 0.08, Text = "+8% damage" },
		{ Id = "Spine", Name = "SPINE", Buff = "Resist", Amount = 0.1, Text = "-10% damage taken" },
		{ Id = "Eyes", Name = "EYES", Buff = "Cooldown", Amount = 0.12, Text = "abilities recharge 12% faster" },
		{ Id = "Ears", Name = "EARS", Buff = "UltGain", Amount = 0.25, Text = "+25% ultimate charge" },
		{ Id = "Legs", Name = "LEGS", Buff = "Speed", Amount = 0.12, Text = "+12% speed" },
	},
	-- Where parts can lie (offsets from the map's origin; snapped to the ground).
	Spots = {
		-- All on flat open ground: none on the mountain ring round the map, the
		-- mesas, Headquarters hill, the mine hill or in the river.
		Vector3.new(-150, 0, -30), Vector3.new(-230, 0, -210), Vector3.new(-190, 0, 245), Vector3.new(150, 0, 232),
		Vector3.new(300, 0, 20), Vector3.new(40, 0, -262), Vector3.new(150, 0, -290), Vector3.new(210, 0, -190),
		Vector3.new(310, 0, -110), Vector3.new(-330, 0, 0), Vector3.new(100, 0, -120), Vector3.new(-120, 0, 120),
	},
	-- Bounties: holders are worth more; these parts most of all.
	PartBounty = 40, -- each part adds this to their price
	BigParts = { Heart = 150, Head = 150 }, -- ...or this, for these
	-- RETRIEVE contracts on the bounty board: one per part. Paid when you take
	-- that part (from where it lies, or by taking down whoever holds it).
	RetrieveReward = 120,
	RetrieveRewards = { Heart = 200, Head = 200 },
	Move = { Cooldown = 20 }, -- the CORPSE MOVE (each character's own; see CorpseMoves)
	-- ALL 8 PARTS: the holder glows gold, everyone is told, and V becomes
	-- THE SAINT'S MIRACLE (one use): can't be hit, healed to full, pillars of
	-- light strike every enemy in range in waves, a final blast; then the
	-- corpse leaves them and every part scatters back across the desert.
	Miracle = {
		Windup = 1.5, Range = 70,
		Waves = 5, WaveEvery = 0.6, Damage = 12, Stun = 0.8,
		FinalRadius = 22, FinalDamage = 20, FinalKnockback = 60, FinalLaunch = 40,
	},
	CompleteBounty = 500, -- extra on the board for whoever holds all of it
	MoveNames = {
		Johnny = "GOLDEN SPIN NAIL", Gyro = "GOLDEN RECTANGLE", Diego = "DINOSAUR CRASH", PorkPie = "HOOK HARVEST",
		Sandman = "SOUND BARRIER", MountainTim = "LASSO CYCLONE", HotPants = "FLESH COCOON", Blackmore = "RAIN CURTAIN",
		Axl = "GUILT FLOOD", Valentine = "CORPSE BLESSING", DiegoAU = "REVOLVER", Josuke = "PLUNDER: SOUND", Tooru = "UNAVOIDABLE CALAMITY", Jodio = "HEAVY RAINFALL", JohnRod = "ROD SNAP",
		Miracle = "THE SAINT'S MIRACLE", -- with the complete corpse (any character)
	},
}

---------------------------------------------------------------------------
-- THE STEEL BALL RUN: a horse race round the map. Every Every seconds entry
-- opens for EntryTime seconds (JOIN button on screen, or the start gate);
-- then everyone who entered is put on a horse at the start line, a
-- countdown, and they race through the checkpoints to the finish. Fighting
-- is allowed. Prizes for the top 3 (and a Saint's Corpse part for the winner).
---------------------------------------------------------------------------
TuskConfig.Race = {
	Enabled = true,
	Every = 600, -- seconds from one race's entry opening to the next (10 minutes)
	FirstAfter = 120, -- the first race opens this long after the server starts
	StudioFirstAfter = 20, -- in Studio the first race opens quickly so you can test it
	EntryTime = 45, -- seconds entry stays open
	Countdown = 4, -- seconds on the start line before each stage (3, 2, 1, GO!)
	TimeLimit = 420, -- the race ends after this long no matter what (7 minutes)
	FinishGrace = 40, -- ...or this long after the winner crosses the line
	-- The course (offsets from the map's origin; snapped to the ground):
	-- about 2,900 studs, a lap of the whole map. It starts inside the fenced
	-- race track behind its START arch, runs south down the track, swings
	-- west and right up the west side, across the north, down the east
	-- side, then back up past Headquarters hill to finish by the spawn.
	Start = Vector3.new(0, 0, 118), -- the front of the starting grid
	StartFacing = Vector3.new(0, 0, -1), -- down the track
	GridColumns = 4, GridSpacing = 4.5, GridRowGap = 7, -- riders line up 4 abreast inside the track
	Checkpoints = {
		Vector3.new(0, 0, -90), -- 1: down the race track
		Vector3.new(0, 0, -262), -- 2: out past the end of the track
		Vector3.new(-100, 0, -250), -- 3: south desert, heading west
		Vector3.new(-200, 0, -170), -- 4: western desert
		Vector3.new(-290, 0, -90), -- 5: far west
		Vector3.new(-340, 0, 60), -- 6: up the west side
		Vector3.new(-320, 0, 200), -- 7: north-west
		Vector3.new(-260, 0, 330), -- 8: north-west corner
		Vector3.new(-100, 0, 360), -- 9: across the north
		Vector3.new(50, 0, 330), -- 10: north
		Vector3.new(200, 0, 330), -- 11: north-east
		Vector3.new(330, 0, 300), -- 12: north-east corner
		Vector3.new(350, 0, 150), -- 13: down the east side
		Vector3.new(340, 0, -60), -- 14: past the western town
		Vector3.new(320, 0, -230), -- 15: south-east
		Vector3.new(200, 0, -190), -- 16: under Headquarters hill
		Vector3.new(185, 0, -40), -- 17: east desert, outside town
		Vector3.new(160, 0, 110), -- 18: the north-east flats
		Vector3.new(130, 0, 165), -- 19: the home stretch
		Vector3.new(45, 0, 175), -- FINISH, by the spawn
	},
	-- THE STAGES, like the real Steel Ball Run: nine stages from San Diego to
	-- New York, each its own race with a mass start where the last one ended.
	-- Placings score points (StagePoints); most points after the last stage
	-- wins. Our desert map stands in for America: each stage is a stretch of
	-- it, routed round every building, mesa, hill and the mountains, and it
	-- only crosses the river by the covered bridge. (Offsets from the map's
	-- origin; snapped to the ground.)
	Stages = {
		{ Name = "SAN DIEGO BEACH", Tagline = "The 15 km sprint off the beach", Start = Vector3.new(0, 0, 118), Gates = { Vector3.new(0, 0, -52), Vector3.new(0, 0, -260) } }, -- 1
		{ Name = "ARIZONA DESERT", Tagline = "Across the desert to Monument Valley", Start = Vector3.new(0, 0, -262), Gates = { Vector3.new(48, 0, -268), Vector3.new(148, 0, -332), Vector3.new(204, 0, -228), Vector3.new(236, 0, -204), Vector3.new(312, 0, -184), Vector3.new(332, 0, -40) } }, -- 2
		{ Name = "ROCKY MOUNTAINS", Tagline = "Up through the Rockies", Start = Vector3.new(330, 0, -40), Gates = { Vector3.new(308, 0, -80), Vector3.new(252, 0, -104), Vector3.new(180, 0, -120), Vector3.new(96, 0, -204), Vector3.new(52, 0, -208), Vector3.new(32, 0, -252), Vector3.new(-148, 0, -280), Vector3.new(-180, 0, -236), Vector3.new(-228, 0, -172) } }, -- 3
		{ Name = "GREAT PLAINS", Tagline = "The long flat run across the prairie", Start = Vector3.new(-230, 0, -170), Gates = { Vector3.new(-324, 0, -60), Vector3.new(-332, 0, 132), Vector3.new(-200, 0, 180) } }, -- 4
		{ Name = "MISSISSIPPI RIVER", Tagline = "Over the bridge and up the far bank", Start = Vector3.new(-200, 0, 180), Gates = { Vector3.new(-60, 0, 228), Vector3.new(-8, 0, 252), Vector3.new(0, 0, 332), Vector3.new(-180, 0, 332) } }, -- 5
		{ Name = "LAKE MICHIGAN", Tagline = "Along the northern shore", Start = Vector3.new(-180, 0, 330), Gates = { Vector3.new(-60, 0, 348), Vector3.new(60, 0, 356), Vector3.new(172, 0, 344) } }, -- 6
		{ Name = "PHILADELPHIA", Tagline = "Back over the river and east", Start = Vector3.new(170, 0, 345), Gates = { Vector3.new(0, 0, 336), Vector3.new(0, 0, 252), Vector3.new(120, 0, 184), Vector3.new(348, 0, 140) } }, -- 7
		{ Name = "NEW JERSEY", Tagline = "Down the east side, almost home", Start = Vector3.new(350, 0, 140), Gates = { Vector3.new(348, 0, -28), Vector3.new(332, 0, -160), Vector3.new(172, 0, -108), Vector3.new(136, 0, -52), Vector3.new(100, 0, 20) } }, -- 8
		{ Name = "NEW YORK", Tagline = "The final stage: to the finish line", Start = Vector3.new(100, 0, 20), Gates = { Vector3.new(172, 0, 60), Vector3.new(228, 0, 104), Vector3.new(120, 0, 148), Vector3.new(44, 0, 176) } }, -- 9
	},
	-- THE RACE MAP: a whole separate, giant world just for the race (RaceMap),
	-- built far from the main map when the server starts: about 12,000 studs of
	-- trail through the nine stages, each with its own scenery. Riders are
	-- taken there for the race and brought back to the spawn after. With it
	-- off, the stages above are run round the main map instead.
	Map = { Enabled = true, Origin = Vector3.new(6000, 0, 0), GateEvery = 260, WaterSlow = 0.45 },
	StagePoints = { 100, 70, 50, 40, 30, 25, 20, 15, 10, 5 }, -- by stage placing (riders who don't finish a stage score 0)
	StageWinnerCash = 50, -- a player who wins a stage
	StageRest = 6, -- seconds between stages (results, then line up again)
	StageTimeLimit = 150, -- a stage ends after this long no matter what...
	StageGrace = 25, -- ...or this long after its winner crosses the line
	GateWidth = 34, -- studs between a gate's posts (wide enough to stand outside the track's fences)
	PassRadius = 20, -- get this close to the next gate to pass it
	-- Horses
	HorseSpeed = 3.2, -- walk speed multiplier while racing
	Coats = { -- NPC jockeys' horses (players ride the horse they set up in the shop)
		{ Color3.fromRGB(120, 76, 44), Color3.fromRGB(40, 26, 18) }, -- bay
		{ Color3.fromRGB(40, 36, 36), Color3.fromRGB(18, 16, 16) }, -- black
		{ Color3.fromRGB(226, 222, 212), Color3.fromRGB(180, 176, 168) }, -- grey / white
		{ Color3.fromRGB(170, 90, 44), Color3.fromRGB(130, 64, 30) }, -- chestnut
		{ Color3.fromRGB(214, 176, 110), Color3.fromRGB(245, 236, 210) }, -- palomino
		{ Color3.fromRGB(150, 110, 80), Color3.fromRGB(240, 238, 230) }, -- paint
	},
	-- NPC JOCKEYS ride too (they find their way round with pathfinding).
	NPCRacers = 7,
	NPCNames = { "Dusty Pete", "Sandstorm Sally", "Iron Hoof Ike", "Lucky Lou", "Prairie Pat", "Cactus Jack", "Two-Spur Tom", "Rattlesnake Rosa", "Big Sky Hank", "Whiskey Jim" },
	NPCSkill = { 0.92, 1.04 }, -- their horse speed is HorseSpeed times this (random per jockey): a real race
	NPCHealth = 120,
	Prizes = { 500, 250, 150 },
	FinishPrize = 50,
	WinnerCorpsePart = true, -- a Saint's Corpse part appears at the finish for the winner (if one is lying out)
	-- GALLOP: hold Shift (L3, or GALLOP on mobile) while racing to go faster.
	-- It uses your horse's stamina; run it dry and your horse is WINDED (no
	-- galloping) until it's got its breath back.
	Gallop = {
		Speed = 1.35, -- speed multiplier while galloping
		Drain = 18, -- stamina per second while galloping (out of 100)
		Regen = 11, -- stamina back per second when not galloping...
		RegenDelay = 0.8, -- ...this long after you stop
		WindedUntil = 40, -- winded: no galloping until stamina is back to this
	},
	-- CARROTS: a crate of carrots on each leg of the course; ride through it
	-- for stamina and a little burst of speed. It comes back after a while.
	Carrots = { PerLeg = 1, Every = 320, Radius = 7, Refill = 45, Boost = 1.2, BoostTime = 1.5, Respawn = 10 }, -- PerLeg at least, or one per Every studs of a long leg
	-- HURDLES: log jumps across the course. Jump them (Space / A); hit one and
	-- your horse stumbles (slowed, loses stamina).
	Hurdles = { Every = 2, MinLeg = 70, Spacing = 220, Width = 30, Clearance = 4.2, StumbleSlow = 0.4, StumbleTime = 1.2, StumbleStamina = 20, ClearStamina = 5, JockeyMiss = 0.05 },
	-- LOST? Press H (D-pad up) to go back to the last gate you passed; you're
	-- held there ReturnPenalty seconds.
	ReturnPenalty = 3, ReturnCooldown = 8,
	-- JOCKEY smarts: they save stamina, sprint the last stretch of a stage,
	-- turn aside for carrots when they're tired, and a jockey who's fallen
	-- far behind digs in (CatchUp speed) so the field stays close.
	Jockey = {
		GallopAbove = 55, StopBelow = 18, SprintFrom = 0.75, CarrotBelow = 55, CarrotReach = 35, CatchUpBehind = 110, CatchUp = 1.08,
		Lane = 4, -- each jockey keeps to its own lane (studs either side of the road's middle) so they don't bunch up
		CornerCut = 12, -- near a gate they already aim on towards the next one
		-- FIGHTING (from FightFromStage on): Brawlers (that share of the
		-- jockeys) ride at rivals close by and lash them with a whip in
		-- passing: other jockeys, and you (PlayerChance of the time).
		FightFromStage = 2, Brawlers = 0.6, SeekRange = 18, FightRange = 9, FightEvery = { 2.5, 4.5 },
		FightPlayers = true, PlayerChance = 0.5,
		Damage = 6, Stun = 0.45, Knockback = 26,
	},
	-- RECORDS: your best total time (all 9 stages) and your wins are saved (DataService).
}

---------------------------------------------------------------------------
-- YOUR HORSE: press M (controller D-pad left) to call your horse and ride it
-- anywhere; press again to get off. Customise it in the STABLE (bounty
-- board > SHOP): coat, mane & tail, saddle blanket, saddle leather, face
-- marking, socks and its name. You
-- race on it too. (Saved with your Cash: TuskConfig.Save.)
---------------------------------------------------------------------------
TuskConfig.Horses = {
	Enabled = true,
	RideSpeed = 2.8, -- walk speed multiplier on your own horse (races use Race.HorseSpeed)
	Cooldown = 2, -- seconds between calling / sending away your horse
	Coats = {
		{ Id = "Bay", Name = "BAY", Price = 0, Body = Color3.fromRGB(120, 76, 44), Mane = Color3.fromRGB(40, 26, 18) },
		{ Id = "Black", Name = "BLACK", Price = 150, Body = Color3.fromRGB(40, 36, 36), Mane = Color3.fromRGB(18, 16, 16) },
		{ Id = "Grey", Name = "DAPPLE GREY", Price = 150, Body = Color3.fromRGB(200, 198, 192), Mane = Color3.fromRGB(150, 148, 142) },
		{ Id = "Chestnut", Name = "CHESTNUT", Price = 150, Body = Color3.fromRGB(170, 90, 44), Mane = Color3.fromRGB(130, 64, 30) },
		{ Id = "Palomino", Name = "PALOMINO", Price = 250, Body = Color3.fromRGB(214, 176, 110), Mane = Color3.fromRGB(245, 236, 210) },
		{ Id = "Paint", Name = "PAINT", Price = 250, Body = Color3.fromRGB(150, 110, 80), Mane = Color3.fromRGB(240, 238, 230) },
		{ Id = "Midnight", Name = "MIDNIGHT", Price = 500, Body = Color3.fromRGB(24, 28, 52), Mane = Color3.fromRGB(190, 200, 230), Socks = false },
		{ Id = "Ghost", Name = "GHOST WHITE", Price = 600, Body = Color3.fromRGB(245, 245, 250), Mane = Color3.fromRGB(200, 220, 255), Socks = false },
		{ Id = "Golden", Name = "GOLDEN STEED", Price = 900, Body = Color3.fromRGB(230, 186, 60), Mane = Color3.fromRGB(255, 244, 200), Material = "Metal", Socks = false },
	},
	Blankets = {
		{ Id = "Red", Name = "RED", Price = 0, Color = Color3.fromRGB(170, 40, 40) },
		{ Id = "Blue", Name = "BLUE", Price = 60, Color = Color3.fromRGB(40, 80, 170) },
		{ Id = "Green", Name = "GREEN", Price = 60, Color = Color3.fromRGB(50, 130, 70) },
		{ Id = "Purple", Name = "PURPLE", Price = 80, Color = Color3.fromRGB(110, 50, 150) },
		{ Id = "Black", Name = "BLACK", Price = 80, Color = Color3.fromRGB(30, 30, 34) },
		{ Id = "Gold", Name = "GOLD TRIM", Price = 200, Color = Color3.fromRGB(230, 186, 60) },
		{ Id = "White", Name = "WHITE", Price = 60, Color = Color3.fromRGB(235, 232, 225) },
		{ Id = "Pink", Name = "PINK", Price = 80, Color = Color3.fromRGB(230, 130, 170) },
		{ Id = "Teal", Name = "TEAL", Price = 80, Color = Color3.fromRGB(60, 160, 160) },
	},
	-- Mane and tail colour ("Natural" = the coat's own).
	Manes = {
		{ Id = "Natural", Name = "NATURAL", Price = 0 },
		{ Id = "Black", Name = "BLACK", Price = 40, Color = Color3.fromRGB(20, 18, 18) },
		{ Id = "Flaxen", Name = "FLAXEN", Price = 60, Color = Color3.fromRGB(240, 222, 170) },
		{ Id = "Silver", Name = "SILVER", Price = 80, Color = Color3.fromRGB(200, 204, 214) },
		{ Id = "Red", Name = "FIERY RED", Price = 80, Color = Color3.fromRGB(190, 50, 30) },
		{ Id = "Blue", Name = "BLUE", Price = 120, Color = Color3.fromRGB(60, 110, 220) },
		{ Id = "Pink", Name = "PINK", Price = 120, Color = Color3.fromRGB(240, 130, 190) },
		{ Id = "Gold", Name = "GOLDEN", Price = 200, Color = Color3.fromRGB(240, 196, 70) },
	},
	-- Saddle, bridle and reins.
	Saddles = {
		{ Id = "Brown", Name = "BROWN", Price = 0, Color = Color3.fromRGB(96, 58, 32) },
		{ Id = "Black", Name = "BLACK", Price = 60, Color = Color3.fromRGB(28, 26, 26) },
		{ Id = "Tan", Name = "TAN", Price = 60, Color = Color3.fromRGB(190, 140, 90) },
		{ Id = "Red", Name = "RED", Price = 100, Color = Color3.fromRGB(150, 30, 30) },
		{ Id = "White", Name = "WHITE", Price = 100, Color = Color3.fromRGB(235, 230, 220) },
		{ Id = "Silver", Name = "SILVER", Price = 250, Color = Color3.fromRGB(190, 195, 205), Material = "Metal" },
	},
	-- Face markings.
	Markings = {
		{ Id = "Blaze", Name = "BLAZE", Price = 0, Style = "Blaze" },
		{ Id = "None", Name = "PLAIN", Price = 0, Style = "None" },
		{ Id = "Star", Name = "STAR", Price = 40, Style = "Star" },
		{ Id = "Stripe", Name = "STRIPE", Price = 40, Style = "Stripe" },
		{ Id = "Bald", Name = "BALD FACE", Price = 60, Style = "Bald" },
	},
	-- White socks.
	Socks = {
		{ Id = "Two", Name = "TWO", Price = 0, Style = "Two" },
		{ Id = "None", Name = "NONE", Price = 0, Style = "None" },
		{ Id = "Front", Name = "FRONT", Price = 30, Style = "Front" },
		{ Id = "Back", Name = "BACK", Price = 30, Style = "Back" },
		{ Id = "Four", Name = "ALL FOUR", Price = 50, Style = "Four" },
	},
	NameMaxLength = 20, -- name your horse (filtered); it's shown above it
}

---------------------------------------------------------------------------
-- SAVING (DataStore): Cash, Bounties and everything in the horse stable are
-- saved and come back next time you play. In Studio, turn on Game Settings >
-- Security > "Enable Studio Access to API Services" (place must be published).
---------------------------------------------------------------------------
TuskConfig.Save = {
	Enabled = true,
	StoreName = "SpinPlayerData_v1", -- change the name to start everyone fresh
	AutosaveEvery = 120, -- seconds
	Retries = 3,
}

---------------------------------------------------------------------------
-- Weather: it rains for a while every few minutes (the whole server).
---------------------------------------------------------------------------
TuskConfig.Weather = {
	Enabled = true,
	RainEvery = 300, -- seconds between the start of one rain and the next (5 minutes)
	RainDuration = 60, -- how long each rain lasts
	FirstRainAfter = 300, -- seconds after the server starts (set lower to test)
	StudioFirstRainAfter = 15, -- in Studio the first rain comes quickly so you can test it
}

TuskConfig.Sounds = {
	Rain = "", -- a looping rain sound id (optional)
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
