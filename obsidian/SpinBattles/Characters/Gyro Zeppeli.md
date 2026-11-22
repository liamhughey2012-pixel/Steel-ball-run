---
tags: [character, gyro]
status: built
updated: 2026-11-22
---
# Gyro Zeppeli: Steel Ball master
Pick him from the character dropdown (top-left card ▼ → GYRO ZEPPELI → SELECT). Numbers: `TuskConfig.Gyro`.
He always holds the green Steel Ball, spinning in his right hand.

**Look** (`GyroOutfit`, everyone sees it): your own clothes stay on. Gyro gets his **hat** from the owner's pictures (tan, wide brim with slots cut all round, slits round the crown, domed top, two big ridged silver goggles on a dark strap) and long blond hair. Your own hats and hair are hidden while you play Gyro.

| Input | Move | What it does |
|---|---|---|
| M1 ×4 | STEEL BALL COMBO | jab, hook, kick, then a spinning-ball smash that hits everyone close |
| 1 | STEEL BALL THROW | the ball flies out, then spins back to his hand; it can hit again on the way back |
| 2 | SPIN TORNADO | bowls the ball along the ground: a green tornado travels forward for 2.2 s, sucking enemies in and juggling them, then bursts (stops at walls) |
| 3 | SPIN VIBRATION | presses the spinning ball into the enemy in front: long paralysis stun and a small launch |
| G | BALL BREAKER | charge: the Golden Rectangle (nested golden-ratio squares + spiral) forms in front of Gyro, 3 rings spin up round the ball · shot: giant ball trailing a spinning spiral · vortex: a ghostly skeletal Ball Breaker spirit rises and spins, rings shrink inward, dust swirls in · burst: green energy pillar, the spirit shatters, layered shockwaves |

- No Tusk Sneak and no Acts: Gyro is one form, and dying keeps you as Gyro.
- Code: server `TuskActs/GyroZeppeli`, client `TuskActVFX/Gyro` (registered internally as "Act 5").

Status: 🧪 built, not yet tested in Studio.

## Animations (procedural, whole-body)
Idle: ball held up at the chest, spinning. M1: jab → hook → front kick → overhead ball smash. Throw: baseball pitch with a leg lift. Tornado: underhand bowl. Spin Vibration: palm press. Ball Breaker: swaying wind-up, then the big pitch.

## Spin Vibration visuals
Wind-up: three tight green rings and a charge gathering on the ball in his hand. Hit: flash, starburst, a golden spiral pressed into the air (plus a Golden Rectangle on a hit), jittering zigzag "vibration" lines, four ripples pushed forward, heat haze; on a hit the ground cracks and sparks fly. Camera shake and a small FOV punch for Gyro.
