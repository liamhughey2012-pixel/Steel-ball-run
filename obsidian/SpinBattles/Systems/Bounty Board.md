---
tags: [system, bounty]
updated: 2026-11-23
---
# Bounty Board
Server: `BountyService` (built into Spin_Server). Client: `UI/BountyUI` (built into Spin_Client). Numbers: `TuskConfig.Bounty`.

![[bounty_board_preview.png]]
*(stand-in render: the poster text and faces show in Studio)*

**The board** (from the owner's picture, blocky): two brown posts on grassy mounds, a ragged brown plank back, a "BOUNTIES" sign on top, and five parchment wanted posters pinned with nails. The posters show the faces, names and rewards of the current top bounties (updated every 5 s). It stands just west of the spawn.

**Using it:**
1. Walk up and press **E** ("View Bounties").
2. A wooden board screen opens with a WANTED poster for every other player (their avatar headshot) and every Stand-user NPC (their actual face, copied live into the poster), each with its reward.
3. **Hover** a poster: it straightens, lifts, grows and casts a shadow. **Click** it: "ACCEPT BOUNTY?" with ACCEPT / DECLINE.
4. **Accept:** a bounty tracker card slides in on the left (target, reward, distance, time left, X to abandon) and a red **TARGET** marker floats over them (only you see it).
5. Land the killing blow (your hit within 6 s of their death): **"BOUNTY CLAIMED! +$..."** and the Cash goes to your leaderstats (Cash, Bounties).

**Rewards:** players $100 + $50 per kill on their current streak; Stand-user NPCs $75. Bounties last 5 minutes. One at a time (a new one replaces the old). If someone else takes down your NPC target, or your target leaves, the bounty is lost.

**Note:** the board only lists *other* players. Playing alone in Studio you'll only see the NPCs; use Test › Clients and Servers with 2+ players to see player posters.

## Board UI (2026-11-23 polish)
- Framed wooden board (grain lines, plank seams, nails, metal corner brackets, dark edges) that **drops in from the top** and slides away when closed.
- Hanging **BOUNTY BOARD** sign ("HUNT THEM DOWN · GET PAID"), round red close button.
- Header strip: your **Cash**, **ALL / PLAYERS / NPCS** tabs, who you're hunting, and how many players / NPCs are wanted.
- Posters: aged parchment with a burnt edge and a red pin, WANTED / DEAD OR ALIVE, face, name, **Stand** (e.g. STAND: BALL BREAKER), **danger pips** (by reward), a red **reward ribbon**, and an "xN KILLS" badge for players on a streak.
- Hover: straightens, lifts, grows, **glows gold**, shows "CLICK TO HUNT".
- Click: a **BOUNTY CONTRACT** card (face, name, Stand, reward, time limit) with ACCEPT / DECLINE; accepting thumps an **ACCEPTED** stamp onto it.

## UI polish (2026-11-24)
- **Contract card:**
  - a wood header band ("BOUNTY CONTRACT", "WANTED · DEAD OR ALIVE");
  - a bigger framed photo with danger pips under it;
  - the name shrinks to fit (never cut off) and the Stand line under it;
  - the reward on a red ribbon, a clearer note, bigger Accept / Decline buttons.
- **Photos never show "?" now:** if an NPC respawned after the list was sent, the photo finds its current body by name (tag SpinFighter). Failing that, it shows the character's initials on their Stand colour.
- **Active-bounty tracker moved to the right side of the screen** (it covered the character card top-left). Full names now shrink to fit; a red side strip and a rounded photo.
- **Character card and dropdown:** 330 wide (was 290); names and Stand names shrink to fit instead of being cut off ("JOHNNY...", "FUNNY...").

## Corpse contracts mixed in (2026-11-24)
- In the **ALL** tab, RETRIEVE contracts are **spread evenly among the other bounties** (players and NPCs stay sorted by reward) instead of sitting together. The **CORPSE** tab still groups them all. (BountyUI `fillGrid`)
