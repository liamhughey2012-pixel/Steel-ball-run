---
tags: [system, ui]
status: built
updated: 2026-11-22
---
# Move HUD
`StarterPlayerScripts.SpinClient.UI.TuskUI`: the battlegrounds-style hotbar shown while Johnny or Gyro is equipped.

![[move_hud_mockup.png]]
*(mockup of the layout and colours; the real HUD is built from Roblox UI)*

| Part | What it does |
|---|---|
| Header | Act / character name in the theme colour over a slanted colour band, tagline under it |
| M1 card | combo name, squashes on every click |
| Ability cards 1–3 | key badge, a drawn icon per move, name; cooldown shade drains with a countdown and greys the card, then a white "ready" flash and pop |
| Hold moves | charge bar above the card; STAGE n (Act 4) or FULL! with a glowing border |
| ULT card | meter rises from the bottom, %; READY = pulsing glow, spinning shine on the border, toast "… READY!"; LOCKED + timer after an awakening |
| Pressed / denied | cards squash while the key, mouse or touch is held; a denied move wobbles its card and shows a toast pill |
| Sneak chip | Johnny only; lights up as SNEAKING with the attack hint |
| Combo counter | big number that pops, turns theme colour at 8 hits and gold at 15, with a draining timer bar |
| Banner | black slash band, gradient title, floating menacing ゴ letters (awakening / evolve) |
| Awakened bar | thin timer under the hotbar |

- Icons are drawn from UI shapes (no image uploads). Matched by move name: nail, barrage, spin, portal, dash, ball, tornado, vibration, star.
- Scales down on small screens (phones) and up a little on big ones.
- Key badges follow the last input: keyboard keys, gamepad buttons, hidden on touch.
