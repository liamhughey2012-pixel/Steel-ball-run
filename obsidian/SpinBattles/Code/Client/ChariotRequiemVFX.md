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

**What it does:** Client visuals for SILVER CHARIOT REQUIEM (Polnareff after the Requiem Arrow, Act 24). Dark, slow and strange: Chariot Requiem (ChariotRequiemStand) looms behind him, a dark wraith with a pale mask, with a violet aura REQUIEM STRIKES: heavy dark slashes edged in gold SOUL SWAP: two pale souls cross between him and the target as they swap places; a flash at both ends REQUIEM'S SLEEP: a violet mist spreads out round him; sleepers get a drifting "Z z z" (and if it's you, the screen goes dark) SHADOW STEP: a dark afterimage left behind, a trail of black smoke SOUL REVERSAL: everyone's soul (a pale see-through copy of them) rises out of them and hangs there, then slams back down THE TRANSFORMATION (a cutscene, when YOU take the Requiem Arrow as Polnareff, about 8.2 s, skippable; TuskConfig.Cutscenes.ChariotRequiem): 1. wide: Polnareff and Silver Chariot, rapier up; daylight fading 2. close on Silver Chariot's chest: the arrow strikes ("ズキュゥゥン") 3. its silver armour shatters off it and a whirl of black shadow rises, violet lightning; night falls (the sky really goes dark) 4. tilting up Chariot Requiem from its boots to its hat, as pale souls start to slip loose ("THE STAND HAS GONE BEYOND ITSELF") 5. low and wide: Requiem towers over Polnareff, collapsed on his knees, souls drifting round them: "SILVER CHARIOT REQUIEM" Anyone else near sees the shadow rise and darkness pulse out.

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
	  * THE TRANSFORMATION (a cutscene, when YOU take the Requiem Arrow as
	    Polnareff, about 8.2 s, skippable; TuskConfig.Cutscenes.ChariotRequiem):
	      1. wide: Polnareff and Silver Chariot, rapier up; daylight fading
	      2. close on Silver Chariot's chest: the arrow strikes ("ズキュゥゥン")
	      3. its silver armour shatters off it and a whirl of black shadow
	         rises, violet lightning; night falls (the sky really goes dark)
	      4. tilting up Chariot Requiem from its boots to its hat, as pale
	         souls start to slip loose ("THE STAND HAS GONE BEYOND ITSELF")
	      5. low and wide: Requiem towers over Polnareff, collapsed on his
	         knees, souls drifting round them: "SILVER CHARIOT REQUIEM"
	    Anyone else near sees the shadow rise and darkness pulse out.
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
local Net = require(Shared.Net)
local Cutscenes = require(script.Parent.Parent.Cutscenes)

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
-- THE TRANSFORMATION (cutscene)
---------------------------------------------------------------------------
local lastCutscene -- os.clock() of the last one (nil: never)

local function standModel(character)
	local stand = TuskStand.get(character)
	return stand and stand.Model and stand.Model.Parent and stand.Model or nil
end

local function standAt(character)
	local model = standModel(character)
	if model then
		local ok, cf = pcall(function()
			return model:GetPivot()
		end)
		if ok and cf then
			return cf
		end
	end
	local root = Common.rootOf(character)
	return root and root.CFrame * ChariotRequiemStand.Offset or CFrame.new()
end

local function bolt(a, b, color)
	local points = { a }
	for k = 1, 5 do
		points[k + 1] = a:Lerp(b, k / 6) + Vector3.new((math.random() - 0.5) * 1.4, (math.random() - 0.5) * 1.4, (math.random() - 0.5) * 1.4)
	end
	points[7] = b
	for k = 1, 6 do
		local p0, p1 = points[k], points[k + 1]
		local seg = VFXLib.part({ Size = Vector3.new(0.12, 0.12, (p1 - p0).Magnitude + 0.1), CFrame = CFrame.lookAt((p0 + p1) / 2, p1), Color = color or VIOLET, Material = Enum.Material.Neon })
		VFXLib.animate(0.12, function(x)
			seg.Transparency = x
		end, function()
			seg:Destroy()
		end)
	end
end

-- The arrow streaking down into Silver Chariot.
local function flyingArrow(from, getTo, time, onHit)
	local head = VFXLib.part({ Size = Vector3.new(0.8, 0.8, 0.2), Color = GOLD, Material = Enum.Material.Metal })
	local shaft = VFXLib.part({ Size = Vector3.new(0.16, 0.16, 2.4), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood })
	local trail = VFXLib.part({ Size = Vector3.new(0.28, 0.28, 6), Color = VIOLET, Material = Enum.Material.Neon, Transparency = 0.4 })
	VFXLib.animate(time, function(a)
		local to = getTo()
		local p = from:Lerp(to, a * a)
		local cf = CFrame.lookAt(p, p + (to - from).Unit)
		head.CFrame = cf * CFrame.Angles(0, 0, math.pi / 4)
		shaft.CFrame = cf * CFrame.new(0, 0, 1.3)
		trail.CFrame = cf * CFrame.new(0, 0, 4)
	end, function()
		head:Destroy()
		shaft:Destroy()
		trail:Destroy()
		if onHit then
			onHit()
		end
	end)
end

-- Silver plates bursting off the Stand.
local function shatter(at)
	for _ = 1, 22 do
		local plate = VFXLib.part({ Size = Vector3.new(0.3 + math.random() * 0.5, 0.06, 0.3 + math.random() * 0.4), Color = math.random() < 0.5 and Color3.fromRGB(214, 222, 236) or Color3.fromRGB(170, 180, 200), Material = Enum.Material.Metal, CFrame = CFrame.new(at) })
		local v = Vector3.new(math.random() - 0.5, math.random() * 0.9, math.random() - 0.5).Unit * (12 + math.random() * 12)
		local spin = Vector3.new(math.random() * 12, math.random() * 12, math.random() * 12)
		VFXLib.animate(1.1, function(a)
			local t = a * 1.1
			plate.CFrame = CFrame.new(at + v * t + Vector3.new(0, -18 * t * t, 0)) * CFrame.Angles(spin.X * t, spin.Y * t, spin.Z * t)
			plate.Transparency = math.max(0, a * 1.4 - 0.4)
		end, function()
			plate:Destroy()
		end)
	end
end

-- A whirl of black shadow rising round a point, for `time`.
local function shadowWhirl(getAt, time, height)
	height = height or 14
	local puffs = {}
	for k = 1, 26 do
		local p = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1) * (1 + math.random() * 1.4), Color = k % 4 == 0 and DARK:Lerp(VIOLET, 0.4) or DARK, Material = Enum.Material.SmoothPlastic, Transparency = 1 })
		p.Shape = Enum.PartType.Ball
		puffs[k] = { Part = p, A = math.random() * math.pi * 2, Y = math.random(), R = 1.4 + math.random() * 1.6, Speed = 2 + math.random() * 2 }
	end
	local nextBolt = 0
	VFXLib.animate(time, function(a)
		local at = getAt()
		local swell = a < 0.15 and a / 0.15 or (a > 0.85 and (1 - a) / 0.15 or 1)
		for _, e in ipairs(puffs) do
			e.A = e.A + 0.12 * e.Speed
			e.Y = (e.Y + 0.012 * e.Speed) % 1
			local r = e.R * (0.6 + e.Y * 0.8)
			e.Part.CFrame = CFrame.new(at + Vector3.new(math.cos(e.A) * r, -3 + e.Y * height, math.sin(e.A) * r))
			e.Part.Transparency = 1 - swell * (0.75 - e.Y * 0.5)
		end
		local c = os.clock()
		if c >= nextBolt then
			nextBolt = c + 0.09
			local a0 = math.random() * math.pi * 2
			bolt(at + Vector3.new(math.cos(a0) * 1.5, math.random() * 8 - 2, math.sin(a0) * 1.5), at + Vector3.new(math.cos(a0 + 1.2) * 5, math.random() * 10 - 2, math.sin(a0 + 1.2) * 5), math.random() < 0.7 and VIOLET or SOUL)
		end
	end, function()
		for _, e in ipairs(puffs) do
			e.Part:Destroy()
		end
	end)
end

-- Pale souls slipping loose and drifting round a point.
local function looseSouls(getAt, time, count)
	for k = 1, count do
		local wisp = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 1.1, 0.7), Color = SOUL, Material = Enum.Material.Neon, Transparency = 1 })
		wisp.Shape = Enum.PartType.Ball
		local tail = VFXLib.part({ Size = Vector3.new(0.25, 0.25, 1.6), Color = SOUL, Material = Enum.Material.Neon, Transparency = 1 })
		local a0, r, h = k / count * math.pi * 2, 4 + math.random() * 4, math.random() * 3
		local delay0 = math.random() * 0.6
		VFXLib.animate(time, function(a)
			local t = a * time - delay0
			if t < 0 then
				return
			end
			local at = getAt()
			local ang = a0 + t * 0.8
			local p = at + Vector3.new(math.cos(ang) * r, -1 + h + t * 0.5 + math.sin(t * 3 + k) * 0.4, math.sin(ang) * r)
			local tangent = Vector3.new(-math.sin(ang), 0, math.cos(ang))
			wisp.CFrame = CFrame.new(p)
			tail.CFrame = CFrame.lookAt(p - tangent * 0.8, p)
			local fade = math.min(1, t / 0.4) * (a > 0.85 and (1 - a) / 0.15 or 1)
			wisp.Transparency = 1 - 0.6 * fade
			tail.Transparency = 1 - 0.4 * fade
		end, function()
			wisp:Destroy()
			tail:Destroy()
		end)
	end
end

-- Words across the bottom of the screen.
local function screenLine(richText, time)
	local pg = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "RequiemLine"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 30
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.AnchorPoint = Vector2.new(0.5, 1)
	tl.Position = UDim2.fromScale(0.5, 0.86)
	tl.Size = UDim2.fromScale(0.8, 0.1)
	tl.Font = Enum.Font.GothamBlack
	tl.RichText = true
	tl.TextScaled = true
	tl.Text = richText
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.TextStrokeColor3 = Color3.fromRGB(20, 10, 40)
	tl.TextStrokeTransparency = 0.2
	tl.TextTransparency = 1
	tl.Parent = gui
	gui.Parent = pg
	VFXLib.animate(time, function(a)
		local fade = a < 0.12 and 1 - a / 0.12 or (a > 0.85 and (a - 0.85) / 0.15 or 0)
		tl.TextTransparency = fade
		tl.TextStrokeTransparency = 0.2 + 0.8 * fade
	end, function()
		gui:Destroy()
	end)
end

-- Night falls (on this screen only), then the day comes back.
local function nightFall(time, total)
	local lighting = game:GetService("Lighting")
	local saved = { Brightness = lighting.Brightness }
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "RequiemNight"
	cc.Parent = lighting
	VFXLib.animate(total, function(a)
		local t = a * total
		local k = math.clamp(t / time, 0, 1)
		local back = t > total - 0.5 and (t - (total - 0.5)) / 0.5 or 0
		local dark = VFXLib.easeInOut(k) * (1 - back)
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(150, 140, 220), dark)
		cc.Brightness = -0.28 * dark
		cc.Saturation = -0.45 * dark
		cc.Contrast = 0.2 * dark
		pcall(function()
			lighting.Brightness = saved.Brightness * (1 - 0.7 * dark)
		end)
	end, function()
		cc:Destroy()
		pcall(function()
			lighting.Brightness = saved.Brightness
		end)
	end)
	return cc
end

local function playRequiemCutscene(character)
	local cc = TuskConfig.Cutscenes or {}
	if cc.Enabled == false or cc.ChariotRequiem == false or (lastCutscene and os.clock() - lastCutscene < 20) then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if not root or not head then
		return false
	end
	lastCutscene = os.clock()
	TuskAnimation.play(character, "PNRequiem")
	local ended = false
	local up = Vector3.new(0, 1, 0)
	local function rel(x, y, z)
		return (root.CFrame * CFrame.new(x, y, z)).Position
	end
	local function chest()
		return (standAt(character) * CFrame.new(0, 0.4, -0.5)).Position
	end
	local function standBase()
		return (standAt(character) * CFrame.new(0, -2.6, 0)).Position
	end
	local function standTop()
		return (standAt(character) * CFrame.new(0, 2.6, 0)).Position
	end
	local T = { 1.2, 1.0, 1.8, 2.2, 2.0 }
	local starts, acc = {}, 0
	for i, d in ipairs(T) do
		starts[i] = acc
		acc = acc + d
	end
	local fwd = function()
		return root.CFrame.LookVector
	end
	local side = function()
		return root.CFrame.RightVector
	end
	local shots = {
		-- 1. Wide from in front: Polnareff and Silver Chariot; daylight fading.
		{ From = function()
			return root.Parent and CFrame.lookAt(rel(-3, 1, -13), rel(1, 2, 1)) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(rel(-2.5, 0.8, -11.5), rel(1, 2.2, 1)) or nil
		end, Time = T[1], FOV = { 55, 50 }, Title = "THE REQUIEM ARROW", Subtitle = "JEAN PIERRE POLNAREFF", Color = Color3.fromRGB(200, 180, 255) },
		-- 2. Close on Silver Chariot's chest as the arrow goes in.
		{ From = function()
			local c = chest()
			return root.Parent and CFrame.lookAt(c + fwd() * 5 + up * 0.5 + side() * 0.6, c) or nil
		end, To = function()
			local c = chest()
			return root.Parent and CFrame.lookAt(c + fwd() * 3.4 + up * 0.3 + side() * 0.4, c) or nil
		end, Time = T[2], FOV = { 40, 34 } },
		-- 3. Pulling back: the armour shatters, the shadow rises, night falls.
		{ From = function()
			local c = chest()
			return root.Parent and CFrame.lookAt(c + fwd() * 6 + side() * 3 + up * 0.5, c + up * 1.5) or nil
		end, To = function()
			local c = chest()
			return root.Parent and CFrame.lookAt(c + fwd() * 13 + side() * 6 + up * 3, c + up * 3) or nil
		end, Time = T[3], FOV = { 50, 62 } },
		-- 4. Tilting up Chariot Requiem, from its boots to its hat.
		{ From = function()
			local b = standBase()
			return root.Parent and CFrame.lookAt(b + fwd() * 4.5 + up * 0.4, b + up * 0.8) or nil
		end, To = function()
			local tp = standTop()
			return root.Parent and CFrame.lookAt(standBase() + fwd() * 4.5 + up * 0.4, tp) or nil
		end, Time = T[4], FOV = { 46, 46 }, Linear = true },
		-- 5. Low and wide: Requiem towers over him, collapsed on his knees.
		{ From = function()
			return root.Parent and CFrame.lookAt(rel(2, -2, -9), rel(1, 3, 1)) or nil
		end, To = function()
			return root.Parent and CFrame.lookAt(rel(3, -2.3, -11), rel(1, 4, 1)) or nil
		end, Time = T[5], FOV = { 58, 64 }, Title = "SILVER CHARIOT REQUIEM", Subtitle = "UNTIL YOU GO DOWN", Color = Color3.fromRGB(190, 160, 255) },
	}
	local night
	local started = Cutscenes.play(shots, { Priority = 3, Skippable = true, OnEnd = function()
		ended = true
		if night and night.Parent then
			night:Destroy()
		end
	end })
	if not started then
		return false
	end
	night = nightFall(starts[4], acc + 0.6)
	VFXLib.sound(sounds.AwakeningBuild, root, 0.6, 0.6)
	local function at(time, fn)
		task.delay(time, function()
			if not ended then
				fn()
			end
		end)
	end
	-- 1-2. The arrow out of the sky into Silver Chariot's chest.
	at(0.3, function()
		flyingArrow(rel(-12, 40, -24), chest, starts[2] + 0.45 - 0.3, function()
			if ended then
				return
			end
			local c = chest()
			local anchor = VFXLib.part({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(c), Transparency = 1 })
			label(anchor, "ズキュゥゥン", VIOLET, 1.2, 320, Vector3.new(-1.5, 1.5, 0))
			task.delay(1.3, function()
				anchor:Destroy()
			end)
			TuskVFX.CreateImpactStar(c, { Size = 6, Rays = 12, Color = VIOLET, Color2 = Color3.new(1, 1, 1), Duration = 0.3 })
			CameraFX.impactFrame(Color3.fromRGB(200, 180, 255))
			CameraFX.shake(0.8, 0.4)
			VFXLib.sound(sounds.AwakeningBurst or sounds.Swing, root, 0.8, 0.9)
		end)
	end)
	-- 3. The armour shatters; the shadow whirls up (the Stand changes in it).
	at(starts[3], function()
		shatter(chest())
		shadowWhirl(function()
			return standAt(character).Position
		end, T[3] + 0.6, 14)
		CameraFX.shake(0.5, 0.6)
	end)
	-- 4. The souls start slipping loose.
	at(starts[4], function()
		looseSouls(function()
			return root.Position
		end, T[4] + T[5], 8)
		screenLine('THE STAND HAS GONE <font color="#C8B4FF">BEYOND ITSELF</font>', T[4])
	end)
	-- 5. Requiem towers: a ring of darkness rolls out.
	at(starts[5], function()
		TuskVFX.CreateRotationalShockwave(CFrame.new(root.Position - Vector3.new(0, 2.8, 0)), { Radius = 22, Layers = 3, Color = VIOLET, Color2 = DARK, Ground = true, Particles = 2, Width = 0.6 })
		CameraFX.shake(0.5, 0.5)
	end)
	return true
end
ChariotRequiemVFX.playRequiemCutscene = playRequiemCutscene

-- The arrow (WorldFX "RequiemArrow"): your own cutscene, or (anyone else
-- near) the shadow rising and the dark pulsing out.
local function onArrow(data)
	if data.Phase ~= "Requiem" or data.Who ~= "Polnareff" or typeof(data.Character) ~= "Instance" then
		return
	end
	local character = data.Character
	if data.Player == (localPlayer and localPlayer.UserId) and playRequiemCutscene(character) then
		return
	end
	task.delay(1.0, function()
		if character.Parent then
			shadowWhirl(function()
				return standAt(character).Position
			end, 2, 12)
			local r = Common.rootOf(character)
			if r and nearLocal(r.Position, 60) then
				TuskVFX.ScreenTint(1.4, { Tint = Color3.fromRGB(150, 130, 220), Brightness = -0.2, Saturation = -0.4, Contrast = 0.2, Release = 0.2, FadeOut = 0.6 })
			end
		end
	end)
end
ChariotRequiemVFX.onArrow = onArrow
pcall(function()
	Net.get("WorldFX").OnClientEvent:Connect(function(name, data)
		if name == "RequiemArrow" and typeof(data) == "table" then
			onArrow(data)
		end
	end)
end)

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
