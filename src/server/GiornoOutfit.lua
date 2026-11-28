--[[
	GiornoOutfit  (ServerScriptService.SpinServer.GiornoOutfit)

	Gives a character the look of Giorno Giovanna (Part 5) while they play
	him (TuskAct 30, and 31 with Gold Experience Requiem), built from blocky
	parts (no catalog asset ids), matched to his art:
	  * golden-blond hair swept back, with his THREE ROUND CURLS in a row
	    over the forehead, side locks, and a long BRAID hanging down his back
	  * a pink-violet suit: a long jacket flaring at the hips, a high collar
	    with a gold spiral pin, and a HEART-SHAPED opening at the chest
	  * a gold chain-zip running down from the heart to the hem
	  * three LADYBUG brooches (two on the chest, one low on the jacket)
	  * gold wrist cuffs; fitted trousers; pink shoes
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local GiornoOutfit = {}
GiornoOutfit.Act = 30
GiornoOutfit.Acts = { [30] = true, [31] = true }

local C = {
	Hair = Color3.fromRGB(246, 212, 92),
	HairShade = Color3.fromRGB(214, 170, 60),
	HairDeep = Color3.fromRGB(176, 130, 40),
	Suit = Color3.fromRGB(198, 100, 200),
	SuitShade = Color3.fromRGB(150, 66, 160),
	SuitDeep = Color3.fromRGB(110, 44, 124),
	Skin = Color3.fromRGB(240, 206, 176),
	Gold = Color3.fromRGB(240, 192, 70),
	GoldDark = Color3.fromRGB(196, 146, 40),
	Bug = Color3.fromRGB(34, 52, 96),
	BugDot = Color3.fromRGB(236, 206, 90),
	Shoe = Color3.fromRGB(196, 100, 160),
	Eye = Color3.fromRGB(70, 150, 140),
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

local function cylinder(parent, outfit, name, length, d, color, offset, material)
	local p = piece(parent, outfit, name, Vector3.new(length, d, d), color, offset, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent, outfit, name, d, color, offset, material)
	local p = piece(parent, outfit, name, Vector3.new(d, d, d), color, offset, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A ladybug brooch: a dark-blue shell with gold dots, facing out along -Z.
local function ladybug(parent, outfit, at, s)
	local shell = piece(parent, outfit, "LadybugShell", Vector3.new(0.3, 0.3, 0.12) * s, C.Bug, at)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = shell
	piece(parent, outfit, "LadybugLine", Vector3.new(0.02, 0.28, 0.13) * s, C.BugDot, at * CFrame.new(0, 0, -0.005 * s))
	for _, d in ipairs({ { -0.07, 0.06 }, { 0.07, 0.06 }, { -0.06, -0.07 }, { 0.06, -0.07 } }) do
		ball(parent, outfit, "LadybugDot", 0.07 * s, C.BugDot, at * CFrame.new(d[1] * s, d[2] * s, -0.05 * s))
	end
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Golden hair, swept back and smooth over the top.
	piece(head, outfit, "HairCap", Vector3.new(head.Size.X + 0.1 * s, 0.3 * s, head.Size.Z + 0.14 * s), C.Hair, CFrame.new(0, h + 0.08 * s, 0.04 * s))
	piece(head, outfit, "HairTop", Vector3.new(head.Size.X * 0.9, 0.16 * s, head.Size.Z * 0.95), C.HairShade, CFrame.new(0, h + 0.26 * s, 0.08 * s))
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.12 * s, 0.85 * s, 0.16 * s), C.Hair, CFrame.new(0, h - 0.35 * s, d + 0.05 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HairSide", Vector3.new(0.12 * s, 0.55 * s, head.Size.Z * 0.8), C.Hair, CFrame.new(side * (w + 0.05 * s), h - 0.22 * s, 0.08 * s))
		-- A lock falling down by each cheek.
		piece(head, outfit, "SideLock", Vector3.new(0.12 * s, 0.6 * s, 0.14 * s), C.HairShade, CFrame.new(side * (w - 0.02 * s), -0.05 * s, -d + 0.08 * s) * CFrame.Angles(0, 0, side * 0.12))
		-- Calm, half-closed teal eyes and thin brows.
		piece(head, outfit, "Eye", Vector3.new(0.2 * s, 0.07 * s, 0.03 * s), C.Eye, CFrame.new(side * 0.22 * s, 0.06 * s, -d - 0.01 * s))
		piece(head, outfit, "Lid", Vector3.new(0.24 * s, 0.04 * s, 0.035 * s), C.HairDeep, CFrame.new(side * 0.22 * s, 0.11 * s, -d - 0.012 * s) * CFrame.Angles(0, 0, side * -0.1))
		piece(head, outfit, "Brow", Vector3.new(0.24 * s, 0.035 * s, 0.03 * s), C.HairShade, CFrame.new(side * 0.22 * s, 0.2 * s, -d - 0.01 * s) * CFrame.Angles(0, 0, side * 0.12))
	end
	-- The three round curls in a row over his forehead (a little to his right).
	for k = -1, 1 do
		local at = CFrame.new(k * 0.36 * s - 0.04 * s, h + 0.2 * s, -d + 0.04 * s)
		cylinder(head, outfit, "Curl", 0.22 * s, 0.42 * s, C.Hair, at * CFrame.Angles(0, math.pi / 2, 0))
		cylinder(head, outfit, "CurlRing", 0.23 * s, 0.3 * s, C.HairShade, at * CFrame.Angles(0, math.pi / 2, 0))
		cylinder(head, outfit, "CurlHole", 0.24 * s, 0.15 * s, C.HairDeep, at * CFrame.Angles(0, math.pi / 2, 0))
	end
	-- The long braid down his back.
	local braidTop = CFrame.new(0, -h + 0.1 * s, d + 0.14 * s)
	for k = 0, 5 do
		piece(head, outfit, k % 2 == 0 and "Braid" or "BraidLink", Vector3.new(0.26 * s - k * 0.012 * s, 0.24 * s, 0.2 * s), k % 2 == 0 and C.Hair or C.HairShade, braidTop * CFrame.new(0, -k * 0.21 * s, k * 0.025 * s) * CFrame.Angles(0, 0, (k % 2 == 0 and 0.35 or -0.35)))
	end
	piece(head, outfit, "BraidTip", Vector3.new(0.14 * s, 0.22 * s, 0.14 * s), C.HairShade, braidTop * CFrame.new(0, -6 * 0.21 * s, 0.16 * s))
	piece(head, outfit, "Mouth", Vector3.new(0.16 * s, 0.025 * s, 0.03 * s), Color3.fromRGB(170, 100, 100), CFrame.new(0, -0.26 * s, -d - 0.01 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Jacket", s + Vector3.new(0.08, 0.02, 0.08), C.Suit, CFrame.new())
		-- The high collar, its gold spiral pin.
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.62, 0.42, s.Z * 0.8), C.Suit, CFrame.new(0, top + 0.18, 0.02))
		piece(upper, outfit, "CollarFold", Vector3.new(s.X * 0.64, 0.06, s.Z * 0.82), C.SuitShade, CFrame.new(0, top + 0.38, 0.02))
		cylinder(upper, outfit, "CollarPin", 0.05, 0.2, C.Gold, CFrame.new(0.16, top + 0.2, front - 0.07) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Metal)
		cylinder(upper, outfit, "CollarPinCurl", 0.06, 0.1, C.GoldDark, CFrame.new(0.16, top + 0.2, front - 0.08) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Metal)
		-- The heart-shaped opening: skin showing, two lobes and a point.
		local heart = CFrame.new(0, top - 0.42, front - 0.045)
		for _, side in ipairs({ -1, 1 }) do
			local lobe = piece(upper, outfit, "HeartLobe", Vector3.new(0.42, 0.42, 0.04), C.Skin, heart * CFrame.new(side * 0.16, 0.1, 0))
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.Sphere
			m.Parent = lobe
			-- A gold rim round each lobe.
			piece(upper, outfit, "HeartRim", Vector3.new(0.05, 0.3, 0.05), C.Gold, heart * CFrame.new(side * 0.36, 0.08, -0.005) * CFrame.Angles(0, 0, side * -0.3), Enum.Material.Metal)
			piece(upper, outfit, "HeartRimLow", Vector3.new(0.05, 0.3, 0.05), C.Gold, heart * CFrame.new(side * 0.15, -0.22, -0.005) * CFrame.Angles(0, 0, side * 0.75), Enum.Material.Metal)
		end
		piece(upper, outfit, "HeartPoint", Vector3.new(0.3, 0.3, 0.04), C.Skin, heart * CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.pi / 4))
		-- The gold chain-zip down from the heart.
		local zipTop = top - 0.8
		local links = math.max(3, math.floor((s.Y - 0.72) / 0.12))
		for k = 0, links do
			piece(upper, outfit, "Zip", Vector3.new(0.07, 0.07, 0.04), k % 2 == 0 and C.Gold or C.GoldDark, CFrame.new(math.sin(k * 0.5) * 0.03, zipTop - k * 0.12, front - 0.06), Enum.Material.Metal)
		end
		-- Two ladybugs on the chest.
		for _, side in ipairs({ -1, 1 }) do
			ladybug(upper, outfit, CFrame.new(side * s.X * 0.33, top - 0.45, front - 0.07), 1)
			piece(upper, outfit, "ChestFold", Vector3.new(0.05, s.Y * 0.6, 0.04), C.SuitShade, CFrame.new(side * s.X * 0.18, -0.15, front - 0.05))
		end
		piece(upper, outfit, "JacketBack", Vector3.new(s.X + 0.1, s.Y, 0.06), C.SuitShade, CFrame.new(0, 0, -front + 0.05))
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.08, 0.02, 0.08), C.Suit, CFrame.new())
		-- The jacket flares out over his hips.
		for _, side in ipairs({ -1, 1 }) do
			piece(lower, outfit, "JacketTail", Vector3.new(ls.X * 0.52, 1.0, 0.08), C.Suit, CFrame.new(side * ls.X * 0.26, -0.3, -ls.Z / 2 - 0.08) * CFrame.Angles(math.rad(-6), 0, side * math.rad(8)))
			piece(lower, outfit, "JacketFlare", Vector3.new(0.1, 1.0, ls.Z + 0.24), C.SuitShade, CFrame.new(side * (ls.X / 2 + 0.12), -0.3, 0) * CFrame.Angles(0, 0, side * math.rad(10)))
		end
		piece(lower, outfit, "JacketTailBack", Vector3.new(ls.X + 0.3, 1.0, 0.08), C.SuitShade, CFrame.new(0, -0.3, ls.Z / 2 + 0.1) * CFrame.Angles(math.rad(6), 0, 0))
		for k = 0, 4 do
			piece(lower, outfit, "Zip", Vector3.new(0.07, 0.07, 0.04), k % 2 == 0 and C.Gold or C.GoldDark, CFrame.new(0, ls.Y / 2 - k * 0.14, -ls.Z / 2 - 0.13), Enum.Material.Metal)
		end
		-- The third ladybug, low on the jacket.
		ladybug(lower, outfit, CFrame.new(-ls.X * 0.26, -0.35, -ls.Z / 2 - 0.14), 1)
	end
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			piece(arm, outfit, "Sleeve", as + Vector3.new(0.1, 0.02, 0.1), C.Suit, CFrame.new())
			if name:find("Lower") or name == "Left Arm" or name == "Right Arm" then
				-- The gold cuff at the wrist.
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.16, 0.18, as.Z + 0.16), C.Gold, CFrame.new(0, -as.Y / 2 + 0.12, 0), Enum.Material.Metal)
				piece(arm, outfit, "CuffEdge", Vector3.new(as.X + 0.17, 0.04, as.Z + 0.17), C.GoldDark, CFrame.new(0, -as.Y / 2 + 0.22, 0), Enum.Material.Metal)
			end
		end
	end
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Trousers", leg.Size + Vector3.new(0.08, 0.02, 0.08), C.Suit, CFrame.new())
			piece(leg, outfit, "Crease", Vector3.new(0.04, leg.Size.Y, 0.04), C.SuitShade, CFrame.new(0.1, 0, -leg.Size.Z / 2 - 0.05))
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.06, 0.04, 0.16), C.Shoe, CFrame.new(0, 0, -0.05))
		end
	end
end

function GiornoOutfit.apply(character)
	if character:FindFirstChild("GiornoOutfit") then
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
	outfit.Name = "GiornoOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function GiornoOutfit.remove(character)
	local outfit = character:FindFirstChild("GiornoOutfit")
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
		if GiornoOutfit.Acts[character:GetAttribute("TuskAct")] then
			task.delay(0.3, function()
				if character.Parent and GiornoOutfit.Acts[character:GetAttribute("TuskAct")] then
					GiornoOutfit.apply(character)
				end
			end)
		else
			GiornoOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function GiornoOutfit.init()
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

return GiornoOutfit
