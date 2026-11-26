--[[
	Spin_Client  (LocalScript)
	PUT IT IN: StarterPlayer > StarterPlayerScripts

	Spin Battlegrounds client CORE: controls (PC, controller, mobile), HUD,
	character card, shared VFX, NPC bubbles, dust. Each character's visuals
	are their own script (ModuleScripts in ReplicatedStorage > SpinCharacters):
	Gyro_Client, Diego_Client, PorkPie_Client. Johnny is built in.

	Needs these ModuleScripts in ReplicatedStorage: SpinConfig, TuskConfig.
	Works with the Script Spin_Server in ServerScriptService.
]]

-- Safety check: this code must be in a LocalScript in StarterPlayerScripts.
if game:GetService("RunService"):IsServer() then
	error("[Spin] This is the Spin_CLIENT code. It must go in a LocalScript in StarterPlayer > StarterPlayerScripts. Paste Spin_Server.lua into the Script in ServerScriptService instead.")
end

-- Private copies of the built-ins we print with, so nothing loaded later can break them.
local print, warn = print, warn
local __modules = {}
local __loaded = {}
local function __hasModule(name)
	return __modules[name] ~= nil
end
local function __require(name)
	local value = __loaded[name]
	if value == nil then
		local loader = __modules[name]
		assert(loader, "[Spin] missing bundled module: " .. tostring(name))
		value = loader()
		__loaded[name] = value
	end
	return value
end

-- ======================================================================
-- MODULE: Act1
-- ======================================================================
__modules["Act1"] = function()
--[[
	TuskActVFX.Act1  (StarterPlayerScripts.SpinClient.TuskActVFX.Act1)

	Client choreography for Tusk Act 1: poses, Stand motion, effects and
	sounds for each server event. Visual only.

	Every major move follows: startup -> anticipation -> impact frame ->
	primary shockwave -> secondary particles -> recovery.
]]

local Players = game:GetService("Players")
local Fighters = __require("Fighters")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local VFXQuality = __require("VFXQuality")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local TuskStand = __require("TuskStand")
local Common = __require("TuskActCommon")

local Act1 = {}
local colors = TuskConfig.Colors
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

local function rootOf(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isLocal(character)
	return character ~= nil and character == localPlayer.Character
end

-- Swipe arc in front of the character (a quick curved ring segment).
local function swipe(root, side, color)
	local cf = root.CFrame * CFrame.new(side * 0.3, 0.3, -1.2) * CFrame.Angles(0, 0, side * 0.5)
	TuskVFX.CreateCrescent(cf, { Radius = 2.2, Width = 0.5, Color = color, Color2 = colors.Ice, Sweep = side * 1.8, Duration = 0.18 })
end

---------------------------------------------------------------------------
-- M1
---------------------------------------------------------------------------
local function onM1(data)
	local character = data.Character
	local root = rootOf(character)
	if not root then
		return
	end
	local index = data.Index
	TuskAnimation.play(character, "M1_" .. index)
	VFXLib.sound(sounds.Swing, root, 0.5, 0.95 + index * 0.06)
	if index == 1 then
		TuskStand.action(character, "Lunge", { Target = CFrame.new(0.4, 0.6, -3), Duration = 0.26 })
		swipe(root, 1, colors.Cyan)
	elseif index == 2 then
		TuskStand.action(character, "Lunge", { Target = CFrame.new(-0.6, 0.4, -3.2), Duration = 0.26 })
		swipe(root, -1, colors.Ice)
		-- Nail glint on the strike.
		VFXLib.burst((root.CFrame * CFrame.new(0, 0.4, -2.6)).Position, { Count = 6, Color = colors.Ice, Speed = 10, Lifetime = 0.2 })
	elseif index == 3 then
		TuskStand.action(character, "Lunge", { Target = CFrame.new(0.9, 1, -2.4), Duration = 0.3 })
	elseif index == 4 then
		TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 1.4, -3.4), Duration = 0.5 })
		-- Anticipation: energy gathers above the fist during the wind-up.
		local gatherAt = (root.CFrame * CFrame.new(0.8, 2.2, -0.6)).Position
		VFXLib.burst(gatherAt, { Count = 8, Color = colors.Cyan, Speed = 4, Lifetime = 0.15 })
	end
end

local function onM1Finisher(data)
	local character = data.Character
	local root = rootOf(character)
	local pos = data.Position
	local ground = pos - Vector3.new(0, 2.6, 0)
	if data.Hit and isLocal(character) then
		CameraFX.impactFrame(colors.Ice)
	end
	TuskVFX.CreateRotationalShockwave(CFrame.new(ground), { Radius = data.Radius or 7, Layers = 3, Color = colors.Cyan, Color2 = colors.Blue, Ground = true, Particles = 1.5, Width = 0.5 })
	TuskVFX.CreateImpact(pos, root and -root.CFrame.LookVector or Vector3.new(0, 1, 0), { Size = 1.2, Radius = 3, Layers = 2, Color = colors.Ice, Color2 = colors.Cyan, Ground = false })
	VFXLib.sound(sounds.Finisher, pos, 0.8, 1)
	CameraFX.shakeAt(pos, 0.6, 50)
end

---------------------------------------------------------------------------
-- Abilities
---------------------------------------------------------------------------
local function onAbility(data)
	local character = data.Character
	local root = rootOf(character)
	if not root then
		return
	end
	if data.Move == "NailShot" and data.Phase == "Startup" then
		TuskAnimation.play(character, "NailShot")
		TuskStand.action(character, "Lunge", { Target = CFrame.new(1.4, 0.8, -1.2), Duration = data.Startup + 0.25 })
		-- Anticipation: hand up, fingers up, blue whirls spinning round his
		-- fingertips; they shoot out with the nail.
		local whirl = Common.fingerWhirl(character, data.Startup)
		task.delay(data.Startup, function()
			whirl:Release(data.Direction)
		end)
	elseif data.Move == "NailBarrage" and data.Phase == "Startup" then
		TuskAnimation.play(character, "NailBarrage")
		TuskStand.action(character, "Lunge", { Target = CFrame.new(1.6, 1.2, -1), Duration = data.Startup + data.Count * data.Interval + 0.2 })
		-- Whirls spin up while his hand is raised, then burst out with each nail.
		local whirl = Common.fingerWhirl(character, data.Startup)
		task.delay(data.Startup, function()
			whirl:Release(data.Direction)
		end)
		for i = 1, (data.Count or 5) - 1 do
			task.delay(data.Startup + i * (data.Interval or 0.09) - 0.06, function()
				local puff = Common.fingerWhirl(character, 0.06)
				task.delay(0.06, function()
					puff:Release(data.Direction)
				end)
			end)
		end
	elseif data.Move == "SpinningNail" then
		if data.Phase == "Release" then
			TuskAnimation.stopHold(character, "ChargeNail")
			TuskAnimation.play(character, "SpinningNailRelease")
			if isLocal(character) then
				CameraFX.fovPunch(data.Full and 9 or 4, 0.35)
				CameraFX.shake(data.Full and 0.5 or 0.2, 0.25)
			end
		elseif data.Phase == "Cancel" then
			TuskAnimation.stopHold(character, "ChargeNail")
		end
	end
end

---------------------------------------------------------------------------
-- Hold charge visuals (driven by the replicated TuskCharge attribute)
---------------------------------------------------------------------------
local charges = {} -- [character] = { Effect, Full, Sound }

local function updateCharges()
	local seen = {}
	for _, player in ipairs(Fighters.list()) do
		local character = player.Character
		local start = character and character:GetAttribute("TuskCharge")
		if start and character:GetAttribute("TuskAct") == 1 and character:GetAttribute("TuskChargeMove") == "SpinningNail" then
			seen[character] = true
			local root = rootOf(character)
			local c = charges[character]
			if not c and root then
				TuskAnimation.hold(character, "ChargeNail")
				local effect = TuskVFX.CreateEnergyCharge({
					Follow = function()
						return root.Parent and root.CFrame * CFrame.new(0, 0.6, -1.7) or nil
					end,
					Color = colors.Cyan,
					Color2 = colors.Ice,
					MaxRadius = 1.1,
					Rings = 3,
					Manual = true,
				})
				c = { Effect = effect, Full = false, Sound = VFXLib.sound(sounds.ChargeLoop, root, 0.4, 0.8, true) }
				charges[character] = c
			end
			if c then
				local p = math.clamp((workspace:GetServerTimeNow() - start) / TuskConfig.Act1.SpinningNail.FullChargeAt, 0, 1)
				c.Effect:SetProgress(p)
				if c.Sound then
					c.Sound.PlaybackSpeed = 0.8 + p * 0.6
				end
				if p >= 1 and not c.Full then
					-- Full charge: rings turn golden-blue, flash, chime.
					c.Full = true
					for i, ring in ipairs(c.Effect.Rings) do
						ring:SetColor(i == 1 and colors.Gold or colors.Cyan)
					end
					local pos = root.CFrame * CFrame.new(0, 0.6, -1.7)
					VFXLib.burst(pos.Position, { Count = 16, Color = colors.Gold, Speed = 12, Lifetime = 0.3 })
					VFXLib.flash(pos.Position, colors.Gold, 5, 12, 0.25)
					VFXLib.sound(sounds.ChargeFull, root, 0.7, 1)
				end
			end
		end
	end
	for character, c in pairs(charges) do
		if not seen[character] then
			charges[character] = nil
			if c.Full or (c.Effect.Progress or 0) > 0.05 then
				local dir = rootOf(character) and rootOf(character).CFrame.LookVector
				c.Effect:Release(dir)
			else
				c.Effect:Destroy()
			end
			if c.Sound then
				c.Sound:Destroy()
			end
			TuskAnimation.stopHold(character, "ChargeNail")
		end
	end
end

---------------------------------------------------------------------------
-- Awakened aura (driven by the TuskAwakened attribute)
---------------------------------------------------------------------------
local auras = {}

local function updateAuras()
	local seen = {}
	for _, player in ipairs(Fighters.list()) do
		local character = player.Character
		if character and character:GetAttribute("TuskAwakened") and character:GetAttribute("TuskAct") == 1 then
			seen[character] = true
			if not auras[character] then
				auras[character] = TuskVFX.CreateGoldenAura(character, { Color = colors.Cyan, Color2 = colors.Blue, Rings = 2 })
			end
		end
	end
	for character, aura in pairs(auras) do
		if not seen[character] then
			auras[character] = nil
			aura:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- Ultimate: TUSK AWAKENING
---------------------------------------------------------------------------
-- TUSK AWAKENING
--   1. the world darkens and drains of colour around Johnny
--   2. three magic circles stack up: feet, waist and above the head
--   3. cyan nails wrapped in Spin whirls orbit him in a widening,
--      accelerating helix while Tusk manifests behind him
--   4. at the burst the nails fly outward, a cyan pillar erupts, the ground
--      cracks and a starburst + impact frame hits everyone nearby
local orbitNails = setmetatable({}, { __mode = "k" }) -- character -> nail visuals

local function launchNails(character, root)
	local nails = orbitNails[character]
	orbitNails[character] = nil
	if not nails then
		return
	end
	for _, n in ipairs(nails) do
		local from = n.Last
		if from then
			local dir = Vector3.new(from.Position.X - root.Position.X, 0.15, from.Position.Z - root.Position.Z)
			dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, 0, -1)
			local startPos = from.Position
			local travel = 26 + math.random() * 10
			VFXLib.animate(0.32, function(a, dt)
				local pos = startPos + dir * travel * VFXLib.easeOut(a)
				n.Visual:Step(CFrame.lookAt(pos, pos + dir), dt)
			end, function()
				local tip = startPos + dir * travel
				n.Visual:Destroy()
				TuskVFX.CreateImpactStar(tip, { Size = 2.4, Color = colors.Cyan, Color2 = colors.Ice, Rays = 5 })
				VFXLib.burst(tip, { Count = 5, Color = colors.Ice, Speed = 14, Lifetime = 0.3 })
			end)
		else
			n.Visual:Destroy()
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = rootOf(character)
	if not root then
		return
	end
	local w = data.Windup or 1.7
	if data.Phase == "Start" then
		local near = isLocal(character) or TuskVFX.IsNear(root.Position, 120)
		TuskAnimation.play(character, "Awakening")
		VFXLib.sound(sounds.AwakeningBuild, root, 0.8, 1)
		-- 1. darken
		if near then
			TuskVFX.ScreenTint(w, { Brightness = -0.18, Saturation = -0.45, Contrast = 0.2, Tint = Color3.fromRGB(200, 235, 255), Release = 0.15 })
		end
		-- 2. stacked circles (the feet circle comes from the transformation)
		TuskVFX.CreateTuskTransformation(character, {
			Duration = w,
			Color = colors.Cyan,
			Color2 = colors.Blue,
			OnManifest = function()
				TuskStand.action(character, "Manifest", { Duration = 0.7 })
				VFXLib.flash(root.Position + Vector3.new(0, 2, 2), colors.Cyan, 6, 22, 0.35)
			end,
		})
		local feet = root.Position - Vector3.new(0, 2.9, 0)
		TuskVFX.CreateMagicCircle(CFrame.new(feet + Vector3.new(0, 3, 0)), { Radius = 3.6, Color = colors.Ice, Color2 = colors.Cyan, Duration = w + 0.3, RotationSpeed = -2.6, Points = 4 })
		TuskVFX.CreateMagicCircle(CFrame.new(feet + Vector3.new(0, 7.2, 0)), { Radius = 5.2, Color = colors.Blue, Color2 = colors.Ice, Duration = w + 0.3, RotationSpeed = 1.8, Points = 5 })
		-- 3. orbiting nails
		local count = VFXQuality.get().RingSegments > 12 and 8 or 4
		local nails = {}
		for i = 1, count do
			nails[i] = {
				Visual = TuskVFX.CreateNailProjectile({ Scale = 0.85, Glow = true, Whirls = 1, Color = colors.Blue, Color2 = colors.Cyan, SpinSpeed = 40 }),
				Phase = (i - 1) / count * math.pi * 2,
				Height = (i % 2 == 0) and 0.4 or 1.8,
			}
		end
		orbitNails[character] = nails
		local angle = 0
		VFXLib.animate(w, function(a, dt)
			if not root.Parent or orbitNails[character] ~= nails then
				return -- character gone, or the burst already launched these nails
			end
			local speed = 3 + a * a * 14 -- accelerates into the burst
			angle = angle + speed * (dt or 0)
			local radius = 2.4 + a * 2.6
			local center = root.Position
			for _, n in ipairs(nails) do
				local th = angle + n.Phase
				local y = n.Height + math.sin(th * 2) * 0.6 + a * 1.2
				local pos = center + Vector3.new(math.cos(th) * radius, y, math.sin(th) * radius)
				-- Point along the orbit, tilted slightly inward.
				local tangent = Vector3.new(-math.sin(th), 0.15, math.cos(th))
				local cf = CFrame.lookAt(pos, pos + tangent - (pos - center).Unit * 0.25)
				n.Last = cf
				n.Visual:Step(cf, dt)
			end
		end, function()
			launchNails(character, root)
		end)
		-- Building pulses as the orbit speeds up.
		for stage = 1, 3 do
			task.delay(w * stage / 3.6, function()
				if root.Parent then
					VFXLib.flash(root.Position, colors.Cyan, 3 + stage * 2, 16 + stage * 6, 0.25)
					VFXLib.burst(root.Position, { Count = 10 * stage, Color = colors.Ice, Speed = 14 + stage * 6, Lifetime = 0.4 })
					if isLocal(character) then
						CameraFX.shake(0.15 * stage, 0.25)
					end
				end
			end)
		end
		if isLocal(character) then
			-- Camera transition: slow push-in during the buildup.
			CameraFX.setFovHold(-14)
			task.delay(w, function()
				CameraFX.setFovHold(0)
				CameraFX.fovPunch(18, 0.6)
			end)
		end
	elseif data.Phase == "Burst" then
		local pos = data.Position
		local radius = data.Radius or 14
		launchNails(character, root) -- in case the burst beats the windup timer
		VFXLib.sound(sounds.AwakeningBurst, pos, 1, 1)
		TuskVFX.CreateEnergyPillar(pos - Vector3.new(0, 3, 0), { Radius = 7, Height = 70, Color = colors.Ice, Color2 = colors.Cyan, Duration = 0.7 })
		TuskVFX.CreateGroundCracks(pos, { Radius = radius, Color = colors.Cyan, Duration = 2 })
		TuskVFX.CreateImpactStar(pos + Vector3.new(0, 1.5, 0), { Size = 14, Rays = 12, Color = colors.Cyan, Color2 = colors.Ice, Duration = 0.4, Width = 1.6 })
		TuskVFX.CreateRotationalShockwave(CFrame.new(pos + Vector3.new(0, 3, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = radius * 0.8, Layers = 2, Color = colors.Ice, Color2 = colors.Blue, Particles = 0, Width = 0.5 })
		CameraFX.shakeAt(pos, 1.3, 100)
		if isLocal(character) or TuskVFX.IsNear(pos, 70) then
			CameraFX.speedLines(0.5, colors.Ice)
			CameraFX.impactFrame(colors.Ice)
		end
	end
end

function Act1.handle(name, data)
	if name == "M1" then
		onM1(data)
	elseif name == "M1Finisher" then
		onM1Finisher(data)
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

function Act1.step()
	updateCharges()
	updateAuras()
end

return Act1
end

-- ======================================================================
-- MODULE: Act2
-- ======================================================================
__modules["Act2"] = function()
--[[
	TuskActVFX.Act2  (StarterPlayerScripts.SpinClient.TuskActVFX.Act2)
	Client choreography for Tusk Act 2 (THE GOLDEN RATIO): golden rectangles
	and golden spirals open where Act 2 used to open portals; nails fly out
	of them with gold trails.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local TuskStand = __require("TuskStand")
local Common = __require("TuskActCommon")

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
end

-- ======================================================================
-- MODULE: Act3
-- ======================================================================
__modules["Act3"] = function()
--[[
	TuskActVFX.Act3  (StarterPlayerScripts.SpinClient.TuskActVFX.Act3)
	Client choreography for Tusk Act 3 (spatial movement): deep-blue
	layered portals, blue distortion afterimages, a tearing dimensional break.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local TuskStand = __require("TuskStand")
local Common = __require("TuskActCommon")

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
		TuskAnimation.play(character, "DimensionalStep")
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
			TuskAnimation.play(character, "SpatialPursuit")
		end
		local targetRoot = data.Target and data.Target:FindFirstChild("HumanoidRootPart")
		local center = targetRoot and targetRoot.Position or data.Portals[1]
		for i, pos in ipairs(data.Portals) do
			-- Each portal opens on its own beat and keeps its own rotation.
			Common.portal(pos, center, 2.2, data.OpenTime + (i - 1) * data.Stagger + 0.35, pal, (i - 1) * 0.07)
		end
	elseif data.Move == "DimensionalBreak" then
		if data.Phase == "Charge" and root then
			TuskAnimation.play(character, "DimensionalBreak")
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
			local charge = TuskVFX.CreateEnergyCharge({
				Follow = function()
					return root.Parent and root.CFrame * CFrame.new(0, 3, 0) or nil
				end,
				Color = pal.Main,
				Color2 = pal.Light,
				MaxRadius = 2.4,
				Duration = data.Windup,
				Rings = 3,
			})
			task.delay(data.Windup, function()
				charge:Release()
			end)
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
		TuskVFX.CreateGroundCracks(pos, { Radius = data.Radius, Color = pal.Main, Duration = 2.2 })
		TuskVFX.CreateEnergyPillar(pos - Vector3.new(0, 3, 0), { Radius = 8, Height = 80, Color = pal.Light, Color2 = pal.Second, Duration = 0.8 })
		TuskVFX.CreateImpactStar(pos + Vector3.new(0, 1.5, 0), { Size = 16, Rays = 12, Color = pal.Main, Color2 = pal.Light, Duration = 0.45, Width = 1.8 })
		VFXLib.sound(sounds.AwakeningBurst, pos, 1, 0.85)
		CameraFX.shakeAt(pos, 1.5, 110)
		if Common.isLocal(character) or TuskVFX.IsNear(pos, 70) then
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
end

-- ======================================================================
-- MODULE: Act4
-- ======================================================================
__modules["Act4"] = function()
--[[
	TuskActVFX.Act4  (StarterPlayerScripts.SpinClient.TuskActVFX.Act4)
	Client choreography for Tusk Act 4 (Infinite Rotation): gold and deep
	blue, giant rotational rings, golden afterimages, distorted air, and the
	10-step INFINITE ROTATION cinematic.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Fighters = __require("Fighters")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local TuskStand = __require("TuskStand")
local Common = __require("TuskActCommon")

local Act4 = {}
local pal = Common.palette(4)
local colors = TuskConfig.Colors
local sounds = TuskConfig.Sounds
local cfg = TuskConfig.Act4

local function golden(root, cframeOffset, duration, maxRadius)
	return TuskVFX.CreateEnergyCharge({
		Follow = function()
			return root.Parent and root.CFrame * cframeOffset or nil
		end,
		Color = pal.Main,
		Color2 = pal.Light,
		MaxRadius = maxRadius or 1,
		Duration = duration,
		Rings = 3,
	})
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Move == "GoldenSpinNail" and root then
		-- A small golden sphere forms, three rings spin up, particles spiral in, release flash.
		TuskAnimation.play(character, "GoldenSpinNail")
		TuskStand.action(character, "Lunge", { Target = CFrame.new(1.6, 1.2, -1.6), Duration = data.Startup + 0.3 })
		local charge = golden(root, CFrame.new(0.9, 0.6, -2), data.Startup, 1)
		-- Gold-tinged whirls round his raised fingertips.
		local whirl = Common.fingerWhirl(character, data.Startup, { Color = Color3.fromRGB(255, 214, 110), Light = Color3.fromRGB(150, 210, 255) })
		VFXLib.sound(sounds.ChargeFull, root, 0.5, 0.8)
		task.delay(data.Startup, function()
			charge:Release(data.Direction)
			whirl:Release(data.Direction)
		end)
	elseif data.Move == "InfiniteRotation" then
		if data.Phase == "Release" then
			TuskAnimation.stopHold(character, "ChargeNail")
			TuskAnimation.play(character, "SpinningNailRelease")
			if Common.isLocal(character) then
				CameraFX.fovPunch(6 + data.Stage * 4, 0.45)
				CameraFX.shake(0.3 * data.Stage, 0.3)
				if data.Stage == 3 then
					CameraFX.speedLines(0.35, pal.Light)
				end
			end
		elseif data.Phase == "Cancel" then
			TuskAnimation.stopHold(character, "ChargeNail")
		end
	elseif data.Move == "GoldenPursuit" then
		if data.Phase == "Gather" and root then
			TuskAnimation.play(character, "GoldenPursuit")
			VFXLib.burst(root.Position, { Count = 20, Color = pal.Main, Speed = 8, Lifetime = 0.25 })
			TuskVFX.CreateSpinRing({ CFrame = CFrame.new(root.Position - Vector3.new(0, 2.6, 0)), Radius = 4, Width = 0.3, Color = pal.Main, RotationSpeed = 9, Duration = 0.35 })
		elseif data.Phase == "Dash" then
			-- Golden streak + afterimages along the rush.
			local length = (data.To - data.From).Magnitude
			if length > 1 then
				local streak = VFXLib.part({ Size = Vector3.new(0.6, 0.6, length), CFrame = CFrame.lookAt((data.From + data.To) / 2, data.To), Color = pal.Main, Transparency = 0.2 })
				VFXLib.animate(0.3, function(a)
					streak.Transparency = 0.2 + 0.8 * a
					streak.Size = Vector3.new(0.6 * (1 - a), 0.6 * (1 - a), length)
				end, function()
					streak:Destroy()
				end)
			end
			for i = 1, 4 do
				VFXLib.afterimage(CFrame.new(data.From:Lerp(data.To, i / 5)), 2.4, i % 2 == 0 and pal.Main or pal.Second)
			end
			if character then
				TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 1.5, -3.5), Duration = 0.6 })
			end
			if Common.isLocal(character) then
				CameraFX.speedLines(0.3, pal.Light)
			end
		elseif data.Phase == "Hit" then
			local axis = CFrame.new(data.Position) * CFrame.Angles(data.Index * 0.6, data.Index, 0)
			TuskVFX.CreateRotationalShockwave(axis, { Radius = 4, Layers = 2, Color = pal.Main, Color2 = pal.Light, Particles = 0.6, Width = 0.35, Duration = 0.25 })
			VFXLib.sound(sounds.Hit, data.Position, 0.5, 1 + data.Index * 0.1)
		elseif data.Phase == "Final" then
			Common.finisher({ Character = character, Position = data.Position, Radius = data.Radius, Hit = true }, pal, { Layers = 4, Size = 1.8, Width = 0.8, Shake = 1, Pitch = 0.85 })
			TuskVFX.CreateDistortion(data.Position, { Radius = 6 })
		end
	end
end

-- Hold charge for INFINITE ROTATION (stages 1 / 2 / 3).
local function stageOf(seconds)
	local stage = 0
	for i, t in ipairs(cfg.InfiniteRotation.Stages) do
		if seconds >= t then
			stage = i
		end
	end
	return stage
end

local chargeStep = Common.chargeDriver(4, "InfiniteRotation", function(character, root)
	TuskAnimation.hold(character, "ChargeNail")
	local effect = TuskVFX.CreateEnergyCharge({
		Follow = function()
			return root.Parent and root.CFrame * CFrame.new(0, 1.2, -2.6) or nil
		end,
		Color = pal.Main,
		Color2 = pal.Light,
		MaxRadius = 2.4,
		Rings = 3,
		Manual = true,
	})
	effect.Stage = 0
	effect.Root = root
	effect.Sound = VFXLib.sound(sounds.ChargeLoop, root, 0.5, 0.7, true)
	return effect
end, function(effect, seconds)
	local stages = cfg.InfiniteRotation.Stages
	effect:SetProgress(math.clamp(seconds / stages[#stages], 0, 1))
	if effect.Sound then
		effect.Sound.PlaybackSpeed = 0.7 + math.min(seconds, 2) * 0.35
	end
	local stage = stageOf(seconds)
	if stage > effect.Stage then
		effect.Stage = stage
		local pos = effect.Root.Position
		-- Stage 1: small golden rings · 2: more rotating circles · 3: golden-blue + distortion
		for i, ring in ipairs(effect.Rings) do
			ring:SetColor((stage >= 3 and i % 2 == 0) and colors.Cyan or pal.Main)
			ring:SetWidth(0.08 + stage * 0.05)
		end
		TuskVFX.CreateSpinRing({ CFrame = CFrame.new(pos - Vector3.new(0, 2.7, 0)), Radius = 3 + stage * 2, Width = 0.25, Color = stage >= 3 and colors.Cyan or pal.Main, RotationSpeed = 4 * stage, Duration = 0.6 })
		VFXLib.burst(pos, { Count = 12 * stage, Color = pal.Light, Speed = 14 + stage * 6, Lifetime = 0.35 })
		VFXLib.flash(pos, pal.Main, 3 + stage * 2, 14, 0.25)
		VFXLib.sound(sounds.ChargeFull, effect.Root, 0.5 + stage * 0.15, 0.8 + stage * 0.15)
		if stage >= 3 then
			TuskVFX.CreateDistortion(pos + Vector3.new(0, 1, -2.6), { Radius = 3.5, Duration = 0.4 })
		end
	end
end, function(effect, character)
	if effect.Sound then
		effect.Sound:Destroy()
	end
	local root = Common.rootOf(character)
	effect:Release(root and root.CFrame.LookVector)
	TuskAnimation.stopHold(character, "ChargeNail")
end)

---------------------------------------------------------------------------
-- Ultimate: INFINITE ROTATION (cinematic)
---------------------------------------------------------------------------
local function darken(duration, release)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "TuskInfiniteDarken"
	cc.Parent = Lighting
	VFXLib.animate(duration, function(a)
		cc.Brightness = -0.22 * math.min(a * 3, 1)
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 225, 170), math.min(a * 2, 1))
		cc.Saturation = 0.15 * a
	end)
	task.delay(duration + (release or 0.3), function()
		VFXLib.animate(0.5, function(a)
			cc.Brightness = -0.22 * (1 - a)
			cc.Saturation = 0.15 * (1 - a)
		end, function()
			cc:Destroy()
		end)
	end)
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local w = data.Windup
	if data.Phase == "Start" then
		local isLocal = Common.isLocal(character)
		local camera = workspace.CurrentCamera
		local near = camera and (camera.CFrame.Position - root.Position).Magnitude < 140
		-- 1. camera moves toward Johnny
		if isLocal then
			CameraFX.setFovHold(-16)
		end
		-- 2. the environment darkens (everyone nearby)
		if near then
			darken(w, 0.4)
		end
		-- 3. Tusk manifests behind Johnny
		TuskAnimation.play(character, "Awakening")
		TuskStand.action(character, "Manifest", { Duration = 0.8 })
		VFXLib.sound(sounds.AwakeningBuild, root, 1, 0.8)
		-- 4. golden energy rotates around the player
		local aura = TuskVFX.CreateGoldenAura(character, { Color = pal.Main, Color2 = pal.Second, Rings = 3, Particles = 2 })
		-- 5. several massive golden rings
		local rings = {}
		for i = 1, 3 do
			rings[i] = TuskVFX.CreateSpinRing({
				Follow = function()
					return root.Parent and CFrame.new(root.Position + Vector3.new(0, i * 1.6 - 1, 0)) or nil
				end,
				Tilt = CFrame.Angles(0.35 * (i - 2), 0, 0.2 * (i - 2)),
				Radius = 5 + i * 3,
				Width = 0.45,
				Color = i == 2 and colors.Cyan or pal.Main,
				RotationSpeed = (i % 2 == 0 and -1 or 1) * (1.5 + i),
				Duration = w + 0.4,
			})
		end
		TuskVFX.CreateMagicCircle(CFrame.new(root.Position - Vector3.new(0, 2.9, 0)), { Radius = 16, Color = pal.Main, Color2 = colors.Cyan, Duration = w + 0.5, RotationSpeed = 1.2, Points = 8 })
		-- 6. energy builds in stages
		for stage = 1, 3 do
			task.delay(w * stage / 3.5, function()
				for _, ring in ipairs(rings) do
					ring.Speed = ring.Speed * 1.6
				end
				VFXLib.burst(root.Position, { Count = 20 * stage, Color = pal.Light, Speed = 20 + stage * 10, Lifetime = 0.5 })
				VFXLib.flash(root.Position, pal.Main, 4 + stage * 3, 20 + stage * 10, 0.3)
				TuskVFX.CreateDistortion(root.Position + Vector3.new(0, 2, 0), { Radius = 3 + stage * 2, Duration = 0.35 })
				if isLocal then
					CameraFX.shake(0.25 * stage, 0.3)
				end
			end)
		end
		-- 7. Tusk's signature: the giant rotational energy forms in front
		local charge = golden(root, CFrame.new(0, 2, -4), w, 3.5)
		task.delay(w, function()
			charge:Release(data.Direction)
			aura:Destroy()
		end)
	elseif data.Phase == "Release" then
		-- 8. the giant golden rotational projectile is released (drawn by TuskProjectiles)
		TuskAnimation.play(character, "SpinningNailRelease")
		VFXLib.flash(data.Position, pal.Light, 14, 60, 0.5)
		if Common.isLocal(character) then
			-- 10. camera returns to normal (with a punch)
			CameraFX.setFovHold(0)
			CameraFX.fovPunch(20, 0.7)
			CameraFX.speedLines(0.6, pal.Light)
		end
	end
end

-- Act 4's Stand carries two slow golden rings at all times.
local standRings = {}
local function updateStandRings()
	local seen = {}
	for _, player in ipairs(Fighters.list()) do
		local character = player.Character
		local stand = character and character:GetAttribute("TuskAct") == 4 and TuskStand.get(character)
		if stand and stand.Visible then
			seen[character] = true
			if not standRings[character] then
				local body = stand.Rig.Body
				standRings[character] = {
					TuskVFX.CreateSpinRing({ Follow = function() return body.Parent and body.CFrame or nil end, Tilt = CFrame.Angles(0.4, 0, 0.2), Radius = 3.2, Width = 0.1, Color = pal.Main, RotationSpeed = 1.6, Transparency = 0.3 }),
					TuskVFX.CreateSpinRing({ Follow = function() return body.Parent and body.CFrame or nil end, Tilt = CFrame.Angles(-0.5, 0, -0.3), Radius = 2.6, Width = 0.08, Color = colors.Cyan, RotationSpeed = -2.2, Transparency = 0.35 }),
				}
			end
		end
	end
	for character, rings in pairs(standRings) do
		if not seen[character] then
			standRings[character] = nil
			for _, ring in ipairs(rings) do
				ring:Destroy()
			end
		end
	end
end

function Act4.handle(name, data)
	if name == "M1" then
		Common.m1(data, pal, { Scale = 1.3, Pitch = 0.85 })
	elseif name == "M1Finisher" then
		Common.finisher(data, pal, { Layers = 4, Size = 1.6, Width = 0.8, Shake = 0.9, Pitch = 0.8 })
		TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = data.Radius * 0.7, Layers = 2, Color = pal.Light, Color2 = pal.Main, Particles = 0, Width = 0.5 })
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

function Act4.step()
	chargeStep()
	updateStandRings()
end

return Act4
end

-- ======================================================================
-- MODULE: Blockify
-- ======================================================================
__modules["Blockify"] = function()
--[[
	Blockify  (ReplicatedStorage.SpinShared.Blockify)

	Turns a part-built model into a blocky (classic Roblox) look while
	keeping each model recognisable:
	  * small round pieces (eyes, studs, tips) become single boxes
	  * BIG round pieces (Tusk's egg body, heads, shoulder balls) become a
	    "voxel-round" shape: a core box plus three crossing boxes, so the
	    outline is a stepped, pixel-art circle instead of a plain cube
	  * flat discs (Act 2's rings) stay circular the same stepped way
	  * long cylinders become square rods
	Part centres don't move. The extra boxes are welded to the original part,
	so welds, rigs, fades and animations keep working. Models whose parts are
	moved one by one (the raptor) pass { Voxel = false } for single boxes.
	Used by the Tusk Stands and the Scary Monsters raptor when
	TuskConfig.BlockyModels is true. A part with the attribute KeepRound
	is left alone.
]]

local Blockify = {}

local ROUND = 0.82 -- single box vs. sphere diameter (similar silhouette)
local ROD = 0.88 -- square rod vs. cylinder diameter
local BIG = 0.7 -- studs: round pieces at least this big get the voxel-round shape
local CORE, ARM = 0.86, 0.62 -- voxel-round: core box and the thin side of the crossing boxes

-- A box welded on top of `part`, copying its look.
local function extraBox(part, size)
	local p = Instance.new("Part")
	p.Name = part.Name .. "Block"
	p.Size = size
	p.Color = part.Color
	p.Material = part.Material
	p.Reflectance = part.Reflectance
	p.Transparency = part.Transparency
	p.CastShadow = part.CastShadow
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = part.CFrame
	local weld = Instance.new("Weld")
	weld.Part0 = part
	weld.Part1 = p
	weld.C0 = CFrame.new()
	weld.Parent = p
	p.Parent = part.Parent
	return p
end

-- Stepped round shape for a piece of size s (core + crossing boxes on the axes in `axes`).
local function voxelRound(part, s, axes)
	part.Size = s * CORE
	for _, axis in ipairs(axes) do
		local x = axis == "X" and s.X or s.X * ARM
		local y = axis == "Y" and s.Y or s.Y * ARM
		local z = axis == "Z" and s.Z or s.Z * ARM
		extraBox(part, Vector3.new(x, y, z))
	end
end

local function convert(part, opts)
	if part:GetAttribute("KeepRound") or (opts.KeepRound and opts.KeepRound[part.Name]) then
		return
	end
	local canAdd = opts.Voxel ~= false and part.Parent ~= nil
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.Sphere then
		mesh:Destroy()
		local s = part.Size
		if canAdd and math.max(s.X, s.Y, s.Z) >= BIG then
			voxelRound(part, s, { "X", "Y", "Z" })
		else
			part.Size = s * ROUND
		end
		return
	end
	if part:IsA("Part") then
		if part.Shape == Enum.PartType.Ball then
			part.Shape = Enum.PartType.Block
			local s = part.Size
			if canAdd and s.X >= BIG then
				voxelRound(part, s, { "X", "Y", "Z" })
			else
				part.Size = s * ROUND
			end
		elseif part.Shape == Enum.PartType.Cylinder then
			-- Cylinder length runs along X; its round face is in Y/Z.
			part.Shape = Enum.PartType.Block
			local s = part.Size
			local diameter = math.min(s.Y, s.Z)
			if canAdd and diameter >= BIG and s.X < diameter * 0.6 then
				-- A disc / wheel / ring: keep it round (stepped) in its face.
				part.Size = Vector3.new(s.X, s.Y * CORE, s.Z * CORE)
				extraBox(part, Vector3.new(s.X, s.Y, s.Z * ARM))
				extraBox(part, Vector3.new(s.X, s.Y * ARM, s.Z))
			else
				part.Size = Vector3.new(s.X, s.Y * ROD, s.Z * ROD)
			end
		end
	end
end

-- opts.Voxel = false: single boxes only (for models whose parts are moved one
-- by one, like the raptor rig).
-- opts.KeepRound = { [partName] = true }: signature round pieces left smooth.
function Blockify.apply(model, opts)
	opts = opts or {}
	local parts = {}
	if model:IsA("BasePart") then
		table.insert(parts, model)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	-- (collected first so the boxes added along the way aren't converted again)
	for _, p in ipairs(parts) do
		convert(p, opts)
	end
	return model
end

-- True when the game wants blocky models (TuskConfig.BlockyModels, default on).
function Blockify.enabled(config)
	return not (config and config.BlockyModels == false)
end

return Blockify
end

-- ======================================================================
-- MODULE: BountyUI
-- ======================================================================
__modules["BountyUI"] = function()
--[[
	BountyUI  (StarterPlayerScripts.SpinClient.UI.BountyUI)

	The bounty board screen (owner's design):
	  * a framed wooden board (grain, nails, metal corner brackets, a hanging
	    title sign) that drops in from the top; a header strip with your Cash,
	    ALL / PLAYERS / NPCS / CORPSE tabs and your current bounty
	  * CORPSE: "RETRIEVE" contracts, one per Saint's Corpse part: paid when you
	    take that part; the photo is the relic (or the face of whoever holds it)
	  * aged parchment WANTED posters with a red pin: face (avatar headshot,
	    or the NPC's face), name, Stand, "DEAD OR ALIVE", danger pips, a red
	    reward ribbon and a kill-streak badge
	  * HOVER a poster: it straightens, lifts, grows, glows gold, "CLICK TO HUNT"
	  * CLICK it: a BOUNTY CONTRACT card with ACCEPT / DECLINE; accepting
	    thumps an ACCEPTED stamp on it
	  * ACCEPT: the board closes and a bounty tracker appears on the left
	    (target, reward, distance, time left, abandon button), plus a red
	    TARGET marker over their head that only you can see
	  * claiming it: a big "BOUNTY CLAIMED! +$350" banner
	  * POST tab: post your own bounty. Pick who it's on (yourself, any
	    player, any Stand-user NPC or any Saint's Corpse part), type how
	    much (or tap +$25 / +$100 / +$500 / MAX) and POST it. The whole
	    server sees a banner
	Remote: Net "Bounty" (server: BountyService).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local Net = __require("Net")
local Registry = __require("TuskActRegistry")
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Cinematic = __require("Cinematic")
local okHorse, HorseModel = pcall(function()
	return __require("HorseModel")
end)
if not okHorse then
	HorseModel = nil
end

local BountyUI = {}
local player = Players.LocalPlayer
local Remote

local WOOD = Color3.fromRGB(112, 74, 44)
local WOOD_DARK = Color3.fromRGB(78, 50, 30)
local WOOD_LIGHT = Color3.fromRGB(134, 90, 56)
local PAPER = Color3.fromRGB(234, 205, 160)
local PAPER_DARK = Color3.fromRGB(205, 172, 125)
local INK = Color3.fromRGB(60, 36, 20)
local RED = Color3.fromRGB(190, 40, 35)
local GREEN = Color3.fromRGB(60, 150, 70)
local GOLD = Color3.fromRGB(255, 205, 90)

local gui, dim, board, grid, confirm, confirmLayer, tracker, banner, marker
local current -- the active bounty
local confirmEntry -- the poster the Accept/Decline card is asking about
local confirmPay, confirmPips -- the reward label and danger pips on the card
local FAST = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SOFT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function corner(p, r)
	new("UICorner", { CornerRadius = UDim.new(0, r) }, p)
end

local function label(parent, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, TextColor3 = INK, Font = Enum.Font.GothamBlack, TextScaled = true }, parent)
	for k, v in pairs(props) do
		l[k] = v
	end
	return l
end

-- A live "photo" of a model's face: the character copied into a ViewportFrame.
local function faceViewport(model, parent)
	local head = model and model:FindFirstChild("Head")
	if not head then
		return false
	end
	local ok, copy = pcall(function()
		local was = model.Archivable
		model.Archivable = true
		local c = model:Clone()
		model.Archivable = was
		return c
	end)
	if not ok or not copy then
		return false
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	local view = new("ViewportFrame", { Name = "Face", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(190, 175, 160), LightColor = Color3.fromRGB(255, 240, 220), LightDirection = Vector3.new(-0.4, -0.6, -1) }, parent)
	local world = new("WorldModel", {}, view)
	copy.Parent = world
	local camera = new("Camera", { FieldOfView = 34 }, view)
	local copyHead = copy:FindFirstChild("Head") or head
	local look = copyHead.CFrame
	camera.CFrame = CFrame.lookAt((look * CFrame.new(0, 0.25, -3.2)).Position, look.Position + Vector3.new(0, 0.1, 0))
	view.CurrentCamera = camera
	return true
end

-- The Saint's Corpse part lying in the world, or the character carrying it.
local function corpseRelic(partId)
	for _, m in ipairs(game:GetService("CollectionService"):GetTagged("SpinCorpse")) do
		if m.Parent and m:GetAttribute("PartId") == partId then
			return m
		end
	end
	return nil
end

local function corpseHolder(partId)
	local function holds(model)
		local parts = model and model:GetAttribute("CorpseParts")
		return parts and string.find("," .. parts .. ",", "," .. partId .. ",", 1, true)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if holds(p.Character) then
			return p.Character
		end
	end
	-- Stand-user NPCs pick parts up too.
	for _, m in ipairs(game:GetService("CollectionService"):GetTagged("SpinFighter")) do
		if m.Parent and holds(m) then
			return m
		end
	end
	return nil
end

-- A small photo of a relic (its parts copied into a viewport).
local function relicViewport(relic, parent)
	local view = new("ViewportFrame", { Name = "Face", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(200, 180, 150), LightColor = Color3.fromRGB(255, 230, 180), LightDirection = Vector3.new(-0.4, -0.6, -1) }, parent)
	local model = new("Model", {}, view)
	for _, p in ipairs(relic:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "Beam" and p.Name ~= "Holder" then
			local c = p:Clone()
			for _, d in ipairs(c:GetChildren()) do
				d:Destroy()
			end
			c.Parent = model
		end
	end
	local center = relic.PrimaryPart and relic.PrimaryPart.Position or relic:GetPivot().Position
	local camera = new("Camera", { FieldOfView = 40 }, view)
	camera.CFrame = CFrame.lookAt(center + Vector3.new(2.2, 1.2, -5.5), center)
	view.CurrentCamera = camera
end

local function photoFor(entry, parent)
	local photo = new("ImageLabel", { Name = "Photo", BackgroundColor3 = PAPER_DARK, BorderSizePixel = 0, ImageColor3 = Color3.fromRGB(240, 220, 190), ClipsDescendants = true }, parent)
	if entry.Kind == "Corpse" then
		-- The relic on a gold backdrop, or the face of whoever carries it.
		photo.BackgroundColor3 = Color3.fromRGB(214, 178, 96)
		local relic = corpseRelic(entry.Part)
		local holder = not relic and corpseHolder(entry.Part)
		if relic then
			relicViewport(relic, photo)
		elseif not (holder and faceViewport(holder, photo)) then
			label(photo, { Size = UDim2.fromScale(1, 1), Text = "✝", Font = Enum.Font.GothamBlack, TextColor3 = INK, TextTransparency = 0.3 })
		end
		if holder then
			local tag = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(0.8, 0, 0, 14), BackgroundColor3 = RED }, photo)
			corner(tag, 3)
			label(tag, { Size = UDim2.fromScale(1, 1), Text = "HELD", Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), TextScaled = true })
		end
		return photo
	end
	if entry.Kind == "Player" and entry.UserId then
		photo.Image = "rbxthumb://type=AvatarHeadShot&id=" .. entry.UserId .. "&w=150&h=150"
	else
		-- NPC: their actual face (copied into a viewport), on their Stand's colour.
		local info = entry.Act and Registry.get(entry.Act)
		photo.BackgroundColor3 = info and info.Theme.Primary:Lerp(PAPER_DARK, 0.55) or PAPER_DARK
		-- The NPC may have respawned since the list was sent: find its current body by name.
		local model = entry.Model
		if not (model and model.Parent and model:FindFirstChild("Head")) then
			model = nil
			for _, m in ipairs(game:GetService("CollectionService"):GetTagged("SpinFighter")) do
				local hum = m:FindFirstChildOfClass("Humanoid")
				if m.Parent and (m.Name == entry.Name or (hum and hum.DisplayName == entry.Name)) then
					model = m
				end
			end
		end
		if not faceViewport(model, photo) then
			-- No body to photograph: their initials on their Stand's colour.
			local who = (entry.Name or "?"):gsub("^Stand User: ", "")
			local initials = ""
			for word in who:gmatch("%S+") do
				if #initials < 2 then
					initials = initials .. word:sub(1, 1)
				end
			end
			label(photo, { Size = UDim2.fromScale(1, 1), Text = string.upper(initials), Font = Enum.Font.Bangers, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3 })
		end
	end
	return photo
end

---------------------------------------------------------------------------
-- Board
---------------------------------------------------------------------------
local lastList = {}
local lastJobs, lastShop, jobsUntil = {}, {}, 0
local lastStable = { Coats = {}, Blankets = {} }
local stablePreview -- { Camera, Angle } spinning horse in the STABLE
local showStable -- (below)
local fillGrid -- (below)
local placeAmount = 100
local placeButton -- "PUT $100 ON THEIR HEAD" on a player's contract
local lastTargets = {} -- who you can post a bounty on (POST tab)
local postCfg = { Min = 25, Max = 5000, Cap = 10000, Quick = { 25, 100, 500 } }
local postPick -- the Key of the target picked in the POST tab
local postAmount = 100
local jobsTimer -- "NEW JOBS IN m:ss"
local filter = "ALL"
local tabs = {}
local cashLabel, huntingLabel, countLabel
local SLIDE = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local GLOW = Color3.fromRGB(255, 214, 110)
local BURNT = Color3.fromRGB(120, 78, 40)
local NAIL = Color3.fromRGB(70, 70, 76)

-- "STAND: BALL BREAKER" from the Act a character is playing.
local function standOf(act)
	if not act then
		return nil
	end
	local who = Registry.characterOf(act)
	if who == "Johnny" then
		local info = Registry.get(act)
		return info and info.Name
	end
	for _, entry in ipairs(TuskConfig.Roster or {}) do
		if entry.Id == who then
			return entry.Stand
		end
	end
	return nil
end

local function themeOf(act)
	local info = act and Registry.get(act)
	return info and info.Theme.Primary or PAPER_DARK
end

local function cashText()
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	return "$" .. tostring(cash and cash.Value or 0)
end

local openToken = 0
local function closeBoard()
	if confirmLayer then
		confirmLayer.Visible = false
	end
	if not dim or not dim.Visible then
		return
	end
	-- Slide up and away.
	TweenService:Create(board, SOFT, { Position = UDim2.fromScale(0.5, -0.6) }):Play()
	TweenService:Create(dim, SOFT, { BackgroundTransparency = 1 }):Play()
	local token = openToken
	task.delay(0.22, function()
		if openToken == token then
			dim.Visible = false
		end
	end)
end

local function showConfirm(entry)
	confirmLayer.Visible = true
	confirm.Visible = true
	local body = confirm:FindFirstChild("Body")
	for _, c in ipairs(body:GetChildren()) do
		if c.Name == "Photo" then
			c:Destroy()
		end
	end
	local photo = photoFor(entry, body)
	photo.AnchorPoint = Vector2.new(0.5, 0)
	photo.Position = UDim2.new(0.5, 0, 0, 66)
	photo.Size = UDim2.fromOffset(136, 136)
	corner(photo, 6)
	new("UIStroke", { Color = WOOD_DARK, Thickness = 4 }, photo)
	body:FindFirstChild("Who").Text = string.upper(entry.Name)
	local stand = standOf(entry.Act)
	if entry.Kind == "Corpse" then
		body:FindFirstChild("Stand").Text = "GIVES: " .. string.upper(entry.Boost or "")
		body:FindFirstChild("Stand").TextColor3 = Color3.fromRGB(150, 100, 20)
	else
		body:FindFirstChild("Stand").Text = stand and ("STAND: " .. stand) or ""
		body:FindFirstChild("Stand").TextColor3 = themeOf(entry.Act):Lerp(INK, 0.45)
	end
	confirmPay.Text = "$" .. entry.Reward
	local danger = math.clamp(math.floor(entry.Reward / 75 + 0.5), 1, 5)
	for i, pip in ipairs(confirmPips) do
		pip.BackgroundColor3 = i <= danger and RED or PAPER_DARK
	end
	local minutes = math.floor((TuskConfig.Bounty and TuskConfig.Bounty.Duration or 300) / 60)
	body:FindFirstChild("Note").Text = (current and current.Key ~= entry.Key) and ("This replaces your bounty on " .. current.Name .. ".")
		or (entry.Kind == "Corpse" and (entry.HeldBy and (entry.HeldBy .. " is carrying it: take them down, then take the part. Paid the moment you take it.") or "It's lying out in the desert under a pillar of light. Paid the moment you take it."))
		or (entry.Corpse and ("Carrying the Saint's Corpse: " .. entry.Corpse .. ". Take them down and the parts drop."))
		or (minutes .. " minutes to find them. Land the final hit to claim the reward.")
	body:FindFirstChild("Stamp").Visible = false
	if placeButton then
		placeButton.Visible = entry.Kind == "Player"
		placeButton:FindFirstChild("Top").Text = "+$" .. placeAmount
	end
	if entry.Placed then
		body:FindFirstChild("Note").Text = "Includes a $" .. entry.Placed .. " price on their head. " .. body:FindFirstChild("Note").Text
	end
	confirmEntry = entry
	local scale = confirm:FindFirstChildOfClass("UIScale")
	scale.Scale = 0.6
	confirm.Rotation = -4
	TweenService:Create(scale, FAST, { Scale = 1 }):Play()
	TweenService:Create(confirm, FAST, { Rotation = 0 }):Play()
end

local function makePoster(entry, index)
	local col = (index - 1) % 4
	local row = math.floor((index - 1) / 4)
	local tilt = ((index * 37) % 11 - 5) * 1.1
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(146, 204), Position = UDim2.fromOffset(14 + col * 160, 16 + row * 222) }, grid)
	local shadow = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.82, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(5, 6), Rotation = tilt }, holder)
	corner(shadow, 4)
	local paper = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = PAPER, Size = UDim2.fromScale(1, 1), Rotation = tilt }, holder)
	corner(paper, 3)
	local scale = new("UIScale", { Scale = 1 }, paper)
	-- Aged paper: lighter middle, browner edges, a burnt-looking border.
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, PAPER_DARK), ColorSequenceKeypoint.new(0.35, PAPER), ColorSequenceKeypoint.new(1, PAPER_DARK) }), Rotation = 70 }, paper)
	local edge = new("UIStroke", { Color = BURNT, Thickness = 2, Transparency = 0.25 }, paper)
	-- Red pin with a shine.
	local pin = new("Frame", { BackgroundColor3 = RED, Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0.5, -7, 0, -4), ZIndex = 3 }, paper)
	corner(pin, 99)
	new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.4, Size = UDim2.fromOffset(4, 4), Position = UDim2.fromOffset(3, 3), ZIndex = 3 }, pin)
	local isCorpse = entry.Kind == "Corpse"
	label(paper, { Position = UDim2.fromScale(0.06, 0.06), Size = UDim2.fromScale(0.88, 0.13), Text = isCorpse and "RETRIEVE" or "WANTED", Font = Enum.Font.Bangers, TextColor3 = isCorpse and Color3.fromRGB(150, 100, 20) or INK })
	label(paper, { Position = UDim2.fromScale(0.1, 0.185), Size = UDim2.fromScale(0.8, 0.05), Text = isCorpse and "SAINT'S CORPSE" or "DEAD OR ALIVE", Font = Enum.Font.GothamBold, TextColor3 = INK:Lerp(PAPER, 0.25) })
	local photo = photoFor(entry, paper)
	photo.Position = UDim2.fromScale(0.15, 0.25)
	photo.Size = UDim2.fromScale(0.7, 0.36)
	new("UIStroke", { Color = INK, Thickness = 2 }, photo)
	label(paper, { Position = UDim2.fromScale(0.05, 0.63), Size = UDim2.fromScale(0.9, 0.08), Text = isCorpse and string.upper((entry.Name:gsub("^SAINT'S CORPSE: ", ""))) or string.upper(entry.Name), TextTruncate = Enum.TextTruncate.AtEnd })
	local stand = standOf(entry.Act)
	if isCorpse then
		label(paper, { Position = UDim2.fromScale(0.05, 0.71), Size = UDim2.fromScale(0.9, 0.05), Text = entry.HeldBy and ("HELD BY " .. string.upper(entry.HeldBy)) or "LYING IN THE DESERT", Font = Enum.Font.GothamBold, TextColor3 = entry.HeldBy and RED or INK:Lerp(PAPER, 0.3) })
	elseif stand then
		label(paper, { Position = UDim2.fromScale(0.05, 0.71), Size = UDim2.fromScale(0.9, 0.05), Text = "STAND: " .. stand, Font = Enum.Font.GothamBold, TextColor3 = themeOf(entry.Act):Lerp(INK, 0.5) })
	end
	-- Danger pips: more pips, more reward.
	local danger = math.clamp(math.floor(entry.Reward / 75 + 0.5), 1, 5)
	for i = 1, 5 do
		local pip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, (i - 3) * 13, 0.795, 0), Size = UDim2.fromOffset(7, 7), Rotation = 45, BackgroundColor3 = i <= danger and RED or PAPER_DARK }, paper)
		new("UIStroke", { Color = INK, Thickness = 1, Transparency = 0.4 }, pip)
	end
	-- Reward ribbon.
	local ribbon = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.84, 0), Size = UDim2.fromScale(0.72, 0.12), BackgroundColor3 = RED }, paper)
	corner(ribbon, 4)
	label(ribbon, { Size = UDim2.fromScale(1, 1), Text = "$" .. entry.Reward, Font = Enum.Font.Bangers, TextColor3 = PAPER })
	if entry.Corpse then
		-- A gold "SAINT'S CORPSE" tag: they're carrying parts.
		local tagC = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -16), Size = UDim2.fromOffset(120, 18), BackgroundColor3 = GOLD, Rotation = -4, ZIndex = 4 }, paper)
		corner(tagC, 4)
		label(tagC, { Size = UDim2.fromScale(1, 1), Text = "SAINT'S CORPSE", Font = Enum.Font.GothamBlack, TextColor3 = INK, TextScaled = true, ZIndex = 4 })
	end
	if entry.Placed then
		local priceTag = new("Frame", { AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, -8, 0, -8), Size = UDim2.fromOffset(62, 22), BackgroundColor3 = GOLD, Rotation = -10, ZIndex = 3 }, paper)
		corner(priceTag, 6)
		label(priceTag, { Size = UDim2.fromScale(1, 1), Text = "+$" .. entry.Placed, Font = Enum.Font.Bangers, TextColor3 = INK, ZIndex = 3 })
	end
	if (entry.Streak or 0) > 0 then
		local badge = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(46, 22), BackgroundColor3 = INK, Rotation = 8, ZIndex = 3 }, paper)
		corner(badge, 6)
		label(badge, { Size = UDim2.fromScale(1, 1), Text = "x" .. entry.Streak .. " KILLS", TextColor3 = GOLD, ZIndex = 3 })
	end
	-- "CLICK TO HUNT" tag shown while hovered.
	local tag = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 14), Size = UDim2.fromOffset(110, 20), BackgroundColor3 = INK, BackgroundTransparency = 1, ZIndex = 4 }, paper)
	corner(tag, 6)
	local tagText = label(tag, { Size = UDim2.fromScale(1, 1), Text = "CLICK TO HUNT", TextColor3 = GOLD, TextTransparency = 1, ZIndex = 4 })
	if current and current.Key == entry.Key then
		local stamp = label(paper, { Position = UDim2.fromScale(0.05, 0.34), Size = UDim2.fromScale(0.9, 0.18), Rotation = -18, Text = "HUNTING", Font = Enum.Font.Bangers, TextColor3 = RED, TextTransparency = 0.1, ZIndex = 3 })
		new("UIStroke", { Color = RED, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.3 }, stamp)
	end
	-- Hover: straighten, lift, grow, glow gold, cast a bigger shadow.
	paper.MouseEnter:Connect(function()
		holder.ZIndex = 5
		TweenService:Create(paper, FAST, { Rotation = 0, Position = UDim2.fromOffset(0, -10) }):Play()
		TweenService:Create(scale, FAST, { Scale = 1.1 }):Play()
		TweenService:Create(edge, SOFT, { Color = GLOW, Thickness = 3, Transparency = 0 }):Play()
		TweenService:Create(shadow, SOFT, { BackgroundTransparency = 0.55, Rotation = 0, Position = UDim2.fromOffset(10, 10) }):Play()
		TweenService:Create(tag, SOFT, { BackgroundTransparency = 0.1 }):Play()
		TweenService:Create(tagText, SOFT, { TextTransparency = 0 }):Play()
	end)
	paper.MouseLeave:Connect(function()
		holder.ZIndex = 1
		TweenService:Create(paper, SOFT, { Rotation = tilt, Position = UDim2.fromOffset(0, 0) }):Play()
		TweenService:Create(scale, SOFT, { Scale = 1 }):Play()
		TweenService:Create(edge, SOFT, { Color = BURNT, Thickness = 2, Transparency = 0.25 }):Play()
		TweenService:Create(shadow, SOFT, { BackgroundTransparency = 0.82, Rotation = tilt, Position = UDim2.fromOffset(5, 6) }):Play()
		TweenService:Create(tag, SOFT, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(tagText, SOFT, { TextTransparency = 1 }):Play()
	end)
	paper.Activated:Connect(function()
		-- A little "tug" when picked.
		scale.Scale = 1.18
		TweenService:Create(scale, FAST, { Scale = 1.1 }):Play()
		showConfirm(entry)
	end)
	-- Posters drop onto the board one after another.
	paper.Position = UDim2.fromOffset(0, -40)
	task.delay(0.15 + index * 0.05, function()
		TweenService:Create(paper, FAST, { Position = UDim2.fromOffset(0, 0) }):Play()
	end)
end

---------------------------------------------------------------------------
-- JOBS and SHOP (drawn in the same space as the posters)
---------------------------------------------------------------------------
local function paperCard(parent, pos, size, tilt)
	local card = new("Frame", { Position = pos, Size = size, BackgroundColor3 = PAPER, Rotation = tilt or 0 }, parent)
	corner(card, 4)
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, PAPER_DARK), ColorSequenceKeypoint.new(0.4, PAPER), ColorSequenceKeypoint.new(1, PAPER_DARK) }), Rotation = 80 }, card)
	new("UIStroke", { Color = BURNT, Thickness = 2, Transparency = 0.25 }, card)
	local pin = new("Frame", { BackgroundColor3 = RED, Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, 10, 0, -4), ZIndex = 3 }, card)
	corner(pin, 99)
	return card
end

local function showJobs()
	local y = 16
	for i, job in ipairs(lastJobs) do
		local card = paperCard(grid, UDim2.fromOffset(14, y), UDim2.new(1, -40, 0, 92), ((i * 37) % 5 - 2) * 0.4)
		label(card, { Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(60, 20), Text = "JOB", Font = Enum.Font.Bangers, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Left })
		local text = label(card, { Position = UDim2.fromOffset(16, 28), Size = UDim2.new(1, -170, 0, 24), Text = string.upper(job.Text), TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
		new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 9 }, text)
		-- Progress bar.
		local bar = new("Frame", { Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -170, 0, 16), BackgroundColor3 = PAPER_DARK }, card)
		corner(bar, 6)
		new("UIStroke", { Color = INK, Thickness = 1, Transparency = 0.4 }, bar)
		local k = math.clamp((job.Progress or 0) / math.max(job.Goal or 1, 1), 0, 1)
		local fill = new("Frame", { Size = UDim2.fromScale(k, 1), BackgroundColor3 = job.Done and GREEN or GOLD }, bar)
		corner(fill, 6)
		label(bar, { Size = UDim2.fromScale(1, 1), Text = (job.Progress or 0) .. " / " .. (job.Goal or 1), Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = INK })
		local ribbon = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(120, 44), BackgroundColor3 = job.Done and GREEN or RED }, card)
		corner(ribbon, 6)
		label(ribbon, { Size = UDim2.fromScale(1, 1), Text = job.Done and "PAID" or ("$" .. (job.Reward or 0)), Font = Enum.Font.Bangers, TextColor3 = PAPER })
		if job.Done then
			local stamp = label(card, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.42, 0.5), Size = UDim2.fromOffset(160, 50), Rotation = -12, Text = "DONE", Font = Enum.Font.Bangers, TextColor3 = GREEN, TextTransparency = 0.15, ZIndex = 3 })
			new("UIStroke", { Color = GREEN, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.3 }, stamp)
		end
		y = y + 104
	end
	jobsTimer = new("Frame", { Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -40, 0, 28), BackgroundTransparency = 1 }, grid)
	label(jobsTimer, { Name = "Text", Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = PAPER, Font = Enum.Font.GothamBold })
	label(jobsTimer, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 18), Text = "Progress counts on its own. You're paid the moment a job's done.", TextColor3 = PAPER_DARK, Font = Enum.Font.GothamMedium })
	grid.CanvasSize = UDim2.fromOffset(0, y + 60)
	return #lastJobs
end

-- STABLE: customise your horse (ride it with M): coat, mane & tail,
-- blanket, saddle, marking, socks and its name.
local STABLE_SECTIONS = {
	{ List = "Coats", Kind = "Coat", Title = "COAT" },
	{ List = "Manes", Kind = "Mane", Title = "MANE & TAIL" },
	{ List = "Blankets", Kind = "Blanket", Title = "SADDLE BLANKET" },
	{ List = "Saddles", Kind = "Saddle", Title = "SADDLE & BRIDLE" },
	{ List = "Markings", Kind = "Marking", Title = "FACE MARKING" },
	{ List = "Socks", Kind = "Socks", Title = "WHITE SOCKS" },
}

local function stableSelection()
	local sel = {}
	for _, sec in ipairs(STABLE_SECTIONS) do
		for _, item in ipairs(lastStable[sec.List] or {}) do
			if item.Equipped then
				sel[sec.Kind] = item.Id
			end
		end
	end
	return sel
end

local MARK_ICONS = { Blaze = "|", None = "-", Star = "*", Stripe = "!", Bald = "O" }
local SOCK_ICONS = { Two = "2", None = "0", Front = "F", Back = "B", Four = "4" }

showStable = function(y, cash)
	stablePreview = nil
	if #(lastStable.Coats or {}) == 0 then
		return y
	end
	local head = new("Frame", { Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -40, 0, 30), BackgroundColor3 = WOOD_DARK }, grid)
	corner(head, 6)
	label(head, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), Text = "STABLE  ·  CUSTOMISE YOUR HORSE  (PRESS M TO RIDE)", Font = Enum.Font.Bangers, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left })
	y = y + 40
	-- Left: a spinning preview and the name box.
	local panel = paperCard(grid, UDim2.fromOffset(14, y), UDim2.fromOffset(200, 290), 0)
	local vp = new("ViewportFrame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 190), BackgroundColor3 = Color3.fromRGB(230, 210, 170), Ambient = Color3.fromRGB(200, 190, 170), LightColor = Color3.new(1, 1, 1) }, panel)
	corner(vp, 4)
	local nameText = lastStable.Name and string.upper(lastStable.Name) or "YOUR HORSE"
	label(panel, { Position = UDim2.fromOffset(8, 200), Size = UDim2.new(1, -16, 0, 24), Text = nameText, Font = Enum.Font.Bangers })
	local box = new("TextBox", { Position = UDim2.fromOffset(8, 228), Size = UDim2.new(1, -78, 0, 28), BackgroundColor3 = Color3.fromRGB(250, 240, 215), Text = "", PlaceholderText = "Name your horse", ClearTextOnFocus = false, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = INK, PlaceholderColor3 = INK:Lerp(PAPER, 0.5) }, panel)
	corner(box, 6)
	new("UIStroke", { Color = INK, Thickness = 1, Transparency = 0.4 }, box)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, box)
	local nameBtn = new("TextButton", { Position = UDim2.new(1, -66, 0, 228), Size = UDim2.fromOffset(58, 28), BackgroundColor3 = GREEN, Text = "NAME", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, panel)
	corner(nameBtn, 6)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, nameBtn)
	nameBtn.Activated:Connect(function()
		Remote:FireServer("NameHorse", string.sub(box.Text or "", 1, lastStable.NameMax or 20))
	end)
	label(panel, { Position = UDim2.fromOffset(8, 262), Size = UDim2.new(1, -16, 0, 20), Text = "Shown above your horse", Font = Enum.Font.GothamMedium, TextColor3 = INK:Lerp(PAPER, 0.35) })
	if HorseModel and HorseModel.lookFrom then
		local ok, horse = pcall(function()
			local body, mane, opts = HorseModel.lookFrom(TuskConfig.Horses, stableSelection())
			return HorseModel.build(body, mane, opts)
		end)
		if ok and horse then
			for _, d in ipairs(horse:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			horse.Parent = vp
			local cam = new("Camera", { FieldOfView = 40 }, vp)
			vp.CurrentCamera = cam
			stablePreview = { Camera = cam, Angle = 0.6 }
			cam.CFrame = CFrame.lookAt(Vector3.new(math.sin(0.6) * 13, 2, math.cos(0.6) * 13), Vector3.new(0, 0.2, -0.6))
		end
	end
	-- Right: every category as a row of small cards, 3 to a row.
	local function swatchCard(x, yy, item, key, sec)
		local card = paperCard(grid, UDim2.fromOffset(x, yy), UDim2.fromOffset(134, 62), 0)
		local colorA = item.Body or item.Color
		local sw = new("Frame", { Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = colorA or WOOD_DARK }, card)
		corner(sw, 99)
		new("UIStroke", { Color = INK, Thickness = 2 }, sw)
		if item.Mane then
			new("Frame", { Position = UDim2.fromOffset(13, 0), Size = UDim2.fromOffset(6, 32), BackgroundColor3 = item.Mane, BorderSizePixel = 0 }, sw)
		end
		local icon = (sec.Kind == "Marking" and MARK_ICONS[item.Style or ""]) or (sec.Kind == "Socks" and SOCK_ICONS[item.Style or ""]) or (sec.Kind == "Mane" and not colorA and "~")
		if icon then
			label(sw, { Size = UDim2.fromScale(1, 1), Text = icon, Font = Enum.Font.GothamBlack, TextColor3 = colorA and INK or GOLD })
		end
		local nameL = label(card, { Position = UDim2.fromOffset(46, 6), Size = UDim2.fromOffset(84, 18), Text = item.Name, Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left })
		new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 7 }, nameL)
		local state
		if not item.Owned then
			state = "$" .. item.Price
		else
			state = item.Equipped and "EQUIPPED" or "EQUIP"
		end
		local afford = item.Owned or cash >= item.Price
		local color = item.Equipped and GOLD or (item.Owned and WOOD_DARK or (afford and GREEN or Color3.fromRGB(130, 120, 110)))
		local btn = new("TextButton", { Position = UDim2.fromOffset(46, 30), Size = UDim2.fromOffset(80, 24), BackgroundColor3 = color, Text = state, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = item.Equipped and INK or Color3.new(1, 1, 1), AutoButtonColor = not item.Equipped }, card)
		corner(btn, 6)
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, btn)
		btn.Activated:Connect(function()
			if not item.Equipped then
				Remote:FireServer("BuyHorse", key)
			end
		end)
	end
	local x0 = 226
	local rowY = y
	for _, sec in ipairs(STABLE_SECTIONS) do
		local items = lastStable[sec.List] or {}
		if #items > 0 then
			label(grid, { Position = UDim2.fromOffset(x0, rowY - 2), Size = UDim2.fromOffset(300, 16), Text = sec.Title, Font = Enum.Font.GothamBlack, TextColor3 = PAPER, TextXAlignment = Enum.TextXAlignment.Left })
			rowY = rowY + 16
			for i, item in ipairs(items) do
				local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
				swatchCard(x0 + col * 140, rowY + row * 68, item, sec.Kind .. ":" .. item.Id, sec)
			end
			rowY = rowY + math.ceil(#items / 3) * 68 + 8
		end
	end
	return math.max(rowY, y + 300)
end

-- The SHOP: a general store. Items are grouped under wooden section signs
-- (SUPPLIES / TONICS / GEAR / SERVICES); each is a parchment card with a
-- picture medallion, its name, an effect chip and a duration chip, a
-- hanging price tag and a BUY button. Things you've bought and that are
-- still working get a green ACTIVE ribbon and a time-left bar (buy again
-- to top it up); things you can't afford say how much more you need.
local SHOP_SECTIONS = {
	{ Id = "SUPPLIES", Title = "SUPPLIES", Sub = "patch up and find your way", Color = Color3.fromRGB(70, 140, 80) },
	{ Id = "TONICS", Title = "TONICS & LUCK", Sub = "a little something for the road", Color = Color3.fromRGB(150, 70, 140) },
	{ Id = "GEAR", Title = "GEAR", Sub = "for the hunter, and the hunted", Color = Color3.fromRGB(70, 110, 170) },
	{ Id = "SERVICES", Title = "SERVICES", Sub = "the sheriff's office", Color = Color3.fromRGB(150, 60, 40) },
}
local shopBars = {} -- { Fill, Text, Until, Time } live time-left bars

local function sectionSign(y, sec)
	local sign = new("Frame", { Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -40, 0, 34), BackgroundColor3 = WOOD_DARK }, grid)
	corner(sign, 6)
	new("UIStroke", { Color = Color3.fromRGB(40, 24, 12), Thickness = 2 }, sign)
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WOOD_LIGHT), ColorSequenceKeypoint.new(1, WOOD_DARK) }), Rotation = 90 }, sign)
	local stripe = new("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = sec.Color, BorderSizePixel = 0 }, sign)
	corner(stripe, 6)
	for _, x in ipairs({ 0, 1 }) do
		local nail = new("Frame", { AnchorPoint = Vector2.new(x, 0.5), Position = UDim2.new(x, x == 0 and 16 or -10, 0.5, 0), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = NAIL }, sign)
		corner(nail, 99)
	end
	label(sign, { Position = UDim2.fromOffset(28, 2), Size = UDim2.new(0.5, 0, 1, -4), Text = sec.Title, Font = Enum.Font.Bangers, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.5 })
	label(sign, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 9), Size = UDim2.new(0.45, 0, 0, 16), Text = string.upper(sec.Sub), Font = Enum.Font.GothamBold, TextColor3 = PAPER_DARK, TextXAlignment = Enum.TextXAlignment.Right })
	return y + 44
end

local function chip(parent, x, y, text, color, textColor)
	local w = math.clamp(#text * 7 + 16, 44, 150)
	local c = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 18), BackgroundColor3 = color }, parent)
	corner(c, 9)
	label(c, { Size = UDim2.fromScale(1, 1), Text = text, Font = Enum.Font.GothamBlack, TextColor3 = textColor or PAPER })
	return c, w
end

local function shopCard(item, x, y, cash, secColor)
	local card = paperCard(grid, UDim2.fromOffset(x, y), UDim2.fromOffset(300, 140), ((#item.Name * 7) % 5 - 2) * 0.25)
	-- A coloured band down the left edge (its section).
	local band = new("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = secColor, BorderSizePixel = 0 }, card)
	corner(band, 4)
	-- Picture medallion: a gold-rimmed disc with the item's picture.
	local medal = new("Frame", { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(62, 62), BackgroundColor3 = secColor:Lerp(WOOD_DARK, 0.45) }, card)
	corner(medal, 99)
	new("UIStroke", { Color = GOLD, Thickness = 3 }, medal)
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 170, 170)) }), Rotation = 90 }, medal)
	label(medal, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.72, 0.72), Text = item.Emoji or item.Icon or "?", Font = Enum.Font.GothamBlack, TextColor3 = GOLD })
	-- Name, effect.
	local name = label(card, { Position = UDim2.fromOffset(88, 12), Size = UDim2.new(1, -170, 0, 24), Text = item.Name, Font = Enum.Font.Bangers, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 10 }, name)
	local desc = label(card, { Position = UDim2.fromOffset(88, 38), Size = UDim2.new(1, -100, 0, 30), Text = item.Text, Font = Enum.Font.GothamMedium, TextWrapped = true, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, desc)
	-- Chips: what it does, how long.
	local cx = 88
	if item.Tag then
		local _, w = chip(card, cx, 72, item.Tag, secColor:Lerp(INK, 0.15))
		cx = cx + w + 6
	end
	local t = item.Time
	chip(card, cx, 72, t and (t >= 60 and string.format("%d:%02d", math.floor(t / 60), t % 60) or (t .. " S")) or "INSTANT", WOOD_DARK)
	-- The price tag, hanging from a string at the top right.
	local clean = item.Clean
	local price = item.Price or 0
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(1, -40, 0, -4), Size = UDim2.fromOffset(2, 12), BackgroundColor3 = BURNT, BorderSizePixel = 0 }, card)
	local tag = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(1, -40, 0, 6), Size = UDim2.fromOffset(62, 26), Rotation = 6, BackgroundColor3 = Color3.fromRGB(250, 238, 210) }, card)
	corner(tag, 5)
	new("UIStroke", { Color = BURNT, Thickness = 2 }, tag)
	label(tag, { Size = UDim2.fromScale(1, 1), Text = clean and "FREE" or ("$" .. price), Font = Enum.Font.Bangers, TextColor3 = (cash >= price or clean) and INK or RED })
	-- Buy button: green if you can, grey with how much more you need if not.
	local afford = cash >= price and not clean
	local activeUntil = item.Active
	local text = clean and "ALREADY CLEAN" or (afford and ((activeUntil and "TOP UP  $" or "BUY  $") .. price) or ("NEED $" .. (price - cash) .. " MORE"))
	local buy = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -10), Size = UDim2.fromOffset(140, 34), BackgroundColor3 = afford and GREEN or Color3.fromRGB(130, 120, 110), Text = text, Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = afford }, card)
	corner(buy, 8)
	new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, buy)
	new("UIStroke", { Color = (afford and GREEN or INK):Lerp(Color3.new(0, 0, 0), 0.4), Thickness = 2 }, buy)
	local scale = new("UIScale", { Scale = 1 }, buy)
	if afford then
		buy.MouseEnter:Connect(function()
			TweenService:Create(scale, FAST, { Scale = 1.07 }):Play()
		end)
		buy.MouseLeave:Connect(function()
			TweenService:Create(scale, SOFT, { Scale = 1 }):Play()
		end)
	end
	buy.Activated:Connect(function()
		if clean or not afford then
			return
		end
		scale.Scale = 0.88
		TweenService:Create(scale, FAST, { Scale = 1 }):Play()
		Remote:FireServer("Buy", item.Id)
	end)
	-- Working right now: a green ribbon and a time-left bar.
	if activeUntil and activeUntil > workspace:GetServerTimeNow() then
		local ribbon = new("Frame", { Position = UDim2.fromOffset(10, 84), Size = UDim2.fromOffset(72, 18), Rotation = -6, BackgroundColor3 = GREEN }, card)
		corner(ribbon, 4)
		label(ribbon, { Size = UDim2.fromScale(1, 1), Text = "ACTIVE", Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1) })
		local bar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -12), Size = UDim2.new(1, -176, 0, 14), BackgroundColor3 = PAPER_DARK }, card)
		corner(bar, 7)
		new("UIStroke", { Color = INK, Thickness = 1, Transparency = 0.5 }, bar)
		local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = GREEN }, bar)
		corner(fill, 7)
		local tl = label(bar, { Size = UDim2.fromScale(1, 1), Text = "", Font = Enum.Font.GothamBlack, TextColor3 = INK })
		table.insert(shopBars, { Fill = fill, Text = tl, Until = activeUntil, Time = item.Time or 60 })
	end
	return card
end

local function stepShopBars()
	local now = workspace:GetServerTimeNow()
	for i = #shopBars, 1, -1 do
		local b = shopBars[i]
		if not b.Fill.Parent then
			table.remove(shopBars, i)
		else
			local left = math.max(0, b.Until - now)
			b.Fill.Size = UDim2.fromScale(math.clamp(left / math.max(b.Time, 1), 0, 1), 1)
			b.Text.Text = left > 0 and string.format("%d:%02d LEFT", math.floor(left / 60), math.floor(left % 60)) or "USED UP"
		end
	end
end

local function showShop()
	local cash = 0
	local ls = player:FindFirstChild("leaderstats")
	local cv = ls and ls:FindFirstChild("Cash")
	cash = cv and cv.Value or 0
	shopBars = {}
	-- The store sign.
	local head = new("Frame", { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -40, 0, 58), BackgroundColor3 = Color3.fromRGB(60, 38, 22) }, grid)
	corner(head, 8)
	new("UIStroke", { Color = GOLD, Thickness = 2, Transparency = 0.3 }, head)
	label(head, { Position = UDim2.fromOffset(16, 4), Size = UDim2.new(0.6, 0, 0, 34), Text = "GENERAL STORE", Font = Enum.Font.Bangers, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0.4 })
	label(head, { Position = UDim2.fromOffset(16, 36), Size = UDim2.new(0.6, 0, 0, 14), Text = "EFFECTS LAST UNTIL THEY RUN OUT OR YOU GO DOWN", Font = Enum.Font.GothamBold, TextColor3 = PAPER_DARK, TextXAlignment = Enum.TextXAlignment.Left })
	local purse = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 38), BackgroundColor3 = GOLD }, head)
	corner(purse, 8)
	new("UIStroke", { Color = WOOD_DARK, Thickness = 2 }, purse)
	label(purse, { Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(34, 38), Text = "💰", Font = Enum.Font.GothamBlack })
	label(purse, { Position = UDim2.fromOffset(40, 2), Size = UDim2.new(1, -46, 1, -4), Text = "$" .. cash, Font = Enum.Font.Bangers, TextColor3 = INK })
	local y = 84
	-- Group the items under their section signs (anything uncategorised last).
	local placed = {}
	local sections = {}
	for _, sec in ipairs(SHOP_SECTIONS) do
		table.insert(sections, sec)
	end
	table.insert(sections, { Id = "_", Title = "MORE", Sub = "odds and ends", Color = WOOD })
	for _, sec in ipairs(sections) do
		local items = {}
		for _, item in ipairs(lastShop) do
			if not placed[item] and (item.Category == sec.Id or (sec.Id == "_" and true)) then
				table.insert(items, item)
				placed[item] = true
			end
		end
		if #items > 0 then
			y = sectionSign(y, sec)
			for i, item in ipairs(items) do
				local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
				shopCard(item, 14 + col * 316, y + row * 152, cash, sec.Color)
			end
			y = y + math.ceil(#items / 2) * 152 + 4
		end
	end
	y = showStable(y + 6, cash)
	grid.CanvasSize = UDim2.fromOffset(0, y + 20)
	return #lastShop
end

-- POST: put your own Cash on someone (or something).
local function cashNow()
	local ls = player:FindFirstChild("leaderstats")
	local cv = ls and ls:FindFirstChild("Cash")
	return cv and cv.Value or 0
end

local function showPost()
	local picked
	for _, t in ipairs(lastTargets) do
		if t.Key == postPick then
			picked = t
		end
	end
	if not picked then
		postPick = nil
	end
	local cash = cashNow()
	-- The form.
	local card = paperCard(grid, UDim2.fromOffset(14, 16), UDim2.new(1, -40, 0, 176), -0.4)
	label(card, { Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(260, 30), Text = "POST A BOUNTY", Font = Enum.Font.Bangers, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Left })
	local photoBox = new("Frame", { Position = UDim2.fromOffset(16, 46), Size = UDim2.fromOffset(100, 100), BackgroundColor3 = PAPER_DARK }, card)
	corner(photoBox, 6)
	new("UIStroke", { Color = WOOD_DARK, Thickness = 3 }, photoBox)
	if picked then
		local photo = photoFor(picked, photoBox)
		photo.Size = UDim2.fromScale(1, 1)
		corner(photo, 6)
	else
		label(photoBox, { Size = UDim2.fromScale(1, 1), Text = "?", Font = Enum.Font.Bangers, TextColor3 = WOOD_DARK })
	end
	local who = label(card, { Position = UDim2.fromOffset(128, 44), Size = UDim2.new(1, -144, 0, 26), Text = picked and string.upper((picked.Self and "YOURSELF: " or "ON: ") .. picked.Name) or "PICK WHO IT'S ON BELOW", TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 10 }, who)
	label(card, { Position = UDim2.fromOffset(128, 70), Size = UDim2.new(1, -144, 0, 16), Text = picked and ((picked.Posted or 0) > 0 and ("ALREADY ON THEM: $" .. picked.Posted) or "NOTHING ON THEM YET") or "", Font = Enum.Font.GothamBold, TextColor3 = (picked and (picked.Posted or 0) > 0) and RED or INK, TextXAlignment = Enum.TextXAlignment.Left })
	-- Amount: type it, or tap the chips.
	local box = new("TextBox", { Position = UDim2.fromOffset(128, 94), Size = UDim2.fromOffset(120, 38), BackgroundColor3 = Color3.fromRGB(250, 236, 205), Text = tostring(postAmount), PlaceholderText = "$", ClearTextOnFocus = false, Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = INK }, card)
	corner(box, 6)
	new("UIStroke", { Color = WOOD_DARK, Thickness = 2 }, box)
	new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, box)
	label(card, { Position = UDim2.fromOffset(112, 94), Size = UDim2.fromOffset(16, 38), Text = "$", Font = Enum.Font.Bangers, TextColor3 = INK })
	local postButton
	local function refreshButton()
		local ok = picked ~= nil and postAmount >= (postCfg.Min or 25) and postAmount <= cash
		postButton.Text = "POST  $" .. postAmount
		postButton.BackgroundColor3 = ok and GREEN or Color3.fromRGB(130, 120, 110)
		postButton.AutoButtonColor = ok
		box.Text = tostring(postAmount)
	end
	local function setAmount(v)
		v = math.floor(tonumber(v) or postAmount)
		postAmount = math.clamp(v, postCfg.Min or 25, postCfg.Max or 5000)
		refreshButton()
	end
	box.FocusLost:Connect(function()
		setAmount((box.Text or ""):gsub("[^%d]", ""))
	end)
	local chips = {}
	for _, q in ipairs(postCfg.Quick or { 25, 100, 500 }) do
		table.insert(chips, { "+$" .. q, function()
			setAmount(postAmount + q)
		end })
	end
	table.insert(chips, { "MAX", function()
		setAmount(math.min(cash, postCfg.Max or 5000))
	end })
	table.insert(chips, { "RESET", function()
		setAmount(postCfg.Min or 25)
	end })
	for i, c in ipairs(chips) do
		local chip = new("TextButton", { Position = UDim2.fromOffset(256 + (i - 1) * 54, 98), Size = UDim2.fromOffset(50, 30), BackgroundColor3 = i > #chips - 2 and WOOD_DARK or GOLD, Text = c[1], Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = i > #chips - 2 and PAPER or INK }, card)
		corner(chip, 6)
		new("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7) }, chip)
		chip.Activated:Connect(c[2])
	end
	postButton = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -10), Size = UDim2.fromOffset(170, 40), BackgroundColor3 = GREEN, Text = "", Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, card)
	corner(postButton, 8)
	new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, postButton)
	new("UIStroke", { Color = Color3.fromRGB(30, 70, 34), Thickness = 2 }, postButton)
	local note = label(card, { Position = UDim2.fromOffset(16, 150), Size = UDim2.new(1, -210, 0, 18), Text = picked and picked.Self and "Bold. Whoever takes YOU down gets it." or "Whoever takes them down (or takes the part) gets it. Cash back if they leave.", Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, note)
	refreshButton()
	postButton.Activated:Connect(function()
		if not picked or postAmount > cashNow() then
			return
		end
		local sc = postButton:FindFirstChildOfClass("UIScale") or new("UIScale", { Scale = 1 }, postButton)
		sc.Scale = 0.9
		TweenService:Create(sc, FAST, { Scale = 1 }):Play()
		Remote:FireServer("Post", { Key = picked.Key, Amount = postAmount })
	end)
	-- Who it can be on.
	label(grid, { Position = UDim2.fromOffset(14, 200), Size = UDim2.new(1, -40, 0, 22), Text = "PICK WHO IT'S ON", Font = Enum.Font.Bangers, TextColor3 = PAPER, TextXAlignment = Enum.TextXAlignment.Left }).Name = "PostHeader"
	local w = 196
	for i, t in ipairs(lastTargets) do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local tc = new("TextButton", { Position = UDim2.fromOffset(14 + col * (w + 8), 228 + row * 80), Size = UDim2.fromOffset(w, 70), BackgroundColor3 = t.Key == postPick and Color3.fromRGB(255, 232, 170) or PAPER, Text = "", AutoButtonColor = true }, grid)
		-- (A Frame-like card so fillGrid clears it.)
		tc.Name = "PostTarget"
		corner(tc, 6)
		new("UIStroke", { Color = t.Key == postPick and GOLD or BURNT, Thickness = t.Key == postPick and 4 or 2 }, tc)
		local ph = photoFor(t, tc)
		ph.Position = UDim2.fromOffset(8, 8)
		ph.Size = UDim2.fromOffset(54, 54)
		corner(ph, 4)
		local nm = label(tc, { Position = UDim2.fromOffset(68, 6), Size = UDim2.new(1, -74, 0, 22), Text = string.upper((t.Name or ""):gsub("^SAINT'S CORPSE: ", "")), TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
		new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 8 }, nm)
		local kindText = t.Self and "YOU" or (t.Kind == "Corpse" and "CORPSE PART" or (t.Kind == "NPC" and "NPC" or "PLAYER"))
		local chip = new("Frame", { Position = UDim2.fromOffset(68, 30), Size = UDim2.fromOffset(t.Kind == "Corpse" and 84 or 52, 16), BackgroundColor3 = t.Self and GOLD or (t.Kind == "Corpse" and Color3.fromRGB(214, 178, 96) or (t.Kind == "NPC" and WOOD_DARK or GREEN)) }, tc)
		corner(chip, 4)
		label(chip, { Size = UDim2.fromScale(1, 1), Text = kindText, Font = Enum.Font.GothamBlack, TextColor3 = (t.Self or t.Kind == "Corpse") and INK or PAPER })
		label(tc, { Position = UDim2.fromOffset(68, 48), Size = UDim2.new(1, -74, 0, 16), Text = (t.Posted or 0) > 0 and ("$" .. t.Posted .. " ON THEM") or "", Font = Enum.Font.GothamBlack, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Left })
		tc.Activated:Connect(function()
			postPick = t.Key
			fillGrid()
		end)
	end
	grid.CanvasSize = UDim2.fromOffset(0, 240 + math.ceil(#lastTargets / 3) * 80)
	return #lastTargets
end

function fillGrid()
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("Frame") or c.Name == "PostTarget" or c.Name == "PostHeader" then
			c:Destroy()
		end
	end
	jobsTimer = nil
	if filter == "JOBS" or filter == "SHOP" or filter == "POST" then
		local n = filter == "JOBS" and showJobs() or (filter == "POST" and showPost() or showShop())
		local empty = grid:FindFirstChild("Empty")
		empty.Visible = n == 0
		empty.Text = filter == "JOBS" and "No jobs right now." or (filter == "POST" and "Nobody to post a bounty on." or "The shop is closed.")
		for name, tab in pairs(tabs) do
			local on = name == filter
			tab.BackgroundColor3 = on and GOLD or WOOD_DARK
			tab.TextColor3 = on and INK or PAPER
		end
		countLabel.Text = filter == "JOBS" and "PAID TASKS" or (filter == "POST" and "YOUR CASH ON ANYONE" or "SPEND YOUR CASH")
		return
	end
	local shown = {}
	for _, entry in ipairs(lastList) do
		if filter == "ALL" or (filter == "PLAYERS" and entry.Kind == "Player") or (filter == "NPCS" and entry.Kind == "NPC") or (filter == "CORPSE" and entry.Kind == "Corpse") then
			table.insert(shown, entry)
		end
	end
	-- ALL: corpse contracts are spread out among the other bounties (evenly)
	-- instead of all sitting together; the CORPSE tab still groups them.
	if filter == "ALL" then
		local others, parts = {}, {}
		for _, entry in ipairs(shown) do
			table.insert(entry.Kind == "Corpse" and parts or others, entry)
		end
		if #parts > 0 and #others > 0 then
			local mixed = {}
			local step = (#others + #parts) / #parts
			local nextAt = step / 2 -- first one partway in, not at the very top
			local pi = 1
			for _, entry in ipairs(others) do
				while pi <= #parts and #mixed + 1 >= nextAt do
					table.insert(mixed, parts[pi])
					pi = pi + 1
					nextAt = nextAt + step
				end
				table.insert(mixed, entry)
			end
			for i = pi, #parts do
				table.insert(mixed, parts[i])
			end
			shown = mixed
		end
	end
	local empty = grid:FindFirstChild("Empty")
	empty.Visible = #shown == 0
	empty.Text = filter == "PLAYERS" and "No other players are wanted right now.\n(Testing alone? Try Test > Clients and Servers.)" or "No bounties right now. Check back later!"
	for i, entry in ipairs(shown) do
		makePoster(entry, i)
	end
	grid.CanvasSize = UDim2.fromOffset(0, 30 + math.ceil(#shown / 4) * 222)
	for name, tab in pairs(tabs) do
		local on = name == filter
		tab.BackgroundColor3 = on and GOLD or WOOD_DARK
		tab.TextColor3 = on and INK or PAPER
	end
	local players, npcs, parts = 0, 0, 0
	for _, e in ipairs(lastList) do
		if e.Kind == "Player" then
			players = players + 1
		elseif e.Kind == "Corpse" then
			parts = parts + 1
		else
			npcs = npcs + 1
		end
	end
	countLabel.Text = players .. " PLAYERS · " .. npcs .. " NPCS · " .. parts .. " PARTS"
end

local function openBoard(data)
	confirmLayer.Visible = false
	current = data.Active or current
	lastList = data.Bounties or {}
	lastJobs, lastShop, jobsUntil = data.Jobs or {}, data.Shop or {}, data.JobsUntil or 0
	lastStable = data.Stable or lastStable
	placeAmount = data.PlaceAmount or placeAmount
	lastTargets = data.Targets or lastTargets
	postCfg = data.Post or postCfg
	cashLabel.Text = cashText()
	huntingLabel.Text = current and ("HUNTING: " .. string.upper(current.Name)) or "NO ACTIVE BOUNTY"
	fillGrid()
	local scale = board:FindFirstChildOfClass("UIScale")
	local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	scale.Scale = math.min(1, (view.X - 24) / 700, (view.Y - 24) / 560)
	-- Drop in from the top.
	openToken = openToken + 1
	dim.Visible = true
	dim.BackgroundTransparency = 1
	board.Position = UDim2.fromScale(0.5, -0.6)
	TweenService:Create(dim, SOFT, { BackgroundTransparency = 0.4 }):Play()
	TweenService:Create(board, SLIDE, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
end

local function buildBoard()
	dim = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), Visible = false }, gui)
	dim.Activated:Connect(closeBoard)
	-- Board: a dark wood frame round plank boards.
	board = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 560), BackgroundColor3 = WOOD_DARK }, dim)
	corner(board, 8)
	new("UIScale", { Scale = 1 }, board)
	new("UIStroke", { Color = Color3.fromRGB(45, 28, 16), Thickness = 3 }, board)
	local inner = new("Frame", { BackgroundColor3 = WOOD, Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 1, -24), ClipsDescendants = true }, board)
	corner(inner, 4)
	for i = 0, 7 do
		local plank = new("Frame", { BackgroundColor3 = (i % 3 == 0) and WOOD_LIGHT or (i % 3 == 1 and WOOD or Color3.fromRGB(122, 82, 50)), BorderSizePixel = 0, Position = UDim2.fromOffset(0, i * 68), Size = UDim2.new(1, 0, 0, 66) }, inner)
		-- Wood grain lines and a seam under each plank.
		for g = 1, 3 do
			local line = new("Frame", { BackgroundColor3 = WOOD_DARK, BorderSizePixel = 0, BackgroundTransparency = 0.55, Position = UDim2.new(((i * 7 + g * 13) % 10) / 20, 0, 0, 10 + g * 15 + (i % 2) * 4), Size = UDim2.new(0.5 + ((i + g) % 4) * 0.1, 0, 0, 2) }, plank)
			new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0), NumberSequenceKeypoint.new(0.7, 0), NumberSequenceKeypoint.new(1, 1) }) }, line)
		end
		new("Frame", { BackgroundColor3 = Color3.fromRGB(50, 32, 18), BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 2) }, plank)
		for _, x in ipairs({ 0, 1 }) do
			local nail = new("Frame", { BackgroundColor3 = NAIL, AnchorPoint = Vector2.new(x, 0.5), Position = UDim2.new(x, x == 0 and 8 or -8, 0.5, 0), Size = UDim2.fromOffset(6, 6) }, plank)
			corner(nail, 99)
		end
	end
	-- Dark edges (vignette) over the planks.
	local shade = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, inner)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.15, 1), NumberSequenceKeypoint.new(0.85, 1), NumberSequenceKeypoint.new(1, 0.55) }) }, shade)
	-- Metal corner brackets.
	for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		local bracket = new("Frame", { AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(90, 92, 100), ZIndex = 3 }, board)
		corner(bracket, 5)
		new("UIStroke", { Color = Color3.fromRGB(40, 40, 46), Thickness = 2 }, bracket)
		local bolt = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.fromRGB(170, 172, 180), ZIndex = 3 }, bracket)
		corner(bolt, 99)
	end
	-- Hanging title sign (inside the board, so it never goes off-screen).
	for _, x in ipairs({ -120, 120 }) do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, x, 0, 0), Size = UDim2.fromOffset(3, 18), BackgroundColor3 = Color3.fromRGB(200, 170, 110), BorderSizePixel = 0, ZIndex = 4 }, board)
	end
	local sign = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(330, 54), BackgroundColor3 = WOOD_DARK, ZIndex = 4 }, board)
	corner(sign, 6)
	new("UIStroke", { Color = Color3.fromRGB(40, 24, 12), Thickness = 2 }, sign)
	label(sign, { Size = UDim2.new(1, 0, 0.78, 0), Text = "BOUNTY BOARD", Font = Enum.Font.Bangers, TextColor3 = PAPER, TextStrokeTransparency = 0.4, ZIndex = 4 })
	label(sign, { Position = UDim2.fromScale(0, 0.72), Size = UDim2.fromScale(1, 0.24), Text = "HUNT THEM DOWN · GET PAID", Font = Enum.Font.GothamBold, TextColor3 = GOLD, ZIndex = 4 })
	local close = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 20), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = RED, Text = "X", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), ZIndex = 4 }, board)
	corner(close, 99)
	new("UIStroke", { Color = Color3.fromRGB(90, 15, 12), Thickness = 2 }, close)
	close.Activated:Connect(closeBoard)
	-- Header strip: cash, tabs, current bounty.
	local strip = new("Frame", { Position = UDim2.fromOffset(22, 78), Size = UDim2.new(1, -44, 0, 34), BackgroundColor3 = Color3.fromRGB(40, 26, 15), BackgroundTransparency = 0.25, ZIndex = 4 }, board)
	corner(strip, 8)
	local cashChip = new("Frame", { Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(86, 26), BackgroundColor3 = GOLD, ZIndex = 4 }, strip)
	corner(cashChip, 6)
	cashLabel = label(cashChip, { Size = UDim2.fromScale(1, 1), Text = "$0", Font = Enum.Font.Bangers, ZIndex = 4 })
	for i, name in ipairs({ "ALL", "PLAYERS", "NPCS", "CORPSE", "JOBS", "SHOP", "POST" }) do
		local x = 98 + (i - 1) * 53 + (i >= 5 and 6 or 0) -- a little gap before JOBS / SHOP / POST
		local tab = new("TextButton", { Position = UDim2.fromOffset(x, 4), Size = UDim2.fromOffset(50, 26), BackgroundColor3 = WOOD_DARK, Text = name, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = PAPER, ZIndex = 4 }, strip)
		corner(tab, 6)
		new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, tab)
		tab.Activated:Connect(function()
			filter = name
			fillGrid()
		end)
		tabs[name] = tab
	end
	huntingLabel = label(strip, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 2), Size = UDim2.fromOffset(150, 16), Text = "", TextColor3 = PAPER, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
	countLabel = label(strip, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 18), Size = UDim2.fromOffset(150, 12), Text = "", Font = Enum.Font.GothamBold, TextColor3 = PAPER_DARK, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
	grid = new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(22, 118), Size = UDim2.new(1, -44, 1, -136), ScrollBarThickness = 6, ScrollBarImageColor3 = PAPER_DARK, CanvasSize = UDim2.new(), ZIndex = 4 }, board)
	label(grid, { Name = "Empty", Position = UDim2.fromScale(0.08, 0.32), Size = UDim2.fromScale(0.84, 0.14), Text = "", TextColor3 = PAPER, Visible = false, ZIndex = 4 })

	-- The contract card (Accept / Decline) sits on its own layer above the
	-- board, so nothing on the board can cover it or swallow its clicks.
	local top = new("ScreenGui", { Name = "BountyConfirm", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 9 }, player:WaitForChild("PlayerGui"))
	confirmLayer = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Size = UDim2.fromScale(1, 1), Visible = false }, top)
	confirmLayer.Activated:Connect(function()
		confirmLayer.Visible = false
	end)
	confirm = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 470), BackgroundColor3 = PAPER }, confirmLayer)
	corner(confirm, 8)
	new("UIScale", { Scale = 1 }, confirm)
	new("UIStroke", { Color = BURNT, Thickness = 4 }, confirm)
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, PAPER_DARK), ColorSequenceKeypoint.new(0.4, PAPER), ColorSequenceKeypoint.new(1, PAPER_DARK) }), Rotation = 80 }, confirm)
	-- Fits small screens too.
	new("UISizeConstraint", { MaxSize = Vector2.new(380, 470) }, confirm)
	local body = new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, confirm)
	-- Header band like a stamped document.
	local head = new("Frame", { BackgroundColor3 = WOOD_DARK, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 54) }, body)
	corner(head, 8)
	new("Frame", { BackgroundColor3 = WOOD_DARK, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -8), Size = UDim2.new(1, 0, 0, 8) }, head)
	label(head, { Position = UDim2.fromOffset(16, 4), Size = UDim2.new(1, -32, 0, 32), Text = "BOUNTY CONTRACT", Font = Enum.Font.Bangers, TextColor3 = GOLD })
	label(head, { Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -32, 0, 14), Text = "WANTED · DEAD OR ALIVE", Font = Enum.Font.GothamBold, TextColor3 = PAPER })
	-- Danger pips (filled from the reward) under the photo.
	local pips = new("Frame", { Name = "Pips", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 212), Size = UDim2.fromOffset(100, 12) }, body)
	confirmPips = {}
	for i = 1, 5 do
		confirmPips[i] = new("Frame", { Name = "Pip" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, (i - 3) * 18, 0.5, 0), Size = UDim2.fromOffset(9, 9), Rotation = 45, BackgroundColor3 = PAPER_DARK }, pips)
	end
	-- Name (shrinks to fit, never cut off) and Stand.
	local who = label(body, { Name = "Who", Position = UDim2.fromOffset(18, 230), Size = UDim2.new(1, -36, 0, 30), Text = "", TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 12 }, who)
	local standLine = label(body, { Name = "Stand", Position = UDim2.fromOffset(18, 260), Size = UDim2.new(1, -36, 0, 16), Text = "", Font = Enum.Font.GothamBold, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 9 }, standLine)
	-- Reward on a red ribbon.
	local ribbon = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 284), Size = UDim2.fromOffset(190, 50), BackgroundColor3 = RED }, body)
	corner(ribbon, 6)
	new("UIStroke", { Color = RED:Lerp(Color3.new(0, 0, 0), 0.4), Thickness = 2 }, ribbon)
	confirmPay = label(ribbon, { Name = "Pay", Size = UDim2.fromScale(1, 1), Text = "", Font = Enum.Font.Bangers, TextColor3 = Color3.new(1, 1, 1), TextScaled = true })
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, ribbon)
	label(body, { Name = "Note", Position = UDim2.fromOffset(24, 340), Size = UDim2.new(1, -48, 0, 44), Text = "", Font = Enum.Font.GothamMedium, TextWrapped = true, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 9 }, body:FindFirstChild("Note"))
	local stamp = label(body, { Name = "Stamp", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(250, 70), Rotation = -14, Text = "ACCEPTED", Font = Enum.Font.Bangers, TextColor3 = RED, Visible = false, ZIndex = 5 })
	new("UIStroke", { Color = RED, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, stamp)
	local stampScale = new("UIScale", { Scale = 1 }, stamp)
	local function button(text, color, x)
		local b = new("TextButton", { Position = UDim2.new(x, 0, 1, -70), Size = UDim2.new(0.42, 0, 0, 50), BackgroundColor3 = color, Text = text, Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, body)
		corner(b, 8)
		new("UIStroke", { Color = color:Lerp(Color3.new(0, 0, 0), 0.45), Thickness = 2 }, b)
		new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, b)
		local s = new("UIScale", { Scale = 1 }, b)
		b.MouseEnter:Connect(function()
			TweenService:Create(s, FAST, { Scale = 1.08 }):Play()
		end)
		b.MouseLeave:Connect(function()
			TweenService:Create(s, SOFT, { Scale = 1 }):Play()
		end)
		return b
	end
	-- PUT A PRICE ON THEIR HEAD (players only).
	placeButton = new("TextButton", { Name = "Place", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 66), Size = UDim2.fromOffset(96, 58), BackgroundColor3 = GOLD, Text = "", AutoButtonColor = true, Visible = false, ZIndex = 3 }, body)
	corner(placeButton, 8)
	new("UIStroke", { Color = WOOD_DARK, Thickness = 2 }, placeButton)
	label(placeButton, { Name = "Top", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 22), Text = "+$100", Font = Enum.Font.Bangers, TextScaled = true, ZIndex = 3 })
	label(placeButton, { Position = UDim2.fromOffset(4, 28), Size = UDim2.new(1, -8, 0, 24), Text = "PUT A PRICE ON THEIR HEAD", Font = Enum.Font.GothamBlack, TextScaled = true, TextWrapped = true, ZIndex = 3 })
	placeButton.Activated:Connect(function()
		if confirmEntry and confirmEntry.Kind == "Player" then
			Remote:FireServer("Place", confirmEntry.Key)
			confirmLayer.Visible = false
		end
	end)
	local accepting = false
	button("ACCEPT", GREEN, 0.06).Activated:Connect(function()
		if accepting or not confirmEntry then
			return
		end
		accepting = true
		-- Thump an ACCEPTED stamp onto the contract, then go.
		stamp.Visible = true
		stampScale.Scale = 2.2
		TweenService:Create(stampScale, FAST, { Scale = 1 }):Play()
		local entry = confirmEntry
		task.delay(0.45, function()
			accepting = false
			Remote:FireServer("Accept", entry.Key)
			closeBoard()
		end)
	end)
	button("DECLINE", RED, 0.52).Activated:Connect(function()
		confirmLayer.Visible = false
	end)
end

---------------------------------------------------------------------------
-- Tracker, target marker, banner
---------------------------------------------------------------------------
local function targetModel()
	if not current then
		return nil
	end
	if current.Kind == "Player" then
		local p = Players:GetPlayerByUserId(current.UserId)
		return p and p.Character
	end
	if current.Kind == "Corpse" then
		return corpseHolder(current.Part) or corpseRelic(current.Part)
	end
	return current.Model
end

local function setMarker(model)
	local head = model and (model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	if not head then
		marker.Enabled = false
		return
	end
	marker.Adornee = head
	marker.Enabled = true
end

local function buildTracker()
	-- On the right side of the screen (the character card is top-left).
	tracker = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.42, 0), Size = UDim2.fromOffset(270, 88), BackgroundColor3 = PAPER, Visible = false }, gui)
	corner(tracker, 8)
	new("UIStroke", { Color = WOOD_DARK, Thickness = 3 }, tracker)
	local strip = new("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Size = UDim2.new(0, 6, 1, 0) }, tracker)
	corner(strip, 8)
	label(tracker, { Position = UDim2.fromOffset(88, 4), Size = UDim2.fromOffset(120, 18), Text = "BOUNTY", Font = Enum.Font.Bangers, TextColor3 = RED, TextXAlignment = Enum.TextXAlignment.Left })
	local trackWho = label(tracker, { Name = "Who", Position = UDim2.fromOffset(88, 22), Size = UDim2.fromOffset(150, 20), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true })
	new("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 8 }, trackWho)
	label(tracker, { Name = "Pay", Position = UDim2.fromOffset(88, 42), Size = UDim2.fromOffset(160, 20), Text = "", Font = Enum.Font.Bangers, TextColor3 = GREEN, TextXAlignment = Enum.TextXAlignment.Left })
	label(tracker, { Name = "Info", Position = UDim2.fromOffset(88, 64), Size = UDim2.fromOffset(170, 14), Text = "", Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left })
	local quit = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = RED, Text = "X", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1) }, tracker)
	corner(quit, 6)
	quit.Activated:Connect(function()
		Remote:FireServer("Abandon")
	end)

	marker = new("BillboardGui", { Size = UDim2.fromOffset(90, 70), StudsOffset = Vector3.new(0, 3.2, 0), AlwaysOnTop = true, LightInfluence = 0, Enabled = false }, gui)
	label(marker, { Size = UDim2.new(1, 0, 0, 22), Text = "TARGET", Font = Enum.Font.Bangers, TextColor3 = RED, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.new(1, 1, 1) })
	local arrow = new("Frame", { Name = "Arrow", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.fromOffset(22, 22), Rotation = 45, BackgroundColor3 = RED }, marker)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, arrow)

	banner = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(560, 80), Text = "", Font = Enum.Font.Bangers, TextColor3 = GOLD, TextStrokeTransparency = 0, Visible = false })
	new("UIScale", { Scale = 1 }, banner)
end

local function showActive(b)
	current = b
	tracker.Visible = true
	for _, c in ipairs(tracker:GetChildren()) do
		if c.Name == "Photo" then
			c:Destroy()
		end
	end
	local photo = photoFor(b, tracker)
	photo.Position = UDim2.fromOffset(14, 10)
	photo.Size = UDim2.fromOffset(68, 68)
	corner(photo, 6)
	tracker:FindFirstChild("Who").Text = string.upper(b.Name)
	tracker:FindFirstChild("Pay").Text = "$" .. b.Reward
	tracker.Position = UDim2.new(1, 290, 0.42, 0)
	TweenService:Create(tracker, FAST, { Position = UDim2.new(1, -12, 0.42, 0) }):Play()
end

local function clearActive()
	current = nil
	tracker.Visible = false
	marker.Enabled = false
end

local function showBanner(text, color)
	banner.Text = text
	banner.TextColor3 = color
	banner.Visible = true
	local scale = banner:FindFirstChildOfClass("UIScale")
	scale.Scale = 0.4
	TweenService:Create(scale, FAST, { Scale = 1 }):Play()
	task.delay(2.6, function()
		if banner.Text == text then
			banner.Visible = false
		end
	end)
end

function BountyUI.step()
	if stablePreview and stablePreview.Camera.Parent and dim and dim.Visible then
		stablePreview.Angle = stablePreview.Angle + 0.01
		local a = stablePreview.Angle
		stablePreview.Camera.CFrame = CFrame.lookAt(Vector3.new(math.sin(a) * 13, 2, math.cos(a) * 13), Vector3.new(0, 0.2, -0.6))
	end
	if #shopBars > 0 then
		stepShopBars()
	end
	if jobsTimer and jobsTimer.Parent then
		local left = math.max(0, jobsUntil - workspace:GetServerTimeNow())
		jobsTimer:FindFirstChild("Text").Text = string.format("NEW JOBS IN %d:%02d", math.floor(left / 60), math.floor(left % 60))
	end
	if cashLabel and dim and dim.Visible then
		cashLabel.Text = cashText()
	end
	if not current or not tracker then
		return
	end
	local model = targetModel()
	setMarker(model)
	local mine = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local theirs = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	local left = math.max(0, (current.Expires or 0) - workspace:GetServerTimeNow())
	local where = (mine and theirs) and (math.floor((theirs.Position - mine.Position).Magnitude) .. " studs") or "respawning..."
	-- A target sneaking far away is lost: no distance, no marker.
	local sneak = TuskConfig.Sneak or {}
	if model and model:GetAttribute("TuskSneaking") and mine and theirs and (theirs.Position - mine.Position).Magnitude > (sneak.HiddenFromBounty or 30) then
		where = "HIDDEN"
		marker.Enabled = false
	end
	-- Smoke bomb (bounty-board shop): no marker, no distance while it lasts.
	if model and (model:GetAttribute("SmokedUntil") or 0) > workspace:GetServerTimeNow() then
		where = "LOST IN SMOKE"
		marker.Enabled = false
	end
	tracker:FindFirstChild("Info").Text = string.format("%s  ·  %d:%02d", where, math.floor(left / 60), math.floor(left % 60))
	if marker.Enabled then
		marker:FindFirstChild("Arrow").Position = UDim2.new(0.5, 0, 0, 26 + math.sin(os.clock() * 5) * 4)
	end
end

function BountyUI.init()
	Remote = Net.get("Bounty")
	gui = new("ScreenGui", { Name = "BountyBoard", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 8 }, player:WaitForChild("PlayerGui"))
	buildBoard()
	buildTracker()
	Remote.OnClientEvent:Connect(function(kind, data)
		data = typeof(data) == "table" and data or {}
		if kind == "Open" then
			openBoard(data)
		elseif kind == "Active" then
			showActive(data)
			showBanner("BOUNTY ACCEPTED: " .. string.upper(data.Name or ""), PAPER)
			Cinematic.title("THE HUNT BEGINS", data.Name or "", GOLD, "$" .. tostring(data.Reward or 0) .. " · DEAD OR ALIVE")
		elseif kind == "Complete" and data.Price then
			showBanner("PRICE ON THEIR HEAD!  +$" .. tostring(data.Reward), GOLD)
		elseif kind == "Complete" then
			clearActive()
			showBanner("BOUNTY CLAIMED!  +$" .. tostring(data.Reward), GOLD)
			Cinematic.title("BOUNTY CLAIMED", "+$" .. tostring(data.Reward), GOLD, data.Name or "")
		elseif kind == "Refresh" then
			lastList = data.Bounties or lastList
			lastJobs, lastShop, jobsUntil = data.Jobs or lastJobs, data.Shop or lastShop, data.JobsUntil or jobsUntil
			lastStable = data.Stable or lastStable
			lastTargets = data.Targets or lastTargets
			cashLabel.Text = cashText()
			if dim.Visible then
				fillGrid()
			end
		elseif kind == "JobDone" then
			showBanner("JOB DONE!  +$" .. tostring(data.Reward), GREEN:Lerp(Color3.new(1, 1, 1), 0.4))
		elseif kind == "Bought" then
			showBanner("BOUGHT: " .. tostring(data.Name), GOLD)
		elseif kind == "Placed" then
			showBanner("$" .. tostring(data.Total) .. " ON " .. string.upper(tostring(data.Name)) .. "'S HEAD", GOLD)
		elseif kind == "Warned" then
			showBanner(string.upper(tostring(data.By)) .. " PUT A PRICE ON YOUR HEAD!  ($" .. tostring(data.Total) .. ")", Color3.fromRGB(255, 140, 120))
		elseif kind == "Posted" then
			local amount, name = tostring(data.Amount), string.upper(tostring(data.Name))
			if data.Mine then
				showBanner((data.Self and "YOU PUT $" .. amount .. " ON YOUR OWN HEAD!") or ("BOUNTY POSTED: $" .. amount .. " ON " .. name), GOLD)
			elseif data.You then
				showBanner(string.upper(tostring(data.By)) .. " POSTED $" .. amount .. " ON YOUR HEAD!", Color3.fromRGB(255, 140, 120))
			elseif data.Self then
				showBanner(string.upper(tostring(data.By)) .. " PUT $" .. amount .. " ON THEIR OWN HEAD!", GOLD)
			else
				showBanner(string.upper(tostring(data.By)) .. " POSTED $" .. amount .. " ON " .. name, PAPER)
			end
		elseif kind == "Refunded" then
			showBanner("$" .. tostring(data.Amount) .. " REFUNDED (" .. string.upper(tostring(data.Name)) .. " IS GONE)", PAPER)
		elseif kind == "Denied" then
			showBanner(string.upper(tostring(data.Reason or "CAN'T DO THAT")), Color3.fromRGB(255, 160, 140))
		elseif kind == "Lost" then
			clearActive()
			showBanner(data.Reason or "BOUNTY LOST", Color3.fromRGB(255, 140, 120))
		elseif kind == "Cleared" then
			clearActive()
		end
	end)
	RunService.RenderStepped:Connect(BountyUI.step)
end

return BountyUI
end

-- ======================================================================
-- MODULE: CameraFX
-- ======================================================================
__modules["CameraFX"] = function()
--[[
	CameraFX  (StarterPlayerScripts.SpinClient.CameraFX)
	Screen-space feedback: camera shake, FOV punch, anime speed lines and
	short impact frames. All of it respects VFXQuality and cleans up.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local VFXQuality = __require("VFXQuality")
local VFXLib = __require("VFXLib")

local CameraFX = {}

local player = Players.LocalPlayer
local shakes = {}
local fovOffset = 0
local appliedFov = 0

RunService:BindToRenderStep("SpinCameraFX", Enum.RenderPriority.Camera.Value + 1, function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	local offset = Vector3.new()
	for i = #shakes, 1, -1 do
		local s = shakes[i]
		local a = (now - s.Start) / s.Duration
		if a >= 1 then
			table.remove(shakes, i)
		else
			local strength = s.Intensity * (1 - a) * (1 - a)
			local t = now * 32
			offset = offset
				+ Vector3.new(
					math.noise(t, s.Seed) * strength,
					math.noise(s.Seed, t) * strength,
					math.noise(t, t + s.Seed) * strength * 0.5
				)
		end
	end
	if offset.Magnitude > 0 then
		camera.CFrame = camera.CFrame * CFrame.new(offset) * CFrame.Angles(0, 0, offset.X * 0.02)
	end
	-- Apply FOV punch as a delta so other systems that set FOV still work.
	if fovOffset ~= appliedFov then
		camera.FieldOfView = camera.FieldOfView + (fovOffset - appliedFov)
		appliedFov = fovOffset
	end
end)

function CameraFX.shake(intensity, duration)
	intensity = intensity * VFXQuality.get().ShakeScale
	if intensity <= 0 then
		return
	end
	table.insert(shakes, { Start = os.clock(), Duration = duration or 0.35, Intensity = intensity, Seed = math.random() * 100 })
end

-- Shake scaled by distance from the camera.
function CameraFX.shakeAt(position, intensity, radius)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local d = (camera.CFrame.Position - position).Magnitude
	local falloff = math.clamp(1 - d / (radius or 80), 0, 1)
	if falloff > 0 then
		CameraFX.shake(intensity * falloff, 0.35)
	end
end

local fovJob
function CameraFX.fovPunch(amount, duration)
	if not VFXQuality.get().ScreenEffects then
		return
	end
	VFXLib.cancel(fovJob)
	fovJob = VFXLib.animate(duration or 0.35, function(a)
		fovOffset = amount * (1 - VFXLib.easeOut(a))
	end, function()
		fovOffset = 0
	end)
end

-- Held FOV offset (e.g. slight zoom while charging). nil clears.
function CameraFX.setFovHold(amount)
	if not VFXQuality.get().ScreenEffects then
		amount = 0
	end
	VFXLib.cancel(fovJob)
	fovJob = nil
	fovOffset = amount or 0
end

local function screenGui(name)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function CameraFX.speedLines(duration, color)
	if not VFXQuality.get().ScreenEffects then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local edge = math.sqrt(viewport.X * viewport.X + viewport.Y * viewport.Y) / 2
	local gui = screenGui("SpinSpeedLines")
	local lines = {}
	local count = VFXLib.particleCount(28)
	for i = 1, count do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = color or Color3.new(1, 1, 1)
		line.Parent = gui
		lines[i] = {
			Frame = line,
			Angle = (i / count) * math.pi * 2 + math.random() * 0.15,
			Inner = edge * (0.45 + math.random() * 0.25), -- where the line starts
			Thickness = math.random(1, 3),
		}
	end
	VFXLib.animate(duration or 0.3, function(a)
		for _, l in ipairs(lines) do
			-- Each line runs from its inner radius out past the screen edge,
			-- creeping inward slightly as the effect plays.
			local inner = l.Inner * (1 - 0.15 * a)
			local length = edge * 1.05 - inner
			local mid = inner + length / 2
			l.Frame.Size = UDim2.fromOffset(length, l.Thickness)
			l.Frame.Position = UDim2.new(0.5, math.cos(l.Angle) * mid, 0.5, math.sin(l.Angle) * mid)
			l.Frame.Rotation = math.deg(l.Angle)
			l.Frame.BackgroundTransparency = math.min(1, 0.2 + a * 0.8 + math.random() * 0.15)
		end
	end, function()
		gui:Destroy()
	end)
end

-- Two-frame high-contrast flash. Brief and subtle (photosensitivity-safe).
function CameraFX.impactFrame(tint)
	if not VFXQuality.get().ImpactFrames then
		return
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SpinImpactFrame"
	cc.Contrast = 0.6
	cc.Saturation = -0.6
	cc.TintColor = tint or Color3.new(1, 0.95, 0.8)
	cc.Brightness = 0.08
	cc.Parent = Lighting
	VFXLib.animate(0.12, function(a)
		cc.Contrast = 0.6 * (1 - a)
		cc.Saturation = -0.6 * (1 - a)
		cc.Brightness = 0.08 * (1 - a)
	end, function()
		cc:Destroy()
	end)
end

return CameraFX
end

-- ======================================================================
-- MODULE: CharacterCard
-- ======================================================================
__modules["CharacterCard"] = function()
--[[
	CharacterCard  (StarterPlayerScripts.SpinClient.UI.CharacterCard)

	Top-left character card, in the bounty-board style, kept clean:
	  * a framed wooden board (planks, metal corner brackets) that lifts a
	    little and turns its rim gold when you hover it
	  * portrait in a parchment mat with a nail on top: your uploaded image
	    (TuskConfig.Character.PortraitImage), or a live 3D view of your own
	    avatar, on a backing in your character's Roster colour
	  * a straight parchment NAME PLATE (Bangers ink)
	  * the Stand on a dark inset with a strip of the Stand's colour
	  * Tusk's four Act pips (Johnny only; for everyone else the health bar
	    moves up into their place)
	  * a wood-framed HEALTH bar: "HP" on the left, numbers on the right
	  * a gold "CHARACTERS ▼" tab hanging under the card
	Pops and flashes the planks in the Act colour when Tusk evolves.

	CHARACTER LIST (tap the card or its tab): a wooden board, "CHOOSE YOUR
	FIGHTER" and how many there are, a SEARCH box (name or Stand), then one
	parchment row per character: a strip and a round badge in the
	character's colour with their initials, their name, their Stand, and a
	status pill (green PLAYING, red SELECT, grey NOT INSTALLED / IN
	DEVELOPMENT). Rows lighten, take their character's colour as an outline
	and lift on hover; the whole row is the button. The one you're playing
	is pinned to the top.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local VFXLib = __require("VFXLib")
local UITheme = __require("UITheme")
local C = UITheme.C
local F = UITheme.Font

local CharacterCard = {}

local player = Players.LocalPlayer
local GOLD = C.GOLD
local PIP_OFF = Color3.fromRGB(58, 40, 26)
local FADED_INK = Color3.fromRGB(150, 122, 96)

local CARD_W, CARD_H = 330, 100
local gui, card, portrait, viewport, photo, nameLabel, standLabel, standStrip, pipRow, pips, hpBar, hpFill, hpText, scale, arrow, flash, cardStroke, tab
local dropdown, dropdownList, rosterRows, searchBox, countLabel, emptyLabel
-- Declared up here so init() can call them (they are defined further down).
local buildDropdown, refreshDropdown, applyFilter
local shownAct
local open = false
local Net = __require("Net")

local function corner(p, r)
	return UITheme.corner(p, r)
end

local function stroke(p, color, t)
	return UITheme.stroke(p, color, t)
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextStrokeTransparency = 0.4
	l.TextStrokeColor3 = C.SHADOW
	l.ZIndex = 3
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.ZIndex = 3
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function sizeLimit(l, max, min)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = max
	c.MinTextSize = min or 8
	c.Parent = l
	return c
end

local function tweenTo(obj, info, props)
	TweenService:Create(obj, info, props):Play()
end

-- Parchment without UITheme.paper's stroke (rows need their own outline).
local function parchment(f, rotation)
	f.BackgroundColor3 = C.PAPER
	f.BackgroundTransparency = 0
	f.BorderSizePixel = 0
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.PAPER_DARK), ColorSequenceKeypoint.new(0.4, C.PAPER), ColorSequenceKeypoint.new(1, C.PAPER_DARK) })
	g.Rotation = rotation or 70
	g.Parent = f
end

local function nail(parent, pos, z)
	local n = frame(parent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(7, 7), BackgroundColor3 = C.NAIL, ZIndex = z or 5 })
	corner(n, 99)
	stroke(n, C.STEEL_DARK, 1)
	return n
end

-- Live 3D portrait of your own avatar (head and shoulders).
local function refreshViewport(character)
	if not viewport then
		return
	end
	viewport:ClearAllChildren()
	if not character then
		return
	end
	local head = character:WaitForChild("Head", 5)
	if not head then
		return
	end
	local wasArchivable = character.Archivable
	character.Archivable = true
	local ok, clone = pcall(function()
		return character:Clone()
	end)
	character.Archivable = wasArchivable
	if not ok or not clone then
		return
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("ForceField") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	clone.Parent = world
	local cloneHead = clone:FindFirstChild("Head")
	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	if cloneHead then
		local h = cloneHead.CFrame
		camera.CFrame = CFrame.lookAt((h * CFrame.new(-0.9, 0.1, -3.6)).Position, h.Position - Vector3.new(0, 0.35, 0))
	end
end

local function buildPips(parent)
	pips = {}
	pipRow = frame(parent, { BackgroundTransparency = 1, Position = UDim2.fromOffset(102, 60), Size = UDim2.fromOffset(124, 8) })
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 5)
	layout.Parent = pipRow
	for i = 1, 4 do
		local pip = frame(pipRow, { Size = UDim2.fromOffset(26, 8), BackgroundColor3 = PIP_OFF })
		corner(pip, 4)
		stroke(pip, C.BRASS, 1).Transparency = 0.2
		pips[i] = pip
	end
end

-- Health sits under the pips (Johnny), or moves up into their place.
local function layoutHealth(withPips)
	if hpBar then
		hpBar.Position = UDim2.fromOffset(102, withPips and 72 or 64)
		hpBar.Size = UDim2.new(1, -112, 0, withPips and 18 or 24)
	end
	if pipRow then
		pipRow.Visible = withPips
	end
end

function CharacterCard.init()
	local config = TuskConfig.Character
	gui = Instance.new("ScreenGui")
	gui.Name = "CharacterCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The card: a framed wooden board with metal corner brackets.
	card = Instance.new("Frame")
	card.Name = "Card"
	card.Position = UDim2.fromOffset(12, 10)
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.Parent = gui
	local planks = UITheme.wood(card, { Planks = 3, Border = 5, Radius = 10, Brackets = true, BracketSize = 12, Nails = false })
	cardStroke = card:FindFirstChildOfClass("UIStroke")
	scale = Instance.new("UIScale")
	scale.Parent = card
	-- Evolve flash over the planks (see CharacterCard.pop).
	flash = frame(planks, { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = GOLD, BackgroundTransparency = 1, ZIndex = 2 })

	-- Portrait: a parchment mat, the picture on a Roster-colour backing.
	local mat = frame(card, { Name = "Portrait", Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(84, 82) })
	UITheme.paper(mat, { Radius = 6, Stroke = 2 })
	photo = frame(mat, { Name = "Photo", Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10), BackgroundColor3 = (TuskConfig.Roster and TuskConfig.Roster[1] and TuskConfig.Roster[1].Color) or GOLD, ClipsDescendants = true })
	corner(photo, 4)
	stroke(photo, C.INK, 1.5)
	local photoShade = Instance.new("UIGradient")
	photoShade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(95, 80, 70))
	photoShade.Rotation = 90
	photoShade.Parent = photo
	if config.PortraitImage ~= "" then
		portrait = Instance.new("ImageLabel")
		portrait.BackgroundTransparency = 1
		portrait.Size = UDim2.fromScale(1, 1)
		portrait.Image = config.PortraitImage
		portrait.ScaleType = Enum.ScaleType.Crop
		portrait.ZIndex = 3
		portrait.Parent = photo
	else
		viewport = Instance.new("ViewportFrame")
		viewport.BackgroundTransparency = 1
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.Ambient = Color3.fromRGB(170, 160, 150)
		viewport.LightColor = Color3.fromRGB(255, 240, 220)
		viewport.LightDirection = Vector3.new(-1, -1, -1)
		viewport.ZIndex = 3
		viewport.Parent = photo
	end
	nail(mat, UDim2.new(0.5, 0, 0, 1), 5)

	-- Name plate: a straight parchment strip, the name in Bangers ink.
	local plate = frame(card, { Name = "NamePlate", Position = UDim2.fromOffset(102, 9), Size = UDim2.new(1, -112, 0, 28) })
	UITheme.paper(plate, { Radius = 5, Stroke = 2 })
	nameLabel = label(plate, {
		Position = UDim2.fromOffset(8, 1),
		Size = UDim2.new(1, -16, 1, -2),
		Font = F.Title,
		TextScaled = true, -- long names shrink to fit
		TextColor3 = C.INK,
		TextStrokeTransparency = 1,
		Text = config.Name,
	})
	sizeLimit(nameLabel, 24, 12)

	-- Stand: a dark inset with a strip of the Stand's colour.
	local inset = frame(card, { Name = "StandInset", Position = UDim2.fromOffset(102, 40), Size = UDim2.new(1, -112, 0, 17), BackgroundColor3 = C.SHADOW, BackgroundTransparency = 0.25 })
	corner(inset, 4)
	standStrip = frame(inset, { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Color3.fromRGB(200, 220, 255) })
	corner(standStrip, 4)
	standLabel = label(inset, {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -14, 1, 0),
		Font = F.Heavy,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(200, 220, 255),
		TextStrokeTransparency = 0.3,
		Text = config.Title,
	})
	sizeLimit(standLabel, 12, 8)
	buildPips(card)

	-- Health: a wood-framed bar, "HP" on the left and the numbers on the right.
	hpBar, hpFill = UITheme.bar(card, Color3.fromRGB(90, 220, 120), { Name = "Health", ZIndex = 3 })
	label(hpBar, { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0, 30, 1, 0), Font = F.Heavy, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.1, Text = "HP", ZIndex = 5 })
	hpText = label(hpBar, {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -8, 1, 0),
		Font = F.Heavy,
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
		ZIndex = 5,
	})
	layoutHealth(true)

	-- A gold tab hanging under the card: opens the character list.
	tab = frame(gui, { Name = "CharactersTab", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(12 + CARD_W - 14, 10 + CARD_H - 3), Size = UDim2.fromOffset(122, 22), BackgroundColor3 = GOLD, ZIndex = 2 })
	corner(tab, 6)
	stroke(tab, C.WOOD_EDGE, 2)
	arrow = label(tab, {
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.new(1, 0, 1, -2),
		Font = F.Title,
		TextSize = 15,
		TextColor3 = C.INK,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "CHARACTERS  ▼",
		ZIndex = 3,
	})

	-- The whole card (and the tab) open the character list.
	local function hitbox(parent)
		local hit = Instance.new("TextButton")
		hit.Name = "OpenCharacters"
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 8
		hit.Parent = parent
		hit.Activated:Connect(CharacterCard.toggle)
		hit.MouseEnter:Connect(function()
			tweenTo(scale, UITheme.FAST, { Scale = 1.02 })
			if cardStroke then
				cardStroke.Color = GOLD
			end
			tab.BackgroundColor3 = C.GLOW
		end)
		hit.MouseLeave:Connect(function()
			tweenTo(scale, UITheme.SOFT, { Scale = 1 })
			if cardStroke then
				cardStroke.Color = C.WOOD_EDGE
			end
			tab.BackgroundColor3 = GOLD
		end)
		hit.MouseButton1Down:Connect(function()
			tweenTo(scale, UITheme.SOFT, { Scale = 0.98 })
		end)
		hit.MouseButton1Up:Connect(function()
			tweenTo(scale, UITheme.FAST, { Scale = 1 })
		end)
		return hit
	end
	hitbox(card)
	hitbox(tab)
	buildDropdown()

	local function onCharacter(character)
		task.defer(refreshViewport, character)
	end
	game:GetService("RunService").RenderStepped:Connect(CharacterCard.step)
	player.CharacterAdded:Connect(onCharacter)
	player.CharacterAppearanceLoaded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

---------------------------------------------------------------------------
-- The character list
---------------------------------------------------------------------------
local LIST_W = 360
local ROW_H = 52
local HEAD_H = 84 -- title, count and search box
local dropdownHeight = 0
local ROW_BG = C.PAPER
local ROW_HOVER = Color3.fromRGB(255, 238, 204)
local GREEN = C.GREEN
local RED = C.RED
local GREY = Color3.fromRGB(128, 112, 96)
local REST_EDGE = C.BURNT

-- "JOHNNY JOESTAR" -> "JJ", "SANDMAN" -> "S".
local function initials(name)
	local out = ""
	for word in string.gmatch(name, "%S+") do
		if #out < 2 and word:sub(1, 1):match("%w") then
			out = out .. word:sub(1, 1)
		end
	end
	return out
end

local function tween(duration, step)
	VFXLib.animate(duration, function(a)
		step(VFXLib.easeOut(a))
	end)
end

-- A row's outline: burnt parchment edge at rest, the character's colour
-- when hovered or playing.
local function setOutline(info, on)
	info.Outline.Color = on and info.Entry.Color or REST_EDGE
	info.Outline.Thickness = on and 3 or 1.5
	info.Outline.Transparency = on and 0 or 0.35
end

function buildDropdown()
	dropdown = Instance.new("Frame")
	dropdown.Name = "CharacterList"
	dropdown.Position = UDim2.fromOffset(12, 10 + CARD_H + 26)
	dropdown.Size = UDim2.fromOffset(LIST_W, 0)
	dropdown.ClipsDescendants = true
	dropdown.Visible = false
	dropdown.Parent = gui
	UITheme.wood(dropdown, { Planks = 6, Border = 5, Radius = 10, Nails = true, Brackets = true, BracketSize = 12 })

	-- Header: title, how many, a search box (stays put while the list scrolls).
	label(dropdown, { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -130, 0, 28), Font = F.Title, TextSize = 26, TextColor3 = C.PAPER, TextStrokeTransparency = 0.2, Text = "CHOOSE YOUR FIGHTER" })
	local countChip = frame(dropdown, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 11), Size = UDim2.fromOffset(96, 22), BackgroundColor3 = C.SHADOW, BackgroundTransparency = 0.25 })
	corner(countChip, 11)
	countLabel = label(countChip, { Size = UDim2.fromScale(1, 1), Font = F.Heavy, TextSize = 11, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 1, Text = "" })
	local searchMat = frame(dropdown, { Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 30) })
	UITheme.paper(searchMat, { Radius = 8, Stroke = 2 })
	label(searchMat, { Position = UDim2.fromOffset(9, 0), Size = UDim2.fromOffset(20, 30), Font = F.Heavy, TextSize = 14, TextColor3 = C.BURNT, TextStrokeTransparency = 1, Text = "⌕" })
	searchBox = Instance.new("TextBox")
	searchBox.Name = "Search"
	searchBox.BackgroundTransparency = 1
	searchBox.Position = UDim2.fromOffset(30, 0)
	searchBox.Size = UDim2.new(1, -38, 1, 0)
	searchBox.Font = F.Body
	searchBox.TextSize = 14
	searchBox.TextColor3 = C.INK
	searchBox.PlaceholderText = "Search a name or a Stand..."
	searchBox.PlaceholderColor3 = FADED_INK
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.ClearTextOnFocus = false
	searchBox.Text = ""
	searchBox.ZIndex = 4
	searchBox.Parent = searchMat
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		applyFilter()
	end)
	frame(dropdown, { Position = UDim2.fromOffset(14, HEAD_H - 4), Size = UDim2.new(1, -28, 0, 2), BackgroundColor3 = C.WOOD_EDGE, BackgroundTransparency = 0.3 })

	dropdownList = Instance.new("ScrollingFrame")
	dropdownList.BackgroundTransparency = 1
	dropdownList.BorderSizePixel = 0
	dropdownList.Position = UDim2.fromOffset(0, HEAD_H)
	dropdownList.Size = UDim2.new(1, 0, 1, -HEAD_H - 4)
	dropdownList.CanvasSize = UDim2.new()
	dropdownList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	dropdownList.ScrollBarThickness = 5
	dropdownList.ScrollingDirection = Enum.ScrollingDirection.Y
	dropdownList.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	dropdownList.ScrollBarImageColor3 = GOLD
	dropdownList.ZIndex = 3
	dropdownList.Parent = dropdown
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = dropdownList
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = dropdownList
	emptyLabel = label(dropdownList, { LayoutOrder = 9999, Size = UDim2.new(1, 0, 0, 40), Font = F.Body, TextSize = 13, TextColor3 = C.PAPER, TextXAlignment = Enum.TextXAlignment.Center, Text = "Nobody by that name.", Visible = false })

	rosterRows = {}
	for order, entry in ipairs(TuskConfig.Roster or {}) do
		-- The whole row is the button: a parchment strip.
		local row = Instance.new("TextButton")
		row.Name = entry.Id
		row.LayoutOrder = order
		row.Text = ""
		row.AutoButtonColor = false
		row.Size = UDim2.new(1, 0, 0, ROW_H)
		row.ZIndex = 3
		row.Parent = dropdownList
		parchment(row, 80)
		corner(row, 8)
		local outline = stroke(row, REST_EDGE, 1.5)
		outline.Transparency = 0.35
		local rowScale = Instance.new("UIScale")
		rowScale.Parent = row
		-- A strip of the character's colour down the left edge.
		local strip = frame(row, { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = entry.Color })
		corner(strip, 8)

		-- Round badge with their initials.
		local badge = frame(row, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = entry.Color })
		corner(badge, 99)
		stroke(badge, C.WOOD_EDGE, 2)
		local shade = Instance.new("UIGradient")
		shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
		shade.Rotation = 90
		shade.Parent = badge
		label(badge, { Size = UDim2.fromScale(1, 1), Font = F.Title, TextSize = 19, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2, Text = initials(entry.Name) })

		-- Name and Stand shrink to fit instead of being cut off.
		local nameText = label(row, { Position = UDim2.fromOffset(60, 7), Size = UDim2.new(1, -158, 0, 22), Font = F.Title, TextScaled = true, TextStrokeTransparency = 1, TextColor3 = entry.Available and C.INK or FADED_INK, Text = entry.Name })
		sizeLimit(nameText, 20, 11)
		local standText = label(row, { Position = UDim2.fromOffset(60, 30), Size = UDim2.new(1, -158, 0, 14), Font = F.Heavy, TextScaled = true, TextStrokeTransparency = 1, TextColor3 = entry.Color:Lerp(Color3.new(0, 0, 0), 0.45), Text = entry.Stand })
		sizeLimit(standText, 11, 7)

		-- Status pill.
		local status = label(row, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(84, 24),
			Font = F.Title,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.7,
			BackgroundTransparency = 0,
			BackgroundColor3 = GREY,
			Text = entry.Available and "SELECT" or "IN DEVELOPMENT",
		})
		corner(status, 12)
		local statusStroke = stroke(status, C.WOOD_EDGE, 1.5)
		local statusPad = Instance.new("UIPadding")
		statusPad.PaddingTop = UDim.new(0, 4)
		statusPad.PaddingBottom = UDim.new(0, 3)
		statusPad.PaddingLeft = UDim.new(0, 6)
		statusPad.PaddingRight = UDim.new(0, 6)
		statusPad.Parent = status
		sizeLimit(status, 16, 8)

		local info = { Row = row, Order = order, Status = status, StatusStroke = statusStroke, Entry = entry, Outline = outline, Name = nameText, Selectable = false, Playing = false }
		rosterRows[entry.Id] = info

		-- Hover: the row lightens, lifts, and takes the character's colour as its outline.
		local function hover(on)
			local from = row.BackgroundColor3
			local to = on and ROW_HOVER or ROW_BG
			tween(0.12, function(a)
				row.BackgroundColor3 = from:Lerp(to, a)
			end)
			setOutline(info, on or info.Playing)
			tweenTo(rowScale, on and UITheme.FAST or UITheme.SOFT, { Scale = on and 1.015 or 1 })
		end
		row.MouseEnter:Connect(function()
			hover(true)
		end)
		row.MouseLeave:Connect(function()
			hover(false)
		end)
		row.Activated:Connect(function()
			if not info.Selectable then
				return
			end
			-- A little press bounce, then ask the server and close.
			tween(0.15, function(a)
				status.Size = UDim2.fromOffset(84 - 8 * math.sin(a * math.pi), 24 - 4 * math.sin(a * math.pi))
			end)
			Net.get("TuskRequest"):FireServer("Character", entry.Id)
			task.delay(0.15, function()
				if open then
					CharacterCard.toggle()
				end
			end)
		end)
	end
	applyFilter()
end

-- Search: show only rows whose name or Stand contains the text.
function applyFilter()
	if not rosterRows then
		return
	end
	local q = searchBox and string.lower((searchBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")) or ""
	local shown, total = 0, 0
	for _, info in pairs(rosterRows) do
		total = total + 1
		local hay = string.lower(info.Entry.Name .. " " .. info.Entry.Stand .. " " .. info.Entry.Id)
		local match = q == "" or string.find(hay, q, 1, true) ~= nil
		info.Row.Visible = match
		if match then
			shown = shown + 1
		end
	end
	if emptyLabel then
		emptyLabel.Visible = shown == 0
	end
	if countLabel then
		countLabel.Text = q == "" and (total .. " FIGHTERS") or (shown .. " OF " .. total)
	end
end

-- Which characters the server can play (the others' scripts aren't installed).
local function installedSet()
	local text = game:GetService("ReplicatedStorage"):GetAttribute("SpinInstalledCharacters")
	if type(text) ~= "string" then
		return nil -- not known yet: treat everyone as installed
	end
	local set = {}
	for id in string.gmatch(text, "[^,]+") do
		set[id] = true
	end
	return set
end

function refreshDropdown(act)
	if not dropdown then
		return
	end
	-- Each row: PLAYING (green), SELECT (red), NOT INSTALLED (grey: that
	-- character's _Server/_Client scripts aren't in the game) or IN DEVELOPMENT.
	local current = act and Registry.characterOf(act)
	local installed = installedSet()
	for id, row in pairs(rosterRows) do
		local playing = current == id
		local missing = installed ~= nil and not installed[id]
		row.Playing = playing
		if row.Entry.Available then
			row.Status.Text = playing and "PLAYING" or (missing and "NOT INSTALLED" or "SELECT")
			row.Status.BackgroundColor3 = playing and GREEN or (missing and GREY or RED)
			row.Status.TextColor3 = missing and Color3.fromRGB(228, 216, 200) or Color3.new(1, 1, 1)
			row.Selectable = not playing and not missing
		end
		row.StatusStroke.Color = row.Status.BackgroundColor3:Lerp(Color3.new(0, 0, 0), 0.5)
		setOutline(row, playing)
		row.Name.TextColor3 = (row.Entry.Available and not missing) and C.INK or FADED_INK
		row.Row.LayoutOrder = playing and 0 or row.Order
	end
	applyFilter()
end

function CharacterCard.toggle()
	if not dropdown then
		return
	end
	open = not open
	local rows = #(TuskConfig.Roster or {})
	local full = HEAD_H + 16 + rows * (ROW_H + 6)
	-- About five rows (never more than 60% of the screen); the rest scrolls.
	local screenH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 600
	local target = math.min(full, HEAD_H + 16 + 5.4 * (ROW_H + 6), math.max(220, screenH * 0.6))
	refreshDropdown(shownAct)
	if open then
		dropdown.Visible = true
		dropdownList.CanvasPosition = Vector2.new()
	elseif searchBox then
		searchBox.Text = ""
	end
	arrow.Text = open and "CLOSE  ▲" or "CHARACTERS  ▼"
	local from = dropdownHeight
	local to = open and target or 0
	VFXLib.animate(0.22, function(a)
		dropdownHeight = from + (to - from) * VFXLib.easeOut(a)
		dropdown.Size = UDim2.fromOffset(LIST_W, dropdownHeight)
	end, function()
		if not open then
			dropdown.Visible = false
		end
	end)
end

function CharacterCard.pop(color)
	-- The board bounces and its planks flash in the Act colour.
	flash.BackgroundColor3 = color
	if cardStroke then
		cardStroke.Color = color
	end
	VFXLib.animate(0.5, function(a)
		scale.Scale = 1 + 0.1 * math.sin(a * math.pi)
		flash.BackgroundTransparency = 0.35 + 0.65 * a
	end, function()
		scale.Scale = 1
		flash.BackgroundTransparency = 1
		if cardStroke then
			cardStroke.Color = C.WOOD_EDGE
		end
	end)
end

function CharacterCard.step()
	if not card then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local frac = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		hpFill.Size = UDim2.fromScale(frac, 1)
		hpFill.BackgroundColor3 = Color3.fromRGB(220, 70, 60):Lerp(Color3.fromRGB(90, 220, 120), frac)
		hpText.Text = math.ceil(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth)
	end
	local act = character and character:GetAttribute("TuskAct")
	if act ~= shownAct then
		local evolved = shownAct ~= nil and act ~= nil and act > shownAct
		shownAct = act
		local info = act and Registry.get(act)
		local who = act ~= nil and Registry.characterOf(act) or "Johnny"
		local isTusk = who == "Johnny" -- (only Tusk has Act pips / the evolve pop)
		-- Name plate follows the character (from TuskConfig.Roster).
		for _, entry in ipairs(TuskConfig.Roster or {}) do
			if entry.Id == who then
				nameLabel.Text = entry.Name
				photo.BackgroundColor3 = entry.Color
			end
		end
		if info and info.CardTitle then
			standLabel.Text = info.CardTitle
		else
			standLabel.Text = info and ("STAND  ·  " .. info.Name) or TuskConfig.Character.Title
		end
		local theme = info and info.Theme.Primary or Color3.fromRGB(200, 220, 255)
		standLabel.TextColor3 = theme:Lerp(Color3.new(1, 1, 1), 0.25)
		standStrip.BackgroundColor3 = theme
		for i, pip in ipairs(pips) do
			local on = act ~= nil and i <= act
			local t = Registry.get(i) and Registry.get(i).Theme.Primary or GOLD
			pip.BackgroundColor3 = on and t or PIP_OFF
		end
		layoutHealth(isTusk)
		if not isTusk then
			evolved = false
		end
		if evolved and info then
			CharacterCard.pop(info.Theme.Primary)
		end
		refreshDropdown(act)
	end
end

return CharacterCard
end

-- ======================================================================
-- MODULE: Cinematic
-- ======================================================================
__modules["Cinematic"] = function()
--[[
	Cinematic  (StarterPlayerScripts.SpinClient.Cinematic)

	Makes the whole game feel more like a film. All client-side, and scaled
	by the VFX setting (Low / Medium / High). Numbers: TuskConfig.Cinematic.
	  * GRADE: a film look on top of the map's own lighting: a touch more
	    contrast and warmth; on High, distant things soften (depth of field)
	  * VIGNETTE: darker screen edges (under the HUD)
	  * DUST: fine desert dust drifting in the air round the camera (High)
	  * LOW HEALTH: the edges pulse red, the world drains of colour
	  * TAKEN DOWN: when you finish someone, letterbox bars slide in, the
	    picture punches in and "TAKEN DOWN" + their name hits the screen
	  * DEATH CAM: when you go down, the world fades to grey behind bars:
	    "YOU WERE TAKEN DOWN · BY <name>" until you respawn
	  * TITLE CARDS: Cinematic.title(top, main, color) for big moments
	    (the bounty board uses it: "THE HUNT BEGINS", "BOUNTY CLAIMED")
	It never takes the camera away from you (cutscenes do that), and it
	stays out of the way while a cutscene is playing.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local VFXQuality = __require("VFXQuality")
local Net = __require("Net")
local CameraFX = __require("CameraFX")

local Cinematic = {}
local cfg = TuskConfig.Cinematic or {}
local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 205, 90)
local PAPER = Color3.fromRGB(234, 205, 160)
local BLOOD = Color3.fromRGB(170, 20, 16)

local grade, dof, dust, dustEmitter
local gui, vignette, redEdges, bars, cardTop, cardMain, cardSub
local mood -- a ColorCorrection the moments (KO, death, low health) push on
local recentHits = setmetatable({}, { __mode = "k" }) -- [victim model] = os.clock() of your last hit on them
local watching = setmetatable({}, { __mode = "k" })
local cardToken = 0
local dead = false
local lastKO = -math.huge

local function level()
	local _, name = VFXQuality.get()
	return name == "High" and 3 or (name == "Medium" and 2 or 1)
end

local function on(key)
	return cfg.Enabled ~= false and cfg[key] ~= false
end

local function cutscenePlaying()
	local cam = workspace.CurrentCamera
	return cam ~= nil and cam.CameraType == Enum.CameraType.Scriptable
end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

---------------------------------------------------------------------------
-- Grade, depth of field, dust
---------------------------------------------------------------------------
local function applyQuality()
	local lv = level()
	if grade then
		grade.Enabled = on("Grade")
	end
	if dof then
		dof.Enabled = on("DepthOfField") and lv >= 3
	end
	if dustEmitter then
		dustEmitter.Enabled = on("Dust") and lv >= 3
	end
	if vignette then
		vignette.Visible = on("Vignette") and lv >= 2
	end
end

local function buildWorld()
	grade = new("ColorCorrectionEffect", { Name = "SpinCinematicGrade", Contrast = cfg.Contrast or 0.08, Saturation = cfg.Saturation or 0.06, Brightness = 0, TintColor = cfg.Tint or Color3.fromRGB(255, 247, 234) }, Lighting)
	mood = new("ColorCorrectionEffect", { Name = "SpinCinematicMood", Contrast = 0, Saturation = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }, Lighting)
	dof = new("DepthOfFieldEffect", { Name = "SpinCinematicDOF", FarIntensity = cfg.FarBlur or 0.12, NearIntensity = 0, FocusDistance = 70, InFocusRadius = 90 }, Lighting)
	-- Dust drifting round the camera (a local part, so only you see yours).
	dust = new("Part", { Name = "SpinDust", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(50, 18, 50) }, workspace.CurrentCamera or workspace)
	dustEmitter = new("ParticleEmitter", {
		Name = "Dust",
		Rate = cfg.DustRate or 14,
		Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(0.3, 1.2),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.5, 0.12), NumberSequenceKeypoint.new(1, 0.05) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(240, 214, 170)),
		LightEmission = 0.3,
		LightInfluence = 0.6,
		Acceleration = Vector3.new(1.2, -0.1, 0.4),
		RotSpeed = NumberRange.new(-30, 30),
	}, dust)
	pcall(function()
		dustEmitter.Shape = Enum.ParticleEmitterShape.Box
		dustEmitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	end)
end

---------------------------------------------------------------------------
-- Screen: vignette, red edges, letterbox and title cards
---------------------------------------------------------------------------
-- Four soft edges of one colour (a vignette).
local function edges(parent, color, depth, name)
	local frame = new("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
	local sides = {
		{ UDim2.fromScale(0, 0), UDim2.fromScale(1, depth), 90 },
		{ UDim2.fromScale(0, 1 - depth), UDim2.fromScale(1, depth), -90 },
		{ UDim2.fromScale(0, 0), UDim2.fromScale(depth * 0.7, 1), 0 },
		{ UDim2.fromScale(1 - depth * 0.7, 0), UDim2.fromScale(depth * 0.7, 1), 180 },
	}
	for _, s in ipairs(sides) do
		local f = new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Position = s[1], Size = s[2] }, frame)
		new("UIGradient", { Rotation = s[3], Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, f)
	end
	return frame
end

local function buildScreen()
	local pg = player:WaitForChild("PlayerGui")
	-- The vignette sits under the HUD.
	local back = new("ScreenGui", { Name = "SpinCinematicBack", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = -5 }, pg)
	vignette = edges(back, Color3.new(0, 0, 0), 0.22, "Vignette")
	vignette.BackgroundTransparency = 1
	for _, f in ipairs(vignette:GetChildren()) do
		f.BackgroundTransparency = cfg.VignetteStrength and (1 - cfg.VignetteStrength) or 0.55
	end
	redEdges = edges(back, BLOOD, 0.28, "LowHealth")
	for _, f in ipairs(redEdges:GetChildren()) do
		f.BackgroundTransparency = 1
	end
	-- Letterbox and title cards sit above most things.
	gui = new("ScreenGui", { Name = "SpinCinematic", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 15 }, pg)
	bars = {}
	for i, y in ipairs({ 0, 1 }) do
		bars[i] = new("Frame", { AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, gui)
	end
	cardTop = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.6, 0.05), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = PAPER, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" }, gui)
	cardMain = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.8, 0.13), BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextScaled = true, TextColor3 = GOLD, TextTransparency = 1, TextStrokeTransparency = 1, TextStrokeColor3 = Color3.fromRGB(40, 22, 10), Text = "" }, gui)
	new("UIScale", { Scale = 1 }, cardMain)
	cardSub = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.fromScale(0.6, 0.045), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = PAPER, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" }, gui)
	for _, l in ipairs({ cardTop, cardMain, cardSub }) do
		new("UITextSizeConstraint", { MaxTextSize = l == cardMain and 80 or 28 }, l)
	end
end

local QUICK = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLAM = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function letterbox(show, size)
	for _, b in ipairs(bars) do
		TweenService:Create(b, QUICK, { Size = UDim2.new(1, 0, show and (size or 0.11) or 0, 0) }):Play()
	end
end

local function hideCard(token)
	if token ~= cardToken then
		return
	end
	letterbox(false)
	for _, l in ipairs({ cardTop, cardMain, cardSub }) do
		TweenService:Create(l, QUICK, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end
end

-- A title card: letterbox bars, a small line on top, a big slammed word,
-- a line under it. `hold` nil keeps it up until the next card / clear.
local function card(top, main, sub, color, hold, barSize)
	if not gui then
		return
	end
	cardToken = cardToken + 1
	local token = cardToken
	letterbox(true, barSize)
	cardTop.Text = string.upper(top or "")
	cardMain.Text = string.upper(main or "")
	cardSub.Text = string.upper(sub or "")
	cardMain.TextColor3 = color or GOLD
	local scale = cardMain:FindFirstChildOfClass("UIScale")
	scale.Scale = 1.8
	TweenService:Create(scale, SLAM, { Scale = 1 }):Play()
	for _, l in ipairs({ cardTop, cardMain, cardSub }) do
		l.TextTransparency = 1
		TweenService:Create(l, QUICK, { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
	end
	if hold then
		task.delay(hold, function()
			hideCard(token)
		end)
	end
	return token
end

-- Push the mood colour for a moment (or hold it with `hold` = nil).
local function moodTo(props, time)
	if not mood then
		return
	end
	TweenService:Create(mood, TweenInfo.new(time or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function moodClear(time)
	moodTo({ Contrast = 0, Saturation = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) }, time or 0.6)
end

---------------------------------------------------------------------------
-- Public: title cards for other systems
---------------------------------------------------------------------------
function Cinematic.title(top, main, color, sub, hold)
	if not on("TitleCards") or cutscenePlaying() or dead then
		return
	end
	card(top, main, sub, color, hold or 2.2, 0.08)
end

---------------------------------------------------------------------------
-- TAKEN DOWN / death cam
---------------------------------------------------------------------------
local function nameOf(model)
	local p = Players:GetPlayerFromCharacter(model)
	if p then
		return p.DisplayName
	end
	local h = model:FindFirstChildOfClass("Humanoid")
	local n = h and h.DisplayName ~= "" and h.DisplayName or model.Name
	return (n:gsub("^Stand User: ", ""))
end

local function takenDown(victim)
	if not on("KOCam") or dead or cutscenePlaying() or os.clock() - lastKO < (cfg.KOCooldown or 2.5) then
		return
	end
	lastKO = os.clock()
	local lv = level()
	card("", "TAKEN DOWN", nameOf(victim), GOLD, cfg.KOHold or 1.5, lv >= 2 and 0.1 or 0.06)
	CameraFX.fovPunch(-10, 0.6)
	if lv >= 2 then
		moodTo({ Contrast = 0.25, Saturation = -0.35, TintColor = Color3.fromRGB(255, 236, 210) }, 0.08)
		task.delay(0.7, function()
			if not dead then
				moodClear(0.8)
			end
		end)
	end
end

local function watchVictim(model)
	if watching[model] then
		return
	end
	local h = model:FindFirstChildOfClass("Humanoid")
	if not h then
		return
	end
	watching[model] = true
	h.Died:Connect(function()
		local t = recentHits[model]
		if t and os.clock() - t <= (cfg.KillCredit or 6) then
			takenDown(model)
		end
	end)
end

local function onDeath(character)
	if not on("DeathCam") then
		return
	end
	dead = true
	local by
	local id = character:GetAttribute("LastAttackerId")
	local when = character:GetAttribute("LastAttackTime") or -math.huge
	if id and workspace:GetServerTimeNow() - when <= 6 then
		local p = Players:GetPlayerByUserId(id)
		by = p and p.DisplayName
	end
	cardToken = cardToken + 1
	card("", "YOU WERE TAKEN DOWN", by and ("BY " .. by) or "THE DESERT TAKES ANOTHER", Color3.fromRGB(230, 90, 70), nil, 0.13)
	moodTo({ Saturation = -1, Contrast = 0.2, Brightness = -0.05, TintColor = Color3.fromRGB(235, 225, 215) }, 1.4)
end

local function onCharacter(character)
	dead = false
	cardToken = cardToken + 1
	hideCard(cardToken)
	moodClear(0.6)
	local h = character:WaitForChild("Humanoid", 10)
	if h then
		h.Died:Connect(function()
			onDeath(character)
		end)
	end
end

---------------------------------------------------------------------------
-- Every frame: dust follows the camera; low-health pulse
---------------------------------------------------------------------------
local lowOn = false
local function step()
	local cam = workspace.CurrentCamera
	if dust and cam then
		if dust.Parent ~= cam then
			dust.Parent = cam
		end
		dust.CFrame = CFrame.new(cam.CFrame.Position + cam.CFrame.LookVector * 14)
	end
	-- Low health: red edges pulse, the colour drains.
	local character = player.Character
	local h = character and character:FindFirstChildOfClass("Humanoid")
	local k = 0
	if on("LowHealth") and h and h.Health > 0 and h.MaxHealth > 0 then
		local frac = h.Health / h.MaxHealth
		local threshold = cfg.LowHealth or 0.3
		if frac < threshold then
			k = 1 - frac / threshold
		end
	end
	if redEdges then
		local pulse = k > 0 and (0.55 + 0.45 * math.abs(math.sin(os.clock() * (3 + k * 3)))) or 0
		for _, f in ipairs(redEdges:GetChildren()) do
			f.BackgroundTransparency = 1 - k * 0.75 * pulse
		end
	end
	if not dead and mood then
		if k > 0 then
			lowOn = true
			mood.Saturation = -0.5 * k
		elseif lowOn then
			lowOn = false
			mood.Saturation = 0
		end
	end
end

---------------------------------------------------------------------------
function Cinematic.init()
	if cfg.Enabled == false then
		return
	end
	if _G.__SpinCinematic then
		return
	end
	_G.__SpinCinematic = true
	buildWorld()
	buildScreen()
	applyQuality()
	VFXQuality.Changed:Connect(applyQuality)
	-- Your hits (to know when YOU took someone down).
	Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
		if name == "Hit" and typeof(data) == "table" and data.AttackerId == player.UserId and typeof(data.Victim) == "Instance" then
			recentHits[data.Victim] = os.clock()
			watchVictim(data.Victim)
		end
	end)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService.RenderStepped:Connect(step)
end

return Cinematic
end

-- ======================================================================
-- MODULE: CombatUI
-- ======================================================================
__modules["CombatUI"] = function()
--[[
	CombatUI  (StarterPlayerScripts.SpinClient.UI.CombatUI)

	Battlegrounds-style fight feedback, in the bounty-board style:
	  * TARGET BAR: hit someone and a nailed wooden plank pops in at the top
	    of the screen with their name in Bangers and a wood-framed health
	    meter (green -> gold -> red). The meter drains smoothly, with a white
	    "chunk" that catches up a moment later so big hits read. Shrinks
	    away after a few seconds.
	  * DAMAGE EDGES: the screen edges flash red when you get hit, and pulse
	    while your health is low.
	  * GUARD BAR: a small wood-framed meter under your character while you
	    block (or while it refills); it turns red as it runs out and shows
	    GUARD BROKEN after a guard break.
	  * DASH / BLOCK chips (bottom right): little wooden planks with a brass
	    key cap; the dash cooldown sweeps back as a dark shadow, and the
	    BLOCK plank glows steel-blue while you block.
	Driven by the shared "Hit" event (CombatAdapter).
]]

local Players = game:GetService("Players")

local Shared = nil -- (bundled: modules are inlined)
local Net = __require("Net")
local UITheme = __require("UITheme")
local C = UITheme.C
local F = UITheme.Font

local CombatUI = {}
local player = Players.LocalPlayer
local GOLD = C.GOLD
local RED = Color3.fromRGB(230, 50, 60)
local BLOCK_BLUE = Color3.fromRGB(110, 180, 255)

local gui, bar, barScale, nameLabel, fill, chunk, hpText, edges
local target -- the model shown in the bar
local shownUntil = 0
local fillValue, chunkValue = 1, 1
local hurtFlash = 0
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local guardGui, guardFill, guardText, chips
local stepDefense -- (defined further down)

local function corner(p, r)
	return UITheme.corner(p, r)
end

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextStrokeColor3 = C.SHADOW
	l.TextStrokeTransparency = 0.3
	l.ZIndex = 4
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function nameOf(model)
	local p = Players:GetPlayerFromCharacter(model)
	if p then
		return p.DisplayName
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.DisplayName ~= "" then
		return humanoid.DisplayName
	end
	return model.Name
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "CombatUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Target bar (top centre): a nailed wooden plank.
	bar = Instance.new("Frame")
	bar.Name = "TargetBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 58)
	bar.Size = UDim2.fromOffset(340, 50)
	bar.Visible = false
	bar.Parent = gui
	UITheme.wood(bar, { Planks = 2, Border = 4, Radius = 8, Nails = true, Brackets = true, BracketSize = 10 })
	barScale = Instance.new("UIScale")
	barScale.Scale = 1
	barScale.Parent = bar
	nameLabel = text(bar, {
		Position = UDim2.fromOffset(14, 4),
		Size = UDim2.new(1, -100, 0, 21),
		Font = F.Title,
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.PAPER,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	hpText = text(bar, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 6),
		Size = UDim2.fromOffset(80, 16),
		Font = F.Heavy,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = GOLD,
	})
	local back
	back, fill = UITheme.bar(bar, RED, {
		Name = "Health",
		Position = UDim2.fromOffset(12, 26),
		Size = UDim2.new(1, -24, 0, 17),
		ZIndex = 3,
	})
	-- The white "chunk" sits under the fill, inside the meter's well.
	chunk = Instance.new("Frame")
	chunk.Name = "Chunk"
	chunk.BorderSizePixel = 0
	chunk.Size = UDim2.fromScale(1, 1)
	chunk.BackgroundColor3 = Color3.fromRGB(255, 244, 220)
	chunk.ZIndex = 3
	chunk.Parent = fill.Parent
	corner(chunk, 3)
	fill.ZIndex = 4
	for _, d in ipairs(fill:GetChildren()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 4
		end
	end

	-- Red damage edges (four gradients round the screen).
	edges = {}
	local sides = {
		{ UDim2.fromScale(0, 0), UDim2.new(1, 0, 0.18, 0), 90 },
		{ UDim2.fromScale(0, 0.82), UDim2.new(1, 0, 0.18, 0), -90 },
		{ UDim2.fromScale(0, 0), UDim2.new(0.12, 0, 1, 0), 0 },
		{ UDim2.fromScale(0.88, 0), UDim2.new(0.12, 0, 1, 0), 180 },
	}
	for _, side in ipairs(sides) do
		local f = Instance.new("Frame")
		f.Position = side[1]
		f.Size = side[2]
		f.BackgroundColor3 = RED
		f.BorderSizePixel = 0
		f.BackgroundTransparency = 1
		f.Parent = gui
		local g = Instance.new("UIGradient")
		g.Rotation = side[3]
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = f
		table.insert(edges, f)
	end
end

local function showTarget(model)
	if not bar then
		return
	end
	if target ~= model then
		target = model
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local k = humanoid and humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth or 1
		fillValue, chunkValue = k, k
		nameLabel.Text = string.upper(nameOf(model))
	end
	shownUntil = os.clock() + 4
	if not bar.Visible then
		bar.Visible = true
		UITheme.pop(bar, 0.7)
	elseif barScale.Scale < 0.99 then
		-- Hit again while it was shrinking away: bounce back up.
		UITheme.pop(bar, barScale.Scale)
	end
end

function CombatUI.step(dt)
	if not bar then
		return
	end
	dt = dt or 1 / 60
	local now = os.clock()
	-- Target bar.
	local humanoid = target and target.Parent and target:FindFirstChildOfClass("Humanoid")
	if humanoid and now < shownUntil then
		local k = humanoid.MaxHealth > 0 and math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) or 0
		fillValue = fillValue + (k - fillValue) * math.min(dt * 18, 1)
		-- The white chunk waits a moment, then catches up.
		if chunkValue > fillValue then
			chunkValue = math.max(fillValue, chunkValue - dt * 0.6)
		else
			chunkValue = fillValue
		end
		fill.Size = UDim2.fromScale(fillValue, 1)
		chunk.Size = UDim2.fromScale(chunkValue, 1)
		fill.BackgroundColor3 = k > 0.5 and Color3.fromRGB(90, 220, 110):Lerp(GOLD, (1 - k) * 2) or GOLD:Lerp(RED, (0.5 - k) * 2)
		hpText.Text = humanoid.Health <= 0 and "K.O." or (math.ceil(humanoid.Health) .. " / " .. math.floor(humanoid.MaxHealth))
		-- Shrinks away over its last 0.4 s (a fade would mean fading every plank).
		local fade = math.clamp((shownUntil - now) / 0.4, 0, 1)
		if fade < 1 then
			barScale.Scale = 0.6 + 0.4 * fade
		end
		bar.Visible = fade > 0
	else
		bar.Visible = false
	end
	-- Damage edges: a flash when hit, a slow pulse while health is low.
	hurtFlash = math.max(0, hurtFlash - dt * 2.5)
	local mine = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local low = 0
	if mine and mine.Health > 0 and mine.MaxHealth > 0 and mine.Health / mine.MaxHealth < 0.3 then
		low = (0.5 + 0.5 * math.sin(now * 5)) * (1 - mine.Health / mine.MaxHealth / 0.3) * 0.5
	end
	local strength = math.max(hurtFlash, low)
	for _, f in ipairs(edges) do
		f.BackgroundTransparency = 1 - strength * 0.7
	end
	stepDefense()
end

local function chip(name, key, order)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(1, 1)
	f.Position = UDim2.new(1, -16, 1, -16 - order * 38)
	f.Size = UDim2.fromOffset(112, 32)
	f.ClipsDescendants = true
	f.Parent = gui
	local planks = UITheme.wood(f, { Planks = 1, Border = 3, Radius = 7, Nails = false, Stroke = 2 })
	local edge = f:FindFirstChildOfClass("UIStroke")
	-- Steel-blue glow while blocking.
	local tint = Instance.new("Frame")
	tint.Name = "Tint"
	tint.BorderSizePixel = 0
	tint.Size = UDim2.fromScale(1, 1)
	tint.BackgroundColor3 = BLOCK_BLUE
	tint.BackgroundTransparency = 1
	tint.ZIndex = 2
	tint.Parent = planks
	-- Cooldown: a dark shadow that sweeps back.
	local sweep = Instance.new("Frame")
	sweep.Name = "Sweep"
	sweep.BorderSizePixel = 0
	sweep.Size = UDim2.fromScale(0, 1)
	sweep.BackgroundColor3 = C.SHADOW
	sweep.BackgroundTransparency = 0.35
	sweep.ZIndex = 2
	sweep.Parent = planks
	-- Brass key cap.
	local keyLabel = text(f, {
		Name = "Key",
		BackgroundTransparency = 0,
		BackgroundColor3 = GOLD,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.fromOffset(22, 22),
		Font = F.Title,
		TextSize = 17,
		TextColor3 = C.INK,
		TextStrokeTransparency = 1,
		Text = key,
	})
	corner(keyLabel, 5)
	UITheme.stroke(keyLabel, C.WOOD_EDGE, 2)
	local label = text(f, {
		Position = UDim2.fromOffset(33, 0),
		Size = UDim2.new(1, -37, 1, 0),
		Font = F.Heavy,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.PAPER,
		Text = name,
	})
	return { Frame = f, Sweep = sweep, Tint = tint, Edge = edge, Label = label, Name = name }
end

local function buildDefense()
	local keys = TuskConfig.Keys
	local function keyText(k)
		local names = { One = "1", Two = "2", Three = "3" }
		return k and (names[k.Name] or k.Name) or "?"
	end
	chips = {
		Dash = chip("DASH", keyText(keys.Dash and keys.Dash.Keyboard), 1),
		Block = chip("BLOCK", keyText(keys.Block and keys.Block.Keyboard), 0),
	}
	guardGui = Instance.new("BillboardGui")
	guardGui.Name = "GuardBar"
	guardGui.Size = UDim2.fromOffset(96, 15)
	guardGui.StudsOffset = Vector3.new(0, -3.4, 0)
	guardGui.AlwaysOnTop = true
	guardGui.LightInfluence = 0
	guardGui.Enabled = false
	guardGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	guardGui.Parent = gui
	local back
	back, guardFill = UITheme.bar(guardGui, BLOCK_BLUE, { Name = "Guard", Size = UDim2.fromScale(1, 1) })
	guardText = text(back, {
		Size = UDim2.fromScale(1, 1),
		Font = F.Title,
		TextSize = 12,
		TextColor3 = C.PAPER,
		TextStrokeTransparency = 0.2,
		Text = "",
		ZIndex = 5,
	})
end

function stepDefense()
	if not chips then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local d = TuskConfig.Defense or {}
	local t = workspace:GetServerTimeNow()
	-- Dash chip: a pip per charge; grey sweep while the next one comes back.
	local maxCharges = d.DashCharges or 1
	local readyAt = character and character:GetAttribute("DashReadyAt") or 0
	local fullAt = character and character:GetAttribute("DashFullAt") or readyAt
	local have = maxCharges
	if maxCharges >= 2 then
		have = (readyAt <= t and 1 or 0) + (fullAt <= t and maxCharges - 1 or 0)
	elseif readyAt > t then
		have = 0
	end
	local pips = string.rep("●", have) .. string.rep("○", maxCharges - have)
	local dashChip = chips.Dash
	local counter = character and (character:GetAttribute("CounterUntil") or 0) > t
	if have < maxCharges then
		local nextAt = have == 0 and readyAt or fullAt
		local left = nextAt - t
		dashChip.Sweep.Size = UDim2.fromScale(math.clamp(left / (d.DashCooldown or 2.2), 0, 1), 1)
		dashChip.Label.Text = string.format("DASH %s %.1f", pips, left)
		dashChip.Label.TextColor3 = have > 0 and C.PAPER or Color3.fromRGB(175, 150, 120)
	else
		dashChip.Sweep.Size = UDim2.fromScale(0, 1)
		dashChip.Label.Text = "DASH " .. pips
		dashChip.Label.TextColor3 = C.PAPER
	end
	if counter then
		dashChip.Label.Text = "COUNTER!"
		dashChip.Label.TextColor3 = Color3.fromRGB(255, 210, 80)
	end
	-- Block chip + guard bar.
	local blockingNow = character and character:GetAttribute("Blocking") == true
	local broken = character and (character:GetAttribute("GuardBrokenUntil") or 0) > t
	local meter = character and character:GetAttribute("BlockMeter")
	local max = d.MaxMeter or 100
	local blockChip = chips.Block
	blockChip.Label.Text = broken and "BROKEN" or (blockingNow and "BLOCKING" or "BLOCK")
	blockChip.Label.TextColor3 = broken and RED or (blockingNow and Color3.fromRGB(190, 225, 255) or C.PAPER)
	blockChip.Tint.BackgroundTransparency = blockingNow and 0.6 or 1
	if blockChip.Edge then
		blockChip.Edge.Color = broken and RED or (blockingNow and BLOCK_BLUE or C.WOOD_EDGE)
	end
	if root and (blockingNow or broken or (meter and meter < max)) then
		guardGui.Adornee = root
		guardGui.Enabled = true
		local k = broken and 0 or math.clamp((meter or max) / max, 0, 1)
		guardFill.Size = UDim2.fromScale(k, 1)
		guardFill.BackgroundColor3 = BLOCK_BLUE:Lerp(RED, 1 - k)
		guardText.Text = broken and "GUARD BROKEN" or ""
	else
		guardGui.Enabled = false
	end
end

function CombatUI.init()
	build()
	buildDefense()
	Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
		if name ~= "Hit" or typeof(data) ~= "table" or not data.Victim then
			return
		end
		if data.AttackerId == player.UserId and data.Victim ~= player.Character then
			showTarget(data.Victim)
		end
		if data.Victim == player.Character then
			hurtFlash = data.Blocked and 0.25 or 0.8
		end
	end)
	game:GetService("RunService").RenderStepped:Connect(CombatUI.step)
end

return CombatUI
end

-- ======================================================================
-- MODULE: CorpseClient
-- ======================================================================
__modules["CorpseClient"] = function()
--[[
	CorpseClient  (StarterPlayerScripts.SpinClient.CorpseClient)

	Client side of the SAINT'S CORPSE (server: CorpseService, CorpseMoves).
	  * the relics float, turn and bob (tag "SpinCorpse")
	  * a panel in the bottom-left corner while you hold parts, in the bounty
	    board's style (UI.UITheme): a framed wooden board with steel corner
	    brackets, a parchment strip per part with its boost, and your chunky
	    red CORPSE MOVE button (V / D-pad right, or tap it; bounces on hover)
	    with its cooldown shade
	  * announcements: you took a part (big outlined gold Bangers), someone
	    else took one or a part fell where someone died (a nailed parchment
	    ribbon at the top)
	  * the relic compass's distance sits on a little wooden plaque
	  * the visuals for every character's corpse move, with its name popping
	    up over the caster
	  * the COMPLETE corpse: a server-wide announcement, a gold halo over the
	    holder, the board's frame turns gold and V is THE SAINT'S MIRACLE (golden sky,
	    a giant halo, pillars of light on every enemy, a final blast)
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local TuskVFX = __require("TuskVFX")
local CameraFX = __require("CameraFX")
local UITheme = __require("UITheme")
local Common = __require("TuskActCommon")
local TuskAnimation = __require("TuskAnimation")

local CorpseClient = {}

local player = Players.LocalPlayer
local cfg
local T = UITheme.C
local GOLD = T.GOLD
local INK = T.INK
local MOVE_RED = T.RED -- the corpse move button
local MOVE_GOLD = Color3.fromRGB(226, 182, 70) -- ... once the corpse is complete
local partInfo = {}

local gui, panel, panelTitle, list, moveButton, moveName, moveFill, moveTime, feed, feedText, banner
local shown = "" -- the parts string the panel was built for

---------------------------------------------------------------------------
-- Small UI helpers
---------------------------------------------------------------------------
local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props or {}) do
		i[k] = v
	end
	i.Parent = parent
	return i
end

local function corner(p, r)
	new("UICorner", { CornerRadius = UDim.new(0, r) }, p)
end

local function label(parent, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left }, parent)
	for k, v in pairs(props) do
		l[k] = v
	end
	return l
end

-- A chunky dark outline round text (UIStroke on the glyphs) with a
-- light-to-shade gradient, like the bounty board's banners.
local function inkOutline(l, thickness)
	l.TextStrokeTransparency = 1
	local stroke = new("UIStroke", { Color = T.WOOD_EDGE, Thickness = thickness or 2, LineJoinMode = Enum.LineJoinMode.Round }, l)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 205, 190)), Rotation = 90 }, l)
	return stroke
end

-- Recolour a chunky button (fill + its darker edge).
local function tintButton(b, color)
	b.BackgroundColor3 = color
	local edge = b:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = color:Lerp(Color3.new(0, 0, 0), 0.45)
	end
end

local function myCharacterName()
	local c = player.Character
	local act = c and c:GetAttribute("TuskAct")
	return act and Registry.characterOf(act) or nil
end

local function aim()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return nil
	end
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch or string.find(last.Name, "Gamepad") then
		return camera.CFrame.LookVector
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, VFXLib.Folder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local target = hit and hit.Position or ray.Origin + ray.Direction * 600
	local dir = target - root.Position
	return dir.Magnitude > 1 and dir.Unit or root.CFrame.LookVector
end

local function useMove()
	local c = player.Character
	if not c or not c:GetAttribute("CorpseParts") then
		return
	end
	Net.get("TuskRequest"):FireServer("CorpseMove", aim())
end

---------------------------------------------------------------------------
-- The panel (left side, while you hold parts)
---------------------------------------------------------------------------
local PANEL_W = 200
local HINT_TEXT = "Hover a part for its boost"
local panelHint

local function rebuildPanel(parts)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local ids = {}
	for id in string.gmatch(parts, "[^,]+") do
		table.insert(ids, id)
	end
	for i, id in ipairs(ids) do
		local info = partInfo[id]
		-- Each part: a small parchment tag with a brass relic diamond (two
		-- columns). Hover / tap it to see its boost on the line under the title.
		local row = new("TextButton", { LayoutOrder = i, Text = "", AutoButtonColor = false, ZIndex = 3 }, list)
		UITheme.paper(row, { Radius = 3, Stroke = 1.5 })
		local icon = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = T.BRASS, Rotation = 45, ZIndex = 4 }, row)
		new("UIStroke", { Color = T.INK, Thickness = 1 }, icon)
		label(row, { Position = UDim2.fromOffset(19, 1), Size = UDim2.new(1, -22, 1, -2), Text = info and info.Name or id, Font = UITheme.Font.Title, TextColor3 = T.INK, ZIndex = 4 })
		local boost = (info and info.Name or id) .. ": " .. (info and info.Text or "")
		local function showBoost()
			panelHint.Text = boost
			panelHint.TextColor3 = GOLD
		end
		local function hideBoost()
			panelHint.Text = HINT_TEXT
			panelHint.TextColor3 = T.PAPER_DARK
		end
		row.MouseEnter:Connect(showBoost)
		row.MouseLeave:Connect(hideBoost)
		row.Activated:Connect(function()
			if panelHint.Text == boost then
				hideBoost()
			else
				showBoost()
			end
		end)
	end
	local rows = math.ceil(#ids / 2)
	panel.Size = UDim2.fromOffset(PANEL_W, 40 + rows * 22 + 42)
	local who = myCharacterName()
	local complete = #ids >= #cfg.Parts
	if complete then
		who = "Miracle"
	end
	moveName.Text = (cfg.MoveNames and who and cfg.MoveNames[who]) or "CORPSE MOVE"
	-- The complete corpse: the board's frame and edge turn gold.
	panel.BackgroundColor3 = complete and T.BRASS or T.WOOD_DARK
	local edge = panel:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = complete and GOLD or T.WOOD_EDGE
		edge.Thickness = complete and 4 or 3
	end
	tintButton(moveButton, complete and MOVE_GOLD or MOVE_RED)
	panelTitle.Text = complete and "COMPLETE SAINT'S CORPSE" or "SAINT'S CORPSE"
end

local function buildUI()
	gui = new("ScreenGui", { Name = "CorpseHUD", ResetOnSpawn = false, DisplayOrder = 4, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
	-- Bottom-left corner (lifted above the thumbstick on touch screens): a
	-- framed wooden board, a parchment strip per part, the move button.
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	panel = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, touch and -230 or -12), Size = UDim2.fromOffset(PANEL_W, 104), Visible = false }, gui)
	UITheme.wood(panel, { Planks = 3, Border = 4, Brackets = true, BracketSize = 11 })
	panelTitle = label(panel, { Position = UDim2.fromOffset(11, 5), Size = UDim2.new(1, -22, 0, 18), Text = "SAINT'S CORPSE", Font = UITheme.Font.Title, TextColor3 = GOLD, TextStrokeColor3 = T.WOOD_EDGE, TextStrokeTransparency = 0.4, ZIndex = 3 })
	panelHint = label(panel, { Position = UDim2.fromOffset(11, 23), Size = UDim2.new(1, -22, 0, 11), Text = HINT_TEXT, Font = Enum.Font.GothamBold, TextColor3 = T.PAPER_DARK, ZIndex = 3 })
	list = new("Frame", { Name = "List", Position = UDim2.fromOffset(8, 38), Size = UDim2.new(1, -16, 1, -82), BackgroundTransparency = 1, ZIndex = 3 }, panel)
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -2, 0, 19), CellPadding = UDim2.fromOffset(4, 3), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	-- The corpse move: a chunky button (bounces on hover / press) with a
	-- cooldown shade sweeping over it.
	moveButton = new("TextButton", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -8), Size = UDim2.new(1, -20, 0, 32), BackgroundColor3 = MOVE_RED, Text = "", AutoButtonColor = false, ClipsDescendants = false, ZIndex = 3 }, panel)
	corner(moveButton, 8)
	new("UIStroke", { Color = MOVE_RED:Lerp(Color3.new(0, 0, 0), 0.45), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, moveButton)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)), Rotation = 90 }, moveButton)
	UITheme.hover(moveButton, 1.04)
	moveFill = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, ZIndex = 4 }, moveButton)
	corner(moveFill, 8)
	-- The key: a little dark plank with a gold V.
	local key = new("Frame", { Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = T.WOOD_DARK, ZIndex = 5 }, moveButton)
	corner(key, 6)
	new("UIStroke", { Color = GOLD, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, key)
	label(key, { Size = UDim2.fromScale(1, 1), Text = "V", Font = UITheme.Font.Title, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5 })
	moveName = label(moveButton, { Position = UDim2.fromOffset(33, 4), Size = UDim2.new(1, -76, 0, 24), Text = "", Font = UITheme.Font.Title, TextStrokeColor3 = T.WOOD_EDGE, TextStrokeTransparency = 0.3, ZIndex = 5 })
	new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 9 }, moveName)
	moveTime = label(moveButton, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 5), Size = UDim2.fromOffset(34, 22), Text = "", Font = UITheme.Font.Title, TextColor3 = GOLD, TextStrokeColor3 = T.WOOD_EDGE, TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 })
	moveButton.Activated:Connect(useMove)
	-- Announcements: a parchment ribbon at the top that fits its line...
	feed = new("Frame", { Name = "Feed", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 118), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, Visible = false }, gui)
	UITheme.paper(feed, { Radius = 4 })
	new("UISizeConstraint", { MaxSize = Vector2.new(560, 26) }, feed)
	new("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22) }, feed)
	for _, x in ipairs({ 0, 1 }) do
		local nail = new("Frame", { AnchorPoint = Vector2.new(x, 0.5), Position = UDim2.new(x, x == 0 and -14 or 14, 0.5, 0), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = T.NAIL, ZIndex = 2 }, feed)
		corner(nail, 99)
	end
	feedText = label(feed, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextScaled = false, TextSize = 15, Text = "", Font = Enum.Font.GothamBold, TextColor3 = T.INK, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2 })
	new("UISizeConstraint", { MaxSize = Vector2.new(516, 26) }, feedText)
	-- ... and a big outlined gold banner.
	banner = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(620, 70), Text = "", Font = UITheme.Font.Title, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, Visible = false })
	inkOutline(banner, 3)
end

local feedToken, bannerToken
local function showFeed(text)
	feedText.Text = text
	feed.Visible = true
	UITheme.pop(feed, 0.85)
	local token = {}
	feedToken = token
	task.delay(3.5, function()
		if feedToken == token then
			feed.Visible = false
		end
	end)
end

local function showBanner(text)
	banner.Text = text
	banner.Visible = true
	local token = {}
	bannerToken = token
	VFXLib.animate(0.25, function(a)
		banner.Size = UDim2.fromOffset(620 * (0.6 + 0.4 * a), 70 * (0.6 + 0.4 * a))
	end)
	task.delay(3, function()
		if bannerToken == token then
			banner.Visible = false
		end
	end)
end

local function stepPanel()
	local c = player.Character
	local parts = c and c:GetAttribute("CorpseParts") or ""
	panel.Visible = parts ~= ""
	if parts ~= shown then
		shown = parts
		if parts ~= "" then
			rebuildPanel(parts)
		end
	end
	if parts ~= "" then
		local left = math.max(0, (c:GetAttribute("CorpseReadyAt") or 0) - workspace:GetServerTimeNow())
		local total = cfg.Move and cfg.Move.Cooldown or 20
		moveFill.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
		moveTime.Text = left > 0 and tostring(math.ceil(left)) or ""
	end
end

---------------------------------------------------------------------------
-- Relics: float, turn and bob
---------------------------------------------------------------------------
local relicBase = setmetatable({}, { __mode = "k" }) -- [part] = original CFrame

local function stepRelics(now)
	for _, model in ipairs(CollectionService:GetTagged("SpinCorpse")) do
		local holder = model.PrimaryPart
		if holder then
			local center = holder.Position
			local turn = CFrame.new(center) * CFrame.new(0, math.sin(now * 2 + center.X) * 0.4, 0) * CFrame.Angles(0, now * 1.2, 0) * CFrame.new(-center)
			for _, p in ipairs(model:GetChildren()) do
				if p:IsA("BasePart") and p ~= holder and p.Name ~= "Beam" then
					relicBase[p] = relicBase[p] or p.CFrame
					p.CFrame = turn * relicBase[p]
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Corpse move visuals
---------------------------------------------------------------------------
local function paletteOf(who)
	local act = Registry.StartAct[who] or 1
	return Common.palette(act)
end

-- The move's name pops up over the caster.
local function callout(character, who)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = new("BillboardGui", { Adornee = head, Size = UDim2.fromOffset(240, 40), StudsOffset = Vector3.new(0, 3.4, 0), AlwaysOnTop = true, LightInfluence = 0 }, VFXLib.Folder)
	local l = label(bb, { Size = UDim2.fromScale(1, 1), Text = (cfg.MoveNames and cfg.MoveNames[who] or "CORPSE MOVE") .. "!", Font = Enum.Font.Bangers, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center })
	local outline = inkOutline(l, 3)
	VFXLib.animate(1.3, function(a)
		bb.StudsOffset = Vector3.new(0, 3.4 + a * 1.2, 0)
		l.TextTransparency = math.max(0, (a - 0.6) / 0.4)
		outline.Transparency = l.TextTransparency
	end, function()
		bb:Destroy()
	end)
end

local function ring(position, radius, color, time)
	local p = VFXLib.part({ Size = Vector3.new(0.5, 1, 1), Color = color, Material = Enum.Material.Neon, Transparency = 0.2, Shape = Enum.PartType.Cylinder })
	VFXLib.animate(time or 0.4, function(a)
		p.Size = Vector3.new(0.5, radius * 2 * a, radius * 2 * a)
		p.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		p.Transparency = 0.2 + 0.8 * a
	end, function()
		p:Destroy()
	end)
end

local function streak(from, to, color, width, time)
	local p = VFXLib.part({ Size = Vector3.new(width or 0.4, width or 0.4, (to - from).Magnitude), CFrame = CFrame.lookAt((from + to) / 2, to), Color = color, Material = Enum.Material.Neon, Transparency = 0.2 })
	VFXLib.animate(time or 0.3, function(a)
		p.Transparency = 0.2 + 0.8 * a
	end, function()
		p:Destroy()
	end)
end

-- A shell round someone for a while (cocoon / light).
---------------------------------------------------------------------------
-- Diego's six-shooter: a proper revolver, built in gun space (origin at the
-- grip, barrel along -Z, top along +Y) and held in his right hand.
---------------------------------------------------------------------------
local revolvers = setmetatable({}, { __mode = "k" }) -- [character] = gun while it's out
local drawRevolver
local STEEL = Color3.fromRGB(64, 66, 76)
local STEEL_LIGHT = Color3.fromRGB(150, 154, 166)
local WOOD = Color3.fromRGB(132, 80, 42)
local WOOD_DARK = Color3.fromRGB(92, 54, 28)
local BRASS = Color3.fromRGB(214, 176, 90)
local CYL_CENTER = Vector3.new(0, 0.42, -0.5)

local function buildRevolver()
	local pieces = {}
	local function add(size, cf, color, material, shape, cylinderPart)
		local p = VFXLib.part({ Size = size, Color = color, Material = material or Enum.Material.Metal })
		if shape then
			p.Shape = shape
		end
		table.insert(pieces, { Part = p, Offset = cf, Cylinder = cylinderPart })
		return p
	end
	local alongZ = CFrame.Angles(0, math.pi / 2, 0) -- turns a cylinder's axis from X onto Z
	-- Grip: curved wood with darker panels and a steel butt cap.
	add(Vector3.new(0.24, 0.62, 0.32), CFrame.new(0, -0.06, 0.14) * CFrame.Angles(-0.32, 0, 0), WOOD, Enum.Material.Wood)
	for _, side in ipairs({ -1, 1 }) do
		add(Vector3.new(0.03, 0.46, 0.22), CFrame.new(side * 0.13, -0.08, 0.15) * CFrame.Angles(-0.32, 0, 0), WOOD_DARK, Enum.Material.Wood)
	end
	add(Vector3.new(0.26, 0.08, 0.34), CFrame.new(0, -0.38, 0.26) * CFrame.Angles(-0.32, 0, 0), STEEL)
	-- Frame, top strap, hammer with its spur.
	add(Vector3.new(0.22, 0.36, 0.62), CFrame.new(0, 0.36, -0.12), STEEL)
	add(Vector3.new(0.16, 0.08, 0.78), CFrame.new(0, 0.6, -0.36), STEEL_LIGHT)
	add(Vector3.new(0.08, 0.2, 0.1), CFrame.new(0, 0.64, 0.16) * CFrame.Angles(-0.5, 0, 0), STEEL)
	add(Vector3.new(0.1, 0.05, 0.14), CFrame.new(0, 0.74, 0.24) * CFrame.Angles(-0.2, 0, 0), STEEL_LIGHT)
	-- Trigger and trigger guard.
	add(Vector3.new(0.05, 0.16, 0.05), CFrame.new(0, 0.12, -0.2) * CFrame.Angles(0.3, 0, 0), BRASS)
	add(Vector3.new(0.07, 0.05, 0.38), CFrame.new(0, -0.03, -0.22), STEEL)
	add(Vector3.new(0.07, 0.22, 0.05), CFrame.new(0, 0.07, -0.42), STEEL)
	-- The cylinder: a fat drum with six chambers on its face and flutes.
	add(Vector3.new(0.5, 0.5, 0.5), CFrame.new(CYL_CENTER) * alongZ, STEEL_LIGHT, Enum.Material.Metal, Enum.PartType.Cylinder, true)
	add(Vector3.new(0.52, 0.42, 0.42), CFrame.new(CYL_CENTER) * alongZ, STEEL, Enum.Material.Metal, Enum.PartType.Cylinder, true)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local off = Vector3.new(math.cos(a) * 0.15, math.sin(a) * 0.15, 0)
		add(Vector3.new(0.06, 0.11, 0.11), CFrame.new(CYL_CENTER + off + Vector3.new(0, 0, -0.25)) * alongZ, Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, true)
		local flute = Vector3.new(math.cos(a + math.pi / 6) * 0.25, math.sin(a + math.pi / 6) * 0.25, 0)
		add(Vector3.new(0.05, 0.05, 0.36), CFrame.new(CYL_CENTER + flute), STEEL, Enum.Material.Metal, nil, true)
	end
	-- An octagonal barrel (two square bars, one turned 45 degrees), the
	-- ejector rod under it, a front sight and a dark muzzle.
	add(Vector3.new(0.16, 0.16, 1.3), CFrame.new(0, 0.5, -1.38), STEEL)
	add(Vector3.new(0.16, 0.16, 1.3), CFrame.new(0, 0.5, -1.38) * CFrame.Angles(0, 0, math.pi / 4), STEEL)
	add(Vector3.new(0.06, 0.06, 0.95), CFrame.new(0, 0.34, -1.2), STEEL_LIGHT)
	add(Vector3.new(0.1, 0.1, 0.22), CFrame.new(0, 0.34, -1.62), STEEL)
	add(Vector3.new(0.04, 0.09, 0.12), CFrame.new(0, 0.62, -1.96), BRASS)
	add(Vector3.new(0.04, 0.17, 0.17), CFrame.new(0, 0.5, -2.04) * alongZ, Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	return pieces
end

drawRevolver = function(character, data)
	local old = revolvers[character]
	if old then
		old.Done()
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then
		return
	end
	local pieces = buildRevolver()
	local gun = { Spin = 0, Kick = -1, Start = os.clock() }
	local drawT = data.Draw or 0.35
	local twirlAt = drawT + (data.Shots or 6) * (data.Every or 0.14) + 0.1
	local total = data.Time or (twirlAt + 0.5)
	local function gunCF()
		local t = os.clock() - gun.Start
		-- Held by the grip, barrel along the hand's pointing direction.
		local grip = (hand.Name == "Right Arm") and hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 + 0.1, 0) or hand.CFrame
		local cf = grip * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.new(0, 0.1, 0.05)
		-- Drawn: it swings up from pointing down.
		if t < drawT then
			cf = cf * CFrame.Angles(-(1 - t / drawT) * 1.6, 0, 0)
		end
		-- Recoil: the barrel kicks up and settles.
		local k = math.max(0, 1 - (os.clock() - gun.Kick) / 0.1)
		cf = cf * CFrame.Angles(k * 0.35, 0, 0)
		-- Twirl round the trigger guard, then it's holstered.
		if t > twirlAt then
			local a = math.min((t - twirlAt) / 0.4, 1)
			cf = cf * CFrame.new(0, 0.05, -0.3) * CFrame.Angles(a * math.pi * 4, 0, 0) * CFrame.new(0, -0.05, 0.3)
		end
		return cf
	end
	gun.Muzzle = function()
		return (gunCF() * CFrame.new(0, 0.5, -2.1)).Position
	end
	local job
	gun.Done = function()
		if revolvers[character] == gun then
			revolvers[character] = nil
		end
		VFXLib.cancel(job)
		for _, e in ipairs(pieces) do
			e.Part:Destroy()
		end
	end
	revolvers[character] = gun
	job = VFXLib.animate(total, function()
		if not hand.Parent then
			return
		end
		local cf = gunCF()
		local spin = CFrame.new(CYL_CENTER) * CFrame.Angles(0, 0, gun.Spin) * CFrame.new(-CYL_CENTER)
		local t = os.clock() - gun.Start
		local fadeOut = math.clamp((t - (total - 0.15)) / 0.15, 0, 1)
		for _, e in ipairs(pieces) do
			e.Part.CFrame = cf * (e.Cylinder and spin * e.Offset or e.Offset)
			e.Part.Transparency = fadeOut
		end
	end, gun.Done)
end

local function shell(character, color, material, time)
	local p = VFXLib.part({ Size = Vector3.new(5, 7, 5), Color = color, Material = material, Transparency = 0.3 })
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local r = Common.rootOf(character)
		local t = os.clock() - start
		if not r or t > time then
			conn:Disconnect()
			p:Destroy()
			return
		end
		p.CFrame = r.CFrame * CFrame.Angles(0, t * 2, 0)
		p.Size = Vector3.new(5, 7, 5) * (1 + math.sin(t * 8) * 0.03)
	end)
end

---------------------------------------------------------------------------
-- The complete corpse: a gold halo over whoever holds all of it
---------------------------------------------------------------------------
local halos = {} -- [character] = { Ring, Light }

local function stepHalos(now)
	local seen = {}
	local candidates = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(candidates, p.Character)
		end
	end
	for _, m in ipairs(CollectionService:GetTagged("SpinFighter")) do
		table.insert(candidates, m)
	end
	for _, character in ipairs(candidates) do
		local head = character.Parent and character:GetAttribute("CorpseComplete") and character:FindFirstChild("Head")
		if head then
			seen[character] = true
			local h = halos[character]
			if not h then
				local ring = VFXLib.part({ Size = Vector3.new(0.15, 2.6, 2.6), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.15, Shape = Enum.PartType.Cylinder })
				local light = Instance.new("PointLight")
				light.Color = GOLD
				light.Range = 16
				light.Brightness = 2
				light.Parent = ring
				h = { Ring = ring }
				halos[character] = h
			end
			h.Ring.CFrame = CFrame.new(head.Position + Vector3.new(0, 1.6 + math.sin(now * 2) * 0.1, 0)) * CFrame.Angles(0, now, math.pi / 2)
			if math.random() < 0.15 then
				VFXLib.burst(head.Position - Vector3.new(0, 2, 0), { Count = 2, Color = GOLD, Speed = 4, Lifetime = 0.8, Direction = Vector3.new(0, 1, 0), Spread = 40 })
			end
		end
	end
	for character, h in pairs(halos) do
		if not seen[character] then
			halos[character] = nil
			h.Ring:Destroy()
		end
	end
end

-- THE SAINT'S MIRACLE.
local function onMiracle(data)
	local character = data.Character
	local local_ = character == player.Character
	if data.Phase == "Start" then
		callout(character, "Miracle")
		local at = data.Position
		-- A giant halo forms high over them and a column of light falls.
		local halo = VFXLib.part({ Size = Vector3.new(0.6, 1, 1), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.2, Shape = Enum.PartType.Cylinder })
		local column = VFXLib.part({ Size = Vector3.new(80, 8, 8), Color = Color3.fromRGB(255, 244, 200), Material = Enum.Material.Neon, Transparency = 0.5, Shape = Enum.PartType.Cylinder })
		VFXLib.animate(data.Time or 4.5, function(a)
			local grow = math.min(a * 4, 1)
			halo.Size = Vector3.new(0.6, 30 * grow, 30 * grow)
			halo.CFrame = CFrame.new(at + Vector3.new(0, 18, 0)) * CFrame.Angles(0, a * 6, math.pi / 2)
			column.CFrame = CFrame.new(at + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			column.Transparency = 0.5 + 0.4 * a
		end, function()
			halo:Destroy()
			column:Destroy()
		end)
		VFXLib.burst(at, { Count = 40, Color = GOLD, Speed = 20, Lifetime = 1, Direction = Vector3.new(0, 1, 0), Spread = 60 })
		-- The sky turns gold for everyone in range.
		local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if me and (me.Position - at).Magnitude <= (data.Range or 70) + 20 then
			TuskVFX.ScreenTint(data.Time or 4.5, { Tint = Color3.fromRGB(255, 236, 190), Saturation = 0.15, Brightness = 0.08 })
			CameraFX.shake(0.3, data.Windup or 1.5)
		end
	elseif data.Phase == "Pillars" then
		for _, pos in ipairs(data.Positions or {}) do
			local pillar = VFXLib.part({ Size = Vector3.new(60, 5, 5), Color = Color3.fromRGB(255, 246, 210), Material = Enum.Material.Neon, Transparency = 0.2, Shape = Enum.PartType.Cylinder })
			VFXLib.animate(0.45, function(a)
				pillar.CFrame = CFrame.new(pos + Vector3.new(0, 30 - 0, 0)) * CFrame.Angles(0, 0, math.pi / 2)
				pillar.Size = Vector3.new(60, 5 * (1 - a * 0.7), 5 * (1 - a * 0.7))
				pillar.Transparency = 0.2 + 0.8 * a
			end, function()
				pillar:Destroy()
			end)
			TuskVFX.CreateImpactStar(pos, { Size = 6, Rays = 10, Color = GOLD, Color2 = Color3.new(1, 1, 1), Duration = 0.2 })
			ring(pos, 6, GOLD, 0.35)
		end
	elseif data.Phase == "Burst" then
		ring(data.Position, data.Radius or 22, GOLD, 0.6)
		ring(data.Position, (data.Radius or 22) * 0.6, Color3.new(1, 1, 1), 0.4)
		VFXLib.burst(data.Position, { Count = 60, Color = GOLD, Speed = 40, Lifetime = 0.8 })
		TuskVFX.CreateImpactStar(data.Position + Vector3.new(0, 2, 0), { Size = 14, Rays = 14, Color = GOLD, Color2 = Color3.new(1, 1, 1), Duration = 0.35 })
		if local_ then
			CameraFX.impactFrame(GOLD)
		end
		CameraFX.shakeAt(data.Position, 1, 80)
	end
end

local function onMove(data)
	if data.Who == "Miracle" then
		onMiracle(data)
		return
	end
	local character = data.Character
	local who = data.Who
	local pal = paletteOf(who)
	local local_ = character == player.Character
	if data.Phase == "Cast" or data.Phase == "Leap" or data.Phase == "Dash" or data.Phase == "Spin" or data.Phase == "Cocoon" or data.Phase == "Curtain" or data.Phase == "Flood" or data.Phase == "Bless" then
		callout(character, who)
		local root = Common.rootOf(character)
		if root then
			TuskVFX.CreateImpactStar(root.Position + Vector3.new(0, 1, 0), { Size = 4, Rays = 8, Color = GOLD, Color2 = pal.Main, Duration = 0.18 })
		end
	end
	if who == "Gyro" and data.Phase == "Cast" then
		-- Golden rings spinning down the line.
		for i = 1, 6 do
			task.delay(i * 0.05, function()
				local at = data.Position + data.Direction * (i * (data.Length or 34) / 6)
				local p = VFXLib.part({ Size = Vector3.new(0.4, 6, 6), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.2, Shape = Enum.PartType.Cylinder })
				VFXLib.animate(0.4, function(a)
					p.CFrame = CFrame.lookAt(at, at + data.Direction) * CFrame.Angles(0, math.pi / 2, a * 6)
					p.Transparency = 0.2 + 0.8 * a
				end, function()
					p:Destroy()
				end)
			end)
		end
	elseif who == "Diego" then
		if data.Phase == "Leap" then
			for i = 0, 6 do
				local t = i / 6
				local p = data.From:Lerp(data.To, t) + Vector3.new(0, math.sin(t * math.pi) * 10, 0)
				task.delay(t * (data.Time or 0.45), function()
					VFXLib.afterimage(CFrame.new(p), 2.4, pal.Main)
				end)
			end
		elseif data.Phase == "Slam" then
			ring(data.Position, data.Radius or 10, pal.Main, 0.45)
			TuskVFX.CreateGroundCracks(data.Position, { Radius = data.Radius or 10, Color = pal.Main })
			CameraFX.shakeAt(data.Position, 0.8, 40)
		end
	elseif who == "PorkPie" and data.Phase == "Cast" then
		-- Hooks fly out in every direction and yank back in.
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			local out = data.Position + Vector3.new(math.cos(a), 0.3, math.sin(a)) * (data.Radius or 20)
			streak(data.Position + Vector3.new(0, 1, 0), out, Color3.fromRGB(200, 205, 215), 0.15, 0.4)
		end
		ring(data.Position, data.Radius or 20, pal.Main, 0.5)
	elseif who == "Sandman" then
		if data.Phase == "Dash" then
			streak(data.From, data.To, Color3.fromRGB(230, 200, 140), 1.2, 0.6)
			VFXLib.burst(data.From, { Count = 16, Color = Color3.fromRGB(230, 200, 140), Speed = 14, Lifetime = 0.5 })
		elseif data.Phase == "Boom" then
			ring(data.Position, 9, pal.Main, 0.4)
			TuskVFX.CreateImpactStar(data.Position + Vector3.new(0, 1, 0), { Size = 7, Rays = 10, Color = pal.Main, Color2 = GOLD, Duration = 0.2 })
		end
	elseif who == "MountainTim" and data.Phase == "Spin" then
		-- A lasso loop spinning round him, closing in.
		local loop = {}
		for i = 1, 16 do
			loop[i] = VFXLib.part({ Size = Vector3.new(0.3, 0.3, 2.4), Color = Color3.fromRGB(205, 170, 110), Material = Enum.Material.Fabric })
		end
		VFXLib.animate(data.Time or 0.8, function(a)
			local r = Common.rootOf(character)
			local c = r and r.Position or data.Position
			local radius = (data.Radius or 14) * (1 - 0.7 * a)
			for i, seg in ipairs(loop) do
				local ang = i / #loop * math.pi * 2 + a * 12
				local p = c + Vector3.new(math.cos(ang) * radius, 1, math.sin(ang) * radius)
				seg.CFrame = CFrame.lookAt(p, p + Vector3.new(-math.sin(ang), 0, math.cos(ang)))
			end
		end, function()
			for _, seg in ipairs(loop) do
				seg:Destroy()
			end
		end)
	elseif who == "HotPants" then
		if data.Phase == "Cocoon" then
			shell(character, Color3.fromRGB(236, 150, 170), Enum.Material.SmoothPlastic, data.Time or 2)
		elseif data.Phase == "Burst" then
			ring(data.Position, 9, Color3.fromRGB(236, 150, 170), 0.4)
			VFXLib.burst(data.Position, { Count = 24, Color = Color3.fromRGB(236, 150, 170), Speed = 18, Lifetime = 0.45 })
		end
	elseif who == "Blackmore" and data.Phase == "Curtain" then
		-- Frozen drops fly out in a cone.
		for i = 1, 24 do
			local ang = math.rad((math.random() - 0.5) * (data.Cone or 70))
			local dir = (CFrame.lookAt(Vector3.new(), data.Direction) * CFrame.Angles(0, ang, 0)).LookVector
			local from = data.Position + Vector3.new(0, 1 + math.random() * 2, 0)
			local d = VFXLib.part({ Size = Vector3.new(0.25, 0.5, 0.25), Color = Color3.fromRGB(150, 205, 255), Material = Enum.Material.Glass, Transparency = 0.2 })
			VFXLib.animate(0.35, function(a)
				local p = from + dir * (data.Range or 26) * a
				d.CFrame = CFrame.lookAt(p, p + dir) * CFrame.Angles(math.pi / 2, 0, 0)
			end, function()
				d:Destroy()
			end)
		end
	elseif who == "Axl" and data.Phase == "Flood" then
		ring(data.Position, data.Radius or 22, pal.Main, 0.6)
		VFXLib.burst(data.Position, { Count = 30, Color = Color3.fromRGB(150, 130, 170), Speed = 16, Lifetime = 0.6 })
	elseif who == "DiegoAU" and data.Phase == "Draw" and character then
		TuskAnimation.play(character, "DWRevolver")
		drawRevolver(character, data)
	elseif who == "DiegoAU" and data.Phase == "Shot" then
		local gun = revolvers[character]
		local muzzle = gun and gun.Muzzle and gun.Muzzle() or data.Position
		if gun then
			gun.Kick = os.clock()
			gun.Spin = gun.Spin + math.pi / 3 -- the cylinder turns one chamber
		end
		if muzzle then
			-- Muzzle flash (a bright star), a puff of smoke.
			local dir = data.Direction or Vector3.new(0, 0, -1)
			local flash = VFXLib.part({ Size = Vector3.new(0.9, 0.9, 0.9), CFrame = CFrame.new(muzzle), Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Neon, Shape = Enum.PartType.Ball })
			local cone = VFXLib.part({ Size = Vector3.new(0.5, 0.5, data.Last and 2.4 or 1.6), CFrame = CFrame.lookAt(muzzle, muzzle + dir) * CFrame.new(0, 0, -0.8), Color = Color3.fromRGB(255, 190, 80), Material = Enum.Material.Neon })
			VFXLib.animate(0.09, function(a)
				flash.Transparency = a
				cone.Transparency = a
			end, function()
				flash:Destroy()
				cone:Destroy()
			end)
			VFXLib.burst(muzzle, { Count = data.Last and 10 or 5, Color = Color3.fromRGB(200, 196, 190), Speed = 4, Lifetime = 0.45 })
			-- A spent glint pops out sideways.
			VFXLib.burst(muzzle, { Count = 1, Color = Color3.fromRGB(220, 180, 90), Speed = 10, Lifetime = 0.3, Direction = Vector3.new(0, 1, 0), Spread = 60 })
		end
		if local_ then
			CameraFX.shake(data.Last and 0.3 or 0.15, 0.06)
		end
	elseif who == "Josuke" and data.Phase == "Silence" and data.Position then
		-- A ring of bubbles bursts out; the sound goes with them.
		ring(data.Position, data.Radius or 20, Color3.fromRGB(170, 220, 255), 0.5)
		for k = 1, 16 do
			local a = k / 16 * math.pi * 2
			local b = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), Color = Color3.fromRGB(200, 235, 255), Material = Enum.Material.Glass, Transparency = 0.4 })
			local from = data.Position + Vector3.new(0, 2, 0)
			local to = from + Vector3.new(math.cos(a), 0.2, math.sin(a)) * (data.Radius or 20)
			VFXLib.animate(0.5, function(t)
				b.CFrame = CFrame.new(from:Lerp(to, t))
				b.Transparency = 0.4 + 0.6 * t
			end, function()
				b:Destroy()
			end)
		end
	elseif who == "Jodio" then
		-- (November Rain's cloud and crush are drawn by JodioVFX.)
	elseif who == "Joseph" and data.Phase == "Hamon" and data.Position then
		-- HAMON BEAT: a golden ripple across the ground.
		ring(data.Position, data.Radius or 16, Color3.fromRGB(255, 214, 80), 0.5)
	elseif who == "Dio" and data.Phase == "Drain" and data.Position then
		-- WRYYY: a blood-red ring pulling in.
		ring(data.Position, data.Radius or 18, Color3.fromRGB(190, 20, 30), 0.6)
	elseif who == "Jotaro" and data.Phase == "Barrage" and data.Position then
		-- ORA BARRAGE: a violet ring of punches spreading out round him.
		ring(data.Position, data.Radius or 16, Color3.fromRGB(150, 120, 255), data.Time or 0.5)
	elseif who == "Ringo" and data.Phase == "Rewind" and data.Position then
		-- SECOND HAND: a pink ring sweeps out; everyone in it loses 6 seconds.
		ring(data.Position, data.Radius or 20, Color3.fromRGB(240, 130, 180), 0.6)
	elseif who == "Tooru" and data.Phase == "Calamity" and data.Position then
		-- A dark maroon ring sweeps out: misfortune finds everyone in it.
		ring(data.Position, data.Radius or 24, Color3.fromRGB(150, 40, 50), 0.6)
		VFXLib.burst(data.Position + Vector3.new(0, 2, 0), { Count = 18, Color = Color3.fromRGB(120, 90, 60), Speed = 14, Lifetime = 0.8 })
	elseif who == "Valentine" then
		if data.Phase == "Bless" then
			shell(character, Color3.fromRGB(255, 250, 225), Enum.Material.ForceField, data.Time or 2.5)
		elseif data.Phase == "Pulse" then
			ring(data.Position, data.Radius or 12, Color3.fromRGB(255, 250, 225), 0.45)
		end
	end
	if local_ and (data.Phase == "Slam" or data.Phase == "Boom" or data.Phase == "Burst" or data.Phase == "Pulse") then
		CameraFX.shake(0.5, 0.2)
	end
end

---------------------------------------------------------------------------
-- CORPSE COMPASS (bounty board shop): while it lasts, a gold arrow floats
-- ahead of you pointing at the nearest part lying out in the desert, with
-- how far it is.
---------------------------------------------------------------------------
local compass
local function stepCompass()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local active = root and (character:GetAttribute("CompassUntil") or 0) > workspace:GetServerTimeNow()
	local best, bestD
	if active then
		for _, relic in ipairs(CollectionService:GetTagged("SpinCorpse")) do
			if relic.Parent then
				local d = (relic:GetPivot().Position - root.Position).Magnitude
				if not bestD or d < bestD then
					best, bestD = relic, d
				end
			end
		end
	end
	if not best then
		if compass then
			compass.Model:Destroy()
			compass = nil
		end
		return
	end
	if not compass then
		local m = Instance.new("Model")
		m.Name = "CorpseCompass"
		m.Parent = VFXLib.Folder
		local shaft = VFXLib.part({ Size = Vector3.new(0.3, 0.3, 2.2), Color = Color3.fromRGB(255, 210, 90), Material = Enum.Material.Neon })
		shaft.Parent = m
		local head = VFXLib.part({ Size = Vector3.new(1.1, 0.3, 0.9), Color = Color3.fromRGB(255, 236, 160), Material = Enum.Material.Neon })
		head.Parent = m
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(120, 26)
		bb.StudsOffset = Vector3.new(0, 1, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Adornee = shaft
		-- A little nailed wooden plaque with the part and distance.
		local board = new("Frame", { Size = UDim2.fromScale(1, 1) }, bb)
		UITheme.wood(board, { Planks = 1, Border = 2, Radius = 5 })
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(10, 2)
		label.Size = UDim2.new(1, -20, 1, -4)
		label.ZIndex = 3
		label.Font = Enum.Font.Bangers
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 220, 120)
		label.TextStrokeColor3 = T.WOOD_EDGE
		label.TextStrokeTransparency = 0.4
		label.Parent = board
		bb.Parent = m
		compass = { Model = m, Shaft = shaft, Head = head, Label = label }
	end
	local to = best:GetPivot().Position - root.Position
	local flat = Vector3.new(to.X, 0, to.Z)
	flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
	local at = root.Position + flat * 4 + Vector3.new(0, 2.2 + math.sin(os.clock() * 3) * 0.15, 0)
	local cf = CFrame.lookAt(at, at + flat)
	compass.Shaft.CFrame = cf
	compass.Head.CFrame = cf * CFrame.new(0, 0, -1.3) * CFrame.Angles(0, math.pi / 4, 0)
	compass.Label.Text = string.format("%s  %dm", string.upper(best:GetAttribute("PartId") or "PART"), math.floor(bestD))
end

---------------------------------------------------------------------------
function CorpseClient.init()
	cfg = TuskConfig.Corpse
	if not cfg or cfg.Enabled == false then
		return
	end
	for _, info in ipairs(cfg.Parts) do
		partInfo[info.Id] = info
	end
	buildUI()
	local keys = TuskConfig.Keys.CorpseMove or {}
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == keys.Keyboard or input.KeyCode == keys.Gamepad then
			useMove()
		end
	end)
	Net.get("WorldFX").OnClientEvent:Connect(function(name, data)
		if typeof(data) ~= "table" then
			return
		end
		if name == "CorpseTaken" then
			local info = partInfo[data.Part]
			local partName = info and info.Name or tostring(data.Part)
			if data.Player == player.UserId then
				showBanner("YOU TOOK THE " .. partName .. "!  " .. (info and string.upper(info.Text) or ""))
			else
				showFeed((data.Name or "Someone") .. " took the Saint's Corpse " .. partName .. "!")
			end
		elseif name == "CorpseDropped" then
			local info = partInfo[data.Part]
			showFeed("The " .. (info and info.Name or "part") .. " fell where " .. (data.Name or "someone") .. " died!")
			if data.Position then
				ring(data.Position, 8, GOLD, 0.6)
			end
		elseif name == "CorpseMove" then
			onMove(data)
		elseif name == "CorpseComplete" then
			if data.Player == player.UserId then
				showBanner("THE COMPLETE SAINT'S CORPSE!  PRESS V: THE SAINT'S MIRACLE")
			else
				showBanner(string.upper(data.Name or "SOMEONE") .. " HAS THE COMPLETE SAINT'S CORPSE!")
			end
		elseif name == "CorpseScattered" then
			showFeed("The Saint's Corpse leaves " .. (data.Name or "them") .. " and scatters across the desert!")
		end
	end)
	RunService.RenderStepped:Connect(function()
		stepPanel()
		stepRelics(os.clock())
		stepHalos(os.clock())
		stepCompass()
	end)
end

return CorpseClient
end

-- ======================================================================
-- MODULE: Cutscenes
-- ======================================================================
__modules["Cutscenes"] = function()
--[[
	Cutscenes  (StarterPlayerScripts.SpinClient.Cutscenes)

	Short cinematic camera moves, with black letterbox bars and a title card
	in the bounty board's style (Bangers on a nailed wooden sign). Every
	cutscene can be skipped (SKIP button, Enter, or the controller's Select).
	Settings: TuskConfig.Cutscenes (each one can be turned off).

	The cutscenes:
	  * WELCOME (once per session, when you first spawn): a fly-over of the
	    desert, the ghost town and the race track, then down to you
	  * STEEL BALL RUN STAGE INTROS: during each stage's countdown, the camera
	    sweeps from high over the stage start down to behind your horse, with
	    "STAGE 3 · ROCKY MOUNTAINS" and its tagline
	  * RACE WINNER: at the end of the race the camera circles the overall
	    winner ("WINNER", their name and points)
	  * ULTIMATES: a quick close-up push-in on you with your ultimate's name
	    (under a second, so you're never out of the fight for long)
	  * THE COMPLETE SAINT'S CORPSE: a slow golden orbit round you

	Engine: Cutscenes.play(shots, opts). A shot is { From, To, Time, FOV =
	{ start, finish }, Title, Subtitle, Color }; From / To are CFrames or
	functions returning one (to follow something that moves). opts.Priority:
	a cutscene only interrupts a lower-priority one. The camera always goes
	back to exactly what it was following before (you, a horse, John Rod...).

	SHIFT LOCK: with shift lock on, Roblox turns your character to face
	wherever the camera looks, so an orbiting cutscene camera used to spin
	you round and round. While a cutscene plays, shift lock is switched off
	(and the mouse freed); it's switched back on afterwards if you had it on.
	The camera is moved after Roblox's own camera each frame, so it doesn't
	fight it (no jitter).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local Net = __require("Net")
local UITheme = __require("UITheme")

local Cutscenes = {}
local player = Players.LocalPlayer
local cfg = TuskConfig.Cutscenes or {}
local C = UITheme.C

local gui, topBar, bottomBar, titleSign, titleText, subText, skipButton
local playing -- the cutscene running now

local function enabled(kind)
	return cfg.Enabled ~= false and (kind == nil or cfg[kind] ~= false)
end

local function easeInOut(a)
	return a < 0.5 and 4 * a * a * a or 1 - ((-2 * a + 2) ^ 3) / 2
end

local function resolve(cf)
	if type(cf) == "function" then
		local ok, v = pcall(cf)
		return ok and v or nil
	end
	return cf
end

---------------------------------------------------------------------------
-- The overlay: letterbox bars, a title sign, a skip button
---------------------------------------------------------------------------
local function buildUI()
	gui = UITheme.new("ScreenGui", { Name = "SpinCutscene", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, Enabled = false }, player:WaitForChild("PlayerGui"))
	topBar = UITheme.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0) }, gui)
	bottomBar = UITheme.new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 0) }, gui)
	titleSign = UITheme.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.13, 6), Size = UDim2.fromOffset(440, 74), Visible = false, ZIndex = 2 }, gui)
	UITheme.wood(titleSign, { Planks = 2, Border = 4, Brackets = true, BracketSize = 14 })
	UITheme.new("UISizeConstraint", { MaxSize = Vector2.new(440, 74) }, titleSign)
	titleText = UITheme.label(titleSign, { Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -28, 0, 44), Text = "", Font = UITheme.Font.Title, TextColor3 = C.GOLD, TextStrokeTransparency = 0.3, TextStrokeColor3 = C.WOOD_EDGE, ZIndex = 4 })
	subText = UITheme.label(titleSign, { Position = UDim2.fromOffset(14, 48), Size = UDim2.new(1, -28, 0, 18), Text = "", Font = UITheme.Font.Body, TextColor3 = C.PAPER, ZIndex = 4 })
	UITheme.new("UIScale", { Scale = 1 }, titleSign)
	skipButton = UITheme.button(gui, "SKIP  ▶", C.WOOD_LIGHT, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -16), Size = UDim2.fromOffset(110, 38), ZIndex = 5 })
	skipButton.Activated:Connect(function()
		Cutscenes.stop()
	end)
end

local function showTitle(title, subtitle, color)
	if not title then
		titleSign.Visible = false
		return
	end
	titleText.Text = title
	titleText.TextColor3 = color or C.GOLD
	subText.Text = subtitle or ""
	subText.Visible = subtitle ~= nil
	titleSign.Size = UDim2.fromOffset(440, subtitle and 74 or 56)
	titleSign.Visible = true
	UITheme.pop(titleSign, 0.6)
end

local function bars(on)
	local size = on and UDim2.fromScale(1, 0.11) or UDim2.fromScale(1, 0)
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(topBar, info, { Size = size }):Play()
	TweenService:Create(bottomBar, info, { Size = size }):Play()
end

---------------------------------------------------------------------------
-- The engine
---------------------------------------------------------------------------
local function restoreCamera(saved)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local subject = saved.Subject
	if not (subject and subject.Parent) then
		subject = hum
	end
	-- Hand back from behind your character (not wherever the last shot
	-- ended, e.g. facing you), so the normal camera picks up naturally.
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and subject == hum then
		local behind = (root.CFrame * CFrame.new(0, 3, 11)).Position
		camera.CFrame = CFrame.lookAt(behind, root.Position + Vector3.new(0, 1.5, 0))
	end
	camera.CameraSubject = subject
	camera.CameraType = saved.Type == Enum.CameraType.Scriptable and Enum.CameraType.Custom or (saved.Type or Enum.CameraType.Custom)
	camera.FieldOfView = saved.FOV or 70
end

-- Shift lock off for the cutscene (it would turn you to face the camera).
local gameSettings
pcall(function()
	gameSettings = UserSettings():GetService("UserGameSettings")
end)

local function holdStill()
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
	if gameSettings then
		pcall(function()
			if gameSettings.RotationType ~= Enum.RotationType.MovementRelative then
				gameSettings.RotationType = Enum.RotationType.MovementRelative
			end
		end)
	end
end

local function releaseMouseLock(run)
	run.MouseLock = player.DevEnableMouseLock
	run.WasLocked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	pcall(function()
		player.DevEnableMouseLock = false
	end)
	holdStill()
end

local function restoreMouseLock(run)
	if run.MouseLock ~= nil then
		pcall(function()
			player.DevEnableMouseLock = run.MouseLock
		end)
	end
	-- Shift lock was on: turn it back on (the camera scripts' own toggle).
	if run.WasLocked and run.MouseLock then
		task.defer(function()
			pcall(function()
				local pm = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 2))
				local cams = pm:GetCameras()
				local mlc = cams and cams.activeMouseLockController
				if mlc and mlc.GetIsMouseLocked and not mlc:GetIsMouseLocked() and mlc.OnMouseLockToggled then
					mlc:OnMouseLockToggled()
				end
			end)
		end)
	end
end

local function finish(run, skipped)
	if playing ~= run then
		return
	end
	playing = nil
	pcall(function()
		RunService:UnbindFromRenderStep("SpinCutscene")
	end)
	if run.Conn then
		run.Conn:Disconnect()
	end
	restoreMouseLock(run)
	ContextActionService:UnbindAction("SpinCutsceneSkip")
	restoreCamera(run.Saved)
	showTitle(nil)
	bars(false)
	task.delay(0.4, function()
		if not playing and gui then
			gui.Enabled = false
		end
	end)
	if run.OnEnd then
		pcall(run.OnEnd, skipped)
	end
end

function Cutscenes.isPlaying()
	return playing ~= nil
end

function Cutscenes.stop()
	if playing then
		finish(playing, true)
	end
end

function Cutscenes.play(shots, opts)
	opts = opts or {}
	local camera = workspace.CurrentCamera
	if not camera or not gui or #shots == 0 then
		return false
	end
	local priority = opts.Priority or 1
	if playing then
		if playing.Priority >= priority then
			return false
		end
		finish(playing, true)
	end
	local run = {
		Priority = priority,
		OnEnd = opts.OnEnd,
		Saved = { Type = camera.CameraType, Subject = camera.CameraSubject, FOV = camera.FieldOfView },
		Shot = 0,
	}
	playing = run
	gui.Enabled = true
	skipButton.Visible = opts.Skippable ~= false
	bars(opts.Letterbox ~= false)
	if opts.Skippable ~= false then
		ContextActionService:BindActionAtPriority("SpinCutsceneSkip", function(_, state)
			if state == Enum.UserInputState.Begin then
				Cutscenes.stop()
			end
			return Enum.ContextActionResult.Sink
		end, false, 4000, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonSelect)
	end
	releaseMouseLock(run)
	camera.CameraType = Enum.CameraType.Scriptable
	local index, started = 1, os.clock()
	local function begin(i)
		local shot = shots[i]
		run.Shot = i
		started = os.clock()
		showTitle(shot.Title, shot.Subtitle, shot.Color)
	end
	begin(1)
	-- After Roblox's own camera each frame, so nothing fights the move.
	RunService:BindToRenderStep("SpinCutscene", Enum.RenderPriority.Camera.Value + 2, function()
		if playing ~= run then
			return
		end
		camera = workspace.CurrentCamera or camera
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		holdStill()
		local shot = shots[index]
		local a = math.clamp((os.clock() - started) / math.max(shot.Time or 2, 0.05), 0, 1)
		local from, to = resolve(shot.From), resolve(shot.To or shot.From)
		if from and to then
			local e = shot.Linear and a or easeInOut(a)
			camera.CFrame = from:Lerp(to, e)
			if shot.FOV then
				camera.FieldOfView = shot.FOV[1] + (shot.FOV[2] - shot.FOV[1]) * e
			end
		end
		if a >= 1 then
			index = index + 1
			if index > #shots then
				finish(run, false)
			else
				begin(index)
			end
		end
	end)
	return true
end

---------------------------------------------------------------------------
-- The cutscenes
---------------------------------------------------------------------------
local function myRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function look(fromPos, atPos)
	return CFrame.lookAt(fromPos, atPos)
end

-- Welcome: a fly-over of the main map, then down to you.
local function intro()
	local map = workspace:FindFirstChild("SBRMap")
	local root = myRoot()
	if not map or not root then
		return
	end
	local o = map:GetAttribute("Origin") or Vector3.new()
	local ghost = o + Vector3.new(-170, 0, -40)
	local track = o + Vector3.new(0, 0, 118)
	Cutscenes.play({
		{ From = look(o + Vector3.new(-380, 170, 380), o), To = look(o + Vector3.new(380, 170, 380), o), Time = 4.2, FOV = { 70, 62 },
			Title = "SPIN BATTLEGROUNDS", Subtitle = "THE STEEL BALL RUN" },
		{ From = look(ghost + Vector3.new(-70, 14, 40), ghost), To = look(ghost + Vector3.new(50, 10, 40), ghost + Vector3.new(0, 4, 0)), Time = 3.2,
			Title = "THE SAINT'S CORPSE", Subtitle = "ITS PARTS ARE SCATTERED ACROSS THE DESERT. FIGHT FOR THEM." },
		{ From = look(track + Vector3.new(0, 40, 80), track + Vector3.new(0, 0, -60)), To = look(track + Vector3.new(0, 14, -20), track + Vector3.new(0, 4, -160)), Time = 3,
			Title = "THE RACE", Subtitle = "EVERY 10 MINUTES: SAN DIEGO TO NEW YORK, NINE STAGES" },
		{ From = function()
			local r = myRoot()
			return r and look(r.Position + Vector3.new(0, 40, 40), r.Position) or nil
		end, To = function()
			local r = myRoot()
			return r and look((r.CFrame * CFrame.new(0, 5, 13)).Position, r.Position + Vector3.new(0, 2, 0)) or nil
		end, Time = 1.8, Title = "CHOOSE YOUR STAND", Subtitle = "PRESS T FOR THE CHARACTER MENU" },
	}, { Priority = 1 })
end

-- A stage of the Steel Ball Run: high over the start, down to behind your horse.
local function stageIntro(data)
	local root = myRoot()
	local course = workspace:FindFirstChild("SteelBallRunCourse")
	if not root or not course then
		return
	end
	local line = course:FindFirstChild("StartLine")
	local gate = course:FindFirstChild("Gate_1")
	local start = line and line.Position or root.Position
	local ahead = gate and gate:GetPivot().Position or (start + root.CFrame.LookVector * 100)
	local dir = Vector3.new(ahead.X - start.X, 0, ahead.Z - start.Z)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, -1)
	local title = "STAGE " .. tostring(data.Index or "?") .. " · " .. string.upper(data.Name or "")
	Cutscenes.play({
		{ From = look(start - dir * 60 + Vector3.new(0, 70, 0), start + dir * 120), To = look(start + dir * 30 + Vector3.new(0, 34, 0), start + dir * 160), Time = 1.6, FOV = { 72, 64 },
			Title = title, Subtitle = data.Tagline and string.upper(data.Tagline) or nil },
		{ From = function()
			local r = myRoot()
			return r and look(r.Position + dir * 10 + Vector3.new(0, 20, 0), r.Position) or nil
		end, To = function()
			local r = myRoot()
			return r and look(r.Position - dir * 13 + Vector3.new(0, 6, 0), r.Position + dir * 20) or nil
		end, Time = 1.1, FOV = { 64, 70 }, Title = title, Subtitle = data.Tagline and string.upper(data.Tagline) or nil },
	}, { Priority = 3 })
end

-- The race winner: circle them.
local function winnerOrbit(row)
	local target
	if row.UserId and row.UserId > 0 then
		local p = Players:GetPlayerByUserId(row.UserId)
		target = p and p.Character
	end
	if not target and row.Name then
		target = workspace:FindFirstChild(row.Name, true)
	end
	local root = target and target:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local startAngle = math.random() * math.pi * 2
	local function orbit(k)
		return function()
			if not root.Parent then
				return nil
			end
			local a = startAngle + k
			return look(root.Position + Vector3.new(math.cos(a) * 15, 6, math.sin(a) * 15), root.Position + Vector3.new(0, 2, 0))
		end
	end
	Cutscenes.play({
		{ From = orbit(0), To = orbit(1.4), Time = 3.4, Linear = true, FOV = { 60, 55 },
			Title = "WINNER: " .. string.upper(row.Name or "?"), Subtitle = tostring(row.Points or 0) .. " POINTS · THE STEEL BALL RUN" },
	}, { Priority = 4 })
end

-- Your ultimate: a quick close-up push-in with its name.
local lastUlt = -math.huge
local function ultimateCloseUp(character, act)
	if os.clock() - lastUlt < 4 then
		return
	end
	lastUlt = os.clock()
	local info = Registry.get(act)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not info then
		return
	end
	local who
	for _, entry in ipairs(TuskConfig.Roster or {}) do
		if entry.Id == info.Character then
			who = entry.Name
		end
	end
	local theme = info.Theme and info.Theme.Primary or C.GOLD
	Cutscenes.play({
		{ From = function()
			return root.Parent and look((root.CFrame * CFrame.new(1.5, 2, -8)).Position, root.Position + Vector3.new(0, 1.6, 0)) or nil
		end, To = function()
			return root.Parent and look((root.CFrame * CFrame.new(0.8, 2.1, -5.2)).Position, root.Position + Vector3.new(0, 1.8, 0)) or nil
		end, Time = 0.9, FOV = { 55, 42 }, Title = string.upper(info.Ultimate or "ULTIMATE"), Subtitle = who, Color = theme:Lerp(Color3.new(1, 1, 1), 0.3) },
	}, { Priority = 2, Skippable = true })
end

-- The complete Saint's Corpse: a slow golden orbit.
local function corpseOrbit()
	local root = myRoot()
	if not root then
		return
	end
	local function orbit(k)
		return function()
			if not root.Parent then
				return nil
			end
			return look(root.Position + Vector3.new(math.cos(k) * 12, 5, math.sin(k) * 12), root.Position + Vector3.new(0, 2, 0))
		end
	end
	Cutscenes.play({
		{ From = orbit(0), To = orbit(math.pi), Time = 3.5, Linear = true, FOV = { 62, 52 },
			Title = "THE SAINT'S CORPSE", Subtitle = "IS COMPLETE · PRESS V: THE SAINT'S MIRACLE", Color = Color3.fromRGB(255, 225, 120) },
	}, { Priority = 4 })
end

function Cutscenes.init()
	buildUI()
	-- Welcome, once a session, a moment after you first spawn.
	if enabled("Intro") then
		task.spawn(function()
			local character = player.Character or player.CharacterAdded:Wait()
			character:WaitForChild("HumanoidRootPart", 15)
			task.wait(cfg.IntroDelay or 2)
			intro()
		end)
	end
	-- The race.
	local racing = false
	Net.get("Race").OnClientEvent:Connect(function(kind, data)
		data = typeof(data) == "table" and data or {}
		if kind == "Stage" and player:GetAttribute("RaceEntered") then
			racing = true
			if enabled("RaceStages") then
				-- (The riders are being lined up: start a beat later.)
				task.delay(0.25, function()
					stageIntro(data)
				end)
			end
		elseif kind == "Results" then
			local wasRacing = racing
			racing = false
			if wasRacing and data.Final and enabled("RaceWinner") and data.List and data.List[1] then
				winnerOrbit(data.List[1])
			end
		elseif kind == "Out" or kind == "Cancelled" then
			racing = false
		end
	end)
	-- Your ultimate.
	Net.get("TuskFX").OnClientEvent:Connect(function(name, data)
		if name == "Ultimate" and typeof(data) == "table" and data.Character and data.Character == player.Character and data.Act and enabled("Ultimates") then
			ultimateCloseUp(data.Character, data.Act)
		end
	end)
	-- The complete Saint's Corpse.
	Net.get("WorldFX").OnClientEvent:Connect(function(name, data)
		if name == "CorpseComplete" and typeof(data) == "table" and data.Player == player.UserId and enabled("CorpseComplete") then
			corpseOrbit()
		end
	end)
	-- Respawning mid-cutscene: just stop it.
	player.CharacterAdded:Connect(function()
		Cutscenes.stop()
	end)
end

return Cutscenes
end

-- ======================================================================
-- MODULE: DefenseClient
-- ======================================================================
__modules["DefenseClient"] = function()
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
	  * the popup words are in the bounty board's style (UI.UITheme): tilted
	    Bangers with a chunky dark-wood outline. The mobile BLOCK / DASH
	    buttons are ContextActionService's own.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local UITheme = __require("UITheme")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Fighters = __require("Fighters")
local Common = __require("TuskActCommon")

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

-- Popup words (PERFECT DODGE, COUNTER READY, PERFECT!, GUARD BREAK) in the
-- bounty board's style: Bangers with a chunky dark-wood outline, a soft
-- light-to-shade gradient and a slight comic tilt. Returns the label and a
-- function that fades it (0 = solid, 1 = gone).
local function popupLabel(parent, text, color)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = UITheme.Font.Title
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 1
	label.Rotation = -4
	local outline = Instance.new("UIStroke")
	outline.Color = UITheme.C.WOOD_EDGE
	outline.Thickness = 3
	outline.LineJoinMode = Enum.LineJoinMode.Round
	outline.Parent = label
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 205, 190))
	shade.Rotation = 90
	shade.Parent = label
	label.Parent = parent
	return label, function(t)
		label.TextTransparency = t
		outline.Transparency = t
	end
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
	bb.LightInfluence = 0
	local _, fade = popupLabel(bb, text, color)
	bb.Parent = VFXLib.Folder
	VFXLib.animate(0.9, function(a)
		bb.StudsOffset = Vector3.new(0, 2.6 + a * 1.2, 0)
		fade(math.max(0, (a - 0.6) / 0.4))
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
	local _, fade = popupLabel(gui, text, color)
	local start = carrier.Position
	VFXLib.animate(0.9, function(a)
		carrier.Position = start + Vector3.new(0, a * 2, 0)
		fade(math.max(0, (a - 0.6) / 0.4))
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
end

-- ======================================================================
-- MODULE: Fighters
-- ======================================================================
__modules["Fighters"] = function()
--[[
	Fighters  (StarterPlayerScripts.SpinClient.Fighters)

	Everyone who can use a Stand: the players plus the Stand-user NPCs
	(StandBots, tagged "SpinFighter" on the server). Returned in the same
	shape as Players:GetPlayers() ({ Character = model }), so visual code
	that loops over players draws the NPCs' Stands and effects too.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Fighters = {}
Fighters.Tag = "SpinFighter"

function Fighters.list()
	local out = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(out, player)
	end
	for _, model in ipairs(CollectionService:GetTagged(Fighters.Tag)) do
		if model.Parent then
			table.insert(out, { Character = model })
		end
	end
	return out
end

return Fighters
end

-- ======================================================================
-- MODULE: HitFX
-- ======================================================================
__modules["HitFX"] = function()
--[[
	HitFX  (StarterPlayerScripts.SpinClient.HitFX)
	Feedback for every hit in the game (any character):
	  * victim flash (white, or blue when blocked) + camera shake for the victim
	  * floating damage numbers for the attacker
	Driven by the shared "Hit" / "Damage" events from CombatAdapter.
]]

local Players = game:GetService("Players")

local Shared = nil -- (bundled: modules are inlined)
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")

local TuskVFX = __require("TuskVFX")

local HitFX = {}
local localPlayer = Players.LocalPlayer
local colors = {
	Gold = Color3.fromRGB(255, 196, 56),
	Perfect = Color3.fromRGB(255, 250, 210),
	GoldLight = Color3.fromRGB(255, 238, 160),
}

local function onHit(data)
	if not data.Victim then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Adornee = data.Victim
	highlight.FillColor = data.Blocked and Color3.fromRGB(140, 200, 255) or Color3.new(1, 1, 1)
	highlight.OutlineColor = data.Blocked and Color3.fromRGB(80, 160, 255) or colors.Gold
	highlight.FillTransparency = 0.3
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = VFXLib.Folder
	VFXLib.animate(0.18, function(a)
		highlight.FillTransparency = 0.3 + 0.7 * a
		highlight.OutlineTransparency = a
	end, function()
		highlight:Destroy()
	end)
	-- Starburst coloured by who landed it: cyan for Johnny, green for Gyro, blue for Diego, bamboo green for Pork Pie Hat Kid.
	local source = tostring(data.Source or "")
	local starColor = Color3.fromRGB(90, 230, 255)
	if source:sub(1, 4) == "Gyro" then
		starColor = Color3.fromRGB(120, 225, 95)
	elseif source:sub(1, 6) == "Joseph" then
		starColor = Color3.fromRGB(255, 214, 80)
	elseif source:sub(1, 3) == "Dio" then
		starColor = Color3.fromRGB(255, 210, 70)
	elseif source:sub(1, 6) == "Jotaro" then
		starColor = Color3.fromRGB(170, 150, 255)
	elseif source:sub(1, 5) == "Ringo" then
		starColor = Color3.fromRGB(246, 204, 40)
	elseif source:sub(1, 7) == "JohnRod" then
		starColor = Color3.fromRGB(220, 230, 250)
	elseif source:sub(1, 5) == "Jodio" then
		starColor = Color3.fromRGB(110, 190, 250)
	elseif source:sub(1, 5) == "Tooru" then
		starColor = Color3.fromRGB(240, 196, 60)
	elseif source:sub(1, 6) == "Josuke" then
		starColor = Color3.fromRGB(120, 190, 240)
	elseif source:sub(1, 7) == "DiegoAU" then
		starColor = Color3.fromRGB(236, 196, 70)
	elseif source:sub(1, 5) == "Diego" then
		starColor = Color3.fromRGB(60, 120, 255)
	elseif source:sub(1, 7) == "PorkPie" then
		starColor = Color3.fromRGB(165, 215, 80)
	elseif source:sub(1, 7) == "Sandman" then
		starColor = Color3.fromRGB(245, 185, 80)
	elseif source:sub(1, 11) == "MountainTim" then
		starColor = Color3.fromRGB(214, 156, 84)
	elseif source:sub(1, 8) == "HotPants" then
		starColor = Color3.fromRGB(242, 140, 172)
	elseif source:sub(1, 9) == "Blackmore" then
		starColor = Color3.fromRGB(110, 180, 255)
	elseif source:sub(1, 9) == "Valentine" then
		starColor = Color3.fromRGB(120, 170, 255)
	elseif source:sub(1, 3) == "Axl" then
		starColor = Color3.fromRGB(214, 60, 70)
	end
	if data.Perfect then
		starColor = colors.Gold
	end
	if data.Position and not data.Blocked then
		TuskVFX.CreateImpactStar(data.Position, { Size = 2.2 + (data.Level or 1) * 0.9, Rays = 6 + (data.Level or 1), Color = starColor, Color2 = Color3.new(1, 1, 1), Duration = 0.18 + (data.Level or 1) * 0.03 })
		-- Sparks thrown away from the attacker, a quick shock ring, a white pop.
		local away
		local attacker = data.AttackerId and Players:GetPlayerByUserId(data.AttackerId)
		local ar = attacker and attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
		if ar then
			local d = data.Position - ar.Position
			away = d.Magnitude > 0.1 and d.Unit or nil
		end
		VFXLib.burst(data.Position, { Count = 10, Color = starColor, Speed = 34, Lifetime = 0.28, Spread = away and 40 or 180, Direction = away, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }) })
		VFXLib.burst(data.Position, { Count = 4, Color = Color3.new(1, 1, 1), Speed = 6, Lifetime = 0.12, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) }) })
		local look = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or data.Position + Vector3.new(0, 0, 1)
		TuskVFX.CreateRotationalShockwave(CFrame.lookAt(data.Position, look) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = 2.6, Layers = 1, Color = starColor, Color2 = Color3.new(1, 1, 1), Particles = 0, Width = 0.12, Duration = 0.18 })
		-- Your own hits kick the camera a little.
		if data.AttackerId == localPlayer.UserId then
			CameraFX.shake(0.12 + (data.Level or 1) * 0.05, 0.12)
		end
	end
	if data.Blocked then
		VFXLib.burst(data.Position, { Count = 12, Color = Color3.fromRGB(150, 210, 255), Speed = 25, Lifetime = 0.3 })
	end
	if localPlayer.Character and data.Victim == localPlayer.Character then
		CameraFX.shake(0.4 + (data.Level or 1) * 0.2, 0.3)
		if data.Perfect then
			CameraFX.impactFrame(colors.GoldLight)
		end
	end
end

-- Floating damage number, only for the attacker.
local function onDamage(data)
	local carrier = VFXLib.anchor(CFrame.new(data.Position + Vector3.new(math.random() - 0.5, 2, math.random() - 0.5)), 1.2)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 60)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = carrier
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.Rotation = (math.random() - 0.5) * 16
	label.Text = data.Blocked and ("BLOCKED " .. data.Amount) or (tostring(data.Amount) .. (data.Perfect and "!" or ""))
	label.TextColor3 = data.Blocked and Color3.fromRGB(170, 200, 230) or (data.Perfect and colors.Perfect or colors.Gold)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(60, 25, 0)
	label.Parent = billboard
	local start = carrier.Position
	local drift = Vector3.new((math.random() - 0.5) * 2, 0, (math.random() - 0.5) * 2)
	-- Bigger hits get bigger, redder numbers.
	local amount = tonumber(data.Amount) or 0
	local big = math.clamp((amount - 4) / 10, 0, 1)
	if not data.Blocked and not data.Perfect then
		label.TextColor3 = colors.Gold:Lerp(Color3.fromRGB(255, 80, 60), big)
	end
	local scale = 1 + big * 0.6
	VFXLib.animate(1, function(a)
		carrier.Position = start + drift * a + Vector3.new(0, a * 3 - a * a * 1.2, 0)
		label.TextTransparency = math.max(0, (a - 0.6) / 0.4)
		label.TextStrokeTransparency = label.TextTransparency
		local pop = a < 0.1 and (1 + (0.1 - a) * 4) or 1
		billboard.Size = UDim2.fromOffset(160 * pop * scale * (data.Perfect and 1.3 or 1), 60 * pop * scale * (data.Perfect and 1.3 or 1))
	end)
end

function HitFX.init()
	Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
		if name == "Hit" then
			onHit(data)
		elseif name == "Damage" then
			onDamage(data)
		end
	end)
end

return HitFX
end

-- ======================================================================
-- MODULE: HorseModel
-- ======================================================================
__modules["HorseModel"] = function()
--[[
	HorseModel  (ReplicatedStorage.SpinShared.HorseModel)

	A blocky racehorse for the Steel Ball Run, built from parts (no uploads):
	a long body, an arched neck with a mane, a head with a white blaze, ears
	and a dark muzzle, a swishing tail, four legs with white socks and
	hooves, and full tack: a red saddle blanket, a brown saddle with a horn,
	stirrups and reins.

	HorseModel.build(coat, mane, opts) -> model (PrimaryPart "Body", facing
	-Z, body centre at the origin, hooves 3.85 studs below it, the top of
	the saddle SaddleTop above it). opts (all optional):
	  Width     body width (default 1.9: slim, so a rider's legs go round it)
	  Blanket   saddle blanket colour      Saddle  saddle / tack colour
	  Material  coat material (e.g. Metal for the Golden Steed)
	  Socks     sock colour (false: no socks)
	The server builds race and ride horses; the shop builds a preview. Every limb is
	joined to the body with a Weld; clients animate the gallop by changing
	those welds' C0 (RaceClient). Each animated part carries attributes:
	  Joint (Vector3, where it pivots on the body) and Drop (studs from the
	  pivot down to the part's centre).
]]

local HorseModel = {}
HorseModel.HoofDepth = 3.85 -- studs from the body centre down to the ground
HorseModel.SaddleTop = 1.37 -- studs from the body centre up to the top of the saddle

local function part(model, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.Anchored = false
	p.Parent = model
	return p
end

local function weld(model, parent, name, size, color, cf, material)
	local p = part(model, name, size, color, material)
	local w = Instance.new("Weld")
	w.Name = name .. "Weld"
	w.Part0 = parent
	w.Part1 = p
	w.C0 = cf
	w.Parent = p
	p.CFrame = parent.CFrame * cf
	return p, w
end

-- A part that swings round a joint on the body (legs, tail, neck).
local function jointed(model, body, name, size, color, joint, drop, angle)
	local p, w = weld(model, body, name, size, color, CFrame.new(joint) * CFrame.Angles(angle or 0, 0, 0) * CFrame.new(0, -drop, 0))
	p:SetAttribute("Joint", joint)
	p:SetAttribute("Drop", drop)
	p:SetAttribute("Rest", angle or 0)
	return p, w
end

function HorseModel.build(coat, mane, opts)
	opts = opts or {}
	coat = coat or Color3.fromRGB(120, 76, 44)
	mane = mane or Color3.fromRGB(40, 26, 18)
	local W = opts.Width or 1.9
	local k = W / 2.2 -- how much narrower than the old 2.2-wide body
	local shade = coat:Lerp(Color3.new(0, 0, 0), 0.2)
	local white = opts.SockColor or (typeof(opts.Socks) == "Color3" and opts.Socks) or Color3.fromRGB(240, 238, 232)
	local sockStyle = opts.SockStyle or (opts.Socks == false and "None" or "Two")
	local marking = opts.Marking or "Blaze"
	local hoof = Color3.fromRGB(46, 40, 36)
	local leather = opts.Saddle or Color3.fromRGB(96, 58, 32)
	local leatherMaterial = opts.SaddleMaterial
	local blanket = opts.Blanket or Color3.fromRGB(170, 40, 40)
	local metal = Color3.fromRGB(180, 182, 188)
	local coatMaterial = opts.Material

	local model = Instance.new("Model")
	model.Name = "Horse"
	local body = part(model, "Body", Vector3.new(W, 2.0, 5.0), coat, coatMaterial)
	body.CFrame = CFrame.new()
	model.PrimaryPart = body
	-- Rounded barrel: chest and rump blocks, a belly.
	weld(model, body, "Chest", Vector3.new(W + 0.1, 2.1, 1.2), coat, CFrame.new(0, 0.05, -2.3))
	weld(model, body, "Rump", Vector3.new(W + 0.1, 2.1, 1.3), coat, CFrame.new(0, 0.12, 2.2))
	weld(model, body, "Belly", Vector3.new(W - 0.3, 0.4, 3.8), shade, CFrame.new(0, -1.05, 0))
	if coatMaterial then
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") and p ~= body then
				p.Material = coatMaterial
			end
		end
	end

	-- Neck (arched forward), mane along its top, head.
	local neck = jointed(model, body, "Neck", Vector3.new(1.1, 2.6, 1.3), coat, Vector3.new(0, 0.6, -2.6), -1.1, -0.55)
	weld(model, neck, "Mane", Vector3.new(0.35, 2.6, 0.5), mane, CFrame.new(0, 0.05, 0.6))
	local head = weld(model, neck, "Head", Vector3.new(1.0, 1.0, 2.1), coat, CFrame.new(0, 1.35, -0.75) * CFrame.Angles(-0.35, 0, 0))
	weld(model, head, "Muzzle", Vector3.new(0.92, 0.75, 0.6), shade, CFrame.new(0, -0.12, -1.2))
	-- Face marking.
	local faceWhite = Color3.fromRGB(240, 238, 232)
	if marking == "Blaze" then
		weld(model, head, "Blaze", Vector3.new(0.3, 0.06, 1.6), faceWhite, CFrame.new(0, 0.52, -0.3))
	elseif marking == "Star" then
		weld(model, head, "Star", Vector3.new(0.32, 0.06, 0.32), faceWhite, CFrame.new(0, 0.52, 0.2) * CFrame.Angles(0, math.pi / 4, 0))
	elseif marking == "Stripe" then
		weld(model, head, "Stripe", Vector3.new(0.14, 0.06, 1.7), faceWhite, CFrame.new(0, 0.52, -0.35))
	elseif marking == "Bald" then
		weld(model, head, "BaldFace", Vector3.new(0.8, 0.06, 1.9), faceWhite, CFrame.new(0, 0.52, -0.3))
		weld(model, head, "BaldMuzzle", Vector3.new(0.94, 0.4, 0.62), faceWhite, CFrame.new(0, 0.12, -1.2))
	end
	weld(model, head, "Forelock", Vector3.new(0.5, 0.2, 0.5), mane, CFrame.new(0, 0.6, 0.45))
	for _, side in ipairs({ -1, 1 }) do
		weld(model, head, "Ear", Vector3.new(0.2, 0.5, 0.22), coat, CFrame.new(side * 0.32, 0.72, 0.75) * CFrame.Angles(0, 0, side * -0.2))
		weld(model, head, "Eye", Vector3.new(0.06, 0.16, 0.16), Color3.fromRGB(20, 16, 14), CFrame.new(side * 0.51, 0.18, -0.1))
		weld(model, head, "Nostril", Vector3.new(0.06, 0.12, 0.12), Color3.fromRGB(30, 22, 18), CFrame.new(side * 0.47, -0.2, -1.42))
		-- Bridle straps.
		weld(model, head, "Bridle", Vector3.new(0.04, 0.9, 0.08), leather, CFrame.new(side * 0.52, 0.1, 0.1), leatherMaterial)
	end
	weld(model, head, "Noseband", Vector3.new(1.0, 0.1, 0.1), leather, CFrame.new(0, -0.05, -0.85), leatherMaterial)

	-- Tail.
	local tail = jointed(model, body, "Tail", Vector3.new(0.5, 2.3, 0.5), mane, Vector3.new(0, 0.7, 2.85), 1.1, -0.55)
	weld(model, tail, "TailTip", Vector3.new(0.6, 0.6, 0.6), mane, CFrame.new(0, -1.2, 0.05))

	-- Legs: thigh-to-hoof, socks by style, hooves.
	local socksOn = {
		None = {},
		Two = { LegFL = true, LegBR = true },
		Front = { LegFL = true, LegFR = true },
		Back = { LegBL = true, LegBR = true },
		Four = { LegFL = true, LegFR = true, LegBL = true, LegBR = true },
	}
	local on = socksOn[sockStyle] or socksOn.Two
	local legs = {
		{ "LegFL", Vector3.new(-0.6 * k, -0.75, -1.9) },
		{ "LegFR", Vector3.new(0.6 * k, -0.75, -1.9) },
		{ "LegBL", Vector3.new(-0.6 * k, -0.75, 1.9) },
		{ "LegBR", Vector3.new(0.6 * k, -0.75, 1.9) },
	}
	for _, l in ipairs(legs) do
		local leg = jointed(model, body, l[1], Vector3.new(0.55, 2.8, 0.6), coat, l[2], 1.4, 0)
		weld(model, leg, "Thigh", Vector3.new(0.7, 1.0, 0.75), coat, CFrame.new(0, 0.85, 0))
		if on[l[1]] then
			weld(model, leg, "Sock", Vector3.new(0.6, 0.7, 0.65), white, CFrame.new(0, -0.95, 0))
		end
		weld(model, leg, "Hoof", Vector3.new(0.62, 0.32, 0.7), hoof, CFrame.new(0, -1.5, -0.04))
	end

	-- Tack: blanket, saddle with a horn, stirrups, reins.
	weld(model, body, "Blanket", Vector3.new(W + 0.2, 0.14, 2.3), blanket, CFrame.new(0, 1.04, -0.1))
	weld(model, body, "BlanketEdge", Vector3.new(W + 0.3, 0.6, 0.1), blanket:Lerp(Color3.new(1, 1, 1), 0.2), CFrame.new(0, 0.8, -1.25))
	for _, side in ipairs({ -1, 1 }) do
		weld(model, body, "BlanketSide", Vector3.new(0.1, 0.8, 2.2), blanket, CFrame.new(side * (W / 2 + 0.06), 0.6, -0.1))
	end
	weld(model, body, "Saddle", Vector3.new(W - 0.4, 0.3, 1.7), leather, CFrame.new(0, 1.22, -0.1), leatherMaterial)
	weld(model, body, "Cantle", Vector3.new(1.4, 0.35, 0.25), leather, CFrame.new(0, 1.45, 0.65), leatherMaterial)
	weld(model, body, "Horn", Vector3.new(0.25, 0.45, 0.25), leather, CFrame.new(0, 1.55, -0.8), leatherMaterial)
	for _, side in ipairs({ -1, 1 }) do
		weld(model, body, "Strap", Vector3.new(0.05, 1.3, 0.12), leather, CFrame.new(side * (W / 2 + 0.13), 0.55, -0.1), leatherMaterial)
		weld(model, body, "Stirrup", Vector3.new(0.12, 0.12, 0.5), metal, CFrame.new(side * (W / 2 + 0.16), -0.15, -0.1), Enum.Material.Metal)
		weld(model, body, "Rein", Vector3.new(0.05, 0.05, 3.4), leather, CFrame.new(side * 0.45, 2.0, -2.4) * CFrame.Angles(0.33, 0, 0))
	end
	return model
end

-- The horse a stable selection describes (used by the server and the shop's
-- preview, so they always match). cat = TuskConfig.Horses; sel = { Coat,
-- Mane, Blanket, Saddle, Marking, Socks }.
-- Returns coat colour, mane colour, opts for HorseModel.build.
local function pick(list, id)
	for _, item in ipairs(list or {}) do
		if item.Id == id then
			return item
		end
	end
	return (list or {})[1]
end

-- A player's stable selection, from their attributes (HorseCoat, HorseMane,
-- HorseBlanket, HorseSaddle, HorseMarking, HorseSocks).
function HorseModel.selectionOf(player)
	return {
		Coat = player and player:GetAttribute("HorseCoat"),
		Mane = player and player:GetAttribute("HorseMane"),
		Blanket = player and player:GetAttribute("HorseBlanket"),
		Saddle = player and player:GetAttribute("HorseSaddle"),
		Marking = player and player:GetAttribute("HorseMarking"),
		Socks = player and player:GetAttribute("HorseSocks"),
	}
end

function HorseModel.lookFrom(cat, sel)
	cat, sel = cat or {}, sel or {}
	local coat = pick(cat.Coats, sel.Coat) or {}
	local maneItem = pick(cat.Manes, sel.Mane)
	local blanket = pick(cat.Blankets, sel.Blanket)
	local saddle = pick(cat.Saddles, sel.Saddle)
	local marking = pick(cat.Markings, sel.Marking)
	local socks = pick(cat.Socks, sel.Socks)
	local mane = (maneItem and maneItem.Color) or coat.Mane
	local opts = {
		Width = 1.9,
		Material = coat.Material and Enum.Material[coat.Material] or nil,
		Blanket = blanket and blanket.Color,
		Saddle = saddle and saddle.Color,
		SaddleMaterial = saddle and saddle.Material and Enum.Material[saddle.Material] or nil,
		Marking = marking and marking.Style or "Blaze",
		SockStyle = coat.Socks == false and (socks and socks.Style == "Two" and "None" or (socks and socks.Style)) or (socks and socks.Style or "Two"),
	}
	return coat.Body, mane, opts
end

return HorseModel
end

-- ======================================================================
-- MODULE: JointCache
-- ======================================================================
__modules["JointCache"] = function()
--[[
	JointCache  (StarterPlayerScripts.SpinClient.JointCache)
	Reads and writes a joint's offset for the pose system, and remembers
	each joint's original offset the first time it is touched.

	Works with both kinds of Roblox character joints:
	  * Motor6D              -> offset is joint.C0
	  * AnimationConstraint  -> offset is joint.Attachment0.CFrame
	    (newer places using the "Avatar Joint Upgrade")
]]

local JointCache = {}
local originals = setmetatable({}, { __mode = "k" })

function JointCache.isJoint(j)
	if not j then
		return false
	end
	if j:IsA("Motor6D") then
		return true
	end
	return j:IsA("AnimationConstraint") and j.Attachment0 ~= nil
end

function JointCache.read(j)
	if j:IsA("Motor6D") then
		return j.C0
	end
	return j.Attachment0.CFrame
end

function JointCache.write(j, cf)
	if j:IsA("Motor6D") then
		j.C0 = cf
	elseif j.Attachment0 then
		j.Attachment0.CFrame = cf
	end
end

function JointCache.original(j)
	local c0 = originals[j]
	if not c0 then
		c0 = JointCache.read(j)
		originals[j] = c0
	end
	return c0
end

return JointCache
end

-- ======================================================================
-- MODULE: NailModel
-- ======================================================================
__modules["NailModel"] = function()
--[[
	NailModel  (ReplicatedStorage.SpinShared.NailModel)

	Procedural fingernail-bullet used by every Tusk nail attack: a metal
	shaft, a flat head at the back and a tapered tip at the front.
	The nail points down its Core's LookVector (-Z).

	NailModel.build(length) -> Model (PrimaryPart = "Core")
	  Core attachments: "Tip" (front), "Tail" (back), "Center".
]]

local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local NailModel = {}

local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = model
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

function NailModel.build(length)
	length = length or 1.3
	local metal = TuskConfig.Colors.Metal
	local model = Instance.new("Model")
	model.Name = "TuskNail"

	-- Shaft: Cylinder axis is X, so turn it to run along Z.
	local core = part(model, {
		Name = "Core",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length * 0.7, length * 0.085, length * 0.085),
		Color = metal,
		Reflectance = 0.25,
		Massless = false,
	})
	core.CFrame = CFrame.Angles(0, math.pi / 2, 0)
	-- Pivot frame faces -Z, so Model:PivotTo(cf) points the tip down cf.LookVector.
	core.PivotOffset = CFrame.Angles(0, -math.pi / 2, 0)
	model.PrimaryPart = core

	local head = part(model, {
		Name = "Head",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length * 0.05, length * 0.24, length * 0.24),
		Color = metal:Lerp(Color3.new(1, 1, 1), 0.2),
		Reflectance = 0.3,
	})
	head.CFrame = CFrame.new(0, 0, length * 0.36) * CFrame.Angles(0, math.pi / 2, 0)
	weld(core, head)

	local tip = part(model, {
		Name = "Tip",
		Size = Vector3.new(length * 0.085, length * 0.085, length * 0.36),
		Color = metal:Lerp(Color3.new(1, 1, 1), 0.35),
		Reflectance = 0.35,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = tip
	tip.CFrame = CFrame.new(0, 0, -length * 0.35)
	weld(core, tip)

	-- Attachments are placed in the core's (rotated) local space:
	-- the core's local X axis runs along world Z here.
	local function att(name, z)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = Vector3.new(-z, 0, 0)
		a.Parent = core
		return a
	end
	att("Tip", -length * 0.5)
	att("Tail", length * 0.4)
	att("Center", 0)

	return model
end

return NailModel
end

-- ======================================================================
-- MODULE: Net
-- ======================================================================
__modules["Net"] = function()
--[[
	Net  (ReplicatedStorage.SpinShared.Net)

	Creates (server) or waits for (client) the RemoteEvents used by the
	Spin system. All remotes live in ReplicatedStorage.SpinRemotes.

	SpinRequest : client -> server  ("Start" | "Release", aimDirection | "Cancel")
	SpinFX      : server -> client  (eventName, payloadTable)
	              Also carries shared events: ProjectileSpawn/End, Hit, Damage.
	TuskRequest : client -> server  (action, ...)  see TuskService
	TuskFX      : server -> client  (eventName, payloadTable)
	WorldFX     : server -> client  map / NPC events (NPCSay)
	Bounty      : both ways         bounty board (open / accept / tracker)
	Race        : both ways         the Steel Ball Run horse race (join / leave / standings)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES = { "SpinRequest", "SpinFX", "TuskRequest", "TuskFX", "WorldFX", "Bounty", "Race" }

local Net = {}
local folder

local function getFolder()
	if folder then
		return folder
	end
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild("SpinRemotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "SpinRemotes"
			folder.Parent = ReplicatedStorage
		end
		for _, name in ipairs(REMOTES) do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild("SpinRemotes")
	end
	return folder
end

function Net.get(name)
	return getFolder():WaitForChild(name)
end

return Net
end

-- ======================================================================
-- MODULE: RaceClient
-- ======================================================================
__modules["RaceClient"] = function()
--[[
	RaceClient  (StarterPlayerScripts.SpinClient.RaceClient)

	STAGES: a big "STAGE 3: ROCKY MOUNTAINS" banner (with its tagline) at
	each stage start; the race card shows the stage, your points and, between
	stages, the countdown to the next; a STAGE RESULTS board (placings,
	times, points scored, then the overall points) between stages and a
	FINAL STANDINGS board (points, total time, prizes) at the end.
	RACING EXTRAS: hold Shift (L3 / GALLOP button) to gallop; a STAMINA meter
	(WINDED! when it runs dry); a PROGRESS STRIP across the top with every
	rider on it (you in gold); "JUMP!" when a log hurdle is ahead; H (D-pad
	up / BACK button) to go back to your last gate; split times at each
	gate; NEW RECORD! and your best time and wins at the finish; a results
	board at the end; dust behind galloping horses; carrot crates bob; a
	whip cracking when a jockey lashes a rival ("WHIPPED BY ...!" if it's you).

	The Steel Ball Run on the client (RaceService runs it):
	  * Look: the bounty board's style (UI.UITheme) - dark wood boards with
	    planks, nails and steel corner brackets, pinned parchment, Bangers
	    titles, chunky buttons that bounce on hover/press.
	  * ENTRY: a wooden board at the top with a pinned parchment notice,
	    "THE STEEL BALL RUN · ENTRY OPEN 0:38", a JOIN button (LEAVE once
	    you're in) and how many riders have entered. A minute before entry
	    opens, a small nailed plank counts down to it
	  * COUNTDOWN: a big outlined gold 3, 2, 1, GO!
	  * RACING (riders): a framed race card top-right (a parchment sheet with
	    your position, gate x / N, the time, the top five) with a LEAVE
	    button; a tall golden beacon (with a wooden distance plaque)
	    on your next gate with its number and distance, and a gold arrow
	    ahead of your horse pointing at it
	  * the winner and the results for everyone
	  * horse names float over them on little wooden plaques
	  * every horse gallops: legs in a four-beat stride that speeds up with
	    the horse, the neck nods, the tail streams out, the body bobs; riders
	    (and NPC jockeys) sit astride, legs round its sides, hands on the reins
	  * M (controller D-pad left, or the HORSE button on mobile): call your
	    own horse and ride it anywhere; press again to get off
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local UITheme = __require("UITheme")
local TuskAnimation = __require("TuskAnimation")

local RaceClient = {}
local player = Players.LocalPlayer
local cfg = TuskConfig.Race or {}
local Remote

local C = UITheme.C
local PAPER = C.PAPER
local INK = C.INK
local RED = C.RED
local GREEN = C.GREEN
local GOLD = C.GOLD

local gui, entryPanel, entryTitle, entryInfo, entryButton, soonChip, countdownLabel, card, cardRows, banner
local staminaPanel, staminaFill, staminaText, raceStrip, stripTrack, stripDots, jumpLabel, resultsBoard
local controlsBound = false
local cfgStageRest = (TuskConfig.Race or {}).StageRest
local stageIndex, stageCount, stageName, myPoints = 0, 0, "", 0
local entered = false
local nextGate = 1
local totalGates = 0
local standings = {}
local elapsedAt, elapsedBase = 0, 0
local beacon, arrow

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function corner(p, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, p)
end

local function label(parent, props)
	return UITheme.label(parent, props)
end

-- A chunky dark outline round text (a UIStroke on the glyphs, thicker and
-- cleaner than TextStroke), plus a light-to-shade gradient for depth.
local function inkOutline(l, thickness, color)
	l.TextStrokeTransparency = 1
	new("UIStroke", { Color = color or C.WOOD_EDGE, Thickness = thickness or 2, LineJoinMode = Enum.LineJoinMode.Round }, l)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 205, 190)), Rotation = 90 }, l)
end

-- A red map pin with a shine (as on the bounty posters).
local function pin(parent, position)
	local p = new("Frame", { BackgroundColor3 = C.RED, Size = UDim2.fromOffset(12, 12), Position = position, ZIndex = (parent.ZIndex or 1) + 2 }, parent)
	corner(p, 99)
	new("Frame", { BackgroundColor3 = C.WHITE, BackgroundTransparency = 0.4, Size = UDim2.fromOffset(4, 4), Position = UDim2.fromOffset(3, 3), ZIndex = p.ZIndex }, p)
	return p
end

-- A small nailed wooden plaque filling a BillboardGui, with Bangers text.
local function plaque(bb, color)
	local f = new("Frame", { Name = "Plaque", Size = UDim2.fromScale(1, 1) }, bb)
	UITheme.wood(f, { Planks = 1, Border = 2, Radius = 5 })
	local text = label(f, { Name = "Text", Position = UDim2.new(0, 10, 0, 2), Size = UDim2.new(1, -20, 1, -4), Text = "", Font = UITheme.Font.Title, TextColor3 = color or C.GOLD, TextStrokeTransparency = 0.5, TextStrokeColor3 = C.WOOD_EDGE, ZIndex = 3 })
	return text
end

local function mmss(seconds)
	seconds = math.max(0, seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

local function ordinal(n)
	local suffix = "TH"
	if n % 100 < 11 or n % 100 > 13 then
		suffix = ({ "ST", "ND", "RD" })[n % 10] or "TH"
	end
	return n .. suffix
end

local function showBanner(text, color, time)
	banner.Text = text
	banner.TextColor3 = color or GOLD
	banner.Visible = true
	local scale = banner:FindFirstChildOfClass("UIScale")
	scale.Scale = 0.5
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local token = {}
	banner:SetAttribute("Token", tostring(token))
	task.delay(time or 3, function()
		if banner:GetAttribute("Token") == tostring(token) then
			banner.Visible = false
		end
	end)
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local function buildUI()
	gui = new("ScreenGui", { Name = "SteelBallRun", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 7, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
	-- Entry banner: a wooden board with a parchment notice and a JOIN button.
	entryPanel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(420, 92), Visible = false }, gui)
	UITheme.wood(entryPanel, { Planks = 2, Border = 5, Brackets = true, BracketSize = 14 })
	new("UISizeConstraint", { MaxSize = Vector2.new(420, 92) }, entryPanel)
	local notice = new("Frame", { Name = "Notice", Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -158, 1, -20), ZIndex = 3 }, entryPanel)
	UITheme.paper(notice, { Radius = 3 })
	pin(notice, UDim2.new(0, 6, 0, -4))
	local strip = new("Frame", { Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = C.RED, BorderSizePixel = 0, ZIndex = 4 }, notice)
	corner(strip, 3)
	entryTitle = label(notice, { Position = UDim2.fromOffset(12, 2), Size = UDim2.new(1, -16, 0, 28), Text = "THE STEEL BALL RUN", Font = UITheme.Font.Title, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 })
	entryInfo = label(notice, { Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -16, 0, 16), Text = "", Font = UITheme.Font.Body, TextColor3 = C.RED, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 })
	label(notice, { Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -16, 0, 22), Text = "Race round the map on horseback. Top 3 win Cash; the winner gets a Saint's Corpse part.", Font = UITheme.Font.Plain, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.INK:Lerp(C.PAPER, 0.25), ZIndex = 4 })
	entryButton = UITheme.button(entryPanel, "JOIN", C.GREEN, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(112, 54), ZIndex = 4 })
	entryButton.Activated:Connect(function()
		Remote:FireServer(entered and "Leave" or "Join")
	end)
	-- "STEEL BALL RUN IN 0:45": a small nailed plank.
	soonChip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(230, 28), Visible = false }, gui)
	UITheme.wood(soonChip, { Planks = 1, Border = 3, Radius = 6 })
	label(soonChip, { Name = "Text", Position = UDim2.fromOffset(12, 3), Size = UDim2.new(1, -24, 1, -6), Text = "", TextColor3 = C.GOLD, Font = UITheme.Font.Title, ZIndex = 3 })
	-- Countdown: huge gold Bangers with a chunky dark outline.
	countdownLabel = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.35), Size = UDim2.fromOffset(400, 150), Text = "", Font = UITheme.Font.Title, TextColor3 = C.GOLD, Visible = false })
	inkOutline(countdownLabel, 5)
	new("UIScale", { Scale = 1 }, countdownLabel)
	-- Race card (top right): a framed board with a parchment standings sheet.
	card = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 64), Size = UDim2.fromOffset(230, 200), Visible = false }, gui)
	UITheme.wood(card, { Planks = 4, Border = 5, Brackets = true, BracketSize = 14 })
	label(card, { Name = "Title", Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -84, 0, 22), Text = "STEEL BALL RUN", Font = UITheme.Font.Title, TextColor3 = C.GOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	local sheet = new("Frame", { Name = "Sheet", Position = UDim2.fromOffset(9, 32), Size = UDim2.new(1, -18, 1, -46), ZIndex = 2 }, card)
	UITheme.paper(sheet, { Radius = 3 })
	label(card, { Name = "Pos", Position = UDim2.fromOffset(16, 34), Size = UDim2.fromOffset(90, 38), Text = "-", Font = UITheme.Font.Title, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	label(card, { Name = "Gate", Position = UDim2.fromOffset(104, 37), Size = UDim2.fromOffset(110, 17), Text = "", Font = UITheme.Font.Body, TextColor3 = C.RED, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3 })
	label(card, { Name = "Time", Position = UDim2.fromOffset(104, 55), Size = UDim2.fromOffset(110, 15), Text = "", Font = UITheme.Font.Body, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.INK:Lerp(C.PAPER, 0.3), ZIndex = 3 })
	new("Frame", { Position = UDim2.fromOffset(16, 74), Size = UDim2.new(1, -32, 0, 2), BackgroundColor3 = C.BURNT, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 3 }, card)
	cardRows = new("Frame", { Position = UDim2.fromOffset(14, 77), Size = UDim2.new(1, -28, 0, 95), BackgroundTransparency = 1, ZIndex = 3 }, card)
	local leave = UITheme.button(card, "LEAVE", C.RED, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 7), Size = UDim2.fromOffset(54, 22), ZIndex = 4 })
	leave.Activated:Connect(function()
		Remote:FireServer("Leave")
	end)
	label(card, { Name = "Hint", Position = UDim2.new(0, 14, 1, -28), Size = UDim2.new(1, -28, 0, 13), Text = "Ride through the gates in order", Font = UITheme.Font.Plain, TextColor3 = C.INK:Lerp(C.PAPER, 0.35), ZIndex = 3 })
	-- Big banner: Bangers with a chunky dark outline (like the bounty banner).
	banner = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.24), Size = UDim2.fromOffset(640, 70), Text = "", Font = UITheme.Font.Title, TextColor3 = C.GOLD, Visible = false })
	inkOutline(banner, 3)
	new("UIScale", { Scale = 1 }, banner)
	-- Stamina: a nailed plank with a wood-framed meter (bottom middle).
	staminaPanel = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(260, 46), Visible = false }, gui)
	UITheme.wood(staminaPanel, { Planks = 1, Border = 3, Radius = 6 })
	staminaText = label(staminaPanel, { Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -20, 0, 16), Text = "STAMINA  ·  SHIFT: GALLOP", Font = UITheme.Font.Title, TextColor3 = C.GOLD, ZIndex = 3 })
	local _, fill = UITheme.bar(staminaPanel, GREEN, { Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 16), ZIndex = 3 })
	staminaFill = fill
	-- Progress strip: a plank across the top with a track, gate ticks, a finish
	-- flag and every rider as a dot (you in gold).
	raceStrip = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(460, 34), Visible = false }, gui)
	UITheme.wood(raceStrip, { Planks = 1, Border = 3, Radius = 6 })
	stripTrack = new("Frame", { Position = UDim2.fromOffset(20, 15), Size = UDim2.new(1, -52, 0, 4), BackgroundColor3 = C.PAPER_DARK, BorderSizePixel = 0, ZIndex = 3 }, raceStrip)
	corner(stripTrack, 2)
	label(raceStrip, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(24, 22), Text = "🏁", Font = UITheme.Font.Heavy, TextColor3 = C.WHITE, ZIndex = 3 })
	stripDots = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, stripTrack)
	-- "JUMP!" over the middle of the screen when a hurdle's coming.
	jumpLabel = label(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(260, 60), Text = "JUMP!", Font = UITheme.Font.Title, TextColor3 = C.GOLD, Visible = false })
	inkOutline(jumpLabel, 3)
end

-- A results board: a wooden board with a parchment list. mode "stage"
-- (time and points scored this stage) or "final" (total points and time).
local function showResults(list, reason, title, subtitle, mode, seconds)
	if resultsBoard then
		resultsBoard:Destroy()
	end
	local rows = math.min(#list, 8)
	resultsBoard = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(380, 96 + math.max(rows, 1) * 24) }, gui)
	UITheme.wood(resultsBoard, { Planks = 4, Border = 6, Brackets = true, BracketSize = 16 })
	UITheme.sign(resultsBoard, title or "STEEL BALL RUN", subtitle or "RESULTS", { Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(300, 46), ZIndex = 3 })
	local sheet = new("Frame", { Position = UDim2.fromOffset(14, 60), Size = UDim2.new(1, -28, 1, -74), ZIndex = 3 }, resultsBoard)
	UITheme.paper(sheet, { Radius = 3 })
	if rows == 0 then
		label(sheet, { Size = UDim2.fromScale(1, 1), Text = string.upper(reason or "NOBODY FINISHED"), Font = UITheme.Font.Title, ZIndex = 4 })
	end
	for i = 1, rows do
		local r = list[i]
		local color = i == 1 and C.GOLD or (i == 2 and Color3.fromRGB(200, 200, 210) or (i == 3 and Color3.fromRGB(205, 130, 70) or nil))
		local y = 4 + (i - 1) * 24
		local me = r.UserId == player.UserId
		if me then
			local hl = new("Frame", { Position = UDim2.fromOffset(2, y), Size = UDim2.new(1, -4, 0, 22), BackgroundColor3 = C.GOLD, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = 4 }, sheet)
			corner(hl, 4)
		end
		if color then
			local medal = new("Frame", { Position = UDim2.fromOffset(6, y + 3), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = color, ZIndex = 5 }, sheet)
			corner(medal, 99)
			UITheme.stroke(medal, C.WOOD_EDGE, 1.5)
		end
		label(sheet, { Position = UDim2.fromOffset(30, y), Size = UDim2.new(0.56, -30, 0, 22), Text = ordinal(r.Place or i) .. "  " .. string.upper(r.Name or "?"), Font = i <= 3 and UITheme.Font.Title or UITheme.Font.Body, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = i == 1 and C.RED or INK, ZIndex = 5 })
		local t = r.Time or 0
		label(sheet, { Position = UDim2.new(0.56, 0, 0, y), Size = UDim2.new(0.22, -4, 0, 22), Text = mmss(t) .. string.format(".%d", math.floor((t % 1) * 10)), Font = UITheme.Font.Body, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 })
		local pts = mode == "stage" and ("+" .. tostring(r.Points or 0)) or (tostring(r.Points or 0) .. " PTS")
		label(sheet, { Position = UDim2.new(0.78, 0, 0, y), Size = UDim2.new(0.22, -8, 0, 22), Text = pts, Font = UITheme.Font.Title, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = mode == "stage" and C.GREEN or C.RED, ZIndex = 5 })
	end
	UITheme.pop(resultsBoard, 0.5)
	local board = resultsBoard
	task.delay(seconds or 9, function()
		if board.Parent then
			board:Destroy()
		end
	end)
end

-- The progress strip: every rider as a dot along the track.
local function fillStrip()
	for _, c in ipairs(stripDots:GetChildren()) do
		c:Destroy()
	end
	for i = 1, math.max(totalGates - 1, 0) do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(i / totalGates, 0.5), Size = UDim2.fromOffset(2, 10), BackgroundColor3 = C.WOOD_EDGE, BorderSizePixel = 0, ZIndex = 4 }, stripDots)
	end
	for _, row in ipairs(standings) do
		local me = row.UserId == player.UserId
		local size = me and 16 or 11
		local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(math.clamp(row.Progress or 0, 0, 1), 0.5), Size = UDim2.fromOffset(size, size), BackgroundColor3 = me and C.GOLD or (row.Jockey and Color3.fromRGB(170, 170, 180) or C.RED), ZIndex = me and 6 or 5 }, stripDots)
		corner(dot, 99)
		UITheme.stroke(dot, C.WOOD_EDGE, me and 2 or 1.5)
		if me then
			label(dot, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -1), Size = UDim2.fromOffset(40, 12), Text = "YOU", Font = UITheme.Font.Title, TextColor3 = C.GOLD, TextStrokeTransparency = 0.3, ZIndex = 6 })
		end
	end
end

local function setEntered(on)
	entered = on
	entryButton.Text = on and "LEAVE" or "JOIN"
	local color = on and RED or GREEN
	entryButton.BackgroundColor3 = color
	local edge = entryButton:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = color:Lerp(Color3.new(0, 0, 0), 0.45)
	end
	UITheme.pop(entryButton, 0.8)
end

local function fillStandings()
	for _, c in ipairs(cardRows:GetChildren()) do
		c:Destroy()
	end
	local mine
	for i, row in ipairs(standings) do
		if row.UserId == player.UserId then
			mine = row
		end
		if i <= 5 then
			local me = row.UserId == player.UserId
			local line = new("Frame", { Position = UDim2.fromOffset(0, (i - 1) * 19), Size = UDim2.new(1, 0, 0, 17), BackgroundColor3 = me and GOLD or PAPER, BackgroundTransparency = me and 0.15 or 1, ZIndex = 3 }, cardRows)
			corner(line, 4)
			if me then
				UITheme.stroke(line, C.BURNT, 1.5, 0.2)
			end
			label(line, { Position = UDim2.fromOffset(4, 1), Size = UDim2.new(0.7, -4, 1, -2), Text = i .. ". " .. string.upper(row.Name or "?"), Font = i <= 3 and UITheme.Font.Heavy or UITheme.Font.Body, TextColor3 = i == 1 and C.RED or INK, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
			label(line, { Position = UDim2.new(0.7, 0, 0, 1), Size = UDim2.new(0.3, -4, 1, -2), Text = row.Finished and "DONE" or ("GATE " .. math.min(row.Next or 1, totalGates)), Font = UITheme.Font.Body, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = row.Finished and GREEN or INK, ZIndex = 4 })
		end
	end
	if mine then
		card:FindFirstChild("Pos").Text = ordinal(mine.Position) .. " / " .. #standings
	end
end

---------------------------------------------------------------------------
-- The next gate: a beacon on it and an arrow ahead of your horse
---------------------------------------------------------------------------
local function gatePosition(index)
	local course = workspace:FindFirstChild("SteelBallRunCourse")
	if not course then
		return nil
	end
	for _, gate in ipairs(course:GetChildren()) do
		local isFinish = gate.Name == "Gate_FINISH"
		if (isFinish and index == totalGates) or (not isFinish and gate:GetAttribute("GateIndex") == index) then
			local line = gate:FindFirstChild("Line")
			return line and line.Position
		end
	end
	return nil
end

local function clearGuide()
	if beacon then
		beacon.Model:Destroy()
		beacon = nil
	end
	if arrow then
		arrow.Model:Destroy()
		arrow = nil
	end
end

local function stepGuide()
	local racing = entered and ReplicatedStorage:GetAttribute("SpinRacePhase") == "Racing" and nextGate <= totalGates
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local at = racing and gatePosition(nextGate)
	if not at or not root then
		clearGuide()
		return
	end
	if not beacon then
		local m = Instance.new("Model")
		m.Name = "RaceBeacon"
		m.Parent = VFXLib.Folder
		local pillar = VFXLib.part({ Size = Vector3.new(80, 3, 3), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.5, Shape = Enum.PartType.Cylinder })
		pillar.Parent = m
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(160, 36)
		bb.StudsOffset = Vector3.new(0, 20, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Adornee = pillar
		local text = plaque(bb, GOLD)
		bb.Parent = m
		beacon = { Model = m, Pillar = pillar, Text = text }
	end
	if not arrow then
		local m = Instance.new("Model")
		m.Name = "RaceArrow"
		m.Parent = VFXLib.Folder
		local shaft = VFXLib.part({ Size = Vector3.new(0.35, 0.35, 2.6), Color = GOLD, Material = Enum.Material.Neon })
		shaft.Parent = m
		local head = VFXLib.part({ Size = Vector3.new(1.3, 0.35, 1.1), Color = Color3.fromRGB(255, 240, 170), Material = Enum.Material.Neon })
		head.Parent = m
		arrow = { Model = m, Shaft = shaft, Head = head }
	end
	beacon.Pillar.CFrame = CFrame.new(at + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beacon.Pillar.Transparency = 0.45 + 0.15 * math.sin(os.clock() * 4)
	local dist = (Vector3.new(at.X, 0, at.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
	beacon.Text.Text = (nextGate == totalGates and "FINISH" or ("GATE " .. nextGate)) .. "  " .. math.floor(dist) .. "m"
	local flat = Vector3.new(at.X - root.Position.X, 0, at.Z - root.Position.Z)
	flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
	local pos = root.Position + flat * 5 + Vector3.new(0, 3 + math.sin(os.clock() * 3) * 0.2, 0)
	local cf = CFrame.lookAt(pos, pos + flat)
	arrow.Shaft.CFrame = cf
	arrow.Head.CFrame = cf * CFrame.new(0, 0, -1.5) * CFrame.Angles(0, math.pi / 4, 0)
end

---------------------------------------------------------------------------
-- Horses gallop, riders sit astride
---------------------------------------------------------------------------
local LEG_PHASE = { LegFL = 0, LegFR = 0.25, LegBL = 0.5, LegBR = 0.75 }
local horses = setmetatable({}, { __mode = "k" }) -- [horse] = { Phase, Joints, Weld, Base }
local riders = setmetatable({}, { __mode = "k" }) -- [character] = previous hold

local function horseState(horse)
	local h = horses[horse]
	if h then
		return h
	end
	h = { Phase = math.random(), Joints = {} }
	for _, p in ipairs(horse:GetChildren()) do
		local joint = p:IsA("BasePart") and p:GetAttribute("Joint")
		local w = joint and p:FindFirstChildOfClass("Weld")
		if w then
			table.insert(h.Joints, { Part = p, Weld = w, Joint = joint, Drop = p:GetAttribute("Drop") or 0, Rest = p:GetAttribute("Rest") or 0 })
		end
	end
	local body = horse.PrimaryPart or horse:FindFirstChild("Body")
	h.Weld = body and body:FindFirstChild("HorseWeld")
	horses[horse] = h
	return h
end

local function clearPlates()
	for horse, h in pairs(horses) do
		if not horse.Parent then
			if h.Stam then
				h.Stam:Destroy()
			end
			if h.Plate then
				h.Plate:Destroy()
			end
			horses[horse] = nil
		end
	end
end

local function stepHorses(dt)
	clearPlates()
	for _, horse in ipairs(CollectionService:GetTagged("SpinHorse")) do
		local character = horse.Parent
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and horse.Parent then
			local h = horseState(horse)
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local amp = math.clamp(speed / 40, 0, 1)
			h.Phase = (h.Phase + dt * (0.6 + speed * 0.045)) % 1
			for _, j in ipairs(h.Joints) do
				local a = j.Rest
				local name = j.Part.Name
				if LEG_PHASE[name] then
					a = a + math.sin((h.Phase + LEG_PHASE[name]) * math.pi * 2) * 0.75 * amp
				elseif name == "Neck" then
					a = a + math.sin(h.Phase * math.pi * 4) * 0.1 * amp
				elseif name == "Tail" then
					a = a - 0.6 * amp + math.sin(os.clock() * 3 + h.Phase) * 0.12
				end
				j.Weld.C0 = CFrame.new(j.Joint) * CFrame.Angles(a, 0, 0) * CFrame.new(0, -j.Drop, 0)
			end
			-- Its name, over its head.
			local name = horse:GetAttribute("HorseName")
			if name and h.PlateName ~= name then
				h.PlateName = name
				if h.Plate then
					h.Plate:Destroy()
				end
				local headPart = horse:FindFirstChild("Head")
				if headPart then
					local bb = Instance.new("BillboardGui")
					bb.Name = "HorseNameplate"
					bb.Adornee = headPart
					bb.Size = UDim2.fromOffset(150, 26)
					bb.StudsOffset = Vector3.new(0, 2.2, 0)
					bb.MaxDistance = 80
					bb.LightInfluence = 0
					local text = plaque(bb, Color3.fromRGB(255, 225, 150))
					text.Text = string.upper(name)
					bb.Parent = VFXLib.Folder
					h.Plate = bb
				end
			elseif not name and h.Plate then
				h.Plate:Destroy()
				h.Plate, h.PlateName = nil, nil
			end
			-- Other riders' stamina: a little bar over their horse while racing
			-- (green, gold, red; WINDED shows red and empty), so you can see who's spent.
			local stamina = character:GetAttribute("HorseStamina")
			if stamina and character ~= player.Character then
				local headPart = horse:FindFirstChild("Head")
				if not h.Stam and headPart then
					local bb = Instance.new("BillboardGui")
					bb.Name = "HorseStamina"
					bb.Adornee = headPart
					bb.Size = UDim2.fromOffset(64, 9)
					bb.StudsOffset = Vector3.new(0, 3.6, 0)
					bb.MaxDistance = 90
					bb.LightInfluence = 0
					local _, fill = UITheme.bar(bb, GREEN, { Size = UDim2.fromScale(1, 1) })
					bb.Parent = VFXLib.Folder
					h.Stam, h.StamFill = bb, fill
				end
				if h.StamFill then
					local k = math.clamp(stamina / 100, 0, 1)
					h.StamFill.Size = UDim2.fromScale(k, 1)
					h.StamFill.BackgroundColor3 = character:GetAttribute("HorseWinded") and RED or (k > 0.5 and GREEN or C.GOLD)
				end
			elseif h.Stam then
				h.Stam:Destroy()
				h.Stam, h.StamFill = nil, nil
			end
			-- Body bob, always from where the server put the horse (BodyY),
			-- never from last frame's position (so it can't creep).
			local bodyY = horse:GetAttribute("BodyY")
			if h.Weld and bodyY then
				h.Weld.C0 = CFrame.new(0, bodyY, -0.4) * CFrame.new(0, math.abs(math.sin(h.Phase * math.pi * 2)) * 0.25 * amp, 0) * CFrame.Angles(math.sin(h.Phase * math.pi * 2) * 0.04 * amp, 0, 0)
			end
		end
	end
end

-- SANDMAN runs the race on foot: sand kicks up behind him as he sprints.
local dustNext = {}
local function stepRunners()
	local t = os.clock()
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and character:GetAttribute("RaceOnFoot") and t >= (dustNext[character] or 0) then
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			if speed > 25 then
				dustNext[character] = t + (character:GetAttribute("Galloping") and 0.05 or 0.09)
				local back = speed > 0 and -Vector3.new(v.X, 0, v.Z).Unit or Vector3.new()
				local puff = Instance.new("Part")
				puff.Anchored = true
				puff.CanCollide = false
				puff.CanQuery = false
				puff.CanTouch = false
				puff.CastShadow = false
				puff.Shape = Enum.PartType.Ball
				puff.Material = Enum.Material.SmoothPlastic
				puff.Color = Color3.fromRGB(226, 196, 140)
				puff.Size = Vector3.new(1, 1, 1)
				puff.Transparency = 0.35
				local at = root.Position - Vector3.new(0, 2.6, 0) + back * 1.5 + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
				puff.CFrame = CFrame.new(at)
				puff.Parent = workspace
				TweenService:Create(puff, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(3, 2.4, 3), Transparency = 1, CFrame = CFrame.new(at + back * 2 + Vector3.new(0, 1, 0)) }):Play()
				game:GetService("Debris"):AddItem(puff, 0.7)
			end
		end
	end
	for character in pairs(dustNext) do
		if not character.Parent then
			dustNext[character] = nil
		end
	end
end

local function stepRiders()
	local seen = {}
	for _, horse in ipairs(CollectionService:GetTagged("SpinHorse")) do
		local character = horse.Parent
		if character and character:IsA("Model") and character:FindFirstChildOfClass("Humanoid") then
			seen[character] = true
			if riders[character] == nil then
				riders[character] = TuskAnimation.currentHold(character) or false
				TuskAnimation.hold(character, "Ride")
			end
			-- Up onto the saddle (the server says how high), camera too.
			local lift = character:GetAttribute("RideLift") or 2.4
			if TuskAnimation.setLift then
				TuskAnimation.setLift(character, lift)
			end
			if character == player.Character then
				local hum = character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.CameraOffset = Vector3.new(0, lift, 0)
				end
			end
			-- Hide the walk / run animation's legs while riding.
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					if track.WeightTarget > 0.01 then
						track:AdjustWeight(0.001, 0)
					end
				end
			end
		end
	end
	for character, previous in pairs(riders) do
		if not seen[character] then
			riders[character] = nil
			if TuskAnimation.setLift then
				TuskAnimation.setLift(character, nil)
			end
			if character == player.Character then
				local hum = character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.CameraOffset = Vector3.new()
				end
			end
			if character.Parent then
				TuskAnimation.stopHold(character, "Ride")
				if previous then
					TuskAnimation.hold(character, previous)
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Every frame: entry banner, countdown, race card
---------------------------------------------------------------------------
local lastCount = nil
-- Dust behind galloping horses (everyone sees it); your view widens when you gallop.
local dustAt = 0
local fovOn = false
local function stepGallop()
	local t = os.clock()
	if t >= dustAt then
		dustAt = t + 0.12
		for _, horse in ipairs(CollectionService:GetTagged("SpinHorse")) do
			local character = horse.Parent
			if character and character:GetAttribute("Galloping") then
				local root = character:FindFirstChild("HumanoidRootPart")
				if root then
					VFXLib.burst((root.CFrame * CFrame.new(0, -3, 3)).Position, { Count = 3, Color = Color3.fromRGB(196, 176, 140), Speed = 6, Lifetime = 0.5 })
				end
			end
		end
	end
	local mine = player.Character and player.Character:GetAttribute("Galloping") == true
	if mine ~= fovOn then
		fovOn = mine
		if CameraFX.setFovHold then
			CameraFX.setFovHold(mine and 8 or 0)
		end
	end
end

-- Gallop (hold) and back-to-last-gate: bound only while you're racing.
function RaceClient.bindControls(on)
	if on == controlsBound then
		return
	end
	controlsBound = on
	local keys = TuskConfig.Keys or {}
	if on then
		local g = keys.Gallop or {}
		ContextActionService:BindActionAtPriority("SpinGallop", function(_, state)
			if state == Enum.UserInputState.Begin then
				Remote:FireServer("Gallop", true)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				Remote:FireServer("Gallop", false)
			end
			return Enum.ContextActionResult.Sink
		end, true, 3000, g.Keyboard or Enum.KeyCode.LeftShift, g.Gamepad or Enum.KeyCode.ButtonL3)
		ContextActionService:SetTitle("SpinGallop", "GALLOP")
		ContextActionService:SetPosition("SpinGallop", UDim2.new(1, -95, 1, -235))
		local rk = keys.RaceReturn or {}
		ContextActionService:BindAction("SpinRaceReturn", function(_, state)
			if state == Enum.UserInputState.Begin then
				Remote:FireServer("Return")
			end
			return Enum.ContextActionResult.Sink
		end, true, rk.Keyboard or Enum.KeyCode.H, rk.Gamepad or Enum.KeyCode.DPadUp)
		ContextActionService:SetTitle("SpinRaceReturn", "BACK")
		ContextActionService:SetPosition("SpinRaceReturn", UDim2.new(1, -250, 1, -165))
	else
		ContextActionService:UnbindAction("SpinGallop")
		ContextActionService:UnbindAction("SpinRaceReturn")
		if Remote then
			Remote:FireServer("Gallop", false)
		end
	end
end

local function stepUI()
	local t = workspace:GetServerTimeNow()
	local phase = ReplicatedStorage:GetAttribute("SpinRacePhase")
	-- Entry.
	if phase == "Entry" then
		entryPanel.Visible = true
		soonChip.Visible = false
		entryInfo.Text = "ENTRY OPEN  " .. mmss((ReplicatedStorage:GetAttribute("SpinRaceEntryEnds") or t) - t) .. (lastCount and ("  ·  " .. lastCount .. " RIDER" .. (lastCount == 1 and "" or "S")) or "")
	else
		entryPanel.Visible = false
		local nextAt = ReplicatedStorage:GetAttribute("SpinRaceNext")
		local left = nextAt and nextAt - t
		soonChip.Visible = phase == nil and left ~= nil and left > 0 and left <= 60
		if soonChip.Visible then
			soonChip:FindFirstChild("Text").Text = "STEEL BALL RUN IN " .. mmss(left)
		end
	end
	-- Countdown: 3, 2, 1, GO!
	local goAt = ReplicatedStorage:GetAttribute("SpinRaceGoAt")
	if entered and goAt and (phase == "Countdown" or (phase == "Racing" and t - goAt < 0.8)) then
		local left = goAt - t
		local text = left > 0 and tostring(math.ceil(left)) or "GO!"
		if countdownLabel.Text ~= text then
			countdownLabel.Text = text
			countdownLabel.TextColor3 = left > 0 and GOLD or Color3.fromRGB(120, 230, 120)
			local scale = countdownLabel:FindFirstChildOfClass("UIScale")
			scale.Scale = 1.8
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			if text == "GO!" then
				CameraFX.fovPunch(10, 0.4)
			end
		end
		countdownLabel.Visible = true
	else
		countdownLabel.Visible = false
	end
	-- Racing extras: stamina, the strip, "JUMP!", gallop / return controls.
	local racing = entered and phase == "Racing" and nextGate <= totalGates
	RaceClient.bindControls(racing)
	raceStrip.Visible = entered and (phase == "Countdown" or phase == "Racing")
	local character = player.Character
	local stamina = character and character:GetAttribute("HorseStamina")
	staminaPanel.Visible = racing and stamina ~= nil
	if staminaPanel.Visible then
		local k = math.clamp(stamina / 100, 0, 1)
		staminaFill.Size = UDim2.fromScale(k, 1)
		local winded = character:GetAttribute("HorseWinded") == true
		staminaFill.BackgroundColor3 = winded and RED or (k > 0.5 and GREEN or C.GOLD)
		local onFoot = character:GetAttribute("RaceOnFoot")
		staminaText.Text = winded and (onFoot and "WINDED!  CATCH YOUR BREATH" or "WINDED!  LET HIM BREATHE")
			or (character:GetAttribute("Galloping") and (onFoot and "SPRINTING!" or "GALLOPING!") or (onFoot and "ON FOOT  ·  SHIFT: SPRINT  ·  H: LAST GATE" or "STAMINA  ·  SHIFT: GALLOP  ·  H: LAST GATE"))
		staminaText.TextColor3 = winded and RED or C.GOLD
	end
	-- A hurdle just ahead?
	local showJump = false
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if racing and root then
		for _, h in ipairs(CollectionService:GetTagged("SpinHurdle")) do
			local facing = h:GetAttribute("Facing")
			local pivot = h:GetPivot().Position
			if typeof(facing) == "Vector3" then
				local along = (root.Position - pivot):Dot(facing)
				local side = math.abs((root.Position - pivot):Dot(facing:Cross(Vector3.new(0, 1, 0))))
				if along < -2 and along > -30 and side < (h:GetAttribute("Width") or 30) / 2 + 4 then
					showJump = true
				end
			end
		end
	end
	if showJump ~= jumpLabel.Visible then
		jumpLabel.Visible = showJump
		if showJump then
			UITheme.pop(jumpLabel, 0.6)
		end
	end
	-- Race card.
	card.Visible = entered and (phase == "Countdown" or phase == "Racing" or phase == "Rest")
	if card.Visible then
		card:FindFirstChild("Title").Text = stageIndex > 0 and ("STAGE " .. stageIndex .. "/" .. stageCount .. ": " .. stageName) or "STEEL BALL RUN"
		local hint = card:FindFirstChild("Hint")
		if phase == "Rest" then
			local at = ReplicatedStorage:GetAttribute("SpinRaceNextStageAt")
			hint.Text = (at and at > t) and ("NEXT STAGE IN " .. mmss(at - t) .. "  ·  " .. myPoints .. " PTS") or ("TOTAL: " .. myPoints .. " PTS")
		else
			hint.Text = "POINTS: " .. myPoints .. "  ·  SHIFT GALLOP  ·  H LAST GATE"
		end
		card:FindFirstChild("Gate").Text = (nextGate > totalGates or phase == "Rest") and "STAGE DONE" or ("GATE " .. nextGate .. " / " .. totalGates)
		local start = ReplicatedStorage:GetAttribute("SpinRaceStart")
		card:FindFirstChild("Time").Text = start and mmss(t - start) or "0:00"
	end
end

function RaceClient.init()
	local horses = TuskConfig.Horses or {}
	if cfg.Enabled == false and horses.Enabled == false then
		return
	end
	Remote = Net.get("Race")
	buildUI()
	-- M: call your horse / get off it.
	if horses.Enabled ~= false then
		local keys = TuskConfig.Keys and TuskConfig.Keys.Horse
		ContextActionService:BindAction("SpinHorse", function(_, state)
			if state == Enum.UserInputState.Begin then
				Remote:FireServer("Horse")
			end
			return Enum.ContextActionResult.Sink
		end, true, keys and keys.Keyboard or Enum.KeyCode.M, keys and keys.Gamepad or Enum.KeyCode.DPadLeft)
		ContextActionService:SetTitle("SpinHorse", "HORSE")
		ContextActionService:SetPosition("SpinHorse", UDim2.new(1, -170, 1, -165))
	end
	Remote.OnClientEvent:Connect(function(kind, data)
		data = typeof(data) == "table" and data or {}
		if kind == "EntryOpen" then
			setEntered(false)
			lastCount = 0
			showBanner("THE STEEL BALL RUN: ENTRY OPEN!", GOLD, 3)
		elseif kind == "Joined" then
			setEntered(true)
			showBanner("YOU'RE IN THE STEEL BALL RUN!", Color3.fromRGB(150, 235, 150), 2.5)
		elseif kind == "Entrants" then
			lastCount = data.Count
		elseif kind == "Out" then
			setEntered(false)
			clearGuide()
			showBanner(string.upper(data.Reason or "OUT OF THE RACE"), Color3.fromRGB(255, 150, 130), 3)
		elseif kind == "Cancelled" then
			setEntered(false)
			showBanner(string.upper(data.Reason or "RACE CANCELLED"), PAPER, 3)
		elseif kind == "Stage" then
			stageIndex, stageCount, stageName = data.Index or 1, data.Count or 1, string.upper(data.Name or "")
			nextGate, totalGates = 1, data.Gates or totalGates
			if resultsBoard then
				resultsBoard:Destroy()
				resultsBoard = nil
			end
			if entered then
				showBanner("STAGE " .. stageIndex .. ": " .. stageName .. (data.Tagline and ("  ·  " .. string.upper(data.Tagline)) or ""), GOLD, 3.5)
			end
		elseif kind == "StageResults" then
			for _, row in ipairs(data.Overall or {}) do
				if row.UserId == player.UserId then
					myPoints = row.Points or myPoints
				end
			end
			if entered then
				clearGuide()
				local last = (data.Index or 1) >= (data.Count or 1)
				showResults(data.List or {}, data.Reason, "STAGE " .. tostring(data.Index) .. ": " .. string.upper(data.Name or ""), last and "STAGE RESULTS" or ("RESULTS  ·  NEXT STAGE SOON"), "stage", (cfgStageRest or 6) - 0.3)
			end
		elseif kind == "Countdown" then
			nextGate, totalGates, standings = 1, data.Total or 0, {}
		elseif kind == "Go" then
			totalGates = data.Total or totalGates
		elseif kind == "Gate" then
			nextGate = (data.Index or 0) + 1
			totalGates = data.Total or totalGates
			VFXLib.sound(TuskConfig.Sounds.Swing, workspace.CurrentCamera, 0.5, 1.4)
			showBanner("GATE " .. tostring(data.Index) .. " / " .. tostring(totalGates) .. (data.Split and ("   " .. mmss(data.Split)) or ""), GOLD, 1.2)
		elseif kind == "Standings" then
			standings = data.List or {}
			totalGates = data.Total or totalGates
			myPoints = data.Points or myPoints
			fillStandings()
			fillStrip()
		elseif kind == "Finished" then
			if data.UserId == player.UserId then
				nextGate = totalGates + 1
				clearGuide()
				showBanner("STAGE " .. tostring(data.Stage or stageIndex) .. ": YOU CAME " .. ordinal(data.Place or 0) .. "!  +" .. tostring(data.Points or 0) .. " PTS" .. ((data.Prize or 0) > 0 and ("  +$" .. data.Prize) or ""), GOLD, 3.5)
			elseif data.Place == 1 and entered then
				showBanner(string.upper(data.Name or "SOMEONE") .. " WINS STAGE " .. tostring(data.Stage or stageIndex) .. "!", GOLD, 2.5)
			end
		elseif kind == "JockeyWhip" and data.From and data.To then
			-- A jockey lashes a rival: a whip cracks between them.
			local from, to = data.From + Vector3.new(0, 2, 0), data.To + Vector3.new(0, 2, 0)
			local mid = (from + to) / 2 + Vector3.new(0, 2.5, 0)
			for k, seg in ipairs({ { from, mid }, { mid, to } }) do
				local a, b = seg[1], seg[2]
				local len = (b - a).Magnitude
				if len > 0.1 then
					local lash = VFXLib.part({ Size = Vector3.new(0.12, 0.12, len), CFrame = CFrame.lookAt((a + b) / 2, b), Color = Color3.fromRGB(90, 56, 30), Material = Enum.Material.SmoothPlastic })
					VFXLib.animate(0.25 + k * 0.05, function(t)
						lash.Transparency = t
					end, function()
						lash:Destroy()
					end)
				end
			end
			VFXLib.burst(to, { Count = 8, Color = Color3.fromRGB(255, 230, 170), Speed = 12, Lifetime = 0.3 })
			VFXLib.sound(TuskConfig.Sounds.Swing, to, 0.6, 1.8)
			if data.TargetUserId == player.UserId then
				showBanner("WHIPPED BY " .. string.upper(data.Name or "A JOCKEY") .. "!", RED, 1.2)
				CameraFX.shake(0.35, 0.2)
			end
		elseif kind == "Winded" then
			showBanner(player.Character and player.Character:GetAttribute("RaceOnFoot") and "YOU'RE WINDED!" or "YOUR HORSE IS WINDED!", RED, 1.6)
		elseif kind == "Recovered" then
			showBanner("GOT HIS BREATH BACK: GALLOP!", Color3.fromRGB(150, 235, 150), 1.2)
		elseif kind == "CarrotYou" then
			showBanner("CARROTS!  +STAMINA", Color3.fromRGB(255, 170, 70), 1.2)
			CameraFX.fovPunch(6, 0.3)
		elseif kind == "Carrot" and data.Position then
			VFXLib.burst(data.Position + Vector3.new(0, 2, 0), { Count = 14, Color = Color3.fromRGB(236, 130, 40), Speed = 10, Lifetime = 0.5 })
		elseif kind == "StumbleYou" then
			showBanner("STUMBLED!", RED, 1.2)
			CameraFX.shake(0.6, 0.3)
		elseif kind == "Stumble" and data.Position then
			VFXLib.burst(data.Position + Vector3.new(0, 1, 0), { Count = 20, Color = Color3.fromRGB(190, 170, 140), Speed = 14, Lifetime = 0.6 })
		elseif kind == "Cleared" then
			showBanner("NICE JUMP!", Color3.fromRGB(150, 235, 150), 0.9)
		elseif kind == "Returned" then
			showBanner("BACK AT " .. ((data.Gate or 0) >= 1 and ("GATE " .. data.Gate) or "THE START") .. "  (-" .. tostring(data.Penalty or 3) .. "s)", PAPER, 2)
		elseif kind == "Record" then
			task.delay(4.5, function()
				local line = "OVERALL " .. ordinal(data.Place or 0) .. "  ·  " .. tostring(data.Points or 0) .. " PTS" .. ((data.Prize or 0) > 0 and ("  ·  +$" .. data.Prize) or "") .. (data.Part and ("  ·  " .. data.Part) or "")
				showBanner(line, GOLD, 3.5)
				task.delay(3.6, function()
					if data.NewRecord then
						showBanner("NEW RECORD!  " .. mmss(data.Time or 0) .. " FOR ALL 9 STAGES   ·   WINS: " .. tostring(data.Wins or 0), GOLD, 3.5)
					elseif data.OldBest then
						showBanner("BEST: " .. mmss(data.OldBest) .. "   ·   WINS: " .. tostring(data.Wins or 0), PAPER, 3)
					end
				end)
			end)
		elseif kind == "Horse" then
			showBanner(data.Riding and "YOUR HORSE  (M TO GET OFF)" or "SENT YOUR HORSE AWAY", PAPER, 1.6)
		elseif kind == "Denied" then
			showBanner(string.upper(data.Reason or "CAN'T DO THAT"), Color3.fromRGB(255, 150, 130), 1.6)
		elseif kind == "Results" then
			local wasIn = entered
			setEntered(false)
			clearGuide()
			stageIndex, myPoints = 0, 0
			if wasIn then
				showResults(data.List or {}, data.Reason, "THE STEEL BALL RUN", "FINAL STANDINGS", "final", 9)
			else
				local first = (data.List or {})[1]
				showBanner(first and (string.upper(first.Name or "?") .. " WON THE STEEL BALL RUN!") or "THE STEEL BALL RUN IS OVER", GOLD, 3.5)
			end
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		stepUI()
		stepGallop()
		stepGuide()
		stepHorses(dt)
		stepRiders()
		stepRunners()
	end)
end

return RaceClient
end

-- ======================================================================
-- MODULE: SettingsUI
-- ======================================================================
__modules["SettingsUI"] = function()
--[[
	SettingsUI  (StarterPlayerScripts.SpinClient.UI.SettingsUI)
	The small "VFX: MEDIUM" button (top right) that cycles Low / Medium / High,
	in the bounty-board style: a little nailed wooden plank with Bangers
	parchment-coloured text and a lamp that glows red / gold / green for
	Low / Medium / High. It bounces on hover and press and pops on change.
	Phones start on Low to keep the frame rate smooth.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = nil -- (bundled: modules are inlined)
local VFXQuality = __require("VFXQuality")
local UITheme = __require("UITheme")
local C = UITheme.C

local SettingsUI = {}
local LAMP = { Low = C.RED, Medium = C.GOLD, High = C.GREEN }

function SettingsUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpinSettings"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- VFX quality toggle (top right, small): a wooden plank button.
	local qualityButton = Instance.new("TextButton")
	qualityButton.Name = "VFXQuality"
	qualityButton.AnchorPoint = Vector2.new(1, 0)
	qualityButton.Position = UDim2.new(1, -12, 0, 12)
	qualityButton.Size = UDim2.fromOffset(130, 30)
	qualityButton.AutoButtonColor = false
	qualityButton.Font = UITheme.Font.Title
	qualityButton.TextSize = 15
	-- The planks cover the button's own text, so a label on top shows it;
	-- .Text is still kept up to date.
	qualityButton.TextTransparency = 1
	qualityButton.Parent = gui
	UITheme.wood(qualityButton, { Planks = 1, Border = 3, Radius = 7, Nails = true, Stroke = 2 })
	local edge = qualityButton:FindFirstChildOfClass("UIStroke")

	local lamp = UITheme.new("Frame", {
		Name = "Lamp",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = C.GOLD,
		ZIndex = 3,
	}, qualityButton)
	UITheme.corner(lamp, 99)
	UITheme.stroke(lamp, C.WOOD_EDGE, 2)
	local text = UITheme.label(qualityButton, {
		Name = "Label",
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -34, 1, 0),
		Font = UITheme.Font.Title,
		TextScaled = false,
		TextSize = 17,
		TextColor3 = C.PAPER,
		TextStrokeColor3 = C.SHADOW,
		TextStrokeTransparency = 0.3,
		ZIndex = 3,
	})

	UITheme.hover(qualityButton)
	qualityButton.MouseEnter:Connect(function()
		if edge then
			edge.Color = C.GOLD
		end
	end)
	qualityButton.MouseLeave:Connect(function()
		if edge then
			edge.Color = C.WOOD_EDGE
		end
	end)

	local function refresh()
		local _, name = VFXQuality.get()
		qualityButton.Text = "VFX: " .. string.upper(name)
		text.Text = qualityButton.Text
		lamp.BackgroundColor3 = LAMP[name] or C.GOLD
	end
	refresh()
	qualityButton.Activated:Connect(function()
		VFXQuality.cycle()
	end)
	VFXQuality.Changed:Connect(function(...)
		refresh()
		UITheme.pop(lamp, 0.4)
	end)

	-- Touch devices start on Low to protect frame rate; players can raise it.
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		VFXQuality.set("Low")
	end
end

return SettingsUI
end

-- ======================================================================
-- MODULE: TuskActCommon
-- ======================================================================
__modules["TuskActCommon"] = function()
--[[
	TuskActCommon  (StarterPlayerScripts.SpinClient.TuskActCommon)

	Shared client choreography used by every Act's visual module:
	  Palette(act)          each Act's colour identity
	  m1(data, palette)     poses, Stand lunges, swipes, mini-portals
	  finisher(data, pal)   combo-ender shockwave
	  portal(...)           wormhole that opens, holds and collapses
	  golden(...)           golden rectangle + spiral (Act 2), same arguments
	  portalNail(...)       portals for nails fired through them
	  evolve(data)          the "next Act" transformation + banner
	  charge helpers        attribute-driven hold charges
]]

local Players = game:GetService("Players")
local Fighters = __require("Fighters")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local TuskStand = __require("TuskStand")

local Common = {}
local colors = TuskConfig.Colors
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

Common.Palettes = {
	[1] = { Main = colors.Cyan, Second = colors.Blue, Light = colors.Ice },
	[2] = { Main = Color3.fromRGB(80, 210, 255), Second = Color3.fromRGB(110, 70, 255), Light = colors.Ice },
	[3] = { Main = Color3.fromRGB(70, 130, 255), Second = Color3.fromRGB(30, 20, 120), Light = Color3.fromRGB(190, 210, 255) },
	[4] = { Main = colors.Gold, Second = colors.DeepBlue, Light = colors.GoldLight },
	[5] = { Main = Color3.fromRGB(120, 225, 95), Second = Color3.fromRGB(40, 120, 50), Light = Color3.fromRGB(225, 255, 205) }, -- Gyro
	[6] = { Main = Color3.fromRGB(80, 210, 220), Second = Color3.fromRGB(35, 60, 190), Light = Color3.fromRGB(215, 255, 250) }, -- Diego
	[7] = { Main = Color3.fromRGB(165, 215, 80), Second = Color3.fromRGB(95, 105, 125), Light = Color3.fromRGB(225, 232, 245) }, -- Pork Pie Hat Kid (bamboo green + steel)
	[8] = { Main = Color3.fromRGB(245, 185, 80), Second = Color3.fromRGB(50, 140, 160), Light = Color3.fromRGB(255, 240, 205) }, -- Sandman (sand + turquoise)
	[9] = { Main = Color3.fromRGB(214, 156, 84), Second = Color3.fromRGB(96, 62, 38), Light = Color3.fromRGB(255, 232, 196) }, -- Mountain Tim (leather + rope)
	[10] = { Main = Color3.fromRGB(242, 140, 172), Second = Color3.fromRGB(120, 60, 92), Light = Color3.fromRGB(255, 220, 230) }, -- Hot Pants (Cream Starter pink)
	[11] = { Main = Color3.fromRGB(110, 180, 255), Second = Color3.fromRGB(40, 50, 90), Light = Color3.fromRGB(225, 245, 255) }, -- Blackmore (rain blue)
	[12] = { Main = Color3.fromRGB(214, 60, 70), Second = Color3.fromRGB(226, 196, 110), Light = Color3.fromRGB(255, 200, 200) }, -- Axl RO (Civil War red)
	[13] = { Main = Color3.fromRGB(120, 170, 255), Second = Color3.fromRGB(236, 120, 170), Light = Color3.fromRGB(240, 246, 255) }, -- Funny Valentine (D4C blue + pink)
	[14] = { Main = Color3.fromRGB(236, 196, 70), Second = Color3.fromRGB(70, 170, 160), Light = Color3.fromRGB(255, 244, 200) }, -- Diego from another world (The World gold + teal)
	[15] = { Main = Color3.fromRGB(120, 190, 240), Second = Color3.fromRGB(240, 200, 90), Light = Color3.fromRGB(235, 248, 255) }, -- Josuke (Soft & Wet bubble blue + gold)
	[16] = { Main = Color3.fromRGB(150, 40, 50), Second = Color3.fromRGB(240, 196, 60), Light = Color3.fromRGB(255, 236, 200) }, -- Tooru (Wonder of U maroon + scarf gold)
	[17] = { Main = Color3.fromRGB(90, 170, 240), Second = Color3.fromRGB(240, 120, 190), Light = Color3.fromRGB(225, 240, 255) }, -- Jodio (November Rain blue + strap pink)
	[18] = { Main = Color3.fromRGB(220, 228, 240), Second = Color3.fromRGB(120, 200, 255), Light = Color3.fromRGB(255, 255, 255) }, -- John Rod (bright metal + blue)
	[22] = { Main = Color3.fromRGB(150, 80, 200), Second = Color3.fromRGB(255, 214, 80), Light = Color3.fromRGB(255, 246, 200) }, -- Joseph (Hermit Purple + Hamon gold)
	[21] = { Main = Color3.fromRGB(240, 196, 50), Second = Color3.fromRGB(60, 160, 110), Light = Color3.fromRGB(255, 244, 200) }, -- DIO (The World gold + green)
	[20] = { Main = Color3.fromRGB(130, 110, 220), Second = Color3.fromRGB(240, 196, 70), Light = Color3.fromRGB(230, 225, 255) }, -- Jotaro (Star Platinum violet + gold)
	[19] = { Main = Color3.fromRGB(230, 120, 170), Second = Color3.fromRGB(246, 204, 40), Light = Color3.fromRGB(255, 236, 220) }, -- Ringo (Mandom pink + watch-hand gold)
}

---------------------------------------------------------------------------
-- FINGER WHIRLS (Johnny's nail shots, from the art): blue rings spinning
-- round his fingertips while his hand is up, following the hand; on
-- Release(direction) they shoot out along the shot, spreading and fading.
---------------------------------------------------------------------------
local WHIRL = Color3.fromRGB(120, 200, 255)
local WHIRL_LIGHT = Color3.fromRGB(200, 236, 255)

-- Where his fingertips are, and the way they point (a CFrame whose
-- UpVector runs along the fingers).
local function fingertips(character)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local root = character:FindFirstChild("HumanoidRootPart")
	if hand then
		local down = -hand.CFrame.UpVector
		local tip = (hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.15, 0)).Position
		return CFrame.lookAt(tip, tip + down) * CFrame.Angles(-math.pi / 2, 0, 0)
	elseif root then
		local tip = (root.CFrame * CFrame.new(0.9, 0.55, -1.6)).Position
		return CFrame.lookAt(tip, tip + root.CFrame.LookVector) * CFrame.Angles(-math.pi / 2, 0, 0)
	end
	return nil
end
Common.fingertips = fingertips

function Common.fingerWhirl(character, duration, opts)
	opts = opts or {}
	local color, light = opts.Color or WHIRL, opts.Light or WHIRL_LIGHT
	local rings = {}
	local spec = { { 0.32, 0, 9 }, { 0.55, 0.14, -7 }, { 0.8, 0.28, 5 } } -- radius, along the fingers, spin speed
	for i, sp in ipairs(spec) do
		local ring = VFXLib.ring({ Radius = 0.05, Width = i == 1 and 0.12 or 0.09, Color = i % 2 == 1 and color or light, Transparency = 0.1, Segments = 14 })
		rings[i] = { Ring = ring, Radius = sp[1], Along = sp[2], Spin = sp[3], Angle = math.random() * math.pi * 2 }
	end
	local glow = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), Color = light, Transparency = 0.3 })
	local handle = { Released = false }
	local start = os.clock()
	local last = start
	local job = VFXLib.animate(math.max(duration, 0.05) + 0.6, function()
		if handle.Released then
			return
		end
		local now = os.clock()
		local dt = now - last
		last = now
		local cf = character.Parent and fingertips(character)
		if not cf then
			return
		end
		local grow = math.min((now - start) / 0.15, 1)
		for i, r in ipairs(rings) do
			r.Angle = r.Angle + r.Spin * dt
			local wobble = math.sin(now * 11 + i) * 0.08
			local radius = r.Radius * grow * (1 + math.sin(now * 14 + i * 2) * 0.1)
			r.Ring:SetRadius(radius)
			r.Ring:SetCFrame(cf * CFrame.new(0, r.Along, 0) * CFrame.Angles(wobble, r.Angle, -wobble))
		end
		glow.CFrame = cf
		local pulse = 0.3 + math.abs(math.sin(now * 18)) * 0.25
		glow.Size = Vector3.new(pulse, pulse, pulse) * (1 + grow * 0.5)
	end)
	function handle:Release(direction)
		if self.Released then
			return
		end
		self.Released = true
		VFXLib.cancel(job)
		local cf = character.Parent and fingertips(character)
		glow:Destroy()
		if not cf then
			for _, r in ipairs(rings) do
				r.Ring:Destroy()
			end
			return
		end
		local dir = (direction and direction.Magnitude > 1e-3) and direction.Unit or cf.UpVector
		local from = cf.Position
		local axis = CFrame.lookAt(from, from + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
		-- The whirls fly out along the shot, spinning, spreading and fading.
		for i, r in ipairs(rings) do
			local base = r.Radius
			VFXLib.animate(0.32, function(a)
				r.Angle = r.Angle + r.Spin * 0.03
				r.Ring:SetRadius(base * (1 + a * (1.5 + i * 0.4)))
				r.Ring:SetCFrame(axis * CFrame.new(0, a * (2.5 + i * 1.6), 0) * CFrame.Angles(0, r.Angle, 0))
				r.Ring:SetTransparency(0.1 + 0.9 * a)
			end, function()
				r.Ring:Destroy()
			end)
		end
		VFXLib.flash(from, color, 4, 10, 0.1)
		VFXLib.burst(from, { Count = 8, Color = light, Speed = 12, Lifetime = 0.25 })
	end
	-- Never left behind if nobody releases it.
	task.delay(math.max(duration, 0.05) + 0.6, function()
		handle:Release(nil)
	end)
	return handle
end

function Common.palette(act)
	return Common.Palettes[act] or Common.Palettes[1]
end

function Common.rootOf(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

function Common.isLocal(character)
	return character ~= nil and character == localPlayer.Character
end

function Common.swipe(root, side, color, scale)
	scale = scale or 1
	local cf = root.CFrame * CFrame.new(side * 0.3, 0.3, -1.2) * CFrame.Angles(0, 0, side * 0.5)
	-- A thick coloured arc, a thin bright inner arc a beat later, and sparks
	-- flung off the tip of the swing.
	TuskVFX.CreateCrescent(cf, { Radius = 2.4 * scale, Width = 0.6 * scale, Color = color, Color2 = Color3.new(1, 1, 1), Sweep = side * 1.9, Duration = 0.2 })
	task.delay(0.03, function()
		if root.Parent then
			TuskVFX.CreateCrescent(cf * CFrame.new(0, 0, -0.3), { Radius = 1.8 * scale, Width = 0.18 * scale, Color = Color3.new(1, 1, 1), Color2 = color, Sweep = side * 2.1, Duration = 0.14 })
		end
	end)
	local tip = (root.CFrame * CFrame.new(-side * 1.6 * scale, 0.4, -2.2 * scale)).Position
	VFXLib.burst(tip, { Count = 5, Color = color, Speed = 18, Lifetime = 0.22, Spread = 50, Direction = root.CFrame.RightVector * -side, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }) })
end

---------------------------------------------------------------------------
-- Portals
---------------------------------------------------------------------------
-- A wormhole facing `lookAt`. Opens, holds `duration`, collapses.
function Common.portal(position, lookAt, radius, duration, palette, delay)
	palette = palette or Common.palette(2)
	local function open()
		local facing = (lookAt and (lookAt - position).Magnitude > 0.1) and CFrame.lookAt(position, lookAt) or CFrame.new(position)
		TuskVFX.CreateWormhole(facing, {
			Radius = radius or 2.5,
			Color = palette.Main,
			Color2 = palette.Second,
			OpenTime = 0.22,
			Duration = duration or 0.6,
			CloseTime = 0.2,
		})
		VFXLib.sound(sounds.Warning, position, 0.25, 1.6)
	end
	if delay and delay > 0 then
		task.delay(delay, open)
	else
		open()
	end
end

-- Golden ratio (Act 2): a Golden Rectangle with its spiral facing `lookAt`,
-- a spinning golden spiral in front and a soft gold flash. Same arguments
-- as Common.portal so the two can be swapped.
function Common.golden(position, lookAt, radius, duration, palette, delay)
	palette = palette or Common.palette(2)
	local function open()
		local facing = (lookAt and (lookAt - position).Magnitude > 0.1) and CFrame.lookAt(position, lookAt) or CFrame.new(position)
		local size = (radius or 2.5) * 1.1
		TuskVFX.CreateGoldenRectangle(facing, { Size = size, Duration = (duration or 0.6) + 0.25, Color = colors.Gold, Color2 = colors.GoldLight, Turn = math.pi * 0.4 })
		TuskVFX.CreateGoldenSpiral(facing * CFrame.new(0, 0, -0.1), { Size = size * 0.9, Duration = (duration or 0.6) + 0.2, Color = palette.Main, Color2 = colors.GoldLight, Width = 0.14 })
		VFXLib.flash(position, colors.Gold, 3, 10 + size * 2, 0.25)
		VFXLib.sound(sounds.Warning, position, 0.2, 1.8)
	end
	if delay and delay > 0 then
		task.delay(delay, open)
	else
		open()
	end
end

---------------------------------------------------------------------------
-- M1
---------------------------------------------------------------------------
local LUNGES = {
	CFrame.new(0.4, 0.6, -3),
	CFrame.new(-0.6, 0.4, -3.2),
	CFrame.new(0.9, 1, -2.4),
	CFrame.new(0, 1.4, -3.4),
}

function Common.m1(data, palette, opts)
	opts = opts or {}
	local character = data.Character
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local index = data.Index
	TuskAnimation.play(character, (opts.AnimPrefix or "M1_") .. index)
	VFXLib.sound(sounds.Swing, root, 0.5, (opts.Pitch or 1) * (0.95 + index * 0.06))
	TuskStand.action(character, "Lunge", { Target = LUNGES[index], Duration = index == 4 and 0.5 or 0.26 })
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and palette.Main or palette.Light, opts.Scale)
	if data.Portal then
		-- Short portal (or golden rectangle) flash beside the strike.
		local pos = (root.CFrame * CFrame.new(index % 2 == 1 and 1.6 or -1.6, 1, -2.6)).Position
		local open = opts.Golden and Common.golden or Common.portal
		open(pos, (root.CFrame * CFrame.new(0, 1, -6)).Position, 1.1, 0.18, palette)
	end
	if (data.Repeat or 1) > 1 then
		for i = 2, data.Repeat do
			task.delay((i - 1) * 0.08, function()
				if root.Parent then
					Common.swipe(root, i % 2 == 0 and -1 or 1, palette.Light, opts.Scale)
					VFXLib.burst((root.CFrame * CFrame.new(0, 0.5, -3)).Position, { Count = 5, Color = palette.Main, Speed = 10, Lifetime = 0.2 })
				end
			end)
		end
	end
end

function Common.finisher(data, palette, opts)
	opts = opts or {}
	local character = data.Character
	local root = Common.rootOf(character)
	local pos = data.Position
	if data.Hit and Common.isLocal(character) then
		CameraFX.impactFrame(palette.Light)
	end
	TuskVFX.CreateRotationalShockwave(CFrame.new(pos - Vector3.new(0, 2.6, 0)), {
		Radius = data.Radius or 7,
		Layers = opts.Layers or 3,
		Color = palette.Main,
		Color2 = palette.Second,
		Ground = true,
		Particles = 1.5,
		Width = opts.Width or 0.5,
	})
	TuskVFX.CreateImpact(pos, root and -root.CFrame.LookVector or Vector3.new(0, 1, 0), { Size = opts.Size or 1.2, Radius = 3, Layers = 2, Color = palette.Light, Color2 = palette.Main, Ground = false })
	TuskVFX.CreateImpactStar(pos, { Size = 6 * (opts.Size or 1.2), Rays = 9, Color = palette.Main, Color2 = palette.Light, Duration = 0.3 })
	if data.Hit then
		TuskVFX.CreateGroundCracks(pos, { Radius = (data.Radius or 7) * 0.8, Color = palette.Main, Duration = 1.3 })
	end
	VFXLib.sound(sounds.Finisher, pos, 0.8, opts.Pitch or 1)
	CameraFX.shakeAt(pos, opts.Shake or 0.6, 50)
end

---------------------------------------------------------------------------
-- Evolution: Act N -> Act N+1
---------------------------------------------------------------------------
function Common.evolve(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local palette = Common.palette(data.To)
	local ground = root.Position - Vector3.new(0, 2.9, 0)
	TuskVFX.CreateMagicCircle(CFrame.new(ground), { Radius = 9, Color = palette.Main, Color2 = palette.Light, Duration = 1.4, RotationSpeed = 2, Points = data.To + 4 })
	TuskVFX.CreateRotationalShockwave(CFrame.new(ground), { Radius = 16, Layers = 3, Color = palette.Main, Color2 = palette.Light, Ground = true, Particles = 2, Width = 0.7, Duration = 0.6 })
	VFXLib.burst(root.Position, { Count = 40, Color = palette.Light, Speed = 40, Lifetime = 0.6 })
	VFXLib.flash(root.Position, palette.Main, 9, 30, 0.6)
	TuskVFX.CreateEnergyPillar(ground, { Radius = 5, Height = 45, Color = palette.Light, Color2 = palette.Main, Duration = 0.6 })
	TuskVFX.CreateImpactStar(root.Position, { Size = 10, Rays = 10, Color = palette.Main, Color2 = palette.Light, Duration = 0.35 })
	VFXLib.sound(sounds.AwakeningBurst, root.Position, 0.9, 1 + data.To * 0.05)
	TuskStand.action(character, "Manifest", { Duration = 0.7 })
	if Common.isLocal(character) then
		CameraFX.speedLines(0.5, palette.Light)
		CameraFX.fovPunch(14, 0.6)
	end
end

---------------------------------------------------------------------------
-- Hold-charge visuals (shared driver)
---------------------------------------------------------------------------
--[[ Common.chargeDriver(act, move, makeEffect(character, root) -> effect,
     update(effect, progress, character), finish(effect, character)) ]]
function Common.chargeDriver(act, move, makeEffect, update, finish)
	local active = {}
	return function()
		local seen = {}
		for _, player in ipairs(Fighters.list()) do
			local character = player.Character
			local start = character and character:GetAttribute("TuskCharge")
			if start and character:GetAttribute("TuskAct") == act and character:GetAttribute("TuskChargeMove") == move then
				seen[character] = true
				local root = Common.rootOf(character)
				if not active[character] and root then
					active[character] = { Effect = makeEffect(character, root), Start = start }
				end
				local entry = active[character]
				if entry then
					update(entry.Effect, workspace:GetServerTimeNow() - start, character)
				end
			end
		end
		for character, entry in pairs(active) do
			if not seen[character] then
				active[character] = nil
				finish(entry.Effect, character)
			end
		end
	end
end

function Common.actName(act)
	local info = Registry.get(act)
	return info and info.Name or ("TUSK ACT " .. tostring(act))
end

return Common
end

-- ======================================================================
-- MODULE: TuskActRegistry
-- ======================================================================
__modules["TuskActRegistry"] = function()
--[[
	TuskActRegistry  (ReplicatedStorage.SpinShared.TuskActRegistry)

	The list of Tusk Acts: names, slot labels, themes and whether each
	Act is implemented. The server refuses to equip an Act whose
	Implemented flag is false, and the menu shows it as IN DEVELOPMENT
	(locked, not a fake button).

	To add an Act: create ServerScriptService.SpinServer.TuskActs.TuskActN,
	add its client choreography in SpinClient.TuskActVFX.ActN, then set
	Implemented = true here.
]]

local TuskActRegistry = {}

TuskActRegistry.Acts = {
	[1] = {
		Name = "TUSK ACT 1",
		Tagline = "The beginning of Spin",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(90, 230, 255), Secondary = Color3.fromRGB(40, 120, 255) },
		M1 = "NAIL COMBO",
		Abilities = { "NAIL SHOT", "NAIL BARRAGE", "SPINNING NAIL" },
		AbilityKinds = { "Press", "Press", "Hold" }, -- Hold = charge on press, fire on release
		Ultimate = "AWAKEN: INFINITE ROTATION",
		Next = 2, -- the ultimate awakens Tusk to this Act
	},
	[2] = {
		Name = "TUSK ACT 2",
		Tagline = "The Golden Ratio",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(70, 200, 255), Secondary = Color3.fromRGB(30, 80, 220) },
		M1 = "GOLDEN COMBO",
		Abilities = { "GOLDEN RATIO NAIL", "UNDERGROUND PURSUIT", "GOLDEN SPIRAL" },
		AbilityKinds = { "Press", "Press", "Press" },
		Next = 3,
		Ultimate = "AWAKEN: INFINITE ROTATION",
	},
	[3] = {
		Name = "TUSK ACT 3",
		Tagline = "Master of spatial movement",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(60, 140, 255), Secondary = Color3.fromRGB(20, 40, 160) },
		M1 = "WORMHOLE STRIKES",
		Abilities = { "DIMENSIONAL STEP", "SPATIAL PURSUIT", "DIMENSIONAL BREAK" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "AWAKEN: INFINITE ROTATION",
		Next = 4,
	},
	[4] = {
		Name = "TUSK ACT 4",
		Tagline = "Infinite Rotation",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(255, 200, 70), Secondary = Color3.fromRGB(20, 40, 160) },
		M1 = "INFINITE BARRAGE",
		Abilities = { "GOLDEN SPIN NAIL", "INFINITE ROTATION", "GOLDEN PURSUIT" },
		AbilityKinds = { "Press", "Hold", "Press" },
		Ultimate = "INFINITE ROTATION",
		Next = nil, -- final form
	},
	-- Gyro Zeppeli: a separate character that reuses the same ability system.
	[5] = {
		Name = "GYRO ZEPPELI",
		Character = "Gyro",
		Tagline = "Steel Ball master",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(120, 220, 95), Secondary = Color3.fromRGB(40, 120, 50) },
		M1 = "STEEL BALL COMBO",
		Abilities = { "STEEL BALL THROW", "SPIN TORNADO", "SPIN VIBRATION" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "BALL BREAKER",
		Next = nil,
		Module = "GyroZeppeli", -- server moves
		ClientModule = "Gyro", -- client visuals (TuskActVFX.Gyro)
		CardTitle = "STAND  ·  BALL BREAKER",
	},
	-- Diego Brando: Scary Monsters (dinosaur Stand). Same ability system.
	[6] = {
		Name = "SCARY MONSTERS",
		Character = "Diego",
		Tagline = "Dinosaur Stand",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(80, 210, 220), Secondary = Color3.fromRGB(35, 60, 190) },
		M1 = "CLAW COMBO",
		Abilities = { "RAPTOR POUNCE", "DINO INFECTION", "SCARY MONSTERS" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "RAPTOR PACK",
		Next = nil,
		Module = "DiegoBrando", -- server moves
		ClientModule = "Diego", -- client visuals (TuskActVFX.Diego)
		CardTitle = "STAND  ·  SCARY MONSTERS",
		-- The HUD shows a timer on these slots while the attribute (server time) is in the future.
		Buffs = {
			{ Slot = 3, Attribute = "DinoModeUntil", Text = "ACTIVE" },
			{ Slot = 2, Attribute = "ThrallUntil", Text = "COMMAND" },
		},
	},
	-- Pork Pie Hat Kid: WIRED (fish hooks and steel cables from a winch in his mouth).
	[7] = {
		Name = "WIRED",
		Character = "PorkPie",
		Tagline = "Hooks from the water",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(165, 215, 80), Secondary = Color3.fromRGB(95, 105, 125) },
		M1 = "HOOK COMBO",
		Abilities = { "WIRED HOOK", "BAIT PAN", "DOUBLE HOOK LIFT" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "WIRED WINCH",
		Next = nil,
		Module = "PorkPieHatKid", -- server moves
		ClientModule = "PorkPie", -- client visuals (TuskActVFX.PorkPie)
		CardTitle = "STAND  ·  WIRED",
		Buffs = {
			{ Slot = 2, Attribute = "BaitPanUntil", Text = "BAITED" },
		},
	},
	-- Sandman (Soundman): IN A SILENT WAY (sounds written as solid words that
	-- cut, burn and explode when touched).
	[8] = {
		Name = "IN A SILENT WAY",
		Character = "Sandman",
		Tagline = "Sounds made solid",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(245, 185, 80), Secondary = Color3.fromRGB(50, 140, 160) },
		M1 = "SOUND CUT COMBO",
		Abilities = { "SOUND SLASH", "SOUND TRAP", "SAND RUN" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "SILENT SYMPHONY",
		Next = nil,
		Module = "Sandman", -- server moves
		WalkSpeed = 1.25, -- he's a runner: 25% faster than everyone else
		ClientModule = "SandmanVFX", -- client visuals (TuskActVFX.SandmanVFX)
		CardTitle = "STAND  ·  IN A SILENT WAY",
	},
	-- Mountain Tim: OH! LONESOME ME (splits his body into pieces that slide
	-- along his lasso rope).
	[9] = {
		Name = "OH! LONESOME ME",
		Character = "MountainTim",
		Tagline = "Split along the rope",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(214, 156, 84), Secondary = Color3.fromRGB(96, 62, 38) },
		M1 = "LASSO COMBO",
		Abilities = { "LASSO SNARE", "SPLIT DODGE", "SPLIT BARRAGE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "LONESOME ROUNDUP",
		Next = nil,
		Module = "MountainTim", -- server moves
		ClientModule = "MountainTimVFX", -- client visuals (TuskActVFX.MountainTimVFX)
		CardTitle = "STAND  ·  OH! LONESOME ME",
	},
	-- Hot Pants: CREAM STARTER (a spray can that sprays flesh: seals wounds,
	-- coats and smothers enemies).
	[10] = {
		Name = "CREAM STARTER",
		Character = "HotPants",
		Tagline = "Flesh spray",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(242, 140, 172), Secondary = Color3.fromRGB(120, 60, 92) },
		M1 = "SPRAY COMBO",
		Abilities = { "FLESH SPRAY", "FLESH SEAL", "FLESH MEND" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "FLESH STORM",
		Next = nil,
		Module = "HotPants", -- server moves
		ClientModule = "HotPantsVFX", -- client visuals (TuskActVFX.HotPantsVFX)
		CardTitle = "STAND  ·  CREAM STARTER",
		Buffs = {
			{ Slot = 3, Attribute = "FleshMendUntil", Text = "HEALING" },
		},
	},
	-- Blackmore: CATCH THE RAINBOW (freezes raindrops in mid-air: cuts with
	-- them, walks on them, scatters into them).
	[11] = {
		Name = "CATCH THE RAINBOW",
		Character = "Blackmore",
		Tagline = "Raindrops frozen in the air",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(110, 180, 255), Secondary = Color3.fromRGB(40, 50, 90) },
		M1 = "RAINDROP COMBO",
		Abilities = { "RAINDROP BLADES", "RAINDROP STEP", "RAINDROP CAGE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "CATCH THE RAINBOW",
		Next = nil,
		Module = "Blackmore", -- server moves
		ClientModule = "BlackmoreVFX", -- client visuals (TuskActVFX.BlackmoreVFX)
		CardTitle = "STAND  ·  CATCH THE RAINBOW",
	},
	-- Axl RO: CIVIL WAR (makes a target's guilt real: specters and the things
	-- they abandoned rise up and engulf them in a crushing membrane; water,
	-- like the rain, washes it away).
	[12] = {
		Name = "CIVIL WAR",
		Character = "Axl",
		Tagline = "Guilt made real",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(214, 60, 70), Secondary = Color3.fromRGB(226, 196, 110) },
		M1 = "GUILT COMBO",
		Abilities = { "GUILT SPECTERS", "ABANDONED JUNK", "GUILT MEMBRANE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "CIVIL WAR",
		Next = nil,
		Module = "Axl", -- server moves
		ClientModule = "AxlVFX", -- client visuals (TuskActVFX.AxlVFX)
		CardTitle = "STAND  ·  CIVIL WAR",
		Passive = "GUILT: your hits mark them; your moves feed on it",
	},
	-- Funny Valentine: D4C (Dirty Deeds Done Dirt Cheap): slips between
	-- parallel worlds when sandwiched between things (a flag), brings
	-- people from other worlds, and Love Train turns misfortune away.
	[13] = {
		Name = "D4C",
		Character = "Valentine",
		Tagline = "Dirty Deeds Done Dirt Cheap",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(120, 170, 255), Secondary = Color3.fromRGB(236, 120, 170) },
		M1 = "DIRTY DEEDS COMBO",
		Abilities = { "DIMENSION HOP", "PARALLEL VALENTINE", "MENGER SPONGE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "D4C LOVE TRAIN",
		Next = nil,
		Module = "Valentine", -- server moves
		ClientModule = "ValentineVFX", -- client visuals (TuskActVFX.ValentineVFX)
		CardTitle = "STAND  ·  D4C",
		Buffs = {
			{ Slot = 2, Attribute = "ParallelCloneUntil", Text = "PARALLEL" },
		},
	},
	-- Diego Brando from another world (AU): THE WORLD (stops time).
	[14] = {
		Name = "THE WORLD",
		Character = "DiegoAU",
		Tagline = "Diego from another world",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(236, 196, 70), Secondary = Color3.fromRGB(70, 170, 160) },
		M1 = "MUDA COMBO",
		Abilities = { "STAND GRAB", "STAND BARRAGE", "KNIFE THROW" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "THE WORLD: TIME STOP",
		Next = nil,
		Module = "DiegoAU", -- server moves
		ClientModule = "DiegoAUVFX", -- client visuals (TuskActVFX.DiegoAUVFX)
		CardTitle = "STAND  ·  THE WORLD",
		Buffs = {
			{ Slot = 2, Attribute = "WorldBarrageUntil", Text = "MUDA" },
		},
	},
	-- Josuke Higashikata (JoJolion): SOFT & WET (plunder bubbles that steal
	-- things from what they touch: friction, sight, sound...).
	[15] = {
		Name = "SOFT & WET",
		Character = "Josuke",
		Tagline = "Plunder bubbles",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(120, 190, 240), Secondary = Color3.fromRGB(240, 200, 90) },
		M1 = "SOFT & WET COMBO",
		Abilities = { "PLUNDER: FRICTION", "PLUNDER: SIGHT", "BUBBLE MINES" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "GO BEYOND",
		Next = nil,
		Module = "Josuke", -- server moves
		ClientModule = "JosukeVFX", -- client visuals (TuskActVFX.JosukeVFX)
		CardTitle = "STAND  ·  SOFT & WET",
	},
	-- Tooru (JoJolion): WONDER OF U. The "calamity": whoever pursues him is
	-- struck by misfortune (falling debris, trips, accidents).
	[16] = {
		Name = "WONDER OF U",
		Character = "Tooru",
		Tagline = "The flow of calamity",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(150, 40, 50), Secondary = Color3.fromRGB(240, 196, 60) },
		M1 = "WONDER OF U COMBO",
		Abilities = { "CALAMITY: DEBRIS", "THE PURSUER'S CURSE", "WONDER OF U" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "THE FLOW OF CALAMITY",
		Next = nil,
		Module = "Tooru", -- server moves
		ClientModule = "TooruVFX", -- client visuals (TuskActVFX.TooruVFX)
		CardTitle = "STAND  ·  WONDER OF U",
	},
	-- Jodio Joestar (The JOJOLands): NOVEMBER RAIN. Heavy raindrops that
	-- strike with crushing pressure.
	[17] = {
		Name = "NOVEMBER RAIN",
		Character = "Jodio",
		Tagline = "Crushing rain",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(90, 170, 240), Secondary = Color3.fromRGB(240, 120, 190) },
		M1 = "NOVEMBER RAIN COMBO",
		Abilities = { "HEAVY RAIN", "RAIN BULLETS", "RAIN JET" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "NOVEMBER RAIN: TORRENT",
		Next = nil,
		Module = "Jodio", -- server moves
		ClientModule = "JodioVFX", -- client visuals (TuskActVFX.JodioVFX)
		CardTitle = "STAND  ·  NOVEMBER RAIN",
	},
	-- JOHN ROD: a Stand that is a single bent metal rod tracing the outline
	-- of a man. Its user can send it off and steer it from far away.
	[18] = {
		Name = "JOHN ROD",
		Character = "JohnRod",
		Tagline = "Remote-control rod",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(220, 228, 240), Secondary = Color3.fromRGB(120, 200, 255) },
		M1 = "ROD STRIKES",
		Abilities = { "REMOTE CONTROL", "ROD LASH", "WIRE SNARE" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "OUTLINE CAGE",
		Next = nil,
		Module = "JohnRod", -- server moves
		ClientModule = "JohnRodVFX", -- client visuals (TuskActVFX.JohnRodVFX)
		CardTitle = "STAND  ·  JOHN ROD",
	},
	-- RINGO ROADAGAIN: MANDOM. Turning his watch rewinds time by exactly 6
	-- seconds, and only he remembers.
	[19] = {
		Name = "MANDOM",
		Character = "Ringo",
		Tagline = "Six seconds back",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(214, 120, 160), Secondary = Color3.fromRGB(240, 200, 70) },
		M1 = "REVOLVER COMBO",
		Abilities = { "SIX SECONDS", "QUICK DRAW", "MANDOM COUNTER" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "THE PATH OF JUSTICE",
		Next = nil,
		Module = "Ringo", -- server moves
		ClientModule = "RingoVFX", -- client visuals (TuskActVFX.RingoVFX)
		CardTitle = "STAND  ·  MANDOM",
	},
	-- JOTARO KUJO: STAR PLATINUM. Precision, speed and power; stops time.
	[20] = {
		Name = "STAR PLATINUM",
		Character = "Jotaro",
		Tagline = "Ora ora ora",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(130, 110, 220), Secondary = Color3.fromRGB(240, 196, 70) },
		M1 = "ORA COMBO",
		Abilities = { "ORA RUSH", "STAR FINGER", "BEARING SHOT" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "STAR PLATINUM: THE WORLD",
		Next = nil,
		Module = "Jotaro", -- server moves
		ClientModule = "JotaroVFX", -- client visuals (TuskActVFX.JotaroVFX)
		CardTitle = "STAND  ·  STAR PLATINUM",
	},
	-- DIO: THE WORLD (Part 3; not Diego's). A vampire; knives; a road roller.
	[21] = {
		Name = "THE WORLD",
		Character = "Dio",
		Tagline = "Muda muda muda",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(240, 196, 50), Secondary = Color3.fromRGB(60, 160, 110) },
		M1 = "MUDA COMBO",
		Abilities = { "VAMPIRE DRAIN", "SPACE RIPPER STINGY EYES", "KNIFE VOLLEY" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "ZA WARUDO: ROAD ROLLER",
		Next = nil,
		Module = "Dio", -- server moves
		ClientModule = "DioVFX", -- client visuals (TuskActVFX.DioVFX)
		CardTitle = "STAND  ·  THE WORLD",
	},
	-- JOSEPH JOESTAR: HERMIT PURPLE. Thorny vines, Hamon through them, and running away.
	[22] = {
		Name = "HERMIT PURPLE",
		Character = "Joseph",
		Tagline = "Your next line is...",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(150, 80, 200), Secondary = Color3.fromRGB(255, 214, 80) },
		M1 = "HAMON COMBO",
		Abilities = { "HERMIT GRAB", "HAMON VINES", "NIGERUNDAYO!" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "HERMIT WEB OVERDRIVE",
		Next = nil,
		Module = "Joseph", -- server moves
		ClientModule = "JosephVFX", -- client visuals (TuskActVFX.JosephVFX)
		CardTitle = "STAND  ·  HERMIT PURPLE",
	},
}

-- Which character an Act belongs to ("Johnny" for Tusk Acts 1-4).
function TuskActRegistry.characterOf(act)
	local info = TuskActRegistry.Acts[act]
	return info and info.Character or "Johnny"
end

-- The Act a character starts on.
TuskActRegistry.StartAct = { Johnny = 1, Gyro = 5, Diego = 6, PorkPie = 7, Sandman = 8, MountainTim = 9, HotPants = 10, Blackmore = 11, Axl = 12, Valentine = 13, DiegoAU = 14, Josuke = 15, Tooru = 16, Jodio = 17, JohnRod = 18, Ringo = 19, Jotaro = 20, Dio = 21, Joseph = 22 }

function TuskActRegistry.get(act)
	return TuskActRegistry.Acts[act]
end

function TuskActRegistry.isImplemented(act)
	local info = TuskActRegistry.Acts[act]
	return info ~= nil and info.Implemented == true
end

return TuskActRegistry
end

-- ======================================================================
-- MODULE: TuskAnimation
-- ======================================================================
__modules["TuskAnimation"] = function()
--[[
	TuskAnimation  (StarterPlayerScripts.SpinClient.TuskAnimation)
	("TuskAnimationController" in the design doc)

	Plays Johnny / Gyro move animations on ANY character, on every client.
	Two layers per character:
	  * Hold   : a sustained pose (Sneak, Charge, Gyro's ball stance) with a
	             breathing idle on top, until stopped
	  * Action : a keyframed move (M1 hits, throws...) that plays on top,
	             then settles back to the Hold pose or rest

	Default = procedural poses built from Motor6D C0 offsets (no uploads
	needed, works on R15 and R6). If TuskConfig.AnimationIds[name] holds
	an uploaded animation id, that real animation plays instead.

	Pose values: degrees {X, Y, Z} rotation in the parent part's space,
	optional 4th value = vertical offset (studs), optional 5th (Root only)
	= forward lunge (studs).
	  Arms:  +X raises the arm forward, +Z (right) / -Z (left) lifts it out.
	  Waist / Root: -X bends forward, -Y turns the right shoulder forward.
	  Hips:  +X lifts the thigh forward.   Knees: -X bends the knee.
	Mirror("Pose") makes the left-handed version of a pose.

	Keyframes: { Time, Pose, Ease, Shake }
	  Ease : "Out" (default), "Snap" (fast strike), "Back" (overshoot and
	         settle), "In" (slow then fast: anticipation), "Sine", "Linear"
	  Shake: impact jitter in degrees, fading over 0.16 s from that key
	Every move follows: anticipation -> strike (snap/overshoot + impact
	shake) -> follow-through -> settle.
]]

local Players = game:GetService("Players")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local VFXLib = __require("VFXLib")
local JointCache = __require("JointCache")

local TuskAnimation = {}

local JOINTS = {
	R15 = {
		RightArm = { "RightUpperArm", "RightShoulder" },
		LeftArm = { "LeftUpperArm", "LeftShoulder" },
		Waist = { "UpperTorso", "Waist" },
		Neck = { "Head", "Neck" },
		Root = { "LowerTorso", "Root" },
		RightHip = { "RightUpperLeg", "RightHip" },
		LeftHip = { "LeftUpperLeg", "LeftHip" },
		RightKnee = { "RightLowerLeg", "RightKnee" },
		LeftKnee = { "LeftLowerLeg", "LeftKnee" },
		RightElbow = { "RightLowerArm", "RightElbow" },
		LeftElbow = { "LeftLowerArm", "LeftElbow" },
	},
	R6 = {
		RightArm = { "Torso", "Right Shoulder" },
		LeftArm = { "Torso", "Left Shoulder" },
		Neck = { "Torso", "Neck" },
		Root = { "HumanoidRootPart", "RootJoint" },
		RightHip = { "Torso", "Right Hip" },
		LeftHip = { "Torso", "Left Hip" },
	},
}

TuskAnimation.Poses = {
	Rest = {},
	Point = { Root = { 0, -12, 0 }, RightArm = { 92, 0, 0 }, LeftArm = { 15, 0, -10 }, Waist = { 0, -18, 0 }, Neck = { 0, 12, 0 } },
	PointRecoil = { Root = { 6, -8, 0 }, RightArm = { 112, 0, 0 }, RightElbow = { 10, 0, 0 }, Waist = { 8, -14, 0 }, Neck = { 4, 10, 0 } },
	ChargeNail = { RightArm = { 75, 0, 28 }, LeftArm = { 75, 0, -28 }, RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 }, Waist = { -8, 0, 0 }, Root = { 0, 0, 0, -0.15 }, RightKnee = { -12, 0, 0 }, LeftKnee = { -12, 0, 0 }, RightHip = { 8, 0, 0 }, LeftHip = { 8, 0, 0 } },
	AwakenCrouch = { Root = { -8, 0, 0, -0.45 }, RightArm = { 30, 0, 40 }, LeftArm = { 30, 0, -40 }, RightElbow = { 60, 0, 0 }, LeftElbow = { 60, 0, 0 }, Waist = { -28, 0, 0 }, Neck = { -18, 0, 0 }, RightHip = { 40, 0, 0 }, LeftHip = { 40, 0, 0 }, RightKnee = { -60, 0, 0 }, LeftKnee = { -60, 0, 0 } },
	AwakenRise = { Root = { 8, 0, 0, 0.15 }, RightArm = { 135, 0, 38 }, LeftArm = { 135, 0, -38 }, Waist = { 16, 0, 0 }, Neck = { 24, 0, 0 } },
	Sneak = { Root = { 0, 0, 0, -0.65 }, Waist = { -26, 0, 0 }, Neck = { 22, 0, 0 }, RightHip = { 50, 0, 0 }, LeftHip = { 50, 0, 0 }, RightKnee = { -85, 0, 0 }, LeftKnee = { -85, 0, 0 }, RightArm = { 25, 0, 8 }, LeftArm = { 25, 0, -8 } },
	Emerge = { Root = { 6, 0, 0, 0.2 }, RightArm = { 150, 0, 15 }, LeftArm = { 40, 0, -40 }, Waist = { 15, 0, 0 }, Neck = { 12, 0, 0 } },

	-- JOHNNY: finger-gun nail shots, fired from a low, steady stance.
	FlickRWind = { Root = { 0, 12, 0 }, Waist = { 2, 16, 0 }, RightArm = { 62, 0, -28 }, RightElbow = { 55, 0, 0 }, LeftArm = { 28, 0, -20 }, Neck = { 0, -10, 0 }, LeftHip = { 10, 0, 0 }, LeftKnee = { -10, 0, 0 } },
	FlickR = { Root = { 0, -18, 0, -0.05, 0.2 }, RightArm = { 96, -8, 6 }, RightElbow = { 0, 0, 0 }, LeftArm = { 38, 0, -22 }, LeftElbow = { 40, 0, 0 }, Waist = { 0, -22, 0 }, Neck = { 0, 16, 0 }, RightHip = { 18, 0, 0 }, RightKnee = { -16, 0, 0 }, LeftHip = { -10, 0, 0 } },
	FlickRFollow = { Root = { -2, -22, 0, -0.08, 0.15 }, RightArm = { 84, -14, 2 }, RightElbow = { 12, 0, 0 }, LeftArm = { 34, 0, -24 }, LeftElbow = { 40, 0, 0 }, Waist = { -4, -26, 0 }, Neck = { 0, 18, 0 }, RightHip = { 14, 0, 0 }, RightKnee = { -14, 0, 0 } },
	FingerGun = { Root = { 0, -14, 0, -0.08 }, RightArm = { 95, 0, 5 }, LeftArm = { 62, 0, -38 }, LeftElbow = { 50, 0, 0 }, Waist = { 0, -22, 0 }, Neck = { 0, 16, 0 }, RightHip = { 12, 0, 0 }, RightKnee = { -14, 0, 0 }, LeftHip = { -10, 0, 0 }, LeftKnee = { -6, 0, 0 } },
	-- NAIL SHOT start-up (Johnny): his right hand comes up in front of him,
	-- fingers pointing up, the nails spinning (then he levels it and fires).
	NailRaise = { Root = { 0, -16, 0, -0.06 }, Waist = { -2, -18, 0 }, Neck = { 4, 14, 0 }, RightArm = { 118, 0, 10 }, RightElbow = { 62, 0, 0 }, LeftArm = { 40, 0, -26 }, LeftElbow = { 60, 0, 0 }, RightHip = { 10, 0, 0 }, RightKnee = { -12, 0, 0 }, LeftHip = { -8, 0, 0 } },
	FingerGunRecoil = { Root = { 8, -10, 0, -0.04, -0.15 }, RightArm = { 120, 0, 6 }, RightElbow = { 14, 0, 0 }, LeftArm = { 56, 0, -36 }, LeftElbow = { 50, 0, 0 }, Waist = { 8, -16, 0 }, Neck = { 6, 12, 0 }, RightHip = { 8, 0, 0 }, RightKnee = { -10, 0, 0 } },
	SlamWindup = { Root = { 10, 16, 0, -0.1 }, RightArm = { 168, 0, 12 }, RightElbow = { 30, 0, 0 }, LeftArm = { 42, 0, -32 }, Waist = { 14, 18, 0 }, Neck = { 8, -8, 0 }, LeftHip = { 24, 0, 0 }, LeftKnee = { -28, 0, 0 } },
	Slam = { Root = { -16, -12, 0, -0.4, 0.4 }, RightArm = { 52, 0, 0 }, RightElbow = { 0, 0, 0 }, LeftArm = { 18, 0, -24 }, Waist = { -24, -12, 0 }, Neck = { -6, 10, 0 }, RightHip = { 36, 0, 0 }, RightKnee = { -46, 0, 0 }, LeftHip = { -14, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	SlamFollow = { Root = { -10, -10, 0, -0.3, 0.3 }, RightArm = { 40, 0, 6 }, LeftArm = { 20, 0, -24 }, Waist = { -16, -10, 0 }, RightHip = { 28, 0, 0 }, RightKnee = { -36, 0, 0 }, LeftKnee = { -14, 0, 0 } },
	SpinChargeA = { RightArm = { 104, 10, 30 }, RightElbow = { 20, 0, 0 }, LeftArm = { 72, 0, -42 }, LeftElbow = { 40, 0, 0 }, Waist = { -6, -10, 0 }, Root = { 0, -6, 0, -0.18 }, RightKnee = { -16, 0, 0 }, LeftKnee = { -16, 0, 0 }, RightHip = { 10, 0, 0 }, LeftHip = { 10, 0, 0 } },
	SpinChargeB = { RightArm = { 96, -10, 22 }, RightElbow = { 26, 0, 0 }, LeftArm = { 72, 0, -42 }, LeftElbow = { 40, 0, 0 }, Waist = { -6, -10, 0 }, Root = { 0, -6, 0, -0.2 }, RightKnee = { -18, 0, 0 }, LeftKnee = { -18, 0, 0 }, RightHip = { 12, 0, 0 }, LeftHip = { 12, 0, 0 } },
	SpreadWind = { Root = { -6, 0, 0, -0.2 }, RightArm = { 40, 0, 20 }, LeftArm = { 40, 0, -20 }, RightElbow = { 70, 0, 0 }, LeftElbow = { 70, 0, 0 }, Waist = { -14, 0, 0 }, Neck = { -10, 0, 0 }, RightKnee = { -20, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	Spread = { Root = { 8, 0, 0, 0.05 }, RightArm = { 92, 0, 72 }, LeftArm = { 92, 0, -72 }, Waist = { 12, 0, 0 }, Neck = { 16, 0, 0 } },
	Dive = { Root = { 0, 0, 0, -0.45, 0.4 }, Waist = { -40, 0, 0 }, Neck = { 20, 0, 0 }, RightArm = { 158, 0, 12 }, LeftArm = { 158, 0, -12 }, RightHip = { 40, 0, 0 }, LeftHip = { 20, 0, 0 }, RightKnee = { -45, 0, 0 }, LeftKnee = { -30, 0, 0 } },
	LungeStep = { Root = { -12, -10, 0, -0.25, 0.6 }, Waist = { -18, -12, 0 }, Neck = { 10, 8, 0 }, RightArm = { 88, 0, 0 }, LeftArm = { -24, 0, -12 }, RightHip = { 40, 0, 0 }, LeftHip = { -28, 0, 0 }, RightKnee = { -34, 0, 0 }, LeftKnee = { -10, 0, 0 } },
	PushTwo = { Root = { -12, 0, 0, -0.1, 0.4 }, RightArm = { 94, 0, 14 }, LeftArm = { 94, 0, -14 }, Waist = { -14, 0, 0 }, Neck = { 8, 0, 0 }, RightHip = { 24, 0, 0 }, LeftHip = { -18, 0, 0 }, RightKnee = { -20, 0, 0 } },
	WindSpin = { Root = { 0, -48, 0, -0.1 }, Waist = { 0, -62, 0 }, Neck = { 0, 40, 0 }, RightArm = { 62, 0, 84 }, LeftArm = { 40, 0, -30 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -24, 0, 0 } },
	DashPunch = { Root = { -18, -16, 0, -0.3, 0.8 }, Waist = { -22, -28, 0 }, Neck = { 12, 14, 0 }, RightArm = { 92, 0, 0 }, LeftArm = { -32, 0, -22 }, RightHip = { 44, 0, 0 }, RightKnee = { -62, 0, 0 }, LeftHip = { -32, 0, 0 }, LeftKnee = { -8, 0, 0 } },

	-- GYRO: a ball thrower: weight shifts, leg lifts, full follow-through.
	GyroIdle = { RightArm = { 55, 0, 14 }, RightElbow = { 45, 0, 0 }, LeftArm = { 12, 0, -10 }, Waist = { 0, -6, 0 }, Neck = { 0, 4, 0 } },
	JabWind = { Root = { 0, 12, 0 }, Waist = { 0, 14, 0 }, RightArm = { 38, 0, 18 }, RightElbow = { 80, 0, 0 }, LeftArm = { 48, 0, -24 }, LeftElbow = { 60, 0, 0 }, Neck = { 0, -8, 0 }, RightKnee = { -10, 0, 0 } },
	Jab = { Root = { 0, -20, 0, -0.05, 0.35 }, RightArm = { 90, 0, 12 }, RightElbow = { 0, 0, 0 }, Waist = { 0, -30, 0 }, Neck = { 0, 22, 0 }, LeftArm = { 32, 0, -20 }, LeftElbow = { 70, 0, 0 }, LeftHip = { 22, 0, 0 }, LeftKnee = { -18, 0, 0 }, RightHip = { -12, 0, 0 } },
	JabRecover = { Root = { 0, -8, 0, 0, 0.15 }, RightArm = { 66, 0, 14 }, RightElbow = { 40, 0, 0 }, Waist = { 0, -12, 0 }, LeftArm = { 36, 0, -20 }, LeftElbow = { 60, 0, 0 } },
	GHookWind = { Root = { 0, 26, 0, -0.05 }, RightArm = { 80, 0, 82 }, RightElbow = { 70, 0, 0 }, Waist = { 0, 28, 0 }, Neck = { 0, -14, 0 }, LeftArm = { 40, 0, -20 }, RightKnee = { -14, 0, 0 } },
	GHook = { Root = { 0, -40, 0, -0.1, 0.3 }, RightArm = { 86, -32, 12 }, RightElbow = { 60, 0, 0 }, Waist = { 0, -44, 0 }, Neck = { 0, 30, 0 }, LeftArm = { 30, 0, -20 }, LeftElbow = { 70, 0, 0 }, LeftHip = { 18, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	GHookFollow = { Root = { 0, -50, 0, -0.1, 0.25 }, RightArm = { 76, -50, 20 }, RightElbow = { 70, 0, 0 }, Waist = { 0, -52, 0 }, Neck = { 0, 34, 0 }, LeftArm = { 26, 0, -24 } },
	KickChamber = { Root = { 10, 0, 0, 0.05 }, RightHip = { 74, 0, 0 }, RightKnee = { -95, 0, 0 }, LeftKnee = { -12, 0, 0 }, Waist = { 10, 0, 0 }, Neck = { 6, 0, 0 }, RightArm = { 30, 0, 34 }, LeftArm = { 34, 0, -34 } },
	FrontKick = { Root = { 18, 0, 0, 0, 0.3 }, RightHip = { 92, 0, 0 }, RightKnee = { -6, 0, 0 }, LeftKnee = { -16, 0, 0 }, Waist = { 14, 0, 0 }, Neck = { -6, 0, 0 }, RightArm = { 26, 0, 40 }, LeftArm = { 28, 0, -40 } },
	KickRechamber = { Root = { 8, 0, 0, 0, 0.2 }, RightHip = { 60, 0, 0 }, RightKnee = { -80, 0, 0 }, LeftKnee = { -10, 0, 0 }, Waist = { 8, 0, 0 }, RightArm = { 30, 0, 30 }, LeftArm = { 30, 0, -30 } },
	OverheadWind = { Root = { 12, 18, 0, 0.1 }, RightArm = { 175, 0, 15 }, RightElbow = { 40, 0, 0 }, Waist = { 16, 22, 0 }, Neck = { 10, -10, 0 }, LeftArm = { 60, 0, -30 }, LeftHip = { 22, 0, 0 }, LeftKnee = { -26, 0, 0 } },
	OverheadSmash = { Root = { -18, -10, 0, -0.45, 0.45 }, RightArm = { 56, 0, 0 }, RightElbow = { 0, 0, 0 }, Waist = { -28, -15, 0 }, Neck = { -10, 10, 0 }, LeftArm = { 10, 0, -30 }, LeftHip = { 40, 0, 0 }, LeftKnee = { -38, 0, 0 }, RightHip = { -18, 0, 0 }, RightKnee = { -24, 0, 0 } },
	SmashFollow = { Root = { -12, -8, 0, -0.35, 0.35 }, RightArm = { 36, 0, 4 }, Waist = { -20, -12, 0 }, Neck = { -4, 8, 0 }, LeftArm = { 14, 0, -28 }, LeftHip = { 34, 0, 0 }, LeftKnee = { -32, 0, 0 }, RightKnee = { -18, 0, 0 } },
	PitchSet = { Root = { 0, 24, 0 }, Waist = { 0, 22, 0 }, Neck = { 0, -24, 0 }, RightArm = { 58, 0, 12 }, RightElbow = { 70, 0, 0 }, LeftArm = { 58, 0, -12 }, LeftElbow = { 70, 0, 0 } },
	PitchBack = { Root = { 6, 34, 0, 0.1 }, RightArm = { 200, 0, 40 }, RightElbow = { 50, 0, 0 }, Waist = { 6, 38, 0 }, Neck = { 0, -30, 0 }, LeftArm = { 82, 0, -30 }, LeftHip = { 62, 0, 0 }, LeftKnee = { -70, 0, 0 }, RightKnee = { -12, 0, 0 } },
	PitchRelease = { Root = { -16, -34, 0, -0.2, 0.6 }, RightArm = { 76, 0, -10 }, RightElbow = { 0, 0, 0 }, Waist = { -24, -38, 0 }, Neck = { 0, 30, 0 }, LeftArm = { -14, 0, -32 }, LeftHip = { 32, 0, 0 }, LeftKnee = { -24, 0, 0 }, RightHip = { -32, 0, 0 }, RightKnee = { -20, 0, 0 } },
	PitchFollow = { Root = { -20, -46, 0, -0.25, 0.5 }, RightArm = { 38, 0, -42 }, RightElbow = { 30, 0, 0 }, Waist = { -30, -46, 0 }, Neck = { 0, 34, 0 }, LeftArm = { -22, 0, -26 }, LeftHip = { 36, 0, 0 }, LeftKnee = { -32, 0, 0 }, RightHip = { -40, 0, 0 }, RightKnee = { -40, 0, 0 } },
	BowlWind = { Root = { 0, 6, 0, -0.45 }, RightArm = { -58, 0, 12 }, Waist = { -18, 8, 0 }, Neck = { 12, 0, 0 }, LeftArm = { 40, 0, -30 }, LeftHip = { 52, 0, 0 }, LeftKnee = { -66, 0, 0 }, RightKnee = { -46, 0, 0 } },
	BowlRelease = { Root = { 0, -4, 0, -0.5, 0.5 }, RightArm = { 64, 0, 0 }, Waist = { -30, -4, 0 }, Neck = { 18, 0, 0 }, LeftArm = { 20, 0, -40 }, LeftHip = { 58, 0, 0 }, LeftKnee = { -68, 0, 0 }, RightHip = { -22, 0, 0 }, RightKnee = { -30, 0, 0 } },
	BowlFollow = { Root = { 0, -6, 0, -0.35, 0.4 }, RightArm = { 112, 0, 0 }, Waist = { -18, -6, 0 }, Neck = { 12, 0, 0 }, LeftArm = { 16, 0, -40 }, LeftHip = { 50, 0, 0 }, LeftKnee = { -60, 0, 0 }, RightHip = { -26, 0, 0 }, RightKnee = { -24, 0, 0 } },
	PalmWind = { Root = { 0, 22, 0, -0.1 }, RightArm = { 40, 0, 22 }, RightElbow = { 90, 0, 0 }, Waist = { 0, 28, 0 }, Neck = { 0, -14, 0 }, LeftArm = { 50, 0, -20 }, LeftElbow = { 50, 0, 0 }, RightKnee = { -18, 0, 0 } },
	PalmPress = { Root = { -12, -12, 0, -0.15, 0.45 }, RightArm = { 92, 0, 0 }, RightElbow = { 0, 0, 0 }, LeftArm = { 72, 0, -22 }, LeftElbow = { 40, 0, 0 }, Waist = { -16, -12, 0 }, Neck = { 6, 8, 0 }, LeftHip = { 32, 0, 0 }, LeftKnee = { -32, 0, 0 }, RightHip = { -16, 0, 0 } },
	PalmPush = { Root = { -16, -14, 0, -0.2, 0.6 }, RightArm = { 98, 0, 0 }, LeftArm = { 76, 0, -18 }, LeftElbow = { 30, 0, 0 }, Waist = { -20, -14, 0 }, Neck = { 6, 8, 0 }, LeftHip = { 38, 0, 0 }, LeftKnee = { -38, 0, 0 }, RightHip = { -20, 0, 0 }, RightKnee = { -10, 0, 0 } },
	BreakerWindA = { Root = { 0, 0, 0, -0.3 }, RightArm = { 122, 0, 62 }, RightElbow = { 30, 0, 0 }, Waist = { 0, 46, 0 }, Neck = { 0, -30, 0 }, LeftArm = { 60, 0, -40 }, LeftKnee = { -25, 0, 0 }, RightKnee = { -25, 0, 0 } },
	BreakerWindB = { Root = { 0, 0, 0, -0.35 }, RightArm = { 132, 10, 70 }, RightElbow = { 40, 0, 0 }, Waist = { 0, 52, 0 }, Neck = { 0, -34, 0 }, LeftArm = { 64, 0, -44 }, LeftKnee = { -30, 0, 0 }, RightKnee = { -30, 0, 0 } },

	-- DIEGO: a hunched, clawing predator (human form; the raptor animates itself).
	DiegoStance = { RightArm = { 38, 0, 18 }, RightElbow = { 55, 0, 0 }, LeftArm = { 38, 0, -18 }, LeftElbow = { 55, 0, 0 }, Waist = { -8, 0, 0 }, Neck = { 6, 0, 0 } },
	ClawWindR = { Root = { 0, 14, 0, -0.05 }, Waist = { 6, 18, 0 }, RightArm = { 152, 0, 32 }, RightElbow = { 50, 0, 0 }, LeftArm = { 42, 0, -20 }, LeftElbow = { 50, 0, 0 }, Neck = { 0, -10, 0 }, LeftHip = { 14, 0, 0 }, LeftKnee = { -16, 0, 0 } },
	ClawR = { Root = { -10, -20, 0, -0.15, 0.35 }, Waist = { -16, -24, 0 }, RightArm = { 42, 0, -30 }, RightElbow = { 18, 0, 0 }, LeftArm = { 50, 0, -24 }, LeftElbow = { 45, 0, 0 }, Neck = { 4, 16, 0 }, RightHip = { 24, 0, 0 }, RightKnee = { -30, 0, 0 }, LeftHip = { -12, 0, 0 } },
	TailWhipWind = { Root = { 0, 42, 0, -0.12 }, Waist = { 0, 30, 0 }, Neck = { 0, -20, 0 }, RightArm = { 40, 0, 40 }, LeftArm = { 40, 0, -40 }, RightElbow = { 40, 0, 0 }, LeftElbow = { 40, 0, 0 }, LeftKnee = { -22, 0, 0 }, RightKnee = { -22, 0, 0 }, LeftHip = { 12, 0, 0 }, RightHip = { 12, 0, 0 } },
	TailWhip = { Root = { 0, -75, 0, -0.18 }, Waist = { 0, -40, 0 }, Neck = { 0, 45, 0 }, RightArm = { 50, 0, 62 }, LeftArm = { 30, 0, -52 }, RightKnee = { -20, 0, 0 }, LeftKnee = { -20, 0, 0 }, RightHip = { 12, 0, 0 }, LeftHip = { 12, 0, 0 } },
	BiteWind = { Root = { 8, 0, 0, -0.12 }, Waist = { 14, 0, 0 }, Neck = { 22, 0, 0 }, RightArm = { 60, 0, 42 }, LeftArm = { 60, 0, -42 }, RightElbow = { 60, 0, 0 }, LeftElbow = { 60, 0, 0 }, RightKnee = { -22, 0, 0 }, LeftKnee = { -22, 0, 0 }, RightHip = { 14, 0, 0 }, LeftHip = { 14, 0, 0 } },
	Bite = { Root = { -20, 0, 0, -0.25, 0.6 }, Waist = { -26, 0, 0 }, Neck = { -12, 0, 0 }, RightArm = { 96, 0, 26 }, LeftArm = { 96, 0, -26 }, RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 }, LeftHip = { 36, 0, 0 }, LeftKnee = { -40, 0, 0 }, RightHip = { -24, 0, 0 } },
	PounceCrouch = { Root = { -14, 0, 0, -0.75 }, Waist = { -30, 0, 0 }, Neck = { 28, 0, 0 }, RightArm = { 40, 0, 30 }, LeftArm = { 40, 0, -30 }, RightElbow = { 70, 0, 0 }, LeftElbow = { 70, 0, 0 }, RightHip = { 70, 0, 0 }, LeftHip = { 70, 0, 0 }, RightKnee = { -100, 0, 0 }, LeftKnee = { -100, 0, 0 } },
	PounceLeap = { Root = { -30, 0, 0, 0, 0.3 }, Waist = { -20, 0, 0 }, Neck = { 30, 0, 0 }, RightArm = { 152, 0, 25 }, LeftArm = { 152, 0, -25 }, RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 }, RightHip = { 60, 0, 0 }, LeftHip = { 20, 0, 0 }, RightKnee = { -80, 0, 0 }, LeftKnee = { -40, 0, 0 } },
	PounceLand = { Root = { -18, 0, 0, -0.65, 0.3 }, Waist = { -28, 0, 0 }, Neck = { 22, 0, 0 }, RightArm = { 72, 0, 20 }, LeftArm = { 72, 0, -20 }, RightElbow = { 30, 0, 0 }, LeftElbow = { 30, 0, 0 }, RightHip = { 62, 0, 0 }, LeftHip = { 40, 0, 0 }, RightKnee = { -92, 0, 0 }, LeftKnee = { -60, 0, 0 } },
	TransformHunch = { Root = { -10, 0, 0, -0.45 }, Waist = { -36, 0, 0 }, Neck = { -22, 0, 0 }, RightArm = { 20, 0, 42 }, LeftArm = { 20, 0, -42 }, RightElbow = { 92, 0, 0 }, LeftElbow = { 92, 0, 0 }, RightKnee = { -52, 0, 0 }, LeftKnee = { -52, 0, 0 }, RightHip = { 32, 0, 0 }, LeftHip = { 32, 0, 0 } },
	Roar = { Root = { 10, 0, 0, 0.05 }, Waist = { 18, 0, 0 }, Neck = { 32, 0, 0 }, RightArm = { 100, 0, 72 }, LeftArm = { 100, 0, -72 }, RightElbow = { 40, 0, 0 }, LeftElbow = { 40, 0, 0 }, RightHip = { -10, 0, 0 }, LeftHip = { 10, 0, 0 }, LeftKnee = { -14, 0, 0 } },
	-- PORK PIE HAT KID: a crouched, twitchy kid; the hooks come out of his mouth.
	PPStance = { Root = { 0, 8, 0, -0.25 }, Waist = { -10, 6, 0 }, Neck = { 10, -6, 0 }, RightArm = { 20, 0, 30 }, RightElbow = { 30, 0, 0 }, LeftArm = { -10, 0, -35 }, LeftElbow = { 20, 0, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -45, 0, 0 }, LeftHip = { 12, 0, 0 }, LeftKnee = { -25, 0, 0 } },
	SpitWind = { Root = { 10, 0, 0, -0.1 }, Waist = { 16, 0, 0 }, Neck = { 34, 0, 0 }, RightArm = { 30, 0, 40 }, LeftArm = { 30, 0, -40 }, RightElbow = { 50, 0, 0 }, LeftElbow = { 50, 0, 0 }, RightKnee = { -18, 0, 0 }, LeftKnee = { -18, 0, 0 } },
	Spit = { Root = { -14, 0, 0, -0.2, 0.4 }, Waist = { -22, 0, 0 }, Neck = { -24, 0, 0 }, RightArm = { -20, 0, 30 }, LeftArm = { -20, 0, -30 }, RightHip = { 30, 0, 0 }, RightKnee = { -36, 0, 0 }, LeftHip = { -16, 0, 0 } },
	ReelBack = { Root = { 12, 0, 0, -0.2, -0.3 }, Waist = { 20, 0, 0 }, Neck = { 12, 0, 0 }, RightArm = { 70, 0, 20 }, RightElbow = { 80, 0, 0 }, LeftArm = { 70, 0, -20 }, LeftElbow = { 80, 0, 0 }, RightHip = { -20, 0, 0 }, LeftHip = { 34, 0, 0 }, LeftKnee = { -40, 0, 0 } },
	HoistUp = { Root = { 18, 0, 0, -0.1, -0.2 }, Waist = { 26, 0, 0 }, Neck = { 40, 0, 0 }, RightArm = { 150, 0, 30 }, LeftArm = { 150, 0, -30 }, RightElbow = { 20, 0, 0 }, LeftElbow = { 20, 0, 0 }, RightKnee = { -20, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	HoistSlam = { Root = { -20, 0, 0, -0.5, 0.3 }, Waist = { -32, 0, 0 }, Neck = { -30, 0, 0 }, RightArm = { 40, 0, 20 }, LeftArm = { 40, 0, -20 }, RightHip = { 50, 0, 0 }, RightKnee = { -60, 0, 0 }, LeftHip = { 40, 0, 0 }, LeftKnee = { -50, 0, 0 } },
	SlapWind = { Root = { 0, 20, 0 }, Waist = { 0, 24, 0 }, RightArm = { 100, 0, 90 }, RightElbow = { 30, 0, 0 }, LeftArm = { 20, 0, -30 }, Neck = { 0, -10, 0 }, RightKnee = { -14, 0, 0 } },
	Slap = { Root = { 0, -26, 0, -0.08, 0.3 }, Waist = { 0, -34, 0 }, RightArm = { 88, -40, -10 }, RightElbow = { 10, 0, 0 }, LeftArm = { 24, 0, -30 }, Neck = { 0, 20, 0 }, LeftHip = { 18, 0, 0 }, LeftKnee = { -18, 0, 0 } },
	FlyKickWind = { Root = { -6, 0, 0, -0.3 }, RightHip = { 60, 0, 0 }, RightKnee = { -100, 0, 0 }, LeftHip = { 40, 0, 0 }, LeftKnee = { -80, 0, 0 }, Waist = { -10, 0, 0 }, RightArm = { 40, 0, 50 }, LeftArm = { 40, 0, -50 } },
	FlyKick = { Root = { 24, 0, 0, 0.3, 0.6 }, RightHip = { 96, 0, 0 }, RightKnee = { 0, 0, 0 }, LeftHip = { -10, 0, 0 }, LeftKnee = { -70, 0, 0 }, Waist = { 16, 0, 0 }, Neck = { -10, 0, 0 }, RightArm = { 20, 0, 70 }, LeftArm = { 20, 0, -70 } },

	-- M1 POLISH: a coil before every strike (twist away, weight back), a
	-- strike that drives the hips through with a forward step, then a
	-- follow-through. Used by every character's M1 combo.
	FlickRCoil = { Root = { 0, 24, 0, -0.14 }, Waist = { 4, 28, 0 }, RightArm = { 72, 0, -40 }, RightElbow = { 88, 0, 0 }, LeftArm = { 40, 0, -26 }, LeftElbow = { 50, 0, 0 }, Neck = { 0, -18, 0 }, LeftHip = { 18, 0, 0 }, LeftKnee = { -20, 0, 0 }, RightKnee = { -16, 0, 0 } },
	FlickRStrike = { Root = { -4, -24, 0, -0.1, 0.55 }, RightArm = { 98, -10, 6 }, RightElbow = { 0, 0, 0 }, LeftArm = { 30, 0, -32 }, LeftElbow = { 62, 0, 0 }, Waist = { -6, -30, 0 }, Neck = { 0, 22, 0 }, RightHip = { 28, 0, 0 }, RightKnee = { -28, 0, 0 }, LeftHip = { -18, 0, 0 }, LeftKnee = { -6, 0, 0 } },
	SlamLeap = { Root = { 14, 18, 0, 0.25, -0.1 }, RightArm = { 178, 0, 14 }, RightElbow = { 36, 0, 0 }, LeftArm = { 120, 0, -30 }, LeftElbow = { 30, 0, 0 }, Waist = { 18, 20, 0 }, Neck = { 12, -8, 0 }, LeftHip = { 40, 0, 0 }, LeftKnee = { -60, 0, 0 }, RightHip = { 20, 0, 0 }, RightKnee = { -30, 0, 0 } },
	JabCoil = { Root = { 0, 16, 0, -0.12 }, Waist = { 0, 18, 0 }, RightArm = { 34, 0, 22 }, RightElbow = { 95, 0, 0 }, LeftArm = { 52, 0, -26 }, LeftElbow = { 70, 0, 0 }, Neck = { 0, -10, 0 }, RightKnee = { -18, 0, 0 }, LeftKnee = { -12, 0, 0 }, LeftHip = { 10, 0, 0 } },
	JabStrike = { Root = { -4, -24, 0, -0.08, 0.6 }, RightArm = { 92, 0, 10 }, RightElbow = { 0, 0, 0 }, Waist = { -4, -34, 0 }, Neck = { 0, 24, 0 }, LeftArm = { 30, 0, -22 }, LeftElbow = { 80, 0, 0 }, LeftHip = { 26, 0, 0 }, LeftKnee = { -22, 0, 0 }, RightHip = { -16, 0, 0 }, RightKnee = { -8, 0, 0 } },
	ClawRStrike = { Root = { -14, -24, 0, -0.2, 0.55 }, Waist = { -20, -28, 0 }, RightArm = { 36, 0, -36 }, RightElbow = { 14, 0, 0 }, LeftArm = { 52, 0, -26 }, LeftElbow = { 48, 0, 0 }, Neck = { 6, 18, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -36, 0, 0 }, LeftHip = { -14, 0, 0 } },
	SlapCoil = { Root = { 0, 26, 0, -0.18 }, Waist = { 0, 30, 0 }, RightArm = { 110, 0, 100 }, RightElbow = { 40, 0, 0 }, LeftArm = { 20, 0, -34 }, Neck = { 0, -14, 0 }, RightKnee = { -22, 0, 0 }, LeftKnee = { -16, 0, 0 } },
	SlapStrike = { Root = { 0, -32, 0, -0.12, 0.45 }, Waist = { 0, -40, 0 }, RightArm = { 86, -48, -14 }, RightElbow = { 6, 0, 0 }, LeftArm = { 24, 0, -34 }, Neck = { 0, 24, 0 }, LeftHip = { 22, 0, 0 }, LeftKnee = { -22, 0, 0 }, RightHip = { -10, 0, 0 } },
	-- BLOCK AND DASH (every character)
	BlockPose = { Root = { 0, 0, 0, -0.2 }, Waist = { -8, 0, 0 }, Neck = { -12, 0, 0 }, RightArm = { 95, 0, -38 }, RightElbow = { 105, 0, 0 }, LeftArm = { 95, 0, 38 }, LeftElbow = { 105, 0, 0 }, RightHip = { 18, 0, 0 }, RightKnee = { -24, 0, 0 }, LeftHip = { -6, 0, 0 }, LeftKnee = { -12, 0, 0 } },
	DashFwd = { Root = { -24, 0, 0, -0.25, 0.2 }, Waist = { -18, 0, 0 }, Neck = { 18, 0, 0 }, RightArm = { -45, 0, 12 }, LeftArm = { -45, 0, -12 }, RightHip = { 55, 0, 0 }, RightKnee = { -70, 0, 0 }, LeftHip = { -25, 0, 0 }, LeftKnee = { -30, 0, 0 } },
	DashBack = { Root = { 18, 0, 0, -0.2, -0.2 }, Waist = { 14, 0, 0 }, Neck = { -6, 0, 0 }, RightArm = { 50, 0, 30 }, LeftArm = { 50, 0, -30 }, RightHip = { -20, 0, 0 }, LeftHip = { 45, 0, 0 }, LeftKnee = { -60, 0, 0 } },
	DashRight = { Root = { 0, 0, -22, -0.3 }, Waist = { 0, 0, -14 }, Neck = { 0, 0, 10 }, RightArm = { 20, 0, 70 }, LeftArm = { 40, 0, -20 }, LeftHip = { 0, 0, -30 }, RightKnee = { -40, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	-- Block family: brace into it, recoil from blocked hits, sag when the guard is low.
	BlockBrace = { Root = { 0, 0, 0, -0.35, 0.1 }, Waist = { -14, 0, 0 }, Neck = { -16, 0, 0 }, RightArm = { 105, 0, -30 }, RightElbow = { 115, 0, 0 }, LeftArm = { 105, 0, 30 }, LeftElbow = { 115, 0, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -40, 0, 0 }, LeftHip = { -10, 0, 0 }, LeftKnee = { -26, 0, 0 } },
	BlockRecoil = { Root = { -8, 0, 0, -0.25, -0.25 }, Waist = { 8, 0, 0 }, Neck = { 6, 0, 0 }, RightArm = { 80, 0, -46 }, RightElbow = { 125, 0, 0 }, LeftArm = { 80, 0, 46 }, LeftElbow = { 125, 0, 0 }, RightHip = { 10, 0, 0 }, RightKnee = { -30, 0, 0 }, LeftHip = { -20, 0, 0 }, LeftKnee = { -16, 0, 0 } },
	BlockWeak = { Root = { 6, 0, 0, -0.4 }, Waist = { 14, 0, 0 }, Neck = { 10, 0, 0 }, RightArm = { 70, 0, -30 }, RightElbow = { 95, 0, 0 }, LeftArm = { 70, 0, 30 }, LeftElbow = { 95, 0, 0 }, RightHip = { 26, 0, 0 }, RightKnee = { -44, 0, 0 }, LeftHip = { 6, 0, 0 }, LeftKnee = { -34, 0, 0 } },
	ParryPose = { Root = { 6, 0, 0, -0.1, -0.15 }, Waist = { 12, 0, 0 }, RightArm = { 140, 0, -20 }, RightElbow = { 30, 0, 0 }, LeftArm = { 60, 0, 30 }, LeftElbow = { 50, 0, 0 }, Neck = { 6, 0, 0 } },
	GuardBroken = { Root = { 14, 0, 0, -0.35, -0.3 }, Waist = { 22, 0, 0 }, Neck = { 28, 0, 0 }, RightArm = { 60, 0, 60 }, LeftArm = { 60, 0, -60 }, RightElbow = { 20, 0, 0 }, LeftElbow = { 20, 0, 0 }, RightKnee = { -30, 0, 0 }, LeftKnee = { -30, 0, 0 } },
	-- MOUNTAIN TIM: a cowboy with a lasso.
	TimStance = { Root = { 0, 6, 0, -0.08 }, Waist = { -4, 6, 0 }, Neck = { 4, -4, 0 }, RightArm = { 18, 0, 22 }, RightElbow = { 40, 0, 0 }, LeftArm = { 10, 0, -18 }, LeftElbow = { 30, 0, 0 }, RightHip = { 6, 0, 0 }, LeftKnee = { -8, 0, 0 } },
	LassoSpin = { Root = { 0, 10, 0, -0.1 }, Waist = { 4, 12, 0 }, RightArm = { 175, 0, 20 }, RightElbow = { 25, 0, 0 }, LeftArm = { 40, 0, -30 }, LeftElbow = { 40, 0, 0 }, Neck = { 12, -6, 0 }, LeftKnee = { -14, 0, 0 } },
	RopeWhipWind = { Root = { 0, 34, 0, -0.08 }, Waist = { 0, 34, 0 }, RightArm = { 120, 0, 70 }, RightElbow = { 20, 0, 0 }, LeftArm = { 30, 0, -30 }, Neck = { 0, -18, 0 } },
	RopeWhip = { Root = { 0, -36, 0, -0.1, 0.35 }, Waist = { 0, -40, 0 }, RightArm = { 90, -40, -30 }, RightElbow = { 0, 0, 0 }, LeftArm = { 24, 0, -36 }, Neck = { 0, 26, 0 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	SplitPose = { Root = { -16, 0, 0, -0.3, 0.3 }, Waist = { -18, 0, 0 }, Neck = { 12, 0, 0 }, RightArm = { 100, 0, 60 }, LeftArm = { 100, 0, -60 }, RightHip = { 30, 0, 0 }, RightKnee = { -40, 0, 0 }, LeftHip = { -20, 0, 0 } },
	-- HOT PANTS: quick and sharp, Cream Starter always in her right hand,
	-- left hand free for jabs (and on her hip at rest).
	HPStance = { Root = { 0, 10, 0, -0.05 }, Waist = { -2, 8, 0 }, Neck = { 0, -6, 0 }, RightArm = { 70, 0, 25 }, RightElbow = { 95, 0, 0 }, LeftArm = { -5, 0, -35 }, LeftElbow = { 70, 0, 0 }, LeftHip = { 10, 0, 0 }, LeftKnee = { -12, 0, 0 }, RightHip = { -4, 0, 0 } },
	CanShakeA = { Root = { 0, 6, 0, -0.06 }, Waist = { 0, 6, 0 }, Neck = { 6, -4, 0 }, RightArm = { 80, 0, 18 }, RightElbow = { 85, 0, 0 }, LeftArm = { -5, 0, -35 }, LeftElbow = { 70, 0, 0 }, LeftKnee = { -10, 0, 0 } },
	CanShakeB = { Root = { 0, 6, 0, -0.08 }, Waist = { 0, 8, 0 }, Neck = { 4, -4, 0 }, RightArm = { 104, 0, 30 }, RightElbow = { 45, 0, 0 }, LeftArm = { -5, 0, -35 }, LeftElbow = { 70, 0, 0 }, LeftKnee = { -10, 0, 0 } },
	SprayAimL = { Root = { 0, 12, 0, -0.1, 0.1 }, Waist = { 0, 22, 0 }, Neck = { 0, -14, 0 }, RightArm = { 92, -22, 10 }, RightElbow = { 4, 0, 0 }, LeftArm = { 50, 0, -30 }, LeftElbow = { 80, 0, 0 }, RightHip = { 16, 0, 0 }, RightKnee = { -18, 0, 0 }, LeftHip = { -8, 0, 0 } },
	SprayAimR = { Root = { 0, -14, 0, -0.1, 0.15 }, Waist = { 0, -26, 0 }, Neck = { 0, 18, 0 }, RightArm = { 92, 20, 0 }, RightElbow = { 4, 0, 0 }, LeftArm = { 50, 0, -30 }, LeftElbow = { 80, 0, 0 }, RightHip = { 16, 0, 0 }, RightKnee = { -18, 0, 0 }, LeftHip = { -8, 0, 0 } },
	SprayThrust = { Root = { -8, -18, 0, -0.12, 0.5 }, Waist = { -10, -22, 0 }, Neck = { 6, 14, 0 }, RightArm = { 100, 0, 0 }, RightElbow = { 0, 0, 0 }, LeftArm = { 20, 0, -40 }, LeftElbow = { 60, 0, 0 }, RightHip = { 28, 0, 0 }, RightKnee = { -30, 0, 0 }, LeftHip = { -14, 0, 0 } },
	HighKickChamber = { Root = { 12, 0, 0, 0.05 }, RightHip = { 95, 0, 0 }, RightKnee = { -100, 0, 0 }, LeftKnee = { -15, 0, 0 }, Waist = { 14, 0, 0 }, RightArm = { 60, 0, 40 }, RightElbow = { 80, 0, 0 }, LeftArm = { 30, 0, -50 } },
	HighKick = { Root = { 26, 0, 0, 0.05, 0.35 }, RightHip = { 125, 0, 0 }, RightKnee = { -4, 0, 0 }, LeftKnee = { -10, 0, 0 }, Waist = { 20, 0, 0 }, Neck = { -12, 0, 0 }, RightArm = { 70, 0, 50 }, RightElbow = { 80, 0, 0 }, LeftArm = { 20, 0, -60 } },
	JumpSpinWind = { Root = { 0, 60, 0, -0.45 }, Waist = { 0, 40, 0 }, Neck = { 0, -30, 0 }, RightArm = { 50, 0, 60 }, RightElbow = { 70, 0, 0 }, LeftArm = { 50, 0, -60 }, LeftHip = { 40, 0, 0 }, LeftKnee = { -70, 0, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -50, 0, 0 } },
	JumpSpinKick = { Root = { 0, -120, 0, 0.6, 0.3 }, Waist = { 0, -35, 0 }, Neck = { 0, 55, 0 }, RightHip = { 85, 0, 35 }, RightKnee = { -5, 0, 0 }, LeftHip = { 50, 0, 0 }, LeftKnee = { -90, 0, 0 }, RightArm = { 60, 0, 70 }, RightElbow = { 70, 0, 0 }, LeftArm = { 40, 0, -80 } },
	SealDash = { Root = { -24, 0, 0, -0.2, 0.9 }, Waist = { -24, 0, 0 }, Neck = { 14, 0, 0 }, RightArm = { 100, 0, 0 }, RightElbow = { 0, 0, 0 }, LeftArm = { -30, 0, -20 }, RightHip = { 50, 0, 0 }, RightKnee = { -60, 0, 0 }, LeftHip = { -30, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	SealPress = { Root = { -10, -10, 0, -0.15, 0.6 }, Waist = { -14, -16, 0 }, Neck = { 4, 10, 0 }, RightArm = { 95, -10, -10 }, RightElbow = { 20, 0, 0 }, LeftArm = { 70, 0, -20 }, LeftElbow = { 60, 0, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -34, 0, 0 } },
	SelfSprayHigh = { Root = { 0, 10, 0, -0.05 }, Waist = { 4, 14, 0 }, Neck = { -10, -20, 0 }, RightArm = { 120, 0, -50 }, RightElbow = { 100, 0, 0 }, LeftArm = { 80, 0, -10 }, LeftElbow = { 90, 0, 0 } },
	SelfSprayLow = { Root = { 6, 6, 0, -0.3 }, Waist = { 26, 8, 0 }, Neck = { -26, 0, 0 }, RightArm = { 40, 0, -30 }, RightElbow = { 60, 0, 0 }, LeftArm = { 30, 0, -20 }, RightHip = { 40, 0, 0 }, RightKnee = { -60, 0, 0 }, LeftHip = { 30, 0, 0 }, LeftKnee = { -50, 0, 0 } },
	MendRelief = { Root = { 4, 0, 0, 0.02 }, Waist = { -8, 0, 0 }, Neck = { 16, 0, 0 }, RightArm = { 40, 0, 30 }, RightElbow = { 80, 0, 0 }, LeftArm = { 10, 0, -20 }, LeftElbow = { 30, 0, 0 } },
	StormRaise = { Root = { 8, 0, 0, 0.25 }, Waist = { 16, 0, 0 }, Neck = { 30, 0, 0 }, RightArm = { 175, 0, 15 }, RightElbow = { 10, 0, 0 }, LeftArm = { 60, 0, -60 }, LeftHip = { 30, 0, 0 }, LeftKnee = { -50, 0, 0 } },
	StormSweepL = { Root = { 0, 30, 0, -0.1, 0.2 }, Waist = { -6, 30, 0 }, Neck = { 0, -20, 0 }, RightArm = { 110, -30, 10 }, RightElbow = { 6, 0, 0 }, LeftArm = { 40, 0, -50 }, RightHip = { 20, 0, 0 }, RightKnee = { -24, 0, 0 } },
	StormSweepR = { Root = { 0, -30, 0, -0.1, 0.2 }, Waist = { -6, -30, 0 }, Neck = { 0, 24, 0 }, RightArm = { 110, 30, 0 }, RightElbow = { 6, 0, 0 }, LeftArm = { 40, 0, -50 }, RightHip = { 20, 0, 0 }, RightKnee = { -24, 0, 0 } },
	-- FUNNY VALENTINE: upright and presidential, a hand at his chest.
	VStance = { Root = { 0, 6, 0, 0.02 }, Waist = { 4, 4, 0 }, Neck = { 8, -6, 0 }, RightArm = { 40, 0, -30 }, RightElbow = { 110, 0, 0 }, LeftArm = { -6, 0, -6 }, LeftElbow = { 10, 0, 0 } },
	VWrap = { Root = { 0, 30, 0, -0.05 }, Waist = { 0, 30, 0 }, Neck = { 0, -20, 0 }, RightArm = { 60, 0, -60 }, RightElbow = { 90, 0, 0 }, LeftArm = { 60, 0, 60 }, LeftElbow = { 90, 0, 0 } },
	VPresent = { Root = { 0, -10, 0, 0 }, Waist = { 0, -10, 0 }, Neck = { 6, 10, 0 }, RightArm = { 70, 0, 50 }, RightElbow = { 10, 0, 0 }, LeftArm = { 30, 0, -10 }, LeftElbow = { 40, 0, 0 } },
	VPledge = { Root = { 6, 0, 0, 0.04 }, Waist = { 8, 0, 0 }, Neck = { 20, 0, 0 }, RightArm = { 50, 0, -40 }, RightElbow = { 120, 0, 0 }, LeftArm = { 150, 0, -20 }, LeftElbow = { 10, 0, 0 } },
	-- DIEGO (AU): cocky, two fingers at his temple, weight on one leg.
	DWStance = { Root = { 0, -10, 0, 0 }, Waist = { 2, -8, 4 }, Neck = { 6, 12, -4 }, RightArm = { 100, 0, 30 }, RightElbow = { 135, 0, 0 }, LeftArm = { -4, 0, -16 }, LeftElbow = { 24, 0, 0 }, RightHip = { 6, 0, 0 }, LeftHip = { -6, 0, 0 }, LeftKnee = { -8, 0, 0 } },
	DWThrowWind = { Root = { 0, 34, 0, -0.04 }, Waist = { -4, 34, 0 }, Neck = { 0, -28, 0 }, RightArm = { 70, 0, -70 }, RightElbow = { 100, 0, 0 }, LeftArm = { 40, 0, -20 }, LeftElbow = { 30, 0, 0 } },
	DWThrow = { Root = { -4, -34, 0, -0.06, 0.3 }, Waist = { -8, -36, 0 }, Neck = { 0, 26, 0 }, RightArm = { 92, 0, 46 }, RightElbow = { 0, 0, 0 }, LeftArm = { 10, 0, -26 }, LeftElbow = { 20, 0, 0 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -18, 0, 0 } },
	DWSpread = { Root = { 4, 0, 0, 0.06 }, Waist = { 10, 0, 0 }, Neck = { 14, 0, 0 }, RightArm = { 50, 0, 80 }, RightElbow = { 20, 0, 0 }, LeftArm = { 50, 0, -80 }, LeftElbow = { 20, 0, 0 } },
	DWAim = { Root = { 0, -20, 0, 0 }, Waist = { 0, -20, 0 }, Neck = { 0, 20, 0 }, RightArm = { 90, 0, 6 }, RightElbow = { 0, 0, 0 }, LeftArm = { 82, 0, -34 }, LeftElbow = { 40, 0, 0 }, RightHip = { 10, 0, 0 }, LeftHip = { -8, 0, 0 } },
	DWFan = { Root = { 0, -20, 0, 0 }, Waist = { 0, -20, 0 }, Neck = { 0, 20, 0 }, RightArm = { 96, 0, 6 }, RightElbow = { 0, 0, 0 }, LeftArm = { 70, 0, -30 }, LeftElbow = { 56, 0, 0 }, RightHip = { 10, 0, 0 }, LeftHip = { -8, 0, 0 } },
	DWTwirl = { Root = { 0, -6, 0, 0 }, Waist = { 0, -6, 0 }, Neck = { 4, 10, 0 }, RightArm = { 40, 0, 50 }, RightElbow = { 70, 0, 0 }, LeftArm = { -4, 0, -16 }, LeftElbow = { 24, 0, 0 } },
	-- JOSUKE (JoJolion): relaxed, hands behind his head; Soft & Wet does the fighting.
	JStance = { Root = { 0, 4, 0, 0 }, Waist = { -4, 4, 0 }, Neck = { -6, -6, 0 }, RightArm = { 160, 0, 40 }, RightElbow = { 130, 0, 0 }, LeftArm = { 160, 0, -40 }, LeftElbow = { 130, 0, 0 }, LeftHip = { 4, 0, 0 } },
	JPoint = { Root = { 0, -16, 0, -0.02 }, Waist = { 0, -16, 0 }, Neck = { 4, 16, 0 }, RightArm = { 90, 0, 4 }, RightElbow = { 0, 0, 0 }, LeftArm = { 160, 0, -40 }, LeftElbow = { 130, 0, 0 } },
	JBlow = { Root = { 0, -10, 0, 0 }, Waist = { 4, -10, 0 }, Neck = { 10, 10, 0 }, RightArm = { 80, 0, 40 }, RightElbow = { 90, 0, 0 }, LeftArm = { 160, 0, -40 }, LeftElbow = { 130, 0, 0 } },
	JFlick = { Root = { -2, -22, 0, -0.04, 0.3 }, Waist = { -4, -24, 0 }, Neck = { 0, 22, 0 }, RightArm = { 95, 0, 10 }, RightElbow = { 0, 0, 0 }, LeftArm = { 160, 0, -40 }, LeftElbow = { 130, 0, 0 }, LeftHip = { 14, 0, 0 } },
	JSpread = { Root = { 2, 0, 0, 0.04 }, Waist = { 6, 0, 0 }, Neck = { 10, 0, 0 }, RightArm = { 60, 0, 70 }, RightElbow = { 30, 0, 0 }, LeftArm = { 60, 0, -70 }, LeftElbow = { 30, 0, 0 } },
	-- GO BEYOND: pointing straight at you, leaning in, left arm hanging loose.
	JGoPoint = { Root = { 6, -12, 0, -0.04 }, Waist = { 8, -14, 0 }, Neck = { 6, 14, -6 }, RightArm = { 88, 0, 6 }, RightElbow = { 4, 0, 0 }, LeftArm = { -6, 0, -10 }, LeftElbow = { 18, 0, 0 }, RightHip = { -6, 0, 0 }, LeftHip = { 14, 0, 0 }, LeftKnee = { -14, 0, 0 } },
	JGoJab = { Root = { 10, -14, 0, -0.08, 0.3 }, Waist = { 12, -16, 0 }, Neck = { 8, 16, -6 }, RightArm = { 94, 0, 4 }, RightElbow = { 0, 0, 0 }, LeftArm = { -10, 0, -12 }, LeftElbow = { 18, 0, 0 }, RightHip = { -10, 0, 0 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -18, 0, 0 } },
	JCharge = { Root = { 6, -20, 0, -0.1 }, Waist = { 10, -20, 0 }, Neck = { 14, 20, 0 }, RightArm = { 70, 0, -10 }, RightElbow = { 100, 0, 0 }, LeftArm = { 60, 0, 10 }, LeftElbow = { 100, 0, 0 }, RightKnee = { -16, 0, 0 }, LeftKnee = { -16, 0, 0 }, RightHip = { 12, 0, 0 }, LeftHip = { 12, 0, 0 } },
	-- TOORU: loose and unbothered, head tilted; Wonder of U does the fighting.
	TStance = { Root = { -2, 8, 0, 0 }, Waist = { -4, 6, 2 }, Neck = { -6, -10, 10 }, RightArm = { -8, 0, 12 }, RightElbow = { 34, 0, 0 }, LeftArm = { -8, 0, -12 }, LeftElbow = { 34, 0, 0 }, RightHip = { 4, 0, 0 }, LeftKnee = { -6, 0, 0 } },
	TFlick = { Root = { 0, -10, 0, 0 }, Waist = { 0, -12, 0 }, Neck = { -4, 12, 6 }, RightArm = { 50, 0, 64 }, RightElbow = { 40, 0, 0 }, LeftArm = { -6, 0, -12 }, LeftElbow = { 30, 0, 0 } },
	TPoint = { Root = { 0, -16, 0, -0.02 }, Waist = { 0, -16, 0 }, Neck = { 4, 16, 4 }, RightArm = { 90, 0, 4 }, RightElbow = { 0, 0, 0 }, LeftArm = { -8, 0, -12 }, LeftElbow = { 30, 0, 0 } },
	TOpen = { Root = { -4, 0, 0, 0.04 }, Waist = { -10, 0, 0 }, Neck = { -26, 0, 8 }, RightArm = { 30, 0, 72 }, RightElbow = { 30, 0, 0 }, LeftArm = { 30, 0, -72 }, LeftElbow = { 30, 0, 0 } },
	-- JODIO: slouched and cocky, one hand behind his head.
	JDStance = { Root = { -3, 6, 0, -0.02 }, Waist = { -6, 6, 0 }, Neck = { 4, -10, 6 }, LeftArm = { 160, 0, -40 }, LeftElbow = { 130, 0, 0 }, RightArm = { -6, 0, 10 }, RightElbow = { 24, 0, 0 }, RightHip = { 4, 0, 0 }, LeftKnee = { -6, 0, 0 } },
	JDPoint = { Root = { 0, -14, 0, -0.02 }, Waist = { 0, -14, 0 }, Neck = { 4, 14, 4 }, RightArm = { 90, 0, 4 }, RightElbow = { 0, 0, 0 }, LeftArm = { 160, 0, -40 }, LeftElbow = { 130, 0, 0 } },
	JDRaise = { Root = { -4, 0, 0, 0.02 }, Waist = { -8, 0, 0 }, Neck = { -20, 0, 0 }, RightArm = { 170, 0, 10 }, RightElbow = { 10, 0, 0 }, LeftArm = { 160, 0, -40 }, LeftElbow = { 130, 0, 0 } },
	JDSurf = { Root = { 18, -30, 0, -0.2 }, Waist = { 14, -20, 0 }, Neck = { -10, 20, 0 }, RightArm = { 40, 0, 70 }, RightElbow = { 20, 0, 0 }, LeftArm = { 40, 0, -70 }, LeftElbow = { 20, 0, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -40, 0, 0 }, LeftHip = { -10, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	-- JOHN ROD's user: hands on hips (like the rod itself); steering it, two fingers at the temple.
	JRStance = { Root = { 0, 0, 0, 0 }, Waist = { -2, 0, 0 }, Neck = { 2, 0, 0 }, RightArm = { -14, 0, 42 }, RightElbow = { 80, 0, 0 }, LeftArm = { -14, 0, -42 }, LeftElbow = { 80, 0, 0 } },
	JRFocus = { Root = { 0, -6, 0, 0 }, Waist = { 2, -6, 0 }, Neck = { 8, 8, -4 }, RightArm = { 100, 0, 30 }, RightElbow = { 135, 0, 0 }, LeftArm = { -6, 0, -14 }, LeftElbow = { 20, 0, 0 } },
	JRFling = { Root = { 0, -18, 0, -0.03 }, Waist = { 0, -18, 0 }, Neck = { 4, 18, 0 }, RightArm = { 92, 0, 10 }, RightElbow = { 0, 0, 0 }, LeftArm = { -14, 0, -42 }, LeftElbow = { 80, 0, 0 } },
	-- RINGO ROADAGAIN: a gunslinger's ease, right hand by the holster; looking at his watch; the shot.
	RGStance = { Root = { 0, 4, 0, 0 }, Waist = { -2, 4, 0 }, Neck = { 4, -6, 0 }, RightArm = { -8, 0, 16 }, RightElbow = { 34, 0, 0 }, LeftArm = { -6, 0, -10 }, LeftElbow = { 22, 0, 0 } },
	RGShoot = { Root = { 0, -20, 0, -0.02 }, Waist = { 0, -16, 0 }, Neck = { 2, 20, 0 }, RightArm = { 90, 0, 6 }, RightElbow = { 0, 0, 0 }, LeftArm = { -10, 0, -12 }, LeftElbow = { 20, 0, 0 } },
	RGWatch = { Root = { 0, 0, 0, 0 }, Waist = { 4, 0, 0 }, Neck = { 22, -12, 0 }, RightArm = { 70, 0, -36 }, RightElbow = { 70, 0, 0 }, LeftArm = { 74, 0, 40 }, LeftElbow = { 80, 0, 0 } },
	-- JOTARO: tall, a hand in his pocket; pointing; a tug at his cap brim; a flick.
	-- DIO: leaning back, one hand at his chest, the other held out; feeding; eyes; knives; ZA WARUDO.
	-- JOSEPH: easy and ready, a finger raised ("your next line is..."); the grab; the lash; the web.
	JOStance = { Root = { 0, 8, 0, 0 }, Waist = { -2, 8, 0 }, Neck = { 4, -8, 0 }, RightArm = { 50, 0, 18 }, RightElbow = { 80, 0, 0 }, LeftArm = { -8, 0, -12 }, LeftElbow = { 26, 0, 0 }, RightHip = { 8, 0, 0 }, LeftHip = { -6, 0, 0 } },
	JOGrabPose = { Root = { -8, -18, 0, -0.06 }, Waist = { -10, -18, 0 }, Neck = { 4, 18, 0 }, RightArm = { 95, 0, 4 }, RightElbow = { 0, 0, 0 }, LeftArm = { 30, 0, -30 }, LeftElbow = { 60, 0, 0 } },
	JOLashPose = { Root = { -4, 24, 0, -0.04 }, Waist = { -6, 28, 0 }, Neck = { 2, -24, 0 }, RightArm = { 85, 0, 60 }, RightElbow = { 10, 0, 0 }, LeftArm = { 20, 0, -30 }, LeftElbow = { 40, 0, 0 } },
	JOWebPose = { Root = { -16, 0, 0, -0.5 }, Waist = { -20, 0, 0 }, Neck = { 14, 0, 0 }, RightArm = { 40, 0, 30 }, RightElbow = { 20, 0, 0 }, LeftArm = { 40, 0, -30 }, LeftElbow = { 20, 0, 0 }, RightHip = { 40, 0, 0 }, RightKnee = { -60, 0, 0 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -40, 0, 0 } },
	DIOStance = { Root = { 8, 18, 0, 0 }, Waist = { 10, 16, 0 }, Neck = { -12, -12, 4 }, RightArm = { 62, 0, -32 }, RightElbow = { 105, 0, 0 }, LeftArm = { 28, 0, -58 }, LeftElbow = { 30, 0, 0 }, RightHip = { 10, 0, 0 }, LeftHip = { -6, 0, 0 }, LeftKnee = { -8, 0, 0 } },
	DIODrainPose = { Root = { -10, -14, 0, -0.06 }, Waist = { -14, -14, 0 }, Neck = { 6, 14, 0 }, RightArm = { 92, 0, 6 }, RightElbow = { 22, 0, 0 }, LeftArm = { 40, 0, -40 }, LeftElbow = { 70, 0, 0 } },
	DIOEyesPose = { Root = { -6, 0, 0, 0 }, Waist = { -8, 0, 0 }, Neck = { 10, 0, 0 }, RightArm = { 140, 0, 18 }, RightElbow = { 120, 0, 0 }, LeftArm = { 140, 0, -18 }, LeftElbow = { 120, 0, 0 } },
	DIOThrowPose = { Root = { 0, -18, 0, 0 }, Waist = { 0, -20, 0 }, Neck = { 0, 18, 0 }, RightArm = { 80, 0, 48 }, RightElbow = { 10, 0, 0 }, LeftArm = { 80, 0, -48 }, LeftElbow = { 10, 0, 0 } },
	DIOWorldPose = { Root = { 10, 0, 0, 0 }, Waist = { 14, 0, 0 }, Neck = { -18, 0, 0 }, RightArm = { 150, 0, 60 }, RightElbow = { 20, 0, 0 }, LeftArm = { 150, 0, -60 }, LeftElbow = { 20, 0, 0 } },
	JTStance = { Root = { 2, 6, 0, 0 }, Waist = { 2, 4, 0 }, Neck = { 4, -6, 0 }, LeftArm = { -12, 0, -10 }, LeftElbow = { 34, 0, 0 }, RightArm = { -4, 0, 8 }, RightElbow = { 12, 0, 0 }, RightHip = { 6, 0, 0 }, LeftHip = { -4, 0, 0 } },
	JTPoint = { Root = { 0, -16, 0, 0 }, Waist = { 0, -12, 0 }, Neck = { 2, 16, 0 }, RightArm = { 90, 0, 4 }, RightElbow = { 0, 0, 0 }, LeftArm = { -12, 0, -10 }, LeftElbow = { 34, 0, 0 } },
	JTCap = { Root = { 0, 0, 0, 0 }, Waist = { 0, 0, 0 }, Neck = { -10, -8, 0 }, RightArm = { 150, 0, 26 }, RightElbow = { 125, 0, 0 }, LeftArm = { -12, 0, -10 }, LeftElbow = { 34, 0, 0 } },
	JTFlick = { Root = { 0, -14, 0, 0 }, Waist = { 0, -10, 0 }, Neck = { 0, 14, 0 }, RightArm = { 84, 0, 10 }, RightElbow = { 24, 0, 0 }, LeftArm = { -12, 0, -10 }, LeftElbow = { 34, 0, 0 } },
	-- RIDING a horse: astride (legs out round its sides, not through it), leaning in, hands on the reins.
	Ride = { Root = { 0, 0, 0, 0 }, Waist = { -10, 0, 0 }, Neck = { 10, 0, 0 }, RightHip = { 25, 0, 50 }, RightKnee = { -40, 0, 0 }, LeftHip = { 25, 0, -50 }, LeftKnee = { -40, 0, 0 }, RightArm = { 50, 0, 8 }, RightElbow = { 55, 0, 0 }, LeftArm = { 50, 0, -8 }, LeftElbow = { 55, 0, 0 } },
	-- AXL RO: slouched and mocking; Civil War does the fighting.
	AxlStance = { Root = { -4, -8, 0, -0.04 }, Waist = { -6, -6, 4 }, Neck = { -10, 12, 8 }, RightArm = { -6, 0, 8 }, RightElbow = { 10, 0, 0 }, LeftArm = { -4, 0, -8 }, LeftElbow = { 14, 0, 0 }, RightHip = { 4, 0, 0 } },
	AxlPoint = { Root = { 0, -14, 0, -0.04 }, Waist = { 0, -14, 0 }, Neck = { 6, 14, 0 }, RightArm = { 88, 0, 6 }, RightElbow = { 0, 0, 0 }, LeftArm = { 0, 0, -10 }, LeftElbow = { 20, 0, 0 } },
	AxlPress = { Root = { 10, -10, 0, -0.2 }, Waist = { 16, -10, 0 }, Neck = { 20, 10, 0 }, RightArm = { 60, 0, 10 }, RightElbow = { 0, 0, 0 }, LeftArm = { 10, 0, -10 }, LeftElbow = { 20, 0, 0 }, RightKnee = { -24, 0, 0 }, LeftKnee = { -24, 0, 0 }, RightHip = { 20, 0, 0 }, LeftHip = { 20, 0, 0 } },
	AxlSummon = { Root = { -6, 0, 0, 0.05 }, Waist = { -8, 0, 0 }, Neck = { -18, 0, 0 }, RightArm = { 120, 0, 50 }, RightElbow = { 10, 0, 0 }, LeftArm = { 120, 0, -50 }, LeftElbow = { 10, 0, 0 } },
	-- BLACKMORE: calm and precise; umbrella in his left hand like a cane.
	BMStance = { Root = { 0, 6, 0, -0.03 }, Waist = { -2, 6, 0 }, Neck = { 2, -4, 0 }, RightArm = { 20, 0, 12 }, RightElbow = { 40, 0, 0 }, LeftArm = { 18, 0, -8 }, LeftElbow = { 20, 0, 0 }, LeftHip = { 4, 0, 0 } },
	BladesWind = { Root = { 0, 22, 0, -0.08 }, Waist = { 0, 24, 0 }, Neck = { 0, -14, 0 }, RightArm = { 70, 0, 80 }, RightElbow = { 30, 0, 0 }, LeftArm = { 30, 0, -20 }, RightKnee = { -14, 0, 0 } },
	BladesSweep = { Root = { 0, -26, 0, -0.1, 0.3 }, Waist = { 0, -32, 0 }, Neck = { 0, 18, 0 }, RightArm = { 92, -50, -10 }, RightElbow = { 0, 0, 0 }, LeftArm = { 40, 0, -30 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -20, 0, 0 } },
	RainStep = { Root = { -20, 0, 0, 0.3, 0.5 }, Waist = { -16, 0, 0 }, Neck = { 14, 0, 0 }, RightArm = { -30, 0, 20 }, LeftArm = { -30, 0, -20 }, RightHip = { 80, 0, 0 }, RightKnee = { -70, 0, 0 }, LeftHip = { -20, 0, 0 }, LeftKnee = { -40, 0, 0 } },
	CagePalm = { Root = { -8, -10, 0, -0.1, 0.4 }, Waist = { -10, -14, 0 }, RightArm = { 95, 0, 10 }, RightElbow = { 0, 0, 0 }, LeftArm = { 30, 0, -20 }, LeftElbow = { 30, 0, 0 }, RightHip = { 24, 0, 0 }, RightKnee = { -26, 0, 0 }, Neck = { 4, 8, 0 } },
	CageClose = { Root = { -6, -8, 0, -0.1, 0.3 }, Waist = { -8, -10, 0 }, RightArm = { 100, 0, 30 }, RightElbow = { 70, 0, 0 }, LeftArm = { 30, 0, -20 }, LeftElbow = { 30, 0, 0 }, RightHip = { 20, 0, 0 }, RightKnee = { -22, 0, 0 } },
	StormCall = { Root = { 8, 0, 0, 0.05 }, Waist = { 14, 0, 0 }, Neck = { 34, 0, 0 }, RightArm = { 165, 0, 30 }, RightElbow = { 20, 0, 0 }, LeftArm = { 150, 0, -10 }, LeftElbow = { 30, 0, 0 } },
	StormHold = { Root = { 0, 0, 0, 0 }, Waist = { 4, 0, 0 }, Neck = { 10, 0, 0 }, RightArm = { 60, 0, 40 }, RightElbow = { 40, 0, 0 }, LeftArm = { 120, 0, -10 }, LeftElbow = { 60, 0, 0 } },
	-- SANDMAN: a light-footed runner; knife-hand chops and spinning kicks.
	SandStance = { Root = { 0, 10, 0, -0.18 }, Waist = { -8, 8, 0 }, Neck = { 8, -6, 0 }, RightArm = { 40, 0, 18 }, RightElbow = { 70, 0, 0 }, LeftArm = { 55, 0, -22 }, LeftElbow = { 60, 0, 0 }, RightHip = { 20, 0, 0 }, RightKnee = { -30, 0, 0 }, LeftHip = { -8, 0, 0 }, LeftKnee = { -14, 0, 0 } },
	ChopCoil = { Root = { 0, 26, 0, -0.14 }, Waist = { 6, 30, 0 }, RightArm = { 160, 0, 40 }, RightElbow = { 60, 0, 0 }, LeftArm = { 60, 0, -20 }, LeftElbow = { 50, 0, 0 }, Neck = { 0, -14, 0 }, LeftHip = { 14, 0, 0 }, LeftKnee = { -16, 0, 0 }, RightKnee = { -12, 0, 0 } },
	ChopStrike = { Root = { -12, -26, 0, -0.16, 0.55 }, Waist = { -16, -30, 0 }, RightArm = { 62, 0, -28 }, RightElbow = { 0, 0, 0 }, LeftArm = { 30, 0, -40 }, LeftElbow = { 60, 0, 0 }, Neck = { 4, 20, 0 }, RightHip = { 30, 0, 0 }, RightKnee = { -34, 0, 0 }, LeftHip = { -16, 0, 0 } },
	SpinKickWind = { Root = { 0, 60, 0, -0.3 }, Waist = { 0, 40, 0 }, Neck = { 0, -30, 0 }, RightArm = { 50, 0, 60 }, LeftArm = { 50, 0, -60 }, LeftHip = { 30, 0, 0 }, LeftKnee = { -50, 0, 0 }, RightKnee = { -30, 0, 0 } },
	SpinKick = { Root = { 0, -110, 0, -0.35, 0.3 }, Waist = { 0, -30, 0 }, Neck = { 0, 50, 0 }, RightHip = { 80, 0, 30 }, RightKnee = { -10, 0, 0 }, LeftKnee = { -60, 0, 0 }, LeftHip = { 40, 0, 0 }, RightArm = { 40, 0, 80 }, LeftArm = { 40, 0, -80 } },
	AxeWind = { Root = { 10, 0, 0, 0.2 }, RightHip = { 130, 0, 0 }, RightKnee = { -10, 0, 0 }, LeftKnee = { -20, 0, 0 }, Waist = { 14, 0, 0 }, Neck = { -6, 0, 0 }, RightArm = { 40, 0, 60 }, LeftArm = { 40, 0, -60 } },
	AxeKick = { Root = { -16, 0, 0, -0.25, 0.6 }, RightHip = { 20, 0, 0 }, RightKnee = { -10, 0, 0 }, LeftHip = { 40, 0, 0 }, LeftKnee = { -60, 0, 0 }, Waist = { -24, 0, 0 }, Neck = { -10, 0, 0 }, RightArm = { 20, 0, 50 }, LeftArm = { 20, 0, -50 } },
	SlashThrow = { Root = { -10, -40, 0, -0.35, 0.4 }, Waist = { -20, -40, 0 }, RightArm = { 40, -60, -20 }, RightElbow = { 0, 0, 0 }, LeftArm = { 20, 0, -50 }, Neck = { 0, 30, 0 }, RightHip = { 50, 0, 0 }, RightKnee = { -60, 0, 0 }, LeftHip = { -20, 0, 0 } },
	TrapPress = { Root = { -20, 0, 0, -1.0, 0.3 }, Waist = { -36, 0, 0 }, Neck = { 20, 0, 0 }, RightArm = { 60, 0, 10 }, RightElbow = { 0, 0, 0 }, LeftArm = { 30, 0, -40 }, RightHip = { 80, 0, 0 }, RightKnee = { -110, 0, 0 }, LeftHip = { 40, 0, 0 }, LeftKnee = { -100, 0, 0 } },
	Sprint = { Root = { -26, 0, 0, -0.2, 0.4 }, Waist = { -20, 0, 0 }, Neck = { 22, 0, 0 }, RightArm = { -50, 0, 10 }, RightElbow = { 80, 0, 0 }, LeftArm = { 80, 0, -10 }, LeftElbow = { 80, 0, 0 }, RightHip = { 70, 0, 0 }, RightKnee = { -90, 0, 0 }, LeftHip = { -30, 0, 0 }, LeftKnee = { -40, 0, 0 } },
	ConductUp = { Root = { 8, 0, 0, 0.1 }, Waist = { 16, 0, 0 }, Neck = { 30, 0, 0 }, RightArm = { 170, 0, 30 }, LeftArm = { 170, 0, -30 }, RightElbow = { 10, 0, 0 }, LeftElbow = { 10, 0, 0 } },
	ConductDown = { Root = { -16, 0, 0, -0.4, 0.3 }, Waist = { -28, 0, 0 }, Neck = { -10, 0, 0 }, RightArm = { 70, 0, 30 }, LeftArm = { 70, 0, -30 }, RightHip = { 40, 0, 0 }, RightKnee = { -50, 0, 0 }, LeftHip = { 30, 0, 0 }, LeftKnee = { -40, 0, 0 } },
}

-- Left-handed version of a pose: swap Right/Left joints and flip Y/Z.
local function mirror(pose)
	local out = {}
	for joint, v in pairs(pose) do
		local target = joint
		if joint:sub(1, 5) == "Right" then
			target = "Left" .. joint:sub(6)
		elseif joint:sub(1, 4) == "Left" then
			target = "Right" .. joint:sub(5)
		end
		out[target] = { v[1], -v[2], -v[3], v[4], v[5] }
	end
	return out
end
TuskAnimation.Mirror = mirror
do
	local P = TuskAnimation.Poses
	P.FlickLWind = mirror(P.FlickRWind)
	P.FlickL = mirror(P.FlickR)
	P.FlickLFollow = mirror(P.FlickRFollow)
	P.JabLeft = mirror(P.Jab)
	-- Older names kept so nothing else breaks.
	P.BarrageA = P.FlickR
	P.BarrageB = P.FlickL
	P.SpinPoke = P.FlickR
	P.ClawWindL = mirror(P.ClawWindR)
	P.ClawL = mirror(P.ClawR)
	P.SlapWindL = mirror(P.SlapWind)
	P.SlapL = mirror(P.Slap)
	P.FlickLCoil = mirror(P.FlickRCoil)
	P.FlickLStrike = mirror(P.FlickRStrike)
	P.ClawLStrike = mirror(P.ClawRStrike)
	P.SlapCoilL = mirror(P.SlapCoil)
	P.SlapStrikeL = mirror(P.SlapStrike)
	P.ChopCoilL = mirror(P.ChopCoil)
	P.ChopStrikeL = mirror(P.ChopStrike)
	P.DashLeft = mirror(P.DashRight)
	P.JabCoilL = mirror(P.JabCoil)
	P.JabStrikeL = mirror(P.JabStrike)
	P.BladesSweepL = mirror(P.BladesSweep)
	P.AxlPointL = mirror(P.AxlPoint)
	P.BladesWindL = mirror(P.BladesWind)
end

--[[
	Action sequences: { Time, Pose, Ease, Shake }. The last key's Time is the
	length; the move then holds briefly (HoldExtra) and settles back.
]]
TuskAnimation.Actions = {
	-- JOHNNY
	M1_1 = { { 0, "Rest" }, { 0.07, "FlickRCoil", "In" }, { 0.12, "FlickRStrike", "Back", 4 }, { 0.17, "FlickRStrike", "Linear" }, { 0.3, "FlickRFollow", "Sine" } },
	M1_2 = { { 0, "FlickRFollow" }, { 0.07, "FlickLCoil", "In" }, { 0.12, "FlickLStrike", "Back", 4 }, { 0.17, "FlickLStrike", "Linear" }, { 0.3, "FlickLFollow", "Sine" } },
	M1_3 = { { 0, "Rest" }, { 0.06, "FlickRCoil", "In" }, { 0.1, "FingerGun", "Snap" }, { 0.14, "FingerGunRecoil", "Snap", 4 }, { 0.2, "FingerGun", "Out" }, { 0.24, "FingerGunRecoil", "Snap", 3 }, { 0.36, "FingerGun", "Sine" } },
	M1_4 = { { 0, "Rest" }, { 0.08, "SlamWindup", "In" }, { 0.16, "SlamLeap", "Out" }, { 0.24, "Slam", "Snap", 8 }, { 0.3, "Slam", "Linear" }, { 0.48, "SlamFollow", "Sine" }, { 0.6, "SlamFollow" } },
	NailShot = { { 0, "Rest" }, { 0.12, "NailRaise", "Out" }, { 0.31, "NailRaise", "Linear" }, { 0.36, "FingerGun", "Snap" }, { 0.42, "FingerGunRecoil", "Snap", 5 }, { 0.7, "FingerGun", "Back" } },
	NailBarrage = {
		{ 0, "Rest" }, { 0.12, "NailRaise", "Out" }, { 0.28, "NailRaise", "Linear" }, { 0.31, "FlickR", "Snap", 2 }, { 0.4, "FlickL", "Snap", 2 }, { 0.49, "FlickR", "Snap", 2 },
		{ 0.58, "FlickL", "Snap", 2 }, { 0.67, "FlickR", "Snap", 2 }, { 0.78, "FingerGunRecoil", "Snap", 4 }, { 0.98, "FingerGun", "Sine" },
	},
	SpinChargeLoop = { { 0, "SpinChargeA" }, { 0.12, "SpinChargeB", "Sine" }, { 0.24, "SpinChargeA", "Sine" } },
	UndergroundDive = { { 0, "Rest" }, { 0.1, "SpreadWind", "In" }, { 0.22, "Dive", "Snap" }, { 0.55, "Dive" } },
	NailDimension = { { 0, "Rest" }, { 0.16, "SpreadWind", "In" }, { 0.28, "Spread", "Back", 3 }, { 0.8, "Spread" } },
	DimensionalStep = { { 0, "Rest" }, { 0.06, "FlickRWind", "In" }, { 0.12, "LungeStep", "Snap", 2 }, { 0.38, "LungeStep", "Sine" } },
	SpatialPursuit = { { 0, "Rest" }, { 0.08, "FlickR", "Snap", 2 }, { 0.22, "SpreadWind", "In" }, { 0.32, "Spread", "Back", 3 }, { 0.6, "Spread" } },
	DimensionalBreak = { { 0, "Rest" }, { 0.25, "AwakenCrouch", "In" }, { 0.72, "AwakenCrouch", "Linear", 2 }, { 0.82, "PushTwo", "Snap", 6 }, { 1.2, "PushTwo", "Sine" } },
	GoldenSpinNail = { { 0, "Rest" }, { 0.12, "NailRaise", "Out" }, { 0.3, "WindSpin", "In" }, { 0.41, "FingerGunRecoil", "Snap", 6 }, { 0.72, "FingerGun", "Back" } },
	GoldenPursuit = { { 0, "Rest" }, { 0.12, "SlamWindup", "In" }, { 0.24, "DashPunch", "Snap", 5 }, { 0.7, "DashPunch", "Sine" } },

	-- GYRO
	G_M1_1 = { { 0, "Rest" }, { 0.06, "JabCoil", "In" }, { 0.11, "JabStrike", "Back", 4 }, { 0.16, "JabStrike", "Linear" }, { 0.28, "JabRecover", "Sine" } },
	G_M1_2 = { { 0, "JabRecover" }, { 0.07, "GHookWind", "In" }, { 0.13, "GHook", "Back", 5 }, { 0.18, "GHook", "Linear" }, { 0.32, "GHookFollow", "Sine" } },
	G_M1_3 = { { 0, "Rest" }, { 0.07, "KickChamber", "In" }, { 0.13, "FrontKick", "Back", 5 }, { 0.18, "FrontKick", "Linear" }, { 0.27, "KickRechamber", "Sine" }, { 0.38, "Rest", "Sine" } },
	G_M1_4 = { { 0, "Rest" }, { 0.1, "PitchSet", "Sine" }, { 0.17, "OverheadWind", "In" }, { 0.25, "OverheadSmash", "Snap", 8 }, { 0.31, "OverheadSmash", "Linear" }, { 0.48, "SmashFollow", "Sine" }, { 0.6, "SmashFollow" } },
	GyroThrow = { { 0, "Rest" }, { 0.06, "PitchSet", "Sine" }, { 0.16, "PitchBack", "In" }, { 0.24, "PitchRelease", "Snap", 5 }, { 0.42, "PitchFollow", "Sine" }, { 0.58, "PitchFollow" } },
	GyroBowl = { { 0, "Rest" }, { 0.14, "BowlWind", "In" }, { 0.27, "BowlRelease", "Snap", 4 }, { 0.45, "BowlFollow", "Sine" }, { 0.6, "BowlFollow" } },
	GyroPalm = { { 0, "Rest" }, { 0.12, "PalmWind", "In" }, { 0.2, "PalmPress", "Snap", 4 }, { 0.32, "PalmPush", "Linear", 7 }, { 0.6, "PalmPush", "Sine", 3 } },
	GyroBreakerCharge = {
		{ 0, "Rest" }, { 0.3, "BreakerWindA", "Sine" }, { 0.55, "BreakerWindB", "Sine", 1 }, { 0.8, "BreakerWindA", "Sine" },
		{ 1.05, "BreakerWindB", "Sine", 2 }, { 1.3, "BreakerWindA", "Sine" }, { 1.55, "BreakerWindB", "Sine", 3 }, { 1.75, "PitchBack", "In" },
	},
	SpinningNailRelease = { { 0, "ChargeNail" }, { 0.06, "PointRecoil", "Snap", 6 }, { 0.4, "Point", "Back" } },

	-- DIEGO
	D_M1_1 = { { 0, "Rest" }, { 0.07, "ClawWindR", "In" }, { 0.12, "ClawRStrike", "Back", 4 }, { 0.17, "ClawRStrike", "Linear" }, { 0.3, "ClawR", "Sine" } },
	D_M1_2 = { { 0, "ClawR" }, { 0.07, "ClawWindL", "In" }, { 0.12, "ClawLStrike", "Back", 4 }, { 0.17, "ClawLStrike", "Linear" }, { 0.3, "ClawL", "Sine" } },
	D_M1_3 = { { 0, "Rest" }, { 0.08, "TailWhipWind", "In" }, { 0.17, "TailWhip", "Snap", 5 }, { 0.22, "TailWhip", "Linear" }, { 0.36, "TailWhip", "Sine" } },
	D_M1_4 = { { 0, "Rest" }, { 0.13, "BiteWind", "In" }, { 0.21, "Bite", "Snap", 7 }, { 0.27, "Bite", "Linear" }, { 0.48, "Bite", "Sine" } },
	DiegoPounce = { { 0, "Rest" }, { 0.16, "PounceCrouch", "In" }, { 0.24, "PounceLeap", "Snap", 3 }, { 0.5, "PounceLeap", "Sine" } },
	DiegoLand = { { 0, "PounceLeap" }, { 0.06, "PounceLand", "Snap", 6 }, { 0.35, "PounceLand", "Sine" } },
	DiegoBite = { { 0, "Rest" }, { 0.14, "BiteWind", "In" }, { 0.22, "Bite", "Snap", 6 }, { 0.5, "Bite", "Sine" } },
	DiegoTransform = { { 0, "Rest" }, { 0.18, "TransformHunch", "In" }, { 0.35, "TransformHunch", "Linear", 4 }, { 0.5, "Roar", "Back", 6 } },
	DiegoRoar = { { 0, "Rest" }, { 0.2, "BiteWind", "In" }, { 0.35, "Roar", "Back", 6 }, { 0.9, "Roar", "Linear", 4 }, { 1.2, "Roar", "Sine", 2 } },

	-- PORK PIE HAT KID
	P_M1_1 = { { 0, "Rest" }, { 0.06, "SlapCoil", "In" }, { 0.11, "SlapStrike", "Back", 4 }, { 0.16, "SlapStrike", "Linear" }, { 0.28, "Slap", "Sine" } },
	P_M1_2 = { { 0, "Slap" }, { 0.06, "SlapCoilL", "In" }, { 0.11, "SlapStrikeL", "Back", 4 }, { 0.16, "SlapStrikeL", "Linear" }, { 0.28, "SlapL", "Sine" } },
	P_M1_3 = { { 0, "Rest" }, { 0.08, "SpitWind", "In" }, { 0.14, "Spit", "Snap", 5 }, { 0.19, "Spit", "Linear" }, { 0.32, "Spit", "Sine" } },
	P_M1_4 = { { 0, "Rest" }, { 0.12, "FlyKickWind", "In" }, { 0.2, "FlyKick", "Snap", 7 }, { 0.26, "FlyKick", "Linear" }, { 0.45, "FlyKick", "Sine" }, { 0.58, "FlyKick" } },
	-- BLOCK AND DASH
	DashF = { { 0, "Rest" }, { 0.05, "DashFwd", "Snap", 2 }, { 0.22, "DashFwd", "Linear" }, { 0.32, "Rest", "Sine" } },
	DashB = { { 0, "Rest" }, { 0.05, "DashBack", "Snap", 2 }, { 0.22, "DashBack", "Linear" }, { 0.32, "Rest", "Sine" } },
	DashR = { { 0, "Rest" }, { 0.05, "DashRight", "Snap", 2 }, { 0.22, "DashRight", "Linear" }, { 0.32, "Rest", "Sine" } },
	DashL = { { 0, "Rest" }, { 0.05, "DashLeft", "Snap", 2 }, { 0.22, "DashLeft", "Linear" }, { 0.32, "Rest", "Sine" } },
	BlockRaise = { { 0, "Rest" }, { 0.07, "BlockBrace", "Snap", 3 }, { 0.18, "BlockPose", "Back", 2 } },
	BlockHit = { { 0, "BlockPose" }, { 0.05, "BlockRecoil", "Snap", 5 }, { 0.22, "BlockPose", "Back", 2 } },
	BlockHitWeak = { { 0, "BlockWeak" }, { 0.05, "BlockRecoil", "Snap", 7 }, { 0.3, "BlockWeak", "Back", 2 } },
	Parry = { { 0, "BlockPose" }, { 0.06, "ParryPose", "Snap", 4 }, { 0.3, "ParryPose", "Sine" } },
	GuardBreak = { { 0, "BlockPose" }, { 0.08, "GuardBroken", "Snap", 6 }, { 0.8, "GuardBroken", "Linear" }, { 1.0, "Rest", "Sine" } },

	-- MOUNTAIN TIM
	T_M1_1 = { { 0, "Rest" }, { 0.06, "JabCoil", "In" }, { 0.11, "JabStrike", "Back", 4 }, { 0.16, "JabStrike", "Linear" }, { 0.28, "TimStance", "Sine" } },
	T_M1_2 = { { 0, "JabStrike" }, { 0.06, "JabCoilL", "In" }, { 0.11, "JabStrikeL", "Back", 4 }, { 0.16, "JabStrikeL", "Linear" }, { 0.28, "TimStance", "Sine" } },
	T_M1_3 = { { 0, "Rest" }, { 0.08, "RopeWhipWind", "In" }, { 0.15, "RopeWhip", "Snap", 5 }, { 0.2, "RopeWhip", "Linear" }, { 0.34, "TimStance", "Sine" } },
	T_M1_4 = { { 0, "Rest" }, { 0.12, "OverheadWind", "In" }, { 0.21, "OverheadSmash", "Snap", 8 }, { 0.27, "OverheadSmash", "Linear" }, { 0.46, "SmashFollow", "Sine" }, { 0.58, "TimStance", "Sine" } },
	TimLassoThrow = { { 0, "Rest" }, { 0.08, "LassoSpin", "Out" }, { 0.26, "LassoSpin", "Linear", 1 }, { 0.34, "PitchRelease", "Snap", 4 }, { 0.5, "PitchFollow", "Sine" } },
	TimReel = { { 0, "PitchFollow" }, { 0.1, "ReelBack", "Snap", 3 }, { 0.5, "ReelBack", "Linear", 2 }, { 0.65, "TimStance", "Sine" } },
	TimSplit = { { 0, "Rest" }, { 0.1, "SplitPose", "Snap", 3 }, { 0.5, "SplitPose", "Linear" }, { 0.65, "TimStance", "Sine" } },
	TimPunch = { { 0, "Rest" }, { 0.1, "JabCoil", "In" }, { 0.18, "JabStrike", "Snap", 4 }, { 0.6, "JabStrike", "Linear", 2 }, { 0.75, "TimStance", "Sine" } },
	TimRoundup = { { 0, "Rest" }, { 0.15, "LassoSpin", "Out" }, { 0.85, "LassoSpin", "Linear", 2 }, { 0.95, "Spread", "Snap", 5 }, { 1.6, "ReelBack", "Snap", 3 }, { 2.2, "ReelBack", "Linear", 2 }, { 2.35, "HoistSlam", "Snap", 8 }, { 2.7, "HoistSlam", "Sine" } },

	-- HOT PANTS
	H_M1_1 = { { 0, "HPStance" }, { 0.06, "JabCoilL", "In" }, { 0.11, "JabStrikeL", "Back", 4 }, { 0.16, "JabStrikeL", "Linear" }, { 0.28, "HPStance", "Sine" } },
	H_M1_2 = { { 0, "HPStance" }, { 0.07, "HighKickChamber", "In" }, { 0.13, "HighKick", "Back", 5 }, { 0.19, "HighKick", "Linear" }, { 0.32, "HPStance", "Sine" } },
	H_M1_3 = { { 0, "HPStance" }, { 0.05, "CanShakeB", "In" }, { 0.11, "SprayThrust", "Snap", 4 }, { 0.17, "SprayThrust", "Linear" }, { 0.3, "HPStance", "Sine" } },
	H_M1_4 = { { 0, "HPStance" }, { 0.1, "JumpSpinWind", "In" }, { 0.19, "JumpSpinKick", "Snap", 7 }, { 0.25, "JumpSpinKick", "Linear" }, { 0.42, "HPStance", "Sine" } },
	HPSpray = { { 0, "HPStance" }, { 0.05, "CanShakeA", "Snap" }, { 0.09, "CanShakeB", "Snap", 1 }, { 0.13, "CanShakeA", "Snap", 1 }, { 0.2, "SprayAimL", "Snap", 2 }, { 0.47, "SprayAimR", "Sine", 2 }, { 0.72, "SprayAimL", "Sine", 2 }, { 0.88, "HPStance", "Sine" } },
	HPSeal = { { 0, "HPStance" }, { 0.1, "CanShakeB", "In" }, { 0.18, "SealDash", "Snap", 4 }, { 0.28, "SealPress", "Snap", 5 }, { 0.5, "SealPress", "Linear", 2 }, { 0.66, "HPStance", "Sine" } },
	HPMend = { { 0, "HPStance" }, { 0.12, "SelfSprayHigh", "Out" }, { 0.55, "SelfSprayLow", "Sine", 1 }, { 0.92, "SelfSprayHigh", "Sine", 1 }, { 1.12, "MendRelief", "Back" }, { 1.35, "HPStance", "Sine" } },
	HPStorm = { { 0, "HPStance" }, { 0.05, "CanShakeA", "Snap" }, { 0.1, "CanShakeB", "Snap", 1 }, { 0.15, "CanShakeA", "Snap", 1 }, { 0.2, "CanShakeB", "Snap", 2 }, { 0.38, "StormRaise", "Back", 4 }, { 0.6, "StormSweepL", "Snap", 3 }, { 0.9, "StormSweepR", "Sine", 2 }, { 1.1, "SprayThrust", "Snap", 5 }, { 1.4, "SprayThrust", "Linear", 2 }, { 1.6, "HPStance", "Sine" } },

	-- FUNNY VALENTINE
	V_M1_1 = { { 0, "VStance" }, { 0.07, "JabStrike", "Back", 4 }, { 0.15, "JabStrike", "Linear" }, { 0.3, "VStance", "Sine" } },
	V_M1_2 = { { 0, "VStance" }, { 0.07, "JabStrikeL", "Back", 4 }, { 0.15, "JabStrikeL", "Linear" }, { 0.3, "VStance", "Sine" } },
	V_M1_3 = { { 0, "VStance" }, { 0.07, "KickChamber", "In" }, { 0.13, "FrontKick", "Back", 5 }, { 0.18, "FrontKick", "Linear" }, { 0.32, "VStance", "Sine" } },
	V_M1_4 = { { 0, "VStance" }, { 0.12, "VWrap", "In" }, { 0.2, "AxlPoint", "Snap", 7 }, { 0.3, "AxlPoint", "Linear" }, { 0.46, "VStance", "Sine" } },
	VHop = { { 0, "VStance" }, { 0.12, "VWrap", "Out" }, { 0.32, "VWrap", "Linear" }, { 0.5, "VStance", "Sine" } },
	VCall = { { 0, "VStance" }, { 0.15, "VPresent", "Out" }, { 0.4, "VPresent", "Linear" }, { 0.6, "VStance", "Sine" } },
	VMenger = { { 0, "VStance" }, { 0.14, "AxlPoint", "Out" }, { 0.36, "AxlPoint", "Linear" }, { 0.55, "VStance", "Sine" } },
	VLoveTrain = { { 0, "VStance" }, { 0.3, "VPledge", "Back", 3 }, { 0.9, "VPledge", "Linear", 3 }, { 1.2, "VStance", "Sine" } },

	-- DIEGO (AU)
	J_M1_1 = { { 0, "JStance" }, { 0.07, "JPoint", "Back", 3 }, { 0.3, "JStance", "Sine" } },
	J_M1_2 = { { 0, "JStance" }, { 0.07, "JPoint", "Back", 3 }, { 0.3, "JStance", "Sine" } },
	J_M1_3 = { { 0, "JStance" }, { 0.07, "KickChamber", "In" }, { 0.13, "FrontKick", "Back", 5 }, { 0.18, "FrontKick", "Linear" }, { 0.32, "JStance", "Sine" } },
	J_M1_4 = { { 0, "JStance" }, { 0.1, "JFlick", "Snap", 6 }, { 0.25, "JFlick", "Linear" }, { 0.42, "JStance", "Sine" } },
	JBubble = { { 0, "JStance" }, { 0.12, "JBlow", "Out" }, { 0.2, "JFlick", "Snap", 4 }, { 0.4, "JFlick", "Linear" }, { 0.6, "JStance", "Sine" } },
	JMines = { { 0, "JStance" }, { 0.15, "JSpread", "Back", 3 }, { 0.5, "JSpread", "Linear" }, { 0.75, "JStance", "Sine" } },
	JGoBeyond = { { 0, "JStance" }, { 0.22, "JGoPoint", "Back", 3 }, { 0.95, "JGoPoint", "Linear", 1 }, { 1.03, "JGoJab", "Snap", 6 }, { 1.5, "JGoJab", "Linear" }, { 1.8, "JStance", "Sine" } },
	T_M1_1 = { { 0, "TStance" }, { 0.08, "TFlick", "Back", 3 }, { 0.3, "TStance", "Sine" } },
	T_M1_2 = { { 0, "TStance" }, { 0.08, "TPoint", "Back", 3 }, { 0.3, "TStance", "Sine" } },
	T_M1_3 = { { 0, "TStance" }, { 0.08, "TFlick", "Back", 3 }, { 0.3, "TStance", "Sine" } },
	T_M1_4 = { { 0, "TStance" }, { 0.1, "TPoint", "Snap", 6 }, { 0.3, "TPoint", "Linear" }, { 0.46, "TStance", "Sine" } },
	TCast = { { 0, "TStance" }, { 0.12, "TFlick", "Back", 3 }, { 0.5, "TFlick", "Linear" }, { 0.75, "TStance", "Sine" } },
	TCurse = { { 0, "TStance" }, { 0.15, "TPoint", "Back", 3 }, { 0.6, "TPoint", "Linear" }, { 0.85, "TStance", "Sine" } },
	TUlt = { { 0, "TStance" }, { 0.3, "TOpen", "Out" }, { 1.2, "TOpen", "Linear", 1 }, { 1.6, "TStance", "Sine" } },
	JD_M1_1 = { { 0, "JDStance" }, { 0.07, "JDPoint", "Back", 3 }, { 0.3, "JDStance", "Sine" } },
	JD_M1_2 = { { 0, "JDStance" }, { 0.07, "JDPoint", "Back", 3 }, { 0.3, "JDStance", "Sine" } },
	JD_M1_3 = { { 0, "JDStance" }, { 0.07, "KickChamber", "In" }, { 0.13, "FrontKick", "Back", 5 }, { 0.18, "FrontKick", "Linear" }, { 0.32, "JDStance", "Sine" } },
	JD_M1_4 = { { 0, "JDStance" }, { 0.1, "JDPoint", "Snap", 6 }, { 0.3, "JDPoint", "Linear" }, { 0.46, "JDStance", "Sine" } },
	JDCall = { { 0, "JDStance" }, { 0.15, "JDRaise", "Back", 3 }, { 0.6, "JDRaise", "Linear" }, { 0.85, "JDStance", "Sine" } },
	JDShoot = { { 0, "JDStance" }, { 0.12, "JDPoint", "Back", 3 }, { 0.6, "JDPoint", "Linear" }, { 0.8, "JDStance", "Sine" } },
	JDJet = { { 0, "JDStance" }, { 0.1, "JDSurf", "Out" }, { 0.42, "JDSurf", "Linear" }, { 0.65, "JDStance", "Sine" } },
	JDTorrent = { { 0, "JDStance" }, { 0.25, "JDRaise", "Out" }, { 1.0, "JDRaise", "Linear", 1 }, { 1.3, "JDStance", "Sine" } },
	JRFlick = { { 0, "JRStance" }, { 0.08, "JRFling", "Back", 3 }, { 0.3, "JRStance", "Sine" } },
	JRCage = { { 0, "JRStance" }, { 0.2, "JRFling", "Back", 3 }, { 0.8, "JRFling", "Linear" }, { 1.0, "JRStance", "Sine" } },
	RG_M1_1 = { { 0, "RGStance" }, { 0.07, "JabStrike", "Back", 4 }, { 0.15, "JabStrike", "Linear" }, { 0.3, "RGStance", "Sine" } },
	RG_M1_2 = { { 0, "RGStance" }, { 0.07, "JabStrikeL", "Back", 4 }, { 0.15, "JabStrikeL", "Linear" }, { 0.3, "RGStance", "Sine" } },
	RG_M1_3 = { { 0, "RGStance" }, { 0.07, "JabStrike", "Back", 4 }, { 0.15, "JabStrike", "Linear" }, { 0.3, "RGStance", "Sine" } },
	RG_M1_4 = { { 0, "RGStance" }, { 0.08, "RGShoot", "Back", 3 }, { 0.3, "RGShoot", "Linear" }, { 0.5, "RGStance", "Sine" } },
	RGDraw = { { 0, "RGStance" }, { 0.12, "RGShoot", "Back", 3 }, { 0.45, "RGShoot", "Linear" }, { 0.65, "RGStance", "Sine" } },
	RGWatchTurn = { { 0, "RGStance" }, { 0.15, "RGWatch", "Out" }, { 0.55, "RGWatch", "Linear" }, { 0.8, "RGStance", "Sine" } },
	RGCounter = { { 0, "RGStance" }, { 0.1, "RGWatch", "Out" }, { 1.0, "RGWatch", "Linear" }, { 1.2, "RGStance", "Sine" } },
	JO_M1_1 = { { 0, "JOStance" }, { 0.07, "JabStrike", "Back", 4 }, { 0.15, "JabStrike", "Linear" }, { 0.3, "JOStance", "Sine" } },
	JO_M1_2 = { { 0, "JOStance" }, { 0.07, "JabStrikeL", "Back", 4 }, { 0.15, "JabStrikeL", "Linear" }, { 0.3, "JOStance", "Sine" } },
	JO_M1_3 = { { 0, "JOStance" }, { 0.07, "JabStrike", "Back", 4 }, { 0.15, "JabStrike", "Linear" }, { 0.3, "JOStance", "Sine" } },
	JO_M1_4 = { { 0, "JOStance" }, { 0.08, "JOGrabPose", "Back", 5 }, { 0.32, "JOGrabPose", "Linear" }, { 0.52, "JOStance", "Sine" } },
	JOGrab = { { 0, "JOStance" }, { 0.12, "JOGrabPose", "Back", 3 }, { 0.6, "JOGrabPose", "Linear" }, { 0.8, "JOStance", "Sine" } },
	JOLash = { { 0, "JOStance" }, { 0.18, "JOLashPose", "Out" }, { 0.4, "JOLashPose", "Linear", 2 }, { 0.65, "JOStance", "Sine" } },
	JOWeb = { { 0, "JOStance" }, { 0.3, "JOWebPose", "Out" }, { 1.0, "JOWebPose", "Linear", 3 }, { 1.3, "JOStance", "Sine" } },
	DIO_M1_1 = { { 0, "DIOStance" }, { 0.07, "JabStrike", "Back", 4 }, { 0.15, "JabStrike", "Linear" }, { 0.3, "DIOStance", "Sine" } },
	DIO_M1_2 = { { 0, "DIOStance" }, { 0.07, "JabStrikeL", "Back", 4 }, { 0.15, "JabStrikeL", "Linear" }, { 0.3, "DIOStance", "Sine" } },
	DIO_M1_3 = { { 0, "DIOStance" }, { 0.07, "JabStrike", "Back", 4 }, { 0.15, "JabStrike", "Linear" }, { 0.3, "DIOStance", "Sine" } },
	DIO_M1_4 = { { 0, "DIOStance" }, { 0.08, "DIOThrowPose", "Back", 4 }, { 0.3, "DIOThrowPose", "Linear" }, { 0.5, "DIOStance", "Sine" } },
	DIODrain = { { 0, "DIOStance" }, { 0.15, "DIODrainPose", "Back", 3 }, { 1.5, "DIODrainPose", "Linear" }, { 1.8, "DIOStance", "Sine" } },
	DIOEyes = { { 0, "DIOStance" }, { 0.2, "DIOEyesPose", "Out" }, { 0.6, "DIOEyesPose", "Linear", 2 }, { 0.85, "DIOStance", "Sine" } },
	DIOThrow = { { 0, "DIOStance" }, { 0.1, "DIOThrowPose", "Back", 3 }, { 0.4, "DIOThrowPose", "Linear" }, { 0.6, "DIOStance", "Sine" } },
	DIOZaWarudo = { { 0, "DIOStance" }, { 0.25, "DIOWorldPose", "Out" }, { 1.1, "DIOWorldPose", "Linear" }, { 1.4, "DIOStance", "Sine" } },
	JT_M1_1 = { { 0, "JTStance" }, { 0.07, "JabStrike", "Back", 4 }, { 0.15, "JabStrike", "Linear" }, { 0.3, "JTStance", "Sine" } },
	JT_M1_2 = { { 0, "JTStance" }, { 0.07, "JabStrikeL", "Back", 4 }, { 0.15, "JabStrikeL", "Linear" }, { 0.3, "JTStance", "Sine" } },
	JT_M1_3 = { { 0, "JTStance" }, { 0.07, "JabStrike", "Back", 4 }, { 0.15, "JabStrike", "Linear" }, { 0.3, "JTStance", "Sine" } },
	JT_M1_4 = { { 0, "JTStance" }, { 0.08, "JTPoint", "Back", 4 }, { 0.3, "JTPoint", "Linear" }, { 0.5, "JTStance", "Sine" } },
	JTRush = { { 0, "JTStance" }, { 0.12, "JTPoint", "Out" }, { 1.5, "JTPoint", "Linear" }, { 1.75, "JTStance", "Sine" } },
	JTPoint = { { 0, "JTStance" }, { 0.12, "JTPoint", "Back", 3 }, { 0.5, "JTPoint", "Linear" }, { 0.7, "JTStance", "Sine" } },
	JTCap = { { 0, "JTStance" }, { 0.2, "JTCap", "Out" }, { 1.1, "JTCap", "Linear" }, { 1.4, "JTStance", "Sine" } },
	JTFlick = { { 0, "JTStance" }, { 0.1, "JTFlick", "Back", 3 }, { 0.35, "JTFlick", "Linear" }, { 0.55, "JTStance", "Sine" } },
	DW_M1_1 = { { 0, "DWStance" }, { 0.07, "JabStrike", "Back", 4 }, { 0.15, "JabStrike", "Linear" }, { 0.3, "DWStance", "Sine" } },
	DW_M1_2 = { { 0, "DWStance" }, { 0.07, "JabStrikeL", "Back", 4 }, { 0.15, "JabStrikeL", "Linear" }, { 0.3, "DWStance", "Sine" } },
	DW_M1_3 = { { 0, "DWStance" }, { 0.07, "KickChamber", "In" }, { 0.13, "FrontKick", "Back", 5 }, { 0.18, "FrontKick", "Linear" }, { 0.32, "DWStance", "Sine" } },
	DW_M1_4 = { { 0, "DWStance" }, { 0.12, "DWThrowWind", "In" }, { 0.2, "AxlPoint", "Snap", 7 }, { 0.3, "AxlPoint", "Linear" }, { 0.46, "DWStance", "Sine" } },
	DWGrab = { { 0, "DWStance" }, { 0.12, "AxlPoint", "Back", 3 }, { 0.7, "AxlPoint", "Linear" }, { 0.8, "DWThrow", "Snap", 5 }, { 1.05, "DWStance", "Sine" } },
	DWBarrage = { { 0, "DWStance" }, { 0.12, "AxlPoint", "Out" }, { 1.7, "AxlPoint", "Linear", 1 }, { 1.9, "DWStance", "Sine" } },
	DWKnife = { { 0, "DWStance" }, { 0.14, "DWThrowWind", "In" }, { 0.22, "DWThrow", "Snap", 4 }, { 0.45, "DWStance", "Sine" } },
	DWTimeStop = { { 0, "DWStance" }, { 0.35, "DWSpread", "Back", 3 }, { 0.95, "DWSpread", "Linear", 2 }, { 1.25, "DWStance", "Sine" } },

	DWRevolver = { { 0, "DWStance" }, { 0.22, "DWAim", "Back", 2 }, { 0.38, "DWFan", "Snap", 3 }, { 0.45, "DWAim", "Out" }, { 0.52, "DWFan", "Snap", 3 }, { 0.59, "DWAim", "Out" }, { 0.66, "DWFan", "Snap", 3 }, { 0.73, "DWAim", "Out" }, { 0.80, "DWFan", "Snap", 3 }, { 0.87, "DWAim", "Out" }, { 0.94, "DWFan", "Snap", 3 }, { 1.01, "DWAim", "Out" }, { 1.08, "DWFan", "Snap", 3 }, { 1.15, "DWAim", "Out" }, { 1.32, "DWTwirl", "Out" }, { 1.62, "DWTwirl", "Linear" }, { 1.85, "DWStance", "Sine" } },

	-- AXL RO
	A_M1_1 = { { 0, "AxlStance" }, { 0.07, "JabStrike", "Back", 4 }, { 0.16, "JabStrike", "Linear" }, { 0.3, "AxlStance", "Sine" } },
	A_M1_2 = { { 0, "AxlStance" }, { 0.07, "JabStrikeL", "Back", 4 }, { 0.16, "JabStrikeL", "Linear" }, { 0.3, "AxlStance", "Sine" } },
	A_M1_3 = { { 0, "AxlStance" }, { 0.07, "KickChamber", "In" }, { 0.13, "FrontKick", "Back", 5 }, { 0.18, "FrontKick", "Linear" }, { 0.32, "AxlStance", "Sine" } },
	A_M1_4 = { { 0, "AxlStance" }, { 0.12, "AxlSummon", "In" }, { 0.2, "AxlPoint", "Snap", 7 }, { 0.3, "AxlPoint", "Linear" }, { 0.46, "AxlStance", "Sine" } },
	AxlSpecter = { { 0, "AxlStance" }, { 0.12, "AxlPoint", "Out" }, { 0.35, "AxlPoint", "Linear" }, { 0.55, "AxlStance", "Sine" } },
	AxlJunk = { { 0, "AxlStance" }, { 0.15, "AxlSummon", "Out" }, { 0.3, "AxlSummon", "Linear" }, { 0.36, "AxlPointL", "Snap", 5 }, { 0.6, "AxlStance", "Sine" } },
	AxlMembrane = { { 0, "AxlStance" }, { 0.14, "AxlPoint", "Out" }, { 0.3, "AxlPress", "Snap", 5 }, { 0.5, "AxlPress", "Sine" }, { 0.7, "AxlStance", "Sine" } },
	AxlCivilWar = { { 0, "AxlStance" }, { 0.4, "AxlSummon", "Back", 3 }, { 1.0, "AxlSummon", "Linear", 3 }, { 1.3, "AxlStance", "Sine" } },

	-- BLACKMORE
	B_M1_1 = { { 0, "Rest" }, { 0.07, "BladesWind", "In" }, { 0.12, "BladesSweep", "Back", 4 }, { 0.17, "BladesSweep", "Linear" }, { 0.3, "BMStance", "Sine" } },
	B_M1_2 = { { 0, "BladesSweep" }, { 0.07, "BladesWindL", "In" }, { 0.12, "BladesSweepL", "Back", 4 }, { 0.17, "BladesSweepL", "Linear" }, { 0.3, "BMStance", "Sine" } },
	B_M1_3 = { { 0, "Rest" }, { 0.07, "KickChamber", "In" }, { 0.13, "FrontKick", "Back", 5 }, { 0.18, "FrontKick", "Linear" }, { 0.32, "BMStance", "Sine" } },
	B_M1_4 = { { 0, "Rest" }, { 0.12, "CagePalm", "In" }, { 0.2, "BladesSweep", "Snap", 7 }, { 0.26, "BladesSweep", "Linear" }, { 0.44, "BMStance", "Sine" } },
	BMBlades = { { 0, "Rest" }, { 0.12, "BladesWind", "In" }, { 0.3, "BladesWind", "Linear", 1 }, { 0.36, "BladesSweep", "Snap", 5 }, { 0.55, "BMStance", "Sine" } },
	BMStep = { { 0, "Rest" }, { 0.06, "RainStep", "Snap", 2 }, { 0.3, "RainStep", "Linear" }, { 0.45, "BMStance", "Sine" } },
	BMCage = { { 0, "Rest" }, { 0.12, "CagePalm", "Out" }, { 0.24, "CageClose", "Snap", 5 }, { 0.45, "CageClose", "Sine" }, { 0.6, "BMStance", "Sine" } },
	BMStorm = { { 0, "Rest" }, { 0.3, "StormCall", "Back", 3 }, { 0.8, "StormCall", "Linear", 3 }, { 1.1, "StormHold", "Sine" }, { 1.4, "StormHold" } },

	-- SANDMAN
	S_M1_1 = { { 0, "Rest" }, { 0.07, "ChopCoil", "In" }, { 0.12, "ChopStrike", "Back", 4 }, { 0.17, "ChopStrike", "Linear" }, { 0.3, "SandStance", "Sine" } },
	S_M1_2 = { { 0, "ChopStrike" }, { 0.07, "ChopCoilL", "In" }, { 0.12, "ChopStrikeL", "Back", 4 }, { 0.17, "ChopStrikeL", "Linear" }, { 0.3, "SandStance", "Sine" } },
	S_M1_3 = { { 0, "Rest" }, { 0.08, "SpinKickWind", "In" }, { 0.16, "SpinKick", "Snap", 5 }, { 0.21, "SpinKick", "Linear" }, { 0.36, "SandStance", "Sine" } },
	S_M1_4 = { { 0, "Rest" }, { 0.13, "AxeWind", "In" }, { 0.21, "AxeKick", "Snap", 8 }, { 0.27, "AxeKick", "Linear" }, { 0.46, "AxeKick", "Sine" }, { 0.58, "SandStance", "Sine" } },
	SandSlash = { { 0, "Rest" }, { 0.12, "ChopCoil", "In" }, { 0.2, "SlashThrow", "Snap", 5 }, { 0.42, "SlashThrow", "Sine" } },
	SandTrap = { { 0, "Rest" }, { 0.14, "TrapPress", "In" }, { 0.25, "TrapPress", "Snap", 5 }, { 0.45, "TrapPress", "Sine" } },
	SandRun = { { 0, "Rest" }, { 0.1, "Sprint", "Snap", 2 }, { 0.4, "Sprint", "Linear" }, { 0.55, "SandStance", "Sine" } },
	SandSymphony = { { 0, "Rest" }, { 0.3, "ConductUp", "Back", 3 }, { 0.9, "ConductUp", "Linear", 2 }, { 1.05, "ConductDown", "Snap", 6 }, { 1.6, "ConductUp", "Back", 2 }, { 2.2, "ConductDown", "Snap", 8 }, { 2.5, "ConductDown", "Sine" } },

	PPHookSpit = { { 0, "Rest" }, { 0.18, "SpitWind", "In" }, { 0.26, "Spit", "Snap", 5 }, { 0.42, "Spit", "Sine" } },
	PPReel = { { 0, "Spit" }, { 0.1, "ReelBack", "Snap", 3 }, { 0.3, "ReelBack", "Linear", 2 }, { 0.55, "ReelBack", "Sine" } },
	PPBaitToss = { { 0, "Rest" }, { 0.14, "BowlWind", "In" }, { 0.26, "BowlRelease", "Snap", 3 }, { 0.42, "BowlFollow", "Sine" } },
	PPHoist = { { 0, "Rest" }, { 0.2, "SpitWind", "In" }, { 0.3, "Spit", "Snap", 4 }, { 0.45, "HoistUp", "Back", 5 }, { 0.8, "HoistUp", "Linear", 2 }, { 0.92, "HoistSlam", "Snap", 7 }, { 1.2, "HoistSlam", "Sine" } },
	PPWinch = {
		{ 0, "Rest" }, { 0.3, "Spread", "Back", 3 }, { 0.9, "Spread", "Linear", 2 }, { 1.05, "Spit", "Snap", 5 },
		{ 1.3, "ReelBack", "Snap", 3 }, { 1.7, "HoistUp", "Sine", 2 }, { 2.1, "ReelBack", "Sine", 2 }, { 2.35, "HoistSlam", "Snap", 8 }, { 2.7, "HoistSlam", "Sine" },
	},
	Awakening = {
		{ 0, "Rest" }, { 0.35, "AwakenCrouch", "In" }, { 0.7, "AwakenCrouch", "Linear", 1 }, { 1.0, "AwakenCrouch", "Linear", 2 },
		{ 1.2, "AwakenCrouch", "Linear", 3 }, { 1.45, "AwakenRise", "Back", 6 }, { 2.2, "AwakenRise", "Sine" },
	},
	Emerge = { { 0, "Sneak" }, { 0.12, "Emerge", "Back", 3 }, { 0.5, "Emerge", "Sine" } },
	Throw = { { 0, "Rest" }, { 0.14, "SlamWindup", "In" }, { 0.24, "Point", "Snap", 3 }, { 0.5, "Point", "Sine" } },
}

local states = setmetatable({}, { __mode = "k" }) -- character -> { Hold, Action, Idle, Tracks }
local warned = setmetatable({}, { __mode = "k" })
-- Extra time each move holds its last pose before settling (makes moves read clearly).
TuskAnimation.HoldExtra = 0.1
TuskAnimation.SettleTime = 0.3
local OVERSHOOT = 1.14 -- "Back" eases swing this far past the pose, then settle
local SHAKE_TIME = 0.16
local SHAKE_JOINTS = { "Root", "Waist", "RightArm", "LeftArm", "Neck" }

local EASES = {
	Linear = function(a)
		return a
	end,
	Out = function(a)
		return 1 - (1 - a) ^ 3
	end,
	Snap = function(a)
		return 1 - (1 - a) ^ 5
	end,
	In = function(a)
		return a * a * a
	end,
	Sine = function(a)
		return 0.5 - 0.5 * math.cos(a * math.pi)
	end,
}

local function rigOf(character)
	if character:FindFirstChild("UpperTorso") then
		return "R15"
	elseif character:FindFirstChild("Torso") then
		return "R6"
	end
	return nil
end

local function motorsOf(character)
	local rig = rigOf(character)
	if not rig then
		return {}
	end
	local motors = {}
	local found = 0
	for name, path in pairs(JOINTS[rig]) do
		local holder = character:FindFirstChild(path[1])
		local motor = holder and holder:FindFirstChild(path[2])
		if JointCache.isJoint(motor) then
			motors[name] = motor
			found = found + 1
		end
	end
	if found == 0 and not warned[character] then
		warned[character] = true
		warn("[Spin] No animatable joints found on " .. character.Name .. " (" .. rig .. "). Move animations can't play on this character.")
	end
	return motors
end

-- Riders sit up on a horse: their whole body is lifted on the root joint by
-- this many studs, under every pose (TuskAnimation.setLift).
local lifts = setmetatable({}, { __mode = "k" }) -- [character] = studs

local function liftOf(motor)
	if motor.Name == "Root" or motor.Name == "RootJoint" then
		local character = motor.Parent and motor.Parent.Parent
		return character and lifts[character] or 0
	end
	return 0
end

-- C0 for a pose value (rotation applied in the parent part's space, about the joint).
local function poseC0(motor, value, scale)
	local base = JointCache.original(motor)
	local lift = liftOf(motor)
	if lift ~= 0 then
		base = base + Vector3.new(0, lift, 0)
	end
	if not value then
		return base
	end
	scale = scale or 1
	local rotation = CFrame.Angles(math.rad(value[1] * scale), math.rad(value[2] * scale), math.rad(value[3] * scale))
	local position = base.Position + Vector3.new(0, (value[4] or 0) * scale, -(value[5] or 0) * scale)
	return CFrame.new(position) * rotation * (base - base.Position)
end

local function resolvePose(pose)
	if typeof(pose) == "string" then
		return TuskAnimation.Poses[pose] or {}
	end
	return pose or {}
end

local function getState(character)
	local s = states[character]
	if not s then
		s = { Hold = nil, Action = nil, Tracks = {}, SettleUntil = 0 }
		states[character] = s
	end
	return s
end

local function animator(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

-- Real uploaded animation, if one is configured for this name.
local function playTrack(character, name, looped)
	local id = TuskConfig.AnimationIds[name]
	if not id or id == "" then
		return nil
	end
	local a = animator(character)
	if not a then
		return nil
	end
	local s = getState(character)
	local track = s.Tracks[name]
	if not track then
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, loaded = pcall(function()
			return a:LoadAnimation(anim)
		end)
		if not ok then
			return nil
		end
		track = loaded
		track.Priority = Enum.AnimationPriority.Action
		s.Tracks[name] = track
	end
	track.Looped = looped == true
	track:Play(0.1)
	return track
end

-- Smoothly settle every joint toward a target pose.
local function blendTo(character, pose, duration)
	local s = getState(character)
	local motors = motorsOf(character)
	local from, to = {}, {}
	for name, motor in pairs(motors) do
		from[name] = JointCache.read(motor)
		to[name] = poseC0(motor, pose[name])
	end
	s.SettleUntil = os.clock() + duration
	-- Only the newest blend runs (an older one finishing later would undo it).
	VFXLib.cancel(s.Blend)
	s.Blend = VFXLib.animate(duration, function(a)
		local e = EASES.Sine(a)
		for name, motor in pairs(motors) do
			if motor.Parent then
				JointCache.write(motor, from[name]:Lerp(to[name], e))
			end
		end
	end)
	return s.Blend
end

-- Breathing idle layered on a Hold pose (chest rise, head and arm sway).
local function startIdle(character, s)
	VFXLib.cancel(s.Idle)
	local motors = motorsOf(character)
	local seed = math.random() * 10
	s.Idle = VFXLib.animate(1e6, function()
		if s.Action or not s.Hold or os.clock() < s.SettleUntil or s.Sprinting then
			return
		end
		local pose = resolvePose(s.Hold)
		local t = os.clock() + seed
		local breath = math.sin(t * 2.2)
		local sway = math.sin(t * 1.1)
		local extra = {
			Waist = CFrame.Angles(math.rad(breath * 1.6), math.rad(sway * 1.2), 0),
			Neck = CFrame.Angles(math.rad(-breath * 1.2), math.rad(math.sin(t * 0.7) * 3), 0),
			RightArm = CFrame.Angles(math.rad(breath * 2.2), 0, math.rad(sway * 1.5)),
			LeftArm = CFrame.Angles(math.rad(breath * 2.2), 0, math.rad(-sway * 1.5)),
		}
		for name, offset in pairs(extra) do
			local motor = motors[name]
			if motor and motor.Parent then
				JointCache.write(motor, poseC0(motor, pose[name]) * offset)
			end
		end
	end)
end

local function stopIdle(s)
	VFXLib.cancel(s.Idle)
	s.Idle = nil
end

function TuskAnimation.play(character, name)
	if not character then
		return
	end
	if playTrack(character, name, false) then
		return
	end
	local frames = TuskAnimation.Actions[name]
	if not frames then
		return
	end
	local s = getState(character)
	VFXLib.cancel(s.Action)
	local motors = motorsOf(character)
	local holdPose = resolvePose(s.Hold)
	local length = frames[#frames][1]
	-- Precompute C0 targets per keyframe; frame 1 starts from the current pose.
	local keys = {}
	for i, frame in ipairs(frames) do
		local pose = resolvePose(frame[2])
		local ease = frame[3] or "Out"
		local c0s, over = {}, nil
		if ease == "Back" then
			over = {}
		end
		for jointName, motor in pairs(motors) do
			local value = pose[jointName] or holdPose[jointName]
			if i == 1 then
				c0s[jointName] = JointCache.read(motor)
			else
				c0s[jointName] = poseC0(motor, value)
				if over then
					over[jointName] = poseC0(motor, value, OVERSHOOT)
				end
			end
		end
		keys[i] = { Time = frame[1], C0 = c0s, Over = over, Ease = ease, Shake = frame[4] }
	end
	local total = length + TuskAnimation.HoldExtra
	local job
	job = VFXLib.animate(total, function(a)
		local t = math.min(a * total, length)
		local k = 1
		while k < #keys and keys[k + 1].Time < t do
			k = k + 1
		end
		local current = keys[k]
		local nextKey = keys[math.min(k + 1, #keys)]
		local span = math.max(nextKey.Time - current.Time, 1e-3)
		local local01 = math.clamp((t - current.Time) / span, 0, 1)
		-- Impact shake from the most recent key that has one.
		local shake = 0
		for i = 1, #keys do
			local key = keys[i]
			if key.Shake and key.Time <= t and t < key.Time + SHAKE_TIME then
				shake = math.max(shake, key.Shake * (1 - (t - key.Time) / SHAKE_TIME))
			end
		end
		for jointName, motor in pairs(motors) do
			if motor.Parent then
				local fromC0, toC0 = current.C0[jointName], nextKey.C0[jointName]
				local c0
				if nextKey.Over and nextKey ~= current then
					-- Overshoot: snap past the pose, then settle back onto it.
					if local01 < 0.6 then
						c0 = fromC0:Lerp(nextKey.Over[jointName], EASES.Snap(local01 / 0.6))
					else
						c0 = nextKey.Over[jointName]:Lerp(toC0, EASES.Sine((local01 - 0.6) / 0.4))
					end
				else
					local ease = EASES[nextKey.Ease] or EASES.Out
					c0 = fromC0:Lerp(toC0, ease(local01))
				end
				if shake > 0 and table.find(SHAKE_JOINTS, jointName) then
					local r = math.rad(shake)
					c0 = c0 * CFrame.Angles((math.random() - 0.5) * r, (math.random() - 0.5) * r, (math.random() - 0.5) * r)
				end
				JointCache.write(motor, c0)
			end
		end
	end, function()
		if s.Action == job then
			s.Action = nil
			blendTo(character, resolvePose(s.Hold), TuskAnimation.SettleTime)
		end
	end)
	s.Action = job
end

-- Sustained pose (e.g. "Sneak", "ChargeNail"). stopHold() releases it.
function TuskAnimation.hold(character, poseName)
	if not character then
		return
	end
	local s = getState(character)
	if s.Hold == poseName then
		return
	end
	s.Hold = poseName
	local track = playTrack(character, poseName, true)
	if track then
		return
	end
	if not s.Action then
		blendTo(character, resolvePose(poseName), 0.25)
	end
	startIdle(character, s)
end

---------------------------------------------------------------------------
-- SPRINT: a full-speed running cycle drawn on the joints every frame (no
-- uploads needed), for characters who run like athletes (Sandman). It
-- takes over from the walk/run animation whenever they're moving fast on
-- their own legs: a hard forward lean, high knees, heels kicking up
-- behind, arms pumping from hip to chin with bent elbows, a head that
-- stays level, and a bounce each stride. The stride rate follows how fast
-- they're actually going. Moves (M1s, abilities) still play on top: the
-- cycle steps aside while one runs. Blends in and out smoothly.
---------------------------------------------------------------------------
local sprinters = setmetatable({}, { __mode = "k" }) -- [character] = { Enabled, K, Phase, Job }

local function mixValue(a, b, k)
	a = a or {}
	b = b or {}
	local out = {}
	for i = 1, 5 do
		out[i] = (a[i] or 0) * (1 - k) + (b[i] or 0) * k
	end
	return out
end

-- The sprint pose at stride phase p (radians); `lean` 0..1 = how hard.
local function sprintPose(p, lean, airborne)
	local sp = math.sin(p)
	local kick = 0.5 - 0.5 * math.sin(p + 0.6) -- 1 when that heel is up behind
	local kickL = 0.5 - 0.5 * math.sin(p + math.pi + 0.6)
	local bounce = math.abs(math.cos(p))
	if airborne then
		-- In the air: knees tucked, arms held mid-swing.
		return {
			Root = { -10 * lean, 0, 0, 0 },
			Waist = { -8 * lean, 0, 0 },
			Neck = { 12 * lean, 0, 0 },
			RightArm = { -30, 0, 10 }, RightElbow = { 90, 0, 0 },
			LeftArm = { 40, 0, -10 }, LeftElbow = { 90, 0, 0 },
			RightHip = { 55, 0, 0 }, RightKnee = { -70, 0, 0 },
			LeftHip = { -15, 0, 0 }, LeftKnee = { -90, 0, 0 },
		}
	end
	return {
		Root = { -16 * lean, sp * 6, 0, -0.12 + bounce * 0.28 },
		Waist = { -10 * lean, sp * 9, 0 },
		Neck = { 22 * lean, -sp * 7, 0 }, -- eyes up the track
		-- Arms pump opposite the legs, elbows ~90 degrees, a little across the body.
		RightArm = { -sp * 72 + 8, 0, 10 - sp * 4 },
		LeftArm = { sp * 72 + 8, 0, -10 - sp * 4 },
		RightElbow = { 95 + math.max(0, sp) * 25, 0, 0 },
		LeftElbow = { 95 + math.max(0, -sp) * 25, 0, 0 },
		-- High knees in front, heels kicking right up behind.
		RightHip = { sp * 68 + 14, 0, 0 },
		LeftHip = { -sp * 68 + 14, 0, 0 },
		RightKnee = { -(18 + 105 * kick), 0, 0 },
		LeftKnee = { -(18 + 105 * kickL), 0, 0 },
	}
end
TuskAnimation.sprintPose = sprintPose

function TuskAnimation.sprint(character, enabled)
	if not character then
		return
	end
	local sp = sprinters[character]
	if not sp then
		if not enabled then
			return
		end
		sp = { Enabled = true, K = 0, Phase = 0 }
		sprinters[character] = sp
	end
	sp.Enabled = enabled
	if sp.Job then
		return
	end
	local s = getState(character)
	local motors = motorsOf(character)
	local last = os.clock()
	sp.Job = VFXLib.animate(1e6, function()
		local now = os.clock()
		local dt = math.min(now - last, 0.1)
		last = now
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not character.Parent or not root or not humanoid then
			VFXLib.cancel(sp.Job)
			sp.Job = nil
			sprinters[character] = nil
			s.Sprinting = nil
			return
		end
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local riding = character:FindFirstChild("RaceHorse") ~= nil or humanoid.Sit
		local airborne = humanoid.FloorMaterial == Enum.Material.Air
		local want = (sp.Enabled and not riding and speed > 14 and humanoid.Health > 0) and 1 or 0
		sp.K = sp.K + (want - sp.K) * math.min(1, dt * (want > sp.K and 7 or 9))
		-- Stride rate follows the real speed.
		local rate = math.clamp(speed / 13, 1.1, 3.6)
		if not airborne then
			sp.Phase = (sp.Phase + dt * rate * math.pi * 2) % (math.pi * 2)
		end
		if sp.K < 0.01 and want == 0 then
			if s.Sprinting then
				s.Sprinting = nil
				if not s.Action then
					blendTo(character, resolvePose(s.Hold), 0.15)
				end
			end
			if not sp.Enabled then
				VFXLib.cancel(sp.Job)
				sp.Job = nil
				sprinters[character] = nil
			end
			return
		end
		s.Sprinting = true
		if s.Action then
			return -- a move is playing: it gets the joints
		end
		local lean = math.clamp((speed - 14) / 30, 0.4, 1)
		local pose = sprintPose(sp.Phase, lean, airborne)
		local hold = resolvePose(s.Hold)
		for name, motor in pairs(motors) do
			if motor.Parent then
				JointCache.write(motor, poseC0(motor, mixValue(hold[name], pose[name], sp.K)))
			end
		end
		-- Mute the default walk/run animation underneath.
		if sp.K > 0.5 then
			local a = animator(character)
			if a then
				for _, track in ipairs(a:GetPlayingAnimationTracks()) do
					if track.Priority == Enum.AnimationPriority.Core or track.Priority == Enum.AnimationPriority.Idle or track.Priority == Enum.AnimationPriority.Movement then
						track:AdjustWeight(0.001, 0)
					end
				end
			end
		end
	end)
end

-- Lift a character's whole body (e.g. onto a horse's saddle); nil / 0 to stop.
function TuskAnimation.setLift(character, studs)
	if not character then
		return
	end
	studs = (studs and studs ~= 0) and studs or nil
	if lifts[character] == studs then
		return
	end
	lifts[character] = studs
	local s = getState(character)
	if not s.Action then
		blendTo(character, resolvePose(s.Hold), 0.15)
	end
end

-- The pose currently held on a character (so a temporary hold can put it back).
function TuskAnimation.currentHold(character)
	return character and getState(character).Hold
end

function TuskAnimation.stopHold(character, poseName)
	if not character then
		return
	end
	local s = getState(character)
	if poseName and s.Hold ~= poseName then
		return
	end
	local track = s.Hold and s.Tracks[s.Hold]
	if track then
		track:Stop(0.15)
	end
	s.Hold = nil
	stopIdle(s)
	if not s.Action then
		blendTo(character, {}, TuskAnimation.SettleTime)
	end
end

-- Swap the local character's idle/walk/run animations while Tusk is equipped
-- (only if ids are configured). Restores the originals on unequip.
local savedAnimate = {}
function TuskAnimation.applyLocomotion(character, enabled)
	local animate = character and character:FindFirstChild("Animate")
	if not animate then
		return
	end
	local map = { idle = "Idle", walk = "Walk", run = "Run" }
	for folderName, key in pairs(map) do
		local id = TuskConfig.AnimationIds[key]
		local folder = animate:FindFirstChild(folderName)
		if folder and id and id ~= "" then
			for _, anim in ipairs(folder:GetChildren()) do
				if anim:IsA("Animation") then
					if enabled then
						savedAnimate[anim] = savedAnimate[anim] or anim.AnimationId
						anim.AnimationId = id
					elseif savedAnimate[anim] then
						anim.AnimationId = savedAnimate[anim]
					end
				end
			end
		end
	end
end

Players.LocalPlayer.CharacterRemoving:Connect(function(character)
	local s = states[character]
	if s then
		stopIdle(s)
	end
	states[character] = nil
end)

return TuskAnimation
end

-- ======================================================================
-- MODULE: TuskController
-- ======================================================================
__modules["TuskController"] = function()
--[[
	TuskController  (StarterPlayerScripts.SpinClient.TuskController)
	("TuskAbilityController" in the design doc)

	Local input for Tusk, and the router for Tusk visual events.
	  PC:         M1 = left click (hold to keep attacking), 1 / 2 / 3 = abilities,
	              G = ultimate, C = sneak, T = Act menu
	  Controller: RB, X / Y / B, D-pad up, LB, D-pad down
	  Mobile:     HUD buttons (slots, ultimate bar, sneak chip) + on-screen M1

	Sends only intents + aim direction. The server validates everything.
	Inputs are bound only while the local character has Tusk equipped, so
	other movesets keep their keys.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local TuskAnimation = __require("TuskAnimation")
local TuskSneakController = __require("TuskSneakController")
local TuskActCommon = __require("TuskActCommon")
local TuskUI = __require("TuskUI")

local TuskController = {}

local player = Players.LocalPlayer
local Request
local actVFX = {}
local bound = false
local m1Held = false
local nextM1 = 0

local function aim()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return nil
	end
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch or string.find(last.Name, "Gamepad") then
		return camera.CFrame.LookVector
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, VFXLib.Folder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local target = hit and hit.Position or ray.Origin + ray.Direction * 600
	local origin = (root.CFrame * CFrame.new(0.9, 0.55, -1.5)).Position
	-- Steering a remote Stand (John Rod): aim from it, not from you.
	local remote = character:GetAttribute("StandRemotePos")
	if typeof(remote) == "Vector3" then
		origin = remote
	end
	local dir = target - origin
	return dir.Magnitude > 1 and dir.Unit or root.CFrame.LookVector
end

local function currentAct()
	local character = player.Character
	return character and character:GetAttribute("TuskAct")
end

function TuskController.ability(slot, began)
	local act = currentAct()
	local info = act and Registry.get(act)
	if not info then
		return
	end
	local kind = info.AbilityKinds[slot]
	if began then
		Request:FireServer("Ability", slot, "Press", aim())
	elseif kind == "Hold" then
		Request:FireServer("Ability", slot, "Release", aim())
	end
end

function TuskController.ultimate()
	Request:FireServer("Ultimate", aim())
end

function TuskController.toggleSneak()
	local character = player.Character
	local sneaking = character and character:GetAttribute("TuskSneaking") == true
	Request:FireServer("Sneak", not sneaking)
end

function TuskController.select(act)
	Request:FireServer("Select", act)
end

local function m1()
	Request:FireServer("M1", aim())
end

local ACTIONS = {
	TuskM1 = function(state)
		if state == Enum.UserInputState.Begin then
			m1Held = true
			nextM1 = 0
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			m1Held = false
		end
	end,
	TuskAbility1 = function(state)
		TuskController.ability(1, state == Enum.UserInputState.Begin)
	end,
	TuskAbility2 = function(state)
		TuskController.ability(2, state == Enum.UserInputState.Begin)
	end,
	TuskAbility3 = function(state)
		TuskController.ability(3, state == Enum.UserInputState.Begin)
	end,
	TuskUltimate = function(state)
		if state == Enum.UserInputState.Begin then
			TuskController.ultimate()
		end
	end,
	TuskSneak = function(state)
		if state == Enum.UserInputState.Begin then
			TuskController.toggleSneak()
		end
	end,
}

local KEYMAP = {
	TuskM1 = "M1",
	TuskAbility1 = "Ability1",
	TuskAbility2 = "Ability2",
	TuskAbility3 = "Ability3",
	TuskUltimate = "Ultimate",
	TuskSneak = "Sneak",
}

local function bindAll()
	if bound then
		return
	end
	bound = true
	for actionName, handler in pairs(ACTIONS) do
		local keys = TuskConfig.Keys[KEYMAP[actionName]]
		ContextActionService:BindAction(actionName, function(_, state)
			if state == Enum.UserInputState.End and actionName ~= "TuskM1" and not string.find(actionName, "Ability") then
				return Enum.ContextActionResult.Sink
			end
			handler(state)
			return Enum.ContextActionResult.Sink
		end, actionName == "TuskM1", keys.Keyboard, keys.Gamepad)
	end
	ContextActionService:SetTitle("TuskM1", "M1")
	ContextActionService:SetPosition("TuskM1", UDim2.new(1, -95, 1, -95))
	TuskAnimation.applyLocomotion(player.Character, true)
end

local function unbindAll()
	if not bound then
		return
	end
	bound = false
	m1Held = false
	for actionName in pairs(ACTIONS) do
		ContextActionService:UnbindAction(actionName)
	end
	TuskAnimation.applyLocomotion(player.Character, false)
end

function TuskController.init()
	Request = Net.get("TuskRequest")
	local FX = Net.get("TuskFX")

	for act, info in pairs(Registry.Acts) do
		local name = info.ClientModule or ("Act" .. act)
		if __hasModule(name) then
			-- One broken character script must not take the whole UI down.
			local ok, result = pcall(__require, name)
			if ok then
				actVFX[act] = result
			else
				warn("[Spin] Couldn't load " .. name .. " (character " .. tostring(info.Character) .. "): " .. tostring(result))
			end
		end
	end

	TuskUI.init({
		Ability = TuskController.ability,
		Ultimate = TuskController.ultimate,
		Sneak = TuskController.toggleSneak,
		Select = TuskController.select,
	})

	FX.OnClientEvent:Connect(function(name, data)
		if typeof(data) ~= "table" then
			return
		end
		if name == "TuskState" then
			TuskUI.onState(data)
		elseif name == "SneakAttack" then
			TuskSneakController.handle(name, data)
		elseif name == "Evolve" then
			TuskActCommon.evolve(data)
			TuskUI.onEvolve(data)
		else
			local m = actVFX[data.Act]
			if m then
				m.handle(name, data)
			end
		end
	end)

	-- Act menu key works whether or not Tusk is equipped.
	ContextActionService:BindAction("TuskActMenu", function(_, state)
		if state == Enum.UserInputState.Begin and TuskConfig.Progression.ShowSelectionMenu then
			TuskUI.toggleMenu()
		end
		return Enum.ContextActionResult.Sink
	end, false, TuskConfig.Keys.ActMenu.Keyboard, TuskConfig.Keys.ActMenu.Gamepad)

	RunService.RenderStepped:Connect(function(dt)
		local act = currentAct()
		if act and not bound then
			bindAll()
		elseif not act and bound then
			unbindAll()
		end
		if m1Held and bound and os.clock() >= nextM1 then
			nextM1 = os.clock() + 0.12
			m1()
		end
		for _, m in pairs(actVFX) do
			if m.step then
				m.step(dt)
			end
		end
		TuskUI.step(act)
	end)

	player.CharacterAdded:Connect(function()
		bound = false
		m1Held = false
	end)
end

return TuskController
end

-- ======================================================================
-- MODULE: TuskProjectiles
-- ======================================================================
__modules["TuskProjectiles"] = function()
--[[
	TuskProjectiles  (StarterPlayerScripts.SpinClient.TuskProjectiles)

	Draws every server "TuskNail" projectile (ProjectileService events on
	SpinFX). Position follows the server's straight-line path using server
	time, so all clients agree. Looks depend on Visual.Act / Visual.Style:

	  Style "M1"       short quick nail
	  Style "Shot"     cyan helix, thin blue trail, launch streak
	  Style "Barrage"  smaller nails, muzzle flash per nail
	  Style "Spinning" bigger with charge, 1-3 rotation rings, golden-blue at full
	  Awakened         extra ring, brighter trails
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")

local TuskProjectiles = {}
local colors = TuskConfig.Colors
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

local active = {}

local function styleFor(visual)
	local style = visual.Style or "Shot"
	local charge = visual.Charge or 0
	local awakened = visual.Awakened == true
	local s = {
		Scale = 1,
		Rings = 0,
		RingColor = colors.Cyan,
		Color = colors.Blue,
		Color2 = colors.Cyan,
		TrailColor = colors.Blue,
		Helix = 2,
		SpinSpeed = 32,
		ImpactSize = 0.8,
		ImpactLayers = 1,
		Afterimages = false,
		-- Johnny's nail look: cyan glowing nail, blue Spin whirls always spinning.
		Glow = true,
		GlowColor = colors.Cyan,
		Whirls = 2,
		WhirlColor = colors.Cyan,
		WhirlColor2 = colors.Blue,
	}
	if style == "M1" then
		s.Scale = 0.75
		s.Helix = 1
		s.Whirls = 1
		s.ImpactSize = 0.6
	elseif style == "Barrage" then
		s.Scale = 0.8
		s.Helix = 1
		s.Whirls = 1
		s.ImpactSize = 0.6
	elseif style == "Spinning" then
		s.Scale = 1 + charge * 0.7
		s.Rings = 1 + math.floor(charge * 2 + 0.01)
		s.SpinSpeed = 40 + charge * 30
		s.ImpactSize = 1 + charge * 1.2
		s.ImpactLayers = 2 + math.floor(charge + 0.01)
		s.Afterimages = charge > 0.5
		s.Whirls = 2 + math.floor(charge + 0.01)
		if charge >= 1 then
			-- Full charge: golden-blue identity.
			s.WhirlColor = colors.GoldLight
			s.WhirlColor2 = colors.Cyan
			s.RingColor = colors.Gold
			s.Color2 = colors.Gold
			s.TrailColor = colors.GoldLight
		end
	end
	local act = visual.Act or 1
	if style == "Wormhole" then
		-- Act 2 (golden ratio): gold and cyan helix, one golden ring.
		s.Color = colors.Gold
		s.Color2 = Color3.fromRGB(80, 210, 255)
		s.Rings = 1
		s.RingColor = colors.GoldLight
		s.TrailColor = colors.GoldLight
		s.ImpactSize = 1
	elseif style == "Portal" then
		-- Nails fired through portals (Acts 2 and 3).
		s.Scale = 0.9
		s.Color = act == 3 and Color3.fromRGB(30, 20, 120) or colors.Gold
		s.Color2 = act == 3 and Color3.fromRGB(120, 160, 255) or colors.Cyan
		s.ImpactSize = 0.8
	elseif style == "Golden" then
		s.GlowColor = colors.GoldLight
		s.WhirlColor = colors.GoldLight
		s.WhirlColor2 = colors.Gold
		-- Act 4: golden spin nail, three golden rings, layered gold + blue trails.
		s.Scale = 1.9
		s.Rings = 3
		s.RingColor = colors.Gold
		s.Color = colors.DeepBlue
		s.Color2 = colors.Gold
		s.TrailColor = colors.GoldLight
		s.Helix = 3
		s.SpinSpeed = 55
		s.Afterimages = true
		s.ImpactSize = 2
		s.ImpactLayers = 3
		s.ImpactColor = colors.Gold
	elseif style == "Rotation" then
		s.GlowColor = colors.GoldLight
		s.WhirlColor = colors.GoldLight
		s.WhirlColor2 = colors.Gold
		local stage = math.floor(charge * 3 + 0.5)
		s.Scale = 1.6 + stage * 0.6
		s.Rings = 1 + stage
		s.RingColor = stage >= 3 and colors.Cyan or colors.Gold
		s.Color = colors.DeepBlue
		s.Color2 = colors.Gold
		s.TrailColor = colors.GoldLight
		s.Helix = 3
		s.SpinSpeed = 45 + stage * 15
		s.Afterimages = true
		s.ImpactSize = 1.4 + stage * 0.7
		s.ImpactLayers = 2 + stage
		s.ImpactColor = colors.Gold
		s.ImpactRadius = 4 + stage * 2
	elseif style == "InfiniteUlt" then
		s.GlowColor = colors.GoldLight
		s.WhirlColor = colors.GoldLight
		s.WhirlColor2 = colors.Gold
		s.Scale = 5
		s.Rings = 3
		s.RingColor = colors.Gold
		s.Color = colors.DeepBlue
		s.Color2 = colors.Gold
		s.TrailColor = colors.GoldLight
		s.TrailLength = 2
		s.Helix = 3
		s.HelixRadius = 0.5
		s.SpinSpeed = 30
		s.Afterimages = true
		s.ImpactSize = 4.5
		s.ImpactLayers = 4
		s.ImpactColor = colors.Gold
		s.ImpactRadius = 12
	end
	if awakened then
		s.Rings = s.Rings + 1
		s.Color2 = colors.Ice
		s.ImpactSize = s.ImpactSize * 1.15
	end
	return s, style, charge
end

local function onSpawn(data)
	local s, style, charge = styleFor(data.Visual or {})
	local visual = TuskVFX.CreateNailProjectile(s)
	local entry = {
		Id = data.Id,
		Visual = visual,
		Style = style,
		StyleData = s,
		Charge = charge,
		Origin = data.Origin,
		Direction = data.Direction,
		Speed = data.Speed,
		Range = data.Range,
		ServerTime = data.ServerTime,
		Expire = os.clock() + data.Range / data.Speed + 1.5,
	}
	active[data.Id] = entry

	-- Launch: muzzle flash, small ring, streak (projectile acceleration feel).
	local axis = CFrame.lookAt(data.Origin, data.Origin + data.Direction) * CFrame.Angles(math.pi / 2, 0, 0)
	VFXLib.burst(data.Origin, { Count = style == "Barrage" and 5 or 9, Color = s.Color2, Speed = 18, Spread = 22, Direction = data.Direction, Lifetime = 0.2 })
	VFXLib.shockwave(axis, { StartRadius = 0.2, Radius = 1.2 * s.Scale, Width = 0.12, Duration = 0.18, Color = s.Color2 })
	VFXLib.sound(sounds.NailFire, data.Origin, style == "Barrage" and 0.4 or 0.6, style == "Barrage" and 1.2 + math.random() * 0.15 or 1)
	if style == "Spinning" and charge >= 1 then
		VFXLib.flash(data.Origin, colors.Gold, 6, 18, 0.3)
		if data.OwnerId == localPlayer.UserId then
			CameraFX.speedLines(0.25, colors.Ice)
		end
	end
end

local function onEnd(data)
	local entry = active[data.Id]
	if entry then
		active[data.Id] = nil
		entry.Visual:Destroy()
	end
	local s, style, charge = styleFor(data.Visual or {})
	local color = s.ImpactColor or ((style == "Spinning" and charge >= 1) and colors.Gold or s.Color2)
	if (s.ImpactSize or 1) >= 2 and data.Normal and data.Normal.Y > 0.6 then
		TuskVFX.CreateGroundCracks(data.Position, { Radius = (s.ImpactRadius or 6) * 1.2, Color = color, Duration = 1.8 })
	end
	TuskVFX.CreateImpact(data.Position, data.Normal, {
		Size = s.ImpactSize,
		Layers = s.ImpactLayers,
		Radius = s.ImpactRadius or (style == "Spinning" and 5 or 3.5),
		Color = color,
		Color2 = colors.Ice,
		Sound = sounds.NailImpact,
		Pitch = style == "Barrage" and 1.25 or 1,
	})
	if style == "InfiniteUlt" or style == "Rotation" or style == "Golden" then
		-- Massive golden shockwave across the battlefield (scaled by style).
		local big = style == "InfiniteUlt"
		local ground = data.Position - Vector3.new(0, 1, 0)
		TuskVFX.CreateRotationalShockwave(CFrame.new(ground), { Radius = big and 40 or (s.ImpactRadius or 6) * 2, Layers = big and 5 or 3, Color = colors.Gold, Color2 = colors.Cyan, Ground = true, Particles = big and 4 or 1.5, Width = big and 1.4 or 0.7, Duration = big and 0.9 or 0.5 })
		TuskVFX.CreateDistortion(data.Position, { Radius = big and 16 or 5, Duration = big and 0.7 or 0.4 })
		VFXLib.flash(data.Position, colors.Gold, big and 16 or 7, big and 80 or 30, big and 0.9 or 0.4)
		CameraFX.shakeAt(data.Position, big and 2 or 0.8, big and 160 or 80)
		if big then
			VFXLib.sound(sounds.AwakeningBurst, data.Position, 1, 0.75)
			local camera = workspace.CurrentCamera
			if camera and (camera.CFrame.Position - data.Position).Magnitude < 120 then
				CameraFX.impactFrame(colors.GoldLight)
			end
		elseif data.HitCharacter and data.OwnerId == localPlayer.UserId then
			CameraFX.impactFrame(colors.GoldLight)
		end
	elseif style == "Spinning" then
		TuskVFX.CreateDistortion(data.Position, { Radius = 2 + charge * 3 })
		CameraFX.shakeAt(data.Position, 0.3 + charge * 0.5, 70)
		if charge >= 1 and data.HitCharacter and data.OwnerId == localPlayer.UserId then
			CameraFX.impactFrame(colors.Ice)
		end
	else
		CameraFX.shakeAt(data.Position, 0.15, 40)
	end
end

function TuskProjectiles.init()
	local FX = Net.get("SpinFX")
	FX.OnClientEvent:Connect(function(name, data)
		if name == "Hit" and typeof(data) == "table" and typeof(data.Source) == "string" and string.sub(data.Source, 1, 4) == "Tusk" then
			VFXLib.sound(sounds.Hit, data.Position, 0.6, 0.95 + math.random() * 0.1)
			return
		end
		if typeof(data) ~= "table" or data.Kind ~= "TuskNail" then
			return
		end
		if name == "ProjectileSpawn" then
			onSpawn(data)
		elseif name == "ProjectileEnd" then
			onEnd(data)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local serverNow = workspace:GetServerTimeNow()
		for id, entry in pairs(active) do
			local distance = math.min(entry.Speed * VFXLib.flight(id, entry.ServerTime), entry.Range)
			local pos = entry.Origin + entry.Direction * distance
			entry.Visual:Step(CFrame.lookAt(pos, pos + entry.Direction), dt)
			if now > entry.Expire + VFXLib.held(id, entry.ServerTime) then
				active[id] = nil
				entry.Visual:Destroy()
			end
		end
	end)
end

return TuskProjectiles
end

-- ======================================================================
-- MODULE: TuskSneakController
-- ======================================================================
__modules["TuskSneakController"] = function()
--[[
	TuskSneakController  (StarterPlayerScripts.SpinClient.TuskSneakController)

	Client side of Tusk Sneak and the Sneak Attack, for every Act.
	  Everyone sees: crouch pose, blue ground particles, ground ripples,
	                 burrow crack, the moving underground trail, the warning
	                 under the target, emergence and shockwave.
	  Local player:  lowered camera, slight zoom, blue screen-edge vignette
	                 (the HUD chip lives in TuskUI).
	Server state comes from the TuskSneaking / TuskBurrowed attributes and
	"SneakAttack" TuskFX events.
	Other players who sneak fade out with distance (TuskConfig.Sneak
	FadeStart..FadeEnd, up to MaxFade), their Stand too, and their ground
	ripples only show up close.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local VFXQuality = __require("VFXQuality")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local TuskStand = __require("TuskStand")

local TuskSneakController = {}
local colors = TuskConfig.Colors
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

local sneakers = {} -- [character] = { Emitter, Attachment, NextRipple }
local hidden = {} -- [character] = true while burrowed
local vignette

local function setHidden(character, hide)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hide and 1 or 0
		end
	end
end

local function startSneakFX(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	TuskAnimation.hold(character, "Sneak")
	local attachment = Instance.new("Attachment")
	attachment.Name = "TuskSneakFX"
	attachment.Position = Vector3.new(0, -2.7, 0)
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Sparkle
	emitter.Color = ColorSequence.new(colors.Cyan, colors.Blue)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(0.5, 2)
	emitter.SpreadAngle = Vector2.new(80, 80)
	emitter.Acceleration = Vector3.new(0, 1.5, 0)
	emitter.Rate = 14 * VFXQuality.get().Particles
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = attachment
	VFXLib.sound(sounds.SneakIn, root, 0.4, 1)
	return { Attachment = attachment, NextRipple = 0 }
end

local function stopSneakFX(character, fx)
	if fx.Attachment then
		fx.Attachment:Destroy()
	end
	TuskAnimation.stopHold(character, "Sneak")
end

-- Local-only camera and screen treatment.
local function setLocalSneak(on)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		TweenService:Create(humanoid, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			CameraOffset = on and Vector3.new(0, -TuskConfig.Sneak.CameraDrop, 0) or Vector3.new(),
		}):Play()
	end
	CameraFX.setFovHold(on and -5 or 0)
	if vignette then
		TweenService:Create(vignette, TweenInfo.new(0.3), { ImageTransparency = on and 0.35 or 1 }):Play()
	end
end

local function buildVignette()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TuskSneakVignette"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	-- Four edge gradients instead of an uploaded vignette image.
	local holder = Instance.new("ImageLabel")
	holder.BackgroundTransparency = 1
	holder.ImageTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	for _, side in ipairs({ { 0, 0.5, 90 }, { 1, 0.5, 270 }, { 0.5, 0, 180 }, { 0.5, 1, 0 } }) do
		local edge = Instance.new("Frame")
		edge.AnchorPoint = Vector2.new(side[1], side[2])
		edge.Position = UDim2.fromScale(side[1], side[2])
		edge.Size = (side[3] == 90 or side[3] == 270) and UDim2.fromScale(0.18, 1) or UDim2.fromScale(1, 0.18)
		edge.BorderSizePixel = 0
		edge.BackgroundColor3 = colors.DeepBlue
		edge.BackgroundTransparency = 1
		edge.Parent = holder
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = side[3]
		gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		gradient.Parent = edge
	end
	vignette = holder
	-- Drive the edge frames from the holder's ImageTransparency.
	holder:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
		for _, edge in ipairs(holder:GetChildren()) do
			if edge:IsA("Frame") then
				edge.BackgroundTransparency = holder.ImageTransparency
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Sneak Attack choreography
---------------------------------------------------------------------------
local function groundCrack(position, color, radius)
	TuskVFX.CreateRotationalShockwave(CFrame.new(position), { Radius = radius, Layers = 2, Color = color, Color2 = colors.DeepBlue, Ground = true, Particles = 0.6, Width = 0.3 })
	VFXLib.burst(position, {
		Count = 8,
		Texture = VFXLib.Textures.Smoke,
		Color = Color3.fromRGB(180, 160, 120),
		LightEmission = 0,
		Speed = 5,
		Lifetime = 0.9,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3) }),
		TransparencySeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
	})
end

-- Moving underground indicator: a ripple ring travelling under the ground.
local function undergroundTrail(from, target, duration)
	local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
	if not targetRoot or not VFXLib.acquire() then
		return
	end
	local ring = VFXLib.ring({ Radius = 1.4, Width = 0.25, Color = colors.Cyan, Segments = 14, Transparency = 0.2 })
	local nextPuff = 0
	VFXLib.animate(duration, function(a)
		local to = targetRoot.Parent and (targetRoot.Position - Vector3.new(0, 2.8, 0)) or from
		local pos = from:Lerp(to, VFXLib.easeInOut(a))
		ring:SetCFrame(CFrame.new(pos + Vector3.new(0, 0.1, 0)))
		ring:SetRadius(1.2 + math.sin(a * 30) * 0.25)
		if os.clock() > nextPuff then
			nextPuff = os.clock() + 0.07
			VFXLib.burst(pos, { Count = 3, Color = colors.Cyan, Speed = 6, Spread = 25, Direction = Vector3.new(0, 1, 0), Lifetime = 0.4 })
		end
	end, function()
		ring:Destroy()
		VFXLib.release()
	end)
end

local function onSneakAttack(data)
	local character = data.Character
	if data.Phase == "Burrow" then
		local burrow = data.BurrowTime or TuskConfig.Sneak.Attack.BurrowTime
		if character then
			TuskAnimation.play(character, "UndergroundDive")
		end
		groundCrack(data.Position, colors.Cyan, 5)
		VFXLib.sound(sounds.Burrow, data.Position, 0.7, 1)
		undergroundTrail(data.Position, data.Target, burrow)
	elseif data.Phase == "Warning" then
		-- Clear warning under the target: pulsing ring, distortion, alarm sound.
		local target = data.Target
		local isTarget = target == localPlayer.Character
		local wormhole = TuskVFX.CreateWormhole(CFrame.new(data.Position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(-math.pi / 2, 0, 0), {
			Radius = 2.2,
			Color = colors.Cyan,
			Color2 = colors.DeepBlue,
			OpenTime = 0.15,
			Duration = data.Duration,
			CloseTime = 0.1,
		})
		TuskVFX.CreateSpinRing({ CFrame = CFrame.new(data.Position + Vector3.new(0, 0.15, 0)), Radius = 3.5, Width = 0.35, Color = Color3.fromRGB(255, 80, 80), RotationSpeed = 6, Duration = data.Duration + 0.1 })
		VFXLib.sound(sounds.Warning, data.Position, isTarget and 0.9 or 0.5, 1)
		if isTarget then
			CameraFX.shake(0.25, data.Duration)
		end
		task.delay(data.Duration + 0.3, function()
			TuskVFX.CleanupEffect(wormhole)
		end)
	elseif data.Phase == "Emerge" then
		if character then
			TuskAnimation.play(character, "Emerge")
			TuskStand.action(character, "Emerge", { Duration = 0.35 })
		end
		VFXLib.burst(data.Position, { Count = 24, Color = colors.Ice, Speed = 30, Spread = 30, Direction = Vector3.new(0, 1, 0), Lifetime = 0.5 })
		VFXLib.sound(sounds.Emerge, data.Position, 0.8, 1)
		groundCrack(data.Position, colors.Ice, 4)
	elseif data.Phase == "Shockwave" then
		TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position), { Radius = 12, Layers = 3, Color = colors.Cyan, Color2 = colors.Blue, Ground = true, Particles = 1.5, Width = 0.6 })
		TuskVFX.CreateDistortion(data.Position + Vector3.new(0, 2, 0), { Radius = 5 })
		CameraFX.shakeAt(data.Position, 0.8, 60)
		if data.Hit and character == localPlayer.Character then
			CameraFX.impactFrame(colors.Ice)
			CameraFX.speedLines(0.3, colors.Ice)
		end
	end
end

function TuskSneakController.handle(name, data)
	if name == "SneakAttack" then
		onSneakAttack(data)
	end
end

-- Other players who sneak fade out with distance (their Stand too).
local faded = {} -- [character] = true while we've changed it
local function setFade(character, alpha)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = alpha
		end
	end
	local stand = TuskStand.get and TuskStand.get(character)
	if stand and stand.Model then
		for _, d in ipairs(stand.Model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = alpha
			end
		end
	end
end

local function fadeFor(character)
	local mine = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	local theirs = character:FindFirstChild("HumanoidRootPart")
	if not mine or not theirs then
		return 0, math.huge
	end
	local cfg = TuskConfig.Sneak
	local d = (theirs.Position - mine.Position).Magnitude
	local a = math.clamp((d - (cfg.FadeStart or 12)) / math.max((cfg.FadeEnd or 40) - (cfg.FadeStart or 12), 1), 0, 1)
	return a * (cfg.MaxFade or 0.85), d
end

function TuskSneakController.init()
	buildVignette()
	local localSneaking = false
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local seenSneak, seenHidden = {}, {}
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character then
				if character:GetAttribute("TuskSneaking") then
					seenSneak[character] = true
					local fx = sneakers[character]
					if not fx then
						fx = startSneakFX(character)
						sneakers[character] = fx or {}
					end
					-- Someone else sneaking: they fade out the further away they are.
					local alpha, dist = 0, 0
					if player ~= localPlayer then
						alpha, dist = fadeFor(character)
						setFade(character, alpha)
						faded[character] = true
					end
					-- Subtle ground ripple every so often (only close up: it'd give them away).
					if fx and fx.Attachment and now >= fx.NextRipple and dist <= (TuskConfig.Sneak.FadeStart or 12) then
						fx.NextRipple = now + 0.8
						VFXLib.shockwave(CFrame.new(fx.Attachment.WorldPosition), { StartRadius = 0.8, Radius = 3, Width = 0.12, Duration = 0.6, Color = colors.Cyan })
					end
				end
				if character:GetAttribute("TuskBurrowed") then
					seenHidden[character] = true
					if not hidden[character] then
						hidden[character] = true
						setHidden(character, true)
					end
				end
			end
		end
		for character in pairs(faded) do
			if not seenSneak[character] then
				faded[character] = nil
				if character.Parent then
					setFade(character, 0)
				end
			end
		end
		for character, fx in pairs(sneakers) do
			if not seenSneak[character] then
				sneakers[character] = nil
				stopSneakFX(character, fx)
			end
		end
		for character in pairs(hidden) do
			if not seenHidden[character] then
				hidden[character] = nil
				if character.Parent then
					setHidden(character, false)
				end
			end
		end
		local mine = localPlayer.Character and localPlayer.Character:GetAttribute("TuskSneaking") == true
		if mine ~= localSneaking then
			localSneaking = mine
			setLocalSneak(mine)
		end
	end)
end

return TuskSneakController
end

-- ======================================================================
-- MODULE: TuskStand
-- ======================================================================
__modules["TuskStand"] = function()
--[[
	TuskStand  (StarterPlayerScripts.SpinClient.TuskStand)

	Builds and animates the Tusk Stand for every player whose character
	has the TuskAct attribute. Purely client-side: each client draws all
	Stands locally, so they cost no server physics or network traffic.

	Idle: floats behind the right shoulder, bobbing, ears flapping, heart
	feet swinging, leaning with the player's movement. Sneak: drops low.
	Actions (called by Act choreography):
	  TuskStand.action(character, "Lunge", { Target = CFrame (root-local), Duration })
	  TuskStand.action(character, "Manifest")  scale-in flash
	  TuskStand.action(character, "Emerge")    rise up out of the ground
	  TuskStand.action(character, "Loom", { Target = CFrame, Duration })
	                                           rise up behind them and hold
	                                           there, right hand raised open
	TuskStand.nailPoint(character) -> world CFrame where nail energy gathers
]]

local Players = game:GetService("Players")
local Fighters = __require("Fighters")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local VFXQuality = __require("VFXQuality")
local TuskStandModels = __require("TuskStandModels")
local VFXLib = __require("VFXLib")

local TuskStand = {}

-- Where each Act's Stand floats (bigger Acts float further back).
local ATTACHED = {} -- [act] = true: the Stand is fixed to its user's body (Mandom on the shoulder): no float, no bob, no lag
local IDLE_OFFSETS = {
	[1] = CFrame.new(1.9, 1.5, 1.7),
	[2] = CFrame.new(2.1, 1.6, 2),
	[3] = CFrame.new(2.4, 1.2, 2.8),
	[4] = CFrame.new(2.6, 1.8, 3.4),
}
local IDLE_OFFSET = IDLE_OFFSETS[1]
local SNEAK_OFFSET = CFrame.new(1.5, -1.4, 1.2)

local stands = {} -- [character] = stand

-- Pink Spin energy aura around every Tusk Stand.
local AURA = Color3.fromRGB(255, 105, 205)
local AURA_LIGHT = Color3.fromRGB(255, 195, 238)

local function addAura(model, rig, AURA, AURA_LIGHT)
	local body = rig and rig.Body or model.PrimaryPart
	if not body then
		return nil
	end
	local quality = VFXQuality.get()
	local boxCF, size = model:GetBoundingBox()
	-- Invisible shell around the whole Stand that the aura particles come from.
	local shell = Instance.new("Part")
	shell.Name = "TuskAuraShell"
	shell.Transparency = 1
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.Massless = true
	shell.Anchored = false
	shell.Size = size * 0.9
	shell.CFrame = boxCF
	local weld = Instance.new("Weld")
	weld.Part0 = body
	weld.Part1 = shell
	weld.C0 = body.CFrame:ToObjectSpace(boxCF)
	weld.Parent = shell
	shell.Parent = model
	local emitters = {}
	-- Soft pink energy rising off the body.
	local glow = Instance.new("ParticleEmitter")
	glow.Texture = VFXLib.Textures.Smoke
	glow.Color = ColorSequence.new(AURA, AURA_LIGHT)
	glow.LightEmission = 1
	glow.LightInfluence = 0
	glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
	glow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.72), NumberSequenceKeypoint.new(1, 1) })
	glow.Lifetime = NumberRange.new(0.6, 1)
	glow.Speed = NumberRange.new(1, 2.5)
	glow.Acceleration = Vector3.new(0, 3, 0)
	glow.RotSpeed = NumberRange.new(-60, 60)
	glow.Rate = 14 * quality.Particles
	glow.Shape = Enum.ParticleEmitterShape.Box
	glow.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	glow.EmissionDirection = Enum.NormalId.Top
	glow.Parent = shell
	table.insert(emitters, glow)
	-- Little pink sparks orbiting out of it.
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = VFXLib.Textures.Sparkle
	sparks.Color = ColorSequence.new(AURA_LIGHT, AURA)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.Speed = NumberRange.new(1.5, 3.5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 12 * quality.Particles
	sparks.Shape = Enum.ParticleEmitterShape.Box
	sparks.Parent = shell
	table.insert(emitters, sparks)
	local light
	if quality.Lights then
		light = Instance.new("PointLight")
		light.Color = AURA
		light.Range = 9
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = body
	end
	return { Emitters = emitters, Light = light }
end

-- Distance culling (studs from the camera).
local FAR = 260 -- beyond this a Stand is hidden and not animated
local MID = 110 -- beyond this it's animated ~10 times a second instead of every frame
local GLOW_RANGE = 90 -- only Stands this close keep their Highlight outline

local function setVisible(stand, visible)
	if stand.Visible == visible then
		return
	end
	stand.Visible = visible
	for part, original in pairs(stand.Transparency) do
		part.Transparency = visible and original or 1
	end
	if stand.Aura then
		for _, e in ipairs(stand.Aura.Emitters) do
			e.Enabled = visible
		end
		if stand.Aura.Light then
			stand.Aura.Light.Enabled = visible
		end
	end
	stand.Highlight.Enabled = visible
end

local function build(character, act)
	local model, rig = TuskStandModels.build(act, 1)
	if not model then
		return nil
	end
	local transparency = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			transparency[d] = d.Transparency
		end
	end
	-- Pink Spin aura for Tusk; a registered Stand can bring its own colour.
	local info = TuskStandModels.info and TuskStandModels.info(act) or {}
	local auraColor, auraLight = info.Aura or AURA, info.AuraLight or AURA_LIGHT
	local aura = addAura(model, rig, auraColor, auraLight)
	-- Pink aura glow + outline (pulses in update); flashes brighter on Manifest.
	local highlight = Instance.new("Highlight")
	highlight.FillColor = auraColor
	highlight.FillTransparency = 0.85
	highlight.OutlineColor = auraColor
	highlight.OutlineTransparency = 0.4
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
	model.Parent = VFXLib.Folder
	local root = character:FindFirstChild("HumanoidRootPart")
	if info.Offset then
		IDLE_OFFSETS[act] = info.Offset
	end
	ATTACHED[act] = info.Attached == true or nil
	local start = root and root.CFrame * (IDLE_OFFSETS[act] or IDLE_OFFSET) or CFrame.new()
	model:PivotTo(start)
	return {
		Act = act,
		Character = character,
		Model = model,
		Rig = rig,
		Highlight = highlight,
		Aura = aura,
		Transparency = transparency,
		Visible = true,
		CF = start,
		Action = nil,
		Phase = math.random() * 10,
	}
end

local function destroy(stand)
	stand.Model:Destroy()
end

function TuskStand.get(character)
	return stands[character]
end

function TuskStand.action(character, kind, data)
	local stand = stands[character]
	if not stand then
		return
	end
	stand.Action = { Kind = kind, Start = os.clock(), Duration = (data and data.Duration) or 0.4, Data = data or {} }
	if kind == "Manifest" then
		stand.Highlight.OutlineTransparency = 0
		VFXLib.animate(0.6, function(a)
			stand.Highlight.OutlineTransparency = a
		end)
	end
end

function TuskStand.nailPoint(character)
	local stand = stands[character]
	if stand and stand.Rig.NailPoint then
		return stand.Rig.NailPoint.WorldCFrame
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.CFrame * CFrame.new(1, 1, -1.5) or CFrame.new()
end

local function update(stand, root, dt, now)
	local character = stand.Character
	local t = now + stand.Phase
	local sneaking = character:GetAttribute("TuskSneaking") == true
	local burrowed = character:GetAttribute("TuskBurrowed") == true
	local awakened = character:GetAttribute("TuskAwakened") == true

	setVisible(stand, not burrowed)
	-- Pink aura: the glow and outline breathe; Awakened = strong outline; Manifest = flash.
	local pulse = (math.sin(t * 3) + 1) / 2
	stand.Highlight.FillTransparency = 0.88 - pulse * 0.06
	stand.Highlight.OutlineTransparency = awakened and 0.05 or (stand.Action and stand.Action.Kind == "Manifest" and stand.Highlight.OutlineTransparency or (0.45 - pulse * 0.2))

	local velocity = root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local localVel = root.CFrame:VectorToObjectSpace(flat)
	local lean = math.clamp(-localVel.Z / 40, -0.4, 0.4) -- lean forward when running

	local bob = math.sin(t * 2.2) * (sneaking and 0.08 or 0.22)
	local offset = (sneaking and SNEAK_OFFSET or (IDLE_OFFSETS[stand.Act] or IDLE_OFFSET)) * CFrame.new(0, bob, 0)
	local desired = root.CFrame * offset * CFrame.Angles(-lean, math.sin(t * 0.9) * 0.12, math.sin(t * 1.3) * 0.08)
	if stand.Act == 1 and not sneaking then
		-- Act 1 is small and restless: quick bounces plus a wandering drift.
		local bounce = math.abs(math.sin(t * 4.2)) * 0.28
		local driftX = math.noise(t * 0.9, stand.Phase) * 0.6
		local driftZ = math.noise(stand.Phase, t * 0.8) * 0.45
		local wobble = math.noise(t * 1.7, stand.Phase + 3) * 0.35
		desired = desired * CFrame.new(driftX, bounce, driftZ) * CFrame.Angles(0, wobble, wobble * 0.4)
	end
	local snap = 12
	-- A remote Stand (John Rod) being steered away from its user: it stands
	-- where the server says (StandRemotePos / StandRemoteYaw).
	local remote = character:GetAttribute("StandRemotePos")
	if typeof(remote) == "Vector3" then
		desired = CFrame.new(remote) * CFrame.Angles(0, character:GetAttribute("StandRemoteYaw") or 0, 0) * CFrame.new(0, bob * 0.5, 0)
		snap = 14
		stand.Action = nil
	end

	-- Attached Stands (Mandom) sit fixed on the body: exactly where the
	-- offset says, every frame, and the move animations don't pull them off.
	if ATTACHED[stand.Act] and not sneaking and typeof(remote) ~= "Vector3" then
		desired = root.CFrame * (IDLE_OFFSETS[stand.Act] or IDLE_OFFSET)
		snap = 1e6
		stand.Action = nil
	end

	local action = stand.Action
	if action then
		local a = (now - action.Start) / action.Duration
		if a >= 1 then
			stand.Action = nil
		elseif action.Kind == "Lunge" then
			-- Out fast, hold, return.
			local target = root.CFrame * (action.Data.Target or CFrame.new(0.6, 0.8, -3.2))
			local out = a < 0.35 and VFXLib.easeOut(a / 0.35) or (a < 0.6 and 1 or 1 - VFXLib.easeInOut((a - 0.6) / 0.4))
			desired = desired:Lerp(target, out)
			snap = 30
		elseif action.Kind == "Manifest" then
			local s = VFXLib.easeOut(math.min(a / 0.5, 1))
			desired = desired * CFrame.new(0, (1 - s) * -1.5, 0) * CFrame.Angles(0, (1 - s) * math.pi * 2, 0)
			snap = 40
		elseif action.Kind == "Loom" then
			-- Rise up behind them, hold there, then settle back.
			local target = root.CFrame * (action.Data.Target or CFrame.new(1.6, 2.4, 2.2))
			local out = a < 0.25 and VFXLib.easeOut(a / 0.25) or (a < 0.85 and 1 or 1 - VFXLib.easeInOut((a - 0.85) / 0.15))
			desired = desired:Lerp(target, out)
			snap = 20
		elseif action.Kind == "Emerge" then
			local s = VFXLib.easeOut(a)
			desired = root.CFrame * CFrame.new(1.2, -3 + s * 4.2, -1.2) * CFrame.Angles(0, s * math.pi * 2, 0)
			snap = 60
		end
	end

	stand.CF = stand.CF:Lerp(desired, 1 - math.exp(-dt * snap))
	stand.Model:PivotTo(stand.CF)

	-- Secondary motion on the built-in model.
	local joints = stand.Rig.Joints
	-- Head: curious little tilts and glances (Act 1 mascot).
	if joints.Head then
		local yaw = math.noise(t * 0.7, stand.Phase + 7) * 0.7
		local tilt = math.noise(stand.Phase + 11, t * 0.9) * 0.3
		local nod = math.sin(t * 2.6) * 0.06
		joints.Head.Weld.C0 = joints.Head.Base * CFrame.Angles(nod, yaw, tilt) * joints.Head.Offset
	end
	if joints.EarL then
		local flap = math.sin(t * 3.1) * 0.18 + lean * 0.5
		joints.EarL.Weld.C0 = joints.EarL.Base * CFrame.Angles(0, 0, flap) * joints.EarL.Offset
		joints.EarR.Weld.C0 = joints.EarR.Base * CFrame.Angles(0, 0, -flap) * joints.EarR.Offset
	end
	-- Arms: idle sway; thrown forward during a Lunge (punch / nail fire).
	local punching = stand.Action and stand.Action.Kind == "Lunge"
	local punchA = 0
	if punching then
		local a = (now - stand.Action.Start) / stand.Action.Duration
		punchA = a < 0.3 and a / 0.3 or math.max(0, 1 - (a - 0.3) / 0.7)
	end
	local looming = stand.Action and stand.Action.Kind == "Loom"
	if joints.ArmR and looming then
		-- Right hand raised open beside it, left arm loose.
		local a = (now - stand.Action.Start) / stand.Action.Duration
		local up = a < 0.25 and VFXLib.easeOut(a / 0.25) or (a < 0.85 and 1 or 1 - (a - 0.85) / 0.15)
		joints.ArmR.Weld.C0 = joints.ArmR.Base * CFrame.Angles(up * 2.3, 0, -up * 0.7) * joints.ArmR.Offset
		joints.ArmL.Weld.C0 = joints.ArmL.Base * CFrame.Angles(up * 0.4, 0, up * 0.25) * joints.ArmL.Offset
	elseif joints.ArmR then
		local sway = math.sin(t * 2) * 0.12
		joints.ArmR.Weld.C0 = joints.ArmR.Base * CFrame.Angles(sway + punchA * 1.7, 0, -punchA * 0.2) * joints.ArmR.Offset
		joints.ArmL.Weld.C0 = joints.ArmL.Base * CFrame.Angles(-sway + punchA * 0.6, 0, punchA * 0.3) * joints.ArmL.Offset
	end
	for i = 1, 4 do
		local leg = joints["Leg" .. i]
		if leg then
			local swing = math.sin(t * 3.6 + i * 1.3) * 0.28 + lean * 1.2
			leg.Weld.C0 = leg.Base * CFrame.Angles(swing, 0, math.sin(t * 2 + i) * 0.1) * leg.Offset
		end
	end
end

-- Rebuild every Stand (e.g. when a custom model finishes loading).
function TuskStand.rebuildAll()
	for character, stand in pairs(stands) do
		stands[character] = nil
		if stand then
			destroy(stand)
		end
	end
end

function TuskStand.init()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local function watch(folder)
		folder.ChildAdded:Connect(TuskStand.rebuildAll)
		folder.ChildRemoved:Connect(TuskStand.rebuildAll)
	end
	local existing = ReplicatedStorage:FindFirstChild("SpinAssets")
	if existing then
		watch(existing)
	end
	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "SpinAssets" then
			watch(child)
			TuskStand.rebuildAll()
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local seen = {}
		local camera = workspace.CurrentCamera
		for _, player in ipairs(Fighters.list()) do
			local character = player.Character
			local act = character and character:GetAttribute("TuskAct")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			-- How far from the camera: far Stands are hidden and not animated,
			-- mid-range ones are animated a few times a second (big savings with
			-- lots of NPCs: each Stand is a model of 70-140 parts).
			local dist = root and camera and (root.Position - camera.CFrame.Position).Magnitude or 0
			if act and root and humanoid and humanoid.Health > 0 and dist > FAR then
				seen[character] = true
				local stand = stands[character]
				if stand then
					setVisible(stand, false)
				end
			elseif act and root and humanoid and humanoid.Health > 0 then
				seen[character] = true
				local stand = stands[character]
				if stand and stand.Act ~= act then
					destroy(stand)
					stand = nil
				end
				if not stand then
					stand = build(character, act)
					stands[character] = stand
					if stand then
						TuskStand.action(character, "Manifest", { Duration = 0.6 })
					end
				end
				if stand then
					stand.Skip = (stand.Skip or 0) + dt
					if dist <= MID or stand.Skip >= 0.1 then
						update(stand, root, stand.Skip, now)
						stand.Skip = 0
					end
					-- Only nearby Stands keep the outline glow (Highlights are costly to draw).
					local glow = stand.Visible and dist <= GLOW_RANGE
					if stand.Highlight.Enabled ~= glow then
						stand.Highlight.Enabled = glow
					end
				end
			end
		end
		for character, stand in pairs(stands) do
			if not seen[character] then
				stands[character] = nil
				if stand then
					destroy(stand)
				end
			end
		end
	end)
end

return TuskStand
end

-- ======================================================================
-- MODULE: TuskStandModels
-- ======================================================================
__modules["TuskStandModels"] = function()
--[[
	TuskStandModels  (ReplicatedStorage.SpinShared.TuskStandModels)

	Builds the Tusk Stand for each Act. Built on each client (visual only),
	so Stands never cost server physics or replication.

	TuskStandModels.build(act, scale) -> model, rig
	  rig.Body           root part of the Stand (anchored by the caller)
	  rig.Joints[name]   = { Weld = Weld, Base = CFrame } for animated pieces
	                       (EarL, EarR, Leg1..Leg4). Animate with
	                       Weld.C0 = Base * rotation.
	  rig.NailPoint      Attachment where Tusk's nail energy gathers

	Act 1 (from the owner's reference): small pink egg-shaped body covered
	in gold stars, floppy ears, a big forehead star with a gold pin running
	to a yellow beak, heavy-lidded eyes and four thin legs ending in hearts.

	Using your own model instead: set its asset id in TuskConfig.StandModels
	(StandAssetLoader loads it into ReplicatedStorage.SpinAssets), or put a
	Model named "TuskAct1" in ReplicatedStorage.SpinAssets by hand. It is
	cloned, cleaned of scripts, welded, resized to the configured Height and
	gets the same floating motion (ears/legs only animate on built-in models).
]]

local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Blockify = __require("Blockify")

local TuskStandModels = {}

local colors = TuskConfig.Colors

local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "Ellipsoid" then
			p[k] = v
		end
	end
	if props.Ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere -- fits the part size, so any Size = ellipsoid
		mesh.Parent = p
	end
	p.Parent = model
	return p
end

-- Weld `p` to `body` at local CFrame `cf` (C0 can be animated later).
local function attach(body, p, cf)
	local w = Instance.new("Weld")
	w.Part0 = body
	w.Part1 = p
	w.C0 = cf
	w.Parent = p
	p.CFrame = body.CFrame * cf
	return w
end

-- Custom Stand model: ReplicatedStorage.SpinAssets.TuskActN (loaded by
-- StandAssetLoader or placed by hand) or SpinShared.Assets.TuskActN.
local function findCustom(act)
	local name = "TuskAct" .. act
	local rs = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
	local custom = rs and rs:FindFirstChild(name)
	if not custom then
		local assets = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
		custom = assets and assets:FindFirstChild(name)
	end
	return custom
end

local function override(act, scale)
	local custom = findCustom(act)
	if not custom then
		return nil
	end
	local clone = custom:Clone()
	if not clone:IsA("Model") then
		local wrapper = Instance.new("Model")
		clone.Parent = wrapper
		clone = wrapper
	end
	-- Safety + visual-only: no scripts, no collisions, no sounds playing.
	local parts = {}
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.Anchored = false
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		return nil
	end
	-- Root = the PrimaryPart, or the biggest part.
	local root = clone.PrimaryPart
	if not root or not root:IsDescendantOf(clone) then
		root = parts[1]
		for _, p in ipairs(parts) do
			if p.Size.Magnitude > root.Size.Magnitude then
				root = p
			end
		end
		clone.PrimaryPart = root
	end
	-- Weld every loose part to the root so the model moves as one piece.
	for _, p in ipairs(parts) do
		if p ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
		end
	end
	root.Anchored = true

	-- Size and facing from TuskConfig.StandModels.
	local settings = TuskConfig.StandModels and TuskConfig.StandModels[act] or {}
	local extents = clone:GetExtentsSize()
	local height = (settings.Height or 3) * scale
	if extents.Y > 0 then
		clone:ScaleTo(clone:GetScale() * height / extents.Y)
	end
	local rot = settings.Rotation or Vector3.new()
	local boxCF = clone:GetBoundingBox()
	-- Pivot at the model's centre, facing -Z, plus the configured rotation.
	clone.WorldPivot = CFrame.new(boxCF.Position) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))

	local point = Instance.new("Attachment")
	point.Name = "NailPoint"
	point.Parent = root
	point.WorldPosition = boxCF.Position + Vector3.new(0, 0, -clone:GetExtentsSize().Z * 0.5)
	return clone, { Body = root, Joints = {}, NailPoint = point, Custom = true }
end

-- Five-point star made of five thin spikes, laid on the surface facing `normal`.
local function star(model, body, center, normal, size, color)
	local up = math.abs(normal.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local base = CFrame.lookAt(center, center + normal, up)
	for i = 0, 4 do
		local spike = part(model, {
			Name = "StarSpike",
			Size = Vector3.new(size * 0.28, size * 0.55, size * 0.04),
			Color = color,
			Ellipsoid = true,
		})
		local cf = base * CFrame.Angles(0, 0, i * math.pi * 2 / 5) * CFrame.new(0, size * 0.22, 0)
		attach(body, spike, cf)
	end
end

-- Thin isosceles triangle from two mirrored WedgeParts. Lies in the plane
-- whose normal is `normal`; apex points along `dir`.
local function triangle(model, parent, base, normal, dir, height, width, thickness, color)
	local n = normal.Unit
	local up = (dir - n * dir:Dot(n)).Unit
	local frame = CFrame.fromMatrix(base, n, up) -- X = normal, Y = toward the apex
	for _, side in ipairs({ -1, 1 }) do
		local w = Instance.new("WedgePart")
		w.Name = "StarPoint"
		w.Anchored = false
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.CastShadow = false
		w.Massless = true
		w.Material = Enum.Material.SmoothPlastic
		w.Color = color
		w.Size = Vector3.new(thickness, height, width / 2)
		local cf = frame * CFrame.new(0, height / 2, side * width / 4)
		if side > 0 then
			cf = cf * CFrame.Angles(0, math.pi, 0) -- mirror so both halves meet on the centre line
		end
		w.Parent = model
		attach(parent, w, parent.CFrame:Inverse() * cf)
	end
end

-- Proper five-pointed star (pentagon centre + five triangle points) on a surface.
local function star5(model, parent, center, normal, size, color, spin)
	local n = normal.Unit
	local helper = math.abs(n.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local u = (helper - n * helper:Dot(n)).Unit
	local v = n:Cross(u)
	local world = parent.CFrame * center
	local worldN = parent.CFrame:VectorToWorldSpace(n)
	local worldU = parent.CFrame:VectorToWorldSpace(u)
	local worldV = parent.CFrame:VectorToWorldSpace(v)
	local core = part(model, { Name = "StarCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(size * 0.06, size * 0.42, size * 0.42), Color = color })
	attach(parent, core, parent.CFrame:Inverse() * CFrame.fromMatrix(world, worldN, worldU))
	for i = 0, 4 do
		local a = (spin or 0) + i * math.pi * 2 / 5
		local dir = worldU * math.cos(a) + worldV * math.sin(a)
		triangle(model, parent, world + dir * size * 0.17, worldN, dir, size * 0.36, size * 0.26, size * 0.06, color)
	end
end

-- Tapered cone made of stacked cylinders, pointing along `dir` (parent space).
local function cone(model, parent, base, dir, length, radius, color, material)
	dir = dir.Unit
	local steps = 4
	for i = 0, steps - 1 do
		local segLen = length / steps
		local r = radius * (1 - i / steps)
		local c = base + dir * (segLen * (i + 0.5))
		local seg = part(model, { Name = "Cone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(segLen * 1.05, r * 2, r * 2), Color = color, Material = material or Enum.Material.SmoothPlastic })
		local up = math.abs(dir.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
		attach(parent, seg, CFrame.fromMatrix(c, dir, dir:Cross(up).Unit:Cross(dir)))
	end
	local tip = part(model, { Name = "ConeTip", Size = Vector3.new(radius * 0.5, radius * 0.5, radius * 0.5), Color = color, Ellipsoid = true })
	attach(parent, tip, CFrame.new(base + dir * length))
end

-- Point on the surface of an axis-aligned ellipsoid (half sizes `h`) toward `dir`.
local function onSurface(h, dir, push)
	local d = dir.Unit
	local k = 1 / math.sqrt((d.X / h.X) ^ 2 + (d.Y / h.Y) ^ 2 + (d.Z / h.Z) ^ 2)
	return d * k * (push or 1)
end

---------------------------------------------------------------------------
-- ACT 1 (from the owner's two reference images)
---------------------------------------------------------------------------
local function buildAct1Classic(scale)
	local s = scale
	local pink = Color3.fromRGB(236, 120, 200)
	local pinkLight = Color3.fromRGB(250, 170, 225)
	local pinkDark = Color3.fromRGB(176, 60, 140)
	local starColor = Color3.fromRGB(255, 182, 52)
	local gold = Color3.fromRGB(240, 190, 70)
	local heart = Color3.fromRGB(190, 36, 96)

	local model = Instance.new("Model")
	model.Name = "TuskAct1"
	local bodySize = Vector3.new(1.65, 2.5, 1.5) * s
	local h = bodySize / 2
	local body = part(model, { Name = "Body", Size = bodySize, Color = pink, Ellipsoid = true, Massless = false })
	-- Leans to its right and tips forward a little, like the drawings.
	body.CFrame = CFrame.Angles(0.12, 0, -0.2)
	body.Anchored = true
	model.PrimaryPart = body
	local rig = { Body = body, Joints = {} }

	-- Two-tone shading: lighter forehead, darker lower half.
	local cap = part(model, { Name = "Highlight", Size = bodySize * Vector3.new(0.78, 0.55, 0.72), Color = pinkLight, Ellipsoid = true })
	attach(body, cap, CFrame.new(0.12 * s, 0.42 * s, -0.22 * s))
	local belly = part(model, { Name = "Belly", Size = bodySize * Vector3.new(0.92, 0.6, 0.94), Color = pinkDark, Ellipsoid = true })
	attach(body, belly, CFrame.new(0.04 * s, -0.42 * s, 0.02 * s))
	-- Pointed bottom: the egg narrows down toward the heart legs.
	local tip = part(model, { Name = "LowerTip", Size = Vector3.new(0.9, 1.0, 0.85) * s, Color = pinkDark, Ellipsoid = true })
	attach(body, tip, CFrame.new(-0.05 * s, -1.05 * s, 0.05 * s))

	-- Long chin / snout below the face, with little gold spikes.
	local chin = part(model, { Name = "Chin", Size = Vector3.new(0.8, 0.95, 0.72) * s, Color = pink, Ellipsoid = true })
	attach(body, chin, CFrame.new(-0.18 * s, -0.8 * s, -0.2 * s) * CFrame.Angles(0.3, 0, -0.2))
	for i = 1, 3 do
		cone(model, body, Vector3.new(-(0.22 + i * 0.12) * s, (-1.05 - i * 0.04) * s, (-0.55 + i * 0.05) * s), Vector3.new(-0.6, -0.5, -0.6), 0.22 * s, 0.05 * s, gold, Enum.Material.Metal)
	end
	local mouth = part(model, { Name = "Mouth", Size = Vector3.new(0.55, 0.22, 0.2) * s, Color = Color3.fromRGB(90, 20, 50), Ellipsoid = true })
	attach(body, mouth, CFrame.new(-0.15 * s, -0.42 * s, -0.66 * s) * CFrame.Angles(0, 0, 0.25))

	-- Big forehead star with spiky dark fur around it.
	local starDir = Vector3.new(0.42, 0.62, -0.66)
	local starPos = onSurface(h, starDir, 1.02)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local n = starDir.Unit
		local helper = Vector3.new(0, 1, 0)
		local u = (helper - n * helper:Dot(n)).Unit
		local v = n:Cross(u)
		local dir = u * math.cos(a) + v * math.sin(a)
		local fur = part(model, { Name = "Fur", Size = Vector3.new(0.03, 0.03, 0.34) * s, Color = Color3.fromRGB(60, 20, 45) })
		local p = starPos + dir * 0.3 * s
		attach(body, fur, CFrame.lookAt(p, p + dir))
	end
	star5(model, body, starPos + starDir.Unit * 0.02 * s, starDir, 1.15 * s, starColor, 0.3)

	-- Eyes: white, black pupil, heavy pink lid, lashes, and wavy tendrils.
	local eyes = { { Vector3.new(0.38, 0.02, -1), -1 }, { Vector3.new(-0.3, -0.06, -1), 1 } }
	for _, e in ipairs(eyes) do
		local pos = onSurface(h, e[1], 0.98)
		local eye = part(model, { Name = "Eye", Size = Vector3.new(0.34, 0.3, 0.2) * s, Color = Color3.fromRGB(250, 248, 240), Ellipsoid = true })
		attach(body, eye, CFrame.new(pos))
		local pupil = part(model, { Name = "Pupil", Size = Vector3.new(0.15, 0.15, 0.06) * s, Color = Color3.fromRGB(25, 15, 20), Ellipsoid = true })
		attach(body, pupil, CFrame.new(pos + Vector3.new(0, -0.03 * s, -0.1 * s)))
		local shine = part(model, { Name = "Shine", Size = Vector3.new(0.05, 0.05, 0.02) * s, Color = Color3.new(1, 1, 1), Ellipsoid = true })
		attach(body, shine, CFrame.new(pos + Vector3.new(0.03 * s, 0.01 * s, -0.13 * s)))
		local lid = part(model, { Name = "Lid", Size = Vector3.new(0.44, 0.22, 0.26) * s, Color = pinkDark, Ellipsoid = true })
		attach(body, lid, CFrame.new(pos + Vector3.new(0, 0.1 * s, -0.02 * s)) * CFrame.Angles(0, 0, e[2] * 0.3))
		for l = -1, 1 do
			local lash = part(model, { Name = "Lash", Size = Vector3.new(0.025, 0.16, 0.025) * s, Color = Color3.fromRGB(40, 10, 30) })
			attach(body, lash, CFrame.new(pos + Vector3.new(l * 0.11 * s, 0.2 * s, -0.08 * s)) * CFrame.Angles(0, 0, l * 0.5))
		end
		-- Wavy pink tendril from the outer corner of each eye.
		local outward = -e[2]
		local prev = pos + Vector3.new(outward * 0.2 * s, 0, 0)
		for k = 1, 3 do
			local nextP = prev + Vector3.new(outward * 0.18 * s, (k % 2 == 0 and 0.08 or -0.06) * s, 0.02 * s)
			local seg = part(model, { Name = "Tendril", Size = Vector3.new(0.09, 0.09, 0.24) * s, Color = pinkLight, Ellipsoid = true })
			attach(body, seg, CFrame.lookAt((prev + nextP) / 2, nextP))
			prev = nextP
		end
	end

	-- Gold beak (a cone) pointing forward-down, and the gold pin from the star to its tip.
	local beakBase = onSurface(h, Vector3.new(-0.06, -0.12, -1), 0.95)
	local beakDir = Vector3.new(-0.35, -0.5, -0.8).Unit
	local beakLen = 0.6 * s
	cone(model, body, beakBase, beakDir, beakLen, 0.13 * s, gold, Enum.Material.Metal)
	local beakTip = beakBase + beakDir * beakLen
	local pinVec = beakTip - starPos
	local pin = part(model, { Name = "Pin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(pinVec.Magnitude, 0.035 * s, 0.035 * s), Color = gold, Material = Enum.Material.Metal, Reflectance = 0.3 })
	local mid = (starPos + beakTip) / 2
	attach(body, pin, CFrame.lookAt(mid, beakTip) * CFrame.Angles(0, math.pi / 2, 0))
	local pinHead = part(model, { Name = "PinHead", Size = Vector3.new(0.09, 0.09, 0.09) * s, Color = gold, Material = Enum.Material.Metal, Ellipsoid = true })
	attach(body, pinHead, CFrame.new(starPos + starDir.Unit * 0.04 * s))

	-- Orange stars all over the body.
	local spots = {
		Vector3.new(0.7, 0.55, -0.3), Vector3.new(0.85, 0.05, -0.2), Vector3.new(-0.9, 0.15, -0.1), Vector3.new(-0.7, -0.45, -0.35),
		Vector3.new(0.6, -0.55, -0.5), Vector3.new(0.15, 0.95, 0.2), Vector3.new(-0.35, 0.45, 0.8), Vector3.new(0.45, 0.2, 0.85),
		Vector3.new(-0.1, -0.7, 0.7), Vector3.new(-0.55, -0.15, -0.8), Vector3.new(0.3, 0.7, -0.6), Vector3.new(-0.8, 0.6, 0.3),
		Vector3.new(0.9, -0.35, 0.2), Vector3.new(-0.5, -0.8, -0.2), Vector3.new(0.65, 0.9, 0.1), Vector3.new(-0.95, -0.4, 0.3),
		Vector3.new(0.2, -0.9, -0.4), Vector3.new(0.95, 0.4, 0.4),
	}
	for i, d in ipairs(spots) do
		local p = onSurface(h, d, 1.01)
		star5(model, body, p, d, (0.26 + (i % 3) * 0.04) * s, starColor, i)
	end

	-- Ears: a huge floppy ear sweeping up (its left), a smaller one drooping (its right). Animated.
	local ears = {
		-- Right ear sweeps up and out; left ear droops down beside the face.
		{ Name = "EarL", Base = CFrame.new(-0.4 * s, 1.0 * s, 0.1 * s) * CFrame.Angles(0.3, -0.25, 1.35), Size = Vector3.new(0.9, 1.9, 0.16), Tip = Vector3.new(0.7, 1.25, 0.14), Curl = 0.55 },
		{ Name = "EarR", Base = CFrame.new(0.72 * s, 0.55 * s, 0.05 * s) * CFrame.Angles(-0.15, 0.3, -2.55), Size = Vector3.new(0.7, 1.55, 0.15), Tip = Vector3.new(0.5, 0.8, 0.13), Curl = -0.5 },
	}
	for _, e in ipairs(ears) do
		-- Leaf-shaped ear: a wide base, a curled tip and a darker pink inside.
		local ear = part(model, { Name = e.Name, Size = e.Size * s, Color = pink, Ellipsoid = true })
		local inner = part(model, { Name = e.Name .. "Inner", Size = e.Size * s * Vector3.new(0.62, 0.82, 0.5), Color = pinkDark, Ellipsoid = true })
		local offset = CFrame.new(0, e.Size.Y * s * 0.45, 0)
		local w = attach(body, ear, e.Base * offset)
		attach(ear, inner, CFrame.new(0, 0, -0.045 * s))
		local tipCF = CFrame.new(0, e.Size.Y * s * 0.42, 0) * CFrame.Angles(0, 0, e.Curl) * CFrame.new(0, e.Tip.Y * s * 0.4, 0)
		local tip = part(model, { Name = e.Name .. "Tip", Size = e.Tip * s, Color = pink, Ellipsoid = true })
		attach(ear, tip, tipCF)
		local tipInner = part(model, { Name = e.Name .. "Inner", Size = e.Tip * s * Vector3.new(0.55, 0.75, 0.5), Color = pinkDark, Ellipsoid = true })
		attach(ear, tipInner, tipCF * CFrame.new(0, 0, -0.04 * s))
		rig.Joints[e.Name] = { Weld = w, Base = e.Base, Offset = offset }
	end
	-- Small spike on top of the head.
	local topSpike = part(model, { Name = "TopSpike", Size = Vector3.new(0.18, 0.45, 0.14) * s, Color = pink, Ellipsoid = true })
	attach(body, topSpike, CFrame.new(-0.05 * s, 1.15 * s, 0.1 * s))

	-- Tattered pink fins around the silhouette.
	local fins = {
		CFrame.new(-0.82 * s, 0.25 * s, -0.2 * s) * CFrame.Angles(0, 0, 1.3),
		CFrame.new(0.86 * s, 0.32 * s, -0.25 * s) * CFrame.Angles(0, 0, -1.2),
		CFrame.new(-0.78 * s, -0.35 * s, -0.25 * s) * CFrame.Angles(0, 0, 2.0),
		CFrame.new(0.7 * s, -0.7 * s, -0.4 * s) * CFrame.Angles(0, 0, -2.2),
		CFrame.new(-0.4 * s, -0.95 * s, -0.4 * s) * CFrame.Angles(0, 0, 2.7),
	}
	for _, cf in ipairs(fins) do
		for k = 0, 1 do
			local fin = part(model, { Name = "Fin", Size = Vector3.new(0.24, 0.62 - k * 0.18, 0.08) * s, Color = k == 0 and pink or pinkLight, Ellipsoid = true })
			attach(body, fin, cf * CFrame.new(k * 0.1 * s, (0.26 + k * 0.14) * s, 0) * CFrame.Angles(0, 0, k * 0.5))
		end
	end

	-- Side appendage (its left) with a gold horn and a star.
	local side = part(model, { Name = "SideHand", Size = Vector3.new(1.0, 0.55, 0.5) * s, Color = pink, Ellipsoid = true })
	attach(body, side, CFrame.new(-1.05 * s, -0.15 * s, -0.1 * s) * CFrame.Angles(0, 0, 0.35))
	local sideTip = part(model, { Name = "SideHand", Size = Vector3.new(0.5, 0.42, 0.4) * s, Color = pinkLight, Ellipsoid = true })
	attach(body, sideTip, CFrame.new(-1.5 * s, 0.02 * s, -0.12 * s) * CFrame.Angles(0, 0, 0.5))
	cone(model, body, Vector3.new(-1.32 * s, -0.08 * s, -0.1 * s), Vector3.new(-1, 0.5, -0.2), 0.3 * s, 0.07 * s, gold, Enum.Material.Metal)
	star5(model, body, Vector3.new(-1.02 * s, -0.12 * s, -0.33 * s), Vector3.new(-0.2, 0.1, -1), 0.22 * s, starColor, 0.5)

	-- Five thin legs ending in hearts (four animated).
	-- Splayed out in a fan under the body, like the drawing.
	local legX = { -0.4, -0.2, 0.02, 0.24, 0.44 }
	for i = 1, 5 do
		local base = CFrame.new(legX[i] * s, -1.35 * s, (i % 2 == 0 and 0.14 or -0.14) * s) * CFrame.Angles((i % 2 == 0 and 0.15 or -0.1), 0, (i - 3) * 0.32)
		local legLength = (0.7 + ((i * 7) % 4) * 0.1) * s
		local leg = part(model, { Name = "Leg" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(legLength, 0.06 * s, 0.06 * s), Color = pinkDark })
		local offset = CFrame.new(0, -legLength / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local w = attach(body, leg, base * offset)
		if i <= 4 then
			rig.Joints["Leg" .. i] = { Weld = w, Base = base, Offset = offset }
		end
		-- Heart: two lobes and a point, facing forward.
		local footCF = CFrame.new(-legLength / 2 - 0.16 * s, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2)
		for _, sx in ipairs({ -1, 1 }) do
			local lobe = part(model, { Name = "HeartLobe", Size = Vector3.new(0.32, 0.32, 0.14) * s, Color = heart, Ellipsoid = true })
			attach(leg, lobe, footCF * CFrame.new(sx * 0.12 * s, 0.07 * s, 0))
		end
		local point = part(model, { Name = "HeartPoint", Size = Vector3.new(0.3, 0.3, 0.12) * s, Color = heart })
		attach(leg, point, footCF * CFrame.new(0, -0.09 * s, 0) * CFrame.Angles(0, 0, math.pi / 4))
	end

	local nailPoint = Instance.new("Attachment")
	nailPoint.Name = "NailPoint"
	nailPoint.Position = beakTip
	nailPoint.Parent = body
	rig.NailPoint = nailPoint
	return model, rig
end

---------------------------------------------------------------------------
-- ACT 2 (from the owner's reference images): a pink mechanical Stand with
-- a ribbed visor face, a blue star, a big dotted pod, a pincer claw and two
-- gold rods ending in purple drums.
---------------------------------------------------------------------------
local function limb(model, parent, rig, name, base, length, thickness, color, handColor)
	local arm = part(model, { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, thickness, thickness), Color = color })
	-- Cylinder axis is X; hang it down from the joint.
	local offset = CFrame.new(0, -length / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local w = attach(parent, arm, base * offset)
	rig.Joints[name] = { Weld = w, Base = base, Offset = offset }
	local hand = part(model, { Name = name .. "Hand", Size = Vector3.new(thickness * 1.6, thickness * 1.6, thickness * 1.6), Color = handColor or color, Ellipsoid = true })
	attach(arm, hand, CFrame.new(-length / 2 - thickness * 0.4, 0, 0))
	return arm, hand
end

local function buildAct2(scale)
	local s = scale * 1.1
	local pink = Color3.fromRGB(240, 150, 214)
	local pinkDark = Color3.fromRGB(196, 100, 176)
	local gold = Color3.fromRGB(232, 182, 70)
	local purple = Color3.fromRGB(86, 64, 132)
	local purpleRim = Color3.fromRGB(160, 140, 200)
	local blueStar = Color3.fromRGB(120, 200, 245)
	local yellow = Color3.fromRGB(255, 210, 70)

	local model = Instance.new("Model")
	model.Name = "TuskAct2"
	local torso = part(model, { Name = "Body", Size = Vector3.new(1.2, 1.3, 0.95) * s, Color = pink, Ellipsoid = true, Massless = false })
	torso.CFrame = CFrame.Angles(0.15, 0, -0.15)
	torso.Anchored = true
	model.PrimaryPart = torso
	local rig = { Body = torso, Joints = {} }

	-- Ribbed chest (gills).
	for i = -2, 2 do
		local rib = part(model, { Name = "Rib", Size = Vector3.new(0.08, 0.75, 0.1) * s, Color = pinkDark })
		attach(torso, rib, CFrame.new(i * 0.16 * s, -0.05 * s, -0.44 * s) * CFrame.Angles(0, i * 0.15, 0))
	end
	local belt = part(model, { Name = "Belt", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 1.05, 1.05) * s, Color = gold, Material = Enum.Material.Metal })
	attach(torso, belt, CFrame.new(0, -0.55 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))

	-- Head: round, with a ribbed visor face and a blue star.
	local head = part(model, { Name = "Head", Size = Vector3.new(1.15, 1.1, 1.1) * s, Color = pink, Ellipsoid = true })
	attach(torso, head, CFrame.new(-0.05 * s, 1.05 * s, -0.05 * s))
	local hcf = CFrame.new(-0.05 * s, 1.05 * s, -0.05 * s)
	local visor = part(model, { Name = "Visor", Size = Vector3.new(0.5, 0.72, 0.2) * s, Color = Color3.fromRGB(70, 30, 70), Ellipsoid = true })
	attach(torso, visor, hcf * CFrame.new(0, -0.05 * s, -0.47 * s))
	for i = -1, 1 do
		local bar = part(model, { Name = "VisorBar", Size = Vector3.new(0.07, 0.68, 0.08) * s, Color = pinkDark })
		attach(torso, bar, hcf * CFrame.new(i * 0.13 * s, -0.05 * s, -0.56 * s))
	end
	for _, side in ipairs({ -1, 1 }) do
		local cheek = part(model, { Name = "Cheek", Size = Vector3.new(0.28, 0.28, 0.16) * s, Color = pinkDark, Ellipsoid = true })
		attach(torso, cheek, hcf * CFrame.new(side * 0.36 * s, -0.18 * s, -0.4 * s))
		local earDisc = part(model, { Name = "EarDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.45, 0.45) * s, Color = gold, Material = Enum.Material.Metal })
		attach(torso, earDisc, hcf * CFrame.new(side * 0.57 * s, 0.05 * s, 0))
	end
	star5(model, torso, (hcf * CFrame.new(0.3 * s, 0.3 * s, -0.38 * s)).Position, Vector3.new(0.4, 0.4, -1), 0.4 * s, blueStar, 0.2)

	-- Two gold rods from the back, each ending in a purple drum (animated like ears).
	for _, d in ipairs({ { "EarL", -1 }, { "EarR", 1 } }) do
		local base = CFrame.new(d[2] * 0.35 * s, 0.55 * s, 0.4 * s) * CFrame.Angles(-0.35, 0, -d[2] * 0.75)
		local rodLength = 1.5 * s
		local rod = part(model, { Name = d[1], Shape = Enum.PartType.Cylinder, Size = Vector3.new(rodLength, 0.1 * s, 0.1 * s), Color = gold, Material = Enum.Material.Metal })
		local offset = CFrame.new(0, rodLength / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local w = attach(torso, rod, base * offset)
		rig.Joints[d[1]] = { Weld = w, Base = base, Offset = offset }
		-- Drum at the far end of the rod (rod axis = its X axis, pointing "up").
		local drum = part(model, { Name = "Drum", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.28, 0.75, 0.75) * s, Color = purple, Material = Enum.Material.Metal })
		attach(rod, drum, CFrame.new(rodLength / 2 + 0.1 * s, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))
		local rim = part(model, { Name = "DrumRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.82, 0.82) * s, Color = purpleRim, Material = Enum.Material.Metal })
		attach(rod, rim, CFrame.new(rodLength / 2 + 0.1 * s, 0, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(-0.02 * s, 0, 0))
		local hole = part(model, { Name = "DrumHole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.32, 0.32, 0.32) * s, Color = Color3.fromRGB(30, 20, 40) })
		attach(rod, hole, CFrame.new(rodLength / 2 + 0.1 * s, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))
	end

	-- Arms: right arm reaches out with a pincer claw; left arm tucked.
	local shoulderR = CFrame.new(0.68 * s, 0.35 * s, -0.05 * s) * CFrame.Angles(1.1, 0, 0.5)
	local _, handR = limb(model, torso, rig, "ArmR", shoulderR, 1.1 * s, 0.2 * s, pink, gold)
	for _, side in ipairs({ -1, 1 }) do
		local prong = part(model, { Name = "Claw", Size = Vector3.new(0.09, 0.4, 0.12) * s, Color = pinkDark })
		attach(handR, prong, CFrame.new(side * 0.1 * s, -0.25 * s, 0) * CFrame.Angles(0, 0, side * 0.35))
	end
	local shoulderL = CFrame.new(-0.68 * s, 0.35 * s, 0) * CFrame.Angles(0.4, 0, -0.35)
	limb(model, torso, rig, "ArmL", shoulderL, 0.95 * s, 0.2 * s, pink, gold)
	for _, side in ipairs({ -1, 1 }) do
		local pad = part(model, { Name = "ShoulderPad", Size = Vector3.new(0.45, 0.4, 0.45) * s, Color = pinkDark, Ellipsoid = true })
		attach(torso, pad, CFrame.new(side * 0.66 * s, 0.4 * s, 0))
	end

	-- Big dotted pod (lower body) with a yellow-and-blue star.
	local podCF = CFrame.new(0.2 * s, -1.25 * s, -0.15 * s)
	local pod = part(model, { Name = "Pod", Size = Vector3.new(1.55, 1.35, 1.45) * s, Color = pink, Ellipsoid = true })
	attach(torso, pod, podCF)
	local golden = math.pi * (3 - math.sqrt(5))
	for i = 0, 13 do
		local y = 1 - (i + 0.5) / 14 * 2
		local ring = math.sqrt(1 - y * y)
		local dir = Vector3.new(math.cos(i * golden) * ring, y, math.sin(i * golden) * ring)
		if dir.Z < 0.4 then
			local p = podCF.Position + onSurface(Vector3.new(0.775, 0.675, 0.725) * s, dir, 0.99)
			local hole = part(model, { Name = "PodHole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 0.13, 0.13) * s, Color = Color3.fromRGB(120, 50, 100) })
			local up = math.abs(dir.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
			attach(torso, hole, CFrame.fromMatrix(p, dir.Unit, dir.Unit:Cross(up).Unit:Cross(dir.Unit)))
		end
	end
	local starAt = podCF.Position + onSurface(Vector3.new(0.775, 0.675, 0.725) * s, Vector3.new(0.6, -0.1, -0.8), 1.01)
	star5(model, torso, starAt, Vector3.new(0.6, -0.1, -0.8), 0.6 * s, yellow, 0.3)
	star5(model, torso, starAt + Vector3.new(0.6, -0.1, -0.8).Unit * 0.02 * s, Vector3.new(0.6, -0.1, -0.8), 0.38 * s, blueStar, 0.3)

	rig.NailPoint = Instance.new("Attachment")
	rig.NailPoint.Name = "NailPoint"
	rig.NailPoint.Parent = handR
	return model, rig
end

---------------------------------------------------------------------------
-- Humanoid Stands (Act 3, Act 4)
---------------------------------------------------------------------------
local function buildHumanoid(name, scale, look)
	local s = scale
	local model = Instance.new("Model")
	model.Name = name
	local rig = { Joints = {} }

	local torso = part(model, { Name = "Body", Size = look.Torso * s, Color = look.Body, Ellipsoid = true, Massless = false })
	torso.CFrame = CFrame.new()
	torso.Anchored = true
	model.PrimaryPart = torso
	rig.Body = torso
	local ty = look.Torso.Y * s / 2

	-- Chest trim and star.
	local plate = part(model, { Name = "Chest", Size = Vector3.new(look.Torso.X * 0.75, look.Torso.Y * 0.45, 0.12) * s, Color = look.Trim, Material = look.TrimMaterial or Enum.Material.SmoothPlastic, Ellipsoid = true })
	attach(torso, plate, CFrame.new(0, ty * 0.3, -look.Torso.Z * s * 0.44))
	star(model, torso, Vector3.new(0, ty * 0.3, -look.Torso.Z * s * 0.52), Vector3.new(0, 0, -1), 0.55 * s, look.Star)

	-- Head with eyes, forehead star and the gold pin.
	local head = part(model, { Name = "Head", Size = look.Head * s, Color = look.HeadColor or look.Body, Ellipsoid = true })
	attach(torso, head, CFrame.new(0, ty + look.Head.Y * s * 0.45, -0.05 * s))
	local hy = look.Head.Y * s
	for _, side in ipairs({ -1, 1 }) do
		local eye = part(model, { Name = "Eye", Size = Vector3.new(0.22, 0.14, 0.08) * s, Color = look.Eye, Material = Enum.Material.Neon, Ellipsoid = true })
		attach(head, eye, CFrame.new(side * 0.2 * s, 0.02 * s, -look.Head.Z * s * 0.47) * CFrame.Angles(0, 0, side * -0.25))
	end
	star(model, head, Vector3.new(0, hy * 0.32, -look.Head.Z * s * 0.42), Vector3.new(0, 0.5, -1).Unit, 0.4 * s, look.Star)
	-- Head fins (animated like Act 1's ears).
	for _, e in ipairs({ { "EarL", -1 }, { "EarR", 1 } }) do
		local base = CFrame.new(e[2] * look.Head.X * s * 0.45, hy * 0.25, 0.05 * s) * CFrame.Angles(0, 0, -e[2] * 1.1)
		local fin = part(model, { Name = e[1], Size = Vector3.new(0.22, 0.8, 0.08) * s, Color = look.Trim, Ellipsoid = true })
		local offset = CFrame.new(0, 0.35 * s, 0)
		local w = attach(head, fin, base * offset)
		rig.Joints[e[1]] = { Weld = w, Base = base, Offset = offset }
	end

	-- Shoulders and arms.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local shoulderPos = CFrame.new(a[2] * (look.Torso.X * s * 0.5 + 0.1 * s), ty * 0.7, 0)
		local pad = part(model, { Name = "Shoulder", Size = Vector3.new(0.6, 0.5, 0.6) * s * look.ArmThickness * 3, Color = look.Trim, Material = look.TrimMaterial or Enum.Material.SmoothPlastic, Ellipsoid = true })
		attach(torso, pad, shoulderPos)
		local _, hand = limb(model, torso, rig, a[1], shoulderPos * CFrame.Angles(0, 0, a[2] * 0.15), look.ArmLength * s, look.ArmThickness * s, look.Body, look.Trim)
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Lower body: legs (Act 4) or a swirling tail (Act 3).
	if look.Legs then
		for i, side in ipairs({ -1, 1 }) do
			local base = CFrame.new(side * look.Torso.X * s * 0.25, -ty * 0.85, 0)
			limb(model, torso, rig, "Leg" .. i, base, look.LegLength * s, look.ArmThickness * 1.3 * s, look.Body, look.Trim)
		end
	else
		local y = -ty * 0.9
		for i = 1, 4 do
			local size = Vector3.new(look.Torso.X * (0.8 - i * 0.16), 0.9, look.Torso.Z * (0.8 - i * 0.16)) * s
			local seg = part(model, { Name = "Tail", Size = size, Color = i % 2 == 0 and look.Trim or look.Body, Ellipsoid = true })
			attach(torso, seg, CFrame.new(math.sin(i * 1.3) * 0.25 * s, y, math.cos(i * 1.3) * 0.2 * s) * CFrame.Angles(0, i * 0.6, 0.15 * i))
			y = y - 0.55 * s
		end
	end

	-- Scattered stars on the torso.
	for _, spot in ipairs({ Vector3.new(0.45, -0.3, -0.35), Vector3.new(-0.45, 0.1, -0.35), Vector3.new(0.3, 0.4, 0.4), Vector3.new(-0.35, -0.4, 0.4) }) do
		star(model, torso, Vector3.new(spot.X * look.Torso.X, spot.Y * look.Torso.Y, spot.Z * look.Torso.Z) * s * 1.05, Vector3.new(spot.X, 0, spot.Z).Unit, 0.22 * s, look.Star)
	end
	return model, rig
end

-- Extend a limb: segment hanging further "down" the limb from `from` (a part
-- whose local -X runs along the limb, like limb()'s hand). Returns the end joint.
local function segment(model, from, length, thickness, color, bend, jointColor)
	local joint = part(model, { Name = "Joint", Size = Vector3.new(thickness * 1.35, thickness * 1.35, thickness * 1.35), Color = jointColor or color, Material = jointColor and Enum.Material.Metal or Enum.Material.SmoothPlastic, Ellipsoid = true })
	attach(from, joint, CFrame.new())
	local seg = part(model, { Name = "Segment", Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, thickness, thickness), Color = color })
	local cf = CFrame.Angles(0, 0, bend or 0) * CFrame.new(-length / 2, 0, 0)
	attach(from, seg, cf)
	local tip = part(model, { Name = "Tip", Size = Vector3.new(thickness, thickness, thickness), Color = color, Ellipsoid = true })
	attach(from, tip, CFrame.Angles(0, 0, bend or 0) * CFrame.new(-length, 0, 0))
	return tip
end

-- Three long metal spikes fanning out from a part, along its local -X.
local function spikes(model, from, length, color)
	for i = -1, 1 do
		cone(model, from, Vector3.new(0, 0, i * 0.06), Vector3.new(-1, 0, i * 0.18), length, 0.045, color, Enum.Material.Metal)
	end
end

---------------------------------------------------------------------------
-- ACT 3 (from the owner's reference images): big pink bean body with a
-- dark crest, antennae, a slotted face mask, blue shoulder balls with red
-- stars, a purple belly lens, thin limbs with ball joints and spiked claws.
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- ACT 1 "Mascot" (owner's written description): a small, toy-like blue and
-- cyan humanoid with a big round head, big eyes, mechanical seams, pink
-- accents, short arms and legs, and cyan Spin sparkles on its hands.
---------------------------------------------------------------------------
local function sparkles(parent, color)
	local a = Instance.new("Attachment")
	a.Name = "SpinSparkles"
	a.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 7
	e.Parent = a
	return e
end

local function buildAct1Mascot(scale)
	local s = scale
	local blue = Color3.fromRGB(46, 120, 214)
	local cyan = Color3.fromRGB(90, 214, 250)
	local light = Color3.fromRGB(196, 240, 255)
	local navy = Color3.fromRGB(26, 52, 120)
	local pink = Color3.fromRGB(246, 120, 190)
	local steel = Color3.fromRGB(170, 185, 200)

	local model = Instance.new("Model")
	model.Name = "TuskAct1"
	-- Small torso is the root; the big head sits on top (animated).
	local torso = part(model, { Name = "Body", Size = Vector3.new(0.85, 0.9, 0.7) * s, Color = blue, Ellipsoid = true, Massless = false })
	torso.CFrame = CFrame.new()
	torso.Anchored = true
	model.PrimaryPart = torso
	local rig = { Body = torso, Joints = {} }

	local chest = part(model, { Name = "ChestPlate", Size = Vector3.new(0.6, 0.55, 0.2) * s, Color = light, Ellipsoid = true })
	attach(torso, chest, CFrame.new(0, 0.05 * s, -0.27 * s))
	star5(model, torso, Vector3.new(0, 0.06 * s, -0.38 * s), Vector3.new(0, 0, -1), 0.32 * s, pink, 0)
	local belt = part(model, { Name = "Belt", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.78, 0.78) * s, Color = navy, Material = Enum.Material.Metal })
	attach(torso, belt, CFrame.new(0, -0.3 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))

	-- Head: a separate welded group so it can tilt and look around.
	local headBase = CFrame.new(0, 0.95 * s, -0.02 * s)
	local head = part(model, { Name = "Head", Size = Vector3.new(1.45, 1.35, 1.35) * s, Color = cyan, Ellipsoid = true })
	local headWeld = attach(torso, head, headBase)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = CFrame.new() }
	local face = part(model, { Name = "Face", Size = Vector3.new(1.15, 0.95, 0.5) * s, Color = light, Ellipsoid = true })
	attach(head, face, CFrame.new(0, -0.08 * s, -0.47 * s))
	-- Mechanical seam ring and side bolts.
	local seam = part(model, { Name = "Seam", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 1.47, 1.47) * s, Color = navy, Material = Enum.Material.Metal })
	attach(head, seam, CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0))
	for _, side in ipairs({ -1, 1 }) do
		local bolt = part(model, { Name = "Bolt", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 0.3, 0.3) * s, Color = steel, Material = Enum.Material.Metal })
		attach(head, bolt, CFrame.new(side * 0.72 * s, 0.02 * s, 0))
		local cheek = part(model, { Name = "Cheek", Size = Vector3.new(0.18, 0.11, 0.05) * s, Color = pink, Ellipsoid = true })
		attach(head, cheek, CFrame.new(side * 0.36 * s, -0.3 * s, -0.66 * s))
	end
	-- Antenna with a pink star ball.
	local antenna = part(model, { Name = "Antenna", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 0.05, 0.05) * s, Color = navy, Material = Enum.Material.Metal })
	attach(head, antenna, CFrame.new(0.15 * s, 0.82 * s, 0) * CFrame.Angles(0, 0, math.pi / 2 - 0.3))
	local bulb = part(model, { Name = "AntennaBall", Size = Vector3.new(0.18, 0.18, 0.18) * s, Color = pink, Material = Enum.Material.Neon, Ellipsoid = true })
	attach(head, bulb, CFrame.new(0.21 * s, 1.02 * s, 0))
	-- Big, slightly mismatched toy eyes.
	for _, e in ipairs({ { -1, 0.42 }, { 1, 0.38 } }) do
		local eyePos = CFrame.new(e[1] * 0.3 * s, 0.08 * s, -0.62 * s)
		local white = part(model, { Name = "Eye", Size = Vector3.new(0.4, e[2] * 1.15, 0.2) * s, Color = Color3.new(1, 1, 1), Ellipsoid = true })
		attach(head, white, eyePos)
		local pupil = part(model, { Name = "Pupil", Size = Vector3.new(0.25, e[2] * 0.75, 0.08) * s, Color = Color3.fromRGB(15, 20, 45), Ellipsoid = true })
		attach(head, pupil, eyePos * CFrame.new(e[1] * -0.03 * s, -0.02 * s, -0.08 * s))
		local glint = part(model, { Name = "Glint", Size = Vector3.new(0.08, 0.08, 0.03) * s, Color = Color3.new(1, 1, 1), Ellipsoid = true })
		attach(head, glint, eyePos * CFrame.new(0.05 * s, 0.07 * s, -0.12 * s))
		local rim = part(model, { Name = "EyeRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 0.46, 0.46) * s, Color = navy, Material = Enum.Material.Metal })
		attach(head, rim, eyePos * CFrame.new(0, 0, 0.02 * s) * CFrame.Angles(0, math.pi / 2, 0))
	end
	local mouth = part(model, { Name = "Mouth", Size = Vector3.new(0.2, 0.07, 0.04) * s, Color = pink, Ellipsoid = true })
	attach(head, mouth, CFrame.new(0, -0.38 * s, -0.66 * s))

	-- Short arms (animated) with round hands and cyan Spin sparkles.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local shoulder = CFrame.new(a[2] * 0.45 * s, 0.22 * s, 0) * CFrame.Angles(0, 0, a[2] * 0.45)
		local _, hand = limb(model, torso, rig, a[1], shoulder, 0.5 * s, 0.2 * s, cyan, light)
		hand.Size = Vector3.new(0.3, 0.3, 0.3) * s
		local pad = part(model, { Name = "ElbowPad", Size = Vector3.new(0.22, 0.22, 0.22) * s, Color = pink, Ellipsoid = true })
		attach(torso, pad, shoulder)
		sparkles(hand, cyan)
		if a[1] == "ArmR" then
			rig.NailPoint = Instance.new("Attachment")
			rig.NailPoint.Name = "NailPoint"
			rig.NailPoint.Parent = hand
		end
	end
	-- Short stubby legs (animated) with navy boots.
	for i, side in ipairs({ -1, 1 }) do
		local hip = CFrame.new(side * 0.2 * s, -0.4 * s, 0)
		local _, foot = limb(model, torso, rig, "Leg" .. i, hip, 0.4 * s, 0.22 * s, blue, navy)
		foot.Size = Vector3.new(0.3, 0.26, 0.4) * s
	end
	return model, rig
end

-- Act 1 has two looks: "Mascot" (default) or "Classic" (the pink star
-- creature from the drawings). Switch in TuskConfig.StandModels[1].Style.
-- ACT 1, "Model" style: from the owner's Studio screenshots (front, both
-- sides, back). Smooth lilac creature: a wide domed head with two little
-- antler horns, a gold star with dark rays on the forehead (and one on the
-- back of the head), small blue eyes under a brow ridge, a dark grey beak,
-- big bat-wing ears with gold stars, two spiky fins under each wing,
-- a teardrop body that tapers to a point, stubby arms with a gold star,
-- and four pink balls hanging on thin stalks.
local function buildAct1Model(scale)
	local s = scale * 0.82
	local lilac = Color3.fromRGB(226, 184, 234)
	local light = Color3.fromRGB(242, 214, 246)
	local shade = Color3.fromRGB(204, 156, 218)
	local pinkBall = Color3.fromRGB(226, 82, 196)
	local gold = Color3.fromRGB(236, 216, 60)
	local fur = Color3.fromRGB(70, 44, 96)
	local eyeBlue = Color3.fromRGB(70, 56, 205)
	local beak = Color3.fromRGB(72, 74, 82)
	local stalk = Color3.fromRGB(240, 236, 244)

	local model = Instance.new("Model")
	model.Name = "TuskAct1"
	local headSize = Vector3.new(2.15, 1.8, 2.15) * s
	local h = headSize / 2
	local body = part(model, { Name = "Body", Size = headSize, Color = lilac, Ellipsoid = true, Massless = false })
	body.CFrame = CFrame.new()
	body.Anchored = true
	model.PrimaryPart = body
	local rig = { Body = body, Joints = {} }

	local function blob(name, size, cf, color, parent)
		local p = part(model, { Name = name, Size = size * s, Color = color or lilac, Ellipsoid = true })
		attach(parent or body, p, cf)
		return p
	end
	-- A star with dark rays around it, on `parent` at `center` facing `normal` (parent space).
	local function rayStar(parent, center, normal, size)
		local n = normal.Unit
		local helper = math.abs(n.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
		local u = (helper - n * helper:Dot(n)).Unit
		local v = n:Cross(u)
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2 + 0.3
			local dir = u * math.cos(a) + v * math.sin(a)
			local ray = part(model, { Name = "Fur", Size = Vector3.new(0.03, 0.03, size * 0.45), Color = fur })
			local p = center + dir * size * 0.62
			attach(parent, ray, CFrame.lookAt(p, p + dir))
		end
		star5(model, parent, center + n * 0.02 * s, n, size, gold, 0)
	end

	-- Head shading: lighter dome, brow ridge over the eyes.
	blob("Highlight", Vector3.new(1.75, 1.2, 1.8), CFrame.new(0, 0.3 * s, -0.06 * s), light)
	blob("Brow", Vector3.new(1.3, 0.3, 0.45), CFrame.new(0, -0.14 * s, -0.86 * s) * CFrame.Angles(-0.2, 0, 0), lilac)
	for _, side in ipairs({ -1, 1 }) do
		blob("Eye", Vector3.new(0.22, 0.22, 0.16), CFrame.new(side * 0.34 * s, -0.32 * s, -0.98 * s), eyeBlue)
		blob("Shine", Vector3.new(0.06, 0.06, 0.03), CFrame.new(side * 0.34 * s + 0.04 * s, -0.28 * s, -1.06 * s), Color3.new(1, 1, 1))
	end
	-- Dark grey beak pointing down and forward.
	cone(model, body, Vector3.new(0, -0.52 * s, -0.9 * s), Vector3.new(0, -0.85, -0.55), 0.55 * s, 0.17 * s, beak, Enum.Material.Metal)
	-- Stars: forehead and back of the head.
	local front = Vector3.new(0, 0.5, -1)
	rayStar(body, onSurface(h, front, 1.0), front, 0.55 * s)
	local back = Vector3.new(0, 0.25, 1)
	rayStar(body, onSurface(h, back, 1.0), back, 0.5 * s)
	-- Two little antler horns on top.
	for _, side in ipairs({ -1, 1 }) do
		blob("Horn", Vector3.new(0.34, 0.8, 0.34), CFrame.new(side * 0.36 * s, 1.05 * s, 0.05 * s) * CFrame.Angles(0, 0, -side * 0.22))
		blob("Horn", Vector3.new(0.24, 0.6, 0.24), CFrame.new(side * 0.52 * s, 1.58 * s, 0.05 * s) * CFrame.Angles(0, 0, -side * 0.45))
		blob("HornNub", Vector3.new(0.17, 0.36, 0.17), CFrame.new(side * 0.25 * s, 1.42 * s, 0.05 * s) * CFrame.Angles(0, 0, side * 0.5))
	end

	-- Bat-wing ears (animated: they flap). Pointed blades made of three
	-- shrinking flat pieces, angled down and out, a gold star near the root.
	for _, e in ipairs({ { "EarL", -1 }, { "EarR", 1 } }) do
		local side = e[2]
		local base = CFrame.new(side * 0.9 * s, 0.35 * s, 0.1 * s)
		local root = part(model, { Name = "Wing", Size = Vector3.new(1.5, 1.05, 0.16) * s, Color = lilac, Ellipsoid = true })
		local offset = CFrame.Angles(0, 0, -side * 0.38) * CFrame.new(side * 0.7 * s, 0, 0)
		local weld = attach(body, root, base * offset)
		rig.Joints[e[1]] = { Weld = weld, Base = base, Offset = offset }
		blob("Wing", Vector3.new(1.3, 0.68, 0.14), CFrame.new(side * 1.0 * s, -0.1 * s, 0) * CFrame.Angles(0, 0, -side * 0.1), lilac, root)
		blob("WingTip", Vector3.new(1.1, 0.3, 0.11), CFrame.new(side * 1.75 * s, -0.22 * s, 0) * CFrame.Angles(0, 0, -side * 0.15), lilac, root)
		blob("WingTip", Vector3.new(0.5, 0.1, 0.08), CFrame.new(side * 2.35 * s, -0.3 * s, 0) * CFrame.Angles(0, 0, -side * 0.2), shade, root)
		star5(model, root, Vector3.new(-side * 0.1 * s, 0.12 * s, -0.1 * s), Vector3.new(0, 0.35, -1), 0.3 * s, gold, 0.2)
		-- Two spiky fins under the wing; the lower one ends in a gold star.
		local f1 = blob("Fin", Vector3.new(0.95, 0.16, 0.14), CFrame.new(side * 1.25 * s, -0.25 * s, -0.05 * s) * CFrame.Angles(0, 0, -side * 0.35))
		local f2 = blob("Fin", Vector3.new(0.9, 0.14, 0.13), CFrame.new(side * 1.15 * s, -0.55 * s, -0.05 * s) * CFrame.Angles(0, 0, -side * 0.15))
		blob("FinSpike", Vector3.new(0.4, 0.09, 0.09), CFrame.new(side * 0.35 * s, 0.06 * s, 0) * CFrame.Angles(0, 0, side * 0.6), lilac, f1)
		star5(model, f2, Vector3.new(side * 0.45 * s, 0, -0.06 * s), Vector3.new(0, 0, -1), 0.24 * s, gold, 0)
	end

	-- Teardrop body under the head, tapering to a point.
	local torso = blob("Torso", Vector3.new(1.55, 1.7, 1.55), CFrame.new(0, -1.3 * s, 0.15 * s))
	blob("Belly", Vector3.new(1.1, 1.2, 0.9), CFrame.new(0, -0.05 * s, -0.32 * s), light, torso)
	rayStar(torso, Vector3.new(0, 0.15 * s, 0.77 * s), Vector3.new(0, 0, 1), 0.45 * s)
	local t1 = blob("Tail", Vector3.new(1.0, 1.15, 1.0), CFrame.new(0, -0.95 * s, 0.1 * s), lilac, torso)
	blob("Tail", Vector3.new(0.55, 0.9, 0.55), CFrame.new(0, -0.65 * s, 0.08 * s), lilac, t1)
	blob("TailTip", Vector3.new(0.22, 0.6, 0.22), CFrame.new(0, -1.15 * s, 0.12 * s), shade, t1)
	blob("Band", Vector3.new(0.6, 0.07, 0.52), CFrame.new(0, -0.42 * s, 0.03 * s), gold, t1)

	-- Stubby arms (animated) with a gold star; a pink ball hangs under each.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local side = a[2]
		local base = CFrame.new(side * 0.72 * s, -0.95 * s, 0.05 * s)
		local arm = part(model, { Name = a[1], Size = Vector3.new(0.62, 1.35, 0.66) * s, Color = lilac, Ellipsoid = true })
		local offset = CFrame.Angles(0, 0, side * 0.12) * CFrame.new(0, -0.5 * s, 0)
		local weld = attach(body, arm, base * offset)
		rig.Joints[a[1]] = { Weld = weld, Base = base, Offset = offset }
		star5(model, arm, Vector3.new(side * 0.29 * s, 0.05 * s, 0), Vector3.new(side, 0, 0), 0.24 * s, gold, 0)
		local st = part(model, { Name = "Stalk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 0.06, 0.06) * s, Color = stalk })
		attach(arm, st, CFrame.new(0, -0.82 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
		local ball = part(model, { Name = "HeartLobe", Size = Vector3.new(0.4, 0.38, 0.4) * s, Color = pinkBall, Ellipsoid = true })
		attach(arm, ball, CFrame.new(0, -1.1 * s, 0))
		if a[1] == "ArmR" then
			rig.NailPoint = Instance.new("Attachment")
			rig.NailPoint.Name = "NailPoint"
			rig.NailPoint.Parent = ball
		end
	end
	-- Two thin legs near the tail with pink balls (animated: they swing).
	for i, side in ipairs({ -1, 1 }) do
		local base = CFrame.new(side * 0.34 * s, -2.25 * s, 0.15 * s)
		local leg = part(model, { Name = "Leg" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 0.07, 0.07) * s, Color = stalk })
		local offset = CFrame.new(0, -0.3 * s, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local weld = attach(body, leg, base * offset)
		rig.Joints["Leg" .. i] = { Weld = weld, Base = base, Offset = offset }
		local ball = part(model, { Name = "HeartLobe", Size = Vector3.new(0.44, 0.42, 0.44) * s, Color = pinkBall, Ellipsoid = true })
		attach(leg, ball, CFrame.new(-0.5 * s, 0, 0))
	end
	return model, rig
end

local function buildAct1(scale)
	local settings = TuskConfig.StandModels and TuskConfig.StandModels[1] or {}
	if settings.Style == "Classic" then
		return buildAct1Classic(scale)
	elseif settings.Style == "Model" or settings.Style == nil then
		return buildAct1Model(scale)
	end
	return buildAct1Mascot(scale)
end

local function buildAct3(scale)
	local s = scale * 1.15
	local pink = Color3.fromRGB(226, 110, 178)
	local pinkDark = Color3.fromRGB(170, 70, 135)
	local navy = Color3.fromRGB(44, 52, 120)
	local blue = Color3.fromRGB(70, 90, 190)
	local lens = Color3.fromRGB(96, 92, 190)
	local steel = Color3.fromRGB(150, 155, 165)
	local red = Color3.fromRGB(210, 60, 40)
	local yellow = Color3.fromRGB(255, 200, 60)
	local starGold = Color3.fromRGB(240, 170, 60)

	local model = Instance.new("Model")
	model.Name = "TuskAct3"
	local bodySize = Vector3.new(2.0, 1.8, 2.3) * s
	local h = bodySize / 2
	local body = part(model, { Name = "Body", Size = bodySize, Color = pink, Ellipsoid = true, Massless = false })
	body.CFrame = CFrame.Angles(0.35, 0, 0) -- leans forward like it's about to pounce
	body.Anchored = true
	model.PrimaryPart = body
	local rig = { Body = body, Joints = {} }

	local back = part(model, { Name = "BackShade", Size = bodySize * Vector3.new(0.9, 0.7, 0.8), Color = pinkDark, Ellipsoid = true })
	attach(body, back, CFrame.new(0, -0.3 * s, 0.25 * s))

	-- Dark mohawk crest running front to back over the top.
	local crest = part(model, { Name = "Crest", Size = Vector3.new(0.16, 1.1, 2.0) * s, Color = navy, Ellipsoid = true })
	attach(body, crest, CFrame.new(0, 0.85 * s, -0.15 * s))
	-- Antennae with grey balls.
	for _, side in ipairs({ -1, 1 }) do
		local base = Vector3.new(side * 0.55 * s, 0.6 * s, -0.7 * s)
		local tipPos = base + Vector3.new(side * 0.45, 0.45, -0.2) * s
		local rod = part(model, { Name = "Antenna", Shape = Enum.PartType.Cylinder, Size = Vector3.new((tipPos - base).Magnitude, 0.04 * s, 0.04 * s), Color = pinkDark })
		attach(body, rod, CFrame.lookAt((base + tipPos) / 2, tipPos) * CFrame.Angles(0, math.pi / 2, 0))
		local ball = part(model, { Name = "AntennaBall", Size = Vector3.new(0.14, 0.14, 0.14) * s, Color = steel, Material = Enum.Material.Metal, Ellipsoid = true })
		attach(body, ball, CFrame.new(tipPos))
	end

	-- Face mask at the front: plate, two eye slits, slotted mouth.
	local facePos = onSurface(h, Vector3.new(0, -0.15, -1), 0.96)
	local mask = part(model, { Name = "Mask", Size = Vector3.new(0.85, 0.8, 0.3) * s, Color = Color3.fromRGB(236, 130, 190), Ellipsoid = true })
	attach(body, mask, CFrame.new(facePos))
	for _, side in ipairs({ -1, 1 }) do
		local slit = part(model, { Name = "EyeSlit", Size = Vector3.new(0.06, 0.24, 0.06) * s, Color = Color3.fromRGB(40, 20, 40) })
		attach(body, slit, CFrame.new(facePos + Vector3.new(side * 0.09 * s, 0.12 * s, -0.14 * s)))
	end
	for i = -2, 2 do
		local tooth = part(model, { Name = "MouthSlot", Size = Vector3.new(0.09, 0.14, 0.06) * s, Color = Color3.fromRGB(60, 25, 55) })
		attach(body, tooth, CFrame.new(facePos + Vector3.new(i * 0.13 * s, -0.2 * s, -0.12 * s)))
	end
	-- Little gold stars over the body.
	for i, d in ipairs({ Vector3.new(0.6, 0.6, -0.5), Vector3.new(-0.55, 0.5, -0.6), Vector3.new(0.75, 0.1, 0.4), Vector3.new(-0.7, 0.2, 0.4), Vector3.new(0.3, 0.85, 0.3), Vector3.new(-0.35, 0.8, -0.2), Vector3.new(0.5, -0.3, -0.8) }) do
		star5(model, body, onSurface(h, d, 1.01), d, 0.22 * s, starGold, i)
	end

	-- Purple-blue belly lens underneath.
	local lensPart = part(model, { Name = "BellyLens", Size = Vector3.new(1.0, 1.25, 0.6) * s, Color = lens, Material = Enum.Material.Glass, Reflectance = 0.2, Ellipsoid = true })
	attach(body, lensPart, CFrame.new(0, -0.95 * s, -0.25 * s) * CFrame.Angles(-0.5, 0, 0))
	local lensRim = part(model, { Name = "LensRim", Size = Vector3.new(1.1, 1.35, 0.5) * s, Color = pinkDark, Ellipsoid = true })
	attach(body, lensRim, CFrame.new(0, -0.92 * s, -0.17 * s) * CFrame.Angles(-0.5, 0, 0))
	-- Hip pistons (springs) from body to hips.
	for _, side in ipairs({ -1, 1 }) do
		local piston = part(model, { Name = "Piston", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 0.08, 0.08) * s, Color = steel, Material = Enum.Material.Metal })
		attach(body, piston, CFrame.new(side * 0.55 * s, -0.95 * s, 0.15 * s) * CFrame.Angles(0, 0, math.pi / 2 + side * 0.3))
	end

	-- Blue shoulder balls with red stars.
	for _, side in ipairs({ -1, 1 }) do
		local center = Vector3.new(side * 1.08 * s, 0.1 * s, -0.15 * s)
		local ball = part(model, { Name = "ShoulderBall", Size = Vector3.new(0.95, 0.95, 0.95) * s, Color = blue, Material = Enum.Material.SmoothPlastic, Reflectance = 0.1, Ellipsoid = true })
		attach(body, ball, CFrame.new(center))
		local starDir = Vector3.new(side * 0.8, 0.1, -0.6)
		star5(model, body, center + starDir.Unit * 0.47 * s, starDir, 0.62 * s, yellow, 0.2)
		star5(model, body, center + starDir.Unit * 0.49 * s, starDir, 0.48 * s, red, 0.2)
	end

	-- Arms: grey joints, long thin pink segments, three-spike claws.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local shoulder = CFrame.new(a[2] * 1.15 * s, -0.25 * s, -0.25 * s) * CFrame.Angles(0.25, 0, a[2] * 0.25)
		local _, hand = limb(model, body, rig, a[1], shoulder, 1.0 * s, 0.22 * s, pink, steel)
		local wrist = segment(model, hand, 0.95 * s, 0.2 * s, pink, a[2] * -0.5, steel)
		local claw = part(model, { Name = "ClawDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 0.4, 0.4) * s, Color = navy, Material = Enum.Material.Metal })
		attach(wrist, claw, CFrame.new(-0.05 * s, 0, 0))
		spikes(model, wrist, 0.7 * s, steel)
		if a[1] == "ArmR" then
			rig.NailPoint = Instance.new("Attachment")
			rig.NailPoint.Name = "NailPoint"
			rig.NailPoint.Parent = wrist
		end
	end

	-- Legs: thighs, knee joints, shins with little stars, pointed spiked feet.
	for i, side in ipairs({ -1, 1 }) do
		local hip = CFrame.new(side * 0.5 * s, -1.25 * s, 0.25 * s) * CFrame.Angles(-0.25, 0, side * 0.12)
		local _, knee = limb(model, body, rig, "Leg" .. i, hip, 0.95 * s, 0.25 * s, pink, steel)
		local ankle = segment(model, knee, 1.0 * s, 0.22 * s, pink, side * 0.35, steel)
		local foot = part(model, { Name = "Foot", Size = Vector3.new(0.3, 0.5, 0.3) * s, Color = pinkDark, Ellipsoid = true })
		attach(ankle, foot, CFrame.new(-0.12 * s, 0, 0))
		spikes(model, ankle, 0.55 * s, steel)
	end
	return model, rig
end

---------------------------------------------------------------------------
-- ACT 4 (from the owner's reference images): an armoured pink humanoid
-- with a slotted helmet, layered shoulder armour, blue gloves and boots,
-- yellow stars on the legs and a long skirt of hanging pink scales.
---------------------------------------------------------------------------
local function buildAct4(scale)
	local s = scale * 1.3
	local pink = Color3.fromRGB(240, 150, 200)
	local pinkLight = Color3.fromRGB(252, 190, 222)
	local pinkDark = Color3.fromRGB(196, 100, 160)
	local glove = Color3.fromRGB(70, 110, 170)
	local yellow = Color3.fromRGB(255, 210, 60)
	local gold = Color3.fromRGB(235, 185, 70)

	local model = Instance.new("Model")
	model.Name = "TuskAct4"
	local torso = part(model, { Name = "Body", Size = Vector3.new(1.7, 1.6, 1.15) * s, Color = pink, Ellipsoid = true, Massless = false })
	torso.CFrame = CFrame.new()
	torso.Anchored = true
	model.PrimaryPart = torso
	local rig = { Body = torso, Joints = {} }

	-- Chest armour plates and a small emblem.
	for _, side in ipairs({ -1, 1 }) do
		local plate = part(model, { Name = "ChestPlate", Size = Vector3.new(0.8, 0.75, 0.3) * s, Color = pinkLight, Ellipsoid = true })
		attach(torso, plate, CFrame.new(side * 0.38 * s, 0.25 * s, -0.48 * s) * CFrame.Angles(0, side * 0.2, 0))
	end
	local emblem = part(model, { Name = "Emblem", Size = Vector3.new(0.18, 0.18, 0.05) * s, Color = gold, Material = Enum.Material.Metal, Ellipsoid = true })
	attach(torso, emblem, CFrame.new(-0.4 * s, 0.35 * s, -0.66 * s))
	local waist = part(model, { Name = "Waist", Size = Vector3.new(1.2, 0.6, 0.9) * s, Color = pinkDark, Ellipsoid = true })
	attach(torso, waist, CFrame.new(0, -0.85 * s, 0))

	-- Helmet: dome, slotted visor, side ridges.
	local head = part(model, { Name = "Head", Size = Vector3.new(0.85, 1.0, 0.9) * s, Color = pink, Ellipsoid = true })
	attach(torso, head, CFrame.new(0, 1.15 * s, -0.08 * s))
	local hcf = CFrame.new(0, 1.15 * s, -0.08 * s)
	local visor = part(model, { Name = "Visor", Size = Vector3.new(0.55, 0.55, 0.2) * s, Color = pinkLight, Ellipsoid = true })
	attach(torso, visor, hcf * CFrame.new(0, -0.08 * s, -0.4 * s))
	for i = -2, 2 do
		local slot = part(model, { Name = "VisorSlot", Size = Vector3.new(0.05, 0.36, 0.05) * s, Color = Color3.fromRGB(80, 30, 70) })
		attach(torso, slot, hcf * CFrame.new(i * 0.09 * s, -0.08 * s, -0.5 * s))
	end
	local ridge = part(model, { Name = "HelmetRidge", Size = Vector3.new(0.12, 0.6, 0.9) * s, Color = pinkDark, Ellipsoid = true })
	attach(torso, ridge, hcf * CFrame.new(0, 0.35 * s, 0.05 * s))
	-- Head fins animate like ears.
	for _, e in ipairs({ { "EarL", -1 }, { "EarR", 1 } }) do
		local base = hcf * CFrame.new(e[2] * 0.4 * s, 0.05 * s, 0.05 * s) * CFrame.Angles(0, 0, -e[2] * 1.2)
		local fin = part(model, { Name = e[1], Size = Vector3.new(0.18, 0.45, 0.35) * s, Color = pinkDark, Ellipsoid = true })
		local offset = CFrame.new(0, 0.18 * s, 0)
		local w = attach(torso, fin, base * offset)
		rig.Joints[e[1]] = { Weld = w, Base = base, Offset = offset }
	end

	-- Layered shoulder armour, armoured arms, blue gloves.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		for layer = 0, 2 do
			local pad = part(model, { Name = "ShoulderPad", Size = Vector3.new(0.8 - layer * 0.12, 0.35, 0.85 - layer * 0.1) * s, Color = layer % 2 == 0 and pink or pinkLight, Ellipsoid = true })
			attach(torso, pad, CFrame.new(a[2] * (0.95 + layer * 0.05) * s, (0.62 - layer * 0.2) * s, 0) * CFrame.Angles(0, 0, -a[2] * (0.35 + layer * 0.1)))
		end
		-- Arms held out from the sides so the blue gloves clear the scale skirt.
		local shoulder = CFrame.new(a[2] * 1.05 * s, 0.3 * s, 0) * CFrame.Angles(0, 0, a[2] * 0.5)
		local _, elbow = limb(model, torso, rig, a[1], shoulder, 1.05 * s, 0.34 * s, pink, pinkLight)
		local wrist = segment(model, elbow, 1.0 * s, 0.3 * s, pink, a[2] * -0.3)
		local hand = part(model, { Name = "Glove", Size = Vector3.new(0.48, 0.42, 0.34) * s, Color = glove, Ellipsoid = true })
		attach(wrist, hand, CFrame.new(-0.2 * s, 0, 0))
		if a[1] == "ArmR" then
			rig.NailPoint = Instance.new("Attachment")
			rig.NailPoint.Name = "NailPoint"
			rig.NailPoint.Parent = hand
		end
	end

	-- Armoured legs, blue boots, yellow stars.
	for i, side in ipairs({ -1, 1 }) do
		local hip = CFrame.new(side * 0.4 * s, -1.05 * s, 0) * CFrame.Angles(0, 0, side * 0.05)
		local _, knee = limb(model, torso, rig, "Leg" .. i, hip, 1.2 * s, 0.42 * s, pink, pinkLight)
		local ankle = segment(model, knee, 1.15 * s, 0.38 * s, pink, 0)
		local boot = part(model, { Name = "Boot", Size = Vector3.new(0.5, 0.45, 0.8) * s, Color = glove, Ellipsoid = true })
		attach(ankle, boot, CFrame.new(-0.15 * s, 0, -0.15 * s))
		star5(model, knee, Vector3.new(-0.45 * s, 0, -0.2 * s), Vector3.new(0, 0, -1), 0.4 * s, yellow, i)
	end

	-- The skirt: rows of hanging pink scales from the chest down to the knees.
	local rows = 5
	for row = 0, rows - 1 do
		local y = (-0.35 - row * 0.42) * s
		local radius = (0.95 + row * 0.12) * s
		local count = 12 + row * 2
		for k = 0, count - 1 do
			local a = (k + (row % 2) * 0.5) / count * math.pi * 2
			local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
			local pos = Vector3.new(dir.X * radius, y, dir.Z * radius * 0.85)
			local scaleSize = Vector3.new(0.34, 0.5, 0.06) * s
			local scalePart = part(model, { Name = "Scale", Size = scaleSize, Color = (k + row) % 3 == 0 and pinkLight or pink, Ellipsoid = true })
			-- Face outward, hang down and flare out a little at the bottom.
			attach(torso, scalePart, CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-0.25 - row * 0.04, 0, 0))
		end
	end
	return model, rig
end

local builders = {
	[1] = buildAct1,
	[2] = buildAct2,
	[3] = buildAct3,
	[4] = buildAct4,
}

-- Mostly blocky, but each Act keeps the curved pieces that make it read as
-- Tusk smooth (the egg body and ears, the ear discs and drum, the round
-- body and shoulder ball, the helmet). Everything else is boxes and
-- stepped voxel-round shapes.
local EYES = { Eye = true, Pupil = true, EyeRim = true, Shine = true, Glint = true }
local function with(list)
	local out = table.clone and table.clone(EYES) or {}
	if not table.clone then
		for k, v in pairs(EYES) do
			out[k] = v
		end
	end
	for _, name in ipairs(list) do
		out[name] = true
	end
	return out
end
local SIGNATURE_ROUND = {
	[1] = with({ "Body", "Face", "Head", "EarL", "EarR", "Chin", "Cheek", "HeartLobe", "Fin", "Highlight", "Belly", "Lid", "Fur", "Seam", "AntennaBall", "PinHead" }),
	[2] = with({ "Body", "Head", "Cheek", "EarDisc", "Drum", "DrumRim", "DrumHole", "Pod", "PodHole", "Visor" }),
	[3] = with({ "Body", "BackShade", "ShoulderBall", "BellyLens", "LensRim", "Mask" }),
	[4] = with({ "Head", "Visor", "HelmetRidge", "Emblem", "Chest", "ShoulderPad" }),
}

-- Other characters' Stands: a character pack registers its own builder.
--   TuskStandModels.register(act, builder, { Aura = Color3, AuraLight = Color3, Offset = CFrame })
-- builder(scale) -> model, rig (same shape as the Tusk rigs). Registered
-- Stands are built blocky already, so they're not run through Blockify.
local registered = {}
function TuskStandModels.register(act, builder, info)
	builders[act] = builder
	registered[act] = info or {}
end

function TuskStandModels.info(act)
	return registered[act]
end

function TuskStandModels.build(act, scale)
	scale = scale or 1
	local model, rig = override(act, scale)
	if model then
		return model, rig
	end
	local builder = builders[act]
	if not builder then
		return nil
	end
	local built, rig = builder(scale)
	-- Blocky (classic Roblox) look for the procedural Stands; custom models are
	-- left as they are. Only the eyes stay round.
	local style = act == 1 and TuskConfig.StandModels and TuskConfig.StandModels[1] and TuskConfig.StandModels[1].Style
	local smooth = act == 1 and (style == "Model" or style == nil) -- the Studio-model look is smooth, like the screenshots
	if built and Blockify.enabled(TuskConfig) and not smooth and not registered[act] then
		Blockify.apply(built, { KeepRound = SIGNATURE_ROUND[act] })
	end
	return built, rig
end

return TuskStandModels
end

-- ======================================================================
-- MODULE: TuskUI
-- ======================================================================
__modules["TuskUI"] = function()
--[[
	TuskUI  (StarterPlayerScripts.SpinClient.UI.TuskUI)

	Battlegrounds-style move HUD (shown while a Stand user is equipped),
	dressed in the bounty-board house style (UITheme): dark wood plaques with
	planks, grain and nails, aged parchment, Bangers titles, chunky strokes.
	The Act's own Theme colours still show as an inlay rim, a painted stripe,
	the key tags and the ready glow, so each character reads at a glance.
	  * header: a small wooden name sign (theme stripe) + tagline
	  * hotbar of wooden move cards: M1, 1, 2, 3 and a big ULT card
	      - key tag, a drawn icon on a dark plate with a brass rim, the move
	        name on a burnt parchment strip
	      - cooldown shade that drains with a countdown, greys the icon,
	        then a golden "ready" flash and pop
	      - cards bounce on hover and squash when pressed (mouse, touch, keys)
	      - hold moves show a wood-framed charge bar (FULL when charged)
	  * ULT card: meter rising up the planks, %, READY glow with a spinning
	    shine on the rim, LOCKED timer after an awakening
	  * wooden sneak chip, combo counter, parchment toasts, awakening banner
	    with menacing "ゴ" letters, wood-framed Awakened timer bar
	  * scales down on small screens
	Act menu (T / MOVESET button): Studio test tool; a bracketed wooden
	board with a hanging sign and one parchment poster per Act.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local UITheme = __require("UITheme")

local TuskUI = {}

local player = Players.LocalPlayer
local colors = TuskConfig.Colors
local C = UITheme.C
local DARK = C.SHADOW -- icon plates (icon cut-outs are drawn in the same colour)
local GREY = Color3.fromRGB(128, 116, 100)
local WHITE = Color3.new(1, 1, 1)
local FONT = UITheme.Font.Heavy
local TITLE_FONT = UITheme.Font.Title
local NAME_INK = C.INK
local NAME_FADED = C.INK:Lerp(C.PAPER_DARK, 0.6)
local SNEAK_IDLE = C.BRASS

local CARD_W, CARD_H, M1_W, ULT_W, GAP = 84, 96, 66, 112, 8

local callbacks
local gui, hud, hudScale, header, nameSign, actLabel, actGradient, actBand, taglineLabel
local sneakChip, sneakHint, comboFrame, comboNumber, comboWord, comboDrain
local toastFrame, toastLabel, toastAccent, toastStroke
local bannerBand, banner, bannerSub, bannerGradient, menacing = nil, nil, nil, nil, {}
local awakenBar, awakenFill
local slots = {} -- [1..3] abilities, slots.M1, slots.Ult
local menu
local shownAct
local theme = { Primary = colors.Cyan, Secondary = colors.Blue }
local combo = { Count = 0, Last = 0 }
local jobs = {}
local ultShown = 0
local wasReady = false

---------------------------------------------------------------------------
-- Small builders
---------------------------------------------------------------------------
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
	return c
end

local function stroke(p, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

local function gradient(p, c0, c1, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rotation or 90
	g.Parent = p
	return g
end

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = C.PAPER
	l.TextStrokeColor3 = C.SHADOW
	l.TextStrokeTransparency = 0.5

	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function keyName(slotKey)
	local keys = TuskConfig.Keys[slotKey]
	if not keys then
		return ""
	end
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return ""
	end
	if string.find(last.Name, "Gamepad") then
		return keys.Gamepad.Name:gsub("Button", "")
	end
	local k = keys.Keyboard
	local names = { One = "1", Two = "2", Three = "3", MouseButton1 = "LMB" }
	return names[k.Name] or k.Name
end

local function animateJob(key, duration, step, done)
	VFXLib.cancel(jobs[key])
	jobs[key] = VFXLib.animate(duration, step, done)
end

---------------------------------------------------------------------------
-- Move icons, drawn from UI shapes so no image uploads are needed
---------------------------------------------------------------------------
local function iconKind(name)
	name = name or ""
	local function has(word)
		return string.find(name, word, 1, true) ~= nil
	end
	if has("PLUNDER") or has("BUBBLE") or has("GO BEYOND") then
		return "bubble"
	elseif has("HERMIT GRAB") then
		return "lasso"
	elseif has("HAMON VINES") or has("HERMIT WEB") or has("HAMON BEAT") then
		return "spiral"
	elseif has("NIGERUNDAYO") then
		return "dash"
	elseif has("VAMPIRE DRAIN") or has("WRYYY") then
		return "grab"
	elseif has("STINGY EYES") then
		return "dash"
	elseif has("KNIFE VOLLEY") then
		return "knife"
	elseif has("ZA WARUDO") then
		return "clock"
	elseif has("ORA RUSH") or has("ORA BARRAGE") then
		return "barrage"
	elseif has("STAR FINGER") then
		return "dash"
	elseif has("BEARING SHOT") then
		return "nail"
	elseif has("STAR PLATINUM: THE WORLD") then
		return "clock"
	elseif has("SIX SECONDS") or has("PATH OF JUSTICE") then
		return "clock"
	elseif has("QUICK DRAW") then
		return "nail"
	elseif has("MANDOM COUNTER") then
		return "portal"
	elseif has("REMOTE CONTROL") then
		return "portal"
	elseif has("ROD LASH") then
		return "dash"
	elseif has("WIRE SNARE") or has("OUTLINE CAGE") then
		return "lasso"
	elseif has("HEAVY RAIN") or has("TORRENT") then
		return "rain"
	elseif has("RAIN BULLETS") then
		return "spray"
	elseif has("RAIN JET") then
		return "dash"
	elseif has("CALAMITY") then
		return "calamity"
	elseif has("PURSUER") then
		return "spiral"
	elseif has("WONDER OF U") then
		return "ghost"
	elseif has("KNIFE") then
		return "knife"
	elseif has("TIME STOP") then
		return "clock"
	elseif has("STAND GRAB") then
		return "grab"
	elseif has("DIMENSION HOP") then
		return "flag"
	elseif has("PARALLEL VALENTINE") then
		return "ghost"
	elseif has("MENGER SPONGE") then
		return "cube"
	elseif has("LOVE TRAIN") then
		return "star"
	elseif has("GUILT SPECTER") then
		return "ghost"
	elseif has("ABANDONED JUNK") then
		return "junk"
	elseif has("GUILT MEMBRANE") or has("CIVIL WAR") then
		return "seal"
	elseif has("RAINDROP BLADES") or has("RAINBOW") then
		return "rain"
	elseif has("RAINDROP STEP") then
		return "dash"
	elseif has("RAINDROP CAGE") then
		return "portal"
	elseif has("FLESH SPRAY") or has("FLESH STORM") then
		return "spray"
	elseif has("FLESH SEAL") then
		return "seal"
	elseif has("FLESH MEND") then
		return "heal"
	elseif has("LASSO") or has("ROUNDUP") then
		return "lasso"
	elseif has("SPLIT DODGE") then
		return "dash"
	elseif has("SPLIT BARRAGE") then
		return "barrage"
	elseif has("SOUND TRAP") then
		return "word"
	elseif has("SOUND") or has("SILENT") then
		return "slash"
	elseif has("SAND RUN") then
		return "dash"
	elseif has("BAIT") then
		return "bait"
	elseif has("HOOK") or has("WIRED") then
		return "hook"
	elseif has("SCARY MONSTERS") then
		return "dino"
	elseif has("INFECTION") or has("BITE") then
		return "fang"
	elseif has("POUNCE") then
		return "dash"
	elseif has("GOLDEN RATIO") or has("GOLDEN SPIRAL") or has("GOLDEN COMBO") then
		return "golden"
	elseif has("BARRAGE") then
		return "barrage"
	elseif has("TORNADO") then
		return "tornado"
	elseif has("VIBRATION") then
		return "vibration"
	elseif has("BALL") then
		return "ball"
	elseif has("PURSUIT") or has("STEP") or has("DIVE") then
		return "dash"
	elseif has("BREAK") then
		return "star"
	elseif has("WORMHOLE") or has("DIMENSION") then
		return "portal"
	elseif has("SPINNING") or has("ROTATION") or has("GOLDEN") then
		return "spin"
	elseif has("NAIL") then
		return "nail"
	end
	return "spin"
end

-- Every icon part is tagged so recolouring (cooldown grey / theme) is one loop.
local function iconPart(icon, props, isStroke)
	local f = frame(icon, props)
	f:SetAttribute("IconFill", not isStroke)
	return f
end

local function ring(icon, size, thickness, pos)
	local f = frame(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos or UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(size, size), BackgroundTransparency = 1 })
	corner(f, 999)
	local s = stroke(f, WHITE, thickness)
	s:SetAttribute("IconStroke", true)
	return f
end

local function bar(icon, x, y, w, h, rot)
	local f = iconPart(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), Rotation = rot or 0, BackgroundColor3 = WHITE })
	corner(f, 3)
	return f
end

local function drawIcon(icon, kind)
	for _, c in ipairs(icon:GetChildren()) do
		c:Destroy()
	end
	if kind == "nail" then
		bar(icon, 0.45, 0.55, 0.12, 0.62, 45)
		bar(icon, 0.68, 0.32, 0.2, 0.2, 45)
	elseif kind == "barrage" then
		for i = -1, 1 do
			bar(icon, 0.5 + i * 0.2, 0.5 - i * 0.08, 0.09, 0.55, 35)
		end
	elseif kind == "spin" then
		ring(icon, 0.8, 3)
		ring(icon, 0.45, 2)
		bar(icon, 0.5, 0.5, 0.16, 0.16, 45)
	elseif kind == "portal" then
		ring(icon, 0.85, 3)
		ring(icon, 0.6, 2)
		ring(icon, 0.35, 2)
	elseif kind == "dash" then
		for i = 0, 2 do
			bar(icon, 0.28 + i * 0.22, 0.38, 0.08, 0.32, -40)
			bar(icon, 0.28 + i * 0.22, 0.62, 0.08, 0.32, 40)
		end
	elseif kind == "ball" then
		local b = bar(icon, 0.5, 0.5, 0.62, 0.62)
		corner(b, 999)
		ring(icon, 0.84, 2)
		frame(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.06), BackgroundColor3 = DARK, Rotation = -25 })
	elseif kind == "tornado" then
		for i = 0, 3 do
			bar(icon, 0.5 + (i % 2 == 0 and 0.04 or -0.04), 0.2 + i * 0.2, 0.85 - i * 0.18, 0.1, 0)
		end
	elseif kind == "vibration" then
		local b = bar(icon, 0.5, 0.5, 0.36, 0.36)
		corner(b, 999)
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 2 do
				bar(icon, 0.5 + side * (0.3 + i * 0.07), 0.5 + (i % 2 == 0 and -0.07 or 0.07), 0.05, 0.22, side * 25 * (i % 2 == 0 and 1 or -1))
			end
		end
	elseif kind == "star" then
		for i = 0, 3 do
			bar(icon, 0.5, 0.5, 0.08, i % 2 == 0 and 0.95 or 0.7, i * 45)
		end
		local c = bar(icon, 0.5, 0.5, 0.3, 0.3, 45)
		corner(c, 999)
	elseif kind == "golden" then
		-- Golden rectangle: a 1.618 box split into a square, with a spiral dot.
		local outer = frame(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.95, 0.59), BackgroundTransparency = 1 })
		local s1 = stroke(outer, WHITE, 2)
		s1:SetAttribute("IconStroke", true)
		bar(icon, 0.665, 0.5, 0.04, 0.59, 0)
		bar(icon, 0.84, 0.39, 0.33, 0.04, 0)
		ring(icon, 0.55, 2, UDim2.fromScale(0.36, 0.5))
		local dot = bar(icon, 0.77, 0.6, 0.12, 0.12)
		corner(dot, 999)
	elseif kind == "fang" then
		-- Two rows of fangs.
		for i = -1, 1 do
			bar(icon, 0.5 + i * 0.22, 0.34, 0.14, 0.34, 0)
			bar(icon, 0.5 + i * 0.22 + 0.11, 0.68, 0.12, 0.28, 0)
		end
		bar(icon, 0.5, 0.16, 0.8, 0.08, 0)
		bar(icon, 0.5, 0.86, 0.8, 0.08, 0)
	elseif kind == "dino" then
		-- Raptor head: skull, long snout, open jaw, crown pins.
		local skull = bar(icon, 0.34, 0.42, 0.38, 0.34)
		corner(skull, 999)
		bar(icon, 0.64, 0.4, 0.5, 0.16, -6)
		bar(icon, 0.6, 0.62, 0.44, 0.1, 18)
		for i = 0, 2 do
			bar(icon, 0.2 + i * 0.1, 0.16 - (i == 1 and 0.04 or 0), 0.05, 0.2, -30 + i * 30)
		end
		frame(icon, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.42, 0.36), Size = UDim2.fromScale(0.08, 0.08), BackgroundColor3 = DARK, Rotation = 45 })
	elseif kind == "hook" then
		-- Fish hook on a cable: shank, J bend, barbed point.
		bar(icon, 0.5, 0.08, 0.05, 0.16, 0) -- cable
		ring(icon, 0.16, 2, UDim2.fromScale(0.5, 0.2))
		bar(icon, 0.5, 0.48, 0.09, 0.5, 0)
		bar(icon, 0.38, 0.75, 0.3, 0.09, 0)
		bar(icon, 0.26, 0.64, 0.09, 0.26, 0)
		bar(icon, 0.3, 0.55, 0.07, 0.14, -40) -- barb
	elseif kind == "bait" then
		-- Pan of water with a feather above it.
		bar(icon, 0.45, 0.78, 0.7, 0.14, 0)
		bar(icon, 0.88, 0.72, 0.26, 0.07, -15)
		bar(icon, 0.45, 0.68, 0.58, 0.06, 0)
		bar(icon, 0.45, 0.32, 0.12, 0.4, 25)
		bar(icon, 0.52, 0.28, 0.07, 0.3, 25)
	elseif kind == "flag" then
		-- A flag on a pole: stripes and a canton.
		bar(icon, 0.28, 0.5, 0.06, 0.6, 0)
		for i = 0, 2 do
			bar(icon, 0.56, 0.3 + i * 0.1, 0.5, 0.05, 0)
		end
		bar(icon, 0.42, 0.3, 0.18, 0.16, 0)
	elseif kind == "cube" then
		-- A Menger-sponge face: a ring of eight squares.
		for i = -1, 1 do
			for j = -1, 1 do
				if not (i == 0 and j == 0) then
					bar(icon, 0.5 + i * 0.18, 0.5 + j * 0.18, 0.14, 0.14, 0)
				end
			end
		end
	elseif kind == "ghost" then
		-- A ghost: round head, a body that trails off.
		local head = bar(icon, 0.5, 0.36, 0.34, 0.3, 0)
		corner(head, 999)
		bar(icon, 0.5, 0.58, 0.34, 0.24, 0)
		bar(icon, 0.42, 0.74, 0.1, 0.1, 0)
		bar(icon, 0.58, 0.74, 0.1, 0.1, 0)
	elseif kind == "junk" then
		-- A tumbling crate and a wheel.
		bar(icon, 0.38, 0.6, 0.3, 0.3, 20)
		local wheel = bar(icon, 0.64, 0.4, 0.26, 0.26, 0)
		corner(wheel, 999)
	elseif kind == "rain" then
		-- Three falling drops.
		for i = -1, 1 do
			local d = bar(icon, 0.5 + i * 0.25, 0.42 + (i % 2) * 0.18, 0.12, 0.3, 0)
			corner(d, 999)
		end
	elseif kind == "spray" then
		-- Spray can with a mist puff.
		bar(icon, 0.32, 0.6, 0.26, 0.5, 0)
		bar(icon, 0.32, 0.3, 0.14, 0.1, 0)
		for i = 0, 2 do
			local dot = bar(icon, 0.6 + i * 0.12, 0.3 + (i - 1) * 0.1, 0.1, 0.1)
			corner(dot, 999)
		end
	elseif kind == "seal" then
		-- A face with its mouth covered.
		ring(icon, 0.72, 3)
		bar(icon, 0.38, 0.4, 0.08, 0.08)
		bar(icon, 0.62, 0.4, 0.08, 0.08)
		bar(icon, 0.5, 0.64, 0.46, 0.16, 0)
	elseif kind == "heal" then
		-- A plus.
		bar(icon, 0.5, 0.5, 0.2, 0.7, 0)
		bar(icon, 0.5, 0.5, 0.7, 0.2, 0)
	elseif kind == "lasso" then
		-- A lasso loop on a rope.
		ring(icon, 0.56, 3, UDim2.fromScale(0.42, 0.4))
		bar(icon, 0.68, 0.72, 0.07, 0.42, -40)
		bar(icon, 0.6, 0.62, 0.12, 0.12, 45)
	elseif kind == "word" then
		-- A written sound effect: three bold blocks with a burst behind.
		for i = 0, 3 do
			bar(icon, 0.5, 0.5, 0.06, 0.95, i * 45)
		end
		for i = -1, 1 do
			bar(icon, 0.5 + i * 0.24, 0.5 + (i == 0 and -0.04 or 0.04), 0.18, 0.34, i * 8)
		end
	elseif kind == "calamity" then
		-- Something heavy falling: a tilted block, speed lines above, a shadow below.
		bar(icon, 0.5, 0.48, 0.5, 0.2, -12)
		for i = -1, 1 do
			bar(icon, 0.5 + i * 0.16, 0.2, 0.05, 0.22, 0)
		end
		bar(icon, 0.5, 0.84, 0.56, 0.07, 0)
	elseif kind == "spiral" then
		-- A curse spiral: rings inside rings.
		ring(icon, 0.72, 3, UDim2.fromScale(0.5, 0.5))
		ring(icon, 0.46, 3, UDim2.fromScale(0.54, 0.5))
		ring(icon, 0.2, 3, UDim2.fromScale(0.57, 0.5))
	elseif kind == "bubble" then
		-- Bubbles: a big one and two small, with shine spots.
		ring(icon, 0.6, 3, UDim2.fromScale(0.42, 0.55))
		ring(icon, 0.3, 2, UDim2.fromScale(0.75, 0.3))
		ring(icon, 0.2, 2, UDim2.fromScale(0.78, 0.72))
		local shine = bar(icon, 0.32, 0.42, 0.1, 0.1)
		corner(shine, 999)
	elseif kind == "knife" then
		-- Three knives fanned out: blades and handles.
		for i = -1, 1 do
			bar(icon, 0.5 + i * 0.2, 0.38, 0.08, 0.46, i * 18)
			bar(icon, 0.5 + i * 0.28, 0.72, 0.1, 0.22, i * 18)
			bar(icon, 0.5 + i * 0.25, 0.62, 0.2, 0.05, i * 18)
		end
	elseif kind == "clock" then
		-- A clock face with its hands stopped.
		ring(icon, 0.82, 3)
		bar(icon, 0.5, 0.36, 0.08, 0.3, 0)
		bar(icon, 0.6, 0.5, 0.24, 0.08, 0)
		for i = 0, 3 do
			local a = i * math.pi / 2
			bar(icon, 0.5 + math.sin(a) * 0.32, 0.5 - math.cos(a) * 0.32, 0.06, 0.06, 0)
		end
	elseif kind == "grab" then
		-- An open hand reaching: palm and four fingers, a thumb.
		bar(icon, 0.5, 0.62, 0.42, 0.3, 0)
		for i = 0, 3 do
			bar(icon, 0.34 + i * 0.11, 0.33, 0.08, 0.3, 0)
		end
		bar(icon, 0.22, 0.55, 0.08, 0.26, -40)
	elseif kind == "slash" then
		for i = -1, 1 do
			bar(icon, 0.5 + i * 0.18, 0.5, 0.08, 0.8 - math.abs(i) * 0.2, 30)
		end
	end
end

local function colorIcon(icon, color)
	for _, c in ipairs(icon:GetDescendants()) do
		if c:IsA("Frame") and c:GetAttribute("IconFill") then
			c.BackgroundColor3 = color
		elseif c:IsA("UIStroke") and c:GetAttribute("IconStroke") then
			c.Color = color
		end
	end
end

---------------------------------------------------------------------------
-- Move cards
---------------------------------------------------------------------------
local function buildCard(parent, id, width, order)
	local button = Instance.new("TextButton")
	button.Name = "Move_" .. tostring(id)
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(width, CARD_H)
	button.AutoButtonColor = false
	button.Text = ""
	button.ClipsDescendants = false
	button.ZIndex = 1
	button.Parent = parent
	-- A dark wooden plaque: two planks with grain inside a dark border.
	local planks = UITheme.wood(button, { Planks = 2, Border = 4, Radius = 9, Nails = false, Stroke = 3 })
	-- Theme-coloured inlay on the wooden border (the ULT spins a shine around it).
	local rim = frame(button, { Name = "Rim", Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundTransparency = 1, ZIndex = 2 })
	corner(rim, 8)
	local edge = stroke(rim, WHITE, 1.5)
	local edgeGradient = gradient(edge, theme.Primary, theme.Secondary, 45)
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	-- Glow behind the card (shown when an ability is ready / ultimate is ready).
	local glow = frame(button, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 10, 1, 10), BackgroundTransparency = 1, ZIndex = 0 })
	corner(glow, 14)
	local glowStroke = stroke(glow, theme.Primary, 4)
	glowStroke.Transparency = 1
	-- Painted theme stripe across the top plank.
	local accent = frame(button, { Size = UDim2.new(1, -16, 0, 4), Position = UDim2.fromOffset(8, 5), BackgroundColor3 = theme.Primary, ZIndex = 3 })
	corner(accent, 2)
	stroke(accent, C.WOOD_EDGE, 1)

	-- Key tag (theme colour, dark stroke, Bangers).
	local badge = frame(button, { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(26, 18), BackgroundColor3 = theme.Primary, Rotation = -4, ZIndex = 5 })
	corner(badge, 5)
	stroke(badge, C.WOOD_EDGE, 2)
	local key = text(badge, { Size = UDim2.fromScale(1, 1), Font = TITLE_FONT, TextSize = 15, TextColor3 = C.INK, TextStrokeTransparency = 1, Text = "", ZIndex = 6 })

	-- Dark icon plate with a brass rim; the drawn icon sits on it.
	local plate = frame(button, { Name = "IconPlate", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 13), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = DARK, ZIndex = 3 })
	corner(plate, 8)
	local plateStroke = stroke(plate, C.BRASS, 2)
	gradient(plate, Color3.fromRGB(255, 235, 210), Color3.fromRGB(150, 130, 115), 90)
	local icon = frame(button, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 17), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, ZIndex = 4 })

	-- Move name on a burnt parchment strip.
	local strip = frame(button, { Name = "NameStrip", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -10, 0, 28), ZIndex = 3 })
	UITheme.paper(strip, { Radius = 4, Stroke = 2 })
	local name = text(button, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -14, 0, 26), TextScaled = true, TextWrapped = true, TextColor3 = NAME_INK, TextStrokeTransparency = 1, Text = "", ZIndex = 4 })
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = 12
	nameLimit.Parent = name

	-- Cooldown shade: drains from the top down; countdown in the middle.
	local shade = frame(button, { Size = UDim2.fromScale(1, 0), BackgroundColor3 = C.SHADOW, BackgroundTransparency = 0.3, ZIndex = 7 })
	corner(shade, 9)
	local shadeEdge = frame(shade, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = theme.Primary, ZIndex = 8 })
	local timer = text(button, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 18), Font = TITLE_FONT, TextSize = 32, TextColor3 = C.GOLD, TextStrokeTransparency = 0, Text = "", ZIndex = 9 })
	local flash = frame(button, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.GLOW, BackgroundTransparency = 1, ZIndex = 10 })
	corner(flash, 9)

	-- Wood-framed charge bar above the card (hold moves).
	local chargeBack, chargeFill = UITheme.bar(button, theme.Primary, { Name = "Charge", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -5), Size = UDim2.new(1, -4, 0, 12), Visible = false, ZIndex = 4 })
	chargeFill.Size = UDim2.fromScale(0, 1)
	local chargeText = text(chargeBack, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -1), Size = UDim2.fromOffset(80, 16), Font = TITLE_FONT, TextSize = 15, TextColor3 = C.GOLD, TextStrokeTransparency = 0.1, Text = "", ZIndex = 5 })

	local card = {
		Button = button, Scale = scale, Edge = edge, EdgeGradient = edgeGradient, Glow = glow, GlowStroke = glowStroke, Accent = accent,
		Badge = badge, Key = key, Icon = icon, Plate = plate, PlateStroke = plateStroke, Planks = planks,
 Name = name, Shade = shade, ShadeEdge = shadeEdge, Timer = timer,
		Flash = flash, ChargeBack = chargeBack, ChargeFill = chargeFill, ChargeText = chargeText,
		CooldownEnd = 0, CooldownDur = 0, Pressed = false, Pop = 0,
	}
	button.MouseButton1Down:Connect(function()
		card.Pressed = true
	end)
	button.MouseButton1Up:Connect(function()
		card.Pressed = false
	end)
	button.MouseLeave:Connect(function()
		card.Pressed = false
	end)
	button.MouseEnter:Connect(function()
		card.Hover = true
	end)
	button.MouseLeave:Connect(function()
		card.Hover = false
	end)
	return card
end

local function readyFlash(card)
	animateJob("flash" .. card.Button.Name, 0.35, function(a)
		card.Flash.BackgroundTransparency = 0.25 + a * 0.75
		card.Pop = (1 - a) * 0.12
	end, function()
		card.Pop = 0
	end)
end

---------------------------------------------------------------------------
-- Toasts, banner, combo
---------------------------------------------------------------------------
function TuskUI.toast(message, color)
	if not toastFrame then
		return
	end
	color = color or Color3.fromRGB(255, 110, 100)
	toastLabel.Text = message
	toastAccent.BackgroundColor3 = color
	toastLabel.TextColor3 = color:Lerp(C.INK, 0.45)
	toastFrame.Size = UDim2.fromOffset(math.clamp(#message * 9 + 50, 160, 460), 34)
	toastFrame.Visible = true
	animateJob("toast", 1.4, function(a)
		local slide = a < 0.12 and (1 - a / 0.12) or 0
		local fade = a < 0.75 and 0 or (a - 0.75) / 0.25
		toastFrame.Position = UDim2.new(0.5, 0, 1, -20 + slide * 14)
		toastFrame.BackgroundTransparency = fade
		toastStroke.Transparency = math.max(0.2, fade)
		toastAccent.BackgroundTransparency = fade
		toastLabel.TextTransparency = fade
		toastLabel.TextStrokeTransparency = 1
	end, function()
		toastFrame.Visible = false
	end)
end

local function showBanner(title, subtitle, color, duration)
	color = color or theme.Primary
	duration = duration or 2.2
	banner.Text = title
	bannerSub.Text = subtitle or ""
	bannerGradient.Color = ColorSequence.new(WHITE, color)
	bannerBand.BackgroundColor3 = Color3.new(0, 0, 0)
	for i, m in ipairs(menacing) do
		m.TextColor3 = Color3.fromRGB(190, 120, 255):Lerp(color, 0.3)
		m:SetAttribute("Seed", math.random() * 10 + i)
	end
	animateJob("banner", duration, function(a)
		local slideIn = a < 0.1 and (1 - VFXLib.easeOut(a / 0.1)) or 0
		local fade = a < 0.78 and 0 or (a - 0.78) / 0.22
		bannerBand.Position = UDim2.new(0.5 - slideIn * 1.2, 0, 0.26, 0)
		bannerBand.BackgroundTransparency = 0.35 + fade * 0.65
		banner.Position = UDim2.new(0.5 + slideIn * 0.8, 0, 0.26, -8)
		banner.TextTransparency = fade
		banner.TextStrokeTransparency = math.max(0.1, fade)
		banner.Rotation = -4 + (a < 0.14 and math.sin(a * 120) * 2 * (1 - a / 0.14) or 0)
		bannerSub.TextTransparency = fade
		bannerSub.TextStrokeTransparency = math.max(0.4, fade)
		for i, m in ipairs(menacing) do
			local seed = m:GetAttribute("Seed") or i
			local appear = math.clamp((a - 0.05 * i) / 0.1, 0, 1)
			m.TextTransparency = math.max(1 - appear, fade)
			m.Position = UDim2.new(m:GetAttribute("X") or 0.5, math.sin(os.clock() * 25 + seed) * 2, 0.26, (m:GetAttribute("Y") or 0) - a * 30)
		end
	end, function()
		bannerBand.BackgroundTransparency = 1
		for _, m in ipairs(menacing) do
			m.TextTransparency = 1
		end
	end)
end

local function bumpCombo()
	local now = os.clock()
	combo.Count = (now - combo.Last < 1.6) and combo.Count + 1 or 1
	combo.Last = now
	if combo.Count < 2 then
		return
	end
	comboNumber.Text = tostring(combo.Count)
	local col = combo.Count >= 15 and C.GOLD or (combo.Count >= 8 and theme.Primary or C.PAPER)
	comboNumber.TextColor3 = col
	comboDrain.BackgroundColor3 = col
	comboFrame.Visible = true
	animateJob("combo", 1.6, function(a)
		local pop = a < 0.1 and (1 - a / 0.1) * 0.5 or 0
		comboNumber.TextSize = 58 * (1 + pop)
		comboNumber.Rotation = a < 0.1 and (0.1 - a) * 80 or 0
		local fade = a < 0.8 and 0 or (a - 0.8) / 0.2
		comboNumber.TextTransparency = fade
		comboNumber.TextStrokeTransparency = math.max(0.15, fade)
		comboWord.TextTransparency = fade
		comboDrain.Size = UDim2.new(1 - a, 0, 0, 4)
		comboDrain.BackgroundTransparency = fade
	end, function()
		comboFrame.Visible = false
	end)
end

---------------------------------------------------------------------------
-- Act menu (Studio test tool)
---------------------------------------------------------------------------
local function buildMenu()
	menu = Instance.new("Frame")
	menu.Name = "ActMenu"
	menu.AnchorPoint = Vector2.new(0.5, 0.5)
	menu.Position = UDim2.fromScale(0.5, 0.5)
	menu.Size = UDim2.new(0.9, 0, 0, 330)
	menu.Visible = false
	menu.ZIndex = 20
	menu.Parent = gui
	-- A bracketed wooden board, like the bounty board.
	UITheme.wood(menu, { Planks = 4, Border = 7, Radius = 10, Brackets = true, BracketSize = 20, Stroke = 4 })
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(860, 330)
	limit.Parent = menu

	UITheme.sign(menu, "TUSK — CHOOSE YOUR ACT", nil, { Position = UDim2.new(0.5, 0, 0, -16), Size = UDim2.fromOffset(330, 46), ZIndex = 24 })
	local close = UITheme.button(menu, "X", C.RED, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(34, 34), ZIndex = 24 })
	close.Activated:Connect(function()
		menu.Visible = false
	end)

	local row = Instance.new("ScrollingFrame")
	row.Position = UDim2.fromOffset(16, 52)
	row.Size = UDim2.new(1, -32, 1, -64)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.AutomaticCanvasSize = Enum.AutomaticSize.X
	row.CanvasSize = UDim2.new()
	row.ScrollBarThickness = 4
	row.ScrollBarImageColor3 = C.BRASS
	row.ZIndex = 21
	row.Parent = menu
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 12)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = row
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = row

	for act = 1, 4 do
		local info = Registry.get(act)
		local ready = Registry.isImplemented(act)
		-- A parchment poster per Act, pinned to the board.
		local card = Instance.new("Frame")
		card.Size = UDim2.fromOffset(196, 240)
		card.ZIndex = 22
		card.Parent = row
		UITheme.paper(card, { Radius = 4, Stroke = 2 })
		if not ready then
			card.BackgroundColor3 = C.PAPER_DARK
		end
		local pin = frame(card, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = C.RED, ZIndex = 24 })
		corner(pin, 99)
		stroke(pin, C.WOOD_EDGE, 1)
		-- Theme stripe: the Act's own colours.
		local stripe = frame(card, { Position = UDim2.fromOffset(8, 18), Size = UDim2.new(1, -16, 0, 5), BackgroundColor3 = ready and info.Theme.Primary or GREY, ZIndex = 23 })
		corner(stripe, 2)
		gradient(stripe, WHITE, ready and info.Theme.Secondary:Lerp(WHITE, 0.3) or GREY, 0)
		text(card, { Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 30), Font = TITLE_FONT, TextSize = 28, TextColor3 = ready and C.INK or NAME_FADED, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Text = info.Name, ZIndex = 23 })
		text(card, { Position = UDim2.fromOffset(10, 56), Size = UDim2.new(1, -20, 0, 14), Font = UITheme.Font.Body, TextSize = 11, TextColor3 = ready and info.Theme.Primary:Lerp(C.INK, 0.55) or NAME_FADED, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Text = info.Tagline, ZIndex = 23 })
		local moves = "M1  " .. info.M1 .. "\n1  " .. info.Abilities[1] .. "\n2  " .. info.Abilities[2] .. "\n3  " .. info.Abilities[3] .. "\nULT  " .. info.Ultimate
		text(card, { Position = UDim2.fromOffset(10, 76), Size = UDim2.new(1, -20, 0, 106), Font = UITheme.Font.Body, TextSize = 12, TextColor3 = C.INK, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Text = moves, ZIndex = 23 })
		if ready then
			local pick = UITheme.button(card, "SELECT", info.Theme.Secondary, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -24, 0, 38), ZIndex = 23 })
			pick.Activated:Connect(function()
				callbacks.Select(act)
				menu.Visible = false
			end)
		else
			-- Stamped across the poster.
			local stamp = text(card, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -30, 0, 34), Font = TITLE_FONT, TextSize = 22, TextColor3 = C.RED, TextStrokeTransparency = 1, Rotation = -6, Text = "IN DEVELOPMENT", ZIndex = 23 })
			stroke(stamp, C.RED, 2).Transparency = 0.3
		end
	end
end


---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
function TuskUI.init(cb)
	callbacks = cb
	gui = Instance.new("ScreenGui")
	gui.Name = "TuskHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local width = M1_W + CARD_W * 3 + ULT_W + GAP * 4
	hud = frame(gui, { Name = "HUD", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(width, 156), BackgroundTransparency = 1, Visible = false })
	hudScale = Instance.new("UIScale")
	hudScale.Parent = hud

	-- Header: a small wooden name sign with a theme stripe, tagline under it.
	header = frame(hud, { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	nameSign = frame(header, { Name = "NameSign", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(230, 32), Rotation = -1.5, ZIndex = 1 })
	UITheme.wood(nameSign, { Planks = 1, Border = 3, Radius = 6, Nails = true, Stroke = 3 })
	actBand = frame(nameSign, { Name = "ThemeStripe", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -4), Size = UDim2.new(1, -20, 0, 3), BackgroundColor3 = theme.Primary, ZIndex = 2 })
	corner(actBand, 2)
	actLabel = text(nameSign, { Position = UDim2.fromOffset(12, 1), Size = UDim2.new(1, -24, 1, -6), Font = TITLE_FONT, TextSize = 28, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = C.SHADOW, Text = "", ZIndex = 3 })
	actGradient = gradient(actLabel, WHITE, theme.Primary, 90)
	taglineLabel = text(header, { Position = UDim2.fromOffset(8, 33), Size = UDim2.fromOffset(320, 12), Font = UITheme.Font.Body, TextSize = 11, TextColor3 = C.PAPER, TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 2 })

	-- Sneak chip (every character), right side of the header.
	sneakChip = Instance.new("TextButton")
	sneakChip.Name = "Sneak"
	sneakChip.AnchorPoint = Vector2.new(1, 0)
	sneakChip.Position = UDim2.new(1, 0, 0, 8)
	sneakChip.Size = UDim2.fromOffset(104, 26)
	sneakChip.AutoButtonColor = false
	sneakChip.Text = ""
	sneakChip.ZIndex = 1
	sneakChip.Parent = header
	-- A little wooden plank with a brass key tag.
	UITheme.wood(sneakChip, { Planks = 1, Border = 2, Radius = 7, Nails = false, Stroke = 2 })
	local sneakStroke = sneakChip:FindFirstChildOfClass("UIStroke")
	local sneakKey = frame(sneakChip, { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(20, 18), BackgroundColor3 = SNEAK_IDLE, ZIndex = 2 })
	corner(sneakKey, 5)
	stroke(sneakKey, C.WOOD_EDGE, 1.5)
	local sneakKeyText = text(sneakKey, { Size = UDim2.fromScale(1, 1), Font = TITLE_FONT, TextSize = 14, TextColor3 = C.INK, TextStrokeTransparency = 1, Text = "C", ZIndex = 3 })
	local sneakText = text(sneakChip, { Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -32, 1, 0), Font = TITLE_FONT, TextSize = 17, TextColor3 = C.PAPER, TextStrokeTransparency = 0.3, Text = "SNEAK", ZIndex = 2 })
	UITheme.hover(sneakChip)
	sneakChip:SetAttribute("Built", true)
	sneakChip.Activated:Connect(function()
		callbacks.Sneak()
	end)
	slots.SneakParts = { Stroke = sneakStroke, Key = sneakKey, KeyText = sneakKeyText, Text = sneakText }
	sneakHint = text(hud, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 0, -2), Size = UDim2.fromOffset(240, 16), Font = UITheme.Font.Body, TextSize = 12, TextColor3 = C.GOLD, TextStrokeTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Right, Text = "", Visible = false })

	-- Hotbar.
	local row = frame(hud, { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, CARD_H), BackgroundTransparency = 1 })
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = row
	slots.M1 = buildCard(row, "M1", M1_W, 0)
	drawIcon(slots.M1.Icon, "slash")
	for i = 1, 3 do
		local card = buildCard(row, i, CARD_W, i)
		card.Slot = i
		card.Button.MouseButton1Down:Connect(function()
			callbacks.Ability(i, true)
		end)
		card.Button.MouseButton1Up:Connect(function()
			callbacks.Ability(i, false)
		end)
		slots[i] = card
	end
	local ult = buildCard(row, "Ult", ULT_W, 4)
	slots.Ult = ult
	-- Ultimate meter rises from the bottom of the card.
	-- (inside the planks, so the wood grain shows through it).
	ult.Meter = frame(ult.Planks, { Name = "Meter", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.4, ZIndex = 2 })
	ult.MeterGradient = gradient(ult.Meter, theme.Primary, theme.Secondary, 90)
	frame(ult.Meter, { Name = "Top", Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.GOLD, BackgroundTransparency = 0.2, ZIndex = 2 })
	ult.Percent = text(ult.Button, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 5), Size = UDim2.fromOffset(54, 18), Font = TITLE_FONT, TextSize = 17, TextColor3 = C.GOLD, TextStrokeTransparency = 0, TextXAlignment = Enum.TextXAlignment.Right, Text = "0%", ZIndex = 6 })
	ult.Icon.Size = UDim2.fromOffset(46, 46)
	ult.Icon.Position = UDim2.new(0.5, 0, 0, 15)
	ult.Plate.Size = UDim2.fromOffset(54, 52)
	ult.Plate.Position = UDim2.new(0.5, 0, 0, 12)
	drawIcon(ult.Icon, "star")
	ult.Button.Activated:Connect(function()
		callbacks.Ultimate()
	end)

	-- Awakened timer bar under the hotbar.
	awakenBar, awakenFill = UITheme.bar(hud, theme.Primary, { Name = "AwakenBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52 + CARD_H + 4), Size = UDim2.new(1, 0, 0, 10), Visible = false })

	-- Combo counter (right middle of the screen).
	comboFrame = frame(gui, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -28, 0.42, 0), Size = UDim2.fromOffset(200, 90), BackgroundTransparency = 1, Visible = false })
	comboNumber = text(comboFrame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(200, 60), Font = TITLE_FONT, TextSize = 58, TextStrokeTransparency = 0.15, TextStrokeColor3 = C.WOOD_EDGE, TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
	comboWord = text(comboFrame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 58), Size = UDim2.fromOffset(200, 18), Font = TITLE_FONT, TextSize = 21, TextColor3 = C.RED:Lerp(WHITE, 0.15), TextStrokeTransparency = 0.1, TextXAlignment = Enum.TextXAlignment.Right, Text = "HIT COMBO!" })
	comboDrain = frame(comboFrame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 80), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = C.PAPER })
	corner(comboDrain, 2)
	stroke(comboDrain, C.WOOD_EDGE, 1)

	-- Toast pill above the hotbar.
	local toastHolder = frame(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -190), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1 })
	-- A torn parchment note with a coloured pin.
	toastFrame = frame(toastHolder, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(260, 34), Visible = false })
	UITheme.paper(toastFrame, { Radius = 5, Stroke = 2 })
	toastStroke = toastFrame:FindFirstChildOfClass("UIStroke")
	toastAccent = frame(toastFrame, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.fromRGB(255, 110, 100), ZIndex = 2 })
	corner(toastAccent, 99)
	toastLabel = text(toastFrame, { Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -40, 1, 0), TextSize = 15, TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 2 })

	-- Awakening banner: black slash band, gradient title, menacing ゴ letters.
	bannerBand = frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.new(1.4, 0, 0, 110), BackgroundColor3 = C.SHADOW, BackgroundTransparency = 1, Rotation = -4 })
	banner = text(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.fromOffset(800, 84), Font = TITLE_FONT, TextSize = 78, TextColor3 = WHITE, TextStrokeColor3 = C.SHADOW, TextTransparency = 1, TextStrokeTransparency = 1, Text = "", ZIndex = 3 })
	bannerGradient = gradient(banner, WHITE, colors.Cyan, 90)
	bannerSub = text(banner, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(600, 22), TextSize = 17, TextColor3 = C.GOLD, TextTransparency = 1, TextStrokeTransparency = 1, Text = "", ZIndex = 3 })
	for i, spot in ipairs({ { 0.2, -20 }, { 0.27, 25 }, { 0.73, -25 }, { 0.8, 20 } }) do
		local m = text(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(70, 70), TextSize = 56, Font = FONT, Text = "ゴ", TextTransparency = 1, TextStrokeTransparency = 0.6, TextStrokeColor3 = Color3.fromRGB(40, 0, 60), Rotation = (i % 2 == 0) and 12 or -12, ZIndex = 2 })
		m:SetAttribute("X", spot[1])
		m:SetAttribute("Y", spot[2])
		menacing[i] = m
	end

	-- MOVESET button (opens the Act menu), Studio only in Awaken mode.
	if TuskUI.menuAllowed() then
		local moveset = UITheme.button(gui, "TUSK ACTS (T)", C.WOOD_LIGHT, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 46), Size = UDim2.fromOffset(130, 30) })
		moveset.Activated:Connect(TuskUI.toggleMenu)

		buildMenu()
	end

	-- Scale the HUD down on small screens.
	local function rescale()
		local camera = workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
		hudScale.Scale = math.clamp(math.min(size.X / 760, size.Y / 560), 0.62, 1.15)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	-- Combo counter feeds on the attacker-only Damage event.
	Net.get("SpinFX").OnClientEvent:Connect(function(name)
		if name == "Damage" and hud.Visible then
			bumpCombo()
		end
	end)
	-- M1 card squash on click.
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and hud.Visible and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == TuskConfig.Keys.M1.Gamepad) then
			slots.M1.KeyDownAt = os.clock()
		end
	end)
end

-- Awaken mode: Acts come from ultimates, so the menu is only a Studio test tool.
function TuskUI.menuAllowed()
	local p = TuskConfig.Progression
	if not p.ShowSelectionMenu then
		return false
	end
	if p.Mode == "Awaken" then
		return RunService:IsStudio() and p.StudioMenu == true
	end
	return true
end

-- Ultimate awakened Tusk to the next Act.
function TuskUI.onEvolve(data)
	if data.Character ~= player.Character then
		return
	end
	local info = Registry.get(data.To)
	if info then
		showBanner(info.Name .. "!", "AWAKENED  ·  " .. info.Tagline:upper(), info.Theme.Primary, 2.6)
	end
end

function TuskUI.toggleMenu()
	if menu and TuskUI.menuAllowed() then
		menu.Visible = not menu.Visible
	end
end

---------------------------------------------------------------------------
-- Per-frame refresh and server messages
---------------------------------------------------------------------------
local function applyTheme(card)
	card.EdgeGradient.Color = ColorSequence.new(theme.Primary, theme.Secondary)
	card.Accent.BackgroundColor3 = theme.Primary
	card.Badge.BackgroundColor3 = theme.Primary
	card.GlowStroke.Color = theme.Primary
	card.ShadeEdge.BackgroundColor3 = theme.Primary
	card.ChargeFill.BackgroundColor3 = theme.Primary
	colorIcon(card.Icon, theme.Primary:Lerp(WHITE, 0.35))
end

local function refreshAct(act)
	shownAct = act
	hud.Visible = act ~= nil
	if not act then
		return
	end
	local info = Registry.get(act)
	theme = info.Theme
	actLabel.Text = info.Name
	nameSign.Size = UDim2.fromOffset(math.clamp(#info.Name * 14 + 40, 150, 300), 32)

	actGradient.Color = ColorSequence.new(WHITE, theme.Primary:Lerp(WHITE, 0.2))
	actBand.BackgroundColor3 = theme.Secondary
	taglineLabel.Text = info.Tagline:upper()
	slots.M1.Name.Text = info.M1
	for i = 1, 3 do
		slots[i].Name.Text = info.Abilities[i]
		slots[i].Kind = info.AbilityKinds and info.AbilityKinds[i] or "Press"
		drawIcon(slots[i].Icon, iconKind(info.Abilities[i]))
	end
	slots.Ult.Name.Text = info.Ultimate
	slots.Ult.MeterGradient.Color = ColorSequence.new(theme.Primary, theme.Secondary)
	for _, card in ipairs({ slots.M1, slots[1], slots[2], slots[3], slots.Ult }) do
		applyTheme(card)
	end
	awakenFill.BackgroundColor3 = theme.Primary
	-- Slide the hotbar in.
	animateJob("hudIn", 0.35, function(a)
		hud.Position = UDim2.new(0.5, 0, 1, -16 + (1 - VFXLib.easeOut(a)) * 60)
	end)
end

local function keyHeld(slotKey)
	local keys = TuskConfig.Keys[slotKey]
	if not keys or UserInputService:GetFocusedTextBox() then
		return false
	end
	local k = keys.Keyboard
	if typeof(k) == "EnumItem" and k.EnumType == Enum.KeyCode and UserInputService:IsKeyDown(k) then
		return true
	end
	local ok, down = pcall(function()
		return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, keys.Gamepad)
	end)
	return ok and down
end

-- The registry buff (if any) that is running on this slot right now.
local function buffFor(info, slot, character)
	local list = info.Buffs or (info.Buff and { info.Buff }) or {}
	for _, buff in ipairs(list) do
		local untilT = buff.Slot == slot and character:GetAttribute(buff.Attribute)
		if untilT and untilT > workspace:GetServerTimeNow() then
			return buff
		end
	end
	return nil
end

local function setKey(card, keyText)
	card.Key.Text = keyText
	card.Badge.Visible = keyText ~= ""
	card.Badge.Size = UDim2.fromOffset(math.max(22, #keyText * 8 + 12), 18)
end

local function stepCard(card, now, dt, cooling)
	-- Press squash + ready pop + hover.
	local target = (card.Pressed and 0.9 or 1) + (card.Pop or 0) + (card.Hover and 0.06 or 0)
	card.Scale.Scale = card.Scale.Scale + (target - card.Scale.Scale) * math.min(1, dt * 18)
	-- Cooldown shade.
	if cooling then
		local left = card.CooldownEnd - now
		card.Shade.Size = UDim2.fromScale(1, math.clamp(left / math.max(card.CooldownDur, 0.01), 0, 1))
		card.Timer.Text = left >= 10 and tostring(math.ceil(left)) or string.format("%.1f", left)
		colorIcon(card.Icon, GREY)
		card.Name.TextColor3 = NAME_FADED
		card.Badge.BackgroundColor3 = GREY
	elseif card.WasCooling then
		card.Shade.Size = UDim2.fromScale(1, 0)
		card.Timer.Text = ""
		colorIcon(card.Icon, theme.Primary:Lerp(WHITE, 0.35))
		card.Name.TextColor3 = NAME_INK
		card.Badge.BackgroundColor3 = theme.Primary
		readyFlash(card)
	end
	card.WasCooling = cooling
end

function TuskUI.step(act)
	if act ~= shownAct then
		refreshAct(act)
	end
	if not act then
		return
	end
	local now = os.clock()
	local dt = math.clamp(now - (TuskUI.LastStep or now), 0, 0.1)
	TuskUI.LastStep = now
	local info = Registry.get(act)
	local character = player.Character

	-- M1 card.
	setKey(slots.M1, keyName("M1"))
	slots.M1.Pressed = (slots.M1.KeyDownAt and now - slots.M1.KeyDownAt < 0.1) or false
	stepCard(slots.M1, now, dt, false)

	-- Ability cards.
	local chargeStart = character and character:GetAttribute("TuskCharge")
	local chargeMove = character and character:GetAttribute("TuskChargeMove")
	local actCfg = TuskConfig["Act" .. act]
	for i = 1, 3 do
		local card = slots[i]
		setKey(card, keyName("Ability" .. i))
		if keyHeld("Ability" .. i) then
			card.Pressed = true
			card.KeyPressed = true
		elseif card.KeyPressed then
			card.Pressed = false
			card.KeyPressed = false
		end
		stepCard(card, now, dt, card.CooldownEnd > now)
		-- Hold-move charge bar.
		local cfg = chargeMove and actCfg and actCfg[chargeMove]
		if chargeStart and card.Kind == "Hold" and cfg then
			local held = workspace:GetServerTimeNow() - chargeStart
			local full = cfg.FullChargeAt or (cfg.Stages and cfg.Stages[#cfg.Stages]) or cfg.MaxHold or 1.5
			local k = math.clamp(held / full, 0, 1)
			card.ChargeBack.Visible = true
			card.ChargeFill.Size = UDim2.fromScale(k, 1)
			if k >= 1 then
				local pulse = (math.sin(now * 14) + 1) / 2
				card.ChargeFill.BackgroundColor3 = theme.Primary:Lerp(WHITE, pulse)
				card.ChargeText.Text = "FULL!"
				card.GlowStroke.Transparency = 0.55 + pulse * 0.3
			else
				card.ChargeFill.BackgroundColor3 = theme.Primary
				card.ChargeText.Text = cfg.Stages and ("STAGE " .. (function()
					local stage = 0
					for s, t in ipairs(cfg.Stages) do
						if held >= t then
							stage = s
						end
					end
					return stage
				end)()) or ""
				card.GlowStroke.Transparency = 1
			end
		elseif character and buffFor(info, i, character) then
			-- Active buff (e.g. Scary Monsters, a commanded dinosaur): draining timer bar + glow.
			local buff = buffFor(info, i, character)
			local untilT = character:GetAttribute(buff.Attribute)
			local left = math.max(0, untilT - workspace:GetServerTimeNow())
			card.BuffMax = math.max(card.BuffMax or 0, left)
			card.ChargeBack.Visible = true
			card.ChargeFill.Size = UDim2.fromScale(left / math.max(card.BuffMax, 0.01), 1)
			card.ChargeFill.BackgroundColor3 = theme.Primary
			card.ChargeText.Text = (buff.Text or "ACTIVE") .. " " .. math.ceil(left) .. "s"
			card.GlowStroke.Transparency = 0.45 + (math.sin(now * 5) + 1) * 0.15
		elseif card.ChargeBack.Visible then
			card.ChargeBack.Visible = false
			card.GlowStroke.Transparency = 1
			card.BuffMax = nil
		end
	end

	-- Ultimate card.
	local ult = slots.Ult
	local max = TuskConfig.Ultimate.MaxMeter
	local meter = player:GetAttribute("TuskUlt") or 0
	ultShown = ultShown + (meter - ultShown) * math.min(1, dt * 8)
	local ready = meter >= max
	local since = player:GetAttribute("TuskActSince")
	local wait = TuskConfig.Ultimate.MinSecondsPerAct or 0
	local lockLeft = since and math.max(0, wait - (workspace:GetServerTimeNow() - since)) or 0
	setKey(ult, keyName("Ultimate"))
	ult.Meter.Size = UDim2.fromScale(1, math.clamp(ultShown / max, 0, 1))
	if ready and lockLeft > 0 then
		ult.Percent.Text = "LOCKED"
		ult.Timer.Text = math.ceil(lockLeft) .. "s"
		ult.MeterGradient.Color = ColorSequence.new(GREY, Color3.fromRGB(60, 62, 75))
		ult.EdgeGradient.Color = ColorSequence.new(GREY, Color3.fromRGB(60, 62, 75))
		ult.Pop = 0
		ult.GlowStroke.Transparency = 1
		ult.EdgeGradient.Rotation = 45
		colorIcon(ult.Icon, GREY)
	elseif ready then
		if not wasReady then
			readyFlash(ult)
			TuskUI.toast(info.Ultimate .. " READY!", theme.Primary)
		end
		local pulse = (math.sin(now * 6) + 1) / 2
		ult.Percent.Text = "READY"
		ult.Timer.Text = ""
		ult.MeterGradient.Color = ColorSequence.new(theme.Primary:Lerp(WHITE, pulse * 0.5), theme.Secondary)
		ult.GlowStroke.Transparency = 0.5 + pulse * 0.35
		ult.EdgeGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, theme.Secondary), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(1, theme.Secondary) })
		ult.EdgeGradient.Rotation = (now * 240) % 360 -- spinning shine on the border
		ult.Pop = 0.03 + pulse * 0.04
		colorIcon(ult.Icon, WHITE)
	else
		ult.EdgeGradient.Color = ColorSequence.new(theme.Primary, theme.Secondary)
		if wasReady then
			ult.Pop = 0
		end
		ult.Percent.Text = math.floor(ultShown / max * 100 + 0.5) .. "%"
		ult.Timer.Text = ""
		ult.MeterGradient.Color = ColorSequence.new(theme.Primary, theme.Secondary)
		ult.GlowStroke.Transparency = 1
		ult.EdgeGradient.Rotation = 45
		colorIcon(ult.Icon, theme.Primary:Lerp(WHITE, 0.35))
	end
	wasReady = ready and lockLeft <= 0
	if keyHeld("Ultimate") then
		ult.Pressed = true
		ult.KeyPressed = true
	elseif ult.KeyPressed then
		ult.Pressed = false
		ult.KeyPressed = false
	end
	stepCard(ult, now, dt, false)
	-- The rim stays theme-coloured; the brass plate turns gold when the ULT is ready.
	ult.PlateStroke.Color = (ready and lockLeft <= 0) and C.GOLD or C.BRASS

	-- Sneak chip.
	local sneaking = character and character:GetAttribute("TuskSneaking") == true
	local sp = slots.SneakParts
	-- Every character can sneak. While sneaking: HIDDEN, or SPOTTED! when an NPC has seen you.
	sneakChip.Visible = act ~= nil
	local spotted = sneaking and (character:GetAttribute("SpottedUntil") or 0) > workspace:GetServerTimeNow()
	local SPOT = Color3.fromRGB(255, 90, 80)
	sp.KeyText.Text = keyName("Sneak") ~= "" and keyName("Sneak") or "C"
	local tint = spotted and SPOT or theme.Primary
	sp.Stroke.Color = sneaking and tint or C.WOOD_EDGE
	sp.Key.BackgroundColor3 = sneaking and tint or SNEAK_IDLE
	sp.Text.TextColor3 = sneaking and tint:Lerp(WHITE, 0.25) or C.PAPER
	sp.Text.Text = spotted and "SPOTTED!" or (sneaking and "HIDDEN" or "SNEAK")
	sneakChip.BackgroundColor3 = sneaking and C.SHADOW or C.WOOD_DARK

	sneakHint.Visible = sneaking and sneakChip.Visible
	sneakHint.Text = Registry.characterOf(act) == "Johnny" and "M1 / TAP: SNEAK ATTACK" or "ATTACK: AMBUSH (+50% FIRST HIT)"
end

local function cooldown(slot, duration)
	local card = slots[slot]
	if not card then
		return
	end
	card.CooldownEnd = os.clock() + duration
	card.CooldownDur = duration
end

local DENY_TEXT = {
	Cooldown = "ON COOLDOWN",
	UltNotReady = "ULTIMATE NOT READY",
	GuardBroken = "GUARD BROKEN: CAN'T BLOCK YET",
	DashCooldown = "DASH ON COOLDOWN",
	NotAvailable = "THAT CHARACTER ISN'T INSTALLED",
	Locked = "ACT LOCKED",
	SwitchCooldown = "WAIT BEFORE SWITCHING ACTS",
	SneakCooldown = "SNEAK ON COOLDOWN",
	SneakAttackCooldown = "SNEAK ATTACK ON COOLDOWN",
	NoTarget = "NO TARGET IN FRONT",
	Blocked = "NO ROOM TO MOVE THERE",
	TooSoon = "TUSK ISN'T READY TO AWAKEN YET",
	NeedCorpse = "FIND A SAINT'S CORPSE PART FIRST",
	Silenced = "SILENCED: YOUR SOUND WAS PLUNDERED",
}

-- Wobble a card (denied input).
local function nudge(card)
	if not card then
		return
	end
	animateJob("nudge" .. card.Button.Name, 0.3, function(a)
		card.Button.Rotation = math.sin(a * 40) * 5 * (1 - a)
	end, function()
		card.Button.Rotation = 0
	end)
end

function TuskUI.onState(data)
	local kind = data.Kind
	if kind == "Cooldown" then
		cooldown(data.Slot, data.Duration)
	elseif kind == "Denied" then
		local msg = DENY_TEXT[data.Reason] or "CAN'T DO THAT"
		if data.Remaining then
			msg = msg .. string.format("  %.1fs", data.Remaining)
		end
		TuskUI.toast(msg)
		if data.Slot and slots[data.Slot] then
			nudge(slots[data.Slot])
		elseif data.Reason == "UltNotReady" or data.Reason == "TooSoon" then
			nudge(slots.Ult)
		end
	elseif kind == "Interrupted" then
		TuskUI.toast("INTERRUPTED!")
	elseif kind == "SneakAttackCooldown" then
		slots.SneakParts.Text.Text = "SNEAK"
	elseif kind == "Awakened" then
		local info = shownAct and Registry.get(shownAct)
		showBanner(info and info.Ultimate or "AWAKENED", "ABILITIES EMPOWERED", theme.Primary, 1.9)
		awakenBar.Visible = true
		animateJob("awaken", data.Duration, function(a)
			awakenFill.Size = UDim2.fromScale(1 - a, 1)
		end, function()
			awakenBar.Visible = false
		end)
	elseif kind == "AwakenEnded" then
		VFXLib.cancel(jobs.awaken)
		awakenBar.Visible = false
	elseif kind == "Equipped" then
		if data.Act and data.Act > 0 then
			local info = Registry.get(data.Act)
			TuskUI.toast(info.Name .. " EQUIPPED", info.Theme.Primary)
		end
	end
end

return TuskUI
end

-- ======================================================================
-- MODULE: TuskVFX
-- ======================================================================
__modules["TuskVFX"] = function()
--[[
	TuskVFX  (StarterPlayerScripts.SpinClient.TuskVFX)

	Reusable procedural VFX framework for every Tusk Act (built on VFXLib).
	Every function takes an options table; common options:
	  Duration, Radius/Size, Color, Color2, RotationSpeed (rad/s),
	  Particles (count multiplier), Transparency, Width
	Quality comes from VFXQuality automatically (segments, particles,
	optional layers). Every effect returns a handle with :Destroy() and
	cleans itself up when its Duration ends.

	  CreateSpinRing(opts)                 rotating energy ring (follows a target)
	  CreateMagicCircle(cframe, opts)      layered rings + star polygon
	  CreateEnergyCharge(opts)             growing core, accelerating rings, inward particles
	  CreateNailProjectile(opts)           nail + helix energy trails + optional rings
	  CreateRotationalShockwave(cf, opts)  layered spinning rings, ground disc, particles
	  CreateWormhole(cframe, opts)         opening, concentric rings, distorted interior, collapse
	  CreateGoldenAura(character, opts)    outline, orbiting rings, rising particles
	  CreateDistortion(position, opts)     refractive heat-haze sphere (High quality)
	  CreateImpact(position, normal, opts) staged impact: flash, shockwave, sparks, dust
	  CreateTuskTransformation(character, opts)  cinematic Act transformation
	  CreateImpactStar(position, opts)     tapered light rays bursting from a hit
	  CreateGroundCracks(position, opts)   glowing cracks torn into the ground
	  CreateEnergyPillar(position, opts)   column of energy shooting upward
	  CreateCrescent(cframe, opts)         tapered crescent slash that sweeps and fades
	  ScreenTint(duration, opts)           darken / tint the screen, then release
	  CreateGoldenSpiral(cframe, opts)     golden-ratio spiral of light, spinning up
	  CreateGoldenRectangle(cframe, opts)  nested golden rectangles + spiral
	  CleanupEffect(handle)
]]

local Debris = game:GetService("Debris")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local VFXQuality = __require("VFXQuality")
local NailModel = __require("NailModel")
local VFXLib = __require("VFXLib")

local TuskVFX = {}
local colors = TuskConfig.Colors
local LONG = 1e6 -- "until destroyed"

local function q()
	return VFXQuality.get()
end

function TuskVFX.CleanupEffect(handle)
	if handle and handle.Destroy then
		pcall(handle.Destroy, handle)
	end
end

local function fadeAlpha(a, fadeIn, fadeOut)
	if a < fadeIn then
		return 1 - a / fadeIn
	elseif a > 1 - fadeOut then
		return (a - (1 - fadeOut)) / fadeOut
	end
	return 0
end

---------------------------------------------------------------------------
-- Spin ring
---------------------------------------------------------------------------
function TuskVFX.CreateSpinRing(opts)
	local ring = VFXLib.ring({
		CFrame = opts.CFrame or CFrame.new(),
		Radius = opts.Radius or 2,
		Width = opts.Width or 0.15,
		Color = opts.Color or colors.Cyan,
		Transparency = 1,
		Segments = opts.Segments,
	})
	local handle = { Ring = ring, Angle = opts.StartAngle or 0, Speed = opts.RotationSpeed or 4, Alive = true }
	local baseT = opts.Transparency or 0.1
	local duration = opts.Duration
	handle.Job = VFXLib.animate(duration or LONG, function(a, dt)
		handle.Angle = handle.Angle + handle.Speed * (dt or 0)
		local base = opts.Follow and opts.Follow() or opts.CFrame
		if base then
			ring:SetCFrame(base * (opts.Tilt or CFrame.new()) * CFrame.Angles(0, handle.Angle, 0))
		end
		local fade = duration and fadeAlpha(a, 0.12, 0.3) or math.max(0, 1 - (a * LONG) / 0.15)
		ring:SetTransparency(baseT + (1 - baseT) * fade)
	end, function()
		handle.Alive = false
		ring:Destroy()
	end)
	function handle:SetRadius(r)
		ring:SetRadius(r)
	end
	function handle:SetColor(c)
		ring:SetColor(c)
	end
	function handle:SetWidth(w)
		ring:SetWidth(w)
	end
	function handle:Destroy()
		VFXLib.cancel(self.Job)
	end
	return handle
end

---------------------------------------------------------------------------
-- Magic circle: outer ring, inner ring and a star polygon of beams
---------------------------------------------------------------------------
function TuskVFX.CreateMagicCircle(cframe, opts)
	opts = opts or {}
	local radius = opts.Radius or 6
	local color = opts.Color or colors.Cyan
	local duration = opts.Duration or 2
	local points = opts.Points or 6
	local carrier = VFXLib.anchor(cframe)
	local attachments = {}
	for i = 1, points do
		local a = Instance.new("Attachment")
		a.Parent = carrier
		attachments[i] = a
	end
	local beams = {}
	local skip = points == 6 and 2 or 2
	for i = 1, points do
		local b = Instance.new("Beam")
		b.Attachment0 = attachments[i]
		b.Attachment1 = attachments[(i - 1 + skip) % points + 1]
		b.Color = ColorSequence.new(opts.Color2 or color)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Width0 = opts.Width or 0.18
		b.Width1 = opts.Width or 0.18
		b.FaceCamera = true
		b.Segments = 1
		b.Parent = carrier
		beams[i] = b
	end
	local outer = TuskVFX.CreateSpinRing({ CFrame = cframe, Radius = radius, Width = 0.25, Color = color, RotationSpeed = opts.RotationSpeed or 1, Duration = duration })
	local inner = TuskVFX.CreateSpinRing({ CFrame = cframe, Radius = radius * 0.72, Width = 0.15, Color = opts.Color2 or color, RotationSpeed = -(opts.RotationSpeed or 1) * 1.6, Duration = duration })
	local handle = { Outer = outer, Inner = inner }
	local angle = 0
	handle.Job = VFXLib.animate(duration, function(a, dt)
		angle = angle + (opts.RotationSpeed or 1) * 0.7 * (dt or 0)
		local open = VFXLib.easeOut(math.min(a / 0.2, 1))
		local r = radius * 0.7 * open
		for i, att in ipairs(attachments) do
			local th = angle + (i - 1) / points * math.pi * 2
			att.Position = Vector3.new(math.cos(th) * r, 0.02, math.sin(th) * r)
		end
		outer:SetRadius(radius * open)
		inner:SetRadius(radius * 0.72 * open)
		local fade = fadeAlpha(a, 0.1, 0.25)
		local seq = NumberSequence.new(0.1 + 0.9 * fade)
		for _, b in ipairs(beams) do
			b.Transparency = seq
		end
	end, function()
		carrier:Destroy()
	end)
	function handle:Destroy()
		VFXLib.cancel(self.Job)
		outer:Destroy()
		inner:Destroy()
	end
	return handle
end

---------------------------------------------------------------------------
-- Energy charge: core sphere + accelerating rings + particles pulled inward
---------------------------------------------------------------------------
function TuskVFX.CreateEnergyCharge(opts)
	local color = opts.Color or colors.Cyan
	local color2 = opts.Color2 or colors.Ice
	local maxRadius = opts.MaxRadius or 1.4
	local ringCount = math.min(opts.Rings or 3, 3)
	local follow = opts.Follow
	local handle = { Progress = 0, Rings = {} }

	local core = VFXLib.part({ Shape = Enum.PartType.Ball, Color = color2, Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 0.15 })
	local light
	if q().Lights then
		light = Instance.new("PointLight")
		light.Color = color
		light.Range = 8
		light.Brightness = 0
		light.Shadows = false
		light.Parent = core
	end

	-- Shell emitter: particles spawn on a sphere surface and fly inward.
	local shell = VFXLib.part({ Shape = Enum.PartType.Ball, Transparency = 1, Size = Vector3.new(maxRadius * 3, maxRadius * 3, maxRadius * 3) })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Sparkle
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Color = ColorSequence.new(color2, color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0), NumberSequenceKeypoint.new(1, 0.4) })
	emitter.Lifetime = NumberRange.new(0.35, 0.45)
	emitter.Speed = NumberRange.new(maxRadius * 3.2, maxRadius * 3.6)
	emitter.Rate = 0
	emitter.Parent = shell

	for i = 1, ringCount do
		handle.Rings[i] = TuskVFX.CreateSpinRing({
			Follow = function()
				return core.CFrame
			end,
			Tilt = CFrame.Angles(0.6 * i, 0, 0.9 * i),
			Radius = 0.1,
			Width = 0.08,
			Color = i == 1 and color2 or color,
			RotationSpeed = 3 + i * 1.5,
			Transparency = 0.15,
		})
	end

	local duration = opts.Duration or 1.2
	local manual = opts.Manual == true
	handle.Job = VFXLib.animate(LONG, function(a, dt)
		local cf = follow and follow() or opts.CFrame
		if not cf then
			return
		end
		local elapsed = a * LONG
		if not manual then
			handle.Progress = math.min(elapsed / duration, 1)
		end
		local p = handle.Progress
		local pulse = 1 + math.sin(elapsed * 18) * 0.06 * p
		local coreSize = (0.25 + p * maxRadius * 0.6) * pulse
		core.CFrame = cf
		core.Size = Vector3.new(coreSize, coreSize, coreSize)
		shell.CFrame = cf
		emitter.Rate = (10 + p * 50) * q().Particles * (opts.Particles or 1)
		if light then
			light.Brightness = 1 + p * 3
		end
		for i, ring in ipairs(handle.Rings) do
			ring.Speed = (3 + i * 1.5) * (1 + p * 3) -- rings accelerate as energy builds
			ring:SetRadius(0.3 + p * maxRadius * (0.55 + i * 0.22))
		end
		if handle.OnStep then
			handle.OnStep(p, cf)
		end
	end, function()
		core:Destroy()
		shell:Destroy()
		for _, ring in ipairs(handle.Rings) do
			ring:Destroy()
		end
	end)

	function handle:SetProgress(p)
		self.Progress = math.clamp(p, 0, 1)
	end
	function handle:Destroy()
		VFXLib.cancel(self.Job)
	end
	-- Bright flash + outward burst, then cleanup.
	function handle:Release(direction)
		local pos = core.Position
		VFXLib.burst(pos, { Count = 20, Color = color2, Speed = 22, Lifetime = 0.35, Direction = direction, Spread = direction and 35 or 180 })
		VFXLib.flash(pos, color, 6, 14, 0.25)
		local flash = VFXLib.part({ Shape = Enum.PartType.Ball, Color = colors.Ice, Size = core.Size, CFrame = core.CFrame, Transparency = 0 })
		local s0 = core.Size.X
		VFXLib.animate(0.15, function(a)
			local s = s0 * (1 + a * 2.5)
			flash.Size = Vector3.new(s, s, s)
			flash.Transparency = a
		end, function()
			flash:Destroy()
		end)
		self:Destroy()
	end
	return handle
end

---------------------------------------------------------------------------
-- Nail projectile visual (pooled nails)
---------------------------------------------------------------------------
local nailPool = {}

local function takeNail(scale)
	local nail = table.remove(nailPool)
	if not nail then
		nail = NailModel.build(1.3)
		nail.PrimaryPart.Anchored = true
	end
	nail:ScaleTo(scale)
	return nail
end

local function returnNail(nail)
	nail.Parent = nil
	if #nailPool < 16 then
		table.insert(nailPool, nail)
	else
		nail:Destroy()
	end
end

local function trailBetween(parent, a0, a1, color, color2, lifetime, transparency)
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = ColorSequence.new(color, color2 or color)
	t.LightEmission = 1
	t.LightInfluence = 0
	t.Lifetime = lifetime
	t.FaceCamera = true
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, transparency or 0), NumberSequenceKeypoint.new(1, 1) })
	t.WidthScale = NumberSequence.new(1, 0.2)
	t.Parent = parent
	return t
end

-- A Spin whirl: spiral arms of beams around an axis (the carrier's local Z),
-- cyan at the centre fading to blue at the tips. Spin it by rotating the carrier.
local function createWhirl(radius, color, color2, arms, points)
	local carrier = VFXLib.anchor(CFrame.new())
	local beams = {}
	for arm = 0, arms - 1 do
		local prev
		for i = 0, points do
			local t = i / points
			local angle = arm / arms * math.pi * 2 + t * math.pi * 1.6
			local r = radius * (0.25 + t * 0.75)
			local a = Instance.new("Attachment")
			a.Position = Vector3.new(math.cos(angle) * r, math.sin(angle) * r, t * radius * 0.35)
			a.Parent = carrier
			if prev then
				local b = Instance.new("Beam")
				b.Attachment0 = prev
				b.Attachment1 = a
				b.FaceCamera = true
				b.LightEmission = 1
				b.LightInfluence = 0
				b.Segments = 1
				local c = color:Lerp(color2, t)
				b.Color = ColorSequence.new(c)
				b.Width0 = radius * 0.16 * (1 - t * 0.6)
				b.Width1 = radius * 0.16 * (1 - (t + 1 / points) * 0.6)
				b.Transparency = NumberSequence.new(0.05 + t * 0.6, 0.05 + math.min(1, t + 1 / points) * 0.6)
				b.Parent = carrier
				table.insert(beams, b)
			end
			prev = a
		end
	end
	return carrier
end

--[[
	opts: Scale, Color, Color2 (helix), TrailColor, Rings (0..3), RingColor,
	      Whirls (0..3) + WhirlColor / WhirlColor2: spinning Spin whirls
	      Glow (true): cyan neon glow sleeve around the nail
	      HelixRadius, Helix (strand count), Afterimages, SpinSpeed
	visual:Step(cframe, dt)  visual:Destroy()
]]
function TuskVFX.CreateNailProjectile(opts)
	local scale = opts.Scale or 1
	local nail = takeNail(scale)
	nail.Parent = VFXLib.Folder

	-- Carrier rotates around the flight axis; attachments on it draw helix trails.
	local carrier = VFXLib.anchor(CFrame.new())
	local trails = {}
	local helixRadius = (opts.HelixRadius or 0.35) * scale
	local strands = opts.Helix or 2
	for i = 1, strands do
		local th = (i - 1) / strands * math.pi * 2
		local dir = Vector3.new(math.cos(th), math.sin(th), 0)
		local a0 = Instance.new("Attachment")
		a0.Position = dir * helixRadius
		a0.Parent = carrier
		local a1 = Instance.new("Attachment")
		a1.Position = dir * (helixRadius + 0.08 * scale)
		a1.Parent = carrier
		table.insert(trails, trailBetween(carrier, a0, a1, opts.Color2 or colors.Cyan, opts.Color or colors.Blue, 0.22, 0.05))
	end
	-- Thin core trail straight behind the nail.
	local c0 = Instance.new("Attachment")
	c0.Position = Vector3.new(0, 0.05 * scale, 0)
	c0.Parent = carrier
	local c1 = Instance.new("Attachment")
	c1.Position = Vector3.new(0, -0.05 * scale, 0)
	c1.Parent = carrier
	table.insert(trails, trailBetween(carrier, c0, c1, opts.TrailColor or colors.Blue, colors.DeepBlue, 0.35 * (opts.TrailLength or 1), 0))

	local rings = {}
	for i = 1, (opts.Rings or 0) do
		rings[i] = VFXLib.ring({ Radius = (0.35 + i * 0.22) * scale, Width = 0.08 * scale, Color = opts.RingColor or colors.Cyan, Transparency = 0.1 })
	end

	-- Glowing cyan sleeve around the nail.
	local glow
	if opts.Glow then
		glow = VFXLib.part({ Color = opts.GlowColor or colors.Cyan, Transparency = 0.45, Size = Vector3.new(0.32, 0.32, 1.6) * scale })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = glow
	end
	-- Spin whirls that keep spinning around the flight path.
	local whirls = {}
	local whirlCount = opts.Whirls or 0
	if q().RingSegments <= 12 then
		whirlCount = math.min(whirlCount, 1)
	end
	for i = 1, whirlCount do
		whirls[i] = createWhirl((0.55 + i * 0.22) * scale, opts.WhirlColor or colors.Cyan, opts.WhirlColor2 or colors.Blue, 3, q().RingSegments > 12 and 6 or 4)
	end

	local visual = { Spin = 0, NextGhost = 0, Alive = true }
	function visual:Step(cframe, dt)
		self.Spin = self.Spin + (dt or 0) * (opts.SpinSpeed or 30)
		nail:PivotTo(cframe * CFrame.Angles(0, 0, self.Spin))
		if glow then
			local pulse = 1 + math.sin(self.Spin * 0.6) * 0.12
			glow.CFrame = cframe * CFrame.new(0, 0, 0.1 * scale)
			glow.Size = Vector3.new(0.32 * pulse, 0.32 * pulse, 1.6) * scale
		end
		for i, whirl in ipairs(whirls) do
			-- Each whirl sits a little further back and spins the opposite way.
			local dir = i % 2 == 1 and 1 or -1
			whirl.CFrame = cframe * CFrame.new(0, 0, (0.15 + (i - 1) * 0.55) * scale) * CFrame.Angles(0, 0, self.Spin * 0.45 * dir)
		end
		carrier.CFrame = cframe * CFrame.new(0, 0, 0.5 * scale) * CFrame.Angles(0, 0, self.Spin * 0.5)
		for i, ring in ipairs(rings) do
			local tilt = 0.4 * i
			ring:SetCFrame(cframe * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.Angles(tilt * math.sin(self.Spin * 0.2 + i), self.Spin * (0.3 + i * 0.15), tilt))
		end
		if opts.Afterimages and q().Afterimages and os.clock() >= self.NextGhost then
			self.NextGhost = os.clock() + 0.045
			VFXLib.afterimage(cframe, 0.35 * scale, opts.RingColor or colors.Cyan)
		end
	end
	function visual:Destroy()
		if not self.Alive then
			return
		end
		self.Alive = false
		returnNail(nail)
		if glow then
			glow:Destroy()
		end
		for _, whirl in ipairs(whirls) do
			whirl:Destroy()
		end
		for _, ring in ipairs(rings) do
			ring:Destroy()
		end
		for _, t in ipairs(trails) do
			t.Enabled = false
		end
		Debris:AddItem(carrier, 0.5)
	end
	return visual
end

---------------------------------------------------------------------------
-- Rotational shockwave
---------------------------------------------------------------------------
--[[ cf: UpVector = shockwave axis. opts: Radius, Color, Color2, Layers,
     Duration, Spin, Ground (disc), Particles, Width ]]
function TuskVFX.CreateRotationalShockwave(cf, opts)
	opts = opts or {}
	local layers = opts.Layers or 2
	if q().RingSegments <= 12 then
		layers = math.min(layers, 2)
	end
	local radius = opts.Radius or 8
	for i = 1, layers do
		task.delay((i - 1) * (opts.Stagger or 0.045), function()
			VFXLib.shockwave(cf * CFrame.Angles(0, i * 0.7, 0), {
				StartRadius = radius * 0.1,
				Radius = radius * (1 - (i - 1) * 0.22),
				Width = (opts.Width or 0.5) * (1 - (i - 1) * 0.2),
				Duration = (opts.Duration or 0.45) + i * 0.05,
				Color = (i % 2 == 1) and (opts.Color or colors.Cyan) or (opts.Color2 or colors.Blue),
				Spin = (opts.Spin or 2) * (i % 2 == 1 and 1 or -1),
			})
		end)
	end
	if opts.Ground then
		VFXLib.groundDisc(cf.Position, cf.UpVector, { Radius = radius * 0.6, Color = opts.Color2 or opts.Color or colors.Cyan, Duration = opts.Duration or 0.4 })
	end
	if (opts.Particles or 1) > 0 then
		VFXLib.burst(cf.Position, {
			Count = 16 * (opts.Particles or 1),
			Color = opts.Color or colors.Cyan,
			Speed = radius * 3,
			Lifetime = 0.45,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }),
		})
	end
end

---------------------------------------------------------------------------
-- Distortion (refraction haze). Glass refracts on higher graphics levels.
---------------------------------------------------------------------------
function TuskVFX.CreateDistortion(position, opts)
	opts = opts or {}
	if not q().ImpactFrames or not VFXLib.acquire() then
		return
	end
	local radius = opts.Radius or 4
	local sphere = VFXLib.part({
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Glass,
		Color = opts.Color or colors.Ice,
		Transparency = 0.6,
		Size = Vector3.new(0.5, 0.5, 0.5),
		CFrame = CFrame.new(position),
	})
	VFXLib.animate(opts.Duration or 0.35, function(a)
		local d = 0.5 + radius * 2 * VFXLib.easeOut(a)
		sphere.Size = Vector3.new(d, d, d)
		sphere.Transparency = 0.6 + 0.4 * a
	end, function()
		sphere:Destroy()
		VFXLib.release()
	end)
end

---------------------------------------------------------------------------
-- Staged impact: flash -> primary shockwave -> sparks -> dust (recovery)
---------------------------------------------------------------------------
function TuskVFX.CreateImpact(position, normal, opts)
	opts = opts or {}
	normal = normal or Vector3.new(0, 1, 0)
	local color = opts.Color or colors.Cyan
	local size = opts.Size or 1
	-- 1. impact flash
	local flash = VFXLib.part({ Shape = Enum.PartType.Ball, Color = colors.Ice, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(position) })
	VFXLib.animate(0.12, function(a)
		local d = 0.5 + 3 * size * a
		flash.Size = Vector3.new(d, d, d)
		flash.Transparency = a
	end, function()
		flash:Destroy()
	end)
	VFXLib.flash(position, color, 3 + size * 2, 10 + size * 6, 0.3)
	if opts.Star ~= false then
		TuskVFX.CreateImpactStar(position, { Size = 2.6 * size, Color = color, Color2 = colors.Ice, Duration = 0.2 + size * 0.05 })
	end
	-- 2. primary shockwave around the surface normal
	local axis = CFrame.lookAt(position, position + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
	TuskVFX.CreateRotationalShockwave(axis, {
		Radius = (opts.Radius or 4) * size,
		Layers = opts.Layers or 2,
		Color = color,
		Color2 = opts.Color2 or colors.Blue,
		Ground = normal.Y > 0.6 and opts.Ground ~= false,
		Particles = 0,
		Width = 0.3 * size,
	})
	-- 3. secondary sparks
	VFXLib.burst(position, {
		Count = math.floor(12 * size),
		Color = opts.Color2 or colors.Ice,
		Speed = 30 * size,
		Lifetime = 0.4,
		Drag = 2,
		Acceleration = Vector3.new(0, -40, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) }),
		Direction = normal,
		Spread = 70,
	})
	-- 4. recovery dust
	if normal.Y > 0.6 then
		VFXLib.burst(position, {
			Count = math.floor(4 * size),
			Texture = VFXLib.Textures.Smoke,
			Color = Color3.fromRGB(196, 170, 125),
			LightEmission = 0,
			Speed = 6,
			Lifetime = 1,
			Drag = 3,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5 * size), NumberSequenceKeypoint.new(1, 4 * size) }),
			TransparencySeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		})
	end
	if opts.Sound then
		VFXLib.sound(opts.Sound, position, 0.6, opts.Pitch or 1)
	end
end

---------------------------------------------------------------------------
-- Wormhole portal
---------------------------------------------------------------------------
--[[ cframe: portal faces cframe.LookVector. opts: Radius, Color, Color2,
     Duration (hold time), OpenTime, CloseTime.  handle:Close() ]]
function TuskVFX.CreateWormhole(cframe, opts)
	opts = opts or {}
	local radius = opts.Radius or 3
	local color = opts.Color or colors.Cyan
	local color2 = opts.Color2 or colors.DeepBlue
	local openTime = opts.OpenTime or 0.25
	local closeTime = opts.CloseTime or 0.22
	-- Ring axis must be the portal facing: rotate so the ring's Up = LookVector.
	local axis = cframe * CFrame.Angles(math.pi / 2, 0, 0)

	local handle = { Scale = 0, Closing = false }
	local rings = {}
	local ringDefs = { { 1, 3, 0.22 }, { 0.82, -4.5, 0.14 }, { 0.62, 6, 0.1 } }
	for i, def in ipairs(ringDefs) do
		if i < 3 or q().RingSegments > 12 then
			rings[i] = TuskVFX.CreateSpinRing({ CFrame = axis, Radius = 0.1, Width = def[3], Color = i == 1 and color or colors.Ice, RotationSpeed = def[2], Transparency = 0.05 })
		end
	end
	-- Distorted interior: ForceField material shimmers; dark core gives depth.
	local interior = VFXLib.part({
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.ForceField,
		Color = color,
		Transparency = 0,
		Size = Vector3.new(0.05, 0.1, 0.1),
	})
	local core = VFXLib.part({
		Shape = Enum.PartType.Cylinder,
		Color = color2,
		Transparency = 0.15,
		Size = Vector3.new(0.04, 0.1, 0.1),
	})
	-- Cylinder axis is X; turn it to face the portal direction.
	local discCF = cframe * CFrame.Angles(0, math.pi / 2, 0)
	interior.CFrame = discCF
	core.CFrame = discCF * CFrame.new(0.05, 0, 0)

	-- Particles pulled inward from the rim.
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Sparkle
	emitter.Shape = Enum.ParticleEmitterShape.Cylinder
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Color = ColorSequence.new(colors.Ice, color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.3, 0.4)
	emitter.Speed = NumberRange.new(radius * 2.5, radius * 3)
	emitter.Rate = 30 * q().Particles
	emitter.Parent = interior

	local light
	if q().Lights then
		light = Instance.new("PointLight")
		light.Color = color
		light.Range = radius * 4
		light.Brightness = 3
		light.Shadows = false
		light.Parent = core
	end

	local function apply(s)
		for i, def in ipairs(ringDefs) do
			if rings[i] then
				rings[i]:SetRadius(math.max(radius * def[1] * s, 0.05))
			end
		end
		local d = math.max(radius * 1.8 * s, 0.1)
		interior.Size = Vector3.new(0.05, d, d)
		core.Size = Vector3.new(0.04, d * 0.75, d * 0.75)
	end
	apply(0)

	handle.Job = VFXLib.animate(LONG, function(a)
		local t = a * LONG
		if not handle.Closing then
			-- Overshoot ease on open, gentle breathing while held.
			local o = math.min(t / openTime, 1)
			local s = o < 1 and (1 - (1 - o) ^ 3) * (1 + 0.15 * math.sin(o * math.pi)) or 1 + math.sin(t * 6) * 0.03
			apply(s)
		end
	end, function()
		for _, ring in pairs(rings) do
			ring:Destroy()
		end
		interior:Destroy()
		core:Destroy()
	end)

	function handle:Close()
		if self.Closing then
			return
		end
		self.Closing = true
		emitter.Rate = 0
		local pos = cframe.Position
		VFXLib.animate(closeTime, function(a)
			apply(1 - VFXLib.easeInOut(a))
			if light then
				light.Brightness = 3 + a * 4
			end
		end, function()
			VFXLib.burst(pos, { Count = 14, Color = colors.Ice, Speed = 14, Lifetime = 0.3 })
			VFXLib.cancel(self.Job)
		end)
	end
	function handle:Destroy()
		VFXLib.cancel(self.Job)
	end
	if opts.Duration then
		task.delay(openTime + opts.Duration, function()
			handle:Close()
		end)
	end
	return handle
end

---------------------------------------------------------------------------
-- Aura (gold for Act 4; cyan/blue for Act 1 Awakened)
---------------------------------------------------------------------------
function TuskVFX.CreateGoldenAura(character, opts)
	opts = opts or {}
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return { Destroy = function() end }
	end
	local color = opts.Color or colors.Gold
	local color2 = opts.Color2 or colors.DeepBlue
	local handle = { Rings = {} }

	local highlight = Instance.new("Highlight")
	highlight.Adornee = character
	highlight.FillColor = color
	highlight.FillTransparency = 0.85
	highlight.OutlineColor = color
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = VFXLib.Folder

	local attachment = Instance.new("Attachment")
	attachment.Name = "TuskAura"
	attachment.Position = Vector3.new(0, -1, 0)
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Sparkle
	emitter.Color = ColorSequence.new(color, color2)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Acceleration = Vector3.new(0, 4, 0)
	emitter.Rate = 18 * q().Particles * (opts.Particles or 1)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = attachment

	for i = 1, (opts.Rings or 2) do
		handle.Rings[i] = TuskVFX.CreateSpinRing({
			Follow = function()
				return root.Parent and root.CFrame * CFrame.new(0, -2.6 + i * 1.2, 0) or nil
			end,
			Tilt = CFrame.Angles(0.25 * (i % 2 == 0 and 1 or -1), 0, 0.15),
			Radius = 2.4 - i * 0.3,
			Width = 0.12,
			Color = i % 2 == 1 and color or color2,
			RotationSpeed = (2.5 + i) * (i % 2 == 0 and -1 or 1),
			Transparency = 0.25,
		})
	end
	function handle:Destroy()
		highlight:Destroy()
		attachment:Destroy()
		for _, ring in ipairs(self.Rings) do
			ring:Destroy()
		end
	end
	return handle
end

---------------------------------------------------------------------------
-- Cinematic transformation (used by Act ultimates)
---------------------------------------------------------------------------
--[[ opts: Duration, Color, Color2, OnManifest() called at ~55%,
     OnBurst() called at the end. ]]
function TuskVFX.CreateTuskTransformation(character, opts)
	opts = opts or {}
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local duration = opts.Duration or 1.7
	local color = opts.Color or colors.Cyan
	local color2 = opts.Color2 or colors.Blue
	local groundCF = CFrame.new(root.Position - Vector3.new(0, 2.9, 0))

	-- Stage 1: layered magic circles open at the feet.
	TuskVFX.CreateMagicCircle(groundCF, { Radius = 7, Color = color, Color2 = colors.Ice, Duration = duration + 0.4, RotationSpeed = 1.2, Points = 6 })
	if q().RingSegments > 12 then
		TuskVFX.CreateMagicCircle(groundCF * CFrame.new(0, 0.05, 0), { Radius = 4.2, Color = color2, Duration = duration + 0.4, RotationSpeed = -2, Points = 5 })
	end

	-- Stage 2: rising energy column.
	local column = VFXLib.part({ Shape = Enum.PartType.Cylinder, Transparency = 1, Size = Vector3.new(0.1, 6, 6), CFrame = groundCF * CFrame.Angles(0, 0, math.pi / 2) })
	local rise = Instance.new("ParticleEmitter")
	rise.Texture = VFXLib.Textures.Sparkle
	rise.Shape = Enum.ParticleEmitterShape.Disc
	rise.Color = ColorSequence.new(colors.Ice, color)
	rise.LightEmission = 1
	rise.LightInfluence = 0
	rise.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	rise.Lifetime = NumberRange.new(0.6, 1)
	rise.Speed = NumberRange.new(8, 14)
	rise.EmissionDirection = Enum.NormalId.Right -- cylinder X axis = world up here
	rise.Rate = 40 * q().Particles
	rise.Parent = column
	Debris:AddItem(column, duration + 1.2)

	-- Stage 3: energy gathers at the chest.
	local charge = TuskVFX.CreateEnergyCharge({
		Follow = function()
			return root.Parent and root.CFrame * CFrame.new(0, 1, -1.2) or nil
		end,
		Color = color,
		Color2 = colors.Ice,
		MaxRadius = 1.6,
		Duration = duration * 0.9,
		Rings = 3,
	})

	task.delay(duration * 0.55, function()
		if opts.OnManifest then
			opts.OnManifest()
		end
	end)
	task.delay(duration, function()
		rise.Rate = 0
		charge:Release()
		-- Stage 4: burst
		TuskVFX.CreateRotationalShockwave(groundCF, { Radius = 20, Layers = 3, Color = color, Color2 = colors.Ice, Ground = true, Particles = 2, Width = 0.8, Duration = 0.6 })
		TuskVFX.CreateDistortion(root.Position, { Radius = 8, Duration = 0.4 })
		VFXLib.burst(root.Position, { Count = 40, Color = colors.Ice, Speed = 50, Lifetime = 0.6 })
		VFXLib.flash(root.Position, color, 10, 40, 0.5)
		if opts.OnBurst then
			opts.OnBurst()
		end
	end)
end

---------------------------------------------------------------------------
-- Impact star: tapered rays of light bursting out of a hit point.
---------------------------------------------------------------------------
--[[ opts: Size (ray length), Rays, Color, Color2, Duration, Width ]]
function TuskVFX.CreateImpactStar(position, opts)
	opts = opts or {}
	if not VFXLib.acquire() then
		return
	end
	local size = opts.Size or 4
	local rays = opts.Rays or (q().RingSegments > 12 and 10 or 6)
	local duration = opts.Duration or 0.28
	local width = opts.Width or size * 0.16
	local carrier = VFXLib.anchor(CFrame.new(position))
	local center = Instance.new("Attachment")
	center.Parent = carrier
	local tips = {}
	local beams = {}
	local color = ColorSequence.new(opts.Color2 or Color3.new(1, 1, 1), opts.Color or colors.Cyan)
	for i = 1, rays do
		-- Random direction, biased so most rays splay sideways (reads as a star).
		local dir = Vector3.new(math.random() * 2 - 1, (math.random() * 2 - 1) * 0.7, math.random() * 2 - 1)
		if dir.Magnitude < 0.05 then
			dir = Vector3.new(1, 0, 0)
		end
		local tip = Instance.new("Attachment")
		tip.Parent = carrier
		tips[i] = { Attachment = tip, Dir = dir.Unit, Length = size * (0.55 + math.random() * 0.6) }
		local b = Instance.new("Beam")
		b.Attachment0 = center
		b.Attachment1 = tip
		b.Color = color
		b.LightEmission = 1
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Segments = 1
		b.Width0 = width * (0.7 + math.random() * 0.6)
		b.Width1 = 0
		b.Parent = carrier
		beams[i] = b
	end
	VFXLib.animate(duration, function(a)
		local grow = VFXLib.easeOut(math.min(a / 0.3, 1))
		for _, t in ipairs(tips) do
			t.Attachment.Position = t.Dir * t.Length * grow
		end
		local fade = NumberSequence.new(math.clamp((a - 0.35) / 0.65, 0, 1))
		for _, b in ipairs(beams) do
			b.Transparency = fade
		end
	end, function()
		carrier:Destroy()
		VFXLib.release()
	end)
end

---------------------------------------------------------------------------
-- Ground cracks: jagged dark fissures with a glowing seam, fading out.
---------------------------------------------------------------------------
--[[ opts: Radius, Count, Color (glow), Duration, Ignore (instances) ]]
function TuskVFX.CreateGroundCracks(position, opts)
	opts = opts or {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { VFXLib.Folder }
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	for _, extra in ipairs(opts.Ignore or {}) do
		table.insert(ignore, extra)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), params)
	if not hit or hit.Normal.Y < 0.6 then
		return -- no flat ground under the impact
	end
	local ground = hit.Position + Vector3.new(0, 0.03, 0)
	local radius = opts.Radius or 8
	local count = opts.Count or (q().RingSegments > 12 and 9 or 5)
	local glowColor = opts.Color or colors.Cyan
	local duration = opts.Duration or 1.6
	local pieces = {}
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.6
		local point = ground + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * 0.12
		local length = radius * (0.6 + math.random() * 0.4)
		local steps = 4
		local width = 0.55
		for _ = 1, steps do
			angle = angle + (math.random() - 0.5) * 0.9
			local seg = length / steps
			local nextPoint = point + Vector3.new(math.cos(angle), 0, math.sin(angle)) * seg
			local cf = CFrame.lookAt(point:Lerp(nextPoint, 0.5), nextPoint)
			local crack = VFXLib.part({ Material = Enum.Material.Slate, Color = Color3.fromRGB(40, 32, 28), Size = Vector3.new(width, 0.08, seg + 0.2), CFrame = cf })
			local seam = VFXLib.part({ Color = glowColor, Size = Vector3.new(width * 0.35, 0.1, seg + 0.1), CFrame = cf * CFrame.new(0, 0.02, 0), Transparency = 0.1 })
			table.insert(pieces, { Part = crack, Base = 0 })
			table.insert(pieces, { Part = seam, Base = 0.1, Seam = true })
			point = nextPoint
			width = width * 0.72
		end
	end
	-- Chunks of debris kicked up from the cracks.
	VFXLib.burst(ground, {
		Count = math.floor(radius * 1.5),
		Texture = VFXLib.Textures.Smoke,
		Color = Color3.fromRGB(150, 128, 100),
		LightEmission = 0,
		Speed = radius * 1.2,
		Lifetime = 0.9,
		Drag = 3,
		Direction = Vector3.new(0, 1, 0),
		Spread = 80,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) }),
		TransparencySeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
	})
	VFXLib.animate(duration, function(a)
		for _, piece in ipairs(pieces) do
			if piece.Seam then
				-- The seam glows hot, then cools faster than the crack fades.
				piece.Part.Transparency = math.min(1, piece.Base + a * 1.4)
			else
				piece.Part.Transparency = math.clamp((a - 0.6) / 0.4, 0, 1)
			end
		end
	end, function()
		for _, piece in ipairs(pieces) do
			piece.Part:Destroy()
		end
	end)
end

---------------------------------------------------------------------------
-- Energy pillar: a column of light that shoots up and thins out.
---------------------------------------------------------------------------
--[[ opts: Radius, Height, Color, Color2 (outer sheath), Duration ]]
function TuskVFX.CreateEnergyPillar(position, opts)
	opts = opts or {}
	local radius = opts.Radius or 6
	local height = opts.Height or 60
	local duration = opts.Duration or 0.65
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local core = VFXLib.part({ Shape = Enum.PartType.Cylinder, Color = opts.Color or colors.Ice, Transparency = 0.05, Size = Vector3.new(1, radius, radius), CFrame = CFrame.new(position) * upright })
	local sheath
	if q().RingSegments > 12 then
		sheath = VFXLib.part({ Shape = Enum.PartType.Cylinder, Color = opts.Color2 or colors.Cyan, Material = Enum.Material.ForceField, Transparency = 0.2, Size = Vector3.new(1, radius * 1.6, radius * 1.6), CFrame = CFrame.new(position) * upright })
	end
	VFXLib.animate(duration, function(a)
		local h = 2 + height * VFXLib.easeOut(a)
		local d = radius * (1 - a * 0.7)
		local cf = CFrame.new(position + Vector3.new(0, h / 2, 0)) * upright
		core.Size = Vector3.new(h, d, d)
		core.CFrame = cf
		core.Transparency = 0.05 + 0.95 * a
		if sheath then
			sheath.Size = Vector3.new(h * 0.9, d * 1.7, d * 1.7)
			sheath.CFrame = cf * CFrame.Angles(a * 6, 0, 0)
			sheath.Transparency = 0.2 + 0.8 * a
		end
	end, function()
		core:Destroy()
		if sheath then
			sheath:Destroy()
		end
	end)
end

---------------------------------------------------------------------------
-- Crescent slash: a tapered arc (thin at both tips, thick in the middle)
-- that sweeps across and fades. Lies in cframe's local XZ plane.
---------------------------------------------------------------------------
--[[ opts: Radius, Width, Arc (radians), Sweep (radians turned while alive),
     Color, Color2 (inner edge), Duration ]]
function TuskVFX.CreateCrescent(cframe, opts)
	opts = opts or {}
	if not VFXLib.acquire() then
		return
	end
	local radius = opts.Radius or 2.4
	local width = opts.Width or 0.45
	local arc = opts.Arc or math.rad(150)
	local sweep = opts.Sweep or 1.6
	local duration = opts.Duration or 0.2
	local points = q().RingSegments > 12 and 12 or 7
	local carrier = VFXLib.anchor(cframe)
	local attachments = {}
	for i = 0, points do
		local th = -arc / 2 + arc * i / points
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(math.sin(th) * radius, 0, -math.cos(th) * radius)
		a.Parent = carrier
		attachments[i] = a
	end
	local beams = {}
	local color = ColorSequence.new(opts.Color2 or Color3.new(1, 1, 1), opts.Color or colors.Cyan)
	for i = 1, points do
		local b = Instance.new("Beam")
		b.Attachment0 = attachments[i - 1]
		b.Attachment1 = attachments[i]
		b.Color = color
		b.LightEmission = 1
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Segments = 1
		-- sin profile: 0 at the tips, full width in the middle
		b.Width0 = width * math.sin(math.pi * (i - 1) / points)
		b.Width1 = width * math.sin(math.pi * i / points)
		b.Parent = carrier
		beams[i] = b
	end
	VFXLib.animate(duration, function(a)
		local e = VFXLib.easeOut(a)
		carrier.CFrame = cframe * CFrame.Angles(0, sweep * (0.5 - e), 0)
		local grow = 1 + e * 0.25
		for i = 0, points do
			local th = -arc / 2 + arc * i / points
			attachments[i].Position = Vector3.new(math.sin(th) * radius * grow, 0, -math.cos(th) * radius * grow)
		end
		local fade = NumberSequence.new(math.clamp((a - 0.25) / 0.75, 0, 1))
		for _, b in ipairs(beams) do
			b.Transparency = fade
		end
	end, function()
		carrier:Destroy()
		VFXLib.release()
	end)
end

---------------------------------------------------------------------------
-- Screen tint: darken/tint the world for a cinematic moment, then release.
---------------------------------------------------------------------------
--[[ opts: Brightness (-0.2), Saturation (-0.3), Contrast (0.15),
     Tint (Color3), Release (seconds to hold after duration), FadeOut ]]
function TuskVFX.ScreenTint(duration, opts)
	opts = opts or {}
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SpinScreenTint"
	cc.Parent = game:GetService("Lighting")
	local brightness = opts.Brightness or -0.2
	local saturation = opts.Saturation or -0.3
	local contrast = opts.Contrast or 0.15
	local tint = opts.Tint or Color3.new(1, 1, 1)
	VFXLib.animate(math.max(duration, 0.05), function(a)
		local k = math.min(a * 3, 1)
		cc.Brightness = brightness * k
		cc.Saturation = saturation * k
		cc.Contrast = contrast * k
		cc.TintColor = Color3.new(1, 1, 1):Lerp(tint, k)
	end)
	task.delay(duration + (opts.Release or 0.2), function()
		VFXLib.animate(opts.FadeOut or 0.5, function(a)
			local k = 1 - a
			cc.Brightness = brightness * k
			cc.Saturation = saturation * k
			cc.Contrast = contrast * k
			cc.TintColor = Color3.new(1, 1, 1):Lerp(tint, k)
		end, function()
			cc:Destroy()
		end)
	end)
	return cc
end

-- True if the local camera is within `range` studs of a position.
function TuskVFX.IsNear(position, range)
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude < (range or 80)
end

---------------------------------------------------------------------------
-- Golden ratio: logarithmic spiral and the Golden Rectangle
---------------------------------------------------------------------------
--[[ Golden spiral of beams that turns faster and faster.
     opts: Size, Duration, Color (outer), Color2 (inner/light), Width ]]
function TuskVFX.CreateGoldenSpiral(cframe, opts)
	opts = opts or {}
	local size, duration = opts.Size or 3, opts.Duration or 0.6
	local main, light = opts.Color or colors.Gold, opts.Color2 or colors.GoldLight
	local carrier = VFXLib.anchor(cframe)
	local prev
	local points = q().RingSegments
	for i = 0, points do
		local t = i / points
		local angle = t * math.pi * 4
		local r = size * 0.08 * math.exp(t * 2.5)
		local a = Instance.new("Attachment")
		a.Position = Vector3.new(math.cos(angle) * r, math.sin(angle) * r, 0)
		a.Parent = carrier
		if prev then
			local b = Instance.new("Beam")
			b.Attachment0 = prev
			b.Attachment1 = a
			b.FaceCamera = true
			b.LightEmission = 1
			b.Width0 = opts.Width or 0.18
			b.Width1 = opts.Width or 0.18
			b.Color = ColorSequence.new(light:Lerp(main, t))
			b.Parent = carrier
		end
		prev = a
	end
	VFXLib.animate(duration, function(a, dt)
		carrier.CFrame = carrier.CFrame * CFrame.Angles(0, 0, (dt or 0) * (2 + a * 8))
	end, function()
		carrier:Destroy()
	end)
end

--[[ The Golden Rectangle: nested golden-ratio rectangles with the spiral
     drawn through them, growing in and turning.
     opts: Size, Duration, Color (outer), Color2 (inner/light), Turn (radians) ]]
function TuskVFX.CreateGoldenRectangle(cframe, opts)
	opts = opts or {}
	local size, duration = opts.Size or 3, opts.Duration or 0.8
	local main, light = opts.Color or colors.Gold, opts.Color2 or colors.GoldLight
	local carrier = VFXLib.anchor(cframe)
	local phi = 1.618
	local function line(a, b, width, color)
		local a0 = Instance.new("Attachment")
		a0.Position = a
		a0.Parent = carrier
		local a1 = Instance.new("Attachment")
		a1.Position = b
		a1.Parent = carrier
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Segments = 1
		beam.Width0 = width
		beam.Width1 = width
		beam.Color = ColorSequence.new(color)
		beam.Parent = carrier
	end
	-- Outer rectangle, then squares cut off in turn (left, top, right, bottom...).
	-- Each square gets a quarter circle centred on its inner corner: together
	-- they make the golden spiral.
	local x0, y0, w, h = -size * phi / 2, -size / 2, size * phi, size
	local arcs = {}
	for i = 0, 6 do
		local color = light:Lerp(main, i / 6)
		local width = 0.16 * (1 - i * 0.1)
		line(Vector3.new(x0, y0, 0), Vector3.new(x0 + w, y0, 0), width, color)
		line(Vector3.new(x0 + w, y0, 0), Vector3.new(x0 + w, y0 + h, 0), width, color)
		line(Vector3.new(x0 + w, y0 + h, 0), Vector3.new(x0, y0 + h, 0), width, color)
		line(Vector3.new(x0, y0 + h, 0), Vector3.new(x0, y0, 0), width, color)
		local side = i % 4
		if side == 0 then -- square on the left
			local sq = h
			table.insert(arcs, { x0 + sq, y0, sq, math.pi, math.pi / 2 })
			x0, w = x0 + sq, w - sq
		elseif side == 1 then -- square on top
			local sq = w
			table.insert(arcs, { x0, y0 + h - sq, sq, math.pi / 2, 0 })
			h = h - sq
		elseif side == 2 then -- square on the right
			local sq = h
			table.insert(arcs, { x0 + w - sq, y0 + h, sq, 0, -math.pi / 2 })
			w = w - sq
		else -- square on the bottom
			local sq = w
			table.insert(arcs, { x0 + w, y0 + sq, sq, -math.pi / 2, -math.pi })
			y0, h = y0 + sq, h - sq
		end
	end
	local prev
	for _, arc in ipairs(arcs) do
		for k = 0, 5 do
			local angle = arc[4] + (arc[5] - arc[4]) * k / 5
			local p = Vector3.new(arc[1] + math.cos(angle) * arc[3], arc[2] + math.sin(angle) * arc[3], -0.05)
			if prev then
				line(prev, p, 0.22, light)
			end
			prev = p
		end
	end
	VFXLib.animate(duration, function(a, dt)
		local grow = VFXLib.easeOut(math.min(a * 2.5, 1))
		carrier.CFrame = cframe * CFrame.Angles(0, 0, a * (opts.Turn or math.pi * 0.6))
		for _, child in ipairs(carrier:GetChildren()) do
			if child:IsA("Beam") then
				child.Transparency = NumberSequence.new(math.clamp(1 - grow + math.max(0, a - 0.85) / 0.15, 0, 1))
			end
		end
	end, function()
		carrier:Destroy()
	end)
end


return TuskVFX
end

-- ======================================================================
-- MODULE: UITheme
-- ======================================================================
__modules["UITheme"] = function()
--[[
	UITheme  (StarterPlayerScripts.SpinClient.UI.UITheme)

	The house style, taken from the bounty board, so every screen matches:
	dark wood frames with planks, grain, nails and metal corner brackets;
	aged parchment with burnt edges; Bangers titles; gold, red and green
	accents; chunky dark strokes; buttons that pop when you hover or press.

	Colours: UITheme.C (WOOD, WOOD_DARK, WOOD_LIGHT, WOOD_EDGE, PAPER,
	PAPER_DARK, INK, BURNT, RED, GREEN, GOLD, BRASS, NAIL, STEEL, SHADOW).
	Fonts:   UITheme.Font (Title = Bangers, Heavy = GothamBlack,
	Body = GothamBold, Plain = GothamMedium).

	Helpers (each returns the instance it makes):
	  new(class, props, parent)          make an instance with properties
	  corner(p, radius) / stroke(p, color, thickness, transparency)
	  label(parent, props)               a scaled text label (ink by default)
	  wood(frame, opts)                  turn a frame into a framed wooden
	                                     board: returns the inner plank area.
	                                     opts: Planks (rows), Brackets (bool),
	                                     Nails (bool), Border (px), Radius
	  paper(frame, opts)                 aged parchment: gradient + burnt edge
	  sign(parent, title, subtitle, props) a hanging wooden title sign
	  button(parent, text, color, props) a chunky button that pops on hover
	  chip(parent, text, color, props)   a small rounded tag
	  bar(parent, color, props)          a wood-framed meter; returns
	                                     frame, fill (set fill.Size X scale)
	  pop(guiObject, from)               bounce something in (needs a UIScale)
	  hover(button, scaleTo)             hover/press bounce on any button
]]

local TweenService = game:GetService("TweenService")

local UITheme = {}

local C = {
	WOOD = Color3.fromRGB(112, 74, 44),
	WOOD_DARK = Color3.fromRGB(78, 50, 30),
	WOOD_LIGHT = Color3.fromRGB(134, 90, 56),
	WOOD_MID = Color3.fromRGB(122, 82, 50),
	WOOD_EDGE = Color3.fromRGB(45, 28, 16),
	GRAIN = Color3.fromRGB(78, 50, 30),
	PAPER = Color3.fromRGB(234, 205, 160),
	PAPER_DARK = Color3.fromRGB(205, 172, 125),
	INK = Color3.fromRGB(60, 36, 20),
	BURNT = Color3.fromRGB(120, 78, 40),
	RED = Color3.fromRGB(190, 40, 35),
	GREEN = Color3.fromRGB(60, 150, 70),
	GOLD = Color3.fromRGB(255, 205, 90),
	GLOW = Color3.fromRGB(255, 214, 110),
	BRASS = Color3.fromRGB(196, 160, 90),
	NAIL = Color3.fromRGB(70, 70, 76),
	STEEL = Color3.fromRGB(90, 92, 100),
	STEEL_DARK = Color3.fromRGB(40, 40, 46),
	SHADOW = Color3.fromRGB(30, 18, 10),
	WHITE = Color3.new(1, 1, 1),
}
UITheme.C = C

UITheme.Font = {
	Title = Enum.Font.Bangers,
	Heavy = Enum.Font.GothamBlack,
	Body = Enum.Font.GothamBold,
	Plain = Enum.Font.GothamMedium,
}

UITheme.FAST = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
UITheme.SOFT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function UITheme.new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local new = UITheme.new

function UITheme.corner(p, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 6) }, p)
end

function UITheme.stroke(p, color, thickness, transparency)
	return new("UIStroke", { Color = color or C.WOOD_EDGE, Thickness = thickness or 2, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end

function UITheme.label(parent, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, TextColor3 = C.INK, Font = UITheme.Font.Heavy, TextScaled = true }, parent)
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	return l
end

-- Turn `frame` into a framed wooden board. Returns the inner plank area
-- (put content in there, or on top of `frame` with a higher ZIndex).
function UITheme.wood(frame, opts)
	opts = opts or {}
	local border = opts.Border or 6
	local radius = opts.Radius or 8
	local z = frame.ZIndex
	frame.BackgroundColor3 = C.WOOD_DARK
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	UITheme.corner(frame, radius)
	UITheme.stroke(frame, C.WOOD_EDGE, opts.Stroke or 3)
	local inner = new("Frame", { Name = "Planks", BackgroundColor3 = C.WOOD, BorderSizePixel = 0, Position = UDim2.fromOffset(border, border), Size = UDim2.new(1, -border * 2, 1, -border * 2), ClipsDescendants = true, ZIndex = z }, frame)
	UITheme.corner(inner, math.max(radius - 3, 2))
	local rows = opts.Planks or 3
	local tones = { C.WOOD_LIGHT, C.WOOD, C.WOOD_MID }
	for i = 0, rows - 1 do
		local plank = new("Frame", { BackgroundColor3 = tones[i % 3 + 1], BorderSizePixel = 0, Position = UDim2.fromScale(0, i / rows), Size = UDim2.new(1, 0, 1 / rows, 0), ZIndex = z }, inner)
		-- Grain lines that fade at their ends, and a dark seam under each plank.
		for g = 1, 2 do
			local line = new("Frame", { BackgroundColor3 = C.GRAIN, BorderSizePixel = 0, BackgroundTransparency = 0.6, Position = UDim2.new(((i * 7 + g * 13) % 10) / 20, 0, 0.25 + g * 0.22, 0), Size = UDim2.new(0.5 + ((i + g) % 4) * 0.1, 0, 0, 2), ZIndex = z }, plank)
			new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0), NumberSequenceKeypoint.new(0.7, 0), NumberSequenceKeypoint.new(1, 1) }) }, line)
		end
		if i < rows - 1 then
			new("Frame", { BackgroundColor3 = Color3.fromRGB(50, 32, 18), BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 2), ZIndex = z }, plank)
		end
		if opts.Nails ~= false then
			for _, x in ipairs({ 0, 1 }) do
				local nail = new("Frame", { BackgroundColor3 = C.NAIL, AnchorPoint = Vector2.new(x, 0.5), Position = UDim2.new(x, x == 0 and 5 or -5, 0.5, 0), Size = UDim2.fromOffset(4, 4), ZIndex = z }, plank)
				UITheme.corner(nail, 99)
			end
		end
	end
	-- Dark edges over the planks.
	local shade = new("Frame", { Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = z }, inner)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.18, 1), NumberSequenceKeypoint.new(0.82, 1), NumberSequenceKeypoint.new(1, 0.6) }), Rotation = opts.ShadeRotation or 0 }, shade)
	if opts.Brackets then
		local size = opts.BracketSize or 18
		for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
			local bracket = new("Frame", { Name = "Bracket", AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.fromOffset(size, size), BackgroundColor3 = C.STEEL, ZIndex = z + 2 }, frame)
			UITheme.corner(bracket, 4)
			UITheme.stroke(bracket, C.STEEL_DARK, 2)
			local bolt = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(math.max(4, size * 0.28), math.max(4, size * 0.28)), BackgroundColor3 = Color3.fromRGB(170, 172, 180), ZIndex = z + 2 }, bracket)
			UITheme.corner(bolt, 99)
		end
	end
	return inner
end

-- Aged parchment: lighter middle, browner edges, a burnt border.
function UITheme.paper(frame, opts)
	opts = opts or {}
	frame.BackgroundColor3 = C.PAPER
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	UITheme.corner(frame, opts.Radius or 4)
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.PAPER_DARK), ColorSequenceKeypoint.new(0.38, C.PAPER), ColorSequenceKeypoint.new(1, C.PAPER_DARK) }), Rotation = opts.Rotation or 70 }, frame)
	UITheme.stroke(frame, C.BURNT, opts.Stroke or 2, 0.2)
	return frame
end

-- A hanging wooden title sign with ropes.
function UITheme.sign(parent, title, subtitle, props)
	local sign = new("Frame", { Name = "Sign", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(240, 44) }, parent)
	for k, v in pairs(props or {}) do
		sign[k] = v
	end
	local z = sign.ZIndex
	UITheme.wood(sign, { Planks = 1, Border = 3, Radius = 6, Nails = true })
	UITheme.label(sign, { Name = "Title", Size = UDim2.new(1, 0, subtitle and 0.72 or 1, 0), Text = title, Font = UITheme.Font.Title, TextColor3 = C.PAPER, TextStrokeTransparency = 0.4, ZIndex = z + 1 })
	if subtitle then
		UITheme.label(sign, { Name = "Subtitle", Position = UDim2.fromScale(0, 0.68), Size = UDim2.fromScale(1, 0.26), Text = subtitle, Font = UITheme.Font.Body, TextColor3 = C.GOLD, ZIndex = z + 1 })
	end
	return sign
end

-- Hover / press bounce on any button (adds a UIScale if it has none).
function UITheme.hover(b, scaleTo)
	local s = b:FindFirstChildOfClass("UIScale") or new("UIScale", { Scale = 1 }, b)
	b.MouseEnter:Connect(function()
		TweenService:Create(s, UITheme.FAST, { Scale = scaleTo or 1.06 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(s, UITheme.SOFT, { Scale = 1 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(s, UITheme.SOFT, { Scale = 0.94 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(s, UITheme.FAST, { Scale = scaleTo or 1.06 }):Play()
	end)
	return s
end

-- A chunky button: bold colour, dark stroke, Bangers text, pops on hover.
function UITheme.button(parent, text, color, props)
	color = color or C.RED
	local b = new("TextButton", { AutoButtonColor = false, BackgroundColor3 = color, Text = text, Font = UITheme.Font.Title, TextScaled = true, TextColor3 = C.WHITE, TextStrokeTransparency = 0.6 }, parent)
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	UITheme.corner(b, 8)
	UITheme.stroke(b, color:Lerp(Color3.new(0, 0, 0), 0.45), 2)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)), Rotation = 90 }, b)
	new("UIPadding", { PaddingTop = UDim.new(0.14, 0), PaddingBottom = UDim.new(0.14, 0), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, b)
	UITheme.hover(b)
	return b
end

-- A small rounded tag.
function UITheme.chip(parent, text, color, props)
	color = color or C.GOLD
	local f = new("Frame", { BackgroundColor3 = color, Size = UDim2.fromOffset(80, 22) }, parent)
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	UITheme.corner(f, 6)
	UITheme.stroke(f, color:Lerp(Color3.new(0, 0, 0), 0.5), 2)
	local light = (color.R * 0.3 + color.G * 0.59 + color.B * 0.11) > 0.55
	UITheme.label(f, { Name = "Text", Size = UDim2.fromScale(1, 1), Text = text, Font = UITheme.Font.Title, TextColor3 = light and C.INK or C.WHITE, ZIndex = f.ZIndex })
	new("UIPadding", { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, f)
	return f
end

-- A wood-framed meter. Returns the frame and the fill (size its X scale 0..1).
function UITheme.bar(parent, color, props)
	local frame = new("Frame", { Name = "Bar", BackgroundColor3 = C.WOOD_DARK, Size = UDim2.fromOffset(200, 16) }, parent)
	for k, v in pairs(props or {}) do
		frame[k] = v
	end
	local z = frame.ZIndex
	UITheme.corner(frame, 5)
	UITheme.stroke(frame, C.WOOD_EDGE, 2)
	local well = new("Frame", { Name = "Well", BackgroundColor3 = C.SHADOW, BorderSizePixel = 0, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), ClipsDescendants = true, ZIndex = z }, frame)
	UITheme.corner(well, 3)
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = color or C.GREEN, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = z }, well)
	UITheme.corner(fill, 3)
	new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)), Rotation = 90 }, fill)
	-- A shine along the top.
	new("Frame", { Name = "Shine", BackgroundColor3 = C.WHITE, BackgroundTransparency = 0.75, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0.35, 0), ZIndex = z }, fill)
	return frame, fill
end

-- Bounce something in from `from` (default 0.6) to full size.
function UITheme.pop(obj, from)
	local s = obj:FindFirstChildOfClass("UIScale") or new("UIScale", { Scale = 1 }, obj)
	s.Scale = from or 0.6
	TweenService:Create(s, UITheme.FAST, { Scale = 1 }):Play()
	return s
end

return UITheme
end

-- ======================================================================
-- MODULE: VFXLib
-- ======================================================================
__modules["VFXLib"] = function()
--[[
	VFXLib  (StarterPlayerScripts.SpinClient.VFXLib)

	Reusable procedural VFX building blocks. Built for Spin first, and meant
	to be reused by Tusk nails, wormholes and Wrecking Balls later.

	Rules every effect follows:
	  * lives in workspace.SpinClientFX (client-only, never replicated)
	  * has a fixed duration and destroys itself (animate() + Debris)
	  * reads VFXQuality for particle counts / detail
	  * skips optional detail when too many effects are already active
]]

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local VFXQuality = __require("VFXQuality")

local VFXLib = {}

VFXLib.Textures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
}

local folder = workspace:FindFirstChild("SpinClientFX")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "SpinClientFX"
	folder.Parent = workspace
end
VFXLib.Folder = folder

---------------------------------------------------------------------------
-- Projectile clock: server projectiles can be paused (The World's time
-- stop). Every projectile visual asks flight(id, serverTime) how long it has
-- been flying instead of (now - serverTime), and adds held(id) to its expiry.
---------------------------------------------------------------------------
local clocks = {} -- [projectile id] = { Frozen = flight seconds } or { Base, At }

function VFXLib.flight(id, serverTime)
	local now = workspace:GetServerTimeNow()
	local c = id and clocks[id]
	if not c then
		return now - (serverTime or now)
	end
	if c.Frozen then
		return c.Frozen
	end
	return c.Base + (now - c.At)
end

-- Seconds this projectile has spent paused (push its expiry back by this).
function VFXLib.held(id, serverTime)
	local c = id and clocks[id]
	if not c then
		return 0
	end
	local now = workspace:GetServerTimeNow()
	return math.max(0, (now - (c.Spawned or serverTime or now)) - VFXLib.flight(id, serverTime))
end

do
	local ok, Net = pcall(function()
		return __require("Net")
	end)
	if ok and Net and Net.get then
		Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
			if typeof(data) ~= "table" then
				return
			end
			if name == "ProjectileFreeze" then
				for i, id in ipairs(data.Ids or {}) do
					clocks[id] = { Frozen = data.Flights and data.Flights[i] or 0, Spawned = data.Spawned and data.Spawned[i] }
				end
			elseif name == "ProjectileResume" then
				for i, id in ipairs(data.Ids or {}) do
					local c = clocks[id]
					clocks[id] = { Base = data.Flights and data.Flights[i] or 0, At = workspace:GetServerTimeNow(), Spawned = c and c.Spawned or (data.Spawned and data.Spawned[i]) }
				end
			elseif name == "ProjectileEnd" and data.Id then
				-- (Ended a moment later, so the visual's last step still uses it.)
				local id = data.Id
				task.delay(0.5, function()
					clocks[id] = nil
				end)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Frame scheduler: one RenderStepped connection drives every animation.
---------------------------------------------------------------------------
local jobs = {}

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for i = #jobs, 1, -1 do
		local job = jobs[i]
		local alpha = (now - job.Start) / job.Duration
		if job.Cancelled or alpha >= 1 then
			table.remove(jobs, i)
			if not job.Cancelled then
				local ok, err = pcall(job.Step, 1, dt)
				if not ok then
					warn("[VFXLib] step error:", err)
				end
			end
			if job.Done then
				pcall(job.Done)
			end
		else
			local ok, err = pcall(job.Step, alpha, dt)
			if not ok then
				warn("[VFXLib] step error:", err)
				job.Cancelled = true
			end
		end
	end
end)

-- step(alpha 0..1, dt); done() always runs exactly once, even if cancelled.
function VFXLib.animate(duration, step, done)
	local job = { Start = os.clock(), Duration = math.max(duration, 1e-3), Step = step, Done = done }
	table.insert(jobs, job)
	return job
end

function VFXLib.cancel(job)
	if job then
		job.Cancelled = true
	end
end

function VFXLib.easeOut(a)
	return 1 - (1 - a) * (1 - a) * (1 - a)
end

function VFXLib.easeInOut(a)
	return a < 0.5 and 4 * a * a * a or 1 - ((-2 * a + 2) ^ 3) / 2
end

---------------------------------------------------------------------------
-- Effect budget
---------------------------------------------------------------------------
local activeEffects = 0

-- Returns true if an optional effect may spawn; call VFXLib.release() after.
function VFXLib.acquire()
	if activeEffects >= VFXQuality.get().MaxActiveEffects then
		return false
	end
	activeEffects = activeEffects + 1
	return true
end

function VFXLib.release()
	activeEffects = math.max(0, activeEffects - 1)
end

function VFXLib.particleCount(n)
	return math.max(1, math.floor(n * VFXQuality.get().Particles + 0.5))
end

---------------------------------------------------------------------------
-- Primitives
---------------------------------------------------------------------------
function VFXLib.part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	if not p.Parent then
		p.Parent = folder
	end
	return p
end

-- Invisible anchored carrier for attachments, emitters and lights.
function VFXLib.anchor(cframe, lifetime)
	local p = VFXLib.part({ Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1), CFrame = cframe })
	if lifetime then
		Debris:AddItem(p, lifetime)
	end
	return p
end

--[[
	Energy ring made of straight Beams between attachments on a circle.
	Ring lies in the carrier part's local XZ plane (axis = local Y).
	ring:SetRadius(r), ring:SetWidth(w), ring:SetTransparency(t),
	ring:SetCFrame(cf), ring:Destroy()
]]
function VFXLib.ring(opts)
	local segments = opts.Segments or VFXQuality.get().RingSegments
	local carrier = VFXLib.anchor(opts.CFrame or CFrame.new())
	local attachments = {}
	local beams = {}
	for i = 1, segments do
		local a = Instance.new("Attachment")
		a.Parent = carrier
		attachments[i] = a
	end
	local color = ColorSequence.new(opts.Color or Color3.new(1, 0.8, 0.3))
	for i = 1, segments do
		local b = Instance.new("Beam")
		b.Attachment0 = attachments[i]
		b.Attachment1 = attachments[i % segments + 1]
		b.Color = color
		b.LightEmission = opts.LightEmission or 1
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Segments = 1
		b.Width0 = opts.Width or 0.3
		b.Width1 = opts.Width or 0.3
		b.Transparency = NumberSequence.new(opts.Transparency or 0)
		b.Parent = carrier
		beams[i] = b
	end

	local ring = { Part = carrier, Radius = opts.Radius or 2 }
	function ring:SetRadius(r)
		self.Radius = r
		for i, a in ipairs(attachments) do
			local theta = (i - 1) / segments * math.pi * 2
			a.Position = Vector3.new(math.cos(theta) * r, 0, math.sin(theta) * r)
		end
	end
	function ring:SetWidth(w)
		for _, b in ipairs(beams) do
			b.Width0 = w
			b.Width1 = w
		end
	end
	function ring:SetTransparency(t)
		local seq = NumberSequence.new(math.clamp(t, 0, 1))
		for _, b in ipairs(beams) do
			b.Transparency = seq
		end
	end
	function ring:SetColor(c)
		local seq = ColorSequence.new(c)
		for _, b in ipairs(beams) do
			b.Color = seq
		end
	end
	function ring:SetCFrame(cf)
		carrier.CFrame = cf
	end
	function ring:Destroy()
		carrier:Destroy()
	end
	ring:SetRadius(ring.Radius)
	return ring
end

-- Expanding, fading ring (shockwave). axisCFrame: ring axis = its UpVector.
function VFXLib.shockwave(axisCFrame, opts)
	if not VFXLib.acquire() then
		return
	end
	local ring = VFXLib.ring({
		CFrame = axisCFrame,
		Radius = opts.StartRadius or 0.5,
		Width = opts.Width or 0.6,
		Color = opts.Color,
	})
	local maxRadius = opts.Radius or 10
	local width = opts.Width or 0.6
	local spin = opts.Spin or 0
	VFXLib.animate(opts.Duration or 0.45, function(a)
		local e = VFXLib.easeOut(a)
		ring:SetRadius((opts.StartRadius or 0.5) + (maxRadius - (opts.StartRadius or 0.5)) * e)
		ring:SetWidth(width * (1 - a * 0.7))
		ring:SetTransparency(a ^ 1.6)
		if spin ~= 0 then
			ring:SetCFrame(axisCFrame * CFrame.Angles(0, spin * e, 0))
		end
	end, function()
		ring:Destroy()
		VFXLib.release()
	end)
end

-- Flat neon disc that expands along the ground.
function VFXLib.groundDisc(position, normal, opts)
	if not VFXLib.acquire() then
		return
	end
	local radius = opts.Radius or 8
	-- Cylinder axis is X: point it along the surface normal.
	local up = math.abs(normal.Y) > 0.95 and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
	local right = normal.Unit
	local back = right:Cross(up).Unit
	local cf = CFrame.fromMatrix(position + normal * 0.05, right, back:Cross(right).Unit)
	local disc = VFXLib.part({
		Shape = Enum.PartType.Cylinder,
		Color = opts.Color or Color3.new(1, 0.8, 0.3),
		Transparency = 0.25,
		CFrame = cf,
		Size = Vector3.new(0.1, 0.5, 0.5),
	})
	VFXLib.animate(opts.Duration or 0.4, function(a)
		local d = 0.5 + radius * 2 * VFXLib.easeOut(a)
		disc.Size = Vector3.new(0.08, d, d)
		disc.Transparency = 0.25 + 0.75 * a
	end, function()
		disc:Destroy()
		VFXLib.release()
	end)
end

-- One-shot particle burst.
function VFXLib.burst(position, opts)
	local carrier = VFXLib.anchor(CFrame.new(position), (opts.Lifetime or 0.6) + 0.5)
	local e = Instance.new("ParticleEmitter")
	e.Texture = opts.Texture or VFXLib.Textures.Sparkle
	e.Color = ColorSequence.new(opts.Color or Color3.new(1, 0.85, 0.4))
	e.LightEmission = opts.LightEmission or 1
	e.LightInfluence = 0
	e.Size = opts.Size or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = opts.TransparencySeq or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new((opts.Lifetime or 0.6) * 0.5, opts.Lifetime or 0.6)
	e.Speed = NumberRange.new((opts.Speed or 20) * 0.5, opts.Speed or 20)
	e.SpreadAngle = Vector2.new(opts.Spread or 180, opts.Spread or 180)
	e.Drag = opts.Drag or 4
	e.Acceleration = opts.Acceleration or Vector3.new(0, 0, 0)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = 0
	if opts.Direction then
		e.EmissionDirection = Enum.NormalId.Top
		carrier.CFrame = CFrame.lookAt(position, position + opts.Direction) * CFrame.Angles(-math.pi / 2, 0, 0)
	end
	e.Parent = carrier
	e:Emit(VFXLib.particleCount(opts.Count or 20))
	return carrier
end

-- Short point-light flash.
function VFXLib.flash(position, color, brightness, range, duration)
	if not VFXQuality.get().Lights then
		return
	end
	local carrier = VFXLib.anchor(CFrame.new(position))
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 16
	light.Brightness = brightness or 4
	light.Shadows = false
	light.Parent = carrier
	VFXLib.animate(duration or 0.3, function(a)
		light.Brightness = (brightness or 4) * (1 - a)
	end, function()
		carrier:Destroy()
	end)
end

-- Fading ghost copy of a sphere (afterimage), High quality only.
function VFXLib.afterimage(cframe, size, color)
	if not VFXQuality.get().Afterimages or not VFXLib.acquire() then
		return
	end
	local ghost = VFXLib.part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		CFrame = cframe,
		Color = color,
		Transparency = 0.55,
	})
	VFXLib.animate(0.18, function(a)
		ghost.Transparency = 0.55 + 0.45 * a
		local s = size * (1 + a * 0.3)
		ghost.Size = Vector3.new(s, s, s)
	end, function()
		ghost:Destroy()
		VFXLib.release()
	end)
end

---------------------------------------------------------------------------
-- Sound
---------------------------------------------------------------------------
function VFXLib.sound(soundId, parentOrPosition, volume, pitch, looped)
	if not soundId or soundId == "" then
		return nil
	end
	local parent = parentOrPosition
	if typeof(parentOrPosition) == "Vector3" then
		parent = VFXLib.anchor(CFrame.new(parentOrPosition), 6)
	end
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	s.Looped = looped == true
	s.RollOffMaxDistance = 220
	s.Parent = parent or folder
	s:Play()
	if not s.Looped then
		Debris:AddItem(s, 6)
	end
	return s
end

return VFXLib
end

-- ======================================================================
-- MODULE: VFXQuality
-- ======================================================================
__modules["VFXQuality"] = function()
--[[
	VFXQuality  (ReplicatedStorage.SpinShared.VFXQuality)

	Per-player visual quality. Purely client-side: it never changes gameplay.
	Every effect asks VFXQuality.get() before spawning detail.
]]

local VFXQuality = {}

VFXQuality.Presets = {
	Low = {
		Particles = 0.3, -- multiplier on particle counts
		RingSegments = 12, -- beam segments per energy ring
		Grooves = false, -- steel ball surface grooves
		Afterimages = false,
		ScreenEffects = false, -- speed lines, FOV punch
		ImpactFrames = false,
		Lights = false,
		MaxActiveEffects = 12,
		ShakeScale = 0.6,
	},
	Medium = {
		Particles = 0.65,
		RingSegments = 18,
		Grooves = true,
		Afterimages = false,
		ScreenEffects = true,
		ImpactFrames = false,
		Lights = true,
		MaxActiveEffects = 24,
		ShakeScale = 1,
	},
	High = {
		Particles = 1,
		RingSegments = 28,
		Grooves = true,
		Afterimages = true,
		ScreenEffects = true,
		ImpactFrames = true,
		Lights = true,
		MaxActiveEffects = 40,
		ShakeScale = 1,
	},
}

VFXQuality.Order = { "Low", "Medium", "High" }

local current = "Medium"
local changed = Instance.new("BindableEvent")
VFXQuality.Changed = changed.Event

function VFXQuality.get()
	return VFXQuality.Presets[current], current
end

function VFXQuality.set(name)
	if VFXQuality.Presets[name] and name ~= current then
		current = name
		changed:Fire(name)
	end
end

function VFXQuality.cycle()
	for i, name in ipairs(VFXQuality.Order) do
		if name == current then
			VFXQuality.set(VFXQuality.Order[i % #VFXQuality.Order + 1])
			return current
		end
	end
	return current
end

return VFXQuality
end

-- ======================================================================
-- MODULE: WeatherClient
-- ======================================================================
__modules["WeatherClient"] = function()
--[[
	WeatherClient  (StarterPlayerScripts.SpinClient.WeatherClient)

	Draws the server's rain (WeatherService sets ReplicatedStorage
	SpinRaining): falling streaks around your camera, a grey-blue tint and
	fog, an optional looping rain sound (TuskConfig.Sounds.Rain), and a
	banner when it starts and stops: a nailed wooden sign in the bounty
	board's style (UI.UITheme) that pops in and fades out. Everything fades
	in and out. Blackmore players get a hint on a pinned parchment strip
	under it: double-jump to walk on the raindrops.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local UITheme = __require("UITheme")

local WeatherClient = {}

local player = Players.LocalPlayer
local STREAKS = 160
local AREA = 70 -- streaks fall within this many studs of the camera
local FALL = 95 -- studs per second
local RAIN_COLOR = Color3.fromRGB(200, 215, 235)

local folder
local pool = {}
local intensity = 0 -- 0 = clear, 1 = full rain
local tint, sound
local clear -- the lighting before the rain (restored after)
local banner, bannerTitle, bannerSub, bannerHint
local bannerToken
local bannerParts = {} -- { Object, Property, Base } faded together

function WeatherClient.isRaining()
	return ReplicatedStorage:GetAttribute("SpinRaining") == true
end

local function newStreak()
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Glass
	p.Color = RAIN_COLOR
	p.Transparency = 1
	p.Size = Vector3.new(0.07, 2.2, 0.07)
	p.Parent = folder
	return p
end

local function reset(s, center, fresh)
	local a = math.random() * math.pi * 2
	local r = math.sqrt(math.random()) * AREA
	s.Offset = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	s.Y = center.Y + (fresh and (math.random() * 70 - 25) or (30 + math.random() * 15))
end

local function showBanner(title, sub)
	if not banner then
		return
	end
	local token = {}
	bannerToken = token
	bannerTitle.Text = title
	bannerSub.Text = sub or ""
	bannerHint.Visible = (sub or "") ~= ""
	banner.Visible = true
	UITheme.pop(banner, 0.7)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if bannerToken ~= token then
			conn:Disconnect()
			return
		end
		local t = os.clock() - start
		local alpha
		if t < 0.4 then
			alpha = t / 0.4
		elseif t < 3.6 then
			alpha = 1
		else
			alpha = math.max(0, 1 - (t - 3.6) / 0.6)
		end
		-- The whole sign (wood, parchment, text, strokes) fades as one.
		for _, e in ipairs(bannerParts) do
			e[1][e[2]] = e[3] + (1 - e[3]) * (1 - alpha)
		end
		banner.Position = UDim2.new(0.5, 0, 0, 70 - 12 * (1 - math.min(t / 0.4, 1)))
		if t > 4.2 then
			banner.Visible = false
			conn:Disconnect()
		end
	end)
end

local function isBlackmore()
	local c = player.Character
	return c and c:GetAttribute("TuskAct") == 11
end

local function onRainChanged()
	if WeatherClient.isRaining() then
		showBanner("IT'S RAINING", isBlackmore() and "BLACKMORE: double-jump to walk on the raindrops" or "")
	else
		showBanner("THE RAIN STOPS", "")
	end
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

function WeatherClient.step(dt)
	local target = WeatherClient.isRaining() and 1 or 0
	-- Fade over about 3 seconds.
	if intensity ~= target then
		if intensity == 0 then
			clear = { FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor }
		end
		intensity = math.clamp(intensity + (target > intensity and dt or -dt) / 3, 0, 1)
	end
	if intensity <= 0 then
		if clear then
			Lighting.FogEnd, Lighting.FogStart, Lighting.FogColor = clear.FogEnd, clear.FogStart, clear.FogColor
			clear = nil
		end
		tint.Enabled = false
		if sound then
			sound.Volume = 0
			if sound.Playing then
				sound:Stop()
			end
		end
		for _, s in ipairs(pool) do
			if s.Part.Transparency ~= 1 then
				s.Part.Transparency = 1
			end
		end
		return
	end
	-- Grey-blue sky and fog.
	tint.Enabled = true
	tint.Saturation = -0.3 * intensity
	tint.Brightness = -0.07 * intensity
	tint.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(205, 215, 235), intensity)
	if clear then
		Lighting.FogColor = clear.FogColor:Lerp(Color3.fromRGB(150, 160, 175), intensity)
		Lighting.FogEnd = lerp(clear.FogEnd, math.min(clear.FogEnd, 420), intensity)
		Lighting.FogStart = lerp(clear.FogStart, math.min(clear.FogStart, 40), intensity)
	end
	if sound then
		if not sound.Playing then
			sound:Play()
		end
		sound.Volume = 0.5 * intensity
	end
	-- The streaks follow the camera; how many show depends on the intensity.
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local center = camera.CFrame.Position
	local active = math.floor(STREAKS * intensity)
	local parts, cframes = {}, {}
	for i, s in ipairs(pool) do
		if i <= active then
			s.Y = s.Y - FALL * dt
			if s.Y < center.Y - 30 then
				reset(s, center, false)
			end
			local pos = Vector3.new(center.X + s.Offset.X, s.Y, center.Z + s.Offset.Z)
			-- Keep them around the camera as it moves.
			if (Vector3.new(pos.X - center.X, 0, pos.Z - center.Z)).Magnitude > AREA then
				reset(s, center, true)
			end
			if s.Part.Transparency ~= 0.45 then
				s.Part.Transparency = 0.45
			end
			table.insert(parts, s.Part)
			table.insert(cframes, CFrame.new(pos) * CFrame.Angles(0, 0, 0.06))
		elseif s.Part.Transparency ~= 1 then
			s.Part.Transparency = 1
		end
	end
	if workspace.BulkMoveTo then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	else
		for i, p in ipairs(parts) do
			p.CFrame = cframes[i]
		end
	end
end

function WeatherClient.init()
	local cfg = TuskConfig.Weather
	if cfg and cfg.Enabled == false then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "SpinRain"
	folder.Parent = workspace
	local center = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or Vector3.new()
	for i = 1, STREAKS do
		local s = { Part = newStreak() }
		reset(s, center, true)
		pool[i] = s
	end
	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "SpinRainTint"
	tint.Enabled = false
	tint.Parent = Lighting
	local id = TuskConfig.Sounds and TuskConfig.Sounds.Rain
	if id and id ~= "" then
		sound = Instance.new("Sound")
		sound.Name = "SpinRain"
		sound.SoundId = id
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = game:GetService("SoundService")
	end

	-- Banner at the top of the screen: a nailed wooden sign with the news,
	-- and (for Blackmore) a pinned parchment hint under it.
	local new = UITheme.new
	local gui = Instance.new("ScreenGui")
	gui.Name = "WeatherBanner"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	banner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(460, 72), BackgroundTransparency = 1, Visible = false }, gui)
	local sign = new("Frame", { Name = "Sign", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(280, 42) }, banner)
	UITheme.wood(sign, { Planks = 1, Border = 4, Radius = 7, Brackets = true, BracketSize = 12 })
	bannerTitle = UITheme.label(sign, { Name = "Title", Position = UDim2.fromOffset(18, 4), Size = UDim2.new(1, -36, 1, -8), Text = "", Font = UITheme.Font.Title, TextColor3 = Color3.fromRGB(190, 220, 255), TextStrokeColor3 = UITheme.C.WOOD_EDGE, TextStrokeTransparency = 0.3, ZIndex = 3 })
	bannerHint = new("Frame", { Name = "Hint", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(380, 22), Visible = false }, banner)
	UITheme.paper(bannerHint, { Radius = 3 })
	local pin = new("Frame", { BackgroundColor3 = UITheme.C.RED, Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0, 8, 0, -3), ZIndex = 3 }, bannerHint)
	UITheme.corner(pin, 99)
	bannerSub = UITheme.label(bannerHint, { Name = "Text", Position = UDim2.fromOffset(22, 3), Size = UDim2.new(1, -30, 1, -6), Text = "", Font = UITheme.Font.Body, TextColor3 = UITheme.C.INK, ZIndex = 2 })
	-- Remember every visible bit's resting transparency, to fade them together.
	for _, d in ipairs(banner:GetDescendants()) do
		if d:IsA("TextLabel") then
			table.insert(bannerParts, { d, "TextTransparency", d.TextTransparency or 0 })
			table.insert(bannerParts, { d, "TextStrokeTransparency", d.TextStrokeTransparency or 0 })
		elseif d:IsA("Frame") then
			table.insert(bannerParts, { d, "BackgroundTransparency", d.BackgroundTransparency or 0 })
		elseif d:IsA("UIStroke") then
			table.insert(bannerParts, { d, "Transparency", d.Transparency or 0 })
		end
	end

	ReplicatedStorage:GetAttributeChangedSignal("SpinRaining"):Connect(onRainChanged)
	if WeatherClient.isRaining() then
		onRainChanged()
	end
	RunService.RenderStepped:Connect(WeatherClient.step)
end

return WeatherClient
end

-- ======================================================================
-- MODULE: WorldClient
-- ======================================================================
__modules["WorldClient"] = function()
--[[
	WorldClient  (StarterPlayerScripts.SpinClient.WorldClient)
	Client side of the SBR map:
	  * NPC speech bubbles (from NPCService "NPCSay"), shown within 60 studs
	  * drifting desert dust around the camera when the SBRMap is present
	    (particle count follows VFXQuality)
	  * map life (client-only, no server cost): spinning windmills (tag
	    "SpinWindmill"), circling vultures, rolling tumbleweeds, dust devils
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local VFXQuality = __require("VFXQuality")
local Net = __require("Net")
local VFXLib = __require("VFXLib")

local WorldClient = {}
local bubbles = {} -- [npc model] = BillboardGui

local function showBubble(npc, text)
	local head = npc and npc:FindFirstChild("Head")
	local camera = workspace.CurrentCamera
	if not head or not camera or (camera.CFrame.Position - head.Position).Magnitude > 60 then
		return
	end
	if bubbles[npc] then
		bubbles[npc]:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(260, 70)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local frame = Instance.new("TextLabel")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(250, 240, 220)
	frame.TextColor3 = Color3.fromRGB(40, 25, 15)
	frame.Font = Enum.Font.GothamMedium
	frame.TextWrapped = true
	frame.TextSize = 15
	frame.Text = text
	frame.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = frame
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(120, 80, 40)
	s.Thickness = 2
	s.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = frame
	bubbles[npc] = gui
	VFXLib.animate(4.5, function(a)
		local fade = a > 0.85 and (a - 0.85) / 0.15 or 0
		frame.BackgroundTransparency = fade
		frame.TextTransparency = fade
		s.Transparency = fade
	end, function()
		if bubbles[npc] == gui then
			bubbles[npc] = nil
		end
		gui:Destroy()
	end)
end

local function startDust()
	local carrier = VFXLib.anchor(CFrame.new())
	carrier.Size = Vector3.new(80, 20, 80)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Smoke
	emitter.Color = ColorSequence.new(Color3.fromRGB(220, 195, 150))
	emitter.LightInfluence = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.88), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(5, 8)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.EmissionDirection = Enum.NormalId.Right -- drift with the wind
	emitter.Acceleration = Vector3.new(2, 0, 0)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Parent = carrier
	local function rate()
		emitter.Rate = 6 * VFXQuality.get().Particles
	end
	rate()
	VFXQuality.Changed:Connect(rate)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera then
			local p = camera.CFrame.Position
			carrier.CFrame = CFrame.new(p.X, math.max(p.Y - 4, 4), p.Z)
		end
	end)
end

---------------------------------------------------------------------------
-- Map life
---------------------------------------------------------------------------
local function startLife(map)
	local origin = map:GetAttribute("Origin") or Vector3.new()
	local quality = VFXQuality.get()

	-- Vultures circling high over the desert.
	local vultures = {}
	for i = 1, (quality.Particles >= 0.6 and 5 or 2) do
		local bird = Instance.new("Model")
		bird.Name = "Vulture"
		local body = VFXLib.part({ Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(35, 30, 30), Size = Vector3.new(0.8, 0.6, 2) })
		body.Parent = bird
		for _, side in ipairs({ -1, 1 }) do
			local wing = VFXLib.part({ Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(25, 22, 22), Size = Vector3.new(3.2, 0.12, 1.2) })
			wing.Name = side < 0 and "WingL" or "WingR"
			wing.Parent = bird
		end
		bird.Parent = VFXLib.Folder
		vultures[i] = { Model = bird, Center = origin + Vector3.new(math.random(-200, 200), 0, math.random(-200, 200)), Radius = math.random(30, 70), Height = math.random(90, 130), Speed = 0.15 + math.random() * 0.1, Phase = math.random() * 6 }
	end

	-- Tumbleweeds rolling with the wind near the camera.
	local weeds = {}
	local function newWeed()
		local camera = workspace.CurrentCamera
		local base = camera and camera.CFrame.Position or origin
		local size = 1.6 + math.random() * 1.4
		local weed = VFXLib.part({ Shape = Enum.PartType.Ball, Material = Enum.Material.Grass, Color = Color3.fromRGB(150, 120, 75), Size = Vector3.new(size, size, size), Transparency = 0.15 })
		return { Part = weed, Pos = Vector3.new(base.X - 90, 0, base.Z + math.random(-70, 70)), Size = size, Speed = 10 + math.random() * 8, Spin = 0, Life = 0 }
	end
	for i = 1, (quality.Particles >= 0.6 and 6 or 2) do
		weeds[i] = newWeed()
		weeds[i].Pos = weeds[i].Pos + Vector3.new(math.random(0, 160), 0, 0)
	end

	-- Dust devils: a swirling smoke column drifting slowly.
	local devils = {}
	if quality.Particles >= 0.6 then
		for i = 1, 2 do
			local carrier = VFXLib.part({ Transparency = 1, Size = Vector3.new(4, 18, 4) })
			local e = Instance.new("ParticleEmitter")
			e.Texture = VFXLib.Textures.Smoke
			e.Color = ColorSequence.new(Color3.fromRGB(215, 190, 145))
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.7), NumberSequenceKeypoint.new(1, 1) })
			e.Lifetime = NumberRange.new(2, 3)
			e.Speed = NumberRange.new(3, 6)
			e.RotSpeed = NumberRange.new(200, 300)
			e.Rate = 14
			e.EmissionDirection = Enum.NormalId.Top
			e.Shape = Enum.ParticleEmitterShape.Cylinder
			e.Parent = carrier
			devils[i] = { Part = carrier, Pos = origin + Vector3.new(math.random(-350, 350), 9, math.random(-350, 350)), Dir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit }
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		-- Windmills
		for _, hub in ipairs(CollectionService:GetTagged("SpinWindmill")) do
			if hub:IsA("BasePart") and hub:IsDescendantOf(workspace) then
				hub.CFrame = hub.CFrame * CFrame.Angles(0, 0, dt * 1.4)
			end
		end
		-- Vultures
		for _, v in ipairs(vultures) do
			local a = t * v.Speed + v.Phase
			local pos = v.Center + Vector3.new(math.cos(a) * v.Radius, v.Height + math.sin(t * 0.7 + v.Phase) * 4, math.sin(a) * v.Radius)
			local ahead = v.Center + Vector3.new(math.cos(a + 0.05) * v.Radius, v.Height, math.sin(a + 0.05) * v.Radius)
			local cf = CFrame.lookAt(pos, ahead) * CFrame.Angles(0, 0, 0.35)
			local flap = math.sin(t * 3 + v.Phase) * 0.25
			local parts = v.Model:GetChildren()
			for _, p in ipairs(parts) do
				if p.Name == "WingL" then
					p.CFrame = cf * CFrame.new(-1.7, 0, 0) * CFrame.Angles(0, 0, flap)
				elseif p.Name == "WingR" then
					p.CFrame = cf * CFrame.new(1.7, 0, 0) * CFrame.Angles(0, 0, -flap)
				else
					p.CFrame = cf
				end
			end
		end
		-- Tumbleweeds
		for i, w in ipairs(weeds) do
			w.Life = w.Life + dt
			w.Pos = w.Pos + Vector3.new(w.Speed * dt, 0, math.sin(t + i) * dt * 2)
			local ground = workspace:Raycast(w.Pos + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0), params)
			local y = (ground and ground.Position.Y or 0) + w.Size / 2 + math.abs(math.sin(w.Life * 3)) * 1.2
			w.Spin = w.Spin + dt * w.Speed / w.Size
			w.Part.CFrame = CFrame.new(w.Pos.X, y, w.Pos.Z) * CFrame.Angles(0, 0, -w.Spin)
			local camera = workspace.CurrentCamera
			if w.Life > 22 or (camera and (camera.CFrame.Position - w.Pos).Magnitude > 220) then
				w.Part:Destroy()
				weeds[i] = newWeed()
			end
		end
		-- Dust devils
		for _, d in ipairs(devils) do
			d.Pos = d.Pos + d.Dir * dt * 4
			if (d.Pos - origin).Magnitude > 450 then
				d.Dir = -d.Dir
			end
			d.Part.CFrame = CFrame.new(d.Pos)
		end
	end)
end

function WorldClient.init()
	Net.get("WorldFX").OnClientEvent:Connect(function(name, data)
		if name == "NPCSay" and typeof(data) == "table" then
			showBubble(data.NPC, tostring(data.Text))
		end
	end)
	task.spawn(function()
		local map = workspace:WaitForChild("SBRMap", 60)
		if map then
			startDust()
			startLife(map)
		end
	end)
end

return WorldClient
end

-- ======================================================================
-- START
-- ======================================================================

-- Only ONE Spin_Client may run (a second copy draws every Stand and effect
-- twice and lags the game).
if _G.__SpinClientRunning then
	warn("[Spin] Another Spin_Client is already running (" .. tostring(_G.__SpinClientRunning) .. "). This copy (" .. script:GetFullName() .. ") is NOT starting. Delete the extra copy.")
	return
end
_G.__SpinClientRunning = script:GetFullName()

-- Character scripts: each character is its own ModuleScript named like
-- "Gyro_Server" / "Gyro_Client". They're found by name anywhere in the usual
-- places (a SpinCharacters folder is tidy but not required), and anything
-- set up wrong is explained in the Output window.
local __packsLoaded = {}
local function __loadPacks(side)
	local suffix = side == "server" and "_server" or "_client"
	local roots = side == "server"
		and { game:GetService("ServerScriptService"), game:GetService("ServerStorage"), game:GetService("ReplicatedStorage") }
		or { game:GetService("ReplicatedStorage"), game:GetService("ReplicatedFirst") }
	-- Only the real character scripts are loaded (e.g. "Gyro_Server"); other
	-- scripts in the game that happen to end in _Server / _Client are ignored.
	local allowed = {}
	for id in pairs(__require("TuskActRegistry").StartAct) do
		allowed[string.lower(id) .. suffix] = true
	end
	local found = 0
	for _, root in ipairs(roots) do
		for _, pack in ipairs(root:GetDescendants()) do
			local name = string.lower(pack.Name):gsub("%.lua$", ""):gsub("%s", "")
			local builtIn = name == "johnny" .. suffix or name == "map" .. suffix -- (now inside Spin_Server / Spin_Client)
			if builtIn and pack:IsA("LuaSourceContainer") and not __packsLoaded[name] then
				__packsLoaded[name] = true
				print("[Spin] " .. pack:GetFullName() .. " isn't needed any more (it's built into Spin_" .. (side == "server" and "Server" or "Client") .. "). You can delete it.")
			elseif not allowed[name] and not __packsLoaded[name] and pack:IsA("ModuleScript")
				and pack.Parent and pack.Parent.Name == "SpinCharacters" and name:match("^%w+" .. suffix .. "$") then
				-- A character script this copy of the game doesn't know about:
				-- Spin_Server / Spin_Client is older than the character.
				__packsLoaded[name] = true
				warn("[Spin] " .. pack:GetFullName() .. " is a character this Spin_" .. (side == "server" and "Server" or "Client")
					.. " doesn't know yet. Replace Spin_" .. (side == "server" and "Server" or "Client") .. " (and TuskConfig) with the newest version.")
			elseif allowed[name] and not __packsLoaded[name] then
				if pack:IsA("ModuleScript") then
					local ok, install = pcall(require, pack)
					if ok and type(install) == "function" then
						local ok2, err = pcall(install, __modules, __require, __hasModule)
						if ok2 then
							__packsLoaded[name] = true
							found = found + 1
						else
							warn("[Spin] Character script " .. pack:GetFullName() .. " failed: " .. tostring(err))
						end
					else
						warn("[Spin] " .. pack:GetFullName() .. " isn't a character script (did the whole file get pasted in?): " .. tostring(install))
					end
				elseif pack:IsA("LuaSourceContainer") then
					warn("[Spin] " .. pack:GetFullName() .. " is a " .. pack.ClassName .. ". It must be a ModuleScript: delete it, insert a ModuleScript with the same name, and paste the code into that.")
				end
			end
		end
	end
	if side == "server" then
		-- A _Client script the server can see but players can't.
		for _, where in ipairs({ game:GetService("ServerScriptService"), game:GetService("ServerStorage") }) do
			for _, pack in ipairs(where:GetDescendants()) do
				local lname = string.lower(pack.Name):gsub("%.lua$", ""):gsub("%s", "")
				local isPack = false
				for id in pairs(__require("TuskActRegistry").StartAct) do
					if lname == string.lower(id) .. "_client" then
						isPack = true
					end
				end
				if isPack and pack:IsA("LuaSourceContainer") then
					warn("[Spin] " .. pack:GetFullName() .. " is in " .. where.Name .. ", where players can't see it. Move it to ReplicatedStorage > SpinCharacters.")
				end
			end
		end
	end
	return found
end

-- No waiting on the folder (it's optional): just make sure the game has loaded.
if not game:IsLoaded() then
	game.Loaded:Wait()
end
__loadPacks("client")
-- Is anything the server plays missing here? (e.g. DIO is installed on the
-- server but Dio_Client isn't in ReplicatedStorage > SpinCharacters, or this
-- Spin_Client is older than the character): then that character would have
-- no Stand, effects or animations. Say so in Output and on screen.
task.spawn(function()
	local rs = game:GetService("ReplicatedStorage")
	local list
	for _ = 1, 40 do
		list = rs:GetAttribute("SpinInstalledCharacters")
		if list then
			break
		end
		task.wait(0.5)
	end
	if not list then
		return
	end
	local Registry = __require("TuskActRegistry")
	local problems = {}
	for id in string.gmatch(list, "[^,]+") do
		local act = Registry.StartAct[id]
		local info = act and Registry.Acts[act]
		if not info then
			table.insert(problems, id .. ": this Spin_Client is older than the server. Replace Spin_Client with the newest version.")
		elseif info.ClientModule and not __hasModule(info.ClientModule) then
			table.insert(problems, id .. ": " .. id .. "_Client is missing. Put it in ReplicatedStorage > SpinCharacters (as a ModuleScript).")
		end
	end
	for _, p in ipairs(problems) do
		warn("[Spin] No effects or animations for " .. p)
	end
	if #problems > 0 then
		local text = #problems == 1 and problems[1] or (#problems .. " characters have no effects: see the Output window.")
		for _ = 1, 10 do
			local ok = pcall(function()
				game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Spin: setup problem", Text = text, Duration = 20 })
			end)
			if ok then
				break
			end
			task.wait(1)
		end
	end
end)
-- Each system starts on its own: if one fails, the rest (HUD, menus, bounty
-- board) still work, and the Output window says what went wrong.
local function __start(name)
	local ok, err = pcall(function()
		__require(name).init()
	end)
	if not ok then
		warn("[Spin] " .. name .. " failed to start: " .. tostring(err))
	end
end
for _, name in ipairs({ "SettingsUI", "HitFX", "TuskStand", "TuskProjectiles", "TuskSneakController", "TuskController", "WorldClient", "CharacterCard", "CombatUI", "DefenseClient", "BountyUI", "WeatherClient", "CorpseClient", "RaceClient", "Cutscenes", "Cinematic" }) do
	__start(name)
end
print("[Spin] Client ready")
