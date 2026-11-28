--[[
	Gyro_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Gyro Zeppeli: Steel Balls and Ball Breaker.
	Its other half is Gyro_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: GyroEyes
-- ======================================================================
__modules["GyroEyes"] = function()
--[[
	GyroEyes  (ServerScriptService.SpinServer.TuskActs.GyroEyes)

	GYRO WITH THE SAINT'S EYES. Registered as "Act" 29 (Character "Gyro").
	Gyro holding the Saint's Corpse EYES puts them to use: one in his own
	eye socket, one set into his steel ball. While he holds them his moves
	change; when he loses them (or goes down) he's back to Act 5.
	  M1        STEEL BALL COMBO (the same as ever)
	  Ability 1 SCAN SHOT: he tosses the eye-ball up, throws a second ball
	            into it at the top, and knocks it DOWN onto the nearest enemy in
	            front (it comes from above, so it goes over cover), steering
	            after them; whoever it hits is left revealed to him for a while
	  Ability 2 SCAN: the eyes see through everything: every enemy near is
	            revealed to him (through walls) and takes more damage from him
	            for a while
	  Ability 3 EYE RICOCHET: the eye-ball picks its path, bouncing from one
	            enemy to the next nearest
	  Ultimate  SCAN: GOLDEN SPIN: the eyes find the nearest enemy anywhere;
	            a golden-spinning ball goes straight through everything to
	            them and leaves them paralysed by the Spin
	The switch (5 <-> 29) is watched here (Init): CorpseParts holding "Eyes".
	Numbers: TuskConfig.GyroEyes. All damage goes through S.hit (CombatAdapter).
]]

local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local Moves = __require("TuskMoves")

local GyroEyes = {}
local cfg = TuskConfig.GyroEyes
local ACT = 29
local GYRO = 5

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

local function aliveModel(model)
	local h = model and model.Parent and model:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end

-- Scanned: revealed to him, and his hits on them land harder (CombatAdapter).
local function scan(char, target, time)
	local untilT = now() + time
	if (target:GetAttribute("ScannedUntil") or 0) < untilT then
		target:SetAttribute("ScannedUntil", untilT)
	end
	if (char:GetAttribute("ScanBonusUntil") or 0) < untilT then
		char:SetAttribute("ScanBonusUntil", untilT)
		char:SetAttribute("ScanBonus", cfg.Scan.BonusDamage)
	end
end

function GyroEyes.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: SCAN SHOT (toss one ball up, knock it down onto them with another)
---------------------------------------------------------------------------
local function scanShot(S, player, state, aim)
	local c = cfg.ScanShot
	if not ready(S, player, state, "ScanShot", 1) then
		return
	end
	S.startCooldown(player, state, "ScanShot", c.Cooldown, 1)
	S.lock(state, c.TossTime + c.StrikeTime + 0.15)
	local character, _, root = alive(S, player)
	local life = state.Life
	local look = Moves.flat(S.aim(aim, root))
	-- The eye-ball goes up above him.
	local hand = S.origin(character, root, Moves.HAND)
	local apex = root.Position + look * c.TossForward + Vector3.new(0, c.TossHeight, 0)
	local id = tostring({})
	S.fx("Ability", { Character = character, Act = ACT, Move = "ScanShot", Phase = "Toss", Id = id, From = hand, Apex = apex, Time = c.TossTime })
	-- At the top, the second ball meets it.
	task.delay(c.TossTime, function()
		if not S.stillValid(player, state, life) then
			S.fx("Ability", { Act = ACT, Move = "ScanShot", Phase = "End", Id = id, Position = apex, Hit = false })
			return
		end
		local char, _, r = alive(S, player)
		local from = S.origin(char, r, Moves.HAND)
		S.fx("Ability", { Character = char, Act = ACT, Move = "ScanShot", Phase = "Strike", Id = id, From = from, Apex = apex, Time = c.StrikeTime })
		task.delay(c.StrikeTime, function()
			if not S.stillValid(player, state, life) then
				S.fx("Ability", { Act = ACT, Move = "ScanShot", Phase = "End", Id = id, Position = apex, Hit = false })
				return
			end
			-- The eye picks its target, and the first ball dives down at them.
			local target = Moves.findTarget(S, char, r, c.LockRange, c.Cone, look)
			local tr = target and target:FindFirstChild("HumanoidRootPart")
			local aimAt = tr and tr.Position or Moves.groundBelow(r.Position + look * 40, { char })
			local pos = apex
			local vel = (aimAt - pos).Unit * c.Speed
			S.fx("Ability", { Character = char, Act = ACT, Move = "ScanShot", Phase = "Dive", Id = id, From = pos, Direction = vel.Unit, Target = target, Speed = c.Speed, Turn = c.Turn, Life = c.Life, Aim = aimAt })
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { char }
			local t, step = 0, 1 / 30
			local function landed(at, victim)
				local hitIt = false
				if victim then
					local vr = victim:FindFirstChild("HumanoidRootPart")
					hitIt = S.hit(player, victim, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = Moves.flat(vel), Position = vr and vr.Position or at, Source = "GyroEyesShot" })
					if hitIt then
						scan(char, victim, c.RevealTime)
					end
				end
				-- The ground where it lands takes a hit too.
				Moves.aoe(S, player, at, c.SplashRadius, { Damage = c.SplashDamage, Stun = 0.3, Knockback = 12, Source = "GyroEyesShot" }, 6, victim and { [victim] = true } or nil)
				S.fx("Ability", { Character = char, Act = ACT, Move = "ScanShot", Phase = "End", Id = id, Position = at, Hit = hitIt, Target = hitIt and victim or nil, Reveal = c.RevealTime, Radius = c.SplashRadius })
			end
			local function tick()
				t = t + step
				local ttr = target and aliveModel(target) and target:FindFirstChild("HumanoidRootPart")
				if ttr then
					local want = (ttr.Position - pos).Unit * c.Speed
					vel = (vel + (want - vel) * math.min(1, c.Turn * step)).Unit * c.Speed
				end
				local move = vel * step
				local wall = workspace:Raycast(pos, move, params)
				if wall and not (wall.Instance.Parent and wall.Instance.Parent:FindFirstChildOfClass("Humanoid")) then
					landed(wall.Position, nil)
					return
				end
				pos = pos + move
				local victim
				if ttr and (ttr.Position - pos).Magnitude <= c.HitRadius then
					victim = target
				else
					for _, other in ipairs(S.Hitbox.inRadius(char, pos, c.HitRadius, 1)) do
						victim = other
					end
				end
				if victim then
					landed(pos, victim)
					return
				end
				if t >= c.Life then
					landed(pos, nil)
					return
				end
				task.delay(step, tick)
			end
			task.delay(step, tick)
		end)
	end)
end

---------------------------------------------------------------------------
-- 2: SCAN
---------------------------------------------------------------------------
local function scanAll(S, player, state)
	local c = cfg.Scan
	if not ready(S, player, state, "Scan", 2) then
		return
	end
	S.startCooldown(player, state, "Scan", c.Cooldown, 2)
	S.lock(state, 0.3)
	local char, _, r = alive(S, player)
	local found = {}
	for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, c.Range, 30)) do
		if aliveModel(target) then
			scan(char, target, c.Time)
			table.insert(found, target)
		end
	end
	char:SetAttribute("ScanBonusUntil", now() + c.Time)
	char:SetAttribute("ScanBonus", c.BonusDamage)
	S.fx("Ability", { Character = char, Act = ACT, Move = "Scan", Phase = "Pulse", Position = r.Position, Range = c.Range, Time = c.Time, Targets = found })
end

---------------------------------------------------------------------------
-- 3: EYE RICOCHET
---------------------------------------------------------------------------
local function ricochet(S, player, state, aim)
	local c = cfg.Ricochet
	if not ready(S, player, state, "Ricochet", 3) then
		return
	end
	S.startCooldown(player, state, "Ricochet", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "Ricochet", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = Moves.flat(S.aim(aim, r))
		local from = S.origin(char, r, Moves.HAND)
		-- Its path: the first in front, then the nearest one not yet hit.
		local path, hitSet = {}, {}
		local current = Moves.findTarget(S, char, r, c.FirstRange, c.Cone, dir)
		local at = from
		while current and #path < c.Bounces do
			local tr = current:FindFirstChild("HumanoidRootPart")
			if not tr then
				break
			end
			table.insert(path, { Target = current, Position = tr.Position })
			hitSet[current] = true
			at = tr.Position
			local best, bestD
			for _, other in ipairs(S.Hitbox.inRadius(char, at, c.Range, 20)) do
				local orr = other:FindFirstChild("HumanoidRootPart")
				if orr and not hitSet[other] and aliveModel(other) then
					local d = (orr.Position - at).Magnitude
					if not bestD or d < bestD then
						best, bestD = other, d
					end
				end
			end
			current = best
		end
		local points = { from }
		for _, p in ipairs(path) do
			table.insert(points, p.Position)
		end
		if #path == 0 then
			table.insert(points, from + dir * c.FirstRange)
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "Ricochet", Phase = "Bounce", Points = points, Gap = c.Gap })
		for i, p in ipairs(path) do
			task.delay(i * c.Gap, function()
				if p.Target.Parent then
					local d = (p.Position - points[i])
					S.hit(player, p.Target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = d.Magnitude > 0.1 and d.Unit or dir, Position = p.Position, Source = "GyroEyesRicochet" })
				end
			end)
		end
	end)
end

function GyroEyes.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		scanShot(S, player, state, aim)
	elseif slot == 2 then
		scanAll(S, player, state)
	elseif slot == 3 then
		ricochet(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- SCAN: GOLDEN SPIN (ultimate)
---------------------------------------------------------------------------
function GyroEyes.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	local char, _, r = alive(S, player)
	-- The eyes find the nearest enemy anywhere in range (walls don't matter).
	local best, bestD
	for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, u.Range, 40)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and aliveModel(target) then
			local d = (tr.Position - r.Position).Magnitude
			if not bestD or d < bestD then
				best, bestD = target, d
			end
		end
	end
	if not best then
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local life = state.Life
	S.lock(state, u.Windup + 0.3)
	char:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Lock", Target = best, Windup = u.Windup })
	task.delay(u.Windup, function()
		if char.Parent then
			char:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local _, _, root = alive(S, player)
		local tr = best:FindFirstChild("HumanoidRootPart")
		if not tr or not aliveModel(best) then
			S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Lost" })
			return
		end
		local from = root.Position + Vector3.new(0, 1.5, 0)
		local to = tr.Position
		local d = to - from
		local dir = d.Magnitude > 0.1 and d.Unit or root.CFrame.LookVector
		-- Straight through everything: anyone else on the line is hit on the way.
		local mid = (from + to) / 2
		for _, other in ipairs(S.Hitbox.inBox(char, CFrame.lookAt(mid, to), Vector3.new(u.Width, u.Width + 2, d.Magnitude), 10)) do
			if other ~= best then
				local orr = other:FindFirstChild("HumanoidRootPart")
				S.hit(player, other, { Damage = u.PassDamage, Stun = 0.6, Knockback = 20, Direction = dir, Position = orr and orr.Position or mid, Source = "GyroEyesUlt" })
			end
		end
		S.hit(player, best, { Damage = u.Damage, Stun = u.Stun, Knockback = u.Knockback, Direction = dir, Position = to, Source = "GyroEyesUlt", Unblockable = true })
		scan(char, best, 4)
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Spin", From = from, To = to, Target = best, Stun = u.Stun })
	end)
end

function GyroEyes.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
	end
end

---------------------------------------------------------------------------
-- The switch: Gyro holding the Eyes is Act 29; without them, Act 5.
---------------------------------------------------------------------------
local function holdsEyes(character)
	for id in string.gmatch(character:GetAttribute("CorpseParts") or "", "[^,]+") do
		if id == "Eyes" then
			return true
		end
	end
	return false
end

function GyroEyes.Init(S)
	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		timer = timer + dt
		if timer < 0.5 then
			return
		end
		timer = 0
		for who, state in pairs(S.States or {}) do
			local character = state.Character
			local act = state.Act
			if character and character.Parent and (act == GYRO or act == ACT) and not S.isBusy(state) and not state.Charging then
				local want = holdsEyes(character) and ACT or GYRO
				if want ~= act and Registry.isImplemented(want) then
					pcall(S.select, who, want, true)
				end
			end
		end
	end)
end

return GyroEyes
end

-- ======================================================================
-- MODULE: GyroOutfit
-- ======================================================================
__modules["GyroOutfit"] = function()
--[[
	GyroOutfit  (ServerScriptService.SpinServer.GyroOutfit)

	Gives a character Gyro Zeppeli's hat and hair while they play Gyro
	(TuskAct 5), built from parts so no catalog asset ids are needed:
	  * tan wide-brimmed hat with slots cut round the brim, slits round the
	    crown, a domed top and two big ridged silver goggles on a strap
	  * long blond hair with side locks, braids and a fringe
	With the Saint's Corpse EYES (TuskAct 29) the corpse's eye sits in his
	face, just under his right eye: a white eyeball with a brown iris in a
	dark, stitched socket.
	The player's own clothes stay on. Their own hats/hair are hidden while
	they play Gyro and come back when they switch. Built on the server so
	every player sees it.
]]

local Players = game:GetService("Players")

local GyroOutfit = {}
GyroOutfit.GyroAct = 5
GyroOutfit.EyesAct = 29

local function isGyro(act)
	return act == GyroOutfit.GyroAct or act == GyroOutfit.EyesAct
end

local C = {
	Hat = Color3.fromRGB(206, 168, 128),
	HatShade = Color3.fromRGB(150, 105, 70),
	Slot = Color3.fromRGB(55, 38, 26),
	Strap = Color3.fromRGB(80, 84, 92),
	Goggle = Color3.fromRGB(176, 182, 192),
	HatBand = Color3.fromRGB(60, 40, 90),
	Gold = Color3.fromRGB(235, 190, 70),
	Hair = Color3.fromRGB(240, 205, 110),
	HairDark = Color3.fromRGB(210, 170, 80),
	Shirt = Color3.fromRGB(102, 64, 150),
	Pants = Color3.fromRGB(70, 46, 110),
}

local saved = setmetatable({}, { __mode = "k" }) -- character -> what to restore

local function piece(parent, outfit, props, offset, ellipsoid)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	if ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = outfit
	return p
end

-- Gyro's hat (from the owner's pictures): tan, a wide brim with slots cut
-- all the way round, slits around the crown, a domed top, and two big silver
-- goggles with ridged lenses strapped to the front.
local function hat(head, outfit)
	local s = head.Size.Y / 1.2
	local top = head.Size.Y * 0.5
	local base = CFrame.new(0, top - 0.05 * s, 0.05 * s) * CFrame.Angles(-0.12, 0, 0)
	local tan, tanDark = C.Hat, C.HatShade
	piece(head, outfit, { Name = "HatBrim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1 * s, 2.9 * s, 2.9 * s), Color = tan }, base * CFrame.Angles(0, 0, math.pi / 2))
	piece(head, outfit, { Name = "HatBrimEdge", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.09 * s, 2.96 * s, 2.96 * s), Color = tanDark }, base * CFrame.new(0, -0.01 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
	-- Slots cut into the brim, all the way round.
	for i = 0, 21 do
		local a = i / 22 * math.pi * 2
		local r = 1.08 * s
		piece(head, outfit, { Name = "BrimSlot", Size = Vector3.new(0.08 * s, 0.03 * s, 0.34 * s), Color = C.Slot }, base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.055 * s, -r))
	end
	-- Crown with slits, domed top.
	piece(head, outfit, { Name = "HatCrown", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.72 * s, 1.45 * s, 1.45 * s), Color = tan }, base * CFrame.new(0, 0.4 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
	piece(head, outfit, { Name = "HatTop", Size = Vector3.new(1.45, 0.42, 1.45) * s, Color = Color3.fromRGB(226, 196, 160) }, base * CFrame.new(0, 0.76 * s, 0), true)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		piece(head, outfit, { Name = "CrownSlit", Size = Vector3.new(0.06 * s, 0.34 * s, 0.03 * s), Color = C.Slot }, base * CFrame.new(0, 0.48 * s, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.73 * s))
	end
	-- Goggle strap around the crown.
	piece(head, outfit, { Name = "GoggleStrap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.16 * s, 1.5 * s, 1.5 * s), Color = C.Strap }, base * CFrame.new(0, 0.24 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
	-- Two big silver goggles with horizontal ridges, joined by a bridge.
	for _, side in ipairs({ -1, 1 }) do
		local lensCF = base * CFrame.new(side * 0.4 * s, 0.38 * s, -0.8 * s) * CFrame.Angles(0, side * 0.35, 0)
		piece(head, outfit, { Name = "GoggleRim", Size = Vector3.new(0.8, 0.62, 0.28) * s, Color = C.Strap, Material = Enum.Material.Metal }, lensCF * CFrame.new(0, 0, 0.04 * s), true)
		piece(head, outfit, { Name = "GoggleLens", Size = Vector3.new(0.72, 0.55, 0.32) * s, Color = C.Goggle, Material = Enum.Material.Metal, Reflectance = 0.25 }, lensCF, true)
		for r = -1, 1 do
			piece(head, outfit, { Name = "GoggleRidge", Size = Vector3.new(0.58 * s, 0.04 * s, 0.05 * s), Color = C.Strap, Material = Enum.Material.Metal }, lensCF * CFrame.new(0, r * 0.13 * s, -0.15 * s))
		end
	end
	piece(head, outfit, { Name = "GoggleBridge", Size = Vector3.new(0.22, 0.14, 0.14) * s, Color = C.Strap, Material = Enum.Material.Metal }, base * CFrame.new(0, 0.38 * s, -0.84 * s))
end

local function hair(head, outfit)
	local s = head.Size.Y / 1.2
	piece(head, outfit, { Name = "HairBack", Size = Vector3.new(1.25, 1.5, 0.55) * s, Color = C.Hair }, CFrame.new(0, -0.25 * s, 0.45 * s), true)
	piece(head, outfit, { Name = "HairTop", Size = Vector3.new(1.28, 0.6, 1.25) * s, Color = C.Hair }, CFrame.new(0, 0.38 * s, 0.05 * s), true)
	-- Long side locks framing the face, and two braids hanging past the shoulders.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, { Name = "SideHair", Size = Vector3.new(0.32, 1.5, 0.7) * s, Color = C.Hair }, CFrame.new(side * 0.66 * s, -0.35 * s, 0.12 * s), true)
		for i = 0, 5 do
			piece(head, outfit, { Name = "Braid", Size = Vector3.new(0.26, 0.34, 0.26) * s, Color = (i % 2 == 0) and C.Hair or C.HairDark }, CFrame.new(side * 0.78 * s, (-0.55 - i * 0.28) * s, -0.05 * s), true)
		end
	end
	-- Short fringe peeking out under the hat brim.
	piece(head, outfit, { Name = "Fringe", Size = Vector3.new(1.1, 0.25, 0.3) * s, Color = C.Hair }, CFrame.new(0, 0.42 * s, -0.5 * s), true)
end

function GyroOutfit.apply(character)
	if character:FindFirstChild("GyroOutfit") then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local store = { Hidden = {} }
	saved[character] = store
	-- Hide the player's own hats and hair so they don't poke through Gyro's.
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
	outfit.Name = "GyroOutfit"
	outfit.Parent = character
	hat(head, outfit)
	hair(head, outfit)
end

-- The corpse's eye in his face (Act 29), just under his right eye.
local function corpseEye(character)
	local head = character:FindFirstChild("Head")
	local outfit = character:FindFirstChild("GyroOutfit")
	local want = character:GetAttribute("TuskAct") == GyroOutfit.EyesAct
	local have = outfit and outfit:FindFirstChild("CorpseEye")
	if not head or not outfit or want == (have ~= nil) then
		return
	end
	if not want then
		have:Destroy()
		return
	end
	local eye = Instance.new("Model")
	eye.Name = "CorpseEye"
	eye.Parent = outfit
	local s = head.Size.Y / 1.2
	local at = CFrame.new(0.26 * s, -0.08 * s, -head.Size.Z / 2 - 0.02 * s)
	piece(head, eye, { Name = "Socket", Size = Vector3.new(0.34, 0.34, 0.08) * s, Color = Color3.fromRGB(70, 40, 30) }, at, true)
	piece(head, eye, { Name = "Eyeball", Size = Vector3.new(0.28, 0.28, 0.16) * s, Color = Color3.fromRGB(246, 242, 236) }, at * CFrame.new(0, 0, -0.04 * s), true)
	piece(head, eye, { Name = "Iris", Size = Vector3.new(0.13, 0.13, 0.04) * s, Color = Color3.fromRGB(130, 80, 40) }, at * CFrame.new(-0.03 * s, 0, -0.12 * s), true)
	piece(head, eye, { Name = "Pupil", Size = Vector3.new(0.06, 0.06, 0.03) * s, Color = Color3.fromRGB(16, 12, 10) }, at * CFrame.new(-0.03 * s, 0, -0.14 * s), true)
	for k = -1, 1 do
		piece(head, eye, { Name = "Stitch", Size = Vector3.new(0.03, 0.12, 0.03) * s, Color = Color3.fromRGB(150, 120, 90) }, at * CFrame.new(0.2 * s, k * 0.1 * s, -0.02 * s) * CFrame.Angles(0, 0, 0.6))
	end
end
GyroOutfit.corpseEye = corpseEye

function GyroOutfit.remove(character)
	local outfit = character:FindFirstChild("GyroOutfit")
	if outfit then
		outfit:Destroy()
	end
	local store = saved[character]
	if not store then
		return
	end
	saved[character] = nil
	for handle, transparency in pairs(store.Hidden) do
		if handle.Parent then
			handle.Transparency = transparency
		end
	end
end

local function watch(character)
	local function update()
		if isGyro(character:GetAttribute("TuskAct")) then
			-- Wait for the avatar's clothes/accessories to load before swapping them.
			task.delay(0.3, function()
				if character.Parent and isGyro(character:GetAttribute("TuskAct")) then
					GyroOutfit.apply(character)
					corpseEye(character)
				end
			end)
		else
			GyroOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function GyroOutfit.init()
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

return GyroOutfit
end

-- ======================================================================
-- MODULE: GyroZeppeli
-- ======================================================================
__modules["GyroZeppeli"] = function()
--[[
	GyroZeppeli  (ServerScriptService.SpinServer.TuskActs.GyroZeppeli)

	Gyro Zeppeli: Steel Ball moveset (registered as "Act" 5 so it reuses the
	Tusk ability system: cooldowns, HUD, ultimate meter, input).
	  M1        STEEL BALL COMBO: jab, hook, kick, spinning-ball smash (area)
	  Ability 1 STEEL BALL THROW: the ball flies out and BOUNCES off walls (up
	            to MaxBounces times, each bank shot hits harder), then returns
	            to Gyro's hand (it can hit on the way back)
	  Ability 2 SPIN TORNADO: bowl the spinning ball along the ground; it
	            becomes a travelling tornado that pulls enemies in, juggles
	            them and bursts (stops at walls)
	  Ability 3 SPIN VIBRATION: press the spinning ball into the enemy in front:
	            paralysis (long stun) and a small launch
	  Ultimate  BALL BREAKER: spiral build-up, a huge ball opens a spinning
	            vortex that pulls enemies in, then bursts
	Numbers: TuskConfig.Gyro. All damage goes through S.hit (CombatAdapter).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Gyro = {}
local cfg = TuskConfig.Gyro
local HAND = CFrame.new(0.9, 0.6, -1.6)

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Gyro.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 5)
end

-- Short body "shake" slow from the Spin (stackable, always removed).
local function spinSlow(S, target, multiplier, seconds)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local key = "GyroSpin"
	S.Adapter.setMoveModifier(humanoid, key, multiplier)
	target:SetAttribute("GyroSpinShake", true)
	local token = {}
	target:SetAttribute("GyroSpinToken", tostring(token))
	task.delay(seconds, function()
		if humanoid.Parent and target:GetAttribute("GyroSpinToken") == tostring(token) then
			S.Adapter.setMoveModifier(humanoid, key, nil)
			target:SetAttribute("GyroSpinShake", nil)
		end
	end)
end

local function steelBallThrow(S, player, state, aim)
	local c = cfg.SteelBallThrow
	if not ready(S, player, state, "SteelBallThrow", 1) then
		return
	end
	S.startCooldown(player, state, "SteelBallThrow", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.25)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 5, Move = "SteelBallThrow", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local hitOut = {}
		local maxBounces = c.MaxBounces or 3

		-- The ball spins its way back to Gyro's hand from wherever it stopped.
		local function returnToHand(position)
			local _, _, rr = alive(S, player)
			if not rr or state.Life ~= life then
				S.fx("Ability", { Character = char, Act = 5, Move = "SteelBallThrow", Phase = "Caught" })
				return
			end
			local back = rr.Position + Vector3.new(0, 1, 0) - position
			if back.Magnitude < 2 then
				S.fx("Ability", { Character = char, Act = 5, Move = "SteelBallThrow", Phase = "Caught" })
				return
			end
			S.fireBall(player, state, {
				Origin = position,
				Direction = back.Unit,
				Speed = c.ReturnSpeed,
				Radius = c.Radius,
				Range = back.Magnitude,
				Style = "Return",
				OnHit = function(target, pos)
					if not hitOut[target] then
						hitOut[target] = true
						S.hit(player, target, { Damage = c.ReturnDamage, Stun = 0.3, Knockback = 8, Direction = back.Unit, Position = pos, Source = "GyroSteelBall" })
					end
				end,
				OnEnd = function()
					S.fx("Ability", { Character = char, Act = 5, Move = "SteelBallThrow", Phase = "Caught" })
				end,
			})
		end

		-- One straight flight. When it hits a wall it bounces off (reflects
		-- around the surface normal) and keeps flying with the range it has left.
		local function launch(origin, dir, rangeLeft, bounce)
			S.fireBall(player, state, {
				Origin = origin,
				Direction = dir,
				Speed = c.Speed * (1 + bounce * 0.08), -- each bounce comes off a little faster
				Radius = c.Radius,
				Range = rangeLeft,
				Style = "Throw",
				Bounce = bounce,
				OnHit = function(target, position)
					if hitOut[target] then
						return
					end
					hitOut[target] = true
					-- Bank shots hit harder.
					local damage = c.Damage + bounce * (c.BounceBonusDamage or 2)
					S.hit(player, target, { Damage = damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Position = position, Source = "GyroSteelBall" })
				end,
				OnEnd = function(position, normal, hitCharacter, projectile)
					if state.Life ~= life then
						S.fx("Ability", { Character = char, Act = 5, Move = "SteelBallThrow", Phase = "Caught" })
						return
					end
					local traveled = projectile and projectile.Traveled or rangeLeft
					local remaining = rangeLeft - traveled
					if not hitCharacter and projectile and projectile.HitWall and bounce < maxBounces and remaining > 6 then
						local n = normal.Unit
						local reflected = dir - 2 * dir:Dot(n) * n
						if reflected.Magnitude < 0.1 then
							reflected = -dir
						end
						reflected = reflected.Unit
						-- Start just off the surface so it doesn't hit the same wall again.
						local from = position + n * (c.Radius + 0.3)
						S.fx("Ability", { Character = char, Act = 5, Move = "SteelBallThrow", Phase = "Bounce", Position = position, Normal = n, Direction = reflected, Bounce = bounce + 1 })
						launch(from, reflected, remaining, bounce + 1)
						return
					end
					returnToHand(position)
				end,
			})
		end

		launch(S.origin(char, r, HAND), direction, c.Range, 0)
	end)
end

-- SPIN TORNADO: the spinning ball is bowled along the ground and becomes a
-- travelling tornado that pulls enemies in, juggles them, then bursts.
local function spinTornado(S, player, state, aim)
	local c = cfg.SpinTornado
	if not ready(S, player, state, "SpinTornado", 2) then
		return
	end
	S.startCooldown(player, state, "SpinTornado", c.Cooldown, 2)
	S.lock(state, c.Startup + 0.3)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	local id = tostring(os.clock()) .. player.UserId
	S.fx("Ability", { Character = character, Act = 5, Move = "SpinTornado", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local pos = Moves.groundBelow(r.Position + direction * 4, { char }) + Vector3.new(0, 3, 0)
		S.fx("Tornado", { Act = 5, Id = id, Phase = "Start", Position = pos, Radius = c.Radius, Duration = c.Duration })
		local ticks = math.floor(c.Duration / c.Tick)
		local stopped = false
		for i = 1, ticks do
			task.delay(i * c.Tick, function()
				if stopped then
					return
				end
				-- Move forward; stop at walls; follow the ground.
				local step = direction * c.Speed * c.Tick
				if workspace:Raycast(pos, step * 1.5, params) then
					stopped = true
				else
					pos = Moves.groundBelow(pos + step, { char }) + Vector3.new(0, 3, 0)
				end
				S.fx("Tornado", { Act = 5, Id = id, Phase = "Move", Position = pos })
				for _, target in ipairs(S.Hitbox.inRadius(player.Character, pos, c.Radius, 6)) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr and S.Adapter.canBeHit(player, target) then
						local inward = pos - tr.Position
						S.Adapter.applyKnockback(target, inward, c.Pull, c.Lift)
						S.hit(player, target, { Damage = c.TickDamage, Stun = 0.3, Knockback = 0, Direction = inward, Position = tr.Position, Source = "GyroSpinTornado" })
					end
				end
			end)
		end
		task.delay(c.Duration + 0.05, function()
			Moves.aoe(S, player, pos, c.Radius + 1.5, { Damage = c.BurstDamage, Stun = 0.4, Knockback = c.BurstKnockback, Launch = c.BurstLaunch, Source = "GyroSpinTornado" }, 6)
			S.fx("Tornado", { Act = 5, Id = id, Phase = "Burst", Position = pos, Radius = c.Radius + 1.5 })
		end)
	end)
end

local function spinVibration(S, player, state, aim)
	local c = cfg.SpinVibration
	if not ready(S, player, state, "SpinVibration", 3) then
		return
	end
	S.startCooldown(player, state, "SpinVibration", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.4)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 5, Move = "SpinVibration", Phase = "Startup", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local _, _, r = alive(S, player)
		local cf = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
		local count, hitSet = Moves.boxHit(S, player, cf, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Source = "GyroSpinVibration" }, 2)
		for target in pairs(hitSet) do
			spinSlow(S, target, 0.4, 1.5)
		end
		S.fx("Ability", { Character = character, Act = 5, Move = "SpinVibration", Phase = "Hit", Position = cf.Position, Hit = count > 0 })
	end)
end

function Gyro.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		steelBallThrow(S, player, state, aim)
	elseif slot == 2 then
		spinTornado(S, player, state, aim)
	elseif slot == 3 then
		spinVibration(S, player, state, aim)
	end
end

-- BALL BREAKER
function Gyro.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.lock(state, u.Windup + 0.5)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = 5, Phase = "Start", Windup = u.Windup, Direction = direction })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local _, _, r = alive(S, player)
		S.fx("Ultimate", { Character = character, Act = 5, Phase = "Release", Position = r.Position, Direction = direction })
		S.fireBall(player, state, {
			Origin = S.origin(character, r, CFrame.new(0, 1.5, -3)),
			Direction = direction,
			Speed = u.Speed,
			Radius = u.Radius,
			Range = u.Range,
			Style = "Breaker",
			Scale = u.Radius * 2,
			OnHit = function(target, position)
				S.hit(player, target, { Damage = u.Damage, Stun = 0.5, Knockback = 10, Direction = direction, Position = position, Source = "GyroBallBreaker" })
			end,
			OnEnd = function(position)
				-- The spinning vortex: pulls enemies in, then bursts.
				S.fx("Ultimate", { Character = character, Act = 5, Phase = "Vortex", Position = position, Radius = u.VortexRadius, Duration = u.VortexTime })
				local ticks = math.floor(u.VortexTime / u.TickInterval)
				for i = 1, ticks do
					task.delay(i * u.TickInterval, function()
						for _, target in ipairs(S.Hitbox.inRadius(player.Character, position, u.VortexRadius, 8)) do
							local tr = target:FindFirstChild("HumanoidRootPart")
							if tr and S.Adapter.canBeHit(player, target) then
								local inward = position - tr.Position
								S.Adapter.applyKnockback(target, inward, u.PullStrength, 2)
								S.hit(player, target, { Damage = u.TickDamage, Stun = 0.25, Knockback = 0, Direction = inward, Position = tr.Position, Source = "GyroBallBreaker" })
							end
						end
					end)
				end
				task.delay(u.VortexTime + 0.05, function()
					Moves.aoe(S, player, position, u.VortexRadius + 2, { Damage = u.BurstDamage, Stun = u.Stun, Knockback = u.BurstKnockback, Launch = u.Launch, Source = "GyroBallBreaker" }, 8)
					S.fx("Ultimate", { Character = character, Act = 5, Phase = "Burst", Position = position, Radius = u.VortexRadius + 2 })
				end)
			end,
		})
		S.finishUltimate(player, state)
	end)
end

function Gyro.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
	end
end

return Gyro
end
end
