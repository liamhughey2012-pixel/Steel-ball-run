---
tags: [character, ui]
updated: 2026-11-22
---
# Johnny Joestar (character card)
Top-left card: portrait, **JOHNNY JOESTAR** name plate, current Stand ("STAND · TUSK ACT 2") in the Act's colour, four Act pips that light up as Tusk awakens, and a health bar. It pops when Tusk evolves.

- Settings: `TuskConfig.Character` (Name, Title, PortraitImage)
- Portrait: a live 3D view of your avatar by default. To use a drawn portrait, upload the image and paste `rbxassetid://...` into `PortraitImage`.
- **Dropdown:** tap the card to open the character list. Johnny Joestar expands into Tusk Acts 1–4 with their moves; your current Act says "YOU ARE HERE". Gyro Zeppeli is playable too: press SELECT on his row to switch. The card shows whoever you are playing.
- Roster settings: `TuskConfig.Roster`
- Code: `CharacterCard` (client)

## Cutscene: Tusk Act 1's first appearance (2026-11-28, from the user's anime clip)
When **you**, playing Johnny (any Tusk Act), pick up the Saint's Corpse **LEFT ARM**. It lasts about 12 s, can be skipped, and has its own toggle (`TuskConfig.Cutscenes.JohnnyArm`):
1. **Looking down at his left hand:** the picture fades in from dark with a green haze. The corpse's withered arm sinks into his own in a golden glow, streaks of light shoot up out of his palm, and Tusk rises out of it with its face turned up to us.
2. **Tusk hovering in front of him**, bobbing, with a burst of teal light and rays behind it.
3. **Over Tusk's back**, at Johnny's face, in a violet tint. His eyes go wide.
4. **Close from the side:** Tusk right by his face, Johnny sweating with his mouth open in shock.
5. **Tusk's face close up** in a pink haze: the star on its forehead, the nail at its chin. Title: "TUSK ACT 1 · FIRST APPEARANCE".

Everything it adds is local to you and removed when it ends or is skipped. It won't replay within 20 s, and it doesn't play for anyone else, or for any part but the Left Arm. Code: `JohnnyArmCutscene` (core client); Tusk is moved with `TuskStand.action(character, "Present", { From, Target, In, Duration })`.

![[johnny_tusk_first_appearance_shots.png]]
*Test renders of the five shots (with the real Tusk Act 1 model; shot 5 without its pink haze).*
