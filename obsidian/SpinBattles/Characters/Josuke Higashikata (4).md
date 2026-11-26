---
tags: [character, josuke4, crazy-diamond]
status: built
updated: 2026-11-26
---
# JOSUKE HIGASHIKATA (4) (CRAZY DIAMOND)
A visitor from another world (Part 4, Diamond is Unbreakable). He is not the JoJolion Josuke ([[Josuke Higashikata (8)]], Act 15). He's last in the character list. Numbers: `TuskConfig.Josuke4`. Act 25.
Server moves: `TuskActs/Josuke4`. Outfit: `Josuke4Outfit`. Visuals: `TuskActVFX/Josuke4VFX`. Stand model: `TuskActVFX/CrazyDiamondStand`. Scripts: `Josuke4_Server` + `Josuke4_Client`.
Matched to the reference art the user sent (2026-11-26).

![[josuke4_crazy_diamond_preview.png]]
**Josuke:**
- A big pompadour, violet-black with a cross-hatched shine.
- A long dark navy gakuran: a tall collar with a gold anchor badge on one side and two gold hearts on the other, open at the top over a yellow shirt.
- A gold peace-sign pin, gold buttons down the front, and tails to the knees.
- Gold bracelets, wide baggy trousers and black shoes.
- He stands with his fists up, loose.

**Crazy Diamond:**
- A muscular pink body under pale blue-white armour.
- A flat-topped helmet round a pink face with glowing cyan eyes, a grilled mouth and a heart-shaped chin.
- White tubes running from the back of its head to its shoulders, and spiked shoulders.
- A white belly plate with a pink heart and a heart belt buckle.
- Studded fists with hearts on the back, and pale knee and shin guards.
- A pink aura.

| Input | Move | What it does |
|---|---|---|
| M1 | DORA COMBO | Crazy Diamond's fists fly out with him; the 4th hit launches ("DORA!") |
| 1 | DORARARA RUSH | a storm of fists in front of him for 1.4 s, dragging enemies along; a final **DORA!** (8 damage, sends them flying) with a shockwave. 11 s |
| 2 | BREAK & RESTORE | punches the nearest enemy in front (9 studs), then "fixes" them into a lump of rock: stuck, can't move or act, for 2.2 s. Then the rock bursts and knocks them away (7 + 7, the burst can't be blocked). A miss costs only 3 s; otherwise 13 s |
| 3 | HOMING SHARD | flicks a bloodied glass shard that steers after the nearest enemy in front (up to 90 studs); 8 damage. Stopped by walls. 8 s |
| G | WHAT DID YOU SAY ABOUT MY HAIR?! | he touches his pompadour and snaps: the outburst blows everyone within 14 studs back (6), then for 10 s he does **+30% damage**, moves 20% faster, and RUSH and BREAK & RESTORE are ready at once. A pulsing red outline shows the rage |
| Corpse | DORA BARRAGE | a 360° rush round him, then a big DORA! |

Rage damage: the `HairRageUntil` / `HairRageDamage` attributes, applied in `CombatAdapter`.
