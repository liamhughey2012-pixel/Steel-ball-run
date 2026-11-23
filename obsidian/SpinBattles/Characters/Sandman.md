---
tags: [character, sandman]
status: built
updated: 2026-11-23
---
# Sandman (Soundman): In a Silent Way
Pick him from the character dropdown (top-left card ▼ → SANDMAN → SELECT). Numbers: `TuskConfig.Sandman`.
Server moves: `TuskActs/Sandman`. Visuals: `TuskActVFX/SandmanVFX`. Look: `SandmanOutfit`. Scripts: `Sandman_Server` + `Sandman_Client`.
Built from the character's description (no reference images yet). Send pictures to refine his look.

![[sandman_outfit_preview.png]]
*(stand-in render on a test avatar)*

**Look** (blocky, matched to the reference art the user sent 2026-11-23): mint-green hair over the top of his head with a black stripe down the middle, two mint braids in front tied with gold beads, a long black ponytail; a yellow collar with a black zigzag; bare chest with the red chevron tattoo and green shoulder tattoos; a dark red corset studded with gold; a sand loincloth with gold pyramid studs and hanging flaps; yellow arm bands and long yellow gauntlets; fringed sand wraps under the knees and at the ankles, black shin bands, bare feet with sandal straps.

**In a Silent Way:** sounds become solid, written sound effects (blocky 3D words) that do what they say when touched.

| Input | Move | What it does |
|---|---|---|
| M1 | SOUND CUT COMBO | chop, chop, spinning kick, axe kick; each hit pops a written sound ("ZAN!", "ZASH!", "DOGO!", "DOGOOO!") |
| 1 | SOUND SLASH | a written "ZBAAK!" skims along the ground (65 studs) and cuts the first enemy (9). 6 s cooldown |
| 2 | SOUND TRAP | plants a written "DOGOOON" on the ground 12 studs ahead (up to 3, 15 s each). The first enemy within 5 studs sets it off (10, launches). Traps in the blast go off together: one hit, +2 each. 5 s cooldown |
| 3 | SAND RUN | sprints 38 studs straight through enemies (7 each) with a sand trail and "ZAZAZA". Can't be hit during the sprint. 7 s cooldown |
| G | SILENT SYMPHONY | sounds gather and orbit him, then 4 waves of written sounds rain down on the area in front (5 each), and a final "DOOOOM!!" explosion (14, launches) |

- Light runner's stance while equipped. Hit sparks are sand-gold.

- **Faster than everyone:** Sandman walks 30% faster than the other characters (`WalkSpeed = 1.3` in his registry entry).

## Stand: In a Silent Way (2026-11-23)
![[in_a_silent_way_preview.png]]
- Blocky model matched to the user's reference art (`TuskActVFX/SilentWayStand`, in `Sandman_Client`):
  - a golden armoured body with six orange roses down the chest;
  - a skull face under a gold helmet with round orange goggle eyes and a spiral on the forehead;
  - a huge feather headdress (white feathers with dark red tips, and a shorter inner row with orange tips);
  - spiked gold shoulder pads and gold arms with zigzag bands;
  - bony white hands;
  - a gold skirt with zigzags and spirals, and patterned gold legs.
- It floats behind him with a **golden aura** (players and NPCs). It throws a strike with every M1 and ability, and does a big manifest spin on Silent Symphony.
- How it works: the core now has `TuskStandModels.register(act, builder, { Aura, AuraLight, Offset })`, so any character pack can bring its own Stand. A custom model at `ReplicatedStorage.SpinAssets.TuskAct8` replaces the built-in one.
