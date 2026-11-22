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
Mobile: tap the HUD slots, the ultimate bar and the SNEAK chip; on-screen M1 button

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
