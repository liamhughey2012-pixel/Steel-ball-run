--[[
	Okuyasu_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Okuyasu Nijimura (Part 4): The Hand.
	Its other half is Okuyasu_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule, __expect)
	-- Pasted into the wrong script? (e.g. Gyro_Client's code in Gyro_Server)
	if type(__expect) == "table" and (string.lower(tostring(__expect.Name)) ~= "okuyasu" or __expect.Side ~= "server") then
		error("this is the code for Okuyasu_Server, but it's in the ModuleScript named " .. tostring(__expect.Script) .. ". Paste " .. tostring(__expect.Script) .. "'s own code into it (or rename it to Okuyasu_Server and put it in ServerScriptService > SpinCharacters).", 0)
	end

-- ======================================================================
-- MODULE: Okuyasu
-- ======================================================================
__modules["Okuyasu"] = function()
--[[
	Okuyasu  (ServerScriptService.SpinServer.TuskActs.Okuyasu)

	Okuyasu Nijimura (Part 4): THE HAND. Registered as "Act" 27.
	The Hand's right palm ERASES whatever it swipes through, space included,
	with a "GAOON".
	  M1        HAND COMBO: The Hand swings with him; the 4th is a heavy
	            backhand that launches
	  Ability 1 SPACE ERASE: a slow, heavy swipe of the right palm erases
	            everything in front: big damage that can't be blocked
	  Ability 2 ERASE PULL: he erases the space between himself and the
	            nearest enemy in front (a long way off): they're yanked right
	            up to him, dazed
	  Ability 3 ERASE DASH: he erases the space in front of himself and is
	            suddenly further along (untouchable for a moment)
	  Ultimate  ZA HANDO: GREAT ERASURE: The Hand swipes again and again,
	            each swipe dragging everyone in front closer, then one huge
	            erase sends them flying
Numbers: TuskConfig.Okuyasu. All damage goes through S.hit (CombatAdapter).
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Okuyasu = {}
local cfg = TuskConfig.Okuyasu
local ACT = 27

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Okuyasu.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, ACT)
end

-- Move a target to `to` (facing `look`), unless something holds them in place.
local function yank(target, to, look)
	local tr = target:FindFirstChild("HumanoidRootPart")
	if not tr or tr.Anchored or target:GetAttribute("TimeStopped") then
		return false
	end
	target:PivotTo(CFrame.lookAt(to, Vector3.new(look.X, to.Y, look.Z)))
	tr.AssemblyLinearVelocity = Vector3.new()
	return true
end

---------------------------------------------------------------------------
-- 1: SPACE ERASE
---------------------------------------------------------------------------
local function erase(S, player, state, aim)
	local c = cfg.Erase
	if not ready(S, player, state, "Erase", 1) then
		return
	end
	S.startCooldown(player, state, "Erase", c.Cooldown, 1)
	S.lock(state, c.Windup + 0.3)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "Erase", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local box = r.CFrame * CFrame.new(0, 0, -c.HitboxForward)
		local count = Moves.boxHit(S, player, box, c.HitboxSize, { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Direction = r.CFrame.LookVector, Source = "OkuyasuErase", Unblockable = true }, c.MaxTargets)
		S.fx("Ability", { Character = char, Act = ACT, Move = "Erase", Phase = "Swipe", CFrame = box, Size = c.HitboxSize, Hit = count > 0 })
	end)
end

---------------------------------------------------------------------------
-- 2: ERASE PULL
---------------------------------------------------------------------------
local function erasePull(S, player, state, aim)
	local c = cfg.ErasePull
	if not ready(S, player, state, "ErasePull", 2) then
		return
	end
	S.startCooldown(player, state, "ErasePull", c.Cooldown, 2)
	S.lock(state, c.Windup + 0.25)
	local character = alive(S, player)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "ErasePull", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local dir = Moves.flat(S.aim(aim, r))
		local target = Moves.findTarget(S, char, r, c.Range, c.Cone, dir)
		local tr = target and target:FindFirstChild("HumanoidRootPart")
		if not tr then
			S.startCooldown(player, state, "ErasePull", c.MissCooldown, 2)
			S.fx("Ability", { Character = char, Act = ACT, Move = "ErasePull", Phase = "Miss", From = r.Position, To = r.Position + dir * c.Range })
			return
		end
		local from = tr.Position
		local to = r.Position + dir * c.PullTo
		local pulled = yank(target, to, r.Position)
		S.hit(player, target, { Damage = c.Damage, Stun = c.Stun, Knockback = 0, Direction = -dir, Position = pulled and to or from, Source = "OkuyasuPull" })
		S.fx("Ability", { Character = char, Act = ACT, Move = "ErasePull", Phase = "Pull", Target = target, From = from, To = pulled and to or from })
	end)
end

---------------------------------------------------------------------------
-- 3: ERASE DASH
---------------------------------------------------------------------------
local function eraseDash(S, player, state, aim)
	local c = cfg.EraseDash
	if not ready(S, player, state, "EraseDash", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local dir = Moves.flat(S.aim(aim, root))
	local to = Moves.safeStep(character, root, dir, c.Distance)
	if not to then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "EraseDash", c.Cooldown, 3)
	S.lock(state, c.Windup + 0.1)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = ACT, Move = "EraseDash", Phase = "Wind", Windup = c.Windup })
	task.delay(c.Windup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		local from = r.Position
		local iframes = S.Adapter.Settings.IFrameAttribute
		char:SetAttribute(iframes, true)
		char:PivotTo(CFrame.lookAt(to, to + dir))
		S.fx("Ability", { Character = char, Act = ACT, Move = "EraseDash", Phase = "Step", From = from, To = to })
		task.delay(c.IFrames, function()
			if char.Parent then
				char:SetAttribute(iframes, nil)
			end
		end)
	end)
end

function Okuyasu.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		erase(S, player, state, aim)
	elseif slot == 2 then
		erasePull(S, player, state, aim)
	elseif slot == 3 then
		eraseDash(S, player, state, aim)
	end
end

---------------------------------------------------------------------------
-- ZA HANDO: GREAT ERASURE (ultimate)
---------------------------------------------------------------------------
function Okuyasu.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character = alive(S, player)
	local life = state.Life
	local total = u.Windup + u.Swipes * u.Gap
	S.lock(state, total + 0.2)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = ACT, Phase = "Call", Windup = u.Windup, Swipes = u.Swipes, Gap = u.Gap })
	task.delay(u.Windup, function()
		if state.Life ~= life or not alive(S, player) then
			if character.Parent then
				character:SetAttribute("Armored", nil)
			end
			return
		end
		S.finishUltimate(player, state)
	end)
	for i = 1, u.Swipes do
		task.delay(u.Windup + (i - 1) * u.Gap, function()
			if state.Life ~= life or not alive(S, player) then
				return
			end
			local char, _, r = alive(S, player)
			local box = r.CFrame * CFrame.new(0, 0, -u.HitboxForward)
			local last = i == u.Swipes
			if last then
				Moves.boxHit(S, player, box, u.HitboxSize, { Damage = u.FinalDamage, Stun = 0.8, Knockback = u.FinalKnockback, Launch = u.FinalLaunch, Direction = r.CFrame.LookVector, Source = "OkuyasuUlt", Unblockable = true }, u.MaxTargets)
				if char.Parent then
					char:SetAttribute("Armored", nil)
				end
			else
				local _, hitSet = Moves.boxHit(S, player, box, u.HitboxSize, { Damage = u.Damage, Stun = u.Stun, Knockback = 0, Direction = r.CFrame.LookVector, Source = "OkuyasuUlt", Unblockable = true }, u.MaxTargets)
				-- Each swipe erases the space between: they're dragged closer.
				for target in pairs(hitSet or {}) do
					local tr = target:FindFirstChild("HumanoidRootPart")
					if tr then
						local close = r.Position + r.CFrame.LookVector * 3
						yank(target, tr.Position:Lerp(Vector3.new(close.X, tr.Position.Y, close.Z), u.Pull), r.Position)
					end
				end
			end
			S.fx("Ultimate", { Character = char, Act = ACT, Phase = "Swipe", Index = i, Last = last, CFrame = box, Size = u.HitboxSize })
		end)
	end
end

function Okuyasu.Cleanup(S, player, state)
	local character = state.Character
	if character then
		character:SetAttribute("Armored", nil)
	end
end

return Okuyasu
end

-- ======================================================================
-- MODULE: OkuyasuOutfit
-- ======================================================================
__modules["OkuyasuOutfit"] = function()
--[[
	OkuyasuOutfit  (ServerScriptService.SpinServer.OkuyasuOutfit)

	Gives a character the look of Okuyasu Nijimura (Part 4) while they play
	him (TuskAct 27), built from blocky parts (no catalog asset ids):
	  * short dark hair: buzzed at the sides, a short flat top; a scar
	    running across his face; heavy, scowling brows
	  * a dark navy GAKURAN worn hanging OPEN over a white undershirt,
	    sleeves pushed up a little; a tall collar with a gold DOLLAR sign on
	    one side and a gold YEN sign on the other, and a gold $ pin on the
	    chest
	  * baggy navy trousers, a chain hanging from his belt, black shoes
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local OkuyasuOutfit = {}
OkuyasuOutfit.Act = 27

local C = {
	Coat = Color3.fromRGB(34, 40, 70),
	CoatShade = Color3.fromRGB(22, 26, 48),
	CoatLight = Color3.fromRGB(56, 64, 104),
	Shirt = Color3.fromRGB(236, 236, 232),
	Gold = Color3.fromRGB(236, 190, 70),
	Silver = Color3.fromRGB(200, 204, 214),
	Hair = Color3.fromRGB(46, 42, 48),
	HairShade = Color3.fromRGB(70, 64, 72),
	Scar = Color3.fromRGB(196, 120, 110),
	Shoe = Color3.fromRGB(20, 20, 24),
}

local saved = setmetatable({}, { __mode = "k" })

local function piece(parent, outfit, name, size, color, offset, material)
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
	p.Material = material or Enum.Material.SmoothPlastic
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

-- Gold glyphs (facing forward, -Z) made of little bars: a dollar sign and a yen sign.
local function bar(parent, outfit, cf, w, h)
	return piece(parent, outfit, "Glyph", Vector3.new(w, h, 0.04), C.Gold, cf, Enum.Material.Metal)
end

local function dollar(parent, outfit, cf, size)
	local t = size * 0.18
	bar(parent, outfit, cf * CFrame.new(0, size * 0.4, 0), size * 0.6, t)
	bar(parent, outfit, cf, size * 0.6, t)
	bar(parent, outfit, cf * CFrame.new(0, -size * 0.4, 0), size * 0.6, t)
	bar(parent, outfit, cf * CFrame.new(size * 0.25, size * 0.2, 0), t, size * 0.4)
	bar(parent, outfit, cf * CFrame.new(-size * 0.25, -size * 0.2, 0), t, size * 0.4)
	bar(parent, outfit, cf * CFrame.new(0, 0, -0.01), t * 0.6, size * 1.2)
end

local function yen(parent, outfit, cf, size)
	local t = size * 0.18
	for _, side in ipairs({ -1, 1 }) do
		bar(parent, outfit, cf * CFrame.new(side * size * 0.17, size * 0.28, 0) * CFrame.Angles(0, 0, side * -0.6), t, size * 0.5)
	end
	bar(parent, outfit, cf * CFrame.new(0, -size * 0.25, 0), t, size * 0.6)
	bar(parent, outfit, cf * CFrame.new(0, -size * 0.05, 0), size * 0.55, t * 0.8)
	bar(parent, outfit, cf * CFrame.new(0, -size * 0.28, 0), size * 0.55, t * 0.8)
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Buzzed sides, a short flat top.
	piece(head, outfit, "FlatTop", Vector3.new(head.Size.X - 0.04 * s, 0.32 * s, head.Size.Z - 0.02 * s), C.Hair, CFrame.new(0, h + 0.12 * s, 0))
	piece(head, outfit, "FlatTopEdge", Vector3.new(head.Size.X - 0.02 * s, 0.06 * s, head.Size.Z), C.HairShade, CFrame.new(0, h + 0.28 * s, 0))
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.04 * s, 0.6 * s, 0.06 * s), C.Hair, CFrame.new(0, h - 0.3 * s, d + 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Buzz", Vector3.new(0.05 * s, 0.4 * s, head.Size.Z * 0.85), C.HairShade, CFrame.new(side * (w + 0.02 * s), h - 0.18 * s, 0.02 * s))
		-- Heavy, scowling brows.
		piece(head, outfit, "Brow", Vector3.new(0.3 * s, 0.08 * s, 0.05 * s), C.Hair, CFrame.new(side * 0.22 * s, 0.13 * s, -d - 0.02 * s) * CFrame.Angles(0, 0, side * -0.25))
	end
	piece(head, outfit, "HairLine", Vector3.new(head.Size.X - 0.04 * s, 0.08 * s, 0.06 * s), C.Hair, CFrame.new(0, h - 0.02 * s, -d - 0.01 * s))
	-- The scar across his face.
	piece(head, outfit, "Scar", Vector3.new(0.7 * s, 0.04 * s, 0.03 * s), C.Scar, CFrame.new(0, 0.05 * s, -d - 0.02 * s) * CFrame.Angles(0, 0, math.rad(-28)))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		-- The white undershirt, showing all down the open front.
		piece(upper, outfit, "Undershirt", s + Vector3.new(0.04, 0, 0.04), C.Shirt, CFrame.new())
		-- The coat hanging open: back, sides and two front panels.
		piece(upper, outfit, "CoatBack", Vector3.new(s.X + 0.14, s.Y + 0.02, 0.12), C.Coat, CFrame.new(0, 0, s.Z / 2 + 0.03))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "CoatSide", Vector3.new(0.12, s.Y + 0.02, s.Z + 0.14), C.Coat, CFrame.new(side * (s.X / 2 + 0.03), 0, 0))
			piece(upper, outfit, "CoatFront", Vector3.new(s.X * 0.3, s.Y + 0.02, 0.1), C.Coat, CFrame.new(side * s.X * 0.37, 0, front - 0.05) * CFrame.Angles(0, side * -0.2, 0))
			piece(upper, outfit, "CoatEdge", Vector3.new(0.05, s.Y, 0.11), C.CoatLight, CFrame.new(side * s.X * 0.22, 0, front - 0.08) * CFrame.Angles(0, side * -0.2, 0))
			-- The tall collar.
			local cf = CFrame.new(side * s.X * 0.33, top + 0.28, -0.05) * CFrame.Angles(0, side * -0.3, 0)
			piece(upper, outfit, "CollarSide", Vector3.new(0.16, 0.6, s.Z * 0.95), C.Coat, cf)
			local face = cf * CFrame.new(0, 0.02, -s.Z * 0.48 - 0.02)
			if side == 1 then
				dollar(upper, outfit, face, 0.32)
			else
				yen(upper, outfit, face, 0.32)
			end
		end
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.75, 0.6, 0.18), C.Coat, CFrame.new(0, top + 0.28, -front))
		-- A gold $ pin on the coat.
		dollar(upper, outfit, CFrame.new(-s.X * 0.37, top - s.Y * 0.35, front - 0.12) * CFrame.Angles(0, 0.2, 0), 0.26)
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.1, 0.02, 0.1), C.Coat, CFrame.new())
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.14, 0.14, ls.Z + 0.14), C.CoatShade, CFrame.new(0, ls.Y / 2 - 0.06, 0))
		-- Coat tails, open at the front.
		piece(lower, outfit, "TailBack", Vector3.new(ls.X + 0.2, 2.0, 0.1), C.Coat, CFrame.new(0, -1.0, ls.Z / 2 + 0.16) * CFrame.Angles(math.rad(8), 0, 0))
		for _, side in ipairs({ -1, 1 }) do
			piece(lower, outfit, "TailSide", Vector3.new(0.1, 1.9, ls.Z + 0.3), C.Coat, CFrame.new(side * (ls.X / 2 + 0.16), -0.95, 0.05) * CFrame.Angles(0, 0, side * -0.12))
			piece(lower, outfit, "TailFront", Vector3.new(ls.X * 0.3, 1.9, 0.1), C.Coat, CFrame.new(side * ls.X * 0.38, -0.95, -ls.Z / 2 - 0.12) * CFrame.Angles(math.rad(-6), side * -0.2, side * -0.1))
		end
		-- A chain hanging from his belt.
		for k = 0, 5 do
			local a = k / 5 * math.pi
			local link = piece(lower, outfit, "Chain", Vector3.new(0.05, 0.1, 0.08), C.Silver, CFrame.new(ls.X * 0.15 + math.sin(a * 0.5) * 0.3, ls.Y / 2 - 0.15 - math.sin(a) * 0.35, -ls.Z / 2 - 0.1) * CFrame.Angles(0, 0, k * 0.6), Enum.Material.Metal)
			link.Name = "Chain"
		end
	end
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			piece(arm, outfit, "Sleeve", as + Vector3.new(0.12, 0.02, 0.12), C.Coat, CFrame.new())
			if name:find("Lower") or name == "Left Arm" or name == "Right Arm" then
				piece(arm, outfit, "PushedUp", Vector3.new(as.X + 0.18, 0.2, as.Z + 0.18), C.CoatShade, CFrame.new(0, -as.Y / 2 + 0.25, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local wide = name:find("Lower") and 0.24 or 0.16
			piece(leg, outfit, "Trousers", leg.Size + Vector3.new(wide, 0.02, wide), C.Coat, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.08, 0.04, 0.18), C.Shoe, CFrame.new(0, 0, -0.05))
		end
	end
end

function OkuyasuOutfit.apply(character)
	if character:FindFirstChild("OkuyasuOutfit") then
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
	outfit.Name = "OkuyasuOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function OkuyasuOutfit.remove(character)
	local outfit = character:FindFirstChild("OkuyasuOutfit")
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
		if character:GetAttribute("TuskAct") == OkuyasuOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == OkuyasuOutfit.Act then
					OkuyasuOutfit.apply(character)
				end
			end)
		else
			OkuyasuOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function OkuyasuOutfit.init()
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

return OkuyasuOutfit
end
end
