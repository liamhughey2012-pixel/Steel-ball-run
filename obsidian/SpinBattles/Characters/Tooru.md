---
tags: [character, tooru]
status: built
updated: 2026-11-24
---
# Tooru (JoJolion): WONDER OF U
Tooru from Part 8. Pick him from the character dropdown (TOORU). Numbers: `TuskConfig.Tooru`. Act 16.
Server moves: `TuskActs/Tooru`. Visuals: `TuskActVFX/TooruVFX`. Stand model: `TuskActVFX/WonderOfUStand`. Look: `TooruOutfit`. Scripts: `Tooru_Server` + `Tooru_Client`.
Matched to the reference art the user sent (2026-11-24).

![[tooru_preview.png]]
**Look:** a big round black hat with a blue spiral on each side of the front, dark slate hair, green lipstick, a purple jacket with dark plaid sleeves, black front panels either side of a purple zip, a grey hood round his neck, the yellow sun-spiral "S" with orange rays on his chest, a teddy bear clinging to each shoulder, a yellow belt, gold patterned trousers and blue shoes. He stands loose, head tilted.

![[wonder_of_u_preview.png]]
**Wonder of U** (remodelled from the user's second set of art): a tall old man in a fitted maroon suit. A bowler hat with a pale band and a curled brim; a round ribbed dark-red head with little pegs out of each side; two long gold plates down the face, each with a round pink eye in a gold sunburst at the top. A yellow dotted knit scarf knotted at the throat, one end down his chest and the other over his right shoulder. Red sunflower brooches either side of the waist, purple hands with red nails, ribbed red bracelets, and a thin red cane with a crook handle. He floats behind Tooru with a dark red aura.

**The idea: calamity.** Whoever pursues him is struck by misfortune: things fall out of the sky on them (a steel girder, a flowerpot, a road sign, a tree branch). A shadow always shows first and the thing takes 0.3 s to land, so you can dodge it.

| Input | Move | What it does |
|---|---|---|
| Passive | CALAMITY | anyone 6–32 studs away **running at him** (closing in faster than 11 studs/s) has something fall where they're heading (3, short stun), at most every 5 s each. Walk up slowly, or dodge the shadow |
| M1 | WONDER OF U COMBO | the old man swings his cane; the 4th hit launches. **Hits on a cursed enemy bring something down on them too** (3, at most every 1.2 s) |
| 1 | CALAMITY: DEBRIS | **three shadows in a row** (0.45 s apart) chase the nearest enemy in front (70 studs); each follows for 0.55 s, stops and turns red, and 0.4 s later something falls on it (5, 5, then a **big one**: 9, launch). Keep moving and they miss. 8 s |
| 2 | THE PURSUER'S CURSE | up to 4 enemies in front (45 studs) are cursed for 6 s (a red spiral over their heads) and **walk at 80%**. Every time one **moves toward him**, something falls where they're heading (4, stun), at most every 0.9 s. Back off and nothing happens. Nobody cursed: most of the cooldown back. 13 s |
| 3 | WONDER OF U | the old man fades in right beside the nearest enemy (50 studs, line of sight) and sweeps his cane through their legs (8, stun, small launch). **Press 3 again within 2.5 s to SWAP**: Tooru vanishes and steps out where the old man stood, untouchable for 0.35 s ("PRESS 3 AGAIN" shows on his screen). 10 s |
| G | THE FLOW OF CALAMITY | "WONDER OF U"; he throws his arms open, the stand looms up behind him. For **7 s nobody can hit him**: any attack that would land is cancelled and the attacker is struck by calamity instead (6, stun, at most every 0.8 s each). Anyone within 45 studs who moves toward him has debris dropped on them (7, stun, every 1.2 s). Nearby screens go sepia, leaves fall, a maroon ring shows his reach. **When it ends: CALAMITY STORM**, a big red shadow under every enemy still within 45 studs and 0.7 s later a big one falls on each (12, launch) |

- **Corpse move (V): UNAVOIDABLE CALAMITY.** A shadow appears under everyone within 24 studs and 0.6 s later something falls on each of them (8, stun).
- He's also a Stand-user NPC (13 NPCs now; new camp in the far south-west) and a bounty-board target.
- **How it works:** the passive runs from `Tooru.Init` (TuskService now calls an `Init(S)` on any character module that has one, once at start). The curse is the `CalamityCurseUntil` attribute; "pursuing" means moving toward him faster than 5 studs/s (4 in the ultimate). The ultimate's guard is `CombatAdapter.DodgeHandlers.CalamityGuard` plus the `CalamityGuard` attribute; it's removed when the ultimate ends or he dies. Falling debris hits from body height above the spot.
