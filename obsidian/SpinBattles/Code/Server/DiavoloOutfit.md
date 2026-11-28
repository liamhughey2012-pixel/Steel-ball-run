---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# DiavoloOutfit

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `DiavoloOutfit` (capitals matter) |

**What it does:** Gives a character the look of Diavolo (Part 5) while they play him (TuskAct 32), built from blocky parts (no catalog asset ids), matched to his art: long PINK hair with dark spots, parted in the middle, falling past his shoulders in front and down his back bare skin under a black WEB-MESH top: rings round the chest, arcs across the ribs and stomach, a line down the middle; dark swirling tattoos on his upper arms green wristbands, a green belt with a gold buckle purple trousers with a row of gold buttons down each outer seam and split hems; purple boots the black strap with white rungs hanging from his left hip The player's own hats/hair are hidden while they play him and come back when they switch. Built on the server so every player sees it.

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **DiavoloOutfit**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	DiavoloOutfit  (ServerScriptService.SpinServer.DiavoloOutfit)

	Gives a character the look of Diavolo (Part 5) while they play him
	(TuskAct 32), built from blocky parts (no catalog asset ids), matched to
	his art:
	  * long PINK hair with dark spots, parted in the middle, falling past
	    his shoulders in front and down his back
	  * bare skin under a black WEB-MESH top: rings round the chest, arcs
	    across the ribs and stomach, a line down the middle; dark swirling
	    tattoos on his upper arms
	  * green wristbands, a green belt with a gold buckle
	  * purple trousers with a row of gold buttons down each outer seam and
	    split hems; purple boots
	  * the black strap with white rungs hanging from his left hip
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local DiavoloOutfit = {}
DiavoloOutfit.Act = 32

local C = {
	Hair = Color3.fromRGB(240, 132, 172),
	HairShade = Color3.fromRGB(206, 100, 146),
	Spot = Color3.fromRGB(44, 62, 46),
	Skin = Color3.fromRGB(232, 196, 166),
	Mesh = Color3.fromRGB(26, 22, 30),
	Band = Color3.fromRGB(60, 172, 140),
	Belt = Color3.fromRGB(70, 160, 110),
	Gold = Color3.fromRGB(230, 186, 70),
	Pants = Color3.fromRGB(132, 92, 192),
	PantsShade = Color3.fromRGB(100, 66, 156),
	Boot = Color3.fromRGB(96, 66, 156),
	Rung = Color3.fromRGB(236, 236, 240),
	Eye = Color3.fromRGB(110, 170, 120),
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

local function ball(parent, outfit, name, d, color, offset)
	local p = piece(parent, outfit, name, Vector3.new(d, d, d), color, offset)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A thin dark mesh strand from a to b, lying on a face of `parent`.
local function strand(parent, outfit, a, b, z)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local angle = math.atan2(b.Y - a.Y, b.X - a.X)
	piece(parent, outfit, "Mesh", Vector3.new(len + 0.03, 0.04, 0.02), C.Mesh, CFrame.new(mid.X, mid.Y, z) * CFrame.Angles(0, 0, angle))
end

-- A ring of strands (an octagon) centred at (x, y) on a face.
local function meshRing(parent, outfit, x, y, r, z)
	local n = 8
	for k = 0, n - 1 do
		local a0, a1 = k / n * math.pi * 2, (k + 1) / n * math.pi * 2
		strand(parent, outfit, Vector3.new(x + math.cos(a0) * r, y + math.sin(a0) * r * 0.85, 0), Vector3.new(x + math.cos(a1) * r, y + math.sin(a1) * r * 0.85, 0), z)
	end
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Pink hair parted in the middle, smooth over the top.
	piece(head, outfit, "HairCap", Vector3.new(head.Size.X + 0.1 * s, 0.28 * s, head.Size.Z + 0.12 * s), C.Hair, CFrame.new(0, h + 0.08 * s, 0.03 * s))
	piece(head, outfit, "Parting", Vector3.new(0.04 * s, 0.05 * s, head.Size.Z * 0.8), C.HairShade, CFrame.new(0, h + 0.23 * s, -0.05 * s))
	for _, side in ipairs({ -1, 1 }) do
		-- Curtains of hair down each side of his face, onto his chest.
		piece(head, outfit, "HairSide", Vector3.new(0.16 * s, 1.0 * s, head.Size.Z * 0.9), C.Hair, CFrame.new(side * (w + 0.06 * s), -0.15 * s, 0.05 * s))
		piece(head, outfit, "FrontLock", Vector3.new(0.3 * s, 1.5 * s, 0.14 * s), side < 0 and C.Hair or C.HairShade, CFrame.new(side * (w - 0.02 * s), -1.0 * s, -d + 0.02 * s) * CFrame.Angles(math.rad(-8), 0, side * 0.08))
		piece(head, outfit, "Bang", Vector3.new(0.34 * s, 0.32 * s, 0.1 * s), C.Hair, CFrame.new(side * 0.26 * s, h - 0.1 * s, -d - 0.03 * s) * CFrame.Angles(0, 0, side * 0.35))
		-- Sharp brows, green eyes.
		piece(head, outfit, "Brow", Vector3.new(0.26 * s, 0.05 * s, 0.03 * s), C.Mesh, CFrame.new(side * 0.21 * s, 0.17 * s, -d - 0.01 * s) * CFrame.Angles(0, 0, side * -0.25))
		piece(head, outfit, "Eye", Vector3.new(0.18 * s, 0.07 * s, 0.03 * s), C.Eye, CFrame.new(side * 0.21 * s, 0.07 * s, -d - 0.01 * s))
	end
	-- The long mass down his back.
	piece(head, outfit, "HairBack", Vector3.new(head.Size.X + 0.3 * s, 2.6 * s, 0.22 * s), C.Hair, CFrame.new(0, -0.8 * s, d + 0.1 * s))
	piece(head, outfit, "HairBackShade", Vector3.new(head.Size.X * 0.5, 2.4 * s, 0.24 * s), C.HairShade, CFrame.new(0.15 * s, -0.9 * s, d + 0.11 * s))
	-- Dark spots all through it.
	for _, sp in ipairs({ { -0.4, 0.3 }, { 0.3, -0.2 }, { -0.1, -0.9 }, { 0.35, -1.4 }, { -0.35, -1.8 } }) do
		ball(head, outfit, "HairSpot", 0.13 * s, C.Spot, CFrame.new(sp[1] * s, sp[2] * s, d + 0.22 * s))
	end
	for _, sp in ipairs({ { 0.2, 0.2 }, { -0.25, -0.1 } }) do
		ball(head, outfit, "HairSpot", 0.12 * s, C.Spot, CFrame.new(sp[1] * s, h + 0.2 * s, sp[2] * s))
	end
	for _, side in ipairs({ -1, 1 }) do
		ball(head, outfit, "HairSpot", 0.11 * s, C.Spot, CFrame.new(side * (w + 0.13 * s), -0.4 * s, 0.1 * s))
		ball(head, outfit, "HairSpot", 0.1 * s, C.Spot, CFrame.new(side * (w - 0.02 * s), -1.2 * s, -d - 0.06 * s))
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local hx, hy = s.X / 2, s.Y / 2
		local zf, zb = -s.Z / 2 - 0.05, s.Z / 2 + 0.05
		piece(upper, outfit, "Skin", s + Vector3.new(0.06, 0.02, 0.06), C.Skin, CFrame.new())
		-- The web mesh: rings round the chest, arcs across, a centre line.
		for _, z in ipairs({ zf, zb }) do
			strand(upper, outfit, Vector3.new(0, hy, 0), Vector3.new(0, -hy, 0), z)
			for k = 0, 3 do
				local y = hy * 0.55 - k * s.Y * 0.24
				local sag = 0.1 + k * 0.02
				strand(upper, outfit, Vector3.new(-hx, y, 0), Vector3.new(-hx * 0.45, y - sag, 0), z)
				strand(upper, outfit, Vector3.new(-hx * 0.45, y - sag, 0), Vector3.new(0, y - sag * 1.3, 0), z)
				strand(upper, outfit, Vector3.new(0, y - sag * 1.3, 0), Vector3.new(hx * 0.45, y - sag, 0), z)
				strand(upper, outfit, Vector3.new(hx * 0.45, y - sag, 0), Vector3.new(hx, y, 0), z)
			end
		end
		for _, side in ipairs({ -1, 1 }) do
			meshRing(upper, outfit, side * hx * 0.5, hy * 0.35, s.X * 0.18, zf - 0.005)
			strand(upper, outfit, Vector3.new(side * hx * 0.5, hy, 0), Vector3.new(side * hx * 0.5, hy * 0.35 + s.X * 0.15, 0), zf - 0.005)
			strand(upper, outfit, Vector3.new(side * hx * 0.25, -hy * 0.2, 0), Vector3.new(side * hx * 0.3, -hy, 0), zf - 0.005)
		end
	end
	if lower then
		local ls = lower.Size
		piece(lower, outfit, "Trousers", ls + Vector3.new(0.08, 0.02, 0.08), C.Pants, CFrame.new())
		piece(lower, outfit, "Belt", Vector3.new(ls.X + 0.12, 0.2, ls.Z + 0.12), C.Belt, CFrame.new(0, ls.Y / 2 - 0.06, 0))
		piece(lower, outfit, "Buckle", Vector3.new(0.24, 0.16, 0.06), C.Gold, CFrame.new(0, ls.Y / 2 - 0.06, -ls.Z / 2 - 0.08), Enum.Material.Metal)
		-- The black strap with white rungs hanging off his left hip, round behind his leg.
		local strapTop = CFrame.new(-ls.X / 2 - 0.08, 0, 0.1)
		for k = 0, 7 do
			local cf = strapTop * CFrame.new(-0.02 * k, -0.25 - k * 0.32, 0.06 * k) * CFrame.Angles(math.rad(-6 - k * 2), 0, math.rad(-4))
			piece(lower, outfit, "Strap", Vector3.new(0.06, 0.34, 0.26), C.Mesh, cf)
			piece(lower, outfit, "Rung", Vector3.new(0.07, 0.05, 0.27), C.Rung, cf * CFrame.new(0, 0.1, 0))
		end
	end
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			piece(arm, outfit, "Skin", as + Vector3.new(0.04, 0.01, 0.04), C.Skin, CFrame.new())
			if name:find("Upper") or name == "Left Arm" or name == "Right Arm" then
				-- Dark swirling tattoos on the outside of the arm.
				local side = name:find("Left") and -1 or 1
				local x = side * (as.X / 2 + 0.03)
				for k = 0, 2 do
					piece(arm, outfit, "Tattoo", Vector3.new(0.02, 0.06, as.Z * (0.7 - k * 0.15)), C.Mesh, CFrame.new(x, as.Y * 0.3 - k * as.Y * 0.18, 0) * CFrame.Angles(math.rad(25 - k * 20), 0, 0))
				end
				piece(arm, outfit, "TattooCurl", Vector3.new(0.02, as.Y * 0.35, 0.06), C.Mesh, CFrame.new(x, -as.Y * 0.1, as.Z * 0.25) * CFrame.Angles(math.rad(15), 0, 0))
			end
			if name:find("Lower") or name == "Left Arm" or name == "Right Arm" then
				piece(arm, outfit, "Wristband", Vector3.new(as.X + 0.14, 0.3, as.Z + 0.14), C.Band, CFrame.new(0, -as.Y / 2 + 0.2, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local lsz = leg.Size
			piece(leg, outfit, "Trousers", lsz + Vector3.new(0.1, 0.02, 0.1), C.Pants, CFrame.new())
			-- A row of gold buttons down the outer seam.
			local side = name:find("Left") and -1 or 1
			for k = 0, 2 do
				ball(leg, outfit, "Button", 0.12, C.Gold, CFrame.new(side * (lsz.X / 2 + 0.06), lsz.Y * 0.3 - k * lsz.Y * 0.3, 0))
			end
			if name:find("Lower") or name == "Left Leg" or name == "Right Leg" then
				-- The split hem.
				piece(leg, outfit, "Split", Vector3.new(0.04, lsz.Y * 0.35, 0.04), C.PantsShade, CFrame.new(0, -lsz.Y * 0.33, -lsz.Z / 2 - 0.06))
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Boot", foot.Size + Vector3.new(0.08, 0.06, 0.2), C.Boot, CFrame.new(0, 0, -0.06))
		end
	end
end

function DiavoloOutfit.apply(character)
	if character:FindFirstChild("DiavoloOutfit") then
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
	outfit.Name = "DiavoloOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function DiavoloOutfit.remove(character)
	local outfit = character:FindFirstChild("DiavoloOutfit")
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
		if character:GetAttribute("TuskAct") == DiavoloOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == DiavoloOutfit.Act then
					DiavoloOutfit.apply(character)
				end
			end)
		else
			DiavoloOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function DiavoloOutfit.init()
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

return DiavoloOutfit
```
