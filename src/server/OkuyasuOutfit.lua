--[[
	OkuyasuOutfit  (ServerScriptService.SpinServer.OkuyasuOutfit)

	Gives a character the look of Okuyasu Nijimura (Part 4) while they play
	him (TuskAct 27), built from blocky parts (no catalog asset ids):
	  * short dark hair: buzzed at the sides, a short flat top; a scar
	    running across his face; heavy, scowling brows
	  * a dark navy GAKURAN worn hanging OPEN over a white undershirt,
	    sleeves pushed up a little; a tall collar with a gold DOLLAR sign on
	    one side and a gold YEN sign on the other, and a gold $ pin on the
	    chest
	  * baggy navy trousers, a chain hanging from his belt, black shoes
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local OkuyasuOutfit = {}
OkuyasuOutfit.Act = 27

local C = {
	Coat = Color3.fromRGB(34, 40, 70),
	CoatShade = Color3.fromRGB(22, 26, 48),
	CoatLight = Color3.fromRGB(56, 64, 104),
	Shirt = Color3.fromRGB(236, 236, 232),
	Gold = Color3.fromRGB(236, 190, 70),
	Silver = Color3.fromRGB(200, 204, 214),
	Hair = Color3.fromRGB(46, 42, 48),
	HairShade = Color3.fromRGB(70, 64, 72),
	Scar = Color3.fromRGB(196, 120, 110),
	Shoe = Color3.fromRGB(20, 20, 24),
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

-- Gold glyphs (facing forward, -Z) made of little bars: a dollar sign and a yen sign.
local function bar(parent, outfit, cf, w, h)
	return piece(parent, outfit, "Glyph", Vector3.new(w, h, 0.04), C.Gold, cf, Enum.Material.Metal)
end

local function dollar(parent, outfit, cf, size)
	local t = size * 0.18
	bar(parent, outfit, cf * CFrame.new(0, size * 0.4, 0), size * 0.6, t)
	bar(parent, outfit, cf, size * 0.6, t)
	bar(parent, outfit, cf * CFrame.new(0, -size * 0.4, 0), size * 0.6, t)
	bar(parent, outfit, cf * CFrame.new(size * 0.25, size * 0.2, 0), t, size * 0.4)
	bar(parent, outfit, cf * CFrame.new(-size * 0.25, -size * 0.2, 0), t, size * 0.4)
	bar(parent, outfit, cf * CFrame.new(0, 0, -0.01), t * 0.6, size * 1.2)
end

local function yen(parent, outfit, cf, size)
	local t = size * 0.18
	for _, side in ipairs({ -1, 1 }) do
		bar(parent, outfit, cf * CFrame.new(side * size * 0.17, size * 0.28, 0) * CFrame.Angles(0, 0, side * -0.6), t, size * 0.5)
	end
	bar(parent, outfit, cf * CFrame.new(0, -size * 0.25, 0), t, size * 0.6)
	bar(parent, outfit, cf * CFrame.new(0, -size * 0.05, 0), size * 0.55, t * 0.8)
	bar(parent, outfit, cf * CFrame.new(0, -size * 0.28, 0), size * 0.55, t * 0.8)
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Buzzed sides, a short flat top.
	piece(head, outfit, "FlatTop", Vector3.new(head.Size.X - 0.04 * s, 0.32 * s, head.Size.Z - 0.02 * s), C.Hair, CFrame.new(0, h + 0.12 * s, 0))
	piece(head, outfit, "FlatTopEdge", Vector3.new(head.Size.X - 0.02 * s, 0.06 * s, head.Size.Z), C.HairShade, CFrame.new(0, h + 0.28 * s, 0))
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.04 * s, 0.6 * s, 0.06 * s), C.Hair, CFrame.new(0, h - 0.3 * s, d + 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Buzz", Vector3.new(0.05 * s, 0.4 * s, head.Size.Z * 0.85), C.HairShade, CFrame.new(side * (w + 0.02 * s), h - 0.18 * s, 0.02 * s))
		-- Heavy, scowling brows.
		piece(head, outfit, "Brow", Vector3.new(0.3 * s, 0.08 * s, 0.05 * s), C.Hair, CFrame.new(side * 0.22 * s, 0.13 * s, -d - 0.02 * s) * CFrame.Angles(0, 0, side * -0.25))
	end
	piece(head, outfit, "HairLine", Vector3.new(head.Size.X - 0.04 * s, 0.08 * s, 0.06 * s), C.Hair, CFrame.new(0, h - 0.02 * s, -d - 0.01 * s))
	-- The scar across his face.
	piece(head, outfit, "Scar", Vector3.new(0.7 * s, 0.04 * s, 0.03 * s), C.Scar, CFrame.new(0, 0.05 * s, -d - 0.02 * s) * CFrame.Angles(0, 0, math.rad(-28)))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		-- The white undershirt, showing all down the open front.
		piece(upper, outfit, "Undershirt", s + Vector3.new(0.04, 0, 0.04), C.Shirt, CFrame.new())
		-- The coat hanging open: back, sides and two front panels.
		piece(upper, outfit, "CoatBack", Vector3.new(s.X + 0.14, s.Y + 0.02, 0.12), C.Coat, CFrame.new(0, 0, s.Z / 2 + 0.03))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "CoatSide", Vector3.new(0.12, s.Y + 0.02, s.Z + 0.14), C.Coat, CFrame.new(side * (s.X / 2 + 0.03), 0, 0))
			piece(upper, outfit, "CoatFront", Vector3.new(s.X * 0.3, s.Y + 0.02, 0.1), C.Coat, CFrame.new(side * s.X * 0.37, 0, front - 0.05) * CFrame.Angles(0, side * -0.2, 0))
			piece(upper, outfit, "CoatEdge", Vector3.new(0.05, s.Y, 0.11), C.CoatLight, CFrame.new(side * s.X * 0.22, 0, front - 0.08) * CFrame.Angles(0, side * -0.2, 0))
			-- The tall collar.
			local cf = CFrame.new(side * s.X * 0.33, top + 0.28, -0.05) * CFrame.Angles(0, side * -0.3, 0)
			piece(upper, outfit, "CollarSide", Vector3.new(0.16, 0.6, s.Z * 0.95), C.Coat, cf)
			local face = cf * CFrame.new(0, 0.02, -s.Z * 0.48 - 0.02)
			if side == 1 then
				dollar(upper, outfit, face, 0.32)
			else
				yen(upper, outfit, face, 0.32)
			end
		end
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.75, 0.6, 0.18), C.Coat, CFrame.new(0, top + 0.28, -front))
		-- A gold $ pin on the coat.
		dollar(upper, outfit, CFrame.new(-s.X * 0.37, top - s.Y * 0.35, front - 0.12) * CFrame.Angles(0, 0.2, 0), 0.26)
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.1, 0.02, 0.1), C.Coat, CFrame.new())
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.14, 0.14, ls.Z + 0.14), C.CoatShade, CFrame.new(0, ls.Y / 2 - 0.06, 0))
		-- Coat tails, open at the front.
		piece(lower, outfit, "TailBack", Vector3.new(ls.X + 0.2, 2.0, 0.1), C.Coat, CFrame.new(0, -1.0, ls.Z / 2 + 0.16) * CFrame.Angles(math.rad(8), 0, 0))
		for _, side in ipairs({ -1, 1 }) do
			piece(lower, outfit, "TailSide", Vector3.new(0.1, 1.9, ls.Z + 0.3), C.Coat, CFrame.new(side * (ls.X / 2 + 0.16), -0.95, 0.05) * CFrame.Angles(0, 0, side * -0.12))
			piece(lower, outfit, "TailFront", Vector3.new(ls.X * 0.3, 1.9, 0.1), C.Coat, CFrame.new(side * ls.X * 0.38, -0.95, -ls.Z / 2 - 0.12) * CFrame.Angles(math.rad(-6), side * -0.2, side * -0.1))
		end
		-- A chain hanging from his belt.
		for k = 0, 5 do
			local a = k / 5 * math.pi
			local link = piece(lower, outfit, "Chain", Vector3.new(0.05, 0.1, 0.08), C.Silver, CFrame.new(ls.X * 0.15 + math.sin(a * 0.5) * 0.3, ls.Y / 2 - 0.15 - math.sin(a) * 0.35, -ls.Z / 2 - 0.1) * CFrame.Angles(0, 0, k * 0.6), Enum.Material.Metal)
			link.Name = "Chain"
		end
	end
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			piece(arm, outfit, "Sleeve", as + Vector3.new(0.12, 0.02, 0.12), C.Coat, CFrame.new())
			if name:find("Lower") or name == "Left Arm" or name == "Right Arm" then
				piece(arm, outfit, "PushedUp", Vector3.new(as.X + 0.18, 0.2, as.Z + 0.18), C.CoatShade, CFrame.new(0, -as.Y / 2 + 0.25, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local wide = name:find("Lower") and 0.24 or 0.16
			piece(leg, outfit, "Trousers", leg.Size + Vector3.new(wide, 0.02, wide), C.Coat, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.08, 0.04, 0.18), C.Shoe, CFrame.new(0, 0, -0.05))
		end
	end
end

function OkuyasuOutfit.apply(character)
	if character:FindFirstChild("OkuyasuOutfit") then
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
	outfit.Name = "OkuyasuOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function OkuyasuOutfit.remove(character)
	local outfit = character:FindFirstChild("OkuyasuOutfit")
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
		if character:GetAttribute("TuskAct") == OkuyasuOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == OkuyasuOutfit.Act then
					OkuyasuOutfit.apply(character)
				end
			end)
		else
			OkuyasuOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function OkuyasuOutfit.init()
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

return OkuyasuOutfit
