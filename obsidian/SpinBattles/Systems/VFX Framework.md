---
tags: [system, vfx]
updated: 2026-11-22
---
# VFX Framework
`VFXLib` (primitives, scheduler, budget) → `TuskVFX` (character-level effects) → per-Act choreography.
TuskVFX: `CreateSpinRing`, `CreateMagicCircle`, `CreateEnergyCharge`, `CreateNailProjectile`, `CreateRotationalShockwave`, `CreateWormhole`, `CreateGoldenAura`, `CreateDistortion`, `CreateImpact`, `CreateTuskTransformation`, `CleanupEffect`.
- One RenderStepped scheduler drives all animation
- Effect budget per quality (12 / 24 / 40 active)
- Nails and Steel Balls are pooled
- Low / Medium / High: particles, ring segments, afterimages, screen effects, impact frames, lights
