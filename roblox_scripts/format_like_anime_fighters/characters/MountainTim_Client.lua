--[[
	MountainTim_Client  (ModuleScript)
	PUT IT IN: ReplicatedStorage > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Mountain Tim: Oh! Lonesome Me.
	Its other half is MountainTim_Server in ServerScriptService > SpinCharacters.
	Loaded by Spin_Client: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: MountainTimVFX
-- ======================================================================
__modules["MountainTimVFX"] = function()
--[[
	TuskActVFX.MountainTimVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.MountainTimVFX)

	Client visuals for Mountain Tim / OH! LONESOME ME (his body splits into
	pieces that slide along his lasso rope). Blocky like the rest of the game.
	  * M1: jabs, a rope whip, an overhead rope slam
	  * LASSO SNARE: a spinning loop on a rope; a catch wraps the loop round
	    the enemy and the rope drags them in
	  * ROPE SPLIT: his body vanishes and blocky pieces (in his own colours)
	    slide along a rope to the far end, then he reappears there
	  * SPLIT PUNCH: his fist flies off along the rope, punching down a line
	  * LONESOME ROUNDUP: he spins the lasso overhead, ropes shoot to everyone
	    nearby, his pieces ride the ropes in, then a rope slam
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Net = __require("Net")
local VFXLib = __require("VFXLib")
local CameraFX = __require("CameraFX")
local TuskVFX = __require("TuskVFX")
local TuskAnimation = __require("TuskAnimation")
local Common = __require("TuskActCommon")
local Fighters = __require("Fighters")
local Players = game:GetService("Players")

local TimVFX = {}
local ACT = 9
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local ROPE = Color3.fromRGB(205, 170, 110)
local ROPE_DARK = Color3.fromRGB(150, 115, 70)

local lassos = {} -- [projectile id] = flying lasso
local lines = {} -- ropes held between two moving points
local stanced = {}

---------------------------------------------------------------------------
-- Rope pieces
---------------------------------------------------------------------------
local function newRope(width)
	return VFXLib.part({ Size = Vector3.new(width or 0.14, width or 0.14, 1), Color = ROPE, Material = Enum.Material.Fabric })
end

local function setRope(rope, a, b)
	local d = (b - a).Magnitude
	if d < 0.05 then
		rope.Transparency = 1
		return
	end
	rope.Transparency = 0
	local w = rope.Size.X
	rope.Size = Vector3.new(w, w, d)
	rope.CFrame = CFrame.lookAt((a + b) / 2, b)
end

-- The lasso loop: a stepped ring of rope.
local function newLoop(radius)
	local m = Instance.new("Model")
	m.Name = "Lasso"
	m.Parent = VFXLib.Folder
	local first
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local p = VFXLib.part({ Size = Vector3.new(0.16, 0.16, radius * 0.66), Color = i % 2 == 0 and ROPE or ROPE_DARK, Material = Enum.Material.Fabric })
		p.CFrame = CFrame.new(math.cos(a) * radius, 0, math.sin(a) * radius) * CFrame.Angles(0, -a, 0)
		p.Parent = m
		first = first or p
	end
	local center = VFXLib.part({ Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1 })
	center.CFrame = CFrame.new()
	center.Parent = m
	m.PrimaryPart = center
	return m
end

local function handPos(character)
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	if hand then
		return hand.Position
	end
	local root = Common.rootOf(character)
	return root and (root.CFrame * CFrame.new(0.9, 0.4, -1)).Position
end

local function torsoPos(model)
	local part = model and (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model:FindFirstChild("HumanoidRootPart"))
	return part and part.Position
end

-- A rope between two moving points for `duration` seconds, with an optional
-- loop wrapped round the far end.
local function holdRope(getA, getB, duration, loopRadius)
	local entry = { GetA = getA, GetB = getB, Rope = newRope(0.15), Loop = loopRadius and newLoop(loopRadius) or nil, Expire = os.clock() + duration, T = 0 }
	table.insert(lines, entry)
	return entry
end

local function stepLines(dt)
	local now = os.clock()
	for i = #lines, 1, -1 do
		local e = lines[i]
		local a, b = e.GetA(), e.GetB()
		if now > e.Expire or not a or not b then
			table.remove(lines, i)
			e.Rope:Destroy()
			if e.Loop then
				e.Loop:Destroy()
			end
		else
			e.T = e.T + dt
			-- A taut rope sags a little and thrums.
			setRope(e.Rope, a, b + Vector3.new(0, math.sin(e.T * 30) * 0.05, 0))
			if e.Loop then
				e.Loop:PivotTo(CFrame.new(b) * CFrame.Angles(0, e.T * 3, 0))
			end
		end
	end
end

---------------------------------------------------------------------------
-- Body pieces (Oh! Lonesome Me)
---------------------------------------------------------------------------
local hiddenUntil = {} -- [character] = os.clock() after which it must be visible again

local function hideBody(character, hidden, seconds)
	hiddenUntil[character] = hidden and (os.clock() + (seconds or 0.4) + 0.6) or nil
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		elseif d:IsA("Decal") then
			d.Transparency = hidden and 1 or 0
		end
	end
end

-- Blocky pieces cut from the character, in its own colours.
local function bodyPieces(character)
	local pieces = {}
	local names = {
		{ "Head", Vector3.new(1, 1, 1) }, { "UpperTorso", Vector3.new(1.8, 1.4, 1) }, { "Torso", Vector3.new(1.8, 1.8, 1) }, { "LowerTorso", Vector3.new(1.6, 0.6, 1) },
		{ "RightUpperArm", Vector3.new(0.8, 1.1, 0.8) }, { "LeftUpperArm", Vector3.new(0.8, 1.1, 0.8) }, { "Right Arm", Vector3.new(0.9, 1.8, 0.9) }, { "Left Arm", Vector3.new(0.9, 1.8, 0.9) },
		{ "RightUpperLeg", Vector3.new(0.8, 1.2, 0.8) }, { "LeftUpperLeg", Vector3.new(0.8, 1.2, 0.8) }, { "Right Leg", Vector3.new(0.9, 1.8, 0.9) }, { "Left Leg", Vector3.new(0.9, 1.8, 0.9) },
	}
	for _, n in ipairs(names) do
		local src = character:FindFirstChild(n[1])
		if src and src:IsA("BasePart") then
			local p = VFXLib.part({ Size = n[2], Color = src.Color, Material = Enum.Material.SmoothPlastic })
			table.insert(pieces, p)
		end
	end
	return pieces
end

---------------------------------------------------------------------------
-- Lasso projectile (server Kind "TimLasso")
---------------------------------------------------------------------------
local function spawnLasso(data)
	local owner
	local p = data.OwnerId and Players:GetPlayerByUserId(data.OwnerId)
	owner = p and p.Character
	lassos[data.Id] = {
		Loop = newLoop(1.2),
		Rope = newRope(0.14),
		Owner = owner,
		Origin = data.Origin,
		Direction = data.Direction,
		Speed = data.Speed,
		Range = data.Range,
		ServerTime = data.ServerTime,
		Spin = 0,
		Expire = os.clock() + data.Range / math.max(data.Speed, 1) + 1,
	}
end

local function removeLasso(v)
	v.Loop:Destroy()
	v.Rope:Destroy()
end

local function endLasso(data)
	local v = lassos[data.Id]
	if not v then
		return
	end
	lassos[data.Id] = nil
	removeLasso(v)
	if not data.HitCharacter then
		-- Miss: the loop flops and the rope snaps back.
		local loop, rope = newLoop(1.2), newRope(0.14)
		local from = data.Position
		VFXLib.animate(0.3, function(a)
			local h = v.Owner and v.Owner.Parent and handPos(v.Owner)
			if not h then
				return
			end
			local p = from:Lerp(h, a * a)
			loop:PivotTo(CFrame.new(p) * CFrame.Angles(a * 2, a * 6, 0))
			loop:ScaleTo(math.max(0.1, 1 - a))
			setRope(rope, h, p)
		end, function()
			loop:Destroy()
			rope:Destroy()
		end)
	end
end

local function stepLassos(dt)
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for id, v in pairs(lassos) do
		local distance = math.min(v.Speed * (serverNow - v.ServerTime), v.Range)
		local pos = v.Origin + v.Direction * math.max(distance, 0)
		v.Spin = v.Spin + dt * 14
		v.Loop:PivotTo(CFrame.lookAt(pos, pos + v.Direction) * CFrame.Angles(math.pi / 2, v.Spin, 0))
		local h = v.Owner and v.Owner.Parent and handPos(v.Owner)
		setRope(v.Rope, h or v.Origin, pos)
		if now > v.Expire then
			lassos[id] = nil
			removeLasso(v)
		end
	end
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
	TuskAnimation.play(character, "T_M1_" .. index)
	VFXLib.sound(sounds.Swing, root, 0.5, 1 + index * 0.06)
	if index <= 2 then
		Common.swipe(root, index == 1 and 1 or -1, index == 1 and pal.Main or pal.Light)
	elseif index == 3 then
		-- Rope whip: a crack of rope out in front.
		local rope = newRope(0.12)
		VFXLib.animate(0.25, function(a)
			local h = root.Parent and handPos(character)
			if not h then
				return
			end
			local reach = math.sin(a * math.pi) * 7
			local tip = (root.CFrame * CFrame.new(math.sin(a * math.pi * 2) * 2.5, 0.5, -reach)).Position
			setRope(rope, h, tip)
		end, function()
			rope:Destroy()
		end)
		TuskVFX.CreateCrescent(root.CFrame * CFrame.new(0, 0.6, -2.6), { Radius = 3.4, Width = 0.25, Color = ROPE, Color2 = pal.Light, Sweep = 2.2, Duration = 0.22 })
		VFXLib.burst((root.CFrame * CFrame.new(0, 0.6, -6)).Position, { Count = 6, Color = pal.Light, Speed = 16, Lifetime = 0.2 })
	end
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "LassoSnare" then
		if phase == "Startup" and character then
			TuskAnimation.play(character, "TimLassoThrow")
			-- The loop whirls over his head before the throw.
			if root then
				local loop = newLoop(1.3)
				VFXLib.animate(data.Startup or 0.28, function(a)
					if root.Parent then
						loop:PivotTo(root.CFrame * CFrame.new(0.6, 3.2, 0) * CFrame.Angles(0, a * 14, 0))
					end
				end, function()
					loop:Destroy()
				end)
			end
		elseif phase == "Snag" and data.Target then
			TuskAnimation.play(character, "TimReel")
			holdRope(function()
				return character.Parent and handPos(character)
			end, function()
				return data.Target.Parent and torsoPos(data.Target)
			end, (data.Duration or 0.6) + 0.15, 1.3)
			local tp = torsoPos(data.Target)
			if tp then
				VFXLib.burst(tp, { Count = 12, Color = ROPE, Speed = 18, Lifetime = 0.3 })
				TuskVFX.CreateImpactStar(tp, { Size = 4, Rays = 7, Color = pal.Main, Color2 = Color3.new(1, 1, 1), Duration = 0.2 })
			end
			VFXLib.sound(sounds.Hit, root or data.Target, 0.6, 1)
		end
	elseif move == "RopeSplit" then
		if phase == "Startup" and character then
			TuskAnimation.play(character, "TimSplit")
		elseif phase == "Split" and character then
			-- He comes apart: the body vanishes, the pieces ride a rope to the end.
			local from, to = data.From, data.To
			local travel = data.Travel or 0.35
			hideBody(character, true, travel)
			local rope = newRope(0.12)
			setRope(rope, from + Vector3.new(0, 0.5, 0), to + Vector3.new(0, 0.5, 0))
			local pieces = bodyPieces(character)
			VFXLib.burst(from, { Count = 14, Color = pal.Main, Speed = 16, Lifetime = 0.35 })
			VFXLib.animate(travel, function(a)
				for i, p in ipairs(pieces) do
					local k = math.clamp(a * 1.4 - (i - 1) * 0.04, 0, 1)
					local pos = from:Lerp(to, k) + Vector3.new(0, 0.6 + math.sin(k * math.pi) * (1 + (i % 3) * 0.4), 0)
					p.CFrame = CFrame.new(pos) * CFrame.Angles(k * 6 + i, k * 4, 0)
				end
			end, function()
				for _, p in ipairs(pieces) do
					p:Destroy()
				end
				task.delay(0.15, function()
					rope:Destroy()
				end)
			end)
			if Common.isLocal(character) then
				CameraFX.fovPunch(6, 0.25)
			end
		elseif phase == "Rejoin" and character then
			hideBody(character, false)
			local pos = data.Position
			VFXLib.burst(pos, { Count = 16, Color = pal.Main, Speed = 18, Lifetime = 0.35 })
			TuskVFX.CreateRotationalShockwave(CFrame.new(pos - Vector3.new(0, 2.5, 0)), { Radius = 4, Layers = 1, Color = pal.Main, Color2 = ROPE, Ground = true, Particles = 0.4, Width = 0.15, Duration = 0.3 })
		end
	elseif move == "SplitPunch" then
		if phase == "Startup" and character then
			TuskAnimation.play(character, "TimPunch")
		elseif phase == "Fly" and root then
			-- The fist comes off and rides the rope out and back.
			local skin = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
			local fist = VFXLib.part({ Size = Vector3.new(0.9, 0.9, 1.1), Color = skin and skin.Color or pal.Main, Material = Enum.Material.SmoothPlastic })
			local rope = newRope(0.12)
			local range = data.Range or 26
			local total = (data.Hits or 3) * (data.HitEvery or 0.12) + 0.2
			local hitEvery = data.HitEvery or 0.12
			local nextBurst = 0
			VFXLib.animate(total, function(a, dt)
				local h = root.Parent and handPos(character)
				if not h then
					return
				end
				local out = math.sin(math.min(a, 1) * math.pi)
				local dir = data.Direction
				local pos = h + dir * range * out + Vector3.new(0, math.sin(a * 30) * 0.2, 0)
				fist.CFrame = CFrame.lookAt(pos, pos + dir)
				setRope(rope, h, pos)
				nextBurst = nextBurst - (dt or 1 / 60)
				if nextBurst <= 0 and out > 0.3 then
					nextBurst = hitEvery
					TuskVFX.CreateImpactStar(pos, { Size = 3, Rays = 6, Color = pal.Main, Color2 = Color3.new(1, 1, 1), Duration = 0.15 })
					VFXLib.sound(sounds.Hit, pos, 0.4, 1.2)
				end
			end, function()
				fist:Destroy()
				rope:Destroy()
			end)
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Start" then
		TuskAnimation.play(character, "TimRoundup")
		if root then
			-- A huge loop spinning overhead, growing.
			local loop = newLoop(1.2)
			VFXLib.animate(data.Windup or 0.9, function(a)
				if root.Parent then
					loop:PivotTo(root.CFrame * CFrame.new(0, 4.2, 0) * CFrame.Angles(0, a * 22, 0))
					loop:ScaleTo(1 + a * 2)
				end
			end, function()
				loop:Destroy()
			end)
			VFXLib.flash(root.Position, pal.Main, 3, 25, 0.4)
		end
		if Common.isLocal(character) then
			CameraFX.fovPunch(-6, 0.4)
		end
	elseif data.Phase == "Rope" then
		local hold = (data.RideHits or 4) * (data.RideEvery or 0.18) + (data.ReelTime or 0.8) + 0.1
		for _, target in ipairs(data.Targets or {}) do
			holdRope(function()
				return character.Parent and handPos(character)
			end, function()
				return target.Parent and torsoPos(target)
			end, hold, 1.4)
			-- His pieces ride the rope in, again and again.
			local pieces = bodyPieces(character)
			VFXLib.animate(hold - 0.1, function(a)
				local h = character.Parent and handPos(character)
				local t = target.Parent and torsoPos(target)
				if not h or not t then
					return
				end
				for i, p in ipairs(pieces) do
					local k = ((a * 4) + i * 0.17) % 1
					p.CFrame = CFrame.new(h:Lerp(t, k) + Vector3.new(0, math.sin(k * math.pi) * 0.8, 0)) * CFrame.Angles(k * 8, i, 0)
				end
			end, function()
				for _, p in ipairs(pieces) do
					p:Destroy()
				end
			end)
		end
		if root then
			VFXLib.sound(sounds.Hit, root, 0.8, 0.9)
		end
		if Common.isLocal(character) then
			CameraFX.shake(0.5, hold)
		end
	elseif data.Phase == "Slam" then
		Common.finisher({ Character = character, Position = data.Position, Radius = data.Radius, Hit = true }, pal, { Size = 1.6, Layers = 3, Shake = 0.9 })
		VFXLib.burst(data.Position, { Count = 24, Color = ROPE, Speed = 30, Lifetime = 0.5 })
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
				TuskAnimation.hold(character, "TimStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "TimStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
	-- Never leave anyone invisible (e.g. if a Rejoin event was missed).
	local now = os.clock()
	for character, untilT in pairs(hiddenUntil) do
		if now > untilT and not character:GetAttribute("RopeSplit") then
			hideBody(character, false)
		end
	end
end

function TimVFX.handle(name, data)
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
function TimVFX.step(dt)
	dt = dt or 1 / 60
	stepLassos(dt)
	stepLines(dt)
	slowTimer = slowTimer + dt
	if slowTimer > 0.2 then
		slowTimer = 0
		stepStance()
	end
end

Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
	if typeof(data) ~= "table" or data.Kind ~= "TimLasso" then
		return
	end
	if name == "ProjectileSpawn" then
		spawnLasso(data)
	elseif name == "ProjectileEnd" then
		endLasso(data)
	end
end)

return TimVFX
end
end
