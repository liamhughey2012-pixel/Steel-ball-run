--[[
	Blackmore_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Blackmore: Catch the Rainbow.
	Its other half is Blackmore_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "blackmore" or __expect.Side ~= "server") then
		error("this is the code for Blackmore_Server, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Blackmore_Server and put it in ServerScriptService > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: Blackmore
-- ======================================================================
__modules["Blackmore"] = function()
--[[
	Blackmore  (ServerScriptService.SpinServer.TuskActs.Blackmore)

	Blackmore: CATCH THE RAINBOW. His Stand freezes raindrops in mid-air: he
	cuts with them, walks on them, and when he's hit in the rain he bursts
	into raindrops. Registered as "Act" 11 so it reuses the Tusk ability system.
	  M1        RAINDROP COMBO: shard strikes; the finisher fans out hardened drops
	  Ability 1 RAINDROP BLADES: drops freeze in a fan in front of him, then
	            fire as a volley (each enemy takes at most a few)
	  Ability 2 RAINDROP STEP: he dashes along a stair of frozen drops (can't
	            be hit), leaving a line of hanging drops that cut anyone who
	            walks through it for a few seconds
	  Ability 3 RAINDROP CAGE: a dome of frozen drops round the nearest enemy:
	            they're slowed, and every time they move the drops cut them
	  Ultimate  CATCH THE RAINBOW: a downpour round him (a rainbow overhead):
	            the rain slices every enemy inside, the first hit on him makes
	            him scatter into raindrops (cancelled, he reappears out of
	            reach), then every frozen drop fires inward at once
	Numbers: TuskConfig.Blackmore. All damage goes through S.hit (CombatAdapter).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Blackmore = {}
local cfg = TuskConfig.Blackmore
local ACT = 11

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

function Blackmore.M1(S, player, state, aim)
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

---------------------------------------------------------------------------
-- RAINDROP BLADES
---------------------------------------------------------------------------
local function raindropBlades(S, player, state, aim)
	local c = cfg.RaindropBlades
	if not ready(S, player, state, "RaindropBlades", 1) then
		return
	end
	S.startCooldown(player, state, "RaindropBlades", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.25)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local flat = Moves.flat(direction)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "RaindropBlades", Phase = "Freeze", Startup = c.Startup, Direction = flat, Drops = c.Drops, Spread = c.Spread })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local hits = {}
		for i = 1, c.Drops do
			local t = c.Drops == 1 and 0 or (i - 1) / (c.Drops - 1) - 0.5
			local dir = (CFrame.lookAt(Vector3.new(), direction) * CFrame.Angles(0, math.rad(-t * c.Spread), 0)).LookVector
			local origin = r.Position + Vector3.new(0, 1, 0) + flat * 2.5 + (CFrame.lookAt(Vector3.new(), flat).RightVector * t * 4)
			S.fireRain(player, state, {
				Origin = origin,
				Direction = dir,
				Speed = c.Speed,
				Radius = c.Radius,
				Range = c.Range,
				OnHit = function(target, position)
					hits[target] = (hits[target] or 0) + 1
					if hits[target] <= c.MaxHitsPerTarget then
						S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Position = position, Source = "BlackmoreBlades" })
					end
				end,
			})
		end
	end)
end

---------------------------------------------------------------------------
-- RAINDROP STEP
---------------------------------------------------------------------------
local function raindropStep(S, player, state, aim)
	local c = cfg.RaindropStep
	if not ready(S, player, state, "RaindropStep", 2) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local destination = Moves.safeStep(character, root, direction, c.Distance)
	if not destination then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "RaindropStep", c.Cooldown, 2)
	S.lock(state, c.Windup + c.Travel + 0.1)
	local life = state.Life
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local from = r.Position
		local to = Moves.safeStep(char, r, direction, c.Distance) or destination
		local iframes = S.Adapter.Settings.IFrameAttribute
		char:SetAttribute(iframes, true)
		S.fx("Ability", { Character = char, Act = ACT, Move = "RaindropStep", Phase = "Step", From = from, To = to, Direction = direction, Travel = c.Travel, TrailTime = c.TrailTime })
		task.delay(c.Travel, function()
			char:SetAttribute(iframes, nil)
			if char.Parent and state.Life == life then
				char:PivotTo(CFrame.lookAt(to, to + direction))
			end
		end)
		-- The hanging drops cut anyone who walks through the line.
		local mid = (from + to) / 2
		local box = CFrame.lookAt(mid, mid + direction)
		local size = Vector3.new(c.TrailWidth, 6, (to - from).Magnitude + 2)
		local lastHit = {}
		for i = 1, math.floor(c.TrailTime / c.TrailTick) do
			task.delay(i * c.TrailTick, function()
				if not player.Character then
					return
				end
				for _, target in ipairs(S.Hitbox.inBox(player.Character, box, size, 6)) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					local t = os.clock()
					if tr and t - (lastHit[target] or -math.huge) >= c.TrailHitEvery then
						lastHit[target] = t
						S.hit(player, target, { Damage = c.TrailDamage, Stun = c.TrailStun, Knockback = 0, Direction = direction, Position = tr.Position, Source = "BlackmoreStep" })
					end
				end
			end)
		end
	end)
end

---------------------------------------------------------------------------
-- RAINDROP CAGE
---------------------------------------------------------------------------
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

local function raindropCage(S, player, state, aim)
	local c = cfg.RaindropCage
	if not ready(S, player, state, "RaindropCage", 3) then
		return
	end
	S.startCooldown(player, state, "RaindropCage", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.25)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "RaindropCage", Phase = "Startup", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local target = targetInCone(S, char, r, direction, c.Range, c.Cone)
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		if not tr or not S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = direction, Position = tr.Position, Source = "BlackmoreCage" }) then
			S.startCooldown(player, state, "RaindropCage", c.MissCooldown, 3)
			S.fx("Ability", { Character = char, Act = ACT, Move = "RaindropCage", Phase = "Miss", Direction = direction })
			return
		end
		local untilT = now() + c.CageTime
		target:SetAttribute("RainCagedUntil", untilT)
		slow(S, target, "RainCage", c.Slow, c.CageTime)
		S.fx("Ability", { Character = char, Act = ACT, Move = "RaindropCage", Phase = "Cage", Target = target, Duration = c.CageTime })
		-- Every tick they've moved, the drops cut them.
		local last = tr.Position
		for i = 1, math.floor(c.CageTime / c.Tick) do
			task.delay(i * c.Tick, function()
				local t = target:FindFirstChild("HumanoidRootPart")
				if not t or (target:GetAttribute("RainCagedUntil") or 0) < untilT - 0.01 then
					return
				end
				local moved = (t.Position - last).Magnitude
				last = t.Position
				if moved > c.MoveThreshold then
					S.hit(player, target, { Damage = c.MoveDamage, Stun = 0.2, Knockback = 0, Direction = t.Position - r.Position, Position = t.Position, Source = "BlackmoreCage" })
					S.fx("Ability", { Act = ACT, Move = "RaindropCage", Phase = "Cut", Position = t.Position })
				end
			end)
		end
	end)
end

function Blackmore.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		raindropBlades(S, player, state, aim)
	elseif slot == 2 then
		raindropStep(S, player, state, aim)
	elseif slot == 3 then
		raindropCage(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- CATCH THE RAINBOW (ultimate)
---------------------------------------------------------------------------
local scatters = setmetatable({}, { __mode = "k" }) -- [character] = scatter function while the storm is up

local function registerScatter(S)
	if S.Adapter.DodgeHandlers and not S.Adapter.DodgeHandlers.RainScatter then
		S.Adapter.DodgeHandlers.RainScatter = function(attackerPlayer, target, info)
			local f = scatters[target]
			if f then
				f(attackerPlayer, info)
			end
		end
	end
end

function Blackmore.Ultimate(S, player, state, aim)
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
	local center = root.Position
	S.lock(state, u.Windup + 0.3)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Start", Windup = u.Windup, Position = center, Radius = u.Radius, Duration = u.Duration })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		character:SetAttribute("RainStormUntil", now() + u.Duration)
		-- In the rain, the first hit on him scatters him into raindrops.
		character:SetAttribute("RainScatter", true)
		scatters[character] = function(attackerPlayer)
			scatters[character] = nil
			character:SetAttribute("RainScatter", nil)
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
		for i = 1, math.floor(u.Duration / u.Tick) - 1 do
			task.delay(i * u.Tick, function()
				if state.Life ~= life then
					return
				end
				Moves.aoe(S, player, center + Vector3.new(0, 2, 0), u.Radius, { Damage = u.TickDamage, Stun = u.TickStun, Knockback = 0, Source = "BlackmoreRain" }, 8)
			end)
		end
		task.delay(u.Duration, function()
			scatters[character] = nil
			if character.Parent then
				character:SetAttribute("RainScatter", nil)
				character:SetAttribute("RainStormUntil", nil)
			end
			if state.Life ~= life then
				return
			end
			-- Every frozen drop fires inward at once.
			Moves.aoe(S, player, center + Vector3.new(0, 2, 0), u.Radius, { Damage = u.BurstDamage, Stun = u.BurstStun, Knockback = u.BurstKnockback, Launch = u.BurstLaunch, Source = "BlackmoreRain" }, 8)
			S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Burst", Position = center, Radius = u.Radius })
		end)
	end)
end

function Blackmore.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute("RainScatter", nil)
		state.Character:SetAttribute("RainStormUntil", nil)
		scatters[state.Character] = nil
	end
end

return Blackmore
end

-- ======================================================================
-- MODULE: BlackmoreOutfit
-- ======================================================================
__modules["BlackmoreOutfit"] = function()
--[[
	BlackmoreOutfit  (ServerScriptService.SpinServer.BlackmoreOutfit)

	Gives a character Blackmore's look while they play him (TuskAct 11),
	built from blocky parts (no catalog asset ids), matched to his art:
	  * a dark navy hood wrapped round the head and neck, a gold ring on top
	    and a long blond ponytail sweeping up and back out of it
	  * his white mask with the diagonal rainbow stripe and black slits
	  * a navy capelet down to the elbows covered in gold grommets, two rows
	    of grommets down the front
	  * a long navy coat skirt to the calves (split at the front)
	  * pale grey-blue sleeves and leggings with dark raindrop marks
	  * grey studded boots
	  (his umbrella is drawn in his hand by the client)
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local BlackmoreOutfit = {}
BlackmoreOutfit.Act = 11

local C = {
	Hood = Color3.fromRGB(40, 40, 72),
	HoodDark = Color3.fromRGB(28, 28, 52),
	Ring = Color3.fromRGB(214, 172, 70),
	Hair = Color3.fromRGB(238, 222, 160),
	HairDark = Color3.fromRGB(206, 186, 120),
	Mask = Color3.fromRGB(236, 240, 244),
	Slit = Color3.fromRGB(20, 20, 24),
	Rainbow = { Color3.fromRGB(235, 80, 100), Color3.fromRGB(250, 220, 70), Color3.fromRGB(70, 190, 230) },
	Coat = Color3.fromRGB(46, 44, 82),
	CoatDark = Color3.fromRGB(32, 30, 60),
	Grommet = Color3.fromRGB(214, 172, 70),
	GrommetHole = Color3.fromRGB(24, 22, 40),
	Sleeve = Color3.fromRGB(190, 198, 214),
	Leg = Color3.fromRGB(200, 206, 220),
	Drop = Color3.fromRGB(60, 56, 96),
	Boot = Color3.fromRGB(150, 156, 170),
	Stud = Color3.fromRGB(225, 228, 236),
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

-- A gold grommet (ring with a dark hole) facing -Z of `cf`.
local function grommet(parent, outfit, cf)
	piece(parent, outfit, "Grommet", Vector3.new(0.17, 0.17, 0.05), C.Grommet, cf)
	piece(parent, outfit, "Grommet", Vector3.new(0.08, 0.08, 0.06), C.GrommetHole, cf * CFrame.new(0, 0, -0.01))
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Hood: wraps the top, sides and back; the face stays open.
	piece(head, outfit, "Hood", Vector3.new(head.Size.X + 0.24 * s, 0.3 * s, head.Size.Z + 0.24 * s), C.Hood, CFrame.new(0, h + 0.04 * s, 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hood", Vector3.new(0.14 * s, head.Size.Y + 0.1 * s, head.Size.Z + 0.2 * s), C.Hood, CFrame.new(side * (w + 0.06 * s), -0.04 * s, 0.03 * s))
	end
	piece(head, outfit, "Hood", Vector3.new(head.Size.X + 0.24 * s, head.Size.Y + 0.1 * s, 0.14 * s), C.Hood, CFrame.new(0, -0.04 * s, d + 0.06 * s))
	piece(head, outfit, "HoodRim", Vector3.new(head.Size.X + 0.26 * s, 0.12 * s, 0.1 * s), C.HoodDark, CFrame.new(0, h - 0.04 * s, -d - 0.04 * s))
	-- Gold ring on top with a long blond ponytail sweeping up and back.
	piece(head, outfit, "Ring", Vector3.new(0.34 * s, 0.12 * s, 0.34 * s), C.Ring, CFrame.new(0, h + 0.24 * s, 0.05 * s))
	-- The tail is a chain of blocks along a curve: up out of the ring, then back and down.
	local pts = {}
	for i = 0, 7 do
		local t = i / 7
		pts[i] = Vector3.new(0, h + 0.3 * s + math.sin(t * math.pi * 0.75) * 0.9 * s, 0.05 * s + t * t * 2.1 * s)
	end
	for i = 1, 7 do
		local a0, a1 = pts[i - 1], pts[i]
		local thick = (0.26 - i * 0.022) * s
		piece(head, outfit, "Ponytail", Vector3.new(thick, thick, (a1 - a0).Magnitude + 0.06 * s), i % 2 == 0 and C.HairDark or C.Hair, CFrame.lookAt((a0 + a1) / 2, a1))
	end
	-- White mask: rainbow stripe across it diagonally, black slits under the eyes.
	local fz = -d - 0.07 * s
	piece(head, outfit, "Mask", Vector3.new(head.Size.X * 0.92, head.Size.Y * 0.88, 0.08 * s), C.Mask, CFrame.new(0, -0.04 * s, fz))
	for i, color in ipairs(C.Rainbow) do
		piece(head, outfit, "MaskStripe", Vector3.new(head.Size.X * 0.95, 0.09 * s, 0.04 * s), color, CFrame.new(0, (0.02 - (i - 2) * 0.1) * s, fz - 0.05 * s) * CFrame.Angles(0, 0, 0.42))
	end
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "MaskEye", Vector3.new(0.26 * s, 0.06 * s, 0.04 * s), C.Slit, CFrame.new(side * 0.22 * s, 0.16 * s, fz - 0.05 * s) * CFrame.Angles(0, 0, side * -0.15))
	end
	for i = -1, 1 do
		piece(head, outfit, "MaskSlit", Vector3.new(0.05 * s, 0.3 * s, 0.04 * s), C.Slit, CFrame.new(i * 0.12 * s, -0.32 * s, fz - 0.05 * s))
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Coat", s + Vector3.new(0.1, 0.02, 0.1), C.Coat, CFrame.new())
		-- Hood wraps down round the neck like a cowl.
		piece(upper, outfit, "Cowl", Vector3.new(s.X * 0.62, 0.36, s.Z + 0.26), C.Hood, CFrame.new(0, top + 0.12, 0))
		-- Capelet over the shoulders (the arm parts are on the arms so they move with them).
		local capeH = s.Y * 0.72
		piece(upper, outfit, "Capelet", Vector3.new(s.X + 0.3, capeH, s.Z + 0.42), C.Coat, CFrame.new(0, top - capeH / 2 + 0.02, 0))
		piece(upper, outfit, "CapeHem", Vector3.new(s.X + 0.34, 0.08, s.Z + 0.46), C.CoatDark, CFrame.new(0, top - capeH, 0))
		-- Two rows of grommets down the front, and a few more beside them.
		for row = 0, 3 do
			for _, side in ipairs({ -1, 1 }) do
				grommet(upper, outfit, CFrame.new(side * 0.22, top - 0.25 - row * 0.3, front - 0.24))
			end
		end
		for _, spot in ipairs({ { -0.75, -0.35 }, { 0.75, -0.35 }, { -0.6, -0.8 }, { 0.6, -0.8 } }) do
			grommet(upper, outfit, CFrame.new(spot[1] * s.X / 2, top + spot[2] * s.Y / 1.6, front - 0.24))
		end
	end
	-- The capelet drapes over each upper arm, down to the elbow, with grommets.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local ch = as.Y > 1.8 and as.Y * 0.55 or as.Y
			local outward = name:find("Left") and -1 or 1
			piece(arm, outfit, "CapeArm", Vector3.new(as.X + 0.34, ch, as.Z + 0.42), C.Coat, CFrame.new(outward * 0.06, as.Y / 2 - ch / 2 + 0.04, 0))
			piece(arm, outfit, "CapeHem", Vector3.new(as.X + 0.38, 0.08, as.Z + 0.46), C.CoatDark, CFrame.new(outward * 0.06, as.Y / 2 - ch + 0.04, 0))
			for _, y in ipairs({ 0.3, 0.65 }) do
				grommet(arm, outfit, CFrame.new(outward * 0.1, as.Y / 2 - ch * y, -as.Z / 2 - 0.26))
			end
		end
	end
	-- Long coat skirt to the calves, split at the front.
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.3
		local skirtH = lower and 1.85 or 1.6
		for _, side in ipairs({ -1, 1 }) do
			piece(waist, outfit, "Skirt", Vector3.new(ws.X / 2 + 0.12, skirtH, 0.14), C.Coat, CFrame.new(side * (ws.X / 4 + 0.14), waistTop - skirtH / 2, -ws.Z / 2 - 0.1) * CFrame.Angles(0, side * 0.12, 0))
			piece(waist, outfit, "Skirt", Vector3.new(0.14, skirtH, ws.Z + 0.2), C.CoatDark, CFrame.new(side * (ws.X / 2 + 0.12), waistTop - skirtH / 2, 0.02))
		end
		piece(waist, outfit, "Skirt", Vector3.new(ws.X + 0.36, skirtH, 0.14), C.Coat, CFrame.new(0, waistTop - skirtH / 2, ws.Z / 2 + 0.1))
		piece(waist, outfit, "Waist", Vector3.new(ws.X + 0.14, 0.4, ws.Z + 0.14), C.Coat, CFrame.new(0, waistTop - 0.2, 0))
	end
	-- Pale grey-blue sleeves (gloves the same colour).
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Sleeve", arm.Size + Vector3.new(0.06, 0.02, 0.06), C.Sleeve, CFrame.new())
		end
	end
	-- Pale leggings with dark raindrop marks.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Legging", ls + Vector3.new(0.05, 0.02, 0.05), C.Leg, CFrame.new())
			local i = 0
			for y = ls.Y / 2 - 0.3, -ls.Y / 2 + 0.25, -0.45 do
				i = i + 1
				local x = (i % 2 == 0 and 0.2 or -0.2) * ls.X
				piece(leg, outfit, "Drop", Vector3.new(0.16, 0.16, 0.04), C.Drop, CFrame.new(x, y, -ls.Z / 2 - 0.04))
				piece(leg, outfit, "Drop", Vector3.new(0.06, 0.14, 0.04), C.Drop, CFrame.new(x + 0.08, y - 0.12, -ls.Z / 2 - 0.04) * CFrame.Angles(0, 0, 0.5))
				piece(leg, outfit, "Drop", Vector3.new(0.04, 0.16, 0.16), C.Drop, CFrame.new(ls.X / 2 + 0.04, y - 0.2, x * 0.6))
				piece(leg, outfit, "Drop", Vector3.new(0.04, 0.16, 0.16), C.Drop, CFrame.new(-ls.X / 2 - 0.04, y - 0.1, -x * 0.6))
			end
			-- Grey boots over the lower leg.
			if name:find("Lower") or ls.Y > 1.8 then
				local bh = ls.Y > 1.8 and 0.7 or 0.6
				piece(leg, outfit, "Boot", Vector3.new(ls.X + 0.14, bh, ls.Z + 0.14), C.Boot, CFrame.new(0, -ls.Y / 2 + bh / 2, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			local fs = foot.Size
			piece(foot, outfit, "Boot", fs + Vector3.new(0.12, 0.08, 0.14), C.Boot, CFrame.new())
			-- Studs on the toe and sole.
			for _, x in ipairs({ -0.25, 0.25 }) do
				piece(foot, outfit, "Stud", Vector3.new(0.12, 0.12, 0.08), C.Stud, CFrame.new(x * fs.X, 0, -fs.Z / 2 - 0.1))
			end
		end
	end
end

function BlackmoreOutfit.apply(character)
	if character:FindFirstChild("BlackmoreOutfit") then
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
	outfit.Name = "BlackmoreOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function BlackmoreOutfit.remove(character)
	local outfit = character:FindFirstChild("BlackmoreOutfit")
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
		if character:GetAttribute("TuskAct") == BlackmoreOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == BlackmoreOutfit.Act then
					BlackmoreOutfit.apply(character)
				end
			end)
		else
			BlackmoreOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function BlackmoreOutfit.init()
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

return BlackmoreOutfit
end
end
