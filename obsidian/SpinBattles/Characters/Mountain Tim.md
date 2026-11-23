---
tags: [character, mountaintim]
status: built
updated: 2026-11-23
---
# Mountain Tim: Oh! Lonesome Me
Pick him from the character dropdown (MOUNTAIN TIM). Numbers: `TuskConfig.MountainTim`.
Server moves: `TuskActs/MountainTim`. Visuals: `TuskActVFX/MountainTimVFX`. Look: `MountainTimOutfit`. Scripts: `MountainTim_Server` + `MountainTim_Client`.
Built from the character's description (no reference images yet). Send pictures to refine his look.

![[mountain_tim_outfit_preview.png]]
*(stand-in render on a test avatar)*

**Look** (blocky): tall brown cowboy hat with a wide brim and a dark band, red bandana, open leather vest, belt with a gold buckle, a coiled lasso at his right hip, leather chaps, dark boots with silver spurs.

**Oh! Lonesome Me:** his body splits into pieces that slide along his lasso rope.

| Input | Move | What it does |
|---|---|---|
| M1 | LASSO COMBO | jab, jab, a curving rope whip that cracks, then a lasso that drops and snaps shut (slam finisher) |
| 1 | LASSO SNARE | the loop whirls overhead and flies (60 studs). A catch cinches the loop round them and **splits their body apart along the rope** (0.9 s, half speed for 1.6 s) while it drags them in (6). 7 s |
| 2 | SPLIT DODGE | he bursts into pieces on a ring of rope for 0.6 s. **Attacked in that window: the hit is cancelled, his pieces zip along a rope to behind the attacker and he reforms with a rope slam (9, stun, knock-up).** Not attacked: the pieces slide 30 studs forward along the rope, slicing through enemies (6). 8 s |
| 3 | SPLIT BARRAGE | his arm comes apart along the rope (shoulder, forearm, fist) and jabs down a 26-stud line 5 times; the last punch (5) hooks them and **reels them back** to him. 7 s |
| G | LONESOME ROUNDUP | a giant lasso spins overhead while a rope ring tightens on the ground; ropes shoot to everyone within 24 studs and **split them apart**, his pieces ride the ropes in (4 hits of 3), then the rope drags them together and slams (12, launches) |

**Models:** a braided rope (twisted two-tone segments) that sags under its weight, a thick lasso loop with a honda knot and a tail, and body pieces that are real copies of the character's own parts (his hat rides on his head piece).
![[mountain_tim_rope_preview.png]]

- Also a Stand-user NPC and a bounty-board target ("STAND: OH! LONESOME ME").
