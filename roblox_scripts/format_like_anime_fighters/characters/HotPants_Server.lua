--[[
	HotPants_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Hot Pants: Cream Starter.
	Its other half is HotPants_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

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
	built from blocky parts (no catalog asset ids):
	  * a low pink cap with a short visor, short hair at the sides
	  * a fitted purple top with a gold cross pendant
	  * her namesake short shorts with a belt, knee-high boots
	  * CREAM STARTER, her Stand: a pink spray can holstered at her hip
	The player's own hats/hair are hidden while they play her and come back
	when she switches. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local HotPantsOutfit = {}
HotPantsOutfit.Act = 10

local C = {
	Cap = Color3.fromRGB(232, 120, 160),
	CapDark = Color3.fromRGB(180, 80, 120),
	Hair = Color3.fromRGB(70, 48, 40),
	Top = Color3.fromRGB(96, 60, 120),
	TopTrim = Color3.fromRGB(70, 40, 92),
	Cross = Color3.fromRGB(236, 196, 80),
	Shorts = Color3.fromRGB(236, 120, 70),
	Belt = Color3.fromRGB(60, 40, 30),
	Boot = Color3.fromRGB(60, 44, 52),
	Can = Color3.fromRGB(242, 140, 172),
	CanCap = Color3.fromRGB(245, 245, 245),
	Label = Color3.fromRGB(255, 225, 120),
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
	local h, d = head.Size.Y / 2, head.Size.Z / 2
	-- Low cap pulled over the brow, with a short visor.
	piece(head, outfit, "Cap", Vector3.new(head.Size.X + 0.14 * s, 0.55 * s, head.Size.Z + 0.14 * s), C.Cap, CFrame.new(0, h - 0.15 * s, 0.02 * s))
	piece(head, outfit, "CapTop", Vector3.new(head.Size.X * 0.8, 0.14 * s, head.Size.Z * 0.8), C.CapDark, CFrame.new(0, h + 0.18 * s, 0.02 * s))
	piece(head, outfit, "Visor", Vector3.new(head.Size.X * 0.9, 0.1 * s, 0.5 * s), C.CapDark, CFrame.new(0, h - 0.32 * s, -d - 0.2 * s) * CFrame.Angles(-0.12, 0, 0))
	-- Short hair at the sides and back.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.16 * s, 0.6 * s, head.Size.Z * 0.75), C.Hair, CFrame.new(side * (head.Size.X / 2 + 0.06 * s), -0.05 * s, 0.05 * s))
	end
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.1 * s, 0.55 * s, 0.16 * s), C.Hair, CFrame.new(0, -0.05 * s, d + 0.06 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		piece(upper, outfit, "Top", s + Vector3.new(0.08, 0.02, 0.08), C.Top, CFrame.new())
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.6, 0.22, s.Z + 0.14), C.TopTrim, CFrame.new(0, s.Y / 2 + 0.02, 0))
		-- Gold cross pendant.
		piece(upper, outfit, "Cross", Vector3.new(0.12, 0.5, 0.06), C.Cross, CFrame.new(0, s.Y * 0.1, -s.Z / 2 - 0.08))
		piece(upper, outfit, "Cross", Vector3.new(0.34, 0.12, 0.06), C.Cross, CFrame.new(0, s.Y * 0.18, -s.Z / 2 - 0.08))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Chain", Vector3.new(0.05, s.Y * 0.4, 0.05), C.Cross, CFrame.new(side * 0.22, s.Y * 0.3, -s.Z / 2 - 0.06) * CFrame.Angles(0, 0, side * 0.5))
		end
	end
	local waist = lower or upper
	if waist then
		local y = lower and 0 or -upper.Size.Y / 2 + 0.15
		piece(waist, outfit, "Shorts", Vector3.new(waist.Size.X + 0.1, lower and waist.Size.Y + 0.04 or 0.5, waist.Size.Z + 0.1), C.Shorts, CFrame.new(0, lower and 0 or y - 0.1, 0))
		piece(waist, outfit, "Belt", Vector3.new(waist.Size.X + 0.14, 0.18, waist.Size.Z + 0.14), C.Belt, CFrame.new(0, lower and waist.Size.Y / 2 - 0.05 or y + 0.12, 0))
		-- CREAM STARTER holstered at the right hip: a pink spray can with a white cap.
		local hip = CFrame.new(waist.Size.X / 2 + 0.28, y - 0.25, 0)
		piece(waist, outfit, "SprayCan", Vector3.new(0.42, 0.85, 0.42), C.Can, hip)
		piece(waist, outfit, "SprayCanBand", Vector3.new(0.44, 0.22, 0.44), C.Label, hip * CFrame.new(0, 0.05, 0))
		piece(waist, outfit, "SprayCanCap", Vector3.new(0.3, 0.22, 0.3), C.CanCap, hip * CFrame.new(0, 0.52, 0))
		piece(waist, outfit, "SprayNozzle", Vector3.new(0.12, 0.1, 0.16), C.Belt, hip * CFrame.new(0, 0.68, -0.08))
	end
	-- Bare legs under the shorts and boots, long purple sleeves.
	local headPart = character:FindFirstChild("Head")
	local skin = headPart and headPart.Color or Color3.fromRGB(238, 196, 164)
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Skin", leg.Size + Vector3.new(0.04, 0.02, 0.04), skin, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local tall = arm.Size.Y > 1.8
			local h = tall and arm.Size.Y - 0.35 or arm.Size.Y
			piece(arm, outfit, "Sleeve", Vector3.new(arm.Size.X + 0.06, h + 0.02, arm.Size.Z + 0.06), C.Top, CFrame.new(0, arm.Size.Y / 2 - h / 2, 0))
		end
	end
	-- Short shorts: only the very top of the legs is covered.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local tall = leg.Size.Y > 1.8
			local h = tall and 0.5 or leg.Size.Y * 0.45
			piece(leg, outfit, "ShortsLeg", Vector3.new(leg.Size.X + 0.14, h, leg.Size.Z + 0.14), C.Shorts, CFrame.new(0, leg.Size.Y / 2 - h / 2, 0))
		end
	end
	-- Knee-high boots.
	for _, name in ipairs({ "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local tall = leg.Size.Y > 1.8
			local h = tall and 1.0 or leg.Size.Y * 0.85
			piece(leg, outfit, "Boot", Vector3.new(leg.Size.X + 0.16, h, leg.Size.Z + 0.18), C.Boot, CFrame.new(0, -leg.Size.Y / 2 + h / 2, 0))
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Boot", foot.Size + Vector3.new(0.1, 0.06, 0.12), C.Boot, CFrame.new())
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
