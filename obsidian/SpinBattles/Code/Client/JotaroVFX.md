---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# JotaroVFX

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `JotaroVFX` (capitals matter) |

**What it does:** Client visuals for Jotaro Kujo / STAR PLATINUM. Blocky. Star Platinum (StarPlatinumStand) floats behind him with a violet aura; Jotaro stands with a hand in his pocket ORA COMBO: Star Platinum's fists fly out with him; "ORA!" on the 4th ORA RUSH: a blur of violet fists hammering the space in front of him, "ORA ORA ORA" spilling out, then one huge "ORA!" and a shockwave STAR FINGER: two long violet fingers shoot out in a line and snap back BEARING SHOT: a flick; a silver streak and a spark where it lands STAR PLATINUM: THE WORLD: the colours invert for a beat, a dome spreads out round him and the world inside goes grey and still; frozen fighters turn grey; when time moves again the colour floods back in a ripple

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **JotaroVFX**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.JotaroVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.JotaroVFX)

	Client visuals for Jotaro Kujo / STAR PLATINUM. Blocky.
	  * Star Platinum (StarPlatinumStand) floats behind him with a violet
	    aura; Jotaro stands with a hand in his pocket
	  * ORA COMBO: Star Platinum's fists fly out with him; "ORA!" on the 4th
	  * ORA RUSH: a blur of violet fists hammering the space in front of
	    him, "ORA ORA ORA" spilling out, then one huge "ORA!" and a shockwave
	  * STAR FINGER: two long violet fingers shoot out in a line and snap back
	  * BEARING SHOT: a flick; a silver streak and a spark where it lands
	  * STAR PLATINUM: THE WORLD: the colours invert for a beat, a dome
	    spreads out round him and the world inside goes grey and still;
	    frozen fighters turn grey; when time moves again the colour floods
	    back in a ripple
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

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
local StarPlatinumStand = require(script.Parent.StarPlatinumStand)

local JotaroVFX = {}
local ACT = 20
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, StarPlatinumStand.build, { Aura = StarPlatinumStand.Aura, AuraLight = StarPlatinumStand.AuraLight, Offset = StarPlatinumStand.Offset })

local VIOLET = Color3.fromRGB(150, 120, 255)
local FIST = Color3.fromRGB(116, 118, 222)
local GLOVE = Color3.fromRGB(30, 34, 40)
local GOLD = Color3.fromRGB(240, 196, 70)
local SILVER = Color3.fromRGB(220, 226, 236)

local stanced = {}
local rushes = {} -- [character] = rush job token
local stops = {} -- [character] = { Dome, Frozen = { [character] = Highlight }, Tint }

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

-- "ORA" text popping out at a world spot.
local function ora(at, big)
	local anchor = VFXLib.part({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(at), Transparency = 1 })
	label(anchor, big and "ORA!" or "ORA", big and GOLD or VIOLET, big and 1.0 or 0.5, big and 260 or 120, Vector3.new((math.random() - 0.5) * 3, math.random() * 2, 0))
	task.delay(1.1, function()
		anchor:Destroy()
	end)
end

-- One violet fist flying forward from `from` along `dir`, then fading.
local function fist(from, dir, size)
	size = size or 1
	local f = VFXLib.part({ Size = Vector3.new(0.75, 0.75, 0.9) * size, Color = FIST, Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
	local glove = VFXLib.part({ Size = Vector3.new(0.78, 0.4, 0.5) * size, Color = GLOVE, Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
	local trail = VFXLib.part({ Size = Vector3.new(0.4, 0.4, 2.2) * size, Color = VIOLET, Transparency = 0.5 })
	VFXLib.animate(0.16, function(a)
		local p = from + dir * (a * 3.2)
		local cf = CFrame.lookAt(p, p + dir)
		f.CFrame = cf
		glove.CFrame = cf * CFrame.new(0, 0.2 * size, 0.1 * size)
		trail.CFrame = cf * CFrame.new(0, 0, 1.3 * size)
		local t = a < 0.6 and 0.15 or 0.15 + (a - 0.6) / 0.4 * 0.85
		f.Transparency = t
		glove.Transparency = t
		trail.Transparency = 0.5 + 0.5 * a
	end, function()
		f:Destroy()
		glove:Destroy()
		trail:Destroy()
	end)
end

local function tracer(from, to, hit)
	local len = (to - from).Magnitude
	if len > 0.5 then
		local line = VFXLib.part({ Size = Vector3.new(0.15, 0.15, len), CFrame = CFrame.lookAt((from + to) / 2, to), Color = SILVER, Transparency = 0.05 })
		VFXLib.animate(0.18, function(a)
			line.Transparency = 0.05 + 0.95 * a
			line.Size = Vector3.new(0.15 * (1 - a), 0.15 * (1 - a), len)
		end, function()
			line:Destroy()
		end)
	end
	VFXLib.flash(from, VIOLET, 4, 10, 0.08)
	if hit then
		TuskVFX.CreateImpactStar(to, { Size = 2.6, Rays = 6, Color = SILVER, Color2 = VIOLET, Duration = 0.14 })
	else
		VFXLib.burst(to, { Count = 5, Color = SILVER, Speed = 10, Lifetime = 0.3 })
	end
	VFXLib.sound(sounds.NailFire, from, 0.6, 1.6)
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
	TuskAnimation.play(character, "JT_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1, -3.4), Duration = 0.28 })
	VFXLib.sound(sounds.Swing, root, 0.5, 1.0 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or pal.Second)
	fist((root.CFrame * CFrame.new(index % 2 == 0 and -0.6 or 0.6, 0.8, -1.8)).Position, root.CFrame.LookVector, 1.1)
	if index == 4 then
		ora((root.CFrame * CFrame.new(0, 2, -3)).Position, true)
	end
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function rush(character, duration)
	local token = {}
	rushes[character] = token
	TuskAnimation.play(character, "JTRush")
	TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 0.8, -3.6), Duration = duration })
	local start = os.clock()
	local nextFist, nextOra = 0, 0
	VFXLib.animate(duration, function()
		local root = Common.rootOf(character)
		if rushes[character] ~= token or not root then
			return
		end
		local t = os.clock() - start
		if t >= nextFist then
			nextFist = t + 0.025
			local off = CFrame.new((math.random() - 0.5) * 2.6, 0.4 + (math.random() - 0.5) * 2.2, -2.4)
			fist((root.CFrame * off).Position, root.CFrame.LookVector, 0.9 + math.random() * 0.3)
		end
		if t >= nextOra then
			nextOra = t + 0.16
			ora((root.CFrame * CFrame.new((math.random() - 0.5) * 4, 2 + math.random(), -3)).Position, false)
		end
	end, function()
		if rushes[character] == token then
			rushes[character] = nil
		end
	end)
	if Common.isLocal(character) then
		CameraFX.speedLines(duration, VIOLET)
	end
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "OraRush" then
		if phase == "Start" and character and root then
			rush(character, (data.Windup or 0.15) + (data.Duration or 1.5))
		elseif phase == "Hit" and data.Position then
			TuskVFX.CreateImpactStar(data.Position, { Size = 2.2, Rays = 5, Color = VIOLET, Color2 = Color3.new(1, 1, 1), Duration = 0.08 })
		elseif phase == "Finish" and data.Position then
			if character then
				rushes[character] = nil
				TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 0.8, -4.2), Duration = 0.35 })
			end
			ora(data.Position + Vector3.new(0, 2, 0), true)
			local dir = data.Direction or Vector3.new(0, 0, -1)
			fist(data.Position - dir * 1.5, dir, 2.2)
			TuskVFX.CreateRotationalShockwave(CFrame.lookAt(data.Position, data.Position + dir) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = data.Radius or 8, Layers = 3, Color = VIOLET, Color2 = GOLD, Particles = 1, Width = 0.5 })
			CameraFX.shakeAt(data.Position, 0.8, 50)
			if character and Common.isLocal(character) then
				CameraFX.impactFrame(pal.Light)
			end
		elseif phase == "Stop" and character then
			rushes[character] = nil
		end
	elseif move == "StarFinger" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "JTPoint")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0.6, 1, -2.6), Duration = (data.Windup or 0.2) + 0.4 })
		elseif phase == "Strike" and data.From and data.Direction then
			local dir, length = data.Direction, data.Length or 20
			local from = data.From + Vector3.new(0, 1.2, 0)
			for k, side in ipairs({ -0.18, 0.18 }) do
				local finger = VFXLib.part({ Size = Vector3.new(0.3, 0.3, 1), Color = FIST, Material = Enum.Material.SmoothPlastic })
				local tip = VFXLib.part({ Size = Vector3.new(0.34, 0.34, 0.4), Color = VIOLET, Transparency = 0.1 })
				local right = dir:Cross(Vector3.new(0, 1, 0))
				local base = from + right * side + Vector3.new(0, k * 0.05, 0)
				VFXLib.animate(0.45, function(a)
					local out = a < 0.3 and VFXLib.easeOut(a / 0.3) or (a < 0.6 and 1 or 1 - (a - 0.6) / 0.4)
					local l = math.max(length * out, 0.3)
					finger.Size = Vector3.new(0.3, 0.3, l)
					finger.CFrame = CFrame.lookAt(base + dir * (l / 2), base + dir * l)
					tip.CFrame = CFrame.lookAt(base + dir * l, base + dir * (l + 1))
				end, function()
					finger:Destroy()
					tip:Destroy()
				end)
			end
			task.delay(0.12, function()
				VFXLib.burst(from + dir * length, { Count = 10, Color = VIOLET, Speed = 14, Lifetime = 0.3 })
			end)
			VFXLib.sound(sounds.Swing, from, 0.6, 1.5)
		end
	elseif move == "BearingShot" then
		if phase == "Flick" and character and root then
			TuskAnimation.play(character, "JTFlick")
		elseif phase == "Shot" and data.From and data.To then
			tracer(data.From, data.To, data.Hit)
		end
	end
end

---------------------------------------------------------------------------
-- STAR PLATINUM: THE WORLD
---------------------------------------------------------------------------
local function invertFlash()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "StarPlatinumInvert"
	cc.Parent = Lighting
	VFXLib.animate(0.45, function(a)
		local k = a < 0.5 and 1 or 1 - (a - 0.5) / 0.5
		cc.Saturation = -1 * k
		cc.Contrast = 0.6 * k
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(180, 160, 255), k)
		cc.Brightness = 0.15 * k
	end, function()
		cc:Destroy()
	end)
end

local function stillTint(duration)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "StarPlatinumStill"
	cc.Parent = Lighting
	VFXLib.animate(duration, function(a)
		local k = a < 0.08 and a / 0.08 or (a > 0.92 and (1 - a) / 0.08 or 1)
		cc.Saturation = -0.85 * k
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(205, 200, 235), k)
		cc.Contrast = 0.1 * k
	end, function()
		cc:Destroy()
	end)
	return cc
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character and root then
		TuskAnimation.play(character, "JTCap")
		TuskStand.action(character, "Loom", { Target = CFrame.new(1.4, 2.6, 2.2), Duration = (data.Windup or 0.7) + 0.6 })
		label(character:FindFirstChild("Head"), "STAR PLATINUM: THE WORLD", VIOLET, 2.0, 380)
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 0.9)
	elseif data.Phase == "Stop" and data.Position then
		local center, range, duration = data.Position, data.Range or 55, data.Duration or 5
		local stop = { Frozen = {} }
		if character then
			stops[character] = stop
		end
		-- The dome spreads out from him.
		local dome = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(center), Color = VIOLET, Material = Enum.Material.ForceField, Transparency = 0.3 })
		stop.Dome = dome
		VFXLib.animate(0.6, function(a)
			local d = range * 2 * VFXLib.easeOut(a)
			dome.Size = Vector3.new(d, d, d)
			dome.Transparency = 0.3 + 0.5 * a
		end)
		VFXLib.animate(duration, function(a)
			if a > 0.9 then
				dome.Transparency = 0.8 + (a - 0.9) / 0.1 * 0.2
			end
		end, function()
			dome:Destroy()
		end)
		-- Everyone frozen turns grey.
		for _, target in ipairs(data.Frozen or {}) do
			if typeof(target) == "Instance" and target.Parent then
				local h = Instance.new("Highlight")
				h.Name = "StarPlatinumFrozen"
				h.FillColor = Color3.fromRGB(150, 150, 160)
				h.FillTransparency = 0.35
				h.OutlineColor = Color3.fromRGB(90, 90, 110)
				h.OutlineTransparency = 0.4
				h.Adornee = target
				h.Parent = target
				stop.Frozen[target] = h
				task.delay(duration + 0.5, function()
					if h.Parent then
						h:Destroy()
					end
				end)
			end
		end
		if nearLocal(center, range + 10) or (character and Common.isLocal(character)) then
			invertFlash()
			task.delay(0.4, function()
				stop.Tint = stillTint(math.max(0.2, duration - 0.4))
			end)
			CameraFX.fovPunch(-12, 0.6)
		end
		VFXLib.sound(sounds.AwakeningBurst or sounds.Swing, center, 0.7, 0.7)
	elseif data.Phase == "Resume" then
		local stop = character and stops[character]
		if character then
			stops[character] = nil
		end
		if stop then
			for _, h in pairs(stop.Frozen) do
				if h.Parent then
					h:Destroy()
				end
			end
			if stop.Tint and stop.Tint.Parent then
				stop.Tint:Destroy()
			end
			if stop.Dome and stop.Dome.Parent then
				stop.Dome:Destroy()
			end
		end
		-- Colour floods back in a ripple.
		if data.Position then
			local ring = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(data.Position), Color = Color3.fromRGB(230, 220, 255), Material = Enum.Material.ForceField, Transparency = 0.4 })
			VFXLib.animate(0.5, function(a)
				local d = 120 * VFXLib.easeOut(a)
				ring.Size = Vector3.new(d, d, d)
				ring.Transparency = 0.4 + 0.6 * a
			end, function()
				ring:Destroy()
			end)
			if nearLocal(data.Position, 70) then
				CameraFX.shake(0.4, 0.3)
			end
		end
		if character and character:FindFirstChild("Head") then
			label(character:FindFirstChild("Head"), "TIME RESUMES", Color3.new(1, 1, 1), 1.2, 240)
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
				TuskAnimation.hold(character, "JTStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "JTStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function JotaroVFX.handle(name, data)
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
function JotaroVFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
	end
end

return JotaroVFX
```
