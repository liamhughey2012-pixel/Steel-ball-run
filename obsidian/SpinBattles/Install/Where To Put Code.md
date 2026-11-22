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
| 1 | [[CombatAdapter]] | ModuleScript | `ServerScriptService › SpinServer` |
| 2 | [[CooldownService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 3 | [[DiegoOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 4 | [[GyroOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 5 | [[NPCService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 6 | [[ProjectileService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 7 | [[StandAssetLoader]] | ModuleScript | `ServerScriptService › SpinServer` |
| 8 | [[TestDummies]] | ModuleScript | `ServerScriptService › SpinServer` |
| 9 | [[TuskHitbox]] | ModuleScript | `ServerScriptService › SpinServer` |
| 10 | [[TuskMoves]] | ModuleScript | `ServerScriptService › SpinServer` |
| 11 | [[TuskService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 12 | [[TuskSneakService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 13 | [[SpinServer]] | Script | `ServerScriptService` |
| 14 | [[DiegoBrando]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 15 | [[GyroZeppeli]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 16 | [[TuskAct1]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 17 | [[TuskAct2]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 18 | [[TuskAct3]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 19 | [[TuskAct4]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |

## Client: StarterPlayer › StarterPlayerScripts › SpinClient
Controls, effects, the Tusk Stand, HUD, NPC speech bubbles.
| # | Script | Type | Put it in |
|---|---|---|---|
| 1 | [[CameraFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 2 | [[HitFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 3 | [[JointCache]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 4 | [[TuskActCommon]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 5 | [[TuskAnimation]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 6 | [[TuskController]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 7 | [[TuskProjectiles]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 8 | [[TuskSneakController]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 9 | [[TuskStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 10 | [[TuskVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 11 | [[VFXLib]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 12 | [[WorldClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 13 | [[SpinClient]] | LocalScript | `StarterPlayer › StarterPlayerScripts` |
| 14 | [[Act1]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 15 | [[Act2]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 16 | [[Act3]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 17 | [[Act4]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 18 | [[Diego]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 19 | [[Gyro]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 20 | [[CharacterCard]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 21 | [[SettingsUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 22 | [[TuskUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |

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
