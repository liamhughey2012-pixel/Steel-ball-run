--[[
	Sandman_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Sandman (Soundman): In a Silent Way.
	Its other half is Sandman_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: Sandman
-- ======================================================================
__modules["Sandman"] = function()
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

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

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
end

-- ======================================================================
-- MODULE: SandmanOutfit
-- ======================================================================
__modules["SandmanOutfit"] = function()
--[[
	SandmanOutfit  (ServerScriptService.SpinServer.SandmanOutfit)

	Gives a character Sandman's look while they play him (TuskAct 8), built
	from blocky parts (no catalog asset ids):
	  * long straight black hair down his back with side locks
	  * a red-and-white beaded headband with a feather at the back
	  * a sand-coloured scarf, a sleeveless sand vest with a dark trim
	  * a red sash with a hanging pouch, wrapped forearms and shins
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local SandmanOutfit = {}
SandmanOutfit.Act = 8

local C = {
	Hair = Color3.fromRGB(25, 22, 24),
	HairShine = Color3.fromRGB(55, 50, 55),
	Band = Color3.fromRGB(190, 50, 45),
	Bead = Color3.fromRGB(240, 235, 220),
	Feather = Color3.fromRGB(245, 240, 230),
	FeatherTip = Color3.fromRGB(40, 35, 35),
	Scarf = Color3.fromRGB(230, 200, 140),
	Vest = Color3.fromRGB(205, 165, 105),
	Trim = Color3.fromRGB(110, 70, 40),
	Sash = Color3.fromRGB(180, 45, 40),
	Pouch = Color3.fromRGB(120, 80, 45),
	Wrap = Color3.fromRGB(235, 220, 190),
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

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Hair: a cap over the top, a long sheet down the back, locks at the sides.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.12 * s, 0.3 * s, head.Size.Z + 0.12 * s), C.Hair, CFrame.new(0, h - 0.05 * s, 0.02 * s))
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.12 * s, head.Size.Y * 0.9, 0.2 * s), C.Hair, CFrame.new(0, 0.05 * s, d + 0.08 * s))
	piece(head, outfit, "HairLong", Vector3.new(head.Size.X * 0.9, 2.2 * s, 0.22 * s), C.Hair, CFrame.new(0, -1.5 * s, d + 0.2 * s) * CFrame.Angles(-0.12, 0, 0))
	piece(head, outfit, "HairShine", Vector3.new(0.12 * s, 2.0 * s, 0.05 * s), C.HairShine, CFrame.new(0.2 * s, -1.4 * s, d + 0.33 * s) * CFrame.Angles(-0.12, 0, 0))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HairLock", Vector3.new(0.2 * s, 1.2 * s, 0.35 * s), C.Hair, CFrame.new(side * (w + 0.08 * s), -0.25 * s, -0.05 * s))
	end
	-- Beaded headband round the forehead.
	local bandY = h * 0.42
	piece(head, outfit, "Band", Vector3.new(head.Size.X + 0.18 * s, 0.18 * s, head.Size.Z + 0.18 * s), C.Band, CFrame.new(0, bandY, 0))
	for i = -2, 2 do
		piece(head, outfit, "Bead", Vector3.new(0.1, 0.1, 0.04) * s, C.Bead, CFrame.new(i * 0.2 * s, bandY, -d - 0.1 * s))
	end
	-- Feather tucked in at the back.
	local feather = CFrame.new(0.25 * s, bandY + 0.5 * s, d + 0.15 * s) * CFrame.Angles(-0.35, 0, -0.3)
	piece(head, outfit, "Feather", Vector3.new(0.08, 1.1, 0.26) * s, C.Feather, feather)
	piece(head, outfit, "FeatherTip", Vector3.new(0.09, 0.28, 0.27) * s, C.FeatherTip, feather * CFrame.new(0, 0.45 * s, 0))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		-- Sleeveless vest, open down the front.
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Vest", Vector3.new(s.X * 0.42, s.Y + 0.04, s.Z + 0.1), C.Vest, CFrame.new(side * s.X * 0.29, 0, 0))
			piece(upper, outfit, "Trim", Vector3.new(0.12, s.Y + 0.06, 0.06), C.Trim, CFrame.new(side * s.X * 0.08, 0, -s.Z / 2 - 0.07))
		end
		piece(upper, outfit, "VestBack", Vector3.new(s.X + 0.06, s.Y + 0.04, 0.08), C.Vest, CFrame.new(0, 0, s.Z / 2 + 0.04))
		-- Scarf round the neck, one end hanging.
		piece(upper, outfit, "Scarf", Vector3.new(s.X * 0.75, 0.3, s.Z + 0.25), C.Scarf, CFrame.new(0, s.Y / 2 + 0.05, 0))
		piece(upper, outfit, "ScarfEnd", Vector3.new(0.35, 0.9, 0.1), C.Scarf, CFrame.new(-s.X * 0.18, s.Y / 2 - 0.45, -s.Z / 2 - 0.1) * CFrame.Angles(0, 0, 0.15))
	end
	local waist = lower or upper
	if waist then
		local y = lower and 0 or -upper.Size.Y / 2 + 0.15
		piece(waist, outfit, "Sash", Vector3.new(waist.Size.X + 0.12, 0.3, waist.Size.Z + 0.12), C.Sash, CFrame.new(0, y, 0))
		piece(waist, outfit, "SashTail", Vector3.new(0.3, 0.9, 0.08), C.Sash, CFrame.new(waist.Size.X * 0.3, y - 0.5, -waist.Size.Z / 2 - 0.08))
		piece(waist, outfit, "Pouch", Vector3.new(0.45, 0.5, 0.3), C.Pouch, CFrame.new(-waist.Size.X / 2 - 0.1, y - 0.25, 0))
	end
	-- Sleeveless: bare arms over whatever shirt the avatar wears.
	local headPart = character:FindFirstChild("Head")
	local skin = headPart and headPart.Color or Color3.fromRGB(170, 115, 80)
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Skin", arm.Size + Vector3.new(0.04, 0.02, 0.04), skin, CFrame.new())
		end
	end
	-- Wrapped forearms and shins.
	for _, name in ipairs({ "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local y = -arm.Size.Y / 2 + (arm.Size.Y > 1.8 and 0.7 or 0.35)
			piece(arm, outfit, "Wrap", Vector3.new(arm.Size.X + 0.1, arm.Size.Y > 1.8 and 0.9 or 0.6, arm.Size.Z + 0.1), C.Wrap, CFrame.new(0, y, 0))
		end
	end
	for _, name in ipairs({ "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local y = -leg.Size.Y / 2 + (leg.Size.Y > 1.8 and 0.6 or 0.4)
			piece(leg, outfit, "Wrap", Vector3.new(leg.Size.X + 0.1, leg.Size.Y > 1.8 and 0.8 or 0.6, leg.Size.Z + 0.1), C.Wrap, CFrame.new(0, y, 0))
		end
	end
end

function SandmanOutfit.apply(character)
	if character:FindFirstChild("SandmanOutfit") then
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
	outfit.Name = "SandmanOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function SandmanOutfit.remove(character)
	local outfit = character:FindFirstChild("SandmanOutfit")
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
		if character:GetAttribute("TuskAct") == SandmanOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == SandmanOutfit.Act then
					SandmanOutfit.apply(character)
				end
			end)
		else
			SandmanOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function SandmanOutfit.init()
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

return SandmanOutfit
end
end
