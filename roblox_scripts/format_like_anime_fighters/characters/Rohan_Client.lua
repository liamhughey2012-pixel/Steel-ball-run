--[[
	Rohan_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Rohan Kishibe (Part 4): Heaven's Door.
	Its other half is Rohan_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "rohan" or __expect.Side ~= "client") then
		error("this is the code for Rohan_Client, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Rohan_Client and put it in ReplicatedStorage > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: HeavensDoorStand
-- ======================================================================
__modules["HeavensDoorStand"] = function()
--[[
	TuskActVFX.HeavensDoorStand  (StarterPlayerScripts.SpinClient.TuskActVFX.HeavensDoorStand)

	HEAVEN'S DOOR (Rohan Kishibe, Part 4), blocky, matched to the art: a
	small, boyish figure, all white and gold:
	  * a pale, smooth face with big GREEN eyes and thin gold lines framing
	    it like a mask
	  * a white HAT with a wide, gold-edged brim and a tall open crown made
	    of a GOLD LATTICE (a grid of gold bars)
	  * a long, loose WHITE COAT with gold trim down the edges and round the
	    hem, and big GOLD CUFFS on its wide sleeves
	  * white hands; green-and-orange shoes
	Small: it floats at Rohan's shoulder. Registered with TuskStandModels by
	RohanVFX, so TuskStand floats it with a soft gold aura.
]]

local HeavensDoorStand = {}

local WHITE = Color3.fromRGB(240, 240, 244)
local WHITE_SHADE = Color3.fromRGB(206, 206, 216)
local FACE = Color3.fromRGB(232, 236, 230)
local GOLD = Color3.fromRGB(240, 196, 60)
local GOLD_DARK = Color3.fromRGB(196, 150, 40)
local EYE = Color3.fromRGB(110, 210, 120)
local PUPIL = Color3.fromRGB(30, 60, 36)
local SHOE = Color3.fromRGB(90, 170, 70)
local SHOE_TOE = Color3.fromRGB(230, 130, 40)

HeavensDoorStand.Aura = Color3.fromRGB(250, 220, 120)
HeavensDoorStand.AuraLight = Color3.fromRGB(255, 248, 220)
HeavensDoorStand.Offset = CFrame.new(1.9, 1.4, 1.4)

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

-- A tube from a to b (in parent space).
local function tube(model, parent, a, b, d, color)
	local len = (b - a).Magnitude
	local p = box(model, parent, "Tube", Vector3.new(len + d * 0.4, d, d), color, CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function egg(model, parent, name, size, color, cf, material)
	local p, w = box(model, parent, name, size, color, cf, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p, w
end

local function egg(model, parent, name, size, color, cf, material)
	local p, w = box(model, parent, name, size, color, cf, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p, w
end

local function cyl(model, parent, name, length, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(length, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function HeavensDoorStand.build(scale)
	local s = (scale or 1) * 0.62
	local model = Instance.new("Model")
	model.Name = "HeavensDoor"
	local rig = { Joints = {} }

	-- A slim body in a long, loose white coat with gold trim.
	local torso = newPart(model, "Body", Vector3.new(1.5, 1.7, 0.95) * s, WHITE)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.48 * s
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "Lapel", Vector3.new(0.3, 1.5, 0.08) * s, WHITE_SHADE, CFrame.new(side * 0.2 * s, 0.05 * s, front - 0.02 * s) * CFrame.Angles(0, 0, side * 0.12))
		box(model, torso, "Trim", Vector3.new(0.06, 1.7, 0.09) * s, GOLD, CFrame.new(side * 0.06 * s, 0, front - 0.04 * s), Enum.Material.Metal)
	end
	box(model, torso, "Collar", Vector3.new(1.0, 0.3, 0.8) * s, WHITE, CFrame.new(0, 0.9 * s, 0.05 * s))
	box(model, torso, "CollarTrim", Vector3.new(1.02, 0.05, 0.82) * s, GOLD, CFrame.new(0, 1.05 * s, 0.05 * s), Enum.Material.Metal)
	-- The coat's long skirt, flaring out, gold round the hem.
	box(model, torso, "CoatSkirt", Vector3.new(1.75, 1.6, 1.15) * s, WHITE, CFrame.new(0, -1.55 * s, 0.04 * s))
	box(model, torso, "SkirtFold", Vector3.new(0.05, 1.5, 1.17) * s, WHITE_SHADE, CFrame.new(0.4 * s, -1.55 * s, 0.04 * s))
	box(model, torso, "Hem", Vector3.new(1.79, 0.1, 1.19) * s, GOLD, CFrame.new(0, -2.32 * s, 0.04 * s), Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		box(model, torso, "SkirtTrim", Vector3.new(0.06, 1.6, 0.06) * s, GOLD, CFrame.new(side * 0.06 * s, -1.55 * s, -0.55 * s), Enum.Material.Metal)
	end
	box(model, torso, "Neck", Vector3.new(0.4, 0.3, 0.4) * s, FACE, CFrame.new(0, 0.98 * s, 0))

	-- The head: a pale face, big green eyes, thin gold lines framing it.
	local headBase = CFrame.new(0, 1.1 * s, 0)
	local headOffset = CFrame.new(0, 0.55 * s, 0)
	local head, headWeld = egg(model, torso, "Head", Vector3.new(0.95, 1.1, 0.95) * s, FACE, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.45 * s
	for _, side in ipairs({ -1, 1 }) do
		egg(model, head, "Eye", Vector3.new(0.24, 0.24, 0.06) * s, EYE, CFrame.new(side * 0.2 * s, 0.02 * s, hf + 0.02 * s), Enum.Material.Neon)
		egg(model, head, "Pupil", Vector3.new(0.1, 0.12, 0.04) * s, PUPIL, CFrame.new(side * 0.2 * s, 0.02 * s, hf - 0.01 * s))
		-- Gold lines framing the face like a mask.
		box(model, head, "FaceLine", Vector3.new(0.04, 0.7, 0.04) * s, GOLD, CFrame.new(side * 0.38 * s, -0.05 * s, hf + 0.12 * s) * CFrame.Angles(0, side * 0.5, side * -0.15), Enum.Material.Metal)
		box(model, head, "EyeLine", Vector3.new(0.3, 0.035, 0.04) * s, GOLD, CFrame.new(side * 0.2 * s, 0.18 * s, hf + 0.03 * s) * CFrame.Angles(0, 0, side * 0.12), Enum.Material.Metal)
	end
	box(model, head, "ChinLine", Vector3.new(0.4, 0.035, 0.04) * s, GOLD, CFrame.new(0, -0.42 * s, hf + 0.15 * s), Enum.Material.Metal)
	box(model, head, "Mouth", Vector3.new(0.14, 0.03, 0.03) * s, WHITE_SHADE, CFrame.new(0, -0.26 * s, hf + 0.03 * s))

	-- The hat: a wide white brim edged in gold, a tall crown of gold lattice.
	local hat = CFrame.new(0, 0.48 * s, 0.03 * s) * CFrame.Angles(math.rad(-10), 0, math.rad(-12))
	cyl(model, head, "Brim", 0.08 * s, 1.75 * s, WHITE, hat * CFrame.Angles(0, 0, math.pi / 2))
	local n = 20
	for k = 0, n - 1 do
		local a0 = k / n * math.pi * 2
		box(model, head, "BrimEdge", Vector3.new(0.1, 0.1, 0.3) * s, GOLD, hat * CFrame.new(math.cos(a0) * 0.86 * s, 0.02 * s, math.sin(a0) * 0.86 * s) * CFrame.Angles(0, -a0, 0), Enum.Material.Metal)
	end
	cyl(model, head, "CrownBase", 0.12 * s, 1.0 * s, WHITE, hat * CFrame.new(0, 0.06 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
	-- Upright bars round the crown...
	for k = 0, 11 do
		local a0 = k / 12 * math.pi * 2
		box(model, head, "LatticeBar", Vector3.new(0.05, 0.75, 0.05) * s, GOLD, hat * CFrame.new(math.cos(a0) * 0.46 * s, 0.45 * s, math.sin(a0) * 0.46 * s), Enum.Material.Metal)
	end
	-- ...and rings across them.
	for r = 0, 3 do
		local y = (0.12 + r * 0.24) * s
		for k = 0, 11 do
			local a0 = (k + 0.5) / 12 * math.pi * 2
			box(model, head, "LatticeRing", Vector3.new(0.05, 0.05, 0.25) * s, r == 3 and GOLD_DARK or GOLD, hat * CFrame.new(math.cos(a0) * 0.46 * s, y, math.sin(a0) * 0.46 * s) * CFrame.Angles(0, -a0, 0), Enum.Material.Metal)
		end
	end

	-- Wide white sleeves with big gold cuffs; white hands.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 0.95 * s, 0.5 * s, 0)
		local offset = CFrame.new(0, -0.8 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.48, 1.6, 0.48) * s, WHITE, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Cuff", Vector3.new(0.66, 0.42, 0.66) * s, GOLD, CFrame.new(0, -0.6 * s, 0), Enum.Material.Metal)
		box(model, arm, "CuffRim", Vector3.new(0.68, 0.06, 0.68) * s, GOLD_DARK, CFrame.new(0, -0.4 * s, 0), Enum.Material.Metal)
		local hand = box(model, arm, "Hand", Vector3.new(0.34, 0.38, 0.22) * s, WHITE, CFrame.new(0, -0.98 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.06, 0.22, 0.07) * s, WHITE_SHADE, CFrame.new(f * 0.08 * s, -0.27 * s, 0))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.2 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs under the coat: green-and-orange shoes peeking out.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.35 * s, -1.6 * s, 0)
		local offset = CFrame.new(0, -0.8 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.36, 1.6, 0.36) * s, WHITE_SHADE, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Shoe", Vector3.new(0.42, 0.3, 0.6) * s, SHOE, CFrame.new(0, -0.72 * s, -0.1 * s))
		box(model, leg, "ShoeToe", Vector3.new(0.4, 0.26, 0.2) * s, SHOE_TOE, CFrame.new(0, -0.74 * s, -0.42 * s))
		box(model, leg, "ShoeBand", Vector3.new(0.44, 0.08, 0.62) * s, GOLD, CFrame.new(0, -0.58 * s, -0.1 * s), Enum.Material.Metal)
	end
	return model, rig
end

return HeavensDoorStand
end

-- ======================================================================
-- MODULE: RohanVFX
-- ======================================================================
__modules["RohanVFX"] = function()
--[[
	TuskActVFX.RohanVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.RohanVFX)

	Client visuals for Rohan Kishibe / HEAVEN'S DOOR. Blocky.
	  * Heaven's Door (HeavensDoorStand), small, floats at his shoulder;
	    Rohan poses with his pen raised by his face
	  * PEN & PAGE COMBO: swipes with ink drops flicking off the pen
	  * HEAVEN'S DOOR: "HEAVEN'S DOOR!"; the target's face peels open into a
	    BOOK: pages fan out in front of their face and flutter while they're
	    stuck; then a little open book floats over their head while he can
	    write in them
	  * WRITE: his pen scribbles; the command appears over them in ink on a
	    strip of paper ("YOU CAN'T ATTACK KISHIBE ROHAN" / "FLY BACKWARDS AT
	    70 KM/H"); flying backwards leaves speed lines; trying to hit him
	    with the command written in them just stops them ("...!?")
	  * EVERYONE IS A BOOK: a burst of pages from him; everyone near opens
	    like a book at once, the command written over each of them
]]

local Players = game:GetService("Players")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local TuskStandModels = __require("TuskStandModels")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Common = __require("TuskActCommon")
local Fighters = __require("Fighters")
local TuskStand = __require("TuskStand")
local HeavensDoorStand = __require("HeavensDoorStand")

local RohanVFX = {}
local ACT = 28
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, HeavensDoorStand.build, { Aura = HeavensDoorStand.Aura, AuraLight = HeavensDoorStand.AuraLight, Offset = HeavensDoorStand.Offset })

local INK = Color3.fromRGB(24, 22, 30)
local PAGE = Color3.fromRGB(250, 246, 232)
local PAGE_SHADE = Color3.fromRGB(226, 216, 190)
local GREEN = Color3.fromRGB(130, 220, 140)

local stanced = {}
local books = {} -- [target] = { Parts, Badge }

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function label(adornee, text, color, duration, size, offset, font)
	if not adornee then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size or 240, (size or 240) / 5)
	bb.StudsOffset = offset or Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = adornee
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = font or Enum.Font.Bangers
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.1
	t.Parent = bb
	bb.Parent = VFXLib.Folder
	local base = bb.StudsOffset
	VFXLib.animate(duration or 1.2, function(a)
		bb.StudsOffset = base + Vector3.new(0, a * 1.2, 0)
		t.TextTransparency = math.max(0, a * 1.6 - 0.6)
		t.TextStrokeTransparency = 0.1 + 0.9 * a
	end, function()
		bb:Destroy()
	end)
end

-- A command written in ink on a strip of paper over someone's head.
local function writtenStrip(target, text, time)
	local head = typeof(target) == "Instance" and target:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(300, 46)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	local paper = Instance.new("Frame")
	paper.Size = UDim2.fromScale(1, 1)
	paper.BackgroundColor3 = PAGE
	paper.BorderSizePixel = 0
	paper.Rotation = -3
	paper.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Color = PAGE_SHADE
	stroke.Thickness = 2
	stroke.Parent = paper
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, -12, 1, -8)
	t.Position = UDim2.fromOffset(6, 4)
	t.Font = Enum.Font.PermanentMarker
	t.TextScaled = true
	t.TextColor3 = INK
	t.Text = ""
	t.Parent = paper
	bb.Parent = VFXLib.Folder
	-- Written out letter by letter.
	local total = #text
	VFXLib.animate(time or 4, function(a)
		local shown = math.min(total, math.floor(a * (time or 4) / 0.025))
		t.Text = string.sub(text, 1, shown)
		if a > 0.85 then
			local k = (a - 0.85) / 0.15
			paper.BackgroundTransparency = k
			t.TextTransparency = k
			stroke.Transparency = k
		end
	end, function()
		bb:Destroy()
	end)
end

-- Ink drops flicking off the pen.
local function ink(from, dir)
	for _ = 1, 5 do
		local drop = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.22, 0.22, 0.22), Color = INK, CFrame = CFrame.new(from) })
		local v = (dir + Vector3.new((math.random() - 0.5) * 0.8, math.random() * 0.5, (math.random() - 0.5) * 0.8)).Unit * (10 + math.random() * 8)
		VFXLib.animate(0.35, function(a)
			local t = a * 0.35
			drop.CFrame = CFrame.new(from + v * t + Vector3.new(0, -30 * t * t, 0))
			drop.Transparency = math.max(0, a * 1.4 - 0.4)
		end, function()
			drop:Destroy()
		end)
	end
end

-- Their face peels open into a book: pages fan out in front of their head.
local function closeBook(target)
	local b = books[target]
	books[target] = nil
	if b then
		for _, p in ipairs(b.Parts) do
			p:Destroy()
		end
		if b.Badge and b.Badge.Parent then
			b.Badge:Destroy()
		end
	end
end

local function openBook(target, bookTime, readable)
	local head = typeof(target) == "Instance" and target:FindFirstChild("Head")
	if not head then
		return
	end
	closeBook(target)
	local parts = {}
	for i = 1, 8 do
		local side = i % 2 == 0 and 1 or -1
		local p = VFXLib.part({ Size = Vector3.new(0.9, 1.2, 0.03), Color = i % 3 == 0 and PAGE_SHADE or PAGE, Material = Enum.Material.SmoothPlastic })
		parts[i] = { Part = p, Side = side, Index = math.ceil(i / 2) }
	end
	local list = {}
	for _, e in ipairs(parts) do
		table.insert(list, e.Part)
	end
	local entry = { Parts = list }
	books[target] = entry
	-- The pages flutter while they're stuck, then fold away.
	VFXLib.animate(bookTime or 1.8, function(a)
		if not head.Parent then
			return
		end
		local open = a < 0.15 and VFXLib.easeOut(a / 0.15) or (a > 0.85 and (1 - a) / 0.15 or 1)
		for _, e in ipairs(parts) do
			local flap = math.sin(os.clock() * 14 + e.Index) * 0.15
			local ang = e.Side * (0.25 + e.Index * 0.22) * open + flap
			e.Part.CFrame = head.CFrame * CFrame.new(0, 0, -head.Size.Z / 2 - 0.15) * CFrame.Angles(0, ang, 0) * CFrame.new(e.Side * 0.45 * open, 0, 0)
		end
	end, function()
		if books[target] == entry then
			for _, p in ipairs(list) do
				p:Destroy()
			end
			entry.Parts = {}
		end
	end)
	-- A little open book over their head while he can write in them.
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(44, 44)
	bb.StudsOffset = Vector3.new(0, 2.4, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = "📖"
	t.Parent = bb
	bb.Parent = VFXLib.Folder
	entry.Badge = bb
	task.delay((bookTime or 1.8) + (readable or 7), function()
		if bb.Parent then
			bb:Destroy()
		end
		if books[target] == entry then
			books[target] = nil
		end
	end)
	VFXLib.sound(sounds.Swing, head.Position, 0.5, 1.6)
end

---------------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------------
local function onM1(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local index = data.Index or 1
	TuskAnimation.play(character, "RH_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.6 or 0.6, 0.8, -2.8), Duration = 0.26 })
	VFXLib.sound(sounds.Swing, root, 0.45, 1.15 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or INK)
	ink((root.CFrame * CFrame.new(0.8, 1, -1.5)).Position, root.CFrame.LookVector)
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "OpenBook" then
		if phase == "Reach" and character and root then
			TuskAnimation.play(character, "RHOpen")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 0.8, -4), Duration = (data.Windup or 0.3) + 0.4 })
			label(character:FindFirstChild("Head"), "HEAVEN'S DOOR!", GREEN, 1.2, 260)
		elseif phase == "Open" and typeof(data.Target) == "Instance" then
			openBook(data.Target, data.BookTime, data.Readable)
			local tr = data.Target:FindFirstChild("HumanoidRootPart")
			if tr then
				TuskVFX.CreateImpactStar(tr.Position + Vector3.new(0, 1.5, 0), { Size = 2.4, Rays = 6, Color = PAGE, Color2 = GREEN, Duration = 0.14 })
			end
		elseif phase == "Miss" and data.Position then
			VFXLib.burst(data.Position, { Count = 6, Color = PAGE, Speed = 8, Lifetime = 0.3 })
		end
	elseif move == "Write" then
		if (phase == "CantAttack" or phase == "FlyWrite") and character and root then
			TuskAnimation.play(character, "RHWrite")
			ink((root.CFrame * CFrame.new(0.8, 1, -1.5)).Position, root.CFrame.LookVector)
		end
		if phase == "CantAttack" and data.Target then
			writtenStrip(data.Target, "YOU CAN'T ATTACK KISHIBE ROHAN", math.min(data.Time or 7, 5))
		elseif phase == "FlyWrite" and data.Target then
			writtenStrip(data.Target, "FLY BACKWARDS AT 70 KM/H", 2.5)
		elseif phase == "Fly" and typeof(data.Target) == "Instance" then
			local tr = data.Target:FindFirstChild("HumanoidRootPart")
			if tr then
				-- Speed lines streaming off them as they go.
				VFXLib.animate(0.7, function()
					if not tr.Parent then
						return
					end
					if math.random() < 0.6 then
						local dir = data.Direction or Vector3.new(0, 0, 1)
						local p = tr.Position + Vector3.new((math.random() - 0.5) * 2, (math.random() - 0.5) * 3, (math.random() - 0.5) * 2)
						local line = VFXLib.part({ Size = Vector3.new(0.08, 0.08, 3), CFrame = CFrame.lookAt(p - dir * 1.5, p + dir), Color = Color3.new(1, 1, 1), Transparency = 0.2 })
						VFXLib.animate(0.2, function(a)
							line.Transparency = 0.2 + 0.8 * a
						end, function()
							line:Destroy()
						end)
					end
				end)
				CameraFX.shakeAt(tr.Position, 0.5, 40)
			end
		elseif phase == "Refused" and typeof(data.Target) == "Instance" then
			label(data.Target:FindFirstChild("Head"), "...!? (CAN'T ATTACK KISHIBE ROHAN)", INK, 1.4, 320, Vector3.new(0, 3.6, 0))
		elseif phase == "NoBook" and character and Common.isLocal(character) then
			label(character:FindFirstChild("Head"), "NO BOOK TO WRITE IN", PAGE, 1.0, 220)
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character and root then
		TuskAnimation.play(character, "RHUlt")
		TuskStand.action(character, "Loom", { Target = CFrame.new(1.2, 2.4, 1.6), Duration = (data.Windup or 0.8) + 0.6 })
		label(character:FindFirstChild("Head"), "HEAVEN'S DOOR: EVERYONE IS A BOOK", GREEN, 2.0, 380)
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.2)
	elseif data.Phase == "Books" and data.Position then
		-- A burst of pages from him.
		for _ = 1, 18 do
			local p = VFXLib.part({ Size = Vector3.new(0.8, 1.1, 0.03), Color = PAGE, CFrame = CFrame.new(data.Position) })
			local dir = Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5).Unit
			local dist = (data.Radius or 30) * (0.4 + math.random() * 0.6)
			local spin = Vector3.new(math.random() * 8, math.random() * 8, math.random() * 8)
			VFXLib.animate(0.9, function(a)
				p.CFrame = CFrame.new(data.Position + dir * dist * VFXLib.easeOut(a)) * CFrame.Angles(spin.X * a, spin.Y * a, spin.Z * a)
				p.Transparency = math.max(0, a * 1.5 - 0.5)
			end, function()
				p:Destroy()
			end)
		end
		for _, target in ipairs(data.Targets or {}) do
			openBook(target, data.BookTime or 3, 6)
			writtenStrip(target, "YOU CAN'T ATTACK KISHIBE ROHAN", 4)
		end
		CameraFX.shakeAt(data.Position, 0.6, 50)
		if character and Common.isLocal(character) then
			CameraFX.impactFrame(pal.Light)
		end
	end
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local function stepStance()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character then
			local want = character:GetAttribute("TuskAct") == ACT
			if want and not stanced[character] then
				stanced[character] = true
				TuskAnimation.hold(character, "RohanStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "RohanStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
	for target in pairs(books) do
		if not target.Parent then
			closeBook(target)
		end
	end
end

function RohanVFX.handle(name, data)
	if name == "M1" then
		onM1(data)
	elseif name == "M1Finisher" then
		onFinisher(data)
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

local slowTimer = 0
function RohanVFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
	end
end

return RohanVFX
end
end
