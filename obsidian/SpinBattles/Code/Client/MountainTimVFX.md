---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# MountainTimVFX

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `MountainTimVFX` (capitals matter) |

**What it does:** Client visuals for Mountain Tim / OH! LONESOME ME: bodies come apart into pieces strung along his lasso rope. Models: a BRAIDED rope (twisted two-tone segments) that sags under its weight a thick lasso LOOP with a honda knot and a tail BODY PIECES: real copies of the character's own parts (with the outfit bits welded to them, e.g. his hat rides on his head) strung on the rope Moves: LASSO SNARE: the loop whirls overhead and flies; a catch cinches the loop round them and their body splits apart along the rope, then snaps back together as they're dragged in SPLIT DODGE: he bursts into pieces hanging on a ring of rope. Attacked: the pieces zip along a rope to behind the attacker and reform with a rope-slam. Not attacked: the pieces slide forward along the rope. SPLIT BARRAGE: his arm comes apart (shoulder, forearm, fist on the rope) and jabs down a line, then reels back in LONESOME ROUNDUP: a giant lasso spins overhead while a rope ring tightens on the ground, ropes shoot out, everyone roped is split apart, his pieces ride the ropes in, then a rope slam

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **MountainTimVFX**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.MountainTimVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.MountainTimVFX)

	Client visuals for Mountain Tim / OH! LONESOME ME: bodies come apart into
	pieces strung along his lasso rope.
	Models:
	  * a BRAIDED rope (twisted two-tone segments) that sags under its weight
	  * a thick lasso LOOP with a honda knot and a tail
	  * BODY PIECES: real copies of the character's own parts (with the outfit
	    bits welded to them, e.g. his hat rides on his head) strung on the rope
	Moves:
	  * LASSO SNARE: the loop whirls overhead and flies; a catch cinches the
	    loop round them and their body splits apart along the rope, then snaps
	    back together as they're dragged in
	  * SPLIT DODGE: he bursts into pieces hanging on a ring of rope. Attacked:
	    the pieces zip along a rope to behind the attacker and reform with a
	    rope-slam. Not attacked: the pieces slide forward along the rope.
	  * SPLIT BARRAGE: his arm comes apart (shoulder, forearm, fist on the
	    rope) and jabs down a line, then reels back in
	  * LONESOME ROUNDUP: a giant lasso spins overhead while a rope ring
	    tightens on the ground, ropes shoot out, everyone roped is split apart,
	    his pieces ride the ropes in, then a rope slam
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local Common = require(script.Parent.Parent.TuskActCommon)
local Fighters = require(script.Parent.Parent.Fighters)

local TimVFX = {}
local ACT = 9
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local ROPE = Color3.fromRGB(212, 176, 116)
local ROPE_DARK = Color3.fromRGB(156, 120, 74)
local KNOT = Color3.fromRGB(120, 88, 52)

local lassos = {} -- [projectile id] = flying lasso
local lines = {} -- ropes held between two moving points
local scattered = {} -- [character] = his pieces during Split Dodge
local stanced = {}
local hiddenUntil = {} -- [character] = os.clock() after which it must be visible again

---------------------------------------------------------------------------
-- Braided rope: twisted two-tone segments along a sagging curve
---------------------------------------------------------------------------
local function newRope(width, segments)
	local rope = { Parts = {}, Width = width or 0.16 }
	for i = 1, segments or 12 do
		rope.Parts[i] = VFXLib.part({ Size = Vector3.new(rope.Width, rope.Width, 1), Color = i % 2 == 0 and ROPE or ROPE_DARK, Material = Enum.Material.Fabric })
	end
	return rope
end

local function setRope(rope, a, b, sag)
	local d = (b - a).Magnitude
	local n = #rope.Parts
	sag = sag or math.min(d * 0.05, 1.4)
	local function at(t)
		return a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
	end
	for i, p in ipairs(rope.Parts) do
		if d < 0.05 then
			p.Transparency = 1
		else
			p.Transparency = 0
			local p0, p1 = at((i - 1) / n), at(i / n)
			local len = (p1 - p0).Magnitude
			p.Size = Vector3.new(rope.Width, rope.Width, len + 0.03)
			-- Each segment is turned a little more: reads as a braid.
			p.CFrame = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, 0, i * 0.7)
		end
	end
end

local function destroyRope(rope)
	for _, p in ipairs(rope.Parts) do
		p:Destroy()
	end
end

-- Lasso loop: a thick ring of rope with a honda knot and a short tail.
local function newLoop(radius)
	local m = Instance.new("Model")
	m.Name = "Lasso"
	m.Parent = VFXLib.Folder
	local n = 14
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local seg = VFXLib.part({ Size = Vector3.new(0.22, 0.22, radius * 2 * math.pi / n + 0.06), Color = i % 2 == 0 and ROPE or ROPE_DARK, Material = Enum.Material.Fabric })
		seg.CFrame = CFrame.new(math.cos(a) * radius, 0, math.sin(a) * radius) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, i * 0.7)
		seg.Parent = m
	end
	local knot = VFXLib.part({ Size = Vector3.new(0.42, 0.34, 0.5), Color = KNOT, Material = Enum.Material.Fabric })
	knot.CFrame = CFrame.new(radius, 0, 0)
	knot.Parent = m
	local tail = VFXLib.part({ Size = Vector3.new(0.18, 0.18, 0.7), Color = ROPE, Material = Enum.Material.Fabric })
	tail.CFrame = CFrame.new(radius + 0.4, -0.1, 0.3) * CFrame.Angles(0.3, 0.6, 0)
	tail.Parent = m
	local center = VFXLib.part({ Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1 })
	center.CFrame = CFrame.new()
	center.Parent = m
	m.PrimaryPart = center
	return m
end

---------------------------------------------------------------------------
-- Body pieces: real copies of a character's parts (plus outfit bits)
---------------------------------------------------------------------------
local PIECES = {
	"Head", "UpperTorso", "LowerTorso", "Torso",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"Right Arm", "Left Arm", "Right Leg", "Left Leg",
}
local ARM = { "RightUpperArm", "RightLowerArm", "RightHand", "Right Arm" }

local function copyPart(src)
	local ok, copy = pcall(function()
		local was = src.Archivable
		src.Archivable = true
		local c = src:Clone()
		src.Archivable = was
		return c
	end)
	if not ok or not copy then
		return nil
	end
	for _, d in ipairs(copy:GetChildren()) do
		if d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("Attachment") or d:IsA("LuaSourceContainer") or d:IsA("Sound") then
			d:Destroy()
		end
	end
	copy.Anchored = true
	copy.CanCollide = false
	copy.CanQuery = false
	copy.CanTouch = false
	copy.LocalTransparencyModifier = 0
	copy.Parent = VFXLib.Folder
	return copy
end

-- Outfit bits (the hat, the vest...) welded to `src` travel with its piece.
local function weldedTo(character, src)
	local list = {}
	for _, d in ipairs(character:GetDescendants()) do
		-- Outfit bits (WeldConstraint from the part) and accessories (hats,
		-- hair: a weld between the accessory's Handle and the part).
		if d:IsA("WeldConstraint") and d.Part0 == src and d.Part1 and d.Part1.Parent and d.Part1.Parent ~= character then
			table.insert(list, d.Part1)
		elseif d:IsA("JointInstance") and d.Parent and d.Parent.Name == "Handle" and d.Parent.Parent and d.Parent.Parent:IsA("Accessory") then
			if d.Part1 == src or d.Part0 == src then
				table.insert(list, d.Parent)
			end
		end
	end
	return list
end

local function cutPieces(character, names)
	local root = Common.rootOf(character)
	if not root then
		return {}
	end
	local pieces = {}
	for _, name in ipairs(names or PIECES) do
		local src = character:FindFirstChild(name)
		if src and src:IsA("BasePart") then
			local main = copyPart(src)
			if main then
				local piece = { Main = main, Extras = {}, Offset = root.CFrame:Inverse() * src.CFrame }
				for _, bit in ipairs(weldedTo(character, src)) do
					local c = copyPart(bit)
					if c then
						table.insert(piece.Extras, { Part = c, Offset = src.CFrame:Inverse() * bit.CFrame })
					end
				end
				table.insert(pieces, piece)
			end
		end
	end
	return pieces
end

local function placePiece(piece, cf)
	piece.Main.CFrame = cf
	for _, e in ipairs(piece.Extras) do
		e.Part.CFrame = cf * e.Offset
	end
end

local function dropPieces(pieces)
	for _, piece in ipairs(pieces) do
		piece.Main:Destroy()
		for _, e in ipairs(piece.Extras) do
			e.Part:Destroy()
		end
	end
end

-- Hide a character (or just some of its parts) on this client. Remembers
-- what it hid and puts exactly that back (faces an outfit hid stay hidden),
-- and keeps it hidden every frame so the camera can't un-hide it.
local hidden = {} -- [character] = { Parts = { [part] = true }, Decals = { [decal] = original } }

local function partSet(character, onlyNames)
	local list = {}
	local set
	if onlyNames then
		set = {}
		for _, n in ipairs(onlyNames) do
			set[n] = true
		end
	end
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			local own = set == nil or set[d.Name]
			if not own then
				-- outfit bits and accessories attached to a hidden part hide with it
				for _, w in ipairs(d:GetChildren()) do
					if (w:IsA("WeldConstraint") or w:IsA("JointInstance")) and ((w.Part0 and set[w.Part0.Name]) or (w.Part1 and set[w.Part1.Name])) then
						own = true
					end
				end
			end
			if own then
				table.insert(list, d)
			end
		end
	end
	return list
end

local function hideBody(character, hide, seconds, onlyNames)
	if not onlyNames then
		hiddenUntil[character] = hide and (os.clock() + (seconds or 0.5) + 0.8) or nil
	end
	local entry = hidden[character]
	if hide then
		entry = entry or { Parts = {}, Decals = {} }
		hidden[character] = entry
		for _, part in ipairs(partSet(character, onlyNames)) do
			entry.Parts[part] = true
			part.LocalTransparencyModifier = 1
		end
		if not onlyNames then
			for _, d in ipairs(character:GetDescendants()) do
				if d:IsA("Decal") and entry.Decals[d] == nil then
					entry.Decals[d] = d.Transparency
					d.Transparency = 1
				end
			end
		end
		return
	end
	if not entry then
		return
	end
	if onlyNames then
		for _, part in ipairs(partSet(character, onlyNames)) do
			entry.Parts[part] = nil
			part.LocalTransparencyModifier = 0
		end
		if next(entry.Parts) == nil and next(entry.Decals) == nil then
			hidden[character] = nil
		end
		return
	end
	hidden[character] = nil
	for part in pairs(entry.Parts) do
		if part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end
	for decal, original in pairs(entry.Decals) do
		if decal.Parent then
			decal.Transparency = original
		end
	end
end

-- Runs after the camera each frame: keeps hidden parts hidden.
local function enforceHidden()
	for character, entry in pairs(hidden) do
		if not character.Parent then
			hidden[character] = nil
		else
			for part in pairs(entry.Parts) do
				if part.Parent and part.LocalTransparencyModifier ~= 1 then
					part.LocalTransparencyModifier = 1
				end
			end
		end
	end
end

-- Oh! Lonesome Me on a victim: their body spreads apart along the rope
-- toward `getAnchor()` (Tim's hand), wobbles, then snaps back together.
local function splitApart(model, getAnchor, duration)
	local root = Common.rootOf(model)
	if not root then
		return
	end
	local pieces = cutPieces(model)
	if #pieces == 0 then
		return
	end
	hideBody(model, true, duration)
	local n = #pieces
	VFXLib.animate(duration, function(a)
		local r = Common.rootOf(model)
		if not r then
			return
		end
		local anchor = getAnchor() or (r.Position + r.CFrame.LookVector * 5)
		local toward = anchor - r.Position
		toward = toward.Magnitude > 0.1 and toward.Unit or r.CFrame.LookVector
		local spread = math.sin(math.min(a / 0.85, 1) * math.pi) * 4.5
		for i, piece in ipairs(pieces) do
			local t = (i - 1) / math.max(n - 1, 1)
			local wob = Vector3.new(math.sin(a * 20 + i), math.cos(a * 17 + i * 2), 0) * 0.25 * spread / 4.5
			local cf = r.CFrame * piece.Offset
			placePiece(piece, cf + toward * spread * t + wob)
		end
	end, function()
		dropPieces(pieces)
		if model.Parent then
			hideBody(model, false)
			local rr = Common.rootOf(model)
			if rr then
				VFXLib.burst(rr.Position, { Count = 8, Color = ROPE, Speed = 10, Lifetime = 0.25 })
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
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

local function holdRope(getA, getB, duration, loopRadius)
	local entry = { GetA = getA, GetB = getB, Rope = newRope(0.17), Loop = loopRadius and newLoop(loopRadius) or nil, Expire = os.clock() + duration, T = 0, Radius = loopRadius }
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
			destroyRope(e.Rope)
			if e.Loop then
				e.Loop:Destroy()
			end
		else
			e.T = e.T + dt
			-- Taut while it pulls: little sag, a thrum along it.
			setRope(e.Rope, a, b + Vector3.new(0, math.sin(e.T * 30) * 0.05, 0), 0.25)
			if e.Loop then
				-- The loop cinches tight round them.
				e.Loop:PivotTo(CFrame.new(b) * CFrame.Angles(0, e.T * 2, 0))
				e.Loop:ScaleTo(math.max(0.7, 1.3 - e.T * 2))
			end
		end
	end
end

---------------------------------------------------------------------------
-- Lasso projectile (server Kind "TimLasso")
---------------------------------------------------------------------------
local function spawnLasso(data)
	local p = data.OwnerId and Players:GetPlayerByUserId(data.OwnerId)
	lassos[data.Id] = {
		Loop = newLoop(1.3),
		Rope = newRope(0.16),
		Owner = (data.Visual and data.Visual.Character) or (p and p.Character),
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
	destroyRope(v.Rope)
end

local function endLasso(data)
	local v = lassos[data.Id]
	if not v then
		return
	end
	lassos[data.Id] = nil
	removeLasso(v)
	if not data.HitCharacter then
		-- Miss: the loop flops in the dirt and the rope snaps back.
		local loop, rope = newLoop(1.3), newRope(0.16)
		local from = data.Position
		VFXLib.burst(from, { Count = 6, Texture = VFXLib.Textures.Smoke, Color = Color3.fromRGB(210, 190, 150), LightEmission = 0, Speed = 6, Lifetime = 0.5 })
		VFXLib.animate(0.32, function(a)
			local h = v.Owner and v.Owner.Parent and handPos(v.Owner)
			if not h then
				return
			end
			local p = from:Lerp(h, a * a)
			loop:PivotTo(CFrame.new(p) * CFrame.Angles(a * 2, a * 6, 0))
			loop:ScaleTo(math.max(0.1, 1 - a))
			setRope(rope, h, p, 1.5 * (1 - a))
		end, function()
			loop:Destroy()
			destroyRope(rope)
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
		setRope(v.Rope, h or v.Origin, pos, 0.6)
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
		-- Rope whip: the rope cracks out in a curve and snaps.
		local rope = newRope(0.14, 10)
		VFXLib.animate(0.26, function(a)
			local h = root.Parent and handPos(character)
			if not h then
				return
			end
			local reach = math.sin(a * math.pi) * 7.5
			local tip = (root.CFrame * CFrame.new(math.sin(a * math.pi * 2) * 2.8, 0.5, -reach)).Position
			setRope(rope, h, tip, -0.6 * math.sin(a * math.pi))
		end, function()
			destroyRope(rope)
		end)
		TuskVFX.CreateCrescent(root.CFrame * CFrame.new(0, 0.6, -2.6), { Radius = 3.6, Width = 0.25, Color = ROPE, Color2 = pal.Light, Sweep = 2.2, Duration = 0.22 })
		task.delay(0.13, function()
			if root.Parent then
				local tip = (root.CFrame * CFrame.new(0, 0.6, -7)).Position
				TuskVFX.CreateImpactStar(tip, { Size = 2.4, Rays = 6, Color = pal.Light, Color2 = Color3.new(1, 1, 1), Duration = 0.12 })
			end
		end)
	elseif index == 4 then
		-- Lasso slam: the loop drops onto the spot in front and snaps shut.
		local spot = (root.CFrame * CFrame.new(0, -2.4, -3.6)).Position
		local loop = newLoop(2)
		VFXLib.animate(0.24, function(a)
			loop:PivotTo(CFrame.new(spot + Vector3.new(0, 3 * (1 - a), 0)) * CFrame.Angles(0, a * 3, 0))
			loop:ScaleTo(math.max(0.2, 1.2 - a * 0.9))
		end, function()
			loop:Destroy()
		end)
	end
end

-- SPLIT DODGE: the pieces hang on a slowly turning ring of rope.
local function scatter(character, window)
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local old = scattered[character]
	if old then
		dropPieces(old.Pieces)
		destroyRope(old.Ring)
	end
	local pieces = cutPieces(character)
	hideBody(character, true, window + 0.5)
	local entry = { Pieces = pieces, Ring = newRope(0.12, 16), Center = root.Position, Start = os.clock(), Window = window }
	scattered[character] = entry
	VFXLib.burst(root.Position, { Count = 16, Color = pal.Main, Speed = 18, Lifetime = 0.35 })
	VFXLib.sound(sounds.Swing, root, 0.6, 0.7)
	return entry
end

local function stepScattered()
	local now = os.clock()
	for character, e in pairs(scattered) do
		local t = now - e.Start
		local n = #e.Pieces
		local ringPoints = {}
		for i, piece in ipairs(e.Pieces) do
			local ang = (i - 1) / math.max(n, 1) * math.pi * 2 + t * 1.6
			local out = math.min(t / 0.15, 1)
			local r = 2.6 * out
			local pos = e.Center + Vector3.new(math.cos(ang) * r, (i % 4) * 0.7 - 0.6 + math.sin(t * 6 + i) * 0.2, math.sin(ang) * r)
			local home = (CFrame.new(e.Center) * piece.Offset)
			local cf = home:Lerp(CFrame.new(pos) * CFrame.Angles(t * 2 + i, t + i * 0.5, 0), out)
			placePiece(piece, cf)
			ringPoints[i] = cf.Position
		end
		-- One rope threaded through every piece.
		for k, p in ipairs(e.Ring.Parts) do
			local a = ringPoints[((k - 1) % math.max(n, 1)) + 1]
			local b = ringPoints[(k % math.max(n, 1)) + 1]
			if a and b and k <= n then
				local len = (b - a).Magnitude
				p.Transparency = 0
				p.Size = Vector3.new(0.12, 0.12, len)
				p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, 0, k * 0.7)
			elseif k > n then
				p.Transparency = 1
			end
		end
		if t > e.Window + 1 then
			-- (safety) nobody resolved it
			scattered[character] = nil
			dropPieces(e.Pieces)
			destroyRope(e.Ring)
			hideBody(character, false)
		end
	end
end

-- Pieces ride a rope from `from` to `to` over `travel`, then reform.
local function rideRope(character, pieces, from, to, travel, done)
	local rope = newRope(0.14, 14)
	setRope(rope, from + Vector3.new(0, 0.5, 0), to + Vector3.new(0, 0.5, 0), 0.4)
	local n = #pieces
	local startCFs = {}
	for i, piece in ipairs(pieces) do
		startCFs[i] = piece.Main.CFrame
	end
	VFXLib.animate(travel, function(a)
		for i, piece in ipairs(pieces) do
			local k = math.clamp(a * 1.5 - (i - 1) / math.max(n, 1) * 0.5, 0, 1)
			local along = from:Lerp(to, k) + Vector3.new(0, 0.5 + math.sin(k * math.pi) * (0.6 + (i % 3) * 0.3), 0)
			local endCF = CFrame.lookAt(to, to + (to - from)) * piece.Offset
			local cf
			if k < 1 then
				cf = startCFs[i]:Lerp(CFrame.new(along) * CFrame.Angles(k * 7 + i, k * 5, 0), math.min(k * 4, 1))
			else
				cf = endCF
			end
			placePiece(piece, cf)
		end
	end, function()
		dropPieces(pieces)
		task.delay(0.12, function()
			destroyRope(rope)
		end)
		if done then
			done()
		end
	end)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "LassoSnare" then
		if phase == "Startup" and character then
			TuskAnimation.play(character, "TimLassoThrow")
			if root then
				local loop = newLoop(1.4)
				local rope = newRope(0.14, 6)
				VFXLib.animate(data.Startup or 0.28, function(a)
					if root.Parent then
						local c = root.CFrame * CFrame.new(0.6, 3.3, 0) * CFrame.Angles(0, a * 16, 0)
						loop:PivotTo(c)
						local h = handPos(character)
						if h then
							setRope(rope, h, (c * CFrame.new(1.4, 0, 0)).Position, 0)
						end
					end
				end, function()
					loop:Destroy()
					destroyRope(rope)
				end)
			end
		elseif phase == "Snag" and data.Target then
			TuskAnimation.play(character, "TimReel")
			local getHand = function()
				return character.Parent and handPos(character)
			end
			holdRope(getHand, function()
				return data.Target.Parent and torsoPos(data.Target)
			end, (data.Duration or 0.6) + 0.2, 1.3)
			if data.SplitTime then
				splitApart(data.Target, getHand, data.SplitTime)
			end
			local tp = torsoPos(data.Target)
			if tp then
				VFXLib.burst(tp, { Count = 12, Color = ROPE, Speed = 18, Lifetime = 0.3 })
				TuskVFX.CreateImpactStar(tp, { Size = 4, Rays = 7, Color = pal.Main, Color2 = Color3.new(1, 1, 1), Duration = 0.2 })
			end
			VFXLib.sound(sounds.Hit, root or data.Target, 0.6, 1)
		end
	elseif move == "SplitDodge" and character then
		if phase == "Scatter" then
			TuskAnimation.play(character, "TimSplit")
			scatter(character, data.Window or 0.6)
		elseif phase == "Counter" or phase == "Slide" then
			local e = scattered[character]
			scattered[character] = nil
			local pieces = e and e.Pieces or cutPieces(character)
			if e then
				destroyRope(e.Ring)
			end
			hideBody(character, true, (data.Travel or 0.18) + 0.3)
			local travel = phase == "Counter" and 0.16 or (data.Travel or 0.3)
			rideRope(character, pieces, data.From, data.To, travel, function()
				if phase == "Counter" and character.Parent then
					hideBody(character, false)
					VFXLib.burst(data.To, { Count = 16, Color = pal.Main, Speed = 18, Lifetime = 0.3 })
				end
			end)
			if phase == "Counter" then
				-- Reformed behind them: rope slam.
				local attackerRoot = data.Attacker and Common.rootOf(data.Attacker)
				task.delay(0.14, function()
					local r = Common.rootOf(character)
					if r then
						TuskAnimation.play(character, "T_M1_4")
						TuskVFX.CreateCrescent(r.CFrame * CFrame.new(0, 1, -2.4) * CFrame.Angles(0, 0, math.pi / 2), { Radius = 3.6, Width = 0.35, Color = ROPE, Color2 = pal.Light, Sweep = 2.6, Duration = 0.22 })
					end
					if attackerRoot then
						TuskVFX.CreateImpactStar(attackerRoot.Position, { Size = 6, Rays = 9, Color = pal.Main, Color2 = Color3.new(1, 1, 1), Duration = 0.25 })
						CameraFX.shakeAt(attackerRoot.Position, 0.5, 40)
					end
				end)
				if Common.isLocal(character) then
					CameraFX.impactFrame(pal.Light)
				end
			elseif Common.isLocal(character) then
				CameraFX.fovPunch(6, 0.25)
			end
		elseif phase == "Rejoin" then
			local e = scattered[character]
			if e then
				scattered[character] = nil
				dropPieces(e.Pieces)
				destroyRope(e.Ring)
			end
			hideBody(character, false)
			local pos = data.Position
			if pos then
				VFXLib.burst(pos, { Count = 16, Color = pal.Main, Speed = 18, Lifetime = 0.35 })
				TuskVFX.CreateRotationalShockwave(CFrame.new(pos - Vector3.new(0, 2.5, 0)), { Radius = 4, Layers = 1, Color = pal.Main, Color2 = ROPE, Ground = true, Particles = 0.4, Width = 0.15, Duration = 0.3 })
			end
		end
	elseif move == "SplitBarrage" then
		if phase == "Startup" and character then
			TuskAnimation.play(character, "TimPunch")
		elseif phase == "Fly" and root then
			-- His arm comes apart along the rope and jabs down the line.
			local arm = cutPieces(character, ARM)
			hideBody(character, true, nil, ARM)
			local rope = newRope(0.12, 12)
			local range = data.Range or 26
			local hits, every = data.Hits or 5, data.HitEvery or 0.1
			local punchTime = hits * every
			local total = punchTime + (data.ReelTime or 0.45)
			local nextHit = 0
			VFXLib.animate(total, function(a, dt)
				local r = Common.rootOf(character)
				if not r then
					return
				end
				local t = a * total
				local dir = data.Direction
				local shoulder = (r.CFrame * CFrame.new(1, 0.6, 0)).Position
				local out
				if t < punchTime then
					out = math.min(t / 0.12, 1) * (0.85 + 0.15 * math.sin(t / every * math.pi * 2))
				else
					out = 1 - (t - punchTime) / (total - punchTime) -- reel back in
				end
				local reach = range * math.max(out, 0)
				local tip = shoulder + dir * reach
				for i, piece in ipairs(arm) do
					local k = #arm == 1 and 1 or i / #arm
					local pos = shoulder + dir * reach * k
					placePiece(piece, CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-math.pi / 2, 0, 0))
				end
				setRope(rope, shoulder, tip, 0.2)
				nextHit = nextHit - (dt or 1 / 60)
				if t < punchTime and nextHit <= 0 and out > 0.6 then
					nextHit = every
					TuskVFX.CreateImpactStar(tip, { Size = 3, Rays = 6, Color = pal.Main, Color2 = Color3.new(1, 1, 1), Duration = 0.12 })
					VFXLib.sound(sounds.Hit, tip, 0.4, 1.2)
				end
			end, function()
				dropPieces(arm)
				destroyRope(rope)
				if character.Parent then
					hideBody(character, false, nil, ARM)
				end
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
			local loop = newLoop(1.4)
			-- A rope ring on the ground, tightening toward him.
			local ring = newRope(0.18, 24)
			local radius = data.Radius or 24
			VFXLib.animate(data.Windup or 0.9, function(a)
				if not root.Parent then
					return
				end
				loop:PivotTo(root.CFrame * CFrame.new(0, 4.4, 0) * CFrame.Angles(0, a * 22, 0))
				loop:ScaleTo(1 + a * 2.2)
				local r = radius * (1 - a * 0.35)
				local center = root.Position - Vector3.new(0, 2.7, 0)
				local n = #ring.Parts
				for i, p in ipairs(ring.Parts) do
					local a0 = (i - 1) / n * math.pi * 2 + a
					local a1 = i / n * math.pi * 2 + a
					local p0 = center + Vector3.new(math.cos(a0) * r, 0, math.sin(a0) * r)
					local p1 = center + Vector3.new(math.cos(a1) * r, 0, math.sin(a1) * r)
					p.Transparency = 0
					p.Size = Vector3.new(0.18, 0.18, (p1 - p0).Magnitude + 0.05)
					p.CFrame = CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, 0, i * 0.7)
				end
			end, function()
				loop:Destroy()
				destroyRope(ring)
			end)
			VFXLib.flash(root.Position, pal.Main, 3, 25, 0.4)
		end
		if Common.isLocal(character) then
			CameraFX.fovPunch(-6, 0.4)
		end
	elseif data.Phase == "Rope" then
		local hold = (data.RideHits or 4) * (data.RideEvery or 0.18) + (data.ReelTime or 0.8) + 0.1
		local getHand = function()
			return character.Parent and handPos(character)
		end
		for _, target in ipairs(data.Targets or {}) do
			holdRope(getHand, function()
				return target.Parent and torsoPos(target)
			end, hold, 1.4)
			if data.SplitTime then
				splitApart(target, getHand, data.SplitTime)
			end
			-- His pieces ride the rope in, again and again.
			local pieces = cutPieces(character, { "Head", "RightHand", "LeftHand", "RightFoot", "LeftFoot", "Right Arm", "Left Arm" })
			VFXLib.animate(hold - 0.1, function(a)
				local h = getHand()
				local t = target.Parent and torsoPos(target)
				if not h or not t then
					return
				end
				for i, piece in ipairs(pieces) do
					local k = ((a * 4) + i * 0.17) % 1
					placePiece(piece, CFrame.new(h:Lerp(t, k) + Vector3.new(0, math.sin(k * math.pi) * 0.8, 0)) * CFrame.Angles(k * 8, i, 0))
				end
			end, function()
				dropPieces(pieces)
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
		local loop = newLoop(3)
		VFXLib.animate(0.3, function(a)
			loop:PivotTo(CFrame.new(data.Position - Vector3.new(0, 2.4 - 0, 0)) * CFrame.Angles(0, a * 4, 0))
			loop:ScaleTo(math.max(0.1, 1.3 - a))
		end, function()
			loop:Destroy()
		end)
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
		if now > untilT and not scattered[character] then
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
	stepScattered()
	slowTimer = slowTimer + dt
	if slowTimer > 0.2 then
		slowTimer = 0
		stepStance()
	end
end

-- Keep split bodies hidden after the camera's own transparency update.
pcall(function()
	game:GetService("RunService"):BindToRenderStep("TimKeepHidden", Enum.RenderPriority.Camera.Value + 2, enforceHidden)
end)

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
```
