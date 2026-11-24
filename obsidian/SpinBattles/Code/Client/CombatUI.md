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

**What it does:** Battlegrounds-style fight feedback, in the bounty-board style: TARGET BAR: hit someone and a nailed wooden plank pops in at the top of the screen with their name in Bangers and a wood-framed health meter (green -> gold -> red). The meter drains smoothly, with a white "chunk" that catches up a moment later so big hits read. Shrinks away after a few seconds. DAMAGE EDGES: the screen edges flash red when you get hit, and pulse while your health is low. GUARD BAR: a small wood-framed meter under your character while you block (or while it refills); it turns red as it runs out and shows GUARD BROKEN after a guard break. DASH / BLOCK chips (bottom right): little wooden planks with a brass key cap; the dash cooldown sweeps back as a dark shadow, and the BLOCK plank glows steel-blue while you block. Driven by the shared "Hit" event (CombatAdapter).

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

	Battlegrounds-style fight feedback, in the bounty-board style:
	  * TARGET BAR: hit someone and a nailed wooden plank pops in at the top
	    of the screen with their name in Bangers and a wood-framed health
	    meter (green -> gold -> red). The meter drains smoothly, with a white
	    "chunk" that catches up a moment later so big hits read. Shrinks
	    away after a few seconds.
	  * DAMAGE EDGES: the screen edges flash red when you get hit, and pulse
	    while your health is low.
	  * GUARD BAR: a small wood-framed meter under your character while you
	    block (or while it refills); it turns red as it runs out and shows
	    GUARD BROKEN after a guard break.
	  * DASH / BLOCK chips (bottom right): little wooden planks with a brass
	    key cap; the dash cooldown sweeps back as a dark shadow, and the
	    BLOCK plank glows steel-blue while you block.
	Driven by the shared "Hit" event (CombatAdapter).
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local Net = require(Shared.Net)
local UITheme = require(script.Parent.UITheme)
local C = UITheme.C
local F = UITheme.Font

local CombatUI = {}
local player = Players.LocalPlayer
local GOLD = C.GOLD
local RED = Color3.fromRGB(230, 50, 60)
local BLOCK_BLUE = Color3.fromRGB(110, 180, 255)

local gui, bar, barScale, nameLabel, fill, chunk, hpText, edges
local target -- the model shown in the bar
local shownUntil = 0
local fillValue, chunkValue = 1, 1
local hurtFlash = 0
local TuskConfig = require(Shared.TuskConfig)
local guardGui, guardFill, guardText, chips
local stepDefense -- (defined further down)

local function corner(p, r)
	return UITheme.corner(p, r)
end

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextStrokeColor3 = C.SHADOW
	l.TextStrokeTransparency = 0.3
	l.ZIndex = 4
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
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
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Target bar (top centre): a nailed wooden plank.
	bar = Instance.new("Frame")
	bar.Name = "TargetBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 58)
	bar.Size = UDim2.fromOffset(340, 50)
	bar.Visible = false
	bar.Parent = gui
	UITheme.wood(bar, { Planks = 2, Border = 4, Radius = 8, Nails = true, Brackets = true, BracketSize = 10 })
	barScale = Instance.new("UIScale")
	barScale.Scale = 1
	barScale.Parent = bar
	nameLabel = text(bar, {
		Position = UDim2.fromOffset(14, 4),
		Size = UDim2.new(1, -100, 0, 21),
		Font = F.Title,
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.PAPER,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	hpText = text(bar, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 6),
		Size = UDim2.fromOffset(80, 16),
		Font = F.Heavy,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = GOLD,
	})
	local back
	back, fill = UITheme.bar(bar, RED, {
		Name = "Health",
		Position = UDim2.fromOffset(12, 26),
		Size = UDim2.new(1, -24, 0, 17),
		ZIndex = 3,
	})
	-- The white "chunk" sits under the fill, inside the meter's well.
	chunk = Instance.new("Frame")
	chunk.Name = "Chunk"
	chunk.BorderSizePixel = 0
	chunk.Size = UDim2.fromScale(1, 1)
	chunk.BackgroundColor3 = Color3.fromRGB(255, 244, 220)
	chunk.ZIndex = 3
	chunk.Parent = fill.Parent
	corner(chunk, 3)
	fill.ZIndex = 4
	for _, d in ipairs(fill:GetChildren()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 4
		end
	end

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
	if not bar.Visible then
		bar.Visible = true
		UITheme.pop(bar, 0.7)
	elseif barScale.Scale < 0.99 then
		-- Hit again while it was shrinking away: bounce back up.
		UITheme.pop(bar, barScale.Scale)
	end
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
		-- Shrinks away over its last 0.4 s (a fade would mean fading every plank).
		local fade = math.clamp((shownUntil - now) / 0.4, 0, 1)
		if fade < 1 then
			barScale.Scale = 0.6 + 0.4 * fade
		end
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
	f.ClipsDescendants = true
	f.Parent = gui
	local planks = UITheme.wood(f, { Planks = 1, Border = 3, Radius = 7, Nails = false, Stroke = 2 })
	local edge = f:FindFirstChildOfClass("UIStroke")
	-- Steel-blue glow while blocking.
	local tint = Instance.new("Frame")
	tint.Name = "Tint"
	tint.BorderSizePixel = 0
	tint.Size = UDim2.fromScale(1, 1)
	tint.BackgroundColor3 = BLOCK_BLUE
	tint.BackgroundTransparency = 1
	tint.ZIndex = 2
	tint.Parent = planks
	-- Cooldown: a dark shadow that sweeps back.
	local sweep = Instance.new("Frame")
	sweep.Name = "Sweep"
	sweep.BorderSizePixel = 0
	sweep.Size = UDim2.fromScale(0, 1)
	sweep.BackgroundColor3 = C.SHADOW
	sweep.BackgroundTransparency = 0.35
	sweep.ZIndex = 2
	sweep.Parent = planks
	-- Brass key cap.
	local keyLabel = text(f, {
		Name = "Key",
		BackgroundTransparency = 0,
		BackgroundColor3 = GOLD,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.fromOffset(22, 22),
		Font = F.Title,
		TextSize = 17,
		TextColor3 = C.INK,
		TextStrokeTransparency = 1,
		Text = key,
	})
	corner(keyLabel, 5)
	UITheme.stroke(keyLabel, C.WOOD_EDGE, 2)
	local label = text(f, {
		Position = UDim2.fromOffset(33, 0),
		Size = UDim2.new(1, -37, 1, 0),
		Font = F.Heavy,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.PAPER,
		Text = name,
	})
	return { Frame = f, Sweep = sweep, Tint = tint, Edge = edge, Label = label, Name = name }
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
	guardGui.Size = UDim2.fromOffset(96, 15)
	guardGui.StudsOffset = Vector3.new(0, -3.4, 0)
	guardGui.AlwaysOnTop = true
	guardGui.LightInfluence = 0
	guardGui.Enabled = false
	guardGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	guardGui.Parent = gui
	local back
	back, guardFill = UITheme.bar(guardGui, BLOCK_BLUE, { Name = "Guard", Size = UDim2.fromScale(1, 1) })
	guardText = text(back, {
		Size = UDim2.fromScale(1, 1),
		Font = F.Title,
		TextSize = 12,
		TextColor3 = C.PAPER,
		TextStrokeTransparency = 0.2,
		Text = "",
		ZIndex = 5,
	})
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
		dashChip.Label.TextColor3 = have > 0 and C.PAPER or Color3.fromRGB(175, 150, 120)
	else
		dashChip.Sweep.Size = UDim2.fromScale(0, 1)
		dashChip.Label.Text = "DASH " .. pips
		dashChip.Label.TextColor3 = C.PAPER
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
	blockChip.Label.TextColor3 = broken and RED or (blockingNow and Color3.fromRGB(190, 225, 255) or C.PAPER)
	blockChip.Tint.BackgroundTransparency = blockingNow and 0.6 or 1
	if blockChip.Edge then
		blockChip.Edge.Color = broken and RED or (blockingNow and BLOCK_BLUE or C.WOOD_EDGE)
	end
	if root and (blockingNow or broken or (meter and meter < max)) then
		guardGui.Adornee = root
		guardGui.Enabled = true
		local k = broken and 0 or math.clamp((meter or max) / max, 0, 1)
		guardFill.Size = UDim2.fromScale(k, 1)
		guardFill.BackgroundColor3 = BLOCK_BLUE:Lerp(RED, 1 - k)
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
