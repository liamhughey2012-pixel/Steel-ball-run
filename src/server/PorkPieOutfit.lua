--[[
	PorkPieOutfit  (ServerScriptService.SpinServer.PorkPieOutfit)

	Gives a character Pork Pie Hat Kid's look while they play him (TuskAct 7),
	built from blocky parts so no catalog asset ids are needed (from the
	owner's pictures):
	  * green bamboo sticks tied round his bald head with a rope band,
	    sticking up and hanging down the sides like dreadlocks
	  * big round eyes with large black irises and bared teeth
	  * a green sleeveless suit with light-green studs in rows down both
	    sides of the chest and down both legs
	  * short golden feathers on the shoulders and a short frilly tutu
	  * big brown bracelets with leaves on both wrists
	The player's own hats/hair (and face) are hidden while they play him and
	come back when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local PorkPieOutfit = {}
PorkPieOutfit.Act = 7

local C = {
	Bamboo = Color3.fromRGB(130, 200, 70),
	BambooDark = Color3.fromRGB(80, 140, 45),
	BambooNode = Color3.fromRGB(175, 225, 110),
	Rope = Color3.fromRGB(150, 110, 70),
	Suit = Color3.fromRGB(95, 115, 45),
	SuitDark = Color3.fromRGB(70, 88, 32),
	Stud = Color3.fromRGB(165, 215, 80),
	Feather = Color3.fromRGB(215, 160, 60),
	FeatherDark = Color3.fromRGB(160, 105, 40),
	Bracelet = Color3.fromRGB(120, 75, 45),
	Leaf = Color3.fromRGB(200, 120, 50),
	EyeWhite = Color3.fromRGB(245, 245, 240),
	Iris = Color3.fromRGB(15, 15, 18),
	Teeth = Color3.fromRGB(250, 248, 235),
	Mouth = Color3.fromRGB(60, 25, 25),
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

-- One bamboo stick: a green rod with lighter node bands.
local function bamboo(head, outfit, s, cf, length)
	piece(head, outfit, "Bamboo", Vector3.new(0.26, length, 0.26) * s, C.Bamboo, cf)
	piece(head, outfit, "BambooNode", Vector3.new(0.3, 0.06, 0.3) * s, C.BambooNode, cf * CFrame.new(0, length * 0.15 * s, 0))
	piece(head, outfit, "BambooTip", Vector3.new(0.3, 0.05, 0.3) * s, C.BambooDark, cf * CFrame.new(0, length * 0.5 * s, 0))
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Rope band round the forehead (four sides) with a knot at the back.
	local bandY = h * 0.45
	piece(head, outfit, "Rope", Vector3.new(head.Size.X + 0.12 * s, 0.22 * s, 0.12 * s), C.Rope, CFrame.new(0, bandY, -d - 0.04 * s))
	piece(head, outfit, "Rope", Vector3.new(head.Size.X + 0.12 * s, 0.22 * s, 0.12 * s), C.Rope, CFrame.new(0, bandY, d + 0.04 * s))
	piece(head, outfit, "Rope", Vector3.new(0.12 * s, 0.22 * s, head.Size.Z + 0.12 * s), C.Rope, CFrame.new(-w - 0.04 * s, bandY, 0))
	piece(head, outfit, "Rope", Vector3.new(0.12 * s, 0.22 * s, head.Size.Z + 0.12 * s), C.Rope, CFrame.new(w + 0.04 * s, bandY, 0))
	piece(head, outfit, "RopeKnot", Vector3.new(0.3, 0.3, 0.2) * s, C.Rope, CFrame.new(0.2 * s, bandY, d + 0.12 * s))
	-- Bamboo crown: sticks pushed under the band, leaning out all round.
	local crown = {
		{ -0.45, -0.3, -0.25, 0.35 }, { -0.15, -0.35, -0.05, 0.1 }, { 0.15, -0.35, 0.05, -0.1 }, { 0.45, -0.3, 0.25, -0.35 },
		{ -0.5, 0.0, 0, 0.5 }, { 0.5, 0.0, 0, -0.5 }, { -0.3, 0.35, 0.35, 0.3 }, { 0.3, 0.35, 0.35, -0.3 }, { 0, 0.4, 0.4, 0 },
	}
	for _, b in ipairs(crown) do
		local base = CFrame.new(b[1] * head.Size.X, bandY + 0.2 * s, b[2] * head.Size.Z)
		bamboo(head, outfit, s, base * CFrame.Angles(b[3], 0, b[4]) * CFrame.new(0, 0.45 * s, 0), 1.0)
	end
	-- Sticks hanging down the sides and back like dreadlocks.
	local hang = { { -1, -0.25 }, { -1, 0.15 }, { 1, -0.25 }, { 1, 0.15 }, { -0.4, 1 }, { 0.4, 1 } }
	for _, b in ipairs(hang) do
		local x, z
		if math.abs(b[1]) == 1 then
			x, z = b[1] * (w + 0.18 * s), b[2] * head.Size.Z
		else
			x, z = b[1] * head.Size.X, d + 0.18 * s
		end
		local tilt = math.abs(b[1]) == 1 and CFrame.Angles(0, 0, b[1] * 0.25) or CFrame.Angles(-0.25, 0, 0)
		bamboo(head, outfit, s, CFrame.new(x, bandY - 0.45 * s, z) * tilt, 0.95)
	end
	-- Face: big round eyes with large black irises, bared teeth.
	local front = -d - 0.02 * s
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "EyeWhite", Vector3.new(0.4, 0.36, 0.04) * s, C.EyeWhite, CFrame.new(side * 0.25 * s, 0.08 * s, front))
		piece(head, outfit, "Iris", Vector3.new(0.28, 0.28, 0.04) * s, C.Iris, CFrame.new(side * 0.25 * s, 0.07 * s, front - 0.02 * s))
	end
	piece(head, outfit, "Mouth", Vector3.new(0.62, 0.24, 0.04) * s, C.Mouth, CFrame.new(0, -0.3 * s, front))
	piece(head, outfit, "Teeth", Vector3.new(0.58, 0.08, 0.04) * s, C.Teeth, CFrame.new(0, -0.23 * s, front - 0.02 * s))
	piece(head, outfit, "Teeth", Vector3.new(0.58, 0.08, 0.04) * s, C.Teeth, CFrame.new(0, -0.37 * s, front - 0.02 * s))
	-- Large angular jaw.
	piece(head, outfit, "Jaw", Vector3.new(head.Size.X * 0.9, 0.18 * s, head.Size.Z * 0.85), head.Color, CFrame.new(0, -h - 0.02 * s, -0.05 * s))
end

-- Green suit shell over a body part, with a row of studs on the front.
local function suit(part, outfit, studsX, studCount)
	local s = part.Size
	piece(part, outfit, "Suit", s + Vector3.new(0.1, 0.04, 0.1), C.Suit, CFrame.new())
	for _, x in ipairs(studsX) do
		for i = 1, studCount do
			local y = s.Y / 2 - (i - 0.5) * s.Y / studCount
			piece(part, outfit, "Stud", Vector3.new(0.24, 0.2, 0.12), C.Stud, CFrame.new(x * s.X / 2, y, -s.Z / 2 - 0.08))
		end
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		suit(upper, outfit, { -0.55, 0.55 }, lower and 3 or 4)
		-- Short feathers on both shoulders.
		for _, side in ipairs({ -1, 1 }) do
			for k = 0, 2 do
				local cf = CFrame.new(side * (upper.Size.X / 2 - 0.1), upper.Size.Y / 2 - 0.05, -0.25 + k * 0.25)
					* CFrame.Angles(0, 0, side * (-0.9 - k * 0.15)) * CFrame.new(0, 0.35, 0)
				piece(upper, outfit, "Feather", Vector3.new(0.18, 0.8, 0.3), k % 2 == 0 and C.Feather or C.FeatherDark, cf)
			end
		end
	end
	local waist = lower or upper
	if waist then
		if lower then
			suit(lower, outfit, {}, 0)
		end
		-- Short frilly tutu round the waist.
		local y = lower and -lower.Size.Y * 0.25 or -upper.Size.Y / 2 + 0.1
		local rx, rz = waist.Size.X / 2 + 0.15, waist.Size.Z / 2 + 0.15
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			local pos = Vector3.new(math.cos(a) * rx, y, math.sin(a) * rz)
			local cf = CFrame.lookAt(pos, pos + Vector3.new(math.cos(a), 0, math.sin(a))) * CFrame.Angles(-0.55, 0, 0)
			piece(waist, outfit, "Tutu", Vector3.new(0.7, 0.12, 0.7), i % 2 == 0 and C.Suit or C.SuitDark, cf)
		end
	end
	-- Legs: suit with studs down the front.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			suit(leg, outfit, { 0 }, name:find("Leg") and leg.Size.Y > 1.8 and 4 or 2)
		end
	end
	-- Sleeveless: bare arms (skin-coloured sleeves over whatever shirt the avatar wears).
	local headPart = character:FindFirstChild("Head")
	local skin = headPart and headPart.Color or Color3.fromRGB(230, 185, 140)
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Skin", arm.Size + Vector3.new(0.04, 0.02, 0.04), skin, CFrame.new())
		end
	end
	-- Big bracelets with leaves on both wrists.
	for _, name in ipairs({ "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local y = -arm.Size.Y / 2 + (arm.Size.Y > 1.8 and 0.55 or 0.25)
			piece(arm, outfit, "Bracelet", Vector3.new(arm.Size.X + 0.22, 0.45, arm.Size.Z + 0.22), C.Bracelet, CFrame.new(0, y, 0))
			piece(arm, outfit, "Leaf", Vector3.new(0.5, 0.08, 0.32), C.Leaf, CFrame.new(0, y + 0.1, -arm.Size.Z / 2 - 0.16) * CFrame.Angles(0.4, 0, 0.5))
			piece(arm, outfit, "Leaf", Vector3.new(0.4, 0.08, 0.26), C.FeatherDark, CFrame.new(0.15, y - 0.08, -arm.Size.Z / 2 - 0.15) * CFrame.Angles(-0.3, 0, -0.6))
		end
	end
end

function PorkPieOutfit.apply(character)
	if character:FindFirstChild("PorkPieOutfit") then
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
	local face = head:FindFirstChildOfClass("Decal")
	if face then
		store.Hidden[face] = face.Transparency
		face.Transparency = 1
	end
	local outfit = Instance.new("Model")
	outfit.Name = "PorkPieOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function PorkPieOutfit.remove(character)
	local outfit = character:FindFirstChild("PorkPieOutfit")
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
		if character:GetAttribute("TuskAct") == PorkPieOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == PorkPieOutfit.Act then
					PorkPieOutfit.apply(character)
				end
			end)
		else
			PorkPieOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function PorkPieOutfit.init()
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

return PorkPieOutfit
