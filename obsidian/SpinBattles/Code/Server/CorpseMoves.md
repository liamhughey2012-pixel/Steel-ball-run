---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# CorpseMoves

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `CorpseMoves` (capitals matter) |

**What it does:** Every character's CORPSE MOVE (V), unlocked while holding a Saint's Corpse part. One shared cooldown (TuskConfig.Corpse.Move.Cooldown); the ready time is the character attribute CorpseReadyAt (server time) for the HUD. Visuals: CorpseClient, from WorldFX "CorpseMove". Johnny       GOLDEN SPIN NAIL: a huge golden spinning nail Gyro         GOLDEN RECTANGLE: a spinning shockwave straight ahead Diego        DINOSAUR CRASH: leaps to the aim point and slams down Pork Pie     HOOK HARVEST: hooks yank everyone round him in Sandman      SOUND BARRIER: dashes through enemies, then a blast Mountain Tim LASSO CYCLONE: a spinning lasso pulls everyone in Hot Pants    FLESH COCOON: heals and armours herself, then a burst Blackmore    RAIN CURTAIN: a cone of frozen drops that cut and slow Axl RO       GUILT FLOOD: guilt for everyone round him, and a hit Valentine    CORPSE BLESSING: a few seconds untouchable, a heal, a pulse All damage goes through S.hit (CombatAdapter).

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **CorpseMoves**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	CorpseMoves  (ServerScriptService.SpinServer.CorpseMoves)

	Every character's CORPSE MOVE (V), unlocked while holding a Saint's
	Corpse part. One shared cooldown (TuskConfig.Corpse.Move.Cooldown); the
	ready time is the character attribute CorpseReadyAt (server time) for
	the HUD. Visuals: CorpseClient, from WorldFX "CorpseMove".
	  Johnny       GOLDEN SPIN NAIL: a huge golden spinning nail
	  Gyro         GOLDEN RECTANGLE: a spinning shockwave straight ahead
	  Diego        DINOSAUR CRASH: leaps to the aim point and slams down
	  Pork Pie     HOOK HARVEST: hooks yank everyone round him in
	  Sandman      SOUND BARRIER: dashes through enemies, then a blast
	  Mountain Tim LASSO CYCLONE: a spinning lasso pulls everyone in
	  Hot Pants    FLESH COCOON: heals and armours herself, then a burst
	  Blackmore    RAIN CURTAIN: a cone of frozen drops that cut and slow
	  Axl RO       GUILT FLOOD: guilt for everyone round him, and a hit
	  Valentine    CORPSE BLESSING: a few seconds untouchable, a heal, a pulse
	All damage goes through S.hit (CombatAdapter).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local Registry = require(Shared.TuskActRegistry)
local Net = require(Shared.Net)
local Moves = require(script.Parent.TuskMoves)

local CorpseMoves = {}

local TuskConfig = require(Shared.TuskConfig)
CorpseMoves.Names = TuskConfig.Corpse.MoveNames

local WorldFX
local function fx(data)
	WorldFX = WorldFX or Net.get("WorldFX")
	WorldFX:FireAllClients("CorpseMove", data)
end

local function now()
	return workspace:GetServerTimeNow()
end

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

-- Everyone in range (pulled toward `center` when pull is set).
local function around(S, player, center, radius, info, pull)
	local character = player.Character
	local count = 0
	for _, target in ipairs(S.Hitbox.inRadius(character, center, radius, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			local hitInfo = table.clone(info)
			hitInfo.Position = tr.Position
			hitInfo.Direction = pull and (center - tr.Position) or (tr.Position - center)
			if S.hit(player, target, hitInfo) then
				count = count + 1
			end
		end
	end
	return count
end

local USE = {}

USE.Johnny = function(S, player, state, character, root, aim)
	local dir = S.aim(aim, root)
	S.lock(state, 0.4)
	fx({ Character = character, Who = "Johnny", Phase = "Cast", Direction = dir })
	task.delay(0.2, function()
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		Moves.nail(S, player, state, {
			Origin = S.origin(char, r, Moves.HAND), Direction = dir, Speed = 210, Radius = 1.7, Range = 220,
			Style = "Spinning", Charge = 1, Damage = 15, Stun = 0.6, Knockback = 45, Launch = 12, Source = "CorpseNail",
		})
	end)
end

USE.Gyro = function(S, player, state, character, root, aim)
	local dir = Moves.flat(S.aim(aim, root))
	S.lock(state, 0.5)
	fx({ Character = character, Who = "Gyro", Phase = "Cast", Position = root.Position, Direction = dir, Length = 34 })
	task.delay(0.25, function()
		local _, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		local mid = r.Position + dir * 17
		Moves.boxHit(S, player, CFrame.lookAt(mid, mid + dir), Vector3.new(7, 7, 34), { Damage = 13, Stun = 0.7, Knockback = 35, Launch = 16, Direction = dir, Source = "CorpseSpin" }, 6)
	end)
end

USE.Diego = function(S, player, state, character, root, aim)
	local dir = Moves.flat(S.aim(aim, root))
	local to = Moves.safeStep(character, root, dir, 30) or root.Position
	S.lock(state, 0.7)
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	fx({ Character = character, Who = "Diego", Phase = "Leap", From = root.Position, To = to, Time = 0.45 })
	task.delay(0.45, function()
		character:SetAttribute(iframes, nil)
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		char:PivotTo(CFrame.lookAt(to, to + dir))
		around(S, player, to, 10, { Damage = 12, Stun = 0.7, Knockback = 30, Launch = 18, Source = "CorpseCrash" })
		fx({ Character = char, Who = "Diego", Phase = "Slam", Position = to, Radius = 10 })
	end)
end

USE.PorkPie = function(S, player, state, character, root)
	S.lock(state, 0.5)
	fx({ Character = character, Who = "PorkPie", Phase = "Cast", Position = root.Position, Radius = 20 })
	task.delay(0.3, function()
		local _, _, r = S.Adapter.getAlive(player)
		if r then
			around(S, player, r.Position, 20, { Damage = 11, Stun = 1.0, Knockback = 45, Source = "CorpseHooks" }, true)
		end
	end)
end

USE.Sandman = function(S, player, state, character, root, aim)
	local dir = Moves.flat(S.aim(aim, root))
	local to = Moves.safeStep(character, root, dir, 36)
	if not to then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return false
	end
	local from = root.Position
	S.lock(state, 0.5)
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	fx({ Character = character, Who = "Sandman", Phase = "Dash", From = from, To = to })
	task.delay(0.2, function()
		character:SetAttribute(iframes, nil)
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		char:PivotTo(CFrame.lookAt(to, to + dir))
		local mid = (from + to) / 2
		Moves.boxHit(S, player, CFrame.lookAt(mid, to), Vector3.new(7, 7, (to - from).Magnitude + 2), { Damage = 9, Stun = 0.6, Knockback = 10, Direction = dir, Source = "CorpseSound" }, 6)
		task.delay(0.45, function()
			around(S, player, mid, 9, { Damage = 6, Stun = 0.6, Knockback = 30, Launch = 18, Source = "CorpseSound" })
			fx({ Character = char, Who = "Sandman", Phase = "Boom", Position = mid })
		end)
	end)
end

USE.MountainTim = function(S, player, state, character, root)
	S.lock(state, 0.8)
	fx({ Character = character, Who = "MountainTim", Phase = "Spin", Position = root.Position, Radius = 14, Time = 0.8 })
	for i = 1, 3 do
		task.delay(i * 0.25, function()
			local _, _, r = S.Adapter.getAlive(player)
			if r then
				around(S, player, r.Position, 14, { Damage = 4, Stun = 0.5, Knockback = 25, Source = "CorpseLasso" }, true)
			end
		end)
	end
end

USE.HotPants = function(S, player, state, character, root)
	local _, humanoid = S.Adapter.getAlive(player)
	S.lock(state, 0.5)
	character:SetAttribute("Armored", true)
	fx({ Character = character, Who = "HotPants", Phase = "Cocoon", Position = root.Position, Time = 2 })
	for i = 1, 5 do
		task.delay(i * 0.3, function()
			if humanoid.Parent and humanoid.Health > 0 then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 6)
			end
		end)
	end
	task.delay(2, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		local _, _, r = S.Adapter.getAlive(player)
		if r then
			around(S, player, r.Position, 9, { Damage = 7, Stun = 0.6, Knockback = 30, Launch = 10, Source = "CorpseFlesh" })
			fx({ Character = character, Who = "HotPants", Phase = "Burst", Position = r.Position })
		end
	end)
end

USE.Blackmore = function(S, player, state, character, root, aim)
	local dir = Moves.flat(S.aim(aim, root))
	S.lock(state, 0.5)
	fx({ Character = character, Who = "Blackmore", Phase = "Curtain", Position = root.Position, Direction = dir, Range = 26, Cone = 70 })
	task.delay(0.3, function()
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		local cosLimit = math.cos(math.rad(35))
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, 26, 8)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			local off = tr and Vector3.new(tr.Position.X - r.Position.X, 0, tr.Position.Z - r.Position.Z)
			if tr and (off.Magnitude < 1 or off.Unit:Dot(dir) >= cosLimit) then
				if S.hit(player, target, { Damage = 12, Stun = 0.6, Knockback = 12, Direction = dir, Position = tr.Position, Source = "CorpseRain" }) then
					slow(S, target, "CorpseRain", 0.6, 2)
				end
			end
		end
	end)
end

USE.Axl = function(S, player, state, character, root)
	S.lock(state, 0.5)
	fx({ Character = character, Who = "Axl", Phase = "Flood", Position = root.Position, Radius = 22 })
	task.delay(0.3, function()
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, 22, 8)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.hit(player, target, { Damage = 8, Stun = 0.6, Knockback = 8, Direction = tr.Position - r.Position, Position = tr.Position, Source = "CorpseGuilt" }) then
				-- +2 guilt (the same stacks Axl's moves feed on).
				local g = math.min(5, (target:GetAttribute("Guilt") or 0) + 2)
				target:SetAttribute("Guilt", g)
				target:SetAttribute("GuiltAt", os.clock())
				S.fx("Ability", { Act = 12, Move = "Guilt", Phase = "Mark", Target = target, Stacks = g })
			end
		end
	end)
end

USE.Valentine = function(S, player, state, character, root)
	local _, humanoid = S.Adapter.getAlive(player)
	S.lock(state, 0.3)
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 15)
	fx({ Character = character, Who = "Valentine", Phase = "Bless", Position = root.Position, Time = 2.5 })
	task.delay(2.5, function()
		if character.Parent then
			character:SetAttribute(iframes, nil)
		end
		local _, _, r = S.Adapter.getAlive(player)
		if r then
			around(S, player, r.Position, 12, { Damage = 9, Stun = 0.6, Knockback = 35, Source = "CorpseLight" })
			fx({ Character = character, Who = "Valentine", Phase = "Pulse", Position = r.Position, Radius = 12 })
		end
	end)
end

function CorpseMoves.use(S, player, state, aim, cfg)
	local character, _, root = S.Adapter.getAlive(player)
	if not character or not state.Act or S.isBusy(state) or state.Charging or not S.Adapter.canAct(player) then
		return
	end
	if (character:GetAttribute("CorpseReadyAt") or 0) > now() then
		S.tell(player, "Denied", { Reason = "Cooldown" })
		return
	end
	local who = Registry.characterOf(state.Act)
	local fn = USE[who]
	if not fn then
		return
	end
	if fn(S, player, state, character, root, aim) == false then
		return
	end
	character:SetAttribute("CorpseReadyAt", now() + (cfg and cfg.Cooldown or 20))
end

return CorpseMoves
```
