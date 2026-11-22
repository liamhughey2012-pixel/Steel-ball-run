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

local gui, card, portrait, viewport, standLabel, pips, hpFill, hpText, scale
local shownAct

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

	label(card, {
		Position = UDim2.fromOffset(98, 6),
		Size = UDim2.new(1, -106, 0, 28),
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
		standLabel.Text = info and ("STAND  ·  " .. info.Name) or TuskConfig.Character.Title
		standLabel.TextColor3 = info and info.Theme.Primary or Color3.fromRGB(200, 220, 255)
		for i, pip in ipairs(pips) do
			local on = act ~= nil and i <= act
			local theme = Registry.get(i) and Registry.get(i).Theme.Primary or GOLD
			pip.BackgroundColor3 = on and theme or Color3.fromRGB(60, 60, 80)
		end
		if evolved and info then
			CharacterCard.pop(info.Theme.Primary)
		end
	end
end

return CharacterCard
```
