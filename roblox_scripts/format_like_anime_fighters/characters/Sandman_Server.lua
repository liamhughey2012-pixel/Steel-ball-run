--[[
	Sandman_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Sandman (Soundman): In a Silent Way.
	Its other half is Sandman_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "sandman" or __expect.Side ~= "server") then
		error("this is the code for Sandman_Server, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Sandman_Server and put it in ServerScriptService > SpinCharacters).", 0)
	end

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
	from blocky parts (no catalog asset ids), matched to his art:
	  * mint-green hair over the top of his head with a black stripe down
	    the middle, two mint braids hanging in front tied with gold beads,
	    and a long black ponytail down his back
	  * a yellow collar round his shoulders with a black zigzag
	  * a bare chest with the red chevron tattoo and green shoulder tattoos
	  * a dark red corset studded with gold
	  * a sand-coloured loincloth with gold pyramid studs and hanging flaps
	  * yellow arm bands and long yellow gauntlets
	  * fringed sand leg wraps under the knees and at the ankles, black
	    shin bands and bare feet with sandal straps
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local SandmanOutfit = {}
SandmanOutfit.Act = 8

local C = {
	Mint = Color3.fromRGB(150, 210, 180),
	MintDark = Color3.fromRGB(110, 170, 145),
	Black = Color3.fromRGB(24, 22, 26),
	Bead = Color3.fromRGB(222, 178, 60),
	Yellow = Color3.fromRGB(240, 192, 50),
	YellowDark = Color3.fromRGB(200, 150, 30),
	Tattoo = Color3.fromRGB(180, 50, 60),
	TattooGreen = Color3.fromRGB(70, 140, 100),
	Corset = Color3.fromRGB(130, 46, 36),
	CorsetDark = Color3.fromRGB(96, 32, 26),
	Stud = Color3.fromRGB(222, 178, 60),
	Cloth = Color3.fromRGB(214, 196, 150),
	ClothDark = Color3.fromRGB(176, 156, 110),
	Wrap = Color3.fromRGB(205, 188, 145),
	Strap = Color3.fromRGB(120, 86, 56),
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
	-- Mint hair hugging the top of the head, a black stripe down the middle.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.12 * s, 0.34 * s, head.Size.Z + 0.12 * s), C.Mint, CFrame.new(0, h - 0.1 * s, 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.1 * s, 0.55 * s, head.Size.Z * 0.75), C.Mint, CFrame.new(side * (w + 0.04 * s), h - 0.38 * s, 0.12 * s))
	end
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.12 * s, 0.7 * s, 0.1 * s), C.Mint, CFrame.new(0, h - 0.4 * s, d + 0.04 * s))
	piece(head, outfit, "Stripe", Vector3.new(0.22 * s, 0.06 * s, head.Size.Z + 0.14 * s), C.Black, CFrame.new(0, h + 0.08 * s, 0.02 * s))
	piece(head, outfit, "Stripe", Vector3.new(0.22 * s, 0.3 * s, 0.06 * s), C.Black, CFrame.new(0, h - 0.12 * s, -d - 0.06 * s))
	-- Two braids hanging down in front of the shoulders, tied off with gold beads.
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (w - 0.02 * s)
		for i = 0, 5 do
			piece(head, outfit, "Braid", Vector3.new(0.2 * s, 0.24 * s, 0.2 * s), i % 2 == 0 and C.Mint or C.MintDark, CFrame.new(x, h - 0.5 * s - i * 0.22 * s, -d - 0.04 * s) * CFrame.Angles(0, 0, (i % 2 == 0 and 0.2 or -0.2)))
		end
		piece(head, outfit, "Bead", Vector3.new(0.16 * s, 0.14 * s, 0.16 * s), C.Bead, CFrame.new(x, h - 1.86 * s, -d - 0.04 * s))
		piece(head, outfit, "BraidTip", Vector3.new(0.12 * s, 0.2 * s, 0.12 * s), C.MintDark, CFrame.new(x, h - 2.02 * s, -d - 0.04 * s))
	end
	-- Long black ponytail down his back.
	for i = 0, 4 do
		piece(head, outfit, "Ponytail", Vector3.new((0.5 - i * 0.05) * s, 0.44 * s, 0.26 * s), C.Black, CFrame.new(0, h - 0.35 * s - i * 0.4 * s, d + 0.14 * s + i * 0.03 * s))
	end
end

local function body(character, outfit)
	local headPart = character:FindFirstChild("Head")
	local skin = headPart and headPart.Color or Color3.fromRGB(190, 130, 100)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		local r6 = not lower
		-- Bare chest.
		piece(upper, outfit, "Skin", s + Vector3.new(0.04, 0.02, 0.04), skin, CFrame.new())
		-- Yellow collar with a black zigzag, wrapping the shoulders.
		piece(upper, outfit, "Collar", Vector3.new(s.X + 0.16, 0.34, s.Z + 0.18), C.Yellow, CFrame.new(0, top - 0.12, 0))
		for i = -4, 4 do
			piece(upper, outfit, "Zigzag", Vector3.new(0.16, 0.16, 0.04), C.Black, CFrame.new(i * 0.22, top - 0.14, front - 0.11) * CFrame.Angles(0, 0, math.pi / 4))
		end
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.5, 0.14, s.Z + 0.12), C.Black, CFrame.new(0, top + 0.08, 0))
		-- Red chevron tattoo on his chest (his left), green tattoos on the shoulders.
		for i = 0, 2 do
			piece(upper, outfit, "Tattoo", Vector3.new(0.42, 0.07, 0.03), C.Tattoo, CFrame.new(0.45, top - 0.45 - i * 0.13, front - 0.03) * CFrame.Angles(0, 0, -0.35))
		end
		-- Dark red corset from under the chest down, studded with gold.
		local corsetH = r6 and s.Y * 0.5 or s.Y * 0.48
		local corsetY = -s.Y / 2 + corsetH / 2
		piece(upper, outfit, "Corset", Vector3.new(s.X + 0.12, corsetH, s.Z + 0.12), C.Corset, CFrame.new(0, corsetY, 0))
		piece(upper, outfit, "Corset", Vector3.new(s.X * 0.5, 0.18, 0.06), C.Corset, CFrame.new(0, corsetY + corsetH / 2 + 0.06, front - 0.07))
		piece(upper, outfit, "CorsetSeam", Vector3.new(0.08, corsetH, 0.03), C.CorsetDark, CFrame.new(0, corsetY, front - 0.08))
		for _, x in ipairs({ -0.75, -0.4, 0.4, 0.75 }) do
			for k = 0, 1 do
				piece(upper, outfit, "Stud", Vector3.new(0.1, 0.1, 0.05), C.Stud, CFrame.new(x, corsetY + corsetH / 2 - 0.12 - k * (corsetH - 0.24), front - 0.08))
			end
		end
	end
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.35
		if lower then
			piece(lower, outfit, "Corset", ws + Vector3.new(0.12, 0.02, 0.12), C.Corset, CFrame.new())
		end
		-- Loincloth: a band round the hips and flaps hanging front and back.
		local bandY = waistTop - 0.32
		piece(waist, outfit, "Loincloth", Vector3.new(ws.X + 0.22, 0.36, ws.Z + 0.22), C.Cloth, CFrame.new(0, bandY, 0))
		piece(waist, outfit, "Flap", Vector3.new(ws.X * 0.7, 0.9, 0.08), C.Cloth, CFrame.new(0, bandY - 0.6, -ws.Z / 2 - 0.13) * CFrame.Angles(-0.06, 0, 0))
		piece(waist, outfit, "Flap", Vector3.new(ws.X * 0.8, 0.8, 0.08), C.ClothDark, CFrame.new(0, bandY - 0.55, ws.Z / 2 + 0.13) * CFrame.Angles(0.06, 0, 0))
		for _, side in ipairs({ -1, 1 }) do
			piece(waist, outfit, "Flap", Vector3.new(0.08, 0.55, ws.Z * 0.8), C.ClothDark, CFrame.new(side * (ws.X / 2 + 0.13), bandY - 0.4, 0))
		end
		-- Gold pyramid studs on the cloth.
		for _, x in ipairs({ -0.65, 0, 0.65 }) do
			piece(waist, outfit, "Pyramid", Vector3.new(0.2, 0.2, 0.08), C.Stud, CFrame.new(x, bandY, -ws.Z / 2 - 0.14) * CFrame.Angles(0, 0, math.pi / 4))
		end
		piece(waist, outfit, "Pyramid", Vector3.new(0.2, 0.2, 0.08), C.Stud, CFrame.new(0, bandY - 0.95, -ws.Z / 2 - 0.2) * CFrame.Angles(0, 0, math.pi / 4))
	end
	-- Bare arms with a green tattoo on each shoulder, yellow band above the
	-- elbow and long yellow gauntlets.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local out = name:find("Left") and -1 or 1
			piece(arm, outfit, "Skin", as + Vector3.new(0.04, 0.02, 0.04), skin, CFrame.new())
			local tall = as.Y > 1.8
			if name:find("Upper") or tall then
				piece(arm, outfit, "Tattoo", Vector3.new(0.04, 0.32, 0.4), C.TattooGreen, CFrame.new(out * (as.X / 2 + 0.03), as.Y / 2 - 0.3, 0))
				piece(arm, outfit, "Armband", Vector3.new(as.X + 0.14, 0.3, as.Z + 0.14), C.Yellow, CFrame.new(0, tall and 0.15 or -as.Y / 2 + 0.2, 0))
			end
			if name:find("Lower") or tall then
				local gh = tall and as.Y * 0.42 or as.Y - 0.05
				piece(arm, outfit, "Gauntlet", Vector3.new(as.X + 0.16, gh, as.Z + 0.16), C.Yellow, CFrame.new(0, -as.Y / 2 + gh / 2, 0))
				piece(arm, outfit, "GauntletBand", Vector3.new(as.X + 0.18, 0.08, as.Z + 0.18), C.Black, CFrame.new(0, -as.Y / 2 + gh - 0.12, 0))
				piece(arm, outfit, "GauntletBand", Vector3.new(as.X + 0.18, 0.08, as.Z + 0.18), C.YellowDark, CFrame.new(0, -as.Y / 2 + 0.12, 0))
			end
		end
	end
	-- Bare legs, fringed wraps under the knee and at the ankle, black shin bands.
	local function fringe(leg, y)
		local ls = leg.Size
		piece(leg, outfit, "Wrap", Vector3.new(ls.X + 0.16, 0.2, ls.Z + 0.16), C.Wrap, CFrame.new(0, y, 0))
		for i = -2, 2 do
			piece(leg, outfit, "Fringe", Vector3.new(0.1, 0.24, 0.05), C.Wrap, CFrame.new(i * ls.X * 0.2, y - 0.2, -ls.Z / 2 - 0.1))
			piece(leg, outfit, "Fringe", Vector3.new(0.1, 0.24, 0.05), C.Wrap, CFrame.new(i * ls.X * 0.2, y - 0.2, ls.Z / 2 + 0.1))
		end
	end
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Skin", ls + Vector3.new(0.04, 0.02, 0.04), skin, CFrame.new())
			local tall = ls.Y > 1.8
			if name:find("Lower") or tall then
				local knee = tall and -0.05 or ls.Y / 2 - 0.12
				fringe(leg, knee)
				piece(leg, outfit, "ShinBand", Vector3.new(ls.X + 0.1, 0.34, ls.Z + 0.1), C.Black, CFrame.new(0, knee - 0.45, 0))
				fringe(leg, -ls.Y / 2 + 0.3)
			end
		end
	end
	-- Bare feet with a sandal strap.
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			local fs = foot.Size
			piece(foot, outfit, "Skin", fs + Vector3.new(0.04, 0.02, 0.04), skin, CFrame.new())
			piece(foot, outfit, "Strap", Vector3.new(fs.X + 0.08, 0.08, 0.14), C.Strap, CFrame.new(0, 0.02, -fs.Z * 0.15))
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
