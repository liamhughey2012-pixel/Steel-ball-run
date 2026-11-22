---
tags: [install]
updated: 2026-11-22
---
# Install Steps
1. Insert the 4 files as in [[Where Every File Goes]].
2. **Build the map** (once): View › Command Bar, paste and press Enter:
   `require(game.ServerStorage.SpinTools.SBRMapBuilder).Build()`
   Then File › Save. Pass `{ Origin = Vector3.new(1500, 0, 0) }` to build it away from an existing map.
3. Press **Play**. You spawn as [[Tusk Act 1]]; three practice dummies stand in front of the spawn.
4. Optional: upload sounds and paste ids into `SpinConfig.Sounds` and `TuskConfig.Sounds` ([[Sounds]]).
5. Optional: connect your own combat in `CombatAdapter.Hooks` ([[Combat Adapter]]).
6. If your game already picks movesets, set `TuskConfig.Progression.AutoEquip = false` and call the Select request from your own menu.
