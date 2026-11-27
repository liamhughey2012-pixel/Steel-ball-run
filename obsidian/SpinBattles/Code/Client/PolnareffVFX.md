---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# PolnareffVFX

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `PolnareffVFX` (capitals matter) |

**What it does:** Client visuals for Jean Pierre Polnareff / SILVER CHARIOT. Blocky. Silver Chariot (SilverChariotStand), a silver knight with a rapier, floats behind him with a pale silver-blue aura RAPIER COMBO: bright thrust streaks; "HORA!" on the 4th HORA HORA RUSH: dozens of thrust streaks stabbing the space in front of him, "HORA HORA" spilling out, a final thrust and a shockwave ARMOR OFF: the armour plates burst off and fly away; while it's off he leaves silver afterimages as he moves RAPIER SHOT: the blade flies out like a bullet, a streak behind it AFTERIMAGE STORM: a ring of see-through Silver Chariots round the target, circling and stabbing in; then they all thrust at once

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **PolnareffVFX**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
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
local SilverChariotStand = require(script.Parent.SilverChariotStand)

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
				-- (Chariot Requiem keeps the same stance.)
				if character:GetAttribute("TuskAct") ~= 24 then
					TuskAnimation.stopHold(character, "PNStance")
				end
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
```
