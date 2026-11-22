---
tags: [world, map]
status: built
updated: 2026-11-22
---
# SBR Map
Built by `ServerStorage.SpinTools.SBRMapBuilder` (run once from the command bar; see [[Install Steps]]). Everything lands in `Workspace.SBRMap` as normal parts you can edit.

| Area | Where (from the origin) | Contents |
|---|---|---|
| Race grounds | x 0, z +140 → −250 | dirt track, rail fences, START/GOAL arch, flags, bleachers, spawn |
| Mission church | z −300 | nave, facade, two bell towers, dome, courtyard walls |
| Tent camp | both sides of the track | tents, covered wagons, campfires |
| Western town | x +260 | 8 false-front buildings, entrance banner arch, barrels, troughs, lamps |
| Race HQ | x +260, z −270 (hill) | red brick building, spires, big race sign |
| Desert | everywhere | sand terrain, mountain ring, rocks, cacti, bushes |

## Upgrade 2
| Added | Where |
|---|---|
| Rolling dunes (45), 6 layered mesas | open desert |
| Oasis with pond, grass and 9 palm trees | x −280, z 200 |
| Railway (1,200 studs), DESERT JUNCTION station, steam train with 2 coaches, water tower | x 440 |
| Old silver mine: timber entrance, rails, ore cart, lanterns | NW hill |
| Race stables with 4 horses, 4 more horses by the track, hay bales | race start |
| Pennant strings + string lights along the track, leaderboard sign | race grounds |
| Boardwalks, well, WANTED board, water tower, windmill | town |
| Telegraph line: start → town → station | roads |
| Rock arch, dead trees, cattle skulls, wrecked wagon | desert |
| Moving life (client-only): spinning windmill, circling vultures, rolling tumbleweeds, dust devils | everywhere |
| 4 more NPCs: Stable Hand, Station Master, Old Miner, Oasis Traveller | |

## Upgrade 3: new places
| Place | Where (from the origin) | Contents |
|---|---|---|
| Rattlesnake River | runs east–west around z +290 | carved riverbed with water, muddy banks, reeds |
| Waterfall | x −400 (west mesa) | rock cliff, falling water, foam, mist, plunge pool |
| River Crossing | x 0, z +290 (north of the race start) | red covered bridge on stone piers, ramps, lanterns |
| Railway trestle | x 440, where the railway crosses the river | timber legs and cross-braces |
| Gold-panning camp | x −200, south bank | tents, sluice box into the river, gold pans, nuggets, campfire, GOLD CLAIM sign |
| Dustwater (ghost town) | x −170, z −40 | 5 ruined buildings, fallen water tank, graveyard, abandoned wagon |
| Lucky Horseshoe Ranch | x +140, z +215 | red barn, ranch house, corral with horses, cows, trough, windmill |
| Fort Dust | x +10, z −410 (south of the church) | log palisade, open gate, 4 watchtowers, barracks, flag, cannons, crates |
| Signpost | race start | arrows to every place |
| Roads | | start → bridge → north, town road → ranch, west road → ghost town and gold camp, church → fort |
| 8 more NPCs | | Bridge Keeper, Gold Prospector, Ranch Owner, Cowhand, Fort Captain, Fort Soldier, Mysterious Drifter, Fisherman |

**To see new places in a place you already saved with the map:** delete `Workspace.SBRMap` and press Play (the server rebuilds it), or run the builder from the command bar again.

The map builds automatically when the server starts (4-file version). Turn it off or move it at the top of `Spin_Server`.

Lighting: desert afternoon, atmosphere haze, warm colour correction, sun rays, clouds. Ambient dust drifts around the camera (client).
Original layout, inspired by the Steel Ball Run setting; not a copy of another game.
