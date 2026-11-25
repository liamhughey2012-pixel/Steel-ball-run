--[[
	RingoOutfit  (ServerScriptService.SpinServer.RingoOutfit)

	Gives a character the look of Ringo Roadagain while they play him
	(TuskAct 19), built from blocky parts (no catalog asset ids), matched
	to his art (2026-11-25):
	  * silver-grey hair swept up and back, a moustache and chin beard
	  * an all-WHITE outfit: a shirt with a huge, high, pointed collar,
	    open in a deep V right down to his belt; short cap sleeves (bare,
	    tanned arms)
	  * purple-grey fingerless gloves; a gold bracelet on his right wrist
	  * a mustard-yellow gun belt with a PINK RING buckle and brass studs,
	    a tan holster on his right hip, and a brown flap hanging down
	    behind his hips
	  * white trousers that flare out at the ankle with a row of gold studs
	    round each hem; brown heeled boots
	  * Mandom's pink tubes plugged in all over his right arm, shoulder and
	    chest (and a couple in his left forearm), gold clamps where they
	    go in; Mandom's yellow WATCH HAND across his chest with "60" / "5"
	Mandom itself (MandomStand) rides on his right shoulder.
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local RingoOutfit = {}
RingoOutfit.Act = 19

local C = {
	Hair = Color3.fromRGB(204, 206, 214),
	HairShade = Color3.fromRGB(150, 154, 166),
	White = Color3.fromRGB(240, 240, 244),
	Shade = Color3.fromRGB(196, 200, 212),
	Fold = Color3.fromRGB(170, 176, 190),
	Mark = Color3.fromRGB(226, 120, 50),
	Hand = Color3.fromRGB(246, 204, 40),
	Tube = Color3.fromRGB(128, 28, 52),
	TubeLight = Color3.fromRGB(162, 50, 76),
	Ring = Color3.fromRGB(226, 182, 76),
	Glove = Color3.fromRGB(122, 106, 128),
	Gold = Color3.fromRGB(230, 186, 70),
	Belt = Color3.fromRGB(206, 162, 62),
	BeltDark = Color3.fromRGB(150, 110, 36),
	Stud = Color3.fromRGB(176, 140, 60),
	PinkRing = Color3.fromRGB(228, 128, 156),
	Holster = Color3.fromRGB(214, 170, 80),
	Grip = Color3.fromRGB(80, 56, 40),
	Flap = Color3.fromRGB(136, 84, 46),
	Boot = Color3.fromRGB(118, 70, 38),
	Heel = Color3.fromRGB(70, 44, 26),
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

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Grey hair swept up and back: a cap, a tall quiff leaning back, sides.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.08 * s, 0.3 * s, head.Size.Z + 0.1 * s), C.Hair, CFrame.new(0, h - 0.1 * s, 0.02 * s))
	piece(head, outfit, "Quiff", Vector3.new(head.Size.X * 0.9, 0.4 * s, head.Size.Z * 0.85), C.Hair, CFrame.new(0, h + 0.15 * s, 0.12 * s) * CFrame.Angles(math.rad(14), 0, 0))
	piece(head, outfit, "QuiffBack", Vector3.new(head.Size.X * 0.8, 0.3 * s, 0.4 * s), C.HairShade, CFrame.new(0, h + 0.1 * s, d + 0.08 * s) * CFrame.Angles(math.rad(30), 0, 0))
	piece(head, outfit, "QuiffFront", Vector3.new(head.Size.X * 0.7, 0.12 * s, 0.14 * s), C.HairShade, CFrame.new(0.1 * s, h + 0.28 * s, -d + 0.12 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HairSide", Vector3.new(0.1 * s, 0.5 * s, head.Size.Z * 0.7), C.Hair, CFrame.new(side * (w + 0.03 * s), h - 0.35 * s, 0.1 * s))
	end
	-- Moustache and chin beard.
	piece(head, outfit, "Moustache", Vector3.new(0.42 * s, 0.08 * s, 0.05 * s), C.Hair, CFrame.new(0, -0.22 * s, -d - 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "MoustacheEnd", Vector3.new(0.06 * s, 0.22 * s, 0.05 * s), C.Hair, CFrame.new(side * 0.2 * s, -0.33 * s, -d - 0.02 * s))
	end
	piece(head, outfit, "Beard", Vector3.new(0.14 * s, 0.24 * s, 0.06 * s), C.Hair, CFrame.new(0, -h + 0.04 * s, -d - 0.02 * s))
end

-- A Mandom tube plugged in at `into` (coming from `from`), with a gold clamp.
local function tube(parent, outfit, from, into, out)
	cyl(parent, outfit, "Tube", from, into, 0.2, C.Tube)
	cyl(parent, outfit, "TubeShine", from + Vector3.new(0, 0.05, 0), into + Vector3.new(0, 0.05, 0), 0.07, C.TubeLight)
	local dir = (into - from).Unit
	local clamp = piece(parent, outfit, "Clamp", Vector3.new(0.1, 0.3, 0.3), C.Ring, CFrame.lookAt(into, into + dir) * CFrame.Angles(0, math.pi / 2, 0))
	clamp.Shape = Enum.PartType.Cylinder
	clamp.Material = Enum.Material.Metal
	-- Three gold claws gripping the skin round where it goes in.
	local o = out or Vector3.new(0, 0, -1)
	local side = dir:Cross(o)
	side = side.Magnitude > 1e-3 and side.Unit or Vector3.new(1, 0, 0)
	local up = side:Cross(dir).Unit
	for k = 0, 2 do
		local ang = k / 3 * math.pi * 2
		local spoke = side * math.cos(ang) + up * math.sin(ang)
		local base = into + spoke * 0.13
		local tip = into + spoke * 0.3 + dir * 0.06
		local claw = piece(parent, outfit, "Claw", Vector3.new(0.06, 0.06, (tip - base).Magnitude + 0.04), C.Ring, CFrame.lookAt((base + tip) / 2, tip))
		claw.Material = Enum.Material.Metal
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	local head = character:FindFirstChild("Head")
	local skin = head and head.Color or Color3.fromRGB(206, 146, 100)
	if upper then
		local s = upper.Size
		local top, front, back = s.Y / 2, -s.Z / 2, s.Z / 2
		piece(upper, outfit, "Shirt", s + Vector3.new(0.1, 0.02, 0.1), C.White, CFrame.new())
		-- Open in a deep V right down to the belt: skin, narrowing as it goes.
		local rows = 6
		for k = 0, rows - 1 do
			local w = 0.95 - k * 0.15
			local h = s.Y / rows
			piece(upper, outfit, "Chest", Vector3.new(w, h + 0.01, 0.04), skin, CFrame.new(0, top - (k + 0.5) * h, front - 0.06))
		end
		-- The V's edges: folded white lapels with a grey shadow.
		for _, side in ipairs({ -1, 1 }) do
			local a = Vector3.new(side * 0.5, top - 0.02, front - 0.08)
			local b = Vector3.new(side * 0.06, -top + 0.05, front - 0.08)
			local mid = (a + b) / 2
			local len = (b - a).Magnitude
			piece(upper, outfit, "Lapel", Vector3.new(0.16, len, 0.05), C.White, CFrame.lookAt(mid, mid + Vector3.new(0, 0, -1), (a - b).Unit) * CFrame.new(side * 0.06, 0, 0))
			piece(upper, outfit, "LapelShade", Vector3.new(0.04, len, 0.055), C.Fold, CFrame.lookAt(mid, mid + Vector3.new(0, 0, -1), (a - b).Unit) * CFrame.new(side * 0.15, 0, 0))
			-- Fabric folds down the side of the shirt.
			piece(upper, outfit, "Fold", Vector3.new(0.05, s.Y * 0.7, 0.03), C.Shade, CFrame.new(side * s.X * 0.38, -0.1, front - 0.06) * CFrame.Angles(0, 0, side * 0.15))
		end
		-- The huge collar: tall, standing up round his neck and flaring out
		-- to points.
		piece(upper, outfit, "CollarBack", Vector3.new(s.X * 0.8, 1.15, 0.2), C.White, CFrame.new(0, top + 0.5, back - 0.05) * CFrame.Angles(math.rad(-14), 0, 0))
		piece(upper, outfit, "CollarBackIn", Vector3.new(s.X * 0.7, 1.0, 0.05), C.Shade, CFrame.new(0, top + 0.46, back - 0.2) * CFrame.Angles(math.rad(-14), 0, 0))
		for _, side in ipairs({ -1, 1 }) do
			-- Each half: a wide panel standing up beside his neck, turned to
			-- face forward-and-out, leaning out over the shoulder, with a
			-- pointed tip at its top outer corner.
			local wing = CFrame.new(side * 0.86, top + 0.42, -0.1) * CFrame.Angles(0, side * -0.35, side * -0.3)
			piece(upper, outfit, "CollarWing", Vector3.new(0.7, 1.05, 0.1), C.White, wing)
			piece(upper, outfit, "CollarWingIn", Vector3.new(0.7, 0.85, 0.04), C.Shade, wing * CFrame.new(-side * 0.02, -0.02, 0.07))
			piece(upper, outfit, "CollarEdge", Vector3.new(0.05, 0.95, 0.11), C.Fold, wing * CFrame.new(-side * 0.4, 0, 0))
			piece(upper, outfit, "CollarTip", Vector3.new(0.42, 0.42, 0.1), C.White, wing * CFrame.new(side * 0.26, 0.45, 0) * CFrame.Angles(0, 0, math.rad(45)))
		end
		-- "60" and "5" and Mandom's watch hand.
		piece(upper, outfit, "Mark60", Vector3.new(0.24, 0.15, 0.04), C.Mark, CFrame.new(0.42, 0.12, front - 0.07))
		piece(upper, outfit, "Mark5", Vector3.new(0.11, 0.15, 0.04), C.Mark, CFrame.new(-0.62, 0.3, front - 0.07))
		local a = Vector3.new(-0.55, top - 0.12, front - 0.11)
		local b = Vector3.new(0.35, -top + 0.08, front - 0.11)
		local mid = (a + b) / 2
		piece(upper, outfit, "WatchHand", Vector3.new(0.07, (b - a).Magnitude, 0.05), C.Hand, CFrame.lookAt(mid, mid + Vector3.new(0, 0, -1), (a - b).Unit))
		piece(upper, outfit, "HandTip", Vector3.new(0.2, 0.2, 0.05), C.Hand, CFrame.new(a) * CFrame.Angles(0, 0, math.pi / 4))
		local ring = piece(upper, outfit, "HandRing", Vector3.new(0.05, 0.24, 0.24), C.Hand, CFrame.new(b) * CFrame.Angles(0, math.pi / 2, 0))
		ring.Shape = Enum.PartType.Cylinder
		piece(upper, outfit, "Mark", Vector3.new(0.12, 0.12, 0.05), C.Hand, CFrame.new(0.05, top - 0.22, front - 0.11) * CFrame.Angles(0, 0, math.pi / 4))
		piece(upper, outfit, "Mark", Vector3.new(0.11, 0.11, 0.05), C.Hand, CFrame.new(-0.72, 0.5, front - 0.11) * CFrame.Angles(0, 0, math.pi / 4))
		-- Tubes into his right chest, right shoulder and upper back.
		for k, y in ipairs({ 0.45, 0.05, -0.35 }) do
			tube(upper, outfit, Vector3.new(s.X / 2 - 0.1 + k * 0.05, top + 0.18, front - 0.05), Vector3.new(0.62 - k * 0.07, y, front - 0.06))
		end
		tube(upper, outfit, Vector3.new(s.X / 2 + 0.2, top + 0.6, 0.2), Vector3.new(s.X / 2 - 0.15, top + 0.02, -0.1), Vector3.new(0, 1, 0))
		tube(upper, outfit, Vector3.new(s.X / 2 + 0.4, top + 0.3, back + 0.3), Vector3.new(0.5, 0.3, back + 0.04), Vector3.new(0, 0, 1))
		tube(upper, outfit, Vector3.new(s.X / 2 + 0.3, 0.2, back + 0.5), Vector3.new(0.3, -0.2, back + 0.04), Vector3.new(0, 0, 1))
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.White, CFrame.new())
		-- The mustard gun belt: brass studs, a pink ring buckle.
		local by = ls.Y / 2 - 0.08
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.18, 0.3, ls.Z + 0.18), C.Belt, CFrame.new(0, by, 0))
		for _, dy in ipairs({ -0.14, 0.14 }) do
			piece(lower, outfit, "BeltStitch", Vector3.new(ls.X + 0.2, 0.03, ls.Z + 0.2), C.BeltDark, CFrame.new(0, by + dy, 0))
		end
		for k = -3, 3 do
			if k ~= 0 then
				local stud = piece(lower, outfit, "BeltStud", Vector3.new(0.08, 0.08, 0.08), C.Stud, CFrame.new(k * 0.26, by, -ls.Z / 2 - 0.11))
				stud.Shape = Enum.PartType.Ball
			end
		end
		local buckle = piece(lower, outfit, "Buckle", Vector3.new(0.05, 0.36, 0.36), C.PinkRing, CFrame.new(0.1, by, -ls.Z / 2 - 0.12) * CFrame.Angles(0, math.pi / 2, 0))
		buckle.Shape = Enum.PartType.Cylinder
		local hole = piece(lower, outfit, "BuckleHole", Vector3.new(0.06, 0.22, 0.22), C.Belt, CFrame.new(0.1, by, -ls.Z / 2 - 0.125) * CFrame.Angles(0, math.pi / 2, 0))
		hole.Shape = Enum.PartType.Cylinder
		-- The holster on his right hip, the revolver's grip poking out.
		piece(lower, outfit, "Holster", Vector3.new(0.26, 0.85, 0.5), C.Holster, CFrame.new(ls.X / 2 + 0.18, -0.25, -0.05) * CFrame.Angles(0, 0, 0.1))
		piece(lower, outfit, "HolsterFlap", Vector3.new(0.28, 0.22, 0.52), C.BeltDark, CFrame.new(ls.X / 2 + 0.16, 0.12, -0.05) * CFrame.Angles(0, 0, 0.1))
		piece(lower, outfit, "Grip", Vector3.new(0.14, 0.34, 0.18), C.Grip, CFrame.new(ls.X / 2 + 0.2, 0.35, 0.05) * CFrame.Angles(0, 0, -0.35))
		-- A brown flap hanging down behind his hips.
		piece(lower, outfit, "Flap", Vector3.new(ls.X + 0.1, 1.7, 0.1), C.Flap, CFrame.new(0, -0.85, ls.Z / 2 + 0.12) * CFrame.Angles(math.rad(6), 0, 0))
		for _, side in ipairs({ -1, 1 }) do
			piece(lower, outfit, "FlapSide", Vector3.new(0.1, 1.4, ls.Z * 0.6), C.Flap, CFrame.new(side * (ls.X / 2 + 0.1), -0.7, ls.Z * 0.2))
		end
	end
	-- Cap sleeves; bare arms below them.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Skin", arm.Size + Vector3.new(0.04, 0, 0.04), skin, CFrame.new())
			if name:find("Upper") then
				local as = arm.Size
				local h = as.Y * 0.42
				piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.16, h, as.Z + 0.16), C.White, CFrame.new(0, as.Y / 2 - h / 2 + 0.02, 0))
				piece(arm, outfit, "SleeveHem", Vector3.new(as.X + 0.2, 0.08, as.Z + 0.2), C.Shade, CFrame.new(0, as.Y / 2 - h + 0.04, 0))
			end
		end
	end
	-- Fingerless gloves.
	for _, name in ipairs({ "LeftHand", "RightHand" }) do
		local hand = character:FindFirstChild(name)
		if hand then
			local hs = hand.Size
			piece(hand, outfit, "Glove", Vector3.new(hs.X + 0.1, hs.Y * 0.7, hs.Z + 0.1), C.Glove, CFrame.new(0, hs.Y * 0.15, 0))
			piece(hand, outfit, "Fingers", Vector3.new(hs.X + 0.02, hs.Y * 0.32, hs.Z + 0.02), skin, CFrame.new(0, -hs.Y * 0.35, 0))
			piece(hand, outfit, "Cuff", Vector3.new(hs.X + 0.2, 0.14, hs.Z + 0.2), C.Glove, CFrame.new(0, hs.Y / 2 + 0.02, 0))
		end
	end
	local rightLower = character:FindFirstChild("RightLowerArm") or character:FindFirstChild("Right Arm")
	if rightLower then
		local as = rightLower.Size
		piece(rightLower, outfit, "Bracelet", Vector3.new(as.X + 0.14, 0.14, as.Z + 0.14), C.Gold, CFrame.new(0, -as.Y / 2 + 0.12, 0))
		for k, y in ipairs({ 0.3, -0.05 }) do
			tube(rightLower, outfit, Vector3.new(as.X / 2 + 0.16, as.Y / 2 + 0.25, 0.2 - k * 0.25), Vector3.new(as.X / 2 + 0.02, y, -0.1 * k), Vector3.new(1, 0, 0))
		end
	end
	-- Tubes all over his right upper arm.
	local rightUpper = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("Right Arm")
	if rightUpper then
		local as = rightUpper.Size
		for k, y in ipairs({ 0.3, 0.0, -0.3 }) do
			tube(rightUpper, outfit, Vector3.new(as.X / 2 + 0.18, as.Y / 2 + 0.35, 0.3 - k * 0.2), Vector3.new(as.X / 2 + 0.02, y, -0.15 + k * 0.1), Vector3.new(1, 0, 0))
		end
		tube(rightUpper, outfit, Vector3.new(0.25, as.Y / 2 + 0.3, -as.Z / 2 - 0.15), Vector3.new(0.05, -0.1, -as.Z / 2 - 0.02), Vector3.new(0, 0, -1))
	end
	-- And a couple in his left forearm.
	local leftLower = character:FindFirstChild("LeftLowerArm") or character:FindFirstChild("Left Arm")
	if leftLower then
		local as = leftLower.Size
		for k, y in ipairs({ 0.25, -0.1 }) do
			tube(leftLower, outfit, Vector3.new(0.25 * k - 0.1, y + 0.55, -as.Z / 2 - 0.18), Vector3.new(0.05 * k, y, -as.Z / 2 - 0.02), Vector3.new(0, 0, -1))
		end
	end
	-- White trousers flaring at the ankle, gold studs round the hem.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.White, CFrame.new())
			if name:find("Lower") or name == "Left Leg" or name == "Right Leg" then
				local fh = ls.Y * 0.4
				local flare = piece(leg, outfit, "Flare", Vector3.new(ls.X + 0.34, fh, ls.Z + 0.34), C.White, CFrame.new(0, -ls.Y / 2 + fh / 2 - 0.05, 0))
				flare.Name = "Flare"
				piece(leg, outfit, "FlareFold", Vector3.new(0.05, fh * 0.9, 0.05), C.Fold, CFrame.new(0, -ls.Y / 2 + fh / 2 - 0.05, -ls.Z / 2 - 0.18))
				local hy = -ls.Y / 2 + 0.02
				for i = 0, 7 do
					local ang = i / 8 * math.pi * 2
					local stud = piece(leg, outfit, "HemStud", Vector3.new(0.13, 0.13, 0.13), C.Gold, CFrame.new(math.sin(ang) * (ls.X / 2 + 0.2), hy, math.cos(ang) * (ls.Z / 2 + 0.2)))
					stud.Shape = Enum.PartType.Ball
				end
			end
		end
	end
	-- Brown heeled boots.
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			local fs = foot.Size
			piece(foot, outfit, "Boot", fs + Vector3.new(0.08, 0.04, 0.16), C.Boot, CFrame.new(0, 0, -0.04))
			piece(foot, outfit, "Heel", Vector3.new(fs.X * 0.7, 0.18, 0.3), C.Heel, CFrame.new(0, -fs.Y / 2 - 0.06, fs.Z / 2 - 0.12))
			piece(foot, outfit, "Toe", Vector3.new(fs.X * 0.9, fs.Y * 0.8, 0.12), C.Heel, CFrame.new(0, -0.02, -fs.Z / 2 - 0.1))
		end
	end
end

function RingoOutfit.apply(character)
	if character:FindFirstChild("RingoOutfit") then
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
	outfit.Name = "RingoOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function RingoOutfit.remove(character)
	local outfit = character:FindFirstChild("RingoOutfit")
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
		if character:GetAttribute("TuskAct") == RingoOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == RingoOutfit.Act then
					RingoOutfit.apply(character)
				end
			end)
		else
			RingoOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function RingoOutfit.init()
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

return RingoOutfit
