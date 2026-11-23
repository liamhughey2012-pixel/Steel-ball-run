--[[
	Blackmore_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Blackmore: Catch the Rainbow.
	Its other half is Blackmore_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: BlackmoreVFX
-- ======================================================================
__modules["BlackmoreVFX"] = function()
--[[
	TuskActVFX.BlackmoreVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.BlackmoreVFX)

	Client visuals for Blackmore / CATCH THE RAINBOW: raindrops frozen in
	mid-air. Blocky like the rest of the game.
	  * his UMBRELLA is always in his left hand (closed, like a cane); it
	    opens above his head during the storm
	  * RAINDROP BLADES: drops freeze in a fan in front of him, shiver, fire
	  * RAINDROP STEP: a stair of frozen drops hangs in the air along his dash
	    for a few seconds, then falls and splashes
	  * RAINDROP CAGE: a dome of frozen drops follows the target; each cut flashes
	  * CATCH THE RAINBOW: a dark cloud, a downpour, a rainbow arc overhead,
	    frozen drops hanging everywhere; he scatters into raindrops when hit;
	    the end: every drop fires inward
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Common = __require("TuskActCommon")
local Fighters = __require("Fighters")

local BlackmoreVFX = {}
local ACT = 11
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds

local DROP = Color3.fromRGB(150, 205, 255)
local DROP_LIGHT = Color3.fromRGB(225, 245, 255)
local CANOPY = Color3.fromRGB(40, 60, 120)
local CANOPY_TRIM = Color3.fromRGB(110, 170, 240)
local SHAFT = Color3.fromRGB(30, 30, 36)
local RAINBOW = {
	Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 150, 60), Color3.fromRGB(255, 230, 80), Color3.fromRGB(90, 220, 110),
	Color3.fromRGB(80, 170, 255), Color3.fromRGB(110, 100, 230), Color3.fromRGB(180, 110, 230),
}

local umbrellas = {} -- [character] = { Closed, Open }
local stanced = {}
local projectiles = {} -- [id] = flying drop
local cages = {} -- [model] = dome of drops
local storms = {} -- list of active storms

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function box(model, size, cf, color, material, transparency)
	local p = VFXLib.part({ Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, Transparency = transparency or 0 })
	p.Parent = model
	return p
end

local function newDrop(scale)
	local s = scale or 1
	return VFXLib.part({ Size = Vector3.new(0.18, 0.36, 0.18) * s, Color = DROP, Material = Enum.Material.Glass, Transparency = 0.2 })
end

-- Closed umbrella (a cane): handle at the origin, shaft going down -Y.
local function buildClosedUmbrella()
	local m = Instance.new("Model")
	m.Name = "Umbrella"
	m.Parent = VFXLib.Folder
	local grip = box(m, Vector3.new(0.16, 0.5, 0.16), CFrame.new(0, 0.15, 0), SHAFT)
	box(m, Vector3.new(0.16, 0.16, 0.4), CFrame.new(0, 0.42, -0.14), SHAFT) -- hooked handle
	box(m, Vector3.new(0.16, 0.3, 0.16), CFrame.new(0, 0.3, -0.32), SHAFT)
	box(m, Vector3.new(0.08, 2.8, 0.08), CFrame.new(0, -1.3, 0), SHAFT)
	-- Furled canopy: stacked blocks tapering to the tip.
	for i = 0, 3 do
		local w = 0.42 - i * 0.08
		box(m, Vector3.new(w, 0.5, w), CFrame.new(0, -0.9 - i * 0.45, 0), i % 2 == 0 and CANOPY or CANOPY:Lerp(CANOPY_TRIM, 0.2))
	end
	box(m, Vector3.new(0.3, 0.06, 0.3), CFrame.new(0, -0.62, 0), CANOPY_TRIM)
	box(m, Vector3.new(0.06, 0.3, 0.06), CFrame.new(0, -2.85, 0), Color3.fromRGB(190, 195, 205)) -- tip
	m.PrimaryPart = grip
	return m
end

-- Open umbrella: canopy above, handle at the bottom of the shaft (origin = grip).
local function buildOpenUmbrella()
	local m = Instance.new("Model")
	m.Name = "UmbrellaOpen"
	m.Parent = VFXLib.Folder
	local grip = box(m, Vector3.new(0.16, 0.5, 0.16), CFrame.new(), SHAFT)
	box(m, Vector3.new(0.08, 2.6, 0.08), CFrame.new(0, 1.4, 0), SHAFT)
	-- Stepped octagon canopy: wide plates getting smaller toward the top.
	for i = 0, 3 do
		local r = 2.4 - i * 0.55
		local y = 2.5 + i * 0.22
		local color = i % 2 == 0 and CANOPY or CANOPY:Lerp(CANOPY_TRIM, 0.25)
		box(m, Vector3.new(r * 2, 0.16, r * 1.2), CFrame.new(0, y, 0), color)
		box(m, Vector3.new(r * 1.2, 0.16, r * 2), CFrame.new(0, y, 0), color)
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		box(m, Vector3.new(0.08, 0.08, 2.4), CFrame.new(math.cos(a) * 1.2, 2.45, math.sin(a) * 1.2) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(0.15, 0, 0), CANOPY_TRIM)
	end
	box(m, Vector3.new(0.1, 0.4, 0.1), CFrame.new(0, 3.5, 0), Color3.fromRGB(190, 195, 205))
	m.PrimaryPart = grip
	return m
end

local function splash(position, size)
	size = size or 1
	VFXLib.burst(position, { Count = math.floor(10 * size), Color = DROP_LIGHT, Speed = 14 * size, Lifetime = 0.35, Spread = 60, Direction = Vector3.new(0, 1, 0), Acceleration = Vector3.new(0, -40, 0) })
end

-- Drops let go: they fall and splash.
local function release(drops)
	for _, d in ipairs(drops) do
		local from = d.Position
		VFXLib.animate(0.35, function(a)
			d.CFrame = CFrame.new(from - Vector3.new(0, 9 * a * a, 0))
			d.Transparency = 0.2 + a * 0.8
		end, function()
			d:Destroy()
		end)
	end
end

---------------------------------------------------------------------------
-- Umbrella in his hand
---------------------------------------------------------------------------
local function stormOver(character)
	for _, st in ipairs(storms) do
		if st.Character == character then
			return st
		end
	end
	return nil
end

local function stepUmbrellas()
	local seen = {}
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character and character:GetAttribute("TuskAct") == ACT then
			local hand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
			local root = Common.rootOf(character)
			if hand and root then
				seen[character] = true
				local u = umbrellas[character]
				if not u then
					u = { Closed = buildClosedUmbrella(), Open = buildOpenUmbrella() }
					umbrellas[character] = u
				end
				local storm = stormOver(character)
				local down = hand.Name == "Left Arm" and -hand.Size.Y / 2 + 0.2 or -0.15
				if storm then
					-- Open, held above his head.
					u.Closed:PivotTo(CFrame.new(0, -1000, 0))
					u.Open:PivotTo(root.CFrame * CFrame.new(-0.6, 1.4, 0) * CFrame.Angles(0, 0, 0.08))
				else
					-- Closed, carried like a cane.
					u.Open:PivotTo(CFrame.new(0, -1000, 0))
					u.Closed:PivotTo(hand.CFrame * CFrame.new(0, down, 0))
				end
			end
		end
	end
	for character, u in pairs(umbrellas) do
		if not seen[character] then
			u.Closed:Destroy()
			u.Open:Destroy()
			umbrellas[character] = nil
		end
	end
end

---------------------------------------------------------------------------
-- Raindrop projectiles (server Kind "RainDrop")
---------------------------------------------------------------------------
local function spawnDrop(data)
	local d = newDrop(1.4)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.2, 0)
	a0.Parent = d
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.2, 0)
	a1.Parent = d
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(DROP_LIGHT, DROP)
	trail.Lifetime = 0.12
	trail.LightEmission = 0.6
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Parent = d
	projectiles[data.Id] = { Part = d, Origin = data.Origin, Direction = data.Direction, Speed = data.Speed, Range = data.Range, ServerTime = data.ServerTime, Expire = os.clock() + data.Range / math.max(data.Speed, 1) + 0.5 }
end

local function endDrop(data)
	local v = projectiles[data.Id]
	if v then
		projectiles[data.Id] = nil
		v.Part:Destroy()
	end
	splash(data.Position, data.HitCharacter and 0.9 or 0.5)
	if data.HitCharacter then
		TuskVFX.CreateImpactStar(data.Position, { Size = 2.4, Rays = 6, Color = DROP, Color2 = Color3.new(1, 1, 1), Duration = 0.12 })
	end
end

local function stepDrops()
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for id, v in pairs(projectiles) do
		local distance = math.min(v.Speed * (serverNow - v.ServerTime), v.Range)
		local pos = v.Origin + v.Direction * math.max(distance, 0)
		-- Point along the flight, like a streak.
		v.Part.CFrame = CFrame.lookAt(pos, pos + v.Direction) * CFrame.Angles(math.pi / 2, 0, 0)
		if now > v.Expire then
			projectiles[id] = nil
			v.Part:Destroy()
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
	local index = data.Index
	TuskAnimation.play(character, "B_M1_" .. index)
	VFXLib.sound(sounds.Swing, root, 0.5, 1.05 + index * 0.06)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or DROP_LIGHT)
	-- A few frozen shards flick out with each strike.
	for i = 1, 3 do
		local d = newDrop(0.9)
		local dir = (root.CFrame * CFrame.Angles(0, (i - 2) * 0.25, 0)).LookVector
		local from = (root.CFrame * CFrame.new(0, 0.5, -1.5)).Position
		VFXLib.animate(0.18, function(a)
			local p = from + dir * 6 * a
			d.CFrame = CFrame.lookAt(p, p + dir) * CFrame.Angles(math.pi / 2, 0, 0)
			d.Transparency = 0.2 + a * 0.8
		end, function()
			d:Destroy()
		end)
	end
end

local function onFinisher(data)
	Common.finisher(data, pal)
	-- A fan of hardened drops bursts out.
	local root = Common.rootOf(data.Character)
	if not root then
		return
	end
	for i = 1, 9 do
		local d = newDrop(1.2)
		local dir = (root.CFrame * CFrame.Angles(0, (i - 5) * 0.18, 0)).LookVector
		local from = data.Position + Vector3.new(0, 0.5, 0)
		VFXLib.animate(0.3, function(a)
			local p = from + dir * 10 * a
			d.CFrame = CFrame.lookAt(p, p + dir) * CFrame.Angles(math.pi / 2, 0, 0)
			d.Transparency = 0.2 + a * 0.8
		end, function()
			d:Destroy()
		end)
	end
end

-- Fibonacci-sphere points for a dome of drops.
local function domePoints(n, radius)
	local pts = {}
	for i = 0, n - 1 do
		local y = 1 - (i / (n - 1)) * 1.4 -- top cap down past the middle
		local r = math.sqrt(math.max(0, 1 - y * y))
		local phi = i * 2.39996
		pts[i + 1] = Vector3.new(math.cos(phi) * r, y, math.sin(phi) * r) * radius
	end
	return pts
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "RaindropBlades" and phase == "Freeze" and root then
		TuskAnimation.play(character, "BMBlades")
		-- Drops freeze in a fan in front of him, shivering, then fire.
		local drops = {}
		local count = (data.Drops or 7) * 3
		local dir = data.Direction or root.CFrame.LookVector
		local base = CFrame.lookAt(root.Position + Vector3.new(0, 1, 0), root.Position + Vector3.new(0, 1, 0) + dir)
		for i = 1, count do
			local t = (i - 1) / (count - 1) - 0.5
			local d = newDrop(1.1)
			local cf = base * CFrame.Angles(0, math.rad(-t * (data.Spread or 34)), 0) * CFrame.new((i % 3 - 1) * 0.3, (i % 3 - 1) * 0.5, -2.5 - (i % 3) * 0.4)
			d.CFrame = cf * CFrame.Angles(math.pi / 2, 0, 0)
			drops[i] = { Part = d, CF = d.CFrame }
		end
		VFXLib.animate(data.Startup or 0.3, function(a)
			for _, d in ipairs(drops) do
				d.Part.CFrame = d.CF + Vector3.new((math.random() - 0.5) * 0.08, (math.random() - 0.5) * 0.08, 0)
			end
		end, function()
			for _, d in ipairs(drops) do
				d.Part:Destroy()
			end
		end)
		VFXLib.sound(sounds.Warning, root, 0.3, 1.8)
	elseif move == "RaindropStep" and phase == "Step" then
		TuskAnimation.play(character, "BMStep")
		local from, to = data.From, data.To
		local steps = math.max(4, math.floor((to - from).Magnitude / 2.2))
		local drops = {}
		for i = 0, steps do
			local p = from:Lerp(to, i / steps) + Vector3.new(0, -2.4 + math.sin(i / steps * math.pi) * 1.2, 0)
			for k = 1, 3 do
				local d = newDrop(1)
				d.CFrame = CFrame.new(p + Vector3.new((k - 2) * 0.5, (k % 2) * 0.3, 0))
				table.insert(drops, d)
			end
			task.delay(i * (data.Travel or 0.25) / steps, function()
				if character and character.Parent then
					VFXLib.afterimage(CFrame.new(from:Lerp(to, i / steps)), 2, DROP)
				end
			end)
		end
		splash(from - Vector3.new(0, 2.5, 0), 0.6)
		-- The drops hang (glinting), then fall.
		local life = data.TrailTime or 3
		VFXLib.animate(life, function(a)
			for i, d in ipairs(drops) do
				if (i + math.floor(a * 30)) % 9 == 0 then
					d.Color = DROP_LIGHT
				else
					d.Color = DROP
				end
			end
		end, function()
			release(drops)
		end)
		if Common.isLocal(character) then
			CameraFX.fovPunch(6, 0.2)
		end
	elseif move == "RaindropCage" then
		if phase == "Startup" and character then
			TuskAnimation.play(character, "BMCage")
		elseif phase == "Cage" and data.Target then
			local pts = domePoints(36, 3.4)
			local drops = {}
			for i, p in ipairs(pts) do
				drops[i] = { Part = newDrop(1), Offset = p }
			end
			cages[data.Target] = { Drops = drops, Expire = os.clock() + (data.Duration or 2.5), Born = os.clock() }
			local tr = Common.rootOf(data.Target)
			if tr then
				splash(tr.Position, 1)
			end
		elseif phase == "Cut" and data.Position then
			VFXLib.burst(data.Position, { Count = 8, Color = DROP_LIGHT, Speed = 18, Lifetime = 0.25 })
			TuskVFX.CreateImpactStar(data.Position, { Size = 2.5, Rays = 6, Color = DROP, Color2 = Color3.new(1, 1, 1), Duration = 0.12 })
		elseif phase == "Miss" and root then
			splash((root.CFrame * CFrame.new(0, 0, -6)).Position - Vector3.new(0, 2, 0), 0.6)
		end
	end
end

-- A rainbow arc over the storm: seven bands of short neon segments.
local function buildRainbow(frame, radius)
	local m = Instance.new("Model")
	m.Name = "Rainbow"
	m.Parent = VFXLib.Folder
	for b, color in ipairs(RAINBOW) do
		local r = radius - (b - 1) * 0.9
		local n = 22
		for i = 0, n - 1 do
			local a0 = i / n * math.pi
			local a1 = (i + 1) / n * math.pi
			local p0 = frame * Vector3.new(math.cos(a0) * r, math.sin(a0) * r, 0)
			local p1 = frame * Vector3.new(math.cos(a1) * r, math.sin(a1) * r, 0)
			local seg = VFXLib.part({ Size = Vector3.new(0.9, 0.9, (p1 - p0).Magnitude + 0.1), Color = color, Material = Enum.Material.Neon, Transparency = 0.35 })
			seg.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
			seg.Parent = m
		end
	end
	return m
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Start" then
		TuskAnimation.play(character, "BMStorm")
		local center = data.Position
		local radius = data.Radius or 22
		local storm = { Character = character, Center = center, Radius = radius, Until = os.clock() + (data.Windup or 0.8) + (data.Duration or 5), Hanging = {}, Next = 0 }
		-- Dark cloud overhead.
		storm.Cloud = Instance.new("Model")
		storm.Cloud.Parent = VFXLib.Folder
		for i = 1, 9 do
			local a = i / 9 * math.pi * 2
			box(storm.Cloud, Vector3.new(12, 3, 12), CFrame.new(center + Vector3.new(math.cos(a) * radius * 0.55, 24 + (i % 3), math.sin(a) * radius * 0.55)), Color3.fromRGB(70, 74, 90), Enum.Material.SmoothPlastic, 0.25)
		end
		box(storm.Cloud, Vector3.new(radius, 3, radius), CFrame.new(center + Vector3.new(0, 25, 0)), Color3.fromRGB(60, 64, 80), Enum.Material.SmoothPlastic, 0.2)
		-- The rainbow arcs over the storm.
		local look = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
		local flatLook = Vector3.new(look.X, 0, look.Z)
		flatLook = flatLook.Magnitude > 0.01 and flatLook.Unit or Vector3.new(0, 0, -1)
		local arcAt = center + flatLook * radius * 0.6 + Vector3.new(0, 2, 0)
		storm.Rainbow = buildRainbow(CFrame.lookAt(arcAt, arcAt + flatLook), radius * 0.9)
		-- Frozen drops hanging all through the area.
		for i = 1, 40 do
			local a = math.random() * math.pi * 2
			local r = math.sqrt(math.random()) * radius
			local d = newDrop(1.2)
			d.CFrame = CFrame.new(center + Vector3.new(math.cos(a) * r, math.random() * 8 - 1, math.sin(a) * r))
			table.insert(storm.Hanging, d)
		end
		table.insert(storms, storm)
		if Common.isLocal(character) then
			TuskVFX.ScreenTint((data.Windup or 0.8) + (data.Duration or 5), { Tint = Color3.fromRGB(190, 205, 235), Saturation = -0.3, Brightness = -0.1 })
		end
		VFXLib.sound(sounds.AwakeningBuild, center, 0.5, 1.3)
	elseif data.Phase == "Scatter" then
		-- He bursts into raindrops and comes back together out of reach.
		local from, to = data.From, data.To
		VFXLib.burst(from, { Count = 30, Color = DROP_LIGHT, Speed = 22, Lifetime = 0.4 })
		for i = 1, 14 do
			local d = newDrop(1.1)
			local off = Vector3.new(math.random() - 0.5, math.random() * 2 - 1, math.random() - 0.5) * 3
			VFXLib.animate(0.25, function(a)
				d.CFrame = CFrame.new((from + off):Lerp(to + off * (1 - a), a))
			end, function()
				d:Destroy()
			end)
		end
		splash(to, 1)
	elseif data.Phase == "Burst" then
		local center = data.Position
		for i = #storms, 1, -1 do
			local st = storms[i]
			if st.Character == character then
				table.remove(storms, i)
				-- Every hanging drop fires inward.
				for _, d in ipairs(st.Hanging) do
					local from = d.Position
					VFXLib.animate(0.2, function(a)
						d.CFrame = CFrame.lookAt(from:Lerp(center + Vector3.new(0, 1, 0), a), center) * CFrame.Angles(math.pi / 2, 0, 0)
					end, function()
						d:Destroy()
					end)
				end
				st.Cloud:Destroy()
				st.Rainbow:Destroy()
			end
		end
		task.delay(0.2, function()
			Common.finisher({ Character = character, Position = center + Vector3.new(0, 1, 0), Radius = data.Radius, Hit = true }, pal, { Size = 1.6, Layers = 3, Shake = 0.9 })
			splash(center, 2.5)
		end)
		if Common.isLocal(character) then
			CameraFX.impactFrame(DROP_LIGHT)
		end
	end
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local function stepCages()
	local now = os.clock()
	for target, cage in pairs(cages) do
		local tr = Common.rootOf(target)
		if not tr or now > cage.Expire then
			cages[target] = nil
			local parts = {}
			for _, d in ipairs(cage.Drops) do
				table.insert(parts, d.Part)
			end
			release(parts)
		else
			local grow = math.min((now - cage.Born) / 0.2, 1)
			for i, d in ipairs(cage.Drops) do
				local jitter = Vector3.new(math.sin(now * 9 + i), math.cos(now * 7 + i), math.sin(now * 8 + i * 2)) * 0.05
				d.Part.CFrame = CFrame.new(tr.Position + d.Offset * grow + jitter)
			end
		end
	end
end

local function stepStorms(dt)
	local now = os.clock()
	for i = #storms, 1, -1 do
		local st = storms[i]
		if now > st.Until + 1 then
			table.remove(storms, i)
			release(st.Hanging)
			st.Cloud:Destroy()
			st.Rainbow:Destroy()
		else
			-- The downpour: streaks falling from the cloud.
			st.Next = st.Next - dt
			while st.Next <= 0 do
				st.Next = st.Next + 0.03
				local a = math.random() * math.pi * 2
				local r = math.sqrt(math.random()) * st.Radius
				local top = st.Center + Vector3.new(math.cos(a) * r, 22, math.sin(a) * r)
				local streak = VFXLib.part({ Size = Vector3.new(0.08, 1.6, 0.08), Color = DROP_LIGHT, Material = Enum.Material.Glass, Transparency = 0.35 })
				VFXLib.animate(0.45, function(t)
					streak.CFrame = CFrame.new(top - Vector3.new(0, 24 * t, 0))
				end, function()
					streak:Destroy()
				end)
			end
			-- Hanging drops glint.
			for k, d in ipairs(st.Hanging) do
				d.Color = (k + math.floor(now * 12)) % 11 == 0 and DROP_LIGHT or DROP
			end
		end
	end
end

local function stepStance()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character then
			local want = character:GetAttribute("TuskAct") == ACT
			if want and not stanced[character] then
				stanced[character] = true
				TuskAnimation.hold(character, "BMStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "BMStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function BlackmoreVFX.handle(name, data)
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
function BlackmoreVFX.step(dt)
	dt = dt or 1 / 60
	stepUmbrellas()
	stepDrops()
	stepCages()
	stepStorms(dt)
	slowTimer = slowTimer + dt
	if slowTimer > 0.2 then
		slowTimer = 0
		stepStance()
	end
end

Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
	if typeof(data) ~= "table" or data.Kind ~= "RainDrop" then
		return
	end
	if name == "ProjectileSpawn" then
		spawnDrop(data)
	elseif name == "ProjectileEnd" then
		endDrop(data)
	end
end)

return BlackmoreVFX
end
end
