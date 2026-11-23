---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# MountainTimOutfit

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `MountainTimOutfit` (capitals matter) |

**What it does:** Gives a character Mountain Tim's cowboy look while they play him (TuskAct 9), built from blocky parts (no catalog asset ids), matched to his art: a zebra-striped cowboy hat with a band of gold conchos, a cow skull on the front and hat cords hanging down to his chest shoulder-length blond hair, sideburns and a chin beard a leopard-print jacket (fur collar and sleeves) over a pale grey shirt with big lapels, an open neck and fringed chest pockets a brown belt with bullet loops, a round gold "MT" buckle and a holster with a revolver on his right hip dark grey gloves with studs, grey trousers, dark boots The player's own hats/hair are hidden while they play him and come back when they switch. Built on the server so every player sees it.

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **MountainTimOutfit**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	MountainTimOutfit  (ServerScriptService.SpinServer.MountainTimOutfit)

	Gives a character Mountain Tim's cowboy look while they play him (TuskAct 9),
	built from blocky parts (no catalog asset ids), matched to his art:
	  * a zebra-striped cowboy hat with a band of gold conchos, a cow skull
	    on the front and hat cords hanging down to his chest
	  * shoulder-length blond hair, sideburns and a chin beard
	  * a leopard-print jacket (fur collar and sleeves) over a pale grey
	    shirt with big lapels, an open neck and fringed chest pockets
	  * a brown belt with bullet loops, a round gold "MT" buckle and a
	    holster with a revolver on his right hip
	  * dark grey gloves with studs, grey trousers, dark boots
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local MountainTimOutfit = {}
MountainTimOutfit.Act = 9

local C = {
	Hat = Color3.fromRGB(228, 226, 218),
	Stripe = Color3.fromRGB(40, 38, 40),
	Concho = Color3.fromRGB(214, 164, 64),
	Skull = Color3.fromRGB(236, 232, 220),
	Cord = Color3.fromRGB(70, 56, 40),
	Hair = Color3.fromRGB(232, 206, 120),
	HairDark = Color3.fromRGB(196, 168, 90),
	Leopard = Color3.fromRGB(214, 172, 92),
	Spot = Color3.fromRGB(60, 40, 22),
	Shirt = Color3.fromRGB(200, 200, 196),
	ShirtDark = Color3.fromRGB(160, 160, 156),
	Fringe = Color3.fromRGB(220, 200, 150),
	Belt = Color3.fromRGB(150, 84, 46),
	Bullet = Color3.fromRGB(222, 190, 90),
	Buckle = Color3.fromRGB(226, 180, 60),
	BuckleDark = Color3.fromRGB(150, 110, 30),
	Gun = Color3.fromRGB(120, 124, 132),
	Glove = Color3.fromRGB(70, 66, 78),
	Pants = Color3.fromRGB(110, 112, 120),
	Boot = Color3.fromRGB(52, 40, 32),
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

-- Dark leopard spots scattered over one face of a part (deterministic).
local function spots(part, outfit, w, h, faceCF, count, seed)
	for i = 1, count do
		local u = ((i * 37 + seed * 13) % 100) / 100 - 0.5
		local v = ((i * 61 + seed * 29) % 100) / 100 - 0.5
		local big = i % 3 == 0
		piece(part, outfit, "Spot", Vector3.new(big and 0.2 or 0.13, big and 0.14 or 0.1, 0.03), C.Spot, faceCF * CFrame.new(u * w * 0.85, v * h * 0.85, 0) * CFrame.Angles(0, 0, (i % 4) * 0.4))
	end
end

-- Leopard print on every side of a box laid over `part`.
local function leopard(part, outfit, size, cf, seed)
	piece(part, outfit, "Leopard", size, C.Leopard, cf)
	local x, y, z = size.X / 2 + 0.015, size.Y, size.Z / 2 + 0.015
	spots(part, outfit, size.X, y, cf * CFrame.new(0, 0, -z), 4, seed)
	spots(part, outfit, size.X, y, cf * CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi, 0), 4, seed + 1)
	spots(part, outfit, size.Z, y, cf * CFrame.new(x, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), 3, seed + 2)
	spots(part, outfit, size.Z, y, cf * CFrame.new(-x, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), 3, seed + 3)
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Shoulder-length blond hair, sideburns and a chin beard.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.14 * s, 0.9 * s, 0.22 * s), C.Hair, CFrame.new(0, -0.15 * s, d + 0.08 * s))
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.24 * s, 0.35 * s, 0.3 * s), C.HairDark, CFrame.new(0, -0.62 * s, d + 0.1 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.14 * s, 0.85 * s, head.Size.Z * 0.6), C.Hair, CFrame.new(side * (w + 0.05 * s), -0.1 * s, 0.18 * s))
		piece(head, outfit, "Sideburn", Vector3.new(0.06 * s, 0.4 * s, 0.14 * s), C.HairDark, CFrame.new(side * (w + 0.02 * s), -0.1 * s, -d + 0.2 * s))
	end
	piece(head, outfit, "Beard", Vector3.new(0.22 * s, 0.14 * s, 0.06 * s), C.HairDark, CFrame.new(0, -h + 0.08 * s, -d - 0.02 * s))
	-- Zebra cowboy hat: wide brim curled up at the sides, a pinched crown.
	local brimY = h - 0.02 * s
	piece(head, outfit, "Brim", Vector3.new(head.Size.X + 1.1 * s, 0.08 * s, head.Size.Z + 1.0 * s), C.Hat, CFrame.new(0, brimY, 0))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "BrimCurl", Vector3.new(0.3 * s, 0.08 * s, head.Size.Z + 0.9 * s), C.Hat, CFrame.new(side * (w + 0.62 * s), brimY + 0.1 * s, 0) * CFrame.Angles(0, 0, side * 0.7))
	end
	local crownH = 0.62 * s
	piece(head, outfit, "Crown", Vector3.new(head.Size.X + 0.06 * s, crownH, head.Size.Z + 0.06 * s), C.Hat, CFrame.new(0, brimY + crownH / 2, 0))
	piece(head, outfit, "Crown", Vector3.new(head.Size.X * 0.7, 0.12 * s, head.Size.Z * 0.9), C.Hat, CFrame.new(0, brimY + crownH + 0.04 * s, 0))
	-- Black stripes round the crown and across the brim.
	for i = 0, 2 do
		piece(head, outfit, "Stripe", Vector3.new(head.Size.X + 0.1 * s, 0.06 * s, head.Size.Z + 0.1 * s), C.Stripe, CFrame.new(0, brimY + 0.28 * s + i * 0.14 * s, 0) * CFrame.Angles(0, 0, (i % 2 == 0 and 0.08 or -0.08)))
	end
	for i = -2, 2 do
		piece(head, outfit, "Stripe", Vector3.new(0.08 * s, 0.09 * s, head.Size.Z + 0.96 * s), C.Stripe, CFrame.new(i * 0.34 * s, brimY, 0) * CFrame.Angles(0, 0.35, 0))
	end
	-- Band of gold conchos round the crown and a cow skull on the front.
	local bandY = brimY + 0.12 * s
	for i = -2, 2 do
		piece(head, outfit, "Concho", Vector3.new(0.16 * s, 0.16 * s, 0.06 * s), C.Concho, CFrame.new(i * 0.24 * s, bandY, -d - 0.06 * s))
	end
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 1 do
			piece(head, outfit, "Concho", Vector3.new(0.06 * s, 0.16 * s, 0.16 * s), C.Concho, CFrame.new(side * (w + 0.06 * s), bandY, -0.2 * s + i * 0.4 * s))
		end
	end
	piece(head, outfit, "Skull", Vector3.new(0.24 * s, 0.26 * s, 0.08 * s), C.Skull, CFrame.new(0.32 * s, bandY + 0.18 * s, -d - 0.1 * s))
	piece(head, outfit, "Skull", Vector3.new(0.46 * s, 0.07 * s, 0.06 * s), C.Skull, CFrame.new(0.32 * s, bandY + 0.3 * s, -d - 0.1 * s))
	-- Hat cords hanging down to the chest.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Cord", Vector3.new(0.04 * s, 1.0 * s, 0.04 * s), C.Cord, CFrame.new(side * (w - 0.05 * s), -0.3 * s, -d - 0.1 * s) * CFrame.Angles(0, 0, side * -0.18))
	end
end

local function body(character, outfit)
	local headPart = character:FindFirstChild("Head")
	local skin = headPart and headPart.Color or Color3.fromRGB(230, 190, 150)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		-- Pale grey shirt, open at the neck.
		piece(upper, outfit, "Shirt", s + Vector3.new(0.08, 0.02, 0.08), C.Shirt, CFrame.new())
		piece(upper, outfit, "Chest", Vector3.new(0.5, 0.6, 0.04), skin, CFrame.new(0, top - 0.32, front - 0.05))
		piece(upper, outfit, "Placket", Vector3.new(0.08, s.Y * 0.55, 0.04), C.ShirtDark, CFrame.new(0, -s.Y * 0.2, front - 0.05))
		-- Big lapels.
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Lapel", Vector3.new(0.4, 0.7, 0.06), C.Shirt, CFrame.new(side * 0.42, top - 0.3, front - 0.09) * CFrame.Angles(0, 0, side * 0.35))
			-- Fringed chest pocket.
			piece(upper, outfit, "Pocket", Vector3.new(0.46, 0.1, 0.05), C.ShirtDark, CFrame.new(side * 0.55, top - 0.68, front - 0.07))
			for k = -2, 2 do
				piece(upper, outfit, "Fringe", Vector3.new(0.05, 0.36, 0.04), C.Fringe, CFrame.new(side * 0.55 + k * 0.09, top - 0.9, front - 0.08))
			end
		end
		-- Leopard fur collar across the shoulders and up the back of the neck.
		leopard(upper, outfit, Vector3.new(s.X + 0.2, 0.3, s.Z + 0.24), CFrame.new(0, top - 0.08, 0.02), 1)
		leopard(upper, outfit, Vector3.new(s.X * 0.7, 0.4, 0.2), CFrame.new(0, top + 0.12, -front + 0.08), 5)
	end
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local beltY = lower and ws.Y / 2 - 0.12 or -upper.Size.Y / 2 + 0.15
		if lower then
			piece(lower, outfit, "Pants", ws + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
		end
		-- Belt with bullet loops, the round MT buckle, a holster on his right hip.
		piece(waist, outfit, "Belt", Vector3.new(ws.X + 0.14, 0.24, ws.Z + 0.14), C.Belt, CFrame.new(0, beltY, 0))
		for i = 1, 4 do
			piece(waist, outfit, "Bullet", Vector3.new(0.07, 0.2, 0.06), C.Bullet, CFrame.new(-0.35 - i * 0.12, beltY + 0.02, -ws.Z / 2 - 0.09))
		end
		piece(waist, outfit, "Buckle", Vector3.new(0.42, 0.34, 0.06), C.Buckle, CFrame.new(0, beltY, -ws.Z / 2 - 0.1))
		piece(waist, outfit, "Buckle", Vector3.new(0.34, 0.42, 0.06), C.Buckle, CFrame.new(0, beltY, -ws.Z / 2 - 0.1))
		piece(waist, outfit, "BuckleMT", Vector3.new(0.06, 0.24, 0.04), C.BuckleDark, CFrame.new(-0.06, beltY, -ws.Z / 2 - 0.14))
		piece(waist, outfit, "BuckleMT", Vector3.new(0.2, 0.05, 0.04), C.BuckleDark, CFrame.new(0, beltY + 0.1, -ws.Z / 2 - 0.14))
		piece(waist, outfit, "BuckleMT", Vector3.new(0.05, 0.22, 0.04), C.BuckleDark, CFrame.new(0.07, beltY - 0.01, -ws.Z / 2 - 0.14))
		local hip = CFrame.new(ws.X / 2 + 0.2, beltY - 0.42, -0.1)
		piece(waist, outfit, "Holster", Vector3.new(0.24, 0.72, 0.4), C.Belt, hip)
		piece(waist, outfit, "GunGrip", Vector3.new(0.16, 0.36, 0.2), C.Gun, hip * CFrame.new(0, 0.5, 0.06) * CFrame.Angles(-0.3, 0, 0))
		piece(waist, outfit, "GunHammer", Vector3.new(0.14, 0.12, 0.26), C.Gun, hip * CFrame.new(0, 0.38, -0.08))
	end
	-- Leopard jacket sleeves, dark studded gloves.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local tall = as.Y > 1.8
			local h = tall and as.Y - 0.4 or as.Y
			leopard(arm, outfit, Vector3.new(as.X + 0.12, h + 0.02, as.Z + 0.12), CFrame.new(0, as.Y / 2 - h / 2, 0), #name)
			if tall then
				piece(arm, outfit, "Glove", Vector3.new(as.X + 0.1, 0.42, as.Z + 0.1), C.Glove, CFrame.new(0, -as.Y / 2 + 0.2, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftHand", "RightHand" }) do
		local hand = character:FindFirstChild(name)
		if hand then
			piece(hand, outfit, "Glove", hand.Size + Vector3.new(0.08, 0.06, 0.08), C.Glove, CFrame.new())
			piece(hand, outfit, "Stud", Vector3.new(0.1, 0.1, 0.06), C.Buckle, CFrame.new(0, 0, -hand.Size.Z / 2 - 0.06))
		end
	end
	-- Grey trousers and dark boots.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Pants", ls + Vector3.new(0.05, 0.02, 0.05), C.Pants, CFrame.new())
			if name:find("Lower") or ls.Y > 1.8 then
				local bh = ls.Y > 1.8 and 0.8 or ls.Y * 0.7
				piece(leg, outfit, "Boot", Vector3.new(ls.X + 0.14, bh, ls.Z + 0.14), C.Boot, CFrame.new(0, -ls.Y / 2 + bh / 2, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Boot", foot.Size + Vector3.new(0.1, 0.06, 0.16), C.Boot, CFrame.new(0, 0, -0.04))
		end
	end
end

function MountainTimOutfit.apply(character)
	if character:FindFirstChild("MountainTimOutfit") then
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
	outfit.Name = "MountainTimOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function MountainTimOutfit.remove(character)
	local outfit = character:FindFirstChild("MountainTimOutfit")
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
		if character:GetAttribute("TuskAct") == MountainTimOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == MountainTimOutfit.Act then
					MountainTimOutfit.apply(character)
				end
			end)
		else
			MountainTimOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function MountainTimOutfit.init()
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

return MountainTimOutfit
```
