--[[
	Rohan  (ServerScriptService.SpinServer.TuskActs.Rohan)

	Rohan Kishibe (Part 4): HEAVEN'S DOOR. Registered as "Act" 28.
	Heaven's Door turns people into BOOKS (their faces peel open into
	pages), and Rohan writes commands in them with his pen.
	  M1        PEN & PAGE COMBO: ink flicks and Heaven's Door's swipes; the
	            4th is a page-slash that launches
	  Ability 1 HEAVEN'S DOOR: the nearest enemy in front becomes a book:
	            stuck for a moment, then readable for a while (moves 2 and 3
	            write in them)
	  Ability 2 WRITE: "YOU CAN'T ATTACK KISHIBE ROHAN": in the nearest
	            readable book; for a while their hits on him do nothing, and
	            their abilities are blank for a moment
	  Ability 3 WRITE: "FLY BACKWARDS AT 70 KM/H": in the nearest readable
	            book (or straight into someone right in front): they're
	            hurled away backwards
	  Ultimate  EVERYONE IS A BOOK: everyone near becomes a book at once,
	            and "YOU CAN'T ATTACK KISHIBE ROHAN" is written in all of them
	Rohan's character carries a "RohanToken" (CombatAdapter checks it against
	a writer's "CantAttack"). Numbers: TuskConfig.Rohan. Damage via S.hit.
]]

local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Rohan = {}
local cfg = TuskConfig.Rohan
local ACT = 28

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

-- His token (who "Kishibe Rohan" is, for the can't-attack command).
local function token(char)
	local t = char:GetAttribute("RohanToken")
	if not t then
		local ok, guid = pcall(function()
			return HttpService:GenerateGUID(false)
		end)
		t = ok and guid or tostring({})
		char:SetAttribute("RohanToken", t)
	end
	return t
end

function Rohan.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

-- Turn someone into a book: stuck (stunned) a moment, then readable by him.
local function makeBook(S, player, char, target, bookTime, readable, damage, source)
	local tr = target:FindFirstChild("HumanoidRootPart")
	if not tr then
		return false
	end
	local landed = S.hit(player, target, { Damage = damage, Stun = bookTime, Knockback = 0, Position = tr.Position, Source = source, Unblockable = true })
	if not landed then
		return false
	end
	local untilT = now() + bookTime + readable
	target:SetAttribute("BookUntil", now() + bookTime)
	target:SetAttribute("ReadableUntil", untilT)
	target:SetAttribute("ReadableBy", token(char))
	return true
end

-- The nearest book he can write in (within range).
local function nearestBook(S, char, root, range)
	local mine = token(char)
	local best, bestD
	for _, target in ipairs(S.Hitbox.inRadius(char, root.Position, range, 30)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and aliveModel(target) and (target:GetAttribute("ReadableUntil") or 0) > now() and target:GetAttribute("ReadableBy") == mine then
			local d = (tr.Position - root.Position).Magnitude
			if not bestD or d < bestD then
				best, bestD = target, d
			end
		end
	end
	return best
end

-- "YOU CAN'T ATTACK KISHIBE ROHAN"
local function writeCantAttack(char, target, time, silence)
	target:SetAttribute("CantAttack", token(char))
	target:SetAttribute("CantAttackUntil", now() + time)
	if silence and silence > 0 then
		local s = now() + silence
		if (target:GetAttribute("SilencedUntil") or 0) < s then
			target:SetAttribute("SilencedUntil", s)
		end
	end
end

---------------------------------------------------------------------------
-- 1: HEAVEN'S DOOR (open a book)
---------------------------------------------------------------------------
local function openBook(S, player, state, aim)
	local c = cfg.OpenBook
	if not ready(S, player, state, "OpenBook", 1) then
		return
	end
	S.startCooldown(player, state, "OpenBook", c.Cooldown, 1)
	S.lock(state, c.Windup + 0.25)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "OpenBook", Phase = "Reach", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = Moves.flat(S.aim(aim, r))
		local target = Moves.findTarget(S, char, r, c.Range, c.Cone, dir)
		if not target or not makeBook(S, player, char, target, c.BookTime, c.ReadableTime, c.Damage, "RohanBook") then
			S.startCooldown(player, state, "OpenBook", c.MissCooldown, 1)
			S.fx("Ability", { Character = char, Act = ACT, Move = "OpenBook", Phase = "Miss", Position = (r.CFrame * CFrame.new(0, 0, -4)).Position })
			return
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "OpenBook", Phase = "Open", Target = target, BookTime = c.BookTime, Readable = c.ReadableTime })
	end)
end

---------------------------------------------------------------------------
-- 2: WRITE "YOU CAN'T ATTACK KISHIBE ROHAN"
---------------------------------------------------------------------------
local function cantAttack(S, player, state)
	local c = cfg.CantAttack
	if not ready(S, player, state, "CantAttack", 2) then
		return
	end
	local char, _, r = alive(S, player)
	local target = nearestBook(S, char, r, c.Range)
	if not target then
		S.tell(player, "Denied", { Reason = "NoBook" })
		S.fx("Ability", { Character = char, Act = ACT, Move = "Write", Phase = "NoBook" })
		return
	end
	S.startCooldown(player, state, "CantAttack", c.Cooldown, 2)
	S.lock(state, 0.35)
	writeCantAttack(char, target, c.Time, c.SilenceTime)
	S.fx("Ability", { Character = char, Act = ACT, Move = "Write", Phase = "CantAttack", Target = target, Time = c.Time })
end

---------------------------------------------------------------------------
-- 3: WRITE "FLY BACKWARDS AT 70 KM/H"
---------------------------------------------------------------------------
local function flyBack(S, player, state, aim)
	local c = cfg.FlyBack
	if not ready(S, player, state, "FlyBack", 3) then
		return
	end
	local char, _, r = alive(S, player)
	local target = nearestBook(S, char, r, c.Range)
	if not target then
		-- No book: he writes straight into someone right in front.
		target = Moves.findTarget(S, char, r, c.TouchRange, 70, Moves.flat(S.aim(aim, r)))
	end
	if not target then
		S.tell(player, "Denied", { Reason = "NoBook" })
		S.fx("Ability", { Character = char, Act = ACT, Move = "Write", Phase = "NoBook" })
		return
	end
	S.startCooldown(player, state, "FlyBack", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.2)
	local life = state.Life
	S.fx("Ability", { Character = char, Act = ACT, Move = "Write", Phase = "FlyWrite", Target = target, Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) or not aliveModel(target) then
			return
		end
		local tr = target:FindFirstChild("HumanoidRootPart")
		if not tr then
			return
		end
		-- Backwards: away from where they're facing.
		local back = -tr.CFrame.LookVector
		back = Vector3.new(back.X, 0, back.Z)
		back = back.Magnitude > 0.1 and back.Unit or Vector3.new(0, 0, 1)
		S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = back, Position = tr.Position, Source = "RohanFly", Unblockable = true })
		S.fx("Ability", { Act = ACT, Move = "Write", Phase = "Fly", Target = target, Direction = back })
	end)
end

function Rohan.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		openBook(S, player, state, aim)
	elseif slot == 2 then
		cantAttack(S, player, state)
	elseif slot == 3 then
		flyBack(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- EVERYONE IS A BOOK (ultimate)
---------------------------------------------------------------------------
function Rohan.Ultimate(S, player, state, aim)
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
		local books = {}
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, u.Radius, 20)) do
			if aliveModel(target) and makeBook(S, player, char, target, u.BookTime, u.CantAttackTime, u.Damage, "RohanUlt") then
				writeCantAttack(char, target, u.BookTime + u.CantAttackTime, 0)
				table.insert(books, target)
			end
		end
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Books", Position = r.Position, Radius = u.Radius, Targets = books, BookTime = u.BookTime })
	end)
end

function Rohan.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
	end
end

function Rohan.Init(S)
	-- Someone tries to hit him with the command written in them: nothing happens.
	local last = setmetatable({}, { __mode = "k" })
	S.Adapter.on("Written", function(writer)
		if not last[writer] or os.clock() - last[writer] > 1 then
			last[writer] = os.clock()
			S.fx("Ability", { Act = ACT, Move = "Write", Phase = "Refused", Target = writer })
		end
	end)
end

return Rohan
