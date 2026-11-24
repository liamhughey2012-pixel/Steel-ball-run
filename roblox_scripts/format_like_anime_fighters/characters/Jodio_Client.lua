--[[
	Jodio_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Jodio Joestar (The JOJOLands): November Rain.
	Its other half is Jodio_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: JodioVFX
-- ======================================================================
__modules["JodioVFX"] = function()
--[[
	TuskActVFX.JodioVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.JodioVFX)

	Client visuals for Jodio Joestar (The JOJOLands) / NOVEMBER RAIN. Blocky.
	  * November Rain (NovemberRainStand) floats behind him with a pale blue
	    aura and punches with him; he slouches, one hand behind his head
	  * HEAVY RAIN: a dark storm cloud puffs up over the spot, a blue ring
	    marks its edge on the ground, and heavy rain hammers down under it,
	    splashing where it lands
	  * RAIN BULLETS (server Kind "RainDrop"): fat blue drops that streak
	    out and burst into spray
	  * RAIN JET: he surfs forward on a gushing stream of rain
	  * SOAKED: soaked fighters drip
	  * TORRENT: "NOVEMBER RAIN", a huge cloud follows him and the sky goes
	    grey-blue for whoever's under it; when it ends, columns of rain slam
	    down on everyone under it
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local TuskStandModels = __require("TuskStandModels")
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Common = __require("TuskActCommon")
local Fighters = __require("Fighters")
local TuskStand = __require("TuskStand")
local NovemberRainStand = __require("NovemberRainStand")

local JodioVFX = {}
local ACT = 17
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, NovemberRainStand.build, { Aura = NovemberRainStand.Aura, AuraLight = NovemberRainStand.AuraLight, Offset = NovemberRainStand.Offset })

local CLOUD = Color3.fromRGB(70, 76, 92)
local CLOUD_LIGHT = Color3.fromRGB(110, 118, 136)
local RAIN = Color3.fromRGB(120, 190, 250)
local SPLASH = Color3.fromRGB(190, 225, 255)
local MAX_DROPS = 160
local CLOUD_HEIGHT = 20

local clouds = {} -- list of { Center, Follow, Radius, Until, Puffs, Ring, Rate, Carry }
local drops = {} -- falling rain streaks
local bullets = {} -- [projectile id] = flying drop
local stanced = {}
local dripNext = {}

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
	return r ~= nil and (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude <= range
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

local function splash(pos, size)
	local ring = VFXLib.part({ Size = Vector3.new(0.1, 0.4, 0.4), Shape = Enum.PartType.Cylinder, Color = SPLASH, Material = Enum.Material.Neon, Transparency = 0.3 })
	local at = pos + Vector3.new(0, 0.1, 0)
	VFXLib.animate(0.25, function(a)
		local d = (size or 1.6) * VFXLib.easeOut(a)
		ring.Size = Vector3.new(0.1, d, d)
		ring.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Transparency = 0.3 + 0.7 * a
	end, function()
		ring:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Storm clouds and the rain under them
---------------------------------------------------------------------------
local function cloudCenter(c)
	if c.Follow then
		local r = Common.rootOf(c.Follow)
		if r then
			c.Center = ground(r.Position)
		end
	end
	return c.Center
end

local function newCloud(center, radius, duration, follow, rate)
	local c = { Center = center, Follow = follow, Radius = radius, Until = os.clock() + duration, Born = os.clock(), Puffs = {}, Rate = rate or (radius * 5), Carry = 0 }
	local count = math.clamp(math.floor(radius / 2), 5, 22)
	for i = 1, count do
		local a = i / count * math.pi * 2 + math.random() * 0.4
		local r = radius * (0.25 + math.random() * 0.65)
		local size = 5 + math.random() * (radius * 0.35)
		local puff = VFXLib.part({ Size = Vector3.new(size, size * 0.7, size), Shape = Enum.PartType.Ball, Color = i % 3 == 0 and CLOUD_LIGHT or CLOUD, Material = Enum.Material.SmoothPlastic, Transparency = 1 })
		table.insert(c.Puffs, { Part = puff, Off = Vector3.new(math.cos(a) * r, math.random() * 2, math.sin(a) * r), Size = size })
	end
	local core = VFXLib.part({ Size = Vector3.new(radius, radius * 0.3, radius), Shape = Enum.PartType.Ball, Color = CLOUD, Material = Enum.Material.SmoothPlastic, Transparency = 1 })
	table.insert(c.Puffs, { Part = core, Off = Vector3.new(0, 1, 0), Size = radius })
	c.Ring = VFXLib.part({ Size = Vector3.new(0.12, radius * 2, radius * 2), Shape = Enum.PartType.Cylinder, Color = RAIN, Material = Enum.Material.Neon, Transparency = 1 })
	table.insert(clouds, c)
	return c
end

local function killCloud(c)
	for _, p in ipairs(c.Puffs) do
		p.Part:Destroy()
	end
	c.Ring:Destroy()
end

local function stepClouds(dt)
	local now = os.clock()
	for i = #clouds, 1, -1 do
		local c = clouds[i]
		local center = cloudCenter(c)
		local age = now - c.Born
		local left = c.Until - now
		local alpha = math.min(age / 0.35, 1) * math.clamp(left / 0.4, 0, 1)
		if left <= 0 or (c.Follow and not c.Follow.Parent) then
			killCloud(c)
			table.remove(clouds, i)
		else
			for k, p in ipairs(c.Puffs) do
				local bob = math.sin(now * 1.3 + k) * 0.4
				p.Part.CFrame = CFrame.new(center + Vector3.new(0, CLOUD_HEIGHT, 0) + p.Off + Vector3.new(0, bob, 0))
				p.Part.Transparency = 1 - alpha * 0.85
			end
			c.Ring.CFrame = CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			c.Ring.Transparency = 1 - alpha * 0.45
			-- Heavy rain under it.
			c.Carry = c.Carry + c.Rate * dt * alpha
			while c.Carry >= 1 and #drops < MAX_DROPS do
				c.Carry = c.Carry - 1
				local a = math.random() * math.pi * 2
				local r = math.sqrt(math.random()) * c.Radius
				local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
				local streak = VFXLib.part({ Size = Vector3.new(0.14, 2.2, 0.14), Color = RAIN, Material = Enum.Material.Neon, Transparency = 0.35 })
				table.insert(drops, { Part = streak, X = x, Z = z, Y = center.Y + CLOUD_HEIGHT - 1, Floor = center.Y })
			end
			c.Carry = math.min(c.Carry, 3)
		end
	end
	for i = #drops, 1, -1 do
		local d = drops[i]
		d.Y = d.Y - 90 * dt
		if d.Y <= d.Floor + 1 then
			if math.random() < 0.35 then
				splash(Vector3.new(d.X, d.Floor, d.Z), 1.4)
			end
			d.Part:Destroy()
			table.remove(drops, i)
		else
			d.Part.CFrame = CFrame.new(d.X, d.Y, d.Z)
		end
	end
end

---------------------------------------------------------------------------
-- RAIN BULLETS (server Kind "RainDrop")
---------------------------------------------------------------------------
local function spawnBullet(data)
	local body = VFXLib.part({ Size = Vector3.new(0.5, 0.5, 1.5), Shape = Enum.PartType.Ball, Color = RAIN, Material = Enum.Material.Glass, Transparency = 0.25 })
	body.Size = Vector3.new(0.55, 0.55, 0.55)
	local tail = VFXLib.part({ Size = Vector3.new(0.18, 0.18, 2.4), Color = SPLASH, Material = Enum.Material.Neon, Transparency = 0.4 })
	bullets[data.Id] = { Body = body, Tail = tail, Origin = data.Origin, Direction = data.Direction, Speed = data.Speed, Range = data.Range, ServerTime = data.ServerTime, Expire = os.clock() + data.Range / math.max(data.Speed, 1) + 0.5 }
end

local function endBullet(data)
	local v = bullets[data.Id]
	if v then
		bullets[data.Id] = nil
		v.Body:Destroy()
		v.Tail:Destroy()
	end
	if data.Position then
		VFXLib.burst(data.Position, { Count = data.HitCharacter and 12 or 6, Color = SPLASH, Speed = 14, Lifetime = 0.35, Acceleration = Vector3.new(0, -40, 0) })
		if data.HitCharacter then
			TuskVFX.CreateImpactStar(data.Position, { Size = 1.8, Rays = 5, Color = RAIN, Color2 = Color3.new(1, 1, 1), Duration = 0.1 })
		end
	end
end

local function stepBullets()
	local now = os.clock()
	for id, v in pairs(bullets) do
		local t = VFXLib.flight(id, v.ServerTime)
		local dist = math.clamp(v.Speed * t, 0, v.Range)
		local pos = v.Origin + v.Direction * dist
		local cf = CFrame.lookAt(pos, pos + v.Direction)
		v.Body.CFrame = cf
		v.Tail.CFrame = cf * CFrame.new(0, 0, 1.3)
		if now > v.Expire + VFXLib.held(id, v.ServerTime) then
			bullets[id] = nil
			v.Body:Destroy()
			v.Tail:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- RAIN JET
---------------------------------------------------------------------------
local function jet(data)
	local character = data.Character
	if character then
		TuskAnimation.play(character, "JDJet")
		TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 0.5, 2.6), Duration = (data.Travel or 0.3) + 0.2 })
	end
	local from, to = data.From, data.To
	if not (from and to) then
		return
	end
	local stream = VFXLib.part({ Size = Vector3.new(1, 1, 1), Shape = Enum.PartType.Cylinder, Color = RAIN, Material = Enum.Material.Glass, Transparency = 0.3 })
	local travel = data.Travel or 0.3
	local base = from - Vector3.new(0, 2, 0)
	VFXLib.animate(travel + 0.6, function(a)
		local t = math.min(a * (travel + 0.6) / travel, 1)
		local tip = (from:Lerp(to, t)) - Vector3.new(0, 2, 0)
		local len = math.max((tip - base).Magnitude, 0.5)
		stream.Size = Vector3.new(len, 1.6, 1.6)
		stream.CFrame = CFrame.lookAt((base + tip) / 2, tip) * CFrame.Angles(0, math.pi / 2, 0)
		stream.Transparency = a < 0.6 and 0.3 or 0.3 + (a - 0.6) / 0.4 * 0.7
		if math.random() < 0.5 then
			VFXLib.burst(tip, { Count = 2, Color = SPLASH, Speed = 10, Lifetime = 0.3 })
		end
	end, function()
		stream:Destroy()
	end)
	VFXLib.sound(sounds.Swing, from, 0.6, 0.7)
	if character and Common.isLocal(character) then
		CameraFX.fovPunch(8, 0.3)
		CameraFX.speedLines(0.3, SPLASH)
	end
end

---------------------------------------------------------------------------
-- TORRENT
---------------------------------------------------------------------------
local stormTint
local function tint(duration)
	if stormTint then
		stormTint:Destroy()
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "JodioTorrent"
	cc.Parent = Lighting
	stormTint = cc
	VFXLib.animate(duration, function(a)
		local k = a < 0.1 and a / 0.1 or (a > 0.85 and (1 - a) / 0.15 or 1)
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(190, 210, 240), k)
		cc.Brightness = -0.08 * k
		cc.Saturation = -0.25 * k
	end, function()
		cc:Destroy()
		if stormTint == cc then
			stormTint = nil
		end
	end)
end

local function crush(data)
	if data.Position then
		splash(ground(data.Position), (data.Radius or 20) * 2)
	end
	for _, pos in ipairs(data.Hits or {}) do
		local at = ground(pos)
		local column = VFXLib.part({ Size = Vector3.new(30, 4, 4), Shape = Enum.PartType.Cylinder, Color = RAIN, Material = Enum.Material.Glass, Transparency = 0.2 })
		VFXLib.animate(0.35, function(a)
			column.CFrame = CFrame.new(at + Vector3.new(0, 15 - a * 15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			column.Size = Vector3.new(30 * (1 - a * 0.7), 4 + a * 2, 4 + a * 2)
			column.Transparency = 0.2 + a * 0.8
		end, function()
			column:Destroy()
		end)
		splash(at, 9)
		VFXLib.burst(at + Vector3.new(0, 1, 0), { Count = 24, Color = SPLASH, Speed = 26, Lifetime = 0.6, Acceleration = Vector3.new(0, -50, 0) })
	end
	if data.Position and nearLocal(data.Position, (data.Radius or 30) + 10) then
		CameraFX.shake(0.9, 0.4)
	end
	VFXLib.sound(sounds.AwakeningBurst or sounds.Swing, data.Position or Vector3.zero, 0.6, 0.6)
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
	TuskAnimation.play(character, "JD_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1, -3.2), Duration = 0.28 })
	VFXLib.sound(sounds.Swing, root, 0.5, 1.0 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or pal.Second)
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "HeavyRain" and phase == "Cloud" and data.Position then
		if character and root then
			TuskAnimation.play(character, "JDCall")
			TuskStand.action(character, "Loom", { Target = CFrame.new(1.4, 2.4, 2.0), Duration = 0.9 })
		end
		newCloud(data.Position, data.Radius or 10, data.Time or 3)
		VFXLib.sound(sounds.Swing, data.Position, 0.5, 0.5)
	elseif move == "RainBullets" and phase == "Aim" and character and root then
		TuskAnimation.play(character, "JDShoot")
		TuskStand.action(character, "Lunge", { Target = CFrame.new(0.6, 1.2, -2.6), Duration = (data.Windup or 0.15) + (data.Time or 0.4) })
	elseif move == "RainJet" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "JDJet")
			VFXLib.burst(root.Position - Vector3.new(0, 2, 0), { Count = 10, Color = SPLASH, Speed = 8, Lifetime = 0.4 })
		elseif phase == "Jet" then
			jet(data)
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Charge" and character and root then
		TuskAnimation.play(character, "JDTorrent")
		TuskStand.action(character, "Loom", { Target = CFrame.new(1.4, 2.6, 2.0), Duration = (data.Windup or 0.8) + 0.8 })
		label(character:FindFirstChild("Head"), "NOVEMBER RAIN", pal.Main, 1.8, 320)
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.0)
	elseif data.Phase == "Storm" and character and root then
		newCloud(ground(root.Position), data.Radius or 35, data.Duration or 6, character, (data.Radius or 35) * 2.5)
		if nearLocal(root.Position, data.Radius or 35) then
			tint(data.Duration or 6)
		end
	elseif data.Phase == "End" and character then
		for _, c in ipairs(clouds) do
			if c.Follow == character then
				c.Until = math.min(c.Until, os.clock() + 0.4)
			end
		end
	elseif data.Phase == "Crush" then
		crush(data)
		if character then
			for _, c in ipairs(clouds) do
				if c.Follow == character then
					c.Until = math.min(c.Until, os.clock() + 0.5)
				end
			end
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
				TuskAnimation.hold(character, "JDStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "JDStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

-- Soaked fighters drip.
local function stepSoaked()
	local t = workspace:GetServerTimeNow()
	local now = os.clock()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character and (character:GetAttribute("SoakedUntil") or 0) > t and now >= (dripNext[character] or 0) then
			dripNext[character] = now + 0.3
			local head = character:FindFirstChild("Head")
			if head then
				VFXLib.burst(head.Position, { Count = 2, Color = RAIN, Speed = 2, Lifetime = 0.6, Acceleration = Vector3.new(0, -30, 0) })
			end
		end
	end
	for character in pairs(dripNext) do
		if not character.Parent then
			dripNext[character] = nil
		end
	end
end

function JodioVFX.handle(name, data)
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
function JodioVFX.step(dt)
	dt = dt or 1 / 60
	stepClouds(dt)
	stepBullets()
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
		stepSoaked()
	end
end

Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
	if typeof(data) ~= "table" or data.Kind ~= "RainDrop" then
		return
	end
	if name == "ProjectileSpawn" then
		spawnBullet(data)
	elseif name == "ProjectileEnd" then
		endBullet(data)
	end
end)

return JodioVFX
end

-- ======================================================================
-- MODULE: NovemberRainStand
-- ======================================================================
__modules["NovemberRainStand"] = function()
--[[
	TuskActVFX.NovemberRainStand  (StarterPlayerScripts.SpinClient.TuskActVFX.NovemberRainStand)

	NOVEMBER RAIN (Jodio Joestar, The JOJOLands), blocky, matched to the
	art: a sleek white figure.
	  * a rounded white helmet with a dark visor and two cyan lights, a fin
	    down the middle
	  * long light-blue streamers flowing back from its head like a mane
	  * two long hoses arching out of its back and curving down past its
	    feet, banded in grey
	  * a blue raindrop on its chest, blue bands on its forearms and knees
	Registered with TuskStandModels by JodioVFX, so TuskStand floats it
	behind Jodio (players and NPCs) with a pale blue aura.
]]

local NovemberRainStand = {}

local BODY = Color3.fromRGB(236, 240, 248)
local PANEL = Color3.fromRGB(196, 206, 222)
local BLUE = Color3.fromRGB(120, 190, 245)
local BLUE_DEEP = Color3.fromRGB(70, 140, 220)
local VISOR = Color3.fromRGB(40, 50, 80)
local LIGHT = Color3.fromRGB(140, 240, 255)
local HOSE_BAND = Color3.fromRGB(150, 160, 180)

NovemberRainStand.Aura = Color3.fromRGB(150, 210, 255)
NovemberRainStand.AuraLight = Color3.fromRGB(220, 240, 255)
NovemberRainStand.Offset = CFrame.new(2.2, 1.6, 2.8)

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

-- A hose along a list of points (in the parent's space): a tube between
-- each pair, a grey band at each joint.
local function hose(model, parent, points, d)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		-- Cylinders run along X: aim X from a to b.
		local look = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0)
		cyl(model, parent, "Hose", len + d * 0.4, d, BODY, look)
		ball(model, parent, "HoseBand", d * 1.25, HOSE_BAND, CFrame.new(b))
	end
end

function NovemberRainStand.build(scale)
	local s = (scale or 1) * 0.85
	local model = Instance.new("Model")
	model.Name = "NovemberRain"
	local rig = { Joints = {} }

	local torso = newPart(model, "Body", Vector3.new(1.7, 1.7, 0.9) * s, BODY)
	torso.Anchored = true
	torso.Massless = false
	torso.CFrame = CFrame.new()
	model.PrimaryPart = torso
	rig.Body = torso
	local front = -0.46 * s
	box(model, torso, "ChestPlate", Vector3.new(1.4, 0.8, 0.08) * s, PANEL, CFrame.new(0, 0.35 * s, front - 0.02 * s))
	-- A blue raindrop on its chest.
	box(model, torso, "Drop", Vector3.new(0.36, 0.36, 0.06) * s, BLUE, CFrame.new(0, 0.32 * s, front - 0.07 * s) * CFrame.Angles(0, 0, math.pi / 4))
	ball(model, torso, "DropBulb", 0.42 * s, BLUE, CFrame.new(0, 0.18 * s, front - 0.02 * s))
	box(model, torso, "Abdomen", Vector3.new(1.1, 0.8, 0.75) * s, PANEL, CFrame.new(0, -1.15 * s, 0))
	box(model, torso, "Hips", Vector3.new(1.3, 0.45, 0.8) * s, BODY, CFrame.new(0, -1.7 * s, 0))
	box(model, torso, "Belt", Vector3.new(1.34, 0.12, 0.84) * s, BLUE_DEEP, CFrame.new(0, -1.5 * s, 0))
	cyl(model, torso, "Neck", 0.5 * s, 0.4 * s, PANEL, CFrame.new(0, 1.05 * s, 0) * ALONG_Y)
	for _, side in ipairs({ -1, 1 }) do
		ball(model, torso, "Shoulder", 0.7 * s, BODY, CFrame.new(side * 1.0 * s, 0.6 * s, 0))
		-- A hose arching up out of its back and curving down past its feet.
		local pts = {
			Vector3.new(side * 0.5, 0.6, 0.5) * s,
			Vector3.new(side * 1.3, 1.9, 1.2) * s,
			Vector3.new(side * 2.4, 2.3, 1.4) * s,
			Vector3.new(side * 3.3, 1.5, 1.0) * s,
			Vector3.new(side * 3.7, 0.0, 0.4) * s,
			Vector3.new(side * 3.6, -1.8, -0.3) * s,
			Vector3.new(side * 3.2, -3.4, -0.9) * s,
		}
		hose(model, torso, pts, 0.22 * s)
		ball(model, torso, "HoseTip", 0.34 * s, BLUE, CFrame.new(pts[#pts]))
	end

	-- Head: a rounded helmet, a dark visor with two lights, a fin.
	local headBase = CFrame.new(0, 1.3 * s, 0)
	local headOffset = CFrame.new(0, 0.5 * s, 0)
	local head, headWeld = box(model, torso, "Head", Vector3.new(0.85, 0.8, 0.85) * s, BODY, headBase * headOffset)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = headOffset }
	ball(model, head, "Dome", 0.9 * s, BODY, CFrame.new(0, 0.25 * s, 0.02 * s))
	box(model, head, "Chin", Vector3.new(0.6, 0.25, 0.7) * s, PANEL, CFrame.new(0, -0.45 * s, -0.04 * s))
	box(model, head, "Visor", Vector3.new(0.9, 0.24, 0.1) * s, VISOR, CFrame.new(0, 0.05 * s, -0.43 * s))
	for _, side in ipairs({ -1, 1 }) do
		box(model, head, "Light", Vector3.new(0.16, 0.08, 0.04) * s, LIGHT, CFrame.new(side * 0.2 * s, 0.05 * s, -0.49 * s), Enum.Material.Neon)
	end
	box(model, head, "Fin", Vector3.new(0.1, 0.35, 0.9) * s, PANEL, CFrame.new(0, 0.62 * s, 0.05 * s))
	-- Long blue streamers flowing back from its head.
	for k = -2, 2 do
		local len = (2.6 - math.abs(k) * 0.35) * s
		local tilt = CFrame.Angles(-0.55 + math.abs(k) * 0.06, k * 0.18, k * 0.14)
		box(model, head, "Streamer", Vector3.new(0.26 * s, len, 0.07 * s), k % 2 == 0 and BLUE or BLUE_DEEP,
			CFrame.new(k * 0.14 * s, 0.35 * s, 0.4 * s) * tilt * CFrame.new(0, -len / 2, 0))
	end

	-- Arms: slim, blue bands on the forearms.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 1.1 * s, 0.4 * s, 0)
		local offset = CFrame.new(0, -1.1 * s, 0)
		local arm, weld = box(model, torso, a[1], Vector3.new(0.45, 2.2, 0.45) * s, BODY, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		ball(model, arm, "Elbow", 0.45 * s, PANEL, CFrame.new(0, 0, 0))
		box(model, arm, "Band", Vector3.new(0.52, 0.14, 0.52) * s, BLUE, CFrame.new(0, -0.55 * s, 0))
		box(model, arm, "Band", Vector3.new(0.52, 0.14, 0.52) * s, BLUE, CFrame.new(0, -0.8 * s, 0))
		local hand = box(model, arm, "Hand", Vector3.new(0.5, 0.45, 0.45) * s, BODY, CFrame.new(0, -1.3 * s, 0))
		for f = -1.5, 1.5 do
			box(model, hand, "Finger", Vector3.new(0.09, 0.38, 0.1) * s, PANEL, CFrame.new(f * 0.11 * s, -0.38 * s, -0.04 * s))
		end
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Position = Vector3.new(0, -0.3 * s, 0)
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Legs: slim, blue knee pads, pointed feet.
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.4 * s, -1.85 * s, 0)
		local offset = CFrame.new(0, -1.2 * s, 0)
		local leg, weld = box(model, torso, "Leg" .. i, Vector3.new(0.5, 2.4, 0.5) * s, BODY, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		box(model, leg, "Knee", Vector3.new(0.56, 0.4, 0.2) * s, BLUE, CFrame.new(0, 0.05 * s, -0.25 * s))
		box(model, leg, "Foot", Vector3.new(0.5, 0.3, 1.0) * s, PANEL, CFrame.new(0, -1.3 * s, -0.2 * s))
		box(model, leg, "Toe", Vector3.new(0.3, 0.2, 0.3) * s, BLUE_DEEP, CFrame.new(0, -1.32 * s, -0.75 * s) * CFrame.Angles(0, math.pi / 4, 0))
	end
	return model, rig
end

return NovemberRainStand
end
end
