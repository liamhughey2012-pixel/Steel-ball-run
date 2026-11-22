---
tags: [system]
updated: 2026-11-22
---
# Projectiles
`ProjectileService` simulates every projectile on the server (spherecast per frame, point-blank overlap check, per-player cap of 12). Clients draw the visuals from `ProjectileSpawn` / `ProjectileEnd` events on SpinFX, timed with server time.
Kinds: `SteelBall` ([[Golden Spin]]), `TuskNail` ([[Tusk Act 1]]).
