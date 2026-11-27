--[[
	CorpseMoves  (ServerScriptService.SpinServer.CorpseMoves)

	Every character's CORPSE MOVE (V), unlocked while holding a Saint's
	Corpse part. One shared cooldown (TuskConfig.Corpse.Move.Cooldown); the
	ready time is the character attribute CorpseReadyAt (server time) for
	the HUD. Visuals: CorpseClient, from WorldFX "CorpseMove".
	  Johnny       GOLDEN SPIN NAIL: a huge golden spinning nail
	  Gyro         GOLDEN RECTANGLE: a spinning shockwave straight ahead
	  Diego        DINOSAUR CRASH: leaps to the aim point and slams down
	  Pork Pie     HOOK HARVEST: hooks yank everyone round him in
	  Sandman      SOUND BARRIER: dashes through enemies, then a blast
	  Mountain Tim LASSO CYCLONE: a spinning lasso pulls everyone in
	  Hot Pants    FLESH COCOON: heals and armours herself, then a burst
	  Blackmore    RAIN CURTAIN: a cone of frozen drops that cut and slow
	  Axl RO       GUILT FLOOD: guilt for everyone round him, and a hit
	  Valentine    CORPSE BLESSING: a few seconds untouchable, a heal, a pulse
	  Diego (AU)   REVOLVER: draws a six-shooter, fans six shots where he aims
	  Josuke (8)   PLUNDER: SOUND: everyone round him can't use abilities for a while
	  Tooru        UNAVOIDABLE CALAMITY: something falls on everyone round him
	  Jodio        HEAVY RAINFALL: a storm cloud over him crushes everyone round him
	  John Rod     ROD SNAP: the rod lashes out at everyone round John Rod (wherever it is)
	  Ringo        SECOND HAND: everyone round him loses 6 seconds (hit, dazed)
	  Jotaro       ORA BARRAGE: Star Platinum punches everyone round him, then a big ORA!
	  DIO          WRYYY: drains everyone round him (he heals)
	  Joseph       HAMON BEAT: a Hamon ripple through the ground round him
	  Polnareff    SWORD WHIRL: Silver Chariot's rapier spins round him
	  Rohan        OPEN BOOK: everyone round him flaps open like a book for a moment
	  Okuyasu      SPACE PULL: The Hand yanks everyone near in next to him
	  Kira         CONTACT DETONATION: Killer Queen blows up the ground round him
	  Josuke4      DORA BARRAGE: Crazy Diamond punches everyone round him, then a big DORA!
	With the COMPLETE corpse (all 8 parts), V is THE SAINT'S MIRACLE instead
	(TuskConfig.Corpse.Miracle), and afterwards every part scatters.
	All damage goes through S.hit (CombatAdapter).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local Registry = require(Shared.TuskActRegistry)
local Net = require(Shared.Net)
local Moves = require(script.Parent.TuskMoves)

local CorpseMoves = {}

local TuskConfig = require(Shared.TuskConfig)
CorpseMoves.Names = TuskConfig.Corpse.MoveNames

local WorldFX
local function fx(data)
	WorldFX = WorldFX or Net.get("WorldFX")
	WorldFX:FireAllClients("CorpseMove", data)
end

local function now()
	return workspace:GetServerTimeNow()
end

local function slow(S, target, key, multiplier, seconds)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	S.Adapter.setMoveModifier(humanoid, key, multiplier)
	local token = tostring({})
	target:SetAttribute(key .. "Token", token)
	task.delay(seconds, function()
		if humanoid.Parent and target:GetAttribute(key .. "Token") == token then
			S.Adapter.setMoveModifier(humanoid, key, nil)
			target:SetAttribute(key .. "Token", nil)
		end
	end)
end

-- Everyone in range (pulled toward `center` when pull is set).
local function around(S, player, center, radius, info, pull)
	local character = player.Character
	local count = 0
	for _, target in ipairs(S.Hitbox.inRadius(character, center, radius, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			local hitInfo = table.clone(info)
			hitInfo.Position = tr.Position
			hitInfo.Direction = pull and (center - tr.Position) or (tr.Position - center)
			if S.hit(player, target, hitInfo) then
				count = count + 1
			end
		end
	end
	return count
end

local USE = {}

USE.Johnny = function(S, player, state, character, root, aim)
	local dir = S.aim(aim, root)
	S.lock(state, 0.4)
	fx({ Character = character, Who = "Johnny", Phase = "Cast", Direction = dir })
	task.delay(0.2, function()
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		Moves.nail(S, player, state, {
			Origin = S.origin(char, r, Moves.HAND), Direction = dir, Speed = 210, Radius = 1.7, Range = 220,
			Style = "Spinning", Charge = 1, Damage = 15, Stun = 0.6, Knockback = 45, Launch = 12, Source = "CorpseNail",
		})
	end)
end

USE.Gyro = function(S, player, state, character, root, aim)
	local dir = Moves.flat(S.aim(aim, root))
	S.lock(state, 0.5)
	fx({ Character = character, Who = "Gyro", Phase = "Cast", Position = root.Position, Direction = dir, Length = 34 })
	task.delay(0.25, function()
		local _, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		local mid = r.Position + dir * 17
		Moves.boxHit(S, player, CFrame.lookAt(mid, mid + dir), Vector3.new(7, 7, 34), { Damage = 13, Stun = 0.7, Knockback = 35, Launch = 16, Direction = dir, Source = "CorpseSpin" }, 6)
	end)
end

USE.Diego = function(S, player, state, character, root, aim)
	local dir = Moves.flat(S.aim(aim, root))
	local to = Moves.safeStep(character, root, dir, 30) or root.Position
	S.lock(state, 0.7)
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	fx({ Character = character, Who = "Diego", Phase = "Leap", From = root.Position, To = to, Time = 0.45 })
	task.delay(0.45, function()
		character:SetAttribute(iframes, nil)
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		char:PivotTo(CFrame.lookAt(to, to + dir))
		around(S, player, to, 10, { Damage = 12, Stun = 0.7, Knockback = 30, Launch = 18, Source = "CorpseCrash" })
		fx({ Character = char, Who = "Diego", Phase = "Slam", Position = to, Radius = 10 })
	end)
end

USE.PorkPie = function(S, player, state, character, root)
	S.lock(state, 0.5)
	fx({ Character = character, Who = "PorkPie", Phase = "Cast", Position = root.Position, Radius = 20 })
	task.delay(0.3, function()
		local _, _, r = S.Adapter.getAlive(player)
		if r then
			around(S, player, r.Position, 20, { Damage = 11, Stun = 1.0, Knockback = 45, Source = "CorpseHooks" }, true)
		end
	end)
end

USE.Sandman = function(S, player, state, character, root, aim)
	local dir = Moves.flat(S.aim(aim, root))
	local to = Moves.safeStep(character, root, dir, 36)
	if not to then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return false
	end
	local from = root.Position
	S.lock(state, 0.5)
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	fx({ Character = character, Who = "Sandman", Phase = "Dash", From = from, To = to })
	task.delay(0.2, function()
		character:SetAttribute(iframes, nil)
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		char:PivotTo(CFrame.lookAt(to, to + dir))
		local mid = (from + to) / 2
		Moves.boxHit(S, player, CFrame.lookAt(mid, to), Vector3.new(7, 7, (to - from).Magnitude + 2), { Damage = 9, Stun = 0.6, Knockback = 10, Direction = dir, Source = "CorpseSound" }, 6)
		task.delay(0.45, function()
			around(S, player, mid, 9, { Damage = 6, Stun = 0.6, Knockback = 30, Launch = 18, Source = "CorpseSound" })
			fx({ Character = char, Who = "Sandman", Phase = "Boom", Position = mid })
		end)
	end)
end

USE.MountainTim = function(S, player, state, character, root)
	S.lock(state, 0.8)
	fx({ Character = character, Who = "MountainTim", Phase = "Spin", Position = root.Position, Radius = 14, Time = 0.8 })
	for i = 1, 3 do
		task.delay(i * 0.25, function()
			local _, _, r = S.Adapter.getAlive(player)
			if r then
				around(S, player, r.Position, 14, { Damage = 4, Stun = 0.5, Knockback = 25, Source = "CorpseLasso" }, true)
			end
		end)
	end
end

USE.HotPants = function(S, player, state, character, root)
	local _, humanoid = S.Adapter.getAlive(player)
	S.lock(state, 0.5)
	character:SetAttribute("Armored", true)
	fx({ Character = character, Who = "HotPants", Phase = "Cocoon", Position = root.Position, Time = 2 })
	for i = 1, 5 do
		task.delay(i * 0.3, function()
			if humanoid.Parent and humanoid.Health > 0 then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 6)
			end
		end)
	end
	task.delay(2, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		local _, _, r = S.Adapter.getAlive(player)
		if r then
			around(S, player, r.Position, 9, { Damage = 7, Stun = 0.6, Knockback = 30, Launch = 10, Source = "CorpseFlesh" })
			fx({ Character = character, Who = "HotPants", Phase = "Burst", Position = r.Position })
		end
	end)
end

USE.Blackmore = function(S, player, state, character, root, aim)
	local dir = Moves.flat(S.aim(aim, root))
	S.lock(state, 0.5)
	fx({ Character = character, Who = "Blackmore", Phase = "Curtain", Position = root.Position, Direction = dir, Range = 26, Cone = 70 })
	task.delay(0.3, function()
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		local cosLimit = math.cos(math.rad(35))
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, 26, 8)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			local off = tr and Vector3.new(tr.Position.X - r.Position.X, 0, tr.Position.Z - r.Position.Z)
			if tr and (off.Magnitude < 1 or off.Unit:Dot(dir) >= cosLimit) then
				if S.hit(player, target, { Damage = 12, Stun = 0.6, Knockback = 12, Direction = dir, Position = tr.Position, Source = "CorpseRain" }) then
					slow(S, target, "CorpseRain", 0.6, 2)
				end
			end
		end
	end)
end

USE.Axl = function(S, player, state, character, root)
	S.lock(state, 0.5)
	fx({ Character = character, Who = "Axl", Phase = "Flood", Position = root.Position, Radius = 22 })
	task.delay(0.3, function()
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, 22, 8)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.hit(player, target, { Damage = 8, Stun = 0.6, Knockback = 8, Direction = tr.Position - r.Position, Position = tr.Position, Source = "CorpseGuilt" }) then
				-- +2 guilt (the same stacks Axl's moves feed on).
				local g = math.min(5, (target:GetAttribute("Guilt") or 0) + 2)
				target:SetAttribute("Guilt", g)
				target:SetAttribute("GuiltAt", os.clock())
				S.fx("Ability", { Act = 12, Move = "Guilt", Phase = "Mark", Target = target, Stacks = g })
			end
		end
	end)
end

USE.Valentine = function(S, player, state, character, root)
	local _, humanoid = S.Adapter.getAlive(player)
	S.lock(state, 0.3)
	local iframes = S.Adapter.Settings.IFrameAttribute
	character:SetAttribute(iframes, true)
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 15)
	fx({ Character = character, Who = "Valentine", Phase = "Bless", Position = root.Position, Time = 2.5 })
	task.delay(2.5, function()
		if character.Parent then
			character:SetAttribute(iframes, nil)
		end
		local _, _, r = S.Adapter.getAlive(player)
		if r then
			around(S, player, r.Position, 12, { Damage = 9, Stun = 0.6, Knockback = 35, Source = "CorpseLight" })
			fx({ Character = character, Who = "Valentine", Phase = "Pulse", Position = r.Position, Radius = 12 })
		end
	end)
end

-- REVOLVER: he draws a six-shooter, aims and fans the hammer: six shots
-- where he's aiming (the last hits hardest), then twirls it and holsters it.
-- (In stopped time the bullets hang in the air like everything else.)
USE.DiegoAU = function(S, player, state, character, root, aim)
	local g = TuskConfig.DiegoAU and TuskConfig.DiegoAU.Revolver
	if not S.fireKnife or not g then
		return false
	end
	local total = g.Draw + g.Shots * g.Every
	S.lock(state, total + 0.25)
	local life = state.Life
	fx({ Character = character, Who = "DiegoAU", Phase = "Draw", Draw = g.Draw, Every = g.Every, Shots = g.Shots, Time = total + 0.6 })
	for i = 1, g.Shots do
		task.delay(g.Draw + (i - 1) * g.Every, function()
			local char, _, r = S.Adapter.getAlive(player)
			if not r or state.Life ~= life then
				return
			end
			local dir = S.aim(aim, r)
			-- A little spread as he fans the hammer.
			dir = (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles(math.rad((math.random() - 0.5) * 2.5), math.rad((math.random() - 0.5) * 3.5), 0)).LookVector
			local muzzle = S.origin(char, r, CFrame.new(1, 0.6, -2.4))
			local last = i == g.Shots
			S.fireKnife(player, state, {
				Origin = muzzle,
				Direction = dir,
				Speed = g.Speed,
				Radius = 0.5,
				Range = g.Range,
				Style = "Bullet",
				OnHit = function(target, position)
					S.hit(player, target, { Damage = last and g.LastShotDamage or g.Damage, Stun = g.Stun, Knockback = last and 20 or g.Knockback, Direction = dir, Position = position, Source = "DiegoAURevolver" })
				end,
			})
			fx({ Character = char, Who = "DiegoAU", Phase = "Shot", Index = i, Position = muzzle, Direction = dir, Last = last })
		end)
	end
end

-- PLUNDER: SOUND: Soft & Wet's bubbles steal the sound from everyone round
-- him: for a few seconds they can't use their abilities or ultimate.
USE.Josuke = function(S, player, state, character, root)
	local c = TuskConfig.Josuke and TuskConfig.Josuke.CorpseSilence or { Radius = 20, Time = 3.5, Damage = 5 }
	S.lock(state, 0.4)
	fx({ Character = character, Who = "Josuke", Phase = "Silence", Position = root.Position, Radius = c.Radius, Time = c.Time })
	task.delay(0.3, function()
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, c.Radius, 12)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.hit(player, target, { Damage = c.Damage, Stun = 0.4, Knockback = 6, Direction = tr.Position - r.Position, Position = tr.Position, Source = "JosukeSound" }) then
				target:SetAttribute("SilencedUntil", workspace:GetServerTimeNow() + c.Time)
			end
		end
	end)
end

-- UNAVOIDABLE CALAMITY: Wonder of U's misfortune falls on everyone round
-- him at once (a shadow under each, then the debris: step out of it!).
USE.Tooru = function(S, player, state, character, root)
	local c = TuskConfig.Tooru and TuskConfig.Tooru.CorpseCalamity or { Radius = 24, Delay = 0.6, Damage = 8, Stun = 0.7, Knockback = 12 }
	S.lock(state, 0.4)
	fx({ Character = character, Who = "Tooru", Phase = "Calamity", Position = root.Position, Radius = c.Radius })
	local kinds = { "Girder", "Pot", "Sign", "Branch" }
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, c.Radius, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			local spot = tr.Position
			local kind = kinds[math.random(1, #kinds)]
			-- A shadow under each of them (Tooru's visuals), then it lands.
			S.fx("Ability", { Act = 16, Move = "Debris", Phase = "Lock", Position = spot, Lock = c.Delay })
			task.delay(math.max(0, c.Delay - 0.3), function()
				S.fx("Ability", { Act = 16, Move = "Calamity", Phase = "Fall", Position = spot, Kind = kind, Radius = 5, FallTime = 0.3 })
			end)
			task.delay(c.Delay, function()
				local char = player.Character
				if char and target.Parent and (tr.Position - spot).Magnitude <= 5.5 then
					local away = Vector3.new(tr.Position.X - root.Position.X, 0, tr.Position.Z - root.Position.Z)
					S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1), Position = spot, Source = "TooruCorpse" })
				end
				S.fx("Ability", { Act = 16, Move = "Calamity", Phase = "Land", Position = spot, Kind = kind, Radius = 5 })
			end)
		end
	end
end

-- HEAVY RAINFALL: November Rain drops a storm cloud over him; a moment
-- later the rain comes down all at once on everyone round him.
USE.Jodio = function(S, player, state, character, root)
	local c = TuskConfig.Jodio and TuskConfig.Jodio.CorpseRain or { Radius = 20, Delay = 0.5, Damage = 9, Stun = 0.8 }
	S.lock(state, 0.4)
	local center = root.Position
	S.fx("Ability", { Character = character, Act = 17, Move = "HeavyRain", Phase = "Cloud", Position = center - Vector3.new(0, 3, 0), Radius = c.Radius, Time = c.Delay + 0.4, Windup = c.Delay })
	task.delay(c.Delay, function()
		local char, _, r = S.Adapter.getAlive(player)
		if not r then
			return
		end
		local hits = {}
		for _, target in ipairs(S.Hitbox.inRadius(char, center, c.Radius, 12)) do
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 4, Direction = Vector3.new(0, -1, 0), Position = tr.Position, Source = "JodioCorpse" }) then
				target:SetAttribute("SoakedUntil", workspace:GetServerTimeNow() + 5)
				table.insert(hits, tr.Position)
			end
		end
		S.fx("Ultimate", { Character = char, Act = 17, Phase = "Crush", Position = center, Radius = c.Radius, Hits = hits })
	end)
end

-- ROD SNAP: John Rod's rod lashes out in every direction at once, from
-- wherever John Rod is (even far away while it's being steered).
USE.JohnRod = function(S, player, state, character, root)
	local c = TuskConfig.JohnRod and TuskConfig.JohnRod.CorpseSnap or { Radius = 18, Damage = 8, Stun = 0.7 }
	S.lock(state, 0.4)
	local remote = character:GetAttribute("StandRemotePos")
	local center = typeof(remote) == "Vector3" and remote or root.Position
	S.fx("Ultimate", { Character = character, Act = 18, Phase = "Snap", Position = center, Radius = c.Radius })
	for _, target in ipairs(S.Hitbox.inRadius(character, center, c.Radius, 10)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			local away = Vector3.new(tr.Position.X - center.X, 0, tr.Position.Z - center.Z)
			S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 18, Direction = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1), Position = tr.Position, Source = "JohnRodSnap" })
		end
	end
end

-- SWORD WHIRL: Silver Chariot spins its rapier round Polnareff.
USE.Polnareff = function(S, player, state, character, root)
	local c = TuskConfig.Polnareff and TuskConfig.Polnareff.CorpseWhirl or { Radius = 14, Damage = 9, Stun = 0.7 }
	S.lock(state, 0.4)
	fx({ Character = character, Who = "Polnareff", Phase = "Whirl", Position = root.Position, Radius = c.Radius })
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, c.Radius, 10)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			local away = Vector3.new(tr.Position.X - root.Position.X, 0, tr.Position.Z - root.Position.Z)
			S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 20, Direction = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1), Position = tr.Position, Source = "PolnareffCorpse" })
		end
	end
end

-- HAMON BEAT: Joseph slaps the ground and a Hamon ripple runs out.
USE.Joseph = function(S, player, state, character, root)
	local c = TuskConfig.Joseph and TuskConfig.Joseph.CorpseHamon or { Radius = 16, Damage = 8, Stun = 1.0 }
	S.lock(state, 0.4)
	fx({ Character = character, Who = "Joseph", Phase = "Hamon", Position = root.Position, Radius = c.Radius })
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, c.Radius, 10)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 8, Direction = Vector3.new(0, 1, 0), Position = tr.Position, Source = "JosephCorpse" })
		end
	end
end

-- WRYYY: DIO drains everyone round him at once; he heals from it.
USE.Dio = function(S, player, state, character, root)
	local c = TuskConfig.Dio and TuskConfig.Dio.CorpseDrain or { Radius = 18, Damage = 7, Stun = 0.6, HealPerDamage = 0.6 }
	S.lock(state, 0.5)
	fx({ Character = character, Who = "Dio", Phase = "Drain", Position = root.Position, Radius = c.Radius })
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local healed = 0
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, c.Radius, 10)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		local hum = target:FindFirstChildOfClass("Humanoid")
		if tr and hum then
			local before = hum.Health
			if S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = Vector3.new(0, 1, 0), Position = tr.Position, Source = "DioCorpse" }) then
				healed = healed + math.max(0, before - hum.Health) * c.HealPerDamage
			end
		end
	end
	if humanoid and healed > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + healed)
	end
end

-- ORA BARRAGE: Star Platinum spins round Jotaro punching everyone near,
-- then one big ORA! sends them flying.
USE.Jotaro = function(S, player, state, character, root)
	local c = TuskConfig.Jotaro and TuskConfig.Jotaro.CorpseOra or { Radius = 16, Hits = 6, Gap = 0.08, Damage = 2, FinalDamage = 6, Stun = 0.6 }
	S.lock(state, c.Hits * c.Gap + 0.3)
	fx({ Character = character, Who = "Jotaro", Phase = "Barrage", Position = root.Position, Radius = c.Radius, Time = c.Hits * c.Gap })
	for i = 1, c.Hits do
		task.delay((i - 1) * c.Gap, function()
			local char = player.Character
			local r = char and char:FindFirstChild("HumanoidRootPart")
			if not r then
				return
			end
			local last = i == c.Hits
			for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, c.Radius, 10)) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr then
					local away = Vector3.new(tr.Position.X - r.Position.X, 0, tr.Position.Z - r.Position.Z)
					S.hit(player, target, { Damage = last and c.FinalDamage or c.Damage, Stun = c.Stun, Knockback = last and 40 or 0, Launch = last and 12 or nil, Direction = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1), Position = tr.Position, Source = "JotaroCorpse" })
				end
			end
		end)
	end
end

-- OPEN BOOK: Heaven's Door opens everyone round Rohan like a book for a
-- moment (stuck, hurt).
USE.Rohan = function(S, player, state, character, root)
	local c = TuskConfig.Rohan and TuskConfig.Rohan.CorpseBook or { Radius = 18, Damage = 7, Stun = 1.2 }
	S.lock(state, 0.4)
	local hit = {}
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, c.Radius, 10)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Position = tr.Position, Source = "RohanCorpse", Unblockable = true }) then
			table.insert(hit, target)
		end
	end
	fx({ Character = character, Who = "Rohan", Phase = "Books", Position = root.Position, Radius = c.Radius, Targets = hit })
end

-- SPACE PULL: The Hand erases the space round Okuyasu: everyone near is
-- yanked in next to him, hurt and dazed.
USE.Okuyasu = function(S, player, state, character, root)
	local c = TuskConfig.Okuyasu and TuskConfig.Okuyasu.CorpsePull or { Radius = 26, Damage = 6, Stun = 0.8 }
	S.lock(state, 0.4)
	fx({ Character = character, Who = "Okuyasu", Phase = "Pull", Position = root.Position, Radius = c.Radius })
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, c.Radius, 10)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and not tr.Anchored then
			local off = Vector3.new(tr.Position.X - root.Position.X, 0, tr.Position.Z - root.Position.Z)
			local to = root.Position + (off.Magnitude > 0.1 and off.Unit or Vector3.new(0, 0, -1)) * 4
			target:PivotTo(CFrame.lookAt(to, Vector3.new(root.Position.X, to.Y, root.Position.Z)))
			S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Position = to, Source = "OkuyasuCorpse" })
		end
	end
end

-- CONTACT DETONATION: Killer Queen sets off the ground round Kira.
USE.Kira = function(S, player, state, character, root)
	local c = TuskConfig.Kira and TuskConfig.Kira.CorpseBlast or { Radius = 15, Damage = 10, Stun = 0.7, Knockback = 40 }
	S.lock(state, 0.4)
	fx({ Character = character, Who = "Kira", Phase = "Blast", Position = root.Position, Radius = c.Radius })
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, c.Radius, 10)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			local away = Vector3.new(tr.Position.X - root.Position.X, 0, tr.Position.Z - root.Position.Z)
			S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = 12, Direction = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1), Position = tr.Position, Source = "KiraCorpse" })
		end
	end
end

-- DORA BARRAGE: Crazy Diamond spins round Josuke (Part 4) punching
-- everyone near, then one big DORA! sends them flying.
USE.Josuke4 = function(S, player, state, character, root)
	local c = TuskConfig.Josuke4 and TuskConfig.Josuke4.CorpseDora or { Radius = 16, Hits = 6, Gap = 0.08, Damage = 2, FinalDamage = 6, Stun = 0.6 }
	S.lock(state, c.Hits * c.Gap + 0.3)
	fx({ Character = character, Who = "Josuke4", Phase = "Barrage", Position = root.Position, Radius = c.Radius, Time = c.Hits * c.Gap })
	for i = 1, c.Hits do
		task.delay((i - 1) * c.Gap, function()
			local char = player.Character
			local r = char and char:FindFirstChild("HumanoidRootPart")
			if not r then
				return
			end
			local last = i == c.Hits
			for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, c.Radius, 10)) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr then
					local away = Vector3.new(tr.Position.X - r.Position.X, 0, tr.Position.Z - r.Position.Z)
					S.hit(player, target, { Damage = last and c.FinalDamage or c.Damage, Stun = c.Stun, Knockback = last and 40 or 0, Launch = last and 12 or nil, Direction = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1), Position = tr.Position, Source = "Josuke4Corpse" })
				end
			end
		end)
	end
end

-- SECOND HAND: Mandom turns everyone round Ringo back 6 seconds: they're
-- hit and dazed (Ringo remembers; they don't).
USE.Ringo = function(S, player, state, character, root)
	local c = TuskConfig.Ringo and TuskConfig.Ringo.CorpseRewind or { Radius = 20, Damage = 7, Stun = 1.2 }
	S.lock(state, 0.4)
	fx({ Character = character, Who = "Ringo", Phase = "Rewind", Position = root.Position, Radius = c.Radius })
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, c.Radius, 10)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			local away = Vector3.new(tr.Position.X - root.Position.X, 0, tr.Position.Z - root.Position.Z)
			if S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 6, Direction = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1), Position = tr.Position, Source = "RingoSecondHand" }) then
				target:SetAttribute("MandomDazedUntil", workspace:GetServerTimeNow() + c.Stun)
			end
		end
	end
end

-- THE SAINT'S MIRACLE: only with the complete corpse (all 8 parts).
local function miracle(S, player, state, character, root)
	local m = TuskConfig.Corpse.Miracle
	local _, humanoid = S.Adapter.getAlive(player)
	local center = root.Position
	local iframes = S.Adapter.Settings.IFrameAttribute
	S.lock(state, m.Windup + m.Waves * m.WaveEvery + 0.5)
	character:SetAttribute(iframes, true)
	character:SetAttribute("Armored", true)
	humanoid.Health = humanoid.MaxHealth
	fx({ Character = character, Who = "Miracle", Phase = "Start", Position = center, Windup = m.Windup, Range = m.Range, Time = m.Windup + m.Waves * m.WaveEvery })
	for w = 1, m.Waves do
		task.delay(m.Windup + (w - 1) * m.WaveEvery, function()
			local char, _, r = S.Adapter.getAlive(player)
			if not r then
				return
			end
			local struck = {}
			for _, target in ipairs(S.Hitbox.inRadius(char, r.Position, m.Range, 16)) do
				local tr = target:FindFirstChild("HumanoidRootPart")
				if tr and S.hit(player, target, { Damage = m.Damage, Stun = m.Stun, Knockback = 0, Direction = Vector3.new(0, -1, 0), Position = tr.Position, Source = "CorpseMiracle" }) then
					table.insert(struck, tr.Position)
				end
			end
			fx({ Character = char, Who = "Miracle", Phase = "Pillars", Positions = struck, Wave = w })
		end)
	end
	task.delay(m.Windup + m.Waves * m.WaveEvery, function()
		if character.Parent then
			character:SetAttribute(iframes, nil)
			character:SetAttribute("Armored", nil)
		end
		local _, _, r = S.Adapter.getAlive(player)
		if r then
			around(S, player, r.Position, m.FinalRadius, { Damage = m.FinalDamage, Stun = 0.9, Knockback = m.FinalKnockback, Launch = m.FinalLaunch, Source = "CorpseMiracle" })
			fx({ Character = character, Who = "Miracle", Phase = "Burst", Position = r.Position, Radius = m.FinalRadius })
		end
		-- The corpse leaves them: every part goes back out into the desert.
		local ok, Corpse = pcall(function()
			return require(script.Parent.CorpseService)
		end)
		if ok and Corpse then
			Corpse.release(player)
		end
	end)
end

function CorpseMoves.use(S, player, state, aim, cfg)
	local character, _, root = S.Adapter.getAlive(player)
	if not character or not state.Act or S.isBusy(state) or state.Charging or not S.Adapter.canAct(player) then
		return
	end
	if (character:GetAttribute("CorpseReadyAt") or 0) > now() then
		S.tell(player, "Denied", { Reason = "Cooldown" })
		return
	end
	if character:GetAttribute("CorpseComplete") then
		miracle(S, player, state, character, root)
		return
	end
	local who = Registry.characterOf(state.Act)
	local fn = USE[who]
	if not fn then
		return
	end
	if fn(S, player, state, character, root, aim) == false then
		return
	end
	character:SetAttribute("CorpseReadyAt", now() + (cfg and cfg.Cooldown or 20))
end

return CorpseMoves
