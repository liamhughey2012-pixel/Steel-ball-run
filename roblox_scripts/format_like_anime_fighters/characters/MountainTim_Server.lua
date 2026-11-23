--[[
	MountainTim_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Mountain Tim: Oh! Lonesome Me.
	Its other half is MountainTim_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: MountainTim
-- ======================================================================
__modules["MountainTim"] = function()
--[[
	MountainTim  (ServerScriptService.SpinServer.TuskActs.MountainTim)

	Mountain Tim: OH! LONESOME ME. The cowboy's Stand splits his body into
	pieces that slide along his lasso rope. Registered as "Act" 9 so it
	reuses the Tusk ability system.
	  M1        LASSO COMBO: jab, jab, rope whip, overhead rope slam
	  Ability 1 LASSO SNARE: throw the lasso; a hit ropes the enemy and drags them in
	  Ability 2 ROPE SPLIT: he splits into pieces that slide along a rope to a
	            spot ahead (can't be hit on the way), slicing through enemies
	  Ability 3 SPLIT PUNCH: his fist comes off and flies along the rope,
	            punching everyone in a line, then flies back
	  Ultimate  LONESOME ROUNDUP: ropes shoot to everyone nearby, his pieces
	            ride them in hitting over and over, then he yanks everyone
	            together and slams the rope down
	Numbers: TuskConfig.MountainTim. All damage goes through S.hit (CombatAdapter).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Tim = {}
local cfg = TuskConfig.MountainTim
local ACT = 9
local HAND = CFrame.new(0.9, 0.6, -1.4)

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Tim.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

-- Rope pull toward `point` (one tick; the knockback lasts ~0.18 s).
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
	S.Adapter.applyKnockback(target, offset, math.min(distance / 0.18 * 0.6, 90), math.clamp(offset.Y * 3, 4, 30))
	return false
end

---------------------------------------------------------------------------
-- LASSO SNARE
---------------------------------------------------------------------------
local function lassoSnare(S, player, state, aim)
	local c = cfg.LassoSnare
	if not ready(S, player, state, "LassoSnare", 1) then
		return
	end
	S.startCooldown(player, state, "LassoSnare", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.3)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "LassoSnare", Phase = "Startup", Startup = c.Startup })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local caught = false
		S.fireLasso(player, state, {
			Origin = S.origin(char, r, HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			OnHit = function(target, position)
				if caught then
					return
				end
				caught = true
				if not S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = direction, Position = position, Source = "MountainTimLasso" }) then
					return
				end
				S.fx("Ability", { Character = char, Act = ACT, Move = "LassoSnare", Phase = "Snag", Target = target, Duration = c.ReelTime })
				local done = false
				for i = 0, math.max(1, math.floor(c.ReelTime / c.ReelTick)) - 1 do
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
-- ROPE SPLIT
---------------------------------------------------------------------------
local function ropeSplit(S, player, state, aim)
	local c = cfg.RopeSplit
	if not ready(S, player, state, "RopeSplit", 2) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	if not Moves.safeStep(character, root, direction, c.Distance) then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "RopeSplit", c.Cooldown, 2)
	S.lock(state, c.Windup + c.Travel + 0.2)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "RopeSplit", Phase = "Startup", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local from = r.Position
		local to = Moves.safeStep(char, r, direction, c.Distance)
		if not to then
			return
		end
		local iframes = S.Adapter.Settings.IFrameAttribute
		char:SetAttribute(iframes, true)
		char:SetAttribute("RopeSplit", true)
		S.fx("Ability", { Character = char, Act = ACT, Move = "RopeSplit", Phase = "Split", From = from, To = to, Direction = direction, Travel = c.Travel })
		-- Everyone along the rope gets sliced by the passing pieces.
		local length = (to - from).Magnitude
		local mid = (from + to) / 2
		Moves.boxHit(S, player, CFrame.lookAt(mid, mid + direction), Vector3.new(c.Width, 6, length + 2), { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = direction, Source = "MountainTimSplit" }, 5)
		task.delay(c.Travel, function()
			char:SetAttribute("RopeSplit", nil)
			char:SetAttribute(iframes, nil)
			if char.Parent and state.Life == life then
				char:PivotTo(CFrame.lookAt(to, to + direction))
				S.fx("Ability", { Character = char, Act = ACT, Move = "RopeSplit", Phase = "Rejoin", Position = to })
			end
		end)
	end)
end

---------------------------------------------------------------------------
-- SPLIT PUNCH
---------------------------------------------------------------------------
local function splitPunch(S, player, state, aim)
	local c = cfg.SplitPunch
	if not ready(S, player, state, "SplitPunch", 3) then
		return
	end
	S.startCooldown(player, state, "SplitPunch", c.Cooldown, 3)
	S.lock(state, c.Windup + c.Hits * c.HitEvery + 0.3)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "SplitPunch", Phase = "Startup", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		S.fx("Ability", { Character = character, Act = ACT, Move = "SplitPunch", Phase = "Fly", Direction = direction, Range = c.Range, Hits = c.Hits, HitEvery = c.HitEvery })
		for i = 1, c.Hits do
			task.delay((i - 1) * c.HitEvery, function()
				local char, _, r = alive(S, player)
				if not char or state.Life ~= life then
					return
				end
				local mid = r.Position + direction * (c.Range / 2)
				local last = i == c.Hits
				Moves.boxHit(S, player, CFrame.lookAt(mid, mid + direction), Vector3.new(c.Width, 5, c.Range), { Damage = c.Damage, Stun = c.Stun, Knockback = last and c.FinalKnockback or 2, Launch = last and 10 or nil, Direction = direction, Source = "MountainTimPunch" }, 4)
			end)
		end
	end)
end

function Tim.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		lassoSnare(S, player, state, aim)
	elseif slot == 2 then
		ropeSplit(S, player, state, aim)
	elseif slot == 3 then
		splitPunch(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- LONESOME ROUNDUP (ultimate)
---------------------------------------------------------------------------
function Tim.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + u.RideHits * u.RideEvery + u.ReelTime + 0.4)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Start", Windup = u.Windup, Radius = u.Radius })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local char, _, r = alive(S, player)
		local roped = {}
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, u.Radius, u.MaxTargets)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.Adapter.canBeHit(player, target) and S.Hitbox.lineOfSight(r.Position + Vector3.new(0, 2, 0), tr.Position, { char, target }) then
				table.insert(roped, target)
			end
		end
		S.finishUltimate(player, state)
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Rope", Targets = roped, RideHits = u.RideHits, RideEvery = u.RideEvery, ReelTime = u.ReelTime })
		-- His pieces ride the ropes and hit, again and again.
		for i = 1, u.RideHits do
			task.delay((i - 1) * u.RideEvery, function()
				if state.Life ~= life then
					return
				end
				for _, target in ipairs(roped) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr then
						S.hit(player, target, { Damage = u.RideDamage, Stun = u.RideStun, Knockback = 0, Direction = tr.Position - r.Position, Position = tr.Position, Source = "MountainTimRoundup" })
					end
				end
			end)
		end
		-- Then the rope yanks everyone together in front of him...
		local reelStart = u.RideHits * u.RideEvery
		for i = 0, math.floor(u.ReelTime / u.ReelTick) - 1 do
			task.delay(reelStart + i * u.ReelTick, function()
				local _, _, rr = alive(S, player)
				if not rr or state.Life ~= life then
					return
				end
				local point = rr.Position + rr.CFrame.LookVector * 5
				for _, target in ipairs(roped) do
					if target.Parent then
						pull(S, target, point, 3)
					end
				end
			end)
		end
		-- ...and slams the rope down on them.
		task.delay(reelStart + u.ReelTime + 0.05, function()
			local _, _, rr = alive(S, player)
			if not rr or state.Life ~= life then
				return
			end
			local pos = rr.Position + rr.CFrame.LookVector * 5
			Moves.aoe(S, player, pos, u.SlamRadius, { Damage = u.SlamDamage, Stun = u.SlamStun, Knockback = u.SlamKnockback, Launch = u.SlamLaunch, Source = "MountainTimRoundup" }, 8)
			S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Slam", Position = pos, Radius = u.SlamRadius })
		end)
	end)
end

function Tim.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute("RopeSplit", nil)
		state.Character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
	end
end

return Tim
end

-- ======================================================================
-- MODULE: MountainTimOutfit
-- ======================================================================
__modules["MountainTimOutfit"] = function()
--[[
	MountainTimOutfit  (ServerScriptService.SpinServer.MountainTimOutfit)

	Gives a character Mountain Tim's cowboy look while they play him (TuskAct 9),
	built from blocky parts (no catalog asset ids):
	  * a tall brown cowboy hat with a wide brim and a dark band
	  * a red bandana round the neck
	  * an open leather vest, a belt with a gold buckle and a coiled lasso
	    at his hip
	  * leather chaps, dark boots with silver spurs
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local MountainTimOutfit = {}
MountainTimOutfit.Act = 9

local C = {
	Hat = Color3.fromRGB(150, 100, 58),
	HatDark = Color3.fromRGB(110, 70, 40),
	Band = Color3.fromRGB(45, 30, 22),
	Bandana = Color3.fromRGB(190, 40, 38),
	Vest = Color3.fromRGB(120, 78, 44),
	VestTrim = Color3.fromRGB(80, 50, 28),
	Belt = Color3.fromRGB(60, 38, 22),
	Buckle = Color3.fromRGB(230, 190, 70),
	Rope = Color3.fromRGB(205, 170, 110),
	Chaps = Color3.fromRGB(138, 92, 52),
	Boot = Color3.fromRGB(70, 44, 28),
	Spur = Color3.fromRGB(200, 205, 215),
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
	local top = head.Size.Y / 2
	-- Cowboy hat: wide brim, tall crown with a dent, dark band.
	piece(head, outfit, "Brim", Vector3.new(head.Size.X + 1.3 * s, 0.14 * s, head.Size.Z + 1.1 * s), C.HatDark, CFrame.new(0, top + 0.02 * s, 0.02 * s))
	piece(head, outfit, "BrimFront", Vector3.new(head.Size.X + 0.9 * s, 0.12 * s, 0.4 * s), C.Hat, CFrame.new(0, top + 0.08 * s, -head.Size.Z / 2 - 0.45 * s) * CFrame.Angles(0.18, 0, 0))
	piece(head, outfit, "Crown", Vector3.new(head.Size.X * 0.85, 0.85 * s, head.Size.Z * 0.8), C.Hat, CFrame.new(0, top + 0.5 * s, 0.03 * s))
	piece(head, outfit, "Dent", Vector3.new(0.18 * s, 0.12 * s, head.Size.Z * 0.6), C.HatDark, CFrame.new(0, top + 0.92 * s, 0.03 * s))
	piece(head, outfit, "Band", Vector3.new(head.Size.X * 0.87, 0.18 * s, head.Size.Z * 0.82), C.Band, CFrame.new(0, top + 0.18 * s, 0.03 * s))
	-- Bandana: knotted round the neck, a triangle hanging in front.
	piece(head, outfit, "Bandana", Vector3.new(head.Size.X * 0.95, 0.22 * s, head.Size.Z * 0.95), C.Bandana, CFrame.new(0, -top - 0.08 * s, 0))
	piece(head, outfit, "BandanaTip", Vector3.new(0.6 * s, 0.5 * s, 0.08 * s), C.Bandana, CFrame.new(0, -top - 0.35 * s, -head.Size.Z / 2 - 0.02 * s) * CFrame.Angles(0, 0, math.pi / 4))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Vest", Vector3.new(s.X * 0.4, s.Y + 0.04, s.Z + 0.1), C.Vest, CFrame.new(side * s.X * 0.3, 0, 0))
			piece(upper, outfit, "VestTrim", Vector3.new(0.1, s.Y + 0.06, 0.06), C.VestTrim, CFrame.new(side * s.X * 0.1, 0, -s.Z / 2 - 0.07))
		end
		piece(upper, outfit, "VestBack", Vector3.new(s.X + 0.06, s.Y + 0.04, 0.08), C.Vest, CFrame.new(0, 0, s.Z / 2 + 0.04))
	end
	local waist = lower or upper
	if waist then
		local y = lower and 0 or -upper.Size.Y / 2 + 0.15
		piece(waist, outfit, "Belt", Vector3.new(waist.Size.X + 0.12, 0.3, waist.Size.Z + 0.12), C.Belt, CFrame.new(0, y, 0))
		piece(waist, outfit, "Buckle", Vector3.new(0.45, 0.32, 0.06), C.Buckle, CFrame.new(0, y, -waist.Size.Z / 2 - 0.09))
		-- Coiled lasso hanging at the right hip (a stepped ring of rope).
		local hip = CFrame.new(waist.Size.X / 2 + 0.25, y - 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			piece(waist, outfit, "Lasso", Vector3.new(0.14, 0.42, 0.14), C.Rope, hip * CFrame.new(math.cos(a) * 0.5, 0, math.sin(a) * 0.5) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.pi / 2))
		end
	end
	-- Chaps and boots with spurs.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Chaps", leg.Size + Vector3.new(0.1, 0.02, 0.1), C.Chaps, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			local tall = foot.Size.Y > 1.8
			local y = -foot.Size.Y / 2 + (tall and 0.35 or foot.Size.Y / 2)
			piece(foot, outfit, "Boot", Vector3.new(foot.Size.X + 0.12, tall and 0.7 or foot.Size.Y + 0.1, foot.Size.Z + 0.2), C.Boot, CFrame.new(0, y, -0.05))
			piece(foot, outfit, "Spur", Vector3.new(0.12, 0.12, 0.3), C.Spur, CFrame.new(0, y - 0.1, foot.Size.Z / 2 + 0.2))
		end
	end
end

function MountainTimOutfit.apply(character)
	if character:FindFirstChild("MountainTimOutfit") then
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
	outfit.Name = "MountainTimOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function MountainTimOutfit.remove(character)
	local outfit = character:FindFirstChild("MountainTimOutfit")
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
		if character:GetAttribute("TuskAct") == MountainTimOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == MountainTimOutfit.Act then
					MountainTimOutfit.apply(character)
				end
			end)
		else
			MountainTimOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function MountainTimOutfit.init()
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

return MountainTimOutfit
end
end
