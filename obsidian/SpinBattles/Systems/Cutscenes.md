---
tags: [system, cutscenes]
status: built
updated: 2026-11-25
---
# Cutscenes
Client module `Cutscenes` (in Spin_Client). Short cinematic camera moves with black letterbox bars and a title card on a nailed wooden sign (the bounty board's style). **Every cutscene can be skipped:** the SKIP button, Enter, or the controller's Select. Settings: `TuskConfig.Cutscenes`, where each one can be switched off.

| Cutscene | When | What you see |
|---|---|---|
| Welcome (`Intro`) | once a session, 2 s after you first spawn | ~12 s fly-over: the whole desert ("SPIN BATTLEGROUNDS · THE STEEL BALL RUN"), the ghost town ("THE SAINT'S CORPSE"), the race track ("THE RACE"), then down to you ("CHOOSE YOUR STAND · PRESS T") |
| Stage intro (`RaceStages`) | every Steel Ball Run stage, during its countdown, for riders | from high over the stage start, sweeping down to behind your horse, "STAGE 3 · ROCKY MOUNTAINS" plus the tagline (~2.7 s, done before GO) |
| Race winner (`RaceWinner`) | the end of the race, for riders | the camera circles the overall winner: "WINNER: NAME", their points (3.4 s) |
| Ultimate (`Ultimates`) | when you use your ultimate | a close-up push-in on you with the ultimate's name in your Stand's colour and your character's name (0.9 s; at most once every 4 s) |
| Complete corpse (`CorpseComplete`) | when you complete the Saint's Corpse | a slow golden half-orbit: "THE SAINT'S CORPSE IS COMPLETE · PRESS V" (3.5 s) |

- Cutscenes have priorities: one only interrupts a lower-priority one (intro 1 < ultimate 2 < stage 3 < winner/corpse 4).
- **The camera always goes back to exactly what it was following** (you, or John Rod while you steer it). Respawning stops a cutscene.
- Engine: `Cutscenes.play(shots, opts)`. A shot is `{ From, To, Time, FOV = {a, b}, Title, Subtitle, Color, Linear }`, where From/To are CFrames or functions (to follow something that moves).

## Fixes (2026-11-26)
- **Shift lock spun you round.** With shift lock on, Roblox turns your character to face wherever the camera looks, so an orbiting cutscene camera made you spin nonstop.
  - While a cutscene plays, `DevEnableMouseLock` is switched off. Every frame, the mouse is freed (`MouseBehavior.Default`) and `UserGameSettings.RotationType` is set back to `MovementRelative`.
  - Afterwards the setting is restored, and if you had shift lock on it's turned back on (through the PlayerModule's MouseLockController).
- **Jitter / fighting the camera:** the cutscene camera now runs in `BindToRenderStep("SpinCutscene", Camera + 2)`, after Roblox's own camera, instead of `RenderStepped`. It also re-asserts `Scriptable` each frame.
- **Ending:** the camera is put back behind your character before control goes back, so it doesn't stay where the last shot left it (e.g. facing you after the ultimate close-up).
