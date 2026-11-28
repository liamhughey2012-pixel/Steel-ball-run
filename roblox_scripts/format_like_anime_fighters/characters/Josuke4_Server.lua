--[[
	Josuke4_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Josuke Higashikata (Part 4): Crazy Diamond.
	Its other half is Josuke4_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "josuke4" or __expect.Side ~= "server") then
		error("this is the code for Josuke4_Server, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Josuke4_Server and put it in ServerScriptService > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: Josuke4
-- ======================================================================
__modules["Josuke4"] = function()
--[[
	Josuke4  (ServerScriptService.SpinServer.TuskActs.Josuke4)

	Josuke Higashikata (Part 4, Diamond is Unbreakable): CRAZY DIAMOND.
	Not the JoJolion Josuke (Act 15). Registered as "Act" 25.
	  M1        DORA COMBO: Crazy Diamond punches with him; the 4th is a
	            heavy straight that launches
	  Ability 1 DORARARA RUSH: a storm of punches in front of him that drags
	            them along (he can still walk); the last big "DORA!" sends
	            them flying with a shockwave
	  Ability 2 BREAK & RESTORE: Crazy Diamond punches the nearest enemy in
	            front, then "fixes" them into a lump of rock: stuck, unable to
	            move or act, until the rock breaks off and knocks them away
	            (a miss only costs a short cooldown)
	  Ability 3 HOMING SHARD: he flicks a bloodied glass shard; Crazy
	            Diamond restores it, so it flies back to where the blood came
	            from, steering after the nearest enemy in front
	  Ultimate  "WHAT DID YOU SAY ABOUT MY HAIR?!": he snaps. The outburst
	            blows everyone near him back; for a while he hits harder,
	            moves faster, and the rush and fusion are ready at once
Numbers: TuskConfig.Josuke4. All damage goes through S.hit (CombatAdapter).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Josuke4 = {}
local cfg = TuskConfig.Josuke4
local ACT = 25

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

function Josuke4.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: DORARARA RUSH
---------------------------------------------------------------------------
local function doraRush(S, player, state, aim)
	local c = cfg.DoraRush
	if not ready(S, player, state, "DoraRush", 1) then
		return
	end
	S.startCooldown(player, state, "DoraRush", c.Cooldown, 1)
	S.lock(state, c.Windup + c.Duration + 0.15)
	local character, humanoid = alive(S, player)
	local life = state.Life
	local untilT = now() + c.Windup + c.Duration
	character:SetAttribute("DoraRushUntil", untilT)
	S.Adapter.setMoveModifier(humanoid, "DoraRush", c.WalkMultiplier)
	S.fx("Ability", { Character = character, Act = ACT, Move = "DoraRush", Phase = "Start", Windup = c.Windup, Duration = c.Duration })
	local ticks = math.max(1, math.floor(c.Duration / c.Tick))
	local function stop()
		if humanoid.Parent then
			S.Adapter.setMoveModifier(humanoid, "DoraRush", nil)
		end
		if character.Parent and character:GetAttribute("DoraRushUntil") == untilT then
			character:SetAttribute("DoraRushUntil", nil)
		end
	end
	for i = 1, ticks do
		task.delay(c.Windup + (i - 1) * c.Tick, function()
			if character:GetAttribute("DoraRushUntil") ~= untilT then
				return
			end
			if not S.stillValid(player, state, life) then
				stop()
				S.fx("Ability", { Character = character, Act = ACT, Move = "DoraRush", Phase = "Stop" })
				return
			end
			local _, _, r = alive(S, player)
			local boxCF = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
			if i == ticks then
				Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.FinalDamage, Stun = c.FinalStun, Knockback = c.FinalKnockback, Launch = c.FinalLaunch, Direction = r.CFrame.LookVector, Source = "Josuke4Dora" }, c.MaxTargets)
				local waveAt = (r.CFrame * CFrame.new(0, 0, -c.HitboxForward - 3)).Position
				Moves.aoe(S, player, waveAt, c.ShockwaveRadius, { Damage = c.ShockwaveDamage, Stun = 0.4, Knockback = 30, Direction = r.CFrame.LookVector, Source = "Josuke4Dora" }, 6)
				S.fx("Ability", { Character = character, Act = ACT, Move = "DoraRush", Phase = "Finish", Position = boxCF.Position, Direction = r.CFrame.LookVector, Radius = c.ShockwaveRadius })
				stop()
			else
				local count, hitSet = Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = r.CFrame.LookVector, Source = "Josuke4Dora" }, c.MaxTargets)
				-- Drag whoever's caught back in front of Crazy Diamond.
				for target in pairs(hitSet or {}) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr and not tr.Anchored then
						local to = boxCF.Position - tr.Position
						tr.AssemblyLinearVelocity = Vector3.new(to.X * c.Drag, tr.AssemblyLinearVelocity.Y, to.Z * c.Drag) + r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
					end
				end
				if count > 0 and i % 2 == 0 then
					S.fx("Ability", { Act = ACT, Move = "DoraRush", Phase = "Hit", Position = boxCF.Position })
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- 2: BREAK & RESTORE (rock fusion)
---------------------------------------------------------------------------
-- Encased in rock: anchored (counted, so two at once don't free them early)
-- and stunned for the whole time.
local encased = setmetatable({}, { __mode = "k" }) -- [root] = { Count, WasAnchored }

local function encase(root)
	local e = encased[root]
	if not e then
		e = { Count = 0, WasAnchored = root.Anchored }
		encased[root] = e
	end
	e.Count = e.Count + 1
	root.Anchored = true
end

local function release(root)
	local e = encased[root]
	if not e then
		return
	end
	e.Count = e.Count - 1
	if e.Count <= 0 then
		encased[root] = nil
		-- (Left anchored if a time stop still holds them.)
		local model = root.Parent
		if model and not model:GetAttribute("TimeStopped") then
			root.Anchored = e.WasAnchored
		end
	end
end

local function rockFusion(S, player, state, aim)
	local c = cfg.RockFusion
	if not ready(S, player, state, "RockFusion", 2) then
		return
	end
	S.lock(state, c.Windup + 0.3)
	local character, _, root = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "RockFusion", Phase = "Wind", Windup = c.Windup })
	S.startCooldown(player, state, "RockFusion", c.Cooldown, 2)
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = Moves.flat(S.aim(aim, r))
		local target = Moves.findTarget(S, char, r, c.Range, c.Cone, dir)
		if not target then
			-- Missed: only a short wait.
			S.startCooldown(player, state, "RockFusion", c.MissCooldown, 2)
			S.fx("Ability", { Character = char, Act = ACT, Move = "RockFusion", Phase = "Miss", Position = (r.CFrame * CFrame.new(0, 0, -4)).Position })
			return
		end
		local tr = target:FindFirstChild("HumanoidRootPart")
		local landed = S.hit(player, target, { Damage = c.Damage, Stun = c.EncaseTime, Knockback = 0, Direction = dir, Position = tr.Position, Source = "Josuke4Fusion" })
		if not landed then
			S.startCooldown(player, state, "RockFusion", c.MissCooldown, 2)
			S.fx("Ability", { Character = char, Act = ACT, Move = "RockFusion", Phase = "Miss", Position = tr.Position })
			return
		end
		local untilT = now() + c.EncaseTime
		target:SetAttribute("RockEncasedUntil", untilT)
		encase(tr)
		S.fx("Ability", { Character = char, Act = ACT, Move = "RockFusion", Phase = "Encase", Target = target, Position = tr.Position, Time = c.EncaseTime })
		task.delay(c.EncaseTime, function()
			release(tr)
			if target.Parent and target:GetAttribute("RockEncasedUntil") == untilT then
				target:SetAttribute("RockEncasedUntil", nil)
			end
			if not target.Parent then
				return
			end
			-- The rock breaks off and knocks them away.
			local away = tr.Position - (r.Parent and r.Position or tr.Position - dir)
			away = Vector3.new(away.X, 0, away.Z)
			away = away.Magnitude > 0.1 and away.Unit or dir
			S.hit(player, target, { Damage = c.BurstDamage, Stun = 0.5, Knockback = c.BurstKnockback, Launch = c.BurstLaunch, Direction = away, Position = tr.Position, Source = "Josuke4Fusion", Unblockable = true })
			S.fx("Ability", { Act = ACT, Move = "RockFusion", Phase = "Burst", Target = target, Position = tr.Position })
		end)
	end)
end

---------------------------------------------------------------------------
-- 3: HOMING SHARD
---------------------------------------------------------------------------
local function homingShard(S, player, state, aim)
	local c = cfg.HomingShard
	if not ready(S, player, state, "HomingShard", 3) then
		return
	end
	S.startCooldown(player, state, "HomingShard", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "HomingShard", Phase = "Flick", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = S.aim(aim, r)
		local target = Moves.findTarget(S, char, r, c.LockRange, c.Cone, dir)
		local pos = S.origin(char, r, Moves.HAND)
		local vel = dir * c.Speed
		local id = tostring({})
		S.fx("Ability", { Character = char, Act = ACT, Move = "HomingShard", Phase = "Fly", Id = id, From = pos, Direction = dir, Target = target, Speed = c.Speed, Turn = c.Turn, Life = c.Life })
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local t, step = 0, 1 / 30
		local function tick()
			t = t + step
			-- Steer after the target (restored back to the blood).
			local tr = target and target.Parent and target:FindFirstChild("HumanoidRootPart")
			local hum = target and target:FindFirstChildOfClass("Humanoid")
			if tr and hum and hum.Health > 0 then
				local want = (tr.Position - pos).Unit * c.Speed
				vel = (vel + (want - vel) * math.min(1, c.Turn * step)).Unit * c.Speed
			end
			local move = vel * step
			local wall = workspace:Raycast(pos, move, params)
			if wall and not (wall.Instance.Parent and wall.Instance.Parent:FindFirstChildOfClass("Humanoid")) then
				S.fx("Ability", { Act = ACT, Move = "HomingShard", Phase = "End", Id = id, Position = wall.Position, Hit = false })
				return
			end
			pos = pos + move
			-- Anyone it passes close to (the target first).
			local victim
			if tr and (tr.Position - pos).Magnitude <= c.HitRadius then
				victim = target
			else
				for _, other in ipairs(S.Hitbox.inRadius(char, pos, c.HitRadius, 1)) do
					victim = other
				end
			end
			if victim then
				local vr = victim:FindFirstChild("HumanoidRootPart")
				local landed = S.hit(player, victim, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = vel.Unit, Position = vr and vr.Position or pos, Source = "Josuke4Shard" })
				S.fx("Ability", { Act = ACT, Move = "HomingShard", Phase = "End", Id = id, Position = pos, Hit = landed })
				return
			end
			if t >= c.Life then
				S.fx("Ability", { Act = ACT, Move = "HomingShard", Phase = "End", Id = id, Position = pos, Hit = false })
				return
			end
			task.delay(step, tick)
		end
		task.delay(step, tick)
	end)
end

function Josuke4.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		doraRush(S, player, state, aim)
	elseif slot == 2 then
		rockFusion(S, player, state, aim)
	elseif slot == 3 then
		homingShard(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- "WHAT DID YOU SAY ABOUT MY HAIR?!" (ultimate)
---------------------------------------------------------------------------
local function calmDown(S, character, untilT)
	if not character.Parent or character:GetAttribute("HairRageUntil") ~= untilT then
		return
	end
	character:SetAttribute("HairRageUntil", nil)
	character:SetAttribute("HairRageDamage", nil)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		S.Adapter.setMoveModifier(humanoid, "HairRage", nil)
	end
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Calm" })
end

function Josuke4.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.2)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Snap", Windup = u.Windup })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local char, hum, r = alive(S, player)
		local duration = (typeof(player) == "table" and player.IsBot) and u.BotDuration or u.Duration
		local untilT = now() + duration
		char:SetAttribute("HairRageUntil", untilT)
		char:SetAttribute("HairRageDamage", u.DamageMultiplier)
		S.Adapter.setMoveModifier(hum, "HairRage", u.SpeedMultiplier)
		local slots = { DoraRush = 1, RockFusion = 2, HomingShard = 3 }
		for _, name in ipairs(u.ResetCooldowns or {}) do
			S.startCooldown(player, state, name, 0, slots[name])
		end
		-- The outburst blows everyone near him back.
		Moves.aoe(S, player, r.Position, u.ShoutRadius, { Damage = u.ShoutDamage, Stun = 0.6, Knockback = u.ShoutKnockback, Launch = 8, Source = "Josuke4Rage" }, 10)
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Rage", Position = r.Position, Radius = u.ShoutRadius, Duration = duration })
		task.delay(duration, function()
			calmDown(S, char, untilT)
		end)
	end)
end

function Josuke4.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("DoraRushUntil", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "DoraRush", nil)
		end
		local untilT = character:GetAttribute("HairRageUntil")
		if untilT then
			calmDown(S, character, untilT)
		end
	end
end

return Josuke4
end

-- ======================================================================
-- MODULE: Josuke4Outfit
-- ======================================================================
__modules["Josuke4Outfit"] = function()
--[[
	Josuke4Outfit  (ServerScriptService.SpinServer.Josuke4Outfit)

	Gives a character the look of Josuke Higashikata (Part 4) while they play
	him (TuskAct 25), built from blocky parts (no catalog asset ids), matched
	to his art:
	  * his POMPADOUR: a big, rounded quiff sweeping up and out over his
	    forehead, dark violet-black with a cross-hatched shine, short at the
	    back and sides
	  * a long dark navy GAKURAN: a tall stand-up collar with a gold ANCHOR
	    badge on one side and two gold HEARTS on the other, hanging open at
	    the top over a yellow shirt; a gold PEACE-SIGN pin on the chest; gold
	    buttons down the front; long tails flaring out to his knees
	  * gold bracelets at both wrists
	  * wide, baggy navy trousers and black shoes
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local Josuke4Outfit = {}
Josuke4Outfit.Act = 25

local C = {
	Coat = Color3.fromRGB(38, 38, 82),
	CoatShade = Color3.fromRGB(24, 24, 56),
	CoatLight = Color3.fromRGB(60, 60, 116),
	Shirt = Color3.fromRGB(240, 196, 60),
	ShirtShade = Color3.fromRGB(206, 160, 40),
	Gold = Color3.fromRGB(236, 192, 72),
	GoldShade = Color3.fromRGB(186, 140, 40),
	Hair = Color3.fromRGB(44, 34, 74),
	HairShine = Color3.fromRGB(96, 80, 150),
	Shoe = Color3.fromRGB(20, 20, 26),
}

local saved = setmetatable({}, { __mode = "k" })

local function piece(parent, outfit, name, size, color, offset, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material or Enum.Material.SmoothPlastic
	p.Size = size
	p.Color = color
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = outfit
	return p
end

local function egg(parent, outfit, name, size, color, offset)
	local p = piece(parent, outfit, name, size, color, offset)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- A flat gold disc facing forward (-Z).
local function coin(parent, outfit, name, d, color, offset)
	local p = piece(parent, outfit, name, Vector3.new(0.05, d, d), color, offset * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Metal)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A small gold heart facing forward: two lobes and a point.
local function heart(parent, outfit, cf, size)
	for _, side in ipairs({ -1, 1 }) do
		local lobe = piece(parent, outfit, "HeartLobe", Vector3.new(0.05, size * 0.55, size * 0.55), C.Gold, cf * CFrame.new(side * size * 0.22, size * 0.12, 0) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Metal)
		lobe.Shape = Enum.PartType.Cylinder
	end
	piece(parent, outfit, "HeartPoint", Vector3.new(size * 0.55, size * 0.55, 0.05), C.Gold, cf * CFrame.new(0, -size * 0.12, 0) * CFrame.Angles(0, 0, math.pi / 4), Enum.Material.Metal)
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Short hair at the back and sides.
	piece(head, outfit, "HairCap", Vector3.new(head.Size.X + 0.08 * s, 0.35 * s, head.Size.Z + 0.08 * s), C.Hair, CFrame.new(0, h - 0.08 * s, 0.02 * s))
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.08 * s, 0.75 * s, 0.14 * s), C.Hair, CFrame.new(0, h - 0.4 * s, d + 0.04 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HairSide", Vector3.new(0.1 * s, 0.5 * s, head.Size.Z * 0.7), C.Hair, CFrame.new(side * (w + 0.03 * s), h - 0.35 * s, 0.1 * s))
	end
	-- The pompadour: a big rounded quiff sweeping up and out over his forehead.
	local quiff = CFrame.new(0, h + 0.38 * s, -0.32 * s) * CFrame.Angles(math.rad(-28), 0, 0)
	egg(head, outfit, "Pompadour", Vector3.new(head.Size.X + 0.14 * s, 0.85 * s, head.Size.Z + 0.75 * s), C.Hair, quiff)
	egg(head, outfit, "PompadourFront", Vector3.new(head.Size.X + 0.04 * s, 0.75 * s, 0.75 * s), C.Hair, quiff * CFrame.new(0, 0.06 * s, -0.55 * s))
	egg(head, outfit, "PompadourBase", Vector3.new(head.Size.X + 0.1 * s, 0.5 * s, head.Size.Z + 0.1 * s), C.Hair, CFrame.new(0, h + 0.05 * s, 0))
	-- Its cross-hatched shine.
	for k = -2, 2 do
		piece(head, outfit, "HatchA", Vector3.new(0.04 * s, 0.05 * s, 0.85 * s), C.HairShine, quiff * CFrame.new(k * 0.2 * s, 0.41 * s, -0.18 * s) * CFrame.Angles(0, math.rad(35), 0))
		piece(head, outfit, "HatchB", Vector3.new(0.04 * s, 0.05 * s, 0.85 * s), C.HairShine, quiff * CFrame.new(k * 0.2 * s, 0.41 * s, -0.18 * s) * CFrame.Angles(0, math.rad(-35), 0))
	end
	piece(head, outfit, "HairLine", Vector3.new(head.Size.X + 0.04 * s, 0.1 * s, 0.1 * s), C.Hair, CFrame.new(0, h - 0.05 * s, -d - 0.02 * s))
	-- Brows.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Brow", Vector3.new(0.28 * s, 0.06 * s, 0.05 * s), C.Hair, CFrame.new(side * 0.22 * s, 0.14 * s, -d - 0.02 * s) * CFrame.Angles(0, 0, side * 0.12))
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Coat", s + Vector3.new(0.12, 0.02, 0.12), C.Coat, CFrame.new())
		-- Open at the top over a yellow shirt (a V down to the chest).
		piece(upper, outfit, "Shirt", Vector3.new(0.6, s.Y * 0.55, 0.04), C.Shirt, CFrame.new(0, top - s.Y * 0.28, front - 0.07))
		piece(upper, outfit, "ShirtFold", Vector3.new(0.04, s.Y * 0.5, 0.045), C.ShirtShade, CFrame.new(0.06, top - s.Y * 0.28, front - 0.075))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Lapel", Vector3.new(0.34, s.Y * 0.62, 0.06), C.CoatLight, CFrame.new(side * 0.36, top - s.Y * 0.3, front - 0.08) * CFrame.Angles(0, 0, side * 0.28))
		end
		-- Gold buttons down the closed front.
		for k = 0, 2 do
			coin(upper, outfit, "Button", 0.14, C.Gold, CFrame.new(0, top - s.Y * 0.62 - k * 0.32, front - 0.1))
		end
		-- The gold peace-sign pin on his chest.
		local pin = CFrame.new(-s.X * 0.28, top - s.Y * 0.5, front - 0.1)
		coin(upper, outfit, "PeaceRing", 0.36, C.Gold, pin)
		coin(upper, outfit, "PeaceInner", 0.27, C.Coat, pin * CFrame.new(0, 0, -0.01))
		piece(upper, outfit, "PeaceStem", Vector3.new(0.04, 0.28, 0.05), C.Gold, pin * CFrame.new(0, 0, -0.03), Enum.Material.Metal)
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "PeaceArm", Vector3.new(0.04, 0.16, 0.05), C.Gold, pin * CFrame.new(side * 0.05, -0.06, -0.03) * CFrame.Angles(0, 0, side * 0.8), Enum.Material.Metal)
		end
		-- The tall stand-up collar: an anchor on one side, two hearts on the other.
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.75, 0.6, 0.18), C.Coat, CFrame.new(0, top + 0.28, -front))
		for _, side in ipairs({ -1, 1 }) do
			local cf = CFrame.new(side * s.X * 0.33, top + 0.28, -0.05) * CFrame.Angles(0, side * -0.3, 0)
			piece(upper, outfit, "CollarSide", Vector3.new(0.16, 0.6, s.Z * 0.95), C.Coat, cf)
			local face = cf * CFrame.new(0, 0.02, -s.Z * 0.48)
			if side == 1 then
				-- Anchor: a ring, a shank, a cross bar and a curved foot.
				coin(upper, outfit, "AnchorRing", 0.12, C.Gold, face * CFrame.new(0, 0.2, -0.02))
				piece(upper, outfit, "AnchorShank", Vector3.new(0.05, 0.34, 0.05), C.Gold, face * CFrame.new(0, 0.02, -0.02), Enum.Material.Metal)
				piece(upper, outfit, "AnchorBar", Vector3.new(0.2, 0.04, 0.05), C.Gold, face * CFrame.new(0, 0.1, -0.02), Enum.Material.Metal)
				for _, f in ipairs({ -1, 1 }) do
					piece(upper, outfit, "AnchorFluke", Vector3.new(0.14, 0.04, 0.05), C.Gold, face * CFrame.new(f * 0.06, -0.15, -0.02) * CFrame.Angles(0, 0, f * 0.6), Enum.Material.Metal)
				end
			else
				heart(upper, outfit, face * CFrame.new(0, 0.12, -0.02), 0.18)
				heart(upper, outfit, face * CFrame.new(0, -0.1, -0.02), 0.18)
			end
		end
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.1, 0.02, 0.1), C.Coat, CFrame.new())
		-- Long coat tails: sides and back, flaring out down to the knees.
		piece(lower, outfit, "TailBack", Vector3.new(ls.X + 0.2, 2.3, 0.1), C.Coat, CFrame.new(0, -1.15, ls.Z / 2 + 0.18) * CFrame.Angles(math.rad(10), 0, 0))
		for _, side in ipairs({ -1, 1 }) do
			piece(lower, outfit, "TailSide", Vector3.new(0.1, 2.2, ls.Z + 0.3), C.Coat, CFrame.new(side * (ls.X / 2 + 0.16), -1.1, 0.05) * CFrame.Angles(0, 0, side * -0.14))
			piece(lower, outfit, "TailFront", Vector3.new(ls.X / 2 + 0.05, 2.1, 0.1), C.Coat, CFrame.new(side * (ls.X / 4 + 0.02), -1.05, -ls.Z / 2 - 0.12) * CFrame.Angles(math.rad(-6), 0, side * -0.1))
		end
		coin(lower, outfit, "TailButton", 0.14, C.Gold, CFrame.new(0, -0.15, -ls.Z / 2 - 0.12))
	end
	-- Long navy sleeves, gold bracelets at the wrists.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			piece(arm, outfit, "Sleeve", as + Vector3.new(0.12, 0.02, 0.12), C.Coat, CFrame.new())
			if name:find("Lower") or name == "Left Arm" or name == "Right Arm" then
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.16, 0.18, as.Z + 0.16), C.CoatShade, CFrame.new(0, -as.Y / 2 + 0.16, 0))
				piece(arm, outfit, "Bracelet", Vector3.new(as.X + 0.2, 0.12, as.Z + 0.2), C.Gold, CFrame.new(0, -as.Y / 2 + 0.02, 0), Enum.Material.Metal)
			end
		end
	end
	-- Wide, baggy trousers and black shoes.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local wide = name:find("Lower") and 0.26 or 0.18
			piece(leg, outfit, "Trousers", leg.Size + Vector3.new(wide, 0.02, wide), C.Coat, CFrame.new())
			piece(leg, outfit, "Crease", Vector3.new(0.04, leg.Size.Y - 0.1, 0.04), C.CoatShade, CFrame.new(0, 0, -(leg.Size.Z + wide) / 2 - 0.01))
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.08, 0.04, 0.18), C.Shoe, CFrame.new(0, 0, -0.05))
		end
	end
end

function Josuke4Outfit.apply(character)
	if character:FindFirstChild("Josuke4Outfit") then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local store = { Hidden = {} }
	saved[character] = store
	for _, d in ipairs(character:GetChildren()) do
		if d:IsA("Accessory") then
			local handle = d:FindFirstChild("Handle")
			local kind = d.AccessoryType
			if handle and (kind == Enum.AccessoryType.Hat or kind == Enum.AccessoryType.Hair or kind == Enum.AccessoryType.Unknown) then
				store.Hidden[handle] = handle.Transparency
				handle.Transparency = 1
			end
		end
	end
	local outfit = Instance.new("Model")
	outfit.Name = "Josuke4Outfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function Josuke4Outfit.remove(character)
	local outfit = character:FindFirstChild("Josuke4Outfit")
	if outfit then
		outfit:Destroy()
	end
	local store = saved[character]
	if not store then
		return
	end
	saved[character] = nil
	for thing, transparency in pairs(store.Hidden) do
		if thing.Parent then
			thing.Transparency = transparency
		end
	end
end

local function watch(character)
	local function update()
		if character:GetAttribute("TuskAct") == Josuke4Outfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == Josuke4Outfit.Act then
					Josuke4Outfit.apply(character)
				end
			end)
		else
			Josuke4Outfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function Josuke4Outfit.init()
	local function onPlayer(player)
		player.CharacterAppearanceLoaded:Connect(watch)
		if player.Character then
			watch(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	-- Stand-user NPCs (StandBots) wear the outfit too.
	local CollectionService = game:GetService("CollectionService")
	for _, model in ipairs(CollectionService:GetTagged("SpinFighter")) do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("SpinFighter"):Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
end

return Josuke4Outfit
end
end
