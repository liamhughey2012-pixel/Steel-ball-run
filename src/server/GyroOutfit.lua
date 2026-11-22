--[[
	GyroOutfit  (ServerScriptService.SpinServer.GyroOutfit)

	Gives a character Gyro Zeppeli's hat and hair while they play Gyro
	(TuskAct 5), built from parts so no catalog asset ids are needed:
	  * tan wide-brimmed hat with slots cut round the brim, slits round the
	    crown, a domed top and two big ridged silver goggles on a strap
	  * long blond hair with side locks, braids and a fringe
	The player's own clothes stay on. Their own hats/hair are hidden while
	they play Gyro and come back when they switch. Built on the server so
	every player sees it.
]]

local Players = game:GetService("Players")

local GyroOutfit = {}
GyroOutfit.GyroAct = 5

local C = {
	Hat = Color3.fromRGB(206, 168, 128),
	HatShade = Color3.fromRGB(150, 105, 70),
	Slot = Color3.fromRGB(55, 38, 26),
	Strap = Color3.fromRGB(80, 84, 92),
	Goggle = Color3.fromRGB(176, 182, 192),
	HatBand = Color3.fromRGB(60, 40, 90),
	Gold = Color3.fromRGB(235, 190, 70),
	Hair = Color3.fromRGB(240, 205, 110),
	HairDark = Color3.fromRGB(210, 170, 80),
	Shirt = Color3.fromRGB(102, 64, 150),
	Pants = Color3.fromRGB(70, 46, 110),
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

-- Gyro's hat (from the owner's pictures): tan, a wide brim with slots cut
-- all the way round, slits around the crown, a domed top, and two big silver
-- goggles with ridged lenses strapped to the front.
local function hat(head, outfit)
	local s = head.Size.Y / 1.2
	local top = head.Size.Y * 0.5
	local base = CFrame.new(0, top - 0.05 * s, 0.05 * s) * CFrame.Angles(-0.12, 0, 0)
	local tan, tanDark = C.Hat, C.HatShade
	piece(head, outfit, { Name = "HatBrim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1 * s, 2.9 * s, 2.9 * s), Color = tan }, base * CFrame.Angles(0, 0, math.pi / 2))
	piece(head, outfit, { Name = "HatBrimEdge", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.09 * s, 2.96 * s, 2.96 * s), Color = tanDark }, base * CFrame.new(0, -0.01 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
	-- Slots cut into the brim, all the way round.
	for i = 0, 21 do
		local a = i / 22 * math.pi * 2
		local r = 1.08 * s
		piece(head, outfit, { Name = "BrimSlot", Size = Vector3.new(0.08 * s, 0.03 * s, 0.34 * s), Color = C.Slot }, base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.055 * s, -r))
	end
	-- Crown with slits, domed top.
	piece(head, outfit, { Name = "HatCrown", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.72 * s, 1.45 * s, 1.45 * s), Color = tan }, base * CFrame.new(0, 0.4 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
	piece(head, outfit, { Name = "HatTop", Size = Vector3.new(1.45, 0.42, 1.45) * s, Color = Color3.fromRGB(226, 196, 160) }, base * CFrame.new(0, 0.76 * s, 0), true)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		piece(head, outfit, { Name = "CrownSlit", Size = Vector3.new(0.06 * s, 0.34 * s, 0.03 * s), Color = C.Slot }, base * CFrame.new(0, 0.48 * s, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.73 * s))
	end
	-- Goggle strap around the crown.
	piece(head, outfit, { Name = "GoggleStrap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.16 * s, 1.5 * s, 1.5 * s), Color = C.Strap }, base * CFrame.new(0, 0.24 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
	-- Two big silver goggles with horizontal ridges, joined by a bridge.
	for _, side in ipairs({ -1, 1 }) do
		local lensCF = base * CFrame.new(side * 0.4 * s, 0.38 * s, -0.8 * s) * CFrame.Angles(0, side * 0.35, 0)
		piece(head, outfit, { Name = "GoggleRim", Size = Vector3.new(0.8, 0.62, 0.28) * s, Color = C.Strap, Material = Enum.Material.Metal }, lensCF * CFrame.new(0, 0, 0.04 * s), true)
		piece(head, outfit, { Name = "GoggleLens", Size = Vector3.new(0.72, 0.55, 0.32) * s, Color = C.Goggle, Material = Enum.Material.Metal, Reflectance = 0.25 }, lensCF, true)
		for r = -1, 1 do
			piece(head, outfit, { Name = "GoggleRidge", Size = Vector3.new(0.58 * s, 0.04 * s, 0.05 * s), Color = C.Strap, Material = Enum.Material.Metal }, lensCF * CFrame.new(0, r * 0.13 * s, -0.15 * s))
		end
	end
	piece(head, outfit, { Name = "GoggleBridge", Size = Vector3.new(0.22, 0.14, 0.14) * s, Color = C.Strap, Material = Enum.Material.Metal }, base * CFrame.new(0, 0.38 * s, -0.84 * s))
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

function GyroOutfit.apply(character)
	if character:FindFirstChild("GyroOutfit") then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local store = { Hidden = {} }
	saved[character] = store
	-- Hide the player's own hats and hair so they don't poke through Gyro's.
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
	outfit.Name = "GyroOutfit"
	outfit.Parent = character
	hat(head, outfit)
	hair(head, outfit)
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
