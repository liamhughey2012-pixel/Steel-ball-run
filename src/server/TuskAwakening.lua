--[[
	TuskAwakening  (ServerScriptService.SpinServer.TuskAwakening)

	Johnny's AWAKENING (G on Tusk Acts 1-3): INFINITE ROTATION. A golden
	spinning nail charged with the Golden Rotation fires (stronger each Act),
	blasts where it lands, and Tusk AWAKENS one Act higher (1 -> 2 -> 3 -> 4).
	Act 4's own ultimate is the full Infinite Rotation (TuskAct4).
	You can't pick your Act: awakening is the only way up, and dying sends
	you back to Act 1 (TuskConfig.Progression).
	Numbers: TuskConfig.Awakening (one value per Act 1-3).
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Moves = require(script.Parent.TuskMoves)

local TuskAwakening = {}

local function pick(list, act)
	if type(list) ~= "table" then
		return list
	end
	return list[math.clamp(act, 1, #list)]
end

function TuskAwakening.use(S, player, state, aim)
	local cfg = TuskConfig.Awakening
	local act = state.Act or 1
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = S.Adapter.getAlive(player)
	local direction = S.aim(aim, root)
	local life = state.Life
	local windup = pick(cfg.Windup, act)
	S.lock(state, windup + 0.6)
	character:SetAttribute("Armored", true)
	-- The Infinite Rotation visuals (Act 4's), scaled by the Act.
	S.fx("Ultimate", { Character = character, Act = 4, Phase = "Start", Windup = windup, Direction = direction, Awakening = act })
	task.delay(windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not S.Adapter.getAlive(player) then
			return
		end
		local _, _, r = S.Adapter.getAlive(player)
		S.fx("Ultimate", { Character = character, Act = 4, Phase = "Release", Position = r.Position, Direction = direction, Awakening = act })
		local directHit = {}
		local blastRadius, blastDamage = pick(cfg.BlastRadius, act), pick(cfg.BlastDamage, act)
		Moves.nail(S, player, state, {
			Origin = S.origin(character, r, CFrame.new(0, 2, -4)),
			Direction = direction,
			Speed = cfg.Speed,
			Radius = pick(cfg.ProjectileRadius, act),
			Range = cfg.Range,
			Style = "InfiniteUlt",
			Charge = 1,
			Damage = pick(cfg.Damage, act),
			Stun = cfg.Stun,
			Knockback = cfg.Knockback,
			Launch = cfg.Launch,
			Source = "TuskAwakening",
			OnEnd = function(position, _, hitCharacter)
				if hitCharacter then
					directHit[hitCharacter] = true
				end
				Moves.aoe(S, player, position, blastRadius, { Damage = blastDamage, Stun = 0.4, Knockback = 30, Launch = 12, Source = "TuskAwakening" }, 6, directHit)
			end,
		})
		-- ...and Tusk awakens one Act higher.
		S.finishUltimate(player, state)
	end)
end

return TuskAwakening
