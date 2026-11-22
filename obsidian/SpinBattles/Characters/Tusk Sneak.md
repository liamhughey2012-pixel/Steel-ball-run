---
tags: [character, tusk, sneak]
status: built
updated: 2026-11-22
---
# Tusk Sneak
Works in every Act. **C** toggles sneak (or tap the SNEAK chip).
- Crouch pose, 45% walk speed, lowered camera, blue screen edges, blue ground particles and ripples
- Lasts up to 8 s, then a 4 s cooldown. Getting hit breaks it.

## Sneak Attack (M1 while sneaking)
1. Tusk sinks underground (invisible and untargetable for 0.7 s); an underground ripple travels toward the target
2. **Warning**: a portal plus a red ring appear under the target 0.45 s before emergence, with an alert sound
3. Emerges behind the target at a server-checked safe spot (line of sight, ground, no walls)
4. 12 dmg + launch, finished with a blue shockwave

Counterplay: move 14+ studs during the warning and it misses. 12 s cooldown (2 s if no target).
Code: `TuskSneakService` (server) · `TuskSneakController` (client)
