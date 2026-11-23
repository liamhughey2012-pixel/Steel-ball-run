---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › UI"
updated: 2026-11-22
---
# CombatUI

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| **Exact name** | `CombatUI` (capitals matter) |

**What it does:** Battlegrounds-style fight feedback: TARGET BAR: hit someone and their name + health bar appears at the top of the screen. The bar drains smoothly, with a white "chunk" that catches up a moment later so big hits read. Fades after a few seconds. DAMAGE EDGES: the screen edges flash red when you get hit, and pulse while your health is low. GUARD BAR: under your character while you block (or while it refills); it turns red as it runs out and shows BROKEN after a guard break. DASH / BLOCK chips (bottom right): the dash cooldown sweeps back. Driven by the shared "Hit" event (CombatAdapter).

## How to add it
1. In Studio's Explorer, find **UI** (StarterPlayer › StarterPlayerScripts › SpinClient › UI).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **CombatUI**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
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

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local Net = require(Shared.Net)

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
local TuskConfig = require(Shared.TuskConfig)
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
	-- Dash chip: grey sweep while on cooldown.
	local readyAt = character and character:GetAttribute("DashReadyAt") or 0
	local left = readyAt - t
	local dashChip = chips.Dash
	if left > 0 then
		dashChip.Sweep.Size = UDim2.fromScale(math.clamp(left / (d.DashCooldown or 2.2), 0, 1), 1)
		dashChip.Label.Text = string.format("DASH %.1f", left)
		dashChip.Label.TextColor3 = Color3.fromRGB(170, 170, 185)
	else
		dashChip.Sweep.Size = UDim2.fromScale(0, 1)
		dashChip.Label.Text = "DASH"
		dashChip.Label.TextColor3 = Color3.new(1, 1, 1)
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
```
