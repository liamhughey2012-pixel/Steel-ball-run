---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# DataService

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `DataService` (capitals matter) |

**What it does:** Saves each player's progress with DataStoreService, so it's still there next time they play: Cash and Bounties (leaderstats) the STABLE: every horse item they've bought (HorseOwned) and what they have on (coat, mane, blanket, saddle, marking, socks, extras) and their horse's name When: it loads when they join; it saves every AutosaveEvery seconds, when they leave, and when the server shuts down (BindToClose). Safety: if their data can't be loaded (DataStore down, or Studio without API access), nothing is saved for them that session, so a failed load can never wipe what they had. Saves use UpdateAsync, retried a few times. Studio: turn on Game Settings > Security > "Enable Studio Access to API Services" (the place must be published) to test saving in Studio. Settings: TuskConfig.Save.

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **DataService**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	DataService  (ServerScriptService.SpinServer.DataService)

	Saves each player's progress with DataStoreService, so it's still there
	next time they play:
	  * Cash and Bounties (leaderstats)
	  * the STABLE: every horse item they've bought (HorseOwned) and what
	    they have on (coat, mane, blanket, saddle, marking, socks, extras)
	    and their horse's name
	When: it loads when they join; it saves every AutosaveEvery seconds,
	when they leave, and when the server shuts down (BindToClose).
	Safety: if their data can't be loaded (DataStore down, or Studio without
	API access), nothing is saved for them that session, so a failed load can
	never wipe what they had. Saves use UpdateAsync, retried a few times.
	Studio: turn on Game Settings > Security > "Enable Studio Access to API
	Services" (the place must be published) to test saving in Studio.
	Settings: TuskConfig.Save.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)

local DataService = {}
local cfg = TuskConfig.Save or {}
local store
local loaded = {} -- [player] = true once their data has loaded (only then do we save)
local VERSION = 1

-- Player attributes that make up the stable.
local HORSE_ATTRS = { "HorseOwned", "HorseCoat", "HorseMane", "HorseBlanket", "HorseSaddle", "HorseMarking", "HorseSocks", "HorseExtras", "HorseName" }

local function keyFor(player)
	return "Player_" .. player.UserId
end

local function retry(fn)
	local lastErr
	for attempt = 1, (cfg.Retries or 3) do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(attempt) -- 1 s, 2 s, ...
	end
	return false, lastErr
end

local function statsOf(player)
	local ls = player:FindFirstChild("leaderstats") or player:WaitForChild("leaderstats", 10)
	return ls and ls:FindFirstChild("Cash"), ls and ls:FindFirstChild("Bounties")
end

-- What we save for a player.
local function snapshot(player)
	local cash, bounties = statsOf(player)
	local horse = {}
	for _, attr in ipairs(HORSE_ATTRS) do
		local v = player:GetAttribute(attr)
		if typeof(v) == "string" and v ~= "" then
			horse[attr] = v
		end
	end
	return {
		Version = VERSION,
		Cash = cash and cash.Value or 0,
		Bounties = bounties and bounties.Value or 0,
		Horse = horse,
		SavedAt = os.time(),
	}
end

local function apply(player, data)
	if typeof(data) ~= "table" then
		return
	end
	local cash, bounties = statsOf(player)
	if cash and typeof(data.Cash) == "number" then
		cash.Value = math.max(0, math.floor(data.Cash))
	end
	if bounties and typeof(data.Bounties) == "number" then
		bounties.Value = math.max(0, math.floor(data.Bounties))
	end
	if typeof(data.Horse) == "table" then
		for _, attr in ipairs(HORSE_ATTRS) do
			local v = data.Horse[attr]
			if typeof(v) == "string" and v ~= "" then
				player:SetAttribute(attr, v)
			end
		end
	end
end

function DataService.load(player)
	if not store then
		return false
	end
	local ok, data = retry(function()
		return store:GetAsync(keyFor(player))
	end)
	if not player.Parent then
		return false
	end
	if not ok then
		warn("[DataService] couldn't load " .. player.Name .. "'s data (" .. tostring(data) .. "); this session won't be saved.")
		player:SetAttribute("DataLoaded", false)
		return false
	end
	apply(player, data)
	loaded[player] = true
	player:SetAttribute("DataLoaded", true)
	return true
end

function DataService.save(player)
	if not store or not loaded[player] then
		return false
	end
	local data = snapshot(player)
	local ok, err = retry(function()
		return store:UpdateAsync(keyFor(player), function()
			return data
		end)
	end)
	if not ok then
		warn("[DataService] couldn't save " .. player.Name .. "'s data: " .. tostring(err))
	end
	return ok
end

function DataService.init()
	if cfg.Enabled == false then
		return
	end
	local ok, result = pcall(function()
		return game:GetService("DataStoreService"):GetDataStore(cfg.StoreName or "SpinPlayerData_v1")
	end)
	if not ok then
		warn("[DataService] DataStores aren't available (" .. tostring(result) .. "). Progress won't be saved." .. (RunService:IsStudio() and " In Studio, turn on Game Settings > Security > Enable Studio Access to API Services." or ""))
		return
	end
	store = result
	local function onPlayer(player)
		task.spawn(DataService.load, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		DataService.save(player)
		loaded[player] = nil
	end)
	-- Autosave.
	task.spawn(function()
		while true do
			task.wait(cfg.AutosaveEvery or 120)
			for _, p in ipairs(Players:GetPlayers()) do
				task.spawn(DataService.save, p)
			end
		end
	end)
	-- Server shutting down: save everyone before it closes.
	game:BindToClose(function()
		local pending = 0
		for _, p in ipairs(Players:GetPlayers()) do
			pending = pending + 1
			task.spawn(function()
				DataService.save(p)
				pending = pending - 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
end

return DataService
```
