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

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local Net = require(Shared.Net)
local Registry = require(Shared.TuskActRegistry)
local TuskConfig = require(Shared.TuskConfig)

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
	for _, p in ipairs(Players:GetPlayers()) do
		local parts = p.Character and p.Character:GetAttribute("CorpseParts")
		if parts and string.find("," .. parts .. ",", "," .. partId .. ",", 1, true) then
			return p.Character
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

local function fillGrid()
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local shown = {}
	for _, entry in ipairs(lastList) do
		if filter == "ALL" or (filter == "PLAYERS" and entry.Kind == "Player") or (filter == "NPCS" and entry.Kind == "NPC") or (filter == "CORPSE" and entry.Kind == "Corpse") then
			table.insert(shown, entry)
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
	local cashChip = new("Frame", { Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(110, 26), BackgroundColor3 = GOLD, ZIndex = 4 }, strip)
	corner(cashChip, 6)
	cashLabel = label(cashChip, { Size = UDim2.fromScale(1, 1), Text = "$0", Font = Enum.Font.Bangers, ZIndex = 4 })
	for i, name in ipairs({ "ALL", "PLAYERS", "NPCS", "CORPSE" }) do
		local tab = new("TextButton", { Position = UDim2.fromOffset(124 + (i - 1) * 78, 4), Size = UDim2.fromOffset(72, 26), BackgroundColor3 = WOOD_DARK, Text = name, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = PAPER, ZIndex = 4 }, strip)
		corner(tab, 6)
		new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, tab)
		tab.Activated:Connect(function()
			filter = name
			fillGrid()
		end)
		tabs[name] = tab
	end
	huntingLabel = label(strip, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 2), Size = UDim2.fromOffset(200, 16), Text = "", TextColor3 = PAPER, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
	countLabel = label(strip, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 18), Size = UDim2.fromOffset(200, 12), Text = "", Font = Enum.Font.GothamBold, TextColor3 = PAPER_DARK, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
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
		elseif kind == "Complete" then
			clearActive()
			showBanner("BOUNTY CLAIMED!  +$" .. tostring(data.Reward), GOLD)
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
