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

**What it does:** The small "VFX: MEDIUM" button (top right) that cycles Low / Medium / High. Phones start on Low to keep the frame rate smooth.

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
	The small "VFX: MEDIUM" button (top right) that cycles Low / Medium / High.
	Phones start on Low to keep the frame rate smooth.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local VFXQuality = require(Shared.VFXQuality)

local SettingsUI = {}
local DARK = Color3.fromRGB(22, 16, 10)
local FONT = Enum.Font.GothamBlack
local colors = { GoldLight = Color3.fromRGB(255, 238, 160), Gold = Color3.fromRGB(255, 196, 56) }

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function SettingsUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpinSettings"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- VFX quality toggle (top right, small).
	local qualityButton = Instance.new("TextButton")
	qualityButton.Name = "VFXQuality"
	qualityButton.AnchorPoint = Vector2.new(1, 0)
	qualityButton.Position = UDim2.new(1, -12, 0, 12)
	qualityButton.Size = UDim2.fromOffset(130, 28)
	qualityButton.BackgroundColor3 = DARK
	qualityButton.BackgroundTransparency = 0.2
	qualityButton.Font = FONT
	qualityButton.TextSize = 13
	qualityButton.TextColor3 = colors.GoldLight
	qualityButton.Parent = gui
	corner(qualityButton, 6)
	stroke(qualityButton, colors.Gold, 1.5)
	local function refresh()
		local _, name = VFXQuality.get()
		qualityButton.Text = "VFX: " .. string.upper(name)
	end
	refresh()
	qualityButton.Activated:Connect(function()
		VFXQuality.cycle()
	end)
	VFXQuality.Changed:Connect(refresh)

	-- Touch devices start on Low to protect frame rate; players can raise it.
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		VFXQuality.set("Low")
	end
end

return SettingsUI
```
