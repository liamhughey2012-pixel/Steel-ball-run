---
tags: [install]
updated: 2026-11-22
---
# Where Every File Goes
Unzip the package. In Roblox Studio, right-click each service below, choose **Insert from File…** and pick the file from `install/`:

| File | Right-click this in Explorer | Becomes |
|---|---|---|
| `SpinShared.rbxmx` | **ReplicatedStorage** | Folder `SpinShared` |
| `SpinServer.rbxmx` | **ServerScriptService** | Script `SpinServer` |
| `SpinClient.rbxmx` | **StarterPlayer › StarterPlayerScripts** | LocalScript `SpinClient` |
| `SpinTools.rbxmx` | **ServerStorage** | Folder `SpinTools` (map builder) |
| `assets/audio/*.ogg` | Creator Hub › Asset Manager (upload) | sound ids for the configs |

> If an older version is already installed, **delete the old SpinShared / SpinServer / SpinClient first**, then insert the new ones.

## Full tree
```
ReplicatedStorage
└─ SpinShared (Folder)
   ├─ SpinConfig, VFXQuality, Net, Maid
   ├─ SteelBallModel, WreckingBallModel
   ├─ TuskConfig        ← all Tusk numbers, keys, sound + animation ids
   ├─ TuskActRegistry   ← Act list, names, Implemented flags
   ├─ TuskStandModels   ← procedural Tusk Act 1 Stand
   └─ NailModel         ← procedural nail
ServerScriptService
└─ SpinServer (Script)
   ├─ CombatAdapter, CooldownService, ProjectileService
   ├─ SpinService, TestDummies
   ├─ TuskService, TuskHitbox, TuskSneakService
   ├─ NPCService
   └─ TuskActs (Folder)
      └─ TuskAct1
StarterPlayer › StarterPlayerScripts
└─ SpinClient (LocalScript)
   ├─ VFXLib, CameraFX, JointCache, ProceduralPose
   ├─ SpinVFX, SpinController
   ├─ TuskVFX, TuskAnimation, TuskStand, TuskProjectiles
   ├─ TuskSneakController, TuskController, WorldClient
   ├─ TuskActVFX (Folder) └─ Act1
   └─ UI (Folder) ├─ SpinMeter └─ TuskUI
ServerStorage
└─ SpinTools (Folder)
   └─ SBRMapBuilder
```
Don't rename anything: the scripts find each other by name.
