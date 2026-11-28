--[[
	JohnnyArmCutscene  (StarterPlayerScripts.SpinClient.JohnnyArmCutscene)

	TUSK ACT 1: FIRST APPEARANCE. When YOU, playing Johnny, pick up the
	Saint's Corpse LEFT ARM, a cutscene follows the user's anime clip shot
	for shot (13.4 s, skippable; TuskConfig.Cutscenes.JohnnyArm). Johnny sits
	on the ground (his legs out in front, his left forearm across his lap),
	and a SMALL Tusk (forearm-sized, as in the anime: the real Tusk Act 1
	model, built small just for this) is animated by hand:
	  1. close above his forearm, a green glow behind: light slices along it
	     and Tusk climbs up OUT OF HIS ARM, legs kicking (the heart feet),
	     ears and arms flapping, face up to us
	  2. from Johnny's eyes: Tusk floating over his lap, wobbling and
	     drifting closer, a burst of teal light behind it
	  3. over Tusk's back (right up at his face): Johnny's eyes go wide
	  4. close: Tusk turns and pokes its golden nail at his cheek; he winces,
	     eyes squeezed shut, sweating
	  5. Tusk's face, close, in a pink haze, its head tilting:
	     "TUSK ACT 1 · FIRST APPEARANCE"
	Johnny's own animations: TuskAnimation "JohnnyFirstTusk" (sit, look
	up, shock, wince). His normal Stand is hidden while it plays. Everything
	it adds is local to you and removed when it ends or is skipped. It won't
	replay within 20 s.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local Net = require(Shared.Net)
local TuskStandModels = require(Shared.TuskStandModels)
local VFXLib = require(script.Parent.VFXLib)
local CameraFX = require(script.Parent.CameraFX)
local TuskStand = require(script.Parent.TuskStand)
local TuskAnimation = require(script.Parent.TuskAnimation)
local Cutscenes = require(script.Parent.Cutscenes)

local JohnnyArmCutscene = {}
local player = Players.LocalPlayer
local last -- os.clock() of the last one (nil: never)

local TEAL = Color3.fromRGB(80, 230, 210)
local GREEN = Color3.fromRGB(60, 210, 120)
local PINK = Color3.fromRGB(255, 150, 210)
local PURPLE = Color3.fromRGB(150, 90, 220)

-- Shot lengths (the clip's 4.0 / 5.4 / 4.6 / 2.6 / 3.7 s, tightened).
local T = { 3.0, 3.2, 2.8, 1.8, 2.6 }
local TUSK_SCALE = 0.4 -- about forearm-sized, as in the anime

local function newPart(holder, name, size, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = holder
	return p
end

local function weldOn(parent, holder, name, size, color, cf, material, ellipse)
	local p = newPart(holder, name, size, color, material)
	p.Anchored = false
	p.Massless = true
	if ellipse then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	p.CFrame = parent.CFrame * cf
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent
	w.Part1 = p
	w.Parent = p
	return p
end

-- Light slicing along his forearm as Tusk tears out of it.
local function armSlices(arm, time)
	local nextAt = 0
	VFXLib.animate(time, function()
		local c = os.clock()
		if c < nextAt or not arm.Parent then
			return
		end
		nextAt = c + 0.05
		local along = (math.random() - 0.5) * arm.Size.Y
		local from = (arm.CFrame * CFrame.new(0, along, 0)).Position
		local dir = (arm.CFrame.RightVector * (math.random() - 0.5) + Vector3.new(0, 1, 0) * (0.4 + math.random()) + arm.CFrame.LookVector * (math.random() - 0.5)).Unit
		local len = 0.8 + math.random() * 1.6
		local s = newPart(VFXLib.Folder, "Slice", Vector3.new(0.04, 0.04, len), math.random() < 0.6 and Color3.new(1, 1, 1) or TEAL, Enum.Material.Neon, 0.1)
		VFXLib.animate(0.22, function(x)
			s.CFrame = CFrame.lookAt(from + dir * (len / 2 + x * 1.2), from + dir * (len + x * 1.2))
			s.Transparency = 0.1 + 0.9 * x
		end, function()
			s:Destroy()
		end)
	end)
end

-- A soft glow of colour (puffs) round a point, for the backgrounds.
local function haze(getAt, color, count, spread, time, size)
	for _ = 1, count do
		local off = Vector3.new((math.random() - 0.5) * spread, (math.random() - 0.5) * spread * 0.5, (math.random() - 0.5) * spread)
		local puff = newPart(VFXLib.Folder, "Haze", Vector3.new(1, 1, 1) * (size or 1.2) * (0.6 + math.random() * 0.8), color, Enum.Material.Neon, 1)
		puff.Shape = Enum.PartType.Ball
		local drift = Vector3.new((math.random() - 0.5) * 0.6, 0.3 + math.random() * 0.4, (math.random() - 0.5) * 0.6)
		VFXLib.animate(time, function(x)
			puff.CFrame = CFrame.new(getAt() + off + drift * x)
			puff.Transparency = 0.8 + 0.2 * math.abs(x - 0.5) * 2
		end, function()
			puff:Destroy()
		end)
	end
end

-- A burst of teal light behind something (a glowing disc and rays).
local function lightBurst(getAt, getFace, time)
	local disc = newPart(VFXLib.Folder, "Burst", Vector3.new(0.05, 3, 3), TEAL, Enum.Material.Neon, 1)
	disc.Shape = Enum.PartType.Cylinder
	local rays = {}
	for k = 1, 12 do
		rays[k] = newPart(VFXLib.Folder, "Ray", Vector3.new(0.06, 0.06, 2.4), Color3.fromRGB(220, 255, 250), Enum.Material.Neon, 1)
	end
	VFXLib.animate(time, function(a)
		local at, face = getAt(), getFace()
		local base = CFrame.lookAt(at, face)
		local swell = a < 0.2 and a / 0.2 or (a > 0.85 and (1 - a) / 0.15 or 1)
		disc.Size = Vector3.new(0.05, 2 + 1.6 * swell, 2 + 1.6 * swell)
		disc.CFrame = base * CFrame.Angles(0, math.pi / 2, 0)
		disc.Transparency = 1 - 0.55 * swell
		for k, r in ipairs(rays) do
			local ang = k / 12 * math.pi * 2 + a * 0.6
			r.CFrame = base * CFrame.Angles(0, 0, ang) * CFrame.new(0, 1.8, 0.05) * CFrame.Angles(math.pi / 2, 0, 0)
			r.Transparency = 1 - 0.5 * swell * (0.5 + 0.5 * math.sin(os.clock() * 8 + k))
		end
	end, function()
		disc:Destroy()
		for _, r in ipairs(rays) do
			r:Destroy()
		end
	end)
end

-- Johnny's face: wide teal eyes and an open mouth, or (wincing) eyes
-- squeezed shut; sweat running down.
local function shockFace(character)
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local s = head.Size.Y / 1.2
	local f = -head.Size.Z / 2 - 0.02 * s
	local holder = Instance.new("Model")
	holder.Name = "JohnnyShock"
	local open, shut = {}, {}
	for _, side in ipairs({ -1, 1 }) do
		table.insert(open, weldOn(head, holder, "EyeWhite", Vector3.new(0.24, 0.22, 0.04) * s, Color3.new(1, 1, 1), CFrame.new(side * 0.21 * s, 0.08 * s, f), nil, true))
		table.insert(open, weldOn(head, holder, "Iris", Vector3.new(0.1, 0.1, 0.045) * s, Color3.fromRGB(70, 220, 210), CFrame.new(side * 0.21 * s, 0.08 * s, f - 0.006 * s), Enum.Material.Neon, true))
		table.insert(open, weldOn(head, holder, "Pupil", Vector3.new(0.035, 0.035, 0.05) * s, Color3.fromRGB(10, 20, 30), CFrame.new(side * 0.21 * s, 0.08 * s, f - 0.01 * s), nil, true))
		-- Squeezed shut: two creased lines.
		for k = -1, 1, 2 do
			local line = weldOn(head, holder, "Shut", Vector3.new(0.2, 0.025, 0.04) * s, Color3.fromRGB(30, 26, 34), CFrame.new(side * 0.21 * s, 0.08 * s + k * 0.02 * s, f - 0.004 * s) * CFrame.Angles(0, 0, side * k * 0.25))
			line.Transparency = 1
			table.insert(shut, line)
		end
	end
	weldOn(head, holder, "Mouth", Vector3.new(0.22, 0.14, 0.04) * s, Color3.fromRGB(40, 20, 30), CFrame.new(0.04 * s, -0.3 * s, f), nil, true)
	weldOn(head, holder, "Teeth", Vector3.new(0.18, 0.04, 0.045) * s, Color3.fromRGB(110, 230, 220), CFrame.new(0.04 * s, -0.25 * s, f - 0.004 * s))
	holder.Parent = VFXLib.Folder
	local ctl = { Holder = holder }
	function ctl.wince(on)
		for _, p in ipairs(open) do
			p.Transparency = on and 1 or 0
		end
		for _, p in ipairs(shut) do
			p.Transparency = on and 0 or 1
		end
	end
	function ctl.sweat(time)
		local nextDrop = 0
		VFXLib.animate(time, function()
			local c = os.clock()
			if c < nextDrop or not head.Parent or not holder.Parent then
				return
			end
			nextDrop = c + 0.3
			local side = math.random() < 0.5 and -1 or 1
			local from = (head.CFrame * CFrame.new(side * 0.45 * s, 0.25 * s, f + 0.1 * s)).Position
			local drop = newPart(VFXLib.Folder, "Sweat", Vector3.new(0.07, 0.11, 0.07) * s, Color3.fromRGB(190, 230, 255), Enum.Material.Glass, 0.2)
			VFXLib.animate(0.8, function(x)
				drop.CFrame = CFrame.new(from + Vector3.new(0, -0.6 * s * x, 0))
				drop.Transparency = 0.2 + 0.8 * x * x
			end, function()
				drop:Destroy()
			end)
		end)
	end
	return ctl
end

-- The small Tusk for the cutscene: the real Act 1 model, built small, posed
-- and animated here (ears, arms, legs, head) every frame.
local function makeTusk()
	local ok, model, rig = pcall(TuskStandModels.build, 1, TUSK_SCALE)
	if not ok or not model then
		return nil
	end
	local body = rig and rig.Body or model.PrimaryPart
	if not body then
		model:Destroy()
		return nil
	end
	body.Anchored = true
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
	model.Parent = VFXLib.Folder
	local tusk = { Model = model, Rig = rig or { Joints = {} }, Body = body }
	-- mood: how wildly it moves (1 = climbing out, 0 = calm).
	function tusk.pose(cf, mood, headTurn)
		model:PivotTo(cf)
		local t = os.clock()
		local j = tusk.Rig.Joints or {}
		local flap = math.sin(t * (6 + 10 * mood)) * (0.15 + 0.35 * mood)
		if j.EarL and j.EarR then
			j.EarL.Weld.C0 = j.EarL.Base * CFrame.Angles(0, 0, flap) * (j.EarL.Offset or CFrame.new())
			j.EarR.Weld.C0 = j.EarR.Base * CFrame.Angles(0, 0, -flap) * (j.EarR.Offset or CFrame.new())
		end
		if j.ArmL and j.ArmR then
			local wave = math.sin(t * (5 + 9 * mood)) * (0.25 + 0.6 * mood)
			j.ArmL.Weld.C0 = j.ArmL.Base * CFrame.Angles(wave, 0, 0.3 * mood) * (j.ArmL.Offset or CFrame.new())
			j.ArmR.Weld.C0 = j.ArmR.Base * CFrame.Angles(-wave, 0, -0.3 * mood) * (j.ArmR.Offset or CFrame.new())
		end
		for i = 1, 4 do
			local leg = j["Leg" .. i]
			if leg then
				-- Kicking (the little heart feet), faster while it struggles out.
				local kick = math.sin(t * (6 + 12 * mood) + i * 1.6) * (0.3 + 0.6 * mood)
				leg.Weld.C0 = leg.Base * CFrame.Angles(kick, 0, math.sin(t * 3 + i) * 0.12) * (leg.Offset or CFrame.new())
			end
		end
		if j.Head then
			j.Head.Weld.C0 = j.Head.Base * CFrame.Angles(0, headTurn or 0, math.sin(t * 1.6) * 0.12) * (j.Head.Offset or CFrame.new())
		end
	end
	return tusk
end

-- Hide (or show again) the real Stand on this screen.
local function hideRealStand(character, hidden)
	local stand = TuskStand.get(character)
	if stand and stand.Model then
		for _, d in ipairs(stand.Model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = hidden and 1 or 0
			end
		end
	end
end

-- The colour, shot by shot: dark with green, bright teal, violet, violet,
-- pink haze.
local GRADES = {
	{ Tint = Color3.fromRGB(150, 220, 190), Brightness = -0.12, Saturation = 0.15, Contrast = 0.2 },
	{ Tint = Color3.fromRGB(170, 255, 240), Brightness = 0.05, Saturation = 0.3, Contrast = 0.15 },
	{ Tint = Color3.fromRGB(190, 160, 255), Brightness = -0.02, Saturation = 0.2, Contrast = 0.2 },
	{ Tint = Color3.fromRGB(200, 170, 255), Brightness = 0, Saturation = 0.2, Contrast = 0.2 },
	{ Tint = Color3.fromRGB(255, 190, 230), Brightness = 0.08, Saturation = 0.2, Contrast = 0.1 },
}

function JohnnyArmCutscene.play(character)
	local cc = TuskConfig.Cutscenes or {}
	if cc.Enabled == false or cc.JohnnyArm == false or (last and os.clock() - last < 20) then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	local arm = character:FindFirstChild("LeftLowerArm") or character:FindFirstChild("Left Arm")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not root or not head or not arm then
		return false
	end
	last = os.clock()
	local up = Vector3.new(0, 1, 0)
	local starts, acc = {}, 0
	for i, d in ipairs(T) do
		starts[i] = acc
		acc = acc + d
	end
	local function fwd()
		return root.CFrame.LookVector
	end
	local function right()
		return root.CFrame.RightVector
	end
	local function headAt()
		return head.Parent and head.Position or root.Position + up * 1.5
	end
	local function armAt()
		return arm.Parent and arm.Position or root.Position
	end
	local function chestAt()
		return torso and torso.Parent and torso.Position or root.Position + up * 0.5
	end
	local function cheekAt()
		return (head.CFrame * CFrame.new(-head.Size.X * 0.45, -0.1, -head.Size.Z * 0.35)).Position
	end
	local t0 -- (set when it starts)
	local function now()
		return t0 and os.clock() - t0 or 0
	end
	-- Where Tusk is, shot by shot (each shot cuts, as the anime does).
	local function tuskCF()
		local t = now()
		if t < starts[2] then
			-- 1. Climbing up out of his forearm, face up to the camera.
			local k = math.clamp((t - 0.3) / 1.9, 0, 1)
			local e = 1 - (1 - k) * (1 - k)
			local base = armAt() + up * (-0.25 + 0.95 * e)
			local cam = armAt() + fwd() * 1.0 + up * 2.4
			return CFrame.lookAt(base, cam) * CFrame.Angles(0, 0, math.sin(t * 9) * 0.12 * (1 - e)), 1 - 0.6 * e, 0
		elseif t < starts[3] then
			-- 2. Floating over his lap, drifting closer, wobbling.
			local k = (t - starts[2]) / T[2]
			local p = chestAt() + fwd() * (1.5 - 0.35 * k) + up * (0.15 + math.sin(t * 2.4) * 0.08)
			return CFrame.lookAt(p, headAt()) * CFrame.Angles(0, 0, math.sin(t * 1.8) * 0.15), 0.25, 0
		elseif t < starts[4] then
			-- 3. Right up at his face.
			local p = headAt() + fwd() * 1.05 - up * 0.45 + Vector3.new(0, math.sin(t * 2.2) * 0.05, 0)
			return CFrame.lookAt(p, headAt()), 0.2, 0
		elseif t < starts[5] then
			-- 4. By his cheek, poking its nail at it (two little jabs).
			local k = (t - starts[4]) / T[4]
			local jab = math.max(0, math.sin(k * math.pi * 4)) * 0.18
			local away = (headAt() + fwd() * 0.75 - right() * 0.45)
			local p = away:Lerp(cheekAt(), 0.35 + jab)
			return CFrame.lookAt(p, cheekAt()), 0.35, 0
		end
		-- 5. In front of his face, head tilting.
		local p = headAt() + fwd() * 1.6 - up * 0.2
		return CFrame.lookAt(p, headAt()) * CFrame.Angles(0, 0, math.sin(now() * 1.4) * 0.18), 0.15, math.sin(now() * 1.1) * 0.25
	end
	JohnnyArmCutscene.tuskCF = tuskCF
	local function tuskAt()
		local cf = tuskCF()
		return cf.Position
	end
	local shots = {
		-- 1. Close above his forearm.
		{ From = function()
			return root.Parent and CFrame.lookAt(armAt() + fwd() * 1.1 + up * 2.3 - right() * 0.2, armAt() + fwd() * 0.15 + up * 0.1) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(armAt() + fwd() * 1.0 + up * 2.4 - right() * 0.15, armAt() + fwd() * 0.1 + up * 0.5) or nil
		end, Time = T[1], FOV = { 44, 42 } },
		-- 2. From his eyes, down at Tusk over his lap.
		{ From = function()
			return root.Parent and CFrame.lookAt(headAt() + fwd() * 0.2, tuskAt()) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(headAt() + fwd() * 0.35 - up * 0.05, tuskAt()) or nil
		end, Time = T[2], FOV = { 50, 46 } },
		-- 3. Over Tusk's back at his face.
		{ From = function()
			local p = tuskAt()
			return root.Parent and CFrame.lookAt(p + (p - headAt()).Unit * 1.3 + up * 0.55 + right() * 0.55, headAt() - right() * 0.15) or nil
		end, To = function()
			local p = tuskAt()
			return root.Parent and CFrame.lookAt(p + (p - headAt()).Unit * 1.15 + up * 0.5 + right() * 0.5, headAt() - right() * 0.15) or nil
		end, Time = T[3], FOV = { 46, 44 }, Linear = true },
		-- 4. Close: the nail at his cheek.
		{ From = function()
			local mid = tuskAt():Lerp(cheekAt(), 0.5)
			return root.Parent and CFrame.lookAt(headAt() + fwd() * 2.0 - right() * 1.5 + up * 0.15, mid + right() * 0.5) or nil
		end, To = function()
			local mid = tuskAt():Lerp(cheekAt(), 0.5)
			return root.Parent and CFrame.lookAt(headAt() + fwd() * 1.8 - right() * 1.35 + up * 0.12, mid + right() * 0.5) or nil
		end, Time = T[4], FOV = { 42, 40 }, Linear = true },
		-- 5. Tusk's face close, in a pink haze.
		{ From = function()
			return root.Parent and CFrame.lookAt(headAt() + fwd() * 0.1 - up * 0.15, tuskAt() + up * 0.1) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(headAt() + fwd() * 0.35 - up * 0.17, tuskAt() + up * 0.1) or nil
		end, Time = T[5], FOV = { 50, 44 }, Title = "TUSK ACT 1", Subtitle = "FIRST APPEARANCE", Color = PINK },
	}
	local ended = false
	local made = {}
	local look = Instance.new("ColorCorrectionEffect")
	look.Name = "TuskFirstAppearance"
	-- (Fades in from dark, like the clip's first frame.)
	look.TintColor = GRADES[1].Tint
	look.Brightness = -0.5
	look.Saturation = 0
	look.Contrast = 0
	look.Parent = game:GetService("Lighting")
	table.insert(made, look)
	local tusk = makeTusk()
	if tusk then
		table.insert(made, tusk.Model)
	end
	local face
	local function cleanup()
		ended = true
		for _, thing in ipairs(made) do
			if thing and thing.Parent then
				thing:Destroy()
			end
		end
		if face and face.Holder.Parent then
			face.Holder:Destroy()
		end
		hideRealStand(character, false)
		TuskAnimation.play(character, "JohnnyStandUp")
	end
	local started = Cutscenes.play(shots, { Priority = 3, Skippable = true, OnEnd = cleanup })
	if not started then
		cleanup()
		return false
	end
	t0 = os.clock()
	TuskAnimation.play(character, "JohnnyFirstTusk")
	-- Every frame: the small Tusk, the grade, and the real Stand kept hidden.
	VFXLib.animate(acc + 0.3, function()
		if ended then
			return
		end
		hideRealStand(character, true)
		if tusk and root.Parent then
			local cf, mood, turn = tuskCF()
			tusk.pose(cf, mood, turn)
		end
		local shot = 1
		for k = #starts, 1, -1 do
			if now() >= starts[k] then
				shot = k
				break
			end
		end
		local g = GRADES[shot]
		look.TintColor = look.TintColor:Lerp(g.Tint, 0.12)
		look.Brightness = look.Brightness + (g.Brightness - look.Brightness) * 0.12
		look.Saturation = look.Saturation + (g.Saturation - look.Saturation) * 0.12
		look.Contrast = look.Contrast + (g.Contrast - look.Contrast) * 0.12
	end)
	local function at(time, fn)
		task.delay(time, function()
			if not ended then
				fn()
			end
		end)
	end
	-- 1. A green glow behind; light slicing along his arm as Tusk tears out.
	haze(function()
		return armAt() - fwd() * 1.2 - up * 0.6
	end, GREEN, 10, 3, T[1], 1.4)
	at(0.2, function()
		armSlices(arm, 2.2)
		CameraFX.shake(0.25, 0.6)
	end)
	-- 2. Teal light bursting behind Tusk.
	at(starts[2], function()
		lightBurst(function()
			return tuskAt() - (headAt() - tuskAt()).Unit * 0.8
		end, headAt, T[2])
	end)
	-- 3-5. Johnny's face: shock, then the wince at the poke.
	at(starts[3], function()
		face = shockFace(character)
		if face then
			face.sweat(T[3] + T[4] + T[5])
		end
		haze(tuskAt, PURPLE, 8, 1.6, T[3] + T[4], 0.8)
	end)
	at(starts[4], function()
		if face then
			face.wince(true)
		end
		-- A glint off the nail.
		local glint = newPart(VFXLib.Folder, "Glint", Vector3.new(0.05, 0.05, 0.6), Color3.new(1, 1, 1), Enum.Material.Neon, 0.1)
		VFXLib.animate(0.3, function(x)
			glint.CFrame = CFrame.lookAt(cheekAt() - fwd() * 0.1, cheekAt() - fwd() * 0.1 + Vector3.new(1, 1, 0)) * CFrame.Angles(0, 0, x * 3)
			glint.Transparency = 0.1 + 0.9 * x
		end, function()
			glint:Destroy()
		end)
	end)
	at(starts[5], function()
		if face then
			face.wince(false)
		end
		haze(tuskAt, PINK, 14, 2.2, T[5], 0.9)
	end)
	return true
end

-- Johnny = Tusk Acts 1-4.
local function playingJohnny(character)
	local act = character and character:GetAttribute("TuskAct")
	return act ~= nil and Registry.characterOf(act) == "Johnny"
end

function JohnnyArmCutscene.init()
	Net.get("WorldFX").OnClientEvent:Connect(function(name, data)
		if name ~= "CorpseTaken" or typeof(data) ~= "table" then
			return
		end
		local character = player and player.Character
		if data.Player == (player and player.UserId) and data.Part == "LeftArm" and playingJohnny(character) then
			JohnnyArmCutscene.play(character)
		end
	end)
end

return JohnnyArmCutscene
