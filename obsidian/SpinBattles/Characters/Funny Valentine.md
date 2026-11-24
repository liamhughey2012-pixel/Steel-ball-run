---
tags: [character, valentine]
status: built
updated: 2026-11-24
---
# Funny Valentine: D4C (Dirty Deeds Done Dirt Cheap)
Pick him from the character dropdown (FUNNY VALENTINE). Numbers: `TuskConfig.Valentine`.
Server moves: `TuskActs/Valentine`. Visuals: `TuskActVFX/ValentineVFX`. Stand model: `TuskActVFX/D4CStand`. Look: `ValentineOutfit`. Scripts: `Valentine_Server` + `Valentine_Client`.
Valentine and D4C were matched to the reference art the user sent (2026-11-24).

![[funny_valentine_preview.png]]
**Look:** long wavy blond hair to the shoulders with big spiral ringlets at the sides; a pink long coat (high grey collar, ribbed sleeves, grey ruffled cuffs, the skirt flaring to the calves, a diagonal closure); padded magenta trousers with a belt; tall magenta boots; magenta lattice gloves.

![[d4c_preview.png]]
**D4C:**
- a sleek, shiny ice-blue humanoid;
- two long flat rabbit ears swept up and back, pink inside;
- a narrow face with a ridge down the middle;
- big pink balls on the shoulders and pink briefs at the hips;
- white crosses on the chest and thin pink lines down the arms and legs.

It floats behind him with an ice-blue aura.

| Input | Move | What it does |
|---|---|---|
| M1 | DIRTY DEEDS COMBO | jab, jab, kick, then a wrap-and-point finisher. D4C strikes with each hit |
| 1 | DIMENSION HOP (2026-11-24: + hop back) | a striped flag sweeps round him and he slips between worlds (**can't be hit** for 0.3 s), then steps out **behind** the nearest enemy in front (40 studs) and strikes (5). With nobody there he hops 26 studs ahead. 7 s |
| 2 | PARALLEL VALENTINE | a shimmering Valentine from another world steps out of a flag and fights for 6 s: it chases the enemy nearest to him and punches (3.5, up to 5 punches), then wraps itself in a flag and leaves. 12 s |
| 3 | MENGER SPONGE | the nearest enemy in front (18 studs): 4, then their **other-world double** appears beside them. Two of the same person can't exist together, so they **crumble into cubes**: slowed to 55%, ticks every 0.4 s for 3 s, then they burst apart (7.5, knockback). 13 s (3 s on a miss) |
| G | D4C LOVE TRAIN | a column of light falls on him and a shell of light surrounds him for 6 s. **Every hit on him is cancelled, and the misfortune lands on the nearest enemy instead** (80% of the damage, at least 3) as a bolt of light. He moves 20% faster. It ends with a ring of light (8, knockback) |

- He's also a Stand-user NPC and a bounty-board target ("STAND: D4C").
- Love Train can't ping-pong: damage that was already redirected is just cancelled.

## Move upgrades (2026-11-24)
- **Dimension Hop:** he leaves a flag on a pole where he hopped from. **Press 1 again within 4 s to hop back through it** (no cooldown needed; also can't be hit). It works as an attack and an escape, and the flag blinks in its last second.
- **Parallel Valentine:** if he drops to 25% HP while it's out, **they swap places**. He appears where it was, healed 30% of max HP, and it's gone (once per summon). It now looks like him: pink coat, blond ringlets, magenta trousers.
- **Menger Sponge:** the double now **stays where it appeared** (3.5 studs beside them). They only crumble within 10 studs of it: **run from it and it shatters**, ending the effect and the slow. The burst also hits enemies within 7 studs (5).
- Fixed: a second Menger Sponge or Guilt Membrane on the same target no longer lets the first one's leftover ticks act (per-cast token).
