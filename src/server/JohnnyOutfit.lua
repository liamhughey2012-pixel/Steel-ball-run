--[[
	JohnnyOutfit  (ServerScriptService.SpinServer.JohnnyOutfit)

	Gives a character Johnny Joestar's look while they play him (Tusk, Acts
	1-4), built from blocky parts (no catalog asset ids), matched to his art:
	  * a light-blue knit cap covered in pink stars, a gold horseshoe on the
	    front with a black horse head inside it, little frayed tips
	  * wavy blond hair to his shoulders
	  * a lavender scarf round his neck
	  * a light-blue top with a black V across the chest, a purple star
	    patch on the sleeve, sleeves pushed up to lavender cuffs at the elbow,
	    bare forearms and black wristbands
	  * light-blue trousers covered in pink stars
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local JohnnyOutfit = {}
JohnnyOutfit.Act = 1 -- (any Tusk Act: 1-4)

local C = {
	Cap = Color3.fromRGB(176, 214, 236),
	CapShade = Color3.fromRGB(140, 182, 210),
	Star = Color3.fromRGB(236, 140, 186),
	Gold = Color3.fromRGB(222, 180, 64),
	GoldDark = Color3.fromRGB(170, 130, 40),
	Horse = Color3.fromRGB(26, 24, 28),
	Hair = Color3.fromRGB(232, 206, 140),
	HairDark = Color3.fromRGB(196, 168, 104),
	Scarf = Color3.fromRGB(184, 160, 222),
	Suit = Color3.fromRGB(170, 208, 232),
	SuitShade = Color3.fromRGB(134, 174, 204),
	Chevron = Color3.fromRGB(26, 28, 34),
	Patch = Color3.fromRGB(120, 90, 170),
	Band = Color3.fromRGB(30, 30, 34),
	Shoe = Color3.fromRGB(60, 54, 70),
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

-- Little pink stars (a diamond and a cross) scattered over one face.
local function stars(part, outfit, faceCF, w, h, count, seed)
	for i = 1, count do
		local u = ((i * 37 + seed * 17) % 100) / 100 - 0.5
		local v = ((i * 59 + seed * 31) % 100) / 100 - 0.5
		local cf = faceCF * CFrame.new(u * w * 0.85, v * h * 0.85, 0)
		piece(part, outfit, "Star", Vector3.new(0.12, 0.12, 0.03), C.Star, cf * CFrame.Angles(0, 0, math.pi / 4))
		piece(part, outfit, "Star", Vector3.new(0.2, 0.05, 0.03), C.Star, cf)
	end
end

-- Stars all round a box laid over a part.
local function starry(part, outfit, size, cf, count, seed)
	local x, z = size.X / 2 + 0.015, size.Z / 2 + 0.015
	stars(part, outfit, cf * CFrame.new(0, 0, -z), size.X, size.Y, count, seed)
	stars(part, outfit, cf * CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi, 0), size.X, size.Y, count, seed + 1)
	stars(part, outfit, cf * CFrame.new(x, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), size.Z, size.Y, math.max(1, count - 1), seed + 2)
	stars(part, outfit, cf * CFrame.new(-x, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), size.Z, size.Y, math.max(1, count - 1), seed + 3)
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Wavy blond hair down to the shoulders.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.18 * s, 1.0 * s, head.Size.Z * 0.85), C.Hair, CFrame.new(side * (w + 0.08 * s), -0.3 * s, 0.06 * s))
		piece(head, outfit, "HairWave", Vector3.new(0.22 * s, 0.3 * s, head.Size.Z * 0.5), C.HairDark, CFrame.new(side * (w + 0.12 * s), -0.75 * s, 0.1 * s) * CFrame.Angles(0, 0, side * 0.3))
	end
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.3 * s, 1.0 * s, 0.22 * s), C.Hair, CFrame.new(0, -0.4 * s, d + 0.1 * s))
	piece(head, outfit, "Bangs", Vector3.new(head.Size.X * 0.5, 0.18 * s, 0.1 * s), C.Hair, CFrame.new(0.15 * s, h - 0.42 * s, -d - 0.03 * s) * CFrame.Angles(0, 0, -0.25))
	-- The knit cap, pulled down low, with a folded band and little frayed tips.
	local capSize = Vector3.new(head.Size.X + 0.2 * s, 0.75 * s, head.Size.Z + 0.2 * s)
	local capCF = CFrame.new(0, h - 0.12 * s, 0.02 * s)
	piece(head, outfit, "Cap", capSize, C.Cap, capCF)
	piece(head, outfit, "CapTop", Vector3.new(head.Size.X * 0.8, 0.2 * s, head.Size.Z * 0.8), C.Cap, CFrame.new(0, h + 0.34 * s, 0.04 * s))
	piece(head, outfit, "CapBand", Vector3.new(head.Size.X + 0.26 * s, 0.18 * s, head.Size.Z + 0.26 * s), C.CapShade, CFrame.new(0, h - 0.42 * s, 0.02 * s))
	starry(head, outfit, capSize, capCF, 3, 4)
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "CapTip", Vector3.new(0.1 * s, 0.3 * s, 0.1 * s), C.CapShade, CFrame.new(side * (w + 0.02 * s), h + 0.24 * s, 0.2 * s) * CFrame.Angles(0, 0, side * -0.5))
	end
	-- Gold horseshoe on the front, opening upward, a black horse head inside.
	local hf = -d - 0.14 * s
	local hy = h - 0.02 * s
	piece(head, outfit, "Horseshoe", Vector3.new(0.5 * s, 0.1 * s, 0.06 * s), C.Gold, CFrame.new(0, hy - 0.26 * s, hf))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Horseshoe", Vector3.new(0.1 * s, 0.5 * s, 0.06 * s), C.Gold, CFrame.new(side * 0.22 * s, hy, hf) * CFrame.Angles(0, 0, side * 0.08))
		piece(head, outfit, "Nail", Vector3.new(0.04 * s, 0.04 * s, 0.04 * s), C.GoldDark, CFrame.new(side * 0.22 * s, hy + 0.05 * s, hf - 0.04 * s))
	end
	piece(head, outfit, "HorseHead", Vector3.new(0.18 * s, 0.34 * s, 0.04 * s), C.Horse, CFrame.new(0, hy - 0.02 * s, hf + 0.02 * s) * CFrame.Angles(0, 0, 0.3))
	piece(head, outfit, "HorseHead", Vector3.new(0.18 * s, 0.1 * s, 0.04 * s), C.Horse, CFrame.new(0.05 * s, hy + 0.14 * s, hf + 0.02 * s))
end

local function body(character, outfit)
	local headPart = character:FindFirstChild("Head")
	local skin = headPart and headPart.Color or Color3.fromRGB(238, 200, 170)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Top", s + Vector3.new(0.1, 0.02, 0.1), C.Suit, CFrame.new())
		-- Lavender scarf round the neck.
		piece(upper, outfit, "Scarf", Vector3.new(s.X * 0.62, 0.34, s.Z + 0.22), C.Scarf, CFrame.new(0, top + 0.1, 0))
		piece(upper, outfit, "ScarfDrape", Vector3.new(0.5, 0.36, 0.08), C.Scarf, CFrame.new(0.1, top - 0.14, front - 0.06))
		-- The black V across the chest (and a matching one at the back).
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Chevron", Vector3.new(0.22, s.Y * 0.75, 0.05), C.Chevron, CFrame.new(side * s.X * 0.22, top - s.Y * 0.3, front - 0.06) * CFrame.Angles(0, 0, side * -0.9))
			piece(upper, outfit, "Chevron", Vector3.new(0.22, s.Y * 0.75, 0.05), C.Chevron, CFrame.new(side * s.X * 0.22, top - s.Y * 0.3, -front + 0.06) * CFrame.Angles(0, 0, side * 0.9))
		end
		stars(upper, outfit, CFrame.new(0, -s.Y * 0.3, front - 0.06), s.X * 0.9, s.Y * 0.3, 2, 9)
	end
	local waist = lower or upper
	if waist and lower then
		piece(lower, outfit, "Pants", lower.Size + Vector3.new(0.06, 0.02, 0.06), C.Suit, CFrame.new())
	end
	-- Sleeves pushed up to the elbow (lavender cuffs), bare forearms, black wristbands.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local tall = as.Y > 1.8
			local out = name:find("Left") and -1 or 1
			if name:find("Upper") or tall then
				local h = tall and as.Y * 0.55 or as.Y
				piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.12, h, as.Z + 0.12), C.Suit, CFrame.new(0, as.Y / 2 - h / 2, 0))
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.18, 0.28, as.Z + 0.18), C.Scarf, CFrame.new(0, as.Y / 2 - h, 0))
				if name:find("Right") or name == "Right Arm" then
					piece(arm, outfit, "Patch", Vector3.new(0.05, 0.36, 0.36), C.Patch, CFrame.new(out * (as.X / 2 + 0.08), as.Y / 2 - 0.4, 0))
				end
			end
			if name:find("Lower") or tall then
				-- Bare forearm (covers whatever shirt the avatar wears).
				local fh = tall and as.Y * 0.45 or as.Y
				piece(arm, outfit, "Skin", Vector3.new(as.X + 0.04, fh, as.Z + 0.04), skin, CFrame.new(0, -as.Y / 2 + fh / 2, 0))
				piece(arm, outfit, "Wristband", Vector3.new(as.X + 0.12, 0.3, as.Z + 0.12), C.Band, CFrame.new(0, -as.Y / 2 + 0.25, 0))
			end
		end
	end
	-- Light-blue trousers covered in pink stars.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local size = leg.Size + Vector3.new(0.06, 0.02, 0.06)
			piece(leg, outfit, "Pants", size, C.Suit, CFrame.new())
			starry(leg, outfit, size, CFrame.new(), leg.Size.Y > 1.8 and 3 or 2, #name)
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.08, 0.06, 0.1), C.Shoe, CFrame.new())
		end
	end
end

function JohnnyOutfit.apply(character)
	if character:FindFirstChild("JohnnyOutfit") then
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
	outfit.Name = "JohnnyOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function JohnnyOutfit.remove(character)
	local outfit = character:FindFirstChild("JohnnyOutfit")
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
		local function isJohnny()
			local act = character:GetAttribute("TuskAct")
			return type(act) == "number" and act >= 1 and act <= 4
		end
		if isJohnny() then
			task.delay(0.3, function()
				if character.Parent and isJohnny() then
					JohnnyOutfit.apply(character)
				end
			end)
		else
			JohnnyOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function JohnnyOutfit.init()
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

return JohnnyOutfit
