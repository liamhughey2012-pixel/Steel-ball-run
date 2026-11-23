--[[
	PorkPie_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Pork Pie Hat Kid: Wired.
	Its other half is PorkPie_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: PorkPieHatKid
-- ======================================================================
__modules["PorkPieHatKid"] = function()
--[[
	PorkPieHatKid  (ServerScriptService.SpinServer.TuskActs.PorkPieHatKid)

	Pork Pie Hat Kid: WIRED. Two fish hooks on steel cables that roll out of a
	winch in the back of his mouth; the hooks come out of water to snag
	whoever goes for the bait, and together they can lift a horse.
	Registered as "Act" 7 so it reuses the Tusk ability system (cooldowns,
	HUD, ultimate meter, input).
	  M1        HOOK COMBO: slap, slap, a hook lash out of his mouth, flying kick
	  Ability 1 WIRED HOOK: a hook shoots out of his mouth; a hit snags the
	            enemy and the winch reels them in to him
	  Ability 2 BAIT PAN: puts down a pan of water with a feather bait. The
	            first enemies to come near get hooked out of the water,
	            hoisted up and yanked back down
	  Ability 3 DOUBLE HOOK LIFT: both hooks snag up to two enemies in front,
	            hoist them high in the air, then slam them down
	  Ultimate  WIRED WINCH: puddles of water all around him, hooks erupt from
	            every one, the winch reels everyone in through the air, slam
	Numbers: TuskConfig.PorkPie. All damage goes through S.hit (CombatAdapter).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local PorkPie = {}
local cfg = TuskConfig.PorkPie
local ACT = 7
local MOUTH = CFrame.new(0, 1.3, -1.2) -- roughly where his mouth is (root space)

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function PorkPie.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

-- The winch pulls `target` toward `point` (one tick; the knockback lasts ~0.18 s).
local function pull(S, target, point, stopDistance)
	local tr = target:FindFirstChild("HumanoidRootPart")
	if not tr then
		return true
	end
	local offset = point - tr.Position
	local distance = offset.Magnitude
	if distance <= (stopDistance or 4) then
		return true
	end
	local strength = math.min(distance / 0.18 * 0.6, 90)
	S.Adapter.applyKnockback(target, offset, strength, math.clamp(offset.Y * 3, 4, 40))
	return false
end

-- Yank a hoisted enemy straight back down into the ground.
local function slamDown(S, player, target, damage, source)
	if not target.Parent then
		return
	end
	S.Adapter.applyKnockback(target, Vector3.new(0, 0, 1), 1, -90)
	task.delay(0.25, function()
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			S.hit(player, target, { Damage = damage, Stun = 0.5, Knockback = 0, Direction = Vector3.new(0, -1, 0), Position = tr.Position, Source = source })
		end
	end)
end

-- Up to `max` enemies in a cone in front, nearest first.
local function targetsInCone(S, character, root, direction, range, cone, max)
	local look = Moves.flat(direction)
	local cosLimit = math.cos(math.rad(cone / 2))
	local list = {}
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, range, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and S.Adapter.canBeHit(nil, target) then
			local offset = tr.Position - root.Position
			local f = Vector3.new(offset.X, 0, offset.Z)
			if (f.Magnitude < 1 or f.Unit:Dot(look) >= cosLimit) and S.Hitbox.lineOfSight(root.Position, tr.Position, { character, target }) then
				table.insert(list, { Target = target, Distance = offset.Magnitude })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Distance < b.Distance
	end)
	local out = {}
	for i = 1, math.min(max, #list) do
		out[i] = list[i].Target
	end
	return out
end

---------------------------------------------------------------------------
-- WIRED HOOK
---------------------------------------------------------------------------
local function wiredHook(S, player, state, aim)
	local c = cfg.WiredHook
	if not ready(S, player, state, "WiredHook", 1) then
		return
	end
	S.startCooldown(player, state, "WiredHook", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.3)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "WiredHook", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local snagged = false
		S.fireHook(player, state, {
			Origin = S.origin(char, r, MOUTH),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			OnHit = function(target, position)
				if snagged then
					return
				end
				snagged = true
				if not S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = direction, Position = position, Source = "PorkPieHook" }) then
					return
				end
				S.fx("Ability", { Character = char, Act = ACT, Move = "WiredHook", Phase = "Snag", Target = target, Duration = c.ReelTime })
				-- The winch reels them in.
				local ticks = math.max(1, math.floor(c.ReelTime / c.ReelTick))
				local done = false
				for i = 0, ticks - 1 do
					task.delay(i * c.ReelTick, function()
						local _, _, rr = alive(S, player)
						if done or not rr or state.Life ~= life then
							return
						end
						done = pull(S, target, rr.Position + rr.CFrame.LookVector * 2, c.ReelStopDistance)
					end)
				end
			end,
		})
	end)
end

---------------------------------------------------------------------------
-- BAIT PAN
---------------------------------------------------------------------------
local function clearPan(S, state, reason)
	local pan = state.BaitPan
	if not pan then
		return
	end
	state.BaitPan = nil
	if state.Character then
		state.Character:SetAttribute("BaitPanUntil", nil)
	end
	S.fx("Ability", { Act = ACT, Move = "BaitPan", Phase = reason or "Expire", Id = pan.Id, Position = pan.Position })
end

local function baitPan(S, player, state, aim)
	local c = cfg.BaitPan
	if not ready(S, player, state, "BaitPan", 2) then
		return
	end
	S.startCooldown(player, state, "BaitPan", c.Cooldown, 2)
	S.lock(state, c.Startup + 0.2)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "BaitPan", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		clearPan(S, state, "Expire") -- one pan at a time
		local spot = Moves.safeStep(char, r, direction, c.Distance) or (r.Position + direction * 3)
		local ground = Moves.groundBelow(spot, { char })
		local pan = { Id = tostring(os.clock()) .. player.UserId, Position = ground, Until = os.clock() + c.Duration }
		state.BaitPan = pan
		char:SetAttribute("BaitPanUntil", workspace:GetServerTimeNow() + c.Duration)
		S.fx("Ability", { Character = char, Act = ACT, Move = "BaitPan", Phase = "Place", Id = pan.Id, Position = ground, From = r.Position, Duration = c.Duration, Radius = c.TriggerRadius })

		local function check()
			if state.BaitPan ~= pan or state.Life ~= life then
				return
			end
			if os.clock() >= pan.Until then
				clearPan(S, state, "Expire")
				return
			end
			local center = pan.Position + Vector3.new(0, 2.5, 0)
			local caught = {}
			for _, target in ipairs(S.Hitbox.inRadius(player.Character, center, c.TriggerRadius, c.MaxTargets)) do
				if S.Adapter.canBeHit(player, target) then
					table.insert(caught, target)
				end
			end
			if #caught == 0 then
				task.delay(c.CheckEvery, check)
				return
			end
			-- Hooks burst out of the water and hoist them.
			S.fx("Ability", { Act = ACT, Move = "BaitPan", Phase = "Trigger", Id = pan.Id, Position = pan.Position, Targets = caught, SlamAfter = c.SlamAfter })
			state.BaitPan = nil
			if state.Character then
				state.Character:SetAttribute("BaitPanUntil", nil)
			end
			for _, target in ipairs(caught) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr and S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Launch = c.Lift, Direction = tr.Position - pan.Position, Position = tr.Position, Source = "PorkPieBait" }) then
					task.delay(c.SlamAfter, function()
						slamDown(S, player, target, c.SlamDamage, "PorkPieBait")
					end)
				end
			end
		end
		task.delay(c.CheckEvery, check)
	end)
end

---------------------------------------------------------------------------
-- DOUBLE HOOK LIFT
---------------------------------------------------------------------------
local function doubleHookLift(S, player, state, aim)
	local c = cfg.DoubleHookLift
	if not ready(S, player, state, "DoubleHookLift", 3) then
		return
	end
	S.startCooldown(player, state, "DoubleHookLift", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.5)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "DoubleHookLift", Phase = "Startup", Windup = c.Windup, Direction = direction })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local targets = targetsInCone(S, char, r, direction, c.Range, c.Cone, c.MaxTargets)
		local hooked = {}
		for _, target in ipairs(targets) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Launch = c.Lift, Direction = direction, Position = tr.Position, Source = "PorkPieLift" }) then
				table.insert(hooked, target)
			end
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "DoubleHookLift", Phase = "Hoist", Targets = hooked, Direction = direction, Range = c.Range, SlamAfter = c.SlamAfter })
		if #hooked == 0 then
			-- Missed: shorter cooldown.
			S.startCooldown(player, state, "DoubleHookLift", c.MissCooldown, 3)
			return
		end
		task.delay(c.SlamAfter, function()
			for _, target in ipairs(hooked) do
				slamDown(S, player, target, c.SlamDamage, "PorkPieLift")
			end
			task.delay(0.3, function()
				for _, target in ipairs(hooked) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr then
						S.fx("Ability", { Act = ACT, Move = "DoubleHookLift", Phase = "Slam", Position = tr.Position, Radius = c.SlamRadius })
					end
				end
			end)
		end)
	end)
end

function PorkPie.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		wiredHook(S, player, state, aim)
	elseif slot == 2 then
		baitPan(S, player, state, aim)
	elseif slot == 3 then
		doubleHookLift(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- WIRED WINCH (ultimate)
---------------------------------------------------------------------------
function PorkPie.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + u.ReelTime + 0.5)
	character:SetAttribute("Armored", true)
	-- Puddles of water in a ring around him.
	local puddles = {}
	for i = 1, u.Puddles do
		local a = (i - 1) / u.Puddles * math.pi * 2
		local spot = root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * u.PuddleRadius
		puddles[i] = Moves.groundBelow(spot, { character })
	end
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Start", Windup = u.Windup, Puddles = puddles, Radius = u.Radius })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local char, _, r = alive(S, player)
		-- Hooks erupt from the puddles and snag everyone around.
		local snagged, from = {}, {}
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, u.Radius, 8)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.Hitbox.lineOfSight(r.Position + Vector3.new(0, 2, 0), tr.Position, { char, target }) then
				if S.hit(player, target, { Damage = u.SnagDamage, Stun = u.SnagStun, Knockback = 0, Launch = u.SnagLift, Direction = r.Position - tr.Position, Position = tr.Position, Source = "PorkPieWinch" }) then
					table.insert(snagged, target)
					local best, bestD = 1, math.huge
					for i, p in ipairs(puddles) do
						local d = (p - tr.Position).Magnitude
						if d < bestD then
							best, bestD = i, d
						end
					end
					table.insert(from, best)
				end
			end
		end
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Snag", Targets = snagged, From = from, Puddles = puddles, ReelTime = u.ReelTime })
		S.finishUltimate(player, state)
		-- The winch reels them all in through the air.
		local ticks = math.floor(u.ReelTime / u.ReelTick)
		local nextDamage = u.TickEvery
		for i = 1, ticks do
			task.delay(i * u.ReelTick, function()
				local _, _, rr = alive(S, player)
				if not rr or state.Life ~= life then
					return
				end
				local point = rr.Position + rr.CFrame.LookVector * 4 + Vector3.new(0, 4, 0)
				local damageTick = i * u.ReelTick >= nextDamage
				if damageTick then
					nextDamage = nextDamage + u.TickEvery
				end
				for _, target in ipairs(snagged) do
					if target.Parent then
						pull(S, target, point, 3)
						local tr = target:FindFirstChild("HumanoidRootPart")
						if damageTick and tr then
							S.hit(player, target, { Damage = u.TickDamage, Stun = 0.6, Knockback = 0, Direction = point - tr.Position, Position = tr.Position, Source = "PorkPieWinch" })
						end
					end
				end
			end)
		end
		task.delay(u.ReelTime + 0.05, function()
			local _, _, rr = alive(S, player)
			if not rr or state.Life ~= life then
				return
			end
			local pos = rr.Position + rr.CFrame.LookVector * 4
			Moves.aoe(S, player, pos, u.SlamRadius, { Damage = u.SlamDamage, Stun = u.SlamStun, Knockback = u.SlamKnockback, Launch = u.SlamLaunch, Source = "PorkPieWinch" }, 8)
			S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Slam", Position = pos, Radius = u.SlamRadius })
		end)
	end)
end

function PorkPie.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
	end
	clearPan(S, state, "Expire")
end

return PorkPie
end

-- ======================================================================
-- MODULE: PorkPieOutfit
-- ======================================================================
__modules["PorkPieOutfit"] = function()
--[[
	PorkPieOutfit  (ServerScriptService.SpinServer.PorkPieOutfit)

	Gives a character Pork Pie Hat Kid's look while they play him (TuskAct 7),
	built from blocky parts so no catalog asset ids are needed (from the
	owner's pictures):
	  * green bamboo sticks tied round his bald head with a rope band,
	    sticking up and hanging down the sides like dreadlocks
	  * big round eyes with large black irises and bared teeth
	  * a green sleeveless suit with light-green studs in rows down both
	    sides of the chest and down both legs
	  * short golden feathers on the shoulders and a short frilly tutu
	  * big brown bracelets with leaves on both wrists
	The player's own hats/hair (and face) are hidden while they play him and
	come back when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local PorkPieOutfit = {}
PorkPieOutfit.Act = 7

local C = {
	Bamboo = Color3.fromRGB(130, 200, 70),
	BambooDark = Color3.fromRGB(80, 140, 45),
	BambooNode = Color3.fromRGB(175, 225, 110),
	Rope = Color3.fromRGB(150, 110, 70),
	Suit = Color3.fromRGB(95, 115, 45),
	SuitDark = Color3.fromRGB(70, 88, 32),
	Stud = Color3.fromRGB(165, 215, 80),
	Feather = Color3.fromRGB(215, 160, 60),
	FeatherDark = Color3.fromRGB(160, 105, 40),
	Bracelet = Color3.fromRGB(120, 75, 45),
	Leaf = Color3.fromRGB(200, 120, 50),
	EyeWhite = Color3.fromRGB(245, 245, 240),
	Iris = Color3.fromRGB(15, 15, 18),
	Teeth = Color3.fromRGB(250, 248, 235),
	Mouth = Color3.fromRGB(60, 25, 25),
}

local saved = setmetatable({}, { __mode = "k" })

local function piece(parent, outfit, name, size, color, offset)
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
	p.Material = Enum.Material.SmoothPlastic
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

-- One bamboo stick: a green rod with lighter node bands.
local function bamboo(head, outfit, s, cf, length)
	piece(head, outfit, "Bamboo", Vector3.new(0.26, length, 0.26) * s, C.Bamboo, cf)
	piece(head, outfit, "BambooNode", Vector3.new(0.3, 0.06, 0.3) * s, C.BambooNode, cf * CFrame.new(0, length * 0.15 * s, 0))
	piece(head, outfit, "BambooTip", Vector3.new(0.3, 0.05, 0.3) * s, C.BambooDark, cf * CFrame.new(0, length * 0.5 * s, 0))
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Rope band round the forehead (four sides) with a knot at the back.
	local bandY = h * 0.45
	piece(head, outfit, "Rope", Vector3.new(head.Size.X + 0.12 * s, 0.22 * s, 0.12 * s), C.Rope, CFrame.new(0, bandY, -d - 0.04 * s))
	piece(head, outfit, "Rope", Vector3.new(head.Size.X + 0.12 * s, 0.22 * s, 0.12 * s), C.Rope, CFrame.new(0, bandY, d + 0.04 * s))
	piece(head, outfit, "Rope", Vector3.new(0.12 * s, 0.22 * s, head.Size.Z + 0.12 * s), C.Rope, CFrame.new(-w - 0.04 * s, bandY, 0))
	piece(head, outfit, "Rope", Vector3.new(0.12 * s, 0.22 * s, head.Size.Z + 0.12 * s), C.Rope, CFrame.new(w + 0.04 * s, bandY, 0))
	piece(head, outfit, "RopeKnot", Vector3.new(0.3, 0.3, 0.2) * s, C.Rope, CFrame.new(0.2 * s, bandY, d + 0.12 * s))
	-- Bamboo crown: sticks pushed under the band, leaning out all round.
	local crown = {
		{ -0.45, -0.3, -0.25, 0.35 }, { -0.15, -0.35, -0.05, 0.1 }, { 0.15, -0.35, 0.05, -0.1 }, { 0.45, -0.3, 0.25, -0.35 },
		{ -0.5, 0.0, 0, 0.5 }, { 0.5, 0.0, 0, -0.5 }, { -0.3, 0.35, 0.35, 0.3 }, { 0.3, 0.35, 0.35, -0.3 }, { 0, 0.4, 0.4, 0 },
	}
	for _, b in ipairs(crown) do
		local base = CFrame.new(b[1] * head.Size.X, bandY + 0.2 * s, b[2] * head.Size.Z)
		bamboo(head, outfit, s, base * CFrame.Angles(b[3], 0, b[4]) * CFrame.new(0, 0.45 * s, 0), 1.0)
	end
	-- Sticks hanging down the sides and back like dreadlocks.
	local hang = { { -1, -0.25 }, { -1, 0.15 }, { 1, -0.25 }, { 1, 0.15 }, { -0.4, 1 }, { 0.4, 1 } }
	for _, b in ipairs(hang) do
		local x, z
		if math.abs(b[1]) == 1 then
			x, z = b[1] * (w + 0.18 * s), b[2] * head.Size.Z
		else
			x, z = b[1] * head.Size.X, d + 0.18 * s
		end
		local tilt = math.abs(b[1]) == 1 and CFrame.Angles(0, 0, b[1] * 0.25) or CFrame.Angles(-0.25, 0, 0)
		bamboo(head, outfit, s, CFrame.new(x, bandY - 0.45 * s, z) * tilt, 0.95)
	end
	-- Face: big round eyes with large black irises, bared teeth.
	local front = -d - 0.02 * s
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "EyeWhite", Vector3.new(0.4, 0.36, 0.04) * s, C.EyeWhite, CFrame.new(side * 0.25 * s, 0.08 * s, front))
		piece(head, outfit, "Iris", Vector3.new(0.28, 0.28, 0.04) * s, C.Iris, CFrame.new(side * 0.25 * s, 0.07 * s, front - 0.02 * s))
	end
	piece(head, outfit, "Mouth", Vector3.new(0.62, 0.24, 0.04) * s, C.Mouth, CFrame.new(0, -0.3 * s, front))
	piece(head, outfit, "Teeth", Vector3.new(0.58, 0.08, 0.04) * s, C.Teeth, CFrame.new(0, -0.23 * s, front - 0.02 * s))
	piece(head, outfit, "Teeth", Vector3.new(0.58, 0.08, 0.04) * s, C.Teeth, CFrame.new(0, -0.37 * s, front - 0.02 * s))
	-- Large angular jaw.
	piece(head, outfit, "Jaw", Vector3.new(head.Size.X * 0.9, 0.18 * s, head.Size.Z * 0.85), head.Color, CFrame.new(0, -h - 0.02 * s, -0.05 * s))
end

-- Green suit shell over a body part, with a row of studs on the front.
local function suit(part, outfit, studsX, studCount)
	local s = part.Size
	piece(part, outfit, "Suit", s + Vector3.new(0.1, 0.04, 0.1), C.Suit, CFrame.new())
	for _, x in ipairs(studsX) do
		for i = 1, studCount do
			local y = s.Y / 2 - (i - 0.5) * s.Y / studCount
			piece(part, outfit, "Stud", Vector3.new(0.24, 0.2, 0.12), C.Stud, CFrame.new(x * s.X / 2, y, -s.Z / 2 - 0.08))
		end
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		suit(upper, outfit, { -0.55, 0.55 }, lower and 3 or 4)
		-- Short feathers on both shoulders.
		for _, side in ipairs({ -1, 1 }) do
			for k = 0, 2 do
				local cf = CFrame.new(side * (upper.Size.X / 2 - 0.1), upper.Size.Y / 2 - 0.05, -0.25 + k * 0.25)
					* CFrame.Angles(0, 0, side * (-0.9 - k * 0.15)) * CFrame.new(0, 0.35, 0)
				piece(upper, outfit, "Feather", Vector3.new(0.18, 0.8, 0.3), k % 2 == 0 and C.Feather or C.FeatherDark, cf)
			end
		end
	end
	local waist = lower or upper
	if waist then
		if lower then
			suit(lower, outfit, {}, 0)
		end
		-- Short frilly tutu round the waist.
		local y = lower and -lower.Size.Y * 0.25 or -upper.Size.Y / 2 + 0.1
		local rx, rz = waist.Size.X / 2 + 0.15, waist.Size.Z / 2 + 0.15
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			local pos = Vector3.new(math.cos(a) * rx, y, math.sin(a) * rz)
			local cf = CFrame.lookAt(pos, pos + Vector3.new(math.cos(a), 0, math.sin(a))) * CFrame.Angles(-0.55, 0, 0)
			piece(waist, outfit, "Tutu", Vector3.new(0.7, 0.12, 0.7), i % 2 == 0 and C.Suit or C.SuitDark, cf)
		end
	end
	-- Legs: suit with studs down the front.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			suit(leg, outfit, { 0 }, name:find("Leg") and leg.Size.Y > 1.8 and 4 or 2)
		end
	end
	-- Sleeveless: bare arms (skin-coloured sleeves over whatever shirt the avatar wears).
	local headPart = character:FindFirstChild("Head")
	local skin = headPart and headPart.Color or Color3.fromRGB(230, 185, 140)
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Skin", arm.Size + Vector3.new(0.04, 0.02, 0.04), skin, CFrame.new())
		end
	end
	-- Big bracelets with leaves on both wrists.
	for _, name in ipairs({ "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local y = -arm.Size.Y / 2 + (arm.Size.Y > 1.8 and 0.55 or 0.25)
			piece(arm, outfit, "Bracelet", Vector3.new(arm.Size.X + 0.22, 0.45, arm.Size.Z + 0.22), C.Bracelet, CFrame.new(0, y, 0))
			piece(arm, outfit, "Leaf", Vector3.new(0.5, 0.08, 0.32), C.Leaf, CFrame.new(0, y + 0.1, -arm.Size.Z / 2 - 0.16) * CFrame.Angles(0.4, 0, 0.5))
			piece(arm, outfit, "Leaf", Vector3.new(0.4, 0.08, 0.26), C.FeatherDark, CFrame.new(0.15, y - 0.08, -arm.Size.Z / 2 - 0.15) * CFrame.Angles(-0.3, 0, -0.6))
		end
	end
end

function PorkPieOutfit.apply(character)
	if character:FindFirstChild("PorkPieOutfit") then
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
	local face = head:FindFirstChildOfClass("Decal")
	if face then
		store.Hidden[face] = face.Transparency
		face.Transparency = 1
	end
	local outfit = Instance.new("Model")
	outfit.Name = "PorkPieOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function PorkPieOutfit.remove(character)
	local outfit = character:FindFirstChild("PorkPieOutfit")
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
		if character:GetAttribute("TuskAct") == PorkPieOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == PorkPieOutfit.Act then
					PorkPieOutfit.apply(character)
				end
			end)
		else
			PorkPieOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function PorkPieOutfit.init()
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

return PorkPieOutfit
end
end
