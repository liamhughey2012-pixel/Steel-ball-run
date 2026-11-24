---
tags: [character, diego-au]
status: built
updated: 2026-11-24
---
# Diego Brando (AU): THE WORLD
Diego Brando from another world. He's a separate character from [[Diego Brando]] (Scary Monsters), and both stay in the game.
Pick him from the character dropdown (DIEGO BRANDO (AU)). Numbers: `TuskConfig.DiegoAU`. Act 14.
Server moves: `TuskActs/DiegoAU`. Visuals: `TuskActVFX/DiegoAUVFX`. Stand model: `TuskActVFX/TheWorldStand`. Look: `DiegoAUOutfit`. Scripts: `DiegoAU_Server` + `DiegoAU_Client`.
Diego and The World were matched to the reference art the user sent (2026-11-24).

![[diego_au_preview.png]]
**Look:**
- a teal jockey cap with a dark brim and "DIO" on the front;
- blond hair to the jaw, with a lock over one eye;
- a teal turtleneck quilted in a dark diamond lattice, with a rolled neck;
- brown gloves;
- khaki trousers with a dark belt and buckle;
- tall dark-brown riding boots with silver spurs.

![[the_world_preview.png]]
**The World** (remodelled from the second set of reference art, 2026-11-24):
- a bright yellow-gold body;
- a tall wedge helmet: wide at the brow, tapering back to a flat top, a sharp ridge up the front, and hood sides round a small face;
- big pillow-like padded rolls looping over both shoulders, down the chest to the hips and round the back;
- clock dials on the wrists and hips, and a belt of round studs;
- boots with a "D" on each shin.

It floats behind him with a golden aura.

| Input | Move | What it does |
|---|---|---|
| M1 | MUDA COMBO | jab, jab, kick, finisher. The World punches with each hit |
| 1 | STAND GRAB | The World lunges out and grabs the nearest enemy in front (12 studs): 4 damage. It holds them up in the air for 0.55 s, then **hurls them** the way he's facing (8, big knockback and launch). Whoever they crash into takes 5. 9 s (3 s on a miss) |
| 2 | STAND BARRAGE | The World rushes ahead with a storm of golden fists for 1.6 s: 16 hits of 0.9, then a big last punch (6, knockback). He can walk at 45% speed during it. A stun stops it. 12 s |
| 3 | KNIFE THROW | **three knives at once**, fanned 8° apart: 4 each. 7 s |
| G | THE WORLD: TIME STOP | "THE WORLD!" appears over his head. **A 60-stud zone** around where he stands is shown as a dome, with a glowing ring on the ground. It stays up for the whole stop. **Time stops for 6 s** (4 s when an NPC does it) for everyone inside, and for anyone who walks in |

**While time is stopped:**
- frozen fighters can't move, act, block or dodge, and their animations freeze;
- the world is grey **inside the dome only** (and always for him);
- he sees a countdown, and frozen players see TIME HAS STOPPED;
- **every projectile in the zone stops in mid-air**: anyone's nails, balls, hooks, words, lassos, raindrops, junk, and his knives and bullets. Others' projectiles stop as soon as they're inside; his own stop after flying 5 studs. They all fly on when time moves again (`ProjectileService.stopTime` / `resumeTime`; clients use `VFXLib.flight` / `held`);
- if he goes down, time moves again at once.

- **Corpse move (V): REVOLVER.** He draws a six-shooter and fans 6 shots where he's aiming: 5 damage each, fast bullets with tracers. Inside stopped time the bullets hang too.
- He's also a Stand-user NPC (11 NPCs now, with a new camp spot in the south-east desert) and a bounty-board target ("STAND: THE WORLD").
- **How it works:** frozen characters get the `TimeStopped` attribute and the server anchors their root. `CombatAdapter.canAct` refuses anyone with that attribute. Freezes and pins are counted, so overlapping time stops, or a grab during a time stop, never unfreeze someone early.
