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
