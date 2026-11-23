"""Packs the modular source into the owner's preferred format:
  Spin_Server.lua  -> Script in ServerScriptService            (core: combat, projectiles, NPCs, dummies)
  Spin_Client.lua  -> LocalScript in StarterPlayerScripts       (core: input, HUD, shared VFX)
  SpinConfig.lua, TuskConfig.lua -> ModuleScripts in ReplicatedStorage (settings, shared by both)
  characters/<Name>_Server.lua -> ModuleScript in ServerScriptService > SpinCharacters
  characters/<Name>_Client.lua -> ModuleScript in ReplicatedStorage > SpinCharacters
Each character (and the map) is its own small script so pasting stays fast
(owner's request). Modules are inlined behind a tiny __require registry; a
character script returns a function that adds its modules to that registry."""
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

PRELUDE = '''-- Private copies of the built-ins we print with, so nothing loaded later can break them.
local print, warn = print, warn
local __modules = {}
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

# Which modules live in which separate script. Johnny (the default character,
# Tusk Stands, Tusk Sneak) is built into the core so the core always works on
# its own, and so is the map; every other character is an optional extra script.
PACKS = [
    ("Gyro", {"server": ["GyroZeppeli", "GyroOutfit"], "client": ["Gyro", "SteelBallModel", "WreckingBallModel"]},
     "Gyro Zeppeli: Steel Balls and Ball Breaker."),
    ("Diego", {"server": ["DiegoBrando", "DiegoOutfit"], "client": ["Diego", "RaptorModel"]},
     "Diego Brando: Scary Monsters."),
    ("PorkPie", {"server": ["PorkPieHatKid", "PorkPieOutfit"], "client": ["PorkPie"]},
     "Pork Pie Hat Kid: Wired."),
    ("Sandman", {"server": ["Sandman", "SandmanOutfit"], "client": ["SandmanVFX", "SilentWayStand"]},
     "Sandman (Soundman): In a Silent Way."),
    ("MountainTim", {"server": ["MountainTim", "MountainTimOutfit"], "client": ["MountainTimVFX"]},
     "Mountain Tim: Oh! Lonesome Me."),
    ("HotPants", {"server": ["HotPants", "HotPantsOutfit"], "client": ["HotPantsVFX"]},
     "Hot Pants: Cream Starter."),
    ("Blackmore", {"server": ["Blackmore", "BlackmoreOutfit"], "client": ["BlackmoreVFX"]},
     "Blackmore: Catch the Rainbow."),
    ("Axl", {"server": ["Axl", "AxlOutfit"], "client": ["AxlVFX", "CivilWarStand"]},
     "Axl RO: Civil War."),
]

def deps(code):
    return set(re.findall(r'__require\("([A-Za-z0-9_]+)"\)', code))

def closure(roots, mods):
    """Every module reachable from roots (so each side only carries what it uses)."""
    seen, todo = set(), list(roots)
    while todo:
        n = todo.pop()
        if n in seen or n not in mods:
            continue
        seen.add(n)
        todo.extend(deps(rewrite(n, mods[n])))
    return seen

def module_block(name, code):
    body = rewrite(name, code).rstrip()
    return f'\n-- ======================================================================\n-- MODULE: {name}\n-- ======================================================================\n__modules["{name}"] = function()\n{body}\nend\n'

def bundle(title, header, mods, main):
    parts = [header, PRELUDE]
    for name in sorted(mods):
        parts.append(module_block(name, mods[name]))
    parts.append("\n-- ======================================================================\n-- START\n-- ======================================================================\n" + main)
    return "".join(parts)

LOAD_PACKS = '''
-- Character scripts: each character is its own ModuleScript named like
-- "Gyro_Server" / "Gyro_Client". They're found by name anywhere in the usual
-- places (a SpinCharacters folder is tidy but not required), and anything
-- set up wrong is explained in the Output window.
local __packsLoaded = {}
local function __loadPacks(side)
	local suffix = side == "server" and "_server" or "_client"
	local roots = side == "server"
		and { game:GetService("ServerScriptService"), game:GetService("ServerStorage"), game:GetService("ReplicatedStorage") }
		or { game:GetService("ReplicatedStorage"), game:GetService("ReplicatedFirst") }
	-- Only the real character scripts are loaded (e.g. "Gyro_Server"); other
	-- scripts in the game that happen to end in _Server / _Client are ignored.
	local allowed = {}
	for id in pairs(__require("TuskActRegistry").StartAct) do
		allowed[string.lower(id) .. suffix] = true
	end
	local found = 0
	for _, root in ipairs(roots) do
		for _, pack in ipairs(root:GetDescendants()) do
			local name = string.lower(pack.Name):gsub("%.lua$", ""):gsub("%s", "")
			local builtIn = name == "johnny" .. suffix or name == "map" .. suffix -- (now inside Spin_Server / Spin_Client)
			if builtIn and pack:IsA("LuaSourceContainer") and not __packsLoaded[name] then
				__packsLoaded[name] = true
				print("[Spin] " .. pack:GetFullName() .. " isn't needed any more (it's built into Spin_" .. (side == "server" and "Server" or "Client") .. "). You can delete it.")
			elseif allowed[name] and not __packsLoaded[name] then
				if pack:IsA("ModuleScript") then
					local ok, install = pcall(require, pack)
					if ok and type(install) == "function" then
						local ok2, err = pcall(install, __modules, __require, __hasModule)
						if ok2 then
							__packsLoaded[name] = true
							found = found + 1
						else
							warn("[Spin] Character script " .. pack:GetFullName() .. " failed: " .. tostring(err))
						end
					else
						warn("[Spin] " .. pack:GetFullName() .. " isn't a character script (did the whole file get pasted in?): " .. tostring(install))
					end
				elseif pack:IsA("LuaSourceContainer") then
					warn("[Spin] " .. pack:GetFullName() .. " is a " .. pack.ClassName .. ". It must be a ModuleScript: delete it, insert a ModuleScript with the same name, and paste the code into that.")
				end
			end
		end
	end
	if side == "server" then
		-- A _Client script the server can see but players can't.
		for _, where in ipairs({ game:GetService("ServerScriptService"), game:GetService("ServerStorage") }) do
			for _, pack in ipairs(where:GetDescendants()) do
				local lname = string.lower(pack.Name):gsub("%.lua$", ""):gsub("%s", "")
				local isPack = false
				for id in pairs(__require("TuskActRegistry").StartAct) do
					if lname == string.lower(id) .. "_client" then
						isPack = true
					end
				end
				if isPack and pack:IsA("LuaSourceContainer") then
					warn("[Spin] " .. pack:GetFullName() .. " is in " .. where.Name .. ", where players can't see it. Move it to ReplicatedStorage > SpinCharacters.")
				end
			end
		end
	end
	return found
end
'''

def pack_source(name, side, mods, about):
    where = "ServerScriptService > SpinCharacters" if side == "server" else "ReplicatedStorage > SpinCharacters"
    other = "ReplicatedStorage > SpinCharacters" if side == "server" else "ServerScriptService > SpinCharacters"
    other_name = f"{name}_Client" if side == "server" else f"{name}_Server"
    parts = [f'''--[[
	{name}_{side.capitalize()}  (ModuleScript)
	PUT IT IN: {where}   (make a Folder named SpinCharacters there if it doesn't exist)

	{about}
	Its other half is {other_name} in {other}.
	Loaded by Spin_{side.capitalize()}: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)
''']
    for n in sorted(mods):
        parts.append(module_block(n, mods[n]))
    parts.append("end\n")
    return "".join(parts)

SERVER_HEADER = '''--[[
	Spin_Server  (Script)
	PUT IT IN: ServerScriptService

	Spin Battlegrounds server CORE: combat, cooldowns, projectiles, NPCs and
	Studio practice dummies. Each character is its own script (ModuleScripts
	in ServerScriptService > SpinCharacters): Gyro_Server, Diego_Server,
	PorkPie_Server. Johnny and the SBR map (built automatically when the
	server starts) are built in, so this works on its own.

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
SERVER_MAIN = LOAD_PACKS + '''
__loadPacks("server")
local ProjectileService = __require("ProjectileService")
local TuskService = __require("TuskService")
local NPCService = __require("NPCService")
local TestDummies = __require("TestDummies")
__require("StandAssetLoader").init()

ProjectileService.MaxActivePerPlayer = 20
TuskService.init()
for _, outfit in ipairs({ "GyroOutfit", "DiegoOutfit", "PorkPieOutfit", "SandmanOutfit", "MountainTimOutfit", "HotPantsOutfit", "BlackmoreOutfit", "AxlOutfit" }) do
	if __hasModule(outfit) then
		__require(outfit).init()
	end
end
if BUILD_MAP_ON_START and __hasModule("SBRMapBuilder") and not workspace:FindFirstChild("SBRMap") then
	local ok, err = pcall(function()
		__require("SBRMapBuilder").Build({ Origin = MAP_ORIGIN })
	end)
	if not ok then
		warn("[Spin] Map build failed: " .. tostring(err))
	end
end
__require("StandBots").init(TuskService)
__require("BountyService").init()
NPCService.init()
TestDummies.init()
print("[Spin] Server ready")
'''
CLIENT_HEADER = '''--[[
	Spin_Client  (LocalScript)
	PUT IT IN: StarterPlayer > StarterPlayerScripts

	Spin Battlegrounds client CORE: controls (PC, controller, mobile), HUD,
	character card, shared VFX, NPC bubbles, dust. Each character's visuals
	are their own script (ModuleScripts in ReplicatedStorage > SpinCharacters):
	Gyro_Client, Diego_Client, PorkPie_Client. Johnny is built in.

	Needs these ModuleScripts in ReplicatedStorage: SpinConfig, TuskConfig.
	Works with the Script Spin_Server in ServerScriptService.
]]

-- Safety check: this code must be in a LocalScript in StarterPlayerScripts.
if game:GetService("RunService"):IsServer() then
	error("[Spin] This is the Spin_CLIENT code. It must go in a LocalScript in StarterPlayer > StarterPlayerScripts. Paste Spin_Server.lua into the Script in ServerScriptService instead.")
end

'''
CLIENT_MAIN = LOAD_PACKS + '''
-- No waiting on the folder (it's optional): just make sure the game has loaded.
if not game:IsLoaded() then
	game.Loaded:Wait()
end
__loadPacks("client")
__require("SettingsUI").init()
__require("HitFX").init()
__require("TuskStand").init()
__require("TuskProjectiles").init()
__require("TuskSneakController").init()
__require("TuskController").init()
__require("WorldClient").init()
__require("CharacterCard").init()
__require("CombatUI").init()
__require("DefenseClient").init()
__require("BountyUI").init()
'''

shared = {k: v for k, v in modules_in("src/shared").items() if k not in EXTERNAL}
server = {**shared, **modules_in("src/server", "src/tools")}
client = {**shared, **modules_in("src/client")}

out = "roblox_scripts/format_like_anime_fighters"
os.makedirs(f"{out}/characters", exist_ok=True)
for f in os.listdir(f"{out}/characters"):
    os.remove(os.path.join(f"{out}/characters", f))
packed = {"server": set(), "client": set()}
for name, sides, about in PACKS:
    for side in ("server", "client"):
        packed[side].update(sides[side])

def split(side, allmods, main):
    core_roots = [n for n in allmods if n not in packed[side] and n not in shared] + list(deps(main))
    core = closure(core_roots, allmods)
    core -= packed[side]
    for name, sides, about in PACKS:
        names = sides[side]
        if not names:
            continue
        # Shared helpers only this character uses travel with it; anything also
        # needed by the core or another character stays in the core.
        mods = {n: allmods[n] for n in names}
        open(f"{out}/characters/{name}_{side.capitalize()}.lua", "w").write(pack_source(name, side, mods, about))
    needed = set(core)
    for name, sides, about in PACKS:
        for n in sides[side]:
            needed |= {d for d in closure([n], allmods) if d not in packed[side]}
    return {n: allmods[n] for n in sorted(needed)}

server_core = split("server", server, SERVER_MAIN)
client_core = split("client", client, CLIENT_MAIN)
open(f"{out}/Spin_Server.lua", "w").write(bundle("server", SERVER_HEADER, server_core, SERVER_MAIN))
open(f"{out}/Spin_Client.lua", "w").write(bundle("client", CLIENT_HEADER, client_core, CLIENT_MAIN))
for name, where in (("SpinConfig", "src/shared/SpinConfig.lua"), ("TuskConfig", "src/shared/TuskConfig.lua")):
    code = open(where).read()
    code = code.replace(f"({name}  (ReplicatedStorage.SpinShared.{name})", f"{name}  (ModuleScript in ReplicatedStorage)")
    code = code.replace(f"	{name}  (ReplicatedStorage.SpinShared.{name})", f"	{name}  (ModuleScript)\n	PUT IT IN: ReplicatedStorage")
    open(f"{out}/{name}.lua", "w").write(code)
for d in (out, f"{out}/characters"):
    for f in sorted(os.listdir(d)):
        if f.endswith(".lua"):
            print(os.path.relpath(os.path.join(d, f), out), os.path.getsize(os.path.join(d, f)) // 1024, "KB")
