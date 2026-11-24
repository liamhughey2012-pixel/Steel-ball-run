---
tags: [system, race]
status: built
updated: 2026-11-24
---
# The Steel Ball Run (horse race)
A horse race round the map **every 10 minutes**.
- Server: `RaceService`. Horse: `HorseModel`. Client: `RaceClient`.
- Numbers: `TuskConfig.Race`. Remote: Net `Race`.
- Ride pose: `TuskAnimation` "Ride".
- Corpse prize: `CorpseService.summon`.

![[race_horse_preview.png]]

## How it plays
1. **Entry (45 s):**
   - A banner at the top says THE STEEL BALL RUN · ENTRY OPEN 0:38, with a **JOIN** button (LEAVE once you're in) and the rider count. You can also press E at the start gate by the spawn.
   - A minute before entry opens, a small chip counts down: STEEL BALL RUN IN 0:45.
   - The numbered course gates go up round the map.
2. **Countdown (4 s):**
   - everyone who entered is lined up at the start gate (6 to a row) on a horse with a random coat (bay, black, grey, chestnut, palomino or paint);
   - they're held still for a big **3, 2, 1, GO!**
3. **The race:**
   - ride through gates 1–19 in order, then the FINISH (passing within 20 studs counts). The course is about 2,900 studs, a lap of the whole map (made longer on 2026-11-24): south down the race track, west and up the west side, across the north, down the east side, then back up past Headquarters hill to the finish by the spawn;
   - horses run at 3.2× walk speed;
   - **everything else still works**: fight, dash, block and use your Stand on horseback;
   - going down (or resetting) puts you out of the race.
   - **Riders see:**
     - a race card top-right: your place, gate x / 20, the time, the top five, and LEAVE;
     - a golden beacon on the next gate with its distance;
     - a gold arrow ahead of the horse pointing at it.
4. **Prizes:**
   - 1st $500, 2nd $250, 3rd $150, every other finisher $50;
   - the winner gets **a Saint's Corpse part at the finish** (one lying out in the desert is brought there; if every part is held, there's no part).
   - Everyone sees who won, then the top 3 results.
5. **It ends** when everyone's finished, 40 s after the winner crosses, or at 7 minutes. Nobody entered: it's cancelled. The next one opens 10 minutes after this one opened.

## The horse
- **Built from blocks:**
  - long body, arched neck with a mane;
  - head with a white blaze, ears, eyes and a dark muzzle;
  - a tail;
  - four legs (white socks on two) and hooves;
  - red saddle blanket, saddle with a horn, stirrups, bridle and reins.
- **How it's attached:**
  - it's welded under the rider's root (Massless, no collision);
  - the rider's HipHeight goes up 2.8, so they sit on it and the hooves touch the ground.
- **The gallop (every client):**
  - a four-beat stride that speeds up with the horse;
  - the neck nods, the tail streams out, the body bobs.
- **The rider:**
  - sits astride (the Ride pose) with the walk/run animation hidden;
  - their stance comes back after the race.

## Studio testing
The first race opens 20 s after the server starts (`StudioFirstAfter`), or 2 minutes in a live server (`FirstAfter`). One rider is enough.

## Update: NPC jockeys, your own horse (M), the stable, bug fixes (2026-11-24)
![[race_rider_preview.png]]
- **NPC JOCKEYS:** 3 of them (`Race.NPCRacers`) join every race that has at least one player in it. They're named Dusty Pete, Sandstorm Sally, Iron Hoof Ike and so on, ride random horses in coloured silks, and have their own speed (`NPCSkill` 78–95% of a player's horse).
  - They find their way to each gate with PathfindingService. If they get stuck they jump, then hop free.
  - You can knock them out of the race.
  - They show in the standings.
  - Prizes go by place among players. If a jockey wins, nobody gets the corpse part.
- **YOUR HORSE (M, controller D-pad left, or the HORSE button on mobile):** call your horse and ride it anywhere at 2.8× speed. Press again to get off (2 s cooldown). You can't toggle it during a race you're in. You race on the same horse, and you keep it after crossing the line.
- **STABLE** (bounty board > SHOP, under the items): a spinning preview of your horse, then **coats** and **saddle blankets**. Buy one once, then equip it any time. If you're riding, the horse changes straight away. Owned items last for the session.
  - **Coats:** Bay (free), Black, Dapple Grey and Chestnut ($150), Palomino and Paint ($250), Midnight ($500), Ghost White ($600), and the metallic Golden Steed ($900).
  - **Blankets:** Red (free), Blue and Green ($60), Purple and Black ($80), Gold Trim ($200).
  - Settings: `TuskConfig.Horses`.
- **Fixes:**
  - **The start no longer clashes with the map.** It's now the map's own fenced race track: riders line up 4 abreast inside it, just behind the START arch. The old start sat on the fence and flag line. The route was re-planned against the map so every gate and stretch is clear of buildings: down the track, out past its end, round the open desert to the east, and back to the finish by the spawn. HorseModel was moved to SpinShared.
  - **You're no longer inside the horse:**
    - the saddle is placed right under the rider's hips (measured from their LowerTorso);
    - their HipHeight is set so the hooves touch the ground;
    - the horse is slimmer (1.9 wide);
    - the Ride pose puts the legs out round its sides.
  - **You no longer spawn in the air:** riders are placed with their hooves exactly on the ground.
  - Leaving during the countdown un-freezes you (you were left anchored).
  - Finishers keep their horse instead of being dropped off it.

## Fix: horses floating up and away (2026-11-24)
**Symptom:** horses rose into the air and drifted off without their riders, and the user saw them climb higher with every move.

**Cause:** riding used to raise the rider's Humanoid **HipHeight**, so they stood high enough to sit on the horse. Roblox can change HipHeight by itself (automatic scaling), and the horse was positioned from that raised value. Riders then dropped back to the ground while the horse was left floating.

**Fix (no HipHeight changes at all):**
- **The horse:** welded under the rider's root at their **normal** height, with its hooves on the ground. The server sets `BodyY` on the horse and re-fits it whenever HipHeight changes. All horse parts are CanCollide/CanQuery/CanTouch false and Massless.
- **The rider:**
  - the server publishes `RideLift`: how far up the saddle is from the rider's seat. The seat is measured from the root joint's rest C0/C1, not from positions replicated from the client;
  - every client lifts the rider's whole body by that much on the root joint (`TuskAnimation.setLift`). It applies under every pose, attacks included, and comes back down when they get off;
  - the rider's camera is raised to match (Humanoid.CameraOffset).
- **The gallop bob** is computed from `BodyY` every frame, never from the previous frame, so it can't creep.
- **TuskAnimation:** only the newest blend runs; an older one finishing later used to undo it.

## More horse customisation (2026-11-24)
![[horse_custom_preview.png]]
The STABLE (bounty board > SHOP) now has a section per category. Each item is a small card: buy it once, then EQUIP it. Extras switch ON / OFF. The live preview on the left spins, and there's a name box under it.

| Category | Options |
|---|---|
| **Coat** | Bay (free), Black, Dapple Grey, Chestnut, Palomino, Paint, Midnight, Ghost White, Golden Steed |
| **Mane & tail** | Natural (the coat's own; free), Black, Flaxen, Silver, Fiery Red, Blue, Pink, Golden |
| **Saddle blanket** | Red (free), Blue, Green, Purple, Black, Gold Trim, White, Pink, Teal |
| **Saddle & bridle** | Brown (free), Black, Tan, Red, White, Silver (metal) |
| **Face marking** | Blaze (free), Plain (free), Star, Stripe, Bald Face |
| **White socks** | Two (free), None (free), Front, Back, All Four |
| **Extras (on/off)** | Saddlebags, Bedroll, Head Plume, Braided Mane, Flowing Tail, Gold Horseshoes, Sleigh Bells, Lantern (it lights up), Winner's Rosettes, War Paint |

- **Name:** type a name (up to 20 characters) and press NAME. It goes through Roblox's text filter (TextService) and shows above your horse for everyone.
- **How it's stored:** player attributes HorseCoat / HorseMane / HorseBlanket / HorseSaddle / HorseMarking / HorseSocks / HorseExtras / HorseName, and HorseOwned (the list of "Kind:Id" you've bought). It lasts for the session.
- `HorseModel.selectionOf(player)` and `HorseModel.lookFrom(TuskConfig.Horses, selection)` build the look, so the shop preview and the real horse always match. If you change anything while riding, the horse is re-saddled straight away.
- Prices are in `TuskConfig.Horses`.


## Racing upgrades (2026-11-24)
- **Gallop:** hold **Shift** (L3, or the GALLOP button on mobile) while racing to go 35% faster. It drains your horse's **stamina** (about 5.5 s from full). Run it dry and the horse is **WINDED**: no galloping until it's back to 40%. Stamina refills when you ease off (after 0.8 s). A stamina meter sits bottom-middle, galloping kicks up dust behind the horse, and your view widens.
- **Carrot crates** on every leg of the course (a hay bale with carrots, glowing orange): ride through one for +45 stamina and a short burst of speed. They come back after 10 s.
- **Log hurdles** across every other long leg (not the first): **jump them** (Space / A). Ride into one on the ground and your horse **stumbles** (40% speed for 1.2 s, -20 stamina). A clean jump gives +5 stamina. "JUMP!" pops up when one's ahead.
- **Lost?** Press **H** (D-pad up, or BACK on mobile) to go back to the last gate you passed. You're held there 3 s; 8 s cooldown.
- **Progress strip** across the top: the course as a track with gate ticks and a finish flag, and every rider as a dot. You're the big gold "YOU" dot, other players are red and jockeys are grey.
- **Splits and records:** each gate shows your split time. Your **best time** (`RaceBest`) and **wins** (`RaceWins`) are saved by DataService. At the finish you see NEW RECORD! (or your best) and your wins.
- **Results board:** riders who were in the race get a wooden board with a parchment list of the finishers, medals for the top 3 and their times. Everyone else gets a one-line "X WON THE STEEL BALL RUN!".
- **Jockeys** gallop when they have the breath (above 65% until 20%), jump hurdles (and misjudge one 15% of the time), and grab carrots they ride over.
- Settings: `TuskConfig.Race.Gallop`, `.Carrots`, `.Hurdles`, `.ReturnPenalty`, `.ReturnCooldown`; keys `TuskConfig.Keys.Gallop` / `.RaceReturn`.


## The stages (2026-11-24)
The race is now run in **nine stages like the real Steel Ball Run**, San Diego to New York. Each stage is its own race: everyone lines up where the last one ended (4 abreast; leaders on points at the front), 3-2-1-GO, and rides that stage's gates to its finish arch ("STAGE n", "FINISH" on the last).

| # | Stage | On our map |
|---|---|---|
| 1 | SAN DIEGO BEACH | the short sprint down the race track |
| 2 | ARIZONA DESERT | out across the south desert, round past Headquarters hill to the east |
| 3 | ROCKY MOUNTAINS | back west across the south, under the mesas |
| 4 | GREAT PLAINS | up the open west side |
| 5 | MISSISSIPPI RIVER | east to the covered bridge, over the river, along the far bank |
| 6 | LAKE MICHIGAN | along the northern shore |
| 7 | PHILADELPHIA | back over the bridge and out east |
| 8 | NEW JERSEY | down the east side |
| 9 | NEW YORK | the final run in to the finish by the spawn |

- About 4,500 studs in all. Every route was generated by a pathfinder round every building, fence, mesa, hill, the mountain ring and the river, and crosses the river **only by the covered bridge**. The old single lap swam the river twice.
- **Points per stage:** 100 / 70 / 50 / 40 / 30 / 25 / 20 / 15 / 10 / 5 by placing (`StagePoints`). Not finishing a stage scores 0. A player who wins a stage gets $50.
- **Each stage ends** when every player still in is home, 15 s after its winner (`StageGrace`), or at 75 s (`StageTimeLimit`). Then there's a 6 s rest (`StageRest`) with the **stage results board**: placings, times, points scored.
- **After stage 9:** the **FINAL STANDINGS** board, ranked by points then total time. Cash goes to the top 3 players overall, a Saint's Corpse part to the overall winner (if a player), and RaceWins +1. Your best total time (`RaceBest`) only counts if you rode all 9 stages.
- Going down still puts you out of the whole race.
- **Smarter jockeys** (`TuskConfig.Race.Jockey`):
  - their horses are as fast as yours (skill 0.92-1.04);
  - they gallop above 55% stamina and ease off below 18%;
  - they flat-out sprint the last quarter of every stage;
  - when tired they turn aside for a carrot crate within 35 studs that's on the way;
  - they miss only 5% of hurdles;
  - one that's fallen 110+ studs behind the leader digs in (8% faster);
  - they get unstuck sooner.
- The stage names follow the real race's route from San Diego to New York, but our desert map stands in for the whole country. Change the names or taglines in `TuskConfig.Race.Stages`.


## The race map (2026-11-24)
![[race_map_top.png]]
The race now has **its own giant world** (`RaceMap`, `TuskConfig.Race.Map`). The server builds it when it starts, far from the main map (6,000 studs east), in batches so it never hitches. It's about **12,800 studs of trail**, roughly 2.5 times the old course, with 54 gates and about 2,800 parts.
- **The trip:** you still JOIN on the main map (button, or E at the start of the main map's race track). When the race starts, everyone is taken to the San Diego beach start. When it ends, or you go out or leave, you're brought back to the spawn. The overall winner's corpse part waits by the spawn.
- **The stages and their scenery:**
  1. Beach: ocean, palms, umbrellas, grandstands at the start.
  2. Desert: layered mesas, cacti, red rocks.
  3. Rockies: a pass between snow-capped terrain peaks, with pines and boulders.
  4. Plains: wheat fields, farmhouses, red barns, windmills.
  5. Mississippi: a wide river across the trail, a covered bridge, a paddle steamer.
  6. Lake Michigan: a great lake, a lighthouse, docks, sailboats.
  7. Philadelphia: a cobbled street lined with brick rows and lamps, and the clock tower.
  8. New Jersey: deep forest and log cabins.
  9. New York: an avenue of skyscrapers to the church and grandstands at the finish.
- **How it's laid out:** the trail (a dirt road on a band of each stage's ground) was laid first, and every bit of scenery is kept at least ~25 studs back from it (tested: nothing solid within reach of the road). A sign marks each stage start.
- **Water** (ocean, river, lake) slows riders to 45%; take the bridge. Invisible walls round the edge stop anyone riding off the map.
- **Longer legs:** more carrot crates (one per ~320 studs) and more hurdles (one per ~220 studs on hurdle legs). Stages allow 150 s (`StageTimeLimit`) and 25 s after the winner (`StageGrace`).
- With `Map.Enabled = false` the race runs on the main-map stages instead (also used while the map is still building).
