# How to install Spin Battlegrounds (Tusk Act 1, Golden Spin, SBR map, NPCs)

Each `.lua` file is one script. The file name is the script's exact name in Studio.

## Steps
1. In Studio, make each object below in the place shown: right-click › **Insert Object** › pick the type › rename it exactly (capitals matter).
2. Open the script, select all its text (Ctrl+A) and paste the matching file's contents over it.
3. Scripts listed "inside" another script go **inside that script**: right-click the script and insert there.
4. Make everything **before** pressing Play.

**ReplicatedStorage**
- Folder **SpinShared**, with these ModuleScripts inside it: Maid, NailModel, Net, SpinConfig, SteelBallModel, TuskActRegistry, TuskConfig, TuskStandModels, VFXQuality, WreckingBallModel

**ServerScriptService**
- Script **SpinServer**, with these ModuleScripts inside it: CombatAdapter, CooldownService, NPCService, ProjectileService, SpinService, TestDummies, TuskHitbox, TuskService, TuskSneakService
- Inside SpinServer, also a Folder **TuskActs** containing ModuleScript **TuskAct1**

**StarterPlayer › StarterPlayerScripts**
- LocalScript **SpinClient**, with these ModuleScripts inside it: CameraFX, JointCache, ProceduralPose, SpinController, SpinVFX, TuskAnimation, TuskController, TuskProjectiles, TuskSneakController, TuskStand, TuskVFX, VFXLib, WorldClient
- Inside SpinClient, also a Folder **TuskActVFX** containing ModuleScript **Act1**
- Inside SpinClient, also a Folder **UI** containing ModuleScripts **SpinMeter** and **TuskUI**

**ServerStorage**
- Folder **SpinTools**, containing ModuleScript **SBRMapBuilder**

5. Build the map once: View › **Command Bar**, paste the line below and press Enter, then File › **Save**:
   `require(game.ServerStorage.SpinTools.SBRMapBuilder).Build()`
6. Press **Play**. You spawn as Tusk Act 1 with practice dummies in front of you.
   - Click = M1 combo · 1 / 2 / 3 = abilities (hold 3 to charge) · G = ultimate · C = sneak (click while sneaking = Sneak Attack) · R = Golden Spin · T = Act menu
   - Walk up to an NPC and press **E** to talk.

**Faster option:** in the AllScripts zip, the `SpinBattlegrounds AllScripts` folder has the same files arranged exactly like Studio's Explorer, so you can see what goes where.

**Optional sounds:** upload the `.ogg` files from `assets/audio` (Creator Hub › Asset Manager) and paste their ids into `SpinConfig.Sounds` and `TuskConfig.Sounds`.
