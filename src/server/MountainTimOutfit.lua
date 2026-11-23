--[[
	MountainTimOutfit  (ServerScriptService.SpinServer.MountainTimOutfit)

	Gives a character Mountain Tim's cowboy look while they play him (TuskAct 9),
	built from blocky parts (no catalog asset ids):
	  * a tall brown cowboy hat with a wide brim and a dark band
	  * a red bandana round the neck
	  * an open leather vest, a belt with a gold buckle and a coiled lasso
	    at his hip
	  * leather chaps, dark boots with silver spurs
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local MountainTimOutfit = {}
MountainTimOutfit.Act = 9

local C = {
	Hat = Color3.fromRGB(150, 100, 58),
	HatDark = Color3.fromRGB(110, 70, 40),
	Band = Color3.fromRGB(45, 30, 22),
	Bandana = Color3.fromRGB(190, 40, 38),
	Vest = Color3.fromRGB(120, 78, 44),
	VestTrim = Color3.fromRGB(80, 50, 28),
	Belt = Color3.fromRGB(60, 38, 22),
	Buckle = Color3.fromRGB(230, 190, 70),
	Rope = Color3.fromRGB(205, 170, 110),
	Chaps = Color3.fromRGB(138, 92, 52),
	Boot = Color3.fromRGB(70, 44, 28),
	Spur = Color3.fromRGB(200, 205, 215),
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

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local top = head.Size.Y / 2
	-- Cowboy hat: wide brim, tall crown with a dent, dark band.
	piece(head, outfit, "Brim", Vector3.new(head.Size.X + 1.3 * s, 0.14 * s, head.Size.Z + 1.1 * s), C.HatDark, CFrame.new(0, top + 0.02 * s, 0.02 * s))
	piece(head, outfit, "BrimFront", Vector3.new(head.Size.X + 0.9 * s, 0.12 * s, 0.4 * s), C.Hat, CFrame.new(0, top + 0.08 * s, -head.Size.Z / 2 - 0.45 * s) * CFrame.Angles(0.18, 0, 0))
	piece(head, outfit, "Crown", Vector3.new(head.Size.X * 0.85, 0.85 * s, head.Size.Z * 0.8), C.Hat, CFrame.new(0, top + 0.5 * s, 0.03 * s))
	piece(head, outfit, "Dent", Vector3.new(0.18 * s, 0.12 * s, head.Size.Z * 0.6), C.HatDark, CFrame.new(0, top + 0.92 * s, 0.03 * s))
	piece(head, outfit, "Band", Vector3.new(head.Size.X * 0.87, 0.18 * s, head.Size.Z * 0.82), C.Band, CFrame.new(0, top + 0.18 * s, 0.03 * s))
	-- Bandana: knotted round the neck, a triangle hanging in front.
	piece(head, outfit, "Bandana", Vector3.new(head.Size.X * 0.95, 0.22 * s, head.Size.Z * 0.95), C.Bandana, CFrame.new(0, -top - 0.08 * s, 0))
	piece(head, outfit, "BandanaTip", Vector3.new(0.6 * s, 0.5 * s, 0.08 * s), C.Bandana, CFrame.new(0, -top - 0.35 * s, -head.Size.Z / 2 - 0.02 * s) * CFrame.Angles(0, 0, math.pi / 4))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Vest", Vector3.new(s.X * 0.4, s.Y + 0.04, s.Z + 0.1), C.Vest, CFrame.new(side * s.X * 0.3, 0, 0))
			piece(upper, outfit, "VestTrim", Vector3.new(0.1, s.Y + 0.06, 0.06), C.VestTrim, CFrame.new(side * s.X * 0.1, 0, -s.Z / 2 - 0.07))
		end
		piece(upper, outfit, "VestBack", Vector3.new(s.X + 0.06, s.Y + 0.04, 0.08), C.Vest, CFrame.new(0, 0, s.Z / 2 + 0.04))
	end
	local waist = lower or upper
	if waist then
		local y = lower and 0 or -upper.Size.Y / 2 + 0.15
		piece(waist, outfit, "Belt", Vector3.new(waist.Size.X + 0.12, 0.3, waist.Size.Z + 0.12), C.Belt, CFrame.new(0, y, 0))
		piece(waist, outfit, "Buckle", Vector3.new(0.45, 0.32, 0.06), C.Buckle, CFrame.new(0, y, -waist.Size.Z / 2 - 0.09))
		-- Coiled lasso hanging at the right hip (a stepped ring of rope).
		local hip = CFrame.new(waist.Size.X / 2 + 0.25, y - 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			piece(waist, outfit, "Lasso", Vector3.new(0.14, 0.42, 0.14), C.Rope, hip * CFrame.new(math.cos(a) * 0.5, 0, math.sin(a) * 0.5) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.pi / 2))
		end
	end
	-- Chaps and boots with spurs.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Chaps", leg.Size + Vector3.new(0.1, 0.02, 0.1), C.Chaps, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			local tall = foot.Size.Y > 1.8
			local y = -foot.Size.Y / 2 + (tall and 0.35 or foot.Size.Y / 2)
			piece(foot, outfit, "Boot", Vector3.new(foot.Size.X + 0.12, tall and 0.7 or foot.Size.Y + 0.1, foot.Size.Z + 0.2), C.Boot, CFrame.new(0, y, -0.05))
			piece(foot, outfit, "Spur", Vector3.new(0.12, 0.12, 0.3), C.Spur, CFrame.new(0, y - 0.1, foot.Size.Z / 2 + 0.2))
		end
	end
end

function MountainTimOutfit.apply(character)
	if character:FindFirstChild("MountainTimOutfit") then
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
	outfit.Name = "MountainTimOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function MountainTimOutfit.remove(character)
	local outfit = character:FindFirstChild("MountainTimOutfit")
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
		if character:GetAttribute("TuskAct") == MountainTimOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == MountainTimOutfit.Act then
					MountainTimOutfit.apply(character)
				end
			end)
		else
			MountainTimOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function MountainTimOutfit.init()
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

return MountainTimOutfit
