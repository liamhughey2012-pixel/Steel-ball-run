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
| 15 | [[RingoOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 16 | [[JohnnyOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 17 | [[JosukeOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 18 | [[MountainTimOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 19 | [[NPCService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 20 | [[PorkPieOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 21 | [[ProjectileService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 22 | [[RaceMap]] | ModuleScript | `ServerScriptService › SpinServer` |
| 23 | [[RaceService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 24 | [[SandmanOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 25 | [[StandAssetLoader]] | ModuleScript | `ServerScriptService › SpinServer` |
| 26 | [[StandBots]] | ModuleScript | `ServerScriptService › SpinServer` |
| 27 | [[TestDummies]] | ModuleScript | `ServerScriptService › SpinServer` |
| 28 | [[TooruOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 29 | [[TuskAwakening]] | ModuleScript | `ServerScriptService › SpinServer` |
| 30 | [[TuskHitbox]] | ModuleScript | `ServerScriptService › SpinServer` |
| 31 | [[TuskMoves]] | ModuleScript | `ServerScriptService › SpinServer` |
| 32 | [[TuskService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 33 | [[TuskSneakService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 34 | [[ValentineOutfit]] | ModuleScript | `ServerScriptService › SpinServer` |
| 35 | [[WeatherService]] | ModuleScript | `ServerScriptService › SpinServer` |
| 36 | [[SpinServer]] | Script | `ServerScriptService` |
| 37 | [[Axl]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 38 | [[Blackmore]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 39 | [[DiegoAU]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 40 | [[DiegoBrando]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 41 | [[GyroZeppeli]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 42 | [[HotPants]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 43 | [[Jodio]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 44 | [[JohnRod]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 45 | [[Josuke]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 46 | [[MountainTim]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 47 | [[PorkPieHatKid]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 48 | [[Ringo]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 49 | [[Sandman]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 50 | [[Tooru]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 51 | [[TuskAct1]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 52 | [[TuskAct2]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 53 | [[TuskAct3]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 54 | [[TuskAct4]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |
| 55 | [[Valentine]] | ModuleScript | `ServerScriptService › SpinServer › TuskActs` |

## Client: StarterPlayer › StarterPlayerScripts › SpinClient
Controls, effects, the Tusk Stand, HUD, NPC speech bubbles.
| # | Script | Type | Put it in |
|---|---|---|---|
| 1 | [[CameraFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 2 | [[CorpseClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 3 | [[Cutscenes]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 4 | [[DefenseClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 5 | [[Fighters]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 6 | [[HitFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 7 | [[JointCache]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 8 | [[RaceClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 9 | [[TuskActCommon]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 10 | [[TuskAnimation]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 11 | [[TuskController]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 12 | [[TuskProjectiles]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 13 | [[TuskSneakController]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 14 | [[TuskStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 15 | [[TuskVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 16 | [[VFXLib]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 17 | [[WeatherClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 18 | [[WorldClient]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| 19 | [[SpinClient]] | LocalScript | `StarterPlayer › StarterPlayerScripts` |
| 20 | [[Act1]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 21 | [[Act2]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 22 | [[Act3]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 23 | [[Act4]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 24 | [[AxlVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 25 | [[BlackmoreVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 26 | [[CivilWarStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 27 | [[D4CStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 28 | [[Diego]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 29 | [[DiegoAUVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 30 | [[Gyro]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 31 | [[HotPantsVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 32 | [[JodioVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 33 | [[JohnRodStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 34 | [[JohnRodVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 35 | [[JosukeVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 36 | [[MandomStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 37 | [[MountainTimVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 38 | [[NovemberRainStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 39 | [[PorkPie]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 40 | [[RingoVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 41 | [[SandmanVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 42 | [[SilentWayStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 43 | [[SoftAndWetStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 44 | [[TheWorldStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 45 | [[TooruVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 46 | [[ValentineVFX]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 47 | [[WonderOfUStand]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| 48 | [[BountyUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 49 | [[CharacterCard]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 50 | [[CombatUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 51 | [[SettingsUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 52 | [[TuskUI]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| 53 | [[UITheme]] | ModuleScript | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |

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

## "A character has no effects or animations" (2026-11-26)
This means that character's **client** half isn't running. The server (Spin_Server + `<Name>_Server`) plays the moves, but every player's screen draws them with Spin_Client + `<Name>_Client`. There are two usual causes:
1. **`<Name>_Client` is missing or in the wrong place.** It must be a **ModuleScript** named exactly `<Name>_Client` (e.g. `Dio_Client`) in **ReplicatedStorage › SpinCharacters**, not in ServerScriptService and not in StarterPlayerScripts.
2. **Spin_Client is older than the character.** If Spin_Client was last replaced before the character was added, it doesn't know the character and quietly ignores its `_Client` script. Replace Spin_Client (and TuskConfig) with the newest files.

Spin_Client now checks this when you join. For every character the server has installed, it makes sure the client has that character too. If not, it warns in Output (`[Spin] No effects or animations for Dio: ...`) and shows an on-screen notification. A `<Name>_Client` / `<Name>_Server` in a SpinCharacters folder that the core doesn't recognise also gets a warning ("…is a character this Spin_Client doesn't know yet").
