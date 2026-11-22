---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# DiegoOutfit

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `DiegoOutfit` (capitals matter) |

**What it does:** Gives a character Diego Brando's half-dinosaur look while they play Diego (TuskAct 6), built from parts so no catalog asset ids are needed (from the owner's references): green scaled racing cap with "DIO" on the front spiky blond hair sticking out under it a long blue dinosaur tail with a pale belly and yellow markings The player's own clothes stay on. Their own hats/hair are hidden while they play Diego and come back when they switch. Built on the server so every player sees it. (In full raptor form the client hides all of this and draws the raptor instead.)

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **DiegoOutfit**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	DiegoOutfit  (ServerScriptService.SpinServer.DiegoOutfit)

	Gives a character Diego Brando's half-dinosaur look while they play Diego
	(TuskAct 6), built from parts so no catalog asset ids are needed
	(from the owner's references):
	  * green scaled racing cap with "DIO" on the front
	  * spiky blond hair sticking out under it
	  * a long blue dinosaur tail with a pale belly and yellow markings
	The player's own clothes stay on. Their own hats/hair are hidden while
	they play Diego and come back when they switch. Built on the server so
	every player sees it. (In full raptor form the client hides all of this
	and draws the raptor instead.)
]]

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Blockify = require(Shared.Blockify)

local DiegoOutfit = {}
DiegoOutfit.DiegoAct = 6

local C = {
	Cap = Color3.fromRGB(70, 160, 120),
	CapDark = Color3.fromRGB(40, 110, 85),
	Scale = Color3.fromRGB(110, 200, 150),
	Letters = Color3.fromRGB(240, 230, 200),
	Hair = Color3.fromRGB(245, 214, 110),
	HairDark = Color3.fromRGB(214, 176, 72),
	TailTeal = Color3.fromRGB(95, 205, 212),
	TailBlue = Color3.fromRGB(38, 62, 190),
	Pale = Color3.fromRGB(242, 234, 172),
	Yellow = Color3.fromRGB(246, 212, 62),
}

local saved = setmetatable({}, { __mode = "k" })

local function piece(parent, outfit, props, offset, ellipsoid)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	if ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = outfit
	return p
end

local function cap(head, outfit)
	local s = head.Size.Y / 1.2
	local top = head.Size.Y * 0.5
	-- Dome with a ridge of scales, short brim, "DIO" on the front.
	piece(head, outfit, { Name = "CapDome", Size = Vector3.new(1.42, 0.95, 1.42) * s, Color = C.Cap }, CFrame.new(0, top - 0.12 * s, 0.02 * s), true)
	piece(head, outfit, { Name = "CapBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22 * s, 1.36 * s, 1.36 * s), Color = C.CapDark }, CFrame.new(0, top - 0.32 * s, 0.02 * s) * CFrame.Angles(0, 0, math.pi / 2))
	piece(head, outfit, { Name = "CapBrim", Size = Vector3.new(1.0, 0.08, 0.5) * s, Color = C.CapDark }, CFrame.new(0, top - 0.36 * s, -0.78 * s) * CFrame.Angles(-0.12, 0, 0))
	for i = 0, 6 do
		local a = (i / 6 - 0.5) * 2.2
		piece(head, outfit, { Name = "CapScale", Size = Vector3.new(0.3, 0.16, 0.3) * s, Color = C.Scale }, CFrame.new(0, top - 0.12 * s, 0.02 * s) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 0.46 * s, 0), true)
	end
	local plate = piece(head, outfit, { Name = "CapLetters", Size = Vector3.new(1.0, 0.36, 0.05) * s, Color = C.Cap, Transparency = 1 }, CFrame.new(0, top + 0.02 * s, -0.68 * s) * CFrame.Angles(-0.35, 0, 0))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = plate
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.TextColor3 = C.Letters
	label.TextStrokeTransparency = 0.3
	label.Text = "DIO"
	label.Parent = gui
end

local function hair(head, outfit)
	local s = head.Size.Y / 1.2
	-- Spiky blond hair sticking out the sides and back under the cap.
	local spikes = {
		{ -0.62, 0.05, 0.1, 0, 0, 0.9 }, { 0.62, 0.05, 0.1, 0, 0, -0.9 },
		{ -0.55, -0.2, 0.35, 0.4, 0, 0.7 }, { 0.55, -0.2, 0.35, 0.4, 0, -0.7 },
		{ 0, -0.1, 0.62, 1.0, 0, 0 }, { -0.3, -0.25, 0.58, 1.1, 0, 0.4 }, { 0.3, -0.25, 0.58, 1.1, 0, -0.4 },
		{ -0.35, 0.15, -0.6, -0.9, 0, 0.3 }, { 0.35, 0.15, -0.6, -0.9, 0, -0.3 },
	}
	for i, sp in ipairs(spikes) do
		piece(head, outfit, { Name = "HairSpike", Size = Vector3.new(0.3, 0.8, 0.3) * s, Color = (i % 2 == 0) and C.Hair or C.HairDark },
			CFrame.new(sp[1] * s, sp[2] * s, sp[3] * s) * CFrame.Angles(sp[4], sp[5], sp[6]) * CFrame.new(0, 0.25 * s, 0), true)
	end
	piece(head, outfit, { Name = "HairBack", Size = Vector3.new(1.25, 0.9, 0.5) * s, Color = C.Hair }, CFrame.new(0, 0.05 * s, 0.45 * s), true)
end

local function tail(character, outfit)
	local hip = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
	if not hip then
		return
	end
	local s = hip.Size.X / 2
	local back = hip.Size.Z / 2
	-- Starts at the lower back, sweeps down and back, the tip curls up.
	local cf = CFrame.new(0, -hip.Size.Y * 0.2, back) * CFrame.Angles(0.75, 0, 0) -- (+X tips the backward-pointing tail down)
	local count = 8
	for i = 1, count do
		local k = (i - 1) / count
		local d = 0.85 * (1 - k * 0.8) * s
		local len = 0.85 * s
		local color = i <= 2 and C.TailTeal:Lerp(C.TailBlue, (i - 1) / 2) or C.TailBlue
		local segCF = cf * CFrame.new(0, 0, len / 2)
		piece(hip, outfit, { Name = "Tail", Size = Vector3.new(d, d * 0.92, len * 1.6), Color = color }, segCF, true)
		piece(hip, outfit, { Name = "TailBelly", Size = Vector3.new(d * 0.7, d * 0.4, len * 1.5), Color = C.Pale }, segCF * CFrame.new(0, -d * 0.3, 0), true)
		if i >= 2 and i <= 7 then
			piece(hip, outfit, { Name = "TailMark", Size = Vector3.new(d * 0.35, d * 0.12, len * 0.7), Color = C.Yellow }, segCF * CFrame.new(0, d * 0.44, 0), true)
		end
		local bend = (i <= 4) and -0.16 or (i >= 6 and -0.22 or 0) -- level out, then the tip curls up
		cf = cf * CFrame.new(0, 0, len) * CFrame.Angles(bend, 0, 0)
	end
end

function DiegoOutfit.apply(character)
	if character:FindFirstChild("DiegoOutfit") then
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
	outfit.Name = "DiegoOutfit"
	outfit.Parent = character
	cap(head, outfit)
	hair(head, outfit)
	tail(character, outfit)
	-- The dinosaur tail is Scary Monsters' and follows its blocky look.
	if Blockify.enabled(TuskConfig) then
		for _, p in ipairs(outfit:GetChildren()) do
			if p.Name:sub(1, 4) == "Tail" then
				Blockify.apply(p)
			end
		end
	end
end

function DiegoOutfit.remove(character)
	local outfit = character:FindFirstChild("DiegoOutfit")
	if outfit then
		outfit:Destroy()
	end
	local store = saved[character]
	if not store then
		return
	end
	saved[character] = nil
	for handle, transparency in pairs(store.Hidden) do
		if handle.Parent then
			handle.Transparency = transparency
		end
	end
end

local function watch(character)
	local function update()
		if character:GetAttribute("TuskAct") == DiegoOutfit.DiegoAct then
			task.delay(0.3, function()
				if character.Parent and character:GetAttribute("TuskAct") == DiegoOutfit.DiegoAct then
					DiegoOutfit.apply(character)
				end
			end)
		else
			DiegoOutfit.remove(character)
		end
	end
	character:GetAttributeChangedSignal("TuskAct"):Connect(update)
	update()
end

function DiegoOutfit.init()
	local function onPlayer(player)
		player.CharacterAppearanceLoaded:Connect(watch)
		if player.Character then
			watch(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
end

return DiegoOutfit
```
