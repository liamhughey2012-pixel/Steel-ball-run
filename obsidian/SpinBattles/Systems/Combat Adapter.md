---
tags: [system]
updated: 2026-11-22
---
# Combat Adapter
`ServerScriptService.SpinServer.CombatAdapter`: the **only** place damage, stun, block and knockback happen.
- `Hooks.ApplyDamage / ApplyStun / IsBlocking / CanAct / CanBeHit`: plug in your own combat system
- Attributes: `Blocking`, `IFrames`, `Armored`, `Stunned`
- Safety caps: MaxKnockback 90, MaxStun 1.0, stun immunity 0.5 s after a stun ends
