--[[
	Giorno  (ServerScriptService.SpinServer.TuskActs.Giorno)

	Giorno Giovanna (Part 5, Golden Wind): GOLD EXPERIENCE. Registered as
	"Act" 30. Gold Experience gives LIFE to whatever it touches.
	  M1        MUDA COMBO: Gold Experience punches with him; the 4th is a
	            heavy straight that launches
	  Ability 1 MUDA MUDA RUSH: a storm of punches in front of him that drags
	            them along (he can still walk); the last big "MUDA!" sends
	            them flying
	  Ability 2 LIFE GIVER: TREE: Gold Experience punches the ground; roots
	            race along it to the nearest enemy in front (or a spot ahead)
	            and a tree bursts up under them, launching them
	  Ability 3 SENSE OVERLOAD: a punch that gives them too much life:
	            their mind races, so their body crawls (very slow for a
	            while), and the pain arrives late, all at once
	  Ultimate  LIFE BURST: the ground round him bursts into a jungle:
	            vines hold everyone near, snakes bite them, he grows back
	            what he's lost (heals), then the trees burst and throw them
	The Requiem Arrow turns Gold Experience into GOLD EXPERIENCE REQUIEM
	(Act 31, TuskActs.GoldExperienceRequiem) until he goes down.
	Numbers: TuskConfig.Giorno. All damage goes through S.hit.
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Giorno = {}
local cfg = TuskConfig.Giorno
local ACT = 30

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

local function aliveModel(model)
	local h = model and model.Parent and model:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end

function Giorno.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: MUDA MUDA RUSH
---------------------------------------------------------------------------
local function mudaRush(S, player, state)
	local c = cfg.MudaRush
	if not ready(S, player, state, "MudaRush", 1) then
		return
	end
	S.startCooldown(player, state, "MudaRush", c.Cooldown, 1)
	S.lock(state, c.Windup + c.Duration + 0.15)
	local character, humanoid = alive(S, player)
	local life = state.Life
	local untilT = now() + c.Windup + c.Duration
	character:SetAttribute("MudaRushUntil", untilT)
	S.Adapter.setMoveModifier(humanoid, "MudaRush", c.WalkMultiplier)
	S.fx("Ability", { Character = character, Act = ACT, Move = "MudaRush", Phase = "Start", Windup = c.Windup, Duration = c.Duration })
	local ticks = math.max(1, math.floor(c.Duration / c.Tick))
	local function stop()
		if humanoid.Parent then
			S.Adapter.setMoveModifier(humanoid, "MudaRush", nil)
		end
		if character.Parent and character:GetAttribute("MudaRushUntil") == untilT then
			character:SetAttribute("MudaRushUntil", nil)
		end
	end
	for i = 1, ticks do
		task.delay(c.Windup + (i - 1) * c.Tick, function()
			if character:GetAttribute("MudaRushUntil") ~= untilT then
				return
			end
			if not S.stillValid(player, state, life) then
				stop()
				S.fx("Ability", { Character = character, Act = ACT, Move = "MudaRush", Phase = "Stop" })
				return
			end
			local _, _, r = alive(S, player)
			local boxCF = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
			if i == ticks then
				Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.FinalDamage, Stun = c.FinalStun, Knockback = c.FinalKnockback, Launch = c.FinalLaunch, Direction = r.CFrame.LookVector, Source = "GiornoMuda" }, c.MaxTargets)
				S.fx("Ability", { Character = character, Act = ACT, Move = "MudaRush", Phase = "Finish", Position = boxCF.Position, Direction = r.CFrame.LookVector })
				stop()
			else
				local count, hitSet = Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = r.CFrame.LookVector, Source = "GiornoMuda" }, c.MaxTargets)
				for target in pairs(hitSet or {}) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr and not tr.Anchored then
						local to = boxCF.Position - tr.Position
						tr.AssemblyLinearVelocity = Vector3.new(to.X * c.Drag, tr.AssemblyLinearVelocity.Y, to.Z * c.Drag) + r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
					end
				end
				if count > 0 and i % 2 == 0 then
					S.fx("Ability", { Act = ACT, Move = "MudaRush", Phase = "Hit", Position = boxCF.Position })
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- 2: LIFE GIVER: TREE
---------------------------------------------------------------------------
local function tree(S, player, state, aim)
	local c = cfg.Tree
	if not ready(S, player, state, "Tree", 2) then
		return
	end
	S.startCooldown(player, state, "Tree", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.2)
	local character, _, root = alive(S, player)
	local life = state.Life
	local dir = Moves.flat(S.aim(aim, root))
	S.fx("Ability", { Character = character, Act = ACT, Move = "Tree", Phase = "Punch", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local target = Moves.findTarget(S, char, r, c.Range, c.Cone, dir)
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		local spot = Moves.groundBelow(tr and tr.Position or (r.Position + dir * c.MissDistance), { char })
		local from = Moves.groundBelow(r.Position + dir * 2, { char })
		S.fx("Ability", { Character = char, Act = ACT, Move = "Tree", Phase = "Roots", From = from, To = spot, Time = c.Travel })
		task.delay(c.Travel, function()
			if not char.Parent then
				return
			end
			-- It grows right under them if they're still close.
			if tr and tr.Parent and (Vector3.new(tr.Position.X, spot.Y, tr.Position.Z) - spot).Magnitude < c.Radius + 3 then
				spot = Moves.groundBelow(tr.Position, { char })
			end
			Moves.aoe(S, player, spot, c.Radius, { Damage = c.Damage, Stun = c.Stun, Knockback = 4, Launch = c.Launch, Direction = Vector3.new(0, 1, 0), Source = "GiornoTree" }, 6)
			S.fx("Ability", { Character = char, Act = ACT, Move = "Tree", Phase = "Burst", Position = spot, Radius = c.Radius, Life = c.TreeLife })
		end)
	end)
end

---------------------------------------------------------------------------
-- 3: SENSE OVERLOAD
---------------------------------------------------------------------------
local function overload(S, player, state, aim)
	local c = cfg.Overload
	if not ready(S, player, state, "Overload", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local target = Moves.findTarget(S, character, root, c.Range, c.Cone, Moves.flat(S.aim(aim, root)))
	S.startCooldown(player, state, "Overload", target and c.Cooldown or c.MissCooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "Overload", Phase = "Punch", Windup = c.Windup, Target = target })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) or not target or not aliveModel(target) then
			return
		end
		local tr = target:FindFirstChild("HumanoidRootPart")
		local th = target:FindFirstChildOfClass("Humanoid")
		if not tr or not th then
			return
		end
		local landed = S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 2, Direction = Moves.flat(tr.Position - root.Position), Position = tr.Position, Source = "GiornoOverload" })
		if not landed then
			return
		end
		local untilT = now() + c.Time
		target:SetAttribute("SenseOverloadUntil", untilT)
		S.Adapter.setMoveModifier(th, "SenseOverload", c.SlowMultiplier)
		S.fx("Ability", { Character = character, Act = ACT, Move = "Overload", Phase = "Overload", Target = target, Time = c.Time })
		task.delay(c.Time, function()
			if th.Parent then
				S.Adapter.setMoveModifier(th, "SenseOverload", nil)
			end
			if target:GetAttribute("SenseOverloadUntil") ~= untilT then
				return
			end
			target:SetAttribute("SenseOverloadUntil", nil)
			if aliveModel(target) and tr.Parent then
				-- The pain catches up with them, all at once.
				S.hit(player, target, { Damage = c.LateDamage, Stun = c.LateStun, Knockback = 18, Launch = 8, Direction = -tr.CFrame.LookVector, Position = tr.Position, Source = "GiornoOverload", Unblockable = true })
				S.fx("Ability", { Act = ACT, Move = "Overload", Phase = "Pain", Target = target })
			end
		end)
	end)
end

function Giorno.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		mudaRush(S, player, state)
	elseif slot == 2 then
		tree(S, player, state, aim)
	elseif slot == 3 then
		overload(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- LIFE BURST (ultimate)
---------------------------------------------------------------------------
function Giorno.Ultimate(S, player, state, aim)
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
		local char, hum, r = alive(S, player)
		local center = Moves.groundBelow(r.Position, { char })
		local held = {}
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, u.Radius, 14)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.hit(player, target, { Damage = u.GrabDamage, Stun = u.HoldTime + 0.2, Knockback = 0, Position = tr.Position, Source = "GiornoJungle" }) then
				table.insert(held, target)
			end
		end
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Jungle", Position = center, Radius = u.Radius, Targets = held, Time = u.HoldTime })
		-- He grows back what he's lost.
		if hum and hum.Health > 0 then
			hum.Health = math.min(hum.MaxHealth, hum.Health + u.Heal)
		end
		local ticks = math.max(1, math.floor(u.HoldTime / u.Tick))
		for k = 1, ticks do
			task.delay(k * u.Tick, function()
				if state.Life ~= life then
					return
				end
				for _, target in ipairs(held) do
					local tr = target.Parent and target:FindFirstChild("HumanoidRootPart")
					if tr and aliveModel(target) then
						S.hit(player, target, { Damage = u.BiteDamage, Stun = u.Tick + 0.15, Knockback = 0, Position = tr.Position, Source = "GiornoJungle" })
					end
				end
				S.fx("Ultimate", { Act = ACT, Phase = "Bite", Targets = held })
			end)
		end
		task.delay(u.HoldTime, function()
			if state.Life ~= life or not char.Parent then
				S.fx("Ultimate", { Character = char, Act = ACT, Phase = "End" })
				return
			end
			for _, target in ipairs(held) do
				local tr = target.Parent and target:FindFirstChild("HumanoidRootPart")
				if tr and aliveModel(target) then
					local away = Vector3.new(tr.Position.X - center.X, 0, tr.Position.Z - center.Z)
					S.hit(player, target, { Damage = u.FinalDamage, Stun = u.FinalStun, Knockback = u.FinalKnockback, Launch = u.FinalLaunch, Direction = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1), Position = tr.Position, Source = "GiornoJungle", Unblockable = true })
				end
			end
			S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Burst", Position = center, Radius = u.Radius, Targets = held })
		end)
	end)
end

function Giorno.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("MudaRushUntil", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "MudaRush", nil)
		end
	end
end

return Giorno
