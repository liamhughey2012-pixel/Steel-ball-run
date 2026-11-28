--[[
	HotPants_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Hot Pants: Cream Starter.
	Its other half is HotPants_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "hotpants" or __expect.Side ~= "server") then
		error("this is the code for HotPants_Server, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to HotPants_Server and put it in ServerScriptService > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: HotPants
-- ======================================================================
__modules["HotPants"] = function()
--[[
	HotPants  (ServerScriptService.SpinServer.TuskActs.HotPants)

	Hot Pants: CREAM STARTER, a spray can that sprays flesh. It can seal
	wounds, coat things in flesh and smother people by sealing their mouth
	and nose. Registered as "Act" 10 so it reuses the Tusk ability system.
	  M1        SPRAY COMBO: jab, kick, a short spray burst, roundhouse
	  Ability 1 FLESH SPRAY: a cone of flesh for a moment; everyone in it is
	            coated (slowed) and takes ticks of damage
	  Ability 2 FLESH SEAL: flesh over the nearest enemy's mouth and nose:
	            they suffocate (damage over time) and are slowed
	  Ability 3 FLESH MEND: she sprays her own wounds shut (heals, clears
	            seals / coatings on herself)
	  Ultimate  FLESH STORM: a cloud of flesh in front hardens into cocoons
	            round everyone caught, crushes them, then bursts apart
	Numbers: TuskConfig.HotPants. All damage goes through S.hit (CombatAdapter).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local HotPants = {}
local cfg = TuskConfig.HotPants
local ACT = 10

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function HotPants.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

local function now()
	return workspace:GetServerTimeNow()
end

-- A slow that's always removed (stackable by key, refreshed by a token).
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
-- FLESH SPRAY
---------------------------------------------------------------------------
local function fleshSpray(S, player, state, aim)
	local c = cfg.FleshSpray
	if not ready(S, player, state, "FleshSpray", 1) then
		return
	end
	S.startCooldown(player, state, "FleshSpray", c.Cooldown, 1)
	S.lock(state, c.Startup + c.Duration + 0.15)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "FleshSpray", Phase = "Spray", Startup = c.Startup, Duration = c.Duration, Direction = direction, Range = c.Range, Cone = c.Cone })
	local ticks = math.floor(c.Duration / c.Tick)
	for i = 1, ticks do
		task.delay(c.Startup + (i - 1) * c.Tick, function()
			if not S.stillValid(player, state, life) then
				return
			end
			local char, _, r = alive(S, player)
			for _, target in ipairs(targetsInCone(S, char, r, direction, c.Range, c.Cone, c.MaxTargets)) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr and S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = direction, Position = tr.Position, Source = "HotPantsSpray" }) then
					target:SetAttribute("FleshCoatedUntil", now() + c.CoatTime)
					slow(S, target, "FleshCoat", c.CoatSlow, c.CoatTime)
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- FLESH SEAL
---------------------------------------------------------------------------
local function fleshSeal(S, player, state, aim)
	local c = cfg.FleshSeal
	if not ready(S, player, state, "FleshSeal", 2) then
		return
	end
	S.startCooldown(player, state, "FleshSeal", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.3)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "FleshSeal", Phase = "Startup", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local target = targetsInCone(S, char, r, direction, c.Range, c.Cone, 1)[1]
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		if not tr or not S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = direction, Position = tr.Position, Source = "HotPantsSeal" }) then
			S.startCooldown(player, state, "FleshSeal", c.MissCooldown, 2)
			S.fx("Ability", { Character = char, Act = ACT, Move = "FleshSeal", Phase = "Miss", Direction = direction, Range = c.Range })
			return
		end
		-- Mouth and nose sealed: they suffocate.
		local untilT = now() + c.SealTime
		target:SetAttribute("FleshSealedUntil", untilT)
		slow(S, target, "FleshSeal", c.SealSlow, c.SealTime)
		S.fx("Ability", { Character = char, Act = ACT, Move = "FleshSeal", Phase = "Seal", Target = target, Duration = c.SealTime })
		for i = 1, math.floor(c.SealTime / c.SealTick) do
			task.delay(i * c.SealTick, function()
				local t = target:FindFirstChild("HumanoidRootPart")
				-- (Flesh Mend or a new life clears it early.)
				if t and (target:GetAttribute("FleshSealedUntil") or 0) >= untilT - 0.01 then
					S.hit(player, target, { Damage = c.SealDamage, Stun = 0, Knockback = 0, Direction = direction, Position = t.Position, Source = "HotPantsSeal" })
				end
			end)
		end
	end)
end

---------------------------------------------------------------------------
-- FLESH MEND
---------------------------------------------------------------------------
local function fleshMend(S, player, state)
	local c = cfg.FleshMend
	if not ready(S, player, state, "FleshMend", 3) then
		return
	end
	S.startCooldown(player, state, "FleshMend", c.Cooldown, 3)
	S.lock(state, 0.35)
	local character, humanoid = alive(S, player)
	local life = state.Life
	-- Clears flesh tricks used on her.
	character:SetAttribute("FleshSealedUntil", nil)
	character:SetAttribute("FleshCoatedUntil", nil)
	character:SetAttribute("FleshMendUntil", now() + c.Duration)
	S.fx("Ability", { Character = character, Act = ACT, Move = "FleshMend", Phase = "Mend", Duration = c.Duration, Heal = c.Heal })
	for i = 1, c.Ticks do
		task.delay(i * c.Duration / c.Ticks, function()
			if state.Life ~= life or not humanoid.Parent or humanoid.Health <= 0 then
				return
			end
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + c.Heal / c.Ticks)
		end)
	end
	task.delay(c.Duration, function()
		if character.Parent then
			character:SetAttribute("FleshMendUntil", nil)
		end
	end)
end

function HotPants.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		fleshSpray(S, player, state, aim)
	elseif slot == 2 then
		fleshSeal(S, player, state, aim)
	elseif slot == 3 then
		fleshMend(S, player, state)
	end
end

---------------------------------------------------------------------------
-- FLESH STORM (ultimate)
---------------------------------------------------------------------------
function HotPants.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	local center = Moves.groundBelow(root.Position + direction * u.Distance, { character })
	S.lock(state, u.Windup + u.EncaseTime + 0.4)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Cloud", Windup = u.Windup, Position = center, Radius = u.Radius, Direction = direction })
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
			if tr and S.hit(player, target, { Damage = u.EncaseDamage, Stun = u.EncaseStun, Knockback = 0, Direction = tr.Position - center, Position = tr.Position, Source = "HotPantsStorm" }) then
				target:SetAttribute("FleshEncasedUntil", now() + u.EncaseTime)
				slow(S, target, "FleshEncase", 0.05, u.EncaseTime)
				table.insert(caught, target)
			end
		end
		S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Encase", Targets = caught, Duration = u.EncaseTime, Position = center, Radius = u.Radius })
		-- The cocoons crush...
		for i = 1, math.floor(u.EncaseTime / u.CrushEvery) do
			task.delay(i * u.CrushEvery, function()
				if state.Life ~= life then
					return
				end
				for _, target in ipairs(caught) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr then
						S.hit(player, target, { Damage = u.CrushDamage, Stun = 0.6, Knockback = 0, Direction = Vector3.new(0, -1, 0), Position = tr.Position, Source = "HotPantsStorm" })
					end
				end
			end)
		end
		-- ...then burst.
		task.delay(u.EncaseTime, function()
			for _, target in ipairs(caught) do
				target:SetAttribute("FleshEncasedUntil", nil)
			end
			if state.Life ~= life then
				return
			end
			Moves.aoe(S, player, up, u.Radius + 1, { Damage = u.BurstDamage, Stun = u.BurstStun, Knockback = u.BurstKnockback, Launch = u.BurstLaunch, Source = "HotPantsStorm" }, 8)
			S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Burst", Position = center, Radius = u.Radius + 1, Targets = caught })
		end)
	end)
end

function HotPants.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute("FleshMendUntil", nil)
	end
end

return HotPants
end

-- ======================================================================
-- MODULE: HotPantsOutfit
-- ======================================================================
__modules["HotPantsOutfit"] = function()
--[[
	HotPantsOutfit  (ServerScriptService.SpinServer.HotPantsOutfit)

	Gives a character Hot Pants' look while they play her (TuskAct 10),
	built from blocky parts (no catalog asset ids), matched to her art:
	  * a pink-purple bob with bangs
	  * a black cap with a gold front plate, gold visor, rivets and a gold
	    spike on top
	  * a thick cream scarf wrapped round her neck
	  * a pink tunic dress with a shoulder capelet, gold four-petal flower
	    clasps, gold leaf studs, a darker pink round panel on the front and a
	    black fur hem
	  * a gold chain belt with square links, a round "HP" buckle and a
	    holster on her hip
	  * cream ribbed sleeves and leggings
	  * tall pink flared boots with pointed cream toes
	  * (CREAM STARTER, her Stand, is drawn in her hand by the client)
	The player's own hats/hair are hidden while they play her and come back
	when she switches. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local HotPantsOutfit = {}
HotPantsOutfit.Act = 10

local C = {
	Hair = Color3.fromRGB(206, 112, 188),
	HairDark = Color3.fromRGB(160, 80, 150),
	Cap = Color3.fromRGB(28, 26, 30),
	Gold = Color3.fromRGB(226, 182, 64),
	GoldDark = Color3.fromRGB(170, 128, 40),
	Scarf = Color3.fromRGB(236, 228, 208),
	ScarfLine = Color3.fromRGB(196, 186, 164),
	Dress = Color3.fromRGB(226, 96, 150),
	DressDark = Color3.fromRGB(184, 64, 120),
	Fur = Color3.fromRGB(26, 24, 28),
	Rib = Color3.fromRGB(232, 224, 202),
	RibLine = Color3.fromRGB(196, 188, 166),
	Boot = Color3.fromRGB(232, 108, 160),
	BootDark = Color3.fromRGB(190, 78, 128),
	Toe = Color3.fromRGB(238, 232, 214),
	Holster = Color3.fromRGB(120, 82, 46),
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

-- A four-petal gold flower clasp facing forward (-Z of `cf`).
local function flower(parent, outfit, cf, size)
	for _, a in ipairs({ math.pi / 4, -math.pi / 4 }) do
		piece(parent, outfit, "Flower", Vector3.new(size, size * 0.38, 0.06), C.Gold, cf * CFrame.Angles(0, 0, a))
	end
	piece(parent, outfit, "Flower", Vector3.new(size * 0.3, size * 0.3, 0.08), C.GoldDark, cf * CFrame.new(0, 0, -0.02))
end

-- A cream ribbed tube over a limb from `top` down to `bottom` (local Y).
local function ribbed(part, outfit, top, bottom, grow)
	local h = top - bottom
	local sz = part.Size
	piece(part, outfit, "Rib", Vector3.new(sz.X + grow, h, sz.Z + grow), C.Rib, CFrame.new(0, (top + bottom) / 2, 0))
	local y = top - 0.18
	while y > bottom + 0.08 do
		piece(part, outfit, "RibLine", Vector3.new(sz.X + grow + 0.03, 0.05, sz.Z + grow + 0.03), C.RibLine, CFrame.new(0, y, 0))
		y = y - 0.24
	end
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Pink-purple bob: sides down to the jaw, the back, and bangs under the cap.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.2 * s, 0.95 * s, head.Size.Z + 0.1 * s), C.Hair, CFrame.new(side * (w + 0.08 * s), -0.05 * s, 0.04 * s))
		piece(head, outfit, "Hair", Vector3.new(0.22 * s, 0.14 * s, head.Size.Z * 0.6), C.HairDark, CFrame.new(side * (w + 0.1 * s), -0.48 * s, 0.1 * s))
	end
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.36 * s, 1.0 * s, 0.2 * s), C.Hair, CFrame.new(0, -0.02 * s, d + 0.08 * s))
	piece(head, outfit, "Bangs", Vector3.new(head.Size.X * 0.9, 0.14 * s, 0.12 * s), C.Hair, CFrame.new(-0.08 * s, h - 0.3 * s, -d - 0.04 * s) * CFrame.Angles(0, 0, 0.12))
	-- Black cap...
	piece(head, outfit, "Cap", Vector3.new(head.Size.X + 0.24 * s, 0.42 * s, head.Size.Z + 0.24 * s), C.Cap, CFrame.new(0, h - 0.06 * s, 0.02 * s))
	piece(head, outfit, "CapTop", Vector3.new(head.Size.X * 0.82, 0.18 * s, head.Size.Z * 0.82), C.Cap, CFrame.new(0, h + 0.22 * s, 0.04 * s))
	-- ...with a gold front plate, rivets, visor and a spike on top.
	piece(head, outfit, "Plate", Vector3.new(head.Size.X * 0.7, 0.3 * s, 0.1 * s), C.Gold, CFrame.new(0, h + 0.04 * s, -d - 0.13 * s) * CFrame.Angles(0.12, 0, 0))
	for i = -1, 1 do
		piece(head, outfit, "Rivet", Vector3.new(0.08 * s, 0.08 * s, 0.06 * s), C.GoldDark, CFrame.new(i * 0.3 * s, h + 0.08 * s, -d - 0.2 * s))
	end
	piece(head, outfit, "Visor", Vector3.new(head.Size.X * 0.95, 0.08 * s, 0.5 * s), C.Gold, CFrame.new(0, h - 0.24 * s, -d - 0.36 * s) * CFrame.Angles(-0.2, 0, 0))
	piece(head, outfit, "Spike", Vector3.new(0.14 * s, 0.3 * s, 0.14 * s), C.Gold, CFrame.new(0, h + 0.44 * s, 0.04 * s))
	piece(head, outfit, "Spike", Vector3.new(0.1 * s, 0.1 * s, 0.22 * s), C.Gold, CFrame.new(0, h + 0.6 * s, 0.1 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		-- Tunic.
		piece(upper, outfit, "Dress", s + Vector3.new(0.1, 0.02, 0.1), C.Dress, CFrame.new())
		-- Capelet over the shoulders (drapes a little lower at the front).
		piece(upper, outfit, "Capelet", Vector3.new(s.X + 0.5, 0.42, s.Z + 0.4), C.Dress, CFrame.new(0, top - 0.18, 0))
		piece(upper, outfit, "Capelet", Vector3.new(s.X + 0.36, 0.3, 0.12), C.DressDark, CFrame.new(0, top - 0.48, front - 0.16))
		-- Thick cream scarf wrapped round the neck.
		piece(upper, outfit, "Scarf", Vector3.new(s.X * 0.62, 0.24, s.Z + 0.24), C.Scarf, CFrame.new(0, top + 0.06, 0))
		piece(upper, outfit, "Scarf", Vector3.new(s.X * 0.52, 0.14, s.Z + 0.14), C.Scarf, CFrame.new(0, top + 0.22, 0))
		piece(upper, outfit, "ScarfLine", Vector3.new(s.X * 0.61, 0.04, s.Z + 0.23), C.ScarfLine, CFrame.new(0, top + 0.1, 0))
		piece(upper, outfit, "ScarfLine", Vector3.new(s.X * 0.51, 0.04, s.Z + 0.13), C.ScarfLine, CFrame.new(0, top + 0.24, 0))
		-- Gold four-petal flowers on each shoulder.
		for _, side in ipairs({ -1, 1 }) do
			flower(upper, outfit, CFrame.new(side * s.X * 0.33, top - 0.22, front - 0.3), 0.42)
		end
		-- Darker pink round panel on the front (blocky octagon).
		piece(upper, outfit, "Panel", Vector3.new(0.8, 0.55, 0.06), C.DressDark, CFrame.new(0, -s.Y * 0.18, front - 0.07))
		piece(upper, outfit, "Panel", Vector3.new(0.55, 0.8, 0.06), C.DressDark, CFrame.new(0, -s.Y * 0.18, front - 0.07))
		-- Gold leaf studs scattered on the dress.
		for _, spot in ipairs({ { -0.68, -0.05, 0.5 }, { 0.68, -0.05, -0.5 }, { -0.62, -0.5, -0.4 }, { 0.62, -0.5, 0.4 } }) do
			piece(upper, outfit, "Leaf", Vector3.new(0.2, 0.13, 0.06), C.Gold, CFrame.new(spot[1], spot[2] * s.Y / 1.6, front - 0.07) * CFrame.Angles(0, 0, spot[3]))
		end
	end
	-- Skirt with a black fur hem, gold chain belt, round HP buckle, holster.
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.3
		local skirtH = lower and 0.75 or 0.6
		local skirtY = waistTop - skirtH / 2
		piece(waist, outfit, "Skirt", Vector3.new(ws.X + 0.22, skirtH, ws.Z + 0.22), C.Dress, CFrame.new(0, skirtY, 0))
		piece(waist, outfit, "Fur", Vector3.new(ws.X + 0.4, 0.26, ws.Z + 0.4), C.Fur, CFrame.new(0, waistTop - skirtH - 0.04, 0)).Material = Enum.Material.Fabric
		local beltY = waistTop - 0.12
		piece(waist, outfit, "Belt", Vector3.new(ws.X + 0.28, 0.14, ws.Z + 0.28), C.GoldDark, CFrame.new(0, beltY, 0))
		for i = -2, 2 do
			if i ~= 0 then
				piece(waist, outfit, "Link", Vector3.new(0.26, 0.2, 0.05), C.Gold, CFrame.new(i * 0.4, beltY, -ws.Z / 2 - 0.16))
				piece(waist, outfit, "Link", Vector3.new(0.14, 0.09, 0.06), C.Dress, CFrame.new(i * 0.4, beltY, -ws.Z / 2 - 0.17))
			end
		end
		piece(waist, outfit, "Buckle", Vector3.new(0.4, 0.34, 0.06), C.Gold, CFrame.new(0, beltY, -ws.Z / 2 - 0.17))
		piece(waist, outfit, "Buckle", Vector3.new(0.3, 0.42, 0.06), C.Gold, CFrame.new(0, beltY, -ws.Z / 2 - 0.17))
		piece(waist, outfit, "BuckleHP", Vector3.new(0.18, 0.18, 0.07), C.GoldDark, CFrame.new(0, beltY, -ws.Z / 2 - 0.18))
		-- Holster hanging off her right hip.
		piece(waist, outfit, "Holster", Vector3.new(0.22, 0.7, 0.36), C.Holster, CFrame.new(ws.X / 2 + 0.2, beltY - 0.4, -0.1) * CFrame.Angles(0, 0, 0.1))
	end
	-- Cream ribbed sleeves.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local tall = arm.Size.Y > 1.8
			local bottom = tall and -arm.Size.Y / 2 + 0.35 or -arm.Size.Y / 2
			ribbed(arm, outfit, arm.Size.Y / 2, bottom, 0.06)
			if name:find("Upper") or tall then
				-- The capelet covers the top of the shoulder.
				piece(arm, outfit, "Shoulder", Vector3.new(arm.Size.X + 0.16, 0.36, arm.Size.Z + 0.16), C.Dress, CFrame.new(0, arm.Size.Y / 2 - 0.12, 0))
			end
		end
	end
	-- Cream ribbed leggings, then tall pink boots that flare at the top.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			ribbed(leg, outfit, leg.Size.Y / 2, -leg.Size.Y / 2, 0.04)
		end
	end
	for _, name in ipairs({ "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local tall = leg.Size.Y > 1.8
			if not tall then
				ribbed(leg, outfit, leg.Size.Y / 2, -leg.Size.Y / 2, 0.04)
			end
			local h = tall and 1.1 or leg.Size.Y + 0.1
			local bootTop = -leg.Size.Y / 2 + h
			piece(leg, outfit, "Boot", Vector3.new(leg.Size.X + 0.14, h, leg.Size.Z + 0.16), C.Boot, CFrame.new(0, bootTop - h / 2, 0))
			-- Flared cuff with a darker fold.
			piece(leg, outfit, "BootCuff", Vector3.new(leg.Size.X + 0.42, 0.34, leg.Size.Z + 0.42), C.Boot, CFrame.new(0, bootTop - 0.05, 0))
			piece(leg, outfit, "BootFold", Vector3.new(0.08, h * 0.6, 0.06), C.BootDark, CFrame.new(leg.Size.X * 0.25, bootTop - h * 0.4, -leg.Size.Z / 2 - 0.1))
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Boot", foot.Size + Vector3.new(0.12, 0.06, 0.1), C.Boot, CFrame.new())
			piece(foot, outfit, "Toe", Vector3.new(foot.Size.X * 0.7, foot.Size.Y * 0.8, 0.4), C.Toe, CFrame.new(0, -foot.Size.Y * 0.1, -foot.Size.Z / 2 - 0.15))
		end
	end
end

function HotPantsOutfit.apply(character)
	if character:FindFirstChild("HotPantsOutfit") then
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
	outfit.Name = "HotPantsOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function HotPantsOutfit.remove(character)
	local outfit = character:FindFirstChild("HotPantsOutfit")
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
		if character:GetAttribute("TuskAct") == HotPantsOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == HotPantsOutfit.Act then
					HotPantsOutfit.apply(character)
				end
			end)
		else
			HotPantsOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function HotPantsOutfit.init()
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

return HotPantsOutfit
end
end
