--[[
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

-- The core is split into ModuleScripts (8 parts) so it pastes quickly.
-- They're found by name (ReplicatedStorage > SpinCore is the tidy place for them).
local __coreParts = { "SpinCore_Client_1", "SpinCore_Client_2", "SpinCore_Client_3", "SpinCore_Client_4", "SpinCore_Client_5", "SpinCore_Client_6", "SpinCore_Client_7", "SpinCore_Client_8" }
local function __findPart(name)
	for _, root in ipairs({ game:GetService("ReplicatedStorage"), game:GetService("ReplicatedFirst") }) do
		local found = root:FindFirstChild(name, true)
		if found then
			return found
		end
	end
	return nil
end
local __coreOk = true
for _, partName in ipairs(__coreParts) do
	local part = __findPart(partName)
	local waited = 0
	while not part and waited < 15 do
		task.wait(0.5)
		waited = waited + 0.5
		part = __findPart(partName)
	end
	if not part then
		__coreOk = false
		warn("[Spin] Missing " .. partName .. ": make a ModuleScript named " .. partName .. " in ReplicatedStorage > SpinCore and paste " .. partName .. ".lua into it.")
	elseif not part:IsA("ModuleScript") then
		__coreOk = false
		warn("[Spin] " .. part:GetFullName() .. " is a " .. part.ClassName .. ". It must be a ModuleScript: delete it, insert a ModuleScript with the same name, and paste the code into that.")
	else
		local ok, install = pcall(require, part)
		if ok and type(install) == "function" then
			local ok2, err = pcall(install, __modules, __require, __hasModule)
			if not ok2 then
				__coreOk = false
				warn("[Spin] " .. partName .. " failed: " .. tostring(err))
			end
		else
			__coreOk = false
			warn("[Spin] " .. partName .. " didn't load (was the whole file pasted in?): " .. tostring(install))
		end
	end
end
if not __coreOk then
	warn("[Spin] Some core parts are missing or broken (see above), so Spin can't start. Every SpinCore_Client_N part has to be there.")
	return
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

-- No waiting on the folder (it's optional): just make sure the game has loaded.
if not game:IsLoaded() then
	game.Loaded:Wait()
end
__loadPacks("client")
-- Each system starts on its own: if one fails, the rest (HUD, menus, bounty
-- board) still work, and the Output window says what went wrong.
local function __start(name)
	local ok, err = pcall(function()
		__require(name).init()
	end)
	if not ok then
		warn("[Spin] " .. name .. " failed to start: " .. tostring(err))
	end
end
for _, name in ipairs({ "SettingsUI", "HitFX", "TuskStand", "TuskProjectiles", "TuskSneakController", "TuskController", "WorldClient", "CharacterCard", "CombatUI", "DefenseClient", "BountyUI", "WeatherClient", "CorpseClient", "RaceClient" }) do
	__start(name)
end
print("[Spin] Client ready")
