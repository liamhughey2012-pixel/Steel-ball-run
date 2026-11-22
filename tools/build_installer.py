"""Builds roblox_scripts/SpinBattlegrounds_Installer.lua: one script that
creates every Spin Battlegrounds script in Studio (plugin or command bar)."""
import os, re

ROOTS = [
    ("src/shared", "ReplicatedStorage", "SpinShared", "Folder"),
    ("src/server", "ServerScriptService", "SpinServer", "Script"),
    ("src/client", "StarterPlayerScripts", "SpinClient", "LocalScript"),
    ("src/tools", "ServerStorage", "SpinTools", "Folder"),
]

entries = []  # (service, path, class, source or None)
for src, service, root, rootClass in ROOTS:
    init = None
    for f in ("init.server.lua", "init.client.lua"):
        if os.path.exists(os.path.join(src, f)):
            init = open(os.path.join(src, f)).read()
    entries.append((service, root, rootClass, init))
    def walk(path, prefix):
        for e in sorted(os.listdir(path)):
            full = os.path.join(path, e)
            if e.startswith("init."):
                continue
            if os.path.isdir(full):
                entries.append((service, prefix + "/" + e, "Folder", None))
                walk(full, prefix + "/" + e)
            elif e.endswith(".lua"):
                entries.append((service, prefix + "/" + e[:-4], "ModuleScript", open(full).read()))
    walk(src, root)

def long_string(text):
    level = 1
    while ("]" + "=" * level + "]") in text:
        level += 1
    eq = "=" * level
    return "[" + eq + "[\n" + text + "]" + eq + "]"

lines = []
for service, path, cls, source in entries:
    src = long_string(source) if source is not None else "nil"
    lines.append(f'\t{{ Service = "{service}", Path = "{path}", Class = "{cls}", Source = {src} }},')

installer = '''--[[
	SPIN BATTLEGROUNDS INSTALLER
	Creates every script (Golden Spin, Tusk Act 1, Tusk Sneak, NPCs, map builder)
	in the right place with the right name. Running it again replaces the old
	versions, so use it for every update.

	OPTION A: plugin (recommended, a reusable button)
	  1. In Studio: Plugins tab > Plugins Folder (opens a folder on your PC).
	  2. Put this file in that folder. Restart Studio.
	  3. Open your place. Plugins tab > "Spin Battlegrounds" toolbar:
	       [Install Scripts]  creates or updates all scripts
	       [Build Map]        builds the SBR map once
	  4. If Studio asks to allow script injection, click Allow.
	  5. File > Save.

	OPTION B: one time, without a plugin
	  View > Command Bar, paste this whole file, press Enter. Then build the map:
	    require(game.ServerStorage.SpinTools.SBRMapBuilder).Build()
	  File > Save.
]]

local SCRIPTS = {
''' + "\n".join(lines) + '''
}

local ROOT_NAMES = { "SpinShared", "SpinServer", "SpinClient", "SpinTools" }

local function service(name)
	if name == "StarterPlayerScripts" then
		return game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
	end
	return game:GetService(name)
end

local function install()
	local ChangeHistoryService = game:GetService("ChangeHistoryService")
	pcall(function()
		ChangeHistoryService:SetWaypoint("Before Spin Battlegrounds install")
	end)

	-- Remove old versions so updates never leave stale scripts behind.
	local roots = {
		{ "ReplicatedStorage", "SpinShared" },
		{ "ServerScriptService", "SpinServer" },
		{ "StarterPlayerScripts", "SpinClient" },
		{ "ServerStorage", "SpinTools" },
	}
	for _, r in ipairs(roots) do
		local old = service(r[1]):FindFirstChild(r[2])
		if old then
			old:Destroy()
		end
	end

	local created = 0
	for _, entry in ipairs(SCRIPTS) do
		local parent = service(entry.Service)
		local parts = string.split(entry.Path, "/")
		for i = 1, #parts - 1 do
			parent = parent:FindFirstChild(parts[i])
			assert(parent, "Installer: missing parent for " .. entry.Path)
		end
		local object = Instance.new(entry.Class)
		object.Name = parts[#parts]
		if entry.Source then
			object.Source = entry.Source
		end
		object.Parent = parent
		created = created + 1
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("Installed Spin Battlegrounds")
	end)
	print(("[Spin Battlegrounds] Installed %d objects. Now build the map (once) and File > Save."):format(created))
	return created
end

local function buildMap()
	local tools = game:GetService("ServerStorage"):FindFirstChild("SpinTools")
	local builder = tools and tools:FindFirstChild("SBRMapBuilder")
	if not builder then
		warn("[Spin Battlegrounds] Install the scripts first.")
		return
	end
	require(builder).Build()
end

if plugin then
	local toolbar = plugin:CreateToolbar("Spin Battlegrounds")
	local installButton = toolbar:CreateButton("Install Scripts", "Create or update every Spin Battlegrounds script", "")
	local mapButton = toolbar:CreateButton("Build Map", "Build the Steel Ball Run map (once)", "")
	installButton.ClickableWhenViewportHidden = true
	mapButton.ClickableWhenViewportHidden = true
	installButton.Click:Connect(function()
		local ok, err = pcall(install)
		if not ok then
			warn("[Spin Battlegrounds] Install failed: " .. tostring(err))
		end
	end)
	mapButton.Click:Connect(function()
		local ok, err = pcall(buildMap)
		if not ok then
			warn("[Spin Battlegrounds] Map build failed: " .. tostring(err))
		end
	end)
else
	install()
end
'''
os.makedirs("roblox_scripts", exist_ok=True)
open("roblox_scripts/SpinBattlegrounds_Installer.lua", "w").write(installer)
print(len(entries), "objects,", len(installer) // 1024, "KB")
