--[[
	TuskActVFX.Act1  (StarterPlayerScripts.SpinClient.TuskActVFX.Act1)

	Client choreography for Tusk Act 1: poses, Stand motion, effects and
	sounds for each server event. Visual only.

	Every major move follows: startup -> anticipation -> impact frame ->
	primary shockwave -> secondary particles -> recovery.
]]

local Players = game:GetService("Players")
local Fighters = require(script.Parent.Parent.Fighters)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local VFXQuality = require(Shared.VFXQuality)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local TuskStand = require(script.Parent.Parent.TuskStand)
local Common = require(script.Parent.Parent.TuskActCommon)

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
