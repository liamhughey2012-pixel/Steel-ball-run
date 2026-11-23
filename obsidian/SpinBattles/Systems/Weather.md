---
tags: [system, weather]
status: built
updated: 2026-11-23
---
# Weather (rain)
Server: `WeatherService`. Client: `WeatherClient`. Numbers: `TuskConfig.Weather`.

- It rains for **60 s every 5 minutes** (`RainEvery = 300`, `RainDuration = 60`). The first rain is 5 minutes after the server starts; in Studio it's 15 s, so you can test it.
- The server sets the ReplicatedStorage attributes `SpinRaining`, `SpinRainEnds` and `SpinNextRain`.
- Clients draw it:
  - rain streaks falling around the camera (pooled parts, moved with BulkMoveTo);
  - a grey-blue tint and fog that fade in and out over about 3 s;
  - the optional looping sound `TuskConfig.Sounds.Rain`;
  - an "IT'S RAINING" / "THE RAIN STOPS" banner.
- Set `Weather.Enabled = false` to turn it off.

## Blackmore: Rain Walk
- While it rains, or inside his own Catch the Rainbow storm, a **jump in mid-air** plants a frozen raindrop under his feet. He can walk on the air, and jumping again steps him higher, like climbing raindrops.
- Limits (`TuskConfig.Blackmore.RainWalk`):
  - lasts up to 6 s;
  - up to 8 steps;
  - 3 s cooldown after it ends.
- It ends early if the rain stops, he gets stunned, or he lands on real ground.
- How it works:
  - the movement is client-side, using an invisible local step that follows him;
  - the server checks the request (`TuskRequest "RainFloat"`: must be Blackmore and must be raining) and sets `RainFloating` on his character;
  - every client then draws frozen drops under his feet and his umbrella open.
