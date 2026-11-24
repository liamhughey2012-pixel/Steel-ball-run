---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# DefenseService

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `DefenseService` (capitals matter) |

**What it does:** BLOCK and DASH for every character (players and Stand-user NPCs). BLOCK (hold F): sets the "Blocking" attribute; CombatAdapter then cuts damage, skips the stun and drains the guard bar (BlockMeter). Hits from behind aren't blocked. Starting a block just before a hit lands is a PERFECT BLOCK (no damage, the attacker is stunned). An empty guard bar is a GUARD BREAK (stunned, can't block for a few seconds). Attacking or dashing drops the block. The bar refills while you aren't blocking. DASH (Q): a short burst in the direction you're moving, with a moment you can't be hit. Two charges (chain them); each comes back after DashCooldown. A dash cancels the recovery after an M1 hit. Dash through an attack (it would have hit you) for a PERFECT DODGE: the charge comes back, the attacker is slowed, you get ultimate meter and your next hit within CounterTime does +40%. The server checks and grants it; the player's own client moves them (smooth, replicates to everyone). NPCs are moved by the server. Numbers: TuskConfig.Defense.

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **DefenseService**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	DefenseService  (ServerScriptService.SpinServer.DefenseService)

	BLOCK and DASH for every character (players and Stand-user NPCs).
	  BLOCK (hold F): sets the "Blocking" attribute; CombatAdapter then cuts
	    damage, skips the stun and drains the guard bar (BlockMeter). Hits from
	    behind aren't blocked. Starting a block just before a hit lands is a
	    PERFECT BLOCK (no damage, the attacker is stunned). An empty guard bar
	    is a GUARD BREAK (stunned, can't block for a few seconds). Attacking or
	    dashing drops the block. The bar refills while you aren't blocking.
	  DASH (Q): a short burst in the direction you're moving, with a moment
	    you can't be hit. Two charges (chain them); each comes back after
	    DashCooldown. A dash cancels the recovery after an M1 hit. Dash
	    through an attack (it would have hit you) for a PERFECT DODGE: the
	    charge comes back, the attacker is slowed, you get ultimate meter and
	    your next hit within CounterTime does +40%. The server checks and
	    grants it; the player's own client moves them (smooth, replicates to
	    everyone). NPCs are moved by the server.
	Numbers: TuskConfig.Defense.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)

local DefenseService = {}
local S -- TuskService
local cfg = TuskConfig.Defense or {}
local lastRelease = setmetatable({}, { __mode = "k" }) -- [character] = server time of the last block release

local function now()
	return workspace:GetServerTimeNow()
end

function DefenseService.isBlocking(character)
	return character ~= nil and character:GetAttribute(S.Adapter.Settings.BlockAttribute) == true
end

function DefenseService.release(player, state)
	local character = state and state.Character or (player and player.Character)
	if not character or not DefenseService.isBlocking(character) then
		return
	end
	character:SetAttribute(S.Adapter.Settings.BlockAttribute, nil)
	character:SetAttribute("BlockCanParry", nil)
	lastRelease[character] = now()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		S.Adapter.setMoveModifier(humanoid, "Block", nil)
	end
end

function DefenseService.block(player, state, on)
	local character, humanoid = S.Adapter.getAlive(player)
	if not character then
		return
	end
	if not on then
		DefenseService.release(player, state)
		return
	end
	if DefenseService.isBlocking(character) then
		return
	end
	if not S.Adapter.canAct(player) or state.Charging or S.isBusy(state) or state.Sneaking then
		return
	end
	if (character:GetAttribute("GuardBrokenUntil") or 0) > now() then
		S.tell(player, "Denied", { Reason = "GuardBroken" })
		return
	end
	local t = now()
	character:SetAttribute("BlockStart", t)
	-- Perfect blocks only count if this isn't block spam.
	character:SetAttribute("BlockCanParry", (t - (lastRelease[character] or -math.huge)) >= (cfg.ParryRetry or 0.6) or nil)
	if character:GetAttribute("BlockMeter") == nil then
		character:SetAttribute("BlockMeter", cfg.MaxMeter or 100)
	end
	character:SetAttribute(S.Adapter.Settings.BlockAttribute, true)
	S.Adapter.setMoveModifier(humanoid, "Block", cfg.BlockWalkSpeed or 0.45)
end

-- Dash charges per character: the server times each charge is ready again
-- (sorted). Shown to the HUD as DashReadyAt (next) and DashFullAt (all).
local charges = setmetatable({}, { __mode = "k" })

local function chargeList(character)
	local list = charges[character]
	if not list then
		list = {}
		for i = 1, (cfg.DashCharges or 2) do
			list[i] = 0
		end
		charges[character] = list
	end
	return list
end

local function publishCharges(character, list)
	table.sort(list)
	character:SetAttribute("DashReadyAt", list[1])
	character:SetAttribute("DashFullAt", list[#list])
	character:SetAttribute("DashCharges", #list)
end

-- Busy only because of an M1's recovery? Then a dash may cancel it.
local function onlyM1Recovery(state)
	return cfg.DashCancelM1 ~= false and state.M1LockUntil ~= nil and state.LockUntil <= state.M1LockUntil
end

function DefenseService.dash(player, state, direction)
	local character, _, root = S.Adapter.getAlive(player)
	if not character or typeof(direction) ~= "Vector3" or direction ~= direction then
		return
	end
	if not S.Adapter.canAct(player) or state.Charging or state.Sneaking then
		return
	end
	local cancel = false
	if S.isBusy(state) then
		if not onlyM1Recovery(state) then
			return
		end
		cancel = true
	end
	local t = now()
	local list = chargeList(character)
	table.sort(list)
	if list[1] > t then
		S.tell(player, "Denied", { Reason = "DashCooldown" })
		return
	end
	if t - (character:GetAttribute("LastDashAt") or -math.huge) < (cfg.DashGap or 0.3) then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	flat = flat.Unit
	DefenseService.release(player, state)
	if cancel then
		-- Dash-cancel: the M1 recovery is over, the combo starts again.
		state.LockUntil = os.clock()
		state.M1LockUntil = nil
		state.Combo = 0
	end
	-- Use a charge: it comes back DashCooldown after the last one queued.
	local cooldown = cfg.DashCooldown or 2.2
	table.remove(list, 1)
	table.insert(list, math.max(t, list[#list] or t) + cooldown)
	publishCharges(character, list)
	character:SetAttribute("LastDashAt", t)
	local iframes = S.Adapter.Settings.IFrameAttribute
	local token = tostring({})
	character:SetAttribute(iframes, true)
	character:SetAttribute("DashToken", token)
	character:SetAttribute("DashDodgeUntil", t + (cfg.PerfectDodgeWindow or 0.22))
	character:SetAttribute("DashDodged", nil)
	task.delay(cfg.DashIFrames or 0.22, function()
		if character:GetAttribute("DashToken") == token then
			character:SetAttribute(iframes, nil)
		end
	end)
	local speed, time = cfg.DashSpeed or 80, cfg.DashTime or 0.21
	S.fx("Dash", { Character = character, Direction = flat, Speed = speed, Time = time, Cancel = cancel })
	-- NPCs have no client to move them: the server does it.
	if typeof(player) ~= "Instance" then
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.MaxForce = math.huge
		velocity.VectorVelocity = flat * speed
		velocity.Parent = attachment
		game:GetService("Debris"):AddItem(attachment, time)
	end
end

-- PERFECT DODGE: an attack that would have hit landed during the dash.
local function onPerfectDodge(character, attackerPlayer)
	local t = now()
	-- The dash charge comes back.
	if cfg.PerfectDodgeRefund ~= false then
		local list = chargeList(character)
		table.sort(list)
		list[#list] = math.min(list[#list], t)
		publishCharges(character, list)
	end
	-- The next hit within CounterTime lands harder.
	character:SetAttribute("CounterUntil", t + (cfg.CounterTime or 1.5))
	-- Ultimate meter (players and NPCs).
	local owner = Players:GetPlayerFromCharacter(character)
	if not owner then
		for p, st in pairs(S.States or {}) do
			if st.Character == character then
				owner = p
			end
		end
	end
	if owner and S.addUlt then
		S.addUlt(owner, cfg.PerfectDodgeUlt or 8)
	end
	-- The attacker stumbles: slowed for a moment.
	local attacker = attackerPlayer and attackerPlayer.Character
	local ah = attacker and attacker:FindFirstChildOfClass("Humanoid")
	if ah then
		local token = tostring({})
		attacker:SetAttribute("DodgedSlowToken", token)
		S.Adapter.setMoveModifier(ah, "Dodged", cfg.PerfectDodgeSlow or 0.5)
		task.delay(cfg.PerfectDodgeSlowTime or 0.8, function()
			if ah.Parent and attacker:GetAttribute("DodgedSlowToken") == token then
				S.Adapter.setMoveModifier(ah, "Dodged", nil)
				attacker:SetAttribute("DodgedSlowToken", nil)
			end
		end)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	S.fx("PerfectDodge", { Character = character, Attacker = attacker, Position = root and root.Position, Counter = cfg.CounterTime or 1.5 })
end

-- Guard bars refill while not blocking.
local function regen(dt)
	local max = cfg.MaxMeter or 100
	local t = now()
	local function tick(character)
		local meter = character and character:GetAttribute("BlockMeter")
		if meter and meter < max and not DefenseService.isBlocking(character) and t - (character:GetAttribute("LastBlockHit") or 0) >= (cfg.RegenDelay or 1.2) then
			local nextValue = math.min(max, meter + (cfg.MeterRegen or 30) * dt)
			character:SetAttribute("BlockMeter", nextValue >= max and nil or nextValue)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		tick(player.Character)
	end
	for _, model in ipairs(CollectionService:GetTagged("SpinFighter")) do
		tick(model)
	end
end

function DefenseService.init(TuskService)
	S = TuskService
	if S.Adapter.on then
		S.Adapter.on("PerfectDodge", onPerfectDodge)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc >= 0.1 then
			regen(acc)
			acc = 0
		end
	end)
end

return DefenseService
```
