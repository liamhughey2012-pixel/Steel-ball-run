---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# CombatAdapter

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `CombatAdapter` (capitals matter) |

**What it does:** THE ONE PLACE the Spin system touches combat. If SPIN BATTLEGROUNDS already has a combat framework (damage, stun, block), plug it into the Hooks table below instead of letting this file use its defaults. That way there is never a second, competing combat system.

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **CombatAdapter**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
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
		state = { mods = {}, product = 1 }
		moveMods[humanoid] = state
	end
	local base = humanoid.WalkSpeed / state.product
	state.mods[key] = multiplier
	local product = 1
	for _, m in pairs(state.mods) do
		product = product * m
	end
	state.product = product
	humanoid.WalkSpeed = base * product
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
function Adapter.dealHit(attackerPlayer, targetCharacter, info)
	if not Adapter.canBeHit(attackerPlayer, targetCharacter) then
		return false
	end
	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	local blocked = Adapter.isBlocking(targetCharacter)
	local s = Adapter.Settings

	local damage = info.Damage * (blocked and s.BlockDamageMultiplier or 1)
	local knockback = info.Knockback * (blocked and s.BlockKnockbackMultiplier or 1)

	if Adapter.Hooks.ApplyDamage then
		Adapter.Hooks.ApplyDamage(attackerPlayer, humanoid, damage, info)
	else
		humanoid:TakeDamage(damage)
	end
	if not blocked then
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
	if attackerPlayer then
		FX:FireClient(attackerPlayer, "Damage", {
			Position = info.Position,
			Amount = math.floor(damage + 0.5),
			Blocked = blocked,
			Perfect = info.Perfect,
		})
	end
	return true, damage
end

return Adapter
```
