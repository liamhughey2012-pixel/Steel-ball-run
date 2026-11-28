---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer › TuskActs"
updated: 2026-11-22
---
# LoveTrain

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer › TuskActs` |
| **Exact name** | `LoveTrain` (capitals matter) |

**What it does:** D4C -LOVE TRAIN-: what D4C becomes when Funny Valentine holds the COMPLETE Saint's Corpse (Act 33, Character "Valentine"; back to D4C, Act 13, the moment he doesn't: the corpse scatters, or he goes down). He stands in a gap of light where misfortune can't reach him: it goes somewhere else, to someone else. Passive   THE GAP OF LIGHT: he only takes part of every hit (LoveTrain.Passive.Keep); the rest of the misfortune lands on the nearest other enemy instead M1        LOVE TRAIN COMBO: D4C's chops with light behind them; the 4th is a blow of light that launches Ability 1 LIGHT RAIL: he glides forward inside the wall of light (nothing can touch him); everyone he passes through is struck by misfortune Ability 2 MISFORTUNE TRANSFER: everything he's been hit for lately (even the part that reached him) lands on the nearest enemy in front, all at once, and he gets that much health back Ability 3 LIGHT SPEARS: five spears of light fan out from the wall; each one strikes the first enemy in its path Ultimate  LOVE TRAIN: THE CHOSEN ONE: for a while nothing reaches him at all (every hit, every stun, all of it goes elsewhere), he moves faster, and the light pulses misfortune into everyone near; it ends in a burst of light The switch (13 <-> 33) is watched here (Init): CorpseComplete. Numbers: TuskConfig.LoveTrain. All damage goes through S.hit.

## How to add it
1. In Studio's Explorer, find **TuskActs** (ServerScriptService › SpinServer › TuskActs).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **LoveTrain**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	LoveTrain  (ServerScriptService.SpinServer.TuskActs.LoveTrain)

	D4C -LOVE TRAIN-: what D4C becomes when Funny Valentine holds the
	COMPLETE Saint's Corpse (Act 33, Character "Valentine"; back to D4C, Act
	13, the moment he doesn't: the corpse scatters, or he goes down). He
	stands in a gap of light where misfortune can't reach him: it goes
	somewhere else, to someone else.
	  Passive   THE GAP OF LIGHT: he only takes part of every hit
	            (LoveTrain.Passive.Keep); the rest of the misfortune lands on
	            the nearest other enemy instead
	  M1        LOVE TRAIN COMBO: D4C's chops with light behind them; the 4th
	            is a blow of light that launches
	  Ability 1 LIGHT RAIL: he glides forward inside the wall of light
	            (nothing can touch him); everyone he passes through is struck
	            by misfortune
	  Ability 2 MISFORTUNE TRANSFER: everything he's been hit for lately
	            (even the part that reached him) lands on the nearest enemy in
	            front, all at once, and he gets that much health back
	  Ability 3 LIGHT SPEARS: five spears of light fan out from the wall;
	            each one strikes the first enemy in its path
	  Ultimate  LOVE TRAIN: THE CHOSEN ONE: for a while nothing reaches him
	            at all (every hit, every stun, all of it goes elsewhere), he
	            moves faster, and the light pulses misfortune into everyone
	            near; it ends in a burst of light
	The switch (13 <-> 33) is watched here (Init): CorpseComplete.
	Numbers: TuskConfig.LoveTrain. All damage goes through S.hit.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local Moves = require(script.Parent.Parent.TuskMoves)

local LoveTrain = {}
local cfg = TuskConfig.LoveTrain
local ACT = 33
local D4C = 13
local MISFORTUNE = "LoveTrainMisfortune"

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

-- The nearest enemy to `pos` (not `exclude`), within `range`.
local function nearestOther(S, character, pos, range, exclude)
	local best, bestD
	for _, target in ipairs(S.Hitbox.inRadius(character, pos, range, 30)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and target ~= exclude and aliveModel(target) then
			local d = (tr.Position - pos).Magnitude
			if not bestD or d < bestD then
				best, bestD = target, d
			end
		end
	end
	return best
end

-- What he's been hit for lately: { { T, Damage } }, per character.
local recent = setmetatable({}, { __mode = "k" })
local function recentDamage(character, window)
	local list = recent[character]
	if not list then
		return 0
	end
	local total, cutoff, keep = 0, now() - window, {}
	for _, e in ipairs(list) do
		if e.T >= cutoff then
			total = total + e.Damage
			table.insert(keep, e)
		end
	end
	recent[character] = keep
	return total
end

function LoveTrain.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: LIGHT RAIL
---------------------------------------------------------------------------
local function lightRail(S, player, state, aim)
	local c = cfg.Rail
	if not ready(S, player, state, "Rail", 1) then
		return
	end
	local character, _, root = alive(S, player)
	local dir = Moves.flat(S.aim(aim, root))
	local to = Moves.safeStep(character, root, dir, c.Distance)
	if not to then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "Rail", c.Cooldown, 1)
	S.lock(state, c.Time + 0.1)
	local from = root.Position
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	S.fx("Ability", { Character = character, Act = ACT, Move = "Rail", Phase = "Glide", From = from, To = to, Time = c.Time })
	local life = state.Life
	local steps = 6
	local struck = {}
	for k = 1, steps do
		task.delay(c.Time * k / steps, function()
			if state.Life ~= life or not character.Parent then
				return
			end
			local p = from:Lerp(to, k / steps)
			character:PivotTo(CFrame.lookAt(p, p + dir))
			for _, target in ipairs(S.Hitbox.inRadius(character, p, c.Width, 8)) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr and not struck[target] then
					struck[target] = true
					S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = dir, Position = tr.Position, Source = MISFORTUNE })
				end
			end
			if k == steps then
				character:SetAttribute(iframes, nil)
				local hits = {}
				for t in pairs(struck) do
					table.insert(hits, t)
				end
				S.fx("Ability", { Character = character, Act = ACT, Move = "Rail", Phase = "Arrive", Position = p, Targets = hits })
			end
		end)
	end
	task.delay(c.Time + 0.3, function()
		if character.Parent then
			character:SetAttribute(iframes, nil)
		end
	end)
end

---------------------------------------------------------------------------
-- 2: MISFORTUNE TRANSFER
---------------------------------------------------------------------------
local function transfer(S, player, state, aim)
	local c = cfg.Transfer
	if not ready(S, player, state, "Transfer", 2) then
		return
	end
	local character, humanoid, root = alive(S, player)
	local target = Moves.findTarget(S, character, root, c.Range, c.Cone, Moves.flat(S.aim(aim, root)))
	if not target then
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	S.startCooldown(player, state, "Transfer", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.2)
	local life = state.Life
	local stored = math.clamp(recentDamage(character, c.Window), c.MinDamage, c.MaxDamage)
	S.fx("Ability", { Character = character, Act = ACT, Move = "Transfer", Phase = "Gather", Target = target, Windup = c.Windup, Amount = stored })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) or not aliveModel(target) then
			return
		end
		local tr = target:FindFirstChild("HumanoidRootPart")
		if not tr then
			return
		end
		local landed = S.hit(player, target, { Damage = stored, Stun = c.Stun, Knockback = c.Knockback, Direction = Moves.flat(tr.Position - root.Position), Position = tr.Position, Source = MISFORTUNE, Unblockable = true })
		if landed then
			recent[character] = {}
			if humanoid.Parent and humanoid.Health > 0 then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + stored * c.HealShare)
			end
		end
		S.fx("Ability", { Character = character, Act = ACT, Move = "Transfer", Phase = "Land", Target = target, Amount = stored, Hit = landed })
	end)
end

---------------------------------------------------------------------------
-- 3: LIGHT SPEARS
---------------------------------------------------------------------------
local function spears(S, player, state, aim)
	local c = cfg.Spears
	if not ready(S, player, state, "Spears", 3) then
		return
	end
	S.startCooldown(player, state, "Spears", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "Spears", Phase = "Form", Windup = c.Windup, Count = c.Count, Spread = c.Spread })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local look = Moves.flat(S.aim(aim, r))
		local lines = {}
		local struck = {} -- (each enemy is struck by one spear only)
		for k = 1, c.Count do
			local ang = math.rad(-c.Spread / 2 + c.Spread * (k - 1) / math.max(1, c.Count - 1))
			local cs, sn = math.cos(ang), math.sin(ang)
			local dir = Vector3.new(look.X * cs - look.Z * sn, 0, look.X * sn + look.Z * cs)
			local from = r.Position + Vector3.new(0, 0.5, 0)
			-- The first enemy along this line.
			local best, bestAlong
			for _, target in ipairs(S.Hitbox.inRadius(char, from + dir * c.Range / 2, c.Range / 2 + 2, 20)) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr and not struck[target] then
					local off = tr.Position - from
					local along = off:Dot(dir)
					if along > 0 and along <= c.Range and (off - dir * along).Magnitude <= c.Width and (not bestAlong or along < bestAlong) then
						best, bestAlong = target, along
					end
				end
			end
			local endAt = from + dir * (bestAlong or c.Range)
			if best then
				struck[best] = true
				local tr = best:FindFirstChild("HumanoidRootPart")
				S.hit(player, best, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Position = tr.Position, Source = MISFORTUNE })
			end
			table.insert(lines, { From = from, To = endAt, Hit = best ~= nil })
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "Spears", Phase = "Fire", Lines = lines })
	end)
end

function LoveTrain.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		lightRail(S, player, state, aim)
	elseif slot == 2 then
		transfer(S, player, state, aim)
	elseif slot == 3 then
		spears(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- LOVE TRAIN: THE CHOSEN ONE (ultimate)
---------------------------------------------------------------------------
function LoveTrain.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, humanoid = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.2)
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
		local untilT = now() + u.Duration
		character:SetAttribute("LoveTrainChosenUntil", untilT)
		character:SetAttribute("LoveTrainKeep", 0) -- nothing reaches him at all
		S.Adapter.setMoveModifier(humanoid, "LoveTrainChosen", u.SpeedMultiplier)
		S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Chosen", Time = u.Duration, Radius = u.PulseRadius })
		local pulses = math.floor(u.Duration / u.PulseEvery)
		for k = 1, pulses do
			task.delay(k * u.PulseEvery, function()
				if state.Life ~= life or character:GetAttribute("LoveTrainChosenUntil") ~= untilT then
					return
				end
				local _, _, r = alive(S, player)
				if not r then
					return
				end
				local hits = {}
				for _, target in ipairs(S.Hitbox.inRadius(character, r.Position, u.PulseRadius, 12)) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr and S.hit(player, target, { Damage = u.PulseDamage, Stun = u.PulseStun, Knockback = 6, Direction = Moves.flat(tr.Position - r.Position), Position = tr.Position, Source = MISFORTUNE }) then
						table.insert(hits, target)
					end
				end
				S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Pulse", Position = r.Position, Radius = u.PulseRadius, Targets = hits })
			end)
		end
		task.delay(u.Duration, function()
			if humanoid.Parent then
				S.Adapter.setMoveModifier(humanoid, "LoveTrainChosen", nil)
			end
			if not character.Parent or character:GetAttribute("LoveTrainChosenUntil") ~= untilT then
				return
			end
			character:SetAttribute("LoveTrainChosenUntil", nil)
			-- Back to the everyday gap of light (if he's still Love Train).
			character:SetAttribute("LoveTrainKeep", character:GetAttribute("TuskAct") == ACT and cfg.Passive.Keep or nil)
			if state.Life ~= life then
				return
			end
			local _, _, r = alive(S, player)
			if r then
				Moves.aoe(S, player, r.Position, u.BurstRadius, { Damage = u.BurstDamage, Stun = u.BurstStun, Knockback = u.BurstKnockback, Launch = 16, Source = MISFORTUNE }, 10)
				S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Burst", Position = r.Position, Radius = u.BurstRadius })
			end
		end)
	end)
end

function LoveTrain.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("LoveTrainChosenUntil", nil)
		character:SetAttribute("LoveTrainKeep", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "LoveTrainChosen", nil)
		end
	end
end

function LoveTrain.Init(S)
	-- The shed misfortune lands on someone else: the nearest other enemy
	-- (not whoever hit him, if there's anyone else), wherever they are.
	S.Adapter.on("LoveTrainShed", function(attackerPlayer, target, shed, info)
		if target:GetAttribute("TuskAct") ~= ACT then
			return
		end
		local r = target:FindFirstChild("HumanoidRootPart")
		local owner
		for who, state in pairs(S.States or {}) do
			if state.Character == target then
				owner = who
			end
		end
		if not r or not owner then
			return
		end
		local attacker = attackerPlayer and attackerPlayer.Character
		local victim = nearestOther(S, target, r.Position, cfg.Passive.Range, attacker) or (attacker and aliveModel(attacker) and attacker) or nil
		if victim then
			local vr = victim:FindFirstChild("HumanoidRootPart")
			if vr then
				S.hit(owner, victim, { Damage = shed * cfg.Passive.Share, Stun = 0.25, Knockback = 4, Direction = Moves.flat(vr.Position - r.Position), Position = vr.Position, Source = MISFORTUNE })
				S.fx("Ability", { Character = target, Act = ACT, Move = "Gap", Phase = "Redirect", From = r.Position, To = vr.Position, Victim = victim })
			end
		end
	end)
	-- Remember what he's been hit for (Misfortune Transfer).
	S.Adapter.on("Hit", function(attackerPlayer, target, damage)
		if target and target:GetAttribute("TuskAct") == ACT and type(damage) == "number" then
			recent[target] = recent[target] or {}
			table.insert(recent[target], { T = now(), Damage = damage })
		end
	end)
	-- The switch: holding the complete corpse makes D4C into Love Train.
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
			if character and character.Parent and (act == D4C or act == ACT) and not S.isBusy(state) and not state.Charging then
				local want = character:GetAttribute("CorpseComplete") and ACT or D4C
				if want ~= act and Registry.isImplemented(want) then
					pcall(S.select, who, want, true)
				end
			end
			-- The everyday gap of light is on whenever he's Love Train.
			if character and character.Parent and not character:GetAttribute("LoveTrainChosenUntil") then
				local keep = state.Act == ACT and cfg.Passive.Keep or nil
				if character:GetAttribute("LoveTrainKeep") ~= keep then
					character:SetAttribute("LoveTrainKeep", keep)
				end
			end
		end
	end)
end

return LoveTrain
```
