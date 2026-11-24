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
| 1 | [[AxlOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 2 | [[BlackmoreOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 3 | [[BountyService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 4 | [[CombatAdapter]] | ModuleScript | `ServerScriptService › SpinServer` |
| 5 | [[CooldownService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 6 | [[CorpseMoves]] | ModuleScript | `ServerScriptService › SpinServer` |
| 7 | [[CorpseService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 8 | [[DataService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 9 | [[DefenseService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 10 | [[DiegoAUOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 11 | [[DiegoOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 12 | [[GyroOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 13 | [[HotPantsOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 14 | [[JodioOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 15 | [[JohnnyOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 16 | [[JosukeOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 17 | [[MountainTimOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 18 | [[NPCService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 19 | [[PorkPieOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 20 | [[ProjectileService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 21 | [[RaceService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 22 | [[SandmanOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 23 | [[StandAssetLoader]] | ModuleScript | `ServerScriptService › SpinServer` |
| 24 | [[StandBots]] | ModuleScript | `ServerScriptService › SpinServer` |
| 25 | [[TestDummies]] | ModuleScript | `ServerScriptService › SpinServer` |
| 26 | [[TooruOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 27 | [[TuskAwakening]] | ModuleScript | `ServerScriptService › SpinServer` |
| 28 | [[TuskHitbox]] | ModuleScript | `ServerScriptService › SpinServer` |
| 29 | [[TuskMoves]] | ModuleScript | `ServerScriptService › SpinServer` |
| 30 | [[TuskService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 31 | [[TuskSneakService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 32 | [[ValentineOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 33 | [[WeatherService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 34 | [[SpinServer]] | Script | `ServerScriptService` |
| 35 | [[Axl]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 36 | [[Blackmore]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 37 | [[DiegoAU]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 38 | [[DiegoBrando]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 39 | [[GyroZeppeli]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 40 | [[HotPants]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 41 | [[Jodio]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 42 | [[Josuke]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 43 | [[MountainTim]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 44 | [[PorkPieHatKid]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 45 | [[Sandman]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 46 | [[Tooru]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 47 | [[TuskAct1]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 48 | [[TuskAct2]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 49 | [[TuskAct3]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 50 | [[TuskAct4]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 51 | [[Valentine]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |

## Client: StarterPlayer › StarterPlayerScripts › SpinClient
Controls, effects, the Tusk Stand, HUD, NPC speech bubbles.
| # | Script | Type | Put it in |
|---|---|---|---|
| 1 | [[CameraFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 2 | [[CorpseClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 3 | [[DefenseClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 4 | [[Fighters]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 5 | [[HitFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 6 | [[JointCache]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 7 | [[RaceClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 8 | [[TuskActCommon]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 9 | [[TuskAnimation]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 10 | [[TuskController]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 11 | [[TuskProjectiles]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 12 | [[TuskSneakController]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 13 | [[TuskStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 14 | [[TuskVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 15 | [[VFXLib]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 16 | [[WeatherClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 17 | [[WorldClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 18 | [[SpinClient]] | LocalScript | `StarterPlayer › StarterPlayerScripts` |
| 19 | [[Act1]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 20 | [[Act2]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 21 | [[Act3]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 22 | [[Act4]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 23 | [[AxlVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 24 | [[BlackmoreVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 25 | [[CivilWarStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 26 | [[D4CStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 27 | [[Diego]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 28 | [[DiegoAUVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 29 | [[Gyro]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 30 | [[HotPantsVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 31 | [[JodioVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 32 | [[JosukeVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 33 | [[MountainTimVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 34 | [[NovemberRainStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 35 | [[PorkPie]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 36 | [[SandmanVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 37 | [[SilentWayStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 38 | [[SoftAndWetStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 39 | [[TheWorldStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 40 | [[TooruVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 41 | [[ValentineVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 42 | [[WonderOfUStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 43 | [[BountyUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 44 | [[CharacterCard]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 45 | [[CombatUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 46 | [[SettingsUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 47 | [[TuskUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 48 | [[UITheme]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |

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
