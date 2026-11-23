--[[
	HotPantsOutfit  (ServerScriptService.SpinServer.HotPantsOutfit)

	Gives a character Hot Pants' look while they play her (TuskAct 10),
	built from blocky parts (no catalog asset ids):
	  * a low pink cap with a short visor, short hair at the sides
	  * a fitted purple top with a gold cross pendant
	  * her namesake short shorts with a belt, knee-high boots
	  * (CREAM STARTER, her Stand, is drawn in her hand by the client)
	The player's own hats/hair are hidden while they play her and come back
	when she switches. Built on the server so every player sees it.
]]

local Players = game:GetService("Players")

local HotPantsOutfit = {}
HotPantsOutfit.Act = 10

local C = {
	Cap = Color3.fromRGB(232, 120, 160),
	CapDark = Color3.fromRGB(180, 80, 120),
	Hair = Color3.fromRGB(70, 48, 40),
	Top = Color3.fromRGB(96, 60, 120),
	TopTrim = Color3.fromRGB(70, 40, 92),
	Cross = Color3.fromRGB(236, 196, 80),
	Shorts = Color3.fromRGB(236, 120, 70),
	Belt = Color3.fromRGB(60, 40, 30),
	Boot = Color3.fromRGB(60, 44, 52),
	Can = Color3.fromRGB(242, 140, 172),
	CanCap = Color3.fromRGB(245, 245, 245),
	Label = Color3.fromRGB(255, 225, 120),
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
	local h, d = head.Size.Y / 2, head.Size.Z / 2
	-- Low cap pulled over the brow, with a short visor.
	piece(head, outfit, "Cap", Vector3.new(head.Size.X + 0.14 * s, 0.55 * s, head.Size.Z + 0.14 * s), C.Cap, CFrame.new(0, h - 0.15 * s, 0.02 * s))
	piece(head, outfit, "CapTop", Vector3.new(head.Size.X * 0.8, 0.14 * s, head.Size.Z * 0.8), C.CapDark, CFrame.new(0, h + 0.18 * s, 0.02 * s))
	piece(head, outfit, "Visor", Vector3.new(head.Size.X * 0.9, 0.1 * s, 0.5 * s), C.CapDark, CFrame.new(0, h - 0.32 * s, -d - 0.2 * s) * CFrame.Angles(-0.12, 0, 0))
	-- Short hair at the sides and back.
	for _, side in ipairs({ -1, 1 }) do
		piece(head, outfit, "Hair", Vector3.new(0.16 * s, 0.6 * s, head.Size.Z * 0.75), C.Hair, CFrame.new(side * (head.Size.X / 2 + 0.06 * s), -0.05 * s, 0.05 * s))
	end
	piece(head, outfit, "Hair", Vector3.new(head.Size.X + 0.1 * s, 0.55 * s, 0.16 * s), C.Hair, CFrame.new(0, -0.05 * s, d + 0.06 * s))
end

local function body(character, outfit)
	local upper = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local lower = character:FindFirstChild("LowerTorso")
	if upper then
		local s = upper.Size
		piece(upper, outfit, "Top", s + Vector3.new(0.08, 0.02, 0.08), C.Top, CFrame.new())
		piece(upper, outfit, "Collar", Vector3.new(s.X * 0.6, 0.22, s.Z + 0.14), C.TopTrim, CFrame.new(0, s.Y / 2 + 0.02, 0))
		-- Gold cross pendant.
		piece(upper, outfit, "Cross", Vector3.new(0.12, 0.5, 0.06), C.Cross, CFrame.new(0, s.Y * 0.1, -s.Z / 2 - 0.08))
		piece(upper, outfit, "Cross", Vector3.new(0.34, 0.12, 0.06), C.Cross, CFrame.new(0, s.Y * 0.18, -s.Z / 2 - 0.08))
		for _, side in ipairs({ -1, 1 }) do
			piece(upper, outfit, "Chain", Vector3.new(0.05, s.Y * 0.4, 0.05), C.Cross, CFrame.new(side * 0.22, s.Y * 0.3, -s.Z / 2 - 0.06) * CFrame.Angles(0, 0, side * 0.5))
		end
	end
	local waist = lower or upper
	if waist then
		local y = lower and 0 or -upper.Size.Y / 2 + 0.15
		piece(waist, outfit, "Shorts", Vector3.new(waist.Size.X + 0.1, lower and waist.Size.Y + 0.04 or 0.5, waist.Size.Z + 0.1), C.Shorts, CFrame.new(0, lower and 0 or y - 0.1, 0))
		piece(waist, outfit, "Belt", Vector3.new(waist.Size.X + 0.14, 0.18, waist.Size.Z + 0.14), C.Belt, CFrame.new(0, lower and waist.Size.Y / 2 - 0.05 or y + 0.12, 0))
		-- (Cream Starter is always in her right hand: drawn by the client.)
	end
	-- Bare legs under the shorts and boots, long purple sleeves.
	local headPart = character:FindFirstChild("Head")
	local skin = headPart and headPart.Color or Color3.fromRGB(238, 196, 164)
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			piece(leg, outfit, "Skin", leg.Size + Vector3.new(0.04, 0.02, 0.04), skin, CFrame.new())
		end
	end
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "Left Arm", "Right Arm" }) do
		local arm = character:FindFirstChild(name)
		if arm then
			local tall = arm.Size.Y > 1.8
			local h = tall and arm.Size.Y - 0.35 or arm.Size.Y
			piece(arm, outfit, "Sleeve", Vector3.new(arm.Size.X + 0.06, h + 0.02, arm.Size.Z + 0.06), C.Top, CFrame.new(0, arm.Size.Y / 2 - h / 2, 0))
		end
	end
	-- Short shorts: only the very top of the legs is covered.
	for _, name in ipairs({ "LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local tall = leg.Size.Y > 1.8
			local h = tall and 0.5 or leg.Size.Y * 0.45
			piece(leg, outfit, "ShortsLeg", Vector3.new(leg.Size.X + 0.14, h, leg.Size.Z + 0.14), C.Shorts, CFrame.new(0, leg.Size.Y / 2 - h / 2, 0))
		end
	end
	-- Knee-high boots.
	for _, name in ipairs({ "LeftLowerLeg", "RightLowerLeg", "Left Leg", "Right Leg" }) do
		local leg = character:FindFirstChild(name)
		if leg then
			local tall = leg.Size.Y > 1.8
			local h = tall and 1.0 or leg.Size.Y * 0.85
			piece(leg, outfit, "Boot", Vector3.new(leg.Size.X + 0.16, h, leg.Size.Z + 0.18), C.Boot, CFrame.new(0, -leg.Size.Y / 2 + h / 2, 0))
		end
	end
	for _, name in ipairs({ "LeftFoot", "RightFoot" }) do
		local foot = character:FindFirstChild(name)
		if foot then
			piece(foot, outfit, "Boot", foot.Size + Vector3.new(0.1, 0.06, 0.12), C.Boot, CFrame.new())
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
