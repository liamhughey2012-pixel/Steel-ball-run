---
tags: [log]
updated: 2026-11-22
---
# Known Issues and Limits
- Nothing has been run in Roblox Studio yet. Every file passes a Lua syntax check and an undefined-name scan; the Spin timing logic passed a unit test. Expect tuning after the first playtest.
- Procedural pose angles, Stand offsets and ring sizes may need adjusting by eye.
- The Tusk Act 1 Stand model hasn't been seen rendered yet; check its proportions.
- No lag compensation on projectiles.
- Keys 1–3 can also select Backpack tools; if your game uses tools, disable the Backpack or change `TuskConfig.Keys`.
- The default stun uses WalkSpeed multipliers; use `Hooks.ApplyStun` if your game has sprint.
- The Obsidian vault can't sync automatically: copy the updated folder over after each session.
- Move animations are made by moving joints in code. They now work with both Motor6D joints and the newer AnimationConstraint joints. If none are found, the Output says "[Spin] No animatable joints found…" — send that line if you see it.
- Fixed (2026-11-28): Spin_Client could stop with "Attempted to call require with invalid argument(s)" when restoring the mouse lock after a cutscene, because the PlayerModule wasn't there yet. It now checks the PlayerModule exists before requiring it, and skips the step if it doesn't.
- Fixed (2026-11-28): Spin_Server stopped in `CombatAdapter.applyKnockback` ("attempt to index a nil value (local 'direction')") when a hit with knockback had no `Direction` (Giorno's Sense Overload was one). `dealHit` now pushes a hit with no direction straight away from the attacker, and `applyKnockback` itself accepts a missing direction.
- Fixed (2026-11-28): "Gyro: not installed" after pasting in every script. All the shipped scripts load together, so the likely cause is a mix-up in the game (e.g. Gyro_Client's code pasted into Gyro_Server). Each character script now checks it's in the script it belongs to and says so if not ("this is the code for Gyro_Client, but it's in the ModuleScript named Gyro_Server…"). Every setup problem, on the server or the client, now shows on screen with its exact reason, not just in the Output window.
- Fixed (2026-11-28): the map (and the HUD) vanished: the Spin_Server and Spin_Client sent with Diavolo had a line break inside a string in their start-up code, so neither would compile in Roblox. Fixed, and `tools/build_bundles.py` now compiles every script it produces and refuses to finish if any of them is broken.
