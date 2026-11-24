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

**What it does:** Top-left character card, in the bounty-board style: a small framed wooden board (planks, grain, metal corner brackets) that bounces when you hover or press it portrait in a parchment mat with a nail on top: your uploaded image (TuskConfig.Character.PortraitImage), or a live 3D view of your own avatar, on a backing in your character's Roster colour JOHNNY JOESTAR name plate: a burnt-edge parchment strip, Bangers ink current Stand ("TUSK ACT 2") on a dark inset in that Act's colour four brass-rimmed Act pips that light up as Tusk awakens wood-framed health meter with numbers (green -> red) Pops and flashes the planks in the Act colour when Tusk evolves.

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

	Top-left character card, in the bounty-board style:
	  * a small framed wooden board (planks, grain, metal corner brackets)
	    that bounces when you hover or press it
	  * portrait in a parchment mat with a nail on top: your uploaded image
	    (TuskConfig.Character.PortraitImage), or a live 3D view of your own
	    avatar, on a backing in your character's Roster colour
	  * JOHNNY JOESTAR name plate: a burnt-edge parchment strip, Bangers ink
	  * current Stand ("TUSK ACT 2") on a dark inset in that Act's colour
	  * four brass-rimmed Act pips that light up as Tusk awakens
	  * wood-framed health meter with numbers (green -> red)
	Pops and flashes the planks in the Act colour when Tusk evolves.

	DROPDOWN: tap/click the card to open the character list
	(TuskConfig.Roster) on a wooden board: one parchment row per character
	with a Roster-colour badge, name, Stand and a status chip (green
	PLAYING, red SELECT, grey NOT INSTALLED / IN DEVELOPMENT); rows light
	up, take a Roster-colour outline and bounce on hover, and the whole row
	is clickable. Your current character is outlined and listed first.
	Characters whose scripts aren't in the game are shown as NOT INSTALLED,
	and characters that aren't finished as IN DEVELOPMENT (neither is
	selectable).
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

local gui, card, portrait, viewport, photo, nameLabel, standLabel, pips, hpFill, hpText, scale, arrow, flash, cardStroke
local dropdown, dropdownList, rosterRows
-- Declared up here so init() can call them (they are defined further down).
local buildDropdown, refreshDropdown
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

local function tweenTo(obj, info, props)
	TweenService:Create(obj, info, props):Play()
end

-- Parchment without UITheme.paper's stroke (rows need their own outline).
local function parchment(frame, rotation)
	frame.BackgroundColor3 = C.PAPER
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.PAPER_DARK), ColorSequenceKeypoint.new(0.38, C.PAPER), ColorSequenceKeypoint.new(1, C.PAPER_DARK) })
	g.Rotation = rotation or 70
	g.Parent = frame
end

local function nail(parent, pos, z)
	local n = Instance.new("Frame")
	n.AnchorPoint = Vector2.new(0.5, 0.5)
	n.Position = pos
	n.Size = UDim2.fromOffset(7, 7)
	n.BackgroundColor3 = C.NAIL
	n.ZIndex = z or 5
	n.Parent = parent
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
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(98, 53)
	row.Size = UDim2.fromOffset(124, 12)
	row.ZIndex = 3
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 5)
	layout.Parent = row
	for i = 1, 4 do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(25, 9)
		pip.BackgroundColor3 = PIP_OFF
		pip.BorderSizePixel = 0
		pip.ZIndex = 3
		pip.Parent = row
		corner(pip, 4)
		stroke(pip, C.BRASS, 1.5).Transparency = 0.15
		pips[i] = pip
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
	card.Size = UDim2.fromOffset(330, 96)
	card.Parent = gui
	local planks = UITheme.wood(card, { Planks = 3, Border = 5, Radius = 10, Brackets = true, BracketSize = 12, Nails = false })
	cardStroke = card:FindFirstChildOfClass("UIStroke")
	scale = Instance.new("UIScale")
	scale.Parent = card
	-- Evolve flash over the planks (see CharacterCard.pop).
	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = GOLD
	flash.BackgroundTransparency = 1
	flash.ZIndex = 2
	flash.Parent = planks

	-- Portrait: a parchment mat, the picture on a Roster-colour backing.
	local frame = Instance.new("Frame")
	frame.Name = "Portrait"
	frame.Position = UDim2.fromOffset(8, 8)
	frame.Size = UDim2.fromOffset(80, 80)
	frame.ZIndex = 3
	frame.Parent = card
	UITheme.paper(frame, { Radius = 6, Stroke = 2 })
	photo = Instance.new("Frame")
	photo.Name = "Photo"
	photo.Position = UDim2.fromOffset(5, 5)
	photo.Size = UDim2.new(1, -10, 1, -10)
	photo.BackgroundColor3 = (TuskConfig.Roster and TuskConfig.Roster[1] and TuskConfig.Roster[1].Color) or GOLD
	photo.ClipsDescendants = true
	photo.ZIndex = 3
	photo.Parent = frame
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
	nail(frame, UDim2.new(0.5, 0, 0, 1), 5)

	-- Name plate: a burnt-edge parchment strip.
	local plate = Instance.new("Frame")
	plate.Name = "NamePlate"
	plate.Position = UDim2.fromOffset(96, 7)
	plate.Size = UDim2.new(1, -132, 0, 26)
	plate.Rotation = -1
	plate.ZIndex = 3
	plate.Parent = card
	UITheme.paper(plate, { Radius = 4, Stroke = 2 })
	nameLabel = label(plate, {
		Position = UDim2.fromOffset(6, 1),
		Size = UDim2.new(1, -12, 1, -2),
		Font = F.Title,
		TextScaled = true, -- long names ("FUNNY VALENTINE") shrink to fit
		TextColor3 = C.INK,
		TextStrokeTransparency = 1,
		Text = config.Name,
	})
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = 26
	nameLimit.MinTextSize = 12
	nameLimit.Parent = nameLabel

	-- Stand: a dark inset so the Act colour reads on the wood.
	local inset = Instance.new("Frame")
	inset.Name = "StandInset"
	inset.Position = UDim2.fromOffset(96, 35)
	inset.Size = UDim2.new(1, -104, 0, 16)
	inset.BackgroundColor3 = C.SHADOW
	inset.BackgroundTransparency = 0.3
	inset.BorderSizePixel = 0
	inset.ZIndex = 3
	inset.Parent = card
	corner(inset, 4)
	standLabel = label(inset, {
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -10, 1, 0),
		Font = F.Heavy,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(200, 220, 255),
		TextStrokeTransparency = 0.2,
		Text = config.Title,
	})
	buildPips(card)

	-- Health: a wood-framed meter with the numbers on top.
	local hp
	hp, hpFill = UITheme.bar(card, Color3.fromRGB(90, 220, 120), {
		Name = "Health",
		Position = UDim2.fromOffset(96, 68),
		Size = UDim2.new(1, -104, 0, 20),
		ZIndex = 3,
	})
	hpText = label(hp, {
		Size = UDim2.fromScale(1, 1),
		Font = F.Heavy,
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		ZIndex = 5,
	})

	-- The whole card is a button that opens the character dropdown.
	local knob = Instance.new("Frame")
	knob.Name = "Arrow"
	knob.AnchorPoint = Vector2.new(1, 0)
	knob.Position = UDim2.new(1, -9, 0, 9)
	knob.Size = UDim2.fromOffset(22, 22)
	knob.BackgroundColor3 = GOLD
	knob.ZIndex = 3
	knob.Parent = card
	corner(knob, 99)
	stroke(knob, C.WOOD_EDGE, 2)
	arrow = label(knob, {
		Size = UDim2.fromScale(1, 1),
		Font = F.Heavy,
		TextSize = 12,
		TextColor3 = C.INK,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "▼",
		ZIndex = 4,
	})
	local hit = Instance.new("TextButton")
	hit.Name = "OpenCharacters"
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 8
	hit.Parent = card
	hit.Activated:Connect(CharacterCard.toggle)
	-- Hover / press: the board bounces and its rim turns gold.
	hit.MouseEnter:Connect(function()
		tweenTo(scale, UITheme.FAST, { Scale = 1.03 })
		if cardStroke then
			cardStroke.Color = GOLD
		end
	end)
	hit.MouseLeave:Connect(function()
		tweenTo(scale, UITheme.SOFT, { Scale = 1 })
		if cardStroke then
			cardStroke.Color = C.WOOD_EDGE
		end
	end)
	hit.MouseButton1Down:Connect(function()
		tweenTo(scale, UITheme.SOFT, { Scale = 0.97 })
	end)
	hit.MouseButton1Up:Connect(function()
		tweenTo(scale, UITheme.FAST, { Scale = 1 })
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
local ROW_BG = C.PAPER
local ROW_HOVER = Color3.fromRGB(255, 236, 196)
local GREEN = C.GREEN
local RED = C.RED
local GREY = Color3.fromRGB(120, 104, 88)
local REST_EDGE = C.BURNT

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

-- A row's outline: burnt parchment edge at rest, the character's colour
-- when hovered or playing.
local function setOutline(info, on)
	info.Outline.Color = on and info.Entry.Color or REST_EDGE
	info.Outline.Thickness = on and 3 or 2
	info.Outline.Transparency = on and 0 or 0.2
end

function buildDropdown()
	dropdown = Instance.new("Frame")
	dropdown.Name = "CharacterList"
	dropdown.Position = UDim2.fromOffset(12, 112)
	dropdown.Size = UDim2.fromOffset(ROW_W, 0)
	dropdown.ClipsDescendants = true
	dropdown.Visible = false
	dropdown.Parent = gui
	UITheme.wood(dropdown, { Planks = 6, Border = 5, Radius = 10, Nails = true })

	-- Header (stays put while the list scrolls): a painted title on the planks.
	label(dropdown, {
		Position = UDim2.fromOffset(14, 7),
		Size = UDim2.new(1, -28, 0, 24),
		Font = F.Title,
		TextSize = 24,
		TextColor3 = C.PAPER,
		TextStrokeTransparency = 0.2,
		Text = "CHARACTERS",
	})
	label(dropdown, {
		Position = UDim2.fromOffset(14, 31),
		Size = UDim2.new(1, -28, 0, 14),
		Font = F.Body,
		TextSize = 10,
		TextColor3 = GOLD,
		TextStrokeTransparency = 0.5,
		Text = "Scroll for more  ·  BLOCK (F)  ·  DASH (Q)",
	})
	local line = Instance.new("Frame")
	line.Position = UDim2.fromOffset(12, 49)
	line.Size = UDim2.new(1, -24, 0, 2)
	line.BackgroundColor3 = C.WOOD_EDGE
	line.BackgroundTransparency = 0.2
	line.BorderSizePixel = 0
	line.ZIndex = 3
	line.Parent = dropdown

	dropdownList = Instance.new("ScrollingFrame")
	dropdownList.BackgroundTransparency = 1
	dropdownList.BorderSizePixel = 0
	dropdownList.Position = UDim2.fromOffset(0, 52)
	dropdownList.Size = UDim2.new(1, 0, 1, -56)
	dropdownList.CanvasSize = UDim2.new()
	dropdownList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	dropdownList.ScrollBarThickness = 6
	dropdownList.ScrollingDirection = Enum.ScrollingDirection.Y
	dropdownList.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	dropdownList.ScrollBarImageColor3 = GOLD
	dropdownList.ZIndex = 3
	dropdownList.Parent = dropdown
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = dropdownList
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = dropdownList

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
		corner(row, 6)
		local outline = stroke(row, REST_EDGE, 2)
		outline.Transparency = 0.2
		local rowScale = Instance.new("UIScale")
		rowScale.Parent = row

		-- Colour badge with initials (the character's Roster colour).
		local badge = Instance.new("Frame")
		badge.Position = UDim2.fromOffset(7, 7)
		badge.Size = UDim2.fromOffset(40, 40)
		badge.BackgroundColor3 = entry.Color
		badge.ZIndex = 3
		badge.Parent = row
		corner(badge, 8)
		stroke(badge, C.WOOD_EDGE, 2)
		local shade = Instance.new("UIGradient")
		shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
		shade.Rotation = 90
		shade.Parent = badge
		label(badge, {
			Size = UDim2.fromScale(1, 1),
			Font = F.Title,
			TextSize = 22,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.2,
			Text = initials(entry.Name),
		})

		-- Names and Stands shrink to fit instead of being cut off ("JOHNNY...").
		local nameText = label(row, {
			Position = UDim2.fromOffset(55, 6),
			Size = UDim2.new(1, -150, 0, 24),
			Font = F.Title,
			TextScaled = true,
			TextStrokeTransparency = 1,
			TextColor3 = entry.Available and C.INK or FADED_INK,
			Text = entry.Name,
		})
		local nameLimit = Instance.new("UITextSizeConstraint")
		nameLimit.MaxTextSize = 21
		nameLimit.MinTextSize = 11
		nameLimit.Parent = nameText
		local standText = label(row, {
			Position = UDim2.fromOffset(55, 30),
			Size = UDim2.new(1, -150, 0, 14),
			Font = F.Heavy,
			TextScaled = true,
			TextStrokeTransparency = 1,
			-- The Roster colour, darkened so it reads on parchment.
			TextColor3 = entry.Color:Lerp(Color3.new(0, 0, 0), 0.4),
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
			Font = F.Title,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.6,
			BackgroundTransparency = 0,
			BackgroundColor3 = GREY,
			Text = entry.Available and "SELECT" or "IN DEVELOPMENT",
		})
		corner(status, 7)
		local statusStroke = stroke(status, C.WOOD_EDGE, 2)
		local statusPad = Instance.new("UIPadding")
		statusPad.PaddingTop = UDim.new(0, 4)
		statusPad.PaddingBottom = UDim.new(0, 3)
		statusPad.PaddingLeft = UDim.new(0, 4)
		statusPad.PaddingRight = UDim.new(0, 4)
		statusPad.Parent = status
		local statusLimit = Instance.new("UITextSizeConstraint")
		statusLimit.MaxTextSize = 17
		statusLimit.Parent = status

		local info = { Row = row, Order = order, Status = status, StatusStroke = statusStroke, Entry = entry, Outline = outline, Name = nameText, Selectable = false, Playing = false }
		rosterRows[entry.Id] = info

		-- Hover: the row lights up, bounces, and the outline shows in the character's colour.
		local function hover(on)
			local from = row.BackgroundColor3
			local to = on and ROW_HOVER or ROW_BG
			tween(0.12, function(a)
				row.BackgroundColor3 = from:Lerp(to, a)
			end)
			setOutline(info, on or info.Playing)
			tweenTo(rowScale, on and UITheme.FAST or UITheme.SOFT, { Scale = on and 1.02 or 1 })
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
			row.Status.BackgroundColor3 = playing and GREEN or (missing and GREY or RED)
			row.Status.TextColor3 = missing and Color3.fromRGB(225, 212, 196) or Color3.new(1, 1, 1)
			row.Selectable = not playing and not missing
		end
		row.StatusStroke.Color = row.Status.BackgroundColor3:Lerp(Color3.new(0, 0, 0), 0.5)
		setOutline(row, playing)
		row.Name.TextColor3 = (row.Entry.Available and not missing) and (playing and RED or C.INK) or FADED_INK
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
	-- The board bounces and its planks flash in the Act colour.
	flash.BackgroundColor3 = color
	if cardStroke then
		cardStroke.Color = color
	end
	VFXLib.animate(0.5, function(a)
		scale.Scale = 1 + 0.12 * math.sin(a * math.pi)
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
		local isGyro = who ~= "Johnny" -- (any non-Tusk character: no Act pips / evolve pop)
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
		standLabel.TextColor3 = info and info.Theme.Primary or Color3.fromRGB(200, 220, 255)
		-- Act pips are Tusk's progression; hidden for other characters.
		for i, pip in ipairs(pips) do
			pip.Visible = not isGyro
			local on = act ~= nil and i <= act
			local theme = Registry.get(i) and Registry.get(i).Theme.Primary or GOLD
			pip.BackgroundColor3 = on and theme or PIP_OFF
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
