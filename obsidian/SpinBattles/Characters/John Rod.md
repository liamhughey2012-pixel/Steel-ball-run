---
tags: [character, john-rod]
status: built
updated: 2026-11-24
---
# JOHN ROD (remote-control Stand)
Pick it from the character dropdown (JOHN ROD). The user keeps their own Roblox avatar (no outfit). Numbers: `TuskConfig.JohnRod`. Act 18.
Server moves: `TuskActs/JohnRod`. Visuals + steering: `TuskActVFX/JohnRodVFX`. Stand model: `TuskActVFX/JohnRodStand`. Scripts: `JohnRod_Server` + `JohnRod_Client`.
Matched to the reference art the user sent (2026-11-24).

![[john_rod_preview.png]]
**Look:** one continuous bent metal rod tracing the outline of a man: a loop for the head, a short neck, square shoulders, arms akimbo, a long leg down one side and the other leg lifted mid-step with its foot bent out. Bright pale metal with a soft shine and a pale blue aura. Its user stands hands on hips like it.

| Input | Move | What it does |
|---|---|---|
| M1 | ROD STRIKES | strikes **from wherever John Rod is**; the 4th hit launches |
| 1 | REMOTE CONTROL | **send John Rod off and steer it** (WASD / thumbstick) up to **100 studs** from you, at 30 studs/s. Your camera follows it; you stand still with two fingers at your temple. A wooden plaque shows "STEERING JOHN ROD", a range meter and how far away it is. Everyone sees a faint line from you to it. Press **1 again to bring it back**; it comes back on its own after 25 s. **If you're hit while steering, it snaps back and you're stunned 0.6 s** ("FEEDBACK!"). 4 s cooldown after it returns |
| 2 | ROD LASH | the rod shoots 16 studs straight out of John Rod and snaps back (8, knockback). 6 s |
| 3 | WIRE SNARE | a wire from John Rod coils round the nearest enemy within 16 studs of it: they can't move for 1.6 s (5). 11 s |
| G | OUTLINE CAGE | round John Rod: rods spring up into a cage (radius 14) round everyone near it; they're held (15% speed) and take 2 every 0.5 s for 3 s, then it **squeezes** (13, long stun) |

- Everything comes from John Rod, so you can fight from cover while it's away. Aiming while steering aims from John Rod.
- **Corpse move (V): ROD SNAP.** Rods lash out in every direction from John Rod (wherever it is): 8 to everyone within 18 studs.
- **NPCs** can't steer, so their John Rod flies at their target on its own for 5 s, striking when close. It's a Stand-user NPC (15 NPCs now; new camp on the north-east edge) and a bounty-board target.
- **How it works:** the server owns John Rod's position. The client only sends its movement input ("Steer" request, about 12 times a second, flattened and capped). The server moves the rod with a speed limit, range limit, wall stops and ground following, and publishes it as `StandRemotePos` / `StandRemoteYaw` on the user's character. Every client's TuskStand draws the Stand there, and TuskController aims from there. The user's walk speed is held at 0 (`RodPilot` modifier) while steering. A hit on the user ends it (`Adapter.on("Hit")` in `JohnRod.Init`).
