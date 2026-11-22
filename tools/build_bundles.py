"""Packs the modular source into the owner's preferred format:
  Spin_Server.lua  -> Script in ServerScriptService            (server + shared modules + map builder)
  Spin_Client.lua  -> LocalScript in StarterPlayerScripts       (client + shared modules)
  SpinConfig.lua, TuskConfig.lua -> ModuleScripts in ReplicatedStorage (settings, shared by both)
Modules are inlined behind a tiny __require registry."""
import os, re

EXTERNAL = {"SpinConfig", "TuskConfig"}  # real ModuleScripts in ReplicatedStorage

def modules_in(*dirs):
    out = {}
    for d in dirs:
        for dp, _, fs in os.walk(d):
            for f in sorted(fs):
                if f.endswith(".lua") and not f.startswith("init."):
                    out[f[:-4]] = open(os.path.join(dp, f)).read()
    return out

def rewrite(name, code):
    # Drop "local Shared = ...SpinShared..." lines (that folder no longer exists).
    code = re.sub(r'^local Shared = .*SpinShared.*$', 'local Shared = nil -- (bundled: modules are inlined)', code, flags=re.M)
    # Custom-model override folder moves to ReplicatedStorage.SpinAssets.
    code = code.replace('script.Parent:FindFirstChild("Assets")', 'game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")')
    if name == "TuskService":
        old = '''	local actsFolder = script.Parent:WaitForChild("TuskActs")
	for act, info in pairs(Registry.Acts) do
		local moduleScript = actsFolder:FindFirstChild(info.Module or ("TuskAct" .. act))
		if moduleScript and Registry.isImplemented(act) then
			actModules[act] = require(moduleScript)
		end
	end'''
        assert old in code, "TuskService patch"
        code = code.replace(old, '''	for act, info in pairs(Registry.Acts) do
		local name = info.Module or ("TuskAct" .. act)
		if Registry.isImplemented(act) and __hasModule(name) then
			actModules[act] = __require(name)
		end
	end''')
    if name == "TuskController":
        old = '''	local actsFolder = script.Parent:WaitForChild("TuskActVFX")
	for act, info in pairs(Registry.Acts) do
		local m = actsFolder:FindFirstChild(info.ClientModule or ("Act" .. act))
		if m then
			actVFX[act] = require(m)
		end
	end'''
        assert old in code, "TuskController patch"
        code = code.replace(old, '''	for act, info in pairs(Registry.Acts) do
		local name = info.ClientModule or ("Act" .. act)
		if __hasModule(name) then
			actVFX[act] = __require(name)
		end
	end''')
    # Static requires: require(<path ending in .Name>) -> __require("Name")
    def sub(m):
        target = m.group(1).split(".")[-1].strip()
        if target in EXTERNAL:
            return f'require(game:GetService("ReplicatedStorage"):WaitForChild("{target}"))'
        return f'__require("{target}")'
    code = re.sub(r'require\(((?:script|Shared|game:GetService\("ReplicatedStorage"\))(?:\.[A-Za-z_][A-Za-z0-9_]*|\.SpinShared)+)\)', sub, code)
    return code

PRELUDE = '''local __modules = {}
local __loaded = {}
local function __hasModule(name)
	return __modules[name] ~= nil
end
local function __require(name)
	local value = __loaded[name]
	if value == nil then
		local loader = __modules[name]
		assert(loader, "[Spin] missing bundled module: " .. tostring(name))
		value = loader()
		__loaded[name] = value
	end
	return value
end
'''

def bundle(title, header, mods, main):
    parts = [header, PRELUDE]
    for name in sorted(mods):
        body = rewrite(name, mods[name]).rstrip()
        parts.append(f'\n-- ======================================================================\n-- MODULE: {name}\n-- ======================================================================\n__modules["{name}"] = function()\n{body}\nend\n')
    parts.append("\n-- ======================================================================\n-- START\n-- ======================================================================\n" + main)
    return "".join(parts)

shared = {k: v for k, v in modules_in("src/shared").items() if k not in EXTERNAL}
server = {**shared, **modules_in("src/server", "src/tools")}
client = {**shared, **modules_in("src/client")}

SERVER_HEADER = '''--[[
	Spin_Server  (Script)
	PUT IT IN: ServerScriptService

	Spin Battlegrounds server: Johnny Joestar (Tusk Acts 1-4 + Tusk Sneak),
	Gyro Zeppeli (Steel Balls), combat,
	cooldowns, projectiles, NPCs, Studio practice dummies, and the SBR map
	(built automatically when the server starts).

	Needs these ModuleScripts in ReplicatedStorage: SpinConfig, TuskConfig.
	Works with the LocalScript Spin_Client in StarterPlayerScripts.

	MAP SETTINGS (change here):
]]
-- Safety check: this code must be in a Script in ServerScriptService.
if not game:GetService("RunService"):IsServer() or script:IsA("LocalScript") then
	error("[Spin] This is the Spin_SERVER code. It must go in a Script in ServerScriptService, not a LocalScript. Paste Spin_Client.lua into the LocalScript instead.")
end

local BUILD_MAP_ON_START = true -- false = don't build the SBR map
local MAP_ORIGIN = Vector3.new(0, 0, 0) -- move the map away from an existing one, e.g. Vector3.new(1500, 0, 0)

'''
SERVER_MAIN = '''local ProjectileService = __require("ProjectileService")
local TuskService = __require("TuskService")
local NPCService = __require("NPCService")
local TestDummies = __require("TestDummies")
__require("StandAssetLoader").init()

ProjectileService.MaxActivePerPlayer = 20
TuskService.init()
__require("GyroOutfit").init()
__require("DiegoOutfit").init()
if BUILD_MAP_ON_START and not workspace:FindFirstChild("SBRMap") then
	local ok, err = pcall(function()
		__require("SBRMapBuilder").Build({ Origin = MAP_ORIGIN })
	end)
	if not ok then
		warn("[Spin] Map build failed: " .. tostring(err))
	end
end
NPCService.init()
TestDummies.init()
print("[Spin] Server ready")
'''
CLIENT_HEADER = '''--[[
	Spin_Client  (LocalScript)
	PUT IT IN: StarterPlayer > StarterPlayerScripts

	Spin Battlegrounds client: controls (PC, controller, mobile), all VFX,
	Tusk Stands, Gyro's Steel Balls, HUD, character card, NPC bubbles, dust.

	Needs these ModuleScripts in ReplicatedStorage: SpinConfig, TuskConfig.
	Works with the Script Spin_Server in ServerScriptService.
]]

-- Safety check: this code must be in a LocalScript in StarterPlayerScripts.
if game:GetService("RunService"):IsServer() then
	error("[Spin] This is the Spin_CLIENT code. It must go in a LocalScript in StarterPlayer > StarterPlayerScripts. Paste Spin_Server.lua into the Script in ServerScriptService instead.")
end

'''
CLIENT_MAIN = '''__require("SettingsUI").init()
__require("HitFX").init()
__require("TuskStand").init()
__require("TuskProjectiles").init()
__require("TuskSneakController").init()
__require("TuskController").init()
__require("WorldClient").init()
__require("CharacterCard").init()
'''

out = "roblox_scripts/format_like_anime_fighters"
os.makedirs(out, exist_ok=True)
open(f"{out}/Spin_Server.lua", "w").write(bundle("server", SERVER_HEADER, server, SERVER_MAIN))
open(f"{out}/Spin_Client.lua", "w").write(bundle("client", CLIENT_HEADER, client, CLIENT_MAIN))
for name, where in (("SpinConfig", "src/shared/SpinConfig.lua"), ("TuskConfig", "src/shared/TuskConfig.lua")):
    code = open(where).read()
    code = code.replace(f"({name}  (ReplicatedStorage.SpinShared.{name})", f"{name}  (ModuleScript in ReplicatedStorage)")
    code = code.replace(f"	{name}  (ReplicatedStorage.SpinShared.{name})", f"	{name}  (ModuleScript)\n	PUT IT IN: ReplicatedStorage")
    open(f"{out}/{name}.lua", "w").write(code)
for f in sorted(os.listdir(out)):
    print(f, os.path.getsize(os.path.join(out, f)) // 1024, "KB")
