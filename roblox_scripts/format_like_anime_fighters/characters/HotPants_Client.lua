--[[
	HotPants_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Hot Pants: Cream Starter.
	Its other half is HotPants_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: HotPantsVFX
-- ======================================================================
__modules["HotPantsVFX"] = function()
--[[
	TuskActVFX.HotPantsVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.HotPantsVFX)

	Client visuals for Hot Pants / CREAM STARTER, a spray can that sprays
	flesh. Blocky like the rest of the game.
	  * the CREAM STARTER can appears in her hand whenever she uses it
	  * FLESH SPRAY: a pink mist stream with flesh blobs; coated enemies have
	    lumps of flesh stuck all over them while it lasts
	  * FLESH SEAL: a flesh mask over the victim's mouth and nose, "MMPH!",
	    and a pink haze for the victim while they suffocate
	  * FLESH MEND: she sprays herself; mist swirls round her and "+5" heals pop up
	  * FLESH STORM: a flesh cloud swells in front of her, hardens into a
	    cocoon round everyone caught, then bursts into chunks
]]

local Players = game:GetService("Players")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Common = __require("TuskActCommon")
local Fighters = __require("Fighters")

local HotPantsVFX = {}
local ACT = 10
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

local FLESH = Color3.fromRGB(236, 160, 150)
local FLESH_DARK = Color3.fromRGB(196, 110, 110)
local CAN = Color3.fromRGB(242, 140, 172)
local CAP = Color3.fromRGB(245, 245, 245)
local LABEL = Color3.fromRGB(255, 225, 120)

local held = {} -- [character] = { Model, Until }
local coats = {} -- [model] = flesh lumps stuck on a coated enemy
local masks = {} -- [model] = flesh mask over a sealed face
local cocoons = {} -- [model] = Flesh Storm cocoon
local stanced = {}

---------------------------------------------------------------------------
-- CREAM STARTER: the spray can
---------------------------------------------------------------------------
local function box(model, size, cf, color, material, transparency)
	local p = VFXLib.part({ Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, Transparency = transparency or 0 })
	p.Parent = model
	return p
end

local function buildCan(scale)
	local s = scale or 1
	local m = Instance.new("Model")
	m.Name = "CreamStarter"
	m.Parent = VFXLib.Folder
	-- Stepped round body (blocky), label band, white cap, nozzle.
	local body = box(m, Vector3.new(0.5, 1.0, 0.5) * s, CFrame.new(), CAN, Enum.Material.Metal)
	box(m, Vector3.new(0.58, 0.92, 0.38) * s, CFrame.new(), CAN, Enum.Material.Metal)
	box(m, Vector3.new(0.38, 0.92, 0.58) * s, CFrame.new(), CAN, Enum.Material.Metal)
	box(m, Vector3.new(0.6, 0.3, 0.6) * s, CFrame.new(0, 0.05 * s, 0), LABEL)
	box(m, Vector3.new(0.4, 0.26, 0.4) * s, CFrame.new(0, 0.62 * s, 0), CAP)
	box(m, Vector3.new(0.14, 0.12, 0.22) * s, CFrame.new(0, 0.8 * s, -0.12 * s), Color3.fromRGB(60, 60, 66))
	m.PrimaryPart = body
	return m
end

local function nozzleCF(character)
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	local root = Common.rootOf(character)
	if not root then
		return nil
	end
	local base = hand and hand.CFrame or root.CFrame * CFrame.new(1, 0.5, -1)
	-- Held upright in the hand, nozzle pointing where she faces.
	local pos = base.Position + root.CFrame.LookVector * 0.5
	return CFrame.lookAt(pos, pos + root.CFrame.LookVector)
end

local function holdCan(character, seconds)
	local entry = held[character]
	if entry then
		entry.Until = math.max(entry.Until, os.clock() + seconds)
		return
	end
	held[character] = { Model = buildCan(1), Until = os.clock() + seconds }
end

local function stepCans()
	local now = os.clock()
	for character, entry in pairs(held) do
		local cf = character.Parent and nozzleCF(character)
		if not cf or now > entry.Until then
			entry.Model:Destroy()
			held[character] = nil
		else
			entry.Model:PivotTo(cf * CFrame.new(0, -0.3, 0.2) * CFrame.Angles(-0.25, 0, 0))
		end
	end
end

---------------------------------------------------------------------------
-- Spray
---------------------------------------------------------------------------
local function mist(position, direction, cone, count, speed)
	VFXLib.burst(position, { Count = count or 8, Texture = VFXLib.Textures.Smoke, Color = FLESH, LightEmission = 0.1, Speed = speed or 26, Lifetime = 0.45, Spread = cone or 25, Direction = direction, Drag = 3 })
	VFXLib.burst(position, { Count = math.max(2, math.floor((count or 8) / 3)), Color = Color3.fromRGB(255, 210, 220), Speed = (speed or 26) * 0.8, Lifetime = 0.3, Spread = cone or 25, Direction = direction })
end

-- Lumps of flesh flying out of the can.
local function blobs(origin, direction, range, count)
	for i = 1, count do
		local spreadDir = (CFrame.lookAt(origin, origin + direction) * CFrame.Angles((math.random() - 0.5) * 0.6, (math.random() - 0.5) * 0.8, 0)).LookVector
		local size = 0.2 + math.random() * 0.25
		local p = VFXLib.part({ Size = Vector3.new(size, size, size), Color = i % 2 == 0 and FLESH or FLESH_DARK, Material = Enum.Material.SmoothPlastic })
		local dist = range * (0.5 + math.random() * 0.5)
		VFXLib.animate(0.3 + math.random() * 0.15, function(a)
			p.CFrame = CFrame.new(origin + spreadDir * dist * a - Vector3.new(0, 2 * a * a, 0)) * CFrame.Angles(a * 6, a * 4, 0)
			p.Transparency = a > 0.8 and (a - 0.8) / 0.2 or 0
		end, function()
			p:Destroy()
		end)
	end
end

---------------------------------------------------------------------------
-- Status visuals driven by attributes (coated / sealed / encased)
---------------------------------------------------------------------------
local function candidates()
	local list = {}
	for _, f in ipairs(Fighters.list()) do
		if f.Character then
			table.insert(list, f.Character)
		end
	end
	local dummies = workspace:FindFirstChild("SpinTestDummies")
	if dummies then
		for _, d in ipairs(dummies:GetChildren()) do
			table.insert(list, d)
		end
	end
	return list
end

local LUMP_PARTS = { "UpperTorso", "Torso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm", "LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg", "Head" }

local function makeCoat(model)
	local lumps = {}
	for i, name in ipairs(LUMP_PARTS) do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local size = 0.35 + (i % 3) * 0.12
			local lump = VFXLib.part({ Size = Vector3.new(size, size * 0.8, size), Color = i % 2 == 0 and FLESH or FLESH_DARK, Material = Enum.Material.SmoothPlastic })
			local offset = CFrame.new((i % 2 == 0 and 1 or -1) * part.Size.X * 0.4, ((i * 37) % 10 / 10 - 0.5) * part.Size.Y * 0.6, -part.Size.Z * 0.45)
			table.insert(lumps, { Part = lump, On = part, Offset = offset })
		end
	end
	return lumps
end

local function makeMask(model)
	local head = model:FindFirstChild("Head")
	if not head then
		return nil
	end
	local s = head.Size.Y / 1.2
	local m = Instance.new("Model")
	m.Parent = VFXLib.Folder
	local main = box(m, Vector3.new(head.Size.X * 0.9, 0.55 * s, 0.3 * s), CFrame.new(), FLESH)
	box(m, Vector3.new(head.Size.X * 0.7, 0.35 * s, 0.38 * s), CFrame.new(0, 0.05 * s, 0), FLESH_DARK)
	m.PrimaryPart = main
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(110, 34)
	gui.StudsOffset = Vector3.new(0, 1.2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = main
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.Text = "MMPH!"
	label.TextColor3 = FLESH_DARK
	label.TextStrokeTransparency = 0
	label.Parent = gui
	return { Model = m, Head = head, Label = label, S = s }
end

local function makeCocoon(model)
	local root = Common.rootOf(model)
	if not root then
		return nil
	end
	local m = Instance.new("Model")
	m.Parent = VFXLib.Folder
	local main = box(m, Vector3.new(4.2, 6.2, 4.2), CFrame.new(), FLESH, Enum.Material.SmoothPlastic, 0.12)
	box(m, Vector3.new(4.8, 5.4, 3.4), CFrame.new(), FLESH, Enum.Material.SmoothPlastic, 0.12)
	box(m, Vector3.new(3.4, 5.4, 4.8), CFrame.new(), FLESH, Enum.Material.SmoothPlastic, 0.12)
	-- Darker veins wrapping it.
	for i = 0, 3 do
		box(m, Vector3.new(4.9, 0.25, 4.9), CFrame.new(0, -2 + i * 1.3, 0) * CFrame.Angles(0, i * 0.4, 0.15 * (i % 2 == 0 and 1 or -1)), FLESH_DARK, Enum.Material.SmoothPlastic, 0.05)
	end
	m.PrimaryPart = main
	m:ScaleTo(0.2)
	return { Model = m, Born = os.clock() }
end

local function stepStatus()
	local t = workspace:GetServerTimeNow()
	local seenCoat, seenMask, seenCocoon = {}, {}, {}
	for _, model in ipairs(candidates()) do
		if (model:GetAttribute("FleshCoatedUntil") or 0) > t then
			seenCoat[model] = true
			coats[model] = coats[model] or makeCoat(model)
		end
		if (model:GetAttribute("FleshSealedUntil") or 0) > t then
			seenMask[model] = true
			if not masks[model] then
				masks[model] = makeMask(model)
				if model == localPlayer.Character then
					TuskVFX.ScreenTint((model:GetAttribute("FleshSealedUntil") or t) - t, { Tint = Color3.fromRGB(255, 190, 190), Saturation = -0.4, Brightness = -0.15 })
				end
			end
		end
		if (model:GetAttribute("FleshEncasedUntil") or 0) > t then
			seenCocoon[model] = true
			cocoons[model] = cocoons[model] or makeCocoon(model)
		end
	end
	for model, lumps in pairs(coats) do
		if not seenCoat[model] then
			coats[model] = nil
			for _, l in ipairs(lumps) do
				VFXLib.burst(l.Part.Position, { Count = 2, Color = FLESH, Speed = 6, Lifetime = 0.25 })
				l.Part:Destroy()
			end
		end
	end
	for model, mask in pairs(masks) do
		if not seenMask[model] then
			masks[model] = nil
			if mask then
				mask.Model:Destroy()
			end
		end
	end
	for model, c in pairs(cocoons) do
		if not seenCocoon[model] then
			cocoons[model] = nil
			if c then
				c.Model:Destroy()
			end
		end
	end
end

local function stepAttached()
	local now = os.clock()
	for _, lumps in pairs(coats) do
		for _, l in ipairs(lumps) do
			if l.On.Parent then
				l.Part.CFrame = l.On.CFrame * l.Offset
			end
		end
	end
	for _, mask in pairs(masks) do
		if mask and mask.Head.Parent then
			mask.Model:PivotTo(mask.Head.CFrame * CFrame.new(0, -0.22 * mask.S, -mask.Head.Size.Z / 2 - 0.08 * mask.S))
			mask.Label.Rotation = math.sin(now * 18) * 6
		end
	end
	for model, c in pairs(cocoons) do
		local root = c and Common.rootOf(model)
		if root then
			local grow = math.min((now - c.Born) / 0.25, 1)
			c.Model:ScaleTo(0.2 + 0.8 * grow + math.sin(now * 14) * 0.02)
			c.Model:PivotTo(CFrame.new(root.Position) * CFrame.Angles(0, now * 0.5, 0))
		end
	end
end

local function popHeal(position, amount)
	local carrier = VFXLib.anchor(CFrame.new(position + Vector3.new((math.random() - 0.5) * 1.5, 2, 0)), 1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(90, 36)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = carrier
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.Text = "+" .. amount
	label.TextColor3 = Color3.fromRGB(150, 240, 150)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local start = carrier.Position
	VFXLib.animate(0.9, function(a)
		carrier.Position = start + Vector3.new(0, a * 2.5, 0)
		label.TextTransparency = math.max(0, (a - 0.6) / 0.4)
		label.TextStrokeTransparency = label.TextTransparency
	end)
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
	local index = data.Index
	TuskAnimation.play(character, "H_M1_" .. index)
	VFXLib.sound(sounds.Swing, root, 0.5, 1.1 + index * 0.06)
	if index <= 2 then
		Common.swipe(root, index == 1 and 1 or -1, index == 1 and pal.Main or pal.Light)
	elseif index == 3 then
		-- A quick spray burst in the face.
		holdCan(character, 0.4)
		task.delay(0.08, function()
			local cf = character.Parent and nozzleCF(character)
			if cf then
				mist(cf.Position, cf.LookVector, 20, 10, 22)
				blobs(cf.Position, cf.LookVector, 6, 4)
			end
		end)
	end
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "FleshSpray" and phase == "Spray" and root then
		TuskAnimation.play(character, "HPSpray")
		local total = (data.Startup or 0.12) + (data.Duration or 0.6)
		holdCan(character, total + 0.2)
		VFXLib.sound(sounds.ChargeLoop, root, 0.4, 1.4)
		local nextPuff = 0
		VFXLib.animate(total, function(a, dt)
			nextPuff = nextPuff - (dt or 1 / 60)
			if a * total < (data.Startup or 0.12) or nextPuff > 0 then
				return
			end
			nextPuff = 0.06
			local cf = character.Parent and nozzleCF(character)
			if cf then
				mist(cf.Position, data.Direction or cf.LookVector, (data.Cone or 55) / 2, 9, (data.Range or 15) * 2)
				blobs(cf.Position, data.Direction or cf.LookVector, data.Range or 15, 2)
			end
		end)
	elseif move == "FleshSeal" then
		if phase == "Startup" and character then
			TuskAnimation.play(character, "HPSeal")
			holdCan(character, 0.7)
		elseif phase == "Seal" and data.Target then
			local head = data.Target:FindFirstChild("Head")
			local cf = character and nozzleCF(character)
			if head and cf then
				blobs(cf.Position, (head.Position - cf.Position).Unit, (head.Position - cf.Position).Magnitude, 6)
				VFXLib.burst(head.Position, { Count = 14, Texture = VFXLib.Textures.Smoke, Color = FLESH, LightEmission = 0, Speed = 8, Lifetime = 0.5 })
			end
			VFXLib.sound(sounds.Hit, head or root, 0.5, 0.8)
		elseif phase == "Miss" and root then
			local cf = nozzleCF(character)
			if cf then
				mist(cf.Position, data.Direction or cf.LookVector, 15, 8, 20)
			end
		end
	elseif move == "FleshMend" and phase == "Mend" and root then
		TuskAnimation.play(character, "HPMend")
		holdCan(character, (data.Duration or 1.2) + 0.1)
		local ticks = 4
		for i = 1, ticks do
			task.delay(i * (data.Duration or 1.2) / ticks, function()
				local r = Common.rootOf(character)
				if r then
					popHeal(r.Position, math.floor((data.Heal or 22) / ticks * 10 + 0.5) / 10)
				end
			end)
		end
		-- Pink mist swirling round her.
		VFXLib.animate(data.Duration or 1.2, function(a)
			local r = Common.rootOf(character)
			if r and math.random() < 0.5 then
				local ang = a * 18
				local p = r.Position + Vector3.new(math.cos(ang) * 2, (a * 4) % 4 - 2, math.sin(ang) * 2)
				VFXLib.burst(p, { Count = 2, Texture = VFXLib.Textures.Smoke, Color = FLESH, LightEmission = 0.2, Speed = 2, Lifetime = 0.5 })
			end
		end)
		VFXLib.flash(root.Position, pal.Light, 2, 14, 0.4)
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Cloud" then
		TuskAnimation.play(character, "HPStorm")
		holdCan(character, (data.Windup or 0.7) + 0.4)
		-- The flesh cloud swells in front of her.
		local cloud = Instance.new("Model")
		cloud.Parent = VFXLib.Folder
		local center = data.Position + Vector3.new(0, 2.5, 0)
		local puffs = {}
		for i = 1, 7 do
			local a = i / 7 * math.pi * 2
			local p = box(cloud, Vector3.new(5, 4, 5), CFrame.new(center + Vector3.new(math.cos(a) * 5, (i % 3) * 1.2, math.sin(a) * 5)), i % 2 == 0 and FLESH or FLESH_DARK, Enum.Material.SmoothPlastic, 0.35)
			puffs[i] = { Part = p, Base = p.CFrame }
		end
		local windup = data.Windup or 0.7
		VFXLib.animate(windup + 1.8, function(a)
			local t = a * (windup + 1.8)
			local grow = math.min(t / windup, 1)
			for i, puff in ipairs(puffs) do
				local w = 1 + math.sin(t * 6 + i) * 0.08
				puff.Part.Size = Vector3.new(5, 4, 5) * (0.3 + grow) * w
				puff.Part.Transparency = t > windup + 1.2 and 0.35 + (t - windup - 1.2) / 0.6 * 0.65 or 0.35
			end
			if root and root.Parent and t < windup then
				local cf = nozzleCF(character)
				if cf and math.random() < 0.6 then
					mist(cf.Position, (center - cf.Position).Unit, 15, 6, 30)
				end
			end
		end, function()
			cloud:Destroy()
		end)
		if Common.isLocal(character) then
			CameraFX.fovPunch(-5, 0.4)
		end
	elseif data.Phase == "Encase" then
		VFXLib.sound(sounds.Hit, data.Position, 0.8, 0.7)
		CameraFX.shakeAt(data.Position, 0.5, 50)
	elseif data.Phase == "Burst" then
		-- Every cocoon bursts into chunks.
		for _, target in ipairs(data.Targets or {}) do
			local r = Common.rootOf(target)
			if r then
				for i = 1, 8 do
					local dir = Vector3.new(math.cos(i), 0.6 + (i % 3) * 0.3, math.sin(i)).Unit
					local chunk = VFXLib.part({ Size = Vector3.new(0.9, 0.7, 0.9), Color = i % 2 == 0 and FLESH or FLESH_DARK, Material = Enum.Material.SmoothPlastic })
					local from = r.Position
					VFXLib.animate(0.6, function(a)
						chunk.CFrame = CFrame.new(from + dir * 14 * a - Vector3.new(0, 18 * a * a, 0)) * CFrame.Angles(a * 8, a * 5, 0)
						chunk.Transparency = a > 0.7 and (a - 0.7) / 0.3 or 0
					end, function()
						chunk:Destroy()
					end)
				end
				VFXLib.burst(r.Position, { Count = 20, Texture = VFXLib.Textures.Smoke, Color = FLESH, LightEmission = 0, Speed = 24, Lifetime = 0.6 })
			end
		end
		Common.finisher({ Character = character, Position = data.Position + Vector3.new(0, 2.5, 0), Radius = data.Radius, Hit = true }, pal, { Size = 1.6, Layers = 3, Shake = 0.9 })
		if Common.isLocal(character) then
			CameraFX.impactFrame(pal.Light)
		end
	end
end

---------------------------------------------------------------------------
local function stepStance()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character then
			local want = character:GetAttribute("TuskAct") == ACT
			if want and not stanced[character] then
				stanced[character] = true
				TuskAnimation.hold(character, "HPStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "HPStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function HotPantsVFX.handle(name, data)
	if name == "M1" then
		onM1(data)
	elseif name == "M1Finisher" then
		Common.finisher(data, pal)
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

local slowTimer = 0
function HotPantsVFX.step(dt)
	dt = dt or 1 / 60
	stepCans()
	stepAttached()
	slowTimer = slowTimer + dt
	if slowTimer > 0.15 then
		slowTimer = 0
		stepStatus()
		stepStance()
	end
end

return HotPantsVFX
end
end
