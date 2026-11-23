---
tags: [install]
updated: 2026-11-23
---
# Quick Install (core + one script per character)
Same format as Anime Fighters (`_Server` = Script, `_Client` = LocalScript, settings = ModuleScripts), but **every character is its own script** so pasting stays fast (owner's request, 2026-11-23).

## Core (4 files)
| File | Type | Put it in |
|---|---|---|
| `SpinConfig.lua` | **ModuleScript** named `SpinConfig` | **ReplicatedStorage** |
| `TuskConfig.lua` | **ModuleScript** named `TuskConfig` | **ReplicatedStorage** |
| `Spin_Server.lua` | **Script** named `Spin_Server` | **ServerScriptService** |
| `Spin_Client.lua` | **LocalScript** named `Spin_Client` | **StarterPlayer › StarterPlayerScripts** |

## Characters (`characters/` folder)
Make a **Folder** named `SpinCharacters` in **ServerScriptService** and another **Folder** named `SpinCharacters` in **ReplicatedStorage**. Each character is a pair of **ModuleScripts**:

| Character | Server half → ServerScriptService › SpinCharacters | Client half → ReplicatedStorage › SpinCharacters |
|---|---|---|
| Gyro Zeppeli (Ball Breaker) | `Gyro_Server` | `Gyro_Client` |
| Diego Brando (Scary Monsters) | `Diego_Server` | `Diego_Client` |
| Pork Pie Hat Kid (Wired) | `PorkPie_Server` | `PorkPie_Client` |
| The SBR map (optional) | `Map_Server` | — |

1. Explorer › right-click the place (or the folder) › ➕ Insert Object › pick the type › rename it exactly.
2. Open it, Ctrl+A, paste the matching file.
3. Press **Play**. Watch the Output window for "[Spin] Server ready".

**Johnny is built into Spin_Server / Spin_Client**, so the core 4 files work on their own. A character whose two scripts aren't installed just can't be picked; without `Map_Server` the map isn't built.

**Updates:** only the files listed in an update change. Open the script, Ctrl+A, paste the new version.
**Settings** (damage, cooldowns, keys, sound ids) live only in SpinConfig and TuskConfig.

> Upgrading from the single big Spin_Server / Spin_Client: replace both, then add the SpinCharacters folders and character scripts.

## Wrong script?
`Spin_Server` code goes in the **Script**, `Spin_Client` code goes in the **LocalScript**. If they're swapped, the Output shows a clear message saying which file goes where.
