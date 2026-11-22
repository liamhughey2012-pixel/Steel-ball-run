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
	(TuskConfig.Roster). Johnny Joestar expands into his four Tusk Acts,
	each with its moves, showing which Act you are on now. Characters that
	aren't finished are shown as IN DEVELOPMENT (not selectable).
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
local dropdown, dropdownList, actRows, rosterRows
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
-- Dropdown
---------------------------------------------------------------------------
local ROW_W = 290

local function chip(parent, text, color, textColor)
	local c = label(parent, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(104, 22),
		Font = Enum.Font.GothamBlack,
		TextSize = 11,
		TextColor3 = textColor or Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 1,
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		Text = text,
	})
	corner(c, 6)
	return c
end

function buildDropdown()
	dropdown = Instance.new("Frame")
	dropdown.Name = "CharacterList"
	dropdown.Position = UDim2.fromOffset(12, 112)
	dropdown.Size = UDim2.fromOffset(ROW_W, 0)
	dropdown.BackgroundColor3 = DARK
	dropdown.BackgroundTransparency = 0.08
	dropdown.ClipsDescendants = true
	dropdown.Visible = false
	dropdown.Parent = gui
	corner(dropdown, 12)
	stroke(dropdown, GOLD, 1.5)

	dropdownList = Instance.new("ScrollingFrame")
	dropdownList.BackgroundTransparency = 1
	dropdownList.BorderSizePixel = 0
	dropdownList.Size = UDim2.fromScale(1, 1)
	dropdownList.CanvasSize = UDim2.new()
	dropdownList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	dropdownList.ScrollBarThickness = 4
	dropdownList.Parent = dropdown
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = dropdownList
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = dropdownList

	label(dropdownList, {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.GothamBlack,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(170, 160, 200),
		Text = "CHARACTERS",
	})

	rosterRows, actRows = {}, {}
	local order = 1
	for _, entry in ipairs(TuskConfig.Roster or {}) do
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		order = order + 1
		row.Size = UDim2.new(1, 0, 0, entry.Note and 62 or 50)
		row.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
		row.Parent = dropdownList
		corner(row, 8)
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(0, 4, 1, -12)
		stripe.Position = UDim2.fromOffset(6, 6)
		stripe.BackgroundColor3 = entry.Color
		stripe.BorderSizePixel = 0
		stripe.Parent = row
		label(row, { Position = UDim2.fromOffset(16, 4), Size = UDim2.new(1, -130, 0, 24), Font = Enum.Font.Bangers, TextSize = 22, TextColor3 = entry.Available and GOLD or Color3.fromRGB(150, 145, 160), Text = entry.Name })
		label(row, { Position = UDim2.fromOffset(16, 27), Size = UDim2.new(1, -130, 0, 16), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = entry.Color, Text = "STAND: " .. entry.Stand })
		if entry.Note then
			label(row, { Position = UDim2.fromOffset(16, 43), Size = UDim2.new(1, -24, 0, 14), Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = Color3.fromRGB(170, 170, 185), Text = entry.Note })
		end
		local status
		if entry.Available then
			status = Instance.new("TextButton")
			status.AnchorPoint = Vector2.new(1, 0)
			status.Position = UDim2.new(1, -8, 0, 12)
			status.Size = UDim2.fromOffset(104, 24)
			status.Font = Enum.Font.GothamBlack
			status.TextSize = 11
			status.AutoButtonColor = true
			status.Parent = row
			corner(status, 6)
			status.Activated:Connect(function()
				Net.get("TuskRequest"):FireServer("Character", entry.Id)
			end)
		else
			status = chip(row, "IN DEVELOPMENT", Color3.fromRGB(60, 58, 72), Color3.fromRGB(190, 185, 200))
			status.AnchorPoint = Vector2.new(1, 0)
			status.Position = UDim2.new(1, -8, 0, 12)
		end
		rosterRows[entry.Id] = { Row = row, Status = status, Entry = entry }

		-- Johnny expands into the four Tusk Acts.
		if entry.Id == "Johnny" then
			for act = 1, 4 do
				local info = Registry.get(act)
				local actRow = Instance.new("Frame")
				actRow.LayoutOrder = order
				order = order + 1
				actRow.Size = UDim2.new(1, 0, 0, 52)
				actRow.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
				actRow.Parent = dropdownList
				corner(actRow, 8)
				local edge = stroke(actRow, info.Theme.Primary, 1.5)
				label(actRow, { Position = UDim2.fromOffset(12, 3), Size = UDim2.new(1, -120, 0, 20), Font = Enum.Font.Bangers, TextSize = 18, TextColor3 = info.Theme.Primary, Text = info.Name })
				label(actRow, { Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -20, 0, 13), Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = Color3.fromRGB(200, 205, 220), TextTruncate = Enum.TextTruncate.AtEnd, Text = "1 " .. info.Abilities[1] .. " · 2 " .. info.Abilities[2] .. " · 3 " .. info.Abilities[3] })
				label(actRow, { Position = UDim2.fromOffset(12, 35), Size = UDim2.new(1, -20, 0, 13), Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = GOLD, TextTruncate = Enum.TextTruncate.AtEnd, Text = "G " .. info.Ultimate .. (info.Next and (" → ACT " .. info.Next) or "  (FINAL FORM)") })
				local state = label(actRow, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 5), Size = UDim2.fromOffset(100, 16), Font = Enum.Font.GothamBlack, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
				actRows[act] = { Row = actRow, Edge = edge, State = state }
			end
		end
	end
end

function refreshDropdown(act)
	if not dropdown then
		return
	end
	-- Each character row: PLAYING (green) or SELECT (blue).
	local current = act and Registry.characterOf(act)
	for id, row in pairs(rosterRows) do
		if row.Entry.Available then
			local playing = current == id
			row.Status.Text = playing and "PLAYING" or "SELECT"
			row.Status.BackgroundColor3 = playing and Color3.fromRGB(40, 120, 70) or Color3.fromRGB(40, 90, 200)
			row.Status.TextColor3 = Color3.new(1, 1, 1)
			row.Status.Active = not playing
		end
	end
	if current ~= "Johnny" then
		act = nil -- Tusk Act rows only light up while playing Johnny
	end
	for i, r in pairs(actRows) do
		if act == i then
			r.State.Text = "◆ YOU ARE HERE"
			r.State.TextColor3 = Color3.new(1, 1, 1)
			r.Row.BackgroundColor3 = Color3.fromRGB(40, 34, 64)
			r.Edge.Thickness = 2.5
			r.Edge.Transparency = 0
		elseif act and i < act then
			r.State.Text = "AWAKENED ✓"
			r.State.TextColor3 = Color3.fromRGB(120, 220, 140)
			r.Row.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
			r.Edge.Thickness = 1
			r.Edge.Transparency = 0.4
		else
			r.State.Text = i == 1 and "START" or "AWAKEN WITH G"
			r.State.TextColor3 = Color3.fromRGB(160, 160, 180)
			r.Row.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
			r.Edge.Thickness = 1
			r.Edge.Transparency = 0.6
		end
	end
end

function CharacterCard.toggle()
	if not dropdown then
		return
	end
	open = not open
	local target = math.min(420, (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 600) - 170)
	refreshDropdown(shownAct)
	if open then
		dropdown.Visible = true
	end
	arrow.Text = open and "▲" or "▼"
	local from = dropdown.Size.Y.Offset
	local to = open and target or 0
	VFXLib.animate(0.2, function(a)
		dropdown.Size = UDim2.fromOffset(ROW_W, from + (to - from) * VFXLib.easeOut(a))
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
		local isGyro = act ~= nil and Registry.characterOf(act) == "Gyro"
		-- Name plate follows the character (from TuskConfig.Roster).
		local who = isGyro and "Gyro" or "Johnny"
		for _, entry in ipairs(TuskConfig.Roster or {}) do
			if entry.Id == who then
				nameLabel.Text = entry.Name
			end
		end
		if isGyro then
			standLabel.Text = "STEEL BALL USER"
		else
			standLabel.Text = info and ("STAND  ·  " .. info.Name) or TuskConfig.Character.Title
		end
		standLabel.TextColor3 = info and info.Theme.Primary or Color3.fromRGB(200, 220, 255)
		-- Act pips are Tusk's progression; hidden for Gyro.
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
