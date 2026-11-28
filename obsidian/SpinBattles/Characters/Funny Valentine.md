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

## Moveset upgrade 2 (2026-11-24)
- **M1 finisher: FLAG WRAP.** The 4th hit wraps them in a flag: a long stun (0.95 s) and almost no knockback, so you can follow up with an ability.
- **Dimension Hop:**
  - D4C chops **twice** when he steps out (4, then 4 with knockback);
  - **hopping back slams the flag shut** on anyone within 7 studs of it (6 and a stun).
- **Parallel Valentine:**
  - lasts 7 s and lands up to 6 punches;
  - **press 2 again to TRADE PLACES with it** (once, with a quarter-second where he can't be hit);
  - the low-HP swap with a heal still works.
- **Menger Sponge:** when it bursts, the cubes **fly on to the nearest other enemy within 12 studs** and crumble them too (1.6 s of ticks, then a small burst).
- **Love Train:**
  - every hit it turns away **heals him 2**;
  - the end pulse does **+1.5 per hit turned away** (up to +12).

## D4C -LOVE TRAIN- (Act 33, 2026-11-28)
While Valentine holds the **complete Saint's Corpse** (all 8 parts), D4C becomes **D4C -LOVE TRAIN-**. The moment he doesn't (the corpse scatters after the Saint's Miracle, or he goes down), he's back to D4C (Act 13). Numbers: `TuskConfig.LoveTrain`. Server: `TuskActs/LoveTrain`, which also watches for the switch (`CorpseComplete`). Visuals: `TuskActVFX/LoveTrainVFX`. Both are in Valentine's scripts.

**The cutscene** (when **you** become Love Train; about 9.4 s, skippable, toggle `TuskConfig.Cutscenes.LoveTrain`):
1. Wide and low: the eight corpse parts circle him, glowing, as the sky darkens ("THE SAINT'S CORPSE").
2. The parts fly into him one by one, a flash of gold with each.
3. Looking up: the walls of light come down out of the sky on either side of him, and D4C lights up behind him.
4. His face in the gold light: "ALL MISFORTUNE GOES ELSEWHERE".
5. Wide: Valentine in the gap of light with D4C ("D4C -LOVE TRAIN- · WHILE YOU HOLD THE CORPSE").

**Look:** D4C glows, with a halo of light at its back and a gold aura. Two thin walls of light stand either side of Valentine the whole time, with gold motes rising (everyone sees them).

| Input | Move | What it does |
|---|---|---|
| Passive | THE GAP OF LIGHT | he only takes **45%** of every hit; 80% of the rest lands on the nearest other enemy within 80 studs instead (not whoever hit him, if there's anyone else), carried off on a beam of light ("MISFORTUNE") |
| M1 | LOVE TRAIN COMBO | D4C's chops trailed with light; the 4th hit launches |
| 1 | LIGHT RAIL | he glides 34 studs inside a wall of light (nothing can touch him); everyone he passes through is struck (10 damage, launched). 9 s |
| 2 | MISFORTUNE TRANSFER | everything he's been hit for in the last 8 s (8 to 45) lands all at once on the nearest enemy in front (can't be blocked, 1.4 s stun), and he heals half of it ("MISFORTUNE ×N"). 15 s |
| 3 | LIGHT SPEARS | five spears of light fan out over 50°; each strikes the first enemy in its path, one spear per enemy (9 damage). 10 s |
| G | LOVE TRAIN: THE CHOSEN ONE | for 7 s nothing reaches him at all (no damage, no stun, no knockback: all of it goes elsewhere), he moves 25% faster, and the light pulses every second (5 damage to everyone within 22 studs); it ends in a burst (16 damage, launched) |

How it works: `CombatAdapter.dealHit` reads the character attribute `LoveTrainKeep`, keeps that share of the damage and emits `LoveTrainShed` with the rest; `TuskActs/LoveTrain` lands it on someone else with the Source `LoveTrainMisfortune`, which is never shed again (so two Love Trains can't bounce it back and forth). During the ultimate `LoveTrainKeep` is 0, which also zeroes the stun and knockback.
