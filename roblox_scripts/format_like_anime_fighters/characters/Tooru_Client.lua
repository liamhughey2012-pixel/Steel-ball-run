--[[
	Tooru_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Tooru (JoJolion): Wonder of U.
	Its other half is Tooru_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: TooruVFX
-- ======================================================================
__modules["TooruVFX"] = function()
--[[
	TuskActVFX.TooruVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.TooruVFX)

	Client visuals for Tooru (JoJolion) / WONDER OF U. Blocky.
	  * Wonder of U (WonderOfUStand), the old man in the maroon suit,
	    floats behind him with a dark red aura and swings his cane with him;
	    Tooru stands loose and unbothered, head tilted
	  * CALAMITY: things fall out of the sky (a steel girder, a flowerpot, a
	    road sign, a tree branch): a dark shadow on the ground first, then
	    it drops, smashes, kicks up dust and lies there a moment
	  * DEBRIS: the shadow slides after the nearest enemy, then stops and
	    turns red: get out from under it
	  * THE PURSUER'S CURSE: a dark red spiral spins over each cursed head;
	    each step toward him brings something down on them
	  * WONDER OF U: the old man fades in right beside them, sweeps his cane
	    through their legs, and fades away
	  * THE FLOW OF CALAMITY: "WONDER OF U" over him, the world goes sepia
	    round him, a maroon ring marks his reach and leaves fall all round;
	    hit him or chase him and calamity finds you ("CALAMITY!")
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

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
local WonderOfUStand = __require("WonderOfUStand")

local TooruVFX = {}
local ACT = 16
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, WonderOfUStand.build, { Aura = WonderOfUStand.Aura, AuraLight = WonderOfUStand.AuraLight, Offset = WonderOfUStand.Offset })

local MAROON = Color3.fromRGB(150, 40, 50)
local SHADOW = Color3.fromRGB(20, 12, 16)
local WARN = Color3.fromRGB(230, 40, 40)
local DUST = Color3.fromRGB(190, 170, 140)
local LEAF = Color3.fromRGB(110, 150, 60)
local LEAF2 = Color3.fromRGB(170, 120, 50)

local stanced = {}
local curseMarks = {} -- [character] = billboard
local ghosts = {} -- [target] = { Model, Rig }
local flows = {} -- [character] = { Until, Ring, NextLeaf }

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function newModel(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = VFXLib.Folder
	return m
end

local function block(model, size, cf, color, material, shape)
	local p = VFXLib.part({ Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic })
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- The things calamity drops. Built round CFrame.new() so they can be moved
-- as a whole; returns the model and its parts' offsets.
local function buildFalling(kind)
	local m = newModel("Calamity" .. tostring(kind))
	local origin = CFrame.new()
	if kind == "Girder" then
		local steel = Color3.fromRGB(120, 124, 130)
		block(m, Vector3.new(7, 0.3, 1.2), origin * CFrame.new(0, 0.6, 0), steel, Enum.Material.Metal)
		block(m, Vector3.new(7, 0.3, 1.2), origin * CFrame.new(0, -0.6, 0), steel, Enum.Material.Metal)
		block(m, Vector3.new(7, 1.0, 0.25), origin, Color3.fromRGB(100, 104, 110), Enum.Material.Metal)
		for k = -3, 3 do
			block(m, Vector3.new(0.15, 0.15, 0.3), origin * CFrame.new(k, 0.78, 0), Color3.fromRGB(80, 60, 50), Enum.Material.Metal)
		end
	elseif kind == "Pot" then
		block(m, Vector3.new(1.4, 1.3, 1.4), origin, Color3.fromRGB(196, 100, 60), Enum.Material.Slate)
		block(m, Vector3.new(1.6, 0.25, 1.6), origin * CFrame.new(0, 0.65, 0), Color3.fromRGB(176, 86, 50), Enum.Material.Slate)
		block(m, Vector3.new(1.3, 0.1, 1.3), origin * CFrame.new(0, 0.7, 0), Color3.fromRGB(70, 50, 34), Enum.Material.Ground)
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			block(m, Vector3.new(0.5, 1.1, 0.12), origin * CFrame.new(math.sin(a) * 0.3, 1.2, math.cos(a) * 0.3) * CFrame.Angles(math.cos(a) * 0.4, 0, -math.sin(a) * 0.4), Color3.fromRGB(70, 160, 70), Enum.Material.Grass)
		end
		block(m, Vector3.new(0.4, 0.4, 0.4), origin * CFrame.new(0, 1.8, 0), Color3.fromRGB(240, 200, 60), Enum.Material.Neon, Enum.PartType.Ball)
	elseif kind == "Sign" then
		block(m, Vector3.new(0.25, 5, 0.25), origin * CFrame.new(0, -1.5, 0), Color3.fromRGB(150, 150, 156), Enum.Material.Metal)
		for k = 0, 1 do
			block(m, Vector3.new(2.2, 2.2, 0.15), origin * CFrame.new(0, 1.6, -0.15) * CFrame.Angles(0, 0, k * math.pi / 4), Color3.fromRGB(200, 30, 30))
		end
		block(m, Vector3.new(1.5, 0.35, 0.18), origin * CFrame.new(0, 1.6, -0.2), Color3.fromRGB(250, 250, 250))
	else -- Branch
		block(m, Vector3.new(6, 0.7, 0.7), origin * CFrame.Angles(0, 0, 0.1), Color3.fromRGB(100, 70, 44), Enum.Material.Wood)
		block(m, Vector3.new(2.5, 0.4, 0.4), origin * CFrame.new(1.2, 0.6, 0) * CFrame.Angles(0, 0, 0.7), Color3.fromRGB(100, 70, 44), Enum.Material.Wood)
		for k = -2, 2 do
			block(m, Vector3.new(1.6, 1.6, 1.6), origin * CFrame.new(k * 1.2, 0.8 + (k % 2) * 0.3, (k % 2 == 0) and 0.3 or -0.3), k % 2 == 0 and LEAF or Color3.fromRGB(80, 130, 50), Enum.Material.Grass, Enum.PartType.Ball)
		end
	end
	local offsets = {}
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			offsets[p] = p.CFrame
		end
	end
	return m, offsets
end

local function placeModel(offsets, cf)
	for p, off in pairs(offsets) do
		p.CFrame = cf * off
	end
end

local function fadeModel(m, offsets, t)
	for p in pairs(offsets) do
		p.Transparency = t
	end
end

-- A shadow on the ground (a dark disc with a ring round it).
local function newShadow(radius, color)
	local disc = VFXLib.part({ Size = Vector3.new(0.12, radius * 2, radius * 2), Shape = Enum.PartType.Cylinder, Color = SHADOW, Material = Enum.Material.SmoothPlastic, Transparency = 0.45 })
	local ring = VFXLib.part({ Size = Vector3.new(0.1, radius * 2 + 0.6, radius * 2 + 0.6), Shape = Enum.PartType.Cylinder, Color = color or MAROON, Material = Enum.Material.Neon, Transparency = 0.4 })
	return { Disc = disc, Ring = ring, Radius = radius }
end

local function placeShadow(sh, pos, scale)
	local cf = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local d = sh.Radius * 2 * scale
	sh.Disc.Size = Vector3.new(0.12, d, d)
	sh.Disc.CFrame = cf
	sh.Ring.Size = Vector3.new(0.1, d + 0.6, d + 0.6)
	sh.Ring.CFrame = cf * CFrame.new(-0.02, 0, 0)
end

local function killShadow(sh)
	sh.Disc:Destroy()
	sh.Ring:Destroy()
end

local function ground(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { VFXLib.Folder }
	local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), params)
	return hit and hit.Position or (pos - Vector3.new(0, 3, 0))
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
	VFXLib.animate(duration or 1.2, function(a)
		bb.StudsOffset = Vector3.new(0, 3 + a, 0)
		t.TextTransparency = math.max(0, a * 1.5 - 0.5)
		t.TextStrokeTransparency = 0.1 + 0.9 * a
	end, function()
		bb:Destroy()
	end)
end

local function nearLocal(pos, range)
	local r = localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	return r ~= nil and (r.Position - pos).Magnitude <= range
end

---------------------------------------------------------------------------
-- Calamity: something falls
---------------------------------------------------------------------------
local function fallOn(position, kind, fallTime, radius)
	local landAt = ground(position)
	local m, offsets = buildFalling(kind)
	local spin = CFrame.Angles(math.random() * 0.6, math.random() * math.pi * 2, math.random() * 0.6)
	local sh = newShadow(radius or 4, WARN)
	VFXLib.animate(fallTime, function(a)
		local y = 45 * (1 - a * a)
		placeModel(offsets, CFrame.new(landAt + Vector3.new(0, 1 + y, 0)) * spin * CFrame.Angles(a * 2, 0, a))
		placeShadow(sh, landAt, 0.4 + 0.6 * a)
	end, function()
		killShadow(sh)
		-- Lies where it landed a moment, then sinks away.
		local rest = CFrame.new(landAt + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, kind == "Sign" and math.pi / 2 - 0.2 or 0.15)
		placeModel(offsets, rest)
		VFXLib.animate(1.6, function(a)
			if a > 0.6 then
				local k = (a - 0.6) / 0.4
				placeModel(offsets, rest * CFrame.new(0, -k * 1.5, 0))
				fadeModel(m, offsets, k)
			end
		end, function()
			m:Destroy()
		end)
	end)
end

local function landFx(position, radius)
	local at = ground(position)
	VFXLib.burst(at + Vector3.new(0, 0.5, 0), { Count = 22, Color = DUST, Speed = 18, Lifetime = 0.7, Spread = 80, Direction = Vector3.new(0, 1, 0) })
	VFXLib.burst(at + Vector3.new(0, 0.5, 0), { Count = 8, Color = Color3.fromRGB(110, 90, 70), Speed = 26, Lifetime = 0.5, Acceleration = Vector3.new(0, -50, 0) })
	local ring = VFXLib.part({ Size = Vector3.new(0.2, 1, 1), Shape = Enum.PartType.Cylinder, Color = DUST, Material = Enum.Material.SmoothPlastic, Transparency = 0.3 })
	VFXLib.animate(0.4, function(a)
		local d = (radius or 5) * 2.4 * VFXLib.easeOut(a)
		ring.Size = Vector3.new(0.2, d, d)
		ring.CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Transparency = 0.3 + 0.7 * a
	end, function()
		ring:Destroy()
	end)
	VFXLib.sound(sounds.Swing, at, 0.7, 0.45)
	if nearLocal(at, 40) then
		CameraFX.shakeAt(at, 0.6, 40)
	end
end

---------------------------------------------------------------------------
-- DEBRIS: the shadow that follows, then locks
---------------------------------------------------------------------------
local function markFollow(data)
	local target = data.Target
	local sh = newShadow(3.5)
	local follow = data.Follow or 0.55
	VFXLib.animate(follow, function(a)
		local tr = target and target.Parent and target:FindFirstChild("HumanoidRootPart")
		local pos = tr and ground(tr.Position) or data.Position
		placeShadow(sh, pos, 0.5 + 0.5 * a)
	end, function()
		killShadow(sh)
	end)
end

local function markLock(data)
	local sh = newShadow(4.5, WARN)
	local at = ground(data.Position)
	VFXLib.animate(data.Lock or 0.4, function(a)
		placeShadow(sh, at, 1 + math.sin(a * 30) * 0.04)
		sh.Ring.Transparency = 0.1 + 0.3 * math.abs(math.sin(a * 18))
	end, function()
		killShadow(sh)
	end)
end

---------------------------------------------------------------------------
-- WONDER OF U appears beside them
---------------------------------------------------------------------------
local function setGhostAlpha(model, t)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Transparency = t
		end
	end
end

local function appear(data)
	local target = data.Target
	local tr = target and target:FindFirstChild("HumanoidRootPart")
	if not data.Position then
		return
	end
	local model, rig = WonderOfUStand.build(1)
	model.Parent = VFXLib.Folder
	local look = tr and Vector3.new(tr.Position.X, data.Position.Y, tr.Position.Z) or (data.Position + Vector3.new(0, 0, -1))
	local cf = CFrame.lookAt(data.Position + Vector3.new(0, 0.6, 0), look)
	model:PivotTo(cf)
	setGhostAlpha(model, 1)
	ghosts[target or model] = { Model = model, Rig = rig }
	VFXLib.burst(data.Position, { Count = 14, Color = MAROON, Speed = 6, Lifetime = 0.6 })
	VFXLib.animate(0.25, function(a)
		setGhostAlpha(model, 1 - a)
	end)
	-- He lifts the cane, ready to sweep.
	local arm = rig.Joints.ArmR
	VFXLib.animate(data.Delay or 0.45, function(a)
		if arm then
			arm.Weld.C0 = arm.Base * CFrame.Angles(a * 1.2, 0, -a * 0.8) * arm.Offset
		end
	end)
	-- Safety: never leave one behind.
	task.delay((data.Delay or 0.45) + 2, function()
		if model.Parent then
			model:Destroy()
		end
		if ghosts[target or model] and ghosts[target or model].Model == model then
			ghosts[target or model] = nil
		end
	end)
end

local function sweep(data)
	local g = data.Target and ghosts[data.Target]
	if g then
		ghosts[data.Target] = nil
		local arm = g.Rig.Joints.ArmR
		VFXLib.animate(0.18, function(a)
			if arm then
				arm.Weld.C0 = arm.Base * CFrame.Angles(1.2 - a * 0.6, 0, -0.8 + a * 2.4) * arm.Offset
			end
		end, function()
			VFXLib.animate(0.4, function(a)
				setGhostAlpha(g.Model, a)
			end, function()
				g.Model:Destroy()
			end)
		end)
	end
	local tr = data.Target and data.Target:FindFirstChild("HumanoidRootPart")
	local pos = tr and tr.Position or data.Position
	VFXLib.burst(ground(pos) + Vector3.new(0, 0.5, 0), { Count = 12, Color = DUST, Speed = 12, Lifetime = 0.5 })
	if data.Hit then
		TuskVFX.CreateImpactStar(pos, { Size = 2.4, Rays = 6, Color = pal.Second, Color2 = Color3.new(1, 1, 1), Duration = 0.14 })
		label(data.Target and data.Target:FindFirstChild("Head"), "TRIPPED", pal.Second, 1)
	end
	VFXLib.sound(sounds.Swing, pos, 0.6, 0.8)
end

---------------------------------------------------------------------------
-- THE PURSUER'S CURSE: a spiral over each cursed head (from the attribute)
---------------------------------------------------------------------------
local function newCurseMark(character)
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "CalamityCurse"
	bb.Size = UDim2.new(2.2, 0, 2.2, 0)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	for k, sc in ipairs({ 1, 0.66, 0.33 }) do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5 + (k - 2) * 0.04, 0.5)
		f.Size = UDim2.fromScale(sc, sc)
		f.BackgroundTransparency = 1
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		local stroke = Instance.new("UIStroke")
		stroke.Color = k == 2 and Color3.fromRGB(90, 20, 30) or WARN
		stroke.Thickness = 3
		stroke.Parent = f
		f.Parent = bb
	end
	bb.Parent = VFXLib.Folder
	return bb
end

local function stepCurses()
	local t = workspace:GetServerTimeNow()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character then
			local on = (character:GetAttribute("CalamityCurseUntil") or 0) > t
			if on and not curseMarks[character] then
				curseMarks[character] = newCurseMark(character) or false
			elseif not on and curseMarks[character] ~= nil then
				if curseMarks[character] then
					curseMarks[character]:Destroy()
				end
				curseMarks[character] = nil
			end
		end
	end
	for character, bb in pairs(curseMarks) do
		if not character.Parent then
			if bb then
				bb:Destroy()
			end
			curseMarks[character] = nil
		elseif bb then
			bb.StudsOffset = Vector3.new(0, 2.6 + math.sin(os.clock() * 3) * 0.15, 0)
			for i, f in ipairs(bb:GetChildren()) do
				f.Rotation = os.clock() * (60 + i * 40)
			end
		end
	end
end

---------------------------------------------------------------------------
-- THE FLOW OF CALAMITY
---------------------------------------------------------------------------
local function sepia(duration)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "TooruCalamity"
	cc.Parent = Lighting
	VFXLib.animate(duration, function(a)
		local k = a < 0.1 and a / 0.1 or (a > 0.85 and (1 - a) / 0.15 or 1)
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 220, 190), k)
		cc.Saturation = -0.45 * k
		cc.Contrast = 0.1 * k
	end, function()
		cc:Destroy()
	end)
end

local function startFlow(character, data)
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local range = data.Range or 45
	local ring = VFXLib.part({ Size = Vector3.new(0.2, range * 2, range * 2), Shape = Enum.PartType.Cylinder, Color = MAROON, Material = Enum.Material.Neon, Transparency = 0.6 })
	flows[character] = { Until = os.clock() + (data.Duration or 7), Ring = ring, Range = range, NextLeaf = 0 }
	if nearLocal(root.Position, range) then
		sepia(data.Duration or 7)
		if not Common.isLocal(character) then
			label(character:FindFirstChild("Head"), "DON'T CHASE HIM...", WARN, 2.2, 300)
		end
	end
end

local function endFlow(character)
	local f = flows[character]
	if f then
		flows[character] = nil
		local ring = f.Ring
		VFXLib.animate(0.4, function(a)
			ring.Transparency = 0.6 + 0.4 * a
		end, function()
			ring:Destroy()
		end)
	end
end

local function stepFlows()
	local now = os.clock()
	for character, f in pairs(flows) do
		local root = Common.rootOf(character)
		if not root or not character.Parent or now > f.Until + 0.5 then
			endFlow(character)
		else
			f.Ring.CFrame = CFrame.new(ground(root.Position) + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			f.Ring.Transparency = 0.6 + math.sin(now * 4) * 0.1
			if now >= f.NextLeaf then
				f.NextLeaf = now + 0.12
				-- Leaves fall all round him.
				local a = math.random() * math.pi * 2
				local r = math.random() * f.Range * 0.8
				local start = root.Position + Vector3.new(math.cos(a) * r, 14 + math.random() * 6, math.sin(a) * r)
				local leaf = VFXLib.part({ Size = Vector3.new(0.6, 0.08, 0.4), Color = math.random() < 0.5 and LEAF or LEAF2, Material = Enum.Material.SmoothPlastic })
				local drift = Vector3.new(math.random() * 4 - 2, 0, math.random() * 4 - 2)
				VFXLib.animate(2.2, function(t)
					leaf.CFrame = CFrame.new(start + drift * t + Vector3.new(math.sin(t * 9) * 0.8, -16 * t, 0)) * CFrame.Angles(t * 5, t * 3, math.sin(t * 7))
					leaf.Transparency = t > 0.8 and (t - 0.8) / 0.2 or 0
				end, function()
					leaf:Destroy()
				end)
			end
		end
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
	TuskAnimation.play(character, "T_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1, -3.2), Duration = 0.3 })
	VFXLib.sound(sounds.Swing, root, 0.5, 0.9 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or pal.Second)
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "Calamity" then
		if phase == "Fall" and data.Position then
			fallOn(data.Position, data.Kind, data.FallTime or 0.3, data.Radius)
		elseif phase == "Land" and data.Position then
			landFx(data.Position, data.Radius)
		elseif phase == "Reflect" and data.Position then
			fallOn(data.Position, data.Kind, 0.2, 3)
			task.delay(0.2, function()
				landFx(data.Position, 3)
			end)
			label(data.Target and data.Target:FindFirstChild("Head"), "CALAMITY!", WARN, 1.2)
		end
	elseif move == "Debris" then
		if phase == "Mark" then
			if character and root then
				TuskAnimation.play(character, "TCast")
				TuskStand.action(character, "Lunge", { Target = CFrame.new(0.6, 1.4, -2.4), Duration = 0.5 })
			end
			markFollow(data)
		elseif phase == "Lock" and data.Position then
			markLock(data)
		end
	elseif move == "Curse" then
		if phase == "Cast" and character and root then
			TuskAnimation.play(character, "TCurse")
			-- A dark wave rolls out in front of him.
			local wave = VFXLib.part({ Size = Vector3.new(0.3, 1, 1), Shape = Enum.PartType.Cylinder, Color = MAROON, Material = Enum.Material.Neon, Transparency = 0.3 })
			local at = ground(root.Position) + Vector3.new(0, 0.3, 0)
			VFXLib.animate(0.45, function(a)
				local d = (data.Range or 45) * 2 * VFXLib.easeOut(a)
				wave.Size = Vector3.new(0.3, d, d)
				wave.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
				wave.Transparency = 0.3 + 0.7 * a
			end, function()
				wave:Destroy()
			end)
		elseif phase == "Cursed" then
			for _, target in ipairs(data.Targets or {}) do
				label(target:FindFirstChild("Head"), "CURSED", WARN, 1.4)
			end
		end
	elseif move == "Appear" then
		if phase == "Appear" then
			if character and root then
				TuskAnimation.play(character, "TCast")
			end
			appear(data)
		elseif phase == "Sweep" then
			sweep(data)
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Charge" and character and root then
		TuskAnimation.play(character, "TUlt")
		TuskStand.action(character, "Loom", { Target = CFrame.new(1.6, 2.2, 2.4), Duration = (data.Windup or 0.7) + 1 })
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 0.8)
		label(character:FindFirstChild("Head"), "WONDER OF U", pal.Second, 1.8, 320)
		VFXLib.burst(root.Position, { Count = 24, Color = MAROON, Speed = 10, Lifetime = 0.8 })
		if Common.isLocal(character) then
			CameraFX.fovPunch(-5, 0.4)
		end
	elseif data.Phase == "Active" and character then
		startFlow(character, data)
	elseif data.Phase == "End" and character then
		endFlow(character)
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
				TuskAnimation.hold(character, "TStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "TStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function TooruVFX.handle(name, data)
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
function TooruVFX.step(dt)
	dt = dt or 1 / 60
	stepFlows()
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
		stepCurses()
	end
end

return TooruVFX
end

-- ======================================================================
-- MODULE: WonderOfUStand
-- ======================================================================
__modules["WonderOfUStand"] = function()
--[[
	TuskActVFX.WonderOfUStand  (StarterPlayerScripts.SpinClient.TuskActVFX.WonderOfUStand)

	WONDER OF U (Tooru, JoJolion), blocky, matched to the art: a tall old
	man in a long maroon suit.
	  * a dark red bowler hat
	  * a mask for a face: stacked ribbed bands of maroon and purple, yellow
	    slats down each side, and one round glowing red eye
	  * a long yellow knit scarf round his neck, its ends hanging down
	  * two red sunflower brooches (gold petals) on the front of his coat
	  * maroon gloves, brown shoes, and a long cane in his right hand
	Registered with TuskStandModels by TooruVFX, so TuskStand floats it
	behind Tooru (players and NPCs). TooruVFX also builds spare copies to
	make it "appear" anywhere.
]]

local WonderOfUStand = {}

local SUIT = Color3.fromRGB(112, 34, 38)
local SUIT_DARK = Color3.fromRGB(78, 22, 28)
local SUIT_LIGHT = Color3.fromRGB(140, 48, 50)
local HAT = Color3.fromRGB(96, 34, 36)
local BAND_A = Color3.fromRGB(120, 40, 60)
local BAND_B = Color3.fromRGB(96, 60, 120)
local SLAT = Color3.fromRGB(226, 186, 70)
local EYE = Color3.fromRGB(255, 50, 40)
local SCARF = Color3.fromRGB(222, 190, 90)
local SCARF_RIB = Color3.fromRGB(190, 156, 64)
local BROOCH = Color3.fromRGB(220, 40, 40)
local PETAL = Color3.fromRGB(236, 176, 50)
local GLOVE = Color3.fromRGB(90, 30, 34)
local SHOE = Color3.fromRGB(110, 70, 44)
local CANE = Color3.fromRGB(120, 40, 36)
local KNOB = Color3.fromRGB(210, 170, 70)

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
		box(model, parent, "Petal", Vector3.new(0.1, 0.16, 0.05) * s, PETAL, cf * CFrame.new(math.sin(a) * 0.17 * s, math.cos(a) * 0.17 * s, 0.01 * s) * CFrame.Angles(0, 0, -a))
	end
	cyl(model, parent, "Brooch", 0.07 * s, 0.26 * s, BROOCH, cf * ALONG_Z, Enum.Material.Neon)
	cyl(model, parent, "BroochRim", 0.06 * s, 0.32 * s, SUIT_DARK, cf * CFrame.new(0, 0, 0.02 * s) * ALONG_Z)
end

function WonderOfUStand.build(scale)
	local s = (scale or 1) * 0.9
	local model = Instance.new("Model")
	model.Name = "WonderOfU"
	local rig = { Joints = {} }

	-- A long coat: chest and the skirt of the coat below it.
	local torso = newPart(model, "Body", Vector3.new(1.9, 2.0, 1.0) * s, SUIT)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.5 * s
	box(model, torso, "CoatSkirt", Vector3.new(1.95, 1.3, 1.05) * s, SUIT, CFrame.new(0, -1.55 * s, 0))
	box(model, torso, "CoatSplit", Vector3.new(0.06, 1.3, 0.05) * s, SUIT_DARK, CFrame.new(0, -1.55 * s, front - 0.03 * s))
	box(model, torso, "Placket", Vector3.new(0.08, 1.9, 0.05) * s, SUIT_DARK, CFrame.new(0, 0, front - 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		-- Lapels and the shoulders of the coat.
		box(model, torso, "Lapel", Vector3.new(0.3, 0.9, 0.06) * s, SUIT_LIGHT, CFrame.new(side * 0.3 * s, 0.5 * s, front - 0.03 * s) * CFrame.Angles(0, 0, side * 0.35))
		box(model, torso, "ShoulderPad", Vector3.new(0.55, 0.3, 1.05) * s, SUIT, CFrame.new(side * 0.95 * s, 0.9 * s, 0))
		-- A sunflower brooch either side of the front.
		brooch(model, torso, CFrame.new(side * 0.66 * s, -0.35 * s, front - 0.06 * s), s)
		box(model, torso, "Pocket", Vector3.new(0.5, 0.06, 0.05) * s, SUIT_DARK, CFrame.new(side * 0.5 * s, -1.25 * s, front - 0.06 * s))
	end

	-- The yellow knit scarf: wound round the neck, both ends hanging down.
	box(model, torso, "ScarfWrap", Vector3.new(1.1, 0.5, 1.15) * s, SCARF, CFrame.new(0, 1.2 * s, 0))
	box(model, torso, "ScarfFold", Vector3.new(1.2, 0.3, 1.2) * s, SCARF_RIB, CFrame.new(0, 1.0 * s, 0))
	for i, end_ in ipairs({ { -0.25, 1.7 }, { 0.22, 1.3 } }) do
		local len = end_[2] * s
		local x = end_[1] * s
		box(model, torso, "ScarfEnd", Vector3.new(0.34 * s, len, 0.1 * s), SCARF, CFrame.new(x, 0.9 * s - len / 2, front - 0.1 * s - i * 0.02 * s))
		for k = 1, math.floor(end_[2] / 0.2) do
			box(model, torso, "ScarfRib", Vector3.new(0.36, 0.03, 0.11) * s, SCARF_RIB, CFrame.new(x, 0.9 * s - k * 0.2 * s, front - 0.1 * s - i * 0.02 * s))
		end
	end

	-- Head: a ribbed mask, yellow slats down the sides, one red eye.
	local headBase = CFrame.new(0, 1.45 * s, 0)
	local headOffset = CFrame.new(0, 0.6 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.85, 1.15, 0.85) * s, BAND_A, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	local hf = -0.43 * s
	for k = 0, 6 do
		box(model, head, "Band", Vector3.new(0.9, 0.08, 0.9) * s, k % 2 == 0 and BAND_B or SUIT_DARK, CFrame.new(0, (-0.48 + k * 0.16) * s, 0))
	end
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			box(model, head, "Slat", Vector3.new(0.07, 0.95, 0.06) * s, SLAT, CFrame.new(side * (0.2 + k * 0.08) * s, -0.05 * s, hf - 0.03 * s))
		end
	end
	box(model, head, "Nose", Vector3.new(0.14, 0.5, 0.1) * s, BAND_A, CFrame.new(0, -0.05 * s, hf - 0.05 * s))
	cyl(model, head, "EyeRim", 0.08 * s, 0.34 * s, SUIT_DARK, CFrame.new(0.18 * s, 0.18 * s, hf - 0.05 * s) * ALONG_Z)
	cyl(model, head, "Eye", 0.1 * s, 0.24 * s, EYE, CFrame.new(0.18 * s, 0.18 * s, hf - 0.07 * s) * ALONG_Z, Enum.Material.Neon)
	-- The bowler hat: a round crown, a band, a curled brim.
	ball(model, head, "HatCrown", 1.0 * s, HAT, CFrame.new(0, 0.62 * s, 0))
	box(model, head, "HatCrownBase", Vector3.new(0.95, 0.3, 0.95) * s, HAT, CFrame.new(0, 0.6 * s, 0))
	box(model, head, "HatBand", Vector3.new(0.98, 0.1, 0.98) * s, SUIT_DARK, CFrame.new(0, 0.52 * s, 0))
	cyl(model, head, "HatBrim", 0.08 * s, 1.45 * s, HAT, CFrame.new(0, 0.44 * s, 0) * ALONG_Y)

	-- Arms: long suit sleeves, maroon gloves. The right hand holds the cane.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.2 * s, 0.75 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.55, 2.2, 0.55) * s, SUIT, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		box(model, arm, "Cuff", Vector3.new(0.62, 0.2, 0.62) * s, SUIT_DARK, CFrame.new(0, -0.95 * s, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.5, 0.45, 0.48) * s, GLOVE, CFrame.new(0, -1.3 * s, 0))
		if a[1] == "ArmR" then
			-- The cane: long, held point-down, a gold knob on top.
			cyl(model, hand, "Cane", 3.6 * s, 0.14 * s, CANE, CFrame.new(0, -1.5 * s, -0.25 * s) * ALONG_Y)
			ball(model, hand, "CaneKnob", 0.24 * s, KNOB, CFrame.new(0, 0.25 * s, -0.25 * s))
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: suit trousers, brown shoes.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.45 * s, -2.1 * s, 0)
		local offset = CFrame.new(0, -1.05 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.65, 2.1, 0.65) * s, SUIT_DARK, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Shoe", Vector3.new(0.66, 0.3, 1.0) * s, SHOE, CFrame.new(0, -1.1 * s, -0.17 * s))
	end
	return model, rig
end

return WonderOfUStand
end
end
