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
| 11 | [[DiavoloOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 12 | [[DiegoAUOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 13 | [[DiegoOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 14 | [[DioOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 15 | [[GiornoOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 16 | [[GyroOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 17 | [[HotPantsOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 18 | [[JodioOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 19 | [[JohnnyOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 20 | [[JosephOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 21 | [[Josuke4Outfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 22 | [[JosukeOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 23 | [[JotaroOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 24 | [[KiraOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 25 | [[MountainTimOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 26 | [[NPCService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 27 | [[OkuyasuOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 28 | [[PolnareffOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 29 | [[PorkPieOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 30 | [[ProjectileService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 31 | [[RaceMap]] | ModuleScript | `ServerScriptService › SpinServer` |
| 32 | [[RaceService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 33 | [[RingoOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 34 | [[RohanOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 35 | [[SandmanOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 36 | [[ShopBalls]] | ModuleScript | `ServerScriptService › SpinServer` |
| 37 | [[StandAssetLoader]] | ModuleScript | `ServerScriptService › SpinServer` |
| 38 | [[StandBots]] | ModuleScript | `ServerScriptService › SpinServer` |
| 39 | [[TestDummies]] | ModuleScript | `ServerScriptService › SpinServer` |
| 40 | [[TooruOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 41 | [[TuskAwakening]] | ModuleScript | `ServerScriptService › SpinServer` |
| 42 | [[TuskHitbox]] | ModuleScript | `ServerScriptService › SpinServer` |
| 43 | [[TuskMoves]] | ModuleScript | `ServerScriptService › SpinServer` |
| 44 | [[TuskService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 45 | [[TuskSneakService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 46 | [[ValentineOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 47 | [[WeatherService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 48 | [[SpinServer]] | Script | `ServerScriptService` |
| 49 | [[Axl]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 50 | [[Blackmore]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 51 | [[ChariotRequiem]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 52 | [[Diavolo]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 53 | [[DiegoAU]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 54 | [[DiegoBrando]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 55 | [[Dio]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 56 | [[Giorno]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 57 | [[GoldExperienceRequiem]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 58 | [[GyroEyes]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 59 | [[GyroZeppeli]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 60 | [[HotPants]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 61 | [[Jodio]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 62 | [[JohnRod]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 63 | [[Joseph]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 64 | [[Josuke]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 65 | [[Josuke4]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 66 | [[Jotaro]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 67 | [[Kira]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 68 | [[MountainTim]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 69 | [[Okuyasu]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 70 | [[Polnareff]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 71 | [[PorkPieHatKid]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 72 | [[Ringo]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 73 | [[Rohan]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 74 | [[Sandman]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 75 | [[Tooru]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 76 | [[TuskAct1]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 77 | [[TuskAct2]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 78 | [[TuskAct3]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 79 | [[TuskAct4]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 80 | [[Valentine]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |

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
| 8 | [[JohnnyArmCutscene]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 9 | [[JointCache]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 10 | [[RaceClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 11 | [[RequiemClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 12 | [[ShopBallClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 13 | [[TuskActCommon]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 14 | [[TuskAnimation]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 15 | [[TuskController]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 16 | [[TuskProjectiles]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 17 | [[TuskSneakController]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 18 | [[TuskStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 19 | [[TuskVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 20 | [[VFXLib]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 21 | [[WeatherClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 22 | [[WorldClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 23 | [[SpinClient]] | LocalScript | `StarterPlayer › StarterPlayerScripts` |
| 24 | [[Act1]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 25 | [[Act2]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 26 | [[Act3]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 27 | [[Act4]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 28 | [[AxlVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 29 | [[BlackmoreVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 30 | [[ChariotRequiemStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 31 | [[ChariotRequiemVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 32 | [[CivilWarStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 33 | [[CrazyDiamondStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 34 | [[D4CStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 35 | [[DiavoloVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 36 | [[Diego]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 37 | [[DiegoAUVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 38 | [[DioVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 39 | [[GERStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 40 | [[GERVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 41 | [[GiornoVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 42 | [[GoldExperienceStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 43 | [[Gyro]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 44 | [[GyroEyesVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 45 | [[HeavensDoorStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 46 | [[HermitPurpleStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 47 | [[HotPantsVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 48 | [[JodioVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 49 | [[JohnRodStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 50 | [[JohnRodVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 51 | [[JosephVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 52 | [[Josuke4VFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 53 | [[JosukeVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 54 | [[JotaroVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 55 | [[KillerQueenStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 56 | [[KingCrimsonStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 57 | [[KiraVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 58 | [[MandomStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 59 | [[MountainTimVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 60 | [[NovemberRainStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 61 | [[OkuyasuVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 62 | [[PolnareffVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 63 | [[PorkPie]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 64 | [[RingoVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 65 | [[RohanVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 66 | [[SandmanVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 67 | [[SilentWayStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 68 | [[SilverChariotStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 69 | [[SoftAndWetStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 70 | [[StarPlatinumStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 71 | [[TheHandStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 72 | [[TheWorldDioStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 73 | [[TheWorldStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 74 | [[TooruVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 75 | [[ValentineVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 76 | [[WonderOfUStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 77 | [[BountyUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 78 | [[CharacterCard]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 79 | [[CombatUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 80 | [[SettingsUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 81 | [[TuskUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 82 | [[UITheme]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |

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
