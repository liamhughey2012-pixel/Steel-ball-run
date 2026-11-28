--[[
	Axl_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Axl RO: Civil War.
	Its other half is Axl_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "axl" or __expect.Side ~= "server") then
		error("this is the code for Axl_Server, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Axl_Server and put it in ServerScriptService > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: Axl
-- ======================================================================
__modules["Axl"] = function()
--[[
	Axl  (ServerScriptService.SpinServer.TuskActs.Axl)

	Axl RO: CIVIL WAR. His Stand makes a target's guilt real: the people
	they left behind rise as specters, the things they abandoned fly at them
	and stick, and their guilt wraps them in a membrane that shrinks until it
	crushes them. Water washes guilt away: in the rain the membrane dissolves
	twice as fast. Registered as "Act" 12 so it reuses the Tusk ability system.
	  Passive   GUILT: every hit he lands marks the target (up to 5 stacks,
	            fading 8 s after the last); his moves feed on it
	  M1        GUILT COMBO: strikes with Civil War's long arms (+1 guilt a hit)
	  Ability 1 GUILT SPECTERS: specters rise from his shadow and HUNT the
	            nearest enemy, grabbing on contact (more guilt = more specters)
	  Ability 2 ABANDONED JUNK: a volley of junk that sticks to whoever it
	            hits: each stuck piece slows them and adds guilt
	  Ability 3 GUILT MEMBRANE: wraps the nearest enemy; it squeezes harder
	            with every tick and USES UP their guilt to squeeze harder
	            still; at max guilt they're flattened
	  Ultimate  CIVIL WAR: the junkyard rises round him: everyone nearby is
	            loaded with guilt, grabbed and engulfed; while it lasts Civil
	            War breaks apart when he's hit (the hit misses, he reforms out
	            of reach); then every membrane crushes shut
Numbers: TuskConfig.Axl. All damage goes through S.hit (CombatAdapter).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Axl = {}
local cfg = TuskConfig.Axl
local ACT = 12

local stick -- (defined with the junk)

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

---------------------------------------------------------------------------
-- GUILT (passive): stacks on the target, fading after a while
---------------------------------------------------------------------------
local function guiltOf(target)
	local g = target:GetAttribute("Guilt") or 0
	if g > 0 and os.clock() - (target:GetAttribute("GuiltAt") or 0) > cfg.Guilt.FadeAfter then
		return 0
	end
	return g
end

local function setGuilt(S, target, g)
	g = math.clamp(g, 0, cfg.Guilt.Max)
	local stamp = os.clock()
	target:SetAttribute("Guilt", g > 0 and g or nil)
	target:SetAttribute("GuiltAt", g > 0 and stamp or nil)
	S.fx("Ability", { Act = ACT, Move = "Guilt", Phase = "Mark", Target = target, Stacks = g })
	if g > 0 then
		task.delay(cfg.Guilt.FadeAfter + 0.05, function()
			if target.Parent and target:GetAttribute("GuiltAt") == stamp then
				target:SetAttribute("Guilt", nil)
				target:SetAttribute("GuiltAt", nil)
				S.fx("Ability", { Act = ACT, Move = "Guilt", Phase = "Mark", Target = target, Stacks = 0 })
			end
		end)
	end
end

local function addGuilt(S, target, n)
	setGuilt(S, target, guiltOf(target) + (n or 1))
end

-- Uses up all their guilt; returns how much there was.
local function consumeGuilt(S, target)
	local g = guiltOf(target)
	if g > 0 then
		setGuilt(S, target, 0)
	end
	return g
end

-- Every hit he lands adds guilt: S with a hit() that marks the target.
local function guiltyHits(S)
	return setmetatable({
		hit = function(player, target, info)
			local ok = S.hit(player, target, info)
			if ok then
				addGuilt(S, target, 1)
			end
			return ok
		end,
	}, { __index = S })
end

function Axl.M1(S, player, state, aim)
	Moves.m1(guiltyHits(S), player, state, aim, cfg.M1, ACT)
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
	local token = tostring({}) -- only this membrane's squeezes may act (a newer one replaces it)
	target:SetAttribute("GuiltMembraneUntil", untilT)
	target:SetAttribute("GuiltMembraneCast", token)
	slow(S, target, "GuiltMembrane", opts.Slow, t)
	local ticks = math.max(1, math.floor(t / opts.Tick))
	for i = 1, ticks do
		task.delay(i * opts.Tick, function()
			local tr = target:FindFirstChild("HumanoidRootPart")
			-- (Ends early if the membrane was cleared, e.g. a new life.)
			if not tr or target:GetAttribute("GuiltMembraneCast") ~= token or not target:GetAttribute("GuiltMembraneUntil") then
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
-- GUILT SPECTERS: they rise from his shadow and hunt the nearest enemy
---------------------------------------------------------------------------
local nextSpecter = 0

local function nearestEnemy(S, character, root, range)
	local best, bestD
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, range, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and S.Adapter.canBeHit(nil, target) then
			local d = (tr.Position - root.Position).Magnitude
			if not bestD or d < bestD then
				best, bestD = target, d
			end
		end
	end
	return best
end

local function guiltSpecters(S, player, state)
	local c = cfg.GuiltSpecter
	if not ready(S, player, state, "GuiltSpecter", 1) then
		return
	end
	S.startCooldown(player, state, "GuiltSpecter", c.Cooldown, 1)
	S.lock(state, c.Windup + 0.25)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "GuiltSpecter", Phase = "Cast", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local target = nearestEnemy(S, char, r, c.Range)
		if not target then
			S.startCooldown(player, state, "GuiltSpecter", c.MissCooldown, 1)
			S.fx("Ability", { Character = char, Act = ACT, Move = "GuiltSpecter", Phase = "Miss" })
			return
		end
		-- More guilt on them, more of their past comes back for them.
		local count = math.min(c.MaxCount, c.Count + math.floor(guiltOf(target) / c.GuiltPerExtra))
		local guilty = guiltyHits(S)
		for i = 1, count do
			nextSpecter = nextSpecter + 1
			local id = nextSpecter
			local side = (i - (count + 1) / 2) * c.Spread
			local pos = (r.CFrame * CFrame.new(side, 0, 1.5)).Position
			S.fx("Ability", { Character = char, Act = ACT, Move = "GuiltSpecter", Phase = "Spawn", Id = id, From = pos, Target = target, Speed = c.Speed, Life = c.Life, Delay = (i - 1) * 0.15 })
			task.delay((i - 1) * 0.15, function()
				local born = os.clock()
				local step = 0.1
				local function tick()
					local tr = target.Parent and target:FindFirstChild("HumanoidRootPart")
					local hum = target:FindFirstChildOfClass("Humanoid")
					if not tr or not hum or hum.Health <= 0 or os.clock() - born > c.Life or state.Life ~= life then
						S.fx("Ability", { Act = ACT, Move = "GuiltSpecter", Phase = "Fade", Id = id, Position = pos })
						return
					end
					local to = tr.Position - pos
					if to.Magnitude <= c.GrabRadius then
						guilty.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = to, Position = tr.Position, Source = "AxlSpecter" })
						S.fx("Ability", { Act = ACT, Move = "GuiltSpecter", Phase = "Grab", Id = id, Position = tr.Position, Target = target })
						return
					end
					pos = pos + to.Unit * math.min(c.Speed * step, to.Magnitude)
					task.delay(step, tick)
				end
				tick()
			end)
		end
	end)
end

---------------------------------------------------------------------------
-- ABANDONED JUNK
---------------------------------------------------------------------------
local JUNK = { "Crate", "Wheel", "Chair", "Bottle", "Boot", "Lamp" }

-- Junk stuck to a target: each piece slows them a bit more until it falls off.
stick = function(S, target, style, c)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local n = (target:GetAttribute("JunkStuck") or 0) + 1
	target:SetAttribute("JunkStuck", n)
	S.Adapter.setMoveModifier(humanoid, "GuiltJunk", math.max(0.5, 1 - c.SlowPerPiece * n))
	S.fx("Ability", { Act = ACT, Move = "AbandonedJunk", Phase = "Stick", Target = target, Style = style, Duration = c.StickTime })
	task.delay(c.StickTime, function()
		local left = math.max(0, (target:GetAttribute("JunkStuck") or 1) - 1)
		target:SetAttribute("JunkStuck", left > 0 and left or nil)
		if humanoid.Parent then
			S.Adapter.setMoveModifier(humanoid, "GuiltJunk", left > 0 and math.max(0.5, 1 - c.SlowPerPiece * left) or nil)
		end
	end)
end

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
					if hits[target] <= c.MaxHitsPerTarget and S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Position = position, Source = "AxlJunk" }) then
						-- It sticks to them: slower with every piece, and more guilt.
						addGuilt(S, target, 1)
						stick(S, target, JUNK[(i - 1) % #JUNK + 1], c)
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
		-- It feeds on their guilt (and uses it up): harder squeezes; at max guilt, flattened.
		local g = consumeGuilt(S, target)
		local mult = 1 + c.PerGuilt * g
		local flatten = g >= cfg.Guilt.Max
		local t = engulf(S, player, target, {
			Time = c.Time, Tick = c.Tick, TickDamage = c.TickDamage * mult, TickGrowth = c.TickGrowth * mult,
			Slow = c.Slow, FinalDamage = c.FinalDamage * mult, FinalStun = flatten and c.FlattenStun or 0.6,
			FinalLaunch = flatten and c.FlattenLaunch or nil, RainMultiplier = c.RainMultiplier, Source = "AxlMembrane",
		})
		S.fx("Ability", { Character = char, Act = ACT, Move = "GuiltMembrane", Phase = "Engulf", Targets = { target }, Duration = t, Rain = rainy(), Guilt = g, Flatten = flatten })
	end)
end

function Axl.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		guiltSpecters(S, player, state)
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
		local perGuilt = cfg.GuiltMembrane.PerGuilt
		for _, target in ipairs(caught) do
			-- Loaded with guilt, then the crush feeds on all of it.
			addGuilt(S, target, u.GuiltAdded)
			local mult = 1 + perGuilt * consumeGuilt(S, target)
			engulf(S, player, target, {
				Time = u.Time, Tick = u.Tick, TickDamage = u.TickDamage, Slow = u.Slow,
				FinalDamage = (u.FinalDamage - u.TickDamage) * mult, FinalStun = u.FinalStun, FinalKnockback = u.FinalKnockback, FinalLaunch = u.FinalLaunch,
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
	from blocky parts (no catalog asset ids), matched to his art:
	  * an olive military helmet covered in a dark net, chin straps hanging
	  * a cream hood lining framing his face, short brown hair at the back
	  * the dotted band across his eyes
	  * a khaki hooded parka: the hood bunched round his neck and shoulders
	  * a yellow chest plate with gold buttons along its edges and a V of
	    gold scales hanging down the front
	  * black clips down the outside of both sleeves
	  * khaki trousers and dark boots
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local AxlOutfit = {}
AxlOutfit.Act = 12

local C = {
	Helmet = Color3.fromRGB(120, 132, 108),
	Net = Color3.fromRGB(96, 52, 40),
	Strap = Color3.fromRGB(110, 70, 44),
	Lining = Color3.fromRGB(236, 228, 204),
	Hair = Color3.fromRGB(90, 62, 44),
	Band = Color3.fromRGB(98, 84, 110),
	Dot = Color3.fromRGB(240, 236, 228),
	Parka = Color3.fromRGB(176, 160, 112),
	ParkaDark = Color3.fromRGB(140, 126, 86),
	Plate = Color3.fromRGB(226, 210, 112),
	Gold = Color3.fromRGB(214, 170, 60),
	GoldDark = Color3.fromRGB(170, 128, 40),
	Clip = Color3.fromRGB(30, 30, 34),
	ClipShine = Color3.fromRGB(120, 124, 132),
	Pants = Color3.fromRGB(150, 136, 96),
	Boot = Color3.fromRGB(50, 40, 32),
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
	local fz = -d - 0.03 * s
	-- Short brown hair at the back under the helmet.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.08 * s, 0.6 * s, 0.12 * s), C.Hair, CFrame.new(0, 0.05 * s, d + 0.04 * s))
	-- Cream hood lining framing the face (sides, back and under the chin).
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Lining", Vector3.new(0.16 * s, head.Size.Y * 0.95, head.Size.Z + 0.12 * s), C.Lining, CFrame.new(side * (w + 0.08 * s), -0.08 * s, 0.04 * s))
	end
	piece(head, outfit, "Lining", Vector3.new(head.Size.X + 0.3 * s, head.Size.Y * 0.8, 0.14 * s), C.Lining, CFrame.new(0, -0.12 * s, d + 0.14 * s))
	-- Olive helmet with a dark net over it.
	local helmY = h + 0.06 * s
	piece(head, outfit, "Helmet", Vector3.new(head.Size.X + 0.42 * s, 0.5 * s, head.Size.Z + 0.42 * s), C.Helmet, CFrame.new(0, helmY, 0.02 * s))
	piece(head, outfit, "Helmet", Vector3.new(head.Size.X * 0.86, 0.22 * s, head.Size.Z * 0.86), C.Helmet, CFrame.new(0, helmY + 0.34 * s, 0.02 * s))
	piece(head, outfit, "Rim", Vector3.new(head.Size.X + 0.5 * s, 0.08 * s, head.Size.Z + 0.5 * s), C.Helmet, CFrame.new(0, helmY - 0.24 * s, 0.02 * s))
	local span = head.Size.X + 0.44 * s
	for i = -3, 3 do
		-- Net strands both ways over the top and down the sides.
		piece(head, outfit, "Net", Vector3.new(0.04 * s, 0.04 * s, span), C.Net, CFrame.new(i * span / 7, helmY + 0.26 * s, 0.02 * s))
		piece(head, outfit, "Net", Vector3.new(span, 0.04 * s, 0.04 * s), C.Net, CFrame.new(0, helmY + 0.26 * s, i * span / 7 + 0.02 * s))
		piece(head, outfit, "Net", Vector3.new(0.04 * s, 0.5 * s, 0.03 * s), C.Net, CFrame.new(i * span / 7, helmY, -span / 2 + 0.01 * s))
		piece(head, outfit, "Net", Vector3.new(0.04 * s, 0.5 * s, 0.03 * s), C.Net, CFrame.new(i * span / 7, helmY, span / 2 + 0.03 * s))
		piece(head, outfit, "Net", Vector3.new(0.03 * s, 0.5 * s, 0.04 * s), C.Net, CFrame.new(-span / 2 - 0.01 * s, helmY, i * span / 7))
		piece(head, outfit, "Net", Vector3.new(0.03 * s, 0.5 * s, 0.04 * s), C.Net, CFrame.new(span / 2 + 0.01 * s, helmY, i * span / 7))
	end
	for _, y in ipairs({ -0.1, 0.1 }) do
		piece(head, outfit, "Net", Vector3.new(span + 0.02 * s, 0.04 * s, span + 0.02 * s), C.Net, CFrame.new(0, helmY + y * s, 0.02 * s))
	end
	-- Chin straps hanging loose.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "ChinStrap", Vector3.new(0.05 * s, 1.1 * s, 0.05 * s), C.Strap, CFrame.new(side * (w + 0.1 * s), -0.45 * s, -0.25 * s) * CFrame.Angles(0.15, 0, side * -0.05))
	end
	-- The dotted band across his eyes (gaps left for the eyes).
	piece(head, outfit, "EyeBand", Vector3.new(head.Size.X * 0.96, 0.12 * s, 0.05 * s), C.Band, CFrame.new(0, 0.26 * s, fz))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "EyeBand", Vector3.new(0.18 * s, 0.34 * s, 0.05 * s), C.Band, CFrame.new(side * 0.44 * s, 0.1 * s, fz))
		piece(head, outfit, "EyeBand", Vector3.new(0.3 * s, 0.1 * s, 0.05 * s), C.Band, CFrame.new(side * 0.2 * s, -0.04 * s, fz))
	end
	piece(head, outfit, "EyeBand", Vector3.new(0.12 * s, 0.22 * s, 0.05 * s), C.Band, CFrame.new(0, 0.1 * s, fz))
	for _, spot in ipairs({ { -0.36, 0.26 }, { -0.12, 0.26 }, { 0.12, 0.26 }, { 0.36, 0.26 }, { -0.44, 0.08 }, { 0.44, 0.08 }, { -0.22, -0.04 }, { 0.22, -0.04 } }) do
		piece(head, outfit, "Dot", Vector3.new(0.05 * s, 0.05 * s, 0.03 * s), C.Dot, CFrame.new(spot[1] * s, spot[2] * s, fz - 0.03 * s))
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Parka", s + Vector3.new(0.12, 0.02, 0.12), C.Parka, CFrame.new())
		-- The hood bunched round his neck and shoulders.
		piece(upper, outfit, "Hood", Vector3.new(s.X + 0.3, 0.42, s.Z + 0.4), C.Parka, CFrame.new(0, top - 0.05, 0.04))
		piece(upper, outfit, "Hood", Vector3.new(s.X * 0.75, 0.5, s.Z + 0.3), C.ParkaDark, CFrame.new(0, top + 0.2, 0.12))
		piece(upper, outfit, "HoodBack", Vector3.new(s.X * 0.7, 0.7, 0.3), C.Parka, CFrame.new(0, top - 0.2, -front + 0.2))
		-- Yellow chest plate (a V shield) with gold buttons along its edges.
		piece(upper, outfit, "Plate", Vector3.new(s.X * 0.8, s.Y * 0.38, 0.06), C.Plate, CFrame.new(0, top - s.Y * 0.28, front - 0.08))
		piece(upper, outfit, "Plate", Vector3.new(s.X * 0.48, s.Y * 0.2, 0.06), C.Plate, CFrame.new(0, top - s.Y * 0.55, front - 0.08))
		piece(upper, outfit, "Plate", Vector3.new(s.X * 0.2, s.Y * 0.12, 0.06), C.Plate, CFrame.new(0, top - s.Y * 0.7, front - 0.08))
		for _, side in ipairs({ -1, 1 }) do
			for k = 0, 3 do
				piece(upper, outfit, "Button", Vector3.new(0.16, 0.16, 0.06), C.Gold, CFrame.new(side * (s.X * 0.42 - k * 0.16), top - 0.12 - k * 0.24, front - 0.12))
			end
			-- A V of gold scales hanging below the plate.
			for k = 0, 4 do
				local x = side * (s.X * 0.46 - k * 0.2)
				local y = top - s.Y * 0.5 - k * 0.14
				piece(upper, outfit, "Scale", Vector3.new(0.18, 0.18, 0.05), k % 2 == 0 and C.Gold or C.GoldDark, CFrame.new(x, y, front - 0.11))
				piece(upper, outfit, "Scale", Vector3.new(0.18, 0.18, 0.05), k % 2 == 0 and C.GoldDark or C.Gold, CFrame.new(x, y - 0.2, front - 0.1))
			end
		end
	end
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.3
		if lower then
			piece(lower, outfit, "Parka", ws + Vector3.new(0.12, 0.02, 0.12), C.Parka, CFrame.new())
		end
		-- Parka hem down over the hips.
		piece(waist, outfit, "Hem", Vector3.new(ws.X + 0.2, 0.7, ws.Z + 0.2), C.Parka, CFrame.new(0, waistTop - 0.45, 0))
		piece(waist, outfit, "HemEdge", Vector3.new(ws.X + 0.24, 0.1, ws.Z + 0.24), C.ParkaDark, CFrame.new(0, waistTop - 0.8, 0))
	end
	-- Khaki sleeves with black clips down the outside.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local out = name:find("Left") and -1 or 1
			local tall = as.Y > 1.8
			local h = tall and as.Y - 0.3 or as.Y
			piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.12, h + 0.02, as.Z + 0.12), C.Parka, CFrame.new(0, as.Y / 2 - h / 2, 0))
			local count = tall and 3 or 2
			for k = 1, count do
				local y = as.Y / 2 - k * h / (count + 1)
				piece(arm, outfit, "Clip", Vector3.new(0.1, 0.26, 0.4), C.Clip, CFrame.new(out * (as.X / 2 + 0.1), y, 0))
				piece(arm, outfit, "Clip", Vector3.new(0.06, 0.08, 0.42), C.ClipShine, CFrame.new(out * (as.X / 2 + 0.14), y + 0.06, 0))
			end
			if name:find("Lower") or tall then
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.18, 0.2, as.Z + 0.18), C.ParkaDark, CFrame.new(0, as.Y / 2 - h + 0.1, 0))
			end
		end
	end
	-- Khaki trousers and dark boots.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Pants", ls + Vector3.new(0.05, 0.02, 0.05), C.Pants, CFrame.new())
			if name:find("Lower") or ls.Y > 1.8 then
				local bh = ls.Y > 1.8 and 0.8 or ls.Y * 0.7
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
