---
tags: [code, shared]
type: ModuleScript
location: "ReplicatedStorage › SpinShared"
updated: 2026-11-22
---
# TuskActRegistry

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ReplicatedStorage › SpinShared` |
| **Exact name** | `TuskActRegistry` (capitals matter) |

**What it does:** The list of Tusk Acts: names, slot labels, themes and whether each Act is implemented. The server refuses to equip an Act whose Implemented flag is false, and the menu shows it as IN DEVELOPMENT (locked, not a fake button).

## How to add it
1. In Studio's Explorer, find **SpinShared** (ReplicatedStorage › SpinShared).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **TuskActRegistry**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActRegistry  (ReplicatedStorage.SpinShared.TuskActRegistry)

	The list of Tusk Acts: names, slot labels, themes and whether each
	Act is implemented. The server refuses to equip an Act whose
	Implemented flag is false, and the menu shows it as IN DEVELOPMENT
	(locked, not a fake button).

	To add an Act: create ServerScriptService.SpinServer.TuskActs.TuskActN,
	add its client choreography in SpinClient.TuskActVFX.ActN, then set
	Implemented = true here.
]]

local TuskActRegistry = {}

TuskActRegistry.Acts = {
	[1] = {
		Name = "TUSK ACT 1",
		Tagline = "The beginning of Spin",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(90, 230, 255), Secondary = Color3.fromRGB(40, 120, 255) },
		M1 = "NAIL COMBO",
		Abilities = { "NAIL SHOT", "NAIL BARRAGE", "SPINNING NAIL" },
		AbilityKinds = { "Press", "Press", "Hold" }, -- Hold = charge on press, fire on release
		Ultimate = "AWAKEN: INFINITE ROTATION",
		Next = 2, -- the ultimate awakens Tusk to this Act
	},
	[2] = {
		Name = "TUSK ACT 2",
		Tagline = "The Golden Ratio",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(70, 200, 255), Secondary = Color3.fromRGB(30, 80, 220) },
		M1 = "GOLDEN COMBO",
		Abilities = { "GOLDEN RATIO NAIL", "UNDERGROUND PURSUIT", "GOLDEN SPIRAL" },
		AbilityKinds = { "Press", "Press", "Press" },
		Next = 3,
		Ultimate = "AWAKEN: INFINITE ROTATION",
	},
	[3] = {
		Name = "TUSK ACT 3",
		Tagline = "Master of spatial movement",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(60, 140, 255), Secondary = Color3.fromRGB(20, 40, 160) },
		M1 = "WORMHOLE STRIKES",
		Abilities = { "DIMENSIONAL STEP", "SPATIAL PURSUIT", "DIMENSIONAL BREAK" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "AWAKEN: INFINITE ROTATION",
		Next = 4,
	},
	[4] = {
		Name = "TUSK ACT 4",
		Tagline = "Infinite Rotation",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(255, 200, 70), Secondary = Color3.fromRGB(20, 40, 160) },
		M1 = "INFINITE BARRAGE",
		Abilities = { "GOLDEN SPIN NAIL", "INFINITE ROTATION", "GOLDEN PURSUIT" },
		AbilityKinds = { "Press", "Hold", "Press" },
		Ultimate = "INFINITE ROTATION",
		Next = nil, -- final form
	},
	-- Gyro Zeppeli: a separate character that reuses the same ability system.
	[5] = {
		Name = "GYRO ZEPPELI",
		Character = "Gyro",
		Tagline = "Steel Ball master",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(120, 220, 95), Secondary = Color3.fromRGB(40, 120, 50) },
		M1 = "STEEL BALL COMBO",
		Abilities = { "STEEL BALL THROW", "SPIN TORNADO", "SPIN VIBRATION" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "BALL BREAKER",
		Next = nil,
		Module = "GyroZeppeli", -- server moves
		ClientModule = "Gyro", -- client visuals (TuskActVFX.Gyro)
		CardTitle = "STAND  ·  BALL BREAKER",
	},
	-- Diego Brando: Scary Monsters (dinosaur Stand). Same ability system.
	[6] = {
		Name = "SCARY MONSTERS",
		Character = "Diego",
		Tagline = "Dinosaur Stand",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(80, 210, 220), Secondary = Color3.fromRGB(35, 60, 190) },
		M1 = "CLAW COMBO",
		Abilities = { "RAPTOR POUNCE", "DINO INFECTION", "SCARY MONSTERS" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "RAPTOR PACK",
		Next = nil,
		Module = "DiegoBrando", -- server moves
		ClientModule = "Diego", -- client visuals (TuskActVFX.Diego)
		CardTitle = "STAND  ·  SCARY MONSTERS",
		-- The HUD shows a timer on these slots while the attribute (server time) is in the future.
		Buffs = {
			{ Slot = 3, Attribute = "DinoModeUntil", Text = "ACTIVE" },
			{ Slot = 2, Attribute = "ThrallUntil", Text = "COMMAND" },
		},
	},
	-- Pork Pie Hat Kid: WIRED (fish hooks and steel cables from a winch in his mouth).
	[7] = {
		Name = "WIRED",
		Character = "PorkPie",
		Tagline = "Hooks from the water",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(165, 215, 80), Secondary = Color3.fromRGB(95, 105, 125) },
		M1 = "HOOK COMBO",
		Abilities = { "WIRED HOOK", "BAIT PAN", "DOUBLE HOOK LIFT" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "WIRED WINCH",
		Next = nil,
		Module = "PorkPieHatKid", -- server moves
		ClientModule = "PorkPie", -- client visuals (TuskActVFX.PorkPie)
		CardTitle = "STAND  ·  WIRED",
		Buffs = {
			{ Slot = 2, Attribute = "BaitPanUntil", Text = "BAITED" },
		},
	},
	-- Sandman (Soundman): IN A SILENT WAY (sounds written as solid words that
	-- cut, burn and explode when touched).
	[8] = {
		Name = "IN A SILENT WAY",
		Character = "Sandman",
		Tagline = "Sounds made solid",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(245, 185, 80), Secondary = Color3.fromRGB(50, 140, 160) },
		M1 = "SOUND CUT COMBO",
		Abilities = { "SOUND SLASH", "SOUND TRAP", "SAND RUN" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "SILENT SYMPHONY",
		Next = nil,
		Module = "Sandman", -- server moves
		WalkSpeed = 1.25, -- he's a runner: 25% faster than everyone else
		ClientModule = "SandmanVFX", -- client visuals (TuskActVFX.SandmanVFX)
		CardTitle = "STAND  ·  IN A SILENT WAY",
	},
	-- Mountain Tim: OH! LONESOME ME (splits his body into pieces that slide
	-- along his lasso rope).
	[9] = {
		Name = "OH! LONESOME ME",
		Character = "MountainTim",
		Tagline = "Split along the rope",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(214, 156, 84), Secondary = Color3.fromRGB(96, 62, 38) },
		M1 = "LASSO COMBO",
		Abilities = { "LASSO SNARE", "SPLIT DODGE", "SPLIT BARRAGE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "LONESOME ROUNDUP",
		Next = nil,
		Module = "MountainTim", -- server moves
		ClientModule = "MountainTimVFX", -- client visuals (TuskActVFX.MountainTimVFX)
		CardTitle = "STAND  ·  OH! LONESOME ME",
	},
	-- Hot Pants: CREAM STARTER (a spray can that sprays flesh: seals wounds,
	-- coats and smothers enemies).
	[10] = {
		Name = "CREAM STARTER",
		Character = "HotPants",
		Tagline = "Flesh spray",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(242, 140, 172), Secondary = Color3.fromRGB(120, 60, 92) },
		M1 = "SPRAY COMBO",
		Abilities = { "FLESH SPRAY", "FLESH SEAL", "FLESH MEND" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "FLESH STORM",
		Next = nil,
		Module = "HotPants", -- server moves
		ClientModule = "HotPantsVFX", -- client visuals (TuskActVFX.HotPantsVFX)
		CardTitle = "STAND  ·  CREAM STARTER",
		Buffs = {
			{ Slot = 3, Attribute = "FleshMendUntil", Text = "HEALING" },
		},
	},
	-- Blackmore: CATCH THE RAINBOW (freezes raindrops in mid-air: cuts with
	-- them, walks on them, scatters into them).
	[11] = {
		Name = "CATCH THE RAINBOW",
		Character = "Blackmore",
		Tagline = "Raindrops frozen in the air",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(110, 180, 255), Secondary = Color3.fromRGB(40, 50, 90) },
		M1 = "RAINDROP COMBO",
		Abilities = { "RAINDROP BLADES", "RAINDROP STEP", "RAINDROP CAGE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "CATCH THE RAINBOW",
		Next = nil,
		Module = "Blackmore", -- server moves
		ClientModule = "BlackmoreVFX", -- client visuals (TuskActVFX.BlackmoreVFX)
		CardTitle = "STAND  ·  CATCH THE RAINBOW",
	},
	-- Axl RO: CIVIL WAR (makes a target's guilt real: specters and the things
	-- they abandoned rise up and engulf them in a crushing membrane; water,
	-- like the rain, washes it away).
	[12] = {
		Name = "CIVIL WAR",
		Character = "Axl",
		Tagline = "Guilt made real",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(214, 60, 70), Secondary = Color3.fromRGB(226, 196, 110) },
		M1 = "GUILT COMBO",
		Abilities = { "GUILT SPECTERS", "ABANDONED JUNK", "GUILT MEMBRANE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "CIVIL WAR",
		Next = nil,
		Module = "Axl", -- server moves
		ClientModule = "AxlVFX", -- client visuals (TuskActVFX.AxlVFX)
		CardTitle = "STAND  ·  CIVIL WAR",
		Passive = "GUILT: your hits mark them; your moves feed on it",
	},
	-- Funny Valentine: D4C (Dirty Deeds Done Dirt Cheap): slips between
	-- parallel worlds when sandwiched between things (a flag), brings
	-- people from other worlds, and Love Train turns misfortune away.
	[13] = {
		Name = "D4C",
		Character = "Valentine",
		Tagline = "Dirty Deeds Done Dirt Cheap",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(120, 170, 255), Secondary = Color3.fromRGB(236, 120, 170) },
		M1 = "DIRTY DEEDS COMBO",
		Abilities = { "DIMENSION HOP", "PARALLEL VALENTINE", "MENGER SPONGE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "D4C LOVE TRAIN",
		Next = nil,
		Module = "Valentine", -- server moves
		ClientModule = "ValentineVFX", -- client visuals (TuskActVFX.ValentineVFX)
		CardTitle = "STAND  ·  D4C",
		Buffs = {
			{ Slot = 2, Attribute = "ParallelCloneUntil", Text = "PARALLEL" },
		},
	},
	-- Diego Brando from another world (AU): THE WORLD (stops time).
	[14] = {
		Name = "THE WORLD",
		Character = "DiegoAU",
		Tagline = "Diego from another world",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(236, 196, 70), Secondary = Color3.fromRGB(70, 170, 160) },
		M1 = "MUDA COMBO",
		Abilities = { "STAND GRAB", "STAND BARRAGE", "KNIFE THROW" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "THE WORLD: TIME STOP",
		Next = nil,
		Module = "DiegoAU", -- server moves
		ClientModule = "DiegoAUVFX", -- client visuals (TuskActVFX.DiegoAUVFX)
		CardTitle = "STAND  ·  THE WORLD",
		Buffs = {
			{ Slot = 2, Attribute = "WorldBarrageUntil", Text = "MUDA" },
		},
	},
	-- Josuke Higashikata (JoJolion): SOFT & WET (plunder bubbles that steal
	-- things from what they touch: friction, sight, sound...).
	[15] = {
		Name = "SOFT & WET",
		Character = "Josuke",
		Tagline = "Plunder bubbles",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(120, 190, 240), Secondary = Color3.fromRGB(240, 200, 90) },
		M1 = "SOFT & WET COMBO",
		Abilities = { "PLUNDER: FRICTION", "PLUNDER: SIGHT", "BUBBLE MINES" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "GO BEYOND",
		Next = nil,
		Module = "Josuke", -- server moves
		ClientModule = "JosukeVFX", -- client visuals (TuskActVFX.JosukeVFX)
		CardTitle = "STAND  ·  SOFT & WET",
	},
	-- Tooru (JoJolion): WONDER OF U. The "calamity": whoever pursues him is
	-- struck by misfortune (falling debris, trips, accidents).
	[16] = {
		Name = "WONDER OF U",
		Character = "Tooru",
		Tagline = "The flow of calamity",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(150, 40, 50), Secondary = Color3.fromRGB(240, 196, 60) },
		M1 = "WONDER OF U COMBO",
		Abilities = { "CALAMITY: DEBRIS", "THE PURSUER'S CURSE", "WONDER OF U" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "THE FLOW OF CALAMITY",
		Next = nil,
		Module = "Tooru", -- server moves
		ClientModule = "TooruVFX", -- client visuals (TuskActVFX.TooruVFX)
		CardTitle = "STAND  ·  WONDER OF U",
	},
	-- Jodio Joestar (The JOJOLands): NOVEMBER RAIN. Heavy raindrops that
	-- strike with crushing pressure.
	[17] = {
		Name = "NOVEMBER RAIN",
		Character = "Jodio",
		Tagline = "Crushing rain",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(90, 170, 240), Secondary = Color3.fromRGB(240, 120, 190) },
		M1 = "NOVEMBER RAIN COMBO",
		Abilities = { "HEAVY RAIN", "RAIN BULLETS", "RAIN JET" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "NOVEMBER RAIN: TORRENT",
		Next = nil,
		Module = "Jodio", -- server moves
		ClientModule = "JodioVFX", -- client visuals (TuskActVFX.JodioVFX)
		CardTitle = "STAND  ·  NOVEMBER RAIN",
	},
	-- JOHN ROD: a Stand that is a single bent metal rod tracing the outline
	-- of a man. Its user can send it off and steer it from far away.
	[18] = {
		Name = "JOHN ROD",
		Character = "JohnRod",
		Tagline = "Remote-control rod",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(220, 228, 240), Secondary = Color3.fromRGB(120, 200, 255) },
		M1 = "ROD STRIKES",
		Abilities = { "REMOTE CONTROL", "ROD LASH", "WIRE SNARE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "OUTLINE CAGE",
		Next = nil,
		Module = "JohnRod", -- server moves
		ClientModule = "JohnRodVFX", -- client visuals (TuskActVFX.JohnRodVFX)
		CardTitle = "STAND  ·  JOHN ROD",
	},
	-- RINGO ROADAGAIN: MANDOM. Turning his watch rewinds time by exactly 6
	-- seconds, and only he remembers.
	[19] = {
		Name = "MANDOM",
		Character = "Ringo",
		Tagline = "Six seconds back",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(214, 120, 160), Secondary = Color3.fromRGB(240, 200, 70) },
		M1 = "REVOLVER COMBO",
		Abilities = { "SIX SECONDS", "QUICK DRAW", "MANDOM COUNTER" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "THE PATH OF JUSTICE",
		Next = nil,
		Module = "Ringo", -- server moves
		ClientModule = "RingoVFX", -- client visuals (TuskActVFX.RingoVFX)
		CardTitle = "STAND  ·  MANDOM",
	},
	-- JOTARO KUJO: STAR PLATINUM. Precision, speed and power; stops time.
	[20] = {
		Name = "STAR PLATINUM",
		Character = "Jotaro",
		Tagline = "Ora ora ora",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(130, 110, 220), Secondary = Color3.fromRGB(240, 196, 70) },
		M1 = "ORA COMBO",
		Abilities = { "ORA RUSH", "STAR FINGER", "BEARING SHOT" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "STAR PLATINUM: THE WORLD",
		Next = nil,
		Module = "Jotaro", -- server moves
		ClientModule = "JotaroVFX", -- client visuals (TuskActVFX.JotaroVFX)
		CardTitle = "STAND  ·  STAR PLATINUM",
	},
	-- DIO: THE WORLD (Part 3; not Diego's). A vampire; knives; a road roller.
	[21] = {
		Name = "THE WORLD",
		Character = "Dio",
		Tagline = "Muda muda muda",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(240, 196, 50), Secondary = Color3.fromRGB(60, 160, 110) },
		M1 = "MUDA COMBO",
		Abilities = { "VAMPIRE DRAIN", "SPACE RIPPER STINGY EYES", "KNIFE VOLLEY" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "ZA WARUDO: ROAD ROLLER",
		Next = nil,
		Module = "Dio", -- server moves
		ClientModule = "DioVFX", -- client visuals (TuskActVFX.DioVFX)
		CardTitle = "STAND  ·  THE WORLD",
	},
	-- JOSEPH JOESTAR: HERMIT PURPLE. Thorny vines, Hamon through them, and running away.
	[22] = {
		Name = "HERMIT PURPLE",
		Character = "Joseph",
		Tagline = "Your next line is...",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(150, 80, 200), Secondary = Color3.fromRGB(255, 214, 80) },
		M1 = "HAMON COMBO",
		Abilities = { "HERMIT GRAB", "HAMON VINES", "NIGERUNDAYO!" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "HERMIT WEB OVERDRIVE",
		Next = nil,
		Module = "Joseph", -- server moves
		ClientModule = "JosephVFX", -- client visuals (TuskActVFX.JosephVFX)
		CardTitle = "STAND  ·  HERMIT PURPLE",
	},
	-- JEAN PIERRE POLNAREFF: SILVER CHARIOT. A knight with a rapier.
	[23] = {
		Name = "SILVER CHARIOT",
		Character = "Polnareff",
		Tagline = "Hora hora hora",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(196, 206, 222), Secondary = Color3.fromRGB(110, 170, 230) },
		M1 = "RAPIER COMBO",
		Abilities = { "HORA HORA RUSH", "ARMOR OFF", "RAPIER SHOT" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "AFTERIMAGE STORM",
		Next = nil,
		Module = "Polnareff", -- server moves
		ClientModule = "PolnareffVFX", -- client visuals (TuskActVFX.PolnareffVFX)
		CardTitle = "STAND  ·  SILVER CHARIOT",
	},
	-- SILVER CHARIOT REQUIEM: Silver Chariot pierced by the Requiem Arrow
	-- (Polnareff only, from the arrow; back to Act 23 when he goes down).
	[24] = {
		Name = "SILVER CHARIOT REQUIEM",
		Character = "Polnareff",
		Tagline = "Requiem",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(150, 110, 220), Secondary = Color3.fromRGB(240, 200, 90) },
		M1 = "REQUIEM STRIKES",
		Abilities = { "SOUL SWAP", "REQUIEM'S SLEEP", "SHADOW STEP" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "SOUL REVERSAL",
		Next = nil,
		Module = "ChariotRequiem", -- server moves
		ClientModule = "ChariotRequiemVFX", -- client visuals (TuskActVFX.ChariotRequiemVFX)
		CardTitle = "STAND  ·  SILVER CHARIOT REQUIEM",
	},
	-- JOSUKE HIGASHIKATA (Part 4): CRAZY DIAMOND. Breaks things and restores them.
	[25] = {
		Name = "CRAZY DIAMOND",
		Character = "Josuke4",
		Tagline = "Dorarara",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(236, 120, 190), Secondary = Color3.fromRGB(150, 220, 240) },
		M1 = "DORA COMBO",
		Abilities = { "DORARARA RUSH", "BREAK & RESTORE", "HOMING SHARD" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "WHAT DID YOU SAY ABOUT MY HAIR?!",
		Next = nil,
		Module = "Josuke4", -- server moves
		ClientModule = "Josuke4VFX", -- client visuals (TuskActVFX.Josuke4VFX)
		CardTitle = "STAND  ·  CRAZY DIAMOND",
	},
	-- YOSHIKAGE KIRA: KILLER QUEEN. Anything it touches becomes a bomb.
	[26] = {
		Name = "KILLER QUEEN",
		Character = "Kira",
		Tagline = "Killer Queen has already touched it",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(214, 140, 210), Secondary = Color3.fromRGB(90, 50, 110) },
		M1 = "KILLER QUEEN COMBO",
		Abilities = { "FIRST BOMB", "SHEER HEART ATTACK", "STRAY CAT AIR BOMBS" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "BITES THE DUST",
		Next = nil,
		Module = "Kira", -- server moves
		ClientModule = "KiraVFX", -- client visuals (TuskActVFX.KiraVFX)
		CardTitle = "STAND  ·  KILLER QUEEN",
	},
	-- OKUYASU NIJIMURA: THE HAND. Its right palm erases space.
	[27] = {
		Name = "THE HAND",
		Character = "Okuyasu",
		Tagline = "Za Hando!",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(90, 130, 220), Secondary = Color3.fromRGB(236, 190, 70) },
		M1 = "HAND COMBO",
		Abilities = { "SPACE ERASE", "ERASE PULL", "ERASE DASH" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "ZA HANDO: GREAT ERASURE",
		Next = nil,
		Module = "Okuyasu", -- server moves
		ClientModule = "OkuyasuVFX", -- client visuals (TuskActVFX.OkuyasuVFX)
		CardTitle = "STAND  ·  THE HAND",
	},
}

-- Which character an Act belongs to ("Johnny" for Tusk Acts 1-4).
function TuskActRegistry.characterOf(act)
	local info = TuskActRegistry.Acts[act]
	return info and info.Character or "Johnny"
end

-- The Act a character starts on.
TuskActRegistry.StartAct = { Johnny = 1, Gyro = 5, Diego = 6, PorkPie = 7, Sandman = 8, MountainTim = 9, HotPants = 10, Blackmore = 11, Axl = 12, Valentine = 13, DiegoAU = 14, Josuke = 15, Tooru = 16, Jodio = 17, JohnRod = 18, Ringo = 19, Jotaro = 20, Dio = 21, Joseph = 22, Polnareff = 23, Josuke4 = 25, Kira = 26, Okuyasu = 27 }

function TuskActRegistry.get(act)
	return TuskActRegistry.Acts[act]
end

function TuskActRegistry.isImplemented(act)
	local info = TuskActRegistry.Acts[act]
	return info ~= nil and info.Implemented == true
end

return TuskActRegistry
```
