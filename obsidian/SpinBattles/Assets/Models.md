---
tags: [assets]
updated: 2026-11-22
---
# Models
| Model | Source | Replace with your own |
|---|---|---|
| Steel Ball (green) | procedural `SteelBallModel` | Model `SteelBall` in `SpinShared.Assets` |
| Wrecking Ball (orange) | procedural `WreckingBallModel` | Model `WreckingBall` |
| Tusk Act 1 Stand | **Creator Store model 8768080824 "Tusk1"** (loaded by `StandAssetLoader`, scripts stripped); procedural fallback | id in `TuskConfig.StandModels[1]`, or a Model `TuskAct1` in ReplicatedStorage › SpinAssets |
| Tusk Act 2–4 Stands | procedural | `TuskConfig.StandModels[2..4]` |
| Nail | procedural `NailModel` | n/a |

## Fixing a custom model
- Too big or too small: change `Height` in `TuskConfig.StandModels`.
- Facing the wrong way: set `Rotation = Vector3.new(0, 180, 0)` (or 90 / -90).
- Didn't load (Output says "Could not load"): Toolbox › search 8768080824 › drag it into **ReplicatedStorage**, put it in a **Folder** named `SpinAssets`, rename it `TuskAct1`. Delete any Scripts inside it.
