--[[
	Joseph_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Joseph Joestar (Part 3): Hermit Purple and Hamon.
	Its other half is Joseph_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: HermitPurpleStand
-- ======================================================================
__modules["HermitPurpleStand"] = function()
--[[
	TuskActVFX.HermitPurpleStand  (StarterPlayerScripts.SpinClient.TuskActVFX.HermitPurpleStand)

	HERMIT PURPLE (Joseph Joestar): not a figure but thorny purple VINES.
	Fixed to Joseph's right side (Attached: no float, no lag): three vines
	spiral up round his right arm, thorns sticking out all along them, and a
	few loose tendrils curl off at the top and bottom. Purple aura.
	Registered by JosephVFX; the vines that lash out in his moves are drawn
	by JosephVFX itself.
]]

local HermitPurpleStand = {}

local VINE = Color3.fromRGB(140, 70, 190)
local VINE_DARK = Color3.fromRGB(96, 40, 140)
local THORN = Color3.fromRGB(196, 150, 236)

HermitPurpleStand.Aura = Color3.fromRGB(170, 100, 230)
HermitPurpleStand.AuraLight = Color3.fromRGB(230, 200, 255)
-- Round his right arm (from the root).
HermitPurpleStand.Offset = CFrame.new(1.5, 0.45, 0)
HermitPurpleStand.Attached = true

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

local function weld(model, parent, name, size, color, cf, material)
	local p = newPart(model, name, size, color, material)
	local w = Instance.new("Weld")
	w.Part0 = parent
	w.Part1 = p
	w.C0 = cf
	w.Parent = p
	p.CFrame = parent.CFrame * cf
	return p
end

-- A vine segment from a to b with a thorn or two.
local function segment(model, body, a, b, d, color, thorns)
	local len = (b - a).Magnitude
	if len < 1e-3 then
		return
	end
	local mid = (a + b) / 2
	local seg = weld(model, body, "Vine", Vector3.new(len + d * 0.5, d, d), color, CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0))
	seg.Shape = Enum.PartType.Cylinder
	if thorns then
		-- A thorn sticking out sideways from the middle.
		local out = (b - a):Cross(Vector3.new(0, 1, 0))
		out = out.Magnitude > 1e-3 and out.Unit or Vector3.new(1, 0, 0)
		local tip = mid + out * d * 1.4
		weld(model, body, "Thorn", Vector3.new(d * 0.35, d * 0.35, d * 1.2), THORN, CFrame.lookAt(mid + out * d * 0.6, tip))
	end
end

function HermitPurpleStand.build(scale)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "HermitPurple"
	local rig = { Joints = {} }
	local body = newPart(model, "Body", Vector3.new(0.3, 0.3, 0.3), VINE)
	body.Transparency = 1
	body.Anchored = true
	body.Massless = false
	body.CFrame = CFrame.new()
	model.PrimaryPart = body
	rig.Body = body

	-- Three vines spiralling up round his arm.
	local d = 0.16 * s
	local height, radius, turns = 2.6 * s, 0.68 * s, 2.2
	for v = 0, 2 do
		local last
		local steps = 22
		for k = 0, steps do
			local f = k / steps
			local a = (v / 3 + f * turns) * math.pi * 2
			local r = radius * (1 + math.sin(f * math.pi * 3 + v) * 0.08)
			local p = Vector3.new(math.cos(a) * r, -height / 2 + f * height, math.sin(a) * r)
			if last then
				segment(model, body, last, p, d, v == 1 and VINE_DARK or VINE, k % 2 == 0)
			end
			last = p
		end
	end
	-- Loose tendrils curling off the top and bottom.
	local tendrils = {
		{ Vector3.new(0.4, 1.3, 0.2), Vector3.new(0.9, 1.9, 0.5), Vector3.new(1.2, 2.3, 0.2), Vector3.new(1.0, 2.6, -0.2) },
		{ Vector3.new(-0.3, 1.3, -0.4), Vector3.new(-0.5, 2.0, -0.9), Vector3.new(-0.2, 2.4, -1.2) },
		{ Vector3.new(0.5, -1.3, -0.3), Vector3.new(0.9, -1.8, -0.8), Vector3.new(0.7, -2.2, -1.2), Vector3.new(0.3, -2.1, -1.4) },
		{ Vector3.new(-0.4, -1.3, 0.4), Vector3.new(-0.9, -1.6, 0.9), Vector3.new(-1.2, -1.3, 1.2) },
	}
	for _, t in ipairs(tendrils) do
		for k = 1, #t - 1 do
			segment(model, body, t[k] * s, t[k + 1] * s, d * (1 - k * 0.15), VINE, true)
		end
		local tip = weld(model, body, "Tip", Vector3.new(d, d, d), THORN, CFrame.new(t[#t] * s))
		tip.Shape = Enum.PartType.Ball
	end
	local point = Instance.new("Attachment")
	point.Name = "NailPoint"
	point.Position = Vector3.new(0, -height / 2, -0.3)
	point.Parent = body
	rig.NailPoint = point
	return model, rig
end

return HermitPurpleStand
end

-- ======================================================================
-- MODULE: JosephVFX
-- ======================================================================
__modules["JosephVFX"] = function()
--[[
	TuskActVFX.JosephVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.JosephVFX)

	Client visuals for Joseph Joestar / HERMIT PURPLE. Blocky.
	  * Hermit Purple (HermitPurpleStand): thorny vines wound round his
	    right arm, with a purple aura
	  * HAMON: golden ripples (rings spreading out) and sparks wherever
	    Hamon goes in
	  * HAMON COMBO: ripples on his fists; "SUNLIGHT YELLOW OVERDRIVE!" on
	    the 4th
	  * HERMIT GRAB: a thorny vine shoots out, wraps the target and drags
	    them in (it stretches with them); a Hamon jolt when they arrive
	  * HAMON VINES: five vines whip out in a fan, Hamon running down them
	  * NIGERUNDAYO!: he turns and sprints (Sandman's sprint cycle), dust
	    kicking up, "NIGERUNDAYO!"
	  * HERMIT WEB OVERDRIVE: vines burst out of the ground and spiral up
	    round everyone near; Hamon pulses down the vines; then a golden
	    "SUNLIGHT YELLOW OVERDRIVE!" blast
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
local HermitPurpleStand = __require("HermitPurpleStand")

local JosephVFX = {}
local ACT = 22
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, HermitPurpleStand.build, { Aura = HermitPurpleStand.Aura, AuraLight = HermitPurpleStand.AuraLight, Offset = HermitPurpleStand.Offset, Attached = HermitPurpleStand.Attached })

local VINE = Color3.fromRGB(140, 70, 190)
local VINE_DARK = Color3.fromRGB(96, 40, 140)
local THORN = Color3.fromRGB(196, 150, 236)
local HAMON = Color3.fromRGB(255, 214, 80)
local HAMON_LIGHT = Color3.fromRGB(255, 246, 190)

local stanced = {}
local webs = {} -- [character] = the ultimate's vines

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function nearLocal(pos, range)
	local r = localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	return r ~= nil and (r.Position - pos).Magnitude <= range
end

local function label(adornee, text, color, duration, size, offset)
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
	t.Font = Enum.Font.Bangers
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

local function handOf(character)
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if hand then
		return hand.Position
	end
	local r = Common.rootOf(character)
	return r and (r.CFrame * CFrame.new(1, 0, -1)).Position or nil
end

-- Hamon: golden rings spreading out round a point, and sparks.
local function ripple(at, size)
	size = size or 1
	for k = 0, 2 do
		task.delay(k * 0.07, function()
			local ring = VFXLib.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 0.4, 0.4), Color = k == 1 and HAMON_LIGHT or HAMON, Transparency = 0.15, CFrame = CFrame.new(at) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, 0) })
			local base = ring.CFrame
			VFXLib.animate(0.3, function(a)
				local d = (0.5 + a * 3.2) * size
				ring.Size = Vector3.new(0.08, d, d)
				ring.CFrame = base
				ring.Transparency = 0.15 + 0.85 * a
			end, function()
				ring:Destroy()
			end)
		end)
	end
	VFXLib.burst(at, { Count = math.floor(6 * size), Color = HAMON, Speed = 10 * size, Lifetime = 0.3 })
end

-- A thorny vine drawn between two points (or functions giving them), made
-- of a few gently-waving segments with thorns.
local function vineBetween(getFrom, getTo, duration, opts)
	opts = opts or {}
	local count = opts.Segments or 8
	local segs, thorns = {}, {}
	for i = 1, count do
		segs[i] = VFXLib.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 0.22, 0.22), Color = i % 3 == 0 and VINE_DARK or VINE, Material = Enum.Material.SmoothPlastic, Transparency = 0 })
		thorns[i] = VFXLib.part({ Size = Vector3.new(0.08, 0.08, 0.3), Color = THORN, Material = Enum.Material.SmoothPlastic, Transparency = 0 })
	end
	local seed = math.random() * 10
	local job = VFXLib.animate(duration, function(a)
		local from = type(getFrom) == "function" and getFrom() or getFrom
		local to = type(getTo) == "function" and getTo() or getTo
		if not from or not to then
			return
		end
		-- Grow out (first 25%), hold, shrink back (last 20%) unless held.
		local reach = opts.Hold and 1 or (a < 0.25 and VFXLib.easeOut(a / 0.25) or (a > 0.8 and 1 - (a - 0.8) / 0.2 or 1))
		local tip = from:Lerp(to, reach)
		local dir = tip - from
		local side = dir:Cross(Vector3.new(0, 1, 0))
		side = side.Magnitude > 1e-3 and side.Unit or Vector3.new(1, 0, 0)
		local last = from
		for i = 1, count do
			local f = i / count
			local wave = math.sin(f * math.pi * 3 + os.clock() * 9 + seed) * 0.35 * math.sin(f * math.pi)
			local p = from:Lerp(tip, f) + side * wave + Vector3.new(0, math.cos(f * 7 + seed) * 0.15, 0)
			local len = (p - last).Magnitude
			if len > 1e-3 then
				local mid = (p + last) / 2
				segs[i].Size = Vector3.new(len + 0.1, 0.22 * (1 - f * 0.35), 0.22 * (1 - f * 0.35))
				segs[i].CFrame = CFrame.lookAt(mid, p) * CFrame.Angles(0, math.pi / 2, 0)
				thorns[i].CFrame = CFrame.lookAt(mid, mid + side * (i % 2 == 0 and 1 or -1) + Vector3.new(0, 0.3, 0)) * CFrame.new(0, 0, -0.18)
			end
			last = p
		end
	end, function()
		for i = 1, count do
			segs[i]:Destroy()
			thorns[i]:Destroy()
		end
	end)
	return job
end

-- Hamon racing down a vine from `from` to `to`.
local function hamonRun(from, to, time)
	local spark = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), Color = HAMON_LIGHT, Transparency = 0.1 })
	VFXLib.animate(time or 0.25, function(a)
		local f = type(from) == "function" and from() or from
		local t = type(to) == "function" and to() or to
		if f and t then
			spark.CFrame = CFrame.new(f:Lerp(t, a))
		end
	end, function()
		spark:Destroy()
		local t = type(to) == "function" and to() or to
		if t then
			ripple(t, 0.8)
		end
	end)
end

local function rootPos(model)
	local r = Common.rootOf(model)
	return r and r.Position or nil
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
	TuskAnimation.play(character, "JO_M1_" .. math.clamp(index, 1, 4))
	VFXLib.sound(sounds.Swing, root, 0.5, 1.0 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Second or pal.Main)
	task.delay(0.08, function()
		local r = Common.rootOf(character)
		if r then
			ripple((r.CFrame * CFrame.new(index % 2 == 0 and -0.7 or 0.7, 0.6, -2.4)).Position, index == 4 and 1.8 or 0.7)
		end
	end)
	if index == 4 then
		label(character:FindFirstChild("Head"), "SUNLIGHT YELLOW OVERDRIVE!", HAMON, 1.4, 360)
	end
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "HermitGrab" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "JOGrab")
			label(character:FindFirstChild("Head"), "HERMIT PURPLE!", VINE, 1.0, 240)
		elseif phase == "Snag" and character and data.Target then
			local target = data.Target
			vineBetween(function()
				return handOf(character)
			end, function()
				return rootPos(target)
			end, (data.PullTime or 0.35) + 0.45, { Segments = 10 })
			-- Coils round them.
			local tr = Common.rootOf(target)
			if tr then
				for k = 0, 2 do
					local coil = VFXLib.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2.4, 2.4), Color = VINE, Material = Enum.Material.SmoothPlastic, Transparency = 0.1 })
					VFXLib.animate((data.PullTime or 0.35) + 0.4, function(a)
						local r2 = Common.rootOf(target)
						if r2 then
							coil.CFrame = CFrame.new(r2.Position + Vector3.new(0, -0.6 + k * 0.6, 0)) * CFrame.Angles(0, os.clock() * 4 + k, math.pi / 2 + 0.2)
						end
						coil.Transparency = a > 0.8 and 0.1 + (a - 0.8) / 0.2 * 0.9 or 0.1
					end, function()
						coil:Destroy()
					end)
				end
			end
		elseif phase == "Shock" and data.Target then
			local p = rootPos(data.Target)
			if p then
				ripple(p, 1.6)
				TuskVFX.CreateImpactStar(p, { Size = 3, Rays = 7, Color = HAMON, Color2 = HAMON_LIGHT, Duration = 0.15 })
			end
			if character and Common.isLocal(character) then
				CameraFX.shake(0.3, 0.2)
			end
		elseif phase == "Miss" and character and data.To then
			vineBetween(function()
				return handOf(character)
			end, data.To, 0.5, { Segments = 10 })
		end
	elseif move == "HamonVines" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "JOLash")
			ripple(handOf(character) or root.Position, 0.8)
		elseif phase == "Lash" and data.From and data.Direction then
			local dir, range, cone = data.Direction, data.Range or 22, math.rad(data.Cone or 70)
			for k = -2, 2 do
				local d = (CFrame.Angles(0, k / 2 * cone / 2, 0) * CFrame.new(Vector3.new(), dir)).LookVector
				local to = data.From + d * range + Vector3.new(0, (math.random() - 0.5) * 2, 0)
				vineBetween(function()
					return handOf(character) or data.From
				end, to, 0.55, { Segments = 8 })
				task.delay(0.12, function()
					hamonRun(function()
						return handOf(character) or data.From
					end, to, 0.18)
				end)
			end
			for _, t in ipairs(data.Hits or {}) do
				task.delay(0.28, function()
					local p = rootPos(t)
					if p then
						ripple(p, 1.3)
					end
				end)
			end
			VFXLib.sound(sounds.Swing, data.From, 0.6, 0.8)
		end
	elseif move == "Nigerundayo" and phase == "Run" and character and root then
		label(character:FindFirstChild("Head"), "NIGERUNDAYO!", Color3.new(1, 1, 1), 1.6, 300)
		if TuskAnimation.sprint then
			TuskAnimation.sprint(character, true)
			task.delay(data.Time or 3.5, function()
				TuskAnimation.sprint(character, false)
			end)
		end
		VFXLib.burst(root.Position - Vector3.new(0, 2.5, 0), { Count = 14, Color = Color3.fromRGB(220, 200, 160), Speed = 12, Lifetime = 0.5 })
		if Common.isLocal(character) then
			CameraFX.speedLines(0.6, Color3.new(1, 1, 1))
			CameraFX.fovPunch(10, 0.5)
		end
	end
end

---------------------------------------------------------------------------
-- HERMIT WEB OVERDRIVE
---------------------------------------------------------------------------
local function clearWeb(character)
	local w = webs[character]
	webs[character] = nil
	if w then
		for _, job in ipairs(w.Jobs) do
			VFXLib.cancel(job)
		end
		for _, p in ipairs(w.Parts) do
			p:Destroy()
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character and root then
		TuskAnimation.play(character, "JOWeb")
		label(character:FindFirstChild("Head"), "HERMIT PURPLE!", VINE, 1.6, 300)
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.1)
	elseif data.Phase == "Bind" and character and data.Position then
		clearWeb(character)
		local w = { Jobs = {}, Parts = {} }
		webs[character] = w
		local time = (data.Time or 2.4) + 0.4
		-- Vines burst out of the ground in a ring round him.
		VFXLib.burst(data.Position - Vector3.new(0, 2.5, 0), { Count = 24, Color = VINE, Speed = 20, Lifetime = 0.5 })
		for _, target in ipairs(data.Targets or {}) do
			-- A vine from Joseph to them, and one spiralling up round them.
			table.insert(w.Jobs, vineBetween(function()
				return handOf(character)
			end, function()
				return rootPos(target)
			end, time, { Segments = 10, Hold = true }))
			local tr = Common.rootOf(target)
			if tr then
				local base = tr.Position - Vector3.new(0, 2.6, 0)
				for k = 1, 10 do
					local seg = VFXLib.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 0.24, 0.24), Color = k % 3 == 0 and VINE_DARK or VINE, Material = Enum.Material.SmoothPlastic, Transparency = 1 })
					table.insert(w.Parts, seg)
					table.insert(w.Jobs, VFXLib.animate(time, function(a)
						local grow = math.min(a * time / 0.4, 1)
						local f = k / 10
						if f > grow then
							seg.Transparency = 1
							return
						end
						local ang = f * math.pi * 5
						local p = base + Vector3.new(math.cos(ang) * 1.3, f * 5, math.sin(ang) * 1.3)
						local q = base + Vector3.new(math.cos(ang + 0.6) * 1.3, (f + 0.1) * 5, math.sin(ang + 0.6) * 1.3)
						seg.CFrame = CFrame.lookAt((p + q) / 2, q) * CFrame.Angles(0, math.pi / 2, 0)
						seg.Transparency = 0
					end))
				end
			end
		end
		if Common.isLocal(character) then
			CameraFX.shake(0.4, 0.3)
		end
	elseif data.Phase == "Pulse" and character then
		for _, target in ipairs(data.Targets or {}) do
			hamonRun(function()
				return handOf(character)
			end, function()
				return rootPos(target)
			end, 0.2)
		end
	elseif data.Phase == "Blast" and character then
		clearWeb(character)
		label(character:FindFirstChild("Head"), "SUNLIGHT YELLOW OVERDRIVE!", HAMON, 2.0, 400)
		if data.Position then
			TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position - Vector3.new(0, 2.5, 0)), { Radius = (data.Radius or 24) * 0.9, Layers = 3, Color = HAMON, Color2 = VINE, Ground = true, Particles = 2, Width = 0.6 })
			VFXLib.flash(data.Position, HAMON, 8, 40, 0.3)
			if nearLocal(data.Position, 60) then
				CameraFX.shake(0.9, 0.45)
				CameraFX.impactFrame(HAMON_LIGHT)
			end
		end
		for _, t in ipairs(data.Targets or {}) do
			local p = rootPos(t)
			if p then
				ripple(p, 2)
			end
		end
		VFXLib.sound(sounds.AwakeningBurst or sounds.Swing, data.Position or Vector3.new(), 0.8, 1.0)
	elseif data.Phase == "End" and character then
		clearWeb(character)
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
				TuskAnimation.hold(character, "JOStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "JOStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function JosephVFX.handle(name, data)
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
function JosephVFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
	end
end

return JosephVFX
end
end
