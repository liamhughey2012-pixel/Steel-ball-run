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

## Jockeys: smarter, more of them, and they fight (2026-11-24)
- **7 NPC jockeys** now (`NPCRacers`), with new names.
- **On the race map they ride the road properly.** No pathfinding: the road is clear by design. Each keeps its own lane (`Lane`) so they don't bunch up, cuts corners toward the next gate when it's close (`CornerCut`), and re-steers 5 times a second.
- **From the 2nd stage on they fight** (`FightFromStage`). About 60% are brawlers (`Brawlers`): they ride at a rival within 18 studs and lash them with a **whip** when within 9 (every 2.5-4.5 s; 6 damage, a short stun, a shove sideways).
- **They come for you too:** when a player's in reach, a brawler picks the player about half the time (`PlayerChance`, re-decided every 4 s). Set `FightPlayers = false` to keep them off players.
- **Whips use the normal combat rules:** a stand-in "player" per jockey, so blocking, dodging, i-frames and hit effects all work. Everyone sees the whip crack; you get "WHIPPED BY ...!" when it's you.
- A jockey taken down is out of the race.

- **Fighting turned OFF (2026-11-24):** `Brawlers = 0`, `FightPlayers = false`. Jockeys just race. Set them back to 0.6 / true to turn it on again.

### Race map, made to look better (2026-11-24)
![[race_map_start.png]]
- **The whole world has ground now.** 250-stud tiles, each coloured like the nearest stage (sand, red desert, rock, plains, cobbles, forest floor, concrete), with a faint natural variation. No more bare khaki.
- **Mountains all round the edge** (terrain, snow-capped in the north and east), so the world never just stops. The open sea stays to the south and the lake to the west. **Rolling hills and dunes** inside each region.
- **The road:** paler packed edges and wheel ruts. Rail fences along the beach, plains and river stretches. Sidewalks in Philadelphia and New York, with lamp posts and yellow cabs in New York.
- **A wooden welcome arch at every stage start** with the stage's name, flags, bunting and spectators on both sides. Crowds line the final avenue in New York.
- **More life in every region:**
  - beach: huts, a pier and white surf along the shore;
  - desert: tumbleweeds, covered-wagon wrecks and rock arches;
  - plains: cattle and hay bales;
  - lake: a pebble beach and cabins.
- Small decorations don't cast shadows (cheaper to draw). About 5,500 parts in all.

### Jockey speed guard (2026-11-24)
Reported: after stage 1 every jockey went "super speed" and finished in about 5 s. The logic checks out in tests (their speed is normal at every stage start), so the likely cause is physics. Being anchored at each stage start and then released hands a jockey's physics to whichever player is nearest. Now:
- The server takes back each jockey's physics (`SetNetworkOwner(nil)`) when it's released, and every 2 s after.
- Every tick the server sets each jockey's WalkSpeed from scratch: horse × skill × gallop × carrot × catch-up × stumble × water × stun.
- If a jockey is ever moving faster than 125% of that (+8), its velocity is cut back.
- A jockey that moved more than 40 studs in one tick (a teleport) can't count a gate that tick.
- Tested: forcing every jockey to WalkSpeed 500 mid-race is corrected within 0.15 s, and a 400 studs/s shove is capped straight away.

### Jockeys race fair (2026-11-24)
- **Their horses are never faster than yours:** `NPCSkill` 0.88-1.0 of yours (it was up to 1.04).
- **Their stamina counts more:** galloping drains it 30% faster than yours (`StaminaDrain` 1.3) and it comes back 25% slower (`StaminaRegen` 0.75). They gallop above 60% and ease off below 25%, so about 3 s of galloping then about 5 s of recovering.
- **Final sprint:** only in the last 15% of a stage (`SprintFrom` 0.85), and only if they have 40%+ stamina (`SprintAbove`). They ride it until spent, and can end up WINDED like you.
- **No catch-up speed** any more (`CatchUp` 1.0).
- **You can see their stamina:** a small bar over every other rider's horse while racing (green, gold when low, red when winded). Pick your moment to pass them.
- Rough average pace: jockeys about 55 studs/s, a player managing stamina well about 58.

## Sandman runs on foot (2026-11-25)
If you're playing **Sandman**, the race doesn't give you a horse: you run every stage on your own legs, like in the story, and you're **exactly as fast as a horse**. The horse speed (`Race.HorseSpeed`) goes on his legs, divided by his usual +25% running speed (Registry `WalkSpeed`) so it isn't added on top.
- Stamina, SHIFT to sprint, carrots, hurdles (jump them yourself), water and H all work the same. The meter says "ON FOOT · SHIFT: SPRINT", and the winded warning says "YOU'RE WINDED!".
- Sand kicks up behind him as he runs (RaceClient `stepRunners`).
- When the race ends he goes back to his normal speed (he doesn't keep a horse).
- Server: `runsOnFoot` / `footSpeed` in RaceService. Attribute `RaceOnFoot` on the character. Turn it off with `Race.SandmanOnFoot = false`.

## Horse gallop (2026-11-27)
- **Two gaits:** slow horses **trot** (diagonal pairs of legs together) and fast ones **gallop** (each pair nearly together, the back pair half a stride behind), blending with speed.
- **Stride:** strides quicken with speed. Each leg reaches forward and sweeps back, tucking up as it swings forward.
- **Body:** the head pumps with the stride. The body bobs twice a stride at a trot, and at a gallop makes one big bound, rocking nose-up then nose-down.
- **Tail and dust:** the tail streams back and swishes. Hoofbeats kick up sand above about 22 studs/s.
- **Fix:** the leg joints are looked for again until all four are found. Online, a horse could appear before its legs loaded, and the client cached an empty list, which left that horse frozen.
- Code: `RaceClient` (stepHorses). It works for race horses and your own horse (M), since both carry the "SpinHorse" tag.
