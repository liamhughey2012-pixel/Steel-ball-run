--[[
	GyroOutfit  (ServerScriptService.SpinServer.GyroOutfit)

	Dresses a character as Gyro Zeppeli while they play Gyro (TuskAct 5),
	built from parts so no catalog asset ids are needed:
	  * cream wide-brimmed hat, dark band, gold "GO! GO! ZEPPELI" plate
	  * long blond hair with two braids
	  * purple outfit with black stripes (shirt/pants swapped for body
	    colours + stripe bands), dark gloves, belt with a gold buckle, boots
	The player's own hats/hair are hidden and their clothes put back when
	they switch to another character. Works on R15 and R6. Built on the
	server so every player sees it.
]]

local Players = game:GetService("Players")

local GyroOutfit = {}
GyroOutfit.GyroAct = 5

local C = {
	Hat = Color3.fromRGB(232, 222, 200),
	HatBand = Color3.fromRGB(60, 40, 90),
	Gold = Color3.fromRGB(235, 190, 70),
	Hair = Color3.fromRGB(240, 205, 110),
	HairDark = Color3.fromRGB(210, 170, 80),
	Shirt = Color3.fromRGB(102, 64, 150),
	Pants = Color3.fromRGB(70, 46, 110),
	Stripe = Color3.fromRGB(25, 20, 35),
	Glove = Color3.fromRGB(45, 32, 70),
	Belt = Color3.fromRGB(95, 60, 35),
	Boot = Color3.fromRGB(70, 45, 30),
}

local saved = setmetatable({}, { __mode = "k" }) -- character -> what to restore

local function piece(parent, outfit, props, offset, ellipsoid)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	if ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = outfit
	return p
end

-- A flat stripe wrapped around a limb (limbs are boxes, so a box band fits).
local function band(limb, outfit, y, thickness, color)
	return piece(limb, outfit, { Name = "Band", Size = Vector3.new(limb.Size.X * 1.05, thickness, limb.Size.Z * 1.05), Color = color }, CFrame.new(0, y, 0))
end

local function hat(head, outfit)
	local s = head.Size.Y / 1.2
	local top = head.Size.Y * 0.5
	local base = CFrame.new(0, top - 0.05 * s, 0.05 * s) * CFrame.Angles(-0.12, 0, 0)
	piece(head, outfit, { Name = "HatBrim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1 * s, 2.7 * s, 2.7 * s), Color = C.Hat }, base * CFrame.Angles(0, 0, math.pi / 2))
	piece(head, outfit, { Name = "HatCrown", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.75 * s, 1.35 * s, 1.35 * s), Color = C.Hat }, base * CFrame.new(0, 0.42 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
	piece(head, outfit, { Name = "HatTop", Size = Vector3.new(1.3, 0.45, 1.3) * s, Color = C.Hat }, base * CFrame.new(0, 0.8 * s, 0), true)
	piece(head, outfit, { Name = "HatBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22 * s, 1.39 * s, 1.39 * s), Color = C.HatBand }, base * CFrame.new(0, 0.18 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
	-- Gold plate on the front of the band with the motto.
	local plate = piece(head, outfit, { Name = "HatPlate", Size = Vector3.new(0.9, 0.2, 0.05) * s, Color = C.Gold, Material = Enum.Material.Metal }, base * CFrame.new(0, 0.18 * s, -0.7 * s))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 120
	gui.Parent = plate
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(60, 30, 10)
	text.Text = "GO! GO! ZEPPELI"
	text.Parent = gui
	-- Two eyelets on the crown, like Gyro's hat.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, { Name = "HatEyelet", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 0.2, 0.2) * s, Color = C.Gold, Material = Enum.Material.Metal }, base * CFrame.new(side * 0.3 * s, 0.55 * s, -0.62 * s) * CFrame.Angles(0, math.pi / 2, 0))
	end
end

local function hair(head, outfit)
	local s = head.Size.Y / 1.2
	piece(head, outfit, { Name = "HairBack", Size = Vector3.new(1.25, 1.5, 0.55) * s, Color = C.Hair }, CFrame.new(0, -0.25 * s, 0.45 * s), true)
	piece(head, outfit, { Name = "HairTop", Size = Vector3.new(1.28, 0.6, 1.25) * s, Color = C.Hair }, CFrame.new(0, 0.38 * s, 0.05 * s), true)
	-- Long side locks framing the face, and two braids hanging past the shoulders.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, { Name = "SideHair", Size = Vector3.new(0.32, 1.5, 0.7) * s, Color = C.Hair }, CFrame.new(side * 0.66 * s, -0.35 * s, 0.12 * s), true)
		for i = 0, 5 do
			piece(head, outfit, { Name = "Braid", Size = Vector3.new(0.26, 0.34, 0.26) * s, Color = (i % 2 == 0) and C.Hair or C.HairDark }, CFrame.new(side * 0.78 * s, (-0.55 - i * 0.28) * s, -0.05 * s), true)
		end
	end
	-- Short fringe peeking out under the hat brim.
	piece(head, outfit, { Name = "Fringe", Size = Vector3.new(1.1, 0.25, 0.3) * s, Color = C.Hair }, CFrame.new(0, 0.42 * s, -0.5 * s), true)
end

local LIMBS = {
	R15 = {
		Arms = { "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" },
		Legs = { "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" },
		Hands = { "LeftHand", "RightHand" },
		Feet = { "LeftFoot", "RightFoot" },
		Torso = "UpperTorso",
		Waist = "LowerTorso",
	},
	R6 = {
		Arms = { "Left Arm", "Right Arm" },
		Legs = { "Left Leg", "Right Leg" },
		Hands = {},
		Feet = {},
		Torso = "Torso",
		Waist = "Torso",
	},
}

function GyroOutfit.apply(character)
	if character:FindFirstChild("GyroOutfit") then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local rig = character:FindFirstChild("UpperTorso") and "R15" or "R6"
	local parts = LIMBS[rig]
	local store = { Clothes = {}, Hidden = {}, Colors = nil }
	saved[character] = store

	-- Hide the player's own hats and hair; take off shirt / pants.
	for _, d in ipairs(character:GetChildren()) do
		if d:IsA("Accessory") then
			local handle = d:FindFirstChild("Handle")
			if handle and (d.AccessoryType == Enum.AccessoryType.Hat or d.AccessoryType == Enum.AccessoryType.Hair or d.AccessoryType == Enum.AccessoryType.Face or d.AccessoryType == Enum.AccessoryType.Unknown) then
				store.Hidden[handle] = handle.Transparency
				handle.Transparency = 1
			end
		elseif d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			table.insert(store.Clothes, d)
			d.Parent = nil
		end
	end
	local colors = character:FindFirstChildOfClass("BodyColors")
	if colors then
		store.Colors = {
			TorsoColor3 = colors.TorsoColor3,
			LeftArmColor3 = colors.LeftArmColor3,
			RightArmColor3 = colors.RightArmColor3,
			LeftLegColor3 = colors.LeftLegColor3,
			RightLegColor3 = colors.RightLegColor3,
		}
		colors.TorsoColor3 = C.Shirt
		colors.LeftArmColor3 = C.Shirt
		colors.RightArmColor3 = C.Shirt
		colors.LeftLegColor3 = C.Pants
		colors.RightLegColor3 = C.Pants
	end

	local outfit = Instance.new("Model")
	outfit.Name = "GyroOutfit"
	outfit.Parent = character

	hat(head, outfit)
	hair(head, outfit)

	-- Black stripes on arms, legs and torso.
	for _, name in ipairs(parts.Arms) do
		local limb = character:FindFirstChild(name)
		if limb then
			band(limb, outfit, limb.Size.Y * 0.2, 0.12, C.Stripe)
			band(limb, outfit, -limb.Size.Y * 0.2, 0.12, C.Stripe)
		end
	end
	for _, name in ipairs(parts.Legs) do
		local limb = character:FindFirstChild(name)
		if limb then
			band(limb, outfit, limb.Size.Y * 0.25, 0.12, C.Stripe)
			band(limb, outfit, -limb.Size.Y * 0.1, 0.12, C.Stripe)
		end
	end
	local torso = character:FindFirstChild(parts.Torso)
	if torso then
		for i = -1, 1 do
			piece(torso, outfit, { Name = "TorsoStripe", Size = Vector3.new(torso.Size.X * 1.02, 0.1, torso.Size.Z * 1.04), Color = C.Stripe }, CFrame.new(0, i * torso.Size.Y * 0.25, 0))
		end
		-- Collar.
		piece(torso, outfit, { Name = "Collar", Size = Vector3.new(torso.Size.X * 0.7, 0.25, torso.Size.Z * 1.1), Color = C.HatBand }, CFrame.new(0, torso.Size.Y * 0.47, 0), true)
	end
	-- Belt with a gold buckle.
	local waist = character:FindFirstChild(parts.Waist)
	if waist then
		local y = rig == "R6" and -waist.Size.Y * 0.42 or 0
		piece(waist, outfit, { Name = "Belt", Size = Vector3.new(waist.Size.X * 1.04, 0.22, waist.Size.Z * 1.06), Color = C.Belt, Material = Enum.Material.Leather }, CFrame.new(0, y, 0))
		piece(waist, outfit, { Name = "Buckle", Size = Vector3.new(0.35, 0.28, 0.06), Color = C.Gold, Material = Enum.Material.Metal }, CFrame.new(0, y, -waist.Size.Z * 0.54))
	end
	-- Gloves and boots.
	if rig == "R15" then
		for _, name in ipairs(parts.Hands) do
			local hand = character:FindFirstChild(name)
			if hand then
				piece(hand, outfit, { Name = "Glove", Size = hand.Size * Vector3.new(1.25, 2.2, 1.25), Color = C.Glove }, CFrame.new(0, 0.05, 0), true)
			end
		end
		for _, name in ipairs(parts.Feet) do
			local foot = character:FindFirstChild(name)
			if foot then
				piece(foot, outfit, { Name = "Boot", Size = foot.Size * Vector3.new(1.12, 1.6, 1.15), Color = C.Boot }, CFrame.new(0, 0.05, -0.05), true)
			end
		end
	else
		for _, name in ipairs({ "Left Arm", "Right Arm" }) do
			local arm = character:FindFirstChild(name)
			if arm then
				piece(arm, outfit, { Name = "Glove", Size = Vector3.new(1.1, 0.5, 1.1), Color = C.Glove }, CFrame.new(0, -arm.Size.Y * 0.4, 0))
			end
		end
		for _, name in ipairs({ "Left Leg", "Right Leg" }) do
			local leg = character:FindFirstChild(name)
			if leg then
				piece(leg, outfit, { Name = "Boot", Size = Vector3.new(1.1, 0.7, 1.15), Color = C.Boot }, CFrame.new(0, -leg.Size.Y * 0.36, -0.03))
			end
		end
	end
end

function GyroOutfit.remove(character)
	local outfit = character:FindFirstChild("GyroOutfit")
	if outfit then
		outfit:Destroy()
	end
	local store = saved[character]
	if not store then
		return
	end
	saved[character] = nil
	for handle, transparency in pairs(store.Hidden) do
		if handle.Parent then
			handle.Transparency = transparency
		end
	end
	for _, clothing in ipairs(store.Clothes) do
		clothing.Parent = character
	end
	local colors = character:FindFirstChildOfClass("BodyColors")
	if colors and store.Colors then
		for k, v in pairs(store.Colors) do
			colors[k] = v
		end
	end
end

local function watch(character)
	local function update()
		if character:GetAttribute("TuskAct") == GyroOutfit.GyroAct then
			-- Wait for the avatar's clothes/accessories to load before swapping them.
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == GyroOutfit.GyroAct then
					GyroOutfit.apply(character)
				end
			end)
		else
			GyroOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function GyroOutfit.init()
	local function onPlayer(player)
		player.CharacterAppearanceLoaded:Connect(watch)
		if player.Character then
			watch(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
end

return GyroOutfit
