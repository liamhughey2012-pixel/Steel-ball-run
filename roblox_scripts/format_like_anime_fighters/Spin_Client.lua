--[[
	Spin_Client  (LocalScript)
	PUT IT IN: StarterPlayer > StarterPlayerScripts

	Spin Battlegrounds client: controls (PC, controller, mobile), all VFX,
	the Tusk Stand, poses, HUD, Act menu, NPC speech bubbles, desert dust.

	Needs these ModuleScripts in ReplicatedStorage: SpinConfig, TuskConfig.
	Works with the Script Spin_Server in ServerScriptService.
]]

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
	if not VFXLib.acquire() then
		return
	end
	local cf = root.CFrame * CFrame.new(side * 0.4, 0.3, -2.4) * CFrame.Angles(0, 0, side * 0.5)
	local ring = VFXLib.ring({ CFrame = cf, Radius = 1.6, Width = 0.22, Color = color, Segments = 10, Transparency = 0.1 })
	VFXLib.animate(0.16, function(a)
		ring:SetCFrame(cf * CFrame.Angles(0, side * (-1.2 + a * 2.4), 0))
		ring:SetRadius(1.6 + a * 0.8)
		ring:SetTransparency(0.1 + a * 0.9)
	end, function()
		ring:Destroy()
		VFXLib.release()
	end)
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
local function onUltimate(data)
	local character = data.Character
	local root = rootOf(character)
	if not root then
		return
	end
	if data.Phase == "Start" then
		TuskAnimation.play(character, "Awakening")
		VFXLib.sound(sounds.AwakeningBuild, root, 0.8, 1)
		TuskVFX.CreateTuskTransformation(character, {
			Duration = data.Windup,
			Color = colors.Cyan,
			Color2 = colors.Blue,
			OnManifest = function()
				TuskStand.action(character, "Manifest", { Duration = 0.6 })
			end,
		})
		if isLocal(character) then
			-- Camera transition: slow push-in during the buildup.
			CameraFX.setFovHold(-12)
			task.delay(data.Windup, function()
				CameraFX.setFovHold(0)
				CameraFX.fovPunch(16, 0.6)
			end)
		end
	elseif data.Phase == "Burst" then
		VFXLib.sound(sounds.AwakeningBurst, data.Position, 1, 1)
		CameraFX.shakeAt(data.Position, 1.2, 90)
		if isLocal(character) then
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
			TuskAnimation.play(character, "NailShot")
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
		VFXLib.sound(sounds.AwakeningBurst, pos, 1, 0.95)
		CameraFX.shakeAt(pos, 1.3, 100)
		if Common.isLocal(character) then
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
		TuskAnimation.play(character, "NailShot")
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
			TuskAnimation.play(character, "M1_4")
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

local gui, card, portrait, viewport, standLabel, pips, hpFill, hpText, scale
local shownAct

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

	label(card, {
		Position = UDim2.fromOffset(98, 6),
		Size = UDim2.new(1, -106, 0, 28),
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
		standLabel.Text = info and ("STAND  ·  " .. info.Name) or TuskConfig.Character.Title
		standLabel.TextColor3 = info and info.Theme.Primary or Color3.fromRGB(200, 220, 255)
		for i, pip in ipairs(pips) do
			local on = act ~= nil and i <= act
			local theme = Registry.get(i) and Registry.get(i).Theme.Primary or GOLD
			pip.BackgroundColor3 = on and theme or Color3.fromRGB(60, 60, 80)
		end
		if evolved and info then
			CharacterCard.pop(info.Theme.Primary)
		end
	end
end

return CharacterCard
end

-- ======================================================================
-- MODULE: JointCache
-- ======================================================================
__modules["JointCache"] = function()
--[[
	JointCache  (StarterPlayerScripts.SpinClient.JointCache)
	Remembers each Motor6D's original C0 the first time any pose system
	touches it, so Spin poses and Tusk poses can both restore the true
	rest pose instead of each other's leftovers.
]]

local JointCache = {}
local originals = setmetatable({}, { __mode = "k" })

function JointCache.original(motor)
	local c0 = originals[motor]
	if not c0 then
		c0 = motor.C0
		originals[motor] = c0
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
-- MODULE: ProceduralPose
-- ======================================================================
__modules["ProceduralPose"] = function()
--[[
	ProceduralPose  (StarterPlayerScripts.SpinClient.ProceduralPose)

	Animation-free arm posing for the Spin throw: tweens the right shoulder
	Motor6D's C0 on top of whatever Animator is playing, then restores it.
	Works on R15 and R6. C0 edits made on a client do not replicate, so
	SpinVFX calls this on EVERY client for EVERY charging character (driven
	by the replicated SpinChargeStart attribute). Everyone sees the pose.

	When real animations are uploaded, set ProceduralPose.Enabled = false
	and play the Animation tracks from SpinController instead.

	Pitch angles (degrees, rotation about the shoulder's side axis):
	  0 = arm down, 90 = arm straight forward, 180 = arm straight up.
]]

local ProceduralPose = {}

ProceduralPose.Enabled = true
ProceduralPose.Poses = {
	Charge = { Pitch = 195, Roll = -12 }, -- wound up over the shoulder, behind the head
	Throw = { Pitch = 80, Roll = 0 }, -- whipped forward at release
}

local jobs = setmetatable({}, { __mode = "k" })

local VFXLib = __require("VFXLib")
local JointCache = __require("JointCache")

local function getShoulder(character)
	local upper = character:FindFirstChild("RightUpperArm")
	if upper then
		return upper:FindFirstChild("RightShoulder"), "R15"
	end
	local torso = character:FindFirstChild("Torso")
	if torso then
		return torso:FindFirstChild("Right Shoulder"), "R6"
	end
	return nil
end

local function poseOffset(rig, pose)
	local pitch = math.rad(pose.Pitch)
	local roll = math.rad(pose.Roll or 0)
	if rig == "R15" then
		return CFrame.Angles(pitch, 0, roll)
	end
	-- R6 shoulder C0 is rotated so its local Z is the torso's side axis.
	return CFrame.Angles(roll, 0, pitch)
end

local function tweenC0(motor, target, duration)
	VFXLib.cancel(jobs[motor])
	local from = motor.C0
	jobs[motor] = VFXLib.animate(duration, function(a)
		if motor.Parent then
			motor.C0 = from:Lerp(target, VFXLib.easeOut(a))
		end
	end)
end

function ProceduralPose.play(character, poseName, duration)
	if not ProceduralPose.Enabled or not character then
		return
	end
	local motor, rig = getShoulder(character)
	local pose = ProceduralPose.Poses[poseName]
	if not motor or not pose then
		return
	end
	tweenC0(motor, JointCache.original(motor) * poseOffset(rig, pose), duration or 0.15)
end

function ProceduralPose.reset(character, duration)
	if not character then
		return
	end
	local motor = getShoulder(character)
	if motor then
		tweenC0(motor, JointCache.original(motor), duration or 0.25)
	end
end

-- Hand part the held ball is welded to, plus the grip offset.
function ProceduralPose.getHand(character)
	local hand = character:FindFirstChild("RightHand")
	if hand then
		return hand, CFrame.new(0, -0.45, -0.1)
	end
	local arm = character:FindFirstChild("Right Arm")
	if arm then
		return arm, CFrame.new(0, -1.1, -0.1)
	end
	return nil
end

return ProceduralPose
end

-- ======================================================================
-- MODULE: SpinController
-- ======================================================================
__modules["SpinController"] = function()
--[[
	SpinController  (StarterPlayerScripts.SpinClient.SpinController)

	Local input for the Golden Spin. Hold to charge, release to throw.
	  PC:         hold R (aims at the mouse)
	  Controller: hold RT (aims where the camera looks)
	  Mobile:     hold the on-screen SPIN button (aims where the camera looks)

	Sends only "Start", "Release" + aim direction, or "Cancel".
	The server decides everything else and answers with SpinState.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = nil -- (bundled: modules are inlined)
local SpinConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("SpinConfig"))
local Net = __require("Net")
local CameraFX = __require("CameraFX")
local VFXLib = __require("VFXLib")
local SpinMeter = __require("SpinMeter")

local SpinController = {}

local player = Players.LocalPlayer
local Request
local charging = false
local chargeStart = 0

local function aliveCharacter()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return character, root
	end
	return nil
end

local function usesCameraAim()
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Touch or string.find(last.Name, "Gamepad") ~= nil
end

local function aimDirection()
	local character, root = aliveCharacter()
	local camera = workspace.CurrentCamera
	if not character or not camera then
		return nil
	end
	local origin = (root.CFrame * SpinConfig.Projectile.SpawnOffset).Position
	if usesCameraAim() then
		return camera.CFrame.LookVector
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, VFXLib.Folder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local target = hit and hit.Position or (ray.Origin + ray.Direction * 600)
	local direction = target - origin
	if direction.Magnitude < 1 then
		return root.CFrame.LookVector
	end
	return direction.Unit
end

local function stopLocal()
	charging = false
	SpinMeter.hideCharge()
	CameraFX.setFovHold(0)
end

local function begin()
	if charging or not aliveCharacter() then
		return
	end
	charging = true
	chargeStart = os.clock()
	Request:FireServer("Start")
	SpinMeter.showCharge()
	CameraFX.setFovHold(-3)
end

local function finish()
	if not charging then
		return
	end
	stopLocal()
	Request:FireServer("Release", aimDirection())
end

local function cancel()
	if not charging then
		return
	end
	stopLocal()
	Request:FireServer("Cancel")
end

local function onState(data)
	local status = data.Status
	if status == "Denied" then
		stopLocal()
		if data.Reason == "Cooldown" then
			SpinMeter.flashDenied(string.format("COOLDOWN %.1fs", data.Remaining or 0))
		else
			SpinMeter.flashDenied("STUNNED")
		end
	elseif status == "Cancelled" then
		stopLocal()
		if data.Reason == "Interrupted" then
			SpinMeter.flashDenied("INTERRUPTED!")
		end
		SpinMeter.startCooldown(data.Cooldown or 0)
	elseif status == "Released" then
		if charging then
			stopLocal() -- server auto-released at max hold
		end
		local level = SpinConfig.Levels[data.Level]
		if data.Perfect then
			SpinMeter.popup("PERFECT SPIN!", SpinConfig.Colors.Perfect, true)
		else
			SpinMeter.popup(level.Name, SpinConfig.Colors.GoldLight, false)
		end
		SpinMeter.startCooldown(data.Cooldown or 0)
	end
end

function SpinController.init()
	Request = Net.get("SpinRequest")
	local FX = Net.get("SpinFX")
	FX.OnClientEvent:Connect(function(name, data)
		if name == "SpinState" then
			onState(data)
		end
	end)

	local input = SpinConfig.Input
	ContextActionService:BindAction(input.ActionName, function(_, state)
		if state == Enum.UserInputState.Begin then
			begin()
		elseif state == Enum.UserInputState.End then
			finish()
		elseif state == Enum.UserInputState.Cancel then
			cancel()
		end
		return Enum.ContextActionResult.Sink
	end, true, input.Keyboard, input.Gamepad)
	ContextActionService:SetTitle(input.ActionName, input.MobileButtonTitle)
	ContextActionService:SetPosition(input.ActionName, input.MobileButtonPosition)

	RunService.RenderStepped:Connect(function()
		if charging then
			SpinMeter.updateCharge(os.clock() - chargeStart)
		end
	end)

	player.CharacterAdded:Connect(function()
		stopLocal()
	end)
end

return SpinController
end

-- ======================================================================
-- MODULE: SpinMeter
-- ======================================================================
__modules["SpinMeter"] = function()
--[[
	SpinMeter  (StarterPlayerScripts.SpinClient.UI.SpinMeter)

	Golden Spin HUD:
	  * charge bar with Power tick, gold PERFECT zone and overcharge zone
	  * live level name ("QUICK SPIN" / "POWER SPIN" / "PERFECT SPIN")
	  * cooldown bar + key hint (R / RT / hidden on touch)
	  * centre-screen popup on release ("PERFECT SPIN!")
	  * VFX quality toggle (top right)
	Built in code so it can be dropped into any place. Later phases will
	merge this into the full ability-slot HUD.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = nil -- (bundled: modules are inlined)
local SpinConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("SpinConfig"))
local VFXQuality = __require("VFXQuality")
local VFXLib = __require("VFXLib")

local SpinMeter = {}

local colors = SpinConfig.Colors
local charge = SpinConfig.Charge
local MAX_T = charge.PerfectWindowStart + charge.PerfectWindowDuration + 0.6
local DARK = Color3.fromRGB(22, 16, 10)
local FONT = Enum.Font.GothamBlack

local gui, chargeFrame, fill, levelLabel, cooldownFill, cooldownLabel, keyHint, popupLabel, popupScale
local cooldownJob, popupJob, chargeFadeJob

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

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = colors.GoldLight
	l.TextStrokeTransparency = 0.4
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function keyText()
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return ""
	end
	if string.find(last.Name, "Gamepad") then
		return "RT"
	end
	return SpinConfig.Input.Keyboard.Name
end

function SpinMeter.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = Instance.new("ScreenGui")
	gui.Name = "SpinHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Bottom-centre panel.
	local panel = Instance.new("Frame")
	panel.Name = "SpinPanel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -24)
	panel.Size = UDim2.fromOffset(320, 58)
	panel.BackgroundTransparency = 1
	panel.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(320, 58)
	sizeLimit.Parent = panel

	-- Charge bar (hidden until charging).
	chargeFrame = Instance.new("Frame")
	chargeFrame.Name = "Charge"
	chargeFrame.Size = UDim2.new(1, 0, 0, 16)
	chargeFrame.BackgroundColor3 = DARK
	chargeFrame.BackgroundTransparency = 0.15
	chargeFrame.Visible = false
	chargeFrame.Parent = panel
	corner(chargeFrame, 8)
	stroke(chargeFrame, colors.Gold, 2)

	local function zone(name, from, to, color, transparency)
		local z = Instance.new("Frame")
		z.Name = name
		z.BorderSizePixel = 0
		z.Position = UDim2.fromScale(from / MAX_T, 0)
		z.Size = UDim2.fromScale((to - from) / MAX_T, 1)
		z.BackgroundColor3 = color
		z.BackgroundTransparency = transparency
		z.ZIndex = 1
		z.Parent = chargeFrame
		return z
	end
	local windowEnd = charge.PerfectWindowStart + charge.PerfectWindowDuration
	zone("PerfectZone", charge.PerfectWindowStart, windowEnd, colors.Perfect, 0.35)
	zone("Overcharge", windowEnd, MAX_T, Color3.fromRGB(120, 30, 20), 0.55)
	zone("PowerTick", SpinConfig.Levels[2].ChargeTime, SpinConfig.Levels[2].ChargeTime + 0.025, colors.GoldLight, 0.2)

	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = colors.Orange
	fill.ZIndex = 2
	fill.Parent = chargeFrame
	corner(fill, 8)

	levelLabel = label(chargeFrame, {
		Name = "Level",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -2),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 18,
		Text = "",
	})

	-- Cooldown row.
	local row = Instance.new("Frame")
	row.Name = "Cooldown"
	row.Position = UDim2.new(0, 0, 1, -22)
	row.Size = UDim2.new(1, 0, 0, 22)
	row.BackgroundColor3 = DARK
	row.BackgroundTransparency = 0.25
	row.Parent = panel
	corner(row, 6)
	stroke(row, colors.BallDark, 1.5)

	cooldownFill = Instance.new("Frame")
	cooldownFill.BorderSizePixel = 0
	cooldownFill.BackgroundColor3 = colors.Gold
	cooldownFill.BackgroundTransparency = 0.6
	cooldownFill.Size = UDim2.fromScale(0, 1)
	cooldownFill.Parent = row
	corner(cooldownFill, 6)

	keyHint = label(row, {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(0, 40, 1, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = keyText(),
	})
	label(row, {
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "GOLDEN SPIN",
	})
	cooldownLabel = label(row, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "READY",
	})

	UserInputService.LastInputTypeChanged:Connect(function()
		keyHint.Text = keyText()
	end)

	-- Centre popup.
	popupLabel = label(gui, {
		Name = "Popup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(500, 70),
		Font = Enum.Font.Bangers,
		TextSize = 56,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",
	})
	popupScale = Instance.new("UIScale")
	popupScale.Parent = popupLabel

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

function SpinMeter.showCharge()
	VFXLib.cancel(chargeFadeJob)
	chargeFrame.Visible = true
	chargeFrame.BackgroundTransparency = 0.15
	fill.Size = UDim2.fromScale(0, 1)
end

function SpinMeter.updateCharge(chargeTime)
	local level, perfect = SpinConfig.getLevel(chargeTime)
	local windowEnd = charge.PerfectWindowStart + charge.PerfectWindowDuration
	local over = chargeTime > windowEnd
	fill.Size = UDim2.fromScale(math.clamp(chargeTime / MAX_T, 0, 1), 1)
	if perfect then
		fill.BackgroundColor3 = colors.Perfect
		levelLabel.Text = "PERFECT SPIN — RELEASE!"
		levelLabel.TextColor3 = colors.Perfect
	elseif over then
		fill.BackgroundColor3 = Color3.fromRGB(170, 80, 40)
		levelLabel.Text = "OVERCHARGED"
		levelLabel.TextColor3 = Color3.fromRGB(230, 120, 90)
	else
		fill.BackgroundColor3 = level == 2 and colors.Gold or colors.Orange
		levelLabel.Text = SpinConfig.Levels[level].Name
		levelLabel.TextColor3 = colors.GoldLight
	end
end

function SpinMeter.hideCharge()
	VFXLib.cancel(chargeFadeJob)
	chargeFadeJob = VFXLib.animate(0.15, function(a)
		chargeFrame.BackgroundTransparency = 0.15 + a * 0.85
	end, function()
		chargeFrame.Visible = false
		levelLabel.Text = ""
	end)
end

function SpinMeter.startCooldown(seconds)
	VFXLib.cancel(cooldownJob)
	if seconds <= 0 then
		cooldownFill.Size = UDim2.fromScale(0, 1)
		cooldownLabel.Text = "READY"
		return
	end
	cooldownJob = VFXLib.animate(seconds, function(a)
		cooldownFill.Size = UDim2.fromScale(1 - a, 1)
		cooldownLabel.Text = string.format("%.1fs", seconds * (1 - a))
	end, function()
		cooldownFill.Size = UDim2.fromScale(0, 1)
		cooldownLabel.Text = "READY"
	end)
end

function SpinMeter.popup(text, color, big)
	VFXLib.cancel(popupJob)
	popupLabel.Text = text
	popupLabel.TextColor3 = color or colors.GoldLight
	local peak = big and 1.25 or 0.9
	popupJob = VFXLib.animate(big and 1.1 or 0.8, function(a)
		if a < 0.12 then
			popupScale.Scale = peak * (1.6 - a / 0.12 * 0.6)
		else
			popupScale.Scale = peak
		end
		local fade = math.clamp((a - 0.65) / 0.35, 0, 1)
		popupLabel.TextTransparency = fade
		popupLabel.TextStrokeTransparency = math.max(fade, 0.2)
	end, function()
		popupLabel.TextTransparency = 1
		popupLabel.TextStrokeTransparency = 1
	end)
end

function SpinMeter.flashDenied(text)
	SpinMeter.popup(text, Color3.fromRGB(230, 120, 90), false)
end

return SpinMeter
end

-- ======================================================================
-- MODULE: SpinVFX
-- ======================================================================
__modules["SpinVFX"] = function()
--[[
	SpinVFX  (StarterPlayerScripts.SpinClient.SpinVFX)

	Draws everything the Golden Spin does, for every player, on every client:
	  * Charge: Steel Ball spinning in the hand, golden rings that multiply
	    per level, rising particles, ground dust, perfect-window flash
	  * Release: muzzle shockwave, throw pose
	  * Projectile: spinning ball, tilted rotating rings, spiral + streak
	    trails, afterimages (High)
	  * Impact / Hit: layered shockwaves, sparks, dust, light, shake,
	    impact frame on Perfect, floating damage numbers for the attacker

	Visual only. The server decides every hit and every number.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local SpinConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("SpinConfig"))
local VFXQuality = __require("VFXQuality")
local SteelBallModel = __require("SteelBallModel")
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local ProceduralPose = __require("ProceduralPose")

local SpinVFX = {}

local localPlayer = Players.LocalPlayer
local colors = SpinConfig.Colors
local sounds = SpinConfig.Sounds

local chargeStates = {} -- [character] = state
local projectiles = {} -- [id] = visual
local ballPool = {}

---------------------------------------------------------------------------
-- Ball pool (projectile balls are reused instead of rebuilt every throw)
---------------------------------------------------------------------------
local function takeBall(scale)
	local ball = table.remove(ballPool)
	if not ball then
		ball = SteelBallModel.build(1, VFXQuality.get().Grooves)
		local core = ball.PrimaryPart
		core.Anchored = true
		-- Spiral trail: attachments rotate with the ball, so the ribbon twists.
		local trail = Instance.new("Trail")
		trail.Name = "SpiralTrail"
		trail.Attachment0 = core:FindFirstChild("TrailTop")
		trail.Attachment1 = core:FindFirstChild("TrailBottom")
		trail.Color = ColorSequence.new(colors.SpinLine, colors.SpinGlow)
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.Lifetime = 0.18
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		trail.FaceCamera = false
		trail.Parent = core
	end
	ball:ScaleTo(scale)
	return ball
end

local function returnBall(ball)
	ball.Parent = nil
	if #ballPool < 8 then
		table.insert(ballPool, ball)
	else
		ball:Destroy()
	end
end

VFXQuality.Changed:Connect(function()
	for _, ball in ipairs(ballPool) do
		ball:Destroy()
	end
	ballPool = {}
end)

---------------------------------------------------------------------------
-- Charge visuals
---------------------------------------------------------------------------
local function createCharge(character)
	local hand, grip = ProceduralPose.getHand(character)
	if not hand then
		return nil
	end
	local quality = VFXQuality.get()
	local ball = SteelBallModel.build(1, quality.Grooves)
	local core = ball.PrimaryPart
	core.Anchored = false
	ball:PivotTo(hand.CFrame * grip)
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = core
	weld.C0 = grip
	weld.Parent = core
	ball.Parent = VFXLib.Folder

	local rings = {}
	for i = 1, 3 do
		rings[i] = VFXLib.ring({
			Radius = 0.75 + i * 0.28,
			Width = 0.1,
			Color = colors.SpinLine,
			Transparency = 1,
		})
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Sparkle
	emitter.Color = ColorSequence.new(colors.SpinGlow, colors.GoldLight)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 6, 0)
	emitter.Rate = 0
	emitter.Parent = core:FindFirstChild("Center") or core

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = colors.Gold
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = character
	highlight.Parent = VFXLib.Folder

	ProceduralPose.play(character, "Charge", 0.18)

	return {
		Character = character,
		Ball = ball,
		Core = core,
		Weld = weld,
		Grip = grip,
		Rings = rings,
		Emitter = emitter,
		Highlight = highlight,
		Sound = VFXLib.sound(sounds.Charge, core, 0.45, 0.8, true),
		Angle = 0,
		Level = 0,
		InPerfect = false,
		NextDust = 0,
	}
end

local function destroyCharge(state, released)
	state.Ball:Destroy()
	for _, ring in ipairs(state.Rings) do
		ring:Destroy()
	end
	state.Highlight:Destroy()
	if state.Sound then
		state.Sound:Destroy()
	end
	if not released then
		ProceduralPose.reset(state.Character, 0.25)
	end
end

local function updateCharge(state, startTime, dt, now)
	local chargeTime = workspace:GetServerTimeNow() - startTime
	local level, perfect = SpinConfig.getLevel(chargeTime)
	local quality = VFXQuality.get()
	local core = state.Core

	-- Ball spin speeds up with each level.
	state.Angle = state.Angle + dt * (10 + level * 7)
	state.Weld.C0 = state.Grip * CFrame.Angles(state.Angle, state.Angle * 0.35, 0)

	-- Rings: one per level, each on its own tilted, precessing axis.
	local center = core.Position
	for i, ring in ipairs(state.Rings) do
		if i <= level then
			local tilt = 0.5 + i * 0.7
			ring:SetCFrame(CFrame.new(center) * CFrame.Angles(tilt + now * 0.8 * i, now * (3 + i), tilt * 0.5))
			ring:SetTransparency(perfect and 0 or 0.25)
			ring:SetWidth(perfect and 0.18 or 0.1)
			ring:SetColor(perfect and colors.Gold or colors.SpinLine)
		else
			ring:SetTransparency(1)
		end
	end

	state.Emitter.Rate = (perfect and 60 or level * 14) * quality.Particles
	if state.Sound then
		state.Sound.PlaybackSpeed = 0.8 + math.min(chargeTime, 2) * 0.3
	end

	-- Level up pulse.
	if level > state.Level then
		if state.Level > 0 then
			VFXLib.shockwave(CFrame.new(center), { Radius = 3 + level, Width = 0.2, Duration = 0.3, Color = colors.Gold })
			VFXLib.burst(center, { Count = 10 * level, Color = colors.GoldLight, Speed = 10, Lifetime = 0.4, Size = NumberSequence.new(0.25, 0) })
			VFXLib.sound(sounds.LevelUp, core, 0.5, 0.9 + level * 0.15)
		end
	end
	state.Level = level

	-- Perfect window: bright outline flash + chime.
	if perfect and not state.InPerfect then
		state.Highlight.OutlineTransparency = 0
		VFXLib.burst(center, { Count = 24, Color = colors.Perfect, Speed = 16, Lifetime = 0.35 })
		VFXLib.flash(center, colors.GoldLight, 5, 14, 0.25)
		VFXLib.sound(sounds.Perfect, core, 0.7, 1)
	elseif not perfect and state.InPerfect then
		state.Highlight.OutlineTransparency = 1
	end
	state.InPerfect = perfect

	-- Ground dust swirl at Power level and above.
	if level >= 2 and now >= state.NextDust then
		state.NextDust = now + 0.3
		local root = state.Character:FindFirstChild("HumanoidRootPart")
		if root then
			VFXLib.shockwave(CFrame.new(root.Position - Vector3.new(0, 2.8, 0)), {
				StartRadius = 1.5,
				Radius = 5 + level,
				Width = 0.25,
				Duration = 0.5,
				Color = colors.Gold,
				Spin = 2,
			})
		end
	end
end

local function chargeLoop(dt)
	local now = os.clock()
	local seen = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local startTime = character and character:GetAttribute("SpinChargeStart")
		if startTime then
			seen[character] = true
			local state = chargeStates[character]
			if not state then
				state = createCharge(character)
				chargeStates[character] = state
			end
			if state then
				updateCharge(state, startTime, dt, now)
			end
		end
	end
	for character, state in pairs(chargeStates) do
		if not seen[character] then
			chargeStates[character] = nil
			destroyCharge(state, state.Released)
		end
	end
end

---------------------------------------------------------------------------
-- Release / projectile / impact
---------------------------------------------------------------------------
local function ringAxisAlong(position, direction)
	-- Ring axis (UpVector) along the travel direction.
	return CFrame.lookAt(position, position + direction) * CFrame.Angles(math.pi / 2, 0, 0)
end

local function onRelease(data)
	local character = data.Character
	local state = character and chargeStates[character]
	if state then
		state.Released = true
	end
	if character then
		ProceduralPose.play(character, "Throw", 0.06)
		task.delay(0.3, function()
			ProceduralPose.reset(character, 0.3)
		end)
	end

	local level = SpinConfig.Levels[data.Level]
	local axis = ringAxisAlong(data.Origin, data.Direction)
	VFXLib.shockwave(axis, { Radius = 2 + data.Level * 1.5, Width = 0.35, Duration = 0.3, Color = colors.Gold })
	VFXLib.burst(data.Origin, {
		Count = 12 * data.Level,
		Color = colors.Gold,
		Speed = 25,
		Spread = 25,
		Direction = data.Direction,
		Lifetime = 0.35,
	})
	VFXLib.sound(sounds.Release, data.Origin, 0.7, 1.15 - data.Level * 0.1)

	if data.Perfect then
		for i = 1, 3 do
			task.delay(i * 0.04, function()
				VFXLib.shockwave(axis * CFrame.new(0, -i * 1.2, 0), {
					Radius = 3 + i * 1.5,
					Width = 0.3,
					Duration = 0.35,
					Color = colors.Perfect,
				})
			end)
		end
		VFXLib.flash(data.Origin, colors.GoldLight, 8, 24, 0.35)
	end

	if character and character == localPlayer.Character then
		CameraFX.shake(level.CameraShake * 0.6, 0.25)
		if data.Perfect then
			CameraFX.speedLines(0.35, colors.GoldLight)
			CameraFX.fovPunch(10, 0.4)
		else
			CameraFX.fovPunch(3 + data.Level * 2, 0.3)
		end
	end
end

local function spawnProjectile(data)
	local visualData = data.Visual or {}
	local levelIndex = visualData.Level or 1
	local level = SpinConfig.Levels[levelIndex]
	local perfect = visualData.Perfect == true

	local ball = takeBall(level.BallScale)
	local core = ball.PrimaryPart
	local start = CFrame.lookAt(data.Origin, data.Origin + data.Direction)
	ball:PivotTo(start)
	ball.Parent = VFXLib.Folder
	local spiral = core:FindFirstChild("SpiralTrail")
	if spiral then
		spiral:Clear()
	end

	-- Flat golden streak trail on a carrier that doesn't spin.
	local carrier = VFXLib.anchor(start)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-level.TrailWidth / 2, 0, 0)
	a0.Parent = carrier
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(level.TrailWidth / 2, 0, 0)
	a1.Parent = carrier
	local streak = Instance.new("Trail")
	streak.Attachment0 = a0
	streak.Attachment1 = a1
	streak.Color = ColorSequence.new(perfect and colors.Perfect or colors.GoldLight, colors.Gold)
	streak.LightEmission = 1
	streak.LightInfluence = 0
	streak.Lifetime = 0.25 + levelIndex * 0.08
	streak.WidthScale = NumberSequence.new(1, 0)
	streak.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	streak.FaceCamera = true
	streak.Parent = carrier

	local rings = {}
	for i = 1, level.Rings do
		rings[i] = VFXLib.ring({
			Radius = level.BallScale * 0.7 + i * 0.25,
			Width = 0.12 + (perfect and 0.06 or 0),
			Color = perfect and colors.Gold or colors.SpinLine,
		})
	end

	local visual = {
		Id = data.Id,
		Ball = ball,
		Core = core,
		Carrier = carrier,
		Streak = streak,
		Rings = rings,
		Origin = data.Origin,
		Direction = data.Direction,
		Speed = data.Speed,
		Range = data.Range,
		ServerTime = data.ServerTime,
		Level = levelIndex,
		Perfect = perfect,
		Spin = 0,
		NextGhost = 0,
		Expire = os.clock() + data.Range / data.Speed + 1.5,
	}
	projectiles[data.Id] = visual
end

local function removeProjectile(visual)
	projectiles[visual.Id] = nil
	returnBall(visual.Ball)
	for _, ring in ipairs(visual.Rings) do
		ring:Destroy()
	end
	visual.Streak.Enabled = false -- let the streak fade out on its own
	game:GetService("Debris"):AddItem(visual.Carrier, visual.Streak.Lifetime + 0.1)
end

local function projectileLoop(dt)
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for _, v in pairs(projectiles) do
		local distance = math.min(v.Speed * (serverNow - v.ServerTime), v.Range)
		local position = v.Origin + v.Direction * distance
		v.Spin = v.Spin + dt * (18 + v.Level * 6)
		local facing = CFrame.lookAt(position, position + v.Direction)
		v.Ball:PivotTo(facing * CFrame.Angles(-v.Spin, 0, v.Spin * 0.15))
		v.Carrier.CFrame = facing
		for i, ring in ipairs(v.Rings) do
			local tilt = 0.35 * i
			ring:SetCFrame(ringAxisAlong(position, v.Direction) * CFrame.Angles(tilt * math.sin(now * 6 + i), v.Spin * (0.4 + i * 0.2), tilt))
		end
		if now >= v.NextGhost then
			v.NextGhost = now + 0.05
			VFXLib.afterimage(v.Core.CFrame, SpinConfig.Levels[v.Level].BallScale, v.Perfect and colors.Perfect or colors.Gold)
		end
		if now > v.Expire then
			removeProjectile(v) -- safety: server end event never arrived
		end
	end
end

local function impact(position, normal, levelIndex, perfect, ownerIsLocal)
	local level = SpinConfig.Levels[levelIndex]
	local axis = CFrame.lookAt(position, position + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
	local color = perfect and colors.Perfect or colors.Gold

	for i = 1, levelIndex do
		task.delay((i - 1) * 0.05, function()
			VFXLib.shockwave(axis, {
				Radius = level.ShockwaveRadius * (1 - (i - 1) * 0.28),
				Width = 0.5 + levelIndex * 0.15,
				Duration = 0.4 + i * 0.05,
				Color = i == 1 and color or colors.Orange,
				Spin = 1.5 * i,
			})
		end)
	end
	if normal.Y > 0.5 then
		VFXLib.groundDisc(position, normal, { Radius = level.ShockwaveRadius * 0.6, Color = colors.Gold, Duration = 0.35 })
	end
	VFXLib.burst(position, { Count = 18 * levelIndex, Color = colors.GoldLight, Speed = 30, Lifetime = 0.5 })
	-- Metal sparks that fall with gravity.
	VFXLib.burst(position, {
		Count = 14 * levelIndex,
		Color = colors.Orange,
		Speed = 45,
		Lifetime = 0.6,
		Drag = 1,
		Acceleration = Vector3.new(0, -70, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) }),
		Direction = normal,
		Spread = 70,
	})
	-- Desert dust.
	VFXLib.burst(position, {
		Count = 6 * levelIndex,
		Texture = VFXLib.Textures.Smoke,
		Color = Color3.fromRGB(196, 168, 120),
		LightEmission = 0,
		Speed = 8,
		Lifetime = 1.1,
		Drag = 3,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) }),
		TransparencySeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
	})
	VFXLib.flash(position, colors.Gold, 3 + levelIndex * 2, 12 + levelIndex * 6, 0.35)
	VFXLib.sound(sounds.Impact, position, 0.6 + levelIndex * 0.15, 1.1 - levelIndex * 0.1)
	CameraFX.shakeAt(position, level.CameraShake * 2, 60 + levelIndex * 20)
	if perfect and ownerIsLocal then
		CameraFX.impactFrame(colors.GoldLight)
	end
end

local function endProjectile(data)
	local visual = projectiles[data.Id]
	local levelIndex = (data.Visual and data.Visual.Level) or (visual and visual.Level) or 1
	local perfect = data.Visual and data.Visual.Perfect == true
	if visual then
		visual.Ball:PivotTo(CFrame.new(data.Position))
		removeProjectile(visual)
	end
	-- Impact frame only for the thrower, and only when the ball hit someone.
	local ownerIsLocal = data.HitCharacter and data.OwnerId == localPlayer.UserId
	impact(data.Position, data.Normal, levelIndex, perfect, ownerIsLocal)
end

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

function SpinVFX.init()
	local FX = Net.get("SpinFX")
	FX.OnClientEvent:Connect(function(name, data)
		if name == "SpinRelease" then
			onRelease(data)
		elseif name == "ProjectileSpawn" and data.Kind == "SteelBall" then
			spawnProjectile(data)
		elseif name == "ProjectileEnd" and data.Kind == "SteelBall" then
			endProjectile(data)
		elseif name == "Hit" then
			onHit(data)
		elseif name == "Damage" then
			onDamage(data)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		chargeLoop(dt)
		projectileLoop(dt)
	end)
end

return SpinVFX
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
	if not VFXLib.acquire() then
		return
	end
	scale = scale or 1
	local cf = root.CFrame * CFrame.new(side * 0.4, 0.3, -2.4) * CFrame.Angles(0, 0, side * 0.5)
	local ring = VFXLib.ring({ CFrame = cf, Radius = 1.6 * scale, Width = 0.22 * scale, Color = color, Segments = 10, Transparency = 0.1 })
	VFXLib.animate(0.16, function(a)
		ring:SetCFrame(cf * CFrame.Angles(0, side * (-1.2 + a * 2.4), 0))
		ring:SetRadius((1.6 + a * 0.8) * scale)
		ring:SetTransparency(0.1 + a * 0.9)
	end, function()
		ring:Destroy()
		VFXLib.release()
	end)
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
	TuskAnimation.play(character, "M1_" .. index)
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
}

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
	Point = { RightArm = { 92, 0, 0 }, LeftArm = { 15, 0, -10 }, Waist = { 0, -18, 0 } },
	PointRecoil = { RightArm = { 110, 0, 0 }, Waist = { 6, -14, 0 } },
	Jab = { RightArm = { 88, 0, 12 }, Waist = { 0, -28, 0 }, LeftArm = { 30, 0, -20 } },
	JabLeft = { LeftArm = { 88, 0, -12 }, Waist = { 0, 28, 0 }, RightArm = { 30, 0, 20 } },
	SpinPoke = { RightArm = { 100, 25, 0 }, Waist = { -10, -24, 0 }, LeftArm = { 20, 0, -30 } },
	SlamWindup = { RightArm = { 165, 0, 10 }, LeftArm = { 40, 0, -30 }, Waist = { 12, 15, 0 } },
	Slam = { RightArm = { 55, 0, 0 }, LeftArm = { 20, 0, -20 }, Waist = { -22, -10, 0 } },
	ChargeNail = { RightArm = { 75, 0, 28 }, LeftArm = { 75, 0, -28 }, Waist = { -8, 0, 0 } },
	BarrageA = { RightArm = { 95, 4, 0 }, LeftArm = { 60, 0, -20 }, Waist = { 0, -14, 0 } },
	BarrageB = { RightArm = { 88, -4, 0 }, LeftArm = { 60, 0, -20 }, Waist = { 0, -18, 0 } },
	AwakenCrouch = { RightArm = { 30, 0, 40 }, LeftArm = { 30, 0, -40 }, Waist = { -25, 0, 0 }, Neck = { -15, 0, 0 } },
	AwakenRise = { RightArm = { 130, 0, 35 }, LeftArm = { 130, 0, -35 }, Waist = { 14, 0, 0 }, Neck = { 22, 0, 0 } },
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
}

--[[
	Action sequences: list of keyframes { Time, Pose, (optional) Ease }.
	The last keyframe's Time is the length; after it the joints blend back.
]]
TuskAnimation.Actions = {
	M1_1 = { { 0, "Rest" }, { 0.07, "Jab" }, { 0.22, "Jab" } },
	M1_2 = { { 0, "Rest" }, { 0.07, "JabLeft" }, { 0.22, "JabLeft" } },
	M1_3 = { { 0, "Rest" }, { 0.08, "SpinPoke" }, { 0.25, "SpinPoke" } },
	M1_4 = { { 0, "Rest" }, { 0.12, "SlamWindup" }, { 0.2, "Slam" }, { 0.5, "Slam" } },
	NailShot = { { 0, "Rest" }, { 0.12, "Point" }, { 0.2, "PointRecoil" }, { 0.45, "Point" } },
	NailBarrage = {
		{ 0, "Rest" }, { 0.12, "BarrageA" }, { 0.21, "BarrageB" }, { 0.3, "BarrageA" },
		{ 0.39, "BarrageB" }, { 0.48, "BarrageA" }, { 0.57, "BarrageB" }, { 0.8, "BarrageB" },
	},
	SpinningNailRelease = { { 0, "ChargeNail" }, { 0.06, "PointRecoil" }, { 0.4, "Point" } },
	Awakening = { { 0, "Rest" }, { 0.35, "AwakenCrouch" }, { 1.2, "AwakenCrouch" }, { 1.45, "AwakenRise" }, { 2.2, "AwakenRise" } },
	Emerge = { { 0, "Sneak" }, { 0.12, "Emerge" }, { 0.5, "Emerge" } },
}

local states = setmetatable({}, { __mode = "k" }) -- character -> { Hold, ActionJob, Tracks }

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
	for name, path in pairs(JOINTS[rig]) do
		local holder = character:FindFirstChild(path[1])
		local motor = holder and holder:FindFirstChild(path[2])
		if motor and motor:IsA("Motor6D") then
			motors[name] = motor
		end
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
		from[name] = motor.C0
		to[name] = poseC0(motor, pose[name])
	end
	return VFXLib.animate(duration, function(a)
		local e = VFXLib.easeOut(a)
		for name, motor in pairs(motors) do
			if motor.Parent then
				motor.C0 = from[name]:Lerp(to[name], e)
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
				c0s[jointName] = motor.C0
			else
				c0s[jointName] = poseC0(motor, pose[jointName] or holdPose[jointName])
			end
		end
		keys[i] = { Time = frame[1], C0 = c0s }
	end
	local job
	job = VFXLib.animate(length, function(a)
		local t = a * length
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
				motor.C0 = current.C0[jointName]:Lerp(nextKey.C0[jointName], e)
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

	for act in pairs(Registry.Acts) do
		if __hasModule("Act" .. act) then
			actVFX[act] = __require("Act" .. act)
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

	RunService.RenderStepped:Connect(function()
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
				m.step()
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
	}
	if style == "M1" then
		s.Scale = 0.75
		s.Helix = 1
		s.ImpactSize = 0.6
	elseif style == "Barrage" then
		s.Scale = 0.8
		s.Helix = 1
		s.ImpactSize = 0.6
	elseif style == "Spinning" then
		s.Scale = 1 + charge * 0.7
		s.Rings = 1 + math.floor(charge * 2 + 0.01)
		s.SpinSpeed = 40 + charge * 30
		s.ImpactSize = 1 + charge * 1.2
		s.ImpactLayers = 2 + math.floor(charge + 0.01)
		s.Afterimages = charge > 0.5
		if charge >= 1 then
			-- Full charge: golden-blue identity.
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

function TuskStand.init()
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

	Using your own model instead: put a Model named "TuskAct1" (PrimaryPart
	set) in ReplicatedStorage.SpinShared.Assets. It is cloned and resized,
	and gets the same idle motion (ears and legs only animate on the
	built-in model).
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

local function override(act, scale)
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
	local custom = assets and assets:FindFirstChild("TuskAct" .. act)
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		local clone = custom:Clone()
		local size = clone:GetExtentsSize()
		local largest = math.max(size.X, size.Y, size.Z)
		if largest > 0 then
			clone:ScaleTo(clone:GetScale() * (2.4 * scale) / largest)
		end
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
				d.Anchored = d == clone.PrimaryPart
			end
		end
		local point = Instance.new("Attachment")
		point.Name = "NailPoint"
		point.Position = Vector3.new(0, 0, -size.Z * 0.5)
		point.Parent = clone.PrimaryPart
		return clone, { Body = clone.PrimaryPart, Joints = {}, NailPoint = point }
	end
	return nil
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

local function buildAct1(scale)
	local s = scale
	local model = Instance.new("Model")
	model.Name = "TuskAct1"

	local body = part(model, {
		Name = "Body",
		Size = Vector3.new(1.35, 1.8, 1.25) * s,
		Color = colors.Pink,
		Ellipsoid = true,
		Massless = false,
	})
	body.CFrame = CFrame.new()
	body.Anchored = true
	model.PrimaryPart = body

	local rig = { Body = body, Joints = {} }

	-- Shading belly (darker lower half reads as volume from a distance).
	local belly = part(model, { Name = "Belly", Size = Vector3.new(1.2, 1.1, 1.15) * s, Color = colors.PinkDark, Ellipsoid = true })
	attach(body, belly, CFrame.new(0, -0.35 * s, 0.04 * s))

	-- Eyes: white balls, black pupils, heavy tilted brows (grumpy look).
	for _, side in ipairs({ -1, 1 }) do
		local eye = part(model, { Name = "Eye", Size = Vector3.new(0.32, 0.32, 0.22) * s, Color = Color3.new(1, 1, 1), Ellipsoid = true })
		attach(body, eye, CFrame.new(side * 0.26 * s, 0.12 * s, -0.55 * s))
		local pupil = part(model, { Name = "Pupil", Size = Vector3.new(0.13, 0.13, 0.06) * s, Color = Color3.fromRGB(20, 10, 20), Ellipsoid = true })
		attach(body, pupil, CFrame.new(side * 0.25 * s, 0.1 * s, -0.66 * s))
		local brow = part(model, { Name = "Brow", Size = Vector3.new(0.4, 0.1, 0.12) * s, Color = colors.PinkDark })
		attach(body, brow, CFrame.new(side * 0.26 * s, 0.3 * s, -0.58 * s) * CFrame.Angles(0, 0, side * -0.35))
	end

	-- Beak: elongated yellow ellipsoid pointing forward and down.
	local beak = part(model, { Name = "Beak", Size = Vector3.new(0.2, 0.2, 0.55) * s, Color = colors.Star, Ellipsoid = true })
	attach(body, beak, CFrame.new(0.05 * s, -0.12 * s, -0.75 * s) * CFrame.Angles(-0.55, 0.15, 0))

	-- Forehead star and the gold pin running from it to the beak.
	local starCenter = Vector3.new(-0.18 * s, 0.62 * s, -0.42 * s)
	star(model, body, starCenter, Vector3.new(-0.2, 0.55, -0.8).Unit, 0.5 * s, colors.Star)
	local beakTip = Vector3.new(0.12 * s, -0.32 * s, -0.95 * s)
	local pinLength = (beakTip - starCenter).Magnitude
	local pin = part(model, {
		Name = "Pin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(pinLength, 0.035 * s, 0.035 * s),
		Color = colors.Gold,
		Material = Enum.Material.Metal,
		Reflectance = 0.3,
	})
	-- Cylinder axis is X: build a frame whose RightVector runs star -> beak.
	local mid = (starCenter + beakTip) / 2
	attach(body, pin, CFrame.lookAt(mid, beakTip) * CFrame.Angles(0, math.pi / 2, 0))

	-- Small gold stars scattered over the body.
	local starSpots = {
		Vector3.new(0.55, 0.45, -0.2), Vector3.new(0.6, -0.1, 0.1), Vector3.new(-0.6, 0.0, 0.15),
		Vector3.new(-0.45, -0.55, -0.3), Vector3.new(0.35, -0.6, -0.4), Vector3.new(0.1, 0.75, 0.35),
		Vector3.new(-0.3, 0.4, 0.55), Vector3.new(0.4, 0.1, 0.55), Vector3.new(0.0, -0.75, 0.3),
	}
	for _, spot in ipairs(starSpots) do
		local n = Vector3.new(spot.X / 0.675, spot.Y / 0.9, spot.Z / 0.625).Unit
		local surface = Vector3.new(n.X * 0.675, n.Y * 0.9, n.Z * 0.625) * s * 1.01
		star(model, body, surface, n, 0.22 * s, colors.Star)
	end

	-- Floppy ears (animated).
	local ears = {
		{ Name = "EarL", Base = CFrame.new(-0.45 * s, 0.75 * s, 0) * CFrame.Angles(0, 0, 0.9), Size = Vector3.new(0.38, 1.25, 0.12) },
		{ Name = "EarR", Base = CFrame.new(0.5 * s, 0.65 * s, 0.05 * s) * CFrame.Angles(0.2, 0, -1.35), Size = Vector3.new(0.34, 1.1, 0.12) },
	}
	for _, e in ipairs(ears) do
		local ear = part(model, { Name = e.Name, Size = e.Size * s, Color = colors.Pink, Ellipsoid = true })
		local inner = part(model, { Name = e.Name .. "Inner", Size = e.Size * s * Vector3.new(0.55, 0.75, 0.5), Color = colors.PinkDark, Ellipsoid = true })
		local offset = CFrame.new(0, e.Size.Y * s * 0.45, 0)
		local w = attach(body, ear, e.Base * offset)
		attach(ear, inner, CFrame.new(0, 0, -0.03 * s))
		rig.Joints[e.Name] = { Weld = w, Base = e.Base, Offset = offset }
	end

	-- Little fin spikes around the silhouette.
	local fins = {
		CFrame.new(-0.62 * s, 0.25 * s, 0) * CFrame.Angles(0, 0, 1.2),
		CFrame.new(0.66 * s, 0.2 * s, -0.1 * s) * CFrame.Angles(0, 0, -1.3),
		CFrame.new(-0.55 * s, -0.4 * s, 0) * CFrame.Angles(0, 0, 2.0),
		CFrame.new(0.58 * s, -0.45 * s, 0) * CFrame.Angles(0, 0, -2.1),
	}
	for _, cf in ipairs(fins) do
		local fin = part(model, { Name = "Fin", Size = Vector3.new(0.16, 0.42, 0.08) * s, Color = colors.Pink, Ellipsoid = true })
		attach(body, fin, cf * CFrame.new(0, 0.18 * s, 0))
	end

	-- Four thin legs ending in hearts (animated swing).
	for i = 1, 4 do
		local x = (-1.5 + (i - 1)) * 0.22 * s
		local base = CFrame.new(x, -0.78 * s, (i % 2 == 0 and 0.12 or -0.1) * s)
		local legLength = (0.55 + (i % 2) * 0.12) * s
		local leg = part(model, {
			Name = "Leg" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(legLength, 0.05 * s, 0.05 * s),
			Color = colors.Pink,
		})
		-- Cylinder axis is X; rotate so it hangs down from the joint.
		local offset = CFrame.new(0, -legLength / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local w = attach(body, leg, base * offset)
		rig.Joints["Leg" .. i] = { Weld = w, Base = base, Offset = offset }

		-- Heart foot: two lobes and a point, attached to the leg's bottom end.
		local footCF = CFrame.new(-legLength / 2 - 0.12 * s, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2)
		for _, side in ipairs({ -1, 1 }) do
			local lobe = part(model, { Name = "HeartLobe", Size = Vector3.new(0.2, 0.2, 0.1) * s, Color = colors.Heart, Ellipsoid = true })
			attach(leg, lobe, footCF * CFrame.new(side * 0.075 * s, 0.03 * s, 0))
		end
		local point = part(model, { Name = "HeartPoint", Size = Vector3.new(0.2, 0.2, 0.1) * s, Color = colors.Heart, Ellipsoid = true })
		attach(leg, point, footCF * CFrame.new(0, -0.08 * s, 0) * CFrame.Angles(0, 0, math.pi / 4))
	end

	local nailPoint = Instance.new("Attachment")
	nailPoint.Name = "NailPoint"
	nailPoint.Position = Vector3.new(0, -0.1 * s, -0.9 * s)
	nailPoint.Parent = body
	rig.NailPoint = nailPoint

	return model, rig
end

---------------------------------------------------------------------------
-- ACT 2: Act 1 grown up. Bigger, magenta, a crest of spikes, two small arms.
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
	local s = scale * 1.25
	local model, rig = buildAct1(s)
	model.Name = "TuskAct2"
	-- (Color3 values can't be table keys, so compare directly.)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Color == colors.Pink then
				d.Color = Color3.fromRGB(214, 84, 196)
			elseif d.Color == colors.PinkDark then
				d.Color = Color3.fromRGB(118, 40, 150)
			end
		end
	end
	local body = rig.Body
	-- Crest of three spikes.
	for i = -1, 1 do
		local spike = part(model, { Name = "Crest", Size = Vector3.new(0.14, 0.7 - math.abs(i) * 0.2, 0.3) * s, Color = Color3.fromRGB(240, 200, 255), Ellipsoid = true })
		attach(body, spike, CFrame.new(i * 0.22 * s, 0.95 * s, 0.1 * s) * CFrame.Angles(0, 0, -i * 0.4))
	end
	-- Glowing chest star.
	local core = part(model, { Name = "Core", Size = Vector3.new(0.3, 0.3, 0.08) * s, Color = colors.Cyan, Material = Enum.Material.Neon, Ellipsoid = true })
	attach(body, core, CFrame.new(0, -0.35 * s, -0.62 * s))
	-- Arms.
	limb(model, body, rig, "ArmL", CFrame.new(-0.62 * s, -0.05 * s, -0.1 * s) * CFrame.Angles(0, 0, -0.5), 0.6 * s, 0.13 * s, Color3.fromRGB(214, 84, 196), colors.Star)
	local _, hand = limb(model, body, rig, "ArmR", CFrame.new(0.62 * s, -0.05 * s, -0.1 * s) * CFrame.Angles(0, 0, 0.5), 0.6 * s, 0.13 * s, Color3.fromRGB(214, 84, 196), colors.Star)
	rig.NailPoint.Parent = hand
	rig.NailPoint.Position = Vector3.new()
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

local function buildAct3(scale)
	return buildHumanoid("TuskAct3", scale, {
		Torso = Vector3.new(1.3, 1.7, 0.9),
		Head = Vector3.new(0.95, 1.05, 0.95),
		Body = Color3.fromRGB(196, 96, 190),
		HeadColor = Color3.fromRGB(236, 170, 220),
		Trim = Color3.fromRGB(40, 50, 130),
		Star = colors.Star,
		Eye = Color3.fromRGB(120, 200, 255),
		ArmLength = 1.1,
		ArmThickness = 0.2,
		Legs = false,
	})
end

local function buildAct4(scale)
	return buildHumanoid("TuskAct4", scale * 1.15, {
		Torso = Vector3.new(1.8, 2.1, 1.1),
		Head = Vector3.new(1, 1.1, 1),
		Body = Color3.fromRGB(70, 56, 150),
		HeadColor = Color3.fromRGB(200, 120, 210),
		Trim = colors.Gold,
		TrimMaterial = Enum.Material.Metal,
		Star = colors.GoldLight,
		Eye = Color3.fromRGB(110, 230, 255),
		ArmLength = 1.4,
		ArmThickness = 0.3,
		Legs = true,
		LegLength = 1.6,
	})
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
	("TuskUIController" in the design doc)

	JoJo-style Tusk HUD (only visible while Tusk is equipped):
	  * Act name + tagline
	  * three ability slots: key, name, cooldown sweep (tap/click = use; mobile-friendly)
	  * ultimate meter + "READY" prompt (tap/click = use)
	  * sneak chip (tap = toggle) + sneak attack hint
	  * combo counter, transformation banner, Awakened timer, short toasts
	Act menu (T / MOVESET button): one card per Act. Unfinished Acts are shown
	locked as IN DEVELOPMENT, never as working buttons.
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
local FONT = Enum.Font.GothamBlack
local TITLE_FONT = Enum.Font.Bangers

local callbacks
local gui, hud, actLabel, taglineLabel, ultFill, ultLabel, sneakChip, sneakHint, comboLabel, toastLabel, banner, bannerSub, awakenBar, awakenFill
local slots = {}
local menu
local shownAct
local combo = { Count = 0, Last = 0 }
local jobs = {}

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
end

local function stroke(p, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
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
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return ""
	end
	if string.find(last.Name, "Gamepad") then
		return keys.Gamepad.Name:gsub("Button", "")
	end
	local k = keys.Keyboard
	local names = { One = "1", Two = "2", Three = "3" }
	return names[k.Name] or k.Name
end

local function animateJob(key, duration, step, done)
	VFXLib.cancel(jobs[key])
	jobs[key] = VFXLib.animate(duration, step, done)
end

function TuskUI.toast(message, color)
	toastLabel.Text = message
	toastLabel.TextColor3 = color or Color3.fromRGB(255, 140, 120)
	animateJob("toast", 1.2, function(a)
		toastLabel.TextTransparency = a < 0.7 and 0 or (a - 0.7) / 0.3
		toastLabel.TextStrokeTransparency = math.max(0.4, toastLabel.TextTransparency)
	end)
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function buildSlot(index, parent)
	local button = Instance.new("TextButton")
	button.Name = "Slot" .. index
	button.Size = UDim2.new(1 / 3, -6, 1, 0)
	button.BackgroundColor3 = DARK
	button.BackgroundTransparency = 0.15
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = parent
	corner(button, 8)
	local edge = stroke(button, colors.Cyan, 2)

	local key = text(button, { Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(30, 16), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = colors.Cyan })
	local name = text(button, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -8, 0, 28), TextSize = 13, TextWrapped = true, Text = "" })
	local overlay = Instance.new("Frame")
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.AnchorPoint = Vector2.new(0, 1)
	overlay.Position = UDim2.fromScale(0, 1)
	overlay.Size = UDim2.fromScale(1, 0)
	overlay.ZIndex = 2
	overlay.Parent = button
	corner(overlay, 8)
	local timer = text(button, { Size = UDim2.fromScale(1, 1), TextSize = 22, Text = "", ZIndex = 3 })

	-- Press / release (works for mouse and touch; hold abilities charge while held).
	button.MouseButton1Down:Connect(function()
		callbacks.Ability(index, true)
	end)
	button.MouseButton1Up:Connect(function()
		callbacks.Ability(index, false)
	end)

	slots[index] = { Button = button, Key = key, Name = name, Overlay = overlay, Timer = timer, Edge = edge }
end

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

function TuskUI.init(cb)
	callbacks = cb
	gui = Instance.new("ScreenGui")
	gui.Name = "TuskHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	hud = Instance.new("Frame")
	hud.Name = "HUD"
	hud.AnchorPoint = Vector2.new(0.5, 1)
	hud.Position = UDim2.new(0.5, 0, 1, -92) -- sits above the Golden Spin panel
	hud.Size = UDim2.new(0.92, 0, 0, 150)
	hud.BackgroundTransparency = 1
	hud.Visible = false
	hud.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 150)
	limit.Parent = hud

	actLabel = text(hud, { Size = UDim2.new(1, 0, 0, 30), Font = TITLE_FONT, TextSize = 30, TextColor3 = colors.Cyan, TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
	taglineLabel = text(hud, { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextColor3 = Color3.fromRGB(170, 200, 230), TextXAlignment = Enum.TextXAlignment.Left, Text = "" })

	local slotRow = Instance.new("Frame")
	slotRow.Position = UDim2.fromOffset(0, 46)
	slotRow.Size = UDim2.new(1, 0, 0, 62)
	slotRow.BackgroundTransparency = 1
	slotRow.Parent = hud
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 9)
	layout.Parent = slotRow
	for i = 1, 3 do
		buildSlot(i, slotRow)
	end

	-- Ultimate bar (also a button).
	local ult = Instance.new("TextButton")
	ult.Name = "Ultimate"
	ult.Position = UDim2.fromOffset(0, 114)
	ult.Size = UDim2.new(1, -96, 0, 26)
	ult.BackgroundColor3 = DARK
	ult.BackgroundTransparency = 0.15
	ult.AutoButtonColor = false
	ult.Text = ""
	ult.Parent = hud
	corner(ult, 8)
	stroke(ult, colors.Blue, 2)
	ultFill = Instance.new("Frame")
	ultFill.BorderSizePixel = 0
	ultFill.BackgroundColor3 = colors.Blue
	ultFill.Size = UDim2.fromScale(0, 1)
	ultFill.Parent = ult
	corner(ultFill, 8)
	ultLabel = text(ult, { Size = UDim2.fromScale(1, 1), TextSize = 13, Text = "", ZIndex = 2 })
	ult.Activated:Connect(function()
		callbacks.Ultimate()
	end)

	-- Sneak chip (also a button).
	sneakChip = Instance.new("TextButton")
	sneakChip.Name = "Sneak"
	sneakChip.AnchorPoint = Vector2.new(1, 0)
	sneakChip.Position = UDim2.new(1, 0, 0, 114)
	sneakChip.Size = UDim2.fromOffset(88, 26)
	sneakChip.BackgroundColor3 = DARK
	sneakChip.BackgroundTransparency = 0.15
	sneakChip.Font = FONT
	sneakChip.TextSize = 13
	sneakChip.TextColor3 = Color3.fromRGB(150, 170, 200)
	sneakChip.Text = "SNEAK"
	sneakChip.Parent = hud
	corner(sneakChip, 8)
	stroke(sneakChip, Color3.fromRGB(60, 80, 120), 2)
	sneakChip.Activated:Connect(function()
		callbacks.Sneak()
	end)
	sneakHint = text(hud, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(200, 18), TextSize = 12, TextColor3 = colors.Cyan, TextXAlignment = Enum.TextXAlignment.Right, Text = "", Visible = false })

	-- Combo counter (right side of the screen).
	comboLabel = text(gui, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.42, 0), Size = UDim2.fromOffset(220, 60), Font = TITLE_FONT, TextSize = 48, TextColor3 = colors.Ice, TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })

	toastLabel = text(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -250), Size = UDim2.fromOffset(400, 26), TextSize = 18, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })

	-- Transformation banner.
	banner = text(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromOffset(700, 80), Font = TITLE_FONT, TextSize = 72, TextColor3 = colors.Cyan, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })
	bannerSub = text(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromOffset(500, 24), TextSize = 16, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })
	bannerSub.Position = UDim2.new(0.5, 0, 0.25, 48)

	awakenBar = Instance.new("Frame")
	awakenBar.AnchorPoint = Vector2.new(0.5, 1)
	awakenBar.Position = UDim2.new(0.5, 0, 1, -248)
	awakenBar.Size = UDim2.fromOffset(240, 6)
	awakenBar.BackgroundColor3 = DARK
	awakenBar.Visible = false
	awakenBar.Parent = gui
	corner(awakenBar, 3)
	awakenFill = Instance.new("Frame")
	awakenFill.BorderSizePixel = 0
	awakenFill.BackgroundColor3 = colors.Cyan
	awakenFill.Size = UDim2.fromScale(1, 1)
	awakenFill.Parent = awakenBar
	corner(awakenFill, 3)

	-- MOVESET button (opens the Act menu), under the VFX quality button.
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

	-- Combo counter feeds on the attacker-only Damage event.
	Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
		if name ~= "Damage" or not hud.Visible then
			return
		end
		local now = os.clock()
		combo.Count = (now - combo.Last < 1.6) and combo.Count + 1 or 1
		combo.Last = now
		if combo.Count >= 2 then
			comboLabel.Text = combo.Count .. " HITS"
			animateJob("combo", 1.6, function(a)
				comboLabel.TextTransparency = a < 0.75 and 0 or (a - 0.75) / 0.25
				comboLabel.TextStrokeTransparency = math.max(0.3, comboLabel.TextTransparency)
				comboLabel.Rotation = a < 0.08 and (0.08 - a) * 60 or 0
			end)
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

local function showBanner(title, subtitle, color)
	banner.Text = title
	banner.TextColor3 = color or colors.Cyan
	bannerSub.Text = subtitle or ""
	animateJob("banner", 2, function(a)
		local slide = a < 0.12 and (1 - a / 0.12) or 0
		banner.Position = UDim2.new(0.5, slide * 200, 0.25, 0)
		local fade = a < 0.75 and 0 or (a - 0.75) / 0.25
		banner.TextTransparency = fade
		banner.TextStrokeTransparency = math.max(0.2, fade)
		bannerSub.TextTransparency = fade
		bannerSub.TextStrokeTransparency = math.max(0.4, fade)
	end)
end

-- Ultimate awakened Tusk to the next Act.
function TuskUI.onEvolve(data)
	if data.Character ~= player.Character then
		return
	end
	local info = Registry.get(data.To)
	if info then
		showBanner(info.Name .. "!", "AWAKENED  ·  " .. info.Tagline:upper(), info.Theme.Primary)
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
local function refreshAct(act)
	shownAct = act
	hud.Visible = act ~= nil
	if not act then
		return
	end
	local info = Registry.get(act)
	actLabel.Text = info.Name
	actLabel.TextColor3 = info.Theme.Primary
	taglineLabel.Text = info.Tagline:upper()
	for i, slot in ipairs(slots) do
		slot.Name.Text = info.Abilities[i]
		slot.Edge.Color = info.Theme.Primary
	end
end

function TuskUI.step(act)
	if act ~= shownAct then
		refreshAct(act)
	end
	if not act then
		return
	end
	for i, slot in ipairs(slots) do
		slot.Key.Text = keyName("Ability" .. i)
	end
	local max = TuskConfig.Ultimate.MaxMeter
	local meter = player:GetAttribute("TuskUlt") or 0
	local ready = meter >= max
	ultFill.Size = UDim2.fromScale(math.clamp(meter / max, 0, 1), 1)
	local info = Registry.get(act)
	local key = keyName("Ultimate")
	if ready then
		local pulse = (math.sin(os.clock() * 6) + 1) / 2
		ultFill.BackgroundColor3 = colors.Blue:Lerp(colors.Cyan, pulse)
		ultLabel.Text = (key ~= "" and ("[" .. key .. "] ") or "") .. info.Ultimate .. " READY"
	else
		ultFill.BackgroundColor3 = colors.Blue
		ultLabel.Text = info.Ultimate .. "  " .. math.floor(meter / max * 100) .. "%"
	end
	local character = player.Character
	local sneaking = character and character:GetAttribute("TuskSneaking") == true
	sneakChip.TextColor3 = sneaking and DARK or Color3.fromRGB(150, 170, 200)
	sneakChip.BackgroundColor3 = sneaking and colors.Cyan or DARK
	sneakHint.Visible = sneaking
	sneakHint.Text = "M1 / TAP: SNEAK ATTACK"
end

local function cooldown(slot, duration)
	local s = slots[slot]
	if not s then
		return
	end
	animateJob("slot" .. slot, duration, function(a)
		s.Overlay.Size = UDim2.fromScale(1, 1 - a)
		s.Timer.Text = string.format("%.1f", duration * (1 - a))
	end, function()
		s.Overlay.Size = UDim2.fromScale(1, 0)
		s.Timer.Text = ""
		-- Ready flash.
		VFXLib.animate(0.25, function(a)
			s.Button.BackgroundColor3 = colors.Cyan:Lerp(DARK, a)
		end)
	end)
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
}

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
	elseif kind == "Interrupted" then
		TuskUI.toast("INTERRUPTED!")
	elseif kind == "SneakAttackCooldown" then
		sneakChip.Text = "SNEAK"
	elseif kind == "Awakened" then
		local info = shownAct and Registry.get(shownAct)
		banner.Text = info and info.Ultimate or "AWAKENED"
		bannerSub.Text = "ABILITIES EMPOWERED"
		animateJob("banner", 1.8, function(a)
			local slide = a < 0.12 and (1 - a / 0.12) or 0
			banner.Position = UDim2.new(0.5, slide * 200, 0.25, 0)
			local fade = a < 0.75 and 0 or (a - 0.75) / 0.25
			banner.TextTransparency = fade
			banner.TextStrokeTransparency = math.max(0.2, fade)
			bannerSub.TextTransparency = fade
			bannerSub.TextStrokeTransparency = math.max(0.4, fade)
		end)
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
			TuskUI.toast(Registry.get(data.Act).Name .. " EQUIPPED", colors.Cyan)
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

--[[
	opts: Scale, Color, Color2 (helix), TrailColor, Rings (0..3), RingColor,
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

	local visual = { Spin = 0, NextGhost = 0, Alive = true }
	function visual:Step(cframe, dt)
		self.Spin = self.Spin + (dt or 0) * (opts.SpinSpeed or 30)
		nail:PivotTo(cframe * CFrame.Angles(0, 0, self.Spin))
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
__require("SpinMeter").init()
__require("SpinVFX").init()
__require("SpinController").init()
__require("TuskStand").init()
__require("TuskProjectiles").init()
__require("TuskSneakController").init()
__require("TuskController").init()
__require("WorldClient").init()
__require("CharacterCard").init()
