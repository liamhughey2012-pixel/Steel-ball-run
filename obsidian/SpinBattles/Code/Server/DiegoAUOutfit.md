---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# DiegoAUOutfit

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `DiegoAUOutfit` (capitals matter) |

**What it does:** Gives a character the look of Diego Brando from another world while they play him (TuskAct 14), built from blocky parts (no catalog asset ids), matched to his art: a teal jockey cap with a dark brim and "DIO" on the front blond hair to the jaw, a long lock falling over one eye a teal turtleneck sweater, quilted in a dark diamond lattice, with a thick rolled neck brown leather gloves with cuffs khaki riding trousers with a dark belt and buckle tall dark-brown riding boots with silver spurs The player's own hats/hair are hidden while they play him and come back when they switch. Built on the server so every player sees it.

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **DiegoAUOutfit**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	DiegoAUOutfit  (ServerScriptService.SpinServer.DiegoAUOutfit)

	Gives a character the look of Diego Brando from another world while
	they play him (TuskAct 14), built from blocky parts (no catalog asset
	ids), matched to his art:
	  * a teal jockey cap with a dark brim and "DIO" on the front
	  * blond hair to the jaw, a long lock falling over one eye
	  * a teal turtleneck sweater, quilted in a dark diamond lattice, with a
	    thick rolled neck
	  * brown leather gloves with cuffs
	  * khaki riding trousers with a dark belt and buckle
	  * tall dark-brown riding boots with silver spurs
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local DiegoAUOutfit = {}
DiegoAUOutfit.Act = 14

local C = {
	Hair = Color3.fromRGB(236, 206, 120),
	HairDark = Color3.fromRGB(196, 160, 80),
	Cap = Color3.fromRGB(96, 184, 176),
	CapDark = Color3.fromRGB(40, 104, 104),
	Sweater = Color3.fromRGB(112, 204, 188),
	SweaterShade = Color3.fromRGB(84, 170, 158),
	Lattice = Color3.fromRGB(36, 96, 92),
	Glove = Color3.fromRGB(128, 80, 44),
	GloveDark = Color3.fromRGB(92, 56, 30),
	Pants = Color3.fromRGB(198, 172, 112),
	PantsShade = Color3.fromRGB(168, 142, 88),
	Belt = Color3.fromRGB(70, 46, 30),
	Buckle = Color3.fromRGB(200, 196, 180),
	Boot = Color3.fromRGB(78, 52, 36),
	BootDark = Color3.fromRGB(52, 34, 24),
	Spur = Color3.fromRGB(200, 204, 212),
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

-- The dark diamond lattice of the quilted sweater on one flat face (w x h,
-- centred on cf): two sets of diagonal lines, each clipped to the face.
local function lattice(part, outfit, w, h, cf)
	local step = 0.6
	local hw, hh = w / 2, h / 2
	local n = math.ceil((w + h) / step)
	for i = -n, n do
		local c = i * step
		-- x - y = c (rising lines) and x + y = c (falling lines).
		for _, rising in ipairs({ true, false }) do
			local x0, x1
			if rising then
				x0, x1 = math.max(-hw, c - hh), math.min(hw, c + hh)
			else
				x0, x1 = math.max(-hw, c - hh), math.min(hw, c + hh)
			end
			if x1 - x0 > 0.08 then
				local x = (x0 + x1) / 2
				local y = rising and (x - c) or (c - x)
				local len = (x1 - x0) * math.sqrt(2)
				piece(part, outfit, "Lattice", Vector3.new(0.05, len, 0.03), C.Lattice, cf * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, rising and -0.785 or 0.785))
			end
		end
	end
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Blond hair: over the ears down to the jaw, longer at the back, a lock over one eye.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.16 * s, 0.3 * s, head.Size.Z + 0.16 * s), C.Hair, CFrame.new(0, h - 0.1 * s, 0.02 * s))
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.24 * s, 1.0 * s, 0.24 * s), C.Hair, CFrame.new(0, -0.15 * s, d + 0.08 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.18 * s, 1.0 * s, head.Size.Z * 0.9), C.Hair, CFrame.new(side * (w + 0.06 * s), -0.12 * s, 0.05 * s))
		piece(head, outfit, "HairTip", Vector3.new(0.16 * s, 0.3 * s, 0.3 * s), C.HairDark, CFrame.new(side * (w + 0.1 * s), -0.66 * s, 0.25 * s) * CFrame.Angles(0, 0, side * 0.3))
	end
	-- The lock over his left eye.
	piece(head, outfit, "Lock", Vector3.new(0.34 * s, 0.85 * s, 0.1 * s), C.Hair, CFrame.new(-0.2 * s, 0.05 * s, -d - 0.04 * s) * CFrame.Angles(0, 0, -0.25))
	piece(head, outfit, "LockShade", Vector3.new(0.1 * s, 0.7 * s, 0.11 * s), C.HairDark, CFrame.new(-0.08 * s, 0.02 * s, -d - 0.05 * s) * CFrame.Angles(0, 0, -0.25))
	-- Teal jockey cap: a rounded crown, a dark band and a short brim.
	piece(head, outfit, "Cap", Vector3.new(head.Size.X + 0.2 * s, 0.5 * s, head.Size.Z + 0.2 * s), C.Cap, CFrame.new(0, h + 0.12 * s, 0.02 * s))
	piece(head, outfit, "CapTop", Vector3.new(head.Size.X * 0.8, 0.16 * s, head.Size.Z * 0.8), C.Cap, CFrame.new(0, h + 0.42 * s, 0.04 * s))
	piece(head, outfit, "CapBand", Vector3.new(head.Size.X + 0.24 * s, 0.1 * s, head.Size.Z + 0.24 * s), C.CapDark, CFrame.new(0, h - 0.1 * s, 0.02 * s))
	piece(head, outfit, "Brim", Vector3.new(head.Size.X + 0.1 * s, 0.08 * s, 0.5 * s), C.CapDark, CFrame.new(0, h - 0.12 * s, -d - 0.22 * s) * CFrame.Angles(-0.12, 0, 0))
	-- "DIO" on the front of the cap.
	local plate = piece(head, outfit, "CapPlate", Vector3.new(head.Size.X * 0.9, 0.36 * s, 0.04), C.Cap, CFrame.new(0, h + 0.14 * s, -d - 0.12 * s))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.6
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bodoni
	label.TextScaled = true
	label.Text = "DIO"
	label.TextColor3 = C.Lattice
	label.TextStrokeColor3 = Color3.fromRGB(220, 250, 245)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = plate
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Sweater", s + Vector3.new(0.1, 0.02, 0.1), C.Sweater, CFrame.new())
		lattice(upper, outfit, s.X, s.Y, CFrame.new(0, 0, front - 0.06))
		lattice(upper, outfit, s.X, s.Y, CFrame.new(0, 0, -front + 0.06))
		-- Thick rolled turtleneck.
		piece(upper, outfit, "Turtleneck", Vector3.new(s.X * 0.55, 0.5, s.Z * 0.85), C.SweaterShade, CFrame.new(0, top + 0.2, 0))
		piece(upper, outfit, "NeckRoll", Vector3.new(s.X * 0.6, 0.16, s.Z * 0.9), C.Sweater, CFrame.new(0, top + 0.34, 0))
	end
	-- Khaki trousers with a dark belt and a buckle.
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.3
		if lower then
			piece(lower, outfit, "Pants", ws + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
		else
			piece(upper, outfit, "SweaterHem", Vector3.new(upper.Size.X + 0.12, 0.2, upper.Size.Z + 0.12), C.SweaterShade, CFrame.new(0, waistTop + 0.1, 0))
		end
		piece(waist, outfit, "Belt", Vector3.new(ws.X + 0.1, 0.18, ws.Z + 0.1), C.Belt, CFrame.new(0, waistTop - 0.12, 0))
		piece(waist, outfit, "Buckle", Vector3.new(0.34, 0.22, 0.06), C.Buckle, CFrame.new(0, waistTop - 0.12, -ws.Z / 2 - 0.08))
	end
	-- Quilted sleeves with a ribbed cuff.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local tall = as.Y > 1.8
			local h = tall and as.Y - 0.3 or as.Y
			piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.1, h + 0.02, as.Z + 0.1), C.Sweater, CFrame.new(0, as.Y / 2 - h / 2, 0))
			local side = name:find("Left") and -1 or 1
			local cy = as.Y / 2 - h / 2
			lattice(arm, outfit, as.X, h, CFrame.new(0, cy, -as.Z / 2 - 0.07))
			lattice(arm, outfit, as.Z, h, CFrame.new(side * (as.X / 2 + 0.07), cy, 0) * CFrame.Angles(0, math.pi / 2, 0))
			if name:find("Lower") or tall then
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.16, 0.22, as.Z + 0.16), C.SweaterShade, CFrame.new(0, as.Y / 2 - h + 0.08, 0))
			end
		end
	end
	-- Brown leather gloves (R15 hands; on R6 the bottom of the arm).
	for _, name in ipairs({ "LeftHand", "RightHand" }) do
		local hand = character:FindFirstChild(name)
		if hand then
			piece(hand, outfit, "Glove", hand.Size + Vector3.new(0.08, 0.06, 0.08), C.Glove, CFrame.new())
			piece(hand, outfit, "GloveCuff", Vector3.new(hand.Size.X + 0.16, 0.16, hand.Size.Z + 0.16), C.GloveDark, CFrame.new(0, hand.Size.Y / 2, 0))
		end
	end
	for _, name in ipairs({ "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Glove", Vector3.new(arm.Size.X + 0.12, 0.32, arm.Size.Z + 0.12), C.Glove, CFrame.new(0, -arm.Size.Y / 2 + 0.15, 0))
		end
	end
	-- Khaki trousers into tall riding boots with spurs.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Pants", ls + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
			piece(leg, outfit, "Crease", Vector3.new(0.05, ls.Y * 0.8, 0.05), C.PantsShade, CFrame.new(0, 0, -ls.Z / 2 - 0.04))
			if name:find("Lower") or ls.Y > 1.8 then
				local bh = ls.Y > 1.8 and 1.2 or ls.Y + 0.05
				piece(leg, outfit, "Boot", Vector3.new(ls.X + 0.14, bh, ls.Z + 0.14), C.Boot, CFrame.new(0, -ls.Y / 2 + bh / 2, 0))
				piece(leg, outfit, "BootTop", Vector3.new(ls.X + 0.2, 0.16, ls.Z + 0.2), C.BootDark, CFrame.new(0, -ls.Y / 2 + bh, 0))
				if ls.Y > 1.8 then
					piece(leg, outfit, "Spur", Vector3.new(0.08, 0.08, 0.36), C.Spur, CFrame.new(0, -ls.Y / 2 + 0.25, ls.Z / 2 + 0.2))
					piece(leg, outfit, "SpurWheel", Vector3.new(0.06, 0.2, 0.2), C.Spur, CFrame.new(0, -ls.Y / 2 + 0.25, ls.Z / 2 + 0.4))
				end
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			local fs = foot.Size
			piece(foot, outfit, "Boot", fs + Vector3.new(0.1, 0.06, 0.14), C.BootDark, CFrame.new(0, 0, -0.03))
			piece(foot, outfit, "Spur", Vector3.new(0.08, 0.08, 0.34), C.Spur, CFrame.new(0, 0, fs.Z / 2 + 0.16))
			piece(foot, outfit, "SpurWheel", Vector3.new(0.06, 0.2, 0.2), C.Spur, CFrame.new(0, 0, fs.Z / 2 + 0.36))
		end
	end
end

function DiegoAUOutfit.apply(character)
	if character:FindFirstChild("DiegoAUOutfit") then
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
	outfit.Name = "DiegoAUOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function DiegoAUOutfit.remove(character)
	local outfit = character:FindFirstChild("DiegoAUOutfit")
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
		if character:GetAttribute("TuskAct") == DiegoAUOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == DiegoAUOutfit.Act then
					DiegoAUOutfit.apply(character)
				end
			end)
		else
			DiegoAUOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function DiegoAUOutfit.init()
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

return DiegoAUOutfit
```
