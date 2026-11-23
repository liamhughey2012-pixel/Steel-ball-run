---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# BlackmoreOutfit

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `BlackmoreOutfit` (capitals matter) |

**What it does:** Gives a character Blackmore's look while they play him (TuskAct 11), built from blocky parts (no catalog asset ids), matched to his art: a dark navy hood wrapped round the head and neck, a gold ring on top and a long blond ponytail sweeping up and back out of it his white mask with the diagonal rainbow stripe and black slits a navy capelet down to the elbows covered in gold grommets, two rows of grommets down the front a long navy coat skirt to the calves (split at the front) pale grey-blue sleeves and leggings with dark raindrop marks grey studded boots (his umbrella is drawn in his hand by the client) The player's own hats/hair are hidden while they play him and come back when they switch. Built on the server so every player sees it.

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **BlackmoreOutfit**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	BlackmoreOutfit  (ServerScriptService.SpinServer.BlackmoreOutfit)

	Gives a character Blackmore's look while they play him (TuskAct 11),
	built from blocky parts (no catalog asset ids), matched to his art:
	  * a dark navy hood wrapped round the head and neck, a gold ring on top
	    and a long blond ponytail sweeping up and back out of it
	  * his white mask with the diagonal rainbow stripe and black slits
	  * a navy capelet down to the elbows covered in gold grommets, two rows
	    of grommets down the front
	  * a long navy coat skirt to the calves (split at the front)
	  * pale grey-blue sleeves and leggings with dark raindrop marks
	  * grey studded boots
	  (his umbrella is drawn in his hand by the client)
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local BlackmoreOutfit = {}
BlackmoreOutfit.Act = 11

local C = {
	Hood = Color3.fromRGB(40, 40, 72),
	HoodDark = Color3.fromRGB(28, 28, 52),
	Ring = Color3.fromRGB(214, 172, 70),
	Hair = Color3.fromRGB(238, 222, 160),
	HairDark = Color3.fromRGB(206, 186, 120),
	Mask = Color3.fromRGB(236, 240, 244),
	Slit = Color3.fromRGB(20, 20, 24),
	Rainbow = { Color3.fromRGB(235, 80, 100), Color3.fromRGB(250, 220, 70), Color3.fromRGB(70, 190, 230) },
	Coat = Color3.fromRGB(46, 44, 82),
	CoatDark = Color3.fromRGB(32, 30, 60),
	Grommet = Color3.fromRGB(214, 172, 70),
	GrommetHole = Color3.fromRGB(24, 22, 40),
	Sleeve = Color3.fromRGB(190, 198, 214),
	Leg = Color3.fromRGB(200, 206, 220),
	Drop = Color3.fromRGB(60, 56, 96),
	Boot = Color3.fromRGB(150, 156, 170),
	Stud = Color3.fromRGB(225, 228, 236),
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

-- A gold grommet (ring with a dark hole) facing -Z of `cf`.
local function grommet(parent, outfit, cf)
	piece(parent, outfit, "Grommet", Vector3.new(0.17, 0.17, 0.05), C.Grommet, cf)
	piece(parent, outfit, "Grommet", Vector3.new(0.08, 0.08, 0.06), C.GrommetHole, cf * CFrame.new(0, 0, -0.01))
end

local function headPieces(head, outfit)
	local s = head.Size.Y / 1.2
	local w, h, d = head.Size.X / 2, head.Size.Y / 2, head.Size.Z / 2
	-- Hood: wraps the top, sides and back; the face stays open.
	piece(head, outfit, "Hood", Vector3.new(head.Size.X + 0.24 * s, 0.3 * s, head.Size.Z + 0.24 * s), C.Hood, CFrame.new(0, h + 0.04 * s, 0.02 * s))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hood", Vector3.new(0.14 * s, head.Size.Y + 0.1 * s, head.Size.Z + 0.2 * s), C.Hood, CFrame.new(side * (w + 0.06 * s), -0.04 * s, 0.03 * s))
	end
	piece(head, outfit, "Hood", Vector3.new(head.Size.X + 0.24 * s, head.Size.Y + 0.1 * s, 0.14 * s), C.Hood, CFrame.new(0, -0.04 * s, d + 0.06 * s))
	piece(head, outfit, "HoodRim", Vector3.new(head.Size.X + 0.26 * s, 0.12 * s, 0.1 * s), C.HoodDark, CFrame.new(0, h - 0.04 * s, -d - 0.04 * s))
	-- Gold ring on top with a long blond ponytail sweeping up and back.
	piece(head, outfit, "Ring", Vector3.new(0.34 * s, 0.12 * s, 0.34 * s), C.Ring, CFrame.new(0, h + 0.24 * s, 0.05 * s))
	-- The tail is a chain of blocks along a curve: up out of the ring, then back and down.
	local pts = {}
	for i = 0, 7 do
		local t = i / 7
		pts[i] = Vector3.new(0, h + 0.3 * s + math.sin(t * math.pi * 0.75) * 0.9 * s, 0.05 * s + t * t * 2.1 * s)
	end
	for i = 1, 7 do
		local a0, a1 = pts[i - 1], pts[i]
		local thick = (0.26 - i * 0.022) * s
		piece(head, outfit, "Ponytail", Vector3.new(thick, thick, (a1 - a0).Magnitude + 0.06 * s), i % 2 == 0 and C.HairDark or C.Hair, CFrame.lookAt((a0 + a1) / 2, a1))
	end
	-- White mask: rainbow stripe across it diagonally, black slits under the eyes.
	local fz = -d - 0.07 * s
	piece(head, outfit, "Mask", Vector3.new(head.Size.X * 0.92, head.Size.Y * 0.88, 0.08 * s), C.Mask, CFrame.new(0, -0.04 * s, fz))
	for i, color in ipairs(C.Rainbow) do
		piece(head, outfit, "MaskStripe", Vector3.new(head.Size.X * 0.95, 0.09 * s, 0.04 * s), color, CFrame.new(0, (0.02 - (i - 2) * 0.1) * s, fz - 0.05 * s) * CFrame.Angles(0, 0, 0.42))
	end
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "MaskEye", Vector3.new(0.26 * s, 0.06 * s, 0.04 * s), C.Slit, CFrame.new(side * 0.22 * s, 0.16 * s, fz - 0.05 * s) * CFrame.Angles(0, 0, side * -0.15))
	end
	for i = -1, 1 do
		piece(head, outfit, "MaskSlit", Vector3.new(0.05 * s, 0.3 * s, 0.04 * s), C.Slit, CFrame.new(i * 0.12 * s, -0.32 * s, fz - 0.05 * s))
	end
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		local top, front = s.Y / 2, -s.Z / 2
		piece(upper, outfit, "Coat", s + Vector3.new(0.1, 0.02, 0.1), C.Coat, CFrame.new())
		-- Hood wraps down round the neck like a cowl.
		piece(upper, outfit, "Cowl", Vector3.new(s.X * 0.62, 0.36, s.Z + 0.26), C.Hood, CFrame.new(0, top + 0.12, 0))
		-- Capelet over the shoulders (the arm parts are on the arms so they move with them).
		local capeH = s.Y * 0.72
		piece(upper, outfit, "Capelet", Vector3.new(s.X + 0.3, capeH, s.Z + 0.42), C.Coat, CFrame.new(0, top - capeH / 2 + 0.02, 0))
		piece(upper, outfit, "CapeHem", Vector3.new(s.X + 0.34, 0.08, s.Z + 0.46), C.CoatDark, CFrame.new(0, top - capeH, 0))
		-- Two rows of grommets down the front, and a few more beside them.
		for row = 0, 3 do
			for _, side in ipairs({ -1, 1 }) do
				grommet(upper, outfit, CFrame.new(side * 0.22, top - 0.25 - row * 0.3, front - 0.24))
			end
		end
		for _, spot in ipairs({ { -0.75, -0.35 }, { 0.75, -0.35 }, { -0.6, -0.8 }, { 0.6, -0.8 } }) do
			grommet(upper, outfit, CFrame.new(spot[1] * s.X / 2, top + spot[2] * s.Y / 1.6, front - 0.24))
		end
	end
	-- The capelet drapes over each upper arm, down to the elbow, with grommets.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local as = arm.Size
			local ch = as.Y > 1.8 and as.Y * 0.55 or as.Y
			local outward = name:find("Left") and -1 or 1
			piece(arm, outfit, "CapeArm", Vector3.new(as.X + 0.34, ch, as.Z + 0.42), C.Coat, CFrame.new(outward * 0.06, as.Y / 2 - ch / 2 + 0.04, 0))
			piece(arm, outfit, "CapeHem", Vector3.new(as.X + 0.38, 0.08, as.Z + 0.46), C.CoatDark, CFrame.new(outward * 0.06, as.Y / 2 - ch + 0.04, 0))
			for _, y in ipairs({ 0.3, 0.65 }) do
				grommet(arm, outfit, CFrame.new(outward * 0.1, as.Y / 2 - ch * y, -as.Z / 2 - 0.26))
			end
		end
	end
	-- Long coat skirt to the calves, split at the front.
	local waist = lower or upper
	if waist then
		local ws = waist.Size
		local waistTop = lower and ws.Y / 2 or -upper.Size.Y / 2 + 0.3
		local skirtH = lower and 1.85 or 1.6
		for _, side in ipairs({ -1, 1 }) do
			piece(waist, outfit, "Skirt", Vector3.new(ws.X / 2 + 0.12, skirtH, 0.14), C.Coat, CFrame.new(side * (ws.X / 4 + 0.14), waistTop - skirtH / 2, -ws.Z / 2 - 0.1) * CFrame.Angles(0, side * 0.12, 0))
			piece(waist, outfit, "Skirt", Vector3.new(0.14, skirtH, ws.Z + 0.2), C.CoatDark, CFrame.new(side * (ws.X / 2 + 0.12), waistTop - skirtH / 2, 0.02))
		end
		piece(waist, outfit, "Skirt", Vector3.new(ws.X + 0.36, skirtH, 0.14), C.Coat, CFrame.new(0, waistTop - skirtH / 2, ws.Z / 2 + 0.1))
		piece(waist, outfit, "Waist", Vector3.new(ws.X + 0.14, 0.4, ws.Z + 0.14), C.Coat, CFrame.new(0, waistTop - 0.2, 0))
	end
	-- Pale grey-blue sleeves (gloves the same colour).
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Sleeve", arm.Size + Vector3.new(0.06, 0.02, 0.06), C.Sleeve, CFrame.new())
		end
	end
	-- Pale leggings with dark raindrop marks.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local ls = leg.Size
			piece(leg, outfit, "Legging", ls + Vector3.new(0.05, 0.02, 0.05), C.Leg, CFrame.new())
			local i = 0
			for y = ls.Y / 2 - 0.3, -ls.Y / 2 + 0.25, -0.45 do
				i = i + 1
				local x = (i % 2 == 0 and 0.2 or -0.2) * ls.X
				piece(leg, outfit, "Drop", Vector3.new(0.16, 0.16, 0.04), C.Drop, CFrame.new(x, y, -ls.Z / 2 - 0.04))
				piece(leg, outfit, "Drop", Vector3.new(0.06, 0.14, 0.04), C.Drop, CFrame.new(x + 0.08, y - 0.12, -ls.Z / 2 - 0.04) * CFrame.Angles(0, 0, 0.5))
				piece(leg, outfit, "Drop", Vector3.new(0.04, 0.16, 0.16), C.Drop, CFrame.new(ls.X / 2 + 0.04, y - 0.2, x * 0.6))
				piece(leg, outfit, "Drop", Vector3.new(0.04, 0.16, 0.16), C.Drop, CFrame.new(-ls.X / 2 - 0.04, y - 0.1, -x * 0.6))
			end
			-- Grey boots over the lower leg.
			if name:find("Lower") or ls.Y > 1.8 then
				local bh = ls.Y > 1.8 and 0.7 or 0.6
				piece(leg, outfit, "Boot", Vector3.new(ls.X + 0.14, bh, ls.Z + 0.14), C.Boot, CFrame.new(0, -ls.Y / 2 + bh / 2, 0))
			end
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			local fs = foot.Size
			piece(foot, outfit, "Boot", fs + Vector3.new(0.12, 0.08, 0.14), C.Boot, CFrame.new())
			-- Studs on the toe and sole.
			for _, x in ipairs({ -0.25, 0.25 }) do
				piece(foot, outfit, "Stud", Vector3.new(0.12, 0.12, 0.08), C.Stud, CFrame.new(x * fs.X, 0, -fs.Z / 2 - 0.1))
			end
		end
	end
end

function BlackmoreOutfit.apply(character)
	if character:FindFirstChild("BlackmoreOutfit") then
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
	outfit.Name = "BlackmoreOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function BlackmoreOutfit.remove(character)
	local outfit = character:FindFirstChild("BlackmoreOutfit")
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
		if character:GetAttribute("TuskAct") == BlackmoreOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == BlackmoreOutfit.Act then
					BlackmoreOutfit.apply(character)
				end
			end)
		else
			BlackmoreOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function BlackmoreOutfit.init()
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

return BlackmoreOutfit
```
