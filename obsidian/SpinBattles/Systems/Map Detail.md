---
tags: [system, map]
status: built
updated: 2026-11-23
---
# Map detail pass
`SBRMapBuilder` now builds a detail layer after everything else: about 2,200 extra parts, for roughly 4,900 in total. Tiny props don't collide, can't be hit by raycasts and cast no shadows, so they cost very little.

![[map_detail_topdown.png]]
*(top-down: green = new desert detail. It only lands in open ground, never on roads, the river, buildings or the arena by the spawn.)*

- **How placement works:** before scattering, the builder marks every 8-stud cell that already has a part, plus the roads and the river band. Then it tries random spots in the open ground only.
- **Desert** (DesertDetail):
  - 120 sagebrush, 80 grass tufts, 30 prickly pear (with fruit), 14 Joshua trees;
  - 45 boulder clusters, 8 hoodoo rock pillars, 10 bleached ribcages and skulls;
  - 6 broken wagons, 10 old fence remnants, 60 pebble clusters.
- **Terrain:** 24 gentle sand dunes, 36 patches of hard ground, sandstone and salt, and a cracked salt flat in the far south-east.
- **Town:** every building gets porch railings with balusters, shutters, plank lines on the false front, a hanging sign under the porch, a bench, a brick chimney and a rain barrel on the roof.
![[map_town_detail.png]]
- **Race grounds** (RaceDetail):
  - furlong distance markers along the track;
  - 6 pennant lines strung across it;
  - a judges' tower with a ladder at the start;
  - hay bale barriers at the far turn;
  - a blocky crowd on the bleachers;
  - a water station with barrels and buckets.
- **Camp** (CampDetail): logs to sit on, a cooking tripod and pot, and smoke at every campfire, plus laundry lines between tents.
![[map_desert_props.png]]
