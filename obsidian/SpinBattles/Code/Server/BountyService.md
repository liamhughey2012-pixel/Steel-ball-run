---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# BountyService

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `BountyService` (capitals matter) |

**What it does:** The BOUNTY BOARD by the spawn (owner's design): a blocky board: two brown posts with grass at their feet, a brown plank back, and parchment wanted posters pinned on it. The posters on the board show the faces of the current top bounties. walk up and press E ("View Bounties"): the client opens the board UI with a wanted poster for every other player and every Stand-user NPC accept one: you get a bounty tracker and a TARGET marker on them. Land the killing blow (your hit within KillCreditTime) and you're paid in Cash (leaderstats). Players are worth more the longer their kill streak. Bounties run out after Duration seconds. JOBS tab: a few paid tasks (the same for everyone, new ones every 10 minutes): take down NPCs, deal damage, perfect blocks / dodges, claim bounties, take a corpse part... Progress counts on its own; you're paid the moment one's done SHOP tab: spend Cash on bandages, a speed tonic, a lucky horseshoe (faster ultimate), a corpse compass, or CLEAR YOUR NAME (wipes your streak and any price on your head) STABLE (in the SHOP): buy and pick your horse's coat and saddle blanket (you ride it with M and race on it) PUT A PRICE ON THEIR HEAD: from a player's contract, pay to raise their bounty. Whoever takes them down next is paid it Numbers: TuskConfig.Bounty. Remote: Net "Bounty".

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **BountyService**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	BountyService  (ServerScriptService.SpinServer.BountyService)

	The BOUNTY BOARD by the spawn (owner's design):
	  * a blocky board: two brown posts with grass at their feet, a brown
	    plank back, and parchment wanted posters pinned on it. The posters on
	    the board show the faces of the current top bounties.
	  * walk up and press E ("View Bounties"): the client opens the board UI
	    with a wanted poster for every other player and every Stand-user NPC
	  * accept one: you get a bounty tracker and a TARGET marker on them.
	    Land the killing blow (your hit within KillCreditTime) and you're paid
	    in Cash (leaderstats). Players are worth more the longer their kill
	    streak. Bounties run out after Duration seconds.
	  * JOBS tab: a few paid tasks (the same for everyone, new ones every 10
	    minutes): take down NPCs, deal damage, perfect blocks / dodges,
	    claim bounties, take a corpse part... Progress counts on its own;
	    you're paid the moment one's done
	  * SHOP tab: spend Cash on bandages, a speed tonic, a lucky horseshoe
	    (faster ultimate), a corpse compass, or CLEAR YOUR NAME (wipes your
	    streak and any price on your head)
	  * STABLE (in the SHOP): buy and pick your horse's coat and saddle
	    blanket (you ride it with M and race on it)
	  * PUT A PRICE ON THEIR HEAD: from a player's contract, pay to raise
	    their bounty. Whoever takes them down next is paid it
	Numbers: TuskConfig.Bounty. Remote: Net "Bounty".
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Net = require(Shared.Net)
local Adapter = require(script.Parent.CombatAdapter)

local BountyService = {}
local cfg = TuskConfig.Bounty or {}
local Remote
local active = {} -- [hunter Player] = bounty
local npcIds = setmetatable({}, { __mode = "k" }) -- [model] = id
local npcById = {} -- [id] = model
local nextNpcId = 0
local posterGuis = {} -- the posters on the physical board

local WOOD = Color3.fromRGB(112, 74, 44)
local WOOD_DARK = Color3.fromRGB(88, 57, 34)
local WOOD_LIGHT = Color3.fromRGB(130, 88, 54)
local GRASS = Color3.fromRGB(88, 125, 52)
local PAPER = Color3.fromRGB(234, 205, 160) -- "skin colour" parchment
local INK = Color3.fromRGB(60, 36, 20)
local NAIL = Color3.fromRGB(60, 58, 62)

---------------------------------------------------------------------------
-- The board model
---------------------------------------------------------------------------
local function block(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function posterGui(poster)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.6
	gui.Parent = poster
	local function text(name, y, h, size, font, value)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.05, y)
		l.Size = UDim2.fromScale(0.9, h)
		l.Font = font
		l.TextScaled = true
		l.TextColor3 = INK
		l.Text = value
		l.Parent = gui
		return l
	end
	text("Title", 0.03, 0.14, 1, Enum.Font.Bangers, "WANTED")
	local photo = Instance.new("ImageLabel")
	photo.Name = "Photo"
	photo.BackgroundColor3 = Color3.fromRGB(205, 175, 130)
	photo.BorderSizePixel = 0
	photo.Position = UDim2.fromScale(0.15, 0.19)
	photo.Size = UDim2.fromScale(0.7, 0.45)
	photo.ImageColor3 = Color3.fromRGB(235, 215, 185) -- old-photo tint
	photo.Parent = gui
	text("PosterName", 0.66, 0.12, 1, Enum.Font.GothamBlack, "")
	text("Reward", 0.8, 0.14, 1, Enum.Font.Bangers, "")
	return gui
end

local function buildBoard(cf)
	local model = Instance.new("Model")
	model.Name = "BountyBoard"
	-- Two posts on grassy mounds.
	for _, x in ipairs({ -4.2, 4.2 }) do
		block(model, "Post", Vector3.new(0.9, 8.6, 0.9), cf * CFrame.new(x, 4.3, 0.6), WOOD_DARK)
		block(model, "Grass", Vector3.new(2.2, 0.5, 2.2), cf * CFrame.new(x, 0.25, 0.6), GRASS, Enum.Material.Grass)
		block(model, "Grass", Vector3.new(1.4, 0.8, 1.2), cf * CFrame.new(x + 0.3, 0.4, 0.9), GRASS, Enum.Material.Grass)
	end
	-- Plank back: uneven planks, ends sticking out like the picture.
	local planks = {
		{ 7.9, 11.2, 0.4, 0.03 }, { 6.8, 10.4, -0.3, -0.02 }, { 5.7, 10.9, 0.2, 0.015 }, { 4.6, 10.2, -0.1, -0.03 },
	}
	for i, pl in ipairs(planks) do
		block(model, "Plank", Vector3.new(pl[2], 1.08, 0.35), cf * CFrame.new(pl[3], pl[1], 0) * CFrame.Angles(0, 0, pl[4]), i % 2 == 0 and WOOD or WOOD_LIGHT, Enum.Material.WoodPlanks)
	end
	-- Title board on top.
	local title = block(model, "Title", Vector3.new(6, 1.2, 0.3), cf * CFrame.new(0, 9.2, -0.05), WOOD_DARK, Enum.Material.WoodPlanks)
	local tg = Instance.new("SurfaceGui")
	tg.Face = Enum.NormalId.Front
	tg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	tg.PixelsPerStud = 50
	tg.Parent = title
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Font = Enum.Font.Bangers
	tl.TextScaled = true
	tl.TextColor3 = PAPER
	tl.TextStrokeTransparency = 0.4
	tl.Text = "BOUNTIES"
	tl.Parent = tg
	-- Parchment posters pinned on the front.
	local spots = { { -3.3, 6.5, 0.06 }, { -1.1, 6.9, -0.04 }, { 1.2, 6.4, 0.05 }, { 3.4, 6.8, -0.06 }, { 0, 4.7, 0.02 } }
	for i, sp in ipairs(spots) do
		local poster = block(model, "Poster", Vector3.new(1.8, 2.3, 0.05), cf * CFrame.new(sp[1], sp[2], -0.22) * CFrame.Angles(0, 0, sp[3]), PAPER, Enum.Material.SmoothPlastic)
		block(model, "Nail", Vector3.new(0.14, 0.14, 0.1), poster.CFrame * CFrame.new(0, 1.0, -0.05), NAIL, Enum.Material.Metal)
		posterGuis[i] = posterGui(poster)
	end
	-- The prompt.
	local hit = block(model, "PromptPart", Vector3.new(8, 5, 1), cf * CFrame.new(0, 5.5, -0.6), WOOD)
	hit.Transparency = 1
	hit.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "View Bounties"
	prompt.ObjectText = "Bounty Board"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = hit
	model.PrimaryPart = hit
	return model, prompt
end

---------------------------------------------------------------------------
-- Bounties
---------------------------------------------------------------------------
local function leaderstats(player)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = player
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Value = cfg.StartingCash or 0
		cash.Parent = ls
		local claimed = Instance.new("IntValue")
		claimed.Name = "Bounties"
		claimed.Value = 0
		claimed.Parent = ls
	end
	return ls
end

local function aliveModel(model)
	local h = model and model.Parent and model:FindFirstChildOfClass("Humanoid")
	return h and h.Health > 0
end

local function npcId(model)
	local id = npcIds[model]
	if not id then
		nextNpcId = nextNpcId + 1
		id = "N" .. nextNpcId
		npcIds[model] = id
		npcById[id] = model
	end
	return id
end

-- RETRIEVE contracts for the Saint's Corpse parts (CorpseService).
local Corpse
local function corpseService()
	if Corpse == nil then
		-- (Wrapped in a function so the bundler can rewrite the require.)
		local ok, mod = pcall(function()
			return require(script.Parent.CorpseService)
		end)
		Corpse = ok and mod or false
	end
	return Corpse or nil
end

local function retrieveBounties(viewer)
	local C = corpseService()
	local corpse = TuskConfig.Corpse
	if not C or not corpse or corpse.Enabled == false then
		return {}
	end
	local list = {}
	for _, info in ipairs(C.parts()) do
		local where = C.where(info.Id)
		-- (Nothing to retrieve if you're the one holding it.)
		if where and where.Holder ~= viewer then
			table.insert(list, {
				Key = "C" .. info.Id,
				Kind = "Corpse",
				Part = info.Id,
				Name = "SAINT'S CORPSE: " .. info.Name,
				Reward = (corpse.RetrieveRewards or {})[info.Id] or corpse.RetrieveReward or 120,
				HeldBy = where.Holder and where.Holder.DisplayName or nil,
				Boost = info.Text,
			})
		end
	end
	return list
end

-- Every bounty on offer (optionally hiding the viewer).
local function listBounties(viewer)
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= viewer and aliveModel(p.Character) then
			local streak = p:GetAttribute("KillStreak") or 0
			-- Saint's Corpse holders are worth more (the Heart and Head most of all).
			local corpse = TuskConfig.Corpse or {}
			local parts = p.Character:GetAttribute("CorpseParts")
			local bonus, names = 0, {}
			if p.Character:GetAttribute("CorpseComplete") then
				bonus = bonus + (corpse.CompleteBounty or 500)
			end
			for id in string.gmatch(parts or "", "[^,]+") do
				bonus = bonus + ((corpse.BigParts or {})[id] or corpse.PartBounty or 40)
				for _, info in ipairs(corpse.Parts or {}) do
					if info.Id == id then
						table.insert(names, info.Name)
					end
				end
			end
			table.insert(list, {
				Key = "P" .. p.UserId,
				Kind = "Player",
				UserId = p.UserId,
				Name = p.DisplayName,
				Reward = (cfg.BaseReward or 100) + streak * (cfg.StreakReward or 50) + bonus + (p:GetAttribute("PlacedBounty") or 0),
				Streak = streak,
				Placed = (p:GetAttribute("PlacedBounty") or 0) > 0 and p:GetAttribute("PlacedBounty") or nil,
				Act = p.Character:GetAttribute("TuskAct"),
				Corpse = #names > 0 and table.concat(names, ", ") or nil,
			})
		end
	end
	for _, model in ipairs(CollectionService:GetTagged("SpinFighter")) do
		if aliveModel(model) then
			local h = model:FindFirstChildOfClass("Humanoid")
			-- NPCs carrying corpse parts are worth more too.
			local corpse = TuskConfig.Corpse or {}
			local bonus, names = 0, {}
			if model:GetAttribute("CorpseComplete") then
				bonus = bonus + (corpse.CompleteBounty or 500)
			end
			for id in string.gmatch(model:GetAttribute("CorpseParts") or "", "[^,]+") do
				bonus = bonus + ((corpse.BigParts or {})[id] or corpse.PartBounty or 40)
				for _, info in ipairs(corpse.Parts or {}) do
					if info.Id == id then
						table.insert(names, info.Name)
					end
				end
			end
			table.insert(list, {
				Key = npcId(model),
				Kind = "NPC",
				Model = model,
				Name = h.DisplayName ~= "" and h.DisplayName or model.Name,
				Reward = (cfg.NPCReward or 75) + bonus,
				Act = model:GetAttribute("TuskAct"),
				Corpse = #names > 0 and table.concat(names, ", ") or nil,
			})
		end
	end
	for _, entry in ipairs(retrieveBounties(viewer)) do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		return a.Reward > b.Reward
	end)
	while #list > (cfg.MaxPosters or 12) + 8 do
		table.remove(list)
	end
	return list
end

local function send(player, kind, data)
	Remote:FireClient(player, kind, data)
end

local function publicBounty(b)
	return { Key = b.Key, Kind = b.Kind, UserId = b.UserId, Model = b.Model, Name = b.Name, Reward = b.Reward, Expires = b.Expires, Act = b.Act, Corpse = b.Corpse, Part = b.Part, HeldBy = b.HeldBy, Boost = b.Boost, Placed = b.Placed }
end

---------------------------------------------------------------------------
-- Cash
---------------------------------------------------------------------------
local function cashOf(player)
	local cash = leaderstats(player):FindFirstChild("Cash")
	return cash and cash.Value or 0
end

local function pay(player, amount)
	local cash = leaderstats(player):FindFirstChild("Cash")
	if cash then
		cash.Value = cash.Value + math.floor(amount + 0.5)
	end
end

local function spend(player, amount)
	local cash = leaderstats(player):FindFirstChild("Cash")
	if not cash or cash.Value < amount then
		return false
	end
	cash.Value = cash.Value - amount
	return true
end

local function isRealPlayer(p)
	return typeof(p) == "Instance" and p:IsA("Player")
end

---------------------------------------------------------------------------
-- JOBS
---------------------------------------------------------------------------
local jobs = {} -- the current jobs: { Key, Type, Text, Goal, Reward }
local jobsUntil = 0
local progress = setmetatable({}, { __mode = "k" }) -- [player] = { Count = {}, Done = {} }
local jobSerial = 0

local function rollJobs()
	local jc = cfg.Jobs
	if not jc or not jc.Types then
		return
	end
	local pool = table.clone(jc.Types)
	jobs = {}
	for _ = 1, math.min(jc.Count or 3, #pool) do
		local t = table.remove(pool, math.random(1, #pool))
		local goal = math.random(t.Goal[1], t.Goal[2])
		if goal >= 100 then
			goal = math.floor(goal / 50 + 0.5) * 50
		end
		jobSerial = jobSerial + 1
		table.insert(jobs, { Key = "J" .. jobSerial, Type = t.Id, Text = (goal == 1 and t.One) or string.format(t.Text, goal), Goal = goal, Reward = math.max(10, math.floor(goal * t.PayEach + 0.5)) })
	end
	jobsUntil = workspace:GetServerTimeNow() + (jc.RefreshEvery or 600)
	progress = setmetatable({}, { __mode = "k" })
end

local function jobProgress(player, jobType, amount)
	if not isRealPlayer(player) or not amount or amount <= 0 then
		return
	end
	local p = progress[player]
	if not p then
		p = { Count = {}, Done = {} }
		progress[player] = p
	end
	for _, job in ipairs(jobs) do
		if job.Type == jobType and not p.Done[job.Key] then
			p.Count[job.Key] = math.min(job.Goal, (p.Count[job.Key] or 0) + amount)
			if p.Count[job.Key] >= job.Goal then
				p.Done[job.Key] = true
				pay(player, job.Reward)
				send(player, "JobDone", { Text = job.Text, Reward = job.Reward })
			end
		end
	end
end
BountyService.jobProgress = jobProgress

local function jobsFor(player)
	local p = progress[player] or { Count = {}, Done = {} }
	local list = {}
	for _, job in ipairs(jobs) do
		table.insert(list, { Key = job.Key, Text = job.Text, Goal = job.Goal, Reward = job.Reward, Progress = math.floor(p.Count[job.Key] or 0), Done = p.Done[job.Key] == true })
	end
	return list
end

---------------------------------------------------------------------------
-- SHOP
---------------------------------------------------------------------------
local function shopItem(id)
	for _, item in ipairs(cfg.Shop or {}) do
		if item.Id == id then
			return item
		end
	end
	return nil
end

local function clearCost(player, item)
	local streak = player:GetAttribute("KillStreak") or 0
	local placed = player:GetAttribute("PlacedBounty") or 0
	if streak <= 0 and placed <= 0 then
		return 0
	end
	return (item.BaseCost or 50) + streak * (item.PerStreak or 50) + placed
end

local function shopFor(player)
	local list = {}
	local character = player.Character
	local t = workspace:GetServerTimeNow()
	for _, item in ipairs(cfg.Shop or {}) do
		local price = item.Id == "ClearName" and clearCost(player, item) or item.Price
		local untilT = character and ({
			Tonic = character:GetAttribute("ShopTonicUntil"),
			Horseshoe = character:GetAttribute("ShopUltUntil"),
			Compass = character:GetAttribute("CompassUntil"),
		})[item.Id]
		table.insert(list, {
			Id = item.Id, Name = item.Name, Text = item.Text, Icon = item.Icon, Price = price,
			Active = untilT and untilT > t and untilT or nil,
			Clean = item.Id == "ClearName" and price == 0 or nil,
		})
	end
	return list
end

local function buy(player, id)
	local item = typeof(id) == "string" and shopItem(id)
	if not item then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local alive = humanoid and humanoid.Health > 0
	local price = item.Id == "ClearName" and clearCost(player, item) or item.Price
	if item.Id == "ClearName" and price <= 0 then
		send(player, "Denied", { Reason = "Your name is already clean." })
		return
	end
	if item.Id ~= "ClearName" and not alive then
		send(player, "Denied", { Reason = "You can't use that right now." })
		return
	end
	if item.Heal and humanoid.Health >= humanoid.MaxHealth then
		send(player, "Denied", { Reason = "You're not hurt." })
		return
	end
	if not spend(player, price) then
		send(player, "Denied", { Reason = "Not enough Cash ($" .. price .. ")." })
		return
	end
	local t = workspace:GetServerTimeNow()
	if item.Heal then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + item.Heal)
	elseif item.Speed then
		local token = tostring({})
		character:SetAttribute("ShopTonicUntil", t + item.Time)
		character:SetAttribute("ShopTonicToken", token)
		Adapter.setMoveModifier(humanoid, "ShopTonic", item.Speed)
		task.delay(item.Time, function()
			if humanoid.Parent and character:GetAttribute("ShopTonicToken") == token then
				Adapter.setMoveModifier(humanoid, "ShopTonic", nil)
				character:SetAttribute("ShopTonicUntil", nil)
			end
		end)
	elseif item.UltGain then
		character:SetAttribute("ShopUltGain", item.UltGain)
		character:SetAttribute("ShopUltUntil", t + item.Time)
	elseif item.Id == "Compass" then
		character:SetAttribute("CompassUntil", t + item.Time)
	elseif item.Id == "ClearName" then
		player:SetAttribute("KillStreak", 0)
		player:SetAttribute("PlacedBounty", nil)
	end
	send(player, "Bought", { Name = item.Name, Price = price })
end

---------------------------------------------------------------------------
-- STABLE (in the SHOP): horse coats and saddle blankets. Bought ones are
-- yours for the session; the equipped ones are what you ride (M) and race.
---------------------------------------------------------------------------
local hcfg = TuskConfig.Horses or {}

local function owned(player)
	local set = {}
	for id in string.gmatch(player:GetAttribute("HorseOwned") or "", "[^,]+") do
		set[id] = true
	end
	return set
end

local function stableFor(player)
	local have = owned(player)
	local coat = player:GetAttribute("HorseCoat") or ((hcfg.Coats or {})[1] or {}).Id
	local blanket = player:GetAttribute("HorseBlanket") or ((hcfg.Blankets or {})[1] or {}).Id
	local coats, blankets = {}, {}
	for _, c in ipairs(hcfg.Coats or {}) do
		table.insert(coats, { Id = c.Id, Name = c.Name, Price = c.Price, Body = c.Body, Mane = c.Mane, Material = c.Material, Socks = c.Socks, Owned = c.Price <= 0 or have["Coat:" .. c.Id] == true, Equipped = c.Id == coat })
	end
	for _, b in ipairs(hcfg.Blankets or {}) do
		table.insert(blankets, { Id = b.Id, Name = b.Name, Price = b.Price, Color = b.Color, Owned = b.Price <= 0 or have["Blanket:" .. b.Id] == true, Equipped = b.Id == blanket })
	end
	return { Coats = coats, Blankets = blankets }
end

local function stableItem(key)
	local kind, id = string.match(tostring(key), "^(%a+):(%w+)$")
	local list = kind == "Coat" and hcfg.Coats or (kind == "Blanket" and hcfg.Blankets or nil)
	for _, item in ipairs(list or {}) do
		if item.Id == id then
			return kind, item
		end
	end
	return nil
end

local function buyHorse(player, key)
	local kind, item = stableItem(key)
	if not item then
		return
	end
	local have = owned(player)
	if item.Price > 0 and not have[kind .. ":" .. item.Id] then
		if not spend(player, item.Price) then
			send(player, "Denied", { Reason = "Not enough Cash ($" .. item.Price .. ")." })
			return
		end
		local list = player:GetAttribute("HorseOwned")
		player:SetAttribute("HorseOwned", (list and list ~= "" and (list .. ",") or "") .. kind .. ":" .. item.Id)
		send(player, "Bought", { Name = item.Name .. (kind == "Coat" and " HORSE" or " BLANKET"), Price = item.Price })
	end
	player:SetAttribute(kind == "Coat" and "HorseCoat" or "HorseBlanket", item.Id)
	-- Riding your horse right now? It changes straight away.
	local ok, Race = pcall(function()
		return require(script.Parent.RaceService)
	end)
	if ok and Race and Race.refreshHorse then
		Race.refreshHorse(player)
	end
end

---------------------------------------------------------------------------
-- PUT A PRICE ON THEIR HEAD
---------------------------------------------------------------------------
local function place(player, key)
	if typeof(key) ~= "string" or key:sub(1, 1) ~= "P" then
		return
	end
	local target = Players:GetPlayerByUserId(tonumber(key:sub(2)) or 0)
	if not target or target == player then
		send(player, "Denied", { Reason = "You can't do that." })
		return
	end
	local amount = cfg.PlaceAmount or 100
	local placed = target:GetAttribute("PlacedBounty") or 0
	if placed + amount > (cfg.PlaceMax or 2000) then
		send(player, "Denied", { Reason = "There's already a huge price on " .. target.DisplayName .. "'s head." })
		return
	end
	if not spend(player, amount) then
		send(player, "Denied", { Reason = "Not enough Cash ($" .. amount .. ")." })
		return
	end
	target:SetAttribute("PlacedBounty", placed + amount)
	send(player, "Placed", { Name = target.DisplayName, Amount = amount, Total = placed + amount })
	send(target, "Warned", { By = player.DisplayName, Total = placed + amount })
end

local function accept(player, key)
	if typeof(key) ~= "string" then
		return
	end
	for _, entry in ipairs(listBounties(player)) do
		if entry.Key == key then
			local b = entry
			b.Expires = workspace:GetServerTimeNow() + (cfg.Duration or 300)
			active[player] = b
			send(player, "Active", publicBounty(b))
			return
		end
	end
	send(player, "Lost", { Reason = "That bounty isn't on the board any more." })
end

local function targetsThis(b, victimPlayer, model)
	if b.Kind == "Player" then
		return victimPlayer ~= nil and victimPlayer.UserId == b.UserId
	end
	return b.Model == model
end

local function onDeath(model)
	local victimPlayer = Players:GetPlayerFromCharacter(model)
	local killerId = model:GetAttribute("LastAttackerId")
	local when = model:GetAttribute("LastAttackTime") or -math.huge
	if workspace:GetServerTimeNow() - when > (cfg.KillCreditTime or 6) then
		killerId = nil
	end
	local killer = killerId and Players:GetPlayerByUserId(killerId)
	-- Kill streaks (they make players worth more on the board).
	if victimPlayer then
		victimPlayer:SetAttribute("KillStreak", 0)
	end
	if killer and killer ~= victimPlayer then
		killer:SetAttribute("KillStreak", (killer:GetAttribute("KillStreak") or 0) + 1)
		jobProgress(killer, victimPlayer and "PlayerKills" or "NPCKills", 1)
	end
	-- A price on their head: whoever took them down gets it (a contract on
	-- them already includes it), and it's gone.
	local placed = victimPlayer and victimPlayer:GetAttribute("PlacedBounty") or 0
	if victimPlayer and placed > 0 then
		victimPlayer:SetAttribute("PlacedBounty", nil)
		local b = killer and active[killer]
		if killer and killer ~= victimPlayer and not (b and targetsThis(b, victimPlayer, model)) then
			pay(killer, placed)
			send(killer, "Complete", { Name = victimPlayer.DisplayName, Reward = placed, Price = true })
		end
	end
	for hunter, b in pairs(active) do
		if targetsThis(b, victimPlayer, model) then
			if killer == hunter then
				local ls = leaderstats(hunter)
				local cash, claimed = ls:FindFirstChild("Cash"), ls:FindFirstChild("Bounties")
				if cash then
					cash.Value = cash.Value + b.Reward
				end
				if claimed then
					claimed.Value = claimed.Value + 1
				end
				active[hunter] = nil
				send(hunter, "Complete", { Name = b.Name, Reward = b.Reward })
				jobProgress(hunter, "Bounties", 1)
			elseif b.Kind == "NPC" then
				active[hunter] = nil
				send(hunter, "Lost", { Reason = "Someone else took down " .. b.Name .. "." })
			end
		end
	end
end

local function watchCharacter(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.Died:Connect(function()
			onDeath(model)
		end)
	end
end

local shownOn = {} -- [poster index] = model whose face it shows

-- An NPC's face on a poster: the model copied into a ViewportFrame.
local function setFace(photo, model)
	local old = photo:FindFirstChild("Face")
	if old then
		old:Destroy()
	end
	local head = model and model:FindFirstChild("Head")
	if not head then
		return
	end
	local was = model.Archivable
	model.Archivable = true
	local ok, copy = pcall(function()
		return model:Clone()
	end)
	model.Archivable = was
	if not ok or not copy then
		return
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	local view = Instance.new("ViewportFrame")
	view.Name = "Face"
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(1, 1)
	view.Ambient = Color3.fromRGB(190, 175, 160)
	view.Parent = photo
	copy.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	local copyHead = copy:FindFirstChild("Head") or head
	camera.CFrame = CFrame.lookAt((copyHead.CFrame * CFrame.new(0, 0.25, -3.2)).Position, copyHead.Position + Vector3.new(0, 0.1, 0))
	camera.Parent = view
	view.CurrentCamera = camera
end

local function refreshPosters()
	local list = listBounties(nil)
	for i, gui in ipairs(posterGuis) do
		local e = list[i]
		gui.PosterName.Text = e and string.upper(e.Name) or ""
		gui.Reward.Text = e and ("$" .. e.Reward) or "NO BOUNTY"
		gui.Photo.Image = (e and e.Kind == "Player") and ("rbxthumb://type=AvatarHeadShot&id=" .. e.UserId .. "&w=150&h=150") or ""
		gui.Photo.BackgroundTransparency = e and 0 or 0.6
		local model = e and e.Kind == "NPC" and e.Model or nil
		if shownOn[i] ~= model then
			shownOn[i] = model
			setFace(gui.Photo, model)
		end
	end
end

function BountyService.init()
	if cfg.Enabled == false then
		return
	end
	Remote = Net.get("Bounty")
	-- Board by the spawn (or by any SpawnLocation without the map).
	local map = workspace:FindFirstChild("SBRMap")
	local base
	if map then
		base = (map:GetAttribute("Origin") or Vector3.new()) + (cfg.BoardOffset or Vector3.new(-20, 0, 140))
	else
		local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		base = spawn and (spawn.Position + Vector3.new(-14, -0.5, -8)) or Vector3.new(-20, 0, 0)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ground = workspace:Raycast(base + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), params)
	if ground then
		base = ground.Position
	end
	local facing = cfg.BoardFacing or Vector3.new(1, 0, 0.5)
	local model, prompt = buildBoard(CFrame.lookAt(base, base + Vector3.new(facing.X, 0, facing.Z)))
	model.Parent = map or workspace

	rollJobs()
	local function boardData(player)
		return {
			Bounties = listBounties(player),
			Active = active[player] and publicBounty(active[player]) or nil,
			Jobs = jobsFor(player),
			JobsUntil = jobsUntil,
			Shop = shopFor(player),
			Stable = stableFor(player),
			PlaceAmount = cfg.PlaceAmount or 100,
		}
	end
	prompt.Triggered:Connect(function(player)
		send(player, "Open", boardData(player))
	end)
	-- Jobs progress from fights.
	Adapter.on("Hit", function(attackerPlayer, _, damage)
		jobProgress(attackerPlayer, "Damage", damage)
	end)
	Adapter.on("PerfectBlock", function(defender)
		jobProgress(Players:GetPlayerFromCharacter(defender), "PerfectBlocks", 1)
	end)
	Adapter.on("PerfectDodge", function(dodger)
		jobProgress(Players:GetPlayerFromCharacter(dodger), "PerfectDodges", 1)
	end)
	-- Retrieve contracts: paid the moment the hunter takes that part.
	local C = corpseService()
	if C and C.OnTaken then
		table.insert(C.OnTaken, function(player, partId)
			jobProgress(player, "Corpse", 1)
			local b = active[player]
			if b and b.Kind == "Corpse" and b.Part == partId then
				local ls = leaderstats(player)
				local cash, claimed = ls:FindFirstChild("Cash"), ls:FindFirstChild("Bounties")
				if cash then
					cash.Value = cash.Value + b.Reward
				end
				if claimed then
					claimed.Value = claimed.Value + 1
				end
				active[player] = nil
				send(player, "Complete", { Name = b.Name, Reward = b.Reward })
				jobProgress(player, "Bounties", 1)
			end
		end)
	end
	Remote.OnServerEvent:Connect(function(player, action, key)
		if action == "Accept" then
			accept(player, key)
		elseif action == "Abandon" then
			active[player] = nil
			send(player, "Cleared", {})
		elseif action == "Buy" then
			buy(player, key)
			send(player, "Refresh", boardData(player))
		elseif action == "Place" then
			place(player, key)
			send(player, "Refresh", boardData(player))
		elseif action == "BuyHorse" then
			buyHorse(player, key)
			send(player, "Refresh", boardData(player))
		end
	end)

	local function onPlayer(player)
		leaderstats(player)
		player.CharacterAdded:Connect(watchCharacter)
		if player.Character then
			task.spawn(watchCharacter, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		active[player] = nil
		for hunter, b in pairs(active) do
			if b.Kind == "Player" and b.UserId == player.UserId then
				active[hunter] = nil
				send(hunter, "Lost", { Reason = b.Name .. " left the game." })
			end
		end
	end)
	for _, model in ipairs(CollectionService:GetTagged("SpinFighter")) do
		task.spawn(watchCharacter, model)
	end
	CollectionService:GetInstanceAddedSignal("SpinFighter"):Connect(function(model)
		task.spawn(watchCharacter, model)
	end)

	-- Expiry, vanished NPC targets, and the posters on the board.
	local acc, posterAcc = 0, 5
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		posterAcc = posterAcc + dt
		if acc >= 1 then
			acc = 0
			local now = workspace:GetServerTimeNow()
			if now >= jobsUntil then
				rollJobs()
			end
			for hunter, b in pairs(active) do
				if now > b.Expires then
					active[hunter] = nil
					send(hunter, "Lost", { Reason = "Your bounty on " .. b.Name .. " ran out." })
				elseif b.Kind == "NPC" and not (b.Model and b.Model.Parent) then
					active[hunter] = nil
					send(hunter, "Lost", { Reason = b.Name .. " is gone." })
				end
			end
		end
		if posterAcc >= 5 then
			posterAcc = 0
			refreshPosters()
		end
	end)
end

return BountyService
```
