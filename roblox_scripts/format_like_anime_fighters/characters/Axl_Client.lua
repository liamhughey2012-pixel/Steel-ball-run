--[[
	Axl_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Axl RO: Civil War.
	Its other half is Axl_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: AxlVFX
-- ======================================================================
__modules["AxlVFX"] = function()
--[[
	TuskActVFX.AxlVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.AxlVFX)

	Client visuals for Axl RO / CIVIL WAR: guilt made real. Blocky.
	  * the CIVIL WAR Stand (CivilWarStand) floats behind him with a crimson
	    aura and strikes with his moves
	  * GUILT (passive): crimson marks above anyone carrying guilt (1-5)
	  * GUILT SPECTERS: pale ghosts rise from his shadow and chase their
	    target, reaching for them, and grab with a flash
	  * ABANDONED JUNK: junk (crates, wheels, chairs, bottles, boots, lamps)
	    materialises round him, shakes, then flies, tumbling; what hits sticks
	    to their body until it falls off
	  * GUILT MEMBRANE: a grey-violet film wraps the target with junk stuck to
	    it and slowly shrinks; in the rain it drips and dissolves faster. The
	    victim's own screen darkens and their guilt whispers at them; at max
	    guilt the crush flattens them
	  * CIVIL WAR: junk piles and specters rise in a ring round him; everyone
	    caught is wrapped; when he's hit he breaks apart into red, yellow and
	    silver pieces and reforms; then every membrane crushes shut
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Net = __require("Net")
local TuskStandModels = __require("TuskStandModels")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Common = __require("TuskActCommon")
local Fighters = __require("Fighters")
local TuskStand = __require("TuskStand")
local CivilWarStand = __require("CivilWarStand")

local AxlVFX = {}
local ACT = 12
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds

-- CIVIL WAR floats behind him (players and NPCs), like Tusk does.
TuskStandModels.register(ACT, CivilWarStand.build, { Aura = CivilWarStand.Aura, AuraLight = CivilWarStand.AuraLight, Offset = CivilWarStand.Offset })

local GHOST = Color3.fromRGB(210, 222, 255)
local SHADOW = Color3.fromRGB(30, 18, 36)
local FILM = Color3.fromRGB(150, 130, 170)
local WATER = Color3.fromRGB(150, 205, 255)
local WOOD = Color3.fromRGB(130, 92, 56)
local WOOD_DARK = Color3.fromRGB(90, 62, 38)
local METAL = Color3.fromRGB(140, 144, 152)
local GLASS = Color3.fromRGB(110, 160, 110)
local LEATHER = Color3.fromRGB(70, 46, 32)
local PIECES = { Color3.fromRGB(196, 46, 40), Color3.fromRGB(234, 208, 128), Color3.fromRGB(190, 196, 206), Color3.fromRGB(90, 52, 110) }

local projectiles = {} -- [id] = flying junk
local hunters = {} -- [id] = specter chasing its target
local marks = {} -- [character] = guilt marks above their head
local stuckJunk = {} -- list of junk stuck to bodies
local membranes = {} -- [character] = film
local stanced = {}

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function box(model, size, cf, color, material, transparency)
	local p = VFXLib.part({ Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, Transparency = transparency or 0 })
	p.Parent = model
	return p
end

local function newModel(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = VFXLib.Folder
	return m
end

-- Move every part of a model built round the origin to `cf` (keeps offsets).
local function place(item, cf)
	for _, p in ipairs(item.Parts) do
		p.CFrame = cf * item.Offsets[p]
	end
end

local function finish(m)
	local item = { Model = m, Parts = {}, Offsets = {} }
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			table.insert(item.Parts, p)
			item.Offsets[p] = p.CFrame
		end
	end
	return item
end

-- A piece of abandoned junk, built round the origin.
local function buildJunk(style, scale)
	local s = scale or 1
	local m = newModel("Junk")
	if style == "Wheel" then
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			box(m, Vector3.new(0.2, 0.62, 0.2) * s, CFrame.new(math.cos(a) * 0.75 * s, math.sin(a) * 0.75 * s, 0) * CFrame.Angles(0, 0, a), WOOD)
		end
		box(m, Vector3.new(1.4, 0.1, 0.1) * s, CFrame.new(), WOOD_DARK)
		box(m, Vector3.new(0.1, 1.4, 0.1) * s, CFrame.new(), WOOD_DARK)
		box(m, Vector3.new(0.3, 0.3, 0.3) * s, CFrame.new(), METAL)
	elseif style == "Chair" then
		box(m, Vector3.new(1, 0.15, 1) * s, CFrame.new(), WOOD)
		box(m, Vector3.new(1, 1, 0.14) * s, CFrame.new(0, 0.55 * s, 0.45 * s), WOOD)
		for _, x in ipairs({ -0.4, 0.4 }) do
			for _, z in ipairs({ -0.4, 0.4 }) do
				box(m, Vector3.new(0.12, 0.8, 0.12) * s, CFrame.new(x * s, -0.45 * s, z * s), WOOD_DARK)
			end
		end
	elseif style == "Bottle" then
		box(m, Vector3.new(0.45, 0.8, 0.45) * s, CFrame.new(), GLASS, Enum.Material.Glass, 0.2)
		box(m, Vector3.new(0.2, 0.4, 0.2) * s, CFrame.new(0, 0.6 * s, 0), GLASS, Enum.Material.Glass, 0.2)
		box(m, Vector3.new(0.22, 0.1, 0.22) * s, CFrame.new(0, 0.82 * s, 0), WOOD_DARK)
	elseif style == "Boot" then
		box(m, Vector3.new(0.5, 0.9, 0.5) * s, CFrame.new(0, 0.2 * s, 0.15 * s), LEATHER)
		box(m, Vector3.new(0.5, 0.35, 0.9) * s, CFrame.new(0, -0.3 * s, -0.1 * s), LEATHER)
	elseif style == "Lamp" then
		box(m, Vector3.new(0.6, 0.12, 0.6) * s, CFrame.new(0, -0.5 * s, 0), METAL)
		box(m, Vector3.new(0.12, 0.8, 0.12) * s, CFrame.new(0, -0.05 * s, 0), METAL)
		box(m, Vector3.new(0.7, 0.45, 0.7) * s, CFrame.new(0, 0.5 * s, 0), Color3.fromRGB(230, 200, 120), Enum.Material.Neon, 0.3)
	else -- Crate
		box(m, Vector3.new(1, 1, 1) * s, CFrame.new(), WOOD)
		for _, y in ipairs({ -0.3, 0.3 }) do
			box(m, Vector3.new(1.04, 0.12, 1.04) * s, CFrame.new(0, y * s, 0), WOOD_DARK)
		end
		box(m, Vector3.new(1.04, 0.12, 1.04) * s, CFrame.new() * CFrame.Angles(0, 0, math.pi / 4), WOOD_DARK)
	end
	return finish(m)
end

-- A pale ghost (a specter of someone they left behind), arms reaching up.
local function buildGhost(scale)
	local s = scale or 1
	local m = newModel("Specter")
	box(m, Vector3.new(1.4, 1.6, 0.8) * s, CFrame.new(0, 0, 0), GHOST, Enum.Material.Neon, 0.45)
	box(m, Vector3.new(1, 1, 1) * s, CFrame.new(0, 1.35 * s, 0), GHOST, Enum.Material.Neon, 0.4)
	box(m, Vector3.new(0.2, 0.25, 0.05) * s, CFrame.new(-0.22 * s, 1.4 * s, -0.5 * s), SHADOW)
	box(m, Vector3.new(0.2, 0.25, 0.05) * s, CFrame.new(0.22 * s, 1.4 * s, -0.5 * s), SHADOW)
	box(m, Vector3.new(0.3, 0.35, 0.05) * s, CFrame.new(0, 1.05 * s, -0.5 * s), SHADOW)
	for _, side in ipairs({ -1, 1 }) do
		box(m, Vector3.new(0.4, 1.7, 0.4) * s, CFrame.new(side * 0.85 * s, 1.1 * s, -0.2 * s) * CFrame.Angles(-0.4, 0, side * -0.35), GHOST, Enum.Material.Neon, 0.45)
	end
	-- Tail of mist fading into the ground.
	for i = 1, 3 do
		box(m, Vector3.new(1.2 - i * 0.25, 0.6, 0.7 - i * 0.12) * s, CFrame.new(0, -0.6 * s - i * 0.5 * s, 0), GHOST, Enum.Material.Neon, 0.45 + i * 0.15)
	end
	return finish(m)
end

local function puff(position, color, count)
	VFXLib.burst(position, { Count = count or 10, Color = color or GHOST, Speed = 10, Lifetime = 0.4, Spread = 180 })
end

-- A ghost rises out of the ground at `spot`, holds, and fades.
local function riseGhost(spot, scale, facing)
	local g = buildGhost(scale)
	local look = facing or Vector3.new(0, 0, -1)
	local base = CFrame.lookAt(spot, spot + Vector3.new(look.X, 0, look.Z))
	VFXLib.animate(0.9, function(a)
		local up = VFXLib.easeOut(math.min(a / 0.35, 1))
		place(g, base * CFrame.new(0, -3 + up * 5, 0) * CFrame.Angles(0, math.sin(a * 9) * 0.1, 0))
		for _, p in ipairs(g.Parts) do
			if a > 0.6 then
				p.Transparency = math.min(1, p.Transparency + 0.06)
			end
		end
	end, function()
		g.Model:Destroy()
	end)
	puff(spot + Vector3.new(0, 1, 0), GHOST, 12)
end

---------------------------------------------------------------------------
-- Membrane on a target: film + stuck junk, shrinks; drips in the rain
---------------------------------------------------------------------------
local function wrap(target, duration, rain, flatten)
	local tr = Common.rootOf(target)
	if not tr then
		return
	end
	local old = membranes[target]
	if old then
		old.Model:Destroy()
	end
	local m = newModel("GuiltMembrane")
	local film = box(m, Vector3.new(3.4, 5.6, 2.4), tr.CFrame, FILM, Enum.Material.Glass, 0.55)
	local stuck = {}
	for i = 1, 5 do
		local styles = { "Crate", "Wheel", "Bottle", "Boot", "Chair" }
		local j = buildJunk(styles[i], 0.55)
		j.Model.Parent = m
		local a = i / 5 * math.pi * 2
		table.insert(stuck, { Item = j, Offset = CFrame.new(math.cos(a) * 1.5, (i % 3 - 1) * 1.4, math.sin(a) * 1.1) * CFrame.Angles(a, a * 2, 0) })
	end
	membranes[target] = { Model = m, Film = film, Stuck = stuck, Target = target, Born = os.clock(), Duration = duration or 3, Rain = rain, Flatten = flatten }
	puff(tr.Position, FILM, 14)
end

local function stepMembranes()
	local now = os.clock()
	for target, mb in pairs(membranes) do
		local tr = Common.rootOf(target)
		local a = (now - mb.Born) / mb.Duration
		if not tr or a >= 1 or not target.Parent then
			membranes[target] = nil
			mb.Model:Destroy()
			if tr then
				-- Squeezed shut: a crunch and a puff.
				VFXLib.burst(tr.Position, { Count = 14, Color = FILM, Speed = 16, Lifetime = 0.35 })
				TuskVFX.CreateImpactStar(tr.Position, { Size = mb.Flatten and 6 or 3, Rays = 6, Color = pal.Main, Color2 = Color3.new(1, 1, 1), Duration = 0.12 })
				if mb.Flatten then
					-- Max guilt: flattened like paper for a moment.
					local sheet = VFXLib.part({ Size = Vector3.new(3.2, 0.15, 2.2), Color = FILM, Material = Enum.Material.Glass, Transparency = 0.3 })
					local at = tr.CFrame
					VFXLib.animate(0.6, function(a)
						sheet.CFrame = at * CFrame.new(0, -2.4, 0)
						sheet.Size = Vector3.new(3.2 + a, 0.15, 2.2 + a)
						sheet.Transparency = 0.3 + 0.7 * a
					end, function()
						sheet:Destroy()
					end)
					TuskVFX.CreateGroundCracks(tr.Position - Vector3.new(0, 2.5, 0), { Radius = 6, Color = pal.Main })
				end
			end
		else
			-- Shrinks tighter and tighter (with a heartbeat squeeze each half second).
			local squeeze = 1.25 - 0.4 * a - 0.05 * math.abs(math.sin((now - mb.Born) * math.pi * 2))
			mb.Film.Size = Vector3.new(2.7, 5.2, 1.9) * squeeze
			mb.Film.CFrame = tr.CFrame
			mb.Film.Transparency = mb.Rain and (0.55 + 0.35 * a) or 0.55
			for _, st in ipairs(mb.Stuck) do
				local off = st.Offset
				place(st.Item, tr.CFrame * CFrame.new(off.Position * squeeze) * (off - off.Position))
			end
			if mb.Rain and math.random() < 0.3 then
				-- Water washes it away: it drips.
				VFXLib.burst(tr.Position + Vector3.new((math.random() - 0.5) * 2, -1, (math.random() - 0.5) * 2), { Count = 2, Color = WATER, Speed = 4, Lifetime = 0.4, Direction = Vector3.new(0, -1, 0), Spread = 20 })
			end
		end
	end
end

---------------------------------------------------------------------------
-- GUILT marks above a head: five pips, the lit ones crimson
---------------------------------------------------------------------------
local function setMarks(target, stacks)
	if typeof(target) ~= "Instance" then
		return
	end
	local m = marks[target]
	if stacks <= 0 then
		if m then
			m.Gui:Destroy()
			marks[target] = nil
		end
		return
	end
	local head = target:FindFirstChild("Head") or Common.rootOf(target)
	if not head then
		return
	end
	if not m then
		local gui = Instance.new("BillboardGui")
		gui.Name = "GuiltMarks"
		gui.Size = UDim2.fromOffset(96, 26)
		gui.StudsOffset = Vector3.new(0, 2.8, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 90
		gui.Adornee = head
		gui.Parent = VFXLib.Folder
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, 11)
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 10
		label.TextColor3 = Color3.fromRGB(255, 170, 180)
		label.TextStrokeTransparency = 0.3
		label.Text = "GUILT"
		label.Parent = gui
		local pips = {}
		for i = 1, 5 do
			local pip = Instance.new("Frame")
			pip.AnchorPoint = Vector2.new(0.5, 0)
			pip.Position = UDim2.new(0.5, (i - 3) * 17, 0, 13)
			pip.Size = UDim2.fromOffset(12, 12)
			pip.Rotation = 45
			pip.BorderSizePixel = 0
			pip.Parent = gui
			pips[i] = pip
		end
		m = { Gui = gui, Pips = pips, Stacks = 0 }
		marks[target] = m
	end
	if stacks > m.Stacks then
		-- A new mark flares as it lands.
		local pip = m.Pips[stacks]
		if pip then
			VFXLib.animate(0.25, function(a)
				pip.Size = UDim2.fromOffset(12 + 10 * (1 - a), 12 + 10 * (1 - a))
			end)
		end
	end
	m.Stacks = stacks
	for i, pip in ipairs(m.Pips) do
		local lit = i <= stacks
		pip.BackgroundColor3 = lit and (stacks >= 5 and Color3.fromRGB(255, 60, 90) or pal.Main) or Color3.fromRGB(40, 24, 36)
		pip.BackgroundTransparency = lit and 0 or 0.35
	end
end

---------------------------------------------------------------------------
-- Specters hunting their target (the server decides the grab)
---------------------------------------------------------------------------
local function spawnHunter(data)
	local target = data.Target
	local g = buildGhost(0.95)
	local h = { Ghost = g, Pos = data.From, Target = target, Speed = data.Speed or 24, Born = os.clock() + (data.Delay or 0), Life = (data.Life or 3) + 0.5, Next = 0 }
	hunters[data.Id] = h
	place(g, CFrame.new(data.From - Vector3.new(0, 3, 0)))
	puff(data.From, GHOST, 8)
end

local function endHunter(id, grabbed, position)
	local h = hunters[id]
	if not h then
		return
	end
	hunters[id] = nil
	local at = position or h.Pos
	if grabbed then
		-- It lunges in and pours into them.
		local g = h.Ghost
		local from = h.Pos
		VFXLib.animate(0.25, function(a)
			place(g, CFrame.lookAt(from:Lerp(at, a), at) * CFrame.new(0, 0, 0) * CFrame.Angles(-0.6 * a, 0, 0))
			for _, p in ipairs(g.Parts) do
				p.Transparency = math.min(1, p.Transparency + 0.08)
			end
		end, function()
			g.Model:Destroy()
		end)
		TuskVFX.CreateImpactStar(at, { Size = 3.5, Rays = 7, Color = GHOST, Color2 = pal.Main, Duration = 0.15 })
		puff(at, GHOST, 16)
	else
		h.Ghost.Model:Destroy()
		puff(at, GHOST, 10)
	end
end

local function stepHunters(dt)
	local now = os.clock()
	for id, h in pairs(hunters) do
		local tr = Common.rootOf(h.Target)
		if now - h.Born > h.Life or (now > h.Born and not tr) then
			endHunter(id, false)
		elseif now >= h.Born then
			local to = tr.Position - h.Pos
			if to.Magnitude > 0.5 then
				h.Pos = h.Pos + to.Unit * math.min(h.Speed * dt, to.Magnitude)
			end
			-- Floats low, swaying, arms out toward them.
			local rise = math.min((now - h.Born) / 0.3, 1)
			local look = Vector3.new(to.X, 0, to.Z)
			local cf = CFrame.lookAt(h.Pos, h.Pos + (look.Magnitude > 0.1 and look or Vector3.new(0, 0, -1)))
			place(h.Ghost, cf * CFrame.new(math.sin(now * 5 + id) * 0.3, -3 + rise * 3.3 + math.sin(now * 3) * 0.2, 0) * CFrame.Angles(0.25, 0, 0))
			h.Next = h.Next - dt
			if h.Next <= 0 then
				h.Next = 0.12
				puff(h.Pos - Vector3.new(0, 1.5, 0), GHOST, 1)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Junk stuck to a body
---------------------------------------------------------------------------
local function stickJunk(target, style, duration)
	local tr = Common.rootOf(target)
	if not tr then
		return
	end
	local item = buildJunk(style or "Crate", 0.5)
	local a = math.random() * math.pi * 2
	table.insert(stuckJunk, { Item = item, Target = target, Offset = CFrame.new(math.cos(a) * 1.1, math.random() * 2 - 0.8, math.sin(a) * 0.7) * CFrame.Angles(a, a * 2, 0), Until = os.clock() + (duration or 4) })
end

local function stepStuck()
	local now = os.clock()
	for i = #stuckJunk, 1, -1 do
		local st = stuckJunk[i]
		local tr = Common.rootOf(st.Target)
		if not tr or now > st.Until then
			table.remove(stuckJunk, i)
			-- It drops off and fades.
			local item = st.Item
			local from = item.Parts[1] and item.Parts[1].CFrame or CFrame.new()
			VFXLib.animate(0.4, function(a)
				place(item, from * CFrame.new(0, -3 * a * a, 0))
				for _, p in ipairs(item.Parts) do
					p.Transparency = math.min(1, p.Transparency + 0.06)
				end
			end, function()
				item.Model:Destroy()
			end)
		else
			place(st.Item, tr.CFrame * st.Offset)
		end
	end
end

-- The victim's own screen: their guilt closes in on them.
local WHISPERS = { "...you left it behind.", "...you gave it up.", "...remember?", "...it was your fault.", "...you never went back." }
local function guiltScreen(duration, strong)
	TuskVFX.ScreenTint(duration, { Tint = Color3.fromRGB(200, 170, 210), Saturation = -0.5, Brightness = -0.12 })
	local gui = Instance.new("ScreenGui")
	gui.Name = "GuiltWhispers"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local count = strong and 4 or 2
	for i = 1, count do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.25 + math.random() * 0.5, 0.3 + math.random() * 0.4)
		label.Size = UDim2.fromOffset(360, 30)
		label.Font = Enum.Font.Fondamento
		label.TextSize = strong and 28 or 22
		label.TextColor3 = Color3.fromRGB(235, 215, 240)
		label.TextStrokeColor3 = Color3.fromRGB(40, 10, 30)
		label.Text = WHISPERS[math.random(1, #WHISPERS)]
		label.TextTransparency = 1
		label.TextStrokeTransparency = 1
		label.Parent = gui
		local start = (i - 1) * duration / (count + 1)
		VFXLib.animate(duration, function(a)
			local t = a * duration - start
			local alpha = t < 0 and 0 or math.min(t / 0.4, 1) * math.max(0, 1 - (t - 1.2) / 0.6)
			label.TextTransparency = 1 - alpha * 0.9
			label.TextStrokeTransparency = 1 - alpha * 0.6
		end)
	end
	task.delay(duration + 0.1, function()
		gui:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Junk projectiles (server Kind "GuiltJunk")
---------------------------------------------------------------------------
local function spawnJunk(data)
	local style = data.Visual and data.Visual.Style or "Crate"
	local item = buildJunk(style, 1)
	projectiles[data.Id] = { Item = item, Origin = data.Origin, Direction = data.Direction, Speed = data.Speed, Range = data.Range, ServerTime = data.ServerTime, Expire = os.clock() + data.Range / math.max(data.Speed, 1) + 0.5, Spin = math.random() * 10 }
end

local function endJunk(data)
	local v = projectiles[data.Id]
	if v then
		projectiles[data.Id] = nil
		v.Item.Model:Destroy()
	end
	VFXLib.burst(data.Position, { Count = data.HitCharacter and 12 or 6, Color = WOOD, Speed = 14, Lifetime = 0.35 })
	if data.HitCharacter then
		TuskVFX.CreateImpactStar(data.Position, { Size = 2.6, Rays = 5, Color = pal.Main, Color2 = Color3.new(1, 1, 1), Duration = 0.12 })
	end
end

local function stepJunk()
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for id, v in pairs(projectiles) do
		local t = VFXLib.flight(id, v.ServerTime)
		local distance = math.min(v.Speed * t, v.Range)
		local pos = v.Origin + v.Direction * math.max(distance, 0)
		place(v.Item, CFrame.new(pos) * CFrame.Angles(t * 9 + v.Spin, t * 6, t * 4))
		if now > v.Expire + VFXLib.held(id, v.ServerTime) then
			projectiles[id] = nil
			v.Item.Model:Destroy()
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
	TuskAnimation.play(character, "A_M1_" .. index)
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1, -3.2), Duration = 0.3 })
	VFXLib.sound(sounds.Swing, root, 0.5, 0.95 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or pal.Second)
end

local function onFinisher(data)
	Common.finisher(data, pal)
	if data.Position then
		puff(data.Position, FILM, 14)
	end
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "Guilt" and phase == "Mark" then
		setMarks(data.Target, data.Stacks or 0)
		return
	end
	if move == "GuiltSpecter" then
		if phase == "Spawn" then
			spawnHunter(data)
		elseif phase == "Grab" then
			endHunter(data.Id, true, data.Position)
			if data.Target and Common.isLocal(data.Target) then
				CameraFX.shake(0.5, 0.25)
			end
		elseif phase == "Fade" then
			endHunter(data.Id, false, data.Position)
		elseif phase == "Cast" and character then
			TuskAnimation.play(character, "AxlSpecter")
			TuskStand.action(character, "Lunge", { Duration = 0.4 })
		elseif phase == "Warn" and data.Position then
			-- A dark pool spreads under them: something is coming up.
			local pool = VFXLib.part({ Size = Vector3.new(0.2, 1, 1), Color = SHADOW, Material = Enum.Material.SmoothPlastic, Transparency = 0.2 })
			local r = data.Radius or 5
			local at = data.Position
			VFXLib.animate(data.Rise or 0.55, function(a)
				pool.Size = Vector3.new(0.2, r * 2 * a, r * 2 * a)
				pool.CFrame = CFrame.new(at + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, a * 2, math.pi / 2)
				if math.random() < 0.4 then
					puff(at + Vector3.new((math.random() - 0.5) * r, 0.5, (math.random() - 0.5) * r), FILM, 2)
				end
			end, function()
				pool:Destroy()
			end)
		elseif phase == "Rise" and data.Position then
			local facing = root and (root.Position - data.Position) or nil
			riseGhost(data.Position, 1.2, facing)
			if data.Hit then
				CameraFX.shake(0.4, 0.2)
			end
		elseif phase == "Miss" and root then
			puff((root.CFrame * CFrame.new(0, 0, -5)).Position, GHOST, 8)
		end
	elseif move == "AbandonedJunk" and phase == "Stick" then
		stickJunk(data.Target, data.Style, data.Duration)
	elseif move == "AbandonedJunk" and phase == "Gather" and root then
		TuskAnimation.play(character, "AxlJunk")
		TuskStand.action(character, "Lunge", { Duration = (data.Startup or 0.3) + 0.2 })
		-- Junk rises out of his shadow and shakes before it flies.
		local styles = { "Crate", "Wheel", "Chair", "Bottle", "Boot", "Lamp" }
		local items = {}
		for i = 1, data.Count or 6 do
			local t = (i - 1) / math.max((data.Count or 6) - 1, 1) - 0.5
			local item = buildJunk(styles[(i - 1) % #styles + 1], 1)
			local home = root.CFrame * CFrame.new(t * 5, 1.5 + (i % 3) * 0.6, -2)
			table.insert(items, { Item = item, Home = home })
		end
		VFXLib.animate(data.Startup or 0.3, function(a)
			for i, it in ipairs(items) do
				local shake = CFrame.new((math.random() - 0.5) * 0.12, (math.random() - 0.5) * 0.12, 0)
				place(it.Item, it.Home * CFrame.new(0, -2 * (1 - a), 0) * shake * CFrame.Angles(0, i + a * 2, 0))
			end
		end, function()
			for _, it in ipairs(items) do
				it.Item.Model:Destroy()
			end
		end)
	elseif move == "GuiltMembrane" then
		if phase == "Cast" and character then
			TuskAnimation.play(character, "AxlMembrane")
			TuskStand.action(character, "Lunge", { Duration = 0.5 })
		elseif phase == "Engulf" then
			for _, target in ipairs(data.Targets or {}) do
				wrap(target, data.Duration, data.Rain, data.Flatten)
				if Common.isLocal(target) then
					guiltScreen(data.Duration or 3, data.Flatten)
				end
			end
		elseif phase == "Miss" and root then
			puff((root.CFrame * CFrame.new(0, 0, -6)).Position, FILM, 8)
		end
	end
end

local rises = {} -- piles and specters standing round an ultimate

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Rise" then
		TuskAnimation.play(character, "AxlCivilWar")
		TuskStand.action(character, "Manifest", { Duration = 1 })
		local center = data.Position
		local radius = data.Radius or 20
		-- Junk piles rise in a ring, specters among them reaching inward.
		local styles = { "Crate", "Wheel", "Chair", "Bottle", "Boot", "Lamp" }
		local list = {}
		for i = 1, 12 do
			local a = i / 12 * math.pi * 2
			local spot = center + Vector3.new(math.cos(a) * radius * 0.85, 0, math.sin(a) * radius * 0.85)
			local pile = buildJunk(styles[(i - 1) % #styles + 1], 1.6)
			table.insert(list, { Item = pile, Spot = spot, Angle = a })
		end
		VFXLib.animate(data.Windup or 1, function(a)
			for _, it in ipairs(list) do
				place(it.Item, CFrame.new(it.Spot + Vector3.new(0, -2 + VFXLib.easeOut(a) * 2.8, 0)) * CFrame.Angles(it.Angle, it.Angle * 2, 0))
			end
		end)
		rises[character] = list
		for i = 1, data.Specters or 7 do
			local a = (i + 0.5) / (data.Specters or 7) * math.pi * 2
			local spot = center + Vector3.new(math.cos(a) * radius * 0.7, 0, math.sin(a) * radius * 0.7)
			task.delay((data.Windup or 1) * 0.5 + i * 0.05, function()
				riseGhost(spot, 1.4, center - spot)
			end)
		end
		if Common.isLocal(character) then
			TuskVFX.ScreenTint((data.Windup or 1) + 3, { Tint = Color3.fromRGB(230, 200, 210), Saturation = -0.4, Brightness = -0.08 })
		end
		VFXLib.sound(sounds.AwakeningBuild, center, 0.5, 0.8)
	elseif data.Phase == "Engulf" then
		for _, target in ipairs(data.Targets or {}) do
			wrap(target, data.Duration, data.Rain, true)
			if Common.isLocal(target) then
				guiltScreen(data.Duration or 3, true)
			end
		end
		TuskVFX.CreateGroundCracks(data.Position, { Radius = (data.Radius or 20) * 0.6, Color = pal.Main })
	elseif data.Phase == "Scatter" then
		-- Civil War breaks apart: red, yellow and silver pieces scatter and reform.
		local from, to = data.From, data.To
		for i = 1, 18 do
			local p = VFXLib.part({ Size = Vector3.new(0.5, 0.5, 0.5), Color = PIECES[(i - 1) % #PIECES + 1], Material = Enum.Material.SmoothPlastic })
			local off = Vector3.new(math.random() - 0.5, math.random() * 2 - 0.5, math.random() - 0.5) * 6
			VFXLib.animate(0.4, function(a)
				local out = a < 0.5 and VFXLib.easeOut(a * 2) or 1 - VFXLib.easeOut((a - 0.5) * 2)
				p.CFrame = CFrame.new(from:Lerp(to, a) + off * out) * CFrame.Angles(a * 6, a * 4, 0)
			end, function()
				p:Destroy()
			end)
		end
		puff(from, FILM, 16)
	elseif data.Phase == "Crush" then
		local list = rises[character]
		rises[character] = nil
		if list then
			for _, it in ipairs(list) do
				local start = it.Item.Parts[1] and it.Item.Parts[1].CFrame or CFrame.new(it.Spot)
				VFXLib.animate(0.35, function(a)
					place(it.Item, CFrame.new(it.Spot + Vector3.new(0, 0.8 - a * 3, 0)) * (start - start.Position))
				end, function()
					it.Item.Model:Destroy()
				end)
			end
		end
		for _, target in ipairs(data.Targets or {}) do
			local tr = Common.rootOf(target)
			if tr then
				Common.finisher({ Character = character, Position = tr.Position, Hit = true }, pal, { Size = 1.2, Layers = 2, Shake = 0.6 })
			end
		end
		if Common.isLocal(character) then
			CameraFX.impactFrame(pal.Main)
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
				TuskAnimation.hold(character, "AxlStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "AxlStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function AxlVFX.handle(name, data)
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
function AxlVFX.step(dt)
	dt = dt or 1 / 60
	stepJunk()
	stepMembranes()
	stepHunters(dt)
	stepStuck()
	-- Marks go when the character does.
	for target, m in pairs(marks) do
		if not target.Parent then
			m.Gui:Destroy()
			marks[target] = nil
		end
	end
	slowTimer = slowTimer + dt
	if slowTimer > 0.2 then
		slowTimer = 0
		stepStance()
	end
end

Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
	if typeof(data) ~= "table" or data.Kind ~= "GuiltJunk" then
		return
	end
	if name == "ProjectileSpawn" then
		spawnJunk(data)
	elseif name == "ProjectileEnd" then
		endJunk(data)
	end
end)

return AxlVFX
end

-- ======================================================================
-- MODULE: CivilWarStand
-- ======================================================================
__modules["CivilWarStand"] = function()
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
end
end
