--[[
	DioOutfit  (ServerScriptService.SpinServer.DioOutfit)

	Gives a character the look of DIO (Part 3) while they play him
	(TuskAct 21), built from blocky parts (no catalog asset ids), matched
	to his art (2026-11-26):
	  * wild, spiky BLOND hair; a thin band with a GREEN HEART on his
	    forehead
	  * a tight BLACK bodysuit with the muscles drawn on it, a turtleneck
	    with a silver ring round it, running down over his hips like a
	    leotard
	  * a CROPPED tan-ochre JACKET (it stops at his chest) with long
	    sleeves and big PUFFED shoulders; coiled bracelets at the wrists
	  * a GREEN BELT with a green HEART buckle and a green strap hanging
	    down his leg in a loop
	  * ochre trousers with big GREEN HEART knee pads; ribbed ochre boots
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local DioOutfit = {}
DioOutfit.Act = 21

local C = {
	Hair = Color3.fromRGB(246, 216, 96),
	HairShade = Color3.fromRGB(206, 166, 50),
	Band = Color3.fromRGB(150, 160, 70),
	HeartGreen = Color3.fromRGB(80, 176, 96),
	HeartDark = Color3.fromRGB(40, 120, 64),
	Jacket = Color3.fromRGB(214, 164, 72),
	JacketShade = Color3.fromRGB(170, 124, 44),
	JacketLight = Color3.fromRGB(236, 196, 110),
	Suit = Color3.fromRGB(26, 26, 30),
	SuitLine = Color3.fromRGB(52, 52, 60),
	Ring = Color3.fromRGB(186, 188, 196),
	Coil = Color3.fromRGB(196, 168, 90),
	CoilDark = Color3.fromRGB(120, 100, 44),
	Belt = Color3.fromRGB(110, 176, 70),
	BeltDark = Color3.fromRGB(70, 130, 46),
	Pants = Color3.fromRGB(214, 164, 72),
	Boot = Color3.fromRGB(196, 150, 64),
	BootDark = Color3.fromRGB(140, 104, 40),
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

local function cyl(parent, outfit, name, a, b, d, color)
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	local p = piece(parent, outfit, name, Vector3.new(len + d * 0.3, d, d), color, CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A heart facing forward (-Z of `cf`), `h` tall, with a darker rim.
local function heart(parent, outfit, cf, h, color, rim, depth)
	depth = depth or 0.08
	for _, side in ipairs({ -1, 1 }) do
		local lobe = piece(parent, outfit, "HeartLobe", Vector3.new(depth, h * 0.6, h * 0.6), color, cf * CFrame.new(side * h * 0.2, h * 0.14, 0) * CFrame.Angles(0, math.pi / 2, 0))
		lobe.Shape = Enum.PartType.Cylinder
		if rim then
			local r = piece(parent, outfit, "HeartRim", Vector3.new(depth * 0.8, h * 0.7, h * 0.7), rim, cf * CFrame.new(side * h * 0.2, h * 0.14, depth * 0.3) * CFrame.Angles(0, math.pi / 2, 0))
			r.Shape = Enum.PartType.Cylinder
		end
	end
	piece(parent, outfit, "HeartPoint", Vector3.new(h * 0.56, h * 0.56, depth), color, cf * CFrame.new(0, -h * 0.1, 0) * CFrame.Angles(0, 0, math.pi / 4))
	if rim then
		piece(parent, outfit, "HeartPointRim", Vector3.new(h * 0.64, h * 0.64, depth * 0.8), rim, cf * CFrame.new(0, -h * 0.12, depth * 0.3) * CFrame.Angles(0, 0, math.pi / 4))
	end
	-- A shine on the left lobe.
	piece(parent, outfit, "HeartShine", Vector3.new(h * 0.14, h * 0.1, depth * 1.1), Color3.fromRGB(200, 240, 200), cf * CFrame.new(-h * 0.26, h * 0.26, -depth * 0.1))
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Wild, spiky blond hair: a cap, spikes up and back and out to the
	-- sides, longer locks at the back, strands down the forehead.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.12 * s, 0.38 * s, head.Size.Z + 0.14 * s), C.Hair, CFrame.new(0, h - 0.06 * s, 0.03 * s))
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.14 * s, 0.95 * s, 0.26 * s), C.Hair, CFrame.new(0, h - 0.5 * s, d + 0.08 * s))
	local spikes = {
		{ 0, 0.15, 0.0, 0.7, -10, 0 }, { -0.25, 0.1, 0.05, 0.65, -20, 25 }, { 0.25, 0.1, 0.05, 0.65, -20, -25 },
		{ -0.42, 0.0, 0.1, 0.6, -10, 55 }, { 0.42, 0.0, 0.1, 0.6, -10, -55 }, { -0.15, 0.05, 0.3, 0.75, -45, 15 },
		{ 0.15, 0.05, 0.3, 0.75, -45, -15 }, { 0, -0.1, 0.45, 0.8, -70, 0 }, { -0.35, -0.2, 0.4, 0.7, -80, 35 },
		{ 0.35, -0.2, 0.4, 0.7, -80, -35 }, { -0.48, -0.35, 0.1, 0.6, 0, 80 }, { 0.48, -0.35, 0.1, 0.6, 0, -80 },
	}
	for i, sp in ipairs(spikes) do
		local cf = CFrame.new(sp[1] * s, h + sp[2] * s, sp[3] * s) * CFrame.Angles(math.rad(sp[5]), 0, math.rad(sp[6]))
		piece(head, outfit, "Spike", Vector3.new(0.24 * s, sp[4] * s, 0.2 * s), i % 3 == 0 and C.HairShade or C.Hair, cf * CFrame.new(0, sp[4] * 0.45 * s, 0))
		piece(head, outfit, "SpikeTip", Vector3.new(0.12 * s, 0.2 * s, 0.1 * s), C.Hair, cf * CFrame.new(0, sp[4] * 0.92 * s, 0))
	end
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "SideHair", Vector3.new(0.14 * s, 0.75 * s, head.Size.Z * 0.8), C.Hair, CFrame.new(side * (w + 0.05 * s), h - 0.5 * s, 0.08 * s))
		piece(head, outfit, "Strand", Vector3.new(0.08 * s, 0.45 * s, 0.05 * s), C.Hair, CFrame.new(side * 0.16 * s, h - 0.35 * s, -d - 0.03 * s) * CFrame.Angles(0, 0, side * 0.3))
	end
	-- A thin band with a green heart on his forehead.
	piece(head, outfit, "Headband", Vector3.new(head.Size.X + 0.1 * s, 0.09 * s, head.Size.Z + 0.1 * s), C.Band, CFrame.new(0, h - 0.27 * s, 0))
	heart(head, outfit, CFrame.new(0, h - 0.26 * s, -d - 0.07 * s), 0.3 * s, C.HeartGreen, C.HeartDark, 0.07 * s)
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front, back = s.Y / 2, -s.Z / 2, s.Z / 2
		-- The black bodysuit with its muscles drawn on.
		piece(upper, outfit, "Suit", s + Vector3.new(0.06, 0.02, 0.06), C.Suit, CFrame.new())
		piece(upper, outfit, "PecLine", Vector3.new(s.X * 0.55, 0.04, 0.04), C.SuitLine, CFrame.new(0, 0.15, front - 0.04))
		piece(upper, outfit, "Sternum", Vector3.new(0.04, 0.5, 0.04), C.SuitLine, CFrame.new(0, 0.35, front - 0.04))
		for k = 0, 2 do
			piece(upper, outfit, "AbLine", Vector3.new(0.45, 0.035, 0.04), C.SuitLine, CFrame.new(0, -0.12 - k * 0.22, front - 0.04))
		end
		piece(upper, outfit, "AbMid", Vector3.new(0.035, 0.7, 0.04), C.SuitLine, CFrame.new(0, -0.35, front - 0.04))
		-- Turtleneck with a silver ring.
		piece(upper, outfit, "Turtleneck", Vector3.new(0.75, 0.4, 0.7), C.Suit, CFrame.new(0, top + 0.17, 0))
		local ring = piece(upper, outfit, "NeckRing", Vector3.new(0.82, 0.1, 0.77), C.Ring, CFrame.new(0, top + 0.12, 0))
		ring.Material = Enum.Material.Metal
		-- The cropped jacket: top half only, open at the front.
		local jh = s.Y * 0.55
		local jy = top - jh / 2 + 0.02
		piece(upper, outfit, "JacketBack", Vector3.new(s.X + 0.16, jh, 0.12), C.Jacket, CFrame.new(0, jy, back + 0.04))
		piece(upper, outfit, "JacketHem", Vector3.new(s.X + 0.18, 0.08, 0.14), C.JacketShade, CFrame.new(0, jy - jh / 2, back + 0.04))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "JacketSide", Vector3.new(0.14, jh, s.Z + 0.16), C.Jacket, CFrame.new(side * (s.X / 2 + 0.03), jy, 0))
			piece(upper, outfit, "JacketFront", Vector3.new(s.X * 0.22, jh, 0.12), C.Jacket, CFrame.new(side * (s.X / 2 - s.X * 0.1), jy, front - 0.04))
			piece(upper, outfit, "Lapel", Vector3.new(0.12, jh * 0.8, 0.13), C.JacketLight, CFrame.new(side * (s.X / 2 - s.X * 0.2), jy + 0.05, front - 0.05) * CFrame.Angles(0, 0, side * 0.2))
			-- Big puffed shoulders.
			local puff = piece(upper, outfit, "Puff", Vector3.new(1.15, 0.9, 1.25), C.Jacket, CFrame.new(side * (s.X / 2 + 0.38), top - 0.05, 0))
			puff.Shape = Enum.PartType.Ball
			puff.Size = Vector3.new(1.15, 1.15, 1.15)
			piece(upper, outfit, "PuffTop", Vector3.new(1.0, 0.35, 1.05), C.JacketLight, CFrame.new(side * (s.X / 2 + 0.35), top + 0.3, 0) * CFrame.Angles(0, 0, side * -0.3))
		end
		-- A short stand-up collar on the jacket, behind the turtleneck.
		piece(upper, outfit, "JacketCollar", Vector3.new(s.X * 0.7, 0.35, 0.14), C.Jacket, CFrame.new(0, top + 0.12, back - 0.05))
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
		-- The bodysuit runs down over his hips like a leotard (a black V).
		for k = 0, 2 do
			local w = ls.X * (0.95 - k * 0.3)
			piece(lower, outfit, "Leotard", Vector3.new(w, 0.16, 0.05), C.Suit, CFrame.new(0, ls.Y / 2 - 0.08 - k * 0.15, -ls.Z / 2 - 0.05))
			piece(lower, outfit, "LeotardBack", Vector3.new(w, 0.16, 0.05), C.Suit, CFrame.new(0, ls.Y / 2 - 0.08 - k * 0.15, ls.Z / 2 + 0.05))
		end
		-- Green belt, green heart buckle, a strap looping down his left leg.
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.18, 0.16, ls.Z + 0.18), C.Belt, CFrame.new(0, ls.Y / 2 + 0.02, 0))
		heart(lower, outfit, CFrame.new(0, ls.Y / 2 + 0.02, -ls.Z / 2 - 0.13), 0.42, C.HeartGreen, C.HeartDark, 0.09)
		local hip = Vector3.new(-ls.X / 2 - 0.08, ls.Y / 2, -0.15)
		local pts = { hip, hip + Vector3.new(-0.12, -0.7, -0.15), hip + Vector3.new(-0.08, -1.5, -0.2), hip + Vector3.new(0.15, -1.9, -0.2), hip + Vector3.new(0.3, -1.4, -0.25), hip + Vector3.new(0.35, -0.6, -0.3) }
		for i = 1, #pts - 1 do
			cyl(lower, outfit, "Strap", pts[i], pts[i + 1], 0.1, i % 2 == 0 and C.BeltDark or C.Belt)
		end
	end
	-- Long tan sleeves, puffy at the top; coiled bracelets at the wrists.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			piece(arm, outfit, "Sleeve", as + Vector3.new(0.14, 0.02, 0.14), C.Jacket, CFrame.new())
			if name:find("Upper") then
				piece(arm, outfit, "SleeveFold", Vector3.new(as.X + 0.18, 0.06, as.Z + 0.18), C.JacketShade, CFrame.new(0, -as.Y * 0.1, 0))
			end
			if name:find("Lower") or name == "Left Arm" or name == "Right Arm" then
				for k = 0, 4 do
					piece(arm, outfit, "Coil", Vector3.new(as.X + 0.2, 0.07, as.Z + 0.2), k % 2 == 0 and C.Coil or C.CoilDark, CFrame.new(0, -as.Y / 2 + 0.1 + k * 0.08, 0) * CFrame.Angles(0, 0, 0.06))
				end
			end
		end
	end
	-- Ochre trousers, big green heart knee pads, ribbed boots.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
			if name:find("Lower") or name == "Left Leg" or name == "Right Leg" then
				local ky = name:find("Lower") and ls.Y / 2 - 0.05 or 0
				heart(leg, outfit, CFrame.new(0, ky, -ls.Z / 2 - 0.1), 0.85, C.HeartGreen, C.HeartDark, 0.14)
				-- Ribbed boots up to mid-shin.
				for k = 0, 4 do
					piece(leg, outfit, "BootRib", Vector3.new(ls.X + 0.12, 0.1, ls.Z + 0.12), k % 2 == 0 and C.Boot or C.BootDark, CFrame.new(0, -ls.Y / 2 + 0.08 + k * 0.1, 0))
				end
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			local fs = foot.Size
			piece(foot, outfit, "Boot", fs + Vector3.new(0.1, 0.04, 0.16), C.Boot, CFrame.new(0, 0, -0.04))
			piece(foot, outfit, "BootToe", Vector3.new(fs.X * 0.6, fs.Y * 0.7, 0.3), C.Boot, CFrame.new(0, -0.03, -fs.Z / 2 - 0.2))
			piece(foot, outfit, "BootHeel", Vector3.new(fs.X * 0.6, 0.15, 0.3), C.BootDark, CFrame.new(0, -fs.Y / 2 - 0.05, fs.Z / 2 - 0.12))
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
