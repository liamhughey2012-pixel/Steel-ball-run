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

## Steel Ball Throw bounces
The ball bounces off walls up to **3** times (`TuskConfig.Gyro.SteelBallThrow.MaxBounces`), keeping the range it has left and coming off each bounce 8% faster. Bank shots hit harder: +2 damage per bounce (`BounceBonusDamage`). Each enemy is hit once per throw. After the last bounce (or when it hits someone or runs out of range) it spins back to Gyro's hand. Bounce visuals: a ring flat on the wall, starburst, sparks along the new direction and a "BOUNCE x2" popup.

## Stand: Ball Breaker
Gyro's Stand is **Ball Breaker** (character card and dropdown say so; not "Steel Balls"). In his ultimate, Ball Breaker rises out of the vortex as in the owner's picture: a green ribbed figure with long arms and legs, a flat round lid head, pink bulbs all over and gold lightning crackling around it, then shatters into green, pink and gold sparks.
![[ball_breaker_vs_picture.png]]

## With the Saint's Corpse EYES (Act 29)
While Gyro holds the corpse's **Eyes**, he puts them to use: one sits in his face just under his right eye (white eyeball, brown iris, stitched socket), and the other is set into his steel ball. His moves change; when he loses the Eyes or goes down, he's back to Act 5. Numbers: `TuskConfig.GyroEyes`. Server: `TuskActs/GyroEyes`, which also watches for the switch. Visuals: `TuskActVFX/GyroEyesVFX`. Both are in Gyro's pack.

| Input | Move | What it does |
|---|---|---|
| M1 | STEEL BALL COMBO | as ever |
| 1 | SCAN SHOT | the eye-ball sees its target and curves after it (the nearest enemy in front, up to 110 studs). 11 damage, and they're revealed to him for 6 s. 7 s |
| 2 | SCAN | every enemy within 130 studs is revealed to him through walls (green glow, an eye over their head) for 8 s, and his hits on them do +20%. **Vibration lines** ripple across the ground: five waves roll out one after another, each further and paler, then pairs of wavy rings (near and wide) and jittering dashes round him while the scan lasts, and small rings pulse under everyone revealed. 14 s |
| 3 | EYE RICOCHET | the eye-ball bounces from enemy to enemy (up to 4), 7 each. 9 s |
| G | SCAN: GOLDEN SPIN | the eyes find the nearest enemy anywhere within 200 studs. A golden-spinning ball goes **straight through everything** to them: 26 damage, can't be blocked, paralysed 2 s. Anyone in its path takes 10 |

**Look (polished 2026-11-27):**
- The eye-ball in his hand has a green spin ring circling it, and the eye "looks" now and then (a thin green beam sweeps out).
- Combo: the ball whirls on each swing, the 4th hit throws off a spin ring, and the finisher sends out a vibration ring.
- Scan Shot: spin rings, green afterimages and a lock-on beam to the target. On a hit, spiral ripples, a vibration ring and an eye opening over the target.
- Scan: a big eye opens over his head, green scan lines sweep his screen, and vibration lines ripple across the ground.
- Ricochet: a fading green zigzag of its path, with a ripple and a vibration ring at each bounce.
- Golden Spin: a turning golden rectangle locks onto the target, a gold eye opens over Gyro, a gold spin gathers in his hand and a "SCAN / GOLDEN SPIN" title appears. A golden helix unwinds along the path, and golden rectangles burst out where it hits.

**Shop:** Gyro buying a Steel Ball gets a **Spin boost** for 60 s: +20% damage, +10% speed and abilities recharge 25% faster (`TuskConfig.ShopBalls.GyroBoost`).
