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
	    you can't be hit. The server checks the cooldown and grants it; the
	    player's own client moves them (smooth, replicates to everyone).
	    NPCs are moved by the server.
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
local dashReady = setmetatable({}, { __mode = "k" }) -- [player] = os.clock() when the next dash is allowed
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

function DefenseService.dash(player, state, direction)
	local character, _, root = S.Adapter.getAlive(player)
	if not character or typeof(direction) ~= "Vector3" or direction ~= direction then
		return
	end
	if not S.Adapter.canAct(player) or state.Charging or S.isBusy(state) or state.Sneaking then
		return
	end
	local clock = os.clock()
	if (dashReady[player] or 0) > clock then
		S.tell(player, "Denied", { Reason = "DashCooldown" })
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	flat = flat.Unit
	DefenseService.release(player, state)
	local cooldown = cfg.DashCooldown or 2.2
	dashReady[player] = clock + cooldown
	character:SetAttribute("DashReadyAt", now() + cooldown)
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	task.delay(cfg.DashIFrames or 0.2, function()
		character:SetAttribute(iframes, nil)
	end)
	local speed, time = cfg.DashSpeed or 75, cfg.DashTime or 0.2
	S.fx("Dash", { Character = character, Direction = flat, Speed = speed, Time = time })
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
