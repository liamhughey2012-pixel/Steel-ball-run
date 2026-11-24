--[[
	SpinCore_Server_2  (ModuleScript)  -- part 2 of 5
	PUT IT IN: ServerScriptService > SpinCore   (make a Folder named SpinCore there if it doesn't exist)

	Part of the Spin Battlegrounds server core, split up so pasting is quick.
	Loaded by Spin_Server: don't put any code in front of this.
]]

return function(__modules, __require, __hasModule)

-- ======================================================================
-- MODULE: DefenseService
-- ======================================================================
__modules["DefenseService"] = function()
--[[
	DefenseService  (ServerScriptService.SpinServer.DefenseService)

	BLOCK and DASH for every character (players and Stand-user NPCs).
	  BLOCK (hold F): sets the "Blocking" attribute; CombatAdapter then cuts
	    damage, skips the stun and drains the guard bar (BlockMeter). Hits from
	    behind aren't blocked. Starting a block just before a hit lands is a
	    PERFECT BLOCK (no damage, the attacker is stunned). An empty guard bar
	    is a GUARD BREAK (stunned, can't block for a few seconds). Attacking or
	    dashing drops the block. The bar refills while you aren't blocking.
	  DASH (Q): a short burst in the direction you're moving, with a moment
	    you can't be hit. Two charges (chain them); each comes back after
	    DashCooldown. A dash cancels the recovery after an M1 hit. Dash
	    through an attack (it would have hit you) for a PERFECT DODGE: the
	    charge comes back, the attacker is slowed, you get ultimate meter and
	    your next hit within CounterTime does +40%. The server checks and
	    grants it; the player's own client moves them (smooth, replicates to
	    everyone). NPCs are moved by the server.
	Numbers: TuskConfig.Defense.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local DefenseService = {}
local S -- TuskService
local cfg = TuskConfig.Defense or {}
local lastRelease = setmetatable({}, { __mode = "k" }) -- [character] = server time of the last block release

local function now()
	return workspace:GetServerTimeNow()
end

function DefenseService.isBlocking(character)
	return character ~= nil and character:GetAttribute(S.Adapter.Settings.BlockAttribute) == true
end

function DefenseService.release(player, state)
	local character = state and state.Character or (player and player.Character)
	if not character or not DefenseService.isBlocking(character) then
		return
	end
	character:SetAttribute(S.Adapter.Settings.BlockAttribute, nil)
	character:SetAttribute("BlockCanParry", nil)
	lastRelease[character] = now()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		S.Adapter.setMoveModifier(humanoid, "Block", nil)
	end
end

function DefenseService.block(player, state, on)
	local character, humanoid = S.Adapter.getAlive(player)
	if not character then
		return
	end
	if not on then
		DefenseService.release(player, state)
		return
	end
	if DefenseService.isBlocking(character) then
		return
	end
	if not S.Adapter.canAct(player) or state.Charging or S.isBusy(state) or state.Sneaking then
		return
	end
	if (character:GetAttribute("GuardBrokenUntil") or 0) > now() then
		S.tell(player, "Denied", { Reason = "GuardBroken" })
		return
	end
	local t = now()
	character:SetAttribute("BlockStart", t)
	-- Perfect blocks only count if this isn't block spam.
	character:SetAttribute("BlockCanParry", (t - (lastRelease[character] or -math.huge)) >= (cfg.ParryRetry or 0.6) or nil)
	if character:GetAttribute("BlockMeter") == nil then
		character:SetAttribute("BlockMeter", cfg.MaxMeter or 100)
	end
	character:SetAttribute(S.Adapter.Settings.BlockAttribute, true)
	S.Adapter.setMoveModifier(humanoid, "Block", cfg.BlockWalkSpeed or 0.45)
end

-- Dash charges per character: the server times each charge is ready again
-- (sorted). Shown to the HUD as DashReadyAt (next) and DashFullAt (all).
local charges = setmetatable({}, { __mode = "k" })

local function chargeList(character)
	local list = charges[character]
	if not list then
		list = {}
		for i = 1, (cfg.DashCharges or 2) do
			list[i] = 0
		end
		charges[character] = list
	end
	return list
end

local function publishCharges(character, list)
	table.sort(list)
	character:SetAttribute("DashReadyAt", list[1])
	character:SetAttribute("DashFullAt", list[#list])
	character:SetAttribute("DashCharges", #list)
end

-- Busy only because of an M1's recovery? Then a dash may cancel it.
local function onlyM1Recovery(state)
	return cfg.DashCancelM1 ~= false and state.M1LockUntil ~= nil and state.LockUntil <= state.M1LockUntil
end

function DefenseService.dash(player, state, direction)
	local character, _, root = S.Adapter.getAlive(player)
	if not character or typeof(direction) ~= "Vector3" or direction ~= direction then
		return
	end
	if not S.Adapter.canAct(player) or state.Charging or state.Sneaking then
		return
	end
	local cancel = false
	if S.isBusy(state) then
		if not onlyM1Recovery(state) then
			return
		end
		cancel = true
	end
	local t = now()
	local list = chargeList(character)
	table.sort(list)
	if list[1] > t then
		S.tell(player, "Denied", { Reason = "DashCooldown" })
		return
	end
	if t - (character:GetAttribute("LastDashAt") or -math.huge) < (cfg.DashGap or 0.3) then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	flat = flat.Unit
	DefenseService.release(player, state)
	if cancel then
		-- Dash-cancel: the M1 recovery is over, the combo starts again.
		state.LockUntil = os.clock()
		state.M1LockUntil = nil
		state.Combo = 0
	end
	-- Use a charge: it comes back DashCooldown after the last one queued.
	local cooldown = cfg.DashCooldown or 2.2
	table.remove(list, 1)
	table.insert(list, math.max(t, list[#list] or t) + cooldown)
	publishCharges(character, list)
	character:SetAttribute("LastDashAt", t)
	local iframes = S.Adapter.Settings.IFrameAttribute
	local token = tostring({})
	character:SetAttribute(iframes, true)
	character:SetAttribute("DashToken", token)
	character:SetAttribute("DashDodgeUntil", t + (cfg.PerfectDodgeWindow or 0.22))
	character:SetAttribute("DashDodged", nil)
	task.delay(cfg.DashIFrames or 0.22, function()
		if character:GetAttribute("DashToken") == token then
			character:SetAttribute(iframes, nil)
		end
	end)
	local speed, time = cfg.DashSpeed or 80, cfg.DashTime or 0.21
	S.fx("Dash", { Character = character, Direction = flat, Speed = speed, Time = time, Cancel = cancel })
	-- NPCs have no client to move them: the server does it.
	if typeof(player) ~= "Instance" then
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.MaxForce = math.huge
		velocity.VectorVelocity = flat * speed
		velocity.Parent = attachment
		game:GetService("Debris"):AddItem(attachment, time)
	end
end

-- PERFECT DODGE: an attack that would have hit landed during the dash.
local function onPerfectDodge(character, attackerPlayer)
	local t = now()
	-- The dash charge comes back.
	if cfg.PerfectDodgeRefund ~= false then
		local list = chargeList(character)
		table.sort(list)
		list[#list] = math.min(list[#list], t)
		publishCharges(character, list)
	end
	-- The next hit within CounterTime lands harder.
	character:SetAttribute("CounterUntil", t + (cfg.CounterTime or 1.5))
	-- Ultimate meter (players and NPCs).
	local owner = Players:GetPlayerFromCharacter(character)
	if not owner then
		for p, st in pairs(S.States or {}) do
			if st.Character == character then
				owner = p
			end
		end
	end
	if owner and S.addUlt then
		S.addUlt(owner, cfg.PerfectDodgeUlt or 8)
	end
	-- The attacker stumbles: slowed for a moment.
	local attacker = attackerPlayer and attackerPlayer.Character
	local ah = attacker and attacker:FindFirstChildOfClass("Humanoid")
	if ah then
		local token = tostring({})
		attacker:SetAttribute("DodgedSlowToken", token)
		S.Adapter.setMoveModifier(ah, "Dodged", cfg.PerfectDodgeSlow or 0.5)
		task.delay(cfg.PerfectDodgeSlowTime or 0.8, function()
			if ah.Parent and attacker:GetAttribute("DodgedSlowToken") == token then
				S.Adapter.setMoveModifier(ah, "Dodged", nil)
				attacker:SetAttribute("DodgedSlowToken", nil)
			end
		end)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	S.fx("PerfectDodge", { Character = character, Attacker = attacker, Position = root and root.Position, Counter = cfg.CounterTime or 1.5 })
end

-- Guard bars refill while not blocking.
local function regen(dt)
	local max = cfg.MaxMeter or 100
	local t = now()
	local function tick(character)
		local meter = character and character:GetAttribute("BlockMeter")
		if meter and meter < max and not DefenseService.isBlocking(character) and t - (character:GetAttribute("LastBlockHit") or 0) >= (cfg.RegenDelay or 1.2) then
			local nextValue = math.min(max, meter + (cfg.MeterRegen or 30) * dt)
			character:SetAttribute("BlockMeter", nextValue >= max and nil or nextValue)
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		tick(player.Character)
	end
	for _, model in ipairs(CollectionService:GetTagged("SpinFighter")) do
		tick(model)
	end
end

function DefenseService.init(TuskService)
	S = TuskService
	if S.Adapter.on then
		S.Adapter.on("PerfectDodge", onPerfectDodge)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc >= 0.1 then
			regen(acc)
			acc = 0
		end
	end)
end

return DefenseService
end

-- ======================================================================
-- MODULE: HorseModel
-- ======================================================================
__modules["HorseModel"] = function()
--[[
	HorseModel  (ReplicatedStorage.SpinShared.HorseModel)

	A blocky racehorse for the Steel Ball Run, built from parts (no uploads):
	a long body, an arched neck with a mane, a head with a white blaze, ears
	and a dark muzzle, a swishing tail, four legs with white socks and
	hooves, and full tack: a red saddle blanket, a brown saddle with a horn,
	stirrups and reins.

	HorseModel.build(coat, mane, opts) -> model (PrimaryPart "Body", facing
	-Z, body centre at the origin, hooves 3.85 studs below it, the top of
	the saddle SaddleTop above it). opts (all optional):
	  Width     body width (default 1.9: slim, so a rider's legs go round it)
	  Blanket   saddle blanket colour      Saddle  saddle / tack colour
	  Material  coat material (e.g. Metal for the Golden Steed)
	  Socks     sock colour (false: no socks)
	The server builds race and ride horses; the shop builds a preview. Every limb is
	joined to the body with a Weld; clients animate the gallop by changing
	those welds' C0 (RaceClient). Each animated part carries attributes:
	  Joint (Vector3, where it pivots on the body) and Drop (studs from the
	  pivot down to the part's centre).
]]

local HorseModel = {}
HorseModel.HoofDepth = 3.85 -- studs from the body centre down to the ground
HorseModel.SaddleTop = 1.37 -- studs from the body centre up to the top of the saddle

local function part(model, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.Anchored = false
	p.Parent = model
	return p
end

local function weld(model, parent, name, size, color, cf, material)
	local p = part(model, name, size, color, material)
	local w = Instance.new("Weld")
	w.Name = name .. "Weld"
	w.Part0 = parent
	w.Part1 = p
	w.C0 = cf
	w.Parent = p
	p.CFrame = parent.CFrame * cf
	return p, w
end

-- A part that swings round a joint on the body (legs, tail, neck).
local function jointed(model, body, name, size, color, joint, drop, angle)
	local p, w = weld(model, body, name, size, color, CFrame.new(joint) * CFrame.Angles(angle or 0, 0, 0) * CFrame.new(0, -drop, 0))
	p:SetAttribute("Joint", joint)
	p:SetAttribute("Drop", drop)
	p:SetAttribute("Rest", angle or 0)
	return p, w
end

function HorseModel.build(coat, mane, opts)
	opts = opts or {}
	coat = coat or Color3.fromRGB(120, 76, 44)
	mane = mane or Color3.fromRGB(40, 26, 18)
	local W = opts.Width or 1.9
	local k = W / 2.2 -- how much narrower than the old 2.2-wide body
	local shade = coat:Lerp(Color3.new(0, 0, 0), 0.2)
	local white = opts.SockColor or (typeof(opts.Socks) == "Color3" and opts.Socks) or Color3.fromRGB(240, 238, 232)
	local sockStyle = opts.SockStyle or (opts.Socks == false and "None" or "Two")
	local marking = opts.Marking or "Blaze"
	local hoof = Color3.fromRGB(46, 40, 36)
	local leather = opts.Saddle or Color3.fromRGB(96, 58, 32)
	local leatherMaterial = opts.SaddleMaterial
	local blanket = opts.Blanket or Color3.fromRGB(170, 40, 40)
	local metal = Color3.fromRGB(180, 182, 188)
	local coatMaterial = opts.Material

	local model = Instance.new("Model")
	model.Name = "Horse"
	local body = part(model, "Body", Vector3.new(W, 2.0, 5.0), coat, coatMaterial)
	body.CFrame = CFrame.new()
	model.PrimaryPart = body
	-- Rounded barrel: chest and rump blocks, a belly.
	weld(model, body, "Chest", Vector3.new(W + 0.1, 2.1, 1.2), coat, CFrame.new(0, 0.05, -2.3))
	weld(model, body, "Rump", Vector3.new(W + 0.1, 2.1, 1.3), coat, CFrame.new(0, 0.12, 2.2))
	weld(model, body, "Belly", Vector3.new(W - 0.3, 0.4, 3.8), shade, CFrame.new(0, -1.05, 0))
	if coatMaterial then
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") and p ~= body then
				p.Material = coatMaterial
			end
		end
	end

	-- Neck (arched forward), mane along its top, head.
	local neck = jointed(model, body, "Neck", Vector3.new(1.1, 2.6, 1.3), coat, Vector3.new(0, 0.6, -2.6), -1.1, -0.55)
	weld(model, neck, "Mane", Vector3.new(0.35, 2.6, 0.5), mane, CFrame.new(0, 0.05, 0.6))
	local head = weld(model, neck, "Head", Vector3.new(1.0, 1.0, 2.1), coat, CFrame.new(0, 1.35, -0.75) * CFrame.Angles(-0.35, 0, 0))
	weld(model, head, "Muzzle", Vector3.new(0.92, 0.75, 0.6), shade, CFrame.new(0, -0.12, -1.2))
	-- Face marking.
	local faceWhite = Color3.fromRGB(240, 238, 232)
	if marking == "Blaze" then
		weld(model, head, "Blaze", Vector3.new(0.3, 0.06, 1.6), faceWhite, CFrame.new(0, 0.52, -0.3))
	elseif marking == "Star" then
		weld(model, head, "Star", Vector3.new(0.32, 0.06, 0.32), faceWhite, CFrame.new(0, 0.52, 0.2) * CFrame.Angles(0, math.pi / 4, 0))
	elseif marking == "Stripe" then
		weld(model, head, "Stripe", Vector3.new(0.14, 0.06, 1.7), faceWhite, CFrame.new(0, 0.52, -0.35))
	elseif marking == "Bald" then
		weld(model, head, "BaldFace", Vector3.new(0.8, 0.06, 1.9), faceWhite, CFrame.new(0, 0.52, -0.3))
		weld(model, head, "BaldMuzzle", Vector3.new(0.94, 0.4, 0.62), faceWhite, CFrame.new(0, 0.12, -1.2))
	end
	weld(model, head, "Forelock", Vector3.new(0.5, 0.2, 0.5), mane, CFrame.new(0, 0.6, 0.45))
	for _, side in ipairs({ -1, 1 }) do
		weld(model, head, "Ear", Vector3.new(0.2, 0.5, 0.22), coat, CFrame.new(side * 0.32, 0.72, 0.75) * CFrame.Angles(0, 0, side * -0.2))
		weld(model, head, "Eye", Vector3.new(0.06, 0.16, 0.16), Color3.fromRGB(20, 16, 14), CFrame.new(side * 0.51, 0.18, -0.1))
		weld(model, head, "Nostril", Vector3.new(0.06, 0.12, 0.12), Color3.fromRGB(30, 22, 18), CFrame.new(side * 0.47, -0.2, -1.42))
		-- Bridle straps.
		weld(model, head, "Bridle", Vector3.new(0.04, 0.9, 0.08), leather, CFrame.new(side * 0.52, 0.1, 0.1), leatherMaterial)
	end
	weld(model, head, "Noseband", Vector3.new(1.0, 0.1, 0.1), leather, CFrame.new(0, -0.05, -0.85), leatherMaterial)

	-- Tail.
	local tail = jointed(model, body, "Tail", Vector3.new(0.5, 2.3, 0.5), mane, Vector3.new(0, 0.7, 2.85), 1.1, -0.55)
	weld(model, tail, "TailTip", Vector3.new(0.6, 0.6, 0.6), mane, CFrame.new(0, -1.2, 0.05))

	-- Legs: thigh-to-hoof, socks by style, hooves.
	local socksOn = {
		None = {},
		Two = { LegFL = true, LegBR = true },
		Front = { LegFL = true, LegFR = true },
		Back = { LegBL = true, LegBR = true },
		Four = { LegFL = true, LegFR = true, LegBL = true, LegBR = true },
	}
	local on = socksOn[sockStyle] or socksOn.Two
	local legs = {
		{ "LegFL", Vector3.new(-0.6 * k, -0.75, -1.9) },
		{ "LegFR", Vector3.new(0.6 * k, -0.75, -1.9) },
		{ "LegBL", Vector3.new(-0.6 * k, -0.75, 1.9) },
		{ "LegBR", Vector3.new(0.6 * k, -0.75, 1.9) },
	}
	for _, l in ipairs(legs) do
		local leg = jointed(model, body, l[1], Vector3.new(0.55, 2.8, 0.6), coat, l[2], 1.4, 0)
		weld(model, leg, "Thigh", Vector3.new(0.7, 1.0, 0.75), coat, CFrame.new(0, 0.85, 0))
		if on[l[1]] then
			weld(model, leg, "Sock", Vector3.new(0.6, 0.7, 0.65), white, CFrame.new(0, -0.95, 0))
		end
		weld(model, leg, "Hoof", Vector3.new(0.62, 0.32, 0.7), hoof, CFrame.new(0, -1.5, -0.04))
	end

	-- Tack: blanket, saddle with a horn, stirrups, reins.
	weld(model, body, "Blanket", Vector3.new(W + 0.2, 0.14, 2.3), blanket, CFrame.new(0, 1.04, -0.1))
	weld(model, body, "BlanketEdge", Vector3.new(W + 0.3, 0.6, 0.1), blanket:Lerp(Color3.new(1, 1, 1), 0.2), CFrame.new(0, 0.8, -1.25))
	for _, side in ipairs({ -1, 1 }) do
		weld(model, body, "BlanketSide", Vector3.new(0.1, 0.8, 2.2), blanket, CFrame.new(side * (W / 2 + 0.06), 0.6, -0.1))
	end
	weld(model, body, "Saddle", Vector3.new(W - 0.4, 0.3, 1.7), leather, CFrame.new(0, 1.22, -0.1), leatherMaterial)
	weld(model, body, "Cantle", Vector3.new(1.4, 0.35, 0.25), leather, CFrame.new(0, 1.45, 0.65), leatherMaterial)
	weld(model, body, "Horn", Vector3.new(0.25, 0.45, 0.25), leather, CFrame.new(0, 1.55, -0.8), leatherMaterial)
	for _, side in ipairs({ -1, 1 }) do
		weld(model, body, "Strap", Vector3.new(0.05, 1.3, 0.12), leather, CFrame.new(side * (W / 2 + 0.13), 0.55, -0.1), leatherMaterial)
		weld(model, body, "Stirrup", Vector3.new(0.12, 0.12, 0.5), metal, CFrame.new(side * (W / 2 + 0.16), -0.15, -0.1), Enum.Material.Metal)
		weld(model, body, "Rein", Vector3.new(0.05, 0.05, 3.4), leather, CFrame.new(side * 0.45, 2.0, -2.4) * CFrame.Angles(0.33, 0, 0))
	end
	return model
end

-- The horse a stable selection describes (used by the server and the shop's
-- preview, so they always match). cat = TuskConfig.Horses; sel = { Coat,
-- Mane, Blanket, Saddle, Marking, Socks }.
-- Returns coat colour, mane colour, opts for HorseModel.build.
local function pick(list, id)
	for _, item in ipairs(list or {}) do
		if item.Id == id then
			return item
		end
	end
	return (list or {})[1]
end

-- A player's stable selection, from their attributes (HorseCoat, HorseMane,
-- HorseBlanket, HorseSaddle, HorseMarking, HorseSocks).
function HorseModel.selectionOf(player)
	return {
		Coat = player and player:GetAttribute("HorseCoat"),
		Mane = player and player:GetAttribute("HorseMane"),
		Blanket = player and player:GetAttribute("HorseBlanket"),
		Saddle = player and player:GetAttribute("HorseSaddle"),
		Marking = player and player:GetAttribute("HorseMarking"),
		Socks = player and player:GetAttribute("HorseSocks"),
	}
end

function HorseModel.lookFrom(cat, sel)
	cat, sel = cat or {}, sel or {}
	local coat = pick(cat.Coats, sel.Coat) or {}
	local maneItem = pick(cat.Manes, sel.Mane)
	local blanket = pick(cat.Blankets, sel.Blanket)
	local saddle = pick(cat.Saddles, sel.Saddle)
	local marking = pick(cat.Markings, sel.Marking)
	local socks = pick(cat.Socks, sel.Socks)
	local mane = (maneItem and maneItem.Color) or coat.Mane
	local opts = {
		Width = 1.9,
		Material = coat.Material and Enum.Material[coat.Material] or nil,
		Blanket = blanket and blanket.Color,
		Saddle = saddle and saddle.Color,
		SaddleMaterial = saddle and saddle.Material and Enum.Material[saddle.Material] or nil,
		Marking = marking and marking.Style or "Blaze",
		SockStyle = coat.Socks == false and (socks and socks.Style == "Two" and "None" or (socks and socks.Style)) or (socks and socks.Style or "Two"),
	}
	return coat.Body, mane, opts
end

return HorseModel
end

-- ======================================================================
-- MODULE: JohnnyOutfit
-- ======================================================================
__modules["JohnnyOutfit"] = function()
--[[
	JohnnyOutfit  (ServerScriptService.SpinServer.JohnnyOutfit)

	Gives a character Johnny Joestar's look while they play him (Tusk, Acts
	1-4), built from blocky parts (no catalog asset ids), matched to his art:
	  * a light-blue knit cap covered in pink stars, a gold horseshoe on the
	    front with a black horse head inside it, little frayed tips
	  * wavy blond hair to his shoulders
	  * a lavender scarf round his neck
	  * a light-blue top with a black V across the chest, a purple star
	    patch on the sleeve, sleeves pushed up to lavender cuffs at the elbow,
	    bare forearms and black wristbands
	  * light-blue trousers covered in pink stars
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local JohnnyOutfit = {}
JohnnyOutfit.Act = 1 -- (any Tusk Act: 1-4)

local C = {
	Cap = Color3.fromRGB(176, 214, 236),
	CapShade = Color3.fromRGB(140, 182, 210),
	Star = Color3.fromRGB(236, 140, 186),
	Gold = Color3.fromRGB(222, 180, 64),
	GoldDark = Color3.fromRGB(170, 130, 40),
	Horse = Color3.fromRGB(26, 24, 28),
	Hair = Color3.fromRGB(232, 206, 140),
	HairDark = Color3.fromRGB(196, 168, 104),
	Scarf = Color3.fromRGB(184, 160, 222),
	Suit = Color3.fromRGB(170, 208, 232),
	SuitShade = Color3.fromRGB(134, 174, 204),
	Chevron = Color3.fromRGB(26, 28, 34),
	Patch = Color3.fromRGB(120, 90, 170),
	Band = Color3.fromRGB(30, 30, 34),
	Shoe = Color3.fromRGB(60, 54, 70),
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

-- Little pink stars (a diamond and a cross) scattered over one face.
local function stars(part, outfit, faceCF, w, h, count, seed)
	for i = 1, count do
		local u = ((i * 37 + seed * 17) % 100) / 100 - 0.5
		local v = ((i * 59 + seed * 31) % 100) / 100 - 0.5
		local cf = faceCF * CFrame.new(u * w * 0.85, v * h * 0.85, 0)
		piece(part, outfit, "Star", Vector3.new(0.12, 0.12, 0.03), C.Star, cf * CFrame.Angles(0, 0, math.pi / 4))
		piece(part, outfit, "Star", Vector3.new(0.2, 0.05, 0.03), C.Star, cf)
	end
end

-- Stars all round a box laid over a part.
local function starry(part, outfit, size, cf, count, seed)
	local x, z = size.X / 2 + 0.015, size.Z / 2 + 0.015
	stars(part, outfit, cf * CFrame.new(0, 0, -z), size.X, size.Y, count, seed)
	stars(part, outfit, cf * CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi, 0), size.X, size.Y, count, seed + 1)
	stars(part, outfit, cf * CFrame.new(x, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), size.Z, size.Y, math.max(1, count - 1), seed + 2)
	stars(part, outfit, cf * CFrame.new(-x, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), size.Z, size.Y, math.max(1, count - 1), seed + 3)
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Wavy blond hair down to the shoulders.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.18 * s, 1.0 * s, head.Size.Z * 0.85), C.Hair, CFrame.new(side * (w + 0.08 * s), -0.3 * s, 0.06 * s))
		piece(head, outfit, "HairWave", Vector3.new(0.22 * s, 0.3 * s, head.Size.Z * 0.5), C.HairDark, CFrame.new(side * (w + 0.12 * s), -0.75 * s, 0.1 * s) * CFrame.Angles(0, 0, side * 0.3))
	end
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.3 * s, 1.0 * s, 0.22 * s), C.Hair, CFrame.new(0, -0.4 * s, d + 0.1 * s))
	piece(head, outfit, "Bangs", Vector3.new(head.Size.X * 0.5, 0.18 * s, 0.1 * s), C.Hair, CFrame.new(0.15 * s, h - 0.42 * s, -d - 0.03 * s) * CFrame.Angles(0, 0, -0.25))
	-- The knit cap, pulled down low, with a folded band and little frayed tips.
	local capSize = Vector3.new(head.Size.X + 0.2 * s, 0.75 * s, head.Size.Z + 0.2 * s)
	local capCF = CFrame.new(0, h - 0.12 * s, 0.02 * s)
	piece(head, outfit, "Cap", capSize, C.Cap, capCF)
	piece(head, outfit, "CapTop", Vector3.new(head.Size.X * 0.8, 0.2 * s, head.Size.Z * 0.8), C.Cap, CFrame.new(0, h + 0.34 * s, 0.04 * s))
	piece(head, outfit, "CapBand", Vector3.new(head.Size.X + 0.26 * s, 0.18 * s, head.Size.Z + 0.26 * s), C.CapShade, CFrame.new(0, h - 0.42 * s, 0.02 * s))
	starry(head, outfit, capSize, capCF, 3, 4)
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "CapTip", Vector3.new(0.1 * s, 0.3 * s, 0.1 * s), C.CapShade, CFrame.new(side * (w + 0.02 * s), h + 0.24 * s, 0.2 * s) * CFrame.Angles(0, 0, side * -0.5))
	end
	-- Gold horseshoe on the front, opening upward, a black horse head inside.
	local hf = -d - 0.14 * s
	local hy = h - 0.02 * s
	piece(head, outfit, "Horseshoe", Vector3.new(0.5 * s, 0.1 * s, 0.06 * s), C.Gold, CFrame.new(0, hy - 0.26 * s, hf))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Horseshoe", Vector3.new(0.1 * s, 0.5 * s, 0.06 * s), C.Gold, CFrame.new(side * 0.22 * s, hy, hf) * CFrame.Angles(0, 0, side * 0.08))
		piece(head, outfit, "Nail", Vector3.new(0.04 * s, 0.04 * s, 0.04 * s), C.GoldDark, CFrame.new(side * 0.22 * s, hy + 0.05 * s, hf - 0.04 * s))
	end
	piece(head, outfit, "HorseHead", Vector3.new(0.18 * s, 0.34 * s, 0.04 * s), C.Horse, CFrame.new(0, hy - 0.02 * s, hf + 0.02 * s) * CFrame.Angles(0, 0, 0.3))
	piece(head, outfit, "HorseHead", Vector3.new(0.18 * s, 0.1 * s, 0.04 * s), C.Horse, CFrame.new(0.05 * s, hy + 0.14 * s, hf + 0.02 * s))
end

local function body(character, outfit)
	local headPart = character:FindFirstChild("Head")
	local skin = headPart and headPart.Color or Color3.fromRGB(238, 200, 170)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Top", s + Vector3.new(0.1, 0.02, 0.1), C.Suit, CFrame.new())
		-- Lavender scarf round the neck.
		piece(upper, outfit, "Scarf", Vector3.new(s.X * 0.62, 0.34, s.Z + 0.22), C.Scarf, CFrame.new(0, top + 0.1, 0))
		piece(upper, outfit, "ScarfDrape", Vector3.new(0.5, 0.36, 0.08), C.Scarf, CFrame.new(0.1, top - 0.14, front - 0.06))
		-- The black V across the chest (and a matching one at the back).
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Chevron", Vector3.new(0.22, s.Y * 0.75, 0.05), C.Chevron, CFrame.new(side * s.X * 0.22, top - s.Y * 0.3, front - 0.06) * CFrame.Angles(0, 0, side * -0.9))
			piece(upper, outfit, "Chevron", Vector3.new(0.22, s.Y * 0.75, 0.05), C.Chevron, CFrame.new(side * s.X * 0.22, top - s.Y * 0.3, -front + 0.06) * CFrame.Angles(0, 0, side * 0.9))
		end
		stars(upper, outfit, CFrame.new(0, -s.Y * 0.3, front - 0.06), s.X * 0.9, s.Y * 0.3, 2, 9)
	end
	local waist = lower or upper
	if waist and lower then
		piece(lower, outfit, "Pants", lower.Size + Vector3.new(0.06, 0.02, 0.06), C.Suit, CFrame.new())
	end
	-- Sleeves pushed up to the elbow (lavender cuffs), bare forearms, black wristbands.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local tall = as.Y > 1.8
			local out = name:find("Left") and -1 or 1
			if name:find("Upper") or tall then
				local h = tall and as.Y * 0.55 or as.Y
				piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.12, h, as.Z + 0.12), C.Suit, CFrame.new(0, as.Y / 2 - h / 2, 0))
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.18, 0.28, as.Z + 0.18), C.Scarf, CFrame.new(0, as.Y / 2 - h, 0))
				if name:find("Right") or name == "Right Arm" then
					piece(arm, outfit, "Patch", Vector3.new(0.05, 0.36, 0.36), C.Patch, CFrame.new(out * (as.X / 2 + 0.08), as.Y / 2 - 0.4, 0))
				end
			end
			if name:find("Lower") or tall then
				-- Bare forearm (covers whatever shirt the avatar wears).
				local fh = tall and as.Y * 0.45 or as.Y
				piece(arm, outfit, "Skin", Vector3.new(as.X + 0.04, fh, as.Z + 0.04), skin, CFrame.new(0, -as.Y / 2 + fh / 2, 0))
				piece(arm, outfit, "Wristband", Vector3.new(as.X + 0.12, 0.3, as.Z + 0.12), C.Band, CFrame.new(0, -as.Y / 2 + 0.25, 0))
			end
		end
	end
	-- Light-blue trousers covered in pink stars.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local size = leg.Size + Vector3.new(0.06, 0.02, 0.06)
			piece(leg, outfit, "Pants", size, C.Suit, CFrame.new())
			starry(leg, outfit, size, CFrame.new(), leg.Size.Y > 1.8 and 3 or 2, #name)
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Shoe", foot.Size + Vector3.new(0.08, 0.06, 0.1), C.Shoe, CFrame.new())
		end
	end
end

function JohnnyOutfit.apply(character)
	if character:FindFirstChild("JohnnyOutfit") then
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
	outfit.Name = "JohnnyOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function JohnnyOutfit.remove(character)
	local outfit = character:FindFirstChild("JohnnyOutfit")
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
		local function isJohnny()
			local act = character:GetAttribute("TuskAct")
			return type(act) == "number" and act >= 1 and act <= 4
		end
		if isJohnny() then
			task.delay(0.3, function()
				if character.Parent and isJohnny() then
					JohnnyOutfit.apply(character)
				end
			end)
		else
			JohnnyOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function JohnnyOutfit.init()
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

return JohnnyOutfit
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
	Bounty      : both ways         bounty board (open / accept / tracker)
	Race        : both ways         the Steel Ball Run horse race (join / leave / standings)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES = { "SpinRequest", "SpinFX", "TuskRequest", "TuskFX", "WorldFX", "Bounty", "Race" }

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

---------------------------------------------------------------------------
-- Stopped time (The World): a zone where projectiles hang in the air. Other
-- people's projectiles stop the moment they're inside; the zone owner's own
-- stop once they've flown OwnFreezeAfter studs. They all fly on when the
-- zone ends. Clients are told ("ProjectileFreeze" / "ProjectileResume") with
-- each projectile's flight time so the visuals stop and restart in step.
---------------------------------------------------------------------------
ProjectileService.OwnFreezeAfter = 5
local zones = {} -- [token] = { Center, Radius, Owner }

local function flightOf(p)
	return p.Traveled / math.max(p.Speed, 1e-3)
end

local function inZone(p)
	for token, z in pairs(zones) do
		if (p.Position - z.Center).Magnitude <= z.Radius and (p.Owner ~= z.Owner or p.Traveled >= ProjectileService.OwnFreezeAfter) then
			return token
		end
	end
	return nil
end

local function freeze(list, token)
	local ids, flights, spawned = {}, {}, {}
	for _, p in ipairs(list) do
		p.FrozenBy = token
		table.insert(ids, p.Id)
		table.insert(flights, flightOf(p))
		table.insert(spawned, p.SpawnedAt)
	end
	if #ids > 0 then
		FX:FireAllClients("ProjectileFreeze", { Ids = ids, Flights = flights, Spawned = spawned })
	end
end

function ProjectileService.stopTime(token, center, radius, owner)
	zones[token] = { Center = center, Radius = radius, Owner = owner }
	local list = {}
	for _, p in pairs(active) do
		if not p.FrozenBy and inZone(p) == token then
			table.insert(list, p)
		end
	end
	freeze(list, token)
end

function ProjectileService.resumeTime(token)
	zones[token] = nil
	local ids, flights, spawned = {}, {}, {}
	for _, p in pairs(active) do
		if p.FrozenBy == token then
			p.FrozenBy = nil
			table.insert(ids, p.Id)
			table.insert(flights, flightOf(p))
			table.insert(spawned, p.SpawnedAt)
		end
	end
	if #ids > 0 then
		FX:FireAllClients("ProjectileResume", { Ids = ids, Flights = flights, Spawned = spawned })
	end
end

function ProjectileService.isTimeStopped(position)
	for _, z in pairs(zones) do
		if (position - z.Center).Magnitude <= z.Radius then
			return true
		end
	end
	return false
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
		SpawnedAt = workspace:GetServerTimeNow(),
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
		ServerTime = p.SpawnedAt,
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
		if p.FrozenBy then
			continue -- hanging in stopped time
		end
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
				if next(zones) then
					local token = inZone(p)
					if token then
						freeze({ p }, token)
					end
				end
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
-- MODULE: RaceService
-- ======================================================================
__modules["RaceService"] = function()
--[[
	RaceService  (ServerScriptService.SpinServer.RaceService)

	THE STEEL BALL RUN: a horse race round the map, every 10 minutes, and
	your own horse (M) to ride anywhere the rest of the time.
	  * ENTRY: every Race.Every seconds entry opens for EntryTime seconds.
	    Everyone gets a banner with a JOIN button (or press E at the
	    starting grid). The numbered gates go up round the course.
	  * START: riders line up 4 abreast inside the map's fenced race track,
	    behind its START arch, on their own horse (coat and blanket from the
	    STABLE) with its hooves on the ground, held for the countdown.
	    NPC JOCKEYS (Race.NPCRacers) line up with them.
	  * THE RACE: down the track, out past its end, round the open desert
	    to the east and back to the FINISH by the spawn, through the gates in
	    order. You can fight, dash, block and use your Stand on horseback.
	    Going down puts you out. Jockeys find their way with pathfinding (and
	    hop free if they get stuck).
	  * PRIZES: Cash for the top 3 players (and a little for every
	    finisher); a Saint's Corpse part appears at the finish for a winning
	    player. Finishers keep their horse to ride on.
	  * YOUR HORSE (M): call it, ride it anywhere, press M again to get off
	    (not during a race you're in; the race gives you yours).
	The rider sits exactly on the saddle: the horse is welded under their
	root with its hooves on the ground, and every client lifts the rider's
	body up onto the saddle (RideLift). HipHeight is never changed (that let
	Roblox's own HipHeight resets send horses floating off).
	Clients: RaceClient (HUD, beacon, gallop, M key). ReplicatedStorage
	attributes: SpinRacePhase, SpinRaceNext, SpinRaceEntryEnds, SpinRaceGoAt,
	SpinRaceStart. Remote: Net "Race" (client: "Join" / "Leave" / "Horse").
	Numbers: TuskConfig.Race and TuskConfig.Horses.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local PlayersService = Players

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Net = __require("Net")
local Adapter = __require("CombatAdapter")
local HorseModel = __require("HorseModel")
local PathfindingService = game:GetService("PathfindingService")

local RaceService = {}
local cfg = TuskConfig.Race or {}
local Remote
local rng = Random.new()

local phase = nil -- nil (idle) | "Entry" | "Countdown" | "Racing"
local nextEntryAt = 0
local entryEnds = 0
local raceStart = 0
local winnerAt
local racers = {} -- [player] = { Next, Finished, Place, Time }
local finishOrder = {}
local course -- { Start = Vector3, StartFacing = Vector3, Gates = { Vector3 ... } }
local courseFolder
local startPrompt

local function now()
	return workspace:GetServerTimeNow()
end

local function setAttr(k, v)
	ReplicatedStorage:SetAttribute(k, v)
end

local function origin()
	local map = workspace:FindFirstChild("SBRMap")
	return map and map:GetAttribute("Origin") or Vector3.new()
end

-- The ground under a point (ignoring characters and the course itself).
local function groundAt(position)
	local ignore = { courseFolder }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	for _, m in ipairs(CollectionService:GetTagged("SpinFighter")) do
		table.insert(ignore, m)
	end
	for _, r in pairs(racers) do
		if r.Model then
			table.insert(ignore, r.Model)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), params)
	return hit and hit.Position or position
end

local function send(player, kind, data)
	if Remote then
		Remote:FireClient(player, kind, data or {})
	end
end

local function broadcast(kind, data)
	if Remote then
		Remote:FireAllClients(kind, data or {})
	end
end

local function pay(player, amount)
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	if cash and amount > 0 then
		cash.Value = cash.Value + amount
	end
end

---------------------------------------------------------------------------
-- The course: numbered gates round the map, a start gate with the entry prompt
---------------------------------------------------------------------------
local WOOD = Color3.fromRGB(112, 74, 44)
local RED = Color3.fromRGB(176, 40, 36)
local CREAM = Color3.fromRGB(240, 228, 200)

local function block(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function bannerText(part, text, color, bg)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		gui.LightInfluence = 0.4
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = bg
		label.BackgroundTransparency = 0
		label.Font = Enum.Font.Bangers
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.5
		label.Parent = gui
		gui.Parent = part
	end
end

-- A gate across the course at `position`, facing along `facing`.
local function buildGate(parent, position, facing, text, kind)
	local width = cfg.GateWidth or 30
	local ground = groundAt(position)
	local cf = CFrame.lookAt(ground, ground + Vector3.new(facing.X, 0, facing.Z))
	local gate = Instance.new("Model")
	gate.Name = "Gate_" .. text
	local postColor = kind == "Finish" and Color3.fromRGB(30, 30, 30) or WOOD
	for _, side in ipairs({ -1, 1 }) do
		block(gate, "Post", Vector3.new(1.2, 16, 1.2), cf * CFrame.new(side * width / 2, 8, 0), postColor)
		block(gate, "PostCap", Vector3.new(1.8, 0.6, 1.8), cf * CFrame.new(side * width / 2, 16.2, 0), RED)
		-- A pennant on each post.
		block(gate, "Pennant", Vector3.new(0.1, 1.4, 2.4), cf * CFrame.new(side * width / 2, 17.4, 1.2), kind == "Finish" and Color3.new(1, 1, 1) or RED, Enum.Material.Fabric)
	end
	local banner = block(gate, "Banner", Vector3.new(width - 2, 3.4, 0.3), cf * CFrame.new(0, 13.5, 0), kind == "Finish" and Color3.new(1, 1, 1) or CREAM, Enum.Material.Fabric)
	if kind == "Finish" then
		-- Chequered.
		for i = 0, 13 do
			for j = 0, 1 do
				if (i + j) % 2 == 0 then
					block(gate, "Check", Vector3.new((width - 2) / 14, 1.7, 0.34), cf * CFrame.new(-(width - 2) / 2 + (i + 0.5) * (width - 2) / 14, 13.5 + (j - 0.5) * 1.7, 0), Color3.fromRGB(20, 20, 20), Enum.Material.Fabric)
				end
			end
		end
		local sign = block(gate, "Sign", Vector3.new(12, 3, 0.4), cf * CFrame.new(0, 17.2, 0), Color3.fromRGB(20, 20, 20))
		bannerText(sign, "FINISH", Color3.fromRGB(255, 220, 90), Color3.fromRGB(20, 20, 20))
	else
		bannerText(banner, text, RED, CREAM)
	end
	-- The line on the ground.
	block(gate, "Line", Vector3.new(width, 0.2, 1.2), cf * CFrame.new(0, 0.1, 0), kind == "Finish" and Color3.new(1, 1, 1) or CREAM, Enum.Material.SmoothPlastic)
	gate:SetAttribute("GateIndex", tonumber(text) or 0)
	gate.Parent = parent
	return gate, ground
end

-- The course gates (the start is the map's own fenced track and arch).
local function buildCourse()
	if courseFolder then
		courseFolder:Destroy()
	end
	courseFolder = Instance.new("Folder")
	courseFolder.Name = "SteelBallRunCourse"
	courseFolder.Parent = workspace
	local o = origin()
	local start = groundAt(o + (cfg.Start or Vector3.new(0, 0, 118)))
	local facing = cfg.StartFacing or Vector3.new(0, 0, -1)
	facing = Vector3.new(facing.X, 0, facing.Z).Unit
	local gates = {}
	local points = { start }
	for _, offset in ipairs(cfg.Checkpoints or {}) do
		table.insert(points, groundAt(o + offset))
	end
	for i = 2, #points do
		local isFinish = i == #points
		local _, ground = buildGate(courseFolder, points[i], points[i] - points[i - 1], isFinish and "FINISH" or tostring(i - 1), isFinish and "Finish" or "Gate")
		table.insert(gates, ground)
	end
	-- The starting grid: a painted line across the track, and the entry
	-- prompt on an invisible marker in the middle of it (nothing to bump into).
	local right = facing:Cross(Vector3.new(0, 1, 0)).Unit
	local lineCf = CFrame.lookAt(start, start + facing)
	block(courseFolder, "StartLine", Vector3.new(24, 0.2, 0.8), lineCf * CFrame.new(0, 0.1, 0), CREAM, Enum.Material.SmoothPlastic)
	local marker = block(courseFolder, "EntryMarker", Vector3.new(4, 4, 4), lineCf * CFrame.new(0, 3, 8), CREAM)
	marker.Transparency = 1
	startPrompt = Instance.new("ProximityPrompt")
	startPrompt.ActionText = "Enter the Race"
	startPrompt.ObjectText = "STEEL BALL RUN"
	startPrompt.HoldDuration = 0
	startPrompt.MaxActivationDistance = 16
	startPrompt.RequiresLineOfSight = false
	startPrompt.Enabled = phase == "Entry"
	startPrompt.Parent = marker
	startPrompt.Triggered:Connect(function(player)
		RaceService.join(player)
	end)
	course = { Start = start, StartFacing = facing, Right = right, Gates = gates }
	return course
end

---------------------------------------------------------------------------
-- Horses (players' own, race horses, jockeys')
---------------------------------------------------------------------------
local hcfg = TuskConfig.Horses or {}

local function catalogue(list, id)
	for _, item in ipairs(list or {}) do
		if item.Id == id then
			return item
		end
	end
	return (list or {})[1]
end

-- The horse a player set up in the stable (the same look the shop previews).
local function lookFor(player)
	local body, mane, opts = HorseModel.lookFrom(hcfg, HorseModel.selectionOf(player))
	return { Body = body, Mane = mane, Opts = opts, Name = player and player:GetAttribute("HorseName") }
end

local function randomLook()
	local coats = cfg.Coats or {}
	local c = coats[rng:NextInteger(1, math.max(#coats, 1))] or {}
	local blankets = hcfg.Blankets or {}
	local b = blankets[rng:NextInteger(1, math.max(#blankets, 1))]
	return { Body = c[1], Mane = c[2], Blanket = b and b.Color, Width = 1.9 }
end

-- Where the rider's seat is (the bottom of their hips), relative to the root,
-- in the rest pose: read from the root joint's C0 / C1 (positions replicated
-- from a player's client include their animation, e.g. the ride lift).
local function seatHeight(character, root)
	local hips = character:FindFirstChild("LowerTorso")
	local joint = hips and hips:FindFirstChild("Root")
	if not hips then
		local torso = character:FindFirstChild("Torso")
		hips = torso
		joint = root:FindFirstChild("RootJoint")
	end
	if hips and joint and joint:IsA("Motor6D") then
		local rest = joint.C0 * joint.C1:Inverse()
		return rest.Position.Y - hips.Size.Y / 2
	end
	if hips then
		return (root.CFrame:Inverse() * hips.Position).Y - hips.Size.Y / 2
	end
	return -1
end

-- Place the horse under a rider: welded to their root with its hooves on the
-- ground at the rider's normal height. The rider's HipHeight is NEVER
-- changed (Roblox can reset it, which made horses float away); instead the
-- clients lift the rider's body onto the saddle (RideLift, TuskAnimation).
-- Re-fitted whenever HipHeight changes.
local function fitHorse(character)
	local horse = character and character:FindFirstChild("RaceHorse")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local body = horse and horse.PrimaryPart
	local w = body and body:FindFirstChild("HorseWeld")
	if not w or not humanoid or not root then
		return
	end
	local bodyY = HorseModel.HoofDepth - (humanoid.HipHeight + root.Size.Y / 2)
	w.C0 = CFrame.new(0, bodyY, -0.4)
	horse:SetAttribute("BodyY", bodyY)
	local seat = character:GetAttribute("RideSeat") or -0.25
	character:SetAttribute("RideLift", math.max(0, bodyY + HorseModel.SaddleTop - seat))
end

local function mount(character, look, speed, kind)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local old = character:FindFirstChild("RaceHorse")
	if old then
		old:Destroy()
	end
	-- (An older version raised HipHeight: put it back if it's still raised.)
	local oldBase = character:GetAttribute("RaceHipBase")
	if oldBase then
		humanoid.HipHeight = oldBase
		character:SetAttribute("RaceHipBase", nil)
	end
	look = look or {}
	local horse = HorseModel.build(look.Body, look.Mane, look.Opts or { Width = look.Width or 1.9, Blanket = look.Blanket, Socks = look.Socks, Material = look.Material })
	horse.Name = "RaceHorse"
	if look.Name then
		horse:SetAttribute("HorseName", look.Name)
	end
	for _, d in ipairs(horse:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	character:SetAttribute("RideSeat", seatHeight(character, root))
	local body = horse.PrimaryPart
	local w = Instance.new("Weld")
	w.Name = "HorseWeld"
	w.Part0 = root
	w.Part1 = body
	w.Parent = body
	horse.Parent = character
	fitHorse(character)
	body.CFrame = root.CFrame * w.C0
	if not character:GetAttribute("HorseFitHooked") then
		character:SetAttribute("HorseFitHooked", true)
		humanoid:GetPropertyChangedSignal("HipHeight"):Connect(function()
			fitHorse(character)
		end)
	end
	CollectionService:AddTag(horse, "SpinHorse")
	Adapter.setMoveModifier(humanoid, "Horse", speed or 3)
	character:SetAttribute("Riding", kind or "Ride")
	return horse
end

local function dismount(character)
	if not character then
		return
	end
	local horse = character:FindFirstChild("RaceHorse")
	if horse then
		horse:Destroy()
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local base = character:GetAttribute("RaceHipBase")
		if base then
			humanoid.HipHeight = base
		end
		Adapter.setMoveModifier(humanoid, "Horse", nil)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and character:GetAttribute("RaceAnchored") then
		root.Anchored = false
	end
	character:SetAttribute("RaceAnchored", nil)
	character:SetAttribute("RaceHipBase", nil)
	character:SetAttribute("Riding", nil)
	character:SetAttribute("RideLift", nil)
end
RaceService.dismount = dismount

-- Put a (mounted) character standing on the ground at `position`, facing `facing`.
local function standAt(character, position, facing)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	local ground = groundAt(position)
	local at = ground + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 + 0.05, 0)
	character:PivotTo(CFrame.lookAt(at, at + facing))
end

-- M: call your horse / send it away.
function RaceService.toggleHorse(player)
	if hcfg.Enabled == false then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local r = racers[player]
	if r and not r.Finished and (phase == "Countdown" or phase == "Racing") then
		send(player, "Denied", { Reason = "You're racing!" })
		return
	end
	local t = now()
	if (player:GetAttribute("HorseReadyAt") or 0) > t then
		return
	end
	player:SetAttribute("HorseReadyAt", t + (hcfg.Cooldown or 2))
	if character:FindFirstChild("RaceHorse") then
		dismount(character)
		send(player, "Horse", { Riding = false })
	else
		if not Adapter.canAct(player) then
			return
		end
		mount(character, lookFor(player), hcfg.RideSpeed or 2.8, "Ride")
		send(player, "Horse", { Riding = true })
	end
end

-- The stable changed: re-saddle anyone riding their own horse.
function RaceService.refreshHorse(player)
	local character = player.Character
	if character and character:FindFirstChild("RaceHorse") then
		local kind = character:GetAttribute("Riding")
		mount(character, lookFor(player), kind == "Race" and (cfg.HorseSpeed or 3.2) or (hcfg.RideSpeed or 2.8), kind)
	end
end

---------------------------------------------------------------------------
-- Racers: players and NPC jockeys. racers[key] = r, where key is the Player
-- (or the jockey's record) and r = { Player?, Jockey?, Name, UserId, Next,
-- Finished, Place, Time }.
---------------------------------------------------------------------------
local function charOf(r)
	return r.Player and r.Player.Character or r.Model
end

local function racerCount(playersOnly)
	local n = 0
	for _, r in pairs(racers) do
		if not playersOnly or r.Player then
			n = n + 1
		end
	end
	return n
end

function RaceService.join(player)
	if phase ~= "Entry" or racers[player] then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	racers[player] = { Player = player, Name = player.DisplayName, UserId = player.UserId, Next = 1 }
	player:SetAttribute("RaceEntered", true)
	send(player, "Joined", { Ends = entryEnds })
	broadcast("Entrants", { Count = racerCount(true) })
end

local function out(key, reason)
	local r = racers[key]
	if not r then
		return
	end
	racers[key] = nil
	if r.Player then
		r.Player:SetAttribute("RaceEntered", nil)
		dismount(r.Player.Character)
		send(r.Player, "Out", { Reason = reason })
		broadcast("Entrants", { Count = racerCount(true) })
	elseif r.Model then
		local model = r.Model
		task.delay(3, function()
			model:Destroy()
		end)
	end
end

function RaceService.leave(player)
	local r = racers[player]
	if not r then
		return
	end
	if phase == "Entry" then
		out(player, "You left the race.")
	elseif not r.Finished then
		out(player, "You pulled out of the race.")
	end
end

---------------------------------------------------------------------------
-- NPC jockeys
---------------------------------------------------------------------------
local JOCKEY_SILKS = {
	Color3.fromRGB(200, 50, 50), Color3.fromRGB(50, 90, 200), Color3.fromRGB(240, 200, 60),
	Color3.fromRGB(60, 160, 90), Color3.fromRGB(150, 70, 170), Color3.fromRGB(240, 140, 50),
}

local function spawnJockey(index)
	local names = cfg.NPCNames or { "Jockey" }
	local name = names[((index - 1) % #names) + 1]
	local desc = Instance.new("HumanoidDescription")
	local silk = JOCKEY_SILKS[((index - 1) % #JOCKEY_SILKS) + 1]
	desc.HeadColor = Color3.fromRGB(226, 186, 150)
	desc.LeftArmColor = silk
	desc.RightArmColor = silk
	desc.TorsoColor = silk
	desc.LeftLegColor = Color3.fromRGB(235, 230, 220)
	desc.RightLegColor = Color3.fromRGB(235, 230, 220)
	local ok, model = pcall(function()
		return PlayersService:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return nil
	end
	model.Name = "Jockey: " .. name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = "Jockey: " .. name
	humanoid.MaxHealth = cfg.NPCHealth or 120
	humanoid.Health = humanoid.MaxHealth
	model:SetAttribute("RaceJockey", true)
	model.Parent = workspace
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root.SetNetworkOwner then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	local skill = cfg.NPCSkill or { 0.8, 0.95 }
	local r = { Jockey = true, Model = model, Name = "Jockey: " .. name, UserId = -500 - index, Next = 1, Skill = skill[1] + rng:NextNumber() * (skill[2] - skill[1]) }
	humanoid.Died:Connect(function()
		for key, rr in pairs(racers) do
			if rr == r then
				out(key, "down")
			end
		end
	end)
	return r
end

-- A jockey rides the course: pathfinding to each gate, hopping free if stuck.
local function runJockey(key, r)
	local model = r.Model
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	local path
	pcall(function()
		path = PathfindingService:CreatePath({ AgentRadius = 3, AgentHeight = 9, AgentCanJump = true, WaypointSpacing = 10 })
	end)
	local waypoints, wi, forGate
	local lastPos, lastProgress = root.Position, now()
	local function step()
		if phase ~= "Racing" or racers[key] ~= r or r.Finished or humanoid.Health <= 0 or not model.Parent then
			return
		end
		local gate = course.Gates[r.Next]
		if not gate then
			return
		end
		if forGate ~= r.Next then
			forGate = r.Next
			waypoints, wi = nil, 1
			if path then
				local ok = pcall(function()
					path:ComputeAsync(root.Position, gate)
				end)
				if ok and path.Status == Enum.PathStatus.Success then
					waypoints, wi = path:GetWaypoints(), 2
				end
			end
		end
		local target = gate
		if waypoints and waypoints[wi] then
			target = waypoints[wi].Position
			local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
			if flat.Magnitude < 7 then
				if waypoints[wi].Action == Enum.PathWaypointAction.Jump then
					humanoid.Jump = true
				end
				wi = wi + 1
				target = waypoints[wi] and waypoints[wi].Position or gate
			end
		end
		humanoid:MoveTo(target)
		-- Stuck? Jump; still stuck? Hop free towards the gate.
		if (root.Position - lastPos).Magnitude > 4 then
			lastPos, lastProgress = root.Position, now()
		elseif now() - lastProgress > 2 then
			humanoid.Jump = true
			if now() - lastProgress > 5 then
				local dir = Vector3.new(gate.X - root.Position.X, 0, gate.Z - root.Position.Z)
				dir = dir.Magnitude > 0.1 and dir.Unit or course.StartFacing
				standAt(model, root.Position + dir * 12, dir)
				lastPos, lastProgress = root.Position, now()
				forGate = nil
			end
		end
		task.delay(0.25, step)
	end
	step()
end

---------------------------------------------------------------------------
-- Entry, start, race, results
---------------------------------------------------------------------------
local function openEntry()
	phase = "Entry"
	racers, finishOrder, winnerAt = {}, {}, nil
	buildCourse()
	entryEnds = now() + (cfg.EntryTime or 45)
	nextEntryAt = now() + (cfg.Every or 600)
	if startPrompt then
		startPrompt.Enabled = true
	end
	setAttr("SpinRacePhase", "Entry")
	setAttr("SpinRaceEntryEnds", entryEnds)
	setAttr("SpinRaceNext", nextEntryAt)
	broadcast("EntryOpen", { Ends = entryEnds })
end

local function cleanup()
	for key, r in pairs(racers) do
		if r.Player then
			r.Player:SetAttribute("RaceEntered", nil)
			local character = r.Player.Character
			-- Riders keep their horse (now theirs to ride around).
			if character and character:FindFirstChild("RaceHorse") then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local root = character:FindFirstChild("HumanoidRootPart")
				if root and character:GetAttribute("RaceAnchored") then
					root.Anchored = false
					character:SetAttribute("RaceAnchored", nil)
				end
				if humanoid then
					Adapter.setMoveModifier(humanoid, "Horse", hcfg.RideSpeed or 2.8)
				end
				character:SetAttribute("Riding", "Ride")
			end
		elseif r.Model then
			local model = r.Model
			task.delay(2, function()
				model:Destroy()
			end)
		end
		racers[key] = nil
	end
	racers, finishOrder, winnerAt = {}, {}, nil
	phase = nil
	setAttr("SpinRacePhase", nil)
	setAttr("SpinRaceGoAt", nil)
	setAttr("SpinRaceStart", nil)
	if courseFolder then
		courseFolder:Destroy()
		courseFolder = nil
	end
	startPrompt = nil
end

local function startRace()
	if startPrompt then
		startPrompt.Enabled = false
	end
	-- Only riders still alive and in the game.
	for key, r in pairs(racers) do
		local player = r.Player
		local h = player and player.Parent and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not h or h.Health <= 0 then
			racers[key] = nil
			if player then
				player:SetAttribute("RaceEntered", nil)
			end
		end
	end
	if racerCount(true) == 0 then
		broadcast("Cancelled", { Reason = "Nobody entered the Steel Ball Run this time." })
		cleanup()
		return
	end
	-- NPC jockeys join the field.
	for i = 1, cfg.NPCRacers or 0 do
		local r = spawnJockey(i)
		if r then
			racers[r] = r
		end
	end
	phase = "Countdown"
	setAttr("SpinRacePhase", "Countdown")
	local goAt = now() + (cfg.Countdown or 4)
	setAttr("SpinRaceGoAt", goAt)
	-- Line everyone up inside the track, 4 abreast, on their horses, hooves on the ground.
	local list = {}
	for key, r in pairs(racers) do
		table.insert(list, { Key = key, R = r })
	end
	table.sort(list, function(a, b)
		return (a.R.Player and 0 or 1) < (b.R.Player and 0 or 1) -- players at the front
	end)
	local facing, right = course.StartFacing, course.Right
	local cols = cfg.GridColumns or 4
	for i, e in ipairs(list) do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local spot = course.Start - facing * (row * (cfg.GridRowGap or 7) + 3) + right * ((col - (cols - 1) / 2) * (cfg.GridSpacing or 4.5))
		local character = charOf(e.R)
		if character then
			local look = e.R.Player and lookFor(e.R.Player) or randomLook()
			mount(character, look, (cfg.HorseSpeed or 3.2) * (e.R.Skill or 1), "Race")
			standAt(character, spot, facing)
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				root.Anchored = true
				character:SetAttribute("RaceAnchored", true)
			end
		end
	end
	broadcast("Countdown", { GoAt = goAt, Riders = #list, Total = #course.Gates })
	task.delay(cfg.Countdown or 4, function()
		if phase ~= "Countdown" then
			return
		end
		phase = "Racing"
		raceStart = now()
		setAttr("SpinRacePhase", "Racing")
		setAttr("SpinRaceStart", raceStart)
		for key, r in pairs(racers) do
			local character = charOf(r)
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				root.Anchored = false
				character:SetAttribute("RaceAnchored", nil)
			end
			if r.Jockey then
				task.spawn(runJockey, key, r)
			end
		end
		broadcast("Go", { Total = #course.Gates })
	end)
end

local function endRace(reason)
	local results = {}
	for _, r in ipairs(finishOrder) do
		table.insert(results, { Name = r.Name, Place = r.Place, Time = r.Time, Jockey = r.Jockey })
	end
	broadcast("Results", { List = results, Reason = reason })
	cleanup()
end

local function finish(r)
	table.insert(finishOrder, r)
	r.Finished = true
	r.Place = #finishOrder
	r.Time = now() - raceStart
	local prize, partName = 0, nil
	if r.Player then
		-- Prizes go by place among the players.
		local playerPlace = 0
		for _, f in ipairs(finishOrder) do
			if f.Player then
				playerPlace = playerPlace + 1
			end
		end
		local prizes = cfg.Prizes or { 500, 250, 150 }
		prize = prizes[playerPlace] or cfg.FinishPrize or 50
		pay(r.Player, prize)
		if r.Place == 1 and cfg.WinnerCorpsePart ~= false then
			-- A Saint's Corpse part appears at the finish for the winner.
			local ok, C = pcall(function()
				return __require("CorpseService")
			end)
			local root = r.Player.Character and r.Player.Character:FindFirstChild("HumanoidRootPart")
			if ok and C and C.summon and root then
				local _, name = C.summon(root.Position + course.StartFacing * 6)
				partName = name
			end
		end
		-- Finished: their horse is theirs to ride around now.
		local character = r.Player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and character:FindFirstChild("RaceHorse") then
			Adapter.setMoveModifier(humanoid, "Horse", hcfg.RideSpeed or 2.8)
			character:SetAttribute("Riding", "Ride")
		end
	end
	if r.Place == 1 then
		winnerAt = now()
	end
	broadcast("Finished", { Name = r.Name, UserId = r.UserId, Place = r.Place, Time = r.Time, Prize = prize, Part = partName, Jockey = r.Jockey })
end

local function standings()
	local list = {}
	for _, r in pairs(racers) do
		local character = charOf(r)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local gate = course.Gates[r.Next]
		local dist = (root and gate) and (Vector3.new(gate.X, 0, gate.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude or 1e6
		table.insert(list, { Name = r.Name, UserId = r.UserId, Next = r.Next, Place = r.Place, Dist = dist, Jockey = r.Jockey })
	end
	table.sort(list, function(a, b)
		if a.Place or b.Place then
			return (a.Place or 1e6) < (b.Place or 1e6)
		end
		if a.Next ~= b.Next then
			return a.Next > b.Next
		end
		return a.Dist < b.Dist
	end)
	local rows = {}
	for i, e in ipairs(list) do
		table.insert(rows, { Name = e.Name, UserId = e.UserId, Position = i, Next = e.Next, Finished = e.Place ~= nil, Dist = math.floor(e.Dist), Jockey = e.Jockey })
	end
	return rows
end

local lastStandings = 0
local function tick()
	local t = now()
	if not phase then
		if t >= nextEntryAt then
			openEntry()
		end
		return
	end
	if phase == "Entry" then
		if t >= entryEnds then
			startRace()
		end
		return
	end
	if phase ~= "Racing" then
		return
	end
	local total = #course.Gates
	local activePlayers = 0
	for key, r in pairs(racers) do
		if not r.Finished then
			local character = charOf(r)
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local gate = course.Gates[r.Next]
			if root and gate then
				if r.Player then
					activePlayers = activePlayers + 1
				end
				local d = (Vector3.new(gate.X, 0, gate.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
				if d <= (cfg.PassRadius or 20) and math.abs(root.Position.Y - gate.Y) < 40 then
					r.Next = r.Next + 1
					if r.Next > total then
						finish(r)
					elseif r.Player then
						send(r.Player, "Gate", { Index = r.Next - 1, Total = total })
					end
				end
			end
		end
	end
	if t - lastStandings >= 0.5 then
		lastStandings = t
		local list = standings()
		for _, r in pairs(racers) do
			if r.Player then
				send(r.Player, "Standings", { List = list, Total = total, Elapsed = t - raceStart })
			end
		end
	end
	-- Ends when no player is still racing, FinishGrace after the winner, or at the time limit.
	if activePlayers == 0 then
		endRace(#finishOrder > 0 and "Everyone's crossed the line." or "Nobody finished.")
	elseif winnerAt and t - winnerAt >= (cfg.FinishGrace or 25) then
		endRace("Time's up for the stragglers.")
	elseif t - raceStart >= (cfg.TimeLimit or 240) then
		endRace("Time's up.")
	end
end

function RaceService.init()
	if cfg.Enabled == false and hcfg.Enabled == false then
		return
	end
	Remote = Net.get("Race")
	Remote.OnServerEvent:Connect(function(player, action)
		if action == "Join" then
			RaceService.join(player)
		elseif action == "Leave" then
			RaceService.leave(player)
		elseif action == "Horse" then
			RaceService.toggleHorse(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		racers[player] = nil
	end)
	-- Going down (or resetting) puts you out of the race; the horse goes with the body.
	local function watchDeath(player, character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				local r = racers[player]
				if r and phase ~= "Entry" and not r.Finished then
					out(player, "You went down: out of the race.")
				end
			end)
		end
	end
	local function hook(player)
		player.CharacterAdded:Connect(function(c)
			task.spawn(watchDeath, player, c)
		end)
		if player.Character then
			task.spawn(watchDeath, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	if cfg.Enabled == false then
		return -- horses only, no races
	end
	local first = RunService:IsStudio() and (cfg.StudioFirstAfter or 20) or (cfg.FirstAfter or 120)
	nextEntryAt = now() + first
	setAttr("SpinRaceNext", nextEntryAt)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc >= 0.1 then
			acc = 0
			tick()
		end
	end)
end

-- For tests / admin: open entry right now.
function RaceService.openNow()
	if not phase then
		openEntry()
	end
end

return RaceService
end
end
