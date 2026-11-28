---
tags: [character, diavolo, king-crimson]
status: built
updated: 2026-11-28
---
# DIAVOLO (KING CRIMSON)
A visitor from another world (Part 5). He's last in the character list. Act 32. Numbers: `TuskConfig.Diavolo`.
Server moves: `TuskActs/Diavolo`. Outfit: `DiavoloOutfit`. Visuals: `TuskActVFX/DiavoloVFX`. Stand model: `TuskActVFX/KingCrimsonStand`. Scripts: `Diavolo_Server` + `Diavolo_Client`.
Matched to the five reference images the user sent (2026-11-28).

![[diavolo_king_crimson_preview.png]]
**Diavolo:**
- Long pink hair with dark spots, parted in the middle, falling past his shoulders in front and down his back.
- Bare skin under a black web-mesh top (rings round the chest, arcs across the ribs, a centre line), with dark swirling tattoos on his upper arms.
- Green wristbands and a green belt with a gold buckle.
- Purple trousers with gold buttons down each outer seam and split hems, and purple boots.
- The black strap with white rungs hanging from his left hip.
- He stands with a hand on his hip.

**King Crimson:**
- Big and muscular, crimson, with a white diamond lattice over the chest, back, arms and legs.
- Huge rounded silver shoulder pads, a dark grey V down the chest, a pale ribbed waist, and dark grey trunks with a rolled top.
- A crimson helmet with white lines round a pale grey face: angry green eyes, heavy brows, clenched teeth.
- **Epitaph:** a small pink face on its forehead.
- Pale grey hands with green nails, silver knee pads, and white-grey boots with a green band. A crimson aura.

| Input | Move | What it does |
|---|---|---|
| M1 | KING CRIMSON COMBO | crimson fists and a white chop; the 4th hit hammers them up |
| 1 | EPITAPH | 1.6 s of seeing the future (Epitaph glows pink; his screen gets a cracked crimson frame). If anyone hits him, the hit never lands: he's already behind them and King Crimson chops them (11 damage, can't be blocked, 1.2 s stun). 12 s |
| 2 | TIME ERASE | "KING CRIMSON!": the screen shatters into crimson shards. For 3 s nothing can touch him and he moves 45% faster, but he can't hit anything either. Everyone near sees the world go crimson while he all but vanishes into red afterimages; he sees everyone outlined in red. When time comes back, ONLY THE RESULT REMAINS: for 1.5 s his hits do ×1.5 and can't be blocked. 18 s |
| 3 | HEART PUNCH | King Crimson's fist punches straight through the nearest enemy in front (9 studs): 16 damage, then 4 bleeds of 2. A miss costs 3 s; otherwise 12 s |
| G | ONLY THE RESULT REMAINS | needs someone within 40 studs. A short close-up for you (King Crimson's face, Epitaph on its brow, Diavolo behind, crimson mist; toggle `TuskConfig.Cutscenes.KingCrimson`). Then time is erased: he's behind each of up to 4 enemies in turn, King Crimson chopping each one, and when time comes back every blow lands at once (18 each, can't be blocked). Nothing is spent if nobody's near |
| Corpse | TIME SKIP | he's suddenly 26 studs ahead, and everyone along the way is hit |

Time erase uses the character attributes `TimeEraseUntil` (iframes) and then `KCResultUntil` / `KCResultDamage`, which `CombatAdapter.dealHit` reads. Epitaph uses `CombatAdapter.DodgeHandlers.Epitaph`.
