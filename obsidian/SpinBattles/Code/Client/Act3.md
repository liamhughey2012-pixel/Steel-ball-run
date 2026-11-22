---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# Act3

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `Act3` (capitals matter) |

**What it does:** Client choreography for Tusk Act 3 (spatial movement): deep-blue layered portals, blue distortion afterimages, a tearing dimensional break.

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **Act3**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.Act3  (StarterPlayerScripts.SpinClient.TuskActVFX.Act3)
	Client choreography for Tusk Act 3 (spatial movement): deep-blue
	layered portals, blue distortion afterimages, a tearing dimensional break.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local TuskStand = require(script.Parent.Parent.TuskStand)
local Common = require(script.Parent.Parent.TuskActCommon)

local Act3 = {}
local pal = Common.palette(3)
local sounds = TuskConfig.Sounds

local function onStep(data)
	local character = data.Character
	local up = Vector3.new(0, 1, 0)
	Common.portal(data.From + up, data.From + up + data.Direction * 5, 2.4, 0.3, pal)
	Common.portal(data.To + up, data.To + up - data.Direction * 5, 2.4, 0.35, pal, 0.05)
	-- Blue distortion afterimages along the path.
	local steps = 5
	for i = 1, steps do
		local p = data.From:Lerp(data.To, i / (steps + 1))
		VFXLib.afterimage(CFrame.new(p), 2.2, pal.Main)
		VFXLib.burst(p, { Count = 3, Color = pal.Light, Speed = 4, Lifetime = 0.3 })
	end
	TuskVFX.CreateDistortion(data.To, { Radius = 3, Duration = 0.25 })
	VFXLib.sound(sounds.Emerge, data.To, 0.6, 1.3)
	if character then
		TuskStand.action(character, "Manifest", { Duration = 0.3 })
	end
	if Common.isLocal(character) then
		CameraFX.fovPunch(8, 0.3)
	end
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Move == "DimensionalStep" then
		onStep(data)
	elseif data.Move == "SpatialPursuit" and data.Phase == "Open" then
		if root then
			TuskAnimation.play(character, "NailBarrage")
		end
		local targetRoot = data.Target and data.Target:FindFirstChild("HumanoidRootPart")
		local center = targetRoot and targetRoot.Position or data.Portals[1]
		for i, pos in ipairs(data.Portals) do
			-- Each portal opens on its own beat and keeps its own rotation.
			Common.portal(pos, center, 2.2, data.OpenTime + (i - 1) * data.Stagger + 0.35, pal, (i - 1) * 0.07)
		end
	elseif data.Move == "DimensionalBreak" then
		if data.Phase == "Charge" and root then
			TuskAnimation.play(character, "Awakening")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 2, -2.5), Duration = data.Charge + 0.4 })
			local charge = TuskVFX.CreateEnergyCharge({
				Follow = function()
					return root.Parent and root.CFrame * CFrame.new(0, 1.5, -3) or nil
				end,
				Color = pal.Main,
				Color2 = pal.Light,
				MaxRadius = 1.6,
				Duration = data.Charge,
				Rings = 3,
			})
			local front = root.CFrame * CFrame.new(0, 2, -5)
			Common.portal(front.Position, front.Position + data.Direction * 10, 4.2, data.Charge + 0.4, pal, data.Charge * 0.3)
			VFXLib.sound(sounds.ChargeLoop, root, 0.5, 1.2)
			task.delay(data.Charge, function()
				charge:Release(data.Direction)
			end)
		elseif data.Phase == "Release" then
			-- A row of tearing rotational shockwaves races forward.
			local rings = 6
			for i = 1, rings do
				task.delay(i * 0.035, function()
					local p = data.Origin + data.Direction * (data.Length * i / rings)
					local axis = CFrame.lookAt(p, p + data.Direction) * CFrame.Angles(math.pi / 2, 0, 0)
					TuskVFX.CreateRotationalShockwave(axis, { Radius = data.Width * 0.7, Layers = 2, Color = pal.Main, Color2 = pal.Light, Particles = 0.6, Width = 0.5, Duration = 0.4 })
					VFXLib.groundDisc(p - Vector3.new(0, 2.8, 0), Vector3.new(0, 1, 0), { Radius = data.Width * 0.4, Color = pal.Second, Duration = 0.35 })
				end)
			end
			TuskVFX.CreateDistortion(data.Origin + data.Direction * 8, { Radius = 6 })
			VFXLib.sound(sounds.Finisher, data.Origin, 0.9, 0.8)
			CameraFX.shakeAt(data.Origin, 0.9, 70)
			if Common.isLocal(character) then
				CameraFX.speedLines(0.3, pal.Light)
				CameraFX.fovPunch(10, 0.4)
			end
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Start" then
		if root then
			TuskAnimation.play(character, "Awakening")
			VFXLib.sound(sounds.AwakeningBuild, root, 0.9, 0.9)
			TuskStand.action(character, "Manifest", { Duration = 0.8 })
		end
		local ground = data.Center - Vector3.new(0, 2.9, 0)
		TuskVFX.CreateMagicCircle(CFrame.new(ground), { Radius = data.Radius, Color = pal.Main, Color2 = pal.Light, Duration = data.Windup + 0.6, RotationSpeed = 0.8, Points = 8 })
		TuskVFX.CreateMagicCircle(CFrame.new(ground + Vector3.new(0, 0.05, 0)), { Radius = data.Radius * 0.55, Color = pal.Second, Color2 = pal.Main, Duration = data.Windup + 0.6, RotationSpeed = -1.4, Points = 5 })
		for i, pos in ipairs(data.Portals) do
			Common.portal(pos, data.Center, i <= #data.Portals / 2 and 3 or 4, data.Windup + 0.4, pal, (i - 1) * (data.Windup * 0.6 / #data.Portals))
		end
		if root then
			TuskVFX.CreateEnergyCharge({
				Follow = function()
					return root.Parent and root.CFrame * CFrame.new(0, 3, 0) or nil
				end,
				Color = pal.Main,
				Color2 = pal.Light,
				MaxRadius = 2.4,
				Duration = data.Windup,
				Rings = 3,
			})
		end
		if Common.isLocal(character) then
			CameraFX.setFovHold(10)
			task.delay(data.Windup + 0.5, function()
				CameraFX.setFovHold(0)
			end)
		end
	elseif data.Phase == "Burst" then
		local pos = data.Position
		-- Dimensional collapse: inward flash, then layered shockwaves outward.
		TuskVFX.CreateDistortion(pos, { Radius = 14, Duration = 0.6 })
		task.delay(0.08, function()
			TuskVFX.CreateRotationalShockwave(CFrame.new(pos - Vector3.new(0, 2.8, 0)), { Radius = data.Radius * 1.4, Layers = 4, Color = pal.Main, Color2 = pal.Light, Ground = true, Particles = 3, Width = 1, Duration = 0.8 })
			TuskVFX.CreateRotationalShockwave(CFrame.new(pos + Vector3.new(0, 4, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = data.Radius, Layers = 2, Color = pal.Light, Color2 = pal.Second, Particles = 0, Width = 0.6 })
		end)
		VFXLib.flash(pos, pal.Main, 14, 60, 0.8)
		VFXLib.sound(sounds.AwakeningBurst, pos, 1, 0.85)
		CameraFX.shakeAt(pos, 1.5, 110)
		if Common.isLocal(character) then
			CameraFX.speedLines(0.5, pal.Light)
			CameraFX.impactFrame(pal.Light)
		end
	end
end

function Act3.handle(name, data)
	if name == "M1" then
		Common.m1(data, pal, { Pitch = 1.1 })
	elseif name == "M1Finisher" then
		Common.finisher(data, pal, { Layers = 3 })
		Common.portal(data.Position + Vector3.new(0, -1, 0), data.Position + Vector3.new(0, 8, 0), 2.8, 0.35, pal)
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Portal" then
		Common.portal(data.Position, data.LookAt, data.Radius, data.Duration, pal)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

return Act3
```
