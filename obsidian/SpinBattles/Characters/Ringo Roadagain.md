---
tags: [character, ringo, mandom]
status: built
updated: 2026-11-25
---
# RINGO ROADAGAIN (MANDOM)
In the character list just before Funny Valentine. Numbers: `TuskConfig.Ringo`. Act 19.
Server moves: `TuskActs/Ringo`. Outfit: `RingoOutfit`. Visuals: `TuskActVFX/RingoVFX`. Stand model: `TuskActVFX/MandomStand`. Scripts: `Ringo_Server` + `Ringo_Client`.
Matched to the reference art the user sent (2026-11-25).

![[ringo_mandom_preview.png]]
**Look (updated 2026-11-25 to the new art):** Mandom rides close on his **right** shoulder: a big red-pink egg tipped forward, a diamond net of dark maroon cords with a gold stud (dark centre) at every crossing, on a chunky rust-brown leather shoulder-pack, pink tubes curling out with gold rings. Ringo is in **all white**: a shirt with a huge pointed collar standing up beside his head, open in a deep V to the belt, short cap sleeves, bare tanned arms. He has purple-grey fingerless gloves, a gold bracelet, a mustard gun belt with brass studs and a **pink ring buckle**, a tan holster on his right hip, and a brown flap hanging behind his hips. His white trousers flare at the ankle with a ring of gold studs, and he wears brown heeled boots. Mandom's pink tubes are clamped into his right arm, shoulder, chest and back (two in his left forearm), and its yellow watch hand runs across his chest with "60" and "5".

| Input | Move | What it does |
|---|---|---|
| M1 | REVOLVER COMBO | three blows, then a point-blank shot (launches) |
| 1 | SIX SECONDS | he turns his watch (0.35 s; a big clock behind him spins backwards) and goes **back 6 seconds**: to where he was, with the health he had then (never less than now). Enemies within 25 studs lose the 6 seconds too: snapped back to where they were (if it's within 60 studs) and dazed 0.9 s. 18 s |
| 2 | QUICK DRAW | an instant revolver shot, 90 studs (9). 5 s |
| 3 | MANDOM COUNTER | he waits 1 s with a clock ticking under him. **Hit him and time rewinds**: the hit never lands, he's 4 studs behind the attacker and shoots (10, long stun, can't be blocked). 12 s |
| G | THE PATH OF JUSTICE | **6 seconds that happen twice.** A big clock follows him and ticks out 6 seconds (he moves 15% faster). When it ends, time rewinds: his health goes back to what it was when it started, and **every hit he landed in those 6 seconds lands again** (up to 14). |

- **Corpse move (V): SECOND HAND.** Everyone within 20 studs loses 6 seconds: 7 damage and dazed 1.2 s.
- He's a Stand-user NPC (16 NPCs now; new camp in the south-east corner) and a bounty-board target.
- **How it works:** while anyone is playing Mandom, the server remembers every fighter's position and health every 0.2 s for the last ~7.5 s (`Ringo.Init`), so SIX SECONDS knows where everyone was. Riders (anyone in a seat) can't be rewound. The counter is a `DodgeHandlers.MandomCounter` (like Mountain Tim's split). The ultimate notes his hits through `Adapter.on("Hit")` and replays them as `RingoEcho`.
