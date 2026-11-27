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

**What it does:** Top-left character card, in the bounty-board style, kept clean: a framed wooden board (planks, metal corner brackets) that lifts a little and turns its rim gold when you hover it portrait in a parchment mat with a nail on top: your uploaded image (TuskConfig.Character.PortraitImage), or a live 3D view of your own avatar, on a backing in your character's Roster colour a straight parchment NAME PLATE (Bangers ink) the Stand on a dark inset with a strip of the Stand's colour Tusk's four Act pips (Johnny only; for everyone else the health bar moves up into their place) a wood-framed HEALTH bar: "HP" on the left, numbers on the right a gold "CHARACTERS ▼" tab hanging under the card Pops and flashes the planks in the Act colour when Tusk evolves.

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

	Top-left character card, in the bounty-board style, kept clean:
	  * a framed wooden board (planks, metal corner brackets) that lifts a
	    little and turns its rim gold when you hover it
	  * portrait in a parchment mat with a nail on top: your uploaded image
	    (TuskConfig.Character.PortraitImage), or a live 3D view of your own
	    avatar, on a backing in your character's Roster colour
	  * a straight parchment NAME PLATE (Bangers ink)
	  * the Stand on a dark inset with a strip of the Stand's colour
	  * Tusk's four Act pips (Johnny only; for everyone else the health bar
	    moves up into their place)
	  * a wood-framed HEALTH bar: "HP" on the left, numbers on the right
	  * a gold "CHARACTERS ▼" tab hanging under the card
	Pops and flashes the planks in the Act colour when Tusk evolves.

	CHARACTER LIST (tap the card or its tab): a wooden board, "CHOOSE YOUR
	FIGHTER" and how many there are, a SEARCH box (name or Stand), then one
	parchment row per character: a strip and a round badge in the
	character's colour with their initials, their name, their Stand, and a
	status pill (green PLAYING, red SELECT, grey NOT INSTALLED / IN
	DEVELOPMENT). Rows lighten, take their character's colour as an outline
	and lift on hover; the whole row is the button. The one you're playing
	is pinned to the top.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local VFXLib = require(script.Parent.Parent.VFXLib)
local UITheme = require(script.Parent.UITheme)
local C = UITheme.C
local F = UITheme.Font

local CharacterCard = {}

local player = Players.LocalPlayer
local GOLD = C.GOLD
local PIP_OFF = Color3.fromRGB(58, 40, 26)
local FADED_INK = Color3.fromRGB(150, 122, 96)

local CARD_W, CARD_H = 330, 100
local gui, card, portrait, viewport, photo, nameLabel, standLabel, standStrip, pipRow, pips, hpBar, hpFill, hpText, scale, arrow, flash, cardStroke, tab
local dropdown, dropdownList, rosterRows, searchBox, countLabel, emptyLabel
-- Declared up here so init() can call them (they are defined further down).
local buildDropdown, refreshDropdown, applyFilter
local shownAct
local open = false
local Net = require(Shared.Net)

local function corner(p, r)
	return UITheme.corner(p, r)
end

local function stroke(p, color, t)
	return UITheme.stroke(p, color, t)
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextStrokeTransparency = 0.4
	l.TextStrokeColor3 = C.SHADOW
	l.ZIndex = 3
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.ZIndex = 3
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function sizeLimit(l, max, min)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = max
	c.MinTextSize = min or 8
	c.Parent = l
	return c
end

local function tweenTo(obj, info, props)
	TweenService:Create(obj, info, props):Play()
end

-- Parchment without UITheme.paper's stroke (rows need their own outline).
local function parchment(f, rotation)
	f.BackgroundColor3 = C.PAPER
	f.BackgroundTransparency = 0
	f.BorderSizePixel = 0
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.PAPER_DARK), ColorSequenceKeypoint.new(0.4, C.PAPER), ColorSequenceKeypoint.new(1, C.PAPER_DARK) })
	g.Rotation = rotation or 70
	g.Parent = f
end

local function nail(parent, pos, z)
	local n = frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(7, 7), BackgroundColor3 = C.NAIL, ZIndex = z or 5 })
	corner(n, 99)
	stroke(n, C.STEEL_DARK, 1)
	return n
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
	pipRow = frame(parent, { BackgroundTransparency = 1, Position = UDim2.fromOffset(102, 60), Size = UDim2.fromOffset(124, 8) })
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 5)
	layout.Parent = pipRow
	for i = 1, 4 do
		local pip = frame(pipRow, { Size = UDim2.fromOffset(26, 8), BackgroundColor3 = PIP_OFF })
		corner(pip, 4)
		stroke(pip, C.BRASS, 1).Transparency = 0.2
		pips[i] = pip
	end
end

-- Health sits under the pips (Johnny), or moves up into their place.
local function layoutHealth(withPips)
	if hpBar then
		hpBar.Position = UDim2.fromOffset(102, withPips and 72 or 64)
		hpBar.Size = UDim2.new(1, -112, 0, withPips and 18 or 24)
	end
	if pipRow then
		pipRow.Visible = withPips
	end
end

function CharacterCard.init()
	local config = TuskConfig.Character
	gui = Instance.new("ScreenGui")
	gui.Name = "CharacterCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The card: a framed wooden board with metal corner brackets.
	card = Instance.new("Frame")
	card.Name = "Card"
	card.Position = UDim2.fromOffset(12, 10)
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.Parent = gui
	local planks = UITheme.wood(card, { Planks = 3, Border = 5, Radius = 10, Brackets = true, BracketSize = 12, Nails = false })
	cardStroke = card:FindFirstChildOfClass("UIStroke")
	scale = Instance.new("UIScale")
	scale.Parent = card
	-- Evolve flash over the planks (see CharacterCard.pop).
	flash = frame(planks, { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = GOLD, BackgroundTransparency = 1, ZIndex = 2 })

	-- Portrait: a parchment mat, the picture on a Roster-colour backing.
	local mat = frame(card, { Name = "Portrait", Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(84, 82) })
	UITheme.paper(mat, { Radius = 6, Stroke = 2 })
	photo = frame(mat, { Name = "Photo", Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10), BackgroundColor3 = (TuskConfig.Roster and TuskConfig.Roster[1] and TuskConfig.Roster[1].Color) or GOLD, ClipsDescendants = true })
	corner(photo, 4)
	stroke(photo, C.INK, 1.5)
	local photoShade = Instance.new("UIGradient")
	photoShade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(95, 80, 70))
	photoShade.Rotation = 90
	photoShade.Parent = photo
	if config.PortraitImage ~= "" then
		portrait = Instance.new("ImageLabel")
		portrait.BackgroundTransparency = 1
		portrait.Size = UDim2.fromScale(1, 1)
		portrait.Image = config.PortraitImage
		portrait.ScaleType = Enum.ScaleType.Crop
		portrait.ZIndex = 3
		portrait.Parent = photo
	else
		viewport = Instance.new("ViewportFrame")
		viewport.BackgroundTransparency = 1
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.Ambient = Color3.fromRGB(170, 160, 150)
		viewport.LightColor = Color3.fromRGB(255, 240, 220)
		viewport.LightDirection = Vector3.new(-1, -1, -1)
		viewport.ZIndex = 3
		viewport.Parent = photo
	end
	nail(mat, UDim2.new(0.5, 0, 0, 1), 5)

	-- Name plate: a straight parchment strip, the name in Bangers ink.
	local plate = frame(card, { Name = "NamePlate", Position = UDim2.fromOffset(102, 9), Size = UDim2.new(1, -112, 0, 28) })
	UITheme.paper(plate, { Radius = 5, Stroke = 2 })
	nameLabel = label(plate, {
		Position = UDim2.fromOffset(8, 1),
		Size = UDim2.new(1, -16, 1, -2),
		Font = F.Title,
		TextScaled = true, -- long names shrink to fit
		TextColor3 = C.INK,
		TextStrokeTransparency = 1,
		Text = config.Name,
	})
	sizeLimit(nameLabel, 24, 12)

	-- Stand: a dark inset with a strip of the Stand's colour.
	local inset = frame(card, { Name = "StandInset", Position = UDim2.fromOffset(102, 40), Size = UDim2.new(1, -112, 0, 17), BackgroundColor3 = C.SHADOW, BackgroundTransparency = 0.25 })
	corner(inset, 4)
	standStrip = frame(inset, { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Color3.fromRGB(200, 220, 255) })
	corner(standStrip, 4)
	standLabel = label(inset, {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -14, 1, 0),
		Font = F.Heavy,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(200, 220, 255),
		TextStrokeTransparency = 0.3,
		Text = config.Title,
	})
	sizeLimit(standLabel, 12, 8)
	buildPips(card)

	-- Health: a wood-framed bar, "HP" on the left and the numbers on the right.
	hpBar, hpFill = UITheme.bar(card, Color3.fromRGB(90, 220, 120), { Name = "Health", ZIndex = 3 })
	label(hpBar, { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0, 30, 1, 0), Font = F.Heavy, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.1, Text = "HP", ZIndex = 5 })
	hpText = label(hpBar, {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -8, 1, 0),
		Font = F.Heavy,
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		ZIndex = 5,
	})
	layoutHealth(true)

	-- A gold tab hanging under the card: opens the character list.
	tab = frame(gui, { Name = "CharactersTab", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(12 + CARD_W - 14, 10 + CARD_H - 3), Size = UDim2.fromOffset(122, 22), BackgroundColor3 = GOLD, ZIndex = 2 })
	corner(tab, 6)
	stroke(tab, C.WOOD_EDGE, 2)
	arrow = label(tab, {
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.new(1, 0, 1, -2),
		Font = F.Title,
		TextSize = 15,
		TextColor3 = C.INK,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "CHARACTERS  ▼",
		ZIndex = 3,
	})

	-- The whole card (and the tab) open the character list.
	local function hitbox(parent)
		local hit = Instance.new("TextButton")
		hit.Name = "OpenCharacters"
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 8
		hit.Parent = parent
		hit.Activated:Connect(CharacterCard.toggle)
		hit.MouseEnter:Connect(function()
			tweenTo(scale, UITheme.FAST, { Scale = 1.02 })
			if cardStroke then
				cardStroke.Color = GOLD
			end
			tab.BackgroundColor3 = C.GLOW
		end)
		hit.MouseLeave:Connect(function()
			tweenTo(scale, UITheme.SOFT, { Scale = 1 })
			if cardStroke then
				cardStroke.Color = C.WOOD_EDGE
			end
			tab.BackgroundColor3 = GOLD
		end)
		hit.MouseButton1Down:Connect(function()
			tweenTo(scale, UITheme.SOFT, { Scale = 0.98 })
		end)
		hit.MouseButton1Up:Connect(function()
			tweenTo(scale, UITheme.FAST, { Scale = 1 })
		end)
		return hit
	end
	hitbox(card)
	hitbox(tab)
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
-- The character list
---------------------------------------------------------------------------
local LIST_W = 360
local ROW_H = 52
local HEAD_H = 84 -- title, count and search box
local dropdownHeight = 0
local ROW_BG = C.PAPER
local ROW_HOVER = Color3.fromRGB(255, 238, 204)
local GREEN = C.GREEN
local RED = C.RED
local GREY = Color3.fromRGB(128, 112, 96)
local REST_EDGE = C.BURNT

-- "JOHNNY JOESTAR" -> "JJ", "SANDMAN" -> "S".
local function initials(name)
	local out = ""
	for word in string.gmatch(name, "%S+") do
		if #out < 2 and word:sub(1, 1):match("%w") then
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

-- A row's outline: burnt parchment edge at rest, the character's colour
-- when hovered or playing.
local function setOutline(info, on)
	info.Outline.Color = on and info.Entry.Color or REST_EDGE
	info.Outline.Thickness = on and 3 or 1.5
	info.Outline.Transparency = on and 0 or 0.35
end

function buildDropdown()
	dropdown = Instance.new("Frame")
	dropdown.Name = "CharacterList"
	dropdown.Position = UDim2.fromOffset(12, 10 + CARD_H + 26)
	dropdown.Size = UDim2.fromOffset(LIST_W, 0)
	dropdown.ClipsDescendants = true
	dropdown.Visible = false
	dropdown.Parent = gui
	UITheme.wood(dropdown, { Planks = 6, Border = 5, Radius = 10, Nails = true, Brackets = true, BracketSize = 12 })

	-- Header: title, how many, a search box (stays put while the list scrolls).
	label(dropdown, { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -130, 0, 28), Font = F.Title, TextSize = 26, TextColor3 = C.PAPER, TextStrokeTransparency = 0.2, Text = "CHOOSE YOUR FIGHTER" })
	local countChip = frame(dropdown, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 11), Size = UDim2.fromOffset(96, 22), BackgroundColor3 = C.SHADOW, BackgroundTransparency = 0.25 })
	corner(countChip, 11)
	countLabel = label(countChip, { Size = UDim2.fromScale(1, 1), Font = F.Heavy, TextSize = 11, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, Text = "" })
	local searchMat = frame(dropdown, { Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 30) })
	UITheme.paper(searchMat, { Radius = 8, Stroke = 2 })
	label(searchMat, { Position = UDim2.fromOffset(9, 0), Size = UDim2.fromOffset(20, 30), Font = F.Heavy, TextSize = 14, TextColor3 = C.BURNT, TextStrokeTransparency = 1, Text = "⌕" })
	searchBox = Instance.new("TextBox")
	searchBox.Name = "Search"
	searchBox.BackgroundTransparency = 1
	searchBox.Position = UDim2.fromOffset(30, 0)
	searchBox.Size = UDim2.new(1, -38, 1, 0)
	searchBox.Font = F.Body
	searchBox.TextSize = 14
	searchBox.TextColor3 = C.INK
	searchBox.PlaceholderText = "Search a name or a Stand..."
	searchBox.PlaceholderColor3 = FADED_INK
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.ClearTextOnFocus = false
	searchBox.Text = ""
	searchBox.ZIndex = 4
	searchBox.Parent = searchMat
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		applyFilter()
	end)
	frame(dropdown, { Position = UDim2.fromOffset(14, HEAD_H - 4), Size = UDim2.new(1, -28, 0, 2), BackgroundColor3 = C.WOOD_EDGE, BackgroundTransparency = 0.3 })

	dropdownList = Instance.new("ScrollingFrame")
	dropdownList.BackgroundTransparency = 1
	dropdownList.BorderSizePixel = 0
	dropdownList.Position = UDim2.fromOffset(0, HEAD_H)
	dropdownList.Size = UDim2.new(1, 0, 1, -HEAD_H - 4)
	dropdownList.CanvasSize = UDim2.new()
	dropdownList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	dropdownList.ScrollBarThickness = 5
	dropdownList.ScrollingDirection = Enum.ScrollingDirection.Y
	dropdownList.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	dropdownList.ScrollBarImageColor3 = GOLD
	dropdownList.ZIndex = 3
	dropdownList.Parent = dropdown
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = dropdownList
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = dropdownList
	emptyLabel = label(dropdownList, { LayoutOrder = 9999, Size = UDim2.new(1, 0, 0, 40), Font = F.Body, TextSize = 13, TextColor3 = C.PAPER, TextXAlignment = Enum.TextXAlignment.Center, Text = "Nobody by that name.", Visible = false })

	rosterRows = {}
	for order, entry in ipairs(TuskConfig.Roster or {}) do
		-- The whole row is the button: a parchment strip.
		local row = Instance.new("TextButton")
		row.Name = entry.Id
		row.LayoutOrder = order
		row.Text = ""
		row.AutoButtonColor = false
		row.Size = UDim2.new(1, 0, 0, ROW_H)
		row.ZIndex = 3
		row.Parent = dropdownList
		parchment(row, 80)
		corner(row, 8)
		local outline = stroke(row, REST_EDGE, 1.5)
		outline.Transparency = 0.35
		local rowScale = Instance.new("UIScale")
		rowScale.Parent = row
		-- A strip of the character's colour down the left edge.
		local strip = frame(row, { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = entry.Color })
		corner(strip, 8)

		-- Round badge with their initials.
		local badge = frame(row, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = entry.Color })
		corner(badge, 99)
		stroke(badge, C.WOOD_EDGE, 2)
		local shade = Instance.new("UIGradient")
		shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
		shade.Rotation = 90
		shade.Parent = badge
		label(badge, { Size = UDim2.fromScale(1, 1), Font = F.Title, TextSize = 19, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2, Text = initials(entry.Name) })

		-- Name and Stand shrink to fit instead of being cut off.
		local nameText = label(row, { Position = UDim2.fromOffset(60, 7), Size = UDim2.new(1, -158, 0, 22), Font = F.Title, TextScaled = true, TextStrokeTransparency = 1, TextColor3 = entry.Available and C.INK or FADED_INK, Text = entry.Name })
		sizeLimit(nameText, 20, 11)
		local standText = label(row, { Position = UDim2.fromOffset(60, 30), Size = UDim2.new(1, -158, 0, 14), Font = F.Heavy, TextScaled = true, TextStrokeTransparency = 1, TextColor3 = entry.Color:Lerp(Color3.new(0, 0, 0), 0.45), Text = entry.Stand })
		sizeLimit(standText, 11, 7)

		-- Status pill.
		local status = label(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(84, 24),
			Font = F.Title,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.7,
			BackgroundTransparency = 0,
			BackgroundColor3 = GREY,
			Text = entry.Available and "SELECT" or "IN DEVELOPMENT",
		})
		corner(status, 12)
		local statusStroke = stroke(status, C.WOOD_EDGE, 1.5)
		local statusPad = Instance.new("UIPadding")
		statusPad.PaddingTop = UDim.new(0, 4)
		statusPad.PaddingBottom = UDim.new(0, 3)
		statusPad.PaddingLeft = UDim.new(0, 6)
		statusPad.PaddingRight = UDim.new(0, 6)
		statusPad.Parent = status
		sizeLimit(status, 16, 8)

		local info = { Row = row, Order = order, Status = status, StatusStroke = statusStroke, Entry = entry, Outline = outline, Name = nameText, Selectable = false, Playing = false }
		rosterRows[entry.Id] = info

		-- Hover: the row lightens, lifts, and takes the character's colour as its outline.
		local function hover(on)
			local from = row.BackgroundColor3
			local to = on and ROW_HOVER or ROW_BG
			tween(0.12, function(a)
				row.BackgroundColor3 = from:Lerp(to, a)
			end)
			setOutline(info, on or info.Playing)
			tweenTo(rowScale, on and UITheme.FAST or UITheme.SOFT, { Scale = on and 1.015 or 1 })
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
			-- A little press bounce, then ask the server and close.
			tween(0.15, function(a)
				status.Size = UDim2.fromOffset(84 - 8 * math.sin(a * math.pi), 24 - 4 * math.sin(a * math.pi))
			end)
			Net.get("TuskRequest"):FireServer("Character", entry.Id)
			task.delay(0.15, function()
				if open then
					CharacterCard.toggle()
				end
			end)
		end)
	end
	applyFilter()
end

-- Search: show only rows whose name or Stand contains the text.
function applyFilter()
	if not rosterRows then
		return
	end
	local q = searchBox and string.lower((searchBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")) or ""
	local shown, total = 0, 0
	for _, info in pairs(rosterRows) do
		total = total + 1
		local hay = string.lower(info.Entry.Name .. " " .. info.Entry.Stand .. " " .. info.Entry.Id)
		local match = q == "" or string.find(hay, q, 1, true) ~= nil
		info.Row.Visible = match
		if match then
			shown = shown + 1
		end
	end
	if emptyLabel then
		emptyLabel.Visible = shown == 0
	end
	if countLabel then
		countLabel.Text = q == "" and (total .. " FIGHTERS") or (shown .. " OF " .. total)
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
	-- Each row: PLAYING (green), SELECT (red), NOT INSTALLED (grey: that
	-- character's _Server/_Client scripts aren't in the game) or IN DEVELOPMENT.
	local current = act and Registry.characterOf(act)
	local installed = installedSet()
	for id, row in pairs(rosterRows) do
		local playing = current == id
		local missing = installed ~= nil and not installed[id]
		row.Playing = playing
		if row.Entry.Available then
			row.Status.Text = playing and "PLAYING" or (missing and "NOT INSTALLED" or "SELECT")
			row.Status.BackgroundColor3 = playing and GREEN or (missing and GREY or RED)
			row.Status.TextColor3 = missing and Color3.fromRGB(228, 216, 200) or Color3.new(1, 1, 1)
			row.Selectable = not playing and not missing
		end
		row.StatusStroke.Color = row.Status.BackgroundColor3:Lerp(Color3.new(0, 0, 0), 0.5)
		setOutline(row, playing)
		row.Name.TextColor3 = (row.Entry.Available and not missing) and C.INK or FADED_INK
		row.Row.LayoutOrder = playing and 0 or row.Order
	end
	applyFilter()
end

function CharacterCard.toggle()
	if not dropdown then
		return
	end
	open = not open
	local rows = #(TuskConfig.Roster or {})
	local full = HEAD_H + 16 + rows * (ROW_H + 6)
	-- About five rows (never more than 60% of the screen); the rest scrolls.
	local screenH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 600
	local target = math.min(full, HEAD_H + 16 + 5.4 * (ROW_H + 6), math.max(220, screenH * 0.6))
	refreshDropdown(shownAct)
	if open then
		dropdown.Visible = true
		dropdownList.CanvasPosition = Vector2.new()
	elseif searchBox then
		searchBox.Text = ""
	end
	arrow.Text = open and "CLOSE  ▲" or "CHARACTERS  ▼"
	local from = dropdownHeight
	local to = open and target or 0
	VFXLib.animate(0.22, function(a)
		dropdownHeight = from + (to - from) * VFXLib.easeOut(a)
		dropdown.Size = UDim2.fromOffset(LIST_W, dropdownHeight)
	end, function()
		if not open then
			dropdown.Visible = false
		end
	end)
end

function CharacterCard.pop(color)
	-- The board bounces and its planks flash in the Act colour.
	flash.BackgroundColor3 = color
	if cardStroke then
		cardStroke.Color = color
	end
	VFXLib.animate(0.5, function(a)
		scale.Scale = 1 + 0.1 * math.sin(a * math.pi)
		flash.BackgroundTransparency = 0.35 + 0.65 * a
	end, function()
		scale.Scale = 1
		flash.BackgroundTransparency = 1
		if cardStroke then
			cardStroke.Color = C.WOOD_EDGE
		end
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
		local isTusk = who == "Johnny" -- (only Tusk has Act pips / the evolve pop)
		-- Name plate follows the character (from TuskConfig.Roster).
		for _, entry in ipairs(TuskConfig.Roster or {}) do
			if entry.Id == who then
				nameLabel.Text = entry.Name
				photo.BackgroundColor3 = entry.Color
			end
		end
		if info and info.CardTitle then
			standLabel.Text = info.CardTitle
		else
			standLabel.Text = info and ("STAND  ·  " .. info.Name) or TuskConfig.Character.Title
		end
		local theme = info and info.Theme.Primary or Color3.fromRGB(200, 220, 255)
		standLabel.TextColor3 = theme:Lerp(Color3.new(1, 1, 1), 0.25)
		standStrip.BackgroundColor3 = theme
		for i, pip in ipairs(pips) do
			local on = act ~= nil and i <= act
			local t = Registry.get(i) and Registry.get(i).Theme.Primary or GOLD
			pip.BackgroundColor3 = on and t or PIP_OFF
		end
		layoutHealth(isTusk)
		if not isTusk then
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
