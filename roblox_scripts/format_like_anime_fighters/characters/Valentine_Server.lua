--[[
	Valentine_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Funny Valentine: D4C (Dirty Deeds Done Dirt Cheap).
	Its other half is Valentine_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: Valentine
-- ======================================================================
__modules["Valentine"] = function()
--[[
	Valentine  (ServerScriptService.SpinServer.TuskActs.Valentine)

	Funny Valentine: D4C (Dirty Deeds Done Dirt Cheap). Sandwiched between
	two things (a flag wrapped round him) he slips into a parallel world and
	out again somewhere else; he brings people across from other worlds;
	and with Love Train, misfortune can't reach him: it lands on someone
	else. Registered as "Act" 13 so it reuses the Tusk ability system.
	  M1        DIRTY DEEDS COMBO: D4C chops with him
	  Ability 1 DIMENSION HOP: a flag sweeps over him (he can't be hit while
	            he's between worlds) and he steps out behind the nearest enemy
	            in front, striking them; with nobody there, he hops ahead. He
	            leaves a flag where he was: press again within 4 s to hop back
	  Ability 2 PARALLEL VALENTINE: a Valentine from another world joins the
	            fight for a few seconds, chasing and punching the nearest enemy.
	            If he's nearly beaten while it's out, they SWAP: he takes its
	            place (healed) and it's gone
	  Ability 3 MENGER SPONGE: the nearest enemy's other-world self appears
	            beside them: two of the same person can't exist together, so
	            they crumble into cubes (slowed, ticks of damage), then burst,
	            hitting whoever's next to them. They only crumble near their
	            double: running away from it ends it
	  Ultimate  D4C LOVE TRAIN: a wall of light: every hit on him is
	            cancelled and the misfortune lands on the nearest enemy
	            instead; he moves faster; it ends with a pulse of light
Numbers: TuskConfig.Valentine. All damage goes through S.hit (CombatAdapter).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Valentine = {}
local cfg = TuskConfig.Valentine
local ACT = 13

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

function Valentine.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

local function slow(S, target, key, multiplier, seconds)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	S.Adapter.setMoveModifier(humanoid, key, multiplier)
	local token = tostring({})
	target:SetAttribute(key .. "Token", token)
	task.delay(seconds, function()
		if humanoid.Parent and target:GetAttribute(key .. "Token") == token then
			S.Adapter.setMoveModifier(humanoid, key, nil)
			target:SetAttribute(key .. "Token", nil)
		end
	end)
end

-- Nearest enemy (optionally only in a cone in front).
local function nearest(S, character, root, range, direction, cone)
	local look = direction and Moves.flat(direction)
	local cosLimit = cone and math.cos(math.rad(cone / 2))
	local best, bestD
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, range, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		local hum = target:FindFirstChildOfClass("Humanoid")
		if tr and hum and hum.Health > 0 and S.Adapter.canBeHit(nil, target) then
			local offset = tr.Position - root.Position
			local f = Vector3.new(offset.X, 0, offset.Z)
			if not look or f.Magnitude < 1 or f.Unit:Dot(look) >= cosLimit then
				if not bestD or offset.Magnitude < bestD then
					best, bestD = target, offset.Magnitude
				end
			end
		end
	end
	return best
end

---------------------------------------------------------------------------
-- DIMENSION HOP
---------------------------------------------------------------------------
-- Step out of another world at `to` (shared by the hop and the hop back).
local function hopThrough(S, player, state, c, to, facing, onArrive)
	local character, _, root = alive(S, player)
	local life = state.Life
	S.lock(state, c.Windup + 0.3)
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	S.fx("Ability", { Character = character, Act = ACT, Move = "DimensionHop", Phase = "Wrap", Position = root.Position, Windup = c.Windup })
	task.delay(c.Windup, function()
		character:SetAttribute(iframes, nil)
		if not S.stillValid(player, state, life) then
			return
		end
		local char = alive(S, player)
		local dest, face = to(), facing()
		local flatFace = Vector3.new(face.X, dest.Y, face.Z)
		char:PivotTo((flatFace - dest).Magnitude > 0.1 and CFrame.lookAt(dest, flatFace) or CFrame.new(dest))
		S.fx("Ability", { Character = char, Act = ACT, Move = "DimensionHop", Phase = "Unwrap", Position = dest })
		if onArrive then
			onArrive(char, dest)
		end
	end)
end

local function dimensionHop(S, player, state, aim)
	local c = cfg.DimensionHop
	-- Hop back through the flag he left (doesn't need the cooldown).
	local back = state.HopReturn
	if back and now() < back.Until and not S.isBusy(state) and not state.Charging then
		state.HopReturn = nil
		local character = alive(S, player)
		S.fx("Ability", { Character = character, Act = ACT, Move = "DimensionHop", Phase = "AnchorGone" })
		hopThrough(S, player, state, c, function()
			return back.Pos
		end, function()
			return back.Pos + back.Facing
		end)
		return
	end
	if not ready(S, player, state, "DimensionHop", 1) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	-- Where he'll step out: behind the nearest enemy in front, or straight ahead.
	local target = nearest(S, character, root, c.Range, direction, c.Cone)
	local tr = target and target:FindFirstChild("HumanoidRootPart")
	local destination, facing
	if tr then
		local behind = -Moves.flat(tr.CFrame.LookVector)
		destination = Moves.safeStep(character, tr, behind, 5) or Moves.safeStep(character, tr, -behind, 5)
		facing = tr.Position
	end
	if not destination then
		target, tr = nil, nil
		destination = Moves.safeStep(character, root, direction, c.Distance)
		facing = destination and destination + direction
	end
	if not destination then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "DimensionHop", c.Cooldown, 1)
	-- He leaves a flag where he was: press again soon to hop back to it.
	local from, fromFacing = root.Position, Moves.flat(root.CFrame.LookVector)
	hopThrough(S, player, state, c, function()
		-- The target may have moved: step out behind where they are now.
		if tr and tr.Parent then
			local behind = -Moves.flat(tr.CFrame.LookVector)
			destination = Moves.safeStep(alive(S, player), tr, behind, 5) or destination
			facing = tr.Position
		end
		return destination
	end, function()
		return facing
	end, function(char, dest)
		state.HopReturn = { Pos = from, Facing = fromFacing, Until = now() + c.ReturnWindow }
		S.fx("Ability", { Character = char, Act = ACT, Move = "DimensionHop", Phase = "Anchor", Position = from, Duration = c.ReturnWindow })
		-- Out of the other world: a strike at whoever he came for.
		if target and tr and (tr.Position - dest).Magnitude <= c.StrikeRange then
			S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = tr.Position - dest, Position = tr.Position, Source = "ValentineHop" })
		end
	end)
end

---------------------------------------------------------------------------
-- PARALLEL VALENTINE: a Valentine from another world fights with him
---------------------------------------------------------------------------
local nextClone = 0

local function parallelClone(S, player, state)
	local c = cfg.ParallelClone
	if not ready(S, player, state, "ParallelClone", 2) then
		return
	end
	S.startCooldown(player, state, "ParallelClone", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.2)
	local character, _, root = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "ParallelClone", Phase = "Call", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		nextClone = nextClone + 1
		local id = nextClone
		local pos = (r.CFrame * CFrame.new(-3, 0, 0)).Position
		local untilT = now() + c.Duration
		char:SetAttribute("ParallelCloneUntil", untilT)
		S.fx("Ability", { Character = char, Act = ACT, Move = "ParallelClone", Phase = "Arrive", Id = id, From = pos, Duration = c.Duration, Speed = c.Speed })
		local born = now()
		local punches, nextPunch, target = 0, 0, nil
		local step = 0.1
		local swapped = false
		local function tick()
			local _, myHum, myRoot = alive(S, player)
			-- Nearly beaten while his other self is out: they swap places.
			if myHum and myRoot and not swapped and myHum.Health > 0 and myHum.Health <= myHum.MaxHealth * c.SwapAt and state.Life == life then
				swapped = true
				local old = myRoot.Position
				myHum.Health = math.min(myHum.MaxHealth, myHum.Health + myHum.MaxHealth * c.SwapHeal)
				local at = Vector3.new(pos.X, old.Y, pos.Z)
				char:PivotTo(CFrame.lookAt(at, at + Moves.flat(myRoot.CFrame.LookVector)))
				char:SetAttribute("ParallelCloneUntil", nil)
				S.fx("Ability", { Character = char, Act = ACT, Move = "ParallelClone", Phase = "Swap", Id = id, From = old, To = at })
				return
			end
			if not myRoot or state.Life ~= life or now() - born > c.Duration or punches >= c.MaxPunches then
				char:SetAttribute("ParallelCloneUntil", nil)
				S.fx("Ability", { Act = ACT, Move = "ParallelClone", Phase = "Leave", Id = id, Position = pos })
				return
			end
			-- Pick the enemy nearest to Valentine (re-picked as they move).
			local pick = nearest(S, char, myRoot, c.Range)
			if pick ~= target then
				target = pick
				S.fx("Ability", { Act = ACT, Move = "ParallelClone", Phase = "Chase", Id = id, Target = target, From = pos })
			end
			local tr = target and target:FindFirstChild("HumanoidRootPart")
			local goal = tr and tr.Position or (myRoot.CFrame * CFrame.new(-3, 0, 2)).Position
			local to = goal - pos
			local reach = tr and c.PunchRange or 2
			if to.Magnitude > reach then
				pos = pos + to.Unit * math.min(c.Speed * step, to.Magnitude - reach * 0.8)
			elseif tr and now() >= nextPunch then
				nextPunch = now() + c.PunchEvery
				punches = punches + 1
				S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = to, Position = tr.Position, Source = "ValentineClone" })
				S.fx("Ability", { Act = ACT, Move = "ParallelClone", Phase = "Punch", Id = id, Position = tr.Position, From = pos })
			end
			task.delay(step, tick)
		end
		tick()
	end)
end

---------------------------------------------------------------------------
-- MENGER SPONGE: their other-world self appears and they crumble into cubes
---------------------------------------------------------------------------
local function mengerSponge(S, player, state, aim)
	local c = cfg.MengerSponge
	if not ready(S, player, state, "MengerSponge", 3) then
		return
	end
	S.startCooldown(player, state, "MengerSponge", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.25)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "MengerSponge", Phase = "Cast", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local target = nearest(S, char, r, c.Range, direction, c.Cone)
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		if not tr or not S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = direction, Position = tr.Position, Source = "ValentineMenger" }) then
			S.startCooldown(player, state, "MengerSponge", c.MissCooldown, 3)
			S.fx("Ability", { Character = char, Act = ACT, Move = "MengerSponge", Phase = "Miss", Direction = direction })
			return
		end
		local untilT = now() + c.Time
		local token = tostring({}) -- only this cast's ticks may act (a newer one replaces it)
		target:SetAttribute("MengerUntil", untilT)
		target:SetAttribute("MengerCast", token)
		slow(S, target, "Menger", c.Slow, c.Time)
		-- Their double appears right beside them, and stays put.
		local doublePos = (tr.CFrame * CFrame.new(c.DoubleOffset, 0, 0)).Position
		S.fx("Ability", { Character = char, Act = ACT, Move = "MengerSponge", Phase = "Crumble", Target = target, Duration = c.Time, DoublePos = doublePos, Leash = c.Leash })
		local ticks = math.floor(c.Time / c.Tick)
		for i = 1, ticks do
			task.delay(i * c.Tick, function()
				local t = target:FindFirstChild("HumanoidRootPart")
				if not t or target:GetAttribute("MengerCast") ~= token or not target:GetAttribute("MengerUntil") then
					return
				end
				-- Got away from their double: it's over.
				if (t.Position - doublePos).Magnitude > c.Leash then
					target:SetAttribute("MengerUntil", nil)
					local hum = target:FindFirstChildOfClass("Humanoid")
					if hum then
						S.Adapter.setMoveModifier(hum, "Menger", nil)
					end
					S.fx("Ability", { Act = ACT, Move = "MengerSponge", Phase = "Escape", Position = t.Position, Target = target, DoublePos = doublePos })
					return
				end
				local last = i == ticks
				S.hit(player, target, {
					Damage = c.TickDamage + c.TickGrowth * (i - 1) + (last and c.FinalDamage or 0),
					Stun = last and c.FinalStun or 0.25,
					Knockback = last and c.FinalKnockback or 0,
					Direction = t.Position - r.Position,
					Position = t.Position,
					Source = "ValentineMenger",
				})
				if last then
					target:SetAttribute("MengerUntil", nil)
					-- The burst catches whoever's right next to them.
					Moves.aoe(S, player, t.Position, c.BurstRadius, { Damage = c.BurstDamage, Stun = 0.5, Knockback = 20, Source = "ValentineMenger" }, 6, { [target] = true })
					S.fx("Ability", { Act = ACT, Move = "MengerSponge", Phase = "Burst", Position = t.Position, Target = target, Radius = c.BurstRadius })
				end
			end)
		end
	end)
end

function Valentine.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		dimensionHop(S, player, state, aim)
	elseif slot == 2 then
		parallelClone(S, player, state)
	elseif slot == 3 then
		mengerSponge(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- D4C LOVE TRAIN (ultimate)
---------------------------------------------------------------------------
local trains = setmetatable({}, { __mode = "k" }) -- [character] = redirect function while it's up

local function registerTrain(S)
	if S.Adapter.DodgeHandlers and not S.Adapter.DodgeHandlers.LoveTrain then
		S.Adapter.DodgeHandlers.LoveTrain = function(attackerPlayer, target, info)
			local f = trains[target]
			if f then
				f(attackerPlayer, info)
			end
		end
	end
end

function Valentine.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	registerTrain(S)
	local character, humanoid = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.2)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Board", Windup = u.Windup, Duration = u.Duration })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		character:SetAttribute("LoveTrain", true)
		S.Adapter.setMoveModifier(humanoid, "LoveTrain", u.SpeedMultiplier)
		local lastRedirect = -math.huge
		-- Misfortune can't reach him: it lands on the nearest enemy instead.
		trains[character] = function(attackerPlayer, info)
			-- (Misfortune already bounced once is just cancelled: no ping-pong
			-- between two Love Trains.)
			if now() - lastRedirect < u.RedirectEvery or (info and info.Source == "ValentineLoveTrain") then
				return
			end
			lastRedirect = now()
			local _, _, r = alive(S, player)
			if not r then
				return
			end
			local victim = nearest(S, character, r, u.RedirectRange)
			local vr = victim and victim:FindFirstChild("HumanoidRootPart")
			S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Redirect", From = r.Position, To = vr and vr.Position, Victim = victim })
			if vr then
				local damage = math.max(u.RedirectMin, (tonumber(info and info.Damage) or 0) * u.RedirectShare)
				S.hit(player, victim, { Damage = damage, Stun = 0.5, Knockback = 10, Direction = vr.Position - r.Position, Position = vr.Position, Source = "ValentineLoveTrain" })
			end
		end
		task.delay(u.Duration, function()
			trains[character] = nil
			if character.Parent then
				character:SetAttribute("LoveTrain", nil)
			end
			if humanoid.Parent then
				S.Adapter.setMoveModifier(humanoid, "LoveTrain", nil)
			end
			if state.Life ~= life then
				return
			end
			local _, _, r = alive(S, player)
			if r then
				Moves.aoe(S, player, r.Position, u.PulseRadius, { Damage = u.PulseDamage, Stun = u.PulseStun, Knockback = u.PulseKnockback, Source = "ValentineLoveTrain" }, 8)
				S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Pulse", Position = r.Position, Radius = u.PulseRadius })
			end
		end)
	end)
end

function Valentine.Cleanup(S, player, state)
	state.HopReturn = nil
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("LoveTrain", nil)
		character:SetAttribute("ParallelCloneUntil", nil)
		trains[character] = nil
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "LoveTrain", nil)
		end
	end
end

return Valentine
end

-- ======================================================================
-- MODULE: ValentineOutfit
-- ======================================================================
__modules["ValentineOutfit"] = function()
--[[
	ValentineOutfit  (ServerScriptService.SpinServer.ValentineOutfit)

	Gives a character Funny Valentine's look while they play him (TuskAct
	13), built from blocky parts (no catalog asset ids), matched to his art:
	  * long wavy blond hair down to his shoulders with big spiral ringlets
	    at the sides
	  * a pink long coat: a high grey collar, ribbed sleeves with grey
	    ruffled cuffs, the skirt flaring down to his calves
	  * magenta padded trousers with a belt, tall magenta boots
	  * magenta gloves with a lattice pattern
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local ValentineOutfit = {}
ValentineOutfit.Act = 13

local C = {
	Hair = Color3.fromRGB(238, 218, 130),
	HairDark = Color3.fromRGB(204, 180, 96),
	Coat = Color3.fromRGB(232, 150, 196),
	CoatShade = Color3.fromRGB(200, 116, 166),
	CoatDark = Color3.fromRGB(170, 86, 136),
	Collar = Color3.fromRGB(120, 116, 124),
	Pants = Color3.fromRGB(196, 96, 210),
	PantsShade = Color3.fromRGB(160, 70, 178),
	Belt = Color3.fromRGB(120, 54, 136),
	Glove = Color3.fromRGB(214, 110, 196),
	GloveLine = Color3.fromRGB(150, 60, 140),
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

-- A spiral ringlet: a ring of blocks curling round, facing sideways.
local function ringlet(head, outfit, cf, r, s)
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		local rr = r * (1 - k * 0.07)
		piece(head, outfit, "Ringlet", Vector3.new(0.14 * s, 0.2 * s, 0.2 * s), k % 2 == 0 and C.Hair or C.HairDark, cf * CFrame.new(0, math.sin(a) * rr, math.cos(a) * rr) * CFrame.Angles(-a, 0, 0))
	end
	piece(head, outfit, "RingletCore", Vector3.new(0.14 * s, 0.14 * s, 0.14 * s), C.HairDark, cf)
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Long wavy blond hair: over the top, a side part, down past the shoulders at the back.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.18 * s, 0.32 * s, head.Size.Z + 0.18 * s), C.Hair, CFrame.new(0, h - 0.02 * s, 0.02 * s))
	piece(head, outfit, "Bangs", Vector3.new(head.Size.X * 0.7, 0.3 * s, 0.12 * s), C.Hair, CFrame.new(-0.14 * s, h - 0.24 * s, -d - 0.04 * s) * CFrame.Angles(0, 0, 0.25))
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.3 * s, 1.5 * s, 0.26 * s), C.Hair, CFrame.new(0, -0.4 * s, d + 0.1 * s))
	piece(head, outfit, "HairWave", Vector3.new(head.Size.X + 0.34 * s, 0.12 * s, 0.28 * s), C.HairDark, CFrame.new(0, -0.6 * s, d + 0.11 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.18 * s, 1.2 * s, head.Size.Z * 0.85), C.Hair, CFrame.new(side * (w + 0.08 * s), -0.2 * s, 0.06 * s))
		-- Big spiral ringlets at the sides, one high and one at the shoulder.
		ringlet(head, outfit, CFrame.new(side * (w + 0.26 * s), 0.05 * s, -0.05 * s), 0.3 * s, s)
		ringlet(head, outfit, CFrame.new(side * (w + 0.22 * s), -0.75 * s, 0.15 * s), 0.26 * s, s)
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Coat", s + Vector3.new(0.1, 0.02, 0.1), C.Coat, CFrame.new())
		-- High grey collar.
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.6, 0.44, s.Z + 0.22), C.Collar, CFrame.new(0, top + 0.16, 0.02))
		piece(upper, outfit, "CollarFold", Vector3.new(s.X * 0.75, 0.2, s.Z + 0.26), C.CoatShade, CFrame.new(0, top - 0.02, 0.02))
		-- The coat closes in a diagonal line across the chest.
		piece(upper, outfit, "Closure", Vector3.new(0.08, s.Y * 1.05, 0.05), C.CoatDark, CFrame.new(0.15, -0.05, front - 0.06) * CFrame.Angles(0, 0, -0.18))
		piece(upper, outfit, "Panel", Vector3.new(s.X * 0.45, s.Y * 0.9, 0.05), C.CoatShade, CFrame.new(-0.42, -0.05, front - 0.05))
	end
	-- Long flaring coat skirt (front split), magenta trousers with a belt.
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.3
		if lower then
			piece(lower, outfit, "Pants", ws + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
		end
		piece(waist, outfit, "Belt", Vector3.new(ws.X + 0.1, 0.16, ws.Z + 0.1), C.Belt, CFrame.new(0, waistTop - 0.12, 0))
		local skirtH = lower and 2.4 or 2.0
		for _, side in ipairs({ -1, 1 }) do
			-- Front panels pulled back to the sides (the trousers show in the middle).
			piece(waist, outfit, "Skirt", Vector3.new(ws.X * 0.3, skirtH, 0.12), C.Coat, CFrame.new(side * (ws.X / 2 - 0.1), waistTop - skirtH / 2, -ws.Z / 2 - 0.1) * CFrame.Angles(0, side * 0.35, side * -0.05))
			piece(waist, outfit, "Skirt", Vector3.new(0.12, skirtH, ws.Z + 0.3), C.CoatShade, CFrame.new(side * (ws.X / 2 + 0.16), waistTop - skirtH / 2, 0.06) * CFrame.Angles(0, 0, side * -0.06))
		end
		piece(waist, outfit, "SkirtBack", Vector3.new(ws.X + 0.5, skirtH + 0.1, 0.12), C.Coat, CFrame.new(0, waistTop - skirtH / 2 - 0.05, ws.Z / 2 + 0.14) * CFrame.Angles(0.06, 0, 0))
		piece(waist, outfit, "Hem", Vector3.new(ws.X + 0.56, 0.1, 0.14), C.CoatDark, CFrame.new(0, waistTop - skirtH - 0.02, ws.Z / 2 + 0.22))
	end
	-- Ribbed pink sleeves with grey ruffled cuffs.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local tall = as.Y > 1.8
			local h = tall and as.Y - 0.3 or as.Y
			piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.1, h + 0.02, as.Z + 0.1), C.Coat, CFrame.new(0, as.Y / 2 - h / 2, 0))
			local y = as.Y / 2 - 0.25
			while y > as.Y / 2 - h + 0.15 do
				piece(arm, outfit, "Rib", Vector3.new(as.X + 0.16, 0.08, as.Z + 0.16), C.CoatShade, CFrame.new(0, y, 0))
				y = y - 0.3
			end
			if name:find("Lower") or tall then
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.2, 0.26, as.Z + 0.2), C.Collar, CFrame.new(0, as.Y / 2 - h + 0.05, 0))
			end
		end
	end
	-- Magenta lattice gloves.
	for _, name in ipairs({ "LeftHand", "RightHand" }) do
		local hand = character:FindFirstChild(name)
		if hand then
			local hs = hand.Size
			piece(hand, outfit, "Glove", hs + Vector3.new(0.08, 0.06, 0.08), C.Glove, CFrame.new())
			for _, a in ipairs({ 0.7, -0.7 }) do
				piece(hand, outfit, "Lattice", Vector3.new(hs.X * 1.2, 0.04, 0.04), C.GloveLine, CFrame.new(0, 0, -hs.Z / 2 - 0.06) * CFrame.Angles(0, 0, a))
			end
		end
	end
	-- Padded magenta trousers and tall boots.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Pants", ls + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
			piece(leg, outfit, "Pad", Vector3.new(ls.X * 0.7, ls.Y * 0.4, 0.06), C.PantsShade, CFrame.new(0, ls.Y * 0.12, -ls.Z / 2 - 0.05))
			if name:find("Lower") or ls.Y > 1.8 then
				local bh = ls.Y > 1.8 and 1.0 or ls.Y + 0.05
				piece(leg, outfit, "Boot", Vector3.new(ls.X + 0.12, bh, ls.Z + 0.12), C.Pants, CFrame.new(0, -ls.Y / 2 + bh / 2, 0))
				piece(leg, outfit, "BootTop", Vector3.new(ls.X + 0.16, 0.12, ls.Z + 0.16), C.PantsShade, CFrame.new(0, -ls.Y / 2 + bh, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Boot", foot.Size + Vector3.new(0.1, 0.06, 0.14), C.PantsShade, CFrame.new(0, 0, -0.03))
		end
	end
end

function ValentineOutfit.apply(character)
	if character:FindFirstChild("ValentineOutfit") then
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
	outfit.Name = "ValentineOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function ValentineOutfit.remove(character)
	local outfit = character:FindFirstChild("ValentineOutfit")
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
		if character:GetAttribute("TuskAct") == ValentineOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == ValentineOutfit.Act then
					ValentineOutfit.apply(character)
				end
			end)
		else
			ValentineOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function ValentineOutfit.init()
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

return ValentineOutfit
end
end
