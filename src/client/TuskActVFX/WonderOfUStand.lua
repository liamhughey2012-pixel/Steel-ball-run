--[[
	TuskActVFX.WonderOfUStand  (StarterPlayerScripts.SpinClient.TuskActVFX.WonderOfUStand)

	WONDER OF U (Tooru, JoJolion), blocky, matched to the art: a tall old
	man in a fitted maroon suit.
	  * a bowler hat, dark maroon with a pale band and a curled brim
	  * a round ribbed head (stacked dark red rings) with little pegs
	    sticking out of each side; down the face, two long gold plates side
	    by side, and at the top of each a round pink eye in a gold sunburst
	  * a yellow knit scarf with a dotted weave, knotted at the throat, one
	    end hanging down his chest and the other thrown over his shoulder
	  * a red sunflower brooch either side of his waist (gold petals)
	  * purple hands with red nails, ribbed red bracelets, rolled cuffs
	  * a thin red cane with a crook handle in his right hand
	  * maroon trousers, brown shoes
	Registered with TuskStandModels by TooruVFX, so TuskStand floats it
	behind Tooru (players and NPCs). TooruVFX also builds spare copies to
	make it "appear" anywhere.
]]

local WonderOfUStand = {}

local SUIT = Color3.fromRGB(122, 28, 34)
local SUIT_DARK = Color3.fromRGB(84, 18, 24)
local SUIT_LIGHT = Color3.fromRGB(150, 42, 46)
local HAT = Color3.fromRGB(62, 22, 26)
local HAT_BAND = Color3.fromRGB(196, 170, 140)
local HEAD = Color3.fromRGB(130, 30, 40)
local RIB = Color3.fromRGB(170, 52, 60)
local RIB_DARK = Color3.fromRGB(70, 14, 22)
local PLATE = Color3.fromRGB(230, 186, 76)
local PLATE_SHADE = Color3.fromRGB(184, 140, 50)
local EYE = Color3.fromRGB(255, 120, 150)
local SCARF = Color3.fromRGB(222, 186, 84)
local SCARF_DOT = Color3.fromRGB(150, 110, 40)
local BROOCH = Color3.fromRGB(230, 50, 40)
local PETAL = Color3.fromRGB(236, 176, 50)
local HAND = Color3.fromRGB(128, 76, 186)
local NAIL = Color3.fromRGB(220, 40, 50)
local BRACELET = Color3.fromRGB(176, 44, 50)
local SHOE = Color3.fromRGB(96, 60, 40)
local CANE = Color3.fromRGB(196, 46, 40)

WonderOfUStand.Aura = Color3.fromRGB(170, 60, 70)
WonderOfUStand.AuraLight = Color3.fromRGB(255, 210, 150)
WonderOfUStand.Offset = CFrame.new(2.2, 1.4, 2.8)

local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)
local ALONG_Y = CFrame.Angles(0, 0, math.pi / 2)

local function newPart(model, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	p.Parent = model
	return p
end

local function box(model, parent, name, size, color, cf, material)
	local p = newPart(model, name, size, color, material)
	local w = Instance.new("Weld")
	w.Part0 = parent
	w.Part1 = p
	w.C0 = cf
	w.Parent = p
	p.CFrame = parent.CFrame * cf
	return p, w
end

local function ball(model, parent, name, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(d, d, d), color, cf, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function cyl(model, parent, name, length, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(length, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A sunflower brooch: a red centre ringed with gold petals, facing -Z.
local function brooch(model, parent, cf, s)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		box(model, parent, "Petal", Vector3.new(0.1, 0.16, 0.05) * s, PETAL, cf * CFrame.new(math.sin(a) * 0.19 * s, math.cos(a) * 0.19 * s, 0.01 * s) * CFrame.Angles(0, 0, -a))
	end
	cyl(model, parent, "Brooch", 0.07 * s, 0.28 * s, BROOCH, cf * ALONG_Z, Enum.Material.Neon)
end

-- A piece of knit scarf with a dotted weave.
local function scarfPiece(model, parent, size, cf, s)
	local p = box(model, parent, "Scarf", size, SCARF, cf)
	local long = size.Y >= size.X
	local n = math.max(1, math.floor((long and size.Y or size.X) / (0.22 * s)))
	for k = 1, n do
		local t = -0.5 + k / (n + 1)
		local off = long and CFrame.new((k % 2 == 0) and -size.X * 0.2 or size.X * 0.2, t * size.Y, -size.Z / 2 - 0.005)
			or CFrame.new(t * size.X, (k % 2 == 0) and -size.Y * 0.2 or size.Y * 0.2, -size.Z / 2 - 0.005)
		box(model, p, "ScarfDot", long and Vector3.new(size.X * 0.22, 0.045 * s, 0.02) or Vector3.new(0.045 * s, size.Y * 0.22, 0.02), SCARF_DOT, off)
	end
	return p
end

function WonderOfUStand.build(scale)
	local s = (scale or 1) * 0.9
	local model = Instance.new("Model")
	model.Name = "WonderOfU"
	local rig = { Joints = {} }

	-- A fitted jacket to the hips, the brooches at the waist.
	local torso = newPart(model, "Body", Vector3.new(1.8, 2.0, 0.95) * s, SUIT)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.48 * s
	box(model, torso, "JacketHem", Vector3.new(1.95, 0.75, 1.02) * s, SUIT, CFrame.new(0, -1.3 * s, 0))
	box(model, torso, "Waistline", Vector3.new(1.84, 0.08, 1.0) * s, SUIT_DARK, CFrame.new(0, -0.9 * s, 0))
	box(model, torso, "Placket", Vector3.new(0.06, 1.0, 0.05) * s, SUIT_DARK, CFrame.new(0.1 * s, -0.4 * s, front - 0.02 * s) * CFrame.Angles(0, 0, 0.15))
	box(model, torso, "HemSplit", Vector3.new(0.06, 0.75, 0.05) * s, SUIT_DARK, CFrame.new(0, -1.3 * s, front - 0.05 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Shoulder", Vector3.new(0.5, 0.35, 0.98) * s, SUIT_LIGHT, CFrame.new(side * 0.9 * s, 0.85 * s, 0))
		brooch(model, torso, CFrame.new(side * 0.5 * s, -0.9 * s, front - 0.08 * s), s)
	end

	-- The scarf: wrapped round the neck, knotted, one end down the chest,
	-- the other thrown back over his right shoulder.
	box(model, torso, "ScarfWrap", Vector3.new(1.05, 0.45, 1.1) * s, SCARF, CFrame.new(0, 1.15 * s, 0))
	box(model, torso, "ScarfWrap2", Vector3.new(1.15, 0.3, 1.15) * s, SCARF, CFrame.new(0.05 * s, 0.9 * s, 0) * CFrame.Angles(0, 0, 0.12))
	for k = 0, 4 do
		box(model, torso, "ScarfDot", Vector3.new(0.12, 0.04, 1.16) * s, SCARF_DOT, CFrame.new((-0.4 + k * 0.2) * s, 1.15 * s, 0))
	end
	box(model, torso, "Knot", Vector3.new(0.4, 0.38, 0.3) * s, SCARF, CFrame.new(-0.25 * s, 0.85 * s, front - 0.12 * s) * CFrame.Angles(0, 0, 0.4))
	-- One end hangs down his chest...
	scarfPiece(model, torso, Vector3.new(0.44, 1.15, 0.12) * s, CFrame.new(-0.38 * s, 0.22 * s, front - 0.12 * s) * CFrame.Angles(0, 0, 0.08), s)
	-- ...the other goes across and over his right shoulder, down his back.
	scarfPiece(model, torso, Vector3.new(1.0, 0.36, 0.12) * s, CFrame.new(0.28 * s, 0.72 * s, front - 0.14 * s) * CFrame.Angles(0, 0, 0.22), s)
	scarfPiece(model, torso, Vector3.new(0.38, 0.12, 1.05) * s, CFrame.new(0.78 * s, 1.03 * s, 0), s)
	scarfPiece(model, torso, Vector3.new(0.38, 0.95, 0.12) * s, CFrame.new(0.78 * s, 0.55 * s, 0.55 * s), s)

	-- Head: a round ribbed head, pegs at the sides, two gold plates down
	-- the face with a pink sunburst eye at the top of each.
	local headBase = CFrame.new(0, 1.4 * s, 0)
	local headOffset = CFrame.new(0, 0.6 * s, 0)
	local head, headWeld = cyl(model, torso, "Head", 1.15 * s, 0.85 * s, HEAD, headBase * headOffset * ALONG_Y), nil
	head.Shape = Enum.PartType.Cylinder
	headWeld = head:FindFirstChildOfClass("Weld")
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset * ALONG_Y }
	local UP = ALONG_Y:Inverse() -- the head part is turned; this turns its children back upright
	for k = 0, 5 do
		cyl(model, head, "Rib", 0.08 * s, (k % 2 == 0 and 0.95 or 0.9) * s, k % 2 == 0 and RIB or RIB_DARK, UP * CFrame.new(0, (-0.45 + k * 0.17) * s, 0) * ALONG_Y)
	end
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			cyl(model, head, "Peg", 0.28 * s, 0.1 * s, RIB, UP * CFrame.new(side * 0.52 * s, (0.25 - k * 0.22) * s, 0.05 * s))
		end
		-- A long gold plate down the face, rounded at the bottom.
		local px = side * 0.17 * s
		box(model, head, "Plate", Vector3.new(0.3, 1.2, 0.12) * s, PLATE, UP * CFrame.new(px, -0.08 * s, -0.52 * s))
		ball(model, head, "PlateEnd", 0.3 * s, PLATE, UP * CFrame.new(px, -0.68 * s, -0.52 * s))
		box(model, head, "PlateEdge", Vector3.new(0.05, 1.2, 0.13) * s, PLATE_SHADE, UP * CFrame.new(px + side * 0.13 * s, -0.08 * s, -0.52 * s))
		-- The eye: a round pink lens in a gold sunburst.
		local eye = UP * CFrame.new(side * 0.2 * s, 0.32 * s, -0.6 * s)
		for r = 0, 7 do
			local a = r / 8 * math.pi * 2
			box(model, head, "EyeRay", Vector3.new(0.06, 0.1, 0.05) * s, PLATE, eye * CFrame.new(math.sin(a) * 0.17 * s, math.cos(a) * 0.17 * s, 0) * CFrame.Angles(0, 0, -a))
		end
		cyl(model, head, "EyeRim", 0.06 * s, 0.3 * s, PLATE_SHADE, eye * ALONG_Z)
		cyl(model, head, "Eye", 0.08 * s, 0.22 * s, EYE, eye * CFrame.new(0, 0, -0.02 * s) * ALONG_Z, Enum.Material.Neon)
	end
	-- The bowler: a round crown, a pale band, a curled brim.
	ball(model, head, "HatCrown", 0.98 * s, HAT, UP * CFrame.new(0, 0.72 * s, 0))
	box(model, head, "HatCrownBase", Vector3.new(0.92, 0.32, 0.92) * s, HAT, UP * CFrame.new(0, 0.66 * s, 0))
	box(model, head, "HatBand", Vector3.new(0.95, 0.12, 0.95) * s, HAT_BAND, UP * CFrame.new(0, 0.58 * s, 0))
	cyl(model, head, "HatBrim", 0.07 * s, 1.5 * s, HAT, UP * CFrame.new(0, 0.5 * s, 0) * ALONG_Y)
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "BrimCurl", Vector3.new(0.12, 0.12, 0.9) * s, HAT, UP * CFrame.new(side * 0.7 * s, 0.56 * s, 0))
	end

	-- Arms: long sleeves with rolled cuffs, ribbed bracelets, purple hands
	-- with red nails. The right hand holds the cane.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.15 * s, 0.75 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.52, 2.2, 0.52) * s, SUIT, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Cuff", Vector3.new(0.62, 0.28, 0.62) * s, SUIT_LIGHT, CFrame.new(0, -0.9 * s, 0))
		for k = 0, 2 do
			cyl(model, arm, "Bracelet", 0.07 * s, 0.56 * s, BRACELET, CFrame.new(0, (-1.08 - k * 0.09) * s, 0) * ALONG_Y)
		end
		local hand = box(model, arm, "Hand", Vector3.new(0.46, 0.42, 0.44) * s, HAND, CFrame.new(0, -1.35 * s, 0))
		for f = -1.5, 1.5 do
			local finger = box(model, hand, "Finger", Vector3.new(0.09, 0.4, 0.1) * s, HAND, CFrame.new(f * 0.11 * s, -0.38 * s, -0.04 * s))
			box(model, finger, "Nail", Vector3.new(0.09, 0.08, 0.04) * s, NAIL, CFrame.new(0, -0.16 * s, -0.05 * s))
		end
		if a[1] == "ArmR" then
			-- The cane: thin and red, point to the ground, a crook handle on top.
			cyl(model, hand, "Cane", 3.4 * s, 0.11 * s, CANE, CFrame.new(0, -1.55 * s, -0.25 * s) * ALONG_Y)
			cyl(model, hand, "CaneCrook", 0.45 * s, 0.11 * s, CANE, CFrame.new(0.0, 0.14 * s, -0.47 * s) * CFrame.Angles(0, math.pi / 2, 0))
			cyl(model, hand, "CaneCrookTip", 0.25 * s, 0.11 * s, CANE, CFrame.new(0, 0.03 * s, -0.68 * s) * ALONG_Y)
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: maroon trousers, brown shoes.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.42 * s, -1.6 * s, 0)
		local offset = CFrame.new(0, -1.25 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.62, 2.5, 0.62) * s, SUIT, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Crease", Vector3.new(0.05, 2.4, 0.05) * s, SUIT_DARK, CFrame.new(0, 0, -0.32 * s))
		box(model, leg, "Shoe", Vector3.new(0.64, 0.3, 0.98) * s, SHOE, CFrame.new(0, -1.3 * s, -0.17 * s))
	end
	return model, rig
end

return WonderOfUStand
