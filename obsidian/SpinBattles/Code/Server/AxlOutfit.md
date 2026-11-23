---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# AxlOutfit

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `AxlOutfit` (capitals matter) |

**What it does:** Gives a character Axl RO's look while they play him (TuskAct 12), built from blocky parts (no catalog asset ids). A stand-in look until there's reference art: long dark hair tied back, a dark headband a grey Civil War-style long coat with a high collar, two rows of brass buttons, shoulder boards and coat tails, a red sash dark trousers and tall black boots The player's own hats/hair are hidden while they play him and come back when they switch. Built on the server so every player sees it.

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **AxlOutfit**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	AxlOutfit  (ServerScriptService.SpinServer.AxlOutfit)

	Gives a character Axl RO's look while they play him (TuskAct 12), built
	from blocky parts (no catalog asset ids). A stand-in look until there's
	reference art:
	  * long dark hair tied back, a dark headband
	  * a grey Civil War-style long coat with a high collar, two rows of
	    brass buttons, shoulder boards and coat tails, a red sash
	  * dark trousers and tall black boots
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local AxlOutfit = {}
AxlOutfit.Act = 12

local C = {
	Hair = Color3.fromRGB(46, 34, 28),
	Band = Color3.fromRGB(60, 22, 26),
	Coat = Color3.fromRGB(116, 120, 130),
	CoatDark = Color3.fromRGB(84, 88, 98),
	Brass = Color3.fromRGB(214, 176, 80),
	Sash = Color3.fromRGB(170, 40, 46),
	Pants = Color3.fromRGB(46, 42, 50),
	Boot = Color3.fromRGB(26, 24, 26),
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
	-- Long dark hair over the top and sides, tied back in a tail.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.14 * s, 0.3 * s, head.Size.Z + 0.14 * s), C.Hair, CFrame.new(0, h - 0.06 * s, 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.12 * s, 0.9 * s, head.Size.Z * 0.7), C.Hair, CFrame.new(side * (w + 0.05 * s), -0.02 * s, 0.14 * s))
	end
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.14 * s, 1.0 * s, 0.14 * s), C.Hair, CFrame.new(0, -0.05 * s, d + 0.06 * s))
	piece(head, outfit, "Bangs", Vector3.new(head.Size.X * 0.8, 0.16 * s, 0.1 * s), C.Hair, CFrame.new(0.1 * s, h - 0.24 * s, -d - 0.03 * s) * CFrame.Angles(0, 0, -0.15))
	for i = 0, 3 do
		piece(head, outfit, "Tail", Vector3.new((0.32 - i * 0.04) * s, 0.4 * s, 0.24 * s), C.Hair, CFrame.new(0, -0.4 * s - i * 0.36 * s, d + 0.16 * s))
	end
	piece(head, outfit, "Headband", Vector3.new(head.Size.X + 0.18 * s, 0.12 * s, head.Size.Z + 0.18 * s), C.Band, CFrame.new(0, h - 0.26 * s, 0.02 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Coat", s + Vector3.new(0.1, 0.02, 0.1), C.Coat, CFrame.new())
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.62, 0.36, s.Z + 0.24), C.CoatDark, CFrame.new(0, top + 0.12, 0))
		-- Two rows of brass buttons.
		for row = 0, 4 do
			for _, side in ipairs({ -1, 1 }) do
				piece(upper, outfit, "Button", Vector3.new(0.12, 0.12, 0.05), C.Brass, CFrame.new(side * 0.28, top - 0.25 - row * 0.28, front - 0.07))
			end
		end
		-- Shoulder boards and a red sash across the chest.
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Board", Vector3.new(0.6, 0.1, s.Z + 0.16), C.CoatDark, CFrame.new(side * (s.X / 2 - 0.3), top + 0.03, 0))
			piece(upper, outfit, "Board", Vector3.new(0.5, 0.06, 0.06), C.Brass, CFrame.new(side * (s.X / 2 - 0.3), top + 0.09, front - 0.04))
		end
		piece(upper, outfit, "Sash", Vector3.new(0.3, s.Y * 1.15, 0.05), C.Sash, CFrame.new(0, 0, front - 0.06) * CFrame.Angles(0, 0, 0.6))
	end
	-- Coat skirt and tails, red waist sash.
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.3
		piece(waist, outfit, "SashBelt", Vector3.new(ws.X + 0.16, 0.26, ws.Z + 0.16), C.Sash, CFrame.new(0, waistTop - 0.14, 0))
		local skirtH = lower and 1.6 or 1.3
		for _, side in ipairs({ -1, 1 }) do
			piece(waist, outfit, "Skirt", Vector3.new(ws.X / 2 + 0.06, skirtH, 0.12), C.Coat, CFrame.new(side * (ws.X / 4 + 0.08), waistTop - skirtH / 2, -ws.Z / 2 - 0.08) * CFrame.Angles(0, side * 0.1, 0))
			piece(waist, outfit, "Skirt", Vector3.new(0.12, skirtH, ws.Z + 0.16), C.CoatDark, CFrame.new(side * (ws.X / 2 + 0.1), waistTop - skirtH / 2, 0.02))
		end
		piece(waist, outfit, "Skirt", Vector3.new(ws.X + 0.3, skirtH + 0.2, 0.12), C.Coat, CFrame.new(0, waistTop - skirtH / 2 - 0.1, ws.Z / 2 + 0.08))
	end
	-- Sleeves with brass cuffs.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local tall = as.Y > 1.8
			local h = tall and as.Y - 0.3 or as.Y
			piece(arm, outfit, "Sleeve", Vector3.new(as.X + 0.08, h + 0.02, as.Z + 0.08), C.Coat, CFrame.new(0, as.Y / 2 - h / 2, 0))
			if name:find("Lower") or tall then
				piece(arm, outfit, "Cuff", Vector3.new(as.X + 0.14, 0.24, as.Z + 0.14), C.CoatDark, CFrame.new(0, as.Y / 2 - h + 0.12, 0))
				piece(arm, outfit, "CuffButton", Vector3.new(0.1, 0.1, 0.05), C.Brass, CFrame.new(0, as.Y / 2 - h + 0.12, -as.Z / 2 - 0.09))
			end
		end
	end
	-- Dark trousers and tall boots.
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

function AxlOutfit.apply(character)
	if character:FindFirstChild("AxlOutfit") then
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
	outfit.Name = "AxlOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function AxlOutfit.remove(character)
	local outfit = character:FindFirstChild("AxlOutfit")
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
		if character:GetAttribute("TuskAct") == AxlOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == AxlOutfit.Act then
					AxlOutfit.apply(character)
				end
			end)
		else
			AxlOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function AxlOutfit.init()
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

return AxlOutfit
```
