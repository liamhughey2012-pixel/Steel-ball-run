---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# OkuyasuVFX

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `OkuyasuVFX` (capitals matter) |

**What it does:** Client visuals for Okuyasu Nijimura / THE HAND. Blocky. The Hand (TheHandStand) floats behind him with a blue aura; Okuyasu stands in a tough slouch HAND COMBO: blue swings; the 4th is a big backhand SPACE ERASE: The Hand winds up and swipes its glowing palm; a black rip opens in the air where it passed (a thin pale edge round a void), then snaps shut; "GAOON" ERASE PULL: a swipe at empty air; a void streak runs from the target to him, an afterimage is left where they stood, "GAOON" ERASE DASH: a swipe; he blinks forward, an afterimage and a void streak left behind ZA HANDO: GREAT ERASURE: "ZA HANDO!", then rip after rip in front of him (GAOON, GAOON...), the last one huge

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **OkuyasuVFX**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.OkuyasuVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.OkuyasuVFX)

	Client visuals for Okuyasu Nijimura / THE HAND. Blocky.
	  * The Hand (TheHandStand) floats behind him with a blue aura; Okuyasu
	    stands in a tough slouch
	  * HAND COMBO: blue swings; the 4th is a big backhand
	  * SPACE ERASE: The Hand winds up and swipes its glowing palm; a black
	    rip opens in the air where it passed (a thin pale edge round a void),
	    then snaps shut; "GAOON"
	  * ERASE PULL: a swipe at empty air; a void streak runs from the target
	    to him, an afterimage is left where they stood, "GAOON"
	  * ERASE DASH: a swipe; he blinks forward, an afterimage and a void
	    streak left behind
	  * ZA HANDO: GREAT ERASURE: "ZA HANDO!", then rip after rip in front of
	    him (GAOON, GAOON...), the last one huge
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
local TheHandStand = require(script.Parent.TheHandStand)

local OkuyasuVFX = {}
local ACT = 27
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, TheHandStand.build, { Aura = TheHandStand.Aura, AuraLight = TheHandStand.AuraLight, Offset = TheHandStand.Offset })

local BLUE = Color3.fromRGB(110, 160, 255)
local EDGE = Color3.fromRGB(200, 240, 255)
local VOID = Color3.fromRGB(6, 4, 12)
local GOLD = Color3.fromRGB(236, 190, 70)

local stanced = {}

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function label(adornee, text, color, duration, size, offset)
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
	t.Font = Enum.Font.Bangers
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

-- "GAOON" at a world spot.
local function gaoon(at, big)
	local anchor = VFXLib.part({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(at), Transparency = 1 })
	label(anchor, "GAOON", big and GOLD or EDGE, big and 1.2 or 0.8, big and 300 or 180, Vector3.new((math.random() - 0.5) * 2, 1, 0))
	task.delay(1.3, function()
		anchor:Destroy()
	end)
end

-- A rip in space: a black void with a pale edge, opening along the swipe and
-- snapping shut. `cf` faces where the swipe went; `width` across, `height` tall.
local function rip(cf, width, height, life)
	life = life or 0.5
	local void = VFXLib.part({ Size = Vector3.new(0.1, height, 0.3), CFrame = cf, Color = VOID, Material = Enum.Material.SmoothPlastic, Transparency = 0 })
	local edgeA = VFXLib.part({ Size = Vector3.new(0.1, height, 0.12), CFrame = cf, Color = EDGE, Transparency = 0.1 })
	local edgeB = VFXLib.part({ Size = Vector3.new(0.1, height, 0.12), CFrame = cf, Color = EDGE, Transparency = 0.1 })
	VFXLib.animate(life, function(a)
		-- Opens fast, hangs, then snaps shut.
		local open = a < 0.25 and VFXLib.easeOut(a / 0.25) or (a < 0.7 and 1 or 1 - (a - 0.7) / 0.3)
		local w = math.max(0.1, width * open)
		void.Size = Vector3.new(w, height * (0.6 + 0.4 * open), 0.3)
		void.CFrame = cf
		edgeA.CFrame = cf * CFrame.new(-w / 2, 0, -0.1)
		edgeB.CFrame = cf * CFrame.new(w / 2, 0, -0.1)
		edgeA.Size = Vector3.new(0.12, void.Size.Y, 0.12)
		edgeB.Size = edgeA.Size
	end, function()
		void:Destroy()
		edgeA:Destroy()
		edgeB:Destroy()
	end)
end

-- The glowing palm sweeping across in front.
local function palmSweep(cf, width)
	local palm = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), Color = EDGE, Transparency = 0.2 })
	local trail = VFXLib.part({ Size = Vector3.new(0.2, 2.4, 0.2), Color = BLUE, Transparency = 0.4 })
	VFXLib.animate(0.18, function(a)
		local x = (0.5 - a) * width
		palm.CFrame = cf * CFrame.new(x, 0.6 - a * 1.2, 0)
		trail.CFrame = cf * CFrame.new(x + width * 0.08, 0.6 - a * 1.2, 0)
		trail.Transparency = 0.4 + 0.6 * a
	end, function()
		palm:Destroy()
		trail:Destroy()
	end)
end

-- A void streak between two points (space erased between them).
local function streak(from, to)
	local len = (to - from).Magnitude
	if len < 0.5 then
		return
	end
	local line = VFXLib.part({ Size = Vector3.new(0.6, 0.6, len), CFrame = CFrame.lookAt((from + to) / 2, to), Color = VOID, Material = Enum.Material.SmoothPlastic, Transparency = 0.1 })
	local glow = VFXLib.part({ Size = Vector3.new(0.9, 0.9, len), CFrame = line.CFrame, Color = EDGE, Transparency = 0.6 })
	VFXLib.animate(0.35, function(a)
		local k = 1 - a
		line.Size = Vector3.new(0.6 * k, 0.6 * k, len)
		glow.Size = Vector3.new(0.9 * k + 0.05, 0.9 * k + 0.05, len)
		glow.Transparency = 0.6 + 0.4 * a
	end, function()
		line:Destroy()
		glow:Destroy()
	end)
end

-- A pale afterimage of someone where they just were.
local function afterimage(character, at)
	if typeof(character) ~= "Instance" then
		return
	end
	local ghost = VFXLib.part({ Size = Vector3.new(2, 5, 1), CFrame = CFrame.new(at), Color = EDGE, Transparency = 0.5 })
	VFXLib.animate(0.4, function(a)
		ghost.Transparency = 0.5 + 0.5 * a
		ghost.Size = Vector3.new(2 * (1 - a * 0.5), 5, 1)
	end, function()
		ghost:Destroy()
	end)
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
	TuskAnimation.play(character, "OK_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1, -3.4), Duration = 0.3 })
	VFXLib.sound(sounds.Swing, root, 0.55, 0.95 + index * 0.05)
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and pal.Main or pal.Second, index == 4 and 1.4 or 1)
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "Erase" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "OKErase")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(1.2, 1.6, -2.4), Duration = (data.Windup or 0.35) + 0.4 })
		elseif phase == "Swipe" and data.CFrame then
			local size = data.Size or Vector3.new(8, 6, 7)
			palmSweep(data.CFrame, size.X)
			rip(data.CFrame * CFrame.Angles(0, 0, math.rad(-20)), size.X * 0.9, size.Y * 0.9, 0.6)
			gaoon(data.CFrame.Position + Vector3.new(0, 2.5, 0), data.Hit)
			VFXLib.sound(sounds.Swing, data.CFrame.Position, 0.8, 0.6)
			if data.Hit then
				CameraFX.shakeAt(data.CFrame.Position, 0.6, 40)
			end
		end
	elseif move == "ErasePull" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "OKPull")
			TuskStand.action(character, "Lunge", { Target = CFrame.new(1.2, 1.6, -2.4), Duration = (data.Windup or 0.3) + 0.4 })
		elseif phase == "Pull" and data.From and data.To then
			afterimage(data.Target, data.From)
			streak(data.From, data.To)
			gaoon(data.To + Vector3.new(0, 2, 0), true)
			if root then
				rip(CFrame.lookAt(root.Position + root.CFrame.LookVector * 2, root.Position + root.CFrame.LookVector * 4), 3, 5, 0.4)
			end
			VFXLib.sound(sounds.Swing, data.To, 0.8, 0.55)
			if typeof(data.Target) == "Instance" and data.Target == (localPlayer and localPlayer.Character) then
				CameraFX.fovPunch(14, 0.35)
			end
		elseif phase == "Miss" and data.From and data.To then
			streak(data.From, data.To)
			gaoon(data.From + Vector3.new(0, 3, 0), false)
		end
	elseif move == "EraseDash" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "OKDash")
		elseif phase == "Step" and data.From and data.To then
			afterimage(character, data.From)
			streak(data.From, data.To)
			rip(CFrame.lookAt(data.From, data.To) * CFrame.new(0, 0, -1.5), 2.5, 5, 0.35)
			gaoon(data.From + Vector3.new(0, 2.5, 0), false)
			if character and Common.isLocal(character) then
				CameraFX.speedLines(0.25, BLUE)
			end
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character and root then
		TuskAnimation.play(character, "OKUlt")
		TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 1.4, -3), Duration = (data.Windup or 0.6) + (data.Swipes or 6) * (data.Gap or 0.24) + 0.2 })
		label(character:FindFirstChild("Head"), "ZA HANDO!", GOLD, 1.8, 320)
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 1.0)
		if Common.isLocal(character) then
			CameraFX.speedLines((data.Windup or 0.6) + (data.Swipes or 6) * (data.Gap or 0.24), BLUE)
		end
	elseif data.Phase == "Swipe" and data.CFrame then
		local size = data.Size or Vector3.new(14, 7, 14)
		local tilt = (data.Index or 1) % 2 == 0 and 25 or -25
		palmSweep(data.CFrame, size.X * 0.8)
		rip(data.CFrame * CFrame.Angles(0, 0, math.rad(tilt)), size.X * (data.Last and 1.0 or 0.6), size.Y * (data.Last and 1.2 or 0.8), data.Last and 0.9 or 0.45)
		gaoon(data.CFrame.Position + Vector3.new((math.random() - 0.5) * 4, 2.5, 0), data.Last)
		if data.Last then
			TuskVFX.CreateRotationalShockwave(data.CFrame * CFrame.Angles(math.pi / 2, 0, 0), { Radius = 10, Layers = 3, Color = BLUE, Color2 = GOLD, Particles = 1, Width = 0.6 })
			CameraFX.shakeAt(data.CFrame.Position, 1.0, 60)
			if character and Common.isLocal(character) then
				CameraFX.impactFrame(pal.Light)
			end
		else
			CameraFX.shakeAt(data.CFrame.Position, 0.3, 40)
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
				TuskAnimation.hold(character, "OKStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				TuskAnimation.stopHold(character, "OKStance")
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function OkuyasuVFX.handle(name, data)
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
function OkuyasuVFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
	end
end

return OkuyasuVFX
```
