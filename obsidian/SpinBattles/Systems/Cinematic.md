---
tags: [system, client, cinematic]
updated: 2026-11-25
---
# Cinematic (film look)
`src/client/Cinematic.lua`; numbers in `TuskConfig.Cinematic`. Client only. Scaled by the VFX button: **Low** = grade and title cards; **Medium** = + vignette; **High** = + depth of field and drifting dust.
- **Grade:** a ColorCorrection (`SpinCinematicGrade`) on top of the map's warmth/bloom/sun rays: a little more contrast, warmth and colour.
- **Depth of field** (`SpinCinematicDOF`): distant things soften a touch (High).
- **Vignette:** dark soft screen edges, *under* the HUD (DisplayOrder -5).
- **Dust:** fine desert dust drifting round the camera (a local part with a volume ParticleEmitter, High).
- **Low health:** under 30% the edges pulse red (faster the lower you are) and colour drains.
- **TAKEN DOWN:** when you finish someone (your hit within 6 s of their death), letterbox bars slide in, "TAKEN DOWN" + their name slams on, the FOV punches in, and there's a short high-contrast flash. 2.5 s cooldown.
- **Death cam:** when you go down the world fades to grey behind bars: "YOU WERE TAKEN DOWN · BY <name>" (or "THE DESERT TAKES ANOTHER"), until you respawn.
- **Title cards:** `Cinematic.title(top, main, color, sub)`. The bounty board uses it for "THE HUNT BEGINS" (on accept) and "BOUNTY CLAIMED".
- It never takes the camera; while a cutscene is playing (camera Scriptable), it doesn't show cards.
