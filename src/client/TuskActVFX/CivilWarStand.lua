--[[
	TuskActVFX.CivilWarStand  (StarterPlayerScripts.SpinClient.TuskActVFX.CivilWarStand)

	The CIVIL WAR Stand model (Axl RO), blocky, matched to the art: red,
	yellow and silvery metal.
	  * the head: a distorted metal mask of tall vertical discs pressed
	    together, a spike on top, three arrow points tapering below
	  * three gas-mask filter canisters round the base of the neck (front
	    and both sides)
	  * a red quilted (tufted) chest and a quilted hump on the back
	  * silver shoulder balls; long yellow limbs with purple joint rings
	  * a bare silver spine from the ribcage down to a toothed silver pelvis
	  * red, fraying bell-bottom lower legs like roots, pointed red feet
	Registered with TuskStandModels by AxlVFX, so TuskStand floats it behind
	Axl RO (players and NPCs) with a crimson aura. A custom model at
	ReplicatedStorage.SpinAssets.TuskAct12 replaces it.
]]

local CivilWarStand = {}

local RED = Color3.fromRGB(196, 46, 40)
local RED_DARK = Color3.fromRGB(128, 26, 26)
local YELLOW = Color3.fromRGB(234, 208, 128)
local YELLOW_DARK = Color3.fromRGB(196, 166, 90)
local SILVER = Color3.fromRGB(190, 196, 206)
local SILVER_DARK = Color3.fromRGB(120, 126, 140)
local PURPLE = Color3.fromRGB(90, 52, 110)
local PURPLE_DARK = Color3.fromRGB(40, 24, 52)
local BUTTON = Color3.fromRGB(214, 170, 80)

CivilWarStand.Aura = Color3.fromRGB(220, 50, 70)
CivilWarStand.AuraLight = Color3.fromRGB(255, 170, 180)
CivilWarStand.Offset = CFrame.new(2.5, 1.7, 3.1)

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

-- A purple joint ring round a limb (local Y axis) at `cf`.
local function ring(model, parent, cf, width, s)
	box(model, parent, "Ring", Vector3.new(width + 0.22 * s, 0.24 * s, width + 0.22 * s), PURPLE, cf)
	box(model, parent, "RingHole", Vector3.new(0.2, 0.2, 0.06) * s, PURPLE_DARK, cf * CFrame.new(0, 0, -(width / 2 + 0.12 * s)))
end

-- Quilting on a face: a diamond grid of creases with buttons where they meet.
local function quilt(model, parent, cf, w, h, s)
	local cols, rows = math.max(2, math.floor(w / (0.5 * s))), math.max(2, math.floor(h / (0.45 * s)))
	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			local x = (i - (cols - 1) / 2) * w / cols
			local y = (j - (rows - 1) / 2) * h / rows
			box(model, parent, "Quilt", Vector3.new(0.3, 0.05, 0.04) * s, RED_DARK, cf * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.pi / 4))
			box(model, parent, "Quilt", Vector3.new(0.3, 0.05, 0.04) * s, RED_DARK, cf * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, -math.pi / 4))
			box(model, parent, "Tuft", Vector3.new(0.08, 0.08, 0.05) * s, BUTTON, cf * CFrame.new(x, y, -0.01 * s))
		end
	end
end

function CivilWarStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "CivilWar"
	local rig = { Joints = {} }

	-- Red quilted chest (the anchored root the Stand is moved by).
	local torso = newPart(model, "Body", Vector3.new(2.1, 1.5, 1.1) * s, RED)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	quilt(model, torso, CFrame.new(0, 0, -0.56 * s), 1.9 * s, 1.3 * s, s)
	-- The quilted hump on its back.
	local hump = box(model, torso, "Hump", Vector3.new(1.9, 1.4, 0.8) * s, RED, CFrame.new(0, 0.25 * s, 0.85 * s))
	box(model, torso, "Hump", Vector3.new(1.5, 1.0, 0.3) * s, RED, CFrame.new(0, 0.3 * s, 1.36 * s))
	quilt(model, hump, CFrame.new(0, 0, 0.41 * s) * CFrame.Angles(0, math.pi, 0), 1.7 * s, 1.2 * s, s)
	box(model, torso, "ChestTrim", Vector3.new(2.16, 0.14, 1.16) * s, RED_DARK, CFrame.new(0, -0.72 * s, 0))

	-- Bare silver spine from the ribcage to the pelvis.
	for i = 0, 3 do
		local y = -0.95 * s - i * 0.34 * s
		box(model, torso, "Vertebra", Vector3.new(0.34, 0.22, 0.34) * s, SILVER, CFrame.new(0, y, 0.05 * s))
		box(model, torso, "Vertebra", Vector3.new(0.6, 0.08, 0.14) * s, SILVER_DARK, CFrame.new(0, y, 0.05 * s))
	end
	-- Toothed pelvis.
	box(model, torso, "Pelvis", Vector3.new(1.5, 0.55, 0.9) * s, SILVER, CFrame.new(0, -2.45 * s, 0))
	for i = -3, 3 do
		box(model, torso, "PelvisTooth", Vector3.new(0.1, 0.4, 0.06) * s, SILVER_DARK, CFrame.new(i * 0.18 * s, -2.5 * s, -0.47 * s))
	end

	-- Neck and the three gas-mask filter canisters.
	box(model, torso, "Neck", Vector3.new(0.5, 0.4, 0.5) * s, SILVER_DARK, CFrame.new(0, 0.9 * s, 0))
	for _, spot in ipairs({ { 0, -0.55, 0 }, { -0.6, -0.1, math.pi / 2 }, { 0.6, -0.1, -math.pi / 2 } }) do
		local cf = CFrame.new(spot[1] * s, 0.95 * s, spot[2] * s) * CFrame.Angles(0, spot[3], 0)
		box(model, torso, "Filter", Vector3.new(0.42, 0.42, 0.32) * s, SILVER, cf)
		box(model, torso, "FilterCap", Vector3.new(0.34, 0.34, 0.08) * s, SILVER_DARK, cf * CFrame.new(0, 0, -0.18 * s))
		box(model, torso, "FilterHole", Vector3.new(0.14, 0.14, 0.06) * s, PURPLE_DARK, cf * CFrame.new(0, 0, -0.22 * s))
	end

	-- Head: tall vertical discs pressed together, a spike, three arrows below.
	local headBase = CFrame.new(0, 1.1 * s, 0)
	local headOffset = CFrame.new(0, 0.75 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.3, 1.1, 0.9) * s, SILVER, headBase * headOffset, Enum.Material.Metal)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local discs = { { -0.48, 0.9 }, { -0.32, 1.2 }, { -0.16, 1.45 }, { 0.16, 1.45 }, { 0.32, 1.2 }, { 0.48, 0.9 } }
	for i, d in ipairs(discs) do
		box(model, head, "Disc", Vector3.new(0.13, d[2], 0.95) * s, i % 2 == 0 and SILVER or SILVER_DARK, CFrame.new(d[1] * s, (d[2] - 1.1) * 0.3 * s, 0), Enum.Material.Metal)
	end
	box(model, head, "Disc", Vector3.new(0.16, 1.7, 1.0) * s, SILVER, CFrame.new(0, 0.2 * s, 0), Enum.Material.Metal)
	-- Spike on top with two little cross bars.
	for i = 0, 4 do
		local w = (0.22 - i * 0.035) * s
		box(model, head, "Spike", Vector3.new(w, 0.32 * s, w), SILVER, CFrame.new(0, (1.15 + i * 0.3) * s, 0), Enum.Material.Metal)
	end
	box(model, head, "CrossBar", Vector3.new(0.7, 0.06, 0.06) * s, SILVER_DARK, CFrame.new(0, 1.35 * s, 0))
	box(model, head, "CrossBar", Vector3.new(0.06, 0.06, 0.5) * s, SILVER_DARK, CFrame.new(0, 1.55 * s, 0))
	-- Three arrow points tapering down below the mask.
	for _, x in ipairs({ -0.3, 0, 0.3 }) do
		box(model, head, "Arrow", Vector3.new(0.1, 0.45, 0.1) * s, SILVER, CFrame.new(x * s, -0.75 * s, -0.2 * s), Enum.Material.Metal)
		box(model, head, "ArrowHead", Vector3.new(0.24, 0.24, 0.08) * s, SILVER_DARK, CFrame.new(x * s, -1.0 * s, -0.2 * s) * CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Metal)
	end
	-- A slit of an eye in the mask.
	box(model, head, "Eye", Vector3.new(0.9, 0.06, 0.04) * s, PURPLE_DARK, CFrame.new(0, 0.25 * s, -0.5 * s))

	-- Shoulders (silver balls) and long yellow arms with purple joint rings.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		box(model, torso, "ShoulderBall", Vector3.new(0.6, 0.6, 0.6) * s, SILVER, CFrame.new(side * 1.25 * s, 0.5 * s, 0), Enum.Material.Metal)
		local base = CFrame.new(side * 1.3 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.25 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.42, 2.5, 0.42) * s, YELLOW, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		ring(model, arm, CFrame.new(0, 1.05 * s, 0), 0.42 * s, s)
		ring(model, arm, CFrame.new(0, 0, 0), 0.42 * s, s)
		ring(model, arm, CFrame.new(0, -1.05 * s, 0), 0.42 * s, s)
		box(model, arm, "Muscle", Vector3.new(0.5, 0.7, 0.5) * s, YELLOW_DARK, CFrame.new(0, 0.55 * s, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.4, 0.34, 0.36) * s, YELLOW, CFrame.new(0, -1.38 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.08, 0.5, 0.08) * s, YELLOW_DARK, CFrame.new(f * 0.1 * s, -0.38 * s, -0.06 * s) * CFrame.Angles(0.25, 0, 0))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.5 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: yellow thighs, purple knee rings, red fraying bell-bottoms.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.5 * s, -2.6 * s, 0)
		local offset = CFrame.new(0, -0.65 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.5, 1.3, 0.5) * s, YELLOW, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		ring(model, leg, CFrame.new(0, 0.6 * s, 0), 0.5 * s, s)
		ring(model, leg, CFrame.new(0, -0.7 * s, 0), 0.5 * s, s)
		-- The bell-bottom widens toward the hem.
		for k = 0, 3 do
			local w = (0.6 + k * 0.16) * s
			box(model, leg, "BellBottom", Vector3.new(w, 0.4 * s, w), k % 2 == 0 and RED or RED_DARK, CFrame.new(0, (-1.0 - k * 0.38) * s, 0))
		end
		-- Frayed, root-like strips hanging from the hem.
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			local len = (0.35 + (k % 3) * 0.18) * s
			box(model, leg, "Fray", Vector3.new(0.12 * s, len, 0.12 * s), k % 2 == 0 and RED or RED_DARK, CFrame.new(math.cos(a) * 0.5 * s, -2.32 * s - len / 2, math.sin(a) * 0.5 * s) * CFrame.Angles(math.sin(a) * 0.3, 0, -math.cos(a) * 0.3))
		end
		box(model, leg, "Foot", Vector3.new(0.5, 0.26, 1.0) * s, RED, CFrame.new(0, -2.4 * s, -0.25 * s))
		box(model, leg, "Toe", Vector3.new(0.3, 0.2, 0.35) * s, RED_DARK, CFrame.new(0, -2.42 * s, -0.86 * s))
	end
	return model, rig
end

return CivilWarStand
