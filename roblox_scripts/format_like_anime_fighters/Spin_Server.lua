--[[
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

-- Private copies of the built-ins we print with, so nothing loaded later can break them.
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

-- ======================================================================
-- START
-- ======================================================================

-- The core is split into ModuleScripts (5 parts) so it pastes quickly.
-- They're found by name (ServerScriptService > SpinCore is the tidy place for them). Anything
-- missing or wrong is shown ON SCREEN (and in Output), and Spin waits for it.
local __coreParts = { "SpinCore_Server_1", "SpinCore_Server_2", "SpinCore_Server_3", "SpinCore_Server_4", "SpinCore_Server_5" }
local __problems = {}
local __notes = {} -- (not fatal: shown, but Spin still starts)
local function __findPart(name)
	for _, root in ipairs({ game:GetService("ServerScriptService"), game:GetService("ServerStorage"), game:GetService("ReplicatedStorage"), workspace }) do
		local found = root:FindFirstChild(name, true)
		if found then
			return found
		end
	end
	return nil
end
local __parts = {}
for _, partName in ipairs(__coreParts) do
	local part = __findPart(partName)
	local waited = 0
	while not part and waited < 10 do
		task.wait(0.5)
		waited = waited + 0.5
		part = __findPart(partName)
	end
	if not part then
		table.insert(__problems, "Missing " .. partName .. ": make a ModuleScript named " .. partName .. " in ServerScriptService > SpinCore and paste " .. partName .. ".lua into it.")
	elseif not part:IsA("ModuleScript") then
		table.insert(__problems, part:GetFullName() .. " is a " .. part.ClassName .. ": it must be a ModuleScript (delete it, insert a ModuleScript with the same name, paste the code in).")
	else
		__parts[partName] = part
	end
end

for _, where in ipairs({ game:GetService("ServerScriptService"), game:GetService("ServerStorage") }) do
	for _, d in ipairs(where:GetDescendants()) do
		local n = d.Name
		if (n:match("^SpinCore_Client_%d+$") or n:match("_Client$")) and d:IsA("ModuleScript") then
			table.insert(__notes, n .. " is in " .. where.Name .. ", where players can't see it: move it to ReplicatedStorage.")
		end
	end
end

if #__problems == 0 then
	for _, partName in ipairs(__coreParts) do
		local ok, install = pcall(require, __parts[partName])
		if ok and type(install) == "function" then
			local ok2, err = pcall(install, __modules, __require, __hasModule)
			if not ok2 then
				table.insert(__problems, partName .. " failed: " .. tostring(err))
			end
		else
			table.insert(__problems, partName .. " didn't load (was the whole file pasted in? is it the right file?): " .. tostring(install))
		end
	end
end
if #__problems > 0 then
	for _, p in ipairs(__problems) do
		warn("[Spin] " .. p)
	end
	warn("[Spin] Spin Battlegrounds can't start until the server setup is fixed (see above).")
	game:GetService("ReplicatedStorage"):SetAttribute("SpinServerSetupProblem", table.concat(__problems, "\n"))
	return
end
if #__notes > 0 then
	for _, p in ipairs(__notes) do
		warn("[Spin] " .. p)
	end
	__problems = __notes
	game:GetService("ReplicatedStorage"):SetAttribute("SpinServerSetupProblem", table.concat(__problems, "\n"))
end

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

__loadPacks("server")
local ProjectileService = __require("ProjectileService")
local TuskService = __require("TuskService")
local NPCService = __require("NPCService")
local TestDummies = __require("TestDummies")
__require("StandAssetLoader").init()

ProjectileService.MaxActivePerPlayer = 20
TuskService.init()
for _, outfit in ipairs({ "JohnnyOutfit", "GyroOutfit", "DiegoOutfit", "PorkPieOutfit", "SandmanOutfit", "MountainTimOutfit", "HotPantsOutfit", "BlackmoreOutfit", "AxlOutfit", "ValentineOutfit", "DiegoAUOutfit" }) do
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
local function __start(name, ...)
	local args = table.pack(...)
	local ok, err = pcall(function()
		__require(name).init(table.unpack(args, 1, args.n))
	end)
	if not ok then
		warn("[Spin] " .. name .. " failed to start: " .. tostring(err))
	end
end
__start("StandBots", TuskService)
__start("BountyService")
__start("DataService")
__start("WeatherService")
__start("CorpseService", TuskService)
__start("RaceService")
__start("NPCService")
__start("TestDummies")
print("[Spin] Server ready")
