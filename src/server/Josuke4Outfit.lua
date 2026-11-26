--[[
	Josuke4Outfit  (ServerScriptService.SpinServer.Josuke4Outfit)

	Gives a character the look of Josuke Higashikata (Part 4) while they play
	him (TuskAct 25), built from blocky parts (no catalog asset ids), matched
	to his art:
	  * his POMPADOUR: a big, rounded quiff sweeping up and out over his
	    forehead, dark violet-black with a cross-hatched shine, short at the
	    back and sides
	  * a long dark navy GAKURAN: a tall stand-up collar with a gold ANCHOR
	    badge on one side and two gold HEARTS on the other, hanging open at
	    the top over a yellow shirt; a gold PEACE-SIGN pin on the chest; gold
	    buttons down the front; long tails flaring out to his knees
	  * gold bracelets at both wrists
	  * wide, baggy navy trousers and black shoes
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local Josuke4Outfit = {}
Josuke4Outfit.Act = 25

local C = {
	Coat = Color3.fromRGB(38, 38, 82),
	CoatShade = Color3.fromRGB(24, 24, 56),
	CoatLight = Color3.fromRGB(60, 60, 116),
	Shirt = Color3.fromRGB(240, 196, 60),
	ShirtShade = Color3.fromRGB(206, 160, 40),
	Gold = Color3.fromRGB(236, 192, 72),
	GoldShade = Color3.fromRGB(186, 140, 40),
	Hair = Color3.fromRGB(44, 34, 74),
	HairShine = Color3.fromRGB(96, 80, 150),
	Shoe = Color3.fromRGB(20, 20, 26),
}

local saved = setmetatable({}, { __mode = "k" })

local function piece(parent, outfit, name, size, color, offset, material)
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
	p.Material = material or Enum.Material.SmoothPlastic
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

local function egg(parent, outfit, name, size, color, offset)
	local p = piece(parent, outfit, name, size, color, offset)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A flat gold disc facing forward (-Z).
local function coin(parent, outfit, name, d, color, offset)
	local p = piece(parent, outfit, name, Vector3.new(0.05, d, d), color, offset * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Metal)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A small gold heart facing forward: two lobes and a point.
local function heart(parent, outfit, cf, size)
	for _, side in ipairs({ -1, 1 }) do
		local lobe = piece(parent, outfit, "HeartLobe", Vector3.new(0.05, size * 0.55, size * 0.55), C.Gold, cf * CFrame.new(side * size * 0.22, size * 0.12, 0) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Metal)
		lobe.Shape = Enum.PartType.Cylinder
	end
	piece(parent, outfit, "HeartPoint", Vector3.new(size * 0.55, size * 0.55, 0.05), C.Gold, cf * CFrame.new(0, -size * 0.12, 0) * CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Metal)
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Short hair at the back and sides.
	piece(head, outfit, "HairCap", Vector3.new(head.Size.X + 0.08 * s, 0.35 * s, head.Size.Z + 0.08 * s), C.Hair, CFrame.new(0, h - 0.08 * s, 0.02 * s))
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.08 * s, 0.75 * s, 0.14 * s), C.Hair, CFrame.new(0, h - 0.4 * s, d + 0.04 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HairSide", Vector3.new(0.1 * s, 0.5 * s, head.Size.Z * 0.7), C.Hair, CFrame.new(side * (w + 0.03 * s), h - 0.35 * s, 0.1 * s))
	end
	-- The pompadour: a big rounded quiff sweeping up and out over his forehead.
	local quiff = CFrame.new(0, h + 0.38 * s, -0.32 * s) * CFrame.Angles(math.rad(-28), 0, 0)
	egg(head, outfit, "Pompadour", Vector3.new(head.Size.X + 0.14 * s, 0.85 * s, head.Size.Z + 0.75 * s), C.Hair, quiff)
	egg(head, outfit, "PompadourFront", Vector3.new(head.Size.X + 0.04 * s, 0.75 * s, 0.75 * s), C.Hair, quiff * CFrame.new(0, 0.06 * s, -0.55 * s))
	egg(head, outfit, "PompadourBase", Vector3.new(head.Size.X + 0.1 * s, 0.5 * s, head.Size.Z + 0.1 * s), C.Hair, CFrame.new(0, h + 0.05 * s, 0))
	-- Its cross-hatched shine.
	for k = -2, 2 do
		piece(head, outfit, "HatchA", Vector3.new(0.04 * s, 0.05 * s, 0.85 * s), C.HairShine, quiff * CFrame.new(k * 0.2 * s, 0.41 * s, -0.18 * s) * CFrame.Angles(0, math.rad(35), 0))
		piece(head, outfit, "HatchB", Vector3.new(0.04 * s, 0.05 * s, 0.85 * s), C.HairShine, quiff * CFrame.new(k * 0.2 * s, 0.41 * s, -0.18 * s) * CFrame.Angles(0, math.rad(-35), 0))
	end
	piece(head, outfit, "HairLine", Vector3.new(head.Size.X + 0.04 * s, 0.1 * s, 0.1 * s), C.Hair, CFrame.new(0, h - 0.05 * s, -d - 0.02 * s))
	-- Brows.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Brow", Vector3.new(0.28 * s, 0.06 * s, 0.05 * s), C.Hair, CFrame.new(side * 0.22 * s, 0.14 * s, -d - 0.02 * s) * CFrame.Angles(0, 0, side * 0.12))
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Coat", s + Vector3.new(0.12, 0.02, 0.12), C.Coat, CFrame.new())
		-- Open at the top over a yellow shirt (a V down to the chest).
		piece(upper, outfit, "Shirt", Vector3.new(0.6, s.Y * 0.55, 0.04), C.Shirt, CFrame.new(0, top - s.Y * 0.28, front - 0.07))
		piece(upper, outfit, "ShirtFold", Vector3.new(0.04, s.Y * 0.5, 0.045), C.ShirtShade, CFrame.new(0.06, top - s.Y * 0.28, front - 0.075))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Lapel", Vector3.new(0.34, s.Y * 0.62, 0.06), C.CoatLight, CFrame.new(side * 0.36, top - s.Y * 0.3, front - 0.08) * CFrame.Angles(0, 0, side * 0.28))
		end
		-- Gold buttons down the closed front.
		for k = 0, 2 do
			coin(upper, outfit, "Button", 0.14, C.Gold, CFrame.new(0, top - s.Y * 0.62 - k * 0.32, front - 0.1))
		end
		-- The gold peace-sign pin on his chest.
		local pin = CFrame.new(-s.X * 0.28, top - s.Y * 0.5, front - 0.1)
		coin(upper, outfit, "PeaceRing", 0.36, C.Gold, pin)
		coin(upper, outfit, "PeaceInner", 0.27, C.Coat, pin * CFrame.new(0, 0, -0.01))
		piece(upper, outfit, "PeaceStem", Vector3.new(0.04, 0.28, 0.05), C.Gold, pin * CFrame.new(0, 0, -0.03), Enum.Material.Metal)
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "PeaceArm", Vector3.new(0.04, 0.16, 0.05), C.Gold, pin * CFrame.new(side * 0.05, -0.06, -0.03) * CFrame.Angles(0, 0, side * 0.8), Enum.Material.Metal)
		end
		-- The tall stand-up collar: an anchor on one side, two hearts on the other.
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.75, 0.6, 0.18), C.Coat, CFrame.new(0, top + 0.28, -front))
		for _, side in ipairs({ -1, 1 }) do
			local cf = CFrame.new(side * s.X * 0.33, top + 0.28, -0.05) * CFrame.Angles(0, side * -0.3, 0)
			piece(upper, outfit, "CollarSide", Vector3.new(0.16, 0.6, s.Z * 0.95), C.Coat, cf)
			local face = cf * CFrame.new(0, 0.02, -s.Z * 0.48)
			if side == 1 then
				-- Anchor: a ring, a shank, a cross bar and a curved foot.
				coin(upper, outfit, "AnchorRing", 0.12, C.Gold, face * CFrame.new(0, 0.2, -0.02))
				piece(upper, outfit, "AnchorShank", Vector3.new(0.05, 0.34, 0.05), C.Gold, face * CFrame.new(0, 0.02, -0.02), Enum.Material.Metal)
				piece(upper, outfit, "AnchorBar", Vector3.new(0.2, 0.04, 0.05), C.Gold, face * CFrame.new(0, 0.1, -0.02), Enum.Material.Metal)
				for _, f in ipairs({ -1, 1 }) do
					piece(upper, outfit, "AnchorFluke", Vector3.new(0.14, 0.04, 0.05), C.Gold, face * CFrame.new(f * 0.06, -0.15, -0.02) * CFrame.Angles(0, 0, f * 0.6), Enum.Material.Metal)
				end
			else
				heart(upper, outfit, face * CFrame.new(0, 0.12, -0.02), 0.18)
				heart(upper, outfit, face * CFrame.new(0, -0.1, -0.02), 0.18)
			end
		end
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.1, 0.02, 0.1), C.Coat, CFrame.new())
		-- Long coat tails: sides and back, flaring out down to the knees.
		piece(lower, outfit, "TailBack", Vector3.new(ls.X + 0.2, 2.3, 0.1), C.Coat, CFrame.new(0, -1.15, ls.Z / 2 + 0.18) * CFrame.Angles(math.rad(10), 0, 0))
		for _, side in ipairs({ -1, 1 }) do
			piece(lower, outfit, "TailSide", Vector3.new(0.1, 2.2, ls.Z + 0.3), C.Coat, CFrame.new(side * (ls.X / 2 + 0.16), -1.1, 0.05) * CFrame.Angles(0, 0, side * -0.14))
			piece(lower, outfit, "TailFront", Vector3.new(ls.X / 2 + 0.05, 2.1, 0.1), C.Coat, CFrame.new(side * (ls.X / 4 + 0.02), -1.05, -ls.Z / 2 - 0.12) * CFrame.Angles(math.rad(-6), 0, side * -0.1))
		end
		coin(lower, outfit, "TailButton", 0.14, C.Gold, CFrame.new(0, -0.15, -ls.Z / 2 - 0.12))
	end
	-- Long navy sleeves, gold bracelets at the wrists.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			piece(arm, outfit, "Sleeve", as + Vector3.new(0.12, 0.02, 0.12), C.Coat, CFrame.new())
			if name:find("Lower") or name == "Left Arm" or name == "Right Arm" then
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.16, 0.18, as.Z + 0.16), C.CoatShade, CFrame.new(0, -as.Y / 2 + 0.16, 0))
				piece(arm, outfit, "Bracelet", Vector3.new(as.X + 0.2, 0.12, as.Z + 0.2), C.Gold, CFrame.new(0, -as.Y / 2 + 0.02, 0), Enum.Material.Metal)
			end
		end
	end
	-- Wide, baggy trousers and black shoes.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local wide = name:find("Lower") and 0.26 or 0.18
			piece(leg, outfit, "Trousers", leg.Size + Vector3.new(wide, 0.02, wide), C.Coat, CFrame.new())
			piece(leg, outfit, "Crease", Vector3.new(0.04, leg.Size.Y - 0.1, 0.04), C.CoatShade, CFrame.new(0, 0, -(leg.Size.Z + wide) / 2 - 0.01))
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.08, 0.04, 0.18), C.Shoe, CFrame.new(0, 0, -0.05))
		end
	end
end

function Josuke4Outfit.apply(character)
	if character:FindFirstChild("Josuke4Outfit") then
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
	outfit.Name = "Josuke4Outfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function Josuke4Outfit.remove(character)
	local outfit = character:FindFirstChild("Josuke4Outfit")
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
		if character:GetAttribute("TuskAct") == Josuke4Outfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == Josuke4Outfit.Act then
					Josuke4Outfit.apply(character)
				end
			end)
		else
			Josuke4Outfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function Josuke4Outfit.init()
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

return Josuke4Outfit
