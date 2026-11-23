--[[
	HotPantsOutfit  (ServerScriptService.SpinServer.HotPantsOutfit)

	Gives a character Hot Pants' look while they play her (TuskAct 10),
	built from blocky parts (no catalog asset ids), matched to her art:
	  * a pink-purple bob with bangs
	  * a black cap with a gold front plate, gold visor, rivets and a gold
	    spike on top
	  * a thick cream scarf wrapped round her neck
	  * a pink tunic dress with a shoulder capelet, gold four-petal flower
	    clasps, gold leaf studs, a darker pink round panel on the front and a
	    black fur hem
	  * a gold chain belt with square links, a round "HP" buckle and a
	    holster on her hip
	  * cream ribbed sleeves and leggings
	  * tall pink flared boots with pointed cream toes
	  * (CREAM STARTER, her Stand, is drawn in her hand by the client)
	The player's own hats/hair are hidden while they play her and come back
	when she switches. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local HotPantsOutfit = {}
HotPantsOutfit.Act = 10

local C = {
	Hair = Color3.fromRGB(206, 112, 188),
	HairDark = Color3.fromRGB(160, 80, 150),
	Cap = Color3.fromRGB(28, 26, 30),
	Gold = Color3.fromRGB(226, 182, 64),
	GoldDark = Color3.fromRGB(170, 128, 40),
	Scarf = Color3.fromRGB(236, 228, 208),
	ScarfLine = Color3.fromRGB(196, 186, 164),
	Dress = Color3.fromRGB(226, 96, 150),
	DressDark = Color3.fromRGB(184, 64, 120),
	Fur = Color3.fromRGB(26, 24, 28),
	Rib = Color3.fromRGB(232, 224, 202),
	RibLine = Color3.fromRGB(196, 188, 166),
	Boot = Color3.fromRGB(232, 108, 160),
	BootDark = Color3.fromRGB(190, 78, 128),
	Toe = Color3.fromRGB(238, 232, 214),
	Holster = Color3.fromRGB(120, 82, 46),
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

-- A four-petal gold flower clasp facing forward (-Z of `cf`).
local function flower(parent, outfit, cf, size)
	for _, a in ipairs({ math.pi / 4, -math.pi / 4 }) do
		piece(parent, outfit, "Flower", Vector3.new(size, size * 0.38, 0.06), C.Gold, cf * CFrame.Angles(0, 0, a))
	end
	piece(parent, outfit, "Flower", Vector3.new(size * 0.3, size * 0.3, 0.08), C.GoldDark, cf * CFrame.new(0, 0, -0.02))
end

-- A cream ribbed tube over a limb from `top` down to `bottom` (local Y).
local function ribbed(part, outfit, top, bottom, grow)
	local h = top - bottom
	local sz = part.Size
	piece(part, outfit, "Rib", Vector3.new(sz.X + grow, h, sz.Z + grow), C.Rib, CFrame.new(0, (top + bottom) / 2, 0))
	local y = top - 0.18
	while y > bottom + 0.08 do
		piece(part, outfit, "RibLine", Vector3.new(sz.X + grow + 0.03, 0.05, sz.Z + grow + 0.03), C.RibLine, CFrame.new(0, y, 0))
		y = y - 0.24
	end
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Pink-purple bob: sides down to the jaw, the back, and bangs under the cap.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.2 * s, 0.95 * s, head.Size.Z + 0.1 * s), C.Hair, CFrame.new(side * (w + 0.08 * s), -0.05 * s, 0.04 * s))
		piece(head, outfit, "Hair", Vector3.new(0.22 * s, 0.14 * s, head.Size.Z * 0.6), C.HairDark, CFrame.new(side * (w + 0.1 * s), -0.48 * s, 0.1 * s))
	end
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.36 * s, 1.0 * s, 0.2 * s), C.Hair, CFrame.new(0, -0.02 * s, d + 0.08 * s))
	piece(head, outfit, "Bangs", Vector3.new(head.Size.X * 0.9, 0.14 * s, 0.12 * s), C.Hair, CFrame.new(-0.08 * s, h - 0.3 * s, -d - 0.04 * s) * CFrame.Angles(0, 0, 0.12))
	-- Black cap...
	piece(head, outfit, "Cap", Vector3.new(head.Size.X + 0.24 * s, 0.42 * s, head.Size.Z + 0.24 * s), C.Cap, CFrame.new(0, h - 0.06 * s, 0.02 * s))
	piece(head, outfit, "CapTop", Vector3.new(head.Size.X * 0.82, 0.18 * s, head.Size.Z * 0.82), C.Cap, CFrame.new(0, h + 0.22 * s, 0.04 * s))
	-- ...with a gold front plate, rivets, visor and a spike on top.
	piece(head, outfit, "Plate", Vector3.new(head.Size.X * 0.7, 0.3 * s, 0.1 * s), C.Gold, CFrame.new(0, h + 0.04 * s, -d - 0.13 * s) * CFrame.Angles(0.12, 0, 0))
	for i = -1, 1 do
		piece(head, outfit, "Rivet", Vector3.new(0.08 * s, 0.08 * s, 0.06 * s), C.GoldDark, CFrame.new(i * 0.3 * s, h + 0.08 * s, -d - 0.2 * s))
	end
	piece(head, outfit, "Visor", Vector3.new(head.Size.X * 0.95, 0.08 * s, 0.5 * s), C.Gold, CFrame.new(0, h - 0.24 * s, -d - 0.36 * s) * CFrame.Angles(-0.2, 0, 0))
	piece(head, outfit, "Spike", Vector3.new(0.14 * s, 0.3 * s, 0.14 * s), C.Gold, CFrame.new(0, h + 0.44 * s, 0.04 * s))
	piece(head, outfit, "Spike", Vector3.new(0.1 * s, 0.1 * s, 0.22 * s), C.Gold, CFrame.new(0, h + 0.6 * s, 0.1 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		-- Tunic.
		piece(upper, outfit, "Dress", s + Vector3.new(0.1, 0.02, 0.1), C.Dress, CFrame.new())
		-- Capelet over the shoulders (drapes a little lower at the front).
		piece(upper, outfit, "Capelet", Vector3.new(s.X + 0.5, 0.42, s.Z + 0.4), C.Dress, CFrame.new(0, top - 0.18, 0))
		piece(upper, outfit, "Capelet", Vector3.new(s.X + 0.36, 0.3, 0.12), C.DressDark, CFrame.new(0, top - 0.48, front - 0.16))
		-- Thick cream scarf wrapped round the neck.
		piece(upper, outfit, "Scarf", Vector3.new(s.X * 0.62, 0.24, s.Z + 0.24), C.Scarf, CFrame.new(0, top + 0.06, 0))
		piece(upper, outfit, "Scarf", Vector3.new(s.X * 0.52, 0.14, s.Z + 0.14), C.Scarf, CFrame.new(0, top + 0.22, 0))
		piece(upper, outfit, "ScarfLine", Vector3.new(s.X * 0.61, 0.04, s.Z + 0.23), C.ScarfLine, CFrame.new(0, top + 0.1, 0))
		piece(upper, outfit, "ScarfLine", Vector3.new(s.X * 0.51, 0.04, s.Z + 0.13), C.ScarfLine, CFrame.new(0, top + 0.24, 0))
		-- Gold four-petal flowers on each shoulder.
		for _, side in ipairs({ -1, 1 }) do
			flower(upper, outfit, CFrame.new(side * s.X * 0.33, top - 0.22, front - 0.3), 0.42)
		end
		-- Darker pink round panel on the front (blocky octagon).
		piece(upper, outfit, "Panel", Vector3.new(0.8, 0.55, 0.06), C.DressDark, CFrame.new(0, -s.Y * 0.18, front - 0.07))
		piece(upper, outfit, "Panel", Vector3.new(0.55, 0.8, 0.06), C.DressDark, CFrame.new(0, -s.Y * 0.18, front - 0.07))
		-- Gold leaf studs scattered on the dress.
		for _, spot in ipairs({ { -0.68, -0.05, 0.5 }, { 0.68, -0.05, -0.5 }, { -0.62, -0.5, -0.4 }, { 0.62, -0.5, 0.4 } }) do
			piece(upper, outfit, "Leaf", Vector3.new(0.2, 0.13, 0.06), C.Gold, CFrame.new(spot[1], spot[2] * s.Y / 1.6, front - 0.07) * CFrame.Angles(0, 0, spot[3]))
		end
	end
	-- Skirt with a black fur hem, gold chain belt, round HP buckle, holster.
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.3
		local skirtH = lower and 0.75 or 0.6
		local skirtY = waistTop - skirtH / 2
		piece(waist, outfit, "Skirt", Vector3.new(ws.X + 0.22, skirtH, ws.Z + 0.22), C.Dress, CFrame.new(0, skirtY, 0))
		piece(waist, outfit, "Fur", Vector3.new(ws.X + 0.4, 0.26, ws.Z + 0.4), C.Fur, CFrame.new(0, waistTop - skirtH - 0.04, 0)).Material = Enum.Material.Fabric
		local beltY = waistTop - 0.12
		piece(waist, outfit, "Belt", Vector3.new(ws.X + 0.28, 0.14, ws.Z + 0.28), C.GoldDark, CFrame.new(0, beltY, 0))
		for i = -2, 2 do
			if i ~= 0 then
				piece(waist, outfit, "Link", Vector3.new(0.26, 0.2, 0.05), C.Gold, CFrame.new(i * 0.4, beltY, -ws.Z / 2 - 0.16))
				piece(waist, outfit, "Link", Vector3.new(0.14, 0.09, 0.06), C.Dress, CFrame.new(i * 0.4, beltY, -ws.Z / 2 - 0.17))
			end
		end
		piece(waist, outfit, "Buckle", Vector3.new(0.4, 0.34, 0.06), C.Gold, CFrame.new(0, beltY, -ws.Z / 2 - 0.17))
		piece(waist, outfit, "Buckle", Vector3.new(0.3, 0.42, 0.06), C.Gold, CFrame.new(0, beltY, -ws.Z / 2 - 0.17))
		piece(waist, outfit, "BuckleHP", Vector3.new(0.18, 0.18, 0.07), C.GoldDark, CFrame.new(0, beltY, -ws.Z / 2 - 0.18))
		-- Holster hanging off her right hip.
		piece(waist, outfit, "Holster", Vector3.new(0.22, 0.7, 0.36), C.Holster, CFrame.new(ws.X / 2 + 0.2, beltY - 0.4, -0.1) * CFrame.Angles(0, 0, 0.1))
	end
	-- Cream ribbed sleeves.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local tall = arm.Size.Y > 1.8
			local bottom = tall and -arm.Size.Y / 2 + 0.35 or -arm.Size.Y / 2
			ribbed(arm, outfit, arm.Size.Y / 2, bottom, 0.06)
			if name:find("Upper") or tall then
				-- The capelet covers the top of the shoulder.
				piece(arm, outfit, "Shoulder", Vector3.new(arm.Size.X + 0.16, 0.36, arm.Size.Z + 0.16), C.Dress, CFrame.new(0, arm.Size.Y / 2 - 0.12, 0))
			end
		end
	end
	-- Cream ribbed leggings, then tall pink boots that flare at the top.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			ribbed(leg, outfit, leg.Size.Y / 2, -leg.Size.Y / 2, 0.04)
		end
	end
	for _, name in ipairs({ "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local tall = leg.Size.Y > 1.8
			if not tall then
				ribbed(leg, outfit, leg.Size.Y / 2, -leg.Size.Y / 2, 0.04)
			end
			local h = tall and 1.1 or leg.Size.Y + 0.1
			local bootTop = -leg.Size.Y / 2 + h
			piece(leg, outfit, "Boot", Vector3.new(leg.Size.X + 0.14, h, leg.Size.Z + 0.16), C.Boot, CFrame.new(0, bootTop - h / 2, 0))
			-- Flared cuff with a darker fold.
			piece(leg, outfit, "BootCuff", Vector3.new(leg.Size.X + 0.42, 0.34, leg.Size.Z + 0.42), C.Boot, CFrame.new(0, bootTop - 0.05, 0))
			piece(leg, outfit, "BootFold", Vector3.new(0.08, h * 0.6, 0.06), C.BootDark, CFrame.new(leg.Size.X * 0.25, bootTop - h * 0.4, -leg.Size.Z / 2 - 0.1))
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Boot", foot.Size + Vector3.new(0.12, 0.06, 0.1), C.Boot, CFrame.new())
			piece(foot, outfit, "Toe", Vector3.new(foot.Size.X * 0.7, foot.Size.Y * 0.8, 0.4), C.Toe, CFrame.new(0, -foot.Size.Y * 0.1, -foot.Size.Z / 2 - 0.15))
		end
	end
end

function HotPantsOutfit.apply(character)
	if character:FindFirstChild("HotPantsOutfit") then
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
	outfit.Name = "HotPantsOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function HotPantsOutfit.remove(character)
	local outfit = character:FindFirstChild("HotPantsOutfit")
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
		if character:GetAttribute("TuskAct") == HotPantsOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == HotPantsOutfit.Act then
					HotPantsOutfit.apply(character)
				end
			end)
		else
			HotPantsOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function HotPantsOutfit.init()
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

return HotPantsOutfit
