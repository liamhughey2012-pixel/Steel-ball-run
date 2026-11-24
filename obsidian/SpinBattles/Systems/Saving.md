---
tags: [system, save]
status: built
updated: 2026-11-24
---
# Saving (DataStore)
`DataService` (ServerScriptService.SpinServer.DataService). Settings: `TuskConfig.Save`.

**What's saved, per player** (key `Player_<UserId>` in the DataStore `SpinPlayerData_v1`):
- Cash and Bounties (leaderstats);
- the horse stable: HorseOwned (everything bought), HorseCoat, HorseMane, HorseBlanket, HorseSaddle, HorseMarking, HorseSocks, HorseExtras and HorseName.

**When:**
- it loads on join;
- it saves every 120 s (`AutosaveEvery`), when they leave, and when the server shuts down (BindToClose waits up to 25 s);
- saves use UpdateAsync, with 3 retries.

**Safety:** if a player's data can't be loaded, nothing is saved for them that session, so a DataStore outage can't wipe their progress. Their `DataLoaded` attribute is false, and a warning is printed.

**Studio:** the place must be published. Turn on Game Settings > Security > **Enable Studio Access to API Services**. Without it, the game still works; it just doesn't save.

To start everyone fresh, change `StoreName`.
