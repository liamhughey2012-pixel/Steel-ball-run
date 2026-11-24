---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer › TuskActs"
updated: 2026-11-22
---
# Jodio

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer › TuskActs` |
| **Exact name** | `Jodio` (capitals matter) |

**What it does:** Jodio Joestar (The JOJOLands): NOVEMBER RAIN. Heavy raindrops that strike with crushing pressure. Registered as "Act" 17 so it reuses the Tusk ability system. Passive   SOAKED: his rain soaks whoever it hits for a few seconds, and his rain hits a soaked enemy harder M1        NOVEMBER RAIN COMBO: the stand punches with him Ability 1 HEAVY RAIN: a storm cloud forms over the nearest enemy in front; for a few seconds the rain under it pounds everyone there and presses them down (they walk at half speed) Ability 2 RAIN BULLETS: a burst of heavy raindrops fired like bullets Ability 3 RAIN JET: November Rain blasts him forward on a jet of rain; anyone in the way is slammed aside (he can't be hit mid-jet) Ultimate  NOVEMBER RAIN: TORRENT: a huge storm follows him; everyone under it is pounded and pressed down, and when it ends the rain comes down all at once and CRUSHES them Numbers: TuskConfig.Jodio. All damage goes through S.hit (CombatAdapter).

## How to add it
1. In Studio's Explorer, find **TuskActs** (ServerScriptService › SpinServer › TuskActs).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **Jodio**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	Jodio  (ServerScriptService.SpinServer.TuskActs.Jodio)

	Jodio Joestar (The JOJOLands): NOVEMBER RAIN. Heavy raindrops that
	strike with crushing pressure. Registered as "Act" 17 so it reuses the
	Tusk ability system.
	  Passive   SOAKED: his rain soaks whoever it hits for a few seconds, and
	            his rain hits a soaked enemy harder
	  M1        NOVEMBER RAIN COMBO: the stand punches with him
	  Ability 1 HEAVY RAIN: a storm cloud forms over the nearest enemy in
	            front; for a few seconds the rain under it pounds everyone
	            there and presses them down (they walk at half speed)
	  Ability 2 RAIN BULLETS: a burst of heavy raindrops fired like bullets
	  Ability 3 RAIN JET: November Rain blasts him forward on a jet of rain;
	            anyone in the way is slammed aside (he can't be hit mid-jet)
	  Ultimate  NOVEMBER RAIN: TORRENT: a huge storm follows him; everyone
	            under it is pounded and pressed down, and when it ends the
	            rain comes down all at once and CRUSHES them
	Numbers: TuskConfig.Jodio. All damage goes through S.hit (CombatAdapter).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Jodio = {}
local cfg = TuskConfig.Jodio
local ACT = 17

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- A hit from his rain: soaked enemies take more, and it soaks them.
local function rainHit(S, player, target, info)
	local hitInfo = table.clone(info)
	if (target:GetAttribute("SoakedUntil") or 0) > now() then
		hitInfo.Damage = hitInfo.Damage * (cfg.SoakBonus or 1.25)
	end
	local ok = S.hit(player, target, hitInfo)
	if ok then
		target:SetAttribute("SoakedUntil", now() + (cfg.SoakTime or 5))
	end
	return ok
end
Jodio.rainHit = rainHit

-- Rain pressing them down: slowed while it keeps falling on them.
local pressedUntil = setmetatable({}, { __mode = "k" })
local function press(S, target, multiplier, seconds)
	local hum = target:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local untilT = now() + seconds
	pressedUntil[target] = untilT
	S.Adapter.setMoveModifier(hum, "RainPressure", multiplier)
	task.delay(seconds + 0.02, function()
		if pressedUntil[target] == untilT then
			pressedUntil[target] = nil
			S.Adapter.setMoveModifier(hum, "RainPressure", nil)
		end
	end)
end

function Jodio.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: HEAVY RAIN (a storm cloud over them)
---------------------------------------------------------------------------
local function heavyRain(S, player, state, aim)
	local c = cfg.HeavyRain
	if not ready(S, player, state, "HeavyRain", 1) then
		return
	end
	S.startCooldown(player, state, "HeavyRain", c.Cooldown, 1)
	S.lock(state, c.Windup + 0.15)
	local character, _, root = alive(S, player)
	local life = state.Life
	local direction = S.aim(aim, root)
	local target = Moves.findTarget(S, character, root, c.Range, c.Cone, direction)
	local troot = target and target:FindFirstChild("HumanoidRootPart")
	local f = flat(direction)
	local center = troot and troot.Position or root.Position + (f.Magnitude > 0 and f.Unit or Vector3.new(0, 0, -1)) * 25
	center = Moves.groundBelow(center, { character, target })
	S.fx("Ability", { Character = character, Act = ACT, Move = "HeavyRain", Phase = "Cloud", Position = center, Radius = c.Radius, Time = c.Time + c.Windup, Windup = c.Windup })
	local ticks = math.floor(c.Time / c.Tick)
	for i = 1, ticks do
		task.delay(c.Windup + i * c.Tick, function()
			if state.Life ~= life or not player.Character then
				return
			end
			for _, t in ipairs(S.Hitbox.inRadius(player.Character, center + Vector3.new(0, 2.5, 0), c.Radius, 8)) do
				local tr = t:FindFirstChild("HumanoidRootPart")
				if tr then
					press(S, t, c.Pressure, c.Tick + 0.1)
					rainHit(S, player, t, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = Vector3.new(0, -1, 0), Position = tr.Position, Source = "JodioRain" })
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- 2: RAIN BULLETS
---------------------------------------------------------------------------
local function rainBullets(S, player, state, aim)
	local c = cfg.RainBullets
	if not ready(S, player, state, "RainBullets", 2) then
		return
	end
	S.startCooldown(player, state, "RainBullets", c.Cooldown, 2)
	S.lock(state, c.Windup + c.Count * c.Gap)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "RainBullets", Phase = "Aim", Windup = c.Windup, Time = c.Count * c.Gap })
	for i = 1, c.Count do
		task.delay(c.Windup + (i - 1) * c.Gap, function()
			if not S.stillValid(player, state, life) then
				return
			end
			local char, _, r = alive(S, player)
			local base = S.aim(aim, r)
			local yaw = math.rad((math.random() - 0.5) * 2 * c.Spread)
			local pitch = math.rad((math.random() - 0.5) * c.Spread)
			local dir = (CFrame.lookAt(Vector3.new(), base) * CFrame.Angles(pitch, yaw, 0)).LookVector
			S.fireRain(player, state, {
				Origin = S.origin(char, r, Moves.HAND),
				Direction = dir,
				Speed = c.Speed,
				Radius = c.Radius,
				Range = c.Range,
				OnHit = function(target, position)
					rainHit(S, player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Position = position, Source = "JodioBullet" })
				end,
			})
		end)
	end
end

---------------------------------------------------------------------------
-- 3: RAIN JET
---------------------------------------------------------------------------
local function rainJet(S, player, state, aim)
	local c = cfg.RainJet
	if not ready(S, player, state, "RainJet", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = flat(S.aim(aim, root))
	direction = direction.Magnitude > 0 and direction.Unit or flat(root.CFrame.LookVector).Unit
	local destination = Moves.safeStep(character, root, direction, c.Distance)
	if not destination then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "RainJet", c.Cooldown, 3)
	S.lock(state, c.Windup + c.Travel + 0.1)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "RainJet", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local from = r.Position
		local to = Moves.safeStep(char, r, direction, c.Distance) or destination
		local iframes = S.Adapter.Settings.IFrameAttribute
		char:SetAttribute(iframes, true)
		S.fx("Ability", { Character = char, Act = ACT, Move = "RainJet", Phase = "Jet", From = from, To = to, Direction = direction, Travel = c.Travel })
		-- Carried along the jet in steps.
		local steps = 6
		for i = 1, steps do
			task.delay(c.Travel * i / steps, function()
				if char.Parent and state.Life == life then
					local p = from:Lerp(to, i / steps)
					char:PivotTo(CFrame.lookAt(p, p + direction))
				end
				if i == steps then
					char:SetAttribute(iframes, nil)
				end
			end)
		end
		-- Anyone along the way is slammed aside.
		local mid = (from + to) / 2
		local box = CFrame.lookAt(mid, mid + direction)
		local size = Vector3.new(c.Width, 6, (to - from).Magnitude + 3)
		task.delay(c.Travel * 0.5, function()
			if not player.Character then
				return
			end
			for _, target in ipairs(S.Hitbox.inBox(player.Character, box, size, 6)) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr then
					local side = (box:Inverse() * tr.Position).X
					local away = box.RightVector * (side >= 0 and 1 or -1) + direction * 0.4
					rainHit(S, player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = away, Position = tr.Position, Source = "JodioJet" })
				end
			end
		end)
	end)
end

function Jodio.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		heavyRain(S, player, state, aim)
	elseif slot == 2 then
		rainBullets(S, player, state, aim)
	elseif slot == 3 then
		rainJet(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- NOVEMBER RAIN: TORRENT (ultimate)
---------------------------------------------------------------------------
function Jodio.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.2)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Charge", Windup = u.Windup })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Storm", Duration = u.Duration, Radius = u.Radius })
		local untilT = now() + u.Duration
		local function tick()
			local char, _, r = alive(S, player)
			if not r or state.Life ~= life or char ~= character then
				S.fx("Ultimate", { Character = character, Act = ACT, Phase = "End" })
				return
			end
			local victims = S.Hitbox.inRadius(char, r.Position, u.Radius, 12)
			if now() >= untilT then
				-- The rain comes down all at once.
				local hit = {}
				for _, target in ipairs(victims) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr and rainHit(S, player, target, { Damage = u.CrushDamage, Stun = u.CrushStun, Knockback = u.CrushKnockback, Direction = Vector3.new(0, -1, 0), Position = tr.Position, Source = "JodioCrush" }) then
						table.insert(hit, tr.Position)
					end
				end
				S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Crush", Position = r.Position, Radius = u.Radius, Hits = hit })
				return
			end
			for _, target in ipairs(victims) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr then
					press(S, target, u.Pressure, u.Tick + 0.1)
					rainHit(S, player, target, { Damage = u.Damage, Stun = u.Stun, Knockback = 0, Direction = Vector3.new(0, -1, 0), Position = tr.Position, Source = "JodioRain" })
				end
			end
			task.delay(u.Tick, tick)
		end
		tick()
	end)
end

function Jodio.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
	end
end

return Jodio
```
