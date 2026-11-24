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
**Wonder of U:** a tall old man in a long maroon suit and a dark red bowler hat. His face is a ribbed mask (maroon and purple bands) with yellow slats and one glowing red eye. A long yellow knit scarf, two red sunflower brooches with gold petals, maroon gloves, brown shoes, and a cane in his right hand. He floats behind Tooru with a dark red aura.

**The idea: calamity.** Whoever pursues him is struck by misfortune: things fall out of the sky on them (a steel girder, a flowerpot, a road sign, a tree branch). A shadow always shows first and the thing takes 0.3 s to land, so you can dodge it.

| Input | Move | What it does |
|---|---|---|
| M1 | WONDER OF U COMBO | the old man swings his cane; the 4th hit launches |
| 1 | CALAMITY: DEBRIS | a shadow follows the nearest enemy in front (70 studs) for 0.55 s, then stops and turns red; 0.4 s later something falls on it (10, stun). Move and it misses. 7 s |
| 2 | THE PURSUER'S CURSE | up to 4 enemies in front (45 studs) are cursed for 6 s (a red spiral over their heads). **Every time one moves toward him**, something falls where they're heading (4, stun), at most every 0.9 s. Back off and nothing happens. Nobody cursed: most of the cooldown back. 13 s |
| 3 | WONDER OF U | the old man fades in right beside the nearest enemy (50 studs, line of sight) and sweeps his cane through their legs (8, stun, small launch), then fades away. 10 s |
| G | THE FLOW OF CALAMITY | "WONDER OF U"; he throws his arms open, the stand looms up behind him. For **7 s nobody can hit him**: any attack that would land is cancelled and the attacker is struck by calamity instead (6, stun, at most every 0.8 s each). Anyone within 45 studs who moves toward him has debris dropped on them (7, stun, every 1.2 s). Nearby players' screens go sepia and leaves fall all round him; a maroon ring shows his reach |

- **Corpse move (V): UNAVOIDABLE CALAMITY.** A shadow appears under everyone within 24 studs and 0.6 s later something falls on each of them (8, stun).
- He's also a Stand-user NPC (13 NPCs now; new camp in the far south-west) and a bounty-board target.
- **How it works:** the curse is the `CalamityCurseUntil` attribute; "pursuing" means moving toward him faster than 5 studs/s (4 in the ultimate). The ultimate's guard is `CombatAdapter.DodgeHandlers.CalamityGuard` plus the `CalamityGuard` attribute; it's removed when the ultimate ends or he dies. Falling debris hits from body height above the spot.
