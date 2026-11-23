---
tags: [character, axl]
status: built
updated: 2026-11-23
---
# Axl RO: Civil War
Pick him from the character dropdown (AXL RO). Numbers: `TuskConfig.Axl`.
Server moves: `TuskActs/Axl`. Visuals: `TuskActVFX/AxlVFX`. Stand model: `TuskActVFX/CivilWarStand`. Look: `AxlOutfit`. Scripts: `Axl_Server` + `Axl_Client`.

## Civil War (the Stand), matched to the user's reference art
![[civil_war_preview.png]]
- **Head:** a distorted metal mask of tall vertical silver discs pressed together, a spike on top with cross bars, and three arrow points tapering down below it.
- **Neck:** three gas-mask filter canisters round its base (front and both sides).
- **Body:** a red quilted (tufted) chest with brass tufts, and a quilted hump on the back.
- **Limbs:** silver shoulder balls; long yellow arms and thighs with purple joint rings.
- **Spine:** bare silver vertebrae down to a toothed silver pelvis.
- **Legs:** red, fraying bell-bottom lower legs like roots, and pointed red feet.
- It floats behind him with a **crimson aura** (players and NPCs) and strikes with his moves.

## Axl RO (matched to the user's reference art, 2026-11-23)
![[axl_ro_preview.png]]
- **Head:** an olive military helmet covered in a dark net, with chin straps hanging; a cream hood lining framing his face, and short brown hair at the back.
- **Face:** the dotted band across his eyes.
- **Body:** a khaki hooded parka, with the hood bunched round his neck and shoulders.
- **Chest:** a yellow chest plate with gold buttons along its edges, and a V of gold scales hanging down the front.
- **Arms:** black clips down the outside of both sleeves.
- **Legs:** khaki trousers and dark boots.

## Moves (reworked 2026-11-23: built around GUILT)
**Passive: GUILT.** Every hit he lands (M1, specters, junk) marks the target with guilt: up to 5 stacks, shown as crimson marks above their head, fading 8 s after the last. His moves feed on it.

| Input | Move | What it does |
|---|---|---|
| M1 | GUILT COMBO | jab, jab, kick, summoning point; Civil War strikes with each. +1 guilt a hit |
| 1 | GUILT SPECTERS | ghosts rise from his shadow and **hunt** the nearest enemy (45 studs, any direction), chasing at 24 studs/s for 3 s, grabbing on contact (5, launch, +1 guilt). **1 specter, +1 per 2 guilt on them (max 3).** A dash can shake them. 8 s |
| 2 | ABANDONED JUNK | a fan of 6 pieces of junk (2.5 each, max 3 per enemy). What hits **sticks to their body** for 4 s: each piece slows them 10% more and adds guilt. 7 s |
| 3 | GUILT MEMBRANE | wraps the nearest enemy in front (16 studs): 4, slowed to 50%, squeezed harder each tick, then crushed. It **uses up their guilt**: +15% squeeze damage per stack; at 5 guilt they're **flattened** (long stun, launch). The victim's own screen darkens and their guilt whispers at them. In the rain it lasts half as long. 13 s |
| G | CIVIL WAR | junk piles and 7 specters rise in a ring (20 studs): everyone inside is grabbed (4), **loaded with 3 guilt**, wrapped (1.5 every 0.5 s), then crushed (10, boosted by their guilt, launches). While it lasts the first hit on him makes Civil War break apart (the hit misses, he reforms 9 studs away). Shorter in the rain |

**How to play him:** M1 or junk to stack guilt, then specters (more of them) or membrane (harder squeeze, flatten at 5). Rain is bad for him.

- He's also a Stand-user NPC and a bounty-board target ("STAND: CIVIL WAR").
