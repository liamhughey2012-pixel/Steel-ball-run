--[[
	Tooru_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Tooru (JoJolion): Wonder of U.
	Its other half is Tooru_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: Tooru
-- ======================================================================
__modules["Tooru"] = function()
--[[
	Tooru  (ServerScriptService.SpinServer.TuskActs.Tooru)

	Tooru (JoJolion): WONDER OF U. Its power is the "calamity": whoever
	pursues him is struck by misfortune. Registered as "Act" 16 so it reuses
	the Tusk ability system.
	  Passive   CALAMITY: anyone running at him (closing in fast from
	            range) has something fall on them now and then
	  M1        WONDER OF U COMBO: the old man swings his cane with him; hits
	            on a CURSED enemy bring something down on them too
	  Ability 1 CALAMITY: DEBRIS: three shadows in a row chase the nearest
	            enemy; each one stops where they are and something heavy
	            falls on it (a girder, a flowerpot, a road sign, a branch).
	            The last is the big one. Keep moving!
	  Ability 2 THE PURSUER'S CURSE: enemies in front are cursed for a few
	            seconds and slowed: every time one MOVES TOWARD him,
	            something falls on them. Back off and nothing happens
	  Ability 3 WONDER OF U: the old man appears right beside the nearest
	            enemy (it can be anywhere) and sweeps their legs with his
	            cane. Press 3 AGAIN soon after to SWAP: Tooru steps out where
	            the old man stood (a moment of untouchable)
	  Ultimate  THE FLOW OF CALAMITY: for a while nobody can hit him: anyone
	            whose attack would land is struck by calamity instead, and
	            anyone close who moves toward him has debris dropped on them.
	            When it ends, CALAMITY STORM: a big one falls on every enemy
	            near him
	Numbers: TuskConfig.Tooru. All damage goes through S.hit (CombatAdapter).
	Falling things take FallTime to land and only hit whoever is still under
	them, so they can be dodged.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Tooru = {}
local cfg = TuskConfig.Tooru
local ACT = 16
local FALL_TIME = 0.3 -- seconds from "it's falling" to it landing
local KINDS = { "Girder", "Pot", "Sign", "Branch" }

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Is `target` moving toward `root` faster than `speed` studs/s?
local function pursuing(target, root, speed)
	local tr = target:FindFirstChild("HumanoidRootPart")
	if not tr then
		return false
	end
	local toHim = flat(root.Position - tr.Position)
	if toHim.Magnitude < 0.5 then
		return false
	end
	return flat(tr.AssemblyLinearVelocity):Dot(toHim.Unit) > speed
end

-- Something falls on `spot`: it lands FALL_TIME later and hits whoever is
-- still under it (everyone in `radius`, or only `only` if given).
local function fall(S, player, spot, radius, info, only)
	local kind = KINDS[math.random(1, #KINDS)]
	S.fx("Ability", { Act = ACT, Move = "Calamity", Phase = "Fall", Position = spot, Kind = kind, Radius = radius, FallTime = FALL_TIME })
	task.delay(FALL_TIME, function()
		local char = player.Character
		if not char then
			return
		end
		local hits = 0
		-- Measured from body height, not the ground (roots stand ~3 studs up).
		for _, target in ipairs(S.Hitbox.inRadius(char, spot + Vector3.new(0, 2.5, 0), radius, 6)) do
			if not only or target == only then
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr then
					local away = flat(tr.Position - spot)
					local hitInfo = table.clone(info)
					hitInfo.Direction = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
					hitInfo.Position = tr.Position
					if S.hit(player, target, hitInfo) then
						hits = hits + 1
					end
				end
			end
		end
		S.fx("Ability", { Act = ACT, Move = "Calamity", Phase = "Land", Position = spot, Kind = kind, Radius = radius, Hits = hits })
	end)
end
Tooru.fall = fall

function Tooru.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: CALAMITY: DEBRIS
---------------------------------------------------------------------------
local function debris(S, player, state, aim)
	local c = cfg.Debris
	if not ready(S, player, state, "Debris", 1) then
		return
	end
	S.startCooldown(player, state, "Debris", c.Cooldown, 1)
	S.lock(state, c.Windup + 0.15)
	local character, _, root = alive(S, player)
	local life = state.Life
	local direction = S.aim(aim, root)
	local target = Moves.findTarget(S, character, root, c.Range, c.Cone, direction)
	local troot = target and target:FindFirstChild("HumanoidRootPart")
	local first = troot and troot.Position or root.Position + flat(direction).Unit * 30
	local drops = c.Drops or 1
	for i = 1, drops do
		task.delay((i - 1) * (c.Gap or 0.45), function()
			if state.Life ~= life then
				return
			end
			local tr = target and target.Parent and target:FindFirstChild("HumanoidRootPart")
			local spot = Moves.groundBelow(tr and tr.Position or first, { character, target })
			local last = i == drops
			S.fx("Ability", { Character = i == 1 and character or nil, Act = ACT, Move = "Debris", Phase = "Mark", Target = target, Position = spot, Follow = c.Follow, Lock = c.Lock, Index = i, Last = last })
			-- The shadow follows them, then stops where they are.
			task.delay(c.Follow, function()
				if state.Life ~= life then
					return
				end
				local tr2 = target and target.Parent and target:FindFirstChild("HumanoidRootPart")
				if tr2 then
					spot = Moves.groundBelow(tr2.Position, { character, target })
				end
				S.fx("Ability", { Act = ACT, Move = "Debris", Phase = "Lock", Position = spot, Lock = c.Lock, Last = last })
				task.delay(math.max(0, c.Lock - FALL_TIME), function()
					if state.Life ~= life then
						return
					end
					if last then
						fall(S, player, spot, c.Radius + 1, { Damage = c.LastDamage, Stun = c.LastStun, Knockback = c.LastKnockback, Launch = c.LastLaunch, Source = "TooruDebris" })
					else
						fall(S, player, spot, c.Radius, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Source = "TooruDebris" })
					end
				end)
			end)
		end)
	end
end

---------------------------------------------------------------------------
-- 2: THE PURSUER'S CURSE
---------------------------------------------------------------------------
local function curse(S, player, state, aim)
	local c = cfg.Curse
	if not ready(S, player, state, "Curse", 2) then
		return
	end
	S.startCooldown(player, state, "Curse", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.2)
	local character, _, root = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "Curse", Phase = "Cast", Windup = c.Windup, Range = c.Range })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life, true) then
			return
		end
		local char, _, r = alive(S, player)
		local look = flat(S.aim(aim, r))
		look = look.Magnitude > 0 and look.Unit or Vector3.new(0, 0, -1)
		local cosLimit = math.cos(math.rad(c.Cone / 2))
		local cursed = {}
		local untilT = now() + c.Time
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, c.Range, 12)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and #cursed < c.MaxTargets then
				local off = flat(tr.Position - r.Position)
				if off.Magnitude < 1 or off.Unit:Dot(look) >= cosLimit then
					table.insert(cursed, { Target = target, Next = 0 })
					target:SetAttribute("CalamityCurseUntil", untilT)
					local hum = target:FindFirstChildOfClass("Humanoid")
					if hum and c.Slow then
						S.Adapter.setMoveModifier(hum, "CalamityCurse", c.Slow)
					end
				end
			end
		end
		local list = {}
		for i, entry in ipairs(cursed) do
			list[i] = entry.Target
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "Curse", Phase = "Cursed", Targets = list, Duration = c.Time })
		if #cursed == 0 then
			-- Nobody to curse: most of the cooldown back.
			S.startCooldown(player, state, "Curse", c.Cooldown * 0.35, 2)
			return
		end
		local function tick()
			local _, _, me = alive(S, player)
			local t = now()
			if not me or state.Life ~= life or t >= untilT then
				for _, entry in ipairs(cursed) do
					if entry.Target.Parent and entry.Target:GetAttribute("CalamityCurseUntil") == untilT then
						entry.Target:SetAttribute("CalamityCurseUntil", nil)
						local hum = entry.Target:FindFirstChildOfClass("Humanoid")
						if hum then
							S.Adapter.setMoveModifier(hum, "CalamityCurse", nil)
						end
					end
				end
				return
			end
			for _, entry in ipairs(cursed) do
				local target = entry.Target
				if target.Parent and t >= entry.Next and target:GetAttribute("CalamityCurseUntil") == untilT and pursuing(target, me, c.ApproachSpeed) then
					entry.Next = t + c.Every
					local tr = target:FindFirstChild("HumanoidRootPart")
					-- It lands where they're heading.
					local spot = tr.Position + flat(tr.AssemblyLinearVelocity) * FALL_TIME * 0.8
					fall(S, player, Moves.groundBelow(spot, { target }), 4.5, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Source = "TooruCurse" }, target)
				end
			end
			task.delay(0.15, tick)
		end
		tick()
	end)
end

---------------------------------------------------------------------------
-- 3: WONDER OF U (it appears beside them)
---------------------------------------------------------------------------
-- Press 3 again soon after: Tooru steps out where the old man stood.
local function swap(S, player, state)
	local c = cfg.Appear
	local sw = state.TooruSwap
	state.TooruSwap = nil
	local character, _, root = alive(S, player)
	if not root then
		return
	end
	local from = root.Position
	local target = sw.Target
	local tr = target and target.Parent and target:FindFirstChild("HumanoidRootPart")
	local face = tr and Vector3.new(tr.Position.X, sw.At.Y, tr.Position.Z) or (sw.At + flat(root.CFrame.LookVector))
	if (face - sw.At).Magnitude < 0.1 then
		face = sw.At + Vector3.new(0, 0, -1)
	end
	root.CFrame = CFrame.lookAt(sw.At, face)
	root.AssemblyLinearVelocity = Vector3.zero
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	task.delay(c.SwapIFrames or 0.35, function()
		if character.Parent then
			character:SetAttribute(iframes, nil)
		end
	end)
	S.fx("Ability", { Character = character, Act = ACT, Move = "Appear", Phase = "Swap", From = from, To = sw.At })
end

local function appear(S, player, state, aim)
	local c = cfg.Appear
	local sw = state.TooruSwap
	if sw and sw.Life == state.Life and now() <= sw.Until and not S.isBusy(state) then
		swap(S, player, state)
		return
	end
	if not ready(S, player, state, "Appear", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local target = Moves.findTarget(S, character, root, c.Range, 360, S.aim(aim, root))
	if not target then
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	S.startCooldown(player, state, "Appear", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local life = state.Life
	local tr = target:FindFirstChild("HumanoidRootPart")
	if not tr then
		return
	end
	-- Beside them, a little behind.
	local side = flat(tr.CFrame.RightVector)
	local at = tr.Position + (side.Magnitude > 0 and side.Unit or Vector3.new(1, 0, 0)) * 3 - flat(tr.CFrame.LookVector) * 1.5
	state.TooruSwap = { At = at, Target = target, Life = life, Until = now() + c.Delay + (c.SwapWindow or 2.5) }
	S.fx("Ability", { Character = character, Act = ACT, Move = "Appear", Phase = "Appear", Target = target, Position = at, Delay = c.Delay, SwapWindow = c.SwapWindow })
	task.delay(c.Delay, function()
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local spot = tr.Parent and tr.Position or at
		local hit = false
		if tr.Parent and (tr.Position - at).Magnitude <= c.Radius + 3 then
			local dir = flat(tr.Position - at)
			hit = S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, 1), Position = spot, Source = "TooruCane" })
		end
		S.fx("Ability", { Act = ACT, Move = "Appear", Phase = "Sweep", Position = at, Target = target, Hit = hit })
	end)
end

function Tooru.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		debris(S, player, state, aim)
	elseif slot == 2 then
		curse(S, player, state, aim)
	elseif slot == 3 then
		appear(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- THE FLOW OF CALAMITY (ultimate)
---------------------------------------------------------------------------
local guards = setmetatable({}, { __mode = "k" }) -- [character] = { Player, Until, Last = {} }

local function installGuard(S)
	if S.Adapter.DodgeHandlers.CalamityGuard then
		return
	end
	-- Any hit on a guarded Tooru is cancelled; the attacker meets calamity.
	S.Adapter.DodgeHandlers.CalamityGuard = function(attackerPlayer, target)
		local g = guards[target]
		local u = cfg.Ultimate
		local attacker = attackerPlayer and attackerPlayer.Character
		local ar = attacker and attacker:FindFirstChild("HumanoidRootPart")
		if not g or now() > g.Until or not ar then
			return
		end
		local t = now()
		if (g.Last[attacker] or 0) > t then
			return
		end
		g.Last[attacker] = t + u.ReflectEvery
		S.fx("Ability", { Act = ACT, Move = "Calamity", Phase = "Reflect", Position = ar.Position, Target = attacker, Kind = KINDS[math.random(1, #KINDS)] })
		local tr = target:FindFirstChild("HumanoidRootPart")
		local away = tr and flat(ar.Position - tr.Position) or Vector3.new(0, 0, 1)
		S.hit(g.Player, attacker, { Damage = u.ReflectDamage, Stun = u.ReflectStun, Knockback = 10, Direction = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1), Position = ar.Position, Source = "TooruReflect" })
	end
end

local function endGuard(character)
	if character then
		guards[character] = nil
		character:SetAttribute("CalamityGuard", nil)
	end
end

function Tooru.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	installGuard(S)
	local character = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.2)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Charge", Windup = u.Windup, Duration = u.Duration })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local untilT = now() + u.Duration
		guards[character] = { Player = player, Until = untilT, Last = {} }
		character:SetAttribute("CalamityGuard", untilT)
		S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Active", Duration = u.Duration, Range = u.Range })
		local nextFor = {}
		local function tick()
			local char, _, r = alive(S, player)
			if not r or state.Life ~= life or now() >= untilT or char ~= character then
				endGuard(character)
				S.fx("Ultimate", { Character = character, Act = ACT, Phase = "End" })
				-- CALAMITY STORM: a big one on every enemy still near him.
				local st = u.Storm
				if st and r and state.Life == life and char == character then
					local victims = S.Hitbox.inRadius(char, r.Position, u.Range, 12)
					if #victims > 0 then
						S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Storm", Count = #victims })
					end
					for _, target in ipairs(victims) do
						local tr = target:FindFirstChild("HumanoidRootPart")
						if tr then
							local spot = Moves.groundBelow(tr.Position, { target })
							S.fx("Ability", { Act = ACT, Move = "Debris", Phase = "Lock", Position = spot, Lock = st.Delay, Last = true })
							task.delay(math.max(0, st.Delay - FALL_TIME), function()
								fall(S, player, spot, st.Radius, { Damage = st.Damage, Stun = st.Stun, Knockback = st.Knockback, Launch = st.Launch, Source = "TooruStorm" })
							end)
						end
					end
				end
				return
			end
			local t = now()
			for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, u.Range, 12)) do
				if t >= (nextFor[target] or 0) and pursuing(target, r, u.ApproachSpeed) then
					nextFor[target] = t + u.Every
					local tr = target:FindFirstChild("HumanoidRootPart")
					local spot = tr.Position + flat(tr.AssemblyLinearVelocity) * FALL_TIME * 0.8
					fall(S, player, Moves.groundBelow(spot, { target }), 5, { Damage = u.Damage, Stun = u.Stun, Knockback = u.Knockback, Source = "TooruFlow" }, target)
				end
			end
			task.delay(0.2, tick)
		end
		tick()
	end)
end

function Tooru.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		endGuard(character)
	end
	state.TooruSwap = nil
end

---------------------------------------------------------------------------
-- PASSIVE: CALAMITY (and M1 hits on cursed enemies). Started once by
-- TuskService for everyone playing Tooru, players and NPCs alike.
---------------------------------------------------------------------------
local started = false
function Tooru.Init(S)
	if started then
		return
	end
	started = true
	local p = cfg.Passive
	local nextFor = setmetatable({}, { __mode = "k" })
	local function passiveTick()
		local t = now()
		for player, state in pairs(S.States) do
			if state.Act == ACT then
				local char, _, r = S.Adapter.getAlive(player)
				if r and not char:GetAttribute("TimeStopped") then
					for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, p.Range, 8)) do
						local tr = target:FindFirstChild("HumanoidRootPart")
						if tr and t >= (nextFor[target] or 0) and flat(tr.Position - r.Position).Magnitude > p.MinDistance and pursuing(target, r, p.ApproachSpeed) then
							nextFor[target] = t + p.Every
							local spot = tr.Position + flat(tr.AssemblyLinearVelocity) * FALL_TIME * 0.8
							fall(S, player, Moves.groundBelow(spot, { target }), p.Radius, { Damage = p.Damage, Stun = p.Stun, Knockback = p.Knockback, Source = "TooruPassive" }, target)
						end
					end
				end
			end
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(passiveTick)
			if not ok then
				warn("[Tooru] passive: " .. tostring(err))
			end
		end
	end)
	-- His M1 on a cursed enemy: something comes down on them too.
	local bonusNext = setmetatable({}, { __mode = "k" })
	S.Adapter.on("Hit", function(attackerPlayer, target, _, info)
		local b = cfg.M1.CursedBonus
		if not b or not info or info.Source ~= "TuskM1" or not attackerPlayer or not target then
			return
		end
		local state = S.States[attackerPlayer]
		if not state or state.Act ~= ACT or (target:GetAttribute("CalamityCurseUntil") or 0) <= now() then
			return
		end
		if (bonusNext[target] or 0) > now() then
			return
		end
		bonusNext[target] = now() + b.Every
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			fall(S, attackerPlayer, Moves.groundBelow(tr.Position, { target }), 4.5, { Damage = b.Damage, Stun = b.Stun, Knockback = 4, Source = "TooruCurse" }, target)
		end
	end)
end

return Tooru
end

-- ======================================================================
-- MODULE: TooruOutfit
-- ======================================================================
__modules["TooruOutfit"] = function()
--[[
	TooruOutfit  (ServerScriptService.SpinServer.TooruOutfit)

	Gives a character the look of Tooru (JoJolion) while they play him
	(TuskAct 16), built from blocky parts (no catalog asset ids), matched
	to his art:
	  * a big round black hat, wide and flat, with a blue spiral on each
	    side of the front; dark slate hair under it; green lipstick
	  * a purple jacket with dark plaid lines on the sleeves, black front
	    panels either side of a purple zip, a grey hood round his neck
	  * the sun-spiral on his chest: a yellow swirl with orange rays and a
	    long curling tail (an "S")
	  * a little teddy bear clinging to each shoulder
	  * a yellow belt, gold patterned trousers, blue shoes
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local TooruOutfit = {}
TooruOutfit.Act = 16

local C = {
	Hat = Color3.fromRGB(24, 22, 30),
	HatShade = Color3.fromRGB(40, 38, 52),
	Spiral = Color3.fromRGB(70, 90, 170),
	Hair = Color3.fromRGB(56, 62, 84),
	Lips = Color3.fromRGB(70, 170, 140),
	Purple = Color3.fromRGB(120, 60, 170),
	PurpleDark = Color3.fromRGB(70, 30, 110),
	Panel = Color3.fromRGB(26, 20, 34),
	Hood = Color3.fromRGB(84, 74, 104),
	Yellow = Color3.fromRGB(244, 196, 40),
	Orange = Color3.fromRGB(236, 120, 40),
	SwirlLine = Color3.fromRGB(180, 110, 30),
	Bear = Color3.fromRGB(190, 140, 80),
	BearLight = Color3.fromRGB(226, 186, 130),
	BearDark = Color3.fromRGB(70, 44, 30),
	Belt = Color3.fromRGB(232, 168, 40),
	Gold = Color3.fromRGB(222, 192, 70),
	GoldDot = Color3.fromRGB(170, 130, 40),
	Shoe = Color3.fromRGB(44, 80, 200),
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

-- A flat disc facing forward (-Z).
local function disc(parent, outfit, name, d, depth, color, offset)
	local p = piece(parent, outfit, name, Vector3.new(depth, d, d), color, offset * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Dark slate hair: short at the sides and a fringe peeking out under the hat.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.08 * s, 0.4 * s, head.Size.Z + 0.1 * s), C.Hair, CFrame.new(0, h - 0.2 * s, 0.02 * s))
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.1 * s, 0.6 * s, 0.12 * s), C.Hair, CFrame.new(0, 0.05 * s, d + 0.04 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Sideburn", Vector3.new(0.1 * s, 0.45 * s, 0.4 * s), C.Hair, CFrame.new(side * (w + 0.03 * s), 0.1 * s, 0.08 * s))
	end
	piece(head, outfit, "Fringe", Vector3.new(head.Size.X * 0.8, 0.14 * s, 0.08 * s), C.Hair, CFrame.new(-0.05 * s, h - 0.28 * s, -d - 0.03 * s))
	-- Green lipstick.
	piece(head, outfit, "Lips", Vector3.new(0.42 * s, 0.13 * s, 0.05 * s), C.Lips, CFrame.new(0, -0.32 * s, -d - 0.02 * s))
	-- The big round black hat: wide and flat, a rounded top.
	piece(head, outfit, "Hat", Vector3.new(head.Size.X + 1.1 * s, 0.5 * s, head.Size.Z + 0.75 * s), C.Hat, CFrame.new(0, h + 0.18 * s, 0.05 * s))
	piece(head, outfit, "HatTop", Vector3.new(head.Size.X + 0.8 * s, 0.2 * s, head.Size.Z + 0.5 * s), C.Hat, CFrame.new(0, h + 0.5 * s, 0.05 * s))
	piece(head, outfit, "HatRim", Vector3.new(head.Size.X + 1.2 * s, 0.14 * s, head.Size.Z + 0.85 * s), C.HatShade, CFrame.new(0, h - 0.03 * s, 0.05 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HatRound", Vector3.new(0.3 * s, 0.4 * s, head.Size.Z + 0.6 * s), C.Hat, CFrame.new(side * (w + 0.62 * s), h + 0.15 * s, 0.05 * s))
		-- A blue spiral on each side of the front: rings inside rings.
		local front = -(head.Size.Z / 2 + 0.38 * s) - 0.02 * s
		local at = CFrame.new(side * 0.55 * s, h + 0.22 * s, front)
		disc(head, outfit, "Spiral", 0.42 * s, 0.04 * s, C.Spiral, at)
		disc(head, outfit, "Spiral", 0.3 * s, 0.05 * s, C.Hat, at * CFrame.new(0.02 * s, 0.02 * s, -0.005 * s))
		disc(head, outfit, "Spiral", 0.18 * s, 0.06 * s, C.Spiral, at * CFrame.new(0.03 * s, 0.01 * s, -0.01 * s))
		disc(head, outfit, "Spiral", 0.07 * s, 0.07 * s, C.Hat, at * CFrame.new(0.04 * s, 0.01 * s, -0.015 * s))
	end
end

-- The sun-spiral: a yellow swirl, orange rays, and a long curling tail.
local function sunSpiral(upper, outfit, x, y, z)
	local at = CFrame.new(x, y, z)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		piece(upper, outfit, "Ray", Vector3.new(0.11, 0.17, 0.05), C.Orange, at * CFrame.new(math.sin(a) * 0.3, math.cos(a) * 0.3, 0.01) * CFrame.Angles(0, 0, -a))
	end
	disc(upper, outfit, "Swirl", 0.48, 0.05, C.Yellow, at)
	disc(upper, outfit, "SwirlLine", 0.3, 0.06, C.SwirlLine, at * CFrame.new(0.02, 0, -0.005))
	disc(upper, outfit, "SwirlIn", 0.18, 0.07, C.Yellow, at * CFrame.new(0.03, 0.01, -0.01))
	-- The tail curls down and round into an "S".
	piece(upper, outfit, "Tail", Vector3.new(0.12, 0.4, 0.05), C.Yellow, at * CFrame.new(0.16, -0.38, 0) * CFrame.Angles(0, 0, 0.35))
	piece(upper, outfit, "Tail", Vector3.new(0.12, 0.32, 0.05), C.Yellow, at * CFrame.new(0.18, -0.68, 0) * CFrame.Angles(0, 0, -0.5))
	piece(upper, outfit, "Tail", Vector3.new(0.28, 0.12, 0.05), C.Yellow, at * CFrame.new(0.03, -0.84, 0) * CFrame.Angles(0, 0, 0.2))
	piece(upper, outfit, "TailCurl", Vector3.new(0.12, 0.17, 0.05), C.Yellow, at * CFrame.new(-0.1, -0.75, 0))
end

-- A little teddy bear clinging to the outside of a shoulder.
local function bear(arm, outfit, side)
	local as = arm.Size
	local base = CFrame.new(side * (as.X / 2 + 0.16), as.Y / 2 - 0.35, -0.05)
	piece(arm, outfit, "BearBody", Vector3.new(0.42, 0.588, 0.448), C.Bear, base)
	piece(arm, outfit, "BearBelly", Vector3.new(0.252, 0.336, 0.07), C.BearLight, base * CFrame.new(0, -0.056, -0.238))
	piece(arm, outfit, "BearHead", Vector3.new(0.448, 0.42, 0.42), C.Bear, base * CFrame.new(0, 0.476, -0.028))
	piece(arm, outfit, "BearSnout", Vector3.new(0.196, 0.14, 0.112), C.BearLight, base * CFrame.new(0, 0.42, -0.266))
	piece(arm, outfit, "BearNose", Vector3.new(0.084, 0.07, 0.056), C.BearDark, base * CFrame.new(0, 0.462, -0.336))
	for _, e in ipairs({ -1, 1 }) do
		local ear = piece(arm, outfit, "BearEar", Vector3.new(0.168, 0.168, 0.168), C.Bear, base * CFrame.new(e * 0.168, 0.7, -0.028))
		ear.Shape = Enum.PartType.Ball
		piece(arm, outfit, "BearEye", Vector3.new(0.056, 0.056, 0.042), C.BearDark, base * CFrame.new(e * 0.098, 0.546, -0.224))
		-- Arms hugging round the shoulder.
		piece(arm, outfit, "BearArm", Vector3.new(0.126, 0.126, 0.42), C.Bear, base * CFrame.new(-side * 0.196, 0.14 + e * 0.112, -0.168))
	end
	piece(arm, outfit, "BearLeg", Vector3.new(0.14, 0.252, 0.14), C.Bear, base * CFrame.new(0.098, -0.364, -0.084))
	piece(arm, outfit, "BearLeg", Vector3.new(0.14, 0.252, 0.14), C.Bear, base * CFrame.new(-0.098, -0.364, -0.084))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front, back = s.Y / 2, -s.Z / 2, s.Z / 2
		-- Purple jacket, black front panels either side of a purple zip.
		piece(upper, outfit, "Jacket", s + Vector3.new(0.1, 0.02, 0.1), C.Purple, CFrame.new())
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Panel", Vector3.new(s.X * 0.4, s.Y - 0.1, 0.05), C.Panel, CFrame.new(side * s.X * 0.27, -0.05, front - 0.06))
			piece(upper, outfit, "Shoulder", Vector3.new(s.X * 0.35, 0.1, s.Z + 0.14), C.Purple, CFrame.new(side * s.X * 0.32, top + 0.02, 0))
		end
		piece(upper, outfit, "Zip", Vector3.new(0.05, s.Y - 0.1, 0.06), C.PurpleDark, CFrame.new(0, -0.05, front - 0.07))
		-- The grey hood bunched round his neck and down his back.
		piece(upper, outfit, "Hood", Vector3.new(s.X * 0.75, 0.3, s.Z + 0.2), C.Hood, CFrame.new(0, top + 0.08, 0.04))
		piece(upper, outfit, "HoodBack", Vector3.new(s.X * 0.65, s.Y * 0.4, 0.14), C.Hood, CFrame.new(0, top - s.Y * 0.18, back + 0.1))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "HoodFront", Vector3.new(0.18, 0.4, 0.14), C.Hood, CFrame.new(side * 0.3, top - 0.12, front - 0.06) * CFrame.Angles(0, 0, side * 0.3))
		end
		-- The sun-spiral on his chest (on the black panel).
		sunSpiral(upper, outfit, s.X * 0.27, 0.3, front - 0.1)
	end
	-- Yellow belt, gold patterned trousers.
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.25
		if lower then
			piece(lower, outfit, "Pants", ws + Vector3.new(0.06, 0.02, 0.06), C.Gold, CFrame.new())
		end
		piece(waist, outfit, "Belt", Vector3.new(ws.X + 0.1, 0.18, ws.Z + 0.1), C.Belt, CFrame.new(0, waistTop - 0.1, 0))
		piece(waist, outfit, "Buckle", Vector3.new(0.34, 0.22, 0.06), C.Yellow, CFrame.new(0, waistTop - 0.1, -ws.Z / 2 - 0.08))
		piece(waist, outfit, "BuckleHole", Vector3.new(0.2, 0.1, 0.07), C.Belt, CFrame.new(0, waistTop - 0.1, -ws.Z / 2 - 0.09))
	end
	-- Purple sleeves with dark plaid lines; a teddy bear on each shoulder.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			piece(arm, outfit, "Sleeve", as + Vector3.new(0.1, 0.02, 0.1), C.Purple, CFrame.new())
			for k = -1, 1, 2 do
				piece(arm, outfit, "Plaid", Vector3.new(0.06, as.Y, as.Z + 0.14), C.PurpleDark, CFrame.new(k * as.X * 0.22, 0, 0))
				piece(arm, outfit, "Plaid", Vector3.new(as.X + 0.14, 0.06, 0.06), C.PurpleDark, CFrame.new(0, k * as.Y * 0.22, -as.Z / 2 - 0.06))
			end
			if name:find("Upper") or (as.Y > 1.8 and not name:find("Lower")) then
				local side = name:find("Left") and -1 or 1
				bear(arm, outfit, side)
			end
		end
	end
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Pants", ls + Vector3.new(0.06, 0.02, 0.06), C.Gold, CFrame.new())
			-- A little pattern of darker flowers.
			for k = 0, 2 do
				local y = (k - 1) * ls.Y * 0.3
				piece(leg, outfit, "Flower", Vector3.new(0.14, 0.14, 0.05), C.GoldDot, CFrame.new((k % 2 == 0 and 0.15 or -0.15), y, -ls.Z / 2 - 0.05) * CFrame.Angles(0, 0, math.pi / 4))
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.08, 0.04, 0.12), C.Shoe, CFrame.new())
		end
	end
end

function TooruOutfit.apply(character)
	if character:FindFirstChild("TooruOutfit") then
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
	outfit.Name = "TooruOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function TooruOutfit.remove(character)
	local outfit = character:FindFirstChild("TooruOutfit")
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
		if character:GetAttribute("TuskAct") == TooruOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == TooruOutfit.Act then
					TooruOutfit.apply(character)
				end
			end)
		else
			TooruOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function TooruOutfit.init()
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

return TooruOutfit
end
end
