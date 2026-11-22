# SPIN BATTLEGROUNDS — Second Brain

The project's shared memory. Read this first in every new chat; update it at the end of every work session.

## 1. Vision
A polished Steel Ball Run-inspired anime Battlegrounds game on Roblox: Spin mechanics, Tusk Acts 1–4, Wrecking Balls, cinematic ultimates, procedural anime VFX, server-authoritative combat.

## 2. Ground rules
1. Inspect the existing project before changing it.
2. Keep existing working systems. Never build a second combat framework. All Spin damage goes through `CombatAdapter`, which can call the game's own combat code.
3. Use modular Luau: small ModuleScripts, no giant scripts.
4. The server decides all damage, hits, cooldowns and teleports. The client only sends "pressed", "released" and an aim direction.
5. Every VFX instance cleans itself up and respects the Low/Medium/High quality setting.
6. No fake UI buttons and no unexplained placeholder abilities.
7. Use original assets and sounds only. Models are procedural or supplied by the owner.
8. **Ask the owner before building any weapon or Stand model**, so they can send a model or reference first.

## 3. Current project state
| Item | Status |
|---|---|
| GitHub repo | Has the Rojo project below. The owner's existing place file has **still not been shared**. |
| Reference images received | Tusk Act 1 (pink, star-covered, heart feet), Steel Ball (orange with gold studs), Steel Ball spinning with golden rings, Johnny firing a nail with Tusk Act 1 |
| Phase 2: core foundations | **Built**: Net, CombatAdapter, CooldownService, ProjectileService, VFXLib, CameraFX, VFXQuality |
| Phase 3: Spin charge system and Steel Ball | **Built and logic-tested, not yet tested in Studio** |
| Tusk, Wrecking Balls, full HUD, map | Not started |

## 4. File map (Rojo: `default.project.json`)
```
ReplicatedStorage.SpinShared            (src/shared)
  SpinConfig       every Spin number: levels, Perfect window, input, colours, sound ids
  VFXQuality       Low / Medium / High presets (client visuals only)
  Net              creates and gets ReplicatedStorage.SpinRemotes (SpinRequest, SpinFX)
  Maid             cleanup helper
  SteelBallModel   procedural Steel Ball (or clones SpinShared.Assets.SteelBall if one is added)
ServerScriptService.SpinServer          (src/server, Script)
  CombatAdapter    damage / stun / block / knockback / team checks + Hooks for the existing combat system
  CooldownService  server cooldowns (reusable for every ability)
  ProjectileService server-simulated spherecast projectiles (reusable for nails and wrecking balls)
  SpinService      charge, release, validation, rate limit, auto-release, interruption
  TestDummies      Studio-only practice dummies
StarterPlayerScripts.SpinClient         (src/client, LocalScript)
  VFXLib           scheduler, beam rings, shockwaves, ground discs, bursts, flashes, afterimages, sound
  CameraFX         shake, FOV punch, speed lines, impact frames
  ProceduralPose   arm wind-up and throw poses via Motor6D C0 (no uploaded animations needed)
  SpinVFX          all Spin visuals for all players
  SpinController   input for PC (R), controller (RT) and mobile (SPIN button)
  UI/SpinMeter     charge bar, Perfect zone, cooldown, popup, VFX quality toggle
assets/audio       original synthesized sounds (upload to Roblox)
docs/steel_ball_preview.png
```

## 5. Spin design (current numbers in SpinConfig)
| Level | Charge | Damage | Stun | Cooldown | Notes |
|---|---|---|---|---|---|
| QUICK SPIN | 0–0.6s | 7 | 0.2s | 2.5s | 1 ring |
| POWER SPIN | 0.6s+ | 13 | 0.4s | 4.5s | 2 rings |
| PERFECT SPIN | release at 1.35–1.57s | 22 | 0.65s | 7s | 3 rings, impact frame |

- Holding past the Perfect window drops the throw back to POWER (overcharge). Auto-release at 3s.
- The server measures charge time itself and allows ±0.05s for lag.
- Counterplay: the thrower moves at half speed while charging, getting hit interrupts the charge (with a short cooldown), the projectile is visible and dodgeable, blocking cuts damage to 35% with no stun, and a 0.5s stun immunity window prevents stun-locks.

## 6. Installation (for the owner)
**Option A: Rojo (recommended)**
1. Install the Rojo plugin in Studio and the Rojo CLI.
2. In this folder, run `rojo serve`, then press Connect in the plugin.

**Option B: by hand.** Recreate the tree in section 4:
- `init.server.lua` becomes a Script named SpinServer.
- `init.client.lua` becomes a LocalScript named SpinClient.
- Every other `.lua` file becomes a ModuleScript with the same name, parented as shown.

**Sounds:** upload `assets/audio/*.ogg` in Creator Hub > Asset Manager, then paste the ids into `SpinConfig.Sounds`.

**Existing combat:** fill in `CombatAdapter.Hooks` (ApplyDamage, IsBlocking, ApplyStun, CanAct) so Spin uses the game's own systems.

## 7. Test checklist (to run in Studio)
- [ ] Hold R: ball appears in hand, rings add per level, meter fills, Perfect zone flashes
- [ ] Release at each level: projectile size, rings and trail change; damage numbers 7 / 13 / 22 on dummies
- [ ] Perfect release: popup, speed lines, FOV punch, impact frame on hit
- [ ] Overcharge (hold past the gold zone) gives POWER; holding 3s auto-throws
- [ ] Cooldown blocks re-use and the UI shows the time left
- [ ] Getting hit while charging shows INTERRUPTED and applies a 0.75s cooldown
- [ ] Throwing at a wall stops the ball with an impact and no damage
- [ ] Two players throwing at each other; same-team players can't hit each other
- [ ] Dying mid-charge leaves no stuck ball or slow after respawn
- [ ] Mobile SPIN button works; controller RT works
- [ ] VFX: LOW / MEDIUM / HIGH all work; Low has no grooves, no screen effects

## 8. Waiting on the owner
- [ ] The existing place file (`.rbxl`), so the adapter can be wired into the real combat system
- [ ] Screenshot of the Tusk Sneak mechanic
- [ ] Screenshot of the Wrecking Balls placeholder
- [ ] Go-ahead plus references for Tusk Act 2, 3 and 4 (Act 1 reference received)
- [ ] Wrecking Ball design: in Steel Ball Run the "wrecking balls" are the small studs that fly off the Steel Ball. Separate weapon, or studs that detach?
- [ ] How Acts unlock: quests, progression, or a selection menu
- [ ] Push access for Claude to the GitHub repo

## 9. Decision log
| Date | Decision |
|---|---|
| 2026-11-22 | Second Brain created. |
| 2026-11-22 | No place file received, so Spin was built as a standalone drop-in with `CombatAdapter` as the single integration point, to avoid a duplicate combat system. |
| 2026-11-22 | Models are procedural so nothing needs uploading; a custom mesh can replace the procedural one via `SpinShared.Assets`. |
| 2026-11-22 | Poses are procedural (Motor6D C0), because animations must be uploaded by the owner's account. Real animations can replace them later. |
| 2026-11-22 | Sounds are synthesized originals in `assets/audio`; they need uploading. |
| 2026-11-22 | Spin key is R (configurable). The client measures charge only for the meter; the server's timing is final. |

## 10. Known issues and limits
- Nothing has been run in Roblox Studio yet. The code passes a Lua syntax check, and the charge-level logic was unit-tested. Pose angles and ring look may need tuning after the first Studio test.
- Server projectiles have no lag compensation, so very high-ping targets can be hit slightly behind where they appear.
- Default stun uses WalkSpeed multipliers. If the game has a sprint system that sets WalkSpeed, use `CombatAdapter.Hooks.ApplyStun`.
- Sounds are silent until ids are pasted into `SpinConfig.Sounds`.
