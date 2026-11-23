---
tags: [system, npc]
updated: 2026-11-23
---
# Stand-user NPCs (StandBots)
Enemy NPCs that fight you with a Stand. Code: `StandBots` (server, built into Spin_Server). Settings: `TuskConfig.StandBots`.

- **Where:** scattered round the map: 6 NPCs, each at a random free spot from `TuskConfig.StandBots.Spots` (Dustwater, the mine, the oasis, the gold camp, the ranch, the town edge, the dunes, the church, outside the fort, the western desert). A respawned NPC takes a new free spot. Without the map they gather 70 studs from the spawn.
- **Who:** each one is a random installed character (Johnny, Gyro, Diego, Pork Pie Hat Kid, Sandman), named "Stand User: GYRO ZEPPELI" etc., in that character's colours and outfit.
- **How they fight:** they use the exact same moves as players (same damage, stuns, Stands and effects). They chase anyone within 60 studs, M1 up close, use an ability every ~2.5 s, and use their ultimate when their meter is full (it fills from their hits, like yours). They give up and walk back to their spot past 120 studs from it.
- **Health:** 200. They respawn 10 s after dying, as a random character.
- Turn them off with `TuskConfig.StandBots.Enabled = false`, or change `Count`, `Health`, `AggroRange` and the rest there.

How it works: a bot is a stand-in "player" table, so the server's move code runs for it unchanged. The bot model is tagged `SpinFighter`, so every client draws its Stand, outfit and move effects (`Fighters` client helper).

## 2026-11-23
- **Every character has an NPC:** `Count = 8`, and each new or respawned NPC is whichever installed character has the fewest NPCs out (ties random), so all 8 are always on the map.
- **Blackmore NPCs rain walk** while it rains (or in their own storm):
  - they start when a player is above them, or now and then while chasing (`RainWalkChance`);
  - they climb toward players above them;
  - same limits as players (`TuskConfig.Blackmore.RainWalk`);
  - the step is server-side, in collision group `SpinRainStep`, which only collides with `SpinStandBot` (the NPC's parts), so players can't stand on it.
