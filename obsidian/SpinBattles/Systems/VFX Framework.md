---
tags: [system, vfx]
updated: 2026-11-22
---
# VFX Framework
`VFXLib` (primitives, scheduler, budget) → `TuskVFX` (character-level effects) → per-Act choreography.
TuskVFX: `CreateSpinRing`, `CreateMagicCircle`, `CreateEnergyCharge`, `CreateNailProjectile`, `CreateRotationalShockwave`, `CreateWormhole`, `CreateGoldenAura`, `CreateDistortion`, `CreateImpact`, `CreateTuskTransformation`, `CreateImpactStar`, `CreateGroundCracks`, `CreateEnergyPillar`, `CreateCrescent`, `ScreenTint`, `IsNear`, `CleanupEffect`.
- One RenderStepped scheduler drives all animation
- Effect budget per quality (12 / 24 / 40 active)
- Nails and Steel Balls are pooled
- Low / Medium / High: particles, ring segments, afterimages, screen effects, impact frames, lights

## Finger whirls: Johnny's nail shot start-up (2026-11-26)
From the art: before a nail shot, Johnny brings his right hand up in front of him with his fingers pointing up (pose `NailRaise`). Blue whirls (three rings of different sizes, spinning opposite ways, wobbling and pulsing, with a glow at the tip) turn around his fingertips and follow his hand. Then he levels the hand (`FingerGun`) and fires, and the whirls shoot out along the shot, spreading and fading.
- `Common.fingerWhirl(character, duration, opts)` returns a handle; `:Release(direction)` sends the rings flying. It cleans itself up if nobody releases it. `Common.fingertips(character)` gives the tip CFrame, with its UpVector along the fingers.
- **Used by:**
  - Act 1 NAIL SHOT (start-up 0.35 s);
  - Act 1 NAIL BARRAGE (0.3 s, then a small whirl puff with every nail);
  - Act 2 WORMHOLE NAIL (0.35 s, then the golden rectangle);
  - Act 4 GOLDEN SPIN NAIL (0.4 s, gold-and-blue whirls).
- Those start-ups were lengthened so the raise reads. The server waits the same time before firing (`TuskConfig` Startup values).

![[johnny_nail_raise.png]]
