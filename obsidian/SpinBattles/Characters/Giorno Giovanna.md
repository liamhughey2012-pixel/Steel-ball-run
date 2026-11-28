---
tags: [character, giorno, gold-experience, requiem]
status: built
updated: 2026-11-28
---
# GIORNO GIOVANNA (GOLD EXPERIENCE · GOLD EXPERIENCE REQUIEM)
A visitor from another world (Part 5). He's last in the character list. Act 30 (Gold Experience); the [[Requiem Arrow]] makes it Act 31 (Gold Experience Requiem) until he goes down. Numbers: `TuskConfig.Giorno` and `TuskConfig.GER`.
Server moves: `TuskActs/Giorno` and `TuskActs/GoldExperienceRequiem`. Outfit: `GiornoOutfit` (both acts). Visuals: `TuskActVFX/GiornoVFX` and `TuskActVFX/GERVFX`. Stand models: `TuskActVFX/GoldExperienceStand` and `TuskActVFX/GERStand`. Scripts: `Giorno_Server` + `Giorno_Client` (both acts are in the one pack).
Matched to the three reference images the user sent (2026-11-28).

![[giorno_gold_experience_preview.png]]
*Top: Giorno. Middle: Gold Experience. Bottom: Gold Experience Requiem.*

**Giorno:**
- Golden-blond hair swept back, with his three round curls in a row over the forehead, side locks, and a long braid down his back.
- A pink-violet suit: a long jacket that flares at the hips, a high collar with a gold spiral pin, and a heart-shaped opening at the chest.
- A gold chain-zip runs down from the heart. Three ladybug brooches (two on the chest, one low on the jacket). Gold wrist cuffs, pink shoes.
- He stands with his hand at his chin and his hip cocked.

**Gold Experience:**
- Slim and golden, with purple balls at the elbows, wrists and knees.
- A smooth golden helmet with a spiral curl on the forehead, narrow pale eyes and purple lips.
- Big swept-up silver shoulder wings with a spiral on each, two purple ladybug studs on the chest.
- A belt with silver straps curving across the hips and a purple buckle on one side. A gold aura.

**Gold Experience Requiem:**
- Brighter gold. A tall helmet with two great swept-back crests, orange-red spots down its sides and a big red disc on each cheek.
- A purple face with orange dots, and the Requiem Arrow's head stuck in its forehead with its beetle eye open.
- A high golden collar, a body dotted with orange spots, huge angular shoulder wings. Violet star sparkles drift round him and his Stand the whole time.

## Gold Experience (Act 30)
| Input | Move | What it does |
|---|---|---|
| M1 | MUDA COMBO | golden fists with him; "MUDA!" and a launch on the 4th |
| 1 | MUDA MUDA RUSH | 1.4 s of punches in front of him that drag them along (he can walk at 55%); the last "MUDA!" sends them flying (9 damage) with a burst of leaves. 11 s |
| 2 | LIFE GIVER: TREE | he punches the ground; roots race to the nearest enemy in front (34 studs) or a spot ahead, and a tree bursts up under them: 11 damage in 6 studs, launched high. The tree stands 5 s. 10 s |
| 3 | SENSE OVERLOAD | a punch (9 studs) that gives them too much life: 3 s moving at 25% speed, glowing gold, leaving slow afterimages ("TOO... SLOW..."). Then the pain lands all at once: 15 damage, can't be blocked ("!!!"). A miss costs 3 s; otherwise 13 s |
| G | LIFE BURST | a ring of trees bursts up round him (28 studs); vines coil round everyone caught and hold them 2.4 s while snakes bite (2.5 every 0.4 s), he heals 30, then the trees burst and throw them (14 damage) |
| Corpse | LIFE BLOOM | flowers and vines burst up round him (18 studs): 8 damage, held 1 s, and he heals 12 |

## Gold Experience Requiem (Act 31, from the arrow)
**Becoming it:** take the Requiem Arrow while playing Giorno. You get a skippable cutscene (about 7.7 s, toggle `TuskConfig.Cutscenes.GER`):
1. Wide: Giorno and Gold Experience; the arrow streaks down out of the sky.
2. Close on Gold Experience's chest: the arrow pierces it ("ズキュゥゥン", flash, shake).
3. The camera pulls back as a pillar of gold and violet light swallows the Stand, with lightning cracking round it. The Stand changes inside it.
4. In profile: Giorno's face with Requiem's head beside it, a cosmic violet sky and white lightning behind them, and the line across the screen: "WHAT YOU ARE **SEEING** IS **CERTAINLY** THE **TRUTH.**" (as in the third image).
5. Low and wide: Requiem towers over him in a burst of gold ("GOLD EXPERIENCE REQUIEM · UNTIL YOU GO DOWN").

Everyone else near sees the pillar of light. Going down sends him back to Act 30.

| Input | Move | What it does |
|---|---|---|
| M1 | REQUIEM MUDA COMBO | heavier, longer-reaching blows; violet fists and "MUDA!" |
| 1 | MUDA RUSH: REQUIEM | 1.6 s of punches (bigger box, drags harder); the last "MUDAAA!" deals 12, then a violet shockwave. 10 s |
| 2 | RETURN TO ZERO | a golden clock face turns round him for 1.3 s (he can barely move). If anyone hits him then, the hit never happens: they're wound back 22 studs along a trail of afterimages, take 10 damage (can't be blocked), stunned 1.6 s and can't use abilities for 3 s. They see "WHAT YOU TRIED TO DO NEVER HAPPENED". 14 s |
| 3 | ZERO PUNCH | he's suddenly right in front of the nearest enemy (22 studs) with an unblockable punch: 12 damage, knocked back, and they can't use abilities for 2.5 s ("ZERO"). 9 s |
| G | INFINITE DEATH | needs a target within 60 studs. They're held for 4.6 s and die again and again: 5 times they're thrown somewhere else nearby and hurt (6 each), then one last blow (18). They see the world go violet: "YOU WILL NEVER ARRIVE AT THE TRUTH". You get the title "GOLD EXPERIENCE REQUIEM · INFINITE DEATH". Nothing happens and nothing is spent if there's no target |

Return to Zero uses `CombatAdapter.DodgeHandlers.ReturnToZero` (character attribute `ReturnToZero`). "Can't use abilities" is the shared `SilencedUntil` attribute (as with Heaven's Door).
