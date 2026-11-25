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
	  * POST tab: post your own bounty. Pick who it's on (yourself, any
	    player, any Stand-user NPC or any Saint's Corpse part), type how
	    much (or tap +$25 / +$100 / +$500 / MAX) and POST it. The whole
	    server sees a banner
	Remote: Net "Bounty" (server: BountyService).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local Net = require(Shared.Net)
local Registry = require(Shared.TuskActRegistry)
local TuskConfig = require(Shared.TuskConfig)
local Cinematic = require(script.Parent.Parent.Cinematic)
local okHorse, HorseModel = pcall(function()
	return require(Shared.HorseModel)
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
local fillGrid -- (below)
local placeAmount = 100
local placeButton -- "PUT $100 ON THEIR HEAD" on a player's contract
local lastTargets = {} -- who you can post a bounty on (POST tab)
local postCfg = { Min = 25, Max = 5000, Cap = 10000, Quick = { 25, 100, 500 } }
local postPick -- the Key of the target picked in the POST tab
local postAmount = 100
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

-- The SHOP: a general store. Items are grouped under wooden section signs
-- (SUPPLIES / TONICS / GEAR / SERVICES); each is a parchment card with a
-- picture medallion, its name, an effect chip and a duration chip, a
-- hanging price tag and a BUY button. Things you've bought and that are
-- still working get a green ACTIVE ribbon and a time-left bar (buy again
-- to top it up); things you can't afford say how much more you need.
local SHOP_SECTIONS = {
	{ Id = "SUPPLIES", Title = "SUPPLIES", Sub = "patch up and find your way", Color = Color3.fromRGB(70, 140, 80) },
	{ Id = "TONICS", Title = "TONICS & LUCK", Sub = "a little something for the road", Color = Color3.fromRGB(150, 70, 140) },
	{ Id = "GEAR", Title = "GEAR", Sub = "for the hunter, and the hunted", Color = Color3.fromRGB(70, 110, 170) },
	{ Id = "SERVICES", Title = "SERVICES", Sub = "the sheriff's office", Color = Color3.fromRGB(150, 60, 40) },
}
local shopBars = {} -- { Fill, Text, Until, Time } live time-left bars

local function sectionSign(y, sec)
	local sign = new("Frame", { Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -40, 0, 34), BackgroundColor3 = WOOD_DARK }, grid)
	corner(sign, 6)
	new("UIStroke", { Color = Color3.fromRGB(40, 24, 12), Thickness = 2 }, sign)
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WOOD_LIGHT), ColorSequenceKeypoint.new(1, WOOD_DARK) }), Rotation = 90 }, sign)
	local stripe = new("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = sec.Color, BorderSizePixel = 0 }, sign)
	corner(stripe, 6)
	for _, x in ipairs({ 0, 1 }) do
		local nail = new("Frame", { AnchorPoint = Vector2.new(x, 0.5), Position = UDim2.new(x, x == 0 and 16 or -10, 0.5, 0), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = NAIL }, sign)
		corner(nail, 99)
	end
	label(sign, { Position = UDim2.fromOffset(28, 2), Size = UDim2.new(0.5, 0, 1, -4), Text = sec.Title, Font = Enum.Font.Bangers, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.5 })
	label(sign, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 9), Size = UDim2.new(0.45, 0, 0, 16), Text = string.upper(sec.Sub), Font = Enum.Font.GothamBold, TextColor3 = PAPER_DARK, TextXAlignment = Enum.TextXAlignment.Right })
	return y + 44
end

local function chip(parent, x, y, text, color, textColor)
	local w = math.clamp(#text * 7 + 16, 44, 150)
	local c = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 18), BackgroundColor3 = color }, parent)
	corner(c, 9)
	label(c, { Size = UDim2.fromScale(1, 1), Text = text, Font = Enum.Font.GothamBlack, TextColor3 = textColor or PAPER })
	return c, w
end

local function shopCard(item, x, y, cash, secColor)
	local card = paperCard(grid, UDim2.fromOffset(x, y), UDim2.fromOffset(300, 140), ((#item.Name * 7) % 5 - 2) * 0.25)
	-- A coloured band down the left edge (its section).
	local band = new("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = secColor, BorderSizePixel = 0 }, card)
	corner(band, 4)
	-- Picture medallion: a gold-rimmed disc with the item's picture.
	local medal = new("Frame", { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(62, 62), BackgroundColor3 = secColor:Lerp(WOOD_DARK, 0.45) }, card)
	corner(medal, 99)
	new("UIStroke", { Color = GOLD, Thickness = 3 }, medal)
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 170, 170)) }), Rotation = 90 }, medal)
	label(medal, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.72, 0.72), Text = item.Emoji or item.Icon or "?", Font = Enum.Font.GothamBlack, TextColor3 = GOLD })
	-- Name, effect.
	local name = label(card, { Position = UDim2.fromOffset(88, 12), Size = UDim2.new(1, -170, 0, 24), Text = item.Name, Font = Enum.Font.Bangers, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 10 }, name)
	local desc = label(card, { Position = UDim2.fromOffset(88, 38), Size = UDim2.new(1, -100, 0, 30), Text = item.Text, Font = Enum.Font.GothamMedium, TextWrapped = true, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, desc)
	-- Chips: what it does, how long.
	local cx = 88
	if item.Tag then
		local _, w = chip(card, cx, 72, item.Tag, secColor:Lerp(INK, 0.15))
		cx = cx + w + 6
	end
	local t = item.Time
	chip(card, cx, 72, t and (t >= 60 and string.format("%d:%02d", math.floor(t / 60), t % 60) or (t .. " S")) or "INSTANT", WOOD_DARK)
	-- The price tag, hanging from a string at the top right.
	local clean = item.Clean
	local price = item.Price or 0
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(1, -40, 0, -4), Size = UDim2.fromOffset(2, 12), BackgroundColor3 = BURNT, BorderSizePixel = 0 }, card)
	local tag = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(1, -40, 0, 6), Size = UDim2.fromOffset(62, 26), Rotation = 6, BackgroundColor3 = Color3.fromRGB(250, 238, 210) }, card)
	corner(tag, 5)
	new("UIStroke", { Color = BURNT, Thickness = 2 }, tag)
	label(tag, { Size = UDim2.fromScale(1, 1), Text = clean and "FREE" or ("$" .. price), Font = Enum.Font.Bangers, TextColor3 = (cash >= price or clean) and INK or RED })
	-- Buy button: green if you can, grey with how much more you need if not.
	local afford = cash >= price and not clean
	local activeUntil = item.Active
	local text = clean and "ALREADY CLEAN" or (afford and ((activeUntil and "TOP UP  $" or "BUY  $") .. price) or ("NEED $" .. (price - cash) .. " MORE"))
	local buy = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -10), Size = UDim2.fromOffset(140, 34), BackgroundColor3 = afford and GREEN or Color3.fromRGB(130, 120, 110), Text = text, Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = afford }, card)
	corner(buy, 8)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, buy)
	new("UIStroke", { Color = (afford and GREEN or INK):Lerp(Color3.new(0, 0, 0), 0.4), Thickness = 2 }, buy)
	local scale = new("UIScale", { Scale = 1 }, buy)
	if afford then
		buy.MouseEnter:Connect(function()
			TweenService:Create(scale, FAST, { Scale = 1.07 }):Play()
		end)
		buy.MouseLeave:Connect(function()
			TweenService:Create(scale, SOFT, { Scale = 1 }):Play()
		end)
	end
	buy.Activated:Connect(function()
		if clean or not afford then
			return
		end
		scale.Scale = 0.88
		TweenService:Create(scale, FAST, { Scale = 1 }):Play()
		Remote:FireServer("Buy", item.Id)
	end)
	-- Working right now: a green ribbon and a time-left bar.
	if activeUntil and activeUntil > workspace:GetServerTimeNow() then
		local ribbon = new("Frame", { Position = UDim2.fromOffset(10, 84), Size = UDim2.fromOffset(72, 18), Rotation = -6, BackgroundColor3 = GREEN }, card)
		corner(ribbon, 4)
		label(ribbon, { Size = UDim2.fromScale(1, 1), Text = "ACTIVE", Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1) })
		local bar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -12), Size = UDim2.new(1, -176, 0, 14), BackgroundColor3 = PAPER_DARK }, card)
		corner(bar, 7)
		new("UIStroke", { Color = INK, Thickness = 1, Transparency = 0.5 }, bar)
		local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = GREEN }, bar)
		corner(fill, 7)
		local tl = label(bar, { Size = UDim2.fromScale(1, 1), Text = "", Font = Enum.Font.GothamBlack, TextColor3 = INK })
		table.insert(shopBars, { Fill = fill, Text = tl, Until = activeUntil, Time = item.Time or 60 })
	end
	return card
end

local function stepShopBars()
	local now = workspace:GetServerTimeNow()
	for i = #shopBars, 1, -1 do
		local b = shopBars[i]
		if not b.Fill.Parent then
			table.remove(shopBars, i)
		else
			local left = math.max(0, b.Until - now)
			b.Fill.Size = UDim2.fromScale(math.clamp(left / math.max(b.Time, 1), 0, 1), 1)
			b.Text.Text = left > 0 and string.format("%d:%02d LEFT", math.floor(left / 60), math.floor(left % 60)) or "USED UP"
		end
	end
end

local function showShop()
	local cash = 0
	local ls = player:FindFirstChild("leaderstats")
	local cv = ls and ls:FindFirstChild("Cash")
	cash = cv and cv.Value or 0
	shopBars = {}
	-- The store sign.
	local head = new("Frame", { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -40, 0, 58), BackgroundColor3 = Color3.fromRGB(60, 38, 22) }, grid)
	corner(head, 8)
	new("UIStroke", { Color = GOLD, Thickness = 2, Transparency = 0.3 }, head)
	label(head, { Position = UDim2.fromOffset(16, 4), Size = UDim2.new(0.6, 0, 0, 34), Text = "GENERAL STORE", Font = Enum.Font.Bangers, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.4 })
	label(head, { Position = UDim2.fromOffset(16, 36), Size = UDim2.new(0.6, 0, 0, 14), Text = "EFFECTS LAST UNTIL THEY RUN OUT OR YOU GO DOWN", Font = Enum.Font.GothamBold, TextColor3 = PAPER_DARK, TextXAlignment = Enum.TextXAlignment.Left })
	local purse = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 38), BackgroundColor3 = GOLD }, head)
	corner(purse, 8)
	new("UIStroke", { Color = WOOD_DARK, Thickness = 2 }, purse)
	label(purse, { Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(34, 38), Text = "💰", Font = Enum.Font.GothamBlack })
	label(purse, { Position = UDim2.fromOffset(40, 2), Size = UDim2.new(1, -46, 1, -4), Text = "$" .. cash, Font = Enum.Font.Bangers, TextColor3 = INK })
	local y = 84
	-- Group the items under their section signs (anything uncategorised last).
	local placed = {}
	local sections = {}
	for _, sec in ipairs(SHOP_SECTIONS) do
		table.insert(sections, sec)
	end
	table.insert(sections, { Id = "_", Title = "MORE", Sub = "odds and ends", Color = WOOD })
	for _, sec in ipairs(sections) do
		local items = {}
		for _, item in ipairs(lastShop) do
			if not placed[item] and (item.Category == sec.Id or (sec.Id == "_" and true)) then
				table.insert(items, item)
				placed[item] = true
			end
		end
		if #items > 0 then
			y = sectionSign(y, sec)
			for i, item in ipairs(items) do
				local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
				shopCard(item, 14 + col * 316, y + row * 152, cash, sec.Color)
			end
			y = y + math.ceil(#items / 2) * 152 + 4
		end
	end
	y = showStable(y + 6, cash)
	grid.CanvasSize = UDim2.fromOffset(0, y + 20)
	return #lastShop
end

-- POST: put your own Cash on someone (or something).
local function cashNow()
	local ls = player:FindFirstChild("leaderstats")
	local cv = ls and ls:FindFirstChild("Cash")
	return cv and cv.Value or 0
end

local function showPost()
	local picked
	for _, t in ipairs(lastTargets) do
		if t.Key == postPick then
			picked = t
		end
	end
	if not picked then
		postPick = nil
	end
	local cash = cashNow()
	-- The form.
	local card = paperCard(grid, UDim2.fromOffset(14, 16), UDim2.new(1, -40, 0, 176), -0.4)
	label(card, { Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(260, 30), Text = "POST A BOUNTY", Font = Enum.Font.Bangers, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Left })
	local photoBox = new("Frame", { Position = UDim2.fromOffset(16, 46), Size = UDim2.fromOffset(100, 100), BackgroundColor3 = PAPER_DARK }, card)
	corner(photoBox, 6)
	new("UIStroke", { Color = WOOD_DARK, Thickness = 3 }, photoBox)
	if picked then
		local photo = photoFor(picked, photoBox)
		photo.Size = UDim2.fromScale(1, 1)
		corner(photo, 6)
	else
		label(photoBox, { Size = UDim2.fromScale(1, 1), Text = "?", Font = Enum.Font.Bangers, TextColor3 = WOOD_DARK })
	end
	local who = label(card, { Position = UDim2.fromOffset(128, 44), Size = UDim2.new(1, -144, 0, 26), Text = picked and string.upper((picked.Self and "YOURSELF: " or "ON: ") .. picked.Name) or "PICK WHO IT'S ON BELOW", TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 10 }, who)
	label(card, { Position = UDim2.fromOffset(128, 70), Size = UDim2.new(1, -144, 0, 16), Text = picked and ((picked.Posted or 0) > 0 and ("ALREADY ON THEM: $" .. picked.Posted) or "NOTHING ON THEM YET") or "", Font = Enum.Font.GothamBold, TextColor3 = (picked and (picked.Posted or 0) > 0) and RED or INK, TextXAlignment = Enum.TextXAlignment.Left })
	-- Amount: type it, or tap the chips.
	local box = new("TextBox", { Position = UDim2.fromOffset(128, 94), Size = UDim2.fromOffset(120, 38), BackgroundColor3 = Color3.fromRGB(250, 236, 205), Text = tostring(postAmount), PlaceholderText = "$", ClearTextOnFocus = false, Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = INK }, card)
	corner(box, 6)
	new("UIStroke", { Color = WOOD_DARK, Thickness = 2 }, box)
	new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, box)
	label(card, { Position = UDim2.fromOffset(112, 94), Size = UDim2.fromOffset(16, 38), Text = "$", Font = Enum.Font.Bangers, TextColor3 = INK })
	local postButton
	local function refreshButton()
		local ok = picked ~= nil and postAmount >= (postCfg.Min or 25) and postAmount <= cash
		postButton.Text = "POST  $" .. postAmount
		postButton.BackgroundColor3 = ok and GREEN or Color3.fromRGB(130, 120, 110)
		postButton.AutoButtonColor = ok
		box.Text = tostring(postAmount)
	end
	local function setAmount(v)
		v = math.floor(tonumber(v) or postAmount)
		postAmount = math.clamp(v, postCfg.Min or 25, postCfg.Max or 5000)
		refreshButton()
	end
	box.FocusLost:Connect(function()
		setAmount((box.Text or ""):gsub("[^%d]", ""))
	end)
	local chips = {}
	for _, q in ipairs(postCfg.Quick or { 25, 100, 500 }) do
		table.insert(chips, { "+$" .. q, function()
			setAmount(postAmount + q)
		end })
	end
	table.insert(chips, { "MAX", function()
		setAmount(math.min(cash, postCfg.Max or 5000))
	end })
	table.insert(chips, { "RESET", function()
		setAmount(postCfg.Min or 25)
	end })
	for i, c in ipairs(chips) do
		local chip = new("TextButton", { Position = UDim2.fromOffset(256 + (i - 1) * 54, 98), Size = UDim2.fromOffset(50, 30), BackgroundColor3 = i > #chips - 2 and WOOD_DARK or GOLD, Text = c[1], Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = i > #chips - 2 and PAPER or INK }, card)
		corner(chip, 6)
		new("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7) }, chip)
		chip.Activated:Connect(c[2])
	end
	postButton = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -10), Size = UDim2.fromOffset(170, 40), BackgroundColor3 = GREEN, Text = "", Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, card)
	corner(postButton, 8)
	new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, postButton)
	new("UIStroke", { Color = Color3.fromRGB(30, 70, 34), Thickness = 2 }, postButton)
	local note = label(card, { Position = UDim2.fromOffset(16, 150), Size = UDim2.new(1, -210, 0, 18), Text = picked and picked.Self and "Bold. Whoever takes YOU down gets it." or "Whoever takes them down (or takes the part) gets it. Cash back if they leave.", Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, note)
	refreshButton()
	postButton.Activated:Connect(function()
		if not picked or postAmount > cashNow() then
			return
		end
		local sc = postButton:FindFirstChildOfClass("UIScale") or new("UIScale", { Scale = 1 }, postButton)
		sc.Scale = 0.9
		TweenService:Create(sc, FAST, { Scale = 1 }):Play()
		Remote:FireServer("Post", { Key = picked.Key, Amount = postAmount })
	end)
	-- Who it can be on.
	label(grid, { Position = UDim2.fromOffset(14, 200), Size = UDim2.new(1, -40, 0, 22), Text = "PICK WHO IT'S ON", Font = Enum.Font.Bangers, TextColor3 = PAPER, TextXAlignment = Enum.TextXAlignment.Left }).Name = "PostHeader"
	local w = 196
	for i, t in ipairs(lastTargets) do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local tc = new("TextButton", { Position = UDim2.fromOffset(14 + col * (w + 8), 228 + row * 80), Size = UDim2.fromOffset(w, 70), BackgroundColor3 = t.Key == postPick and Color3.fromRGB(255, 232, 170) or PAPER, Text = "", AutoButtonColor = true }, grid)
		-- (A Frame-like card so fillGrid clears it.)
		tc.Name = "PostTarget"
		corner(tc, 6)
		new("UIStroke", { Color = t.Key == postPick and GOLD or BURNT, Thickness = t.Key == postPick and 4 or 2 }, tc)
		local ph = photoFor(t, tc)
		ph.Position = UDim2.fromOffset(8, 8)
		ph.Size = UDim2.fromOffset(54, 54)
		corner(ph, 4)
		local nm = label(tc, { Position = UDim2.fromOffset(68, 6), Size = UDim2.new(1, -74, 0, 22), Text = string.upper((t.Name or ""):gsub("^SAINT'S CORPSE: ", "")), TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
		new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 8 }, nm)
		local kindText = t.Self and "YOU" or (t.Kind == "Corpse" and "CORPSE PART" or (t.Kind == "NPC" and "NPC" or "PLAYER"))
		local chip = new("Frame", { Position = UDim2.fromOffset(68, 30), Size = UDim2.fromOffset(t.Kind == "Corpse" and 84 or 52, 16), BackgroundColor3 = t.Self and GOLD or (t.Kind == "Corpse" and Color3.fromRGB(214, 178, 96) or (t.Kind == "NPC" and WOOD_DARK or GREEN)) }, tc)
		corner(chip, 4)
		label(chip, { Size = UDim2.fromScale(1, 1), Text = kindText, Font = Enum.Font.GothamBlack, TextColor3 = (t.Self or t.Kind == "Corpse") and INK or PAPER })
		label(tc, { Position = UDim2.fromOffset(68, 48), Size = UDim2.new(1, -74, 0, 16), Text = (t.Posted or 0) > 0 and ("$" .. t.Posted .. " ON THEM") or "", Font = Enum.Font.GothamBlack, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Left })
		tc.Activated:Connect(function()
			postPick = t.Key
			fillGrid()
		end)
	end
	grid.CanvasSize = UDim2.fromOffset(0, 240 + math.ceil(#lastTargets / 3) * 80)
	return #lastTargets
end

function fillGrid()
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("Frame") or c.Name == "PostTarget" or c.Name == "PostHeader" then
			c:Destroy()
		end
	end
	jobsTimer = nil
	if filter == "JOBS" or filter == "SHOP" or filter == "POST" then
		local n = filter == "JOBS" and showJobs() or (filter == "POST" and showPost() or showShop())
		local empty = grid:FindFirstChild("Empty")
		empty.Visible = n == 0
		empty.Text = filter == "JOBS" and "No jobs right now." or (filter == "POST" and "Nobody to post a bounty on." or "The shop is closed.")
		for name, tab in pairs(tabs) do
			local on = name == filter
			tab.BackgroundColor3 = on and GOLD or WOOD_DARK
			tab.TextColor3 = on and INK or PAPER
		end
		countLabel.Text = filter == "JOBS" and "PAID TASKS" or (filter == "POST" and "YOUR CASH ON ANYONE" or "SPEND YOUR CASH")
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
	lastTargets = data.Targets or lastTargets
	postCfg = data.Post or postCfg
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
	for i, name in ipairs({ "ALL", "PLAYERS", "NPCS", "CORPSE", "JOBS", "SHOP", "POST" }) do
		local x = 98 + (i - 1) * 53 + (i >= 5 and 6 or 0) -- a little gap before JOBS / SHOP / POST
		local tab = new("TextButton", { Position = UDim2.fromOffset(x, 4), Size = UDim2.fromOffset(50, 26), BackgroundColor3 = WOOD_DARK, Text = name, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = PAPER, ZIndex = 4 }, strip)
		corner(tab, 6)
		new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, tab)
		tab.Activated:Connect(function()
			filter = name
			fillGrid()
		end)
		tabs[name] = tab
	end
	huntingLabel = label(strip, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 2), Size = UDim2.fromOffset(150, 16), Text = "", TextColor3 = PAPER, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
	countLabel = label(strip, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 18), Size = UDim2.fromOffset(150, 12), Text = "", Font = Enum.Font.GothamBold, TextColor3 = PAPER_DARK, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
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
	if #shopBars > 0 then
		stepShopBars()
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
	-- Smoke bomb (bounty-board shop): no marker, no distance while it lasts.
	if model and (model:GetAttribute("SmokedUntil") or 0) > workspace:GetServerTimeNow() then
		where = "LOST IN SMOKE"
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
			Cinematic.title("THE HUNT BEGINS", data.Name or "", GOLD, "$" .. tostring(data.Reward or 0) .. " · DEAD OR ALIVE")
		elseif kind == "Complete" and data.Price then
			showBanner("PRICE ON THEIR HEAD!  +$" .. tostring(data.Reward), GOLD)
		elseif kind == "Complete" then
			clearActive()
			showBanner("BOUNTY CLAIMED!  +$" .. tostring(data.Reward), GOLD)
			Cinematic.title("BOUNTY CLAIMED", "+$" .. tostring(data.Reward), GOLD, data.Name or "")
		elseif kind == "Refresh" then
			lastList = data.Bounties or lastList
			lastJobs, lastShop, jobsUntil = data.Jobs or lastJobs, data.Shop or lastShop, data.JobsUntil or jobsUntil
			lastStable = data.Stable or lastStable
			lastTargets = data.Targets or lastTargets
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
		elseif kind == "Posted" then
			local amount, name = tostring(data.Amount), string.upper(tostring(data.Name))
			if data.Mine then
				showBanner((data.Self and "YOU PUT $" .. amount .. " ON YOUR OWN HEAD!") or ("BOUNTY POSTED: $" .. amount .. " ON " .. name), GOLD)
			elseif data.You then
				showBanner(string.upper(tostring(data.By)) .. " POSTED $" .. amount .. " ON YOUR HEAD!", Color3.fromRGB(255, 140, 120))
			elseif data.Self then
				showBanner(string.upper(tostring(data.By)) .. " PUT $" .. amount .. " ON THEIR OWN HEAD!", GOLD)
			else
				showBanner(string.upper(tostring(data.By)) .. " POSTED $" .. amount .. " ON " .. name, PAPER)
			end
		elseif kind == "Refunded" then
			showBanner("$" .. tostring(data.Amount) .. " REFUNDED (" .. string.upper(tostring(data.Name)) .. " IS GONE)", PAPER)
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
