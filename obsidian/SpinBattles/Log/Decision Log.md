---
tags: [log]
updated: 2026-11-22
---
# Decision Log
| Date | Decision |
|---|---|
| 2026-11-22 | Second Brain created; moved to HTML, then to this Obsidian vault |
| 2026-11-22 | No place file yet, so systems are drop-ins with [[Combat Adapter]] as the single integration point |
| 2026-11-22 | Green ball = Steel Ball; orange studded = Wrecking Ball |
| 2026-11-22 | Tusk built on the existing framework (one combat path), Act by Act; Act 1 first |
| 2026-11-22 | Stands render client-side from the replicated `TuskAct` attribute (no server cost) |
| 2026-11-22 | Unfinished Acts are shown as IN DEVELOPMENT, never as working buttons |
| 2026-11-22 | The map is a one-time builder tool, so the result is editable parts saved in the place |
| 2026-11-22 | NPCs are invulnerable, talk via ProximityPrompt, and share one 0.5 s brain loop |
| 2026-11-22 | Ultimates awaken Tusk to the next Act (Awaken mode); death resets to Act 1 |
| 2026-11-22 | Acts 2–4 Stands are procedural first passes until reference images arrive |
| 2026-11-22 | Johnny Joestar card in the top left, live avatar portrait by default |
| 2026-11-22 | Map upgrade: landforms, railway, mine, oasis, horses, moving life (client-only) |
| 2026-11-22 | Character card became a dropdown roster (Johnny playable; Gyro in development) |
| 2026-11-22 | Tusk Act 1 uses the owner's Creator Store model 8768080824; loaded scripts are stripped for safety |
| 2026-11-22 | Slower ultimate progression: per-Act meter gain + 45 s lock after each awakening; Studio refill off |
| 2026-11-22 | Act 1 and Act 2 Stands rebuilt from the owner's images; Act 1 store model is optional (AssetId 0 by default) |
| 2026-11-22 | Stand previews are rendered outside Studio with tools/preview (Roblox maths stand-in + ray tracer) |
| 2026-11-22 | Act 3 and Act 4 Stands rebuilt from the owner's images |
| 2026-11-22 | Act 1 default look is the blue/cyan Mascot (owner's description); the pink Classic look stays as an option |
| 2026-11-22 | Both scripts check they are in the right kind of script and explain the fix if not |
| 2026-11-22 | Act 1 back to the pink Classic look by default (owner re-sent the drawing); Mascot kept as an option |
| 2026-11-22 | Johnny's nails: cyan glow + spinning blue Spin whirls |
| 2026-11-22 | Gyro Zeppeli playable with a Steel Ball moveset (reuses the Tusk ability system as Act 5) |
| 2026-11-22 | Golden Spin (R for everyone) removed; its hit feedback and settings button kept in new modules |
| 2026-11-22 | Gyro's Wrecking Balls replaced by Spin Tornado |
| 2026-11-22 | Separate procedural animation sets for Johnny (finger guns) and Gyro (ball thrower) |
| 2026-11-22 | Gyro's look built from parts (hat, hair, striped outfit) since no catalog ids were given |
| 2026-11-22 | Attack poses now twist, lean and dip the whole body; poses checked on a stand-in R15 rig |
| 2026-11-22 | Gyro outfit removed (player keeps own clothes); hat rebuilt from the owner's pictures with goggles |
| 2026-11-22 | Ball Breaker visuals: Golden Rectangle charge, Ball Breaker spirit, inward pulses, energy pillar |
| 2026-11-22 | Animations: support AnimationConstraint joints, warn when no joints, hold poses slightly longer |
| 2026-11-22 | Tusk Awakening rebuilt: screen darkens, stacked magic circles, 8 cyan nails orbit and fly out, pillar + ground cracks + starburst |
| 2026-11-22 | VFX polish for Johnny and Gyro: crescent M1 slashes, impact stars on every hit (cyan/green by attacker), finisher and ultimate ground cracks |
| 2026-11-22 | Gyro: Steel Ball Throw gets a glow, spiral trails, afterimages, a release ring and drilling ripples; Spin Tornado gets spiral strands, a wind body, a ground swirl, flying debris and sparks |
| 2026-11-22 | Map upgrade 3: river with waterfall, covered bridge, railway trestle, gold camp, Dustwater ghost town, Lucky Horseshoe Ranch, Fort Dust, signpost, 8 NPCs |
| 2026-11-22 | Spin Vibration visuals rebuilt (charge, spiral, zigzag vibration lines, ripples, cracks) |
| 2026-11-22 | Move HUD rebuilt as a battlegrounds hotbar: drawn move icons, cooldown drain + ready flash, charge bars, ULT card with glow/shine, combo counter, toast pills, ゴゴゴ banner |
| 2026-11-22 | Fixed glowing charge orbs that never disappeared (Act 3 ultimate, Ball Breaker windup and vortex) |
| 2026-11-22 | Steel Ball Throw bounces off walls (3 bounces, +2 damage per bounce, faster each time) |
| 2026-11-22 | Animation engine upgrade: eases (In/Snap/Back/Sine), impact shake, elbows + legs + forward lunge, mirrored poses, breathing idle, smooth settle; every move re-keyed |
| 2026-11-22 | Diego Brando / Scary Monsters added as character 6 (from the owner's raptor and Diego pictures): claw combo, Raptor Pounce, Dino Infection, Scary Monsters raptor form with Kinetic Vision, Raptor Pack ultimate |
| 2026-11-22 | Blocky (classic Roblox) look for the Tusk Stands, the Scary Monsters raptor and Diego's tail (SpinShared.Blockify, TuskConfig.BlockyModels) |
| 2026-11-22 | Tusk Act 2 uses golden-ratio visuals (Golden Rectangle + spiral) instead of portals; moves renamed; golden spiral construction fixed (also improves Gyro's Ball Breaker) |
| 2026-11-22 | Scary Monsters slashes are blue |
| 2026-11-22 | Dino Infection turns the victim into a dinosaur in their avatar's colours that Diego commands for 10 s (25 s cooldown on hit) |
| 2026-11-23 | Raptor Pounce fixed: the leap is flown by the owning client (smooth arc), the server decides the landing spot and damage |
| 2026-11-23 | Tusk Stands look like Tusk again: signature round shapes kept smooth, other big round pieces become stepped voxel-round shapes |
| 2026-11-23 | Tusk Act 1 reshaped to match the drawing (leaf ears, fanned heart legs, frills); Act 1 stays round |
| 2026-11-23 | Pink energy aura on every Tusk Stand |
| 2026-11-23 | Gyro's Stand named Ball Breaker; the Ball Breaker figure rebuilt from the owner's picture |
| 2026-11-23 | Pork Pie Hat Kid (Wired) added as a playable character, from the owner's pictures and description |
| 2026-11-23 | All Stands mostly blocky: every Tusk Act and Ball Breaker use boxes / stepped voxel-round shapes; only eyes stay round |
| 2026-11-23 | Each character is its own script (core Spin_Server/Spin_Client + a Server and Client ModuleScript per character in SpinCharacters folders); the map is its own script too |
| 2026-11-23 | Johnny moved back into the core scripts so Spin_Server / Spin_Client work on their own; the other characters and the map stay as optional extra scripts |
| 2026-11-23 | The SBR map moved back into Spin_Server (it went missing when it was an optional script) |
| 2026-11-23 | Character menu: Tusk Act rows removed (one row per character); characters whose scripts are not installed show NOT INSTALLED |
| 2026-11-23 | M1 animations polished for every character: coil before the strike, a stepping strike with overshoot, a short hit-stop hold, then follow-through |
| 2026-11-23 | Sandman (In a Silent Way) added, built from the description; sounds are blocky 3D written words |
| 2026-11-23 | Stand-user NPCs (StandBots) fight players with real character movesets |
| 2026-11-23 | Tusk looks like Tusk again: each Act keeps its signature curved pieces smooth (egg body, ears, ear discs, round body, helmet); the rest stays blocky |
| 2026-11-23 | Practice dummies restyled as burlap training dummies (stitched face, straw, chest target) |
| 2026-11-23 | Combat UI: enemy health bar on hit, red damage edges; hit sparks, shock rings, camera kick, bigger damage numbers; layered M1 swipes |
| 2026-11-23 | Stand-user NPCs scattered round the map (6, at landmark spots checked clear of buildings) |
| 2026-11-23 | Block (F) and Dash (Q) for every character: guard bar, guard break, perfect block, dash i-frames; NPCs use them too |
| 2026-11-23 | Bounty board by the spawn (owner's design): wanted-poster UI, accept/decline, tracker + target marker, Cash and kill streaks in leaderstats |
| 2026-11-23 | Tusk Act 1 rebuilt from the owner's Studio screenshots (smooth lilac, bat-wing ears); bounty Accept button bug fixed |
| 2026-11-23 | Bounty posters show NPC faces (live viewport); the Accept/Decline card sits on its own top layer |
| 2026-11-23 | Bounty board UI polished: framed board, tabs, cash, richer posters, contract card with ACCEPTED stamp |
| 2026-11-23 | Sandman walks 30% faster (Registry WalkSpeed); Mountain Tim (Oh! Lonesome Me) added, also as an NPC and bounty target |
| 2026-11-23 | Character-script loader only loads real character scripts (Gyro_Server etc.), not other *_Server modules; print/warn captured at the top of the bundles |
| 2026-11-23 | Mountain Tim reworked: victim body-split, Split Dodge counter (CombatAdapter.DodgeHandlers), Split Barrage reel; braided rope, knotted lasso, real body-part pieces |
| 2026-11-23 | Hot Pants (Cream Starter) added from the description: flesh spray/seal/mend, Flesh Storm cocoons; also an NPC and bounty target |
| 2026-11-23 | Mountain Tim bug fixes: split body stays hidden (camera-proof) and restores faces exactly, hats ride the pieces, Split Dodge holds still + safe counter spot, gentler pulls, NPC lasso ropes |
| 2026-11-23 | Hot Pants always holds Cream Starter in her hand (hip can removed); new animations (can shakes, spray sweeps, lunge seal, body-spray mend) |
| 2026-11-23 | Character selection redesigned: CHOOSE YOUR FIGHTER screen (themed tiles, status badges, details panel with moves + keys, SELECT) |

## 2026-11-23: Character menu back to the dropdown; balance pass
- The full-screen CHOOSE YOUR FIGHTER screen was reverted at the user's request. The top-left card + dropdown is back, polished: a colour badge with initials, name, Stand, and a status chip on each row; hover highlight; the whole row is clickable; your character is outlined and listed first; the list closes after picking.
- Balance target: abilities roughly 1.5 to 2.5 damage per second of cooldown, ultimates 24 to 34 on one target (Tusk Act 4 stays stronger, since it's earned).

| Character | Change | Why |
|---|---|---|
| Johnny Act 1 | Tusk Jab 3 → 3.5 | starter combo was below everyone else |
| Gyro | Steel Ball cd 5 → 6, return 5 → 4, bank bonus 2 → 1.5; Ball Breaker ticks 2 → 1.5, burst 14 → 12 | throw was ~4 dmg/s; ult was ~44 |
| Diego | Scary Monsters lasts 8 s (was 10) | ~40% uptime on a big buff |
| Pork Pie | Wired Hook 6 → 7; winch slam 14 → 16 | lowest damage kit |
| Sandman | Sound Trap cd 5 → 7; walk speed 1.3 → 1.25 | traps came back too fast; still the fastest runner |
| Mountain Tim | Split Barrage cd 7 → 8 | 15 damage every 7 s |
| Hot Pants | Flesh Mend heal 22 → 18, cd 14 → 16 | too much sustain |
| Blackmore | Cage slow 30% → 45%, cuts 2.5 → 2; storm radius 22 → 18, ticks 2 → 1.5 | cage could do 25+; storm was the biggest AoE in the game |

## 2026-11-23: UI and bounty board broken in the pasted game (fixed)
- **Cause:** the In a Silent Way update made `SandmanVFX` require `TuskStandModels` through `ReplicatedStorage:WaitForChild("SpinShared")`.
  - The bundler only rewrote `Shared.X` / `script.X` requires, so that line shipped as-is.
  - In the pasted install there is no SpinShared folder, so it waited forever.
  - That froze `TuskController.init`, and everything after it never started: the character card, combat UI, defense UI and the bounty UI.
- **Fixes:**
  - SandmanVFX uses `Shared.TuskStandModels`.
  - The bundler rewrites `WaitForChild("SpinShared").X` requires too, and **refuses to build** if any runtime code still mentions SpinShared.
  - Character (act) modules load in `pcall`, so one broken character can't take the game down.
  - Every core system starts in its own `pcall` (`__start`).
- **Also found:** the bundle start-up (hand-written in build_bundles.py) never started `WeatherService` / `WeatherClient`, so it never rained in the pasted game. Both are added now, and the bundler **fails the build** if the source `init.server.lua` / `init.client.lua` starts a system the bundle doesn't.
- **Lesson:** smoke tests ran the source modules, not the built bundles. The new build-time guards cover the two ways the bundles drifted from the source.

## 2026-11-24: un-rewritable require caught before it shipped broken
- BountyService loaded CorpseService with `pcall(require, script.Parent.CorpseService)`. The bundler only rewrites `require(script...)`, so in the pasted install it would have indexed a missing child of ServerScriptService. That throws outside the pcall and breaks the bounty board's list. It was caught by the old bounty test the same session; the fix was re-sent.
- Fix: `pcall(function() return require(script.Parent.CorpseService) end)`, which the bundler rewrites to `__require`.
- **New build guard:** build_bundles refuses any `require, script` / `require(script` left in a module after rewriting.
