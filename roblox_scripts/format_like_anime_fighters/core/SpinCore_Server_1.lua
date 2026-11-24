--[[
	SpinCore_Server_1  (ModuleScript)  -- part 1 of 5
	PUT IT IN: ServerScriptService > SpinCore   (make a Folder named SpinCore there if it doesn't exist)

	Part of the Spin Battlegrounds server core, split up so pasting is quick.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

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
	  * STABLE (in the SHOP): customise your horse: coat, mane & tail,
	    saddle blanket, saddle leather, face marking, socks and its name
	    (filtered). You ride it with M and race on it
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

-- Every stable category: its config list, the player attribute holding the
-- equipped one.
local KINDS = {
	{ Kind = "Coat", List = "Coats", Attr = "HorseCoat" },
	{ Kind = "Mane", List = "Manes", Attr = "HorseMane" },
	{ Kind = "Blanket", List = "Blankets", Attr = "HorseBlanket" },
	{ Kind = "Saddle", List = "Saddles", Attr = "HorseSaddle" },
	{ Kind = "Marking", List = "Markings", Attr = "HorseMarking" },
	{ Kind = "Socks", List = "Socks", Attr = "HorseSocks" },
}
local KIND = {}
for _, k in ipairs(KINDS) do
	KIND[k.Kind] = k
end

local function stableFor(player)
	local have = owned(player)
	local out = { Name = player:GetAttribute("HorseName"), NameMax = hcfg.NameMaxLength or 20 }
	for _, k in ipairs(KINDS) do
		local list = hcfg[k.List] or {}
		local current = player:GetAttribute(k.Attr) or (list[1] or {}).Id
		local items = {}
		for _, item in ipairs(list) do
			table.insert(items, {
				Id = item.Id, Name = item.Name, Price = item.Price,
				Body = item.Body, Mane = item.Mane, Color = item.Color, Material = item.Material, Socks = item.Socks, Style = item.Style,
				Owned = item.Price <= 0 or have[k.Kind .. ":" .. item.Id] == true,
				Equipped = item.Id == current,
			})
		end
		out[k.List] = items
	end
	return out
end

local function stableItem(key)
	local kind, id = string.match(tostring(key), "^(%a+):(%w+)$")
	local k = kind and KIND[kind]
	for _, item in ipairs(k and hcfg[k.List] or {}) do
		if item.Id == id then
			return k, item
		end
	end
	return nil
end

local function refreshRide(player)
	-- Riding your horse right now? It changes straight away.
	local ok, Race = pcall(function()
		return __require("RaceService")
	end)
	if ok and Race and Race.refreshHorse then
		Race.refreshHorse(player)
	end
end

local function buyHorse(player, key)
	local k, item = stableItem(key)
	if not item then
		return
	end
	local have = owned(player)
	if item.Price > 0 and not have[k.Kind .. ":" .. item.Id] then
		if not spend(player, item.Price) then
			send(player, "Denied", { Reason = "Not enough Cash ($" .. item.Price .. ")." })
			return
		end
		local list = player:GetAttribute("HorseOwned")
		player:SetAttribute("HorseOwned", (list and list ~= "" and (list .. ",") or "") .. k.Kind .. ":" .. item.Id)
		send(player, "Bought", { Name = item.Name .. " (" .. string.upper(k.Kind) .. ")", Price = item.Price })
	end
	player:SetAttribute(k.Attr, item.Id)
	refreshRide(player)
end

-- Name your horse (run through Roblox's text filter; shown above the horse).
local TextService = game:GetService("TextService")
local function nameHorse(player, name)
	if typeof(name) ~= "string" then
		return
	end
	name = name:gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	name = name:sub(1, hcfg.NameMaxLength or 20)
	if name == "" then
		player:SetAttribute("HorseName", nil)
		refreshRide(player)
		return
	end
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(name, player.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or not filtered or filtered == "" then
		send(player, "Denied", { Reason = "Couldn't use that name right now." })
		return
	end
	player:SetAttribute("HorseName", filtered)
	send(player, "Bought", { Name = "NAMED: " .. string.upper(filtered), Price = 0 })
	refreshRide(player)
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
		elseif action == "NameHorse" then
			nameHorse(player, key)
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

-- Bring a part that's lying out in the desert (nobody holding it) to a
-- spot, e.g. the race finish for the winner. Returns its id, or nil when
-- every part is held. It goes back out into the desert if nobody takes it.
function CorpseService.summon(position)
	local lying = {}
	for id, m in pairs(relics) do
		if m.Parent then
			table.insert(lying, id)
		end
	end
	if #lying == 0 then
		return nil
	end
	local id = lying[rng:NextInteger(1, #lying)]
	placeRelic(id, position, true)
	return id, partInfo[id] and partInfo[id].Name
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
-- MODULE: DataService
-- ======================================================================
__modules["DataService"] = function()
--[[
	DataService  (ServerScriptService.SpinServer.DataService)

	Saves each player's progress with DataStoreService, so it's still there
	next time they play:
	  * Cash and Bounties (leaderstats)
	  * the STABLE: every horse item they've bought (HorseOwned) and what
	    they have on (coat, mane, blanket, saddle, marking, socks)
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

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local DataService = {}
local cfg = TuskConfig.Save or {}
local store
local loaded = {} -- [player] = true once their data has loaded (only then do we save)
local VERSION = 1

-- Player attributes that make up the stable.
local HORSE_ATTRS = { "HorseOwned", "HorseCoat", "HorseMane", "HorseBlanket", "HorseSaddle", "HorseMarking", "HorseSocks", "HorseName" }

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
	-- An unpublished place can't use DataStores at all: don't even try (the
	-- call errors, and Studio's debugger stops on it).
	if game.PlaceId == 0 then
		warn("[DataService] This place isn't published, so progress won't be saved. Publish it (File > Publish to Roblox) and turn on Game Settings > Security > Enable Studio Access to API Services to test saving.")
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
end
end
