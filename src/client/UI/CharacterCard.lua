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

	FIGHTER SELECT: tap/click the card to open "CHOOSE YOUR FIGHTER": a grid
	of tiles (one per TuskConfig.Roster entry, in its Stand's colours, with
	an emblem and a PLAYING / NOT INSTALLED badge) and a details panel with
	the fighter's Stand, tagline, every move with its key, and SELECT.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local VFXLib = require(script.Parent.Parent.VFXLib)

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
local Net = require(Shared.Net)

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
	card.Size = UDim2.fromOffset(290, 96)
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
		TextSize = 28,
		TextColor3 = GOLD,
		Text = config.Name,
	})
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
-- Fighter select ("CHOOSE YOUR FIGHTER")
---------------------------------------------------------------------------
local TweenService = game:GetService("TweenService")
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SOFT = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PANEL = Color3.fromRGB(22, 18, 34)
local INK = Color3.fromRGB(12, 10, 18)
local panel, panelScale, grid, details, selectedId

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
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

local function infoFor(entry)
	local act = Registry.StartAct[entry.Id]
	return act and Registry.get(act), act
end

local function initials(name)
	local words = {}
	for w in string.gmatch(name, "%S+") do
		table.insert(words, w)
	end
	if #words >= 2 then
		return words[1]:sub(1, 1) .. words[2]:sub(1, 1)
	end
	return name:sub(1, 2)
end

local function keyText(slot)
	local keys = TuskConfig.Keys[slot]
	local k = keys and keys.Keyboard
	local names = { One = "1", Two = "2", Three = "3", MouseButton1 = "LMB" }
	return k and (names[k.Name] or k.Name) or "?"
end

-- Status of a roster entry for this player right now.
local function statusOf(entry)
	if not entry.Available then
		return "DEV"
	end
	local installed = installedSet()
	if installed ~= nil and not installed[entry.Id] then
		return "MISSING"
	end
	local current = shownAct and Registry.characterOf(shownAct)
	if current == entry.Id then
		return "PLAYING"
	end
	return "READY"
end

local BADGE = {
	PLAYING = { "PLAYING", Color3.fromRGB(46, 150, 80) },
	MISSING = { "NOT INSTALLED", Color3.fromRGB(70, 66, 84) },
	DEV = { "IN DEVELOPMENT", Color3.fromRGB(70, 66, 84) },
}

local function showDetails(entry)
	selectedId = entry.Id
	local info = infoFor(entry)
	local theme = info and info.Theme or { Primary = entry.Color, Secondary = PANEL }
	details.Header.BackgroundColor3 = theme.Primary
	details.HeaderGradient.Color = ColorSequence.new(theme.Primary, theme.Secondary)
	details.Emblem.Text = initials(entry.Name)
	details.Name.Text = entry.Name
	details.Stand.Text = "STAND: " .. entry.Stand
	details.Stand.TextColor3 = theme.Primary:Lerp(Color3.new(1, 1, 1), 0.35)
	details.Tagline.Text = info and info.Tagline and string.upper(info.Tagline) or ""
	local moves = info and {
		{ keyText("M1"), info.M1 },
		{ keyText("Ability1"), info.Abilities[1] },
		{ keyText("Ability2"), info.Abilities[2] },
		{ keyText("Ability3"), info.Abilities[3] },
		{ keyText("Ultimate"), info.Ultimate .. (entry.Id == "Johnny" and "  (AWAKENS TUSK)" or "") },
	} or {}
	for i, row in ipairs(details.Moves) do
		local m = moves[i]
		row.Frame.Visible = m ~= nil
		if m then
			row.Key.Text = m[1]
			row.Key.BackgroundColor3 = i == 5 and Color3.fromRGB(255, 205, 90) or theme.Primary
			row.Name.Text = m[2]
		end
	end
	local status = statusOf(entry)
	local button = details.Select
	button.Active = status == "READY"
	button.AutoButtonColor = status == "READY"
	button.Text = status == "PLAYING" and "PLAYING" or (status == "MISSING" and "NOT INSTALLED" or (status == "DEV" and "IN DEVELOPMENT" or "SELECT"))
	button.BackgroundColor3 = status == "READY" and Color3.fromRGB(60, 170, 90) or (status == "PLAYING" and Color3.fromRGB(40, 110, 70) or Color3.fromRGB(70, 66, 84))
	details.Hint.Text = status == "MISSING" and ("Add " .. entry.Id .. "_Server and " .. entry.Id .. "_Client to the game to unlock.") or ""
	for id, tile in pairs(rosterRows) do
		local on = id == selectedId
		TweenService:Create(tile.Stroke, SOFT, { Thickness = on and 4 or 2, Color = on and Color3.new(1, 1, 1) or tile.Theme.Secondary:Lerp(INK, 0.3) }):Play()
	end
	-- Little pop when the details change.
	details.Scale.Scale = 0.96
	TweenService:Create(details.Scale, POP, { Scale = 1 }):Play()
end

local function buildTile(entry, order)
	local info = infoFor(entry)
	local theme = info and info.Theme or { Primary = entry.Color, Secondary = PANEL }
	local tile = make("TextButton", { Name = entry.Id, LayoutOrder = order, Text = "", AutoButtonColor = false, BackgroundColor3 = theme.Primary }, grid)
	corner(tile, 10)
	make("UIGradient", { Color = ColorSequence.new(theme.Primary, theme.Secondary), Rotation = 60 }, tile)
	local strokeLine = make("UIStroke", { Thickness = 2, Color = theme.Secondary:Lerp(INK, 0.3), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, tile)
	local tileScale = make("UIScale", { Scale = 1 }, tile)
	-- Diagonal stripes for texture.
	for i = 0, 3 do
		make("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.2 + i * 0.25, 0.4), Size = UDim2.new(0, 10, 1.6, 0), Rotation = 30 }, tile)
	end
	label(tile, { Name = "Emblem", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.9, 0.48), Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Center, Text = initials(entry.Name) })
	local band = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.34, 0), BackgroundColor3 = INK, BackgroundTransparency = 0.15 }, tile)
	corner(band, 10)
	label(band, { Position = UDim2.fromScale(0.06, 0.06), Size = UDim2.fromScale(0.88, 0.5), Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, Text = entry.Name })
	label(band, { Position = UDim2.fromScale(0.06, 0.56), Size = UDim2.fromScale(0.88, 0.32), Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = theme.Primary:Lerp(Color3.new(1, 1, 1), 0.45), TextXAlignment = Enum.TextXAlignment.Center, Text = entry.Stand })
	local badge = label(tile, { Name = "Badge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(84, 18), Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = PANEL, Text = "", Visible = false, TextStrokeTransparency = 1 })
	corner(badge, 6)
	make("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, badge)
	local shade = make("Frame", { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 3 }, tile)
	corner(shade, 10)
	tile.MouseEnter:Connect(function()
		TweenService:Create(tileScale, POP, { Scale = 1.06 }):Play()
		showDetails(entry)
	end)
	tile.MouseLeave:Connect(function()
		TweenService:Create(tileScale, SOFT, { Scale = 1 }):Play()
	end)
	tile.Activated:Connect(function()
		tileScale.Scale = 0.95
		TweenService:Create(tileScale, POP, { Scale = 1.06 }):Play()
		showDetails(entry)
	end)
	rosterRows[entry.Id] = { Tile = tile, Badge = badge, Shade = shade, Stroke = strokeLine, Theme = theme, Entry = entry }
end

function buildDropdown()
	-- (named "dropdown" for the rest of the card code; it's the full fighter select)
	dropdown = make("TextButton", { Name = "FighterSelect", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 10 }, gui)
	dropdown.Activated:Connect(function()
		CharacterCard.toggle()
	end)
	panel = make("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(780, 480), BackgroundColor3 = PANEL, ZIndex = 10 }, dropdown)
	corner(panel, 14)
	stroke(panel, GOLD, 2)
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(60, 36, 96), Color3.fromRGB(16, 14, 26)), Rotation = 30 }, panel)
	panelScale = make("UIScale", { Scale = 1 }, panel)
	label(panel, { Position = UDim2.fromOffset(24, 12), Size = UDim2.fromOffset(500, 40), Font = Enum.Font.Bangers, TextSize = 40, TextColor3 = GOLD, TextStrokeTransparency = 0.4, Text = "CHOOSE YOUR FIGHTER", ZIndex = 10 })
	label(panel, { Position = UDim2.fromOffset(26, 50), Size = UDim2.fromOffset(500, 16), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.fromRGB(190, 180, 215), Text = "Pick a fighter to see their moves.  Everyone can BLOCK (" .. keyText("Block") .. ") and DASH (" .. keyText("Dash") .. ").", ZIndex = 10 })
	local close = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = Color3.fromRGB(200, 50, 50), Text = "X", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), ZIndex = 11 }, panel)
	corner(close, 99)
	close.Activated:Connect(function()
		CharacterCard.toggle()
	end)

	grid = make("ScrollingFrame", { Position = UDim2.fromOffset(20, 78), Size = UDim2.fromOffset(456, 384), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = GOLD, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 10 }, panel)
	make("UIGridLayout", { CellSize = UDim2.fromOffset(140, 150), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, grid)

	-- Details on the right.
	local side = make("Frame", { Position = UDim2.fromOffset(490, 78), Size = UDim2.fromOffset(270, 384), BackgroundColor3 = INK, BackgroundTransparency = 0.25, ZIndex = 10 }, panel)
	corner(side, 12)
	details = { Scale = make("UIScale", { Scale = 1 }, side), Moves = {} }
	local header = make("Frame", { Size = UDim2.new(1, 0, 0, 86), BackgroundColor3 = GOLD, ZIndex = 10 }, side)
	corner(header, 12)
	header.Name = "Header"
	details.Header = header
	details.HeaderGradient = make("UIGradient", { Rotation = 60 }, header)
	details.Emblem = label(header, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(70, 66), Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Center, Text = "", ZIndex = 11 })
	details.Name = label(header, { Position = UDim2.fromOffset(86, 12), Size = UDim2.new(1, -96, 0, 34), Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3, Text = "", ZIndex = 11 })
	details.Tagline = label(header, { Position = UDim2.fromOffset(86, 50), Size = UDim2.new(1, -96, 0, 22), Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = Color3.fromRGB(255, 245, 225), Text = "", ZIndex = 11 })
	details.Stand = label(side, { Position = UDim2.fromOffset(14, 94), Size = UDim2.new(1, -28, 0, 20), Font = Enum.Font.GothamBlack, TextSize = 14, Text = "", ZIndex = 10 })
	for i = 1, 5 do
		local row = make("Frame", { Position = UDim2.fromOffset(12, 122 + (i - 1) * 40), Size = UDim2.new(1, -24, 0, 34), BackgroundColor3 = PANEL, BackgroundTransparency = 0.1, ZIndex = 10 }, side)
		corner(row, 8)
		local key = label(row, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 5, 0.5, 0), Size = UDim2.fromOffset(40, 24), Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = INK, BackgroundTransparency = 0, BackgroundColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, Text = "", ZIndex = 11 })
		corner(key, 6)
		make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, key)
		local name = label(row, { Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -58, 1, 0), Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), TextTruncate = Enum.TextTruncate.AtEnd, Text = "", ZIndex = 11 })
		details.Moves[i] = { Frame = row, Key = key, Name = name }
	end
	local select = make("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.new(1, -24, 0, 44), BackgroundColor3 = Color3.fromRGB(60, 170, 90), Text = "SELECT", Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), ZIndex = 11 }, side)
	corner(select, 10)
	make("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, select)
	local selectScale = make("UIScale", { Scale = 1 }, select)
	select.MouseEnter:Connect(function()
		if select.Active then
			TweenService:Create(selectScale, POP, { Scale = 1.05 }):Play()
		end
	end)
	select.MouseLeave:Connect(function()
		TweenService:Create(selectScale, SOFT, { Scale = 1 }):Play()
	end)
	select.Activated:Connect(function()
		if select.Active and selectedId then
			Net.get("TuskRequest"):FireServer("Character", selectedId)
			selectScale.Scale = 0.92
			TweenService:Create(selectScale, POP, { Scale = 1 }):Play()
			task.delay(0.25, function()
				if open then
					CharacterCard.toggle()
				end
			end)
		end
	end)
	details.Select = select
	details.Hint = label(side, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -20, 0, 20), Font = Enum.Font.Gotham, TextScaled = true, TextColor3 = Color3.fromRGB(190, 180, 215), TextXAlignment = Enum.TextXAlignment.Center, Text = "", ZIndex = 11 })

	rosterRows = {}
	for i, entry in ipairs(TuskConfig.Roster or {}) do
		buildTile(entry, i)
	end
end

function refreshDropdown()
	if not dropdown or not rosterRows then
		return
	end
	for _, tile in pairs(rosterRows) do
		local status = statusOf(tile.Entry)
		local b = BADGE[status]
		tile.Badge.Visible = b ~= nil
		if b then
			tile.Badge.Text = b[1]
			tile.Badge.BackgroundColor3 = b[2]
		end
		tile.Shade.BackgroundTransparency = (status == "MISSING" or status == "DEV") and 0.5 or 1
	end
	local current = shownAct and Registry.characterOf(shownAct)
	for _, entry in ipairs(TuskConfig.Roster or {}) do
		if entry.Id == (selectedId or current or "Johnny") then
			showDetails(entry)
		end
	end
end

function CharacterCard.toggle()
	if not dropdown then
		return
	end
	open = not open
	arrow.Text = open and "▲" or "▼"
	if open then
		selectedId = nil
		refreshDropdown()
		local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local fit = math.min(1, (view.X - 24) / 780, (view.Y - 40) / 480)
		dropdown.Visible = true
		dropdown.BackgroundTransparency = 1
		panelScale.Scale = fit * 0.8
		TweenService:Create(dropdown, SOFT, { BackgroundTransparency = 0.45 }):Play()
		TweenService:Create(panelScale, POP, { Scale = fit }):Play()
	else
		TweenService:Create(dropdown, SOFT, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(panelScale, SOFT, { Scale = panelScale.Scale * 0.85 }):Play()
		task.delay(0.16, function()
			if not open then
				dropdown.Visible = false
			end
		end)
	end
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
		if open then
			refreshDropdown()
		end
	end
end

return CharacterCard
