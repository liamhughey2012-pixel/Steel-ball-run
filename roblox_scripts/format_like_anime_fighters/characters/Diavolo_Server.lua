--[[
	Diavolo_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Diavolo (Part 5): King Crimson.
	Its other half is Diavolo_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "diavolo" or __expect.Side ~= "server") then
		error("this is the code for Diavolo_Server, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Diavolo_Server and put it in ServerScriptService > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: Diavolo
-- ======================================================================
__modules["Diavolo"] = function()
--[[
	Diavolo  (ServerScriptService.SpinServer.TuskActs.Diavolo)

	Diavolo (Part 5, Golden Wind): KING CRIMSON. Registered as "Act" 32.
	King Crimson ERASES TIME: the seconds go by, but nobody lives through
	them, and only the result remains. Its forehead face, EPITAPH, shows
	him the future.
	  M1        KING CRIMSON COMBO: heavy chops and punches; the 4th is a
	            hammering blow that launches
	  Ability 1 EPITAPH: for a moment he sees the next attack coming: if
	            anyone hits him, it never lands; he's already behind them,
	            and King Crimson chops them down
	  Ability 2 TIME ERASE ("KING CRIMSON!"): time is erased for a few
	            seconds. Nothing can touch him and he moves faster, but he
	            can't hit anything either (nobody's really there). When time
	            comes back, ONLY THE RESULT REMAINS: for a moment his hits
	            land harder and can't be blocked
	  Ability 3 HEART PUNCH: King Crimson drives its fist straight through
	            the nearest enemy in front: a huge hit, and they bleed
	  Ultimate  ONLY THE RESULT REMAINS: time is erased round him; he's
	            behind each enemy near him in turn, King Crimson chopping
	            each one, and when time comes back every blow lands at once
	Numbers: TuskConfig.Diavolo. All damage goes through S.hit.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Diavolo = {}
local cfg = TuskConfig.Diavolo
local ACT = 32

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function now()
	return workspace:GetServerTimeNow()
end

local function aliveModel(model)
	local h = model and model.Parent and model:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end

-- While time is erased he can't affect anything.
local function erasing(char)
	return (char and (char:GetAttribute("TimeEraseUntil") or 0) > now()) or false
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

-- Behind someone, facing their back.
local function behind(target, dist)
	local tr = target:FindFirstChild("HumanoidRootPart")
	if not tr then
		return nil
	end
	local back = -tr.CFrame.LookVector
	back = Vector3.new(back.X, 0, back.Z)
	back = back.Magnitude > 0.1 and back.Unit or Vector3.new(0, 0, 1)
	local at = tr.Position + back * (dist or 3.5)
	return CFrame.lookAt(at, Vector3.new(tr.Position.X, at.Y, tr.Position.Z))
end

function Diavolo.M1(S, player, state, aim)
	local char = alive(S, player)
	if erasing(char) then
		return
	end
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: EPITAPH (sees the next attack: it never lands, and he counters)
---------------------------------------------------------------------------
local counters = setmetatable({}, { __mode = "k" }) -- [character] = function(attackerPlayer)

local function registerCounter(S)
	if S.Adapter.DodgeHandlers and not S.Adapter.DodgeHandlers.Epitaph then
		S.Adapter.DodgeHandlers.Epitaph = function(attackerPlayer, target)
			local counter = counters[target]
			if counter then
				counter(attackerPlayer)
			end
		end
	end
end

local function epitaph(S, player, state)
	local c = cfg.Epitaph
	if not ready(S, player, state, "Epitaph", 1) then
		return
	end
	registerCounter(S)
	S.startCooldown(player, state, "Epitaph", c.Cooldown, 1)
	local character = alive(S, player)
	local life = state.Life
	local used = false
	character:SetAttribute("Epitaph", true)
	character:SetAttribute("EpitaphUntil", now() + c.Window)
	S.fx("Ability", { Character = character, Act = ACT, Move = "Epitaph", Phase = "See", Window = c.Window })
	local function finish()
		counters[character] = nil
		if character.Parent then
			character:SetAttribute("Epitaph", nil)
			character:SetAttribute("EpitaphUntil", nil)
		end
	end
	counters[character] = function(attackerPlayer)
		if used or state.Life ~= life then
			return
		end
		used = true
		finish()
		local attacker = attackerPlayer and attackerPlayer.Character
		local spot = attacker and behind(attacker, 3.2)
		local _, _, r = alive(S, player)
		if not spot or not r then
			return
		end
		local from = r.Position
		character:PivotTo(spot)
		r.AssemblyLinearVelocity = Vector3.new()
		S.lock(state, 0.3)
		local ar = attacker:FindFirstChild("HumanoidRootPart")
		S.hit(player, attacker, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = ar and ar.CFrame.LookVector or nil, Position = ar and ar.Position or spot.Position, Source = "DiavoloEpitaph", Unblockable = true })
		S.fx("Ability", { Character = character, Act = ACT, Move = "Epitaph", Phase = "Counter", Target = attacker, From = from, To = spot.Position })
	end
	task.delay(c.Window, function()
		if not used then
			finish()
			if state.Life == life then
				S.fx("Ability", { Character = character, Act = ACT, Move = "Epitaph", Phase = "Fade" })
			end
		end
	end)
end

---------------------------------------------------------------------------
-- 2: TIME ERASE ("KING CRIMSON!")
---------------------------------------------------------------------------
local function eraseTime(S, player, state, length, fxExtra)
	local c = cfg.Erase
	local character, humanoid = alive(S, player)
	local iframes = S.Adapter.Settings.IFrameAttribute
	local untilT = now() + length
	character:SetAttribute("TimeEraseUntil", untilT)
	character:SetAttribute(iframes, true)
	S.Adapter.setMoveModifier(humanoid, "TimeErase", c.SpeedMultiplier)
	local data = { Character = character, Act = ACT, Move = "Erase", Phase = "Erase", Time = length, Radius = c.SeenRadius }
	for k, v in pairs(fxExtra or {}) do
		data[k] = v
	end
	S.fx("Ability", data)
	task.delay(length, function()
		if humanoid.Parent then
			S.Adapter.setMoveModifier(humanoid, "TimeErase", nil)
		end
		if not character.Parent or character:GetAttribute("TimeEraseUntil") ~= untilT then
			return
		end
		character:SetAttribute("TimeEraseUntil", nil)
		character:SetAttribute(iframes, nil)
		-- Only the result remains.
		character:SetAttribute("KCResultUntil", now() + c.ResultTime)
		character:SetAttribute("KCResultDamage", c.ResultDamage)
		S.fx("Ability", { Character = character, Act = ACT, Move = "Erase", Phase = "Resume", Time = c.ResultTime })
	end)
	return untilT
end

local function timeErase(S, player, state)
	local c = cfg.Erase
	if not ready(S, player, state, "Erase", 2) then
		return
	end
	S.startCooldown(player, state, "Erase", c.Cooldown, 2)
	S.lock(state, 0.25)
	eraseTime(S, player, state, c.Time)
end

---------------------------------------------------------------------------
-- 3: HEART PUNCH (straight through them)
---------------------------------------------------------------------------
local function heartPunch(S, player, state, aim)
	local c = cfg.HeartPunch
	if not ready(S, player, state, "HeartPunch", 3) then
		return
	end
	local character, _, root = alive(S, player)
	if erasing(character) then
		return
	end
	local target = Moves.findTarget(S, character, root, c.Range, c.Cone, Moves.flat(S.aim(aim, root)))
	S.startCooldown(player, state, "HeartPunch", target and c.Cooldown or c.MissCooldown, 3)
	S.lock(state, c.Windup + 0.3)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "HeartPunch", Phase = "Wind", Windup = c.Windup, Target = target })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		if not target or not aliveModel(target) then
			S.fx("Ability", { Character = char, Act = ACT, Move = "HeartPunch", Phase = "Miss", Position = (r.CFrame * CFrame.new(0, 0, -4)).Position })
			return
		end
		local tr = target:FindFirstChild("HumanoidRootPart")
		if not tr or (tr.Position - r.Position).Magnitude > c.Range + 3 then
			S.fx("Ability", { Character = char, Act = ACT, Move = "HeartPunch", Phase = "Miss", Position = (r.CFrame * CFrame.new(0, 0, -4)).Position })
			return
		end
		local dir = Moves.flat(tr.Position - r.Position)
		local landed = S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = dir, Position = tr.Position, Source = "DiavoloHeart" })
		S.fx("Ability", { Character = char, Act = ACT, Move = "HeartPunch", Phase = "Through", Target = target, Hit = landed, Direction = dir })
		if landed then
			for k = 1, c.BleedTicks do
				task.delay(k * c.BleedEvery, function()
					local t2 = target.Parent and target:FindFirstChild("HumanoidRootPart")
					if t2 and aliveModel(target) then
						S.hit(player, target, { Damage = c.BleedDamage, Stun = 0.1, Knockback = 0, Direction = dir, Position = t2.Position, Source = "DiavoloBleed", Unblockable = true })
						S.fx("Ability", { Act = ACT, Move = "HeartPunch", Phase = "Bleed", Target = target })
					end
				end)
			end
		end
	end)
end

function Diavolo.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		epitaph(S, player, state)
	elseif slot == 2 then
		timeErase(S, player, state)
	elseif slot == 3 then
		heartPunch(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- ONLY THE RESULT REMAINS (ultimate)
---------------------------------------------------------------------------
function Diavolo.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	local character, _, root = alive(S, player)
	-- Nearest first, up to MaxTargets.
	local list = {}
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, u.Radius, 20)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and aliveModel(target) then
			table.insert(list, { Target = target, D = (tr.Position - root.Position).Magnitude })
		end
	end
	table.sort(list, function(a, b)
		return a.D < b.D
	end)
	if #list == 0 then
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local targets = {}
	for k = 1, math.min(u.MaxTargets, #list) do
		targets[k] = list[k].Target
	end
	local life = state.Life
	local total = u.Windup + #targets * u.Gap + 0.3
	S.lock(state, total + 0.3)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Call", Windup = u.Windup, Targets = targets })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local eraseFor = #targets * u.Gap + 0.3
		eraseTime(S, player, state, eraseFor, { Ultimate = true, Targets = targets })
		-- He's behind each of them in turn; King Crimson chops.
		for k, target in ipairs(targets) do
			task.delay((k - 1) * u.Gap, function()
				if state.Life ~= life or not aliveModel(target) then
					return
				end
				local spot = behind(target, 3.2)
				if spot then
					character:PivotTo(spot)
					S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Chop", Target = target, Index = k, Position = spot.Position })
				end
			end)
		end
		-- Time comes back: every blow lands at once.
		task.delay(eraseFor, function()
			if state.Life ~= life then
				return
			end
			local hits = {}
			for _, target in ipairs(targets) do
				local tr = target.Parent and target:FindFirstChild("HumanoidRootPart")
				if tr and aliveModel(target) then
					if S.hit(player, target, { Damage = u.Damage, Stun = u.Stun, Knockback = u.Knockback, Launch = u.Launch, Direction = tr.CFrame.LookVector, Position = tr.Position, Source = "DiavoloResult", Unblockable = true }) then
						table.insert(hits, target)
					end
				end
			end
			S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Result", Targets = hits })
		end)
	end)
end

function Diavolo.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("Epitaph", nil)
		character:SetAttribute("EpitaphUntil", nil)
		character:SetAttribute("TimeEraseUntil", nil)
		character:SetAttribute("KCResultUntil", nil)
		character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
		counters[character] = nil
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "TimeErase", nil)
		end
	end
end

function Diavolo.Init(S)
	registerCounter(S)
end

return Diavolo
end

-- ======================================================================
-- MODULE: DiavoloOutfit
-- ======================================================================
__modules["DiavoloOutfit"] = function()
--[[
	DiavoloOutfit  (ServerScriptService.SpinServer.DiavoloOutfit)

	Gives a character the look of Diavolo (Part 5) while they play him
	(TuskAct 32), built from blocky parts (no catalog asset ids), matched to
	his art:
	  * long PINK hair with dark spots, parted in the middle, falling past
	    his shoulders in front and down his back
	  * bare skin under a black WEB-MESH top: rings round the chest, arcs
	    across the ribs and stomach, a line down the middle; dark swirling
	    tattoos on his upper arms
	  * green wristbands, a green belt with a gold buckle
	  * purple trousers with a row of gold buttons down each outer seam and
	    split hems; purple boots
	  * the black strap with white rungs hanging from his left hip
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local DiavoloOutfit = {}
DiavoloOutfit.Act = 32

local C = {
	Hair = Color3.fromRGB(240, 132, 172),
	HairShade = Color3.fromRGB(206, 100, 146),
	Spot = Color3.fromRGB(44, 62, 46),
	Skin = Color3.fromRGB(232, 196, 166),
	Mesh = Color3.fromRGB(26, 22, 30),
	Band = Color3.fromRGB(60, 172, 140),
	Belt = Color3.fromRGB(70, 160, 110),
	Gold = Color3.fromRGB(230, 186, 70),
	Pants = Color3.fromRGB(132, 92, 192),
	PantsShade = Color3.fromRGB(100, 66, 156),
	Boot = Color3.fromRGB(96, 66, 156),
	Rung = Color3.fromRGB(236, 236, 240),
	Eye = Color3.fromRGB(110, 170, 120),
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

local function ball(parent, outfit, name, d, color, offset)
	local p = piece(parent, outfit, name, Vector3.new(d, d, d), color, offset)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A thin dark mesh strand from a to b, lying on a face of `parent`.
local function strand(parent, outfit, a, b, z)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local angle = math.atan2(b.Y - a.Y, b.X - a.X)
	piece(parent, outfit, "Mesh", Vector3.new(len + 0.03, 0.04, 0.02), C.Mesh, CFrame.new(mid.X, mid.Y, z) * CFrame.Angles(0, 0, angle))
end

-- A ring of strands (an octagon) centred at (x, y) on a face.
local function meshRing(parent, outfit, x, y, r, z)
	local n = 8
	for k = 0, n - 1 do
		local a0, a1 = k / n * math.pi * 2, (k + 1) / n * math.pi * 2
		strand(parent, outfit, Vector3.new(x + math.cos(a0) * r, y + math.sin(a0) * r * 0.85, 0), Vector3.new(x + math.cos(a1) * r, y + math.sin(a1) * r * 0.85, 0), z)
	end
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Pink hair parted in the middle, smooth over the top.
	piece(head, outfit, "HairCap", Vector3.new(head.Size.X + 0.1 * s, 0.28 * s, head.Size.Z + 0.12 * s), C.Hair, CFrame.new(0, h + 0.08 * s, 0.03 * s))
	piece(head, outfit, "Parting", Vector3.new(0.04 * s, 0.05 * s, head.Size.Z * 0.8), C.HairShade, CFrame.new(0, h + 0.23 * s, -0.05 * s))
	for _, side in ipairs({ -1, 1 }) do
		-- Curtains of hair down each side of his face, onto his chest.
		piece(head, outfit, "HairSide", Vector3.new(0.16 * s, 1.0 * s, head.Size.Z * 0.9), C.Hair, CFrame.new(side * (w + 0.06 * s), -0.15 * s, 0.05 * s))
		piece(head, outfit, "FrontLock", Vector3.new(0.3 * s, 1.5 * s, 0.14 * s), side < 0 and C.Hair or C.HairShade, CFrame.new(side * (w - 0.02 * s), -1.0 * s, -d + 0.02 * s) * CFrame.Angles(math.rad(-8), 0, side * 0.08))
		piece(head, outfit, "Bang", Vector3.new(0.34 * s, 0.32 * s, 0.1 * s), C.Hair, CFrame.new(side * 0.26 * s, h - 0.1 * s, -d - 0.03 * s) * CFrame.Angles(0, 0, side * 0.35))
		-- Sharp brows, green eyes.
		piece(head, outfit, "Brow", Vector3.new(0.26 * s, 0.05 * s, 0.03 * s), C.Mesh, CFrame.new(side * 0.21 * s, 0.17 * s, -d - 0.01 * s) * CFrame.Angles(0, 0, side * -0.25))
		piece(head, outfit, "Eye", Vector3.new(0.18 * s, 0.07 * s, 0.03 * s), C.Eye, CFrame.new(side * 0.21 * s, 0.07 * s, -d - 0.01 * s))
	end
	-- The long mass down his back.
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.3 * s, 2.6 * s, 0.22 * s), C.Hair, CFrame.new(0, -0.8 * s, d + 0.1 * s))
	piece(head, outfit, "HairBackShade", Vector3.new(head.Size.X * 0.5, 2.4 * s, 0.24 * s), C.HairShade, CFrame.new(0.15 * s, -0.9 * s, d + 0.11 * s))
	-- Dark spots all through it.
	for _, sp in ipairs({ { -0.4, 0.3 }, { 0.3, -0.2 }, { -0.1, -0.9 }, { 0.35, -1.4 }, { -0.35, -1.8 } }) do
		ball(head, outfit, "HairSpot", 0.13 * s, C.Spot, CFrame.new(sp[1] * s, sp[2] * s, d + 0.22 * s))
	end
	for _, sp in ipairs({ { 0.2, 0.2 }, { -0.25, -0.1 } }) do
		ball(head, outfit, "HairSpot", 0.12 * s, C.Spot, CFrame.new(sp[1] * s, h + 0.2 * s, sp[2] * s))
	end
	for _, side in ipairs({ -1, 1 }) do
		ball(head, outfit, "HairSpot", 0.11 * s, C.Spot, CFrame.new(side * (w + 0.13 * s), -0.4 * s, 0.1 * s))
		ball(head, outfit, "HairSpot", 0.1 * s, C.Spot, CFrame.new(side * (w - 0.02 * s), -1.2 * s, -d - 0.06 * s))
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local hx, hy = s.X / 2, s.Y / 2
		local zf, zb = -s.Z / 2 - 0.05, s.Z / 2 + 0.05
		piece(upper, outfit, "Skin", s + Vector3.new(0.06, 0.02, 0.06), C.Skin, CFrame.new())
		-- The web mesh: rings round the chest, arcs across, a centre line.
		for _, z in ipairs({ zf, zb }) do
			strand(upper, outfit, Vector3.new(0, hy, 0), Vector3.new(0, -hy, 0), z)
			for k = 0, 3 do
				local y = hy * 0.55 - k * s.Y * 0.24
				local sag = 0.1 + k * 0.02
				strand(upper, outfit, Vector3.new(-hx, y, 0), Vector3.new(-hx * 0.45, y - sag, 0), z)
				strand(upper, outfit, Vector3.new(-hx * 0.45, y - sag, 0), Vector3.new(0, y - sag * 1.3, 0), z)
				strand(upper, outfit, Vector3.new(0, y - sag * 1.3, 0), Vector3.new(hx * 0.45, y - sag, 0), z)
				strand(upper, outfit, Vector3.new(hx * 0.45, y - sag, 0), Vector3.new(hx, y, 0), z)
			end
		end
		for _, side in ipairs({ -1, 1 }) do
			meshRing(upper, outfit, side * hx * 0.5, hy * 0.35, s.X * 0.18, zf - 0.005)
			strand(upper, outfit, Vector3.new(side * hx * 0.5, hy, 0), Vector3.new(side * hx * 0.5, hy * 0.35 + s.X * 0.15, 0), zf - 0.005)
			strand(upper, outfit, Vector3.new(side * hx * 0.25, -hy * 0.2, 0), Vector3.new(side * hx * 0.3, -hy, 0), zf - 0.005)
		end
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.08, 0.02, 0.08), C.Pants, CFrame.new())
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.12, 0.2, ls.Z + 0.12), C.Belt, CFrame.new(0, ls.Y / 2 - 0.06, 0))
		piece(lower, outfit, "Buckle", Vector3.new(0.24, 0.16, 0.06), C.Gold, CFrame.new(0, ls.Y / 2 - 0.06, -ls.Z / 2 - 0.08), Enum.Material.Metal)
		-- The black strap with white rungs hanging off his left hip, round behind his leg.
		local strapTop = CFrame.new(-ls.X / 2 - 0.08, 0, 0.1)
		for k = 0, 7 do
			local cf = strapTop * CFrame.new(-0.02 * k, -0.25 - k * 0.32, 0.06 * k) * CFrame.Angles(math.rad(-6 - k * 2), 0, math.rad(-4))
			piece(lower, outfit, "Strap", Vector3.new(0.06, 0.34, 0.26), C.Mesh, cf)
			piece(lower, outfit, "Rung", Vector3.new(0.07, 0.05, 0.27), C.Rung, cf * CFrame.new(0, 0.1, 0))
		end
	end
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			piece(arm, outfit, "Skin", as + Vector3.new(0.04, 0.01, 0.04), C.Skin, CFrame.new())
			if name:find("Upper") or name == "Left Arm" or name == "Right Arm" then
				-- Dark swirling tattoos on the outside of the arm.
				local side = name:find("Left") and -1 or 1
				local x = side * (as.X / 2 + 0.03)
				for k = 0, 2 do
					piece(arm, outfit, "Tattoo", Vector3.new(0.02, 0.06, as.Z * (0.7 - k * 0.15)), C.Mesh, CFrame.new(x, as.Y * 0.3 - k * as.Y * 0.18, 0) * CFrame.Angles(math.rad(25 - k * 20), 0, 0))
				end
				piece(arm, outfit, "TattooCurl", Vector3.new(0.02, as.Y * 0.35, 0.06), C.Mesh, CFrame.new(x, -as.Y * 0.1, as.Z * 0.25) * CFrame.Angles(math.rad(15), 0, 0))
			end
			if name:find("Lower") or name == "Left Arm" or name == "Right Arm" then
				piece(arm, outfit, "Wristband", Vector3.new(as.X + 0.14, 0.3, as.Z + 0.14), C.Band, CFrame.new(0, -as.Y / 2 + 0.2, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local lsz = leg.Size
			piece(leg, outfit, "Trousers", lsz + Vector3.new(0.1, 0.02, 0.1), C.Pants, CFrame.new())
			-- A row of gold buttons down the outer seam.
			local side = name:find("Left") and -1 or 1
			for k = 0, 2 do
				ball(leg, outfit, "Button", 0.12, C.Gold, CFrame.new(side * (lsz.X / 2 + 0.06), lsz.Y * 0.3 - k * lsz.Y * 0.3, 0))
			end
			if name:find("Lower") or name == "Left Leg" or name == "Right Leg" then
				-- The split hem.
				piece(leg, outfit, "Split", Vector3.new(0.04, lsz.Y * 0.35, 0.04), C.PantsShade, CFrame.new(0, -lsz.Y * 0.33, -lsz.Z / 2 - 0.06))
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Boot", foot.Size + Vector3.new(0.08, 0.06, 0.2), C.Boot, CFrame.new(0, 0, -0.06))
		end
	end
end

function DiavoloOutfit.apply(character)
	if character:FindFirstChild("DiavoloOutfit") then
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
	outfit.Name = "DiavoloOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function DiavoloOutfit.remove(character)
	local outfit = character:FindFirstChild("DiavoloOutfit")
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
		if character:GetAttribute("TuskAct") == DiavoloOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == DiavoloOutfit.Act then
					DiavoloOutfit.apply(character)
				end
			end)
		else
			DiavoloOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function DiavoloOutfit.init()
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

return DiavoloOutfit
end
end
