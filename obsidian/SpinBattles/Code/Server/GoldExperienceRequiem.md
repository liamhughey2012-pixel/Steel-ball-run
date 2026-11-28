---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer › TuskActs"
updated: 2026-11-22
---
# GoldExperienceRequiem

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer › TuskActs` |
| **Exact name** | `GoldExperienceRequiem` (capitals matter) |

**What it does:** GOLD EXPERIENCE REQUIEM: what the Requiem Arrow makes of Giorno's Gold Experience (Act 31, only from the arrow; back to Gold Experience, Act 30, when he goes down). Its power: RETURN TO ZERO. Whatever anyone tries to do to him never happens. M1        REQUIEM MUDA COMBO: heavier, longer-reaching blows Ability 1 MUDA RUSH: REQUIEM: a bigger storm of punches; the last "MUDA!" blasts them away Ability 2 RETURN TO ZERO: for a moment, any attack on him is undone: it never lands, and the attacker is sent back to where they started, hurt, and can't use abilities for a while Ability 3 ZERO PUNCH: Gold Experience Requiem is suddenly in front of them (a short dash) with an unblockable punch that cancels what they were doing (they can't use abilities for a while) Ultimate  INFINITE DEATH: the nearest enemy in range is trapped in a death that never ends: held, they're thrown about and hurt again and again ("they will never arrive at the truth"), then one last blow Numbers: TuskConfig.GER. All damage goes through S.hit.

## How to add it
1. In Studio's Explorer, find **TuskActs** (ServerScriptService › SpinServer › TuskActs).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **GoldExperienceRequiem**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
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

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

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
```
