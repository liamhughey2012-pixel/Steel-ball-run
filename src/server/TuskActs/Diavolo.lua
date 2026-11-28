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

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

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
