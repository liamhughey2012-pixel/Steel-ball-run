---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# RohanVFX

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `RohanVFX` (capitals matter) |

**What it does:** Client visuals for Rohan Kishibe / HEAVEN'S DOOR. Blocky. Heaven's Door (HeavensDoorStand), small, floats at his shoulder; Rohan poses with his pen raised by his face PEN & PAGE COMBO: swipes with ink drops flicking off the pen HEAVEN'S DOOR: "HEAVEN'S DOOR!"; the target's face peels open into a BOOK: pages fan out in front of their face and flutter while they're stuck; then a little open book floats over their head while he can write in them WRITE: his pen scribbles; the command appears over them in ink on a strip of paper ("YOU CAN'T ATTACK KISHIBE ROHAN" / "FLY BACKWARDS AT 70 KM/H"); flying backwards leaves speed lines; trying to hit him with the command written in them just stops them ("...!?") EVERYONE IS A BOOK: a burst of pages from him; everyone near opens like a book at once, the command written over each of them

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **RohanVFX**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.RohanVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.RohanVFX)

	Client visuals for Rohan Kishibe / HEAVEN'S DOOR. Blocky.
	  * Heaven's Door (HeavensDoorStand), small, floats at his shoulder;
	    Rohan poses with his pen raised by his face
	  * PEN & PAGE COMBO: swipes with ink drops flicking off the pen
	  * HEAVEN'S DOOR: "HEAVEN'S DOOR!"; the target's face peels open into a
	    BOOK: pages fan out in front of their face and flutter while they're
	    stuck; then a little open book floats over their head while he can
	    write in them
	  * WRITE: his pen scribbles; the command appears over them in ink on a
	    strip of paper ("YOU CAN'T ATTACK KISHIBE ROHAN" / "FLY BACKWARDS AT
	    70 KM/H"); flying backwards leaves speed lines; trying to hit him
	    with the command written in them just stops them ("...!?")
	  * EVERYONE IS A BOOK: a burst of pages from him; everyone near opens
	    like a book at once, the command written over each of them
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local TuskStandModels = require(Shared.TuskStandModels)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local Common = require(script.Parent.Parent.TuskActCommon)
local Fighters = require(script.Parent.Parent.Fighters)
local TuskStand = require(script.Parent.Parent.TuskStand)
local HeavensDoorStand = require(script.Parent.HeavensDoorStand)

local RohanVFX = {}
local ACT = 28
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, HeavensDoorStand.build, { Aura = HeavensDoorStand.Aura, AuraLight = HeavensDoorStand.AuraLight, Offset = HeavensDoorStand.Offset })

local INK = Color3.fromRGB(24, 22, 30)
local PAGE = Color3.fromRGB(250, 246, 232)
local PAGE_SHADE = Color3.fromRGB(226, 216, 190)
local GREEN = Color3.fromRGB(130, 220, 140)

local stanced = {}
local books = {} -- [target] = { Parts, Badge }

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function label(adornee, text, color, duration, size, offset, font)
	if not adornee then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size or 240, (size or 240) / 5)
	bb.StudsOffset = offset or Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = adornee
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = font or Enum.Font.Bangers
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.1
	t.Parent = bb
	bb.Parent = VFXLib.Folder
	local base = bb.StudsOffset
	VFXLib.animate(duration or 1.2, function(a)
		bb.StudsOffset = base + Vector3.new(0, a * 1.2, 0)
		t.TextTransparency = math.max(0, a * 1.6 - 0.6)
		t.TextStrokeTransparency = 0.1 + 0.9 * a
	end, function()
		bb:Destroy()
	end)
end

-- A command written in ink on a strip of paper over someone's head.
local function writtenStrip(target, text, time)
	local head = typeof(target) == "Instance" and target:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(300, 46)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	local paper = Instance.new("Frame")
	paper.Size = UDim2.fromScale(1, 1)
	paper.BackgroundColor3 = PAGE
	paper.BorderSizePixel = 0
	paper.Rotation = -3
	paper.Parent = bb
	local stroke = Instance.new("UIStroke")
	stroke.Color = PAGE_SHADE
	stroke.Thickness = 2
	stroke.Parent = paper
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, -12, 1, -8)
	t.Position = UDim2.fromOffset(6, 4)
	t.Font = Enum.Font.PermanentMarker
	t.TextScaled = true
	t.TextColor3 = INK
	t.Text = ""
	t.Parent = paper
	bb.Parent = VFXLib.Folder
	-- Written out letter by letter.
	local total = #text
	VFXLib.animate(time or 4, function(a)
		local shown = math.min(total, math.floor(a * (time or 4) / 0.025))
		t.Text = string.sub(text, 1, shown)
		if a > 0.85 then
			local k = (a - 0.85) / 0.15
			paper.BackgroundTransparency = k
			t.TextTransparency = k
			stroke.Transparency = k
		end
	end, function()
		bb:Destroy()
	end)
end

-- Ink drops flicking off the pen.
local function ink(from, dir)
	for _ = 1, 5 do
		local drop = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.22, 0.22, 0.22), Color = INK, CFrame = CFrame.new(from) })
		local v = (dir + Vector3.new((math.random() - 0.5) * 0.8, math.random() * 0.5, (math.random() - 0.5) * 0.8)).Unit * (10 + math.random() * 8)
		VFXLib.animate(0.35, function(a)
			local t = a * 0.35
			drop.CFrame = CFrame.new(from + v * t + Vector3.new(0, -30 * t * t, 0))
			drop.Transparency = math.max(0, a * 1.4 - 0.4)
		end, function()
			drop:Destroy()
		end)
	end
end

-- Their face peels open into a book: pages fan out in front of their head.
local function closeBook(target)
	local b = books[target]
	books[target] = nil
	if b then
		for _, p in ipairs(b.Parts) do
			p:Destroy()
		end
		if b.Badge and b.Badge.Parent then
			b.Badge:Destroy()
		end
	end
end

local function openBook(target, bookTime, readable)
	local head = typeof(target) == "Instance" and target:FindFirstChild("Head")
	if not head then
		return
	end
	closeBook(target)
	local parts = {}
	for i = 1, 8 do
		local side = i % 2 == 0 and 1 or -1
		local p = VFXLib.part({ Size = Vector3.new(0.9, 1.2, 0.03), Color = i % 3 == 0 and PAGE_SHADE or PAGE, Material = Enum.Material.SmoothPlastic })
		parts[i] = { Part = p, Side = side, Index = math.ceil(i / 2) }
	end
	local list = {}
	for _, e in ipairs(parts) do
		table.insert(list, e.Part)
	end
	local entry = { Parts = list }
	books[target] = entry
	-- The pages flutter while they're stuck, then fold away.
	VFXLib.animate(bookTime or 1.8, function(a)
		if not head.Parent then
			return
		end
		local open = a < 0.15 and VFXLib.easeOut(a / 0.15) or (a > 0.85 and (1 - a) / 0.15 or 1)
		for _, e in ipairs(parts) do
			local flap = math.sin(os.clock() * 14 + e.Index) * 0.15
			local ang = e.Side * (0.25 + e.Index * 0.22) * open + flap
			e.Part.CFrame = head.CFrame * CFrame.new(0, 0, -head.Size.Z / 2 - 0.15) * CFrame.Angles(0, ang, 0) * CFrame.new(e.Side * 0.45 * open, 0, 0)
		end
	end, function()
		if books[target] == entry then
			for _, p in ipairs(list) do
				p:Destroy()
			end
			entry.Parts = {}
		end
	end)
	-- A little open book over their head while he can write in them.
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(44, 44)
	bb.StudsOffset = Vector3.new(0, 2.4, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = "📖"
	t.Parent = bb
	bb.Parent = VFXLib.Folder
	entry.Badge = bb
	task.delay((bookTime or 1.8) + (readable or 7), function()
		if bb.Parent then
			bb:Destroy()
		end
		if books[target] == entry then
			books[target] = nil
		end
	end)
	VFXLib.sound(sounds.Swing, head.Position, 0.5, 1.6)
end

---------------------------------------------------------------------------
-- Moves
---------------------------------------------------------------------------
local function onM1(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local index = data.Index or 1
	TuskAnimation.play(character, "RH_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.6 or 0.6, 0.8, -2.8), Duration = 0.26 })
	VFXLib.sound(sounds.Swing, root, 0.45, 1.15 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or INK)
	ink((root.CFrame * CFrame.new(0.8, 1, -1.5)).Position, root.CFrame.LookVector)
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "OpenBook" then
		if phase == "Reach" and character and root then
			TuskAnimation.play(character, "RHOpen")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 0.8, -4), Duration = (data.Windup or 0.3) + 0.4 })
			label(character:FindFirstChild("Head"), "HEAVEN'S DOOR!", GREEN, 1.2, 260)
		elseif phase == "Open" and typeof(data.Target) == "Instance" then
			openBook(data.Target, data.BookTime, data.Readable)
			local tr = data.Target:FindFirstChild("HumanoidRootPart")
			if tr then
				TuskVFX.CreateImpactStar(tr.Position + Vector3.new(0, 1.5, 0), { Size = 2.4, Rays = 6, Color = PAGE, Color2 = GREEN, Duration = 0.14 })
			end
		elseif phase == "Miss" and data.Position then
			VFXLib.burst(data.Position, { Count = 6, Color = PAGE, Speed = 8, Lifetime = 0.3 })
		end
	elseif move == "Write" then
		if (phase == "CantAttack" or phase == "FlyWrite") and character and root then
			TuskAnimation.play(character, "RHWrite")
			ink((root.CFrame * CFrame.new(0.8, 1, -1.5)).Position, root.CFrame.LookVector)
		end
		if phase == "CantAttack" and data.Target then
			writtenStrip(data.Target, "YOU CAN'T ATTACK KISHIBE ROHAN", math.min(data.Time or 7, 5))
		elseif phase == "FlyWrite" and data.Target then
			writtenStrip(data.Target, "FLY BACKWARDS AT 70 KM/H", 2.5)
		elseif phase == "Fly" and typeof(data.Target) == "Instance" then
			local tr = data.Target:FindFirstChild("HumanoidRootPart")
			if tr then
				-- Speed lines streaming off them as they go.
				VFXLib.animate(0.7, function()
					if not tr.Parent then
						return
					end
					if math.random() < 0.6 then
						local dir = data.Direction or Vector3.new(0, 0, 1)
						local p = tr.Position + Vector3.new((math.random() - 0.5) * 2, (math.random() - 0.5) * 3, (math.random() - 0.5) * 2)
						local line = VFXLib.part({ Size = Vector3.new(0.08, 0.08, 3), CFrame = CFrame.lookAt(p - dir * 1.5, p + dir), Color = Color3.new(1, 1, 1), Transparency = 0.2 })
						VFXLib.animate(0.2, function(a)
							line.Transparency = 0.2 + 0.8 * a
						end, function()
							line:Destroy()
						end)
					end
				end)
				CameraFX.shakeAt(tr.Position, 0.5, 40)
			end
		elseif phase == "Refused" and typeof(data.Target) == "Instance" then
			label(data.Target:FindFirstChild("Head"), "...!? (CAN'T ATTACK KISHIBE ROHAN)", INK, 1.4, 320, Vector3.new(0, 3.6, 0))
		elseif phase == "NoBook" and character and Common.isLocal(character) then
			label(character:FindFirstChild("Head"), "NO BOOK TO WRITE IN", PAGE, 1.0, 220)
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character and root then
		TuskAnimation.play(character, "RHUlt")
		TuskStand.action(character, "Loom", { Target = CFrame.new(1.2, 2.4, 1.6), Duration = (data.Windup or 0.8) + 0.6 })
		label(character:FindFirstChild("Head"), "HEAVEN'S DOOR: EVERYONE IS A BOOK", GREEN, 2.0, 380)
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.2)
	elseif data.Phase == "Books" and data.Position then
		-- A burst of pages from him.
		for _ = 1, 18 do
			local p = VFXLib.part({ Size = Vector3.new(0.8, 1.1, 0.03), Color = PAGE, CFrame = CFrame.new(data.Position) })
			local dir = Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5).Unit
			local dist = (data.Radius or 30) * (0.4 + math.random() * 0.6)
			local spin = Vector3.new(math.random() * 8, math.random() * 8, math.random() * 8)
			VFXLib.animate(0.9, function(a)
				p.CFrame = CFrame.new(data.Position + dir * dist * VFXLib.easeOut(a)) * CFrame.Angles(spin.X * a, spin.Y * a, spin.Z * a)
				p.Transparency = math.max(0, a * 1.5 - 0.5)
			end, function()
				p:Destroy()
			end)
		end
		for _, target in ipairs(data.Targets or {}) do
			openBook(target, data.BookTime or 3, 6)
			writtenStrip(target, "YOU CAN'T ATTACK KISHIBE ROHAN", 4)
		end
		CameraFX.shakeAt(data.Position, 0.6, 50)
		if character and Common.isLocal(character) then
			CameraFX.impactFrame(pal.Light)
		end
	end
end

---------------------------------------------------------------------------
-- Every frame
---------------------------------------------------------------------------
local function stepStance()
	for _, fighter in ipairs(Fighters.list()) do
		local character = fighter.Character
		if character then
			local want = character:GetAttribute("TuskAct") == ACT
			if want and not stanced[character] then
				stanced[character] = true
				TuskAnimation.hold(character, "RohanStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "RohanStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
	for target in pairs(books) do
		if not target.Parent then
			closeBook(target)
		end
	end
end

function RohanVFX.handle(name, data)
	if name == "M1" then
		onM1(data)
	elseif name == "M1Finisher" then
		onFinisher(data)
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

local slowTimer = 0
function RohanVFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
	end
end

return RohanVFX
```
