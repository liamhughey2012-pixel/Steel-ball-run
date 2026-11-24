---
tags: [install]
updated: 2026-11-24
---
# Core parts (fast pasting)
Pasting one 400–600 KB script froze Studio for minutes, so the core is split up. **No single script is over ~100 KB.**

| File | Type | Where |
|---|---|---|
| `Spin_Server` (7 KB) | **Script** | ServerScriptService |
| `Spin_Client` (7 KB) | **LocalScript** | StarterPlayer > StarterPlayerScripts |
| `SpinCore_Server_1` … `_5` | **ModuleScripts** | ServerScriptService > **SpinCore** (a Folder) |
| `SpinCore_Client_1` … `_8` | **ModuleScripts** | ReplicatedStorage > **SpinCore** (a Folder) |
| `TuskConfig`, `SpinConfig` | ModuleScripts | ReplicatedStorage |
| `<Name>_Server` / `<Name>_Client` | ModuleScripts | SpinCharacters folders (as before) |

- Spin_Server / Spin_Client find the parts by name (waiting up to 15 s for each), install their modules, then start everything.
- **A missing or wrong part is named in Output** (e.g. "Missing SpinCore_Client_3: make a ModuleScript named …"), and Spin doesn't start half-built.
- The part count can change when the code grows. The build (`tools/build_bundles.py`, `PART_LIMIT`) prints the list.
- Everything is also in `roblox_scripts/SpinBattlegrounds_Paste.zip`.
- The horse EXTRAS (saddlebags, plume, …) were removed at the owner's request. The stable keeps coat, mane & tail, blanket, saddle, marking, socks and the name.
