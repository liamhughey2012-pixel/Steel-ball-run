--[[
	SpinMeter  (StarterPlayerScripts.SpinClient.UI.SpinMeter)

	Golden Spin HUD:
	  * charge bar with Power tick, gold PERFECT zone and overcharge zone
	  * live level name ("QUICK SPIN" / "POWER SPIN" / "PERFECT SPIN")
	  * cooldown bar + key hint (R / RT / hidden on touch)
	  * centre-screen popup on release ("PERFECT SPIN!")
	  * VFX quality toggle (top right)
	Built in code so it can be dropped into any place. Later phases will
	merge this into the full ability-slot HUD.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local SpinConfig = require(Shared.SpinConfig)
local VFXQuality = require(Shared.VFXQuality)
local VFXLib = require(script.Parent.Parent.VFXLib)

local SpinMeter = {}

local colors = SpinConfig.Colors
local charge = SpinConfig.Charge
local MAX_T = charge.PerfectWindowStart + charge.PerfectWindowDuration + 0.6
local DARK = Color3.fromRGB(22, 16, 10)
local FONT = Enum.Font.GothamBlack

local gui, chargeFrame, fill, levelLabel, cooldownFill, cooldownLabel, keyHint, popupLabel, popupScale
local cooldownJob, popupJob, chargeFadeJob

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

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = colors.GoldLight
	l.TextStrokeTransparency = 0.4
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function keyText()
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return ""
	end
	if string.find(last.Name, "Gamepad") then
		return "RT"
	end
	return SpinConfig.Input.Keyboard.Name
end

function SpinMeter.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = Instance.new("ScreenGui")
	gui.Name = "SpinHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Bottom-centre panel.
	local panel = Instance.new("Frame")
	panel.Name = "SpinPanel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -24)
	panel.Size = UDim2.fromOffset(320, 58)
	panel.BackgroundTransparency = 1
	panel.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(320, 58)
	sizeLimit.Parent = panel

	-- Charge bar (hidden until charging).
	chargeFrame = Instance.new("Frame")
	chargeFrame.Name = "Charge"
	chargeFrame.Size = UDim2.new(1, 0, 0, 16)
	chargeFrame.BackgroundColor3 = DARK
	chargeFrame.BackgroundTransparency = 0.15
	chargeFrame.Visible = false
	chargeFrame.Parent = panel
	corner(chargeFrame, 8)
	stroke(chargeFrame, colors.Gold, 2)

	local function zone(name, from, to, color, transparency)
		local z = Instance.new("Frame")
		z.Name = name
		z.BorderSizePixel = 0
		z.Position = UDim2.fromScale(from / MAX_T, 0)
		z.Size = UDim2.fromScale((to - from) / MAX_T, 1)
		z.BackgroundColor3 = color
		z.BackgroundTransparency = transparency
		z.ZIndex = 1
		z.Parent = chargeFrame
		return z
	end
	local windowEnd = charge.PerfectWindowStart + charge.PerfectWindowDuration
	zone("PerfectZone", charge.PerfectWindowStart, windowEnd, colors.Perfect, 0.35)
	zone("Overcharge", windowEnd, MAX_T, Color3.fromRGB(120, 30, 20), 0.55)
	zone("PowerTick", SpinConfig.Levels[2].ChargeTime, SpinConfig.Levels[2].ChargeTime + 0.025, colors.GoldLight, 0.2)

	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = colors.Orange
	fill.ZIndex = 2
	fill.Parent = chargeFrame
	corner(fill, 8)

	levelLabel = label(chargeFrame, {
		Name = "Level",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -2),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 18,
		Text = "",
	})

	-- Cooldown row.
	local row = Instance.new("Frame")
	row.Name = "Cooldown"
	row.Position = UDim2.new(0, 0, 1, -22)
	row.Size = UDim2.new(1, 0, 0, 22)
	row.BackgroundColor3 = DARK
	row.BackgroundTransparency = 0.25
	row.Parent = panel
	corner(row, 6)
	stroke(row, colors.BallDark, 1.5)

	cooldownFill = Instance.new("Frame")
	cooldownFill.BorderSizePixel = 0
	cooldownFill.BackgroundColor3 = colors.Gold
	cooldownFill.BackgroundTransparency = 0.6
	cooldownFill.Size = UDim2.fromScale(0, 1)
	cooldownFill.Parent = row
	corner(cooldownFill, 6)

	keyHint = label(row, {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(0, 40, 1, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = keyText(),
	})
	label(row, {
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "GOLDEN SPIN",
	})
	cooldownLabel = label(row, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "READY",
	})

	UserInputService.LastInputTypeChanged:Connect(function()
		keyHint.Text = keyText()
	end)

	-- Centre popup.
	popupLabel = label(gui, {
		Name = "Popup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(500, 70),
		Font = Enum.Font.Bangers,
		TextSize = 56,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",
	})
	popupScale = Instance.new("UIScale")
	popupScale.Parent = popupLabel

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

function SpinMeter.showCharge()
	VFXLib.cancel(chargeFadeJob)
	chargeFrame.Visible = true
	chargeFrame.BackgroundTransparency = 0.15
	fill.Size = UDim2.fromScale(0, 1)
end

function SpinMeter.updateCharge(chargeTime)
	local level, perfect = SpinConfig.getLevel(chargeTime)
	local windowEnd = charge.PerfectWindowStart + charge.PerfectWindowDuration
	local over = chargeTime > windowEnd
	fill.Size = UDim2.fromScale(math.clamp(chargeTime / MAX_T, 0, 1), 1)
	if perfect then
		fill.BackgroundColor3 = colors.Perfect
		levelLabel.Text = "PERFECT SPIN — RELEASE!"
		levelLabel.TextColor3 = colors.Perfect
	elseif over then
		fill.BackgroundColor3 = Color3.fromRGB(170, 80, 40)
		levelLabel.Text = "OVERCHARGED"
		levelLabel.TextColor3 = Color3.fromRGB(230, 120, 90)
	else
		fill.BackgroundColor3 = level == 2 and colors.Gold or colors.Orange
		levelLabel.Text = SpinConfig.Levels[level].Name
		levelLabel.TextColor3 = colors.GoldLight
	end
end

function SpinMeter.hideCharge()
	VFXLib.cancel(chargeFadeJob)
	chargeFadeJob = VFXLib.animate(0.15, function(a)
		chargeFrame.BackgroundTransparency = 0.15 + a * 0.85
	end, function()
		chargeFrame.Visible = false
		levelLabel.Text = ""
	end)
end

function SpinMeter.startCooldown(seconds)
	VFXLib.cancel(cooldownJob)
	if seconds <= 0 then
		cooldownFill.Size = UDim2.fromScale(0, 1)
		cooldownLabel.Text = "READY"
		return
	end
	cooldownJob = VFXLib.animate(seconds, function(a)
		cooldownFill.Size = UDim2.fromScale(1 - a, 1)
		cooldownLabel.Text = string.format("%.1fs", seconds * (1 - a))
	end, function()
		cooldownFill.Size = UDim2.fromScale(0, 1)
		cooldownLabel.Text = "READY"
	end)
end

function SpinMeter.popup(text, color, big)
	VFXLib.cancel(popupJob)
	popupLabel.Text = text
	popupLabel.TextColor3 = color or colors.GoldLight
	local peak = big and 1.25 or 0.9
	popupJob = VFXLib.animate(big and 1.1 or 0.8, function(a)
		if a < 0.12 then
			popupScale.Scale = peak * (1.6 - a / 0.12 * 0.6)
		else
			popupScale.Scale = peak
		end
		local fade = math.clamp((a - 0.65) / 0.35, 0, 1)
		popupLabel.TextTransparency = fade
		popupLabel.TextStrokeTransparency = math.max(fade, 0.2)
	end, function()
		popupLabel.TextTransparency = 1
		popupLabel.TextStrokeTransparency = 1
	end)
end

function SpinMeter.flashDenied(text)
	SpinMeter.popup(text, Color3.fromRGB(230, 120, 90), false)
end

return SpinMeter
