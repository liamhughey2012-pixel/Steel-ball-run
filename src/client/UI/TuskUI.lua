--[[
	TuskUI  (StarterPlayerScripts.SpinClient.UI.TuskUI)
	("TuskUIController" in the design doc)

	JoJo-style Tusk HUD (only visible while Tusk is equipped):
	  * Act name + tagline
	  * three ability slots: key, name, cooldown sweep (tap/click = use; mobile-friendly)
	  * ultimate meter + "READY" prompt (tap/click = use)
	  * sneak chip (tap = toggle) + sneak attack hint
	  * combo counter, transformation banner, Awakened timer, short toasts
	Act menu (T / MOVESET button): one card per Act. Unfinished Acts are shown
	locked as IN DEVELOPMENT, never as working buttons.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.Parent.VFXLib)

local TuskUI = {}

local player = Players.LocalPlayer
local colors = TuskConfig.Colors
local DARK = Color3.fromRGB(12, 16, 28)
local FONT = Enum.Font.GothamBlack
local TITLE_FONT = Enum.Font.Bangers

local callbacks
local gui, hud, actLabel, taglineLabel, ultFill, ultLabel, sneakChip, sneakHint, comboLabel, toastLabel, banner, bannerSub, awakenBar, awakenFill
local slots = {}
local menu
local shownAct
local combo = { Count = 0, Last = 0 }
local jobs = {}

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
end

local function stroke(p, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = colors.Ice
	l.TextStrokeTransparency = 0.5
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function keyName(slotKey)
	local keys = TuskConfig.Keys[slotKey]
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return ""
	end
	if string.find(last.Name, "Gamepad") then
		return keys.Gamepad.Name:gsub("Button", "")
	end
	local k = keys.Keyboard
	local names = { One = "1", Two = "2", Three = "3" }
	return names[k.Name] or k.Name
end

local function animateJob(key, duration, step, done)
	VFXLib.cancel(jobs[key])
	jobs[key] = VFXLib.animate(duration, step, done)
end

function TuskUI.toast(message, color)
	toastLabel.Text = message
	toastLabel.TextColor3 = color or Color3.fromRGB(255, 140, 120)
	animateJob("toast", 1.2, function(a)
		toastLabel.TextTransparency = a < 0.7 and 0 or (a - 0.7) / 0.3
		toastLabel.TextStrokeTransparency = math.max(0.4, toastLabel.TextTransparency)
	end)
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function buildSlot(index, parent)
	local button = Instance.new("TextButton")
	button.Name = "Slot" .. index
	button.Size = UDim2.new(1 / 3, -6, 1, 0)
	button.BackgroundColor3 = DARK
	button.BackgroundTransparency = 0.15
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = parent
	corner(button, 8)
	local edge = stroke(button, colors.Cyan, 2)

	local key = text(button, { Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(30, 16), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = colors.Cyan })
	local name = text(button, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -8, 0, 28), TextSize = 13, TextWrapped = true, Text = "" })
	local overlay = Instance.new("Frame")
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.AnchorPoint = Vector2.new(0, 1)
	overlay.Position = UDim2.fromScale(0, 1)
	overlay.Size = UDim2.fromScale(1, 0)
	overlay.ZIndex = 2
	overlay.Parent = button
	corner(overlay, 8)
	local timer = text(button, { Size = UDim2.fromScale(1, 1), TextSize = 22, Text = "", ZIndex = 3 })

	-- Press / release (works for mouse and touch; hold abilities charge while held).
	button.MouseButton1Down:Connect(function()
		callbacks.Ability(index, true)
	end)
	button.MouseButton1Up:Connect(function()
		callbacks.Ability(index, false)
	end)

	slots[index] = { Button = button, Key = key, Name = name, Overlay = overlay, Timer = timer, Edge = edge }
end

local function buildMenu()
	menu = Instance.new("Frame")
	menu.Name = "ActMenu"
	menu.AnchorPoint = Vector2.new(0.5, 0.5)
	menu.Position = UDim2.fromScale(0.5, 0.5)
	menu.Size = UDim2.new(0.9, 0, 0, 330)
	menu.BackgroundColor3 = DARK
	menu.BackgroundTransparency = 0.05
	menu.Visible = false
	menu.ZIndex = 20
	menu.Parent = gui
	corner(menu, 12)
	stroke(menu, colors.Cyan, 2)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(860, 330)
	limit.Parent = menu

	text(menu, { Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -80, 0, 36), Font = TITLE_FONT, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Left, Text = "TUSK — CHOOSE YOUR ACT", ZIndex = 21 })
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(32, 32)
	close.BackgroundColor3 = Color3.fromRGB(40, 50, 80)
	close.Font = FONT
	close.Text = "X"
	close.TextSize = 16
	close.TextColor3 = colors.Ice
	close.ZIndex = 21
	close.Parent = menu
	corner(close, 6)
	close.Activated:Connect(function()
		menu.Visible = false
	end)

	local row = Instance.new("ScrollingFrame")
	row.Position = UDim2.fromOffset(14, 56)
	row.Size = UDim2.new(1, -28, 1, -70)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.AutomaticCanvasSize = Enum.AutomaticSize.X
	row.CanvasSize = UDim2.new()
	row.ScrollBarThickness = 4
	row.ZIndex = 21
	row.Parent = menu
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.Parent = row

	for act = 1, 4 do
		local info = Registry.get(act)
		local ready = Registry.isImplemented(act)
		local card = Instance.new("Frame")
		card.Size = UDim2.fromOffset(196, 250)
		card.BackgroundColor3 = Color3.fromRGB(20, 28, 48)
		card.BackgroundTransparency = ready and 0 or 0.4
		card.ZIndex = 22
		card.Parent = row
		corner(card, 10)
		stroke(card, ready and info.Theme.Primary or Color3.fromRGB(70, 80, 100), 2)
		text(card, { Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 30), Font = TITLE_FONT, TextSize = 28, TextColor3 = ready and info.Theme.Primary or Color3.fromRGB(130, 140, 160), TextXAlignment = Enum.TextXAlignment.Left, Text = info.Name, ZIndex = 23 })
		text(card, { Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 16), TextSize = 12, TextColor3 = Color3.fromRGB(170, 185, 210), TextXAlignment = Enum.TextXAlignment.Left, Text = info.Tagline, ZIndex = 23 })
		local moves = "M1  " .. info.M1 .. "\n1  " .. info.Abilities[1] .. "\n2  " .. info.Abilities[2] .. "\n3  " .. info.Abilities[3] .. "\nULT  " .. info.Ultimate
		text(card, { Position = UDim2.fromOffset(10, 62), Size = UDim2.new(1, -20, 0, 120), TextSize = 12, TextColor3 = Color3.fromRGB(210, 220, 240), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Text = moves, ZIndex = 23 })
		if ready then
			local pick = Instance.new("TextButton")
			pick.AnchorPoint = Vector2.new(0.5, 1)
			pick.Position = UDim2.new(0.5, 0, 1, -10)
			pick.Size = UDim2.new(1, -20, 0, 36)
			pick.BackgroundColor3 = info.Theme.Secondary
			pick.Font = FONT
			pick.TextSize = 15
			pick.TextColor3 = Color3.new(1, 1, 1)
			pick.Text = "SELECT"
			pick.ZIndex = 23
			pick.Parent = card
			corner(pick, 8)
			pick.Activated:Connect(function()
				callbacks.Select(act)
				menu.Visible = false
			end)
		else
			text(card, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 36), TextSize = 13, TextColor3 = Color3.fromRGB(150, 160, 180), Text = "IN DEVELOPMENT", ZIndex = 23 })
		end
	end
end

function TuskUI.init(cb)
	callbacks = cb
	gui = Instance.new("ScreenGui")
	gui.Name = "TuskHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	hud = Instance.new("Frame")
	hud.Name = "HUD"
	hud.AnchorPoint = Vector2.new(0.5, 1)
	hud.Position = UDim2.new(0.5, 0, 1, -92) -- sits above the Golden Spin panel
	hud.Size = UDim2.new(0.92, 0, 0, 150)
	hud.BackgroundTransparency = 1
	hud.Visible = false
	hud.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 150)
	limit.Parent = hud

	actLabel = text(hud, { Size = UDim2.new(1, 0, 0, 30), Font = TITLE_FONT, TextSize = 30, TextColor3 = colors.Cyan, TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
	taglineLabel = text(hud, { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextColor3 = Color3.fromRGB(170, 200, 230), TextXAlignment = Enum.TextXAlignment.Left, Text = "" })

	local slotRow = Instance.new("Frame")
	slotRow.Position = UDim2.fromOffset(0, 46)
	slotRow.Size = UDim2.new(1, 0, 0, 62)
	slotRow.BackgroundTransparency = 1
	slotRow.Parent = hud
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 9)
	layout.Parent = slotRow
	for i = 1, 3 do
		buildSlot(i, slotRow)
	end

	-- Ultimate bar (also a button).
	local ult = Instance.new("TextButton")
	ult.Name = "Ultimate"
	ult.Position = UDim2.fromOffset(0, 114)
	ult.Size = UDim2.new(1, -96, 0, 26)
	ult.BackgroundColor3 = DARK
	ult.BackgroundTransparency = 0.15
	ult.AutoButtonColor = false
	ult.Text = ""
	ult.Parent = hud
	corner(ult, 8)
	stroke(ult, colors.Blue, 2)
	ultFill = Instance.new("Frame")
	ultFill.BorderSizePixel = 0
	ultFill.BackgroundColor3 = colors.Blue
	ultFill.Size = UDim2.fromScale(0, 1)
	ultFill.Parent = ult
	corner(ultFill, 8)
	ultLabel = text(ult, { Size = UDim2.fromScale(1, 1), TextSize = 13, Text = "", ZIndex = 2 })
	ult.Activated:Connect(function()
		callbacks.Ultimate()
	end)

	-- Sneak chip (also a button).
	sneakChip = Instance.new("TextButton")
	sneakChip.Name = "Sneak"
	sneakChip.AnchorPoint = Vector2.new(1, 0)
	sneakChip.Position = UDim2.new(1, 0, 0, 114)
	sneakChip.Size = UDim2.fromOffset(88, 26)
	sneakChip.BackgroundColor3 = DARK
	sneakChip.BackgroundTransparency = 0.15
	sneakChip.Font = FONT
	sneakChip.TextSize = 13
	sneakChip.TextColor3 = Color3.fromRGB(150, 170, 200)
	sneakChip.Text = "SNEAK"
	sneakChip.Parent = hud
	corner(sneakChip, 8)
	stroke(sneakChip, Color3.fromRGB(60, 80, 120), 2)
	sneakChip.Activated:Connect(function()
		callbacks.Sneak()
	end)
	sneakHint = text(hud, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(200, 18), TextSize = 12, TextColor3 = colors.Cyan, TextXAlignment = Enum.TextXAlignment.Right, Text = "", Visible = false })

	-- Combo counter (right side of the screen).
	comboLabel = text(gui, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.42, 0), Size = UDim2.fromOffset(220, 60), Font = TITLE_FONT, TextSize = 48, TextColor3 = colors.Ice, TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })

	toastLabel = text(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -250), Size = UDim2.fromOffset(400, 26), TextSize = 18, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })

	-- Transformation banner.
	banner = text(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromOffset(700, 80), Font = TITLE_FONT, TextSize = 72, TextColor3 = colors.Cyan, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })
	bannerSub = text(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromOffset(500, 24), TextSize = 16, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })
	bannerSub.Position = UDim2.new(0.5, 0, 0.25, 48)

	awakenBar = Instance.new("Frame")
	awakenBar.AnchorPoint = Vector2.new(0.5, 1)
	awakenBar.Position = UDim2.new(0.5, 0, 1, -248)
	awakenBar.Size = UDim2.fromOffset(240, 6)
	awakenBar.BackgroundColor3 = DARK
	awakenBar.Visible = false
	awakenBar.Parent = gui
	corner(awakenBar, 3)
	awakenFill = Instance.new("Frame")
	awakenFill.BorderSizePixel = 0
	awakenFill.BackgroundColor3 = colors.Cyan
	awakenFill.Size = UDim2.fromScale(1, 1)
	awakenFill.Parent = awakenBar
	corner(awakenFill, 3)

	-- MOVESET button (opens the Act menu), under the VFX quality button.
	if TuskUI.menuAllowed() then
		local moveset = Instance.new("TextButton")
		moveset.AnchorPoint = Vector2.new(1, 0)
		moveset.Position = UDim2.new(1, -12, 0, 46)
		moveset.Size = UDim2.fromOffset(130, 28)
		moveset.BackgroundColor3 = DARK
		moveset.BackgroundTransparency = 0.2
		moveset.Font = FONT
		moveset.TextSize = 13
		moveset.TextColor3 = colors.Ice
		moveset.Text = "TUSK ACTS (T)"
		moveset.Parent = gui
		corner(moveset, 6)
		stroke(moveset, colors.Cyan, 1.5)
		moveset.Activated:Connect(TuskUI.toggleMenu)
		buildMenu()
	end

	-- Combo counter feeds on the attacker-only Damage event.
	Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
		if name ~= "Damage" or not hud.Visible then
			return
		end
		local now = os.clock()
		combo.Count = (now - combo.Last < 1.6) and combo.Count + 1 or 1
		combo.Last = now
		if combo.Count >= 2 then
			comboLabel.Text = combo.Count .. " HITS"
			animateJob("combo", 1.6, function(a)
				comboLabel.TextTransparency = a < 0.75 and 0 or (a - 0.75) / 0.25
				comboLabel.TextStrokeTransparency = math.max(0.3, comboLabel.TextTransparency)
				comboLabel.Rotation = a < 0.08 and (0.08 - a) * 60 or 0
			end)
		end
	end)
end

-- Awaken mode: Acts come from ultimates, so the menu is only a Studio test tool.
function TuskUI.menuAllowed()
	local p = TuskConfig.Progression
	if not p.ShowSelectionMenu then
		return false
	end
	if p.Mode == "Awaken" then
		return RunService:IsStudio() and p.StudioMenu == true
	end
	return true
end

local function showBanner(title, subtitle, color)
	banner.Text = title
	banner.TextColor3 = color or colors.Cyan
	bannerSub.Text = subtitle or ""
	animateJob("banner", 2, function(a)
		local slide = a < 0.12 and (1 - a / 0.12) or 0
		banner.Position = UDim2.new(0.5, slide * 200, 0.25, 0)
		local fade = a < 0.75 and 0 or (a - 0.75) / 0.25
		banner.TextTransparency = fade
		banner.TextStrokeTransparency = math.max(0.2, fade)
		bannerSub.TextTransparency = fade
		bannerSub.TextStrokeTransparency = math.max(0.4, fade)
	end)
end

-- Ultimate awakened Tusk to the next Act.
function TuskUI.onEvolve(data)
	if data.Character ~= player.Character then
		return
	end
	local info = Registry.get(data.To)
	if info then
		showBanner(info.Name .. "!", "AWAKENED  ·  " .. info.Tagline:upper(), info.Theme.Primary)
	end
end

function TuskUI.toggleMenu()
	if menu and TuskUI.menuAllowed() then
		menu.Visible = not menu.Visible
	end
end

---------------------------------------------------------------------------
-- Per-frame refresh and server messages
---------------------------------------------------------------------------
local function refreshAct(act)
	shownAct = act
	hud.Visible = act ~= nil
	if not act then
		return
	end
	local info = Registry.get(act)
	actLabel.Text = info.Name
	actLabel.TextColor3 = info.Theme.Primary
	taglineLabel.Text = info.Tagline:upper()
	for i, slot in ipairs(slots) do
		slot.Name.Text = info.Abilities[i]
		slot.Edge.Color = info.Theme.Primary
	end
end

function TuskUI.step(act)
	if act ~= shownAct then
		refreshAct(act)
	end
	if not act then
		return
	end
	for i, slot in ipairs(slots) do
		slot.Key.Text = keyName("Ability" .. i)
	end
	local max = TuskConfig.Ultimate.MaxMeter
	local meter = player:GetAttribute("TuskUlt") or 0
	local ready = meter >= max
	ultFill.Size = UDim2.fromScale(math.clamp(meter / max, 0, 1), 1)
	local info = Registry.get(act)
	local key = keyName("Ultimate")
	if ready then
		local pulse = (math.sin(os.clock() * 6) + 1) / 2
		ultFill.BackgroundColor3 = colors.Blue:Lerp(colors.Cyan, pulse)
		ultLabel.Text = (key ~= "" and ("[" .. key .. "] ") or "") .. info.Ultimate .. " READY"
	else
		ultFill.BackgroundColor3 = colors.Blue
		ultLabel.Text = info.Ultimate .. "  " .. math.floor(meter / max * 100) .. "%"
	end
	local character = player.Character
	local sneaking = character and character:GetAttribute("TuskSneaking") == true
	sneakChip.TextColor3 = sneaking and DARK or Color3.fromRGB(150, 170, 200)
	sneakChip.BackgroundColor3 = sneaking and colors.Cyan or DARK
	sneakHint.Visible = sneaking
	sneakHint.Text = "M1 / TAP: SNEAK ATTACK"
end

local function cooldown(slot, duration)
	local s = slots[slot]
	if not s then
		return
	end
	animateJob("slot" .. slot, duration, function(a)
		s.Overlay.Size = UDim2.fromScale(1, 1 - a)
		s.Timer.Text = string.format("%.1f", duration * (1 - a))
	end, function()
		s.Overlay.Size = UDim2.fromScale(1, 0)
		s.Timer.Text = ""
		-- Ready flash.
		VFXLib.animate(0.25, function(a)
			s.Button.BackgroundColor3 = colors.Cyan:Lerp(DARK, a)
		end)
	end)
end

local DENY_TEXT = {
	Cooldown = "ON COOLDOWN",
	UltNotReady = "ULTIMATE NOT READY",
	NotAvailable = "THAT ACT IS IN DEVELOPMENT",
	Locked = "ACT LOCKED",
	SwitchCooldown = "WAIT BEFORE SWITCHING ACTS",
	SneakCooldown = "SNEAK ON COOLDOWN",
	SneakAttackCooldown = "SNEAK ATTACK ON COOLDOWN",
	NoTarget = "NO TARGET IN FRONT",
	Blocked = "NO ROOM TO MOVE THERE",
}

function TuskUI.onState(data)
	local kind = data.Kind
	if kind == "Cooldown" then
		cooldown(data.Slot, data.Duration)
	elseif kind == "Denied" then
		local msg = DENY_TEXT[data.Reason] or "CAN'T DO THAT"
		if data.Remaining then
			msg = msg .. string.format("  %.1fs", data.Remaining)
		end
		TuskUI.toast(msg)
	elseif kind == "Interrupted" then
		TuskUI.toast("INTERRUPTED!")
	elseif kind == "SneakAttackCooldown" then
		sneakChip.Text = "SNEAK"
	elseif kind == "Awakened" then
		local info = shownAct and Registry.get(shownAct)
		banner.Text = info and info.Ultimate or "AWAKENED"
		bannerSub.Text = "ABILITIES EMPOWERED"
		animateJob("banner", 1.8, function(a)
			local slide = a < 0.12 and (1 - a / 0.12) or 0
			banner.Position = UDim2.new(0.5, slide * 200, 0.25, 0)
			local fade = a < 0.75 and 0 or (a - 0.75) / 0.25
			banner.TextTransparency = fade
			banner.TextStrokeTransparency = math.max(0.2, fade)
			bannerSub.TextTransparency = fade
			bannerSub.TextStrokeTransparency = math.max(0.4, fade)
		end)
		awakenBar.Visible = true
		animateJob("awaken", data.Duration, function(a)
			awakenFill.Size = UDim2.fromScale(1 - a, 1)
		end, function()
			awakenBar.Visible = false
		end)
	elseif kind == "AwakenEnded" then
		VFXLib.cancel(jobs.awaken)
		awakenBar.Visible = false
	elseif kind == "Equipped" then
		if data.Act and data.Act > 0 then
			TuskUI.toast(Registry.get(data.Act).Name .. " EQUIPPED", colors.Cyan)
		end
	end
end

return TuskUI
