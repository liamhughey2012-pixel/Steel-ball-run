--[[
	Spin_Server  (Script)
	PUT IT IN: ServerScriptService

	Spin Battlegrounds server: Johnny Joestar (Tusk Acts 1-4 + Tusk Sneak),
	Gyro Zeppeli (Steel Balls), combat,
	cooldowns, projectiles, NPCs, Studio practice dummies, and the SBR map
	(built automatically when the server starts).

	Needs these ModuleScripts in ReplicatedStorage: SpinConfig, TuskConfig.
	Works with the LocalScript Spin_Client in StarterPlayerScripts.

	MAP SETTINGS (change here):
]]
-- Safety check: this code must be in a Script in ServerScriptService.
if not game:GetService("RunService"):IsServer() or script:IsA("LocalScript") then
	error("[Spin] This is the Spin_SERVER code. It must go in a Script in ServerScriptService, not a LocalScript. Paste Spin_Client.lua into the LocalScript instead.")
end

local BUILD_MAP_ON_START = true -- false = don't build the SBR map
local MAP_ORIGIN = Vector3.new(0, 0, 0) -- move the map away from an existing one, e.g. Vector3.new(1500, 0, 0)

local __modules = {}
local __loaded = {}
local function __hasModule(name)
	return __modules[name] ~= nil
end
local function __require(name)
	local value = __loaded[name]
	if value == nil then
		local loader = __modules[name]
		assert(loader, "[Spin] missing bundled module: " .. tostring(name))
		value = loader()
		__loaded[name] = value
	end
	return value
end

-- ======================================================================
-- MODULE: Blockify
-- ======================================================================
__modules["Blockify"] = function()
--[[
	Blockify  (ReplicatedStorage.SpinShared.Blockify)

	Turns a part-built model into a blocky (classic Roblox) look while
	keeping each model recognisable:
	  * small round pieces (eyes, studs, tips) become single boxes
	  * BIG round pieces (Tusk's egg body, heads, shoulder balls) become a
	    "voxel-round" shape: a core box plus three crossing boxes, so the
	    outline is a stepped, pixel-art circle instead of a plain cube
	  * flat discs (Act 2's rings) stay circular the same stepped way
	  * long cylinders become square rods
	Part centres don't move. The extra boxes are welded to the original part,
	so welds, rigs, fades and animations keep working. Models whose parts are
	moved one by one (the raptor) pass { Voxel = false } for single boxes.
	Used by the Tusk Stands and the Scary Monsters raptor when
	TuskConfig.BlockyModels is true. A part with the attribute KeepRound
	is left alone.
]]

local Blockify = {}

local ROUND = 0.82 -- single box vs. sphere diameter (similar silhouette)
local ROD = 0.88 -- square rod vs. cylinder diameter
local BIG = 0.7 -- studs: round pieces at least this big get the voxel-round shape
local CORE, ARM = 0.86, 0.62 -- voxel-round: core box and the thin side of the crossing boxes

-- A box welded on top of `part`, copying its look.
local function extraBox(part, size)
	local p = Instance.new("Part")
	p.Name = part.Name .. "Block"
	p.Size = size
	p.Color = part.Color
	p.Material = part.Material
	p.Reflectance = part.Reflectance
	p.Transparency = part.Transparency
	p.CastShadow = part.CastShadow
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = part.CFrame
	local weld = Instance.new("Weld")
	weld.Part0 = part
	weld.Part1 = p
	weld.C0 = CFrame.new()
	weld.Parent = p
	p.Parent = part.Parent
	return p
end

-- Stepped round shape for a piece of size s (core + crossing boxes on the axes in `axes`).
local function voxelRound(part, s, axes)
	part.Size = s * CORE
	for _, axis in ipairs(axes) do
		local x = axis == "X" and s.X or s.X * ARM
		local y = axis == "Y" and s.Y or s.Y * ARM
		local z = axis == "Z" and s.Z or s.Z * ARM
		extraBox(part, Vector3.new(x, y, z))
	end
end

local function convert(part, opts)
	if part:GetAttribute("KeepRound") or (opts.KeepRound and opts.KeepRound[part.Name]) then
		return
	end
	local canAdd = opts.Voxel ~= false and part.Parent ~= nil
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if mesh and mesh.MeshType == Enum.MeshType.Sphere then
		mesh:Destroy()
		local s = part.Size
		if canAdd and math.max(s.X, s.Y, s.Z) >= BIG then
			voxelRound(part, s, { "X", "Y", "Z" })
		else
			part.Size = s * ROUND
		end
		return
	end
	if part:IsA("Part") then
		if part.Shape == Enum.PartType.Ball then
			part.Shape = Enum.PartType.Block
			local s = part.Size
			if canAdd and s.X >= BIG then
				voxelRound(part, s, { "X", "Y", "Z" })
			else
				part.Size = s * ROUND
			end
		elseif part.Shape == Enum.PartType.Cylinder then
			-- Cylinder length runs along X; its round face is in Y/Z.
			part.Shape = Enum.PartType.Block
			local s = part.Size
			local diameter = math.min(s.Y, s.Z)
			if canAdd and diameter >= BIG and s.X < diameter * 0.6 then
				-- A disc / wheel / ring: keep it round (stepped) in its face.
				part.Size = Vector3.new(s.X, s.Y * CORE, s.Z * CORE)
				extraBox(part, Vector3.new(s.X, s.Y, s.Z * ARM))
				extraBox(part, Vector3.new(s.X, s.Y * ARM, s.Z))
			else
				part.Size = Vector3.new(s.X, s.Y * ROD, s.Z * ROD)
			end
		end
	end
end

-- opts.Voxel = false: single boxes only (for models whose parts are moved one
-- by one, like the raptor rig).
-- opts.KeepRound = { [partName] = true }: signature round pieces left smooth.
function Blockify.apply(model, opts)
	opts = opts or {}
	local parts = {}
	if model:IsA("BasePart") then
		table.insert(parts, model)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	-- (collected first so the boxes added along the way aren't converted again)
	for _, p in ipairs(parts) do
		convert(p, opts)
	end
	return model
end

-- True when the game wants blocky models (TuskConfig.BlockyModels, default on).
function Blockify.enabled(config)
	return not (config and config.BlockyModels == false)
end

return Blockify
end

-- ======================================================================
-- MODULE: CombatAdapter
-- ======================================================================
__modules["CombatAdapter"] = function()
--[[
	CombatAdapter  (ServerScriptService.SpinServer.CombatAdapter)

	THE ONE PLACE the Spin system touches combat. If SPIN BATTLEGROUNDS
	already has a combat framework (damage, stun, block), plug it into the
	Hooks table below instead of letting this file use its defaults. That
	way there is never a second, competing combat system.

	Example (in your own server code, before players join):
		local Adapter = require(ServerScriptService.SpinServer.CombatAdapter)
		Adapter.Hooks.ApplyDamage = function(attacker, humanoid, amount, info)
			YourCombat.Damage(attacker, humanoid, amount)
		end
		Adapter.Hooks.IsBlocking = function(character)
			return YourCombat.IsBlocking(character)
		end
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Net = __require("Net")
local FX = Net.get("SpinFX")

local Adapter = {}

Adapter.Settings = {
	FriendlyFire = false, -- same-Team players can't hit each other
	BlockAttribute = "Blocking", -- character attribute your block sets
	BlockDamageMultiplier = 0.35,
	BlockKnockbackMultiplier = 0.3,
	IFrameAttribute = "IFrames", -- character attribute = invulnerable (dashes etc.)
	ArmorAttribute = "Armored", -- character attribute = takes damage but no stun/knockback (ult wind-ups)
	MaxKnockback = 90, -- hard cap so no move can fling players across the map
	MaxStun = 1.0, -- hard cap on any single stun
	StunAttribute = "Stunned",
	StunWalkSpeedMultiplier = 0.15,
	StunImmunityAfter = 0.5, -- seconds after a stun ends where no new stun applies
	KnockbackDuration = 0.18,
}

-- Optional overrides. Leave nil to use the defaults in this file.
Adapter.Hooks = {
	ApplyDamage = nil, -- function(attackerPlayer, humanoid, amount, info)
	ApplyStun = nil, -- function(humanoid, duration) -> applied:boolean
	IsBlocking = nil, -- function(character) -> boolean
	CanAct = nil, -- function(player) -> boolean (extra checks: ragdoll, menus...)
	CanBeHit = nil, -- function(attackerPlayer, targetCharacter) -> boolean
}

local moveMods = setmetatable({}, { __mode = "k" }) -- humanoid -> { mods = {}, product = 1 }
local stunState = setmetatable({}, { __mode = "k" }) -- humanoid -> { token, immuneUntil }

function Adapter.getAlive(player)
	local character = player and player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end
	return character, humanoid, root
end

function Adapter.isStunned(character)
	return character:GetAttribute(Adapter.Settings.StunAttribute) == true
end

function Adapter.canAct(player)
	local character = Adapter.getAlive(player)
	if not character then
		return false
	end
	if Adapter.isStunned(character) then
		return false
	end
	-- Turned into Diego's dinosaur (Scary Monsters): Diego is in control.
	if character:GetAttribute("DinoThrall") then
		return false
	end
	if Adapter.Hooks.CanAct and not Adapter.Hooks.CanAct(player) then
		return false
	end
	return true
end

function Adapter.canBeHit(attackerPlayer, targetCharacter)
	if not targetCharacter or (attackerPlayer and targetCharacter == attackerPlayer.Character) then
		return false
	end
	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	if targetCharacter:GetAttribute(Adapter.Settings.IFrameAttribute) == true then
		return false
	end
	if targetCharacter:FindFirstChildOfClass("ForceField") then
		return false
	end
	-- Diego can't hurt the dinosaur he is commanding.
	if attackerPlayer and targetCharacter:GetAttribute("DinoThrall") == attackerPlayer.UserId then
		return false
	end
	if not Adapter.Settings.FriendlyFire and attackerPlayer then
		local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
		if targetPlayer and not attackerPlayer.Neutral and not targetPlayer.Neutral and targetPlayer.Team == attackerPlayer.Team then
			return false
		end
	end
	if Adapter.Hooks.CanBeHit and not Adapter.Hooks.CanBeHit(attackerPlayer, targetCharacter) then
		return false
	end
	return true
end

-- Stackable walk-speed multipliers keyed by source ("SpinCharge", "Stun"...).
function Adapter.setMoveModifier(humanoid, key, multiplier)
	local state = moveMods[humanoid]
	if not state then
		state = { mods = {}, product = 1 }
		moveMods[humanoid] = state
	end
	local base = humanoid.WalkSpeed / state.product
	state.mods[key] = multiplier
	local product = 1
	for _, m in pairs(state.mods) do
		product = product * m
	end
	state.product = product
	humanoid.WalkSpeed = base * product
end

function Adapter.isBlocking(character)
	if Adapter.Hooks.IsBlocking then
		return Adapter.Hooks.IsBlocking(character) == true
	end
	return character:GetAttribute(Adapter.Settings.BlockAttribute) == true
end

function Adapter.applyStun(humanoid, duration)
	duration = math.min(duration, Adapter.Settings.MaxStun)
	if duration <= 0 then
		return false
	end
	if humanoid.Parent and humanoid.Parent:GetAttribute(Adapter.Settings.ArmorAttribute) == true then
		return false
	end
	if Adapter.Hooks.ApplyStun then
		return Adapter.Hooks.ApplyStun(humanoid, duration)
	end
	local character = humanoid.Parent
	local state = stunState[humanoid] or { token = 0, immuneUntil = 0 }
	stunState[humanoid] = state
	local now = os.clock()
	if now < state.immuneUntil and not Adapter.isStunned(character) then
		return false -- anti stun-lock
	end
	state.token = state.token + 1
	local token = state.token
	character:SetAttribute(Adapter.Settings.StunAttribute, true)
	Adapter.setMoveModifier(humanoid, "Stun", Adapter.Settings.StunWalkSpeedMultiplier)
	task.delay(duration, function()
		if state.token ~= token or not humanoid.Parent then
			return
		end
		character:SetAttribute(Adapter.Settings.StunAttribute, nil)
		Adapter.setMoveModifier(humanoid, "Stun", nil)
		state.immuneUntil = os.clock() + Adapter.Settings.StunImmunityAfter
	end)
	return true
end

function Adapter.applyKnockback(character, direction, strength, upward)
	local root = character:FindFirstChild("HumanoidRootPart")
	strength = math.min(strength or 0, Adapter.Settings.MaxKnockback)
	upward = upward or strength * 0.3
	if not root or (strength <= 0 and upward <= 0) then
		return
	end
	if character:GetAttribute(Adapter.Settings.ArmorAttribute) == true then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		flat = -root.CFrame.LookVector
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "SpinKnockback"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = flat.Unit * strength + Vector3.new(0, math.min(upward, Adapter.Settings.MaxKnockback), 0)
	velocity.Parent = attachment
	Debris:AddItem(attachment, Adapter.Settings.KnockbackDuration)
end

--[[
	dealHit: the only entry point for Spin damage. Server only.
	info = { Damage, Stun, Knockback, Launch?, Direction, Position, Level, Perfect, Source }
	Returns: hit:boolean, damageDealt:number
]]
function Adapter.dealHit(attackerPlayer, targetCharacter, info)
	if not Adapter.canBeHit(attackerPlayer, targetCharacter) then
		return false
	end
	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	local blocked = Adapter.isBlocking(targetCharacter)
	local s = Adapter.Settings

	local damage = info.Damage * (blocked and s.BlockDamageMultiplier or 1)
	local knockback = info.Knockback * (blocked and s.BlockKnockbackMultiplier or 1)

	if Adapter.Hooks.ApplyDamage then
		Adapter.Hooks.ApplyDamage(attackerPlayer, humanoid, damage, info)
	else
		humanoid:TakeDamage(damage)
	end
	if not blocked then
		Adapter.applyStun(humanoid, info.Stun or 0)
	end
	local launch = info.Launch and info.Launch * (blocked and s.BlockKnockbackMultiplier or 1) or nil
	Adapter.applyKnockback(targetCharacter, info.Direction, knockback, launch)

	FX:FireAllClients("Hit", {
		Position = info.Position,
		Level = info.Level,
		Perfect = info.Perfect,
		Blocked = blocked,
		Victim = targetCharacter,
		Source = info.Source,
		AttackerId = attackerPlayer and attackerPlayer.UserId or 0,
	})
	if attackerPlayer then
		FX:FireClient(attackerPlayer, "Damage", {
			Position = info.Position,
			Amount = math.floor(damage + 0.5),
			Blocked = blocked,
			Perfect = info.Perfect,
		})
	end
	return true, damage
end

return Adapter
end

-- ======================================================================
-- MODULE: CooldownService
-- ======================================================================
__modules["CooldownService"] = function()
--[[
	CooldownService  (ServerScriptService.SpinServer.CooldownService)
	Server-owned cooldowns. Clients only ever display what the server says.
	Reusable by any ability: CooldownService.start(player, "AbilityKey", seconds)
]]

local Players = game:GetService("Players")

local CooldownService = {}
local readyAt = {} -- [player] = { [key] = os.clock() time when ready }

function CooldownService.remaining(player, key)
	local list = readyAt[player]
	local t = list and list[key]
	if not t then
		return 0
	end
	return math.max(0, t - os.clock())
end

function CooldownService.isReady(player, key)
	return CooldownService.remaining(player, key) <= 0
end

function CooldownService.start(player, key, duration)
	local list = readyAt[player]
	if not list then
		list = {}
		readyAt[player] = list
	end
	list[key] = os.clock() + duration
end

function CooldownService.reset(player, key)
	if readyAt[player] then
		readyAt[player][key] = nil
	end
end

Players.PlayerRemoving:Connect(function(player)
	readyAt[player] = nil
end)

return CooldownService
end

-- ======================================================================
-- MODULE: DiegoBrando
-- ======================================================================
__modules["DiegoBrando"] = function()
--[[
	DiegoBrando  (ServerScriptService.SpinServer.TuskActs.DiegoBrando)

	Diego Brando: SCARY MONSTERS (dinosaur Stand). Registered as "Act" 6 so it
	reuses the Tusk ability system (cooldowns, HUD, ultimate meter, input).
	  M1        CLAW COMBO: claw, claw, tail whip, bite (area). Stronger and
	            faster while transformed.
	  Ability 1 RAPTOR POUNCE: crouch, then leap at the nearest enemy in front
	            and land on them (bite + area hit). Hits harder transformed.
	  Ability 2 DINO INFECTION: an infecting bite. Scales spread over the
	            victim, then they TURN INTO A DINOSAUR (in their own avatar's
	            colours) that Diego commands for ThrallTime seconds: it heels
	            beside him and bites nearby enemies; press the move again to
	            send it after whoever Diego aims at. 25 s cooldown on a hit.
	  Ability 3 SCARY MONSTERS: turn into a full raptor for a while: faster,
	            stronger claws, and KINETIC VISION (moving enemies glow for
	            Diego). Press again to change back early.
	  Ultimate  RAPTOR PACK: a roar that stuns everyone close, then a pack of
	            raptors charges out in a fan, mauling everything in their path
	Numbers: TuskConfig.Diego. All damage goes through S.hit (CombatAdapter).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Diego = {}
local cfg = TuskConfig.Diego
local ACT = 6

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Diego.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, state.DinoMode and cfg.DinoM1 or cfg.M1, ACT)
end

---------------------------------------------------------------------------
-- SCARY MONSTERS (transformation)
---------------------------------------------------------------------------
local function revert(S, player, state, startCooldown)
	if not state.DinoMode then
		return
	end
	state.DinoMode = nil
	local character = state.Character
	if character then
		character:SetAttribute("DinoMode", nil)
		character:SetAttribute("DinoModeUntil", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "ScaryMonsters", nil)
		end
		S.fx("Ability", { Character = character, Act = ACT, Move = "ScaryMonsters", Phase = "Revert" })
	end
	if startCooldown then
		S.startCooldown(player, state, "ScaryMonsters", cfg.ScaryMonsters.Cooldown, 3)
	end
end

local function scaryMonsters(S, player, state)
	local c = cfg.ScaryMonsters
	if state.DinoMode then
		revert(S, player, state, true) -- press again: change back early
		return
	end
	if not ready(S, player, state, "ScaryMonsters", 3) then
		return
	end
	local character, humanoid = alive(S, player)
	local token = {}
	state.DinoMode = token
	S.lock(state, c.Transform)
	character:SetAttribute("Armored", true)
	S.fx("Ability", { Character = character, Act = ACT, Move = "ScaryMonsters", Phase = "Transform", Duration = c.Transform })
	task.delay(c.Transform * 0.6, function()
		if state.DinoMode ~= token or not character.Parent then
			return
		end
		character:SetAttribute("DinoMode", true)
		character:SetAttribute("DinoModeUntil", workspace:GetServerTimeNow() + c.Duration)
		S.Adapter.setMoveModifier(humanoid, "ScaryMonsters", c.SpeedMultiplier)
	end)
	task.delay(c.Transform, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
	end)
	task.delay(c.Duration + c.Transform * 0.6, function()
		if state.DinoMode == token then
			revert(S, player, state, true)
		end
	end)
end

---------------------------------------------------------------------------
-- RAPTOR POUNCE
---------------------------------------------------------------------------
local function raptorPounce(S, player, state, aim)
	local c = cfg.RaptorPounce
	if not ready(S, player, state, "RaptorPounce", 1) then
		return
	end
	S.startCooldown(player, state, "RaptorPounce", c.Cooldown, 1)
	S.lock(state, c.Windup + c.LeapTime + 0.2)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "RaptorPounce", Phase = "Startup", Windup = c.Windup, Direction = direction })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		-- Leap at the nearest enemy in front, or straight ahead.
		local distance = c.Distance
		local target = Moves.findTarget(S, char, r, c.Distance, c.TargetCone, direction)
		local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			local offset = targetRoot.Position - r.Position
			local flatOffset = Vector3.new(offset.X, 0, offset.Z)
			if flatOffset.Magnitude > 0.5 then
				direction = flatOffset.Unit
				distance = math.max(4, flatOffset.Magnitude - 2.5)
			end
		end
		local destination = Moves.safeStep(char, r, direction, distance)
		local from = r.Position
		local to = destination or from -- blocked: a short hop in place
		-- The leap itself is flown by Diego's own client (it owns his physics, so the
		-- arc is smooth for everyone). The server decides where it lands and hits there.
		S.fx("Ability", { Character = char, Act = ACT, Move = "RaptorPounce", Phase = "Leap", From = from, To = to, Time = c.LeapTime, Height = c.LeapHeight, Direction = direction })
		-- (a little extra time so a client that started the leap late isn't corrected mid-air)
		task.delay(c.LeapTime + (c.LandGrace or 0.12), function()
			if not S.stillValid(player, state, life) then
				return -- stunned or died mid-leap: no landing hit
			end
			local _, _, rr = alive(S, player)
			if not rr then
				return
			end
			-- If the client didn't arrive (lag, blocked), put Diego where the leap ends.
			if (rr.Position - to).Magnitude > 10 then
				char:PivotTo(CFrame.lookAt(to, to + direction))
			end
			local damage = c.Damage * (state.DinoMode and cfg.ScaryMonsters.PounceMultiplier or 1)
			local landAt = to + direction * 1.5
			local count = Moves.aoe(S, player, landAt, c.HitRadius, { Damage = damage, Stun = c.Stun, Knockback = c.Knockback, Direction = direction, Source = "DiegoPounce" }, 4)
			S.fx("Ability", { Character = char, Act = ACT, Move = "RaptorPounce", Phase = "Land", Position = to, Direction = direction, Radius = c.HitRadius, Hit = count > 0 })
		end)
	end)
end

---------------------------------------------------------------------------
-- DINO INFECTION: the bite turns the victim into a dinosaur (in their own
-- avatar's colours, drawn by the clients) that Diego commands for a while.
---------------------------------------------------------------------------
local Players = game:GetService("Players")

local function releaseThrall(S, player, state)
	local thrall = state.Thrall
	if not thrall then
		return
	end
	state.Thrall = nil
	local target = thrall.Target
	if target and target.Parent then
		target:SetAttribute("DinoThrall", nil)
		target:SetAttribute("DinoThrallUntil", nil)
		target:SetAttribute("DinoInfected", nil)
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		local root = target:FindFirstChild("HumanoidRootPart")
		if humanoid then
			S.Adapter.setMoveModifier(humanoid, "DinoThrall", nil)
			if root then
				humanoid:MoveTo(root.Position)
			end
		end
		-- Hand movement back to the player who owns this character.
		if root and thrall.Player then
			pcall(function()
				root:SetNetworkOwner(thrall.Player)
			end)
		end
		S.fx("Ability", { Act = ACT, Move = "DinoInfection", Phase = "Release", Target = target })
	end
	if state.Character then
		state.Character:SetAttribute("ThrallUntil", nil)
	end
end

-- Pick the thrall's prey: Diego's command target, else the nearest enemy close by.
local function preyFor(S, player, thrall, c)
	local forced = thrall.Command
	if forced and forced.Until > os.clock() and forced.Target.Parent and S.Adapter.canBeHit(player, forced.Target) then
		return forced.Target, true
	end
	thrall.Command = nil
	local tr = thrall.Target:FindFirstChild("HumanoidRootPart")
	if not tr then
		return nil
	end
	local best, bestDistance
	for _, enemy in ipairs(S.Hitbox.inRadius(player.Character, tr.Position, c.ThrallAggroRange, 6)) do
		if enemy ~= thrall.Target and S.Adapter.canBeHit(player, enemy) then
			local er = enemy:FindFirstChild("HumanoidRootPart")
			local d = er and (er.Position - tr.Position).Magnitude
			if d and (not bestDistance or d < bestDistance) then
				best, bestDistance = enemy, d
			end
		end
	end
	return best, false
end

local function enthrall(S, player, state, target, c)
	releaseThrall(S, player, state)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	local root = target:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	local token = {}
	local thrall = { Target = target, Player = Players:GetPlayerFromCharacter(target), Token = token, NextBite = 0 }
	state.Thrall = thrall
	local untilT = workspace:GetServerTimeNow() + c.ThrallTime
	-- 1) the infection spreads (scales grow), 2) they become a dinosaur.
	target:SetAttribute("DinoInfected", tostring(token))
	task.delay(c.SpreadTime, function()
		if state.Thrall ~= thrall or not target.Parent or humanoid.Health <= 0 then
			return
		end
		target:SetAttribute("DinoThrall", player.UserId)
		target:SetAttribute("DinoThrallUntil", untilT + c.SpreadTime)
		if state.Character then
			state.Character:SetAttribute("ThrallUntil", untilT + c.SpreadTime)
		end
		S.Adapter.setMoveModifier(humanoid, "DinoThrall", c.ThrallSpeed)
		-- The server takes over the body so Diego's commands drive it.
		if thrall.Player then
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
		end
		S.fx("Ability", { Act = ACT, Move = "DinoInfection", Phase = "Turn", Target = target, Position = root.Position })
	end)
	-- Brain: every tick, chase prey (bite when close) or heel beside Diego.
	local ticks = math.floor((c.ThrallTime + c.SpreadTime) / c.ThrallTick)
	for i = 1, ticks do
		task.delay(i * c.ThrallTick, function()
			if state.Thrall ~= thrall or i * c.ThrallTick < c.SpreadTime then
				return
			end
			if not target.Parent or humanoid.Health <= 0 then
				releaseThrall(S, player, state)
				return
			end
			local _, _, diegoRoot = alive(S, player)
			local tr = target:FindFirstChild("HumanoidRootPart")
			if not diegoRoot or not tr then
				releaseThrall(S, player, state)
				return
			end
			local prey, commanded = preyFor(S, player, thrall, c)
			local pr = prey and prey:FindFirstChild("HumanoidRootPart")
			if pr then
				humanoid:MoveTo(pr.Position)
				if (pr.Position - tr.Position).Magnitude <= c.ThrallBiteRange and os.clock() >= thrall.NextBite then
					thrall.NextBite = os.clock() + c.ThrallBiteInterval
					local dir = pr.Position - tr.Position
					S.hit(player, prey, { Damage = commanded and c.CommandDamage or c.ThrallDamage, Stun = 0.45, Knockback = 10, Direction = dir, Position = pr.Position, Source = "DiegoThrall" })
					S.fx("Ability", { Act = ACT, Move = "DinoInfection", Phase = "ThrallBite", Target = target, Position = pr.Position, Direction = dir })
				end
			else
				-- Heel: stay just behind Diego's shoulder.
				local spot = diegoRoot.Position - diegoRoot.CFrame.LookVector * 5 + diegoRoot.CFrame.RightVector * 4
				if (spot - tr.Position).Magnitude > 3 then
					humanoid:MoveTo(spot)
				end
			end
		end)
	end
	task.delay(c.ThrallTime + c.SpreadTime, function()
		if state.Thrall == thrall then
			releaseThrall(S, player, state)
		end
	end)
end

-- While a dinosaur is under control, pressing the move again sends it after
-- whoever Diego is aiming at ("sic 'em").
local function commandThrall(S, player, state, aim, c)
	local character, _, root = alive(S, player)
	local thrall = state.Thrall
	local direction = Moves.flat(S.aim(aim, root))
	local prey = Moves.findTarget(S, character, root, c.CommandRange, c.CommandCone, direction)
	if prey == thrall.Target then
		prey = nil
	end
	if not prey then
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	thrall.Command = { Target = prey, Until = os.clock() + c.CommandTime }
	thrall.NextBite = 0
	local pr = prey:FindFirstChild("HumanoidRootPart")
	S.fx("Ability", { Character = character, Act = ACT, Move = "DinoInfection", Phase = "Command", Target = thrall.Target, Prey = prey, Position = pr and pr.Position or root.Position })
end

local function dinoInfection(S, player, state, aim)
	local c = cfg.DinoInfection
	if state.Thrall and state.Thrall.Target:GetAttribute("DinoThrall") then
		commandThrall(S, player, state, aim, c)
		return
	end
	if not ready(S, player, state, "DinoInfection", 2) then
		return
	end
	S.lock(state, c.Windup + 0.35)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "DinoInfection", Phase = "Startup", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local _, _, r = alive(S, player)
		local cf = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
		local count, hitSet = Moves.boxHit(S, player, cf, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Source = "DiegoInfection" }, 1)
		local victim = next(hitSet)
		if victim then
			S.startCooldown(player, state, "DinoInfection", c.Cooldown, 2)
			enthrall(S, player, state, victim, c)
		else
			S.startCooldown(player, state, "DinoInfection", c.MissCooldown, 2) -- missed: short cooldown
		end
		S.fx("Ability", { Character = character, Act = ACT, Move = "DinoInfection", Phase = "Hit", Position = cf.Position, Hit = count > 0 })
	end)
end

function Diego.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		raptorPounce(S, player, state, aim)
	elseif slot == 2 then
		dinoInfection(S, player, state, aim)
	elseif slot == 3 then
		scaryMonsters(S, player, state)
	end
end

---------------------------------------------------------------------------
-- RAPTOR PACK (ultimate)
---------------------------------------------------------------------------
function Diego.Ultimate(S, player, state, aim)
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
	S.lock(state, u.Windup + 0.3)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Roar", Position = root.Position, Radius = u.RoarRadius, Windup = u.Windup, Direction = direction })
	-- The roar: stuns everyone close.
	task.delay(u.Windup * 0.35, function()
		if state.Life ~= life then
			return
		end
		local _, _, r = alive(S, player)
		if r then
			Moves.aoe(S, player, r.Position, u.RoarRadius, { Damage = u.RoarDamage, Stun = u.RoarStun, Knockback = 6, Source = "DiegoRoar" }, 8)
		end
	end)
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local char, _, r = alive(S, player)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local raptors = {}
		local bitten = {} -- target -> how many raptors have bitten it
		local maxBites = u.MaxHitsPerTarget or 2
		local baseId = tostring(os.clock()) .. player.UserId
		for i = 1, u.Count do
			local angle = math.rad((i - (u.Count + 1) / 2) * u.Spread)
			local dir = (CFrame.Angles(0, angle, 0) * CFrame.lookAt(Vector3.new(), direction)).LookVector
			dir = Moves.flat(dir)
			local origin = Moves.groundBelow(r.Position + dir * 2, { char })
			raptors[i] = { Id = baseId .. "_" .. i, Origin = origin, Direction = dir, Pos = origin, Traveled = 0, Hit = {}, Done = false }
		end
		local payload = {}
		for i, rp in ipairs(raptors) do
			payload[i] = { Id = rp.Id, Origin = rp.Origin, Direction = rp.Direction }
		end
		S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Release", Raptors = payload, Speed = u.Speed, Range = u.Range })
		local ticks = math.ceil(u.Range / (u.Speed * u.Tick))
		for t = 1, ticks do
			task.delay(t * u.Tick, function()
				for _, rp in ipairs(raptors) do
					if not rp.Done then
						local step = rp.Direction * u.Speed * u.Tick
						local wall = workspace:Raycast(rp.Pos + Vector3.new(0, 2.5, 0), step * 1.2, params)
						rp.Traveled = rp.Traveled + step.Magnitude
						if wall or rp.Traveled >= u.Range then
							rp.Done = true
							S.fx("Ultimate", { Act = ACT, Phase = "RaptorEnd", Id = rp.Id, Position = rp.Pos })
						else
							rp.Pos = Moves.groundBelow(rp.Pos + step, { char })
							for _, target in ipairs(S.Hitbox.inRadius(player.Character, rp.Pos + Vector3.new(0, 2.5, 0), u.HitRadius, 4)) do
								if not rp.Hit[target] and (bitten[target] or 0) < maxBites and S.Adapter.canBeHit(player, target) then
									rp.Hit[target] = true
									bitten[target] = (bitten[target] or 0) + 1
									local tr = target:FindFirstChild("HumanoidRootPart")
									S.hit(player, target, { Damage = u.Damage, Stun = u.Stun, Knockback = u.Knockback, Launch = u.Launch, Direction = rp.Direction, Position = tr and tr.Position or rp.Pos, Source = "DiegoRaptorPack" })
									S.fx("Ultimate", { Act = ACT, Phase = "RaptorBite", Id = rp.Id, Position = tr and tr.Position or rp.Pos })
								end
							end
						end
					end
				end
			end)
		end
		S.finishUltimate(player, state)
	end)
end

function Diego.Cleanup(S, player, state)
	revert(S, player, state, false)
	releaseThrall(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
	end
end

return Diego
end

-- ======================================================================
-- MODULE: DiegoOutfit
-- ======================================================================
__modules["DiegoOutfit"] = function()
--[[
	DiegoOutfit  (ServerScriptService.SpinServer.DiegoOutfit)

	Gives a character Diego Brando's half-dinosaur look while they play Diego
	(TuskAct 6), built from parts so no catalog asset ids are needed
	(from the owner's references):
	  * green scaled racing cap with "DIO" on the front
	  * spiky blond hair sticking out under it
	  * a long blue dinosaur tail with a pale belly and yellow markings
	The player's own clothes stay on. Their own hats/hair are hidden while
	they play Diego and come back when they switch. Built on the server so
	every player sees it. (In full raptor form the client hides all of this
	and draws the raptor instead.)
]]

local Players = game:GetService("Players")
local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Blockify = __require("Blockify")

local DiegoOutfit = {}
DiegoOutfit.DiegoAct = 6

local C = {
	Cap = Color3.fromRGB(70, 160, 120),
	CapDark = Color3.fromRGB(40, 110, 85),
	Scale = Color3.fromRGB(110, 200, 150),
	Letters = Color3.fromRGB(240, 230, 200),
	Hair = Color3.fromRGB(245, 214, 110),
	HairDark = Color3.fromRGB(214, 176, 72),
	TailTeal = Color3.fromRGB(95, 205, 212),
	TailBlue = Color3.fromRGB(38, 62, 190),
	Pale = Color3.fromRGB(242, 234, 172),
	Yellow = Color3.fromRGB(246, 212, 62),
}

local saved = setmetatable({}, { __mode = "k" })

local function piece(parent, outfit, props, offset, ellipsoid)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	if ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = outfit
	return p
end

local function cap(head, outfit)
	local s = head.Size.Y / 1.2
	local top = head.Size.Y * 0.5
	-- Dome with a ridge of scales, short brim, "DIO" on the front.
	piece(head, outfit, { Name = "CapDome", Size = Vector3.new(1.42, 0.95, 1.42) * s, Color = C.Cap }, CFrame.new(0, top - 0.12 * s, 0.02 * s), true)
	piece(head, outfit, { Name = "CapBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22 * s, 1.36 * s, 1.36 * s), Color = C.CapDark }, CFrame.new(0, top - 0.32 * s, 0.02 * s) * CFrame.Angles(0, 0, math.pi / 2))
	piece(head, outfit, { Name = "CapBrim", Size = Vector3.new(1.0, 0.08, 0.5) * s, Color = C.CapDark }, CFrame.new(0, top - 0.36 * s, -0.78 * s) * CFrame.Angles(-0.12, 0, 0))
	for i = 0, 6 do
		local a = (i / 6 - 0.5) * 2.2
		piece(head, outfit, { Name = "CapScale", Size = Vector3.new(0.3, 0.16, 0.3) * s, Color = C.Scale }, CFrame.new(0, top - 0.12 * s, 0.02 * s) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 0.46 * s, 0), true)
	end
	local plate = piece(head, outfit, { Name = "CapLetters", Size = Vector3.new(1.0, 0.36, 0.05) * s, Color = C.Cap, Transparency = 1 }, CFrame.new(0, top + 0.02 * s, -0.68 * s) * CFrame.Angles(-0.35, 0, 0))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = plate
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.TextColor3 = C.Letters
	label.TextStrokeTransparency = 0.3
	label.Text = "DIO"
	label.Parent = gui
end

local function hair(head, outfit)
	local s = head.Size.Y / 1.2
	-- Spiky blond hair sticking out the sides and back under the cap.
	local spikes = {
		{ -0.62, 0.05, 0.1, 0, 0, 0.9 }, { 0.62, 0.05, 0.1, 0, 0, -0.9 },
		{ -0.55, -0.2, 0.35, 0.4, 0, 0.7 }, { 0.55, -0.2, 0.35, 0.4, 0, -0.7 },
		{ 0, -0.1, 0.62, 1.0, 0, 0 }, { -0.3, -0.25, 0.58, 1.1, 0, 0.4 }, { 0.3, -0.25, 0.58, 1.1, 0, -0.4 },
		{ -0.35, 0.15, -0.6, -0.9, 0, 0.3 }, { 0.35, 0.15, -0.6, -0.9, 0, -0.3 },
	}
	for i, sp in ipairs(spikes) do
		piece(head, outfit, { Name = "HairSpike", Size = Vector3.new(0.3, 0.8, 0.3) * s, Color = (i % 2 == 0) and C.Hair or C.HairDark },
			CFrame.new(sp[1] * s, sp[2] * s, sp[3] * s) * CFrame.Angles(sp[4], sp[5], sp[6]) * CFrame.new(0, 0.25 * s, 0), true)
	end
	piece(head, outfit, { Name = "HairBack", Size = Vector3.new(1.25, 0.9, 0.5) * s, Color = C.Hair }, CFrame.new(0, 0.05 * s, 0.45 * s), true)
end

local function tail(character, outfit)
	local hip = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
	if not hip then
		return
	end
	local s = hip.Size.X / 2
	local back = hip.Size.Z / 2
	-- Starts at the lower back, sweeps down and back, the tip curls up.
	local cf = CFrame.new(0, -hip.Size.Y * 0.2, back) * CFrame.Angles(0.75, 0, 0) -- (+X tips the backward-pointing tail down)
	local count = 8
	for i = 1, count do
		local k = (i - 1) / count
		local d = 0.85 * (1 - k * 0.8) * s
		local len = 0.85 * s
		local color = i <= 2 and C.TailTeal:Lerp(C.TailBlue, (i - 1) / 2) or C.TailBlue
		local segCF = cf * CFrame.new(0, 0, len / 2)
		piece(hip, outfit, { Name = "Tail", Size = Vector3.new(d, d * 0.92, len * 1.6), Color = color }, segCF, true)
		piece(hip, outfit, { Name = "TailBelly", Size = Vector3.new(d * 0.7, d * 0.4, len * 1.5), Color = C.Pale }, segCF * CFrame.new(0, -d * 0.3, 0), true)
		if i >= 2 and i <= 7 then
			piece(hip, outfit, { Name = "TailMark", Size = Vector3.new(d * 0.35, d * 0.12, len * 0.7), Color = C.Yellow }, segCF * CFrame.new(0, d * 0.44, 0), true)
		end
		local bend = (i <= 4) and -0.16 or (i >= 6 and -0.22 or 0) -- level out, then the tip curls up
		cf = cf * CFrame.new(0, 0, len) * CFrame.Angles(bend, 0, 0)
	end
end

function DiegoOutfit.apply(character)
	if character:FindFirstChild("DiegoOutfit") then
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
	outfit.Name = "DiegoOutfit"
	outfit.Parent = character
	cap(head, outfit)
	hair(head, outfit)
	tail(character, outfit)
	-- The dinosaur tail is Scary Monsters' and follows its blocky look.
	if Blockify.enabled(TuskConfig) then
		for _, p in ipairs(outfit:GetChildren()) do
			if p.Name:sub(1, 4) == "Tail" then
				Blockify.apply(p)
			end
		end
	end
end

function DiegoOutfit.remove(character)
	local outfit = character:FindFirstChild("DiegoOutfit")
	if outfit then
		outfit:Destroy()
	end
	local store = saved[character]
	if not store then
		return
	end
	saved[character] = nil
	for handle, transparency in pairs(store.Hidden) do
		if handle.Parent then
			handle.Transparency = transparency
		end
	end
end

local function watch(character)
	local function update()
		if character:GetAttribute("TuskAct") == DiegoOutfit.DiegoAct then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == DiegoOutfit.DiegoAct then
					DiegoOutfit.apply(character)
				end
			end)
		else
			DiegoOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function DiegoOutfit.init()
	local function onPlayer(player)
		player.CharacterAppearanceLoaded:Connect(watch)
		if player.Character then
			watch(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
end

return DiegoOutfit
end

-- ======================================================================
-- MODULE: GyroOutfit
-- ======================================================================
__modules["GyroOutfit"] = function()
--[[
	GyroOutfit  (ServerScriptService.SpinServer.GyroOutfit)

	Gives a character Gyro Zeppeli's hat and hair while they play Gyro
	(TuskAct 5), built from parts so no catalog asset ids are needed:
	  * tan wide-brimmed hat with slots cut round the brim, slits round the
	    crown, a domed top and two big ridged silver goggles on a strap
	  * long blond hair with side locks, braids and a fringe
	The player's own clothes stay on. Their own hats/hair are hidden while
	they play Gyro and come back when they switch. Built on the server so
	every player sees it.
]]

local Players = game:GetService("Players")

local GyroOutfit = {}
GyroOutfit.GyroAct = 5

local C = {
	Hat = Color3.fromRGB(206, 168, 128),
	HatShade = Color3.fromRGB(150, 105, 70),
	Slot = Color3.fromRGB(55, 38, 26),
	Strap = Color3.fromRGB(80, 84, 92),
	Goggle = Color3.fromRGB(176, 182, 192),
	HatBand = Color3.fromRGB(60, 40, 90),
	Gold = Color3.fromRGB(235, 190, 70),
	Hair = Color3.fromRGB(240, 205, 110),
	HairDark = Color3.fromRGB(210, 170, 80),
	Shirt = Color3.fromRGB(102, 64, 150),
	Pants = Color3.fromRGB(70, 46, 110),
}

local saved = setmetatable({}, { __mode = "k" }) -- character -> what to restore

local function piece(parent, outfit, props, offset, ellipsoid)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	if ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = outfit
	return p
end

-- Gyro's hat (from the owner's pictures): tan, a wide brim with slots cut
-- all the way round, slits around the crown, a domed top, and two big silver
-- goggles with ridged lenses strapped to the front.
local function hat(head, outfit)
	local s = head.Size.Y / 1.2
	local top = head.Size.Y * 0.5
	local base = CFrame.new(0, top - 0.05 * s, 0.05 * s) * CFrame.Angles(-0.12, 0, 0)
	local tan, tanDark = C.Hat, C.HatShade
	piece(head, outfit, { Name = "HatBrim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1 * s, 2.9 * s, 2.9 * s), Color = tan }, base * CFrame.Angles(0, 0, math.pi / 2))
	piece(head, outfit, { Name = "HatBrimEdge", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.09 * s, 2.96 * s, 2.96 * s), Color = tanDark }, base * CFrame.new(0, -0.01 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
	-- Slots cut into the brim, all the way round.
	for i = 0, 21 do
		local a = i / 22 * math.pi * 2
		local r = 1.08 * s
		piece(head, outfit, { Name = "BrimSlot", Size = Vector3.new(0.08 * s, 0.03 * s, 0.34 * s), Color = C.Slot }, base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.055 * s, -r))
	end
	-- Crown with slits, domed top.
	piece(head, outfit, { Name = "HatCrown", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.72 * s, 1.45 * s, 1.45 * s), Color = tan }, base * CFrame.new(0, 0.4 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
	piece(head, outfit, { Name = "HatTop", Size = Vector3.new(1.45, 0.42, 1.45) * s, Color = Color3.fromRGB(226, 196, 160) }, base * CFrame.new(0, 0.76 * s, 0), true)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		piece(head, outfit, { Name = "CrownSlit", Size = Vector3.new(0.06 * s, 0.34 * s, 0.03 * s), Color = C.Slot }, base * CFrame.new(0, 0.48 * s, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.73 * s))
	end
	-- Goggle strap around the crown.
	piece(head, outfit, { Name = "GoggleStrap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.16 * s, 1.5 * s, 1.5 * s), Color = C.Strap }, base * CFrame.new(0, 0.24 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))
	-- Two big silver goggles with horizontal ridges, joined by a bridge.
	for _, side in ipairs({ -1, 1 }) do
		local lensCF = base * CFrame.new(side * 0.4 * s, 0.38 * s, -0.8 * s) * CFrame.Angles(0, side * 0.35, 0)
		piece(head, outfit, { Name = "GoggleRim", Size = Vector3.new(0.8, 0.62, 0.28) * s, Color = C.Strap, Material = Enum.Material.Metal }, lensCF * CFrame.new(0, 0, 0.04 * s), true)
		piece(head, outfit, { Name = "GoggleLens", Size = Vector3.new(0.72, 0.55, 0.32) * s, Color = C.Goggle, Material = Enum.Material.Metal, Reflectance = 0.25 }, lensCF, true)
		for r = -1, 1 do
			piece(head, outfit, { Name = "GoggleRidge", Size = Vector3.new(0.58 * s, 0.04 * s, 0.05 * s), Color = C.Strap, Material = Enum.Material.Metal }, lensCF * CFrame.new(0, r * 0.13 * s, -0.15 * s))
		end
	end
	piece(head, outfit, { Name = "GoggleBridge", Size = Vector3.new(0.22, 0.14, 0.14) * s, Color = C.Strap, Material = Enum.Material.Metal }, base * CFrame.new(0, 0.38 * s, -0.84 * s))
end

local function hair(head, outfit)
	local s = head.Size.Y / 1.2
	piece(head, outfit, { Name = "HairBack", Size = Vector3.new(1.25, 1.5, 0.55) * s, Color = C.Hair }, CFrame.new(0, -0.25 * s, 0.45 * s), true)
	piece(head, outfit, { Name = "HairTop", Size = Vector3.new(1.28, 0.6, 1.25) * s, Color = C.Hair }, CFrame.new(0, 0.38 * s, 0.05 * s), true)
	-- Long side locks framing the face, and two braids hanging past the shoulders.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, { Name = "SideHair", Size = Vector3.new(0.32, 1.5, 0.7) * s, Color = C.Hair }, CFrame.new(side * 0.66 * s, -0.35 * s, 0.12 * s), true)
		for i = 0, 5 do
			piece(head, outfit, { Name = "Braid", Size = Vector3.new(0.26, 0.34, 0.26) * s, Color = (i % 2 == 0) and C.Hair or C.HairDark }, CFrame.new(side * 0.78 * s, (-0.55 - i * 0.28) * s, -0.05 * s), true)
		end
	end
	-- Short fringe peeking out under the hat brim.
	piece(head, outfit, { Name = "Fringe", Size = Vector3.new(1.1, 0.25, 0.3) * s, Color = C.Hair }, CFrame.new(0, 0.42 * s, -0.5 * s), true)
end

function GyroOutfit.apply(character)
	if character:FindFirstChild("GyroOutfit") then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local store = { Hidden = {} }
	saved[character] = store
	-- Hide the player's own hats and hair so they don't poke through Gyro's.
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
	outfit.Name = "GyroOutfit"
	outfit.Parent = character
	hat(head, outfit)
	hair(head, outfit)
end

function GyroOutfit.remove(character)
	local outfit = character:FindFirstChild("GyroOutfit")
	if outfit then
		outfit:Destroy()
	end
	local store = saved[character]
	if not store then
		return
	end
	saved[character] = nil
	for handle, transparency in pairs(store.Hidden) do
		if handle.Parent then
			handle.Transparency = transparency
		end
	end
end

local function watch(character)
	local function update()
		if character:GetAttribute("TuskAct") == GyroOutfit.GyroAct then
			-- Wait for the avatar's clothes/accessories to load before swapping them.
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == GyroOutfit.GyroAct then
					GyroOutfit.apply(character)
				end
			end)
		else
			GyroOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function GyroOutfit.init()
	local function onPlayer(player)
		player.CharacterAppearanceLoaded:Connect(watch)
		if player.Character then
			watch(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
end

return GyroOutfit
end

-- ======================================================================
-- MODULE: GyroZeppeli
-- ======================================================================
__modules["GyroZeppeli"] = function()
--[[
	GyroZeppeli  (ServerScriptService.SpinServer.TuskActs.GyroZeppeli)

	Gyro Zeppeli: Steel Ball moveset (registered as "Act" 5 so it reuses the
	Tusk ability system: cooldowns, HUD, ultimate meter, input).
	  M1        STEEL BALL COMBO: jab, hook, kick, spinning-ball smash (area)
	  Ability 1 STEEL BALL THROW: the ball flies out and BOUNCES off walls (up
	            to MaxBounces times, each bank shot hits harder), then returns
	            to Gyro's hand (it can hit on the way back)
	  Ability 2 SPIN TORNADO: bowl the spinning ball along the ground; it
	            becomes a travelling tornado that pulls enemies in, juggles
	            them and bursts (stops at walls)
	  Ability 3 SPIN VIBRATION: press the spinning ball into the enemy in front:
	            paralysis (long stun) and a small launch
	  Ultimate  BALL BREAKER: spiral build-up, a huge ball opens a spinning
	            vortex that pulls enemies in, then bursts
	Numbers: TuskConfig.Gyro. All damage goes through S.hit (CombatAdapter).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Gyro = {}
local cfg = TuskConfig.Gyro
local HAND = CFrame.new(0.9, 0.6, -1.6)

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Gyro.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 5)
end

-- Short body "shake" slow from the Spin (stackable, always removed).
local function spinSlow(S, target, multiplier, seconds)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local key = "GyroSpin"
	S.Adapter.setMoveModifier(humanoid, key, multiplier)
	target:SetAttribute("GyroSpinShake", true)
	local token = {}
	target:SetAttribute("GyroSpinToken", tostring(token))
	task.delay(seconds, function()
		if humanoid.Parent and target:GetAttribute("GyroSpinToken") == tostring(token) then
			S.Adapter.setMoveModifier(humanoid, key, nil)
			target:SetAttribute("GyroSpinShake", nil)
		end
	end)
end

local function steelBallThrow(S, player, state, aim)
	local c = cfg.SteelBallThrow
	if not ready(S, player, state, "SteelBallThrow", 1) then
		return
	end
	S.startCooldown(player, state, "SteelBallThrow", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.25)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 5, Move = "SteelBallThrow", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local hitOut = {}
		local maxBounces = c.MaxBounces or 3

		-- The ball spins its way back to Gyro's hand from wherever it stopped.
		local function returnToHand(position)
			local _, _, rr = alive(S, player)
			if not rr or state.Life ~= life then
				S.fx("Ability", { Character = char, Act = 5, Move = "SteelBallThrow", Phase = "Caught" })
				return
			end
			local back = rr.Position + Vector3.new(0, 1, 0) - position
			if back.Magnitude < 2 then
				S.fx("Ability", { Character = char, Act = 5, Move = "SteelBallThrow", Phase = "Caught" })
				return
			end
			S.fireBall(player, state, {
				Origin = position,
				Direction = back.Unit,
				Speed = c.ReturnSpeed,
				Radius = c.Radius,
				Range = back.Magnitude,
				Style = "Return",
				OnHit = function(target, pos)
					if not hitOut[target] then
						hitOut[target] = true
						S.hit(player, target, { Damage = c.ReturnDamage, Stun = 0.3, Knockback = 8, Direction = back.Unit, Position = pos, Source = "GyroSteelBall" })
					end
				end,
				OnEnd = function()
					S.fx("Ability", { Character = char, Act = 5, Move = "SteelBallThrow", Phase = "Caught" })
				end,
			})
		end

		-- One straight flight. When it hits a wall it bounces off (reflects
		-- around the surface normal) and keeps flying with the range it has left.
		local function launch(origin, dir, rangeLeft, bounce)
			S.fireBall(player, state, {
				Origin = origin,
				Direction = dir,
				Speed = c.Speed * (1 + bounce * 0.08), -- each bounce comes off a little faster
				Radius = c.Radius,
				Range = rangeLeft,
				Style = "Throw",
				Bounce = bounce,
				OnHit = function(target, position)
					if hitOut[target] then
						return
					end
					hitOut[target] = true
					-- Bank shots hit harder.
					local damage = c.Damage + bounce * (c.BounceBonusDamage or 2)
					S.hit(player, target, { Damage = damage, Stun = c.Stun, Knockback = c.Knockback, Direction = dir, Position = position, Source = "GyroSteelBall" })
				end,
				OnEnd = function(position, normal, hitCharacter, projectile)
					if state.Life ~= life then
						S.fx("Ability", { Character = char, Act = 5, Move = "SteelBallThrow", Phase = "Caught" })
						return
					end
					local traveled = projectile and projectile.Traveled or rangeLeft
					local remaining = rangeLeft - traveled
					if not hitCharacter and projectile and projectile.HitWall and bounce < maxBounces and remaining > 6 then
						local n = normal.Unit
						local reflected = dir - 2 * dir:Dot(n) * n
						if reflected.Magnitude < 0.1 then
							reflected = -dir
						end
						reflected = reflected.Unit
						-- Start just off the surface so it doesn't hit the same wall again.
						local from = position + n * (c.Radius + 0.3)
						S.fx("Ability", { Character = char, Act = 5, Move = "SteelBallThrow", Phase = "Bounce", Position = position, Normal = n, Direction = reflected, Bounce = bounce + 1 })
						launch(from, reflected, remaining, bounce + 1)
						return
					end
					returnToHand(position)
				end,
			})
		end

		launch(S.origin(char, r, HAND), direction, c.Range, 0)
	end)
end

-- SPIN TORNADO: the spinning ball is bowled along the ground and becomes a
-- travelling tornado that pulls enemies in, juggles them, then bursts.
local function spinTornado(S, player, state, aim)
	local c = cfg.SpinTornado
	if not ready(S, player, state, "SpinTornado", 2) then
		return
	end
	S.startCooldown(player, state, "SpinTornado", c.Cooldown, 2)
	S.lock(state, c.Startup + 0.3)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	local id = tostring(os.clock()) .. player.UserId
	S.fx("Ability", { Character = character, Act = 5, Move = "SpinTornado", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local pos = Moves.groundBelow(r.Position + direction * 4, { char }) + Vector3.new(0, 3, 0)
		S.fx("Tornado", { Act = 5, Id = id, Phase = "Start", Position = pos, Radius = c.Radius, Duration = c.Duration })
		local ticks = math.floor(c.Duration / c.Tick)
		local stopped = false
		for i = 1, ticks do
			task.delay(i * c.Tick, function()
				if stopped then
					return
				end
				-- Move forward; stop at walls; follow the ground.
				local step = direction * c.Speed * c.Tick
				if workspace:Raycast(pos, step * 1.5, params) then
					stopped = true
				else
					pos = Moves.groundBelow(pos + step, { char }) + Vector3.new(0, 3, 0)
				end
				S.fx("Tornado", { Act = 5, Id = id, Phase = "Move", Position = pos })
				for _, target in ipairs(S.Hitbox.inRadius(player.Character, pos, c.Radius, 6)) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr and S.Adapter.canBeHit(player, target) then
						local inward = pos - tr.Position
						S.Adapter.applyKnockback(target, inward, c.Pull, c.Lift)
						S.hit(player, target, { Damage = c.TickDamage, Stun = 0.3, Knockback = 0, Direction = inward, Position = tr.Position, Source = "GyroSpinTornado" })
					end
				end
			end)
		end
		task.delay(c.Duration + 0.05, function()
			Moves.aoe(S, player, pos, c.Radius + 1.5, { Damage = c.BurstDamage, Stun = 0.4, Knockback = c.BurstKnockback, Launch = c.BurstLaunch, Source = "GyroSpinTornado" }, 6)
			S.fx("Tornado", { Act = 5, Id = id, Phase = "Burst", Position = pos, Radius = c.Radius + 1.5 })
		end)
	end)
end

local function spinVibration(S, player, state, aim)
	local c = cfg.SpinVibration
	if not ready(S, player, state, "SpinVibration", 3) then
		return
	end
	S.startCooldown(player, state, "SpinVibration", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.4)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 5, Move = "SpinVibration", Phase = "Startup", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local _, _, r = alive(S, player)
		local cf = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
		local count, hitSet = Moves.boxHit(S, player, cf, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Source = "GyroSpinVibration" }, 2)
		for target in pairs(hitSet) do
			spinSlow(S, target, 0.4, 1.5)
		end
		S.fx("Ability", { Character = character, Act = 5, Move = "SpinVibration", Phase = "Hit", Position = cf.Position, Hit = count > 0 })
	end)
end

function Gyro.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		steelBallThrow(S, player, state, aim)
	elseif slot == 2 then
		spinTornado(S, player, state, aim)
	elseif slot == 3 then
		spinVibration(S, player, state, aim)
	end
end

-- BALL BREAKER
function Gyro.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.lock(state, u.Windup + 0.5)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = 5, Phase = "Start", Windup = u.Windup, Direction = direction })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local _, _, r = alive(S, player)
		S.fx("Ultimate", { Character = character, Act = 5, Phase = "Release", Position = r.Position, Direction = direction })
		S.fireBall(player, state, {
			Origin = S.origin(character, r, CFrame.new(0, 1.5, -3)),
			Direction = direction,
			Speed = u.Speed,
			Radius = u.Radius,
			Range = u.Range,
			Style = "Breaker",
			Scale = u.Radius * 2,
			OnHit = function(target, position)
				S.hit(player, target, { Damage = u.Damage, Stun = 0.5, Knockback = 10, Direction = direction, Position = position, Source = "GyroBallBreaker" })
			end,
			OnEnd = function(position)
				-- The spinning vortex: pulls enemies in, then bursts.
				S.fx("Ultimate", { Character = character, Act = 5, Phase = "Vortex", Position = position, Radius = u.VortexRadius, Duration = u.VortexTime })
				local ticks = math.floor(u.VortexTime / u.TickInterval)
				for i = 1, ticks do
					task.delay(i * u.TickInterval, function()
						for _, target in ipairs(S.Hitbox.inRadius(player.Character, position, u.VortexRadius, 8)) do
							local tr = target:FindFirstChild("HumanoidRootPart")
							if tr and S.Adapter.canBeHit(player, target) then
								local inward = position - tr.Position
								S.Adapter.applyKnockback(target, inward, u.PullStrength, 2)
								S.hit(player, target, { Damage = u.TickDamage, Stun = 0.25, Knockback = 0, Direction = inward, Position = tr.Position, Source = "GyroBallBreaker" })
							end
						end
					end)
				end
				task.delay(u.VortexTime + 0.05, function()
					Moves.aoe(S, player, position, u.VortexRadius + 2, { Damage = u.BurstDamage, Stun = u.Stun, Knockback = u.BurstKnockback, Launch = u.Launch, Source = "GyroBallBreaker" }, 8)
					S.fx("Ultimate", { Character = character, Act = 5, Phase = "Burst", Position = position, Radius = u.VortexRadius + 2 })
				end)
			end,
		})
		S.finishUltimate(player, state)
	end)
end

function Gyro.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
	end
end

return Gyro
end

-- ======================================================================
-- MODULE: Maid
-- ======================================================================
__modules["Maid"] = function()
--[[
	Maid  (ReplicatedStorage.SpinShared.Maid)
	Tracks connections, instances and cleanup functions so effects always end.
]]

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(task)
	table.insert(self._tasks, task)
	return task
end

function Maid:Clean()
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		local t = tasks[i]
		local kind = typeof(t)
		if kind == "RBXScriptConnection" then
			t:Disconnect()
		elseif kind == "Instance" then
			t:Destroy()
		elseif kind == "function" then
			local ok, err = pcall(t)
			if not ok then
				warn("[Maid] cleanup error:", err)
			end
		elseif kind == "table" and t.Destroy then
			t:Destroy()
		end
	end
end

Maid.Destroy = Maid.Clean

return Maid
end

-- ======================================================================
-- MODULE: NPCService
-- ======================================================================
__modules["NPCService"] = function()
--[[
	NPCService  (ServerScriptService.SpinServer.NPCService)

	Turns the markers in workspace.SBRMap.NPCSpawns (made by SBRMapBuilder)
	into living NPCs:
	  * R15 characters with role-based outfits colours and a name tag
	  * "Talk" ProximityPrompt: cycles through that NPC's lines
	  * Racers jog the track waypoints; others wander near home
	  * occasional ambient lines to nearby players
	  * respawn if they fall out of the world
	NPCs carry the IFrames attribute, so no attack can hurt them, and an
	"NPC" attribute so other systems can recognise them.
	Does nothing if the map isn't in the place.
]]

local Players = game:GetService("Players")

local Net = __require("Net")

local NPCService = {}

local ROLE_STYLE = {
	Announcer = { Torso = Color3.fromRGB(150, 30, 40), Legs = Color3.fromRGB(40, 35, 30), Speed = 0 },
	Official = { Torso = Color3.fromRGB(40, 50, 80), Legs = Color3.fromRGB(30, 30, 35), Speed = 8 },
	Racer = { Torso = Color3.fromRGB(70, 120, 170), Legs = Color3.fromRGB(110, 80, 50), Speed = 16 },
	Guard = { Torso = Color3.fromRGB(110, 80, 50), Legs = Color3.fromRGB(50, 40, 30), Speed = 9 },
	Spectator = { Torso = Color3.fromRGB(160, 140, 100), Legs = Color3.fromRGB(80, 60, 45), Speed = 7 },
}
local SKIN = { Color3.fromRGB(234, 184, 146), Color3.fromRGB(204, 142, 105), Color3.fromRGB(160, 105, 75), Color3.fromRGB(110, 70, 50) }

local npcs = {}
local WorldFX

local function splitLines(s)
	local lines = {}
	for line in string.gmatch(s or "", "[^|]+") do
		table.insert(lines, line)
	end
	return lines
end

local function say(npc, line, toPlayer)
	local payload = { NPC = npc.Model, Text = line }
	if toPlayer then
		WorldFX:FireClient(toPlayer, "NPCSay", payload)
	else
		WorldFX:FireAllClients("NPCSay", payload)
	end
end

local function spawnNPC(marker, waypoints, index)
	local role = marker:GetAttribute("Role") or "Spectator"
	local style = ROLE_STYLE[role] or ROLE_STYLE.Spectator
	local description = Instance.new("HumanoidDescription")
	local skin = SKIN[(index % #SKIN) + 1]
	description.HeadColor = skin
	description.LeftArmColor = style.Torso
	description.RightArmColor = style.Torso
	description.TorsoColor = style.Torso
	description.LeftLegColor = style.Legs
	description.RightLegColor = style.Legs
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[NPCService] could not create NPC:", model)
		return nil
	end
	local displayName = marker:GetAttribute("DisplayName") or marker.Name
	model.Name = displayName
	model:SetAttribute("NPC", true)
	model:SetAttribute("IFrames", true)
	model:SetAttribute("Role", role)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = displayName
	humanoid.NameDisplayDistance = 40
	humanoid.WalkSpeed = style.Speed
	humanoid.BreakJointsOnDeath = false
	local home = marker.Position + Vector3.new(0, 3, 0)
	model:PivotTo(CFrame.new(home) * CFrame.Angles(0, math.rad(index * 47), 0))
	model.Parent = marker.Parent.Parent:FindFirstChild("NPCs") or marker.Parent.Parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = displayName
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model:WaitForChild("HumanoidRootPart")

	local npc = {
		Model = model,
		Humanoid = humanoid,
		Marker = marker,
		Home = home,
		Role = role,
		Wander = marker:GetAttribute("WanderRadius") or 0,
		Lines = splitLines(marker:GetAttribute("Lines")),
		LineIndex = 0,
		NextMove = os.clock() + math.random() * 4,
		Waypoint = 1,
		Waypoints = waypoints,
		Index = index,
		Talking = 0,
	}
	prompt.Triggered:Connect(function(player)
		if #npc.Lines == 0 then
			return
		end
		npc.LineIndex = npc.LineIndex % #npc.Lines + 1
		npc.Talking = os.clock() + 4
		humanoid:MoveTo(model.HumanoidRootPart.Position) -- stop and chat
		local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if playerRoot then
			local pos = model.HumanoidRootPart.Position
			model:PivotTo(CFrame.lookAt(pos, Vector3.new(playerRoot.Position.X, pos.Y, playerRoot.Position.Z)))
		end
		say(npc, npc.Lines[npc.LineIndex], nil)
	end)
	return npc
end

local function think(npc, now)
	local model = npc.Model
	local root = model.Parent and model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if root.Position.Y < -60 then
		model:PivotTo(CFrame.new(npc.Home)) -- fell out of the world
		return
	end
	if now < npc.Talking or now < npc.NextMove then
		return
	end
	if npc.Role == "Racer" and #npc.Waypoints > 0 then
		local wp = npc.Waypoints[npc.Waypoint]
		npc.Humanoid:MoveTo(wp.Position + Vector3.new(npc.Index % 2 == 0 and 3 or -3, 0, 0))
		if (root.Position - wp.Position).Magnitude < 8 then
			npc.Waypoint = npc.Waypoint % #npc.Waypoints + 1
		end
		npc.NextMove = now + 0.5
	elseif npc.Wander > 0 then
		local angle = math.random() * math.pi * 2
		local dist = math.random() * npc.Wander
		npc.Humanoid:MoveTo(npc.Home + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist))
		npc.NextMove = now + 4 + math.random() * 5
	else
		npc.NextMove = now + 10
	end
end

-- Ambient line from an NPC close to a player, every so often.
local function ambientChatter()
	local candidates = {}
	for _, npc in ipairs(npcs) do
		local root = npc.Model:FindFirstChild("HumanoidRootPart")
		if root and #npc.Lines > 0 then
			for _, player in ipairs(Players:GetPlayers()) do
				local pr = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if pr and (pr.Position - root.Position).Magnitude < 45 then
					table.insert(candidates, npc)
					break
				end
			end
		end
	end
	if #candidates > 0 then
		local npc = candidates[math.random(1, #candidates)]
		say(npc, npc.Lines[math.random(1, #npc.Lines)], nil)
	end
end

function NPCService.init()
	WorldFX = Net.get("WorldFX")
	task.spawn(function()
		local map = workspace:FindFirstChild("SBRMap") or workspace:WaitForChild("SBRMap", 10)
		local spawns = map and map:FindFirstChild("NPCSpawns")
		if not spawns then
			return -- no map in this place: nothing to do
		end
		local container = Instance.new("Folder")
		container.Name = "NPCs"
		container.Parent = map
		local waypoints = {}
		local wpFolder = map:FindFirstChild("RacerWaypoints")
		if wpFolder then
			waypoints = wpFolder:GetChildren()
			table.sort(waypoints, function(a, b)
				return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
			end)
		end
		for i, marker in ipairs(spawns:GetChildren()) do
			local npc = spawnNPC(marker, waypoints, i)
			if npc then
				table.insert(npcs, npc)
			end
		end
		-- One shared low-frequency loop for all NPC brains (no per-NPC Heartbeat).
		local nextChatter = os.clock() + 20
		while true do
			local now = os.clock()
			for _, npc in ipairs(npcs) do
				think(npc, now)
			end
			if now >= nextChatter then
				nextChatter = now + 20 + math.random() * 20
				ambientChatter()
			end
			task.wait(0.5)
		end
	end)
end

return NPCService
end

-- ======================================================================
-- MODULE: NailModel
-- ======================================================================
__modules["NailModel"] = function()
--[[
	NailModel  (ReplicatedStorage.SpinShared.NailModel)

	Procedural fingernail-bullet used by every Tusk nail attack: a metal
	shaft, a flat head at the back and a tapered tip at the front.
	The nail points down its Core's LookVector (-Z).

	NailModel.build(length) -> Model (PrimaryPart = "Core")
	  Core attachments: "Tip" (front), "Tail" (back), "Center".
]]

local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local NailModel = {}

local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = model
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

function NailModel.build(length)
	length = length or 1.3
	local metal = TuskConfig.Colors.Metal
	local model = Instance.new("Model")
	model.Name = "TuskNail"

	-- Shaft: Cylinder axis is X, so turn it to run along Z.
	local core = part(model, {
		Name = "Core",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length * 0.7, length * 0.085, length * 0.085),
		Color = metal,
		Reflectance = 0.25,
		Massless = false,
	})
	core.CFrame = CFrame.Angles(0, math.pi / 2, 0)
	-- Pivot frame faces -Z, so Model:PivotTo(cf) points the tip down cf.LookVector.
	core.PivotOffset = CFrame.Angles(0, -math.pi / 2, 0)
	model.PrimaryPart = core

	local head = part(model, {
		Name = "Head",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length * 0.05, length * 0.24, length * 0.24),
		Color = metal:Lerp(Color3.new(1, 1, 1), 0.2),
		Reflectance = 0.3,
	})
	head.CFrame = CFrame.new(0, 0, length * 0.36) * CFrame.Angles(0, math.pi / 2, 0)
	weld(core, head)

	local tip = part(model, {
		Name = "Tip",
		Size = Vector3.new(length * 0.085, length * 0.085, length * 0.36),
		Color = metal:Lerp(Color3.new(1, 1, 1), 0.35),
		Reflectance = 0.35,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = tip
	tip.CFrame = CFrame.new(0, 0, -length * 0.35)
	weld(core, tip)

	-- Attachments are placed in the core's (rotated) local space:
	-- the core's local X axis runs along world Z here.
	local function att(name, z)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = Vector3.new(-z, 0, 0)
		a.Parent = core
		return a
	end
	att("Tip", -length * 0.5)
	att("Tail", length * 0.4)
	att("Center", 0)

	return model
end

return NailModel
end

-- ======================================================================
-- MODULE: Net
-- ======================================================================
__modules["Net"] = function()
--[[
	Net  (ReplicatedStorage.SpinShared.Net)

	Creates (server) or waits for (client) the RemoteEvents used by the
	Spin system. All remotes live in ReplicatedStorage.SpinRemotes.

	SpinRequest : client -> server  ("Start" | "Release", aimDirection | "Cancel")
	SpinFX      : server -> client  (eventName, payloadTable)
	              Also carries shared events: ProjectileSpawn/End, Hit, Damage.
	TuskRequest : client -> server  (action, ...)  see TuskService
	TuskFX      : server -> client  (eventName, payloadTable)
	WorldFX     : server -> client  map / NPC events (NPCSay)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES = { "SpinRequest", "SpinFX", "TuskRequest", "TuskFX", "WorldFX" }

local Net = {}
local folder

local function getFolder()
	if folder then
		return folder
	end
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild("SpinRemotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "SpinRemotes"
			folder.Parent = ReplicatedStorage
		end
		for _, name in ipairs(REMOTES) do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild("SpinRemotes")
	end
	return folder
end

function Net.get(name)
	return getFolder():WaitForChild(name)
end

return Net
end

-- ======================================================================
-- MODULE: ProjectileService
-- ======================================================================
__modules["ProjectileService"] = function()
--[[
	ProjectileService  (ServerScriptService.SpinServer.ProjectileService)

	Server-simulated projectiles. The server owns position, collision and
	hits; clients only draw a matching visual (told via SpinFX
	"ProjectileSpawn" / "ProjectileEnd"). No physics parts are created on
	the server, so many projectiles at once stay cheap.

	Reusable for nails, wrecking balls, etc.:
		ProjectileService.fire(owner, {
			Kind = "SteelBall", Origin = Vector3, Direction = unit Vector3,
			Speed = 120, Radius = 1, Range = 150,
			Visual = { ...any data the client effect needs... },
			OnHit = function(targetCharacter, position, projectile) end,
		})
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Net = __require("Net")
local Adapter = __require("CombatAdapter")

local FX = Net.get("SpinFX")

local ProjectileService = {}
ProjectileService.MaxActivePerPlayer = 4

local active = {}
local countByPlayer = {}
local nextId = 0

local function characterFromPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function finish(p, position, normal, hitCharacter)
	if not active[p.Id] then
		return
	end
	active[p.Id] = nil
	if p.Owner then
		countByPlayer[p.Owner] = math.max(0, (countByPlayer[p.Owner] or 1) - 1)
	end
	-- Tell OnEnd why it stopped: hit a character, hit a wall/ground, or ran out of range.
	p.HitWall = hitCharacter == nil and normal ~= nil
	if hitCharacter and p.OnHit then
		local ok, err = pcall(p.OnHit, hitCharacter, position, p)
		if not ok then
			warn("[ProjectileService] OnHit error:", err)
		end
	end
	if p.OnEnd then
		local ok, err = pcall(p.OnEnd, position, normal or Vector3.new(0, 1, 0), hitCharacter, p)
		if not ok then
			warn("[ProjectileService] OnEnd error:", err)
		end
	end
	FX:FireAllClients("ProjectileEnd", {
		Id = p.Id,
		Kind = p.Kind,
		Position = position,
		Normal = normal or Vector3.new(0, 1, 0),
		HitCharacter = hitCharacter ~= nil,
		OwnerId = p.OwnerId,
		Visual = p.Visual,
	})
end

local function ignore(p, instance)
	local list = p.Params.FilterDescendantsInstances
	table.insert(list, instance)
	p.Params.FilterDescendantsInstances = list
end

-- Point-blank check: Spherecast misses parts already inside the start sphere.
local function overlapAtStart(p)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = p.Params.FilterDescendantsInstances
	for _, part in ipairs(workspace:GetPartBoundsInRadius(p.Position, p.Radius, overlap)) do
		local character = characterFromPart(part)
		if character and Adapter.canBeHit(p.Owner, character) then
			return character, part.Position
		end
	end
	return nil
end

function ProjectileService.activeCount(player)
	return countByPlayer[player] or 0
end

function ProjectileService.fire(owner, spec)
	if owner and ProjectileService.activeCount(owner) >= ProjectileService.MaxActivePerPlayer then
		return nil
	end
	nextId = nextId + 1

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local filter = {}
	if owner and owner.Character then
		table.insert(filter, owner.Character)
	end
	params.FilterDescendantsInstances = filter

	local p = {
		Id = nextId,
		Owner = owner,
		OwnerId = owner and owner.UserId or 0,
		Kind = spec.Kind or "Projectile",
		Position = spec.Origin,
		Direction = spec.Direction.Unit,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Traveled = 0,
		Params = params,
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd, -- function(position, normal, hitCharacter, projectile): always called once
		-- (projectile.HitWall is true when it stopped on a wall / the ground)
		Visual = spec.Visual or {},
	}
	active[p.Id] = p
	if owner then
		countByPlayer[owner] = (countByPlayer[owner] or 0) + 1
	end

	FX:FireAllClients("ProjectileSpawn", {
		Id = p.Id,
		Kind = p.Kind,
		Origin = p.Position,
		Direction = p.Direction,
		Speed = p.Speed,
		Range = p.Range,
		OwnerId = owner and owner.UserId or 0,
		ServerTime = workspace:GetServerTimeNow(),
		Visual = p.Visual,
	})

	local character, position = overlapAtStart(p)
	if character then
		finish(p, position, nil, character)
	end
	return p.Id
end

RunService.Heartbeat:Connect(function(dt)
	for _, p in pairs(active) do
		local step = math.min(p.Speed * dt, p.Range - p.Traveled)
		if step <= 0.01 then
			finish(p, p.Position, nil, nil)
		else
			local result = workspace:Spherecast(p.Position, p.Radius, p.Direction * step, p.Params)
			if result then
				local character = characterFromPart(result.Instance)
				if character then
					if Adapter.canBeHit(p.Owner, character) then
						finish(p, result.Position, result.Normal, character)
					else
						ignore(p, character) -- ally / i-frames / dead: pass through
					end
				else
					finish(p, result.Position, result.Normal, nil) -- wall / ground
				end
			else
				p.Position = p.Position + p.Direction * step
				p.Traveled = p.Traveled + step
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	countByPlayer[player] = nil
	for _, p in pairs(active) do
		if p.Owner == player then
			p.Owner = nil
			p.OnHit = nil
			p.OnEnd = nil
			finish(p, p.Position, nil, nil)
		end
	end
end)

return ProjectileService
end

-- ======================================================================
-- MODULE: RaptorModel
-- ======================================================================
__modules["RaptorModel"] = function()
--[[
	RaptorModel  (ReplicatedStorage.SpinShared.RaptorModel)

	Scary Monsters' raptor, built from parts (from the owner's references):
	  * teal head, neck and chest with dark navy stripe rings
	  * deep blue haunches, legs and tail; pale yellow tail underside
	  * yellow "0101" markings along the tail
	  * open jaws with rows of white teeth and a pink mouth/tongue
	  * the yellow pin crown around the back of the skull
	  * small clawed arms, digitigrade legs with yellow toe and sickle claws

	RaptorModel.build(scale, opts) -> rig
	  opts.Lite = true   fewer details (teeth, crown, markings) for crowds
	  opts.Blocky = false  keep rounded shapes (default: TuskConfig.BlockyModels)
	  opts.Palette = { Body, Legs, Head }  recolour the raptor (Color3 values)
	  rig.Model          the Model (all parts anchored, no collision)
	  rig:Pose(groundCF, s)  place every part. groundCF = point on the ground
	                         under the hips, facing the way the raptor looks.
	      s.Phase  walk cycle (radians)     s.Speed  0..1 run amount
	      s.Jaw    0..1 mouth open          s.Lunge  0..1 head/body thrust
	      s.Claw   0..1 arm swipe           s.Crouch 0..1 low stance
	      s.Whip   -1..1 tail whip          s.Time   seconds (idle motion)
	      s.HeadYaw / s.HeadPitch  radians
	  rig:Destroy()
	Size: about 8 studs tall at the head and 15 long at scale 1.
]]

local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Blockify = __require("Blockify")

local RaptorModel = {}

local C = {
	Teal = Color3.fromRGB(95, 205, 212),
	TealDark = Color3.fromRGB(55, 150, 170),
	Navy = Color3.fromRGB(22, 32, 72),
	Blue = Color3.fromRGB(38, 62, 190),
	BlueDark = Color3.fromRGB(24, 40, 140),
	Pale = Color3.fromRGB(242, 234, 172),
	Yellow = Color3.fromRGB(246, 212, 62),
	Gold = Color3.fromRGB(232, 190, 58),
	Mouth = Color3.fromRGB(215, 95, 108),
	Tongue = Color3.fromRGB(230, 130, 140),
	Teeth = Color3.fromRGB(246, 246, 236),
	Eye = Color3.fromRGB(250, 240, 200),
	Pupil = Color3.fromRGB(15, 15, 20),
}
RaptorModel.Colors = C

local TAIL_SEGMENTS = 9
local TAIL_LENGTH = 1.25

local function newPart(model, name, size, color, opts)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = (opts and opts.Material) or Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CastShadow = not (opts and opts.NoShadow)
	if opts and opts.Ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	if opts and opts.Cylinder then
		p.Shape = Enum.PartType.Cylinder
	end
	if opts and opts.Ball then
		p.Shape = Enum.PartType.Ball
	end
	p.Parent = model
	return p
end

function RaptorModel.build(scale, opts)
	scale = scale or 1
	opts = opts or {}
	local lite = opts.Lite == true
	local model = Instance.new("Model")
	model.Name = "ScaryMonstersRaptor"

	local entries = {} -- { Part, Bone, Offset }
	-- Optional recolour (e.g. a victim of Dino Infection in their avatar's colours):
	-- teal skin -> Body (Head colour on the head and jaw), blue -> Legs.
	local palette = opts.Palette
	local function recolor(bone, color)
		if not palette then
			return color
		end
		local onHead = bone == "Head" or bone == "Jaw"
		if color == C.Teal then
			return onHead and (palette.Head or palette.Body) or palette.Body
		elseif color == C.TealDark then
			return (onHead and (palette.Head or palette.Body) or palette.Body):Lerp(Color3.new(0, 0, 0), 0.25)
		elseif color == C.Blue then
			return palette.Legs
		elseif color == C.BlueDark then
			return palette.Legs:Lerp(Color3.new(0, 0, 0), 0.3)
		elseif color == C.Navy then
			return palette.Body:Lerp(Color3.new(0, 0, 0), 0.6)
		end
		if bone:sub(1, 4) == "Tail" and color ~= C.Pale and color ~= C.Yellow then
			return palette.Legs -- tail base blends teal -> blue
		end
		return color
	end
	local function add(bone, name, size, color, offset, partOpts)
		local p = newPart(model, name, size * scale, recolor(bone, color), partOpts)
		local o = offset or CFrame.new()
		table.insert(entries, { Part = p, Bone = bone, Offset = o - o.Position + o.Position * scale })
		return p
	end
	local E = { Ellipsoid = true }
	local function ell(extra)
		local t = { Ellipsoid = true }
		for k, v in pairs(extra or {}) do
			t[k] = v
		end
		return t
	end

	-- BODY (bone origin = middle of the torso)
	add("Body", "Torso", Vector3.new(2.6, 2.7, 4.6), C.Teal, CFrame.new(0, 0, 0), E)
	add("Body", "Chest", Vector3.new(2.35, 2.55, 2.5), C.Teal, CFrame.new(0, 0.25, -2.0), E)
	add("Body", "Belly", Vector3.new(2.1, 1.6, 3.4), C.TealDark, CFrame.new(0, -0.65, -0.6), E)
	for _, side in ipairs({ -1, 1 }) do
		add("Body", "Haunch", Vector3.new(1.5, 2.5, 2.8), C.Blue, CFrame.new(side * 0.85, -0.2, 1.0), E)
	end
	-- Dark stripe rings around the chest and torso.
	for i, z in ipairs({ -2.5, -1.7, -0.9, -0.1 }) do
		local k = 1 - math.abs(z + 1) * 0.08
		add("Body", "Stripe", Vector3.new(2.66 * k, 2.76 * k, 0.24), C.Navy, CFrame.new(0, 0.12, z), E)
	end
	add("Body", "Spine", Vector3.new(0.5, 0.4, 5.6), C.TealDark, CFrame.new(0, 1.3, -0.6), E)

	-- NECK (pitched up)
	add("Neck", "NeckLow", Vector3.new(1.6, 1.7, 2.4), C.Teal, CFrame.new(0, 0, -0.8), E)
	add("Neck", "NeckHigh", Vector3.new(1.4, 1.5, 2.2), C.Teal, CFrame.new(0, 0, -1.9), E)
	for _, z in ipairs({ -0.5, -1.3, -2.1 }) do
		add("Neck", "Stripe", Vector3.new(1.62, 1.72, 0.2), C.Navy, CFrame.new(0, 0, z), E)
	end

	-- HEAD
	add("Head", "Skull", Vector3.new(2.0, 1.8, 2.6), C.Teal, CFrame.new(0, 0.15, -0.6), E)
	add("Head", "Snout", Vector3.new(1.45, 1.0, 2.7), C.Teal, CFrame.new(0, 0.1, -2.2), E)
	add("Head", "MouthRoof", Vector3.new(0.95, 0.12, 2.1), C.Mouth, CFrame.new(0, -0.32, -1.9))
	add("Head", "Brow", Vector3.new(1.85, 0.35, 0.9), C.TealDark, CFrame.new(0, 0.62, -1.0), E)
	for _, side in ipairs({ -1, 1 }) do
		add("Head", "Eye", Vector3.new(0.18, 0.36, 0.42), C.Eye, CFrame.new(side * 0.78, 0.42, -0.95), E)
		add("Head", "Pupil", Vector3.new(0.1, 0.2, 0.12), C.Pupil, CFrame.new(side * 0.86, 0.43, -1.0), ell({ NoShadow = true }))
		add("Head", "Nostril", Vector3.new(0.12, 0.1, 0.16), C.Navy, CFrame.new(side * 0.32, 0.4, -3.1), ell({ NoShadow = true }))
		add("Head", "Cheek", Vector3.new(0.3, 0.6, 1.2), C.TealDark, CFrame.new(side * 0.7, -0.15, -0.6), E)
		if not lite then
			for k = 0, 5 do
				local tooth = add("Head", "Tooth", Vector3.new(0.1, 0.32, 0.12), C.Teeth, CFrame.new(side * (0.5 - k * 0.04), -0.42, -1.1 - k * 0.36) * CFrame.Angles(0, 0, side * 0.1), { NoShadow = true })
				tooth.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	-- The yellow pin crown fanned around the back of the skull.
	local pins = lite and 4 or 7
	for k = 1, pins do
		local a = -1.25 + (k - 1) / (pins - 1) * 2.5 -- side to side over the top
		local dir = Vector3.new(math.sin(a), math.cos(a), 0.35).Unit
		local base = Vector3.new(0, 0.2, -0.3) + dir * 0.72
		local pinCF = CFrame.lookAt(base + dir * 0.55, base + dir * 2) * CFrame.Angles(0, math.pi / 2, 0)
		add("Head", "CrownPin", Vector3.new(1.1, 0.12, 0.12), C.Gold, pinCF, { Cylinder = true, Material = Enum.Material.Metal })
		add("Head", "CrownBall", Vector3.new(0.3, 0.3, 0.3), C.Yellow, CFrame.new(base + dir * 1.15), { Ball = true, Material = Enum.Material.Metal })
	end

	-- JAW
	add("Jaw", "LowerJaw", Vector3.new(1.35, 0.55, 2.7), C.Teal, CFrame.new(0, -0.12, -1.55), E)
	add("Jaw", "Tongue", Vector3.new(0.7, 0.16, 1.7), C.Tongue, CFrame.new(0, 0.04, -1.3), E)
	add("Jaw", "Throat", Vector3.new(0.9, 0.5, 1.0), C.Pale, CFrame.new(0, -0.25, -0.4), E)
	if not lite then
		for _, side in ipairs({ -1, 1 }) do
			for k = 0, 4 do
				add("Jaw", "Tooth", Vector3.new(0.1, 0.28, 0.12), C.Teeth, CFrame.new(side * (0.42 - k * 0.04), 0.18, -0.95 - k * 0.36), { NoShadow = true })
			end
		end
	end

	-- TAIL (bone i starts at segment i and points backward, +Z)
	for i = 1, TAIL_SEGMENTS do
		local k = (i - 1) / TAIL_SEGMENTS
		local d = 1.95 * (1 - k * 0.85)
		local color = i <= 2 and C.Teal:Lerp(C.Blue, (i - 1) / 2) or C.Blue
		add("Tail" .. i, "Tail", Vector3.new(d, d * 0.92, TAIL_LENGTH * 1.75), color, CFrame.new(0, 0, TAIL_LENGTH / 2), E)
		add("Tail" .. i, "TailBelly", Vector3.new(d * 0.72, d * 0.4, TAIL_LENGTH * 1.7), C.Pale, CFrame.new(0, -d * 0.3, TAIL_LENGTH / 2), E)
		if not lite and i >= 2 and i <= 8 then
			-- Yellow "0101" markings riding on top of the tail.
			local strip = add("Tail" .. i, "Marking", Vector3.new(d * 0.55, 0.05, TAIL_LENGTH), C.Yellow, CFrame.new(0, d * 0.47, TAIL_LENGTH / 2), { NoShadow = true })
			strip.Transparency = 1
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Top
			gui.LightInfluence = 0.3
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 30
			gui.Parent = strip
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.Arcade
			label.TextScaled = true
			label.TextColor3 = C.Yellow
			label.Rotation = 90
			label.Text = (i % 2 == 0) and "0101" or "1010"
			label.Parent = gui
		end
	end

	-- LEGS
	for _, side in ipairs({ -1, 1 }) do
		local s = side > 0 and "R" or "L"
		add("Thigh" .. s, "Thigh", Vector3.new(1.2, 2.4, 1.5), C.Blue, CFrame.new(0, -0.95, 0), E)
		add("Shin" .. s, "Shin", Vector3.new(0.75, 2.3, 0.85), C.Blue, CFrame.new(0, -1.0, 0), E)
		add("Meta" .. s, "Metatarsal", Vector3.new(0.55, 1.4, 0.6), C.BlueDark, CFrame.new(0, -0.6, 0), E)
		for t = -1, 1 do
			add("Foot" .. s, "Toe", Vector3.new(0.28, 0.26, 1.0), C.BlueDark, CFrame.new(t * 0.3, 0.14, -0.45 - math.abs(t) * -0.05) * CFrame.Angles(0, -t * 0.25, 0), E)
			add("Foot" .. s, "ToeClaw", Vector3.new(0.18, 0.34, 0.36), C.Yellow, CFrame.new(t * 0.3 - t * 0.12, 0.12, -1.02) * CFrame.Angles(-0.5, -t * 0.25, 0), { NoShadow = true })
		end
		-- The big curved sickle claw on the second toe.
		add("Foot" .. s, "SickleClaw", Vector3.new(0.16, 0.55, 0.5), C.Yellow, CFrame.new(-side * 0.08, 0.5, -0.15) * CFrame.Angles(0.6, 0, 0), { NoShadow = true })
	end

	-- ARMS
	for _, side in ipairs({ -1, 1 }) do
		local s = side > 0 and "R" or "L"
		add("UpperArm" .. s, "UpperArm", Vector3.new(0.55, 1.3, 0.6), C.Teal, CFrame.new(0, -0.55, 0), E)
		add("Forearm" .. s, "Forearm", Vector3.new(0.45, 1.15, 0.5), C.Teal, CFrame.new(0, -0.5, 0), E)
		for c = -1, 1 do
			add("Forearm" .. s, "Claw", Vector3.new(0.12, 0.55, 0.14), C.Yellow, CFrame.new(c * 0.15, -1.2, -0.12) * CFrame.Angles(0.6, 0, 0), { NoShadow = true })
		end
	end

	-- Blocky (classic Roblox) look: boxes instead of rounded shapes.
	if opts.Blocky ~= false and Blockify.enabled(TuskConfig) then
		Blockify.apply(model, { Voxel = false }) -- parts are posed one by one
	end

	local rig = { Model = model, Scale = scale, Entries = entries }

	local function bonesFor(ground, s)
		local sc = scale
		local t = s.Time or 0
		local speed = s.Speed or 0
		local phase = s.Phase or 0
		local lunge = s.Lunge or 0
		local crouch = s.Crouch or 0
		local claw = s.Claw or 0
		local jaw = s.Jaw or 0
		local whip = s.Whip or 0
		local idle = 1 - math.min(speed, 1)
		local breath = math.sin(t * 2.4) * 0.04 * idle
		local bob = math.abs(math.sin(phase)) * 0.18 * speed
		local bones = {}
		local function at(x, y, z)
			return CFrame.new(x * sc, y * sc, z * sc)
		end
		local body = ground * at(0, 4.6 + bob - crouch * 0.9, -0.3 - lunge * 1.3)
			* CFrame.Angles(0.1 - lunge * 0.3 - crouch * 0.12 + breath, whip * 0.5, math.sin(phase) * 0.04 * speed)
		bones.Body = body
		local neck = body * at(0, 0.5, -2.6) * CFrame.Angles(0.8 - lunge * 0.45 + (s.HeadPitch or 0) * 0.5 + breath * 2, (s.HeadYaw or 0) * 0.5, 0)
		bones.Neck = neck
		local head = neck * at(0, 0, -2.5) * CFrame.Angles(-0.85 + lunge * 0.2 + (s.HeadPitch or 0) * 0.5 + jaw * 0.2, (s.HeadYaw or 0) * 0.5, 0)
		bones.Head = head
		bones.Jaw = head * at(0, -0.3, 0.2) * CFrame.Angles(-0.06 - jaw * 0.8, 0, 0)
		-- Tail: sways while idle, swings harder when running, whips on attacks.
		local tail = body * at(0, 0.15, 2.1)
		for i = 1, TAIL_SEGMENTS do
			local k = i / TAIL_SEGMENTS
			local sway = math.sin(t * 2.2 - i * 0.55) * (0.06 + 0.08 * speed) + whip * 0.35 * (1 - k * 0.5)
			local lift = (i == 1 and 0.12 or 0) + (i >= 2 and i <= 4 and 0.04 or 0) + (i >= 6 and -0.12 or 0) - speed * 0.02
			tail = tail * CFrame.Angles(lift, sway, 0)
			bones["Tail" .. i] = tail
			tail = tail * at(0, 0, TAIL_LENGTH * 0.92)
		end
		-- Legs (digitigrade): hip -> knee -> ankle -> toes.
		local flatGround = ground - ground.Position
		for _, side in ipairs({ -1, 1 }) do
			local s2 = side > 0 and "R" or "L"
			local off = side > 0 and 0 or math.pi
			local swing = math.sin(phase + off) * 0.65 * speed
			local liftAmt = math.max(0, math.cos(phase + off)) * speed
			local hip = body * at(side * 0.95, -0.25, 1.0)
			local thigh = hip * CFrame.Angles(math.rad(28) + swing - crouch * 0.55 + lunge * 0.2, 0, side * 0.05)
			bones["Thigh" .. s2] = thigh
			local knee = thigh * at(0, -2.0, 0) * CFrame.Angles(math.rad(-78) - liftAmt * 0.7 - crouch * 0.7, 0, 0)
			bones["Shin" .. s2] = knee
			local ankle = knee * at(0, -2.0, 0) * CFrame.Angles(math.rad(62) + liftAmt * 0.6 + crouch * 0.6, 0, 0)
			bones["Meta" .. s2] = ankle
			local toe = ankle * at(0, -1.2, 0)
			bones["Foot" .. s2] = CFrame.new(toe.Position) * flatGround * CFrame.Angles(liftAmt * 0.5, 0, 0)
		end
		-- Arms: tucked, raking forward on claw attacks.
		for _, side in ipairs({ -1, 1 }) do
			local s2 = side > 0 and "R" or "L"
			local shoulder = body * at(side * 0.95, 0.15, -2.5)
			local upper = shoulder * CFrame.Angles(math.rad(35) + claw * 1.4 + math.sin(phase + (side > 0 and math.pi or 0)) * 0.12 * speed, 0, side * (0.2 + claw * 0.2))
			bones["UpperArm" .. s2] = upper
			bones["Forearm" .. s2] = upper * at(0, -1.1, 0) * CFrame.Angles(math.rad(70) - claw * 0.9, 0, 0)
		end
		return bones
	end

	local parts, cframes = {}, {}
	for i, e in ipairs(entries) do
		parts[i] = e.Part
	end

	function rig:Pose(ground, s)
		local bones = bonesFor(ground, s or {})
		for i, e in ipairs(entries) do
			cframes[i] = bones[e.Bone] * e.Offset
		end
		local ok = pcall(function()
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end)
		if not ok then
			for i, p in ipairs(parts) do
				p.CFrame = cframes[i]
			end
		end
	end

	function rig:SetTransparency(t)
		for _, e in ipairs(entries) do
			if e.Part.Name ~= "Marking" then
				e.Part.Transparency = t
			end
		end
	end

	function rig:Destroy()
		model:Destroy()
	end

	return rig
end

return RaptorModel
end

-- ======================================================================
-- MODULE: SBRMapBuilder
-- ======================================================================
__modules["SBRMapBuilder"] = function()
--[[
	SBRMapBuilder  (ServerStorage.SpinTools.SBRMapBuilder — ModuleScript)

	One-time Studio tool that builds an original Steel Ball Run-style
	western map into your place as normal, editable parts + terrain:

	  * race grounds: dirt track, rail fences, START/GOAL arch, flags
	  * mission church at the end of the track
	  * racers' tent camp with covered wagons
	  * western town (saloon, store, sheriff, hotel, bank, stables,
	    post office, blacksmith) with an entrance banner arch
	  * Race Headquarters building on the hill
	  * desert: sand terrain, mountain ring, rocks, cacti, grass patches
	  * desert lighting, atmosphere, clouds, spawn point
	  * NPC spawn markers (NPCService turns them into NPCs at runtime)
	  * new places: Rattlesnake River with a mesa waterfall, covered bridge
	    and railway trestle, gold-panning camp, Dustwater ghost town,
	    Lucky Horseshoe Ranch, Fort Dust, and a signpost at the race start

	HOW TO RUN (Studio, edit mode):
	  View > Command Bar, paste and press Enter:
	    require(game.ServerStorage.SpinTools.SBRMapBuilder).Build()
	  Options:
	    .Build({ Origin = Vector3.new(0, 0, 0), Terrain = true, Lighting = true, Seed = 7 })
	  Running it again replaces the previous "SBRMap" model (terrain is
	  re-filled in the map area only). Tip: try it in a new Baseplate place
	  first, or pass an Origin away from your existing map.
	  Then File > Save.
]]

local Lighting = game:GetService("Lighting")

local SBRMapBuilder = {}

local C = {
	Stucco = Color3.fromRGB(214, 198, 170),
	StuccoDark = Color3.fromRGB(176, 158, 128),
	Wood = Color3.fromRGB(122, 84, 52),
	WoodDark = Color3.fromRGB(84, 56, 34),
	WoodLight = Color3.fromRGB(160, 118, 76),
	Canvas = Color3.fromRGB(232, 226, 210),
	Red = Color3.fromRGB(176, 40, 36),
	White = Color3.fromRGB(240, 236, 228),
	Brick = Color3.fromRGB(150, 70, 56),
	Roof = Color3.fromRGB(96, 40, 44),
	Window = Color3.fromRGB(40, 36, 44),
	Green = Color3.fromRGB(70, 120, 50),
	Cactus = Color3.fromRGB(80, 120, 60),
	Gold = Color3.fromRGB(220, 170, 60),
}

local FLAG_PALETTES = {
	{ Color3.fromRGB(200, 30, 40), Color3.fromRGB(245, 245, 240) },
	{ Color3.fromRGB(30, 60, 150), Color3.fromRGB(245, 245, 240), Color3.fromRGB(200, 30, 40) },
	{ Color3.fromRGB(20, 120, 60), Color3.fromRGB(250, 210, 40) },
	{ Color3.fromRGB(245, 245, 240), Color3.fromRGB(30, 110, 60) },
	{ Color3.fromRGB(20, 20, 20), Color3.fromRGB(250, 200, 30), Color3.fromRGB(200, 30, 40) },
	{ Color3.fromRGB(30, 80, 170), Color3.fromRGB(250, 210, 40) },
	{ Color3.fromRGB(200, 30, 40), Color3.fromRGB(30, 60, 150) },
}

local root, origin, rng

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or root
	return f
end

local function block(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(origin) * cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function cylinder(parent, name, length, diameter, cf, color, material)
	-- Cylinder axis is X; callers pass cf with the axis already rotated as needed.
	return block(parent, name, Vector3.new(length, diameter, diameter), cf, color, material, { Shape = Enum.PartType.Cylinder })
end

local function upright(x, y, z)
	return CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2)
end

local function sign(part, face, text, textColor, bg, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bg or part.Color
	label.BackgroundTransparency = bg and 0 or 1
	label.Font = font or Enum.Font.Fondamento
	label.TextScaled = true
	label.TextColor3 = textColor or Color3.fromRGB(30, 20, 10)
	label.Text = text
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = label
	return gui
end

local function stripedPole(parent, x, z, height)
	local segments = 8
	local seg = height / segments
	for i = 0, segments - 1 do
		cylinder(parent, "PoleStripe", seg, 1.2, upright(x, seg * (i + 0.5), z), i % 2 == 0 and C.Red or C.White)
	end
	block(parent, "PoleCap", Vector3.new(1.5, 1.5, 1.5), CFrame.new(x, height + 0.6, z), C.Gold, Enum.Material.Metal, { Shape = Enum.PartType.Ball })
end

local function flag(parent, x, z, height, palette, yaw)
	cylinder(parent, "FlagPole", height, 0.35, upright(x, height / 2, z), C.WoodLight, Enum.Material.Wood)
	local stripes = #palette
	local w, h = 5, 3.2
	for i, color in ipairs(palette) do
		local stripeH = h / stripes
		block(parent, "Flag", Vector3.new(w, stripeH, 0.12),
			CFrame.new(x, height - 0.4 - stripeH * (i - 0.5), z) * CFrame.Angles(0, yaw or 0, 0) * CFrame.new(w / 2 + 0.2, 0, 0),
			color, Enum.Material.Fabric)
	end
end

local function tent(parent, x, z, yaw, scale)
	scale = scale or 1
	-- A block rotated 45 degrees and sunk halfway reads as an A-frame tent.
	local s = 6 * scale
	block(parent, "Tent", Vector3.new(s, s, 9 * scale),
		CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.pi / 4),
		C.Canvas, Enum.Material.Fabric)
	block(parent, "TentDoor", Vector3.new(1.6 * scale, 2.2 * scale, 0.1),
		CFrame.new(x, 1.1 * scale, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -4.5 * scale - 0.06),
		C.WoodDark, Enum.Material.Fabric)
end

local function wagon(parent, x, z, yaw)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local function at(cf)
		return base * cf
	end
	local model = Instance.new("Model")
	model.Name = "CoveredWagon"
	model.Parent = parent
	block(model, "Bed", Vector3.new(4.4, 1.6, 9), at(CFrame.new(0, 2.6, 0)), C.Wood, Enum.Material.WoodPlanks)
	-- Canvas: long cylinder along Z, lower half hidden inside the bed.
	block(model, "Canvas", Vector3.new(8.6, 4.6, 4.6), at(CFrame.new(0, 3.3, 0) * CFrame.Angles(0, math.pi / 2, 0)), C.Canvas, Enum.Material.Fabric, { Shape = Enum.PartType.Cylinder })
	for _, wz in ipairs({ -3, 3 }) do
		for _, wx in ipairs({ -2.5, 2.5 }) do
			local d = wz > 0 and 3.6 or 3
			block(model, "Wheel", Vector3.new(0.4, d, d), at(CFrame.new(wx, d / 2, wz)), C.WoodDark, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
		end
	end
	block(model, "Tongue", Vector3.new(0.4, 0.4, 5), at(CFrame.new(0, 1.6, -7) * CFrame.Angles(0.15, 0, 0)), C.WoodDark, Enum.Material.Wood)
end

local function fenceLine(parent, x, z0, z1)
	local step = 8
	local count = math.floor(math.abs(z1 - z0) / step)
	local dir = z1 > z0 and 1 or -1
	for i = 0, count do
		local z = z0 + i * step * dir
		block(parent, "FencePost", Vector3.new(0.6, 3.4, 0.6), CFrame.new(x, 1.7, z), C.WoodDark, Enum.Material.Wood)
	end
	local length = count * step
	local mid = z0 + dir * length / 2
	for _, y in ipairs({ 1.4, 2.8 }) do
		block(parent, "FenceRail", Vector3.new(0.35, 0.35, length), CFrame.new(x, y, mid), C.WoodLight, Enum.Material.Wood)
	end
end

local function windowRow(parent, cf, count, spacing, size)
	for i = 1, count do
		local offset = (i - (count + 1) / 2) * spacing
		block(parent, "Window", size, cf * CFrame.new(offset, 0, 0), C.Window, Enum.Material.Glass, { Transparency = 0.1 })
	end
end

---------------------------------------------------------------------------
-- Sections
---------------------------------------------------------------------------
local function buildTerrain()
	local terrain = workspace.Terrain
	local o = origin
	terrain:FillBlock(CFrame.new(o + Vector3.new(0, -8, 0)), Vector3.new(1400, 16, 1400), Enum.Material.Sand)
	-- Race track strip and town street (hard-packed ground).
	terrain:FillBlock(CFrame.new(o + Vector3.new(0, -0.6, -50)), Vector3.new(26, 1.2, 420), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(o + Vector3.new(260, -0.6, -40)), Vector3.new(30, 1.2, 240), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(o + Vector3.new(130, -0.6, 100)), Vector3.new(260, 1.2, 18), Enum.Material.Ground)
	-- Grass around the town and headquarters hill.
	for _ = 1, 26 do
		local p = o + Vector3.new(rng:NextNumber(180, 360), -0.8, rng:NextNumber(-220, 120))
		terrain:FillCylinder(CFrame.new(p), 1, rng:NextNumber(6, 18), Enum.Material.Grass)
	end
	-- Headquarters hill.
	terrain:FillBall(o + Vector3.new(260, -70, -265), 90, Enum.Material.Grass)
	-- Mountain ring.
	for i = 1, 30 do
		local angle = (i / 30) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local dist = rng:NextNumber(520, 620)
		local radius = rng:NextNumber(70, 130)
		local p = o + Vector3.new(math.cos(angle) * dist, -radius * 0.45, math.sin(angle) * dist)
		terrain:FillBall(p, radius, i % 3 == 0 and Enum.Material.Rock or Enum.Material.Sandstone)
	end
	-- Rocks scattered in the desert.
	for _ = 1, 60 do
		local p = o + Vector3.new(rng:NextNumber(-450, 450), 0, rng:NextNumber(-450, 450))
		if math.abs(p.X - o.X) > 30 or math.abs(p.Z - o.Z + 50) > 220 then
			terrain:FillBall(p, rng:NextNumber(2, 6), Enum.Material.Sandstone)
		end
	end
end

local function buildLighting()
	Lighting.ClockTime = 14.6
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(110, 96, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 135, 115)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	local function ensure(class, name)
		local existing = Lighting:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
		local inst = Instance.new(class)
		inst.Name = name
		inst.Parent = Lighting
		return inst
	end
	local atmosphere = ensure("Atmosphere", "SBRAtmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(230, 205, 170)
	atmosphere.Decay = Color3.fromRGB(190, 150, 110)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.6
	local cc = ensure("ColorCorrectionEffect", "SBRWarmth")
	cc.TintColor = Color3.fromRGB(255, 244, 228)
	cc.Saturation = 0.05
	cc.Contrast = 0.06
	local rays = ensure("SunRaysEffect", "SBRSunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	local bloom = ensure("BloomEffect", "SBRBloom")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.6
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = workspace.Terrain
end

local function buildRaceGrounds()
	local f = folder("RaceGrounds")
	fenceLine(f, -14, 140, -250)
	fenceLine(f, 14, 140, -250)

	-- START / GOAL arch.
	local archZ = 110
	stripedPole(f, -16, archZ, 22)
	stripedPole(f, 16, archZ, 22)
	local bannerPart = block(f, "RaceBanner", Vector3.new(30, 6, 0.4), CFrame.new(0, 18, archZ), C.White, Enum.Material.Fabric)
	sign(bannerPart, Enum.NormalId.Front, "★ STEEL BALL RUN ★  START", C.Red, C.White, Enum.Font.Fondamento)
	sign(bannerPart, Enum.NormalId.Back, "★ STEEL BALL RUN ★  GOAL", C.Red, C.White, Enum.Font.Fondamento)
	for _, x in ipairs({ -12.5, 12.5 }) do
		block(f, "BannerStripe", Vector3.new(1, 6, 0.45), CFrame.new(x, 18, archZ), C.Red, Enum.Material.Fabric)
	end

	-- Flags lining the track.
	for i = 0, 11 do
		local z = 120 - i * 32
		flag(f, -22, z, 16, FLAG_PALETTES[(i % #FLAG_PALETTES) + 1], math.pi)
		flag(f, 22, z - 16, 16, FLAG_PALETTES[((i + 3) % #FLAG_PALETTES) + 1], 0)
	end

	-- Spectator stand near the start.
	for row = 0, 3 do
		block(f, "Bleacher", Vector3.new(4, 1, 40), CFrame.new(-30 - row * 4, 1 + row * 1.6, 70), C.WoodLight, Enum.Material.WoodPlanks)
	end
	block(f, "BleacherRoof", Vector3.new(20, 0.6, 44), CFrame.new(-36, 11, 70) * CFrame.Angles(0, 0, -0.12), C.Red, Enum.Material.Fabric)
	for _, z in ipairs({ 50, 90 }) do
		cylinder(f, "BleacherPost", 10, 0.6, upright(-27, 5, z), C.WoodDark, Enum.Material.Wood)
		cylinder(f, "BleacherPost", 12, 0.6, upright(-45, 6, z), C.WoodDark, Enum.Material.Wood)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SBRSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(origin + Vector3.new(0, 0.5, 150))
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Color = C.WoodLight
	spawn.Duration = 0
	spawn.Parent = f
end

local function buildChurch()
	local f = folder("MissionChurch")
	local z = -300
	block(f, "Nave", Vector3.new(36, 24, 60), CFrame.new(0, 12, z - 20), C.Stucco, Enum.Material.Limestone)
	block(f, "NaveRoof", Vector3.new(38, 2, 62), CFrame.new(0, 25, z - 20), C.StuccoDark, Enum.Material.Limestone)
	local facade = block(f, "Facade", Vector3.new(40, 30, 3), CFrame.new(0, 15, z + 11), C.Stucco, Enum.Material.Limestone)
	block(f, "FacadeGable", Vector3.new(16, 8, 3), CFrame.new(0, 33, z + 11), C.Stucco, Enum.Material.Limestone)
	block(f, "Doorway", Vector3.new(9, 13, 0.4), CFrame.new(0, 6.5, z + 12.6), C.WoodDark, Enum.Material.Wood)
	block(f, "DoorArch", Vector3.new(9, 9, 0.5), CFrame.new(0, 13, z + 12.5) * CFrame.Angles(0, math.pi / 2, 0), C.WoodDark, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
	windowRow(f, CFrame.new(0, 22, z + 12.6), 3, 6, Vector3.new(2, 4, 0.3))
	for _, x in ipairs({ -22, 22 }) do
		block(f, "BellTower", Vector3.new(12, 44, 12), CFrame.new(x, 22, z + 8), C.Stucco, Enum.Material.Limestone)
		block(f, "BellLoft", Vector3.new(9, 8, 9), CFrame.new(x, 48, z + 8), C.StuccoDark, Enum.Material.Limestone)
		block(f, "BellOpening", Vector3.new(4, 5, 9.2), CFrame.new(x, 48, z + 8), C.Window, Enum.Material.SmoothPlastic)
		block(f, "TowerDome", Vector3.new(8, 8, 8), CFrame.new(x, 52, z + 8), C.StuccoDark, Enum.Material.Limestone, { Shape = Enum.PartType.Ball })
		block(f, "CrossV", Vector3.new(0.5, 4, 0.5), CFrame.new(x, 58, z + 8), C.WoodDark, Enum.Material.Wood)
		block(f, "CrossH", Vector3.new(2.2, 0.5, 0.5), CFrame.new(x, 58.6, z + 8), C.WoodDark, Enum.Material.Wood)
		windowRow(f, CFrame.new(x, 30, z + 14.1), 1, 0, Vector3.new(2.2, 4, 0.3))
	end
	block(f, "Dome", Vector3.new(20, 20, 20), CFrame.new(0, 26, z - 26), C.StuccoDark, Enum.Material.Limestone, { Shape = Enum.PartType.Ball })
	block(f, "DomeLantern", Vector3.new(3, 5, 3), CFrame.new(0, 37, z - 26), C.Stucco, Enum.Material.Limestone)
	-- Courtyard wall with gate.
	for _, x in ipairs({ -32, 32 }) do
		block(f, "CourtWall", Vector3.new(20, 8, 2), CFrame.new(x, 4, z + 24), C.Brick, Enum.Material.Brick)
	end
	for _, x in ipairs({ -22, 22 }) do
		block(f, "CourtWallSide", Vector3.new(2, 8, 14), CFrame.new(x * 1.92, 4, z + 17), C.Brick, Enum.Material.Brick)
	end
end

local function buildCamp()
	local f = folder("TentCamp")
	for side = -1, 1, 2 do
		for i = 0, 13 do
			for j = 0, 2 do
				local x = side * (40 + j * 24 + rng:NextNumber(-4, 4))
				local z = 40 - i * 18 + rng:NextNumber(-4, 4)
				if rng:NextNumber() < 0.68 then
					tent(f, x, z, rng:NextNumber(-0.4, 0.4) + (side > 0 and math.pi / 2 or -math.pi / 2), rng:NextNumber(0.85, 1.15))
				elseif rng:NextNumber() < 0.6 then
					wagon(f, x, z, rng:NextNumber(0, math.pi * 2))
				end
			end
		end
	end
	-- Campfires.
	for _ = 1, 8 do
		local x = (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(45, 100)
		local z = rng:NextNumber(-200, 50)
		local fire = block(f, "Campfire", Vector3.new(2.4, 0.6, 2.4), CFrame.new(x, 0.3, z), C.WoodDark, Enum.Material.Wood)
		local emitter = Instance.new("Fire")
		emitter.Size = 4
		emitter.Heat = 6
		emitter.Parent = fire
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 160, 80)
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = fire
	end
end

local TOWN_BUILDINGS = { "SALOON", "GENERAL STORE", "SHERIFF", "HOTEL", "BANK", "STABLES", "POST OFFICE", "BLACKSMITH" }

local function westernBuilding(parent, name, cf, width, depth, height, color)
	local model = Instance.new("Model")
	model.Name = name:gsub(" ", "")
	model.Parent = parent
	local function at(offset)
		return cf * offset
	end
	block(model, "Body", Vector3.new(width, height, depth), at(CFrame.new(0, height / 2, depth / 2)), color, Enum.Material.WoodPlanks)
	block(model, "Roof", Vector3.new(width + 1, 1, depth + 1), at(CFrame.new(0, height + 0.5, depth / 2)), C.Roof, Enum.Material.WoodPlanks)
	-- False front, taller than the building (classic western look).
	local front = block(model, "FalseFront", Vector3.new(width + 1, height + 6, 1), at(CFrame.new(0, (height + 6) / 2, -0.5)), color, Enum.Material.WoodPlanks)
	local board = block(model, "SignBoard", Vector3.new(width - 2, 3.2, 0.3), at(CFrame.new(0, height + 2.5, -1.15)), C.WoodDark, Enum.Material.Wood)
	sign(board, Enum.NormalId.Front, name, Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	-- Door, windows, porch.
	block(model, "Door", Vector3.new(3.2, 6.5, 0.3), at(CFrame.new(0, 3.25, -1.1)), C.WoodDark, Enum.Material.Wood)
	windowRow(model, at(CFrame.new(0, 4, -1.1)), 2, width * 0.55, Vector3.new(3, 3.6, 0.2))
	windowRow(model, at(CFrame.new(0, height - 3, -1.1)), 3, width * 0.28, Vector3.new(2.4, 3, 0.2))
	block(model, "PorchFloor", Vector3.new(width + 1, 0.6, 6), at(CFrame.new(0, 0.3, -4)), C.WoodLight, Enum.Material.WoodPlanks)
	block(model, "PorchRoof", Vector3.new(width + 1, 0.5, 6.5), at(CFrame.new(0, 8.6, -4) * CFrame.Angles(-0.12, 0, 0)), C.Roof, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -width / 2, 0, width / 2 }) do
		block(model, "PorchPost", Vector3.new(0.5, 8, 0.5), at(CFrame.new(x, 4.3, -6.8)), C.WoodDark, Enum.Material.Wood)
	end
	return model
end

local function buildTown()
	local f = folder("WesternTown")
	local streetX = 260
	local colors = { C.Wood, C.WoodLight, Color3.fromRGB(150, 90, 70), Color3.fromRGB(120, 110, 90), C.Brick }
	for i, name in ipairs(TOWN_BUILDINGS) do
		local side = (i % 2 == 1) and -1 or 1
		local row = math.floor((i - 1) / 2)
		local z = 40 - row * 34
		local x = streetX + side * 24
		-- Front faces the street.
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, side * math.pi / 2, 0)
		westernBuilding(f, name, cf, 18, 20, 12 + (i % 3) * 2, colors[(i % #colors) + 1])
	end
	-- Entrance arch banner.
	for _, x in ipairs({ streetX - 15, streetX + 15 }) do
		block(f, "ArchPost", Vector3.new(1.4, 20, 1.4), CFrame.new(x, 10, 90), C.WoodDark, Enum.Material.Wood)
	end
	block(f, "ArchBeam", Vector3.new(34, 1.4, 1.4), CFrame.new(streetX, 19.5, 90), C.WoodDark, Enum.Material.Wood)
	local banner = block(f, "TownBanner", Vector3.new(26, 5, 0.3), CFrame.new(streetX, 15.5, 90), Color3.fromRGB(150, 175, 90), Enum.Material.Fabric)
	sign(banner, Enum.NormalId.Front, "★ STEEL BALL RUN RACE ★", Color3.fromRGB(25, 25, 20), nil, Enum.Font.Fondamento)
	sign(banner, Enum.NormalId.Back, "★ STEEL BALL RUN RACE ★", Color3.fromRGB(25, 25, 20), nil, Enum.Font.Fondamento)
	-- Props: barrels, crates, troughs, hitching rails, lamp posts.
	for i = 1, 14 do
		local side = i % 2 == 0 and -1 or 1
		local z = 50 - i * 12
		local x = streetX + side * rng:NextNumber(11, 13)
		local roll = rng:NextNumber()
		if roll < 0.35 then
			block(f, "Barrel", Vector3.new(3, 2.4, 2.4), upright(x, 1.5, z), C.Wood, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
		elseif roll < 0.6 then
			block(f, "Crate", Vector3.new(2.6, 2.6, 2.6), CFrame.new(x, 1.3, z) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), C.WoodLight, Enum.Material.WoodPlanks)
		elseif roll < 0.8 then
			block(f, "Trough", Vector3.new(2, 1.6, 6), CFrame.new(x, 0.8, z), C.WoodDark, Enum.Material.Wood)
			block(f, "TroughWater", Vector3.new(1.6, 0.2, 5.6), CFrame.new(x, 1.5, z), Color3.fromRGB(70, 110, 130), Enum.Material.Glass, { Transparency = 0.3 })
		else
			block(f, "HitchRail", Vector3.new(0.4, 0.4, 7), CFrame.new(x, 2.8, z), C.WoodDark, Enum.Material.Wood)
			block(f, "HitchPost", Vector3.new(0.4, 3, 0.4), CFrame.new(x, 1.5, z - 3.3), C.WoodDark, Enum.Material.Wood)
			block(f, "HitchPost", Vector3.new(0.4, 3, 0.4), CFrame.new(x, 1.5, z + 3.3), C.WoodDark, Enum.Material.Wood)
		end
	end
	for i = 0, 4 do
		for _, side in ipairs({ -1, 1 }) do
			local x, z = streetX + side * 14, 60 - i * 34
			block(f, "LampPost", Vector3.new(0.4, 10, 0.4), CFrame.new(x, 5, z), Color3.fromRGB(40, 40, 40), Enum.Material.Metal)
			local lamp = block(f, "Lamp", Vector3.new(1, 1.4, 1), CFrame.new(x, 10.4, z), Color3.fromRGB(255, 220, 150), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Range = 16
			light.Brightness = 0.8
			light.Color = Color3.fromRGB(255, 200, 130)
			light.Parent = lamp
		end
	end
end

local function buildHeadquarters()
	local f = folder("RaceHeadquarters")
	local base = CFrame.new(260, 18, -270)
	local function at(cf)
		return base * cf
	end
	block(f, "Foundation", Vector3.new(96, 24, 36), at(CFrame.new(0, -12, 0)), Color3.fromRGB(150, 140, 120), Enum.Material.Cobblestone)
	block(f, "Main", Vector3.new(90, 22, 30), at(CFrame.new(0, 11, 0)), C.Brick, Enum.Material.Brick)
	block(f, "Roof", Vector3.new(92, 3, 32), at(CFrame.new(0, 23.5, 0)), C.Roof, Enum.Material.Slate)
	for _, y in ipairs({ 6, 16 }) do
		windowRow(f, at(CFrame.new(0, y, 15.1)), 11, 7.6, Vector3.new(2.6, 5, 0.3))
	end
	for _, x in ipairs({ -36, 0, 36 }) do
		local h = x == 0 and 18 or 12
		block(f, "Tower", Vector3.new(10, h, 10), at(CFrame.new(x, 22 + h / 2, 2)), C.Brick, Enum.Material.Brick)
		block(f, "Spire", Vector3.new(7, 9, 7), at(CFrame.new(x, 22 + h + 3, 2) * CFrame.Angles(0, math.pi / 4, 0)), C.Roof, Enum.Material.Slate)
		block(f, "SpireTip", Vector3.new(3, 6, 3), at(CFrame.new(x, 22 + h + 9, 2) * CFrame.Angles(0, math.pi / 4, 0)), C.Roof, Enum.Material.Slate)
		block(f, "SpirePole", Vector3.new(0.3, 4, 0.3), at(CFrame.new(x, 22 + h + 13.5, 2)), C.WoodDark, Enum.Material.Wood)
		block(f, "SpireFlag", Vector3.new(2.6, 1.6, 0.1), at(CFrame.new(x + 1.4, 22 + h + 14.6, 2)), Color3.fromRGB(110, 190, 120), Enum.Material.Fabric)
	end
	local billboard = block(f, "RaceSign", Vector3.new(40, 16, 1), at(CFrame.new(0, 2, 34)), C.Red, Enum.Material.WoodPlanks)
	sign(billboard, Enum.NormalId.Front, "STEEL BALL RUN\nRACE HEADQUARTERS", Color3.fromRGB(240, 200, 120), nil, Enum.Font.Fondamento)
	for _, x in ipairs({ -16, 16 }) do
		block(f, "SignLeg", Vector3.new(1, 12, 1), at(CFrame.new(x, -6, 34.8)), C.WoodDark, Enum.Material.Wood)
	end
end

local function cactus(parent, x, z)
	local h = rng:NextNumber(7, 14)
	cylinder(parent, "CactusTrunk", h, 1.6, upright(x, h / 2, z), C.Cactus, Enum.Material.Grass)
	local arms = rng:NextInteger(0, 2)
	for i = 1, arms do
		local side = i == 1 and 1 or -1
		local armY = h * rng:NextNumber(0.4, 0.65)
		local armH = rng:NextNumber(2.5, 4.5)
		block(parent, "CactusArm", Vector3.new(2.2, 1.1, 1.1), CFrame.new(x + side * 1.3, armY, z), C.Cactus, Enum.Material.Grass)
		cylinder(parent, "CactusArm", armH, 1.1, upright(x + side * 2.2, armY + armH / 2, z), C.Cactus, Enum.Material.Grass)
	end
end

local function buildDesert()
	local f = folder("Desert")
	for _ = 1, 55 do
		local x, z = rng:NextNumber(-450, 450), rng:NextNumber(-450, 450)
		local nearTrack = math.abs(x) < 130 and z > -330 and z < 160
		local nearTown = x > 170 and x < 350 and z > -320 and z < 130
		if not nearTrack and not nearTown then
			cactus(f, x, z)
		end
	end
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-450, 450), rng:NextNumber(-450, 450)
		if math.abs(x) > 120 then
			local s = rng:NextNumber(2, 4)
			block(f, "Bush", Vector3.new(s, s * 0.7, s), CFrame.new(x, s * 0.25, z), Color3.fromRGB(110, 120, 70), Enum.Material.Grass, { Shape = Enum.PartType.Ball })
		end
	end
	-- Large sandstone blocks.
	for _ = 1, 14 do
		local x, z = rng:NextNumber(-400, 400), rng:NextNumber(-400, 400)
		if math.abs(x) > 140 and not (x > 170 and x < 350) then
			local s = rng:NextNumber(5, 10)
			block(f, "Boulder", Vector3.new(s, s * 0.8, s * 1.1), CFrame.new(x, s * 0.3, z) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6), rng:NextNumber(-0.2, 0.2)), Color3.fromRGB(196, 160, 118), Enum.Material.Sandstone)
		end
	end
end

---------------------------------------------------------------------------
-- MAP UPGRADE: props
---------------------------------------------------------------------------
local CollectionService = game:GetService("CollectionService")

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function ellipsoid(parent, name, size, cf, color, material)
	local p = block(parent, name, size, cf, color, material or Enum.Material.SmoothPlastic)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function small(p)
	p.CastShadow = false
	return p
end

local HORSE_COATS = {
	Color3.fromRGB(110, 70, 40), Color3.fromRGB(60, 40, 30), Color3.fromRGB(200, 190, 175),
	Color3.fromRGB(150, 100, 60), Color3.fromRGB(35, 30, 30), Color3.fromRGB(170, 120, 80),
}

-- A standing horse (about 6 studs tall) with saddle and blanket.
local function horse(parent, cf, coat)
	local m = model(parent, "Horse")
	local mane = Color3.fromRGB(40, 28, 20)
	local function at(offset)
		return cf * offset
	end
	ellipsoid(m, "Body", Vector3.new(2.4, 2.4, 5), at(CFrame.new(0, 4, 0)), coat)
	ellipsoid(m, "Chest", Vector3.new(2.2, 2.4, 2.2), at(CFrame.new(0, 4.1, -1.9)), coat)
	block(m, "Neck", Vector3.new(1.1, 2.8, 1.4), at(CFrame.new(0, 5.6, -2.7) * CFrame.Angles(-0.55, 0, 0)), coat)
	ellipsoid(m, "Head", Vector3.new(1.1, 1.2, 2.4), at(CFrame.new(0, 6.6, -3.9) * CFrame.Angles(0.5, 0, 0)), coat)
	ellipsoid(m, "Muzzle", Vector3.new(0.9, 0.8, 0.9), at(CFrame.new(0, 6.0, -4.8)), coat:Lerp(Color3.new(0, 0, 0), 0.25))
	for _, side in ipairs({ -1, 1 }) do
		small(block(m, "Ear", Vector3.new(0.2, 0.5, 0.2), at(CFrame.new(side * 0.3, 7.5, -3.4)), coat))
		small(ellipsoid(m, "Eye", Vector3.new(0.15, 0.2, 0.2), at(CFrame.new(side * 0.52, 6.9, -4.1)), Color3.new(0.05, 0.05, 0.05)))
	end
	small(block(m, "Mane", Vector3.new(0.3, 2.8, 0.5), at(CFrame.new(0, 6.0, -2.4) * CFrame.Angles(-0.55, 0, 0)), mane))
	ellipsoid(m, "Tail", Vector3.new(0.5, 2.6, 0.6), at(CFrame.new(0, 3.6, 2.7) * CFrame.Angles(0.35, 0, 0)), mane)
	for _, x in ipairs({ -0.7, 0.7 }) do
		for _, z in ipairs({ -1.8, 1.8 }) do
			local leg = block(m, "Leg", Vector3.new(0.5, 3.2, 0.55), at(CFrame.new(x, 1.6, z)), coat)
			small(block(m, "Hoof", Vector3.new(0.6, 0.35, 0.65), at(CFrame.new(x, 0.18, z)), Color3.fromRGB(30, 25, 20)))
			leg.CastShadow = true
		end
	end
	block(m, "Saddle", Vector3.new(1.6, 0.4, 1.8), at(CFrame.new(0, 5.3, -0.3)), Color3.fromRGB(90, 50, 25), Enum.Material.Leather)
	block(m, "Blanket", Vector3.new(2.6, 0.15, 2.2), at(CFrame.new(0, 5.15, -0.3)), Color3.fromRGB(170, 40, 40), Enum.Material.Fabric)
	return m
end

local function hayBale(parent, x, z, yaw)
	local p = block(parent, "HayBale", Vector3.new(3, 2.4, 2.4), CFrame.new(x, 1.2, z) * CFrame.Angles(0, yaw or 0, 0), Color3.fromRGB(214, 180, 90), Enum.Material.Grass, { Shape = Enum.PartType.Cylinder })
	return p
end

local function stables(parent, x, z, yaw)
	local m = model(parent, "Stables")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local function at(offset)
		return base * offset
	end
	block(m, "Floor", Vector3.new(30, 0.4, 12), at(CFrame.new(0, 0.2, 0)), C.WoodLight, Enum.Material.WoodPlanks)
	block(m, "BackWall", Vector3.new(30, 9, 0.6), at(CFrame.new(0, 4.5, 6)), C.Wood, Enum.Material.WoodPlanks)
	block(m, "Roof", Vector3.new(32, 0.6, 14), at(CFrame.new(0, 9.4, 0) * CFrame.Angles(0.18, 0, 0)), C.Roof, Enum.Material.WoodPlanks)
	for i = 0, 4 do
		local px = -15 + i * 7.5
		block(m, "Post", Vector3.new(0.6, 9, 0.6), at(CFrame.new(px, 4.5, -6)), C.WoodDark, Enum.Material.Wood)
		block(m, "Divider", Vector3.new(0.4, 4, 10), at(CFrame.new(px, 2.2, 0.5)), C.Wood, Enum.Material.WoodPlanks)
	end
	local sign1 = block(m, "Sign", Vector3.new(10, 2, 0.3), at(CFrame.new(0, 10.4, -6.4)), C.WoodDark, Enum.Material.Wood)
	sign(sign1, Enum.NormalId.Front, "RACE STABLES", Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	for i = 0, 3 do
		horse(m, at(CFrame.new(-11.25 + i * 7.5, 0.4, 0.5) * CFrame.Angles(0, math.pi, 0)), HORSE_COATS[i % #HORSE_COATS + 1])
	end
	local hay = at(CFrame.new(18, 0, -2))
	hayBale(m, hay.X, hay.Z, 0.3)
	return m
end

-- Rope between two points with small hanging pieces (pennants or light bulbs).
local function hangingLine(parent, a, b, count, kind)
	local m = model(parent, kind == "lights" and "StringLights" or "Pennants")
	local sag = (b - a).Magnitude * 0.06
	local function pointAt(t)
		return a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * sag, 0)
	end
	local anchorA = small(block(m, "RopeA", Vector3.new(0.2, 0.2, 0.2), CFrame.new(a), Color3.new(0, 0, 0), nil, { Transparency = 1, CanCollide = false }))
	local anchorB = small(block(m, "RopeB", Vector3.new(0.2, 0.2, 0.2), CFrame.new(b), Color3.new(0, 0, 0), nil, { Transparency = 1, CanCollide = false }))
	-- block() already offsets by origin; the attachments sit at the parts' centres.
	local a0 = Instance.new("Attachment")
	a0.Parent = anchorA
	local a1 = Instance.new("Attachment")
	a1.Parent = anchorB
	local rope = Instance.new("Beam")
	rope.Attachment0 = a0
	rope.Attachment1 = a1
	rope.Width0 = 0.08
	rope.Width1 = 0.08
	rope.Color = ColorSequence.new(Color3.fromRGB(50, 40, 30))
	rope.CurveSize0 = -sag * 1.3
	rope.CurveSize1 = sag * 1.3
	rope.Parent = anchorA
	for i = 1, count do
		local t = i / (count + 1)
		local p = pointAt(t)
		if kind == "lights" then
			local bulb = small(block(m, "Bulb", Vector3.new(0.45, 0.6, 0.45), CFrame.new(p - Vector3.new(0, 0.35, 0)), Color3.fromRGB(255, 215, 140), Enum.Material.Neon, { Shape = Enum.PartType.Ball, CanCollide = false }))
			if i % 3 == 0 then
				local light = Instance.new("PointLight")
				light.Range = 10
				light.Brightness = 0.6
				light.Color = Color3.fromRGB(255, 200, 130)
				light.Parent = bulb
			end
		else
			local palette = FLAG_PALETTES[(i % #FLAG_PALETTES) + 1]
			local dir = (b - a).Unit
			small(block(m, "Pennant", Vector3.new(0.05, 1.2, 1.2), CFrame.lookAt(p, p + dir) * CFrame.new(0, -0.6, 0) * CFrame.Angles(math.pi / 4, 0, 0), palette[1], Enum.Material.Fabric, { CanCollide = false }))
		end
	end
	return m
end

local function palm(parent, x, z)
	local m = model(parent, "PalmTree")
	local lean = rng:NextNumber(-0.25, 0.25)
	local y, px = 0, x
	local segments = 6
	for i = 1, segments do
		local h = 2.6
		cylinder(m, "Trunk", h, 1.3 - i * 0.08, CFrame.new(px, y + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2 + lean), Color3.fromRGB(130, 100, 70), Enum.Material.Wood)
		y = y + h * 0.97
		px = px - math.sin(lean) * h
	end
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		local leaf = small(block(m, "Leaf", Vector3.new(1.2, 0.15, 7), CFrame.new(px, y + 0.4, z) * CFrame.Angles(0, angle, 0) * CFrame.Angles(0.45, 0, 0) * CFrame.new(0, 0, -3.3), Color3.fromRGB(70, 130, 50), Enum.Material.Grass))
		leaf.CastShadow = true
	end
	for i = 1, 3 do
		small(block(m, "Coconut", Vector3.new(0.8, 0.8, 0.8), CFrame.new(px + math.cos(i * 2) * 0.6, y - 0.3, z + math.sin(i * 2) * 0.6), Color3.fromRGB(90, 60, 30), Enum.Material.Wood, { Shape = Enum.PartType.Ball }))
	end
end

local function deadTree(parent, x, z)
	local m = model(parent, "DeadTree")
	local h = rng:NextNumber(6, 11)
	local bark = Color3.fromRGB(95, 75, 60)
	cylinder(m, "Trunk", h, 0.9, upright(x, h / 2, z), bark, Enum.Material.Wood)
	for i = 1, 4 do
		local y = h * rng:NextNumber(0.45, 0.95)
		local yaw = rng:NextNumber(0, math.pi * 2)
		local len = rng:NextNumber(2.5, 4.5)
		small(block(m, "Branch", Vector3.new(0.35, 0.35, len), CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0.7, 0, 0) * CFrame.new(0, 0, -len / 2), bark, Enum.Material.Wood))
	end
end

local function skull(parent, x, z)
	local m = model(parent, "CattleSkull")
	local bone = Color3.fromRGB(235, 228, 210)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local base = CFrame.new(x, 0.4, z) * CFrame.Angles(0, yaw, 0)
	small(block(m, "Skull", Vector3.new(1, 0.7, 1.6), base, bone))
	small(block(m, "HornL", Vector3.new(1.6, 0.25, 0.25), base * CFrame.new(-1, 0.2, -0.3) * CFrame.Angles(0, 0, 0.4), bone))
	small(block(m, "HornR", Vector3.new(1.6, 0.25, 0.25), base * CFrame.new(1, 0.2, -0.3) * CFrame.Angles(0, 0, -0.4), bone))
end

local function waterTower(parent, x, z)
	local m = model(parent, "WaterTower")
	for _, dx in ipairs({ -3, 3 }) do
		for _, dz in ipairs({ -3, 3 }) do
			block(m, "Leg", Vector3.new(0.8, 18, 0.8), CFrame.new(x + dx, 9, z + dz) * CFrame.Angles(dz * 0.015, 0, -dx * 0.015), C.WoodDark, Enum.Material.Wood)
		end
	end
	block(m, "Brace", Vector3.new(8.5, 0.4, 0.4), CFrame.new(x, 8, z - 3), C.WoodDark, Enum.Material.Wood)
	block(m, "Brace", Vector3.new(8.5, 0.4, 0.4), CFrame.new(x, 8, z + 3), C.WoodDark, Enum.Material.Wood)
	cylinder(m, "Tank", 9, 10, upright(x, 22.5, z), C.Wood, Enum.Material.WoodPlanks)
	for _, y in ipairs({ 19.5, 25.5 }) do
		cylinder(m, "Band", 0.4, 10.2, upright(x, y, z), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
	end
	block(m, "Roof", Vector3.new(11, 4, 11), CFrame.new(x, 28.5, z), C.Roof, Enum.Material.WoodPlanks, { Shape = Enum.PartType.Ball })
	small(block(m, "Spout", Vector3.new(0.6, 0.6, 5), CFrame.new(x, 18.5, z - 6) * CFrame.Angles(0.4, 0, 0), Color3.fromRGB(60, 60, 65), Enum.Material.Metal))
end

-- Windmill: the rotor hub is tagged "SpinWindmill"; clients spin it.
local function windmill(parent, x, z)
	local m = model(parent, "Windmill")
	local h = 24
	for _, d in ipairs({ { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } }) do
		block(m, "Leg", Vector3.new(0.5, h, 0.5), CFrame.new(x + d[1] * 0.75, h / 2, z + d[2] * 0.75) * CFrame.Angles(d[2] * 0.06, 0, -d[1] * 0.06), Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
	end
	for y = 4, h - 2, 5 do
		block(m, "Rung", Vector3.new(3.4 - y * 0.06, 0.3, 0.3), CFrame.new(x, y, z - 1.6 + y * 0.03), Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
	end
	local hub = block(m, "Hub", Vector3.new(1.4, 1.4, 1.4), CFrame.new(x, h + 1, z - 1.5), Color3.fromRGB(70, 70, 75), Enum.Material.Metal, { Shape = Enum.PartType.Ball })
	CollectionService:AddTag(hub, "SpinWindmill")
	for i = 1, 12 do
		local blade = block(m, "Blade", Vector3.new(0.9, 4.5, 0.1), CFrame.new(), Color3.fromRGB(200, 195, 185), Enum.Material.Metal)
		-- hub.CFrame is already in world space, so set the blade directly.
		blade.CFrame = hub.CFrame * CFrame.Angles(0, 0, i / 12 * math.pi * 2) * CFrame.new(0, 3, -0.3) * CFrame.Angles(0, 0.35, 0)
		blade.Anchored = false
		blade.CastShadow = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = hub
		w.Part1 = blade
		w.Parent = blade
	end
	local vane = block(m, "Vane", Vector3.new(0.1, 3, 5), CFrame.new(x, h + 1, z + 2), Color3.fromRGB(200, 60, 50), Enum.Material.Metal)
	vane.CastShadow = false
end

local function telegraphLine(parent, points)
	local m = model(parent, "TelegraphLine")
	local tops = {}
	for i, p in ipairs(points) do
		cylinder(m, "Pole", 16, 0.6, upright(p.X, 8, p.Z), C.WoodDark, Enum.Material.Wood)
		local bar = block(m, "Crossbar", Vector3.new(4, 0.4, 0.4), CFrame.new(p.X, 15, p.Z), C.WoodDark, Enum.Material.Wood)
		tops[i] = bar
	end
	for i = 1, #tops - 1 do
		for _, side in ipairs({ -1.6, 1.6 }) do
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(side, 0.3, 0)
			a0.Parent = tops[i]
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(side, 0.3, 0)
			a1.Parent = tops[i + 1]
			local wire = Instance.new("Beam")
			wire.Attachment0 = a0
			wire.Attachment1 = a1
			wire.Width0 = 0.06
			wire.Width1 = 0.06
			wire.Color = ColorSequence.new(Color3.fromRGB(30, 30, 30))
			wire.CurveSize0 = -1.5
			wire.CurveSize1 = 1.5
			wire.Parent = tops[i]
		end
	end
end

local function railway(parent, x, z0, z1)
	local m = model(parent, "Railway")
	local length = z1 - z0
	for _, dx in ipairs({ -2.4, 2.4 }) do
		local segments = math.ceil(length / 200)
		for i = 0, segments - 1 do
			local a = z0 + i * 200
			local b = math.min(z1, a + 200)
			block(m, "Rail", Vector3.new(0.3, 0.4, b - a), CFrame.new(x + dx, 0.6, (a + b) / 2), Color3.fromRGB(80, 75, 70), Enum.Material.Metal)
		end
	end
	for z = z0, z1, 4 do
		small(block(m, "Sleeper", Vector3.new(7, 0.35, 1), CFrame.new(x, 0.25, z), Color3.fromRGB(85, 60, 40), Enum.Material.Wood))
	end
end

local function locomotive(parent, x, z)
	local m = model(parent, "SteamTrain")
	local black = Color3.fromRGB(30, 30, 34)
	local red = Color3.fromRGB(150, 30, 30)
	local function at(dz, y)
		return CFrame.new(x, y, z + dz)
	end
	block(m, "Frame", Vector3.new(6, 1, 26), at(0, 2.2), black, Enum.Material.Metal)
	block(m, "Boiler", Vector3.new(16, 5, 5), at(-4, 5.2) * CFrame.Angles(0, math.pi / 2, 0), black, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	block(m, "SmokeBox", Vector3.new(1, 5.4, 5.4), at(-12.2, 5.2) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(50, 50, 55), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	local stack = cylinder(m, "Smokestack", 4, 1.8, CFrame.new(x, 9.4, z - 10.5) * CFrame.Angles(0, 0, math.pi / 2), black, Enum.Material.Metal)
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(200, 200, 200)
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 6
	smoke.Size = 3
	smoke.Parent = stack
	block(m, "Dome", Vector3.new(2, 2, 2), at(-4, 8), Color3.fromRGB(190, 150, 60), Enum.Material.Metal, { Shape = Enum.PartType.Ball })
	block(m, "Cab", Vector3.new(6, 6, 6), at(7, 6), red, Enum.Material.WoodPlanks)
	block(m, "CabRoof", Vector3.new(7, 0.5, 7), at(7, 9.2), black, Enum.Material.Metal)
	windowRow(m, at(7, 6.5) * CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, -3.05), 1, 0, Vector3.new(2.5, 2, 0.2))
	block(m, "Cowcatcher", Vector3.new(5.5, 2, 3), at(-14, 1.6) * CFrame.Angles(0.5, 0, 0), red, Enum.Material.Metal)
	local lamp = small(block(m, "Headlamp", Vector3.new(1.2, 1.2, 1), at(-12.9, 7), Color3.fromRGB(255, 240, 190), Enum.Material.Neon))
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Range = 40
	light.Brightness = 2
	light.Parent = lamp
	for _, dz in ipairs({ -9, -5, -1, 3 }) do
		for _, dx in ipairs({ -3.1, 3.1 }) do
			local d = dz > -6 and 4 or 2.6
			block(m, "Wheel", Vector3.new(0.5, d, d), at(dz, d / 2 + 0.6) * CFrame.new(dx, 0, 0), red, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
		end
	end
	-- Two passenger coaches.
	for i = 1, 2 do
		local cz = 13 + i * 18
		block(m, "Coach", Vector3.new(6, 6, 16), at(cz, 5), Color3.fromRGB(110, 60, 40), Enum.Material.WoodPlanks)
		block(m, "CoachRoof", Vector3.new(6.6, 0.8, 16.6), at(cz, 8.4), Color3.fromRGB(60, 55, 50), Enum.Material.Metal)
		windowRow(m, at(cz, 5.8) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, -3.05), 5, 3, Vector3.new(1.8, 1.8, 0.2))
		windowRow(m, at(cz, 5.8) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(0, 0, -3.05), 5, 3, Vector3.new(1.8, 1.8, 0.2))
		for _, wz in ipairs({ -5, 5 }) do
			for _, dx in ipairs({ -3.1, 3.1 }) do
				block(m, "Wheel", Vector3.new(0.5, 2.4, 2.4), at(cz + wz, 1.8) * CFrame.new(dx, 0, 0), black, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
			end
		end
	end
end

local function station(parent, x, z)
	local m = model(parent, "TrainStation")
	block(m, "Platform", Vector3.new(10, 1.6, 60), CFrame.new(x, 0.8, z), Color3.fromRGB(150, 130, 105), Enum.Material.WoodPlanks)
	block(m, "Building", Vector3.new(14, 11, 24), CFrame.new(x - 12, 5.5, z), Color3.fromRGB(170, 120, 80), Enum.Material.WoodPlanks)
	block(m, "Roof", Vector3.new(16, 1, 26), CFrame.new(x - 12, 11.5, z) * CFrame.Angles(0, 0, 0.12), C.Roof, Enum.Material.WoodPlanks)
	local board = block(m, "StationSign", Vector3.new(0.4, 3, 16), CFrame.new(x - 4.8, 8.5, z), C.WoodDark, Enum.Material.Wood)
	sign(board, Enum.NormalId.Right, "DESERT JUNCTION", Color3.fromRGB(245, 225, 175), nil, Enum.Font.Fondamento)
	windowRow(m, CFrame.new(x - 4.95, 4.5, z) * CFrame.Angles(0, math.pi / 2, 0), 4, 5, Vector3.new(2.2, 3.2, 0.2))
	block(m, "Canopy", Vector3.new(10, 0.5, 50), CFrame.new(x, 10, z) * CFrame.Angles(0, 0, -0.08), Color3.fromRGB(120, 40, 40), Enum.Material.WoodPlanks)
	for dz = -22, 22, 11 do
		block(m, "CanopyPost", Vector3.new(0.5, 8.6, 0.5), CFrame.new(x + 4, 5.9, z + dz), C.WoodDark, Enum.Material.Wood)
		small(block(m, "Bench", Vector3.new(1.4, 0.4, 5), CFrame.new(x - 3, 2.4, z + dz + 5), C.WoodLight, Enum.Material.WoodPlanks))
	end
	small(block(m, "Clock", Vector3.new(0.3, 2.4, 2.4), CFrame.new(x - 4.7, 12.5, z), Color3.fromRGB(240, 235, 220), nil, { Shape = Enum.PartType.Cylinder }))
end

local function mine(parent, center)
	local m = model(parent, "OldMine")
	local dir = Vector3.new(-center.X, 0, -center.Z).Unit
	local entrance = center + dir * 58
	-- Faces back into the hill: the tunnel opening is on the local +Z side.
	local base = CFrame.lookAt(Vector3.new(entrance.X, 0, entrance.Z), Vector3.new(entrance.X, 0, entrance.Z) + dir)
	local function at(offset)
		return base * offset
	end
	block(m, "TunnelDark", Vector3.new(10, 10, 6), at(CFrame.new(0, 5, 3)), Color3.fromRGB(10, 8, 6), Enum.Material.SmoothPlastic)
	for _, x in ipairs({ -5.5, 5.5 }) do
		block(m, "Timber", Vector3.new(1.2, 12, 1.2), at(CFrame.new(x, 6, 0)), C.WoodDark, Enum.Material.Wood)
	end
	block(m, "Lintel", Vector3.new(13, 1.4, 1.4), at(CFrame.new(0, 12, 0)), C.WoodDark, Enum.Material.Wood)
	local board = block(m, "MineSign", Vector3.new(8, 2, 0.3), at(CFrame.new(0, 14, -0.4)), C.Wood, Enum.Material.Wood)
	sign(board, Enum.NormalId.Front, "SILVER MINE · KEEP OUT", Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	for _, x in ipairs({ -1.6, 1.6 }) do
		block(m, "MineRail", Vector3.new(0.3, 0.3, 26), at(CFrame.new(x, 0.4, -10)), Color3.fromRGB(80, 75, 70), Enum.Material.Metal)
	end
	for zz = 0, 22, 3 do
		small(block(m, "Sleeper", Vector3.new(4.6, 0.3, 0.8), at(CFrame.new(0, 0.2, -zz)), Color3.fromRGB(85, 60, 40), Enum.Material.Wood))
	end
	block(m, "OreCart", Vector3.new(3.6, 2.4, 4.4), at(CFrame.new(0, 2.1, -9)), Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
	for i = 1, 5 do
		small(block(m, "Ore", Vector3.new(1.1, 1.1, 1.1), at(CFrame.new(rng:NextNumber(-1, 1), 3.4, -9 + rng:NextNumber(-1.4, 1.4))), Color3.fromRGB(160, 165, 175), Enum.Material.Slate, { Shape = Enum.PartType.Ball }))
	end
	for _, x in ipairs({ -5.5, 5.5 }) do
		local lantern = small(block(m, "Lantern", Vector3.new(0.7, 1, 0.7), at(CFrame.new(x, 9, -0.9)), Color3.fromRGB(255, 190, 100), Enum.Material.Neon))
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 180, 90)
		light.Range = 14
		light.Brightness = 1.2
		light.Parent = lantern
	end
end

local function rockArch(parent, x, z)
	local m = model(parent, "RockArch")
	local stone = Color3.fromRGB(190, 120, 80)
	block(m, "PillarL", Vector3.new(8, 26, 9), CFrame.new(x - 14, 13, z) * CFrame.Angles(0, 0, 0.08), stone, Enum.Material.Sandstone)
	block(m, "PillarR", Vector3.new(8, 24, 9), CFrame.new(x + 14, 12, z) * CFrame.Angles(0, 0, -0.08), stone, Enum.Material.Sandstone)
	block(m, "Span", Vector3.new(38, 7, 8), CFrame.new(x, 27, z) * CFrame.Angles(0, 0, 0.03), stone, Enum.Material.Sandstone)
end

local function well(parent, x, z)
	local m = model(parent, "Well")
	cylinder(m, "WellRing", 3, 5, upright(x, 1.5, z), Color3.fromRGB(150, 140, 125), Enum.Material.Cobblestone)
	cylinder(m, "WellWater", 0.2, 4.2, upright(x, 2.5, z), Color3.fromRGB(60, 100, 120), Enum.Material.Glass)
	for _, dx in ipairs({ -2.2, 2.2 }) do
		block(m, "Post", Vector3.new(0.5, 6, 0.5), CFrame.new(x + dx, 4, z), C.WoodDark, Enum.Material.Wood)
	end
	block(m, "Roof", Vector3.new(6, 0.5, 4), CFrame.new(x, 7.2, z), C.Roof, Enum.Material.WoodPlanks)
	small(block(m, "Bucket", Vector3.new(0.9, 0.9, 0.9), CFrame.new(x, 4.5, z), C.Wood, Enum.Material.Wood))
end

local function wantedBoard(parent, x, z, yaw)
	local m = model(parent, "WantedBoard")
	local board = block(m, "Board", Vector3.new(6, 4, 0.3), CFrame.new(x, 4, z) * CFrame.Angles(0, yaw, 0), C.Wood, Enum.Material.WoodPlanks)
	for _, dx in ipairs({ -2.6, 2.6 }) do
		block(m, "Leg", Vector3.new(0.4, 6, 0.4), CFrame.new(x, 3, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(dx, 0, 0.3), C.WoodDark, Enum.Material.Wood)
	end
	for i, text in ipairs({ "WANTED\nGYRO", "WANTED\nDIO", "REWARD\n$5000" }) do
		local poster = small(block(m, "Poster", Vector3.new(1.6, 2.2, 0.05), CFrame.new(x, 4.1, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(-2 + (i - 1) * 2, 0, -0.18), Color3.fromRGB(230, 210, 170), Enum.Material.Fabric))
		sign(poster, Enum.NormalId.Front, text, Color3.fromRGB(60, 30, 15), nil, Enum.Font.Fondamento)
	end
end

local function boardwalk(parent, x, z0, z1)
	block(parent, "Boardwalk", Vector3.new(5, 0.6, math.abs(z1 - z0)), CFrame.new(x, 0.3, (z0 + z1) / 2), C.WoodLight, Enum.Material.WoodPlanks)
end

local function scoreboard(parent, x, z, yaw)
	local m = model(parent, "Scoreboard")
	local board = block(m, "Board", Vector3.new(20, 10, 0.6), CFrame.new(x, 12, z) * CFrame.Angles(0, yaw, 0), Color3.fromRGB(30, 40, 30), Enum.Material.WoodPlanks)
	sign(board, Enum.NormalId.Front, "STAGE 1 — SAN DIEGO BEACH\n1. ???   2. ???   3. ???\n6,000 KM TO NEW YORK", Color3.fromRGB(240, 235, 200), nil, Enum.Font.Fondamento)
	for _, dx in ipairs({ -8, 8 }) do
		block(m, "Leg", Vector3.new(0.8, 12, 0.8), CFrame.new(x, 6, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(dx, 0, 0.6), C.WoodDark, Enum.Material.Wood)
	end
	block(m, "Trim", Vector3.new(21, 1, 1), CFrame.new(x, 17.4, z) * CFrame.Angles(0, yaw, 0), C.Gold, Enum.Material.Metal)
end

---------------------------------------------------------------------------
-- MAP UPGRADE: sections
---------------------------------------------------------------------------
local function buildLandforms()
	local terrain = workspace.Terrain
	local o = origin
	-- Rolling dunes in the open desert.
	for _ = 1, 45 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(230, 470)
		local p = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local inTown = p.X > 170 and p.X < 470 and p.Z > -340 and p.Z < 140
		if not inTown then
			local r = rng:NextNumber(18, 45)
			terrain:FillBall(o + p - Vector3.new(0, r * 0.78, 0), r, Enum.Material.Sand)
		end
	end
	-- Layered mesas (stratified sandstone and rock).
	local mesas = { Vector3.new(-380, 0, 60), Vector3.new(-300, 0, -250), Vector3.new(120, 0, -430), Vector3.new(-120, 0, 400), Vector3.new(330, 0, 380), Vector3.new(-430, 0, 300) }
	for i, p in ipairs(mesas) do
		local radius = 30 + (i % 3) * 10
		local height = 0
		local layers = { Enum.Material.Sandstone, Enum.Material.Rock, Enum.Material.Sandstone, Enum.Material.Slate }
		for l = 1, 4 do
			local h = rng:NextNumber(10, 16)
			local r = radius * (1 - (l - 1) * 0.12)
			terrain:FillCylinder(CFrame.new(o + p + Vector3.new(0, height + h / 2, 0)), h, r, layers[l])
			height = height + h
		end
	end
	-- Oasis: pond, grass ring, palms.
	local oasis = Vector3.new(-280, 0, 200)
	terrain:FillCylinder(CFrame.new(o + oasis + Vector3.new(0, -0.5, 0)), 2, 34, Enum.Material.Grass)
	terrain:FillCylinder(CFrame.new(o + oasis + Vector3.new(0, -2, 0)), 4, 20, Enum.Material.Water)
	-- Mine hill.
	terrain:FillBall(o + Vector3.new(-360, -30, -380), 70, Enum.Material.Rock)
	-- Roads (hard-packed ground).
	terrain:FillBlock(CFrame.new(o + Vector3.new(350, -0.6, 0)), Vector3.new(180, 1.2, 16), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(o + Vector3.new(-140, -0.6, 150)), Vector3.new(280, 1.2, 14), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(o + Vector3.new(-170, -0.6, -340)) * CFrame.Angles(0, 0.75, 0), Vector3.new(14, 1.2, 240), Enum.Material.Ground)
	return oasis
end

local function buildUpgrades()
	local f = folder("Upgrades")
	local oasis = buildLandforms()

	-- Race grounds: stables, horses, pennants, lights, scoreboard, hay.
	stables(f, -80, 125, -math.pi / 2)
	for i = 0, 3 do
		horse(f, CFrame.new(26 + (i % 2) * 4, 0, 130 - i * 6) * CFrame.Angles(0, math.pi / 2 + rng:NextNumber(-0.3, 0.3), 0), HORSE_COATS[(i + 2) % #HORSE_COATS + 1])
	end
	for i = 0, 10 do
		local z = 120 - i * 32
		hangingLine(f, Vector3.new(-22, 14.5, z), Vector3.new(-22, 14.5, z - 32), 7, "pennants")
		hangingLine(f, Vector3.new(22, 13.5, z - 16), Vector3.new(22, 13.5, z - 48), 8, "lights")
	end
	hangingLine(f, Vector3.new(-16, 21, 110), Vector3.new(16, 21, 110), 10, "lights")
	scoreboard(f, 44, 118, -math.pi / 2)
	for i = 1, 10 do
		hayBale(f, rng:NextNumber(-18, -12) * (i % 2 == 0 and 1 or -1), 100 - i * 30, rng:NextNumber(0, 3))
	end

	-- Town extras: boardwalks, well, wanted board, water tower, windmill.
	boardwalk(f, 260 - 14.5, -110, 60)
	boardwalk(f, 260 + 14.5, -110, 60)
	well(f, 260, -70)
	wantedBoard(f, 248, 80, math.pi / 2)
	waterTower(f, 300, 70)
	windmill(f, 315, 115)

	-- Railway, station and steam train.
	railway(f, 440, -600, 600)
	station(f, 432, 0)
	locomotive(f, 440, -20)
	waterTower(f, 420, 50)

	-- Telegraph line: race start -> town -> station.
	local poles = {}
	for x = 30, 250, 40 do
		table.insert(poles, Vector3.new(x, 0, 92))
	end
	for x = 290, 410, 40 do
		table.insert(poles, Vector3.new(x, 0, -10))
	end
	telegraphLine(f, poles)

	-- Oasis palms, mine, rock arch, desert details.
	for i = 1, 9 do
		local angle = i / 9 * math.pi * 2
		palm(f, oasis.X + math.cos(angle) * rng:NextNumber(23, 30), oasis.Z + math.sin(angle) * rng:NextNumber(23, 30))
	end
	mine(f, Vector3.new(-360, 0, -380))
	rockArch(f, -150, -440)
	for _ = 1, 22 do
		local x, z = rng:NextNumber(-460, 460), rng:NextNumber(-460, 460)
		if math.abs(x) > 140 and not (x > 170 and x < 470) then
			if rng:NextNumber() < 0.5 then
				deadTree(f, x, z)
			else
				skull(f, x, z)
			end
		end
	end
	-- Wrecked wagon out in the desert.
	wagon(f, -200, -120, 0.7)
end

---------------------------------------------------------------------------
-- NEW PLACES: river + waterfall, covered bridge, railway trestle,
-- gold-panning camp, ghost town, horse ranch, Fort Dust, signposts
---------------------------------------------------------------------------
local RIVER_Z = 290
local function riverZ(x)
	return RIVER_Z + math.sin(x / 90) * 18
end

-- Clear dunes/rocks above ground level so a place sits on flat sand.
local function flatten(x, z, radius)
	local terrain = workspace.Terrain
	terrain:FillCylinder(CFrame.new(origin + Vector3.new(x, 20, z)), 40, radius, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(origin + Vector3.new(x, -0.5, z)), 1, radius, Enum.Material.Sand)
end

local function road(x, z, sizeX, sizeZ, yaw)
	workspace.Terrain:FillBlock(CFrame.new(origin + Vector3.new(x, -0.6, z)) * CFrame.Angles(0, yaw or 0, 0), Vector3.new(sizeX, 1.2, sizeZ), Enum.Material.Ground)
end

local function placeSign(parent, text, x, z, yaw)
	local m = model(parent, "PlaceSign")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw or 0, 0)
	for _, dx in ipairs({ -4.5, 4.5 }) do
		block(m, "Post", Vector3.new(0.7, 9, 0.7), base * CFrame.new(dx, 4.5, 0), C.WoodDark, Enum.Material.Wood)
	end
	local board = block(m, "Board", Vector3.new(11, 3.2, 0.4), base * CFrame.new(0, 7, 0), C.Wood, Enum.Material.WoodPlanks)
	sign(board, Enum.NormalId.Front, text, Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	sign(board, Enum.NormalId.Back, text, Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	return m
end

local function lanternPost(parent, x, z, y)
	y = y or 0
	block(parent, "LanternPost", Vector3.new(0.5, 7, 0.5), CFrame.new(x, y + 3.5, z), C.WoodDark, Enum.Material.Wood)
	local lantern = small(block(parent, "Lantern", Vector3.new(0.8, 1.1, 0.8), CFrame.new(x, y + 7.4, z), Color3.fromRGB(255, 190, 100), Enum.Material.Neon))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 90)
	light.Range = 16
	light.Brightness = 1
	light.Parent = lantern
end

local function barrel(parent, x, z, y)
	return cylinder(parent, "Barrel", 2.6, 2, upright(x, (y or 0) + 1.3, z), C.Wood, Enum.Material.Wood)
end

local function crate(parent, x, z, y, s)
	s = s or 2.4
	return block(parent, "Crate", Vector3.new(s, s, s), CFrame.new(x, (y or 0) + s / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), C.WoodLight, Enum.Material.WoodPlanks)
end

-- A black-and-white cow.
local function cow(parent, cf)
	local m = model(parent, "Cow")
	local white, black = Color3.fromRGB(235, 232, 225), Color3.fromRGB(35, 32, 30)
	local function at(o)
		return cf * o
	end
	ellipsoid(m, "Body", Vector3.new(2.8, 2.6, 5), at(CFrame.new(0, 3.4, 0)), white)
	for i = 1, 3 do
		small(ellipsoid(m, "Spot", Vector3.new(1.4, 1.2, 1.6), at(CFrame.new((i % 2 == 0 and 1 or -1) * 0.9, 3.7 + (i - 2) * 0.2, (i - 2) * 1.4)), black))
	end
	ellipsoid(m, "Head", Vector3.new(1.3, 1.4, 2), at(CFrame.new(0, 4.2, -3.1) * CFrame.Angles(0.3, 0, 0)), black)
	ellipsoid(m, "Muzzle", Vector3.new(1.1, 0.8, 0.8), at(CFrame.new(0, 3.7, -3.9)), Color3.fromRGB(220, 170, 160))
	for _, side in ipairs({ -1, 1 }) do
		small(block(m, "Horn", Vector3.new(0.6, 0.18, 0.18), at(CFrame.new(side * 0.8, 5, -2.9) * CFrame.Angles(0, 0, side * 0.4)), Color3.fromRGB(230, 220, 190)))
	end
	for _, x in ipairs({ -0.8, 0.8 }) do
		for _, z in ipairs({ -1.6, 1.6 }) do
			block(m, "Leg", Vector3.new(0.55, 2.2, 0.55), at(CFrame.new(x, 1.1, z)), white)
		end
	end
	small(block(m, "Tail", Vector3.new(0.2, 2, 0.2), at(CFrame.new(0, 3, 2.6) * CFrame.Angles(0.2, 0, 0)), black))
	return m
end

-- Round fence (corral).
local function corral(parent, cx, cz, radius, gapAngle)
	local posts = math.floor(radius * 2 * math.pi / 7)
	for i = 0, posts - 1 do
		local a0 = i / posts * math.pi * 2
		local a1 = (i + 1) / posts * math.pi * 2
		local skip = gapAngle and math.abs(((a0 - gapAngle + math.pi) % (2 * math.pi)) - math.pi) < 0.25
		local p0 = Vector3.new(cx + math.cos(a0) * radius, 0, cz + math.sin(a0) * radius)
		local p1 = Vector3.new(cx + math.cos(a1) * radius, 0, cz + math.sin(a1) * radius)
		block(parent, "CorralPost", Vector3.new(0.6, 4, 0.6), CFrame.new(p0.X, 2, p0.Z), C.WoodDark, Enum.Material.Wood)
		if not skip then
			local mid = (p0 + p1) / 2
			for _, y in ipairs({ 1.5, 3.1 }) do
				block(parent, "CorralRail", Vector3.new(0.3, 0.35, (p1 - p0).Magnitude + 0.4), CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(p1.X, y, p1.Z)), C.WoodLight, Enum.Material.Wood)
			end
		end
	end
end

local function buildRiver(f)
	local terrain = workspace.Terrain
	local o = origin
	-- Carve the riverbed, then fill it with water, from the mesa waterfall to the mountains.
	for x = -380, 560, 12 do
		local z = riverZ(x)
		terrain:FillBlock(CFrame.new(o + Vector3.new(x, 6, z)), Vector3.new(16, 26, 30), Enum.Material.Air)
		terrain:FillBlock(CFrame.new(o + Vector3.new(x, -9, z)), Vector3.new(16, 4, 30), Enum.Material.Mud)
		terrain:FillBlock(CFrame.new(o + Vector3.new(x, -5, z)), Vector3.new(16, 4, 26), Enum.Material.Water)
		-- Muddy banks with reeds of grass.
		for _, side in ipairs({ -1, 1 }) do
			terrain:FillBlock(CFrame.new(o + Vector3.new(x, -0.6, z + side * 17)), Vector3.new(14, 1.2, 4), Enum.Material.Mud)
			if rng:NextNumber() < 0.35 then
				terrain:FillCylinder(CFrame.new(o + Vector3.new(x + rng:NextNumber(-5, 5), -0.5, z + side * rng:NextNumber(19, 24))), 1, rng:NextNumber(3, 6), Enum.Material.Grass)
			end
		end
	end
	-- Waterfall pouring off the mesa into the river.
	local wz = riverZ(-380)
	-- Rock cliff on the mesa's edge for the water to pour down.
	terrain:FillBlock(CFrame.new(o + Vector3.new(-412, 23, wz)), Vector3.new(24, 48, 30), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(o + Vector3.new(-412, 47.5, wz)), Vector3.new(24, 1, 10), Enum.Material.Water)
	local fall = model(f, "Waterfall")
	block(fall, "Fall", Vector3.new(2, 50, 10), CFrame.new(-399, 23, wz), Color3.fromRGB(110, 175, 210), Enum.Material.Glass, { Transparency = 0.25, CanCollide = false })
	block(fall, "FallFoam", Vector3.new(1, 50, 6), CFrame.new(-397.6, 23, wz), Color3.fromRGB(230, 245, 255), Enum.Material.SmoothPlastic, { Transparency = 0.45, CanCollide = false })
	local pool = block(fall, "Mist", Vector3.new(10, 3, 18), CFrame.new(-388, -2, wz), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false })
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	mist.Lifetime = NumberRange.new(1.5, 2.5)
	mist.Speed = NumberRange.new(2, 5)
	mist.Rate = 12
	mist.Parent = pool
	terrain:FillBall(o + Vector3.new(-388, -6, wz), 12, Enum.Material.Water)
	placeSign(f, "RATTLESNAKE RIVER", -350, wz - 26, 0)
end

local function coveredBridge(f, x)
	local m = model(f, "CoveredBridge")
	local z = riverZ(x)
	local length, width = 48, 12
	local red = Color3.fromRGB(150, 50, 40)
	block(m, "Deck", Vector3.new(width, 1, length), CFrame.new(x, 0.9, z), C.WoodLight, Enum.Material.WoodPlanks)
	for _, side in ipairs({ -1, 1 }) do
		-- Side walls with a window strip.
		block(m, "WallLow", Vector3.new(0.6, 3.5, length), CFrame.new(x + side * width / 2, 3.15, z), red, Enum.Material.WoodPlanks)
		block(m, "WallHigh", Vector3.new(0.6, 2.5, length), CFrame.new(x + side * width / 2, 8.3, z), red, Enum.Material.WoodPlanks)
		for zz = -length / 2, length / 2, 6 do
			block(m, "WallPost", Vector3.new(0.7, 9.6, 0.7), CFrame.new(x + side * width / 2, 5.6, z + zz), C.WoodDark, Enum.Material.Wood)
		end
		-- Gable roof.
		block(m, "Roof", Vector3.new(width * 0.62, 0.6, length + 2), CFrame.new(x + side * width * 0.26, 11.6, z) * CFrame.Angles(0, 0, side * -0.5), C.Roof, Enum.Material.WoodPlanks)
		-- Stone piers in the river.
		block(m, "Pier", Vector3.new(4, 10, 4), CFrame.new(x + side * 4, -4.5, z), Color3.fromRGB(140, 130, 120), Enum.Material.Cobblestone)
	end
	for _, end_ in ipairs({ -1, 1 }) do
		local gable = block(m, "Gable", Vector3.new(width, 2.4, 0.5), CFrame.new(x, 10.8, z + end_ * length / 2), red, Enum.Material.WoodPlanks)
		if end_ == -1 then
			sign(gable, Enum.NormalId.Front, "RIVER CROSSING", Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
		end
		-- Ramps down to the road.
		block(m, "Ramp", Vector3.new(width, 0.8, 8), CFrame.new(x, 0.45, z + end_ * (length / 2 + 3.6)) * CFrame.Angles(end_ * 0.12, 0, 0), C.WoodLight, Enum.Material.WoodPlanks)
	end
	lanternPost(m, x - width / 2 - 1.5, z - length / 2 - 2)
	lanternPost(m, x + width / 2 + 1.5, z + length / 2 + 2)
end

local function railwayTrestle(f, x)
	local m = model(f, "RailwayTrestle")
	local z = riverZ(x)
	block(m, "TrestleDeck", Vector3.new(8, 0.6, 36), CFrame.new(x, -0.3, z), C.WoodDark, Enum.Material.WoodPlanks)
	for zz = -15, 15, 6 do
		for _, dx in ipairs({ -3, 3 }) do
			block(m, "TrestleLeg", Vector3.new(0.8, 10, 0.8), CFrame.new(x + dx, -5, z + zz) * CFrame.Angles(0, 0, dx > 0 and -0.12 or 0.12), C.WoodDark, Enum.Material.Wood)
		end
		block(m, "Brace", Vector3.new(0.4, 0.4, 8.6), CFrame.new(x, -4.5, z + zz) * CFrame.Angles(0, math.pi / 2, 0.8), C.Wood, Enum.Material.Wood)
		block(m, "Brace", Vector3.new(0.4, 0.4, 8.6), CFrame.new(x, -4.5, z + zz) * CFrame.Angles(0, math.pi / 2, -0.8), C.Wood, Enum.Material.Wood)
	end
end

local function goldCamp(f, x)
	local m = model(f, "GoldPanningCamp")
	local z = riverZ(x) - 26 -- south bank
	tent(m, x - 12, z - 8, 0.3, 0.9)
	tent(m, x + 10, z - 10, -0.4, 1)
	-- Sluice box running down into the river.
	block(m, "Sluice", Vector3.new(2.4, 1, 18), CFrame.new(x, 1.6, z + 10) * CFrame.Angles(-0.14, 0, 0), C.Wood, Enum.Material.WoodPlanks)
	for _, dx in ipairs({ -1.3, 1.3 }) do
		block(m, "SluiceSide", Vector3.new(0.3, 1.4, 18), CFrame.new(x + dx, 2.1, z + 10) * CFrame.Angles(-0.14, 0, 0), C.WoodDark, Enum.Material.Wood)
	end
	block(m, "SluiceWater", Vector3.new(2, 0.2, 17), CFrame.new(x, 2.15, z + 10) * CFrame.Angles(-0.14, 0, 0), Color3.fromRGB(100, 160, 190), Enum.Material.Glass, { Transparency = 0.3, CanCollide = false })
	for i = 1, 3 do
		small(cylinder(m, "GoldPan", 0.25, 2, CFrame.new(x - 5 + i * 2.2, 0.2, z + 4) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(120, 110, 100), Enum.Material.Metal))
	end
	for i = 1, 6 do
		small(block(m, "Nugget", Vector3.new(0.5, 0.4, 0.5), CFrame.new(x - 6 + rng:NextNumber(0, 6), 0.3, z + 3.5 + rng:NextNumber(-0.5, 0.5)), C.Gold, Enum.Material.Metal, { Shape = Enum.PartType.Ball }))
	end
	block(m, "Campfire", Vector3.new(2.4, 0.4, 2.4), CFrame.new(x - 1, 0.2, z - 14), Color3.fromRGB(60, 40, 30), Enum.Material.Slate)
	local fire = small(block(m, "Fire", Vector3.new(1, 1, 1), CFrame.new(x - 1, 0.9, z - 14), Color3.fromRGB(255, 140, 40), Enum.Material.Neon, { Transparency = 0.3, CanCollide = false }))
	local flame = Instance.new("Fire")
	flame.Size = 4
	flame.Heat = 6
	flame.Parent = fire
	barrel(m, x + 4, z - 16)
	crate(m, x + 6.5, z - 15)
	placeSign(m, "GOLD CLAIM · NO JUMPERS", x - 22, z, math.pi / 2)
end

-- A ruined, weathered building for the ghost town.
local function ruin(parent, name, cf, width, depth, height, lean)
	local m = model(parent, name:gsub(" ", ""))
	local grey = Color3.fromRGB(128 + rng:NextInteger(-12, 12), 116, 100)
	local function at(o)
		return cf * o
	end
	-- Walls (one missing side wall, broken back wall).
	block(m, "BackWall", Vector3.new(width, height * 0.7, 1), at(CFrame.new(0, height * 0.35, depth)), grey, Enum.Material.WoodPlanks)
	block(m, "SideWall", Vector3.new(1, height, depth), at(CFrame.new(-width / 2, height / 2, depth / 2)), grey, Enum.Material.WoodPlanks)
	block(m, "SideWallStub", Vector3.new(1, height * 0.4, depth * 0.5), at(CFrame.new(width / 2, height * 0.2, depth * 0.75)), grey, Enum.Material.WoodPlanks)
	-- Leaning false front with a faded sign.
	local front = block(m, "FalseFront", Vector3.new(width + 1, height + 5, 1), at(CFrame.new(0, (height + 5) / 2, -0.5) * CFrame.Angles(lean or 0.06, 0, (lean or 0.06) * 0.5)), grey, Enum.Material.WoodPlanks)
	local board = block(m, "SignBoard", Vector3.new(width - 2, 3, 0.3), at(CFrame.new(0.4, height + 1.8, -1.2) * CFrame.Angles(lean or 0.06, 0, 0.12)), Color3.fromRGB(90, 76, 62), Enum.Material.Wood)
	sign(board, Enum.NormalId.Front, name, Color3.fromRGB(200, 185, 160), nil, Enum.Font.Fondamento)
	-- Boarded-up door and windows.
	block(m, "Doorway", Vector3.new(3.2, 6.5, 0.3), at(CFrame.new(0, 3.25, -1.1)), Color3.fromRGB(20, 16, 14), Enum.Material.SmoothPlastic)
	for i = -1, 1 do
		block(m, "Board", Vector3.new(4, 0.5, 0.2), at(CFrame.new(0, 3 + i * 1.6, -1.3) * CFrame.Angles(0, 0, i * 0.2)), Color3.fromRGB(110, 92, 70), Enum.Material.Wood)
	end
	-- Collapsed roof: a few planks resting at angles, the rest on the floor.
	for i = 1, 4 do
		block(m, "RoofPlank", Vector3.new(width * 0.5, 0.4, 2), at(CFrame.new(rng:NextNumber(-width / 4, width / 4), height - i * 0.8, depth * i / 5) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.6, 0.6))), C.WoodDark, Enum.Material.WoodPlanks)
	end
	for _ = 1, 3 do
		block(m, "Rubble", Vector3.new(rng:NextNumber(1, 3), 0.5, rng:NextNumber(2, 5)), at(CFrame.new(rng:NextNumber(-width / 3, width / 3), 0.25, depth * rng:NextNumber(0.2, 0.8)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0)), grey, Enum.Material.WoodPlanks)
	end
	return m
end

local function ghostTown(f, cx, cz)
	local m = model(f, "GhostTown")
	local names = { "SALOON", "ASSAY OFFICE", "DRY GOODS", "UNDERTAKER", "HOTEL" }
	for i, name in ipairs(names) do
		local side = (i % 2 == 1) and -1 or 1
		local z = cz + 40 - (i - 1) * 20
		local cf = CFrame.new(cx + side * 20, 0, z) * CFrame.Angles(0, side * math.pi / 2, 0)
		ruin(m, name, cf, 16, 18, 13, rng:NextNumber(0.03, 0.12) * (i % 2 == 0 and -1 or 1))
	end
	-- Broken water tower lying on its side.
	cylinder(m, "FallenTank", 10, 8, CFrame.new(cx + 6, 3.5, cz - 52) * CFrame.Angles(0, 0.6, 0.15), C.WoodDark, Enum.Material.WoodPlanks)
	-- Graveyard with crosses.
	local gx, gz = cx - 52, cz - 30
	for i = 0, 8 do
		local x = gx + (i % 3) * 6 + rng:NextNumber(-1, 1)
		local z = gz + math.floor(i / 3) * 7
		local tilt = rng:NextNumber(-0.25, 0.25)
		block(m, "CrossPost", Vector3.new(0.5, 4, 0.5), CFrame.new(x, 1.8, z) * CFrame.Angles(0, 0, tilt), C.WoodDark, Enum.Material.Wood)
		block(m, "CrossBar", Vector3.new(2.2, 0.45, 0.5), CFrame.new(x, 2.8, z) * CFrame.Angles(0, 0, tilt), C.WoodDark, Enum.Material.Wood)
		block(m, "Mound", Vector3.new(2.4, 0.6, 4), CFrame.new(x, 0.2, z + 2.4), Color3.fromRGB(150, 120, 90), Enum.Material.Ground)
	end
	fenceLine(m, gx - 4, gz - 4, gz + 22)
	-- Abandoned wagon and barrels in the street.
	wagon(m, cx - 4, cz + 8, 2.6)
	barrel(m, cx + 8, cz - 10)
	barrel(m, cx + 9.5, cz - 12)
	placeSign(m, "DUSTWATER · POP. 0", cx, cz + 64, 0)
end

local function ranch(f, cx, cz)
	local m = model(f, "HorseRanch")
	local red = Color3.fromRGB(160, 46, 38)
	-- Barn with a two-slope (gambrel) roof and big doors.
	local bx, bz = cx + 34, cz + 8
	block(m, "BarnBody", Vector3.new(26, 16, 32), CFrame.new(bx, 8, bz), red, Enum.Material.WoodPlanks)
	for _, side in ipairs({ -1, 1 }) do
		block(m, "BarnRoofLow", Vector3.new(9, 0.8, 34), CFrame.new(bx + side * 10.5, 18.5, bz) * CFrame.Angles(0, 0, side * -1), C.Roof, Enum.Material.WoodPlanks)
		block(m, "BarnRoofHigh", Vector3.new(9, 0.8, 34), CFrame.new(bx + side * 4.4, 23.4, bz) * CFrame.Angles(0, 0, side * -0.35), C.Roof, Enum.Material.WoodPlanks)
	end
	block(m, "BarnDoor", Vector3.new(10, 11, 0.4), CFrame.new(bx, 5.5, bz - 16.1), C.WoodDark, Enum.Material.WoodPlanks)
	for _, ang in ipairs({ 0.75, -0.75 }) do
		block(m, "DoorX", Vector3.new(0.6, 14, 0.2), CFrame.new(bx, 5.5, bz - 16.4) * CFrame.Angles(0, 0, ang), C.White, Enum.Material.Wood)
	end
	local loft = block(m, "LoftSign", Vector3.new(12, 2.6, 0.3), CFrame.new(bx, 14, bz - 16.2), C.White, Enum.Material.Wood)
	sign(loft, Enum.NormalId.Front, "LUCKY HORSESHOE RANCH", red, nil, Enum.Font.Fondamento)
	for i = 1, 6 do
		hayBale(m, bx - 18 + (i % 3) * 3.2, bz - 6 + math.floor(i / 4) * 2.6, math.pi / 2)
	end
	-- Ranch house with a porch.
	westernBuilding(m, "RANCH HOUSE", CFrame.new(cx - 30, 0, cz - 4), 18, 16, 10, C.WoodLight)
	-- Corral with horses.
	local kx, kz = cx, cz + 34
	corral(m, kx, kz, 16, -math.pi / 2)
	for i = 1, 3 do
		horse(m, CFrame.new(kx + rng:NextNumber(-8, 8), 0, kz + rng:NextNumber(-6, 8)) * CFrame.Angles(0, rng:NextNumber(0, 6.2), 0), HORSE_COATS[i])
	end
	block(m, "Trough", Vector3.new(2.4, 1.6, 7), CFrame.new(kx + 11, 0.8, kz), C.Wood, Enum.Material.WoodPlanks)
	block(m, "TroughWater", Vector3.new(2, 0.2, 6.6), CFrame.new(kx + 11, 1.55, kz), Color3.fromRGB(80, 130, 160), Enum.Material.Glass, { Transparency = 0.2 })
	-- Cows grazing beside the barn.
	for i = 1, 4 do
		cow(m, CFrame.new(bx + 22 + rng:NextNumber(-4, 6), 0, bz - 12 + i * 8) * CFrame.Angles(0, rng:NextNumber(0, 6.2), 0))
	end
	fenceLine(m, bx + 32, bz - 20, bz + 30)
	windmill(m, cx - 10, cz + 4)
	placeSign(m, "LUCKY HORSESHOE RANCH", cx - 8, cz - 40, 0)
end

local function fort(f, cx, cz)
	local m = model(f, "FortDust")
	local half = 30
	local log = Color3.fromRGB(110, 78, 50)
	-- Palisade walls of sharpened logs; the gate opens north toward the church.
	for _, wall in ipairs({ { 0, -half, "X" }, { 0, half, "X" }, { -half, 0, "Z" }, { half, 0, "Z" } }) do
		for t = -half, half, 2.2 do
			local x = wall[3] == "X" and cx + t or cx + wall[1]
			local z = wall[3] == "X" and cz + wall[2] or cz + t
			local isGate = wall[3] == "X" and wall[2] > 0 and math.abs(t) < 6
			if not isGate then
				local h = 13 + rng:NextNumber(-0.6, 0.6)
				cylinder(m, "Log", h, 2, upright(x, h / 2, z), log, Enum.Material.Wood)
				small(block(m, "LogTip", Vector3.new(1.4, 1.4, 1.4), CFrame.new(x, h + 0.4, z) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), log, Enum.Material.Wood))
			end
		end
	end
	-- Walkway along the inside of the walls.
	for _, wall in ipairs({ { 0, -half + 2.5, 2 * half, 3 }, { 0, half - 2.5, 2 * half, 3 }, { -half + 2.5, 0, 3, 2 * half }, { half - 2.5, 0, 3, 2 * half } }) do
		block(m, "Walkway", Vector3.new(wall[3], 0.6, wall[4]), CFrame.new(cx + wall[1], 8.5, cz + wall[2]), C.WoodLight, Enum.Material.WoodPlanks)
	end
	-- Gate doors (open) and a sign above.
	for _, side in ipairs({ -1, 1 }) do
		block(m, "GateDoor", Vector3.new(6, 12, 0.8), CFrame.new(cx + side * 9, 6, cz + half + 3) * CFrame.Angles(0, side * 1.1, 0), C.WoodDark, Enum.Material.WoodPlanks)
	end
	local gateSign = block(m, "GateSign", Vector3.new(14, 3, 0.5), CFrame.new(cx, 15, cz + half + 0.5), C.WoodDark, Enum.Material.Wood)
	sign(gateSign, Enum.NormalId.Back, "FORT DUST", Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	-- Corner watchtowers.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local tx, tz = cx + sx * half, cz + sz * half
			for _, lx in ipairs({ -2.5, 2.5 }) do
				for _, lz in ipairs({ -2.5, 2.5 }) do
					block(m, "TowerLeg", Vector3.new(0.8, 18, 0.8), CFrame.new(tx + lx, 9, tz + lz), C.WoodDark, Enum.Material.Wood)
				end
			end
			block(m, "TowerFloor", Vector3.new(7, 0.6, 7), CFrame.new(tx, 16, tz), C.WoodLight, Enum.Material.WoodPlanks)
			block(m, "TowerRail", Vector3.new(7, 2, 0.4), CFrame.new(tx, 17.3, tz - 3.3), C.Wood, Enum.Material.WoodPlanks)
			block(m, "TowerRail", Vector3.new(7, 2, 0.4), CFrame.new(tx, 17.3, tz + 3.3), C.Wood, Enum.Material.WoodPlanks)
			block(m, "TowerRoof", Vector3.new(8, 0.6, 8), CFrame.new(tx, 21, tz), C.Roof, Enum.Material.WoodPlanks)
		end
	end
	-- Inside: barracks, flag, cannons, supplies.
	westernBuilding(m, "BARRACKS", CFrame.new(cx, 0, cz - 10), 22, 14, 10, C.Wood)
	flag(m, cx + 14, cz + 12, 22, FLAG_PALETTES[2], 0)
	for _, side in ipairs({ -1, 1 }) do
		local x, z = cx + side * 12, cz + 18
		cylinder(m, "CannonBarrel", 6, 1.4, CFrame.new(x, 2.3, z) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0.15), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
		for _, dx in ipairs({ -1, 1 }) do
			cylinder(m, "CannonWheel", 0.5, 3, CFrame.new(x + dx * 1.2, 1.5, z + 0.5), C.WoodDark, Enum.Material.Wood)
		end
		for k = 1, 3 do
			small(block(m, "Cannonball", Vector3.new(1, 1, 1), CFrame.new(x + side * 3, 0.5, z - 1 + k * 1.1), Color3.fromRGB(30, 30, 30), Enum.Material.Metal, { Shape = Enum.PartType.Ball }))
		end
	end
	for i = 1, 5 do
		crate(m, cx - 22 + rng:NextNumber(-2, 2), cz + 14 + i * 2.6)
	end
	barrel(m, cx + 22, cz + 18)
	barrel(m, cx + 22, cz + 21)
	lanternPost(m, cx - 7, cz + half + 3)
	lanternPost(m, cx + 7, cz + half + 3)
end

-- Signpost at the race start pointing to every place on the map.
local function crossroads(f, x, z)
	local m = model(f, "Signpost")
	block(m, "Post", Vector3.new(0.8, 14, 0.8), CFrame.new(x, 7, z), C.WoodDark, Enum.Material.Wood)
	local signs = {
		{ "RIVER & BRIDGE", 0, 0 },
		{ "RANCH", 0.5, 1 },
		{ "TOWN · STATION", math.pi / 2, 2 },
		{ "FORT DUST", math.pi, 3 },
		{ "GHOST TOWN", -math.pi / 2 - 0.2, 4 },
		{ "OASIS · MINE", -math.pi / 2 + 0.5, 5 },
	}
	for _, def in ipairs(signs) do
		-- Arrow board pointing along its yaw (0 = north / +Z).
		local cf = CFrame.new(x, 12.5 - def[3] * 1.5, z) * CFrame.Angles(0, -def[2] + math.pi / 2, 0) * CFrame.new(3.2, 0, 0)
		local board = block(m, "Arrow", Vector3.new(6, 1.2, 0.3), cf, C.WoodLight, Enum.Material.WoodPlanks)
		sign(board, Enum.NormalId.Front, def[1], Color3.fromRGB(50, 30, 15), nil, Enum.Font.Fondamento)
		sign(board, Enum.NormalId.Back, def[1], Color3.fromRGB(50, 30, 15), nil, Enum.Font.Fondamento)
	end
end

local function buildNewPlaces()
	local f = folder("NewPlaces")
	-- Flat ground for each place first.
	flatten(140, 220, 75) -- ranch
	flatten(10, -410, 50) -- fort
	flatten(-170, -40, 70) -- ghost town
	flatten(-200, riverZ(-200) - 30, 30) -- gold camp
	buildRiver(f)
	coveredBridge(f, 0)
	railwayTrestle(f, 440)
	goldCamp(f, -200)
	ghostTown(f, -170, -40)
	ranch(f, 140, 215)
	fort(f, 10, -410)
	crossroads(f, 30, 140)
	-- Roads linking them up.
	road(0, 210, 14, 100) -- race start -> bridge
	road(0, riverZ(0) + 60, 14, 70) -- across the bridge, north
	road(140, 150, 12, 100) -- town road -> ranch
	road(-170, -40, 14, 150) -- ghost town main street
	road(-170, 92, 14, 116) -- ghost town -> west road
	road(5, -335, 12, 90) -- church -> fort
	road(-200, riverZ(-200) - 60, 12, 70) -- west road -> gold camp
end

-- NPC markers: NPCService (runtime) spawns a character at each.
local NPCS = {
	{ "Race Announcer", "Announcer", Vector3.new(-6, 0, 118), 0, "Welcome, riders! The greatest horse race in history starts right here!|Six thousand kilometers of desert, mountains and rivers. Only one can win.|Keep your Spin steady and your eyes on the trail!" },
	{ "Race Official", "Official", Vector3.new(10, 0, 100), 0, "Racers, line up behind the start banner.|No shortcuts through the town, I'm watching you.|Checkpoints are marked with flags. Don't miss one!" },
	{ "Rival Racer", "Racer", Vector3.new(-8, 0, 60), 0, "Think you can keep up? Ha!|I've trained for this race my whole life.|See you at the goal... if you make it." },
	{ "Rookie Racer", "Racer", Vector3.new(8, 0, 20), 0, "My first race! I'm so nervous...|Do you know how to do that spinning thing?|I heard someone can fire their fingernails. Scary!" },
	{ "Camp Cook", "Spectator", Vector3.new(-60, 0, -20), 12, "Beans again tonight, folks.|Eat up, the desert won't wait for you.|Stay away from the cactus juice." },
	{ "Wagon Driver", "Spectator", Vector3.new(70, 0, -80), 14, "These wheels have crossed three states already.|Need a ride? Sorry, wagons are for supplies only.|Dust storm's coming, I can feel it." },
	{ "Sheriff", "Guard", Vector3.new(272, 0, 6), 6, "No fighting on Main Street. Take it outside of town.|I've got my eye on you, stranger.|Strange powers in this race. Strange times." },
	{ "Saloon Owner", "Spectator", Vector3.new(248, 0, 40), 6, "Welcome to the saloon, partner!|Racers drink free... water, that is.|Heard the favourite spins steel balls. Odd fellow." },
	{ "Shopkeeper", "Spectator", Vector3.new(272, 0, 40), 6, "Ropes, canteens, horseshoes, all here.|Prices doubled for the race. Supply and demand!|Come back when you've got more coin." },
	{ "Townsfolk", "Spectator", Vector3.new(260, 0, -40), 30, "The racers came through town at dawn!|My money's on the cowboy with the blue scarf.|Did you see that flash of light out by the church?" },
	{ "Priest", "Spectator", Vector3.new(0, 0, -270), 10, "Peace be with you, traveller.|This mission has stood for a hundred years.|Many racers rest here before the long road." },
	{ "Stable Hand", "Spectator", Vector3.new(-66, 0, 112), 8, "Easy, easy... these horses are nervous before a race.|A good horse is worth more than gold out here.|Feed them, water them, never rush them." },
	{ "Station Master", "Official", Vector3.new(425, 1.6, 10), 10, "Next train to the east leaves at sundown.|Racers ride horses, not trains. Rules are rules!|The telegraph says the leaders passed Arizona already." },
	{ "Old Miner", "Spectator", Vector3.new(-320, 0, -335), 6, "Silver? Nah, the mine's been empty for years.|I heard strange spinning sounds down there last night.|Don't go in without a lantern." },
	{ "Oasis Traveller", "Spectator", Vector3.new(-262, 0, 178), 10, "Fresh water! First I've seen in two days.|Rest here before you cross the dunes.|The mesas make good landmarks. Don't get lost." },
	{ "Headquarters Clerk", "Official", Vector3.new(260, 18, -228), 8, "Registration is closed, I'm afraid.|The sponsors are watching every rider closely.|Prize money is fifty million dollars. Can you believe it?" },
	{ "Bridge Keeper", "Official", Vector3.new(-9, 0, 258), 6, "Toll's free during the race. Lucky you.|This bridge has survived three floods.|Don't fight on my bridge. The river's colder than it looks." },
	{ "Gold Prospector", "Spectator", Vector3.new(-196, 0, 240), 10, "Gold! There's gold in this river, I tell ya!|Keep your hands off my claim.|Found a nugget shaped like a horseshoe this morning." },
	{ "Ranch Owner", "Spectator", Vector3.new(118, 0, 196), 10, "Welcome to the Lucky Horseshoe!|Best horses west of the Mississippi.|Need a fresh mount? Win the race first." },
	{ "Cowhand", "Spectator", Vector3.new(196, 0, 214), 14, "Yee-haw! Watch the cows, they spook easy.|I rope cattle all day. Spinning? That's new.|The barn's got hay if your horse is hungry." },
	{ "Fort Captain", "Guard", Vector3.new(4, 0, -392), 8, "Fort Dust stands guard over the southern trail.|Report any strange powers to me, rider.|My soldiers saw someone fire nails from his fingers!" },
	{ "Fort Soldier", "Guard", Vector3.new(18, 0, -428), 10, "Halt! Oh, a racer. Carry on.|Watch duty again... nothing but sand.|The cannons haven't fired in years." },
	{ "Mysterious Drifter", "Spectator", Vector3.new(-168, 0, -20), 12, "Nobody's lived in Dustwater for twenty years.|The well dried up and the people left.|Some say a Stand user drained it. Who knows." },
	{ "Fisherman", "Spectator", Vector3.new(60, 0, 268), 6, "Shh, you'll scare the fish.|Caught a catfish this big yesterday!|The waterfall's to the west, if you like sightseeing." },
}

local function buildNPCMarkers()
	local f = folder("NPCSpawns")
	for _, def in ipairs(NPCS) do
		local marker = block(f, def[1]:gsub(" ", ""), Vector3.new(2, 1, 2), CFrame.new(def[3] + Vector3.new(0, 0.5, 0)), Color3.fromRGB(80, 200, 255), Enum.Material.Neon, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		marker:SetAttribute("DisplayName", def[1])
		marker:SetAttribute("Role", def[2])
		marker:SetAttribute("WanderRadius", def[4])
		marker:SetAttribute("Lines", def[5])
	end
	-- Waypoints racers jog between (along the track).
	local wp = folder("RacerWaypoints")
	for i, z in ipairs({ 100, 0, -100, -200, -100, 0 }) do
		local p = block(wp, "Waypoint" .. i, Vector3.new(1, 1, 1), CFrame.new((i % 2 == 0) and 5 or -5, 0.5, z), Color3.new(1, 1, 1), Enum.Material.Neon, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		p:SetAttribute("Order", i)
	end
end

---------------------------------------------------------------------------
function SBRMapBuilder.Build(options)
	options = options or {}
	origin = options.Origin or Vector3.new(0, 0, 0)
	rng = Random.new(options.Seed or 7)

	local old = workspace:FindFirstChild("SBRMap")
	if old then
		old:Destroy()
	end
	root = Instance.new("Model")
	root.Name = "SBRMap"
	root:SetAttribute("Origin", origin)

	if options.Terrain ~= false then
		buildTerrain()
	end
	if options.Lighting ~= false then
		buildLighting()
	end
	buildRaceGrounds()
	buildChurch()
	buildCamp()
	buildTown()
	buildHeadquarters()
	buildDesert()
	buildUpgrades()
	buildNewPlaces()
	buildNPCMarkers()
	root.Parent = workspace

	local count = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			count = count + 1
		end
	end
	print(("[SBRMapBuilder] Built SBRMap with %d parts at %s. Remember File > Save."):format(count, tostring(origin)))
	return root
end

return SBRMapBuilder
end

-- ======================================================================
-- MODULE: StandAssetLoader
-- ======================================================================
__modules["StandAssetLoader"] = function()
--[[
	StandAssetLoader  (ServerScriptService.SpinServer.StandAssetLoader)

	Loads the Stand models listed in TuskConfig.StandModels (by asset id)
	into ReplicatedStorage.SpinAssets as "TuskAct1", "TuskAct2"...
	Every client then uses that model instead of the built-in one.

	Safety: every Script, LocalScript and ModuleScript inside a loaded
	model is deleted before anyone can see it (free models sometimes hide
	harmful scripts).

	If Roblox refuses to load an asset (InsertService can only load models
	your account owns, or free models depending on Roblox's rules), the
	Output says so. Then insert the model yourself: Toolbox > search the id
	> drag it into ReplicatedStorage > put it in a Folder named SpinAssets
	> rename it TuskAct1.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local StandAssetLoader = {}

local function assetsFolder()
	local folder = ReplicatedStorage:FindFirstChild("SpinAssets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SpinAssets"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local function sanitize(model)
	local removed = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
			removed = removed + 1
		end
	end
	return removed
end

local function load(act, entry)
	local name = "TuskAct" .. act
	local folder = assetsFolder()
	if folder:FindFirstChild(name) then
		return -- already placed by hand: keep it
	end
	local ok, container = pcall(function()
		return InsertService:LoadAsset(entry.AssetId)
	end)
	if not ok or not container then
		warn(("[Spin] Could not load Stand model %d for Act %d (%s). Insert it by hand: Toolbox > drag into ReplicatedStorage.SpinAssets > rename %s."):format(entry.AssetId, act, tostring(container), name))
		return
	end
	local model = container:FindFirstChildWhichIsA("Model", true) or container
	local removed = sanitize(model)
	model.Name = name
	if not model:IsA("Model") then
		local wrapper = Instance.new("Model")
		for _, child in ipairs(model:GetChildren()) do
			child.Parent = wrapper
		end
		model = wrapper
		model.Name = name
	end
	model.Parent = folder
	container:Destroy()
	print(("[Spin] Loaded Stand model %d as %s%s"):format(entry.AssetId, name, removed > 0 and (" (removed " .. removed .. " scripts for safety)") or ""))
end

function StandAssetLoader.init()
	for act, entry in pairs(TuskConfig.StandModels or {}) do
		if entry.AssetId and entry.AssetId ~= 0 then
			task.spawn(load, act, entry)
		end
	end
end

return StandAssetLoader
end

-- ======================================================================
-- MODULE: SteelBallModel
-- ======================================================================
__modules["SteelBallModel"] = function()
--[[
	SteelBallModel  (ReplicatedStorage.SpinShared.SteelBallModel)

	Procedurally builds the Steel Ball from the owner's reference images:
	a glossy green metal sphere with raised hexagon panels (dark outer edge
	plus a bright inner edge, so they read as raised plates), round
	panels, and curved parallel grooves sweeping around the surface.

	SteelBallModel.build(diameter, detailed) -> Model (PrimaryPart = "Core")
	  detailed = false (Low quality) keeps only the hexagon outer edges.

	All parts are visual only: no collision, no queries, no touch events,
	massless, and welded to the Core. Anchor the Core to move it with
	PivotTo, or weld the Core to a hand.

	Swapping in a real mesh later: put a Model named "SteelBall" (with a
	PrimaryPart) in ReplicatedStorage.SpinShared.Assets and build() will
	clone and resize it instead of generating one.
]]

local SpinConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("SpinConfig"))

local SteelBallModel = {}

-- Panel layout (unit directions on the ball, angular radius in radians).
-- Kept as data so the look can be tuned without touching the builder.
SteelBallModel.Layout = {
	Hexagons = {
		{ Dir = Vector3.new(-0.45, 0.35, 0.82), Radius = 0.55, Spin = 0.2 },
		{ Dir = Vector3.new(0.6, -0.2, -0.77), Radius = 0.5, Spin = 0.5 },
		{ Dir = Vector3.new(-0.3, -0.85, -0.4), Radius = 0.45, Spin = 0.0 },
	},
	Circles = {
		{ Dir = Vector3.new(0.45, -0.4, 0.8), Radius = 0.3 },
		{ Dir = Vector3.new(0.2, 0.85, -0.45), Radius = 0.35 },
	},
	-- Grooves: arcs of a circle around Axis at angular radius Radius,
	-- from angle From to To (radians).
	Grooves = {
		{ Axis = Vector3.new(0.95, 0.25, 0.15), Radius = 0.5, From = -1.2, To = 1.3 },
		{ Axis = Vector3.new(0.95, 0.25, 0.15), Radius = 0.78, From = -1.0, To = 1.1 },
		{ Axis = Vector3.new(-0.75, 0.15, -0.6), Radius = 0.6, From = 0.6, To = 3.2 },
	},
}

local function visualPart(props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function weld(core, part)
	local w = Instance.new("WeldConstraint")
	w.Part0 = core
	w.Part1 = part
	w.Parent = part
end

-- Two unit vectors perpendicular to dir.
local function basis(dir)
	local helper = math.abs(dir.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local u = dir:Cross(helper).Unit
	local v = dir:Cross(u).Unit
	return u, v
end

-- Point on the unit sphere at angular distance `radius` from `center`, around angle `theta`.
local function around(center, radius, theta)
	local u, v = basis(center)
	return (center * math.cos(radius) + (u * math.cos(theta) + v * math.sin(theta)) * math.sin(radius)).Unit
end

local function fromOverride(diameter)
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
	local custom = assets and assets:FindFirstChild("SteelBall")
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		local clone = custom:Clone()
		local size = clone:GetExtentsSize()
		local largest = math.max(size.X, size.Y, size.Z)
		if largest > 0 then
			clone:ScaleTo(clone:GetScale() * diameter / largest)
		end
		clone.PrimaryPart.Name = "Core"
		return clone
	end
	return nil
end

function SteelBallModel.build(diameter, detailed)
	diameter = diameter or 1
	if detailed == nil then
		detailed = true
	end

	local override = fromOverride(diameter)
	if override then
		return override
	end

	local colors = SpinConfig.Colors
	local r = diameter / 2

	local model = Instance.new("Model")
	model.Name = "SteelBall"

	local core = visualPart({
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		Color = colors.Ball,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.18,
		Massless = false,
	})
	core.CFrame = CFrame.new()
	core.Parent = model
	model.PrimaryPart = core

	-- Attachments other systems hook effects onto.
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = core
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, r * 0.9, 0)
	top.Parent = core
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -r * 0.9, 0)
	bottom.Parent = core

	-- One straight raised line between two directions on the surface.
	local function line(a, b, width, color, name)
		local lift = r * 1.012
		local pa, pb = a * lift, b * lift
		local mid = (pa + pb) / 2
		local seg = visualPart({
			Name = name,
			Size = Vector3.new(width, width * 0.5, (pb - pa).Magnitude + width * 0.6),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0.1,
		})
		seg.CFrame = CFrame.lookAt(mid, pb, mid.Unit)
		seg.Parent = model
		weld(core, seg)
	end

	local function polygon(dirCenter, radius, sides, spin, width, color, name)
		local c = dirCenter.Unit
		for i = 0, sides - 1 do
			local a = around(c, radius, spin + i / sides * math.pi * 2)
			local b = around(c, radius, spin + (i + 1) / sides * math.pi * 2)
			line(a, b, width, color, name)
		end
	end

	local layout = SteelBallModel.Layout

	-- Hexagon plates: dark outer edge, bright inner edge.
	for _, hex in ipairs(layout.Hexagons) do
		polygon(hex.Dir, hex.Radius, 6, hex.Spin, diameter * 0.04, colors.BallDark, "HexEdge")
		if detailed then
			polygon(hex.Dir, hex.Radius * 0.84, 6, hex.Spin, diameter * 0.025, colors.BallLight, "HexHighlight")
		end
	end

	if detailed then
		-- Round panels.
		for _, circle in ipairs(layout.Circles) do
			polygon(circle.Dir, circle.Radius, 10, 0, diameter * 0.035, colors.BallDark, "RoundPanel")
		end
		-- Curved grooves.
		for _, groove in ipairs(layout.Grooves) do
			local axis = groove.Axis.Unit
			local steps = 6
			for i = 0, steps - 1 do
				local t0 = groove.From + (groove.To - groove.From) * i / steps
				local t1 = groove.From + (groove.To - groove.From) * (i + 1) / steps
				line(around(axis, groove.Radius, t0), around(axis, groove.Radius, t1), diameter * 0.03, colors.BallDark, "Groove")
			end
		end
	end

	return model
end

return SteelBallModel
end

-- ======================================================================
-- MODULE: TestDummies
-- ======================================================================
__modules["TestDummies"] = function()
--[[
	TestDummies  (ServerScriptService.SpinServer.TestDummies)
	Studio-only practice targets so Spin can be tested solo.
	Never runs in a live server (guarded by RunService:IsStudio()).
	Turn off with SpinConfig.Debug.SpawnTestDummies = false.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SpinConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("SpinConfig"))

local TestDummies = {}

local function findSpawn()
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.CFrame
	end
	return CFrame.new(0, 5, 0)
end

local function spawnDummy(folder, cframe, index)
	local ok, dummy = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not dummy then
		warn("[TestDummies] could not create dummy:", dummy)
		return
	end
	dummy.Name = "SpinDummy" .. index
	dummy:PivotTo(cframe)
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.MaxHealth = 150
	humanoid.Health = 150
	dummy.Parent = folder
	humanoid.Died:Connect(function()
		task.wait(SpinConfig.Debug.DummyRespawnTime)
		dummy:Destroy()
		spawnDummy(folder, cframe, index)
	end)
end

function TestDummies.init()
	if not RunService:IsStudio() or not SpinConfig.Debug.SpawnTestDummies then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "SpinTestDummies"
	folder.Parent = workspace
	local base = findSpawn()
	for i = 1, SpinConfig.Debug.DummyCount do
		local offset = CFrame.new((i - (SpinConfig.Debug.DummyCount + 1) / 2) * 8, 3, -30 - i * 6)
		spawnDummy(folder, base * offset * CFrame.Angles(0, math.pi, 0), i)
	end
end

return TestDummies
end

-- ======================================================================
-- MODULE: TuskAct1
-- ======================================================================
__modules["TuskAct1"] = function()
--[[
	TuskAct1  (ServerScriptService.SpinServer.TuskActs.TuskAct1)

	Server logic for Tusk Act 1, "the beginning of Spin".
	  M1        NAIL COMBO: jab, nail strike, spinning nail assist, shock finisher
	  Ability 1 NAIL SHOT: one spinning nail
	  Ability 2 NAIL BARRAGE: five nails fanned out
	  Ability 3 SPINNING NAIL: hold to charge, release (golden-blue at full charge)
	  Ultimate  TUSK AWAKENING: armored cinematic burst, then evolves to Act 2
	            (in Menu mode: 20 s Awakened buff instead)

	Every number is in TuskConfig.Act1. All hits go through S.hit()
	(CombatAdapter), all timing and cooldowns live here on the server.
	Visual events are sent with S.fx(); clients choreograph them in
	SpinClient.TuskActVFX.Act1.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local Act1 = {}
local cfg = TuskConfig.Act1

local HAND_OFFSET = CFrame.new(0.9, 0.55, -1.5) -- right-hand fingertip area

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function nailDamage(state, base)
	return state.Awakened and base * cfg.Ultimate.DamageMultiplier or base
end

local function cooldown(state, base)
	return state.Awakened and base * cfg.Ultimate.CooldownMultiplier or base
end

---------------------------------------------------------------------------
-- M1: NAIL COMBO
---------------------------------------------------------------------------
function Act1.M1(S, player, state, aim)
	local m = cfg.M1
	if S.isBusy(state) or state.Charging then
		return
	end
	local now = os.clock()
	if now - state.LastM1 > m.ResetAfter then
		state.Combo = 0
	end
	local index = state.Combo + 1
	state.Combo = index >= 4 and 0 or index
	state.LastM1 = now
	S.lock(state, index == 4 and m.EndLag or m.Interval)

	local character, _, root = alive(S, player)
	local hit = m.Hits[index]
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("M1", { Character = character, Act = 1, Index = index })

	task.delay(m.Windup, function()
		-- Getting stunned during the wind-up cancels the hit (trades are fair).
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		if hit.Projectile then
			local p = hit.Projectile
			S.fireNail(player, state, {
				Origin = S.origin(char, r, HAND_OFFSET),
				Direction = direction,
				Speed = p.Speed,
				Radius = p.Radius,
				Range = p.Range,
				Style = "M1",
				OnHit = function(target, position)
					S.hit(player, target, {
						Damage = hit.Damage,
						Stun = hit.Stun,
						Knockback = hit.Knockback,
						Direction = direction,
						Position = position,
						Source = "TuskM1",
					})
				end,
			})
			return
		end

		local boxCF = r.CFrame * CFrame.new(0, 0, -m.HitboxForward)
		local targets = S.Hitbox.inBox(char, boxCF, m.HitboxSize, m.MaxTargets)
		local landed = false
		for _, target in ipairs(targets) do
			local targetRoot = target:FindFirstChild("HumanoidRootPart")
			if targetRoot and S.Hitbox.lineOfSight(r.Position, targetRoot.Position, { char, target }) then
				local ok = S.hit(player, target, {
					Damage = hit.Damage,
					Stun = hit.Stun,
					Knockback = hit.Knockback,
					Launch = hit.Launch,
					Direction = targetRoot.Position - r.Position,
					Position = targetRoot.Position,
					Source = "TuskM1",
				})
				landed = landed or ok
			end
		end
		if index == 4 then
			S.fx("M1Finisher", { Character = char, Act = 1, Position = boxCF.Position, Radius = hit.ShockwaveRadius, Hit = landed })
		end
	end)
end

---------------------------------------------------------------------------
-- Abilities
---------------------------------------------------------------------------
local function nailShot(S, player, state, aim)
	local c = cfg.NailShot
	if S.isBusy(state) or state.Charging or not S.cooldownReady(player, state, "NailShot", 1) then
		return
	end
	S.startCooldown(player, state, "NailShot", cooldown(state, c.Cooldown), 1)
	S.lock(state, c.Startup + 0.2)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 1, Move = "NailShot", Phase = "Startup", Direction = direction, Startup = c.Startup })

	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		S.fireNail(player, state, {
			Origin = S.origin(char, r, HAND_OFFSET),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Shot",
			OnHit = function(target, position)
				S.hit(player, target, {
					Damage = nailDamage(state, c.Damage),
					Stun = c.Stun,
					Knockback = c.Knockback,
					Direction = direction,
					Position = position,
					Source = "TuskNailShot",
				})
			end,
		})
	end)
end

-- Fixed fan pattern (not random) so the barrage is readable and dodgeable.
local BARRAGE_PATTERN = { { 0, 0 }, { -1, 0.3 }, { 1, -0.2 }, { -0.5, -0.4 }, { 0.6, 0.5 }, { 0, 0.2 }, { -1, -0.3 } }

local function nailBarrage(S, player, state, aim)
	local c = cfg.NailBarrage
	if S.isBusy(state) or state.Charging or not S.cooldownReady(player, state, "NailBarrage", 2) then
		return
	end
	S.startCooldown(player, state, "NailBarrage", cooldown(state, c.Cooldown), 2)
	S.lock(state, c.Startup + c.Count * c.Interval + 0.15)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 1, Move = "NailBarrage", Phase = "Startup", Direction = direction, Startup = c.Startup, Count = c.Count, Interval = c.Interval })

	for i = 1, c.Count do
		task.delay(c.Startup + (i - 1) * c.Interval, function()
			if not S.stillValid(player, state, life) then
				return
			end
			local char, _, r = alive(S, player)
			local pattern = BARRAGE_PATTERN[(i - 1) % #BARRAGE_PATTERN + 1]
			local spread = math.rad(c.SpreadDegrees)
			local look = CFrame.lookAt(Vector3.new(), direction)
			local dir = (look * CFrame.Angles(pattern[2] * spread * 0.5, pattern[1] * spread, 0)).LookVector
			S.fireNail(player, state, {
				Origin = S.origin(char, r, HAND_OFFSET),
				Direction = dir,
				Speed = c.Speed,
				Radius = c.Radius,
				Range = c.Range,
				Style = "Barrage",
				OnHit = function(target, position)
					S.hit(player, target, {
						Damage = nailDamage(state, c.Damage),
						Stun = c.Stun,
						Knockback = c.Knockback,
						Direction = dir,
						Position = position,
						Source = "TuskNailBarrage",
					})
				end,
			})
		end)
	end
end

local function spinningNailRelease(S, player, state, aim)
	local c = cfg.SpinningNail
	local charge = S.endCharge(player, state)
	if not charge or charge.Move ~= "SpinningNail" then
		return
	end
	local character, _, root = alive(S, player)
	if not character then
		return
	end
	local t = math.clamp((os.clock() - charge.Start) / c.FullChargeAt, 0, 1)
	local full = t >= 1
	local direction = S.aim(aim, root)
	local function lerp(a, b)
		return a + (b - a) * t
	end
	S.startCooldown(player, state, "SpinningNail", cooldown(state, c.Cooldown), 3)
	S.lock(state, 0.3)
	S.fx("Ability", { Character = character, Act = 1, Move = "SpinningNail", Phase = "Release", Charge = t, Full = full, Direction = direction })
	S.fireNail(player, state, {
		Origin = S.origin(character, root, HAND_OFFSET),
		Direction = direction,
		Speed = lerp(c.MinSpeed, c.MaxSpeed),
		Radius = lerp(c.MinRadius, c.MaxRadius),
		Range = c.Range,
		Style = "Spinning",
		Charge = t,
		OnHit = function(target, position)
			S.hit(player, target, {
				Damage = nailDamage(state, lerp(c.MinDamage, c.MaxDamage)),
				Stun = c.Stun * (0.5 + t * 0.5),
				Knockback = c.Knockback * (0.4 + t * 0.6),
				Direction = direction,
				Position = position,
				Source = "TuskSpinningNail",
			})
		end,
	})
end

local function spinningNailPress(S, player, state)
	local c = cfg.SpinningNail
	if S.isBusy(state) or state.Charging or not S.cooldownReady(player, state, "SpinningNail", 3) then
		return
	end
	local charge = S.beginCharge(player, state, "SpinningNail", 3, c.WalkSpeedMultiplier)
	local token = charge.Token
	task.delay(c.MaxHold, function()
		if state.Charging and state.Charging.Token == token then
			spinningNailRelease(S, player, state, nil) -- auto-release forward
		end
	end)
end

function Act1.Ability(S, player, state, slot, phase, aim)
	if slot == 1 and phase == "Press" then
		nailShot(S, player, state, aim)
	elseif slot == 2 and phase == "Press" then
		nailBarrage(S, player, state, aim)
	elseif slot == 3 then
		if phase == "Press" then
			spinningNailPress(S, player, state)
		else
			spinningNailRelease(S, player, state, aim)
		end
	end
end

function Act1.CancelCharge(S, player, state)
	local charge = S.endCharge(player, state)
	if charge then
		S.startCooldown(player, state, charge.Move, 1.5, charge.Slot)
		S.fx("Ability", { Character = state.Character, Act = 1, Move = charge.Move, Phase = "Cancel" })
	end
end

---------------------------------------------------------------------------
-- Ultimate: TUSK AWAKENING
---------------------------------------------------------------------------
local function endAwakening(S, player, state)
	state.Awakened = false
	state.AwakenToken = nil
	if state.Character then
		state.Character:SetAttribute("TuskAwakened", nil)
	end
	S.tell(player, "AwakenEnded", {})
end

function Act1.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging or state.Awakened then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.4)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = 1, Phase = "Start", Windup = u.Windup })

	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if not S.stillValid(player, state, life, true) then
			return
		end
		local char, _, root = alive(S, player)
		for _, target in ipairs(S.Hitbox.inRadius(char, root.Position, u.Radius, 8)) do
			local targetRoot = target:FindFirstChild("HumanoidRootPart")
			if targetRoot and S.Hitbox.lineOfSight(root.Position, targetRoot.Position, { char, target }) then
				S.hit(player, target, {
					Damage = u.Damage,
					Stun = u.Stun,
					Knockback = u.Knockback,
					Launch = u.Launch,
					Direction = targetRoot.Position - root.Position,
					Position = targetRoot.Position,
					Source = "TuskAwakening",
				})
			end
		end
		S.fx("Ultimate", { Character = char, Act = 1, Phase = "Burst", Position = root.Position, Radius = u.Radius })

		if TuskConfig.Progression.Mode == "Awaken" then
			S.finishUltimate(player, state) -- awakens Tusk to Act 2
			return
		end
		state.Awakened = true
		local token = {}
		state.AwakenToken = token
		char:SetAttribute("TuskAwakened", true)
		S.tell(player, "Awakened", { Duration = u.Duration })
		task.delay(u.Duration, function()
			if state.AwakenToken == token then
				endAwakening(S, player, state)
			end
		end)
	end)
end

function Act1.Cleanup(S, player, state)
	if state.Charging then
		S.endCharge(player, state)
	end
	if state.Awakened then
		endAwakening(S, player, state)
	end
end

return Act1
end

-- ======================================================================
-- MODULE: TuskAct2
-- ======================================================================
__modules["TuskAct2"] = function()
--[[
	TuskAct2  (ServerScriptService.SpinServer.TuskActs.TuskAct2)

	Tusk Act 2: wormhole combat.
	  M1        DIMENSIONAL COMBO: Tusk-assisted hits, portal flashes, dimensional finisher
	  Ability 1 WORMHOLE NAIL: nail opens a wormhole where it lands; a second nail
	            bursts out of an exit portal behind the nearest enemy
	  Ability 2 UNDERGROUND PURSUIT: burrow, travel under the ground, emerge behind the target
	  Ability 3 NAIL DIMENSION: three portals around the target fire converging nails,
	            then a dimensional shockwave
	  Ultimate  DIMENSIONAL STORM: six portals rain nail waves, giant blue burst,
	            then Tusk evolves to Act 3
	Numbers: TuskConfig.Act2.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")
local Sneak = __require("TuskSneakService")

local Act2 = {}
local cfg = TuskConfig.Act2

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Act2.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 2)
end

local function wormholeNail(S, player, state, aim)
	local c = cfg.WormholeNail
	if not ready(S, player, state, "WormholeNail", 1) then
		return
	end
	S.startCooldown(player, state, "WormholeNail", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.2)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 2, Move = "WormholeNail", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		Moves.nail(S, player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Wormhole",
			Damage = c.Damage,
			Stun = c.Stun,
			Knockback = c.Knockback,
			Source = "TuskWormholeNail",
			OnEnd = function(position, normal)
				-- Entrance wormhole where the nail landed.
				S.fx("Portal", { Act = 2, Position = position + normal * 0.5, LookAt = position + normal * 5, Radius = 2.4, Duration = c.ExitDelay + 0.35 })
				-- Exit portal behind the nearest enemy near the impact.
				local victims = S.Hitbox.inRadius(char, position, c.ExitSearch, 1)
				local victim = victims[1]
				local vr = victim and victim:FindFirstChild("HumanoidRootPart")
				if not vr then
					return
				end
				local exitPos = (vr.CFrame * CFrame.new(0, 1.5, 6)).Position
				if not S.Hitbox.lineOfSight(vr.Position, exitPos, { char, victim }) then
					exitPos = vr.Position + Vector3.new(0, 7, 0)
				end
				S.fx("Portal", { Act = 2, Position = exitPos, LookAt = vr.Position, Radius = 2.2, Duration = c.ExitDelay + 0.45 })
				task.delay(c.ExitDelay, function()
					if state.Life ~= life or not vr.Parent then
						return
					end
					local dir = (vr.Position - exitPos)
					if dir.Magnitude < 0.5 then
						return
					end
					Moves.nail(S, player, state, {
						Origin = exitPos,
						Direction = dir.Unit,
						Speed = c.Speed,
						Radius = c.Radius,
						Range = dir.Magnitude + 6,
						Style = "Wormhole",
						Damage = c.ExitDamage,
						Stun = c.Stun,
						Knockback = c.Knockback,
						Source = "TuskWormholeNail",
					})
				end)
			end,
		})
	end)
end

local function undergroundPursuit(S, player, state, aim)
	local c = cfg.UndergroundPursuit
	if not ready(S, player, state, "UndergroundPursuit", 2) then
		return
	end
	local character, _, root = alive(S, player)
	local target = Moves.findTarget(S, character, root, c.Range, c.ConeDegrees, S.aim(aim, root))
	if not target then
		S.startCooldown(player, state, "UndergroundPursuit", 1.5, 2)
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	S.startCooldown(player, state, "UndergroundPursuit", c.Cooldown, 2)
	Sneak.burrowStrike(player, state, target, {
		Range = c.Range,
		BurrowTime = c.BurrowTime,
		WarningTime = c.WarningTime,
		EmergeDistance = 3.5,
		MaxTargetDrift = 16,
		HitRadius = c.HitRadius,
		Damage = c.Damage,
		Stun = c.Stun,
		Knockback = c.Knockback,
		Launch = c.Launch,
	}, "TuskUndergroundPursuit")
end

-- Portals around a point fire converging nails, then a shockwave.
local function nailDimension(S, player, state, aim)
	local c = cfg.NailDimension
	if not ready(S, player, state, "NailDimension", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local target = Moves.findTarget(S, character, root, c.Range, c.ConeDegrees, direction)
	local center
	if target then
		center = target.HumanoidRootPart.Position
	else
		center = Moves.groundBelow(root.Position + Moves.flat(direction) * 35, { character }) + Vector3.new(0, 3, 0)
	end
	S.startCooldown(player, state, "NailDimension", c.Cooldown, 3)
	S.lock(state, 0.6)
	local yaw = math.atan2(direction.Z, direction.X)
	local portals = Moves.ring(center, c.Portals, c.PortalRadius, yaw, 4, 8)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 2, Move = "NailDimension", Phase = "Open", Portals = portals, Center = center, OpenTime = c.OpenTime })
	task.delay(c.OpenTime, function()
		if state.Life ~= life then
			return
		end
		local aimAt = (target and target.Parent and target:FindFirstChild("HumanoidRootPart")) and target.HumanoidRootPart.Position or center
		for _, pos in ipairs(portals) do
			local dir = aimAt - pos
			Moves.nail(S, player, state, {
				Origin = pos,
				Direction = dir.Unit,
				Speed = c.Speed,
				Radius = 0.8,
				Range = dir.Magnitude + 8,
				Style = "Portal",
				Damage = c.Damage,
				Stun = c.Stun,
				Knockback = c.Knockback,
				Source = "TuskNailDimension",
			})
		end
		local travel = (portals[1] - aimAt).Magnitude / c.Speed
		task.delay(travel + 0.05, function()
			if state.Life ~= life then
				return
			end
			Moves.aoe(S, player, aimAt, c.FinalRadius, { Damage = c.FinalDamage, Stun = 0.3, Knockback = 20, Launch = 12, Source = "TuskNailDimension" }, 5)
			S.fx("AbilityImpact", { Act = 2, Move = "NailDimension", Position = aimAt, Radius = c.FinalRadius })
		end)
	end)
end

function Act2.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		wormholeNail(S, player, state, aim)
	elseif slot == 2 then
		undergroundPursuit(S, player, state, aim)
	elseif slot == 3 then
		nailDimension(S, player, state, aim)
	end
end

-- DIMENSIONAL STORM
function Act2.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local life = state.Life
	local total = u.Windup + u.Waves * u.WaveInterval + 0.5
	S.lock(state, total)
	character:SetAttribute("Armored", true)
	local center = root.Position
	local portals = Moves.ring(center, u.Portals, u.Radius * 0.55, math.random() * math.pi * 2, 7, 11)
	S.fx("Ultimate", { Character = character, Act = 2, Phase = "Start", Windup = u.Windup, Portals = portals, Center = center })

	local function finish()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
	end
	for wave = 1, u.Waves do
		task.delay(u.Windup + (wave - 1) * u.WaveInterval, function()
			if state.Life ~= life then
				return
			end
			local targets = S.Hitbox.inRadius(character, center, u.Radius, 8)
			for i, pos in ipairs(portals) do
				local t = targets[(i + wave) % math.max(#targets, 1) + 1]
				local tr = t and t:FindFirstChild("HumanoidRootPart")
				local aimAt = tr and tr.Position or (center + Vector3.new(math.random(-12, 12), -2, math.random(-12, 12)))
				local dir = aimAt - pos
				Moves.nail(S, player, state, {
					Origin = pos,
					Direction = dir.Unit,
					Speed = u.NailSpeed,
					Radius = 0.8,
					Range = dir.Magnitude + 10,
					Style = "Portal",
					Damage = u.NailDamage,
					Stun = 0.3,
					Knockback = 4,
					Source = "TuskDimensionalStorm",
				})
			end
		end)
	end
	task.delay(total - 0.4, function()
		finish()
		if state.Life ~= life or not alive(S, player) then
			return
		end
		Moves.aoe(S, player, center, u.BurstRadius, { Damage = u.BurstDamage, Stun = u.Stun, Knockback = u.Knockback, Launch = u.Launch, Source = "TuskDimensionalStorm" }, 8)
		S.fx("Ultimate", { Character = character, Act = 2, Phase = "Burst", Position = center, Radius = u.BurstRadius })
		task.delay(0.35, function()
			if state.Life == life then
				S.finishUltimate(player, state) -- evolves to Act 3
			end
		end)
	end)
	task.delay(total + 1, finish)
end

function Act2.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
	end
end

return Act2
end

-- ======================================================================
-- MODULE: TuskAct3
-- ======================================================================
__modules["TuskAct3"] = function()
--[[
	TuskAct3  (ServerScriptService.SpinServer.TuskActs.TuskAct3)

	Tusk Act 3: master of spatial movement.
	  M1        WORMHOLE STRIKES: fast combo with portal flashes, portal uppercut finisher
	  Ability 1 DIMENSIONAL STEP: short validated portal teleport (entrance + exit portals)
	  Ability 2 SPATIAL PURSUIT: four portals around the target fire nails one after
	            another, each re-aimed at where the target is now
	  Ability 3 DIMENSIONAL BREAK: energy gathers, a large portal opens, a long
	            dimensional shockwave tears forward
	  Ultimate  INFINITE DIMENSION: layered portals around the battlefield, a giant
	            dimensional collapse, then Tusk evolves to Act 4
	Numbers: TuskConfig.Act3.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Act3 = {}
local cfg = TuskConfig.Act3

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Act3.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 3)
end

local function dimensionalStep(S, player, state, aim)
	local c = cfg.DimensionalStep
	if not ready(S, player, state, "DimensionalStep", 1) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local destination = Moves.safeStep(character, root, direction, c.Distance)
	if not destination then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "DimensionalStep", c.Cooldown, 1)
	S.lock(state, 0.25)
	local from = root.Position
	character:SetAttribute(S.Adapter.Settings.IFrameAttribute, true)
	character:PivotTo(CFrame.lookAt(destination, destination + direction))
	S.fx("Ability", { Character = character, Act = 3, Move = "DimensionalStep", From = from, To = destination, Direction = direction })
	task.delay(c.IFrames, function()
		if character.Parent then
			character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
		end
	end)
end

local function spatialPursuit(S, player, state, aim)
	local c = cfg.SpatialPursuit
	if not ready(S, player, state, "SpatialPursuit", 2) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local target = Moves.findTarget(S, character, root, c.Range, c.ConeDegrees, direction)
	if not target then
		S.startCooldown(player, state, "SpatialPursuit", 1.5, 2)
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	S.startCooldown(player, state, "SpatialPursuit", c.Cooldown, 2)
	S.lock(state, 0.5)
	local tr = target.HumanoidRootPart
	local portals = Moves.ring(tr.Position, c.Portals, c.PortalRadius, math.random() * math.pi * 2, 3, 7)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 3, Move = "SpatialPursuit", Phase = "Open", Portals = portals, Target = target, OpenTime = c.OpenTime, Stagger = c.Stagger })
	for i, pos in ipairs(portals) do
		task.delay(c.OpenTime + (i - 1) * c.Stagger, function()
			if state.Life ~= life or not tr.Parent then
				return
			end
			local dir = tr.Position - pos -- re-aimed at the target's current position
			Moves.nail(S, player, state, {
				Origin = pos,
				Direction = dir.Unit,
				Speed = c.Speed,
				Radius = 0.8,
				Range = dir.Magnitude + 10,
				Style = "Portal",
				Damage = c.Damage,
				Stun = c.Stun,
				Knockback = c.Knockback,
				Source = "TuskSpatialPursuit",
			})
		end)
	end
end

local function dimensionalBreak(S, player, state, aim)
	local c = cfg.DimensionalBreak
	if not ready(S, player, state, "DimensionalBreak", 3) then
		return
	end
	S.startCooldown(player, state, "DimensionalBreak", c.Cooldown, 3)
	S.lock(state, c.Charge + 0.5)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 3, Move = "DimensionalBreak", Phase = "Charge", Charge = c.Charge, Direction = direction })
	task.delay(c.Charge, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local _, _, r = alive(S, player)
		local origin = r.Position
		local cf = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -(c.Length / 2 + 1))
		Moves.boxHit(S, player, cf, Vector3.new(c.Width, 9, c.Length), { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = direction, Source = "TuskDimensionalBreak" }, 6)
		S.fx("Ability", { Character = character, Act = 3, Move = "DimensionalBreak", Phase = "Release", Origin = origin, Direction = direction, Length = c.Length, Width = c.Width })
	end)
end

function Act3.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		dimensionalStep(S, player, state, aim)
	elseif slot == 2 then
		spatialPursuit(S, player, state, aim)
	elseif slot == 3 then
		dimensionalBreak(S, player, state, aim)
	end
end

-- INFINITE DIMENSION
function Act3.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.6)
	character:SetAttribute("Armored", true)
	local center = root.Position
	local inner = Moves.ring(center, u.Portals / 2, u.Radius * 0.45, 0, 5, 9)
	local outer = Moves.ring(center, u.Portals / 2, u.Radius * 0.85, math.pi / (u.Portals / 2), 10, 14)
	local portals = {}
	for _, p in ipairs(inner) do
		table.insert(portals, p)
	end
	for _, p in ipairs(outer) do
		table.insert(portals, p)
	end
	S.fx("Ultimate", { Character = character, Act = 3, Phase = "Start", Windup = u.Windup, Portals = portals, Center = center, Radius = u.Radius })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		Moves.aoe(S, player, center, u.Radius, { Damage = u.Damage, Stun = u.Stun, Knockback = u.Knockback, Launch = u.Launch, Source = "TuskInfiniteDimension" }, 10)
		S.fx("Ultimate", { Character = character, Act = 3, Phase = "Burst", Position = center, Radius = u.Radius })
		task.delay(0.4, function()
			if state.Life == life then
				S.finishUltimate(player, state) -- evolves to Act 4
			end
		end)
	end)
end

function Act3.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
	end
end

return Act3
end

-- ======================================================================
-- MODULE: TuskAct4
-- ======================================================================
__modules["TuskAct4"] = function()
--[[
	TuskAct4  (ServerScriptService.SpinServer.TuskActs.TuskAct4)

	Tusk Act 4: Infinite Rotation. Gold and deep blue, heavy and majestic.
	  M1        INFINITE BARRAGE: heavy punch, golden spin strike, rapid Stand
	            triple-hit, massive golden rotational finisher (area)
	  Ability 1 GOLDEN SPIN NAIL: big rotating projectile, golden impact blast
	  Ability 2 INFINITE ROTATION (hold): 3 charge stages, bigger projectile and
	            blast per stage
	  Ability 3 GOLDEN PURSUIT: golden rush to the first enemy ahead, rotational
	            strikes, huge golden shockwave
	  Ultimate  INFINITE ROTATION: 10-step cinematic, giant golden rotational
	            projectile, battlefield-wide golden shockwave (final form)
	Numbers: TuskConfig.Act4.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Act4 = {}
local cfg = TuskConfig.Act4

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Act4.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 4)
end

-- Projectile with an area blast where it lands (direct target excluded from the blast).
local function blastNail(S, player, state, spec, blastRadius, blastDamage, source)
	local directHit = {}
	local base = spec.OnHit
	spec.OnEnd = function(position, _, hitCharacter)
		if hitCharacter then
			directHit[hitCharacter] = true
		end
		Moves.aoe(S, player, position, blastRadius, { Damage = blastDamage, Stun = 0.35, Knockback = 25, Launch = 10, Source = source }, 6, directHit)
	end
	return Moves.nail(S, player, state, spec), base
end

local function goldenSpinNail(S, player, state, aim)
	local c = cfg.GoldenSpinNail
	if not ready(S, player, state, "GoldenSpinNail", 1) then
		return
	end
	S.startCooldown(player, state, "GoldenSpinNail", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.25)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 4, Move = "GoldenSpinNail", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		blastNail(S, player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Golden",
			Damage = c.Damage,
			Stun = c.Stun,
			Knockback = c.Knockback,
			Source = "TuskGoldenSpinNail",
		}, c.ImpactRadius, c.ImpactDamage, "TuskGoldenSpinNail")
	end)
end

local function infiniteRotationRelease(S, player, state, aim)
	local c = cfg.InfiniteRotation
	local charge = S.endCharge(player, state)
	if not charge or charge.Move ~= "InfiniteRotation" then
		return
	end
	local character, _, root = alive(S, player)
	if not character then
		return
	end
	local held = os.clock() - charge.Start
	local stage = 1
	for i, t in ipairs(c.Stages) do
		if held >= t then
			stage = i
		end
	end
	local direction = S.aim(aim, root)
	S.startCooldown(player, state, "InfiniteRotation", c.Cooldown, 2)
	S.lock(state, 0.4)
	S.fx("Ability", { Character = character, Act = 4, Move = "InfiniteRotation", Phase = "Release", Stage = stage, Direction = direction })
	blastNail(S, player, state, {
		Origin = S.origin(character, root, CFrame.new(0, 1.2, -2.5)),
		Direction = direction,
		Speed = c.Speed[stage],
		Radius = c.Radius[stage],
		Range = c.Range,
		Style = "Rotation",
		Charge = stage / 3,
		Damage = c.Damage[stage],
		Stun = c.Stun,
		Knockback = c.Knockback * (0.5 + stage / 6),
		Source = "TuskInfiniteRotation",
	}, c.ImpactRadius[stage], c.ImpactDamage[stage], "TuskInfiniteRotation")
end

local function infiniteRotationPress(S, player, state)
	local c = cfg.InfiniteRotation
	if not ready(S, player, state, "InfiniteRotation", 2) then
		return
	end
	local charge = S.beginCharge(player, state, "InfiniteRotation", 2, c.WalkSpeedMultiplier)
	local token = charge.Token
	task.delay(c.MaxHold, function()
		if state.Charging and state.Charging.Token == token then
			infiniteRotationRelease(S, player, state, nil)
		end
	end)
end

local function goldenPursuit(S, player, state, aim)
	local c = cfg.GoldenPursuit
	if not ready(S, player, state, "GoldenPursuit", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	-- Stop just short of the first enemy along the rush line.
	local distance = c.Distance
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, c.Distance + 4, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			local offset = tr.Position - root.Position
			local along = offset:Dot(direction)
			local side = (offset - direction * along).Magnitude
			if along > 0 and side < 5 and along - 3 < distance then
				distance = math.max(along - 3, 3)
			end
		end
	end
	local destination = Moves.safeStep(character, root, direction, distance)
	if not destination then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "GoldenPursuit", c.Cooldown, 3)
	local gather = 0.2
	S.lock(state, gather + c.Hits * c.HitInterval + 0.45)
	local life = state.Life
	local from = root.Position
	S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Gather", Direction = direction })
	task.delay(gather, function()
		if not S.stillValid(player, state, life) then
			return
		end
		character:SetAttribute(S.Adapter.Settings.IFrameAttribute, true)
		character:PivotTo(CFrame.lookAt(destination, destination + direction))
		S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Dash", From = from, To = destination })
		task.delay(0.15, function()
			if character.Parent then
				character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
			end
		end)
		local front = destination + direction * 3
		for i = 1, c.Hits do
			task.delay(i * c.HitInterval, function()
				if state.Life ~= life then
					return
				end
				Moves.aoe(S, player, front, 6, { Damage = c.HitDamage, Stun = 0.4, Knockback = 3, Direction = direction, Source = "TuskGoldenPursuit" }, 3)
				S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Hit", Position = front, Index = i })
			end)
		end
		task.delay((c.Hits + 1) * c.HitInterval, function()
			if state.Life ~= life then
				return
			end
			Moves.aoe(S, player, front, c.FinalRadius, { Damage = c.FinalDamage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = direction, Source = "TuskGoldenPursuit" }, 6)
			S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Final", Position = front, Radius = c.FinalRadius })
		end)
	end)
end

function Act4.Ability(S, player, state, slot, phase, aim)
	if slot == 1 and phase == "Press" then
		goldenSpinNail(S, player, state, aim)
	elseif slot == 2 then
		if phase == "Press" then
			infiniteRotationPress(S, player, state)
		else
			infiniteRotationRelease(S, player, state, aim)
		end
	elseif slot == 3 and phase == "Press" then
		goldenPursuit(S, player, state, aim)
	end
end

function Act4.CancelCharge(S, player, state)
	local charge = S.endCharge(player, state)
	if charge then
		S.startCooldown(player, state, charge.Move, 2, charge.Slot)
		S.fx("Ability", { Character = state.Character, Act = 4, Move = charge.Move, Phase = "Cancel" })
	end
end

-- INFINITE ROTATION (ultimate)
function Act4.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.lock(state, u.Windup + 0.6)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = 4, Phase = "Start", Windup = u.Windup, Direction = direction })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local _, _, r = alive(S, player)
		S.fx("Ultimate", { Character = character, Act = 4, Phase = "Release", Position = r.Position, Direction = direction })
		blastNail(S, player, state, {
			Origin = S.origin(character, r, CFrame.new(0, 2, -4)),
			Direction = direction,
			Speed = u.Speed,
			Radius = u.ProjectileRadius,
			Range = u.Range,
			Style = "InfiniteUlt",
			Charge = 1,
			Damage = u.Damage,
			Stun = u.Stun,
			Knockback = u.Knockback,
			Launch = u.Launch,
			Source = "TuskInfiniteRotationUlt",
		}, u.BlastRadius, u.BlastDamage, "TuskInfiniteRotationUlt")
		S.finishUltimate(player, state) -- final form: no evolution (Studio refills the meter)
	end)
end

function Act4.Cleanup(S, player, state)
	if state.Charging then
		S.endCharge(player, state)
	end
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
	end
end

return Act4
end

-- ======================================================================
-- MODULE: TuskActRegistry
-- ======================================================================
__modules["TuskActRegistry"] = function()
--[[
	TuskActRegistry  (ReplicatedStorage.SpinShared.TuskActRegistry)

	The list of Tusk Acts: names, slot labels, themes and whether each
	Act is implemented. The server refuses to equip an Act whose
	Implemented flag is false, and the menu shows it as IN DEVELOPMENT
	(locked, not a fake button).

	To add an Act: create ServerScriptService.SpinServer.TuskActs.TuskActN,
	add its client choreography in SpinClient.TuskActVFX.ActN, then set
	Implemented = true here.
]]

local TuskActRegistry = {}

TuskActRegistry.Acts = {
	[1] = {
		Name = "TUSK ACT 1",
		Tagline = "The beginning of Spin",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(90, 230, 255), Secondary = Color3.fromRGB(40, 120, 255) },
		M1 = "NAIL COMBO",
		Abilities = { "NAIL SHOT", "NAIL BARRAGE", "SPINNING NAIL" },
		AbilityKinds = { "Press", "Press", "Hold" }, -- Hold = charge on press, fire on release
		Ultimate = "TUSK AWAKENING",
		Next = 2, -- the ultimate awakens Tusk to this Act
	},
	[2] = {
		Name = "TUSK ACT 2",
		Tagline = "The Golden Ratio",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(70, 200, 255), Secondary = Color3.fromRGB(30, 80, 220) },
		M1 = "GOLDEN COMBO",
		Abilities = { "GOLDEN RATIO NAIL", "UNDERGROUND PURSUIT", "GOLDEN SPIRAL" },
		AbilityKinds = { "Press", "Press", "Press" },
		Next = 3,
		Ultimate = "GOLDEN RATIO STORM",
	},
	[3] = {
		Name = "TUSK ACT 3",
		Tagline = "Master of spatial movement",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(60, 140, 255), Secondary = Color3.fromRGB(20, 40, 160) },
		M1 = "WORMHOLE STRIKES",
		Abilities = { "DIMENSIONAL STEP", "SPATIAL PURSUIT", "DIMENSIONAL BREAK" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "INFINITE DIMENSION",
		Next = 4,
	},
	[4] = {
		Name = "TUSK ACT 4",
		Tagline = "Infinite Rotation",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(255, 200, 70), Secondary = Color3.fromRGB(20, 40, 160) },
		M1 = "INFINITE BARRAGE",
		Abilities = { "GOLDEN SPIN NAIL", "INFINITE ROTATION", "GOLDEN PURSUIT" },
		AbilityKinds = { "Press", "Hold", "Press" },
		Ultimate = "INFINITE ROTATION",
		Next = nil, -- final form
	},
	-- Gyro Zeppeli: a separate character that reuses the same ability system.
	[5] = {
		Name = "GYRO ZEPPELI",
		Character = "Gyro",
		Tagline = "Steel Ball master",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(120, 220, 95), Secondary = Color3.fromRGB(40, 120, 50) },
		M1 = "STEEL BALL COMBO",
		Abilities = { "STEEL BALL THROW", "SPIN TORNADO", "SPIN VIBRATION" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "BALL BREAKER",
		Next = nil,
		Module = "GyroZeppeli", -- server moves
		ClientModule = "Gyro", -- client visuals (TuskActVFX.Gyro)
		CardTitle = "STEEL BALL USER",
	},
	-- Diego Brando: Scary Monsters (dinosaur Stand). Same ability system.
	[6] = {
		Name = "SCARY MONSTERS",
		Character = "Diego",
		Tagline = "Dinosaur Stand",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(80, 210, 220), Secondary = Color3.fromRGB(35, 60, 190) },
		M1 = "CLAW COMBO",
		Abilities = { "RAPTOR POUNCE", "DINO INFECTION", "SCARY MONSTERS" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "RAPTOR PACK",
		Next = nil,
		Module = "DiegoBrando", -- server moves
		ClientModule = "Diego", -- client visuals (TuskActVFX.Diego)
		CardTitle = "STAND  ·  SCARY MONSTERS",
		-- The HUD shows a timer on these slots while the attribute (server time) is in the future.
		Buffs = {
			{ Slot = 3, Attribute = "DinoModeUntil", Text = "ACTIVE" },
			{ Slot = 2, Attribute = "ThrallUntil", Text = "COMMAND" },
		},
	},
}

-- Which character an Act belongs to ("Johnny" for Tusk Acts 1-4).
function TuskActRegistry.characterOf(act)
	local info = TuskActRegistry.Acts[act]
	return info and info.Character or "Johnny"
end

-- The Act a character starts on.
TuskActRegistry.StartAct = { Johnny = 1, Gyro = 5, Diego = 6 }

function TuskActRegistry.get(act)
	return TuskActRegistry.Acts[act]
end

function TuskActRegistry.isImplemented(act)
	local info = TuskActRegistry.Acts[act]
	return info ~= nil and info.Implemented == true
end

return TuskActRegistry
end

-- ======================================================================
-- MODULE: TuskHitbox
-- ======================================================================
__modules["TuskHitbox"] = function()
--[[
	TuskHitbox  (ServerScriptService.SpinServer.TuskHitbox)
	Server-side spatial queries for melee and area attacks.
	Returns unique characters (models with a Humanoid), nearest first.
]]

local TuskHitbox = {}

local function characterFromPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end
TuskHitbox.characterFromPart = characterFromPart

local function collect(parts, attacker, origin, max)
	local seen, list = {}, {}
	for _, part in ipairs(parts) do
		local character = characterFromPart(part)
		if character and character ~= attacker and not seen[character] then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart")
			if humanoid and root and humanoid.Health > 0 then
				seen[character] = true
				table.insert(list, { Character = character, Distance = (root.Position - origin).Magnitude })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Distance < b.Distance
	end)
	local out = {}
	for i = 1, math.min(#list, max or #list) do
		out[i] = list[i].Character
	end
	return out
end

local function overlapParams(attacker)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = attacker and { attacker } or {}
	return params
end

function TuskHitbox.inBox(attacker, cframe, size, max)
	local parts = workspace:GetPartBoundsInBox(cframe, size, overlapParams(attacker))
	return collect(parts, attacker, cframe.Position, max)
end

function TuskHitbox.inRadius(attacker, position, radius, max)
	local parts = workspace:GetPartBoundsInRadius(position, radius, overlapParams(attacker))
	return collect(parts, attacker, position, max)
end

-- True if nothing but characters blocks the line between the two points.
function TuskHitbox.lineOfSight(fromPos, toPos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	params.IgnoreWater = true
	local offset = toPos - fromPos
	local result = workspace:Raycast(fromPos, offset, params)
	if not result then
		return true
	end
	return characterFromPart(result.Instance) ~= nil
end

return TuskHitbox
end

-- ======================================================================
-- MODULE: TuskMoves
-- ======================================================================
__modules["TuskMoves"] = function()
--[[
	TuskMoves  (ServerScriptService.SpinServer.TuskMoves)

	Shared server building blocks for every Tusk Act, so each Act module
	only describes what makes it different:
	  m1(...)          generic 4-hit combo (portals, multi-hits, AoE finisher, nail hits)
	  findTarget(...)  nearest valid enemy in a cone with line of sight
	  aoe(...)         radius hit with line-of-sight checks
	  boxHit(...)      oriented box hit
	  safeStep(...)    validated short teleport / dash destination
	  nail(...)        fire a nail with standard damage handling
	All damage still goes through TuskService.hit -> CombatAdapter.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local TuskMoves = {}
TuskMoves.HAND = CFrame.new(0.9, 0.55, -1.5)

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 1e-3 and f.Unit or Vector3.new(0, 0, -1)
end
TuskMoves.flat = flat

---------------------------------------------------------------------------
-- Targeting and area damage
---------------------------------------------------------------------------
function TuskMoves.findTarget(S, character, root, range, coneDegrees, direction)
	local look = flat(direction or root.CFrame.LookVector)
	local cosLimit = math.cos(math.rad((coneDegrees or 360) / 2))
	local best, bestDistance
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, range)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and S.Adapter.canBeHit(nil, target) then
			local offset = tr.Position - root.Position
			local f = Vector3.new(offset.X, 0, offset.Z)
			if f.Magnitude < 0.5 or f.Unit:Dot(look) >= cosLimit then
				if S.Hitbox.lineOfSight(root.Position, tr.Position, { character, target }) then
					if not bestDistance or offset.Magnitude < bestDistance then
						best, bestDistance = target, offset.Magnitude
					end
				end
			end
		end
	end
	return best
end

-- Damage everyone in a radius (line of sight from `center`). Returns hit count.
function TuskMoves.aoe(S, player, center, radius, info, maxTargets, exclude)
	local character = player.Character
	local count = 0
	for _, target in ipairs(S.Hitbox.inRadius(character, center, radius, maxTargets or 8)) do
		if not (exclude and exclude[target]) then
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.Hitbox.lineOfSight(center, tr.Position, { character, target }) then
				local hitInfo = table.clone(info)
				hitInfo.Direction = info.Direction or (tr.Position - center)
				hitInfo.Position = tr.Position
				if S.hit(player, target, hitInfo) then
					count = count + 1
				end
			end
		end
	end
	return count
end

function TuskMoves.boxHit(S, player, cframe, size, info, maxTargets)
	local character, _, root = alive(S, player)
	local count, hitSet = 0, {}
	if not character then
		return 0, hitSet
	end
	for _, target in ipairs(S.Hitbox.inBox(character, cframe, size, maxTargets or 3)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and S.Hitbox.lineOfSight(root.Position, tr.Position, { character, target }) then
			local hitInfo = table.clone(info)
			hitInfo.Direction = info.Direction or (tr.Position - root.Position)
			hitInfo.Position = tr.Position
			if S.hit(player, target, hitInfo) then
				count = count + 1
				hitSet[target] = true
			end
		end
	end
	return count, hitSet
end

---------------------------------------------------------------------------
-- Movement
---------------------------------------------------------------------------
-- Validated destination for a short teleport/dash along a flat direction.
-- Stops before walls, needs ground below, and free space to stand in.
function TuskMoves.safeStep(character, root, direction, distance)
	local dir = flat(direction)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild("SpinClientFX") }
	local wall = workspace:Raycast(root.Position, dir * distance, params)
	local travel = wall and (wall.Distance - 2.5) or distance
	if travel < 3 then
		return nil
	end
	local groundHere = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	local height = groundHere and (root.Position.Y - groundHere.Position.Y) or 3
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	-- Walk back from the furthest point until a valid spot is found.
	local d = travel
	while d >= 3 do
		local probe = root.Position + dir * d
		local ground = workspace:Raycast(probe + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), params)
		if ground then
			local stand = Vector3.new(probe.X, ground.Position.Y + height, probe.Z)
			local blocked = false
			for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(stand), Vector3.new(2, 4.5, 2), overlap)) do
				if part.CanCollide then
					blocked = true
					break
				end
			end
			if not blocked then
				return stand
			end
		end
		d = d - 2
	end
	return nil
end

function TuskMoves.groundBelow(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position or position
end

---------------------------------------------------------------------------
-- Nails
---------------------------------------------------------------------------
--[[ spec: Origin, Direction, Speed, Radius, Range, Style, Charge,
          Damage, Stun, Knockback, Launch, Source, OnEnd ]]
function TuskMoves.nail(S, player, state, spec)
	return S.fireNail(player, state, {
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius or 0.7,
		Range = spec.Range,
		Style = spec.Style,
		Charge = spec.Charge,
		OnHit = function(target, position)
			S.hit(player, target, {
				Damage = spec.Damage,
				Stun = spec.Stun,
				Knockback = spec.Knockback,
				Launch = spec.Launch,
				Direction = spec.Direction,
				Position = position,
				Source = spec.Source or "TuskNail",
			})
		end,
		OnEnd = spec.OnEnd,
	})
end

---------------------------------------------------------------------------
-- Generic M1 combo
---------------------------------------------------------------------------
--[[ m1cfg.Hits[i] fields: Damage, Stun, Knockback, Launch,
     Portal (cosmetic), Repeat + RepeatInterval (multi-hit), AoeRadius
     (finisher hits a radius instead of the box), ShockwaveRadius (visual),
     Projectile = { Speed, Radius, Range } (nail instead of melee) ]]
function TuskMoves.m1(S, player, state, aim, m1cfg, act)
	if S.isBusy(state) or state.Charging then
		return
	end
	local now = os.clock()
	if now - state.LastM1 > m1cfg.ResetAfter then
		state.Combo = 0
	end
	local index = state.Combo + 1
	state.Combo = index >= 4 and 0 or index
	state.LastM1 = now
	local hit = m1cfg.Hits[index]
	local repeatTime = (hit.Repeat or 1) > 1 and (hit.Repeat - 1) * (hit.RepeatInterval or 0.08) or 0
	S.lock(state, (index == 4 and m1cfg.EndLag or m1cfg.Interval) + repeatTime)

	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("M1", { Character = character, Act = act, Index = index, Portal = hit.Portal == true, Repeat = hit.Repeat })

	local function strike(isLast)
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		if hit.Projectile then
			TuskMoves.nail(S, player, state, {
				Origin = S.origin(char, r, TuskMoves.HAND),
				Direction = direction,
				Speed = hit.Projectile.Speed,
				Radius = hit.Projectile.Radius,
				Range = hit.Projectile.Range,
				Style = "M1",
				Damage = hit.Damage,
				Stun = hit.Stun,
				Knockback = hit.Knockback,
				Source = "TuskM1",
			})
			return
		end
		local boxCF = r.CFrame * CFrame.new(0, 0, -m1cfg.HitboxForward)
		local info = { Damage = hit.Damage, Stun = hit.Stun, Knockback = hit.Knockback, Launch = hit.Launch, Source = "TuskM1" }
		local landed
		if hit.AoeRadius and isLast then
			landed = TuskMoves.aoe(S, player, boxCF.Position, hit.AoeRadius, info, 5) > 0
		else
			landed = TuskMoves.boxHit(S, player, boxCF, m1cfg.HitboxSize, info, m1cfg.MaxTargets) > 0
		end
		if index == 4 and isLast then
			S.fx("M1Finisher", { Character = char, Act = act, Position = boxCF.Position, Radius = hit.ShockwaveRadius or 7, Hit = landed })
		end
	end

	local count = hit.Repeat or 1
	for i = 1, count do
		task.delay(m1cfg.Windup + (i - 1) * (hit.RepeatInterval or 0.08), function()
			strike(i == count)
		end)
	end
end

-- Ring of points around a center (portal placement shared by server and client payloads).
function TuskMoves.ring(center, count, radius, yaw, heightA, heightB)
	local points = {}
	for i = 1, count do
		local angle = (yaw or 0) + (i - 1) / count * math.pi * 2
		local h = (i % 2 == 0) and (heightB or 6) or (heightA or 4)
		table.insert(points, center + Vector3.new(math.cos(angle) * radius, h, math.sin(angle) * radius))
	end
	return points
end

TuskMoves.Config = TuskConfig
return TuskMoves
end

-- ======================================================================
-- MODULE: TuskService
-- ======================================================================
__modules["TuskService"] = function()
--[[
	TuskService  (ServerScriptService.SpinServer.TuskService)

	Server brain for Tusk (the "TuskController" of the design doc):
	  * equips / switches Acts (validated against TuskActRegistry and
	    TuskConfig.Progression)
	  * routes every TuskRequest to the active Act module or TuskSneakService
	  * owns per-player state, action locks, cooldowns, the ultimate meter
	  * gives Act modules safe helpers: hit(), fireNail(), aim(), origin()...

	Request protocol (client -> server, TuskRequest:FireServer):
	  "Select", act          equip Act n (0 = unequip)
	  "M1", aim              basic attack (sneak attack while sneaking)
	  "Ability", slot, phase, aim   slot 1..3, phase "Press" | "Release"
	  "Ultimate", aim
	  "Sneak", on

	Attributes it sets (replicated; clients render from them):
	  Player.TuskUlt (0..Max)  Character.TuskAct  Character.TuskCharge
	  Character.TuskAwakened   Character.Armored  (Sneak ones: see TuskSneakService)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local Net = __require("Net")
local Adapter = __require("CombatAdapter")
local Cooldowns = __require("CooldownService")
local Projectiles = __require("ProjectileService")
local Hitbox = __require("TuskHitbox")

local Request = Net.get("TuskRequest")
local FX = Net.get("TuskFX")

local TuskService = {}
TuskService.Hitbox = Hitbox
TuskService.Adapter = Adapter

local states = {} -- [player] = state
local rate = {}
local actModules = {}
local Sneak -- set in init (circular dependency)

local RATE_LIMIT = 24 -- requests per second

---------------------------------------------------------------------------
-- Helpers for Act modules
---------------------------------------------------------------------------
function TuskService.getState(player)
	return states[player]
end

function TuskService.fx(name, data)
	FX:FireAllClients(name, data)
end

function TuskService.tell(player, kind, data)
	data = data or {}
	data.Kind = kind
	FX:FireClient(player, "TuskState", data)
end

function TuskService.isBusy(state)
	return os.clock() < state.LockUntil
end

function TuskService.lock(state, seconds)
	state.LockUntil = math.max(state.LockUntil, os.clock() + seconds)
end

local function cooldownKey(state, name)
	return "Tusk" .. state.Act .. "_" .. name
end

-- Returns true if ready; otherwise tells the client how long is left.
function TuskService.cooldownReady(player, state, name, slot)
	local remaining = Cooldowns.remaining(player, cooldownKey(state, name))
	if remaining > 0 then
		TuskService.tell(player, "Denied", { Reason = "Cooldown", Slot = slot, Remaining = remaining })
		return false
	end
	return true
end

function TuskService.startCooldown(player, state, name, seconds, slot)
	Cooldowns.start(player, cooldownKey(state, name), seconds)
	TuskService.tell(player, "Cooldown", { Slot = slot, Duration = seconds })
end

-- A token that changes on death / Act switch, so delayed actions can
-- check they still belong to the same "life".
function TuskService.stillValid(player, state, life, allowStunned)
	if states[player] ~= state or state.Life ~= life then
		return false
	end
	if allowStunned then
		return Adapter.getAlive(player) ~= nil
	end
	return Adapter.canAct(player)
end

function TuskService.aim(aim, root)
	local fallback = root.CFrame.LookVector
	if typeof(aim) ~= "Vector3" or aim ~= aim or aim.Magnitude < 1e-3 or aim.Magnitude > 1e4 then
		return fallback
	end
	if aim.X ~= aim.X or aim.Y ~= aim.Y or aim.Z ~= aim.Z then
		return fallback
	end
	local unit = aim.Unit
	local y = math.clamp(unit.Y, -0.8, 0.8)
	local flat = Vector3.new(unit.X, 0, unit.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(fallback.X, 0, fallback.Z)
	end
	flat = flat.Unit * math.sqrt(1 - y * y)
	return Vector3.new(flat.X, y, flat.Z).Unit
end

-- Spawn point for attacks, pulled back to the root if a wall is in the way.
function TuskService.origin(character, root, offset)
	local desired = (root.CFrame * offset).Position
	if Hitbox.lineOfSight(root.Position, desired, { character }) then
		return desired
	end
	return root.Position
end

function TuskService.addUlt(player, amount)
	local max = TuskConfig.Ultimate.MaxMeter
	local state = states[player]
	local byAct = TuskConfig.Ultimate.GainByAct
	if state and state.Act and byAct and byAct[state.Act] then
		amount = amount * byAct[state.Act]
	end
	local current = player:GetAttribute("TuskUlt") or 0
	player:SetAttribute("TuskUlt", math.clamp(current + amount, 0, max))
end

function TuskService.spendUlt(player)
	local max = TuskConfig.Ultimate.MaxMeter
	if (player:GetAttribute("TuskUlt") or 0) < max then
		TuskService.tell(player, "Denied", { Reason = "UltNotReady" })
		return false
	end
	-- Each Act must be played for a while before the next awakening.
	local state = states[player]
	local wait = TuskConfig.Ultimate.MinSecondsPerAct or 0
	if state and state.ActSince and os.clock() - state.ActSince < wait then
		TuskService.tell(player, "Denied", { Reason = "TooSoon", Remaining = wait - (os.clock() - state.ActSince) })
		return false
	end
	player:SetAttribute("TuskUlt", 0)
	return true
end

-- All Tusk damage goes through here: CombatAdapter + ultimate meter.
function TuskService.hit(player, targetCharacter, info)
	local ok, damage = Adapter.dealHit(player, targetCharacter, info)
	if ok then
		TuskService.addUlt(player, (damage or 0) * TuskConfig.Ultimate.GainPerDamage)
	end
	return ok
end

-- Server projectile with a Tusk nail visual.
function TuskService.fireNail(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "TuskNail",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = {
			Act = state.Act,
			Style = spec.Style or "Shot",
			Charge = spec.Charge or 0,
			Awakened = state.Awakened == true,
			Stage = spec.Stage,
		},
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Server projectile with a Steel Ball visual (Gyro).
function TuskService.fireBall(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "GyroBall",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = { Style = spec.Style or "Throw", Scale = spec.Scale, Bounce = spec.Bounce },
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
	})
end

-- Charge helpers (hold abilities): sets the replicated TuskCharge attribute.
function TuskService.beginCharge(player, state, move, slot, multiplier)
	local character, humanoid = Adapter.getAlive(player)
	state.Charging = { Move = move, Slot = slot, Start = os.clock(), Token = {} }
	Adapter.setMoveModifier(humanoid, "TuskCharge", multiplier or 1)
	character:SetAttribute("TuskCharge", workspace:GetServerTimeNow())
	character:SetAttribute("TuskChargeMove", move)
	return state.Charging
end

function TuskService.endCharge(player, state)
	local charge = state.Charging
	state.Charging = nil
	local character = state.Character
	if character then
		character:SetAttribute("TuskCharge", nil)
		character:SetAttribute("TuskChargeMove", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Adapter.setMoveModifier(humanoid, "TuskCharge", nil)
		end
	end
	return charge
end

---------------------------------------------------------------------------
-- Equip / switch
---------------------------------------------------------------------------
local function cleanupAct(player, state)
	state.Life = state.Life + 1
	local module = state.Act and actModules[state.Act]
	if module and module.Cleanup then
		pcall(module.Cleanup, TuskService, player, state)
	end
	TuskService.endCharge(player, state)
	if Sneak then
		Sneak.exit(player, state, false)
	end
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute("TuskAwakened", nil)
	end
	state.Awakened = false
	state.Combo = 0
	state.LockUntil = 0
end

local function isUnlocked(player, act)
	local p = TuskConfig.Progression
	if p.Mode == "Awaken" then
		-- Acts are reached through ultimates; the menu is a Studio testing aid only.
		return RunService:IsStudio() and p.StudioMenu == true
	end
	if p.Mode == "Unlock" then
		return p.IsUnlocked ~= nil and p.IsUnlocked(player, act) == true
	end
	return true
end

function TuskService.select(player, act, internal)
	if typeof(act) ~= "number" or act ~= math.floor(act) then
		return
	end
	local state = states[player]
	if not state then
		return
	end
	if act == 0 then
		cleanupAct(player, state)
		state.Act = nil
		if state.Character then
			state.Character:SetAttribute("TuskAct", nil)
		end
		TuskService.tell(player, "Equipped", { Act = 0 })
		return
	end
	if not Registry.isImplemented(act) or not actModules[act] then
		TuskService.tell(player, "Denied", { Reason = "NotAvailable" })
		return
	end
	if not internal and not isUnlocked(player, act) then
		TuskService.tell(player, "Denied", { Reason = "Locked" })
		return
	end
	if state.Act == act then
		return
	end
	if not internal and (os.clock() - state.LastSwitch < TuskConfig.Progression.SwitchCooldown or TuskService.isBusy(state)) then
		TuskService.tell(player, "Denied", { Reason = "SwitchCooldown" })
		return
	end
	cleanupAct(player, state)
	state.Act = act
	state.LastSwitch = os.clock()
	TuskService.markActStart(player, state)
	player:SetAttribute("TuskSelectedAct", act)
	if state.Character then
		state.Character:SetAttribute("TuskAct", act)
	end
	TuskService.tell(player, "Equipped", { Act = act })
end

-- Remember when the current Act began (the HUD shows the lock timer).
function TuskService.markActStart(player, state)
	state.ActSince = os.clock()
	player:SetAttribute("TuskActSince", workspace:GetServerTimeNow())
end

-- Awakening: move straight to another Act (no menu rules, no switch cooldown).
function TuskService.evolve(player, state, toAct)
	if not Registry.isImplemented(toAct) or not actModules[toAct] then
		return
	end
	local from = state.Act
	cleanupAct(player, state)
	state.Act = toAct
	TuskService.markActStart(player, state)
	player:SetAttribute("TuskSelectedAct", toAct)
	if state.Character then
		state.Character:SetAttribute("TuskAct", toAct)
	end
	TuskService.fx("Evolve", { Character = state.Character, From = from, To = toAct })
	TuskService.tell(player, "Evolved", { Act = toAct })
end

-- Called by every Act's ultimate when its attack has finished.
function TuskService.finishUltimate(player, state)
	local info = Registry.get(state.Act)
	if TuskConfig.Progression.Mode == "Awaken" and info and info.Next then
		TuskService.evolve(player, state, info.Next)
	end
	if RunService:IsStudio() and TuskConfig.Ultimate.StudioRefill then
		player:SetAttribute("TuskUlt", TuskConfig.Ultimate.MaxMeter)
	end
end

---------------------------------------------------------------------------
-- Request routing
---------------------------------------------------------------------------
local function rateLimited(player)
	local r = rate[player]
	local now = os.clock()
	if not r or now - r.Start >= 1 then
		rate[player] = { Start = now, Count = 1 }
		return false
	end
	r.Count = r.Count + 1
	return r.Count > RATE_LIMIT
end

local function onRequest(player, action, a, b, c)
	if rateLimited(player) or typeof(action) ~= "string" then
		return
	end
	if action == "Select" then
		TuskService.select(player, a)
		return
	end
	if action == "Character" then
		-- Character dropdown: "Johnny" (Tusk, starts at Act 1) or "Gyro" (Steel Balls).
		local st = states[player]
		local start = typeof(a) == "string" and Registry.StartAct[a]
		if not st or not start then
			return
		end
		if st.Act and Registry.characterOf(st.Act) == a then
			return -- already playing that character
		end
		if TuskService.isBusy(st) or st.Charging or st.Burrowed then
			return
		end
		TuskService.select(player, start, true)
		return
	end
	local state = states[player]
	if not state or not state.Act or not state.Character then
		return
	end
	local module = actModules[state.Act]

	local isJohnny = Registry.characterOf(state.Act) == "Johnny"
	if action == "Sneak" then
		if isJohnny then -- Tusk Sneak is Johnny's
			Sneak.toggle(player, state, a == true)
		end
		return
	end
	if state.Burrowed then
		return
	end

	-- Releasing a held ability is allowed even mid-lock; everything else needs a free player.
	if action == "Ability" and b == "Release" then
		if typeof(a) == "number" and module.Ability then
			module.Ability(TuskService, player, state, a, "Release", c)
		end
		return
	end
	if not Adapter.canAct(player) then
		return
	end

	if action == "M1" then
		if state.Sneaking then
			Sneak.attack(player, state)
		else
			module.M1(TuskService, player, state, a)
		end
	elseif action == "Ability" then
		if typeof(a) ~= "number" or (a ~= 1 and a ~= 2 and a ~= 3) then
			return
		end
		if state.Sneaking then
			Sneak.exit(player, state, true)
		end
		module.Ability(TuskService, player, state, a, "Press", c)
	elseif action == "Ultimate" then
		if state.Sneaking then
			Sneak.exit(player, state, true)
		end
		module.Ultimate(TuskService, player, state, a)
	end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local function onCharacter(player, character)
	local state = states[player]
	if not state then
		return
	end
	cleanupAct(player, state)
	state.Character = character
	state.Burrowed = false
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or states[player] ~= state or state.Character ~= character then
		return
	end
	local progression = TuskConfig.Progression
	if state.Act and progression.Mode == "Awaken" and progression.ResetOnDeath then
		-- Back to the character's first Act after dying (Johnny -> Act 1; Gyro stays Gyro).
		state.Act = Registry.StartAct[Registry.characterOf(state.Act)] or progression.DefaultAct
		TuskService.markActStart(player, state)
	end
	if state.Act then
		character:SetAttribute("TuskAct", state.Act)
	end
	humanoid.Died:Connect(function()
		if state.Character == character then
			cleanupAct(player, state)
		end
	end)
	-- Getting stunned interrupts charges and breaks sneak (counterplay).
	character:GetAttributeChangedSignal(Adapter.Settings.StunAttribute):Connect(function()
		if not Adapter.isStunned(character) or state.Character ~= character then
			return
		end
		if state.Charging then
			local module = state.Act and actModules[state.Act]
			if module and module.CancelCharge then
				module.CancelCharge(TuskService, player, state)
			else
				TuskService.endCharge(player, state)
			end
			TuskService.tell(player, "Interrupted", {})
		end
		if state.Sneaking then
			Sneak.exit(player, state, true)
		end
	end)
end

local function onPlayer(player)
	states[player] = {
		Act = nil,
		Character = nil,
		Life = 0,
		Combo = 0,
		LastM1 = 0,
		LockUntil = 0,
		LastSwitch = -math.huge,
		Charging = nil,
		Sneaking = false,
		Burrowed = false,
		Awakened = false,
	}
	player:SetAttribute("TuskUlt", (RunService:IsStudio() and TuskConfig.Ultimate.StudioStartFull) and TuskConfig.Ultimate.MaxMeter or 0)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	if TuskConfig.Progression.AutoEquip then
		task.defer(TuskService.select, player, TuskConfig.Progression.DefaultAct, true)
	end
end

function TuskService.init()
	for act, info in pairs(Registry.Acts) do
		local name = info.Module or ("TuskAct" .. act)
		if Registry.isImplemented(act) and __hasModule(name) then
			actModules[act] = __require(name)
		end
	end
	Sneak = __require("TuskSneakService")
	Sneak.init(TuskService)

	Request.OnServerEvent:Connect(onRequest)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		if state then
			cleanupAct(player, state)
		end
		states[player] = nil
		rate[player] = nil
	end)
end

return TuskService
end

-- ======================================================================
-- MODULE: TuskSneakService
-- ======================================================================
__modules["TuskSneakService"] = function()
--[[
	TuskSneakService  (ServerScriptService.SpinServer.TuskSneakService)

	Tusk Sneak (every Act): a crouched, slowed stalking state, plus the
	Sneak Attack (M1 while sneaking):
	  1. Tusk sinks into the ground (Burrow): invisible and briefly untargetable
	  2. a distortion warning appears under the target (WarningTime before emergence)
	  3. Tusk emerges behind the target at a server-validated safe spot
	  4. surprise hit + launch, finished with a blue shockwave

	Counterplay: the warning is visible and audible, a target that moves
	MaxTargetDrift studs away is missed, getting hit breaks sneak, and both
	sneak and the attack have cooldowns.

	Character attributes: TuskSneaking, TuskBurrowed.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Adapter = __require("CombatAdapter")
local Cooldowns = __require("CooldownService")
local Hitbox = __require("TuskHitbox")

local TuskSneakService = {}
local S -- TuskService

local cfg = TuskConfig.Sneak

function TuskSneakService.init(service)
	S = service
end

function TuskSneakService.exit(player, state, applyCooldown)
	if not state.Sneaking then
		return
	end
	state.Sneaking = false
	state.SneakToken = nil
	local character = state.Character
	if character then
		character:SetAttribute("TuskSneaking", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Adapter.setMoveModifier(humanoid, "TuskSneak", nil)
		end
	end
	if applyCooldown then
		Cooldowns.start(player, "TuskSneak", cfg.Cooldown)
		S.tell(player, "SneakCooldown", { Duration = cfg.Cooldown })
	end
end

function TuskSneakService.toggle(player, state, on)
	if not on then
		TuskSneakService.exit(player, state, true)
		return
	end
	if state.Sneaking or state.Charging or S.isBusy(state) or not Adapter.canAct(player) then
		return
	end
	local remaining = Cooldowns.remaining(player, "TuskSneak")
	if remaining > 0 then
		S.tell(player, "Denied", { Reason = "SneakCooldown", Remaining = remaining })
		return
	end
	local character, humanoid = Adapter.getAlive(player)
	state.Sneaking = true
	local token = {}
	state.SneakToken = token
	character:SetAttribute("TuskSneaking", true)
	Adapter.setMoveModifier(humanoid, "TuskSneak", cfg.WalkSpeedMultiplier)
	task.delay(cfg.MaxDuration, function()
		if state.SneakToken == token then
			TuskSneakService.exit(player, state, true)
		end
	end)
end

-- Nearest enemy in front, in range, with line of sight.
local function findTarget(character, root, range, coneDegrees)
	range = range or cfg.Attack.Range
	coneDegrees = coneDegrees or cfg.Attack.ConeDegrees
	local best, bestDistance
	local cosLimit = math.cos(math.rad(coneDegrees / 2))
	for _, target in ipairs(Hitbox.inRadius(character, root.Position, range)) do
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if targetRoot and Adapter.canBeHit(nil, target) then
			local offset = targetRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			if flat.Magnitude > 0.1 and flat.Unit:Dot(look.Unit) >= cosLimit then
				if Hitbox.lineOfSight(root.Position, targetRoot.Position, { character, target }) then
					if not bestDistance or offset.Magnitude < bestDistance then
						best, bestDistance = target, offset.Magnitude
					end
				end
			end
		end
	end
	return best
end

-- Safe emergence point near the target: behind first, then the sides, then in front.
-- Must have clear line of sight from the target, solid ground below and free space.
TuskSneakService.findTarget = findTarget

local function emergePoint(attacker, target, distance)
	local targetRoot = target.HumanoidRootPart
	local d = distance or cfg.Attack.EmergeDistance
	local candidates = {
		targetRoot.CFrame * CFrame.new(0, 0, d),
		targetRoot.CFrame * CFrame.new(d, 0, 0),
		targetRoot.CFrame * CFrame.new(-d, 0, 0),
		targetRoot.CFrame * CFrame.new(0, 0, -d),
	}
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { attacker, target }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { attacker, target }
	for _, cf in ipairs(candidates) do
		local pos = cf.Position
		if Hitbox.lineOfSight(targetRoot.Position, pos, { attacker, target }) then
			local ground = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), rayParams)
			if ground then
				local standPos = ground.Position + Vector3.new(0, 3, 0)
				local blocking = workspace:GetPartBoundsInBox(CFrame.new(standPos), Vector3.new(2, 4.5, 2), overlap)
				local solid = false
				for _, part in ipairs(blocking) do
					if part.CanCollide then
						solid = true
						break
					end
				end
				if not solid then
					return standPos
				end
			end
		end
	end
	return nil
end

function TuskSneakService.attack(player, state)
	local a = cfg.Attack
	if S.isBusy(state) or state.Charging then
		return
	end
	local remaining = Cooldowns.remaining(player, "TuskSneakAttack")
	if remaining > 0 then
		S.tell(player, "Denied", { Reason = "SneakAttackCooldown", Remaining = remaining })
		return
	end
	local character, _, root = Adapter.getAlive(player)
	local target = findTarget(character, root)
	if not target then
		Cooldowns.start(player, "TuskSneakAttack", a.FailCooldown)
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end

	TuskSneakService.exit(player, state, true)
	Cooldowns.start(player, "TuskSneakAttack", a.Cooldown)
	S.tell(player, "SneakAttackCooldown", { Duration = a.Cooldown })
	TuskSneakService.burrowStrike(player, state, target, a, "TuskSneakAttack")
end

--[[
	Burrow -> warning -> emerge behind the target -> hit + shockwave.
	Shared by the Sneak Attack and Act 2's Underground Pursuit.
	a = { BurrowTime, WarningTime, EmergeDistance, MaxTargetDrift, Range,
	      HitRadius, Damage, Stun, Knockback, Launch }
]]
function TuskSneakService.burrowStrike(player, state, target, a, source)
	local character, _, root = Adapter.getAlive(player)
	if not character then
		return
	end
	a = setmetatable(table.clone(a), { __index = cfg.Attack })
	S.lock(state, a.BurrowTime + 0.45)

	local life = state.Life
	local startPos = root.Position
	local targetStart = target.HumanoidRootPart.Position
	state.Burrowed = true
	character:SetAttribute("TuskBurrowed", true)
	character:SetAttribute(Adapter.Settings.IFrameAttribute, true)
	-- Anchor in place while underground so the hidden body can't wander.
	root.Anchored = true

	S.fx("SneakAttack", { Phase = "Burrow", Character = character, Position = startPos - Vector3.new(0, 2.8, 0), Target = target, BurrowTime = a.BurrowTime })

	local function surface()
		state.Burrowed = false
		if character.Parent then
			character:SetAttribute("TuskBurrowed", nil)
			character:SetAttribute(Adapter.Settings.IFrameAttribute, nil)
			if root.Parent then
				root.Anchored = false
			end
		end
	end

	task.delay(a.BurrowTime - a.WarningTime, function()
		if state.Life ~= life or not target.Parent then
			return
		end
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			S.fx("SneakAttack", { Phase = "Warning", Character = character, Target = target, Position = targetRoot.Position - Vector3.new(0, 2.8, 0), Duration = a.WarningTime })
		end
	end)

	task.delay(a.BurrowTime, function()
		if state.Life ~= life or not Adapter.getAlive(player) then
			surface()
			return
		end
		local targetRoot = target.Parent and target:FindFirstChild("HumanoidRootPart")
		local valid = targetRoot
			and Adapter.canBeHit(player, target)
			and (targetRoot.Position - targetStart).Magnitude <= a.MaxTargetDrift
			and (targetRoot.Position - startPos).Magnitude <= a.Range * 1.4
		local pos = valid and emergePoint(character, target, a.EmergeDistance) or nil

		surface()
		if not pos then
			-- Whiff: surface where we went under.
			S.fx("SneakAttack", { Phase = "Emerge", Character = character, Position = startPos - Vector3.new(0, 2.8, 0), Hit = false })
			return
		end
		local facing = Vector3.new(targetRoot.Position.X, pos.Y, targetRoot.Position.Z)
		character:PivotTo(CFrame.lookAt(pos, facing))
		S.fx("SneakAttack", { Phase = "Emerge", Character = character, Position = pos - Vector3.new(0, 2.8, 0), Hit = true })

		local hitAny = false
		for _, victim in ipairs(Hitbox.inRadius(character, pos, a.HitRadius, 3)) do
			local victimRoot = victim:FindFirstChild("HumanoidRootPart")
			if victimRoot and Hitbox.lineOfSight(pos, victimRoot.Position, { character, victim }) then
				local hit = S.hit(player, victim, {
					Damage = a.Damage,
					Stun = a.Stun,
					Knockback = a.Knockback,
					Launch = a.Launch,
					Direction = victimRoot.Position - pos,
					Position = victimRoot.Position,
					Source = source or "TuskSneakAttack",
				})
				hitAny = hitAny or hit
			end
		end
		S.fx("SneakAttack", { Phase = "Shockwave", Character = character, Position = pos - Vector3.new(0, 2.8, 0), Hit = hitAny })
	end)
end

return TuskSneakService
end

-- ======================================================================
-- MODULE: TuskStandModels
-- ======================================================================
__modules["TuskStandModels"] = function()
--[[
	TuskStandModels  (ReplicatedStorage.SpinShared.TuskStandModels)

	Builds the Tusk Stand for each Act. Built on each client (visual only),
	so Stands never cost server physics or replication.

	TuskStandModels.build(act, scale) -> model, rig
	  rig.Body           root part of the Stand (anchored by the caller)
	  rig.Joints[name]   = { Weld = Weld, Base = CFrame } for animated pieces
	                       (EarL, EarR, Leg1..Leg4). Animate with
	                       Weld.C0 = Base * rotation.
	  rig.NailPoint      Attachment where Tusk's nail energy gathers

	Act 1 (from the owner's reference): small pink egg-shaped body covered
	in gold stars, floppy ears, a big forehead star with a gold pin running
	to a yellow beak, heavy-lidded eyes and four thin legs ending in hearts.

	Using your own model instead: set its asset id in TuskConfig.StandModels
	(StandAssetLoader loads it into ReplicatedStorage.SpinAssets), or put a
	Model named "TuskAct1" in ReplicatedStorage.SpinAssets by hand. It is
	cloned, cleaned of scripts, welded, resized to the configured Height and
	gets the same floating motion (ears/legs only animate on built-in models).
]]

local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Blockify = __require("Blockify")

local TuskStandModels = {}

local colors = TuskConfig.Colors

local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "Ellipsoid" then
			p[k] = v
		end
	end
	if props.Ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere -- fits the part size, so any Size = ellipsoid
		mesh.Parent = p
	end
	p.Parent = model
	return p
end

-- Weld `p` to `body` at local CFrame `cf` (C0 can be animated later).
local function attach(body, p, cf)
	local w = Instance.new("Weld")
	w.Part0 = body
	w.Part1 = p
	w.C0 = cf
	w.Parent = p
	p.CFrame = body.CFrame * cf
	return w
end

-- Custom Stand model: ReplicatedStorage.SpinAssets.TuskActN (loaded by
-- StandAssetLoader or placed by hand) or SpinShared.Assets.TuskActN.
local function findCustom(act)
	local name = "TuskAct" .. act
	local rs = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
	local custom = rs and rs:FindFirstChild(name)
	if not custom then
		local assets = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
		custom = assets and assets:FindFirstChild(name)
	end
	return custom
end

local function override(act, scale)
	local custom = findCustom(act)
	if not custom then
		return nil
	end
	local clone = custom:Clone()
	if not clone:IsA("Model") then
		local wrapper = Instance.new("Model")
		clone.Parent = wrapper
		clone = wrapper
	end
	-- Safety + visual-only: no scripts, no collisions, no sounds playing.
	local parts = {}
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.Anchored = false
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		return nil
	end
	-- Root = the PrimaryPart, or the biggest part.
	local root = clone.PrimaryPart
	if not root or not root:IsDescendantOf(clone) then
		root = parts[1]
		for _, p in ipairs(parts) do
			if p.Size.Magnitude > root.Size.Magnitude then
				root = p
			end
		end
		clone.PrimaryPart = root
	end
	-- Weld every loose part to the root so the model moves as one piece.
	for _, p in ipairs(parts) do
		if p ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
		end
	end
	root.Anchored = true

	-- Size and facing from TuskConfig.StandModels.
	local settings = TuskConfig.StandModels and TuskConfig.StandModels[act] or {}
	local extents = clone:GetExtentsSize()
	local height = (settings.Height or 3) * scale
	if extents.Y > 0 then
		clone:ScaleTo(clone:GetScale() * height / extents.Y)
	end
	local rot = settings.Rotation or Vector3.new()
	local boxCF = clone:GetBoundingBox()
	-- Pivot at the model's centre, facing -Z, plus the configured rotation.
	clone.WorldPivot = CFrame.new(boxCF.Position) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))

	local point = Instance.new("Attachment")
	point.Name = "NailPoint"
	point.Parent = root
	point.WorldPosition = boxCF.Position + Vector3.new(0, 0, -clone:GetExtentsSize().Z * 0.5)
	return clone, { Body = root, Joints = {}, NailPoint = point, Custom = true }
end

-- Five-point star made of five thin spikes, laid on the surface facing `normal`.
local function star(model, body, center, normal, size, color)
	local up = math.abs(normal.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local base = CFrame.lookAt(center, center + normal, up)
	for i = 0, 4 do
		local spike = part(model, {
			Name = "StarSpike",
			Size = Vector3.new(size * 0.28, size * 0.55, size * 0.04),
			Color = color,
			Ellipsoid = true,
		})
		local cf = base * CFrame.Angles(0, 0, i * math.pi * 2 / 5) * CFrame.new(0, size * 0.22, 0)
		attach(body, spike, cf)
	end
end

-- Thin isosceles triangle from two mirrored WedgeParts. Lies in the plane
-- whose normal is `normal`; apex points along `dir`.
local function triangle(model, parent, base, normal, dir, height, width, thickness, color)
	local n = normal.Unit
	local up = (dir - n * dir:Dot(n)).Unit
	local frame = CFrame.fromMatrix(base, n, up) -- X = normal, Y = toward the apex
	for _, side in ipairs({ -1, 1 }) do
		local w = Instance.new("WedgePart")
		w.Name = "StarPoint"
		w.Anchored = false
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.CastShadow = false
		w.Massless = true
		w.Material = Enum.Material.SmoothPlastic
		w.Color = color
		w.Size = Vector3.new(thickness, height, width / 2)
		local cf = frame * CFrame.new(0, height / 2, side * width / 4)
		if side > 0 then
			cf = cf * CFrame.Angles(0, math.pi, 0) -- mirror so both halves meet on the centre line
		end
		w.Parent = model
		attach(parent, w, parent.CFrame:Inverse() * cf)
	end
end

-- Proper five-pointed star (pentagon centre + five triangle points) on a surface.
local function star5(model, parent, center, normal, size, color, spin)
	local n = normal.Unit
	local helper = math.abs(n.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local u = (helper - n * helper:Dot(n)).Unit
	local v = n:Cross(u)
	local world = parent.CFrame * center
	local worldN = parent.CFrame:VectorToWorldSpace(n)
	local worldU = parent.CFrame:VectorToWorldSpace(u)
	local worldV = parent.CFrame:VectorToWorldSpace(v)
	local core = part(model, { Name = "StarCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(size * 0.06, size * 0.42, size * 0.42), Color = color })
	attach(parent, core, parent.CFrame:Inverse() * CFrame.fromMatrix(world, worldN, worldU))
	for i = 0, 4 do
		local a = (spin or 0) + i * math.pi * 2 / 5
		local dir = worldU * math.cos(a) + worldV * math.sin(a)
		triangle(model, parent, world + dir * size * 0.17, worldN, dir, size * 0.36, size * 0.26, size * 0.06, color)
	end
end

-- Tapered cone made of stacked cylinders, pointing along `dir` (parent space).
local function cone(model, parent, base, dir, length, radius, color, material)
	dir = dir.Unit
	local steps = 4
	for i = 0, steps - 1 do
		local segLen = length / steps
		local r = radius * (1 - i / steps)
		local c = base + dir * (segLen * (i + 0.5))
		local seg = part(model, { Name = "Cone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(segLen * 1.05, r * 2, r * 2), Color = color, Material = material or Enum.Material.SmoothPlastic })
		local up = math.abs(dir.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
		attach(parent, seg, CFrame.fromMatrix(c, dir, dir:Cross(up).Unit:Cross(dir)))
	end
	local tip = part(model, { Name = "ConeTip", Size = Vector3.new(radius * 0.5, radius * 0.5, radius * 0.5), Color = color, Ellipsoid = true })
	attach(parent, tip, CFrame.new(base + dir * length))
end

-- Point on the surface of an axis-aligned ellipsoid (half sizes `h`) toward `dir`.
local function onSurface(h, dir, push)
	local d = dir.Unit
	local k = 1 / math.sqrt((d.X / h.X) ^ 2 + (d.Y / h.Y) ^ 2 + (d.Z / h.Z) ^ 2)
	return d * k * (push or 1)
end

---------------------------------------------------------------------------
-- ACT 1 (from the owner's two reference images)
---------------------------------------------------------------------------
local function buildAct1Classic(scale)
	local s = scale
	local pink = Color3.fromRGB(236, 120, 200)
	local pinkLight = Color3.fromRGB(250, 170, 225)
	local pinkDark = Color3.fromRGB(176, 60, 140)
	local starColor = Color3.fromRGB(255, 182, 52)
	local gold = Color3.fromRGB(240, 190, 70)
	local heart = Color3.fromRGB(190, 36, 96)

	local model = Instance.new("Model")
	model.Name = "TuskAct1"
	local bodySize = Vector3.new(1.65, 2.5, 1.5) * s
	local h = bodySize / 2
	local body = part(model, { Name = "Body", Size = bodySize, Color = pink, Ellipsoid = true, Massless = false })
	-- Leans to its right and tips forward a little, like the drawings.
	body.CFrame = CFrame.Angles(0.12, 0, -0.2)
	body.Anchored = true
	model.PrimaryPart = body
	local rig = { Body = body, Joints = {} }

	-- Two-tone shading: lighter forehead, darker lower half.
	local cap = part(model, { Name = "Highlight", Size = bodySize * Vector3.new(0.78, 0.55, 0.72), Color = pinkLight, Ellipsoid = true })
	attach(body, cap, CFrame.new(0.12 * s, 0.42 * s, -0.22 * s))
	local belly = part(model, { Name = "Belly", Size = bodySize * Vector3.new(0.92, 0.6, 0.94), Color = pinkDark, Ellipsoid = true })
	attach(body, belly, CFrame.new(0.04 * s, -0.42 * s, 0.02 * s))
	-- Pointed bottom: the egg narrows down toward the heart legs.
	local tip = part(model, { Name = "LowerTip", Size = Vector3.new(0.9, 1.0, 0.85) * s, Color = pinkDark, Ellipsoid = true })
	attach(body, tip, CFrame.new(-0.05 * s, -1.05 * s, 0.05 * s))

	-- Long chin / snout below the face, with little gold spikes.
	local chin = part(model, { Name = "Chin", Size = Vector3.new(0.95, 1.15, 0.95) * s, Color = pink, Ellipsoid = true })
	attach(body, chin, CFrame.new(-0.22 * s, -0.78 * s, -0.28 * s) * CFrame.Angles(0.35, 0, -0.25))
	for i = 1, 3 do
		cone(model, body, Vector3.new(-(0.22 + i * 0.12) * s, (-1.05 - i * 0.04) * s, (-0.55 + i * 0.05) * s), Vector3.new(-0.6, -0.5, -0.6), 0.22 * s, 0.05 * s, gold, Enum.Material.Metal)
	end
	local mouth = part(model, { Name = "Mouth", Size = Vector3.new(0.55, 0.22, 0.2) * s, Color = Color3.fromRGB(90, 20, 50), Ellipsoid = true })
	attach(body, mouth, CFrame.new(-0.15 * s, -0.42 * s, -0.66 * s) * CFrame.Angles(0, 0, 0.25))

	-- Big forehead star with spiky dark fur around it.
	local starDir = Vector3.new(0.42, 0.62, -0.66)
	local starPos = onSurface(h, starDir, 1.02)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local n = starDir.Unit
		local helper = Vector3.new(0, 1, 0)
		local u = (helper - n * helper:Dot(n)).Unit
		local v = n:Cross(u)
		local dir = u * math.cos(a) + v * math.sin(a)
		local fur = part(model, { Name = "Fur", Size = Vector3.new(0.03, 0.03, 0.34) * s, Color = Color3.fromRGB(60, 20, 45) })
		local p = starPos + dir * 0.3 * s
		attach(body, fur, CFrame.lookAt(p, p + dir))
	end
	star5(model, body, starPos + starDir.Unit * 0.02 * s, starDir, 1.15 * s, starColor, 0.3)

	-- Eyes: white, black pupil, heavy pink lid, lashes, and wavy tendrils.
	local eyes = { { Vector3.new(0.38, 0.02, -1), -1 }, { Vector3.new(-0.3, -0.06, -1), 1 } }
	for _, e in ipairs(eyes) do
		local pos = onSurface(h, e[1], 0.98)
		local eye = part(model, { Name = "Eye", Size = Vector3.new(0.34, 0.3, 0.2) * s, Color = Color3.fromRGB(250, 248, 240), Ellipsoid = true })
		attach(body, eye, CFrame.new(pos))
		local pupil = part(model, { Name = "Pupil", Size = Vector3.new(0.15, 0.15, 0.06) * s, Color = Color3.fromRGB(25, 15, 20), Ellipsoid = true })
		attach(body, pupil, CFrame.new(pos + Vector3.new(0, -0.03 * s, -0.1 * s)))
		local shine = part(model, { Name = "Shine", Size = Vector3.new(0.05, 0.05, 0.02) * s, Color = Color3.new(1, 1, 1), Ellipsoid = true })
		attach(body, shine, CFrame.new(pos + Vector3.new(0.03 * s, 0.01 * s, -0.13 * s)))
		local lid = part(model, { Name = "Lid", Size = Vector3.new(0.44, 0.22, 0.26) * s, Color = pinkDark, Ellipsoid = true })
		attach(body, lid, CFrame.new(pos + Vector3.new(0, 0.1 * s, -0.02 * s)) * CFrame.Angles(0, 0, e[2] * 0.3))
		for l = -1, 1 do
			local lash = part(model, { Name = "Lash", Size = Vector3.new(0.025, 0.16, 0.025) * s, Color = Color3.fromRGB(40, 10, 30) })
			attach(body, lash, CFrame.new(pos + Vector3.new(l * 0.11 * s, 0.2 * s, -0.08 * s)) * CFrame.Angles(0, 0, l * 0.5))
		end
		-- Wavy pink tendril from the outer corner of each eye.
		local outward = -e[2]
		local prev = pos + Vector3.new(outward * 0.2 * s, 0, 0)
		for k = 1, 3 do
			local nextP = prev + Vector3.new(outward * 0.18 * s, (k % 2 == 0 and 0.08 or -0.06) * s, 0.02 * s)
			local seg = part(model, { Name = "Tendril", Size = Vector3.new(0.09, 0.09, 0.24) * s, Color = pinkLight, Ellipsoid = true })
			attach(body, seg, CFrame.lookAt((prev + nextP) / 2, nextP))
			prev = nextP
		end
	end

	-- Gold beak (a cone) pointing forward-down, and the gold pin from the star to its tip.
	local beakBase = onSurface(h, Vector3.new(-0.06, -0.12, -1), 0.95)
	local beakDir = Vector3.new(-0.35, -0.5, -0.8).Unit
	local beakLen = 0.6 * s
	cone(model, body, beakBase, beakDir, beakLen, 0.13 * s, gold, Enum.Material.Metal)
	local beakTip = beakBase + beakDir * beakLen
	local pinVec = beakTip - starPos
	local pin = part(model, { Name = "Pin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(pinVec.Magnitude, 0.035 * s, 0.035 * s), Color = gold, Material = Enum.Material.Metal, Reflectance = 0.3 })
	local mid = (starPos + beakTip) / 2
	attach(body, pin, CFrame.lookAt(mid, beakTip) * CFrame.Angles(0, math.pi / 2, 0))
	local pinHead = part(model, { Name = "PinHead", Size = Vector3.new(0.09, 0.09, 0.09) * s, Color = gold, Material = Enum.Material.Metal, Ellipsoid = true })
	attach(body, pinHead, CFrame.new(starPos + starDir.Unit * 0.04 * s))

	-- Orange stars all over the body.
	local spots = {
		Vector3.new(0.7, 0.55, -0.3), Vector3.new(0.85, 0.05, -0.2), Vector3.new(-0.9, 0.15, -0.1), Vector3.new(-0.7, -0.45, -0.35),
		Vector3.new(0.6, -0.55, -0.5), Vector3.new(0.15, 0.95, 0.2), Vector3.new(-0.35, 0.45, 0.8), Vector3.new(0.45, 0.2, 0.85),
		Vector3.new(-0.1, -0.7, 0.7), Vector3.new(-0.55, -0.15, -0.8), Vector3.new(0.3, 0.7, -0.6), Vector3.new(-0.8, 0.6, 0.3),
		Vector3.new(0.9, -0.35, 0.2), Vector3.new(-0.5, -0.8, -0.2), Vector3.new(0.65, 0.9, 0.1), Vector3.new(-0.95, -0.4, 0.3),
		Vector3.new(0.2, -0.9, -0.4), Vector3.new(0.95, 0.4, 0.4),
	}
	for i, d in ipairs(spots) do
		local p = onSurface(h, d, 1.01)
		star5(model, body, p, d, (0.26 + (i % 3) * 0.04) * s, starColor, i)
	end

	-- Ears: a huge floppy ear sweeping up (its left), a smaller one drooping (its right). Animated.
	local ears = {
		-- Right ear sweeps up and out; left ear droops down beside the face.
		{ Name = "EarL", Base = CFrame.new(-0.5 * s, 0.9 * s, 0.1 * s) * CFrame.Angles(0.25, -0.3, 1.15), Size = Vector3.new(0.6, 1.8, 0.13) },
		{ Name = "EarR", Base = CFrame.new(0.7 * s, 0.75 * s, 0.05 * s) * CFrame.Angles(-0.1, 0.25, -1.35), Size = Vector3.new(0.5, 1.4, 0.13) },
	}
	for _, e in ipairs(ears) do
		local ear = part(model, { Name = e.Name, Size = e.Size * s, Color = pink, Ellipsoid = true })
		local inner = part(model, { Name = e.Name .. "Inner", Size = e.Size * s * Vector3.new(0.6, 0.8, 0.5), Color = pinkDark, Ellipsoid = true })
		local offset = CFrame.new(0, e.Size.Y * s * 0.45, 0)
		local w = attach(body, ear, e.Base * offset)
		attach(ear, inner, CFrame.new(0, 0, -0.035 * s))
		rig.Joints[e.Name] = { Weld = w, Base = e.Base, Offset = offset }
	end
	-- Small spike on top of the head.
	local topSpike = part(model, { Name = "TopSpike", Size = Vector3.new(0.18, 0.45, 0.14) * s, Color = pink, Ellipsoid = true })
	attach(body, topSpike, CFrame.new(-0.05 * s, 1.15 * s, 0.1 * s))

	-- Tattered pink fins around the silhouette.
	local fins = {
		CFrame.new(-0.82 * s, 0.25 * s, -0.2 * s) * CFrame.Angles(0, 0, 1.3),
		CFrame.new(0.86 * s, 0.32 * s, -0.25 * s) * CFrame.Angles(0, 0, -1.2),
		CFrame.new(-0.78 * s, -0.35 * s, -0.25 * s) * CFrame.Angles(0, 0, 2.0),
		CFrame.new(0.7 * s, -0.7 * s, -0.4 * s) * CFrame.Angles(0, 0, -2.2),
		CFrame.new(-0.4 * s, -0.95 * s, -0.4 * s) * CFrame.Angles(0, 0, 2.7),
	}
	for _, cf in ipairs(fins) do
		for k = 0, 1 do
			local fin = part(model, { Name = "Fin", Size = Vector3.new(0.14, 0.42 - k * 0.12, 0.07) * s, Color = k == 0 and pink or pinkLight, Ellipsoid = true })
			attach(body, fin, cf * CFrame.new(k * 0.07 * s, (0.18 + k * 0.1) * s, 0) * CFrame.Angles(0, 0, k * 0.4))
		end
	end

	-- Side appendage (its left) with a gold horn and a star.
	local side = part(model, { Name = "SideHand", Size = Vector3.new(0.75, 0.5, 0.45) * s, Color = pink, Ellipsoid = true })
	attach(body, side, CFrame.new(-1.0 * s, -0.2 * s, -0.1 * s) * CFrame.Angles(0, 0, 0.4))
	cone(model, body, Vector3.new(-1.32 * s, -0.08 * s, -0.1 * s), Vector3.new(-1, 0.5, -0.2), 0.3 * s, 0.07 * s, gold, Enum.Material.Metal)
	star5(model, body, Vector3.new(-1.02 * s, -0.12 * s, -0.33 * s), Vector3.new(-0.2, 0.1, -1), 0.22 * s, starColor, 0.5)

	-- Five thin legs ending in hearts (four animated).
	local legX = { -0.34, -0.15, 0.04, 0.22, 0.4 }
	for i = 1, 5 do
		local base = CFrame.new(legX[i] * s, -1.4 * s, (i % 2 == 0 and 0.12 or -0.12) * s)
		local legLength = (0.55 + ((i * 7) % 4) * 0.1) * s
		local leg = part(model, { Name = "Leg" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(legLength, 0.06 * s, 0.06 * s), Color = pinkDark })
		local offset = CFrame.new(0, -legLength / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local w = attach(body, leg, base * offset)
		if i <= 4 then
			rig.Joints["Leg" .. i] = { Weld = w, Base = base, Offset = offset }
		end
		-- Heart: two lobes and a point, facing forward.
		local footCF = CFrame.new(-legLength / 2 - 0.16 * s, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2)
		for _, sx in ipairs({ -1, 1 }) do
			local lobe = part(model, { Name = "HeartLobe", Size = Vector3.new(0.24, 0.24, 0.12) * s, Color = heart, Ellipsoid = true })
			attach(leg, lobe, footCF * CFrame.new(sx * 0.09 * s, 0.05 * s, 0))
		end
		local point = part(model, { Name = "HeartPoint", Size = Vector3.new(0.22, 0.22, 0.1) * s, Color = heart })
		attach(leg, point, footCF * CFrame.new(0, -0.07 * s, 0) * CFrame.Angles(0, 0, math.pi / 4))
	end

	local nailPoint = Instance.new("Attachment")
	nailPoint.Name = "NailPoint"
	nailPoint.Position = beakTip
	nailPoint.Parent = body
	rig.NailPoint = nailPoint
	return model, rig
end

---------------------------------------------------------------------------
-- ACT 2 (from the owner's reference images): a pink mechanical Stand with
-- a ribbed visor face, a blue star, a big dotted pod, a pincer claw and two
-- gold rods ending in purple drums.
---------------------------------------------------------------------------
local function limb(model, parent, rig, name, base, length, thickness, color, handColor)
	local arm = part(model, { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, thickness, thickness), Color = color })
	-- Cylinder axis is X; hang it down from the joint.
	local offset = CFrame.new(0, -length / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local w = attach(parent, arm, base * offset)
	rig.Joints[name] = { Weld = w, Base = base, Offset = offset }
	local hand = part(model, { Name = name .. "Hand", Size = Vector3.new(thickness * 1.6, thickness * 1.6, thickness * 1.6), Color = handColor or color, Ellipsoid = true })
	attach(arm, hand, CFrame.new(-length / 2 - thickness * 0.4, 0, 0))
	return arm, hand
end

local function buildAct2(scale)
	local s = scale * 1.1
	local pink = Color3.fromRGB(240, 150, 214)
	local pinkDark = Color3.fromRGB(196, 100, 176)
	local gold = Color3.fromRGB(232, 182, 70)
	local purple = Color3.fromRGB(86, 64, 132)
	local purpleRim = Color3.fromRGB(160, 140, 200)
	local blueStar = Color3.fromRGB(120, 200, 245)
	local yellow = Color3.fromRGB(255, 210, 70)

	local model = Instance.new("Model")
	model.Name = "TuskAct2"
	local torso = part(model, { Name = "Body", Size = Vector3.new(1.2, 1.3, 0.95) * s, Color = pink, Ellipsoid = true, Massless = false })
	torso.CFrame = CFrame.Angles(0.15, 0, -0.15)
	torso.Anchored = true
	model.PrimaryPart = torso
	local rig = { Body = torso, Joints = {} }

	-- Ribbed chest (gills).
	for i = -2, 2 do
		local rib = part(model, { Name = "Rib", Size = Vector3.new(0.08, 0.75, 0.1) * s, Color = pinkDark })
		attach(torso, rib, CFrame.new(i * 0.16 * s, -0.05 * s, -0.44 * s) * CFrame.Angles(0, i * 0.15, 0))
	end
	local belt = part(model, { Name = "Belt", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 1.05, 1.05) * s, Color = gold, Material = Enum.Material.Metal })
	attach(torso, belt, CFrame.new(0, -0.55 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))

	-- Head: round, with a ribbed visor face and a blue star.
	local head = part(model, { Name = "Head", Size = Vector3.new(1.15, 1.1, 1.1) * s, Color = pink, Ellipsoid = true })
	attach(torso, head, CFrame.new(-0.05 * s, 1.05 * s, -0.05 * s))
	local hcf = CFrame.new(-0.05 * s, 1.05 * s, -0.05 * s)
	local visor = part(model, { Name = "Visor", Size = Vector3.new(0.5, 0.72, 0.2) * s, Color = Color3.fromRGB(70, 30, 70), Ellipsoid = true })
	attach(torso, visor, hcf * CFrame.new(0, -0.05 * s, -0.47 * s))
	for i = -1, 1 do
		local bar = part(model, { Name = "VisorBar", Size = Vector3.new(0.07, 0.68, 0.08) * s, Color = pinkDark })
		attach(torso, bar, hcf * CFrame.new(i * 0.13 * s, -0.05 * s, -0.56 * s))
	end
	for _, side in ipairs({ -1, 1 }) do
		local cheek = part(model, { Name = "Cheek", Size = Vector3.new(0.28, 0.28, 0.16) * s, Color = pinkDark, Ellipsoid = true })
		attach(torso, cheek, hcf * CFrame.new(side * 0.36 * s, -0.18 * s, -0.4 * s))
		local earDisc = part(model, { Name = "EarDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.45, 0.45) * s, Color = gold, Material = Enum.Material.Metal })
		attach(torso, earDisc, hcf * CFrame.new(side * 0.57 * s, 0.05 * s, 0))
	end
	star5(model, torso, (hcf * CFrame.new(0.3 * s, 0.3 * s, -0.38 * s)).Position, Vector3.new(0.4, 0.4, -1), 0.4 * s, blueStar, 0.2)

	-- Two gold rods from the back, each ending in a purple drum (animated like ears).
	for _, d in ipairs({ { "EarL", -1 }, { "EarR", 1 } }) do
		local base = CFrame.new(d[2] * 0.35 * s, 0.55 * s, 0.4 * s) * CFrame.Angles(-0.35, 0, -d[2] * 0.75)
		local rodLength = 1.5 * s
		local rod = part(model, { Name = d[1], Shape = Enum.PartType.Cylinder, Size = Vector3.new(rodLength, 0.1 * s, 0.1 * s), Color = gold, Material = Enum.Material.Metal })
		local offset = CFrame.new(0, rodLength / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local w = attach(torso, rod, base * offset)
		rig.Joints[d[1]] = { Weld = w, Base = base, Offset = offset }
		-- Drum at the far end of the rod (rod axis = its X axis, pointing "up").
		local drum = part(model, { Name = "Drum", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.28, 0.75, 0.75) * s, Color = purple, Material = Enum.Material.Metal })
		attach(rod, drum, CFrame.new(rodLength / 2 + 0.1 * s, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))
		local rim = part(model, { Name = "DrumRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 0.82, 0.82) * s, Color = purpleRim, Material = Enum.Material.Metal })
		attach(rod, rim, CFrame.new(rodLength / 2 + 0.1 * s, 0, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(-0.02 * s, 0, 0))
		local hole = part(model, { Name = "DrumHole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.32, 0.32, 0.32) * s, Color = Color3.fromRGB(30, 20, 40) })
		attach(rod, hole, CFrame.new(rodLength / 2 + 0.1 * s, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))
	end

	-- Arms: right arm reaches out with a pincer claw; left arm tucked.
	local shoulderR = CFrame.new(0.68 * s, 0.35 * s, -0.05 * s) * CFrame.Angles(1.1, 0, 0.5)
	local _, handR = limb(model, torso, rig, "ArmR", shoulderR, 1.1 * s, 0.2 * s, pink, gold)
	for _, side in ipairs({ -1, 1 }) do
		local prong = part(model, { Name = "Claw", Size = Vector3.new(0.09, 0.4, 0.12) * s, Color = pinkDark })
		attach(handR, prong, CFrame.new(side * 0.1 * s, -0.25 * s, 0) * CFrame.Angles(0, 0, side * 0.35))
	end
	local shoulderL = CFrame.new(-0.68 * s, 0.35 * s, 0) * CFrame.Angles(0.4, 0, -0.35)
	limb(model, torso, rig, "ArmL", shoulderL, 0.95 * s, 0.2 * s, pink, gold)
	for _, side in ipairs({ -1, 1 }) do
		local pad = part(model, { Name = "ShoulderPad", Size = Vector3.new(0.45, 0.4, 0.45) * s, Color = pinkDark, Ellipsoid = true })
		attach(torso, pad, CFrame.new(side * 0.66 * s, 0.4 * s, 0))
	end

	-- Big dotted pod (lower body) with a yellow-and-blue star.
	local podCF = CFrame.new(0.2 * s, -1.25 * s, -0.15 * s)
	local pod = part(model, { Name = "Pod", Size = Vector3.new(1.55, 1.35, 1.45) * s, Color = pink, Ellipsoid = true })
	attach(torso, pod, podCF)
	local golden = math.pi * (3 - math.sqrt(5))
	for i = 0, 13 do
		local y = 1 - (i + 0.5) / 14 * 2
		local ring = math.sqrt(1 - y * y)
		local dir = Vector3.new(math.cos(i * golden) * ring, y, math.sin(i * golden) * ring)
		if dir.Z < 0.4 then
			local p = podCF.Position + onSurface(Vector3.new(0.775, 0.675, 0.725) * s, dir, 0.99)
			local hole = part(model, { Name = "PodHole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 0.13, 0.13) * s, Color = Color3.fromRGB(120, 50, 100) })
			local up = math.abs(dir.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
			attach(torso, hole, CFrame.fromMatrix(p, dir.Unit, dir.Unit:Cross(up).Unit:Cross(dir.Unit)))
		end
	end
	local starAt = podCF.Position + onSurface(Vector3.new(0.775, 0.675, 0.725) * s, Vector3.new(0.6, -0.1, -0.8), 1.01)
	star5(model, torso, starAt, Vector3.new(0.6, -0.1, -0.8), 0.6 * s, yellow, 0.3)
	star5(model, torso, starAt + Vector3.new(0.6, -0.1, -0.8).Unit * 0.02 * s, Vector3.new(0.6, -0.1, -0.8), 0.38 * s, blueStar, 0.3)

	rig.NailPoint = Instance.new("Attachment")
	rig.NailPoint.Name = "NailPoint"
	rig.NailPoint.Parent = handR
	return model, rig
end

---------------------------------------------------------------------------
-- Humanoid Stands (Act 3, Act 4)
---------------------------------------------------------------------------
local function buildHumanoid(name, scale, look)
	local s = scale
	local model = Instance.new("Model")
	model.Name = name
	local rig = { Joints = {} }

	local torso = part(model, { Name = "Body", Size = look.Torso * s, Color = look.Body, Ellipsoid = true, Massless = false })
	torso.CFrame = CFrame.new()
	torso.Anchored = true
	model.PrimaryPart = torso
	rig.Body = torso
	local ty = look.Torso.Y * s / 2

	-- Chest trim and star.
	local plate = part(model, { Name = "Chest", Size = Vector3.new(look.Torso.X * 0.75, look.Torso.Y * 0.45, 0.12) * s, Color = look.Trim, Material = look.TrimMaterial or Enum.Material.SmoothPlastic, Ellipsoid = true })
	attach(torso, plate, CFrame.new(0, ty * 0.3, -look.Torso.Z * s * 0.44))
	star(model, torso, Vector3.new(0, ty * 0.3, -look.Torso.Z * s * 0.52), Vector3.new(0, 0, -1), 0.55 * s, look.Star)

	-- Head with eyes, forehead star and the gold pin.
	local head = part(model, { Name = "Head", Size = look.Head * s, Color = look.HeadColor or look.Body, Ellipsoid = true })
	attach(torso, head, CFrame.new(0, ty + look.Head.Y * s * 0.45, -0.05 * s))
	local hy = look.Head.Y * s
	for _, side in ipairs({ -1, 1 }) do
		local eye = part(model, { Name = "Eye", Size = Vector3.new(0.22, 0.14, 0.08) * s, Color = look.Eye, Material = Enum.Material.Neon, Ellipsoid = true })
		attach(head, eye, CFrame.new(side * 0.2 * s, 0.02 * s, -look.Head.Z * s * 0.47) * CFrame.Angles(0, 0, side * -0.25))
	end
	star(model, head, Vector3.new(0, hy * 0.32, -look.Head.Z * s * 0.42), Vector3.new(0, 0.5, -1).Unit, 0.4 * s, look.Star)
	-- Head fins (animated like Act 1's ears).
	for _, e in ipairs({ { "EarL", -1 }, { "EarR", 1 } }) do
		local base = CFrame.new(e[2] * look.Head.X * s * 0.45, hy * 0.25, 0.05 * s) * CFrame.Angles(0, 0, -e[2] * 1.1)
		local fin = part(model, { Name = e[1], Size = Vector3.new(0.22, 0.8, 0.08) * s, Color = look.Trim, Ellipsoid = true })
		local offset = CFrame.new(0, 0.35 * s, 0)
		local w = attach(head, fin, base * offset)
		rig.Joints[e[1]] = { Weld = w, Base = base, Offset = offset }
	end

	-- Shoulders and arms.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local shoulderPos = CFrame.new(a[2] * (look.Torso.X * s * 0.5 + 0.1 * s), ty * 0.7, 0)
		local pad = part(model, { Name = "Shoulder", Size = Vector3.new(0.6, 0.5, 0.6) * s * look.ArmThickness * 3, Color = look.Trim, Material = look.TrimMaterial or Enum.Material.SmoothPlastic, Ellipsoid = true })
		attach(torso, pad, shoulderPos)
		local _, hand = limb(model, torso, rig, a[1], shoulderPos * CFrame.Angles(0, 0, a[2] * 0.15), look.ArmLength * s, look.ArmThickness * s, look.Body, look.Trim)
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Lower body: legs (Act 4) or a swirling tail (Act 3).
	if look.Legs then
		for i, side in ipairs({ -1, 1 }) do
			local base = CFrame.new(side * look.Torso.X * s * 0.25, -ty * 0.85, 0)
			limb(model, torso, rig, "Leg" .. i, base, look.LegLength * s, look.ArmThickness * 1.3 * s, look.Body, look.Trim)
		end
	else
		local y = -ty * 0.9
		for i = 1, 4 do
			local size = Vector3.new(look.Torso.X * (0.8 - i * 0.16), 0.9, look.Torso.Z * (0.8 - i * 0.16)) * s
			local seg = part(model, { Name = "Tail", Size = size, Color = i % 2 == 0 and look.Trim or look.Body, Ellipsoid = true })
			attach(torso, seg, CFrame.new(math.sin(i * 1.3) * 0.25 * s, y, math.cos(i * 1.3) * 0.2 * s) * CFrame.Angles(0, i * 0.6, 0.15 * i))
			y = y - 0.55 * s
		end
	end

	-- Scattered stars on the torso.
	for _, spot in ipairs({ Vector3.new(0.45, -0.3, -0.35), Vector3.new(-0.45, 0.1, -0.35), Vector3.new(0.3, 0.4, 0.4), Vector3.new(-0.35, -0.4, 0.4) }) do
		star(model, torso, Vector3.new(spot.X * look.Torso.X, spot.Y * look.Torso.Y, spot.Z * look.Torso.Z) * s * 1.05, Vector3.new(spot.X, 0, spot.Z).Unit, 0.22 * s, look.Star)
	end
	return model, rig
end

-- Extend a limb: segment hanging further "down" the limb from `from` (a part
-- whose local -X runs along the limb, like limb()'s hand). Returns the end joint.
local function segment(model, from, length, thickness, color, bend, jointColor)
	local joint = part(model, { Name = "Joint", Size = Vector3.new(thickness * 1.35, thickness * 1.35, thickness * 1.35), Color = jointColor or color, Material = jointColor and Enum.Material.Metal or Enum.Material.SmoothPlastic, Ellipsoid = true })
	attach(from, joint, CFrame.new())
	local seg = part(model, { Name = "Segment", Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, thickness, thickness), Color = color })
	local cf = CFrame.Angles(0, 0, bend or 0) * CFrame.new(-length / 2, 0, 0)
	attach(from, seg, cf)
	local tip = part(model, { Name = "Tip", Size = Vector3.new(thickness, thickness, thickness), Color = color, Ellipsoid = true })
	attach(from, tip, CFrame.Angles(0, 0, bend or 0) * CFrame.new(-length, 0, 0))
	return tip
end

-- Three long metal spikes fanning out from a part, along its local -X.
local function spikes(model, from, length, color)
	for i = -1, 1 do
		cone(model, from, Vector3.new(0, 0, i * 0.06), Vector3.new(-1, 0, i * 0.18), length, 0.045, color, Enum.Material.Metal)
	end
end

---------------------------------------------------------------------------
-- ACT 3 (from the owner's reference images): big pink bean body with a
-- dark crest, antennae, a slotted face mask, blue shoulder balls with red
-- stars, a purple belly lens, thin limbs with ball joints and spiked claws.
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- ACT 1 "Mascot" (owner's written description): a small, toy-like blue and
-- cyan humanoid with a big round head, big eyes, mechanical seams, pink
-- accents, short arms and legs, and cyan Spin sparkles on its hands.
---------------------------------------------------------------------------
local function sparkles(parent, color)
	local a = Instance.new("Attachment")
	a.Name = "SpinSparkles"
	a.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 7
	e.Parent = a
	return e
end

local function buildAct1Mascot(scale)
	local s = scale
	local blue = Color3.fromRGB(46, 120, 214)
	local cyan = Color3.fromRGB(90, 214, 250)
	local light = Color3.fromRGB(196, 240, 255)
	local navy = Color3.fromRGB(26, 52, 120)
	local pink = Color3.fromRGB(246, 120, 190)
	local steel = Color3.fromRGB(170, 185, 200)

	local model = Instance.new("Model")
	model.Name = "TuskAct1"
	-- Small torso is the root; the big head sits on top (animated).
	local torso = part(model, { Name = "Body", Size = Vector3.new(0.85, 0.9, 0.7) * s, Color = blue, Ellipsoid = true, Massless = false })
	torso.CFrame = CFrame.new()
	torso.Anchored = true
	model.PrimaryPart = torso
	local rig = { Body = torso, Joints = {} }

	local chest = part(model, { Name = "ChestPlate", Size = Vector3.new(0.6, 0.55, 0.2) * s, Color = light, Ellipsoid = true })
	attach(torso, chest, CFrame.new(0, 0.05 * s, -0.27 * s))
	star5(model, torso, Vector3.new(0, 0.06 * s, -0.38 * s), Vector3.new(0, 0, -1), 0.32 * s, pink, 0)
	local belt = part(model, { Name = "Belt", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.78, 0.78) * s, Color = navy, Material = Enum.Material.Metal })
	attach(torso, belt, CFrame.new(0, -0.3 * s, 0) * CFrame.Angles(0, 0, math.pi / 2))

	-- Head: a separate welded group so it can tilt and look around.
	local headBase = CFrame.new(0, 0.95 * s, -0.02 * s)
	local head = part(model, { Name = "Head", Size = Vector3.new(1.45, 1.35, 1.35) * s, Color = cyan, Ellipsoid = true })
	local headWeld = attach(torso, head, headBase)
	rig.Joints.Head = { Weld = headWeld, Base = headBase, Offset = CFrame.new() }
	local face = part(model, { Name = "Face", Size = Vector3.new(1.15, 0.95, 0.5) * s, Color = light, Ellipsoid = true })
	attach(head, face, CFrame.new(0, -0.08 * s, -0.47 * s))
	-- Mechanical seam ring and side bolts.
	local seam = part(model, { Name = "Seam", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 1.47, 1.47) * s, Color = navy, Material = Enum.Material.Metal })
	attach(head, seam, CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0))
	for _, side in ipairs({ -1, 1 }) do
		local bolt = part(model, { Name = "Bolt", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 0.3, 0.3) * s, Color = steel, Material = Enum.Material.Metal })
		attach(head, bolt, CFrame.new(side * 0.72 * s, 0.02 * s, 0))
		local cheek = part(model, { Name = "Cheek", Size = Vector3.new(0.18, 0.11, 0.05) * s, Color = pink, Ellipsoid = true })
		attach(head, cheek, CFrame.new(side * 0.36 * s, -0.3 * s, -0.66 * s))
	end
	-- Antenna with a pink star ball.
	local antenna = part(model, { Name = "Antenna", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 0.05, 0.05) * s, Color = navy, Material = Enum.Material.Metal })
	attach(head, antenna, CFrame.new(0.15 * s, 0.82 * s, 0) * CFrame.Angles(0, 0, math.pi / 2 - 0.3))
	local bulb = part(model, { Name = "AntennaBall", Size = Vector3.new(0.18, 0.18, 0.18) * s, Color = pink, Material = Enum.Material.Neon, Ellipsoid = true })
	attach(head, bulb, CFrame.new(0.21 * s, 1.02 * s, 0))
	-- Big, slightly mismatched toy eyes.
	for _, e in ipairs({ { -1, 0.42 }, { 1, 0.38 } }) do
		local eyePos = CFrame.new(e[1] * 0.3 * s, 0.08 * s, -0.62 * s)
		local white = part(model, { Name = "Eye", Size = Vector3.new(0.4, e[2] * 1.15, 0.2) * s, Color = Color3.new(1, 1, 1), Ellipsoid = true })
		attach(head, white, eyePos)
		local pupil = part(model, { Name = "Pupil", Size = Vector3.new(0.25, e[2] * 0.75, 0.08) * s, Color = Color3.fromRGB(15, 20, 45), Ellipsoid = true })
		attach(head, pupil, eyePos * CFrame.new(e[1] * -0.03 * s, -0.02 * s, -0.08 * s))
		local glint = part(model, { Name = "Glint", Size = Vector3.new(0.08, 0.08, 0.03) * s, Color = Color3.new(1, 1, 1), Ellipsoid = true })
		attach(head, glint, eyePos * CFrame.new(0.05 * s, 0.07 * s, -0.12 * s))
		local rim = part(model, { Name = "EyeRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 0.46, 0.46) * s, Color = navy, Material = Enum.Material.Metal })
		attach(head, rim, eyePos * CFrame.new(0, 0, 0.02 * s) * CFrame.Angles(0, math.pi / 2, 0))
	end
	local mouth = part(model, { Name = "Mouth", Size = Vector3.new(0.2, 0.07, 0.04) * s, Color = pink, Ellipsoid = true })
	attach(head, mouth, CFrame.new(0, -0.38 * s, -0.66 * s))

	-- Short arms (animated) with round hands and cyan Spin sparkles.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local shoulder = CFrame.new(a[2] * 0.45 * s, 0.22 * s, 0) * CFrame.Angles(0, 0, a[2] * 0.45)
		local _, hand = limb(model, torso, rig, a[1], shoulder, 0.5 * s, 0.2 * s, cyan, light)
		hand.Size = Vector3.new(0.3, 0.3, 0.3) * s
		local pad = part(model, { Name = "ElbowPad", Size = Vector3.new(0.22, 0.22, 0.22) * s, Color = pink, Ellipsoid = true })
		attach(torso, pad, shoulder)
		sparkles(hand, cyan)
		if a[1] == "ArmR" then
			rig.NailPoint = Instance.new("Attachment")
			rig.NailPoint.Name = "NailPoint"
			rig.NailPoint.Parent = hand
		end
	end
	-- Short stubby legs (animated) with navy boots.
	for i, side in ipairs({ -1, 1 }) do
		local hip = CFrame.new(side * 0.2 * s, -0.4 * s, 0)
		local _, foot = limb(model, torso, rig, "Leg" .. i, hip, 0.4 * s, 0.22 * s, blue, navy)
		foot.Size = Vector3.new(0.3, 0.26, 0.4) * s
	end
	return model, rig
end

-- Act 1 has two looks: "Mascot" (default) or "Classic" (the pink star
-- creature from the drawings). Switch in TuskConfig.StandModels[1].Style.
local function buildAct1(scale)
	local settings = TuskConfig.StandModels and TuskConfig.StandModels[1] or {}
	if settings.Style == "Classic" then
		return buildAct1Classic(scale)
	end
	return buildAct1Mascot(scale)
end

local function buildAct3(scale)
	local s = scale * 1.15
	local pink = Color3.fromRGB(226, 110, 178)
	local pinkDark = Color3.fromRGB(170, 70, 135)
	local navy = Color3.fromRGB(44, 52, 120)
	local blue = Color3.fromRGB(70, 90, 190)
	local lens = Color3.fromRGB(96, 92, 190)
	local steel = Color3.fromRGB(150, 155, 165)
	local red = Color3.fromRGB(210, 60, 40)
	local yellow = Color3.fromRGB(255, 200, 60)
	local starGold = Color3.fromRGB(240, 170, 60)

	local model = Instance.new("Model")
	model.Name = "TuskAct3"
	local bodySize = Vector3.new(2.0, 1.8, 2.3) * s
	local h = bodySize / 2
	local body = part(model, { Name = "Body", Size = bodySize, Color = pink, Ellipsoid = true, Massless = false })
	body.CFrame = CFrame.Angles(0.35, 0, 0) -- leans forward like it's about to pounce
	body.Anchored = true
	model.PrimaryPart = body
	local rig = { Body = body, Joints = {} }

	local back = part(model, { Name = "BackShade", Size = bodySize * Vector3.new(0.9, 0.7, 0.8), Color = pinkDark, Ellipsoid = true })
	attach(body, back, CFrame.new(0, -0.3 * s, 0.25 * s))

	-- Dark mohawk crest running front to back over the top.
	local crest = part(model, { Name = "Crest", Size = Vector3.new(0.16, 1.1, 2.0) * s, Color = navy, Ellipsoid = true })
	attach(body, crest, CFrame.new(0, 0.85 * s, -0.15 * s))
	-- Antennae with grey balls.
	for _, side in ipairs({ -1, 1 }) do
		local base = Vector3.new(side * 0.55 * s, 0.6 * s, -0.7 * s)
		local tipPos = base + Vector3.new(side * 0.45, 0.45, -0.2) * s
		local rod = part(model, { Name = "Antenna", Shape = Enum.PartType.Cylinder, Size = Vector3.new((tipPos - base).Magnitude, 0.04 * s, 0.04 * s), Color = pinkDark })
		attach(body, rod, CFrame.lookAt((base + tipPos) / 2, tipPos) * CFrame.Angles(0, math.pi / 2, 0))
		local ball = part(model, { Name = "AntennaBall", Size = Vector3.new(0.14, 0.14, 0.14) * s, Color = steel, Material = Enum.Material.Metal, Ellipsoid = true })
		attach(body, ball, CFrame.new(tipPos))
	end

	-- Face mask at the front: plate, two eye slits, slotted mouth.
	local facePos = onSurface(h, Vector3.new(0, -0.15, -1), 0.96)
	local mask = part(model, { Name = "Mask", Size = Vector3.new(0.85, 0.8, 0.3) * s, Color = Color3.fromRGB(236, 130, 190), Ellipsoid = true })
	attach(body, mask, CFrame.new(facePos))
	for _, side in ipairs({ -1, 1 }) do
		local slit = part(model, { Name = "EyeSlit", Size = Vector3.new(0.06, 0.24, 0.06) * s, Color = Color3.fromRGB(40, 20, 40) })
		attach(body, slit, CFrame.new(facePos + Vector3.new(side * 0.09 * s, 0.12 * s, -0.14 * s)))
	end
	for i = -2, 2 do
		local tooth = part(model, { Name = "MouthSlot", Size = Vector3.new(0.09, 0.14, 0.06) * s, Color = Color3.fromRGB(60, 25, 55) })
		attach(body, tooth, CFrame.new(facePos + Vector3.new(i * 0.13 * s, -0.2 * s, -0.12 * s)))
	end
	-- Little gold stars over the body.
	for i, d in ipairs({ Vector3.new(0.6, 0.6, -0.5), Vector3.new(-0.55, 0.5, -0.6), Vector3.new(0.75, 0.1, 0.4), Vector3.new(-0.7, 0.2, 0.4), Vector3.new(0.3, 0.85, 0.3), Vector3.new(-0.35, 0.8, -0.2), Vector3.new(0.5, -0.3, -0.8) }) do
		star5(model, body, onSurface(h, d, 1.01), d, 0.22 * s, starGold, i)
	end

	-- Purple-blue belly lens underneath.
	local lensPart = part(model, { Name = "BellyLens", Size = Vector3.new(1.0, 1.25, 0.6) * s, Color = lens, Material = Enum.Material.Glass, Reflectance = 0.2, Ellipsoid = true })
	attach(body, lensPart, CFrame.new(0, -0.95 * s, -0.25 * s) * CFrame.Angles(-0.5, 0, 0))
	local lensRim = part(model, { Name = "LensRim", Size = Vector3.new(1.1, 1.35, 0.5) * s, Color = pinkDark, Ellipsoid = true })
	attach(body, lensRim, CFrame.new(0, -0.92 * s, -0.17 * s) * CFrame.Angles(-0.5, 0, 0))
	-- Hip pistons (springs) from body to hips.
	for _, side in ipairs({ -1, 1 }) do
		local piston = part(model, { Name = "Piston", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 0.08, 0.08) * s, Color = steel, Material = Enum.Material.Metal })
		attach(body, piston, CFrame.new(side * 0.55 * s, -0.95 * s, 0.15 * s) * CFrame.Angles(0, 0, math.pi / 2 + side * 0.3))
	end

	-- Blue shoulder balls with red stars.
	for _, side in ipairs({ -1, 1 }) do
		local center = Vector3.new(side * 1.08 * s, 0.1 * s, -0.15 * s)
		local ball = part(model, { Name = "ShoulderBall", Size = Vector3.new(0.95, 0.95, 0.95) * s, Color = blue, Material = Enum.Material.SmoothPlastic, Reflectance = 0.1, Ellipsoid = true })
		attach(body, ball, CFrame.new(center))
		local starDir = Vector3.new(side * 0.8, 0.1, -0.6)
		star5(model, body, center + starDir.Unit * 0.47 * s, starDir, 0.62 * s, yellow, 0.2)
		star5(model, body, center + starDir.Unit * 0.49 * s, starDir, 0.48 * s, red, 0.2)
	end

	-- Arms: grey joints, long thin pink segments, three-spike claws.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local shoulder = CFrame.new(a[2] * 1.15 * s, -0.25 * s, -0.25 * s) * CFrame.Angles(0.25, 0, a[2] * 0.25)
		local _, hand = limb(model, body, rig, a[1], shoulder, 1.0 * s, 0.22 * s, pink, steel)
		local wrist = segment(model, hand, 0.95 * s, 0.2 * s, pink, a[2] * -0.5, steel)
		local claw = part(model, { Name = "ClawDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, 0.4, 0.4) * s, Color = navy, Material = Enum.Material.Metal })
		attach(wrist, claw, CFrame.new(-0.05 * s, 0, 0))
		spikes(model, wrist, 0.7 * s, steel)
		if a[1] == "ArmR" then
			rig.NailPoint = Instance.new("Attachment")
			rig.NailPoint.Name = "NailPoint"
			rig.NailPoint.Parent = wrist
		end
	end

	-- Legs: thighs, knee joints, shins with little stars, pointed spiked feet.
	for i, side in ipairs({ -1, 1 }) do
		local hip = CFrame.new(side * 0.5 * s, -1.25 * s, 0.25 * s) * CFrame.Angles(-0.25, 0, side * 0.12)
		local _, knee = limb(model, body, rig, "Leg" .. i, hip, 0.95 * s, 0.25 * s, pink, steel)
		local ankle = segment(model, knee, 1.0 * s, 0.22 * s, pink, side * 0.35, steel)
		local foot = part(model, { Name = "Foot", Size = Vector3.new(0.3, 0.5, 0.3) * s, Color = pinkDark, Ellipsoid = true })
		attach(ankle, foot, CFrame.new(-0.12 * s, 0, 0))
		spikes(model, ankle, 0.55 * s, steel)
	end
	return model, rig
end

---------------------------------------------------------------------------
-- ACT 4 (from the owner's reference images): an armoured pink humanoid
-- with a slotted helmet, layered shoulder armour, blue gloves and boots,
-- yellow stars on the legs and a long skirt of hanging pink scales.
---------------------------------------------------------------------------
local function buildAct4(scale)
	local s = scale * 1.3
	local pink = Color3.fromRGB(240, 150, 200)
	local pinkLight = Color3.fromRGB(252, 190, 222)
	local pinkDark = Color3.fromRGB(196, 100, 160)
	local glove = Color3.fromRGB(70, 110, 170)
	local yellow = Color3.fromRGB(255, 210, 60)
	local gold = Color3.fromRGB(235, 185, 70)

	local model = Instance.new("Model")
	model.Name = "TuskAct4"
	local torso = part(model, { Name = "Body", Size = Vector3.new(1.7, 1.6, 1.15) * s, Color = pink, Ellipsoid = true, Massless = false })
	torso.CFrame = CFrame.new()
	torso.Anchored = true
	model.PrimaryPart = torso
	local rig = { Body = torso, Joints = {} }

	-- Chest armour plates and a small emblem.
	for _, side in ipairs({ -1, 1 }) do
		local plate = part(model, { Name = "ChestPlate", Size = Vector3.new(0.8, 0.75, 0.3) * s, Color = pinkLight, Ellipsoid = true })
		attach(torso, plate, CFrame.new(side * 0.38 * s, 0.25 * s, -0.48 * s) * CFrame.Angles(0, side * 0.2, 0))
	end
	local emblem = part(model, { Name = "Emblem", Size = Vector3.new(0.18, 0.18, 0.05) * s, Color = gold, Material = Enum.Material.Metal, Ellipsoid = true })
	attach(torso, emblem, CFrame.new(-0.4 * s, 0.35 * s, -0.66 * s))
	local waist = part(model, { Name = "Waist", Size = Vector3.new(1.2, 0.6, 0.9) * s, Color = pinkDark, Ellipsoid = true })
	attach(torso, waist, CFrame.new(0, -0.85 * s, 0))

	-- Helmet: dome, slotted visor, side ridges.
	local head = part(model, { Name = "Head", Size = Vector3.new(0.85, 1.0, 0.9) * s, Color = pink, Ellipsoid = true })
	attach(torso, head, CFrame.new(0, 1.15 * s, -0.08 * s))
	local hcf = CFrame.new(0, 1.15 * s, -0.08 * s)
	local visor = part(model, { Name = "Visor", Size = Vector3.new(0.55, 0.55, 0.2) * s, Color = pinkLight, Ellipsoid = true })
	attach(torso, visor, hcf * CFrame.new(0, -0.08 * s, -0.4 * s))
	for i = -2, 2 do
		local slot = part(model, { Name = "VisorSlot", Size = Vector3.new(0.05, 0.36, 0.05) * s, Color = Color3.fromRGB(80, 30, 70) })
		attach(torso, slot, hcf * CFrame.new(i * 0.09 * s, -0.08 * s, -0.5 * s))
	end
	local ridge = part(model, { Name = "HelmetRidge", Size = Vector3.new(0.12, 0.6, 0.9) * s, Color = pinkDark, Ellipsoid = true })
	attach(torso, ridge, hcf * CFrame.new(0, 0.35 * s, 0.05 * s))
	-- Head fins animate like ears.
	for _, e in ipairs({ { "EarL", -1 }, { "EarR", 1 } }) do
		local base = hcf * CFrame.new(e[2] * 0.4 * s, 0.05 * s, 0.05 * s) * CFrame.Angles(0, 0, -e[2] * 1.2)
		local fin = part(model, { Name = e[1], Size = Vector3.new(0.18, 0.45, 0.35) * s, Color = pinkDark, Ellipsoid = true })
		local offset = CFrame.new(0, 0.18 * s, 0)
		local w = attach(torso, fin, base * offset)
		rig.Joints[e[1]] = { Weld = w, Base = base, Offset = offset }
	end

	-- Layered shoulder armour, armoured arms, blue gloves.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		for layer = 0, 2 do
			local pad = part(model, { Name = "ShoulderPad", Size = Vector3.new(0.8 - layer * 0.12, 0.35, 0.85 - layer * 0.1) * s, Color = layer % 2 == 0 and pink or pinkLight, Ellipsoid = true })
			attach(torso, pad, CFrame.new(a[2] * (0.95 + layer * 0.05) * s, (0.62 - layer * 0.2) * s, 0) * CFrame.Angles(0, 0, -a[2] * (0.35 + layer * 0.1)))
		end
		-- Arms held out from the sides so the blue gloves clear the scale skirt.
		local shoulder = CFrame.new(a[2] * 1.05 * s, 0.3 * s, 0) * CFrame.Angles(0, 0, a[2] * 0.5)
		local _, elbow = limb(model, torso, rig, a[1], shoulder, 1.05 * s, 0.34 * s, pink, pinkLight)
		local wrist = segment(model, elbow, 1.0 * s, 0.3 * s, pink, a[2] * -0.3)
		local hand = part(model, { Name = "Glove", Size = Vector3.new(0.48, 0.42, 0.34) * s, Color = glove, Ellipsoid = true })
		attach(wrist, hand, CFrame.new(-0.2 * s, 0, 0))
		if a[1] == "ArmR" then
			rig.NailPoint = Instance.new("Attachment")
			rig.NailPoint.Name = "NailPoint"
			rig.NailPoint.Parent = hand
		end
	end

	-- Armoured legs, blue boots, yellow stars.
	for i, side in ipairs({ -1, 1 }) do
		local hip = CFrame.new(side * 0.4 * s, -1.05 * s, 0) * CFrame.Angles(0, 0, side * 0.05)
		local _, knee = limb(model, torso, rig, "Leg" .. i, hip, 1.2 * s, 0.42 * s, pink, pinkLight)
		local ankle = segment(model, knee, 1.15 * s, 0.38 * s, pink, 0)
		local boot = part(model, { Name = "Boot", Size = Vector3.new(0.5, 0.45, 0.8) * s, Color = glove, Ellipsoid = true })
		attach(ankle, boot, CFrame.new(-0.15 * s, 0, -0.15 * s))
		star5(model, knee, Vector3.new(-0.45 * s, 0, -0.2 * s), Vector3.new(0, 0, -1), 0.4 * s, yellow, i)
	end

	-- The skirt: rows of hanging pink scales from the chest down to the knees.
	local rows = 5
	for row = 0, rows - 1 do
		local y = (-0.35 - row * 0.42) * s
		local radius = (0.95 + row * 0.12) * s
		local count = 12 + row * 2
		for k = 0, count - 1 do
			local a = (k + (row % 2) * 0.5) / count * math.pi * 2
			local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
			local pos = Vector3.new(dir.X * radius, y, dir.Z * radius * 0.85)
			local scaleSize = Vector3.new(0.34, 0.5, 0.06) * s
			local scalePart = part(model, { Name = "Scale", Size = scaleSize, Color = (k + row) % 3 == 0 and pinkLight or pink, Ellipsoid = true })
			-- Face outward, hang down and flare out a little at the bottom.
			attach(torso, scalePart, CFrame.lookAt(pos, pos + dir) * CFrame.Angles(-0.25 - row * 0.04, 0, 0))
		end
	end
	return model, rig
end

local builders = {
	[1] = buildAct1,
	[2] = buildAct2,
	[3] = buildAct3,
	[4] = buildAct4,
}

-- Round pieces that make each Act recognisable as Tusk (kept smooth when blocky).
local SIGNATURE_ROUND = {
	[1] = { Body = true, Belly = true, Chin = true, Eye = true, Lid = true, Pupil = true, Highlight = true, Shine = true, HeartLobe = true, PinHead = true, Mouth = true, Head = true, Chest = true },
	[2] = { Body = true, Head = true, Cheek = true, EarDisc = true, Drum = true, DrumRim = true, DrumHole = true, Pod = true, PodHole = true, Visor = true },
	[3] = { Body = true, BackShade = true, ShoulderBall = true, BellyLens = true, LensRim = true, Mask = true },
	[4] = { Head = true, Visor = true, HelmetRidge = true, Emblem = true },
}

function TuskStandModels.build(act, scale)
	scale = scale or 1
	local model, rig = override(act, scale)
	if model then
		return model, rig
	end
	local builder = builders[act]
	if not builder then
		return nil
	end
	local built, rig = builder(scale)
	-- Blocky (classic Roblox) look for the procedural Stands; custom models are
	-- left as they are. Each Act keeps its signature round shapes smooth so it
	-- still reads as Tusk (egg body and face, ear discs, ball body, dome head...).
	if built and Blockify.enabled(TuskConfig) then
		Blockify.apply(built, { KeepRound = SIGNATURE_ROUND[act] })
	end
	return built, rig
end

return TuskStandModels
end

-- ======================================================================
-- MODULE: VFXQuality
-- ======================================================================
__modules["VFXQuality"] = function()
--[[
	VFXQuality  (ReplicatedStorage.SpinShared.VFXQuality)

	Per-player visual quality. Purely client-side: it never changes gameplay.
	Every effect asks VFXQuality.get() before spawning detail.
]]

local VFXQuality = {}

VFXQuality.Presets = {
	Low = {
		Particles = 0.3, -- multiplier on particle counts
		RingSegments = 12, -- beam segments per energy ring
		Grooves = false, -- steel ball surface grooves
		Afterimages = false,
		ScreenEffects = false, -- speed lines, FOV punch
		ImpactFrames = false,
		Lights = false,
		MaxActiveEffects = 12,
		ShakeScale = 0.6,
	},
	Medium = {
		Particles = 0.65,
		RingSegments = 18,
		Grooves = true,
		Afterimages = false,
		ScreenEffects = true,
		ImpactFrames = false,
		Lights = true,
		MaxActiveEffects = 24,
		ShakeScale = 1,
	},
	High = {
		Particles = 1,
		RingSegments = 28,
		Grooves = true,
		Afterimages = true,
		ScreenEffects = true,
		ImpactFrames = true,
		Lights = true,
		MaxActiveEffects = 40,
		ShakeScale = 1,
	},
}

VFXQuality.Order = { "Low", "Medium", "High" }

local current = "Medium"
local changed = Instance.new("BindableEvent")
VFXQuality.Changed = changed.Event

function VFXQuality.get()
	return VFXQuality.Presets[current], current
end

function VFXQuality.set(name)
	if VFXQuality.Presets[name] and name ~= current then
		current = name
		changed:Fire(name)
	end
end

function VFXQuality.cycle()
	for i, name in ipairs(VFXQuality.Order) do
		if name == current then
			VFXQuality.set(VFXQuality.Order[i % #VFXQuality.Order + 1])
			return current
		end
	end
	return current
end

return VFXQuality
end

-- ======================================================================
-- MODULE: WreckingBallModel
-- ======================================================================
__modules["WreckingBallModel"] = function()
--[[
	WreckingBallModel  (ReplicatedStorage.SpinShared.WreckingBallModel)

	Procedurally builds a Wrecking Ball from the owner's reference image:
	a glossy orange metal sphere, ten raised gold studs sitting in darker
	gold collars, and a dark seam groove wrapping around the surface.
	Not used yet: kept for the Wrecking Ball phase.

	WreckingBallModel.build(diameter, withGrooves) -> Model (PrimaryPart = "Core")

	All parts are visual only: no collision, no queries, no touch events,
	massless, and welded to the Core. Anchor the Core to move it with
	PivotTo, or weld the Core to a hand.

	Swapping in a real mesh later: put a Model named "WreckingBall" (with a
	PrimaryPart) in ReplicatedStorage.SpinShared.Assets and build() will
	clone it instead of generating one.
]]

local WreckingBallModel = {}

WreckingBallModel.Colors = {
	Ball = Color3.fromRGB(226, 96, 24),
	BallDark = Color3.fromRGB(150, 52, 12),
	Stud = Color3.fromRGB(255, 205, 70),
}

local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))
local STUD_COUNT = 10
local SEAM_SEGMENTS = 22

local function visualPart(props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function weld(core, part)
	local w = Instance.new("WeldConstraint")
	w.Part0 = core
	w.Part1 = part
	w.Parent = part
end

local function fromOverride(diameter)
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
	local custom = assets and assets:FindFirstChild("WreckingBall")
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		local clone = custom:Clone()
		local size = clone:GetExtentsSize()
		local largest = math.max(size.X, size.Y, size.Z)
		if largest > 0 then
			clone:ScaleTo(clone:GetScale() * diameter / largest)
		end
		clone.PrimaryPart.Name = "Core"
		return clone
	end
	return nil
end

function WreckingBallModel.build(diameter, withGrooves)
	diameter = diameter or 1
	if withGrooves == nil then
		withGrooves = true
	end

	local override = fromOverride(diameter)
	if override then
		return override
	end

	local colors = WreckingBallModel.Colors
	local r = diameter / 2

	local model = Instance.new("Model")
	model.Name = "WreckingBall"

	local core = visualPart({
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		Color = colors.Ball,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.2,
		Massless = false,
	})
	core.CFrame = CFrame.new()
	core.Parent = model
	model.PrimaryPart = core

	-- Attachments other systems hook effects onto.
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = core
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, r * 0.9, 0)
	top.Parent = core
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -r * 0.9, 0)
	bottom.Parent = core

	-- Gold studs on a Fibonacci sphere so they spread evenly.
	for i = 0, STUD_COUNT - 1 do
		local y = 1 - (i + 0.5) / STUD_COUNT * 2
		local ring = math.sqrt(1 - y * y)
		local theta = i * GOLDEN_ANGLE
		local dir = Vector3.new(math.cos(theta) * ring, y, math.sin(theta) * ring)
		local up = math.abs(dir.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)

		local collar = visualPart({
			Name = "StudCollar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(diameter * 0.05, diameter * 0.2, diameter * 0.2),
			Color = colors.BallDark:Lerp(colors.Stud, 0.35),
			Material = Enum.Material.Metal,
			Reflectance = 0.1,
		})
		-- Cylinder axis is X, so point RightVector along the surface normal.
		local right = dir
		local back = right:Cross(up).Unit
		local realUp = back:Cross(right).Unit
		collar.CFrame = CFrame.fromMatrix(dir * r * 0.985, right, realUp)
		collar.Parent = model
		weld(core, collar)

		local stud = visualPart({
			Name = "Stud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(diameter * 0.15, diameter * 0.15, diameter * 0.15),
			Color = colors.Stud,
			Material = Enum.Material.Metal,
			Reflectance = 0.35,
		})
		stud.CFrame = CFrame.new(dir * r * 1.01)
		stud.Parent = model
		weld(core, stud)
	end

	-- Seam groove: a wave wrapping the ball like a tennis-ball seam.
	if withGrooves then
		local function seamPoint(t)
			local lon = t * math.pi * 2
			local lat = 0.55 * math.sin(2 * lon)
			return Vector3.new(math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon)) * r * 1.003
		end
		for i = 0, SEAM_SEGMENTS - 1 do
			local a = seamPoint(i / SEAM_SEGMENTS)
			local b = seamPoint((i + 1) / SEAM_SEGMENTS)
			local mid = (a + b) / 2
			local len = (b - a).Magnitude
			local seg = visualPart({
				Name = "Groove",
				Size = Vector3.new(diameter * 0.035, diameter * 0.012, len * 1.08),
				Color = colors.BallDark,
				Material = Enum.Material.SmoothPlastic,
			})
			seg.CFrame = CFrame.lookAt(mid, b, mid.Unit)
			seg.Parent = model
			weld(core, seg)
		end
	end

	-- Everything was laid out around the origin; move the model as one piece from here on.
	return model
end

return WreckingBallModel
end

-- ======================================================================
-- START
-- ======================================================================
local ProjectileService = __require("ProjectileService")
local TuskService = __require("TuskService")
local NPCService = __require("NPCService")
local TestDummies = __require("TestDummies")
__require("StandAssetLoader").init()

ProjectileService.MaxActivePerPlayer = 20
TuskService.init()
__require("GyroOutfit").init()
__require("DiegoOutfit").init()
if BUILD_MAP_ON_START and not workspace:FindFirstChild("SBRMap") then
	local ok, err = pcall(function()
		__require("SBRMapBuilder").Build({ Origin = MAP_ORIGIN })
	end)
	if not ok then
		warn("[Spin] Map build failed: " .. tostring(err))
	end
end
NPCService.init()
TestDummies.init()
print("[Spin] Server ready")
