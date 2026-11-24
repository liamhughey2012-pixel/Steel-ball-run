
## NPCs collect slower (2026-11-24)
NPC camps sit next to several part spots, so NPCs were grabbing parts the moment they spawned. Now (`TuskConfig.StandBots`):
- **CorpseSeekDelay = 120:** an NPC doesn't look for parts for 2 minutes after it spawns.
- **CorpseFreshTime = 90:** a part that just appeared (spawned, dropped or scattered) is left alone by NPCs for 90 s, so players get first go.
- **CorpseSeekEvery = 15 / CorpseSeekChance = 0.3:** idle NPCs only sometimes decide to go for one.
- **CorpseSeekRange = 60** (was 90).
- **CorpseMaxPerBot = 1, CorpseMaxForBots = 3:** an NPC holds at most 1 part, and NPCs together hold at most 3.
- **CorpsePickupTime = 2.5:** an NPC kneels by the part for 2.5 s before it has it, so you can snatch it first. A fight interrupts it.

Relics now carry a `LaidAt` attribute (server time).
