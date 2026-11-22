---
tags: [system, animation]
status: built
updated: 2026-11-22
---
# Animations
`StarterPlayerScripts.SpinClient.TuskAnimation`: procedural move animations for Johnny and Gyro (no uploads needed; works on R15 and R6). An uploaded animation id in `TuskConfig.AnimationIds[name]` replaces the procedural one.

![[animation_poses_preview.png]]
*(rough stand-in renders of key poses)*

## How a move is built
Every move follows **anticipation → strike → follow-through → settle**.
Keyframes are `{ Time, Pose, Ease, Shake }`:

| Ease | Feel | Used for |
|---|---|---|
| In | slow then fast | wind-ups (anticipation) |
| Snap | very fast into the pose | strikes, releases |
| Back | swings ~14% past the pose, then settles | jabs, kicks, flicks, big reveals |
| Sine | smooth | follow-through, recovery, loops |
| Out / Linear | default / constant | holds, power build-ups |

- **Shake**: impact jitter (degrees) on the torso, arms and head, fading over 0.16 s.
- **Full body**: hips, knees, elbows and a forward lunge on the root (5th pose value) so weight steps into every hit.
- **Mirror**: left-hand poses are generated from the right-hand ones.
- **Hold poses** (Gyro's ball stance, Sneak, charging) get a breathing idle: chest rise, head and arm sway.
- **Settle**: after a move it eases back over 0.3 s.

## Gyro
| Move | Keys |
|---|---|
| M1 jab | wind back → jab (overshoot, shake) → recover |
| M1 hook | wind → hook (snap) → follow across the body |
| M1 kick | chamber → kick (overshoot) → re-chamber → stance |
| M1 smash | ball overhead → smash (snap, big shake) → follow |
| Steel Ball Throw | set (sideways) → leg-lift wind-up → release (snap) → full follow-through |
| Spin Tornado | crouch wind → underhand bowl → follow |
| Spin Vibration | wind → palm press → push with long vibration shake |
| Ball Breaker | swaying wind-ups with growing shake → big pitch |

## Johnny
Finger-gun flicks with a cocked wind-up, recoil with shake, slam with knee drop, barrage of snapping flicks, Awakening crouch with building shake then an overshoot rise.
