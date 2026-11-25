--[[
	Ringo_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Ringo Roadagain: Mandom (six seconds back).
	Its other half is Ringo_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: MandomStand
-- ======================================================================
__modules["MandomStand"] = function()
--[[
	TuskActVFX.MandomStand  (StarterPlayerScripts.SpinClient.TuskActVFX.MandomStand)

	MANDOM, matched to the art: it rides on Ringo's right shoulder.
	  * a big red-pink egg, tipped forward, covered in a diamond net of
	    dark maroon cords with a gold stud (dark centre) at every crossing
	  * under it, a chunky padded shoulder-pack of rust-brown leather:
	    stacked blocks and pouches with flaps and seams
	  * pink tubes curling out from under the pack, each ending in a gold
	    ring (the outfit plugs the same tubes into his arm and chest)
	TuskStand gives it a soft pink aura. Registered by RingoVFX.
]]

local MandomStand = {}

local EGG = Color3.fromRGB(188, 62, 98)
local CORD = Color3.fromRGB(112, 26, 56)
local STUD = Color3.fromRGB(226, 182, 76)
local STUD_DARK = Color3.fromRGB(46, 22, 26)
local PACK = Color3.fromRGB(172, 98, 70)
local PACK_DARK = Color3.fromRGB(122, 64, 44)
local PACK_LIGHT = Color3.fromRGB(198, 128, 92)
local TUBE = Color3.fromRGB(176, 58, 100)
local RING = Color3.fromRGB(226, 182, 76)

MandomStand.Aura = Color3.fromRGB(240, 130, 180)
MandomStand.AuraLight = Color3.fromRGB(255, 220, 236)
-- On his right shoulder, a little behind.
MandomStand.Offset = CFrame.new(1.5, 1.4, 0.45)

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

-- A rod from a to b (in the parent's space).
local function rod(model, parent, name, a, b, d, color)
	local len = (b - a).Magnitude
	if len < 1e-3 then
		return nil
	end
	local mid = (a + b) / 2
	local p = box(model, parent, name, Vector3.new(len + d * 0.4, d, d), color, CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- The egg's surface: theta from the top (0) to the bottom (pi).
local function eggPoint(theta, phi, a, b, push)
	local r = 1 + (push or 0)
	-- A little fuller at the bottom, like an egg.
	local fat = 1 + 0.08 * math.cos(theta)
	return Vector3.new(a * fat * r * math.sin(theta) * math.cos(phi), b * r * math.cos(theta), a * fat * r * math.sin(theta) * math.sin(phi))
end

function MandomStand.build(scale)
	local s = (scale or 1) * 0.8
	local model = Instance.new("Model")
	model.Name = "Mandom"
	local rig = { Joints = {} }
	local function V(x, y, z)
		return Vector3.new(x, y, z) * s
	end

	-- The shoulder-pack is the body.
	local pack = newPart(model, "Body", V(2.3, 1.5, 1.9), PACK)
	pack.Anchored = true
	pack.Massless = false
	pack.CFrame = CFrame.new()
	model.PrimaryPart = pack
	rig.Body = pack
	-- Stacked blocks and pouches, seams and flaps.
	box(model, pack, "Block", V(1.9, 0.9, 1.6), PACK_LIGHT, CFrame.new(-0.25 * s, 0.95 * s, 0.1 * s) * CFrame.Angles(0, 0, 0.12))
	box(model, pack, "BlockSeam", V(1.95, 0.08, 1.65), PACK_DARK, CFrame.new(-0.25 * s, 0.55 * s, 0.1 * s) * CFrame.Angles(0, 0, 0.12))
	box(model, pack, "Pouch", V(1.0, 1.1, 0.55), PACK, CFrame.new(0.35 * s, -0.2 * s, -1.15 * s))
	box(model, pack, "PouchFlap", V(1.08, 0.38, 0.62), PACK_LIGHT, CFrame.new(0.35 * s, 0.3 * s, -1.17 * s))
	box(model, pack, "PouchSeam", V(1.02, 0.06, 0.58), PACK_DARK, CFrame.new(0.35 * s, -0.75 * s, -1.15 * s))
	box(model, pack, "SidePouch", V(0.55, 1.0, 1.1), PACK, CFrame.new(1.35 * s, -0.25 * s, -0.2 * s))
	box(model, pack, "SideFlap", V(0.62, 0.34, 1.16), PACK_LIGHT, CFrame.new(1.37 * s, 0.25 * s, -0.2 * s))
	box(model, pack, "Strap", V(0.3, 1.7, 2.0), PACK_DARK, CFrame.new(-0.8 * s, 0, 0))
	box(model, pack, "LowerBlock", V(2.0, 0.6, 1.6), PACK_DARK, CFrame.new(0, -1.0 * s, 0.1 * s))
	for _, x in ipairs({ -0.7, 0, 0.7 }) do
		box(model, pack, "Rivet", V(0.14, 0.14, 0.06), STUD, CFrame.new(x * s, -1.0 * s, -0.72 * s))
	end

	-- The egg, on a joint so it can tip and turn.
	local a, b = 1.15 * s, 1.55 * s
	local headBase = CFrame.new(-0.1 * s, 1.6 * s, 0.2 * s) * CFrame.Angles(math.rad(-28), 0, math.rad(-10))
	local headOffset = CFrame.new(0, b * 0.9, 0)
	local egg, eggWeld = box(model, pack, "Head", Vector3.new(a * 2, b * 2, a * 2), EGG, headBase * headOffset)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	rig.Joints.Head = { Weld = eggWeld, Base = headBase, Offset = headOffset }
	-- The net: a diamond lattice of cords, a gold stud at each crossing.
	local rows, cols = 6, 8
	local points = {}
	for i = 1, rows do
		points[i] = {}
		local theta = math.pi * (0.16 + 0.7 * (i - 1) / (rows - 1))
		for j = 1, cols do
			local phi = (j + (i % 2) * 0.5) / cols * math.pi * 2
			points[i][j] = eggPoint(theta, phi, a, b, 0.015)
		end
	end
	local cord = 0.1 * s
	for i = 1, rows do
		for j = 1, cols do
			local p = points[i][j]
			-- Stud: gold, dark centre, facing out.
			local out = p.Magnitude > 0 and p.Unit or Vector3.new(0, 1, 0)
			ball(model, egg, "Stud", 0.22 * s, STUD, CFrame.new(p + out * 0.02 * s), Enum.Material.Metal)
			ball(model, egg, "StudEye", 0.11 * s, STUD_DARK, CFrame.new(p + out * 0.11 * s))
			if i < rows then
				-- Down-left and down-right to the next row (a diamond net).
				local shift = (i % 2 == 1) and 0 or 1
				local left = points[i + 1][((j - 1 + shift - 1) % cols) + 1]
				local right = points[i + 1][((j + shift - 1) % cols) + 1]
				rod(model, egg, "Cord", p, left, cord, CORD)
				rod(model, egg, "Cord", p, right, cord, CORD)
			end
		end
	end
	-- Top stud.
	ball(model, egg, "Stud", 0.26 * s, STUD, CFrame.new(0, b * 1.0, 0), Enum.Material.Metal)

	-- Tubes curling out from under the pack, each ending in a gold ring.
	-- (They loop out towards Ringo, on the pack's left, and forward.)
	local tubes = {
		{ Vector3.new(-1.0, -0.9, -0.5), Vector3.new(-1.7, -1.3, -0.9), Vector3.new(-2.0, -0.8, -1.4), Vector3.new(-1.7, -0.2, -1.5) },
		{ Vector3.new(-0.9, -1.2, 0.1), Vector3.new(-1.8, -1.8, 0.0), Vector3.new(-2.3, -1.4, -0.5) },
		{ Vector3.new(-0.3, -1.3, -0.7), Vector3.new(-0.6, -2.0, -1.3), Vector3.new(-1.3, -2.1, -1.6), Vector3.new(-1.6, -1.6, -1.9) },
		{ Vector3.new(0.5, -1.3, -0.6), Vector3.new(0.6, -1.9, -1.2), Vector3.new(0.1, -2.3, -1.6) },
		{ Vector3.new(-1.1, 0.2, -0.8), Vector3.new(-1.8, 0.4, -1.3), Vector3.new(-2.1, -0.1, -1.8) },
		{ Vector3.new(1.2, -0.9, 0.3), Vector3.new(1.7, -1.5, 0.1), Vector3.new(1.5, -2.0, -0.4) },
	}
	local td = 0.2 * s
	for _, t in ipairs(tubes) do
		local last = t[1] * s
		for k = 2, #t do
			local nxt = t[k] * s
			rod(model, pack, "Tube", last, nxt, td, TUBE)
			ball(model, pack, "TubeBend", td, TUBE, CFrame.new(nxt))
			last = nxt
		end
		local dir = (t[#t] - t[#t - 1]).Unit
		local ringCF = CFrame.lookAt(last, last + dir) * CFrame.Angles(0, math.pi / 2, 0)
		local ring = box(model, pack, "Ring", Vector3.new(0.12 * s, 0.34 * s, 0.34 * s), RING, ringCF, Enum.Material.Metal)
		ring.Shape = Enum.PartType.Cylinder
	end

	-- Where its effects come from: the egg's top.
	local point = Instance.new("Attachment")
	point.Name = "NailPoint"
	point.Position = Vector3.new(-0.1 * s, 3.2 * s, -0.4 * s)
	point.Parent = pack
	rig.NailPoint = point
	return model, rig
end

return MandomStand
end

-- ======================================================================
-- MODULE: RingoVFX
-- ======================================================================
__modules["RingoVFX"] = function()
--[[
	TuskActVFX.RingoVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.RingoVFX)

	Client visuals for Ringo Roadagain / MANDOM. Blocky.
	  * Mandom (MandomStand) rides on his right shoulder with a soft pink
	    aura; he stands easy, right hand by his holster
	  * REVOLVER COMBO: blows, then a point-blank shot (muzzle flash)
	  * SIX SECONDS: he looks at his watch; a big clock face appears behind
	    him and its hand spins BACKWARDS; then he's gone from where he
	    stood (a pink ghost stays a moment), a rewind streak runs back to
	    where he was 6 seconds ago, the screen goes sepia for whoever went
	    back, and enemies caught in it get a ghost and a spinning clock
	    over their head while they're dazed
	  * QUICK DRAW: muzzle flash, a bright tracer, a star where it lands
	  * MANDOM COUNTER: a clock on the ground under him, ticking; when he's
	    hit it spins back, he's behind them and fires
	  * THE PATH OF JUSTICE: "THE PATH OF JUSTICE"; a huge clock on the
	    ground follows him, its second hand sweeping out 6 seconds; then
	    "6 SECONDS", the hand whirls back and every hit lands again
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
local MandomStand = __require("MandomStand")

local RingoVFX = {}
local ACT = 19
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, MandomStand.build, { Aura = MandomStand.Aura, AuraLight = MandomStand.AuraLight, Offset = MandomStand.Offset })

local PINK = Color3.fromRGB(240, 130, 180)
local GOLD = Color3.fromRGB(246, 204, 40)
local FACE = Color3.fromRGB(255, 244, 220)
local FLASH = Color3.fromRGB(255, 236, 170)
local SEPIA = Color3.fromRGB(255, 226, 180)
local FLAT = CFrame.Angles(0, 0, math.pi / 2) -- a cylinder lying flat

local stanced = {}
local poses = setmetatable({}, { __mode = "k" }) -- [character] = snapshot taken when he turns the watch
local dazeClocks = {} -- [character] = clock over their head
local paths = {} -- [character] = the ultimate's ground clock

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function ground(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { VFXLib.Folder }
	local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position or (pos - Vector3.new(0, 3, 0))
end

local function nearLocal(pos, range)
	local r = localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	return r ~= nil and (r.Position - pos).Magnitude <= range
end

local function label(adornee, text, color, duration, size)
	if not adornee then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size or 240, (size or 240) / 5)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = adornee
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.1
	t.Parent = bb
	bb.Parent = VFXLib.Folder
	VFXLib.animate(duration or 1.4, function(a)
		bb.StudsOffset = Vector3.new(0, 3 + a, 0)
		t.TextTransparency = math.max(0, a * 1.5 - 0.5)
		t.TextStrokeTransparency = 0.1 + 0.9 * a
	end, function()
		bb:Destroy()
	end)
end

-- A clock face: a rim, a face, 12 marks (the 12 a little bigger) and a
-- hand. `place()` sets where it is (its face looks along the CFrame's
-- LookVector), `set(angle)` turns the hand, `fade(t)` and `destroy()`.
local function clock(radius, faceAlpha)
	local parts = {}
	local function add(p)
		table.insert(parts, { Part = p, Base = p.Transparency })
		return p
	end
	local face = add(VFXLib.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, radius * 2, radius * 2), Color = FACE, Material = Enum.Material.Neon, Transparency = faceAlpha or 0.8 }))
	local rim = add(VFXLib.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, radius * 2.08, radius * 2.08), Color = PINK, Material = Enum.Material.Neon, Transparency = 0.35 }))
	local marks = {}
	for i = 1, 12 do
		local big = i == 12 or i % 3 == 0
		marks[i] = add(VFXLib.part({ Size = Vector3.new(0.12, big and radius * 0.22 or radius * 0.12, big and 0.2 or 0.12), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.15 }))
	end
	local hand = add(VFXLib.part({ Size = Vector3.new(0.14, radius * 0.85, 0.18), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.05 }))
	local hub = add(VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4) * math.max(radius / 3, 0.6), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.05 }))
	local c = { CF = CFrame.new(), Angle = 0 }
	local function draw()
		-- The face's local frame: X out of the face, Y up the face (12 o'clock).
		local cf = c.CF * CFrame.Angles(0, math.pi / 2, 0)
		face.CFrame = cf
		rim.CFrame = cf * CFrame.new(-0.02, 0, 0)
		for i = 1, 12 do
			local a = -i / 12 * math.pi * 2
			marks[i].CFrame = cf * CFrame.Angles(a, 0, 0) * CFrame.new(0.05, radius * 0.85, 0)
		end
		hand.CFrame = cf * CFrame.Angles(-c.Angle, 0, 0) * CFrame.new(0.08, radius * 0.42, 0)
		hub.CFrame = cf * CFrame.new(0.08, 0, 0)
	end
	function c.place(cf)
		c.CF = cf
		draw()
	end
	function c.set(angle)
		c.Angle = angle
		draw()
	end
	function c.fade(t)
		for _, p in ipairs(parts) do
			p.Part.Transparency = p.Base + (1 - p.Base) * math.clamp(t, 0, 1)
		end
	end
	function c.destroy()
		for _, p in ipairs(parts) do
			p.Part:Destroy()
		end
	end
	return c
end
RingoVFX.clock = clock

-- A flat clock lying on the ground (12 o'clock pointing along `forward`).
local function groundCF(center, forward)
	local f = Vector3.new(forward.X, 0, forward.Z)
	f = f.Magnitude > 1e-3 and f.Unit or Vector3.new(0, 0, -1)
	return CFrame.lookAt(center + Vector3.new(0, 0.12, 0), center + Vector3.new(0, 1.12, 0), f)
end

-- A pink see-through copy of a character's pose.
local function snapshot(character)
	local shot = {}
	for _, d in ipairs(character:GetChildren()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
			table.insert(shot, { Size = d.Size, CFrame = d.CFrame })
		end
	end
	return shot
end

local function ghost(shot, duration, color)
	local parts = {}
	for _, s in ipairs(shot or {}) do
		table.insert(parts, VFXLib.part({ Size = s.Size, CFrame = s.CFrame, Color = color or PINK, Material = Enum.Material.Neon, Transparency = 0.45 }))
	end
	VFXLib.animate(duration or 0.9, function(a)
		for _, p in ipairs(parts) do
			p.Transparency = 0.45 + 0.55 * a
		end
	end, function()
		for _, p in ipairs(parts) do
			p:Destroy()
		end
	end)
end

local function boxGhost(position, duration)
	ghost({ { Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0)) }, { Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(position + Vector3.new(0, 2.2, 0)) }, { Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(position - Vector3.new(0, 1.4, 0)) } }, duration)
end

-- A streak running backwards from `from` to `to` (the rewind).
local function streak(from, to, color)
	local len = (to - from).Magnitude
	if len < 0.5 then
		return
	end
	local beam = VFXLib.part({ Size = Vector3.new(0.4, 0.4, len), Color = color or PINK, Material = Enum.Material.Neon, Transparency = 0.2 })
	VFXLib.animate(0.45, function(a)
		local head = from:Lerp(to, math.min(a * 2, 1))
		local tail = from:Lerp(to, math.max(a * 2 - 1, 0))
		local l = math.max((head - tail).Magnitude, 0.1)
		beam.Size = Vector3.new(0.4 * (1 - a * 0.5), 0.4 * (1 - a * 0.5), l)
		beam.CFrame = CFrame.lookAt((head + tail) / 2, head + (to - from).Unit * 0.01)
		beam.Transparency = 0.2 + 0.6 * a
	end, function()
		beam:Destroy()
	end)
end

-- The screen goes sepia and the edges darken (time going back).
local function sepia(duration)
	TuskVFX.ScreenTint(duration, { Tint = SEPIA, Saturation = -0.7, Brightness = -0.05, Contrast = 0.2, Release = 0.05, FadeOut = 0.4 })
end

local function muzzle(pos, direction)
	VFXLib.flash(pos, FLASH, 6, 14, 0.08)
	local f = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(pos), Color = FLASH, Transparency = 0.1 })
	VFXLib.animate(0.1, function(a)
		local s = 1.2 + a * 1.2
		f.Size = Vector3.new(s, s, s)
		f.Transparency = 0.1 + 0.9 * a
	end, function()
		f:Destroy()
	end)
	if direction and direction.Magnitude > 1e-3 then
		VFXLib.burst(pos, { Count = 6, Color = FLASH, Speed = 18, Lifetime = 0.2 })
	end
end

local function tracer(from, to, hit)
	muzzle(from, to - from)
	local len = (to - from).Magnitude
	if len > 0.5 then
		local line = VFXLib.part({ Size = Vector3.new(0.12, 0.12, len), CFrame = CFrame.lookAt((from + to) / 2, to), Color = FLASH, Transparency = 0.05 })
		VFXLib.animate(0.16, function(a)
			line.Transparency = 0.05 + 0.95 * a
			line.Size = Vector3.new(0.12 * (1 - a), 0.12 * (1 - a), len)
		end, function()
			line:Destroy()
		end)
	end
	if hit then
		TuskVFX.CreateImpactStar(to, { Size = 2.4, Rays = 6, Color = GOLD, Color2 = Color3.new(1, 1, 1), Duration = 0.14 })
	else
		VFXLib.burst(to, { Count = 5, Color = Color3.fromRGB(200, 180, 150), Speed = 8, Lifetime = 0.3 })
	end
	VFXLib.sound(sounds.NailFire, from, 0.7, 1.3)
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
	TuskAnimation.play(character, "RG_M1_" .. math.clamp(index, 1, 4))
	VFXLib.sound(sounds.Swing, root, 0.5, 1.0 + index * 0.05)
	if index == 4 then
		task.delay(0.1, function()
			local r = Common.rootOf(character)
			if r then
				local from = (r.CFrame * CFrame.new(0.9, 0.5, -2.2)).Position
				tracer(from, from + r.CFrame.LookVector * 4, false)
			end
		end)
	else
		Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or pal.Second)
	end
end

local function onFinisher(data)
	Common.finisher(data, pal, { Size = 1, Layers = 2 })
end

-- SIX SECONDS: a big clock behind him, its hand spinning back.
local function turnWatch(character, root, windup)
	poses[character] = snapshot(character)
	TuskAnimation.play(character, "RGWatchTurn")
	TuskStand.action(character, "Loom", { Target = CFrame.new(1.6, 2.4, 0.8), Duration = windup + 0.5 })
	local c = clock(3.2, 0.75)
	local spin = 0
	VFXLib.animate(windup + 0.35, function(a)
		local r = Common.rootOf(character)
		local at = r and r.CFrame or root.CFrame
		c.place(at * CFrame.new(0, 2.6, 2.6) * CFrame.Angles(0, math.pi, 0))
		spin = -a * math.pi * 4
		c.set(spin)
		c.fade(a < 0.15 and 1 - a / 0.15 or (a > 0.8 and (a - 0.8) / 0.2 or 0))
	end, function()
		c.destroy()
	end)
	VFXLib.sound(sounds.ChargeFull, root, 0.5, 0.8)
end

local function rewound(data)
	local character = data.Character
	if character and data.From then
		ghost(poses[character], 0.9)
		poses[character] = nil
		if data.To then
			streak(data.From, data.To, PINK)
		end
		VFXLib.burst(data.From, { Count = 14, Color = PINK, Speed = 10, Lifetime = 0.5 })
	end
	if data.To then
		TuskVFX.CreateRotationalShockwave(CFrame.new(ground(data.To)), { Radius = 5, Layers = 2, Color = PINK, Color2 = GOLD, Ground = true, Particles = 0.5, Width = 0.35 })
	end
	local mine = character and Common.isLocal(character)
	for _, s in ipairs(data.Snapped or {}) do
		if s.From then
			boxGhost(s.From, 0.8)
			if s.To then
				streak(s.From, s.To, GOLD)
			end
		end
		if s.Target and Common.isLocal(s.Target) then
			mine = true
		end
	end
	if mine then
		sepia(0.5)
		CameraFX.fovPunch(-10, 0.4)
		CameraFX.impactFrame(SEPIA)
	end
	VFXLib.sound(sounds.AwakeningBurst or sounds.Swing, data.To or data.From or Vector3.new(), 0.5, 1.4)
end

local counters = {} -- [character] = the ground clock while he waits

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "SixSeconds" then
		if phase == "Wind" and character and root then
			turnWatch(character, root, data.Windup or 0.35)
		elseif phase == "Rewind" then
			rewound(data)
		end
	elseif move == "QuickDraw" then
		if phase == "Draw" and character and root then
			TuskAnimation.play(character, "RGDraw")
			VFXLib.burst((root.CFrame * CFrame.new(1, -0.6, 0)).Position, { Count = 3, Color = GOLD, Speed = 4, Lifetime = 0.2 })
		elseif phase == "Bang" and data.From and data.To then
			tracer(data.From, data.To, data.Hit)
			if character and Common.isLocal(character) then
				CameraFX.shake(0.25, 0.12)
			end
		end
	elseif move == "Counter" then
		if phase == "Ready" and character and root then
			TuskAnimation.play(character, "RGCounter")
			local old = counters[character]
			if old then
				old.destroy()
			end
			local c = clock(4, 0.85)
			counters[character] = c
			local window = data.Window or 1
			local start = os.clock()
			VFXLib.animate(window + 0.1, function(a)
				local r = Common.rootOf(character)
				if counters[character] ~= c or not r then
					return
				end
				c.place(groundCF(ground(r.Position), r.CFrame.LookVector))
				-- Ticks round, one mark at a time.
				c.set(math.floor((os.clock() - start) * 6) / 12 * math.pi * 2)
				c.fade(a < 0.1 and 1 - a / 0.1 or 0)
			end, function()
				if counters[character] == c then
					counters[character] = nil
					c.destroy()
				end
			end)
			label(character:FindFirstChild("Head"), "MANDOM", PINK, 1.0, 180)
		elseif phase == "Rewind" and character then
			local c = counters[character]
			counters[character] = nil
			if c then
				VFXLib.animate(0.3, function(a)
					c.set(-a * math.pi * 4)
					c.fade(a)
				end, function()
					c.destroy()
				end)
			end
			if data.From then
				boxGhost(data.From, 0.6)
				if data.To then
					streak(data.From, data.To, PINK)
				end
			end
			if (character and Common.isLocal(character)) or (data.Attacker and Common.isLocal(data.Attacker)) then
				sepia(0.35)
				CameraFX.impactFrame(SEPIA)
			end
			label(character:FindFirstChild("Head"), "6 SECONDS", GOLD, 1.0, 200)
		elseif phase == "Whiff" and character then
			local c = counters[character]
			counters[character] = nil
			if c then
				VFXLib.animate(0.25, function(a)
					c.fade(a)
				end, function()
					c.destroy()
				end)
			end
		end
	end
end

---------------------------------------------------------------------------
-- THE PATH OF JUSTICE
---------------------------------------------------------------------------
local function endPath(character)
	local p = paths[character]
	paths[character] = nil
	if p then
		VFXLib.animate(0.3, function(a)
			p.Clock.fade(a)
		end, function()
			p.Clock.destroy()
		end)
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Wind" and character and root then
		TuskAnimation.play(character, "RGWatchTurn")
		TuskStand.action(character, "Loom", { Target = CFrame.new(1.6, 2.6, 0.8), Duration = (data.Windup or 0.6) + 0.6 })
		label(character:FindFirstChild("Head"), "THE PATH OF JUSTICE", PINK, 2.0, 360)
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.0)
	elseif data.Phase == "Path" and character and root then
		endPath(character)
		local duration = data.Duration or 6
		local c = clock(9, 0.88)
		local p = { Clock = c, Start = os.clock(), Duration = duration }
		paths[character] = p
		VFXLib.animate(duration, function(a)
			local r = Common.rootOf(character)
			if paths[character] ~= p or not r then
				return
			end
			c.place(groundCF(ground(r.Position), Vector3.new(0, 0, -1)))
			-- The second hand ticks out the 6 seconds (one mark = 1 second, here).
			local t = os.clock() - p.Start
			c.set(math.floor(t) / 12 * math.pi * 2 + math.min((t % 1) * 8, 1) * math.pi * 2 / 12)
			c.fade(a < 0.05 and 1 - a / 0.05 or 0)
		end)
		if nearLocal(root.Position, 40) then
			TuskVFX.ScreenTint(duration, { Tint = Color3.fromRGB(255, 220, 236), Saturation = -0.25, Brightness = 0, Contrast = 0.1, Release = 0, FadeOut = 0.4 })
		end
	elseif data.Phase == "Rewind" and character then
		local p = paths[character]
		paths[character] = nil
		if p then
			local from = p.Clock.Angle
			VFXLib.animate(0.6, function(a)
				p.Clock.set(from - VFXLib.easeOut(a) * math.pi * 6)
				p.Clock.fade(a > 0.6 and (a - 0.6) / 0.4 or 0)
			end, function()
				p.Clock.destroy()
			end)
		end
		label(character:FindFirstChild("Head"), "6 SECONDS", GOLD, 1.8, 300)
		if root then
			TuskVFX.CreateRotationalShockwave(CFrame.new(ground(root.Position)), { Radius = 12, Layers = 3, Color = PINK, Color2 = GOLD, Ground = true, Particles = 1, Width = 0.5 })
		end
		local hitLocal = Common.isLocal(character)
		for _, target in ipairs(data.Targets or {}) do
			local tr = Common.rootOf(target)
			if tr then
				-- The hits come back: a burst of gold stars on them.
				for k = 0, 3 do
					task.delay(0.35 + k * 0.12, function()
						local r2 = Common.rootOf(target)
						if r2 then
							TuskVFX.CreateImpactStar(r2.Position + Vector3.new(math.random() - 0.5, math.random(), math.random() - 0.5), { Size = 3, Rays = 7, Color = GOLD, Color2 = PINK, Duration = 0.16 })
						end
					end)
				end
			end
			if Common.isLocal(target) then
				hitLocal = true
			end
		end
		if hitLocal then
			sepia(0.6)
			CameraFX.impactFrame(SEPIA)
			CameraFX.shake(0.6, 0.4)
		end
		VFXLib.sound(sounds.AwakeningBurst or sounds.Swing, root or Vector3.new(), 0.7, 0.9)
	elseif data.Phase == "End" and character then
		endPath(character)
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
				TuskAnimation.hold(character, "RGStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "RGStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

-- Dazed (lost 6 seconds): a little clock spins over their head.
local function stepDazed()
	local t = workspace:GetServerTimeNow()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character and (character:GetAttribute("MandomDazedUntil") or 0) > t and not dazeClocks[character] then
			dazeClocks[character] = clock(0.8, 0.5)
		end
	end
	for character, c in pairs(dazeClocks) do
		local head = character.Parent and character:FindFirstChild("Head")
		if not head or (character:GetAttribute("MandomDazedUntil") or 0) <= t then
			c.destroy()
			dazeClocks[character] = nil
		end
	end
end

local function stepDazeClocks()
	local cam = workspace.CurrentCamera
	for character, c in pairs(dazeClocks) do
		local head = character:FindFirstChild("Head")
		if head then
			local at = head.Position + Vector3.new(0, 2, 0)
			local look = cam and (cam.CFrame.Position - at) or Vector3.new(0, 0, 1)
			look = Vector3.new(look.X, 0, look.Z)
			if look.Magnitude < 1e-3 then
				look = Vector3.new(0, 0, 1)
			end
			c.place(CFrame.lookAt(at, at + look.Unit))
			c.set(-os.clock() * 8)
		end
	end
end

function RingoVFX.handle(name, data)
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
function RingoVFX.step(dt)
	dt = dt or 1 / 60
	stepDazeClocks()
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
		stepDazed()
	end
end

return RingoVFX
end
end
