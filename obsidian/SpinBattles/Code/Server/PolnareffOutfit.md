---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# PolnareffOutfit

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `PolnareffOutfit` (capitals matter) |

**What it does:** Gives a character the look of Jean Pierre Polnareff (Part 3) while they play him (TuskAct 23), built from blocky parts (no catalog asset ids): his famous HAIR: silver-white, standing straight up in a tall column with a flat top; short at the sides half-heart ("broken heart") earrings a black sleeveless top with a high neck; bare, muscular arms high-waisted cream trousers with a dark belt; dark boots The player's own hats/hair are hidden while they play him and come back when they switch. Built on the server so every player sees it.

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **PolnareffOutfit**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	PolnareffOutfit  (ServerScriptService.SpinServer.PolnareffOutfit)

	Gives a character the look of Jean Pierre Polnareff (Part 3) while they
	play him (TuskAct 23), built from blocky parts (no catalog asset ids):
	  * his famous HAIR: silver-white, standing straight up in a tall column
	    with a flat top; short at the sides
	  * half-heart ("broken heart") earrings
	  * a black sleeveless top with a high neck; bare, muscular arms
	  * high-waisted cream trousers with a dark belt; dark boots
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local PolnareffOutfit = {}
PolnareffOutfit.Act = 23

local C = {
	Hair = Color3.fromRGB(232, 234, 240),
	HairShade = Color3.fromRGB(196, 200, 212),
	Earring = Color3.fromRGB(236, 196, 210),
	Top = Color3.fromRGB(30, 32, 44),
	TopShade = Color3.fromRGB(50, 54, 70),
	Pants = Color3.fromRGB(228, 222, 202),
	PantsShade = Color3.fromRGB(196, 188, 164),
	Belt = Color3.fromRGB(60, 44, 34),
	Buckle = Color3.fromRGB(200, 200, 210),
	Boot = Color3.fromRGB(56, 42, 34),
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

-- A flat disc facing forward (-Z).
local function disc(parent, outfit, name, d, depth, color, offset)
	local p = piece(parent, outfit, name, Vector3.new(depth, d, d), color, offset * CFrame.Angles(0, math.pi / 2, 0))
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Short at the sides and back...
	piece(head, outfit, "HairBase", Vector3.new(head.Size.X + 0.08 * s, 0.3 * s, head.Size.Z + 0.08 * s), C.Hair, CFrame.new(0, h - 0.1 * s, 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Side", Vector3.new(0.08 * s, 0.4 * s, head.Size.Z * 0.7), C.HairShade, CFrame.new(side * (w + 0.03 * s), h - 0.35 * s, 0.08 * s))
	end
	-- ...and standing straight up in a tall column with a flat top.
	local tall = 1.5 * s
	local tiers = 4
	for k = 0, tiers - 1 do
		local f = k / tiers
		local h0 = tall / tiers
		piece(head, outfit, "HairColumn", Vector3.new(head.Size.X * (0.86 - f * 0.14), h0 + 0.02 * s, head.Size.Z * (0.74 - f * 0.12)), k % 2 == 0 and C.Hair or Color3.fromRGB(240, 242, 248), CFrame.new(0, h + h0 * (k + 0.5), 0.05 * s + f * 0.06 * s))
	end
	piece(head, outfit, "HairTop", Vector3.new(head.Size.X * 0.7, 0.1 * s, head.Size.Z * 0.6), Color3.new(1, 1, 1), CFrame.new(0, h + tall, 0.1 * s))
	for k = -1, 1 do
		piece(head, outfit, "HairStreak", Vector3.new(0.04 * s, tall * 0.85, 0.05 * s), C.HairShade, CFrame.new(k * 0.2 * s, h + tall / 2, -head.Size.Z * 0.33 + 0.05 * s) * CFrame.Angles(math.rad(-3), 0, 0))
	end
	-- Half-heart earrings.
	for _, side in ipairs({ -1, 1 }) do
		local lobe = piece(head, outfit, "Earring", Vector3.new(0.05 * s, 0.16 * s, 0.16 * s), C.Earring, CFrame.new(side * (w + 0.05 * s), -0.2 * s, 0.02 * s))
		lobe.Shape = Enum.PartType.Cylinder
		piece(head, outfit, "EarringPoint", Vector3.new(0.05 * s, 0.12 * s, 0.12 * s), C.Earring, CFrame.new(side * (w + 0.05 * s), -0.3 * s, 0.05 * s) * CFrame.Angles(math.pi / 4, 0, 0))
	end
	-- Strong brows.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Brow", Vector3.new(0.28 * s, 0.06 * s, 0.05 * s), C.HairShade, CFrame.new(side * 0.22 * s, 0.14 * s, -d - 0.02 * s) * CFrame.Angles(0, 0, side * 0.1))
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	local head = character:FindFirstChild("Head")
	local skin = head and head.Color or Color3.fromRGB(236, 200, 170)
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Top", s + Vector3.new(0.06, 0.02, 0.06), C.Top, CFrame.new())
		piece(upper, outfit, "HighNeck", Vector3.new(0.7, 0.3, 0.66), C.Top, CFrame.new(0, top + 0.12, 0))
		-- Sleeveless: bare shoulders where the arm holes are.
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Shoulder", Vector3.new(0.42, 0.5, s.Z + 0.08), skin, CFrame.new(side * (s.X / 2 - 0.18), top - 0.24, 0))
			piece(upper, outfit, "Strap", Vector3.new(0.22, 0.52, s.Z + 0.1), C.Top, CFrame.new(side * (s.X / 2 - 0.48), top - 0.23, 0))
		end
		piece(upper, outfit, "PecLine", Vector3.new(s.X * 0.5, 0.04, 0.04), C.TopShade, CFrame.new(0, 0.12, front - 0.04))
		piece(upper, outfit, "AbLine", Vector3.new(0.04, 0.7, 0.04), C.TopShade, CFrame.new(0, -0.35, front - 0.04))
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.06, 0.24, 0.06), C.Pants, CFrame.new(0, 0.1, 0))
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.16, 0.16, ls.Z + 0.16), C.Belt, CFrame.new(0, ls.Y / 2 + 0.12, 0))
		piece(lower, outfit, "Buckle", Vector3.new(0.26, 0.18, 0.06), C.Buckle, CFrame.new(0, ls.Y / 2 + 0.12, -ls.Z / 2 - 0.1))
	end
	-- Bare arms.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Skin", arm.Size + Vector3.new(0.04, 0, 0.04), skin, CFrame.new())
		end
	end
	-- Cream trousers, dark boots.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Trousers", ls + Vector3.new(0.06, 0.02, 0.06), C.Pants, CFrame.new())
			piece(leg, outfit, "Crease", Vector3.new(0.04, ls.Y * 0.9, 0.04), C.PantsShade, CFrame.new(0, 0, -ls.Z / 2 - 0.04))
			if name:find("Lower") then
				piece(leg, outfit, "Boot", Vector3.new(ls.X + 0.1, ls.Y * 0.45, ls.Z + 0.1), C.Boot, CFrame.new(0, -ls.Y * 0.28, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Boot", foot.Size + Vector3.new(0.08, 0.04, 0.14), C.Boot, CFrame.new(0, 0, -0.04))
		end
	end
end

function PolnareffOutfit.apply(character)
	if character:FindFirstChild("PolnareffOutfit") then
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
	outfit.Name = "PolnareffOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function PolnareffOutfit.remove(character)
	local outfit = character:FindFirstChild("PolnareffOutfit")
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
		if (character:GetAttribute("TuskAct") == PolnareffOutfit.Act or character:GetAttribute("TuskAct") == 24) then
			task.delay(0.3, function()
				if character.Parent and (character:GetAttribute("TuskAct") == PolnareffOutfit.Act or character:GetAttribute("TuskAct") == 24) then
					PolnareffOutfit.apply(character)
				end
			end)
		else
			PolnareffOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function PolnareffOutfit.init()
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

return PolnareffOutfit
```
