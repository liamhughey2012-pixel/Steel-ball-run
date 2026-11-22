---
tags: [character, diego]
status: built
updated: 2026-11-22
---
# Diego Brando: Scary Monsters
Pick him from the character dropdown (top-left card ▼ → DIEGO BRANDO → SELECT). Numbers: `TuskConfig.Diego`.
Server moves: `TuskActs/DiegoBrando`. Visuals: `TuskActVFX/Diego`. Raptor: `SpinShared/RaptorModel`. Look: `DiegoOutfit`.

![[scary_monsters_raptor_preview.png]]
*(stand-in renders of the raptor: idle with jaws open, then running with a claw swipe)*

**Human look** (`DiegoOutfit`, everyone sees it): your own clothes stay on. Green scaled cap with **DIO** on the front, spiky blond hair, and a long blue dinosaur tail (teal at the base, pale belly, yellow markings).
![[diego_outfit_preview.png]]

**Raptor** (from the owner's pictures): teal head, neck and chest with dark navy stripe rings, deep blue haunches, legs and tail, pale yellow tail underside, yellow "0101" markings, wide jaws with white teeth and a pink mouth, the yellow pin crown round the skull, yellow claws and sickle claws.

| Input | Move | What it does |
|---|---|---|
| M1 | CLAW COMBO | claw, claw, tail whip, bite (area finisher with a chomp). Bigger and faster while transformed |
| 1 | RAPTOR POUNCE | crouch, then leap in an arc at the nearest enemy in front (up to 32 studs), land with a bite and an area hit (9, or 11.7 transformed) |
| 2 | DINO INFECTION | infecting bite (7). Scales spread for 0.8 s, then the victim **turns into a dinosaur in their own avatar's colours** that you command for **10 s**: it follows you and bites nearby enemies (5). Press 2 again to send it after whoever you aim at (7 per bite). 25 s cooldown on a hit, 4 s on a miss |
| 3 | SCARY MONSTERS | turn into the full raptor for 10 s: 1.35x speed, stronger claws, harder pounce, and **Kinetic Vision** (moving enemies glow orange through walls, only for you). Press again to change back early. 14 s cooldown after |
| G | RAPTOR PACK | a roar that stuns everyone within 16 studs, then 5 raptors burst from the ground and charge out in a fan, biting everything in their path (12 each, at most 2 bites per enemy) |

- Untransformed, Diego stands hunched with clawed hands and breathing idle.
- Transformed, the player's body is hidden and the raptor runs, sways its tail, snaps its jaws, rakes with its claws and whips its tail on each move.
- HUD: the SCARY MONSTERS card shows "ACTIVE 7s" with a draining bar while transformed.
- Hit sparks are blue for Diego.

## Blocky look
The raptor (and Diego's dino tail) are blocky like the Tusk Stands: boxes instead of rounded shapes (`TuskConfig.BlockyModels`, on by default). See [[Tusk]] for the comparison sheet.

## Dino Infection: commanded dinosaurs
![[dino_infection_thrall_preview.png]]
*(top: Diego's raptor. Bottom: a victim with a red shirt, black trousers and light skin turned into a dinosaur in those colours)*
- The victim can't use their own moves while turned, and Diego's attacks can't hurt his own dinosaur.
- The server takes over the victim's movement (network ownership) and gives it back afterwards.
- Everyone sees a blue outline and a tag: "DIEGO'S DINO 7s" (or "YOUR DINO" for Diego).
- The HUD's Dino Infection card shows "COMMAND 7s" while you control one.

## Blue slashes
Claw marks and the tail sweep are blue.
