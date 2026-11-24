--[[
	DefenseClient  (StarterPlayerScripts.SpinClient.DefenseClient)

	Block and Dash on the client, for every character:
	  * input: hold F (controller L2) to block, Q (controller R2) to dash,
	    on-screen buttons on mobile. Intents only: the server decides.
	  * DASH: when the server grants it, this client moves its own character
	    (smooth, and it replicates). Everyone sees a dust burst, a wind ring,
	    body-shaped afterimages in the character's colour, wind streaks, a
	    landing puff and a dash pose (forward / back / left / right); speed
	    lines for the dasher. A dash that cancels an attack flashes white.
	  * PERFECT DODGE: a gold ghost and "PERFECT DODGE", a blue slowed-down
	    flash and COUNTER READY for the dodger.
	  * BLOCK: anyone blocking braces into a guard pose (and sags into a weak
	    guard when the guard bar is low). A curved barrier of glowing tiles in
	    their character's colour builds in front of them; it shimmers, its
	    tiles darken, flicker and crack red as the guard bar drains, and it
	    scatters away on release. A blocked hit makes them recoil, lights the
	    tile it struck, sends a ripple across the barrier and throws sparks.
	  * PERFECT BLOCK: gold flash and "PERFECT!" on the defender, the attacker
	    reels. GUARD BREAK: the shield shatters, "GUARD BREAK" and a stagger.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)
local CameraFX = require(script.Parent.CameraFX)
local TuskVFX = require(script.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.TuskAnimation)
local Fighters = require(script.Parent.Fighters)
local Common = require(script.Parent.TuskActCommon)

local DefenseClient = {}
local player = Players.LocalPlayer
local sounds = TuskConfig.Sounds
local SHIELD = Color3.fromRGB(110, 180, 255)
local SHIELD_LIGHT = Color3.fromRGB(210, 235, 255)
local GOLD = Color3.fromRGB(255, 210, 80)

local Request
local blocking = {} -- [character] = { Shield, Previous hold }
local blockHeld = false

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
local function moveDirection()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
		return humanoid.MoveDirection
	end
	return root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
end

local function onBlock(_, state)
	if state == Enum.UserInputState.Begin then
		blockHeld = true
		Request:FireServer("Block", true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if blockHeld then
			blockHeld = false
			Request:FireServer("Block", false)
		end
	end
	return Enum.ContextActionResult.Sink
end

local function onDashInput(_, state)
	if state == Enum.UserInputState.Begin then
		Request:FireServer("Dash", moveDirection())
	end
	return Enum.ContextActionResult.Sink
end

---------------------------------------------------------------------------
-- Dash
---------------------------------------------------------------------------
local function dashPose(root, direction)
	local look, right = root.CFrame.LookVector, root.CFrame.RightVector
	local f, r = direction:Dot(look), direction:Dot(right)
	if math.abs(f) >= math.abs(r) then
		return f >= 0 and "DashF" or "DashB"
	end
	return r >= 0 and "DashR" or "DashL"
end

local BODY = { "Head", "UpperTorso", "LowerTorso", "Torso", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local function dashColour(character)
	local act = character:GetAttribute("TuskAct")
	local pal = act and Common.palette(act)
	return pal and pal.Main or SHIELD_LIGHT, pal and pal.Light or Color3.new(1, 1, 1)
end

-- A see-through copy of the body (every limb), in a colour, fading out.
local function bodyGhost(character, color, life, startT)
	if not VFXLib.acquire() then
		return
	end
	local parts = {}
	for _, name in ipairs(BODY) do
		local limb = character:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			table.insert(parts, VFXLib.part({ Size = limb.Size * 1.02, CFrame = limb.CFrame, Color = color, Material = Enum.Material.Neon, Transparency = startT or 0.45 }))
		end
	end
	VFXLib.animate(life or 0.25, function(a)
		for _, g in ipairs(parts) do
			g.Transparency = (startT or 0.45) + (1 - (startT or 0.45)) * a
		end
	end, function()
		for _, g in ipairs(parts) do
			g:Destroy()
		end
		VFXLib.release()
	end)
end

local function groundRing(position, radius, color, time)
	local ring = VFXLib.part({ Size = Vector3.new(0.2, 1, 1), Color = color, Material = Enum.Material.Neon, Transparency = 0.3, Shape = Enum.PartType.Cylinder })
	VFXLib.animate(time or 0.3, function(a)
		local d = radius * 2 * VFXLib.easeOut(a)
		ring.Size = Vector3.new(0.2, d, d)
		ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Transparency = 0.3 + 0.7 * a
	end, function()
		ring:Destroy()
	end)
end

local function onDashFX(data)
	local character = data.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local dir = data.Direction
	local color, light = dashColour(character)
	local time = data.Time or 0.21
	TuskAnimation.play(character, dashPose(root, dir))
	local feet = root.Position - Vector3.new(0, 2.6, 0)
	-- Kick-off: a dust burst behind, a wind ring at the feet.
	VFXLib.burst(feet, { Count = 14, Texture = VFXLib.Textures.Smoke, Color = Color3.fromRGB(215, 190, 150), LightEmission = 0, Speed = 16, Lifetime = 0.6, Spread = 60, Direction = -dir })
	groundRing(feet + Vector3.new(0, 0.1, 0), 3.2, light, 0.28)
	VFXLib.sound(sounds.Swing, root, 0.5, 0.8)
	if data.Cancel then
		-- Dash-cancelled out of an attack: a sharp white flash.
		TuskVFX.CreateImpactStar(root.Position, { Size = 2.4, Rays = 6, Color = Color3.new(1, 1, 1), Color2 = color, Duration = 0.1 })
	end
	-- Coloured body afterimages along the way, and wind streaks.
	local steps = 5
	for i = 0, steps - 1 do
		task.delay(i * time / steps, function()
			if root.Parent then
				bodyGhost(character, i % 2 == 0 and color or light, 0.22, 0.4 + i * 0.06)
			end
		end)
	end
	local start = root.Position
	for k = 1, 3 do
		local streak = VFXLib.part({ Size = Vector3.new(0.12, 0.12, 1), Color = light, Material = Enum.Material.Neon, Transparency = 0.3 })
		local offset = Vector3.new((math.random() - 0.5) * 2, (k - 2) * 0.9, (math.random() - 0.5) * 2)
		VFXLib.animate(time + 0.2, function(a)
			if not root.Parent then
				return
			end
			local from, to = start + offset, root.Position + offset - dir * 1.5
			local len = math.max((to - from).Magnitude, 0.2)
			streak.Size = Vector3.new(0.12, 0.12, len)
			streak.CFrame = CFrame.lookAt((from + to) / 2, to)
			streak.Transparency = 0.3 + 0.7 * math.max(0, (a - 0.5) * 2)
		end, function()
			streak:Destroy()
		end)
	end
	-- Landing: a puff where the dash ends.
	task.delay(time, function()
		if root.Parent then
			VFXLib.burst(root.Position - Vector3.new(0, 2.6, 0), { Count = 8, Texture = VFXLib.Textures.Smoke, Color = Color3.fromRGB(215, 190, 150), LightEmission = 0, Speed = 8, Lifetime = 0.5, Spread = 80, Direction = dir })
		end
	end)
	if character ~= player.Character then
		return
	end
	-- Our own character: move it ourselves (we own its physics).
	local speed = data.Speed or 80
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	VFXLib.animate(time, function()
		if not root.Parent or (humanoid and humanoid.Health <= 0) then
			return
		end
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, math.min(v.Y, 0), dir.Z * speed)
	end, function()
		if root.Parent then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(dir.X * 14, v.Y, dir.Z * 14)
		end
	end)
	CameraFX.fovPunch(6, 0.22)
	CameraFX.speedLines(time + 0.15, light)
end

-- PERFECT DODGE: a gold ghost left where the attack landed, the word over
-- their head; for the dodger a flash of slowed-down blue and COUNTER READY.
local function floatingText(character, text, color)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Adornee = head
	bb.Size = UDim2.fromOffset(220, 50)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = bb
	bb.Parent = VFXLib.Folder
	VFXLib.animate(0.9, function(a)
		bb.StudsOffset = Vector3.new(0, 2.6 + a * 1.2, 0)
		label.TextTransparency = math.max(0, (a - 0.6) / 0.4)
		label.TextStrokeTransparency = math.max(0, (a - 0.6) / 0.4)
	end, function()
		bb:Destroy()
	end)
end

local function onPerfectDodge(data)
	local character = data.Character
	if not character then
		return
	end
	bodyGhost(character, GOLD, 0.55, 0.2)
	if data.Position then
		groundRing(data.Position - Vector3.new(0, 2.4, 0), 5, GOLD, 0.35)
		TuskVFX.CreateImpactStar(data.Position, { Size = 3.2, Rays = 8, Color = GOLD, Color2 = Color3.new(1, 1, 1), Duration = 0.14 })
	end
	floatingText(character, "PERFECT DODGE", GOLD)
	if character == player.Character then
		TuskVFX.ScreenTint(0.25, { Tint = Color3.fromRGB(200, 225, 255), Saturation = -0.5, Brightness = 0.06, Contrast = 0.1, FadeOut = 0.3 })
		CameraFX.fovPunch(-7, 0.3)
		VFXLib.sound(sounds.ChargeFull, workspace.CurrentCamera, 0.5, 1.3)
		task.delay(0.35, function()
			floatingText(character, "COUNTER READY", Color3.fromRGB(255, 240, 200))
		end)
	elseif data.Attacker and data.Attacker == player.Character then
		CameraFX.shake(0.25, 0.1)
	end
end

---------------------------------------------------------------------------
-- Block visuals
---------------------------------------------------------------------------
-- A curved barrier of glowing tiles (5 across, 4 high) in front of the body,
-- in the character's colour. Each tile: { Part, Offset, Col, Row }.
local COLS, ROWS = 5, 4
local TILE_W, TILE_H, GAP = 0.78, 0.9, 0.08
local CRACK = Color3.fromRGB(255, 80, 70)

local function colourOf(character)
	local act = character:GetAttribute("TuskAct")
	local pal = act and Common.palette(act)
	return pal and pal.Main or SHIELD
end

local function makeShield(character)
	local m = Instance.new("Model")
	m.Name = "BlockShield"
	m.Parent = VFXLib.Folder
	local color = colourOf(character)
	local tiles = {}
	for col = 1, COLS do
		for row = 1, ROWS do
			local x = (col - (COLS + 1) / 2)
			local y = (row - (ROWS + 1) / 2)
			-- Curve round the body: outer columns angle back.
			local yaw = -x * 0.32
			local offset = CFrame.new(0, 0.3 + y * (TILE_H + GAP), 0) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -2.3)
			local p = VFXLib.part({ Material = Enum.Material.ForceField, Color = color, Size = Vector3.new(TILE_W, TILE_H, 0.12), Transparency = 0.1 })
			p.Parent = m
			table.insert(tiles, { Part = p, Offset = offset, Col = col, Row = row, Seed = math.random() * 10, Flash = 0 })
		end
	end
	-- A brighter rim along the top and bottom edges.
	local rims = {}
	for _, y in ipairs({ -1, 1 }) do
		for col = 1, COLS do
			local x = (col - (COLS + 1) / 2)
			local offset = CFrame.new(0, 0.3 + y * (ROWS / 2) * (TILE_H + GAP), 0) * CFrame.Angles(0, -x * 0.32, 0) * CFrame.new(0, 0, -2.3)
			local p = VFXLib.part({ Material = Enum.Material.Neon, Color = color:Lerp(Color3.new(1, 1, 1), 0.4), Size = Vector3.new(TILE_W + GAP, 0.08, 0.14), Transparency = 0.2 })
			p.Parent = m
			table.insert(rims, { Part = p, Offset = offset })
		end
	end
	return m, tiles, rims, color
end

local function placeShield(entry, root, t)
	local maxMeter = (TuskConfig.Defense and TuskConfig.Defense.MaxMeter) or 100
	local k = math.clamp((entry.Character:GetAttribute("BlockMeter") or maxMeter) / maxMeter, 0, 1)
	-- It builds in from the middle over the first moment.
	local build = math.clamp((t - entry.Born) / 0.16, 0, 1)
	local ripple = entry.Ripple -- { At = time, Col, Row }
	for i, tile in ipairs(entry.Tiles) do
		local p = tile.Part
		-- How "broken" this tile is: as the guard drains, tiles fail from the edges in.
		local edge = math.abs(tile.Col - (COLS + 1) / 2) / ((COLS - 1) / 2) * 0.5 + (tile.Row == 1 and 0.3 or 0)
		local broken = math.clamp((1 - k) * 1.6 - (1 - edge) * 0.7, 0, 1)
		local gone = broken > 0.85 and (math.floor(t * 10 + tile.Seed) % 3 == 0)
		-- Ripple from a blocked hit travels across the tiles.
		local wave = 0
		if ripple then
			local dist = math.sqrt((tile.Col - ripple.Col) ^ 2 + (tile.Row - ripple.Row) ^ 2)
			local front = (t - ripple.At) * 14
			wave = math.max(0, 1 - math.abs(front - dist)) * math.max(0, 1 - (t - ripple.At) / 0.5)
		end
		tile.Flash = math.max(0, tile.Flash - 0.08)
		local bob = math.sin(t * 6 + tile.Seed) * 0.03
		local pop = 1 + wave * 0.25 + tile.Flash * 0.3
		p.Size = Vector3.new(TILE_W * build * pop, TILE_H * build * pop, 0.12)
		p.CFrame = root.CFrame * tile.Offset * CFrame.new(0, bob, -wave * 0.3)
		local shimmer = 0.1 + 0.08 * math.sin(t * 4 + tile.Seed * 2)
		p.Transparency = gone and 1 or math.clamp(shimmer + broken * 0.35 - tile.Flash * 0.3, 0, 0.9)
		local color = entry.Color:Lerp(CRACK, broken)
		p.Color = color:Lerp(Color3.new(1, 1, 1), math.max(tile.Flash, wave * 0.6))
		-- A cracked tile jitters.
		if broken > 0.5 then
			p.CFrame = p.CFrame * CFrame.new((math.random() - 0.5) * 0.06, (math.random() - 0.5) * 0.06, 0)
		end
	end
	for _, rim in ipairs(entry.Rims) do
		rim.Part.CFrame = root.CFrame * rim.Offset
		rim.Part.Size = Vector3.new((TILE_W + GAP) * build, 0.08, 0.14)
		rim.Part.Color = entry.Color:Lerp(CRACK, 1 - k):Lerp(Color3.new(1, 1, 1), 0.4)
	end
	-- Low guard: sag into a weak, shaky stance (and back up when it refills).
	local weak = k < 0.35
	if weak ~= entry.Weak then
		entry.Weak = weak
		TuskAnimation.hold(entry.Character, weak and "BlockWeak" or "BlockPose")
	end
end

local function startBlock(character)
	local shield, tiles, rims, color = makeShield(character)
	local entry = { Character = character, Shield = shield, Tiles = tiles, Rims = rims, Color = color, Born = os.clock(), Previous = TuskAnimation.currentHold(character) }
	blocking[character] = entry
	TuskAnimation.hold(character, "BlockPose")
	TuskAnimation.play(character, "BlockRaise")
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		local front = (root.CFrame * CFrame.new(0, 0.3, -2.3)).Position
		VFXLib.burst(front, { Count = 8, Color = color, Speed = 10, Lifetime = 0.25 })
	end
	return entry
end

-- Release: the tiles scatter outward and fade.
local function scatterTiles(entry, speed, life, color)
	local root = entry.Character:FindFirstChild("HumanoidRootPart")
	local center = root and (root.CFrame * CFrame.new(0, 0.3, -2)).Position
	for _, tile in ipairs(entry.Tiles) do
		local p = tile.Part
		if p.Parent then
			local from = p.CFrame
			local away = center and (p.Position - center) or Vector3.new(0, 1, 0)
			away = (away.Magnitude > 0.01 and away.Unit or Vector3.new(0, 1, 0)) + Vector3.new(0, 0.4, 0)
			local spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 8
			if color then
				p.Color = color
				p.Material = Enum.Material.Neon
			end
			VFXLib.animate(life, function(a)
				p.CFrame = (from + away * speed * a - Vector3.new(0, (color and 12 or 0) * a * a, 0)) * CFrame.Angles(spin.X * a, spin.Y * a, spin.Z * a)
				p.Transparency = math.max(p.Transparency, a)
			end, function()
				p:Destroy()
			end)
		end
	end
	for _, rim in ipairs(entry.Rims) do
		rim.Part:Destroy()
	end
	task.delay(life + 0.05, function()
		entry.Shield:Destroy()
	end)
end

local function stopBlock(character, entry)
	blocking[character] = nil
	if not entry.Shattered then
		scatterTiles(entry, 2, 0.18)
	end
	TuskAnimation.stopHold(character, entry.Weak and "BlockWeak" or "BlockPose")
	if entry.Previous and entry.Previous ~= "BlockPose" and entry.Previous ~= "BlockWeak" and character.Parent then
		TuskAnimation.hold(character, entry.Previous) -- back to the character's stance
	end
end

-- A hit lands on someone's block: they recoil, the struck tile lights up,
-- a ripple runs across the barrier and sparks fly off it.
local function onBlockedHit(data)
	local victim = data.Victim
	local entry = victim and blocking[victim]
	local root = victim and victim:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	TuskAnimation.play(victim, (entry and entry.Weak) and "BlockHitWeak" or "BlockHit")
	local at = data.Position or (root.CFrame * CFrame.new(0, 0.3, -2.3)).Position
	if entry then
		-- The tile nearest the impact.
		local best, bestD
		for _, tile in ipairs(entry.Tiles) do
			local d = (tile.Part.Position - at).Magnitude
			if not bestD or d < bestD then
				best, bestD = tile, d
			end
		end
		if best then
			best.Flash = 1
			entry.Ripple = { At = os.clock(), Col = best.Col, Row = best.Row }
			at = best.Part.Position
		end
	end
	local color = entry and entry.Color or SHIELD
	local out = root.CFrame.LookVector
	VFXLib.burst(at, { Count = 14, Color = color:Lerp(Color3.new(1, 1, 1), 0.4), Speed = 30, Lifetime = 0.25, Spread = 55, Direction = out, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }) })
	TuskVFX.CreateRotationalShockwave(CFrame.lookAt(at, at + out) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = 2.2, Layers = 1, Color = color, Color2 = Color3.new(1, 1, 1), Particles = 0, Width = 0.1, Duration = 0.2 })
	VFXLib.sound(sounds.NailImpact, at, 0.35, 1.6)
	if victim == player.Character then
		CameraFX.shake(0.18, 0.12)
	end
end

-- Who's blocking: start / stop their barrier.
local function stepBlocks()
	local t = os.clock()
	local seen = {}
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and character:GetAttribute("Blocking") then
			seen[character] = true
			local entry = blocking[character] or startBlock(character)
			placeShield(entry, root, t)
		end
	end
	for character, entry in pairs(blocking) do
		if not seen[character] then
			stopBlock(character, entry)
		end
	end
end

local function popText(position, text, color)
	local carrier = VFXLib.anchor(CFrame.new(position + Vector3.new(0, 3, 0)), 1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = carrier
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local start = carrier.Position
	VFXLib.animate(0.9, function(a)
		carrier.Position = start + Vector3.new(0, a * 2, 0)
		label.TextTransparency = math.max(0, (a - 0.6) / 0.4)
		label.TextStrokeTransparency = label.TextTransparency
		local pop = a < 0.12 and 1 + (0.12 - a) * 5 or 1
		gui.Size = UDim2.fromOffset(220 * pop, 60 * pop)
	end)
end

local function onParry(data)
	local defender = data.Defender
	local root = defender and defender:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	TuskAnimation.play(defender, "Parry")
	local entry = blocking[defender]
	if entry then
		for _, tile in ipairs(entry.Tiles) do
			tile.Flash = 1
			tile.Part.Color = GOLD
		end
		entry.Color = GOLD
		task.delay(0.35, function()
			entry.Color = colourOf(defender)
		end)
	end
	local pos = (root.CFrame * CFrame.new(0, 0.5, -1.8)).Position
	TuskVFX.CreateImpactStar(pos, { Size = 7, Rays = 10, Color = GOLD, Color2 = Color3.new(1, 1, 1), Duration = 0.3 })
	VFXLib.burst(pos, { Count = 24, Color = GOLD, Speed = 40, Lifetime = 0.4 })
	VFXLib.flash(pos, GOLD, 5, 20, 0.25)
	TuskVFX.CreateRotationalShockwave(CFrame.lookAt(pos, pos + root.CFrame.LookVector) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = 4, Layers = 2, Color = GOLD, Color2 = Color3.new(1, 1, 1), Particles = 0.5, Width = 0.2, Duration = 0.3 })
	popText(root.Position, "PERFECT!", GOLD)
	VFXLib.sound(sounds.Finisher, pos, 0.6, 1.4)
	if data.Attacker then
		TuskAnimation.play(data.Attacker, "GuardBreak")
	end
	if defender == player.Character or data.Attacker == player.Character then
		CameraFX.impactFrame(GOLD)
		CameraFX.shake(0.4, 0.25)
	end
end

local function onGuardBreak(data)
	local victim = data.Victim
	local root = victim and victim:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	TuskAnimation.play(victim, "GuardBreak")
	local entry = blocking[victim]
	if entry and not entry.Shattered then
		-- The barrier's tiles shatter and fly.
		entry.Shattered = true
		scatterTiles(entry, 14, 0.7, Color3.fromRGB(255, 120, 100))
	end
	local pos = (root.CFrame * CFrame.new(0, 0.5, -1.8)).Position
	-- The shield shatters into blue shards.
	VFXLib.burst(pos, { Count = 30, Color = SHIELD, Speed = 35, Lifetime = 0.6, Acceleration = Vector3.new(0, -40, 0) })
	VFXLib.burst(pos, { Count = 10, Color = SHIELD_LIGHT, Speed = 12, Lifetime = 0.25, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) }) })
	popText(root.Position, "GUARD BREAK", Color3.fromRGB(255, 90, 80))
	VFXLib.sound(sounds.NailImpact, pos, 0.6, 0.7)
	if victim == player.Character then
		CameraFX.shake(0.6, 0.4)
	end
end

---------------------------------------------------------------------------
function DefenseClient.init()
	Request = Net.get("TuskRequest")
	local keys = TuskConfig.Keys
	ContextActionService:BindAction("SpinBlock", onBlock, true, keys.Block.Keyboard, keys.Block.Gamepad)
	ContextActionService:SetTitle("SpinBlock", "BLOCK")
	ContextActionService:SetPosition("SpinBlock", UDim2.new(1, -170, 1, -70))
	ContextActionService:BindAction("SpinDash", onDashInput, true, keys.Dash.Keyboard, keys.Dash.Gamepad)
	ContextActionService:SetTitle("SpinDash", "DASH")
	ContextActionService:SetPosition("SpinDash", UDim2.new(1, -95, 1, -165))
	player.CharacterAdded:Connect(function()
		blockHeld = false
	end)
	Net.get("TuskFX").OnClientEvent:Connect(function(name, data)
		if name == "Dash" and typeof(data) == "table" then
			onDashFX(data)
		elseif name == "PerfectDodge" and typeof(data) == "table" then
			onPerfectDodge(data)
		end
	end)
	Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
		if typeof(data) ~= "table" then
			return
		end
		if name == "Hit" and data.Blocked then
			onBlockedHit(data)
		elseif name == "Parry" then
			onParry(data)
		elseif name == "GuardBreak" then
			onGuardBreak(data)
		end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc = acc + dt
		for character, entry in pairs(blocking) do
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				placeShield(entry, root, os.clock())
			end
		end
		if acc >= 0.1 then
			acc = 0
			stepBlocks()
		end
	end)
end

return DefenseClient
