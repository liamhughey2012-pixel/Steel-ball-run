# SPIN BATTLEGROUNDS — Second Brain

The project's shared memory. Read this first in every new chat; update it at the end of every work session.

## 1. Vision
A polished Steel Ball Run-inspired anime Battlegrounds game on Roblox: Spin mechanics, Tusk Acts 1–4, Wrecking Balls, cinematic ultimates, procedural anime VFX, server-authoritative combat.

## 2. Ground rules
1. Inspect the existing project before changing it.
2. Keep existing working systems. Never build a second combat framework.
3. Use modular Luau: small ModuleScripts, no giant scripts.
4. Server decides all damage, hits, cooldowns and teleports.
5. Every VFX instance cleans itself up and respects the Low/Medium/High quality setting.
6. No fake UI buttons and no unexplained placeholder abilities.
7. Use original assets and sounds only.
8. **Ask the owner before building any weapon or Stand model** (Steel Ball, Tusk Acts, Wrecking Ball), so they can send a model or reference image first.

## 3. Current project state
| Item | Status |
|---|---|
| GitHub repo `liamhughey2012-pixel/Steel-ball-run` | Only has a README. No game files yet. |
| Roblox place file / scripts | **Not received yet** |
| Reference screenshots (Tusk Sneak, Spin/Wrecking Balls) | **Not received yet** |
| Existing combat, M1, UI, cooldown systems | Unknown until the place is shared |

## 4. Waiting on the owner
- [ ] Place file (`.rbxl` / `.rbxlx`) or a Rojo export of the scripts
- [ ] Screenshot 1: Tusk Sneak
- [ ] Screenshot 2: Spin / Wrecking Balls placeholder
- [ ] Reference or model: Steel Ball
- [ ] Reference or model: Tusk Act 1 / 2 / 3 / 4
- [ ] Reference or model: Wrecking Ball
- [ ] Decision: how Acts unlock (quests, progression, or a selection menu). The system will be configurable either way.
- [ ] Sync method: Rojo (recommended) or copy-paste into Studio

## 5. Planned build phases
Each phase is built and tested before the next one starts.
1. Audit the existing project. Map its combat, M1, abilities, UI, remotes, Tusk and Spin code.
2. Core foundations: config modules, server validation, cooldown service, hitbox service, VFX module with quality levels, projectile service.
3. Spin charge system: Quick, Power and Perfect levels, timing window, charge meter UI. Reusable by other characters.
4. Tusk framework: Act registry, progression config, Act transformation.
5. Tusk Sneak and the underground Sneak Attack, with counterplay.
6. Tusk Act 2 moveset, then Act 3, then Act 4 (Infinite World ultimate).
7. Wrecking Balls: Throw, Returning Spin, Double Wrecking, and the Wrecking Crash ultimate.
8. UI pass for PC, mobile and controller.
9. Map atmosphere pass. The map stays as it is; only lighting, dust and decorations are added.
10. Multiplayer, respawn, low-graphics and mobile testing, then the final report.

## 6. Decision log
| Date | Decision |
|---|---|
| 2026-11-22 | Second Brain created. Work is paused until the place file and screenshots arrive. |

## 7. Known issues and open questions
- What does "Chat New Game" mean? Confirm what the owner expects from this Second Brain.
