---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › UI"
updated: 2026-11-22
---
# BountyUI

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › UI` |
| **Exact name** | `BountyUI` (capitals matter) |

**What it does:** The bounty board screen (owner's design): a wooden board full of parchment WANTED posters, one per player (their avatar headshot) or Stand-user NPC, each with its reward HOVER a poster: it straightens, lifts, grows and gets a shadow CLICK it: "ACCEPT BOUNTY?" with ACCEPT / DECLINE ACCEPT: the board closes and a bounty tracker appears on the left (target, reward, distance, time left, abandon button), plus a red TARGET marker over their head that only you can see claiming it: a big "BOUNTY CLAIMED! +$350" banner Remote: Net "Bounty" (server: BountyService).

## How to add it
1. In Studio's Explorer, find **UI** (StarterPlayer › StarterPlayerScripts › SpinClient › UI).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **BountyUI**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	BountyUI  (StarterPlayerScripts.SpinClient.UI.BountyUI)

	The bounty board screen (owner's design):
	  * a wooden board full of parchment WANTED posters, one per player (their
	    avatar headshot) or Stand-user NPC, each with its reward
	  * HOVER a poster: it straightens, lifts, grows and gets a shadow
	  * CLICK it: "ACCEPT BOUNTY?" with ACCEPT / DECLINE
	  * ACCEPT: the board closes and a bounty tracker appears on the left
	    (target, reward, distance, time left, abandon button), plus a red
	    TARGET marker over their head that only you can see
	  * claiming it: a big "BOUNTY CLAIMED! +$350" banner
	Remote: Net "Bounty" (server: BountyService).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local Net = require(Shared.Net)
local Registry = require(Shared.TuskActRegistry)

local BountyUI = {}
local player = Players.LocalPlayer
local Remote

local WOOD = Color3.fromRGB(112, 74, 44)
local WOOD_DARK = Color3.fromRGB(78, 50, 30)
local WOOD_LIGHT = Color3.fromRGB(134, 90, 56)
local PAPER = Color3.fromRGB(234, 205, 160)
local PAPER_DARK = Color3.fromRGB(205, 172, 125)
local INK = Color3.fromRGB(60, 36, 20)
local RED = Color3.fromRGB(190, 40, 35)
local GREEN = Color3.fromRGB(60, 150, 70)
local GOLD = Color3.fromRGB(255, 205, 90)

local gui, dim, board, grid, confirm, tracker, banner, marker
local current -- the active bounty
local confirmEntry -- the poster the Accept/Decline card is asking about
local FAST = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SOFT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function corner(p, r)
	new("UICorner", { CornerRadius = UDim.new(0, r) }, p)
end

local function label(parent, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, TextColor3 = INK, Font = Enum.Font.GothamBlack, TextScaled = true }, parent)
	for k, v in pairs(props) do
		l[k] = v
	end
	return l
end

local function photoFor(entry, parent)
	local photo = new("ImageLabel", { Name = "Photo", BackgroundColor3 = PAPER_DARK, BorderSizePixel = 0, ImageColor3 = Color3.fromRGB(240, 220, 190) }, parent)
	if entry.Kind == "Player" and entry.UserId then
		photo.Image = "rbxthumb://type=AvatarHeadShot&id=" .. entry.UserId .. "&w=150&h=150"
	else
		-- NPC: a silhouette in their Stand's colour with a question mark.
		local info = entry.Act and Registry.get(entry.Act)
		photo.BackgroundColor3 = info and info.Theme.Primary:Lerp(PAPER_DARK, 0.45) or PAPER_DARK
		label(photo, { Size = UDim2.fromScale(1, 1), Text = "?", Font = Enum.Font.Bangers, TextColor3 = INK, TextTransparency = 0.25 })
	end
	return photo
end

---------------------------------------------------------------------------
-- Board
---------------------------------------------------------------------------
local function closeBoard()
	if dim then
		dim.Visible = false
	end
	if confirm then
		confirm.Visible = false
	end
end

local function showConfirm(entry)
	confirm.Visible = true
	local body = confirm:FindFirstChild("Body")
	for _, c in ipairs(body:GetChildren()) do
		if c.Name == "Photo" then
			c:Destroy()
		end
	end
	local photo = photoFor(entry, body)
	photo.Position = UDim2.fromScale(0.36, 0.2)
	photo.Size = UDim2.fromScale(0.28, 0.36)
	body:FindFirstChild("Who").Text = string.upper(entry.Name)
	body:FindFirstChild("Pay").Text = "REWARD  $" .. entry.Reward
	body:FindFirstChild("Note").Text = (current and current.Key ~= entry.Key) and ("This replaces your bounty on " .. current.Name .. ".") or "Land the final hit to claim it."
	confirmEntry = entry
	local scale = confirm:FindFirstChildOfClass("UIScale")
	scale.Scale = 0.6
	TweenService:Create(scale, FAST, { Scale = 1 }):Play()
end

local function makePoster(entry, index)
	local col = (index - 1) % 4
	local row = math.floor((index - 1) / 4)
	local tilt = ((index * 37) % 11 - 5) * 1.2
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(126, 166), Position = UDim2.fromOffset(16 + col * 140, 12 + row * 178) }, grid)
	local shadow = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(6, 8), Rotation = tilt }, holder)
	corner(shadow, 4)
	local paper = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = PAPER, Size = UDim2.fromScale(1, 1), Rotation = tilt }, holder)
	corner(paper, 3)
	local scale = new("UIScale", { Scale = 1 }, paper)
	new("UIGradient", { Color = ColorSequence.new(PAPER, PAPER_DARK), Rotation = 90 }, paper)
	new("UIStroke", { Color = PAPER_DARK:Lerp(INK, 0.3), Thickness = 1.5 }, paper)
	new("Frame", { BackgroundColor3 = Color3.fromRGB(70, 70, 76), Size = UDim2.fromOffset(9, 9), Position = UDim2.new(0.5, -4, 0, 4) }, paper) -- nail
	label(paper, { Position = UDim2.fromScale(0.05, 0.07), Size = UDim2.fromScale(0.9, 0.14), Text = "WANTED", Font = Enum.Font.Bangers })
	local photo = photoFor(entry, paper)
	photo.Position = UDim2.fromScale(0.14, 0.23)
	photo.Size = UDim2.fromScale(0.72, 0.42)
	label(paper, { Position = UDim2.fromScale(0.05, 0.67), Size = UDim2.fromScale(0.9, 0.1), Text = string.upper(entry.Name), TextTruncate = Enum.TextTruncate.AtEnd })
	label(paper, { Position = UDim2.fromScale(0.05, 0.79), Size = UDim2.fromScale(0.9, 0.13), Text = "$" .. entry.Reward, Font = Enum.Font.Bangers, TextColor3 = RED })
	if (entry.Streak or 0) > 0 then
		label(paper, { Position = UDim2.fromScale(0.05, 0.92), Size = UDim2.fromScale(0.9, 0.06), Text = entry.Streak .. " KILL STREAK", TextColor3 = INK:Lerp(PAPER, 0.3) })
	end
	if current and current.Key == entry.Key then
		local stamp = label(paper, { Position = UDim2.fromScale(0.05, 0.36), Size = UDim2.fromScale(0.9, 0.2), Rotation = -18, Text = "HUNTING", Font = Enum.Font.Bangers, TextColor3 = RED, TextTransparency = 0.15, ZIndex = 3 })
		new("UIStroke", { Color = RED, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.3 }, stamp)
	end
	-- Hover: straighten, lift, grow, cast a shadow. Leave: settle back.
	paper.MouseEnter:Connect(function()
		holder.ZIndex = 5
		TweenService:Create(paper, FAST, { Rotation = 0, Position = UDim2.fromOffset(0, -8) }):Play()
		TweenService:Create(scale, FAST, { Scale = 1.12 }):Play()
		TweenService:Create(shadow, SOFT, { BackgroundTransparency = 0.6, Rotation = 0, Position = UDim2.fromOffset(8, 6) }):Play()
	end)
	paper.MouseLeave:Connect(function()
		holder.ZIndex = 1
		TweenService:Create(paper, SOFT, { Rotation = tilt, Position = UDim2.fromOffset(0, 0) }):Play()
		TweenService:Create(scale, SOFT, { Scale = 1 }):Play()
		TweenService:Create(shadow, SOFT, { BackgroundTransparency = 1, Rotation = tilt, Position = UDim2.fromOffset(6, 8) }):Play()
	end)
	paper.Activated:Connect(function()
		-- A little "tug" when picked.
		scale.Scale = 1.2
		TweenService:Create(scale, FAST, { Scale = 1.12 }):Play()
		showConfirm(entry)
	end)
	-- Posters drop onto the board one after another.
	paper.Position = UDim2.fromOffset(0, -30)
	paper.BackgroundTransparency = 1
	task.delay(index * 0.04, function()
		TweenService:Create(paper, FAST, { Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 0 }):Play()
	end)
end

local function openBoard(data)
	dim.Visible = true
	confirm.Visible = false
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	current = data.Active or current
	local list = data.Bounties or {}
	grid:FindFirstChild("Empty").Visible = #list == 0
	for i, entry in ipairs(list) do
		makePoster(entry, i)
	end
	grid.CanvasSize = UDim2.fromOffset(0, 24 + math.ceil(#list / 4) * 178)
	local scale = board:FindFirstChildOfClass("UIScale")
	local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local fit = math.min(1, view.X / 640, view.Y / 520)
	scale.Scale = fit * 0.85
	TweenService:Create(scale, FAST, { Scale = fit }):Play()
end

local function buildBoard()
	dim = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false }, gui)
	dim.Activated:Connect(closeBoard)
	board = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 470), BackgroundColor3 = WOOD }, dim)
	corner(board, 6)
	new("UIScale", { Scale = 1 }, board)
	new("UIStroke", { Color = WOOD_DARK, Thickness = 4 }, board)
	-- Planks.
	for i = 0, 5 do
		new("Frame", { BackgroundColor3 = i % 2 == 0 and WOOD_LIGHT or WOOD, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 60 + i * 68), Size = UDim2.new(1, 0, 0, 66), BackgroundTransparency = 0.2 }, board)
	end
	local title = new("Frame", { BackgroundColor3 = WOOD_DARK, Position = UDim2.fromOffset(-10, -16), Size = UDim2.new(1, 20, 0, 64) }, board)
	corner(title, 6)
	label(title, { Size = UDim2.fromScale(1, 1), Text = "BOUNTY BOARD", Font = Enum.Font.Bangers, TextColor3 = PAPER, TextStrokeTransparency = 0.5 })
	local close = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, 4), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = RED, Text = "X", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, title)
	corner(close, 8)
	close.Activated:Connect(closeBoard)
	grid = new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 56), Size = UDim2.new(1, -16, 1, -64), ScrollBarThickness = 6, CanvasSize = UDim2.new() }, board)
	label(grid, { Name = "Empty", Position = UDim2.fromScale(0.1, 0.35), Size = UDim2.fromScale(0.8, 0.12), Text = "No bounties right now. Check back later!", TextColor3 = PAPER, Visible = false })

	-- Accept / decline.
	confirm = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(330, 300), BackgroundColor3 = PAPER, Visible = false, ZIndex = 10 }, dim)
	corner(confirm, 6)
	new("UIScale", { Scale = 1 }, confirm)
	new("UIStroke", { Color = INK, Thickness = 3 }, confirm)
	local body = new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, confirm)
	label(body, { Position = UDim2.fromScale(0.05, 0.03), Size = UDim2.fromScale(0.9, 0.13), Text = "ACCEPT BOUNTY?", Font = Enum.Font.Bangers })
	label(body, { Name = "Who", Position = UDim2.fromScale(0.05, 0.58), Size = UDim2.fromScale(0.9, 0.09), Text = "" })
	label(body, { Name = "Pay", Position = UDim2.fromScale(0.05, 0.67), Size = UDim2.fromScale(0.9, 0.09), Text = "", Font = Enum.Font.Bangers, TextColor3 = RED })
	label(body, { Name = "Note", Position = UDim2.fromScale(0.05, 0.76), Size = UDim2.fromScale(0.9, 0.06), Text = "", Font = Enum.Font.Gotham })
	local function button(text, color, x)
		local b = new("TextButton", { Position = UDim2.fromScale(x, 0.85), Size = UDim2.fromScale(0.4, 0.11), BackgroundColor3 = color, Text = text, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, body)
		corner(b, 8)
		local s = new("UIScale", { Scale = 1 }, b)
		b.MouseEnter:Connect(function()
			TweenService:Create(s, FAST, { Scale = 1.08 }):Play()
		end)
		b.MouseLeave:Connect(function()
			TweenService:Create(s, SOFT, { Scale = 1 }):Play()
		end)
		return b
	end
	button("ACCEPT", GREEN, 0.07).Activated:Connect(function()
		if confirmEntry then
			Remote:FireServer("Accept", confirmEntry.Key)
		end
		closeBoard()
	end)
	button("DECLINE", RED, 0.53).Activated:Connect(function()
		confirm.Visible = false
	end)
end

---------------------------------------------------------------------------
-- Tracker, target marker, banner
---------------------------------------------------------------------------
local function targetModel()
	if not current then
		return nil
	end
	if current.Kind == "Player" then
		local p = Players:GetPlayerByUserId(current.UserId)
		return p and p.Character
	end
	return current.Model
end

local function setMarker(model)
	local head = model and (model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart"))
	if not head then
		marker.Enabled = false
		return
	end
	marker.Adornee = head
	marker.Enabled = true
end

local function buildTracker()
	tracker = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.42, 0), Size = UDim2.fromOffset(250, 84), BackgroundColor3 = PAPER, Visible = false }, gui)
	corner(tracker, 6)
	new("UIStroke", { Color = INK, Thickness = 2 }, tracker)
	label(tracker, { Position = UDim2.fromOffset(82, 4), Size = UDim2.fromOffset(120, 18), Text = "BOUNTY", Font = Enum.Font.Bangers, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Left })
	label(tracker, { Name = "Who", Position = UDim2.fromOffset(82, 22), Size = UDim2.fromOffset(160, 18), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
	label(tracker, { Name = "Pay", Position = UDim2.fromOffset(82, 40), Size = UDim2.fromOffset(160, 18), Text = "", Font = Enum.Font.Bangers, TextColor3 = GREEN, TextXAlignment = Enum.TextXAlignment.Left })
	label(tracker, { Name = "Info", Position = UDim2.fromOffset(82, 60), Size = UDim2.fromOffset(160, 14), Text = "", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left })
	local quit = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = RED, Text = "X", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, tracker)
	corner(quit, 6)
	quit.Activated:Connect(function()
		Remote:FireServer("Abandon")
	end)

	marker = new("BillboardGui", { Size = UDim2.fromOffset(90, 70), StudsOffset = Vector3.new(0, 3.2, 0), AlwaysOnTop = true, LightInfluence = 0, Enabled = false }, gui)
	label(marker, { Size = UDim2.new(1, 0, 0, 22), Text = "TARGET", Font = Enum.Font.Bangers, TextColor3 = RED, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.new(1, 1, 1) })
	local arrow = new("Frame", { Name = "Arrow", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.fromOffset(22, 22), Rotation = 45, BackgroundColor3 = RED }, marker)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, arrow)

	banner = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(560, 80), Text = "", Font = Enum.Font.Bangers, TextColor3 = GOLD, TextStrokeTransparency = 0, Visible = false })
	new("UIScale", { Scale = 1 }, banner)
end

local function showActive(b)
	current = b
	tracker.Visible = true
	for _, c in ipairs(tracker:GetChildren()) do
		if c.Name == "Photo" then
			c:Destroy()
		end
	end
	local photo = photoFor(b, tracker)
	photo.Position = UDim2.fromOffset(8, 8)
	photo.Size = UDim2.fromOffset(66, 66)
	tracker:FindFirstChild("Who").Text = string.upper(b.Name)
	tracker:FindFirstChild("Pay").Text = "$" .. b.Reward
	tracker.Position = UDim2.new(0, -260, 0.42, 0)
	TweenService:Create(tracker, FAST, { Position = UDim2.new(0, 12, 0.42, 0) }):Play()
end

local function clearActive()
	current = nil
	tracker.Visible = false
	marker.Enabled = false
end

local function showBanner(text, color)
	banner.Text = text
	banner.TextColor3 = color
	banner.Visible = true
	local scale = banner:FindFirstChildOfClass("UIScale")
	scale.Scale = 0.4
	TweenService:Create(scale, FAST, { Scale = 1 }):Play()
	task.delay(2.6, function()
		if banner.Text == text then
			banner.Visible = false
		end
	end)
end

function BountyUI.step()
	if not current or not tracker then
		return
	end
	local model = targetModel()
	setMarker(model)
	local mine = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local theirs = model and model:FindFirstChild("HumanoidRootPart")
	local left = math.max(0, (current.Expires or 0) - workspace:GetServerTimeNow())
	local where = (mine and theirs) and (math.floor((theirs.Position - mine.Position).Magnitude) .. " studs") or "respawning..."
	tracker:FindFirstChild("Info").Text = string.format("%s  ·  %d:%02d", where, math.floor(left / 60), math.floor(left % 60))
	if marker.Enabled then
		marker:FindFirstChild("Arrow").Position = UDim2.new(0.5, 0, 0, 26 + math.sin(os.clock() * 5) * 4)
	end
end

function BountyUI.init()
	Remote = Net.get("Bounty")
	gui = new("ScreenGui", { Name = "BountyBoard", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 8 }, player:WaitForChild("PlayerGui"))
	buildBoard()
	buildTracker()
	Remote.OnClientEvent:Connect(function(kind, data)
		data = typeof(data) == "table" and data or {}
		if kind == "Open" then
			openBoard(data)
		elseif kind == "Active" then
			showActive(data)
			showBanner("BOUNTY ACCEPTED: " .. string.upper(data.Name or ""), PAPER)
		elseif kind == "Complete" then
			clearActive()
			showBanner("BOUNTY CLAIMED!  +$" .. tostring(data.Reward), GOLD)
		elseif kind == "Lost" then
			clearActive()
			showBanner(data.Reason or "BOUNTY LOST", Color3.fromRGB(255, 140, 120))
		elseif kind == "Cleared" then
			clearActive()
		end
	end)
	RunService.RenderStepped:Connect(BountyUI.step)
end

return BountyUI
```
