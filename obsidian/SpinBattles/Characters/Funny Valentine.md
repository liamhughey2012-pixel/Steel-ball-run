---
tags: [character, valentine]
status: built
updated: 2026-11-24
---
# Funny Valentine: D4C (Dirty Deeds Done Dirt Cheap)
Pick him from the character dropdown (FUNNY VALENTINE). Numbers: `TuskConfig.Valentine`.
Server moves: `TuskActs/Valentine`. Visuals: `TuskActVFX/ValentineVFX`. Stand model: `TuskActVFX/D4CStand`. Look: `ValentineOutfit`. Scripts: `Valentine_Server` + `Valentine_Client`.
Built from the characters' descriptions (no reference art yet). Send pictures of Valentine and D4C to match them.

![[funny_valentine_preview.png]]
**Look:** curly blond hair with big curls out at the sides, a long pale presidential frock coat with gold trim, buttons and tails, a white ruffled cravat, a gold star pin, navy trousers and black riding boots.

![[d4c_preview.png]]
**D4C:**
- a pale-blue humanoid with dark-navy stripes;
- two long rabbit-like horns, pink inside;
- big round eyes and a slitted mouth plate;
- a navy cross over the chest and a pink diamond on the belt;
- pink-rimmed shoulders and knuckles.

It floats behind him with a pale-blue aura (players and NPCs) and strikes with his moves.

| Input | Move | What it does |
|---|---|---|
| M1 | DIRTY DEEDS COMBO | jab, jab, kick, then a wrap-and-point finisher. D4C strikes with each hit |
| 1 | DIMENSION HOP | a striped flag sweeps round him and he slips between worlds (**can't be hit** for 0.3 s), then steps out **behind** the nearest enemy in front (40 studs) and strikes (5). With nobody there he hops 26 studs ahead. 7 s |
| 2 | PARALLEL VALENTINE | a shimmering Valentine from another world steps out of a flag and fights for 6 s: it chases the enemy nearest to him and punches (3.5, up to 5 punches), then wraps itself in a flag and leaves. 12 s |
| 3 | MENGER SPONGE | the nearest enemy in front (18 studs): 4, then their **other-world double** appears beside them. Two of the same person can't exist together, so they **crumble into cubes**: slowed to 55%, ticks every 0.4 s for 3 s, then they burst apart (7.5, knockback). 13 s (3 s on a miss) |
| G | D4C LOVE TRAIN | a column of light falls on him and a shell of light surrounds him for 6 s. **Every hit on him is cancelled, and the misfortune lands on the nearest enemy instead** (80% of the damage, at least 3) as a bolt of light. He moves 20% faster. It ends with a ring of light (8, knockback) |

- He's also a Stand-user NPC and a bounty-board target ("STAND: D4C").
- Love Train can't ping-pong: damage that was already redirected is just cancelled.
