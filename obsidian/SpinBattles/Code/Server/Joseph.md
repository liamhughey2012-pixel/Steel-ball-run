---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer › TuskActs"
updated: 2026-11-22
---
# Joseph

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer › TuskActs` |
| **Exact name** | `Joseph` (capitals matter) |

**What it does:** Joseph Joestar (a visitor from another world: Part 3): HERMIT PURPLE. Thorny purple vines, Hamon running through them, and his greatest technique: running away. Registered as "Act" 22. M1        HAMON COMBO: Hamon-charged punches; the 4th is a SUNLIGHT YELLOW OVERDRIVE that launches Ability 1 HERMIT GRAB: vines shoot out in a line, snag the first enemy, drag them back to him and jolt them with Hamon Ability 2 HAMON VINES: a fan of vines whips out in front; Hamon surges through them into everyone they touch Ability 3 NIGERUNDAYO!: "run away!": 70% faster for 3.5 s, and he can't be hit for the first half second Ultimate  HERMIT WEB OVERDRIVE: vines burst up out of the ground and bind everyone near him (they can't move); Hamon pulses through them, then SUNLIGHT YELLOW OVERDRIVE blasts them away Numbers: TuskConfig.Joseph. All damage goes through S.hit (CombatAdapter).

## How to add it
1. In Studio's Explorer, find **TuskActs** (ServerScriptService › SpinServer › TuskActs).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **Joseph**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	Joseph  (ServerScriptService.SpinServer.TuskActs.Joseph)

	Joseph Joestar (a visitor from another world: Part 3): HERMIT PURPLE.
	Thorny purple vines, Hamon running through them, and his greatest
	technique: running away. Registered as "Act" 22.
	  M1        HAMON COMBO: Hamon-charged punches; the 4th is a SUNLIGHT
	            YELLOW OVERDRIVE that launches
	  Ability 1 HERMIT GRAB: vines shoot out in a line, snag the first enemy,
	            drag them back to him and jolt them with Hamon
	  Ability 2 HAMON VINES: a fan of vines whips out in front; Hamon surges
	            through them into everyone they touch
	  Ability 3 NIGERUNDAYO!: "run away!": 70% faster for 3.5 s, and he
	            can't be hit for the first half second
	  Ultimate  HERMIT WEB OVERDRIVE: vines burst up out of the ground and
	            bind everyone near him (they can't move); Hamon pulses
	            through them, then SUNLIGHT YELLOW OVERDRIVE blasts them away
	Numbers: TuskConfig.Joseph. All damage goes through S.hit (CombatAdapter).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Joseph = {}
local cfg = TuskConfig.Joseph
local ACT = 22

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

function Joseph.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- Pinning (bound by vines). Counted, so two binds don't free them early.
---------------------------------------------------------------------------
local pins = setmetatable({}, { __mode = "k" }) -- [root] = { Count, WasAnchored }

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

local function away(from, to, fallback)
	local v = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return v.Magnitude > 0.1 and v.Unit or fallback
end

---------------------------------------------------------------------------
-- 1: HERMIT GRAB
---------------------------------------------------------------------------
local function hermitGrab(S, player, state, aim)
	local c = cfg.HermitGrab
	if not ready(S, player, state, "HermitGrab", 1) then
		return
	end
	local character, _, root = alive(S, player)
	local life = state.Life
	S.lock(state, c.Windup + c.PullTime + 0.2)
	S.fx("Ability", { Character = character, Act = ACT, Move = "HermitGrab", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = Moves.flat(S.aim(aim, r))
		local from = r.Position
		-- Stops at a wall.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local wall = workspace:Raycast(from, dir * c.Range, params)
		local reach = c.Range
		if wall and not (wall.Instance.Parent and wall.Instance.Parent:FindFirstChildOfClass("Humanoid")) then
			reach = (wall.Position - from).Magnitude
		end
		-- The first enemy along the line.
		local mid = from + dir * (reach / 2)
		local best, bestD, bestRoot
		for _, target in ipairs(S.Hitbox.inBox(char, CFrame.lookAt(mid, mid + dir), Vector3.new(c.Width, 6, reach), 8)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr then
				local d = (tr.Position - from):Dot(dir)
				if d > 0 and (not bestD or d < bestD) then
					best, bestD, bestRoot = target, d, tr
				end
			end
		end
		if not best then
			S.startCooldown(player, state, "HermitGrab", c.MissCooldown, 1)
			S.fx("Ability", { Character = char, Act = ACT, Move = "HermitGrab", Phase = "Miss", From = from, To = from + dir * reach })
			return
		end
		S.startCooldown(player, state, "HermitGrab", c.Cooldown, 1)
		if not S.hit(player, best, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = -dir, Position = bestRoot.Position, Source = "JosephGrab" }) then
			S.fx("Ability", { Character = char, Act = ACT, Move = "HermitGrab", Phase = "Miss", From = from, To = bestRoot.Position })
			return
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "HermitGrab", Phase = "Snag", Target = best, From = from, PullTime = c.PullTime })
		-- Dragged back to just in front of him.
		local start = bestRoot.Position
		local steps = 7
		for k = 1, steps do
			task.delay(c.PullTime * k / steps, function()
				local _, _, rr = alive(S, player)
				if not rr or not best.Parent or not bestRoot.Parent or bestRoot.Anchored then
					return
				end
				local stopAt = rr.Position + Moves.flat(rr.CFrame.LookVector) * c.StopDistance
				local p = start:Lerp(Vector3.new(stopAt.X, start.Y, stopAt.Z), k / steps)
				best:PivotTo(CFrame.lookAt(p, Vector3.new(rr.Position.X, p.Y, rr.Position.Z)))
				bestRoot.AssemblyLinearVelocity = Vector3.new()
				if k == steps then
					S.hit(player, best, { Damage = c.ShockDamage, Stun = 0.5, Knockback = 0, Direction = dir, Position = bestRoot.Position, Unblockable = true, Source = "JosephHamon" })
					S.fx("Ability", { Character = char, Act = ACT, Move = "HermitGrab", Phase = "Shock", Target = best })
				end
			end)
		end
	end)
end

---------------------------------------------------------------------------
-- 2: HAMON VINES
---------------------------------------------------------------------------
local function hamonVines(S, player, state, aim)
	local c = cfg.HamonVines
	if not ready(S, player, state, "HamonVines", 2) then
		return
	end
	S.startCooldown(player, state, "HamonVines", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.3)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "HamonVines", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = Moves.flat(S.aim(aim, r))
		local cosLimit = math.cos(math.rad(c.Cone / 2))
		local hits = {}
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, c.Range, 10)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr then
				local f = Vector3.new(tr.Position.X - r.Position.X, 0, tr.Position.Z - r.Position.Z)
				if (f.Magnitude < 2 or f.Unit:Dot(dir) >= cosLimit) and S.Hitbox.lineOfSight(r.Position, tr.Position, { char, target }) then
					if S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = away(r.Position, tr.Position, dir), Position = tr.Position, Source = "JosephVines" }) then
						table.insert(hits, target)
					end
				end
			end
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "HamonVines", Phase = "Lash", From = r.Position, Direction = dir, Range = c.Range, Cone = c.Cone, Hits = hits })
	end)
end

---------------------------------------------------------------------------
-- 3: NIGERUNDAYO!
---------------------------------------------------------------------------
local function nigerundayo(S, player, state)
	local c = cfg.Nigerundayo
	if not S.cooldownReady(player, state, "Nigerundayo", 3) or state.Charging then
		return
	end
	-- (Usable even mid-combo: running away is always an option.)
	S.startCooldown(player, state, "Nigerundayo", c.Cooldown, 3)
	local character, humanoid = alive(S, player)
	local token = tostring({})
	character:SetAttribute("JosephRunToken", token)
	character:SetAttribute("JosephRunUntil", workspace:GetServerTimeNow() + c.Time)
	S.Adapter.setMoveModifier(humanoid, "Nigerundayo", c.Speed)
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	S.fx("Ability", { Character = character, Act = ACT, Move = "Nigerundayo", Phase = "Run", Time = c.Time })
	task.delay(c.IFrames, function()
		if character.Parent and character:GetAttribute("JosephRunToken") == token then
			character:SetAttribute(iframes, nil)
		end
	end)
	task.delay(c.Time, function()
		if character.Parent and character:GetAttribute("JosephRunToken") == token then
			character:SetAttribute("JosephRunToken", nil)
			character:SetAttribute("JosephRunUntil", nil)
			S.Adapter.setMoveModifier(humanoid, "Nigerundayo", nil)
		end
	end)
end

function Joseph.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		hermitGrab(S, player, state, aim)
	elseif slot == 2 then
		hamonVines(S, player, state, aim)
	elseif slot == 3 then
		nigerundayo(S, player, state)
	end
end

---------------------------------------------------------------------------
-- HERMIT WEB OVERDRIVE (ultimate)
---------------------------------------------------------------------------
function Joseph.Ultimate(S, player, state, aim)
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
		local char, _, r = alive(S, player)
		local center = r.Position
		local bound = {}
		for _, target in ipairs(S.Hitbox.inRadius(char, center, u.Radius, 12)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr then
				pin(tr)
				table.insert(bound, target)
			end
		end
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Bind", Position = center, Radius = u.Radius, Targets = bound, Time = u.BindTime })
		local ticks = math.max(1, math.floor(u.BindTime / u.Tick))
		for k = 1, ticks do
			task.delay(k * u.Tick, function()
				if state.Life ~= life then
					return
				end
				for _, target in ipairs(bound) do
					local tr = target.Parent and target:FindFirstChild("HumanoidRootPart")
					if tr then
						S.hit(player, target, { Damage = u.TickDamage, Stun = u.Tick + 0.1, Knockback = 0, Direction = Vector3.new(0, 1, 0), Position = tr.Position, Source = "JosephWeb" })
					end
				end
				S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Pulse", Targets = bound })
			end)
		end
		task.delay(u.BindTime, function()
			for _, target in ipairs(bound) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr then
					unpin(tr)
				end
			end
			if state.Life ~= life or not char.Parent then
				S.fx("Ultimate", { Character = char, Act = ACT, Phase = "End" })
				return
			end
			local _, _, rr = alive(S, player)
			local at = rr and rr.Position or center
			for _, target in ipairs(bound) do
				local tr = target.Parent and target:FindFirstChild("HumanoidRootPart")
				if tr then
					S.hit(player, target, { Damage = u.BlastDamage, Stun = u.BlastStun, Knockback = u.BlastKnockback, Launch = u.BlastLaunch, Direction = away(at, tr.Position, Vector3.new(0, 0, 1)), Position = tr.Position, Unblockable = true, Source = "JosephOverdrive" })
				end
			end
			S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Blast", Position = at, Radius = u.Radius, Targets = bound })
		end)
	end)
end

function Joseph.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("JosephRunToken", nil)
		character:SetAttribute("JosephRunUntil", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "Nigerundayo", nil)
		end
	end
end

return Joseph
```
