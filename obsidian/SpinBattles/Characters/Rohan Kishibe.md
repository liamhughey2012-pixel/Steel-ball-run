---
tags: [character, rohan, heavens-door]
status: built
updated: 2026-11-27
---
# ROHAN KISHIBE (HEAVEN'S DOOR)
A visitor from another world (Part 4). He's last in the character list. Numbers: `TuskConfig.Rohan`. Act 28.
Server moves: `TuskActs/Rohan`. Outfit: `RohanOutfit`. Visuals: `TuskActVFX/RohanVFX`. Stand model: `TuskActVFX/HeavensDoorStand`. Scripts: `Rohan_Server` + `Rohan_Client`.
Built from memory of the anime; the user sent no reference images.

![[rohan_heavens_door_preview.png]]
**Rohan:**
- Dark green hair under a headband with a zigzag, pen-nib top edge, and gold pen-nib earrings.
- A short cropped light jacket with a high collar and buttons, over a bare midriff (coloured to match the avatar's skin).
- Dark green trousers with a wide belt, brown shoes, and his G-pen in his right hand.
- He poses with the pen raised by his face.

**Heaven's Door:**
- Small, floating at his shoulder: a boyish manga hero.
- A top hat with a gold band and a feather, a green cape, a cream vest with a pink bow, puffy shorts and tall boots.
- An open book floating at its side.

| Input | Move | What it does |
|---|---|---|
| M1 | PEN & PAGE COMBO | swipes with ink flicking off the pen; the 4th hit launches |
| 1 | HEAVEN'S DOOR | the nearest enemy in front becomes a **book**: their face peels open into pages, and they're stuck 1.8 s (6 damage, can't be blocked). Then he can write in them for 7 s (a little 📖 over their head). A miss costs 3 s; otherwise 10 s |
| 2 | WRITE: "YOU CAN'T ATTACK KISHIBE ROHAN" | in the nearest open book (within 40 studs): for 7 s their hits on him do nothing ("...!?"), and their abilities are blank for 2 s. 12 s |
| 3 | WRITE: "FLY BACKWARDS AT 70 KM/H" | in the nearest open book (or straight into someone right in front): they're hurled away backwards (9 damage, can't be blocked). 9 s |
| G | EVERYONE IS A BOOK | everyone within 30 studs becomes a book at once (10 damage, stuck 3 s), with "YOU CAN'T ATTACK KISHIBE ROHAN" written in all of them for 6 s more |
| Corpse | OPEN BOOK | everyone round him flaps open for a moment |

The can't-attack rule: Rohan's character has `RohanToken`; a written target gets `CantAttack` = that token plus `CantAttackUntil`. `CombatAdapter.dealHit` refuses their hits on him.
