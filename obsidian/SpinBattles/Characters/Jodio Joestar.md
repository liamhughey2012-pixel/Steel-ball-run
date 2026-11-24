---
tags: [character, jodio]
status: built
updated: 2026-11-24
---
# Jodio Joestar (The JOJOLands): NOVEMBER RAIN
Jodio from Part 9. Pick him from the character dropdown (JODIO JOESTAR). Numbers: `TuskConfig.Jodio`. Act 17.
Server moves: `TuskActs/Jodio`. Visuals: `TuskActVFX/JodioVFX`. Stand model: `TuskActVFX/NovemberRainStand`. Look: `JodioOutfit`. Scripts: `Jodio_Server` + `Jodio_Client`.
Matched to the reference art the user sent (2026-11-24).

![[jodio_preview.png]]
**Look:** a dark blue hood up with orange toggles and a high white collar; silver hair with a jagged fringe and a long lock down one side; yellow lips; a green star earring. A dark top with his emblem (yellow horns, a green heart with a bow tie, a grey bib edged in red) and a pink strap round his chest. Pink shoulder pads, light-blue short sleeves, bare forearms. Navy trousers with orange buttons down the outside of each leg. He slouches with one hand behind his head.

![[november_rain_preview.png]]
**November Rain:** a sleek white figure: a rounded helmet with a dark visor and two cyan lights, light-blue streamers flowing back from its head, two long hoses arching out of its back and down past its feet, a blue raindrop on its chest, blue bands on its forearms and knees.

**The idea: crushing rain.** His raindrops hit with heavy pressure. They press people down (slow) rather than stun them, so it plays differently from Blackmore's rain.

| Input | Move | What it does |
|---|---|---|
| Passive | SOAKED | his rain soaks whoever it hits for 5 s (they drip); his rain hits soaked enemies **25% harder** |
| M1 | NOVEMBER RAIN COMBO | the stand punches; the 4th hit launches |
| 1 | HEAVY RAIN | a storm cloud forms over the nearest enemy in front (55 studs; else 25 ahead), radius 10, for 3 s. Everyone under it takes 1.2 every 0.3 s and **walks at 50%**. 11 s |
| 2 | RAIN BULLETS | 6 heavy drops fired in a quick burst (3 each, small stun) |
| 3 | RAIN JET | November Rain blasts him 30 studs forward on a jet of rain (he can't be hit mid-jet); anyone in the way is slammed aside (6, stun). 9 s |
| G | NOVEMBER RAIN: TORRENT | "NOVEMBER RAIN"; a huge storm (radius 35) follows him for 6 s and the sky goes grey-blue under it. Everyone under it takes 2 every 0.4 s and walks at 60%. **When it ends the rain comes down all at once: CRUSH** (14, long stun), soaked enemies take more |

- **Corpse move (V): HEAVY RAINFALL.** A storm cloud over him; 0.5 s later the rain crushes everyone within 20 studs (9, stun) and soaks them.
- He's also a Stand-user NPC (14 NPCs now; new camp in the far north) and a bounty-board target.
- **How it works:** soaked is the `SoakedUntil` attribute; the pressure slow is the `RainPressure` move modifier, refreshed each tick and removed when the rain stops reaching them. Rain bullets are server projectiles (Kind `RainDrop`, `TuskService.fireRain`), so time stops freeze them.
