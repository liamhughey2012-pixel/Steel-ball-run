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
   - ride through gates 1–6 in order, then the FINISH (passing within 20 studs counts). The route goes from the start (by the spawn) through the dunes, the mission church, the western desert, the Dustwater ghost town, the oasis and the gold-panning camp, then back to the finish by the spawn;
   - horses run at 3.2× walk speed;
   - **everything else still works**: fight, dash, block and use your Stand on horseback;
   - going down (or resetting) puts you out of the race.
   - **Riders see:**
     - a race card top-right: your place, gate x / 7, the time, the top five, and LEAVE;
     - a golden beacon on the next gate with its distance;
     - a gold arrow ahead of the horse pointing at it.
4. **Prizes:**
   - 1st $500, 2nd $250, 3rd $150, every other finisher $50;
   - the winner gets **a Saint's Corpse part at the finish** (one lying out in the desert is brought there; if every part is held, there's no part).
   - Everyone sees who won, then the top 3 results.
5. **It ends** when everyone's finished, 25 s after the winner crosses, or at 4 minutes. Nobody entered: it's cancelled. The next one opens 10 minutes after this one opened.

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
