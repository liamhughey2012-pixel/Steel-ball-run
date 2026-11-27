--[[
	KiraOutfit  (ServerScriptService.SpinServer.KiraOutfit)

	Gives a character the look of Yoshikage Kira (Part 4) while they play him
	(TuskAct 26), built from blocky parts (no catalog asset ids):
	  matched to his art:
	  * GOLDEN blond hair, thick and wavy, swept up and back with one loose
	    strand curling down over his forehead; heavy brows
	  * a pale periwinkle SUIT: big shoulders, wide notched lapels, a breast
	    pocket, buttoned front
	  * a GREEN shirt with thin yellow pinstripes
	  * a black TIE covered in GOLD SKULLS
	  * a black belt with a silver buckle; matching periwinkle trousers with
	    a crease; a gold watch; dark brown shoes
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local KiraOutfit = {}
KiraOutfit.Act = 26

local C = {
	Suit = Color3.fromRGB(176, 162, 226),
	SuitShade = Color3.fromRGB(134, 118, 196),
	SuitLight = Color3.fromRGB(204, 194, 242),
	Shirt = Color3.fromRGB(112, 176, 124),
	Stripe = Color3.fromRGB(226, 214, 110),
	Tie = Color3.fromRGB(22, 26, 24),
	Skull = Color3.fromRGB(226, 182, 60),
	Gold = Color3.fromRGB(236, 192, 72),
	Belt = Color3.fromRGB(24, 24, 28),
	Hair = Color3.fromRGB(238, 200, 92),
	HairShade = Color3.fromRGB(196, 150, 54),
	Shoe = Color3.fromRGB(70, 44, 30),
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
	-- Thick golden hair, swept up and back in waves.
	piece(head, outfit, "HairCap", Vector3.new(head.Size.X + 0.12 * s, 0.36 * s, head.Size.Z + 0.14 * s), C.Hair, CFrame.new(0, h + 0.08 * s, 0.03 * s))
	for k = 0, 3 do
		-- Rolls of hair, each a little further back and higher.
		local wave = piece(head, outfit, "Wave", Vector3.new(head.Size.X + 0.1 * s - k * 0.06 * s, 0.26 * s, 0.32 * s), k % 2 == 0 and C.Hair or C.HairShade, CFrame.new(0, h + 0.28 * s + math.sin(k * 1.4) * 0.04 * s, -d + 0.12 * s + k * 0.3 * s) * CFrame.Angles(math.rad(-20 + k * 12), 0, 0))
		wave.Shape = Enum.PartType.Cylinder
		wave.Size = Vector3.new(head.Size.X + 0.1 * s - k * 0.06 * s, 0.3 * s, 0.3 * s)
	end
	piece(head, outfit, "Quiff", Vector3.new(head.Size.X * 0.9, 0.24 * s, 0.3 * s), C.Hair, CFrame.new(0.06 * s, h + 0.34 * s, -d + 0.02 * s) * CFrame.Angles(math.rad(-30), 0, math.rad(-4)))
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.12 * s, 0.7 * s, 0.18 * s), C.Hair, CFrame.new(0, h - 0.2 * s, d + 0.06 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HairSide", Vector3.new(0.14 * s, 0.55 * s, head.Size.Z * 0.8), C.Hair, CFrame.new(side * (w + 0.05 * s), h - 0.18 * s, 0.08 * s) * CFrame.Angles(0, 0, side * -0.08))
		piece(head, outfit, "HairWave", Vector3.new(0.04 * s, 0.05 * s, head.Size.Z * 0.7), C.HairShade, CFrame.new(side * (w + 0.12 * s), h - 0.08 * s, 0.08 * s))
		-- Heavy brows.
		piece(head, outfit, "Brow", Vector3.new(0.3 * s, 0.07 * s, 0.05 * s), C.HairShade, CFrame.new(side * 0.22 * s, 0.15 * s, -d - 0.02 * s) * CFrame.Angles(0, 0, side * 0.14))
	end
	-- The loose strand curling down over his forehead.
	piece(head, outfit, "Strand", Vector3.new(0.09 * s, 0.4 * s, 0.07 * s), C.Hair, CFrame.new(-0.24 * s, h - 0.05 * s, -d - 0.05 * s) * CFrame.Angles(0, 0, math.rad(18)))
	piece(head, outfit, "StrandCurl", Vector3.new(0.09 * s, 0.2 * s, 0.07 * s), C.Hair, CFrame.new(-0.31 * s, h - 0.28 * s, -d - 0.05 * s) * CFrame.Angles(0, 0, math.rad(-25)))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Jacket", s + Vector3.new(0.12, 0.02, 0.12), C.Suit, CFrame.new())
		-- White shirt and the skull tie in the V of the jacket.
		piece(upper, outfit, "Shirt", Vector3.new(0.62, s.Y * 0.62, 0.04), C.Shirt, CFrame.new(0, top - s.Y * 0.31, front - 0.07))
		for k = -3, 3 do
			piece(upper, outfit, "Pinstripe", Vector3.new(0.025, s.Y * 0.58, 0.045), C.Stripe, CFrame.new(k * 0.08, top - s.Y * 0.31, front - 0.075))
		end
		piece(upper, outfit, "Collar", Vector3.new(0.72, 0.16, 0.22), C.Shirt, CFrame.new(0, top + 0.03, front + 0.02))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "CollarPoint", Vector3.new(0.2, 0.14, 0.05), C.Shirt, CFrame.new(side * 0.14, top - 0.04, front - 0.09) * CFrame.Angles(0, 0, side * 0.6))
		end
		piece(upper, outfit, "TieKnot", Vector3.new(0.16, 0.14, 0.06), C.Tie, CFrame.new(0, top - 0.08, front - 0.1))
		piece(upper, outfit, "Tie", Vector3.new(0.26, s.Y * 0.62, 0.05), C.Tie, CFrame.new(0, top - 0.15 - s.Y * 0.31, front - 0.1))
		-- Gold skulls all over the tie.
		for k = 0, 3 do
			local x = k % 2 == 0 and -0.04 or 0.05
			local y = top - 0.3 - k * 0.24
			local sk = piece(upper, outfit, "TieSkull", Vector3.new(0.05, 0.13, 0.12), C.Skull, CFrame.new(x, y, front - 0.13) * CFrame.Angles(0, math.pi / 2, 0))
			sk.Shape = Enum.PartType.Cylinder
			piece(upper, outfit, "TieSkullJaw", Vector3.new(0.07, 0.05, 0.04), C.Skull, CFrame.new(x, y - 0.07, front - 0.13))
			for _, e in ipairs({ -1, 1 }) do
				piece(upper, outfit, "TieSkullEye", Vector3.new(0.025, 0.03, 0.02), C.Tie, CFrame.new(x + e * 0.025, y + 0.01, front - 0.16))
			end
		end
		-- Notched lapels.
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Lapel", Vector3.new(0.3, s.Y * 0.62, 0.06), C.SuitLight, CFrame.new(side * 0.38, top - s.Y * 0.32, front - 0.08) * CFrame.Angles(0, 0, side * 0.3))
			piece(upper, outfit, "LapelNotch", Vector3.new(0.18, 0.12, 0.065), C.SuitShade, CFrame.new(side * 0.5, top - 0.1, front - 0.085) * CFrame.Angles(0, 0, side * -0.4))
		end
		-- Breast pocket and buttons.
		piece(upper, outfit, "Pocket", Vector3.new(0.34, 0.05, 0.05), C.SuitShade, CFrame.new(-s.X * 0.28, top - 0.45, front - 0.08))
		for k = 0, 1 do
			local b = piece(upper, outfit, "Button", Vector3.new(0.05, 0.11, 0.11), C.SuitShade, CFrame.new(0, -s.Y * 0.32 - k * 0.22, front - 0.09) * CFrame.Angles(0, math.pi / 2, 0))
			b.Shape = Enum.PartType.Cylinder
		end
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "ShoulderPad", Vector3.new(0.5, 0.16, s.Z + 0.16), C.Suit, CFrame.new(side * (s.X / 2 - 0.1), top + 0.02, 0) * CFrame.Angles(0, 0, side * -0.12))
		end
		piece(upper, outfit, "Hem", Vector3.new(s.X + 0.14, 0.08, s.Z + 0.14), C.SuitShade, CFrame.new(0, -top + 0.04, 0))
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.Suit, CFrame.new())
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.1, 0.14, ls.Z + 0.1), C.Belt, CFrame.new(0, ls.Y / 2 - 0.06, 0))
		piece(lower, outfit, "Buckle", Vector3.new(0.2, 0.12, 0.04), Color3.fromRGB(200, 204, 214), CFrame.new(0, ls.Y / 2 - 0.06, -ls.Z / 2 - 0.07), Enum.Material.Metal)
		-- The jacket hangs a little below the waist.
		piece(lower, outfit, "JacketSkirt", Vector3.new(ls.X + 0.14, 0.5, ls.Z + 0.14), C.Suit, CFrame.new(0, -0.1, 0))
		piece(lower, outfit, "JacketVent", Vector3.new(0.04, 0.45, 0.04), C.SuitShade, CFrame.new(0, -0.1, ls.Z / 2 + 0.08))
	end
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			piece(arm, outfit, "Sleeve", as + Vector3.new(0.1, 0.02, 0.1), C.Suit, CFrame.new())
			if name:find("Lower") or name == "Left Arm" or name == "Right Arm" then
				piece(arm, outfit, "ShirtCuff", Vector3.new(as.X + 0.06, 0.1, as.Z + 0.06), C.Shirt, CFrame.new(0, -as.Y / 2 + 0.02, 0))
				if name:find("Left") then
					piece(arm, outfit, "Watch", Vector3.new(as.X + 0.14, 0.12, as.Z + 0.14), C.Gold, CFrame.new(0, -as.Y / 2 + 0.16, 0), Enum.Material.Metal)
				end
			end
		end
	end
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Trousers", leg.Size + Vector3.new(0.06, 0.02, 0.06), C.Suit, CFrame.new())
			piece(leg, outfit, "Crease", Vector3.new(0.03, leg.Size.Y - 0.1, 0.03), C.SuitShade, CFrame.new(0, 0, -leg.Size.Z / 2 - 0.04))
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.06, 0.04, 0.16), C.Shoe, CFrame.new(0, 0, -0.05))
		end
	end
end

function KiraOutfit.apply(character)
	if character:FindFirstChild("KiraOutfit") then
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
	outfit.Name = "KiraOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function KiraOutfit.remove(character)
	local outfit = character:FindFirstChild("KiraOutfit")
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
		if character:GetAttribute("TuskAct") == KiraOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == KiraOutfit.Act then
					KiraOutfit.apply(character)
				end
			end)
		else
			KiraOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function KiraOutfit.init()
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

return KiraOutfit
