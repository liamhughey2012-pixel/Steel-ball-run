--[[
	RingoOutfit  (ServerScriptService.SpinServer.RingoOutfit)

	Gives a character the look of Ringo Roadagain while they play him
	(TuskAct 19), built from blocky parts (no catalog asset ids), matched
	to his art:
	  * grey hair swept up and back, a grey moustache and chin beard
	  * a sleeveless grey top with a huge high collar (a folded-back hood),
	    open down the chest; orange "60" and "5" marks and Mandom's yellow
	    WATCH HAND across his chest (a triangle at the top, a ring at the
	    bottom, small yellow squares beside it)
	  * pink tubes plugged into his right arm and chest, gold rings where
	    they go in
	  * purple gloves, a gold bracelet, a brown gun belt with a holster
	  * grey trousers
	Mandom itself (MandomStand) rides on his right shoulder.
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local RingoOutfit = {}
RingoOutfit.Act = 19

local C = {
	Hair = Color3.fromRGB(176, 180, 188),
	HairShade = Color3.fromRGB(130, 134, 144),
	Top = Color3.fromRGB(150, 156, 166),
	TopShade = Color3.fromRGB(112, 118, 130),
	CollarIn = Color3.fromRGB(196, 200, 208),
	Mark = Color3.fromRGB(226, 120, 50),
	Hand = Color3.fromRGB(246, 204, 40),
	Tube = Color3.fromRGB(190, 74, 124),
	Ring = Color3.fromRGB(226, 182, 76),
	Glove = Color3.fromRGB(150, 128, 176),
	Gold = Color3.fromRGB(230, 186, 70),
	Belt = Color3.fromRGB(150, 96, 46),
	BeltDark = Color3.fromRGB(104, 64, 30),
	Buckle = Color3.fromRGB(220, 190, 110),
	Pants = Color3.fromRGB(132, 138, 150),
	Shoe = Color3.fromRGB(70, 52, 40),
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

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Grey hair swept up and back: a cap, a tall quiff leaning back, sides.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.08 * s, 0.3 * s, head.Size.Z + 0.1 * s), C.Hair, CFrame.new(0, h - 0.1 * s, 0.02 * s))
	piece(head, outfit, "Quiff", Vector3.new(head.Size.X * 0.9, 0.4 * s, head.Size.Z * 0.85), C.Hair, CFrame.new(0, h + 0.15 * s, 0.12 * s) * CFrame.Angles(math.rad(14), 0, 0))
	piece(head, outfit, "QuiffBack", Vector3.new(head.Size.X * 0.8, 0.3 * s, 0.4 * s), C.HairShade, CFrame.new(0, h + 0.1 * s, d + 0.08 * s) * CFrame.Angles(math.rad(30), 0, 0))
	piece(head, outfit, "QuiffFront", Vector3.new(head.Size.X * 0.7, 0.12 * s, 0.14 * s), C.HairShade, CFrame.new(0.1 * s, h + 0.28 * s, -d + 0.12 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HairSide", Vector3.new(0.1 * s, 0.5 * s, head.Size.Z * 0.7), C.Hair, CFrame.new(side * (w + 0.03 * s), h - 0.35 * s, 0.1 * s))
	end
	-- Moustache and chin beard.
	piece(head, outfit, "Moustache", Vector3.new(0.42 * s, 0.08 * s, 0.05 * s), C.Hair, CFrame.new(0, -0.22 * s, -d - 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "MoustacheEnd", Vector3.new(0.06 * s, 0.22 * s, 0.05 * s), C.Hair, CFrame.new(side * 0.2 * s, -0.33 * s, -d - 0.02 * s))
	end
	piece(head, outfit, "Beard", Vector3.new(0.14 * s, 0.24 * s, 0.06 * s), C.Hair, CFrame.new(0, -h + 0.04 * s, -d - 0.02 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	local head = character:FindFirstChild("Head")
	local skin = head and head.Color or Color3.fromRGB(196, 136, 92)
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Top", s + Vector3.new(0.1, 0.02, 0.1), C.Top, CFrame.new())
		-- Open down the chest: a V of skin.
		piece(upper, outfit, "Chest", Vector3.new(0.34, s.Y * 0.55, 0.04), skin, CFrame.new(-0.08, top - s.Y * 0.3, front - 0.06))
		piece(upper, outfit, "ChestTip", Vector3.new(0.22, 0.22, 0.04), skin, CFrame.new(-0.08, top - s.Y * 0.58, front - 0.06) * CFrame.Angles(0, 0, math.pi / 4))
		-- The huge high collar (a folded-back hood), open at the front.
		piece(upper, outfit, "CollarBack", Vector3.new(s.X * 0.85, 0.95, 0.25), C.Top, CFrame.new(0, top + 0.4, -front - 0.05) * CFrame.Angles(math.rad(-12), 0, 0))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Collar", Vector3.new(0.22, 0.9, s.Z * 0.9), C.Top, CFrame.new(side * s.X * 0.36, top + 0.36, 0.02) * CFrame.Angles(0, 0, side * -0.22))
			piece(upper, outfit, "CollarIn", Vector3.new(0.06, 0.8, s.Z * 0.75), C.CollarIn, CFrame.new(side * (s.X * 0.36 - 0.12), top + 0.36, 0.0) * CFrame.Angles(0, 0, side * -0.22))
			piece(upper, outfit, "Lapel", Vector3.new(0.3, 0.7, 0.06), C.TopShade, CFrame.new(side * 0.28 - 0.08, top - 0.3, front - 0.05) * CFrame.Angles(0, 0, side * 0.35))
		end
		-- "60" and "5" marks.
		piece(upper, outfit, "Mark60", Vector3.new(0.26, 0.16, 0.04), C.Mark, CFrame.new(0.2, 0.05, front - 0.06))
		piece(upper, outfit, "Mark5", Vector3.new(0.12, 0.16, 0.04), C.Mark, CFrame.new(-0.6, 0.3, front - 0.06))
		-- Mandom's watch hand across his chest: from up by his left
		-- shoulder down towards his right hip, a triangle at the top, a ring below.
		local a = Vector3.new(-0.55, top - 0.12, front - 0.1)
		local b = Vector3.new(0.35, -top + 0.08, front - 0.1)
		local mid = (a + b) / 2
		piece(upper, outfit, "WatchHand", Vector3.new(0.07, (b - a).Magnitude, 0.05), C.Hand, CFrame.lookAt(mid, mid + Vector3.new(0, 0, -1), (a - b).Unit))
		piece(upper, outfit, "HandTip", Vector3.new(0.22, 0.22, 0.05), C.Hand, CFrame.new(a) * CFrame.Angles(0, 0, math.pi / 4))
		local ring = piece(upper, outfit, "HandRing", Vector3.new(0.05, 0.24, 0.24), C.Hand, CFrame.new(b) * CFrame.Angles(0, math.pi / 2, 0))
		ring.Shape = Enum.PartType.Cylinder
		piece(upper, outfit, "Mark", Vector3.new(0.13, 0.13, 0.05), C.Hand, CFrame.new(0.05, top - 0.2, front - 0.1) * CFrame.Angles(0, 0, math.pi / 4))
		piece(upper, outfit, "Mark", Vector3.new(0.12, 0.12, 0.05), C.Hand, CFrame.new(-0.7, 0.5, front - 0.1) * CFrame.Angles(0, 0, math.pi / 4))
		-- Pink tubes into his chest (right side), gold rings where they go in.
		for k, y in ipairs({ 0.35, -0.05, -0.4 }) do
			local into = Vector3.new(0.7 - k * 0.06, y, front - 0.04)
			local from = Vector3.new(s.X / 2 + 0.35, y + 0.35, front + 0.25)
			cyl(upper, outfit, "Tube", from, into, 0.13, C.Tube)
			local r = piece(upper, outfit, "TubeRing", Vector3.new(0.05, 0.2, 0.2), C.Ring, CFrame.new(into) * CFrame.Angles(0, math.pi / 2, 0))
			r.Shape = Enum.PartType.Cylinder
		end
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Pants", ls + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
		-- The brown gun belt, buckle, and a holster on his right hip.
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.16, 0.24, ls.Z + 0.16), C.Belt, CFrame.new(0, ls.Y / 2 - 0.1, 0))
		piece(lower, outfit, "BeltEdge", Vector3.new(ls.X + 0.18, 0.05, ls.Z + 0.18), C.BeltDark, CFrame.new(0, ls.Y / 2 - 0.22, 0))
		piece(lower, outfit, "Buckle", Vector3.new(0.3, 0.2, 0.06), C.Buckle, CFrame.new(0, ls.Y / 2 - 0.1, -ls.Z / 2 - 0.1))
		piece(lower, outfit, "Holster", Vector3.new(0.24, 0.6, 0.4), C.BeltDark, CFrame.new(ls.X / 2 + 0.14, -0.05, 0.05) * CFrame.Angles(0, 0, 0.12))
		piece(lower, outfit, "Grip", Vector3.new(0.12, 0.3, 0.16), Color3.fromRGB(60, 50, 44), CFrame.new(ls.X / 2 + 0.16, 0.3, 0.12) * CFrame.Angles(0, 0, -0.3))
	end
	-- Bare arms (sleeveless), purple gloves, a gold bracelet on the right wrist.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Skin", arm.Size + Vector3.new(0.04, 0, 0.04), skin, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftHand", "RightHand" }) do
		local hand = character:FindFirstChild(name)
		if hand then
			piece(hand, outfit, "Glove", hand.Size + Vector3.new(0.1, 0.06, 0.1), C.Glove, CFrame.new())
			piece(hand, outfit, "Cuff", Vector3.new(hand.Size.X + 0.2, 0.16, hand.Size.Z + 0.2), C.Glove, CFrame.new(0, hand.Size.Y / 2 + 0.02, 0))
		end
	end
	local rightLower = character:FindFirstChild("RightLowerArm") or character:FindFirstChild("Right Arm")
	if rightLower then
		local as = rightLower.Size
		piece(rightLower, outfit, "Bracelet", Vector3.new(as.X + 0.14, 0.14, as.Z + 0.14), C.Gold, CFrame.new(0, -as.Y / 2 + 0.12, 0))
	end
	-- Pink tubes plugged into his right arm, gold rings where they go in.
	local rightUpper = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm")
	if rightUpper then
		local as = rightUpper.Size
		for k, y in ipairs({ 0.25, -0.15 }) do
			local into = Vector3.new(as.X / 2 + 0.02, y, -0.05 * k)
			local from = Vector3.new(as.X / 2 + 0.45, y + 0.4, 0.3)
			cyl(rightUpper, outfit, "Tube", from, into, 0.13, C.Tube)
			local r = piece(rightUpper, outfit, "TubeRing", Vector3.new(0.05, 0.2, 0.2), C.Ring, CFrame.new(into) * CFrame.Angles(0, 0, math.pi / 2))
			r.Shape = Enum.PartType.Cylinder
		end
	end
	if rightLower then
		local as = rightLower.Size
		local into = Vector3.new(as.X / 2 + 0.02, 0.1, 0)
		cyl(rightLower, outfit, "Tube", Vector3.new(as.X / 2 + 0.5, 0.7, 0.2), into, 0.13, C.Tube)
		local r = piece(rightLower, outfit, "TubeRing", Vector3.new(0.05, 0.2, 0.2), C.Ring, CFrame.new(into) * CFrame.Angles(0, 0, math.pi / 2))
		r.Shape = Enum.PartType.Cylinder
	end
	-- Grey trousers, brown boots.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Pants", leg.Size + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.08, 0.04, 0.12), C.Shoe, CFrame.new())
		end
	end
end

function RingoOutfit.apply(character)
	if character:FindFirstChild("RingoOutfit") then
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
	outfit.Name = "RingoOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function RingoOutfit.remove(character)
	local outfit = character:FindFirstChild("RingoOutfit")
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
		if character:GetAttribute("TuskAct") == RingoOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == RingoOutfit.Act then
					RingoOutfit.apply(character)
				end
			end)
		else
			RingoOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function RingoOutfit.init()
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

return RingoOutfit
