---
tags: [character, jotaro, star-platinum]
status: built
updated: 2026-11-25
---
# JOTARO KUJO (STAR PLATINUM)
A visitor from another world (Part 3). He's last in the character list. Numbers: `TuskConfig.Jotaro`. Act 20.
Server moves: `TuskActs/Jotaro`. Outfit: `JotaroOutfit`. Visuals: `TuskActVFX/JotaroVFX`. Stand model: `TuskActVFX/StarPlatinumStand`. Scripts: `Jotaro_Server` + `Jotaro_Client`.
Matched to the reference art the user sent (2026-11-25).

![[jotaro_preview.png]]
![[star_platinum_preview.png]]
**Jotaro:**
- A black cap with a gold button and the gold hand badge, with his black hair spiking out of the back.
- A long black gakuran: a tall stand-up collar with gold buttons, open over a grey-green shirt, gold buttons down the front and on the cuffs, and long tails flaring to the knees.
- The gold chain from his left collar, a plain belt and a red/white/teal patterned belt, black trousers and loafers.
- He stands with a hand in his pocket.

**Star Platinum:**
- A huge, muscular blue-violet body with a six-pack.
- Glowing pale eyes, a gold headband with a gem, and long wild black hair streaming back.
- A red scarf with its ends flying behind, and round gold shoulder guards with spirals.
- Black fingerless gloves with gold cuffs, gold elbow and knee bands, a gold belt and a long white loincloth.
- A violet aura.

| Input | Move | What it does |
|---|---|---|
| M1 | ORA COMBO | Star Platinum's fists fly out with him; the 4th hit is a straight that launches ("ORA!") |
| 1 | ORA RUSH | a blur of violet fists in front of him for 1.5 s, dragging enemies along ("ORA ORA ORA"); he can walk slowly. A final big **ORA!** (8 damage, sends them flying) with a shockwave. 11 s |
| 2 | STAR FINGER | two fingers shoot out 22 studs in a line, hitting everyone in it (9). Stopped by walls. 7 s |
| 3 | BEARING SHOT | a flicked ball bearing: instant, 100 studs (7). 6 s |
| G | STAR PLATINUM: THE WORLD | **time stops** for 5 s in a 55-stud zone (3.5 s for NPCs). The colours invert for a beat, a dome spreads out, and the world inside goes grey. Everyone in it, and anyone who walks in, is frozen and turns grey; projectiles hang in the air. He moves 15% faster, and ORA RUSH and STAR FINGER are ready instantly. "TIME RESUMES" with a colour ripple. If he goes down, time resumes at once. |

- **Corpse move (V): ORA BARRAGE.** Star Platinum punches everyone within 16 studs six times, then a big ORA! launches them.
- He's a Stand-user NPC (17 NPCs; new camp on the east edge at 400, 130) and a bounty-board target.
- The time stop works like Diego (AU)'s: frozen characters get the `TimeStopped` attribute (CombatAdapter.canAct refuses them) and their root is anchored.
