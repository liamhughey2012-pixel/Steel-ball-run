--[[
	Spin_Client  (LocalScript)
	PUT IT IN: StarterPlayer > StarterPlayerScripts

	Spin Battlegrounds client: controls (PC, controller, mobile), all VFX,
	Tusk Stands, Gyro's Steel Balls, HUD, character card, NPC bubbles, dust.

	Needs these ModuleScripts in ReplicatedStorage: SpinConfig, TuskConfig.
	Works with the Script Spin_Server in ServerScriptService.
]]

-- Safety check: this code must be in a LocalScript in StarterPlayerScripts.
if game:GetService("RunService"):IsServer() then
	error("[Spin] This is the Spin_CLIENT code. It must go in a LocalScript in StarterPlayer > StarterPlayerScripts. Paste Spin_Server.lua into the Script in ServerScriptService instead.")
end

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

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local VFXQuality = __require("VFXQuality")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local TuskStand = __require("TuskStand")

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
		-- Anticipation: a small spinning charge at the fingertip.
		local charge = TuskVFX.CreateEnergyCharge({
			Follow = function()
				return root.Parent and root.CFrame * CFrame.new(0.9, 0.55, -1.6) or nil
			end,
			Color = colors.Cyan,
			Color2 = colors.Ice,
			MaxRadius = 0.5,
			Duration = data.Startup,
			Rings = 1,
			Particles = 0.5,
		})
		task.delay(data.Startup, function()
			charge:Release(data.Direction)
		end)
	elseif data.Move == "NailBarrage" and data.Phase == "Startup" then
		TuskAnimation.play(character, "NailBarrage")
		TuskStand.action(character, "Lunge", { Target = CFrame.new(1.6, 1.2, -1), Duration = data.Startup + data.Count * data.Interval + 0.2 })
		VFXLib.burst((root.CFrame * CFrame.new(0.9, 0.55, -1.6)).Position, { Count = 10, Color = colors.Cyan, Speed = 6, Lifetime = 0.2 })
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
	for _, player in ipairs(Players:GetPlayers()) do
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
	for _, player in ipairs(Players:GetPlayers()) do
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
	Client choreography for Tusk Act 2 (wormhole combat): cyan + violet
	portals, spatial distortion, rotating nails through wormholes.
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
		-- A small portal opens at the fingertip; the nail is fired through it.
		local tip = (root.CFrame * CFrame.new(0.9, 0.55, -2.2)).Position
		Common.portal(tip, tip + data.Direction * 5, 1, data.Startup + 0.2, pal)
	elseif data.Move == "NailDimension" and data.Phase == "Open" then
		if root then
			TuskAnimation.play(character, "NailDimension")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 2, -2), Duration = 0.6 })
		end
		for i, pos in ipairs(data.Portals) do
			Common.portal(pos, data.Center, 2.4, data.OpenTime + 0.55, pal, (i - 1) * 0.06)
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
			Common.portal(pos, center, 3, data.Windup + 1.2, pal, (i - 1) * (data.Windup * 0.5 / #data.Portals))
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
		Common.m1(data, pal)
	elseif name == "M1Finisher" then
		Common.finisher(data, pal)
		Common.portal(data.Position + Vector3.new(0, 1, 0), data.Position + Vector3.new(0, 1, -4), 2.6, 0.35, pal)
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "AbilityImpact" then
		onAbilityImpact(data)
	elseif name == "Portal" then
		Common.portal(data.Position, data.LookAt, data.Radius, data.Duration, pal)
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
		VFXLib.sound(sounds.ChargeFull, root, 0.5, 0.8)
		task.delay(data.Startup, function()
			charge:Release(data.Direction)
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
	for _, player in ipairs(Players:GetPlayers()) do
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

	Top-left character card:
	  * portrait: your uploaded image (TuskConfig.Character.PortraitImage),
	    or a live 3D view of your own avatar
	  * JOHNNY JOESTAR name plate (TuskConfig.Character.Name)
	  * current Stand ("TUSK ACT 2") in that Act's colour
	  * four Act pips that light up as Tusk awakens
	  * health bar with numbers
	Pops and flashes when Tusk evolves.

	DROPDOWN: tap/click the card to open the character list
	(TuskConfig.Roster). Johnny Joestar expands into his four Tusk Acts,
	each with its moves, showing which Act you are on now. Characters that
	aren't finished are shown as IN DEVELOPMENT (not selectable).
]]

local Players = game:GetService("Players")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local VFXLib = __require("VFXLib")

local CharacterCard = {}

local player = Players.LocalPlayer
local DARK = Color3.fromRGB(14, 12, 20)
local GOLD = Color3.fromRGB(255, 205, 90)

local gui, card, portrait, viewport, nameLabel, standLabel, pips, hpFill, hpText, scale, arrow
local dropdown, dropdownList, actRows, rosterRows
-- Declared up here so init() can call them (they are defined further down).
local buildDropdown, refreshDropdown
local shownAct
local open = false
local Net = __require("Net")

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local function stroke(p, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextStrokeTransparency = 0.4
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
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
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(98, 52)
	row.Size = UDim2.fromOffset(120, 12)
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 5)
	layout.Parent = row
	for i = 1, 4 do
		local pip = Instance.new("Frame")
		pip.Size = UDim2.fromOffset(24, 8)
		pip.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		pip.BorderSizePixel = 0
		pip.Parent = row
		corner(pip, 4)
		pips[i] = pip
	end
end

function CharacterCard.init()
	local config = TuskConfig.Character
	gui = Instance.new("ScreenGui")
	gui.Name = "CharacterCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")

	card = Instance.new("Frame")
	card.Name = "Card"
	card.Position = UDim2.fromOffset(12, 10)
	card.Size = UDim2.fromOffset(290, 96)
	card.BackgroundColor3 = DARK
	card.BackgroundTransparency = 0.12
	card.Parent = gui
	corner(card, 12)
	stroke(card, GOLD, 2)
	scale = Instance.new("UIScale")
	scale.Parent = card
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(70, 40, 110), Color3.fromRGB(20, 18, 30))
	gradient.Rotation = 20
	gradient.Parent = card

	-- Portrait frame.
	local frame = Instance.new("Frame")
	frame.Position = UDim2.fromOffset(8, 8)
	frame.Size = UDim2.fromOffset(80, 80)
	frame.BackgroundColor3 = Color3.fromRGB(240, 200, 120)
	frame.ClipsDescendants = true
	frame.Parent = card
	corner(frame, 10)
	stroke(frame, Color3.fromRGB(30, 20, 10), 2)
	local frameGradient = Instance.new("UIGradient")
	frameGradient.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(190, 110, 200))
	frameGradient.Rotation = 90
	frameGradient.Parent = frame
	if config.PortraitImage ~= "" then
		portrait = Instance.new("ImageLabel")
		portrait.BackgroundTransparency = 1
		portrait.Size = UDim2.fromScale(1, 1)
		portrait.Image = config.PortraitImage
		portrait.ScaleType = Enum.ScaleType.Crop
		portrait.Parent = frame
	else
		viewport = Instance.new("ViewportFrame")
		viewport.BackgroundTransparency = 1
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.Ambient = Color3.fromRGB(170, 160, 150)
		viewport.LightColor = Color3.fromRGB(255, 240, 220)
		viewport.LightDirection = Vector3.new(-1, -1, -1)
		viewport.Parent = frame
	end

	nameLabel = label(card, {
		Position = UDim2.fromOffset(98, 6),
		Size = UDim2.new(1, -130, 0, 28),
		Font = Enum.Font.Bangers,
		TextSize = 28,
		TextColor3 = GOLD,
		Text = config.Name,
	})
	standLabel = label(card, {
		Position = UDim2.fromOffset(98, 33),
		Size = UDim2.new(1, -106, 0, 16),
		Font = Enum.Font.GothamBlack,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(200, 220, 255),
		Text = config.Title,
	})
	buildPips(card)

	local hp = Instance.new("Frame")
	hp.Position = UDim2.fromOffset(98, 70)
	hp.Size = UDim2.new(1, -108, 0, 14)
	hp.BackgroundColor3 = Color3.fromRGB(40, 20, 25)
	hp.Parent = card
	corner(hp, 5)
	hpFill = Instance.new("Frame")
	hpFill.BorderSizePixel = 0
	hpFill.BackgroundColor3 = Color3.fromRGB(90, 220, 120)
	hpFill.Size = UDim2.fromScale(1, 1)
	hpFill.Parent = hp
	corner(hpFill, 5)
	hpText = label(hp, {
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		ZIndex = 2,
	})

	-- The whole card is a button that opens the character dropdown.
	arrow = label(card, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(20, 20),
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "▼",
		ZIndex = 3,
	})
	local hit = Instance.new("TextButton")
	hit.Name = "OpenCharacters"
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 4
	hit.Parent = card
	hit.Activated:Connect(CharacterCard.toggle)
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
-- Dropdown
---------------------------------------------------------------------------
local ROW_W = 290

local function chip(parent, text, color, textColor)
	local c = label(parent, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(104, 22),
		Font = Enum.Font.GothamBlack,
		TextSize = 11,
		TextColor3 = textColor or Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 1,
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		Text = text,
	})
	corner(c, 6)
	return c
end

function buildDropdown()
	dropdown = Instance.new("Frame")
	dropdown.Name = "CharacterList"
	dropdown.Position = UDim2.fromOffset(12, 112)
	dropdown.Size = UDim2.fromOffset(ROW_W, 0)
	dropdown.BackgroundColor3 = DARK
	dropdown.BackgroundTransparency = 0.08
	dropdown.ClipsDescendants = true
	dropdown.Visible = false
	dropdown.Parent = gui
	corner(dropdown, 12)
	stroke(dropdown, GOLD, 1.5)

	dropdownList = Instance.new("ScrollingFrame")
	dropdownList.BackgroundTransparency = 1
	dropdownList.BorderSizePixel = 0
	dropdownList.Size = UDim2.fromScale(1, 1)
	dropdownList.CanvasSize = UDim2.new()
	dropdownList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	dropdownList.ScrollBarThickness = 4
	dropdownList.Parent = dropdown
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = dropdownList
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = dropdownList

	label(dropdownList, {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.GothamBlack,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(170, 160, 200),
		Text = "CHARACTERS",
	})

	rosterRows, actRows = {}, {}
	local order = 1
	for _, entry in ipairs(TuskConfig.Roster or {}) do
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		order = order + 1
		row.Size = UDim2.new(1, 0, 0, entry.Note and 62 or 50)
		row.BackgroundColor3 = Color3.fromRGB(28, 24, 40)
		row.Parent = dropdownList
		corner(row, 8)
		local stripe = Instance.new("Frame")
		stripe.Size = UDim2.new(0, 4, 1, -12)
		stripe.Position = UDim2.fromOffset(6, 6)
		stripe.BackgroundColor3 = entry.Color
		stripe.BorderSizePixel = 0
		stripe.Parent = row
		label(row, { Position = UDim2.fromOffset(16, 4), Size = UDim2.new(1, -130, 0, 24), Font = Enum.Font.Bangers, TextSize = 22, TextColor3 = entry.Available and GOLD or Color3.fromRGB(150, 145, 160), Text = entry.Name })
		label(row, { Position = UDim2.fromOffset(16, 27), Size = UDim2.new(1, -130, 0, 16), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = entry.Color, Text = "STAND: " .. entry.Stand })
		if entry.Note then
			label(row, { Position = UDim2.fromOffset(16, 43), Size = UDim2.new(1, -24, 0, 14), Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = Color3.fromRGB(170, 170, 185), Text = entry.Note })
		end
		local status
		if entry.Available then
			status = Instance.new("TextButton")
			status.AnchorPoint = Vector2.new(1, 0)
			status.Position = UDim2.new(1, -8, 0, 12)
			status.Size = UDim2.fromOffset(104, 24)
			status.Font = Enum.Font.GothamBlack
			status.TextSize = 11
			status.AutoButtonColor = true
			status.Parent = row
			corner(status, 6)
			status.Activated:Connect(function()
				Net.get("TuskRequest"):FireServer("Character", entry.Id)
			end)
		else
			status = chip(row, "IN DEVELOPMENT", Color3.fromRGB(60, 58, 72), Color3.fromRGB(190, 185, 200))
			status.AnchorPoint = Vector2.new(1, 0)
			status.Position = UDim2.new(1, -8, 0, 12)
		end
		rosterRows[entry.Id] = { Row = row, Status = status, Entry = entry }

		-- Johnny expands into the four Tusk Acts.
		if entry.Id == "Johnny" then
			for act = 1, 4 do
				local info = Registry.get(act)
				local actRow = Instance.new("Frame")
				actRow.LayoutOrder = order
				order = order + 1
				actRow.Size = UDim2.new(1, 0, 0, 52)
				actRow.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
				actRow.Parent = dropdownList
				corner(actRow, 8)
				local edge = stroke(actRow, info.Theme.Primary, 1.5)
				label(actRow, { Position = UDim2.fromOffset(12, 3), Size = UDim2.new(1, -120, 0, 20), Font = Enum.Font.Bangers, TextSize = 18, TextColor3 = info.Theme.Primary, Text = info.Name })
				label(actRow, { Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -20, 0, 13), Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = Color3.fromRGB(200, 205, 220), TextTruncate = Enum.TextTruncate.AtEnd, Text = "1 " .. info.Abilities[1] .. " · 2 " .. info.Abilities[2] .. " · 3 " .. info.Abilities[3] })
				label(actRow, { Position = UDim2.fromOffset(12, 35), Size = UDim2.new(1, -20, 0, 13), Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = GOLD, TextTruncate = Enum.TextTruncate.AtEnd, Text = "G " .. info.Ultimate .. (info.Next and (" → ACT " .. info.Next) or "  (FINAL FORM)") })
				local state = label(actRow, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 5), Size = UDim2.fromOffset(100, 16), Font = Enum.Font.GothamBlack, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
				actRows[act] = { Row = actRow, Edge = edge, State = state }
			end
		end
	end
end

function refreshDropdown(act)
	if not dropdown then
		return
	end
	-- Each character row: PLAYING (green) or SELECT (blue).
	local current = act and Registry.characterOf(act)
	for id, row in pairs(rosterRows) do
		if row.Entry.Available then
			local playing = current == id
			row.Status.Text = playing and "PLAYING" or "SELECT"
			row.Status.BackgroundColor3 = playing and Color3.fromRGB(40, 120, 70) or Color3.fromRGB(40, 90, 200)
			row.Status.TextColor3 = Color3.new(1, 1, 1)
			row.Status.Active = not playing
		end
	end
	if current ~= "Johnny" then
		act = nil -- Tusk Act rows only light up while playing Johnny
	end
	for i, r in pairs(actRows) do
		if act == i then
			r.State.Text = "◆ YOU ARE HERE"
			r.State.TextColor3 = Color3.new(1, 1, 1)
			r.Row.BackgroundColor3 = Color3.fromRGB(40, 34, 64)
			r.Edge.Thickness = 2.5
			r.Edge.Transparency = 0
		elseif act and i < act then
			r.State.Text = "AWAKENED ✓"
			r.State.TextColor3 = Color3.fromRGB(120, 220, 140)
			r.Row.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
			r.Edge.Thickness = 1
			r.Edge.Transparency = 0.4
		else
			r.State.Text = i == 1 and "START" or "AWAKEN WITH G"
			r.State.TextColor3 = Color3.fromRGB(160, 160, 180)
			r.Row.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
			r.Edge.Thickness = 1
			r.Edge.Transparency = 0.6
		end
	end
end

function CharacterCard.toggle()
	if not dropdown then
		return
	end
	open = not open
	local target = math.min(420, (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 600) - 170)
	refreshDropdown(shownAct)
	if open then
		dropdown.Visible = true
	end
	arrow.Text = open and "▲" or "▼"
	local from = dropdown.Size.Y.Offset
	local to = open and target or 0
	VFXLib.animate(0.2, function(a)
		dropdown.Size = UDim2.fromOffset(ROW_W, from + (to - from) * VFXLib.easeOut(a))
	end, function()
		if not open then
			dropdown.Visible = false
		end
	end)
end

function CharacterCard.pop(color)
	VFXLib.animate(0.5, function(a)
		scale.Scale = 1 + 0.12 * math.sin(a * math.pi)
		card.BackgroundColor3 = color:Lerp(DARK, a)
	end, function()
		scale.Scale = 1
		card.BackgroundColor3 = DARK
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
		local isGyro = act ~= nil and Registry.characterOf(act) == "Gyro"
		-- Name plate follows the character (from TuskConfig.Roster).
		local who = isGyro and "Gyro" or "Johnny"
		for _, entry in ipairs(TuskConfig.Roster or {}) do
			if entry.Id == who then
				nameLabel.Text = entry.Name
			end
		end
		if isGyro then
			standLabel.Text = "STEEL BALL USER"
		else
			standLabel.Text = info and ("STAND  ·  " .. info.Name) or TuskConfig.Character.Title
		end
		standLabel.TextColor3 = info and info.Theme.Primary or Color3.fromRGB(200, 220, 255)
		-- Act pips are Tusk's progression; hidden for Gyro.
		for i, pip in ipairs(pips) do
			pip.Visible = not isGyro
			local on = act ~= nil and i <= act
			local theme = Registry.get(i) and Registry.get(i).Theme.Primary or GOLD
			pip.BackgroundColor3 = on and theme or Color3.fromRGB(60, 60, 80)
		end
		if isGyro then
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
-- MODULE: Gyro
-- ======================================================================
__modules["Gyro"] = function()
--[[
	TuskActVFX.Gyro  (StarterPlayerScripts.SpinClient.TuskActVFX.Gyro)

	Client visuals for Gyro Zeppeli (Steel Ball moveset):
	  * the green Steel Ball always spinning in Gyro's right hand
	    (hidden while it's thrown, back when it returns)
	  * thrown / returning ball with white-green spin rings and a trail
	  * SPIN TORNADO: a travelling green funnel of spinning rings
	  * Spin Vibration ripples, and shaking sparks on anyone hit by the Spin
	  * Gyro's own animations (pitch, bowl, kick, palm press...) and his
	    ball-in-hand idle stance
	  * BALL BREAKER: spiral build-up, giant ball, spinning vortex, burst
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local VFXQuality = __require("VFXQuality")
local Net = __require("Net")
local SteelBallModel = __require("SteelBallModel")
local WreckingBallModel = __require("WreckingBallModel")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Common = __require("TuskActCommon")

local Gyro = {}
local pal = Common.palette(5)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer
local GYRO_ACT = 5

local held = {} -- [character] = { Ball, Weld, Grip, Angle, HiddenUntil }
local shakes = {} -- [character] = attachment with sparkles
local balls = {} -- [projectile id] = visual

local function handOf(character)
	local hand = character:FindFirstChild("RightHand")
	if hand then
		return hand, CFrame.new(0, -0.5, -0.15)
	end
	local arm = character:FindFirstChild("Right Arm")
	if arm then
		return arm, CFrame.new(0, -1.15, -0.15)
	end
	return nil
end

local function setHidden(entry, hidden)
	for _, d in ipairs(entry.Ball:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
	entry.Hidden = hidden
end

---------------------------------------------------------------------------
-- Ball always in Gyro's hand
---------------------------------------------------------------------------
local function updateHeld(dt)
	local seen = {}
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character:GetAttribute("TuskAct") == GYRO_ACT then
			local hand, grip = handOf(character)
			if hand then
				seen[character] = true
				local entry = held[character]
				if not entry then
					local ball = SteelBallModel.build(0.9, VFXQuality.get().Grooves)
					local core = ball.PrimaryPart
					core.Anchored = false
					ball:PivotTo(hand.CFrame * grip)
					local weld = Instance.new("Weld")
					weld.Part0 = hand
					weld.Part1 = core
					weld.C0 = grip
					weld.Parent = core
					ball.Parent = VFXLib.Folder
					entry = { Ball = ball, Weld = weld, Grip = grip, Angle = 0, HiddenUntil = 0, Spin = 8, Character = character }
					held[character] = entry
					TuskAnimation.hold(character, "GyroIdle") -- ball held up at the chest
				end
				entry.Angle = entry.Angle + dt * entry.Spin
				entry.Weld.C0 = entry.Grip * CFrame.Angles(entry.Angle, entry.Angle * 0.3, 0)
				local hide = now < entry.HiddenUntil
				if hide ~= (entry.Hidden == true) then
					setHidden(entry, hide)
				end
			end
		end
	end
	for character, entry in pairs(held) do
		if not seen[character] then
			held[character] = nil
			entry.Ball:Destroy()
			if character.Parent then
				TuskAnimation.stopHold(character, "GyroIdle")
			end
		end
	end
end

-- Sparkly "shaking" on anyone the Spin is vibrating.
local function updateShakes()
	local seen = {}
	local candidates = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(candidates, player.Character)
		end
	end
	local dummies = workspace:FindFirstChild("SpinTestDummies")
	if dummies then
		for _, d in ipairs(dummies:GetChildren()) do
			table.insert(candidates, d)
		end
	end
	for _, model in ipairs(candidates) do
		if model:IsA("Model") and model:GetAttribute("GyroSpinShake") then
			local root = model:FindFirstChild("HumanoidRootPart")
			if root then
				seen[model] = true
				if not shakes[model] then
					local a = Instance.new("Attachment")
					a.Name = "GyroSpinShake"
					a.Parent = root
					local e = Instance.new("ParticleEmitter")
					e.Texture = VFXLib.Textures.Sparkle
					e.Color = ColorSequence.new(pal.Light, pal.Main)
					e.LightEmission = 1
					e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
					e.Lifetime = NumberRange.new(0.2, 0.35)
					e.Speed = NumberRange.new(4, 8)
					e.SpreadAngle = Vector2.new(180, 180)
					e.Rate = 30 * VFXQuality.get().Particles
					e.Parent = a
					shakes[model] = a
				end
			end
		end
	end
	for model, a in pairs(shakes) do
		if not seen[model] then
			shakes[model] = nil
			a:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- Ball projectiles (server Kind "GyroBall")
---------------------------------------------------------------------------
local function spawnBall(data)
	local style = data.Visual and data.Visual.Style or "Throw"
	local ball
	local rings = {}
	if style == "Wrecking" then
		ball = WreckingBallModel.build(0.7, false)
	else
		local size = style == "Breaker" and (data.Visual.Scale or 6) or 1.1
		ball = SteelBallModel.build(size, VFXQuality.get().Grooves)
		local ringCount = style == "Breaker" and 3 or 2
		for i = 1, ringCount do
			rings[i] = VFXLib.ring({ Radius = size * 0.6 + i * (style == "Breaker" and 0.8 or 0.25), Width = style == "Breaker" and 0.35 or 0.1, Color = i % 2 == 1 and pal.Light or pal.Main, Transparency = 0.1 })
		end
	end
	ball.PrimaryPart.Anchored = true
	ball.Parent = VFXLib.Folder
	local core = ball.PrimaryPart
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = core
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = core
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = style == "Wrecking" and ColorSequence.new(Color3.fromRGB(255, 160, 60)) or ColorSequence.new(pal.Light, pal.Main)
	trail.LightEmission = 1
	trail.Lifetime = style == "Breaker" and 0.5 or 0.25
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = core
	-- Steel Ball Throw / return: green glow, spiral Spin trails, afterimages.
	local glow, helix
	if style == "Throw" or style == "Return" then
		glow = VFXLib.part({ Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Color = pal.Main, Transparency = 0.1, Size = Vector3.new(1.9, 1.9, 1.9) })
		helix = VFXLib.anchor(CFrame.new(data.Origin))
		local strands = VFXQuality.get().RingSegments > 12 and 3 or 2
		for i = 1, strands do
			local th = (i - 1) / strands * math.pi * 2
			local dir = Vector3.new(math.cos(th), math.sin(th), 0)
			local h0 = Instance.new("Attachment")
			h0.Position = dir * 0.9
			h0.Parent = helix
			local h1 = Instance.new("Attachment")
			h1.Position = dir * 1.05
			h1.Parent = helix
			local t = Instance.new("Trail")
			t.Attachment0 = h0
			t.Attachment1 = h1
			t.Color = ColorSequence.new(Color3.new(1, 1, 1), pal.Main)
			t.LightEmission = 1
			t.LightInfluence = 0
			t.FaceCamera = true
			t.Lifetime = 0.3
			t.WidthScale = NumberSequence.new(1, 0.1)
			t.Transparency = NumberSequence.new(0, 1)
			t.Parent = helix
		end
	end
	local whirl
	if style == "Breaker" then
		-- Spinning spiral trailing the giant ball.
		whirl = VFXLib.anchor(CFrame.new(data.Origin))
		local prev
		for i = 0, 16 do
			local t = i / 16
			local angle = t * math.pi * 3
			local r = 1 + t * 4
			local a = Instance.new("Attachment")
			a.Position = Vector3.new(math.cos(angle) * r, math.sin(angle) * r, t * 3)
			a.Parent = whirl
			if prev then
				local b = Instance.new("Beam")
				b.Attachment0 = prev
				b.Attachment1 = a
				b.FaceCamera = true
				b.LightEmission = 1
				b.Width0 = 0.5 * (1 - t * 0.6)
				b.Width1 = 0.5 * (1 - t * 0.6)
				b.Color = ColorSequence.new(pal.Light:Lerp(pal.Main, t))
				b.Transparency = NumberSequence.new(t * 0.7)
				b.Parent = whirl
			end
			prev = a
		end
	end
	balls[data.Id] = {
		Glow = glow,
		Helix = helix,
		Whirl = whirl,
		Model = ball,
		Rings = rings,
		Style = style,
		Origin = data.Origin,
		Direction = data.Direction,
		Speed = data.Speed,
		Range = data.Range,
		ServerTime = data.ServerTime,
		Spin = 0,
		Expire = os.clock() + data.Range / data.Speed + 1.5,
		NextGhost = 0,
	}
	VFXLib.sound(sounds.NailFire, data.Origin, 0.5, style == "Wrecking" and 1.3 or 0.8)
	if style ~= "Return" then
		VFXLib.burst(data.Origin, { Count = 14, Color = pal.Light, Speed = 22, Spread = 30, Direction = data.Direction, Lifetime = 0.3 })
	end
	if style == "Throw" then
		-- Release: a spin ring blasts off the hand along the throw, plus a flash.
		local axis = CFrame.lookAt(data.Origin, data.Origin + data.Direction) * CFrame.Angles(math.pi / 2, 0, 0)
		TuskVFX.CreateRotationalShockwave(axis, { Radius = 3.2, Layers = 2, Color = pal.Light, Color2 = pal.Main, Particles = 0, Width = 0.25, Duration = 0.3, Spin = 6 })
		TuskVFX.CreateImpactStar(data.Origin, { Size = 3, Rays = 6, Color = pal.Main, Color2 = pal.Light, Duration = 0.18 })
		VFXLib.flash(data.Origin, pal.Main, 4, 16, 0.2)
	end
end

local function removeBall(v)
	for _, ring in ipairs(v.Rings) do
		ring:Destroy()
	end
	if v.Whirl then
		v.Whirl:Destroy()
	end
	if v.Glow then
		v.Glow:Destroy()
	end
	if v.Helix then
		Debris:AddItem(v.Helix, 0.4) -- let the spiral trails finish fading
		for _, t in ipairs(v.Helix:GetChildren()) do
			if t:IsA("Trail") then
				t.Enabled = false
			end
		end
	end
	v.Model:Destroy()
end

local function endBall(data)
	local v = balls[data.Id]
	if v then
		balls[data.Id] = nil
		removeBall(v)
	end
	local style = data.Visual and data.Visual.Style or "Throw"
	if style == "Breaker" then
		return -- the vortex event takes over
	end
	if style == "Wrecking" then
		VFXLib.burst(data.Position, { Count = 10, Color = Color3.fromRGB(255, 170, 70), Speed = 25, Lifetime = 0.3, Acceleration = Vector3.new(0, -50, 0) })
		VFXLib.sound(sounds.NailImpact, data.Position, 0.4, 1.3)
	elseif style == "Throw" then
		TuskVFX.CreateImpact(data.Position, data.Normal, { Size = 1.3, Radius = 4.5, Layers = 3, Color = pal.Main, Color2 = pal.Light, Sound = sounds.NailImpact, Pitch = 0.8 })
		-- The Spin keeps drilling: two late ripples spiral out from the hit.
		local normal = data.Normal or Vector3.new(0, 1, 0)
		local axis = CFrame.lookAt(data.Position, data.Position + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
		for i = 1, 2 do
			task.delay(0.08 * i, function()
				TuskVFX.CreateRotationalShockwave(axis, { Radius = 3 + i * 2, Layers = 1, Color = pal.Light, Color2 = pal.Main, Particles = 0.5, Width = 0.2, Duration = 0.35, Spin = 8 })
			end)
		end
		if normal.Y > 0.6 then
			TuskVFX.CreateGroundCracks(data.Position, { Radius = 5, Count = 5, Color = pal.Main, Duration = 1.2 })
		end
		CameraFX.shakeAt(data.Position, 0.4, 50)
	end
end

local function stepBalls(dt)
	local serverNow = workspace:GetServerTimeNow()
	local now = os.clock()
	for id, v in pairs(balls) do
		local distance = math.min(v.Speed * (serverNow - v.ServerTime), v.Range)
		local pos = v.Origin + v.Direction * distance
		v.Spin = v.Spin + dt * (v.Style == "Breaker" and 10 or 25)
		local facing = CFrame.lookAt(pos, pos + v.Direction)
		v.Model:PivotTo(facing * CFrame.Angles(-v.Spin, 0, v.Spin * 0.2))
		local axis = facing * CFrame.Angles(math.pi / 2, 0, 0)
		for i, ring in ipairs(v.Rings) do
			ring:SetCFrame(axis * CFrame.Angles(0.5 * i * math.sin(v.Spin * 0.2), v.Spin * (0.4 + i * 0.2) * (i % 2 == 0 and -1 or 1), 0.3 * i))
		end
		if v.Style == "Breaker" and now >= v.NextGhost then
			v.NextGhost = now + 0.05
			VFXLib.afterimage(facing, 4, pal.Main)
			if math.random() < 0.2 then
				TuskVFX.CreateDistortion(pos, { Radius = 4, Duration = 0.25 })
			end
		end
		if v.Whirl then
			v.Whirl.CFrame = facing * CFrame.new(0, 0, 3.5) * CFrame.Angles(0, 0, v.Spin * 0.5)
		end
		if v.Glow then
			local pulse = 1.8 + math.sin(v.Spin * 0.8) * 0.25
			v.Glow.Size = Vector3.new(pulse, pulse, pulse)
			v.Glow.CFrame = facing
		end
		if v.Helix then
			v.Helix.CFrame = facing * CFrame.Angles(0, 0, v.Spin * 0.6)
			if v.Style == "Throw" and VFXQuality.get().Afterimages and now >= v.NextGhost then
				v.NextGhost = now + 0.05
				VFXLib.afterimage(facing, 1, pal.Light)
			end
		end
		if now > v.Expire then
			balls[id] = nil
			removeBall(v)
		end
	end
end

---------------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------------
local vibrationStartup, vibrationHit -- defined below (they use the spiral helpers)

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local entry = character and held[character]
	if data.Move == "SteelBallThrow" then
		if data.Phase == "Startup" and root then
			TuskAnimation.play(character, "GyroThrow")
			-- Wind-up: the ball spins faster and faster inside two whirling rings.
			for i = 1, 2 do
				TuskVFX.CreateSpinRing({
					Follow = function()
						local hand = handOf(character)
						return hand and hand.Parent and hand.CFrame * CFrame.new(0, -0.6, 0) or nil
					end,
					Tilt = CFrame.Angles(0.9 * i, 0, 0.6 * i),
					Radius = 0.9 + i * 0.3,
					Width = 0.08,
					Color = i == 1 and pal.Light or pal.Main,
					RotationSpeed = 10 + i * 4,
					Duration = data.Startup or 0.3,
				})
			end
			if entry then
				entry.Spin = 30
				task.delay(data.Startup, function()
					entry.HiddenUntil = os.clock() + 4 -- until it's caught again
					entry.Spin = 8
				end)
			end
		elseif data.Phase == "Caught" and entry then
			entry.HiddenUntil = 0
			if root then
				VFXLib.burst(root.Position + Vector3.new(0, 1, 0), { Count = 8, Color = pal.Light, Speed = 6, Lifetime = 0.25 })
			end
		end
	elseif data.Move == "SpinTornado" and data.Phase == "Startup" and root then
		TuskAnimation.play(character, "GyroBowl")
		TuskVFX.CreateMagicCircle(CFrame.new(root.Position - Vector3.new(0, 2.9, 0)), { Radius = 4, Color = pal.Main, Color2 = pal.Light, Duration = (data.Startup or 0.3) + 0.3, RotationSpeed = 5, Points = 5 })
		VFXLib.burst(root.Position - Vector3.new(0, 2.5, 0), { Count = 12, Color = pal.Light, Speed = 10, Spread = 40, Direction = Vector3.new(0, 1, 0), Lifetime = 0.4 })
		if entry then
			entry.Spin = 40
			task.delay(data.Startup, function()
				entry.HiddenUntil = os.clock() + 2.6 -- the ball becomes the tornado
				entry.Spin = 8
			end)
		end
	elseif data.Move == "SpinVibration" then
		if data.Phase == "Startup" and root then
			TuskAnimation.play(character, "GyroPalm")
			if entry then
				entry.Spin = 45
				task.delay(0.6, function()
					entry.Spin = 8
				end)
			end
			vibrationStartup(character, root, data)
		elseif data.Phase == "Hit" then
			vibrationHit(character, root, data)
		end
	end
end

-- Logarithmic spiral of beams (the Spin's "golden ratio" spiral, in green/white).
local function spiral(cframe, size, duration)
	local carrier = VFXLib.anchor(cframe)
	local prev
	local points = VFXQuality.get().RingSegments
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
			b.Width0 = 0.18
			b.Width1 = 0.18
			b.Color = ColorSequence.new(pal.Light:Lerp(pal.Main, t))
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

-- The Golden Rectangle: nested golden-ratio rectangles with the spiral
-- drawn through them (green/white Spin energy), growing and turning.
local function goldenRectangle(cframe, size, duration)
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
	-- Outer rectangle, then 6 nested squares cut off in turn (golden subdivision).
	local x0, y0, w, h = -size * phi / 2, -size / 2, size * phi, size
	local spiralPoints = {}
	for i = 0, 6 do
		local color = pal.Light:Lerp(pal.Main, i / 6)
		local width = 0.16 * (1 - i * 0.1)
		line(Vector3.new(x0, y0, 0), Vector3.new(x0 + w, y0, 0), width, color)
		line(Vector3.new(x0 + w, y0, 0), Vector3.new(x0 + w, y0 + h, 0), width, color)
		line(Vector3.new(x0 + w, y0 + h, 0), Vector3.new(x0, y0 + h, 0), width, color)
		line(Vector3.new(x0, y0 + h, 0), Vector3.new(x0, y0, 0), width, color)
		-- Cut a square off the rectangle (rotating which side each time).
		local side = i % 4
		local sq = math.min(w, h)
		local cx, cy
		if side == 0 then
			cx, cy = x0 + sq, y0 + sq
			x0, w = x0 + sq, w - sq
		elseif side == 1 then
			cx, cy = x0 + w - sq, y0 + sq
			y0, h = y0 + sq, h - sq
		elseif side == 2 then
			cx, cy = x0 + w - sq, y0 + h - sq
			w = w - sq
		else
			cx, cy = x0 + sq, y0 + h - sq
			h = h - sq
		end
		table.insert(spiralPoints, { cx, cy, sq, side })
	end
	-- Quarter-circle arcs through the squares = the golden spiral.
	local prev
	for _, q in ipairs(spiralPoints) do
		for k = 0, 4 do
			local angle = (q[4] * math.pi / 2) + math.pi + k / 4 * (math.pi / 2)
			local p = Vector3.new(q[1] + math.cos(angle) * q[3], q[2] + math.sin(angle) * q[3], -0.05)
			if prev then
				line(prev, p, 0.22, pal.Light)
			end
			prev = p
		end
	end
	VFXLib.animate(duration, function(a, dt)
		local grow = VFXLib.easeOut(math.min(a * 2.5, 1))
		carrier.CFrame = cframe * CFrame.Angles(0, 0, a * math.pi * 0.6)
		for _, child in ipairs(carrier:GetChildren()) do
			if child:IsA("Beam") then
				child.Transparency = NumberSequence.new(math.clamp(1 - grow + math.max(0, a - 0.85) / 0.15, 0, 1))
			end
		end
	end, function()
		carrier:Destroy()
	end)
end

---------------------------------------------------------------------------
-- SPIN VIBRATION: Gyro presses the spinning ball into the target and the
-- Spin shakes everything around it.
---------------------------------------------------------------------------
-- Zigzag "vibration" lines that jitter every frame while they shoot outward.
local function vibrationLines(axisCF, count, length, duration)
	local carrier = VFXLib.anchor(axisCF)
	local lines = {}
	local points = 7
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local dir = Vector3.new(math.cos(angle), math.sin(angle), -0.6).Unit
		local side = dir:Cross(Vector3.new(0, 0, 1))
		if side.Magnitude < 0.01 then
			side = Vector3.new(1, 0, 0)
		end
		local atts = {}
		for k = 0, points do
			local a = Instance.new("Attachment")
			a.Parent = carrier
			atts[k] = a
			if k > 0 then
				local b = Instance.new("Beam")
				b.Attachment0 = atts[k - 1]
				b.Attachment1 = a
				b.FaceCamera = true
				b.LightEmission = 1
				b.LightInfluence = 0
				b.Segments = 1
				b.Width0 = 0.22 * (1 - (k - 1) / points)
				b.Width1 = 0.22 * (1 - k / points)
				b.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(pal.Main, k / points))
				b.Parent = carrier
			end
		end
		lines[i] = { Atts = atts, Dir = dir, Side = side.Unit }
	end
	VFXLib.animate(duration, function(a)
		local reach = length * VFXLib.easeOut(a)
		local shake = 0.45 * (1 - a)
		for _, line in ipairs(lines) do
			for k = 0, points do
				local t = k / points
				local zig = (k % 2 == 0 and 1 or -1) * shake * (0.6 + math.random() * 0.8)
				line.Atts[k].Position = line.Dir * (0.6 + reach * t) + line.Side * zig
			end
		end
		local fade = NumberSequence.new(math.clamp((a - 0.4) / 0.6, 0, 1))
		for _, b in ipairs(carrier:GetChildren()) do
			if b:IsA("Beam") then
				b.Transparency = fade
			end
		end
	end, function()
		carrier:Destroy()
	end)
end

function vibrationStartup(character, root, data)
	local windup = data.Windup or 0.35
	-- The ball in hand winds up inside tight, fast rings + gathering energy.
	for i = 1, 3 do
		TuskVFX.CreateSpinRing({
			Follow = function()
				local hand = handOf(character)
				return hand and hand.Parent and hand.CFrame * CFrame.new(0, -0.6, 0) or nil
			end,
			Tilt = CFrame.Angles(0.8 * i, 0.4 * i, 0.5 * i),
			Radius = 0.6 + i * 0.22,
			Width = 0.07,
			Color = i % 2 == 1 and pal.Light or pal.Main,
			RotationSpeed = 14 + i * 5,
			Duration = windup + 0.15,
		})
	end
	local charge = TuskVFX.CreateEnergyCharge({
		Follow = function()
			local hand = handOf(character)
			return hand and hand.Parent and hand.CFrame * CFrame.new(0, -0.6, 0) or nil
		end,
		Color = pal.Main,
		Color2 = pal.Light,
		MaxRadius = 0.9,
		Duration = windup,
		Rings = 2,
	})
	task.delay(windup, function()
		charge:Release(root and root.CFrame.LookVector)
	end)
	VFXLib.sound(sounds.ChargeLoop, root, 0.35, 1.8)
end

function vibrationHit(character, root, data)
	local pos = data.Position
	local look = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
	local facing = CFrame.lookAt(pos, pos + look)
	-- 1. contact: flash + starburst + a spinning golden spiral pressed into the air
	VFXLib.flash(pos, pal.Light, 6, 20, 0.25)
	TuskVFX.CreateImpactStar(pos, { Size = data.Hit and 6 or 3.5, Rays = 9, Color = pal.Main, Color2 = pal.Light, Duration = 0.3 })
	spiral(facing, data.Hit and 3.2 or 2.2, 0.45)
	if data.Hit then
		goldenRectangle(facing * CFrame.new(0, 0, -0.4), 2.4, 0.5)
	end
	-- 2. vibration: jittering zigzag lines + layered ripples pushed forward
	vibrationLines(facing, VFXQuality.get().RingSegments > 12 and 10 or 6, data.Hit and 7 or 4.5, 0.4)
	local axis = facing * CFrame.Angles(math.pi / 2, 0, 0)
	for i = 1, 4 do
		task.delay(i * 0.05, function()
			TuskVFX.CreateRotationalShockwave(axis * CFrame.new(0, -i * 0.9, 0), { Radius = 1.5 + i * 1.3, Layers = 1, Color = i % 2 == 1 and pal.Light or pal.Main, Color2 = pal.Main, Particles = i == 1 and 0.6 or 0, Width = 0.22, Duration = 0.28, Spin = (i % 2 == 1 and 7 or -7) })
		end)
	end
	TuskVFX.CreateDistortion(pos, { Radius = data.Hit and 4 or 2.5, Duration = 0.3 })
	-- 3. on hit: the ground trembles under the target
	if data.Hit then
		TuskVFX.CreateGroundCracks(pos, { Radius = 6, Count = 6, Color = pal.Main, Duration = 1.4 })
		VFXLib.burst(pos, { Count = 20, Color = pal.Light, Speed = 26, Lifetime = 0.35, Spread = 60, Direction = look })
	end
	VFXLib.sound(sounds.Hit, pos, 0.7, 0.7)
	VFXLib.sound(sounds.NailImpact, pos, 0.4, 1.4)
	if Common.isLocal(character) then
		CameraFX.shake(data.Hit and 0.55 or 0.25, 0.35)
		if data.Hit then
			CameraFX.fovPunch(6, 0.25)
		end
	end
	CameraFX.shakeAt(pos, 0.35, 40)
end


-- The Ball Breaker spirit: a glowing ghostly skeletal figure (ForceField
-- material shimmers) that rises out of the vortex, spins, then shatters.
local function breakerSpirit(position, duration)
	local quality = VFXQuality.get()
	local bits = {}
	local function bone(size, offset, ellipsoid)
		local p = VFXLib.part({ Material = Enum.Material.ForceField, Color = pal.Light, Size = size, Transparency = 0 })
		if ellipsoid then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		table.insert(bits, { Part = p, Offset = offset, Size = size })
	end
	bone(Vector3.new(2.4, 2.8, 2.4), CFrame.new(0, 7.5, 0), true) -- skull
	bone(Vector3.new(0.5, 0.6, 0.3), CFrame.new(-0.5, 7.4, -1.1), true) -- eye
	bone(Vector3.new(0.5, 0.6, 0.3), CFrame.new(0.5, 7.4, -1.1), true) -- eye
	bone(Vector3.new(0.5, 3.4, 0.5), CFrame.new(0, 4.5, 0.3), false) -- spine
	for i = 0, (quality.RingSegments > 12 and 3 or 1) do -- ribs
		bone(Vector3.new(3.4 - i * 0.35, 0.35, 1.8), CFrame.new(0, 5.6 - i * 0.7, 0), true)
	end
	for _, side in ipairs({ -1, 1 }) do -- arms reaching out
		bone(Vector3.new(0.45, 3.2, 0.45), CFrame.new(side * 2.4, 5.2, -0.4) * CFrame.Angles(0, 0, side * 1.1), false)
		bone(Vector3.new(0.9, 0.9, 0.9), CFrame.new(side * 3.8, 4.4, -0.8), true)
	end
	local light
	if quality.Lights then
		light = Instance.new("PointLight")
		light.Color = pal.Main
		light.Range = 30
		light.Brightness = 4
		light.Parent = bits[1].Part
	end
	local spin = 0
	VFXLib.animate(duration, function(a, dt)
		spin = spin + (dt or 0) * (1.5 + a * 4)
		local rise = VFXLib.easeOut(math.min(a / 0.3, 1))
		local base = CFrame.new(position + Vector3.new(0, -4 + rise * 4, 0)) * CFrame.Angles(0, spin, 0)
		for _, b in ipairs(bits) do
			b.Part.CFrame = base * b.Offset
			b.Part.Size = b.Size * (0.4 + rise * 0.6)
			b.Part.Transparency = 0.15 + math.sin(a * 30) * 0.08
		end
	end, function()
		-- Shatter: every bone bursts into sparks.
		for _, b in ipairs(bits) do
			VFXLib.burst(b.Part.Position, { Count = 6, Color = pal.Light, Speed = 30, Lifetime = 0.5 })
			b.Part:Destroy()
		end
	end)
end


local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Start" and root then
		TuskAnimation.play(character, "GyroBreakerCharge")
		VFXLib.sound(sounds.AwakeningBuild, root, 0.9, 0.9)
		local entry = held[character]
		if entry then
			entry.Spin = 60
		end
		goldenRectangle(root.CFrame * CFrame.new(0, 2.2, -3.5), 3.2, data.Windup + 0.2)
		-- Three rings spin up around the held ball.
		for i = 1, 3 do
			TuskVFX.CreateSpinRing({
				Follow = function()
					local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
					return hand and hand.Parent and hand.CFrame * CFrame.new(0, -0.6, -0.2) or nil
				end,
				Tilt = CFrame.Angles(0.7 * i, 0, 0.5 * i),
				Radius = 0.9 + i * 0.35,
				Width = 0.1,
				Color = i % 2 == 1 and pal.Light or pal.Main,
				RotationSpeed = 6 + i * 3,
				Duration = data.Windup + 0.2,
			})
		end
		VFXLib.burst(root.Position - Vector3.new(0, 2.5, 0), { Count = 30, Color = pal.Light, Speed = 12, Spread = 25, Direction = Vector3.new(0, 1, 0), Lifetime = 1 })
		TuskVFX.CreateMagicCircle(CFrame.new(root.Position - Vector3.new(0, 2.9, 0)), { Radius = 8, Color = pal.Main, Color2 = pal.Light, Duration = data.Windup + 0.3, RotationSpeed = 2, Points = 5 })
		local charge = TuskVFX.CreateEnergyCharge({
			Follow = function()
				return root.Parent and root.CFrame * CFrame.new(0.9, 0.8, -1.8) or nil
			end,
			Color = pal.Main,
			Color2 = pal.Light,
			MaxRadius = 1.6,
			Duration = data.Windup,
			Rings = 3,
		})
		task.delay(data.Windup, function()
			charge:Release()
		end)
		if Common.isLocal(character) then
			CameraFX.setFovHold(-10)
		end
	elseif data.Phase == "Release" then
		local entry = character and held[character]
		if entry then
			entry.Spin = 8
		end
		if character then
			TuskAnimation.play(character, "GyroThrow")
		end
		VFXLib.flash(data.Position, pal.Light, 10, 40, 0.5)
		if Common.isLocal(character) then
			CameraFX.setFovHold(0)
			CameraFX.fovPunch(16, 0.6)
			CameraFX.speedLines(0.45, pal.Light)
		end
	elseif data.Phase == "Vortex" then
		local pos = data.Position
		local ground = CFrame.new(pos - Vector3.new(0, 1, 0))
		for i = 1, 3 do
			TuskVFX.CreateSpinRing({ CFrame = ground * CFrame.new(0, i * 1.6, 0), Tilt = CFrame.Angles(0.15 * i, 0, 0), Radius = data.Radius * (1.05 - i * 0.2), Width = 0.4, Color = i % 2 == 1 and pal.Main or pal.Light, RotationSpeed = (5 + i * 2) * (i % 2 == 0 and -1 or 1), Duration = data.Duration })
		end
		TuskVFX.CreateMagicCircle(ground, { Radius = data.Radius, Color = pal.Main, Color2 = pal.Light, Duration = data.Duration, RotationSpeed = 3, Points = 6 })
		local vortexCore = TuskVFX.CreateEnergyCharge({ CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)), Color = pal.Main, Color2 = pal.Light, MaxRadius = 3, Duration = data.Duration, Rings = 3 })
		task.delay(data.Duration, function()
			vortexCore:Release()
		end)
		spiral(CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(-math.pi / 2, 0, 0), data.Radius * 0.8, data.Duration)
		VFXLib.sound(sounds.ChargeLoop, pos, 0.8, 0.6)
		breakerSpirit(pos, data.Duration)
		-- Rings that shrink inward show the pull.
		local pulses = math.floor(data.Duration / 0.4)
		for i = 0, pulses - 1 do
			task.delay(i * 0.4, function()
				local ring = VFXLib.ring({ CFrame = ground * CFrame.new(0, 0.3, 0), Radius = data.Radius * 1.3, Width = 0.3, Color = pal.Light, Transparency = 0.2 })
				VFXLib.animate(0.4, function(a)
					ring:SetRadius(data.Radius * 1.3 * (1 - a * 0.85))
					ring:SetTransparency(0.2 + a * 0.8)
				end, function()
					ring:Destroy()
				end)
			end)
		end
		-- Dust swirling in.
		local swirl = VFXLib.anchor(CFrame.new(pos), data.Duration + 1)
		swirl.Shape = Enum.PartType.Ball
		swirl.Size = Vector3.new(data.Radius * 2.4, data.Radius * 2.4, data.Radius * 2.4)
		local dust = Instance.new("ParticleEmitter")
		dust.Texture = VFXLib.Textures.Smoke
		dust.Shape = Enum.ParticleEmitterShape.Sphere
		dust.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		dust.Color = ColorSequence.new(Color3.fromRGB(205, 185, 140))
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 1) })
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1) })
		dust.Lifetime = NumberRange.new(0.6, 0.8)
		dust.Speed = NumberRange.new(data.Radius * 1.8, data.Radius * 2.2)
		dust.RotSpeed = NumberRange.new(200, 300)
		dust.Rate = 25 * VFXQuality.get().Particles
		dust.Parent = swirl
		task.delay(data.Duration, function()
			dust.Enabled = false
		end)
	elseif data.Phase == "Burst" then
		local pos = data.Position
		TuskVFX.CreateRotationalShockwave(CFrame.new(pos - Vector3.new(0, 1, 0)), { Radius = data.Radius * 1.6, Layers = 4, Color = pal.Main, Color2 = pal.Light, Ground = true, Particles = 3, Width = 1, Duration = 0.7 })
		TuskVFX.CreateDistortion(pos, { Radius = 10, Duration = 0.5 })
		TuskVFX.CreateRotationalShockwave(CFrame.new(pos + Vector3.new(0, 5, 0)) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = data.Radius, Layers = 2, Color = pal.Light, Color2 = pal.Main, Particles = 0, Width = 0.6 })
		TuskVFX.CreateEnergyPillar(pos - Vector3.new(0, 2, 0), { Radius = data.Radius * 0.8, Height = 70, Color = pal.Light, Color2 = pal.Main, Duration = 0.7 })
		TuskVFX.CreateGroundCracks(pos, { Radius = data.Radius * 1.2, Color = pal.Main, Duration = 2.2 })
		TuskVFX.CreateImpactStar(pos + Vector3.new(0, 1.5, 0), { Size = 16, Rays = 12, Color = pal.Main, Color2 = pal.Light, Duration = 0.45, Width = 1.8 })
		VFXLib.burst(pos, { Count = 60, Color = pal.Light, Speed = 55, Lifetime = 0.7 })
		VFXLib.flash(pos, pal.Light, 14, 60, 0.7)
		VFXLib.sound(sounds.AwakeningBurst, pos, 1, 0.8)
		CameraFX.shakeAt(pos, 1.5, 110)
		local camera = workspace.CurrentCamera
		if Common.isLocal(character) or (camera and (camera.CFrame.Position - pos).Magnitude < 60) then
			CameraFX.impactFrame(pal.Light)
			CameraFX.speedLines(0.35, pal.Light)
		end
	end
end

---------------------------------------------------------------------------
-- SPIN TORNADO visual: a funnel of spinning rings that follows the server's
-- position updates, with a ground swirl, dust and green sparkles.
---------------------------------------------------------------------------
local tornadoes = {}

local function startTornado(data)
	local r = data.Radius
	local t = { Pos = data.Position, Target = data.Position, Rings = {}, Angle = 0, Radius = r }
	local layers = VFXQuality.get().RingSegments > 12 and 7 or 4
	for i = 1, layers do
		local k = (i - 1) / (layers - 1)
		t.Rings[i] = {
			Ring = VFXLib.ring({ Radius = r * (0.25 + k * 0.75), Width = 0.3 + k * 0.25, Color = (i % 2 == 0) and pal.Light or pal.Main, Transparency = 0.1 + k * 0.3 }),
			Height = -2.5 + k * 11,
			Speed = (9 - k * 4) * (i % 2 == 0 and -1 or 1),
			Tilt = (math.random() - 0.5) * 0.3,
		}
	end
	-- Swirling dust + sparkles on a carrier that moves with the tornado.
	local carrier = VFXLib.anchor(CFrame.new(data.Position))
	carrier.Size = Vector3.new(r * 1.2, 10, r * 1.2)
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = VFXLib.Textures.Smoke
	dust.Color = ColorSequence.new(Color3.fromRGB(205, 180, 135))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.6, 1.1)
	dust.Speed = NumberRange.new(6, 10)
	dust.RotSpeed = NumberRange.new(250, 400)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Shape = Enum.ParticleEmitterShape.Cylinder
	dust.Rate = 30 * VFXQuality.get().Particles
	dust.Parent = carrier
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = VFXLib.Textures.Sparkle
	sparks.Color = ColorSequence.new(pal.Light, pal.Main)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.4, 0.7)
	sparks.Speed = NumberRange.new(8, 14)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Shape = Enum.ParticleEmitterShape.Cylinder
	sparks.Rate = 40 * VFXQuality.get().Particles
	sparks.Parent = carrier
	t.Carrier = carrier
	local high = VFXQuality.get().RingSegments > 12
	-- Spiral strands of light winding up the funnel (rotated every frame).
	local helix = VFXLib.anchor(CFrame.new(data.Position))
	local strands = high and 3 or 2
	local points = high and 14 or 8
	for sIdx = 1, strands do
		local prev
		for i = 0, points do
			local k = i / points
			local th = k * math.pi * 3 + (sIdx - 1) / strands * math.pi * 2
			local rad = r * (0.2 + k * 0.85)
			local a = Instance.new("Attachment")
			a.Position = Vector3.new(math.cos(th) * rad, -2.5 + k * 12, math.sin(th) * rad)
			a.Parent = helix
			if prev then
				local b = Instance.new("Beam")
				b.Attachment0 = prev
				b.Attachment1 = a
				b.FaceCamera = true
				b.LightEmission = 1
				b.LightInfluence = 0
				b.Segments = 1
				b.Width0 = 0.35 + k * 0.3
				b.Width1 = 0.35 + k * 0.3
				b.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(pal.Main, k))
				b.Transparency = NumberSequence.new(0.15 + k * 0.45)
				b.Parent = helix
			end
			prev = a
		end
	end
	t.Helix = helix
	-- See-through wind body: stacked force-field rings of air.
	t.Body = {}
	for i = 1, (high and 3 or 2) do
		local k = (i - 1) / 2
		local d = r * (0.6 + k * 1.1)
		t.Body[i] = {
			Part = VFXLib.part({ Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = i == 2 and pal.Light or pal.Main, Transparency = 0.15, Size = Vector3.new(4, d, d) }),
			Height = -1 + k * 8,
			Speed = (i % 2 == 0) and -7 or 9,
		}
	end
	-- Ground swirl: a flat ring of churned dust at the base.
	t.Ground = VFXLib.ring({ Radius = r * 1.3, Width = 0.5, Color = Color3.fromRGB(225, 205, 160), Transparency = 0.35, LightEmission = 0.2 })
	-- Debris sucked up the funnel: rocks and planks that orbit and rise.
	t.Debris = {}
	local debrisCount = high and 8 or 4
	for i = 1, debrisCount do
		local isPlank = i % 3 == 0
		t.Debris[i] = {
			Part = VFXLib.part({ Material = isPlank and Enum.Material.Wood or Enum.Material.Sandstone, Color = isPlank and Color3.fromRGB(120, 84, 52) or Color3.fromRGB(180, 150, 110), Size = isPlank and Vector3.new(0.3, 0.3, 1.6) or Vector3.new(0.7, 0.6, 0.7), CastShadow = true }),
			Phase = i / debrisCount * math.pi * 2,
			Rise = math.random(),
			Speed = 0.35 + math.random() * 0.3,
		}
	end
	t.NextBolt = os.clock() + 0.2
	t.Sound = VFXLib.sound(sounds.ChargeLoop, carrier, 0.6, 0.6, true)
	t.Expire = os.clock() + data.Duration + 1
	tornadoes[data.Id] = t
	VFXLib.burst(data.Position, { Count = 24, Color = pal.Light, Speed = 22, Lifetime = 0.45 })
	TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position - Vector3.new(0, 2.5, 0)), { Radius = r * 1.6, Layers = 2, Color = pal.Light, Color2 = pal.Main, Ground = true, Particles = 0.5, Width = 0.4, Duration = 0.4 })
end

local function endTornado(data)
	local t = tornadoes[data.Id]
	if t then
		tornadoes[data.Id] = nil
		for _, layer in ipairs(t.Rings) do
			layer.Ring:Destroy()
		end
		if t.Sound then
			t.Sound:Destroy()
		end
		t.Carrier:Destroy()
		t.Helix:Destroy()
		t.Ground:Destroy()
		for _, b in ipairs(t.Body) do
			b.Part:Destroy()
		end
		-- Debris is flung outward when the tornado bursts.
		for _, d in ipairs(t.Debris) do
			local part = d.Part
			local from = part.Position
			local out = Vector3.new(from.X - t.Pos.X, 0, from.Z - t.Pos.Z)
			out = (out.Magnitude > 0.01 and out.Unit or Vector3.new(1, 0, 0)) * (18 + math.random() * 10) + Vector3.new(0, 12, 0)
			local spin = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
			VFXLib.animate(0.9, function(a)
				local p = from + out * a + Vector3.new(0, -30 * a * a, 0)
				part.CFrame = CFrame.new(p) * CFrame.Angles(spin.X * a, spin.Y * a, spin.Z * a)
				part.Transparency = math.max(0, (a - 0.6) / 0.4)
			end, function()
				part:Destroy()
			end)
		end
	end
	local pos = data.Position
	TuskVFX.CreateRotationalShockwave(CFrame.new(pos - Vector3.new(0, 2.5, 0)), { Radius = data.Radius * 1.6, Layers = 3, Color = pal.Main, Color2 = pal.Light, Ground = true, Particles = 2, Width = 0.7 })
	VFXLib.burst(pos, { Count = 30, Color = pal.Light, Speed = 40, Lifetime = 0.5 })
	TuskVFX.CreateImpactStar(pos, { Size = 9, Rays = 10, Color = pal.Main, Color2 = pal.Light, Duration = 0.35, Width = 1 })
	TuskVFX.CreateEnergyPillar(pos - Vector3.new(0, 2.5, 0), { Radius = data.Radius * 0.9, Height = 35, Color = pal.Light, Color2 = pal.Main, Duration = 0.5 })
	TuskVFX.CreateGroundCracks(pos, { Radius = data.Radius * 1.4, Color = pal.Main, Duration = 1.6 })
	VFXLib.flash(pos, pal.Light, 8, 30, 0.4)
	VFXLib.sound(sounds.Finisher, pos, 0.8, 0.9)
	CameraFX.shakeAt(pos, 0.8, 70)
end

local function stepTornadoes(dt)
	local now = os.clock()
	for id, t in pairs(tornadoes) do
		t.Pos = t.Pos:Lerp(t.Target, math.min(1, dt * 10))
		t.Angle = t.Angle + dt
		for _, layer in ipairs(t.Rings) do
			local sway = math.sin(now * 3 + layer.Height) * 0.6
			layer.Ring:SetCFrame(CFrame.new(t.Pos + Vector3.new(sway, layer.Height, 0)) * CFrame.Angles(layer.Tilt, t.Angle * layer.Speed, 0))
		end
		t.Carrier.CFrame = CFrame.new(t.Pos + Vector3.new(0, 2, 0))
		t.Helix.CFrame = CFrame.new(t.Pos) * CFrame.Angles(0, -t.Angle * 7, 0)
		t.Ground:SetCFrame(CFrame.new(t.Pos - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, t.Angle * 5, 0))
		for _, b in ipairs(t.Body) do
			-- Upright cylinder (axis X -> world up), spun around its axis for a shimmer.
			b.Part.CFrame = CFrame.new(t.Pos + Vector3.new(0, b.Height, 0)) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(t.Angle * b.Speed, 0, 0)
		end
		for _, d in ipairs(t.Debris) do
			d.Rise = (d.Rise + dt * d.Speed) % 1
			local th = d.Phase + t.Angle * (8 - d.Rise * 3)
			local rad = t.Radius * (0.3 + d.Rise * 0.8)
			d.Part.CFrame = CFrame.new(t.Pos + Vector3.new(math.cos(th) * rad, -2 + d.Rise * 11, math.sin(th) * rad)) * CFrame.Angles(th * 2, th, 0)
		end
		-- Green Spin sparks crackling inside the funnel.
		if now >= t.NextBolt then
			t.NextBolt = now + 0.18 + math.random() * 0.2
			local th = math.random() * math.pi * 2
			local p = t.Pos + Vector3.new(math.cos(th) * t.Radius * 0.5, math.random() * 8 - 1, math.sin(th) * t.Radius * 0.5)
			TuskVFX.CreateImpactStar(p, { Size = 2, Rays = 4, Color = pal.Main, Color2 = Color3.new(1, 1, 1), Duration = 0.15 })
		end
		if now > t.Expire then
			endTornado({ Id = id, Position = t.Pos, Radius = t.Radius })
		end
	end
end

function Gyro.handle(name, data)
	if name == "Tornado" then
		if data.Phase == "Start" then
			startTornado(data)
		elseif data.Phase == "Move" then
			local t = tornadoes[data.Id]
			if t then
				t.Target = data.Position
			end
		elseif data.Phase == "Burst" then
			endTornado(data)
		end
		return
	end
	if name == "M1" then
		Common.m1(data, pal, { AnimPrefix = "G_M1_" })
	elseif name == "M1Finisher" then
		Common.finisher(data, pal)
		local entry = data.Character and held[data.Character]
		if entry then
			entry.Spin = 50
			task.delay(0.4, function()
				entry.Spin = 8
			end)
		end
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

local shakeTimer = 0
function Gyro.step(dt)
	dt = dt or 1 / 60
	updateHeld(dt)
	stepBalls(dt)
	stepTornadoes(dt)
	shakeTimer = shakeTimer + dt
	if shakeTimer > 0.25 then
		shakeTimer = 0
		updateShakes()
	end
end

-- Ball projectiles come through the shared SpinFX channel.
Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
	if typeof(data) ~= "table" or data.Kind ~= "GyroBall" then
		return
	end
	if name == "ProjectileSpawn" then
		spawnBall(data)
	elseif name == "ProjectileEnd" then
		endBall(data)
	end
end)

return Gyro
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
	-- Starburst coloured by who landed it: cyan for Johnny, green for Gyro.
	local source = tostring(data.Source or "")
	local starColor = (source:sub(1, 4) == "Gyro") and Color3.fromRGB(120, 225, 95) or Color3.fromRGB(90, 230, 255)
	if data.Perfect then
		starColor = colors.Gold
	end
	if data.Position and not data.Blocked then
		TuskVFX.CreateImpactStar(data.Position, { Size = 2.2 + (data.Level or 1) * 0.9, Rays = 6 + (data.Level or 1), Color = starColor, Color2 = Color3.new(1, 1, 1), Duration = 0.18 + (data.Level or 1) * 0.03 })
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
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = data.Blocked and ("BLOCKED " .. data.Amount) or (tostring(data.Amount) .. (data.Perfect and "!" or ""))
	label.TextColor3 = data.Blocked and Color3.fromRGB(170, 200, 230) or (data.Perfect and colors.Perfect or colors.Gold)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(60, 25, 0)
	label.Parent = billboard
	local start = carrier.Position
	VFXLib.animate(1, function(a)
		carrier.Position = start + Vector3.new(0, a * 3, 0)
		label.TextTransparency = math.max(0, (a - 0.6) / 0.4)
		label.TextStrokeTransparency = label.TextTransparency
		local pop = a < 0.1 and (1 + (0.1 - a) * 4) or 1
		billboard.Size = UDim2.fromOffset(160 * pop * (data.Perfect and 1.3 or 1), 60 * pop * (data.Perfect and 1.3 or 1))
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
-- MODULE: Maid
-- ======================================================================
__modules["Maid"] = function()
--[[
	Maid  (ReplicatedStorage.SpinShared.Maid)
	Tracks connections, instances and cleanup functions so effects always end.
]]

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(task)
	table.insert(self._tasks, task)
	return task
end

function Maid:Clean()
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		local t = tasks[i]
		local kind = typeof(t)
		if kind == "RBXScriptConnection" then
			t:Disconnect()
		elseif kind == "Instance" then
			t:Destroy()
		elseif kind == "function" then
			local ok, err = pcall(t)
			if not ok then
				warn("[Maid] cleanup error:", err)
			end
		elseif kind == "table" and t.Destroy then
			t:Destroy()
		end
	end
end

Maid.Destroy = Maid.Clean

return Maid
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
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES = { "SpinRequest", "SpinFX", "TuskRequest", "TuskFX", "WorldFX" }

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
-- MODULE: SettingsUI
-- ======================================================================
__modules["SettingsUI"] = function()
--[[
	SettingsUI  (StarterPlayerScripts.SpinClient.UI.SettingsUI)
	The small "VFX: MEDIUM" button (top right) that cycles Low / Medium / High.
	Phones start on Low to keep the frame rate smooth.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = nil -- (bundled: modules are inlined)
local VFXQuality = __require("VFXQuality")

local SettingsUI = {}
local DARK = Color3.fromRGB(22, 16, 10)
local FONT = Enum.Font.GothamBlack
local colors = { GoldLight = Color3.fromRGB(255, 238, 160), Gold = Color3.fromRGB(255, 196, 56) }

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function SettingsUI.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpinSettings"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- VFX quality toggle (top right, small).
	local qualityButton = Instance.new("TextButton")
	qualityButton.Name = "VFXQuality"
	qualityButton.AnchorPoint = Vector2.new(1, 0)
	qualityButton.Position = UDim2.new(1, -12, 0, 12)
	qualityButton.Size = UDim2.fromOffset(130, 28)
	qualityButton.BackgroundColor3 = DARK
	qualityButton.BackgroundTransparency = 0.2
	qualityButton.Font = FONT
	qualityButton.TextSize = 13
	qualityButton.TextColor3 = colors.GoldLight
	qualityButton.Parent = gui
	corner(qualityButton, 6)
	stroke(qualityButton, colors.Gold, 1.5)
	local function refresh()
		local _, name = VFXQuality.get()
		qualityButton.Text = "VFX: " .. string.upper(name)
	end
	refresh()
	qualityButton.Activated:Connect(function()
		VFXQuality.cycle()
	end)
	VFXQuality.Changed:Connect(refresh)

	-- Touch devices start on Low to protect frame rate; players can raise it.
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		VFXQuality.set("Low")
	end
end

return SettingsUI
end

-- ======================================================================
-- MODULE: SteelBallModel
-- ======================================================================
__modules["SteelBallModel"] = function()
--[[
	SteelBallModel  (ReplicatedStorage.SpinShared.SteelBallModel)

	Procedurally builds the Steel Ball from the owner's reference images:
	a glossy green metal sphere with raised hexagon panels (dark outer edge
	plus a bright inner edge, so they read as raised plates), round
	panels, and curved parallel grooves sweeping around the surface.

	SteelBallModel.build(diameter, detailed) -> Model (PrimaryPart = "Core")
	  detailed = false (Low quality) keeps only the hexagon outer edges.

	All parts are visual only: no collision, no queries, no touch events,
	massless, and welded to the Core. Anchor the Core to move it with
	PivotTo, or weld the Core to a hand.

	Swapping in a real mesh later: put a Model named "SteelBall" (with a
	PrimaryPart) in ReplicatedStorage.SpinShared.Assets and build() will
	clone and resize it instead of generating one.
]]

local SpinConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("SpinConfig"))

local SteelBallModel = {}

-- Panel layout (unit directions on the ball, angular radius in radians).
-- Kept as data so the look can be tuned without touching the builder.
SteelBallModel.Layout = {
	Hexagons = {
		{ Dir = Vector3.new(-0.45, 0.35, 0.82), Radius = 0.55, Spin = 0.2 },
		{ Dir = Vector3.new(0.6, -0.2, -0.77), Radius = 0.5, Spin = 0.5 },
		{ Dir = Vector3.new(-0.3, -0.85, -0.4), Radius = 0.45, Spin = 0.0 },
	},
	Circles = {
		{ Dir = Vector3.new(0.45, -0.4, 0.8), Radius = 0.3 },
		{ Dir = Vector3.new(0.2, 0.85, -0.45), Radius = 0.35 },
	},
	-- Grooves: arcs of a circle around Axis at angular radius Radius,
	-- from angle From to To (radians).
	Grooves = {
		{ Axis = Vector3.new(0.95, 0.25, 0.15), Radius = 0.5, From = -1.2, To = 1.3 },
		{ Axis = Vector3.new(0.95, 0.25, 0.15), Radius = 0.78, From = -1.0, To = 1.1 },
		{ Axis = Vector3.new(-0.75, 0.15, -0.6), Radius = 0.6, From = 0.6, To = 3.2 },
	},
}

local function visualPart(props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function weld(core, part)
	local w = Instance.new("WeldConstraint")
	w.Part0 = core
	w.Part1 = part
	w.Parent = part
end

-- Two unit vectors perpendicular to dir.
local function basis(dir)
	local helper = math.abs(dir.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local u = dir:Cross(helper).Unit
	local v = dir:Cross(u).Unit
	return u, v
end

-- Point on the unit sphere at angular distance `radius` from `center`, around angle `theta`.
local function around(center, radius, theta)
	local u, v = basis(center)
	return (center * math.cos(radius) + (u * math.cos(theta) + v * math.sin(theta)) * math.sin(radius)).Unit
end

local function fromOverride(diameter)
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
	local custom = assets and assets:FindFirstChild("SteelBall")
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		local clone = custom:Clone()
		local size = clone:GetExtentsSize()
		local largest = math.max(size.X, size.Y, size.Z)
		if largest > 0 then
			clone:ScaleTo(clone:GetScale() * diameter / largest)
		end
		clone.PrimaryPart.Name = "Core"
		return clone
	end
	return nil
end

function SteelBallModel.build(diameter, detailed)
	diameter = diameter or 1
	if detailed == nil then
		detailed = true
	end

	local override = fromOverride(diameter)
	if override then
		return override
	end

	local colors = SpinConfig.Colors
	local r = diameter / 2

	local model = Instance.new("Model")
	model.Name = "SteelBall"

	local core = visualPart({
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		Color = colors.Ball,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.18,
		Massless = false,
	})
	core.CFrame = CFrame.new()
	core.Parent = model
	model.PrimaryPart = core

	-- Attachments other systems hook effects onto.
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = core
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, r * 0.9, 0)
	top.Parent = core
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -r * 0.9, 0)
	bottom.Parent = core

	-- One straight raised line between two directions on the surface.
	local function line(a, b, width, color, name)
		local lift = r * 1.012
		local pa, pb = a * lift, b * lift
		local mid = (pa + pb) / 2
		local seg = visualPart({
			Name = name,
			Size = Vector3.new(width, width * 0.5, (pb - pa).Magnitude + width * 0.6),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0.1,
		})
		seg.CFrame = CFrame.lookAt(mid, pb, mid.Unit)
		seg.Parent = model
		weld(core, seg)
	end

	local function polygon(dirCenter, radius, sides, spin, width, color, name)
		local c = dirCenter.Unit
		for i = 0, sides - 1 do
			local a = around(c, radius, spin + i / sides * math.pi * 2)
			local b = around(c, radius, spin + (i + 1) / sides * math.pi * 2)
			line(a, b, width, color, name)
		end
	end

	local layout = SteelBallModel.Layout

	-- Hexagon plates: dark outer edge, bright inner edge.
	for _, hex in ipairs(layout.Hexagons) do
		polygon(hex.Dir, hex.Radius, 6, hex.Spin, diameter * 0.04, colors.BallDark, "HexEdge")
		if detailed then
			polygon(hex.Dir, hex.Radius * 0.84, 6, hex.Spin, diameter * 0.025, colors.BallLight, "HexHighlight")
		end
	end

	if detailed then
		-- Round panels.
		for _, circle in ipairs(layout.Circles) do
			polygon(circle.Dir, circle.Radius, 10, 0, diameter * 0.035, colors.BallDark, "RoundPanel")
		end
		-- Curved grooves.
		for _, groove in ipairs(layout.Grooves) do
			local axis = groove.Axis.Unit
			local steps = 6
			for i = 0, steps - 1 do
				local t0 = groove.From + (groove.To - groove.From) * i / steps
				local t1 = groove.From + (groove.To - groove.From) * (i + 1) / steps
				line(around(axis, groove.Radius, t0), around(axis, groove.Radius, t1), diameter * 0.03, colors.BallDark, "Groove")
			end
		end
	end

	return model
end

return SteelBallModel
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
	  portalNail(...)       portals for nails fired through them
	  evolve(data)          the "next Act" transformation + banner
	  charge helpers        attribute-driven hold charges
]]

local Players = game:GetService("Players")

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
}

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
	TuskVFX.CreateCrescent(cf, { Radius = 2.2 * scale, Width = 0.5 * scale, Color = color, Color2 = Color3.new(1, 1, 1), Sweep = side * 1.8, Duration = 0.18 })
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
		-- Short portal flash beside the strike.
		local pos = (root.CFrame * CFrame.new(index % 2 == 1 and 1.6 or -1.6, 1, -2.6)).Position
		Common.portal(pos, (root.CFrame * CFrame.new(0, 1, -6)).Position, 1.1, 0.18, palette)
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
		for _, player in ipairs(Players:GetPlayers()) do
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
		Ultimate = "TUSK AWAKENING",
		Next = 2, -- the ultimate awakens Tusk to this Act
	},
	[2] = {
		Name = "TUSK ACT 2",
		Tagline = "Wormhole combat",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(70, 200, 255), Secondary = Color3.fromRGB(30, 80, 220) },
		M1 = "DIMENSIONAL COMBO",
		Abilities = { "WORMHOLE NAIL", "UNDERGROUND PURSUIT", "NAIL DIMENSION" },
		AbilityKinds = { "Press", "Press", "Press" },
		Next = 3,
		Ultimate = "DIMENSIONAL STORM",
	},
	[3] = {
		Name = "TUSK ACT 3",
		Tagline = "Master of spatial movement",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(60, 140, 255), Secondary = Color3.fromRGB(20, 40, 160) },
		M1 = "WORMHOLE STRIKES",
		Abilities = { "DIMENSIONAL STEP", "SPATIAL PURSUIT", "DIMENSIONAL BREAK" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "INFINITE DIMENSION",
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
	},
}

-- Which character an Act belongs to ("Johnny" for Tusk Acts 1-4).
function TuskActRegistry.characterOf(act)
	local info = TuskActRegistry.Acts[act]
	return info and info.Character or "Johnny"
end

-- The Act a character starts on.
TuskActRegistry.StartAct = { Johnny = 1, Gyro = 5 }

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

	Plays Tusk character animations on ANY character, on every client.
	Two layers per character:
	  * Hold   : a sustained pose (Sneak, Charge) until stopped
	  * Action : a short keyframed move (M1 hits, Nail Shot...) that plays
	             on top, then blends back to the Hold pose or rest

	Default = procedural poses built from Motor6D C0 offsets (no uploads
	needed, works on R15 and R6). If TuskConfig.AnimationIds[name] holds
	an uploaded animation id, that real animation plays instead.

	Pose values: degrees {X, Y, Z} rotation in the parent part's space,
	optional 4th value = vertical offset in studs.
	  Arms:  +X raises the arm forward.   Waist: -X bends forward.
	  Hips:  +X lifts the thigh forward.   Knees: -X bends the knee.
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
	Point = { Root = { 0, -12, 0 }, RightArm = { 92, 0, 0 }, LeftArm = { 15, 0, -10 }, Waist = { 0, -18, 0 } },
	PointRecoil = { Root = { 6, -8, 0 }, RightArm = { 110, 0, 0 }, Waist = { 6, -14, 0 } },
	Jab = { Root = { 0, -18, 0 }, RightArm = { 88, 0, 12 }, Waist = { 0, -28, 0 }, LeftArm = { 30, 0, -20 } },
	JabLeft = { Root = { 0, 18, 0 }, LeftArm = { 88, 0, -12 }, Waist = { 0, 28, 0 }, RightArm = { 30, 0, 20 } },
	SpinPoke = { Root = { -6, -20, 0 }, RightArm = { 100, 25, 0 }, Waist = { -10, -24, 0 }, LeftArm = { 20, 0, -30 } },
	SlamWindup = { Root = { 10, 14, 0 }, RightArm = { 165, 0, 10 }, LeftArm = { 40, 0, -30 }, Waist = { 12, 15, 0 } },
	Slam = { Root = { -14, -10, 0, -0.3 }, RightArm = { 55, 0, 0 }, LeftArm = { 20, 0, -20 }, Waist = { -22, -10, 0 } },
	ChargeNail = { RightArm = { 75, 0, 28 }, LeftArm = { 75, 0, -28 }, Waist = { -8, 0, 0 } },
	BarrageA = { Root = { 0, -14, 0 }, RightArm = { 95, 4, 0 }, LeftArm = { 60, 0, -20 }, Waist = { 0, -14, 0 } },
	BarrageB = { Root = { 0, -20, 0 }, RightArm = { 88, -4, 0 }, LeftArm = { 60, 0, -20 }, Waist = { 0, -18, 0 } },
	AwakenCrouch = { Root = { -6, 0, 0, -0.3 }, RightArm = { 30, 0, 40 }, LeftArm = { 30, 0, -40 }, Waist = { -25, 0, 0 }, Neck = { -15, 0, 0 } },
	AwakenRise = { Root = { 6, 0, 0 }, RightArm = { 130, 0, 35 }, LeftArm = { 130, 0, -35 }, Waist = { 14, 0, 0 }, Neck = { 22, 0, 0 } },
	Sneak = {
		Root = { 0, 0, 0, -0.65 },
		Waist = { -26, 0, 0 },
		Neck = { 22, 0, 0 },
		RightHip = { 50, 0, 0 },
		LeftHip = { 50, 0, 0 },
		RightKnee = { -85, 0, 0 },
		LeftKnee = { -85, 0, 0 },
		RightArm = { 25, 0, 8 },
		LeftArm = { 25, 0, -8 },
	},
	Emerge = { RightArm = { 150, 0, 15 }, LeftArm = { 40, 0, -40 }, Waist = { 15, 0, 0 } },

	-- JOHNNY: fights with finger-gun nail shots.
	FingerGun = { Root = { 0, -14, 0 }, RightArm = { 95, 0, 5 }, LeftArm = { 62, 0, -38 }, Waist = { 0, -22, 0 }, Neck = { 0, 16, 0 } },
	FingerGunRecoil = { Root = { 6, -10, 0 }, RightArm = { 118, 0, 6 }, LeftArm = { 56, 0, -36 }, Waist = { 6, -16, 0 }, Neck = { 0, 12, 0 } },
	FlickR = { Root = { 0, -16, 0 }, RightArm = { 96, -8, 6 }, LeftArm = { 38, 0, -22 }, Waist = { 0, -20, 0 } },
	FlickL = { Root = { 0, 16, 0 }, LeftArm = { 96, 8, -6 }, RightArm = { 38, 0, 22 }, Waist = { 0, 20, 0 } },
	SpinChargeA = { RightArm = { 104, 10, 30 }, LeftArm = { 72, 0, -42 }, Waist = { -6, -10, 0 } },
	SpinChargeB = { RightArm = { 96, -10, 22 }, LeftArm = { 72, 0, -42 }, Waist = { -6, -10, 0 } },
	Spread = { Root = { 8, 0, 0 }, RightArm = { 92, 0, 70 }, LeftArm = { 92, 0, -70 }, Waist = { 10, 0, 0 }, Neck = { 15, 0, 0 } },
	Dive = { Root = { 0, 0, 0, -0.45 }, Waist = { -38, 0, 0 }, RightArm = { 155, 0, 12 }, LeftArm = { 155, 0, -12 }, RightHip = { 40, 0, 0 }, LeftHip = { 20, 0, 0 }, RightKnee = { -45, 0, 0 }, LeftKnee = { -30, 0, 0 } },
	LungeStep = { Root = { -10, -10, 0, -0.2 }, Waist = { -16, -12, 0 }, RightArm = { 86, 0, 0 }, LeftArm = { -22, 0, -12 }, RightHip = { 38, 0, 0 }, LeftHip = { -26, 0, 0 }, RightKnee = { -32, 0, 0 } },
	PushTwo = { Root = { -10, 0, 0 }, RightArm = { 92, 0, 14 }, LeftArm = { 92, 0, -14 }, Waist = { -12, 0, 0 }, RightHip = { 22, 0, 0 }, LeftHip = { -16, 0, 0 } },
	WindSpin = { Root = { 0, -45, 0 }, Waist = { 0, -60, 0 }, RightArm = { 62, 0, 82 }, LeftArm = { 40, 0, -30 } },
	DashPunch = { Root = { -16, -16, 0, -0.25 }, Waist = { -20, -26, 0 }, RightArm = { 92, 0, 0 }, LeftArm = { -30, 0, -22 }, RightHip = { 42, 0, 0 }, RightKnee = { -60, 0, 0 }, LeftHip = { -30, 0, 0 } },

	-- GYRO: fights like a ball thrower.
	GyroIdle = { RightArm = { 55, 0, 14 }, LeftArm = { 12, 0, -10 } },
	GHookWind = { Root = { 0, 22, 0 }, RightArm = { 82, 0, 80 }, Waist = { 0, 25, 0 } },
	GHook = { Root = { 0, -38, 0 }, RightArm = { 86, -32, 12 }, Waist = { 0, -42, 0 }, LeftArm = { 30, 0, -20 } },
	KickChamber = { Root = { 8, 0, 0 }, RightHip = { 72, 0, 0 }, RightKnee = { -92, 0, 0 }, Waist = { 8, 0, 0 }, RightArm = { 30, 0, 30 }, LeftArm = { 30, 0, -30 } },
	FrontKick = { Root = { 15, 0, 0 }, RightHip = { 88, 0, 0 }, RightKnee = { -8, 0, 0 }, LeftKnee = { -15, 0, 0 }, Waist = { 12, 0, 0 }, RightArm = { 30, 0, 34 }, LeftArm = { 30, 0, -34 } },
	OverheadWind = { Root = { 10, 16, 0 }, RightArm = { 172, 0, 15 }, Waist = { 15, 20, 0 }, LeftHip = { 18, 0, 0 }, LeftKnee = { -22, 0, 0 } },
	OverheadSmash = { Root = { -16, -10, 0, -0.35 }, RightArm = { 58, 0, 0 }, Waist = { -26, -15, 0 }, LeftHip = { 36, 0, 0 }, LeftKnee = { -30, 0, 0 }, RightHip = { -15, 0, 0 } },
	PitchBack = { Root = { 4, 32, 0 }, RightArm = { 200, 0, 40 }, Waist = { 5, 36, 0 }, LeftArm = { 80, 0, -30 }, LeftHip = { 48, 0, 0 }, LeftKnee = { -52, 0, 0 } },
	PitchRelease = { Root = { -14, -32, 0, -0.15 }, RightArm = { 74, 0, -10 }, Waist = { -22, -36, 0 }, LeftArm = { -12, 0, -30 }, LeftHip = { 30, 0, 0 }, LeftKnee = { -20, 0, 0 }, RightHip = { -30, 0, 0 } },
	BowlWind = { Root = { 0, 0, 0, -0.4 }, RightArm = { -55, 0, 10 }, Waist = { -16, 0, 0 }, LeftHip = { 50, 0, 0 }, LeftKnee = { -62, 0, 0 }, RightKnee = { -42, 0, 0 } },
	BowlRelease = { Root = { 0, 0, 0, -0.45 }, RightArm = { 62, 0, 0 }, Waist = { -28, 0, 0 }, LeftHip = { 55, 0, 0 }, LeftKnee = { -65, 0, 0 }, RightHip = { -20, 0, 0 } },
	PalmWind = { Root = { 0, 20, 0 }, RightArm = { 40, 0, 20 }, Waist = { 0, 25, 0 } },
	PalmPress = { Root = { -12, -12, 0, -0.1 }, RightArm = { 92, 0, 0 }, LeftArm = { 70, 0, -22 }, Waist = { -16, -12, 0 }, LeftHip = { 30, 0, 0 }, LeftKnee = { -30, 0, 0 } },
	BreakerWindA = { Root = { 0, 0, 0, -0.3 }, RightArm = { 122, 0, 62 }, Waist = { 0, 46, 0 }, LeftArm = { 60, 0, -40 }, LeftKnee = { -25, 0, 0 }, RightKnee = { -25, 0, 0 } },
	BreakerWindB = { Root = { 0, 0, 0, -0.3 }, RightArm = { 132, 10, 70 }, Waist = { 0, 52, 0 }, LeftArm = { 64, 0, -44 }, LeftKnee = { -25, 0, 0 }, RightKnee = { -25, 0, 0 } },
}

--[[
	Action sequences: list of keyframes { Time, Pose, (optional) Ease }.
	The last keyframe's Time is the length; after it the joints blend back.
]]
TuskAnimation.Actions = {
	-- JOHNNY
	M1_1 = { { 0, "Rest" }, { 0.06, "FlickR" }, { 0.22, "FlickR" } },
	M1_2 = { { 0, "Rest" }, { 0.06, "FlickL" }, { 0.22, "FlickL" } },
	M1_3 = { { 0, "Rest" }, { 0.08, "FingerGun" }, { 0.14, "FingerGunRecoil" }, { 0.27, "FingerGun" } },
	M1_4 = { { 0, "Rest" }, { 0.12, "SlamWindup" }, { 0.2, "Slam" }, { 0.5, "Slam" } },
	NailShot = { { 0, "Rest" }, { 0.12, "FingerGun" }, { 0.2, "FingerGunRecoil" }, { 0.45, "FingerGun" } },
	NailBarrage = {
		{ 0, "Rest" }, { 0.1, "FlickR" }, { 0.19, "FlickL" }, { 0.28, "FlickR" },
		{ 0.37, "FlickL" }, { 0.46, "FlickR" }, { 0.55, "FlickL" }, { 0.8, "FingerGun" },
	},
	SpinChargeLoop = { { 0, "SpinChargeA" }, { 0.12, "SpinChargeB" }, { 0.24, "SpinChargeA" } },
	UndergroundDive = { { 0, "Rest" }, { 0.15, "Dive" }, { 0.55, "Dive" } },
	NailDimension = { { 0, "Rest" }, { 0.2, "Spread" }, { 0.8, "Spread" } },
	DimensionalStep = { { 0, "Rest" }, { 0.08, "LungeStep" }, { 0.35, "LungeStep" } },
	SpatialPursuit = { { 0, "Rest" }, { 0.1, "FlickR" }, { 0.25, "Spread" }, { 0.6, "Spread" } },
	DimensionalBreak = { { 0, "Rest" }, { 0.25, "AwakenCrouch" }, { 0.72, "AwakenCrouch" }, { 0.82, "PushTwo" }, { 1.2, "PushTwo" } },
	GoldenSpinNail = { { 0, "Rest" }, { 0.15, "WindSpin" }, { 0.3, "FingerGunRecoil" }, { 0.6, "FingerGun" } },
	GoldenPursuit = { { 0, "Rest" }, { 0.12, "SlamWindup" }, { 0.25, "DashPunch" }, { 0.7, "DashPunch" } },

	-- GYRO
	G_M1_1 = { { 0, "Rest" }, { 0.06, "Jab" }, { 0.22, "Jab" } },
	G_M1_2 = { { 0, "Rest" }, { 0.05, "GHookWind" }, { 0.12, "GHook" }, { 0.26, "GHook" } },
	G_M1_3 = { { 0, "Rest" }, { 0.06, "KickChamber" }, { 0.12, "FrontKick" }, { 0.3, "FrontKick" } },
	G_M1_4 = { { 0, "Rest" }, { 0.12, "OverheadWind" }, { 0.22, "OverheadSmash" }, { 0.5, "OverheadSmash" } },
	GyroThrow = { { 0, "Rest" }, { 0.14, "PitchBack" }, { 0.24, "PitchRelease" }, { 0.55, "PitchRelease" } },
	GyroBowl = { { 0, "Rest" }, { 0.14, "BowlWind" }, { 0.28, "BowlRelease" }, { 0.6, "BowlRelease" } },
	GyroPalm = { { 0, "Rest" }, { 0.12, "PalmWind" }, { 0.2, "PalmPress" }, { 0.6, "PalmPress" } },
	GyroBreakerCharge = {
		{ 0, "Rest" }, { 0.3, "BreakerWindA" }, { 0.55, "BreakerWindB" }, { 0.8, "BreakerWindA" },
		{ 1.05, "BreakerWindB" }, { 1.3, "BreakerWindA" }, { 1.55, "BreakerWindB" }, { 1.75, "PitchBack" },
	},
	SpinningNailRelease = { { 0, "ChargeNail" }, { 0.06, "PointRecoil" }, { 0.4, "Point" } },
	Awakening = { { 0, "Rest" }, { 0.35, "AwakenCrouch" }, { 1.2, "AwakenCrouch" }, { 1.45, "AwakenRise" }, { 2.2, "AwakenRise" } },
	Emerge = { { 0, "Sneak" }, { 0.12, "Emerge" }, { 0.5, "Emerge" } },
	Throw = { { 0, "Rest" }, { 0.14, "SlamWindup" }, { 0.24, "Point" }, { 0.5, "Point" } },
}

local states = setmetatable({}, { __mode = "k" }) -- character -> { Hold, ActionJob, Tracks }
local warned = setmetatable({}, { __mode = "k" })
-- Extra time each move holds its last pose before relaxing (makes moves read clearly).
TuskAnimation.HoldExtra = 0.12

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

-- C0 for a pose value (rotation applied in the parent part's space, about the joint).
local function poseC0(motor, value)
	local base = JointCache.original(motor)
	if not value then
		return base
	end
	local rotation = CFrame.Angles(math.rad(value[1]), math.rad(value[2]), math.rad(value[3]))
	local position = base.Position + Vector3.new(0, value[4] or 0, 0)
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
		s = { Hold = nil, Action = nil, Tracks = {} }
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

-- Blend every joint toward a target pose over `duration`.
local function blendTo(character, pose, duration)
	local motors = motorsOf(character)
	local from, to = {}, {}
	for name, motor in pairs(motors) do
		from[name] = JointCache.read(motor)
		to[name] = poseC0(motor, pose[name])
	end
	return VFXLib.animate(duration, function(a)
		local e = VFXLib.easeOut(a)
		for name, motor in pairs(motors) do
			if motor.Parent then
				JointCache.write(motor, from[name]:Lerp(to[name], e))
			end
		end
	end)
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
		local c0s = {}
		for jointName, motor in pairs(motors) do
			if i == 1 then
				c0s[jointName] = JointCache.read(motor)
			else
				c0s[jointName] = poseC0(motor, pose[jointName] or holdPose[jointName])
			end
		end
		keys[i] = { Time = frame[1], C0 = c0s }
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
		local e = VFXLib.easeOut(local01)
		for jointName, motor in pairs(motors) do
			if motor.Parent then
				JointCache.write(motor, current.C0[jointName]:Lerp(nextKey.C0[jointName], e))
			end
		end
	end, function()
		if s.Action == job then
			s.Action = nil
			blendTo(character, resolvePose(s.Hold), 0.2)
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
		blendTo(character, resolvePose(poseName), 0.2)
	end
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
	if not s.Action then
		blendTo(character, {}, 0.25)
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
			actVFX[act] = __require(name)
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
		-- Act 2: violet-cyan helix, one tilted ring.
		s.Color = Color3.fromRGB(110, 70, 255)
		s.Color2 = Color3.fromRGB(80, 210, 255)
		s.Rings = 1
		s.RingColor = Color3.fromRGB(160, 120, 255)
		s.ImpactSize = 1
	elseif style == "Portal" then
		-- Nails fired through portals (Acts 2 and 3).
		s.Scale = 0.9
		s.Color = act == 3 and Color3.fromRGB(30, 20, 120) or Color3.fromRGB(110, 70, 255)
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
			local distance = math.min(entry.Speed * (serverNow - entry.ServerTime), entry.Range)
			local pos = entry.Origin + entry.Direction * distance
			entry.Visual:Step(CFrame.lookAt(pos, pos + entry.Direction), dt)
			if now > entry.Expire then
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
					-- Subtle ground ripple every so often.
					if fx and fx.Attachment and now >= fx.NextRipple then
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
	TuskStand.nailPoint(character) -> world CFrame where nail energy gathers
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local TuskStandModels = __require("TuskStandModels")
local VFXLib = __require("VFXLib")

local TuskStand = {}

-- Where each Act's Stand floats (bigger Acts float further back).
local IDLE_OFFSETS = {
	[1] = CFrame.new(1.9, 1.5, 1.7),
	[2] = CFrame.new(2.1, 1.6, 2),
	[3] = CFrame.new(2.4, 1.2, 2.8),
	[4] = CFrame.new(2.6, 1.8, 3.4),
}
local IDLE_OFFSET = IDLE_OFFSETS[1]
local SNEAK_OFFSET = CFrame.new(1.5, -1.4, 1.2)

local stands = {} -- [character] = stand

local function setVisible(stand, visible)
	if stand.Visible == visible then
		return
	end
	stand.Visible = visible
	for part, original in pairs(stand.Transparency) do
		part.Transparency = visible and original or 1
	end
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
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = TuskConfig.Colors.Cyan
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
	model.Parent = VFXLib.Folder
	local root = character:FindFirstChild("HumanoidRootPart")
	local start = root and root.CFrame * (IDLE_OFFSETS[act] or IDLE_OFFSET) or CFrame.new()
	model:PivotTo(start)
	return {
		Act = act,
		Character = character,
		Model = model,
		Rig = rig,
		Highlight = highlight,
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
	stand.Highlight.OutlineTransparency = awakened and 0.1 or (stand.Action and stand.Action.Kind == "Manifest" and stand.Highlight.OutlineTransparency or 1)

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
	if joints.ArmR then
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
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local act = character and character:GetAttribute("TuskAct")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if act and root and humanoid and humanoid.Health > 0 then
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
					update(stand, root, dt, now)
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
	local chin = part(model, { Name = "Chin", Size = Vector3.new(0.95, 1.15, 0.95) * s, Color = pink, Ellipsoid = true })
	attach(body, chin, CFrame.new(-0.22 * s, -0.78 * s, -0.28 * s) * CFrame.Angles(0.35, 0, -0.25))
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
		{ Name = "EarL", Base = CFrame.new(-0.5 * s, 0.9 * s, 0.1 * s) * CFrame.Angles(0.25, -0.3, 1.15), Size = Vector3.new(0.6, 1.8, 0.13) },
		{ Name = "EarR", Base = CFrame.new(0.7 * s, 0.75 * s, 0.05 * s) * CFrame.Angles(-0.1, 0.25, -1.35), Size = Vector3.new(0.5, 1.4, 0.13) },
	}
	for _, e in ipairs(ears) do
		local ear = part(model, { Name = e.Name, Size = e.Size * s, Color = pink, Ellipsoid = true })
		local inner = part(model, { Name = e.Name .. "Inner", Size = e.Size * s * Vector3.new(0.6, 0.8, 0.5), Color = pinkDark, Ellipsoid = true })
		local offset = CFrame.new(0, e.Size.Y * s * 0.45, 0)
		local w = attach(body, ear, e.Base * offset)
		attach(ear, inner, CFrame.new(0, 0, -0.035 * s))
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
			local fin = part(model, { Name = "Fin", Size = Vector3.new(0.14, 0.42 - k * 0.12, 0.07) * s, Color = k == 0 and pink or pinkLight, Ellipsoid = true })
			attach(body, fin, cf * CFrame.new(k * 0.07 * s, (0.18 + k * 0.1) * s, 0) * CFrame.Angles(0, 0, k * 0.4))
		end
	end

	-- Side appendage (its left) with a gold horn and a star.
	local side = part(model, { Name = "SideHand", Size = Vector3.new(0.75, 0.5, 0.45) * s, Color = pink, Ellipsoid = true })
	attach(body, side, CFrame.new(-1.0 * s, -0.2 * s, -0.1 * s) * CFrame.Angles(0, 0, 0.4))
	cone(model, body, Vector3.new(-1.32 * s, -0.08 * s, -0.1 * s), Vector3.new(-1, 0.5, -0.2), 0.3 * s, 0.07 * s, gold, Enum.Material.Metal)
	star5(model, body, Vector3.new(-1.02 * s, -0.12 * s, -0.33 * s), Vector3.new(-0.2, 0.1, -1), 0.22 * s, starColor, 0.5)

	-- Five thin legs ending in hearts (four animated).
	local legX = { -0.34, -0.15, 0.04, 0.22, 0.4 }
	for i = 1, 5 do
		local base = CFrame.new(legX[i] * s, -1.4 * s, (i % 2 == 0 and 0.12 or -0.12) * s)
		local legLength = (0.55 + ((i * 7) % 4) * 0.1) * s
		local leg = part(model, { Name = "Leg" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(legLength, 0.06 * s, 0.06 * s), Color = pinkDark })
		local offset = CFrame.new(0, -legLength / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local w = attach(body, leg, base * offset)
		if i <= 4 then
			rig.Joints["Leg" .. i] = { Weld = w, Base = base, Offset = offset }
		end
		-- Heart: two lobes and a point, facing forward.
		local footCF = CFrame.new(-legLength / 2 - 0.16 * s, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2)
		for _, sx in ipairs({ -1, 1 }) do
			local lobe = part(model, { Name = "HeartLobe", Size = Vector3.new(0.24, 0.24, 0.12) * s, Color = heart, Ellipsoid = true })
			attach(leg, lobe, footCF * CFrame.new(sx * 0.09 * s, 0.05 * s, 0))
		end
		local point = part(model, { Name = "HeartPoint", Size = Vector3.new(0.22, 0.22, 0.1) * s, Color = heart })
		attach(leg, point, footCF * CFrame.new(0, -0.07 * s, 0) * CFrame.Angles(0, 0, math.pi / 4))
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
local function buildAct1(scale)
	local settings = TuskConfig.StandModels and TuskConfig.StandModels[1] or {}
	if settings.Style == "Classic" then
		return buildAct1Classic(scale)
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
	return builder(scale)
end

return TuskStandModels
end

-- ======================================================================
-- MODULE: TuskUI
-- ======================================================================
__modules["TuskUI"] = function()
--[[
	TuskUI  (StarterPlayerScripts.SpinClient.UI.TuskUI)

	Battlegrounds-style move HUD (shown while Johnny or Gyro is equipped):
	  * header: Act / character name with a slanted colour band + tagline
	  * hotbar of move cards: M1, 1, 2, 3 and a big ULT card
	      - key badge, a drawn icon for each move, the move name
	      - cooldown shade that drains with a countdown, greys the icon,
	        then a white "ready" flash and pop
	      - cards squash when pressed (mouse, touch or keyboard)
	      - hold moves show a charge bar (FULL when fully charged)
	  * ULT card: rising meter, %, READY glow with a spinning shine,
	    LOCKED timer after an awakening
	  * sneak chip (Johnny), combo counter, toasts, awakening banner with
	    menacing "ゴ" letters, Awakened timer bar
	  * scales down on small screens
	Act menu (T / MOVESET button): Studio test tool, one card per Act.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local Net = __require("Net")
local VFXLib = __require("VFXLib")

local TuskUI = {}

local player = Players.LocalPlayer
local colors = TuskConfig.Colors
local DARK = Color3.fromRGB(12, 16, 28)
local DARK2 = Color3.fromRGB(26, 34, 56)
local GREY = Color3.fromRGB(110, 118, 135)
local WHITE = Color3.new(1, 1, 1)
local FONT = Enum.Font.GothamBlack
local TITLE_FONT = Enum.Font.Bangers

local CARD_W, CARD_H, M1_W, ULT_W, GAP = 84, 96, 66, 112, 8

local callbacks
local gui, hud, hudScale, header, actLabel, actGradient, actBand, taglineLabel
local sneakChip, sneakHint, comboFrame, comboNumber, comboWord, comboDrain
local toastFrame, toastLabel, toastAccent
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
	l.TextColor3 = colors.Ice
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
	if has("BARRAGE") then
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
	button.BackgroundColor3 = DARK
	button.BackgroundTransparency = 0.08
	button.AutoButtonColor = false
	button.Text = ""
	button.ClipsDescendants = false
	button.Parent = parent
	corner(button, 10)
	gradient(button, Color3.fromRGB(200, 210, 230), Color3.fromRGB(120, 130, 150), 90)
	local edge = stroke(button, WHITE, 2)
	local edgeGradient = gradient(edge, theme.Primary, theme.Secondary, 45)
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	-- Glow behind the card (shown when an ability is ready / ultimate is ready).
	local glow = frame(button, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 8, 1, 8), BackgroundTransparency = 1, ZIndex = 0 })
	corner(glow, 13)
	local glowStroke = stroke(glow, theme.Primary, 4)
	glowStroke.Transparency = 1
	local accent = frame(button, { Size = UDim2.new(1, -16, 0, 3), Position = UDim2.fromOffset(8, 0), BackgroundColor3 = theme.Primary, ZIndex = 2 })
	corner(accent, 2)

	local badge = frame(button, { Position = UDim2.fromOffset(5, 6), Size = UDim2.fromOffset(26, 18), BackgroundColor3 = theme.Primary, ZIndex = 4 })
	corner(badge, 5)
	local key = text(badge, { Size = UDim2.fromScale(1, 1), TextSize = 12, TextColor3 = DARK, TextStrokeTransparency = 1, Text = "", ZIndex = 5 })

	local icon = frame(button, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, ZIndex = 3 })
	local name = text(button, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(1, -8, 0, 26), TextScaled = true, TextWrapped = true, Text = "", ZIndex = 3 })
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MaxTextSize = 12
	nameLimit.Parent = name

	-- Cooldown shade: drains from the top down; countdown in the middle.
	local shade = frame(button, { Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, ZIndex = 6 })
	corner(shade, 10)
	local shadeEdge = frame(shade, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = theme.Primary, ZIndex = 7 })
	local timer = text(button, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 22), TextSize = 26, TextStrokeTransparency = 0.2, Text = "", ZIndex = 8 })
	local flash = frame(button, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 9 })
	corner(flash, 10)

	-- Charge bar above the card (hold moves).
	local chargeBack = frame(button, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.new(1, -6, 0, 7), BackgroundColor3 = DARK, Visible = false, ZIndex = 4 })
	corner(chargeBack, 4)
	stroke(chargeBack, WHITE, 1)
	local chargeFill = frame(chargeBack, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = theme.Primary, ZIndex = 5 })
	corner(chargeFill, 4)
	local chargeText = text(chargeBack, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -1), Size = UDim2.fromOffset(60, 14), TextSize = 11, Text = "", ZIndex = 5 })

	local card = {
		Button = button, Scale = scale, Edge = edge, EdgeGradient = edgeGradient, Glow = glow, GlowStroke = glowStroke, Accent = accent,
		Badge = badge, Key = key, Icon = icon, Name = name, Shade = shade, ShadeEdge = shadeEdge, Timer = timer,
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
	toastLabel.TextColor3 = color:Lerp(WHITE, 0.45)
	toastFrame.Size = UDim2.fromOffset(math.clamp(#message * 9 + 46, 160, 460), 32)
	toastFrame.Visible = true
	animateJob("toast", 1.4, function(a)
		local slide = a < 0.12 and (1 - a / 0.12) or 0
		local fade = a < 0.75 and 0 or (a - 0.75) / 0.25
		toastFrame.Position = UDim2.new(0.5, 0, 1, -20 + slide * 14)
		toastFrame.BackgroundTransparency = 0.15 + fade * 0.85
		toastAccent.BackgroundTransparency = fade
		toastLabel.TextTransparency = fade
		toastLabel.TextStrokeTransparency = math.max(0.5, fade)
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
	local col = combo.Count >= 15 and colors.Gold or (combo.Count >= 8 and theme.Primary or colors.Ice)
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
	menu.BackgroundColor3 = DARK
	menu.BackgroundTransparency = 0.05
	menu.Visible = false
	menu.ZIndex = 20
	menu.Parent = gui
	corner(menu, 12)
	stroke(menu, colors.Cyan, 2)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(860, 330)
	limit.Parent = menu

	text(menu, { Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -80, 0, 36), Font = TITLE_FONT, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Left, Text = "TUSK — CHOOSE YOUR ACT", ZIndex = 21 })
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(32, 32)
	close.BackgroundColor3 = Color3.fromRGB(40, 50, 80)
	close.Font = FONT
	close.Text = "X"
	close.TextSize = 16
	close.TextColor3 = colors.Ice
	close.ZIndex = 21
	close.Parent = menu
	corner(close, 6)
	close.Activated:Connect(function()
		menu.Visible = false
	end)

	local row = Instance.new("ScrollingFrame")
	row.Position = UDim2.fromOffset(14, 56)
	row.Size = UDim2.new(1, -28, 1, -70)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.AutomaticCanvasSize = Enum.AutomaticSize.X
	row.CanvasSize = UDim2.new()
	row.ScrollBarThickness = 4
	row.ZIndex = 21
	row.Parent = menu
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.Parent = row

	for act = 1, 4 do
		local info = Registry.get(act)
		local ready = Registry.isImplemented(act)
		local card = Instance.new("Frame")
		card.Size = UDim2.fromOffset(196, 250)
		card.BackgroundColor3 = Color3.fromRGB(20, 28, 48)
		card.BackgroundTransparency = ready and 0 or 0.4
		card.ZIndex = 22
		card.Parent = row
		corner(card, 10)
		stroke(card, ready and info.Theme.Primary or Color3.fromRGB(70, 80, 100), 2)
		text(card, { Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 30), Font = TITLE_FONT, TextSize = 28, TextColor3 = ready and info.Theme.Primary or Color3.fromRGB(130, 140, 160), TextXAlignment = Enum.TextXAlignment.Left, Text = info.Name, ZIndex = 23 })
		text(card, { Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 16), TextSize = 12, TextColor3 = Color3.fromRGB(170, 185, 210), TextXAlignment = Enum.TextXAlignment.Left, Text = info.Tagline, ZIndex = 23 })
		local moves = "M1  " .. info.M1 .. "\n1  " .. info.Abilities[1] .. "\n2  " .. info.Abilities[2] .. "\n3  " .. info.Abilities[3] .. "\nULT  " .. info.Ultimate
		text(card, { Position = UDim2.fromOffset(10, 62), Size = UDim2.new(1, -20, 0, 120), TextSize = 12, TextColor3 = Color3.fromRGB(210, 220, 240), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Text = moves, ZIndex = 23 })
		if ready then
			local pick = Instance.new("TextButton")
			pick.AnchorPoint = Vector2.new(0.5, 1)
			pick.Position = UDim2.new(0.5, 0, 1, -10)
			pick.Size = UDim2.new(1, -20, 0, 36)
			pick.BackgroundColor3 = info.Theme.Secondary
			pick.Font = FONT
			pick.TextSize = 15
			pick.TextColor3 = Color3.new(1, 1, 1)
			pick.Text = "SELECT"
			pick.ZIndex = 23
			pick.Parent = card
			corner(pick, 8)
			pick.Activated:Connect(function()
				callbacks.Select(act)
				menu.Visible = false
			end)
		else
			text(card, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 36), TextSize = 13, TextColor3 = Color3.fromRGB(150, 160, 180), Text = "IN DEVELOPMENT", ZIndex = 23 })
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

	-- Header: slanted colour band + name + tagline.
	header = frame(hud, { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	actBand = frame(header, { Position = UDim2.fromOffset(-6, 6), Size = UDim2.fromOffset(230, 30), BackgroundColor3 = theme.Primary, Rotation = -3, ZIndex = 1 })
	corner(actBand, 4)
	local bandGradient = Instance.new("UIGradient")
	bandGradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1) })
	bandGradient.Parent = actBand
	actLabel = text(header, { Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(320, 34), Font = TITLE_FONT, TextSize = 34, TextColor3 = WHITE, TextStrokeTransparency = 0, TextStrokeColor3 = DARK, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 2 })
	actGradient = gradient(actLabel, WHITE, theme.Primary, 90)
	taglineLabel = text(header, { Position = UDim2.fromOffset(8, 32), Size = UDim2.fromOffset(320, 12), TextSize = 11, TextColor3 = Color3.fromRGB(190, 210, 235), TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 2 })

	-- Sneak chip (Johnny only), right side of the header.
	sneakChip = Instance.new("TextButton")
	sneakChip.Name = "Sneak"
	sneakChip.AnchorPoint = Vector2.new(1, 0)
	sneakChip.Position = UDim2.new(1, 0, 0, 8)
	sneakChip.Size = UDim2.fromOffset(104, 26)
	sneakChip.BackgroundColor3 = DARK
	sneakChip.BackgroundTransparency = 0.1
	sneakChip.AutoButtonColor = false
	sneakChip.Text = ""
	sneakChip.Parent = header
	corner(sneakChip, 13)
	local sneakStroke = stroke(sneakChip, Color3.fromRGB(60, 80, 120), 2)
	local sneakKey = frame(sneakChip, { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(20, 18), BackgroundColor3 = Color3.fromRGB(60, 80, 120) })
	corner(sneakKey, 9)
	local sneakKeyText = text(sneakKey, { Size = UDim2.fromScale(1, 1), TextSize = 11, TextColor3 = WHITE, TextStrokeTransparency = 1, Text = "C" })
	local sneakText = text(sneakChip, { Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -32, 1, 0), TextSize = 13, TextColor3 = Color3.fromRGB(150, 170, 200), Text = "SNEAK" })
	sneakChip:SetAttribute("Built", true)
	sneakChip.Activated:Connect(function()
		callbacks.Sneak()
	end)
	slots.SneakParts = { Stroke = sneakStroke, Key = sneakKey, KeyText = sneakKeyText, Text = sneakText }
	sneakHint = text(hud, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 0, -2), Size = UDim2.fromOffset(240, 16), TextSize = 12, TextColor3 = colors.Cyan, TextXAlignment = Enum.TextXAlignment.Right, Text = "", Visible = false })

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
	ult.Meter = frame(ult.Button, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.35, ZIndex = 1 })
	corner(ult.Meter, 10)
	ult.MeterGradient = gradient(ult.Meter, theme.Primary, theme.Secondary, 90)
	ult.Percent = text(ult.Button, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(50, 16), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Text = "0%", ZIndex = 4 })
	ult.Icon.Size = UDim2.fromOffset(46, 46)
	drawIcon(ult.Icon, "star")
	ult.Button.Activated:Connect(function()
		callbacks.Ultimate()
	end)

	-- Awakened timer bar under the hotbar.
	awakenBar = frame(hud, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52 + CARD_H + 6), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = DARK, Visible = false })
	corner(awakenBar, 3)
	awakenFill = frame(awakenBar, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = colors.Cyan })
	corner(awakenFill, 3)

	-- Combo counter (right middle of the screen).
	comboFrame = frame(gui, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -28, 0.42, 0), Size = UDim2.fromOffset(200, 90), BackgroundTransparency = 1, Visible = false })
	comboNumber = text(comboFrame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(200, 60), Font = TITLE_FONT, TextSize = 58, TextStrokeTransparency = 0.15, TextXAlignment = Enum.TextXAlignment.Right, Text = "" })
	comboWord = text(comboFrame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 58), Size = UDim2.fromOffset(200, 18), Font = TITLE_FONT, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, Text = "HIT COMBO!" })
	comboDrain = frame(comboFrame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 80), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = colors.Ice })
	corner(comboDrain, 2)

	-- Toast pill above the hotbar.
	local toastHolder = frame(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -190), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1 })
	toastFrame = frame(toastHolder, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(260, 32), BackgroundColor3 = DARK, BackgroundTransparency = 0.15, Visible = false })
	corner(toastFrame, 16)
	toastAccent = frame(toastFrame, { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.fromRGB(255, 110, 100), Rotation = 45 })
	corner(toastAccent, 3)
	toastLabel = text(toastFrame, { Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -40, 1, 0), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Text = "" })

	-- Awakening banner: black slash band, gradient title, menacing ゴ letters.
	bannerBand = frame(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.new(1.4, 0, 0, 110), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Rotation = -4 })
	banner = text(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.fromOffset(800, 84), Font = TITLE_FONT, TextSize = 78, TextColor3 = WHITE, TextTransparency = 1, TextStrokeTransparency = 1, Text = "", ZIndex = 3 })
	bannerGradient = gradient(banner, WHITE, colors.Cyan, 90)
	bannerSub = text(banner, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(600, 22), TextSize = 17, TextTransparency = 1, TextStrokeTransparency = 1, Text = "", ZIndex = 3 })
	for i, spot in ipairs({ { 0.2, -20 }, { 0.27, 25 }, { 0.73, -25 }, { 0.8, 20 } }) do
		local m = text(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(70, 70), TextSize = 56, Font = FONT, Text = "ゴ", TextTransparency = 1, TextStrokeTransparency = 0.6, TextStrokeColor3 = Color3.fromRGB(40, 0, 60), Rotation = (i % 2 == 0) and 12 or -12, ZIndex = 2 })
		m:SetAttribute("X", spot[1])
		m:SetAttribute("Y", spot[2])
		menacing[i] = m
	end

	-- MOVESET button (opens the Act menu), Studio only in Awaken mode.
	if TuskUI.menuAllowed() then
		local moveset = Instance.new("TextButton")
		moveset.AnchorPoint = Vector2.new(1, 0)
		moveset.Position = UDim2.new(1, -12, 0, 46)
		moveset.Size = UDim2.fromOffset(130, 28)
		moveset.BackgroundColor3 = DARK
		moveset.BackgroundTransparency = 0.2
		moveset.Font = FONT
		moveset.TextSize = 13
		moveset.TextColor3 = colors.Ice
		moveset.Text = "TUSK ACTS (T)"
		moveset.Parent = gui
		corner(moveset, 6)
		stroke(moveset, colors.Cyan, 1.5)
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

local function setKey(card, keyText)
	card.Key.Text = keyText
	card.Badge.Visible = keyText ~= ""
	card.Badge.Size = UDim2.fromOffset(math.max(22, #keyText * 8 + 12), 18)
end

local function stepCard(card, now, dt, cooling)
	-- Press squash + ready pop + hover.
	local target = (card.Pressed and 0.9 or 1) + (card.Pop or 0) + (card.Hover and 0.03 or 0)
	card.Scale.Scale = card.Scale.Scale + (target - card.Scale.Scale) * math.min(1, dt * 18)
	-- Cooldown shade.
	if cooling then
		local left = card.CooldownEnd - now
		card.Shade.Size = UDim2.fromScale(1, math.clamp(left / math.max(card.CooldownDur, 0.01), 0, 1))
		card.Timer.Text = left >= 10 and tostring(math.ceil(left)) or string.format("%.1f", left)
		colorIcon(card.Icon, GREY)
		card.Name.TextColor3 = GREY
		card.Badge.BackgroundColor3 = GREY
	elseif card.WasCooling then
		card.Shade.Size = UDim2.fromScale(1, 0)
		card.Timer.Text = ""
		colorIcon(card.Icon, theme.Primary:Lerp(WHITE, 0.35))
		card.Name.TextColor3 = colors.Ice
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
		elseif card.ChargeBack.Visible then
			card.ChargeBack.Visible = false
			card.GlowStroke.Transparency = 1
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

	-- Sneak chip.
	local sneaking = character and character:GetAttribute("TuskSneaking") == true
	local sp = slots.SneakParts
	sneakChip.Visible = Registry.characterOf(act) == "Johnny"
	sp.KeyText.Text = keyName("Sneak") ~= "" and keyName("Sneak") or "C"
	sp.Stroke.Color = sneaking and theme.Primary or Color3.fromRGB(60, 80, 120)
	sp.Key.BackgroundColor3 = sneaking and theme.Primary or Color3.fromRGB(60, 80, 120)
	sp.Text.TextColor3 = sneaking and theme.Primary or Color3.fromRGB(150, 170, 200)
	sp.Text.Text = sneaking and "SNEAKING" or "SNEAK"
	sneakChip.BackgroundColor3 = sneaking and DARK2 or DARK
	sneakHint.Visible = sneaking and sneakChip.Visible
	sneakHint.Text = "M1 / TAP: SNEAK ATTACK"
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
	NotAvailable = "THAT ACT IS IN DEVELOPMENT",
	Locked = "ACT LOCKED",
	SwitchCooldown = "WAIT BEFORE SWITCHING ACTS",
	SneakCooldown = "SNEAK ON COOLDOWN",
	SneakAttackCooldown = "SNEAK ATTACK ON COOLDOWN",
	NoTarget = "NO TARGET IN FRONT",
	Blocked = "NO ROOM TO MOVE THERE",
	TooSoon = "TUSK ISN'T READY TO AWAKEN YET",
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

return TuskVFX
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
-- MODULE: WreckingBallModel
-- ======================================================================
__modules["WreckingBallModel"] = function()
--[[
	WreckingBallModel  (ReplicatedStorage.SpinShared.WreckingBallModel)

	Procedurally builds a Wrecking Ball from the owner's reference image:
	a glossy orange metal sphere, ten raised gold studs sitting in darker
	gold collars, and a dark seam groove wrapping around the surface.
	Not used yet: kept for the Wrecking Ball phase.

	WreckingBallModel.build(diameter, withGrooves) -> Model (PrimaryPart = "Core")

	All parts are visual only: no collision, no queries, no touch events,
	massless, and welded to the Core. Anchor the Core to move it with
	PivotTo, or weld the Core to a hand.

	Swapping in a real mesh later: put a Model named "WreckingBall" (with a
	PrimaryPart) in ReplicatedStorage.SpinShared.Assets and build() will
	clone it instead of generating one.
]]

local WreckingBallModel = {}

WreckingBallModel.Colors = {
	Ball = Color3.fromRGB(226, 96, 24),
	BallDark = Color3.fromRGB(150, 52, 12),
	Stud = Color3.fromRGB(255, 205, 70),
}

local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))
local STUD_COUNT = 10
local SEAM_SEGMENTS = 22

local function visualPart(props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function weld(core, part)
	local w = Instance.new("WeldConstraint")
	w.Part0 = core
	w.Part1 = part
	w.Parent = part
end

local function fromOverride(diameter)
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
	local custom = assets and assets:FindFirstChild("WreckingBall")
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		local clone = custom:Clone()
		local size = clone:GetExtentsSize()
		local largest = math.max(size.X, size.Y, size.Z)
		if largest > 0 then
			clone:ScaleTo(clone:GetScale() * diameter / largest)
		end
		clone.PrimaryPart.Name = "Core"
		return clone
	end
	return nil
end

function WreckingBallModel.build(diameter, withGrooves)
	diameter = diameter or 1
	if withGrooves == nil then
		withGrooves = true
	end

	local override = fromOverride(diameter)
	if override then
		return override
	end

	local colors = WreckingBallModel.Colors
	local r = diameter / 2

	local model = Instance.new("Model")
	model.Name = "WreckingBall"

	local core = visualPart({
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		Color = colors.Ball,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.2,
		Massless = false,
	})
	core.CFrame = CFrame.new()
	core.Parent = model
	model.PrimaryPart = core

	-- Attachments other systems hook effects onto.
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = core
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, r * 0.9, 0)
	top.Parent = core
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -r * 0.9, 0)
	bottom.Parent = core

	-- Gold studs on a Fibonacci sphere so they spread evenly.
	for i = 0, STUD_COUNT - 1 do
		local y = 1 - (i + 0.5) / STUD_COUNT * 2
		local ring = math.sqrt(1 - y * y)
		local theta = i * GOLDEN_ANGLE
		local dir = Vector3.new(math.cos(theta) * ring, y, math.sin(theta) * ring)
		local up = math.abs(dir.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)

		local collar = visualPart({
			Name = "StudCollar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(diameter * 0.05, diameter * 0.2, diameter * 0.2),
			Color = colors.BallDark:Lerp(colors.Stud, 0.35),
			Material = Enum.Material.Metal,
			Reflectance = 0.1,
		})
		-- Cylinder axis is X, so point RightVector along the surface normal.
		local right = dir
		local back = right:Cross(up).Unit
		local realUp = back:Cross(right).Unit
		collar.CFrame = CFrame.fromMatrix(dir * r * 0.985, right, realUp)
		collar.Parent = model
		weld(core, collar)

		local stud = visualPart({
			Name = "Stud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(diameter * 0.15, diameter * 0.15, diameter * 0.15),
			Color = colors.Stud,
			Material = Enum.Material.Metal,
			Reflectance = 0.35,
		})
		stud.CFrame = CFrame.new(dir * r * 1.01)
		stud.Parent = model
		weld(core, stud)
	end

	-- Seam groove: a wave wrapping the ball like a tennis-ball seam.
	if withGrooves then
		local function seamPoint(t)
			local lon = t * math.pi * 2
			local lat = 0.55 * math.sin(2 * lon)
			return Vector3.new(math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon)) * r * 1.003
		end
		for i = 0, SEAM_SEGMENTS - 1 do
			local a = seamPoint(i / SEAM_SEGMENTS)
			local b = seamPoint((i + 1) / SEAM_SEGMENTS)
			local mid = (a + b) / 2
			local len = (b - a).Magnitude
			local seg = visualPart({
				Name = "Groove",
				Size = Vector3.new(diameter * 0.035, diameter * 0.012, len * 1.08),
				Color = colors.BallDark,
				Material = Enum.Material.SmoothPlastic,
			})
			seg.CFrame = CFrame.lookAt(mid, b, mid.Unit)
			seg.Parent = model
			weld(core, seg)
		end
	end

	-- Everything was laid out around the origin; move the model as one piece from here on.
	return model
end

return WreckingBallModel
end

-- ======================================================================
-- START
-- ======================================================================
__require("SettingsUI").init()
__require("HitFX").init()
__require("TuskStand").init()
__require("TuskProjectiles").init()
__require("TuskSneakController").init()
__require("TuskController").init()
__require("WorldClient").init()
__require("CharacterCard").init()
