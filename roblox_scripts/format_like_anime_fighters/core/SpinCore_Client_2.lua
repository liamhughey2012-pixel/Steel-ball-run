--[[
	SpinCore_Client_2  (ModuleScript)  -- part 2 of 8
	PUT IT IN: ReplicatedStorage > SpinCore   (make a Folder named SpinCore there if it doesn't exist)

	Part of the Spin Battlegrounds client core, split up so pasting is quick.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: BountyUI
-- ======================================================================
__modules["BountyUI"] = function()
--[[
	BountyUI  (StarterPlayerScripts.SpinClient.UI.BountyUI)

	The bounty board screen (owner's design):
	  * a framed wooden board (grain, nails, metal corner brackets, a hanging
	    title sign) that drops in from the top; a header strip with your Cash,
	    ALL / PLAYERS / NPCS / CORPSE tabs and your current bounty
	  * CORPSE: "RETRIEVE" contracts, one per Saint's Corpse part: paid when you
	    take that part; the photo is the relic (or the face of whoever holds it)
	  * aged parchment WANTED posters with a red pin: face (avatar headshot,
	    or the NPC's face), name, Stand, "DEAD OR ALIVE", danger pips, a red
	    reward ribbon and a kill-streak badge
	  * HOVER a poster: it straightens, lifts, grows, glows gold, "CLICK TO HUNT"
	  * CLICK it: a BOUNTY CONTRACT card with ACCEPT / DECLINE; accepting
	    thumps an ACCEPTED stamp on it
	  * ACCEPT: the board closes and a bounty tracker appears on the left
	    (target, reward, distance, time left, abandon button), plus a red
	    TARGET marker over their head that only you can see
	  * claiming it: a big "BOUNTY CLAIMED! +$350" banner
	Remote: Net "Bounty" (server: BountyService).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local Net = __require("Net")
local Registry = __require("TuskActRegistry")
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local okHorse, HorseModel = pcall(function()
	return __require("HorseModel")
end)
if not okHorse then
	HorseModel = nil
end

local BountyUI = {}
local player = Players.LocalPlayer
local Remote

local WOOD = Color3.fromRGB(112, 74, 44)
local WOOD_DARK = Color3.fromRGB(78, 50, 30)
local WOOD_LIGHT = Color3.fromRGB(134, 90, 56)
local PAPER = Color3.fromRGB(234, 205, 160)
local PAPER_DARK = Color3.fromRGB(205, 172, 125)
local INK = Color3.fromRGB(60, 36, 20)
local RED = Color3.fromRGB(190, 40, 35)
local GREEN = Color3.fromRGB(60, 150, 70)
local GOLD = Color3.fromRGB(255, 205, 90)

local gui, dim, board, grid, confirm, confirmLayer, tracker, banner, marker
local current -- the active bounty
local confirmEntry -- the poster the Accept/Decline card is asking about
local confirmPay, confirmPips -- the reward label and danger pips on the card
local FAST = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SOFT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function corner(p, r)
	new("UICorner", { CornerRadius = UDim.new(0, r) }, p)
end

local function label(parent, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, TextColor3 = INK, Font = Enum.Font.GothamBlack, TextScaled = true }, parent)
	for k, v in pairs(props) do
		l[k] = v
	end
	return l
end

-- A live "photo" of a model's face: the character copied into a ViewportFrame.
local function faceViewport(model, parent)
	local head = model and model:FindFirstChild("Head")
	if not head then
		return false
	end
	local ok, copy = pcall(function()
		local was = model.Archivable
		model.Archivable = true
		local c = model:Clone()
		model.Archivable = was
		return c
	end)
	if not ok or not copy then
		return false
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	local view = new("ViewportFrame", { Name = "Face", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(190, 175, 160), LightColor = Color3.fromRGB(255, 240, 220), LightDirection = Vector3.new(-0.4, -0.6, -1) }, parent)
	local world = new("WorldModel", {}, view)
	copy.Parent = world
	local camera = new("Camera", { FieldOfView = 34 }, view)
	local copyHead = copy:FindFirstChild("Head") or head
	local look = copyHead.CFrame
	camera.CFrame = CFrame.lookAt((look * CFrame.new(0, 0.25, -3.2)).Position, look.Position + Vector3.new(0, 0.1, 0))
	view.CurrentCamera = camera
	return true
end

-- The Saint's Corpse part lying in the world, or the character carrying it.
local function corpseRelic(partId)
	for _, m in ipairs(game:GetService("CollectionService"):GetTagged("SpinCorpse")) do
		if m.Parent and m:GetAttribute("PartId") == partId then
			return m
		end
	end
	return nil
end

local function corpseHolder(partId)
	local function holds(model)
		local parts = model and model:GetAttribute("CorpseParts")
		return parts and string.find("," .. parts .. ",", "," .. partId .. ",", 1, true)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if holds(p.Character) then
			return p.Character
		end
	end
	-- Stand-user NPCs pick parts up too.
	for _, m in ipairs(game:GetService("CollectionService"):GetTagged("SpinFighter")) do
		if m.Parent and holds(m) then
			return m
		end
	end
	return nil
end

-- A small photo of a relic (its parts copied into a viewport).
local function relicViewport(relic, parent)
	local view = new("ViewportFrame", { Name = "Face", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(200, 180, 150), LightColor = Color3.fromRGB(255, 230, 180), LightDirection = Vector3.new(-0.4, -0.6, -1) }, parent)
	local model = new("Model", {}, view)
	for _, p in ipairs(relic:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "Beam" and p.Name ~= "Holder" then
			local c = p:Clone()
			for _, d in ipairs(c:GetChildren()) do
				d:Destroy()
			end
			c.Parent = model
		end
	end
	local center = relic.PrimaryPart and relic.PrimaryPart.Position or relic:GetPivot().Position
	local camera = new("Camera", { FieldOfView = 40 }, view)
	camera.CFrame = CFrame.lookAt(center + Vector3.new(2.2, 1.2, -5.5), center)
	view.CurrentCamera = camera
end

local function photoFor(entry, parent)
	local photo = new("ImageLabel", { Name = "Photo", BackgroundColor3 = PAPER_DARK, BorderSizePixel = 0, ImageColor3 = Color3.fromRGB(240, 220, 190), ClipsDescendants = true }, parent)
	if entry.Kind == "Corpse" then
		-- The relic on a gold backdrop, or the face of whoever carries it.
		photo.BackgroundColor3 = Color3.fromRGB(214, 178, 96)
		local relic = corpseRelic(entry.Part)
		local holder = not relic and corpseHolder(entry.Part)
		if relic then
			relicViewport(relic, photo)
		elseif not (holder and faceViewport(holder, photo)) then
			label(photo, { Size = UDim2.fromScale(1, 1), Text = "✝", Font = Enum.Font.GothamBlack, TextColor3 = INK, TextTransparency = 0.3 })
		end
		if holder then
			local tag = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(0.8, 0, 0, 14), BackgroundColor3 = RED }, photo)
			corner(tag, 3)
			label(tag, { Size = UDim2.fromScale(1, 1), Text = "HELD", Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), TextScaled = true })
		end
		return photo
	end
	if entry.Kind == "Player" and entry.UserId then
		photo.Image = "rbxthumb://type=AvatarHeadShot&id=" .. entry.UserId .. "&w=150&h=150"
	else
		-- NPC: their actual face (copied into a viewport), on their Stand's colour.
		local info = entry.Act and Registry.get(entry.Act)
		photo.BackgroundColor3 = info and info.Theme.Primary:Lerp(PAPER_DARK, 0.55) or PAPER_DARK
		-- The NPC may have respawned since the list was sent: find its current body by name.
		local model = entry.Model
		if not (model and model.Parent and model:FindFirstChild("Head")) then
			model = nil
			for _, m in ipairs(game:GetService("CollectionService"):GetTagged("SpinFighter")) do
				local hum = m:FindFirstChildOfClass("Humanoid")
				if m.Parent and (m.Name == entry.Name or (hum and hum.DisplayName == entry.Name)) then
					model = m
				end
			end
		end
		if not faceViewport(model, photo) then
			-- No body to photograph: their initials on their Stand's colour.
			local who = (entry.Name or "?"):gsub("^Stand User: ", "")
			local initials = ""
			for word in who:gmatch("%S+") do
				if #initials < 2 then
					initials = initials .. word:sub(1, 1)
				end
			end
			label(photo, { Size = UDim2.fromScale(1, 1), Text = string.upper(initials), Font = Enum.Font.Bangers, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3 })
		end
	end
	return photo
end

---------------------------------------------------------------------------
-- Board
---------------------------------------------------------------------------
local lastList = {}
local lastJobs, lastShop, jobsUntil = {}, {}, 0
local lastStable = { Coats = {}, Blankets = {} }
local stablePreview -- { Camera, Angle } spinning horse in the STABLE
local showStable -- (below)
local placeAmount = 100
local placeButton -- "PUT $100 ON THEIR HEAD" on a player's contract
local jobsTimer -- "NEW JOBS IN m:ss"
local filter = "ALL"
local tabs = {}
local cashLabel, huntingLabel, countLabel
local SLIDE = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local GLOW = Color3.fromRGB(255, 214, 110)
local BURNT = Color3.fromRGB(120, 78, 40)
local NAIL = Color3.fromRGB(70, 70, 76)

-- "STAND: BALL BREAKER" from the Act a character is playing.
local function standOf(act)
	if not act then
		return nil
	end
	local who = Registry.characterOf(act)
	if who == "Johnny" then
		local info = Registry.get(act)
		return info and info.Name
	end
	for _, entry in ipairs(TuskConfig.Roster or {}) do
		if entry.Id == who then
			return entry.Stand
		end
	end
	return nil
end

local function themeOf(act)
	local info = act and Registry.get(act)
	return info and info.Theme.Primary or PAPER_DARK
end

local function cashText()
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	return "$" .. tostring(cash and cash.Value or 0)
end

local openToken = 0
local function closeBoard()
	if confirmLayer then
		confirmLayer.Visible = false
	end
	if not dim or not dim.Visible then
		return
	end
	-- Slide up and away.
	TweenService:Create(board, SOFT, { Position = UDim2.fromScale(0.5, -0.6) }):Play()
	TweenService:Create(dim, SOFT, { BackgroundTransparency = 1 }):Play()
	local token = openToken
	task.delay(0.22, function()
		if openToken == token then
			dim.Visible = false
		end
	end)
end

local function showConfirm(entry)
	confirmLayer.Visible = true
	confirm.Visible = true
	local body = confirm:FindFirstChild("Body")
	for _, c in ipairs(body:GetChildren()) do
		if c.Name == "Photo" then
			c:Destroy()
		end
	end
	local photo = photoFor(entry, body)
	photo.AnchorPoint = Vector2.new(0.5, 0)
	photo.Position = UDim2.new(0.5, 0, 0, 66)
	photo.Size = UDim2.fromOffset(136, 136)
	corner(photo, 6)
	new("UIStroke", { Color = WOOD_DARK, Thickness = 4 }, photo)
	body:FindFirstChild("Who").Text = string.upper(entry.Name)
	local stand = standOf(entry.Act)
	if entry.Kind == "Corpse" then
		body:FindFirstChild("Stand").Text = "GIVES: " .. string.upper(entry.Boost or "")
		body:FindFirstChild("Stand").TextColor3 = Color3.fromRGB(150, 100, 20)
	else
		body:FindFirstChild("Stand").Text = stand and ("STAND: " .. stand) or ""
		body:FindFirstChild("Stand").TextColor3 = themeOf(entry.Act):Lerp(INK, 0.45)
	end
	confirmPay.Text = "$" .. entry.Reward
	local danger = math.clamp(math.floor(entry.Reward / 75 + 0.5), 1, 5)
	for i, pip in ipairs(confirmPips) do
		pip.BackgroundColor3 = i <= danger and RED or PAPER_DARK
	end
	local minutes = math.floor((TuskConfig.Bounty and TuskConfig.Bounty.Duration or 300) / 60)
	body:FindFirstChild("Note").Text = (current and current.Key ~= entry.Key) and ("This replaces your bounty on " .. current.Name .. ".")
		or (entry.Kind == "Corpse" and (entry.HeldBy and (entry.HeldBy .. " is carrying it: take them down, then take the part. Paid the moment you take it.") or "It's lying out in the desert under a pillar of light. Paid the moment you take it."))
		or (entry.Corpse and ("Carrying the Saint's Corpse: " .. entry.Corpse .. ". Take them down and the parts drop."))
		or (minutes .. " minutes to find them. Land the final hit to claim the reward.")
	body:FindFirstChild("Stamp").Visible = false
	if placeButton then
		placeButton.Visible = entry.Kind == "Player"
		placeButton:FindFirstChild("Top").Text = "+$" .. placeAmount
	end
	if entry.Placed then
		body:FindFirstChild("Note").Text = "Includes a $" .. entry.Placed .. " price on their head. " .. body:FindFirstChild("Note").Text
	end
	confirmEntry = entry
	local scale = confirm:FindFirstChildOfClass("UIScale")
	scale.Scale = 0.6
	confirm.Rotation = -4
	TweenService:Create(scale, FAST, { Scale = 1 }):Play()
	TweenService:Create(confirm, FAST, { Rotation = 0 }):Play()
end

local function makePoster(entry, index)
	local col = (index - 1) % 4
	local row = math.floor((index - 1) / 4)
	local tilt = ((index * 37) % 11 - 5) * 1.1
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(146, 204), Position = UDim2.fromOffset(14 + col * 160, 16 + row * 222) }, grid)
	local shadow = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.82, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(5, 6), Rotation = tilt }, holder)
	corner(shadow, 4)
	local paper = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = PAPER, Size = UDim2.fromScale(1, 1), Rotation = tilt }, holder)
	corner(paper, 3)
	local scale = new("UIScale", { Scale = 1 }, paper)
	-- Aged paper: lighter middle, browner edges, a burnt-looking border.
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, PAPER_DARK), ColorSequenceKeypoint.new(0.35, PAPER), ColorSequenceKeypoint.new(1, PAPER_DARK) }), Rotation = 70 }, paper)
	local edge = new("UIStroke", { Color = BURNT, Thickness = 2, Transparency = 0.25 }, paper)
	-- Red pin with a shine.
	local pin = new("Frame", { BackgroundColor3 = RED, Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0.5, -7, 0, -4), ZIndex = 3 }, paper)
	corner(pin, 99)
	new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.4, Size = UDim2.fromOffset(4, 4), Position = UDim2.fromOffset(3, 3), ZIndex = 3 }, pin)
	local isCorpse = entry.Kind == "Corpse"
	label(paper, { Position = UDim2.fromScale(0.06, 0.06), Size = UDim2.fromScale(0.88, 0.13), Text = isCorpse and "RETRIEVE" or "WANTED", Font = Enum.Font.Bangers, TextColor3 = isCorpse and Color3.fromRGB(150, 100, 20) or INK })
	label(paper, { Position = UDim2.fromScale(0.1, 0.185), Size = UDim2.fromScale(0.8, 0.05), Text = isCorpse and "SAINT'S CORPSE" or "DEAD OR ALIVE", Font = Enum.Font.GothamBold, TextColor3 = INK:Lerp(PAPER, 0.25) })
	local photo = photoFor(entry, paper)
	photo.Position = UDim2.fromScale(0.15, 0.25)
	photo.Size = UDim2.fromScale(0.7, 0.36)
	new("UIStroke", { Color = INK, Thickness = 2 }, photo)
	label(paper, { Position = UDim2.fromScale(0.05, 0.63), Size = UDim2.fromScale(0.9, 0.08), Text = isCorpse and string.upper((entry.Name:gsub("^SAINT'S CORPSE: ", ""))) or string.upper(entry.Name), TextTruncate = Enum.TextTruncate.AtEnd })
	local stand = standOf(entry.Act)
	if isCorpse then
		label(paper, { Position = UDim2.fromScale(0.05, 0.71), Size = UDim2.fromScale(0.9, 0.05), Text = entry.HeldBy and ("HELD BY " .. string.upper(entry.HeldBy)) or "LYING IN THE DESERT", Font = Enum.Font.GothamBold, TextColor3 = entry.HeldBy and RED or INK:Lerp(PAPER, 0.3) })
	elseif stand then
		label(paper, { Position = UDim2.fromScale(0.05, 0.71), Size = UDim2.fromScale(0.9, 0.05), Text = "STAND: " .. stand, Font = Enum.Font.GothamBold, TextColor3 = themeOf(entry.Act):Lerp(INK, 0.5) })
	end
	-- Danger pips: more pips, more reward.
	local danger = math.clamp(math.floor(entry.Reward / 75 + 0.5), 1, 5)
	for i = 1, 5 do
		local pip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, (i - 3) * 13, 0.795, 0), Size = UDim2.fromOffset(7, 7), Rotation = 45, BackgroundColor3 = i <= danger and RED or PAPER_DARK }, paper)
		new("UIStroke", { Color = INK, Thickness = 1, Transparency = 0.4 }, pip)
	end
	-- Reward ribbon.
	local ribbon = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.84, 0), Size = UDim2.fromScale(0.72, 0.12), BackgroundColor3 = RED }, paper)
	corner(ribbon, 4)
	label(ribbon, { Size = UDim2.fromScale(1, 1), Text = "$" .. entry.Reward, Font = Enum.Font.Bangers, TextColor3 = PAPER })
	if entry.Corpse then
		-- A gold "SAINT'S CORPSE" tag: they're carrying parts.
		local tagC = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -16), Size = UDim2.fromOffset(120, 18), BackgroundColor3 = GOLD, Rotation = -4, ZIndex = 4 }, paper)
		corner(tagC, 4)
		label(tagC, { Size = UDim2.fromScale(1, 1), Text = "SAINT'S CORPSE", Font = Enum.Font.GothamBlack, TextColor3 = INK, TextScaled = true, ZIndex = 4 })
	end
	if entry.Placed then
		local priceTag = new("Frame", { AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, -8, 0, -8), Size = UDim2.fromOffset(62, 22), BackgroundColor3 = GOLD, Rotation = -10, ZIndex = 3 }, paper)
		corner(priceTag, 6)
		label(priceTag, { Size = UDim2.fromScale(1, 1), Text = "+$" .. entry.Placed, Font = Enum.Font.Bangers, TextColor3 = INK, ZIndex = 3 })
	end
	if (entry.Streak or 0) > 0 then
		local badge = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(46, 22), BackgroundColor3 = INK, Rotation = 8, ZIndex = 3 }, paper)
		corner(badge, 6)
		label(badge, { Size = UDim2.fromScale(1, 1), Text = "x" .. entry.Streak .. " KILLS", TextColor3 = GOLD, ZIndex = 3 })
	end
	-- "CLICK TO HUNT" tag shown while hovered.
	local tag = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 14), Size = UDim2.fromOffset(110, 20), BackgroundColor3 = INK, BackgroundTransparency = 1, ZIndex = 4 }, paper)
	corner(tag, 6)
	local tagText = label(tag, { Size = UDim2.fromScale(1, 1), Text = "CLICK TO HUNT", TextColor3 = GOLD, TextTransparency = 1, ZIndex = 4 })
	if current and current.Key == entry.Key then
		local stamp = label(paper, { Position = UDim2.fromScale(0.05, 0.34), Size = UDim2.fromScale(0.9, 0.18), Rotation = -18, Text = "HUNTING", Font = Enum.Font.Bangers, TextColor3 = RED, TextTransparency = 0.1, ZIndex = 3 })
		new("UIStroke", { Color = RED, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.3 }, stamp)
	end
	-- Hover: straighten, lift, grow, glow gold, cast a bigger shadow.
	paper.MouseEnter:Connect(function()
		holder.ZIndex = 5
		TweenService:Create(paper, FAST, { Rotation = 0, Position = UDim2.fromOffset(0, -10) }):Play()
		TweenService:Create(scale, FAST, { Scale = 1.1 }):Play()
		TweenService:Create(edge, SOFT, { Color = GLOW, Thickness = 3, Transparency = 0 }):Play()
		TweenService:Create(shadow, SOFT, { BackgroundTransparency = 0.55, Rotation = 0, Position = UDim2.fromOffset(10, 10) }):Play()
		TweenService:Create(tag, SOFT, { BackgroundTransparency = 0.1 }):Play()
		TweenService:Create(tagText, SOFT, { TextTransparency = 0 }):Play()
	end)
	paper.MouseLeave:Connect(function()
		holder.ZIndex = 1
		TweenService:Create(paper, SOFT, { Rotation = tilt, Position = UDim2.fromOffset(0, 0) }):Play()
		TweenService:Create(scale, SOFT, { Scale = 1 }):Play()
		TweenService:Create(edge, SOFT, { Color = BURNT, Thickness = 2, Transparency = 0.25 }):Play()
		TweenService:Create(shadow, SOFT, { BackgroundTransparency = 0.82, Rotation = tilt, Position = UDim2.fromOffset(5, 6) }):Play()
		TweenService:Create(tag, SOFT, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(tagText, SOFT, { TextTransparency = 1 }):Play()
	end)
	paper.Activated:Connect(function()
		-- A little "tug" when picked.
		scale.Scale = 1.18
		TweenService:Create(scale, FAST, { Scale = 1.1 }):Play()
		showConfirm(entry)
	end)
	-- Posters drop onto the board one after another.
	paper.Position = UDim2.fromOffset(0, -40)
	task.delay(0.15 + index * 0.05, function()
		TweenService:Create(paper, FAST, { Position = UDim2.fromOffset(0, 0) }):Play()
	end)
end

---------------------------------------------------------------------------
-- JOBS and SHOP (drawn in the same space as the posters)
---------------------------------------------------------------------------
local function paperCard(parent, pos, size, tilt)
	local card = new("Frame", { Position = pos, Size = size, BackgroundColor3 = PAPER, Rotation = tilt or 0 }, parent)
	corner(card, 4)
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, PAPER_DARK), ColorSequenceKeypoint.new(0.4, PAPER), ColorSequenceKeypoint.new(1, PAPER_DARK) }), Rotation = 80 }, card)
	new("UIStroke", { Color = BURNT, Thickness = 2, Transparency = 0.25 }, card)
	local pin = new("Frame", { BackgroundColor3 = RED, Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, 10, 0, -4), ZIndex = 3 }, card)
	corner(pin, 99)
	return card
end

local function showJobs()
	local y = 16
	for i, job in ipairs(lastJobs) do
		local card = paperCard(grid, UDim2.fromOffset(14, y), UDim2.new(1, -40, 0, 92), ((i * 37) % 5 - 2) * 0.4)
		label(card, { Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(60, 20), Text = "JOB", Font = Enum.Font.Bangers, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Left })
		local text = label(card, { Position = UDim2.fromOffset(16, 28), Size = UDim2.new(1, -170, 0, 24), Text = string.upper(job.Text), TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
		new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 9 }, text)
		-- Progress bar.
		local bar = new("Frame", { Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -170, 0, 16), BackgroundColor3 = PAPER_DARK }, card)
		corner(bar, 6)
		new("UIStroke", { Color = INK, Thickness = 1, Transparency = 0.4 }, bar)
		local k = math.clamp((job.Progress or 0) / math.max(job.Goal or 1, 1), 0, 1)
		local fill = new("Frame", { Size = UDim2.fromScale(k, 1), BackgroundColor3 = job.Done and GREEN or GOLD }, bar)
		corner(fill, 6)
		label(bar, { Size = UDim2.fromScale(1, 1), Text = (job.Progress or 0) .. " / " .. (job.Goal or 1), Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = INK })
		local ribbon = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(120, 44), BackgroundColor3 = job.Done and GREEN or RED }, card)
		corner(ribbon, 6)
		label(ribbon, { Size = UDim2.fromScale(1, 1), Text = job.Done and "PAID" or ("$" .. (job.Reward or 0)), Font = Enum.Font.Bangers, TextColor3 = PAPER })
		if job.Done then
			local stamp = label(card, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.42, 0.5), Size = UDim2.fromOffset(160, 50), Rotation = -12, Text = "DONE", Font = Enum.Font.Bangers, TextColor3 = GREEN, TextTransparency = 0.15, ZIndex = 3 })
			new("UIStroke", { Color = GREEN, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.3 }, stamp)
		end
		y = y + 104
	end
	jobsTimer = new("Frame", { Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -40, 0, 28), BackgroundTransparency = 1 }, grid)
	label(jobsTimer, { Name = "Text", Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = PAPER, Font = Enum.Font.GothamBold })
	label(jobsTimer, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 18), Text = "Progress counts on its own. You're paid the moment a job's done.", TextColor3 = PAPER_DARK, Font = Enum.Font.GothamMedium })
	grid.CanvasSize = UDim2.fromOffset(0, y + 60)
	return #lastJobs
end

-- STABLE: customise your horse (ride it with M): coat, mane & tail,
-- blanket, saddle, marking, socks and its name.
local STABLE_SECTIONS = {
	{ List = "Coats", Kind = "Coat", Title = "COAT" },
	{ List = "Manes", Kind = "Mane", Title = "MANE & TAIL" },
	{ List = "Blankets", Kind = "Blanket", Title = "SADDLE BLANKET" },
	{ List = "Saddles", Kind = "Saddle", Title = "SADDLE & BRIDLE" },
	{ List = "Markings", Kind = "Marking", Title = "FACE MARKING" },
	{ List = "Socks", Kind = "Socks", Title = "WHITE SOCKS" },
}

local function stableSelection()
	local sel = {}
	for _, sec in ipairs(STABLE_SECTIONS) do
		for _, item in ipairs(lastStable[sec.List] or {}) do
			if item.Equipped then
				sel[sec.Kind] = item.Id
			end
		end
	end
	return sel
end

local MARK_ICONS = { Blaze = "|", None = "-", Star = "*", Stripe = "!", Bald = "O" }
local SOCK_ICONS = { Two = "2", None = "0", Front = "F", Back = "B", Four = "4" }

showStable = function(y, cash)
	stablePreview = nil
	if #(lastStable.Coats or {}) == 0 then
		return y
	end
	local head = new("Frame", { Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -40, 0, 30), BackgroundColor3 = WOOD_DARK }, grid)
	corner(head, 6)
	label(head, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), Text = "STABLE  ·  CUSTOMISE YOUR HORSE  (PRESS M TO RIDE)", Font = Enum.Font.Bangers, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left })
	y = y + 40
	-- Left: a spinning preview and the name box.
	local panel = paperCard(grid, UDim2.fromOffset(14, y), UDim2.fromOffset(200, 290), 0)
	local vp = new("ViewportFrame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 190), BackgroundColor3 = Color3.fromRGB(230, 210, 170), Ambient = Color3.fromRGB(200, 190, 170), LightColor = Color3.new(1, 1, 1) }, panel)
	corner(vp, 4)
	local nameText = lastStable.Name and string.upper(lastStable.Name) or "YOUR HORSE"
	label(panel, { Position = UDim2.fromOffset(8, 200), Size = UDim2.new(1, -16, 0, 24), Text = nameText, Font = Enum.Font.Bangers })
	local box = new("TextBox", { Position = UDim2.fromOffset(8, 228), Size = UDim2.new(1, -78, 0, 28), BackgroundColor3 = Color3.fromRGB(250, 240, 215), Text = "", PlaceholderText = "Name your horse", ClearTextOnFocus = false, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = INK, PlaceholderColor3 = INK:Lerp(PAPER, 0.5) }, panel)
	corner(box, 6)
	new("UIStroke", { Color = INK, Thickness = 1, Transparency = 0.4 }, box)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, box)
	local nameBtn = new("TextButton", { Position = UDim2.new(1, -66, 0, 228), Size = UDim2.fromOffset(58, 28), BackgroundColor3 = GREEN, Text = "NAME", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, panel)
	corner(nameBtn, 6)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, nameBtn)
	nameBtn.Activated:Connect(function()
		Remote:FireServer("NameHorse", string.sub(box.Text or "", 1, lastStable.NameMax or 20))
	end)
	label(panel, { Position = UDim2.fromOffset(8, 262), Size = UDim2.new(1, -16, 0, 20), Text = "Shown above your horse", Font = Enum.Font.GothamMedium, TextColor3 = INK:Lerp(PAPER, 0.35) })
	if HorseModel and HorseModel.lookFrom then
		local ok, horse = pcall(function()
			local body, mane, opts = HorseModel.lookFrom(TuskConfig.Horses, stableSelection())
			return HorseModel.build(body, mane, opts)
		end)
		if ok and horse then
			for _, d in ipairs(horse:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			horse.Parent = vp
			local cam = new("Camera", { FieldOfView = 40 }, vp)
			vp.CurrentCamera = cam
			stablePreview = { Camera = cam, Angle = 0.6 }
			cam.CFrame = CFrame.lookAt(Vector3.new(math.sin(0.6) * 13, 2, math.cos(0.6) * 13), Vector3.new(0, 0.2, -0.6))
		end
	end
	-- Right: every category as a row of small cards, 3 to a row.
	local function swatchCard(x, yy, item, key, sec)
		local card = paperCard(grid, UDim2.fromOffset(x, yy), UDim2.fromOffset(134, 62), 0)
		local colorA = item.Body or item.Color
		local sw = new("Frame", { Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = colorA or WOOD_DARK }, card)
		corner(sw, 99)
		new("UIStroke", { Color = INK, Thickness = 2 }, sw)
		if item.Mane then
			new("Frame", { Position = UDim2.fromOffset(13, 0), Size = UDim2.fromOffset(6, 32), BackgroundColor3 = item.Mane, BorderSizePixel = 0 }, sw)
		end
		local icon = (sec.Kind == "Marking" and MARK_ICONS[item.Style or ""]) or (sec.Kind == "Socks" and SOCK_ICONS[item.Style or ""]) or (sec.Kind == "Mane" and not colorA and "~")
		if icon then
			label(sw, { Size = UDim2.fromScale(1, 1), Text = icon, Font = Enum.Font.GothamBlack, TextColor3 = colorA and INK or GOLD })
		end
		local nameL = label(card, { Position = UDim2.fromOffset(46, 6), Size = UDim2.fromOffset(84, 18), Text = item.Name, Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left })
		new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 7 }, nameL)
		local state
		if not item.Owned then
			state = "$" .. item.Price
		else
			state = item.Equipped and "EQUIPPED" or "EQUIP"
		end
		local afford = item.Owned or cash >= item.Price
		local color = item.Equipped and GOLD or (item.Owned and WOOD_DARK or (afford and GREEN or Color3.fromRGB(130, 120, 110)))
		local btn = new("TextButton", { Position = UDim2.fromOffset(46, 30), Size = UDim2.fromOffset(80, 24), BackgroundColor3 = color, Text = state, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = item.Equipped and INK or Color3.new(1, 1, 1), AutoButtonColor = not item.Equipped }, card)
		corner(btn, 6)
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, btn)
		btn.Activated:Connect(function()
			if not item.Equipped then
				Remote:FireServer("BuyHorse", key)
			end
		end)
	end
	local x0 = 226
	local rowY = y
	for _, sec in ipairs(STABLE_SECTIONS) do
		local items = lastStable[sec.List] or {}
		if #items > 0 then
			label(grid, { Position = UDim2.fromOffset(x0, rowY - 2), Size = UDim2.fromOffset(300, 16), Text = sec.Title, Font = Enum.Font.GothamBlack, TextColor3 = PAPER, TextXAlignment = Enum.TextXAlignment.Left })
			rowY = rowY + 16
			for i, item in ipairs(items) do
				local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
				swatchCard(x0 + col * 140, rowY + row * 68, item, sec.Kind .. ":" .. item.Id, sec)
			end
			rowY = rowY + math.ceil(#items / 3) * 68 + 8
		end
	end
	return math.max(rowY, y + 300)
end

local function showShop()
	local cash = 0
	local ls = player:FindFirstChild("leaderstats")
	local cv = ls and ls:FindFirstChild("Cash")
	cash = cv and cv.Value or 0
	for i, item in ipairs(lastShop) do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		local card = paperCard(grid, UDim2.fromOffset(14 + col * 316, 16 + row * 134), UDim2.fromOffset(300, 122), ((i * 53) % 5 - 2) * 0.5)
		local badge = new("Frame", { Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(54, 54), BackgroundColor3 = item.Id == "ClearName" and INK or WOOD_DARK }, card)
		corner(badge, 99)
		new("UIStroke", { Color = GOLD, Thickness = 2 }, badge)
		label(badge, { Size = UDim2.fromScale(1, 1), Text = item.Icon or "?", Font = Enum.Font.Bangers, TextColor3 = GOLD, TextScaled = true })
		local name = label(card, { Position = UDim2.fromOffset(76, 10), Size = UDim2.new(1, -86, 0, 22), Text = item.Name, Font = Enum.Font.Bangers, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
		new("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 10 }, name)
		local desc = label(card, { Position = UDim2.fromOffset(76, 34), Size = UDim2.new(1, -86, 0, 36), Text = item.Text, Font = Enum.Font.GothamMedium, TextWrapped = true, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
		new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, desc)
		local clean = item.Clean
		local price = item.Price or 0
		local afford = cash >= price and not clean
		local buy = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -10), Size = UDim2.fromOffset(150, 36), BackgroundColor3 = afford and GREEN or Color3.fromRGB(130, 120, 110), Text = clean and "ALREADY CLEAN" or ("BUY  $" .. price), Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = afford }, card)
		corner(buy, 8)
		new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, buy)
		new("UIStroke", { Color = (afford and GREEN or INK):Lerp(Color3.new(0, 0, 0), 0.4), Thickness = 2 }, buy)
		if item.Active then
			local left = math.max(0, item.Active - workspace:GetServerTimeNow())
			label(card, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(120, 18), Text = string.format("ACTIVE %d:%02d", math.floor(left / 60), math.floor(left % 60)), Font = Enum.Font.GothamBlack, TextColor3 = GREEN, TextXAlignment = Enum.TextXAlignment.Left })
		end
		buy.Activated:Connect(function()
			if clean then
				return
			end
			local s = buy:FindFirstChildOfClass("UIScale") or new("UIScale", { Scale = 1 }, buy)
			s.Scale = 0.9
			TweenService:Create(s, FAST, { Scale = 1 }):Play()
			Remote:FireServer("Buy", item.Id)
		end)
	end
	local y = 16 + math.ceil(#lastShop / 2) * 134 + 6
	y = showStable(y, cash)
	grid.CanvasSize = UDim2.fromOffset(0, y + 20)
	return #lastShop
end

local function fillGrid()
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	jobsTimer = nil
	if filter == "JOBS" or filter == "SHOP" then
		local n = filter == "JOBS" and showJobs() or showShop()
		local empty = grid:FindFirstChild("Empty")
		empty.Visible = n == 0
		empty.Text = filter == "JOBS" and "No jobs right now." or "The shop is closed."
		for name, tab in pairs(tabs) do
			local on = name == filter
			tab.BackgroundColor3 = on and GOLD or WOOD_DARK
			tab.TextColor3 = on and INK or PAPER
		end
		countLabel.Text = filter == "JOBS" and "PAID TASKS" or "SPEND YOUR CASH"
		return
	end
	local shown = {}
	for _, entry in ipairs(lastList) do
		if filter == "ALL" or (filter == "PLAYERS" and entry.Kind == "Player") or (filter == "NPCS" and entry.Kind == "NPC") or (filter == "CORPSE" and entry.Kind == "Corpse") then
			table.insert(shown, entry)
		end
	end
	-- ALL: corpse contracts are spread out among the other bounties (evenly)
	-- instead of all sitting together; the CORPSE tab still groups them.
	if filter == "ALL" then
		local others, parts = {}, {}
		for _, entry in ipairs(shown) do
			table.insert(entry.Kind == "Corpse" and parts or others, entry)
		end
		if #parts > 0 and #others > 0 then
			local mixed = {}
			local step = (#others + #parts) / #parts
			local nextAt = step / 2 -- first one partway in, not at the very top
			local pi = 1
			for _, entry in ipairs(others) do
				while pi <= #parts and #mixed + 1 >= nextAt do
					table.insert(mixed, parts[pi])
					pi = pi + 1
					nextAt = nextAt + step
				end
				table.insert(mixed, entry)
			end
			for i = pi, #parts do
				table.insert(mixed, parts[i])
			end
			shown = mixed
		end
	end
	local empty = grid:FindFirstChild("Empty")
	empty.Visible = #shown == 0
	empty.Text = filter == "PLAYERS" and "No other players are wanted right now.\n(Testing alone? Try Test > Clients and Servers.)" or "No bounties right now. Check back later!"
	for i, entry in ipairs(shown) do
		makePoster(entry, i)
	end
	grid.CanvasSize = UDim2.fromOffset(0, 30 + math.ceil(#shown / 4) * 222)
	for name, tab in pairs(tabs) do
		local on = name == filter
		tab.BackgroundColor3 = on and GOLD or WOOD_DARK
		tab.TextColor3 = on and INK or PAPER
	end
	local players, npcs, parts = 0, 0, 0
	for _, e in ipairs(lastList) do
		if e.Kind == "Player" then
			players = players + 1
		elseif e.Kind == "Corpse" then
			parts = parts + 1
		else
			npcs = npcs + 1
		end
	end
	countLabel.Text = players .. " PLAYERS · " .. npcs .. " NPCS · " .. parts .. " PARTS"
end

local function openBoard(data)
	confirmLayer.Visible = false
	current = data.Active or current
	lastList = data.Bounties or {}
	lastJobs, lastShop, jobsUntil = data.Jobs or {}, data.Shop or {}, data.JobsUntil or 0
	lastStable = data.Stable or lastStable
	placeAmount = data.PlaceAmount or placeAmount
	cashLabel.Text = cashText()
	huntingLabel.Text = current and ("HUNTING: " .. string.upper(current.Name)) or "NO ACTIVE BOUNTY"
	fillGrid()
	local scale = board:FindFirstChildOfClass("UIScale")
	local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	scale.Scale = math.min(1, (view.X - 24) / 700, (view.Y - 24) / 560)
	-- Drop in from the top.
	openToken = openToken + 1
	dim.Visible = true
	dim.BackgroundTransparency = 1
	board.Position = UDim2.fromScale(0.5, -0.6)
	TweenService:Create(dim, SOFT, { BackgroundTransparency = 0.4 }):Play()
	TweenService:Create(board, SLIDE, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
end

local function buildBoard()
	dim = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), Visible = false }, gui)
	dim.Activated:Connect(closeBoard)
	-- Board: a dark wood frame round plank boards.
	board = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 560), BackgroundColor3 = WOOD_DARK }, dim)
	corner(board, 8)
	new("UIScale", { Scale = 1 }, board)
	new("UIStroke", { Color = Color3.fromRGB(45, 28, 16), Thickness = 3 }, board)
	local inner = new("Frame", { BackgroundColor3 = WOOD, Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 1, -24), ClipsDescendants = true }, board)
	corner(inner, 4)
	for i = 0, 7 do
		local plank = new("Frame", { BackgroundColor3 = (i % 3 == 0) and WOOD_LIGHT or (i % 3 == 1 and WOOD or Color3.fromRGB(122, 82, 50)), BorderSizePixel = 0, Position = UDim2.fromOffset(0, i * 68), Size = UDim2.new(1, 0, 0, 66) }, inner)
		-- Wood grain lines and a seam under each plank.
		for g = 1, 3 do
			local line = new("Frame", { BackgroundColor3 = WOOD_DARK, BorderSizePixel = 0, BackgroundTransparency = 0.55, Position = UDim2.new(((i * 7 + g * 13) % 10) / 20, 0, 0, 10 + g * 15 + (i % 2) * 4), Size = UDim2.new(0.5 + ((i + g) % 4) * 0.1, 0, 0, 2) }, plank)
			new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0), NumberSequenceKeypoint.new(0.7, 0), NumberSequenceKeypoint.new(1, 1) }) }, line)
		end
		new("Frame", { BackgroundColor3 = Color3.fromRGB(50, 32, 18), BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 2) }, plank)
		for _, x in ipairs({ 0, 1 }) do
			local nail = new("Frame", { BackgroundColor3 = NAIL, AnchorPoint = Vector2.new(x, 0.5), Position = UDim2.new(x, x == 0 and 8 or -8, 0.5, 0), Size = UDim2.fromOffset(6, 6) }, plank)
			corner(nail, 99)
		end
	end
	-- Dark edges (vignette) over the planks.
	local shade = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, inner)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.15, 1), NumberSequenceKeypoint.new(0.85, 1), NumberSequenceKeypoint.new(1, 0.55) }) }, shade)
	-- Metal corner brackets.
	for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		local bracket = new("Frame", { AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(90, 92, 100), ZIndex = 3 }, board)
		corner(bracket, 5)
		new("UIStroke", { Color = Color3.fromRGB(40, 40, 46), Thickness = 2 }, bracket)
		local bolt = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.fromRGB(170, 172, 180), ZIndex = 3 }, bracket)
		corner(bolt, 99)
	end
	-- Hanging title sign (inside the board, so it never goes off-screen).
	for _, x in ipairs({ -120, 120 }) do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, x, 0, 0), Size = UDim2.fromOffset(3, 18), BackgroundColor3 = Color3.fromRGB(200, 170, 110), BorderSizePixel = 0, ZIndex = 4 }, board)
	end
	local sign = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(330, 54), BackgroundColor3 = WOOD_DARK, ZIndex = 4 }, board)
	corner(sign, 6)
	new("UIStroke", { Color = Color3.fromRGB(40, 24, 12), Thickness = 2 }, sign)
	label(sign, { Size = UDim2.new(1, 0, 0.78, 0), Text = "BOUNTY BOARD", Font = Enum.Font.Bangers, TextColor3 = PAPER, TextStrokeTransparency = 0.4, ZIndex = 4 })
	label(sign, { Position = UDim2.fromScale(0, 0.72), Size = UDim2.fromScale(1, 0.24), Text = "HUNT THEM DOWN · GET PAID", Font = Enum.Font.GothamBold, TextColor3 = GOLD, ZIndex = 4 })
	local close = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 20), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = RED, Text = "X", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), ZIndex = 4 }, board)
	corner(close, 99)
	new("UIStroke", { Color = Color3.fromRGB(90, 15, 12), Thickness = 2 }, close)
	close.Activated:Connect(closeBoard)
	-- Header strip: cash, tabs, current bounty.
	local strip = new("Frame", { Position = UDim2.fromOffset(22, 78), Size = UDim2.new(1, -44, 0, 34), BackgroundColor3 = Color3.fromRGB(40, 26, 15), BackgroundTransparency = 0.25, ZIndex = 4 }, board)
	corner(strip, 8)
	local cashChip = new("Frame", { Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(86, 26), BackgroundColor3 = GOLD, ZIndex = 4 }, strip)
	corner(cashChip, 6)
	cashLabel = label(cashChip, { Size = UDim2.fromScale(1, 1), Text = "$0", Font = Enum.Font.Bangers, ZIndex = 4 })
	for i, name in ipairs({ "ALL", "PLAYERS", "NPCS", "CORPSE", "JOBS", "SHOP" }) do
		local x = 98 + (i - 1) * 60 + (i >= 5 and 8 or 0) -- a little gap before JOBS / SHOP
		local tab = new("TextButton", { Position = UDim2.fromOffset(x, 4), Size = UDim2.fromOffset(56, 26), BackgroundColor3 = WOOD_DARK, Text = name, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = PAPER, ZIndex = 4 }, strip)
		corner(tab, 6)
		new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, tab)
		tab.Activated:Connect(function()
			filter = name
			fillGrid()
		end)
		tabs[name] = tab
	end
	huntingLabel = label(strip, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 2), Size = UDim2.fromOffset(170, 16), Text = "", TextColor3 = PAPER, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
	countLabel = label(strip, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 18), Size = UDim2.fromOffset(170, 12), Text = "", Font = Enum.Font.GothamBold, TextColor3 = PAPER_DARK, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
	grid = new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(22, 118), Size = UDim2.new(1, -44, 1, -136), ScrollBarThickness = 6, ScrollBarImageColor3 = PAPER_DARK, CanvasSize = UDim2.new(), ZIndex = 4 }, board)
	label(grid, { Name = "Empty", Position = UDim2.fromScale(0.08, 0.32), Size = UDim2.fromScale(0.84, 0.14), Text = "", TextColor3 = PAPER, Visible = false, ZIndex = 4 })

	-- The contract card (Accept / Decline) sits on its own layer above the
	-- board, so nothing on the board can cover it or swallow its clicks.
	local top = new("ScreenGui", { Name = "BountyConfirm", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 9 }, player:WaitForChild("PlayerGui"))
	confirmLayer = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Size = UDim2.fromScale(1, 1), Visible = false }, top)
	confirmLayer.Activated:Connect(function()
		confirmLayer.Visible = false
	end)
	confirm = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 470), BackgroundColor3 = PAPER }, confirmLayer)
	corner(confirm, 8)
	new("UIScale", { Scale = 1 }, confirm)
	new("UIStroke", { Color = BURNT, Thickness = 4 }, confirm)
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, PAPER_DARK), ColorSequenceKeypoint.new(0.4, PAPER), ColorSequenceKeypoint.new(1, PAPER_DARK) }), Rotation = 80 }, confirm)
	-- Fits small screens too.
	new("UISizeConstraint", { MaxSize = Vector2.new(380, 470) }, confirm)
	local body = new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, confirm)
	-- Header band like a stamped document.
	local head = new("Frame", { BackgroundColor3 = WOOD_DARK, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 54) }, body)
	corner(head, 8)
	new("Frame", { BackgroundColor3 = WOOD_DARK, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -8), Size = UDim2.new(1, 0, 0, 8) }, head)
	label(head, { Position = UDim2.fromOffset(16, 4), Size = UDim2.new(1, -32, 0, 32), Text = "BOUNTY CONTRACT", Font = Enum.Font.Bangers, TextColor3 = GOLD })
	label(head, { Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -32, 0, 14), Text = "WANTED · DEAD OR ALIVE", Font = Enum.Font.GothamBold, TextColor3 = PAPER })
	-- Danger pips (filled from the reward) under the photo.
	local pips = new("Frame", { Name = "Pips", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 212), Size = UDim2.fromOffset(100, 12) }, body)
	confirmPips = {}
	for i = 1, 5 do
		confirmPips[i] = new("Frame", { Name = "Pip" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, (i - 3) * 18, 0.5, 0), Size = UDim2.fromOffset(9, 9), Rotation = 45, BackgroundColor3 = PAPER_DARK }, pips)
	end
	-- Name (shrinks to fit, never cut off) and Stand.
	local who = label(body, { Name = "Who", Position = UDim2.fromOffset(18, 230), Size = UDim2.new(1, -36, 0, 30), Text = "", TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 12 }, who)
	local standLine = label(body, { Name = "Stand", Position = UDim2.fromOffset(18, 260), Size = UDim2.new(1, -36, 0, 16), Text = "", Font = Enum.Font.GothamBold, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 9 }, standLine)
	-- Reward on a red ribbon.
	local ribbon = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 284), Size = UDim2.fromOffset(190, 50), BackgroundColor3 = RED }, body)
	corner(ribbon, 6)
	new("UIStroke", { Color = RED:Lerp(Color3.new(0, 0, 0), 0.4), Thickness = 2 }, ribbon)
	confirmPay = label(ribbon, { Name = "Pay", Size = UDim2.fromScale(1, 1), Text = "", Font = Enum.Font.Bangers, TextColor3 = Color3.new(1, 1, 1), TextScaled = true })
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, ribbon)
	label(body, { Name = "Note", Position = UDim2.fromOffset(24, 340), Size = UDim2.new(1, -48, 0, 44), Text = "", Font = Enum.Font.GothamMedium, TextWrapped = true, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 9 }, body:FindFirstChild("Note"))
	local stamp = label(body, { Name = "Stamp", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(250, 70), Rotation = -14, Text = "ACCEPTED", Font = Enum.Font.Bangers, TextColor3 = RED, Visible = false, ZIndex = 5 })
	new("UIStroke", { Color = RED, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, stamp)
	local stampScale = new("UIScale", { Scale = 1 }, stamp)
	local function button(text, color, x)
		local b = new("TextButton", { Position = UDim2.new(x, 0, 1, -70), Size = UDim2.new(0.42, 0, 0, 50), BackgroundColor3 = color, Text = text, Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, body)
		corner(b, 8)
		new("UIStroke", { Color = color:Lerp(Color3.new(0, 0, 0), 0.45), Thickness = 2 }, b)
		new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, b)
		local s = new("UIScale", { Scale = 1 }, b)
		b.MouseEnter:Connect(function()
			TweenService:Create(s, FAST, { Scale = 1.08 }):Play()
		end)
		b.MouseLeave:Connect(function()
			TweenService:Create(s, SOFT, { Scale = 1 }):Play()
		end)
		return b
	end
	-- PUT A PRICE ON THEIR HEAD (players only).
	placeButton = new("TextButton", { Name = "Place", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 66), Size = UDim2.fromOffset(96, 58), BackgroundColor3 = GOLD, Text = "", AutoButtonColor = true, Visible = false, ZIndex = 3 }, body)
	corner(placeButton, 8)
	new("UIStroke", { Color = WOOD_DARK, Thickness = 2 }, placeButton)
	label(placeButton, { Name = "Top", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 22), Text = "+$100", Font = Enum.Font.Bangers, TextScaled = true, ZIndex = 3 })
	label(placeButton, { Position = UDim2.fromOffset(4, 28), Size = UDim2.new(1, -8, 0, 24), Text = "PUT A PRICE ON THEIR HEAD", Font = Enum.Font.GothamBlack, TextScaled = true, TextWrapped = true, ZIndex = 3 })
	placeButton.Activated:Connect(function()
		if confirmEntry and confirmEntry.Kind == "Player" then
			Remote:FireServer("Place", confirmEntry.Key)
			confirmLayer.Visible = false
		end
	end)
	local accepting = false
	button("ACCEPT", GREEN, 0.06).Activated:Connect(function()
		if accepting or not confirmEntry then
			return
		end
		accepting = true
		-- Thump an ACCEPTED stamp onto the contract, then go.
		stamp.Visible = true
		stampScale.Scale = 2.2
		TweenService:Create(stampScale, FAST, { Scale = 1 }):Play()
		local entry = confirmEntry
		task.delay(0.45, function()
			accepting = false
			Remote:FireServer("Accept", entry.Key)
			closeBoard()
		end)
	end)
	button("DECLINE", RED, 0.52).Activated:Connect(function()
		confirmLayer.Visible = false
	end)
end

---------------------------------------------------------------------------
-- Tracker, target marker, banner
---------------------------------------------------------------------------
local function targetModel()
	if not current then
		return nil
	end
	if current.Kind == "Player" then
		local p = Players:GetPlayerByUserId(current.UserId)
		return p and p.Character
	end
	if current.Kind == "Corpse" then
		return corpseHolder(current.Part) or corpseRelic(current.Part)
	end
	return current.Model
end

local function setMarker(model)
	local head = model and (model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	if not head then
		marker.Enabled = false
		return
	end
	marker.Adornee = head
	marker.Enabled = true
end

local function buildTracker()
	-- On the right side of the screen (the character card is top-left).
	tracker = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.42, 0), Size = UDim2.fromOffset(270, 88), BackgroundColor3 = PAPER, Visible = false }, gui)
	corner(tracker, 8)
	new("UIStroke", { Color = WOOD_DARK, Thickness = 3 }, tracker)
	local strip = new("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Size = UDim2.new(0, 6, 1, 0) }, tracker)
	corner(strip, 8)
	label(tracker, { Position = UDim2.fromOffset(88, 4), Size = UDim2.fromOffset(120, 18), Text = "BOUNTY", Font = Enum.Font.Bangers, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Left })
	local trackWho = label(tracker, { Name = "Who", Position = UDim2.fromOffset(88, 22), Size = UDim2.fromOffset(150, 20), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 8 }, trackWho)
	label(tracker, { Name = "Pay", Position = UDim2.fromOffset(88, 42), Size = UDim2.fromOffset(160, 20), Text = "", Font = Enum.Font.Bangers, TextColor3 = GREEN, TextXAlignment = Enum.TextXAlignment.Left })
	label(tracker, { Name = "Info", Position = UDim2.fromOffset(88, 64), Size = UDim2.fromOffset(170, 14), Text = "", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left })
	local quit = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = RED, Text = "X", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, tracker)
	corner(quit, 6)
	quit.Activated:Connect(function()
		Remote:FireServer("Abandon")
	end)

	marker = new("BillboardGui", { Size = UDim2.fromOffset(90, 70), StudsOffset = Vector3.new(0, 3.2, 0), AlwaysOnTop = true, LightInfluence = 0, Enabled = false }, gui)
	label(marker, { Size = UDim2.new(1, 0, 0, 22), Text = "TARGET", Font = Enum.Font.Bangers, TextColor3 = RED, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.new(1, 1, 1) })
	local arrow = new("Frame", { Name = "Arrow", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.fromOffset(22, 22), Rotation = 45, BackgroundColor3 = RED }, marker)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, arrow)

	banner = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(560, 80), Text = "", Font = Enum.Font.Bangers, TextColor3 = GOLD, TextStrokeTransparency = 0, Visible = false })
	new("UIScale", { Scale = 1 }, banner)
end

local function showActive(b)
	current = b
	tracker.Visible = true
	for _, c in ipairs(tracker:GetChildren()) do
		if c.Name == "Photo" then
			c:Destroy()
		end
	end
	local photo = photoFor(b, tracker)
	photo.Position = UDim2.fromOffset(14, 10)
	photo.Size = UDim2.fromOffset(68, 68)
	corner(photo, 6)
	tracker:FindFirstChild("Who").Text = string.upper(b.Name)
	tracker:FindFirstChild("Pay").Text = "$" .. b.Reward
	tracker.Position = UDim2.new(1, 290, 0.42, 0)
	TweenService:Create(tracker, FAST, { Position = UDim2.new(1, -12, 0.42, 0) }):Play()
end

local function clearActive()
	current = nil
	tracker.Visible = false
	marker.Enabled = false
end

local function showBanner(text, color)
	banner.Text = text
	banner.TextColor3 = color
	banner.Visible = true
	local scale = banner:FindFirstChildOfClass("UIScale")
	scale.Scale = 0.4
	TweenService:Create(scale, FAST, { Scale = 1 }):Play()
	task.delay(2.6, function()
		if banner.Text == text then
			banner.Visible = false
		end
	end)
end

function BountyUI.step()
	if stablePreview and stablePreview.Camera.Parent and dim and dim.Visible then
		stablePreview.Angle = stablePreview.Angle + 0.01
		local a = stablePreview.Angle
		stablePreview.Camera.CFrame = CFrame.lookAt(Vector3.new(math.sin(a) * 13, 2, math.cos(a) * 13), Vector3.new(0, 0.2, -0.6))
	end
	if jobsTimer and jobsTimer.Parent then
		local left = math.max(0, jobsUntil - workspace:GetServerTimeNow())
		jobsTimer:FindFirstChild("Text").Text = string.format("NEW JOBS IN %d:%02d", math.floor(left / 60), math.floor(left % 60))
	end
	if cashLabel and dim and dim.Visible then
		cashLabel.Text = cashText()
	end
	if not current or not tracker then
		return
	end
	local model = targetModel()
	setMarker(model)
	local mine = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local theirs = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	local left = math.max(0, (current.Expires or 0) - workspace:GetServerTimeNow())
	local where = (mine and theirs) and (math.floor((theirs.Position - mine.Position).Magnitude) .. " studs") or "respawning..."
	-- A target sneaking far away is lost: no distance, no marker.
	local sneak = TuskConfig.Sneak or {}
	if model and model:GetAttribute("TuskSneaking") and mine and theirs and (theirs.Position - mine.Position).Magnitude > (sneak.HiddenFromBounty or 30) then
		where = "HIDDEN"
		marker.Enabled = false
	end
	tracker:FindFirstChild("Info").Text = string.format("%s  ·  %d:%02d", where, math.floor(left / 60), math.floor(left % 60))
	if marker.Enabled then
		marker:FindFirstChild("Arrow").Position = UDim2.new(0.5, 0, 0, 26 + math.sin(os.clock() * 5) * 4)
	end
end

function BountyUI.init()
	Remote = Net.get("Bounty")
	gui = new("ScreenGui", { Name = "BountyBoard", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 8 }, player:WaitForChild("PlayerGui"))
	buildBoard()
	buildTracker()
	Remote.OnClientEvent:Connect(function(kind, data)
		data = typeof(data) == "table" and data or {}
		if kind == "Open" then
			openBoard(data)
		elseif kind == "Active" then
			showActive(data)
			showBanner("BOUNTY ACCEPTED: " .. string.upper(data.Name or ""), PAPER)
		elseif kind == "Complete" and data.Price then
			showBanner("PRICE ON THEIR HEAD!  +$" .. tostring(data.Reward), GOLD)
		elseif kind == "Complete" then
			clearActive()
			showBanner("BOUNTY CLAIMED!  +$" .. tostring(data.Reward), GOLD)
		elseif kind == "Refresh" then
			lastList = data.Bounties or lastList
			lastJobs, lastShop, jobsUntil = data.Jobs or lastJobs, data.Shop or lastShop, data.JobsUntil or jobsUntil
			lastStable = data.Stable or lastStable
			cashLabel.Text = cashText()
			if dim.Visible then
				fillGrid()
			end
		elseif kind == "JobDone" then
			showBanner("JOB DONE!  +$" .. tostring(data.Reward), GREEN:Lerp(Color3.new(1, 1, 1), 0.4))
		elseif kind == "Bought" then
			showBanner("BOUGHT: " .. tostring(data.Name), GOLD)
		elseif kind == "Placed" then
			showBanner("$" .. tostring(data.Total) .. " ON " .. string.upper(tostring(data.Name)) .. "'S HEAD", GOLD)
		elseif kind == "Warned" then
			showBanner(string.upper(tostring(data.By)) .. " PUT A PRICE ON YOUR HEAD!  ($" .. tostring(data.Total) .. ")", Color3.fromRGB(255, 140, 120))
		elseif kind == "Denied" then
			showBanner(string.upper(tostring(data.Reason or "CAN'T DO THAT")), Color3.fromRGB(255, 160, 140))
		elseif kind == "Lost" then
			clearActive()
			showBanner(data.Reason or "BOUNTY LOST", Color3.fromRGB(255, 140, 120))
		elseif kind == "Cleared" then
			clearActive()
		end
	end)
	RunService.RenderStepped:Connect(BountyUI.step)
end

return BountyUI
end

-- ======================================================================
-- MODULE: CameraFX
-- ======================================================================
__modules["CameraFX"] = function()
--[[
	CameraFX  (StarterPlayerScripts.SpinClient.CameraFX)
	Screen-space feedback: camera shake, FOV punch, anime speed lines and
	short impact frames. All of it respects VFXQuality and cleans up.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local VFXQuality = __require("VFXQuality")
local VFXLib = __require("VFXLib")

local CameraFX = {}

local player = Players.LocalPlayer
local shakes = {}
local fovOffset = 0
local appliedFov = 0

RunService:BindToRenderStep("SpinCameraFX", Enum.RenderPriority.Camera.Value + 1, function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	local offset = Vector3.new()
	for i = #shakes, 1, -1 do
		local s = shakes[i]
		local a = (now - s.Start) / s.Duration
		if a >= 1 then
			table.remove(shakes, i)
		else
			local strength = s.Intensity * (1 - a) * (1 - a)
			local t = now * 32
			offset = offset
				+ Vector3.new(
					math.noise(t, s.Seed) * strength,
					math.noise(s.Seed, t) * strength,
					math.noise(t, t + s.Seed) * strength * 0.5
				)
		end
	end
	if offset.Magnitude > 0 then
		camera.CFrame = camera.CFrame * CFrame.new(offset) * CFrame.Angles(0, 0, offset.X * 0.02)
	end
	-- Apply FOV punch as a delta so other systems that set FOV still work.
	if fovOffset ~= appliedFov then
		camera.FieldOfView = camera.FieldOfView + (fovOffset - appliedFov)
		appliedFov = fovOffset
	end
end)

function CameraFX.shake(intensity, duration)
	intensity = intensity * VFXQuality.get().ShakeScale
	if intensity <= 0 then
		return
	end
	table.insert(shakes, { Start = os.clock(), Duration = duration or 0.35, Intensity = intensity, Seed = math.random() * 100 })
end

-- Shake scaled by distance from the camera.
function CameraFX.shakeAt(position, intensity, radius)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local d = (camera.CFrame.Position - position).Magnitude
	local falloff = math.clamp(1 - d / (radius or 80), 0, 1)
	if falloff > 0 then
		CameraFX.shake(intensity * falloff, 0.35)
	end
end

local fovJob
function CameraFX.fovPunch(amount, duration)
	if not VFXQuality.get().ScreenEffects then
		return
	end
	VFXLib.cancel(fovJob)
	fovJob = VFXLib.animate(duration or 0.35, function(a)
		fovOffset = amount * (1 - VFXLib.easeOut(a))
	end, function()
		fovOffset = 0
	end)
end

-- Held FOV offset (e.g. slight zoom while charging). nil clears.
function CameraFX.setFovHold(amount)
	if not VFXQuality.get().ScreenEffects then
		amount = 0
	end
	VFXLib.cancel(fovJob)
	fovJob = nil
	fovOffset = amount or 0
end

local function screenGui(name)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function CameraFX.speedLines(duration, color)
	if not VFXQuality.get().ScreenEffects then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local edge = math.sqrt(viewport.X * viewport.X + viewport.Y * viewport.Y) / 2
	local gui = screenGui("SpinSpeedLines")
	local lines = {}
	local count = VFXLib.particleCount(28)
	for i = 1, count do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = color or Color3.new(1, 1, 1)
		line.Parent = gui
		lines[i] = {
			Frame = line,
			Angle = (i / count) * math.pi * 2 + math.random() * 0.15,
			Inner = edge * (0.45 + math.random() * 0.25), -- where the line starts
			Thickness = math.random(1, 3),
		}
	end
	VFXLib.animate(duration or 0.3, function(a)
		for _, l in ipairs(lines) do
			-- Each line runs from its inner radius out past the screen edge,
			-- creeping inward slightly as the effect plays.
			local inner = l.Inner * (1 - 0.15 * a)
			local length = edge * 1.05 - inner
			local mid = inner + length / 2
			l.Frame.Size = UDim2.fromOffset(length, l.Thickness)
			l.Frame.Position = UDim2.new(0.5, math.cos(l.Angle) * mid, 0.5, math.sin(l.Angle) * mid)
			l.Frame.Rotation = math.deg(l.Angle)
			l.Frame.BackgroundTransparency = math.min(1, 0.2 + a * 0.8 + math.random() * 0.15)
		end
	end, function()
		gui:Destroy()
	end)
end

-- Two-frame high-contrast flash. Brief and subtle (photosensitivity-safe).
function CameraFX.impactFrame(tint)
	if not VFXQuality.get().ImpactFrames then
		return
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SpinImpactFrame"
	cc.Contrast = 0.6
	cc.Saturation = -0.6
	cc.TintColor = tint or Color3.new(1, 0.95, 0.8)
	cc.Brightness = 0.08
	cc.Parent = Lighting
	VFXLib.animate(0.12, function(a)
		cc.Contrast = 0.6 * (1 - a)
		cc.Saturation = -0.6 * (1 - a)
		cc.Brightness = 0.08 * (1 - a)
	end, function()
		cc:Destroy()
	end)
end

return CameraFX
end

-- ======================================================================
-- MODULE: CharacterCard
-- ======================================================================
__modules["CharacterCard"] = function()
--[[
	CharacterCard  (StarterPlayerScripts.SpinClient.UI.CharacterCard)

	Top-left character card:
	  * portrait: your uploaded image (TuskConfig.Character.PortraitImage),
	    or a live 3D view of your own avatar
	  * JOHNNY JOESTAR name plate (TuskConfig.Character.Name)
	  * current Stand ("TUSK ACT 2") in that Act's colour
	  * four Act pips that light up as Tusk awakens
	  * health bar with numbers
	Pops and flashes when Tusk evolves.

	DROPDOWN: tap/click the card to open the character list
	(TuskConfig.Roster): one row per character with a colour badge, name,
	Stand and a status chip; rows light up on hover and the whole row is
	clickable. Your current character is outlined and listed first. Characters whose scripts
	aren't in the game are shown as NOT INSTALLED, and characters that aren't
	finished as IN DEVELOPMENT (neither is selectable).
]]

local Players = game:GetService("Players")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local VFXLib = __require("VFXLib")

local CharacterCard = {}

local player = Players.LocalPlayer
local DARK = Color3.fromRGB(14, 12, 20)
local GOLD = Color3.fromRGB(255, 205, 90)

local gui, card, portrait, viewport, nameLabel, standLabel, pips, hpFill, hpText, scale, arrow
local dropdown, dropdownList, rosterRows
-- Declared up here so init() can call them (they are defined further down).
local buildDropdown, refreshDropdown
local shownAct
local open = false
local Net = __require("Net")

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local function stroke(p, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextStrokeTransparency = 0.4
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- Live 3D portrait of your own avatar (head and shoulders).
local function refreshViewport(character)
	if not viewport then
		return
	end
	viewport:ClearAllChildren()
	if not character then
		return
	end
	local head = character:WaitForChild("Head", 5)
	if not head then
		return
	end
	local wasArchivable = character.Archivable
	character.Archivable = true
	local ok, clone = pcall(function()
		return character:Clone()
	end)
	character.Archivable = wasArchivable
	if not ok or not clone then
		return
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("ForceField") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	clone.Parent = world
	local cloneHead = clone:FindFirstChild("Head")
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	if cloneHead then
		local h = cloneHead.CFrame
		camera.CFrame = CFrame.lookAt((h * CFrame.new(-0.9, 0.1, -3.6)).Position, h.Position - Vector3.new(0, 0.35, 0))
	end
end

local function buildPips(parent)
	pips = {}
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(98, 52)
	row.Size = UDim2.fromOffset(120, 12)
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 5)
	layout.Parent = row
	for i = 1, 4 do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(24, 8)
		pip.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		pip.BorderSizePixel = 0
		pip.Parent = row
		corner(pip, 4)
		pips[i] = pip
	end
end

function CharacterCard.init()
	local config = TuskConfig.Character
	gui = Instance.new("ScreenGui")
	gui.Name = "CharacterCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")

	card = Instance.new("Frame")
	card.Name = "Card"
	card.Position = UDim2.fromOffset(12, 10)
	card.Size = UDim2.fromOffset(330, 96)
	card.BackgroundColor3 = DARK
	card.BackgroundTransparency = 0.12
	card.Parent = gui
	corner(card, 12)
	stroke(card, GOLD, 2)
	scale = Instance.new("UIScale")
	scale.Parent = card
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(70, 40, 110), Color3.fromRGB(20, 18, 30))
	gradient.Rotation = 20
	gradient.Parent = card

	-- Portrait frame.
	local frame = Instance.new("Frame")
	frame.Position = UDim2.fromOffset(8, 8)
	frame.Size = UDim2.fromOffset(80, 80)
	frame.BackgroundColor3 = Color3.fromRGB(240, 200, 120)
	frame.ClipsDescendants = true
	frame.Parent = card
	corner(frame, 10)
	stroke(frame, Color3.fromRGB(30, 20, 10), 2)
	local frameGradient = Instance.new("UIGradient")
	frameGradient.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(190, 110, 200))
	frameGradient.Rotation = 90
	frameGradient.Parent = frame
	if config.PortraitImage ~= "" then
		portrait = Instance.new("ImageLabel")
		portrait.BackgroundTransparency = 1
		portrait.Size = UDim2.fromScale(1, 1)
		portrait.Image = config.PortraitImage
		portrait.ScaleType = Enum.ScaleType.Crop
		portrait.Parent = frame
	else
		viewport = Instance.new("ViewportFrame")
		viewport.BackgroundTransparency = 1
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.Ambient = Color3.fromRGB(170, 160, 150)
		viewport.LightColor = Color3.fromRGB(255, 240, 220)
		viewport.LightDirection = Vector3.new(-1, -1, -1)
		viewport.Parent = frame
	end

	nameLabel = label(card, {
		Position = UDim2.fromOffset(98, 6),
		Size = UDim2.new(1, -130, 0, 28),
		Font = Enum.Font.Bangers,
		TextScaled = true, -- long names ("FUNNY VALENTINE") shrink to fit
		TextColor3 = GOLD,
		Text = config.Name,
	})
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = 28
	nameLimit.MinTextSize = 14
	nameLimit.Parent = nameLabel
	standLabel = label(card, {
		Position = UDim2.fromOffset(98, 33),
		Size = UDim2.new(1, -106, 0, 16),
		Font = Enum.Font.GothamBlack,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(200, 220, 255),
		Text = config.Title,
	})
	buildPips(card)

	local hp = Instance.new("Frame")
	hp.Position = UDim2.fromOffset(98, 70)
	hp.Size = UDim2.new(1, -108, 0, 14)
	hp.BackgroundColor3 = Color3.fromRGB(40, 20, 25)
	hp.Parent = card
	corner(hp, 5)
	hpFill = Instance.new("Frame")
	hpFill.BorderSizePixel = 0
	hpFill.BackgroundColor3 = Color3.fromRGB(90, 220, 120)
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.Parent = hp
	corner(hpFill, 5)
	hpText = label(hp, {
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		ZIndex = 2,
	})

	-- The whole card is a button that opens the character dropdown.
	arrow = label(card, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(20, 20),
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "▼",
		ZIndex = 3,
	})
	local hit = Instance.new("TextButton")
	hit.Name = "OpenCharacters"
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 4
	hit.Parent = card
	hit.Activated:Connect(CharacterCard.toggle)
	local cardStroke = card:FindFirstChildOfClass("UIStroke")
	hit.MouseEnter:Connect(function()
		if cardStroke then
			cardStroke.Thickness = 3
		end
	end)
	hit.MouseLeave:Connect(function()
		if cardStroke then
			cardStroke.Thickness = 2
		end
	end)
	buildDropdown()

	local function onCharacter(character)
		task.defer(refreshViewport, character)
	end
	game:GetService("RunService").RenderStepped:Connect(CharacterCard.step)
	player.CharacterAdded:Connect(onCharacter)
	player.CharacterAppearanceLoaded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

---------------------------------------------------------------------------
-- Dropdown
---------------------------------------------------------------------------
local ROW_W = 330
local ROW_H = 54
local dropdownHeight = 0
local ROW_BG = Color3.fromRGB(26, 23, 38)
local ROW_HOVER = Color3.fromRGB(40, 35, 58)
local GREEN = Color3.fromRGB(46, 150, 86)
local BLUE = Color3.fromRGB(52, 104, 220)
local GREY = Color3.fromRGB(58, 56, 70)

-- "JOHNNY JOESTAR" -> "JJ", "SANDMAN" -> "S".
local function initials(name)
	local out = ""
	for word in string.gmatch(name, "%S+") do
		if #out < 2 then
			out = out .. word:sub(1, 1)
		end
	end
	return out
end

local function tween(duration, step)
	VFXLib.animate(duration, function(a)
		step(VFXLib.easeOut(a))
	end)
end

function buildDropdown()
	dropdown = Instance.new("Frame")
	dropdown.Name = "CharacterList"
	dropdown.Position = UDim2.fromOffset(12, 112)
	dropdown.Size = UDim2.fromOffset(ROW_W, 0)
	dropdown.BackgroundColor3 = DARK
	dropdown.BackgroundTransparency = 0.06
	dropdown.ClipsDescendants = true
	dropdown.Visible = false
	dropdown.Parent = gui
	corner(dropdown, 12)
	stroke(dropdown, GOLD, 1.5)
	local bg = Instance.new("UIGradient")
	bg.Color = ColorSequence.new(Color3.fromRGB(34, 26, 52), Color3.fromRGB(14, 12, 20))
	bg.Rotation = 90
	bg.Parent = dropdown

	-- Header (stays put while the list scrolls).
	label(dropdown, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 22),
		Font = Enum.Font.Bangers,
		TextSize = 22,
		TextColor3 = GOLD,
		Text = "CHARACTERS",
	})
	label(dropdown, {
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -24, 0, 14),
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(165, 158, 190),
		TextStrokeTransparency = 1,
		Text = "Scroll for more  ·  BLOCK (F)  ·  DASH (Q)",
	})
	local line = Instance.new("Frame")
	line.Position = UDim2.fromOffset(12, 49)
	line.Size = UDim2.new(1, -24, 0, 1)
	line.BackgroundColor3 = GOLD
	line.BackgroundTransparency = 0.6
	line.BorderSizePixel = 0
	line.Parent = dropdown

	dropdownList = Instance.new("ScrollingFrame")
	dropdownList.BackgroundTransparency = 1
	dropdownList.BorderSizePixel = 0
	dropdownList.Position = UDim2.fromOffset(0, 52)
	dropdownList.Size = UDim2.new(1, 0, 1, -52)
	dropdownList.CanvasSize = UDim2.new()
	dropdownList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	dropdownList.ScrollBarThickness = 6
	dropdownList.ScrollingDirection = Enum.ScrollingDirection.Y
	dropdownList.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	dropdownList.ScrollBarImageColor3 = GOLD
	dropdownList.Parent = dropdown
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = dropdownList
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = dropdownList

	rosterRows = {}
	for order, entry in ipairs(TuskConfig.Roster or {}) do
		-- The whole row is the button.
		local row = Instance.new("TextButton")
		row.Name = entry.Id
		row.LayoutOrder = order
		row.Text = ""
		row.AutoButtonColor = false
		row.Size = UDim2.new(1, 0, 0, ROW_H)
		row.BackgroundColor3 = ROW_BG
		row.Parent = dropdownList
		corner(row, 9)
		local outline = stroke(row, entry.Color, 1.5)
		outline.Transparency = 1

		-- Colour badge with initials.
		local badge = Instance.new("Frame")
		badge.Position = UDim2.fromOffset(7, 7)
		badge.Size = UDim2.fromOffset(40, 40)
		badge.BackgroundColor3 = entry.Color
		badge.Parent = row
		corner(badge, 8)
		local shade = Instance.new("UIGradient")
		shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
		shade.Rotation = 90
		shade.Parent = badge
		label(badge, {
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.Bangers,
			TextSize = 22,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.3,
			Text = initials(entry.Name),
		})

		-- Names and Stands shrink to fit instead of being cut off ("JOHNNY...").
		local nameText = label(row, {
			Position = UDim2.fromOffset(55, 6),
			Size = UDim2.new(1, -150, 0, 24),
			Font = Enum.Font.Bangers,
			TextScaled = true,
			TextColor3 = entry.Available and Color3.new(1, 1, 1) or Color3.fromRGB(150, 145, 160),
			Text = entry.Name,
		})
		local nameLimit = Instance.new("UITextSizeConstraint")
		nameLimit.MaxTextSize = 21
		nameLimit.MinTextSize = 11
		nameLimit.Parent = nameText
		local standText = label(row, {
			Position = UDim2.fromOffset(55, 30),
			Size = UDim2.new(1, -150, 0, 14),
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextStrokeTransparency = 1,
			TextColor3 = entry.Color,
			Text = "STAND: " .. entry.Stand,
		})
		local standLimit = Instance.new("UITextSizeConstraint")
		standLimit.MaxTextSize = 10
		standLimit.MinTextSize = 7
		standLimit.Parent = standText

		local status = label(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(86, 26),
			Font = Enum.Font.GothamBlack,
			TextSize = 11,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 1,
			BackgroundTransparency = 0,
			BackgroundColor3 = GREY,
			Text = entry.Available and "SELECT" or "IN DEVELOPMENT",
		})
		corner(status, 7)

		local info = { Row = row, Order = order, Status = status, Entry = entry, Outline = outline, Name = nameText, Selectable = false, Playing = false }
		rosterRows[entry.Id] = info

		-- Hover: the row lights up and the outline shows in the character's colour.
		local function hover(on)
			local from = row.BackgroundColor3
			local to = on and ROW_HOVER or ROW_BG
			local fromT = outline.Transparency
			local toT = (on or info.Playing) and 0 or 1
			tween(0.12, function(a)
				row.BackgroundColor3 = from:Lerp(to, a)
				outline.Transparency = fromT + (toT - fromT) * a
			end)
		end
		row.MouseEnter:Connect(function()
			hover(true)
		end)
		row.MouseLeave:Connect(function()
			hover(false)
		end)
		row.Activated:Connect(function()
			if not info.Selectable then
				return
			end
			-- Little press bounce, then ask the server and close.
			tween(0.15, function(a)
				status.Size = UDim2.fromOffset(86 - 8 * math.sin(a * math.pi), 26 - 4 * math.sin(a * math.pi))
			end)
			Net.get("TuskRequest"):FireServer("Character", entry.Id)
			task.delay(0.15, function()
				if open then
					CharacterCard.toggle()
				end
			end)
		end)
	end
end

-- Which characters the server can play (the others' scripts aren't installed).
local function installedSet()
	local text = game:GetService("ReplicatedStorage"):GetAttribute("SpinInstalledCharacters")
	if type(text) ~= "string" then
		return nil -- not known yet: treat everyone as installed
	end
	local set = {}
	for id in string.gmatch(text, "[^,]+") do
		set[id] = true
	end
	return set
end

function refreshDropdown(act)
	if not dropdown then
		return
	end
	-- Each character row: PLAYING (green), SELECT (blue), NOT INSTALLED (grey:
	-- that character's _Server/_Client scripts aren't in the game) or IN DEVELOPMENT.
	local current = act and Registry.characterOf(act)
	local installed = installedSet()
	for id, row in pairs(rosterRows) do
		local playing = current == id
		local missing = installed ~= nil and not installed[id]
		row.Playing = playing
		if row.Entry.Available then
			row.Status.Text = playing and "PLAYING" or (missing and "NOT INSTALLED" or "SELECT")
			row.Status.BackgroundColor3 = playing and GREEN or (missing and GREY or BLUE)
			row.Status.TextColor3 = missing and Color3.fromRGB(190, 185, 200) or Color3.new(1, 1, 1)
			row.Selectable = not playing and not missing
		end
		row.Outline.Transparency = playing and 0 or 1
		row.Name.TextColor3 = (row.Entry.Available and not missing) and (playing and GOLD or Color3.new(1, 1, 1)) or Color3.fromRGB(150, 145, 160)
		row.Row.LayoutOrder = playing and 0 or row.Order
	end
end

function CharacterCard.toggle()
	if not dropdown then
		return
	end
	open = not open
	local rows = #(TuskConfig.Roster or {})
	local full = 52 + 14 + rows * (ROW_H + 5)
	-- Short list (about 4 rows, never more than 45% of the screen); the rest scrolls.
	local screenH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 600
	local target = math.min(full, 52 + 14 + 4.4 * (ROW_H + 5), math.max(180, screenH * 0.45))
	refreshDropdown(shownAct)
	if open then
		dropdown.Visible = true
		dropdownList.CanvasPosition = Vector2.new()
	end
	arrow.Text = open and "▲" or "▼"
	local from = dropdownHeight
	local to = open and target or 0
	VFXLib.animate(0.22, function(a)
		dropdownHeight = from + (to - from) * VFXLib.easeOut(a)
		dropdown.Size = UDim2.fromOffset(ROW_W, dropdownHeight)
	end, function()
		if not open then
			dropdown.Visible = false
		end
	end)
end

function CharacterCard.pop(color)
	VFXLib.animate(0.5, function(a)
		scale.Scale = 1 + 0.12 * math.sin(a * math.pi)
		card.BackgroundColor3 = color:Lerp(DARK, a)
	end, function()
		scale.Scale = 1
		card.BackgroundColor3 = DARK
	end)
end

function CharacterCard.step()
	if not card then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local frac = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		hpFill.Size = UDim2.fromScale(frac, 1)
		hpFill.BackgroundColor3 = Color3.fromRGB(220, 70, 60):Lerp(Color3.fromRGB(90, 220, 120), frac)
		hpText.Text = math.ceil(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth)
	end
	local act = character and character:GetAttribute("TuskAct")
	if act ~= shownAct then
		local evolved = shownAct ~= nil and act ~= nil and act > shownAct
		shownAct = act
		local info = act and Registry.get(act)
		local who = act ~= nil and Registry.characterOf(act) or "Johnny"
		local isGyro = who ~= "Johnny" -- (any non-Tusk character: no Act pips / evolve pop)
		-- Name plate follows the character (from TuskConfig.Roster).
		for _, entry in ipairs(TuskConfig.Roster or {}) do
			if entry.Id == who then
				nameLabel.Text = entry.Name
			end
		end
		if info and info.CardTitle then
			standLabel.Text = info.CardTitle
		else
			standLabel.Text = info and ("STAND  ·  " .. info.Name) or TuskConfig.Character.Title
		end
		standLabel.TextColor3 = info and info.Theme.Primary or Color3.fromRGB(200, 220, 255)
		-- Act pips are Tusk's progression; hidden for other characters.
		for i, pip in ipairs(pips) do
			pip.Visible = not isGyro
			local on = act ~= nil and i <= act
			local theme = Registry.get(i) and Registry.get(i).Theme.Primary or GOLD
			pip.BackgroundColor3 = on and theme or Color3.fromRGB(60, 60, 80)
		end
		if isGyro then
			evolved = false
		end
		if evolved and info then
			CharacterCard.pop(info.Theme.Primary)
		end
		refreshDropdown(act)
	end
end

return CharacterCard
end

-- ======================================================================
-- MODULE: CombatUI
-- ======================================================================
__modules["CombatUI"] = function()
--[[
	CombatUI  (StarterPlayerScripts.SpinClient.UI.CombatUI)

	Battlegrounds-style fight feedback:
	  * TARGET BAR: hit someone and their name + health bar appears at the
	    top of the screen. The bar drains smoothly, with a white "chunk" that
	    catches up a moment later so big hits read. Fades after a few seconds.
	  * DAMAGE EDGES: the screen edges flash red when you get hit, and pulse
	    while your health is low.
	  * GUARD BAR: under your character while you block (or while it
	    refills); it turns red as it runs out and shows BROKEN after a
	    guard break.
	  * DASH / BLOCK chips (bottom right): the dash cooldown sweeps back.
	Driven by the shared "Hit" event (CombatAdapter).
]]

local Players = game:GetService("Players")

local Shared = nil -- (bundled: modules are inlined)
local Net = __require("Net")

local CombatUI = {}
local player = Players.LocalPlayer
local DARK = Color3.fromRGB(14, 12, 20)
local GOLD = Color3.fromRGB(255, 205, 90)
local RED = Color3.fromRGB(230, 50, 60)

local gui, bar, nameLabel, fill, chunk, hpText, edges
local target -- the model shown in the bar
local shownUntil = 0
local fillValue, chunkValue = 1, 1
local hurtFlash = 0
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local guardGui, guardFill, guardText, chips
local stepDefense -- (defined further down)

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local function nameOf(model)
	local p = Players:GetPlayerFromCharacter(model)
	if p then
		return p.DisplayName
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.DisplayName ~= "" then
		return humanoid.DisplayName
	end
	return model.Name
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "CombatUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Target bar (top centre).
	bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 58)
	bar.Size = UDim2.fromOffset(340, 46)
	bar.BackgroundColor3 = DARK
	bar.BackgroundTransparency = 0.15
	bar.Visible = false
	bar.Parent = gui
	corner(bar, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 1.5
	stroke.Parent = bar
	nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(12, 3)
	nameLabel.Size = UDim2.new(1, -90, 0, 20)
	nameLabel.Font = Enum.Font.Bangers
	nameLabel.TextSize = 20
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = GOLD
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = bar
	hpText = Instance.new("TextLabel")
	hpText.BackgroundTransparency = 1
	hpText.AnchorPoint = Vector2.new(1, 0)
	hpText.Position = UDim2.new(1, -12, 0, 5)
	hpText.Size = UDim2.fromOffset(80, 16)
	hpText.Font = Enum.Font.GothamBlack
	hpText.TextSize = 12
	hpText.TextXAlignment = Enum.TextXAlignment.Right
	hpText.TextColor3 = Color3.new(1, 1, 1)
	hpText.Parent = bar
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(12, 26)
	back.Size = UDim2.new(1, -24, 0, 12)
	back.BackgroundColor3 = Color3.fromRGB(40, 36, 50)
	back.Parent = bar
	corner(back, 6)
	chunk = Instance.new("Frame")
	chunk.Size = UDim2.fromScale(1, 1)
	chunk.BackgroundColor3 = Color3.new(1, 1, 1)
	chunk.Parent = back
	corner(chunk, 6)
	fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = RED
	fill.Parent = back
	corner(fill, 6)
	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	shine.Rotation = 90
	shine.Parent = fill

	-- Red damage edges (four gradients round the screen).
	edges = {}
	local sides = {
		{ UDim2.fromScale(0, 0), UDim2.new(1, 0, 0.18, 0), 90 },
		{ UDim2.fromScale(0, 0.82), UDim2.new(1, 0, 0.18, 0), -90 },
		{ UDim2.fromScale(0, 0), UDim2.new(0.12, 0, 1, 0), 0 },
		{ UDim2.fromScale(0.88, 0), UDim2.new(0.12, 0, 1, 0), 180 },
	}
	for _, side in ipairs(sides) do
		local f = Instance.new("Frame")
		f.Position = side[1]
		f.Size = side[2]
		f.BackgroundColor3 = RED
		f.BorderSizePixel = 0
		f.BackgroundTransparency = 1
		f.Parent = gui
		local g = Instance.new("UIGradient")
		g.Rotation = side[3]
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = f
		table.insert(edges, f)
	end
end

local function showTarget(model)
	if not bar then
		return
	end
	if target ~= model then
		target = model
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local k = humanoid and humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth or 1
		fillValue, chunkValue = k, k
		nameLabel.Text = string.upper(nameOf(model))
	end
	shownUntil = os.clock() + 4
	bar.Visible = true
end

function CombatUI.step(dt)
	if not bar then
		return
	end
	dt = dt or 1 / 60
	local now = os.clock()
	-- Target bar.
	local humanoid = target and target.Parent and target:FindFirstChildOfClass("Humanoid")
	if humanoid and now < shownUntil then
		local k = humanoid.MaxHealth > 0 and math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) or 0
		fillValue = fillValue + (k - fillValue) * math.min(dt * 18, 1)
		-- The white chunk waits a moment, then catches up.
		if chunkValue > fillValue then
			chunkValue = math.max(fillValue, chunkValue - dt * 0.6)
		else
			chunkValue = fillValue
		end
		fill.Size = UDim2.fromScale(fillValue, 1)
		chunk.Size = UDim2.fromScale(chunkValue, 1)
		fill.BackgroundColor3 = k > 0.5 and Color3.fromRGB(90, 220, 110):Lerp(GOLD, (1 - k) * 2) or GOLD:Lerp(RED, (0.5 - k) * 2)
		hpText.Text = humanoid.Health <= 0 and "K.O." or (math.ceil(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth))
		local fade = math.clamp((shownUntil - now) / 0.4, 0, 1)
		bar.BackgroundTransparency = 1 - 0.85 * fade
		bar.Visible = fade > 0
	else
		bar.Visible = false
	end
	-- Damage edges: a flash when hit, a slow pulse while health is low.
	hurtFlash = math.max(0, hurtFlash - dt * 2.5)
	local mine = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local low = 0
	if mine and mine.Health > 0 and mine.MaxHealth > 0 and mine.Health / mine.MaxHealth < 0.3 then
		low = (0.5 + 0.5 * math.sin(now * 5)) * (1 - mine.Health / mine.MaxHealth / 0.3) * 0.5
	end
	local strength = math.max(hurtFlash, low)
	for _, f in ipairs(edges) do
		f.BackgroundTransparency = 1 - strength * 0.7
	end
	stepDefense()
end

local function chip(name, key, order)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(1, 1)
	f.Position = UDim2.new(1, -16, 1, -16 - order * 38)
	f.Size = UDim2.fromOffset(112, 32)
	f.BackgroundColor3 = DARK
	f.BackgroundTransparency = 0.15
	f.ClipsDescendants = true
	f.Parent = gui
	corner(f, 8)
	local sweep = Instance.new("Frame")
	sweep.Name = "Sweep"
	sweep.BorderSizePixel = 0
	sweep.Size = UDim2.fromScale(0, 1)
	sweep.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
	sweep.BackgroundTransparency = 0.3
	sweep.Parent = f
	local keyLabel = Instance.new("TextLabel")
	keyLabel.BackgroundColor3 = GOLD
	keyLabel.Position = UDim2.fromOffset(5, 5)
	keyLabel.Size = UDim2.fromOffset(22, 22)
	keyLabel.Font = Enum.Font.GothamBlack
	keyLabel.TextSize = 13
	keyLabel.TextColor3 = DARK
	keyLabel.Text = key
	keyLabel.Parent = f
	corner(keyLabel, 5)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(34, 0)
	label.Size = UDim2.new(1, -38, 1, 0)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = name
	label.Parent = f
	return { Frame = f, Sweep = sweep, Label = label, Name = name }
end

local function buildDefense()
	local keys = TuskConfig.Keys
	local function keyText(k)
		local names = { One = "1", Two = "2", Three = "3" }
		return k and (names[k.Name] or k.Name) or "?"
	end
	chips = {
		Dash = chip("DASH", keyText(keys.Dash and keys.Dash.Keyboard), 1),
		Block = chip("BLOCK", keyText(keys.Block and keys.Block.Keyboard), 0),
	}
	guardGui = Instance.new("BillboardGui")
	guardGui.Name = "GuardBar"
	guardGui.Size = UDim2.fromOffset(90, 12)
	guardGui.StudsOffset = Vector3.new(0, -3.4, 0)
	guardGui.AlwaysOnTop = true
	guardGui.LightInfluence = 0
	guardGui.Enabled = false
	guardGui.Parent = gui
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = DARK
	back.BackgroundTransparency = 0.2
	back.Parent = guardGui
	corner(back, 6)
	guardFill = Instance.new("Frame")
	guardFill.Position = UDim2.fromOffset(2, 2)
	guardFill.Size = UDim2.new(1, -4, 1, -4)
	guardFill.BackgroundColor3 = Color3.fromRGB(110, 180, 255)
	guardFill.Parent = back
	corner(guardFill, 5)
	guardText = Instance.new("TextLabel")
	guardText.BackgroundTransparency = 1
	guardText.Size = UDim2.fromScale(1, 1)
	guardText.Font = Enum.Font.GothamBlack
	guardText.TextSize = 9
	guardText.TextColor3 = Color3.new(1, 1, 1)
	guardText.TextStrokeTransparency = 0.4
	guardText.Text = ""
	guardText.Parent = back
end

function stepDefense()
	if not chips then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local d = TuskConfig.Defense or {}
	local t = workspace:GetServerTimeNow()
	-- Dash chip: a pip per charge; grey sweep while the next one comes back.
	local maxCharges = d.DashCharges or 1
	local readyAt = character and character:GetAttribute("DashReadyAt") or 0
	local fullAt = character and character:GetAttribute("DashFullAt") or readyAt
	local have = maxCharges
	if maxCharges >= 2 then
		have = (readyAt <= t and 1 or 0) + (fullAt <= t and maxCharges - 1 or 0)
	elseif readyAt > t then
		have = 0
	end
	local pips = string.rep("●", have) .. string.rep("○", maxCharges - have)
	local dashChip = chips.Dash
	local counter = character and (character:GetAttribute("CounterUntil") or 0) > t
	if have < maxCharges then
		local nextAt = have == 0 and readyAt or fullAt
		local left = nextAt - t
		dashChip.Sweep.Size = UDim2.fromScale(math.clamp(left / (d.DashCooldown or 2.2), 0, 1), 1)
		dashChip.Label.Text = string.format("DASH %s %.1f", pips, left)
		dashChip.Label.TextColor3 = have > 0 and Color3.new(1, 1, 1) or Color3.fromRGB(170, 170, 185)
	else
		dashChip.Sweep.Size = UDim2.fromScale(0, 1)
		dashChip.Label.Text = "DASH " .. pips
		dashChip.Label.TextColor3 = Color3.new(1, 1, 1)
	end
	if counter then
		dashChip.Label.Text = "COUNTER!"
		dashChip.Label.TextColor3 = Color3.fromRGB(255, 210, 80)
	end
	-- Block chip + guard bar.
	local blockingNow = character and character:GetAttribute("Blocking") == true
	local broken = character and (character:GetAttribute("GuardBrokenUntil") or 0) > t
	local meter = character and character:GetAttribute("BlockMeter")
	local max = d.MaxMeter or 100
	local blockChip = chips.Block
	blockChip.Label.Text = broken and "BROKEN" or (blockingNow and "BLOCKING" or "BLOCK")
	blockChip.Label.TextColor3 = broken and RED or (blockingNow and Color3.fromRGB(150, 205, 255) or Color3.new(1, 1, 1))
	blockChip.Frame.BackgroundColor3 = blockingNow and Color3.fromRGB(30, 50, 90) or DARK
	if root and (blockingNow or broken or (meter and meter < max)) then
		guardGui.Adornee = root
		guardGui.Enabled = true
		local k = broken and 0 or math.clamp((meter or max) / max, 0, 1)
		guardFill.Size = UDim2.new(k, k > 0 and -4 or 0, 1, -4)
		guardFill.BackgroundColor3 = Color3.fromRGB(110, 180, 255):Lerp(RED, 1 - k)
		guardText.Text = broken and "GUARD BROKEN" or ""
	else
		guardGui.Enabled = false
	end
end

function CombatUI.init()
	build()
	buildDefense()
	Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
		if name ~= "Hit" or typeof(data) ~= "table" or not data.Victim then
			return
		end
		if data.AttackerId == player.UserId and data.Victim ~= player.Character then
			showTarget(data.Victim)
		end
		if data.Victim == player.Character then
			hurtFlash = data.Blocked and 0.25 or 0.8
		end
	end)
	game:GetService("RunService").RenderStepped:Connect(CombatUI.step)
end

return CombatUI
end
end
