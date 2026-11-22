---
tags: [code, shared]
type: ModuleScript
location: "ReplicatedStorage › SpinShared"
updated: 2026-11-22
---
# RaptorModel

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ReplicatedStorage › SpinShared` |
| **Exact name** | `RaptorModel` (capitals matter) |

**What it does:** Scary Monsters' raptor, built from parts (from the owner's references): teal head, neck and chest with dark navy stripe rings deep blue haunches, legs and tail; pale yellow tail underside yellow "0101" markings along the tail open jaws with rows of white teeth and a pink mouth/tongue the yellow pin crown around the back of the skull small clawed arms, digitigrade legs with yellow toe and sickle claws

## How to add it
1. In Studio's Explorer, find **SpinShared** (ReplicatedStorage › SpinShared).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **RaptorModel**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	RaptorModel  (ReplicatedStorage.SpinShared.RaptorModel)

	Scary Monsters' raptor, built from parts (from the owner's references):
	  * teal head, neck and chest with dark navy stripe rings
	  * deep blue haunches, legs and tail; pale yellow tail underside
	  * yellow "0101" markings along the tail
	  * open jaws with rows of white teeth and a pink mouth/tongue
	  * the yellow pin crown around the back of the skull
	  * small clawed arms, digitigrade legs with yellow toe and sickle claws

	RaptorModel.build(scale, opts) -> rig
	  opts.Lite = true   fewer details (teeth, crown, markings) for crowds
	  opts.Blocky = false  keep rounded shapes (default: TuskConfig.BlockyModels)
	  rig.Model          the Model (all parts anchored, no collision)
	  rig:Pose(groundCF, s)  place every part. groundCF = point on the ground
	                         under the hips, facing the way the raptor looks.
	      s.Phase  walk cycle (radians)     s.Speed  0..1 run amount
	      s.Jaw    0..1 mouth open          s.Lunge  0..1 head/body thrust
	      s.Claw   0..1 arm swipe           s.Crouch 0..1 low stance
	      s.Whip   -1..1 tail whip          s.Time   seconds (idle motion)
	      s.HeadYaw / s.HeadPitch  radians
	  rig:Destroy()
	Size: about 8 studs tall at the head and 15 long at scale 1.
]]

local TuskConfig = require(script.Parent.TuskConfig)
local Blockify = require(script.Parent.Blockify)

local RaptorModel = {}

local C = {
	Teal = Color3.fromRGB(95, 205, 212),
	TealDark = Color3.fromRGB(55, 150, 170),
	Navy = Color3.fromRGB(22, 32, 72),
	Blue = Color3.fromRGB(38, 62, 190),
	BlueDark = Color3.fromRGB(24, 40, 140),
	Pale = Color3.fromRGB(242, 234, 172),
	Yellow = Color3.fromRGB(246, 212, 62),
	Gold = Color3.fromRGB(232, 190, 58),
	Mouth = Color3.fromRGB(215, 95, 108),
	Tongue = Color3.fromRGB(230, 130, 140),
	Teeth = Color3.fromRGB(246, 246, 236),
	Eye = Color3.fromRGB(250, 240, 200),
	Pupil = Color3.fromRGB(15, 15, 20),
}
RaptorModel.Colors = C

local TAIL_SEGMENTS = 9
local TAIL_LENGTH = 1.25

local function newPart(model, name, size, color, opts)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = (opts and opts.Material) or Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CastShadow = not (opts and opts.NoShadow)
	if opts and opts.Ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	if opts and opts.Cylinder then
		p.Shape = Enum.PartType.Cylinder
	end
	if opts and opts.Ball then
		p.Shape = Enum.PartType.Ball
	end
	p.Parent = model
	return p
end

function RaptorModel.build(scale, opts)
	scale = scale or 1
	opts = opts or {}
	local lite = opts.Lite == true
	local model = Instance.new("Model")
	model.Name = "ScaryMonstersRaptor"

	local entries = {} -- { Part, Bone, Offset }
	local function add(bone, name, size, color, offset, partOpts)
		local p = newPart(model, name, size * scale, color, partOpts)
		local o = offset or CFrame.new()
		table.insert(entries, { Part = p, Bone = bone, Offset = o - o.Position + o.Position * scale })
		return p
	end
	local E = { Ellipsoid = true }
	local function ell(extra)
		local t = { Ellipsoid = true }
		for k, v in pairs(extra or {}) do
			t[k] = v
		end
		return t
	end

	-- BODY (bone origin = middle of the torso)
	add("Body", "Torso", Vector3.new(2.6, 2.7, 4.6), C.Teal, CFrame.new(0, 0, 0), E)
	add("Body", "Chest", Vector3.new(2.35, 2.55, 2.5), C.Teal, CFrame.new(0, 0.25, -2.0), E)
	add("Body", "Belly", Vector3.new(2.1, 1.6, 3.4), C.TealDark, CFrame.new(0, -0.65, -0.6), E)
	for _, side in ipairs({ -1, 1 }) do
		add("Body", "Haunch", Vector3.new(1.5, 2.5, 2.8), C.Blue, CFrame.new(side * 0.85, -0.2, 1.0), E)
	end
	-- Dark stripe rings around the chest and torso.
	for i, z in ipairs({ -2.5, -1.7, -0.9, -0.1 }) do
		local k = 1 - math.abs(z + 1) * 0.08
		add("Body", "Stripe", Vector3.new(2.66 * k, 2.76 * k, 0.24), C.Navy, CFrame.new(0, 0.12, z), E)
	end
	add("Body", "Spine", Vector3.new(0.5, 0.4, 5.6), C.TealDark, CFrame.new(0, 1.3, -0.6), E)

	-- NECK (pitched up)
	add("Neck", "NeckLow", Vector3.new(1.6, 1.7, 2.4), C.Teal, CFrame.new(0, 0, -0.8), E)
	add("Neck", "NeckHigh", Vector3.new(1.4, 1.5, 2.2), C.Teal, CFrame.new(0, 0, -1.9), E)
	for _, z in ipairs({ -0.5, -1.3, -2.1 }) do
		add("Neck", "Stripe", Vector3.new(1.62, 1.72, 0.2), C.Navy, CFrame.new(0, 0, z), E)
	end

	-- HEAD
	add("Head", "Skull", Vector3.new(2.0, 1.8, 2.6), C.Teal, CFrame.new(0, 0.15, -0.6), E)
	add("Head", "Snout", Vector3.new(1.45, 1.0, 2.7), C.Teal, CFrame.new(0, 0.1, -2.2), E)
	add("Head", "MouthRoof", Vector3.new(0.95, 0.12, 2.1), C.Mouth, CFrame.new(0, -0.32, -1.9))
	add("Head", "Brow", Vector3.new(1.85, 0.35, 0.9), C.TealDark, CFrame.new(0, 0.62, -1.0), E)
	for _, side in ipairs({ -1, 1 }) do
		add("Head", "Eye", Vector3.new(0.18, 0.36, 0.42), C.Eye, CFrame.new(side * 0.78, 0.42, -0.95), E)
		add("Head", "Pupil", Vector3.new(0.1, 0.2, 0.12), C.Pupil, CFrame.new(side * 0.86, 0.43, -1.0), ell({ NoShadow = true }))
		add("Head", "Nostril", Vector3.new(0.12, 0.1, 0.16), C.Navy, CFrame.new(side * 0.32, 0.4, -3.1), ell({ NoShadow = true }))
		add("Head", "Cheek", Vector3.new(0.3, 0.6, 1.2), C.TealDark, CFrame.new(side * 0.7, -0.15, -0.6), E)
		if not lite then
			for k = 0, 5 do
				local tooth = add("Head", "Tooth", Vector3.new(0.1, 0.32, 0.12), C.Teeth, CFrame.new(side * (0.5 - k * 0.04), -0.42, -1.1 - k * 0.36) * CFrame.Angles(0, 0, side * 0.1), { NoShadow = true })
				tooth.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	-- The yellow pin crown fanned around the back of the skull.
	local pins = lite and 4 or 7
	for k = 1, pins do
		local a = -1.25 + (k - 1) / (pins - 1) * 2.5 -- side to side over the top
		local dir = Vector3.new(math.sin(a), math.cos(a), 0.35).Unit
		local base = Vector3.new(0, 0.2, -0.3) + dir * 0.72
		local pinCF = CFrame.lookAt(base + dir * 0.55, base + dir * 2) * CFrame.Angles(0, math.pi / 2, 0)
		add("Head", "CrownPin", Vector3.new(1.1, 0.12, 0.12), C.Gold, pinCF, { Cylinder = true, Material = Enum.Material.Metal })
		add("Head", "CrownBall", Vector3.new(0.3, 0.3, 0.3), C.Yellow, CFrame.new(base + dir * 1.15), { Ball = true, Material = Enum.Material.Metal })
	end

	-- JAW
	add("Jaw", "LowerJaw", Vector3.new(1.35, 0.55, 2.7), C.Teal, CFrame.new(0, -0.12, -1.55), E)
	add("Jaw", "Tongue", Vector3.new(0.7, 0.16, 1.7), C.Tongue, CFrame.new(0, 0.04, -1.3), E)
	add("Jaw", "Throat", Vector3.new(0.9, 0.5, 1.0), C.Pale, CFrame.new(0, -0.25, -0.4), E)
	if not lite then
		for _, side in ipairs({ -1, 1 }) do
			for k = 0, 4 do
				add("Jaw", "Tooth", Vector3.new(0.1, 0.28, 0.12), C.Teeth, CFrame.new(side * (0.42 - k * 0.04), 0.18, -0.95 - k * 0.36), { NoShadow = true })
			end
		end
	end

	-- TAIL (bone i starts at segment i and points backward, +Z)
	for i = 1, TAIL_SEGMENTS do
		local k = (i - 1) / TAIL_SEGMENTS
		local d = 1.95 * (1 - k * 0.85)
		local color = i <= 2 and C.Teal:Lerp(C.Blue, (i - 1) / 2) or C.Blue
		add("Tail" .. i, "Tail", Vector3.new(d, d * 0.92, TAIL_LENGTH * 1.75), color, CFrame.new(0, 0, TAIL_LENGTH / 2), E)
		add("Tail" .. i, "TailBelly", Vector3.new(d * 0.72, d * 0.4, TAIL_LENGTH * 1.7), C.Pale, CFrame.new(0, -d * 0.3, TAIL_LENGTH / 2), E)
		if not lite and i >= 2 and i <= 8 then
			-- Yellow "0101" markings riding on top of the tail.
			local strip = add("Tail" .. i, "Marking", Vector3.new(d * 0.55, 0.05, TAIL_LENGTH), C.Yellow, CFrame.new(0, d * 0.47, TAIL_LENGTH / 2), { NoShadow = true })
			strip.Transparency = 1
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Top
			gui.LightInfluence = 0.3
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 30
			gui.Parent = strip
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.Arcade
			label.TextScaled = true
			label.TextColor3 = C.Yellow
			label.Rotation = 90
			label.Text = (i % 2 == 0) and "0101" or "1010"
			label.Parent = gui
		end
	end

	-- LEGS
	for _, side in ipairs({ -1, 1 }) do
		local s = side > 0 and "R" or "L"
		add("Thigh" .. s, "Thigh", Vector3.new(1.2, 2.4, 1.5), C.Blue, CFrame.new(0, -0.95, 0), E)
		add("Shin" .. s, "Shin", Vector3.new(0.75, 2.3, 0.85), C.Blue, CFrame.new(0, -1.0, 0), E)
		add("Meta" .. s, "Metatarsal", Vector3.new(0.55, 1.4, 0.6), C.BlueDark, CFrame.new(0, -0.6, 0), E)
		for t = -1, 1 do
			add("Foot" .. s, "Toe", Vector3.new(0.28, 0.26, 1.0), C.BlueDark, CFrame.new(t * 0.3, 0.14, -0.45 - math.abs(t) * -0.05) * CFrame.Angles(0, -t * 0.25, 0), E)
			add("Foot" .. s, "ToeClaw", Vector3.new(0.18, 0.34, 0.36), C.Yellow, CFrame.new(t * 0.3 - t * 0.12, 0.12, -1.02) * CFrame.Angles(-0.5, -t * 0.25, 0), { NoShadow = true })
		end
		-- The big curved sickle claw on the second toe.
		add("Foot" .. s, "SickleClaw", Vector3.new(0.16, 0.55, 0.5), C.Yellow, CFrame.new(-side * 0.08, 0.5, -0.15) * CFrame.Angles(0.6, 0, 0), { NoShadow = true })
	end

	-- ARMS
	for _, side in ipairs({ -1, 1 }) do
		local s = side > 0 and "R" or "L"
		add("UpperArm" .. s, "UpperArm", Vector3.new(0.55, 1.3, 0.6), C.Teal, CFrame.new(0, -0.55, 0), E)
		add("Forearm" .. s, "Forearm", Vector3.new(0.45, 1.15, 0.5), C.Teal, CFrame.new(0, -0.5, 0), E)
		for c = -1, 1 do
			add("Forearm" .. s, "Claw", Vector3.new(0.12, 0.55, 0.14), C.Yellow, CFrame.new(c * 0.15, -1.2, -0.12) * CFrame.Angles(0.6, 0, 0), { NoShadow = true })
		end
	end

	-- Blocky (classic Roblox) look: boxes instead of rounded shapes.
	if opts.Blocky ~= false and Blockify.enabled(TuskConfig) then
		Blockify.apply(model)
	end

	local rig = { Model = model, Scale = scale, Entries = entries }

	local function bonesFor(ground, s)
		local sc = scale
		local t = s.Time or 0
		local speed = s.Speed or 0
		local phase = s.Phase or 0
		local lunge = s.Lunge or 0
		local crouch = s.Crouch or 0
		local claw = s.Claw or 0
		local jaw = s.Jaw or 0
		local whip = s.Whip or 0
		local idle = 1 - math.min(speed, 1)
		local breath = math.sin(t * 2.4) * 0.04 * idle
		local bob = math.abs(math.sin(phase)) * 0.18 * speed
		local bones = {}
		local function at(x, y, z)
			return CFrame.new(x * sc, y * sc, z * sc)
		end
		local body = ground * at(0, 4.6 + bob - crouch * 0.9, -0.3 - lunge * 1.3)
			* CFrame.Angles(0.1 - lunge * 0.3 - crouch * 0.12 + breath, whip * 0.5, math.sin(phase) * 0.04 * speed)
		bones.Body = body
		local neck = body * at(0, 0.5, -2.6) * CFrame.Angles(0.8 - lunge * 0.45 + (s.HeadPitch or 0) * 0.5 + breath * 2, (s.HeadYaw or 0) * 0.5, 0)
		bones.Neck = neck
		local head = neck * at(0, 0, -2.5) * CFrame.Angles(-0.85 + lunge * 0.2 + (s.HeadPitch or 0) * 0.5 + jaw * 0.2, (s.HeadYaw or 0) * 0.5, 0)
		bones.Head = head
		bones.Jaw = head * at(0, -0.3, 0.2) * CFrame.Angles(-0.06 - jaw * 0.8, 0, 0)
		-- Tail: sways while idle, swings harder when running, whips on attacks.
		local tail = body * at(0, 0.15, 2.1)
		for i = 1, TAIL_SEGMENTS do
			local k = i / TAIL_SEGMENTS
			local sway = math.sin(t * 2.2 - i * 0.55) * (0.06 + 0.08 * speed) + whip * 0.35 * (1 - k * 0.5)
			local lift = (i == 1 and 0.12 or 0) + (i >= 2 and i <= 4 and 0.04 or 0) + (i >= 6 and -0.12 or 0) - speed * 0.02
			tail = tail * CFrame.Angles(lift, sway, 0)
			bones["Tail" .. i] = tail
			tail = tail * at(0, 0, TAIL_LENGTH * 0.92)
		end
		-- Legs (digitigrade): hip -> knee -> ankle -> toes.
		local flatGround = ground - ground.Position
		for _, side in ipairs({ -1, 1 }) do
			local s2 = side > 0 and "R" or "L"
			local off = side > 0 and 0 or math.pi
			local swing = math.sin(phase + off) * 0.65 * speed
			local liftAmt = math.max(0, math.cos(phase + off)) * speed
			local hip = body * at(side * 0.95, -0.25, 1.0)
			local thigh = hip * CFrame.Angles(math.rad(28) + swing - crouch * 0.55 + lunge * 0.2, 0, side * 0.05)
			bones["Thigh" .. s2] = thigh
			local knee = thigh * at(0, -2.0, 0) * CFrame.Angles(math.rad(-78) - liftAmt * 0.7 - crouch * 0.7, 0, 0)
			bones["Shin" .. s2] = knee
			local ankle = knee * at(0, -2.0, 0) * CFrame.Angles(math.rad(62) + liftAmt * 0.6 + crouch * 0.6, 0, 0)
			bones["Meta" .. s2] = ankle
			local toe = ankle * at(0, -1.2, 0)
			bones["Foot" .. s2] = CFrame.new(toe.Position) * flatGround * CFrame.Angles(liftAmt * 0.5, 0, 0)
		end
		-- Arms: tucked, raking forward on claw attacks.
		for _, side in ipairs({ -1, 1 }) do
			local s2 = side > 0 and "R" or "L"
			local shoulder = body * at(side * 0.95, 0.15, -2.5)
			local upper = shoulder * CFrame.Angles(math.rad(35) + claw * 1.4 + math.sin(phase + (side > 0 and math.pi or 0)) * 0.12 * speed, 0, side * (0.2 + claw * 0.2))
			bones["UpperArm" .. s2] = upper
			bones["Forearm" .. s2] = upper * at(0, -1.1, 0) * CFrame.Angles(math.rad(70) - claw * 0.9, 0, 0)
		end
		return bones
	end

	local parts, cframes = {}, {}
	for i, e in ipairs(entries) do
		parts[i] = e.Part
	end

	function rig:Pose(ground, s)
		local bones = bonesFor(ground, s or {})
		for i, e in ipairs(entries) do
			cframes[i] = bones[e.Bone] * e.Offset
		end
		local ok = pcall(function()
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end)
		if not ok then
			for i, p in ipairs(parts) do
				p.CFrame = cframes[i]
			end
		end
	end

	function rig:SetTransparency(t)
		for _, e in ipairs(entries) do
			if e.Part.Name ~= "Marking" then
				e.Part.Transparency = t
			end
		end
	end

	function rig:Destroy()
		model:Destroy()
	end

	return rig
end

return RaptorModel
```
