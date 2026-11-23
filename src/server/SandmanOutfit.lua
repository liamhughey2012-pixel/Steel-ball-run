--[[
	SandmanOutfit  (ServerScriptService.SpinServer.SandmanOutfit)

	Gives a character Sandman's look while they play him (TuskAct 8), built
	from blocky parts (no catalog asset ids), matched to his art:
	  * mint-green hair over the top of his head with a black stripe down
	    the middle, two mint braids hanging in front tied with gold beads,
	    and a long black ponytail down his back
	  * a yellow collar round his shoulders with a black zigzag
	  * a bare chest with the red chevron tattoo and green shoulder tattoos
	  * a dark red corset studded with gold
	  * a sand-coloured loincloth with gold pyramid studs and hanging flaps
	  * yellow arm bands and long yellow gauntlets
	  * fringed sand leg wraps under the knees and at the ankles, black
	    shin bands and bare feet with sandal straps
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local SandmanOutfit = {}
SandmanOutfit.Act = 8

local C = {
	Mint = Color3.fromRGB(150, 210, 180),
	MintDark = Color3.fromRGB(110, 170, 145),
	Black = Color3.fromRGB(24, 22, 26),
	Bead = Color3.fromRGB(222, 178, 60),
	Yellow = Color3.fromRGB(240, 192, 50),
	YellowDark = Color3.fromRGB(200, 150, 30),
	Tattoo = Color3.fromRGB(180, 50, 60),
	TattooGreen = Color3.fromRGB(70, 140, 100),
	Corset = Color3.fromRGB(130, 46, 36),
	CorsetDark = Color3.fromRGB(96, 32, 26),
	Stud = Color3.fromRGB(222, 178, 60),
	Cloth = Color3.fromRGB(214, 196, 150),
	ClothDark = Color3.fromRGB(176, 156, 110),
	Wrap = Color3.fromRGB(205, 188, 145),
	Strap = Color3.fromRGB(120, 86, 56),
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
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Mint hair hugging the top of the head, a black stripe down the middle.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.12 * s, 0.34 * s, head.Size.Z + 0.12 * s), C.Mint, CFrame.new(0, h - 0.1 * s, 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.1 * s, 0.55 * s, head.Size.Z * 0.75), C.Mint, CFrame.new(side * (w + 0.04 * s), h - 0.38 * s, 0.12 * s))
	end
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.12 * s, 0.7 * s, 0.1 * s), C.Mint, CFrame.new(0, h - 0.4 * s, d + 0.04 * s))
	piece(head, outfit, "Stripe", Vector3.new(0.22 * s, 0.06 * s, head.Size.Z + 0.14 * s), C.Black, CFrame.new(0, h + 0.08 * s, 0.02 * s))
	piece(head, outfit, "Stripe", Vector3.new(0.22 * s, 0.3 * s, 0.06 * s), C.Black, CFrame.new(0, h - 0.12 * s, -d - 0.06 * s))
	-- Two braids hanging down in front of the shoulders, tied off with gold beads.
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (w - 0.02 * s)
		for i = 0, 5 do
			piece(head, outfit, "Braid", Vector3.new(0.2 * s, 0.24 * s, 0.2 * s), i % 2 == 0 and C.Mint or C.MintDark, CFrame.new(x, h - 0.5 * s - i * 0.22 * s, -d - 0.04 * s) * CFrame.Angles(0, 0, (i % 2 == 0 and 0.2 or -0.2)))
		end
		piece(head, outfit, "Bead", Vector3.new(0.16 * s, 0.14 * s, 0.16 * s), C.Bead, CFrame.new(x, h - 1.86 * s, -d - 0.04 * s))
		piece(head, outfit, "BraidTip", Vector3.new(0.12 * s, 0.2 * s, 0.12 * s), C.MintDark, CFrame.new(x, h - 2.02 * s, -d - 0.04 * s))
	end
	-- Long black ponytail down his back.
	for i = 0, 4 do
		piece(head, outfit, "Ponytail", Vector3.new((0.5 - i * 0.05) * s, 0.44 * s, 0.26 * s), C.Black, CFrame.new(0, h - 0.35 * s - i * 0.4 * s, d + 0.14 * s + i * 0.03 * s))
	end
end

local function body(character, outfit)
	local headPart = character:FindFirstChild("Head")
	local skin = headPart and headPart.Color or Color3.fromRGB(190, 130, 100)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		local r6 = not lower
		-- Bare chest.
		piece(upper, outfit, "Skin", s + Vector3.new(0.04, 0.02, 0.04), skin, CFrame.new())
		-- Yellow collar with a black zigzag, wrapping the shoulders.
		piece(upper, outfit, "Collar", Vector3.new(s.X + 0.16, 0.34, s.Z + 0.18), C.Yellow, CFrame.new(0, top - 0.12, 0))
		for i = -4, 4 do
			piece(upper, outfit, "Zigzag", Vector3.new(0.16, 0.16, 0.04), C.Black, CFrame.new(i * 0.22, top - 0.14, front - 0.11) * CFrame.Angles(0, 0, math.pi / 4))
		end
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.5, 0.14, s.Z + 0.12), C.Black, CFrame.new(0, top + 0.08, 0))
		-- Red chevron tattoo on his chest (his left), green tattoos on the shoulders.
		for i = 0, 2 do
			piece(upper, outfit, "Tattoo", Vector3.new(0.42, 0.07, 0.03), C.Tattoo, CFrame.new(0.45, top - 0.45 - i * 0.13, front - 0.03) * CFrame.Angles(0, 0, -0.35))
		end
		-- Dark red corset from under the chest down, studded with gold.
		local corsetH = r6 and s.Y * 0.5 or s.Y * 0.48
		local corsetY = -s.Y / 2 + corsetH / 2
		piece(upper, outfit, "Corset", Vector3.new(s.X + 0.12, corsetH, s.Z + 0.12), C.Corset, CFrame.new(0, corsetY, 0))
		piece(upper, outfit, "Corset", Vector3.new(s.X * 0.5, 0.18, 0.06), C.Corset, CFrame.new(0, corsetY + corsetH / 2 + 0.06, front - 0.07))
		piece(upper, outfit, "CorsetSeam", Vector3.new(0.08, corsetH, 0.03), C.CorsetDark, CFrame.new(0, corsetY, front - 0.08))
		for _, x in ipairs({ -0.75, -0.4, 0.4, 0.75 }) do
			for k = 0, 1 do
				piece(upper, outfit, "Stud", Vector3.new(0.1, 0.1, 0.05), C.Stud, CFrame.new(x, corsetY + corsetH / 2 - 0.12 - k * (corsetH - 0.24), front - 0.08))
			end
		end
	end
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.35
		if lower then
			piece(lower, outfit, "Corset", ws + Vector3.new(0.12, 0.02, 0.12), C.Corset, CFrame.new())
		end
		-- Loincloth: a band round the hips and flaps hanging front and back.
		local bandY = waistTop - 0.32
		piece(waist, outfit, "Loincloth", Vector3.new(ws.X + 0.22, 0.36, ws.Z + 0.22), C.Cloth, CFrame.new(0, bandY, 0))
		piece(waist, outfit, "Flap", Vector3.new(ws.X * 0.7, 0.9, 0.08), C.Cloth, CFrame.new(0, bandY - 0.6, -ws.Z / 2 - 0.13) * CFrame.Angles(-0.06, 0, 0))
		piece(waist, outfit, "Flap", Vector3.new(ws.X * 0.8, 0.8, 0.08), C.ClothDark, CFrame.new(0, bandY - 0.55, ws.Z / 2 + 0.13) * CFrame.Angles(0.06, 0, 0))
		for _, side in ipairs({ -1, 1 }) do
			piece(waist, outfit, "Flap", Vector3.new(0.08, 0.55, ws.Z * 0.8), C.ClothDark, CFrame.new(side * (ws.X / 2 + 0.13), bandY - 0.4, 0))
		end
		-- Gold pyramid studs on the cloth.
		for _, x in ipairs({ -0.65, 0, 0.65 }) do
			piece(waist, outfit, "Pyramid", Vector3.new(0.2, 0.2, 0.08), C.Stud, CFrame.new(x, bandY, -ws.Z / 2 - 0.14) * CFrame.Angles(0, 0, math.pi / 4))
		end
		piece(waist, outfit, "Pyramid", Vector3.new(0.2, 0.2, 0.08), C.Stud, CFrame.new(0, bandY - 0.95, -ws.Z / 2 - 0.2) * CFrame.Angles(0, 0, math.pi / 4))
	end
	-- Bare arms with a green tattoo on each shoulder, yellow band above the
	-- elbow and long yellow gauntlets.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local out = name:find("Left") and -1 or 1
			piece(arm, outfit, "Skin", as + Vector3.new(0.04, 0.02, 0.04), skin, CFrame.new())
			local tall = as.Y > 1.8
			if name:find("Upper") or tall then
				piece(arm, outfit, "Tattoo", Vector3.new(0.04, 0.32, 0.4), C.TattooGreen, CFrame.new(out * (as.X / 2 + 0.03), as.Y / 2 - 0.3, 0))
				piece(arm, outfit, "Armband", Vector3.new(as.X + 0.14, 0.3, as.Z + 0.14), C.Yellow, CFrame.new(0, tall and 0.15 or -as.Y / 2 + 0.2, 0))
			end
			if name:find("Lower") or tall then
				local gh = tall and as.Y * 0.42 or as.Y - 0.05
				piece(arm, outfit, "Gauntlet", Vector3.new(as.X + 0.16, gh, as.Z + 0.16), C.Yellow, CFrame.new(0, -as.Y / 2 + gh / 2, 0))
				piece(arm, outfit, "GauntletBand", Vector3.new(as.X + 0.18, 0.08, as.Z + 0.18), C.Black, CFrame.new(0, -as.Y / 2 + gh - 0.12, 0))
				piece(arm, outfit, "GauntletBand", Vector3.new(as.X + 0.18, 0.08, as.Z + 0.18), C.YellowDark, CFrame.new(0, -as.Y / 2 + 0.12, 0))
			end
		end
	end
	-- Bare legs, fringed wraps under the knee and at the ankle, black shin bands.
	local function fringe(leg, y)
		local ls = leg.Size
		piece(leg, outfit, "Wrap", Vector3.new(ls.X + 0.16, 0.2, ls.Z + 0.16), C.Wrap, CFrame.new(0, y, 0))
		for i = -2, 2 do
			piece(leg, outfit, "Fringe", Vector3.new(0.1, 0.24, 0.05), C.Wrap, CFrame.new(i * ls.X * 0.2, y - 0.2, -ls.Z / 2 - 0.1))
			piece(leg, outfit, "Fringe", Vector3.new(0.1, 0.24, 0.05), C.Wrap, CFrame.new(i * ls.X * 0.2, y - 0.2, ls.Z / 2 + 0.1))
		end
	end
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Skin", ls + Vector3.new(0.04, 0.02, 0.04), skin, CFrame.new())
			local tall = ls.Y > 1.8
			if name:find("Lower") or tall then
				local knee = tall and -0.05 or ls.Y / 2 - 0.12
				fringe(leg, knee)
				piece(leg, outfit, "ShinBand", Vector3.new(ls.X + 0.1, 0.34, ls.Z + 0.1), C.Black, CFrame.new(0, knee - 0.45, 0))
				fringe(leg, -ls.Y / 2 + 0.3)
			end
		end
	end
	-- Bare feet with a sandal strap.
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			local fs = foot.Size
			piece(foot, outfit, "Skin", fs + Vector3.new(0.04, 0.02, 0.04), skin, CFrame.new())
			piece(foot, outfit, "Strap", Vector3.new(fs.X + 0.08, 0.08, 0.14), C.Strap, CFrame.new(0, 0.02, -fs.Z * 0.15))
		end
	end
end

function SandmanOutfit.apply(character)
	if character:FindFirstChild("SandmanOutfit") then
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
	outfit.Name = "SandmanOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function SandmanOutfit.remove(character)
	local outfit = character:FindFirstChild("SandmanOutfit")
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
		if character:GetAttribute("TuskAct") == SandmanOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == SandmanOutfit.Act then
					SandmanOutfit.apply(character)
				end
			end)
		else
			SandmanOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function SandmanOutfit.init()
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

return SandmanOutfit
