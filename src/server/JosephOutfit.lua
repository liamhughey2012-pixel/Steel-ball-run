--[[
	JosephOutfit  (ServerScriptService.SpinServer.JosephOutfit)

	Gives a character the look of old Joseph Joestar (Part 3) while they
	play him (TuskAct 22), built from blocky parts (no catalog asset ids):
	  * a tan FEDORA with a dark band and a wide brim; short grey hair
	    under it
	  * a full white BEARD and moustache
	  * a dark navy button-up shirt, open at the collar, sleeves rolled up
	    to the elbows (bare, strong forearms)
	  * a black glove on his left hand (his prosthetic)
	  * a brown belt, khaki trousers, brown shoes
	(Hermit Purple, HermitPurpleStand, winds round his right arm.)
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local JosephOutfit = {}
JosephOutfit.Act = 22

local C = {
	Hat = Color3.fromRGB(196, 166, 112),
	HatShade = Color3.fromRGB(160, 130, 84),
	HatBand = Color3.fromRGB(70, 48, 30),
	Hair = Color3.fromRGB(196, 196, 200),
	Beard = Color3.fromRGB(236, 236, 238),
	BeardShade = Color3.fromRGB(196, 196, 202),
	Shirt = Color3.fromRGB(40, 52, 84),
	ShirtShade = Color3.fromRGB(28, 36, 60),
	Button = Color3.fromRGB(220, 220, 226),
	Glove = Color3.fromRGB(26, 26, 30),
	Belt = Color3.fromRGB(96, 62, 34),
	Buckle = Color3.fromRGB(210, 180, 100),
	Pants = Color3.fromRGB(178, 152, 110),
	PantsShade = Color3.fromRGB(150, 126, 90),
	Shoe = Color3.fromRGB(84, 54, 32),
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

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Short grey hair at the sides and back.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "SideHair", Vector3.new(0.1 * s, 0.5 * s, head.Size.Z * 0.7), C.Hair, CFrame.new(side * (w + 0.03 * s), h - 0.4 * s, 0.1 * s))
	end
	piece(head, outfit, "BackHair", Vector3.new(head.Size.X + 0.06 * s, 0.5 * s, 0.12 * s), C.Hair, CFrame.new(0, h - 0.38 * s, d + 0.04 * s))
	-- The fedora: a pinched crown, a dark band, a wide brim dipping at the front.
	piece(head, outfit, "Crown", Vector3.new(head.Size.X * 0.95, 0.5 * s, head.Size.Z * 0.95), C.Hat, CFrame.new(0, h + 0.2 * s, 0.02 * s))
	piece(head, outfit, "Pinch", Vector3.new(0.1 * s, 0.14 * s, head.Size.Z * 0.6), C.HatShade, CFrame.new(0, h + 0.44 * s, 0.05 * s))
	piece(head, outfit, "Band", Vector3.new(head.Size.X * 0.97, 0.14 * s, head.Size.Z * 0.97), C.HatBand, CFrame.new(0, h + 0.02 * s, 0.02 * s))
	piece(head, outfit, "Brim", Vector3.new(head.Size.X + 0.6 * s, 0.06 * s, head.Size.Z + 0.6 * s), C.Hat, CFrame.new(0, h - 0.04 * s, 0.02 * s))
	piece(head, outfit, "BrimFront", Vector3.new(head.Size.X + 0.5 * s, 0.06 * s, 0.4 * s), C.HatShade, CFrame.new(0, h - 0.08 * s, -d - 0.2 * s) * CFrame.Angles(math.rad(-10), 0, 0))
	-- A full white beard and moustache, heavy brows.
	piece(head, outfit, "Beard", Vector3.new(head.Size.X * 0.9, 0.42 * s, 0.12 * s), C.Beard, CFrame.new(0, -h + 0.2 * s, -d - 0.03 * s))
	piece(head, outfit, "BeardChin", Vector3.new(head.Size.X * 0.6, 0.2 * s, 0.3 * s), C.Beard, CFrame.new(0, -h - 0.02 * s, -d + 0.06 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "BeardSide", Vector3.new(0.1 * s, 0.5 * s, head.Size.Z * 0.6), C.Beard, CFrame.new(side * (w + 0.03 * s), -h + 0.35 * s, -0.05 * s))
		piece(head, outfit, "Moustache", Vector3.new(0.26 * s, 0.1 * s, 0.06 * s), C.Beard, CFrame.new(side * 0.13 * s, -0.22 * s, -d - 0.05 * s) * CFrame.Angles(0, 0, side * -0.2))
		piece(head, outfit, "Brow", Vector3.new(0.28 * s, 0.07 * s, 0.05 * s), C.Hair, CFrame.new(side * 0.22 * s, 0.14 * s, -d - 0.02 * s) * CFrame.Angles(0, 0, side * 0.12))
	end
	piece(head, outfit, "BeardLine", Vector3.new(0.04 * s, 0.36 * s, 0.13 * s), C.BeardShade, CFrame.new(0, -h + 0.2 * s, -d - 0.035 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	local head = character:FindFirstChild("Head")
	local skin = head and head.Color or Color3.fromRGB(226, 186, 150)
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Shirt", s + Vector3.new(0.08, 0.02, 0.08), C.Shirt, CFrame.new())
		-- Open at the collar: a little V of skin, the collar points.
		piece(upper, outfit, "Neck", Vector3.new(0.34, 0.34, 0.04), skin, CFrame.new(0, top - 0.17, front - 0.05))
		piece(upper, outfit, "NeckTip", Vector3.new(0.24, 0.24, 0.04), skin, CFrame.new(0, top - 0.33, front - 0.05) * CFrame.Angles(0, 0, math.pi / 4))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Collar", Vector3.new(0.36, 0.16, 0.06), C.ShirtShade, CFrame.new(side * 0.26, top - 0.08, front - 0.06) * CFrame.Angles(0, 0, side * -0.5))
			piece(upper, outfit, "Pocket", Vector3.new(0.4, 0.34, 0.04), C.ShirtShade, CFrame.new(side * 0.5, top - 0.55, front - 0.06))
		end
		piece(upper, outfit, "Placket", Vector3.new(0.12, s.Y * 0.6, 0.05), C.ShirtShade, CFrame.new(0, -s.Y * 0.18, front - 0.06))
		for k = 0, 3 do
			local b = piece(upper, outfit, "Button", Vector3.new(0.04, 0.09, 0.09), C.Button, CFrame.new(0, top - 0.6 - k * 0.24, front - 0.09) * CFrame.Angles(0, math.pi / 2, 0))
			b.Shape = Enum.PartType.Cylinder
		end
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.16, 0.16, ls.Z + 0.16), C.Belt, CFrame.new(0, ls.Y / 2 - 0.06, 0))
		piece(lower, outfit, "Buckle", Vector3.new(0.24, 0.16, 0.06), C.Buckle, CFrame.new(0, ls.Y / 2 - 0.06, -ls.Z / 2 - 0.1))
	end
	-- Sleeves rolled up to the elbows; bare forearms; a black glove on his left hand.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local h = name:find("Upper") and as.Y or as.Y * 0.45
			piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.1, h, as.Z + 0.1), C.Shirt, CFrame.new(0, as.Y / 2 - h / 2, 0))
			piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.16, 0.16, as.Z + 0.16), C.ShirtShade, CFrame.new(0, as.Y / 2 - h + 0.06, 0))
		end
	end
	for _, name in ipairs({ "LeftLowerArm", "RightLowerArm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Skin", arm.Size + Vector3.new(0.04, 0, 0.04), skin, CFrame.new())
		end
	end
	local leftHand = character:FindFirstChild("LeftHand")
	if leftHand then
		piece(leftHand, outfit, "Glove", leftHand.Size + Vector3.new(0.08, 0.06, 0.08), C.Glove, CFrame.new())
	end
	local leftLower = character:FindFirstChild("LeftLowerArm")
	if leftLower then
		piece(leftLower, outfit, "GloveCuff", Vector3.new(leftLower.Size.X + 0.1, 0.24, leftLower.Size.Z + 0.1), C.Glove, CFrame.new(0, -leftLower.Size.Y / 2 + 0.12, 0))
	end
	-- Khaki trousers, brown shoes.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Trousers", leg.Size + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
			piece(leg, outfit, "Crease", Vector3.new(0.04, leg.Size.Y * 0.9, 0.04), C.PantsShade, CFrame.new(0, 0, -leg.Size.Z / 2 - 0.04))
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.08, 0.04, 0.14), C.Shoe, CFrame.new(0, 0, -0.04))
		end
	end
end

function JosephOutfit.apply(character)
	if character:FindFirstChild("JosephOutfit") then
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
	outfit.Name = "JosephOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function JosephOutfit.remove(character)
	local outfit = character:FindFirstChild("JosephOutfit")
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
		if character:GetAttribute("TuskAct") == JosephOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == JosephOutfit.Act then
					JosephOutfit.apply(character)
				end
			end)
		else
			JosephOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function JosephOutfit.init()
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

return JosephOutfit
