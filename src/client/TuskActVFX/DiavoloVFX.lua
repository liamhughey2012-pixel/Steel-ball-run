--[[
	TuskActVFX.DiavoloVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.DiavoloVFX)

	Client visuals for Diavolo / KING CRIMSON. Blocky.
	  * King Crimson (KingCrimsonStand) looms behind him with a crimson
	    aura; Diavolo stands with a hand on his hip
	  * KING CRIMSON COMBO: crimson fists and white chop arcs
	  * EPITAPH: Epitaph's face glows pink; Diavolo sees the future (his
	    screen gets a cracked crimson frame, flickering); if someone attacks,
	    he's already behind them: a streak of afterimages and a chop
	  * TIME ERASE: the moment SHATTERS: crimson and black shards of the
	    screen fall away. Everyone else (near) sees the world go crimson
	    while Diavolo all but vanishes, leaving red afterimages; Diavolo
	    sees everyone outlined in red. When time comes back, the shards snap
	    together in a white flash, and "ONLY THE RESULT REMAINS"
	  * HEART PUNCH: King Crimson's crimson fist bursts out through their
	    back; blood; they bleed for a while
	  * ONLY THE RESULT REMAINS (ultimate): a short cutscene for you (King
	    Crimson's face close up, Epitaph on its brow, Diavolo behind it, a
	    crimson mist; TuskConfig.Cutscenes.KingCrimson), then time is
	    erased: he's behind each of them in turn, King Crimson chopping, and
	    when time comes back every blow lands at once
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local TuskStandModels = require(Shared.TuskStandModels)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local Common = require(script.Parent.Parent.TuskActCommon)
local Fighters = require(script.Parent.Parent.Fighters)
local TuskStand = require(script.Parent.Parent.TuskStand)
local Cutscenes = require(script.Parent.Parent.Cutscenes)
local KingCrimsonStand = require(script.Parent.KingCrimsonStand)

local DiavoloVFX = {}
local ACT = 32
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, KingCrimsonStand.build, { Aura = KingCrimsonStand.Aura, AuraLight = KingCrimsonStand.AuraLight, Offset = KingCrimsonStand.Offset })

local RED = Color3.fromRGB(220, 46, 82)
local RED_DARK = Color3.fromRGB(110, 14, 36)
local WHITE = Color3.fromRGB(250, 244, 246)
local PINK = Color3.fromRGB(240, 150, 196)
local BLOOD = Color3.fromRGB(170, 10, 30)
local GREEN = Color3.fromRGB(120, 230, 120)

local stanced = {}
local erased = {} -- [character] = token while time is erased by them
local lastUltCut -- (not again within 8 s)

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function isMe(character)
	return character ~= nil and localPlayer ~= nil and character == localPlayer.Character
end

local function nearMe(pos, range)
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

local function worldLabel(at, text, color, duration, size)
	local anchor = VFXLib.part({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(at), Transparency = 1 })
	label(anchor, text, color, duration, size, Vector3.new(0, 0, 0))
	task.delay((duration or 1.2) + 0.1, function()
		anchor:Destroy()
	end)
end

-- A crimson fist (studded with white lattice lines) flying forward.
local function fist(from, dir, size)
	size = size or 1
	local f = VFXLib.part({ Size = Vector3.new(0.8, 0.75, 0.9) * size, Color = Color3.fromRGB(214, 212, 222), Transparency = 0.1 })
	local cuff = VFXLib.part({ Size = Vector3.new(0.82, 0.77, 0.5) * size, Color = RED, Transparency = 0.1 })
	local trail = VFXLib.part({ Size = Vector3.new(0.4, 0.4, 2.2) * size, Color = RED, Transparency = 0.5 })
	VFXLib.animate(0.16, function(a)
		local p = from + dir * (a * 3.2)
		local cf = CFrame.lookAt(p, p + dir)
		f.CFrame = cf
		cuff.CFrame = cf * CFrame.new(0, 0, 0.6 * size)
		trail.CFrame = cf * CFrame.new(0, 0, 1.6 * size)
		local t = a < 0.6 and 0.1 or 0.1 + (a - 0.6) / 0.4 * 0.9
		f.Transparency = t
		cuff.Transparency = t
		trail.Transparency = 0.5 + 0.5 * a
	end, function()
		f:Destroy()
		cuff:Destroy()
		trail:Destroy()
	end)
end

-- A white chop arc.
local function chop(at, look, size)
	size = size or 1
	local arc = {}
	for k = 1, 6 do
		arc[k] = VFXLib.part({ Size = Vector3.new(0.12, 0.6 * size, 0.7 * size), Color = k % 2 == 0 and WHITE or RED, Material = Enum.Material.Neon, Transparency = 0.2 })
	end
	local base = CFrame.lookAt(at, at + look)
	VFXLib.animate(0.22, function(a)
		for k, p in ipairs(arc) do
			local ang = -1.2 + (k / 6) * 2.4 * math.min(1, a * 1.6)
			p.CFrame = base * CFrame.Angles(ang, 0, 0) * CFrame.new(0, 1.6 * size, 0)
			p.Transparency = 0.2 + 0.8 * a
		end
	end, function()
		for _, p in ipairs(arc) do
			p:Destroy()
		end
	end)
end

local function blood(at, count, speed)
	for _ = 1, count do
		local d = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.18, 0.18, 0.18), Color = BLOOD, CFrame = CFrame.new(at) })
		d.Shape = Enum.PartType.Ball
		local v = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit * (speed or 10) * (0.5 + math.random() * 0.5)
		VFXLib.animate(0.5, function(a)
			local t = a * 0.5
			d.CFrame = CFrame.new(at + v * t + Vector3.new(0, -20 * t * t, 0))
			d.Transparency = math.max(0, a * 1.5 - 0.5)
		end, function()
			d:Destroy()
		end)
	end
end

-- Afterimages along a line.
local function afterimages(from, to, count, color)
	for k = 0, count - 1 do
		local p = from:Lerp(to, k / math.max(1, count - 1))
		local g = VFXLib.part({ Size = Vector3.new(2, 4.6, 1), CFrame = CFrame.new(p), Color = color or RED, Transparency = 0.5 })
		task.delay(k * 0.02, function()
			VFXLib.animate(0.45, function(t)
				g.Transparency = 0.5 + 0.5 * t
			end, function()
				g:Destroy()
			end)
		end)
	end
end

-- The moment shattering: crimson and black shards of the screen fall away
-- (`back` = they fly in and snap together instead).
local function shatterScreen(duration, back)
	local pg = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "KingCrimsonShards"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 45
	local shards = {}
	for gx = 0, 5 do
		for gy = 0, 3 do
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.BorderSizePixel = 0
			f.Size = UDim2.fromScale(0.2 + math.random() * 0.06, 0.28 + math.random() * 0.06)
			f.BackgroundColor3 = (gx + gy) % 3 == 0 and Color3.fromRGB(10, 4, 8) or ((gx + gy) % 3 == 1 and RED or RED_DARK)
			f.Rotation = math.random() * 40 - 20
			f.Parent = gui
			local stroke = Instance.new("UIStroke")
			stroke.Color = WHITE
			stroke.Thickness = 2
			stroke.Parent = f
			shards[#shards + 1] = { Frame = f, X = (gx + 0.5) / 6, Y = (gy + 0.5) / 4, VX = (math.random() - 0.5) * 0.6, VY = 0.6 + math.random() * 0.9, Spin = (math.random() - 0.5) * 300, Rot = f.Rotation }
		end
	end
	gui.Parent = pg
	VFXLib.animate(duration, function(a)
		local k = back and (1 - a) or a
		for _, s in ipairs(shards) do
			s.Frame.Position = UDim2.fromScale(s.X + s.VX * k, s.Y + s.VY * k * k)
			s.Frame.Rotation = s.Rot + s.Spin * k
			s.Frame.BackgroundTransparency = back and (a > 0.85 and (a - 0.85) / 0.15 or 0) or math.max(0, k * 1.4 - 0.4)
		end
	end, function()
		gui:Destroy()
	end)
end

-- Diavolo seeing the future: a cracked crimson frame round the screen.
local function futureFrame(duration)
	local pg = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "EpitaphFuture"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 38
	local edges = {}
	for _, e in ipairs({ { 0, 0, 1, 0.06 }, { 0, 0.94, 1, 0.06 }, { 0, 0, 0.04, 1 }, { 0.96, 0, 0.04, 1 } }) do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale(e[1], e[2])
		f.Size = UDim2.fromScale(e[3], e[4])
		f.BackgroundColor3 = RED_DARK
		f.BackgroundTransparency = 0.3
		f.Parent = gui
		table.insert(edges, f)
	end
	for k = 1, 10 do
		local crack = Instance.new("Frame")
		crack.BorderSizePixel = 0
		crack.AnchorPoint = Vector2.new(0.5, 0.5)
		local onSide = k % 2 == 0
		crack.Position = UDim2.fromScale(onSide and (k % 4 == 0 and 0.05 or 0.95) or (0.1 + k * 0.08), onSide and (0.1 + k * 0.07) or (k % 3 == 0 and 0.06 or 0.94))
		crack.Size = UDim2.fromScale(0.08 + math.random() * 0.06, 0.004)
		crack.Rotation = math.random() * 180
		crack.BackgroundColor3 = WHITE
		crack.Parent = gui
		table.insert(edges, crack)
	end
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0)
	t.Position = UDim2.fromScale(0.5, 0.08)
	t.Size = UDim2.fromScale(0.5, 0.06)
	t.Font = Enum.Font.Bangers
	t.TextScaled = true
	t.Text = "EPITAPH: THE FUTURE"
	t.TextColor3 = PINK
	t.TextStrokeTransparency = 0.2
	t.Parent = gui
	gui.Parent = pg
	VFXLib.animate(duration, function(a)
		local flick = (math.floor(a * duration * 14) % 5 == 0) and 0.6 or 0
		for _, f in ipairs(edges) do
			f.BackgroundTransparency = math.min(1, 0.3 + flick + (a > 0.85 and (a - 0.85) / 0.15 or 0))
		end
		t.TextTransparency = a > 0.8 and (a - 0.8) / 0.2 or 0
	end, function()
		gui:Destroy()
	end)
end

-- Make a character (and its Stand) all but invisible on this screen.
local function fade(character, amount)
	local function each(model)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = amount
			end
		end
	end
	each(character)
	local stand = TuskStand.get(character)
	if stand and stand.Model then
		each(stand.Model)
	end
end

-- Time erased by `character`, as seen from this screen.
local function eraseView(character, time, ultimate)
	local token = {}
	erased[character] = token
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local mine = isMe(character)
	local seen = mine or nearMe(root.Position, 80)
	if not seen then
		return
	end
	shatterScreen(0.45, false)
	CameraFX.impactFrame(Color3.fromRGB(255, 200, 210))
	local lighting = game:GetService("Lighting")
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "KingCrimsonErase"
	cc.TintColor = mine and Color3.fromRGB(255, 150, 170) or Color3.fromRGB(255, 120, 140)
	cc.Saturation = mine and -0.5 or -0.2
	cc.Contrast = 0.25
	cc.Brightness = mine and -0.1 or -0.05
	cc.Parent = lighting
	local outlines = {}
	if mine then
		-- He sees everyone else outlined in red: where their fate takes them.
		for _, f in ipairs(Fighters.list()) do
			local c = f.Character
			if c and c ~= character then
				local hl = Instance.new("Highlight")
				hl.FillTransparency = 0.85
				hl.FillColor = RED
				hl.OutlineColor = RED
				hl.Adornee = c
				hl.Parent = VFXLib.Folder
				table.insert(outlines, hl)
			end
		end
		label(character:FindFirstChild("Head"), ultimate and "KING CRIMSON!!" or "KING CRIMSON!", RED, 1.2, 280)
	end
	local nextGhost = 0
	VFXLib.animate(time, function(a)
		if erased[character] ~= token then
			return
		end
		if not mine and character.Parent then
			-- Everyone else: he's all but gone, leaving red afterimages.
			fade(character, 0.88)
			local now = os.clock()
			if now >= nextGhost and root.Parent then
				nextGhost = now + 0.12
				local g = VFXLib.part({ Size = Vector3.new(2, 4.6, 1), CFrame = root.CFrame, Color = RED, Transparency = 0.7 })
				VFXLib.animate(0.5, function(b)
					g.Transparency = 0.7 + 0.3 * b
				end, function()
					g:Destroy()
				end)
			end
		end
		cc.Saturation = (mine and -0.5 or -0.2) + math.sin(os.clock() * 20) * 0.04
	end, function()
		cc:Destroy()
		for _, hl in ipairs(outlines) do
			hl:Destroy()
		end
		if character.Parent then
			fade(character, 0)
		end
		if erased[character] == token then
			erased[character] = nil
		end
	end)
end

-- King Crimson close up (your ultimate): its face, Epitaph on its brow,
-- Diavolo behind it, a crimson mist.
local function ultCloseUp(character, time)
	local cc = TuskConfig.Cutscenes or {}
	if cc.Enabled == false or cc.KingCrimson == false or (lastUltCut and os.clock() - lastUltCut < 8) then
		return false
	end
	local root = Common.rootOf(character)
	local stand = TuskStand.get(character)
	if not root or not stand or not stand.Model then
		return false
	end
	lastUltCut = os.clock()
	local function kcHead()
		local h = stand.Model:FindFirstChild("Head", true)
		return h and h.Position or (root.CFrame * CFrame.new(2, 3.5, 2.8)).Position
	end
	local function shot(a)
		local h = kcHead()
		local fwd = root.CFrame.LookVector
		local side = -root.CFrame.RightVector
		return CFrame.lookAt(h + fwd * (3.4 - a) + side * 0.9 - Vector3.new(0, 0.8, 0), h + Vector3.new(0, 0.1, 0))
	end
	local ok = Cutscenes.play({
		{ From = function()
			return root.Parent and shot(0) or nil
		end, To = function()
			return root.Parent and shot(0.9) or nil
		end, Time = time, FOV = { 46, 38 }, Title = "ONLY THE RESULT REMAINS", Subtitle = "KING CRIMSON", Color = RED },
	}, { Priority = 2, Skippable = true })
	if not ok then
		return false
	end
	TuskStand.action(character, "Loom", { Target = CFrame.new(-1.2, 1.2, -1.4), Duration = time + 0.2 })
	-- The crimson mist billowing round them.
	for _ = 1, 22 do
		local at = kcHead() + Vector3.new((math.random() - 0.5) * 8, (math.random() - 0.7) * 5, (math.random() - 0.5) * 8)
		local puff = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1) * (1.5 + math.random() * 2), Color = math.random() < 0.6 and Color3.fromRGB(230, 90, 150) or RED, CFrame = CFrame.new(at), Transparency = 1 })
		puff.Shape = Enum.PartType.Ball
		local drift = Vector3.new((math.random() - 0.5) * 2, 1 + math.random(), (math.random() - 0.5) * 2)
		VFXLib.animate(time + 0.3, function(a)
			puff.CFrame = CFrame.new(at + drift * a)
			puff.Transparency = 0.45 + 0.55 * math.abs(a - 0.4) * 1.6
		end, function()
			puff:Destroy()
		end)
	end
	return true
end
DiavoloVFX.ultCloseUp = ultCloseUp

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
	TuskAnimation.play(character, "DI_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.6 or 0.6, 0.9, -3.4), Duration = 0.28 })
	VFXLib.sound(sounds.Swing, root, 0.5, 1.0 + index * 0.05)
	local look = root.CFrame.LookVector
	if index == 3 then
		chop((root.CFrame * CFrame.new(0, 1, -3)).Position, look, 1)
	else
		fist((root.CFrame * CFrame.new(index % 2 == 0 and -0.6 or 0.6, 0.8, -1.8)).Position, look, index == 4 and 1.6 or 1.1)
	end
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "Epitaph" then
		if phase == "See" and character and root then
			TuskAnimation.play(character, "DIEpitaph")
			TuskStand.action(character, "Loom", { Target = CFrame.new(0.4, 2.4, 1.4), Duration = data.Window or 1.6 })
			label(character:FindFirstChild("Head"), "EPITAPH", PINK, 1.0, 200)
			if isMe(character) then
				futureFrame(data.Window or 1.6)
			end
			-- Epitaph glows on King Crimson's brow.
			local stand = TuskStand.get(character)
			local ep = stand and stand.Model and stand.Model:FindFirstChild("Epitaph", true)
			if ep then
				local light = Instance.new("PointLight")
				light.Color = PINK
				light.Range = 6
				light.Brightness = 3
				light.Parent = ep
				task.delay(data.Window or 1.6, function()
					light:Destroy()
				end)
			end
		elseif phase == "Counter" then
			if data.From and data.To then
				afterimages(data.From, data.To, 6, RED)
			end
			local target = typeof(data.Target) == "Instance" and data.Target or nil
			local tr = target and target:FindFirstChild("HumanoidRootPart")
			if tr then
				chop(tr.Position + Vector3.new(0, 1, 0), tr.CFrame.LookVector, 1.3)
				blood(tr.Position + Vector3.new(0, 1, 0), 10, 10)
				label(target:FindFirstChild("Head"), "...!? (HE WAS ALREADY BEHIND YOU)", WHITE, 1.4, 320, Vector3.new(0, 3.6, 0))
			end
			if character then
				TuskAnimation.play(character, "DIChop")
				TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 1, -3), Duration = 0.3 })
				if isMe(character) then
					CameraFX.impactFrame(pal.Light)
				end
			end
		end
	elseif move == "Erase" then
		if phase == "Erase" and character then
			if not data.Ultimate then
				TuskAnimation.play(character, "DIErase")
			end
			eraseView(character, data.Time or 3, data.Ultimate)
		elseif phase == "Resume" and character then
			erased[character] = nil
			fade(character, 0)
			local r = Common.rootOf(character)
			if r and (isMe(character) or nearMe(r.Position, 80)) then
				shatterScreen(0.3, true)
				CameraFX.impactFrame(Color3.new(1, 1, 1))
			end
			if isMe(character) then
				label(character:FindFirstChild("Head"), "ONLY THE RESULT REMAINS", RED, 1.6, 340)
			end
			-- His fists glow while his hits can't be blocked.
			local hl = Instance.new("Highlight")
			hl.FillTransparency = 1
			hl.OutlineColor = RED
			hl.Adornee = character
			hl.Parent = VFXLib.Folder
			task.delay(data.Time or 1.5, function()
				hl:Destroy()
			end)
		end
	elseif move == "HeartPunch" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "DIHeart")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0.3, 0.9, -4.2), Duration = (data.Windup or 0.3) + 0.4 })
		elseif phase == "Through" and typeof(data.Target) == "Instance" then
			local tr = data.Target:FindFirstChild("HumanoidRootPart")
			if tr then
				local dir = data.Direction or tr.CFrame.LookVector
				-- The fist bursting out of their back.
				local arm = VFXLib.part({ Size = Vector3.new(0.7, 0.7, 3.4), Color = RED, CFrame = CFrame.lookAt(tr.Position + Vector3.new(0, 0.6, 0), tr.Position + Vector3.new(0, 0.6, 0) + dir) * CFrame.new(0, 0, -1.2) })
				local hand = VFXLib.part({ Size = Vector3.new(0.8, 0.75, 0.8), Color = Color3.fromRGB(214, 212, 222), CFrame = arm.CFrame * CFrame.new(0, 0, -1.9) })
				VFXLib.animate(0.6, function(a)
					local t = a > 0.7 and (a - 0.7) / 0.3 or 0
					arm.Transparency = t
					hand.Transparency = t
				end, function()
					arm:Destroy()
					hand:Destroy()
				end)
				blood(tr.Position + Vector3.new(0, 0.6, 0) + dir * 1.2, 18, 14)
				TuskVFX.CreateImpactStar(tr.Position + Vector3.new(0, 0.6, 0), { Size = 4.5, Rays = 10, Color = RED, Color2 = WHITE, Duration = 0.2 })
				CameraFX.shakeAt(tr.Position, 0.8, 50)
				if character and isMe(character) then
					CameraFX.impactFrame(pal.Light)
				end
			end
		elseif phase == "Bleed" and typeof(data.Target) == "Instance" then
			local tr = data.Target:FindFirstChild("HumanoidRootPart")
			if tr then
				blood(tr.Position + Vector3.new(0, 0.5, 0), 4, 4)
			end
		elseif phase == "Miss" and data.Position then
			VFXLib.burst(data.Position, { Count = 6, Color = RED, Speed = 8, Lifetime = 0.3 })
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character and root then
		TuskAnimation.play(character, "DIErase")
		if isMe(character) then
			ultCloseUp(character, data.Windup or 0.6)
		else
			label(character:FindFirstChild("Head"), "KING CRIMSON!!", RED, 1.2, 280)
		end
	elseif data.Phase == "Chop" and typeof(data.Target) == "Instance" then
		local tr = data.Target:FindFirstChild("HumanoidRootPart")
		if character then
			TuskAnimation.play(character, "DIChop")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 1, -3), Duration = 0.28 })
		end
		if tr then
			chop(tr.Position + Vector3.new(0, 1, 0), tr.CFrame.LookVector, 1.3)
			if data.Position then
				afterimages(data.Position + Vector3.new(0, 0.5, 0), data.Position + Vector3.new(0, 0.5, 0), 1, RED)
			end
		end
	elseif data.Phase == "Result" then
		for _, target in ipairs(data.Targets or {}) do
			local tr = typeof(target) == "Instance" and target:FindFirstChild("HumanoidRootPart")
			if tr then
				blood(tr.Position + Vector3.new(0, 1, 0), 16, 14)
				TuskVFX.CreateImpactStar(tr.Position + Vector3.new(0, 1, 0), { Size = 5, Rays = 10, Color = RED, Color2 = WHITE, Duration = 0.2 })
				if Players:GetPlayerFromCharacter(target) == localPlayer then
					CameraFX.impactFrame(Color3.fromRGB(255, 180, 190))
					CameraFX.shake(1, 0.4)
				end
			end
		end
		if character and root then
			worldLabel(root.Position + Vector3.new(0, 5, 0), "ONLY THE RESULT REMAINS", RED, 1.8, 380)
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
				TuskAnimation.hold(character, "DIStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "DIStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
	for character in pairs(erased) do
		if not character.Parent then
			erased[character] = nil
		end
	end
end

function DiavoloVFX.handle(name, data)
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
function DiavoloVFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
	end
end

return DiavoloVFX
