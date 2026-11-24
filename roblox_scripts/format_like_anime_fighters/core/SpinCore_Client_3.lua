--[[
	SpinCore_Client_3  (ModuleScript)  -- part 3 of 8
	PUT IT IN: ReplicatedStorage > SpinCore   (make a Folder named SpinCore there if it doesn't exist)

	Part of the Spin Battlegrounds client core, split up so pasting is quick.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: CorpseClient
-- ======================================================================
__modules["CorpseClient"] = function()
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

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local TuskVFX = __require("TuskVFX")
local CameraFX = __require("CameraFX")
local Common = __require("TuskActCommon")
local TuskAnimation = __require("TuskAnimation")

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
		bb.Size = UDim2.fromOffset(110, 26)
		bb.StudsOffset = Vector3.new(0, 1, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = shaft
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 220, 120)
		label.TextStrokeTransparency = 0.2
		label.Parent = bb
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
end

-- ======================================================================
-- MODULE: DefenseClient
-- ======================================================================
__modules["DefenseClient"] = function()
--[[
	DefenseClient  (StarterPlayerScripts.SpinClient.DefenseClient)

	Block and Dash on the client, for every character:
	  * input: hold F (controller L2) to block, Q (controller R2) to dash,
	    on-screen buttons on mobile. Intents only: the server decides.
	  * DASH: when the server grants it, this client moves its own character
	    (smooth, and it replicates). Everyone sees a dust burst, a wind ring,
	    body-shaped afterimages in the character's colour, wind streaks, a
	    landing puff and a dash pose (forward / back / left / right); speed
	    lines for the dasher. A dash that cancels an attack flashes white.
	  * PERFECT DODGE: a gold ghost and "PERFECT DODGE", a blue slowed-down
	    flash and COUNTER READY for the dodger.
	  * BLOCK: anyone blocking braces into a guard pose (and sags into a weak
	    guard when the guard bar is low). A curved barrier of glowing tiles in
	    their character's colour builds in front of them; it shimmers, its
	    tiles darken, flicker and crack red as the guard bar drains, and it
	    scatters away on release. A blocked hit makes them recoil, lights the
	    tile it struck, sends a ripple across the barrier and throws sparks.
	  * PERFECT BLOCK: gold flash and "PERFECT!" on the defender, the attacker
	    reels. GUARD BREAK: the shield shatters, "GUARD BREAK" and a stagger.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Fighters = __require("Fighters")
local Common = __require("TuskActCommon")

local DefenseClient = {}
local player = Players.LocalPlayer
local sounds = TuskConfig.Sounds
local SHIELD = Color3.fromRGB(110, 180, 255)
local SHIELD_LIGHT = Color3.fromRGB(210, 235, 255)
local GOLD = Color3.fromRGB(255, 210, 80)

local Request
local blocking = {} -- [character] = { Shield, Previous hold }
local blockHeld = false

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
local function moveDirection()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
		return humanoid.MoveDirection
	end
	return root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
end

local function onBlock(_, state)
	if state == Enum.UserInputState.Begin then
		blockHeld = true
		Request:FireServer("Block", true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if blockHeld then
			blockHeld = false
			Request:FireServer("Block", false)
		end
	end
	return Enum.ContextActionResult.Sink
end

local function onDashInput(_, state)
	if state == Enum.UserInputState.Begin then
		Request:FireServer("Dash", moveDirection())
	end
	return Enum.ContextActionResult.Sink
end

---------------------------------------------------------------------------
-- Dash
---------------------------------------------------------------------------
local function dashPose(root, direction)
	local look, right = root.CFrame.LookVector, root.CFrame.RightVector
	local f, r = direction:Dot(look), direction:Dot(right)
	if math.abs(f) >= math.abs(r) then
		return f >= 0 and "DashF" or "DashB"
	end
	return r >= 0 and "DashR" or "DashL"
end

local BODY = { "Head", "UpperTorso", "LowerTorso", "Torso", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local function dashColour(character)
	local act = character:GetAttribute("TuskAct")
	local pal = act and Common.palette(act)
	return pal and pal.Main or SHIELD_LIGHT, pal and pal.Light or Color3.new(1, 1, 1)
end

-- A see-through copy of the body (every limb), in a colour, fading out.
local function bodyGhost(character, color, life, startT)
	if not VFXLib.acquire() then
		return
	end
	local parts = {}
	for _, name in ipairs(BODY) do
		local limb = character:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			table.insert(parts, VFXLib.part({ Size = limb.Size * 1.02, CFrame = limb.CFrame, Color = color, Material = Enum.Material.Neon, Transparency = startT or 0.45 }))
		end
	end
	VFXLib.animate(life or 0.25, function(a)
		for _, g in ipairs(parts) do
			g.Transparency = (startT or 0.45) + (1 - (startT or 0.45)) * a
		end
	end, function()
		for _, g in ipairs(parts) do
			g:Destroy()
		end
		VFXLib.release()
	end)
end

local function groundRing(position, radius, color, time)
	local ring = VFXLib.part({ Size = Vector3.new(0.2, 1, 1), Color = color, Material = Enum.Material.Neon, Transparency = 0.3, Shape = Enum.PartType.Cylinder })
	VFXLib.animate(time or 0.3, function(a)
		local d = radius * 2 * VFXLib.easeOut(a)
		ring.Size = Vector3.new(0.2, d, d)
		ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Transparency = 0.3 + 0.7 * a
	end, function()
		ring:Destroy()
	end)
end

local function onDashFX(data)
	local character = data.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local dir = data.Direction
	local color, light = dashColour(character)
	local time = data.Time or 0.21
	TuskAnimation.play(character, dashPose(root, dir))
	local feet = root.Position - Vector3.new(0, 2.6, 0)
	-- Kick-off: a dust burst behind, a wind ring at the feet.
	VFXLib.burst(feet, { Count = 14, Texture = VFXLib.Textures.Smoke, Color = Color3.fromRGB(215, 190, 150), LightEmission = 0, Speed = 16, Lifetime = 0.6, Spread = 60, Direction = -dir })
	groundRing(feet + Vector3.new(0, 0.1, 0), 3.2, light, 0.28)
	VFXLib.sound(sounds.Swing, root, 0.5, 0.8)
	if data.Cancel then
		-- Dash-cancelled out of an attack: a sharp white flash.
		TuskVFX.CreateImpactStar(root.Position, { Size = 2.4, Rays = 6, Color = Color3.new(1, 1, 1), Color2 = color, Duration = 0.1 })
	end
	-- Coloured body afterimages along the way, and wind streaks.
	local steps = 5
	for i = 0, steps - 1 do
		task.delay(i * time / steps, function()
			if root.Parent then
				bodyGhost(character, i % 2 == 0 and color or light, 0.22, 0.4 + i * 0.06)
			end
		end)
	end
	local start = root.Position
	for k = 1, 3 do
		local streak = VFXLib.part({ Size = Vector3.new(0.12, 0.12, 1), Color = light, Material = Enum.Material.Neon, Transparency = 0.3 })
		local offset = Vector3.new((math.random() - 0.5) * 2, (k - 2) * 0.9, (math.random() - 0.5) * 2)
		VFXLib.animate(time + 0.2, function(a)
			if not root.Parent then
				return
			end
			local from, to = start + offset, root.Position + offset - dir * 1.5
			local len = math.max((to - from).Magnitude, 0.2)
			streak.Size = Vector3.new(0.12, 0.12, len)
			streak.CFrame = CFrame.lookAt((from + to) / 2, to)
			streak.Transparency = 0.3 + 0.7 * math.max(0, (a - 0.5) * 2)
		end, function()
			streak:Destroy()
		end)
	end
	-- Landing: a puff where the dash ends.
	task.delay(time, function()
		if root.Parent then
			VFXLib.burst(root.Position - Vector3.new(0, 2.6, 0), { Count = 8, Texture = VFXLib.Textures.Smoke, Color = Color3.fromRGB(215, 190, 150), LightEmission = 0, Speed = 8, Lifetime = 0.5, Spread = 80, Direction = dir })
		end
	end)
	if character ~= player.Character then
		return
	end
	-- Our own character: move it ourselves (we own its physics).
	local speed = data.Speed or 80
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	VFXLib.animate(time, function()
		if not root.Parent or (humanoid and humanoid.Health <= 0) then
			return
		end
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, math.min(v.Y, 0), dir.Z * speed)
	end, function()
		if root.Parent then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(dir.X * 14, v.Y, dir.Z * 14)
		end
	end)
	CameraFX.fovPunch(6, 0.22)
	CameraFX.speedLines(time + 0.15, light)
end

-- PERFECT DODGE: a gold ghost left where the attack landed, the word over
-- their head; for the dodger a flash of slowed-down blue and COUNTER READY.
local function floatingText(character, text, color)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Adornee = head
	bb.Size = UDim2.fromOffset(220, 50)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = bb
	bb.Parent = VFXLib.Folder
	VFXLib.animate(0.9, function(a)
		bb.StudsOffset = Vector3.new(0, 2.6 + a * 1.2, 0)
		label.TextTransparency = math.max(0, (a - 0.6) / 0.4)
		label.TextStrokeTransparency = math.max(0, (a - 0.6) / 0.4)
	end, function()
		bb:Destroy()
	end)
end

local function onPerfectDodge(data)
	local character = data.Character
	if not character then
		return
	end
	bodyGhost(character, GOLD, 0.55, 0.2)
	if data.Position then
		groundRing(data.Position - Vector3.new(0, 2.4, 0), 5, GOLD, 0.35)
		TuskVFX.CreateImpactStar(data.Position, { Size = 3.2, Rays = 8, Color = GOLD, Color2 = Color3.new(1, 1, 1), Duration = 0.14 })
	end
	floatingText(character, "PERFECT DODGE", GOLD)
	if character == player.Character then
		TuskVFX.ScreenTint(0.25, { Tint = Color3.fromRGB(200, 225, 255), Saturation = -0.5, Brightness = 0.06, Contrast = 0.1, FadeOut = 0.3 })
		CameraFX.fovPunch(-7, 0.3)
		VFXLib.sound(sounds.ChargeFull, workspace.CurrentCamera, 0.5, 1.3)
		task.delay(0.35, function()
			floatingText(character, "COUNTER READY", Color3.fromRGB(255, 240, 200))
		end)
	elseif data.Attacker and data.Attacker == player.Character then
		CameraFX.shake(0.25, 0.1)
	end
end

---------------------------------------------------------------------------
-- Block visuals
---------------------------------------------------------------------------
-- A curved barrier of glowing tiles (5 across, 4 high) in front of the body,
-- in the character's colour. Each tile: { Part, Offset, Col, Row }.
local COLS, ROWS = 5, 4
local TILE_W, TILE_H, GAP = 0.78, 0.9, 0.08
local CRACK = Color3.fromRGB(255, 80, 70)

local function colourOf(character)
	local act = character:GetAttribute("TuskAct")
	local pal = act and Common.palette(act)
	return pal and pal.Main or SHIELD
end

local function makeShield(character)
	local m = Instance.new("Model")
	m.Name = "BlockShield"
	m.Parent = VFXLib.Folder
	local color = colourOf(character)
	local tiles = {}
	for col = 1, COLS do
		for row = 1, ROWS do
			local x = (col - (COLS + 1) / 2)
			local y = (row - (ROWS + 1) / 2)
			-- Curve round the body: outer columns angle back.
			local yaw = -x * 0.32
			local offset = CFrame.new(0, 0.3 + y * (TILE_H + GAP), 0) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -2.3)
			local p = VFXLib.part({ Material = Enum.Material.ForceField, Color = color, Size = Vector3.new(TILE_W, TILE_H, 0.12), Transparency = 0.1 })
			p.Parent = m
			table.insert(tiles, { Part = p, Offset = offset, Col = col, Row = row, Seed = math.random() * 10, Flash = 0 })
		end
	end
	-- A brighter rim along the top and bottom edges.
	local rims = {}
	for _, y in ipairs({ -1, 1 }) do
		for col = 1, COLS do
			local x = (col - (COLS + 1) / 2)
			local offset = CFrame.new(0, 0.3 + y * (ROWS / 2) * (TILE_H + GAP), 0) * CFrame.Angles(0, -x * 0.32, 0) * CFrame.new(0, 0, -2.3)
			local p = VFXLib.part({ Material = Enum.Material.Neon, Color = color:Lerp(Color3.new(1, 1, 1), 0.4), Size = Vector3.new(TILE_W + GAP, 0.08, 0.14), Transparency = 0.2 })
			p.Parent = m
			table.insert(rims, { Part = p, Offset = offset })
		end
	end
	return m, tiles, rims, color
end

local function placeShield(entry, root, t)
	local maxMeter = (TuskConfig.Defense and TuskConfig.Defense.MaxMeter) or 100
	local k = math.clamp((entry.Character:GetAttribute("BlockMeter") or maxMeter) / maxMeter, 0, 1)
	-- It builds in from the middle over the first moment.
	local build = math.clamp((t - entry.Born) / 0.16, 0, 1)
	local ripple = entry.Ripple -- { At = time, Col, Row }
	for i, tile in ipairs(entry.Tiles) do
		local p = tile.Part
		-- How "broken" this tile is: as the guard drains, tiles fail from the edges in.
		local edge = math.abs(tile.Col - (COLS + 1) / 2) / ((COLS - 1) / 2) * 0.5 + (tile.Row == 1 and 0.3 or 0)
		local broken = math.clamp((1 - k) * 1.6 - (1 - edge) * 0.7, 0, 1)
		local gone = broken > 0.85 and (math.floor(t * 10 + tile.Seed) % 3 == 0)
		-- Ripple from a blocked hit travels across the tiles.
		local wave = 0
		if ripple then
			local dist = math.sqrt((tile.Col - ripple.Col) ^ 2 + (tile.Row - ripple.Row) ^ 2)
			local front = (t - ripple.At) * 14
			wave = math.max(0, 1 - math.abs(front - dist)) * math.max(0, 1 - (t - ripple.At) / 0.5)
		end
		tile.Flash = math.max(0, tile.Flash - 0.08)
		local bob = math.sin(t * 6 + tile.Seed) * 0.03
		local pop = 1 + wave * 0.25 + tile.Flash * 0.3
		p.Size = Vector3.new(TILE_W * build * pop, TILE_H * build * pop, 0.12)
		p.CFrame = root.CFrame * tile.Offset * CFrame.new(0, bob, -wave * 0.3)
		local shimmer = 0.1 + 0.08 * math.sin(t * 4 + tile.Seed * 2)
		p.Transparency = gone and 1 or math.clamp(shimmer + broken * 0.35 - tile.Flash * 0.3, 0, 0.9)
		local color = entry.Color:Lerp(CRACK, broken)
		p.Color = color:Lerp(Color3.new(1, 1, 1), math.max(tile.Flash, wave * 0.6))
		-- A cracked tile jitters.
		if broken > 0.5 then
			p.CFrame = p.CFrame * CFrame.new((math.random() - 0.5) * 0.06, (math.random() - 0.5) * 0.06, 0)
		end
	end
	for _, rim in ipairs(entry.Rims) do
		rim.Part.CFrame = root.CFrame * rim.Offset
		rim.Part.Size = Vector3.new((TILE_W + GAP) * build, 0.08, 0.14)
		rim.Part.Color = entry.Color:Lerp(CRACK, 1 - k):Lerp(Color3.new(1, 1, 1), 0.4)
	end
	-- Low guard: sag into a weak, shaky stance (and back up when it refills).
	local weak = k < 0.35
	if weak ~= entry.Weak then
		entry.Weak = weak
		TuskAnimation.hold(entry.Character, weak and "BlockWeak" or "BlockPose")
	end
end

local function startBlock(character)
	local shield, tiles, rims, color = makeShield(character)
	local entry = { Character = character, Shield = shield, Tiles = tiles, Rims = rims, Color = color, Born = os.clock(), Previous = TuskAnimation.currentHold(character) }
	blocking[character] = entry
	TuskAnimation.hold(character, "BlockPose")
	TuskAnimation.play(character, "BlockRaise")
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		local front = (root.CFrame * CFrame.new(0, 0.3, -2.3)).Position
		VFXLib.burst(front, { Count = 8, Color = color, Speed = 10, Lifetime = 0.25 })
	end
	return entry
end

-- Release: the tiles scatter outward and fade.
local function scatterTiles(entry, speed, life, color)
	local root = entry.Character:FindFirstChild("HumanoidRootPart")
	local center = root and (root.CFrame * CFrame.new(0, 0.3, -2)).Position
	for _, tile in ipairs(entry.Tiles) do
		local p = tile.Part
		if p.Parent then
			local from = p.CFrame
			local away = center and (p.Position - center) or Vector3.new(0, 1, 0)
			away = (away.Magnitude > 0.01 and away.Unit or Vector3.new(0, 1, 0)) + Vector3.new(0, 0.4, 0)
			local spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 8
			if color then
				p.Color = color
				p.Material = Enum.Material.Neon
			end
			VFXLib.animate(life, function(a)
				p.CFrame = (from + away * speed * a - Vector3.new(0, (color and 12 or 0) * a * a, 0)) * CFrame.Angles(spin.X * a, spin.Y * a, spin.Z * a)
				p.Transparency = math.max(p.Transparency, a)
			end, function()
				p:Destroy()
			end)
		end
	end
	for _, rim in ipairs(entry.Rims) do
		rim.Part:Destroy()
	end
	task.delay(life + 0.05, function()
		entry.Shield:Destroy()
	end)
end

local function stopBlock(character, entry)
	blocking[character] = nil
	if not entry.Shattered then
		scatterTiles(entry, 2, 0.18)
	end
	TuskAnimation.stopHold(character, entry.Weak and "BlockWeak" or "BlockPose")
	if entry.Previous and entry.Previous ~= "BlockPose" and entry.Previous ~= "BlockWeak" and character.Parent then
		TuskAnimation.hold(character, entry.Previous) -- back to the character's stance
	end
end

-- A hit lands on someone's block: they recoil, the struck tile lights up,
-- a ripple runs across the barrier and sparks fly off it.
local function onBlockedHit(data)
	local victim = data.Victim
	local entry = victim and blocking[victim]
	local root = victim and victim:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	TuskAnimation.play(victim, (entry and entry.Weak) and "BlockHitWeak" or "BlockHit")
	local at = data.Position or (root.CFrame * CFrame.new(0, 0.3, -2.3)).Position
	if entry then
		-- The tile nearest the impact.
		local best, bestD
		for _, tile in ipairs(entry.Tiles) do
			local d = (tile.Part.Position - at).Magnitude
			if not bestD or d < bestD then
				best, bestD = tile, d
			end
		end
		if best then
			best.Flash = 1
			entry.Ripple = { At = os.clock(), Col = best.Col, Row = best.Row }
			at = best.Part.Position
		end
	end
	local color = entry and entry.Color or SHIELD
	local out = root.CFrame.LookVector
	VFXLib.burst(at, { Count = 14, Color = color:Lerp(Color3.new(1, 1, 1), 0.4), Speed = 30, Lifetime = 0.25, Spread = 55, Direction = out, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }) })
	TuskVFX.CreateRotationalShockwave(CFrame.lookAt(at, at + out) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = 2.2, Layers = 1, Color = color, Color2 = Color3.new(1, 1, 1), Particles = 0, Width = 0.1, Duration = 0.2 })
	VFXLib.sound(sounds.NailImpact, at, 0.35, 1.6)
	if victim == player.Character then
		CameraFX.shake(0.18, 0.12)
	end
end

-- Who's blocking: start / stop their barrier.
local function stepBlocks()
	local t = os.clock()
	local seen = {}
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and character:GetAttribute("Blocking") then
			seen[character] = true
			local entry = blocking[character] or startBlock(character)
			placeShield(entry, root, t)
		end
	end
	for character, entry in pairs(blocking) do
		if not seen[character] then
			stopBlock(character, entry)
		end
	end
end

local function popText(position, text, color)
	local carrier = VFXLib.anchor(CFrame.new(position + Vector3.new(0, 3, 0)), 1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = carrier
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local start = carrier.Position
	VFXLib.animate(0.9, function(a)
		carrier.Position = start + Vector3.new(0, a * 2, 0)
		label.TextTransparency = math.max(0, (a - 0.6) / 0.4)
		label.TextStrokeTransparency = label.TextTransparency
		local pop = a < 0.12 and 1 + (0.12 - a) * 5 or 1
		gui.Size = UDim2.fromOffset(220 * pop, 60 * pop)
	end)
end

local function onParry(data)
	local defender = data.Defender
	local root = defender and defender:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	TuskAnimation.play(defender, "Parry")
	local entry = blocking[defender]
	if entry then
		for _, tile in ipairs(entry.Tiles) do
			tile.Flash = 1
			tile.Part.Color = GOLD
		end
		entry.Color = GOLD
		task.delay(0.35, function()
			entry.Color = colourOf(defender)
		end)
	end
	local pos = (root.CFrame * CFrame.new(0, 0.5, -1.8)).Position
	TuskVFX.CreateImpactStar(pos, { Size = 7, Rays = 10, Color = GOLD, Color2 = Color3.new(1, 1, 1), Duration = 0.3 })
	VFXLib.burst(pos, { Count = 24, Color = GOLD, Speed = 40, Lifetime = 0.4 })
	VFXLib.flash(pos, GOLD, 5, 20, 0.25)
	TuskVFX.CreateRotationalShockwave(CFrame.lookAt(pos, pos + root.CFrame.LookVector) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = 4, Layers = 2, Color = GOLD, Color2 = Color3.new(1, 1, 1), Particles = 0.5, Width = 0.2, Duration = 0.3 })
	popText(root.Position, "PERFECT!", GOLD)
	VFXLib.sound(sounds.Finisher, pos, 0.6, 1.4)
	if data.Attacker then
		TuskAnimation.play(data.Attacker, "GuardBreak")
	end
	if defender == player.Character or data.Attacker == player.Character then
		CameraFX.impactFrame(GOLD)
		CameraFX.shake(0.4, 0.25)
	end
end

local function onGuardBreak(data)
	local victim = data.Victim
	local root = victim and victim:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	TuskAnimation.play(victim, "GuardBreak")
	local entry = blocking[victim]
	if entry and not entry.Shattered then
		-- The barrier's tiles shatter and fly.
		entry.Shattered = true
		scatterTiles(entry, 14, 0.7, Color3.fromRGB(255, 120, 100))
	end
	local pos = (root.CFrame * CFrame.new(0, 0.5, -1.8)).Position
	-- The shield shatters into blue shards.
	VFXLib.burst(pos, { Count = 30, Color = SHIELD, Speed = 35, Lifetime = 0.6, Acceleration = Vector3.new(0, -40, 0) })
	VFXLib.burst(pos, { Count = 10, Color = SHIELD_LIGHT, Speed = 12, Lifetime = 0.25, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) }) })
	popText(root.Position, "GUARD BREAK", Color3.fromRGB(255, 90, 80))
	VFXLib.sound(sounds.NailImpact, pos, 0.6, 0.7)
	if victim == player.Character then
		CameraFX.shake(0.6, 0.4)
	end
end

---------------------------------------------------------------------------
function DefenseClient.init()
	Request = Net.get("TuskRequest")
	local keys = TuskConfig.Keys
	ContextActionService:BindAction("SpinBlock", onBlock, true, keys.Block.Keyboard, keys.Block.Gamepad)
	ContextActionService:SetTitle("SpinBlock", "BLOCK")
	ContextActionService:SetPosition("SpinBlock", UDim2.new(1, -170, 1, -70))
	ContextActionService:BindAction("SpinDash", onDashInput, true, keys.Dash.Keyboard, keys.Dash.Gamepad)
	ContextActionService:SetTitle("SpinDash", "DASH")
	ContextActionService:SetPosition("SpinDash", UDim2.new(1, -95, 1, -165))
	player.CharacterAdded:Connect(function()
		blockHeld = false
	end)
	Net.get("TuskFX").OnClientEvent:Connect(function(name, data)
		if name == "Dash" and typeof(data) == "table" then
			onDashFX(data)
		elseif name == "PerfectDodge" and typeof(data) == "table" then
			onPerfectDodge(data)
		end
	end)
	Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
		if typeof(data) ~= "table" then
			return
		end
		if name == "Hit" and data.Blocked then
			onBlockedHit(data)
		elseif name == "Parry" then
			onParry(data)
		elseif name == "GuardBreak" then
			onGuardBreak(data)
		end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc = acc + dt
		for character, entry in pairs(blocking) do
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				placeShield(entry, root, os.clock())
			end
		end
		if acc >= 0.1 then
			acc = 0
			stepBlocks()
		end
	end)
end

return DefenseClient
end

-- ======================================================================
-- MODULE: Fighters
-- ======================================================================
__modules["Fighters"] = function()
--[[
	Fighters  (StarterPlayerScripts.SpinClient.Fighters)

	Everyone who can use a Stand: the players plus the Stand-user NPCs
	(StandBots, tagged "SpinFighter" on the server). Returned in the same
	shape as Players:GetPlayers() ({ Character = model }), so visual code
	that loops over players draws the NPCs' Stands and effects too.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Fighters = {}
Fighters.Tag = "SpinFighter"

function Fighters.list()
	local out = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(out, player)
	end
	for _, model in ipairs(CollectionService:GetTagged(Fighters.Tag)) do
		if model.Parent then
			table.insert(out, { Character = model })
		end
	end
	return out
end

return Fighters
end

-- ======================================================================
-- MODULE: HitFX
-- ======================================================================
__modules["HitFX"] = function()
--[[
	HitFX  (StarterPlayerScripts.SpinClient.HitFX)
	Feedback for every hit in the game (any character):
	  * victim flash (white, or blue when blocked) + camera shake for the victim
	  * floating damage numbers for the attacker
	Driven by the shared "Hit" / "Damage" events from CombatAdapter.
]]

local Players = game:GetService("Players")

local Shared = nil -- (bundled: modules are inlined)
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")

local TuskVFX = __require("TuskVFX")

local HitFX = {}
local localPlayer = Players.LocalPlayer
local colors = {
	Gold = Color3.fromRGB(255, 196, 56),
	Perfect = Color3.fromRGB(255, 250, 210),
	GoldLight = Color3.fromRGB(255, 238, 160),
}

local function onHit(data)
	if not data.Victim then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Adornee = data.Victim
	highlight.FillColor = data.Blocked and Color3.fromRGB(140, 200, 255) or Color3.new(1, 1, 1)
	highlight.OutlineColor = data.Blocked and Color3.fromRGB(80, 160, 255) or colors.Gold
	highlight.FillTransparency = 0.3
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = VFXLib.Folder
	VFXLib.animate(0.18, function(a)
		highlight.FillTransparency = 0.3 + 0.7 * a
		highlight.OutlineTransparency = a
	end, function()
		highlight:Destroy()
	end)
	-- Starburst coloured by who landed it: cyan for Johnny, green for Gyro, blue for Diego, bamboo green for Pork Pie Hat Kid.
	local source = tostring(data.Source or "")
	local starColor = Color3.fromRGB(90, 230, 255)
	if source:sub(1, 4) == "Gyro" then
		starColor = Color3.fromRGB(120, 225, 95)
	elseif source:sub(1, 7) == "DiegoAU" then
		starColor = Color3.fromRGB(236, 196, 70)
	elseif source:sub(1, 5) == "Diego" then
		starColor = Color3.fromRGB(60, 120, 255)
	elseif source:sub(1, 7) == "PorkPie" then
		starColor = Color3.fromRGB(165, 215, 80)
	elseif source:sub(1, 7) == "Sandman" then
		starColor = Color3.fromRGB(245, 185, 80)
	elseif source:sub(1, 11) == "MountainTim" then
		starColor = Color3.fromRGB(214, 156, 84)
	elseif source:sub(1, 8) == "HotPants" then
		starColor = Color3.fromRGB(242, 140, 172)
	elseif source:sub(1, 9) == "Blackmore" then
		starColor = Color3.fromRGB(110, 180, 255)
	elseif source:sub(1, 9) == "Valentine" then
		starColor = Color3.fromRGB(120, 170, 255)
	elseif source:sub(1, 3) == "Axl" then
		starColor = Color3.fromRGB(214, 60, 70)
	end
	if data.Perfect then
		starColor = colors.Gold
	end
	if data.Position and not data.Blocked then
		TuskVFX.CreateImpactStar(data.Position, { Size = 2.2 + (data.Level or 1) * 0.9, Rays = 6 + (data.Level or 1), Color = starColor, Color2 = Color3.new(1, 1, 1), Duration = 0.18 + (data.Level or 1) * 0.03 })
		-- Sparks thrown away from the attacker, a quick shock ring, a white pop.
		local away
		local attacker = data.AttackerId and Players:GetPlayerByUserId(data.AttackerId)
		local ar = attacker and attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
		if ar then
			local d = data.Position - ar.Position
			away = d.Magnitude > 0.1 and d.Unit or nil
		end
		VFXLib.burst(data.Position, { Count = 10, Color = starColor, Speed = 34, Lifetime = 0.28, Spread = away and 40 or 180, Direction = away, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }) })
		VFXLib.burst(data.Position, { Count = 4, Color = Color3.new(1, 1, 1), Speed = 6, Lifetime = 0.12, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) }) })
		local look = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or data.Position + Vector3.new(0, 0, 1)
		TuskVFX.CreateRotationalShockwave(CFrame.lookAt(data.Position, look) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = 2.6, Layers = 1, Color = starColor, Color2 = Color3.new(1, 1, 1), Particles = 0, Width = 0.12, Duration = 0.18 })
		-- Your own hits kick the camera a little.
		if data.AttackerId == localPlayer.UserId then
			CameraFX.shake(0.12 + (data.Level or 1) * 0.05, 0.12)
		end
	end
	if data.Blocked then
		VFXLib.burst(data.Position, { Count = 12, Color = Color3.fromRGB(150, 210, 255), Speed = 25, Lifetime = 0.3 })
	end
	if localPlayer.Character and data.Victim == localPlayer.Character then
		CameraFX.shake(0.4 + (data.Level or 1) * 0.2, 0.3)
		if data.Perfect then
			CameraFX.impactFrame(colors.GoldLight)
		end
	end
end

-- Floating damage number, only for the attacker.
local function onDamage(data)
	local carrier = VFXLib.anchor(CFrame.new(data.Position + Vector3.new(math.random() - 0.5, 2, math.random() - 0.5)), 1.2)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 60)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = carrier
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.Rotation = (math.random() - 0.5) * 16
	label.Text = data.Blocked and ("BLOCKED " .. data.Amount) or (tostring(data.Amount) .. (data.Perfect and "!" or ""))
	label.TextColor3 = data.Blocked and Color3.fromRGB(170, 200, 230) or (data.Perfect and colors.Perfect or colors.Gold)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(60, 25, 0)
	label.Parent = billboard
	local start = carrier.Position
	local drift = Vector3.new((math.random() - 0.5) * 2, 0, (math.random() - 0.5) * 2)
	-- Bigger hits get bigger, redder numbers.
	local amount = tonumber(data.Amount) or 0
	local big = math.clamp((amount - 4) / 10, 0, 1)
	if not data.Blocked and not data.Perfect then
		label.TextColor3 = colors.Gold:Lerp(Color3.fromRGB(255, 80, 60), big)
	end
	local scale = 1 + big * 0.6
	VFXLib.animate(1, function(a)
		carrier.Position = start + drift * a + Vector3.new(0, a * 3 - a * a * 1.2, 0)
		label.TextTransparency = math.max(0, (a - 0.6) / 0.4)
		label.TextStrokeTransparency = label.TextTransparency
		local pop = a < 0.1 and (1 + (0.1 - a) * 4) or 1
		billboard.Size = UDim2.fromOffset(160 * pop * scale * (data.Perfect and 1.3 or 1), 60 * pop * scale * (data.Perfect and 1.3 or 1))
	end)
end

function HitFX.init()
	Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
		if name == "Hit" then
			onHit(data)
		elseif name == "Damage" then
			onDamage(data)
		end
	end)
end

return HitFX
end

-- ======================================================================
-- MODULE: HorseModel
-- ======================================================================
__modules["HorseModel"] = function()
--[[
	HorseModel  (ReplicatedStorage.SpinShared.HorseModel)

	A blocky racehorse for the Steel Ball Run, built from parts (no uploads):
	a long body, an arched neck with a mane, a head with a white blaze, ears
	and a dark muzzle, a swishing tail, four legs with white socks and
	hooves, and full tack: a red saddle blanket, a brown saddle with a horn,
	stirrups and reins.

	HorseModel.build(coat, mane, opts) -> model (PrimaryPart "Body", facing
	-Z, body centre at the origin, hooves 3.85 studs below it, the top of
	the saddle SaddleTop above it). opts (all optional):
	  Width     body width (default 1.9: slim, so a rider's legs go round it)
	  Blanket   saddle blanket colour      Saddle  saddle / tack colour
	  Material  coat material (e.g. Metal for the Golden Steed)
	  Socks     sock colour (false: no socks)
	The server builds race and ride horses; the shop builds a preview. Every limb is
	joined to the body with a Weld; clients animate the gallop by changing
	those welds' C0 (RaceClient). Each animated part carries attributes:
	  Joint (Vector3, where it pivots on the body) and Drop (studs from the
	  pivot down to the part's centre).
]]

local HorseModel = {}
HorseModel.HoofDepth = 3.85 -- studs from the body centre down to the ground
HorseModel.SaddleTop = 1.37 -- studs from the body centre up to the top of the saddle

local function part(model, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.Anchored = false
	p.Parent = model
	return p
end

local function weld(model, parent, name, size, color, cf, material)
	local p = part(model, name, size, color, material)
	local w = Instance.new("Weld")
	w.Name = name .. "Weld"
	w.Part0 = parent
	w.Part1 = p
	w.C0 = cf
	w.Parent = p
	p.CFrame = parent.CFrame * cf
	return p, w
end

-- A part that swings round a joint on the body (legs, tail, neck).
local function jointed(model, body, name, size, color, joint, drop, angle)
	local p, w = weld(model, body, name, size, color, CFrame.new(joint) * CFrame.Angles(angle or 0, 0, 0) * CFrame.new(0, -drop, 0))
	p:SetAttribute("Joint", joint)
	p:SetAttribute("Drop", drop)
	p:SetAttribute("Rest", angle or 0)
	return p, w
end

function HorseModel.build(coat, mane, opts)
	opts = opts or {}
	coat = coat or Color3.fromRGB(120, 76, 44)
	mane = mane or Color3.fromRGB(40, 26, 18)
	local W = opts.Width or 1.9
	local k = W / 2.2 -- how much narrower than the old 2.2-wide body
	local shade = coat:Lerp(Color3.new(0, 0, 0), 0.2)
	local white = opts.SockColor or (typeof(opts.Socks) == "Color3" and opts.Socks) or Color3.fromRGB(240, 238, 232)
	local sockStyle = opts.SockStyle or (opts.Socks == false and "None" or "Two")
	local marking = opts.Marking or "Blaze"
	local hoof = Color3.fromRGB(46, 40, 36)
	local leather = opts.Saddle or Color3.fromRGB(96, 58, 32)
	local leatherMaterial = opts.SaddleMaterial
	local blanket = opts.Blanket or Color3.fromRGB(170, 40, 40)
	local metal = Color3.fromRGB(180, 182, 188)
	local coatMaterial = opts.Material

	local model = Instance.new("Model")
	model.Name = "Horse"
	local body = part(model, "Body", Vector3.new(W, 2.0, 5.0), coat, coatMaterial)
	body.CFrame = CFrame.new()
	model.PrimaryPart = body
	-- Rounded barrel: chest and rump blocks, a belly.
	weld(model, body, "Chest", Vector3.new(W + 0.1, 2.1, 1.2), coat, CFrame.new(0, 0.05, -2.3))
	weld(model, body, "Rump", Vector3.new(W + 0.1, 2.1, 1.3), coat, CFrame.new(0, 0.12, 2.2))
	weld(model, body, "Belly", Vector3.new(W - 0.3, 0.4, 3.8), shade, CFrame.new(0, -1.05, 0))
	if coatMaterial then
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") and p ~= body then
				p.Material = coatMaterial
			end
		end
	end

	-- Neck (arched forward), mane along its top, head.
	local neck = jointed(model, body, "Neck", Vector3.new(1.1, 2.6, 1.3), coat, Vector3.new(0, 0.6, -2.6), -1.1, -0.55)
	weld(model, neck, "Mane", Vector3.new(0.35, 2.6, 0.5), mane, CFrame.new(0, 0.05, 0.6))
	local head = weld(model, neck, "Head", Vector3.new(1.0, 1.0, 2.1), coat, CFrame.new(0, 1.35, -0.75) * CFrame.Angles(-0.35, 0, 0))
	weld(model, head, "Muzzle", Vector3.new(0.92, 0.75, 0.6), shade, CFrame.new(0, -0.12, -1.2))
	-- Face marking.
	local faceWhite = Color3.fromRGB(240, 238, 232)
	if marking == "Blaze" then
		weld(model, head, "Blaze", Vector3.new(0.3, 0.06, 1.6), faceWhite, CFrame.new(0, 0.52, -0.3))
	elseif marking == "Star" then
		weld(model, head, "Star", Vector3.new(0.32, 0.06, 0.32), faceWhite, CFrame.new(0, 0.52, 0.2) * CFrame.Angles(0, math.pi / 4, 0))
	elseif marking == "Stripe" then
		weld(model, head, "Stripe", Vector3.new(0.14, 0.06, 1.7), faceWhite, CFrame.new(0, 0.52, -0.35))
	elseif marking == "Bald" then
		weld(model, head, "BaldFace", Vector3.new(0.8, 0.06, 1.9), faceWhite, CFrame.new(0, 0.52, -0.3))
		weld(model, head, "BaldMuzzle", Vector3.new(0.94, 0.4, 0.62), faceWhite, CFrame.new(0, 0.12, -1.2))
	end
	weld(model, head, "Forelock", Vector3.new(0.5, 0.2, 0.5), mane, CFrame.new(0, 0.6, 0.45))
	for _, side in ipairs({ -1, 1 }) do
		weld(model, head, "Ear", Vector3.new(0.2, 0.5, 0.22), coat, CFrame.new(side * 0.32, 0.72, 0.75) * CFrame.Angles(0, 0, side * -0.2))
		weld(model, head, "Eye", Vector3.new(0.06, 0.16, 0.16), Color3.fromRGB(20, 16, 14), CFrame.new(side * 0.51, 0.18, -0.1))
		weld(model, head, "Nostril", Vector3.new(0.06, 0.12, 0.12), Color3.fromRGB(30, 22, 18), CFrame.new(side * 0.47, -0.2, -1.42))
		-- Bridle straps.
		weld(model, head, "Bridle", Vector3.new(0.04, 0.9, 0.08), leather, CFrame.new(side * 0.52, 0.1, 0.1), leatherMaterial)
	end
	weld(model, head, "Noseband", Vector3.new(1.0, 0.1, 0.1), leather, CFrame.new(0, -0.05, -0.85), leatherMaterial)

	-- Tail.
	local tail = jointed(model, body, "Tail", Vector3.new(0.5, 2.3, 0.5), mane, Vector3.new(0, 0.7, 2.85), 1.1, -0.55)
	weld(model, tail, "TailTip", Vector3.new(0.6, 0.6, 0.6), mane, CFrame.new(0, -1.2, 0.05))

	-- Legs: thigh-to-hoof, socks by style, hooves.
	local socksOn = {
		None = {},
		Two = { LegFL = true, LegBR = true },
		Front = { LegFL = true, LegFR = true },
		Back = { LegBL = true, LegBR = true },
		Four = { LegFL = true, LegFR = true, LegBL = true, LegBR = true },
	}
	local on = socksOn[sockStyle] or socksOn.Two
	local legs = {
		{ "LegFL", Vector3.new(-0.6 * k, -0.75, -1.9) },
		{ "LegFR", Vector3.new(0.6 * k, -0.75, -1.9) },
		{ "LegBL", Vector3.new(-0.6 * k, -0.75, 1.9) },
		{ "LegBR", Vector3.new(0.6 * k, -0.75, 1.9) },
	}
	for _, l in ipairs(legs) do
		local leg = jointed(model, body, l[1], Vector3.new(0.55, 2.8, 0.6), coat, l[2], 1.4, 0)
		weld(model, leg, "Thigh", Vector3.new(0.7, 1.0, 0.75), coat, CFrame.new(0, 0.85, 0))
		if on[l[1]] then
			weld(model, leg, "Sock", Vector3.new(0.6, 0.7, 0.65), white, CFrame.new(0, -0.95, 0))
		end
		weld(model, leg, "Hoof", Vector3.new(0.62, 0.32, 0.7), hoof, CFrame.new(0, -1.5, -0.04))
	end

	-- Tack: blanket, saddle with a horn, stirrups, reins.
	weld(model, body, "Blanket", Vector3.new(W + 0.2, 0.14, 2.3), blanket, CFrame.new(0, 1.04, -0.1))
	weld(model, body, "BlanketEdge", Vector3.new(W + 0.3, 0.6, 0.1), blanket:Lerp(Color3.new(1, 1, 1), 0.2), CFrame.new(0, 0.8, -1.25))
	for _, side in ipairs({ -1, 1 }) do
		weld(model, body, "BlanketSide", Vector3.new(0.1, 0.8, 2.2), blanket, CFrame.new(side * (W / 2 + 0.06), 0.6, -0.1))
	end
	weld(model, body, "Saddle", Vector3.new(W - 0.4, 0.3, 1.7), leather, CFrame.new(0, 1.22, -0.1), leatherMaterial)
	weld(model, body, "Cantle", Vector3.new(1.4, 0.35, 0.25), leather, CFrame.new(0, 1.45, 0.65), leatherMaterial)
	weld(model, body, "Horn", Vector3.new(0.25, 0.45, 0.25), leather, CFrame.new(0, 1.55, -0.8), leatherMaterial)
	for _, side in ipairs({ -1, 1 }) do
		weld(model, body, "Strap", Vector3.new(0.05, 1.3, 0.12), leather, CFrame.new(side * (W / 2 + 0.13), 0.55, -0.1), leatherMaterial)
		weld(model, body, "Stirrup", Vector3.new(0.12, 0.12, 0.5), metal, CFrame.new(side * (W / 2 + 0.16), -0.15, -0.1), Enum.Material.Metal)
		weld(model, body, "Rein", Vector3.new(0.05, 0.05, 3.4), leather, CFrame.new(side * 0.45, 2.0, -2.4) * CFrame.Angles(0.33, 0, 0))
	end
	return model
end

-- The horse a stable selection describes (used by the server and the shop's
-- preview, so they always match). cat = TuskConfig.Horses; sel = { Coat,
-- Mane, Blanket, Saddle, Marking, Socks }.
-- Returns coat colour, mane colour, opts for HorseModel.build.
local function pick(list, id)
	for _, item in ipairs(list or {}) do
		if item.Id == id then
			return item
		end
	end
	return (list or {})[1]
end

-- A player's stable selection, from their attributes (HorseCoat, HorseMane,
-- HorseBlanket, HorseSaddle, HorseMarking, HorseSocks).
function HorseModel.selectionOf(player)
	return {
		Coat = player and player:GetAttribute("HorseCoat"),
		Mane = player and player:GetAttribute("HorseMane"),
		Blanket = player and player:GetAttribute("HorseBlanket"),
		Saddle = player and player:GetAttribute("HorseSaddle"),
		Marking = player and player:GetAttribute("HorseMarking"),
		Socks = player and player:GetAttribute("HorseSocks"),
	}
end

function HorseModel.lookFrom(cat, sel)
	cat, sel = cat or {}, sel or {}
	local coat = pick(cat.Coats, sel.Coat) or {}
	local maneItem = pick(cat.Manes, sel.Mane)
	local blanket = pick(cat.Blankets, sel.Blanket)
	local saddle = pick(cat.Saddles, sel.Saddle)
	local marking = pick(cat.Markings, sel.Marking)
	local socks = pick(cat.Socks, sel.Socks)
	local mane = (maneItem and maneItem.Color) or coat.Mane
	local opts = {
		Width = 1.9,
		Material = coat.Material and Enum.Material[coat.Material] or nil,
		Blanket = blanket and blanket.Color,
		Saddle = saddle and saddle.Color,
		SaddleMaterial = saddle and saddle.Material and Enum.Material[saddle.Material] or nil,
		Marking = marking and marking.Style or "Blaze",
		SockStyle = coat.Socks == false and (socks and socks.Style == "Two" and "None" or (socks and socks.Style)) or (socks and socks.Style or "Two"),
	}
	return coat.Body, mane, opts
end

return HorseModel
end

-- ======================================================================
-- MODULE: JointCache
-- ======================================================================
__modules["JointCache"] = function()
--[[
	JointCache  (StarterPlayerScripts.SpinClient.JointCache)
	Reads and writes a joint's offset for the pose system, and remembers
	each joint's original offset the first time it is touched.

	Works with both kinds of Roblox character joints:
	  * Motor6D              -> offset is joint.C0
	  * AnimationConstraint  -> offset is joint.Attachment0.CFrame
	    (newer places using the "Avatar Joint Upgrade")
]]

local JointCache = {}
local originals = setmetatable({}, { __mode = "k" })

function JointCache.isJoint(j)
	if not j then
		return false
	end
	if j:IsA("Motor6D") then
		return true
	end
	return j:IsA("AnimationConstraint") and j.Attachment0 ~= nil
end

function JointCache.read(j)
	if j:IsA("Motor6D") then
		return j.C0
	end
	return j.Attachment0.CFrame
end

function JointCache.write(j, cf)
	if j:IsA("Motor6D") then
		j.C0 = cf
	elseif j.Attachment0 then
		j.Attachment0.CFrame = cf
	end
end

function JointCache.original(j)
	local c0 = originals[j]
	if not c0 then
		c0 = JointCache.read(j)
		originals[j] = c0
	end
	return c0
end

return JointCache
end

-- ======================================================================
-- MODULE: NailModel
-- ======================================================================
__modules["NailModel"] = function()
--[[
	NailModel  (ReplicatedStorage.SpinShared.NailModel)

	Procedural fingernail-bullet used by every Tusk nail attack: a metal
	shaft, a flat head at the back and a tapered tip at the front.
	The nail points down its Core's LookVector (-Z).

	NailModel.build(length) -> Model (PrimaryPart = "Core")
	  Core attachments: "Tip" (front), "Tail" (back), "Center".
]]

local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local NailModel = {}

local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = model
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

function NailModel.build(length)
	length = length or 1.3
	local metal = TuskConfig.Colors.Metal
	local model = Instance.new("Model")
	model.Name = "TuskNail"

	-- Shaft: Cylinder axis is X, so turn it to run along Z.
	local core = part(model, {
		Name = "Core",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length * 0.7, length * 0.085, length * 0.085),
		Color = metal,
		Reflectance = 0.25,
		Massless = false,
	})
	core.CFrame = CFrame.Angles(0, math.pi / 2, 0)
	-- Pivot frame faces -Z, so Model:PivotTo(cf) points the tip down cf.LookVector.
	core.PivotOffset = CFrame.Angles(0, -math.pi / 2, 0)
	model.PrimaryPart = core

	local head = part(model, {
		Name = "Head",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length * 0.05, length * 0.24, length * 0.24),
		Color = metal:Lerp(Color3.new(1, 1, 1), 0.2),
		Reflectance = 0.3,
	})
	head.CFrame = CFrame.new(0, 0, length * 0.36) * CFrame.Angles(0, math.pi / 2, 0)
	weld(core, head)

	local tip = part(model, {
		Name = "Tip",
		Size = Vector3.new(length * 0.085, length * 0.085, length * 0.36),
		Color = metal:Lerp(Color3.new(1, 1, 1), 0.35),
		Reflectance = 0.35,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = tip
	tip.CFrame = CFrame.new(0, 0, -length * 0.35)
	weld(core, tip)

	-- Attachments are placed in the core's (rotated) local space:
	-- the core's local X axis runs along world Z here.
	local function att(name, z)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = Vector3.new(-z, 0, 0)
		a.Parent = core
		return a
	end
	att("Tip", -length * 0.5)
	att("Tail", length * 0.4)
	att("Center", 0)

	return model
end

return NailModel
end

-- ======================================================================
-- MODULE: Net
-- ======================================================================
__modules["Net"] = function()
--[[
	Net  (ReplicatedStorage.SpinShared.Net)

	Creates (server) or waits for (client) the RemoteEvents used by the
	Spin system. All remotes live in ReplicatedStorage.SpinRemotes.

	SpinRequest : client -> server  ("Start" | "Release", aimDirection | "Cancel")
	SpinFX      : server -> client  (eventName, payloadTable)
	              Also carries shared events: ProjectileSpawn/End, Hit, Damage.
	TuskRequest : client -> server  (action, ...)  see TuskService
	TuskFX      : server -> client  (eventName, payloadTable)
	WorldFX     : server -> client  map / NPC events (NPCSay)
	Bounty      : both ways         bounty board (open / accept / tracker)
	Race        : both ways         the Steel Ball Run horse race (join / leave / standings)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES = { "SpinRequest", "SpinFX", "TuskRequest", "TuskFX", "WorldFX", "Bounty", "Race" }

local Net = {}
local folder

local function getFolder()
	if folder then
		return folder
	end
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild("SpinRemotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "SpinRemotes"
			folder.Parent = ReplicatedStorage
		end
		for _, name in ipairs(REMOTES) do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild("SpinRemotes")
	end
	return folder
end

function Net.get(name)
	return getFolder():WaitForChild(name)
end

return Net
end
end
