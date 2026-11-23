--[[
	Blackmore_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Blackmore: Catch the Rainbow.
	Its other half is Blackmore_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

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
	built from blocky parts (no catalog asset ids):
	  * a dark wide-brimmed hat
	  * a blue mask over the lower face
	  * a long dark navy coat with a high collar, buttons and coat tails
	  * dark gloves and boots
	  (his umbrella is drawn in his hand by the client)
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local BlackmoreOutfit = {}
BlackmoreOutfit.Act = 11

local C = {
	Hat = Color3.fromRGB(34, 36, 48),
	HatBand = Color3.fromRGB(70, 110, 170),
	Mask = Color3.fromRGB(80, 130, 200),
	Coat = Color3.fromRGB(36, 44, 70),
	CoatDark = Color3.fromRGB(24, 28, 46),
	Button = Color3.fromRGB(200, 210, 230),
	Glove = Color3.fromRGB(28, 28, 34),
	Boot = Color3.fromRGB(30, 30, 38),
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
	local top, d = head.Size.Y / 2, head.Size.Z / 2
	-- Wide-brimmed hat with a blue band.
	piece(head, outfit, "Brim", Vector3.new(head.Size.X + 1.1 * s, 0.12 * s, head.Size.Z + 1.0 * s), C.Hat, CFrame.new(0, top + 0.02 * s, 0))
	piece(head, outfit, "Crown", Vector3.new(head.Size.X * 0.86, 0.6 * s, head.Size.Z * 0.82), C.Hat, CFrame.new(0, top + 0.36 * s, 0.02 * s))
	piece(head, outfit, "Band", Vector3.new(head.Size.X * 0.88, 0.14 * s, head.Size.Z * 0.84), C.HatBand, CFrame.new(0, top + 0.14 * s, 0.02 * s))
	-- Blue mask over the lower face.
	piece(head, outfit, "Mask", Vector3.new(head.Size.X + 0.06 * s, 0.5 * s, head.Size.Z + 0.06 * s), C.Mask, CFrame.new(0, -0.3 * s, 0))
	piece(head, outfit, "MaskSeam", Vector3.new(0.06 * s, 0.5 * s, 0.04 * s), C.CoatDark, CFrame.new(0, -0.3 * s, -d - 0.04 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		piece(upper, outfit, "Coat", s + Vector3.new(0.1, 0.04, 0.1), C.Coat, CFrame.new())
		-- High collar standing up round the neck.
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.7, 0.5, s.Z + 0.2), C.CoatDark, CFrame.new(0, s.Y / 2 + 0.2, 0.02))
		for i = 0, 2 do
			piece(upper, outfit, "Button", Vector3.new(0.14, 0.14, 0.06), C.Button, CFrame.new(0.18, s.Y * 0.3 - i * s.Y * 0.28, -s.Z / 2 - 0.08))
		end
		piece(upper, outfit, "CoatEdge", Vector3.new(0.08, s.Y + 0.06, 0.06), C.CoatDark, CFrame.new(0, 0, -s.Z / 2 - 0.07))
	end
	local waist = lower or upper
	if waist then
		local y = lower and 0 or -upper.Size.Y / 2
		if lower then
			piece(lower, outfit, "Coat", lower.Size + Vector3.new(0.1, 0.04, 0.1), C.Coat, CFrame.new())
		end
		-- Long coat tails down to the knees (front split, back closed).
		for _, side in ipairs({ -1, 1 }) do
			piece(waist, outfit, "CoatTail", Vector3.new(waist.Size.X * 0.48, 1.8, 0.14), C.Coat, CFrame.new(side * waist.Size.X * 0.26, y - 0.9, -waist.Size.Z / 2 - 0.1) * CFrame.Angles(-0.08, 0, side * 0.05))
			piece(waist, outfit, "CoatSide", Vector3.new(0.14, 1.8, waist.Size.Z + 0.2), C.CoatDark, CFrame.new(side * (waist.Size.X / 2 + 0.1), y - 0.9, 0))
		end
		piece(waist, outfit, "CoatBack", Vector3.new(waist.Size.X + 0.2, 1.9, 0.14), C.Coat, CFrame.new(0, y - 0.95, waist.Size.Z / 2 + 0.12) * CFrame.Angles(0.08, 0, 0))
	end
	-- Coat sleeves, gloves, boots.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Sleeve", arm.Size + Vector3.new(0.08, 0.02, 0.08), C.Coat, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftHand", "RightHand" }) do
		local hand = character:FindFirstChild(name)
		if hand then
			piece(hand, outfit, "Glove", hand.Size + Vector3.new(0.1, 0.06, 0.1), C.Glove, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local tall = leg.Size.Y > 1.8
			local h = tall and 0.9 or leg.Size.Y * 0.8
			piece(leg, outfit, "Boot", Vector3.new(leg.Size.X + 0.12, h, leg.Size.Z + 0.14), C.Boot, CFrame.new(0, -leg.Size.Y / 2 + h / 2, 0))
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
