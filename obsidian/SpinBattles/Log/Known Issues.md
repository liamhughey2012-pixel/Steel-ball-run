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
