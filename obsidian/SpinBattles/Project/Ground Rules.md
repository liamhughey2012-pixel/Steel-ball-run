---
tags: [project, rules]
updated: 2026-11-22
---
# Ground Rules
1. Inspect the existing project before changing it.
2. Keep working systems. One combat path only: everything goes through [[Combat Adapter]].
3. Small, modular Luau files.
4. The server decides damage, hits, cooldowns and teleports. Clients send intents and aim only.
5. Every effect has a start, an end and cleanup, and respects Low/Medium/High quality.
6. No fake buttons. Unfinished Acts are shown as IN DEVELOPMENT.
7. Original models and sounds only.
8. Ask before building any weapon or Stand model.
9. Every update says where each new file goes ([[Where Every File Goes]]).
10. Never claim something works until it has been tested in Studio.
11. Every character except Johnny (built into the core) is its own separate script (a `_Server` and `_Client` ModuleScript in the SpinCharacters folders), so pasting stays fast. New characters always ship this way.
