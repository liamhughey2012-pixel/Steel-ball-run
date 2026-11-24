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
-- MODULE: Blockify
-- ======================================================================
__modules["Blockify"] = function()
--[[
	Blockify  (ReplicatedStorage.SpinShared.Blockify)

	Turns a part-built model into a blocky (classic Roblox) look while
	keeping each model recognisable:
	  * small round pieces (eyes, studs, tips) become single boxes
	  * BIG round pieces (Tusk's egg body, heads, shoulder balls) become a
	    "voxel-round" shape: a core box plus three crossing boxes, so the
	    outline is a stepped, pixel-art circle instead of a plain cube
	  * flat discs (Act 2's rings) stay circular the same stepped way
	  * long cylinders become square rods
	Part centres don't move. The extra boxes are welded to the original part,
	so welds, rigs, fades and animations keep working. Models whose parts are
	moved one by one (the raptor) pass { Voxel = false } for single boxes.
	Used by the Tusk Stands and the Scary Monsters raptor when
	TuskConfig.BlockyModels is true. A part with the attribute KeepRound
	is left alone.
]]

local Blockify = {}

local ROUND = 0.82 -- single box vs. sphere diameter (similar silhouette)
local ROD = 0.88 -- square rod vs. cylinder diameter
local BIG = 0.7 -- studs: round pieces at least this big get the voxel-round shape
local CORE, ARM = 0.86, 0.62 -- voxel-round: core box and the thin side of the crossing boxes

-- A box welded on top of `part`, copying its look.
local function extraBox(part, size)
	local p = Instance.new("Part")
	p.Name = part.Name .. "Block"
	p.Size = size
	p.Color = part.Color
	p.Material = part.Material
	p.Reflectance = part.Reflectance
	p.Transparency = part.Transparency
	p.CastShadow = part.CastShadow
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = part.CFrame
	local weld = Instance.new("Weld")
	weld.Part0 = part
	weld.Part1 = p
	weld.C0 = CFrame.new()
	weld.Parent = p
	p.Parent = part.Parent
	return p
end

-- Stepped round shape for a piece of size s (core + crossing boxes on the axes in `axes`).
local function voxelRound(part, s, axes)
	part.Size = s * CORE
	for _, axis in ipairs(axes) do
		local x = axis == "X" and s.X or s.X * ARM
		local y = axis == "Y" and s.Y or s.Y * ARM
		local z = axis == "Z" and s.Z or s.Z * ARM
		extraBox(part, Vector3.new(x, y, z))
	end
end

local function convert(part, opts)
	if part:GetAttribute("KeepRound") or (opts.KeepRound and opts.KeepRound[part.Name]) then
		return
	end
	local canAdd = opts.Voxel ~= false and part.Parent ~= nil
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.Sphere then
		mesh:Destroy()
		local s = part.Size
		if canAdd and math.max(s.X, s.Y, s.Z) >= BIG then
			voxelRound(part, s, { "X", "Y", "Z" })
		else
			part.Size = s * ROUND
		end
		return
	end
	if part:IsA("Part") then
		if part.Shape == Enum.PartType.Ball then
			part.Shape = Enum.PartType.Block
			local s = part.Size
			if canAdd and s.X >= BIG then
				voxelRound(part, s, { "X", "Y", "Z" })
			else
				part.Size = s * ROUND
			end
		elseif part.Shape == Enum.PartType.Cylinder then
			-- Cylinder length runs along X; its round face is in Y/Z.
			part.Shape = Enum.PartType.Block
			local s = part.Size
			local diameter = math.min(s.Y, s.Z)
			if canAdd and diameter >= BIG and s.X < diameter * 0.6 then
				-- A disc / wheel / ring: keep it round (stepped) in its face.
				part.Size = Vector3.new(s.X, s.Y * CORE, s.Z * CORE)
				extraBox(part, Vector3.new(s.X, s.Y, s.Z * ARM))
				extraBox(part, Vector3.new(s.X, s.Y * ARM, s.Z))
			else
				part.Size = Vector3.new(s.X, s.Y * ROD, s.Z * ROD)
			end
		end
	end
end

-- opts.Voxel = false: single boxes only (for models whose parts are moved one
-- by one, like the raptor rig).
-- opts.KeepRound = { [partName] = true }: signature round pieces left smooth.
function Blockify.apply(model, opts)
	opts = opts or {}
	local parts = {}
	if model:IsA("BasePart") then
		table.insert(parts, model)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	-- (collected first so the boxes added along the way aren't converted again)
	for _, p in ipairs(parts) do
		convert(p, opts)
	end
	return model
end

-- True when the game wants blocky models (TuskConfig.BlockyModels, default on).
function Blockify.enabled(config)
	return not (config and config.BlockyModels == false)
end

return Blockify
end

-- ======================================================================
-- MODULE: BountyService
-- ======================================================================
__modules["BountyService"] = function()
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
	  * PUT A PRICE ON THEIR HEAD: from a player's contract, pay to raise
	    their bounty. Whoever takes them down next is paid it
	Numbers: TuskConfig.Bounty. Remote: Net "Bounty".
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Net = __require("Net")
local Adapter = __require("CombatAdapter")

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
			return __require("CorpseService")
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
end

-- ======================================================================
-- MODULE: CombatAdapter
-- ======================================================================
__modules["CombatAdapter"] = function()
--[[
	CombatAdapter  (ServerScriptService.SpinServer.CombatAdapter)

	THE ONE PLACE the Spin system touches combat. If SPIN BATTLEGROUNDS
	already has a combat framework (damage, stun, block), plug it into the
	Hooks table below instead of letting this file use its defaults. That
	way there is never a second, competing combat system.

	Example (in your own server code, before players join):
		local Adapter = require(ServerScriptService.SpinServer.CombatAdapter)
		Adapter.Hooks.ApplyDamage = function(attacker, humanoid, amount, info)
			YourCombat.Damage(attacker, humanoid, amount)
		end
		Adapter.Hooks.IsBlocking = function(character)
			return YourCombat.IsBlocking(character)
		end
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Net = __require("Net")
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local FX = Net.get("SpinFX")

local Adapter = {}

Adapter.Settings = {
	FriendlyFire = false, -- same-Team players can't hit each other
	BlockAttribute = "Blocking", -- character attribute your block sets
	BlockDamageMultiplier = 0.35,
	BlockKnockbackMultiplier = 0.3,
	IFrameAttribute = "IFrames", -- character attribute = invulnerable (dashes etc.)
	ArmorAttribute = "Armored", -- character attribute = takes damage but no stun/knockback (ult wind-ups)
	MaxKnockback = 90, -- hard cap so no move can fling players across the map
	MaxStun = 1.0, -- hard cap on any single stun
	StunAttribute = "Stunned",
	StunWalkSpeedMultiplier = 0.15,
	StunImmunityAfter = 0.5, -- seconds after a stun ends where no new stun applies
	KnockbackDuration = 0.18,
}

-- Optional overrides. Leave nil to use the defaults in this file.
Adapter.Hooks = {
	ApplyDamage = nil, -- function(attackerPlayer, humanoid, amount, info)
	ApplyStun = nil, -- function(humanoid, duration) -> applied:boolean
	IsBlocking = nil, -- function(character) -> boolean
	CanAct = nil, -- function(player) -> boolean (extra checks: ragdoll, menus...)
	CanBeHit = nil, -- function(attackerPlayer, targetCharacter) -> boolean
}

local moveMods = setmetatable({}, { __mode = "k" }) -- humanoid -> { mods = {}, product = 1 }
local stunState = setmetatable({}, { __mode = "k" }) -- humanoid -> { token, immuneUntil }

function Adapter.getAlive(player)
	local character = player and player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end
	return character, humanoid, root
end

function Adapter.isStunned(character)
	return character:GetAttribute(Adapter.Settings.StunAttribute) == true
end

function Adapter.canAct(player)
	local character = Adapter.getAlive(player)
	if not character then
		return false
	end
	if Adapter.isStunned(character) then
		return false
	end
	-- Turned into Diego's dinosaur (Scary Monsters): Diego is in control.
	if character:GetAttribute("DinoThrall") then
		return false
	end
	-- Frozen in stopped time (The World): can't do anything until it moves again.
	if character:GetAttribute("TimeStopped") then
		return false
	end
	if Adapter.Hooks.CanAct and not Adapter.Hooks.CanAct(player) then
		return false
	end
	return true
end

function Adapter.canBeHit(attackerPlayer, targetCharacter)
	if not targetCharacter or (attackerPlayer and targetCharacter == attackerPlayer.Character) then
		return false
	end
	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	if targetCharacter:GetAttribute(Adapter.Settings.IFrameAttribute) == true then
		return false
	end
	if targetCharacter:FindFirstChildOfClass("ForceField") then
		return false
	end
	-- Diego can't hurt the dinosaur he is commanding.
	if attackerPlayer and targetCharacter:GetAttribute("DinoThrall") == attackerPlayer.UserId then
		return false
	end
	if not Adapter.Settings.FriendlyFire and attackerPlayer then
		local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
		if targetPlayer and not attackerPlayer.Neutral and not targetPlayer.Neutral and targetPlayer.Team == attackerPlayer.Team then
			return false
		end
	end
	if Adapter.Hooks.CanBeHit and not Adapter.Hooks.CanBeHit(attackerPlayer, targetCharacter) then
		return false
	end
	return true
end

-- Stackable walk-speed multipliers keyed by source ("SpinCharge", "Stun"...).
function Adapter.setMoveModifier(humanoid, key, multiplier)
	local state = moveMods[humanoid]
	if not state then
		state = { mods = {}, product = 1 }
		moveMods[humanoid] = state
	end
	local base = humanoid.WalkSpeed / state.product
	state.mods[key] = multiplier
	local product = 1
	for _, m in pairs(state.mods) do
		product = product * m
	end
	state.product = product
	humanoid.WalkSpeed = base * product
end

-- True when the hit comes from in front of the target (blocks only face forward).
function Adapter.isFrontal(attackerPlayer, targetCharacter, info)
	local d = TuskConfig.Defense or {}
	if d.FrontOnly == false then
		return true
	end
	local root = targetCharacter:FindFirstChild("HumanoidRootPart")
	local attacker = attackerPlayer and attackerPlayer.Character
	local from = attacker and attacker:FindFirstChild("HumanoidRootPart")
	local source = from and from.Position or (info and info.Position)
	if not root or not source then
		return true
	end
	local offset = Vector3.new(source.X - root.Position.X, 0, source.Z - root.Position.Z)
	if offset.Magnitude < 0.5 then
		return true
	end
	return root.CFrame.LookVector:Dot(offset.Unit) >= -0.1
end

function Adapter.isBlocking(character)
	if Adapter.Hooks.IsBlocking then
		return Adapter.Hooks.IsBlocking(character) == true
	end
	return character:GetAttribute(Adapter.Settings.BlockAttribute) == true
end

function Adapter.applyStun(humanoid, duration)
	duration = math.min(duration, Adapter.Settings.MaxStun)
	if duration <= 0 then
		return false
	end
	if humanoid.Parent and humanoid.Parent:GetAttribute(Adapter.Settings.ArmorAttribute) == true then
		return false
	end
	if Adapter.Hooks.ApplyStun then
		return Adapter.Hooks.ApplyStun(humanoid, duration)
	end
	local character = humanoid.Parent
	local state = stunState[humanoid] or { token = 0, immuneUntil = 0 }
	stunState[humanoid] = state
	local now = os.clock()
	if now < state.immuneUntil and not Adapter.isStunned(character) then
		return false -- anti stun-lock
	end
	state.token = state.token + 1
	local token = state.token
	character:SetAttribute(Adapter.Settings.StunAttribute, true)
	Adapter.setMoveModifier(humanoid, "Stun", Adapter.Settings.StunWalkSpeedMultiplier)
	task.delay(duration, function()
		if state.token ~= token or not humanoid.Parent then
			return
		end
		character:SetAttribute(Adapter.Settings.StunAttribute, nil)
		Adapter.setMoveModifier(humanoid, "Stun", nil)
		state.immuneUntil = os.clock() + Adapter.Settings.StunImmunityAfter
	end)
	return true
end

function Adapter.applyKnockback(character, direction, strength, upward)
	local root = character:FindFirstChild("HumanoidRootPart")
	strength = math.min(strength or 0, Adapter.Settings.MaxKnockback)
	upward = upward or strength * 0.3
	if not root or (strength <= 0 and upward <= 0) then
		return
	end
	if character:GetAttribute(Adapter.Settings.ArmorAttribute) == true then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		flat = -root.CFrame.LookVector
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "SpinKnockback"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = flat.Unit * strength + Vector3.new(0, math.min(upward, Adapter.Settings.MaxKnockback), 0)
	velocity.Parent = attachment
	Debris:AddItem(attachment, Adapter.Settings.KnockbackDuration)
end

--[[
	dealHit: the only entry point for Spin damage. Server only.
	info = { Damage, Stun, Knockback, Launch?, Direction, Position, Level, Perfect, Source }
	Returns: hit:boolean, damageDealt:number
]]
-- Counter-dodges (e.g. Mountain Tim's Split Dodge): while the target has
-- the attribute, an incoming hit is cancelled and the handler runs instead.
-- Adapter.DodgeHandlers[attributeName] = function(attackerPlayer, target, info)
Adapter.DodgeHandlers = {}

-- Simple events other systems listen to (bounty jobs, the dash):
--   "Hit" (attackerPlayer, target, damage, info)
--   "PerfectBlock" (defenderCharacter, attackerPlayer)
--   "PerfectDodge" (dodgerCharacter, attackerPlayer)
Adapter.Listeners = {}
function Adapter.on(name, fn)
	Adapter.Listeners[name] = Adapter.Listeners[name] or {}
	table.insert(Adapter.Listeners[name], fn)
end
function Adapter.emit(name, ...)
	for _, fn in ipairs(Adapter.Listeners[name] or {}) do
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[CombatAdapter] " .. name .. " listener: " .. tostring(err))
		end
	end
end

function Adapter.dealHit(attackerPlayer, targetCharacter, info)
	if targetCharacter and attackerPlayer and targetCharacter ~= attackerPlayer.Character then
		for attribute, handler in pairs(Adapter.DodgeHandlers) do
			if targetCharacter:GetAttribute(attribute) then
				pcall(handler, attackerPlayer, targetCharacter, info)
				return false
			end
		end
	end
	-- PERFECT DODGE: an attack that would have hit lands during a dash's
	-- dodge window (once per dash).
	if attackerPlayer and targetCharacter and targetCharacter ~= attackerPlayer.Character
		and (targetCharacter:GetAttribute("DashDodgeUntil") or 0) > workspace:GetServerTimeNow()
		and not targetCharacter:GetAttribute("DashDodged") then
		targetCharacter:SetAttribute("DashDodged", true)
		Adapter.emit("PerfectDodge", targetCharacter, attackerPlayer)
		return false
	end
	if not Adapter.canBeHit(attackerPlayer, targetCharacter) then
		return false
	end
	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	local blocked = Adapter.isBlocking(targetCharacter) and Adapter.isFrontal(attackerPlayer, targetCharacter, info)
	local s = Adapter.Settings
	local d = TuskConfig.Defense or {}
	local guardBreak = false
	if blocked then
		local now = workspace:GetServerTimeNow()
		local start = targetCharacter:GetAttribute("BlockStart")
		-- PERFECT BLOCK: no damage, the attacker is stunned.
		if attackerPlayer and start and now - start <= (d.ParryWindow or 0.2) and targetCharacter:GetAttribute("BlockCanParry") then
			targetCharacter:SetAttribute("BlockCanParry", nil)
			local attacker = attackerPlayer.Character
			local ah = attacker and attacker:FindFirstChildOfClass("Humanoid")
			if ah then
				Adapter.applyStun(ah, d.ParryStun or 1)
				local ar = attacker:FindFirstChild("HumanoidRootPart")
				local tr = targetCharacter:FindFirstChild("HumanoidRootPart")
				if ar and tr then
					Adapter.applyKnockback(attacker, ar.Position - tr.Position, 22, 6)
				end
			end
			FX:FireAllClients("Parry", { Defender = targetCharacter, Attacker = attacker, Position = info.Position })
			Adapter.emit("PerfectBlock", targetCharacter, attackerPlayer)
			return false
		end
		-- The guard bar takes the hit; when it runs out the guard breaks.
		local meter = (targetCharacter:GetAttribute("BlockMeter") or d.MaxMeter or 100) - info.Damage * (d.MeterPerDamage or 4)
		targetCharacter:SetAttribute("BlockMeter", math.max(meter, 0))
		targetCharacter:SetAttribute("LastBlockHit", now)
		if meter <= 0 then
			guardBreak = true
			blocked = false
			targetCharacter:SetAttribute(s.BlockAttribute, nil)
			targetCharacter:SetAttribute("GuardBrokenUntil", now + (d.GuardBreakLockout or 3))
			Adapter.setMoveModifier(humanoid, "Block", nil)
		end
	end

	local damage = info.Damage * (blocked and s.BlockDamageMultiplier or 1)
	-- Saint's Corpse boosts: the attacker's damage, the target's resistance.
	local attackerCharacter = attackerPlayer and attackerPlayer.Character
	if attackerCharacter then
		damage = damage * (attackerCharacter:GetAttribute("CorpseDamage") or 1)
		-- Ambush out of sneak: the first hit lands harder (used up).
		if (attackerCharacter:GetAttribute("AmbushUntil") or 0) > workspace:GetServerTimeNow() then
			attackerCharacter:SetAttribute("AmbushUntil", nil)
			damage = damage * ((TuskConfig.Sneak and TuskConfig.Sneak.AmbushMultiplier) or 1.5)
			info.Ambush = true
		end
		-- Counter after a perfect dodge: the next hit lands harder (used up).
		if (attackerCharacter:GetAttribute("CounterUntil") or 0) > workspace:GetServerTimeNow() then
			attackerCharacter:SetAttribute("CounterUntil", nil)
			damage = damage * ((TuskConfig.Defense and TuskConfig.Defense.CounterMultiplier) or 1.4)
			info.Counter = true
		end
	end
	damage = damage * (targetCharacter:GetAttribute("CorpseResist") or 1)
	local knockback = info.Knockback * (blocked and s.BlockKnockbackMultiplier or 1)

	-- Who hit them last (kill credit for bounties and kill streaks).
	if attackerPlayer then
		targetCharacter:SetAttribute("LastAttackerId", attackerPlayer.UserId)
		targetCharacter:SetAttribute("LastAttackTime", workspace:GetServerTimeNow())
	end
	if Adapter.Hooks.ApplyDamage then
		Adapter.Hooks.ApplyDamage(attackerPlayer, humanoid, damage, info)
	else
		humanoid:TakeDamage(damage)
	end
	if guardBreak then
		Adapter.applyStun(humanoid, math.max(info.Stun or 0, d.GuardBreakStun or 1))
		FX:FireAllClients("GuardBreak", { Victim = targetCharacter, Position = info.Position })
	elseif not blocked then
		Adapter.applyStun(humanoid, info.Stun or 0)
	end
	local launch = info.Launch and info.Launch * (blocked and s.BlockKnockbackMultiplier or 1) or nil
	Adapter.applyKnockback(targetCharacter, info.Direction, knockback, launch)

	FX:FireAllClients("Hit", {
		Position = info.Position,
		Level = info.Level,
		Perfect = info.Perfect,
		Blocked = blocked,
		Victim = targetCharacter,
		Source = info.Source,
		AttackerId = attackerPlayer and attackerPlayer.UserId or 0,
	})
	if attackerPlayer and typeof(attackerPlayer) == "Instance" then
		FX:FireClient(attackerPlayer, "Damage", {
			Position = info.Position,
			Amount = math.floor(damage + 0.5),
			Blocked = blocked,
			Perfect = info.Perfect,
		})
	end
	Adapter.emit("Hit", attackerPlayer, targetCharacter, damage, info)
	return true, damage
end

return Adapter
end

-- ======================================================================
-- MODULE: CooldownService
-- ======================================================================
__modules["CooldownService"] = function()
--[[
	CooldownService  (ServerScriptService.SpinServer.CooldownService)
	Server-owned cooldowns. Clients only ever display what the server says.
	Reusable by any ability: CooldownService.start(player, "AbilityKey", seconds)
]]

local Players = game:GetService("Players")

local CooldownService = {}
local readyAt = {} -- [player] = { [key] = os.clock() time when ready }

function CooldownService.remaining(player, key)
	local list = readyAt[player]
	local t = list and list[key]
	if not t then
		return 0
	end
	return math.max(0, t - os.clock())
end

function CooldownService.isReady(player, key)
	return CooldownService.remaining(player, key) <= 0
end

function CooldownService.start(player, key, duration)
	local list = readyAt[player]
	if not list then
		list = {}
		readyAt[player] = list
	end
	list[key] = os.clock() + duration
end

function CooldownService.reset(player, key)
	if readyAt[player] then
		readyAt[player][key] = nil
	end
end

Players.PlayerRemoving:Connect(function(player)
	readyAt[player] = nil
end)

return CooldownService
end

-- ======================================================================
-- MODULE: CorpseMoves
-- ======================================================================
__modules["CorpseMoves"] = function()
--[[
	CorpseMoves  (ServerScriptService.SpinServer.CorpseMoves)

	Every character's CORPSE MOVE (V), unlocked while holding a Saint's
	Corpse part. One shared cooldown (TuskConfig.Corpse.Move.Cooldown); the
	ready time is the character attribute CorpseReadyAt (server time) for
	the HUD. Visuals: CorpseClient, from WorldFX "CorpseMove".
	  Johnny       GOLDEN SPIN NAIL: a huge golden spinning nail
	  Gyro         GOLDEN RECTANGLE: a spinning shockwave straight ahead
	  Diego        DINOSAUR CRASH: leaps to the aim point and slams down
	  Pork Pie     HOOK HARVEST: hooks yank everyone round him in
	  Sandman      SOUND BARRIER: dashes through enemies, then a blast
	  Mountain Tim LASSO CYCLONE: a spinning lasso pulls everyone in
	  Hot Pants    FLESH COCOON: heals and armours herself, then a burst
	  Blackmore    RAIN CURTAIN: a cone of frozen drops that cut and slow
	  Axl RO       GUILT FLOOD: guilt for everyone round him, and a hit
	  Valentine    CORPSE BLESSING: a few seconds untouchable, a heal, a pulse
	  Diego (AU)   REVOLVER: draws a six-shooter, fans six shots where he aims
	With the COMPLETE corpse (all 8 parts), V is THE SAINT'S MIRACLE instead
	(TuskConfig.Corpse.Miracle), and afterwards every part scatters.
	All damage goes through S.hit (CombatAdapter).
]]

local Shared = nil -- (bundled: modules are inlined)
local Registry = __require("TuskActRegistry")
local Net = __require("Net")
local Moves = __require("TuskMoves")

local CorpseMoves = {}

local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
CorpseMoves.Names = TuskConfig.Corpse.MoveNames

local WorldFX
local function fx(data)
	WorldFX = WorldFX or Net.get("WorldFX")
	WorldFX:FireAllClients("CorpseMove", data)
end

local function now()
	return workspace:GetServerTimeNow()
end

local function slow(S, target, key, multiplier, seconds)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	S.Adapter.setMoveModifier(humanoid, key, multiplier)
	local token = tostring({})
	target:SetAttribute(key .. "Token", token)
	task.delay(seconds, function()
		if humanoid.Parent and target:GetAttribute(key .. "Token") == token then
			S.Adapter.setMoveModifier(humanoid, key, nil)
			target:SetAttribute(key .. "Token", nil)
		end
	end)
end

-- Everyone in range (pulled toward `center` when pull is set).
local function around(S, player, center, radius, info, pull)
	local character = player.Character
	local count = 0
	for _, target in ipairs(S.Hitbox.inRadius(character, center, radius, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			local hitInfo = table.clone(info)
			hitInfo.Position = tr.Position
			hitInfo.Direction = pull and (center - tr.Position) or (tr.Position - center)
			if S.hit(player, target, hitInfo) then
				count = count + 1
			end
		end
	end
	return count
end

local USE = {}

USE.Johnny = function(S, player, state, character, root, aim)
	local dir = S.aim(aim, root)
	S.lock(state, 0.4)
	fx({ Character = character, Who = "Johnny", Phase = "Cast", Direction = dir })
	task.delay(0.2, function()
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		Moves.nail(S, player, state, {
			Origin = S.origin(char, r, Moves.HAND), Direction = dir, Speed = 210, Radius = 1.7, Range = 220,
			Style = "Spinning", Charge = 1, Damage = 15, Stun = 0.6, Knockback = 45, Launch = 12, Source = "CorpseNail",
		})
	end)
end

USE.Gyro = function(S, player, state, character, root, aim)
	local dir = Moves.flat(S.aim(aim, root))
	S.lock(state, 0.5)
	fx({ Character = character, Who = "Gyro", Phase = "Cast", Position = root.Position, Direction = dir, Length = 34 })
	task.delay(0.25, function()
		local _, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		local mid = r.Position + dir * 17
		Moves.boxHit(S, player, CFrame.lookAt(mid, mid + dir), Vector3.new(7, 7, 34), { Damage = 13, Stun = 0.7, Knockback = 35, Launch = 16, Direction = dir, Source = "CorpseSpin" }, 6)
	end)
end

USE.Diego = function(S, player, state, character, root, aim)
	local dir = Moves.flat(S.aim(aim, root))
	local to = Moves.safeStep(character, root, dir, 30) or root.Position
	S.lock(state, 0.7)
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	fx({ Character = character, Who = "Diego", Phase = "Leap", From = root.Position, To = to, Time = 0.45 })
	task.delay(0.45, function()
		character:SetAttribute(iframes, nil)
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		char:PivotTo(CFrame.lookAt(to, to + dir))
		around(S, player, to, 10, { Damage = 12, Stun = 0.7, Knockback = 30, Launch = 18, Source = "CorpseCrash" })
		fx({ Character = char, Who = "Diego", Phase = "Slam", Position = to, Radius = 10 })
	end)
end

USE.PorkPie = function(S, player, state, character, root)
	S.lock(state, 0.5)
	fx({ Character = character, Who = "PorkPie", Phase = "Cast", Position = root.Position, Radius = 20 })
	task.delay(0.3, function()
		local _, _, r = S.Adapter.getAlive(player)
		if r then
			around(S, player, r.Position, 20, { Damage = 11, Stun = 1.0, Knockback = 45, Source = "CorpseHooks" }, true)
		end
	end)
end

USE.Sandman = function(S, player, state, character, root, aim)
	local dir = Moves.flat(S.aim(aim, root))
	local to = Moves.safeStep(character, root, dir, 36)
	if not to then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return false
	end
	local from = root.Position
	S.lock(state, 0.5)
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	fx({ Character = character, Who = "Sandman", Phase = "Dash", From = from, To = to })
	task.delay(0.2, function()
		character:SetAttribute(iframes, nil)
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		char:PivotTo(CFrame.lookAt(to, to + dir))
		local mid = (from + to) / 2
		Moves.boxHit(S, player, CFrame.lookAt(mid, to), Vector3.new(7, 7, (to - from).Magnitude + 2), { Damage = 9, Stun = 0.6, Knockback = 10, Direction = dir, Source = "CorpseSound" }, 6)
		task.delay(0.45, function()
			around(S, player, mid, 9, { Damage = 6, Stun = 0.6, Knockback = 30, Launch = 18, Source = "CorpseSound" })
			fx({ Character = char, Who = "Sandman", Phase = "Boom", Position = mid })
		end)
	end)
end

USE.MountainTim = function(S, player, state, character, root)
	S.lock(state, 0.8)
	fx({ Character = character, Who = "MountainTim", Phase = "Spin", Position = root.Position, Radius = 14, Time = 0.8 })
	for i = 1, 3 do
		task.delay(i * 0.25, function()
			local _, _, r = S.Adapter.getAlive(player)
			if r then
				around(S, player, r.Position, 14, { Damage = 4, Stun = 0.5, Knockback = 25, Source = "CorpseLasso" }, true)
			end
		end)
	end
end

USE.HotPants = function(S, player, state, character, root)
	local _, humanoid = S.Adapter.getAlive(player)
	S.lock(state, 0.5)
	character:SetAttribute("Armored", true)
	fx({ Character = character, Who = "HotPants", Phase = "Cocoon", Position = root.Position, Time = 2 })
	for i = 1, 5 do
		task.delay(i * 0.3, function()
			if humanoid.Parent and humanoid.Health > 0 then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 6)
			end
		end)
	end
	task.delay(2, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		local _, _, r = S.Adapter.getAlive(player)
		if r then
			around(S, player, r.Position, 9, { Damage = 7, Stun = 0.6, Knockback = 30, Launch = 10, Source = "CorpseFlesh" })
			fx({ Character = character, Who = "HotPants", Phase = "Burst", Position = r.Position })
		end
	end)
end

USE.Blackmore = function(S, player, state, character, root, aim)
	local dir = Moves.flat(S.aim(aim, root))
	S.lock(state, 0.5)
	fx({ Character = character, Who = "Blackmore", Phase = "Curtain", Position = root.Position, Direction = dir, Range = 26, Cone = 70 })
	task.delay(0.3, function()
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		local cosLimit = math.cos(math.rad(35))
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, 26, 8)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			local off = tr and Vector3.new(tr.Position.X - r.Position.X, 0, tr.Position.Z - r.Position.Z)
			if tr and (off.Magnitude < 1 or off.Unit:Dot(dir) >= cosLimit) then
				if S.hit(player, target, { Damage = 12, Stun = 0.6, Knockback = 12, Direction = dir, Position = tr.Position, Source = "CorpseRain" }) then
					slow(S, target, "CorpseRain", 0.6, 2)
				end
			end
		end
	end)
end

USE.Axl = function(S, player, state, character, root)
	S.lock(state, 0.5)
	fx({ Character = character, Who = "Axl", Phase = "Flood", Position = root.Position, Radius = 22 })
	task.delay(0.3, function()
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, 22, 8)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.hit(player, target, { Damage = 8, Stun = 0.6, Knockback = 8, Direction = tr.Position - r.Position, Position = tr.Position, Source = "CorpseGuilt" }) then
				-- +2 guilt (the same stacks Axl's moves feed on).
				local g = math.min(5, (target:GetAttribute("Guilt") or 0) + 2)
				target:SetAttribute("Guilt", g)
				target:SetAttribute("GuiltAt", os.clock())
				S.fx("Ability", { Act = 12, Move = "Guilt", Phase = "Mark", Target = target, Stacks = g })
			end
		end
	end)
end

USE.Valentine = function(S, player, state, character, root)
	local _, humanoid = S.Adapter.getAlive(player)
	S.lock(state, 0.3)
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 15)
	fx({ Character = character, Who = "Valentine", Phase = "Bless", Position = root.Position, Time = 2.5 })
	task.delay(2.5, function()
		if character.Parent then
			character:SetAttribute(iframes, nil)
		end
		local _, _, r = S.Adapter.getAlive(player)
		if r then
			around(S, player, r.Position, 12, { Damage = 9, Stun = 0.6, Knockback = 35, Source = "CorpseLight" })
			fx({ Character = character, Who = "Valentine", Phase = "Pulse", Position = r.Position, Radius = 12 })
		end
	end)
end

-- REVOLVER: he draws a six-shooter, aims and fans the hammer: six shots
-- where he's aiming (the last hits hardest), then twirls it and holsters it.
-- (In stopped time the bullets hang in the air like everything else.)
USE.DiegoAU = function(S, player, state, character, root, aim)
	local g = TuskConfig.DiegoAU and TuskConfig.DiegoAU.Revolver
	if not S.fireKnife or not g then
		return false
	end
	local total = g.Draw + g.Shots * g.Every
	S.lock(state, total + 0.25)
	local life = state.Life
	fx({ Character = character, Who = "DiegoAU", Phase = "Draw", Draw = g.Draw, Every = g.Every, Shots = g.Shots, Time = total + 0.6 })
	for i = 1, g.Shots do
		task.delay(g.Draw + (i - 1) * g.Every, function()
			local char, _, r = S.Adapter.getAlive(player)
			if not r or state.Life ~= life then
				return
			end
			local dir = S.aim(aim, r)
			-- A little spread as he fans the hammer.
			dir = (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(math.rad((math.random() - 0.5) * 2.5), math.rad((math.random() - 0.5) * 3.5), 0)).LookVector
			local muzzle = S.origin(char, r, CFrame.new(1, 0.6, -2.4))
			local last = i == g.Shots
			S.fireKnife(player, state, {
				Origin = muzzle,
				Direction = dir,
				Speed = g.Speed,
				Radius = 0.5,
				Range = g.Range,
				Style = "Bullet",
				OnHit = function(target, position)
					S.hit(player, target, { Damage = last and g.LastShotDamage or g.Damage, Stun = g.Stun, Knockback = last and 20 or g.Knockback, Direction = dir, Position = position, Source = "DiegoAURevolver" })
				end,
			})
			fx({ Character = char, Who = "DiegoAU", Phase = "Shot", Index = i, Position = muzzle, Direction = dir, Last = last })
		end)
	end
end

-- THE SAINT'S MIRACLE: only with the complete corpse (all 8 parts).
local function miracle(S, player, state, character, root)
	local m = TuskConfig.Corpse.Miracle
	local _, humanoid = S.Adapter.getAlive(player)
	local center = root.Position
	local iframes = S.Adapter.Settings.IFrameAttribute
	S.lock(state, m.Windup + m.Waves * m.WaveEvery + 0.5)
	character:SetAttribute(iframes, true)
	character:SetAttribute("Armored", true)
	humanoid.Health = humanoid.MaxHealth
	fx({ Character = character, Who = "Miracle", Phase = "Start", Position = center, Windup = m.Windup, Range = m.Range, Time = m.Windup + m.Waves * m.WaveEvery })
	for w = 1, m.Waves do
		task.delay(m.Windup + (w - 1) * m.WaveEvery, function()
			local char, _, r = S.Adapter.getAlive(player)
			if not r then
				return
			end
			local struck = {}
			for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, m.Range, 16)) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr and S.hit(player, target, { Damage = m.Damage, Stun = m.Stun, Knockback = 0, Direction = Vector3.new(0, -1, 0), Position = tr.Position, Source = "CorpseMiracle" }) then
					table.insert(struck, tr.Position)
				end
			end
			fx({ Character = char, Who = "Miracle", Phase = "Pillars", Positions = struck, Wave = w })
		end)
	end
	task.delay(m.Windup + m.Waves * m.WaveEvery, function()
		if character.Parent then
			character:SetAttribute(iframes, nil)
			character:SetAttribute("Armored", nil)
		end
		local _, _, r = S.Adapter.getAlive(player)
		if r then
			around(S, player, r.Position, m.FinalRadius, { Damage = m.FinalDamage, Stun = 0.9, Knockback = m.FinalKnockback, Launch = m.FinalLaunch, Source = "CorpseMiracle" })
			fx({ Character = character, Who = "Miracle", Phase = "Burst", Position = r.Position, Radius = m.FinalRadius })
		end
		-- The corpse leaves them: every part goes back out into the desert.
		local ok, Corpse = pcall(function()
			return __require("CorpseService")
		end)
		if ok and Corpse then
			Corpse.release(player)
		end
	end)
end

function CorpseMoves.use(S, player, state, aim, cfg)
	local character, _, root = S.Adapter.getAlive(player)
	if not character or not state.Act or S.isBusy(state) or state.Charging or not S.Adapter.canAct(player) then
		return
	end
	if (character:GetAttribute("CorpseReadyAt") or 0) > now() then
		S.tell(player, "Denied", { Reason = "Cooldown" })
		return
	end
	if character:GetAttribute("CorpseComplete") then
		miracle(S, player, state, character, root)
		return
	end
	local who = Registry.characterOf(state.Act)
	local fn = USE[who]
	if not fn then
		return
	end
	if fn(S, player, state, character, root, aim) == false then
		return
	end
	character:SetAttribute("CorpseReadyAt", now() + (cfg and cfg.Cooldown or 20))
end

return CorpseMoves
end

-- ======================================================================
-- MODULE: CorpseService
-- ======================================================================
__modules["CorpseService"] = function()
--[[
	CorpseService  (ServerScriptService.SpinServer.CorpseService)

	SAINT'S CORPSE. Eight parts (TuskConfig.Corpse.Parts), each existing
	once, lie around the map: a mummified relic glowing gold with a beam of
	light you can see from far away. Hold E by one to take it.
	  * each part gives its own boost until you die (Damage, Resist, Cooldown,
	    UltGain, Speed, MaxHealth), stacking with any others you hold
	  * when you die your parts drop where you fell for anyone to grab; one
	    nobody takes moves to a new random spot after a while
	  * holding any part unlocks your character's CORPSE MOVE (V), see
	    CorpseMoves
	  * holders are worth more on the bounty board (BountyService)
	  * Stand-user NPCs pick parts up too, use their corpse move, and drop
	    their parts when they die (StandBots uses take / dropFor)
	Boosts are character attributes the combat code reads:
	  CorpseDamage, CorpseResist, CorpseCooldown, CorpseUltGain (multipliers)
	  CorpseParts ("Heart,Spine") for the HUD and the bounty board
	Clients are told about pickups and drops over WorldFX ("Corpse...").
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Net = __require("Net")

local CorpseService = {}
CorpseService.OnTaken = {} -- functions(player, partId) called when someone takes a part

local cfg
local S -- TuskService
local folder
local WorldFX
local partInfo = {} -- [id] = config entry
local relics = {} -- [id] = relic model lying in the world
local held = {} -- [player] = { Ids = { ... }, BaseMax = number }
local rng = Random.new()

local MUMMY = Color3.fromRGB(122, 90, 60)
local MUMMY_DARK = Color3.fromRGB(84, 60, 40)
local WRAP = Color3.fromRGB(222, 204, 164)
local GLOW = Color3.fromRGB(255, 214, 110)

local function origin()
	local map = workspace:FindFirstChild("SBRMap")
	return map and map:GetAttribute("Origin") or Vector3.new()
end

local function groundAt(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { folder }
	for _, m in ipairs(CollectionService:GetTagged("SpinFighter")) do
		table.insert(ex, m)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ex, p.Character)
		end
	end
	params.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(pos + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), params)
	return hit and hit.Position or pos
end

---------------------------------------------------------------------------
-- The relics
---------------------------------------------------------------------------
local function piece(model, size, cf, color, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local WRAP_DARK = Color3.fromRGB(184, 164, 124)
local BONE = Color3.fromRGB(226, 214, 186)
local SINEW = Color3.fromRGB(96, 52, 40)
local GOLD = Color3.fromRGB(226, 182, 70)

-- A bandage band round a box-shaped piece.
local function band(model, cf, w, d)
	piece(model, Vector3.new(w + 0.06, 0.14, d + 0.06), cf, WRAP)
	piece(model, Vector3.new(w + 0.07, 0.04, d + 0.07), cf * CFrame.new(0, 0.05, 0), WRAP_DARK)
end

-- A mummified part, blocky but detailed, built round `at` (the floating centre).
local function shape(model, id, at)
	local c = CFrame.new(at)
	if id == "Heart" then
		local h = c * CFrame.Angles(0, 0, 0.25)
		piece(model, Vector3.new(1.2, 1.4, 1.0), h, MUMMY)
		piece(model, Vector3.new(0.7, 0.8, 0.9), h * CFrame.new(-0.45, 0.25, 0), MUMMY) -- left lobe
		piece(model, Vector3.new(0.6, 0.7, 0.8), h * CFrame.new(0.42, 0.3, 0.05), MUMMY_DARK) -- right lobe
		piece(model, Vector3.new(0.5, 0.5, 0.6), h * CFrame.new(0.05, -0.75, 0) * CFrame.Angles(0, 0, 0.6), MUMMY_DARK) -- apex
		-- The aorta arching over the top, and two vessels.
		piece(model, Vector3.new(0.28, 0.5, 0.28), h * CFrame.new(-0.15, 0.9, 0), SINEW)
		piece(model, Vector3.new(0.5, 0.24, 0.24), h * CFrame.new(0.05, 1.15, 0) * CFrame.Angles(0, 0, -0.2), SINEW)
		piece(model, Vector3.new(0.22, 0.4, 0.22), h * CFrame.new(0.32, 0.95, 0), SINEW)
		piece(model, Vector3.new(0.2, 0.35, 0.2), h * CFrame.new(-0.45, 0.8, 0.15), SINEW)
		-- Veins over the front.
		for i = -1, 1 do
			piece(model, Vector3.new(0.05, 0.7, 0.04), h * CFrame.new(i * 0.25, 0, -0.52) * CFrame.Angles(0, 0, i * 0.4), SINEW)
		end
		-- Crossed bandages.
		piece(model, Vector3.new(1.5, 0.16, 1.1), h * CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, 0.5), WRAP)
		piece(model, Vector3.new(1.4, 0.14, 1.08), h * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, -0.6), WRAP_DARK)
	elseif id == "Head" then
		piece(model, Vector3.new(1.3, 1.3, 1.35), c * CFrame.new(0, 0.1, 0), BONE) -- cranium
		piece(model, Vector3.new(1.36, 0.16, 0.3), c * CFrame.new(0, 0.32, -0.6), MUMMY) -- brow ridge
		for _, x in ipairs({ -0.3, 0.3 }) do
			piece(model, Vector3.new(0.34, 0.34, 0.12), c * CFrame.new(x, 0.08, -0.66), MUMMY_DARK) -- eye socket
			piece(model, Vector3.new(0.16, 0.16, 0.06), c * CFrame.new(x, 0.08, -0.7), Color3.fromRGB(30, 20, 16))
			piece(model, Vector3.new(0.3, 0.2, 0.2), c * CFrame.new(x * 1.7, -0.15, -0.5), MUMMY) -- cheekbones
		end
		piece(model, Vector3.new(0.2, 0.3, 0.1), c * CFrame.new(0, -0.15, -0.68), MUMMY_DARK) -- nose
		-- Jaw hanging slightly open, a row of teeth.
		piece(model, Vector3.new(1.0, 0.3, 0.9), c * CFrame.new(0, -0.68, -0.15) * CFrame.Angles(0.2, 0, 0), MUMMY)
		for i = -2, 2 do
			piece(model, Vector3.new(0.12, 0.16, 0.08), c * CFrame.new(i * 0.16, -0.48, -0.62), BONE)
		end
		-- Bandages wound round the top and under the chin.
		band(model, c * CFrame.new(0, 0.55, 0), 1.3, 1.35)
		piece(model, Vector3.new(0.18, 1.5, 1.4), c * CFrame.new(0.55, -0.05, 0) * CFrame.Angles(0, 0, 0.15), WRAP)
		piece(model, Vector3.new(0.5, 0.12, 0.08), c * CFrame.new(0.6, -0.9, -0.3) * CFrame.Angles(0, 0, -0.8), WRAP_DARK) -- loose end
	elseif id == "Spine" then
		for i = 0, 6 do
			local v = c * CFrame.new(math.sin(i * 0.7) * 0.08, -1.3 + i * 0.43, 0)
			piece(model, Vector3.new(0.5, 0.3, 0.45), v, BONE) -- vertebra
			piece(model, Vector3.new(1.0, 0.12, 0.2), v * CFrame.new(0, 0, 0.12), MUMMY) -- side wings
			piece(model, Vector3.new(0.14, 0.2, 0.4), v * CFrame.new(0, -0.05, 0.35) * CFrame.Angles(-0.5, 0, 0), MUMMY_DARK) -- spike
			if i < 6 then
				piece(model, Vector3.new(0.42, 0.12, 0.38), v * CFrame.new(0, 0.22, 0), SINEW) -- disc
			end
		end
		band(model, c * CFrame.new(0, 0.1, 0), 0.5, 0.45)
		band(model, c * CFrame.new(0, -0.8, 0), 0.5, 0.45)
	elseif id == "Eyes" then
		piece(model, Vector3.new(1.9, 0.45, 0.4), c * CFrame.new(0, 0, 0.1), WRAP) -- cloth band
		piece(model, Vector3.new(1.92, 0.06, 0.42), c * CFrame.new(0, 0.12, 0.1), WRAP_DARK)
		for _, x in ipairs({ -0.45, 0.45 }) do
			piece(model, Vector3.new(0.5, 0.5, 0.5), c * CFrame.new(x, 0, -0.2), Color3.fromRGB(236, 228, 214), Enum.PartType.Ball)
			piece(model, Vector3.new(0.24, 0.24, 0.24), c * CFrame.new(x, 0, -0.42), Color3.fromRGB(70, 110, 140), Enum.PartType.Ball) -- iris
			piece(model, Vector3.new(0.12, 0.12, 0.12), c * CFrame.new(x, 0, -0.52), Color3.fromRGB(20, 16, 16), Enum.PartType.Ball) -- pupil
			-- Nerves trailing back.
			piece(model, Vector3.new(0.08, 0.08, 0.7), c * CFrame.new(x * 0.8, -0.05, 0.4) * CFrame.Angles(0, x * 0.6, 0), SINEW)
		end
	elseif id == "Ears" then
		for _, side in ipairs({ -1, 1 }) do
			local e = c * CFrame.new(side * 0.5, 0, 0) * CFrame.Angles(0, side * 0.3, 0)
			-- The outer rim: a C of blocks.
			piece(model, Vector3.new(0.2, 0.25, 0.6), e * CFrame.new(0, 0.5, 0), MUMMY)
			piece(model, Vector3.new(0.2, 0.8, 0.25), e * CFrame.new(0, 0.1, 0.28), MUMMY)
			piece(model, Vector3.new(0.2, 0.25, 0.45), e * CFrame.new(0, -0.35, 0.05), MUMMY)
			piece(model, Vector3.new(0.18, 0.3, 0.3), e * CFrame.new(0, -0.55, -0.1), MUMMY_DARK) -- lobe
			piece(model, Vector3.new(0.16, 0.45, 0.3), e * CFrame.new(0.02, 0.1, 0.02), MUMMY_DARK) -- inner fold
		end
		piece(model, Vector3.new(1.4, 0.14, 0.3), c * CFrame.new(0, -0.75, 0), WRAP) -- tied together
	elseif id == "Legs" then
		for _, side in ipairs({ -1, 1 }) do
			local l = c * CFrame.new(side * 0.38, 0, 0) * CFrame.Angles(0, 0, side * 0.06)
			piece(model, Vector3.new(0.55, 1.2, 0.55), l * CFrame.new(0, 0.7, 0), MUMMY) -- thigh
			piece(model, Vector3.new(0.5, 0.3, 0.55), l * CFrame.new(0, 0.05, -0.05), BONE) -- knee
			piece(model, Vector3.new(0.45, 1.2, 0.45), l * CFrame.new(0, -0.65, 0), MUMMY) -- shin
			piece(model, Vector3.new(0.5, 0.25, 0.85), l * CFrame.new(0, -1.35, -0.2), MUMMY_DARK) -- foot
			for t = -1.5, 1.5 do
				piece(model, Vector3.new(0.1, 0.12, 0.16), l * CFrame.new(t * 0.11, -1.38, -0.68), MUMMY_DARK) -- toes
			end
			band(model, l * CFrame.new(0, 0.9, 0), 0.55, 0.55)
			band(model, l * CFrame.new(0, -0.4, 0), 0.45, 0.45)
		end
	else -- LeftArm / RightArm: bent at the elbow
		local side = id == "LeftArm" and -1 or 1
		local upper = c * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, side * 0.3)
		piece(model, Vector3.new(0.5, 1.2, 0.5), upper, MUMMY)
		local elbow = upper * CFrame.new(0, -0.65, 0)
		piece(model, Vector3.new(0.45, 0.3, 0.45), elbow, BONE)
		local fore = elbow * CFrame.Angles(0, 0, side * -0.7) * CFrame.new(0, -0.6, 0)
		piece(model, Vector3.new(0.42, 1.1, 0.42), fore, MUMMY)
		local hand = fore * CFrame.new(0, -0.7, 0)
		piece(model, Vector3.new(0.55, 0.45, 0.25), hand, MUMMY_DARK)
		for f = -1.5, 1.5 do
			piece(model, Vector3.new(0.09, 0.42, 0.09), hand * CFrame.new(f * 0.13, -0.4, 0) * CFrame.Angles(0.25, 0, 0), MUMMY_DARK)
		end
		piece(model, Vector3.new(0.09, 0.3, 0.09), hand * CFrame.new(side * -0.32, -0.1, -0.05) * CFrame.Angles(0, 0, side * 0.6), MUMMY_DARK) -- thumb
		band(model, upper * CFrame.new(0, 0.3, 0), 0.5, 0.5)
		band(model, fore * CFrame.new(0, 0.2, 0), 0.42, 0.42)
		piece(model, Vector3.new(0.1, 0.8, 0.06), fore * CFrame.new(0.2, -0.2, 0.22) * CFrame.Angles(0.2, 0, 0.2), WRAP) -- loose strip
	end
	-- A floating gold halo over every relic.
	local halo = piece(model, Vector3.new(0.12, 2.2, 2.2), CFrame.new(at + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, 0, math.pi / 2), GOLD, Enum.PartType.Cylinder)
	halo.Name = "Halo"
	halo.Material = Enum.Material.Neon
	halo.Transparency = 0.3
	piece(model, Vector3.new(0.14, 1.7, 1.7), CFrame.new(at + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, 0, math.pi / 2), GLOW, Enum.PartType.Cylinder).Transparency = 1
end

local collect -- (defined below)

local function placeRelic(id, position, dropped)
	local old = relics[id]
	if old then
		old:Destroy()
	end
	local info = partInfo[id]
	local ground = groundAt(position)
	local model = Instance.new("Model")
	model.Name = "Corpse" .. id
	local holder = piece(model, Vector3.new(3, 3, 3), CFrame.new(ground + Vector3.new(0, 2.5, 0)), GLOW)
	holder.Name = "Holder"
	holder.Transparency = 1
	model.PrimaryPart = holder
	shape(model, id, ground + Vector3.new(0, 2.5, 0))
	-- A pillar of light you can see from far away.
	local beam = piece(model, Vector3.new(60, 1.6, 1.6), CFrame.new(ground + Vector3.new(0, 31, 0)) * CFrame.Angles(0, 0, math.pi / 2), GLOW, Enum.PartType.Cylinder)
	beam.Name = "Beam"
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.65
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = holder
	-- Golden motes drifting up from it.
	local motes = Instance.new("ParticleEmitter")
	motes.Color = ColorSequence.new(GLOW)
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	motes.Lifetime = NumberRange.new(1, 1.8)
	motes.Speed = NumberRange.new(1, 2.5)
	motes.SpreadAngle = Vector2.new(40, 40)
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Rate = 8
	motes.Parent = holder
	local highlight = Instance.new("Highlight")
	highlight.FillColor = GLOW
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = GLOW
	highlight.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Take"
	prompt.ObjectText = "Saint's Corpse: " .. info.Name
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = holder
	prompt.Triggered:Connect(function(player)
		collect(player, id)
	end)
	model:SetAttribute("PartId", id)
	model:SetAttribute("Dropped", dropped == true)
	model:SetAttribute("LaidAt", workspace:GetServerTimeNow())
	model.Parent = folder
	CollectionService:AddTag(model, "SpinCorpse")
	relics[id] = model
	if dropped then
		-- Nobody takes it: it goes back out into the desert somewhere else.
		local stamp = os.clock()
		model:SetAttribute("DroppedAt", stamp)
		task.delay(cfg.DropDespawn or 60, function()
			if relics[id] == model and model.Parent and model:GetAttribute("DroppedAt") == stamp then
				CorpseService.scatter(id)
			end
		end)
	end
	return model
end

-- Put a part on a random spot (not one another part is already on).
function CorpseService.scatter(id)
	local used = {}
	for otherId, m in pairs(relics) do
		if otherId ~= id and m.Parent then
			used[m:GetAttribute("Spot") or -1] = true
		end
	end
	local free = {}
	for i = 1, #cfg.Spots do
		if not used[i] then
			table.insert(free, i)
		end
	end
	local i = #free > 0 and free[rng:NextInteger(1, #free)] or rng:NextInteger(1, #cfg.Spots)
	local model = placeRelic(id, origin() + cfg.Spots[i], false)
	model:SetAttribute("Spot", i)
end

---------------------------------------------------------------------------
-- Holding parts: boosts
---------------------------------------------------------------------------
local function apply(player)
	local h = held[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local sum = { Damage = 0, Resist = 0, Cooldown = 0, UltGain = 0, Speed = 0, MaxHealth = 0 }
	local ids = h and h.Ids or {}
	for _, id in ipairs(ids) do
		local info = partInfo[id]
		if info then
			sum[info.Buff] = (sum[info.Buff] or 0) + info.Amount
		end
	end
	local any = #ids > 0
	character:SetAttribute("CorpseParts", any and table.concat(ids, ",") or nil)
	character:SetAttribute("CorpseComplete", (#ids >= #cfg.Parts) or nil)
	character:SetAttribute("CorpseDamage", sum.Damage > 0 and 1 + sum.Damage or nil)
	character:SetAttribute("CorpseResist", sum.Resist > 0 and math.max(0.5, 1 - sum.Resist) or nil)
	character:SetAttribute("CorpseCooldown", sum.Cooldown > 0 and math.max(0.5, 1 - sum.Cooldown) or nil)
	character:SetAttribute("CorpseUltGain", sum.UltGain > 0 and 1 + sum.UltGain or nil)
	S.Adapter.setMoveModifier(humanoid, "Corpse", sum.Speed > 0 and 1 + sum.Speed or nil)
	if h then
		h.BaseMax = h.BaseMax or humanoid.MaxHealth
		local want = h.BaseMax + sum.MaxHealth
		if humanoid.MaxHealth ~= want then
			local gained = want - humanoid.MaxHealth
			humanoid.MaxHealth = want
			if gained > 0 then
				humanoid.Health = math.min(want, humanoid.Health + gained)
			end
		end
	end
end

function collect(player, id)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local model = relics[id]
	if not humanoid or humanoid.Health <= 0 or not model or not model.Parent then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - model:GetPivot().Position).Magnitude > 14 then
		return
	end
	relics[id] = nil
	model:Destroy()
	held[player] = held[player] or { Ids = {} }
	table.insert(held[player].Ids, id)
	apply(player)
	WorldFX:FireAllClients("CorpseTaken", { Player = player.UserId, Name = player.DisplayName, Part = id, Position = root.Position })
	for _, fn in ipairs(CorpseService.OnTaken) do
		task.spawn(fn, player, id)
	end
	-- All of it: everyone hears about it.
	if #held[player].Ids >= #cfg.Parts then
		WorldFX:FireAllClients("CorpseComplete", { Player = player.UserId, Name = player.DisplayName, Character = character })
	end
end

-- Where a part is: { Holder = player } if someone carries it, or
-- { Relic = model } if it's lying in the world (nil if neither).
function CorpseService.where(id)
	for p, h in pairs(held) do
		for _, heldId in ipairs(h.Ids) do
			if heldId == id then
				return { Holder = p }
			end
		end
	end
	local relic = relics[id]
	if relic and relic.Parent then
		return { Relic = relic }
	end
	return nil
end

function CorpseService.parts()
	return cfg and cfg.Parts or {}
end

-- Dies (or leaves): their parts fall where they were.
local function dropAll(player, position)
	local h = held[player]
	held[player] = nil
	if not h then
		return
	end
	for i, id in ipairs(h.Ids) do
		if position then
			local a = i / #h.Ids * math.pi * 2
			placeRelic(id, position + Vector3.new(math.cos(a) * 3, 0, math.sin(a) * 3), true)
			WorldFX:FireAllClients("CorpseDropped", { Part = id, Position = position, Name = player.DisplayName })
		else
			CorpseService.scatter(id)
		end
	end
end

-- After THE SAINT'S MIRACLE: the corpse leaves them; every part scatters.
function CorpseService.release(player)
	local h = held[player]
	if not h then
		return
	end
	local ids = h.Ids
	h.Ids = {}
	apply(player)
	held[player] = nil
	for _, id in ipairs(ids) do
		CorpseService.scatter(id)
	end
	WorldFX:FireAllClients("CorpseScattered", { Name = player.DisplayName })
end

-- For Stand-user NPCs (StandBots): take a part, and drop theirs when they die.
function CorpseService.take(botPlayer, id)
	collect(botPlayer, id)
end

function CorpseService.dropFor(botPlayer, position)
	dropAll(botPlayer, position)
end

function CorpseService.holding(player)
	local h = held[player]
	return h and #h.Ids or 0
end

local function watch(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		local root = character:FindFirstChild("HumanoidRootPart")
		dropAll(player, root and root.Position or nil)
	end)
end

function CorpseService.init(TuskService)
	cfg = TuskConfig.Corpse
	if not cfg or cfg.Enabled == false then
		return
	end
	S = TuskService
	WorldFX = Net.get("WorldFX")
	for _, info in ipairs(cfg.Parts) do
		partInfo[info.Id] = info
	end
	folder = Instance.new("Folder")
	folder.Name = "SaintsCorpse"
	folder.Parent = workspace
	for _, info in ipairs(cfg.Parts) do
		CorpseService.scatter(info.Id)
	end
	local function onPlayer(player)
		player.CharacterAdded:Connect(function(character)
			watch(player, character)
		end)
		if player.Character then
			task.spawn(watch, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		dropAll(player, nil)
	end)
	-- The CORPSE MOVE goes through TuskService's request handler.
	local Moves = __require("CorpseMoves")
	TuskService.CorpseMove = function(player, state, aim)
		if CorpseService.holding(player) < 1 then
			TuskService.tell(player, "Denied", { Reason = "NeedCorpse" })
			return
		end
		Moves.use(TuskService, player, state, aim, cfg.Move)
	end
end

return CorpseService
end

-- ======================================================================
-- MODULE: DefenseService
-- ======================================================================
__modules["DefenseService"] = function()
--[[
	DefenseService  (ServerScriptService.SpinServer.DefenseService)

	BLOCK and DASH for every character (players and Stand-user NPCs).
	  BLOCK (hold F): sets the "Blocking" attribute; CombatAdapter then cuts
	    damage, skips the stun and drains the guard bar (BlockMeter). Hits from
	    behind aren't blocked. Starting a block just before a hit lands is a
	    PERFECT BLOCK (no damage, the attacker is stunned). An empty guard bar
	    is a GUARD BREAK (stunned, can't block for a few seconds). Attacking or
	    dashing drops the block. The bar refills while you aren't blocking.
	  DASH (Q): a short burst in the direction you're moving, with a moment
	    you can't be hit. Two charges (chain them); each comes back after
	    DashCooldown. A dash cancels the recovery after an M1 hit. Dash
	    through an attack (it would have hit you) for a PERFECT DODGE: the
	    charge comes back, the attacker is slowed, you get ultimate meter and
	    your next hit within CounterTime does +40%. The server checks and
	    grants it; the player's own client moves them (smooth, replicates to
	    everyone). NPCs are moved by the server.
	Numbers: TuskConfig.Defense.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local DefenseService = {}
local S -- TuskService
local cfg = TuskConfig.Defense or {}
local lastRelease = setmetatable({}, { __mode = "k" }) -- [character] = server time of the last block release

local function now()
	return workspace:GetServerTimeNow()
end

function DefenseService.isBlocking(character)
	return character ~= nil and character:GetAttribute(S.Adapter.Settings.BlockAttribute) == true
end

function DefenseService.release(player, state)
	local character = state and state.Character or (player and player.Character)
	if not character or not DefenseService.isBlocking(character) then
		return
	end
	character:SetAttribute(S.Adapter.Settings.BlockAttribute, nil)
	character:SetAttribute("BlockCanParry", nil)
	lastRelease[character] = now()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		S.Adapter.setMoveModifier(humanoid, "Block", nil)
	end
end

function DefenseService.block(player, state, on)
	local character, humanoid = S.Adapter.getAlive(player)
	if not character then
		return
	end
	if not on then
		DefenseService.release(player, state)
		return
	end
	if DefenseService.isBlocking(character) then
		return
	end
	if not S.Adapter.canAct(player) or state.Charging or S.isBusy(state) or state.Sneaking then
		return
	end
	if (character:GetAttribute("GuardBrokenUntil") or 0) > now() then
		S.tell(player, "Denied", { Reason = "GuardBroken" })
		return
	end
	local t = now()
	character:SetAttribute("BlockStart", t)
	-- Perfect blocks only count if this isn't block spam.
	character:SetAttribute("BlockCanParry", (t - (lastRelease[character] or -math.huge)) >= (cfg.ParryRetry or 0.6) or nil)
	if character:GetAttribute("BlockMeter") == nil then
		character:SetAttribute("BlockMeter", cfg.MaxMeter or 100)
	end
	character:SetAttribute(S.Adapter.Settings.BlockAttribute, true)
	S.Adapter.setMoveModifier(humanoid, "Block", cfg.BlockWalkSpeed or 0.45)
end

-- Dash charges per character: the server times each charge is ready again
-- (sorted). Shown to the HUD as DashReadyAt (next) and DashFullAt (all).
local charges = setmetatable({}, { __mode = "k" })

local function chargeList(character)
	local list = charges[character]
	if not list then
		list = {}
		for i = 1, (cfg.DashCharges or 2) do
			list[i] = 0
		end
		charges[character] = list
	end
	return list
end

local function publishCharges(character, list)
	table.sort(list)
	character:SetAttribute("DashReadyAt", list[1])
	character:SetAttribute("DashFullAt", list[#list])
	character:SetAttribute("DashCharges", #list)
end

-- Busy only because of an M1's recovery? Then a dash may cancel it.
local function onlyM1Recovery(state)
	return cfg.DashCancelM1 ~= false and state.M1LockUntil ~= nil and state.LockUntil <= state.M1LockUntil
end

function DefenseService.dash(player, state, direction)
	local character, _, root = S.Adapter.getAlive(player)
	if not character or typeof(direction) ~= "Vector3" or direction ~= direction then
		return
	end
	if not S.Adapter.canAct(player) or state.Charging or state.Sneaking then
		return
	end
	local cancel = false
	if S.isBusy(state) then
		if not onlyM1Recovery(state) then
			return
		end
		cancel = true
	end
	local t = now()
	local list = chargeList(character)
	table.sort(list)
	if list[1] > t then
		S.tell(player, "Denied", { Reason = "DashCooldown" })
		return
	end
	if t - (character:GetAttribute("LastDashAt") or -math.huge) < (cfg.DashGap or 0.3) then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	flat = flat.Unit
	DefenseService.release(player, state)
	if cancel then
		-- Dash-cancel: the M1 recovery is over, the combo starts again.
		state.LockUntil = os.clock()
		state.M1LockUntil = nil
		state.Combo = 0
	end
	-- Use a charge: it comes back DashCooldown after the last one queued.
	local cooldown = cfg.DashCooldown or 2.2
	table.remove(list, 1)
	table.insert(list, math.max(t, list[#list] or t) + cooldown)
	publishCharges(character, list)
	character:SetAttribute("LastDashAt", t)
	local iframes = S.Adapter.Settings.IFrameAttribute
	local token = tostring({})
	character:SetAttribute(iframes, true)
	character:SetAttribute("DashToken", token)
	character:SetAttribute("DashDodgeUntil", t + (cfg.PerfectDodgeWindow or 0.22))
	character:SetAttribute("DashDodged", nil)
	task.delay(cfg.DashIFrames or 0.22, function()
		if character:GetAttribute("DashToken") == token then
			character:SetAttribute(iframes, nil)
		end
	end)
	local speed, time = cfg.DashSpeed or 80, cfg.DashTime or 0.21
	S.fx("Dash", { Character = character, Direction = flat, Speed = speed, Time = time, Cancel = cancel })
	-- NPCs have no client to move them: the server does it.
	if typeof(player) ~= "Instance" then
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.MaxForce = math.huge
		velocity.VectorVelocity = flat * speed
		velocity.Parent = attachment
		game:GetService("Debris"):AddItem(attachment, time)
	end
end

-- PERFECT DODGE: an attack that would have hit landed during the dash.
local function onPerfectDodge(character, attackerPlayer)
	local t = now()
	-- The dash charge comes back.
	if cfg.PerfectDodgeRefund ~= false then
		local list = chargeList(character)
		table.sort(list)
		list[#list] = math.min(list[#list], t)
		publishCharges(character, list)
	end
	-- The next hit within CounterTime lands harder.
	character:SetAttribute("CounterUntil", t + (cfg.CounterTime or 1.5))
	-- Ultimate meter (players and NPCs).
	local owner = Players:GetPlayerFromCharacter(character)
	if not owner then
		for p, st in pairs(S.States or {}) do
			if st.Character == character then
				owner = p
			end
		end
	end
	if owner and S.addUlt then
		S.addUlt(owner, cfg.PerfectDodgeUlt or 8)
	end
	-- The attacker stumbles: slowed for a moment.
	local attacker = attackerPlayer and attackerPlayer.Character
	local ah = attacker and attacker:FindFirstChildOfClass("Humanoid")
	if ah then
		local token = tostring({})
		attacker:SetAttribute("DodgedSlowToken", token)
		S.Adapter.setMoveModifier(ah, "Dodged", cfg.PerfectDodgeSlow or 0.5)
		task.delay(cfg.PerfectDodgeSlowTime or 0.8, function()
			if ah.Parent and attacker:GetAttribute("DodgedSlowToken") == token then
				S.Adapter.setMoveModifier(ah, "Dodged", nil)
				attacker:SetAttribute("DodgedSlowToken", nil)
			end
		end)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	S.fx("PerfectDodge", { Character = character, Attacker = attacker, Position = root and root.Position, Counter = cfg.CounterTime or 1.5 })
end

-- Guard bars refill while not blocking.
local function regen(dt)
	local max = cfg.MaxMeter or 100
	local t = now()
	local function tick(character)
		local meter = character and character:GetAttribute("BlockMeter")
		if meter and meter < max and not DefenseService.isBlocking(character) and t - (character:GetAttribute("LastBlockHit") or 0) >= (cfg.RegenDelay or 1.2) then
			local nextValue = math.min(max, meter + (cfg.MeterRegen or 30) * dt)
			character:SetAttribute("BlockMeter", nextValue >= max and nil or nextValue)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		tick(player.Character)
	end
	for _, model in ipairs(CollectionService:GetTagged("SpinFighter")) do
		tick(model)
	end
end

function DefenseService.init(TuskService)
	S = TuskService
	if S.Adapter.on then
		S.Adapter.on("PerfectDodge", onPerfectDodge)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc >= 0.1 then
			regen(acc)
			acc = 0
		end
	end)
end

return DefenseService
end

-- ======================================================================
-- MODULE: JohnnyOutfit
-- ======================================================================
__modules["JohnnyOutfit"] = function()
--[[
	JohnnyOutfit  (ServerScriptService.SpinServer.JohnnyOutfit)

	Gives a character Johnny Joestar's look while they play him (Tusk, Acts
	1-4), built from blocky parts (no catalog asset ids), matched to his art:
	  * a light-blue knit cap covered in pink stars, a gold horseshoe on the
	    front with a black horse head inside it, little frayed tips
	  * wavy blond hair to his shoulders
	  * a lavender scarf round his neck
	  * a light-blue top with a black V across the chest, a purple star
	    patch on the sleeve, sleeves pushed up to lavender cuffs at the elbow,
	    bare forearms and black wristbands
	  * light-blue trousers covered in pink stars
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local JohnnyOutfit = {}
JohnnyOutfit.Act = 1 -- (any Tusk Act: 1-4)

local C = {
	Cap = Color3.fromRGB(176, 214, 236),
	CapShade = Color3.fromRGB(140, 182, 210),
	Star = Color3.fromRGB(236, 140, 186),
	Gold = Color3.fromRGB(222, 180, 64),
	GoldDark = Color3.fromRGB(170, 130, 40),
	Horse = Color3.fromRGB(26, 24, 28),
	Hair = Color3.fromRGB(232, 206, 140),
	HairDark = Color3.fromRGB(196, 168, 104),
	Scarf = Color3.fromRGB(184, 160, 222),
	Suit = Color3.fromRGB(170, 208, 232),
	SuitShade = Color3.fromRGB(134, 174, 204),
	Chevron = Color3.fromRGB(26, 28, 34),
	Patch = Color3.fromRGB(120, 90, 170),
	Band = Color3.fromRGB(30, 30, 34),
	Shoe = Color3.fromRGB(60, 54, 70),
}

local saved = setmetatable({}, { __mode = "k" })

local function piece(parent, outfit, name, size, color, offset)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.Color = color
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = outfit
	return p
end

-- Little pink stars (a diamond and a cross) scattered over one face.
local function stars(part, outfit, faceCF, w, h, count, seed)
	for i = 1, count do
		local u = ((i * 37 + seed * 17) % 100) / 100 - 0.5
		local v = ((i * 59 + seed * 31) % 100) / 100 - 0.5
		local cf = faceCF * CFrame.new(u * w * 0.85, v * h * 0.85, 0)
		piece(part, outfit, "Star", Vector3.new(0.12, 0.12, 0.03), C.Star, cf * CFrame.Angles(0, 0, math.pi / 4))
		piece(part, outfit, "Star", Vector3.new(0.2, 0.05, 0.03), C.Star, cf)
	end
end

-- Stars all round a box laid over a part.
local function starry(part, outfit, size, cf, count, seed)
	local x, z = size.X / 2 + 0.015, size.Z / 2 + 0.015
	stars(part, outfit, cf * CFrame.new(0, 0, -z), size.X, size.Y, count, seed)
	stars(part, outfit, cf * CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi, 0), size.X, size.Y, count, seed + 1)
	stars(part, outfit, cf * CFrame.new(x, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), size.Z, size.Y, math.max(1, count - 1), seed + 2)
	stars(part, outfit, cf * CFrame.new(-x, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), size.Z, size.Y, math.max(1, count - 1), seed + 3)
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Wavy blond hair down to the shoulders.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.18 * s, 1.0 * s, head.Size.Z * 0.85), C.Hair, CFrame.new(side * (w + 0.08 * s), -0.3 * s, 0.06 * s))
		piece(head, outfit, "HairWave", Vector3.new(0.22 * s, 0.3 * s, head.Size.Z * 0.5), C.HairDark, CFrame.new(side * (w + 0.12 * s), -0.75 * s, 0.1 * s) * CFrame.Angles(0, 0, side * 0.3))
	end
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.3 * s, 1.0 * s, 0.22 * s), C.Hair, CFrame.new(0, -0.4 * s, d + 0.1 * s))
	piece(head, outfit, "Bangs", Vector3.new(head.Size.X * 0.5, 0.18 * s, 0.1 * s), C.Hair, CFrame.new(0.15 * s, h - 0.42 * s, -d - 0.03 * s) * CFrame.Angles(0, 0, -0.25))
	-- The knit cap, pulled down low, with a folded band and little frayed tips.
	local capSize = Vector3.new(head.Size.X + 0.2 * s, 0.75 * s, head.Size.Z + 0.2 * s)
	local capCF = CFrame.new(0, h - 0.12 * s, 0.02 * s)
	piece(head, outfit, "Cap", capSize, C.Cap, capCF)
	piece(head, outfit, "CapTop", Vector3.new(head.Size.X * 0.8, 0.2 * s, head.Size.Z * 0.8), C.Cap, CFrame.new(0, h + 0.34 * s, 0.04 * s))
	piece(head, outfit, "CapBand", Vector3.new(head.Size.X + 0.26 * s, 0.18 * s, head.Size.Z + 0.26 * s), C.CapShade, CFrame.new(0, h - 0.42 * s, 0.02 * s))
	starry(head, outfit, capSize, capCF, 3, 4)
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "CapTip", Vector3.new(0.1 * s, 0.3 * s, 0.1 * s), C.CapShade, CFrame.new(side * (w + 0.02 * s), h + 0.24 * s, 0.2 * s) * CFrame.Angles(0, 0, side * -0.5))
	end
	-- Gold horseshoe on the front, opening upward, a black horse head inside.
	local hf = -d - 0.14 * s
	local hy = h - 0.02 * s
	piece(head, outfit, "Horseshoe", Vector3.new(0.5 * s, 0.1 * s, 0.06 * s), C.Gold, CFrame.new(0, hy - 0.26 * s, hf))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Horseshoe", Vector3.new(0.1 * s, 0.5 * s, 0.06 * s), C.Gold, CFrame.new(side * 0.22 * s, hy, hf) * CFrame.Angles(0, 0, side * 0.08))
		piece(head, outfit, "Nail", Vector3.new(0.04 * s, 0.04 * s, 0.04 * s), C.GoldDark, CFrame.new(side * 0.22 * s, hy + 0.05 * s, hf - 0.04 * s))
	end
	piece(head, outfit, "HorseHead", Vector3.new(0.18 * s, 0.34 * s, 0.04 * s), C.Horse, CFrame.new(0, hy - 0.02 * s, hf + 0.02 * s) * CFrame.Angles(0, 0, 0.3))
	piece(head, outfit, "HorseHead", Vector3.new(0.18 * s, 0.1 * s, 0.04 * s), C.Horse, CFrame.new(0.05 * s, hy + 0.14 * s, hf + 0.02 * s))
end

local function body(character, outfit)
	local headPart = character:FindFirstChild("Head")
	local skin = headPart and headPart.Color or Color3.fromRGB(238, 200, 170)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Top", s + Vector3.new(0.1, 0.02, 0.1), C.Suit, CFrame.new())
		-- Lavender scarf round the neck.
		piece(upper, outfit, "Scarf", Vector3.new(s.X * 0.62, 0.34, s.Z + 0.22), C.Scarf, CFrame.new(0, top + 0.1, 0))
		piece(upper, outfit, "ScarfDrape", Vector3.new(0.5, 0.36, 0.08), C.Scarf, CFrame.new(0.1, top - 0.14, front - 0.06))
		-- The black V across the chest (and a matching one at the back).
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Chevron", Vector3.new(0.22, s.Y * 0.75, 0.05), C.Chevron, CFrame.new(side * s.X * 0.22, top - s.Y * 0.3, front - 0.06) * CFrame.Angles(0, 0, side * -0.9))
			piece(upper, outfit, "Chevron", Vector3.new(0.22, s.Y * 0.75, 0.05), C.Chevron, CFrame.new(side * s.X * 0.22, top - s.Y * 0.3, -front + 0.06) * CFrame.Angles(0, 0, side * 0.9))
		end
		stars(upper, outfit, CFrame.new(0, -s.Y * 0.3, front - 0.06), s.X * 0.9, s.Y * 0.3, 2, 9)
	end
	local waist = lower or upper
	if waist and lower then
		piece(lower, outfit, "Pants", lower.Size + Vector3.new(0.06, 0.02, 0.06), C.Suit, CFrame.new())
	end
	-- Sleeves pushed up to the elbow (lavender cuffs), bare forearms, black wristbands.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local tall = as.Y > 1.8
			local out = name:find("Left") and -1 or 1
			if name:find("Upper") or tall then
				local h = tall and as.Y * 0.55 or as.Y
				piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.12, h, as.Z + 0.12), C.Suit, CFrame.new(0, as.Y / 2 - h / 2, 0))
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.18, 0.28, as.Z + 0.18), C.Scarf, CFrame.new(0, as.Y / 2 - h, 0))
				if name:find("Right") or name == "Right Arm" then
					piece(arm, outfit, "Patch", Vector3.new(0.05, 0.36, 0.36), C.Patch, CFrame.new(out * (as.X / 2 + 0.08), as.Y / 2 - 0.4, 0))
				end
			end
			if name:find("Lower") or tall then
				-- Bare forearm (covers whatever shirt the avatar wears).
				local fh = tall and as.Y * 0.45 or as.Y
				piece(arm, outfit, "Skin", Vector3.new(as.X + 0.04, fh, as.Z + 0.04), skin, CFrame.new(0, -as.Y / 2 + fh / 2, 0))
				piece(arm, outfit, "Wristband", Vector3.new(as.X + 0.12, 0.3, as.Z + 0.12), C.Band, CFrame.new(0, -as.Y / 2 + 0.25, 0))
			end
		end
	end
	-- Light-blue trousers covered in pink stars.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local size = leg.Size + Vector3.new(0.06, 0.02, 0.06)
			piece(leg, outfit, "Pants", size, C.Suit, CFrame.new())
			starry(leg, outfit, size, CFrame.new(), leg.Size.Y > 1.8 and 3 or 2, #name)
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.08, 0.06, 0.1), C.Shoe, CFrame.new())
		end
	end
end

function JohnnyOutfit.apply(character)
	if character:FindFirstChild("JohnnyOutfit") then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local store = { Hidden = {} }
	saved[character] = store
	for _, d in ipairs(character:GetChildren()) do
		if d:IsA("Accessory") then
			local handle = d:FindFirstChild("Handle")
			local kind = d.AccessoryType
			if handle and (kind == Enum.AccessoryType.Hat or kind == Enum.AccessoryType.Hair or kind == Enum.AccessoryType.Unknown) then
				store.Hidden[handle] = handle.Transparency
				handle.Transparency = 1
			end
		end
	end
	local outfit = Instance.new("Model")
	outfit.Name = "JohnnyOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function JohnnyOutfit.remove(character)
	local outfit = character:FindFirstChild("JohnnyOutfit")
	if outfit then
		outfit:Destroy()
	end
	local store = saved[character]
	if not store then
		return
	end
	saved[character] = nil
	for thing, transparency in pairs(store.Hidden) do
		if thing.Parent then
			thing.Transparency = transparency
		end
	end
end

local function watch(character)
	local function update()
		local function isJohnny()
			local act = character:GetAttribute("TuskAct")
			return type(act) == "number" and act >= 1 and act <= 4
		end
		if isJohnny() then
			task.delay(0.3, function()
				if character.Parent and isJohnny() then
					JohnnyOutfit.apply(character)
				end
			end)
		else
			JohnnyOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function JohnnyOutfit.init()
	local function onPlayer(player)
		player.CharacterAppearanceLoaded:Connect(watch)
		if player.Character then
			watch(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	-- Stand-user NPCs (StandBots) wear the outfit too.
	local CollectionService = game:GetService("CollectionService")
	for _, model in ipairs(CollectionService:GetTagged("SpinFighter")) do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("SpinFighter"):Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
end

return JohnnyOutfit
end

-- ======================================================================
-- MODULE: NPCService
-- ======================================================================
__modules["NPCService"] = function()
--[[
	NPCService  (ServerScriptService.SpinServer.NPCService)

	Turns the markers in workspace.SBRMap.NPCSpawns (made by SBRMapBuilder)
	into living NPCs:
	  * R15 characters with role-based outfits colours and a name tag
	  * "Talk" ProximityPrompt: cycles through that NPC's lines
	  * Racers jog the track waypoints; others wander near home
	  * occasional ambient lines to nearby players
	  * respawn if they fall out of the world
	NPCs carry the IFrames attribute, so no attack can hurt them, and an
	"NPC" attribute so other systems can recognise them.
	Does nothing if the map isn't in the place.
]]

local Players = game:GetService("Players")

local Net = __require("Net")

local NPCService = {}

local ROLE_STYLE = {
	Announcer = { Torso = Color3.fromRGB(150, 30, 40), Legs = Color3.fromRGB(40, 35, 30), Speed = 0 },
	Official = { Torso = Color3.fromRGB(40, 50, 80), Legs = Color3.fromRGB(30, 30, 35), Speed = 8 },
	Racer = { Torso = Color3.fromRGB(70, 120, 170), Legs = Color3.fromRGB(110, 80, 50), Speed = 16 },
	Guard = { Torso = Color3.fromRGB(110, 80, 50), Legs = Color3.fromRGB(50, 40, 30), Speed = 9 },
	Spectator = { Torso = Color3.fromRGB(160, 140, 100), Legs = Color3.fromRGB(80, 60, 45), Speed = 7 },
}
local SKIN = { Color3.fromRGB(234, 184, 146), Color3.fromRGB(204, 142, 105), Color3.fromRGB(160, 105, 75), Color3.fromRGB(110, 70, 50) }

local npcs = {}
local WorldFX

local function splitLines(s)
	local lines = {}
	for line in string.gmatch(s or "", "[^|]+") do
		table.insert(lines, line)
	end
	return lines
end

local function say(npc, line, toPlayer)
	local payload = { NPC = npc.Model, Text = line }
	if toPlayer then
		WorldFX:FireClient(toPlayer, "NPCSay", payload)
	else
		WorldFX:FireAllClients("NPCSay", payload)
	end
end

local function spawnNPC(marker, waypoints, index)
	local role = marker:GetAttribute("Role") or "Spectator"
	local style = ROLE_STYLE[role] or ROLE_STYLE.Spectator
	local description = Instance.new("HumanoidDescription")
	local skin = SKIN[(index % #SKIN) + 1]
	description.HeadColor = skin
	description.LeftArmColor = style.Torso
	description.RightArmColor = style.Torso
	description.TorsoColor = style.Torso
	description.LeftLegColor = style.Legs
	description.RightLegColor = style.Legs
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[NPCService] could not create NPC:", model)
		return nil
	end
	local displayName = marker:GetAttribute("DisplayName") or marker.Name
	model.Name = displayName
	model:SetAttribute("NPC", true)
	model:SetAttribute("IFrames", true)
	model:SetAttribute("Role", role)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = displayName
	humanoid.NameDisplayDistance = 40
	humanoid.WalkSpeed = style.Speed
	humanoid.BreakJointsOnDeath = false
	local home = marker.Position + Vector3.new(0, 3, 0)
	model:PivotTo(CFrame.new(home) * CFrame.Angles(0, math.rad(index * 47), 0))
	model.Parent = marker.Parent.Parent:FindFirstChild("NPCs") or marker.Parent.Parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = displayName
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model:WaitForChild("HumanoidRootPart")

	local npc = {
		Model = model,
		Humanoid = humanoid,
		Marker = marker,
		Home = home,
		Role = role,
		Wander = marker:GetAttribute("WanderRadius") or 0,
		Lines = splitLines(marker:GetAttribute("Lines")),
		LineIndex = 0,
		NextMove = os.clock() + math.random() * 4,
		Waypoint = 1,
		Waypoints = waypoints,
		Index = index,
		Talking = 0,
	}
	prompt.Triggered:Connect(function(player)
		if #npc.Lines == 0 then
			return
		end
		npc.LineIndex = npc.LineIndex % #npc.Lines + 1
		npc.Talking = os.clock() + 4
		humanoid:MoveTo(model.HumanoidRootPart.Position) -- stop and chat
		local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if playerRoot then
			local pos = model.HumanoidRootPart.Position
			model:PivotTo(CFrame.lookAt(pos, Vector3.new(playerRoot.Position.X, pos.Y, playerRoot.Position.Z)))
		end
		say(npc, npc.Lines[npc.LineIndex], nil)
	end)
	return npc
end

local function think(npc, now)
	local model = npc.Model
	local root = model.Parent and model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if root.Position.Y < -60 then
		model:PivotTo(CFrame.new(npc.Home)) -- fell out of the world
		return
	end
	if now < npc.Talking or now < npc.NextMove then
		return
	end
	if npc.Role == "Racer" and #npc.Waypoints > 0 then
		local wp = npc.Waypoints[npc.Waypoint]
		npc.Humanoid:MoveTo(wp.Position + Vector3.new(npc.Index % 2 == 0 and 3 or -3, 0, 0))
		if (root.Position - wp.Position).Magnitude < 8 then
			npc.Waypoint = npc.Waypoint % #npc.Waypoints + 1
		end
		npc.NextMove = now + 0.5
	elseif npc.Wander > 0 then
		local angle = math.random() * math.pi * 2
		local dist = math.random() * npc.Wander
		npc.Humanoid:MoveTo(npc.Home + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist))
		npc.NextMove = now + 4 + math.random() * 5
	else
		npc.NextMove = now + 10
	end
end

-- Ambient line from an NPC close to a player, every so often.
local function ambientChatter()
	local candidates = {}
	for _, npc in ipairs(npcs) do
		local root = npc.Model:FindFirstChild("HumanoidRootPart")
		if root and #npc.Lines > 0 then
			for _, player in ipairs(Players:GetPlayers()) do
				local pr = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if pr and (pr.Position - root.Position).Magnitude < 45 then
					table.insert(candidates, npc)
					break
				end
			end
		end
	end
	if #candidates > 0 then
		local npc = candidates[math.random(1, #candidates)]
		say(npc, npc.Lines[math.random(1, #npc.Lines)], nil)
	end
end

function NPCService.init()
	WorldFX = Net.get("WorldFX")
	task.spawn(function()
		local map = workspace:FindFirstChild("SBRMap") or workspace:WaitForChild("SBRMap", 10)
		local spawns = map and map:FindFirstChild("NPCSpawns")
		if not spawns then
			return -- no map in this place: nothing to do
		end
		local container = Instance.new("Folder")
		container.Name = "NPCs"
		container.Parent = map
		local waypoints = {}
		local wpFolder = map:FindFirstChild("RacerWaypoints")
		if wpFolder then
			waypoints = wpFolder:GetChildren()
			table.sort(waypoints, function(a, b)
				return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
			end)
		end
		for i, marker in ipairs(spawns:GetChildren()) do
			local npc = spawnNPC(marker, waypoints, i)
			if npc then
				table.insert(npcs, npc)
			end
		end
		-- One shared low-frequency loop for all NPC brains (no per-NPC Heartbeat).
		local nextChatter = os.clock() + 20
		while true do
			local now = os.clock()
			for _, npc in ipairs(npcs) do
				think(npc, now)
			end
			if now >= nextChatter then
				nextChatter = now + 20 + math.random() * 20
				ambientChatter()
			end
			task.wait(0.5)
		end
	end)
end

return NPCService
end

-- ======================================================================
-- MODULE: Net
-- ======================================================================
__modules["Net"] = function()
--[[
	Net  (ReplicatedStorage.SpinShared.Net)

	Creates (server) or waits for (client) the RemoteEvents used by the
	Spin system. All remotes live in ReplicatedStorage.SpinRemotes.

	SpinRequest : client -> server  ("Start" | "Release", aimDirection | "Cancel")
	SpinFX      : server -> client  (eventName, payloadTable)
	              Also carries shared events: ProjectileSpawn/End, Hit, Damage.
	TuskRequest : client -> server  (action, ...)  see TuskService
	TuskFX      : server -> client  (eventName, payloadTable)
	WorldFX     : server -> client  map / NPC events (NPCSay)
	Bounty      : both ways         bounty board (open / accept / tracker)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES = { "SpinRequest", "SpinFX", "TuskRequest", "TuskFX", "WorldFX", "Bounty" }

local Net = {}
local folder

local function getFolder()
	if folder then
		return folder
	end
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild("SpinRemotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "SpinRemotes"
			folder.Parent = ReplicatedStorage
		end
		for _, name in ipairs(REMOTES) do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild("SpinRemotes")
	end
	return folder
end

function Net.get(name)
	return getFolder():WaitForChild(name)
end

return Net
end

-- ======================================================================
-- MODULE: ProjectileService
-- ======================================================================
__modules["ProjectileService"] = function()
--[[
	ProjectileService  (ServerScriptService.SpinServer.ProjectileService)

	Server-simulated projectiles. The server owns position, collision and
	hits; clients only draw a matching visual (told via SpinFX
	"ProjectileSpawn" / "ProjectileEnd"). No physics parts are created on
	the server, so many projectiles at once stay cheap.

	Reusable for nails, wrecking balls, etc.:
		ProjectileService.fire(owner, {
			Kind = "SteelBall", Origin = Vector3, Direction = unit Vector3,
			Speed = 120, Radius = 1, Range = 150,
			Visual = { ...any data the client effect needs... },
			OnHit = function(targetCharacter, position, projectile) end,
		})
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Net = __require("Net")
local Adapter = __require("CombatAdapter")

local FX = Net.get("SpinFX")

local ProjectileService = {}
ProjectileService.MaxActivePerPlayer = 4

local active = {}
local countByPlayer = {}
local nextId = 0

local function characterFromPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function finish(p, position, normal, hitCharacter)
	if not active[p.Id] then
		return
	end
	active[p.Id] = nil
	if p.Owner then
		countByPlayer[p.Owner] = math.max(0, (countByPlayer[p.Owner] or 1) - 1)
	end
	-- Tell OnEnd why it stopped: hit a character, hit a wall/ground, or ran out of range.
	p.HitWall = hitCharacter == nil and normal ~= nil
	if hitCharacter and p.OnHit then
		local ok, err = pcall(p.OnHit, hitCharacter, position, p)
		if not ok then
			warn("[ProjectileService] OnHit error:", err)
		end
	end
	if p.OnEnd then
		local ok, err = pcall(p.OnEnd, position, normal or Vector3.new(0, 1, 0), hitCharacter, p)
		if not ok then
			warn("[ProjectileService] OnEnd error:", err)
		end
	end
	FX:FireAllClients("ProjectileEnd", {
		Id = p.Id,
		Kind = p.Kind,
		Position = position,
		Normal = normal or Vector3.new(0, 1, 0),
		HitCharacter = hitCharacter ~= nil,
		OwnerId = p.OwnerId,
		Visual = p.Visual,
	})
end

local function ignore(p, instance)
	local list = p.Params.FilterDescendantsInstances
	table.insert(list, instance)
	p.Params.FilterDescendantsInstances = list
end

-- Point-blank check: Spherecast misses parts already inside the start sphere.
local function overlapAtStart(p)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = p.Params.FilterDescendantsInstances
	for _, part in ipairs(workspace:GetPartBoundsInRadius(p.Position, p.Radius, overlap)) do
		local character = characterFromPart(part)
		if character and Adapter.canBeHit(p.Owner, character) then
			return character, part.Position
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Stopped time (The World): a zone where projectiles hang in the air. Other
-- people's projectiles stop the moment they're inside; the zone owner's own
-- stop once they've flown OwnFreezeAfter studs. They all fly on when the
-- zone ends. Clients are told ("ProjectileFreeze" / "ProjectileResume") with
-- each projectile's flight time so the visuals stop and restart in step.
---------------------------------------------------------------------------
ProjectileService.OwnFreezeAfter = 5
local zones = {} -- [token] = { Center, Radius, Owner }

local function flightOf(p)
	return p.Traveled / math.max(p.Speed, 1e-3)
end

local function inZone(p)
	for token, z in pairs(zones) do
		if (p.Position - z.Center).Magnitude <= z.Radius and (p.Owner ~= z.Owner or p.Traveled >= ProjectileService.OwnFreezeAfter) then
			return token
		end
	end
	return nil
end

local function freeze(list, token)
	local ids, flights, spawned = {}, {}, {}
	for _, p in ipairs(list) do
		p.FrozenBy = token
		table.insert(ids, p.Id)
		table.insert(flights, flightOf(p))
		table.insert(spawned, p.SpawnedAt)
	end
	if #ids > 0 then
		FX:FireAllClients("ProjectileFreeze", { Ids = ids, Flights = flights, Spawned = spawned })
	end
end

function ProjectileService.stopTime(token, center, radius, owner)
	zones[token] = { Center = center, Radius = radius, Owner = owner }
	local list = {}
	for _, p in pairs(active) do
		if not p.FrozenBy and inZone(p) == token then
			table.insert(list, p)
		end
	end
	freeze(list, token)
end

function ProjectileService.resumeTime(token)
	zones[token] = nil
	local ids, flights, spawned = {}, {}, {}
	for _, p in pairs(active) do
		if p.FrozenBy == token then
			p.FrozenBy = nil
			table.insert(ids, p.Id)
			table.insert(flights, flightOf(p))
			table.insert(spawned, p.SpawnedAt)
		end
	end
	if #ids > 0 then
		FX:FireAllClients("ProjectileResume", { Ids = ids, Flights = flights, Spawned = spawned })
	end
end

function ProjectileService.isTimeStopped(position)
	for _, z in pairs(zones) do
		if (position - z.Center).Magnitude <= z.Radius then
			return true
		end
	end
	return false
end

function ProjectileService.activeCount(player)
	return countByPlayer[player] or 0
end

function ProjectileService.fire(owner, spec)
	if owner and ProjectileService.activeCount(owner) >= ProjectileService.MaxActivePerPlayer then
		return nil
	end
	nextId = nextId + 1

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local filter = {}
	if owner and owner.Character then
		table.insert(filter, owner.Character)
	end
	params.FilterDescendantsInstances = filter

	local p = {
		Id = nextId,
		Owner = owner,
		OwnerId = owner and owner.UserId or 0,
		Kind = spec.Kind or "Projectile",
		Position = spec.Origin,
		Direction = spec.Direction.Unit,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Traveled = 0,
		Params = params,
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd, -- function(position, normal, hitCharacter, projectile): always called once
		-- (projectile.HitWall is true when it stopped on a wall / the ground)
		Visual = spec.Visual or {},
		SpawnedAt = workspace:GetServerTimeNow(),
	}
	active[p.Id] = p
	if owner then
		countByPlayer[owner] = (countByPlayer[owner] or 0) + 1
	end

	FX:FireAllClients("ProjectileSpawn", {
		Id = p.Id,
		Kind = p.Kind,
		Origin = p.Position,
		Direction = p.Direction,
		Speed = p.Speed,
		Range = p.Range,
		OwnerId = owner and owner.UserId or 0,
		ServerTime = p.SpawnedAt,
		Visual = p.Visual,
	})

	local character, position = overlapAtStart(p)
	if character then
		finish(p, position, nil, character)
	end
	return p.Id
end

RunService.Heartbeat:Connect(function(dt)
	for _, p in pairs(active) do
		if p.FrozenBy then
			continue -- hanging in stopped time
		end
		local step = math.min(p.Speed * dt, p.Range - p.Traveled)
		if step <= 0.01 then
			finish(p, p.Position, nil, nil)
		else
			local result = workspace:Spherecast(p.Position, p.Radius, p.Direction * step, p.Params)
			if result then
				local character = characterFromPart(result.Instance)
				if character then
					if Adapter.canBeHit(p.Owner, character) then
						finish(p, result.Position, result.Normal, character)
					else
						ignore(p, character) -- ally / i-frames / dead: pass through
					end
				else
					finish(p, result.Position, result.Normal, nil) -- wall / ground
				end
			else
				p.Position = p.Position + p.Direction * step
				p.Traveled = p.Traveled + step
				if next(zones) then
					local token = inZone(p)
					if token then
						freeze({ p }, token)
					end
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	countByPlayer[player] = nil
	for _, p in pairs(active) do
		if p.Owner == player then
			p.Owner = nil
			p.OnHit = nil
			p.OnEnd = nil
			finish(p, p.Position, nil, nil)
		end
	end
end)

return ProjectileService
end

-- ======================================================================
-- MODULE: SBRMapBuilder
-- ======================================================================
__modules["SBRMapBuilder"] = function()
--[[
	SBRMapBuilder  (ServerStorage.SpinTools.SBRMapBuilder — ModuleScript)

	One-time Studio tool that builds an original Steel Ball Run-style
	western map into your place as normal, editable parts + terrain:

	  * race grounds: dirt track, rail fences, START/GOAL arch, flags
	  * mission church at the end of the track
	  * racers' tent camp with covered wagons
	  * western town (saloon, store, sheriff, hotel, bank, stables,
	    post office, blacksmith) with an entrance banner arch
	  * Race Headquarters building on the hill
	  * desert: sand terrain, mountain ring, rocks, cacti, grass patches
	  * desert lighting, atmosphere, clouds, spawn point
	  * NPC spawn markers (NPCService turns them into NPCs at runtime)
	  * new places: Rattlesnake River with a mesa waterfall, covered bridge
	    and railway trestle, gold-panning camp, Dustwater ghost town,
	    Lucky Horseshoe Ranch, Fort Dust, and a signpost at the race start
	  * detail pass: sagebrush, grass tufts, prickly pear, Joshua trees,
	    boulders, hoodoos, bones, broken wagons, old fences, pebbles, dunes,
	    hard-ground and salt patches (only in open ground); town porches with
	    railings, shutters, hanging signs, benches, chimneys; race distance
	    markers, pennant lines, judges' tower, hay bales, a crowd, a water
	    station; logs, cooking pots, smoke and laundry lines at the camp

	HOW TO RUN (Studio, edit mode):
	  View > Command Bar, paste and press Enter:
	    require(game.ServerStorage.SpinTools.SBRMapBuilder).Build()
	  Options:
	    .Build({ Origin = Vector3.new(0, 0, 0), Terrain = true, Lighting = true, Seed = 7 })
	  Running it again replaces the previous "SBRMap" model (terrain is
	  re-filled in the map area only). Tip: try it in a new Baseplate place
	  first, or pass an Origin away from your existing map.
	  Then File > Save.
]]

local Lighting = game:GetService("Lighting")

local SBRMapBuilder = {}

local C = {
	Stucco = Color3.fromRGB(214, 198, 170),
	StuccoDark = Color3.fromRGB(176, 158, 128),
	Wood = Color3.fromRGB(122, 84, 52),
	WoodDark = Color3.fromRGB(84, 56, 34),
	WoodLight = Color3.fromRGB(160, 118, 76),
	Canvas = Color3.fromRGB(232, 226, 210),
	Red = Color3.fromRGB(176, 40, 36),
	White = Color3.fromRGB(240, 236, 228),
	Brick = Color3.fromRGB(150, 70, 56),
	Roof = Color3.fromRGB(96, 40, 44),
	Window = Color3.fromRGB(40, 36, 44),
	Green = Color3.fromRGB(70, 120, 50),
	Cactus = Color3.fromRGB(80, 120, 60),
	Gold = Color3.fromRGB(220, 170, 60),
}

local FLAG_PALETTES = {
	{ Color3.fromRGB(200, 30, 40), Color3.fromRGB(245, 245, 240) },
	{ Color3.fromRGB(30, 60, 150), Color3.fromRGB(245, 245, 240), Color3.fromRGB(200, 30, 40) },
	{ Color3.fromRGB(20, 120, 60), Color3.fromRGB(250, 210, 40) },
	{ Color3.fromRGB(245, 245, 240), Color3.fromRGB(30, 110, 60) },
	{ Color3.fromRGB(20, 20, 20), Color3.fromRGB(250, 200, 30), Color3.fromRGB(200, 30, 40) },
	{ Color3.fromRGB(30, 80, 170), Color3.fromRGB(250, 210, 40) },
	{ Color3.fromRGB(200, 30, 40), Color3.fromRGB(30, 60, 150) },
}

local root, origin, rng

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or root
	return f
end

local function block(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(origin) * cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function cylinder(parent, name, length, diameter, cf, color, material)
	-- Cylinder axis is X; callers pass cf with the axis already rotated as needed.
	return block(parent, name, Vector3.new(length, diameter, diameter), cf, color, material, { Shape = Enum.PartType.Cylinder })
end

local function upright(x, y, z)
	return CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2)
end

local function sign(part, face, text, textColor, bg, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bg or part.Color
	label.BackgroundTransparency = bg and 0 or 1
	label.Font = font or Enum.Font.Fondamento
	label.TextScaled = true
	label.TextColor3 = textColor or Color3.fromRGB(30, 20, 10)
	label.Text = text
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = label
	return gui
end

local function stripedPole(parent, x, z, height)
	local segments = 8
	local seg = height / segments
	for i = 0, segments - 1 do
		cylinder(parent, "PoleStripe", seg, 1.2, upright(x, seg * (i + 0.5), z), i % 2 == 0 and C.Red or C.White)
	end
	block(parent, "PoleCap", Vector3.new(1.5, 1.5, 1.5), CFrame.new(x, height + 0.6, z), C.Gold, Enum.Material.Metal, { Shape = Enum.PartType.Ball })
end

local function flag(parent, x, z, height, palette, yaw)
	cylinder(parent, "FlagPole", height, 0.35, upright(x, height / 2, z), C.WoodLight, Enum.Material.Wood)
	local stripes = #palette
	local w, h = 5, 3.2
	for i, color in ipairs(palette) do
		local stripeH = h / stripes
		block(parent, "Flag", Vector3.new(w, stripeH, 0.12),
			CFrame.new(x, height - 0.4 - stripeH * (i - 0.5), z) * CFrame.Angles(0, yaw or 0, 0) * CFrame.new(w / 2 + 0.2, 0, 0),
			color, Enum.Material.Fabric)
	end
end

local function tent(parent, x, z, yaw, scale)
	scale = scale or 1
	-- A block rotated 45 degrees and sunk halfway reads as an A-frame tent.
	local s = 6 * scale
	block(parent, "Tent", Vector3.new(s, s, 9 * scale),
		CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.pi / 4),
		C.Canvas, Enum.Material.Fabric)
	block(parent, "TentDoor", Vector3.new(1.6 * scale, 2.2 * scale, 0.1),
		CFrame.new(x, 1.1 * scale, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -4.5 * scale - 0.06),
		C.WoodDark, Enum.Material.Fabric)
end

local function wagon(parent, x, z, yaw)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local function at(cf)
		return base * cf
	end
	local model = Instance.new("Model")
	model.Name = "CoveredWagon"
	model.Parent = parent
	block(model, "Bed", Vector3.new(4.4, 1.6, 9), at(CFrame.new(0, 2.6, 0)), C.Wood, Enum.Material.WoodPlanks)
	-- Canvas: long cylinder along Z, lower half hidden inside the bed.
	block(model, "Canvas", Vector3.new(8.6, 4.6, 4.6), at(CFrame.new(0, 3.3, 0) * CFrame.Angles(0, math.pi / 2, 0)), C.Canvas, Enum.Material.Fabric, { Shape = Enum.PartType.Cylinder })
	for _, wz in ipairs({ -3, 3 }) do
		for _, wx in ipairs({ -2.5, 2.5 }) do
			local d = wz > 0 and 3.6 or 3
			block(model, "Wheel", Vector3.new(0.4, d, d), at(CFrame.new(wx, d / 2, wz)), C.WoodDark, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
		end
	end
	block(model, "Tongue", Vector3.new(0.4, 0.4, 5), at(CFrame.new(0, 1.6, -7) * CFrame.Angles(0.15, 0, 0)), C.WoodDark, Enum.Material.Wood)
end

local function fenceLine(parent, x, z0, z1)
	local step = 8
	local count = math.floor(math.abs(z1 - z0) / step)
	local dir = z1 > z0 and 1 or -1
	for i = 0, count do
		local z = z0 + i * step * dir
		block(parent, "FencePost", Vector3.new(0.6, 3.4, 0.6), CFrame.new(x, 1.7, z), C.WoodDark, Enum.Material.Wood)
	end
	local length = count * step
	local mid = z0 + dir * length / 2
	for _, y in ipairs({ 1.4, 2.8 }) do
		block(parent, "FenceRail", Vector3.new(0.35, 0.35, length), CFrame.new(x, y, mid), C.WoodLight, Enum.Material.Wood)
	end
end

local function windowRow(parent, cf, count, spacing, size)
	for i = 1, count do
		local offset = (i - (count + 1) / 2) * spacing
		block(parent, "Window", size, cf * CFrame.new(offset, 0, 0), C.Window, Enum.Material.Glass, { Transparency = 0.1 })
	end
end

---------------------------------------------------------------------------
-- Sections
---------------------------------------------------------------------------
local function buildTerrain()
	local terrain = workspace.Terrain
	local o = origin
	terrain:FillBlock(CFrame.new(o + Vector3.new(0, -8, 0)), Vector3.new(1400, 16, 1400), Enum.Material.Sand)
	-- Race track strip and town street (hard-packed ground).
	terrain:FillBlock(CFrame.new(o + Vector3.new(0, -0.6, -50)), Vector3.new(26, 1.2, 420), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(o + Vector3.new(260, -0.6, -40)), Vector3.new(30, 1.2, 240), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(o + Vector3.new(130, -0.6, 100)), Vector3.new(260, 1.2, 18), Enum.Material.Ground)
	-- Grass around the town and headquarters hill.
	for _ = 1, 26 do
		local p = o + Vector3.new(rng:NextNumber(180, 360), -0.8, rng:NextNumber(-220, 120))
		terrain:FillCylinder(CFrame.new(p), 1, rng:NextNumber(6, 18), Enum.Material.Grass)
	end
	-- Headquarters hill.
	terrain:FillBall(o + Vector3.new(260, -70, -265), 90, Enum.Material.Grass)
	-- Mountain ring.
	for i = 1, 30 do
		local angle = (i / 30) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local dist = rng:NextNumber(520, 620)
		local radius = rng:NextNumber(70, 130)
		local p = o + Vector3.new(math.cos(angle) * dist, -radius * 0.45, math.sin(angle) * dist)
		terrain:FillBall(p, radius, i % 3 == 0 and Enum.Material.Rock or Enum.Material.Sandstone)
	end
	-- Rocks scattered in the desert.
	for _ = 1, 60 do
		local p = o + Vector3.new(rng:NextNumber(-450, 450), 0, rng:NextNumber(-450, 450))
		if math.abs(p.X - o.X) > 30 or math.abs(p.Z - o.Z + 50) > 220 then
			terrain:FillBall(p, rng:NextNumber(2, 6), Enum.Material.Sandstone)
		end
	end
end

local function buildLighting()
	Lighting.ClockTime = 14.6
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(110, 96, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 135, 115)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	local function ensure(class, name)
		local existing = Lighting:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
		local inst = Instance.new(class)
		inst.Name = name
		inst.Parent = Lighting
		return inst
	end
	local atmosphere = ensure("Atmosphere", "SBRAtmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(230, 205, 170)
	atmosphere.Decay = Color3.fromRGB(190, 150, 110)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.6
	local cc = ensure("ColorCorrectionEffect", "SBRWarmth")
	cc.TintColor = Color3.fromRGB(255, 244, 228)
	cc.Saturation = 0.05
	cc.Contrast = 0.06
	local rays = ensure("SunRaysEffect", "SBRSunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	local bloom = ensure("BloomEffect", "SBRBloom")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.6
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = workspace.Terrain
end

local function buildRaceGrounds()
	local f = folder("RaceGrounds")
	fenceLine(f, -14, 140, -250)
	fenceLine(f, 14, 140, -250)

	-- START / GOAL arch.
	local archZ = 110
	stripedPole(f, -16, archZ, 22)
	stripedPole(f, 16, archZ, 22)
	local bannerPart = block(f, "RaceBanner", Vector3.new(30, 6, 0.4), CFrame.new(0, 18, archZ), C.White, Enum.Material.Fabric)
	sign(bannerPart, Enum.NormalId.Front, "★ STEEL BALL RUN ★  START", C.Red, C.White, Enum.Font.Fondamento)
	sign(bannerPart, Enum.NormalId.Back, "★ STEEL BALL RUN ★  GOAL", C.Red, C.White, Enum.Font.Fondamento)
	for _, x in ipairs({ -12.5, 12.5 }) do
		block(f, "BannerStripe", Vector3.new(1, 6, 0.45), CFrame.new(x, 18, archZ), C.Red, Enum.Material.Fabric)
	end

	-- Flags lining the track.
	for i = 0, 11 do
		local z = 120 - i * 32
		flag(f, -22, z, 16, FLAG_PALETTES[(i % #FLAG_PALETTES) + 1], math.pi)
		flag(f, 22, z - 16, 16, FLAG_PALETTES[((i + 3) % #FLAG_PALETTES) + 1], 0)
	end

	-- Spectator stand near the start.
	for row = 0, 3 do
		block(f, "Bleacher", Vector3.new(4, 1, 40), CFrame.new(-30 - row * 4, 1 + row * 1.6, 70), C.WoodLight, Enum.Material.WoodPlanks)
	end
	block(f, "BleacherRoof", Vector3.new(20, 0.6, 44), CFrame.new(-36, 11, 70) * CFrame.Angles(0, 0, -0.12), C.Red, Enum.Material.Fabric)
	for _, z in ipairs({ 50, 90 }) do
		cylinder(f, "BleacherPost", 10, 0.6, upright(-27, 5, z), C.WoodDark, Enum.Material.Wood)
		cylinder(f, "BleacherPost", 12, 0.6, upright(-45, 6, z), C.WoodDark, Enum.Material.Wood)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SBRSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(origin + Vector3.new(0, 0.5, 150))
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Color = C.WoodLight
	spawn.Duration = 0
	spawn.Parent = f
end

local function buildChurch()
	local f = folder("MissionChurch")
	local z = -300
	block(f, "Nave", Vector3.new(36, 24, 60), CFrame.new(0, 12, z - 20), C.Stucco, Enum.Material.Limestone)
	block(f, "NaveRoof", Vector3.new(38, 2, 62), CFrame.new(0, 25, z - 20), C.StuccoDark, Enum.Material.Limestone)
	local facade = block(f, "Facade", Vector3.new(40, 30, 3), CFrame.new(0, 15, z + 11), C.Stucco, Enum.Material.Limestone)
	block(f, "FacadeGable", Vector3.new(16, 8, 3), CFrame.new(0, 33, z + 11), C.Stucco, Enum.Material.Limestone)
	block(f, "Doorway", Vector3.new(9, 13, 0.4), CFrame.new(0, 6.5, z + 12.6), C.WoodDark, Enum.Material.Wood)
	block(f, "DoorArch", Vector3.new(9, 9, 0.5), CFrame.new(0, 13, z + 12.5) * CFrame.Angles(0, math.pi / 2, 0), C.WoodDark, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
	windowRow(f, CFrame.new(0, 22, z + 12.6), 3, 6, Vector3.new(2, 4, 0.3))
	for _, x in ipairs({ -22, 22 }) do
		block(f, "BellTower", Vector3.new(12, 44, 12), CFrame.new(x, 22, z + 8), C.Stucco, Enum.Material.Limestone)
		block(f, "BellLoft", Vector3.new(9, 8, 9), CFrame.new(x, 48, z + 8), C.StuccoDark, Enum.Material.Limestone)
		block(f, "BellOpening", Vector3.new(4, 5, 9.2), CFrame.new(x, 48, z + 8), C.Window, Enum.Material.SmoothPlastic)
		block(f, "TowerDome", Vector3.new(8, 8, 8), CFrame.new(x, 52, z + 8), C.StuccoDark, Enum.Material.Limestone, { Shape = Enum.PartType.Ball })
		block(f, "CrossV", Vector3.new(0.5, 4, 0.5), CFrame.new(x, 58, z + 8), C.WoodDark, Enum.Material.Wood)
		block(f, "CrossH", Vector3.new(2.2, 0.5, 0.5), CFrame.new(x, 58.6, z + 8), C.WoodDark, Enum.Material.Wood)
		windowRow(f, CFrame.new(x, 30, z + 14.1), 1, 0, Vector3.new(2.2, 4, 0.3))
	end
	block(f, "Dome", Vector3.new(20, 20, 20), CFrame.new(0, 26, z - 26), C.StuccoDark, Enum.Material.Limestone, { Shape = Enum.PartType.Ball })
	block(f, "DomeLantern", Vector3.new(3, 5, 3), CFrame.new(0, 37, z - 26), C.Stucco, Enum.Material.Limestone)
	-- Courtyard wall with gate.
	for _, x in ipairs({ -32, 32 }) do
		block(f, "CourtWall", Vector3.new(20, 8, 2), CFrame.new(x, 4, z + 24), C.Brick, Enum.Material.Brick)
	end
	for _, x in ipairs({ -22, 22 }) do
		block(f, "CourtWallSide", Vector3.new(2, 8, 14), CFrame.new(x * 1.92, 4, z + 17), C.Brick, Enum.Material.Brick)
	end
end

local function buildCamp()
	local f = folder("TentCamp")
	for side = -1, 1, 2 do
		for i = 0, 13 do
			for j = 0, 2 do
				local x = side * (40 + j * 24 + rng:NextNumber(-4, 4))
				local z = 40 - i * 18 + rng:NextNumber(-4, 4)
				if rng:NextNumber() < 0.68 then
					tent(f, x, z, rng:NextNumber(-0.4, 0.4) + (side > 0 and math.pi / 2 or -math.pi / 2), rng:NextNumber(0.85, 1.15))
				elseif rng:NextNumber() < 0.6 then
					wagon(f, x, z, rng:NextNumber(0, math.pi * 2))
				end
			end
		end
	end
	-- Campfires.
	for _ = 1, 8 do
		local x = (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(45, 100)
		local z = rng:NextNumber(-200, 50)
		local fire = block(f, "Campfire", Vector3.new(2.4, 0.6, 2.4), CFrame.new(x, 0.3, z), C.WoodDark, Enum.Material.Wood)
		local emitter = Instance.new("Fire")
		emitter.Size = 4
		emitter.Heat = 6
		emitter.Parent = fire
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 160, 80)
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = fire
	end
end

local TOWN_BUILDINGS = { "SALOON", "GENERAL STORE", "SHERIFF", "HOTEL", "BANK", "STABLES", "POST OFFICE", "BLACKSMITH" }

local function westernBuilding(parent, name, cf, width, depth, height, color)
	local model = Instance.new("Model")
	model.Name = name:gsub(" ", "")
	model.Parent = parent
	local function at(offset)
		return cf * offset
	end
	block(model, "Body", Vector3.new(width, height, depth), at(CFrame.new(0, height / 2, depth / 2)), color, Enum.Material.WoodPlanks)
	block(model, "Roof", Vector3.new(width + 1, 1, depth + 1), at(CFrame.new(0, height + 0.5, depth / 2)), C.Roof, Enum.Material.WoodPlanks)
	-- False front, taller than the building (classic western look).
	local front = block(model, "FalseFront", Vector3.new(width + 1, height + 6, 1), at(CFrame.new(0, (height + 6) / 2, -0.5)), color, Enum.Material.WoodPlanks)
	local board = block(model, "SignBoard", Vector3.new(width - 2, 3.2, 0.3), at(CFrame.new(0, height + 2.5, -1.15)), C.WoodDark, Enum.Material.Wood)
	sign(board, Enum.NormalId.Front, name, Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	-- Door, windows, porch.
	block(model, "Door", Vector3.new(3.2, 6.5, 0.3), at(CFrame.new(0, 3.25, -1.1)), C.WoodDark, Enum.Material.Wood)
	windowRow(model, at(CFrame.new(0, 4, -1.1)), 2, width * 0.55, Vector3.new(3, 3.6, 0.2))
	windowRow(model, at(CFrame.new(0, height - 3, -1.1)), 3, width * 0.28, Vector3.new(2.4, 3, 0.2))
	block(model, "PorchFloor", Vector3.new(width + 1, 0.6, 6), at(CFrame.new(0, 0.3, -4)), C.WoodLight, Enum.Material.WoodPlanks)
	block(model, "PorchRoof", Vector3.new(width + 1, 0.5, 6.5), at(CFrame.new(0, 8.6, -4) * CFrame.Angles(-0.12, 0, 0)), C.Roof, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -width / 2, 0, width / 2 }) do
		block(model, "PorchPost", Vector3.new(0.5, 8, 0.5), at(CFrame.new(x, 4.3, -6.8)), C.WoodDark, Enum.Material.Wood)
	end
	-- DETAIL: porch railings, plank lines, shutters, a hanging sign, a bench,
	-- a chimney and a rain barrel on the roof.
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (width / 4 + 1.5)
		block(model, "Railing", Vector3.new(width / 2 - 3, 0.3, 0.3), at(CFrame.new(x, 3, -6.8)), C.WoodDark, Enum.Material.Wood)
		for k = -1, 1 do
			block(model, "Baluster", Vector3.new(0.2, 2.4, 0.2), at(CFrame.new(x + k * (width / 8), 1.8, -6.8)), C.WoodDark, Enum.Material.Wood).CastShadow = false
		end
		-- Shutters beside the lower windows.
		for _, dx in ipairs({ -2, 2 }) do
			block(model, "Shutter", Vector3.new(1, 3.6, 0.15), at(CFrame.new(side * width * 0.275 + dx, 4, -1.25)), Color3.fromRGB(70, 90, 70), Enum.Material.Wood).CastShadow = false
		end
	end
	for k = 1, 4 do
		block(model, "PlankLine", Vector3.new(width + 1.02, 0.12, 0.05), at(CFrame.new(0, height + 6 - k * 1.3, -1.02)), C.WoodDark, Enum.Material.Wood).CastShadow = false
	end
	local hanging = block(model, "HangingSign", Vector3.new(4, 1.4, 0.2), at(CFrame.new(width / 2 - 3, 6.6, -6.6)), C.WoodLight, Enum.Material.Wood)
	sign(hanging, Enum.NormalId.Front, name, Color3.fromRGB(60, 30, 20), nil, Enum.Font.Fondamento)
	block(model, "Bench", Vector3.new(5, 0.4, 1.4), at(CFrame.new(-width / 4, 1.6, -3)), C.WoodLight, Enum.Material.WoodPlanks)
	for _, dx in ipairs({ -2, 2 }) do
		block(model, "BenchLeg", Vector3.new(0.3, 1.1, 1.2), at(CFrame.new(-width / 4 + dx, 1.05, -3)), C.WoodDark, Enum.Material.Wood).CastShadow = false
	end
	block(model, "Chimney", Vector3.new(1.6, 4, 1.6), at(CFrame.new(width / 2 - 2.5, height + 2.5, depth - 3)), C.Brick, Enum.Material.Brick)
	block(model, "RoofBarrel", Vector3.new(2.4, 2, 2), at(CFrame.new(-width / 2 + 2.5, height + 1.9, depth - 4)) * CFrame.Angles(0, 0, math.pi / 2), C.Wood, Enum.Material.Wood).Shape = Enum.PartType.Cylinder
	return model
end

local function buildTown()
	local f = folder("WesternTown")
	local streetX = 260
	local colors = { C.Wood, C.WoodLight, Color3.fromRGB(150, 90, 70), Color3.fromRGB(120, 110, 90), C.Brick }
	for i, name in ipairs(TOWN_BUILDINGS) do
		local side = (i % 2 == 1) and -1 or 1
		local row = math.floor((i - 1) / 2)
		local z = 40 - row * 34
		local x = streetX + side * 24
		-- Front faces the street.
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, side * math.pi / 2, 0)
		westernBuilding(f, name, cf, 18, 20, 12 + (i % 3) * 2, colors[(i % #colors) + 1])
	end
	-- Entrance arch banner.
	for _, x in ipairs({ streetX - 15, streetX + 15 }) do
		block(f, "ArchPost", Vector3.new(1.4, 20, 1.4), CFrame.new(x, 10, 90), C.WoodDark, Enum.Material.Wood)
	end
	block(f, "ArchBeam", Vector3.new(34, 1.4, 1.4), CFrame.new(streetX, 19.5, 90), C.WoodDark, Enum.Material.Wood)
	local banner = block(f, "TownBanner", Vector3.new(26, 5, 0.3), CFrame.new(streetX, 15.5, 90), Color3.fromRGB(150, 175, 90), Enum.Material.Fabric)
	sign(banner, Enum.NormalId.Front, "★ STEEL BALL RUN RACE ★", Color3.fromRGB(25, 25, 20), nil, Enum.Font.Fondamento)
	sign(banner, Enum.NormalId.Back, "★ STEEL BALL RUN RACE ★", Color3.fromRGB(25, 25, 20), nil, Enum.Font.Fondamento)
	-- Props: barrels, crates, troughs, hitching rails, lamp posts.
	for i = 1, 14 do
		local side = i % 2 == 0 and -1 or 1
		local z = 50 - i * 12
		local x = streetX + side * rng:NextNumber(11, 13)
		local roll = rng:NextNumber()
		if roll < 0.35 then
			block(f, "Barrel", Vector3.new(3, 2.4, 2.4), upright(x, 1.5, z), C.Wood, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
		elseif roll < 0.6 then
			block(f, "Crate", Vector3.new(2.6, 2.6, 2.6), CFrame.new(x, 1.3, z) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), C.WoodLight, Enum.Material.WoodPlanks)
		elseif roll < 0.8 then
			block(f, "Trough", Vector3.new(2, 1.6, 6), CFrame.new(x, 0.8, z), C.WoodDark, Enum.Material.Wood)
			block(f, "TroughWater", Vector3.new(1.6, 0.2, 5.6), CFrame.new(x, 1.5, z), Color3.fromRGB(70, 110, 130), Enum.Material.Glass, { Transparency = 0.3 })
		else
			block(f, "HitchRail", Vector3.new(0.4, 0.4, 7), CFrame.new(x, 2.8, z), C.WoodDark, Enum.Material.Wood)
			block(f, "HitchPost", Vector3.new(0.4, 3, 0.4), CFrame.new(x, 1.5, z - 3.3), C.WoodDark, Enum.Material.Wood)
			block(f, "HitchPost", Vector3.new(0.4, 3, 0.4), CFrame.new(x, 1.5, z + 3.3), C.WoodDark, Enum.Material.Wood)
		end
	end
	for i = 0, 4 do
		for _, side in ipairs({ -1, 1 }) do
			local x, z = streetX + side * 14, 60 - i * 34
			block(f, "LampPost", Vector3.new(0.4, 10, 0.4), CFrame.new(x, 5, z), Color3.fromRGB(40, 40, 40), Enum.Material.Metal)
			local lamp = block(f, "Lamp", Vector3.new(1, 1.4, 1), CFrame.new(x, 10.4, z), Color3.fromRGB(255, 220, 150), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Range = 16
			light.Brightness = 0.8
			light.Color = Color3.fromRGB(255, 200, 130)
			light.Parent = lamp
		end
	end
end

local function buildHeadquarters()
	local f = folder("RaceHeadquarters")
	local base = CFrame.new(260, 18, -270)
	local function at(cf)
		return base * cf
	end
	block(f, "Foundation", Vector3.new(96, 24, 36), at(CFrame.new(0, -12, 0)), Color3.fromRGB(150, 140, 120), Enum.Material.Cobblestone)
	block(f, "Main", Vector3.new(90, 22, 30), at(CFrame.new(0, 11, 0)), C.Brick, Enum.Material.Brick)
	block(f, "Roof", Vector3.new(92, 3, 32), at(CFrame.new(0, 23.5, 0)), C.Roof, Enum.Material.Slate)
	for _, y in ipairs({ 6, 16 }) do
		windowRow(f, at(CFrame.new(0, y, 15.1)), 11, 7.6, Vector3.new(2.6, 5, 0.3))
	end
	for _, x in ipairs({ -36, 0, 36 }) do
		local h = x == 0 and 18 or 12
		block(f, "Tower", Vector3.new(10, h, 10), at(CFrame.new(x, 22 + h / 2, 2)), C.Brick, Enum.Material.Brick)
		block(f, "Spire", Vector3.new(7, 9, 7), at(CFrame.new(x, 22 + h + 3, 2) * CFrame.Angles(0, math.pi / 4, 0)), C.Roof, Enum.Material.Slate)
		block(f, "SpireTip", Vector3.new(3, 6, 3), at(CFrame.new(x, 22 + h + 9, 2) * CFrame.Angles(0, math.pi / 4, 0)), C.Roof, Enum.Material.Slate)
		block(f, "SpirePole", Vector3.new(0.3, 4, 0.3), at(CFrame.new(x, 22 + h + 13.5, 2)), C.WoodDark, Enum.Material.Wood)
		block(f, "SpireFlag", Vector3.new(2.6, 1.6, 0.1), at(CFrame.new(x + 1.4, 22 + h + 14.6, 2)), Color3.fromRGB(110, 190, 120), Enum.Material.Fabric)
	end
	local billboard = block(f, "RaceSign", Vector3.new(40, 16, 1), at(CFrame.new(0, 2, 34)), C.Red, Enum.Material.WoodPlanks)
	sign(billboard, Enum.NormalId.Front, "STEEL BALL RUN\nRACE HEADQUARTERS", Color3.fromRGB(240, 200, 120), nil, Enum.Font.Fondamento)
	for _, x in ipairs({ -16, 16 }) do
		block(f, "SignLeg", Vector3.new(1, 12, 1), at(CFrame.new(x, -6, 34.8)), C.WoodDark, Enum.Material.Wood)
	end
end

local function cactus(parent, x, z)
	local h = rng:NextNumber(7, 14)
	cylinder(parent, "CactusTrunk", h, 1.6, upright(x, h / 2, z), C.Cactus, Enum.Material.Grass)
	local arms = rng:NextInteger(0, 2)
	for i = 1, arms do
		local side = i == 1 and 1 or -1
		local armY = h * rng:NextNumber(0.4, 0.65)
		local armH = rng:NextNumber(2.5, 4.5)
		block(parent, "CactusArm", Vector3.new(2.2, 1.1, 1.1), CFrame.new(x + side * 1.3, armY, z), C.Cactus, Enum.Material.Grass)
		cylinder(parent, "CactusArm", armH, 1.1, upright(x + side * 2.2, armY + armH / 2, z), C.Cactus, Enum.Material.Grass)
	end
end

local function buildDesert()
	local f = folder("Desert")
	for _ = 1, 55 do
		local x, z = rng:NextNumber(-450, 450), rng:NextNumber(-450, 450)
		local nearTrack = math.abs(x) < 130 and z > -330 and z < 160
		local nearTown = x > 170 and x < 350 and z > -320 and z < 130
		if not nearTrack and not nearTown then
			cactus(f, x, z)
		end
	end
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-450, 450), rng:NextNumber(-450, 450)
		if math.abs(x) > 120 then
			local s = rng:NextNumber(2, 4)
			block(f, "Bush", Vector3.new(s, s * 0.7, s), CFrame.new(x, s * 0.25, z), Color3.fromRGB(110, 120, 70), Enum.Material.Grass, { Shape = Enum.PartType.Ball })
		end
	end
	-- Large sandstone blocks.
	for _ = 1, 14 do
		local x, z = rng:NextNumber(-400, 400), rng:NextNumber(-400, 400)
		if math.abs(x) > 140 and not (x > 170 and x < 350) then
			local s = rng:NextNumber(5, 10)
			block(f, "Boulder", Vector3.new(s, s * 0.8, s * 1.1), CFrame.new(x, s * 0.3, z) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6), rng:NextNumber(-0.2, 0.2)), Color3.fromRGB(196, 160, 118), Enum.Material.Sandstone)
		end
	end
end

---------------------------------------------------------------------------
-- MAP UPGRADE: props
---------------------------------------------------------------------------
local CollectionService = game:GetService("CollectionService")

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function ellipsoid(parent, name, size, cf, color, material)
	local p = block(parent, name, size, cf, color, material or Enum.Material.SmoothPlastic)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function small(p)
	p.CastShadow = false
	return p
end

local HORSE_COATS = {
	Color3.fromRGB(110, 70, 40), Color3.fromRGB(60, 40, 30), Color3.fromRGB(200, 190, 175),
	Color3.fromRGB(150, 100, 60), Color3.fromRGB(35, 30, 30), Color3.fromRGB(170, 120, 80),
}

-- A standing horse (about 6 studs tall) with saddle and blanket.
local function horse(parent, cf, coat)
	local m = model(parent, "Horse")
	local mane = Color3.fromRGB(40, 28, 20)
	local function at(offset)
		return cf * offset
	end
	ellipsoid(m, "Body", Vector3.new(2.4, 2.4, 5), at(CFrame.new(0, 4, 0)), coat)
	ellipsoid(m, "Chest", Vector3.new(2.2, 2.4, 2.2), at(CFrame.new(0, 4.1, -1.9)), coat)
	block(m, "Neck", Vector3.new(1.1, 2.8, 1.4), at(CFrame.new(0, 5.6, -2.7) * CFrame.Angles(-0.55, 0, 0)), coat)
	ellipsoid(m, "Head", Vector3.new(1.1, 1.2, 2.4), at(CFrame.new(0, 6.6, -3.9) * CFrame.Angles(0.5, 0, 0)), coat)
	ellipsoid(m, "Muzzle", Vector3.new(0.9, 0.8, 0.9), at(CFrame.new(0, 6.0, -4.8)), coat:Lerp(Color3.new(0, 0, 0), 0.25))
	for _, side in ipairs({ -1, 1 }) do
		small(block(m, "Ear", Vector3.new(0.2, 0.5, 0.2), at(CFrame.new(side * 0.3, 7.5, -3.4)), coat))
		small(ellipsoid(m, "Eye", Vector3.new(0.15, 0.2, 0.2), at(CFrame.new(side * 0.52, 6.9, -4.1)), Color3.new(0.05, 0.05, 0.05)))
	end
	small(block(m, "Mane", Vector3.new(0.3, 2.8, 0.5), at(CFrame.new(0, 6.0, -2.4) * CFrame.Angles(-0.55, 0, 0)), mane))
	ellipsoid(m, "Tail", Vector3.new(0.5, 2.6, 0.6), at(CFrame.new(0, 3.6, 2.7) * CFrame.Angles(0.35, 0, 0)), mane)
	for _, x in ipairs({ -0.7, 0.7 }) do
		for _, z in ipairs({ -1.8, 1.8 }) do
			local leg = block(m, "Leg", Vector3.new(0.5, 3.2, 0.55), at(CFrame.new(x, 1.6, z)), coat)
			small(block(m, "Hoof", Vector3.new(0.6, 0.35, 0.65), at(CFrame.new(x, 0.18, z)), Color3.fromRGB(30, 25, 20)))
			leg.CastShadow = true
		end
	end
	block(m, "Saddle", Vector3.new(1.6, 0.4, 1.8), at(CFrame.new(0, 5.3, -0.3)), Color3.fromRGB(90, 50, 25), Enum.Material.Leather)
	block(m, "Blanket", Vector3.new(2.6, 0.15, 2.2), at(CFrame.new(0, 5.15, -0.3)), Color3.fromRGB(170, 40, 40), Enum.Material.Fabric)
	return m
end

local function hayBale(parent, x, z, yaw)
	local p = block(parent, "HayBale", Vector3.new(3, 2.4, 2.4), CFrame.new(x, 1.2, z) * CFrame.Angles(0, yaw or 0, 0), Color3.fromRGB(214, 180, 90), Enum.Material.Grass, { Shape = Enum.PartType.Cylinder })
	return p
end

local function stables(parent, x, z, yaw)
	local m = model(parent, "Stables")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local function at(offset)
		return base * offset
	end
	block(m, "Floor", Vector3.new(30, 0.4, 12), at(CFrame.new(0, 0.2, 0)), C.WoodLight, Enum.Material.WoodPlanks)
	block(m, "BackWall", Vector3.new(30, 9, 0.6), at(CFrame.new(0, 4.5, 6)), C.Wood, Enum.Material.WoodPlanks)
	block(m, "Roof", Vector3.new(32, 0.6, 14), at(CFrame.new(0, 9.4, 0) * CFrame.Angles(0.18, 0, 0)), C.Roof, Enum.Material.WoodPlanks)
	for i = 0, 4 do
		local px = -15 + i * 7.5
		block(m, "Post", Vector3.new(0.6, 9, 0.6), at(CFrame.new(px, 4.5, -6)), C.WoodDark, Enum.Material.Wood)
		block(m, "Divider", Vector3.new(0.4, 4, 10), at(CFrame.new(px, 2.2, 0.5)), C.Wood, Enum.Material.WoodPlanks)
	end
	local sign1 = block(m, "Sign", Vector3.new(10, 2, 0.3), at(CFrame.new(0, 10.4, -6.4)), C.WoodDark, Enum.Material.Wood)
	sign(sign1, Enum.NormalId.Front, "RACE STABLES", Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	for i = 0, 3 do
		horse(m, at(CFrame.new(-11.25 + i * 7.5, 0.4, 0.5) * CFrame.Angles(0, math.pi, 0)), HORSE_COATS[i % #HORSE_COATS + 1])
	end
	local hay = at(CFrame.new(18, 0, -2))
	hayBale(m, hay.X, hay.Z, 0.3)
	return m
end

-- Rope between two points with small hanging pieces (pennants or light bulbs).
local function hangingLine(parent, a, b, count, kind)
	local m = model(parent, kind == "lights" and "StringLights" or "Pennants")
	local sag = (b - a).Magnitude * 0.06
	local function pointAt(t)
		return a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * sag, 0)
	end
	local anchorA = small(block(m, "RopeA", Vector3.new(0.2, 0.2, 0.2), CFrame.new(a), Color3.new(0, 0, 0), nil, { Transparency = 1, CanCollide = false }))
	local anchorB = small(block(m, "RopeB", Vector3.new(0.2, 0.2, 0.2), CFrame.new(b), Color3.new(0, 0, 0), nil, { Transparency = 1, CanCollide = false }))
	-- block() already offsets by origin; the attachments sit at the parts' centres.
	local a0 = Instance.new("Attachment")
	a0.Parent = anchorA
	local a1 = Instance.new("Attachment")
	a1.Parent = anchorB
	local rope = Instance.new("Beam")
	rope.Attachment0 = a0
	rope.Attachment1 = a1
	rope.Width0 = 0.08
	rope.Width1 = 0.08
	rope.Color = ColorSequence.new(Color3.fromRGB(50, 40, 30))
	rope.CurveSize0 = -sag * 1.3
	rope.CurveSize1 = sag * 1.3
	rope.Parent = anchorA
	for i = 1, count do
		local t = i / (count + 1)
		local p = pointAt(t)
		if kind == "lights" then
			local bulb = small(block(m, "Bulb", Vector3.new(0.45, 0.6, 0.45), CFrame.new(p - Vector3.new(0, 0.35, 0)), Color3.fromRGB(255, 215, 140), Enum.Material.Neon, { Shape = Enum.PartType.Ball, CanCollide = false }))
			if i % 3 == 0 then
				local light = Instance.new("PointLight")
				light.Range = 10
				light.Brightness = 0.6
				light.Color = Color3.fromRGB(255, 200, 130)
				light.Parent = bulb
			end
		else
			local palette = FLAG_PALETTES[(i % #FLAG_PALETTES) + 1]
			local dir = (b - a).Unit
			small(block(m, "Pennant", Vector3.new(0.05, 1.2, 1.2), CFrame.lookAt(p, p + dir) * CFrame.new(0, -0.6, 0) * CFrame.Angles(math.pi / 4, 0, 0), palette[1], Enum.Material.Fabric, { CanCollide = false }))
		end
	end
	return m
end

local function palm(parent, x, z)
	local m = model(parent, "PalmTree")
	local lean = rng:NextNumber(-0.25, 0.25)
	local y, px = 0, x
	local segments = 6
	for i = 1, segments do
		local h = 2.6
		cylinder(m, "Trunk", h, 1.3 - i * 0.08, CFrame.new(px, y + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2 + lean), Color3.fromRGB(130, 100, 70), Enum.Material.Wood)
		y = y + h * 0.97
		px = px - math.sin(lean) * h
	end
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		local leaf = small(block(m, "Leaf", Vector3.new(1.2, 0.15, 7), CFrame.new(px, y + 0.4, z) * CFrame.Angles(0, angle, 0) * CFrame.Angles(0.45, 0, 0) * CFrame.new(0, 0, -3.3), Color3.fromRGB(70, 130, 50), Enum.Material.Grass))
		leaf.CastShadow = true
	end
	for i = 1, 3 do
		small(block(m, "Coconut", Vector3.new(0.8, 0.8, 0.8), CFrame.new(px + math.cos(i * 2) * 0.6, y - 0.3, z + math.sin(i * 2) * 0.6), Color3.fromRGB(90, 60, 30), Enum.Material.Wood, { Shape = Enum.PartType.Ball }))
	end
end

local function deadTree(parent, x, z)
	local m = model(parent, "DeadTree")
	local h = rng:NextNumber(6, 11)
	local bark = Color3.fromRGB(95, 75, 60)
	cylinder(m, "Trunk", h, 0.9, upright(x, h / 2, z), bark, Enum.Material.Wood)
	for i = 1, 4 do
		local y = h * rng:NextNumber(0.45, 0.95)
		local yaw = rng:NextNumber(0, math.pi * 2)
		local len = rng:NextNumber(2.5, 4.5)
		small(block(m, "Branch", Vector3.new(0.35, 0.35, len), CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0.7, 0, 0) * CFrame.new(0, 0, -len / 2), bark, Enum.Material.Wood))
	end
end

local function skull(parent, x, z)
	local m = model(parent, "CattleSkull")
	local bone = Color3.fromRGB(235, 228, 210)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local base = CFrame.new(x, 0.4, z) * CFrame.Angles(0, yaw, 0)
	small(block(m, "Skull", Vector3.new(1, 0.7, 1.6), base, bone))
	small(block(m, "HornL", Vector3.new(1.6, 0.25, 0.25), base * CFrame.new(-1, 0.2, -0.3) * CFrame.Angles(0, 0, 0.4), bone))
	small(block(m, "HornR", Vector3.new(1.6, 0.25, 0.25), base * CFrame.new(1, 0.2, -0.3) * CFrame.Angles(0, 0, -0.4), bone))
end

local function waterTower(parent, x, z)
	local m = model(parent, "WaterTower")
	for _, dx in ipairs({ -3, 3 }) do
		for _, dz in ipairs({ -3, 3 }) do
			block(m, "Leg", Vector3.new(0.8, 18, 0.8), CFrame.new(x + dx, 9, z + dz) * CFrame.Angles(dz * 0.015, 0, -dx * 0.015), C.WoodDark, Enum.Material.Wood)
		end
	end
	block(m, "Brace", Vector3.new(8.5, 0.4, 0.4), CFrame.new(x, 8, z - 3), C.WoodDark, Enum.Material.Wood)
	block(m, "Brace", Vector3.new(8.5, 0.4, 0.4), CFrame.new(x, 8, z + 3), C.WoodDark, Enum.Material.Wood)
	cylinder(m, "Tank", 9, 10, upright(x, 22.5, z), C.Wood, Enum.Material.WoodPlanks)
	for _, y in ipairs({ 19.5, 25.5 }) do
		cylinder(m, "Band", 0.4, 10.2, upright(x, y, z), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
	end
	block(m, "Roof", Vector3.new(11, 4, 11), CFrame.new(x, 28.5, z), C.Roof, Enum.Material.WoodPlanks, { Shape = Enum.PartType.Ball })
	small(block(m, "Spout", Vector3.new(0.6, 0.6, 5), CFrame.new(x, 18.5, z - 6) * CFrame.Angles(0.4, 0, 0), Color3.fromRGB(60, 60, 65), Enum.Material.Metal))
end

-- Windmill: the rotor hub is tagged "SpinWindmill"; clients spin it.
local function windmill(parent, x, z)
	local m = model(parent, "Windmill")
	local h = 24
	for _, d in ipairs({ { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } }) do
		block(m, "Leg", Vector3.new(0.5, h, 0.5), CFrame.new(x + d[1] * 0.75, h / 2, z + d[2] * 0.75) * CFrame.Angles(d[2] * 0.06, 0, -d[1] * 0.06), Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
	end
	for y = 4, h - 2, 5 do
		block(m, "Rung", Vector3.new(3.4 - y * 0.06, 0.3, 0.3), CFrame.new(x, y, z - 1.6 + y * 0.03), Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
	end
	local hub = block(m, "Hub", Vector3.new(1.4, 1.4, 1.4), CFrame.new(x, h + 1, z - 1.5), Color3.fromRGB(70, 70, 75), Enum.Material.Metal, { Shape = Enum.PartType.Ball })
	CollectionService:AddTag(hub, "SpinWindmill")
	for i = 1, 12 do
		local blade = block(m, "Blade", Vector3.new(0.9, 4.5, 0.1), CFrame.new(), Color3.fromRGB(200, 195, 185), Enum.Material.Metal)
		-- hub.CFrame is already in world space, so set the blade directly.
		blade.CFrame = hub.CFrame * CFrame.Angles(0, 0, i / 12 * math.pi * 2) * CFrame.new(0, 3, -0.3) * CFrame.Angles(0, 0.35, 0)
		blade.Anchored = false
		blade.CastShadow = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = hub
		w.Part1 = blade
		w.Parent = blade
	end
	local vane = block(m, "Vane", Vector3.new(0.1, 3, 5), CFrame.new(x, h + 1, z + 2), Color3.fromRGB(200, 60, 50), Enum.Material.Metal)
	vane.CastShadow = false
end

local function telegraphLine(parent, points)
	local m = model(parent, "TelegraphLine")
	local tops = {}
	for i, p in ipairs(points) do
		cylinder(m, "Pole", 16, 0.6, upright(p.X, 8, p.Z), C.WoodDark, Enum.Material.Wood)
		local bar = block(m, "Crossbar", Vector3.new(4, 0.4, 0.4), CFrame.new(p.X, 15, p.Z), C.WoodDark, Enum.Material.Wood)
		tops[i] = bar
	end
	for i = 1, #tops - 1 do
		for _, side in ipairs({ -1.6, 1.6 }) do
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(side, 0.3, 0)
			a0.Parent = tops[i]
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(side, 0.3, 0)
			a1.Parent = tops[i + 1]
			local wire = Instance.new("Beam")
			wire.Attachment0 = a0
			wire.Attachment1 = a1
			wire.Width0 = 0.06
			wire.Width1 = 0.06
			wire.Color = ColorSequence.new(Color3.fromRGB(30, 30, 30))
			wire.CurveSize0 = -1.5
			wire.CurveSize1 = 1.5
			wire.Parent = tops[i]
		end
	end
end

local function railway(parent, x, z0, z1)
	local m = model(parent, "Railway")
	local length = z1 - z0
	for _, dx in ipairs({ -2.4, 2.4 }) do
		local segments = math.ceil(length / 200)
		for i = 0, segments - 1 do
			local a = z0 + i * 200
			local b = math.min(z1, a + 200)
			block(m, "Rail", Vector3.new(0.3, 0.4, b - a), CFrame.new(x + dx, 0.6, (a + b) / 2), Color3.fromRGB(80, 75, 70), Enum.Material.Metal)
		end
	end
	for z = z0, z1, 4 do
		small(block(m, "Sleeper", Vector3.new(7, 0.35, 1), CFrame.new(x, 0.25, z), Color3.fromRGB(85, 60, 40), Enum.Material.Wood))
	end
end

local function locomotive(parent, x, z)
	local m = model(parent, "SteamTrain")
	local black = Color3.fromRGB(30, 30, 34)
	local red = Color3.fromRGB(150, 30, 30)
	local function at(dz, y)
		return CFrame.new(x, y, z + dz)
	end
	block(m, "Frame", Vector3.new(6, 1, 26), at(0, 2.2), black, Enum.Material.Metal)
	block(m, "Boiler", Vector3.new(16, 5, 5), at(-4, 5.2) * CFrame.Angles(0, math.pi / 2, 0), black, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	block(m, "SmokeBox", Vector3.new(1, 5.4, 5.4), at(-12.2, 5.2) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(50, 50, 55), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	local stack = cylinder(m, "Smokestack", 4, 1.8, CFrame.new(x, 9.4, z - 10.5) * CFrame.Angles(0, 0, math.pi / 2), black, Enum.Material.Metal)
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(200, 200, 200)
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 6
	smoke.Size = 3
	smoke.Parent = stack
	block(m, "Dome", Vector3.new(2, 2, 2), at(-4, 8), Color3.fromRGB(190, 150, 60), Enum.Material.Metal, { Shape = Enum.PartType.Ball })
	block(m, "Cab", Vector3.new(6, 6, 6), at(7, 6), red, Enum.Material.WoodPlanks)
	block(m, "CabRoof", Vector3.new(7, 0.5, 7), at(7, 9.2), black, Enum.Material.Metal)
	windowRow(m, at(7, 6.5) * CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, -3.05), 1, 0, Vector3.new(2.5, 2, 0.2))
	block(m, "Cowcatcher", Vector3.new(5.5, 2, 3), at(-14, 1.6) * CFrame.Angles(0.5, 0, 0), red, Enum.Material.Metal)
	local lamp = small(block(m, "Headlamp", Vector3.new(1.2, 1.2, 1), at(-12.9, 7), Color3.fromRGB(255, 240, 190), Enum.Material.Neon))
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Range = 40
	light.Brightness = 2
	light.Parent = lamp
	for _, dz in ipairs({ -9, -5, -1, 3 }) do
		for _, dx in ipairs({ -3.1, 3.1 }) do
			local d = dz > -6 and 4 or 2.6
			block(m, "Wheel", Vector3.new(0.5, d, d), at(dz, d / 2 + 0.6) * CFrame.new(dx, 0, 0), red, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
		end
	end
	-- Two passenger coaches.
	for i = 1, 2 do
		local cz = 13 + i * 18
		block(m, "Coach", Vector3.new(6, 6, 16), at(cz, 5), Color3.fromRGB(110, 60, 40), Enum.Material.WoodPlanks)
		block(m, "CoachRoof", Vector3.new(6.6, 0.8, 16.6), at(cz, 8.4), Color3.fromRGB(60, 55, 50), Enum.Material.Metal)
		windowRow(m, at(cz, 5.8) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, -3.05), 5, 3, Vector3.new(1.8, 1.8, 0.2))
		windowRow(m, at(cz, 5.8) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(0, 0, -3.05), 5, 3, Vector3.new(1.8, 1.8, 0.2))
		for _, wz in ipairs({ -5, 5 }) do
			for _, dx in ipairs({ -3.1, 3.1 }) do
				block(m, "Wheel", Vector3.new(0.5, 2.4, 2.4), at(cz + wz, 1.8) * CFrame.new(dx, 0, 0), black, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
			end
		end
	end
end

local function station(parent, x, z)
	local m = model(parent, "TrainStation")
	block(m, "Platform", Vector3.new(10, 1.6, 60), CFrame.new(x, 0.8, z), Color3.fromRGB(150, 130, 105), Enum.Material.WoodPlanks)
	block(m, "Building", Vector3.new(14, 11, 24), CFrame.new(x - 12, 5.5, z), Color3.fromRGB(170, 120, 80), Enum.Material.WoodPlanks)
	block(m, "Roof", Vector3.new(16, 1, 26), CFrame.new(x - 12, 11.5, z) * CFrame.Angles(0, 0, 0.12), C.Roof, Enum.Material.WoodPlanks)
	local board = block(m, "StationSign", Vector3.new(0.4, 3, 16), CFrame.new(x - 4.8, 8.5, z), C.WoodDark, Enum.Material.Wood)
	sign(board, Enum.NormalId.Right, "DESERT JUNCTION", Color3.fromRGB(245, 225, 175), nil, Enum.Font.Fondamento)
	windowRow(m, CFrame.new(x - 4.95, 4.5, z) * CFrame.Angles(0, math.pi / 2, 0), 4, 5, Vector3.new(2.2, 3.2, 0.2))
	block(m, "Canopy", Vector3.new(10, 0.5, 50), CFrame.new(x, 10, z) * CFrame.Angles(0, 0, -0.08), Color3.fromRGB(120, 40, 40), Enum.Material.WoodPlanks)
	for dz = -22, 22, 11 do
		block(m, "CanopyPost", Vector3.new(0.5, 8.6, 0.5), CFrame.new(x + 4, 5.9, z + dz), C.WoodDark, Enum.Material.Wood)
		small(block(m, "Bench", Vector3.new(1.4, 0.4, 5), CFrame.new(x - 3, 2.4, z + dz + 5), C.WoodLight, Enum.Material.WoodPlanks))
	end
	small(block(m, "Clock", Vector3.new(0.3, 2.4, 2.4), CFrame.new(x - 4.7, 12.5, z), Color3.fromRGB(240, 235, 220), nil, { Shape = Enum.PartType.Cylinder }))
end

local function mine(parent, center)
	local m = model(parent, "OldMine")
	local dir = Vector3.new(-center.X, 0, -center.Z).Unit
	local entrance = center + dir * 58
	-- Faces back into the hill: the tunnel opening is on the local +Z side.
	local base = CFrame.lookAt(Vector3.new(entrance.X, 0, entrance.Z), Vector3.new(entrance.X, 0, entrance.Z) + dir)
	local function at(offset)
		return base * offset
	end
	block(m, "TunnelDark", Vector3.new(10, 10, 6), at(CFrame.new(0, 5, 3)), Color3.fromRGB(10, 8, 6), Enum.Material.SmoothPlastic)
	for _, x in ipairs({ -5.5, 5.5 }) do
		block(m, "Timber", Vector3.new(1.2, 12, 1.2), at(CFrame.new(x, 6, 0)), C.WoodDark, Enum.Material.Wood)
	end
	block(m, "Lintel", Vector3.new(13, 1.4, 1.4), at(CFrame.new(0, 12, 0)), C.WoodDark, Enum.Material.Wood)
	local board = block(m, "MineSign", Vector3.new(8, 2, 0.3), at(CFrame.new(0, 14, -0.4)), C.Wood, Enum.Material.Wood)
	sign(board, Enum.NormalId.Front, "SILVER MINE · KEEP OUT", Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	for _, x in ipairs({ -1.6, 1.6 }) do
		block(m, "MineRail", Vector3.new(0.3, 0.3, 26), at(CFrame.new(x, 0.4, -10)), Color3.fromRGB(80, 75, 70), Enum.Material.Metal)
	end
	for zz = 0, 22, 3 do
		small(block(m, "Sleeper", Vector3.new(4.6, 0.3, 0.8), at(CFrame.new(0, 0.2, -zz)), Color3.fromRGB(85, 60, 40), Enum.Material.Wood))
	end
	block(m, "OreCart", Vector3.new(3.6, 2.4, 4.4), at(CFrame.new(0, 2.1, -9)), Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
	for i = 1, 5 do
		small(block(m, "Ore", Vector3.new(1.1, 1.1, 1.1), at(CFrame.new(rng:NextNumber(-1, 1), 3.4, -9 + rng:NextNumber(-1.4, 1.4))), Color3.fromRGB(160, 165, 175), Enum.Material.Slate, { Shape = Enum.PartType.Ball }))
	end
	for _, x in ipairs({ -5.5, 5.5 }) do
		local lantern = small(block(m, "Lantern", Vector3.new(0.7, 1, 0.7), at(CFrame.new(x, 9, -0.9)), Color3.fromRGB(255, 190, 100), Enum.Material.Neon))
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 180, 90)
		light.Range = 14
		light.Brightness = 1.2
		light.Parent = lantern
	end
end

local function rockArch(parent, x, z)
	local m = model(parent, "RockArch")
	local stone = Color3.fromRGB(190, 120, 80)
	block(m, "PillarL", Vector3.new(8, 26, 9), CFrame.new(x - 14, 13, z) * CFrame.Angles(0, 0, 0.08), stone, Enum.Material.Sandstone)
	block(m, "PillarR", Vector3.new(8, 24, 9), CFrame.new(x + 14, 12, z) * CFrame.Angles(0, 0, -0.08), stone, Enum.Material.Sandstone)
	block(m, "Span", Vector3.new(38, 7, 8), CFrame.new(x, 27, z) * CFrame.Angles(0, 0, 0.03), stone, Enum.Material.Sandstone)
end

local function well(parent, x, z)
	local m = model(parent, "Well")
	cylinder(m, "WellRing", 3, 5, upright(x, 1.5, z), Color3.fromRGB(150, 140, 125), Enum.Material.Cobblestone)
	cylinder(m, "WellWater", 0.2, 4.2, upright(x, 2.5, z), Color3.fromRGB(60, 100, 120), Enum.Material.Glass)
	for _, dx in ipairs({ -2.2, 2.2 }) do
		block(m, "Post", Vector3.new(0.5, 6, 0.5), CFrame.new(x + dx, 4, z), C.WoodDark, Enum.Material.Wood)
	end
	block(m, "Roof", Vector3.new(6, 0.5, 4), CFrame.new(x, 7.2, z), C.Roof, Enum.Material.WoodPlanks)
	small(block(m, "Bucket", Vector3.new(0.9, 0.9, 0.9), CFrame.new(x, 4.5, z), C.Wood, Enum.Material.Wood))
end

local function wantedBoard(parent, x, z, yaw)
	local m = model(parent, "WantedBoard")
	local board = block(m, "Board", Vector3.new(6, 4, 0.3), CFrame.new(x, 4, z) * CFrame.Angles(0, yaw, 0), C.Wood, Enum.Material.WoodPlanks)
	for _, dx in ipairs({ -2.6, 2.6 }) do
		block(m, "Leg", Vector3.new(0.4, 6, 0.4), CFrame.new(x, 3, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(dx, 0, 0.3), C.WoodDark, Enum.Material.Wood)
	end
	for i, text in ipairs({ "WANTED\nGYRO", "WANTED\nDIO", "REWARD\n$5000" }) do
		local poster = small(block(m, "Poster", Vector3.new(1.6, 2.2, 0.05), CFrame.new(x, 4.1, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(-2 + (i - 1) * 2, 0, -0.18), Color3.fromRGB(230, 210, 170), Enum.Material.Fabric))
		sign(poster, Enum.NormalId.Front, text, Color3.fromRGB(60, 30, 15), nil, Enum.Font.Fondamento)
	end
end

local function boardwalk(parent, x, z0, z1)
	block(parent, "Boardwalk", Vector3.new(5, 0.6, math.abs(z1 - z0)), CFrame.new(x, 0.3, (z0 + z1) / 2), C.WoodLight, Enum.Material.WoodPlanks)
end

local function scoreboard(parent, x, z, yaw)
	local m = model(parent, "Scoreboard")
	local board = block(m, "Board", Vector3.new(20, 10, 0.6), CFrame.new(x, 12, z) * CFrame.Angles(0, yaw, 0), Color3.fromRGB(30, 40, 30), Enum.Material.WoodPlanks)
	sign(board, Enum.NormalId.Front, "STAGE 1 — SAN DIEGO BEACH\n1. ???   2. ???   3. ???\n6,000 KM TO NEW YORK", Color3.fromRGB(240, 235, 200), nil, Enum.Font.Fondamento)
	for _, dx in ipairs({ -8, 8 }) do
		block(m, "Leg", Vector3.new(0.8, 12, 0.8), CFrame.new(x, 6, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(dx, 0, 0.6), C.WoodDark, Enum.Material.Wood)
	end
	block(m, "Trim", Vector3.new(21, 1, 1), CFrame.new(x, 17.4, z) * CFrame.Angles(0, yaw, 0), C.Gold, Enum.Material.Metal)
end

---------------------------------------------------------------------------
-- MAP UPGRADE: sections
---------------------------------------------------------------------------
local function buildLandforms()
	local terrain = workspace.Terrain
	local o = origin
	-- Rolling dunes in the open desert.
	for _ = 1, 45 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(230, 470)
		local p = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local inTown = p.X > 170 and p.X < 470 and p.Z > -340 and p.Z < 140
		if not inTown then
			local r = rng:NextNumber(18, 45)
			terrain:FillBall(o + p - Vector3.new(0, r * 0.78, 0), r, Enum.Material.Sand)
		end
	end
	-- Layered mesas (stratified sandstone and rock).
	local mesas = { Vector3.new(-380, 0, 60), Vector3.new(-300, 0, -250), Vector3.new(120, 0, -430), Vector3.new(-120, 0, 400), Vector3.new(330, 0, 380), Vector3.new(-430, 0, 300) }
	for i, p in ipairs(mesas) do
		local radius = 30 + (i % 3) * 10
		local height = 0
		local layers = { Enum.Material.Sandstone, Enum.Material.Rock, Enum.Material.Sandstone, Enum.Material.Slate }
		for l = 1, 4 do
			local h = rng:NextNumber(10, 16)
			local r = radius * (1 - (l - 1) * 0.12)
			terrain:FillCylinder(CFrame.new(o + p + Vector3.new(0, height + h / 2, 0)), h, r, layers[l])
			height = height + h
		end
	end
	-- Oasis: pond, grass ring, palms.
	local oasis = Vector3.new(-280, 0, 200)
	terrain:FillCylinder(CFrame.new(o + oasis + Vector3.new(0, -0.5, 0)), 2, 34, Enum.Material.Grass)
	terrain:FillCylinder(CFrame.new(o + oasis + Vector3.new(0, -2, 0)), 4, 20, Enum.Material.Water)
	-- Mine hill.
	terrain:FillBall(o + Vector3.new(-360, -30, -380), 70, Enum.Material.Rock)
	-- Roads (hard-packed ground).
	terrain:FillBlock(CFrame.new(o + Vector3.new(350, -0.6, 0)), Vector3.new(180, 1.2, 16), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(o + Vector3.new(-140, -0.6, 150)), Vector3.new(280, 1.2, 14), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(o + Vector3.new(-170, -0.6, -340)) * CFrame.Angles(0, 0.75, 0), Vector3.new(14, 1.2, 240), Enum.Material.Ground)
	return oasis
end

local function buildUpgrades()
	local f = folder("Upgrades")
	local oasis = buildLandforms()

	-- Race grounds: stables, horses, pennants, lights, scoreboard, hay.
	stables(f, -80, 125, -math.pi / 2)
	for i = 0, 3 do
		horse(f, CFrame.new(26 + (i % 2) * 4, 0, 130 - i * 6) * CFrame.Angles(0, math.pi / 2 + rng:NextNumber(-0.3, 0.3), 0), HORSE_COATS[(i + 2) % #HORSE_COATS + 1])
	end
	for i = 0, 10 do
		local z = 120 - i * 32
		hangingLine(f, Vector3.new(-22, 14.5, z), Vector3.new(-22, 14.5, z - 32), 7, "pennants")
		hangingLine(f, Vector3.new(22, 13.5, z - 16), Vector3.new(22, 13.5, z - 48), 8, "lights")
	end
	hangingLine(f, Vector3.new(-16, 21, 110), Vector3.new(16, 21, 110), 10, "lights")
	scoreboard(f, 44, 118, -math.pi / 2)
	for i = 1, 10 do
		hayBale(f, rng:NextNumber(-18, -12) * (i % 2 == 0 and 1 or -1), 100 - i * 30, rng:NextNumber(0, 3))
	end

	-- Town extras: boardwalks, well, wanted board, water tower, windmill.
	boardwalk(f, 260 - 14.5, -110, 60)
	boardwalk(f, 260 + 14.5, -110, 60)
	well(f, 260, -70)
	wantedBoard(f, 248, 80, math.pi / 2)
	waterTower(f, 300, 70)
	windmill(f, 315, 115)

	-- Railway, station and steam train.
	railway(f, 440, -600, 600)
	station(f, 432, 0)
	locomotive(f, 440, -20)
	waterTower(f, 420, 50)

	-- Telegraph line: race start -> town -> station.
	local poles = {}
	for x = 30, 250, 40 do
		table.insert(poles, Vector3.new(x, 0, 92))
	end
	for x = 290, 410, 40 do
		table.insert(poles, Vector3.new(x, 0, -10))
	end
	telegraphLine(f, poles)

	-- Oasis palms, mine, rock arch, desert details.
	for i = 1, 9 do
		local angle = i / 9 * math.pi * 2
		palm(f, oasis.X + math.cos(angle) * rng:NextNumber(23, 30), oasis.Z + math.sin(angle) * rng:NextNumber(23, 30))
	end
	mine(f, Vector3.new(-360, 0, -380))
	rockArch(f, -150, -440)
	for _ = 1, 22 do
		local x, z = rng:NextNumber(-460, 460), rng:NextNumber(-460, 460)
		if math.abs(x) > 140 and not (x > 170 and x < 470) then
			if rng:NextNumber() < 0.5 then
				deadTree(f, x, z)
			else
				skull(f, x, z)
			end
		end
	end
	-- Wrecked wagon out in the desert.
	wagon(f, -200, -120, 0.7)
end

---------------------------------------------------------------------------
-- NEW PLACES: river + waterfall, covered bridge, railway trestle,
-- gold-panning camp, ghost town, horse ranch, Fort Dust, signposts
---------------------------------------------------------------------------
local RIVER_Z = 290
local function riverZ(x)
	return RIVER_Z + math.sin(x / 90) * 18
end

-- Clear dunes/rocks above ground level so a place sits on flat sand.
local function flatten(x, z, radius)
	local terrain = workspace.Terrain
	terrain:FillCylinder(CFrame.new(origin + Vector3.new(x, 20, z)), 40, radius, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(origin + Vector3.new(x, -0.5, z)), 1, radius, Enum.Material.Sand)
end

local function road(x, z, sizeX, sizeZ, yaw)
	workspace.Terrain:FillBlock(CFrame.new(origin + Vector3.new(x, -0.6, z)) * CFrame.Angles(0, yaw or 0, 0), Vector3.new(sizeX, 1.2, sizeZ), Enum.Material.Ground)
end

local function placeSign(parent, text, x, z, yaw)
	local m = model(parent, "PlaceSign")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw or 0, 0)
	for _, dx in ipairs({ -4.5, 4.5 }) do
		block(m, "Post", Vector3.new(0.7, 9, 0.7), base * CFrame.new(dx, 4.5, 0), C.WoodDark, Enum.Material.Wood)
	end
	local board = block(m, "Board", Vector3.new(11, 3.2, 0.4), base * CFrame.new(0, 7, 0), C.Wood, Enum.Material.WoodPlanks)
	sign(board, Enum.NormalId.Front, text, Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	sign(board, Enum.NormalId.Back, text, Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	return m
end

local function lanternPost(parent, x, z, y)
	y = y or 0
	block(parent, "LanternPost", Vector3.new(0.5, 7, 0.5), CFrame.new(x, y + 3.5, z), C.WoodDark, Enum.Material.Wood)
	local lantern = small(block(parent, "Lantern", Vector3.new(0.8, 1.1, 0.8), CFrame.new(x, y + 7.4, z), Color3.fromRGB(255, 190, 100), Enum.Material.Neon))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 90)
	light.Range = 16
	light.Brightness = 1
	light.Parent = lantern
end

local function barrel(parent, x, z, y)
	return cylinder(parent, "Barrel", 2.6, 2, upright(x, (y or 0) + 1.3, z), C.Wood, Enum.Material.Wood)
end

local function crate(parent, x, z, y, s)
	s = s or 2.4
	return block(parent, "Crate", Vector3.new(s, s, s), CFrame.new(x, (y or 0) + s / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), C.WoodLight, Enum.Material.WoodPlanks)
end

-- A black-and-white cow.
local function cow(parent, cf)
	local m = model(parent, "Cow")
	local white, black = Color3.fromRGB(235, 232, 225), Color3.fromRGB(35, 32, 30)
	local function at(o)
		return cf * o
	end
	ellipsoid(m, "Body", Vector3.new(2.8, 2.6, 5), at(CFrame.new(0, 3.4, 0)), white)
	for i = 1, 3 do
		small(ellipsoid(m, "Spot", Vector3.new(1.4, 1.2, 1.6), at(CFrame.new((i % 2 == 0 and 1 or -1) * 0.9, 3.7 + (i - 2) * 0.2, (i - 2) * 1.4)), black))
	end
	ellipsoid(m, "Head", Vector3.new(1.3, 1.4, 2), at(CFrame.new(0, 4.2, -3.1) * CFrame.Angles(0.3, 0, 0)), black)
	ellipsoid(m, "Muzzle", Vector3.new(1.1, 0.8, 0.8), at(CFrame.new(0, 3.7, -3.9)), Color3.fromRGB(220, 170, 160))
	for _, side in ipairs({ -1, 1 }) do
		small(block(m, "Horn", Vector3.new(0.6, 0.18, 0.18), at(CFrame.new(side * 0.8, 5, -2.9) * CFrame.Angles(0, 0, side * 0.4)), Color3.fromRGB(230, 220, 190)))
	end
	for _, x in ipairs({ -0.8, 0.8 }) do
		for _, z in ipairs({ -1.6, 1.6 }) do
			block(m, "Leg", Vector3.new(0.55, 2.2, 0.55), at(CFrame.new(x, 1.1, z)), white)
		end
	end
	small(block(m, "Tail", Vector3.new(0.2, 2, 0.2), at(CFrame.new(0, 3, 2.6) * CFrame.Angles(0.2, 0, 0)), black))
	return m
end

-- Round fence (corral).
local function corral(parent, cx, cz, radius, gapAngle)
	local posts = math.floor(radius * 2 * math.pi / 7)
	for i = 0, posts - 1 do
		local a0 = i / posts * math.pi * 2
		local a1 = (i + 1) / posts * math.pi * 2
		local skip = gapAngle and math.abs(((a0 - gapAngle + math.pi) % (2 * math.pi)) - math.pi) < 0.25
		local p0 = Vector3.new(cx + math.cos(a0) * radius, 0, cz + math.sin(a0) * radius)
		local p1 = Vector3.new(cx + math.cos(a1) * radius, 0, cz + math.sin(a1) * radius)
		block(parent, "CorralPost", Vector3.new(0.6, 4, 0.6), CFrame.new(p0.X, 2, p0.Z), C.WoodDark, Enum.Material.Wood)
		if not skip then
			local mid = (p0 + p1) / 2
			for _, y in ipairs({ 1.5, 3.1 }) do
				block(parent, "CorralRail", Vector3.new(0.3, 0.35, (p1 - p0).Magnitude + 0.4), CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(p1.X, y, p1.Z)), C.WoodLight, Enum.Material.Wood)
			end
		end
	end
end

local function buildRiver(f)
	local terrain = workspace.Terrain
	local o = origin
	-- Carve the riverbed, then fill it with water, from the mesa waterfall to the mountains.
	for x = -380, 560, 12 do
		local z = riverZ(x)
		terrain:FillBlock(CFrame.new(o + Vector3.new(x, 6, z)), Vector3.new(16, 26, 30), Enum.Material.Air)
		terrain:FillBlock(CFrame.new(o + Vector3.new(x, -9, z)), Vector3.new(16, 4, 30), Enum.Material.Mud)
		terrain:FillBlock(CFrame.new(o + Vector3.new(x, -5, z)), Vector3.new(16, 4, 26), Enum.Material.Water)
		-- Muddy banks with reeds of grass.
		for _, side in ipairs({ -1, 1 }) do
			terrain:FillBlock(CFrame.new(o + Vector3.new(x, -0.6, z + side * 17)), Vector3.new(14, 1.2, 4), Enum.Material.Mud)
			if rng:NextNumber() < 0.35 then
				terrain:FillCylinder(CFrame.new(o + Vector3.new(x + rng:NextNumber(-5, 5), -0.5, z + side * rng:NextNumber(19, 24))), 1, rng:NextNumber(3, 6), Enum.Material.Grass)
			end
		end
	end
	-- Waterfall pouring off the mesa into the river.
	local wz = riverZ(-380)
	-- Rock cliff on the mesa's edge for the water to pour down.
	terrain:FillBlock(CFrame.new(o + Vector3.new(-412, 23, wz)), Vector3.new(24, 48, 30), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(o + Vector3.new(-412, 47.5, wz)), Vector3.new(24, 1, 10), Enum.Material.Water)
	local fall = model(f, "Waterfall")
	block(fall, "Fall", Vector3.new(2, 50, 10), CFrame.new(-399, 23, wz), Color3.fromRGB(110, 175, 210), Enum.Material.Glass, { Transparency = 0.25, CanCollide = false })
	block(fall, "FallFoam", Vector3.new(1, 50, 6), CFrame.new(-397.6, 23, wz), Color3.fromRGB(230, 245, 255), Enum.Material.SmoothPlastic, { Transparency = 0.45, CanCollide = false })
	local pool = block(fall, "Mist", Vector3.new(10, 3, 18), CFrame.new(-388, -2, wz), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false })
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	mist.Lifetime = NumberRange.new(1.5, 2.5)
	mist.Speed = NumberRange.new(2, 5)
	mist.Rate = 12
	mist.Parent = pool
	terrain:FillBall(o + Vector3.new(-388, -6, wz), 12, Enum.Material.Water)
	placeSign(f, "RATTLESNAKE RIVER", -350, wz - 26, 0)
end

local function coveredBridge(f, x)
	local m = model(f, "CoveredBridge")
	local z = riverZ(x)
	local length, width = 48, 12
	local red = Color3.fromRGB(150, 50, 40)
	block(m, "Deck", Vector3.new(width, 1, length), CFrame.new(x, 0.9, z), C.WoodLight, Enum.Material.WoodPlanks)
	for _, side in ipairs({ -1, 1 }) do
		-- Side walls with a window strip.
		block(m, "WallLow", Vector3.new(0.6, 3.5, length), CFrame.new(x + side * width / 2, 3.15, z), red, Enum.Material.WoodPlanks)
		block(m, "WallHigh", Vector3.new(0.6, 2.5, length), CFrame.new(x + side * width / 2, 8.3, z), red, Enum.Material.WoodPlanks)
		for zz = -length / 2, length / 2, 6 do
			block(m, "WallPost", Vector3.new(0.7, 9.6, 0.7), CFrame.new(x + side * width / 2, 5.6, z + zz), C.WoodDark, Enum.Material.Wood)
		end
		-- Gable roof.
		block(m, "Roof", Vector3.new(width * 0.62, 0.6, length + 2), CFrame.new(x + side * width * 0.26, 11.6, z) * CFrame.Angles(0, 0, side * -0.5), C.Roof, Enum.Material.WoodPlanks)
		-- Stone piers in the river.
		block(m, "Pier", Vector3.new(4, 10, 4), CFrame.new(x + side * 4, -4.5, z), Color3.fromRGB(140, 130, 120), Enum.Material.Cobblestone)
	end
	for _, end_ in ipairs({ -1, 1 }) do
		local gable = block(m, "Gable", Vector3.new(width, 2.4, 0.5), CFrame.new(x, 10.8, z + end_ * length / 2), red, Enum.Material.WoodPlanks)
		if end_ == -1 then
			sign(gable, Enum.NormalId.Front, "RIVER CROSSING", Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
		end
		-- Ramps down to the road.
		block(m, "Ramp", Vector3.new(width, 0.8, 8), CFrame.new(x, 0.45, z + end_ * (length / 2 + 3.6)) * CFrame.Angles(end_ * 0.12, 0, 0), C.WoodLight, Enum.Material.WoodPlanks)
	end
	lanternPost(m, x - width / 2 - 1.5, z - length / 2 - 2)
	lanternPost(m, x + width / 2 + 1.5, z + length / 2 + 2)
end

local function railwayTrestle(f, x)
	local m = model(f, "RailwayTrestle")
	local z = riverZ(x)
	block(m, "TrestleDeck", Vector3.new(8, 0.6, 36), CFrame.new(x, -0.3, z), C.WoodDark, Enum.Material.WoodPlanks)
	for zz = -15, 15, 6 do
		for _, dx in ipairs({ -3, 3 }) do
			block(m, "TrestleLeg", Vector3.new(0.8, 10, 0.8), CFrame.new(x + dx, -5, z + zz) * CFrame.Angles(0, 0, dx > 0 and -0.12 or 0.12), C.WoodDark, Enum.Material.Wood)
		end
		block(m, "Brace", Vector3.new(0.4, 0.4, 8.6), CFrame.new(x, -4.5, z + zz) * CFrame.Angles(0, math.pi / 2, 0.8), C.Wood, Enum.Material.Wood)
		block(m, "Brace", Vector3.new(0.4, 0.4, 8.6), CFrame.new(x, -4.5, z + zz) * CFrame.Angles(0, math.pi / 2, -0.8), C.Wood, Enum.Material.Wood)
	end
end

local function goldCamp(f, x)
	local m = model(f, "GoldPanningCamp")
	local z = riverZ(x) - 26 -- south bank
	tent(m, x - 12, z - 8, 0.3, 0.9)
	tent(m, x + 10, z - 10, -0.4, 1)
	-- Sluice box running down into the river.
	block(m, "Sluice", Vector3.new(2.4, 1, 18), CFrame.new(x, 1.6, z + 10) * CFrame.Angles(-0.14, 0, 0), C.Wood, Enum.Material.WoodPlanks)
	for _, dx in ipairs({ -1.3, 1.3 }) do
		block(m, "SluiceSide", Vector3.new(0.3, 1.4, 18), CFrame.new(x + dx, 2.1, z + 10) * CFrame.Angles(-0.14, 0, 0), C.WoodDark, Enum.Material.Wood)
	end
	block(m, "SluiceWater", Vector3.new(2, 0.2, 17), CFrame.new(x, 2.15, z + 10) * CFrame.Angles(-0.14, 0, 0), Color3.fromRGB(100, 160, 190), Enum.Material.Glass, { Transparency = 0.3, CanCollide = false })
	for i = 1, 3 do
		small(cylinder(m, "GoldPan", 0.25, 2, CFrame.new(x - 5 + i * 2.2, 0.2, z + 4) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(120, 110, 100), Enum.Material.Metal))
	end
	for i = 1, 6 do
		small(block(m, "Nugget", Vector3.new(0.5, 0.4, 0.5), CFrame.new(x - 6 + rng:NextNumber(0, 6), 0.3, z + 3.5 + rng:NextNumber(-0.5, 0.5)), C.Gold, Enum.Material.Metal, { Shape = Enum.PartType.Ball }))
	end
	block(m, "Campfire", Vector3.new(2.4, 0.4, 2.4), CFrame.new(x - 1, 0.2, z - 14), Color3.fromRGB(60, 40, 30), Enum.Material.Slate)
	local fire = small(block(m, "Fire", Vector3.new(1, 1, 1), CFrame.new(x - 1, 0.9, z - 14), Color3.fromRGB(255, 140, 40), Enum.Material.Neon, { Transparency = 0.3, CanCollide = false }))
	local flame = Instance.new("Fire")
	flame.Size = 4
	flame.Heat = 6
	flame.Parent = fire
	barrel(m, x + 4, z - 16)
	crate(m, x + 6.5, z - 15)
	placeSign(m, "GOLD CLAIM · NO JUMPERS", x - 22, z, math.pi / 2)
end

-- A ruined, weathered building for the ghost town.
local function ruin(parent, name, cf, width, depth, height, lean)
	local m = model(parent, name:gsub(" ", ""))
	local grey = Color3.fromRGB(128 + rng:NextInteger(-12, 12), 116, 100)
	local function at(o)
		return cf * o
	end
	-- Walls (one missing side wall, broken back wall).
	block(m, "BackWall", Vector3.new(width, height * 0.7, 1), at(CFrame.new(0, height * 0.35, depth)), grey, Enum.Material.WoodPlanks)
	block(m, "SideWall", Vector3.new(1, height, depth), at(CFrame.new(-width / 2, height / 2, depth / 2)), grey, Enum.Material.WoodPlanks)
	block(m, "SideWallStub", Vector3.new(1, height * 0.4, depth * 0.5), at(CFrame.new(width / 2, height * 0.2, depth * 0.75)), grey, Enum.Material.WoodPlanks)
	-- Leaning false front with a faded sign.
	local front = block(m, "FalseFront", Vector3.new(width + 1, height + 5, 1), at(CFrame.new(0, (height + 5) / 2, -0.5) * CFrame.Angles(lean or 0.06, 0, (lean or 0.06) * 0.5)), grey, Enum.Material.WoodPlanks)
	local board = block(m, "SignBoard", Vector3.new(width - 2, 3, 0.3), at(CFrame.new(0.4, height + 1.8, -1.2) * CFrame.Angles(lean or 0.06, 0, 0.12)), Color3.fromRGB(90, 76, 62), Enum.Material.Wood)
	sign(board, Enum.NormalId.Front, name, Color3.fromRGB(200, 185, 160), nil, Enum.Font.Fondamento)
	-- Boarded-up door and windows.
	block(m, "Doorway", Vector3.new(3.2, 6.5, 0.3), at(CFrame.new(0, 3.25, -1.1)), Color3.fromRGB(20, 16, 14), Enum.Material.SmoothPlastic)
	for i = -1, 1 do
		block(m, "Board", Vector3.new(4, 0.5, 0.2), at(CFrame.new(0, 3 + i * 1.6, -1.3) * CFrame.Angles(0, 0, i * 0.2)), Color3.fromRGB(110, 92, 70), Enum.Material.Wood)
	end
	-- Collapsed roof: a few planks resting at angles, the rest on the floor.
	for i = 1, 4 do
		block(m, "RoofPlank", Vector3.new(width * 0.5, 0.4, 2), at(CFrame.new(rng:NextNumber(-width / 4, width / 4), height - i * 0.8, depth * i / 5) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.6, 0.6))), C.WoodDark, Enum.Material.WoodPlanks)
	end
	for _ = 1, 3 do
		block(m, "Rubble", Vector3.new(rng:NextNumber(1, 3), 0.5, rng:NextNumber(2, 5)), at(CFrame.new(rng:NextNumber(-width / 3, width / 3), 0.25, depth * rng:NextNumber(0.2, 0.8)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0)), grey, Enum.Material.WoodPlanks)
	end
	return m
end

local function ghostTown(f, cx, cz)
	local m = model(f, "GhostTown")
	local names = { "SALOON", "ASSAY OFFICE", "DRY GOODS", "UNDERTAKER", "HOTEL" }
	for i, name in ipairs(names) do
		local side = (i % 2 == 1) and -1 or 1
		local z = cz + 40 - (i - 1) * 20
		local cf = CFrame.new(cx + side * 20, 0, z) * CFrame.Angles(0, side * math.pi / 2, 0)
		ruin(m, name, cf, 16, 18, 13, rng:NextNumber(0.03, 0.12) * (i % 2 == 0 and -1 or 1))
	end
	-- Broken water tower lying on its side.
	cylinder(m, "FallenTank", 10, 8, CFrame.new(cx + 6, 3.5, cz - 52) * CFrame.Angles(0, 0.6, 0.15), C.WoodDark, Enum.Material.WoodPlanks)
	-- Graveyard with crosses.
	local gx, gz = cx - 52, cz - 30
	for i = 0, 8 do
		local x = gx + (i % 3) * 6 + rng:NextNumber(-1, 1)
		local z = gz + math.floor(i / 3) * 7
		local tilt = rng:NextNumber(-0.25, 0.25)
		block(m, "CrossPost", Vector3.new(0.5, 4, 0.5), CFrame.new(x, 1.8, z) * CFrame.Angles(0, 0, tilt), C.WoodDark, Enum.Material.Wood)
		block(m, "CrossBar", Vector3.new(2.2, 0.45, 0.5), CFrame.new(x, 2.8, z) * CFrame.Angles(0, 0, tilt), C.WoodDark, Enum.Material.Wood)
		block(m, "Mound", Vector3.new(2.4, 0.6, 4), CFrame.new(x, 0.2, z + 2.4), Color3.fromRGB(150, 120, 90), Enum.Material.Ground)
	end
	fenceLine(m, gx - 4, gz - 4, gz + 22)
	-- Abandoned wagon and barrels in the street.
	wagon(m, cx - 4, cz + 8, 2.6)
	barrel(m, cx + 8, cz - 10)
	barrel(m, cx + 9.5, cz - 12)
	placeSign(m, "DUSTWATER · POP. 0", cx, cz + 64, 0)
end

local function ranch(f, cx, cz)
	local m = model(f, "HorseRanch")
	local red = Color3.fromRGB(160, 46, 38)
	-- Barn with a two-slope (gambrel) roof and big doors.
	local bx, bz = cx + 34, cz + 8
	block(m, "BarnBody", Vector3.new(26, 16, 32), CFrame.new(bx, 8, bz), red, Enum.Material.WoodPlanks)
	for _, side in ipairs({ -1, 1 }) do
		block(m, "BarnRoofLow", Vector3.new(9, 0.8, 34), CFrame.new(bx + side * 10.5, 18.5, bz) * CFrame.Angles(0, 0, side * -1), C.Roof, Enum.Material.WoodPlanks)
		block(m, "BarnRoofHigh", Vector3.new(9, 0.8, 34), CFrame.new(bx + side * 4.4, 23.4, bz) * CFrame.Angles(0, 0, side * -0.35), C.Roof, Enum.Material.WoodPlanks)
	end
	block(m, "BarnDoor", Vector3.new(10, 11, 0.4), CFrame.new(bx, 5.5, bz - 16.1), C.WoodDark, Enum.Material.WoodPlanks)
	for _, ang in ipairs({ 0.75, -0.75 }) do
		block(m, "DoorX", Vector3.new(0.6, 14, 0.2), CFrame.new(bx, 5.5, bz - 16.4) * CFrame.Angles(0, 0, ang), C.White, Enum.Material.Wood)
	end
	local loft = block(m, "LoftSign", Vector3.new(12, 2.6, 0.3), CFrame.new(bx, 14, bz - 16.2), C.White, Enum.Material.Wood)
	sign(loft, Enum.NormalId.Front, "LUCKY HORSESHOE RANCH", red, nil, Enum.Font.Fondamento)
	for i = 1, 6 do
		hayBale(m, bx - 18 + (i % 3) * 3.2, bz - 6 + math.floor(i / 4) * 2.6, math.pi / 2)
	end
	-- Ranch house with a porch.
	westernBuilding(m, "RANCH HOUSE", CFrame.new(cx - 30, 0, cz - 4), 18, 16, 10, C.WoodLight)
	-- Corral with horses.
	local kx, kz = cx, cz + 34
	corral(m, kx, kz, 16, -math.pi / 2)
	for i = 1, 3 do
		horse(m, CFrame.new(kx + rng:NextNumber(-8, 8), 0, kz + rng:NextNumber(-6, 8)) * CFrame.Angles(0, rng:NextNumber(0, 6.2), 0), HORSE_COATS[i])
	end
	block(m, "Trough", Vector3.new(2.4, 1.6, 7), CFrame.new(kx + 11, 0.8, kz), C.Wood, Enum.Material.WoodPlanks)
	block(m, "TroughWater", Vector3.new(2, 0.2, 6.6), CFrame.new(kx + 11, 1.55, kz), Color3.fromRGB(80, 130, 160), Enum.Material.Glass, { Transparency = 0.2 })
	-- Cows grazing beside the barn.
	for i = 1, 4 do
		cow(m, CFrame.new(bx + 22 + rng:NextNumber(-4, 6), 0, bz - 12 + i * 8) * CFrame.Angles(0, rng:NextNumber(0, 6.2), 0))
	end
	fenceLine(m, bx + 32, bz - 20, bz + 30)
	windmill(m, cx - 10, cz + 4)
	placeSign(m, "LUCKY HORSESHOE RANCH", cx - 8, cz - 40, 0)
end

local function fort(f, cx, cz)
	local m = model(f, "FortDust")
	local half = 30
	local log = Color3.fromRGB(110, 78, 50)
	-- Palisade walls of sharpened logs; the gate opens north toward the church.
	for _, wall in ipairs({ { 0, -half, "X" }, { 0, half, "X" }, { -half, 0, "Z" }, { half, 0, "Z" } }) do
		for t = -half, half, 2.2 do
			local x = wall[3] == "X" and cx + t or cx + wall[1]
			local z = wall[3] == "X" and cz + wall[2] or cz + t
			local isGate = wall[3] == "X" and wall[2] > 0 and math.abs(t) < 6
			if not isGate then
				local h = 13 + rng:NextNumber(-0.6, 0.6)
				cylinder(m, "Log", h, 2, upright(x, h / 2, z), log, Enum.Material.Wood)
				small(block(m, "LogTip", Vector3.new(1.4, 1.4, 1.4), CFrame.new(x, h + 0.4, z) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), log, Enum.Material.Wood))
			end
		end
	end
	-- Walkway along the inside of the walls.
	for _, wall in ipairs({ { 0, -half + 2.5, 2 * half, 3 }, { 0, half - 2.5, 2 * half, 3 }, { -half + 2.5, 0, 3, 2 * half }, { half - 2.5, 0, 3, 2 * half } }) do
		block(m, "Walkway", Vector3.new(wall[3], 0.6, wall[4]), CFrame.new(cx + wall[1], 8.5, cz + wall[2]), C.WoodLight, Enum.Material.WoodPlanks)
	end
	-- Gate doors (open) and a sign above.
	for _, side in ipairs({ -1, 1 }) do
		block(m, "GateDoor", Vector3.new(6, 12, 0.8), CFrame.new(cx + side * 9, 6, cz + half + 3) * CFrame.Angles(0, side * 1.1, 0), C.WoodDark, Enum.Material.WoodPlanks)
	end
	local gateSign = block(m, "GateSign", Vector3.new(14, 3, 0.5), CFrame.new(cx, 15, cz + half + 0.5), C.WoodDark, Enum.Material.Wood)
	sign(gateSign, Enum.NormalId.Back, "FORT DUST", Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	-- Corner watchtowers.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local tx, tz = cx + sx * half, cz + sz * half
			for _, lx in ipairs({ -2.5, 2.5 }) do
				for _, lz in ipairs({ -2.5, 2.5 }) do
					block(m, "TowerLeg", Vector3.new(0.8, 18, 0.8), CFrame.new(tx + lx, 9, tz + lz), C.WoodDark, Enum.Material.Wood)
				end
			end
			block(m, "TowerFloor", Vector3.new(7, 0.6, 7), CFrame.new(tx, 16, tz), C.WoodLight, Enum.Material.WoodPlanks)
			block(m, "TowerRail", Vector3.new(7, 2, 0.4), CFrame.new(tx, 17.3, tz - 3.3), C.Wood, Enum.Material.WoodPlanks)
			block(m, "TowerRail", Vector3.new(7, 2, 0.4), CFrame.new(tx, 17.3, tz + 3.3), C.Wood, Enum.Material.WoodPlanks)
			block(m, "TowerRoof", Vector3.new(8, 0.6, 8), CFrame.new(tx, 21, tz), C.Roof, Enum.Material.WoodPlanks)
		end
	end
	-- Inside: barracks, flag, cannons, supplies.
	westernBuilding(m, "BARRACKS", CFrame.new(cx, 0, cz - 10), 22, 14, 10, C.Wood)
	flag(m, cx + 14, cz + 12, 22, FLAG_PALETTES[2], 0)
	for _, side in ipairs({ -1, 1 }) do
		local x, z = cx + side * 12, cz + 18
		cylinder(m, "CannonBarrel", 6, 1.4, CFrame.new(x, 2.3, z) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0.15), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
		for _, dx in ipairs({ -1, 1 }) do
			cylinder(m, "CannonWheel", 0.5, 3, CFrame.new(x + dx * 1.2, 1.5, z + 0.5), C.WoodDark, Enum.Material.Wood)
		end
		for k = 1, 3 do
			small(block(m, "Cannonball", Vector3.new(1, 1, 1), CFrame.new(x + side * 3, 0.5, z - 1 + k * 1.1), Color3.fromRGB(30, 30, 30), Enum.Material.Metal, { Shape = Enum.PartType.Ball }))
		end
	end
	for i = 1, 5 do
		crate(m, cx - 22 + rng:NextNumber(-2, 2), cz + 14 + i * 2.6)
	end
	barrel(m, cx + 22, cz + 18)
	barrel(m, cx + 22, cz + 21)
	lanternPost(m, cx - 7, cz + half + 3)
	lanternPost(m, cx + 7, cz + half + 3)
end

-- Signpost at the race start pointing to every place on the map.
local function crossroads(f, x, z)
	local m = model(f, "Signpost")
	block(m, "Post", Vector3.new(0.8, 14, 0.8), CFrame.new(x, 7, z), C.WoodDark, Enum.Material.Wood)
	local signs = {
		{ "RIVER & BRIDGE", 0, 0 },
		{ "RANCH", 0.5, 1 },
		{ "TOWN · STATION", math.pi / 2, 2 },
		{ "FORT DUST", math.pi, 3 },
		{ "GHOST TOWN", -math.pi / 2 - 0.2, 4 },
		{ "OASIS · MINE", -math.pi / 2 + 0.5, 5 },
	}
	for _, def in ipairs(signs) do
		-- Arrow board pointing along its yaw (0 = north / +Z).
		local cf = CFrame.new(x, 12.5 - def[3] * 1.5, z) * CFrame.Angles(0, -def[2] + math.pi / 2, 0) * CFrame.new(3.2, 0, 0)
		local board = block(m, "Arrow", Vector3.new(6, 1.2, 0.3), cf, C.WoodLight, Enum.Material.WoodPlanks)
		sign(board, Enum.NormalId.Front, def[1], Color3.fromRGB(50, 30, 15), nil, Enum.Font.Fondamento)
		sign(board, Enum.NormalId.Back, def[1], Color3.fromRGB(50, 30, 15), nil, Enum.Font.Fondamento)
	end
end

local function buildNewPlaces()
	local f = folder("NewPlaces")
	-- Flat ground for each place first.
	flatten(140, 220, 75) -- ranch
	flatten(10, -410, 50) -- fort
	flatten(-170, -40, 70) -- ghost town
	flatten(-200, riverZ(-200) - 30, 30) -- gold camp
	buildRiver(f)
	coveredBridge(f, 0)
	railwayTrestle(f, 440)
	goldCamp(f, -200)
	ghostTown(f, -170, -40)
	ranch(f, 140, 215)
	fort(f, 10, -410)
	crossroads(f, 30, 140)
	-- Roads linking them up.
	road(0, 210, 14, 100) -- race start -> bridge
	road(0, riverZ(0) + 60, 14, 70) -- across the bridge, north
	road(140, 150, 12, 100) -- town road -> ranch
	road(-170, -40, 14, 150) -- ghost town main street
	road(-170, 92, 14, 116) -- ghost town -> west road
	road(5, -335, 12, 90) -- church -> fort
	road(-200, riverZ(-200) - 60, 12, 70) -- west road -> gold camp
end

---------------------------------------------------------------------------
-- DETAIL PASS: desert flora and clutter in the open ground, more life at
-- the race grounds and the camp, terrain variety. Small props don't
-- collide or cast shadows so they cost very little.
---------------------------------------------------------------------------
local D = {
	Sage = Color3.fromRGB(128, 138, 100),
	SageDark = Color3.fromRGB(100, 112, 80),
	Straw = Color3.fromRGB(214, 190, 120),
	Pad = Color3.fromRGB(96, 138, 70),
	Fruit = Color3.fromRGB(200, 60, 100),
	Bark = Color3.fromRGB(110, 92, 70),
	Spike = Color3.fromRGB(120, 140, 70),
	Bone = Color3.fromRGB(236, 228, 210),
	Rock = Color3.fromRGB(176, 128, 96),
	RockDark = Color3.fromRGB(140, 98, 72),
	Grey = Color3.fromRGB(150, 146, 140),
}

local function decor(p)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- Where things already stand (cells of 8 studs), so scattered detail
-- only goes in open ground: never on a building, road or the river.
local CELL = 8
local occupied = {}
local function markCircle(x, z, r)
	for cx = math.floor((x - r) / CELL), math.floor((x + r) / CELL) do
		for cz = math.floor((z - r) / CELL), math.floor((z + r) / CELL) do
			occupied[cx .. "," .. cz] = true
		end
	end
end
local function markRect(x, z, sx, sz)
	markCircle(x, z, math.max(sx, sz) / 2) -- (generous: a square around it)
end
local function isFree(x, z, r)
	if math.abs(z - riverZ(x)) < 26 + r and x > -400 and x < 580 then
		return false
	end
	for cx = math.floor((x - r) / CELL), math.floor((x + r) / CELL) do
		for cz = math.floor((z - r) / CELL), math.floor((z + r) / CELL) do
			if occupied[cx .. "," .. cz] then
				return false
			end
		end
	end
	return true
end
local function mapOccupied()
	occupied = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			local p = d.Position - origin
			local size = d.Size
			markCircle(p.X, p.Z, math.max(size.X, size.Z) / 2 + 4)
		end
	end
	-- Roads, the track and the town street (terrain, not parts).
	markRect(0, -50, 40, 440)
	markRect(260, -40, 44, 260)
	markRect(130, 100, 270, 26)
	markRect(0, 210, 24, 110)
	markRect(140, 150, 22, 110)
	markRect(-170, -40, 24, 160)
	markRect(-170, 92, 24, 126)
	markRect(5, -335, 22, 100)
	-- Keep the spawn and the arena round it clear.
	markCircle(0, 150, 30)
end

-- n tries at a random open spot inside the map; calls fn(x, z) for each.
local function scatter(n, radius, fn)
	local placed, tries = 0, 0
	while placed < n and tries < n * 12 do
		tries = tries + 1
		local x, z = rng:NextNumber(-470, 470), rng:NextNumber(-470, 470)
		if isFree(x, z, radius) then
			markCircle(x, z, radius)
			fn(x, z)
			placed = placed + 1
		end
	end
	return placed
end

local function sagebrush(parent, x, z)
	local m = model(parent, "Sagebrush")
	for i = 1, 3 do
		local s = rng:NextNumber(1.2, 2.2)
		decor(block(m, "Leaves", Vector3.new(s * 1.2, s * 0.8, s), CFrame.new(x + rng:NextNumber(-0.8, 0.8), s * 0.35, z + rng:NextNumber(-0.8, 0.8)) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)), i % 2 == 0 and D.Sage or D.SageDark, Enum.Material.Grass))
	end
end

local function grassTuft(parent, x, z)
	local m = model(parent, "GrassTuft")
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2
		decor(block(m, "Blade", Vector3.new(0.18, rng:NextNumber(0.9, 1.6), 0.18), CFrame.new(x + math.cos(a) * 0.25, 0.55, z + math.sin(a) * 0.25) * CFrame.Angles(math.sin(a) * 0.35, 0, -math.cos(a) * 0.35), D.Straw, Enum.Material.Grass))
	end
end

local function pricklyPear(parent, x, z)
	local m = model(parent, "PricklyPear")
	local pads = {
		{ 0, 0.8, 0, 0 }, { -0.7, 1.7, 0.1, 0.4 }, { 0.7, 1.6, -0.1, -0.35 }, { 0.2, 2.6, 0, 0.15 },
	}
	for i, pd in ipairs(pads) do
		local cf = CFrame.new(x + pd[1], pd[2], z + pd[3]) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), pd[4])
		block(m, "Pad", Vector3.new(1.2, 1.4, 0.35), cf, D.Pad, Enum.Material.Grass)
		if i > 1 then
			decor(block(m, "Fruit", Vector3.new(0.3, 0.3, 0.3), cf * CFrame.new(0.3, 0.75, 0), D.Fruit, Enum.Material.SmoothPlastic))
		end
	end
end

local function spikyTuft(parent, cf)
	for _, a in ipairs({ 0, math.pi / 4 }) do
		decor(block(parent, "Spikes", Vector3.new(1.6, 0.25, 0.25), cf * CFrame.Angles(0, a, math.pi / 4), D.Spike, Enum.Material.Grass))
		decor(block(parent, "Spikes", Vector3.new(0.25, 1.6, 0.25), cf * CFrame.Angles(a, 0, 0), D.Spike, Enum.Material.Grass))
	end
end

local function joshuaTree(parent, x, z)
	local m = model(parent, "JoshuaTree")
	local h = rng:NextNumber(7, 10)
	block(m, "Trunk", Vector3.new(1.1, h, 1.1), CFrame.new(x, h / 2, z), D.Bark, Enum.Material.Wood)
	for i = 1, rng:NextInteger(2, 3) do
		local a = i / 3 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local len = rng:NextNumber(2.5, 4)
		local base = CFrame.new(x, h * rng:NextNumber(0.6, 0.9), z) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, 0.8)
		block(m, "Arm", Vector3.new(0.7, len, 0.7), base * CFrame.new(0, len / 2, 0), D.Bark, Enum.Material.Wood)
		spikyTuft(m, base * CFrame.new(0, len + 0.4, 0))
	end
	spikyTuft(m, CFrame.new(x, h + 0.5, z))
end

local function boulders(parent, x, z)
	local m = model(parent, "Boulders")
	for i = 1, rng:NextInteger(2, 4) do
		local s = rng:NextNumber(2, 5.5)
		block(m, "Boulder", Vector3.new(s * rng:NextNumber(0.9, 1.4), s * 0.8, s), CFrame.new(x + rng:NextNumber(-3, 3), s * 0.3, z + rng:NextNumber(-3, 3)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), i % 2 == 0 and D.Rock or D.RockDark, Enum.Material.Sandstone)
	end
end

local function hoodoo(parent, x, z)
	local m = model(parent, "Hoodoo")
	local y = 0
	local w = rng:NextNumber(5, 7)
	for i = 1, 4 do
		local h = rng:NextNumber(3, 5)
		block(m, "Layer", Vector3.new(w, h, w * 0.9), CFrame.new(x + rng:NextNumber(-0.4, 0.4), y + h / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), i % 2 == 0 and D.Rock or D.RockDark, Enum.Material.Sandstone)
		y = y + h
		w = w * rng:NextNumber(0.7, 0.85)
	end
	-- A wider cap stone balanced on top.
	block(m, "Cap", Vector3.new(w * 2.2, 1.6, w * 2), CFrame.new(x, y + 0.8, z) * CFrame.Angles(0, rng:NextNumber(0, 2), 0.05), D.RockDark, Enum.Material.Slate)
end

local function bones(parent, x, z)
	local m = model(parent, "Bones")
	local yaw = rng:NextNumber(0, math.pi * 2)
	local base = CFrame.new(x, 0.3, z) * CFrame.Angles(0, yaw, 0)
	decor(block(m, "Spine", Vector3.new(0.35, 0.35, 4), base, D.Bone, Enum.Material.SmoothPlastic))
	for i = -2, 2 do
		for _, side in ipairs({ -1, 1 }) do
			decor(block(m, "Rib", Vector3.new(0.2, 1.6, 0.2), base * CFrame.new(side * 0.6, 0.6, i * 0.6) * CFrame.Angles(0, 0, side * -0.5), D.Bone, Enum.Material.SmoothPlastic))
		end
	end
	decor(block(m, "Skull", Vector3.new(1, 0.8, 1.6), base * CFrame.new(0, 0.1, 2.8), D.Bone, Enum.Material.SmoothPlastic))
	for _, side in ipairs({ -1, 1 }) do
		decor(block(m, "Horn", Vector3.new(1.2, 0.2, 0.2), base * CFrame.new(side * 0.9, 0.4, 2.6) * CFrame.Angles(0, 0, side * 0.5), D.Bone, Enum.Material.SmoothPlastic))
	end
end

local function brokenWagon(parent, x, z)
	local m = model(parent, "BrokenWagon")
	local yaw = rng:NextNumber(0, math.pi * 2)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	block(m, "Bed", Vector3.new(5, 0.5, 9), base * CFrame.new(0, 1.1, 0) * CFrame.Angles(0.08, 0, 0.25), C.WoodDark, Enum.Material.WoodPlanks)
	block(m, "Side", Vector3.new(0.4, 1.6, 9), base * CFrame.new(2.4, 1.6, 0) * CFrame.Angles(0, 0, 0.3), C.Wood, Enum.Material.WoodPlanks)
	cylinder(m, "Wheel", 0.5, 4, base * CFrame.new(-2.8, 2, 2.8), C.WoodDark, Enum.Material.Wood)
	cylinder(m, "FallenWheel", 0.5, 4, base * CFrame.new(3.5, 0.3, -3.5) * CFrame.Angles(0, 0, math.pi / 2), C.WoodDark, Enum.Material.Wood)
	for i = 1, 3 do
		decor(block(m, "Plank", Vector3.new(0.5, 0.25, rng:NextNumber(3, 5)), base * CFrame.new(rng:NextNumber(-4, 4), 0.15, rng:NextNumber(-6, 6)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), C.WoodLight, Enum.Material.WoodPlanks))
	end
end

local function oldFence(parent, x, z)
	local m = model(parent, "OldFence")
	local yaw = rng:NextNumber(0, math.pi * 2)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local n = rng:NextInteger(3, 5)
	for i = 1, n do
		block(m, "Post", Vector3.new(0.5, 4, 0.5), base * CFrame.new(0, 2, (i - 1) * 4) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)), C.WoodDark, Enum.Material.Wood)
	end
	block(m, "Rail", Vector3.new(0.3, 0.3, (n - 1) * 4), base * CFrame.new(0, 3, (n - 1) * 2) * CFrame.Angles(0.05, 0, 0), C.Wood, Enum.Material.Wood)
	block(m, "FallenRail", Vector3.new(0.3, 0.3, 4), base * CFrame.new(0.8, 0.2, (n - 1) * 2) * CFrame.Angles(0, 0.3, 0), C.Wood, Enum.Material.Wood)
end

local function pebbles(parent, x, z)
	local m = model(parent, "Pebbles")
	for _ = 1, 3 do
		local s = rng:NextNumber(0.5, 1.1)
		decor(block(m, "Pebble", Vector3.new(s, s * 0.6, s * 0.8), CFrame.new(x + rng:NextNumber(-1.5, 1.5), s * 0.2, z + rng:NextNumber(-1.5, 1.5)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), D.Grey, Enum.Material.Slate))
	end
end

local function buildDesertDetail()
	local f = folder("DesertDetail")
	mapOccupied()
	-- Terrain variety first: gentle dunes and patches of hard ground / salt.
	local terrain = workspace.Terrain
	scatter(24, 34, function(x, z)
		local r = rng:NextNumber(22, 40)
		terrain:FillBall(origin + Vector3.new(x, -r * 0.86, z), r, Enum.Material.Sand)
	end)
	local mats = { Enum.Material.Ground, Enum.Material.Sandstone, Enum.Material.Ground, Enum.Material.Salt }
	scatter(36, 10, function(x, z)
		terrain:FillCylinder(CFrame.new(origin + Vector3.new(x, -0.45, z)), 1, rng:NextNumber(5, 14), mats[rng:NextInteger(1, #mats)])
	end)
	-- A cracked salt flat out in the far desert.
	if isFree(380, -390, 50) then
		terrain:FillCylinder(CFrame.new(origin + Vector3.new(380, -0.45, -390)), 1, 55, Enum.Material.Salt)
		markCircle(380, -390, 55)
	end
	-- Flora and clutter (bigger things first so they get the space).
	scatter(8, 8, function(x, z) hoodoo(f, x, z) end)
	scatter(14, 6, function(x, z) joshuaTree(f, x, z) end)
	scatter(45, 5, function(x, z) boulders(f, x, z) end)
	scatter(6, 7, function(x, z) brokenWagon(f, x, z) end)
	scatter(12, 9, function(x, z) oldFence(f, x, z) end)
	scatter(10, 4, function(x, z) bones(f, x, z) end)
	scatter(30, 2, function(x, z) pricklyPear(f, x, z) end)
	scatter(120, 2, function(x, z) sagebrush(f, x, z) end)
	scatter(80, 1, function(x, z) grassTuft(f, x, z) end)
	scatter(60, 2, function(x, z) pebbles(f, x, z) end)
end

-- Race grounds: distance markers, pennants over the track, a judges' tower,
-- hay bale barriers, a crowd on the bleachers, a water station.
local function buildRaceDetail()
	local f = folder("RaceDetail")
	local marks = { "START", "1 FURLONG", "2 FURLONGS", "3 FURLONGS", "4 FURLONGS", "5 FURLONGS", "6 FURLONGS", "7 FURLONGS", "1 MILE" }
	for i, text in ipairs(marks) do
		local z = 120 - (i - 1) * 42
		if z < -250 then
			break
		end
		local post = block(f, "MarkerPost", Vector3.new(0.6, 5, 0.6), CFrame.new(17, 2.5, z - 6), C.White, Enum.Material.Wood)
		local board = block(f, "MarkerBoard", Vector3.new(0.3, 1.6, 4.2), CFrame.new(17, 5.4, z - 6), C.White, Enum.Material.Wood)
		sign(board, Enum.NormalId.Left, text, C.Red, nil, Enum.Font.Fondamento)
		sign(board, Enum.NormalId.Right, text, C.Red, nil, Enum.Font.Fondamento)
		decor(post)
	end
	-- Pennant lines strung across the track.
	for i = 0, 5 do
		local z = 96 - i * 64
		hangingLine(f, Vector3.new(-22, 15, z), Vector3.new(22, 15, z - 16), 10, "pennants")
	end
	-- Judges' tower beside the start.
	local tx, tz = 22, 100
	for _, dx in ipairs({ -2.5, 2.5 }) do
		for _, dz in ipairs({ -2.5, 2.5 }) do
			block(f, "TowerLeg", Vector3.new(0.6, 12, 0.6), CFrame.new(tx + dx, 6, tz + dz), C.WoodDark, Enum.Material.Wood)
		end
	end
	block(f, "TowerFloor", Vector3.new(7, 0.6, 7), CFrame.new(tx, 12.3, tz), C.WoodLight, Enum.Material.WoodPlanks)
	block(f, "TowerRail", Vector3.new(7, 2, 0.3), CFrame.new(tx, 13.6, tz - 3.4), C.White, Enum.Material.Wood)
	block(f, "TowerRail", Vector3.new(0.3, 2, 7), CFrame.new(tx - 3.4, 13.6, tz), C.White, Enum.Material.Wood)
	block(f, "TowerRoof", Vector3.new(8, 0.5, 8), CFrame.new(tx, 17, tz) * CFrame.Angles(0.1, 0, 0), C.Red, Enum.Material.Fabric)
	for _, dx in ipairs({ -3.5, 3.5 }) do
		block(f, "RoofPost", Vector3.new(0.4, 4.5, 0.4), CFrame.new(tx + dx, 14.8, tz - 3.5), C.WoodDark, Enum.Material.Wood)
	end
	for i = 0, 5 do
		decor(block(f, "LadderRung", Vector3.new(2, 0.2, 0.2), CFrame.new(tx, 1 + i * 2, tz + 3.4), C.WoodDark, Enum.Material.Wood))
	end
	local judgeBoard = block(f, "JudgesBoard", Vector3.new(6, 1.6, 0.3), CFrame.new(tx, 15.6, tz - 3.6), C.WoodDark, Enum.Material.Wood)
	sign(judgeBoard, Enum.NormalId.Front, "JUDGES", Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	-- Hay bale barriers on the inside of the far end.
	for i = 0, 7 do
		local a = i / 7 * math.pi
		block(f, "HayBale", Vector3.new(3, 2, 2), CFrame.new(math.cos(a) * 9, 1, -238 - math.sin(a) * 6) * CFrame.Angles(0, -a, 0), Color3.fromRGB(214, 186, 110), Enum.Material.Grass)
	end
	-- A blocky crowd on the bleachers.
	local shirts = { C.Red, Color3.fromRGB(60, 90, 160), Color3.fromRGB(90, 130, 70), Color3.fromRGB(200, 170, 90), C.White, Color3.fromRGB(120, 80, 60) }
	for row = 0, 3 do
		for i = 0, 6 do
			if rng:NextNumber() < 0.75 then
				local x, y, z = -30 - row * 4, 1 + row * 1.6 + 0.5, 54 + i * 5.2 + rng:NextNumber(-1, 1)
				decor(block(f, "Spectator", Vector3.new(1.2, 1.8, 1.6), CFrame.new(x, y + 0.9, z), shirts[rng:NextInteger(1, #shirts)], Enum.Material.Fabric))
				decor(block(f, "SpectatorHead", Vector3.new(0.9, 0.9, 0.9), CFrame.new(x, y + 2.25, z), Color3.fromRGB(226, 186, 150), Enum.Material.SmoothPlastic))
				if rng:NextNumber() < 0.6 then
					decor(block(f, "SpectatorHat", Vector3.new(1.6, 0.25, 1.6), CFrame.new(x, y + 2.75, z), C.WoodDark, Enum.Material.Fabric))
				end
			end
		end
	end
	-- Water station for the horses.
	block(f, "WaterTable", Vector3.new(3, 0.4, 8), CFrame.new(-19, 2.6, 30), C.WoodLight, Enum.Material.WoodPlanks)
	for _, dz in ipairs({ -3, 3 }) do
		block(f, "TableLeg", Vector3.new(0.4, 2.4, 0.4), CFrame.new(-19, 1.2, 30 + dz), C.WoodDark, Enum.Material.Wood)
		barrel(f, -21.5, 30 + dz)
	end
	for i = -1, 1 do
		decor(block(f, "Bucket", Vector3.new(0.9, 0.9, 0.9), CFrame.new(-19, 3.25, 30 + i * 2.2), Color3.fromRGB(120, 124, 130), Enum.Material.Metal))
	end
end

-- Camp: logs round the campfires, cooking pots, laundry lines.
local function buildCampDetail()
	local f = folder("CampDetail")
	local camp = root:FindFirstChild("TentCamp")
	if not camp then
		return
	end
	local tents = {}
	for _, d in ipairs(camp:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Campfire" then
			local p = d.Position - origin
			for i = 0, 2 do
				local a = i / 3 * math.pi * 2 + 0.4
				cylinder(f, "Log", 3.4, 0.9, CFrame.new(p.X + math.cos(a) * 3.2, 0.45, p.Z + math.sin(a) * 3.2) * CFrame.Angles(0, -a + math.pi / 2, 0), C.WoodDark, Enum.Material.Wood)
			end
			for i = 0, 2 do
				local a = i / 3 * math.pi * 2
				decor(block(f, "Tripod", Vector3.new(0.15, 3.4, 0.15), CFrame.new(p.X + math.cos(a) * 0.8, 1.6, p.Z + math.sin(a) * 0.8) * CFrame.Angles(math.sin(a) * 0.3, 0, -math.cos(a) * 0.3), C.WoodDark, Enum.Material.Wood))
			end
			decor(block(f, "Pot", Vector3.new(1, 0.8, 1), CFrame.new(p.X, 1.4, p.Z), Color3.fromRGB(50, 48, 46), Enum.Material.Metal))
			local smoke = Instance.new("Smoke")
			smoke.Color = Color3.fromRGB(150, 140, 130)
			smoke.Opacity = 0.08
			smoke.RiseVelocity = 4
			smoke.Size = 2
			smoke.Parent = d
		elseif d:IsA("BasePart") and d.Name:find("Tent") and #tents < 40 then
			table.insert(tents, d.Position - origin)
		end
	end
	-- Laundry lines between neighbouring tents.
	local made = 0
	for i = 1, #tents - 1, 3 do
		local a, b = tents[i], tents[i + 1]
		local dist = (a - b).Magnitude
		if dist > 8 and dist < 24 and made < 8 then
			made = made + 1
			hangingLine(f, Vector3.new(a.X, 4, a.Z), Vector3.new(b.X, 4, b.Z), 5, "pennants")
		end
	end
end

-- NPC markers: NPCService (runtime) spawns a character at each.
local NPCS = {
	{ "Race Announcer", "Announcer", Vector3.new(-6, 0, 118), 0, "Welcome, riders! The greatest horse race in history starts right here!|Six thousand kilometers of desert, mountains and rivers. Only one can win.|Keep your Spin steady and your eyes on the trail!" },
	{ "Race Official", "Official", Vector3.new(10, 0, 100), 0, "Racers, line up behind the start banner.|No shortcuts through the town, I'm watching you.|Checkpoints are marked with flags. Don't miss one!" },
	{ "Rival Racer", "Racer", Vector3.new(-8, 0, 60), 0, "Think you can keep up? Ha!|I've trained for this race my whole life.|See you at the goal... if you make it." },
	{ "Rookie Racer", "Racer", Vector3.new(8, 0, 20), 0, "My first race! I'm so nervous...|Do you know how to do that spinning thing?|I heard someone can fire their fingernails. Scary!" },
	{ "Camp Cook", "Spectator", Vector3.new(-60, 0, -20), 12, "Beans again tonight, folks.|Eat up, the desert won't wait for you.|Stay away from the cactus juice." },
	{ "Wagon Driver", "Spectator", Vector3.new(70, 0, -80), 14, "These wheels have crossed three states already.|Need a ride? Sorry, wagons are for supplies only.|Dust storm's coming, I can feel it." },
	{ "Sheriff", "Guard", Vector3.new(272, 0, 6), 6, "No fighting on Main Street. Take it outside of town.|I've got my eye on you, stranger.|Strange powers in this race. Strange times." },
	{ "Saloon Owner", "Spectator", Vector3.new(248, 0, 40), 6, "Welcome to the saloon, partner!|Racers drink free... water, that is.|Heard the favourite spins steel balls. Odd fellow." },
	{ "Shopkeeper", "Spectator", Vector3.new(272, 0, 40), 6, "Ropes, canteens, horseshoes, all here.|Prices doubled for the race. Supply and demand!|Come back when you've got more coin." },
	{ "Townsfolk", "Spectator", Vector3.new(260, 0, -40), 30, "The racers came through town at dawn!|My money's on the cowboy with the blue scarf.|Did you see that flash of light out by the church?" },
	{ "Priest", "Spectator", Vector3.new(0, 0, -270), 10, "Peace be with you, traveller.|This mission has stood for a hundred years.|Many racers rest here before the long road." },
	{ "Stable Hand", "Spectator", Vector3.new(-66, 0, 112), 8, "Easy, easy... these horses are nervous before a race.|A good horse is worth more than gold out here.|Feed them, water them, never rush them." },
	{ "Station Master", "Official", Vector3.new(425, 1.6, 10), 10, "Next train to the east leaves at sundown.|Racers ride horses, not trains. Rules are rules!|The telegraph says the leaders passed Arizona already." },
	{ "Old Miner", "Spectator", Vector3.new(-320, 0, -335), 6, "Silver? Nah, the mine's been empty for years.|I heard strange spinning sounds down there last night.|Don't go in without a lantern." },
	{ "Oasis Traveller", "Spectator", Vector3.new(-262, 0, 178), 10, "Fresh water! First I've seen in two days.|Rest here before you cross the dunes.|The mesas make good landmarks. Don't get lost." },
	{ "Headquarters Clerk", "Official", Vector3.new(260, 18, -228), 8, "Registration is closed, I'm afraid.|The sponsors are watching every rider closely.|Prize money is fifty million dollars. Can you believe it?" },
	{ "Bridge Keeper", "Official", Vector3.new(-9, 0, 258), 6, "Toll's free during the race. Lucky you.|This bridge has survived three floods.|Don't fight on my bridge. The river's colder than it looks." },
	{ "Gold Prospector", "Spectator", Vector3.new(-196, 0, 240), 10, "Gold! There's gold in this river, I tell ya!|Keep your hands off my claim.|Found a nugget shaped like a horseshoe this morning." },
	{ "Ranch Owner", "Spectator", Vector3.new(118, 0, 196), 10, "Welcome to the Lucky Horseshoe!|Best horses west of the Mississippi.|Need a fresh mount? Win the race first." },
	{ "Cowhand", "Spectator", Vector3.new(196, 0, 214), 14, "Yee-haw! Watch the cows, they spook easy.|I rope cattle all day. Spinning? That's new.|The barn's got hay if your horse is hungry." },
	{ "Fort Captain", "Guard", Vector3.new(4, 0, -392), 8, "Fort Dust stands guard over the southern trail.|Report any strange powers to me, rider.|My soldiers saw someone fire nails from his fingers!" },
	{ "Fort Soldier", "Guard", Vector3.new(18, 0, -428), 10, "Halt! Oh, a racer. Carry on.|Watch duty again... nothing but sand.|The cannons haven't fired in years." },
	{ "Mysterious Drifter", "Spectator", Vector3.new(-168, 0, -20), 12, "Nobody's lived in Dustwater for twenty years.|The well dried up and the people left.|Some say a Stand user drained it. Who knows." },
	{ "Fisherman", "Spectator", Vector3.new(60, 0, 268), 6, "Shh, you'll scare the fish.|Caught a catfish this big yesterday!|The waterfall's to the west, if you like sightseeing." },
}

local function buildNPCMarkers()
	local f = folder("NPCSpawns")
	for _, def in ipairs(NPCS) do
		local marker = block(f, def[1]:gsub(" ", ""), Vector3.new(2, 1, 2), CFrame.new(def[3] + Vector3.new(0, 0.5, 0)), Color3.fromRGB(80, 200, 255), Enum.Material.Neon, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		marker:SetAttribute("DisplayName", def[1])
		marker:SetAttribute("Role", def[2])
		marker:SetAttribute("WanderRadius", def[4])
		marker:SetAttribute("Lines", def[5])
	end
	-- Waypoints racers jog between (along the track).
	local wp = folder("RacerWaypoints")
	for i, z in ipairs({ 100, 0, -100, -200, -100, 0 }) do
		local p = block(wp, "Waypoint" .. i, Vector3.new(1, 1, 1), CFrame.new((i % 2 == 0) and 5 or -5, 0.5, z), Color3.new(1, 1, 1), Enum.Material.Neon, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		p:SetAttribute("Order", i)
	end
end

---------------------------------------------------------------------------
function SBRMapBuilder.Build(options)
	options = options or {}
	origin = options.Origin or Vector3.new(0, 0, 0)
	rng = Random.new(options.Seed or 7)

	local old = workspace:FindFirstChild("SBRMap")
	if old then
		old:Destroy()
	end
	root = Instance.new("Model")
	root.Name = "SBRMap"
	root:SetAttribute("Origin", origin)

	if options.Terrain ~= false then
		buildTerrain()
	end
	if options.Lighting ~= false then
		buildLighting()
	end
	buildRaceGrounds()
	buildChurch()
	buildCamp()
	buildTown()
	buildHeadquarters()
	buildDesert()
	buildUpgrades()
	buildNewPlaces()
	buildRaceDetail()
	buildCampDetail()
	buildDesertDetail() -- last: fills only the open ground left over
	buildNPCMarkers()
	root.Parent = workspace

	local count = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			count = count + 1
		end
	end
	print(("[SBRMapBuilder] Built SBRMap with %d parts at %s. Remember File > Save."):format(count, tostring(origin)))
	return root
end

return SBRMapBuilder
end

-- ======================================================================
-- MODULE: StandAssetLoader
-- ======================================================================
__modules["StandAssetLoader"] = function()
--[[
	StandAssetLoader  (ServerScriptService.SpinServer.StandAssetLoader)

	Loads the Stand models listed in TuskConfig.StandModels (by asset id)
	into ReplicatedStorage.SpinAssets as "TuskAct1", "TuskAct2"...
	Every client then uses that model instead of the built-in one.

	Safety: every Script, LocalScript and ModuleScript inside a loaded
	model is deleted before anyone can see it (free models sometimes hide
	harmful scripts).

	If Roblox refuses to load an asset (InsertService can only load models
	your account owns, or free models depending on Roblox's rules), the
	Output says so. Then insert the model yourself: Toolbox > search the id
	> drag it into ReplicatedStorage > put it in a Folder named SpinAssets
	> rename it TuskAct1.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local StandAssetLoader = {}

local function assetsFolder()
	local folder = ReplicatedStorage:FindFirstChild("SpinAssets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SpinAssets"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local function sanitize(model)
	local removed = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
			removed = removed + 1
		end
	end
	return removed
end

local function load(act, entry)
	local name = "TuskAct" .. act
	local folder = assetsFolder()
	if folder:FindFirstChild(name) then
		return -- already placed by hand: keep it
	end
	local ok, container = pcall(function()
		return InsertService:LoadAsset(entry.AssetId)
	end)
	if not ok or not container then
		warn(("[Spin] Could not load Stand model %d for Act %d (%s). Insert it by hand: Toolbox > drag into ReplicatedStorage.SpinAssets > rename %s."):format(entry.AssetId, act, tostring(container), name))
		return
	end
	local model = container:FindFirstChildWhichIsA("Model", true) or container
	local removed = sanitize(model)
	model.Name = name
	if not model:IsA("Model") then
		local wrapper = Instance.new("Model")
		for _, child in ipairs(model:GetChildren()) do
			child.Parent = wrapper
		end
		model = wrapper
		model.Name = name
	end
	model.Parent = folder
	container:Destroy()
	print(("[Spin] Loaded Stand model %d as %s%s"):format(entry.AssetId, name, removed > 0 and (" (removed " .. removed .. " scripts for safety)") or ""))
end

function StandAssetLoader.init()
	for act, entry in pairs(TuskConfig.StandModels or {}) do
		if entry.AssetId and entry.AssetId ~= 0 then
			task.spawn(load, act, entry)
		end
	end
end

return StandAssetLoader
end

-- ======================================================================
-- MODULE: StandBots
-- ======================================================================
__modules["StandBots"] = function()
--[[
	StandBots  (ServerScriptService.SpinServer.StandBots)

	Enemy NPCs that fight you with a Stand. Each one plays a real character
	(Johnny / Tusk, Gyro, Diego, Pork Pie Hat Kid, Sandman, Mountain Tim, Hot Pants, Blackmore, Axl RO, Funny Valentine, Diego (AU):
	whichever are installed) through exactly the same move code as players, so their M1s,
	abilities and ultimates hit, stun and look the same.
	  * they're scattered round the map (TuskConfig.StandBots.Spots), chase
	    any player who comes within AggroRange and walk back to their spot
	    when the player gets away
	  * each respawn picks a new free spot, so they move around over time
	  * M1 combo up close, abilities on cooldown, ultimate when their meter is full
	  * hold abilities are charged and released automatically
	  * they block now and then, dash in to close the gap, and dash away when hurt
	  * a sneaking player isn't noticed until they're close (TuskConfig.Sneak
	    NoticeRange), or they hit the bot; a bot that saw them keeps track for
	    a few seconds
	  * every installed character has an NPC out: a new NPC is whichever
	    character has the fewest right now (TuskConfig.StandBots.Characters)
	  * Blackmore NPCs rain walk while it rains: they step up onto frozen
	    raindrops (an invisible step only NPCs collide with) and climb
	    toward players above them
	  * idle bots walk over and pick up Saint's Corpse parts lying near their
	    camp; bots holding parts use their corpse move and drop them on death
	  * they respawn RespawnTime seconds after dying, as whoever is missing
	Settings: TuskConfig.StandBots (Enabled = false turns them off).
	Tagged "SpinFighter" so every client draws their Stand, outfit and effects.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")

local StandBots = {}
local S -- TuskService
local cfg
local folder
local bots = {}
local nextId = 0

-- Body colours per character so you can tell them apart before they attack.
local LOOKS = {
	Johnny = { Skin = Color3.fromRGB(234, 190, 150), Torso = Color3.fromRGB(60, 110, 190), Legs = Color3.fromRGB(40, 40, 60) },
	Gyro = { Skin = Color3.fromRGB(226, 180, 140), Torso = Color3.fromRGB(102, 64, 150), Legs = Color3.fromRGB(70, 46, 110) },
	Diego = { Skin = Color3.fromRGB(240, 200, 165), Torso = Color3.fromRGB(60, 120, 90), Legs = Color3.fromRGB(40, 50, 45) },
	PorkPie = { Skin = Color3.fromRGB(205, 150, 110), Torso = Color3.fromRGB(95, 115, 45), Legs = Color3.fromRGB(95, 115, 45) },
	Sandman = { Skin = Color3.fromRGB(170, 115, 80), Torso = Color3.fromRGB(200, 160, 100), Legs = Color3.fromRGB(120, 85, 55) },
	MountainTim = { Skin = Color3.fromRGB(226, 180, 140), Torso = Color3.fromRGB(70, 90, 130), Legs = Color3.fromRGB(60, 50, 70) },
	HotPants = { Skin = Color3.fromRGB(238, 196, 164), Torso = Color3.fromRGB(96, 60, 120), Legs = Color3.fromRGB(238, 196, 164) },
	Blackmore = { Skin = Color3.fromRGB(220, 196, 176), Torso = Color3.fromRGB(36, 44, 70), Legs = Color3.fromRGB(30, 30, 40) },
	Valentine = { Skin = Color3.fromRGB(240, 210, 190), Torso = Color3.fromRGB(236, 230, 220), Legs = Color3.fromRGB(40, 44, 70) },
	Axl = { Skin = Color3.fromRGB(230, 196, 160), Torso = Color3.fromRGB(110, 116, 128), Legs = Color3.fromRGB(46, 42, 50) },
	DiegoAU = { Skin = Color3.fromRGB(240, 205, 170), Torso = Color3.fromRGB(110, 200, 185), Legs = Color3.fromRGB(196, 170, 110) },
}

local usedSpots = {} -- [spot index] = slot using it

local function groundAt(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(pos + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
	return hit and hit.Position + Vector3.new(0, 3, 0) or pos
end

-- A free spot round the map (or, with no map, a camp near the spawn).
local function findHome(slot, count)
	local map = workspace:FindFirstChild("SBRMap")
	local spots = cfg.Spots
	if map and spots and #spots > 0 then
		local origin = map:GetAttribute("Origin") or Vector3.new()
		local free = {}
		for i in ipairs(spots) do
			if not usedSpots[i] then
				table.insert(free, i)
			end
		end
		if #free > 0 then
			local i = free[math.random(1, #free)]
			usedSpots[i] = slot
			return groundAt(origin + spots[i]), i
		end
	end
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = spawn and spawn.CFrame or CFrame.new(0, 5, 0)
	local spread = (slot - (count + 1) / 2) * (cfg.Spacing or 14)
	return groundAt((base * CFrame.new(spread, 0, cfg.Distance or 70)).Position), nil
end

-- Characters this server can actually play, as their start Acts.
local function playableActs()
	local list = {}
	for _, who in ipairs(cfg.Characters or {}) do
		local act = Registry.StartAct[who]
		if act and S.hasAct(act) then
			table.insert(list, { Who = who, Act = act })
		end
	end
	return list
end

-- A table that looks enough like a Player for the move code.
local function newBotPlayer(name, model)
	nextId = nextId + 1
	local attrs = {}
	return {
		Name = name,
		DisplayName = name,
		UserId = -1000 - nextId,
		Character = model,
		Neutral = true,
		IsBot = true,
		GetAttribute = function(_, k)
			return attrs[k]
		end,
		SetAttribute = function(_, k, v)
			attrs[k] = v
		end,
	}
end

local function buildModel(who)
	local look = LOOKS[who] or LOOKS.Johnny
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = look.Skin
	desc.LeftArmColor = look.Skin
	desc.RightArmColor = look.Skin
	desc.TorsoColor = look.Torso
	desc.LeftLegColor = look.Legs
	desc.RightLegColor = look.Legs
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[StandBots] couldn't create an NPC body: " .. tostring(model))
		return nil
	end
	return model
end

local spawnBot -- (defined below; respawn calls it)
local corpseService -- (defined below with the corpse helpers)

local endRainWalk -- (rain walk, below)

local function removeBot(bot)
	endRainWalk(bot, false)
	bots[bot.Slot] = nil
	if bot.Spot and usedSpots[bot.Spot] == bot.Slot then
		usedSpots[bot.Spot] = nil
	end
	S.removeBot(bot.Player)
	if bot.Model then
		bot.Model:Destroy()
	end
end

function spawnBot(slot)
	local choices = playableActs()
	if #choices == 0 then
		return
	end
	-- Whoever has the fewest NPCs out right now, so every character shows up.
	local counts = {}
	for _, other in pairs(bots) do
		if other.Slot ~= slot then
			counts[other.Who] = (counts[other.Who] or 0) + 1
		end
	end
	local fewest = math.huge
	for _, c in ipairs(choices) do
		fewest = math.min(fewest, counts[c.Who] or 0)
	end
	local pool = {}
	for _, c in ipairs(choices) do
		if (counts[c.Who] or 0) == fewest then
			table.insert(pool, c)
		end
	end
	local pick = pool[math.random(1, #pool)]
	local model = buildModel(pick.Who)
	if not model then
		return
	end
	local roster
	for _, entry in ipairs(TuskConfig.Roster or {}) do
		if entry.Id == pick.Who then
			roster = entry
		end
	end
	local name = "Stand User: " .. (roster and roster.Name or pick.Who)
	model.Name = name
	local home, spot = findHome(slot, cfg.Count)
	model:PivotTo(CFrame.new(home))
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 80
	humanoid.HealthDisplayDistance = 80
	humanoid.MaxHealth = cfg.Health or 200
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = cfg.WalkSpeed or 15
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		pcall(function()
			root:SetNetworkOwner(nil) -- the server drives NPCs
		end)
	end
	local botPlayer = newBotPlayer(name, model)
	local bot = { Slot = slot, Spot = spot, Player = botPlayer, Model = model, Humanoid = humanoid, Home = home, Who = pick.Who, NextThink = 0, NextAbility = os.clock() + 2, NextUlt = 0, SpawnedAt = os.clock() }
	bots[slot] = bot
	bot.State = S.addBot(botPlayer, pick.Act)
	CollectionService:AddTag(model, "SpinFighter")
	humanoid.Died:Connect(function()
		endRainWalk(bot, false)
		local C = corpseService()
		if C then
			local r = model:FindFirstChild("HumanoidRootPart")
			C.dropFor(botPlayer, r and r.Position or nil)
		end
		task.delay(cfg.RespawnTime or 10, function()
			if bots[slot] == bot then
				removeBot(bot)
				spawnBot(slot)
			end
		end)
	end)
end

---------------------------------------------------------------------------
-- Blackmore NPCs: RAIN WALK (the server moves NPCs, so the server does it).
-- An invisible step under his feet that only Stand-user NPCs collide with.
---------------------------------------------------------------------------
local STEP_GROUP, BOT_GROUP = "SpinRainStep", "SpinStandBot"
local groupsReady = false

local function setupGroups()
	if groupsReady then
		return true
	end
	groupsReady = pcall(function()
		for _, g in ipairs({ STEP_GROUP, BOT_GROUP }) do
			if not PhysicsService:IsCollisionGroupRegistered(g) then
				PhysicsService:RegisterCollisionGroup(g)
			end
		end
		for _, g in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
			PhysicsService:CollisionGroupSetCollidable(STEP_GROUP, g.name, g.name == BOT_GROUP)
		end
	end)
	return groupsReady
end

local function rainingFor(model)
	if game:GetService("ReplicatedStorage"):GetAttribute("SpinRaining") == true then
		return true
	end
	return (model:GetAttribute("RainStormUntil") or 0) > workspace:GetServerTimeNow()
end

local function feetY(bot, root)
	return root.Position.Y - (bot.Humanoid.HipHeight + root.Size.Y / 2)
end

local function walkCfg()
	return (TuskConfig.Blackmore and TuskConfig.Blackmore.RainWalk) or { FloatTime = 6, MaxSteps = 8, Cooldown = 3 }
end

function endRainWalk(bot, cooldown)
	local rw = bot.RainWalk
	if not rw then
		return
	end
	bot.RainWalk = nil
	if rw.Step then
		rw.Step:Destroy()
	end
	if bot.Model and bot.Model.Parent then
		bot.Model:SetAttribute("RainFloating", nil)
	end
	if cooldown then
		bot.RainWalkReady = os.clock() + walkCfg().Cooldown + 2
	end
end

-- Jump, then a frozen raindrop catches his feet near the top of the jump.
local function rainHop(bot)
	local rw = bot.RainWalk
	if not rw or rw.Steps >= walkCfg().MaxSteps then
		return
	end
	rw.Steps = rw.Steps + 1
	rw.Hopping = true
	bot.Humanoid.Jump = true
	task.delay(0.32, function()
		if bot.RainWalk ~= rw then
			return
		end
		rw.Hopping = false
		local root = bot.Model:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		rw.Y = math.max(feetY(bot, root), rw.Y or -math.huge)
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
	end)
end

local function startRainWalk(bot, root)
	if not setupGroups() then
		return
	end
	for _, d in ipairs(bot.Model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = BOT_GROUP
		end
	end
	local step = Instance.new("Part")
	step.Name = "RainStep"
	step.Anchored = true
	step.CanCollide = true
	step.CanQuery = false
	step.CanTouch = false
	step.Transparency = 1
	step.Size = Vector3.new(5, 0.4, 5)
	step.CollisionGroup = STEP_GROUP
	step.CFrame = CFrame.new(root.Position.X, -10000, root.Position.Z)
	step.Parent = folder
	local token = tostring({})
	bot.RainWalk = { Step = step, Start = os.clock(), Steps = 0, Token = token }
	bot.Model:SetAttribute("RainFloating", token)
	rainHop(bot)
end

-- Every frame: keep the step under his feet.
local function stepRainWalks()
	for _, bot in pairs(bots) do
		local rw = bot.RainWalk
		if rw and rw.Step and rw.Y then
			local root = bot.Model and bot.Model:FindFirstChild("HumanoidRootPart")
			if root then
				rw.Step.CFrame = CFrame.new(root.Position.X, rw.Y - 0.2, root.Position.Z)
			end
		end
	end
end

-- Each think: start, climb toward a target above him, or end.
local function thinkRainWalk(bot, root, target)
	if bot.Who ~= "Blackmore" then
		return
	end
	local now = os.clock()
	local rw = bot.RainWalk
	if rw then
		if now - rw.Start > walkCfg().FloatTime or not rainingFor(bot.Model) or bot.Model:GetAttribute("Stunned") or bot.Humanoid.Health <= 0 then
			endRainWalk(bot, true)
			return
		end
		-- Climb toward someone above him.
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		if tr and not rw.Hopping and rw.Y and tr.Position.Y - 1 > feetY(bot, root) + 2 then
			rainHop(bot)
		end
		return
	end
	if not target or now < (bot.RainWalkReady or 0) or not rainingFor(bot.Model) then
		return
	end
	local tr = target:FindFirstChild("HumanoidRootPart")
	local above = tr and tr.Position.Y > root.Position.Y + 4
	if above or math.random() < (cfg.RainWalkChance or 0.05) then
		startRainWalk(bot, root)
	end
end

-- Can this bot see `player`? Sneaking players are only noticed up close,
-- or if they just hit the bot, or the bot saw them a moment ago.
local function notices(bot, player, character, d)
	local sneak = TuskConfig.Sneak or {}
	bot.Noticed = bot.Noticed or {}
	local now = os.clock()
	local hitMe = bot.Model and bot.Model:GetAttribute("LastAttackerId") == player.UserId
		and workspace:GetServerTimeNow() - (bot.Model:GetAttribute("LastAttackTime") or -math.huge) < 4
	if not character:GetAttribute("TuskSneaking") or d <= (sneak.NoticeRange or 12) or hitMe then
		bot.Noticed[player] = now + (sneak.NoticeMemory or 3)
	end
	return (bot.Noticed[player] or 0) > now
end

-- Nearest player in range (that the bot has noticed).
local function findTarget(bot, root)
	local best, bestDist
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local tr = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if tr and hum and hum.Health > 0 and S.Adapter.canBeHit(bot.Player, character) then
			local d = (tr.Position - root.Position).Magnitude
			local fromHome = (tr.Position - bot.Home).Magnitude
			if d <= (cfg.AggroRange or 70) and fromHome <= (cfg.LeashRange or 120) and notices(bot, player, character, d) and (not bestDist or d < bestDist) then
				best, bestDist = character, d
			end
		end
	end
	-- Tell a sneaking target they've been spotted (the HUD shows it).
	if best and best:GetAttribute("TuskSneaking") then
		best:SetAttribute("SpottedUntil", workspace:GetServerTimeNow() + 1)
	end
	return best, bestDist
end

---------------------------------------------------------------------------
-- Saint's Corpse: idle bots go and pick up parts lying near their camp; in a
-- fight, bots holding parts use their corpse move; their parts drop on death.
---------------------------------------------------------------------------
local Corpse
corpseService = function()
	if Corpse == nil then
		-- (Wrapped in a function so the bundler can rewrite the require.)
		local ok, mod = pcall(function()
			return __require("CorpseService")
		end)
		Corpse = ok and mod or false
	end
	return Corpse or nil
end

-- How many parts a model holds (CorpseParts is a comma list of ids).
local function partsHeld(model)
	local list = model and model:GetAttribute("CorpseParts")
	if type(list) ~= "string" or list == "" then
		return 0
	end
	local n = 0
	for _ in string.gmatch(list, "[^,]+") do
		n = n + 1
	end
	return n
end

local function botsHolding()
	local n = 0
	for _, other in pairs(bots) do
		n = n + partsHeld(other.Model)
	end
	return n
end

local function seekCorpse(bot, root)
	local C = corpseService()
	if not C then
		return false
	end
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	-- Not straight after spawning, not when already holding enough, and NPCs
	-- together never hoard the corpse.
	if now - (bot.SpawnedAt or 0) < (cfg.CorpseSeekDelay or 120)
		or partsHeld(bot.Model) >= (cfg.CorpseMaxPerBot or 1)
		or botsHolding() >= (cfg.CorpseMaxForBots or 3) then
		bot.CorpseGoal, bot.PickupStart = nil, nil
		return false
	end
	local goal = bot.CorpseGoal
	if not (goal and goal.Parent) then
		goal = nil
		bot.PickupStart = nil
		if now >= (bot.NextCorpseLook or 0) then
			bot.NextCorpseLook = now + (cfg.CorpseSeekEvery or 15) * (0.7 + math.random() * 0.6)
			if math.random() < (cfg.CorpseSeekChance or 0.3) then
				local best, bestD
				for _, relic in ipairs(CollectionService:GetTagged("SpinCorpse")) do
					local at = relic.Parent and relic:GetPivot().Position
					local fresh = serverNow - (relic:GetAttribute("LaidAt") or 0) < (cfg.CorpseFreshTime or 90)
					if at and not fresh and (at - bot.Home).Magnitude <= (cfg.CorpseSeekRange or 60) then
						local d = (at - root.Position).Magnitude
						if not bestD or d < bestD then
							best, bestD = relic, d
						end
					end
				end
				goal = best
			end
		end
		bot.CorpseGoal = goal
	end
	if not goal then
		return false
	end
	local at = goal:GetPivot().Position
	if (at - root.Position).Magnitude <= 7 then
		-- Kneel by it for a moment: a player can still snatch it first.
		bot.Humanoid:MoveTo(root.Position)
		bot.PickupStart = bot.PickupStart or now
		if now - bot.PickupStart >= (cfg.CorpsePickupTime or 2.5) then
			C.take(bot.Player, goal:GetAttribute("PartId"))
			bot.CorpseGoal, bot.PickupStart = nil, nil
		end
	else
		bot.PickupStart = nil
		bot.Humanoid:MoveTo(at)
	end
	return true
end

local function useAbility(bot, module, slot, aim)
	local info = Registry.get(bot.State.Act)
	local kind = info and info.AbilityKinds and info.AbilityKinds[slot] or "Press"
	module.Ability(S, bot.Player, bot.State, slot, "Press", aim)
	if kind == "Hold" then
		local hold = 0.5 + math.random() * 0.9
		task.delay(hold, function()
			if bots[bot.Slot] == bot then
				module.Ability(S, bot.Player, bot.State, slot, "Release", aim)
			end
		end)
	end
end

local function think(bot, now)
	local model, humanoid = bot.Model, bot.Humanoid
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if not root or humanoid.Health <= 0 then
		return
	end
	local state = bot.State
	local module = state.Act and S.actModule(state.Act)
	if not module then
		return
	end
	local target, dist = findTarget(bot, root)
	if target then
		bot.PickupStart = nil -- a fight interrupts picking up a part
	end
	if not target then
		if bot.RainWalk then
			endRainWalk(bot, false)
		end
		if seekCorpse(bot, root) then
			return
		end
		if (root.Position - bot.Home).Magnitude > 6 then
			humanoid:MoveTo(bot.Home)
		end
		return
	end
	thinkRainWalk(bot, root, target)
	local tr = target:FindFirstChild("HumanoidRootPart")
	local flatTarget = Vector3.new(tr.Position.X, root.Position.Y, tr.Position.Z)
	local reach = cfg.AttackRange or 6
	if dist > reach - 1 then
		humanoid:MoveTo(tr.Position - (tr.Position - root.Position).Unit * (reach - 2))
	else
		humanoid:MoveTo(root.Position)
	end
	local Defense = S.Defense
	-- Holding a block: wait it out.
	if Defense and model:GetAttribute("Blocking") then
		if now >= (bot.BlockUntil or 0) then
			Defense.block(bot.Player, state, false)
		end
		return
	end
	if not S.Adapter.canAct(bot.Player) or S.isBusy(state) or state.Charging then
		return
	end
	if Defense then
		local hurt = humanoid.Health < humanoid.MaxHealth * 0.35
		-- Close in with a dash, or dash away when hurt.
		if dist > 14 and dist < 30 and math.random() < (cfg.DashChance or 0.06) then
			Defense.dash(bot.Player, state, tr.Position - root.Position)
			return
		elseif hurt and dist < 8 and math.random() < (cfg.DashChance or 0.06) then
			Defense.dash(bot.Player, state, root.Position - tr.Position)
			return
		end
		-- Block now and then when someone's right in front of them.
		if dist < reach + 2 and math.random() < (cfg.BlockChance or 0.05) then
			bot.BlockUntil = now + 0.4 + math.random() * 0.5
			Defense.block(bot.Player, state, true)
			return
		end
	end
	-- Face the target and attack.
	if (flatTarget - root.Position).Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, flatTarget)
	end
	local aim = (tr.Position - root.Position).Unit
	if bot.Player:GetAttribute("TuskUlt") and bot.Player:GetAttribute("TuskUlt") >= TuskConfig.Ultimate.MaxMeter and dist < 22 and now >= bot.NextUlt then
		bot.NextUlt = now + 5
		module.Ultimate(S, bot.Player, state, aim)
		return
	end
	-- Holding a corpse part: use the corpse move now and then.
	if model:GetAttribute("CorpseParts") and dist < 22 and (model:GetAttribute("CorpseReadyAt") or 0) <= workspace:GetServerTimeNow() and math.random() < (cfg.CorpseMoveChance or 0.12) and S.CorpseMove then
		S.CorpseMove(bot.Player, state, aim)
		return
	end
	if now >= bot.NextAbility and dist < (cfg.AbilityRange or 35) then
		bot.NextAbility = now + (cfg.AbilityEvery or 2.5) * (0.7 + math.random() * 0.6)
		useAbility(bot, module, math.random(1, 3), aim)
		return
	end
	if dist <= reach then
		module.M1(S, bot.Player, state, aim)
	end
end

function StandBots.init(TuskService)
	S = TuskService
	cfg = TuskConfig.StandBots or {}
	if cfg.Enabled == false or (cfg.Count or 0) <= 0 then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "SpinStandBots"
	folder.Parent = workspace
	task.delay(cfg.StartDelay or 3, function()
		for slot = 1, cfg.Count do
			spawnBot(slot)
		end
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		stepRainWalks()
		accumulator = accumulator + dt
		if accumulator < (cfg.ThinkEvery or 0.15) then
			return
		end
		accumulator = 0
		local now = os.clock()
		for _, bot in pairs(bots) do
			local ok, err = pcall(think, bot, now)
			if not ok then
				warn("[StandBots] " .. tostring(err))
			end
		end
	end)
end

return StandBots
end

-- ======================================================================
-- MODULE: TestDummies
-- ======================================================================
__modules["TestDummies"] = function()
--[[
	TestDummies  (ServerScriptService.SpinServer.TestDummies)
	Studio-only practice targets so Spin can be tested solo.
	Never runs in a live server (guarded by RunService:IsStudio()).
	Turn off with SpinConfig.Debug.SpawnTestDummies = false.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SpinConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("SpinConfig"))

local TestDummies = {}

local function findSpawn()
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.CFrame
	end
	return CFrame.new(0, 5, 0)
end

-- Training-dummy look (blocky, built from parts): burlap sack body, straw
-- sticking out of the head and cuffs, a stitched face with button eyes, a
-- red-and-white target on the chest, rope belt, wooden peg feet.
local BURLAP = Color3.fromRGB(196, 160, 108)
local BURLAP_DARK = Color3.fromRGB(150, 116, 74)
local STRAW = Color3.fromRGB(236, 205, 110)
local ROPE = Color3.fromRGB(120, 85, 50)
local RED = Color3.fromRGB(200, 50, 45)
local WHITE = Color3.fromRGB(245, 240, 230)
local INK = Color3.fromRGB(35, 28, 24)
local WOOD = Color3.fromRGB(110, 75, 45)

local function deco(parent, name, size, color, offset)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent.Parent
	return p
end

local function dress(dummy)
	local head = dummy:FindFirstChild("Head")
	local torso = dummy:FindFirstChild("UpperTorso") or dummy:FindFirstChild("Torso")
	local lower = dummy:FindFirstChild("LowerTorso")
	for _, part in ipairs(dummy:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = BURLAP
			part.Material = Enum.Material.Fabric
		end
	end
	if head then
		local face = head:FindFirstChildOfClass("Decal")
		if face then
			face:Destroy()
		end
		local s = head.Size.Y / 1.2
		local front = -head.Size.Z / 2 - 0.02
		-- Button eyes, a stitched mouth, a seam down the middle.
		for _, side in ipairs({ -1, 1 }) do
			deco(head, "Button", Vector3.new(0.26, 0.26, 0.06) * s, INK, CFrame.new(side * 0.24 * s, 0.1 * s, front))
			deco(head, "ButtonHole", Vector3.new(0.06, 0.06, 0.04) * s, BURLAP, CFrame.new(side * 0.24 * s, 0.1 * s, front - 0.04 * s))
		end
		deco(head, "Mouth", Vector3.new(0.6, 0.05, 0.04) * s, INK, CFrame.new(0, -0.26 * s, front))
		for i = -2, 2 do
			deco(head, "Stitch", Vector3.new(0.04, 0.16, 0.04) * s, INK, CFrame.new(i * 0.12 * s, -0.26 * s, front - 0.01 * s))
		end
		deco(head, "Seam", Vector3.new(0.05, head.Size.Y + 0.02, 0.05), BURLAP_DARK, CFrame.new(0, 0, front + 0.01))
		-- Straw sticking out of the top.
		for i = 0, 6 do
			local a = i / 7 * math.pi * 2
			deco(head, "Straw", Vector3.new(0.08, 0.6, 0.08) * s, STRAW, CFrame.new(math.cos(a) * 0.25 * s, head.Size.Y / 2 + 0.15 * s, math.sin(a) * 0.25 * s) * CFrame.Angles(math.sin(a) * 0.6, 0, -math.cos(a) * 0.6))
		end
		deco(head, "Tie", Vector3.new(0.5, 0.1, 0.5) * s, ROPE, CFrame.new(0, head.Size.Y / 2 - 0.02, 0))
	end
	if torso then
		local z = -torso.Size.Z / 2 - 0.03
		-- Target on the chest.
		deco(torso, "Target", Vector3.new(1.3, 1.3, 0.05), RED, CFrame.new(0, 0.1, z))
		deco(torso, "Target", Vector3.new(0.95, 0.95, 0.05), WHITE, CFrame.new(0, 0.1, z - 0.01))
		deco(torso, "Target", Vector3.new(0.6, 0.6, 0.05), RED, CFrame.new(0, 0.1, z - 0.02))
		deco(torso, "Target", Vector3.new(0.25, 0.25, 0.05), WHITE, CFrame.new(0, 0.1, z - 0.03))
		deco(torso, "Patch", Vector3.new(0.5, 0.4, 0.05), BURLAP_DARK, CFrame.new(-0.55, -0.55, z) * CFrame.Angles(0, 0, 0.2))
	end
	local waist = lower or torso
	if waist then
		local y = lower and 0 or -torso.Size.Y / 2 + 0.1
		deco(waist, "Rope", Vector3.new(waist.Size.X + 0.12, 0.2, waist.Size.Z + 0.12), ROPE, CFrame.new(0, y, 0))
		deco(waist, "RopeKnot", Vector3.new(0.3, 0.45, 0.15), ROPE, CFrame.new(0.4, y - 0.15, -waist.Size.Z / 2 - 0.08))
	end
	-- Straw cuffs at the wrists, wooden pegs for feet.
	for _, name in ipairs({ "LeftHand", "RightHand", "Left Arm", "Right Arm" }) do
		local hand = dummy:FindFirstChild(name)
		if hand then
			deco(hand, "Straw", Vector3.new(hand.Size.X + 0.15, 0.2, hand.Size.Z + 0.15), STRAW, CFrame.new(0, hand.Size.Y / 2 - 0.05, 0))
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }) do
		local foot = dummy:FindFirstChild(name)
		if foot then
			deco(foot, "Peg", Vector3.new(foot.Size.X + 0.05, 0.35, foot.Size.Z + 0.05), WOOD, CFrame.new(0, -foot.Size.Y / 2 + 0.15, 0))
		end
	end
	for _, d in ipairs(dummy:GetChildren()) do
		if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end
end

local function spawnDummy(folder, cframe, index)
	local ok, dummy = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not dummy then
		warn("[TestDummies] could not create dummy:", dummy)
		return
	end
	dummy.Name = "SpinDummy" .. index
	dummy:PivotTo(cframe)
	pcall(dress, dummy)
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.DisplayName = "Training Dummy"
	humanoid.MaxHealth = 150
	humanoid.Health = 150
	dummy.Parent = folder
	humanoid.Died:Connect(function()
		task.wait(SpinConfig.Debug.DummyRespawnTime)
		dummy:Destroy()
		spawnDummy(folder, cframe, index)
	end)
end

function TestDummies.init()
	if not RunService:IsStudio() or not SpinConfig.Debug.SpawnTestDummies then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "SpinTestDummies"
	folder.Parent = workspace
	local base = findSpawn()
	for i = 1, SpinConfig.Debug.DummyCount do
		local offset = CFrame.new((i - (SpinConfig.Debug.DummyCount + 1) / 2) * 8, 3, -30 - i * 6)
		spawnDummy(folder, base * offset * CFrame.Angles(0, math.pi, 0), i)
	end
end

return TestDummies
end

-- ======================================================================
-- MODULE: TuskAct1
-- ======================================================================
__modules["TuskAct1"] = function()
--[[
	TuskAct1  (ServerScriptService.SpinServer.TuskActs.TuskAct1)

	Server logic for Tusk Act 1, "the beginning of Spin".
	  M1        NAIL COMBO: jab, nail strike, spinning nail assist, shock finisher
	  Ability 1 NAIL SHOT: one spinning nail
	  Ability 2 NAIL BARRAGE: five nails fanned out
	  Ability 3 SPINNING NAIL: hold to charge, release (golden-blue at full charge)
	  Ultimate  TUSK AWAKENING: armored cinematic burst, then evolves to Act 2
	            (in Menu mode: 20 s Awakened buff instead)

	Every number is in TuskConfig.Act1. All hits go through S.hit()
	(CombatAdapter), all timing and cooldowns live here on the server.
	Visual events are sent with S.fx(); clients choreograph them in
	SpinClient.TuskActVFX.Act1.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local Awakening = __require("TuskAwakening")
local Act1 = {}
local cfg = TuskConfig.Act1

local HAND_OFFSET = CFrame.new(0.9, 0.55, -1.5) -- right-hand fingertip area

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function nailDamage(state, base)
	return state.Awakened and base * cfg.Ultimate.DamageMultiplier or base
end

local function cooldown(state, base)
	return state.Awakened and base * cfg.Ultimate.CooldownMultiplier or base
end

---------------------------------------------------------------------------
-- M1: NAIL COMBO
---------------------------------------------------------------------------
function Act1.M1(S, player, state, aim)
	local m = cfg.M1
	if S.isBusy(state) or state.Charging then
		return
	end
	local now = os.clock()
	if now - state.LastM1 > m.ResetAfter then
		state.Combo = 0
	end
	local index = state.Combo + 1
	state.Combo = index >= 4 and 0 or index
	state.LastM1 = now
	S.lock(state, index == 4 and m.EndLag or m.Interval)

	local character, _, root = alive(S, player)
	local hit = m.Hits[index]
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("M1", { Character = character, Act = 1, Index = index })

	task.delay(m.Windup, function()
		-- Getting stunned during the wind-up cancels the hit (trades are fair).
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		if hit.Projectile then
			local p = hit.Projectile
			S.fireNail(player, state, {
				Origin = S.origin(char, r, HAND_OFFSET),
				Direction = direction,
				Speed = p.Speed,
				Radius = p.Radius,
				Range = p.Range,
				Style = "M1",
				OnHit = function(target, position)
					S.hit(player, target, {
						Damage = hit.Damage,
						Stun = hit.Stun,
						Knockback = hit.Knockback,
						Direction = direction,
						Position = position,
						Source = "TuskM1",
					})
				end,
			})
			return
		end

		local boxCF = r.CFrame * CFrame.new(0, 0, -m.HitboxForward)
		local targets = S.Hitbox.inBox(char, boxCF, m.HitboxSize, m.MaxTargets)
		local landed = false
		for _, target in ipairs(targets) do
			local targetRoot = target:FindFirstChild("HumanoidRootPart")
			if targetRoot and S.Hitbox.lineOfSight(r.Position, targetRoot.Position, { char, target }) then
				local ok = S.hit(player, target, {
					Damage = hit.Damage,
					Stun = hit.Stun,
					Knockback = hit.Knockback,
					Launch = hit.Launch,
					Direction = targetRoot.Position - r.Position,
					Position = targetRoot.Position,
					Source = "TuskM1",
				})
				landed = landed or ok
			end
		end
		if index == 4 then
			S.fx("M1Finisher", { Character = char, Act = 1, Position = boxCF.Position, Radius = hit.ShockwaveRadius, Hit = landed })
		end
	end)
end

---------------------------------------------------------------------------
-- Abilities
---------------------------------------------------------------------------
local function nailShot(S, player, state, aim)
	local c = cfg.NailShot
	if S.isBusy(state) or state.Charging or not S.cooldownReady(player, state, "NailShot", 1) then
		return
	end
	S.startCooldown(player, state, "NailShot", cooldown(state, c.Cooldown), 1)
	S.lock(state, c.Startup + 0.2)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 1, Move = "NailShot", Phase = "Startup", Direction = direction, Startup = c.Startup })

	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		S.fireNail(player, state, {
			Origin = S.origin(char, r, HAND_OFFSET),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Shot",
			OnHit = function(target, position)
				S.hit(player, target, {
					Damage = nailDamage(state, c.Damage),
					Stun = c.Stun,
					Knockback = c.Knockback,
					Direction = direction,
					Position = position,
					Source = "TuskNailShot",
				})
			end,
		})
	end)
end

-- Fixed fan pattern (not random) so the barrage is readable and dodgeable.
local BARRAGE_PATTERN = { { 0, 0 }, { -1, 0.3 }, { 1, -0.2 }, { -0.5, -0.4 }, { 0.6, 0.5 }, { 0, 0.2 }, { -1, -0.3 } }

local function nailBarrage(S, player, state, aim)
	local c = cfg.NailBarrage
	if S.isBusy(state) or state.Charging or not S.cooldownReady(player, state, "NailBarrage", 2) then
		return
	end
	S.startCooldown(player, state, "NailBarrage", cooldown(state, c.Cooldown), 2)
	S.lock(state, c.Startup + c.Count * c.Interval + 0.15)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 1, Move = "NailBarrage", Phase = "Startup", Direction = direction, Startup = c.Startup, Count = c.Count, Interval = c.Interval })

	for i = 1, c.Count do
		task.delay(c.Startup + (i - 1) * c.Interval, function()
			if not S.stillValid(player, state, life) then
				return
			end
			local char, _, r = alive(S, player)
			local pattern = BARRAGE_PATTERN[(i - 1) % #BARRAGE_PATTERN + 1]
			local spread = math.rad(c.SpreadDegrees)
			local look = CFrame.lookAt(Vector3.new(), direction)
			local dir = (look * CFrame.Angles(pattern[2] * spread * 0.5, pattern[1] * spread, 0)).LookVector
			S.fireNail(player, state, {
				Origin = S.origin(char, r, HAND_OFFSET),
				Direction = dir,
				Speed = c.Speed,
				Radius = c.Radius,
				Range = c.Range,
				Style = "Barrage",
				OnHit = function(target, position)
					S.hit(player, target, {
						Damage = nailDamage(state, c.Damage),
						Stun = c.Stun,
						Knockback = c.Knockback,
						Direction = dir,
						Position = position,
						Source = "TuskNailBarrage",
					})
				end,
			})
		end)
	end
end

local function spinningNailRelease(S, player, state, aim)
	local c = cfg.SpinningNail
	local charge = S.endCharge(player, state)
	if not charge or charge.Move ~= "SpinningNail" then
		return
	end
	local character, _, root = alive(S, player)
	if not character then
		return
	end
	local t = math.clamp((os.clock() - charge.Start) / c.FullChargeAt, 0, 1)
	local full = t >= 1
	local direction = S.aim(aim, root)
	local function lerp(a, b)
		return a + (b - a) * t
	end
	S.startCooldown(player, state, "SpinningNail", cooldown(state, c.Cooldown), 3)
	S.lock(state, 0.3)
	S.fx("Ability", { Character = character, Act = 1, Move = "SpinningNail", Phase = "Release", Charge = t, Full = full, Direction = direction })
	S.fireNail(player, state, {
		Origin = S.origin(character, root, HAND_OFFSET),
		Direction = direction,
		Speed = lerp(c.MinSpeed, c.MaxSpeed),
		Radius = lerp(c.MinRadius, c.MaxRadius),
		Range = c.Range,
		Style = "Spinning",
		Charge = t,
		OnHit = function(target, position)
			S.hit(player, target, {
				Damage = nailDamage(state, lerp(c.MinDamage, c.MaxDamage)),
				Stun = c.Stun * (0.5 + t * 0.5),
				Knockback = c.Knockback * (0.4 + t * 0.6),
				Direction = direction,
				Position = position,
				Source = "TuskSpinningNail",
			})
		end,
	})
end

local function spinningNailPress(S, player, state)
	local c = cfg.SpinningNail
	if S.isBusy(state) or state.Charging or not S.cooldownReady(player, state, "SpinningNail", 3) then
		return
	end
	local charge = S.beginCharge(player, state, "SpinningNail", 3, c.WalkSpeedMultiplier)
	local token = charge.Token
	task.delay(c.MaxHold, function()
		if state.Charging and state.Charging.Token == token then
			spinningNailRelease(S, player, state, nil) -- auto-release forward
		end
	end)
end

function Act1.Ability(S, player, state, slot, phase, aim)
	if slot == 1 and phase == "Press" then
		nailShot(S, player, state, aim)
	elseif slot == 2 and phase == "Press" then
		nailBarrage(S, player, state, aim)
	elseif slot == 3 then
		if phase == "Press" then
			spinningNailPress(S, player, state)
		else
			spinningNailRelease(S, player, state, aim)
		end
	end
end

function Act1.CancelCharge(S, player, state)
	local charge = S.endCharge(player, state)
	if charge then
		S.startCooldown(player, state, charge.Move, 1.5, charge.Slot)
		S.fx("Ability", { Character = state.Character, Act = 1, Move = charge.Move, Phase = "Cancel" })
	end
end

---------------------------------------------------------------------------
-- Ultimate: TUSK AWAKENING
---------------------------------------------------------------------------
local function endAwakening(S, player, state)
	state.Awakened = false
	state.AwakenToken = nil
	if state.Character then
		state.Character:SetAttribute("TuskAwakened", nil)
	end
	S.tell(player, "AwakenEnded", {})
end

-- G: AWAKENING. Infinite Rotation (TuskAwakening), then Tusk awakens to Act 2.
function Act1.Ultimate(S, player, state, aim)
	return Awakening.use(S, player, state, aim)
end

function Act1.Cleanup(S, player, state)
	if state.Charging then
		S.endCharge(player, state)
	end
	if state.Awakened then
		endAwakening(S, player, state)
	end
end

return Act1
end

-- ======================================================================
-- MODULE: TuskAct2
-- ======================================================================
__modules["TuskAct2"] = function()
--[[
	TuskAct2  (ServerScriptService.SpinServer.TuskActs.TuskAct2)

	Tusk Act 2: wormhole combat.
	  M1        DIMENSIONAL COMBO: Tusk-assisted hits, portal flashes, dimensional finisher
	  Ability 1 WORMHOLE NAIL: nail opens a wormhole where it lands; a second nail
	            bursts out of an exit portal behind the nearest enemy
	  Ability 2 UNDERGROUND PURSUIT: burrow, travel under the ground, emerge behind the target
	  Ability 3 NAIL DIMENSION: three portals around the target fire converging nails,
	            then a dimensional shockwave
	  Ultimate  DIMENSIONAL STORM: six portals rain nail waves, giant blue burst,
	            then Tusk evolves to Act 3
	Numbers: TuskConfig.Act2.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")
local Awakening = __require("TuskAwakening")
local Sneak = __require("TuskSneakService")

local Act2 = {}
local cfg = TuskConfig.Act2

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Act2.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 2)
end

local function wormholeNail(S, player, state, aim)
	local c = cfg.WormholeNail
	if not ready(S, player, state, "WormholeNail", 1) then
		return
	end
	S.startCooldown(player, state, "WormholeNail", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.2)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 2, Move = "WormholeNail", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		Moves.nail(S, player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Wormhole",
			Damage = c.Damage,
			Stun = c.Stun,
			Knockback = c.Knockback,
			Source = "TuskWormholeNail",
			OnEnd = function(position, normal)
				-- Entrance wormhole where the nail landed.
				S.fx("Portal", { Act = 2, Position = position + normal * 0.5, LookAt = position + normal * 5, Radius = 2.4, Duration = c.ExitDelay + 0.35 })
				-- Exit portal behind the nearest enemy near the impact.
				local victims = S.Hitbox.inRadius(char, position, c.ExitSearch, 1)
				local victim = victims[1]
				local vr = victim and victim:FindFirstChild("HumanoidRootPart")
				if not vr then
					return
				end
				local exitPos = (vr.CFrame * CFrame.new(0, 1.5, 6)).Position
				if not S.Hitbox.lineOfSight(vr.Position, exitPos, { char, victim }) then
					exitPos = vr.Position + Vector3.new(0, 7, 0)
				end
				S.fx("Portal", { Act = 2, Position = exitPos, LookAt = vr.Position, Radius = 2.2, Duration = c.ExitDelay + 0.45 })
				task.delay(c.ExitDelay, function()
					if state.Life ~= life or not vr.Parent then
						return
					end
					local dir = (vr.Position - exitPos)
					if dir.Magnitude < 0.5 then
						return
					end
					Moves.nail(S, player, state, {
						Origin = exitPos,
						Direction = dir.Unit,
						Speed = c.Speed,
						Radius = c.Radius,
						Range = dir.Magnitude + 6,
						Style = "Wormhole",
						Damage = c.ExitDamage,
						Stun = c.Stun,
						Knockback = c.Knockback,
						Source = "TuskWormholeNail",
					})
				end)
			end,
		})
	end)
end

local function undergroundPursuit(S, player, state, aim)
	local c = cfg.UndergroundPursuit
	if not ready(S, player, state, "UndergroundPursuit", 2) then
		return
	end
	local character, _, root = alive(S, player)
	local target = Moves.findTarget(S, character, root, c.Range, c.ConeDegrees, S.aim(aim, root))
	if not target then
		S.startCooldown(player, state, "UndergroundPursuit", 1.5, 2)
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	S.startCooldown(player, state, "UndergroundPursuit", c.Cooldown, 2)
	Sneak.burrowStrike(player, state, target, {
		Range = c.Range,
		BurrowTime = c.BurrowTime,
		WarningTime = c.WarningTime,
		EmergeDistance = 3.5,
		MaxTargetDrift = 16,
		HitRadius = c.HitRadius,
		Damage = c.Damage,
		Stun = c.Stun,
		Knockback = c.Knockback,
		Launch = c.Launch,
	}, "TuskUndergroundPursuit")
end

-- Portals around a point fire converging nails, then a shockwave.
local function nailDimension(S, player, state, aim)
	local c = cfg.NailDimension
	if not ready(S, player, state, "NailDimension", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local target = Moves.findTarget(S, character, root, c.Range, c.ConeDegrees, direction)
	local center
	if target then
		center = target.HumanoidRootPart.Position
	else
		center = Moves.groundBelow(root.Position + Moves.flat(direction) * 35, { character }) + Vector3.new(0, 3, 0)
	end
	S.startCooldown(player, state, "NailDimension", c.Cooldown, 3)
	S.lock(state, 0.6)
	local yaw = math.atan2(direction.Z, direction.X)
	local portals = Moves.ring(center, c.Portals, c.PortalRadius, yaw, 4, 8)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 2, Move = "NailDimension", Phase = "Open", Portals = portals, Center = center, OpenTime = c.OpenTime })
	task.delay(c.OpenTime, function()
		if state.Life ~= life then
			return
		end
		local aimAt = (target and target.Parent and target:FindFirstChild("HumanoidRootPart")) and target.HumanoidRootPart.Position or center
		for _, pos in ipairs(portals) do
			local dir = aimAt - pos
			Moves.nail(S, player, state, {
				Origin = pos,
				Direction = dir.Unit,
				Speed = c.Speed,
				Radius = 0.8,
				Range = dir.Magnitude + 8,
				Style = "Portal",
				Damage = c.Damage,
				Stun = c.Stun,
				Knockback = c.Knockback,
				Source = "TuskNailDimension",
			})
		end
		local travel = (portals[1] - aimAt).Magnitude / c.Speed
		task.delay(travel + 0.05, function()
			if state.Life ~= life then
				return
			end
			Moves.aoe(S, player, aimAt, c.FinalRadius, { Damage = c.FinalDamage, Stun = 0.3, Knockback = 20, Launch = 12, Source = "TuskNailDimension" }, 5)
			S.fx("AbilityImpact", { Act = 2, Move = "NailDimension", Position = aimAt, Radius = c.FinalRadius })
		end)
	end)
end

function Act2.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		wormholeNail(S, player, state, aim)
	elseif slot == 2 then
		undergroundPursuit(S, player, state, aim)
	elseif slot == 3 then
		nailDimension(S, player, state, aim)
	end
end

-- DIMENSIONAL STORM
-- G: AWAKENING. Infinite Rotation (TuskAwakening), then Tusk awakens to Act 3.
function Act2.Ultimate(S, player, state, aim)
	return Awakening.use(S, player, state, aim)
end

function Act2.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
	end
end

return Act2
end

-- ======================================================================
-- MODULE: TuskAct3
-- ======================================================================
__modules["TuskAct3"] = function()
--[[
	TuskAct3  (ServerScriptService.SpinServer.TuskActs.TuskAct3)

	Tusk Act 3: master of spatial movement.
	  M1        WORMHOLE STRIKES: fast combo with portal flashes, portal uppercut finisher
	  Ability 1 DIMENSIONAL STEP: short validated portal teleport (entrance + exit portals)
	  Ability 2 SPATIAL PURSUIT: four portals around the target fire nails one after
	            another, each re-aimed at where the target is now
	  Ability 3 DIMENSIONAL BREAK: energy gathers, a large portal opens, a long
	            dimensional shockwave tears forward
	  Ultimate  INFINITE DIMENSION: layered portals around the battlefield, a giant
	            dimensional collapse, then Tusk evolves to Act 4
	Numbers: TuskConfig.Act3.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")
local Awakening = __require("TuskAwakening")

local Act3 = {}
local cfg = TuskConfig.Act3

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Act3.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 3)
end

local function dimensionalStep(S, player, state, aim)
	local c = cfg.DimensionalStep
	if not ready(S, player, state, "DimensionalStep", 1) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local destination = Moves.safeStep(character, root, direction, c.Distance)
	if not destination then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "DimensionalStep", c.Cooldown, 1)
	S.lock(state, 0.25)
	local from = root.Position
	character:SetAttribute(S.Adapter.Settings.IFrameAttribute, true)
	character:PivotTo(CFrame.lookAt(destination, destination + direction))
	S.fx("Ability", { Character = character, Act = 3, Move = "DimensionalStep", From = from, To = destination, Direction = direction })
	task.delay(c.IFrames, function()
		if character.Parent then
			character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
		end
	end)
end

local function spatialPursuit(S, player, state, aim)
	local c = cfg.SpatialPursuit
	if not ready(S, player, state, "SpatialPursuit", 2) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local target = Moves.findTarget(S, character, root, c.Range, c.ConeDegrees, direction)
	if not target then
		S.startCooldown(player, state, "SpatialPursuit", 1.5, 2)
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	S.startCooldown(player, state, "SpatialPursuit", c.Cooldown, 2)
	S.lock(state, 0.5)
	local tr = target.HumanoidRootPart
	local portals = Moves.ring(tr.Position, c.Portals, c.PortalRadius, math.random() * math.pi * 2, 3, 7)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 3, Move = "SpatialPursuit", Phase = "Open", Portals = portals, Target = target, OpenTime = c.OpenTime, Stagger = c.Stagger })
	for i, pos in ipairs(portals) do
		task.delay(c.OpenTime + (i - 1) * c.Stagger, function()
			if state.Life ~= life or not tr.Parent then
				return
			end
			local dir = tr.Position - pos -- re-aimed at the target's current position
			Moves.nail(S, player, state, {
				Origin = pos,
				Direction = dir.Unit,
				Speed = c.Speed,
				Radius = 0.8,
				Range = dir.Magnitude + 10,
				Style = "Portal",
				Damage = c.Damage,
				Stun = c.Stun,
				Knockback = c.Knockback,
				Source = "TuskSpatialPursuit",
			})
		end)
	end
end

local function dimensionalBreak(S, player, state, aim)
	local c = cfg.DimensionalBreak
	if not ready(S, player, state, "DimensionalBreak", 3) then
		return
	end
	S.startCooldown(player, state, "DimensionalBreak", c.Cooldown, 3)
	S.lock(state, c.Charge + 0.5)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 3, Move = "DimensionalBreak", Phase = "Charge", Charge = c.Charge, Direction = direction })
	task.delay(c.Charge, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local _, _, r = alive(S, player)
		local origin = r.Position
		local cf = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -(c.Length / 2 + 1))
		Moves.boxHit(S, player, cf, Vector3.new(c.Width, 9, c.Length), { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = direction, Source = "TuskDimensionalBreak" }, 6)
		S.fx("Ability", { Character = character, Act = 3, Move = "DimensionalBreak", Phase = "Release", Origin = origin, Direction = direction, Length = c.Length, Width = c.Width })
	end)
end

function Act3.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		dimensionalStep(S, player, state, aim)
	elseif slot == 2 then
		spatialPursuit(S, player, state, aim)
	elseif slot == 3 then
		dimensionalBreak(S, player, state, aim)
	end
end

-- INFINITE DIMENSION
-- G: AWAKENING. Infinite Rotation (TuskAwakening), then Tusk awakens to Act 4.
function Act3.Ultimate(S, player, state, aim)
	return Awakening.use(S, player, state, aim)
end

function Act3.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
	end
end

return Act3
end

-- ======================================================================
-- MODULE: TuskAct4
-- ======================================================================
__modules["TuskAct4"] = function()
--[[
	TuskAct4  (ServerScriptService.SpinServer.TuskActs.TuskAct4)

	Tusk Act 4: Infinite Rotation. Gold and deep blue, heavy and majestic.
	  M1        INFINITE BARRAGE: heavy punch, golden spin strike, rapid Stand
	            triple-hit, massive golden rotational finisher (area)
	  Ability 1 GOLDEN SPIN NAIL: big rotating projectile, golden impact blast
	  Ability 2 INFINITE ROTATION (hold): 3 charge stages, bigger projectile and
	            blast per stage
	  Ability 3 GOLDEN PURSUIT: golden rush to the first enemy ahead, rotational
	            strikes, huge golden shockwave
	  Ultimate  INFINITE ROTATION: 10-step cinematic, giant golden rotational
	            projectile, battlefield-wide golden shockwave (final form)
	Numbers: TuskConfig.Act4.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Act4 = {}
local cfg = TuskConfig.Act4

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Act4.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 4)
end

-- Projectile with an area blast where it lands (direct target excluded from the blast).
local function blastNail(S, player, state, spec, blastRadius, blastDamage, source)
	local directHit = {}
	local base = spec.OnHit
	spec.OnEnd = function(position, _, hitCharacter)
		if hitCharacter then
			directHit[hitCharacter] = true
		end
		Moves.aoe(S, player, position, blastRadius, { Damage = blastDamage, Stun = 0.35, Knockback = 25, Launch = 10, Source = source }, 6, directHit)
	end
	return Moves.nail(S, player, state, spec), base
end

local function goldenSpinNail(S, player, state, aim)
	local c = cfg.GoldenSpinNail
	if not ready(S, player, state, "GoldenSpinNail", 1) then
		return
	end
	S.startCooldown(player, state, "GoldenSpinNail", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.25)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 4, Move = "GoldenSpinNail", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		blastNail(S, player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Golden",
			Damage = c.Damage,
			Stun = c.Stun,
			Knockback = c.Knockback,
			Source = "TuskGoldenSpinNail",
		}, c.ImpactRadius, c.ImpactDamage, "TuskGoldenSpinNail")
	end)
end

local function infiniteRotationRelease(S, player, state, aim)
	local c = cfg.InfiniteRotation
	local charge = S.endCharge(player, state)
	if not charge or charge.Move ~= "InfiniteRotation" then
		return
	end
	local character, _, root = alive(S, player)
	if not character then
		return
	end
	local held = os.clock() - charge.Start
	local stage = 1
	for i, t in ipairs(c.Stages) do
		if held >= t then
			stage = i
		end
	end
	local direction = S.aim(aim, root)
	S.startCooldown(player, state, "InfiniteRotation", c.Cooldown, 2)
	S.lock(state, 0.4)
	S.fx("Ability", { Character = character, Act = 4, Move = "InfiniteRotation", Phase = "Release", Stage = stage, Direction = direction })
	blastNail(S, player, state, {
		Origin = S.origin(character, root, CFrame.new(0, 1.2, -2.5)),
		Direction = direction,
		Speed = c.Speed[stage],
		Radius = c.Radius[stage],
		Range = c.Range,
		Style = "Rotation",
		Charge = stage / 3,
		Damage = c.Damage[stage],
		Stun = c.Stun,
		Knockback = c.Knockback * (0.5 + stage / 6),
		Source = "TuskInfiniteRotation",
	}, c.ImpactRadius[stage], c.ImpactDamage[stage], "TuskInfiniteRotation")
end

local function infiniteRotationPress(S, player, state)
	local c = cfg.InfiniteRotation
	if not ready(S, player, state, "InfiniteRotation", 2) then
		return
	end
	local charge = S.beginCharge(player, state, "InfiniteRotation", 2, c.WalkSpeedMultiplier)
	local token = charge.Token
	task.delay(c.MaxHold, function()
		if state.Charging and state.Charging.Token == token then
			infiniteRotationRelease(S, player, state, nil)
		end
	end)
end

local function goldenPursuit(S, player, state, aim)
	local c = cfg.GoldenPursuit
	if not ready(S, player, state, "GoldenPursuit", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	-- Stop just short of the first enemy along the rush line.
	local distance = c.Distance
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, c.Distance + 4, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			local offset = tr.Position - root.Position
			local along = offset:Dot(direction)
			local side = (offset - direction * along).Magnitude
			if along > 0 and side < 5 and along - 3 < distance then
				distance = math.max(along - 3, 3)
			end
		end
	end
	local destination = Moves.safeStep(character, root, direction, distance)
	if not destination then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "GoldenPursuit", c.Cooldown, 3)
	local gather = 0.2
	S.lock(state, gather + c.Hits * c.HitInterval + 0.45)
	local life = state.Life
	local from = root.Position
	S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Gather", Direction = direction })
	task.delay(gather, function()
		if not S.stillValid(player, state, life) then
			return
		end
		character:SetAttribute(S.Adapter.Settings.IFrameAttribute, true)
		character:PivotTo(CFrame.lookAt(destination, destination + direction))
		S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Dash", From = from, To = destination })
		task.delay(0.15, function()
			if character.Parent then
				character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
			end
		end)
		local front = destination + direction * 3
		for i = 1, c.Hits do
			task.delay(i * c.HitInterval, function()
				if state.Life ~= life then
					return
				end
				Moves.aoe(S, player, front, 6, { Damage = c.HitDamage, Stun = 0.4, Knockback = 3, Direction = direction, Source = "TuskGoldenPursuit" }, 3)
				S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Hit", Position = front, Index = i })
			end)
		end
		task.delay((c.Hits + 1) * c.HitInterval, function()
			if state.Life ~= life then
				return
			end
			Moves.aoe(S, player, front, c.FinalRadius, { Damage = c.FinalDamage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = direction, Source = "TuskGoldenPursuit" }, 6)
			S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Final", Position = front, Radius = c.FinalRadius })
		end)
	end)
end

function Act4.Ability(S, player, state, slot, phase, aim)
	if slot == 1 and phase == "Press" then
		goldenSpinNail(S, player, state, aim)
	elseif slot == 2 then
		if phase == "Press" then
			infiniteRotationPress(S, player, state)
		else
			infiniteRotationRelease(S, player, state, aim)
		end
	elseif slot == 3 and phase == "Press" then
		goldenPursuit(S, player, state, aim)
	end
end

function Act4.CancelCharge(S, player, state)
	local charge = S.endCharge(player, state)
	if charge then
		S.startCooldown(player, state, charge.Move, 2, charge.Slot)
		S.fx("Ability", { Character = state.Character, Act = 4, Move = charge.Move, Phase = "Cancel" })
	end
end

-- INFINITE ROTATION (ultimate)
function Act4.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.lock(state, u.Windup + 0.6)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = 4, Phase = "Start", Windup = u.Windup, Direction = direction })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local _, _, r = alive(S, player)
		S.fx("Ultimate", { Character = character, Act = 4, Phase = "Release", Position = r.Position, Direction = direction })
		blastNail(S, player, state, {
			Origin = S.origin(character, r, CFrame.new(0, 2, -4)),
			Direction = direction,
			Speed = u.Speed,
			Radius = u.ProjectileRadius,
			Range = u.Range,
			Style = "InfiniteUlt",
			Charge = 1,
			Damage = u.Damage,
			Stun = u.Stun,
			Knockback = u.Knockback,
			Launch = u.Launch,
			Source = "TuskInfiniteRotationUlt",
		}, u.BlastRadius, u.BlastDamage, "TuskInfiniteRotationUlt")
		S.finishUltimate(player, state) -- final form: no evolution (Studio refills the meter)
	end)
end

function Act4.Cleanup(S, player, state)
	if state.Charging then
		S.endCharge(player, state)
	end
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
	end
end

return Act4
end

-- ======================================================================
-- MODULE: TuskActRegistry
-- ======================================================================
__modules["TuskActRegistry"] = function()
--[[
	TuskActRegistry  (ReplicatedStorage.SpinShared.TuskActRegistry)

	The list of Tusk Acts: names, slot labels, themes and whether each
	Act is implemented. The server refuses to equip an Act whose
	Implemented flag is false, and the menu shows it as IN DEVELOPMENT
	(locked, not a fake button).

	To add an Act: create ServerScriptService.SpinServer.TuskActs.TuskActN,
	add its client choreography in SpinClient.TuskActVFX.ActN, then set
	Implemented = true here.
]]

local TuskActRegistry = {}

TuskActRegistry.Acts = {
	[1] = {
		Name = "TUSK ACT 1",
		Tagline = "The beginning of Spin",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(90, 230, 255), Secondary = Color3.fromRGB(40, 120, 255) },
		M1 = "NAIL COMBO",
		Abilities = { "NAIL SHOT", "NAIL BARRAGE", "SPINNING NAIL" },
		AbilityKinds = { "Press", "Press", "Hold" }, -- Hold = charge on press, fire on release
		Ultimate = "AWAKEN: INFINITE ROTATION",
		Next = 2, -- the ultimate awakens Tusk to this Act
	},
	[2] = {
		Name = "TUSK ACT 2",
		Tagline = "The Golden Ratio",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(70, 200, 255), Secondary = Color3.fromRGB(30, 80, 220) },
		M1 = "GOLDEN COMBO",
		Abilities = { "GOLDEN RATIO NAIL", "UNDERGROUND PURSUIT", "GOLDEN SPIRAL" },
		AbilityKinds = { "Press", "Press", "Press" },
		Next = 3,
		Ultimate = "AWAKEN: INFINITE ROTATION",
	},
	[3] = {
		Name = "TUSK ACT 3",
		Tagline = "Master of spatial movement",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(60, 140, 255), Secondary = Color3.fromRGB(20, 40, 160) },
		M1 = "WORMHOLE STRIKES",
		Abilities = { "DIMENSIONAL STEP", "SPATIAL PURSUIT", "DIMENSIONAL BREAK" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "AWAKEN: INFINITE ROTATION",
		Next = 4,
	},
	[4] = {
		Name = "TUSK ACT 4",
		Tagline = "Infinite Rotation",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(255, 200, 70), Secondary = Color3.fromRGB(20, 40, 160) },
		M1 = "INFINITE BARRAGE",
		Abilities = { "GOLDEN SPIN NAIL", "INFINITE ROTATION", "GOLDEN PURSUIT" },
		AbilityKinds = { "Press", "Hold", "Press" },
		Ultimate = "INFINITE ROTATION",
		Next = nil, -- final form
	},
	-- Gyro Zeppeli: a separate character that reuses the same ability system.
	[5] = {
		Name = "GYRO ZEPPELI",
		Character = "Gyro",
		Tagline = "Steel Ball master",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(120, 220, 95), Secondary = Color3.fromRGB(40, 120, 50) },
		M1 = "STEEL BALL COMBO",
		Abilities = { "STEEL BALL THROW", "SPIN TORNADO", "SPIN VIBRATION" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "BALL BREAKER",
		Next = nil,
		Module = "GyroZeppeli", -- server moves
		ClientModule = "Gyro", -- client visuals (TuskActVFX.Gyro)
		CardTitle = "STAND  ·  BALL BREAKER",
	},
	-- Diego Brando: Scary Monsters (dinosaur Stand). Same ability system.
	[6] = {
		Name = "SCARY MONSTERS",
		Character = "Diego",
		Tagline = "Dinosaur Stand",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(80, 210, 220), Secondary = Color3.fromRGB(35, 60, 190) },
		M1 = "CLAW COMBO",
		Abilities = { "RAPTOR POUNCE", "DINO INFECTION", "SCARY MONSTERS" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "RAPTOR PACK",
		Next = nil,
		Module = "DiegoBrando", -- server moves
		ClientModule = "Diego", -- client visuals (TuskActVFX.Diego)
		CardTitle = "STAND  ·  SCARY MONSTERS",
		-- The HUD shows a timer on these slots while the attribute (server time) is in the future.
		Buffs = {
			{ Slot = 3, Attribute = "DinoModeUntil", Text = "ACTIVE" },
			{ Slot = 2, Attribute = "ThrallUntil", Text = "COMMAND" },
		},
	},
	-- Pork Pie Hat Kid: WIRED (fish hooks and steel cables from a winch in his mouth).
	[7] = {
		Name = "WIRED",
		Character = "PorkPie",
		Tagline = "Hooks from the water",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(165, 215, 80), Secondary = Color3.fromRGB(95, 105, 125) },
		M1 = "HOOK COMBO",
		Abilities = { "WIRED HOOK", "BAIT PAN", "DOUBLE HOOK LIFT" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "WIRED WINCH",
		Next = nil,
		Module = "PorkPieHatKid", -- server moves
		ClientModule = "PorkPie", -- client visuals (TuskActVFX.PorkPie)
		CardTitle = "STAND  ·  WIRED",
		Buffs = {
			{ Slot = 2, Attribute = "BaitPanUntil", Text = "BAITED" },
		},
	},
	-- Sandman (Soundman): IN A SILENT WAY (sounds written as solid words that
	-- cut, burn and explode when touched).
	[8] = {
		Name = "IN A SILENT WAY",
		Character = "Sandman",
		Tagline = "Sounds made solid",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(245, 185, 80), Secondary = Color3.fromRGB(50, 140, 160) },
		M1 = "SOUND CUT COMBO",
		Abilities = { "SOUND SLASH", "SOUND TRAP", "SAND RUN" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "SILENT SYMPHONY",
		Next = nil,
		Module = "Sandman", -- server moves
		WalkSpeed = 1.25, -- he's a runner: 25% faster than everyone else
		ClientModule = "SandmanVFX", -- client visuals (TuskActVFX.SandmanVFX)
		CardTitle = "STAND  ·  IN A SILENT WAY",
	},
	-- Mountain Tim: OH! LONESOME ME (splits his body into pieces that slide
	-- along his lasso rope).
	[9] = {
		Name = "OH! LONESOME ME",
		Character = "MountainTim",
		Tagline = "Split along the rope",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(214, 156, 84), Secondary = Color3.fromRGB(96, 62, 38) },
		M1 = "LASSO COMBO",
		Abilities = { "LASSO SNARE", "SPLIT DODGE", "SPLIT BARRAGE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "LONESOME ROUNDUP",
		Next = nil,
		Module = "MountainTim", -- server moves
		ClientModule = "MountainTimVFX", -- client visuals (TuskActVFX.MountainTimVFX)
		CardTitle = "STAND  ·  OH! LONESOME ME",
	},
	-- Hot Pants: CREAM STARTER (a spray can that sprays flesh: seals wounds,
	-- coats and smothers enemies).
	[10] = {
		Name = "CREAM STARTER",
		Character = "HotPants",
		Tagline = "Flesh spray",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(242, 140, 172), Secondary = Color3.fromRGB(120, 60, 92) },
		M1 = "SPRAY COMBO",
		Abilities = { "FLESH SPRAY", "FLESH SEAL", "FLESH MEND" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "FLESH STORM",
		Next = nil,
		Module = "HotPants", -- server moves
		ClientModule = "HotPantsVFX", -- client visuals (TuskActVFX.HotPantsVFX)
		CardTitle = "STAND  ·  CREAM STARTER",
		Buffs = {
			{ Slot = 3, Attribute = "FleshMendUntil", Text = "HEALING" },
		},
	},
	-- Blackmore: CATCH THE RAINBOW (freezes raindrops in mid-air: cuts with
	-- them, walks on them, scatters into them).
	[11] = {
		Name = "CATCH THE RAINBOW",
		Character = "Blackmore",
		Tagline = "Raindrops frozen in the air",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(110, 180, 255), Secondary = Color3.fromRGB(40, 50, 90) },
		M1 = "RAINDROP COMBO",
		Abilities = { "RAINDROP BLADES", "RAINDROP STEP", "RAINDROP CAGE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "CATCH THE RAINBOW",
		Next = nil,
		Module = "Blackmore", -- server moves
		ClientModule = "BlackmoreVFX", -- client visuals (TuskActVFX.BlackmoreVFX)
		CardTitle = "STAND  ·  CATCH THE RAINBOW",
	},
	-- Axl RO: CIVIL WAR (makes a target's guilt real: specters and the things
	-- they abandoned rise up and engulf them in a crushing membrane; water,
	-- like the rain, washes it away).
	[12] = {
		Name = "CIVIL WAR",
		Character = "Axl",
		Tagline = "Guilt made real",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(214, 60, 70), Secondary = Color3.fromRGB(226, 196, 110) },
		M1 = "GUILT COMBO",
		Abilities = { "GUILT SPECTERS", "ABANDONED JUNK", "GUILT MEMBRANE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "CIVIL WAR",
		Next = nil,
		Module = "Axl", -- server moves
		ClientModule = "AxlVFX", -- client visuals (TuskActVFX.AxlVFX)
		CardTitle = "STAND  ·  CIVIL WAR",
		Passive = "GUILT: your hits mark them; your moves feed on it",
	},
	-- Funny Valentine: D4C (Dirty Deeds Done Dirt Cheap): slips between
	-- parallel worlds when sandwiched between things (a flag), brings
	-- people from other worlds, and Love Train turns misfortune away.
	[13] = {
		Name = "D4C",
		Character = "Valentine",
		Tagline = "Dirty Deeds Done Dirt Cheap",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(120, 170, 255), Secondary = Color3.fromRGB(236, 120, 170) },
		M1 = "DIRTY DEEDS COMBO",
		Abilities = { "DIMENSION HOP", "PARALLEL VALENTINE", "MENGER SPONGE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "D4C LOVE TRAIN",
		Next = nil,
		Module = "Valentine", -- server moves
		ClientModule = "ValentineVFX", -- client visuals (TuskActVFX.ValentineVFX)
		CardTitle = "STAND  ·  D4C",
		Buffs = {
			{ Slot = 2, Attribute = "ParallelCloneUntil", Text = "PARALLEL" },
		},
	},
	-- Diego Brando from another world (AU): THE WORLD (stops time).
	[14] = {
		Name = "THE WORLD",
		Character = "DiegoAU",
		Tagline = "Diego from another world",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(236, 196, 70), Secondary = Color3.fromRGB(70, 170, 160) },
		M1 = "MUDA COMBO",
		Abilities = { "STAND GRAB", "STAND BARRAGE", "KNIFE THROW" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "THE WORLD: TIME STOP",
		Next = nil,
		Module = "DiegoAU", -- server moves
		ClientModule = "DiegoAUVFX", -- client visuals (TuskActVFX.DiegoAUVFX)
		CardTitle = "STAND  ·  THE WORLD",
		Buffs = {
			{ Slot = 2, Attribute = "WorldBarrageUntil", Text = "MUDA" },
		},
	},
}

-- Which character an Act belongs to ("Johnny" for Tusk Acts 1-4).
function TuskActRegistry.characterOf(act)
	local info = TuskActRegistry.Acts[act]
	return info and info.Character or "Johnny"
end

-- The Act a character starts on.
TuskActRegistry.StartAct = { Johnny = 1, Gyro = 5, Diego = 6, PorkPie = 7, Sandman = 8, MountainTim = 9, HotPants = 10, Blackmore = 11, Axl = 12, Valentine = 13, DiegoAU = 14 }

function TuskActRegistry.get(act)
	return TuskActRegistry.Acts[act]
end

function TuskActRegistry.isImplemented(act)
	local info = TuskActRegistry.Acts[act]
	return info ~= nil and info.Implemented == true
end

return TuskActRegistry
end

-- ======================================================================
-- MODULE: TuskAwakening
-- ======================================================================
__modules["TuskAwakening"] = function()
--[[
	TuskAwakening  (ServerScriptService.SpinServer.TuskAwakening)

	Johnny's AWAKENING (G on Tusk Acts 1-3): INFINITE ROTATION. A golden
	spinning nail charged with the Golden Rotation fires (stronger each Act),
	blasts where it lands, and Tusk AWAKENS one Act higher (1 -> 2 -> 3 -> 4).
	Act 4's own ultimate is the full Infinite Rotation (TuskAct4).
	You can't pick your Act: awakening is the only way up, and dying sends
	you back to Act 1 (TuskConfig.Progression).
	Numbers: TuskConfig.Awakening (one value per Act 1-3).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local TuskAwakening = {}

local function pick(list, act)
	if type(list) ~= "table" then
		return list
	end
	return list[math.clamp(act, 1, #list)]
end

function TuskAwakening.use(S, player, state, aim)
	local cfg = TuskConfig.Awakening
	local act = state.Act or 1
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = S.Adapter.getAlive(player)
	local direction = S.aim(aim, root)
	local life = state.Life
	local windup = pick(cfg.Windup, act)
	S.lock(state, windup + 0.6)
	character:SetAttribute("Armored", true)
	-- The Infinite Rotation visuals (Act 4's), scaled by the Act.
	S.fx("Ultimate", { Character = character, Act = 4, Phase = "Start", Windup = windup, Direction = direction, Awakening = act })
	task.delay(windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not S.Adapter.getAlive(player) then
			return
		end
		local _, _, r = S.Adapter.getAlive(player)
		S.fx("Ultimate", { Character = character, Act = 4, Phase = "Release", Position = r.Position, Direction = direction, Awakening = act })
		local directHit = {}
		local blastRadius, blastDamage = pick(cfg.BlastRadius, act), pick(cfg.BlastDamage, act)
		Moves.nail(S, player, state, {
			Origin = S.origin(character, r, CFrame.new(0, 2, -4)),
			Direction = direction,
			Speed = cfg.Speed,
			Radius = pick(cfg.ProjectileRadius, act),
			Range = cfg.Range,
			Style = "InfiniteUlt",
			Charge = 1,
			Damage = pick(cfg.Damage, act),
			Stun = cfg.Stun,
			Knockback = cfg.Knockback,
			Launch = cfg.Launch,
			Source = "TuskAwakening",
			OnEnd = function(position, _, hitCharacter)
				if hitCharacter then
					directHit[hitCharacter] = true
				end
				Moves.aoe(S, player, position, blastRadius, { Damage = blastDamage, Stun = 0.4, Knockback = 30, Launch = 12, Source = "TuskAwakening" }, 6, directHit)
			end,
		})
		-- ...and Tusk awakens one Act higher.
		S.finishUltimate(player, state)
	end)
end

return TuskAwakening
end

-- ======================================================================
-- MODULE: TuskHitbox
-- ======================================================================
__modules["TuskHitbox"] = function()
--[[
	TuskHitbox  (ServerScriptService.SpinServer.TuskHitbox)
	Server-side spatial queries for melee and area attacks.
	Returns unique characters (models with a Humanoid), nearest first.
]]

local TuskHitbox = {}

local function characterFromPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end
TuskHitbox.characterFromPart = characterFromPart

local function collect(parts, attacker, origin, max)
	local seen, list = {}, {}
	for _, part in ipairs(parts) do
		local character = characterFromPart(part)
		if character and character ~= attacker and not seen[character] then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart")
			if humanoid and root and humanoid.Health > 0 then
				seen[character] = true
				table.insert(list, { Character = character, Distance = (root.Position - origin).Magnitude })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Distance < b.Distance
	end)
	local out = {}
	for i = 1, math.min(#list, max or #list) do
		out[i] = list[i].Character
	end
	return out
end

local function overlapParams(attacker)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = attacker and { attacker } or {}
	return params
end

function TuskHitbox.inBox(attacker, cframe, size, max)
	local parts = workspace:GetPartBoundsInBox(cframe, size, overlapParams(attacker))
	return collect(parts, attacker, cframe.Position, max)
end

function TuskHitbox.inRadius(attacker, position, radius, max)
	local parts = workspace:GetPartBoundsInRadius(position, radius, overlapParams(attacker))
	return collect(parts, attacker, position, max)
end

-- True if nothing but characters blocks the line between the two points.
function TuskHitbox.lineOfSight(fromPos, toPos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	params.IgnoreWater = true
	local offset = toPos - fromPos
	local result = workspace:Raycast(fromPos, offset, params)
	if not result then
		return true
	end
	return characterFromPart(result.Instance) ~= nil
end

return TuskHitbox
end

-- ======================================================================
-- MODULE: TuskMoves
-- ======================================================================
__modules["TuskMoves"] = function()
--[[
	TuskMoves  (ServerScriptService.SpinServer.TuskMoves)

	Shared server building blocks for every Tusk Act, so each Act module
	only describes what makes it different:
	  m1(...)          generic 4-hit combo (portals, multi-hits, AoE finisher, nail hits)
	  findTarget(...)  nearest valid enemy in a cone with line of sight
	  aoe(...)         radius hit with line-of-sight checks
	  boxHit(...)      oriented box hit
	  safeStep(...)    validated short teleport / dash destination
	  nail(...)        fire a nail with standard damage handling
	All damage still goes through TuskService.hit -> CombatAdapter.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local TuskMoves = {}
TuskMoves.HAND = CFrame.new(0.9, 0.55, -1.5)

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 1e-3 and f.Unit or Vector3.new(0, 0, -1)
end
TuskMoves.flat = flat

---------------------------------------------------------------------------
-- Targeting and area damage
---------------------------------------------------------------------------
function TuskMoves.findTarget(S, character, root, range, coneDegrees, direction)
	local look = flat(direction or root.CFrame.LookVector)
	local cosLimit = math.cos(math.rad((coneDegrees or 360) / 2))
	local best, bestDistance
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, range)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and S.Adapter.canBeHit(nil, target) then
			local offset = tr.Position - root.Position
			local f = Vector3.new(offset.X, 0, offset.Z)
			if f.Magnitude < 0.5 or f.Unit:Dot(look) >= cosLimit then
				if S.Hitbox.lineOfSight(root.Position, tr.Position, { character, target }) then
					if not bestDistance or offset.Magnitude < bestDistance then
						best, bestDistance = target, offset.Magnitude
					end
				end
			end
		end
	end
	return best
end

-- Damage everyone in a radius (line of sight from `center`). Returns hit count.
function TuskMoves.aoe(S, player, center, radius, info, maxTargets, exclude)
	local character = player.Character
	local count = 0
	for _, target in ipairs(S.Hitbox.inRadius(character, center, radius, maxTargets or 8)) do
		if not (exclude and exclude[target]) then
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.Hitbox.lineOfSight(center, tr.Position, { character, target }) then
				local hitInfo = table.clone(info)
				hitInfo.Direction = info.Direction or (tr.Position - center)
				hitInfo.Position = tr.Position
				if S.hit(player, target, hitInfo) then
					count = count + 1
				end
			end
		end
	end
	return count
end

function TuskMoves.boxHit(S, player, cframe, size, info, maxTargets)
	local character, _, root = alive(S, player)
	local count, hitSet = 0, {}
	if not character then
		return 0, hitSet
	end
	for _, target in ipairs(S.Hitbox.inBox(character, cframe, size, maxTargets or 3)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and S.Hitbox.lineOfSight(root.Position, tr.Position, { character, target }) then
			local hitInfo = table.clone(info)
			hitInfo.Direction = info.Direction or (tr.Position - root.Position)
			hitInfo.Position = tr.Position
			if S.hit(player, target, hitInfo) then
				count = count + 1
				hitSet[target] = true
			end
		end
	end
	return count, hitSet
end

---------------------------------------------------------------------------
-- Movement
---------------------------------------------------------------------------
-- Validated destination for a short teleport/dash along a flat direction.
-- Stops before walls, needs ground below, and free space to stand in.
function TuskMoves.safeStep(character, root, direction, distance)
	local dir = flat(direction)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild("SpinClientFX") }
	local wall = workspace:Raycast(root.Position, dir * distance, params)
	local travel = wall and (wall.Distance - 2.5) or distance
	if travel < 3 then
		return nil
	end
	local groundHere = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	local height = groundHere and (root.Position.Y - groundHere.Position.Y) or 3
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	-- Walk back from the furthest point until a valid spot is found.
	local d = travel
	while d >= 3 do
		local probe = root.Position + dir * d
		local ground = workspace:Raycast(probe + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), params)
		if ground then
			local stand = Vector3.new(probe.X, ground.Position.Y + height, probe.Z)
			local blocked = false
			for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(stand), Vector3.new(2, 4.5, 2), overlap)) do
				if part.CanCollide then
					blocked = true
					break
				end
			end
			if not blocked then
				return stand
			end
		end
		d = d - 2
	end
	return nil
end

function TuskMoves.groundBelow(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position or position
end

---------------------------------------------------------------------------
-- Nails
---------------------------------------------------------------------------
--[[ spec: Origin, Direction, Speed, Radius, Range, Style, Charge,
          Damage, Stun, Knockback, Launch, Source, OnEnd ]]
function TuskMoves.nail(S, player, state, spec)
	return S.fireNail(player, state, {
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius or 0.7,
		Range = spec.Range,
		Style = spec.Style,
		Charge = spec.Charge,
		OnHit = function(target, position)
			S.hit(player, target, {
				Damage = spec.Damage,
				Stun = spec.Stun,
				Knockback = spec.Knockback,
				Launch = spec.Launch,
				Direction = spec.Direction,
				Position = position,
				Source = spec.Source or "TuskNail",
			})
		end,
		OnEnd = spec.OnEnd,
	})
end

---------------------------------------------------------------------------
-- Generic M1 combo
---------------------------------------------------------------------------
--[[ m1cfg.Hits[i] fields: Damage, Stun, Knockback, Launch,
     Portal (cosmetic), Repeat + RepeatInterval (multi-hit), AoeRadius
     (finisher hits a radius instead of the box), ShockwaveRadius (visual),
     Projectile = { Speed, Radius, Range } (nail instead of melee) ]]
function TuskMoves.m1(S, player, state, aim, m1cfg, act)
	if S.isBusy(state) or state.Charging then
		return
	end
	local now = os.clock()
	if now - state.LastM1 > m1cfg.ResetAfter then
		state.Combo = 0
	end
	local index = state.Combo + 1
	state.Combo = index >= 4 and 0 or index
	state.LastM1 = now
	local hit = m1cfg.Hits[index]
	local repeatTime = (hit.Repeat or 1) > 1 and (hit.Repeat - 1) * (hit.RepeatInterval or 0.08) or 0
	S.lock(state, (index == 4 and m1cfg.EndLag or m1cfg.Interval) + repeatTime)
	state.M1LockUntil = state.LockUntil -- (a dash can cancel this recovery)

	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("M1", { Character = character, Act = act, Index = index, Portal = hit.Portal == true, Repeat = hit.Repeat })

	local function strike(isLast)
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		if hit.Projectile then
			TuskMoves.nail(S, player, state, {
				Origin = S.origin(char, r, TuskMoves.HAND),
				Direction = direction,
				Speed = hit.Projectile.Speed,
				Radius = hit.Projectile.Radius,
				Range = hit.Projectile.Range,
				Style = "M1",
				Damage = hit.Damage,
				Stun = hit.Stun,
				Knockback = hit.Knockback,
				Source = "TuskM1",
			})
			return
		end
		local boxCF = r.CFrame * CFrame.new(0, 0, -m1cfg.HitboxForward)
		local info = { Damage = hit.Damage, Stun = hit.Stun, Knockback = hit.Knockback, Launch = hit.Launch, Source = "TuskM1" }
		local landed
		if hit.AoeRadius and isLast then
			landed = TuskMoves.aoe(S, player, boxCF.Position, hit.AoeRadius, info, 5) > 0
		else
			landed = TuskMoves.boxHit(S, player, boxCF, m1cfg.HitboxSize, info, m1cfg.MaxTargets) > 0
		end
		if index == 4 and isLast then
			S.fx("M1Finisher", { Character = char, Act = act, Position = boxCF.Position, Radius = hit.ShockwaveRadius or 7, Hit = landed })
		end
	end

	local count = hit.Repeat or 1
	for i = 1, count do
		task.delay(m1cfg.Windup + (i - 1) * (hit.RepeatInterval or 0.08), function()
			strike(i == count)
		end)
	end
end

-- Ring of points around a center (portal placement shared by server and client payloads).
function TuskMoves.ring(center, count, radius, yaw, heightA, heightB)
	local points = {}
	for i = 1, count do
		local angle = (yaw or 0) + (i - 1) / count * math.pi * 2
		local h = (i % 2 == 0) and (heightB or 6) or (heightA or 4)
		table.insert(points, center + Vector3.new(math.cos(angle) * radius, h, math.sin(angle) * radius))
	end
	return points
end

TuskMoves.Config = TuskConfig
return TuskMoves
end

-- ======================================================================
-- MODULE: TuskService
-- ======================================================================
__modules["TuskService"] = function()
--[[
	TuskService  (ServerScriptService.SpinServer.TuskService)

	Server brain for Tusk (the "TuskController" of the design doc):
	  * equips / switches Acts (validated against TuskActRegistry and
	    TuskConfig.Progression)
	  * routes every TuskRequest to the active Act module or TuskSneakService
	  * owns per-player state, action locks, cooldowns, the ultimate meter
	  * gives Act modules safe helpers: hit(), fireNail(), aim(), origin()...

	Request protocol (client -> server, TuskRequest:FireServer):
	  "Select", act          equip Act n (0 = unequip)
	  "M1", aim              basic attack (sneak attack while sneaking)
	  "Ability", slot, phase, aim   slot 1..3, phase "Press" | "Release"
	  "Ultimate", aim
	  "Sneak", on

	Attributes it sets (replicated; clients render from them):
	  Player.TuskUlt (0..Max)  Character.TuskAct  Character.TuskCharge
	  Character.TuskAwakened   Character.Armored  (Sneak ones: see TuskSneakService)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local Net = __require("Net")
local Adapter = __require("CombatAdapter")
local Cooldowns = __require("CooldownService")
local Projectiles = __require("ProjectileService")
local Hitbox = __require("TuskHitbox")

local Request = Net.get("TuskRequest")
local FX = Net.get("TuskFX")

local TuskService = {}
TuskService.Hitbox = Hitbox
TuskService.Adapter = Adapter
TuskService.Projectiles = Projectiles

local states = {} -- [player] = state
TuskService.States = states -- (read-only use: who owns a character, e.g. NPC perfect dodges)
local rate = {}
local actModules = {}
local Defense -- DefenseService (block / dash), loaded in init
local Sneak -- set in init (circular dependency)

local RATE_LIMIT = 24 -- requests per second

---------------------------------------------------------------------------
-- Helpers for Act modules
---------------------------------------------------------------------------
function TuskService.getState(player)
	return states[player]
end

function TuskService.fx(name, data)
	FX:FireAllClients(name, data)
end

function TuskService.tell(player, kind, data)
	if typeof(player) ~= "Instance" then
		return -- a Stand-user NPC (StandBots): nobody to tell
	end
	data = data or {}
	data.Kind = kind
	FX:FireClient(player, "TuskState", data)
end

function TuskService.isBusy(state)
	return os.clock() < state.LockUntil
end

function TuskService.lock(state, seconds)
	state.LockUntil = math.max(state.LockUntil, os.clock() + seconds)
end

local function cooldownKey(state, name)
	return "Tusk" .. state.Act .. "_" .. name
end

-- Returns true if ready; otherwise tells the client how long is left.
function TuskService.cooldownReady(player, state, name, slot)
	local remaining = Cooldowns.remaining(player, cooldownKey(state, name))
	if remaining > 0 then
		TuskService.tell(player, "Denied", { Reason = "Cooldown", Slot = slot, Remaining = remaining })
		return false
	end
	return true
end

function TuskService.startCooldown(player, state, name, seconds, slot)
	-- Saint's Corpse (Eyes): abilities recharge faster.
	local character = player.Character
	seconds = seconds * (character and character:GetAttribute("CorpseCooldown") or 1)
	Cooldowns.start(player, cooldownKey(state, name), seconds)
	TuskService.tell(player, "Cooldown", { Slot = slot, Duration = seconds })
end

-- A token that changes on death / Act switch, so delayed actions can
-- check they still belong to the same "life".
function TuskService.stillValid(player, state, life, allowStunned)
	if states[player] ~= state or state.Life ~= life then
		return false
	end
	if allowStunned then
		return Adapter.getAlive(player) ~= nil
	end
	return Adapter.canAct(player)
end

function TuskService.aim(aim, root)
	local fallback = root.CFrame.LookVector
	if typeof(aim) ~= "Vector3" or aim ~= aim or aim.Magnitude < 1e-3 or aim.Magnitude > 1e4 then
		return fallback
	end
	if aim.X ~= aim.X or aim.Y ~= aim.Y or aim.Z ~= aim.Z then
		return fallback
	end
	local unit = aim.Unit
	local y = math.clamp(unit.Y, -0.8, 0.8)
	local flat = Vector3.new(unit.X, 0, unit.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(fallback.X, 0, fallback.Z)
	end
	flat = flat.Unit * math.sqrt(1 - y * y)
	return Vector3.new(flat.X, y, flat.Z).Unit
end

-- Spawn point for attacks, pulled back to the root if a wall is in the way.
function TuskService.origin(character, root, offset)
	local desired = (root.CFrame * offset).Position
	if Hitbox.lineOfSight(root.Position, desired, { character }) then
		return desired
	end
	return root.Position
end

function TuskService.addUlt(player, amount)
	local max = TuskConfig.Ultimate.MaxMeter
	local state = states[player]
	local byAct = TuskConfig.Ultimate.GainByAct
	if state and state.Act and byAct and byAct[state.Act] then
		amount = amount * byAct[state.Act]
	end
	-- Saint's Corpse (Ears): the ultimate charges faster.
	local character = player.Character
	amount = amount * (character and character:GetAttribute("CorpseUltGain") or 1)
	-- Bounty board shop (Lucky Horseshoe).
	if character and (character:GetAttribute("ShopUltUntil") or 0) > workspace:GetServerTimeNow() then
		amount = amount * (character:GetAttribute("ShopUltGain") or 1)
	end
	local current = player:GetAttribute("TuskUlt") or 0
	player:SetAttribute("TuskUlt", math.clamp(current + amount, 0, max))
end

function TuskService.spendUlt(player)
	local max = TuskConfig.Ultimate.MaxMeter
	if (player:GetAttribute("TuskUlt") or 0) < max then
		TuskService.tell(player, "Denied", { Reason = "UltNotReady" })
		return false
	end
	-- Each Act must be played for a while before the next awakening.
	local state = states[player]
	local wait = TuskConfig.Ultimate.MinSecondsPerAct or 0
	if state and state.ActSince and os.clock() - state.ActSince < wait then
		TuskService.tell(player, "Denied", { Reason = "TooSoon", Remaining = wait - (os.clock() - state.ActSince) })
		return false
	end
	player:SetAttribute("TuskUlt", 0)
	return true
end

-- All Tusk damage goes through here: CombatAdapter + ultimate meter.
function TuskService.hit(player, targetCharacter, info)
	local ok, damage = Adapter.dealHit(player, targetCharacter, info)
	if ok then
		TuskService.addUlt(player, (damage or 0) * TuskConfig.Ultimate.GainPerDamage)
	end
	return ok
end

-- Server projectile with a Tusk nail visual.
function TuskService.fireNail(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "TuskNail",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = {
			Act = state.Act,
			Style = spec.Style or "Shot",
			Charge = spec.Charge or 0,
			Awakened = state.Awakened == true,
			Stage = spec.Stage,
		},
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Server projectile with a Steel Ball visual (Gyro).
function TuskService.fireBall(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "GyroBall",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = { Style = spec.Style or "Throw", Scale = spec.Scale, Bounce = spec.Bounce },
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Server projectile with a Wired fish-hook visual (Pork Pie Hat Kid).
function TuskService.fireHook(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "WiredHook",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = { Style = spec.Style or "Hook" },
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Server projectile with a written-sound visual (Sandman: In a Silent Way).
function TuskService.fireWord(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "SoundWord",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = { Text = spec.Text or "ZBAAK!", Style = spec.Style or "Slash" },
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Server projectile with a lasso visual (Mountain Tim).
function TuskService.fireLasso(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "TimLasso",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = { Style = spec.Style or "Lasso", Character = spec.Character },
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Server projectile with a frozen-raindrop visual (Blackmore).
function TuskService.fireRain(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "RainDrop",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = { Style = spec.Style or "Drop" },
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Server projectile with a piece of abandoned junk as the visual (Axl RO).
function TuskService.fireJunk(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "GuiltJunk",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = { Style = spec.Style or "Crate" },
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Server projectile with a thrown-knife visual (Diego from another world).
function TuskService.fireKnife(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "WorldKnife",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = { Style = spec.Style or "Knife" },
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Some characters walk faster or slower (Registry WalkSpeed, e.g. Sandman).
function TuskService.applyCharacterSpeed(state)
	local character = state and state.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local info = state.Act and Registry.get(state.Act)
	local mult = info and info.WalkSpeed or 1
	Adapter.setMoveModifier(humanoid, "CharacterSpeed", mult ~= 1 and mult or nil)
end

-- Charge helpers (hold abilities): sets the replicated TuskCharge attribute.
function TuskService.beginCharge(player, state, move, slot, multiplier)
	local character, humanoid = Adapter.getAlive(player)
	state.Charging = { Move = move, Slot = slot, Start = os.clock(), Token = {} }
	Adapter.setMoveModifier(humanoid, "TuskCharge", multiplier or 1)
	character:SetAttribute("TuskCharge", workspace:GetServerTimeNow())
	character:SetAttribute("TuskChargeMove", move)
	return state.Charging
end

function TuskService.endCharge(player, state)
	local charge = state.Charging
	state.Charging = nil
	local character = state.Character
	if character then
		character:SetAttribute("TuskCharge", nil)
		character:SetAttribute("TuskChargeMove", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Adapter.setMoveModifier(humanoid, "TuskCharge", nil)
		end
	end
	return charge
end

---------------------------------------------------------------------------
-- Equip / switch
---------------------------------------------------------------------------
local function cleanupAct(player, state)
	state.Life = state.Life + 1
	if Defense then
		Defense.release(player, state)
	end
	local module = state.Act and actModules[state.Act]
	if module and module.Cleanup then
		pcall(module.Cleanup, TuskService, player, state)
	end
	TuskService.endCharge(player, state)
	if Sneak then
		Sneak.exit(player, state, false)
	end
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute("TuskAwakened", nil)
	end
	state.Awakened = false
	state.Combo = 0
	state.LockUntil = 0
end

local function isUnlocked(player, act)
	local p = TuskConfig.Progression
	if p.Mode == "Awaken" then
		-- Acts are reached through ultimates; the menu is a Studio testing aid only.
		return RunService:IsStudio() and p.StudioMenu == true
	end
	if p.Mode == "Unlock" then
		return p.IsUnlocked ~= nil and p.IsUnlocked(player, act) == true
	end
	return true
end

function TuskService.select(player, act, internal)
	if typeof(act) ~= "number" or act ~= math.floor(act) then
		return
	end
	local state = states[player]
	if not state then
		return
	end
	if act == 0 then
		cleanupAct(player, state)
		state.Act = nil
		if state.Character then
			state.Character:SetAttribute("TuskAct", nil)
		end
		TuskService.tell(player, "Equipped", { Act = 0 })
		return
	end
	if not Registry.isImplemented(act) or not actModules[act] then
		TuskService.tell(player, "Denied", { Reason = "NotAvailable" })
		return
	end
	if not internal and not isUnlocked(player, act) then
		TuskService.tell(player, "Denied", { Reason = "Locked" })
		return
	end
	if state.Act == act then
		return
	end
	if not internal and (os.clock() - state.LastSwitch < TuskConfig.Progression.SwitchCooldown or TuskService.isBusy(state)) then
		TuskService.tell(player, "Denied", { Reason = "SwitchCooldown" })
		return
	end
	cleanupAct(player, state)
	state.Act = act
	state.LastSwitch = os.clock()
	TuskService.markActStart(player, state)
	player:SetAttribute("TuskSelectedAct", act)
	if state.Character then
		state.Character:SetAttribute("TuskAct", act)
	end
	TuskService.applyCharacterSpeed(state)
	TuskService.tell(player, "Equipped", { Act = act })
end

-- Remember when the current Act began (the HUD shows the lock timer).
function TuskService.markActStart(player, state)
	state.ActSince = os.clock()
	player:SetAttribute("TuskActSince", workspace:GetServerTimeNow())
end

-- Awakening: move straight to another Act (no menu rules, no switch cooldown).
function TuskService.evolve(player, state, toAct)
	if not Registry.isImplemented(toAct) or not actModules[toAct] then
		return
	end
	local from = state.Act
	cleanupAct(player, state)
	state.Act = toAct
	TuskService.markActStart(player, state)
	player:SetAttribute("TuskSelectedAct", toAct)
	if state.Character then
		state.Character:SetAttribute("TuskAct", toAct)
	end
	TuskService.applyCharacterSpeed(state)
	TuskService.fx("Evolve", { Character = state.Character, From = from, To = toAct })
	TuskService.tell(player, "Evolved", { Act = toAct })
end

-- Called by every Act's ultimate when its attack has finished.
function TuskService.finishUltimate(player, state)
	local info = Registry.get(state.Act)
	if TuskConfig.Progression.Mode == "Awaken" and info and info.Next then
		TuskService.evolve(player, state, info.Next)
	end
	if RunService:IsStudio() and TuskConfig.Ultimate.StudioRefill then
		player:SetAttribute("TuskUlt", TuskConfig.Ultimate.MaxMeter)
	end
end

---------------------------------------------------------------------------
-- Request routing
---------------------------------------------------------------------------
local function rateLimited(player)
	local r = rate[player]
	local now = os.clock()
	if not r or now - r.Start >= 1 then
		rate[player] = { Start = now, Count = 1 }
		return false
	end
	r.Count = r.Count + 1
	return r.Count > RATE_LIMIT
end

local function onRequest(player, action, a, b, c)
	if rateLimited(player) or typeof(action) ~= "string" then
		return
	end
	if action == "Select" then
		TuskService.select(player, a)
		return
	end
	if action == "Character" then
		-- Character dropdown: "Johnny" (Tusk, starts at Act 1) or "Gyro" (Ball Breaker).
		local st = states[player]
		local start = typeof(a) == "string" and Registry.StartAct[a]
		if not st or not start then
			return
		end
		if st.Act and Registry.characterOf(st.Act) == a then
			return -- already playing that character
		end
		if TuskService.isBusy(st) or st.Charging or st.Burrowed then
			return
		end
		TuskService.select(player, start, true)
		return
	end
	if action == "CorpseMove" then
		-- The character's own move, unlocked by holding a Saint's Corpse part.
		local st = states[player]
		if st and TuskService.CorpseMove then
			TuskService.CorpseMove(player, st, a)
		end
		return
	end
	if action == "RainFloat" then
		-- Blackmore standing on frozen raindrops in mid-air (the movement is the
		-- client's; this only shows the drops to everyone).
		local st = states[player]
		local character = player.Character
		if not st or not character or st.Act ~= 11 then
			return
		end
		local raining = game:GetService("ReplicatedStorage"):GetAttribute("SpinRaining") == true
			or (character:GetAttribute("RainStormUntil") or 0) > workspace:GetServerTimeNow()
		if a == true and raining then
			local cfg = TuskConfig.Blackmore and TuskConfig.Blackmore.RainWalk
			local token = tostring({})
			character:SetAttribute("RainFloating", token)
			task.delay((cfg and cfg.FloatTime or 6) + 0.5, function()
				if character:GetAttribute("RainFloating") == token then
					character:SetAttribute("RainFloating", nil)
				end
			end)
		else
			character:SetAttribute("RainFloating", nil)
		end
		return
	end
	local state = states[player]
	if not state or not state.Act or not state.Character then
		return
	end
	local module = actModules[state.Act]

	local isJohnny = Registry.characterOf(state.Act) == "Johnny"
	if action == "Sneak" then
		-- Every character can sneak (only Johnny's Tusk can burrow out of it).
		Sneak.toggle(player, state, a == true)
		return
	end
	if state.Burrowed then
		return
	end
	-- Block and Dash work for every character.
	if action == "Block" then
		Defense.block(player, state, a == true)
		return
	elseif action == "Dash" then
		Defense.dash(player, state, a)
		return
	end
	-- Attacking drops the block.
	if action == "M1" or action == "Ultimate" or (action == "Ability" and b ~= "Release") then
		Defense.release(player, state)
	end

	-- Releasing a held ability is allowed even mid-lock; everything else needs a free player.
	if action == "Ability" and b == "Release" then
		if typeof(a) == "number" and module.Ability then
			module.Ability(TuskService, player, state, a, "Release", c)
		end
		return
	end
	if not Adapter.canAct(player) then
		return
	end

	if action == "M1" then
		if state.Sneaking and isJohnny then
			Sneak.attack(player, state)
		elseif state.Sneaking then
			-- Everyone else ambushes: out of sneak, the first hit does extra damage.
			Sneak.ambush(player, state)
			module.M1(TuskService, player, state, a)
		else
			module.M1(TuskService, player, state, a)
		end
	elseif action == "Ability" then
		if typeof(a) ~= "number" or (a ~= 1 and a ~= 2 and a ~= 3) then
			return
		end
		if state.Sneaking then
			Sneak.ambush(player, state)
		end
		module.Ability(TuskService, player, state, a, "Press", c)
	elseif action == "Ultimate" then
		if state.Sneaking then
			Sneak.exit(player, state, true)
		end
		module.Ultimate(TuskService, player, state, a)
	end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local function onCharacter(player, character)
	local state = states[player]
	if not state then
		return
	end
	cleanupAct(player, state)
	state.Character = character
	state.Burrowed = false
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or states[player] ~= state or state.Character ~= character then
		return
	end
	local progression = TuskConfig.Progression
	if state.Act and progression.Mode == "Awaken" and progression.ResetOnDeath then
		-- Back to the character's first Act after dying (Johnny -> Act 1; Gyro stays Gyro).
		state.Act = Registry.StartAct[Registry.characterOf(state.Act)] or progression.DefaultAct
		TuskService.markActStart(player, state)
	end
	if state.Act then
		character:SetAttribute("TuskAct", state.Act)
	end
	TuskService.applyCharacterSpeed(state)
	humanoid.Died:Connect(function()
		if state.Character == character then
			cleanupAct(player, state)
		end
	end)
	-- Getting stunned interrupts charges and breaks sneak (counterplay).
	character:GetAttributeChangedSignal(Adapter.Settings.StunAttribute):Connect(function()
		if not Adapter.isStunned(character) or state.Character ~= character then
			return
		end
		if Defense then
			Defense.release(player, state) -- a stun knocks you out of your block
		end
		if state.Charging then
			local module = state.Act and actModules[state.Act]
			if module and module.CancelCharge then
				module.CancelCharge(TuskService, player, state)
			else
				TuskService.endCharge(player, state)
			end
			TuskService.tell(player, "Interrupted", {})
		end
		if state.Sneaking then
			Sneak.exit(player, state, true)
		end
	end)
end

local function onPlayer(player)
	states[player] = {
		Act = nil,
		Character = nil,
		Life = 0,
		Combo = 0,
		LastM1 = 0,
		LockUntil = 0,
		LastSwitch = -math.huge,
		Charging = nil,
		Sneaking = false,
		Burrowed = false,
		Awakened = false,
	}
	player:SetAttribute("TuskUlt", (RunService:IsStudio() and TuskConfig.Ultimate.StudioStartFull) and TuskConfig.Ultimate.MaxMeter or 0)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	if TuskConfig.Progression.AutoEquip then
		task.defer(TuskService.select, player, TuskConfig.Progression.DefaultAct, true)
	end
end

-- Stand-user NPCs (StandBots): a bot is a table that looks enough like a
-- Player for the move code ({ Name, UserId < 0, Character, Neutral,
-- GetAttribute, SetAttribute }). It gets a normal state and plays an Act.
function TuskService.hasAct(act)
	return actModules[act] ~= nil
end

function TuskService.actModule(act)
	return actModules[act]
end

function TuskService.addBot(bot, act)
	local state = {
		Act = nil,
		Character = bot.Character,
		Life = 0,
		Combo = 0,
		LastM1 = 0,
		LockUntil = 0,
		LastSwitch = -math.huge,
		Charging = nil,
		Sneaking = false,
		Burrowed = false,
		Awakened = false,
		IsBot = true,
	}
	states[bot] = state
	bot:SetAttribute("TuskUlt", 0)
	TuskService.select(bot, act, true)
	local humanoid = bot.Character and bot.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			if states[bot] == state then
				cleanupAct(bot, state)
			end
		end)
	end
	return state
end

function TuskService.removeBot(bot)
	local state = states[bot]
	if state then
		cleanupAct(bot, state)
		states[bot] = nil
	end
end

function TuskService.init()
	for act, info in pairs(Registry.Acts) do
		local name = info.Module or ("TuskAct" .. act)
		if Registry.isImplemented(act) and __hasModule(name) then
			-- One broken character script must not take the whole game down.
			local ok, result = pcall(__require, name)
			if ok then
				actModules[act] = result
			else
				warn("[Spin] Couldn't load " .. name .. " (character " .. tostring(info.Character) .. "): " .. tostring(result))
			end
		end
	end
	Sneak = __require("TuskSneakService")
	Sneak.init(TuskService)
	Defense = __require("DefenseService")
	Defense.init(TuskService)
	TuskService.Defense = Defense
	-- Tell every client which characters this server can actually play (each
	-- non-Johnny character is an optional script), so the menu can say so.
	local installed, seen = {}, {}
	for act in pairs(actModules) do
		local who = Registry.characterOf(act)
		if not seen[who] then
			seen[who] = true
			table.insert(installed, who)
		end
	end
	table.sort(installed)
	game:GetService("ReplicatedStorage"):SetAttribute("SpinInstalledCharacters", table.concat(installed, ","))
	print("[Spin] Characters installed: " .. table.concat(installed, ", "))

	Request.OnServerEvent:Connect(onRequest)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		if state then
			cleanupAct(player, state)
		end
		states[player] = nil
		rate[player] = nil
	end)
end

return TuskService
end

-- ======================================================================
-- MODULE: TuskSneakService
-- ======================================================================
__modules["TuskSneakService"] = function()
--[[
	TuskSneakService  (ServerScriptService.SpinServer.TuskSneakService)

	Tusk Sneak (every Act): a crouched, slowed stalking state, plus the
	Sneak Attack (M1 while sneaking):
	  1. Tusk sinks into the ground (Burrow): invisible and briefly untargetable
	  2. a distortion warning appears under the target (WarningTime before emergence)
	  3. Tusk emerges behind the target at a server-validated safe spot
	  4. surprise hit + launch, finished with a blue shockwave

	Counterplay: the warning is visible and audible, a target that moves
	MaxTargetDrift studs away is missed, getting hit breaks sneak, and both
	sneak and the attack have cooldowns.

	Every character can sneak: NPCs don't notice a sneaking player until
	they're close (StandBots), other players see them fade with distance and
	can't see their name (TuskSneakController), and bounty hunters lose
	track of them (BountyUI). Attacking out of sneak as anyone but Johnny is
	an AMBUSH: the first hit within a moment does extra damage (CombatAdapter).

	Character attributes: TuskSneaking, TuskBurrowed, AmbushUntil, SpottedUntil.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Adapter = __require("CombatAdapter")
local Cooldowns = __require("CooldownService")
local Hitbox = __require("TuskHitbox")

local TuskSneakService = {}
local S -- TuskService

local cfg = TuskConfig.Sneak

function TuskSneakService.init(service)
	S = service
end

function TuskSneakService.exit(player, state, applyCooldown)
	if not state.Sneaking then
		return
	end
	state.Sneaking = false
	state.SneakToken = nil
	local character = state.Character
	if character then
		character:SetAttribute("TuskSneaking", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Adapter.setMoveModifier(humanoid, "TuskSneak", nil)
			if state.SneakDisplay then
				humanoid.DisplayDistanceType = state.SneakDisplay
				state.SneakDisplay = nil
			end
		end
	end
	if applyCooldown then
		Cooldowns.start(player, "TuskSneak", cfg.Cooldown)
		S.tell(player, "SneakCooldown", { Duration = cfg.Cooldown })
	end
end

-- Attacking out of sneak (anyone but Johnny): leave sneak, and the first
-- hit in the next moment is an ambush (extra damage; CombatAdapter).
function TuskSneakService.ambush(player, state)
	local character = state.Character
	TuskSneakService.exit(player, state, true)
	if character then
		character:SetAttribute("AmbushUntil", workspace:GetServerTimeNow() + (cfg.AmbushWindow or 1))
	end
end

function TuskSneakService.toggle(player, state, on)
	if not on then
		TuskSneakService.exit(player, state, true)
		return
	end
	if state.Sneaking or state.Charging or S.isBusy(state) or not Adapter.canAct(player) then
		return
	end
	local remaining = Cooldowns.remaining(player, "TuskSneak")
	if remaining > 0 then
		S.tell(player, "Denied", { Reason = "SneakCooldown", Remaining = remaining })
		return
	end
	local character, humanoid = Adapter.getAlive(player)
	state.Sneaking = true
	local token = {}
	state.SneakToken = token
	character:SetAttribute("TuskSneaking", true)
	Adapter.setMoveModifier(humanoid, "TuskSneak", cfg.WalkSpeedMultiplier)
	-- Your name and health bar disappear while you sneak.
	state.SneakDisplay = humanoid.DisplayDistanceType
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	task.delay(cfg.MaxDuration, function()
		if state.SneakToken == token then
			TuskSneakService.exit(player, state, true)
		end
	end)
end

-- Nearest enemy in front, in range, with line of sight.
local function findTarget(character, root, range, coneDegrees)
	range = range or cfg.Attack.Range
	coneDegrees = coneDegrees or cfg.Attack.ConeDegrees
	local best, bestDistance
	local cosLimit = math.cos(math.rad(coneDegrees / 2))
	for _, target in ipairs(Hitbox.inRadius(character, root.Position, range)) do
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if targetRoot and Adapter.canBeHit(nil, target) then
			local offset = targetRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			if flat.Magnitude > 0.1 and flat.Unit:Dot(look.Unit) >= cosLimit then
				if Hitbox.lineOfSight(root.Position, targetRoot.Position, { character, target }) then
					if not bestDistance or offset.Magnitude < bestDistance then
						best, bestDistance = target, offset.Magnitude
					end
				end
			end
		end
	end
	return best
end

-- Safe emergence point near the target: behind first, then the sides, then in front.
-- Must have clear line of sight from the target, solid ground below and free space.
TuskSneakService.findTarget = findTarget

local function emergePoint(attacker, target, distance)
	local targetRoot = target.HumanoidRootPart
	local d = distance or cfg.Attack.EmergeDistance
	local candidates = {
		targetRoot.CFrame * CFrame.new(0, 0, d),
		targetRoot.CFrame * CFrame.new(d, 0, 0),
		targetRoot.CFrame * CFrame.new(-d, 0, 0),
		targetRoot.CFrame * CFrame.new(0, 0, -d),
	}
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { attacker, target }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { attacker, target }
	for _, cf in ipairs(candidates) do
		local pos = cf.Position
		if Hitbox.lineOfSight(targetRoot.Position, pos, { attacker, target }) then
			local ground = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), rayParams)
			if ground then
				local standPos = ground.Position + Vector3.new(0, 3, 0)
				local blocking = workspace:GetPartBoundsInBox(CFrame.new(standPos), Vector3.new(2, 4.5, 2), overlap)
				local solid = false
				for _, part in ipairs(blocking) do
					if part.CanCollide then
						solid = true
						break
					end
				end
				if not solid then
					return standPos
				end
			end
		end
	end
	return nil
end

function TuskSneakService.attack(player, state)
	local a = cfg.Attack
	if S.isBusy(state) or state.Charging then
		return
	end
	local remaining = Cooldowns.remaining(player, "TuskSneakAttack")
	if remaining > 0 then
		S.tell(player, "Denied", { Reason = "SneakAttackCooldown", Remaining = remaining })
		return
	end
	local character, _, root = Adapter.getAlive(player)
	local target = findTarget(character, root)
	if not target then
		Cooldowns.start(player, "TuskSneakAttack", a.FailCooldown)
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end

	TuskSneakService.exit(player, state, true)
	Cooldowns.start(player, "TuskSneakAttack", a.Cooldown)
	S.tell(player, "SneakAttackCooldown", { Duration = a.Cooldown })
	TuskSneakService.burrowStrike(player, state, target, a, "TuskSneakAttack")
end

--[[
	Burrow -> warning -> emerge behind the target -> hit + shockwave.
	Shared by the Sneak Attack and Act 2's Underground Pursuit.
	a = { BurrowTime, WarningTime, EmergeDistance, MaxTargetDrift, Range,
	      HitRadius, Damage, Stun, Knockback, Launch }
]]
function TuskSneakService.burrowStrike(player, state, target, a, source)
	local character, _, root = Adapter.getAlive(player)
	if not character then
		return
	end
	a = setmetatable(table.clone(a), { __index = cfg.Attack })
	S.lock(state, a.BurrowTime + 0.45)

	local life = state.Life
	local startPos = root.Position
	local targetStart = target.HumanoidRootPart.Position
	state.Burrowed = true
	character:SetAttribute("TuskBurrowed", true)
	character:SetAttribute(Adapter.Settings.IFrameAttribute, true)
	-- Anchor in place while underground so the hidden body can't wander.
	root.Anchored = true

	S.fx("SneakAttack", { Phase = "Burrow", Character = character, Position = startPos - Vector3.new(0, 2.8, 0), Target = target, BurrowTime = a.BurrowTime })

	local function surface()
		state.Burrowed = false
		if character.Parent then
			character:SetAttribute("TuskBurrowed", nil)
			character:SetAttribute(Adapter.Settings.IFrameAttribute, nil)
			if root.Parent then
				root.Anchored = false
			end
		end
	end

	task.delay(a.BurrowTime - a.WarningTime, function()
		if state.Life ~= life or not target.Parent then
			return
		end
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			S.fx("SneakAttack", { Phase = "Warning", Character = character, Target = target, Position = targetRoot.Position - Vector3.new(0, 2.8, 0), Duration = a.WarningTime })
		end
	end)

	task.delay(a.BurrowTime, function()
		if state.Life ~= life or not Adapter.getAlive(player) then
			surface()
			return
		end
		local targetRoot = target.Parent and target:FindFirstChild("HumanoidRootPart")
		local valid = targetRoot
			and Adapter.canBeHit(player, target)
			and (targetRoot.Position - targetStart).Magnitude <= a.MaxTargetDrift
			and (targetRoot.Position - startPos).Magnitude <= a.Range * 1.4
		local pos = valid and emergePoint(character, target, a.EmergeDistance) or nil

		surface()
		if not pos then
			-- Whiff: surface where we went under.
			S.fx("SneakAttack", { Phase = "Emerge", Character = character, Position = startPos - Vector3.new(0, 2.8, 0), Hit = false })
			return
		end
		local facing = Vector3.new(targetRoot.Position.X, pos.Y, targetRoot.Position.Z)
		character:PivotTo(CFrame.lookAt(pos, facing))
		S.fx("SneakAttack", { Phase = "Emerge", Character = character, Position = pos - Vector3.new(0, 2.8, 0), Hit = true })

		local hitAny = false
		for _, victim in ipairs(Hitbox.inRadius(character, pos, a.HitRadius, 3)) do
			local victimRoot = victim:FindFirstChild("HumanoidRootPart")
			if victimRoot and Hitbox.lineOfSight(pos, victimRoot.Position, { character, victim }) then
				local hit = S.hit(player, victim, {
					Damage = a.Damage,
					Stun = a.Stun,
					Knockback = a.Knockback,
					Launch = a.Launch,
					Direction = victimRoot.Position - pos,
					Position = victimRoot.Position,
					Source = source or "TuskSneakAttack",
				})
				hitAny = hitAny or hit
			end
		end
		S.fx("SneakAttack", { Phase = "Shockwave", Character = character, Position = pos - Vector3.new(0, 2.8, 0), Hit = hitAny })
	end)
end

return TuskSneakService
end

-- ======================================================================
-- MODULE: WeatherService
-- ======================================================================
__modules["WeatherService"] = function()
--[[
	WeatherService  (ServerScriptService.SpinServer.WeatherService)

	Rain for the whole server: every TuskConfig.Weather.RainEvery seconds it
	rains for RainDuration seconds. Sets these ReplicatedStorage attributes:
	  SpinRaining   true while it rains
	  SpinRainEnds  server time the rain stops
	  SpinNextRain  server time the next rain starts
	Clients draw the rain (WeatherClient). Blackmore can walk on raindrops
	while it rains (TuskActs/Blackmore + BlackmoreVFX).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local WeatherService = {}

local function now()
	return workspace:GetServerTimeNow()
end

function WeatherService.isRaining()
	return ReplicatedStorage:GetAttribute("SpinRaining") == true
end

function WeatherService.setRain(on, seconds)
	ReplicatedStorage:SetAttribute("SpinRaining", on and true or nil)
	ReplicatedStorage:SetAttribute("SpinRainEnds", on and (now() + (seconds or 60)) or nil)
end

function WeatherService.init()
	local cfg = TuskConfig.Weather
	if not cfg or cfg.Enabled == false then
		return
	end
	local first = RunService:IsStudio() and (cfg.StudioFirstRainAfter or cfg.FirstRainAfter) or cfg.FirstRainAfter
	task.spawn(function()
		local nextRain = now() + (first or cfg.RainEvery)
		while true do
			ReplicatedStorage:SetAttribute("SpinNextRain", nextRain)
			task.wait(math.max(nextRain - now(), 0.1))
			WeatherService.setRain(true, cfg.RainDuration)
			task.wait(cfg.RainDuration)
			WeatherService.setRain(false)
			nextRain = nextRain + math.max(cfg.RainEvery, cfg.RainDuration + 1)
			if nextRain < now() then
				nextRain = now() + cfg.RainEvery
			end
		end
	end)
end

return WeatherService
end

-- ======================================================================
-- START
-- ======================================================================

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
__start("WeatherService")
__start("CorpseService", TuskService)
__start("NPCService")
__start("TestDummies")
print("[Spin] Server ready")
