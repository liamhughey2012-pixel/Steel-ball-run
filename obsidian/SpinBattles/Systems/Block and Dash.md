---
tags: [system, combat]
updated: 2026-11-23
---
# Block and Dash
Every character (and the Stand-user NPCs). Server: `DefenseService` + `CombatAdapter`. Client: `DefenseClient`, HUD in `CombatUI`. Numbers: `TuskConfig.Defense`. Keys: `TuskConfig.Keys.Block` / `.Dash`.

| Input | What it does |
|---|---|
| **Hold F** (controller L2, mobile BLOCK button) | Block: guard pose with a blue shield. Hits from the front do 35% damage, no stun, less knockback. You walk at 45% speed. Attacking or dashing drops the block; getting stunned knocks you out of it |
| **Q** (controller R2, mobile DASH button) | Dash ~15 studs the way you're moving (forward if standing still), can't be hit for 0.2 s. 2.2 s cooldown |

- **Guard bar:** shows under your character. Each blocked hit drains it (4 per point of damage); it refills 30/s after 1.2 s without a blocked hit. The shield turns red as it runs low.
- **Guard break:** when the bar runs out, the hit goes through, you're stunned for 1 s and can't block for 3 s ("GUARD BREAK").
- **Perfect block:** start blocking within 0.22 s before a hit lands: no damage, the attacker is stunned for 1 s and knocked back ("PERFECT!"). Doesn't work if you re-pressed block less than 0.6 s after letting go (no spamming).
- **Hits from behind** aren't blocked.
- The HUD shows DASH (with its cooldown) and BLOCK chips at the bottom right.
- NPCs block now and then when you're close, dash in to close the gap, and dash away when they're hurt.

## Block upgrade (2026-11-24)
![[block_shield_preview.png]]
- **Animations:**
  - **BlockRaise:** a snap brace into the guard;
  - **BlockHit:** a recoil every time a hit is blocked (arms knocked back, body leaning away);
  - **BlockWeak:** a sagging, shaky low guard while the guard bar is under 35% (with its own **BlockHitWeak** recoil);
  - it stands back up when the guard refills.
- **The shield:** a curved barrier of 5×4 glowing tiles with bright rims, in the **character's own colour** (their palette).
  - It builds in from the middle and shimmers.
  - As the guard drains, tiles fail from the edges in: they turn red, jitter and flicker out.
  - **On release** the tiles scatter and fade.
- **Blocked hit:** the tile it struck lights up white, a ripple runs across the tiles, sparks fly off forward, a small ring and a "tink" sound play, and the blocker's camera nudges.
- **Perfect block:** the whole barrier flashes gold (on top of the PERFECT! effects).
- **Guard break:** the tiles shatter, turn red-hot and fly off with gravity.
