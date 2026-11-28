--[[
	CorpseClient  (StarterPlayerScripts.SpinClient.CorpseClient)

	Client side of the SAINT'S CORPSE (server: CorpseService, CorpseMoves).
	  * the relics float, turn and bob (tag "SpinCorpse")
	  * a panel in the bottom-left corner while you hold parts, in the bounty
	    board's style (UI.UITheme): a framed wooden board with steel corner
	    brackets, a parchment strip per part with its boost, and your chunky
	    red CORPSE MOVE button (V / D-pad right, or tap it; bounces on hover)
	    with its cooldown shade
	  * announcements: you took a part (big outlined gold Bangers), someone
	    else took one or a part fell where someone died (a nailed parchment
	    ribbon at the top)
	  * the relic compass's distance sits on a little wooden plaque
	  * the visuals for every character's corpse move, with its name popping
	    up over the caster
	  * the COMPLETE corpse: a server-wide announcement, a gold halo over the
	    holder, the board's frame turns gold and V is THE SAINT'S MIRACLE (golden sky,
	    a giant halo, pillars of light on every enemy, a final blast)
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)
local TuskVFX = require(script.Parent.TuskVFX)
local CameraFX = require(script.Parent.CameraFX)
local UITheme = require(script.Parent.UI.UITheme)
local Common = require(script.Parent.TuskActCommon)
local TuskAnimation = require(script.Parent.TuskAnimation)

local CorpseClient = {}

local player = Players.LocalPlayer
local cfg
local T = UITheme.C
local GOLD = T.GOLD
local INK = T.INK
local MOVE_RED = T.RED -- the corpse move button
local MOVE_GOLD = Color3.fromRGB(226, 182, 70) -- ... once the corpse is complete
local partInfo = {}

local gui, panel, panelTitle, list, moveButton, moveName, moveFill, moveTime, feed, feedText, banner
local shown = "" -- the parts string the panel was built for

---------------------------------------------------------------------------
-- Small UI helpers
---------------------------------------------------------------------------
local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do
		i[k] = v
	end
	i.Parent = parent
	return i
end

local function corner(p, r)
	new("UICorner", { CornerRadius = UDim.new(0, r) }, p)
end

local function label(parent, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left }, parent)
	for k, v in pairs(props) do
		l[k] = v
	end
	return l
end

-- A chunky dark outline round text (UIStroke on the glyphs) with a
-- light-to-shade gradient, like the bounty board's banners.
local function inkOutline(l, thickness)
	l.TextStrokeTransparency = 1
	local stroke = new("UIStroke", { Color = T.WOOD_EDGE, Thickness = thickness or 2, LineJoinMode = Enum.LineJoinMode.Round }, l)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 205, 190)), Rotation = 90 }, l)
	return stroke
end

-- Recolour a chunky button (fill + its darker edge).
local function tintButton(b, color)
	b.BackgroundColor3 = color
	local edge = b:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = color:Lerp(Color3.new(0, 0, 0), 0.45)
	end
end

local function myCharacterName()
	local c = player.Character
	local act = c and c:GetAttribute("TuskAct")
	return act and Registry.characterOf(act) or nil
end

local function aim()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return nil
	end
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch or string.find(last.Name, "Gamepad") then
		return camera.CFrame.LookVector
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, VFXLib.Folder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local target = hit and hit.Position or ray.Origin + ray.Direction * 600
	local dir = target - root.Position
	return dir.Magnitude > 1 and dir.Unit or root.CFrame.LookVector
end

local function useMove()
	local c = player.Character
	if not c or not c:GetAttribute("CorpseParts") then
		return
	end
	Net.get("TuskRequest"):FireServer("CorpseMove", aim())
end

---------------------------------------------------------------------------
-- The panel (left side, while you hold parts)
---------------------------------------------------------------------------
local PANEL_W = 200
local HINT_TEXT = "Hover a part for its boost"
local panelHint

local function rebuildPanel(parts)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local ids = {}
	for id in string.gmatch(parts, "[^,]+") do
		table.insert(ids, id)
	end
	for i, id in ipairs(ids) do
		local info = partInfo[id]
		-- Each part: a small parchment tag with a brass relic diamond (two
		-- columns). Hover / tap it to see its boost on the line under the title.
		local row = new("TextButton", { LayoutOrder = i, Text = "", AutoButtonColor = false, ZIndex = 3 }, list)
		UITheme.paper(row, { Radius = 3, Stroke = 1.5 })
		local icon = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = T.BRASS, Rotation = 45, ZIndex = 4 }, row)
		new("UIStroke", { Color = T.INK, Thickness = 1 }, icon)
		label(row, { Position = UDim2.fromOffset(19, 1), Size = UDim2.new(1, -22, 1, -2), Text = info and info.Name or id, Font = UITheme.Font.Title, TextColor3 = T.INK, ZIndex = 4 })
		local boost = (info and info.Name or id) .. ": " .. (info and info.Text or "")
		local function showBoost()
			panelHint.Text = boost
			panelHint.TextColor3 = GOLD
		end
		local function hideBoost()
			panelHint.Text = HINT_TEXT
			panelHint.TextColor3 = T.PAPER_DARK
		end
		row.MouseEnter:Connect(showBoost)
		row.MouseLeave:Connect(hideBoost)
		row.Activated:Connect(function()
			if panelHint.Text == boost then
				hideBoost()
			else
				showBoost()
			end
		end)
	end
	local rows = math.ceil(#ids / 2)
	panel.Size = UDim2.fromOffset(PANEL_W, 40 + rows * 22 + 42)
	local who = myCharacterName()
	local complete = #ids >= #cfg.Parts
	if complete then
		who = "Miracle"
	end
	moveName.Text = (cfg.MoveNames and who and cfg.MoveNames[who]) or "CORPSE MOVE"
	-- The complete corpse: the board's frame and edge turn gold.
	panel.BackgroundColor3 = complete and T.BRASS or T.WOOD_DARK
	local edge = panel:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = complete and GOLD or T.WOOD_EDGE
		edge.Thickness = complete and 4 or 3
	end
	tintButton(moveButton, complete and MOVE_GOLD or MOVE_RED)
	panelTitle.Text = complete and "COMPLETE SAINT'S CORPSE" or "SAINT'S CORPSE"
end

local function buildUI()
	gui = new("ScreenGui", { Name = "CorpseHUD", ResetOnSpawn = false, DisplayOrder = 4, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
	-- Bottom-left corner (lifted above the thumbstick on touch screens): a
	-- framed wooden board, a parchment strip per part, the move button.
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	panel = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, touch and -230 or -12), Size = UDim2.fromOffset(PANEL_W, 104), Visible = false }, gui)
	UITheme.wood(panel, { Planks = 3, Border = 4, Brackets = true, BracketSize = 11 })
	panelTitle = label(panel, { Position = UDim2.fromOffset(11, 5), Size = UDim2.new(1, -22, 0, 18), Text = "SAINT'S CORPSE", Font = UITheme.Font.Title, TextColor3 = GOLD, TextStrokeColor3 = T.WOOD_EDGE, TextStrokeTransparency = 0.4, ZIndex = 3 })
	panelHint = label(panel, { Position = UDim2.fromOffset(11, 23), Size = UDim2.new(1, -22, 0, 11), Text = HINT_TEXT, Font = Enum.Font.GothamBold, TextColor3 = T.PAPER_DARK, ZIndex = 3 })
	list = new("Frame", { Name = "List", Position = UDim2.fromOffset(8, 38), Size = UDim2.new(1, -16, 1, -82), BackgroundTransparency = 1, ZIndex = 3 }, panel)
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -2, 0, 19), CellPadding = UDim2.fromOffset(4, 3), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	-- The corpse move: a chunky button (bounces on hover / press) with a
	-- cooldown shade sweeping over it.
	moveButton = new("TextButton", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -8), Size = UDim2.new(1, -20, 0, 32), BackgroundColor3 = MOVE_RED, Text = "", AutoButtonColor = false, ClipsDescendants = false, ZIndex = 3 }, panel)
	corner(moveButton, 8)
	new("UIStroke", { Color = MOVE_RED:Lerp(Color3.new(0, 0, 0), 0.45), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, moveButton)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)), Rotation = 90 }, moveButton)
	UITheme.hover(moveButton, 1.04)
	moveFill = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, ZIndex = 4 }, moveButton)
	corner(moveFill, 8)
	-- The key: a little dark plank with a gold V.
	local key = new("Frame", { Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = T.WOOD_DARK, ZIndex = 5 }, moveButton)
	corner(key, 6)
	new("UIStroke", { Color = GOLD, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, key)
	label(key, { Size = UDim2.fromScale(1, 1), Text = "V", Font = UITheme.Font.Title, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
	moveName = label(moveButton, { Position = UDim2.fromOffset(33, 4), Size = UDim2.new(1, -76, 0, 24), Text = "", Font = UITheme.Font.Title, TextStrokeColor3 = T.WOOD_EDGE, TextStrokeTransparency = 0.3, ZIndex = 5 })
	new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 9 }, moveName)
	moveTime = label(moveButton, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 5), Size = UDim2.fromOffset(34, 22), Text = "", Font = UITheme.Font.Title, TextColor3 = GOLD, TextStrokeColor3 = T.WOOD_EDGE, TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 })
	moveButton.Activated:Connect(useMove)
	-- Announcements: a parchment ribbon at the top that fits its line...
	feed = new("Frame", { Name = "Feed", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 118), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, Visible = false }, gui)
	UITheme.paper(feed, { Radius = 4 })
	new("UISizeConstraint", { MaxSize = Vector2.new(560, 26) }, feed)
	new("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22) }, feed)
	for _, x in ipairs({ 0, 1 }) do
		local nail = new("Frame", { AnchorPoint = Vector2.new(x, 0.5), Position = UDim2.new(x, x == 0 and -14 or 14, 0.5, 0), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = T.NAIL, ZIndex = 2 }, feed)
		corner(nail, 99)
	end
	feedText = label(feed, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextScaled = false, TextSize = 15, Text = "", Font = Enum.Font.GothamBold, TextColor3 = T.INK, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2 })
	new("UISizeConstraint", { MaxSize = Vector2.new(516, 26) }, feedText)
	-- ... and a big outlined gold banner.
	banner = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(620, 70), Text = "", Font = UITheme.Font.Title, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, Visible = false })
	inkOutline(banner, 3)
end

local feedToken, bannerToken
local function showFeed(text)
	feedText.Text = text
	feed.Visible = true
	UITheme.pop(feed, 0.85)
	local token = {}
	feedToken = token
	task.delay(3.5, function()
		if feedToken == token then
			feed.Visible = false
		end
	end)
end

local function showBanner(text)
	banner.Text = text
	banner.Visible = true
	local token = {}
	bannerToken = token
	VFXLib.animate(0.25, function(a)
		banner.Size = UDim2.fromOffset(620 * (0.6 + 0.4 * a), 70 * (0.6 + 0.4 * a))
	end)
	task.delay(3, function()
		if bannerToken == token then
			banner.Visible = false
		end
	end)
end

local function stepPanel()
	local c = player.Character
	local parts = c and c:GetAttribute("CorpseParts") or ""
	panel.Visible = parts ~= ""
	if parts ~= shown then
		shown = parts
		if parts ~= "" then
			rebuildPanel(parts)
		end
	end
	if parts ~= "" then
		local left = math.max(0, (c:GetAttribute("CorpseReadyAt") or 0) - workspace:GetServerTimeNow())
		local total = cfg.Move and cfg.Move.Cooldown or 20
		moveFill.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
		moveTime.Text = left > 0 and tostring(math.ceil(left)) or ""
	end
end

---------------------------------------------------------------------------
-- Relics: float, turn and bob
---------------------------------------------------------------------------
local relicBase = setmetatable({}, { __mode = "k" }) -- [part] = original CFrame

local function stepRelics(now)
	for _, model in ipairs(CollectionService:GetTagged("SpinCorpse")) do
		local holder = model.PrimaryPart
		if holder then
			local center = holder.Position
			local turn = CFrame.new(center) * CFrame.new(0, math.sin(now * 2 + center.X) * 0.4, 0) * CFrame.Angles(0, now * 1.2, 0) * CFrame.new(-center)
			for _, p in ipairs(model:GetChildren()) do
				if p:IsA("BasePart") and p ~= holder and p.Name ~= "Beam" then
					relicBase[p] = relicBase[p] or p.CFrame
					p.CFrame = turn * relicBase[p]
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Corpse move visuals
---------------------------------------------------------------------------
local function paletteOf(who)
	local act = Registry.StartAct[who] or 1
	return Common.palette(act)
end

-- The move's name pops up over the caster.
local function callout(character, who)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = new("BillboardGui", { Adornee = head, Size = UDim2.fromOffset(240, 40), StudsOffset = Vector3.new(0, 3.4, 0), AlwaysOnTop = true, LightInfluence = 0 }, VFXLib.Folder)
	local l = label(bb, { Size = UDim2.fromScale(1, 1), Text = (cfg.MoveNames and cfg.MoveNames[who] or "CORPSE MOVE") .. "!", Font = Enum.Font.Bangers, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center })
	local outline = inkOutline(l, 3)
	VFXLib.animate(1.3, function(a)
		bb.StudsOffset = Vector3.new(0, 3.4 + a * 1.2, 0)
		l.TextTransparency = math.max(0, (a - 0.6) / 0.4)
		outline.Transparency = l.TextTransparency
	end, function()
		bb:Destroy()
	end)
end

local function ring(position, radius, color, time)
	local p = VFXLib.part({ Size = Vector3.new(0.5, 1, 1), Color = color, Material = Enum.Material.Neon, Transparency = 0.2, Shape = Enum.PartType.Cylinder })
	VFXLib.animate(time or 0.4, function(a)
		p.Size = Vector3.new(0.5, radius * 2 * a, radius * 2 * a)
		p.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		p.Transparency = 0.2 + 0.8 * a
	end, function()
		p:Destroy()
	end)
end

local function streak(from, to, color, width, time)
	local p = VFXLib.part({ Size = Vector3.new(width or 0.4, width or 0.4, (to - from).Magnitude), CFrame = CFrame.lookAt((from + to) / 2, to), Color = color, Material = Enum.Material.Neon, Transparency = 0.2 })
	VFXLib.animate(time or 0.3, function(a)
		p.Transparency = 0.2 + 0.8 * a
	end, function()
		p:Destroy()
	end)
end

-- A shell round someone for a while (cocoon / light).
---------------------------------------------------------------------------
-- Diego's six-shooter: a proper revolver, built in gun space (origin at the
-- grip, barrel along -Z, top along +Y) and held in his right hand.
---------------------------------------------------------------------------
local revolvers = setmetatable({}, { __mode = "k" }) -- [character] = gun while it's out
local drawRevolver
local STEEL = Color3.fromRGB(64, 66, 76)
local STEEL_LIGHT = Color3.fromRGB(150, 154, 166)
local WOOD = Color3.fromRGB(132, 80, 42)
local WOOD_DARK = Color3.fromRGB(92, 54, 28)
local BRASS = Color3.fromRGB(214, 176, 90)
local CYL_CENTER = Vector3.new(0, 0.42, -0.5)

local function buildRevolver()
	local pieces = {}
	local function add(size, cf, color, material, shape, cylinderPart)
		local p = VFXLib.part({ Size = size, Color = color, Material = material or Enum.Material.Metal })
		if shape then
			p.Shape = shape
		end
		table.insert(pieces, { Part = p, Offset = cf, Cylinder = cylinderPart })
		return p
	end
	local alongZ = CFrame.Angles(0, math.pi / 2, 0) -- turns a cylinder's axis from X onto Z
	-- Grip: curved wood with darker panels and a steel butt cap.
	add(Vector3.new(0.24, 0.62, 0.32), CFrame.new(0, -0.06, 0.14) * CFrame.Angles(-0.32, 0, 0), WOOD, Enum.Material.Wood)
	for _, side in ipairs({ -1, 1 }) do
		add(Vector3.new(0.03, 0.46, 0.22), CFrame.new(side * 0.13, -0.08, 0.15) * CFrame.Angles(-0.32, 0, 0), WOOD_DARK, Enum.Material.Wood)
	end
	add(Vector3.new(0.26, 0.08, 0.34), CFrame.new(0, -0.38, 0.26) * CFrame.Angles(-0.32, 0, 0), STEEL)
	-- Frame, top strap, hammer with its spur.
	add(Vector3.new(0.22, 0.36, 0.62), CFrame.new(0, 0.36, -0.12), STEEL)
	add(Vector3.new(0.16, 0.08, 0.78), CFrame.new(0, 0.6, -0.36), STEEL_LIGHT)
	add(Vector3.new(0.08, 0.2, 0.1), CFrame.new(0, 0.64, 0.16) * CFrame.Angles(-0.5, 0, 0), STEEL)
	add(Vector3.new(0.1, 0.05, 0.14), CFrame.new(0, 0.74, 0.24) * CFrame.Angles(-0.2, 0, 0), STEEL_LIGHT)
	-- Trigger and trigger guard.
	add(Vector3.new(0.05, 0.16, 0.05), CFrame.new(0, 0.12, -0.2) * CFrame.Angles(0.3, 0, 0), BRASS)
	add(Vector3.new(0.07, 0.05, 0.38), CFrame.new(0, -0.03, -0.22), STEEL)
	add(Vector3.new(0.07, 0.22, 0.05), CFrame.new(0, 0.07, -0.42), STEEL)
	-- The cylinder: a fat drum with six chambers on its face and flutes.
	add(Vector3.new(0.5, 0.5, 0.5), CFrame.new(CYL_CENTER) * alongZ, STEEL_LIGHT, Enum.Material.Metal, Enum.PartType.Cylinder, true)
	add(Vector3.new(0.52, 0.42, 0.42), CFrame.new(CYL_CENTER) * alongZ, STEEL, Enum.Material.Metal, Enum.PartType.Cylinder, true)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local off = Vector3.new(math.cos(a) * 0.15, math.sin(a) * 0.15, 0)
		add(Vector3.new(0.06, 0.11, 0.11), CFrame.new(CYL_CENTER + off + Vector3.new(0, 0, -0.25)) * alongZ, Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, true)
		local flute = Vector3.new(math.cos(a + math.pi / 6) * 0.25, math.sin(a + math.pi / 6) * 0.25, 0)
		add(Vector3.new(0.05, 0.05, 0.36), CFrame.new(CYL_CENTER + flute), STEEL, Enum.Material.Metal, nil, true)
	end
	-- An octagonal barrel (two square bars, one turned 45 degrees), the
	-- ejector rod under it, a front sight and a dark muzzle.
	add(Vector3.new(0.16, 0.16, 1.3), CFrame.new(0, 0.5, -1.38), STEEL)
	add(Vector3.new(0.16, 0.16, 1.3), CFrame.new(0, 0.5, -1.38) * CFrame.Angles(0, 0, math.pi / 4), STEEL)
	add(Vector3.new(0.06, 0.06, 0.95), CFrame.new(0, 0.34, -1.2), STEEL_LIGHT)
	add(Vector3.new(0.1, 0.1, 0.22), CFrame.new(0, 0.34, -1.62), STEEL)
	add(Vector3.new(0.04, 0.09, 0.12), CFrame.new(0, 0.62, -1.96), BRASS)
	add(Vector3.new(0.04, 0.17, 0.17), CFrame.new(0, 0.5, -2.04) * alongZ, Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	return pieces
end

drawRevolver = function(character, data)
	local old = revolvers[character]
	if old then
		old.Done()
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then
		return
	end
	local pieces = buildRevolver()
	local gun = { Spin = 0, Kick = -1, Start = os.clock() }
	local drawT = data.Draw or 0.35
	local twirlAt = drawT + (data.Shots or 6) * (data.Every or 0.14) + 0.1
	local total = data.Time or (twirlAt + 0.5)
	local function gunCF()
		local t = os.clock() - gun.Start
		-- Held by the grip, barrel along the hand's pointing direction.
		local grip = (hand.Name == "Right Arm") and hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 + 0.1, 0) or hand.CFrame
		local cf = grip * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.new(0, 0.1, 0.05)
		-- Drawn: it swings up from pointing down.
		if t < drawT then
			cf = cf * CFrame.Angles(-(1 - t / drawT) * 1.6, 0, 0)
		end
		-- Recoil: the barrel kicks up and settles.
		local k = math.max(0, 1 - (os.clock() - gun.Kick) / 0.1)
		cf = cf * CFrame.Angles(k * 0.35, 0, 0)
		-- Twirl round the trigger guard, then it's holstered.
		if t > twirlAt then
			local a = math.min((t - twirlAt) / 0.4, 1)
			cf = cf * CFrame.new(0, 0.05, -0.3) * CFrame.Angles(a * math.pi * 4, 0, 0) * CFrame.new(0, -0.05, 0.3)
		end
		return cf
	end
	gun.Muzzle = function()
		return (gunCF() * CFrame.new(0, 0.5, -2.1)).Position
	end
	local job
	gun.Done = function()
		if revolvers[character] == gun then
			revolvers[character] = nil
		end
		VFXLib.cancel(job)
		for _, e in ipairs(pieces) do
			e.Part:Destroy()
		end
	end
	revolvers[character] = gun
	job = VFXLib.animate(total, function()
		if not hand.Parent then
			return
		end
		local cf = gunCF()
		local spin = CFrame.new(CYL_CENTER) * CFrame.Angles(0, 0, gun.Spin) * CFrame.new(-CYL_CENTER)
		local t = os.clock() - gun.Start
		local fadeOut = math.clamp((t - (total - 0.15)) / 0.15, 0, 1)
		for _, e in ipairs(pieces) do
			e.Part.CFrame = cf * (e.Cylinder and spin * e.Offset or e.Offset)
			e.Part.Transparency = fadeOut
		end
	end, gun.Done)
end

local function shell(character, color, material, time)
	local p = VFXLib.part({ Size = Vector3.new(5, 7, 5), Color = color, Material = material, Transparency = 0.3 })
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local r = Common.rootOf(character)
		local t = os.clock() - start
		if not r or t > time then
			conn:Disconnect()
			p:Destroy()
			return
		end
		p.CFrame = r.CFrame * CFrame.Angles(0, t * 2, 0)
		p.Size = Vector3.new(5, 7, 5) * (1 + math.sin(t * 8) * 0.03)
	end)
end

---------------------------------------------------------------------------
-- The complete corpse: a gold halo over whoever holds all of it
---------------------------------------------------------------------------
local halos = {} -- [character] = { Ring, Light }

local function stepHalos(now)
	local seen = {}
	local candidates = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(candidates, p.Character)
		end
	end
	for _, m in ipairs(CollectionService:GetTagged("SpinFighter")) do
		table.insert(candidates, m)
	end
	for _, character in ipairs(candidates) do
		local head = character.Parent and character:GetAttribute("CorpseComplete") and character:FindFirstChild("Head")
		if head then
			seen[character] = true
			local h = halos[character]
			if not h then
				local ring = VFXLib.part({ Size = Vector3.new(0.15, 2.6, 2.6), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.15, Shape = Enum.PartType.Cylinder })
				local light = Instance.new("PointLight")
				light.Color = GOLD
				light.Range = 16
				light.Brightness = 2
				light.Parent = ring
				h = { Ring = ring }
				halos[character] = h
			end
			h.Ring.CFrame = CFrame.new(head.Position + Vector3.new(0, 1.6 + math.sin(now * 2) * 0.1, 0)) * CFrame.Angles(0, now, math.pi / 2)
			if math.random() < 0.15 then
				VFXLib.burst(head.Position - Vector3.new(0, 2, 0), { Count = 2, Color = GOLD, Speed = 4, Lifetime = 0.8, Direction = Vector3.new(0, 1, 0), Spread = 40 })
			end
		end
	end
	for character, h in pairs(halos) do
		if not seen[character] then
			halos[character] = nil
			h.Ring:Destroy()
		end
	end
end

-- THE SAINT'S MIRACLE.
local function onMiracle(data)
	local character = data.Character
	local local_ = character == player.Character
	if data.Phase == "Start" then
		callout(character, "Miracle")
		local at = data.Position
		-- A giant halo forms high over them and a column of light falls.
		local halo = VFXLib.part({ Size = Vector3.new(0.6, 1, 1), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.2, Shape = Enum.PartType.Cylinder })
		local column = VFXLib.part({ Size = Vector3.new(80, 8, 8), Color = Color3.fromRGB(255, 244, 200), Material = Enum.Material.Neon, Transparency = 0.5, Shape = Enum.PartType.Cylinder })
		VFXLib.animate(data.Time or 4.5, function(a)
			local grow = math.min(a * 4, 1)
			halo.Size = Vector3.new(0.6, 30 * grow, 30 * grow)
			halo.CFrame = CFrame.new(at + Vector3.new(0, 18, 0)) * CFrame.Angles(0, a * 6, math.pi / 2)
			column.CFrame = CFrame.new(at + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			column.Transparency = 0.5 + 0.4 * a
		end, function()
			halo:Destroy()
			column:Destroy()
		end)
		VFXLib.burst(at, { Count = 40, Color = GOLD, Speed = 20, Lifetime = 1, Direction = Vector3.new(0, 1, 0), Spread = 60 })
		-- The sky turns gold for everyone in range.
		local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if me and (me.Position - at).Magnitude <= (data.Range or 70) + 20 then
			TuskVFX.ScreenTint(data.Time or 4.5, { Tint = Color3.fromRGB(255, 236, 190), Saturation = 0.15, Brightness = 0.08 })
			CameraFX.shake(0.3, data.Windup or 1.5)
		end
	elseif data.Phase == "Pillars" then
		for _, pos in ipairs(data.Positions or {}) do
			local pillar = VFXLib.part({ Size = Vector3.new(60, 5, 5), Color = Color3.fromRGB(255, 246, 210), Material = Enum.Material.Neon, Transparency = 0.2, Shape = Enum.PartType.Cylinder })
			VFXLib.animate(0.45, function(a)
				pillar.CFrame = CFrame.new(pos + Vector3.new(0, 30 - 0, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				pillar.Size = Vector3.new(60, 5 * (1 - a * 0.7), 5 * (1 - a * 0.7))
				pillar.Transparency = 0.2 + 0.8 * a
			end, function()
				pillar:Destroy()
			end)
			TuskVFX.CreateImpactStar(pos, { Size = 6, Rays = 10, Color = GOLD, Color2 = Color3.new(1, 1, 1), Duration = 0.2 })
			ring(pos, 6, GOLD, 0.35)
		end
	elseif data.Phase == "Burst" then
		ring(data.Position, data.Radius or 22, GOLD, 0.6)
		ring(data.Position, (data.Radius or 22) * 0.6, Color3.new(1, 1, 1), 0.4)
		VFXLib.burst(data.Position, { Count = 60, Color = GOLD, Speed = 40, Lifetime = 0.8 })
		TuskVFX.CreateImpactStar(data.Position + Vector3.new(0, 2, 0), { Size = 14, Rays = 14, Color = GOLD, Color2 = Color3.new(1, 1, 1), Duration = 0.35 })
		if local_ then
			CameraFX.impactFrame(GOLD)
		end
		CameraFX.shakeAt(data.Position, 1, 80)
	end
end

local function onMove(data)
	if data.Who == "Miracle" then
		onMiracle(data)
		return
	end
	local character = data.Character
	local who = data.Who
	local pal = paletteOf(who)
	local local_ = character == player.Character
	if data.Phase == "Cast" or data.Phase == "Leap" or data.Phase == "Dash" or data.Phase == "Spin" or data.Phase == "Cocoon" or data.Phase == "Curtain" or data.Phase == "Flood" or data.Phase == "Bless" then
		callout(character, who)
		local root = Common.rootOf(character)
		if root then
			TuskVFX.CreateImpactStar(root.Position + Vector3.new(0, 1, 0), { Size = 4, Rays = 8, Color = GOLD, Color2 = pal.Main, Duration = 0.18 })
		end
	end
	if who == "Gyro" and data.Phase == "Cast" then
		-- Golden rings spinning down the line.
		for i = 1, 6 do
			task.delay(i * 0.05, function()
				local at = data.Position + data.Direction * (i * (data.Length or 34) / 6)
				local p = VFXLib.part({ Size = Vector3.new(0.4, 6, 6), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.2, Shape = Enum.PartType.Cylinder })
				VFXLib.animate(0.4, function(a)
					p.CFrame = CFrame.lookAt(at, at + data.Direction) * CFrame.Angles(0, math.pi / 2, a * 6)
					p.Transparency = 0.2 + 0.8 * a
				end, function()
					p:Destroy()
				end)
			end)
		end
	elseif who == "Diego" then
		if data.Phase == "Leap" then
			for i = 0, 6 do
				local t = i / 6
				local p = data.From:Lerp(data.To, t) + Vector3.new(0, math.sin(t * math.pi) * 10, 0)
				task.delay(t * (data.Time or 0.45), function()
					VFXLib.afterimage(CFrame.new(p), 2.4, pal.Main)
				end)
			end
		elseif data.Phase == "Slam" then
			ring(data.Position, data.Radius or 10, pal.Main, 0.45)
			TuskVFX.CreateGroundCracks(data.Position, { Radius = data.Radius or 10, Color = pal.Main })
			CameraFX.shakeAt(data.Position, 0.8, 40)
		end
	elseif who == "PorkPie" and data.Phase == "Cast" then
		-- Hooks fly out in every direction and yank back in.
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			local out = data.Position + Vector3.new(math.cos(a), 0.3, math.sin(a)) * (data.Radius or 20)
			streak(data.Position + Vector3.new(0, 1, 0), out, Color3.fromRGB(200, 205, 215), 0.15, 0.4)
		end
		ring(data.Position, data.Radius or 20, pal.Main, 0.5)
	elseif who == "Sandman" then
		if data.Phase == "Dash" then
			streak(data.From, data.To, Color3.fromRGB(230, 200, 140), 1.2, 0.6)
			VFXLib.burst(data.From, { Count = 16, Color = Color3.fromRGB(230, 200, 140), Speed = 14, Lifetime = 0.5 })
		elseif data.Phase == "Boom" then
			ring(data.Position, 9, pal.Main, 0.4)
			TuskVFX.CreateImpactStar(data.Position + Vector3.new(0, 1, 0), { Size = 7, Rays = 10, Color = pal.Main, Color2 = GOLD, Duration = 0.2 })
		end
	elseif who == "MountainTim" and data.Phase == "Spin" then
		-- A lasso loop spinning round him, closing in.
		local loop = {}
		for i = 1, 16 do
			loop[i] = VFXLib.part({ Size = Vector3.new(0.3, 0.3, 2.4), Color = Color3.fromRGB(205, 170, 110), Material = Enum.Material.Fabric })
		end
		VFXLib.animate(data.Time or 0.8, function(a)
			local r = Common.rootOf(character)
			local c = r and r.Position or data.Position
			local radius = (data.Radius or 14) * (1 - 0.7 * a)
			for i, seg in ipairs(loop) do
				local ang = i / #loop * math.pi * 2 + a * 12
				local p = c + Vector3.new(math.cos(ang) * radius, 1, math.sin(ang) * radius)
				seg.CFrame = CFrame.lookAt(p, p + Vector3.new(-math.sin(ang), 0, math.cos(ang)))
			end
		end, function()
			for _, seg in ipairs(loop) do
				seg:Destroy()
			end
		end)
	elseif who == "HotPants" then
		if data.Phase == "Cocoon" then
			shell(character, Color3.fromRGB(236, 150, 170), Enum.Material.SmoothPlastic, data.Time or 2)
		elseif data.Phase == "Burst" then
			ring(data.Position, 9, Color3.fromRGB(236, 150, 170), 0.4)
			VFXLib.burst(data.Position, { Count = 24, Color = Color3.fromRGB(236, 150, 170), Speed = 18, Lifetime = 0.45 })
		end
	elseif who == "Blackmore" and data.Phase == "Curtain" then
		-- Frozen drops fly out in a cone.
		for i = 1, 24 do
			local ang = math.rad((math.random() - 0.5) * (data.Cone or 70))
			local dir = (CFrame.lookAt(Vector3.new(), data.Direction) * CFrame.Angles(0, ang, 0)).LookVector
			local from = data.Position + Vector3.new(0, 1 + math.random() * 2, 0)
			local d = VFXLib.part({ Size = Vector3.new(0.25, 0.5, 0.25), Color = Color3.fromRGB(150, 205, 255), Material = Enum.Material.Glass, Transparency = 0.2 })
			VFXLib.animate(0.35, function(a)
				local p = from + dir * (data.Range or 26) * a
				d.CFrame = CFrame.lookAt(p, p + dir) * CFrame.Angles(math.pi / 2, 0, 0)
			end, function()
				d:Destroy()
			end)
		end
	elseif who == "Axl" and data.Phase == "Flood" then
		ring(data.Position, data.Radius or 22, pal.Main, 0.6)
		VFXLib.burst(data.Position, { Count = 30, Color = Color3.fromRGB(150, 130, 170), Speed = 16, Lifetime = 0.6 })
	elseif who == "DiegoAU" and data.Phase == "Draw" and character then
		TuskAnimation.play(character, "DWRevolver")
		drawRevolver(character, data)
	elseif who == "DiegoAU" and data.Phase == "Shot" then
		local gun = revolvers[character]
		local muzzle = gun and gun.Muzzle and gun.Muzzle() or data.Position
		if gun then
			gun.Kick = os.clock()
			gun.Spin = gun.Spin + math.pi / 3 -- the cylinder turns one chamber
		end
		if muzzle then
			-- Muzzle flash (a bright star), a puff of smoke.
			local dir = data.Direction or Vector3.new(0, 0, -1)
			local flash = VFXLib.part({ Size = Vector3.new(0.9, 0.9, 0.9), CFrame = CFrame.new(muzzle), Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Neon, Shape = Enum.PartType.Ball })
			local cone = VFXLib.part({ Size = Vector3.new(0.5, 0.5, data.Last and 2.4 or 1.6), CFrame = CFrame.lookAt(muzzle, muzzle + dir) * CFrame.new(0, 0, -0.8), Color = Color3.fromRGB(255, 190, 80), Material = Enum.Material.Neon })
			VFXLib.animate(0.09, function(a)
				flash.Transparency = a
				cone.Transparency = a
			end, function()
				flash:Destroy()
				cone:Destroy()
			end)
			VFXLib.burst(muzzle, { Count = data.Last and 10 or 5, Color = Color3.fromRGB(200, 196, 190), Speed = 4, Lifetime = 0.45 })
			-- A spent glint pops out sideways.
			VFXLib.burst(muzzle, { Count = 1, Color = Color3.fromRGB(220, 180, 90), Speed = 10, Lifetime = 0.3, Direction = Vector3.new(0, 1, 0), Spread = 60 })
		end
		if local_ then
			CameraFX.shake(data.Last and 0.3 or 0.15, 0.06)
		end
	elseif who == "Josuke" and data.Phase == "Silence" and data.Position then
		-- A ring of bubbles bursts out; the sound goes with them.
		ring(data.Position, data.Radius or 20, Color3.fromRGB(170, 220, 255), 0.5)
		for k = 1, 16 do
			local a = k / 16 * math.pi * 2
			local b = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), Color = Color3.fromRGB(200, 235, 255), Material = Enum.Material.Glass, Transparency = 0.4 })
			local from = data.Position + Vector3.new(0, 2, 0)
			local to = from + Vector3.new(math.cos(a), 0.2, math.sin(a)) * (data.Radius or 20)
			VFXLib.animate(0.5, function(t)
				b.CFrame = CFrame.new(from:Lerp(to, t))
				b.Transparency = 0.4 + 0.6 * t
			end, function()
				b:Destroy()
			end)
		end
	elseif who == "Jodio" then
		-- (November Rain's cloud and crush are drawn by JodioVFX.)
	elseif who == "Polnareff" and data.Phase == "Whirl" and data.Position then
		-- SWORD WHIRL: a silver ring of blade.
		ring(data.Position, data.Radius or 14, Color3.fromRGB(220, 230, 250), 0.4)
	elseif who == "Joseph" and data.Phase == "Hamon" and data.Position then
		-- HAMON BEAT: a golden ripple across the ground.
		ring(data.Position, data.Radius or 16, Color3.fromRGB(255, 214, 80), 0.5)
	elseif who == "Dio" and data.Phase == "Drain" and data.Position then
		-- WRYYY: a blood-red ring pulling in.
		ring(data.Position, data.Radius or 18, Color3.fromRGB(190, 20, 30), 0.6)
	elseif who == "Rohan" and data.Phase == "Books" and data.Position then
		-- OPEN BOOK: a ring of pages.
		ring(data.Position, data.Radius or 18, Color3.fromRGB(250, 246, 232), 0.5)
		VFXLib.burst(data.Position + Vector3.new(0, 2, 0), { Count = 16, Color = Color3.fromRGB(250, 246, 232), Speed = 14, Lifetime = 0.6 })
	elseif who == "Giorno" and data.Phase == "Bloom" and data.Position then
		-- LIFE BLOOM: a ring of gold, then flowers bursting up.
		ring(data.Position, data.Radius or 18, Color3.fromRGB(255, 214, 90), 0.5)
		for k = 1, 14 do
			local a = k / 14 * math.pi * 2
			local p = data.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * (data.Radius or 18) * (0.3 + math.random() * 0.6) - Vector3.new(0, 2.6, 0)
			VFXLib.burst(p, { Count = 4, Color = k % 2 == 0 and Color3.fromRGB(255, 120, 170) or Color3.fromRGB(110, 210, 90), Speed = 8, Lifetime = 0.6 })
		end
	elseif who == "Okuyasu" and data.Phase == "Pull" and data.Position then
		-- SPACE PULL: a dark ring snapping inward.
		ring(data.Position, data.Radius or 26, Color3.fromRGB(150, 200, 255), 0.4)
	elseif who == "Kira" and data.Phase == "Blast" and data.Position then
		-- CONTACT DETONATION: a ring of fire round him.
		ring(data.Position, data.Radius or 15, Color3.fromRGB(255, 150, 60), 0.5)
		VFXLib.burst(data.Position + Vector3.new(0, 2, 0), { Count = 18, Color = Color3.fromRGB(255, 150, 60), Speed = 18, Lifetime = 0.6 })
	elseif who == "Josuke4" and data.Phase == "Barrage" and data.Position then
		-- DORA BARRAGE: a pink ring of punches spreading out round him.
		ring(data.Position, data.Radius or 16, Color3.fromRGB(255, 130, 200), data.Time or 0.5)
	elseif who == "Jotaro" and data.Phase == "Barrage" and data.Position then
		-- ORA BARRAGE: a violet ring of punches spreading out round him.
		ring(data.Position, data.Radius or 16, Color3.fromRGB(150, 120, 255), data.Time or 0.5)
	elseif who == "Ringo" and data.Phase == "Rewind" and data.Position then
		-- SECOND HAND: a pink ring sweeps out; everyone in it loses 6 seconds.
		ring(data.Position, data.Radius or 20, Color3.fromRGB(240, 130, 180), 0.6)
	elseif who == "Tooru" and data.Phase == "Calamity" and data.Position then
		-- A dark maroon ring sweeps out: misfortune finds everyone in it.
		ring(data.Position, data.Radius or 24, Color3.fromRGB(150, 40, 50), 0.6)
		VFXLib.burst(data.Position + Vector3.new(0, 2, 0), { Count = 18, Color = Color3.fromRGB(120, 90, 60), Speed = 14, Lifetime = 0.8 })
	elseif who == "Valentine" then
		if data.Phase == "Bless" then
			shell(character, Color3.fromRGB(255, 250, 225), Enum.Material.ForceField, data.Time or 2.5)
		elseif data.Phase == "Pulse" then
			ring(data.Position, data.Radius or 12, Color3.fromRGB(255, 250, 225), 0.45)
		end
	end
	if local_ and (data.Phase == "Slam" or data.Phase == "Boom" or data.Phase == "Burst" or data.Phase == "Pulse") then
		CameraFX.shake(0.5, 0.2)
	end
end

---------------------------------------------------------------------------
-- CORPSE COMPASS (bounty board shop): while it lasts, a gold arrow floats
-- ahead of you pointing at the nearest part lying out in the desert, with
-- how far it is.
---------------------------------------------------------------------------
local compass
local function stepCompass()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local active = root and (character:GetAttribute("CompassUntil") or 0) > workspace:GetServerTimeNow()
	local best, bestD
	if active then
		for _, relic in ipairs(CollectionService:GetTagged("SpinCorpse")) do
			if relic.Parent then
				local d = (relic:GetPivot().Position - root.Position).Magnitude
				if not bestD or d < bestD then
					best, bestD = relic, d
				end
			end
		end
	end
	if not best then
		if compass then
			compass.Model:Destroy()
			compass = nil
		end
		return
	end
	if not compass then
		local m = Instance.new("Model")
		m.Name = "CorpseCompass"
		m.Parent = VFXLib.Folder
		local shaft = VFXLib.part({ Size = Vector3.new(0.3, 0.3, 2.2), Color = Color3.fromRGB(255, 210, 90), Material = Enum.Material.Neon })
		shaft.Parent = m
		local head = VFXLib.part({ Size = Vector3.new(1.1, 0.3, 0.9), Color = Color3.fromRGB(255, 236, 160), Material = Enum.Material.Neon })
		head.Parent = m
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(120, 26)
		bb.StudsOffset = Vector3.new(0, 1, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Adornee = shaft
		-- A little nailed wooden plaque with the part and distance.
		local board = new("Frame", { Size = UDim2.fromScale(1, 1) }, bb)
		UITheme.wood(board, { Planks = 1, Border = 2, Radius = 5 })
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(10, 2)
		label.Size = UDim2.new(1, -20, 1, -4)
		label.ZIndex = 3
		label.Font = Enum.Font.Bangers
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 220, 120)
		label.TextStrokeColor3 = T.WOOD_EDGE
		label.TextStrokeTransparency = 0.4
		label.Parent = board
		bb.Parent = m
		compass = { Model = m, Shaft = shaft, Head = head, Label = label }
	end
	local to = best:GetPivot().Position - root.Position
	local flat = Vector3.new(to.X, 0, to.Z)
	flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
	local at = root.Position + flat * 4 + Vector3.new(0, 2.2 + math.sin(os.clock() * 3) * 0.15, 0)
	local cf = CFrame.lookAt(at, at + flat)
	compass.Shaft.CFrame = cf
	compass.Head.CFrame = cf * CFrame.new(0, 0, -1.3) * CFrame.Angles(0, math.pi / 4, 0)
	compass.Label.Text = string.format("%s  %dm", string.upper(best:GetAttribute("PartId") or "PART"), math.floor(bestD))
end

---------------------------------------------------------------------------
function CorpseClient.init()
	cfg = TuskConfig.Corpse
	if not cfg or cfg.Enabled == false then
		return
	end
	for _, info in ipairs(cfg.Parts) do
		partInfo[info.Id] = info
	end
	buildUI()
	local keys = TuskConfig.Keys.CorpseMove or {}
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == keys.Keyboard or input.KeyCode == keys.Gamepad then
			useMove()
		end
	end)
	Net.get("WorldFX").OnClientEvent:Connect(function(name, data)
		if typeof(data) ~= "table" then
			return
		end
		if name == "CorpseTaken" then
			local info = partInfo[data.Part]
			local partName = info and info.Name or tostring(data.Part)
			if data.Player == player.UserId then
				showBanner("YOU TOOK THE " .. partName .. "!  " .. (info and string.upper(info.Text) or ""))
			else
				showFeed((data.Name or "Someone") .. " took the Saint's Corpse " .. partName .. "!")
			end
		elseif name == "CorpseDropped" then
			local info = partInfo[data.Part]
			showFeed("The " .. (info and info.Name or "part") .. " fell where " .. (data.Name or "someone") .. " died!")
			if data.Position then
				ring(data.Position, 8, GOLD, 0.6)
			end
		elseif name == "CorpseMove" then
			onMove(data)
		elseif name == "CorpseComplete" then
			if data.Player == player.UserId then
				showBanner("THE COMPLETE SAINT'S CORPSE!  PRESS V: THE SAINT'S MIRACLE")
			else
				showBanner(string.upper(data.Name or "SOMEONE") .. " HAS THE COMPLETE SAINT'S CORPSE!")
			end
		elseif name == "CorpseScattered" then
			showFeed("The Saint's Corpse leaves " .. (data.Name or "them") .. " and scatters across the desert!")
		end
	end)
	RunService.RenderStepped:Connect(function()
		stepPanel()
		stepRelics(os.clock())
		stepHalos(os.clock())
		stepCompass()
	end)
end

return CorpseClient
