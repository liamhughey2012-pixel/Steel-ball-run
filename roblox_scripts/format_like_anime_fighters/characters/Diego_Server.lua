--[[
	Diego_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Diego Brando: Scary Monsters.
	Its other half is Diego_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "diego" or __expect.Side ~= "server") then
		error("this is the code for Diego_Server, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Diego_Server and put it in ServerScriptService > SpinCharacters).", 0)
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

return DiegoOutfit
end
end
