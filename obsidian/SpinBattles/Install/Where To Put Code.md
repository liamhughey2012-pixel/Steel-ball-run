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
| 1 | [[Maid]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 2 | [[NailModel]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 3 | [[Net]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 4 | [[SpinConfig]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 5 | [[SteelBallModel]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 6 | [[TuskActRegistry]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 7 | [[TuskConfig]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 8 | [[TuskStandModels]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 9 | [[VFXQuality]] | ModuleScript | `ReplicatedStorage › SpinShared` |
| 10 | [[WreckingBallModel]] | ModuleScript | `ReplicatedStorage › SpinShared` |

## Server: ServerScriptService › SpinServer
Damage, cooldowns, projectiles, Tusk, Sneak, NPCs. Players can't see or change these.
| # | Script | Type | Put it in |
|---|---|---|---|
| 1 | [[CombatAdapter]] | ModuleScript | `ServerScriptService › SpinServer` |
| 2 | [[CooldownService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 3 | [[NPCService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 4 | [[ProjectileService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 5 | [[SpinService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 6 | [[StandAssetLoader]] | ModuleScript | `ServerScriptService › SpinServer` |
| 7 | [[TestDummies]] | ModuleScript | `ServerScriptService › SpinServer` |
| 8 | [[TuskHitbox]] | ModuleScript | `ServerScriptService › SpinServer` |
| 9 | [[TuskMoves]] | ModuleScript | `ServerScriptService › SpinServer` |
| 10 | [[TuskService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 11 | [[TuskSneakService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 12 | [[SpinServer]] | Script | `ServerScriptService` |
| 13 | [[TuskAct1]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 14 | [[TuskAct2]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 15 | [[TuskAct3]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 16 | [[TuskAct4]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |

## Client: StarterPlayer › StarterPlayerScripts › SpinClient
Controls, effects, the Tusk Stand, HUD, NPC speech bubbles.
| # | Script | Type | Put it in |
|---|---|---|---|
| 1 | [[CameraFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 2 | [[JointCache]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 3 | [[ProceduralPose]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 4 | [[SpinController]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 5 | [[SpinVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 6 | [[TuskActCommon]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 7 | [[TuskAnimation]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 8 | [[TuskController]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 9 | [[TuskProjectiles]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 10 | [[TuskSneakController]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 11 | [[TuskStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 12 | [[TuskVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 13 | [[VFXLib]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 14 | [[WorldClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 15 | [[SpinClient]] | LocalScript | `StarterPlayer › StarterPlayerScripts` |
| 16 | [[Act1]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 17 | [[Act2]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 18 | [[Act3]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 19 | [[Act4]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 20 | [[CharacterCard]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 21 | [[SpinMeter]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
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
