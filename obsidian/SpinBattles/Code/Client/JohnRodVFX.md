---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# JohnRodVFX

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `JohnRodVFX` (capitals matter) |

**What it does:** Client side of JOHN ROD, the remote-control Stand. Blocky. John Rod (JohnRodStand), a bent rod in the outline of a man, stands beside its user with a pale blue aura; the user stands hands on hips REMOTE CONTROL (yours): while you steer it, your movement keys / thumbstick go to John Rod instead of you, your camera follows it, and a wooden plaque shows "STEERING JOHN ROD", how far it is from you (a meter up to its range) and "1: BRING IT BACK". You stand with two fingers at your temple. Everyone sees a faint shining line from you to it while it's away ROD STRIKES / ROD LASH: white streaks from wherever John Rod is; the lash shoots a long rod straight out and snaps it back WIRE SNARE: a wire shoots to the target and coils round them while they're snared (from the SnaredUntil attribute) OUTLINE CAGE: a ring marks the spot, then rods spring up all round into a cage and finally squeeze in if you're hit while steering it: "FEEDBACK!" and the camera snaps back

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **JohnRodVFX**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
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

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local TuskStandModels = require(Shared.TuskStandModels)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local Common = require(script.Parent.Parent.TuskActCommon)
local Fighters = require(script.Parent.Parent.Fighters)
local UITheme = require(script.Parent.Parent.UI.UITheme)
local JohnRodStand = require(script.Parent.JohnRodStand)

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
```
