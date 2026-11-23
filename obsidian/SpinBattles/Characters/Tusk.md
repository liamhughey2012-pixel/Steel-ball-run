---
tags: [character, tusk]
updated: 2026-11-22
---
# Tusk
Four Acts, each with its own Stand, M1, three abilities and an ultimate. Shared: the ultimate meter (fills from damage dealt), [[Tusk Sneak]], the Act menu (**T**) and the HUD.

| Act | Identity | Status |
|---|---|---|
| [[Tusk Act 1]] | the beginning of Spin: nails, cyan energy | 🧪 built, needs Studio test |
| [[Tusk Act 2]] | wormhole combat | 🧪 built |
| [[Tusk Act 3]] | spatial movement mastery | 🧪 built |
| [[Tusk Act 4]] | Infinite Rotation: gold + deep blue | 🧪 built |

## Controls
PC: M1 click (hold to keep attacking) · 1 / 2 / 3 abilities · G ultimate · C sneak · T Act menu
Controller: RB · X / Y / B · D-pad up · LB · D-pad down
Mobile: tap the move cards, the ULT card and the SNEAK chip; on-screen M1 button. See [[Move HUD]].

## Progression
**Awaken mode (default):** everyone starts as Act 1. Each **ultimate awakens Tusk to the next Act** (1→2→3→4) with a new Stand and new moves. Dying resets to Act 1. Act 4's ultimate is the final Infinite Rotation.

`TuskConfig.Progression.Mode`
- `"Menu"`: pick any implemented Act
- `"Unlock"`: point `IsUnlocked(player, act)` at your quest/progression system

## Code
Server: `TuskService` (router, state, cooldowns, ult meter) → `TuskActs/TuskActN`
Client: `TuskController` (input) → `TuskActVFX/ActN` (choreography), `TuskStand`, `TuskAnimation`, `TuskUI`

## Johnny's animations (procedural)
M1: right flick → left flick → finger-gun shot → overhead slam. Nail Shot: finger gun with recoil. Barrage: rapid alternating flicks. Underground Pursuit / Sneak Attack: dive into the ground. Nail Dimension: arms spread. Dimensional Step: lunge. Spatial Pursuit: sweep. Dimensional Break: crouch then two-hand push. Golden Spin Nail: spin wind-up. Golden Pursuit: dash punch.
Real uploaded animations can replace any of these in `TuskConfig.AnimationIds`.

## Blocky look
The Stands are blocky but keep the round shapes that make them Tusk (`SpinShared.Blockify`):
- signature round pieces stay smooth: Act 1's pink egg body and face (eyes, lids, beak pin, hearts), Act 2's ball body, head and ear discs, Act 3's dome body, shoulder balls and belly lens, Act 4's helmet
- other big round pieces become stepped "voxel-round" shapes (a core box + crossing boxes)
- small pieces become single boxes, rods become square rods
Turn blocky off with `TuskConfig.BlockyModels = false`. Custom Stand models from SpinAssets are never changed.
![[blocky_models_preview.png]]

## Pink energy aura
Every Act's Stand glows with a pink Spin aura: a pulsing pink glow and outline, soft pink energy rising off the whole model, pink sparks and a pink light. It hides while Tusk is burrowed and follows the VFX quality setting (`TuskStand`).

## Mostly blocky (2026-11-23)
Every Act (and Gyro's Ball Breaker) is now mostly blocky: every round piece becomes a box or a stepped voxel-round shape; only the eyes stay round.
![[stands_mostly_blocky.png]]

## Curves back (2026-11-23)
Each Act keeps its signature curved pieces smooth again (Act 1's egg body, face and hearts; Act 2's ear discs and drum; Act 3's round body and shoulder ball; Act 4's helmet and chest); everything else stays blocky.
![[tusk_acts_signature_round.png]]
![[tusk_act1_vs_drawing_v2.png]]

**Using a Toolbox model instead:** Studio › Toolbox › find a Tusk model › drag it into ReplicatedStorage › put it in a Folder named `SpinAssets` › rename it `TuskAct1` (or 2, 3, 4). The game uses it instead of the built-in Stand, strips any scripts inside it, and still adds the pink aura.
