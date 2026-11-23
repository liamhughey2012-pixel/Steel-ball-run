--[[
	Axl_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Axl RO: Civil War.
	Its other half is Axl_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: Axl
-- ======================================================================
__modules["Axl"] = function()
--[[
	Axl  (ServerScriptService.SpinServer.TuskActs.Axl)

	Axl RO: CIVIL WAR. His Stand makes a target's guilt real: the people
	they left behind rise as specters, the things they abandoned fly at them,
	and their guilt wraps them in a membrane that shrinks until it crushes
	them. Water washes guilt away: in the rain the membrane dissolves twice
	as fast. Registered as "Act" 12 so it reuses the Tusk ability system.
	  M1        GUILT COMBO: strikes with Civil War's long arms
	  Ability 1 GUILT SPECTER: a ghost rises out of the nearest enemy's shadow
	            (a warning first, so they can dodge out) and grabs them
	  Ability 2 ABANDONED JUNK: a volley of junk (crates, wheels, chairs...)
	  Ability 3 GUILT MEMBRANE: the nearest enemy is wrapped in a membrane:
	            slowed, squeezed harder every tick, then crushed
	  Ultimate  CIVIL WAR: the junkyard rises round him: specters grab
	            everyone nearby and engulf them; while it lasts Civil War
	            breaks apart when he's hit (the hit misses, he reforms out of
	            reach); then the membranes crush everyone at once
Numbers: TuskConfig.Axl. All damage goes through S.hit (CombatAdapter).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Axl = {}
local cfg = TuskConfig.Axl
local ACT = 12

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

-- Water washes guilt away: shorter in the rain.
local function rainy()
	return game:GetService("ReplicatedStorage"):GetAttribute("SpinRaining") == true
end

function Axl.M1(S, player, state, aim)
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

-- Nearest enemy in a cone in front.
local function targetInCone(S, character, root, direction, range, cone)
	local look = Moves.flat(direction)
	local cosLimit = math.cos(math.rad(cone / 2))
	local best, bestD
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, range, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and S.Adapter.canBeHit(nil, target) then
			local offset = tr.Position - root.Position
			local f = Vector3.new(offset.X, 0, offset.Z)
			if (f.Magnitude < 1 or f.Unit:Dot(look) >= cosLimit) and S.Hitbox.lineOfSight(root.Position, tr.Position, { character, target }) then
				if not bestD or offset.Magnitude < bestD then
					best, bestD = target, offset.Magnitude
				end
			end
		end
	end
	return best
end

---------------------------------------------------------------------------
-- The membrane (Guilt Membrane and the ultimate): slowed, squeezed harder
-- each tick, then crushed. Rain halves how long it lasts.
---------------------------------------------------------------------------
local function engulf(S, player, target, opts)
	local t = opts.Time * (rainy() and (opts.RainMultiplier or 0.5) or 1)
	local untilT = now() + t
	target:SetAttribute("GuiltMembraneUntil", untilT)
	slow(S, target, "GuiltMembrane", opts.Slow, t)
	local ticks = math.max(1, math.floor(t / opts.Tick))
	for i = 1, ticks do
		task.delay(i * opts.Tick, function()
			local tr = target:FindFirstChild("HumanoidRootPart")
			-- (Ends early if the membrane was cleared, e.g. a new life.)
			if not tr or (target:GetAttribute("GuiltMembraneUntil") or 0) < untilT - 0.01 then
				return
			end
			local last = i == ticks
			local damage = (opts.TickDamage + (opts.TickGrowth or 0) * (i - 1)) + (last and (opts.FinalDamage or 0) or 0)
			S.hit(player, target, {
				Damage = damage,
				Stun = last and (opts.FinalStun or 0.5) or 0.3,
				Knockback = last and (opts.FinalKnockback or 0) or 0,
				Launch = last and opts.FinalLaunch or nil,
				Direction = Vector3.new(0, -1, 0),
				Position = tr.Position,
				Source = opts.Source,
			})
			if last then
				target:SetAttribute("GuiltMembraneUntil", nil)
			end
		end)
	end
	return t
end

---------------------------------------------------------------------------
-- GUILT SPECTER
---------------------------------------------------------------------------
local function guiltSpecter(S, player, state, aim)
	local c = cfg.GuiltSpecter
	if not ready(S, player, state, "GuiltSpecter", 1) then
		return
	end
	S.startCooldown(player, state, "GuiltSpecter", c.Cooldown, 1)
	S.lock(state, c.Windup + 0.25)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "GuiltSpecter", Phase = "Cast", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local target = targetInCone(S, char, r, direction, c.Range, c.Cone)
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		if not tr then
			S.startCooldown(player, state, "GuiltSpecter", c.MissCooldown, 1)
			S.fx("Ability", { Character = char, Act = ACT, Move = "GuiltSpecter", Phase = "Miss" })
			return
		end
		-- It rises where they're standing now: they get a moment to dodge out.
		local spot = Moves.groundBelow(tr.Position, { target })
		S.fx("Ability", { Character = char, Act = ACT, Move = "GuiltSpecter", Phase = "Warn", Position = spot, Rise = c.Rise, Radius = c.Radius, Target = target })
		task.delay(c.Rise, function()
			if state.Life ~= life then
				return
			end
			local hit = 0
			for _, victim in ipairs(S.Hitbox.inRadius(char, spot + Vector3.new(0, 2.5, 0), c.Radius, 3)) do
				local vr = victim:FindFirstChild("HumanoidRootPart")
				if vr and S.hit(player, victim, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = vr.Position - spot, Position = vr.Position, Source = "AxlSpecter" }) then
					hit = hit + 1
				end
			end
			S.fx("Ability", { Character = char, Act = ACT, Move = "GuiltSpecter", Phase = "Rise", Position = spot, Hit = hit > 0 })
		end)
	end)
end

---------------------------------------------------------------------------
-- ABANDONED JUNK
---------------------------------------------------------------------------
local JUNK = { "Crate", "Wheel", "Chair", "Bottle", "Boot", "Lamp" }

local function abandonedJunk(S, player, state, aim)
	local c = cfg.AbandonedJunk
	if not ready(S, player, state, "AbandonedJunk", 2) then
		return
	end
	S.startCooldown(player, state, "AbandonedJunk", c.Cooldown, 2)
	S.lock(state, c.Startup + 0.25)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local flat = Moves.flat(direction)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "AbandonedJunk", Phase = "Gather", Startup = c.Startup, Direction = flat, Count = c.Count })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local _, _, r = alive(S, player)
		local hits = {}
		for i = 1, c.Count do
			local t = c.Count == 1 and 0 or (i - 1) / (c.Count - 1) - 0.5
			local dir = (CFrame.lookAt(Vector3.new(), direction) * CFrame.Angles(math.rad((i % 2) * 4), math.rad(-t * c.Spread), 0)).LookVector
			local side = CFrame.lookAt(Vector3.new(), flat).RightVector
			local origin = r.Position + Vector3.new(0, 1.5 + (i % 3) * 0.6, 0) + flat * 2 + side * t * 5
			S.fireJunk(player, state, {
				Origin = origin,
				Direction = dir,
				Speed = c.Speed,
				Radius = c.Radius,
				Range = c.Range,
				Style = JUNK[(i - 1) % #JUNK + 1],
				OnHit = function(target, position)
					hits[target] = (hits[target] or 0) + 1
					if hits[target] <= c.MaxHitsPerTarget then
						S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Position = position, Source = "AxlJunk" })
					end
				end,
			})
		end
	end)
end

---------------------------------------------------------------------------
-- GUILT MEMBRANE
---------------------------------------------------------------------------
local function guiltMembrane(S, player, state, aim)
	local c = cfg.GuiltMembrane
	if not ready(S, player, state, "GuiltMembrane", 3) then
		return
	end
	S.startCooldown(player, state, "GuiltMembrane", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.25)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "GuiltMembrane", Phase = "Cast", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local target = targetInCone(S, char, r, direction, c.Range, c.Cone)
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		if not tr or not S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = direction, Position = tr.Position, Source = "AxlMembrane" }) then
			S.startCooldown(player, state, "GuiltMembrane", c.MissCooldown, 3)
			S.fx("Ability", { Character = char, Act = ACT, Move = "GuiltMembrane", Phase = "Miss", Direction = direction })
			return
		end
		local t = engulf(S, player, target, {
			Time = c.Time, Tick = c.Tick, TickDamage = c.TickDamage, TickGrowth = c.TickGrowth,
			Slow = c.Slow, FinalDamage = c.FinalDamage, FinalStun = 0.6, RainMultiplier = c.RainMultiplier, Source = "AxlMembrane",
		})
		S.fx("Ability", { Character = char, Act = ACT, Move = "GuiltMembrane", Phase = "Engulf", Targets = { target }, Duration = t, Rain = rainy() })
	end)
end

function Axl.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		guiltSpecter(S, player, state, aim)
	elseif slot == 2 then
		abandonedJunk(S, player, state, aim)
	elseif slot == 3 then
		guiltMembrane(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- CIVIL WAR (ultimate)
---------------------------------------------------------------------------
local scatters = setmetatable({}, { __mode = "k" }) -- [character] = break-apart function while it lasts

local function registerScatter(S)
	if S.Adapter.DodgeHandlers and not S.Adapter.DodgeHandlers.GuiltScatter then
		S.Adapter.DodgeHandlers.GuiltScatter = function(attackerPlayer, target, info)
			local f = scatters[target]
			if f then
				f(attackerPlayer, info)
			end
		end
	end
end

function Axl.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	registerScatter(S)
	local character, _, root = alive(S, player)
	local life = state.Life
	local center = Moves.groundBelow(root.Position, { character })
	S.lock(state, u.Windup + 0.3)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Rise", Windup = u.Windup, Position = center, Radius = u.Radius, Specters = u.Specters })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local up = center + Vector3.new(0, 2.5, 0)
		local caught = {}
		for _, target in ipairs(S.Hitbox.inRadius(character, up, u.Radius, 8)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.hit(player, target, { Damage = u.SpecterDamage, Stun = u.SpecterStun, Knockback = 0, Direction = tr.Position - center, Position = tr.Position, Source = "AxlCivilWar" }) then
				table.insert(caught, target)
			end
		end
		local t = u.Time * (rainy() and u.RainMultiplier or 1)
		for _, target in ipairs(caught) do
			engulf(S, player, target, {
				Time = u.Time, Tick = u.Tick, TickDamage = u.TickDamage, Slow = u.Slow,
				FinalDamage = u.FinalDamage - u.TickDamage, FinalStun = u.FinalStun, FinalKnockback = u.FinalKnockback, FinalLaunch = u.FinalLaunch,
				RainMultiplier = u.RainMultiplier, Source = "AxlCivilWar",
			})
		end
		S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Engulf", Targets = caught, Duration = t, Position = center, Radius = u.Radius, Rain = rainy() })
		-- While it lasts, a hit on him makes Civil War break apart: the hit misses.
		character:SetAttribute("GuiltScatter", true)
		scatters[character] = function(attackerPlayer)
			scatters[character] = nil
			character:SetAttribute("GuiltScatter", nil)
			local attacker = attackerPlayer and attackerPlayer.Character
			local ar = attacker and attacker:FindFirstChild("HumanoidRootPart")
			local _, _, r = alive(S, player)
			if not r then
				return
			end
			local away = ar and Moves.flat(r.Position - ar.Position) or r.CFrame.LookVector * -1
			local spot = Moves.safeStep(character, r, away, u.ScatterDistance) or r.Position
			local iframes = S.Adapter.Settings.IFrameAttribute
			character:SetAttribute(iframes, true)
			S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Scatter", From = r.Position, To = spot })
			character:PivotTo(CFrame.lookAt(spot, spot - away))
			task.delay(0.4, function()
				character:SetAttribute(iframes, nil)
			end)
		end
		task.delay(t + 0.05, function()
			scatters[character] = nil
			if character.Parent then
				character:SetAttribute("GuiltScatter", nil)
			end
			if state.Life == life then
				S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Crush", Position = center, Radius = u.Radius, Targets = caught })
			end
		end)
	end)
end

function Axl.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute("GuiltScatter", nil)
		scatters[state.Character] = nil
	end
end

return Axl
end

-- ======================================================================
-- MODULE: AxlOutfit
-- ======================================================================
__modules["AxlOutfit"] = function()
--[[
	AxlOutfit  (ServerScriptService.SpinServer.AxlOutfit)

	Gives a character Axl RO's look while they play him (TuskAct 12), built
	from blocky parts (no catalog asset ids). A stand-in look until there's
	reference art:
	  * long dark hair tied back, a dark headband
	  * a grey Civil War-style long coat with a high collar, two rows of
	    brass buttons, shoulder boards and coat tails, a red sash
	  * dark trousers and tall black boots
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local AxlOutfit = {}
AxlOutfit.Act = 12

local C = {
	Hair = Color3.fromRGB(46, 34, 28),
	Band = Color3.fromRGB(60, 22, 26),
	Coat = Color3.fromRGB(116, 120, 130),
	CoatDark = Color3.fromRGB(84, 88, 98),
	Brass = Color3.fromRGB(214, 176, 80),
	Sash = Color3.fromRGB(170, 40, 46),
	Pants = Color3.fromRGB(46, 42, 50),
	Boot = Color3.fromRGB(26, 24, 26),
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

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Long dark hair over the top and sides, tied back in a tail.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.14 * s, 0.3 * s, head.Size.Z + 0.14 * s), C.Hair, CFrame.new(0, h - 0.06 * s, 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.12 * s, 0.9 * s, head.Size.Z * 0.7), C.Hair, CFrame.new(side * (w + 0.05 * s), -0.02 * s, 0.14 * s))
	end
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.14 * s, 1.0 * s, 0.14 * s), C.Hair, CFrame.new(0, -0.05 * s, d + 0.06 * s))
	piece(head, outfit, "Bangs", Vector3.new(head.Size.X * 0.8, 0.16 * s, 0.1 * s), C.Hair, CFrame.new(0.1 * s, h - 0.24 * s, -d - 0.03 * s) * CFrame.Angles(0, 0, -0.15))
	for i = 0, 3 do
		piece(head, outfit, "Tail", Vector3.new((0.32 - i * 0.04) * s, 0.4 * s, 0.24 * s), C.Hair, CFrame.new(0, -0.4 * s - i * 0.36 * s, d + 0.16 * s))
	end
	piece(head, outfit, "Headband", Vector3.new(head.Size.X + 0.18 * s, 0.12 * s, head.Size.Z + 0.18 * s), C.Band, CFrame.new(0, h - 0.26 * s, 0.02 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Coat", s + Vector3.new(0.1, 0.02, 0.1), C.Coat, CFrame.new())
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.62, 0.36, s.Z + 0.24), C.CoatDark, CFrame.new(0, top + 0.12, 0))
		-- Two rows of brass buttons.
		for row = 0, 4 do
			for _, side in ipairs({ -1, 1 }) do
				piece(upper, outfit, "Button", Vector3.new(0.12, 0.12, 0.05), C.Brass, CFrame.new(side * 0.28, top - 0.25 - row * 0.28, front - 0.07))
			end
		end
		-- Shoulder boards and a red sash across the chest.
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Board", Vector3.new(0.6, 0.1, s.Z + 0.16), C.CoatDark, CFrame.new(side * (s.X / 2 - 0.3), top + 0.03, 0))
			piece(upper, outfit, "Board", Vector3.new(0.5, 0.06, 0.06), C.Brass, CFrame.new(side * (s.X / 2 - 0.3), top + 0.09, front - 0.04))
		end
		piece(upper, outfit, "Sash", Vector3.new(0.3, s.Y * 1.15, 0.05), C.Sash, CFrame.new(0, 0, front - 0.06) * CFrame.Angles(0, 0, 0.6))
	end
	-- Coat skirt and tails, red waist sash.
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.3
		piece(waist, outfit, "SashBelt", Vector3.new(ws.X + 0.16, 0.26, ws.Z + 0.16), C.Sash, CFrame.new(0, waistTop - 0.14, 0))
		local skirtH = lower and 1.6 or 1.3
		for _, side in ipairs({ -1, 1 }) do
			piece(waist, outfit, "Skirt", Vector3.new(ws.X / 2 + 0.06, skirtH, 0.12), C.Coat, CFrame.new(side * (ws.X / 4 + 0.08), waistTop - skirtH / 2, -ws.Z / 2 - 0.08) * CFrame.Angles(0, side * 0.1, 0))
			piece(waist, outfit, "Skirt", Vector3.new(0.12, skirtH, ws.Z + 0.16), C.CoatDark, CFrame.new(side * (ws.X / 2 + 0.1), waistTop - skirtH / 2, 0.02))
		end
		piece(waist, outfit, "Skirt", Vector3.new(ws.X + 0.3, skirtH + 0.2, 0.12), C.Coat, CFrame.new(0, waistTop - skirtH / 2 - 0.1, ws.Z / 2 + 0.08))
	end
	-- Sleeves with brass cuffs.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local tall = as.Y > 1.8
			local h = tall and as.Y - 0.3 or as.Y
			piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.08, h + 0.02, as.Z + 0.08), C.Coat, CFrame.new(0, as.Y / 2 - h / 2, 0))
			if name:find("Lower") or tall then
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.14, 0.24, as.Z + 0.14), C.CoatDark, CFrame.new(0, as.Y / 2 - h + 0.12, 0))
				piece(arm, outfit, "CuffButton", Vector3.new(0.1, 0.1, 0.05), C.Brass, CFrame.new(0, as.Y / 2 - h + 0.12, -as.Z / 2 - 0.09))
			end
		end
	end
	-- Dark trousers and tall boots.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Pants", ls + Vector3.new(0.05, 0.02, 0.05), C.Pants, CFrame.new())
			if name:find("Lower") or ls.Y > 1.8 then
				local bh = ls.Y > 1.8 and 1.0 or ls.Y + 0.05
				piece(leg, outfit, "Boot", Vector3.new(ls.X + 0.14, bh, ls.Z + 0.14), C.Boot, CFrame.new(0, -ls.Y / 2 + bh / 2, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Boot", foot.Size + Vector3.new(0.1, 0.06, 0.14), C.Boot, CFrame.new(0, 0, -0.03))
		end
	end
end

function AxlOutfit.apply(character)
	if character:FindFirstChild("AxlOutfit") then
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
	outfit.Name = "AxlOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function AxlOutfit.remove(character)
	local outfit = character:FindFirstChild("AxlOutfit")
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
		if character:GetAttribute("TuskAct") == AxlOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == AxlOutfit.Act then
					AxlOutfit.apply(character)
				end
			end)
		else
			AxlOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function AxlOutfit.init()
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

return AxlOutfit
end
end
