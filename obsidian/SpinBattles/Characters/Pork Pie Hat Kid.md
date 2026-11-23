---
tags: [character, porkpie]
status: built
updated: 2026-11-23
---
# Pork Pie Hat Kid: Wired
Pick him from the character dropdown (top-left card ▼ → PORK PIE HAT KID → SELECT). Numbers: `TuskConfig.PorkPie`.
Server moves: `TuskActs/PorkPieHatKid`. Visuals: `TuskActVFX/PorkPie`. Look: `PorkPieOutfit`. Scripts: `PorkPie_Server` + `PorkPie_Client`.

![[porkpie_outfit_preview.png]]
*(stand-in render on a test avatar with a red shirt: the shirt is covered by the suit and bare arms)*

**Look** (`PorkPieOutfit`, everyone sees it, blocky, from the owner's pictures): green bamboo sticks tied round his head with a rope band (sticking up and hanging down the sides), big eyes with large black irises, bared teeth and a big jaw, bare arms, a green sleeveless suit with light-green studs down both sides of the chest and both legs, golden feathers on the shoulders, a short frilly tutu, big brown bracelets with leaves on both wrists. The player's own hats, hair and face are hidden while playing him.

**Wired:** two blocky fish hooks (barbed J hook, ring eye, feather bait) on steel cables that come out of his **mouth**, wound on a cable drum (the winch) that spins in front of his face while he reels.
![[wired_hook_winch_preview.png]]
*(the winch drum and a hook with its feather bait)*

| Input | Move | What it does |
|---|---|---|
| M1 | HOOK COMBO | slap, slap, a hook lashing out of his mouth, flying kick (area finisher) |
| 1 | WIRED HOOK | a hook shoots out of his mouth (75 studs). A hit snags the enemy (6, 1 s stun) and the winch reels them in to him. A miss whips the hook back. 7 s cooldown |
| 2 | BAIT PAN | puts a frying pan of water with a feather bait 10 studs in front. The first enemies (up to 2) to come within 7 studs get hooked out of the water, hoisted up (8) and yanked back down (4). Waits 10 s; one pan at a time. 12 s cooldown |
| 3 | DOUBLE HOOK LIFT | both hooks snag up to 2 enemies in front (22 studs), hoist them high like lifting a horse (6), then slam them down (7). 10 s cooldown, 3 s on a miss |
| G | WIRED WINCH | 6 puddles of water appear around him, hooks erupt from them and snag everyone within 24 studs (6), the cables swing over to his mouth and the winch reels everyone in through the air (1.5 ticks), then a big slam (14) |

- He stands in a crouched, twitchy kid stance while equipped.
- HUD: the Bait Pan card shows "BAITED 7s" while a pan is waiting.
- Hit sparks are bamboo green.
