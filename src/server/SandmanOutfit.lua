--[[
	SandmanOutfit  (ServerScriptService.SpinServer.SandmanOutfit)

	Gives a character Sandman's look while they play him (TuskAct 8), built
	from blocky parts (no catalog asset ids):
	  * long straight black hair down his back with side locks
	  * a red-and-white beaded headband with a feather at the back
	  * a sand-coloured scarf, a sleeveless sand vest with a dark trim
	  * a red sash with a hanging pouch, wrapped forearms and shins
	The player's own hats/hair are hidden while they play him and come back
	when they switch. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local SandmanOutfit = {}
SandmanOutfit.Act = 8

local C = {
	Hair = Color3.fromRGB(25, 22, 24),
	HairShine = Color3.fromRGB(55, 50, 55),
	Band = Color3.fromRGB(190, 50, 45),
	Bead = Color3.fromRGB(240, 235, 220),
	Feather = Color3.fromRGB(245, 240, 230),
	FeatherTip = Color3.fromRGB(40, 35, 35),
	Scarf = Color3.fromRGB(230, 200, 140),
	Vest = Color3.fromRGB(205, 165, 105),
	Trim = Color3.fromRGB(110, 70, 40),
	Sash = Color3.fromRGB(180, 45, 40),
	Pouch = Color3.fromRGB(120, 80, 45),
	Wrap = Color3.fromRGB(235, 220, 190),
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
	-- Hair: a cap over the top, a long sheet down the back, locks at the sides.
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.12 * s, 0.3 * s, head.Size.Z + 0.12 * s), C.Hair, CFrame.new(0, h - 0.05 * s, 0.02 * s))
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.12 * s, head.Size.Y * 0.9, 0.2 * s), C.Hair, CFrame.new(0, 0.05 * s, d + 0.08 * s))
	piece(head, outfit, "HairLong", Vector3.new(head.Size.X * 0.9, 2.2 * s, 0.22 * s), C.Hair, CFrame.new(0, -1.5 * s, d + 0.2 * s) * CFrame.Angles(-0.12, 0, 0))
	piece(head, outfit, "HairShine", Vector3.new(0.12 * s, 2.0 * s, 0.05 * s), C.HairShine, CFrame.new(0.2 * s, -1.4 * s, d + 0.33 * s) * CFrame.Angles(-0.12, 0, 0))
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "HairLock", Vector3.new(0.2 * s, 1.2 * s, 0.35 * s), C.Hair, CFrame.new(side * (w + 0.08 * s), -0.25 * s, -0.05 * s))
	end
	-- Beaded headband round the forehead.
	local bandY = h * 0.42
	piece(head, outfit, "Band", Vector3.new(head.Size.X + 0.18 * s, 0.18 * s, head.Size.Z + 0.18 * s), C.Band, CFrame.new(0, bandY, 0))
	for i = -2, 2 do
		piece(head, outfit, "Bead", Vector3.new(0.1, 0.1, 0.04) * s, C.Bead, CFrame.new(i * 0.2 * s, bandY, -d - 0.1 * s))
	end
	-- Feather tucked in at the back.
	local feather = CFrame.new(0.25 * s, bandY + 0.5 * s, d + 0.15 * s) * CFrame.Angles(-0.35, 0, -0.3)
	piece(head, outfit, "Feather", Vector3.new(0.08, 1.1, 0.26) * s, C.Feather, feather)
	piece(head, outfit, "FeatherTip", Vector3.new(0.09, 0.28, 0.27) * s, C.FeatherTip, feather * CFrame.new(0, 0.45 * s, 0))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		-- Sleeveless vest, open down the front.
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Vest", Vector3.new(s.X * 0.42, s.Y + 0.04, s.Z + 0.1), C.Vest, CFrame.new(side * s.X * 0.29, 0, 0))
			piece(upper, outfit, "Trim", Vector3.new(0.12, s.Y + 0.06, 0.06), C.Trim, CFrame.new(side * s.X * 0.08, 0, -s.Z / 2 - 0.07))
		end
		piece(upper, outfit, "VestBack", Vector3.new(s.X + 0.06, s.Y + 0.04, 0.08), C.Vest, CFrame.new(0, 0, s.Z / 2 + 0.04))
		-- Scarf round the neck, one end hanging.
		piece(upper, outfit, "Scarf", Vector3.new(s.X * 0.75, 0.3, s.Z + 0.25), C.Scarf, CFrame.new(0, s.Y / 2 + 0.05, 0))
		piece(upper, outfit, "ScarfEnd", Vector3.new(0.35, 0.9, 0.1), C.Scarf, CFrame.new(-s.X * 0.18, s.Y / 2 - 0.45, -s.Z / 2 - 0.1) * CFrame.Angles(0, 0, 0.15))
	end
	local waist = lower or upper
	if waist then
		local y = lower and 0 or -upper.Size.Y / 2 + 0.15
		piece(waist, outfit, "Sash", Vector3.new(waist.Size.X + 0.12, 0.3, waist.Size.Z + 0.12), C.Sash, CFrame.new(0, y, 0))
		piece(waist, outfit, "SashTail", Vector3.new(0.3, 0.9, 0.08), C.Sash, CFrame.new(waist.Size.X * 0.3, y - 0.5, -waist.Size.Z / 2 - 0.08))
		piece(waist, outfit, "Pouch", Vector3.new(0.45, 0.5, 0.3), C.Pouch, CFrame.new(-waist.Size.X / 2 - 0.1, y - 0.25, 0))
	end
	-- Sleeveless: bare arms over whatever shirt the avatar wears.
	local headPart = character:FindFirstChild("Head")
	local skin = headPart and headPart.Color or Color3.fromRGB(170, 115, 80)
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			piece(arm, outfit, "Skin", arm.Size + Vector3.new(0.04, 0.02, 0.04), skin, CFrame.new())
		end
	end
	-- Wrapped forearms and shins.
	for _, name in ipairs({ "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local y = -arm.Size.Y / 2 + (arm.Size.Y > 1.8 and 0.7 or 0.35)
			piece(arm, outfit, "Wrap", Vector3.new(arm.Size.X + 0.1, arm.Size.Y > 1.8 and 0.9 or 0.6, arm.Size.Z + 0.1), C.Wrap, CFrame.new(0, y, 0))
		end
	end
	for _, name in ipairs({ "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local y = -leg.Size.Y / 2 + (leg.Size.Y > 1.8 and 0.6 or 0.4)
			piece(leg, outfit, "Wrap", Vector3.new(leg.Size.X + 0.1, leg.Size.Y > 1.8 and 0.8 or 0.6, leg.Size.Z + 0.1), C.Wrap, CFrame.new(0, y, 0))
		end
	end
end

function SandmanOutfit.apply(character)
	if character:FindFirstChild("SandmanOutfit") then
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
	outfit.Name = "SandmanOutfit"
	outfit.Parent = character
	headPieces(head, outfit)
	body(character, outfit)
end

function SandmanOutfit.remove(character)
	local outfit = character:FindFirstChild("SandmanOutfit")
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
		if character:GetAttribute("TuskAct") == SandmanOutfit.Act then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == SandmanOutfit.Act then
					SandmanOutfit.apply(character)
				end
			end)
		else
			SandmanOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function SandmanOutfit.init()
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

return SandmanOutfit
