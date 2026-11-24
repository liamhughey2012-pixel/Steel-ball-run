--[[
	TooruOutfit  (ServerScriptService.SpinServer.TooruOutfit)

	Gives a character the look of Tooru (JoJolion) while they play him
	(TuskAct 16), built from blocky parts (no catalog asset ids), matched
	to his art:
	  * a big round black hat, wide and flat, with a blue spiral on each
	    side of the front; dark slate hair under it; green lipstick
	  * a purple jacket with dark plaid lines on the sleeves, black front
	    panels either side of a purple zip, a grey hood round his neck
	  * the sun-spiral on his chest: a yellow swirl with orange rays and a
	    long curling tail (an "S")
	  * a little teddy bear clinging to each shoulder
	  * a yellow belt, gold patterned trousers, blue shoes
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local TooruOutfit = {}
TooruOutfit.Act = 16

local C = {
	Hat = Color3.fromRGB(24, 22, 30),
	HatShade = Color3.fromRGB(40, 38, 52),
	Spiral = Color3.fromRGB(70, 90, 170),
	Hair = Color3.fromRGB(56, 62, 84),
	Lips = Color3.fromRGB(70, 170, 140),
	Purple = Color3.fromRGB(120, 60, 170),
	PurpleDark = Color3.fromRGB(70, 30, 110),
	Panel = Color3.fromRGB(26, 20, 34),
	Hood = Color3.fromRGB(84, 74, 104),
	Yellow = Color3.fromRGB(244, 196, 40),
	Orange = Color3.fromRGB(236, 120, 40),
	SwirlLine = Color3.fromRGB(180, 110, 30),
	Bear = Color3.fromRGB(190, 140, 80),
	BearLight = Color3.fromRGB(226, 186, 130),
	BearDark = Color3.fromRGB(70, 44, 30),
	Belt = Color3.fromRGB(232, 168, 40),
	Gold = Color3.fromRGB(222, 192, 70),
	GoldDot = Color3.fromRGB(170, 130, 40),
	Shoe = Color3.fromRGB(44, 80, 200),
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

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Dark slate hair: short at the sides and a fringe peeking out under the hat.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.08 * s, 0.4 * s, head.Size.Z + 0.1 * s), C.Hair, CFrame.new(0, h - 0.2 * s, 0.02 * s))
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.1 * s, 0.6 * s, 0.12 * s), C.Hair, CFrame.new(0, 0.05 * s, d + 0.04 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Sideburn", Vector3.new(0.1 * s, 0.45 * s, 0.4 * s), C.Hair, CFrame.new(side * (w + 0.03 * s), 0.1 * s, 0.08 * s))
	end
	piece(head, outfit, "Fringe", Vector3.new(head.Size.X * 0.8, 0.14 * s, 0.08 * s), C.Hair, CFrame.new(-0.05 * s, h - 0.28 * s, -d - 0.03 * s))
	-- Green lipstick.
	piece(head, outfit, "Lips", Vector3.new(0.42 * s, 0.13 * s, 0.05 * s), C.Lips, CFrame.new(0, -0.32 * s, -d - 0.02 * s))
	-- The big round black hat: wide and flat, a rounded top.
	piece(head, outfit, "Hat", Vector3.new(head.Size.X + 1.1 * s, 0.5 * s, head.Size.Z + 0.75 * s), C.Hat, CFrame.new(0, h + 0.18 * s, 0.05 * s))
	piece(head, outfit, "HatTop", Vector3.new(head.Size.X + 0.8 * s, 0.2 * s, head.Size.Z + 0.5 * s), C.Hat, CFrame.new(0, h + 0.5 * s, 0.05 * s))
	piece(head, outfit, "HatRim", Vector3.new(head.Size.X + 1.2 * s, 0.14 * s, head.Size.Z + 0.85 * s), C.HatShade, CFrame.new(0, h - 0.03 * s, 0.05 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HatRound", Vector3.new(0.3 * s, 0.4 * s, head.Size.Z + 0.6 * s), C.Hat, CFrame.new(side * (w + 0.62 * s), h + 0.15 * s, 0.05 * s))
		-- A blue spiral on each side of the front: rings inside rings.
		local front = -(head.Size.Z / 2 + 0.38 * s) - 0.02 * s
		local at = CFrame.new(side * 0.55 * s, h + 0.22 * s, front)
		disc(head, outfit, "Spiral", 0.42 * s, 0.04 * s, C.Spiral, at)
		disc(head, outfit, "Spiral", 0.3 * s, 0.05 * s, C.Hat, at * CFrame.new(0.02 * s, 0.02 * s, -0.005 * s))
		disc(head, outfit, "Spiral", 0.18 * s, 0.06 * s, C.Spiral, at * CFrame.new(0.03 * s, 0.01 * s, -0.01 * s))
		disc(head, outfit, "Spiral", 0.07 * s, 0.07 * s, C.Hat, at * CFrame.new(0.04 * s, 0.01 * s, -0.015 * s))
	end
end

-- The sun-spiral: a yellow swirl, orange rays, and a long curling tail.
local function sunSpiral(upper, outfit, x, y, z)
	local at = CFrame.new(x, y, z)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		piece(upper, outfit, "Ray", Vector3.new(0.11, 0.17, 0.05), C.Orange, at * CFrame.new(math.sin(a) * 0.3, math.cos(a) * 0.3, 0.01) * CFrame.Angles(0, 0, -a))
	end
	disc(upper, outfit, "Swirl", 0.48, 0.05, C.Yellow, at)
	disc(upper, outfit, "SwirlLine", 0.3, 0.06, C.SwirlLine, at * CFrame.new(0.02, 0, -0.005))
	disc(upper, outfit, "SwirlIn", 0.18, 0.07, C.Yellow, at * CFrame.new(0.03, 0.01, -0.01))
	-- The tail curls down and round into an "S".
	piece(upper, outfit, "Tail", Vector3.new(0.12, 0.4, 0.05), C.Yellow, at * CFrame.new(0.16, -0.38, 0) * CFrame.Angles(0, 0, 0.35))
	piece(upper, outfit, "Tail", Vector3.new(0.12, 0.32, 0.05), C.Yellow, at * CFrame.new(0.18, -0.68, 0) * CFrame.Angles(0, 0, -0.5))
	piece(upper, outfit, "Tail", Vector3.new(0.28, 0.12, 0.05), C.Yellow, at * CFrame.new(0.03, -0.84, 0) * CFrame.Angles(0, 0, 0.2))
	piece(upper, outfit, "TailCurl", Vector3.new(0.12, 0.17, 0.05), C.Yellow, at * CFrame.new(-0.1, -0.75, 0))
end

-- A little teddy bear clinging to the outside of a shoulder.
local function bear(arm, outfit, side)
	local as = arm.Size
	local base = CFrame.new(side * (as.X / 2 + 0.16), as.Y / 2 - 0.35, -0.05)
	piece(arm, outfit, "BearBody", Vector3.new(0.42, 0.588, 0.448), C.Bear, base)
	piece(arm, outfit, "BearBelly", Vector3.new(0.252, 0.336, 0.07), C.BearLight, base * CFrame.new(0, -0.056, -0.238))
	piece(arm, outfit, "BearHead", Vector3.new(0.448, 0.42, 0.42), C.Bear, base * CFrame.new(0, 0.476, -0.028))
	piece(arm, outfit, "BearSnout", Vector3.new(0.196, 0.14, 0.112), C.BearLight, base * CFrame.new(0, 0.42, -0.266))
	piece(arm, outfit, "BearNose", Vector3.new(0.084, 0.07, 0.056), C.BearDark, base * CFrame.new(0, 0.462, -0.336))
	for _, e in ipairs({ -1, 1 }) do
		local ear = piece(arm, outfit, "BearEar", Vector3.new(0.168, 0.168, 0.168), C.Bear, base * CFrame.new(e * 0.168, 0.7, -0.028))
		ear.Shape = Enum.PartType.Ball
		piece(arm, outfit, "BearEye", Vector3.new(0.056, 0.056, 0.042), C.BearDark, base * CFrame.new(e * 0.098, 0.546, -0.224))
		-- Arms hugging round the shoulder.
		piece(arm, outfit, "BearArm", Vector3.new(0.126, 0.126, 0.42), C.Bear, base * CFrame.new(-side * 0.196, 0.14 + e * 0.112, -0.168))
	end
	piece(arm, outfit, "BearLeg", Vector3.new(0.14, 0.252, 0.14), C.Bear, base * CFrame.new(0.098, -0.364, -0.084))
	piece(arm, outfit, "BearLeg", Vector3.new(0.14, 0.252, 0.14), C.Bear, base * CFrame.new(-0.098, -0.364, -0.084))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front, back = s.Y / 2, -s.Z / 2, s.Z / 2
		-- Purple jacket, black front panels either side of a purple zip.
		piece(upper, outfit, "Jacket", s + Vector3.new(0.1, 0.02, 0.1), C.Purple, CFrame.new())
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Panel", Vector3.new(s.X * 0.4, s.Y - 0.1, 0.05), C.Panel, CFrame.new(side * s.X * 0.27, -0.05, front - 0.06))
			piece(upper, outfit, "Shoulder", Vector3.new(s.X * 0.35, 0.1, s.Z + 0.14), C.Purple, CFrame.new(side * s.X * 0.32, top + 0.02, 0))
		end
		piece(upper, outfit, "Zip", Vector3.new(0.05, s.Y - 0.1, 0.06), C.PurpleDark, CFrame.new(0, -0.05, front - 0.07))
		-- The grey hood bunched round his neck and down his back.
		piece(upper, outfit, "Hood", Vector3.new(s.X * 0.75, 0.3, s.Z + 0.2), C.Hood, CFrame.new(0, top + 0.08, 0.04))
		piece(upper, outfit, "HoodBack", Vector3.new(s.X * 0.65, s.Y * 0.4, 0.14), C.Hood, CFrame.new(0, top - s.Y * 0.18, back + 0.1))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "HoodFront", Vector3.new(0.18, 0.4, 0.14), C.Hood, CFrame.new(side * 0.3, top - 0.12, front - 0.06) * CFrame.Angles(0, 0, side * 0.3))
		end
		-- The sun-spiral on his chest (on the black panel).
		sunSpiral(upper, outfit, s.X * 0.27, 0.3, front - 0.1)
	end
	-- Yellow belt, gold patterned trousers.
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.25
		if lower then
			piece(lower, outfit, "Pants", ws + Vector3.new(0.06, 0.02, 0.06), C.Gold, CFrame.new())
		end
		piece(waist, outfit, "Belt", Vector3.new(ws.X + 0.1, 0.18, ws.Z + 0.1), C.Belt, CFrame.new(0, waistTop - 0.1, 0))
		piece(waist, outfit, "Buckle", Vector3.new(0.34, 0.22, 0.06), C.Yellow, CFrame.new(0, waistTop - 0.1, -ws.Z / 2 - 0.08))
		piece(waist, outfit, "BuckleHole", Vector3.new(0.2, 0.1, 0.07), C.Belt, CFrame.new(0, waistTop - 0.1, -ws.Z / 2 - 0.09))
	end
	-- Purple sleeves with dark plaid lines; a teddy bear on each shoulder.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			piece(arm, outfit, "Sleeve", as + Vector3.new(0.1, 0.02, 0.1), C.Purple, CFrame.new())
			for k = -1, 1, 2 do
				piece(arm, outfit, "Plaid", Vector3.new(0.06, as.Y, as.Z + 0.14), C.PurpleDark, CFrame.new(k * as.X * 0.22, 0, 0))
				piece(arm, outfit, "Plaid", Vector3.new(as.X + 0.14, 0.06, 0.06), C.PurpleDark, CFrame.new(0, k * as.Y * 0.22, -as.Z / 2 - 0.06))
			end
			if name:find("Upper") or (as.Y > 1.8 and not name:find("Lower")) then
				local side = name:find("Left") and -1 or 1
				bear(arm, outfit, side)
			end
		end
	end
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Pants", ls + Vector3.new(0.06, 0.02, 0.06), C.Gold, CFrame.new())
			-- A little pattern of darker flowers.
			for k = 0, 2 do
				local y = (k - 1) * ls.Y * 0.3
				piece(leg, outfit, "Flower", Vector3.new(0.14, 0.14, 0.05), C.GoldDot, CFrame.new((k % 2 == 0 and 0.15 or -0.15), y, -ls.Z / 2 - 0.05) * CFrame.Angles(0, 0, math.pi / 4))
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.08, 0.04, 0.12), C.Shoe, CFrame.new())
		end
	end
end

function TooruOutfit.apply(character)
	if character:FindFirstChild("TooruOutfit") then
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
	outfit.Name = "TooruOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function TooruOutfit.remove(character)
	local outfit = character:FindFirstChild("TooruOutfit")
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
		if character:GetAttribute("TuskAct") == TooruOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == TooruOutfit.Act then
					TooruOutfit.apply(character)
				end
			end)
		else
			TooruOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function TooruOutfit.init()
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

return TooruOutfit
