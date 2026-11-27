--[[
	ShopBalls  (ServerScriptService.SpinServer.ShopBalls)

	The bounty board's THROWABLES: a STEEL BALL or a WRECKING BALL. Buying
	one (BountyService) puts it in your hand (character attribute
	"HeldThrowable" = "Steel" / "Wrecking"); ThrowItem (X) throws it once.
	  * Steel Ball: fast and spinning; it hits the first one it meets
	  * Wrecking Ball: slower; it bursts where it lands and blasts everyone
	    near it
	  * Gyro buying a Steel Ball also gets a SPIN BOOST for a while (more
	    damage, more speed, quicker cooldowns): ShopBalls.gyroBoost
	One at a time; a ball you're holding is gone when you die.
	Numbers: TuskConfig.ShopBalls. Visuals: the "GyroBall" projectile (Gyro.lua).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Adapter = require(script.Parent.CombatAdapter)

local Net = require(Shared.Net)

local ShopBalls = {}
local cfg = TuskConfig.ShopBalls or {}
local WorldFX

local function fx(data)
	WorldFX = WorldFX or Net.get("WorldFX")
	WorldFX:FireAllClients("ShopBall", data)
end

local function now()
	return workspace:GetServerTimeNow()
end

-- Gyro's Spin boost.
function ShopBalls.gyroBoost(character)
	local b = cfg.GyroBoost or {}
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local untilT = now() + (b.Time or 60)
	character:SetAttribute("SpinBoostUntil", untilT)
	character:SetAttribute("SpinBoostDamage", b.Damage or 1.2)
	character:SetAttribute("SpinBoostCooldown", b.Cooldown or 0.75)
	if humanoid then
		Adapter.setMoveModifier(humanoid, "SpinBoost", b.Speed or 1.1)
	end
	task.delay(b.Time or 60, function()
		if character.Parent and character:GetAttribute("SpinBoostUntil") == untilT then
			character:SetAttribute("SpinBoostUntil", nil)
			if humanoid and humanoid.Parent then
				Adapter.setMoveModifier(humanoid, "SpinBoost", nil)
			end
		end
	end)
end

local function throw(S, player, state, aim)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local kind = character and character:GetAttribute("HeldThrowable")
	if not root or not kind or not cfg[kind] then
		S.tell(player, "Denied", { Reason = "NoThrowable" })
		return
	end
	if S.isBusy(state) or state.Charging or not Adapter.canAct(player) then
		return
	end
	local c = cfg[kind]
	character:SetAttribute("HeldThrowable", nil)
	S.lock(state, 0.3)
	local dir = S.aim(aim, root)
	local origin = S.origin(character, root, CFrame.new(1, 1, -1.5))
	fx({ Phase = "Throw", Character = character, Kind = kind })
	local hit = {}
	S.fireBall(player, state, {
		Origin = origin,
		Direction = dir,
		Speed = c.Speed,
		Radius = c.Radius,
		Range = c.Range,
		Style = kind == "Wrecking" and "Wrecking" or "Throw",
		OnHit = function(target, position)
			if hit[target] then
				return
			end
			hit[target] = true
			S.hit(player, target, { Damage = c.Damage, Stun = c.Stun or 0.5, Knockback = c.Knockback or 20, Direction = dir, Position = position, Source = kind == "Wrecking" and "ShopWrecking" or "ShopSteel" })
		end,
		OnEnd = function(position)
			if kind ~= "Wrecking" then
				return
			end
			-- It bursts: everyone near is blasted away.
			for _, target in ipairs(S.Hitbox.inRadius(character, position, c.BlastRadius, 10)) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr then
					local away = Vector3.new(tr.Position.X - position.X, 0, tr.Position.Z - position.Z)
					S.hit(player, target, { Damage = c.BlastDamage, Stun = c.BlastStun, Knockback = c.BlastKnockback, Launch = c.BlastLaunch, Direction = away.Magnitude > 0.1 and away.Unit or dir, Position = tr.Position, Source = "ShopWrecking" })
				end
			end
			fx({ Phase = "Burst", Kind = "Wrecking", Position = position, Radius = c.BlastRadius })
		end,
	})
end

function ShopBalls.init(S)
	S.ThrowItem = function(player, state, aim)
		throw(S, player, state, aim)
	end
end

return ShopBalls
