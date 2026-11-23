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
2. A wooden board screen opens with a WANTED poster for every other player (their avatar headshot) and every Stand-user NPC (a "?" in their Stand's colour), each with its reward.
3. **Hover** a poster: it straightens, lifts, grows and casts a shadow. **Click** it: "ACCEPT BOUNTY?" with ACCEPT / DECLINE.
4. **Accept:** a bounty tracker card slides in on the left (target, reward, distance, time left, X to abandon) and a red **TARGET** marker floats over them (only you see it).
5. Land the killing blow (your hit within 6 s of their death): **"BOUNTY CLAIMED! +$..."** and the Cash goes to your leaderstats (Cash, Bounties).

**Rewards:** players $100 + $50 per kill on their current streak; Stand-user NPCs $75. Bounties last 5 minutes. One at a time (a new one replaces the old). If someone else takes down your NPC target, or your target leaves, the bounty is lost.
