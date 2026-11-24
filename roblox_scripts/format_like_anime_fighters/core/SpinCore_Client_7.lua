--[[
	SpinCore_Client_7  (ModuleScript)  -- part 7 of 8
	PUT IT IN: ReplicatedStorage > SpinCore   (make a Folder named SpinCore there if it doesn't exist)

	Part of the Spin Battlegrounds client core, split up so pasting is quick.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: TuskUI
-- ======================================================================
__modules["TuskUI"] = function()
--[[
	TuskUI  (StarterPlayerScripts.SpinClient.UI.TuskUI)

	Battlegrounds-style move HUD (shown while Johnny or Gyro is equipped):
	  * header: Act / character name with a slanted colour band + tagline
	  * hotbar of move cards: M1, 1, 2, 3 and a big ULT card
	      - key badge, a drawn icon for each move, the move name
	      - cooldown shade that drains with a countdown, greys the icon,
	        then a white "ready" flash and pop
	      - cards squash when pressed (mouse, touch or keyboard)
	      - hold moves show a charge bar (FULL when fully charged)
	  * ULT card: rising meter, %, READY glow with a spinning shine,
	    LOCKED timer after an awakening
	  * sneak chip (Johnny), combo counter, toasts, awakening banner with
	    menacing "ゴ" letters, Awakened timer bar
	  * scales down on small screens
	Act menu (T / MOVESET button): Studio test tool, one card per Act.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local Net = __require("Net")
local VFXLib = __require("VFXLib")

local TuskUI = {}

local player = Players.LocalPlayer
local colors = TuskConfig.Colors
local DARK = Color3.fromRGB(12, 16, 28)
local DARK2 = Color3.fromRGB(26, 34, 56)
local GREY = Color3.fromRGB(110, 118, 135)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.GothamBlack
local TITLE_FONT = Enum.Font.Bangers

local CARD_W, CARD_H, M1_W, ULT_W, GAP = 84, 96, 66, 112, 8

local callbacks
local gui, hud, hudScale, header, actLabel, actGradient, actBand, taglineLabel
local sneakChip, sneakHint, comboFrame, comboNumber, comboWord, comboDrain
local toastFrame, toastLabel, toastAccent
local bannerBand, banner, bannerSub, bannerGradient, menacing = nil, nil, nil, nil, {}
local awakenBar, awakenFill
local slots = {} -- [1..3] abilities, slots.M1, slots.Ult
local menu
local shownAct
local theme = { Primary = colors.Cyan, Secondary = colors.Blue }
local combo = { Count = 0, Last = 0 }
local jobs = {}
local ultShown = 0
local wasReady = false

---------------------------------------------------------------------------
-- Small builders
---------------------------------------------------------------------------
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
	return c
end

local function stroke(p, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

local function gradient(p, c0, c1, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rotation or 90
	g.Parent = p
	return g
end

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = parent
	return f
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
	if not keys then
		return ""
	end
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return ""
	end
	if string.find(last.Name, "Gamepad") then
		return keys.Gamepad.Name:gsub("Button", "")
	end
	local k = keys.Keyboard
	local names = { One = "1", Two = "2", Three = "3", MouseButton1 = "LMB" }
	return names[k.Name] or k.Name
end

local function animateJob(key, duration, step, done)
	VFXLib.cancel(jobs[key])
	jobs[key] = VFXLib.animate(duration, step, done)
end

---------------------------------------------------------------------------
-- Move icons, drawn from UI shapes so no image uploads are needed
---------------------------------------------------------------------------
local function iconKind(name)
	name = name or ""
	local function has(word)
		return string.find(name, word, 1, true) ~= nil
	end
	if has("KNIFE") then
		return "knife"
	elseif has("TIME STOP") then
		return "clock"
	elseif has("STAND GRAB") then
		return "grab"
	elseif has("DIMENSION HOP") then
		return "flag"
	elseif has("PARALLEL VALENTINE") then
		return "ghost"
	elseif has("MENGER SPONGE") then
		return "cube"
	elseif has("LOVE TRAIN") then
		return "star"
	elseif has("GUILT SPECTER") then
		return "ghost"
	elseif has("ABANDONED JUNK") then
		return "junk"
	elseif has("GUILT MEMBRANE") or has("CIVIL WAR") then
		return "seal"
	elseif has("RAINDROP BLADES") or has("RAINBOW") then
		return "rain"
	elseif has("RAINDROP STEP") then
		return "dash"
	elseif has("RAINDROP CAGE") then
		return "portal"
	elseif has("FLESH SPRAY") or has("FLESH STORM") then
		return "spray"
	elseif has("FLESH SEAL") then
		return "seal"
	elseif has("FLESH MEND") then
		return "heal"
	elseif has("LASSO") or has("ROUNDUP") then
		return "lasso"
	elseif has("SPLIT DODGE") then
		return "dash"
	elseif has("SPLIT BARRAGE") then
		return "barrage"
	elseif has("SOUND TRAP") then
		return "word"
	elseif has("SOUND") or has("SILENT") then
		return "slash"
	elseif has("SAND RUN") then
		return "dash"
	elseif has("BAIT") then
		return "bait"
	elseif has("HOOK") or has("WIRED") then
		return "hook"
	elseif has("SCARY MONSTERS") then
		return "dino"
	elseif has("INFECTION") or has("BITE") then
		return "fang"
	elseif has("POUNCE") then
		return "dash"
	elseif has("GOLDEN RATIO") or has("GOLDEN SPIRAL") or has("GOLDEN COMBO") then
		return "golden"
	elseif has("BARRAGE") then
		return "barrage"
	elseif has("TORNADO") then
		return "tornado"
	elseif has("VIBRATION") then
		return "vibration"
	elseif has("BALL") then
		return "ball"
	elseif has("PURSUIT") or has("STEP") or has("DIVE") then
		return "dash"
	elseif has("BREAK") then
		return "star"
	elseif has("WORMHOLE") or has("DIMENSION") then
		return "portal"
	elseif has("SPINNING") or has("ROTATION") or has("GOLDEN") then
		return "spin"
	elseif has("NAIL") then
		return "nail"
	end
	return "spin"
end

-- Every icon part is tagged so recolouring (cooldown grey / theme) is one loop.
local function iconPart(icon, props, isStroke)
	local f = frame(icon, props)
	f:SetAttribute("IconFill", not isStroke)
	return f
end

local function ring(icon, size, thickness, pos)
	local f = frame(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos or UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(size, size), BackgroundTransparency = 1 })
	corner(f, 999)
	local s = stroke(f, WHITE, thickness)
	s:SetAttribute("IconStroke", true)
	return f
end

local function bar(icon, x, y, w, h, rot)
	local f = iconPart(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), Rotation = rot or 0, BackgroundColor3 = WHITE })
	corner(f, 3)
	return f
end

local function drawIcon(icon, kind)
	for _, c in ipairs(icon:GetChildren()) do
		c:Destroy()
	end
	if kind == "nail" then
		bar(icon, 0.45, 0.55, 0.12, 0.62, 45)
		bar(icon, 0.68, 0.32, 0.2, 0.2, 45)
	elseif kind == "barrage" then
		for i = -1, 1 do
			bar(icon, 0.5 + i * 0.2, 0.5 - i * 0.08, 0.09, 0.55, 35)
		end
	elseif kind == "spin" then
		ring(icon, 0.8, 3)
		ring(icon, 0.45, 2)
		bar(icon, 0.5, 0.5, 0.16, 0.16, 45)
	elseif kind == "portal" then
		ring(icon, 0.85, 3)
		ring(icon, 0.6, 2)
		ring(icon, 0.35, 2)
	elseif kind == "dash" then
		for i = 0, 2 do
			bar(icon, 0.28 + i * 0.22, 0.38, 0.08, 0.32, -40)
			bar(icon, 0.28 + i * 0.22, 0.62, 0.08, 0.32, 40)
		end
	elseif kind == "ball" then
		local b = bar(icon, 0.5, 0.5, 0.62, 0.62)
		corner(b, 999)
		ring(icon, 0.84, 2)
		frame(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.06), BackgroundColor3 = DARK, Rotation = -25 })
	elseif kind == "tornado" then
		for i = 0, 3 do
			bar(icon, 0.5 + (i % 2 == 0 and 0.04 or -0.04), 0.2 + i * 0.2, 0.85 - i * 0.18, 0.1, 0)
		end
	elseif kind == "vibration" then
		local b = bar(icon, 0.5, 0.5, 0.36, 0.36)
		corner(b, 999)
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 2 do
				bar(icon, 0.5 + side * (0.3 + i * 0.07), 0.5 + (i % 2 == 0 and -0.07 or 0.07), 0.05, 0.22, side * 25 * (i % 2 == 0 and 1 or -1))
			end
		end
	elseif kind == "star" then
		for i = 0, 3 do
			bar(icon, 0.5, 0.5, 0.08, i % 2 == 0 and 0.95 or 0.7, i * 45)
		end
		local c = bar(icon, 0.5, 0.5, 0.3, 0.3, 45)
		corner(c, 999)
	elseif kind == "golden" then
		-- Golden rectangle: a 1.618 box split into a square, with a spiral dot.
		local outer = frame(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.95, 0.59), BackgroundTransparency = 1 })
		local s1 = stroke(outer, WHITE, 2)
		s1:SetAttribute("IconStroke", true)
		bar(icon, 0.665, 0.5, 0.04, 0.59, 0)
		bar(icon, 0.84, 0.39, 0.33, 0.04, 0)
		ring(icon, 0.55, 2, UDim2.fromScale(0.36, 0.5))
		local dot = bar(icon, 0.77, 0.6, 0.12, 0.12)
		corner(dot, 999)
	elseif kind == "fang" then
		-- Two rows of fangs.
		for i = -1, 1 do
			bar(icon, 0.5 + i * 0.22, 0.34, 0.14, 0.34, 0)
			bar(icon, 0.5 + i * 0.22 + 0.11, 0.68, 0.12, 0.28, 0)
		end
		bar(icon, 0.5, 0.16, 0.8, 0.08, 0)
		bar(icon, 0.5, 0.86, 0.8, 0.08, 0)
	elseif kind == "dino" then
		-- Raptor head: skull, long snout, open jaw, crown pins.
		local skull = bar(icon, 0.34, 0.42, 0.38, 0.34)
		corner(skull, 999)
		bar(icon, 0.64, 0.4, 0.5, 0.16, -6)
		bar(icon, 0.6, 0.62, 0.44, 0.1, 18)
		for i = 0, 2 do
			bar(icon, 0.2 + i * 0.1, 0.16 - (i == 1 and 0.04 or 0), 0.05, 0.2, -30 + i * 30)
		end
		frame(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.42, 0.36), Size = UDim2.fromScale(0.08, 0.08), BackgroundColor3 = DARK, Rotation = 45 })
	elseif kind == "hook" then
		-- Fish hook on a cable: shank, J bend, barbed point.
		bar(icon, 0.5, 0.08, 0.05, 0.16, 0) -- cable
		ring(icon, 0.16, 2, UDim2.fromScale(0.5, 0.2))
		bar(icon, 0.5, 0.48, 0.09, 0.5, 0)
		bar(icon, 0.38, 0.75, 0.3, 0.09, 0)
		bar(icon, 0.26, 0.64, 0.09, 0.26, 0)
		bar(icon, 0.3, 0.55, 0.07, 0.14, -40) -- barb
	elseif kind == "bait" then
		-- Pan of water with a feather above it.
		bar(icon, 0.45, 0.78, 0.7, 0.14, 0)
		bar(icon, 0.88, 0.72, 0.26, 0.07, -15)
		bar(icon, 0.45, 0.68, 0.58, 0.06, 0)
		bar(icon, 0.45, 0.32, 0.12, 0.4, 25)
		bar(icon, 0.52, 0.28, 0.07, 0.3, 25)
	elseif kind == "flag" then
		-- A flag on a pole: stripes and a canton.
		bar(icon, 0.28, 0.5, 0.06, 0.6, 0)
		for i = 0, 2 do
			bar(icon, 0.56, 0.3 + i * 0.1, 0.5, 0.05, 0)
		end
		bar(icon, 0.42, 0.3, 0.18, 0.16, 0)
	elseif kind == "cube" then
		-- A Menger-sponge face: a ring of eight squares.
		for i = -1, 1 do
			for j = -1, 1 do
				if not (i == 0 and j == 0) then
					bar(icon, 0.5 + i * 0.18, 0.5 + j * 0.18, 0.14, 0.14, 0)
				end
			end
		end
	elseif kind == "ghost" then
		-- A ghost: round head, a body that trails off.
		local head = bar(icon, 0.5, 0.36, 0.34, 0.3, 0)
		corner(head, 999)
		bar(icon, 0.5, 0.58, 0.34, 0.24, 0)
		bar(icon, 0.42, 0.74, 0.1, 0.1, 0)
		bar(icon, 0.58, 0.74, 0.1, 0.1, 0)
	elseif kind == "junk" then
		-- A tumbling crate and a wheel.
		bar(icon, 0.38, 0.6, 0.3, 0.3, 20)
		local wheel = bar(icon, 0.64, 0.4, 0.26, 0.26, 0)
		corner(wheel, 999)
	elseif kind == "rain" then
		-- Three falling drops.
		for i = -1, 1 do
			local d = bar(icon, 0.5 + i * 0.25, 0.42 + (i % 2) * 0.18, 0.12, 0.3, 0)
			corner(d, 999)
		end
	elseif kind == "spray" then
		-- Spray can with a mist puff.
		bar(icon, 0.32, 0.6, 0.26, 0.5, 0)
		bar(icon, 0.32, 0.3, 0.14, 0.1, 0)
		for i = 0, 2 do
			local dot = bar(icon, 0.6 + i * 0.12, 0.3 + (i - 1) * 0.1, 0.1, 0.1)
			corner(dot, 999)
		end
	elseif kind == "seal" then
		-- A face with its mouth covered.
		ring(icon, 0.72, 3)
		bar(icon, 0.38, 0.4, 0.08, 0.08)
		bar(icon, 0.62, 0.4, 0.08, 0.08)
		bar(icon, 0.5, 0.64, 0.46, 0.16, 0)
	elseif kind == "heal" then
		-- A plus.
		bar(icon, 0.5, 0.5, 0.2, 0.7, 0)
		bar(icon, 0.5, 0.5, 0.7, 0.2, 0)
	elseif kind == "lasso" then
		-- A lasso loop on a rope.
		ring(icon, 0.56, 3, UDim2.fromScale(0.42, 0.4))
		bar(icon, 0.68, 0.72, 0.07, 0.42, -40)
		bar(icon, 0.6, 0.62, 0.12, 0.12, 45)
	elseif kind == "word" then
		-- A written sound effect: three bold blocks with a burst behind.
		for i = 0, 3 do
			bar(icon, 0.5, 0.5, 0.06, 0.95, i * 45)
		end
		for i = -1, 1 do
			bar(icon, 0.5 + i * 0.24, 0.5 + (i == 0 and -0.04 or 0.04), 0.18, 0.34, i * 8)
		end
	elseif kind == "knife" then
		-- Three knives fanned out: blades and handles.
		for i = -1, 1 do
			bar(icon, 0.5 + i * 0.2, 0.38, 0.08, 0.46, i * 18)
			bar(icon, 0.5 + i * 0.28, 0.72, 0.1, 0.22, i * 18)
			bar(icon, 0.5 + i * 0.25, 0.62, 0.2, 0.05, i * 18)
		end
	elseif kind == "clock" then
		-- A clock face with its hands stopped.
		ring(icon, 0.82, 3)
		bar(icon, 0.5, 0.36, 0.08, 0.3, 0)
		bar(icon, 0.6, 0.5, 0.24, 0.08, 0)
		for i = 0, 3 do
			local a = i * math.pi / 2
			bar(icon, 0.5 + math.sin(a) * 0.32, 0.5 - math.cos(a) * 0.32, 0.06, 0.06, 0)
		end
	elseif kind == "grab" then
		-- An open hand reaching: palm and four fingers, a thumb.
		bar(icon, 0.5, 0.62, 0.42, 0.3, 0)
		for i = 0, 3 do
			bar(icon, 0.34 + i * 0.11, 0.33, 0.08, 0.3, 0)
		end
		bar(icon, 0.22, 0.55, 0.08, 0.26, -40)
	elseif kind == "slash" then
		for i = -1, 1 do
			bar(icon, 0.5 + i * 0.18, 0.5, 0.08, 0.8 - math.abs(i) * 0.2, 30)
		end
	end
end

local function colorIcon(icon, color)
	for _, c in ipairs(icon:GetDescendants()) do
		if c:IsA("Frame") and c:GetAttribute("IconFill") then
			c.BackgroundColor3 = color
		elseif c:IsA("UIStroke") and c:GetAttribute("IconStroke") then
			c.Color = color
		end
	end
end

---------------------------------------------------------------------------
-- Move cards
---------------------------------------------------------------------------
local function buildCard(parent, id, width, order)
	local button = Instance.new("TextButton")
	button.Name = "Move_" .. tostring(id)
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(width, CARD_H)
	button.BackgroundColor3 = DARK
	button.BackgroundTransparency = 0.08
	button.AutoButtonColor = false
	button.Text = ""
	button.ClipsDescendants = false
	button.Parent = parent
	corner(button, 10)
	gradient(button, Color3.fromRGB(200, 210, 230), Color3.fromRGB(120, 130, 150), 90)
	local edge = stroke(button, WHITE, 2)
	local edgeGradient = gradient(edge, theme.Primary, theme.Secondary, 45)
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	-- Glow behind the card (shown when an ability is ready / ultimate is ready).
	local glow = frame(button, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 8, 1, 8), BackgroundTransparency = 1, ZIndex = 0 })
	corner(glow, 13)
	local glowStroke = stroke(glow, theme.Primary, 4)
	glowStroke.Transparency = 1
	local accent = frame(button, { Size = UDim2.new(1, -16, 0, 3), Position = UDim2.fromOffset(8, 0), BackgroundColor3 = theme.Primary, ZIndex = 2 })
	corner(accent, 2)

	local badge = frame(button, { Position = UDim2.fromOffset(5, 6), Size = UDim2.fromOffset(26, 18), BackgroundColor3 = theme.Primary, ZIndex = 4 })
	corner(badge, 5)
	local key = text(badge, { Size = UDim2.fromScale(1, 1), TextSize = 12, TextColor3 = DARK, TextStrokeTransparency = 1, Text = "", ZIndex = 5 })

	local icon = frame(button, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, ZIndex = 3 })
	local name = text(button, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -8, 0, 26), TextScaled = true, TextWrapped = true, Text = "", ZIndex = 3 })
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = 12
	nameLimit.Parent = name

	-- Cooldown shade: drains from the top down; countdown in the middle.
	local shade = frame(button, { Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, ZIndex = 6 })
	corner(shade, 10)
	local shadeEdge = frame(shade, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = theme.Primary, ZIndex = 7 })
	local timer = text(button, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 22), TextSize = 26, TextStrokeTransparency = 0.2, Text = "", ZIndex = 8 })
	local flash = frame(button, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 9 })
	corner(flash, 10)

	-- Charge bar above the card (hold moves).
	local chargeBack = frame(button, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.new(1, -6, 0, 7), BackgroundColor3 = DARK, Visible = false, ZIndex = 4 })
	corner(chargeBack, 4)
	stroke(chargeBack, WHITE, 1)
	local chargeFill = frame(chargeBack, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = theme.Primary, ZIndex = 5 })
	corner(chargeFill, 4)
	local chargeText = text(chargeBack, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -1), Size = UDim2.fromOffset(60, 14), TextSize = 11, Text = "", ZIndex = 5 })

	local card = {
		Button = button, Scale = scale, Edge = edge, EdgeGradient = edgeGradient, Glow = glow, GlowStroke = glowStroke, Accent = accent,
		Badge = badge, Key = key, Icon = icon, Name = name, Shade = shade, ShadeEdge = shadeEdge, Timer = timer,
		Flash = flash, ChargeBack = chargeBack, ChargeFill = chargeFill, ChargeText = chargeText,
		CooldownEnd = 0, CooldownDur = 0, Pressed = false, Pop = 0,
	}
	button.MouseButton1Down:Connect(function()
		card.Pressed = true
	end)
	button.MouseButton1Up:Connect(function()
		card.Pressed = false
	end)
	button.MouseLeave:Connect(function()
		card.Pressed = false
	end)
	button.MouseEnter:Connect(function()
		card.Hover = true
	end)
	button.MouseLeave:Connect(function()
		card.Hover = false
	end)
	return card
end

local function readyFlash(card)
	animateJob("flash" .. card.Button.Name, 0.35, function(a)
		card.Flash.BackgroundTransparency = 0.25 + a * 0.75
		card.Pop = (1 - a) * 0.12
	end, function()
		card.Pop = 0
	end)
end

---------------------------------------------------------------------------
-- Toasts, banner, combo
---------------------------------------------------------------------------
function TuskUI.toast(message, color)
	if not toastFrame then
		return
	end
	color = color or Color3.fromRGB(255, 110, 100)
	toastLabel.Text = message
	toastAccent.BackgroundColor3 = color
	toastLabel.TextColor3 = color:Lerp(WHITE, 0.45)
	toastFrame.Size = UDim2.fromOffset(math.clamp(#message * 9 + 46, 160, 460), 32)
	toastFrame.Visible = true
	animateJob("toast", 1.4, function(a)
		local slide = a < 0.12 and (1 - a / 0.12) or 0
		local fade = a < 0.75 and 0 or (a - 0.75) / 0.25
		toastFrame.Position = UDim2.new(0.5, 0, 1, -20 + slide * 14)
		toastFrame.BackgroundTransparency = 0.15 + fade * 0.85
		toastAccent.BackgroundTransparency = fade
		toastLabel.TextTransparency = fade
		toastLabel.TextStrokeTransparency = math.max(0.5, fade)
	end, function()
		toastFrame.Visible = false
	end)
end

local function showBanner(title, subtitle, color, duration)
	color = color or theme.Primary
	duration = duration or 2.2
	banner.Text = title
	bannerSub.Text = subtitle or ""
	bannerGradient.Color = ColorSequence.new(WHITE, color)
	bannerBand.BackgroundColor3 = Color3.new(0, 0, 0)
	for i, m in ipairs(menacing) do
		m.TextColor3 = Color3.fromRGB(190, 120, 255):Lerp(color, 0.3)
		m:SetAttribute("Seed", math.random() * 10 + i)
	end
	animateJob("banner", duration, function(a)
		local slideIn = a < 0.1 and (1 - VFXLib.easeOut(a / 0.1)) or 0
		local fade = a < 0.78 and 0 or (a - 0.78) / 0.22
		bannerBand.Position = UDim2.new(0.5 - slideIn * 1.2, 0, 0.26, 0)
		bannerBand.BackgroundTransparency = 0.35 + fade * 0.65
		banner.Position = UDim2.new(0.5 + slideIn * 0.8, 0, 0.26, -8)
		banner.TextTransparency = fade
		banner.TextStrokeTransparency = math.max(0.1, fade)
		banner.Rotation = -4 + (a < 0.14 and math.sin(a * 120) * 2 * (1 - a / 0.14) or 0)
		bannerSub.TextTransparency = fade
		bannerSub.TextStrokeTransparency = math.max(0.4, fade)
		for i, m in ipairs(menacing) do
			local seed = m:GetAttribute("Seed") or i
			local appear = math.clamp((a - 0.05 * i) / 0.1, 0, 1)
			m.TextTransparency = math.max(1 - appear, fade)
			m.Position = UDim2.new(m:GetAttribute("X") or 0.5, math.sin(os.clock() * 25 + seed) * 2, 0.26, (m:GetAttribute("Y") or 0) - a * 30)
		end
	end, function()
		bannerBand.BackgroundTransparency = 1
		for _, m in ipairs(menacing) do
			m.TextTransparency = 1
		end
	end)
end

local function bumpCombo()
	local now = os.clock()
	combo.Count = (now - combo.Last < 1.6) and combo.Count + 1 or 1
	combo.Last = now
	if combo.Count < 2 then
		return
	end
	comboNumber.Text = tostring(combo.Count)
	local col = combo.Count >= 15 and colors.Gold or (combo.Count >= 8 and theme.Primary or colors.Ice)
	comboNumber.TextColor3 = col
	comboDrain.BackgroundColor3 = col
	comboFrame.Visible = true
	animateJob("combo", 1.6, function(a)
		local pop = a < 0.1 and (1 - a / 0.1) * 0.5 or 0
		comboNumber.TextSize = 58 * (1 + pop)
		comboNumber.Rotation = a < 0.1 and (0.1 - a) * 80 or 0
		local fade = a < 0.8 and 0 or (a - 0.8) / 0.2
		comboNumber.TextTransparency = fade
		comboNumber.TextStrokeTransparency = math.max(0.15, fade)
		comboWord.TextTransparency = fade
		comboDrain.Size = UDim2.new(1 - a, 0, 0, 4)
		comboDrain.BackgroundTransparency = fade
	end, function()
		comboFrame.Visible = false
	end)
end

---------------------------------------------------------------------------
-- Act menu (Studio test tool)
---------------------------------------------------------------------------
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


---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
function TuskUI.init(cb)
	callbacks = cb
	gui = Instance.new("ScreenGui")
	gui.Name = "TuskHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local width = M1_W + CARD_W * 3 + ULT_W + GAP * 4
	hud = frame(gui, { Name = "HUD", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(width, 156), BackgroundTransparency = 1, Visible = false })
	hudScale = Instance.new("UIScale")
	hudScale.Parent = hud

	-- Header: slanted colour band + name + tagline.
	header = frame(hud, { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	actBand = frame(header, { Position = UDim2.fromOffset(-6, 6), Size = UDim2.fromOffset(230, 30), BackgroundColor3 = theme.Primary, Rotation = -3, ZIndex = 1 })
	corner(actBand, 4)
	local bandGradient = Instance.new("UIGradient")
	bandGradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1) })
	bandGradient.Parent = actBand
	actLabel = text(header, { Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(320, 34), Font = TITLE_FONT, TextSize = 34, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = DARK, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 2 })
	actGradient = gradient(actLabel, WHITE, theme.Primary, 90)
	taglineLabel = text(header, { Position = UDim2.fromOffset(8, 32), Size = UDim2.fromOffset(320, 12), TextSize = 11, TextColor3 = Color3.fromRGB(190, 210, 235), TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 2 })

	-- Sneak chip (every character), right side of the header.
	sneakChip = Instance.new("TextButton")
	sneakChip.Name = "Sneak"
	sneakChip.AnchorPoint = Vector2.new(1, 0)
	sneakChip.Position = UDim2.new(1, 0, 0, 8)
	sneakChip.Size = UDim2.fromOffset(104, 26)
	sneakChip.BackgroundColor3 = DARK
	sneakChip.BackgroundTransparency = 0.1
	sneakChip.AutoButtonColor = false
	sneakChip.Text = ""
	sneakChip.Parent = header
	corner(sneakChip, 13)
	local sneakStroke = stroke(sneakChip, Color3.fromRGB(60, 80, 120), 2)
	local sneakKey = frame(sneakChip, { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(20, 18), BackgroundColor3 = Color3.fromRGB(60, 80, 120) })
	corner(sneakKey, 9)
	local sneakKeyText = text(sneakKey, { Size = UDim2.fromScale(1, 1), TextSize = 11, TextColor3 = WHITE, TextStrokeTransparency = 1, Text = "C" })
	local sneakText = text(sneakChip, { Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -32, 1, 0), TextSize = 13, TextColor3 = Color3.fromRGB(150, 170, 200), Text = "SNEAK" })
	sneakChip:SetAttribute("Built", true)
	sneakChip.Activated:Connect(function()
		callbacks.Sneak()
	end)
	slots.SneakParts = { Stroke = sneakStroke, Key = sneakKey, KeyText = sneakKeyText, Text = sneakText }
	sneakHint = text(hud, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 0, -2), Size = UDim2.fromOffset(240, 16), TextSize = 12, TextColor3 = colors.Cyan, TextXAlignment = Enum.TextXAlignment.Right, Text = "", Visible = false })

	-- Hotbar.
	local row = frame(hud, { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, CARD_H), BackgroundTransparency = 1 })
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = row
	slots.M1 = buildCard(row, "M1", M1_W, 0)
	drawIcon(slots.M1.Icon, "slash")
	for i = 1, 3 do
		local card = buildCard(row, i, CARD_W, i)
		card.Slot = i
		card.Button.MouseButton1Down:Connect(function()
			callbacks.Ability(i, true)
		end)
		card.Button.MouseButton1Up:Connect(function()
			callbacks.Ability(i, false)
		end)
		slots[i] = card
	end
	local ult = buildCard(row, "Ult", ULT_W, 4)
	slots.Ult = ult
	-- Ultimate meter rises from the bottom of the card.
	ult.Meter = frame(ult.Button, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.35, ZIndex = 1 })
	corner(ult.Meter, 10)
	ult.MeterGradient = gradient(ult.Meter, theme.Primary, theme.Secondary, 90)
	ult.Percent = text(ult.Button, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(50, 16), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Text = "0%", ZIndex = 4 })
	ult.Icon.Size = UDim2.fromOffset(46, 46)
	drawIcon(ult.Icon, "star")
	ult.Button.Activated:Connect(function()
		callbacks.Ultimate()
	end)

	-- Awakened timer bar under the hotbar.
	awakenBar = frame(hud, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52 + CARD_H + 6), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = DARK, Visible = false })
	corner(awakenBar, 3)
	awakenFill = frame(awakenBar, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = colors.Cyan })
	corner(awakenFill, 3)

	-- Combo counter (right middle of the screen).
	comboFrame = frame(gui, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -28, 0.42, 0), Size = UDim2.fromOffset(200, 90), BackgroundTransparency = 1, Visible = false })
	comboNumber = text(comboFrame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(200, 60), Font = TITLE_FONT, TextSize = 58, TextStrokeTransparency = 0.15, TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
	comboWord = text(comboFrame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 58), Size = UDim2.fromOffset(200, 18), Font = TITLE_FONT, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, Text = "HIT COMBO!" })
	comboDrain = frame(comboFrame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 80), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = colors.Ice })
	corner(comboDrain, 2)

	-- Toast pill above the hotbar.
	local toastHolder = frame(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -190), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1 })
	toastFrame = frame(toastHolder, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(260, 32), BackgroundColor3 = DARK, BackgroundTransparency = 0.15, Visible = false })
	corner(toastFrame, 16)
	toastAccent = frame(toastFrame, { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.fromRGB(255, 110, 100), Rotation = 45 })
	corner(toastAccent, 3)
	toastLabel = text(toastFrame, { Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -40, 1, 0), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Text = "" })

	-- Awakening banner: black slash band, gradient title, menacing ゴ letters.
	bannerBand = frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.new(1.4, 0, 0, 110), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Rotation = -4 })
	banner = text(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.fromOffset(800, 84), Font = TITLE_FONT, TextSize = 78, TextColor3 = WHITE, TextTransparency = 1, TextStrokeTransparency = 1, Text = "", ZIndex = 3 })
	bannerGradient = gradient(banner, WHITE, colors.Cyan, 90)
	bannerSub = text(banner, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(600, 22), TextSize = 17, TextTransparency = 1, TextStrokeTransparency = 1, Text = "", ZIndex = 3 })
	for i, spot in ipairs({ { 0.2, -20 }, { 0.27, 25 }, { 0.73, -25 }, { 0.8, 20 } }) do
		local m = text(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(70, 70), TextSize = 56, Font = FONT, Text = "ゴ", TextTransparency = 1, TextStrokeTransparency = 0.6, TextStrokeColor3 = Color3.fromRGB(40, 0, 60), Rotation = (i % 2 == 0) and 12 or -12, ZIndex = 2 })
		m:SetAttribute("X", spot[1])
		m:SetAttribute("Y", spot[2])
		menacing[i] = m
	end

	-- MOVESET button (opens the Act menu), Studio only in Awaken mode.
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

	-- Scale the HUD down on small screens.
	local function rescale()
		local camera = workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
		hudScale.Scale = math.clamp(math.min(size.X / 760, size.Y / 560), 0.62, 1.15)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	-- Combo counter feeds on the attacker-only Damage event.
	Net.get("SpinFX").OnClientEvent:Connect(function(name)
		if name == "Damage" and hud.Visible then
			bumpCombo()
		end
	end)
	-- M1 card squash on click.
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and hud.Visible and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == TuskConfig.Keys.M1.Gamepad) then
			slots.M1.KeyDownAt = os.clock()
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

-- Ultimate awakened Tusk to the next Act.
function TuskUI.onEvolve(data)
	if data.Character ~= player.Character then
		return
	end
	local info = Registry.get(data.To)
	if info then
		showBanner(info.Name .. "!", "AWAKENED  ·  " .. info.Tagline:upper(), info.Theme.Primary, 2.6)
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
local function applyTheme(card)
	card.EdgeGradient.Color = ColorSequence.new(theme.Primary, theme.Secondary)
	card.Accent.BackgroundColor3 = theme.Primary
	card.Badge.BackgroundColor3 = theme.Primary
	card.GlowStroke.Color = theme.Primary
	card.ShadeEdge.BackgroundColor3 = theme.Primary
	card.ChargeFill.BackgroundColor3 = theme.Primary
	colorIcon(card.Icon, theme.Primary:Lerp(WHITE, 0.35))
end

local function refreshAct(act)
	shownAct = act
	hud.Visible = act ~= nil
	if not act then
		return
	end
	local info = Registry.get(act)
	theme = info.Theme
	actLabel.Text = info.Name
	actGradient.Color = ColorSequence.new(WHITE, theme.Primary:Lerp(WHITE, 0.2))
	actBand.BackgroundColor3 = theme.Secondary
	taglineLabel.Text = info.Tagline:upper()
	slots.M1.Name.Text = info.M1
	for i = 1, 3 do
		slots[i].Name.Text = info.Abilities[i]
		slots[i].Kind = info.AbilityKinds and info.AbilityKinds[i] or "Press"
		drawIcon(slots[i].Icon, iconKind(info.Abilities[i]))
	end
	slots.Ult.Name.Text = info.Ultimate
	slots.Ult.MeterGradient.Color = ColorSequence.new(theme.Primary, theme.Secondary)
	for _, card in ipairs({ slots.M1, slots[1], slots[2], slots[3], slots.Ult }) do
		applyTheme(card)
	end
	awakenFill.BackgroundColor3 = theme.Primary
	-- Slide the hotbar in.
	animateJob("hudIn", 0.35, function(a)
		hud.Position = UDim2.new(0.5, 0, 1, -16 + (1 - VFXLib.easeOut(a)) * 60)
	end)
end

local function keyHeld(slotKey)
	local keys = TuskConfig.Keys[slotKey]
	if not keys or UserInputService:GetFocusedTextBox() then
		return false
	end
	local k = keys.Keyboard
	if typeof(k) == "EnumItem" and k.EnumType == Enum.KeyCode and UserInputService:IsKeyDown(k) then
		return true
	end
	local ok, down = pcall(function()
		return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, keys.Gamepad)
	end)
	return ok and down
end

-- The registry buff (if any) that is running on this slot right now.
local function buffFor(info, slot, character)
	local list = info.Buffs or (info.Buff and { info.Buff }) or {}
	for _, buff in ipairs(list) do
		local untilT = buff.Slot == slot and character:GetAttribute(buff.Attribute)
		if untilT and untilT > workspace:GetServerTimeNow() then
			return buff
		end
	end
	return nil
end

local function setKey(card, keyText)
	card.Key.Text = keyText
	card.Badge.Visible = keyText ~= ""
	card.Badge.Size = UDim2.fromOffset(math.max(22, #keyText * 8 + 12), 18)
end

local function stepCard(card, now, dt, cooling)
	-- Press squash + ready pop + hover.
	local target = (card.Pressed and 0.9 or 1) + (card.Pop or 0) + (card.Hover and 0.03 or 0)
	card.Scale.Scale = card.Scale.Scale + (target - card.Scale.Scale) * math.min(1, dt * 18)
	-- Cooldown shade.
	if cooling then
		local left = card.CooldownEnd - now
		card.Shade.Size = UDim2.fromScale(1, math.clamp(left / math.max(card.CooldownDur, 0.01), 0, 1))
		card.Timer.Text = left >= 10 and tostring(math.ceil(left)) or string.format("%.1f", left)
		colorIcon(card.Icon, GREY)
		card.Name.TextColor3 = GREY
		card.Badge.BackgroundColor3 = GREY
	elseif card.WasCooling then
		card.Shade.Size = UDim2.fromScale(1, 0)
		card.Timer.Text = ""
		colorIcon(card.Icon, theme.Primary:Lerp(WHITE, 0.35))
		card.Name.TextColor3 = colors.Ice
		card.Badge.BackgroundColor3 = theme.Primary
		readyFlash(card)
	end
	card.WasCooling = cooling
end

function TuskUI.step(act)
	if act ~= shownAct then
		refreshAct(act)
	end
	if not act then
		return
	end
	local now = os.clock()
	local dt = math.clamp(now - (TuskUI.LastStep or now), 0, 0.1)
	TuskUI.LastStep = now
	local info = Registry.get(act)
	local character = player.Character

	-- M1 card.
	setKey(slots.M1, keyName("M1"))
	slots.M1.Pressed = (slots.M1.KeyDownAt and now - slots.M1.KeyDownAt < 0.1) or false
	stepCard(slots.M1, now, dt, false)

	-- Ability cards.
	local chargeStart = character and character:GetAttribute("TuskCharge")
	local chargeMove = character and character:GetAttribute("TuskChargeMove")
	local actCfg = TuskConfig["Act" .. act]
	for i = 1, 3 do
		local card = slots[i]
		setKey(card, keyName("Ability" .. i))
		if keyHeld("Ability" .. i) then
			card.Pressed = true
			card.KeyPressed = true
		elseif card.KeyPressed then
			card.Pressed = false
			card.KeyPressed = false
		end
		stepCard(card, now, dt, card.CooldownEnd > now)
		-- Hold-move charge bar.
		local cfg = chargeMove and actCfg and actCfg[chargeMove]
		if chargeStart and card.Kind == "Hold" and cfg then
			local held = workspace:GetServerTimeNow() - chargeStart
			local full = cfg.FullChargeAt or (cfg.Stages and cfg.Stages[#cfg.Stages]) or cfg.MaxHold or 1.5
			local k = math.clamp(held / full, 0, 1)
			card.ChargeBack.Visible = true
			card.ChargeFill.Size = UDim2.fromScale(k, 1)
			if k >= 1 then
				local pulse = (math.sin(now * 14) + 1) / 2
				card.ChargeFill.BackgroundColor3 = theme.Primary:Lerp(WHITE, pulse)
				card.ChargeText.Text = "FULL!"
				card.GlowStroke.Transparency = 0.55 + pulse * 0.3
			else
				card.ChargeFill.BackgroundColor3 = theme.Primary
				card.ChargeText.Text = cfg.Stages and ("STAGE " .. (function()
					local stage = 0
					for s, t in ipairs(cfg.Stages) do
						if held >= t then
							stage = s
						end
					end
					return stage
				end)()) or ""
				card.GlowStroke.Transparency = 1
			end
		elseif character and buffFor(info, i, character) then
			-- Active buff (e.g. Scary Monsters, a commanded dinosaur): draining timer bar + glow.
			local buff = buffFor(info, i, character)
			local untilT = character:GetAttribute(buff.Attribute)
			local left = math.max(0, untilT - workspace:GetServerTimeNow())
			card.BuffMax = math.max(card.BuffMax or 0, left)
			card.ChargeBack.Visible = true
			card.ChargeFill.Size = UDim2.fromScale(left / math.max(card.BuffMax, 0.01), 1)
			card.ChargeFill.BackgroundColor3 = theme.Primary
			card.ChargeText.Text = (buff.Text or "ACTIVE") .. " " .. math.ceil(left) .. "s"
			card.GlowStroke.Transparency = 0.45 + (math.sin(now * 5) + 1) * 0.15
		elseif card.ChargeBack.Visible then
			card.ChargeBack.Visible = false
			card.GlowStroke.Transparency = 1
			card.BuffMax = nil
		end
	end

	-- Ultimate card.
	local ult = slots.Ult
	local max = TuskConfig.Ultimate.MaxMeter
	local meter = player:GetAttribute("TuskUlt") or 0
	ultShown = ultShown + (meter - ultShown) * math.min(1, dt * 8)
	local ready = meter >= max
	local since = player:GetAttribute("TuskActSince")
	local wait = TuskConfig.Ultimate.MinSecondsPerAct or 0
	local lockLeft = since and math.max(0, wait - (workspace:GetServerTimeNow() - since)) or 0
	setKey(ult, keyName("Ultimate"))
	ult.Meter.Size = UDim2.fromScale(1, math.clamp(ultShown / max, 0, 1))
	if ready and lockLeft > 0 then
		ult.Percent.Text = "LOCKED"
		ult.Timer.Text = math.ceil(lockLeft) .. "s"
		ult.MeterGradient.Color = ColorSequence.new(GREY, Color3.fromRGB(60, 62, 75))
		ult.EdgeGradient.Color = ColorSequence.new(GREY, Color3.fromRGB(60, 62, 75))
		ult.Pop = 0
		ult.GlowStroke.Transparency = 1
		ult.EdgeGradient.Rotation = 45
		colorIcon(ult.Icon, GREY)
	elseif ready then
		if not wasReady then
			readyFlash(ult)
			TuskUI.toast(info.Ultimate .. " READY!", theme.Primary)
		end
		local pulse = (math.sin(now * 6) + 1) / 2
		ult.Percent.Text = "READY"
		ult.Timer.Text = ""
		ult.MeterGradient.Color = ColorSequence.new(theme.Primary:Lerp(WHITE, pulse * 0.5), theme.Secondary)
		ult.GlowStroke.Transparency = 0.5 + pulse * 0.35
		ult.EdgeGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, theme.Secondary), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(1, theme.Secondary) })
		ult.EdgeGradient.Rotation = (now * 240) % 360 -- spinning shine on the border
		ult.Pop = 0.03 + pulse * 0.04
		colorIcon(ult.Icon, WHITE)
	else
		ult.EdgeGradient.Color = ColorSequence.new(theme.Primary, theme.Secondary)
		if wasReady then
			ult.Pop = 0
		end
		ult.Percent.Text = math.floor(ultShown / max * 100 + 0.5) .. "%"
		ult.Timer.Text = ""
		ult.MeterGradient.Color = ColorSequence.new(theme.Primary, theme.Secondary)
		ult.GlowStroke.Transparency = 1
		ult.EdgeGradient.Rotation = 45
		colorIcon(ult.Icon, theme.Primary:Lerp(WHITE, 0.35))
	end
	wasReady = ready and lockLeft <= 0
	if keyHeld("Ultimate") then
		ult.Pressed = true
		ult.KeyPressed = true
	elseif ult.KeyPressed then
		ult.Pressed = false
		ult.KeyPressed = false
	end
	stepCard(ult, now, dt, false)

	-- Sneak chip.
	local sneaking = character and character:GetAttribute("TuskSneaking") == true
	local sp = slots.SneakParts
	-- Every character can sneak. While sneaking: HIDDEN, or SPOTTED! when an NPC has seen you.
	sneakChip.Visible = act ~= nil
	local spotted = sneaking and (character:GetAttribute("SpottedUntil") or 0) > workspace:GetServerTimeNow()
	local SPOT = Color3.fromRGB(255, 90, 80)
	sp.KeyText.Text = keyName("Sneak") ~= "" and keyName("Sneak") or "C"
	local tint = spotted and SPOT or theme.Primary
	sp.Stroke.Color = sneaking and tint or Color3.fromRGB(60, 80, 120)
	sp.Key.BackgroundColor3 = sneaking and tint or Color3.fromRGB(60, 80, 120)
	sp.Text.TextColor3 = sneaking and tint or Color3.fromRGB(150, 170, 200)
	sp.Text.Text = spotted and "SPOTTED!" or (sneaking and "HIDDEN" or "SNEAK")
	sneakChip.BackgroundColor3 = sneaking and DARK2 or DARK
	sneakHint.Visible = sneaking and sneakChip.Visible
	sneakHint.Text = Registry.characterOf(act) == "Johnny" and "M1 / TAP: SNEAK ATTACK" or "ATTACK: AMBUSH (+50% FIRST HIT)"
end

local function cooldown(slot, duration)
	local card = slots[slot]
	if not card then
		return
	end
	card.CooldownEnd = os.clock() + duration
	card.CooldownDur = duration
end

local DENY_TEXT = {
	Cooldown = "ON COOLDOWN",
	UltNotReady = "ULTIMATE NOT READY",
	GuardBroken = "GUARD BROKEN: CAN'T BLOCK YET",
	DashCooldown = "DASH ON COOLDOWN",
	NotAvailable = "THAT CHARACTER ISN'T INSTALLED",
	Locked = "ACT LOCKED",
	SwitchCooldown = "WAIT BEFORE SWITCHING ACTS",
	SneakCooldown = "SNEAK ON COOLDOWN",
	SneakAttackCooldown = "SNEAK ATTACK ON COOLDOWN",
	NoTarget = "NO TARGET IN FRONT",
	Blocked = "NO ROOM TO MOVE THERE",
	TooSoon = "TUSK ISN'T READY TO AWAKEN YET",
	NeedCorpse = "FIND A SAINT'S CORPSE PART FIRST",
}

-- Wobble a card (denied input).
local function nudge(card)
	if not card then
		return
	end
	animateJob("nudge" .. card.Button.Name, 0.3, function(a)
		card.Button.Rotation = math.sin(a * 40) * 5 * (1 - a)
	end, function()
		card.Button.Rotation = 0
	end)
end

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
		if data.Slot and slots[data.Slot] then
			nudge(slots[data.Slot])
		elseif data.Reason == "UltNotReady" or data.Reason == "TooSoon" then
			nudge(slots.Ult)
		end
	elseif kind == "Interrupted" then
		TuskUI.toast("INTERRUPTED!")
	elseif kind == "SneakAttackCooldown" then
		slots.SneakParts.Text.Text = "SNEAK"
	elseif kind == "Awakened" then
		local info = shownAct and Registry.get(shownAct)
		showBanner(info and info.Ultimate or "AWAKENED", "ABILITIES EMPOWERED", theme.Primary, 1.9)
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
			local info = Registry.get(data.Act)
			TuskUI.toast(info.Name .. " EQUIPPED", info.Theme.Primary)
		end
	end
end

return TuskUI
end

-- ======================================================================
-- MODULE: TuskVFX
-- ======================================================================
__modules["TuskVFX"] = function()
--[[
	TuskVFX  (StarterPlayerScripts.SpinClient.TuskVFX)

	Reusable procedural VFX framework for every Tusk Act (built on VFXLib).
	Every function takes an options table; common options:
	  Duration, Radius/Size, Color, Color2, RotationSpeed (rad/s),
	  Particles (count multiplier), Transparency, Width
	Quality comes from VFXQuality automatically (segments, particles,
	optional layers). Every effect returns a handle with :Destroy() and
	cleans itself up when its Duration ends.

	  CreateSpinRing(opts)                 rotating energy ring (follows a target)
	  CreateMagicCircle(cframe, opts)      layered rings + star polygon
	  CreateEnergyCharge(opts)             growing core, accelerating rings, inward particles
	  CreateNailProjectile(opts)           nail + helix energy trails + optional rings
	  CreateRotationalShockwave(cf, opts)  layered spinning rings, ground disc, particles
	  CreateWormhole(cframe, opts)         opening, concentric rings, distorted interior, collapse
	  CreateGoldenAura(character, opts)    outline, orbiting rings, rising particles
	  CreateDistortion(position, opts)     refractive heat-haze sphere (High quality)
	  CreateImpact(position, normal, opts) staged impact: flash, shockwave, sparks, dust
	  CreateTuskTransformation(character, opts)  cinematic Act transformation
	  CreateImpactStar(position, opts)     tapered light rays bursting from a hit
	  CreateGroundCracks(position, opts)   glowing cracks torn into the ground
	  CreateEnergyPillar(position, opts)   column of energy shooting upward
	  CreateCrescent(cframe, opts)         tapered crescent slash that sweeps and fades
	  ScreenTint(duration, opts)           darken / tint the screen, then release
	  CreateGoldenSpiral(cframe, opts)     golden-ratio spiral of light, spinning up
	  CreateGoldenRectangle(cframe, opts)  nested golden rectangles + spiral
	  CleanupEffect(handle)
]]

local Debris = game:GetService("Debris")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local VFXQuality = __require("VFXQuality")
local NailModel = __require("NailModel")
local VFXLib = __require("VFXLib")

local TuskVFX = {}
local colors = TuskConfig.Colors
local LONG = 1e6 -- "until destroyed"

local function q()
	return VFXQuality.get()
end

function TuskVFX.CleanupEffect(handle)
	if handle and handle.Destroy then
		pcall(handle.Destroy, handle)
	end
end

local function fadeAlpha(a, fadeIn, fadeOut)
	if a < fadeIn then
		return 1 - a / fadeIn
	elseif a > 1 - fadeOut then
		return (a - (1 - fadeOut)) / fadeOut
	end
	return 0
end

---------------------------------------------------------------------------
-- Spin ring
---------------------------------------------------------------------------
function TuskVFX.CreateSpinRing(opts)
	local ring = VFXLib.ring({
		CFrame = opts.CFrame or CFrame.new(),
		Radius = opts.Radius or 2,
		Width = opts.Width or 0.15,
		Color = opts.Color or colors.Cyan,
		Transparency = 1,
		Segments = opts.Segments,
	})
	local handle = { Ring = ring, Angle = opts.StartAngle or 0, Speed = opts.RotationSpeed or 4, Alive = true }
	local baseT = opts.Transparency or 0.1
	local duration = opts.Duration
	handle.Job = VFXLib.animate(duration or LONG, function(a, dt)
		handle.Angle = handle.Angle + handle.Speed * (dt or 0)
		local base = opts.Follow and opts.Follow() or opts.CFrame
		if base then
			ring:SetCFrame(base * (opts.Tilt or CFrame.new()) * CFrame.Angles(0, handle.Angle, 0))
		end
		local fade = duration and fadeAlpha(a, 0.12, 0.3) or math.max(0, 1 - (a * LONG) / 0.15)
		ring:SetTransparency(baseT + (1 - baseT) * fade)
	end, function()
		handle.Alive = false
		ring:Destroy()
	end)
	function handle:SetRadius(r)
		ring:SetRadius(r)
	end
	function handle:SetColor(c)
		ring:SetColor(c)
	end
	function handle:SetWidth(w)
		ring:SetWidth(w)
	end
	function handle:Destroy()
		VFXLib.cancel(self.Job)
	end
	return handle
end

---------------------------------------------------------------------------
-- Magic circle: outer ring, inner ring and a star polygon of beams
---------------------------------------------------------------------------
function TuskVFX.CreateMagicCircle(cframe, opts)
	opts = opts or {}
	local radius = opts.Radius or 6
	local color = opts.Color or colors.Cyan
	local duration = opts.Duration or 2
	local points = opts.Points or 6
	local carrier = VFXLib.anchor(cframe)
	local attachments = {}
	for i = 1, points do
		local a = Instance.new("Attachment")
		a.Parent = carrier
		attachments[i] = a
	end
	local beams = {}
	local skip = points == 6 and 2 or 2
	for i = 1, points do
		local b = Instance.new("Beam")
		b.Attachment0 = attachments[i]
		b.Attachment1 = attachments[(i - 1 + skip) % points + 1]
		b.Color = ColorSequence.new(opts.Color2 or color)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Width0 = opts.Width or 0.18
		b.Width1 = opts.Width or 0.18
		b.FaceCamera = true
		b.Segments = 1
		b.Parent = carrier
		beams[i] = b
	end
	local outer = TuskVFX.CreateSpinRing({ CFrame = cframe, Radius = radius, Width = 0.25, Color = color, RotationSpeed = opts.RotationSpeed or 1, Duration = duration })
	local inner = TuskVFX.CreateSpinRing({ CFrame = cframe, Radius = radius * 0.72, Width = 0.15, Color = opts.Color2 or color, RotationSpeed = -(opts.RotationSpeed or 1) * 1.6, Duration = duration })
	local handle = { Outer = outer, Inner = inner }
	local angle = 0
	handle.Job = VFXLib.animate(duration, function(a, dt)
		angle = angle + (opts.RotationSpeed or 1) * 0.7 * (dt or 0)
		local open = VFXLib.easeOut(math.min(a / 0.2, 1))
		local r = radius * 0.7 * open
		for i, att in ipairs(attachments) do
			local th = angle + (i - 1) / points * math.pi * 2
			att.Position = Vector3.new(math.cos(th) * r, 0.02, math.sin(th) * r)
		end
		outer:SetRadius(radius * open)
		inner:SetRadius(radius * 0.72 * open)
		local fade = fadeAlpha(a, 0.1, 0.25)
		local seq = NumberSequence.new(0.1 + 0.9 * fade)
		for _, b in ipairs(beams) do
			b.Transparency = seq
		end
	end, function()
		carrier:Destroy()
	end)
	function handle:Destroy()
		VFXLib.cancel(self.Job)
		outer:Destroy()
		inner:Destroy()
	end
	return handle
end

---------------------------------------------------------------------------
-- Energy charge: core sphere + accelerating rings + particles pulled inward
---------------------------------------------------------------------------
function TuskVFX.CreateEnergyCharge(opts)
	local color = opts.Color or colors.Cyan
	local color2 = opts.Color2 or colors.Ice
	local maxRadius = opts.MaxRadius or 1.4
	local ringCount = math.min(opts.Rings or 3, 3)
	local follow = opts.Follow
	local handle = { Progress = 0, Rings = {} }

	local core = VFXLib.part({ Shape = Enum.PartType.Ball, Color = color2, Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 0.15 })
	local light
	if q().Lights then
		light = Instance.new("PointLight")
		light.Color = color
		light.Range = 8
		light.Brightness = 0
		light.Shadows = false
		light.Parent = core
	end

	-- Shell emitter: particles spawn on a sphere surface and fly inward.
	local shell = VFXLib.part({ Shape = Enum.PartType.Ball, Transparency = 1, Size = Vector3.new(maxRadius * 3, maxRadius * 3, maxRadius * 3) })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Sparkle
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Color = ColorSequence.new(color2, color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0), NumberSequenceKeypoint.new(1, 0.4) })
	emitter.Lifetime = NumberRange.new(0.35, 0.45)
	emitter.Speed = NumberRange.new(maxRadius * 3.2, maxRadius * 3.6)
	emitter.Rate = 0
	emitter.Parent = shell

	for i = 1, ringCount do
		handle.Rings[i] = TuskVFX.CreateSpinRing({
			Follow = function()
				return core.CFrame
			end,
			Tilt = CFrame.Angles(0.6 * i, 0, 0.9 * i),
			Radius = 0.1,
			Width = 0.08,
			Color = i == 1 and color2 or color,
			RotationSpeed = 3 + i * 1.5,
			Transparency = 0.15,
		})
	end

	local duration = opts.Duration or 1.2
	local manual = opts.Manual == true
	handle.Job = VFXLib.animate(LONG, function(a, dt)
		local cf = follow and follow() or opts.CFrame
		if not cf then
			return
		end
		local elapsed = a * LONG
		if not manual then
			handle.Progress = math.min(elapsed / duration, 1)
		end
		local p = handle.Progress
		local pulse = 1 + math.sin(elapsed * 18) * 0.06 * p
		local coreSize = (0.25 + p * maxRadius * 0.6) * pulse
		core.CFrame = cf
		core.Size = Vector3.new(coreSize, coreSize, coreSize)
		shell.CFrame = cf
		emitter.Rate = (10 + p * 50) * q().Particles * (opts.Particles or 1)
		if light then
			light.Brightness = 1 + p * 3
		end
		for i, ring in ipairs(handle.Rings) do
			ring.Speed = (3 + i * 1.5) * (1 + p * 3) -- rings accelerate as energy builds
			ring:SetRadius(0.3 + p * maxRadius * (0.55 + i * 0.22))
		end
		if handle.OnStep then
			handle.OnStep(p, cf)
		end
	end, function()
		core:Destroy()
		shell:Destroy()
		for _, ring in ipairs(handle.Rings) do
			ring:Destroy()
		end
	end)

	function handle:SetProgress(p)
		self.Progress = math.clamp(p, 0, 1)
	end
	function handle:Destroy()
		VFXLib.cancel(self.Job)
	end
	-- Bright flash + outward burst, then cleanup.
	function handle:Release(direction)
		local pos = core.Position
		VFXLib.burst(pos, { Count = 20, Color = color2, Speed = 22, Lifetime = 0.35, Direction = direction, Spread = direction and 35 or 180 })
		VFXLib.flash(pos, color, 6, 14, 0.25)
		local flash = VFXLib.part({ Shape = Enum.PartType.Ball, Color = colors.Ice, Size = core.Size, CFrame = core.CFrame, Transparency = 0 })
		local s0 = core.Size.X
		VFXLib.animate(0.15, function(a)
			local s = s0 * (1 + a * 2.5)
			flash.Size = Vector3.new(s, s, s)
			flash.Transparency = a
		end, function()
			flash:Destroy()
		end)
		self:Destroy()
	end
	return handle
end

---------------------------------------------------------------------------
-- Nail projectile visual (pooled nails)
---------------------------------------------------------------------------
local nailPool = {}

local function takeNail(scale)
	local nail = table.remove(nailPool)
	if not nail then
		nail = NailModel.build(1.3)
		nail.PrimaryPart.Anchored = true
	end
	nail:ScaleTo(scale)
	return nail
end

local function returnNail(nail)
	nail.Parent = nil
	if #nailPool < 16 then
		table.insert(nailPool, nail)
	else
		nail:Destroy()
	end
end

local function trailBetween(parent, a0, a1, color, color2, lifetime, transparency)
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = ColorSequence.new(color, color2 or color)
	t.LightEmission = 1
	t.LightInfluence = 0
	t.Lifetime = lifetime
	t.FaceCamera = true
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, transparency or 0), NumberSequenceKeypoint.new(1, 1) })
	t.WidthScale = NumberSequence.new(1, 0.2)
	t.Parent = parent
	return t
end

-- A Spin whirl: spiral arms of beams around an axis (the carrier's local Z),
-- cyan at the centre fading to blue at the tips. Spin it by rotating the carrier.
local function createWhirl(radius, color, color2, arms, points)
	local carrier = VFXLib.anchor(CFrame.new())
	local beams = {}
	for arm = 0, arms - 1 do
		local prev
		for i = 0, points do
			local t = i / points
			local angle = arm / arms * math.pi * 2 + t * math.pi * 1.6
			local r = radius * (0.25 + t * 0.75)
			local a = Instance.new("Attachment")
			a.Position = Vector3.new(math.cos(angle) * r, math.sin(angle) * r, t * radius * 0.35)
			a.Parent = carrier
			if prev then
				local b = Instance.new("Beam")
				b.Attachment0 = prev
				b.Attachment1 = a
				b.FaceCamera = true
				b.LightEmission = 1
				b.LightInfluence = 0
				b.Segments = 1
				local c = color:Lerp(color2, t)
				b.Color = ColorSequence.new(c)
				b.Width0 = radius * 0.16 * (1 - t * 0.6)
				b.Width1 = radius * 0.16 * (1 - (t + 1 / points) * 0.6)
				b.Transparency = NumberSequence.new(0.05 + t * 0.6, 0.05 + math.min(1, t + 1 / points) * 0.6)
				b.Parent = carrier
				table.insert(beams, b)
			end
			prev = a
		end
	end
	return carrier
end

--[[
	opts: Scale, Color, Color2 (helix), TrailColor, Rings (0..3), RingColor,
	      Whirls (0..3) + WhirlColor / WhirlColor2: spinning Spin whirls
	      Glow (true): cyan neon glow sleeve around the nail
	      HelixRadius, Helix (strand count), Afterimages, SpinSpeed
	visual:Step(cframe, dt)  visual:Destroy()
]]
function TuskVFX.CreateNailProjectile(opts)
	local scale = opts.Scale or 1
	local nail = takeNail(scale)
	nail.Parent = VFXLib.Folder

	-- Carrier rotates around the flight axis; attachments on it draw helix trails.
	local carrier = VFXLib.anchor(CFrame.new())
	local trails = {}
	local helixRadius = (opts.HelixRadius or 0.35) * scale
	local strands = opts.Helix or 2
	for i = 1, strands do
		local th = (i - 1) / strands * math.pi * 2
		local dir = Vector3.new(math.cos(th), math.sin(th), 0)
		local a0 = Instance.new("Attachment")
		a0.Position = dir * helixRadius
		a0.Parent = carrier
		local a1 = Instance.new("Attachment")
		a1.Position = dir * (helixRadius + 0.08 * scale)
		a1.Parent = carrier
		table.insert(trails, trailBetween(carrier, a0, a1, opts.Color2 or colors.Cyan, opts.Color or colors.Blue, 0.22, 0.05))
	end
	-- Thin core trail straight behind the nail.
	local c0 = Instance.new("Attachment")
	c0.Position = Vector3.new(0, 0.05 * scale, 0)
	c0.Parent = carrier
	local c1 = Instance.new("Attachment")
	c1.Position = Vector3.new(0, -0.05 * scale, 0)
	c1.Parent = carrier
	table.insert(trails, trailBetween(carrier, c0, c1, opts.TrailColor or colors.Blue, colors.DeepBlue, 0.35 * (opts.TrailLength or 1), 0))

	local rings = {}
	for i = 1, (opts.Rings or 0) do
		rings[i] = VFXLib.ring({ Radius = (0.35 + i * 0.22) * scale, Width = 0.08 * scale, Color = opts.RingColor or colors.Cyan, Transparency = 0.1 })
	end

	-- Glowing cyan sleeve around the nail.
	local glow
	if opts.Glow then
		glow = VFXLib.part({ Color = opts.GlowColor or colors.Cyan, Transparency = 0.45, Size = Vector3.new(0.32, 0.32, 1.6) * scale })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = glow
	end
	-- Spin whirls that keep spinning around the flight path.
	local whirls = {}
	local whirlCount = opts.Whirls or 0
	if q().RingSegments <= 12 then
		whirlCount = math.min(whirlCount, 1)
	end
	for i = 1, whirlCount do
		whirls[i] = createWhirl((0.55 + i * 0.22) * scale, opts.WhirlColor or colors.Cyan, opts.WhirlColor2 or colors.Blue, 3, q().RingSegments > 12 and 6 or 4)
	end

	local visual = { Spin = 0, NextGhost = 0, Alive = true }
	function visual:Step(cframe, dt)
		self.Spin = self.Spin + (dt or 0) * (opts.SpinSpeed or 30)
		nail:PivotTo(cframe * CFrame.Angles(0, 0, self.Spin))
		if glow then
			local pulse = 1 + math.sin(self.Spin * 0.6) * 0.12
			glow.CFrame = cframe * CFrame.new(0, 0, 0.1 * scale)
			glow.Size = Vector3.new(0.32 * pulse, 0.32 * pulse, 1.6) * scale
		end
		for i, whirl in ipairs(whirls) do
			-- Each whirl sits a little further back and spins the opposite way.
			local dir = i % 2 == 1 and 1 or -1
			whirl.CFrame = cframe * CFrame.new(0, 0, (0.15 + (i - 1) * 0.55) * scale) * CFrame.Angles(0, 0, self.Spin * 0.45 * dir)
		end
		carrier.CFrame = cframe * CFrame.new(0, 0, 0.5 * scale) * CFrame.Angles(0, 0, self.Spin * 0.5)
		for i, ring in ipairs(rings) do
			local tilt = 0.4 * i
			ring:SetCFrame(cframe * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.Angles(tilt * math.sin(self.Spin * 0.2 + i), self.Spin * (0.3 + i * 0.15), tilt))
		end
		if opts.Afterimages and q().Afterimages and os.clock() >= self.NextGhost then
			self.NextGhost = os.clock() + 0.045
			VFXLib.afterimage(cframe, 0.35 * scale, opts.RingColor or colors.Cyan)
		end
	end
	function visual:Destroy()
		if not self.Alive then
			return
		end
		self.Alive = false
		returnNail(nail)
		if glow then
			glow:Destroy()
		end
		for _, whirl in ipairs(whirls) do
			whirl:Destroy()
		end
		for _, ring in ipairs(rings) do
			ring:Destroy()
		end
		for _, t in ipairs(trails) do
			t.Enabled = false
		end
		Debris:AddItem(carrier, 0.5)
	end
	return visual
end

---------------------------------------------------------------------------
-- Rotational shockwave
---------------------------------------------------------------------------
--[[ cf: UpVector = shockwave axis. opts: Radius, Color, Color2, Layers,
     Duration, Spin, Ground (disc), Particles, Width ]]
function TuskVFX.CreateRotationalShockwave(cf, opts)
	opts = opts or {}
	local layers = opts.Layers or 2
	if q().RingSegments <= 12 then
		layers = math.min(layers, 2)
	end
	local radius = opts.Radius or 8
	for i = 1, layers do
		task.delay((i - 1) * (opts.Stagger or 0.045), function()
			VFXLib.shockwave(cf * CFrame.Angles(0, i * 0.7, 0), {
				StartRadius = radius * 0.1,
				Radius = radius * (1 - (i - 1) * 0.22),
				Width = (opts.Width or 0.5) * (1 - (i - 1) * 0.2),
				Duration = (opts.Duration or 0.45) + i * 0.05,
				Color = (i % 2 == 1) and (opts.Color or colors.Cyan) or (opts.Color2 or colors.Blue),
				Spin = (opts.Spin or 2) * (i % 2 == 1 and 1 or -1),
			})
		end)
	end
	if opts.Ground then
		VFXLib.groundDisc(cf.Position, cf.UpVector, { Radius = radius * 0.6, Color = opts.Color2 or opts.Color or colors.Cyan, Duration = opts.Duration or 0.4 })
	end
	if (opts.Particles or 1) > 0 then
		VFXLib.burst(cf.Position, {
			Count = 16 * (opts.Particles or 1),
			Color = opts.Color or colors.Cyan,
			Speed = radius * 3,
			Lifetime = 0.45,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }),
		})
	end
end

---------------------------------------------------------------------------
-- Distortion (refraction haze). Glass refracts on higher graphics levels.
---------------------------------------------------------------------------
function TuskVFX.CreateDistortion(position, opts)
	opts = opts or {}
	if not q().ImpactFrames or not VFXLib.acquire() then
		return
	end
	local radius = opts.Radius or 4
	local sphere = VFXLib.part({
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Glass,
		Color = opts.Color or colors.Ice,
		Transparency = 0.6,
		Size = Vector3.new(0.5, 0.5, 0.5),
		CFrame = CFrame.new(position),
	})
	VFXLib.animate(opts.Duration or 0.35, function(a)
		local d = 0.5 + radius * 2 * VFXLib.easeOut(a)
		sphere.Size = Vector3.new(d, d, d)
		sphere.Transparency = 0.6 + 0.4 * a
	end, function()
		sphere:Destroy()
		VFXLib.release()
	end)
end

---------------------------------------------------------------------------
-- Staged impact: flash -> primary shockwave -> sparks -> dust (recovery)
---------------------------------------------------------------------------
function TuskVFX.CreateImpact(position, normal, opts)
	opts = opts or {}
	normal = normal or Vector3.new(0, 1, 0)
	local color = opts.Color or colors.Cyan
	local size = opts.Size or 1
	-- 1. impact flash
	local flash = VFXLib.part({ Shape = Enum.PartType.Ball, Color = colors.Ice, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(position) })
	VFXLib.animate(0.12, function(a)
		local d = 0.5 + 3 * size * a
		flash.Size = Vector3.new(d, d, d)
		flash.Transparency = a
	end, function()
		flash:Destroy()
	end)
	VFXLib.flash(position, color, 3 + size * 2, 10 + size * 6, 0.3)
	if opts.Star ~= false then
		TuskVFX.CreateImpactStar(position, { Size = 2.6 * size, Color = color, Color2 = colors.Ice, Duration = 0.2 + size * 0.05 })
	end
	-- 2. primary shockwave around the surface normal
	local axis = CFrame.lookAt(position, position + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
	TuskVFX.CreateRotationalShockwave(axis, {
		Radius = (opts.Radius or 4) * size,
		Layers = opts.Layers or 2,
		Color = color,
		Color2 = opts.Color2 or colors.Blue,
		Ground = normal.Y > 0.6 and opts.Ground ~= false,
		Particles = 0,
		Width = 0.3 * size,
	})
	-- 3. secondary sparks
	VFXLib.burst(position, {
		Count = math.floor(12 * size),
		Color = opts.Color2 or colors.Ice,
		Speed = 30 * size,
		Lifetime = 0.4,
		Drag = 2,
		Acceleration = Vector3.new(0, -40, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) }),
		Direction = normal,
		Spread = 70,
	})
	-- 4. recovery dust
	if normal.Y > 0.6 then
		VFXLib.burst(position, {
			Count = math.floor(4 * size),
			Texture = VFXLib.Textures.Smoke,
			Color = Color3.fromRGB(196, 170, 125),
			LightEmission = 0,
			Speed = 6,
			Lifetime = 1,
			Drag = 3,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5 * size), NumberSequenceKeypoint.new(1, 4 * size) }),
			TransparencySeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		})
	end
	if opts.Sound then
		VFXLib.sound(opts.Sound, position, 0.6, opts.Pitch or 1)
	end
end

---------------------------------------------------------------------------
-- Wormhole portal
---------------------------------------------------------------------------
--[[ cframe: portal faces cframe.LookVector. opts: Radius, Color, Color2,
     Duration (hold time), OpenTime, CloseTime.  handle:Close() ]]
function TuskVFX.CreateWormhole(cframe, opts)
	opts = opts or {}
	local radius = opts.Radius or 3
	local color = opts.Color or colors.Cyan
	local color2 = opts.Color2 or colors.DeepBlue
	local openTime = opts.OpenTime or 0.25
	local closeTime = opts.CloseTime or 0.22
	-- Ring axis must be the portal facing: rotate so the ring's Up = LookVector.
	local axis = cframe * CFrame.Angles(math.pi / 2, 0, 0)

	local handle = { Scale = 0, Closing = false }
	local rings = {}
	local ringDefs = { { 1, 3, 0.22 }, { 0.82, -4.5, 0.14 }, { 0.62, 6, 0.1 } }
	for i, def in ipairs(ringDefs) do
		if i < 3 or q().RingSegments > 12 then
			rings[i] = TuskVFX.CreateSpinRing({ CFrame = axis, Radius = 0.1, Width = def[3], Color = i == 1 and color or colors.Ice, RotationSpeed = def[2], Transparency = 0.05 })
		end
	end
	-- Distorted interior: ForceField material shimmers; dark core gives depth.
	local interior = VFXLib.part({
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.ForceField,
		Color = color,
		Transparency = 0,
		Size = Vector3.new(0.05, 0.1, 0.1),
	})
	local core = VFXLib.part({
		Shape = Enum.PartType.Cylinder,
		Color = color2,
		Transparency = 0.15,
		Size = Vector3.new(0.04, 0.1, 0.1),
	})
	-- Cylinder axis is X; turn it to face the portal direction.
	local discCF = cframe * CFrame.Angles(0, math.pi / 2, 0)
	interior.CFrame = discCF
	core.CFrame = discCF * CFrame.new(0.05, 0, 0)

	-- Particles pulled inward from the rim.
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Sparkle
	emitter.Shape = Enum.ParticleEmitterShape.Cylinder
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Color = ColorSequence.new(colors.Ice, color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.3, 0.4)
	emitter.Speed = NumberRange.new(radius * 2.5, radius * 3)
	emitter.Rate = 30 * q().Particles
	emitter.Parent = interior

	local light
	if q().Lights then
		light = Instance.new("PointLight")
		light.Color = color
		light.Range = radius * 4
		light.Brightness = 3
		light.Shadows = false
		light.Parent = core
	end

	local function apply(s)
		for i, def in ipairs(ringDefs) do
			if rings[i] then
				rings[i]:SetRadius(math.max(radius * def[1] * s, 0.05))
			end
		end
		local d = math.max(radius * 1.8 * s, 0.1)
		interior.Size = Vector3.new(0.05, d, d)
		core.Size = Vector3.new(0.04, d * 0.75, d * 0.75)
	end
	apply(0)

	handle.Job = VFXLib.animate(LONG, function(a)
		local t = a * LONG
		if not handle.Closing then
			-- Overshoot ease on open, gentle breathing while held.
			local o = math.min(t / openTime, 1)
			local s = o < 1 and (1 - (1 - o) ^ 3) * (1 + 0.15 * math.sin(o * math.pi)) or 1 + math.sin(t * 6) * 0.03
			apply(s)
		end
	end, function()
		for _, ring in pairs(rings) do
			ring:Destroy()
		end
		interior:Destroy()
		core:Destroy()
	end)

	function handle:Close()
		if self.Closing then
			return
		end
		self.Closing = true
		emitter.Rate = 0
		local pos = cframe.Position
		VFXLib.animate(closeTime, function(a)
			apply(1 - VFXLib.easeInOut(a))
			if light then
				light.Brightness = 3 + a * 4
			end
		end, function()
			VFXLib.burst(pos, { Count = 14, Color = colors.Ice, Speed = 14, Lifetime = 0.3 })
			VFXLib.cancel(self.Job)
		end)
	end
	function handle:Destroy()
		VFXLib.cancel(self.Job)
	end
	if opts.Duration then
		task.delay(openTime + opts.Duration, function()
			handle:Close()
		end)
	end
	return handle
end

---------------------------------------------------------------------------
-- Aura (gold for Act 4; cyan/blue for Act 1 Awakened)
---------------------------------------------------------------------------
function TuskVFX.CreateGoldenAura(character, opts)
	opts = opts or {}
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return { Destroy = function() end }
	end
	local color = opts.Color or colors.Gold
	local color2 = opts.Color2 or colors.DeepBlue
	local handle = { Rings = {} }

	local highlight = Instance.new("Highlight")
	highlight.Adornee = character
	highlight.FillColor = color
	highlight.FillTransparency = 0.85
	highlight.OutlineColor = color
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = VFXLib.Folder

	local attachment = Instance.new("Attachment")
	attachment.Name = "TuskAura"
	attachment.Position = Vector3.new(0, -1, 0)
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Sparkle
	emitter.Color = ColorSequence.new(color, color2)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Acceleration = Vector3.new(0, 4, 0)
	emitter.Rate = 18 * q().Particles * (opts.Particles or 1)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = attachment

	for i = 1, (opts.Rings or 2) do
		handle.Rings[i] = TuskVFX.CreateSpinRing({
			Follow = function()
				return root.Parent and root.CFrame * CFrame.new(0, -2.6 + i * 1.2, 0) or nil
			end,
			Tilt = CFrame.Angles(0.25 * (i % 2 == 0 and 1 or -1), 0, 0.15),
			Radius = 2.4 - i * 0.3,
			Width = 0.12,
			Color = i % 2 == 1 and color or color2,
			RotationSpeed = (2.5 + i) * (i % 2 == 0 and -1 or 1),
			Transparency = 0.25,
		})
	end
	function handle:Destroy()
		highlight:Destroy()
		attachment:Destroy()
		for _, ring in ipairs(self.Rings) do
			ring:Destroy()
		end
	end
	return handle
end

---------------------------------------------------------------------------
-- Cinematic transformation (used by Act ultimates)
---------------------------------------------------------------------------
--[[ opts: Duration, Color, Color2, OnManifest() called at ~55%,
     OnBurst() called at the end. ]]
function TuskVFX.CreateTuskTransformation(character, opts)
	opts = opts or {}
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local duration = opts.Duration or 1.7
	local color = opts.Color or colors.Cyan
	local color2 = opts.Color2 or colors.Blue
	local groundCF = CFrame.new(root.Position - Vector3.new(0, 2.9, 0))

	-- Stage 1: layered magic circles open at the feet.
	TuskVFX.CreateMagicCircle(groundCF, { Radius = 7, Color = color, Color2 = colors.Ice, Duration = duration + 0.4, RotationSpeed = 1.2, Points = 6 })
	if q().RingSegments > 12 then
		TuskVFX.CreateMagicCircle(groundCF * CFrame.new(0, 0.05, 0), { Radius = 4.2, Color = color2, Duration = duration + 0.4, RotationSpeed = -2, Points = 5 })
	end

	-- Stage 2: rising energy column.
	local column = VFXLib.part({ Shape = Enum.PartType.Cylinder, Transparency = 1, Size = Vector3.new(0.1, 6, 6), CFrame = groundCF * CFrame.Angles(0, 0, math.pi / 2) })
	local rise = Instance.new("ParticleEmitter")
	rise.Texture = VFXLib.Textures.Sparkle
	rise.Shape = Enum.ParticleEmitterShape.Disc
	rise.Color = ColorSequence.new(colors.Ice, color)
	rise.LightEmission = 1
	rise.LightInfluence = 0
	rise.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	rise.Lifetime = NumberRange.new(0.6, 1)
	rise.Speed = NumberRange.new(8, 14)
	rise.EmissionDirection = Enum.NormalId.Right -- cylinder X axis = world up here
	rise.Rate = 40 * q().Particles
	rise.Parent = column
	Debris:AddItem(column, duration + 1.2)

	-- Stage 3: energy gathers at the chest.
	local charge = TuskVFX.CreateEnergyCharge({
		Follow = function()
			return root.Parent and root.CFrame * CFrame.new(0, 1, -1.2) or nil
		end,
		Color = color,
		Color2 = colors.Ice,
		MaxRadius = 1.6,
		Duration = duration * 0.9,
		Rings = 3,
	})

	task.delay(duration * 0.55, function()
		if opts.OnManifest then
			opts.OnManifest()
		end
	end)
	task.delay(duration, function()
		rise.Rate = 0
		charge:Release()
		-- Stage 4: burst
		TuskVFX.CreateRotationalShockwave(groundCF, { Radius = 20, Layers = 3, Color = color, Color2 = colors.Ice, Ground = true, Particles = 2, Width = 0.8, Duration = 0.6 })
		TuskVFX.CreateDistortion(root.Position, { Radius = 8, Duration = 0.4 })
		VFXLib.burst(root.Position, { Count = 40, Color = colors.Ice, Speed = 50, Lifetime = 0.6 })
		VFXLib.flash(root.Position, color, 10, 40, 0.5)
		if opts.OnBurst then
			opts.OnBurst()
		end
	end)
end

---------------------------------------------------------------------------
-- Impact star: tapered rays of light bursting out of a hit point.
---------------------------------------------------------------------------
--[[ opts: Size (ray length), Rays, Color, Color2, Duration, Width ]]
function TuskVFX.CreateImpactStar(position, opts)
	opts = opts or {}
	if not VFXLib.acquire() then
		return
	end
	local size = opts.Size or 4
	local rays = opts.Rays or (q().RingSegments > 12 and 10 or 6)
	local duration = opts.Duration or 0.28
	local width = opts.Width or size * 0.16
	local carrier = VFXLib.anchor(CFrame.new(position))
	local center = Instance.new("Attachment")
	center.Parent = carrier
	local tips = {}
	local beams = {}
	local color = ColorSequence.new(opts.Color2 or Color3.new(1, 1, 1), opts.Color or colors.Cyan)
	for i = 1, rays do
		-- Random direction, biased so most rays splay sideways (reads as a star).
		local dir = Vector3.new(math.random() * 2 - 1, (math.random() * 2 - 1) * 0.7, math.random() * 2 - 1)
		if dir.Magnitude < 0.05 then
			dir = Vector3.new(1, 0, 0)
		end
		local tip = Instance.new("Attachment")
		tip.Parent = carrier
		tips[i] = { Attachment = tip, Dir = dir.Unit, Length = size * (0.55 + math.random() * 0.6) }
		local b = Instance.new("Beam")
		b.Attachment0 = center
		b.Attachment1 = tip
		b.Color = color
		b.LightEmission = 1
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Segments = 1
		b.Width0 = width * (0.7 + math.random() * 0.6)
		b.Width1 = 0
		b.Parent = carrier
		beams[i] = b
	end
	VFXLib.animate(duration, function(a)
		local grow = VFXLib.easeOut(math.min(a / 0.3, 1))
		for _, t in ipairs(tips) do
			t.Attachment.Position = t.Dir * t.Length * grow
		end
		local fade = NumberSequence.new(math.clamp((a - 0.35) / 0.65, 0, 1))
		for _, b in ipairs(beams) do
			b.Transparency = fade
		end
	end, function()
		carrier:Destroy()
		VFXLib.release()
	end)
end

---------------------------------------------------------------------------
-- Ground cracks: jagged dark fissures with a glowing seam, fading out.
---------------------------------------------------------------------------
--[[ opts: Radius, Count, Color (glow), Duration, Ignore (instances) ]]
function TuskVFX.CreateGroundCracks(position, opts)
	opts = opts or {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { VFXLib.Folder }
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	for _, extra in ipairs(opts.Ignore or {}) do
		table.insert(ignore, extra)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), params)
	if not hit or hit.Normal.Y < 0.6 then
		return -- no flat ground under the impact
	end
	local ground = hit.Position + Vector3.new(0, 0.03, 0)
	local radius = opts.Radius or 8
	local count = opts.Count or (q().RingSegments > 12 and 9 or 5)
	local glowColor = opts.Color or colors.Cyan
	local duration = opts.Duration or 1.6
	local pieces = {}
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.6
		local point = ground + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * 0.12
		local length = radius * (0.6 + math.random() * 0.4)
		local steps = 4
		local width = 0.55
		for _ = 1, steps do
			angle = angle + (math.random() - 0.5) * 0.9
			local seg = length / steps
			local nextPoint = point + Vector3.new(math.cos(angle), 0, math.sin(angle)) * seg
			local cf = CFrame.lookAt(point:Lerp(nextPoint, 0.5), nextPoint)
			local crack = VFXLib.part({ Material = Enum.Material.Slate, Color = Color3.fromRGB(40, 32, 28), Size = Vector3.new(width, 0.08, seg + 0.2), CFrame = cf })
			local seam = VFXLib.part({ Color = glowColor, Size = Vector3.new(width * 0.35, 0.1, seg + 0.1), CFrame = cf * CFrame.new(0, 0.02, 0), Transparency = 0.1 })
			table.insert(pieces, { Part = crack, Base = 0 })
			table.insert(pieces, { Part = seam, Base = 0.1, Seam = true })
			point = nextPoint
			width = width * 0.72
		end
	end
	-- Chunks of debris kicked up from the cracks.
	VFXLib.burst(ground, {
		Count = math.floor(radius * 1.5),
		Texture = VFXLib.Textures.Smoke,
		Color = Color3.fromRGB(150, 128, 100),
		LightEmission = 0,
		Speed = radius * 1.2,
		Lifetime = 0.9,
		Drag = 3,
		Direction = Vector3.new(0, 1, 0),
		Spread = 80,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) }),
		TransparencySeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
	})
	VFXLib.animate(duration, function(a)
		for _, piece in ipairs(pieces) do
			if piece.Seam then
				-- The seam glows hot, then cools faster than the crack fades.
				piece.Part.Transparency = math.min(1, piece.Base + a * 1.4)
			else
				piece.Part.Transparency = math.clamp((a - 0.6) / 0.4, 0, 1)
			end
		end
	end, function()
		for _, piece in ipairs(pieces) do
			piece.Part:Destroy()
		end
	end)
end

---------------------------------------------------------------------------
-- Energy pillar: a column of light that shoots up and thins out.
---------------------------------------------------------------------------
--[[ opts: Radius, Height, Color, Color2 (outer sheath), Duration ]]
function TuskVFX.CreateEnergyPillar(position, opts)
	opts = opts or {}
	local radius = opts.Radius or 6
	local height = opts.Height or 60
	local duration = opts.Duration or 0.65
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local core = VFXLib.part({ Shape = Enum.PartType.Cylinder, Color = opts.Color or colors.Ice, Transparency = 0.05, Size = Vector3.new(1, radius, radius), CFrame = CFrame.new(position) * upright })
	local sheath
	if q().RingSegments > 12 then
		sheath = VFXLib.part({ Shape = Enum.PartType.Cylinder, Color = opts.Color2 or colors.Cyan, Material = Enum.Material.ForceField, Transparency = 0.2, Size = Vector3.new(1, radius * 1.6, radius * 1.6), CFrame = CFrame.new(position) * upright })
	end
	VFXLib.animate(duration, function(a)
		local h = 2 + height * VFXLib.easeOut(a)
		local d = radius * (1 - a * 0.7)
		local cf = CFrame.new(position + Vector3.new(0, h / 2, 0)) * upright
		core.Size = Vector3.new(h, d, d)
		core.CFrame = cf
		core.Transparency = 0.05 + 0.95 * a
		if sheath then
			sheath.Size = Vector3.new(h * 0.9, d * 1.7, d * 1.7)
			sheath.CFrame = cf * CFrame.Angles(a * 6, 0, 0)
			sheath.Transparency = 0.2 + 0.8 * a
		end
	end, function()
		core:Destroy()
		if sheath then
			sheath:Destroy()
		end
	end)
end

---------------------------------------------------------------------------
-- Crescent slash: a tapered arc (thin at both tips, thick in the middle)
-- that sweeps across and fades. Lies in cframe's local XZ plane.
---------------------------------------------------------------------------
--[[ opts: Radius, Width, Arc (radians), Sweep (radians turned while alive),
     Color, Color2 (inner edge), Duration ]]
function TuskVFX.CreateCrescent(cframe, opts)
	opts = opts or {}
	if not VFXLib.acquire() then
		return
	end
	local radius = opts.Radius or 2.4
	local width = opts.Width or 0.45
	local arc = opts.Arc or math.rad(150)
	local sweep = opts.Sweep or 1.6
	local duration = opts.Duration or 0.2
	local points = q().RingSegments > 12 and 12 or 7
	local carrier = VFXLib.anchor(cframe)
	local attachments = {}
	for i = 0, points do
		local th = -arc / 2 + arc * i / points
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(math.sin(th) * radius, 0, -math.cos(th) * radius)
		a.Parent = carrier
		attachments[i] = a
	end
	local beams = {}
	local color = ColorSequence.new(opts.Color2 or Color3.new(1, 1, 1), opts.Color or colors.Cyan)
	for i = 1, points do
		local b = Instance.new("Beam")
		b.Attachment0 = attachments[i - 1]
		b.Attachment1 = attachments[i]
		b.Color = color
		b.LightEmission = 1
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Segments = 1
		-- sin profile: 0 at the tips, full width in the middle
		b.Width0 = width * math.sin(math.pi * (i - 1) / points)
		b.Width1 = width * math.sin(math.pi * i / points)
		b.Parent = carrier
		beams[i] = b
	end
	VFXLib.animate(duration, function(a)
		local e = VFXLib.easeOut(a)
		carrier.CFrame = cframe * CFrame.Angles(0, sweep * (0.5 - e), 0)
		local grow = 1 + e * 0.25
		for i = 0, points do
			local th = -arc / 2 + arc * i / points
			attachments[i].Position = Vector3.new(math.sin(th) * radius * grow, 0, -math.cos(th) * radius * grow)
		end
		local fade = NumberSequence.new(math.clamp((a - 0.25) / 0.75, 0, 1))
		for _, b in ipairs(beams) do
			b.Transparency = fade
		end
	end, function()
		carrier:Destroy()
		VFXLib.release()
	end)
end

---------------------------------------------------------------------------
-- Screen tint: darken/tint the world for a cinematic moment, then release.
---------------------------------------------------------------------------
--[[ opts: Brightness (-0.2), Saturation (-0.3), Contrast (0.15),
     Tint (Color3), Release (seconds to hold after duration), FadeOut ]]
function TuskVFX.ScreenTint(duration, opts)
	opts = opts or {}
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SpinScreenTint"
	cc.Parent = game:GetService("Lighting")
	local brightness = opts.Brightness or -0.2
	local saturation = opts.Saturation or -0.3
	local contrast = opts.Contrast or 0.15
	local tint = opts.Tint or Color3.new(1, 1, 1)
	VFXLib.animate(math.max(duration, 0.05), function(a)
		local k = math.min(a * 3, 1)
		cc.Brightness = brightness * k
		cc.Saturation = saturation * k
		cc.Contrast = contrast * k
		cc.TintColor = Color3.new(1, 1, 1):Lerp(tint, k)
	end)
	task.delay(duration + (opts.Release or 0.2), function()
		VFXLib.animate(opts.FadeOut or 0.5, function(a)
			local k = 1 - a
			cc.Brightness = brightness * k
			cc.Saturation = saturation * k
			cc.Contrast = contrast * k
			cc.TintColor = Color3.new(1, 1, 1):Lerp(tint, k)
		end, function()
			cc:Destroy()
		end)
	end)
	return cc
end

-- True if the local camera is within `range` studs of a position.
function TuskVFX.IsNear(position, range)
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude < (range or 80)
end

---------------------------------------------------------------------------
-- Golden ratio: logarithmic spiral and the Golden Rectangle
---------------------------------------------------------------------------
--[[ Golden spiral of beams that turns faster and faster.
     opts: Size, Duration, Color (outer), Color2 (inner/light), Width ]]
function TuskVFX.CreateGoldenSpiral(cframe, opts)
	opts = opts or {}
	local size, duration = opts.Size or 3, opts.Duration or 0.6
	local main, light = opts.Color or colors.Gold, opts.Color2 or colors.GoldLight
	local carrier = VFXLib.anchor(cframe)
	local prev
	local points = q().RingSegments
	for i = 0, points do
		local t = i / points
		local angle = t * math.pi * 4
		local r = size * 0.08 * math.exp(t * 2.5)
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(math.cos(angle) * r, math.sin(angle) * r, 0)
		a.Parent = carrier
		if prev then
			local b = Instance.new("Beam")
			b.Attachment0 = prev
			b.Attachment1 = a
			b.FaceCamera = true
			b.LightEmission = 1
			b.Width0 = opts.Width or 0.18
			b.Width1 = opts.Width or 0.18
			b.Color = ColorSequence.new(light:Lerp(main, t))
			b.Parent = carrier
		end
		prev = a
	end
	VFXLib.animate(duration, function(a, dt)
		carrier.CFrame = carrier.CFrame * CFrame.Angles(0, 0, (dt or 0) * (2 + a * 8))
	end, function()
		carrier:Destroy()
	end)
end

--[[ The Golden Rectangle: nested golden-ratio rectangles with the spiral
     drawn through them, growing in and turning.
     opts: Size, Duration, Color (outer), Color2 (inner/light), Turn (radians) ]]
function TuskVFX.CreateGoldenRectangle(cframe, opts)
	opts = opts or {}
	local size, duration = opts.Size or 3, opts.Duration or 0.8
	local main, light = opts.Color or colors.Gold, opts.Color2 or colors.GoldLight
	local carrier = VFXLib.anchor(cframe)
	local phi = 1.618
	local function line(a, b, width, color)
		local a0 = Instance.new("Attachment")
		a0.Position = a
		a0.Parent = carrier
		local a1 = Instance.new("Attachment")
		a1.Position = b
		a1.Parent = carrier
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Segments = 1
		beam.Width0 = width
		beam.Width1 = width
		beam.Color = ColorSequence.new(color)
		beam.Parent = carrier
	end
	-- Outer rectangle, then squares cut off in turn (left, top, right, bottom...).
	-- Each square gets a quarter circle centred on its inner corner: together
	-- they make the golden spiral.
	local x0, y0, w, h = -size * phi / 2, -size / 2, size * phi, size
	local arcs = {}
	for i = 0, 6 do
		local color = light:Lerp(main, i / 6)
		local width = 0.16 * (1 - i * 0.1)
		line(Vector3.new(x0, y0, 0), Vector3.new(x0 + w, y0, 0), width, color)
		line(Vector3.new(x0 + w, y0, 0), Vector3.new(x0 + w, y0 + h, 0), width, color)
		line(Vector3.new(x0 + w, y0 + h, 0), Vector3.new(x0, y0 + h, 0), width, color)
		line(Vector3.new(x0, y0 + h, 0), Vector3.new(x0, y0, 0), width, color)
		local side = i % 4
		if side == 0 then -- square on the left
			local sq = h
			table.insert(arcs, { x0 + sq, y0, sq, math.pi, math.pi / 2 })
			x0, w = x0 + sq, w - sq
		elseif side == 1 then -- square on top
			local sq = w
			table.insert(arcs, { x0, y0 + h - sq, sq, math.pi / 2, 0 })
			h = h - sq
		elseif side == 2 then -- square on the right
			local sq = h
			table.insert(arcs, { x0 + w - sq, y0 + h, sq, 0, -math.pi / 2 })
			w = w - sq
		else -- square on the bottom
			local sq = w
			table.insert(arcs, { x0 + w, y0 + sq, sq, -math.pi / 2, -math.pi })
			y0, h = y0 + sq, h - sq
		end
	end
	local prev
	for _, arc in ipairs(arcs) do
		for k = 0, 5 do
			local angle = arc[4] + (arc[5] - arc[4]) * k / 5
			local p = Vector3.new(arc[1] + math.cos(angle) * arc[3], arc[2] + math.sin(angle) * arc[3], -0.05)
			if prev then
				line(prev, p, 0.22, light)
			end
			prev = p
		end
	end
	VFXLib.animate(duration, function(a, dt)
		local grow = VFXLib.easeOut(math.min(a * 2.5, 1))
		carrier.CFrame = cframe * CFrame.Angles(0, 0, a * (opts.Turn or math.pi * 0.6))
		for _, child in ipairs(carrier:GetChildren()) do
			if child:IsA("Beam") then
				child.Transparency = NumberSequence.new(math.clamp(1 - grow + math.max(0, a - 0.85) / 0.15, 0, 1))
			end
		end
	end, function()
		carrier:Destroy()
	end)
end


return TuskVFX
end
end
