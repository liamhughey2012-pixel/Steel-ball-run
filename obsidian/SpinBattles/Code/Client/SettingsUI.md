---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › UI"
updated: 2026-11-22
---
# SettingsUI

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| **Exact name** | `SettingsUI` (capitals matter) |

**What it does:** The small "VFX: MEDIUM" button (top right) that cycles Low / Medium / High, in the bounty-board style: a little nailed wooden plank with Bangers parchment-coloured text and a lamp that glows red / gold / green for Low / Medium / High. It bounces on hover and press and pops on change. Phones start on Low to keep the frame rate smooth.

## How to add it
1. In Studio's Explorer, find **UI** (StarterPlayer › StarterPlayerScripts › SpinClient › UI).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **SettingsUI**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	SettingsUI  (StarterPlayerScripts.SpinClient.UI.SettingsUI)
	The small "VFX: MEDIUM" button (top right) that cycles Low / Medium / High,
	in the bounty-board style: a little nailed wooden plank with Bangers
	parchment-coloured text and a lamp that glows red / gold / green for
	Low / Medium / High. It bounces on hover and press and pops on change.
	Phones start on Low to keep the frame rate smooth.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local VFXQuality = require(Shared.VFXQuality)
local UITheme = require(script.Parent.UITheme)
local C = UITheme.C

local SettingsUI = {}
local LAMP = { Low = C.RED, Medium = C.GOLD, High = C.GREEN }

function SettingsUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpinSettings"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- VFX quality toggle (top right, small): a wooden plank button.
	local qualityButton = Instance.new("TextButton")
	qualityButton.Name = "VFXQuality"
	qualityButton.AnchorPoint = Vector2.new(1, 0)
	qualityButton.Position = UDim2.new(1, -12, 0, 12)
	qualityButton.Size = UDim2.fromOffset(130, 30)
	qualityButton.AutoButtonColor = false
	qualityButton.Font = UITheme.Font.Title
	qualityButton.TextSize = 15
	-- The planks cover the button's own text, so a label on top shows it;
	-- .Text is still kept up to date.
	qualityButton.TextTransparency = 1
	qualityButton.Parent = gui
	UITheme.wood(qualityButton, { Planks = 1, Border = 3, Radius = 7, Nails = true, Stroke = 2 })
	local edge = qualityButton:FindFirstChildOfClass("UIStroke")

	local lamp = UITheme.new("Frame", {
		Name = "Lamp",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = C.GOLD,
		ZIndex = 3,
	}, qualityButton)
	UITheme.corner(lamp, 99)
	UITheme.stroke(lamp, C.WOOD_EDGE, 2)
	local text = UITheme.label(qualityButton, {
		Name = "Label",
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -34, 1, 0),
		Font = UITheme.Font.Title,
		TextScaled = false,
		TextSize = 17,
		TextColor3 = C.PAPER,
		TextStrokeColor3 = C.SHADOW,
		TextStrokeTransparency = 0.3,
		ZIndex = 3,
	})

	UITheme.hover(qualityButton)
	qualityButton.MouseEnter:Connect(function()
		if edge then
			edge.Color = C.GOLD
		end
	end)
	qualityButton.MouseLeave:Connect(function()
		if edge then
			edge.Color = C.WOOD_EDGE
		end
	end)

	local function refresh()
		local _, name = VFXQuality.get()
		qualityButton.Text = "VFX: " .. string.upper(name)
		text.Text = qualityButton.Text
		lamp.BackgroundColor3 = LAMP[name] or C.GOLD
	end
	refresh()
	qualityButton.Activated:Connect(function()
		VFXQuality.cycle()
	end)
	VFXQuality.Changed:Connect(function(...)
		refresh()
		UITheme.pop(lamp, 0.4)
	end)

	-- Touch devices start on Low to protect frame rate; players can raise it.
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		VFXQuality.set("Low")
	end
end

return SettingsUI
```
