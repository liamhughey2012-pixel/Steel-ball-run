---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX"
updated: 2026-11-22
---
# ChariotRequiemVFX

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX` |
| **Exact name** | `ChariotRequiemVFX` (capitals matter) |

**What it does:** Client visuals for SILVER CHARIOT REQUIEM (Polnareff after the Requiem Arrow, Act 24). Dark, slow and strange: Chariot Requiem (ChariotRequiemStand) looms behind him, a dark wraith with a pale mask, with a violet aura REQUIEM STRIKES: heavy dark slashes edged in gold SOUL SWAP: two pale souls cross between him and the target as they swap places; a flash at both ends REQUIEM'S SLEEP: a violet mist spreads out round him; sleepers get a drifting "Z z z" (and if it's you, the screen goes dark) SHADOW STEP: a dark afterimage left behind, a trail of black smoke SOUL REVERSAL: everyone's soul (a pale see-through copy of them) rises out of them and hangs there, then slams back down

## How to add it
1. In Studio's Explorer, find **TuskActVFX** (StarterPlayer › StarterPlayerScripts › SpinClient › TuskActVFX).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **ChariotRequiemVFX**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActVFX.ChariotRequiemVFX  (StarterPlayerScripts.SpinClient.TuskActVFX.ChariotRequiemVFX)

	Client visuals for SILVER CHARIOT REQUIEM (Polnareff after the Requiem
	Arrow, Act 24). Dark, slow and strange:
	  * Chariot Requiem (ChariotRequiemStand) looms behind him, a dark
	    wraith with a pale mask, with a violet aura
	  * REQUIEM STRIKES: heavy dark slashes edged in gold
	  * SOUL SWAP: two pale souls cross between him and the target as they
	    swap places; a flash at both ends
	  * REQUIEM'S SLEEP: a violet mist spreads out round him; sleepers get
	    a drifting "Z z z" (and if it's you, the screen goes dark)
	  * SHADOW STEP: a dark afterimage left behind, a trail of black smoke
	  * SOUL REVERSAL: everyone's soul (a pale see-through copy of them)
	    rises out of them and hangs there, then slams back down
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
local ChariotRequiemStand = require(script.Parent.ChariotRequiemStand)

local ChariotRequiemVFX = {}
local ACT = 24
local pal = Common.palette(ACT)
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

TuskStandModels.register(ACT, ChariotRequiemStand.build, { Aura = ChariotRequiemStand.Aura, AuraLight = ChariotRequiemStand.AuraLight, Offset = ChariotRequiemStand.Offset })

local DARK = Color3.fromRGB(40, 30, 60)
local VIOLET = Color3.fromRGB(150, 100, 230)
local GOLD = Color3.fromRGB(240, 200, 90)
local SOUL = Color3.fromRGB(210, 230, 255)

local stanced = {}
local souls = {} -- [character] = { parts } the ultimate's lifted souls

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
local function nearLocal(pos, range)
	local r = localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	return r ~= nil and (r.Position - pos).Magnitude <= range
end

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

-- A heavy dark slash: a wide dark blade-streak with a gold edge.
local function slash(root, side)
	local arc = VFXLib.part({ Size = Vector3.new(6, 0.3, 1.2), Color = DARK, Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
	local edge = VFXLib.part({ Size = Vector3.new(6, 0.08, 0.2), Color = GOLD, Transparency = 0.2 })
	local base = root.CFrame * CFrame.new(0, 0.8, -3.2) * CFrame.Angles(0, 0, side * 0.6)
	VFXLib.animate(0.22, function(a)
		local cf = base * CFrame.Angles(0, side * (-0.9 + a * 1.8), 0)
		arc.CFrame = cf
		edge.CFrame = cf * CFrame.new(0, 0.15, -0.55)
		arc.Transparency = 0.15 + 0.85 * a
		edge.Transparency = 0.2 + 0.8 * a
	end, function()
		arc:Destroy()
		edge:Destroy()
	end)
end

-- A pale see-through copy of someone (their soul).
local function soulOf(character)
	local parts = {}
	for _, d in ipairs(character:GetChildren()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
			table.insert(parts, { Part = VFXLib.part({ Size = d.Size, CFrame = d.CFrame, Color = SOUL, Material = Enum.Material.Neon, Transparency = 0.55 }), Offset = d.CFrame })
		end
	end
	return parts
end

local function orb(from, to, time, color)
	local o = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1), Color = color or SOUL, Transparency = 0.2 })
	VFXLib.animate(time, function(a)
		local p = from:Lerp(to, VFXLib.easeInOut(a)) + Vector3.new(0, math.sin(a * math.pi) * 4, 0)
		o.CFrame = CFrame.new(p)
		VFXLib.burst(p, { Count = 1, Color = color or SOUL, Speed = 2, Lifetime = 0.3 })
	end, function()
		o:Destroy()
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
	TuskAnimation.play(character, "PN_M1_" .. math.clamp(index, 1, 4))
	TuskStand.action(character, "Lunge", { Target = CFrame.new(index % 2 == 0 and -0.8 or 0.8, 1.2, -3.8), Duration = 0.34 })
	VFXLib.sound(sounds.Swing, root, 0.5, 0.7)
	task.delay(0.08, function()
		local r = Common.rootOf(character)
		if r then
			slash(r, index % 2 == 1 and 1 or -1)
		end
	end)
end

local function onFinisher(data)
	Common.finisher(data, pal)
end

local function onAbility(data)
	local character = data.Character
	local root = Common.rootOf(character)
	local move, phase = data.Move, data.Phase
	if move == "SoulSwap" then
		if phase == "Reach" and character and root then
			TuskAnimation.play(character, "PNPoint")
			TuskStand.action(character, "Loom", { Target = CFrame.new(1.6, 3, 2.6), Duration = (data.Windup or 0.35) + 0.4 })
			local tr = data.Target and Common.rootOf(data.Target)
			if tr then
				VFXLib.burst(tr.Position, { Count = 10, Color = SOUL, Speed = 4, Lifetime = 0.5 })
			end
		elseif phase == "Swap" and data.A and data.B then
			orb(data.A, data.B, 0.4, SOUL)
			orb(data.B, data.A, 0.4, VIOLET)
			for _, p in ipairs({ data.A, data.B }) do
				VFXLib.flash(p, VIOLET, 4, 14, 0.2)
				TuskVFX.CreateImpactStar(p, { Size = 3, Rays = 6, Color = SOUL, Color2 = VIOLET, Duration = 0.15 })
			end
			if data.Target then
				label(data.Target:FindFirstChild("Head"), "SOULS SWAPPED", SOUL, 1.4, 240)
			end
			if (character and Common.isLocal(character)) or (data.Target and Common.isLocal(data.Target)) then
				CameraFX.impactFrame(Color3.fromRGB(200, 180, 255))
				CameraFX.fovPunch(-10, 0.4)
			end
		end
	elseif move == "Sleep" then
		if phase == "Wind" and character and root then
			TuskAnimation.play(character, "PNArmorOff")
			TuskStand.action(character, "Loom", { Target = CFrame.new(0, 4, 2.6), Duration = (data.Windup or 0.5) + 0.6 })
			label(character:FindFirstChild("Head"), "REQUIEM", VIOLET, 1.2, 240)
		elseif phase == "Sleep" and data.Position then
			local mist = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(data.Position), Color = VIOLET, Material = Enum.Material.ForceField, Transparency = 0.4 })
			VFXLib.animate(1.0, function(a)
				local d = (data.Radius or 26) * 2 * VFXLib.easeOut(math.min(a * 1.6, 1))
				mist.Size = Vector3.new(d, d * 0.5, d)
				mist.Transparency = 0.4 + 0.6 * a
			end, function()
				mist:Destroy()
			end)
			local time = data.Time or 2.2
			for _, t in ipairs(data.Targets or {}) do
				local head = t:FindFirstChild("Head")
				for k = 0, 2 do
					task.delay(k * (time / 3), function()
						label(head, "Z z z", Color3.fromRGB(200, 190, 255), time / 3 + 0.2, 140)
					end)
				end
				if Common.isLocal(t) then
					TuskVFX.ScreenTint(time, { Tint = Color3.fromRGB(120, 100, 170), Brightness = -0.35, Saturation = -0.5, Contrast = 0.1, Release = 0, FadeOut = 0.4 })
				end
			end
		end
	elseif move == "ShadowStep" and phase == "Step" and data.From and data.To then
		local ghost = VFXLib.part({ Size = Vector3.new(2, 5, 1), CFrame = CFrame.new(data.From), Color = DARK, Material = Enum.Material.SmoothPlastic, Transparency = 0.3 })
		VFXLib.animate(0.5, function(a)
			ghost.Transparency = 0.3 + 0.7 * a
		end, function()
			ghost:Destroy()
		end)
		for k = 0, 8 do
			local p = data.From:Lerp(data.To, k / 8)
			VFXLib.burst(p - Vector3.new(0, 1.5, 0), { Count = 3, Color = DARK, Speed = 3, Lifetime = 0.6 })
		end
		if character and Common.isLocal(character) then
			CameraFX.speedLines(0.25, VIOLET)
		end
	end
end

---------------------------------------------------------------------------
-- SOUL REVERSAL
---------------------------------------------------------------------------
local function dropSouls(character)
	local list = souls[character]
	souls[character] = nil
	for _, s in ipairs(list or {}) do
		VFXLib.cancel(s.Job)
		for _, p in ipairs(s.Parts) do
			p.Part:Destroy()
		end
	end
end

local function onUltimate(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if data.Phase == "Call" and character and root then
		TuskAnimation.play(character, "PNArmorOff")
		TuskStand.action(character, "Loom", { Target = CFrame.new(0, 5, 3), Duration = (data.Windup or 0.8) + 0.8 })
		label(character:FindFirstChild("Head"), "SILVER CHARIOT REQUIEM", VIOLET, 2.0, 380)
		if nearLocal(root.Position, 50) then
			TuskVFX.ScreenTint(1.2, { Tint = Color3.fromRGB(150, 120, 210), Brightness = -0.2, Saturation = -0.4, Contrast = 0.2, Release = 0.1, FadeOut = 0.5 })
		end
		VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 0.7)
	elseif data.Phase == "Souls" and character then
		dropSouls(character)
		local list = {}
		souls[character] = list
		local time = (data.Time or 2.2) + 0.2
		for i, t in ipairs(data.Targets or {}) do
			local tr = Common.rootOf(t)
			if tr then
				local parts = soulOf(t)
				local base = tr.CFrame
				local entry = { Parts = parts }
				entry.Job = VFXLib.animate(time, function(a)
					local lift = math.min(a * time / 0.5, 1) * 4
					local bob = math.sin(os.clock() * 3 + i) * 0.3
					local spin = CFrame.Angles(0, os.clock() * 0.8, 0)
					for _, p in ipairs(parts) do
						local rel = base:Inverse() * p.Offset
						p.Part.CFrame = CFrame.new(base.Position + Vector3.new(0, lift + bob, 0)) * spin * (base - base.Position) * rel
					end
				end)
				table.insert(list, entry)
				-- A thin cord from body to soul.
				VFXLib.burst(tr.Position, { Count = 12, Color = SOUL, Speed = 6, Lifetime = 0.6 })
			end
		end
	elseif data.Phase == "Return" and character then
		local list = souls[character]
		souls[character] = nil
		for _, s in ipairs(list or {}) do
			VFXLib.cancel(s.Job)
			local start = {}
			for _, p in ipairs(s.Parts) do
				start[p] = p.Part.CFrame
			end
			VFXLib.animate(0.18, function(a)
				for _, p in ipairs(s.Parts) do
					p.Part.CFrame = start[p]:Lerp(p.Offset, a)
					p.Part.Transparency = 0.55 + 0.45 * a
				end
			end, function()
				for _, p in ipairs(s.Parts) do
					p.Part:Destroy()
				end
			end)
		end
		for _, t in ipairs(data.Targets or {}) do
			local tr = Common.rootOf(t)
			if tr then
				task.delay(0.18, function()
					TuskVFX.CreateImpactStar(tr.Position, { Size = 4, Rays = 8, Color = SOUL, Color2 = VIOLET, Duration = 0.2 })
				end)
			end
			if Common.isLocal(t) then
				CameraFX.shake(0.6, 0.3)
				CameraFX.impactFrame(SOUL)
			end
		end
	elseif data.Phase == "End" and character then
		dropSouls(character)
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
				TuskAnimation.hold(character, "PNStance")
			elseif not want and stanced[character] then
				stanced[character] = nil
				-- (Polnareff's own stance takes over again if he's back to Silver Chariot.)
				if character:GetAttribute("TuskAct") ~= 23 then
					TuskAnimation.stopHold(character, "PNStance")
				end
			end
		end
	end
	for character in pairs(stanced) do
		if not character.Parent then
			stanced[character] = nil
		end
	end
end

function ChariotRequiemVFX.handle(name, data)
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
function ChariotRequiemVFX.step(dt)
	dt = dt or 1 / 60
	slowTimer = slowTimer + dt
	if slowTimer > 0.1 then
		slowTimer = 0
		stepStance()
	end
end

return ChariotRequiemVFX
```
