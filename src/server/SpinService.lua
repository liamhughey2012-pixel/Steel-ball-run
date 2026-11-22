--[[
	SpinService  (ServerScriptService.SpinServer.SpinService)

	Server authority for the charge-based Golden Spin throw.

	Flow:
	  client "Start"            -> validate, mark charging, slow the player,
	                               set character attribute SpinChargeStart
	                               (every client reads it to draw the charge)
	  client "Release", aimDir  -> server measures charge time itself,
	                               picks the level, starts the cooldown,
	                               fires a server projectile
	  "Cancel" / stun / death   -> charge ends, short cooldown

	The client never sends damage, level, position or timing. It only sends
	"I pressed" / "I let go" and an aim direction, which is sanitised.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").SpinShared
local SpinConfig = require(Shared.SpinConfig)
local Net = require(Shared.Net)
local Adapter = require(script.Parent.CombatAdapter)
local Cooldowns = require(script.Parent.CooldownService)
local Projectiles = require(script.Parent.ProjectileService)

local Request = Net.get("SpinRequest")
local FX = Net.get("SpinFX")

local SpinService = {}

local COOLDOWN_KEY = "GoldenSpin"
local RATE_LIMIT = 10 -- requests per second per player

local states = {} -- [player] = { Charging, Start, Token, Humanoid, Character }
local rate = {} -- [player] = { WindowStart, Count }

local function rateLimited(player)
	local r = rate[player]
	local now = os.clock()
	if not r or now - r.WindowStart >= 1 then
		rate[player] = { WindowStart = now, Count = 1 }
		return false
	end
	r.Count = r.Count + 1
	return r.Count > RATE_LIMIT
end

local function tell(player, status, data)
	data = data or {}
	data.Status = status
	FX:FireClient(player, "SpinState", data)
end

local function sanitizeAim(aim, root)
	local fallback = root.CFrame.LookVector
	if typeof(aim) ~= "Vector3" then
		return fallback
	end
	if aim.X ~= aim.X or aim.Y ~= aim.Y or aim.Z ~= aim.Z then
		return fallback -- NaN
	end
	if aim.Magnitude < 1e-3 or aim.Magnitude > 1e4 then
		return fallback
	end
	local unit = aim.Unit
	local maxPitch = SpinConfig.Projectile.MaxAimPitch
	local y = math.clamp(unit.Y, -maxPitch, maxPitch)
	local flat = Vector3.new(unit.X, 0, unit.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(fallback.X, 0, fallback.Z)
	end
	flat = flat.Unit * math.sqrt(1 - y * y)
	return Vector3.new(flat.X, y, flat.Z).Unit
end

-- Throw origin is computed by the server and line-of-sight checked, so a
-- player standing against a wall can't spawn the ball on the other side.
local function throwOrigin(character, root)
	local desired = (root.CFrame * SpinConfig.Projectile.SpawnOffset).Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local offset = desired - root.Position
	if workspace:Raycast(root.Position, offset, params) then
		return root.Position
	end
	return desired
end

local function endCharge(player)
	local state = states[player]
	if not state then
		return nil
	end
	states[player] = nil
	if state.Humanoid and state.Humanoid.Parent then
		Adapter.setMoveModifier(state.Humanoid, "SpinCharge", nil)
	end
	if state.Character and state.Character.Parent then
		state.Character:SetAttribute("SpinChargeStart", nil)
	end
	return state
end

function SpinService.cancel(player, reason)
	local state = endCharge(player)
	if state then
		Cooldowns.start(player, COOLDOWN_KEY, SpinConfig.Charge.CancelCooldown)
		tell(player, "Cancelled", { Reason = reason, Cooldown = SpinConfig.Charge.CancelCooldown })
	end
end

function SpinService.start(player)
	if states[player] then
		return
	end
	if not Adapter.canAct(player) then
		tell(player, "Denied", { Reason = "Stunned" })
		return
	end
	local remaining = Cooldowns.remaining(player, COOLDOWN_KEY)
	if remaining > 0 then
		tell(player, "Denied", { Reason = "Cooldown", Remaining = remaining })
		return
	end
	local character, humanoid = Adapter.getAlive(player)

	local token = {}
	states[player] = {
		Start = os.clock(),
		Token = token,
		Humanoid = humanoid,
		Character = character,
	}
	Adapter.setMoveModifier(humanoid, "SpinCharge", SpinConfig.Charge.WalkSpeedMultiplier)
	character:SetAttribute("SpinChargeStart", workspace:GetServerTimeNow())
	tell(player, "Charging")

	-- Getting stunned while charging interrupts it: that's the counterplay.
	local stunConn
	stunConn = character:GetAttributeChangedSignal(Adapter.Settings.StunAttribute):Connect(function()
		if Adapter.isStunned(character) and states[player] and states[player].Token == token then
			SpinService.cancel(player, "Interrupted")
		end
		if not states[player] or states[player].Token ~= token then
			stunConn:Disconnect()
		end
	end)

	task.delay(SpinConfig.Charge.MaxHoldTime, function()
		local state = states[player]
		if state and state.Token == token then
			SpinService.release(player, nil) -- auto-release forward
		end
		if stunConn.Connected then
			stunConn:Disconnect()
		end
	end)
end

function SpinService.release(player, aim)
	local state = states[player]
	if not state then
		return
	end
	local chargeTime = os.clock() - state.Start
	endCharge(player)

	if not Adapter.canAct(player) then
		return
	end
	local character, _, root = Adapter.getAlive(player)

	local levelIndex, perfect = SpinConfig.getLevel(chargeTime, SpinConfig.Charge.ServerTimingTolerance)
	local level = SpinConfig.Levels[levelIndex]
	local direction = sanitizeAim(aim, root)
	local origin = throwOrigin(character, root)

	Cooldowns.start(player, COOLDOWN_KEY, level.Cooldown)

	local id = Projectiles.fire(player, {
		Kind = "SteelBall",
		Origin = origin,
		Direction = direction,
		Speed = level.Speed,
		Radius = level.Radius,
		Range = level.Range,
		Visual = { Level = levelIndex, Perfect = perfect },
		OnHit = function(target, position)
			Adapter.dealHit(player, target, {
				Damage = level.Damage,
				Stun = level.Stun,
				Knockback = level.Knockback,
				Direction = direction,
				Position = position,
				Level = levelIndex,
				Perfect = perfect,
				Source = "GoldenSpin",
			})
		end,
	})

	FX:FireAllClients("SpinRelease", {
		Character = character,
		Origin = origin,
		Direction = direction,
		Level = levelIndex,
		Perfect = perfect,
	})
	tell(player, "Released", {
		Level = levelIndex,
		Perfect = perfect,
		Cooldown = level.Cooldown,
		Fired = id ~= nil,
	})
end

function SpinService.init()
	Request.OnServerEvent:Connect(function(player, action, aim)
		if rateLimited(player) then
			return
		end
		if action == "Start" then
			SpinService.start(player)
		elseif action == "Release" then
			SpinService.release(player, aim)
		elseif action == "Cancel" then
			SpinService.cancel(player, "Manual")
		end
	end)

	local function onCharacter(player, character)
		endCharge(player)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				endCharge(player)
			end)
		end
	end

	local function onPlayer(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		endCharge(player)
		rate[player] = nil
	end)
end

return SpinService
