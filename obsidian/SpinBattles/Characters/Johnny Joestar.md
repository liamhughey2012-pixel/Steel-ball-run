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

## Cutscene: Tusk Act 1's first appearance (2026-11-28, from the user's anime clip; rebuilt the same day to follow it more closely)
When **you**, playing Johnny (any Tusk Act), pick up the Saint's Corpse **LEFT ARM**. It lasts 13.4 s (the clip's 20 s, tightened), can be skipped, and has its own toggle (`TuskConfig.Cutscenes.JohnnyArm`).

As in the clip, Johnny **sits on the ground** (legs out in front, leaning back on his right hand, his **left forearm lying across his lap**), and **Tusk is tiny**: forearm-sized. The cutscene builds its own small Tusk (the real Act 1 model at 0.4 scale) and animates it by hand: ears and arms flapping, the four legs kicking their heart feet (wildly as it climbs out, calmly later), and its head tilting. Your normal Stand is hidden while it plays.
1. **Close above his forearm** (fading in from dark, a green glow behind): light slices along his arm and Tusk climbs up **out of his forearm**, struggling, face up to us.
2. **From Johnny's eyes:** Tusk floats over his lap, wobbling and drifting closer, with a burst of teal light behind it.
3. **Over Tusk's back** at Johnny's face (violet tint). He leans back, eyes wide.
4. **Close:** Tusk jabs its golden nail at his cheek twice (a glint). He winces with his head turned away, eyes squeezed shut, sweating.
5. **Tusk's face** in a pink haze, its head tilting: "TUSK ACT 1 · FIRST APPEARANCE".

**Johnny's animations** (TuskAnimation): poses `JASit`, `JALook`, `JAShock` and `JAWince`, in the action `JohnnyFirstTusk` (timed to the shots), plus `JohnnyStandUp` to blend him back up if it's skipped.

Everything it adds is local to you and removed when it ends or is skipped. It won't replay within 20 s, and it doesn't play for anyone else, or for any part but the Left Arm. Code: `JohnnyArmCutscene` (core client).

![[johnny_first_tusk_poses.png]]
*Johnny sitting (top) and in shock (bottom): front, three-quarter and side.*

![[johnny_tusk_first_appearance_shots.png]]
*Test renders of shots 1–5 with the posed test figure and the small Tusk. The grey eye shapes floating in shots 3 and 5 are a quirk of the test (his face overlay doesn't follow when the test figure is re-posed); in game they're on his face.*
