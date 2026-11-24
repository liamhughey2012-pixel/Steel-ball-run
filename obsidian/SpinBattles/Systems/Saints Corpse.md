---
tags: [system, corpse]
status: built
updated: 2026-11-24
---
# Saint's Corpse
Server: `CorpseService` (relics, pickup, boosts, drops) and `CorpseMoves` (each character's move). Client: `CorpseClient`. Numbers: `TuskConfig.Corpse`.

- **8 parts, each exists once:** Heart, Head, Left Arm, Right Arm, Spine, Eyes, Ears, Legs.
  - Each lies on a random spot (12 spots round the map).
  - It's a mummified relic that floats and turns, glowing gold, with a **pillar of light** you can see from far away.
  - **Hold E** to take it.
- **Boosts until you die** (they stack):

| Part | Boost |
|---|---|
| Heart | +25 max HP (and healed by 25) |
| Head | +12% damage |
| Left Arm / Right Arm | +8% damage each |
| Spine | -10% damage taken |
| Eyes | abilities recharge 12% faster |
| Ears | +25% ultimate charge |
| Legs | +12% speed |

- **When you die**, your parts **drop where you fell** for anyone to grab. A dropped part nobody takes moves to a new random spot after 60 s. Leaving the game scatters them.
- **CORPSE MOVE (V / D-pad right, or tap the button):** needs at least one part; 20 s cooldown. Each character's own move:

| Character | Move | What it does |
|---|---|---|
| Johnny | GOLDEN SPIN NAIL | a huge golden spinning nail (15, launch) |
| Gyro | GOLDEN RECTANGLE | a spinning shockwave 34 studs straight ahead (13, launch) |
| Diego | DINOSAUR CRASH | leaps 30 studs (can't be hit mid-air) and slams down (12 in 10 studs) |
| Pork Pie Hat Kid | HOOK HARVEST | hooks yank everyone within 20 studs in (11, long stun) |
| Sandman | SOUND BARRIER | dashes 36 studs through enemies (9), then a blast on the path (6, launch) |
| Mountain Tim | LASSO CYCLONE | a spinning lasso pulls everyone within 14 studs in (3 × 4) |
| Hot Pants | FLESH COCOON | armoured for 2 s and heals 30, then a burst (7) |
| Blackmore | RAIN CURTAIN | a cone of frozen drops (12, slowed 2 s) |
| Axl RO | GUILT FLOOD | everyone within 22 studs takes 8 and gets +2 guilt |
| Funny Valentine | CORPSE BLESSING | can't be hit for 2.5 s, heals 15, then a pulse of light (9) |

- **HUD:** a panel on the left lists your parts and their boosts, with the move button and its cooldown. A big banner shows when you take a part; a line at the top when someone else takes one, or a part falls where someone died. The move's name pops up over the caster.
- **Bounties:** holders are worth more on the board: +$40 per part, **+$150 for the Heart or the Head**. Their poster gets a gold "SAINT'S CORPSE" tag, and the contract says which parts they carry.
- **How it works:** boosts are character attributes the combat code reads:
  - `CorpseDamage` and `CorpseResist` in CombatAdapter;
  - `CorpseCooldown` in startCooldown;
  - `CorpseUltGain` in addUlt;
  - speed via the move modifier "Corpse".

## Retrieve contracts + HUD move (2026-11-24)
- **RETRIEVE contracts** on the bounty board: one per part, under a new **CORPSE** tab.
  - $120 each; **$200 for the Heart or the Head** (`RetrieveReward` / `RetrieveRewards`).
  - The poster says **RETRIEVE · SAINT'S CORPSE**. Its photo is the relic itself, or the face of whoever carries it, with a red HELD tag. It reads **HELD BY name** or **LYING IN THE DESERT**.
  - The contract card says what the part GIVES.
  - **Paid the moment you take that part**, from where it lies, or after taking down whoever holds it and grabbing it. Someone else taking it doesn't pay you; the contract keeps running until it times out.
  - The tracker points at the relic or at the holder.
  - You never see a contract for a part you're carrying.
  - (CorpseService `where(id)` / `OnTaken`; BountyService `retrieveBounties`)
- The **Saint's Corpse panel** moved to the **bottom-left corner** (lifted above the thumbstick on touch screens).

## NPC collectors + new relic models (2026-11-24)
- **NPCs collect parts too:**
  - an idle Stand-user NPC walks to any relic within 90 studs of its camp and takes it (`StandBots.CorpseSeekRange`);
  - it gets the boosts, uses its corpse move in fights (`CorpseMoveChance`), and drops its parts where it dies;
  - NPC carriers are worth more on the board (same bonuses as players), and retrieve contracts can say "HELD BY Stand User: X".
- **Relic models rebuilt:**
  - Heart: lobes, aorta and veins, crossed bandages.
  - Head: a skull with a brow ridge, deep sockets, teeth, a jaw and wraps.
  - Spine: 7 vertebrae with wings and discs.
  - Eyes: eyeballs with irises and nerves in a cloth band.
  - Ears: C-shaped ears with folds.
  - Arms: bent at the elbow, with a hand, fingers, a thumb and loose bandages.
  - Legs: thighs, knees, shins, feet and toes.
  - Every relic has a **floating gold halo** and golden motes rising.

![[corpse_relics_1.png]]
![[corpse_relics_2.png]]

## The complete corpse: THE SAINT'S MIRACLE (2026-11-24)
- **Hold all 8 parts** and you have the complete Saint's Corpse:
  - the **whole server is told** in a banner ("NAME HAS THE COMPLETE SAINT'S CORPSE!");
  - a **gold halo** floats over you, with golden motes;
  - your panel turns gold;
  - your bounty gets **+$500** on top of the part bonuses (`CompleteBounty`). NPCs count too.
- **V becomes THE SAINT'S MIRACLE** (any character, one use; `TuskConfig.Corpse.Miracle`):
  1. You can't be hit and you're **healed to full**. A giant golden halo forms high above you, a column of light falls, and the sky turns gold for everyone in range.
  2. **Pillars of light strike every enemy within 70 studs**: 5 waves, 0.6 s apart, 12 each.
  3. A **final blast** (22 studs, 20 damage, a huge launch).
  4. Then **the corpse leaves you**: every part scatters back across the desert ("The Saint's Corpse scatters across the desert!") for the next hunt.
