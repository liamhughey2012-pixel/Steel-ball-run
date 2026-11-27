--[[
	Rohan_Server  (ModuleScript)
	PUT IT IN: ServerScriptService > SpinCharacters   (make a Folder named SpinCharacters there if it doesn't exist)

	Rohan Kishibe (Part 4): Heaven's Door.
	Its other half is Rohan_Client in ReplicatedStorage > SpinCharacters.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: Rohan
-- ======================================================================
__modules["Rohan"] = function()
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

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

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
end

-- ======================================================================
-- MODULE: RohanOutfit
-- ======================================================================
__modules["RohanOutfit"] = function()
--[[
	RohanOutfit  (ServerScriptService.SpinServer.RohanOutfit)

	Gives a character the look of Rohan Kishibe (Part 4) while they play him
	(TuskAct 28), built from blocky parts (no catalog asset ids). Built from
	memory of the anime (no reference images yet):
	  * dark green hair, swept back and to the side, under his HEADBAND with
	    its jagged, pen-nib zigzag top edge
	  * gold PEN-NIB earrings
	  * a short, cropped light jacket with a high collar and a row of buttons,
	    bare midriff below it
	  * dark green trousers with a wide belt, brown shoes
	  * his G-PEN in his right hand (black holder, gold nib)
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local RohanOutfit = {}
RohanOutfit.Act = 28

local C = {
	Hair = Color3.fromRGB(40, 86, 64),
	HairShade = Color3.fromRGB(26, 60, 44),
	Band = Color3.fromRGB(232, 236, 222),
	BandShade = Color3.fromRGB(180, 196, 170),
	Jacket = Color3.fromRGB(214, 232, 196),
	JacketShade = Color3.fromRGB(160, 190, 140),
	Trousers = Color3.fromRGB(40, 70, 52),
	Belt = Color3.fromRGB(70, 46, 30),
	Gold = Color3.fromRGB(236, 192, 72),
	Pen = Color3.fromRGB(24, 24, 28),
	Shoe = Color3.fromRGB(96, 62, 38),
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

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Dark green hair, swept back and to one side.
	piece(head, outfit, "HairCap", Vector3.new(head.Size.X + 0.1 * s, 0.34 * s, head.Size.Z + 0.12 * s), C.Hair, CFrame.new(0, h + 0.1 * s, 0.03 * s))
	piece(head, outfit, "HairSweep", Vector3.new(head.Size.X * 0.7, 0.3 * s, head.Size.Z + 0.2 * s), C.Hair, CFrame.new(0.14 * s, h + 0.32 * s, 0.06 * s) * CFrame.Angles(math.rad(-8), 0, math.rad(-10)))
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.12 * s, 0.75 * s, 0.18 * s), C.Hair, CFrame.new(0, h - 0.3 * s, d + 0.06 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HairSide", Vector3.new(0.12 * s, 0.6 * s, head.Size.Z * 0.75), C.Hair, CFrame.new(side * (w + 0.05 * s), h - 0.25 * s, 0.1 * s))
		piece(head, outfit, "Brow", Vector3.new(0.28 * s, 0.06 * s, 0.05 * s), C.HairShade, CFrame.new(side * 0.22 * s, 0.14 * s, -d - 0.02 * s) * CFrame.Angles(0, 0, side * 0.18))
		-- Gold pen-nib earrings.
		local ear = CFrame.new(side * (w + 0.06 * s), -0.15 * s, 0.05 * s)
		piece(head, outfit, "EarringNib", Vector3.new(0.05 * s, 0.22 * s, 0.12 * s), C.Gold, ear * CFrame.new(0, -0.12 * s, 0), Enum.Material.Metal)
		piece(head, outfit, "EarringTip", Vector3.new(0.05 * s, 0.08 * s, 0.08 * s), C.Gold, ear * CFrame.new(0, -0.26 * s, 0) * CFrame.Angles(math.pi / 4, 0, 0), Enum.Material.Metal)
	end
	piece(head, outfit, "Fringe", Vector3.new(head.Size.X * 0.55, 0.22 * s, 0.12 * s), C.Hair, CFrame.new(-0.16 * s, h - 0.05 * s, -d - 0.04 * s) * CFrame.Angles(0, 0, math.rad(12)))
	-- The headband, its top edge cut into a zigzag like pen nibs.
	piece(head, outfit, "Headband", Vector3.new(head.Size.X + 0.16 * s, 0.18 * s, head.Size.Z + 0.16 * s), C.Band, CFrame.new(0, h + 0.02 * s, 0))
	for k = -3, 3 do
		piece(head, outfit, "BandTooth", Vector3.new(0.13 * s, 0.13 * s, 0.06 * s), C.Band, CFrame.new(k * 0.14 * s, h + 0.13 * s, -d - 0.08 * s) * CFrame.Angles(0, 0, math.pi / 4))
	end
	for _, side in ipairs({ -1, 1 }) do
		for k = -2, 2 do
			piece(head, outfit, "BandTooth", Vector3.new(0.06 * s, 0.13 * s, 0.13 * s), C.Band, CFrame.new(side * (w + 0.08 * s), h + 0.13 * s, k * 0.14 * s) * CFrame.Angles(math.pi / 4, 0, 0))
		end
	end
	piece(head, outfit, "BandLine", Vector3.new(head.Size.X + 0.17 * s, 0.03 * s, head.Size.Z + 0.17 * s), C.BandShade, CFrame.new(0, h - 0.06 * s, 0))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		-- A short, cropped jacket: the top two-thirds of the chest; the rest bare.
		local jh = s.Y * 0.68
		-- (Bare skin below it, whatever shirt the avatar wears: the head's colour.)
		local head = character:FindFirstChild("Head")
		piece(upper, outfit, "Midriff", Vector3.new(s.X + 0.04, s.Y - jh + 0.02, s.Z + 0.04), head and head.Color or Color3.fromRGB(236, 200, 170), CFrame.new(0, -top + (s.Y - jh) / 2, 0))
		piece(upper, outfit, "Jacket", Vector3.new(s.X + 0.12, jh, s.Z + 0.12), C.Jacket, CFrame.new(0, top - jh / 2, 0))
		piece(upper, outfit, "JacketHem", Vector3.new(s.X + 0.14, 0.08, s.Z + 0.14), C.JacketShade, CFrame.new(0, top - jh, 0))
		piece(upper, outfit, "Placket", Vector3.new(0.12, jh, 0.05), C.JacketShade, CFrame.new(0, top - jh / 2, front - 0.07))
		for k = 0, 3 do
			local b = piece(upper, outfit, "Button", Vector3.new(0.05, 0.1, 0.1), C.Gold, CFrame.new(0, top - 0.18 - k * jh / 4.5, front - 0.1) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Metal)
			b.Shape = Enum.PartType.Cylinder
		end
		-- The high collar.
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Collar", Vector3.new(0.14, 0.42, s.Z * 0.85), C.Jacket, CFrame.new(side * s.X * 0.3, top + 0.18, 0) * CFrame.Angles(0, side * -0.3, side * 0.1))
		end
		piece(upper, outfit, "CollarBack", Vector3.new(s.X * 0.6, 0.42, 0.12), C.Jacket, CFrame.new(0, top + 0.18, -front))
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.08, 0.02, 0.08), C.Trousers, CFrame.new())
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.14, 0.22, ls.Z + 0.14), C.Belt, CFrame.new(0, ls.Y / 2 - 0.1, 0))
		piece(lower, outfit, "Buckle", Vector3.new(0.26, 0.18, 0.05), C.Gold, CFrame.new(0, ls.Y / 2 - 0.1, -ls.Z / 2 - 0.08), Enum.Material.Metal)
	end
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			-- Short sleeves.
			local sh = name:find("Upper") and as.Y * 0.6 or as.Y * 0.3
			piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.1, sh, as.Z + 0.1), C.Jacket, CFrame.new(0, as.Y / 2 - sh / 2, 0))
		end
	end
	-- His G-pen in his right hand.
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand then
		local hs = hand.Size
		local grip = CFrame.new(0, -hs.Y / 2 - 0.05, -0.15) * CFrame.Angles(math.rad(-70), 0, 0)
		piece(hand, outfit, "PenHolder", Vector3.new(0.09, 0.8, 0.09), C.Pen, grip)
		piece(hand, outfit, "PenNib", Vector3.new(0.07, 0.18, 0.04), C.Gold, grip * CFrame.new(0, -0.48, 0), Enum.Material.Metal)
	end
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Trousers", leg.Size + Vector3.new(0.08, 0.02, 0.08), C.Trousers, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.06, 0.04, 0.16), C.Shoe, CFrame.new(0, 0, -0.05))
		end
	end
end

function RohanOutfit.apply(character)
	if character:FindFirstChild("RohanOutfit") then
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
	outfit.Name = "RohanOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function RohanOutfit.remove(character)
	local outfit = character:FindFirstChild("RohanOutfit")
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
		if character:GetAttribute("TuskAct") == RohanOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == RohanOutfit.Act then
					RohanOutfit.apply(character)
				end
			end)
		else
			RohanOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function RohanOutfit.init()
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

return RohanOutfit
end
end
