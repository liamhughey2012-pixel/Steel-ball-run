---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › UI"
updated: 2026-11-22
---
# UITheme

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| **Exact name** | `UITheme` (capitals matter) |

**What it does:** The house style, taken from the bounty board, so every screen matches: dark wood frames with planks, grain, nails and metal corner brackets; aged parchment with burnt edges; Bangers titles; gold, red and green accents; chunky dark strokes; buttons that pop when you hover or press.

## How to add it
1. In Studio's Explorer, find **UI** (StarterPlayer › StarterPlayerScripts › SpinClient › UI).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **UITheme**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	UITheme  (StarterPlayerScripts.SpinClient.UI.UITheme)

	The house style, taken from the bounty board, so every screen matches:
	dark wood frames with planks, grain, nails and metal corner brackets;
	aged parchment with burnt edges; Bangers titles; gold, red and green
	accents; chunky dark strokes; buttons that pop when you hover or press.

	Colours: UITheme.C (WOOD, WOOD_DARK, WOOD_LIGHT, WOOD_EDGE, PAPER,
	PAPER_DARK, INK, BURNT, RED, GREEN, GOLD, BRASS, NAIL, STEEL, SHADOW).
	Fonts:   UITheme.Font (Title = Bangers, Heavy = GothamBlack,
	Body = GothamBold, Plain = GothamMedium).

	Helpers (each returns the instance it makes):
	  new(class, props, parent)          make an instance with properties
	  corner(p, radius) / stroke(p, color, thickness, transparency)
	  label(parent, props)               a scaled text label (ink by default)
	  wood(frame, opts)                  turn a frame into a framed wooden
	                                     board: returns the inner plank area.
	                                     opts: Planks (rows), Brackets (bool),
	                                     Nails (bool), Border (px), Radius
	  paper(frame, opts)                 aged parchment: gradient + burnt edge
	  sign(parent, title, subtitle, props) a hanging wooden title sign
	  button(parent, text, color, props) a chunky button that pops on hover
	  chip(parent, text, color, props)   a small rounded tag
	  bar(parent, color, props)          a wood-framed meter; returns
	                                     frame, fill (set fill.Size X scale)
	  pop(guiObject, from)               bounce something in (needs a UIScale)
	  hover(button, scaleTo)             hover/press bounce on any button
]]

local TweenService = game:GetService("TweenService")

local UITheme = {}

local C = {
	WOOD = Color3.fromRGB(112, 74, 44),
	WOOD_DARK = Color3.fromRGB(78, 50, 30),
	WOOD_LIGHT = Color3.fromRGB(134, 90, 56),
	WOOD_MID = Color3.fromRGB(122, 82, 50),
	WOOD_EDGE = Color3.fromRGB(45, 28, 16),
	GRAIN = Color3.fromRGB(78, 50, 30),
	PAPER = Color3.fromRGB(234, 205, 160),
	PAPER_DARK = Color3.fromRGB(205, 172, 125),
	INK = Color3.fromRGB(60, 36, 20),
	BURNT = Color3.fromRGB(120, 78, 40),
	RED = Color3.fromRGB(190, 40, 35),
	GREEN = Color3.fromRGB(60, 150, 70),
	GOLD = Color3.fromRGB(255, 205, 90),
	GLOW = Color3.fromRGB(255, 214, 110),
	BRASS = Color3.fromRGB(196, 160, 90),
	NAIL = Color3.fromRGB(70, 70, 76),
	STEEL = Color3.fromRGB(90, 92, 100),
	STEEL_DARK = Color3.fromRGB(40, 40, 46),
	SHADOW = Color3.fromRGB(30, 18, 10),
	WHITE = Color3.new(1, 1, 1),
}
UITheme.C = C

UITheme.Font = {
	Title = Enum.Font.Bangers,
	Heavy = Enum.Font.GothamBlack,
	Body = Enum.Font.GothamBold,
	Plain = Enum.Font.GothamMedium,
}

UITheme.FAST = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
UITheme.SOFT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function UITheme.new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local new = UITheme.new

function UITheme.corner(p, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 6) }, p)
end

function UITheme.stroke(p, color, thickness, transparency)
	return new("UIStroke", { Color = color or C.WOOD_EDGE, Thickness = thickness or 2, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end

function UITheme.label(parent, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, TextColor3 = C.INK, Font = UITheme.Font.Heavy, TextScaled = true }, parent)
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end

-- Turn `frame` into a framed wooden board. Returns the inner plank area
-- (put content in there, or on top of `frame` with a higher ZIndex).
function UITheme.wood(frame, opts)
	opts = opts or {}
	local border = opts.Border or 6
	local radius = opts.Radius or 8
	local z = frame.ZIndex
	frame.BackgroundColor3 = C.WOOD_DARK
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	UITheme.corner(frame, radius)
	UITheme.stroke(frame, C.WOOD_EDGE, opts.Stroke or 3)
	local inner = new("Frame", { Name = "Planks", BackgroundColor3 = C.WOOD, BorderSizePixel = 0, Position = UDim2.fromOffset(border, border), Size = UDim2.new(1, -border * 2, 1, -border * 2), ClipsDescendants = true, ZIndex = z }, frame)
	UITheme.corner(inner, math.max(radius - 3, 2))
	local rows = opts.Planks or 3
	local tones = { C.WOOD_LIGHT, C.WOOD, C.WOOD_MID }
	for i = 0, rows - 1 do
		local plank = new("Frame", { BackgroundColor3 = tones[i % 3 + 1], BorderSizePixel = 0, Position = UDim2.fromScale(0, i / rows), Size = UDim2.new(1, 0, 1 / rows, 0), ZIndex = z }, inner)
		-- Grain lines that fade at their ends, and a dark seam under each plank.
		for g = 1, 2 do
			local line = new("Frame", { BackgroundColor3 = C.GRAIN, BorderSizePixel = 0, BackgroundTransparency = 0.6, Position = UDim2.new(((i * 7 + g * 13) % 10) / 20, 0, 0.25 + g * 0.22, 0), Size = UDim2.new(0.5 + ((i + g) % 4) * 0.1, 0, 0, 2), ZIndex = z }, plank)
			new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0), NumberSequenceKeypoint.new(0.7, 0), NumberSequenceKeypoint.new(1, 1) }) }, line)
		end
		if i < rows - 1 then
			new("Frame", { BackgroundColor3 = Color3.fromRGB(50, 32, 18), BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 2), ZIndex = z }, plank)
		end
		if opts.Nails ~= false then
			for _, x in ipairs({ 0, 1 }) do
				local nail = new("Frame", { BackgroundColor3 = C.NAIL, AnchorPoint = Vector2.new(x, 0.5), Position = UDim2.new(x, x == 0 and 5 or -5, 0.5, 0), Size = UDim2.fromOffset(4, 4), ZIndex = z }, plank)
				UITheme.corner(nail, 99)
			end
		end
	end
	-- Dark edges over the planks.
	local shade = new("Frame", { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = z }, inner)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.18, 1), NumberSequenceKeypoint.new(0.82, 1), NumberSequenceKeypoint.new(1, 0.6) }), Rotation = opts.ShadeRotation or 0 }, shade)
	if opts.Brackets then
		local size = opts.BracketSize or 18
		for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
			local bracket = new("Frame", { Name = "Bracket", AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.fromOffset(size, size), BackgroundColor3 = C.STEEL, ZIndex = z + 2 }, frame)
			UITheme.corner(bracket, 4)
			UITheme.stroke(bracket, C.STEEL_DARK, 2)
			local bolt = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(math.max(4, size * 0.28), math.max(4, size * 0.28)), BackgroundColor3 = Color3.fromRGB(170, 172, 180), ZIndex = z + 2 }, bracket)
			UITheme.corner(bolt, 99)
		end
	end
	return inner
end

-- Aged parchment: lighter middle, browner edges, a burnt border.
function UITheme.paper(frame, opts)
	opts = opts or {}
	frame.BackgroundColor3 = C.PAPER
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	UITheme.corner(frame, opts.Radius or 4)
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.PAPER_DARK), ColorSequenceKeypoint.new(0.38, C.PAPER), ColorSequenceKeypoint.new(1, C.PAPER_DARK) }), Rotation = opts.Rotation or 70 }, frame)
	UITheme.stroke(frame, C.BURNT, opts.Stroke or 2, 0.2)
	return frame
end

-- A hanging wooden title sign with ropes.
function UITheme.sign(parent, title, subtitle, props)
	local sign = new("Frame", { Name = "Sign", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(240, 44) }, parent)
	for k, v in pairs(props or {}) do
		sign[k] = v
	end
	local z = sign.ZIndex
	UITheme.wood(sign, { Planks = 1, Border = 3, Radius = 6, Nails = true })
	UITheme.label(sign, { Name = "Title", Size = UDim2.new(1, 0, subtitle and 0.72 or 1, 0), Text = title, Font = UITheme.Font.Title, TextColor3 = C.PAPER, TextStrokeTransparency = 0.4, ZIndex = z + 1 })
	if subtitle then
		UITheme.label(sign, { Name = "Subtitle", Position = UDim2.fromScale(0, 0.68), Size = UDim2.fromScale(1, 0.26), Text = subtitle, Font = UITheme.Font.Body, TextColor3 = C.GOLD, ZIndex = z + 1 })
	end
	return sign
end

-- Hover / press bounce on any button (adds a UIScale if it has none).
function UITheme.hover(b, scaleTo)
	local s = b:FindFirstChildOfClass("UIScale") or new("UIScale", { Scale = 1 }, b)
	b.MouseEnter:Connect(function()
		TweenService:Create(s, UITheme.FAST, { Scale = scaleTo or 1.06 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(s, UITheme.SOFT, { Scale = 1 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(s, UITheme.SOFT, { Scale = 0.94 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(s, UITheme.FAST, { Scale = scaleTo or 1.06 }):Play()
	end)
	return s
end

-- A chunky button: bold colour, dark stroke, Bangers text, pops on hover.
function UITheme.button(parent, text, color, props)
	color = color or C.RED
	local b = new("TextButton", { AutoButtonColor = false, BackgroundColor3 = color, Text = text, Font = UITheme.Font.Title, TextScaled = true, TextColor3 = C.WHITE, TextStrokeTransparency = 0.6 }, parent)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	UITheme.corner(b, 8)
	UITheme.stroke(b, color:Lerp(Color3.new(0, 0, 0), 0.45), 2)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)), Rotation = 90 }, b)
	new("UIPadding", { PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	UITheme.hover(b)
	return b
end

-- A small rounded tag.
function UITheme.chip(parent, text, color, props)
	color = color or C.GOLD
	local f = new("Frame", { BackgroundColor3 = color, Size = UDim2.fromOffset(80, 22) }, parent)
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	UITheme.corner(f, 6)
	UITheme.stroke(f, color:Lerp(Color3.new(0, 0, 0), 0.5), 2)
	local light = (color.R * 0.3 + color.G * 0.59 + color.B * 0.11) > 0.55
	UITheme.label(f, { Name = "Text", Size = UDim2.fromScale(1, 1), Text = text, Font = UITheme.Font.Title, TextColor3 = light and C.INK or C.WHITE, ZIndex = f.ZIndex })
	new("UIPadding", { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, f)
	return f
end

-- A wood-framed meter. Returns the frame and the fill (size its X scale 0..1).
function UITheme.bar(parent, color, props)
	local frame = new("Frame", { Name = "Bar", BackgroundColor3 = C.WOOD_DARK, Size = UDim2.fromOffset(200, 16) }, parent)
	for k, v in pairs(props or {}) do
		frame[k] = v
	end
	local z = frame.ZIndex
	UITheme.corner(frame, 5)
	UITheme.stroke(frame, C.WOOD_EDGE, 2)
	local well = new("Frame", { Name = "Well", BackgroundColor3 = C.SHADOW, BorderSizePixel = 0, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), ClipsDescendants = true, ZIndex = z }, frame)
	UITheme.corner(well, 3)
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = color or C.GREEN, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = z }, well)
	UITheme.corner(fill, 3)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)), Rotation = 90 }, fill)
	-- A shine along the top.
	new("Frame", { Name = "Shine", BackgroundColor3 = C.WHITE, BackgroundTransparency = 0.75, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0.35, 0), ZIndex = z }, fill)
	return frame, fill
end

-- Bounce something in from `from` (default 0.6) to full size.
function UITheme.pop(obj, from)
	local s = obj:FindFirstChildOfClass("UIScale") or new("UIScale", { Scale = 1 }, obj)
	s.Scale = from or 0.6
	TweenService:Create(s, UITheme.FAST, { Scale = 1 }):Play()
	return s
end

return UITheme
```
