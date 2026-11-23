--[[
	PorkPie_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Pork Pie Hat Kid: Wired.
	Its other half is PorkPie_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: PorkPie
-- ======================================================================
__modules["PorkPie"] = function()
--[[
	TuskActVFX.PorkPie  (StarterPlayerScripts.SpinClient.TuskActVFX.PorkPie)

	Client visuals for Pork Pie Hat Kid / WIRED (from the owner's pictures):
	  * blocky fish hooks (barbed J hook, ring eye, feather bait) on steel
	    cables that run out of his MOUTH
	  * the winch: a cable drum that spins in front of his mouth while he reels
	  * WIRED HOOK: the hook flies out, snags, the cable reels the enemy in
	    (a miss whips the hook back into his mouth)
	  * BAIT PAN: a frying pan of water with a feather bait bobbing over it;
	    hooks burst out of the water at whoever comes near
	  * DOUBLE HOOK LIFT: both hooks snag, hoist the enemies up, slam them down
	  * WIRED WINCH: puddles all round him, hooks erupt from every puddle, the
	    cables swing over to his mouth and the winch reels everyone in, slam
	Everything is blocky to match the game's look.
]]

local Players = game:GetService("Players")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Common = __require("TuskActCommon")

local PorkPie = {}
local ACT = 7
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds

local STEEL = Color3.fromRGB(205, 210, 222)
local CABLE = Color3.fromRGB(165, 170, 182)
local WATER = Color3.fromRGB(70, 150, 230)
local WATER_LIGHT = Color3.fromRGB(190, 230, 255)
local PAN = Color3.fromRGB(60, 62, 68)
local FEATHER = Color3.fromRGB(150, 110, 70)
local FEATHER_LIGHT = Color3.fromRGB(225, 200, 150)

local hooks = {} -- [projectile id] = flying hook
local lines = {} -- list of cables held taut between two moving points
local pans = {} -- [pan id] = bait pan
local puddles = {} -- list of the ultimate's puddles
local winches = {} -- [character] = spinning cable drum at the mouth
local stanced = {}

---------------------------------------------------------------------------
-- Building blocks
---------------------------------------------------------------------------
local function box(model, size, cf, color, material, transparency)
	local p = VFXLib.part({ Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, Transparency = transparency or 0 })
	p.Parent = model
	return p
end

-- Stepped (pixel-art) round plate lying in the XZ plane.
local function roundPlate(model, diameter, thickness, cf, color, material, transparency)
	local core = box(model, Vector3.new(diameter * 0.86, thickness, diameter * 0.86), cf, color, material, transparency)
	box(model, Vector3.new(diameter, thickness, diameter * 0.62), cf, color, material, transparency)
	box(model, Vector3.new(diameter * 0.62, thickness, diameter), cf, color, material, transparency)
	return core
end

local function newModel(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = VFXLib.Folder
	return m
end

-- The fish hook from the pictures: shank, J bend with a barbed point, a ring
-- eye at the back and a feather bait. Points along -Z (the bend leads).
local function buildHook(scale)
	scale = scale or 1
	local m = newModel("WiredHook")
	local s = scale
	local metal = Enum.Material.Metal
	local shank = box(m, Vector3.new(0.14, 0.14, 1.4) * s, CFrame.new(), STEEL, metal)
	box(m, Vector3.new(0.14, 0.9, 0.14) * s, CFrame.new(0, -0.38 * s, -0.7 * s), STEEL, metal) -- bend down
	box(m, Vector3.new(0.14, 0.14, 0.52) * s, CFrame.new(0, -0.8 * s, -0.5 * s), STEEL, metal) -- bottom of the J
	box(m, Vector3.new(0.14, 0.5, 0.14) * s, CFrame.new(0, -0.57 * s, -0.27 * s) * CFrame.Angles(0.15, 0, 0), STEEL, metal) -- point
	box(m, Vector3.new(0.1, 0.26, 0.1) * s, CFrame.new(0, -0.42 * s, -0.37 * s) * CFrame.Angles(-0.75, 0, 0), STEEL, metal) -- barb
	-- Ring eye.
	for _, o in ipairs({ { 0.14, 0, 0.1, 0.34 }, { -0.14, 0, 0.1, 0.34 }, { 0, 0.14, 0.34, 0.1 }, { 0, -0.14, 0.34, 0.1 } }) do
		box(m, Vector3.new(o[3], o[4], 0.1) * s, CFrame.new(o[1] * s, o[2] * s, 0.8 * s), STEEL, metal)
	end
	-- Feather bait.
	box(m, Vector3.new(0.06, 0.32, 0.8) * s, CFrame.new(0, 0.22 * s, 0.95 * s) * CFrame.Angles(0.35, 0, 0), FEATHER)
	box(m, Vector3.new(0.07, 0.18, 0.6) * s, CFrame.new(0, 0.3 * s, 0.9 * s) * CFrame.Angles(0.35, 0, 0), FEATHER_LIGHT)
	m.PrimaryPart = shank
	return m
end

-- The winch from the picture: a cable drum with side wheels, axis along X.
local function buildWinch(scale)
	local m = newModel("WiredWinch")
	local s = scale or 1
	local metal = Enum.Material.Metal
	local hub = box(m, Vector3.new(0.9, 0.5, 0.5) * s, CFrame.new(), CABLE, metal)
	for _, side in ipairs({ -1, 1 }) do
		local cf = CFrame.new(side * 0.5 * s, 0, 0)
		box(m, Vector3.new(0.12, 1.0, 0.86) * s, cf, STEEL, metal)
		box(m, Vector3.new(0.12, 0.62, 1.0) * s, cf, STEEL, metal)
		box(m, Vector3.new(0.12, 1.0, 0.62) * s, cf, STEEL, metal)
		box(m, Vector3.new(0.14, 0.2, 0.2) * s, cf, PAN, metal) -- axle cap
	end
	-- Cable wound round the drum (stripes so the spin reads).
	for i = 0, 3 do
		box(m, Vector3.new(0.86, 0.08, 0.62) * s, CFrame.Angles(i * math.pi / 4, 0, 0), Color3.fromRGB(120, 124, 135), metal)
	end
	m.PrimaryPart = hub
	return m
end

local function mouthCF(character)
	local head = character and character:FindFirstChild("Head")
	if not head then
		local root = Common.rootOf(character)
		return root and root.CFrame * CFrame.new(0, 1.3, -0.8)
	end
	local s = head.Size.Y / 1.2
	return head.CFrame * CFrame.new(0, -0.3 * s, -0.65 * s)
end

local function torsoPos(model)
	local part = model and (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart"))
	return part and part.Position
end

local function characterById(userId)
	local player = userId and Players:GetPlayerByUserId(userId)
	return player and player.Character
end

---------------------------------------------------------------------------
-- Cables: a thin steel bar stretched between two points, updated every frame
---------------------------------------------------------------------------
local function newCable(width)
	return VFXLib.part({ Size = Vector3.new(width or 0.09, width or 0.09, 1), Color = CABLE, Material = Enum.Material.Metal })
end

local function setCable(cable, a, b)
	local d = (b - a).Magnitude
	if d < 0.05 then
		cable.Transparency = 1
		return
	end
	cable.Transparency = 0
	local w = cable.Size.X
	cable.Size = Vector3.new(w, w, d)
	cable.CFrame = CFrame.lookAt((a + b) / 2, b)
end

--[[ A cable from `getA()` to `getB()` with a hook at the B end, for `duration`
     seconds. getA/getB return a Vector3 or nil (nil = that end is gone). ]]
local function holdLine(getA, getB, duration, opts)
	opts = opts or {}
	local entry = {
		GetA = getA,
		GetB = getB,
		Cable = newCable(opts.Width),
		Hook = opts.NoHook and nil or buildHook(opts.HookScale or 1),
		Expire = os.clock() + duration,
		Shake = opts.Shake or 0,
	}
	table.insert(lines, entry)
	return entry
end

local function dropLine(entry)
	entry.Cable:Destroy()
	if entry.Hook then
		entry.Hook:Destroy()
	end
end

local function stepLines()
	local now = os.clock()
	for i = #lines, 1, -1 do
		local e = lines[i]
		local a, b = e.GetA(), e.GetB()
		if now > e.Expire or not a or not b then
			table.remove(lines, i)
			dropLine(e)
		else
			if e.Shake > 0 then
				-- A taut cable thrums.
				b = b + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * e.Shake
			end
			setCable(e.Cable, a, b)
			if e.Hook then
				local dir = (b - a).Magnitude > 0.1 and (b - a).Unit or Vector3.new(0, 0, -1)
				e.Hook:PivotTo(CFrame.lookAt(b, b + dir))
			end
		end
	end
end

---------------------------------------------------------------------------
-- Winch at the mouth
---------------------------------------------------------------------------
local function startWinch(character, duration)
	local w = winches[character]
	if w then
		w.Expire = math.max(w.Expire, os.clock() + duration)
		return
	end
	winches[character] = { Model = buildWinch(0.9), Angle = 0, Expire = os.clock() + duration }
end

local function stepWinches(dt)
	local now = os.clock()
	for character, w in pairs(winches) do
		local cf = character.Parent and mouthCF(character)
		if not cf or now > w.Expire then
			w.Model:Destroy()
			winches[character] = nil
		else
			w.Angle = w.Angle + dt * 25
			w.Model:PivotTo(cf * CFrame.new(0, 0, -0.55) * CFrame.Angles(w.Angle, 0, 0))
		end
	end
end

---------------------------------------------------------------------------
-- Water
---------------------------------------------------------------------------
local function splash(position, size)
	size = size or 1
	VFXLib.burst(position, { Count = math.floor(16 * size), Texture = VFXLib.Textures.Smoke, Color = WATER_LIGHT, LightEmission = 0.3, Speed = 22 * size, Lifetime = 0.55, Spread = 35, Direction = Vector3.new(0, 1, 0), Acceleration = Vector3.new(0, -60, 0) })
	VFXLib.burst(position, { Count = math.floor(10 * size), Color = WATER, Speed = 16 * size, Lifetime = 0.4 })
	TuskVFX.CreateRotationalShockwave(CFrame.new(position), { Radius = 3.5 * size, Layers = 1, Color = WATER_LIGHT, Color2 = WATER, Ground = true, Particles = 0.3, Width = 0.2, Duration = 0.4 })
end

local function buildPuddle(position, diameter)
	local m = newModel("WiredPuddle")
	local cf = CFrame.new(position + Vector3.new(0, 0.06, 0))
	local water = roundPlate(m, diameter, 0.1, cf, WATER, Enum.Material.Glass, 0.25)
	roundPlate(m, diameter * 0.55, 0.12, cf, WATER_LIGHT, Enum.Material.Neon, 0.6)
	m.PrimaryPart = water
	return m
end

-- A frying pan of water with a feather bait bobbing above it.
local function buildPan(position)
	local m = newModel("BaitPan")
	local base = CFrame.new(position + Vector3.new(0, 0.15, 0))
	local metal = Enum.Material.Metal
	local core = roundPlate(m, 3.2, 0.25, base, PAN, metal)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		box(m, Vector3.new(1.3, 0.45, 0.22), base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.25, -1.5), PAN, metal)
	end
	box(m, Vector3.new(0.35, 0.2, 2.2), base * CFrame.new(0, 0.3, 2.5), Color3.fromRGB(90, 60, 40)) -- handle
	roundPlate(m, 2.8, 0.1, base * CFrame.new(0, 0.32, 0), WATER, Enum.Material.Glass, 0.2)
	m.PrimaryPart = core
	local bait = buildHook(0.8)
	return m, bait
end

---------------------------------------------------------------------------
-- Hook projectiles (server Kind "WiredHook")
---------------------------------------------------------------------------
local function spawnHook(data)
	local owner = characterById(data.OwnerId)
	local v = {
		Model = buildHook(1.1),
		Cable = newCable(0.1),
		Owner = owner,
		Origin = data.Origin,
		Direction = data.Direction,
		Speed = data.Speed,
		Range = data.Range,
		ServerTime = data.ServerTime,
		Expire = os.clock() + data.Range / math.max(data.Speed, 1) + 1,
	}
	hooks[data.Id] = v
	if owner then
		startWinch(owner, data.Range / math.max(data.Speed, 1) + 0.2)
	end
end

local function hookPos(v)
	local distance = math.min(v.Speed * (workspace:GetServerTimeNow() - v.ServerTime), v.Range)
	return v.Origin + v.Direction * math.max(distance, 0)
end

local function removeHook(v)
	v.Model:Destroy()
	v.Cable:Destroy()
end

-- A miss: the hook whips back into his mouth.
local function retract(owner, from)
	local model = buildHook(1.1)
	local cable = newCable(0.1)
	VFXLib.animate(0.25, function(a)
		local m = owner and owner.Parent and mouthCF(owner)
		if not m then
			return
		end
		local p = from:Lerp(m.Position, VFXLib.easeInOut(a))
		local dir = (p - m.Position).Magnitude > 0.1 and (p - m.Position).Unit or Vector3.new(0, 0, -1)
		model:PivotTo(CFrame.lookAt(p, p + dir) * CFrame.Angles(0, 0, a * 6))
		setCable(cable, m.Position, p)
	end, function()
		model:Destroy()
		cable:Destroy()
	end)
end

local function endHook(data)
	local v = hooks[data.Id]
	if not v then
		return
	end
	hooks[data.Id] = nil
	removeHook(v)
	if not data.HitCharacter then
		VFXLib.burst(data.Position, { Count = 8, Color = STEEL, Speed = 18, Lifetime = 0.25 })
		VFXLib.sound(sounds.NailImpact, data.Position, 0.3, 1.5)
		retract(v.Owner, data.Position)
	end
end

local function stepHooks()
	local now = os.clock()
	for id, v in pairs(hooks) do
		local pos = hookPos(v)
		v.Model:PivotTo(CFrame.lookAt(pos, pos + v.Direction))
		local m = v.Owner and v.Owner.Parent and mouthCF(v.Owner)
		setCable(v.Cable, m and m.Position or v.Origin, pos)
		if now > v.Expire then
			hooks[id] = nil
			removeHook(v)
		end
	end
end

---------------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------------
local function mouthGetter(character)
	return function()
		local m = character and character.Parent and mouthCF(character)
		return m and m.Position
	end
end

local function targetGetter(target)
	return function()
		return target and target.Parent and torsoPos(target)
	end
end

local function onM1(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local index = data.Index
	TuskAnimation.play(character, "P_M1_" .. index)
	VFXLib.sound(sounds.Swing, root, 0.5, 1.1 + index * 0.06)
	if index <= 2 then
		Common.swipe(root, index == 1 and 1 or -1, index == 1 and pal.Main or pal.Light)
	elseif index == 3 then
		-- A hook lashes out of his mouth and snaps back.
		local model = buildHook(0.9)
		local cable = newCable(0.08)
		VFXLib.animate(0.28, function(a)
			local m = character.Parent and mouthCF(character)
			if not m then
				return
			end
			local reach = math.sin(a * math.pi) * 6
			local p = (m * CFrame.new(math.sin(a * math.pi * 2) * 0.8, 0, -reach)).Position
			model:PivotTo(CFrame.lookAt(p, p + m.LookVector) * CFrame.Angles(0, 0, a * 8))
			setCable(cable, m.Position, p)
		end, function()
			model:Destroy()
			cable:Destroy()
		end)
		TuskVFX.CreateCrescent(root.CFrame * CFrame.new(0, 1.2, -2.4), { Radius = 3, Width = 0.2, Color = STEEL, Color2 = pal.Light, Sweep = 2, Duration = 0.2 })
	end
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "WiredHook" then
		if phase == "Startup" and root then
			TuskAnimation.play(character, "PPHookSpit")
			VFXLib.sound(sounds.Warning, root, 0.3, 1.6)
		elseif phase == "Snag" and data.Target then
			TuskAnimation.play(character, "PPReel")
			startWinch(character, data.Duration + 0.2)
			holdLine(mouthGetter(character), targetGetter(data.Target), data.Duration + 0.15, { Width = 0.1, HookScale = 1.1, Shake = 0.08 })
			local tp = torsoPos(data.Target)
			if tp then
				VFXLib.burst(tp, { Count = 14, Color = STEEL, Speed = 24, Lifetime = 0.3 })
				TuskVFX.CreateImpactStar(tp, { Size = 4, Rays = 7, Color = pal.Main, Color2 = STEEL, Duration = 0.2 })
			end
			VFXLib.sound(sounds.Hit, root or data.Target, 0.6, 1.2)
			if Common.isLocal(character) or Common.isLocal(data.Target) then
				CameraFX.shake(0.3, 0.25)
			end
		end
	elseif move == "BaitPan" then
		if phase == "Startup" and character then
			TuskAnimation.play(character, "PPBaitToss")
		elseif phase == "Place" then
			local model, bait = buildPan(data.Position)
			pans[data.Id] = { Model = model, Bait = bait, Position = data.Position, Expire = os.clock() + (data.Duration or 10) + 1, T = 0, NextRipple = 0 }
			splash(data.Position + Vector3.new(0, 0.5, 0), 0.7)
			VFXLib.sound(sounds.NailImpact, data.Position, 0.4, 0.7)
		elseif phase == "Trigger" or phase == "Expire" then
			local pan = pans[data.Id]
			if pan then
				pans[data.Id] = nil
				pan.Model:Destroy()
				pan.Bait:Destroy()
			end
			local water = data.Position + Vector3.new(0, 0.5, 0)
			splash(water, phase == "Trigger" and 1.3 or 0.6)
			if phase == "Trigger" then
				-- Hooks burst out of the water and hoist whoever went for the bait.
				for _, target in ipairs(data.Targets or {}) do
					holdLine(function()
						return water
					end, targetGetter(target), (data.SlamAfter or 0.5) + 0.35, { Width = 0.1, HookScale = 1.1, Shake = 0.05 })
					task.delay((data.SlamAfter or 0.5) + 0.25, function()
						local tp = torsoPos(target)
						if tp then
							TuskVFX.CreateImpact(tp - Vector3.new(0, 2.5, 0), Vector3.new(0, 1, 0), { Size = 1.2, Radius = 5, Layers = 2, Color = pal.Main, Color2 = STEEL, Sound = sounds.NailImpact, Pitch = 0.7 })
							TuskVFX.CreateGroundCracks(tp, { Radius = 4.5, Count = 5, Color = pal.Second, Duration = 1.2 })
							CameraFX.shakeAt(tp, 0.45, 40)
						end
					end)
				end
				VFXLib.sound(sounds.Hit, data.Position, 0.7, 0.9)
				CameraFX.shakeAt(data.Position, 0.35, 40)
			end
		end
	elseif move == "DoubleHookLift" then
		if phase == "Startup" and character then
			TuskAnimation.play(character, "PPHoist")
			VFXLib.sound(sounds.Warning, root or character, 0.35, 1.3)
		elseif phase == "Hoist" and root then
			local targets = data.Targets or {}
			startWinch(character, (data.SlamAfter or 0.55) + 0.3)
			if #targets == 0 then
				-- Both hooks shoot out, catch nothing, and whip back.
				for side = -1, 1, 2 do
					local reach = data.Range or 20
					local model = buildHook(1)
					local cable = newCable(0.09)
					VFXLib.animate(0.45, function(a)
						local m = character.Parent and mouthCF(character)
						if not m then
							return
						end
						local out = math.sin(a * math.pi)
						local p = (m * CFrame.new(side * out * 2.5, 0, -out * reach)).Position
						model:PivotTo(CFrame.lookAt(p, p + m.LookVector))
						setCable(cable, m.Position, p)
					end, function()
						model:Destroy()
						cable:Destroy()
					end)
				end
			else
				for _, target in ipairs(targets) do
					holdLine(mouthGetter(character), targetGetter(target), (data.SlamAfter or 0.55) + 0.3, { Width = 0.11, HookScale = 1.15, Shake = 0.1 })
					local tp = torsoPos(target)
					if tp then
						VFXLib.burst(tp, { Count = 14, Color = STEEL, Speed = 24, Lifetime = 0.3 })
					end
				end
				VFXLib.sound(sounds.Hit, root, 0.7, 0.9)
				if Common.isLocal(character) then
					CameraFX.shake(0.35, 0.3)
				end
			end
		elseif phase == "Slam" then
			TuskVFX.CreateImpact(data.Position - Vector3.new(0, 2.5, 0), Vector3.new(0, 1, 0), { Size = 1.4, Radius = data.Radius or 6, Layers = 2, Color = pal.Main, Color2 = STEEL, Sound = sounds.NailImpact, Pitch = 0.6 })
			TuskVFX.CreateGroundCracks(data.Position, { Radius = data.Radius or 6, Count = 6, Color = pal.Second, Duration = 1.4 })
			CameraFX.shakeAt(data.Position, 0.6, 50)
		end
	end
end

local function clearPuddles()
	for _, p in ipairs(puddles) do
		p.Model:Destroy()
		if p.Bait then
			p.Bait:Destroy()
		end
	end
	puddles = {}
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Start" then
		TuskAnimation.play(character, "PPWinch")
		clearPuddles()
		for i, pos in ipairs(data.Puddles or {}) do
			task.delay((i - 1) * 0.08, function()
				local bait = buildHook(0.7)
				table.insert(puddles, { Model = buildPuddle(pos, 4), Bait = bait, Position = pos, T = i, Expire = os.clock() + 4 })
				splash(pos + Vector3.new(0, 0.3, 0), 0.6)
			end)
		end
		if root then
			VFXLib.flash(root.Position, WATER_LIGHT, 3, 30, 0.5)
		end
		if Common.isLocal(character) then
			TuskVFX.ScreenTint(data.Windup or 1, { Tint = WATER_LIGHT })
			CameraFX.fovPunch(-6, 0.5)
		end
	elseif data.Phase == "Snag" then
		local reel = data.ReelTime or 1.3
		startWinch(character, reel + 0.6)
		for k, target in ipairs(data.Targets or {}) do
			local puddle = data.Puddles and data.Puddles[data.From and data.From[k] or 1]
			if puddle then
				local water = puddle + Vector3.new(0, 0.3, 0)
				splash(water, 1.2)
				-- Out of the water first...
				holdLine(function()
					return water
				end, targetGetter(target), 0.3, { Width = 0.11, HookScale = 1.1 })
			end
			-- ...then the cable swings over to his mouth and the winch reels.
			task.delay(0.25, function()
				holdLine(mouthGetter(character), targetGetter(target), reel + 0.1, { Width = 0.12, HookScale = 1.15, Shake = 0.12 })
			end)
		end
		if root then
			VFXLib.sound(sounds.Hit, root, 0.8, 0.8)
		end
		if Common.isLocal(character) then
			CameraFX.shake(0.5, reel)
		end
	elseif data.Phase == "Slam" then
		clearPuddles()
		Common.finisher({ Character = character, Position = data.Position, Radius = data.Radius, Hit = true }, pal, { Size = 1.6, Layers = 3, Shake = 0.9 })
		splash(data.Position, 1.6)
		if Common.isLocal(character) then
			CameraFX.impactFrame(WATER_LIGHT)
		end
	end
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local function stepPans(dt)
	local now = os.clock()
	for id, pan in pairs(pans) do
		if now > pan.Expire then
			pans[id] = nil
			pan.Model:Destroy()
			pan.Bait:Destroy()
		else
			pan.T = pan.T + dt
			local p = pan.Position + Vector3.new(0, 2.6 + math.sin(pan.T * 2.4) * 0.35, 0)
			pan.Bait:PivotTo(CFrame.new(p) * CFrame.Angles(math.pi / 2, pan.T * 0.8, math.sin(pan.T * 3) * 0.3))
			if now >= pan.NextRipple then
				pan.NextRipple = now + 0.8
				TuskVFX.CreateRotationalShockwave(CFrame.new(pan.Position + Vector3.new(0, 0.5, 0)), { Radius = 1.6, Layers = 1, Color = WATER_LIGHT, Color2 = WATER, Ground = true, Particles = 0, Width = 0.08, Duration = 0.7 })
			end
		end
	end
	for i = #puddles, 1, -1 do
		local pd = puddles[i]
		if now > pd.Expire then
			pd.Model:Destroy()
			pd.Bait:Destroy()
			table.remove(puddles, i)
		else
			pd.T = pd.T + dt
			pd.Bait:PivotTo(CFrame.new(pd.Position + Vector3.new(0, 2 + math.sin(pd.T * 3) * 0.3, 0)) * CFrame.Angles(math.pi / 2, pd.T, 0))
		end
	end
end

local function stepStance()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local want = character:GetAttribute("TuskAct") == ACT
			if want and not stanced[character] then
				stanced[character] = true
				TuskAnimation.hold(character, "PPStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "PPStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function PorkPie.handle(name, data)
	if name == "M1" then
		onM1(data)
	elseif name == "M1Finisher" then
		Common.finisher(data, pal)
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

local slowTimer = 0
function PorkPie.step(dt)
	dt = dt or 1 / 60
	stepHooks()
	stepLines()
	stepWinches(dt)
	stepPans(dt)
	slowTimer = slowTimer + dt
	if slowTimer > 0.2 then
		slowTimer = 0
		stepStance()
	end
end

-- Hook projectiles come through the shared SpinFX channel.
Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
	if typeof(data) ~= "table" or data.Kind ~= "WiredHook" then
		return
	end
	if name == "ProjectileSpawn" then
		spawnHook(data)
	elseif name == "ProjectileEnd" then
		endHook(data)
	end
end)

return PorkPie
end
end
