---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › UI"
updated: 2026-11-22
---
# CharacterCard

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| **Exact name** | `CharacterCard` (capitals matter) |

**What it does:** Top-left character card: portrait: your uploaded image (TuskConfig.Character.PortraitImage), or a live 3D view of your own avatar JOHNNY JOESTAR name plate (TuskConfig.Character.Name) current Stand ("TUSK ACT 2") in that Act's colour four Act pips that light up as Tusk awakens health bar with numbers Pops and flashes when Tusk evolves.

## How to add it
1. In Studio's Explorer, find **UI** (StarterPlayer › StarterPlayerScripts › SpinClient › UI).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **CharacterCard**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
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
local ROW_W = 290
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

		local nameText = label(row, {
			Position = UDim2.fromOffset(55, 6),
			Size = UDim2.new(1, -165, 0, 24),
			Font = Enum.Font.Bangers,
			TextSize = 21,
			TextScaled = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = entry.Available and Color3.new(1, 1, 1) or Color3.fromRGB(150, 145, 160),
			Text = entry.Name,
		})
		label(row, {
			Position = UDim2.fromOffset(55, 29),
			Size = UDim2.new(1, -165, 0, 16),
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextStrokeTransparency = 1,
			TextColor3 = entry.Color,
			Text = "STAND: " .. entry.Stand,
		})

		local status = label(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(98, 26),
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
				status.Size = UDim2.fromOffset(98 - 8 * math.sin(a * math.pi), 26 - 4 * math.sin(a * math.pi))
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
```
