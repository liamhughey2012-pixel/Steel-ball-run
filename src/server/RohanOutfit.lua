--[[
	RohanOutfit  (ServerScriptService.SpinServer.RohanOutfit)

	Gives a character the look of Rohan Kishibe (Part 4) while they play him
	(TuskAct 28), built from blocky parts (no catalog asset ids), matched to
	his art:
	  * dark green-black hair, swept up and back into short spikes, under
	    his lime-green HEADBAND with its zigzag top edge
	  * gold PEN-NIB earrings
	  * a PURPLE shirt with a high mandarin collar and full sleeves
	  * a long LIME-GREEN VEST over it, buttoned, with gold pocket flaps,
	    hanging down over his hips
	  * purple trousers, dark shoes
	  * his slim pen in his right hand
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local RohanOutfit = {}
RohanOutfit.Act = 28

local C = {
	Hair = Color3.fromRGB(34, 56, 46),
	HairShade = Color3.fromRGB(22, 38, 32),
	Band = Color3.fromRGB(150, 210, 80),
	BandShade = Color3.fromRGB(96, 156, 50),
	Shirt = Color3.fromRGB(150, 70, 170),
	ShirtShade = Color3.fromRGB(110, 46, 130),
	Vest = Color3.fromRGB(176, 220, 100),
	VestShade = Color3.fromRGB(130, 176, 66),
	Gold = Color3.fromRGB(236, 192, 72),
	Pen = Color3.fromRGB(90, 140, 70),
	Shoe = Color3.fromRGB(40, 32, 40),
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

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Dark green hair, swept back and to one side.
	piece(head, outfit, "HairCap", Vector3.new(head.Size.X + 0.1 * s, 0.34 * s, head.Size.Z + 0.12 * s), C.Hair, CFrame.new(0, h + 0.1 * s, 0.03 * s))
	piece(head, outfit, "HairSweep", Vector3.new(head.Size.X * 0.8, 0.3 * s, head.Size.Z + 0.2 * s), C.Hair, CFrame.new(0.1 * s, h + 0.3 * s, 0.06 * s) * CFrame.Angles(math.rad(-8), 0, math.rad(-8)))
	for k = -2, 2 do
		piece(head, outfit, "HairSpike", Vector3.new(0.2 * s, 0.4 * s, 0.2 * s), C.Hair, CFrame.new(k * 0.18 * s, h + 0.5 * s, 0.15 * s) * CFrame.Angles(math.rad(-35), 0, math.rad(k * 12)))
	end
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.12 * s, 0.75 * s, 0.18 * s), C.Hair, CFrame.new(0, h - 0.3 * s, d + 0.06 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HairSide", Vector3.new(0.12 * s, 0.6 * s, head.Size.Z * 0.75), C.Hair, CFrame.new(side * (w + 0.05 * s), h - 0.25 * s, 0.1 * s))
		piece(head, outfit, "Brow", Vector3.new(0.28 * s, 0.06 * s, 0.05 * s), C.HairShade, CFrame.new(side * 0.22 * s, 0.14 * s, -d - 0.02 * s) * CFrame.Angles(0, 0, side * 0.18))
		-- Gold pen-nib earrings.
		local ear = CFrame.new(side * (w + 0.06 * s), -0.15 * s, 0.05 * s)
		piece(head, outfit, "EarringNib", Vector3.new(0.05 * s, 0.22 * s, 0.12 * s), C.Gold, ear * CFrame.new(0, -0.12 * s, 0), Enum.Material.Metal)
		piece(head, outfit, "EarringTip", Vector3.new(0.05 * s, 0.08 * s, 0.08 * s), C.Gold, ear * CFrame.new(0, -0.26 * s, 0) * CFrame.Angles(math.pi / 4, 0, 0), Enum.Material.Metal)
	end
	piece(head, outfit, "Fringe", Vector3.new(head.Size.X * 0.55, 0.22 * s, 0.12 * s), C.Hair, CFrame.new(-0.16 * s, h - 0.05 * s, -d - 0.04 * s) * CFrame.Angles(0, 0, math.rad(12)))
	-- The headband, its top edge cut into a zigzag like pen nibs.
	piece(head, outfit, "Headband", Vector3.new(head.Size.X + 0.16 * s, 0.18 * s, head.Size.Z + 0.16 * s), C.Band, CFrame.new(0, h + 0.02 * s, 0))
	for k = -3, 3 do
		piece(head, outfit, "BandTooth", Vector3.new(0.13 * s, 0.13 * s, 0.06 * s), C.Band, CFrame.new(k * 0.14 * s, h + 0.13 * s, -d - 0.08 * s) * CFrame.Angles(0, 0, math.pi / 4))
	end
	for _, side in ipairs({ -1, 1 }) do
		for k = -2, 2 do
			piece(head, outfit, "BandTooth", Vector3.new(0.06 * s, 0.13 * s, 0.13 * s), C.Band, CFrame.new(side * (w + 0.08 * s), h + 0.13 * s, k * 0.14 * s) * CFrame.Angles(math.pi / 4, 0, 0))
		end
	end
	piece(head, outfit, "BandLine", Vector3.new(head.Size.X + 0.17 * s, 0.03 * s, head.Size.Z + 0.17 * s), C.BandShade, CFrame.new(0, h - 0.06 * s, 0))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		-- The purple shirt, high mandarin collar.
		piece(upper, outfit, "Shirt", s + Vector3.new(0.08, 0.02, 0.08), C.Shirt, CFrame.new())
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.6, 0.38, s.Z * 0.75), C.Shirt, CFrame.new(0, top + 0.16, 0))
		piece(upper, outfit, "CollarEdge", Vector3.new(s.X * 0.62, 0.05, s.Z * 0.77), C.ShirtShade, CFrame.new(0, top + 0.34, 0))
		-- The long lime-green vest over it: front panels, back, gold pocket flaps.
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "VestFront", Vector3.new(s.X * 0.42, s.Y + 0.02, 0.08), C.Vest, CFrame.new(side * s.X * 0.27, 0, front - 0.06))
			piece(upper, outfit, "VestSide", Vector3.new(0.08, s.Y + 0.02, s.Z + 0.14), C.Vest, CFrame.new(side * (s.X / 2 + 0.06), 0, 0))
			piece(upper, outfit, "PocketFlap", Vector3.new(0.3, 0.07, 0.05), C.Gold, CFrame.new(side * s.X * 0.27, -s.Y * 0.2, front - 0.11), Enum.Material.Metal)
		end
		piece(upper, outfit, "ChestPocket", Vector3.new(0.24, 0.06, 0.05), C.Gold, CFrame.new(-s.X * 0.27, top - 0.32, front - 0.11), Enum.Material.Metal)
		piece(upper, outfit, "VestBack", Vector3.new(s.X + 0.14, s.Y + 0.02, 0.08), C.Vest, CFrame.new(0, 0, -front + 0.06))
		piece(upper, outfit, "VestEdge", Vector3.new(0.05, s.Y, 0.09), C.VestShade, CFrame.new(0, 0, front - 0.07))
		for k = 0, 3 do
			local b = piece(upper, outfit, "Button", Vector3.new(0.05, 0.1, 0.1), C.VestShade, CFrame.new(0.07, top - 0.2 - k * s.Y * 0.24, front - 0.11) * CFrame.Angles(0, math.pi / 2, 0))
			b.Shape = Enum.PartType.Cylinder
		end
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.08, 0.02, 0.08), C.Shirt, CFrame.new())
		-- The vest hangs down over his hips.
		for _, side in ipairs({ -1, 1 }) do
			piece(lower, outfit, "VestTail", Vector3.new(ls.X * 0.45, 1.3, 0.08), C.Vest, CFrame.new(side * ls.X * 0.27, -0.45, -ls.Z / 2 - 0.08) * CFrame.Angles(math.rad(-4), 0, 0))
			piece(lower, outfit, "VestTailSide", Vector3.new(0.08, 1.3, ls.Z + 0.14), C.Vest, CFrame.new(side * (ls.X / 2 + 0.07), -0.45, 0))
		end
		piece(lower, outfit, "VestTailBack", Vector3.new(ls.X + 0.14, 1.3, 0.08), C.Vest, CFrame.new(0, -0.45, ls.Z / 2 + 0.08))
	end
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			-- Full purple sleeves, loose at the cuff.
			piece(arm, outfit, "Sleeve", as + Vector3.new(0.12, 0.02, 0.12), C.Shirt, CFrame.new())
			if name:find("Lower") or name == "Left Arm" or name == "Right Arm" then
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.18, 0.2, as.Z + 0.18), C.ShirtShade, CFrame.new(0, -as.Y / 2 + 0.14, 0))
			end
		end
	end
	-- His G-pen in his right hand.
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand then
		local hs = hand.Size
		local grip = CFrame.new(0, -hs.Y / 2 - 0.05, -0.15) * CFrame.Angles(math.rad(-70), 0, 0)
		piece(hand, outfit, "PenHolder", Vector3.new(0.07, 0.85, 0.07), C.Pen, grip)
		piece(hand, outfit, "PenNib", Vector3.new(0.07, 0.18, 0.04), C.Gold, grip * CFrame.new(0, -0.48, 0), Enum.Material.Metal)
	end
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Trousers", leg.Size + Vector3.new(0.1, 0.02, 0.1), C.Shirt, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.06, 0.04, 0.16), C.Shoe, CFrame.new(0, 0, -0.05))
		end
	end
end

function RohanOutfit.apply(character)
	if character:FindFirstChild("RohanOutfit") then
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
	outfit.Name = "RohanOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function RohanOutfit.remove(character)
	local outfit = character:FindFirstChild("RohanOutfit")
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
		if character:GetAttribute("TuskAct") == RohanOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == RohanOutfit.Act then
					RohanOutfit.apply(character)
				end
			end)
		else
			RohanOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function RohanOutfit.init()
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

return RohanOutfit
