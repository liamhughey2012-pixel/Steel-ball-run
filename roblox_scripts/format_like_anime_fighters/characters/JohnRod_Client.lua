--[[
	JohnRod_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	John Rod: a remote-control Stand.
	Its other half is JohnRod_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "johnrod" or __expect.Side ~= "client") then
		error("this is the code for JohnRod_Client, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to JohnRod_Client and put it in ReplicatedStorage > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: JohnRodStand
-- ======================================================================
__modules["JohnRodStand"] = function()
--[[
	TuskActVFX.JohnRodStand  (StarterPlayerScripts.SpinClient.TuskActVFX.JohnRodStand)

	JOHN ROD, matched to the art: a single bent metal rod tracing the
	outline of a man. One continuous line: up from the left foot (bent out
	sideways), up the left leg, out to an akimbo elbow, up to the shoulder,
	into the neck, round a loop for the head, back down the neck, out to the
	right shoulder and akimbo elbow, in to the waist, and down the long
	right leg to a foot bent out the other way. It's bright pale metal with
	a soft shine; TuskStand gives it a pale blue aura.
	Registered with TuskStandModels by JohnRodVFX. TuskStand floats it
	beside its user, or draws it wherever the user is steering it
	(StandRemotePos).
]]

local JohnRodStand = {}

local ROD = Color3.fromRGB(236, 240, 250)
local SHINE = Color3.fromRGB(255, 255, 255)
local DIAMETER = 0.22
local CHEST = 4.2 -- the rig's body sits at this height above the feet

JohnRodStand.Aura = Color3.fromRGB(170, 215, 255)
JohnRodStand.AuraLight = Color3.fromRGB(240, 250, 255)
JohnRodStand.Offset = CFrame.new(2.8, 1.2, 1.5)

-- The outline (x, y) from the left foot round to the right foot; y = 0 is
-- the ground. The head loop is added in between.
local LEFT = {
	{ -2.4, 1.55 }, { -1.35, 1.42 }, { -1.27, 2.6 }, { -1.15, 3.8 }, { -2.1, 4.55 }, { -1.3, 5.5 }, { -0.35, 5.62 }, { -0.3, 6.05 },
}
local RIGHT = {
	{ 0.3, 6.05 }, { 0.35, 5.62 }, { 1.3, 5.5 }, { 2.1, 4.55 }, { 1.2, 3.9 }, { 1.4, 1.2 }, { 1.6, 0.12 }, { 2.6, 0.02 },
}
local HEAD_CENTER, HEAD_RADIUS = { 0, 6.78 }, 0.78

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

-- The full path, head loop included.
local function outline()
	local pts = {}
	for _, p in ipairs(LEFT) do
		table.insert(pts, p)
	end
	-- Round the head: from its bottom-left, over the top, to its bottom-right.
	local a0, a1 = math.rad(-115), math.rad(-65 - 360)
	local steps = 16
	for i = 1, steps - 1 do
		local a = a0 + (a1 - a0) * i / steps
		table.insert(pts, { HEAD_CENTER[1] + math.cos(a) * HEAD_RADIUS, HEAD_CENTER[2] + math.sin(a) * HEAD_RADIUS })
	end
	for _, p in ipairs(RIGHT) do
		table.insert(pts, p)
	end
	return pts
end

function JohnRodStand.build(scale)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "JohnRod"
	local rig = { Joints = {} }
	-- An invisible core at chest height holds the rod.
	local body = newPart(model, "Body", Vector3.new(0.4, 0.4, 0.4), ROD)
	body.Transparency = 1
	body.Anchored = true
	body.Massless = false
	body.CFrame = CFrame.new()
	model.PrimaryPart = body
	rig.Body = body
	local d = DIAMETER * s
	local pts = outline()
	local function at(p)
		return Vector3.new(p[1] * s, (p[2] - CHEST) * s, 0)
	end
	for i = 1, #pts - 1 do
		local a, b = at(pts[i]), at(pts[i + 1])
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		-- Cylinders run along X: aim X from a to b.
		local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0)
		local seg = weld(model, body, "Rod", Vector3.new(len + d * 0.5, d, d), ROD, cf)
		seg.Shape = Enum.PartType.Cylinder
		seg.Reflectance = 0.25
		-- Round the bends.
		local bend = weld(model, body, "Bend", Vector3.new(d, d, d), ROD, CFrame.new(b))
		bend.Shape = Enum.PartType.Ball
	end
	-- Rounded ends at the feet, with a glint.
	for _, p in ipairs({ pts[1], pts[#pts] }) do
		local tip = weld(model, body, "Tip", Vector3.new(d * 1.3, d * 1.3, d * 1.3), SHINE, CFrame.new(at(p)), Enum.Material.Neon)
		tip.Shape = Enum.PartType.Ball
	end
	-- A little shine high on the head loop.
	local glint = weld(model, body, "Glint", Vector3.new(d * 0.9, d * 0.9, d * 0.9), SHINE, CFrame.new(at({ HEAD_CENTER[1] - 0.45, HEAD_CENTER[2] + 0.55 })) * CFrame.new(0, 0, -d * 0.4), Enum.Material.Neon)
	glint.Shape = Enum.PartType.Ball
	-- Where its strikes come from: the right elbow.
	local point = Instance.new("Attachment")
	point.Name = "NailPoint"
	point.Position = at(RIGHT[4])
	point.Parent = body
	rig.NailPoint = point
	return model, rig
end

return JohnRodStand
end

-- ======================================================================
-- MODULE: JohnRodVFX
-- ======================================================================
__modules["JohnRodVFX"] = function()
--[[
	TuskActVFX.JohnRodVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.JohnRodVFX)

	Client side of JOHN ROD, the remote-control Stand. Blocky.
	  * John Rod (JohnRodStand), a bent rod in the outline of a man, stands
	    beside its user with a pale blue aura; the user stands hands on hips
	  * REMOTE CONTROL (yours): while you steer it, your movement keys /
	    thumbstick go to John Rod instead of you, your camera follows it,
	    and a wooden plaque shows "STEERING JOHN ROD", how far it is from
	    you (a meter up to its range) and "1: BRING IT BACK". You stand with
	    two fingers at your temple. Everyone sees a faint shining line from
	    you to it while it's away
	  * ROD STRIKES / ROD LASH: white streaks from wherever John Rod is;
	    the lash shoots a long rod straight out and snaps it back
	  * WIRE SNARE: a wire shoots to the target and coils round them while
	    they're snared (from the SnaredUntil attribute)
	  * OUTLINE CAGE: a ring marks the spot, then rods spring up all round
	    into a cage and finally squeeze in
	  * if you're hit while steering it: "FEEDBACK!" and the camera snaps back
]]

local Players = game:GetService("Players")

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
local UITheme = __require("UITheme")
local JohnRodStand = __require("JohnRodStand")

local JohnRodVFX = {}
local ACT = 18
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer
local cfg = TuskConfig.JohnRod

TuskStandModels.register(ACT, JohnRodStand.build, { Aura = JohnRodStand.Aura, AuraLight = JohnRodStand.AuraLight, Offset = JohnRodStand.Offset })

local ROD = Color3.fromRGB(236, 240, 250)
local WIRE = Color3.fromRGB(200, 225, 255)

local stanced = {} -- [character] = pose name held
local tethers = {} -- [character] = line part
local snareRings = {} -- [character] = { parts }
local pilot -- the local player's steering session

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function streak(from, to, color, width, life)
	local len = (to - from).Magnitude
	if len < 0.1 then
		return
	end
	local p = VFXLib.part({ Size = Vector3.new(width or 0.2, width or 0.2, len), CFrame = CFrame.lookAt((from + to) / 2, to), Color = color or ROD, Material = Enum.Material.Neon, Transparency = 0.15 })
	VFXLib.animate(life or 0.2, function(a)
		p.Transparency = 0.15 + 0.85 * a
	end, function()
		p:Destroy()
	end)
end

local function label(adornee, text, color, duration, size)
	if not adornee then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size or 220, (size or 220) / 5)
	bb.StudsOffset = Vector3.new(0, 3, 0)
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
	VFXLib.animate(duration or 1.2, function(a)
		bb.StudsOffset = Vector3.new(0, 3 + a, 0)
		t.TextTransparency = math.max(0, a * 1.5 - 0.5)
		t.TextStrokeTransparency = 0.1 + 0.9 * a
	end, function()
		bb:Destroy()
	end)
end

local function remotePos(character)
	local p = character and character:GetAttribute("StandRemotePos")
	return typeof(p) == "Vector3" and p or nil
end

---------------------------------------------------------------------------
-- REMOTE CONTROL: your keys steer it, your camera follows it
---------------------------------------------------------------------------
local controls
local function moveVector()
	if controls == nil then
		local ok, result = pcall(function()
			local module = localPlayer:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")
			return module and require(module):GetControls()
		end)
		controls = ok and result or false
	end
	if controls then
		local ok, v = pcall(function()
			return controls:GetMoveVector()
		end)
		if ok and typeof(v) == "Vector3" then
			return v
		end
	end
	local character = localPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	return hum and hum.MoveDirection or Vector3.new()
end

local function buildPilotHud()
	local pg = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end
	local gui = UITheme.new("ScreenGui", { Name = "JohnRodPilot", ResetOnSpawn = false, DisplayOrder = 6 }, pg)
	local plaque = UITheme.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(300, 74) }, gui)
	UITheme.wood(plaque, { Planks = 2, Border = 4, Brackets = true, BracketSize = 14 })
	UITheme.label(plaque, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 24), Text = "STEERING JOHN ROD", Font = UITheme.Font.Title, TextColor3 = UITheme.C.GOLD, TextStrokeTransparency = 0.4, ZIndex = plaque.ZIndex + 1 })
	local bar, fill = UITheme.bar(plaque, Color3.fromRGB(120, 200, 255), { Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -28, 0, 14), ZIndex = plaque.ZIndex + 1 })
	local hint = UITheme.label(plaque, { Position = UDim2.fromOffset(10, 50), Size = UDim2.new(1, -20, 0, 16), Text = "1: BRING IT BACK", Font = UITheme.Font.Body, TextColor3 = UITheme.C.PAPER, ZIndex = plaque.ZIndex + 1 })
	UITheme.pop(plaque)
	return { Gui = gui, Fill = fill, Bar = bar, Hint = hint }
end

local function startPilot(character)
	local camera = workspace.CurrentCamera
	local root = character:FindFirstChild("HumanoidRootPart")
	local anchor = Instance.new("Part")
	anchor.Name = "JohnRodCamera"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(remotePos(character) or (root and root.Position) or Vector3.new())
	anchor.Parent = workspace
	pilot = { Character = character, Anchor = anchor, OldSubject = camera and camera.CameraSubject, NextSend = 0, LastMove = Vector3.new(), Hud = buildPilotHud() }
	if camera then
		camera.CameraSubject = anchor
	end
end

local function stopPilot()
	if not pilot then
		return
	end
	local camera = workspace.CurrentCamera
	local character = pilot.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if camera then
		camera.CameraSubject = hum or pilot.OldSubject
	end
	pilot.Anchor:Destroy()
	if pilot.Hud then
		pilot.Hud.Gui:Destroy()
	end
	pilot = nil
end

local Request
local function stepPilot(dt)
	local character = localPlayer and localPlayer.Character
	local steering = character and character:GetAttribute("RodPiloting") == true and remotePos(character) ~= nil
	if steering and not pilot then
		startPilot(character)
	elseif not steering and pilot then
		stopPilot()
	end
	if not pilot then
		return
	end
	local target = remotePos(character)
	if target then
		pilot.Anchor.CFrame = CFrame.new(pilot.Anchor.Position:Lerp(target, math.clamp(dt * 12, 0, 1)))
	end
	-- Movement keys, relative to the camera, flattened.
	local camera = workspace.CurrentCamera
	local mv = moveVector()
	local move = Vector3.new()
	if camera and mv.Magnitude > 0.05 then
		if controls then
			local look = camera.CFrame.LookVector
			local right = camera.CFrame.RightVector
			local f = Vector3.new(look.X, 0, look.Z)
			local r = Vector3.new(right.X, 0, right.Z)
			f = f.Magnitude > 0 and f.Unit or Vector3.new(0, 0, -1)
			r = r.Magnitude > 0 and r.Unit or Vector3.new(1, 0, 0)
			move = r * mv.X + f * -mv.Z
		else
			move = Vector3.new(mv.X, 0, mv.Z)
		end
		if move.Magnitude > 1 then
			move = move.Unit
		end
	end
	local now = os.clock()
	if now >= pilot.NextSend and ((move - pilot.LastMove).Magnitude > 0.05 or now >= pilot.NextSend + 0.3) then
		pilot.NextSend = now + 0.08
		pilot.LastMove = move
		Request = Request or Net.get("TuskRequest")
		Request:FireServer("Steer", move)
	end
	-- The range meter.
	local root = character:FindFirstChild("HumanoidRootPart")
	if pilot.Hud and root and target then
		local d = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z).Magnitude
		local k = math.clamp(d / cfg.Pilot.Range, 0, 1)
		pilot.Hud.Fill.Size = UDim2.fromScale(k, 1)
		pilot.Hud.Fill.BackgroundColor3 = k > 0.9 and UITheme.C.RED or Color3.fromRGB(120, 200, 255)
		pilot.Hud.Hint.Text = string.format("%dm AWAY  ·  1: BRING IT BACK", math.floor(d + 0.5))
	end
end

-- Everyone: a faint shining line from a steering user to their rod.
local function stepTethers()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character then
			local pos = character:GetAttribute("RodPiloting") and remotePos(character)
			local root = character:FindFirstChild("HumanoidRootPart")
			if pos and root then
				local line = tethers[character]
				if not line then
					line = VFXLib.part({ Size = Vector3.new(0.06, 0.06, 1), Color = WIRE, Material = Enum.Material.Neon, Transparency = 0.7 })
					tethers[character] = line
				end
				local from = root.Position + Vector3.new(0, 1.5, 0)
				local len = (pos - from).Magnitude
				line.Size = Vector3.new(0.06, 0.06, math.max(len, 0.1))
				line.CFrame = CFrame.lookAt((from + pos) / 2, pos)
			elseif tethers[character] then
				tethers[character]:Destroy()
				tethers[character] = nil
			end
		end
	end
	for character, line in pairs(tethers) do
		if not character.Parent then
			line:Destroy()
			tethers[character] = nil
		end
	end
end

---------------------------------------------------------------------------
-- WIRE SNARE: coils round anyone snared
---------------------------------------------------------------------------
local function stepSnares()
	local t = workspace:GetServerTimeNow()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local on = (character:GetAttribute("SnaredUntil") or 0) > t
			if on and not snareRings[character] then
				local rings = {}
				for k = 1, 3 do
					rings[k] = VFXLib.part({ Size = Vector3.new(0.12, 3.2, 3.2), Shape = Enum.PartType.Cylinder, Color = ROD, Material = Enum.Material.Neon, Transparency = 0.2 })
				end
				snareRings[character] = rings
			elseif not on and snareRings[character] then
				for _, r in ipairs(snareRings[character]) do
					r:Destroy()
				end
				snareRings[character] = nil
			end
			if snareRings[character] then
				for k, r in ipairs(snareRings[character]) do
					r.CFrame = CFrame.new(root.Position + Vector3.new(0, -1.2 + k * 0.9, 0)) * CFrame.Angles(0, os.clock() * (2 + k), math.pi / 2 + math.sin(os.clock() * 3 + k) * 0.15)
				end
			end
		end
	end
	for character, rings in pairs(snareRings) do
		if not character.Parent then
			for _, r in ipairs(rings) do
				r:Destroy()
			end
			snareRings[character] = nil
		end
	end
end

---------------------------------------------------------------------------
-- OUTLINE CAGE
---------------------------------------------------------------------------
local function ground(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { VFXLib.Folder }
	local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position or (pos - Vector3.new(0, 4, 0))
end

local function cage(data)
	local center = ground(data.Position)
	local r = data.Radius or 14
	local bars = {}
	local count = 18
	for i = 1, count do
		bars[i] = VFXLib.part({ Size = Vector3.new(0.3, 0.1, 0.3), Color = ROD, Material = Enum.Material.Neon, Transparency = 0.1 })
	end
	local top = VFXLib.part({ Size = Vector3.new(0.25, r * 2, r * 2), Shape = Enum.PartType.Cylinder, Color = ROD, Material = Enum.Material.Neon, Transparency = 1 })
	local duration = data.Duration or 3
	VFXLib.animate(duration + 0.6, function(a)
		local t = a * (duration + 0.6)
		local grow = math.min(t / 0.25, 1)
		local squeeze = t > duration and (t - duration) / 0.6 or 0
		local rr = r * (1 - squeeze * 0.8)
		for i, b in ipairs(bars) do
			local ang = i / count * math.pi * 2 + t * 0.3
			local h = 9 * grow
			b.Size = Vector3.new(0.3, h, 0.3)
			b.CFrame = CFrame.new(center + Vector3.new(math.cos(ang) * rr, h / 2, math.sin(ang) * rr))
			b.Transparency = 0.1 + squeeze * 0.9
		end
		top.Size = Vector3.new(0.25, rr * 2, rr * 2)
		top.CFrame = CFrame.new(center + Vector3.new(0, 9 * grow, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		top.Transparency = grow < 1 and 1 or (0.4 + squeeze * 0.6)
	end, function()
		for _, b in ipairs(bars) do
			b:Destroy()
		end
		top:Destroy()
	end)
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
	if not data.Remote then
		TuskAnimation.play(character, "JRFlick")
	end
	local from = data.Position or root.Position
	local dir = data.Direction or root.CFrame.LookVector
	local side = ((data.Index or 1) % 2 == 0) and -1 or 1
	local right = dir:Cross(Vector3.new(0, 1, 0))
	right = right.Magnitude > 0 and right.Unit or Vector3.new(1, 0, 0)
	streak(from + right * side * 1.2, from + dir * 5.5 - right * side * 0.8, ROD, 0.22, 0.18)
	if data.Hit then
		TuskVFX.CreateImpactStar(from + dir * 4.5, { Size = 1.8, Rays = 5, Color = pal.Second, Color2 = Color3.new(1, 1, 1), Duration = 0.1 })
	end
	VFXLib.sound(sounds.Swing, from, 0.5, 1.3 + (data.Index or 1) * 0.05)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "Pilot" then
		if phase == "Send" and data.Position then
			VFXLib.burst(data.Position, { Count = 14, Color = WIRE, Speed = 8, Lifetime = 0.5 })
		elseif phase == "Return" then
			if data.From then
				VFXLib.burst(data.From, { Count = 12, Color = WIRE, Speed = 8, Lifetime = 0.5 })
			end
		elseif phase == "Feedback" and character then
			label(character:FindFirstChild("Head"), "FEEDBACK!", UITheme.C.RED, 1.2)
			if Common.isLocal(character) then
				CameraFX.shake(0.6, 0.3)
			end
		end
	elseif move == "Lash" then
		if phase == "Wind" and character and root and not remotePos(character) then
			TuskAnimation.play(character, "JRFlick")
		elseif phase == "Strike" and data.Position and data.Direction then
			local from = data.Position + Vector3.new(0, -0.5, 0)
			local to = from + data.Direction * (data.Length or 16)
			local rod = VFXLib.part({ Size = Vector3.new(0.25, 0.25, 0.1), Color = ROD, Material = Enum.Material.Neon, Transparency = 0.05 })
			VFXLib.animate(0.3, function(a)
				local out = a < 0.4 and VFXLib.easeOut(a / 0.4) or 1 - (a - 0.4) / 0.6
				local tip = from:Lerp(to, out)
				local len = math.max((tip - from).Magnitude, 0.1)
				rod.Size = Vector3.new(0.25, 0.25, len)
				rod.CFrame = CFrame.lookAt((from + tip) / 2, tip + data.Direction * 0.01)
			end, function()
				rod:Destroy()
			end)
			VFXLib.burst(to, { Count = 8, Color = WIRE, Speed = 12, Lifetime = 0.3 })
			VFXLib.sound(sounds.Swing, from, 0.6, 1.6)
		end
	elseif move == "Snare" then
		if phase == "Throw" and data.Position and data.Target then
			local tr = data.Target:FindFirstChild("HumanoidRootPart")
			if tr then
				streak(data.Position, tr.Position, WIRE, 0.1, (data.Windup or 0.2) + 0.15)
			end
		elseif phase == "Bound" and data.Target then
			label(data.Target:FindFirstChild("Head"), "SNARED", WIRE, 1.2)
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	if data.Phase == "Bend" and data.Position then
		if character and not remotePos(character) then
			TuskAnimation.play(character, "JRCage")
		end
		local at = ground(data.Position)
		local ring = VFXLib.part({ Size = Vector3.new(0.15, 1, 1), Shape = Enum.PartType.Cylinder, Color = ROD, Material = Enum.Material.Neon, Transparency = 0.3 })
		VFXLib.animate(data.Windup or 0.6, function(a)
			local d = (data.Radius or 14) * 2 * VFXLib.easeOut(a)
			ring.Size = Vector3.new(0.15, d, d)
			ring.CFrame = CFrame.new(at + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		end, function()
			ring:Destroy()
		end)
		if character then
			label(character:FindFirstChild("Head"), "OUTLINE CAGE", pal.Second, 1.4, 260)
		end
	elseif data.Phase == "Cage" and data.Position then
		cage(data)
	elseif data.Phase == "Squeeze" and data.Position then
		VFXLib.flash(data.Position, ROD, 5, 30, 0.3)
		local r = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - data.Position).Magnitude < 40 then
			CameraFX.shake(0.7, 0.3)
		end
	elseif data.Phase == "Snap" and data.Position then
		-- The corpse move: rods lash out in every direction.
		for k = 1, 12 do
			local a = k / 12 * math.pi * 2
			streak(data.Position, data.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * (data.Radius or 18), ROD, 0.2, 0.3)
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
			local want = nil
			if character:GetAttribute("TuskAct") == ACT then
				want = character:GetAttribute("RodPiloting") and "JRFocus" or "JRStance"
			end
			local have = stanced[character]
			if want ~= have then
				if have then
					TuskAnimation.stopHold(character, have)
				end
				if want then
					TuskAnimation.hold(character, want)
				end
				stanced[character] = want
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function JohnRodVFX.handle(name, data)
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
function JohnRodVFX.step(dt)
	dt = dt or 1 / 60
	stepPilot(dt)
	stepTethers()
	stepSnares()
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
	end
end

return JohnRodVFX
end
end
