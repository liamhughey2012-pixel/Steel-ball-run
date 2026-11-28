--[[
	ValentineOutfit  (ServerScriptService.SpinServer.ValentineOutfit)

	Gives a character Funny Valentine's look while they play him (TuskAct
	13), built from blocky parts (no catalog asset ids), matched to his art:
	  * long wavy blond hair down to his shoulders with big spiral ringlets
	    at the sides
	  * a pink long coat: a high grey collar, ribbed sleeves with grey
	    ruffled cuffs, the skirt flaring down to his calves
	  * magenta padded trousers with a belt, tall magenta boots
	  * magenta gloves with a lattice pattern
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local ValentineOutfit = {}
ValentineOutfit.Act = 13

local C = {
	Hair = Color3.fromRGB(238, 218, 130),
	HairDark = Color3.fromRGB(204, 180, 96),
	Coat = Color3.fromRGB(232, 150, 196),
	CoatShade = Color3.fromRGB(200, 116, 166),
	CoatDark = Color3.fromRGB(170, 86, 136),
	Collar = Color3.fromRGB(120, 116, 124),
	Pants = Color3.fromRGB(196, 96, 210),
	PantsShade = Color3.fromRGB(160, 70, 178),
	Belt = Color3.fromRGB(120, 54, 136),
	Glove = Color3.fromRGB(214, 110, 196),
	GloveLine = Color3.fromRGB(150, 60, 140),
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

-- A spiral ringlet: a ring of blocks curling round, facing sideways.
local function ringlet(head, outfit, cf, r, s)
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		local rr = r * (1 - k * 0.07)
		piece(head, outfit, "Ringlet", Vector3.new(0.14 * s, 0.2 * s, 0.2 * s), k % 2 == 0 and C.Hair or C.HairDark, cf * CFrame.new(0, math.sin(a) * rr, math.cos(a) * rr) * CFrame.Angles(-a, 0, 0))
	end
	piece(head, outfit, "RingletCore", Vector3.new(0.14 * s, 0.14 * s, 0.14 * s), C.HairDark, cf)
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Long wavy blond hair: over the top, a side part, down past the shoulders at the back.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.18 * s, 0.32 * s, head.Size.Z + 0.18 * s), C.Hair, CFrame.new(0, h - 0.02 * s, 0.02 * s))
	piece(head, outfit, "Bangs", Vector3.new(head.Size.X * 0.7, 0.3 * s, 0.12 * s), C.Hair, CFrame.new(-0.14 * s, h - 0.24 * s, -d - 0.04 * s) * CFrame.Angles(0, 0, 0.25))
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.3 * s, 1.5 * s, 0.26 * s), C.Hair, CFrame.new(0, -0.4 * s, d + 0.1 * s))
	piece(head, outfit, "HairWave", Vector3.new(head.Size.X + 0.34 * s, 0.12 * s, 0.28 * s), C.HairDark, CFrame.new(0, -0.6 * s, d + 0.11 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.18 * s, 1.2 * s, head.Size.Z * 0.85), C.Hair, CFrame.new(side * (w + 0.08 * s), -0.2 * s, 0.06 * s))
		-- Big spiral ringlets at the sides, one high and one at the shoulder.
		ringlet(head, outfit, CFrame.new(side * (w + 0.26 * s), 0.05 * s, -0.05 * s), 0.3 * s, s)
		ringlet(head, outfit, CFrame.new(side * (w + 0.22 * s), -0.75 * s, 0.15 * s), 0.26 * s, s)
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Coat", s + Vector3.new(0.1, 0.02, 0.1), C.Coat, CFrame.new())
		-- High grey collar.
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.6, 0.44, s.Z + 0.22), C.Collar, CFrame.new(0, top + 0.16, 0.02))
		piece(upper, outfit, "CollarFold", Vector3.new(s.X * 0.75, 0.2, s.Z + 0.26), C.CoatShade, CFrame.new(0, top - 0.02, 0.02))
		-- The coat closes in a diagonal line across the chest.
		piece(upper, outfit, "Closure", Vector3.new(0.08, s.Y * 1.05, 0.05), C.CoatDark, CFrame.new(0.15, -0.05, front - 0.06) * CFrame.Angles(0, 0, -0.18))
		piece(upper, outfit, "Panel", Vector3.new(s.X * 0.45, s.Y * 0.9, 0.05), C.CoatShade, CFrame.new(-0.42, -0.05, front - 0.05))
	end
	-- Long flaring coat skirt (front split), magenta trousers with a belt.
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.3
		if lower then
			piece(lower, outfit, "Pants", ws + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
		end
		piece(waist, outfit, "Belt", Vector3.new(ws.X + 0.1, 0.16, ws.Z + 0.1), C.Belt, CFrame.new(0, waistTop - 0.12, 0))
		local skirtH = lower and 2.4 or 2.0
		for _, side in ipairs({ -1, 1 }) do
			-- Front panels pulled back to the sides (the trousers show in the middle).
			piece(waist, outfit, "Skirt", Vector3.new(ws.X * 0.3, skirtH, 0.12), C.Coat, CFrame.new(side * (ws.X / 2 - 0.1), waistTop - skirtH / 2, -ws.Z / 2 - 0.1) * CFrame.Angles(0, side * 0.35, side * -0.05))
			piece(waist, outfit, "Skirt", Vector3.new(0.12, skirtH, ws.Z + 0.3), C.CoatShade, CFrame.new(side * (ws.X / 2 + 0.16), waistTop - skirtH / 2, 0.06) * CFrame.Angles(0, 0, side * -0.06))
		end
		piece(waist, outfit, "SkirtBack", Vector3.new(ws.X + 0.5, skirtH + 0.1, 0.12), C.Coat, CFrame.new(0, waistTop - skirtH / 2 - 0.05, ws.Z / 2 + 0.14) * CFrame.Angles(0.06, 0, 0))
		piece(waist, outfit, "Hem", Vector3.new(ws.X + 0.56, 0.1, 0.14), C.CoatDark, CFrame.new(0, waistTop - skirtH - 0.02, ws.Z / 2 + 0.22))
	end
	-- Ribbed pink sleeves with grey ruffled cuffs.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local tall = as.Y > 1.8
			local h = tall and as.Y - 0.3 or as.Y
			piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.1, h + 0.02, as.Z + 0.1), C.Coat, CFrame.new(0, as.Y / 2 - h / 2, 0))
			local y = as.Y / 2 - 0.25
			while y > as.Y / 2 - h + 0.15 do
				piece(arm, outfit, "Rib", Vector3.new(as.X + 0.16, 0.08, as.Z + 0.16), C.CoatShade, CFrame.new(0, y, 0))
				y = y - 0.3
			end
			if name:find("Lower") or tall then
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.2, 0.26, as.Z + 0.2), C.Collar, CFrame.new(0, as.Y / 2 - h + 0.05, 0))
			end
		end
	end
	-- Magenta lattice gloves.
	for _, name in ipairs({ "LeftHand", "RightHand" }) do
		local hand = character:FindFirstChild(name)
		if hand then
			local hs = hand.Size
			piece(hand, outfit, "Glove", hs + Vector3.new(0.08, 0.06, 0.08), C.Glove, CFrame.new())
			for _, a in ipairs({ 0.7, -0.7 }) do
				piece(hand, outfit, "Lattice", Vector3.new(hs.X * 1.2, 0.04, 0.04), C.GloveLine, CFrame.new(0, 0, -hs.Z / 2 - 0.06) * CFrame.Angles(0, 0, a))
			end
		end
	end
	-- Padded magenta trousers and tall boots.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Pants", ls + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
			piece(leg, outfit, "Pad", Vector3.new(ls.X * 0.7, ls.Y * 0.4, 0.06), C.PantsShade, CFrame.new(0, ls.Y * 0.12, -ls.Z / 2 - 0.05))
			if name:find("Lower") or ls.Y > 1.8 then
				local bh = ls.Y > 1.8 and 1.0 or ls.Y + 0.05
				piece(leg, outfit, "Boot", Vector3.new(ls.X + 0.12, bh, ls.Z + 0.12), C.Pants, CFrame.new(0, -ls.Y / 2 + bh / 2, 0))
				piece(leg, outfit, "BootTop", Vector3.new(ls.X + 0.16, 0.12, ls.Z + 0.16), C.PantsShade, CFrame.new(0, -ls.Y / 2 + bh, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Boot", foot.Size + Vector3.new(0.1, 0.06, 0.14), C.PantsShade, CFrame.new(0, 0, -0.03))
		end
	end
end

function ValentineOutfit.apply(character)
	if character:FindFirstChild("ValentineOutfit") then
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
	outfit.Name = "ValentineOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function ValentineOutfit.remove(character)
	local outfit = character:FindFirstChild("ValentineOutfit")
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
		local act = character:GetAttribute("TuskAct")
		if act == ValentineOutfit.Act or act == 33 then -- (and as D4C -Love Train-)
			task.delay(0.3, function()
				local now = character:GetAttribute("TuskAct")
				if character.Parent and (now == ValentineOutfit.Act or now == 33) then
					ValentineOutfit.apply(character)
				end
			end)
		else
			ValentineOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function ValentineOutfit.init()
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

return ValentineOutfit
