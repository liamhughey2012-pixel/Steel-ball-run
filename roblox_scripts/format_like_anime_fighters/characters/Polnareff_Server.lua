--[[
	Polnareff_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Jean Pierre Polnareff (Part 3): Silver Chariot.
	Its other half is Polnareff_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "polnareff" or __expect.Side ~= "server") then
		error("this is the code for Polnareff_Server, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Polnareff_Server and put it in ServerScriptService > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: ChariotRequiem
-- ======================================================================
__modules["ChariotRequiem"] = function()
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

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

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
end

-- ======================================================================
-- MODULE: Polnareff
-- ======================================================================
__modules["Polnareff"] = function()
--[[
	Polnareff  (ServerScriptService.SpinServer.TuskActs.Polnareff)

	Jean Pierre Polnareff (a visitor from another world: Part 3): SILVER
	CHARIOT, a knight with a rapier. Registered as "Act" 23.
	  M1        RAPIER COMBO: quick thrusts; the 4th is a lunge (faster with
	            the armour off)
	  Ability 1 HORA HORA RUSH: a storm of rapier thrusts in front of him,
	            holding them in place; a last big thrust sends them flying
	  Ability 2 ARMOR OFF: Silver Chariot sheds its armour for 8 s: he's 35%
	            faster and the rapier combo is much quicker
	  Ability 3 RAPIER SHOT: the Chariot fires its blade like a bullet
	            (instant, long range, stopped by walls)
	  Ultimate  AFTERIMAGE STORM: the Chariot splits into a ring of
	            afterimages round the nearest enemy in front; they all stab
	            at once for 2 s (everyone in the ring is hit), then one final
	            thrust launches them
	Numbers: TuskConfig.Polnareff. All damage goes through S.hit.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Polnareff = {}
local cfg = TuskConfig.Polnareff
local ACT = 23

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

local function now()
	return workspace:GetServerTimeNow()
end

local function armorOff(character)
	return (character:GetAttribute("ChariotArmorOffUntil") or 0) > now()
end

function Polnareff.M1(S, player, state, aim)
	local character = state.Character
	Moves.m1(S, player, state, aim, (character and armorOff(character)) and cfg.M1ArmorOff or cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- 1: HORA HORA RUSH
---------------------------------------------------------------------------
local function horaRush(S, player, state, aim)
	local c = cfg.HoraRush
	if not ready(S, player, state, "HoraRush", 1) then
		return
	end
	S.startCooldown(player, state, "HoraRush", c.Cooldown, 1)
	S.lock(state, c.Windup + c.Duration + 0.15)
	local character, humanoid = alive(S, player)
	local life = state.Life
	local untilT = now() + c.Windup + c.Duration
	character:SetAttribute("HoraRushUntil", untilT)
	S.Adapter.setMoveModifier(humanoid, "HoraRush", c.WalkMultiplier)
	S.fx("Ability", { Character = character, Act = ACT, Move = "HoraRush", Phase = "Start", Windup = c.Windup, Duration = c.Duration })
	local ticks = math.max(1, math.floor(c.Duration / c.Tick))
	local function stop()
		if humanoid.Parent then
			S.Adapter.setMoveModifier(humanoid, "HoraRush", nil)
		end
		if character.Parent and character:GetAttribute("HoraRushUntil") == untilT then
			character:SetAttribute("HoraRushUntil", nil)
		end
	end
	for i = 1, ticks do
		task.delay(c.Windup + (i - 1) * c.Tick, function()
			if character:GetAttribute("HoraRushUntil") ~= untilT then
				return -- already over
			end
			if not S.stillValid(player, state, life) then
				-- Stunned (or gone) out of it: The World goes back.
				stop()
				S.fx("Ability", { Character = character, Act = ACT, Move = "HoraRush", Phase = "Stop" })
				return
			end
			local _, _, r = alive(S, player)
			local boxCF = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
			local last = i == ticks
			if last then
				Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.FinalDamage, Stun = c.FinalStun, Knockback = c.FinalKnockback, Launch = c.FinalLaunch, Direction = r.CFrame.LookVector, Source = "PolnareffRush" }, c.MaxTargets)
				-- The last punch's shockwave catches everyone in front.
				local waveAt = (r.CFrame * CFrame.new(0, 0, -c.HitboxForward - 3)).Position
				Moves.aoe(S, player, waveAt, c.ShockwaveRadius, { Damage = c.ShockwaveDamage, Stun = 0.4, Knockback = 30, Direction = r.CFrame.LookVector, Source = "PolnareffRush" }, 6)
				S.fx("Ability", { Character = character, Act = ACT, Move = "HoraRush", Phase = "Finish", Position = boxCF.Position, Direction = r.CFrame.LookVector, Radius = c.ShockwaveRadius })
				stop()
			else
				local count, hitSet = Moves.boxHit(S, player, boxCF, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = r.CFrame.LookVector, Source = "PolnareffRush" }, c.MaxTargets)
				-- Drag whoever's caught back in front of The World (they can't slip out).
				for target in pairs(hitSet or {}) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr and not tr.Anchored then
						local to = boxCF.Position - tr.Position
						to = Vector3.new(to.X, 0, to.Z)
						tr.AssemblyLinearVelocity = Vector3.new(to.X * c.Drag, tr.AssemblyLinearVelocity.Y, to.Z * c.Drag) + r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
					end
				end
				if count > 0 and i % 2 == 0 then
					S.fx("Ability", { Act = ACT, Move = "HoraRush", Phase = "Hit", Position = boxCF.Position })
				end
			end
		end)
	end
end

---------------------------------------------------------------------------
-- 2: ARMOR OFF
---------------------------------------------------------------------------
local function shedArmor(S, player, state)
	local c = cfg.ArmorOff
	if not ready(S, player, state, "ArmorOff", 2) then
		return
	end
	S.startCooldown(player, state, "ArmorOff", c.Cooldown, 2)
	S.lock(state, 0.3)
	local character, humanoid = alive(S, player)
	local untilT = now() + c.Time
	character:SetAttribute("ChariotArmorOffUntil", untilT)
	S.Adapter.setMoveModifier(humanoid, "ArmorOff", c.Speed)
	S.fx("Ability", { Character = character, Act = ACT, Move = "ArmorOff", Phase = "Shed", Time = c.Time })
	task.delay(c.Time, function()
		if character.Parent and character:GetAttribute("ChariotArmorOffUntil") == untilT then
			character:SetAttribute("ChariotArmorOffUntil", nil)
			S.fx("Ability", { Character = character, Act = ACT, Move = "ArmorOff", Phase = "Back" })
		end
		if humanoid.Parent and not armorOff(character) then
			S.Adapter.setMoveModifier(humanoid, "ArmorOff", nil)
		end
	end)
end

---------------------------------------------------------------------------
-- 3: RAPIER SHOT
---------------------------------------------------------------------------
local function rapierShot(S, player, state, aim)
	local c = cfg.RapierShot
	if not ready(S, player, state, "RapierShot", 3) then
		return
	end
	S.startCooldown(player, state, "RapierShot", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "RapierShot", Phase = "Aim", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = S.aim(aim, r)
		local origin = S.origin(char, r, Moves.HAND)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local wall = workspace:Raycast(origin, dir * c.Range, params)
		local reach = c.Range
		if wall and not (wall.Instance.Parent and wall.Instance.Parent:FindFirstChildOfClass("Humanoid")) then
			reach = (wall.Position - origin).Magnitude
		end
		local mid = origin + dir * (reach / 2)
		local best, bestD, bestPos
		for _, target in ipairs(S.Hitbox.inBox(char, CFrame.lookAt(mid, mid + dir), Vector3.new(c.Width, c.Width + 2, reach), 8)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr then
				local d = (tr.Position - origin):Dot(dir)
				if d > 0 and (not bestD or d < bestD) then
					best, bestD, bestPos = target, d, tr.Position
				end
			end
		end
		local landed = false
		if best then
			landed = S.hit(player, best, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Position = bestPos, Source = "PolnareffShot" })
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "RapierShot", Phase = "Fire", From = origin, To = bestPos or (origin + dir * reach), Hit = landed })
	end)
end

function Polnareff.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		horaRush(S, player, state, aim)
	elseif slot == 2 then
		shedArmor(S, player, state)
	elseif slot == 3 then
		rapierShot(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- AFTERIMAGE STORM (ultimate)
---------------------------------------------------------------------------
function Polnareff.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.3)
	character:SetAttribute("Armored", true)
	local target = Moves.findTarget(S, character, root, u.Range, u.Cone, S.aim(aim, root))
	local tr = target and target:FindFirstChild("HumanoidRootPart")
	local center = tr and tr.Position or (root.Position + Moves.flat(root.CFrame.LookVector) * 8)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Split", Windup = u.Windup, Position = center, Radius = u.Radius, Images = u.Images })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		-- The ring follows the target if there is one.
		local function centerNow()
			local p = tr and tr.Parent and tr.Position
			return p or center
		end
		S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Storm", Position = centerNow(), Target = target, Radius = u.Radius, Images = u.Images, Duration = u.Duration })
		local ticks = math.max(1, math.floor(u.Duration / u.Tick))
		for k = 1, ticks do
			task.delay(k * u.Tick, function()
				if state.Life ~= life or not character.Parent then
					return
				end
				local at = centerNow()
				for _, t in ipairs(S.Hitbox.inRadius(character, at, u.Radius, 8)) do
					local r2 = t:FindFirstChild("HumanoidRootPart")
					if r2 then
						S.hit(player, t, { Damage = u.TickDamage, Stun = u.TickStun, Knockback = 0, Direction = Vector3.new(0, 1, 0), Position = r2.Position, Source = "PolnareffStorm" })
					end
				end
			end)
		end
		task.delay(u.Duration + 0.05, function()
			if state.Life ~= life or not character.Parent then
				S.fx("Ultimate", { Character = character, Act = ACT, Phase = "End" })
				return
			end
			local at = centerNow()
			local _, _, r = alive(S, player)
			for _, t in ipairs(S.Hitbox.inRadius(character, at, u.Radius, 8)) do
				local r2 = t:FindFirstChild("HumanoidRootPart")
				if r2 then
					local dir = r and Vector3.new(r2.Position.X - r.Position.X, 0, r2.Position.Z - r.Position.Z) or Vector3.new(0, 0, 1)
					S.hit(player, t, { Damage = u.FinalDamage, Stun = u.FinalStun, Knockback = u.FinalKnockback, Launch = u.FinalLaunch, Direction = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 0, 1), Position = r2.Position, Unblockable = true, Source = "PolnareffFinal" })
				end
			end
			S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Final", Position = at, Radius = u.Radius })
		end)
	end)
end

function Polnareff.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
		character:SetAttribute("HoraRushUntil", nil)
		character:SetAttribute("ChariotArmorOffUntil", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "HoraRush", nil)
			S.Adapter.setMoveModifier(humanoid, "ArmorOff", nil)
		end
	end
end

return Polnareff
end

-- ======================================================================
-- MODULE: PolnareffOutfit
-- ======================================================================
__modules["PolnareffOutfit"] = function()
--[[
	PolnareffOutfit  (ServerScriptService.SpinServer.PolnareffOutfit)

	Gives a character the look of Jean Pierre Polnareff (Part 3) while they
	play him (TuskAct 23), built from blocky parts (no catalog asset ids):
	  * his famous HAIR: silver-white, standing straight up in a tall column
	    with a flat top; short at the sides
	  * half-heart ("broken heart") earrings
	  * a black sleeveless top with a high neck; bare, muscular arms
	  * high-waisted cream trousers with a dark belt; dark boots
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local PolnareffOutfit = {}
PolnareffOutfit.Act = 23

local C = {
	Hair = Color3.fromRGB(232, 234, 240),
	HairShade = Color3.fromRGB(196, 200, 212),
	Earring = Color3.fromRGB(236, 196, 210),
	Top = Color3.fromRGB(30, 32, 44),
	TopShade = Color3.fromRGB(50, 54, 70),
	Pants = Color3.fromRGB(228, 222, 202),
	PantsShade = Color3.fromRGB(196, 188, 164),
	Belt = Color3.fromRGB(60, 44, 34),
	Buckle = Color3.fromRGB(200, 200, 210),
	Boot = Color3.fromRGB(56, 42, 34),
}

local saved = setmetatable({}, { __mode = "k" })

local function piece(parent, outfit, name, size, color, offset)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.Color = color
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = outfit
	return p
end

-- A flat disc facing forward (-Z).
local function disc(parent, outfit, name, d, depth, color, offset)
	local p = piece(parent, outfit, name, Vector3.new(depth, d, d), color, offset * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Short at the sides and back...
	piece(head, outfit, "HairBase", Vector3.new(head.Size.X + 0.08 * s, 0.3 * s, head.Size.Z + 0.08 * s), C.Hair, CFrame.new(0, h - 0.1 * s, 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Side", Vector3.new(0.08 * s, 0.4 * s, head.Size.Z * 0.7), C.HairShade, CFrame.new(side * (w + 0.03 * s), h - 0.35 * s, 0.08 * s))
	end
	-- ...and standing straight up in a tall column with a flat top.
	local tall = 1.5 * s
	local tiers = 4
	for k = 0, tiers - 1 do
		local f = k / tiers
		local h0 = tall / tiers
		piece(head, outfit, "HairColumn", Vector3.new(head.Size.X * (0.86 - f * 0.14), h0 + 0.02 * s, head.Size.Z * (0.74 - f * 0.12)), k % 2 == 0 and C.Hair or Color3.fromRGB(240, 242, 248), CFrame.new(0, h + h0 * (k + 0.5), 0.05 * s + f * 0.06 * s))
	end
	piece(head, outfit, "HairTop", Vector3.new(head.Size.X * 0.7, 0.1 * s, head.Size.Z * 0.6), Color3.new(1, 1, 1), CFrame.new(0, h + tall, 0.1 * s))
	for k = -1, 1 do
		piece(head, outfit, "HairStreak", Vector3.new(0.04 * s, tall * 0.85, 0.05 * s), C.HairShade, CFrame.new(k * 0.2 * s, h + tall / 2, -head.Size.Z * 0.33 + 0.05 * s) * CFrame.Angles(math.rad(-3), 0, 0))
	end
	-- Half-heart earrings.
	for _, side in ipairs({ -1, 1 }) do
		local lobe = piece(head, outfit, "Earring", Vector3.new(0.05 * s, 0.16 * s, 0.16 * s), C.Earring, CFrame.new(side * (w + 0.05 * s), -0.2 * s, 0.02 * s))
		lobe.Shape = Enum.PartType.Cylinder
		piece(head, outfit, "EarringPoint", Vector3.new(0.05 * s, 0.12 * s, 0.12 * s), C.Earring, CFrame.new(side * (w + 0.05 * s), -0.3 * s, 0.05 * s) * CFrame.Angles(math.pi / 4, 0, 0))
	end
	-- Strong brows.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Brow", Vector3.new(0.28 * s, 0.06 * s, 0.05 * s), C.HairShade, CFrame.new(side * 0.22 * s, 0.14 * s, -d - 0.02 * s) * CFrame.Angles(0, 0, side * 0.1))
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	local head = character:FindFirstChild("Head")
	local skin = head and head.Color or Color3.fromRGB(236, 200, 170)
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Top", s + Vector3.new(0.06, 0.02, 0.06), C.Top, CFrame.new())
		piece(upper, outfit, "HighNeck", Vector3.new(0.7, 0.3, 0.66), C.Top, CFrame.new(0, top + 0.12, 0))
		-- Sleeveless: bare shoulders where the arm holes are.
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Shoulder", Vector3.new(0.42, 0.5, s.Z + 0.08), skin, CFrame.new(side * (s.X / 2 - 0.18), top - 0.24, 0))
			piece(upper, outfit, "Strap", Vector3.new(0.22, 0.52, s.Z + 0.1), C.Top, CFrame.new(side * (s.X / 2 - 0.48), top - 0.23, 0))
		end
		piece(upper, outfit, "PecLine", Vector3.new(s.X * 0.5, 0.04, 0.04), C.TopShade, CFrame.new(0, 0.12, front - 0.04))
		piece(upper, outfit, "AbLine", Vector3.new(0.04, 0.7, 0.04), C.TopShade, CFrame.new(0, -0.35, front - 0.04))
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.06, 0.24, 0.06), C.Pants, CFrame.new(0, 0.1, 0))
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.16, 0.16, ls.Z + 0.16), C.Belt, CFrame.new(0, ls.Y / 2 + 0.12, 0))
		piece(lower, outfit, "Buckle", Vector3.new(0.26, 0.18, 0.06), C.Buckle, CFrame.new(0, ls.Y / 2 + 0.12, -ls.Z / 2 - 0.1))
	end
	-- Bare arms.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Skin", arm.Size + Vector3.new(0.04, 0, 0.04), skin, CFrame.new())
		end
	end
	-- Cream trousers, dark boots.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
			piece(leg, outfit, "Crease", Vector3.new(0.04, ls.Y * 0.9, 0.04), C.PantsShade, CFrame.new(0, 0, -ls.Z / 2 - 0.04))
			if name:find("Lower") then
				piece(leg, outfit, "Boot", Vector3.new(ls.X + 0.1, ls.Y * 0.45, ls.Z + 0.1), C.Boot, CFrame.new(0, -ls.Y * 0.28, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Boot", foot.Size + Vector3.new(0.08, 0.04, 0.14), C.Boot, CFrame.new(0, 0, -0.04))
		end
	end
end

function PolnareffOutfit.apply(character)
	if character:FindFirstChild("PolnareffOutfit") then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local store = { Hidden = {} }
	saved[character] = store
	for _, d in ipairs(character:GetChildren()) do
		if d:IsA("Accessory") then
			local handle = d:FindFirstChild("Handle")
			local kind = d.AccessoryType
			if handle and (kind == Enum.AccessoryType.Hat or kind == Enum.AccessoryType.Hair or kind == Enum.AccessoryType.Unknown) then
				store.Hidden[handle] = handle.Transparency
				handle.Transparency = 1
			end
		end
	end
	local outfit = Instance.new("Model")
	outfit.Name = "PolnareffOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function PolnareffOutfit.remove(character)
	local outfit = character:FindFirstChild("PolnareffOutfit")
	if outfit then
		outfit:Destroy()
	end
	local store = saved[character]
	if not store then
		return
	end
	saved[character] = nil
	for thing, transparency in pairs(store.Hidden) do
		if thing.Parent then
			thing.Transparency = transparency
		end
	end
end

local function watch(character)
	local function update()
		if (character:GetAttribute("TuskAct") == PolnareffOutfit.Act or character:GetAttribute("TuskAct") == 24) then
			task.delay(0.3, function()
				if character.Parent and (character:GetAttribute("TuskAct") == PolnareffOutfit.Act or character:GetAttribute("TuskAct") == 24) then
					PolnareffOutfit.apply(character)
				end
			end)
		else
			PolnareffOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function PolnareffOutfit.init()
	local function onPlayer(player)
		player.CharacterAppearanceLoaded:Connect(watch)
		if player.Character then
			watch(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	-- Stand-user NPCs (StandBots) wear the outfit too.
	local CollectionService = game:GetService("CollectionService")
	for _, model in ipairs(CollectionService:GetTagged("SpinFighter")) do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("SpinFighter"):Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
end

return PolnareffOutfit
end
end
