---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer › TuskActs"
updated: 2026-11-22
---
# Okuyasu

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer › TuskActs` |
| **Exact name** | `Okuyasu` (capitals matter) |

**What it does:** Okuyasu Nijimura (Part 4): THE HAND. Registered as "Act" 27. The Hand's right palm ERASES whatever it swipes through, space included, with a "GAOON". M1        HAND COMBO: The Hand swings with him; the 4th is a heavy backhand that launches Ability 1 SPACE ERASE: a slow, heavy swipe of the right palm erases everything in front: big damage that can't be blocked Ability 2 ERASE PULL: he erases the space between himself and the nearest enemy in front (a long way off): they're yanked right up to him, dazed Ability 3 ERASE DASH: he erases the space in front of himself and is suddenly further along (untouchable for a moment) Ultimate  ZA HANDO: GREAT ERASURE: The Hand swipes again and again, each swipe dragging everyone in front closer, then one huge erase sends them flying Numbers: TuskConfig.Okuyasu. All damage goes through S.hit (CombatAdapter).

## How to add it
1. In Studio's Explorer, find **TuskActs** (ServerScriptService › SpinServer › TuskActs).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **Okuyasu**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	Okuyasu  (ServerScriptService.SpinServer.TuskActs.Okuyasu)

	Okuyasu Nijimura (Part 4): THE HAND. Registered as "Act" 27.
	The Hand's right palm ERASES whatever it swipes through, space included,
	with a "GAOON".
	  M1        HAND COMBO: The Hand swings with him; the 4th is a heavy
	            backhand that launches
	  Ability 1 SPACE ERASE: a slow, heavy swipe of the right palm erases
	            everything in front: big damage that can't be blocked
	  Ability 2 ERASE PULL: he erases the space between himself and the
	            nearest enemy in front (a long way off): they're yanked right
	            up to him, dazed
	  Ability 3 ERASE DASH: he erases the space in front of himself and is
	            suddenly further along (untouchable for a moment)
	  Ultimate  ZA HANDO: GREAT ERASURE: The Hand swipes again and again,
	            each swipe dragging everyone in front closer, then one huge
	            erase sends them flying
Numbers: TuskConfig.Okuyasu. All damage goes through S.hit (CombatAdapter).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Okuyasu = {}
local cfg = TuskConfig.Okuyasu
local ACT = 27

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Okuyasu.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

-- Move a target to `to` (facing `look`), unless something holds them in place.
local function yank(target, to, look)
	local tr = target:FindFirstChild("HumanoidRootPart")
	if not tr or tr.Anchored or target:GetAttribute("TimeStopped") then
		return false
	end
	target:PivotTo(CFrame.lookAt(to, Vector3.new(look.X, to.Y, look.Z)))
	tr.AssemblyLinearVelocity = Vector3.new()
	return true
end

---------------------------------------------------------------------------
-- 1: SPACE ERASE
---------------------------------------------------------------------------
local function erase(S, player, state, aim)
	local c = cfg.Erase
	if not ready(S, player, state, "Erase", 1) then
		return
	end
	S.startCooldown(player, state, "Erase", c.Cooldown, 1)
	S.lock(state, c.Windup + 0.3)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "Erase", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local box = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
		local count = Moves.boxHit(S, player, box, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = r.CFrame.LookVector, Source = "OkuyasuErase", Unblockable = true }, c.MaxTargets)
		S.fx("Ability", { Character = char, Act = ACT, Move = "Erase", Phase = "Swipe", CFrame = box, Size = c.HitboxSize, Hit = count > 0 })
	end)
end

---------------------------------------------------------------------------
-- 2: ERASE PULL
---------------------------------------------------------------------------
local function erasePull(S, player, state, aim)
	local c = cfg.ErasePull
	if not ready(S, player, state, "ErasePull", 2) then
		return
	end
	S.startCooldown(player, state, "ErasePull", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.25)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "ErasePull", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = Moves.flat(S.aim(aim, r))
		local target = Moves.findTarget(S, char, r, c.Range, c.Cone, dir)
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		if not tr then
			S.startCooldown(player, state, "ErasePull", c.MissCooldown, 2)
			S.fx("Ability", { Character = char, Act = ACT, Move = "ErasePull", Phase = "Miss", From = r.Position, To = r.Position + dir * c.Range })
			return
		end
		local from = tr.Position
		local to = r.Position + dir * c.PullTo
		local pulled = yank(target, to, r.Position)
		S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = -dir, Position = pulled and to or from, Source = "OkuyasuPull" })
		S.fx("Ability", { Character = char, Act = ACT, Move = "ErasePull", Phase = "Pull", Target = target, From = from, To = pulled and to or from })
	end)
end

---------------------------------------------------------------------------
-- 3: ERASE DASH
---------------------------------------------------------------------------
local function eraseDash(S, player, state, aim)
	local c = cfg.EraseDash
	if not ready(S, player, state, "EraseDash", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local dir = Moves.flat(S.aim(aim, root))
	local to = Moves.safeStep(character, root, dir, c.Distance)
	if not to then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "EraseDash", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.1)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "EraseDash", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local from = r.Position
		local iframes = S.Adapter.Settings.IFrameAttribute
		char:SetAttribute(iframes, true)
		char:PivotTo(CFrame.lookAt(to, to + dir))
		S.fx("Ability", { Character = char, Act = ACT, Move = "EraseDash", Phase = "Step", From = from, To = to })
		task.delay(c.IFrames, function()
			if char.Parent then
				char:SetAttribute(iframes, nil)
			end
		end)
	end)
end

function Okuyasu.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		erase(S, player, state, aim)
	elseif slot == 2 then
		erasePull(S, player, state, aim)
	elseif slot == 3 then
		eraseDash(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- ZA HANDO: GREAT ERASURE (ultimate)
---------------------------------------------------------------------------
function Okuyasu.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character = alive(S, player)
	local life = state.Life
	local total = u.Windup + u.Swipes * u.Gap
	S.lock(state, total + 0.2)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Call", Windup = u.Windup, Swipes = u.Swipes, Gap = u.Gap })
	task.delay(u.Windup, function()
		if state.Life ~= life or not alive(S, player) then
			if character.Parent then
				character:SetAttribute("Armored", nil)
			end
			return
		end
		S.finishUltimate(player, state)
	end)
	for i = 1, u.Swipes do
		task.delay(u.Windup + (i - 1) * u.Gap, function()
			if state.Life ~= life or not alive(S, player) then
				return
			end
			local char, _, r = alive(S, player)
			local box = r.CFrame * CFrame.new(0, 0, -u.HitboxForward)
			local last = i == u.Swipes
			if last then
				Moves.boxHit(S, player, box, u.HitboxSize, { Damage = u.FinalDamage, Stun = 0.8, Knockback = u.FinalKnockback, Launch = u.FinalLaunch, Direction = r.CFrame.LookVector, Source = "OkuyasuUlt", Unblockable = true }, u.MaxTargets)
				if char.Parent then
					char:SetAttribute("Armored", nil)
				end
			else
				local _, hitSet = Moves.boxHit(S, player, box, u.HitboxSize, { Damage = u.Damage, Stun = u.Stun, Knockback = 0, Direction = r.CFrame.LookVector, Source = "OkuyasuUlt", Unblockable = true }, u.MaxTargets)
				-- Each swipe erases the space between: they're dragged closer.
				for target in pairs(hitSet or {}) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr then
						local close = r.Position + r.CFrame.LookVector * 3
						yank(target, tr.Position:Lerp(Vector3.new(close.X, tr.Position.Y, close.Z), u.Pull), r.Position)
					end
				end
			end
			S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Swipe", Index = i, Last = last, CFrame = box, Size = u.HitboxSize })
		end)
	end
end

function Okuyasu.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
	end
end

return Okuyasu
```
