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

**What it does:** Gives a character Blackmore's look while they play him (TuskAct 11), built from blocky parts (no catalog asset ids): a dark wide-brimmed hat a blue mask over the lower face a long dark navy coat with a high collar, buttons and coat tails dark gloves and boots (his umbrella is drawn in his hand by the client) The player's own hats/hair are hidden while they play him and come back when they switch. Built on the server so every player sees it.

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
	built from blocky parts (no catalog asset ids):
	  * a dark wide-brimmed hat
	  * a blue mask over the lower face
	  * a long dark navy coat with a high collar, buttons and coat tails
	  * dark gloves and boots
	  (his umbrella is drawn in his hand by the client)
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local BlackmoreOutfit = {}
BlackmoreOutfit.Act = 11

local C = {
	Hat = Color3.fromRGB(34, 36, 48),
	HatBand = Color3.fromRGB(70, 110, 170),
	Mask = Color3.fromRGB(80, 130, 200),
	Coat = Color3.fromRGB(36, 44, 70),
	CoatDark = Color3.fromRGB(24, 28, 46),
	Button = Color3.fromRGB(200, 210, 230),
	Glove = Color3.fromRGB(28, 28, 34),
	Boot = Color3.fromRGB(30, 30, 38),
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
	local top, d = head.Size.Y / 2, head.Size.Z / 2
	-- Wide-brimmed hat with a blue band.
	piece(head, outfit, "Brim", Vector3.new(head.Size.X + 1.1 * s, 0.12 * s, head.Size.Z + 1.0 * s), C.Hat, CFrame.new(0, top + 0.02 * s, 0))
	piece(head, outfit, "Crown", Vector3.new(head.Size.X * 0.86, 0.6 * s, head.Size.Z * 0.82), C.Hat, CFrame.new(0, top + 0.36 * s, 0.02 * s))
	piece(head, outfit, "Band", Vector3.new(head.Size.X * 0.88, 0.14 * s, head.Size.Z * 0.84), C.HatBand, CFrame.new(0, top + 0.14 * s, 0.02 * s))
	-- Blue mask over the lower face.
	piece(head, outfit, "Mask", Vector3.new(head.Size.X + 0.06 * s, 0.5 * s, head.Size.Z + 0.06 * s), C.Mask, CFrame.new(0, -0.3 * s, 0))
	piece(head, outfit, "MaskSeam", Vector3.new(0.06 * s, 0.5 * s, 0.04 * s), C.CoatDark, CFrame.new(0, -0.3 * s, -d - 0.04 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		piece(upper, outfit, "Coat", s + Vector3.new(0.1, 0.04, 0.1), C.Coat, CFrame.new())
		-- High collar standing up round the neck.
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.7, 0.5, s.Z + 0.2), C.CoatDark, CFrame.new(0, s.Y / 2 + 0.2, 0.02))
		for i = 0, 2 do
			piece(upper, outfit, "Button", Vector3.new(0.14, 0.14, 0.06), C.Button, CFrame.new(0.18, s.Y * 0.3 - i * s.Y * 0.28, -s.Z / 2 - 0.08))
		end
		piece(upper, outfit, "CoatEdge", Vector3.new(0.08, s.Y + 0.06, 0.06), C.CoatDark, CFrame.new(0, 0, -s.Z / 2 - 0.07))
	end
	local waist = lower or upper
	if waist then
		local y = lower and 0 or -upper.Size.Y / 2
		if lower then
			piece(lower, outfit, "Coat", lower.Size + Vector3.new(0.1, 0.04, 0.1), C.Coat, CFrame.new())
		end
		-- Long coat tails down to the knees (front split, back closed).
		for _, side in ipairs({ -1, 1 }) do
			piece(waist, outfit, "CoatTail", Vector3.new(waist.Size.X * 0.48, 1.8, 0.14), C.Coat, CFrame.new(side * waist.Size.X * 0.26, y - 0.9, -waist.Size.Z / 2 - 0.1) * CFrame.Angles(-0.08, 0, side * 0.05))
			piece(waist, outfit, "CoatSide", Vector3.new(0.14, 1.8, waist.Size.Z + 0.2), C.CoatDark, CFrame.new(side * (waist.Size.X / 2 + 0.1), y - 0.9, 0))
		end
		piece(waist, outfit, "CoatBack", Vector3.new(waist.Size.X + 0.2, 1.9, 0.14), C.Coat, CFrame.new(0, y - 0.95, waist.Size.Z / 2 + 0.12) * CFrame.Angles(0.08, 0, 0))
	end
	-- Coat sleeves, gloves, boots.
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Sleeve", arm.Size + Vector3.new(0.08, 0.02, 0.08), C.Coat, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftHand", "RightHand" }) do
		local hand = character:FindFirstChild(name)
		if hand then
			piece(hand, outfit, "Glove", hand.Size + Vector3.new(0.1, 0.06, 0.1), C.Glove, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local tall = leg.Size.Y > 1.8
			local h = tall and 0.9 or leg.Size.Y * 0.8
			piece(leg, outfit, "Boot", Vector3.new(leg.Size.X + 0.12, h, leg.Size.Z + 0.14), C.Boot, CFrame.new(0, -leg.Size.Y / 2 + h / 2, 0))
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
