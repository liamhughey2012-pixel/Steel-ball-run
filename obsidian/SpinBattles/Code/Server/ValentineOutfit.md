---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# ValentineOutfit

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `ValentineOutfit` (capitals matter) |

**What it does:** Gives a character Funny Valentine's look while they play him (TuskAct 13), built from blocky parts (no catalog asset ids). Built from the character's description until there's reference art: curly blond hair with big curls sticking out at the sides a long pale presidential frock coat with gold trim, gold buttons and tails, a gold star pin a white ruffled cravat (jabot) at the throat navy trousers and black riding boots The player's own hats/hair are hidden while they play him and come back when they switch. Built on the server so every player sees it.

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **ValentineOutfit**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	ValentineOutfit  (ServerScriptService.SpinServer.ValentineOutfit)

	Gives a character Funny Valentine's look while they play him (TuskAct
	13), built from blocky parts (no catalog asset ids). Built from the
	character's description until there's reference art:
	  * curly blond hair with big curls sticking out at the sides
	  * a long pale presidential frock coat with gold trim, gold buttons and
	    tails, a gold star pin
	  * a white ruffled cravat (jabot) at the throat
	  * navy trousers and black riding boots
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local ValentineOutfit = {}
ValentineOutfit.Act = 13

local C = {
	Hair = Color3.fromRGB(244, 218, 120),
	HairDark = Color3.fromRGB(214, 182, 86),
	Coat = Color3.fromRGB(232, 226, 236),
	CoatShade = Color3.fromRGB(200, 192, 210),
	Gold = Color3.fromRGB(222, 178, 70),
	Jabot = Color3.fromRGB(250, 250, 248),
	Pants = Color3.fromRGB(44, 50, 84),
	Boot = Color3.fromRGB(22, 20, 24),
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
	-- Curly blond hair: a volume on top, down the back, and big curls out at the sides.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.2 * s, 0.4 * s, head.Size.Z + 0.2 * s), C.Hair, CFrame.new(0, h, 0.02 * s))
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.24 * s, 0.9 * s, 0.24 * s), C.Hair, CFrame.new(0, -0.1 * s, d + 0.1 * s))
	piece(head, outfit, "Bangs", Vector3.new(head.Size.X * 0.9, 0.2 * s, 0.14 * s), C.HairDark, CFrame.new(0, h - 0.22 * s, -d - 0.04 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.16 * s, 0.8 * s, head.Size.Z * 0.8), C.Hair, CFrame.new(side * (w + 0.07 * s), 0.02 * s, 0.08 * s))
		-- Ringlet curls sticking out sideways (stacked, spiralling).
		for k = 0, 2 do
			piece(head, outfit, "Curl", Vector3.new((0.34 - k * 0.06) * s, (0.34 - k * 0.06) * s, (0.34 - k * 0.06) * s), k % 2 == 0 and C.Hair or C.HairDark,
				CFrame.new(side * (w + (0.25 + k * 0.22) * s), (0.25 + k * 0.12) * s, (0.05 - k * 0.05) * s) * CFrame.Angles(0, 0, side * k * 0.5))
		end
		piece(head, outfit, "Curl", Vector3.new(0.3 * s, 0.3 * s, 0.3 * s), C.HairDark, CFrame.new(side * (w + 0.18 * s), -0.42 * s, 0.1 * s))
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Coat", s + Vector3.new(0.1, 0.02, 0.1), C.Coat, CFrame.new())
		-- High collar and the white ruffled cravat.
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.7, 0.4, s.Z + 0.24), C.CoatShade, CFrame.new(0, top + 0.12, 0.04))
		for k = 0, 3 do
			piece(upper, outfit, "Jabot", Vector3.new(0.6 - k * 0.08, 0.2, 0.12), C.Jabot, CFrame.new(0, top - 0.08 - k * 0.18, front - 0.08 - (k % 2) * 0.04) * CFrame.Angles(0, 0, (k % 2 == 0 and 0.12 or -0.12)))
		end
		-- Lapels edged in gold, gold buttons down the front, a gold star pin.
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Lapel", Vector3.new(0.36, s.Y * 0.6, 0.06), C.CoatShade, CFrame.new(side * 0.42, top - s.Y * 0.3, front - 0.06) * CFrame.Angles(0, 0, side * 0.25))
			piece(upper, outfit, "LapelTrim", Vector3.new(0.06, s.Y * 0.6, 0.07), C.Gold, CFrame.new(side * 0.6, top - s.Y * 0.3, front - 0.07) * CFrame.Angles(0, 0, side * 0.25))
			for k = 0, 2 do
				piece(upper, outfit, "Button", Vector3.new(0.12, 0.12, 0.05), C.Gold, CFrame.new(side * 0.2, -s.Y * 0.05 - k * 0.3, front - 0.07))
			end
		end
		for _, a in ipairs({ 0, math.pi / 4 }) do
			piece(upper, outfit, "StarPin", Vector3.new(0.26, 0.08, 0.04), C.Gold, CFrame.new(-0.55, top - 0.75, front - 0.1) * CFrame.Angles(0, 0, a))
			piece(upper, outfit, "StarPin", Vector3.new(0.08, 0.26, 0.04), C.Gold, CFrame.new(-0.55, top - 0.75, front - 0.1) * CFrame.Angles(0, 0, a))
		end
		piece(upper, outfit, "Hem", Vector3.new(s.X + 0.14, 0.1, s.Z + 0.14), C.Gold, CFrame.new(0, -s.Y / 2 + 0.05, 0))
	end
	-- Frock-coat skirt and tails.
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.3
		local skirtH = lower and 1.7 or 1.4
		for _, side in ipairs({ -1, 1 }) do
			piece(waist, outfit, "Skirt", Vector3.new(ws.X / 2 + 0.06, skirtH, 0.12), C.Coat, CFrame.new(side * (ws.X / 4 + 0.1), waistTop - skirtH / 2, -ws.Z / 2 - 0.08) * CFrame.Angles(0, side * 0.12, 0))
			piece(waist, outfit, "SkirtTrim", Vector3.new(0.07, skirtH, 0.13), C.Gold, CFrame.new(side * 0.14, waistTop - skirtH / 2, -ws.Z / 2 - 0.1))
			piece(waist, outfit, "Skirt", Vector3.new(0.12, skirtH, ws.Z + 0.16), C.CoatShade, CFrame.new(side * (ws.X / 2 + 0.1), waistTop - skirtH / 2, 0.02))
		end
		piece(waist, outfit, "Tails", Vector3.new(ws.X + 0.3, skirtH + 0.4, 0.12), C.Coat, CFrame.new(0, waistTop - skirtH / 2 - 0.2, ws.Z / 2 + 0.08))
		if lower then
			piece(lower, outfit, "Pants", ws + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
		end
	end
	-- Sleeves with gold cuffs.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local tall = as.Y > 1.8
			local h = tall and as.Y - 0.3 or as.Y
			piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.08, h + 0.02, as.Z + 0.08), C.Coat, CFrame.new(0, as.Y / 2 - h / 2, 0))
			if name:find("Lower") or tall then
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.14, 0.22, as.Z + 0.14), C.Gold, CFrame.new(0, as.Y / 2 - h + 0.11, 0))
				piece(arm, outfit, "Ruffle", Vector3.new(as.X + 0.04, 0.14, as.Z + 0.04), C.Jabot, CFrame.new(0, as.Y / 2 - h - 0.04, 0))
			end
		end
	end
	-- Navy trousers and black riding boots.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Pants", ls + Vector3.new(0.05, 0.02, 0.05), C.Pants, CFrame.new())
			if name:find("Lower") or ls.Y > 1.8 then
				local bh = ls.Y > 1.8 and 1.0 or ls.Y + 0.05
				piece(leg, outfit, "Boot", Vector3.new(ls.X + 0.14, bh, ls.Z + 0.14), C.Boot, CFrame.new(0, -ls.Y / 2 + bh / 2, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Boot", foot.Size + Vector3.new(0.1, 0.06, 0.14), C.Boot, CFrame.new(0, 0, -0.03))
		end
	end
end

function ValentineOutfit.apply(character)
	if character:FindFirstChild("ValentineOutfit") then
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
	outfit.Name = "ValentineOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function ValentineOutfit.remove(character)
	local outfit = character:FindFirstChild("ValentineOutfit")
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
		if character:GetAttribute("TuskAct") == ValentineOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == ValentineOutfit.Act then
					ValentineOutfit.apply(character)
				end
			end)
		else
			ValentineOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function ValentineOutfit.init()
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

return ValentineOutfit
```
