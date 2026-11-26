--[[
	CombatAdapter  (ServerScriptService.SpinServer.CombatAdapter)

	THE ONE PLACE the Spin system touches combat. If SPIN BATTLEGROUNDS
	already has a combat framework (damage, stun, block), plug it into the
	Hooks table below instead of letting this file use its defaults. That
	way there is never a second, competing combat system.

	Example (in your own server code, before players join):
		local Adapter = require(ServerScriptService.SpinServer.CombatAdapter)
		Adapter.Hooks.ApplyDamage = function(attacker, humanoid, amount, info)
			YourCombat.Damage(attacker, humanoid, amount)
		end
		Adapter.Hooks.IsBlocking = function(character)
			return YourCombat.IsBlocking(character)
		end
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Net = require(game:GetService("ReplicatedStorage").SpinShared.Net)
local TuskConfig = require(game:GetService("ReplicatedStorage").SpinShared.TuskConfig)
local FX = Net.get("SpinFX")

local Adapter = {}

Adapter.Settings = {
	FriendlyFire = false, -- same-Team players can't hit each other
	BlockAttribute = "Blocking", -- character attribute your block sets
	BlockDamageMultiplier = 0.35,
	BlockKnockbackMultiplier = 0.3,
	IFrameAttribute = "IFrames", -- character attribute = invulnerable (dashes etc.)
	ArmorAttribute = "Armored", -- character attribute = takes damage but no stun/knockback (ult wind-ups)
	MaxKnockback = 90, -- hard cap so no move can fling players across the map
	MaxStun = 1.0, -- hard cap on any single stun
	StunAttribute = "Stunned",
	StunWalkSpeedMultiplier = 0.15,
	StunImmunityAfter = 0.5, -- seconds after a stun ends where no new stun applies
	KnockbackDuration = 0.18,
}

-- Optional overrides. Leave nil to use the defaults in this file.
Adapter.Hooks = {
	ApplyDamage = nil, -- function(attackerPlayer, humanoid, amount, info)
	ApplyStun = nil, -- function(humanoid, duration) -> applied:boolean
	IsBlocking = nil, -- function(character) -> boolean
	CanAct = nil, -- function(player) -> boolean (extra checks: ragdoll, menus...)
	CanBeHit = nil, -- function(attackerPlayer, targetCharacter) -> boolean
}

local moveMods = setmetatable({}, { __mode = "k" }) -- humanoid -> { mods = {}, product = 1 }
local stunState = setmetatable({}, { __mode = "k" }) -- humanoid -> { token, immuneUntil }

function Adapter.getAlive(player)
	local character = player and player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end
	return character, humanoid, root
end

function Adapter.isStunned(character)
	return character:GetAttribute(Adapter.Settings.StunAttribute) == true
end

function Adapter.canAct(player)
	local character = Adapter.getAlive(player)
	if not character then
		return false
	end
	if Adapter.isStunned(character) then
		return false
	end
	-- Turned into Diego's dinosaur (Scary Monsters): Diego is in control.
	if character:GetAttribute("DinoThrall") then
		return false
	end
	-- Frozen in stopped time (The World): can't do anything until it moves again.
	if character:GetAttribute("TimeStopped") then
		return false
	end
	if Adapter.Hooks.CanAct and not Adapter.Hooks.CanAct(player) then
		return false
	end
	return true
end

function Adapter.canBeHit(attackerPlayer, targetCharacter)
	if not targetCharacter or (attackerPlayer and targetCharacter == attackerPlayer.Character) then
		return false
	end
	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	if targetCharacter:GetAttribute(Adapter.Settings.IFrameAttribute) == true then
		return false
	end
	if targetCharacter:FindFirstChildOfClass("ForceField") then
		return false
	end
	-- Diego can't hurt the dinosaur he is commanding.
	if attackerPlayer and targetCharacter:GetAttribute("DinoThrall") == attackerPlayer.UserId then
		return false
	end
	if not Adapter.Settings.FriendlyFire and attackerPlayer then
		local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
		if targetPlayer and not attackerPlayer.Neutral and not targetPlayer.Neutral and targetPlayer.Team == attackerPlayer.Team then
			return false
		end
	end
	if Adapter.Hooks.CanBeHit and not Adapter.Hooks.CanBeHit(attackerPlayer, targetCharacter) then
		return false
	end
	return true
end

-- Stackable walk-speed multipliers keyed by source ("SpinCharge", "Stun"...).
function Adapter.setMoveModifier(humanoid, key, multiplier)
	local state = moveMods[humanoid]
	if not state then
		state = { mods = {}, product = 1, base = humanoid.WalkSpeed }
		moveMods[humanoid] = state
	end
	-- Work the base speed back out (other scripts may have changed WalkSpeed),
	-- but never from a x0 modifier (0 / 0 would lose it for good: you'd be
	-- stuck at 0 or NaN speed after John Rod's steering or snare ended).
	local base = state.base or 16
	if state.product > 1e-3 then
		local derived = humanoid.WalkSpeed / state.product
		if derived == derived and derived < math.huge then
			base = derived
		end
	end
	state.base = base
	state.mods[key] = multiplier
	local product = 1
	for _, m in pairs(state.mods) do
		product = product * m
	end
	state.product = product
	humanoid.WalkSpeed = base * product
end

-- True when the hit comes from in front of the target (blocks only face forward).
function Adapter.isFrontal(attackerPlayer, targetCharacter, info)
	local d = TuskConfig.Defense or {}
	if d.FrontOnly == false then
		return true
	end
	local root = targetCharacter:FindFirstChild("HumanoidRootPart")
	local attacker = attackerPlayer and attackerPlayer.Character
	local from = attacker and attacker:FindFirstChild("HumanoidRootPart")
	local source = from and from.Position or (info and info.Position)
	if not root or not source then
		return true
	end
	local offset = Vector3.new(source.X - root.Position.X, 0, source.Z - root.Position.Z)
	if offset.Magnitude < 0.5 then
		return true
	end
	return root.CFrame.LookVector:Dot(offset.Unit) >= -0.1
end

function Adapter.isBlocking(character)
	if Adapter.Hooks.IsBlocking then
		return Adapter.Hooks.IsBlocking(character) == true
	end
	return character:GetAttribute(Adapter.Settings.BlockAttribute) == true
end

function Adapter.applyStun(humanoid, duration)
	duration = math.min(duration, Adapter.Settings.MaxStun)
	if duration <= 0 then
		return false
	end
	if humanoid.Parent and humanoid.Parent:GetAttribute(Adapter.Settings.ArmorAttribute) == true then
		return false
	end
	if Adapter.Hooks.ApplyStun then
		return Adapter.Hooks.ApplyStun(humanoid, duration)
	end
	local character = humanoid.Parent
	local state = stunState[humanoid] or { token = 0, immuneUntil = 0 }
	stunState[humanoid] = state
	local now = os.clock()
	if now < state.immuneUntil and not Adapter.isStunned(character) then
		return false -- anti stun-lock
	end
	state.token = state.token + 1
	local token = state.token
	character:SetAttribute(Adapter.Settings.StunAttribute, true)
	Adapter.setMoveModifier(humanoid, "Stun", Adapter.Settings.StunWalkSpeedMultiplier)
	task.delay(duration, function()
		if state.token ~= token or not humanoid.Parent then
			return
		end
		character:SetAttribute(Adapter.Settings.StunAttribute, nil)
		Adapter.setMoveModifier(humanoid, "Stun", nil)
		state.immuneUntil = os.clock() + Adapter.Settings.StunImmunityAfter
	end)
	return true
end

function Adapter.applyKnockback(character, direction, strength, upward)
	local root = character:FindFirstChild("HumanoidRootPart")
	strength = math.min(strength or 0, Adapter.Settings.MaxKnockback)
	upward = upward or strength * 0.3
	if not root or (strength <= 0 and upward <= 0) then
		return
	end
	if character:GetAttribute(Adapter.Settings.ArmorAttribute) == true then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		flat = -root.CFrame.LookVector
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "SpinKnockback"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = flat.Unit * strength + Vector3.new(0, math.min(upward, Adapter.Settings.MaxKnockback), 0)
	velocity.Parent = attachment
	Debris:AddItem(attachment, Adapter.Settings.KnockbackDuration)
end

--[[
	dealHit: the only entry point for Spin damage. Server only.
	info = { Damage, Stun, Knockback, Launch?, Direction, Position, Level, Perfect, Source }
	Returns: hit:boolean, damageDealt:number
]]
-- Counter-dodges (e.g. Mountain Tim's Split Dodge): while the target has
-- the attribute, an incoming hit is cancelled and the handler runs instead.
-- Adapter.DodgeHandlers[attributeName] = function(attackerPlayer, target, info)
Adapter.DodgeHandlers = {}

-- Simple events other systems listen to (bounty jobs, the dash):
--   "Hit" (attackerPlayer, target, damage, info)
--   "PerfectBlock" (defenderCharacter, attackerPlayer)
--   "PerfectDodge" (dodgerCharacter, attackerPlayer)
Adapter.Listeners = {}
function Adapter.on(name, fn)
	Adapter.Listeners[name] = Adapter.Listeners[name] or {}
	table.insert(Adapter.Listeners[name], fn)
end
function Adapter.emit(name, ...)
	for _, fn in ipairs(Adapter.Listeners[name] or {}) do
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[CombatAdapter] " .. name .. " listener: " .. tostring(err))
		end
	end
end

function Adapter.dealHit(attackerPlayer, targetCharacter, info)
	if targetCharacter and attackerPlayer and targetCharacter ~= attackerPlayer.Character then
		for attribute, handler in pairs(Adapter.DodgeHandlers) do
			if targetCharacter:GetAttribute(attribute) then
				pcall(handler, attackerPlayer, targetCharacter, info)
				return false
			end
		end
	end
	-- PERFECT DODGE: an attack that would have hit lands during a dash's
	-- dodge window (once per dash).
	if attackerPlayer and targetCharacter and targetCharacter ~= attackerPlayer.Character
		and (targetCharacter:GetAttribute("DashDodgeUntil") or 0) > workspace:GetServerTimeNow()
		and not targetCharacter:GetAttribute("DashDodged") then
		targetCharacter:SetAttribute("DashDodged", true)
		Adapter.emit("PerfectDodge", targetCharacter, attackerPlayer)
		return false
	end
	if not Adapter.canBeHit(attackerPlayer, targetCharacter) then
		return false
	end
	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	-- (info.Unblockable: e.g. Soft & Wet's Go Beyond goes straight through a guard.)
	local blocked = not info.Unblockable and Adapter.isBlocking(targetCharacter) and Adapter.isFrontal(attackerPlayer, targetCharacter, info)
	local s = Adapter.Settings
	local d = TuskConfig.Defense or {}
	local guardBreak = false
	if blocked then
		local now = workspace:GetServerTimeNow()
		local start = targetCharacter:GetAttribute("BlockStart")
		-- PERFECT BLOCK: no damage, the attacker is stunned.
		if attackerPlayer and start and now - start <= (d.ParryWindow or 0.2) and targetCharacter:GetAttribute("BlockCanParry") then
			targetCharacter:SetAttribute("BlockCanParry", nil)
			local attacker = attackerPlayer.Character
			local ah = attacker and attacker:FindFirstChildOfClass("Humanoid")
			if ah then
				Adapter.applyStun(ah, d.ParryStun or 1)
				local ar = attacker:FindFirstChild("HumanoidRootPart")
				local tr = targetCharacter:FindFirstChild("HumanoidRootPart")
				if ar and tr then
					Adapter.applyKnockback(attacker, ar.Position - tr.Position, 22, 6)
				end
			end
			FX:FireAllClients("Parry", { Defender = targetCharacter, Attacker = attacker, Position = info.Position })
			Adapter.emit("PerfectBlock", targetCharacter, attackerPlayer)
			return false
		end
		-- The guard bar takes the hit; when it runs out the guard breaks.
		local meter = (targetCharacter:GetAttribute("BlockMeter") or d.MaxMeter or 100) - info.Damage * (d.MeterPerDamage or 4)
		targetCharacter:SetAttribute("BlockMeter", math.max(meter, 0))
		targetCharacter:SetAttribute("LastBlockHit", now)
		if meter <= 0 then
			guardBreak = true
			blocked = false
			targetCharacter:SetAttribute(s.BlockAttribute, nil)
			targetCharacter:SetAttribute("GuardBrokenUntil", now + (d.GuardBreakLockout or 3))
			Adapter.setMoveModifier(humanoid, "Block", nil)
		end
	end

	local damage = info.Damage * (blocked and s.BlockDamageMultiplier or 1)
	-- Saint's Corpse boosts: the attacker's damage, the target's resistance.
	local attackerCharacter = attackerPlayer and attackerPlayer.Character
	if attackerCharacter then
		damage = damage * (attackerCharacter:GetAttribute("CorpseDamage") or 1)
		-- Ambush out of sneak: the first hit lands harder (used up).
		if (attackerCharacter:GetAttribute("AmbushUntil") or 0) > workspace:GetServerTimeNow() then
			attackerCharacter:SetAttribute("AmbushUntil", nil)
			damage = damage * ((TuskConfig.Sneak and TuskConfig.Sneak.AmbushMultiplier) or 1.5)
			info.Ambush = true
		end
		-- Counter after a perfect dodge: the next hit lands harder (used up).
		if (attackerCharacter:GetAttribute("CounterUntil") or 0) > workspace:GetServerTimeNow() then
			attackerCharacter:SetAttribute("CounterUntil", nil)
			damage = damage * ((TuskConfig.Defense and TuskConfig.Defense.CounterMultiplier) or 1.4)
			info.Counter = true
		end
	end
	damage = damage * (targetCharacter:GetAttribute("CorpseResist") or 1)
	-- Bounty-board shop: Rye Whiskey (hit harder), Leather Duster (take less).
	local shopNow = workspace:GetServerTimeNow()
	if attackerCharacter and (attackerCharacter:GetAttribute("ShopDamageUntil") or 0) > shopNow then
		damage = damage * (attackerCharacter:GetAttribute("ShopDamage") or 1)
	end
	if (targetCharacter:GetAttribute("ShopResistUntil") or 0) > shopNow then
		damage = damage * (targetCharacter:GetAttribute("ShopResist") or 1)
	end
	-- The Requiem Arrow's blessing.
	if attackerCharacter and (attackerCharacter:GetAttribute("ArrowBlessUntil") or 0) > shopNow then
		damage = damage * (attackerCharacter:GetAttribute("ArrowDamage") or 1)
	end
	if (targetCharacter:GetAttribute("ArrowBlessUntil") or 0) > shopNow then
		damage = damage * (targetCharacter:GetAttribute("ArrowResist") or 1)
	end
	local knockback = info.Knockback * (blocked and s.BlockKnockbackMultiplier or 1)

	-- Who hit them last (kill credit for bounties and kill streaks).
	if attackerPlayer then
		targetCharacter:SetAttribute("LastAttackerId", attackerPlayer.UserId)
		targetCharacter:SetAttribute("LastAttackTime", workspace:GetServerTimeNow())
	end
	if Adapter.Hooks.ApplyDamage then
		Adapter.Hooks.ApplyDamage(attackerPlayer, humanoid, damage, info)
	else
		humanoid:TakeDamage(damage)
	end
	if guardBreak then
		Adapter.applyStun(humanoid, math.max(info.Stun or 0, d.GuardBreakStun or 1))
		FX:FireAllClients("GuardBreak", { Victim = targetCharacter, Position = info.Position })
	elseif not blocked then
		Adapter.applyStun(humanoid, info.Stun or 0)
	end
	local launch = info.Launch and info.Launch * (blocked and s.BlockKnockbackMultiplier or 1) or nil
	Adapter.applyKnockback(targetCharacter, info.Direction, knockback, launch)

	FX:FireAllClients("Hit", {
		Position = info.Position,
		Level = info.Level,
		Perfect = info.Perfect,
		Blocked = blocked,
		Victim = targetCharacter,
		Source = info.Source,
		AttackerId = attackerPlayer and attackerPlayer.UserId or 0,
	})
	if attackerPlayer and typeof(attackerPlayer) == "Instance" then
		FX:FireClient(attackerPlayer, "Damage", {
			Position = info.Position,
			Amount = math.floor(damage + 0.5),
			Blocked = blocked,
			Perfect = info.Perfect,
		})
	end
	Adapter.emit("Hit", attackerPlayer, targetCharacter, damage, info)
	return true, damage
end

return Adapter
