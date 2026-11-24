---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient"
updated: 2026-11-22
---
# CorpseClient

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| **Exact name** | `CorpseClient` (capitals matter) |

**What it does:** Client side of the SAINT'S CORPSE (server: CorpseService, CorpseMoves). the relics float, turn and bob (tag "SpinCorpse") a panel in the bottom-left corner while you hold parts: each part with its boost, and your CORPSE MOVE button (V / D-pad right, or tap it) with its cooldown announcements: you took a part (big), someone else took one or a part fell where someone died (a line at the top) the visuals for every character's corpse move, with its name popping up over the caster the COMPLETE corpse: a server-wide announcement, a gold halo over the holder, the panel turns gold and V is THE SAINT'S MIRACLE (golden sky, a giant halo, pillars of light on every enemy, a final blast)

## How to add it
1. In Studio's Explorer, find **SpinClient** (StarterPlayer › StarterPlayerScripts › SpinClient).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **CorpseClient**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	CorpseClient  (StarterPlayerScripts.SpinClient.CorpseClient)

	Client side of the SAINT'S CORPSE (server: CorpseService, CorpseMoves).
	  * the relics float, turn and bob (tag "SpinCorpse")
	  * a panel in the bottom-left corner while you hold parts: each part with its boost,
	    and your CORPSE MOVE button (V / D-pad right, or tap it) with its
	    cooldown
	  * announcements: you took a part (big), someone else took one or a
	    part fell where someone died (a line at the top)
	  * the visuals for every character's corpse move, with its name popping
	    up over the caster
	  * the COMPLETE corpse: a server-wide announcement, a gold halo over the
	    holder, the panel turns gold and V is THE SAINT'S MIRACLE (golden sky,
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
local Common = require(script.Parent.TuskActCommon)

local CorpseClient = {}

local player = Players.LocalPlayer
local cfg
local GOLD = Color3.fromRGB(255, 205, 90)
local INK = Color3.fromRGB(40, 26, 14)
local PANEL = Color3.fromRGB(26, 20, 16)
local partInfo = {}

local gui, panel, panelTitle, list, moveButton, moveName, moveFill, moveTime, feed, banner
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
local function rebuildPanel(parts)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local ids = {}
	for id in string.gmatch(parts, "[^,]+") do
		table.insert(ids, id)
	end
	for i, id in ipairs(ids) do
		local info = partInfo[id]
		local row = new("Frame", { LayoutOrder = i, BackgroundColor3 = Color3.fromRGB(46, 36, 26), Size = UDim2.new(1, 0, 0, 30) }, list)
		corner(row, 6)
		local icon = new("Frame", { Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = Color3.fromRGB(122, 90, 60), Rotation = 45 }, row)
		new("UIStroke", { Color = GOLD, Thickness = 1.5 }, icon)
		label(row, { Position = UDim2.fromOffset(34, 2), Size = UDim2.new(1, -40, 0, 14), Text = info and info.Name or id, TextColor3 = GOLD })
		label(row, { Position = UDim2.fromOffset(34, 16), Size = UDim2.new(1, -40, 0, 11), Text = info and info.Text or "", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(230, 220, 200) })
	end
	panel.Size = UDim2.fromOffset(240, 44 + #ids * 34 + 52)
	local who = myCharacterName()
	local complete = #ids >= #cfg.Parts
	if complete then
		who = "Miracle"
	end
	moveName.Text = (cfg.MoveNames and who and cfg.MoveNames[who]) or "CORPSE MOVE"
	-- The complete corpse: the panel turns gold.
	panel.BackgroundColor3 = complete and Color3.fromRGB(70, 52, 16) or PANEL
	moveButton.BackgroundColor3 = complete and Color3.fromRGB(226, 182, 70) or Color3.fromRGB(150, 110, 40)
	panelTitle.Text = complete and "COMPLETE SAINT'S CORPSE" or "SAINT'S CORPSE"
end

local function buildUI()
	gui = new("ScreenGui", { Name = "CorpseHUD", ResetOnSpawn = false, DisplayOrder = 4 }, player:WaitForChild("PlayerGui"))
	-- Bottom-left corner (lifted above the thumbstick on touch screens).
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	panel = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, touch and -230 or -12), Size = UDim2.fromOffset(240, 120), BackgroundColor3 = PANEL, BackgroundTransparency = 0.08, Visible = false }, gui)
	corner(panel, 10)
	new("UIStroke", { Color = GOLD, Thickness = 2 }, panel)
	panelTitle = label(panel, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 22), Text = "SAINT'S CORPSE", Font = Enum.Font.Bangers, TextColor3 = GOLD })
	label(panel, { Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, 11), Text = "Boosts last until you die", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(190, 175, 150) })
	list = new("Frame", { Position = UDim2.fromOffset(8, 42), Size = UDim2.new(1, -16, 1, -96), BackgroundTransparency = 1 }, panel)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	-- The corpse move: a button with a cooldown fill.
	moveButton = new("TextButton", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8), Size = UDim2.new(1, -16, 0, 40), BackgroundColor3 = Color3.fromRGB(150, 110, 40), Text = "", AutoButtonColor = true }, panel)
	corner(moveButton, 8)
	new("UIStroke", { Color = GOLD, Thickness = 2 }, moveButton)
	moveFill = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, moveButton)
	corner(moveFill, 8)
	local key = new("Frame", { Position = UDim2.fromOffset(6, 7), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = GOLD }, moveButton)
	corner(key, 6)
	label(key, { Size = UDim2.fromScale(1, 1), Text = "V", TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Center })
	moveName = label(moveButton, { Position = UDim2.fromOffset(40, 6), Size = UDim2.new(1, -86, 0, 28), Text = "", Font = Enum.Font.Bangers })
	new("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 10 }, moveName)
	moveTime = label(moveButton, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 10), Size = UDim2.fromOffset(40, 20), Text = "", TextXAlignment = Enum.TextXAlignment.Right })
	moveButton.Activated:Connect(useMove)
	-- Announcements.
	feed = label(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(520, 22), Text = "", Font = Enum.Font.GothamBold, TextColor3 = GOLD, TextStrokeTransparency = 0.3, TextXAlignment = Enum.TextXAlignment.Center, Visible = false })
	banner = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(620, 70), Text = "", Font = Enum.Font.Bangers, TextColor3 = GOLD, TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, Visible = false })
end

local feedToken, bannerToken
local function showFeed(text)
	feed.Text = text
	feed.Visible = true
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
	local l = label(bb, { Size = UDim2.fromScale(1, 1), Text = (cfg.MoveNames and cfg.MoveNames[who] or "CORPSE MOVE") .. "!", Font = Enum.Font.Bangers, TextColor3 = GOLD, TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center })
	VFXLib.animate(1.3, function(a)
		bb.StudsOffset = Vector3.new(0, 3.4 + a * 1.2, 0)
		l.TextTransparency = math.max(0, (a - 0.6) / 0.4)
		l.TextStrokeTransparency = l.TextTransparency
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
	end)
end

return CorpseClient
```
