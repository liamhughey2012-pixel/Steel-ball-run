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
| 2 | [[Maid]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 3 | [[NailModel]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 4 | [[Net]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 5 | [[RaptorModel]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 6 | [[SpinConfig]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 7 | [[SteelBallModel]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 8 | [[TuskActRegistry]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 9 | [[TuskConfig]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 10 | [[TuskStandModels]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 11 | [[VFXQuality]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 12 | [[WreckingBallModel]] | ModuleScript | `ReplicatedStorage › SpinShared` |

## Server: ServerScriptService › SpinServer
Damage, cooldowns, projectiles, Tusk, Sneak, NPCs. Players can't see or change these.
| # | Script | Type | Put it in |
|---|---|---|---|
| 1 | [[AxlOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 2 | [[BlackmoreOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 3 | [[BountyService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 4 | [[CombatAdapter]] | ModuleScript | `ServerScriptService › SpinServer` |
| 5 | [[CooldownService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 6 | [[DefenseService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 7 | [[DiegoOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 8 | [[GyroOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 9 | [[HotPantsOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 10 | [[JohnnyOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 11 | [[MountainTimOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 12 | [[NPCService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 13 | [[PorkPieOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 14 | [[ProjectileService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 15 | [[SandmanOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 16 | [[StandAssetLoader]] | ModuleScript | `ServerScriptService › SpinServer` |
| 17 | [[StandBots]] | ModuleScript | `ServerScriptService › SpinServer` |
| 18 | [[TestDummies]] | ModuleScript | `ServerScriptService › SpinServer` |
| 19 | [[TuskHitbox]] | ModuleScript | `ServerScriptService › SpinServer` |
| 20 | [[TuskMoves]] | ModuleScript | `ServerScriptService › SpinServer` |
| 21 | [[TuskService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 22 | [[TuskSneakService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 23 | [[ValentineOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 24 | [[WeatherService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 25 | [[SpinServer]] | Script | `ServerScriptService` |
| 26 | [[Axl]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 27 | [[Blackmore]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 28 | [[DiegoBrando]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 29 | [[GyroZeppeli]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 30 | [[HotPants]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 31 | [[MountainTim]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 32 | [[PorkPieHatKid]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 33 | [[Sandman]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 34 | [[TuskAct1]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 35 | [[TuskAct2]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 36 | [[TuskAct3]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 37 | [[TuskAct4]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 38 | [[Valentine]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |

## Client: StarterPlayer › StarterPlayerScripts › SpinClient
Controls, effects, the Tusk Stand, HUD, NPC speech bubbles.
| # | Script | Type | Put it in |
|---|---|---|---|
| 1 | [[CameraFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 2 | [[DefenseClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 3 | [[Fighters]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 4 | [[HitFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 5 | [[JointCache]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 6 | [[TuskActCommon]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 7 | [[TuskAnimation]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 8 | [[TuskController]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 9 | [[TuskProjectiles]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 10 | [[TuskSneakController]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 11 | [[TuskStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 12 | [[TuskVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 13 | [[VFXLib]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 14 | [[WeatherClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 15 | [[WorldClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 16 | [[SpinClient]] | LocalScript | `StarterPlayer › StarterPlayerScripts` |
| 17 | [[Act1]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 18 | [[Act2]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 19 | [[Act3]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 20 | [[Act4]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 21 | [[AxlVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 22 | [[BlackmoreVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 23 | [[CivilWarStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 24 | [[D4CStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 25 | [[Diego]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 26 | [[Gyro]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 27 | [[HotPantsVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 28 | [[MountainTimVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 29 | [[PorkPie]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 30 | [[SandmanVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 31 | [[SilentWayStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 32 | [[ValentineVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 33 | [[BountyUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 34 | [[CharacterCard]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 35 | [[CombatUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 36 | [[SettingsUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 37 | [[TuskUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |

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
