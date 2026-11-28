--[[
	JohnnyArmCutscene  (StarterPlayerScripts.SpinClient.JohnnyArmCutscene)

	TUSK ACT 1: FIRST APPEARANCE. When YOU, playing Johnny, pick up the
	Saint's Corpse LEFT ARM, a cutscene follows the user's anime clip
	(about 12 s, skippable; TuskConfig.Cutscenes.JohnnyArm):
	  1. looking down at Johnny's left hand: the corpse's withered arm sinks
	     into his own in a golden glow, light streaks up out of his palm, and
	     Tusk rises out of it, looking up at us (dark, with a green haze)
	  2. Tusk hovering in front of him, wobbling, a burst of teal light
	     behind it
	  3. over Tusk's shoulder (its back), at Johnny's face: his eyes wide
	  4. close, from the side: Tusk right by his face, Johnny sweating,
	     mouth open in shock
	  5. Tusk's face close up in a pink haze: "TUSK ACT 1 · FIRST APPEARANCE"
	Everything it adds is local to you and removed when it ends or is
	skipped. It won't replay within 20 s.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)
local CameraFX = require(script.Parent.CameraFX)
local TuskStand = require(script.Parent.TuskStand)
local Cutscenes = require(script.Parent.Cutscenes)

local JohnnyArmCutscene = {}
local player = Players.LocalPlayer
local last -- os.clock() of the last one (nil: never)

local GOLD = Color3.fromRGB(255, 214, 110)
local TEAL = Color3.fromRGB(80, 230, 210)
local PINK = Color3.fromRGB(255, 150, 210)
local WITHERED = Color3.fromRGB(150, 120, 96)
local WITHERED_DARK = Color3.fromRGB(110, 86, 68)

local function newPart(holder, name, size, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = holder
	return p
end

local function weldOn(parent, holder, name, size, color, cf, material, ellipse)
	local p = newPart(holder, name, size, color, material)
	p.Anchored = false
	p.Massless = true
	if ellipse then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	p.CFrame = parent.CFrame * cf
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent
	w.Part1 = p
	w.Parent = p
	return p
end

-- The corpse's withered left arm sinking into his own, in a golden glow.
local function armSinks(character, time)
	local arm = character:FindFirstChild("LeftLowerArm") or character:FindFirstChild("Left Arm")
	local hand = character:FindFirstChild("LeftHand") or arm
	if not arm then
		return nil
	end
	local holder = Instance.new("Model")
	holder.Name = "SaintsArm"
	local pieces = {
		newPart(holder, "Forearm", Vector3.new(0.5, 1.3, 0.45), WITHERED),
		newPart(holder, "Wrist", Vector3.new(0.4, 0.2, 0.36), WITHERED_DARK),
		newPart(holder, "Palm", Vector3.new(0.5, 0.45, 0.2), WITHERED),
	}
	for k = 1, 4 do
		pieces[#pieces + 1] = newPart(holder, "Finger", Vector3.new(0.08, 0.36, 0.08), WITHERED_DARK)
	end
	local glow = newPart(holder, "Glow", arm.Size + Vector3.new(0.3, 0.3, 0.3), GOLD, Enum.Material.Neon, 1)
	holder.Parent = VFXLib.Folder
	VFXLib.animate(time, function(a)
		if not arm.Parent then
			return
		end
		-- Lying along his forearm, sinking in.
		local sink = math.clamp((a - 0.15) / 0.75, 0, 1)
		local base = arm.CFrame * CFrame.new(-0.55 * (1 - sink), 0, 0)
		pieces[1].CFrame = base
		pieces[2].CFrame = base * CFrame.new(0, -0.72, 0)
		pieces[3].CFrame = base * CFrame.new(0, -0.95, 0)
		for k = 1, 4 do
			pieces[3 + k].CFrame = base * CFrame.new((k - 2.5) * 0.11, -1.3, 0)
		end
		for _, p in ipairs(pieces) do
			p.Transparency = math.clamp(sink * 1.15, 0, 1)
		end
		glow.CFrame = arm.CFrame
		glow.Transparency = 1 - 0.6 * math.sin(math.clamp(a, 0, 1) * math.pi)
		if math.random() < 0.4 then
			VFXLib.burst(arm.Position + Vector3.new((math.random() - 0.5) * 0.6, (math.random() - 0.5) * 1.2, (math.random() - 0.5) * 0.6), { Count = 1, Color = GOLD, Speed = 2, Lifetime = 0.4 })
		end
	end, function()
		holder:Destroy()
	end)
	return holder, hand
end

-- Streaks of light shooting up out of his palm.
local function palmStreaks(getFrom, time)
	local nextAt = 0
	VFXLib.animate(time, function()
		local c = os.clock()
		if c < nextAt then
			return
		end
		nextAt = c + 0.035
		local from = getFrom() + Vector3.new((math.random() - 0.5) * 0.8, 0, (math.random() - 0.5) * 0.8)
		local len = 1.5 + math.random() * 2.5
		local streak = newPart(VFXLib.Folder, "Streak", Vector3.new(0.05, len, 0.05), math.random() < 0.5 and Color3.new(1, 1, 1) or TEAL, Enum.Material.Neon, 0.2)
		local speed = 10 + math.random() * 8
		VFXLib.animate(0.35, function(x)
			streak.CFrame = CFrame.new(from + Vector3.new(0, len / 2 + speed * x * 0.35, 0))
			streak.Transparency = 0.2 + 0.8 * x
		end, function()
			streak:Destroy()
		end)
	end)
end

-- A burst of teal light behind something (a glowing disc and rays).
local function lightBurst(getAt, getFace, time)
	local disc = newPart(VFXLib.Folder, "Burst", Vector3.new(0.05, 6, 6), TEAL, Enum.Material.Neon, 1)
	disc.Shape = Enum.PartType.Cylinder
	local rays = {}
	for k = 1, 12 do
		rays[k] = newPart(VFXLib.Folder, "Ray", Vector3.new(0.12, 0.12, 5), Color3.fromRGB(220, 255, 250), Enum.Material.Neon, 1)
	end
	VFXLib.animate(time, function(a)
		local at, face = getAt(), getFace()
		local base = CFrame.lookAt(at, face)
		local swell = a < 0.2 and a / 0.2 or (a > 0.85 and (1 - a) / 0.15 or 1)
		disc.Size = Vector3.new(0.05, 4 + 3 * swell, 4 + 3 * swell)
		disc.CFrame = base * CFrame.Angles(0, math.pi / 2, 0)
		disc.Transparency = 1 - 0.55 * swell
		for k, r in ipairs(rays) do
			local ang = k / 12 * math.pi * 2 + a * 0.6
			r.CFrame = base * CFrame.Angles(0, 0, ang) * CFrame.new(0, 3.5, 0.1) * CFrame.Angles(math.pi / 2, 0, 0)
			r.Transparency = 1 - 0.5 * swell * (0.5 + 0.5 * math.sin(os.clock() * 8 + k))
		end
	end, function()
		disc:Destroy()
		for _, r in ipairs(rays) do
			r:Destroy()
		end
	end)
end

-- Johnny's shock: wide teal eyes, an open mouth, sweat running down.
local function shock(character, time)
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local s = head.Size.Y / 1.2
	local f = -head.Size.Z / 2 - 0.02 * s
	local holder = Instance.new("Model")
	holder.Name = "JohnnyShock"
	for _, side in ipairs({ -1, 1 }) do
		weldOn(head, holder, "EyeWhite", Vector3.new(0.24, 0.22, 0.04) * s, Color3.new(1, 1, 1), CFrame.new(side * 0.21 * s, 0.08 * s, f), nil, true)
		weldOn(head, holder, "Iris", Vector3.new(0.1, 0.1, 0.045) * s, Color3.fromRGB(70, 220, 210), CFrame.new(side * 0.21 * s, 0.08 * s, f - 0.006 * s), Enum.Material.Neon, true)
		weldOn(head, holder, "Pupil", Vector3.new(0.035, 0.035, 0.05) * s, Color3.fromRGB(10, 20, 30), CFrame.new(side * 0.21 * s, 0.08 * s, f - 0.01 * s), nil, true)
	end
	weldOn(head, holder, "Mouth", Vector3.new(0.22, 0.14, 0.04) * s, Color3.fromRGB(40, 20, 30), CFrame.new(0.04 * s, -0.3 * s, f), nil, true)
	weldOn(head, holder, "Teeth", Vector3.new(0.18, 0.04, 0.045) * s, Color3.fromRGB(110, 230, 220), CFrame.new(0.04 * s, -0.25 * s, f - 0.004 * s))
	holder.Parent = VFXLib.Folder
	local nextDrop = 0
	VFXLib.animate(time, function()
		local c = os.clock()
		if c < nextDrop or not head.Parent then
			return
		end
		nextDrop = c + 0.35
		local side = math.random() < 0.5 and -1 or 1
		local from = (head.CFrame * CFrame.new(side * 0.45 * s, 0.25 * s, f + 0.1 * s)).Position
		local drop = newPart(VFXLib.Folder, "Sweat", Vector3.new(0.07, 0.11, 0.07) * s, Color3.fromRGB(190, 230, 255), Enum.Material.Glass, 0.2)
		VFXLib.animate(0.8, function(x)
			drop.CFrame = CFrame.new(from + Vector3.new(0, -0.6 * s * x, 0))
			drop.Transparency = 0.2 + 0.8 * x * x
		end, function()
			drop:Destroy()
		end)
	end)
	return holder
end

-- The colour, shot by shot: dark with a green haze, then bright teal, then
-- violet, then a pink haze.
local GRADES = {
	{ Tint = Color3.fromRGB(150, 220, 180), Brightness = -0.15, Saturation = 0.1, Contrast = 0.2 },
	{ Tint = Color3.fromRGB(170, 255, 240), Brightness = 0.05, Saturation = 0.3, Contrast = 0.15 },
	{ Tint = Color3.fromRGB(190, 160, 255), Brightness = -0.02, Saturation = 0.15, Contrast = 0.2 },
	{ Tint = Color3.fromRGB(200, 170, 255), Brightness = 0, Saturation = 0.2, Contrast = 0.2 },
	{ Tint = Color3.fromRGB(255, 190, 230), Brightness = 0.08, Saturation = 0.2, Contrast = 0.1 },
}

function JohnnyArmCutscene.play(character)
	local cc = TuskConfig.Cutscenes or {}
	if cc.Enabled == false or cc.JohnnyArm == false or (last and os.clock() - last < 20) then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	local hand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	if not root or not head or not hand then
		return false
	end
	last = os.clock()
	local up = Vector3.new(0, 1, 0)
	local T = { 2.8, 2.6, 2.4, 1.8, 2.4 }
	local starts, acc = {}, 0
	for i, d in ipairs(T) do
		starts[i] = acc
		acc = acc + d
	end
	-- Where Tusk ends up: in front of him at head height, facing him.
	local headY = (root.CFrame:Inverse() * head.CFrame).Position.Y
	local TGT = CFrame.new(0.15, headY - 0.4, -4.4) * CFrame.Angles(0, math.pi, 0) -- (Tusk Act 1 is about 3.2 studs tall)
	local function rel(cf)
		return root.CFrame * cf
	end
	local function tuskAt()
		return rel(TGT).Position
	end
	local function headAt()
		return head.Parent and head.Position or root.Position + up * 1.5
	end
	local function handAt()
		return hand.Parent and hand.Position or root.Position
	end
	local shots = {
		-- 1. Down at his left hand; Tusk rises out of the palm.
		{ From = function()
			return root.Parent and CFrame.lookAt(handAt() + up * 6.5 + root.CFrame.LookVector * 2.4, handAt()) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(handAt() + up * 7 + root.CFrame.LookVector * 2.6, handAt() + up * 1.4) or nil
		end, Time = T[1], FOV = { 46, 50 } },
		-- 2. Tusk hovering in front of him, teal light behind it.
		{ From = function()
			return root.Parent and CFrame.lookAt(rel(CFrame.new(0.1, headY - 0.8, -0.4)).Position, tuskAt()) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(rel(CFrame.new(0.12, headY - 0.75, -0.9)).Position, tuskAt()) or nil
		end, Time = T[2], FOV = { 60, 54 } },
		-- 3. Over Tusk's back at Johnny's face.
		{ From = function()
			return root.Parent and CFrame.lookAt(rel(CFrame.new(1.6, headY + 0.7, -7.0)).Position, headAt()) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(rel(CFrame.new(1.5, headY + 0.6, -6.6)).Position, headAt()) or nil
		end, Time = T[3], FOV = { 34, 32 }, Linear = true },
		-- 4. Close, from the side: Tusk by his face; he's in shock.
		{ From = function()
			local mid = headAt():Lerp(tuskAt(), 0.4)
			return root.Parent and CFrame.lookAt(mid + root.CFrame.RightVector * 5.2 + up * 0.2, mid) or nil
		end, To = function()
			local mid = headAt():Lerp(tuskAt(), 0.4)
			return root.Parent and CFrame.lookAt(mid + root.CFrame.RightVector * 4.6 + up * 0.15, mid) or nil
		end, Time = T[4], FOV = { 42, 40 }, Linear = true },
		-- 5. Tusk's face close up, in a pink haze.
		{ From = function()
			return root.Parent and CFrame.lookAt(rel(CFrame.new(0.15, headY - 0.6, -0.6)).Position, tuskAt() + up * 0.4) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(rel(CFrame.new(0.15, headY - 0.6, -1.3)).Position, tuskAt() + up * 0.4) or nil
		end, Time = T[5], FOV = { 44, 38 }, Title = "TUSK ACT 1", Subtitle = "FIRST APPEARANCE", Color = PINK },
	}
	local ended = false
	local made = {}
	local look = Instance.new("ColorCorrectionEffect")
	look.Name = "TuskFirstAppearance"
	-- (Fades in from dark, like the clip's first frame.)
	look.TintColor = GRADES[1].Tint
	look.Brightness = -0.5
	look.Saturation = 0
	look.Contrast = 0
	look.Parent = game:GetService("Lighting")
	table.insert(made, look)
	local started = Cutscenes.play(shots, { Priority = 3, Skippable = true, OnEnd = function()
		ended = true
		for _, thing in ipairs(made) do
			if thing and thing.Parent then
				thing:Destroy()
			end
		end
		TuskStand.action(character, "Present", { Target = TGT, Duration = 0.05 })
	end })
	if not started then
		look:Destroy()
		return false
	end
	-- The grade follows the shots.
	local t0 = os.clock()
	VFXLib.animate(acc + 0.3, function()
		if ended or not look.Parent then
			return
		end
		local now = os.clock() - t0
		local shot = 1
		for k = #starts, 1, -1 do
			if now >= starts[k] then
				shot = k
				break
			end
		end
		local g = GRADES[shot]
		look.TintColor = look.TintColor:Lerp(g.Tint, 0.12)
		look.Brightness = look.Brightness + (g.Brightness - look.Brightness) * 0.12
		look.Saturation = look.Saturation + (g.Saturation - look.Saturation) * 0.12
		look.Contrast = look.Contrast + (g.Contrast - look.Contrast) * 0.12
	end)
	local function at(time, fn)
		task.delay(time, function()
			if not ended then
				fn()
			end
		end)
	end
	-- 1. The arm sinks in; light streaks out of his palm; Tusk rises from it.
	local arm = armSinks(character, 1.4)
	if arm then
		table.insert(made, arm)
	end
	local handLocal = (root.CFrame:Inverse() * hand.CFrame).Position
	-- Rising out of the palm, face turned up to the camera above.
	local camLocal = handLocal + Vector3.new(0, 7, -2.6)
	local risePos = handLocal + Vector3.new(0, 1.8, -0.4)
	local rise = CFrame.lookAt(risePos, camLocal)
	local fromPos = handLocal + Vector3.new(0, -1.2, 0)
	TuskStand.action(character, "Present", { From = CFrame.lookAt(fromPos, camLocal), Target = rise, In = 0.55, Duration = T[1] + 0.2, Snap = 60 })
	at(0.9, function()
		palmStreaks(handAt, T[1] - 0.9)
		CameraFX.shake(0.4, 0.4)
	end)
	-- 2. Up to hover in front of him; teal light bursts behind it.
	at(starts[2], function()
		TuskStand.action(character, "Present", { Target = TGT, In = 0.08, Duration = acc - starts[2] + 0.3, Snap = 30 })
		lightBurst(function()
			return tuskAt() - (headAt() - tuskAt()).Unit * 1.5
		end, headAt, T[2])
	end)
	-- 3-4. Johnny's shock.
	at(starts[3], function()
		local s = shock(character, T[3] + T[4] + 0.2)
		if s then
			table.insert(made, s)
		end
	end)
	-- 5. The pink haze.
	at(starts[5], function()
		for _ = 1, 14 do
			local p = tuskAt() + Vector3.new((math.random() - 0.5) * 5, (math.random() - 0.5) * 3, (math.random() - 0.5) * 5)
			local puff = newPart(VFXLib.Folder, "Haze", Vector3.new(1, 1, 1) * (1 + math.random() * 1.5), PINK, Enum.Material.SmoothPlastic, 1)
			puff.Shape = Enum.PartType.Ball
			VFXLib.animate(T[5], function(x)
				puff.CFrame = CFrame.new(p + Vector3.new(0, x * 0.6, 0))
				puff.Transparency = 0.7 + 0.3 * math.abs(x - 0.5) * 2
			end, function()
				puff:Destroy()
			end)
		end
	end)
	return true
end

-- Johnny = Tusk Acts 1-4.
local function playingJohnny(character)
	local act = character and character:GetAttribute("TuskAct")
	return act ~= nil and Registry.characterOf(act) == "Johnny"
end

function JohnnyArmCutscene.init()
	Net.get("WorldFX").OnClientEvent:Connect(function(name, data)
		if name ~= "CorpseTaken" or typeof(data) ~= "table" then
			return
		end
		local character = player and player.Character
		if data.Player == (player and player.UserId) and data.Part == "LeftArm" and playingJohnny(character) then
			JohnnyArmCutscene.play(character)
		end
	end)
end

return JohnnyArmCutscene
