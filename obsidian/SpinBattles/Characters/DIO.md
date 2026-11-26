---
tags: [character, dio, the-world]
status: built
updated: 2026-11-26
---
# DIO (THE WORLD, Part 3)
A visitor from another world (Part 3). He's last in the character list. **Not** Diego (AU)'s The World: a different Stand, model and moveset. Numbers: `TuskConfig.Dio`. Act 21.
Server moves: `TuskActs/Dio`. Outfit: `DioOutfit`. Visuals: `TuskActVFX/DioVFX`. Stand model: `TuskActVFX/TheWorldDioStand`. Scripts: `Dio_Server` + `Dio_Client`.

![[dio_preview.png]]
![[the_world_dio_preview.png]]
**DIO:**
- Swept-up blond hair with spiky points, a green headband with a gold heart, and green lips.
- A yellow sleeveless jacket (flared shoulders, high collar), open over a black top. Bare arms with green wristbands.
- A black belt with a green buckle, yellow trousers with gold heart knee pads, and yellow boots with green trim.
- He leans back with a hand at his chest.

**The World (Part 3):**
- A tall, golden, muscular body with sharp green trim lines and a heart on its chest.
- A helmet with a crest sweeping back to a point, a faceplate over the mouth with green seams, narrow white eyes, and ear fins.
- Two green hoses from the back of its head into its back.
- Gold shoulder guards rimmed in green, green wrist and ankle bands, and heart-shaped knee guards.
- A golden aura.

| Input | Move | What it does |
|---|---|---|
| M1 | MUDA COMBO | The World's fists fly out with him; the 4th launches ("MUDA!") |
| 1 | VAMPIRE DRAIN | he grabs the nearest enemy in front (9 studs) and drinks their blood: held for 1.5 s, 3 damage every 0.3 s, he heals 80% of it ("WRYYYYY!", red blood streams into his hand), then he throws them off. A miss is a 3 s cooldown. 12 s |
| 2 | SPACE RIPPER STINGY EYES | two thin white-hot beams from his eyes, 70 studs (10). Stopped by walls. 9 s |
| 3 | KNIFE VOLLEY | a fan of 5 silver knives. **In his own stopped time: a wall of 10, ready again in 2 s.** They hang in the air until time moves. 7 s |
| G | ZA WARUDO: ROAD ROLLER | time stops for 5 s in a 55-stud zone (3.5 s for NPCs). The colours invert, a golden dome spreads, and the world inside goes grey; everyone in it freezes and turns grey, and projectiles hang. He's 20% faster, and knives and eyes are ready at once. **1.3 s before time moves again, a ROAD ROLLER drops out of the sky onto the nearest frozen enemy ("ROAD ROLLER DA!"): 22 damage in 9 studs, can't be blocked.** Then "TOKI WA UGOKIDASU". If he goes down, time resumes at once. |

- **Corpse move (V): WRYYY.** He drains everyone within 18 studs (7 each) and heals 60% of it.
- He's a Stand-user NPC (18 NPCs; new camp far north at 20, 410) and a bounty-board target.
- Knives are server projectiles of Kind `DioKnife` (`TuskService.fireDioKnife`), drawn by DioVFX.
