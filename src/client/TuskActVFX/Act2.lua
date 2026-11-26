--[[
	TuskActVFX.Act2  (StarterPlayerScripts.SpinClient.TuskActVFX.Act2)
	Client choreography for Tusk Act 2 (THE GOLDEN RATIO): golden rectangles
	and golden spirals open where Act 2 used to open portals; nails fly out
	of them with gold trails.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local TuskStand = require(script.Parent.Parent.TuskStand)
local Common = require(script.Parent.Parent.TuskActCommon)

local Act2 = {}
local pal = Common.palette(2)
local sounds = TuskConfig.Sounds

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Move == "WormholeNail" and root then
		TuskAnimation.play(character, "NailShot")
		TuskStand.action(character, "Lunge", { Target = CFrame.new(1.4, 0.8, -1.2), Duration = data.Startup + 0.25 })
		-- Whirls spin round his raised fingertips; then a small golden
		-- rectangle opens there and the nail is fired through it.
		local whirl = Common.fingerWhirl(character, data.Startup)
		task.delay(data.Startup, function()
			whirl:Release(data.Direction)
			local r = Common.rootOf(character)
			if r then
				local tip = (r.CFrame * CFrame.new(0.9, 0.55, -2.2)).Position
				Common.golden(tip, tip + data.Direction * 5, 1, 0.3, pal)
			end
		end)
	elseif data.Move == "NailDimension" and data.Phase == "Open" then
		if root then
			TuskAnimation.play(character, "NailDimension")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 2, -2), Duration = 0.6 })
		end
		for i, pos in ipairs(data.Portals) do
			Common.golden(pos, data.Center, 2.4, data.OpenTime + 0.55, pal, (i - 1) * 0.06)
		end
		TuskVFX.CreateMagicCircle(CFrame.new(data.Center - Vector3.new(0, 2.8, 0)), { Radius = 11, Color = pal.Second, Color2 = pal.Main, Duration = data.OpenTime + 0.9, RotationSpeed = 1.5, Points = 6 })
	end
end

local function onAbilityImpact(data)
	if data.Move == "NailDimension" then
		TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position - Vector3.new(0, 2.6, 0)), { Radius = data.Radius * 1.6, Layers = 3, Color = pal.Main, Color2 = pal.Second, Ground = true, Particles = 2, Width = 0.6 })
		TuskVFX.CreateDistortion(data.Position, { Radius = data.Radius * 0.7 })
		VFXLib.flash(data.Position, pal.Main, 6, 20, 0.4)
		VFXLib.sound(sounds.Finisher, data.Position, 0.8, 0.9)
		CameraFX.shakeAt(data.Position, 0.7, 70)
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Start" then
		if root then
			TuskAnimation.play(character, "Awakening")
			VFXLib.sound(sounds.AwakeningBuild, root, 0.8, 1.05)
			TuskStand.action(character, "Manifest", { Duration = 0.6 })
		end
		local center = data.Center
		TuskVFX.CreateMagicCircle(CFrame.new(center - Vector3.new(0, 2.9, 0)), { Radius = 14, Color = pal.Main, Color2 = pal.Second, Duration = data.Windup + 1.6, RotationSpeed = 1, Points = 7 })
		for i, pos in ipairs(data.Portals) do
			Common.golden(pos, center, 3, data.Windup + 1.2, pal, (i - 1) * (data.Windup * 0.5 / #data.Portals))
		end
		if Common.isLocal(character) then
			CameraFX.setFovHold(8) -- pull back to see the storm
			task.delay(data.Windup + 1.2, function()
				CameraFX.setFovHold(0)
			end)
		end
	elseif data.Phase == "Burst" then
		local pos = data.Position
		TuskVFX.CreateRotationalShockwave(CFrame.new(pos - Vector3.new(0, 2.8, 0)), { Radius = data.Radius * 1.3, Layers = 4, Color = pal.Main, Color2 = pal.Light, Ground = true, Particles = 3, Width = 0.9, Duration = 0.7 })
		TuskVFX.CreateDistortion(pos, { Radius = 10, Duration = 0.5 })
		VFXLib.burst(pos, { Count = 50, Color = pal.Light, Speed = 60, Lifetime = 0.7 })
		VFXLib.flash(pos, pal.Main, 12, 50, 0.7)
		TuskVFX.CreateGroundCracks(pos, { Radius = data.Radius, Color = pal.Main, Duration = 2 })
		TuskVFX.CreateImpactStar(pos + Vector3.new(0, 1.5, 0), { Size = 14, Rays = 12, Color = pal.Main, Color2 = pal.Light, Duration = 0.4, Width = 1.6 })
		VFXLib.sound(sounds.AwakeningBurst, pos, 1, 0.95)
		CameraFX.shakeAt(pos, 1.3, 100)
		if Common.isLocal(character) or TuskVFX.IsNear(pos, 70) then
			CameraFX.speedLines(0.45, pal.Light)
			CameraFX.impactFrame(pal.Light)
		end
	end
end

function Act2.handle(name, data)
	if name == "M1" then
		Common.m1(data, pal, { Golden = true })
	elseif name == "M1Finisher" then
		Common.finisher(data, pal)
		Common.golden(data.Position + Vector3.new(0, 1, 0), data.Position + Vector3.new(0, 1, -4), 2.6, 0.35, pal)
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "AbilityImpact" then
		onAbilityImpact(data)
	elseif name == "Portal" then
		Common.golden(data.Position, data.LookAt, data.Radius, data.Duration, pal)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

return Act2
