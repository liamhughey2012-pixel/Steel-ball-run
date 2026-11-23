---
tags: [character, tusk, act1]
status: built
updated: 2026-11-22
---
# Tusk Act 1: the beginning of Spin
**Alternative look "Mascot"** (owner's written description): a small blue/cyan toy-like humanoid with a big round head, big eyes, mechanical seams and bolts, pink accents, short arms and legs, cyan Spin sparkles on its hands. It floats with quick, bouncy, slightly unpredictable motion and looks around.

**Default look "Classic"** (`TuskConfig.StandModels[1].Style = "Classic"`), from the owner's two drawings: tilted pink egg, big five-point forehead star with dark fur, gold pin to a gold cone beak, heavy-lidded eyes with lashes and wavy tendrils, one big sweeping ear and one drooping ear, long chin with gold spikes, a side appendage with a horn, orange stars everywhere, five legs with heart feet.

| Input | Move | What it does | Numbers (TuskConfig.Act1) |
|---|---|---|---|
| M1 ×4 | NAIL COMBO | jab → nail strike → spinning nail assist → blue shockwave finisher | 3 / 3.5 / 3 / 6 dmg, 0.9 s end lag |
| 1 | NAIL SHOT | one spinning nail, cyan helix, thin blue trail | 8 dmg, 4 s cd |
| 2 | NAIL BARRAGE | 5 nails in a fixed fan, individual trails, muzzle flashes | 3 dmg each, 9 s cd |
| 3 (hold) | SPINNING NAIL | charge rings and inward particles; full charge = golden-blue | 8→19 dmg, 10 s cd |
| G | TUSK AWAKENING | armored 1.7 s transformation (magic circles, energy column, Stand manifests) → 18-stud burst → 20 s Awakened | 15 dmg burst; Awakened = cooldowns ×0.6, nails ×1.25 |

Counterplay: M1 wind-up is cancelled by a stun; Spinning Nail is interrupted by a hit; the ultimate has a visible 1.7 s buildup; nails are dodgeable projectiles; there are stun caps and stun immunity.

Status: 🧪 code complete, waiting for the owner's Studio test. See [[Test Checklist]].

## Ultimate pacing
The meter fills slower each Act (`GainByAct`), and the ultimate stays locked for 45 s after each awakening (`MinSecondsPerAct`). Studio test helpers (`StudioStartFull`, `StudioRefill`) are now OFF by default.

## Nail shots
Cyan glowing nails with **blue Spin whirls** (3-armed spirals, cyan centre fading to blue) that keep spinning around the shot, plus the cyan/blue helix trail. Shot = 2 whirls, M1/Barrage = 1, Spinning Nail = 2–3 (golden at full charge). Act 4's golden shots get golden whirls.

## Closer to the drawing (owner's picture)
- Leaf-shaped ears with a darker inside: the big one sweeps out to the right and curls over at the tip, the other droops down the left side and curls.
- Smaller, tucked-in chin so the egg narrows toward the legs; bigger frilly fins; a longer side arm.
- Five legs fanned out under the body with bigger hearts.
- Act 1 keeps all its round shapes (only the thin legs are square rods in the blocky look).
![[act1_vs_picture.png]]
