--[[
	TuskActVFX.Diego  (StarterPlayerScripts.SpinClient.TuskActVFX.Diego)

	Client visuals for Diego Brando / SCARY MONSTERS:
	  * hunched predator stance + claw / tail-whip / bite animations (human)
	  * SCARY MONSTERS: the player turns into the full raptor (RaptorModel),
	    animated every frame: running legs, swaying tail, jaw snaps, claw
	    rakes, tail whips. The player's own body is hidden locally.
	  * KINETIC VISION (Diego only, while transformed): moving enemies glow
	  * claw marks, tail sweeps, "chomp" fangs that snap shut on bites
	  * DINO INFECTION: scales spread over the victim, then they turn into a
	    dinosaur in their own avatar's colours that Diego commands
	    ("YOUR DINO 7s" tag, blue outline, bites, "sic 'em" target marks)
	  * RAPTOR POUNCE: crouch, leap trail, crunching landing
	  * RAPTOR PACK: a roar shock, then a pack of raptors charges out
]]

local Players = game:GetService("Players")
local Fighters = require(script.Parent.Parent.Fighters)
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local VFXQuality = require(Shared.VFXQuality)
local RaptorModel = require(Shared.RaptorModel)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local Common = require(script.Parent.Parent.TuskActCommon)

local Diego = {}
local pal = Common.palette(6)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer
local DIEGO_ACT = 6
local WHITE = Color3.new(1, 1, 1)
-- Scary Monsters' slashes are blue (owner's request).
local SLASH = Color3.fromRGB(40, 110, 255)
local SLASH_LIGHT = Color3.fromRGB(150, 205, 255)

local dinos = {} -- [character] = transformed raptor entry
local stanced = {} -- [character] = true while holding the human stance
local infected = {} -- [model] = infection visuals
local seen = {} -- [model] = kinetic-vision highlight
local pack = {} -- [raptor id] = running pack raptor
local thralls = {} -- [model] = a Dino Infection victim turned into a dinosaur
local visionTint

local function candidates()
	local list = {}
	for _, player in ipairs(Fighters.list()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	local dummies = workspace:FindFirstChild("SpinTestDummies")
	if dummies then
		for _, d in ipairs(dummies:GetChildren()) do
			if d:IsA("Model") then
				table.insert(list, d)
			end
		end
	end
	return list
end

local function groundCF(character, root)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local drop = 3
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then
		drop = humanoid.HipHeight + root.Size.Y / 2
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	local pos = root.Position - Vector3.new(0, drop, 0)
	return CFrame.lookAt(pos, pos + flat.Unit)
end

---------------------------------------------------------------------------
-- Small effects
---------------------------------------------------------------------------
-- Three parallel claw marks raking across.
local function clawMarks(cf, side, scale, color)
	for k = -1, 1 do
		TuskVFX.CreateCrescent(cf * CFrame.new(k * 0.35 * scale, k * 0.45 * scale, 0) * CFrame.Angles(0, 0, side * 0.95), {
			Radius = 2.3 * scale,
			Width = 0.24 * scale,
			Arc = math.rad(105),
			Sweep = side * 1.5,
			Color = color or SLASH,
			Color2 = SLASH_LIGHT,
			Duration = 0.2,
		})
	end
end

-- Rows of fangs that snap shut on a point: the "chomp".
local function chomp(position, facing, size, color)
	if not VFXLib.acquire() then
		return
	end
	size = size or 1
	color = color or pal.Light
	local fangs = {}
	local count = 5
	local look = facing or Vector3.new(0, 0, -1)
	local base = CFrame.lookAt(position, position + look)
	for row = -1, 1, 2 do
		for i = 1, count do
			local x = (i - (count + 1) / 2) * 0.42 * size
			local fang = VFXLib.part({ Color = color, Size = Vector3.new(0.18, 0.75, 0.18) * size, Transparency = 0.05 })
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = fang
			fangs[#fangs + 1] = { Part = fang, X = x, Row = row }
		end
	end
	local open = 1.3 * size
	VFXLib.animate(0.32, function(a)
		local close = a < 0.35 and VFXLib.easeOut(a / 0.35) or 1
		local fade = a < 0.5 and 0 or (a - 0.5) / 0.5
		for _, f in ipairs(fangs) do
			local y = f.Row * (open - (open - 0.3 * size) * close)
			f.Part.CFrame = base * CFrame.new(f.X, y, 0) * CFrame.Angles(0, 0, f.Row > 0 and 0 or math.pi)
			f.Part.Transparency = 0.05 + fade * 0.95
		end
	end, function()
		for _, f in ipairs(fangs) do
			f.Part:Destroy()
		end
		VFXLib.release()
	end)
	task.delay(0.1, function()
		TuskVFX.CreateImpactStar(position, { Size = 3.5 * size, Rays = 7, Color = pal.Main, Color2 = WHITE, Duration = 0.2 })
		VFXLib.burst(position, { Count = 10, Color = pal.Light, Speed = 18, Lifetime = 0.25 })
	end)
end

local function roarSound(position, pitch)
	VFXLib.sound(sounds.AwakeningBurst, position, 1, pitch or 0.55)
	VFXLib.sound(sounds.Warning, position, 0.5, 0.45)
end

---------------------------------------------------------------------------
-- SCARY MONSTERS: transformed raptor on any character
---------------------------------------------------------------------------
local function setHidden(character, hidden)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function transformBurst(character, root, color)
	local pos = root.Position
	VFXLib.flash(pos, color or pal.Main, 8, 30, 0.4)
	TuskVFX.CreateRotationalShockwave(CFrame.new(pos - Vector3.new(0, 2.8, 0)), { Radius = 12, Layers = 3, Color = pal.Main, Color2 = pal.Second, Ground = true, Particles = 1.5, Width = 0.6 })
	TuskVFX.CreateImpactStar(pos + Vector3.new(0, 1, 0), { Size = 8, Rays = 10, Color = pal.Main, Color2 = WHITE, Duration = 0.35 })
	-- Scales burst off the body.
	VFXLib.burst(pos, {
		Count = 30,
		Color = pal.Main,
		Speed = 30,
		Lifetime = 0.6,
		Drag = 2,
		Acceleration = Vector3.new(0, -40, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) }),
	})
	VFXLib.burst(pos, { Count = 8, Texture = VFXLib.Textures.Smoke, Color = Color3.fromRGB(190, 170, 140), LightEmission = 0, Speed = 10, Lifetime = 0.8 })
end

local function startDino(character, root)
	local rig = RaptorModel.build(1, { Lite = VFXQuality.get().RingSegments <= 12 })
	rig.Model.Parent = VFXLib.Folder
	local entry = { Rig = rig, Phase = 0, Jaw = 0, Lunge = 0, Claw = 0, Crouch = 0, Whip = 0, WhipT = 0, WhipDir = 1, Grow = 0 }
	dinos[character] = entry
	transformBurst(character, root)
	roarSound(root.Position, 0.6)
	if Common.isLocal(character) then
		CameraFX.shake(0.6, 0.4)
		CameraFX.fovPunch(10, 0.4)
		if not visionTint then
			visionTint = Instance.new("ColorCorrectionEffect")
			visionTint.Name = "KineticVision"
			visionTint.TintColor = Color3.fromRGB(215, 255, 240)
			visionTint.Saturation = 0.15
			visionTint.Contrast = 0.08
			visionTint.Parent = game:GetService("Lighting")
		end
	end
	return entry
end

local function stopDino(character)
	local entry = dinos[character]
	if not entry then
		return
	end
	dinos[character] = nil
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		transformBurst(character, root, pal.Light)
	end
	entry.Rig:Destroy()
	if character.Parent then
		setHidden(character, false)
	end
	if Common.isLocal(character) and visionTint then
		visionTint:Destroy()
		visionTint = nil
	end
end

local function stepDinos(dt)
	local now = os.clock()
	local alive = {}
	for _, player in ipairs(Fighters.list()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and character:GetAttribute("DinoMode") then
			alive[character] = true
			local entry = dinos[character] or startDino(character, root)
			setHidden(character, true)
			local v = root.AssemblyLinearVelocity
			local speed = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / 26, 0, 1)
			entry.Phase = entry.Phase + dt * (3 + speed * 12)
			local decay = math.exp(-dt * 7)
			entry.Jaw = entry.Jaw * decay
			entry.Lunge = entry.Lunge * decay
			entry.Claw = entry.Claw * decay
			entry.Crouch = entry.Crouch * math.exp(-dt * 5)
			local whip = 0
			if entry.WhipT > 0 then
				entry.WhipT = math.max(0, entry.WhipT - dt)
				whip = math.sin((1 - entry.WhipT / 0.35) * math.pi) * entry.WhipDir
			end
			entry.Grow = math.min(1, entry.Grow + dt * 4)
			local airborne = humanoid.FloorMaterial == Enum.Material.Air
			entry.Rig:Pose(groundCF(character, root), {
				Time = now,
				Phase = entry.Phase,
				Speed = airborne and 0.3 or speed,
				Jaw = math.max(entry.Jaw, entry.Roar or 0),
				Lunge = entry.Lunge,
				Claw = entry.Claw,
				Crouch = entry.Crouch + (1 - entry.Grow) * 0.8,
				Whip = whip,
				HeadPitch = (entry.Roar or 0) * 0.5,
			})
		end
	end
	for character in pairs(dinos) do
		if not alive[character] then
			stopDino(character)
		end
	end
end

---------------------------------------------------------------------------
-- DINO INFECTION victims: a dinosaur in their own avatar's colours
---------------------------------------------------------------------------
local function partColor(model, names)
	for _, n in ipairs(names) do
		local p = model:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			return p.Color
		end
	end
	return nil
end

-- Colours from the victim's avatar: torso -> body, legs -> legs and tail, head -> head.
local function avatarPalette(model)
	local body = partColor(model, { "UpperTorso", "Torso" }) or pal.Main
	local legs = partColor(model, { "LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg" }) or pal.Second
	local head = partColor(model, { "Head" }) or body
	-- Keep the body and legs readable when the avatar is all one colour.
	local d = math.abs(body.R - legs.R) + math.abs(body.G - legs.G) + math.abs(body.B - legs.B)
	if d < 0.15 then
		legs = body:Lerp(Color3.new(0, 0, 0), 0.35)
	end
	return { Body = body, Legs = legs, Head = head }
end

local function stopThrall(model)
	local t = thralls[model]
	if not t then
		return
	end
	thralls[model] = nil
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		transformBurst(model, root, pal.Light)
	end
	t.Rig:Destroy()
	t.Tag:Destroy()
	t.Highlight:Destroy()
	if model.Parent then
		setHidden(model, false)
	end
end

local function stepThralls(dt)
	local now = os.clock()
	local keep = {}
	for _, model in ipairs(candidates()) do
		local owner = model:GetAttribute("DinoThrall")
		local root = model:FindFirstChild("HumanoidRootPart")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if owner and root and humanoid and humanoid.Health > 0 then
			keep[model] = true
			local t = thralls[model]
			if not t then
				local rig = RaptorModel.build(0.85, { Lite = VFXQuality.get().RingSegments <= 12, Palette = avatarPalette(model) })
				rig.Model.Parent = VFXLib.Folder
				-- Blue outline: this dinosaur belongs to Diego.
				local h = Instance.new("Highlight")
				h.Adornee = rig.Model
				h.FillTransparency = 1
				h.OutlineColor = SLASH
				h.DepthMode = Enum.HighlightDepthMode.Occluded
				h.Parent = VFXLib.Folder
				-- Floating tag with the time left.
				local tag = Instance.new("BillboardGui")
				tag.Size = UDim2.fromOffset(150, 26)
				tag.StudsOffset = Vector3.new(0, 5.5, 0)
				tag.AlwaysOnTop = true
				tag.Adornee = root
				tag.Parent = VFXLib.Folder
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromScale(1, 1)
				label.Font = Enum.Font.Bangers
				label.TextScaled = true
				label.TextColor3 = SLASH_LIGHT
				label.TextStrokeTransparency = 0
				label.Parent = tag
				t = { Rig = rig, Tag = tag, Label = label, Highlight = h, Phase = 0, Jaw = 0, Lunge = 0 }
				thralls[model] = t
				transformBurst(model, root, pal.Main)
				roarSound(root.Position, 0.75)
			end
			setHidden(model, true)
			local v = root.AssemblyLinearVelocity
			local speed = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / 24, 0, 1)
			t.Phase = t.Phase + dt * (3 + speed * 12)
			local decay = math.exp(-dt * 7)
			t.Jaw = t.Jaw * decay
			t.Lunge = t.Lunge * decay
			t.Rig:Pose(groundCF(model, root), { Time = now, Phase = t.Phase, Speed = speed, Jaw = math.max(t.Jaw, 0.15), Lunge = t.Lunge })
			local untilT = model:GetAttribute("DinoThrallUntil")
			local left = untilT and math.max(0, untilT - workspace:GetServerTimeNow()) or 0
			t.Label.Text = (owner == localPlayer.UserId and "YOUR DINO" or "DIEGO'S DINO") .. "  " .. math.ceil(left) .. "s"
		end
	end
	for model in pairs(thralls) do
		if not keep[model] then
			stopThrall(model)
		end
	end
end

-- Kinetic vision: while YOU are transformed, moving enemies glow through walls.
local function stepVision()
	local me = localPlayer.Character
	local myRoot = me and me:FindFirstChild("HumanoidRootPart")
	local active = me and me:GetAttribute("DinoMode") and myRoot
	local range = TuskConfig.Diego.ScaryMonsters.KineticVision or 90
	local keep = {}
	if active then
		for _, model in ipairs(candidates()) do
			if model ~= me and model:GetAttribute("DinoThrall") ~= localPlayer.UserId then
				local root = model:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - myRoot.Position).Magnitude < range then
					local v = root.AssemblyLinearVelocity
					if Vector3.new(v.X, 0, v.Z).Magnitude > 3 or math.abs(v.Y) > 8 then
						keep[model] = true
						if not seen[model] then
							local h = Instance.new("Highlight")
							h.Name = "KineticVision"
							h.Adornee = model
							h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
							h.FillColor = Color3.fromRGB(255, 120, 60)
							h.FillTransparency = 0.75
							h.OutlineColor = Color3.fromRGB(255, 200, 80)
							h.Parent = VFXLib.Folder
							seen[model] = h
						end
					end
				end
			end
		end
	end
	for model, h in pairs(seen) do
		if not keep[model] then
			h:Destroy()
			seen[model] = nil
		end
	end
end

---------------------------------------------------------------------------
-- Human stance (hunched predator) while playing Diego untransformed
---------------------------------------------------------------------------
local function stepStance()
	for _, player in ipairs(Fighters.list()) do
		local character = player.Character
		if character then
			local want = character:GetAttribute("TuskAct") == DIEGO_ACT and not character:GetAttribute("DinoMode")
			if want and not stanced[character] then
				stanced[character] = true
				TuskAnimation.hold(character, "DiegoStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "DiegoStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

---------------------------------------------------------------------------
-- DINO INFECTION visuals on infected targets
---------------------------------------------------------------------------
local function stepInfected()
	local keep = {}
	for _, model in ipairs(candidates()) do
		if model:GetAttribute("DinoInfected") and not model:GetAttribute("DinoThrall") then
			local root = model:FindFirstChild("HumanoidRootPart")
			if root then
				keep[model] = true
				local entry = infected[model]
				if not entry then
					entry = { Scales = {}, Start = os.clock() }
					local h = Instance.new("Highlight")
					h.Adornee = model
					h.FillColor = pal.Main
					h.FillTransparency = 0.7
					h.OutlineColor = pal.Second
					h.DepthMode = Enum.HighlightDepthMode.Occluded
					h.Parent = VFXLib.Folder
					entry.Highlight = h
					local a = Instance.new("Attachment")
					a.Name = "DinoSpores"
					a.Parent = root
					local e = Instance.new("ParticleEmitter")
					e.Texture = VFXLib.Textures.Sparkle
					e.Color = ColorSequence.new(pal.Light, pal.Second)
					e.LightEmission = 0.6
					e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
					e.Lifetime = NumberRange.new(0.4, 0.8)
					e.Speed = NumberRange.new(1, 3)
					e.SpreadAngle = Vector2.new(180, 180)
					e.Rate = 14 * VFXQuality.get().Particles
					e.Parent = a
					entry.Spores = a
					-- Dinosaur scales sprout on the limbs.
					for _, limbName in ipairs({ "RightUpperArm", "LeftUpperArm", "UpperTorso", "RightUpperLeg", "LeftUpperLeg", "Right Arm", "Left Arm", "Torso", "Right Leg", "Left Leg", "Head" }) do
						local limb = model:FindFirstChild(limbName)
						if limb and limb:IsA("BasePart") and #entry.Scales < 10 then
							for _ = 1, 2 do
								local offset = Vector3.new((math.random() - 0.5) * limb.Size.X, (math.random() - 0.5) * limb.Size.Y, -limb.Size.Z / 2)
								local scale = VFXLib.part({ Material = Enum.Material.SmoothPlastic, Color = (math.random() < 0.5) and pal.Main or pal.Second, Size = Vector3.new(0.1, 0.1, 0.1), Anchored = false, Massless = true })
								local mesh = Instance.new("SpecialMesh")
								mesh.MeshType = Enum.MeshType.Sphere
								mesh.Parent = scale
								scale.CFrame = limb.CFrame * CFrame.new(offset)
								local weld = Instance.new("WeldConstraint")
								weld.Part0 = limb
								weld.Part1 = scale
								weld.Parent = scale
								table.insert(entry.Scales, { Part = scale, Limb = limb, Offset = offset })
							end
						end
					end
					infected[model] = entry
				end
				-- Scales grow in over half a second; the glow pulses.
				local grow = math.min(1, (os.clock() - entry.Start) / 0.5)
				for _, sc in ipairs(entry.Scales) do
					local d = 0.1 + 0.5 * grow
					if sc.Part.Size.X < d - 0.01 then
						-- Resize only: never move a welded part (that would drag the victim).
						sc.Part.Size = Vector3.new(d, d * 0.6, d)
					end
				end
				entry.Highlight.FillTransparency = 0.65 + math.sin(os.clock() * 6) * 0.1
			end
		end
	end
	for model, entry in pairs(infected) do
		if not keep[model] then
			infected[model] = nil
			entry.Highlight:Destroy()
			entry.Spores:Destroy()
			for _, sc in ipairs(entry.Scales) do
				local root = model:FindFirstChild("HumanoidRootPart")
				if root and sc.Part.Parent then
					VFXLib.burst(sc.Part.Position, { Count = 2, Color = pal.Main, Speed = 6, Lifetime = 0.3 })
				end
				sc.Part:Destroy()
			end
		end
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function dinoAction(character, kind, value)
	local entry = dinos[character]
	if not entry then
		return false
	end
	if kind == "Claw" then
		entry.Claw = 1
		entry.Jaw = math.max(entry.Jaw, 0.35)
	elseif kind == "Whip" then
		entry.WhipT = 0.35
		entry.WhipDir = value or 1
	elseif kind == "Bite" then
		entry.Jaw = 1
		entry.Lunge = 1
	elseif kind == "Crouch" then
		entry.Crouch = 1
	elseif kind == "Roar" then
		entry.Roar = 1
		task.delay(value or 0.8, function()
			entry.Roar = 0
		end)
	end
	return true
end

local function onM1(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local index = data.Index
	local transformed = dinos[character] ~= nil
	local scale = transformed and 1.4 or 1
	VFXLib.sound(sounds.Swing, root, 0.5, (transformed and 0.8 or 1) * (0.95 + index * 0.06))
	if index <= 2 then
		local side = index == 1 and 1 or -1
		if not dinoAction(character, "Claw") then
			TuskAnimation.play(character, "D_M1_" .. index)
		end
		clawMarks(root.CFrame * CFrame.new(side * 0.3, 0.6, -2.2 * scale), side, scale)
	elseif index == 3 then
		if not dinoAction(character, "Whip", 1) then
			TuskAnimation.play(character, "D_M1_3")
		end
		-- Wide low tail sweep around the body.
		TuskVFX.CreateCrescent(root.CFrame * CFrame.new(0, -1.6, 0), { Radius = 4.5 * scale, Width = 0.5 * scale, Arc = math.rad(200), Sweep = 2.6, Color = SLASH, Color2 = SLASH_LIGHT, Duration = 0.26 })
		VFXLib.burst(root.Position - Vector3.new(0, 2.5, 0), { Count = 8, Texture = VFXLib.Textures.Smoke, Color = Color3.fromRGB(200, 180, 140), LightEmission = 0, Speed = 12, Lifetime = 0.5 })
	else
		if not dinoAction(character, "Bite") then
			TuskAnimation.play(character, "D_M1_4")
		end
	end
end

-- RAPTOR POUNCE: Diego's own client flies the leap (it owns his physics, so
-- the arc is smooth and every other player sees it replicate). The server
-- picked the landing spot and deals the damage there.
local function flyLeap(character, root, data)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local from = root.Position -- start from where we really are right now
	local to = data.To or from
	local height = data.Height or 7
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(data.Direction.X, 0, data.Direction.Z).Unit
	local stopped = false
	if humanoid then
		humanoid.AutoRotate = false
	end
	VFXLib.animate(data.Time or 0.36, function(a)
		if stopped then
			return
		end
		-- Hit out of the air (stunned) or died: let physics take over.
		if not root.Parent or character:GetAttribute("Stunned") or (humanoid and humanoid.Health <= 0) then
			stopped = true
			return
		end
		local e = a < 1 and (0.5 - 0.5 * math.cos(a * math.pi)) or 1 -- ease in/out along the ground
		local p = from:Lerp(to, e) + Vector3.new(0, 4 * height * a * (1 - a), 0)
		root.CFrame = CFrame.lookAt(p, p + dir)
		root.AssemblyLinearVelocity = Vector3.new()
	end, function()
		if humanoid and humanoid.Parent then
			humanoid.AutoRotate = true
		end
		if root.Parent and not stopped then
			root.AssemblyLinearVelocity = dir * 6 -- small carry on landing, no slide
		end
	end)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Move == "RaptorPounce" then
		if data.Phase == "Startup" and root then
			if not dinoAction(character, "Crouch") then
				TuskAnimation.play(character, "DiegoPounce")
			end
			VFXLib.burst(root.Position - Vector3.new(0, 2.6, 0), { Count = 10, Texture = VFXLib.Textures.Smoke, Color = Color3.fromRGB(200, 180, 140), LightEmission = 0, Speed = 8, Lifetime = 0.6 })
			-- Eyes flash before the leap.
			VFXLib.flash(root.Position + Vector3.new(0, 1.5, 0), pal.Main, 3, 10, 0.2)
		elseif data.Phase == "Leap" and root then
			if Common.isLocal(character) then
				flyLeap(character, root, data)
			end
			dinoAction(character, "Bite")
			VFXLib.sound(sounds.Swing, root, 0.7, 0.7)
			TuskVFX.CreateRotationalShockwave(CFrame.new(data.From - Vector3.new(0, 2.8, 0)), { Radius = 6, Layers = 2, Color = pal.Light, Color2 = pal.Main, Ground = true, Particles = 0.5, Width = 0.3 })
			-- Streak trail while airborne.
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, 1, 0)
			a0.Parent = root
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -1, 0)
			a1.Parent = root
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Color = ColorSequence.new(pal.Light, pal.Second)
			trail.LightEmission = 0.8
			trail.Lifetime = 0.25
			trail.Transparency = NumberSequence.new(0.2, 1)
			trail.Parent = root
			Debris:AddItem(trail, (data.Time or 0.36) + 0.3)
			Debris:AddItem(a0, (data.Time or 0.36) + 0.3)
			Debris:AddItem(a1, (data.Time or 0.36) + 0.3)
			task.delay(data.Time or 0.36, function()
				trail.Enabled = false
			end)
		elseif data.Phase == "Land" then
			if character and not dinos[character] then
				TuskAnimation.play(character, "DiegoLand")
			end
			local pos = data.Position
			TuskVFX.CreateImpact(pos - Vector3.new(0, 2.5, 0), Vector3.new(0, 1, 0), { Size = 1.4, Radius = data.Radius or 6, Layers = 2, Color = pal.Main, Color2 = pal.Light, Sound = sounds.NailImpact, Pitch = 0.7 })
			TuskVFX.CreateGroundCracks(pos, { Radius = (data.Radius or 6) * 0.9, Count = 6, Color = pal.Main, Duration = 1.4 })
			if data.Hit then
				chomp(pos + (data.Direction or Vector3.new(0, 0, -1)) * 2 + Vector3.new(0, 0.5, 0), data.Direction, 1.3)
				VFXLib.sound(sounds.Hit, pos, 0.8, 0.8)
			end
			CameraFX.shakeAt(pos, data.Hit and 0.7 or 0.4, 50)
		end
	elseif data.Move == "DinoInfection" and data.Phase == "ThrallBite" then
		local t = data.Target and thralls[data.Target]
		if t then
			t.Jaw = 1
			t.Lunge = 1
		end
		chomp(data.Position + Vector3.new(0, 0.5, 0), data.Direction, 1.1)
		VFXLib.sound(sounds.Hit, data.Position, 0.6, 0.85)
	elseif data.Move == "DinoInfection" and data.Phase == "Command" then
		-- "Sic 'em": a blue target mark on the prey, the dinosaur roars.
		local t = data.Target and thralls[data.Target]
		if t then
			t.Jaw = 1
		end
		TuskVFX.CreateImpactStar(data.Position + Vector3.new(0, 1, 0), { Size = 5, Rays = 8, Color = SLASH, Color2 = SLASH_LIGHT, Duration = 0.35 })
		TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position - Vector3.new(0, 2.6, 0)), { Radius = 5, Layers = 2, Color = SLASH, Color2 = SLASH_LIGHT, Ground = true, Particles = 0, Width = 0.3 })
		local thrallRoot = data.Target and data.Target:FindFirstChild("HumanoidRootPart")
		if thrallRoot then
			roarSound(thrallRoot.Position, 0.8)
		end
		if root then
			TuskAnimation.play(character, "D_M1_1") -- Diego points the claw
		end
	elseif data.Move == "DinoInfection" and (data.Phase == "Turn" or data.Phase == "Release") then
		-- Drawn by stepThralls from the DinoThrall attribute.
	elseif data.Move == "DinoInfection" then
		if data.Phase == "Startup" and root then
			if not dinoAction(character, "Bite") then
				TuskAnimation.play(character, "DiegoBite")
			end
			-- Teal venom gathers at the mouth.
			local mouth = root.Position + root.CFrame.LookVector * 1.4 + Vector3.new(0, 1.4, 0)
			VFXLib.flash(mouth, pal.Main, 3, 10, (data.Windup or 0.2) + 0.1)
			VFXLib.burst(mouth, { Count = 8, Color = pal.Light, Speed = 3, Lifetime = 0.3 })
		elseif data.Phase == "Hit" then
			local look = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
			chomp(data.Position + Vector3.new(0, 1, 0), look, data.Hit and 1.4 or 1)
			VFXLib.sound(sounds.Hit, data.Position, 0.7, 0.75)
			if data.Hit then
				-- Infection spores burst out of the bite.
				VFXLib.burst(data.Position, { Count = 24, Color = pal.Main, Speed = 16, Lifetime = 0.7, Drag = 3, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) }) })
				TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position), { Radius = 5, Layers = 2, Color = pal.Main, Color2 = pal.Second, Particles = 0, Width = 0.25, Duration = 0.4 })
				if Common.isLocal(character) then
					CameraFX.shake(0.4, 0.25)
				end
			end
		end
	elseif data.Move == "ScaryMonsters" then
		if data.Phase == "Transform" and root then
			TuskAnimation.play(character, "DiegoTransform")
			TuskVFX.CreateMagicCircle(CFrame.new(root.Position - Vector3.new(0, 2.9, 0)), { Radius = 7, Color = pal.Main, Color2 = pal.Second, Duration = (data.Duration or 0.5) + 0.3, RotationSpeed = 3, Points = 6 })
			VFXLib.sound(sounds.AwakeningBuild, root, 0.7, 0.8)
			-- Scales flicker over the body before the change.
			VFXLib.burst(root.Position, { Count = 18, Color = pal.Main, Speed = 4, Lifetime = 0.5, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }) })
		end
		-- "Revert" is handled by stepDinos when the DinoMode attribute goes away.
	end
end

---------------------------------------------------------------------------
-- RAPTOR PACK (ultimate)
---------------------------------------------------------------------------
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundAt(pos)
	local ignore = { VFXLib.Folder }
	for _, player in ipairs(Fighters.list()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	groundParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), groundParams)
	return hit and hit.Position or pos
end

local function endRaptor(id, position)
	local r = pack[id]
	if not r then
		return
	end
	pack[id] = nil
	local pos = position or r.Pos
	VFXLib.burst(pos + Vector3.new(0, 2, 0), { Count = 16, Color = pal.Main, Speed = 16, Lifetime = 0.5 })
	VFXLib.burst(pos, { Count = 6, Texture = VFXLib.Textures.Smoke, Color = Color3.fromRGB(200, 180, 140), LightEmission = 0, Speed = 8, Lifetime = 0.8 })
	local rig = r.Rig
	VFXLib.animate(0.3, function(a)
		rig:SetTransparency(a)
	end, function()
		rig:Destroy()
	end)
end

local function stepPack(dt)
	local now = os.clock()
	for id, r in pairs(pack) do
		r.Traveled = math.min(r.Traveled + r.Speed * dt, r.Range)
		local flat = r.Origin + r.Direction * r.Traveled
		-- Follow the ground a few times a second (cheap).
		r.NextGround = r.NextGround - dt
		if r.NextGround <= 0 then
			r.NextGround = 0.1
			r.GroundY = groundAt(flat).Y
		end
		r.Pos = Vector3.new(flat.X, r.GroundY, flat.Z)
		r.Phase = r.Phase + dt * 15
		r.Jaw = r.Jaw * math.exp(-dt * 6)
		r.Rig:Pose(CFrame.lookAt(r.Pos, r.Pos + r.Direction), { Time = now, Phase = r.Phase, Speed = 1, Jaw = math.max(r.Jaw, 0.25 + math.sin(now * 9 + r.Seed) * 0.2), Lunge = r.Jaw * 0.6 })
		if now > r.Expire then
			endRaptor(id)
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Roar" and root then
		local w = data.Windup or 1.2
		if not dinoAction(character, "Roar", w * 0.8) then
			TuskAnimation.play(character, "DiegoRoar")
		end
		local near = Common.isLocal(character) or TuskVFX.IsNear(root.Position, 90)
		if near then
			TuskVFX.ScreenTint(w, { Brightness = -0.12, Saturation = -0.2, Contrast = 0.2, Tint = Color3.fromRGB(200, 255, 240), Release = 0.1 })
		end
		TuskVFX.CreateMagicCircle(CFrame.new(root.Position - Vector3.new(0, 2.9, 0)), { Radius = data.Radius or 16, Color = pal.Main, Color2 = pal.Second, Duration = w + 0.3, RotationSpeed = 1.5, Points = 7 })
		-- The roar: rings of sound blasting out from the mouth.
		task.delay(w * 0.35, function()
			if not root.Parent then
				return
			end
			roarSound(root.Position, 0.5)
			local mouth = root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 2, 0)
			for i = 1, 4 do
				task.delay(i * 0.07, function()
					local axis = CFrame.lookAt(mouth, mouth + root.CFrame.LookVector) * CFrame.Angles(math.pi / 2, 0, 0)
					TuskVFX.CreateRotationalShockwave(axis * CFrame.new(0, -i * 1.5, 0), { Radius = 3 + i * 2.5, Layers = 1, Color = i % 2 == 1 and pal.Light or pal.Main, Color2 = pal.Main, Particles = 0, Width = 0.35, Duration = 0.35, Spin = 0 })
				end)
			end
			TuskVFX.CreateRotationalShockwave(CFrame.new(root.Position - Vector3.new(0, 2.8, 0)), { Radius = data.Radius or 16, Layers = 3, Color = pal.Main, Color2 = pal.Light, Ground = true, Particles = 1.5, Width = 0.6 })
			TuskVFX.CreateDistortion(mouth, { Radius = 6, Duration = 0.5 })
			CameraFX.shakeAt(root.Position, 1, 80)
			if near then
				CameraFX.impactFrame(pal.Light)
			end
		end)
	elseif data.Phase == "Release" then
		local count = 0
		for _, info in ipairs(data.Raptors or {}) do
			count = count + 1
			local rig = RaptorModel.build(0.75, { Lite = true })
			rig.Model.Parent = VFXLib.Folder
			pack[info.Id] = {
				Rig = rig,
				Origin = info.Origin,
				Direction = info.Direction,
				Pos = info.Origin,
				GroundY = info.Origin.Y,
				NextGround = 0,
				Speed = data.Speed or 48,
				Range = data.Range or 75,
				Traveled = 0,
				Phase = math.random() * 6,
				Seed = math.random() * 10,
				Jaw = 1,
				Expire = os.clock() + (data.Range or 75) / (data.Speed or 48) + 1,
			}
			-- Each raptor bursts out of the ground.
			VFXLib.burst(info.Origin, { Count = 8, Texture = VFXLib.Textures.Smoke, Color = Color3.fromRGB(200, 180, 140), LightEmission = 0, Speed = 12, Lifetime = 0.7 })
			TuskVFX.CreateImpactStar(info.Origin + Vector3.new(0, 2, 0), { Size = 4, Rays = 6, Color = pal.Main, Color2 = WHITE, Duration = 0.25 })
		end
		if root then
			VFXLib.sound(sounds.AwakeningBurst, root.Position, 0.8, 0.7)
		end
		if Common.isLocal(character) then
			CameraFX.speedLines(0.5, pal.Light)
			CameraFX.fovPunch(14, 0.5)
		end
	elseif data.Phase == "RaptorBite" then
		local r = pack[data.Id]
		if r then
			r.Jaw = 1
		end
		chomp(data.Position + Vector3.new(0, 0.5, 0), r and r.Direction, 1.2)
		VFXLib.sound(sounds.Hit, data.Position, 0.7, 0.8)
		CameraFX.shakeAt(data.Position, 0.4, 40)
	elseif data.Phase == "RaptorEnd" then
		endRaptor(data.Id, data.Position)
	end
end

function Diego.handle(name, data)
	if name == "M1" then
		onM1(data)
	elseif name == "M1Finisher" then
		Common.finisher(data, Common.palette(6))
		local look = data.Character and Common.rootOf(data.Character)
		chomp(data.Position + Vector3.new(0, 0.5, 0), look and look.CFrame.LookVector, 1.4)
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

local slowTimer = 0
function Diego.step(dt)
	dt = dt or 1 / 60
	stepDinos(dt)
	stepThralls(dt)
	stepPack(dt)
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
		stepInfected()
		stepVision()
	end
end

return Diego
