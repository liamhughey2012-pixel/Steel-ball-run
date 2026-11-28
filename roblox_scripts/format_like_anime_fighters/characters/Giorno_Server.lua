--[[
	Giorno_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Giorno Giovanna (Part 5): Gold Experience, and Gold Experience Requiem from the Requiem Arrow.
	Its other half is Giorno_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "giorno" or __expect.Side ~= "server") then
		error("this is the code for Giorno_Server, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Giorno_Server and put it in ServerScriptService > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: Giorno
-- ======================================================================
__modules["Giorno"] = function()
--[[
	Giorno  (ServerScriptService.SpinServer.TuskActs.Giorno)

	Giorno Giovanna (Part 5, Golden Wind): GOLD EXPERIENCE. Registered as
	"Act" 30. Gold Experience gives LIFE to whatever it touches.
	  M1        MUDA COMBO: Gold Experience punches with him; the 4th is a
	            heavy straight that launches
	  Ability 1 MUDA MUDA RUSH: a storm of punches in front of him that drags
	            them along (he can still walk); the last big "MUDA!" sends
	            them flying
	  Ability 2 LIFE GIVER: TREE: Gold Experience punches the ground; roots
	            race along it to the nearest enemy in front (or a spot ahead)
	            and a tree bursts up under them, launching them
	  Ability 3 SENSE OVERLOAD: a punch that gives them too much life:
	            their mind races, so their body crawls (very slow for a
	            while), and the pain arrives late, all at once
	  Ultimate  LIFE BURST: the ground round him bursts into a jungle:
	            vines hold everyone near, snakes bite them, he grows back
	            what he's lost (heals), then the trees burst and throw them
	The Requiem Arrow turns Gold Experience into GOLD EXPERIENCE REQUIEM
	(Act 31, TuskActs.GoldExperienceRequiem) until he goes down.
	Numbers: TuskConfig.Giorno. All damage goes through S.hit.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Giorno = {}
local cfg = TuskConfig.Giorno
local ACT = 30

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

function Giorno.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: MUDA MUDA RUSH
---------------------------------------------------------------------------
local function mudaRush(S, player, state)
	local c = cfg.MudaRush
	if not ready(S, player, state, "MudaRush", 1) then
		return
	end
	S.startCooldown(player, state, "MudaRush", c.Cooldown, 1)
	S.lock(state, c.Windup + c.Duration + 0.15)
	local character, humanoid = alive(S, player)
	local life = state.Life
	local untilT = now() + c.Windup + c.Duration
	character:SetAttribute("MudaRushUntil", untilT)
	S.Adapter.setMoveModifier(humanoid, "MudaRush", c.WalkMultiplier)
	S.fx("Ability", { Character = character, Act = ACT, Move = "MudaRush", Phase = "Start", Windup = c.Windup, Duration = c.Duration })
	local ticks = math.max(1, math.floor(c.Duration / c.Tick))
	local function stop()
		if humanoid.Parent then
			S.Adapter.setMoveModifier(humanoid, "MudaRush", nil)
		end
		if character.Parent and character:GetAttribute("MudaRushUntil") == untilT then
			character:SetAttribute("MudaRushUntil", nil)
		end
	end
	for i = 1, ticks do
		task.delay(c.Windup + (i - 1) * c.Tick, function()
			if character:GetAttribute("MudaRushUntil") ~= untilT then
				return
			end
			if not S.stillValid(player, state, life) then
				stop()
				S.fx("Ability", { Character = character, Act = ACT, Move = "MudaRush", Phase = "Stop" })
				return
			end
			local _, _, r = alive(S, player)
			local boxCF = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
			if i == ticks then
				Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.FinalDamage, Stun = c.FinalStun, Knockback = c.FinalKnockback, Launch = c.FinalLaunch, Direction = r.CFrame.LookVector, Source = "GiornoMuda" }, c.MaxTargets)
				S.fx("Ability", { Character = character, Act = ACT, Move = "MudaRush", Phase = "Finish", Position = boxCF.Position, Direction = r.CFrame.LookVector })
				stop()
			else
				local count, hitSet = Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = r.CFrame.LookVector, Source = "GiornoMuda" }, c.MaxTargets)
				for target in pairs(hitSet or {}) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr and not tr.Anchored then
						local to = boxCF.Position - tr.Position
						tr.AssemblyLinearVelocity = Vector3.new(to.X * c.Drag, tr.AssemblyLinearVelocity.Y, to.Z * c.Drag) + r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
					end
				end
				if count > 0 and i % 2 == 0 then
					S.fx("Ability", { Act = ACT, Move = "MudaRush", Phase = "Hit", Position = boxCF.Position })
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- 2: LIFE GIVER: TREE
---------------------------------------------------------------------------
local function tree(S, player, state, aim)
	local c = cfg.Tree
	if not ready(S, player, state, "Tree", 2) then
		return
	end
	S.startCooldown(player, state, "Tree", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.2)
	local character, _, root = alive(S, player)
	local life = state.Life
	local dir = Moves.flat(S.aim(aim, root))
	S.fx("Ability", { Character = character, Act = ACT, Move = "Tree", Phase = "Punch", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local target = Moves.findTarget(S, char, r, c.Range, c.Cone, dir)
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		local spot = Moves.groundBelow(tr and tr.Position or (r.Position + dir * c.MissDistance), { char })
		local from = Moves.groundBelow(r.Position + dir * 2, { char })
		S.fx("Ability", { Character = char, Act = ACT, Move = "Tree", Phase = "Roots", From = from, To = spot, Time = c.Travel })
		task.delay(c.Travel, function()
			if not char.Parent then
				return
			end
			-- It grows right under them if they're still close.
			if tr and tr.Parent and (Vector3.new(tr.Position.X, spot.Y, tr.Position.Z) - spot).Magnitude < c.Radius + 3 then
				spot = Moves.groundBelow(tr.Position, { char })
			end
			Moves.aoe(S, player, spot, c.Radius, { Damage = c.Damage, Stun = c.Stun, Knockback = 4, Launch = c.Launch, Direction = Vector3.new(0, 1, 0), Source = "GiornoTree" }, 6)
			S.fx("Ability", { Character = char, Act = ACT, Move = "Tree", Phase = "Burst", Position = spot, Radius = c.Radius, Life = c.TreeLife })
		end)
	end)
end

---------------------------------------------------------------------------
-- 3: SENSE OVERLOAD
---------------------------------------------------------------------------
local function overload(S, player, state, aim)
	local c = cfg.Overload
	if not ready(S, player, state, "Overload", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local target = Moves.findTarget(S, character, root, c.Range, c.Cone, Moves.flat(S.aim(aim, root)))
	S.startCooldown(player, state, "Overload", target and c.Cooldown or c.MissCooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "Overload", Phase = "Punch", Windup = c.Windup, Target = target })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) or not target or not aliveModel(target) then
			return
		end
		local tr = target:FindFirstChild("HumanoidRootPart")
		local th = target:FindFirstChildOfClass("Humanoid")
		if not tr or not th then
			return
		end
		local landed = S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 2, Direction = Moves.flat(tr.Position - root.Position), Position = tr.Position, Source = "GiornoOverload" })
		if not landed then
			return
		end
		local untilT = now() + c.Time
		target:SetAttribute("SenseOverloadUntil", untilT)
		S.Adapter.setMoveModifier(th, "SenseOverload", c.SlowMultiplier)
		S.fx("Ability", { Character = character, Act = ACT, Move = "Overload", Phase = "Overload", Target = target, Time = c.Time })
		task.delay(c.Time, function()
			if th.Parent then
				S.Adapter.setMoveModifier(th, "SenseOverload", nil)
			end
			if target:GetAttribute("SenseOverloadUntil") ~= untilT then
				return
			end
			target:SetAttribute("SenseOverloadUntil", nil)
			if aliveModel(target) and tr.Parent then
				-- The pain catches up with them, all at once.
				S.hit(player, target, { Damage = c.LateDamage, Stun = c.LateStun, Knockback = 18, Launch = 8, Direction = -tr.CFrame.LookVector, Position = tr.Position, Source = "GiornoOverload", Unblockable = true })
				S.fx("Ability", { Act = ACT, Move = "Overload", Phase = "Pain", Target = target })
			end
		end)
	end)
end

function Giorno.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		mudaRush(S, player, state)
	elseif slot == 2 then
		tree(S, player, state, aim)
	elseif slot == 3 then
		overload(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- LIFE BURST (ultimate)
---------------------------------------------------------------------------
function Giorno.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.3)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Call", Windup = u.Windup })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local char, hum, r = alive(S, player)
		local center = Moves.groundBelow(r.Position, { char })
		local held = {}
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, u.Radius, 14)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.hit(player, target, { Damage = u.GrabDamage, Stun = u.HoldTime + 0.2, Knockback = 0, Position = tr.Position, Source = "GiornoJungle" }) then
				table.insert(held, target)
			end
		end
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Jungle", Position = center, Radius = u.Radius, Targets = held, Time = u.HoldTime })
		-- He grows back what he's lost.
		if hum and hum.Health > 0 then
			hum.Health = math.min(hum.MaxHealth, hum.Health + u.Heal)
		end
		local ticks = math.max(1, math.floor(u.HoldTime / u.Tick))
		for k = 1, ticks do
			task.delay(k * u.Tick, function()
				if state.Life ~= life then
					return
				end
				for _, target in ipairs(held) do
					local tr = target.Parent and target:FindFirstChild("HumanoidRootPart")
					if tr and aliveModel(target) then
						S.hit(player, target, { Damage = u.BiteDamage, Stun = u.Tick + 0.15, Knockback = 0, Position = tr.Position, Source = "GiornoJungle" })
					end
				end
				S.fx("Ultimate", { Act = ACT, Phase = "Bite", Targets = held })
			end)
		end
		task.delay(u.HoldTime, function()
			if state.Life ~= life or not char.Parent then
				S.fx("Ultimate", { Character = char, Act = ACT, Phase = "End" })
				return
			end
			for _, target in ipairs(held) do
				local tr = target.Parent and target:FindFirstChild("HumanoidRootPart")
				if tr and aliveModel(target) then
					local away = Vector3.new(tr.Position.X - center.X, 0, tr.Position.Z - center.Z)
					S.hit(player, target, { Damage = u.FinalDamage, Stun = u.FinalStun, Knockback = u.FinalKnockback, Launch = u.FinalLaunch, Direction = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1), Position = tr.Position, Source = "GiornoJungle", Unblockable = true })
				end
			end
			S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Burst", Position = center, Radius = u.Radius, Targets = held })
		end)
	end)
end

function Giorno.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("MudaRushUntil", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "MudaRush", nil)
		end
	end
end

return Giorno
end

-- ======================================================================
-- MODULE: GiornoOutfit
-- ======================================================================
__modules["GiornoOutfit"] = function()
--[[
	GiornoOutfit  (ServerScriptService.SpinServer.GiornoOutfit)

	Gives a character the look of Giorno Giovanna (Part 5) while they play
	him (TuskAct 30, and 31 with Gold Experience Requiem), built from blocky
	parts (no catalog asset ids), matched to his art:
	  * golden-blond hair swept back, with his THREE ROUND CURLS in a row
	    over the forehead, side locks, and a long BRAID hanging down his back
	  * a pink-violet suit: a long jacket flaring at the hips, a high collar
	    with a gold spiral pin, and a HEART-SHAPED opening at the chest
	  * a gold chain-zip running down from the heart to the hem
	  * three LADYBUG brooches (two on the chest, one low on the jacket)
	  * gold wrist cuffs; fitted trousers; pink shoes
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local GiornoOutfit = {}
GiornoOutfit.Act = 30
GiornoOutfit.Acts = { [30] = true, [31] = true }

local C = {
	Hair = Color3.fromRGB(246, 212, 92),
	HairShade = Color3.fromRGB(214, 170, 60),
	HairDeep = Color3.fromRGB(176, 130, 40),
	Suit = Color3.fromRGB(198, 100, 200),
	SuitShade = Color3.fromRGB(150, 66, 160),
	SuitDeep = Color3.fromRGB(110, 44, 124),
	Skin = Color3.fromRGB(240, 206, 176),
	Gold = Color3.fromRGB(240, 192, 70),
	GoldDark = Color3.fromRGB(196, 146, 40),
	Bug = Color3.fromRGB(34, 52, 96),
	BugDot = Color3.fromRGB(236, 206, 90),
	Shoe = Color3.fromRGB(196, 100, 160),
	Eye = Color3.fromRGB(70, 150, 140),
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

local function cylinder(parent, outfit, name, length, d, color, offset, material)
	local p = piece(parent, outfit, name, Vector3.new(length, d, d), color, offset, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent, outfit, name, d, color, offset, material)
	local p = piece(parent, outfit, name, Vector3.new(d, d, d), color, offset, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A ladybug brooch: a dark-blue shell with gold dots, facing out along -Z.
local function ladybug(parent, outfit, at, s)
	local shell = piece(parent, outfit, "LadybugShell", Vector3.new(0.3, 0.3, 0.12) * s, C.Bug, at)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = shell
	piece(parent, outfit, "LadybugLine", Vector3.new(0.02, 0.28, 0.13) * s, C.BugDot, at * CFrame.new(0, 0, -0.005 * s))
	for _, d in ipairs({ { -0.07, 0.06 }, { 0.07, 0.06 }, { -0.06, -0.07 }, { 0.06, -0.07 } }) do
		ball(parent, outfit, "LadybugDot", 0.07 * s, C.BugDot, at * CFrame.new(d[1] * s, d[2] * s, -0.05 * s))
	end
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Golden hair, swept back and smooth over the top.
	piece(head, outfit, "HairCap", Vector3.new(head.Size.X + 0.1 * s, 0.3 * s, head.Size.Z + 0.14 * s), C.Hair, CFrame.new(0, h + 0.08 * s, 0.04 * s))
	piece(head, outfit, "HairTop", Vector3.new(head.Size.X * 0.9, 0.16 * s, head.Size.Z * 0.95), C.HairShade, CFrame.new(0, h + 0.26 * s, 0.08 * s))
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.12 * s, 0.85 * s, 0.16 * s), C.Hair, CFrame.new(0, h - 0.35 * s, d + 0.05 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HairSide", Vector3.new(0.12 * s, 0.55 * s, head.Size.Z * 0.8), C.Hair, CFrame.new(side * (w + 0.05 * s), h - 0.22 * s, 0.08 * s))
		-- A lock falling down by each cheek.
		piece(head, outfit, "SideLock", Vector3.new(0.12 * s, 0.6 * s, 0.14 * s), C.HairShade, CFrame.new(side * (w - 0.02 * s), -0.05 * s, -d + 0.08 * s) * CFrame.Angles(0, 0, side * 0.12))
		-- Calm, half-closed teal eyes and thin brows.
		piece(head, outfit, "Eye", Vector3.new(0.2 * s, 0.07 * s, 0.03 * s), C.Eye, CFrame.new(side * 0.22 * s, 0.06 * s, -d - 0.01 * s))
		piece(head, outfit, "Lid", Vector3.new(0.24 * s, 0.04 * s, 0.035 * s), C.HairDeep, CFrame.new(side * 0.22 * s, 0.11 * s, -d - 0.012 * s) * CFrame.Angles(0, 0, side * -0.1))
		piece(head, outfit, "Brow", Vector3.new(0.24 * s, 0.035 * s, 0.03 * s), C.HairShade, CFrame.new(side * 0.22 * s, 0.2 * s, -d - 0.01 * s) * CFrame.Angles(0, 0, side * 0.12))
	end
	-- The three round curls in a row over his forehead (a little to his right).
	for k = -1, 1 do
		local at = CFrame.new(k * 0.36 * s - 0.04 * s, h + 0.2 * s, -d + 0.04 * s)
		cylinder(head, outfit, "Curl", 0.22 * s, 0.42 * s, C.Hair, at * CFrame.Angles(0, math.pi / 2, 0))
		cylinder(head, outfit, "CurlRing", 0.23 * s, 0.3 * s, C.HairShade, at * CFrame.Angles(0, math.pi / 2, 0))
		cylinder(head, outfit, "CurlHole", 0.24 * s, 0.15 * s, C.HairDeep, at * CFrame.Angles(0, math.pi / 2, 0))
	end
	-- The long braid down his back.
	local braidTop = CFrame.new(0, -h + 0.1 * s, d + 0.14 * s)
	for k = 0, 5 do
		piece(head, outfit, k % 2 == 0 and "Braid" or "BraidLink", Vector3.new(0.26 * s - k * 0.012 * s, 0.24 * s, 0.2 * s), k % 2 == 0 and C.Hair or C.HairShade, braidTop * CFrame.new(0, -k * 0.21 * s, k * 0.025 * s) * CFrame.Angles(0, 0, (k % 2 == 0 and 0.35 or -0.35)))
	end
	piece(head, outfit, "BraidTip", Vector3.new(0.14 * s, 0.22 * s, 0.14 * s), C.HairShade, braidTop * CFrame.new(0, -6 * 0.21 * s, 0.16 * s))
	piece(head, outfit, "Mouth", Vector3.new(0.16 * s, 0.025 * s, 0.03 * s), Color3.fromRGB(170, 100, 100), CFrame.new(0, -0.26 * s, -d - 0.01 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Jacket", s + Vector3.new(0.08, 0.02, 0.08), C.Suit, CFrame.new())
		-- The high collar, its gold spiral pin.
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.62, 0.42, s.Z * 0.8), C.Suit, CFrame.new(0, top + 0.18, 0.02))
		piece(upper, outfit, "CollarFold", Vector3.new(s.X * 0.64, 0.06, s.Z * 0.82), C.SuitShade, CFrame.new(0, top + 0.38, 0.02))
		cylinder(upper, outfit, "CollarPin", 0.05, 0.2, C.Gold, CFrame.new(0.16, top + 0.2, front - 0.07) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Metal)
		cylinder(upper, outfit, "CollarPinCurl", 0.06, 0.1, C.GoldDark, CFrame.new(0.16, top + 0.2, front - 0.08) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Metal)
		-- The heart-shaped opening: skin showing, two lobes and a point.
		local heart = CFrame.new(0, top - 0.42, front - 0.045)
		for _, side in ipairs({ -1, 1 }) do
			local lobe = piece(upper, outfit, "HeartLobe", Vector3.new(0.42, 0.42, 0.04), C.Skin, heart * CFrame.new(side * 0.16, 0.1, 0))
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.Sphere
			m.Parent = lobe
			-- A gold rim round each lobe.
			piece(upper, outfit, "HeartRim", Vector3.new(0.05, 0.3, 0.05), C.Gold, heart * CFrame.new(side * 0.36, 0.08, -0.005) * CFrame.Angles(0, 0, side * -0.3), Enum.Material.Metal)
			piece(upper, outfit, "HeartRimLow", Vector3.new(0.05, 0.3, 0.05), C.Gold, heart * CFrame.new(side * 0.15, -0.22, -0.005) * CFrame.Angles(0, 0, side * 0.75), Enum.Material.Metal)
		end
		piece(upper, outfit, "HeartPoint", Vector3.new(0.3, 0.3, 0.04), C.Skin, heart * CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.pi / 4))
		-- The gold chain-zip down from the heart.
		local zipTop = top - 0.8
		local links = math.max(3, math.floor((s.Y - 0.72) / 0.12))
		for k = 0, links do
			piece(upper, outfit, "Zip", Vector3.new(0.07, 0.07, 0.04), k % 2 == 0 and C.Gold or C.GoldDark, CFrame.new(math.sin(k * 0.5) * 0.03, zipTop - k * 0.12, front - 0.06), Enum.Material.Metal)
		end
		-- Two ladybugs on the chest.
		for _, side in ipairs({ -1, 1 }) do
			ladybug(upper, outfit, CFrame.new(side * s.X * 0.33, top - 0.45, front - 0.07), 1)
			piece(upper, outfit, "ChestFold", Vector3.new(0.05, s.Y * 0.6, 0.04), C.SuitShade, CFrame.new(side * s.X * 0.18, -0.15, front - 0.05))
		end
		piece(upper, outfit, "JacketBack", Vector3.new(s.X + 0.1, s.Y, 0.06), C.SuitShade, CFrame.new(0, 0, -front + 0.05))
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.08, 0.02, 0.08), C.Suit, CFrame.new())
		-- The jacket flares out over his hips.
		for _, side in ipairs({ -1, 1 }) do
			piece(lower, outfit, "JacketTail", Vector3.new(ls.X * 0.52, 1.0, 0.08), C.Suit, CFrame.new(side * ls.X * 0.26, -0.3, -ls.Z / 2 - 0.08) * CFrame.Angles(math.rad(-6), 0, side * math.rad(8)))
			piece(lower, outfit, "JacketFlare", Vector3.new(0.1, 1.0, ls.Z + 0.24), C.SuitShade, CFrame.new(side * (ls.X / 2 + 0.12), -0.3, 0) * CFrame.Angles(0, 0, side * math.rad(10)))
		end
		piece(lower, outfit, "JacketTailBack", Vector3.new(ls.X + 0.3, 1.0, 0.08), C.SuitShade, CFrame.new(0, -0.3, ls.Z / 2 + 0.1) * CFrame.Angles(math.rad(6), 0, 0))
		for k = 0, 4 do
			piece(lower, outfit, "Zip", Vector3.new(0.07, 0.07, 0.04), k % 2 == 0 and C.Gold or C.GoldDark, CFrame.new(0, ls.Y / 2 - k * 0.14, -ls.Z / 2 - 0.13), Enum.Material.Metal)
		end
		-- The third ladybug, low on the jacket.
		ladybug(lower, outfit, CFrame.new(-ls.X * 0.26, -0.35, -ls.Z / 2 - 0.14), 1)
	end
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			piece(arm, outfit, "Sleeve", as + Vector3.new(0.1, 0.02, 0.1), C.Suit, CFrame.new())
			if name:find("Lower") or name == "Left Arm" or name == "Right Arm" then
				-- The gold cuff at the wrist.
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.16, 0.18, as.Z + 0.16), C.Gold, CFrame.new(0, -as.Y / 2 + 0.12, 0), Enum.Material.Metal)
				piece(arm, outfit, "CuffEdge", Vector3.new(as.X + 0.17, 0.04, as.Z + 0.17), C.GoldDark, CFrame.new(0, -as.Y / 2 + 0.22, 0), Enum.Material.Metal)
			end
		end
	end
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Trousers", leg.Size + Vector3.new(0.08, 0.02, 0.08), C.Suit, CFrame.new())
			piece(leg, outfit, "Crease", Vector3.new(0.04, leg.Size.Y, 0.04), C.SuitShade, CFrame.new(0.1, 0, -leg.Size.Z / 2 - 0.05))
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.06, 0.04, 0.16), C.Shoe, CFrame.new(0, 0, -0.05))
		end
	end
end

function GiornoOutfit.apply(character)
	if character:FindFirstChild("GiornoOutfit") then
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
	outfit.Name = "GiornoOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function GiornoOutfit.remove(character)
	local outfit = character:FindFirstChild("GiornoOutfit")
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
		if GiornoOutfit.Acts[character:GetAttribute("TuskAct")] then
			task.delay(0.3, function()
				if character.Parent and GiornoOutfit.Acts[character:GetAttribute("TuskAct")] then
					GiornoOutfit.apply(character)
				end
			end)
		else
			GiornoOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function GiornoOutfit.init()
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

return GiornoOutfit
end

-- ======================================================================
-- MODULE: GoldExperienceRequiem
-- ======================================================================
__modules["GoldExperienceRequiem"] = function()
--[[
	GoldExperienceRequiem  (ServerScriptService.SpinServer.TuskActs.GoldExperienceRequiem)

	GOLD EXPERIENCE REQUIEM: what the Requiem Arrow makes of Giorno's Gold
	Experience (Act 31, only from the arrow; back to Gold Experience, Act 30,
	when he goes down). Its power: RETURN TO ZERO. Whatever anyone tries to
	do to him never happens.
	  M1        REQUIEM MUDA COMBO: heavier, longer-reaching blows
	  Ability 1 MUDA RUSH: REQUIEM: a bigger storm of punches; the last
	            "MUDA!" blasts them away
	  Ability 2 RETURN TO ZERO: for a moment, any attack on him is undone:
	            it never lands, and the attacker is sent back to where they
	            started, hurt, and can't use abilities for a while
	  Ability 3 ZERO PUNCH: Gold Experience Requiem is suddenly in front of
	            them (a short dash) with an unblockable punch that cancels
	            what they were doing (they can't use abilities for a while)
	  Ultimate  INFINITE DEATH: the nearest enemy in range is trapped in a
	            death that never ends: held, they're thrown about and hurt
	            again and again ("they will never arrive at the truth"),
	            then one last blow
	Numbers: TuskConfig.GER. All damage goes through S.hit.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local GER = {}
local cfg = TuskConfig.GER
local ACT = 31

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

local function silence(target, time)
	local s = now() + time
	if (target:GetAttribute("SilencedUntil") or 0) < s then
		target:SetAttribute("SilencedUntil", s)
	end
end

-- Held in place (counted, so two holds at once don't free them early).
local pins = setmetatable({}, { __mode = "k" })
local function pin(root)
	local p = pins[root]
	if not p then
		p = { Count = 0, WasAnchored = root.Anchored }
		pins[root] = p
	end
	p.Count = p.Count + 1
	root.Anchored = true
end
local function unpin(root)
	local p = pins[root]
	if not p then
		return
	end
	p.Count = p.Count - 1
	if p.Count <= 0 then
		pins[root] = nil
		if root.Parent then
			root.Anchored = p.WasAnchored
		end
	end
end

function GER.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: MUDA RUSH: REQUIEM
---------------------------------------------------------------------------
local function rush(S, player, state)
	local c = cfg.Rush
	if not ready(S, player, state, "Rush", 1) then
		return
	end
	S.startCooldown(player, state, "Rush", c.Cooldown, 1)
	S.lock(state, c.Windup + c.Duration + 0.15)
	local character, humanoid = alive(S, player)
	local life = state.Life
	local untilT = now() + c.Windup + c.Duration
	character:SetAttribute("MudaRushUntil", untilT)
	S.Adapter.setMoveModifier(humanoid, "MudaRush", c.WalkMultiplier)
	S.fx("Ability", { Character = character, Act = ACT, Move = "Rush", Phase = "Start", Windup = c.Windup, Duration = c.Duration })
	local ticks = math.max(1, math.floor(c.Duration / c.Tick))
	local function stop()
		if humanoid.Parent then
			S.Adapter.setMoveModifier(humanoid, "MudaRush", nil)
		end
		if character.Parent and character:GetAttribute("MudaRushUntil") == untilT then
			character:SetAttribute("MudaRushUntil", nil)
		end
	end
	for i = 1, ticks do
		task.delay(c.Windup + (i - 1) * c.Tick, function()
			if character:GetAttribute("MudaRushUntil") ~= untilT then
				return
			end
			if not S.stillValid(player, state, life) then
				stop()
				S.fx("Ability", { Character = character, Act = ACT, Move = "Rush", Phase = "Stop" })
				return
			end
			local _, _, r = alive(S, player)
			local boxCF = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
			if i == ticks then
				Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.FinalDamage, Stun = c.FinalStun, Knockback = c.FinalKnockback, Launch = c.FinalLaunch, Direction = r.CFrame.LookVector, Source = "GERMuda" }, c.MaxTargets)
				local waveAt = (r.CFrame * CFrame.new(0, 0, -c.HitboxForward - 3)).Position
				Moves.aoe(S, player, waveAt, c.ShockwaveRadius, { Damage = c.ShockwaveDamage, Stun = 0.4, Knockback = 34, Direction = r.CFrame.LookVector, Source = "GERMuda" }, 6)
				S.fx("Ability", { Character = character, Act = ACT, Move = "Rush", Phase = "Finish", Position = boxCF.Position, Direction = r.CFrame.LookVector, Radius = c.ShockwaveRadius })
				stop()
			else
				local count, hitSet = Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = r.CFrame.LookVector, Source = "GERMuda" }, c.MaxTargets)
				for target in pairs(hitSet or {}) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr and not tr.Anchored then
						local to = boxCF.Position - tr.Position
						tr.AssemblyLinearVelocity = Vector3.new(to.X * c.Drag, tr.AssemblyLinearVelocity.Y, to.Z * c.Drag) + r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
					end
				end
				if count > 0 and i % 2 == 0 then
					S.fx("Ability", { Act = ACT, Move = "Rush", Phase = "Hit", Position = boxCF.Position })
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- 2: RETURN TO ZERO (counter)
---------------------------------------------------------------------------
local counters = setmetatable({}, { __mode = "k" }) -- [character] = function(attackerPlayer, info)

local function registerCounter(S)
	if S.Adapter.DodgeHandlers and not S.Adapter.DodgeHandlers.ReturnToZero then
		S.Adapter.DodgeHandlers.ReturnToZero = function(attackerPlayer, target, info)
			local counter = counters[target]
			if counter then
				counter(attackerPlayer, info)
			end
		end
	end
end

local function returnToZero(S, player, state)
	local c = cfg.Zero
	if not ready(S, player, state, "Zero", 2) then
		return
	end
	registerCounter(S)
	S.startCooldown(player, state, "Zero", c.Cooldown, 2)
	S.lock(state, c.Window + c.WhiffLag)
	local character, humanoid = alive(S, player)
	local life = state.Life
	local used = false
	S.Adapter.setMoveModifier(humanoid, "ReturnToZero", 0.01)
	character:SetAttribute("ReturnToZero", true)
	S.fx("Ability", { Character = character, Act = ACT, Move = "Zero", Phase = "Ready", Window = c.Window })
	local function finish()
		counters[character] = nil
		if character.Parent then
			character:SetAttribute("ReturnToZero", nil)
		end
		if humanoid.Parent then
			S.Adapter.setMoveModifier(humanoid, "ReturnToZero", nil)
		end
	end
	counters[character] = function(attackerPlayer)
		if used or state.Life ~= life then
			return
		end
		used = true
		finish()
		S.lock(state, 0.35)
		local attacker = attackerPlayer and attackerPlayer.Character
		local ar = attacker and attacker:FindFirstChild("HumanoidRootPart")
		local _, _, r = alive(S, player)
		if not ar or not r then
			return
		end
		-- Back to where they started: thrown back to "zero", away from him.
		local from = ar.Position
		local away = Vector3.new(ar.Position.X - r.Position.X, 0, ar.Position.Z - r.Position.Z)
		away = away.Magnitude > 0.1 and away.Unit or -r.CFrame.LookVector
		local to = Moves.safeStep(attacker, ar, away, c.SendBack) or ar.Position
		if not ar.Anchored then
			attacker:PivotTo(CFrame.lookAt(to, to - away))
			ar.AssemblyLinearVelocity = Vector3.new()
		end
		S.hit(player, attacker, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Position = to, Source = "GERZero", Unblockable = true })
		silence(attacker, c.SilenceTime)
		S.fx("Ability", { Character = character, Act = ACT, Move = "Zero", Phase = "Return", Target = attacker, From = from, To = to })
	end
	task.delay(c.Window, function()
		if used then
			return
		end
		finish()
		if state.Life == life then
			S.fx("Ability", { Character = character, Act = ACT, Move = "Zero", Phase = "Whiff" })
		end
	end)
end

---------------------------------------------------------------------------
-- 3: ZERO PUNCH
---------------------------------------------------------------------------
local function zeroPunch(S, player, state, aim)
	local c = cfg.ZeroPunch
	if not ready(S, player, state, "ZeroPunch", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local dir = Moves.flat(S.aim(aim, root))
	local target = Moves.findTarget(S, character, root, c.Range, c.Cone, dir)
	local tr = target and target:FindFirstChild("HumanoidRootPart")
	S.startCooldown(player, state, "ZeroPunch", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.25)
	local from = root.Position
	-- Suddenly right in front of them.
	if tr then
		local flatTo = Vector3.new(tr.Position.X - root.Position.X, 0, tr.Position.Z - root.Position.Z)
		local dist = math.max(0, flatTo.Magnitude - 3.5)
		if dist > 0.5 then
			dir = flatTo.Unit
			local to = Moves.safeStep(character, root, dir, dist)
			if to then
				character:PivotTo(CFrame.lookAt(to, to + dir))
			end
		else
			character:PivotTo(CFrame.lookAt(root.Position, root.Position + flatTo.Unit))
		end
	end
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "ZeroPunch", Phase = "Appear", From = from, To = root.Position, Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local boxCF = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
		local count, hitSet = Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = r.CFrame.LookVector, Source = "GERZero", Unblockable = true }, c.MaxTargets)
		local hits = {}
		for victim in pairs(hitSet or {}) do
			silence(victim, c.SilenceTime)
			table.insert(hits, victim)
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "ZeroPunch", Phase = "Punch", Position = boxCF.Position, Direction = r.CFrame.LookVector, Targets = hits, Hit = count > 0 })
	end)
end

function GER.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		rush(S, player, state)
	elseif slot == 2 then
		returnToZero(S, player, state)
	elseif slot == 3 then
		zeroPunch(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- INFINITE DEATH (ultimate)
---------------------------------------------------------------------------
function GER.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	local character, _, root = alive(S, player)
	local target = Moves.findTarget(S, character, root, u.Range, 360, Moves.flat(S.aim(aim, root)))
	if not target then
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local life = state.Life
	S.lock(state, u.Windup + 0.4)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Call", Target = target, Windup = u.Windup })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) or not aliveModel(target) then
			S.fx("Ultimate", { Character = character, Act = ACT, Phase = "End" })
			return
		end
		S.finishUltimate(player, state)
		local tr = target:FindFirstChild("HumanoidRootPart")
		if not tr then
			return
		end
		local home = tr.CFrame
		local untilT = now() + u.Duration
		target:SetAttribute("InfiniteDeathUntil", untilT)
		pin(tr)
		S.hit(player, target, { Damage = u.FirstDamage, Stun = u.Duration + 0.3, Knockback = 0, Position = tr.Position, Source = "GERDeath", Unblockable = true })
		S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Loop", Target = target, Time = u.Duration, Deaths = u.Deaths, Home = home.Position })
		local gap = u.Duration / (u.Deaths + 1)
		for k = 1, u.Deaths do
			task.delay(k * gap, function()
				if not aliveModel(target) or not tr.Parent then
					return
				end
				-- Another death: somewhere else, then back to zero.
				local a = math.random() * math.pi * 2
				local d = u.Scatter * (0.4 + math.random() * 0.6)
				local spot = Moves.groundBelow(home.Position + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), { target, character }) + Vector3.new(0, 3, 0)
				local before = tr.Position
				target:PivotTo(CFrame.new(spot) * (home - home.Position))
				S.hit(player, target, { Damage = u.DeathDamage, Stun = u.Duration, Knockback = 0, Position = spot, Source = "GERDeath", Unblockable = true })
				S.fx("Ultimate", { Act = ACT, Phase = "Death", Target = target, Index = k, From = before, To = spot })
			end)
		end
		task.delay(u.Duration, function()
			if tr.Parent then
				if target:GetAttribute("InfiniteDeathUntil") == untilT then
					target:PivotTo(home)
					target:SetAttribute("InfiniteDeathUntil", nil)
				end
				unpin(tr)
			end
			if aliveModel(target) and tr.Parent then
				local _, _, r = alive(S, player)
				local away = r and Vector3.new(tr.Position.X - r.Position.X, 0, tr.Position.Z - r.Position.Z) or Vector3.new(0, 0, 1)
				S.hit(player, target, { Damage = u.FinalDamage, Stun = u.FinalStun, Knockback = u.FinalKnockback, Launch = u.FinalLaunch, Direction = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1), Position = tr.Position, Source = "GERDeath", Unblockable = true })
			end
			S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Final", Target = target })
		end)
	end)
end

function GER.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("ReturnToZero", nil)
		character:SetAttribute("MudaRushUntil", nil)
		counters[character] = nil
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "ReturnToZero", nil)
			S.Adapter.setMoveModifier(humanoid, "MudaRush", nil)
		end
	end
end

function GER.Init(S)
	registerCounter(S)
end

return GER
end
end
