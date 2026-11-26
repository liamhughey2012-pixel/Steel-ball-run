--[[
	Polnareff_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Jean Pierre Polnareff (Part 3): Silver Chariot.
	Its other half is Polnareff_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: PolnareffVFX
-- ======================================================================
__modules["PolnareffVFX"] = function()
--[[
	TuskActVFX.PolnareffVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.PolnareffVFX)

	Client visuals for Jean Pierre Polnareff / SILVER CHARIOT. Blocky.
	  * Silver Chariot (SilverChariotStand), a silver knight with a rapier,
	    floats behind him with a pale silver-blue aura
	  * RAPIER COMBO: bright thrust streaks; "HORA!" on the 4th
	  * HORA HORA RUSH: dozens of thrust streaks stabbing the space in front
	    of him, "HORA HORA" spilling out, a final thrust and a shockwave
	  * ARMOR OFF: the armour plates burst off and fly away; while it's off
	    he leaves silver afterimages as he moves
	  * RAPIER SHOT: the blade flies out like a bullet, a streak behind it
	  * AFTERIMAGE STORM: a ring of see-through Silver Chariots round the
	    target, circling and stabbing in; then they all thrust at once
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
local SilverChariotStand = __require("SilverChariotStand")

local PolnareffVFX = {}
local ACT = 23
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, SilverChariotStand.build, { Aura = SilverChariotStand.Aura, AuraLight = SilverChariotStand.AuraLight, Offset = SilverChariotStand.Offset })

local SILVER = Color3.fromRGB(210, 218, 232)
local BLADE = Color3.fromRGB(240, 246, 255)
local BLUE = Color3.fromRGB(120, 180, 240)

local stanced = {}
local rushes = {}
local storms = {}
local trailNext = {}

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

local function word(at, text, color, big)
	local anchor = VFXLib.part({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(at), Transparency = 1 })
	label(anchor, text, color or SILVER, big and 1.0 or 0.5, big and 260 or 120, Vector3.new((math.random() - 0.5) * 3, math.random() * 2, 0))
	task.delay(1.1, function()
		anchor:Destroy()
	end)
end

-- A rapier thrust: a bright thin streak shooting forward and fading.
local function thrust(from, dir, length, width)
	length, width = length or 5, width or 0.12
	local line = VFXLib.part({ Size = Vector3.new(width, width, 0.5), Color = BLADE, Transparency = 0 })
	local glow = VFXLib.part({ Size = Vector3.new(width * 3, width * 3, 0.5), Color = BLUE, Transparency = 0.6 })
	VFXLib.animate(0.12, function(a)
		local l = math.max(length * math.min(a * 2.5, 1), 0.3)
		local cf = CFrame.lookAt(from + dir * (l / 2), from + dir * l)
		line.Size = Vector3.new(width * (1 - a * 0.6), width * (1 - a * 0.6), l)
		line.CFrame = cf
		glow.Size = Vector3.new(width * 3, width * 3, l)
		glow.CFrame = cf
		line.Transparency = a > 0.6 and (a - 0.6) / 0.4 or 0
		glow.Transparency = 0.6 + 0.4 * a
	end, function()
		line:Destroy()
		glow:Destroy()
	end)
end

-- A see-through silver copy of a character's pose (afterimage).
local function afterimage(character, color)
	local parts = {}
	for _, d in ipairs(character:GetChildren()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
			table.insert(parts, VFXLib.part({ Size = d.Size, CFrame = d.CFrame, Color = color or SILVER, Material = Enum.Material.Neon, Transparency = 0.6 }))
		end
	end
	VFXLib.animate(0.35, function(a)
		for _, p in ipairs(parts) do
			p.Transparency = 0.6 + 0.4 * a
		end
	end, function()
		for _, p in ipairs(parts) do
			p:Destroy()
		end
	end)
end

-- A see-through Silver Chariot (blocky silhouette with a rapier), facing `look`.
local function chariotGhost()
	local g = {}
	local function add(size, offset)
		table.insert(g, { Part = VFXLib.part({ Size = size, Color = SILVER, Material = Enum.Material.Neon, Transparency = 0.45 }), Offset = offset })
	end
	add(Vector3.new(1.6, 1.6, 0.9), CFrame.new(0, 0, 0))
	add(Vector3.new(0.7, 0.8, 0.7), CFrame.new(0, 1.3, 0))
	add(Vector3.new(0.12, 0.6, 0.6), CFrame.new(0, 1.85, 0.2))
	add(Vector3.new(0.5, 1.8, 0.5), CFrame.new(-1.05, -0.3, 0))
	add(Vector3.new(0.5, 1.8, 0.5), CFrame.new(1.05, -0.1, -0.5) * CFrame.Angles(math.rad(70), 0, 0))
	add(Vector3.new(0.6, 2.0, 0.6), CFrame.new(-0.4, -1.9, 0))
	add(Vector3.new(0.6, 2.0, 0.6), CFrame.new(0.4, -1.9, 0))
	add(Vector3.new(0.08, 0.08, 3.6), CFrame.new(1.05, 0.4, -2.6))
	return g
end

local function placeGhost(g, cf, t)
	for _, p in ipairs(g) do
		p.Part.CFrame = cf * p.Offset
		p.Part.Transparency = t
	end
end

local function dropGhost(g)
	for _, p in ipairs(g) do
		p.Part:Destroy()
	end
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
	TuskAnimation.play(character, "PN_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.6 or 0.6, 0.8, -3.4), Duration = 0.24 })
	VFXLib.sound(sounds.Swing, root, 0.45, 1.3 + index * 0.05)
	task.delay(0.05, function()
		local r = Common.rootOf(character)
		if r then
			local from = (r.CFrame * CFrame.new((math.random() - 0.5) * 1.2, 0.5 + (math.random() - 0.5) * 0.8, -1.5)).Position
			thrust(from, r.CFrame.LookVector, index == 4 and 9 or 6, index == 4 and 0.2 or 0.12)
		end
	end)
	if index == 4 then
		word((root.CFrame * CFrame.new(0, 2, -3)).Position, "HORA!", SILVER, true)
	end
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function rush(character, duration)
	local token = {}
	rushes[character] = token
	TuskAnimation.play(character, "PNRush")
	TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 0.8, -3.8), Duration = duration })
	local start = os.clock()
	local nextThrust, nextWord = 0, 0
	VFXLib.animate(duration, function()
		local r = Common.rootOf(character)
		if rushes[character] ~= token or not r then
			return
		end
		local t = os.clock() - start
		if t >= nextThrust then
			nextThrust = t + 0.02
			local from = (r.CFrame * CFrame.new((math.random() - 0.5) * 3, 0.4 + (math.random() - 0.5) * 2.6, -1.5)).Position
			local dir = (r.CFrame * CFrame.Angles((math.random() - 0.5) * 0.2, (math.random() - 0.5) * 0.3, 0)).LookVector
			thrust(from, dir, 6 + math.random() * 3, 0.1)
		end
		if t >= nextWord then
			nextWord = t + 0.18
			word((r.CFrame * CFrame.new((math.random() - 0.5) * 4, 2 + math.random(), -3)).Position, "HORA", SILVER, false)
		end
	end, function()
		if rushes[character] == token then
			rushes[character] = nil
		end
	end)
	if Common.isLocal(character) then
		CameraFX.speedLines(duration, SILVER)
	end
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "HoraRush" then
		if phase == "Start" and character and root then
			rush(character, (data.Windup or 0.12) + (data.Duration or 1.4))
		elseif phase == "Hit" and data.Position then
			TuskVFX.CreateImpactStar(data.Position, { Size = 2, Rays = 5, Color = SILVER, Color2 = BLUE, Duration = 0.08 })
		elseif phase == "Finish" and data.Position then
			if character then
				rushes[character] = nil
			end
			local dir = data.Direction or Vector3.new(0, 0, -1)
			thrust(data.Position - dir * 3, dir, 12, 0.3)
			word(data.Position + Vector3.new(0, 2, 0), "HORA!", SILVER, true)
			TuskVFX.CreateRotationalShockwave(CFrame.lookAt(data.Position, data.Position + dir) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = data.Radius or 7, Layers = 2, Color = SILVER, Color2 = BLUE, Particles = 1, Width = 0.4 })
			CameraFX.shakeAt(data.Position, 0.6, 50)
		elseif phase == "Stop" and character then
			rushes[character] = nil
		end
	elseif move == "ArmorOff" then
		if phase == "Shed" and character and root then
			TuskAnimation.play(character, "PNArmorOff")
			label(character:FindFirstChild("Head"), "ARMOR OFF!", SILVER, 1.4, 260)
			-- The plates burst off and fly away.
			for k = 1, 14 do
				local plate = VFXLib.part({ Size = Vector3.new(0.6 + math.random() * 0.4, 0.15, 0.5 + math.random() * 0.4), Color = SILVER, Material = Enum.Material.Metal, Transparency = 0 })
				local from = (root.CFrame * CFrame.new(2.2, 1.5, 2.6)).Position
				local vel = Vector3.new((math.random() - 0.5) * 30, 15 + math.random() * 15, (math.random() - 0.5) * 30)
				local spin = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
				VFXLib.animate(0.8, function(a)
					local t = a * 0.8
					local p = from + vel * t + Vector3.new(0, -50 * t * t, 0)
					plate.CFrame = CFrame.new(p) * spin * CFrame.Angles(t * 8, t * 6, 0)
					plate.Transparency = a > 0.7 and (a - 0.7) / 0.3 or 0
				end, function()
					plate:Destroy()
				end)
			end
			VFXLib.flash(root.Position, BLUE, 4, 14, 0.2)
			if Common.isLocal(character) then
				CameraFX.fovPunch(8, 0.4)
			end
		elseif phase == "Back" and character then
			label(character:FindFirstChild("Head"), "ARMOR BACK ON", SILVER, 1.0, 220)
		end
	elseif move == "RapierShot" then
		if phase == "Aim" and character and root then
			TuskAnimation.play(character, "PNPoint")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0.6, 1, -2.6), Duration = (data.Windup or 0.25) + 0.3 })
		elseif phase == "Fire" and data.From and data.To then
			local from, to = data.From, data.To
			local dir = (to - from).Magnitude > 0.1 and (to - from).Unit or Vector3.new(0, 0, -1)
			local blade = VFXLib.part({ Size = Vector3.new(0.1, 0.18, 3.4), Color = BLADE, Material = Enum.Material.Metal, Transparency = 0 })
			local len = (to - from).Magnitude
			VFXLib.animate(math.max(0.08, len / 400), function(a)
				local p = from + dir * (len * a)
				blade.CFrame = CFrame.lookAt(p, p + dir)
			end, function()
				blade:Destroy()
				if data.Hit then
					TuskVFX.CreateImpactStar(to, { Size = 3, Rays = 6, Color = BLADE, Color2 = BLUE, Duration = 0.14 })
				else
					VFXLib.burst(to, { Count = 6, Color = SILVER, Speed = 10, Lifetime = 0.3 })
				end
			end)
			thrust(from, dir, math.min(len, 40), 0.08)
			VFXLib.sound(sounds.NailFire, from, 0.6, 1.4)
		end
	end
end

---------------------------------------------------------------------------
-- AFTERIMAGE STORM
---------------------------------------------------------------------------
local function endStorm(character)
	local st = storms[character]
	storms[character] = nil
	if st then
		VFXLib.cancel(st.Job)
		for _, g in ipairs(st.Ghosts) do
			dropGhost(g)
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Split" and character and root then
		TuskAnimation.play(character, "PNPoint")
		label(character:FindFirstChild("Head"), "SILVER CHARIOT!", SILVER, 1.6, 300)
		TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 1, -4), Duration = (data.Windup or 0.5) + 0.3 })
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.2)
	elseif data.Phase == "Storm" and character and data.Position then
		endStorm(character)
		local target, center = data.Target, data.Position
		local count, radius, duration = data.Images or 7, (data.Radius or 10) * 0.7, data.Duration or 2.2
		local st = { Ghosts = {} }
		for i = 1, count do
			st.Ghosts[i] = chariotGhost()
		end
		storms[character] = st
		local start = os.clock()
		local nextStab = 0
		st.Job = VFXLib.animate(duration + 0.1, function()
			local tr = target and Common.rootOf(target)
			local at = tr and tr.Position or center
			local t = os.clock() - start
			for i, g in ipairs(st.Ghosts) do
				local ang = i / count * math.pi * 2 + t * 2.4
				local pos = at + Vector3.new(math.cos(ang) * radius, 0.5, math.sin(ang) * radius)
				local lunge = math.max(0, math.sin(t * 18 + i * 1.7)) * 1.2
				local look = CFrame.lookAt(pos, Vector3.new(at.X, pos.Y, at.Z))
				placeGhost(g, look * CFrame.new(0, 0, -lunge), 0.45 + 0.1 * math.sin(t * 9 + i))
			end
			if t >= nextStab then
				nextStab = t + 0.05
				local i = math.random(1, count)
				local ang = i / count * math.pi * 2 + t * 2.4
				local from = at + Vector3.new(math.cos(ang) * radius, 0.9, math.sin(ang) * radius)
				thrust(from, (at + Vector3.new(0, 0.5, 0) - from).Unit, radius, 0.1)
			end
		end)
		if nearLocal(center, 40) then
			CameraFX.speedLines(duration, SILVER)
		end
	elseif data.Phase == "Final" and character then
		local st = storms[character]
		local at = data.Position
		if st and at then
			-- They all thrust in at once, then vanish.
			for i, g in ipairs(st.Ghosts) do
				local p = g[1].Part.Position
				thrust(p, (at - p).Magnitude > 0.1 and (at - p).Unit or Vector3.new(0, 0, -1), (at - p).Magnitude + 2, 0.25)
			end
		end
		endStorm(character)
		if at then
			label(character:FindFirstChild("Head"), "HORA HORA HORA!", SILVER, 1.4, 300)
			TuskVFX.CreateRotationalShockwave(CFrame.new(at), { Radius = (data.Radius or 10) * 1.2, Layers = 3, Color = SILVER, Color2 = BLUE, Ground = true, Particles = 1.5, Width = 0.5 })
			TuskVFX.CreateImpactStar(at, { Size = 6, Rays = 10, Color = BLADE, Color2 = BLUE, Duration = 0.25 })
			if nearLocal(at, 60) then
				CameraFX.shake(0.7, 0.35)
			end
		end
	elseif data.Phase == "End" and character then
		endStorm(character)
	end
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local function stepStance()
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character then
			local want = character:GetAttribute("TuskAct") == ACT
			if want and not stanced[character] then
				stanced[character] = true
				TuskAnimation.hold(character, "PNStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "PNStance")
			end
			-- Armour off: silver afterimages as he moves.
			if want and (character:GetAttribute("ChariotArmorOffUntil") or 0) > serverNow and now >= (trailNext[character] or 0) then
				local r = Common.rootOf(character)
				if r and Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z).Magnitude > 4 then
					trailNext[character] = now + 0.12
					afterimage(character, SILVER)
				end
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
			trailNext[character] = nil
		end
	end
end

function PolnareffVFX.handle(name, data)
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
function PolnareffVFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.05 then
		slowTimer = 0
		stepStance()
	end
end

return PolnareffVFX
end

-- ======================================================================
-- MODULE: SilverChariotStand
-- ======================================================================
__modules["SilverChariotStand"] = function()
--[[
	TuskActVFX.SilverChariotStand  (StarterPlayerScripts.SpinClient.TuskActVFX.SilverChariotStand)

	SILVER CHARIOT (Jean Pierre Polnareff), blocky: a slim KNIGHT in
	silver armour.
	  * a helmet with a visor (two narrow glowing eye slits) and a crest of
	    blades sweeping back over the top
	  * a breastplate with a round emblem, layered shoulder plates, a skirt
	    of plates at the hips, greaves and pointed sabatons
	  * dark joints between the plates
	  * a long, thin RAPIER in its right hand: a cup guard and a fine blade
	Registered with TuskStandModels by PolnareffVFX, so TuskStand floats it
	behind him with a pale silver-blue aura.
]]

local SilverChariotStand = {}

local SILVER = Color3.fromRGB(200, 208, 222)
local SILVER_LIGHT = Color3.fromRGB(232, 238, 248)
local SILVER_DARK = Color3.fromRGB(130, 138, 158)
local JOINT = Color3.fromRGB(50, 54, 66)
local ACCENT = Color3.fromRGB(110, 170, 230)
local EYE = Color3.fromRGB(170, 230, 255)
local BLADE = Color3.fromRGB(236, 242, 252)

SilverChariotStand.Aura = Color3.fromRGB(170, 200, 240)
SilverChariotStand.AuraLight = Color3.fromRGB(236, 244, 255)
SilverChariotStand.Offset = CFrame.new(2.2, 1.5, 2.6)

local function newPart(model, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = material or Enum.Material.Metal
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

local function cyl(model, parent, name, length, d, color, cf, material)
	local p = box(model, parent, name, Vector3.new(length, d, d), color, cf, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function SilverChariotStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "SilverChariot"
	local rig = { Joints = {} }

	-- A slim torso under a breastplate.
	local torso = newPart(model, "Body", Vector3.new(1.9, 1.8, 1.0) * s, JOINT, Enum.Material.SmoothPlastic)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	box(model, torso, "Breastplate", Vector3.new(2.0, 1.2, 1.1) * s, SILVER, CFrame.new(0, 0.3 * s, 0))
	box(model, torso, "PlateRidge", Vector3.new(0.08, 1.1, 0.08) * s, SILVER_LIGHT, CFrame.new(0, 0.3 * s, -0.58 * s))
	cyl(model, torso, "Emblem", 0.08 * s, 0.42 * s, ACCENT, CFrame.new(0, 0.45 * s, -0.59 * s) * CFrame.Angles(0, math.pi / 2, 0))
	cyl(model, torso, "EmblemRim", 0.06 * s, 0.52 * s, SILVER_LIGHT, CFrame.new(0, 0.45 * s, -0.57 * s) * CFrame.Angles(0, math.pi / 2, 0))
	for k = 0, 1 do
		box(model, torso, "Faulds", Vector3.new(1.7 - k * 0.1, 0.22, 1.0) * s, k == 0 and SILVER_DARK or SILVER, CFrame.new(0, (-0.42 - k * 0.24) * s, 0))
	end
	box(model, torso, "Waist", Vector3.new(1.3, 0.6, 0.85) * s, JOINT, CFrame.new(0, -1.05 * s, 0), Enum.Material.SmoothPlastic)
	box(model, torso, "Belt", Vector3.new(1.45, 0.18, 0.95) * s, SILVER_DARK, CFrame.new(0, -1.3 * s, 0))
	-- A skirt of plates at the hips.
	for k = -2, 2 do
		box(model, torso, "Tasset", Vector3.new(0.3, 0.65, 0.08) * s, k % 2 == 0 and SILVER or SILVER_LIGHT, CFrame.new(k * 0.3 * s, -1.68 * s, -0.5 * s) * CFrame.Angles(math.rad(-8), 0, 0))
	end
	box(model, torso, "TassetBack", Vector3.new(1.5, 0.6, 0.08) * s, SILVER_DARK, CFrame.new(0, -1.65 * s, 0.5 * s) * CFrame.Angles(math.rad(8), 0, 0))
	box(model, torso, "Neck", Vector3.new(0.45, 0.4, 0.45) * s, JOINT, CFrame.new(0, 1.05 * s, 0), Enum.Material.SmoothPlastic)

	-- Helmet: a visor with two glowing slits, a crest of blades sweeping back.
	local headBase = CFrame.new(0, 1.2 * s, 0)
	local headOffset = CFrame.new(0, 0.5 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.75, 0.9, 0.8) * s, SILVER, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.41 * s
	box(model, head, "Visor", Vector3.new(0.72, 0.5, 0.08) * s, SILVER_DARK, CFrame.new(0, -0.05 * s, hf - 0.03 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "EyeSlit", Vector3.new(0.22, 0.05, 0.05) * s, EYE, CFrame.new(side * 0.16 * s, 0.06 * s, hf - 0.08 * s) * CFrame.Angles(0, 0, side * -0.15), Enum.Material.Neon)
		box(model, head, "Cheek", Vector3.new(0.1, 0.55, 0.6) * s, SILVER_LIGHT, CFrame.new(side * 0.4 * s, -0.12 * s, -0.05 * s))
	end
	box(model, head, "Grill", Vector3.new(0.04, 0.3, 0.09) * s, JOINT, CFrame.new(0, -0.2 * s, hf - 0.04 * s))
	for k = 0, 4 do
		local f = k / 4
		box(model, head, "Crest", Vector3.new(0.12, (0.5 - f * 0.12) * s, (0.32 + f * 0.1) * s), k % 2 == 0 and SILVER_LIGHT or SILVER, CFrame.new(0, (0.5 + f * 0.15) * s, (-0.25 + f * 0.65) * s) * CFrame.Angles(math.rad(-35 - f * 25), 0, 0))
	end
	box(model, head, "CrestBlade", Vector3.new(0.06, 0.12, 0.9) * s, ACCENT, CFrame.new(0, 0.72 * s, 0.75 * s) * CFrame.Angles(math.rad(-20), 0, 0), Enum.Material.Neon)

	-- Arms: layered shoulder plates, armoured forearms; the rapier in its right hand.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		for k = 0, 2 do
			box(model, torso, "Pauldron", Vector3.new(0.8 - k * 0.08, 0.2, 0.85 - k * 0.05) * s, k % 2 == 0 and SILVER or SILVER_LIGHT, CFrame.new(side * (1.15 + k * 0.05) * s, (0.82 - k * 0.18) * s, 0) * CFrame.Angles(0, 0, side * (-0.35 - k * 0.1)))
		end
		local base = CFrame.new(side * 1.25 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.05 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.5, 2.1, 0.5) * s, JOINT, base * offset, Enum.Material.SmoothPlastic)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Rerebrace", Vector3.new(0.6, 0.7, 0.6) * s, SILVER, CFrame.new(0, 0.45 * s, 0))
		box(model, arm, "Couter", Vector3.new(0.58, 0.22, 0.62) * s, SILVER_LIGHT, CFrame.new(0, -0.05 * s, -0.02 * s))
		box(model, arm, "Vambrace", Vector3.new(0.62, 0.75, 0.62) * s, SILVER, CFrame.new(0, -0.55 * s, 0))
		local hand = box(model, arm, "Gauntlet", Vector3.new(0.5, 0.45, 0.5) * s, SILVER_DARK, CFrame.new(0, -1.2 * s, 0))
		if a[1] == "ArmR" then
			-- The rapier: hilt in the hand, a cup guard, a long fine blade forward.
			cyl(model, hand, "Hilt", 0.6 * s, 0.12 * s, JOINT, CFrame.new(0, -0.05 * s, 0) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.SmoothPlastic)
			local guard = box(model, hand, "Guard", Vector3.new(0.5, 0.5, 0.18) * s, SILVER_LIGHT, CFrame.new(0, -0.05 * s, -0.35 * s))
			guard.Shape = Enum.PartType.Ball
			box(model, hand, "Quillon", Vector3.new(0.7, 0.06, 0.06) * s, SILVER_LIGHT, CFrame.new(0, -0.05 * s, -0.42 * s))
			box(model, hand, "Blade", Vector3.new(0.06, 0.12, 4.2) * s, BLADE, CFrame.new(0, -0.05 * s, -2.55 * s), Enum.Material.Metal)
			box(model, hand, "BladeShine", Vector3.new(0.02, 0.04, 4.0) * s, Color3.new(1, 1, 1), CFrame.new(0, -0.02 * s, -2.55 * s), Enum.Material.Neon)
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.05 * s, -4.6 * s)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: greaves, knee plates, pointed sabatons.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.42 * s, -1.95 * s, 0)
		local offset = CFrame.new(0, -1.15 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.55, 2.3, 0.55) * s, JOINT, base * offset, Enum.Material.SmoothPlastic)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Cuisse", Vector3.new(0.66, 0.85, 0.66) * s, SILVER, CFrame.new(0, 0.6 * s, 0))
		box(model, leg, "Poleyn", Vector3.new(0.5, 0.3, 0.15) * s, SILVER_LIGHT, CFrame.new(0, 0.05 * s, -0.36 * s))
		box(model, leg, "Greave", Vector3.new(0.64, 0.85, 0.66) * s, SILVER, CFrame.new(0, -0.55 * s, 0))
		box(model, leg, "Sabaton", Vector3.new(0.55, 0.26, 0.9) * s, SILVER_DARK, CFrame.new(0, -1.22 * s, -0.15 * s))
		box(model, leg, "Toe", Vector3.new(0.3, 0.2, 0.35) * s, SILVER_LIGHT, CFrame.new(0, -1.25 * s, -0.7 * s) * CFrame.Angles(0, math.pi / 4, 0))
	end
	return model, rig
end

return SilverChariotStand
end
end
