--[[
	ChariotRequiem  (ServerScriptService.SpinServer.TuskActs.ChariotRequiem)

	SILVER CHARIOT REQUIEM: what the Requiem Arrow makes of Polnareff's
	Silver Chariot (Act 24, only from the arrow; back to Silver Chariot,
	Act 23, when he goes down). A whole new style: slow, heavy, and it
	plays with souls.
	  M1        REQUIEM STRIKES: slow, heavy, long-reaching blows
	  Ability 1 SOUL SWAP: he and the nearest enemy in front swap places in
	            a flash; they're hurt and left reeling
	  Ability 2 REQUIEM'S SLEEP: everyone round him falls asleep (they can't
	            move or act for 2.2 s)
	  Ability 3 SHADOW STEP: he slips forward like a shadow (can't be hit
	            for a moment)
	  Ultimate  SOUL REVERSAL: everyone near him has their soul pulled out
	            and held (they can't move, they're drained), then slammed back
	Numbers: TuskConfig.Requiem. All damage goes through S.hit.
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local ChariotRequiem = {}
local cfg = TuskConfig.Requiem
local ACT = 24

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

function ChariotRequiem.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

local pins = setmetatable({}, { __mode = "k" }) -- [root] = { Count, WasAnchored }

local function pin(root)
	local p = pins[root]
	if not p then
		p = { Count = 0, WasAnchored = root.Anchored }
		pins[root] = p
	end
	p.Count = p.Count + 1
	root.Anchored = true
end

local function unpin(root)
	local p = pins[root]
	if not p then
		return
	end
	p.Count = p.Count - 1
	if p.Count <= 0 then
		pins[root] = nil
		if root.Parent then
			root.Anchored = p.WasAnchored
		end
	end
end

---------------------------------------------------------------------------
-- 1: SOUL SWAP
---------------------------------------------------------------------------
local function soulSwap(S, player, state, aim)
	local c = cfg.SoulSwap
	if not ready(S, player, state, "SoulSwap", 1) then
		return
	end
	local character, _, root = alive(S, player)
	local target = Moves.findTarget(S, character, root, c.Range, c.Cone, S.aim(aim, root))
	if not target then
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	S.startCooldown(player, state, "SoulSwap", c.Cooldown, 1)
	S.lock(state, c.Windup + 0.2)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "SoulSwap", Phase = "Reach", Target = target, Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) or not target.Parent then
			return
		end
		local tr = target:FindFirstChild("HumanoidRootPart")
		local _, _, r = alive(S, player)
		if not tr or not r or tr.Anchored then
			return
		end
		local mine, theirs = r.CFrame, tr.CFrame
		character:PivotTo(theirs)
		target:PivotTo(mine)
		r.AssemblyLinearVelocity = Vector3.new()
		tr.AssemblyLinearVelocity = Vector3.new()
		target:SetAttribute("SoulSwappedUntil", now() + c.Stun)
		S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = Vector3.new(0, 1, 0), Position = tr.Position, Unblockable = true, Source = "RequiemSwap" })
		S.fx("Ability", { Character = character, Act = ACT, Move = "SoulSwap", Phase = "Swap", Target = target, A = mine.Position, B = theirs.Position })
	end)
end

---------------------------------------------------------------------------
-- 2: REQUIEM'S SLEEP
---------------------------------------------------------------------------
local function sleep(S, player, state)
	local c = cfg.Sleep
	if not ready(S, player, state, "Sleep", 2) then
		return
	end
	S.startCooldown(player, state, "Sleep", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "Sleep", Phase = "Wind", Windup = c.Windup, Radius = c.Radius })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local sleepers = {}
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, c.Radius, 12)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.hit(player, target, { Damage = c.Damage, Stun = c.Time, Knockback = 0, Direction = Vector3.new(0, 1, 0), Position = tr.Position, Source = "RequiemSleep" }) then
				target:SetAttribute("RequiemSleepUntil", now() + c.Time)
				table.insert(sleepers, target)
			end
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "Sleep", Phase = "Sleep", Position = r.Position, Radius = c.Radius, Targets = sleepers, Time = c.Time })
	end)
end

---------------------------------------------------------------------------
-- 3: SHADOW STEP
---------------------------------------------------------------------------
local function shadowStep(S, player, state, aim)
	local c = cfg.ShadowStep
	if not ready(S, player, state, "ShadowStep", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local dir = Moves.flat(S.aim(aim, root))
	local to = Moves.safeStep(character, root, dir, c.Distance)
	if not to then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "ShadowStep", c.Cooldown, 3)
	S.lock(state, 0.15)
	local from = root.Position
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	character:PivotTo(CFrame.lookAt(to, to + dir))
	S.fx("Ability", { Character = character, Act = ACT, Move = "ShadowStep", Phase = "Step", From = from, To = to })
	task.delay(c.IFrames, function()
		if character.Parent then
			character:SetAttribute(iframes, nil)
		end
	end)
end

function ChariotRequiem.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		soulSwap(S, player, state, aim)
	elseif slot == 2 then
		sleep(S, player, state)
	elseif slot == 3 then
		shadowStep(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- SOUL REVERSAL (ultimate)
---------------------------------------------------------------------------
function ChariotRequiem.Ultimate(S, player, state, aim)
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
		local char, _, r = alive(S, player)
		local held = {}
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, u.Radius, 14)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr then
				pin(tr)
				table.insert(held, target)
			end
		end
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Souls", Position = r.Position, Radius = u.Radius, Targets = held, Time = u.HoldTime })
		local ticks = math.max(1, math.floor(u.HoldTime / u.Tick))
		for k = 1, ticks do
			task.delay(k * u.Tick, function()
				if state.Life ~= life then
					return
				end
				for _, target in ipairs(held) do
					local tr = target.Parent and target:FindFirstChild("HumanoidRootPart")
					if tr then
						S.hit(player, target, { Damage = u.TickDamage, Stun = u.Tick + 0.1, Knockback = 0, Direction = Vector3.new(0, 1, 0), Position = tr.Position, Source = "RequiemSouls" })
					end
				end
			end)
		end
		task.delay(u.HoldTime, function()
			for _, target in ipairs(held) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr then
					unpin(tr)
				end
			end
			if state.Life ~= life or not char.Parent then
				S.fx("Ultimate", { Character = char, Act = ACT, Phase = "End" })
				return
			end
			for _, target in ipairs(held) do
				local tr = target.Parent and target:FindFirstChild("HumanoidRootPart")
				if tr then
					S.hit(player, target, { Damage = u.FinalDamage, Stun = u.FinalStun, Knockback = 10, Direction = Vector3.new(0, -1, 0), Position = tr.Position, Unblockable = true, Source = "RequiemReversal" })
				end
			end
			S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Return", Targets = held })
		end)
	end)
end

function ChariotRequiem.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
	end
end

return ChariotRequiem
