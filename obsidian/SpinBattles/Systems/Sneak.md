---
tags: [system, sneak]
status: built
updated: 2026-11-24
---
# Sneak (every character)
Press **C** (or the SNEAK chip). You crouch and move at 45% speed for up to 15 s (4 s cooldown after). Numbers: `TuskConfig.Sneak`.

**What it's for: staying unseen**
- **NPCs don't notice you** unless you're within **12 studs**, or you just hit them.
  - A bot that saw you keeps tracking you for 3 s; after that it loses you and walks home.
  - (StandBots `notices()`)
- **Other players see you fade out with distance:** fully visible within 12 studs, up to 85% see-through at 40+. Your Stand fades too, and the ground ripples only show up close. (TuskSneakController)
- **Your name and health bar are hidden** while you sneak.
- **Bounty hunters lose you:** past 30 studs their tracker shows **HIDDEN** instead of the distance, and the target marker disappears. (BountyUI)
- **The sneak chip** shows **HIDDEN**, or **SPOTTED!** in red when an NPC has seen you (`SpottedUntil`).

**Attacking out of sneak**
- **Johnny:** Tusk's Sneak Attack (burrow and emerge behind the target), as before.
- **Everyone else:** an **AMBUSH**. Leaving sneak with an M1 or an ability makes the first hit within 1 s do **1.5× damage** (`AmbushUntil`, read in CombatAdapter).
