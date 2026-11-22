---
tags: [install]
updated: 2026-11-22
---
# Quick Install (4 files)
Same format as Anime Fighters: `_Server` = Script, `_Client` = LocalScript, settings = ModuleScripts.

| File | Type | Put it in |
|---|---|---|
| `SpinConfig.lua` | **ModuleScript** named `SpinConfig` | **ReplicatedStorage** |
| `TuskConfig.lua` | **ModuleScript** named `TuskConfig` | **ReplicatedStorage** |
| `Spin_Server.lua` | **Script** named `Spin_Server` | **ServerScriptService** |
| `Spin_Client.lua` | **LocalScript** named `Spin_Client` | **StarterPlayer › StarterPlayerScripts** |

1. Explorer › right-click the place › ➕ Insert Object › pick the type › rename it.
2. Open it, Ctrl+A, paste the matching file.
3. Press **Play**. The SBR map builds itself when the game starts (turn off with `BUILD_MAP_ON_START = false` at the top of Spin_Server).
4. Watch the Output window for "[Spin] Server ready".

**Updates:** open the script, Ctrl+A, paste the new version. The names don't change.
**Settings** (damage, cooldowns, keys, sound ids) live only in SpinConfig and TuskConfig.

> If you installed the older 39-script version, delete the `SpinShared`, `SpinServer`, `SpinClient` and `SpinTools` objects first.

## Wrong script?
`Spin_Server` code goes in the **Script**, `Spin_Client` code goes in the **LocalScript**. If they're swapped, the Output now shows a clear message saying which file goes where.
