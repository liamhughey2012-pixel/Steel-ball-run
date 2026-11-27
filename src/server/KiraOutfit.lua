--[[
	KiraOutfit  (ServerScriptService.SpinServer.KiraOutfit)

	Gives a character the look of Yoshikage Kira (Part 4) while they play him
	(TuskAct 26), built from blocky parts (no catalog asset ids):
	  * neat ash-blond hair, combed with a side part, swept back over his
	    ears; a calm brow
	  * a lavender SUIT jacket with notched lapels and darker edging, a
	    breast pocket and square, buttoned front
	  * a white shirt and his purple TIE dotted with little white SKULLS,
	    a gold tie clip
	  * a gold watch on his left wrist; matching lavender trousers with a
	    crease; dark brown shoes
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local KiraOutfit = {}
KiraOutfit.Act = 26

local C = {
	Suit = Color3.fromRGB(150, 116, 180),
	SuitShade = Color3.fromRGB(112, 82, 142),
	SuitLight = Color3.fromRGB(184, 156, 210),
	Shirt = Color3.fromRGB(240, 238, 236),
	Tie = Color3.fromRGB(96, 48, 120),
	Skull = Color3.fromRGB(244, 240, 244),
	Gold = Color3.fromRGB(236, 192, 72),
	Hair = Color3.fromRGB(222, 210, 176),
	HairShade = Color3.fromRGB(186, 172, 136),
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
	-- Neat, combed hair with a side part, swept back.
	piece(head, outfit, "HairCap", Vector3.new(head.Size.X + 0.1 * s, 0.32 * s, head.Size.Z + 0.12 * s), C.Hair, CFrame.new(0, h + 0.06 * s, 0.02 * s))
	piece(head, outfit, "HairSweep", Vector3.new(head.Size.X * 0.62, 0.22 * s, head.Size.Z + 0.14 * s), C.Hair, CFrame.new(0.12 * s, h + 0.25 * s, 0.02 * s) * CFrame.Angles(0, 0, math.rad(-6)))
	piece(head, outfit, "Part", Vector3.new(0.05 * s, 0.06 * s, head.Size.Z * 0.9), C.HairShade, CFrame.new(-0.22 * s, h + 0.23 * s, 0))
	piece(head, outfit, "Fringe", Vector3.new(head.Size.X + 0.06 * s, 0.18 * s, 0.14 * s), C.Hair, CFrame.new(0.04 * s, h - 0.02 * s, -d - 0.03 * s) * CFrame.Angles(0, 0, math.rad(-5)))
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.1 * s, 0.6 * s, 0.14 * s), C.Hair, CFrame.new(0, h - 0.25 * s, d + 0.05 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HairSide", Vector3.new(0.1 * s, 0.45 * s, head.Size.Z * 0.75), C.Hair, CFrame.new(side * (w + 0.04 * s), h - 0.22 * s, 0.08 * s))
		for k = 0, 1 do
			piece(head, outfit, "Comb", Vector3.new(0.03 * s, 0.04 * s, head.Size.Z * 0.7), C.HairShade, CFrame.new(side * (w + 0.09 * s), h - 0.12 * s - k * 0.14 * s, 0.08 * s))
		end
		piece(head, outfit, "Brow", Vector3.new(0.26 * s, 0.05 * s, 0.05 * s), C.HairShade, CFrame.new(side * 0.22 * s, 0.14 * s, -d - 0.02 * s))
	end
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
		piece(upper, outfit, "Collar", Vector3.new(0.7, 0.14, 0.2), C.Shirt, CFrame.new(0, top + 0.02, front + 0.02))
		piece(upper, outfit, "TieKnot", Vector3.new(0.16, 0.14, 0.06), C.Tie, CFrame.new(0, top - 0.08, front - 0.1))
		piece(upper, outfit, "Tie", Vector3.new(0.2, s.Y * 0.62, 0.05), C.Tie, CFrame.new(0, top - 0.15 - s.Y * 0.31, front - 0.1))
		for k = 0, 3 do
			local sk = piece(upper, outfit, "TieSkull", Vector3.new(0.05, 0.08, 0.08), C.Skull, CFrame.new((k % 2 == 0 and -0.03 or 0.04), top - 0.32 - k * 0.24, front - 0.13) * CFrame.Angles(0, math.pi / 2, 0))
			sk.Shape = Enum.PartType.Cylinder
		end
		piece(upper, outfit, "TieClip", Vector3.new(0.3, 0.04, 0.05), C.Gold, CFrame.new(0, top - 0.6, front - 0.135), Enum.Material.Metal)
		-- Notched lapels.
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Lapel", Vector3.new(0.3, s.Y * 0.62, 0.06), C.SuitLight, CFrame.new(side * 0.38, top - s.Y * 0.32, front - 0.08) * CFrame.Angles(0, 0, side * 0.3))
			piece(upper, outfit, "LapelNotch", Vector3.new(0.18, 0.12, 0.065), C.SuitShade, CFrame.new(side * 0.5, top - 0.1, front - 0.085) * CFrame.Angles(0, 0, side * -0.4))
		end
		-- Breast pocket and buttons.
		piece(upper, outfit, "Pocket", Vector3.new(0.34, 0.05, 0.05), C.SuitShade, CFrame.new(-s.X * 0.28, top - 0.45, front - 0.08))
		piece(upper, outfit, "PocketSquare", Vector3.new(0.2, 0.1, 0.04), C.Tie, CFrame.new(-s.X * 0.28, top - 0.39, front - 0.08))
		for k = 0, 1 do
			local b = piece(upper, outfit, "Button", Vector3.new(0.05, 0.11, 0.11), C.SuitShade, CFrame.new(0, -s.Y * 0.32 - k * 0.22, front - 0.09) * CFrame.Angles(0, math.pi / 2, 0))
			b.Shape = Enum.PartType.Cylinder
		end
		piece(upper, outfit, "Hem", Vector3.new(s.X + 0.14, 0.08, s.Z + 0.14), C.SuitShade, CFrame.new(0, -top + 0.04, 0))
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.Suit, CFrame.new())
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.1, 0.12, ls.Z + 0.1), C.SuitShade, CFrame.new(0, ls.Y / 2 - 0.06, 0))
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
