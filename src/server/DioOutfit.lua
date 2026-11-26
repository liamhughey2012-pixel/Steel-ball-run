--[[
	DioOutfit  (ServerScriptService.SpinServer.DioOutfit)

	Gives a character the look of DIO (Part 3) while they play him
	(TuskAct 21), built from blocky parts (no catalog asset ids):
	  * swept-up BLOND hair with spiky points and a few strands down the
	    forehead; a GREEN HEADBAND with a gold heart; green lips
	  * a YELLOW sleeveless jacket, open over a tight black top, with
	    flared shoulders and a high collar; bare arms with green wristbands
	  * a black belt with a green buckle
	  * YELLOW trousers with gold HEART knee pads, and yellow boots with
	    green trim
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local DioOutfit = {}
DioOutfit.Act = 21

local C = {
	Hair = Color3.fromRGB(246, 218, 120),
	HairShade = Color3.fromRGB(214, 176, 80),
	Band = Color3.fromRGB(50, 140, 96),
	Lips = Color3.fromRGB(60, 140, 90),
	Jacket = Color3.fromRGB(236, 194, 58),
	JacketShade = Color3.fromRGB(196, 150, 36),
	Top = Color3.fromRGB(28, 28, 32),
	Gold = Color3.fromRGB(246, 210, 90),
	Green = Color3.fromRGB(50, 140, 96),
	Belt = Color3.fromRGB(24, 24, 28),
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

local function heart(parent, outfit, cf, h)
	for _, side in ipairs({ -1, 1 }) do
		local lobe = piece(parent, outfit, "HeartLobe", Vector3.new(0.06, h * 0.6, h * 0.6), C.Gold, cf * CFrame.new(side * h * 0.2, h * 0.14, 0) * CFrame.Angles(0, math.pi / 2, 0))
		lobe.Shape = Enum.PartType.Cylinder
	end
	piece(parent, outfit, "HeartPoint", Vector3.new(h * 0.56, h * 0.56, 0.06), C.Gold, cf * CFrame.new(0, -h * 0.1, 0) * CFrame.Angles(0, 0, math.pi / 4))
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Blond hair swept up and back in spiky points.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.1 * s, 0.35 * s, head.Size.Z + 0.12 * s), C.Hair, CFrame.new(0, h - 0.08 * s, 0.03 * s))
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.1 * s, 0.75 * s, 0.22 * s), C.Hair, CFrame.new(0, h - 0.4 * s, d + 0.06 * s))
	for k = -2, 2 do
		local spike = CFrame.new(k * 0.22 * s, h + 0.12 * s, 0.1 * s + math.abs(k) * 0.05 * s) * CFrame.Angles(math.rad(-35), 0, math.rad(-k * 18))
		piece(head, outfit, "Spike", Vector3.new(0.24 * s, 0.6 * s, 0.2 * s), k % 2 == 0 and C.Hair or C.HairShade, spike * CFrame.new(0, 0.25 * s, 0))
	end
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "SideHair", Vector3.new(0.12 * s, 0.6 * s, head.Size.Z * 0.75), C.Hair, CFrame.new(side * (w + 0.04 * s), h - 0.42 * s, 0.08 * s))
		piece(head, outfit, "Strand", Vector3.new(0.08 * s, 0.4 * s, 0.05 * s), C.Hair, CFrame.new(side * 0.12 * s, h - 0.35 * s, -d - 0.03 * s) * CFrame.Angles(0, 0, side * 0.25))
	end
	-- The green headband with a gold heart.
	piece(head, outfit, "Headband", Vector3.new(head.Size.X + 0.12 * s, 0.14 * s, head.Size.Z + 0.12 * s), C.Band, CFrame.new(0, h - 0.24 * s, 0))
	heart(head, outfit, CFrame.new(0, h - 0.24 * s, -d - 0.08 * s), 0.26 * s)
	-- Green lips.
	piece(head, outfit, "Lips", Vector3.new(0.34 * s, 0.1 * s, 0.05 * s), C.Lips, CFrame.new(0, -0.3 * s, -d - 0.02 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	local head = character:FindFirstChild("Head")
	local skin = head and head.Color or Color3.fromRGB(236, 206, 176)
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Top", s + Vector3.new(0.06, 0.02, 0.06), C.Top, CFrame.new())
		-- The yellow jacket: sides, back and shoulders; open at the front.
		piece(upper, outfit, "JacketBack", Vector3.new(s.X + 0.14, s.Y + 0.04, 0.12), C.Jacket, CFrame.new(0, 0, -front + 0.02))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "JacketSide", Vector3.new(0.14, s.Y + 0.04, s.Z + 0.14), C.Jacket, CFrame.new(side * (s.X / 2 + 0.02), 0, 0))
			piece(upper, outfit, "JacketFront", Vector3.new(s.X * 0.3, s.Y + 0.04, 0.12), C.Jacket, CFrame.new(side * s.X * 0.36, 0, front - 0.04))
			piece(upper, outfit, "JacketEdge", Vector3.new(0.06, s.Y, 0.13), C.JacketShade, CFrame.new(side * s.X * 0.21, 0, front - 0.045))
			-- Flared shoulders.
			piece(upper, outfit, "Shoulder", Vector3.new(0.7, 0.3, s.Z + 0.3), C.Jacket, CFrame.new(side * (s.X / 2 + 0.15), top - 0.05, 0) * CFrame.Angles(0, 0, side * -0.35))
			piece(upper, outfit, "ShoulderEdge", Vector3.new(0.72, 0.06, s.Z + 0.32), C.JacketShade, CFrame.new(side * (s.X / 2 + 0.17), top - 0.2, 0) * CFrame.Angles(0, 0, side * -0.35))
		end
		-- A high collar.
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.7, 0.45, 0.16), C.Jacket, CFrame.new(0, top + 0.2, -front))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "CollarSide", Vector3.new(0.14, 0.45, s.Z * 0.8), C.Jacket, CFrame.new(side * s.X * 0.32, top + 0.2, 0) * CFrame.Angles(0, side * -0.25, 0))
		end
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.Jacket, CFrame.new())
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.16, 0.18, ls.Z + 0.16), C.Belt, CFrame.new(0, ls.Y / 2 - 0.08, 0))
		piece(lower, outfit, "Buckle", Vector3.new(0.3, 0.2, 0.06), C.Green, CFrame.new(0, ls.Y / 2 - 0.08, -ls.Z / 2 - 0.1))
	end
	-- Bare arms, green wristbands.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Skin", arm.Size + Vector3.new(0.04, 0, 0.04), skin, CFrame.new())
			if name:find("Lower") then
				piece(arm, outfit, "Wristband", Vector3.new(arm.Size.X + 0.14, 0.22, arm.Size.Z + 0.14), C.Green, CFrame.new(0, -arm.Size.Y / 2 + 0.14, 0))
			end
		end
	end
	-- Yellow trousers, gold heart knee pads.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.Jacket, CFrame.new())
			if name:find("Lower") or name == "Left Leg" or name == "Right Leg" then
				local ky = name:find("Lower") and ls.Y / 2 - 0.15 or 0
				heart(leg, outfit, CFrame.new(0, ky, -ls.Z / 2 - 0.06), 0.55)
				piece(leg, outfit, "BootTop", Vector3.new(ls.X + 0.14, 0.14, ls.Z + 0.14), C.Green, CFrame.new(0, -ls.Y / 2 + 0.4, 0))
				piece(leg, outfit, "Boot", Vector3.new(ls.X + 0.1, 0.4, ls.Z + 0.1), C.Jacket, CFrame.new(0, -ls.Y / 2 + 0.2, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "BootFoot", foot.Size + Vector3.new(0.1, 0.04, 0.16), C.Jacket, CFrame.new(0, 0, -0.04))
			piece(foot, outfit, "BootSole", Vector3.new(foot.Size.X + 0.12, 0.08, foot.Size.Z + 0.18), C.Green, CFrame.new(0, -foot.Size.Y / 2, -0.04))
		end
	end
end

function DioOutfit.apply(character)
	if character:FindFirstChild("DioOutfit") then
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
	outfit.Name = "DioOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function DioOutfit.remove(character)
	local outfit = character:FindFirstChild("DioOutfit")
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
		if character:GetAttribute("TuskAct") == DioOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == DioOutfit.Act then
					DioOutfit.apply(character)
				end
			end)
		else
			DioOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function DioOutfit.init()
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

return DioOutfit
