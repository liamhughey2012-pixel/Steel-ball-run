---
tags: [system, server, client, requiem]
updated: 2026-11-26
---
# The Requiem Arrow
Server: `ArrowService`. Client: `RequiemClient`. Numbers: `TuskConfig.RequiemArrow`.
- **Spawning:** every **5 minutes** (the first one 1 minute after the server starts), an arrow turns up at a random spot in the desert, up to 360 studs from the map's centre.
  - It always lands on open, low ground: never on the mountains (over `MaxHeight`), in water, or on a roof.
  - An arrow nobody has taken vanishes when the next one turns up somewhere else.
- **Not marked:** it's an ordinary arrow stuck in the sand at a slant (wooden shaft, gold head with a scarab, white fletching). It has no glow, light, beam, particles, highlight or map marker. The only way to find it is to look.
- **Everyone is told:** a wooden sign drops in at the top of the screen ("A REQUIEM ARROW HAS APPEARED · SOMEWHERE IN THE DESERT · IT'S ON THE BOUNTY BOARD"), with a letterboxed title card. Everyone also hears who takes it, and when an untaken one vanishes.
- **Taking it:** hold E for 1.5 s next to it (the prompt only shows up close).
  - **Playing Polnareff (Silver Chariot):** an arrow streaks out of the sky into Silver Chariot, with a dark violet burst, and it becomes **SILVER CHARIOT REQUIEM** (Act 24) until he goes down. Dying sends him back to Act 23 (Progression `ResetOnDeath`).
  - **Anyone else** (or Requiem Polnareff picking up another): **THE ARROW'S BLESSING** for 90 s. You hit 20% harder, take 20% less, move 15% faster and charge your ultimate 50% faster. A gold glint round you shows it (everyone can see).
- **Bounty board:** while an arrow is out, the board has a **FIND IT** poster ("LOCATION UNKNOWN", $250). Accept it, and the tracker says only "SOMEWHERE IN THE DESERT", with no distance and no marker. You're paid the moment you take the arrow; anyone else holding the contract loses it ("X took the Requiem Arrow").
- **Announced as a bounty:** when an arrow turns up, everyone gets a banner: "NEW BOUNTY: THE REQUIEM ARROW · $X · CHECK THE BOARD". If it vanishes untaken, anyone hunting it loses the contract.
- **Post your own bounty on it:** in the board's POST tab, the arrow is a target ("ARROW · OUT NOW", or "ARROW · NEXT ONE" while none is out). Posted Cash adds to its poster's reward and is paid (Pinkerton Badge applies) to **whoever takes the arrow**, contract or not. It carries over to the next arrow if one vanishes; it's never refunded. Same min, max and cap as other posts (`TuskConfig.Bounty.Post`).
- Blessing hooks: `ArrowBlessUntil`, `ArrowDamage` and `ArrowResist` (in CombatAdapter.dealHit), `ArrowUltGain` (in TuskService.addUlt), and the `ArrowBlessing` move modifier.

- **Purple flash:** when an arrow turns up, a purple Highlight shows it through walls for `HighlightTime` (5) seconds, fading over the last second. After that it's unmarked.
- **Starting Cash:** players start with `Bounty.StartingCash` (250), so they can post straight away. In Studio they get at least `StudioCash` (5000). Pressing POST without enough Cash, or without picking a target, now shows a banner saying why.
