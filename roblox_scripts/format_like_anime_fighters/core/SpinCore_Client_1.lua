--[[
	SpinCore_Client_1  (ModuleScript)  -- part 1 of 8
	PUT IT IN: ReplicatedStorage > SpinCore   (make a Folder named SpinCore there if it doesn't exist)

	Part of the Spin Battlegrounds client core, split up so pasting is quick.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

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
		-- A small golden rectangle opens at the fingertip; the nail is fired through it.
		local tip = (root.CFrame * CFrame.new(0.9, 0.55, -2.2)).Position
		Common.golden(tip, tip + data.Direction * 5, 1, data.Startup + 0.2, pal)
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
end
