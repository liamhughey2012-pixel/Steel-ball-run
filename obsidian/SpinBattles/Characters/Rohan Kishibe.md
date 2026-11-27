---
tags: [character, rohan, heavens-door]
status: built
updated: 2026-11-27
---
# ROHAN KISHIBE (HEAVEN'S DOOR)
A visitor from another world (Part 4). He's last in the character list. Numbers: `TuskConfig.Rohan`. Act 28.
Server moves: `TuskActs/Rohan`. Outfit: `RohanOutfit`. Visuals: `TuskActVFX/RohanVFX`. Stand model: `TuskActVFX/HeavensDoorStand`. Scripts: `Rohan_Server` + `Rohan_Client`.
Matched to the reference art the user sent (2026-11-27).

![[rohan_heavens_door_preview.png]]
**Rohan:**
- Dark green-black hair swept up into short spikes, under a lime-green headband with a zigzag top edge, and gold pen-nib earrings.
- A purple shirt with a high mandarin collar and full sleeves, and a long lime-green vest over it, buttoned, with gold pocket flaps, hanging over his hips.
- Purple trousers, and his slim pen in his right hand.
- He poses with the pen raised by his face.

**Heaven's Door:**
- Small, floating at his shoulder, all white and gold.
- A pale face with big green eyes and thin gold lines framing it like a mask.
- A white hat with a wide gold-edged brim and a tall crown made of a gold lattice.
- A long loose white coat with gold trim and big gold cuffs, white hands, and green-and-orange shoes.
- A gold aura.

| Input | Move | What it does |
|---|---|---|
| M1 | PEN & PAGE COMBO | swipes with ink flicking off the pen; the 4th hit launches |
| 1 | HEAVEN'S DOOR | the nearest enemy in front becomes a **book**: their face peels open into pages, and they're stuck 1.8 s (6 damage, can't be blocked). Then he can write in them for 7 s (a little 📖 over their head). A miss costs 3 s; otherwise 10 s |
| 2 | WRITE: "YOU CAN'T ATTACK KISHIBE ROHAN" | in the nearest open book (within 40 studs): for 7 s their hits on him do nothing ("...!?"), and their abilities are blank for 2 s. 12 s |
| 3 | WRITE: "FLY BACKWARDS AT 70 KM/H" | in the nearest open book (or straight into someone right in front): they're hurled away backwards (9 damage, can't be blocked). 9 s |
| G | EVERYONE IS A BOOK | everyone within 30 studs becomes a book at once (10 damage, stuck 3 s), with "YOU CAN'T ATTACK KISHIBE ROHAN" written in all of them for 6 s more |
| Corpse | OPEN BOOK | everyone round him flaps open for a moment |

The can't-attack rule: Rohan's character has `RohanToken`; a written target gets `CantAttack` = that token plus `CantAttackUntil`. `CombatAdapter.dealHit` refuses their hits on him.
