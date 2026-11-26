---
tags: [character, polnareff, silver-chariot]
status: built
updated: 2026-11-26
---
# JEAN PIERRE POLNAREFF (SILVER CHARIOT)
Part 3, a visitor from another world. He's last in the character list. Numbers: `TuskConfig.Polnareff`. Act 23.
Server moves: `TuskActs/Polnareff`. Outfit: `PolnareffOutfit`. Visuals: `TuskActVFX/PolnareffVFX`. Stand model: `TuskActVFX/SilverChariotStand`. Scripts: `Polnareff_Server` + `Polnareff_Client`.
(No reference images were sent; designed from the Part 3 look.)

![[polnareff_preview.png]]
**Polnareff:** his tall silver-white hair standing straight up (tapering a little), half-heart earrings, a black sleeveless top with a high neck, bare muscular arms, high-waisted cream trousers with a dark belt, and dark boots. He stands in a fencer's guard.
**Silver Chariot:** a slim knight in silver armour.
- A helmet with a visor (two glowing eye slits) and a crest of blades sweeping back.
- A breastplate with a round blue emblem, layered shoulder plates, a skirt of plates, greaves and pointed sabatons.
- A long, fine **rapier** with a cup guard.
- A pale silver-blue aura.

| Input | Move | What it does |
|---|---|---|
| M1 | RAPIER COMBO | quick thrusts (bright streaks); the 4th is a lunge ("HORA!") |
| 1 | HORA HORA RUSH | 1.4 s of rapier thrusts stabbing the space in front (dozens of streaks, "HORA HORA"), dragging them in; he can walk slowly. A final thrust (7) with a shockwave. 11 s |
| 2 | ARMOR OFF | the armour plates burst off: for 8 s he's **35% faster**, and the rapier combo is much quicker (0.16 s between thrusts, not 0.24). He leaves silver afterimages as he moves. 20 s |
| 3 | RAPIER SHOT | the Chariot fires its blade like a bullet: instant, 85 studs, stopped by walls (11). 7 s |
| G | AFTERIMAGE STORM | the Chariot splits into **7 see-through copies** circling the nearest enemy in front (30 studs). They stab in for 2.2 s (everyone in the 10-stud ring is hit every 0.15 s), then all thrust at once: 12 damage and a launch ("HORA HORA HORA!") |

- **Corpse move (V): SWORD WHIRL.** The rapier spins round him: 9 damage to everyone within 14 studs.
- He's a Stand-user NPC (20 NPCs; new camp on the east edge at 420, -120) and a bounty-board target.

## SILVER CHARIOT REQUIEM (Act 24, from the Requiem Arrow)
See [[Requiem Arrow]]. Only Polnareff can get it, by taking the arrow, and it lasts until he goes down. Numbers: `TuskConfig.Requiem`. Server: `TuskActs/ChariotRequiem`. Client: `TuskActVFX/ChariotRequiemVFX`, `ChariotRequiemStand`. It ships inside `Polnareff_Server` / `Polnareff_Client`.

![[chariot_requiem_preview.png]]
**Look:** a tall dark wraith in near-black armour.
- A dark hood round a pale mask with hollow eyes.
- The Requiem Arrow's golden scarab glowing in its chest.
- Gold trim, a high collar of spikes, and long thin arms with clawed hands.
- No legs: a long torn robe.
- A floating gold ring behind its head, and a violet aura.

| Input | Move | What it does |
|---|---|---|
| M1 | REQUIEM STRIKES | slow, heavy, long-reaching blows (dark slashes edged in gold) |
| 1 | SOUL SWAP | he and the nearest enemy in front (45 studs) **swap places**; two souls cross between them. They take 8 and reel for 1.4 s ("SOULS SWAPPED"). 10 s |
| 2 | REQUIEM'S SLEEP | a violet mist spreads out: everyone within 26 studs **falls asleep** for 2.2 s ("Z z z"; a sleeper's screen goes dark). 16 s |
| 3 | SHADOW STEP | he slips 24 studs forward like a shadow (can't be hit for a moment), leaving a dark afterimage and black smoke. 6 s |
| G | SOUL REVERSAL | everyone within 35 studs has their **soul pulled out**: a pale see-through copy of them rises and hangs. They're held and drained for 2.2 s, then the souls slam back (18) |
