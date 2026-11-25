--[[
	JotaroOutfit  (ServerScriptService.SpinServer.JotaroOutfit)

	Gives a character the look of Jotaro Kujo while they play him
	(TuskAct 20), built from blocky parts (no catalog asset ids), matched
	to his art:
	  * his black CAP: a dark crown and visor, a gold button and the gold
	    hand-shaped badge on the front, and his black hair running into
	    the back of it in jagged spikes
	  * a long black GAKURAN coat: a tall stand-up collar with gold buttons,
	    hanging open over a grey-green shirt; gold buttons down the front
	    and on the cuffs; long tails flaring out to his knees
	  * the gold CHAIN hanging from his left collar
	  * two belts: a plain one and one with a red / white / teal pattern
	  * black trousers and black loafers
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local JotaroOutfit = {}
JotaroOutfit.Act = 20

local C = {
	Coat = Color3.fromRGB(36, 36, 42),
	CoatShade = Color3.fromRGB(22, 22, 26),
	CoatLight = Color3.fromRGB(58, 58, 66),
	Lining = Color3.fromRGB(214, 200, 150),
	Shirt = Color3.fromRGB(112, 122, 100),
	ShirtShade = Color3.fromRGB(86, 96, 78),
	Gold = Color3.fromRGB(232, 186, 70),
	GoldShade = Color3.fromRGB(184, 140, 44),
	Hair = Color3.fromRGB(26, 24, 30),
	Belt = Color3.fromRGB(46, 40, 36),
	Red = Color3.fromRGB(196, 56, 46),
	Teal = Color3.fromRGB(70, 170, 160),
	White = Color3.fromRGB(236, 230, 214),
	Shoe = Color3.fromRGB(18, 18, 22),
}

local saved = setmetatable({}, { __mode = "k" })

local function piece(parent, outfit, name, size, color, offset)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.Color = color
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = outfit
	return p
end

-- A flat disc facing forward (-Z).
local function disc(parent, outfit, name, d, depth, color, offset)
	local p = piece(parent, outfit, name, Vector3.new(depth, d, d), color, offset * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function cyl(parent, outfit, name, a, b, d, color)
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	local p = piece(parent, outfit, name, Vector3.new(len + d * 0.3, d, d), color, CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function cyl(parent, outfit, name, a, b, d, color)
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	local p = piece(parent, outfit, name, Vector3.new(len + d * 0.3, d, d), color, CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Hair at the sides and back, spiking out behind the cap.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Sideburn", Vector3.new(0.1 * s, 0.55 * s, head.Size.Z * 0.6), C.Hair, CFrame.new(side * (w + 0.03 * s), h - 0.45 * s, 0.12 * s))
	end
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.1 * s, 0.7 * s, 0.2 * s), C.Hair, CFrame.new(0, h - 0.35 * s, d + 0.06 * s))
	for k = -2, 2 do
		piece(head, outfit, "Spike", Vector3.new(0.22 * s, 0.6 * s, 0.18 * s), C.Hair, CFrame.new(k * 0.24 * s, h - 0.05 * s, d + 0.22 * s) * CFrame.Angles(math.rad(55 + math.abs(k) * 8), 0, math.rad(k * 14)))
	end
	-- The cap: a tall dark crown, a visor out front.
	piece(head, outfit, "Cap", Vector3.new(head.Size.X + 0.16 * s, 0.5 * s, head.Size.Z + 0.16 * s), C.Coat, CFrame.new(0, h + 0.12 * s, 0))
	piece(head, outfit, "CapTop", Vector3.new(head.Size.X + 0.24 * s, 0.12 * s, head.Size.Z + 0.3 * s), C.CoatLight, CFrame.new(0, h + 0.4 * s, -0.04 * s))
	piece(head, outfit, "CapBand", Vector3.new(head.Size.X + 0.18 * s, 0.1 * s, head.Size.Z + 0.18 * s), C.CoatShade, CFrame.new(0, h - 0.08 * s, 0))
	piece(head, outfit, "Visor", Vector3.new(head.Size.X + 0.1 * s, 0.08 * s, 0.45 * s), C.CoatShade, CFrame.new(0, h - 0.12 * s, -d - 0.2 * s) * CFrame.Angles(math.rad(-12), 0, 0))
	piece(head, outfit, "VisorEdge", Vector3.new(head.Size.X + 0.12 * s, 0.05 * s, 0.06 * s), C.Gold, CFrame.new(0, h - 0.07 * s, -d - 0.02 * s))
	-- The gold button and the hand-shaped badge.
	local button = piece(head, outfit, "CapButton", Vector3.new(0.06 * s, 0.24 * s, 0.24 * s), C.Gold, CFrame.new(-0.18 * s, h + 0.15 * s, -d - 0.1 * s) * CFrame.Angles(0, math.pi / 2, 0))
	button.Shape = Enum.PartType.Cylinder
	piece(head, outfit, "Badge", Vector3.new(0.2 * s, 0.26 * s, 0.05 * s), C.Gold, CFrame.new(0.2 * s, h + 0.15 * s, -d - 0.1 * s))
	for f = 0, 2 do
		piece(head, outfit, "BadgeFinger", Vector3.new(0.04 * s, 0.1 * s, 0.05 * s), C.GoldShade, CFrame.new((0.14 + f * 0.05) * s, h + 0.31 * s, -d - 0.1 * s))
	end
	-- Heavy brows.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Brow", Vector3.new(0.3 * s, 0.07 * s, 0.05 * s), C.Hair, CFrame.new(side * 0.22 * s, 0.12 * s, -d - 0.02 * s) * CFrame.Angles(0, 0, side * 0.15))
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Coat", s + Vector3.new(0.12, 0.02, 0.12), C.Coat, CFrame.new())
		-- Hanging open over the grey-green shirt.
		piece(upper, outfit, "Shirt", Vector3.new(0.62, s.Y - 0.1, 0.04), C.Shirt, CFrame.new(-0.05, -0.05, front - 0.07))
		for k = 0, 3 do
			piece(upper, outfit, "ShirtFold", Vector3.new(0.5, 0.03, 0.045), C.ShirtShade, CFrame.new(-0.05, top - 0.35 - k * 0.3, front - 0.075))
		end
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Lapel", Vector3.new(0.22, s.Y - 0.05, 0.06), C.CoatLight, CFrame.new(side * 0.42 - 0.05, -0.02, front - 0.08) * CFrame.Angles(0, 0, side * 0.05))
			piece(upper, outfit, "LiningEdge", Vector3.new(0.04, s.Y - 0.1, 0.065), C.Lining, CFrame.new(side * 0.31 - 0.05, -0.02, front - 0.085))
		end
		-- Gold buttons down the right edge.
		for k = 0, 3 do
			local b = piece(upper, outfit, "Button", Vector3.new(0.05, 0.13, 0.13), C.Gold, CFrame.new(0.55, top - 0.3 - k * 0.36, front - 0.12) * CFrame.Angles(0, math.pi / 2, 0))
			b.Shape = Enum.PartType.Cylinder
		end
		-- The tall stand-up collar, gold buttons at its corners.
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.75, 0.6, 0.18), C.Coat, CFrame.new(0, top + 0.28, -front + 0.0))
		for _, side in ipairs({ -1, 1 }) do
			local cf = CFrame.new(side * s.X * 0.33, top + 0.28, -0.05) * CFrame.Angles(0, side * -0.3, 0)
			piece(upper, outfit, "CollarSide", Vector3.new(0.16, 0.6, s.Z * 0.95), C.Coat, cf)
			local b = piece(upper, outfit, "CollarButton", Vector3.new(0.05, 0.14, 0.14), C.Gold, cf * CFrame.new(0, 0.12, -s.Z * 0.48) * CFrame.Angles(0, math.pi / 2, 0))
			b.Shape = Enum.PartType.Cylinder
		end
		-- The gold chain from his left collar, swinging down and back up.
		local a = Vector3.new(-s.X * 0.36, top + 0.2, front - 0.1)
		local pts = { a, a + Vector3.new(0.05, -0.35, -0.02), a + Vector3.new(0.18, -0.6, -0.03), a + Vector3.new(0.35, -0.7, -0.03), a + Vector3.new(0.5, -0.55, -0.02) }
		for i = 1, #pts - 1 do
			local mid = (pts[i] + pts[i + 1]) / 2
			for k = 0, 1 do
				local link = piece(upper, outfit, "Chain", Vector3.new(0.04, 0.12, 0.08), C.Gold, CFrame.lookAt(pts[i]:Lerp(pts[i + 1], 0.25 + k * 0.5), mid + (pts[i + 1] - pts[i])) * CFrame.Angles(0, 0, k * math.pi / 2))
				link.Material = Enum.Material.Metal
			end
		end
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.Coat, CFrame.new())
		-- Two belts: one plain, one patterned (red / white / teal).
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.16, 0.14, ls.Z + 0.16), C.Belt, CFrame.new(0, ls.Y / 2 - 0.06, 0))
		local pattern = piece(lower, outfit, "BeltPattern", Vector3.new(ls.X + 0.2, 0.14, ls.Z + 0.2), C.White, CFrame.new(0, ls.Y / 2 - 0.22, 0) * CFrame.Angles(0, 0, -0.06))
		pattern.Name = "BeltPattern"
		for k = -4, 4 do
			piece(lower, outfit, "Zig", Vector3.new(0.12, 0.12, 0.04), k % 2 == 0 and C.Red or C.Teal, CFrame.new(k * 0.2, ls.Y / 2 - 0.22 - k * 0.012, -ls.Z / 2 - 0.11) * CFrame.Angles(0, 0, math.pi / 4))
		end
		-- Long coat tails: sides and back, flaring out down to the knees.
		piece(lower, outfit, "TailBack", Vector3.new(ls.X + 0.2, 2.4, 0.1), C.Coat, CFrame.new(0, -1.2, ls.Z / 2 + 0.18) * CFrame.Angles(math.rad(10), 0, 0))
		piece(lower, outfit, "TailLining", Vector3.new(ls.X, 2.2, 0.04), C.Lining, CFrame.new(0, -1.15, ls.Z / 2 + 0.11) * CFrame.Angles(math.rad(10), 0, 0))
		for _, side in ipairs({ -1, 1 }) do
			piece(lower, outfit, "TailSide", Vector3.new(0.1, 2.3, ls.Z + 0.3), C.Coat, CFrame.new(side * (ls.X / 2 + 0.16), -1.15, 0.05) * CFrame.Angles(0, 0, side * -0.14))
			piece(lower, outfit, "TailFront", Vector3.new(0.4, 2.2, 0.1), C.Coat, CFrame.new(side * (ls.X / 2 - 0.1), -1.1, -ls.Z / 2 - 0.12) * CFrame.Angles(math.rad(-6), 0, side * -0.12))
		end
	end
	-- Long black sleeves, gold buttons at the cuffs.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			piece(arm, outfit, "Sleeve", as + Vector3.new(0.1, 0.02, 0.1), C.Coat, CFrame.new())
			if name:find("Lower") or name == "Left Arm" or name == "Right Arm" then
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.14, 0.2, as.Z + 0.14), C.CoatShade, CFrame.new(0, -as.Y / 2 + 0.12, 0))
				for k = 0, 1 do
					local b = piece(arm, outfit, "CuffButton", Vector3.new(0.04, 0.1, 0.1), C.Gold, CFrame.new((name:find("Left") and -1 or 1) * (as.X / 2 + 0.08), -as.Y / 2 + 0.2 + k * 0.16, 0.2) * CFrame.Angles(0, 0, 0))
					b.Shape = Enum.PartType.Cylinder
				end
			end
		end
	end
	-- Black trousers, black loafers.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Trousers", leg.Size + Vector3.new(0.06, 0.02, 0.06), C.Coat, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			local fs = foot.Size
			piece(foot, outfit, "Loafer", fs + Vector3.new(0.08, 0.04, 0.16), C.Shoe, CFrame.new(0, 0, -0.04))
			piece(foot, outfit, "LoaferStrap", Vector3.new(fs.X + 0.1, 0.06, 0.1), C.CoatLight, CFrame.new(0, fs.Y / 2, -fs.Z / 2 + 0.1))
		end
	end
end

function JotaroOutfit.apply(character)
	if character:FindFirstChild("JotaroOutfit") then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local store = { Hidden = {} }
	saved[character] = store
	for _, d in ipairs(character:GetChildren()) do
		if d:IsA("Accessory") then
			local handle = d:FindFirstChild("Handle")
			local kind = d.AccessoryType
			if handle and (kind == Enum.AccessoryType.Hat or kind == Enum.AccessoryType.Hair or kind == Enum.AccessoryType.Unknown) then
				store.Hidden[handle] = handle.Transparency
				handle.Transparency = 1
			end
		end
	end
	local outfit = Instance.new("Model")
	outfit.Name = "JotaroOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function JotaroOutfit.remove(character)
	local outfit = character:FindFirstChild("JotaroOutfit")
	if outfit then
		outfit:Destroy()
	end
	local store = saved[character]
	if not store then
		return
	end
	saved[character] = nil
	for thing, transparency in pairs(store.Hidden) do
		if thing.Parent then
			thing.Transparency = transparency
		end
	end
end

local function watch(character)
	local function update()
		if character:GetAttribute("TuskAct") == JotaroOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == JotaroOutfit.Act then
					JotaroOutfit.apply(character)
				end
			end)
		else
			JotaroOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function JotaroOutfit.init()
	local function onPlayer(player)
		player.CharacterAppearanceLoaded:Connect(watch)
		if player.Character then
			watch(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	-- Stand-user NPCs (StandBots) wear the outfit too.
	local CollectionService = game:GetService("CollectionService")
	for _, model in ipairs(CollectionService:GetTagged("SpinFighter")) do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("SpinFighter"):Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
end

return JotaroOutfit
