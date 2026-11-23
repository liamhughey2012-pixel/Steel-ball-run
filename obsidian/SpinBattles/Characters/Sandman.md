---
tags: [character, sandman]
status: built
updated: 2026-11-23
---
# Sandman (Soundman): In a Silent Way
Pick him from the character dropdown (top-left card ▼ → SANDMAN → SELECT). Numbers: `TuskConfig.Sandman`.
Server moves: `TuskActs/Sandman`. Visuals: `TuskActVFX/SandmanVFX`. Look: `SandmanOutfit`. Scripts: `Sandman_Server` + `Sandman_Client`.
Built from the character's description (no reference images yet). Send pictures to refine his look.

![[sandman_outfit_preview.png]]
*(stand-in render on a test avatar)*

**Look** (blocky): long straight black hair down his back with side locks, a red beaded headband with a feather, a sand-coloured scarf and sleeveless vest, bare arms, a red sash with a pouch, wrapped forearms and shins. He keeps the player's own face.

**In a Silent Way:** sounds become solid, written sound effects (blocky 3D words) that do what they say when touched.

| Input | Move | What it does |
|---|---|---|
| M1 | SOUND CUT COMBO | chop, chop, spinning kick, axe kick; each hit pops a written sound ("ZAN!", "ZASH!", "DOGO!", "DOGOOO!") |
| 1 | SOUND SLASH | a written "ZBAAK!" skims along the ground (65 studs) and cuts the first enemy (9). 6 s cooldown |
| 2 | SOUND TRAP | plants a written "DOGOOON" on the ground 12 studs ahead (up to 3, 15 s each). The first enemy within 5 studs sets it off (10, launches). Traps in the blast go off together: one hit, +2 each. 5 s cooldown |
| 3 | SAND RUN | sprints 38 studs straight through enemies (7 each) with a sand trail and "ZAZAZA". Can't be hit during the sprint. 7 s cooldown |
| G | SILENT SYMPHONY | sounds gather and orbit him, then 4 waves of written sounds rain down on the area in front (5 each), and a final "DOOOOM!!" explosion (14, launches) |

- Light runner's stance while equipped. Hit sparks are sand-gold.
