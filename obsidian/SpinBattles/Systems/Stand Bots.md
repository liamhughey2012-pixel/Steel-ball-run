---
tags: [system, npc]
updated: 2026-11-23
---
# Stand-user NPCs (StandBots)
Enemy NPCs that fight you with a Stand. Code: `StandBots` (server, built into Spin_Server). Settings: `TuskConfig.StandBots`.

- **Where:** a camp 70 studs from the spawn (2 NPCs by default, 14 studs apart).
- **Who:** each one is a random installed character (Johnny, Gyro, Diego, Pork Pie Hat Kid, Sandman), named "Stand User: GYRO ZEPPELI" etc., in that character's colours and outfit.
- **How they fight:** they use the exact same moves as players (same damage, stuns, Stands and effects). They chase anyone within 60 studs, M1 up close, use an ability every ~2.5 s, and use their ultimate when their meter is full (it fills from their hits, like yours). They give up and walk home past 120 studs from camp.
- **Health:** 200. They respawn 10 s after dying, as a random character.
- Turn them off with `TuskConfig.StandBots.Enabled = false`, or change `Count`, `Health`, `AggroRange` and the rest there.

How it works: a bot is a stand-in "player" table, so the server's move code runs for it unchanged. The bot model is tagged `SpinFighter`, so every client draws its Stand, outfit and move effects (`Fighters` client helper).
