--[[
	Sandman  (ServerScriptService.SpinServer.TuskActs.Sandman)

	Sandman (Soundman): IN A SILENT WAY. His Stand turns sounds into solid,
	written sound effects that do what they say when touched (cut, burn,
	explode). Registered as "Act" 8 so it reuses the Tusk ability system.
	  M1        SOUND CUT COMBO: chop, chop, spinning kick, a written sound that bursts
	  Ability 1 SOUND SLASH: a written "ZBAAK!" flies along the ground and cuts
	  Ability 2 SOUND TRAP: plants a written "DOGOOON" on the ground (up to 3);
	            the first enemy to step near it sets it off
	  Ability 3 SAND RUN: sprints straight through enemies (he's a runner),
	            hitting everyone in his path
	  Ultimate  SILENT SYMPHONY: gathers sound, rains written sounds down on the
	            area in front, the last one explodes
	Numbers: TuskConfig.Sandman. All damage goes through S.hit (CombatAdapter).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.Parent.TuskMoves)

local Sandman = {}
local cfg = TuskConfig.Sandman
local ACT = 8
local HAND = CFrame.new(0.9, 0.2, -1.8)

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Sandman.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- SOUND SLASH
---------------------------------------------------------------------------
local function soundSlash(S, player, state, aim)
	local c = cfg.SoundSlash
	if not ready(S, player, state, "SoundSlash", 1) then
		return
	end
	S.startCooldown(player, state, "SoundSlash", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.25)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "SoundSlash", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		S.fireWord(player, state, {
			Origin = S.origin(char, r, HAND) - Vector3.new(0, 1, 0),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Text = "ZBAAK!",
			Style = "Slash",
			OnHit = function(target, position)
				S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = direction, Position = position, Source = "SandmanSlash" })
			end,
		})
	end)
end

---------------------------------------------------------------------------
-- SOUND TRAP
---------------------------------------------------------------------------
local function clearTraps(S, state)
	for _, trap in ipairs(state.SoundTraps or {}) do
		S.fx("Ability", { Act = ACT, Move = "SoundTrap", Phase = "Expire", Id = trap.Id, Position = trap.Position })
	end
	state.SoundTraps = {}
end

local function soundTrap(S, player, state, aim)
	local c = cfg.SoundTrap
	if not ready(S, player, state, "SoundTrap", 2) then
		return
	end
	S.startCooldown(player, state, "SoundTrap", c.Cooldown, 2)
	S.lock(state, c.Startup + 0.2)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "SoundTrap", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		state.SoundTraps = state.SoundTraps or {}
		-- Oldest trap goes when the limit is reached.
		if #state.SoundTraps >= c.MaxTraps then
			local old = table.remove(state.SoundTraps, 1)
			S.fx("Ability", { Act = ACT, Move = "SoundTrap", Phase = "Expire", Id = old.Id, Position = old.Position })
		end
		local spot = Moves.safeStep(char, r, direction, c.Distance) or (r.Position + direction * 3)
		local ground = Moves.groundBelow(spot, { char })
		local trap = { Id = tostring(os.clock()) .. player.UserId, Position = ground, Until = os.clock() + c.Lifetime }
		table.insert(state.SoundTraps, trap)
		S.fx("Ability", { Character = char, Act = ACT, Move = "SoundTrap", Phase = "Place", Id = trap.Id, Position = ground, Lifetime = c.Lifetime })

		local function remove()
			for i, t in ipairs(state.SoundTraps or {}) do
				if t == trap then
					table.remove(state.SoundTraps, i)
					return true
				end
			end
			return false
		end
		local function check()
			if state.Life ~= life or not table.find(state.SoundTraps or {}, trap) then
				return
			end
			if os.clock() >= trap.Until then
				remove()
				S.fx("Ability", { Act = ACT, Move = "SoundTrap", Phase = "Expire", Id = trap.Id, Position = trap.Position })
				return
			end
			local center = trap.Position + Vector3.new(0, 2.5, 0)
			for _, target in ipairs(S.Hitbox.inRadius(player.Character, center, c.TriggerRadius, 1)) do
				if S.Adapter.canBeHit(player, target) then
					remove()
					S.fx("Ability", { Act = ACT, Move = "SoundTrap", Phase = "Boom", Id = trap.Id, Position = trap.Position, Radius = c.Radius })
					-- His other traps in the blast go off with it (one hit, a bit harder).
					local chained = 0
					for k = #state.SoundTraps, 1, -1 do
						local other = state.SoundTraps[k]
						if (other.Position - trap.Position).Magnitude <= c.Radius then
							table.remove(state.SoundTraps, k)
							chained = chained + 1
							S.fx("Ability", { Act = ACT, Move = "SoundTrap", Phase = "Boom", Id = other.Id, Position = other.Position, Radius = c.Radius })
						end
					end
					Moves.aoe(S, player, center, c.Radius, { Damage = c.Damage + chained * (c.ChainBonus or 2), Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Source = "SandmanTrap" }, 6)
					return
				end
			end
			task.delay(c.CheckEvery, check)
		end
		task.delay(c.CheckEvery, check)
	end)
end

---------------------------------------------------------------------------
-- SAND RUN
---------------------------------------------------------------------------
local function sandRun(S, player, state, aim)
	local c = cfg.SandRun
	if not ready(S, player, state, "SandRun", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local destination = Moves.safeStep(character, root, direction, c.Distance)
	if not destination then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "SandRun", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.3)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "SandRun", Phase = "Startup", Windup = c.Windup, Direction = direction })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local from = r.Position
		local to = Moves.safeStep(char, r, direction, c.Distance) or destination
		local length = (to - from).Magnitude
		char:SetAttribute(S.Adapter.Settings.IFrameAttribute, true)
		char:PivotTo(CFrame.lookAt(to, to + direction))
		-- Everyone along the path gets hit.
		local mid = (from + to) / 2
		local box = CFrame.lookAt(mid, mid + direction)
		local _, hitSet = Moves.boxHit(S, player, box, Vector3.new(c.Width, 6, length + 2), { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = direction, Source = "SandmanRun" }, 5)
		local hits = {}
		for target in pairs(hitSet) do
			table.insert(hits, target)
		end
		S.fx("Ability", { Character = char, Act = ACT, Move = "SandRun", Phase = "Run", From = from, To = to, Direction = direction, Targets = hits })
		task.delay(0.25, function()
			if char.Parent then
				char:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
			end
		end)
	end)
end

function Sandman.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		soundSlash(S, player, state, aim)
	elseif slot == 2 then
		soundTrap(S, player, state, aim)
	elseif slot == 3 then
		sandRun(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- SILENT SYMPHONY (ultimate)
---------------------------------------------------------------------------
function Sandman.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	local center = Moves.groundBelow(root.Position + direction * u.Distance, { character })
	S.lock(state, u.Windup + u.Waves * u.WaveEvery + 0.4)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Start", Windup = u.Windup, Position = center, Radius = u.Radius, Direction = direction })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		S.finishUltimate(player, state)
		local up = center + Vector3.new(0, 2.5, 0)
		for wave = 1, u.Waves do
			task.delay((wave - 1) * u.WaveEvery, function()
				if state.Life ~= life then
					return
				end
				S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Wave", Wave = wave, Position = center, Radius = u.Radius })
				Moves.aoe(S, player, up, u.Radius, { Damage = u.WaveDamage, Stun = u.WaveStun, Knockback = 0, Source = "SandmanSymphony" }, 8)
			end)
		end
		task.delay(u.Waves * u.WaveEvery, function()
			if state.Life ~= life then
				return
			end
			Moves.aoe(S, player, up, u.Radius + 1, { Damage = u.FinalDamage, Stun = u.FinalStun, Knockback = u.FinalKnockback, Launch = u.FinalLaunch, Source = "SandmanSymphony" }, 8)
			S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Final", Position = center, Radius = u.Radius + 1 })
		end)
	end)
end

function Sandman.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
	end
	clearTraps(S, state)
end

return Sandman
