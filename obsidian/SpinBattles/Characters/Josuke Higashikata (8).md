---
tags: [character, josuke]
status: built
updated: 2026-11-24
---
# Josuke Higashikata (JoJolion): SOFT & WET
Josuke from Part 8. Pick him from the character dropdown. Numbers: `TuskConfig.Josuke`. Act 15.
Server moves: `TuskActs/Josuke`. Visuals: `TuskActVFX/JosukeVFX`. Stand model: `TuskActVFX/SoftAndWetStand`. Look: `JosukeOutfit`. Scripts: `Josuke_Server` + `Josuke_Client`.
Matched to the reference art the user sent (2026-11-24).

![[josuke_preview.png]]
**Look:** a white sailor cap with navy stripes and a gold capsule, dark curly hair, a cropped white sailor top with a striped collar and cuffs, a green neckerchief with a pink ring, a teal anchor patch, an orange badge with a green star, a light-blue belt with a gold buckle, white trousers, and the star birthmark on his neck. He stands relaxed with his hands behind his head.

![[soft_and_wet_preview.png]]
**Soft & Wet** (remodelled from the user's second set of art): glossy icy white-teal and slim like a jointed doll. A tall capsule head with a narrow chin, a striped purple line down the face, round slit eyes and a horn out of each side (a yellow star on one tip). A big heart-shaped chest with the ring and anchor/trident emblem (two arms curving up to arrowheads). Purple ball joints, green springs at elbows, wrists and knees, pointed fins on shoulders and hips, a maroon waist with a blue band, blue shoes with lime soles, and star bubbles floating round it.

| Input | Move | What it does |
|---|---|---|
| M1 | SOFT & WET COMBO | jab, jab, kick, then a flick that **launches** them |
| 1 | PLUNDER: FRICTION | a pale-blue bubble (5, shove). It **steals their friction** for 3.5 s: they slide like on ice and can barely steer. 8 s |
| 2 | PLUNDER: SIGHT | a violet bubble (4). It **steals their sight** for 3 s: a player's screen goes nearly black; an NPC loses track of him. 14 s |
| 3 | BUBBLE MINES | 6 bubbles drift out round him and bob there for 8 s. An enemy who touches one pops it (6, stun, knockback). 12 s |
| G | GO BEYOND | he charges (armored) for 1 s, then fires a tiny bubble spinning infinitely, rings whirling round it: slow, but **can't be blocked**, 30 damage, launch |

- **Corpse move (V): PLUNDER: SOUND.** Steals the sound round him (20 studs): enemies take 5 and are **silenced** for 3.5 s (no abilities or ultimate).
- He's also a Stand-user NPC and a bounty-board target.
- **How it works:** the friction steal sets `NoFrictionUntil` / `NoFrictionGrip`. A `LinearVelocity` called `JosukeSlide` takes over from walking (on the server for NPCs, on the victim's own client for players) and only turns towards where they want to go at the stolen grip. Sight sets `BlindUntil`; silence sets `SilencedUntil`. Bubbles are server projectiles (Kind `PlunderBubble`), so time stops freeze them too.
