---
tags: [install, code]
updated: 2026-11-22
---
# Where To Put Code

Every script in Spin Battlegrounds, and exactly where it goes in Roblox Studio. Click a script name to open its note with the full code.

## The rules
1. **Make the containers first**, before any ModuleScripts:
   - Folder `SpinShared` in **ReplicatedStorage**
   - Script `SpinServer` in **ServerScriptService**
   - LocalScript `SpinClient` in **StarterPlayer › StarterPlayerScripts**
   - Folder `SpinTools` in **ServerStorage**
2. **Names must match exactly**, capitals included. The scripts find each other by name.
3. **"Inside a script"** means right-click that Script or LocalScript itself and insert there.
4. Three extra folders go inside the scripts:
   - `SpinServer › TuskActs` (Folder)
   - `SpinClient › TuskActVFX` (Folder)
   - `SpinClient › UI` (Folder)
5. Paste everything **before** pressing Play, or the Output window will show "is not a valid member" errors.
6. To update a script later: open it, Ctrl+A, and paste the new code over it. The name doesn't change.

## What a Studio Explorer should look like
```
ReplicatedStorage
└─ SpinShared                 Folder
   └─ (10 ModuleScripts)
ServerScriptService
└─ SpinServer                 Script
   ├─ (9 ModuleScripts)
   └─ TuskActs                Folder
      └─ TuskAct1             ModuleScript
StarterPlayer
└─ StarterPlayerScripts
   └─ SpinClient              LocalScript
      ├─ (13 ModuleScripts)
      ├─ TuskActVFX           Folder
      │  └─ Act1              ModuleScript
      └─ UI                   Folder
         ├─ SpinMeter         ModuleScript
         └─ TuskUI            ModuleScript
ServerStorage
└─ SpinTools                  Folder
   └─ SBRMapBuilder           ModuleScript
```

## Shared: ReplicatedStorage › SpinShared
Used by both the server and players.
| # | Script | Type | Put it in |
|---|---|---|---|
| 1 | [[Blockify]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 2 | [[HorseModel]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 3 | [[Maid]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 4 | [[NailModel]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 5 | [[Net]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 6 | [[RaptorModel]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 7 | [[SpinConfig]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 8 | [[SteelBallModel]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 9 | [[TuskActRegistry]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 10 | [[TuskConfig]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 11 | [[TuskStandModels]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 12 | [[VFXQuality]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 13 | [[WreckingBallModel]] | ModuleScript | `ReplicatedStorage › SpinShared` |

## Server: ServerScriptService › SpinServer
Damage, cooldowns, projectiles, Tusk, Sneak, NPCs. Players can't see or change these.
| # | Script | Type | Put it in |
|---|---|---|---|
| 1 | [[ArrowService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 2 | [[AxlOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 3 | [[BlackmoreOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 4 | [[BountyService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 5 | [[CombatAdapter]] | ModuleScript | `ServerScriptService › SpinServer` |
| 6 | [[CooldownService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 7 | [[CorpseMoves]] | ModuleScript | `ServerScriptService › SpinServer` |
| 8 | [[CorpseService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 9 | [[DataService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 10 | [[DefenseService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 11 | [[DiegoAUOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 12 | [[DiegoOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 13 | [[DioOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 14 | [[GiornoOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 15 | [[GyroOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 16 | [[HotPantsOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 17 | [[JodioOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 18 | [[JohnnyOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 19 | [[JosephOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 20 | [[Josuke4Outfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 21 | [[JosukeOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 22 | [[JotaroOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 23 | [[KiraOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 24 | [[MountainTimOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 25 | [[NPCService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 26 | [[OkuyasuOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 27 | [[PolnareffOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 28 | [[PorkPieOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 29 | [[ProjectileService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 30 | [[RaceMap]] | ModuleScript | `ServerScriptService › SpinServer` |
| 31 | [[RaceService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 32 | [[RingoOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 33 | [[RohanOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 34 | [[SandmanOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 35 | [[ShopBalls]] | ModuleScript | `ServerScriptService › SpinServer` |
| 36 | [[StandAssetLoader]] | ModuleScript | `ServerScriptService › SpinServer` |
| 37 | [[StandBots]] | ModuleScript | `ServerScriptService › SpinServer` |
| 38 | [[TestDummies]] | ModuleScript | `ServerScriptService › SpinServer` |
| 39 | [[TooruOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 40 | [[TuskAwakening]] | ModuleScript | `ServerScriptService › SpinServer` |
| 41 | [[TuskHitbox]] | ModuleScript | `ServerScriptService › SpinServer` |
| 42 | [[TuskMoves]] | ModuleScript | `ServerScriptService › SpinServer` |
| 43 | [[TuskService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 44 | [[TuskSneakService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 45 | [[ValentineOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 46 | [[WeatherService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 47 | [[SpinServer]] | Script | `ServerScriptService` |
| 48 | [[Axl]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 49 | [[Blackmore]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 50 | [[ChariotRequiem]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 51 | [[DiegoAU]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 52 | [[DiegoBrando]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 53 | [[Dio]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 54 | [[Giorno]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 55 | [[GoldExperienceRequiem]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 56 | [[GyroEyes]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 57 | [[GyroZeppeli]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 58 | [[HotPants]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 59 | [[Jodio]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 60 | [[JohnRod]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 61 | [[Joseph]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 62 | [[Josuke]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 63 | [[Josuke4]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 64 | [[Jotaro]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 65 | [[Kira]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 66 | [[MountainTim]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 67 | [[Okuyasu]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 68 | [[Polnareff]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 69 | [[PorkPieHatKid]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 70 | [[Ringo]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 71 | [[Rohan]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 72 | [[Sandman]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 73 | [[Tooru]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 74 | [[TuskAct1]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 75 | [[TuskAct2]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 76 | [[TuskAct3]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 77 | [[TuskAct4]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 78 | [[Valentine]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |

## Client: StarterPlayer › StarterPlayerScripts › SpinClient
Controls, effects, the Tusk Stand, HUD, NPC speech bubbles.
| # | Script | Type | Put it in |
|---|---|---|---|
| 1 | [[CameraFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 2 | [[Cinematic]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 3 | [[CorpseClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 4 | [[Cutscenes]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 5 | [[DefenseClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 6 | [[Fighters]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 7 | [[HitFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 8 | [[JointCache]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 9 | [[RaceClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 10 | [[RequiemClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 11 | [[ShopBallClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 12 | [[TuskActCommon]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 13 | [[TuskAnimation]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 14 | [[TuskController]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 15 | [[TuskProjectiles]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 16 | [[TuskSneakController]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 17 | [[TuskStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 18 | [[TuskVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 19 | [[VFXLib]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 20 | [[WeatherClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 21 | [[WorldClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 22 | [[SpinClient]] | LocalScript | `StarterPlayer › StarterPlayerScripts` |
| 23 | [[Act1]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 24 | [[Act2]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 25 | [[Act3]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 26 | [[Act4]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 27 | [[AxlVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 28 | [[BlackmoreVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 29 | [[ChariotRequiemStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 30 | [[ChariotRequiemVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 31 | [[CivilWarStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 32 | [[CrazyDiamondStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 33 | [[D4CStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 34 | [[Diego]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 35 | [[DiegoAUVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 36 | [[DioVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 37 | [[GERStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 38 | [[GERVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 39 | [[GiornoVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 40 | [[GoldExperienceStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 41 | [[Gyro]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 42 | [[GyroEyesVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 43 | [[HeavensDoorStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 44 | [[HermitPurpleStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 45 | [[HotPantsVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 46 | [[JodioVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 47 | [[JohnRodStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 48 | [[JohnRodVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 49 | [[JosephVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 50 | [[Josuke4VFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 51 | [[JosukeVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 52 | [[JotaroVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 53 | [[KillerQueenStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 54 | [[KiraVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 55 | [[MandomStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 56 | [[MountainTimVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 57 | [[NovemberRainStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 58 | [[OkuyasuVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 59 | [[PolnareffVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 60 | [[PorkPie]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 61 | [[RingoVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 62 | [[RohanVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 63 | [[SandmanVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 64 | [[SilentWayStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 65 | [[SilverChariotStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 66 | [[SoftAndWetStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 67 | [[StarPlatinumStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 68 | [[TheHandStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 69 | [[TheWorldDioStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 70 | [[TheWorldStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 71 | [[TooruVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 72 | [[ValentineVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 73 | [[WonderOfUStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 74 | [[BountyUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 75 | [[CharacterCard]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 76 | [[CombatUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 77 | [[SettingsUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 78 | [[TuskUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 79 | [[UITheme]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |

## Tools: ServerStorage › SpinTools
Only used in Studio, to build the map once.
| # | Script | Type | Put it in |
|---|---|---|---|
| 1 | [[SBRMapBuilder]] | ModuleScript | `ServerStorage › SpinTools` |

After everything is in: build the map from View › Command Bar with `require(game.ServerStorage.SpinTools.SBRMapBuilder).Build()`, then File › Save. See [[Install Steps]].

## Adding new code later
Every new update will say which scripts are **new** and which are **changed**:
- **New script:** create it in the place shown in its note.
- **Changed script:** open it, Ctrl+A, paste the new version.
- **Asset ids** (sounds, animations) go in [[SpinConfig]] and [[TuskConfig]], not in new scripts.
