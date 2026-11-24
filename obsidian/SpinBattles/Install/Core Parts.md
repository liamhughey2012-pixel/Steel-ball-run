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

## Easiest install: insert the model files (no pasting)
`python3 tools/build_paste_models.py` (after `build_bundles.py`) writes three files to `roblox_scripts/`. In Studio, **delete the old Spin scripts first**, then right-click each service > **Insert from File…**:

| File | Right-click this service | It adds |
|---|---|---|
| `Insert_into_ServerScriptService.rbxmx` | ServerScriptService | Spin_Server (Script), SpinCore folder (SpinCore_Server_1–5), SpinCharacters folder (every `_Server`) |
| `Insert_into_ReplicatedStorage.rbxmx` | ReplicatedStorage | TuskConfig, SpinConfig, SpinCore folder (SpinCore_Client_1–8), SpinCharacters folder (every `_Client`) |
| `Insert_into_StarterPlayerScripts.rbxmx` | StarterPlayer > StarterPlayerScripts | Spin_Client (LocalScript) |

## Setup problems are shown on screen
- If a core part is missing, isn't a ModuleScript, or fails, Spin_Client shows a big **"SPIN BATTLEGROUNDS ISN'T SET UP RIGHT"** box listing exactly what to fix. The server's problems reach the screen through the ReplicatedStorage attribute `SpinServerSetupProblem`.
- It's also printed in Output.
- A `_Client` pack left in ServerScriptService is pointed out but doesn't stop the game.
- Parts are also found in ReplicatedStorage and Workspace, in case they're put there.
