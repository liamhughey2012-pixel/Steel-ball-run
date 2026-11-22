---
tags: [character, gyro]
status: built
updated: 2026-11-22
---
# Gyro Zeppeli: Steel Ball master
Pick him from the character dropdown (top-left card ▼ → GYRO ZEPPELI → SELECT). Numbers: `TuskConfig.Gyro`.
He always holds the green Steel Ball, spinning in his right hand.

| Input | Move | What it does |
|---|---|---|
| M1 ×4 | STEEL BALL COMBO | jab, hook, kick, then a spinning-ball smash that hits everyone close |
| 1 | STEEL BALL THROW | the ball flies out, then spins back to his hand; it can hit again on the way back |
| 2 | SPIN TORNADO | bowls the ball along the ground: a green tornado travels forward for 2.2 s, sucking enemies in and juggling them, then bursts (stops at walls) |
| 3 | SPIN VIBRATION | presses the spinning ball into the enemy in front: long paralysis stun and a small launch |
| G | BALL BREAKER | green spiral build-up (armored), a giant ball, a spinning vortex that pulls enemies in for 2.4 s, then a big burst |

- No Tusk Sneak and no Acts: Gyro is one form, and dying keeps you as Gyro.
- Code: server `TuskActs/GyroZeppeli`, client `TuskActVFX/Gyro` (registered internally as "Act 5").

Status: 🧪 built, not yet tested in Studio.

## Animations (procedural)
Idle: ball held up at the chest, spinning. M1: jab → hook → front kick → overhead ball smash. Throw: baseball pitch with a leg lift. Tornado: underhand bowl. Spin Vibration: palm press. Ball Breaker: swaying wind-up, then the big pitch.
