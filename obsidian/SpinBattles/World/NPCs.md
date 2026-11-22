---
tags: [world, npc]
status: built
updated: 2026-11-22
---
# NPCs
Spawned at runtime by `NPCService` from markers in `SBRMap.NPCSpawns`.
| NPC | Role | Behaviour |
|---|---|---|
| Race Announcer | Announcer | stands at the start |
| Race Official, HQ Clerk | Official | patrols near home |
| Rival Racer, Rookie Racer | Racer | jog the track waypoints |
| Camp Cook, Wagon Driver, Saloon Owner, Shopkeeper, Townsfolk, Priest | Spectator | wander |
| Sheriff | Guard | walks Main Street |

- Press **E** ("Talk") to hear their lines (speech bubble)
- They sometimes speak on their own when a player is nearby
- Invulnerable (IFrames attribute), and attacks pass through them
- Add or edit an NPC by changing its marker attributes: DisplayName, Role, WanderRadius, Lines (separated by `|`)
