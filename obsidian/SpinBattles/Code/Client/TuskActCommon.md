---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient"
updated: 2026-11-22
---
# TuskActCommon

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| **Exact name** | `TuskActCommon` (capitals matter) |

**What it does:** Shared client choreography used by every Act's visual module: Palette(act)          each Act's colour identity m1(data, palette)     poses, Stand lunges, swipes, mini-portals finisher(data, pal)   combo-ender shockwave portal(...)           wormhole that opens, holds and collapses golden(...)           golden rectangle + spiral (Act 2), same arguments portalNail(...)       portals for nails fired through them evolve(data)          the "next Act" transformation + banner charge helpers        attribute-driven hold charges

## How to add it
1. In Studio's Explorer, find **SpinClient** (StarterPlayer › StarterPlayerScripts › SpinClient).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **TuskActCommon**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskActCommon  (StarterPlayerScripts.SpinClient.TuskActCommon)

	Shared client choreography used by every Act's visual module:
	  Palette(act)          each Act's colour identity
	  m1(data, palette)     poses, Stand lunges, swipes, mini-portals
	  finisher(data, pal)   combo-ender shockwave
	  portal(...)           wormhole that opens, holds and collapses
	  golden(...)           golden rectangle + spiral (Act 2), same arguments
	  portalNail(...)       portals for nails fired through them
	  evolve(data)          the "next Act" transformation + banner
	  charge helpers        attribute-driven hold charges
]]

local Players = game:GetService("Players")
local Fighters = require(script.Parent.Fighters)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local VFXLib = require(script.Parent.VFXLib)
local CameraFX = require(script.Parent.CameraFX)
local TuskVFX = require(script.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.TuskAnimation)
local TuskStand = require(script.Parent.TuskStand)

local Common = {}
local colors = TuskConfig.Colors
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

Common.Palettes = {
	[1] = { Main = colors.Cyan, Second = colors.Blue, Light = colors.Ice },
	[2] = { Main = Color3.fromRGB(80, 210, 255), Second = Color3.fromRGB(110, 70, 255), Light = colors.Ice },
	[3] = { Main = Color3.fromRGB(70, 130, 255), Second = Color3.fromRGB(30, 20, 120), Light = Color3.fromRGB(190, 210, 255) },
	[4] = { Main = colors.Gold, Second = colors.DeepBlue, Light = colors.GoldLight },
	[5] = { Main = Color3.fromRGB(120, 225, 95), Second = Color3.fromRGB(40, 120, 50), Light = Color3.fromRGB(225, 255, 205) }, -- Gyro
	[6] = { Main = Color3.fromRGB(80, 210, 220), Second = Color3.fromRGB(35, 60, 190), Light = Color3.fromRGB(215, 255, 250) }, -- Diego
	[7] = { Main = Color3.fromRGB(165, 215, 80), Second = Color3.fromRGB(95, 105, 125), Light = Color3.fromRGB(225, 232, 245) }, -- Pork Pie Hat Kid (bamboo green + steel)
	[8] = { Main = Color3.fromRGB(245, 185, 80), Second = Color3.fromRGB(50, 140, 160), Light = Color3.fromRGB(255, 240, 205) }, -- Sandman (sand + turquoise)
	[9] = { Main = Color3.fromRGB(214, 156, 84), Second = Color3.fromRGB(96, 62, 38), Light = Color3.fromRGB(255, 232, 196) }, -- Mountain Tim (leather + rope)
	[10] = { Main = Color3.fromRGB(242, 140, 172), Second = Color3.fromRGB(120, 60, 92), Light = Color3.fromRGB(255, 220, 230) }, -- Hot Pants (Cream Starter pink)
	[11] = { Main = Color3.fromRGB(110, 180, 255), Second = Color3.fromRGB(40, 50, 90), Light = Color3.fromRGB(225, 245, 255) }, -- Blackmore (rain blue)
	[12] = { Main = Color3.fromRGB(214, 60, 70), Second = Color3.fromRGB(226, 196, 110), Light = Color3.fromRGB(255, 200, 200) }, -- Axl RO (Civil War red)
	[13] = { Main = Color3.fromRGB(120, 170, 255), Second = Color3.fromRGB(236, 120, 170), Light = Color3.fromRGB(240, 246, 255) }, -- Funny Valentine (D4C blue + pink)
	[14] = { Main = Color3.fromRGB(236, 196, 70), Second = Color3.fromRGB(70, 170, 160), Light = Color3.fromRGB(255, 244, 200) }, -- Diego from another world (The World gold + teal)
	[15] = { Main = Color3.fromRGB(120, 190, 240), Second = Color3.fromRGB(240, 200, 90), Light = Color3.fromRGB(235, 248, 255) }, -- Josuke (Soft & Wet bubble blue + gold)
	[16] = { Main = Color3.fromRGB(150, 40, 50), Second = Color3.fromRGB(240, 196, 60), Light = Color3.fromRGB(255, 236, 200) }, -- Tooru (Wonder of U maroon + scarf gold)
	[17] = { Main = Color3.fromRGB(90, 170, 240), Second = Color3.fromRGB(240, 120, 190), Light = Color3.fromRGB(225, 240, 255) }, -- Jodio (November Rain blue + strap pink)
	[18] = { Main = Color3.fromRGB(220, 228, 240), Second = Color3.fromRGB(120, 200, 255), Light = Color3.fromRGB(255, 255, 255) }, -- John Rod (bright metal + blue)
	[24] = { Main = Color3.fromRGB(150, 110, 220), Second = Color3.fromRGB(240, 200, 90), Light = Color3.fromRGB(230, 220, 255) }, -- Silver Chariot Requiem
	[28] = { Main = Color3.fromRGB(120, 200, 130), Second = Color3.fromRGB(240, 226, 180), Light = Color3.fromRGB(240, 255, 236) }, -- Rohan (Heaven's Door green + paper)
	[33] = { Main = Color3.fromRGB(255, 236, 170), Second = Color3.fromRGB(236, 120, 170), Light = Color3.fromRGB(255, 252, 235) }, -- D4C -Love Train- (light + D4C pink)
	[32] = { Main = Color3.fromRGB(220, 50, 85), Second = Color3.fromRGB(235, 235, 245), Light = Color3.fromRGB(255, 215, 225) }, -- Diavolo (King Crimson crimson + white)
	[30] = { Main = Color3.fromRGB(245, 200, 70), Second = Color3.fromRGB(180, 90, 210), Light = Color3.fromRGB(255, 246, 210) }, -- Giorno (Gold Experience gold + purple)
	[31] = { Main = Color3.fromRGB(255, 222, 110), Second = Color3.fromRGB(150, 80, 230), Light = Color3.fromRGB(255, 250, 230) }, -- Gold Experience Requiem (bright gold + violet)
	[29] = { Main = Color3.fromRGB(120, 220, 95), Second = Color3.fromRGB(240, 196, 70), Light = Color3.fromRGB(230, 255, 210) }, -- Gyro with the Saint's Eyes (green + gold)
	[27] = { Main = Color3.fromRGB(100, 140, 230), Second = Color3.fromRGB(236, 190, 70), Light = Color3.fromRGB(220, 236, 255) }, -- Okuyasu (The Hand blue + gold)
	[26] = { Main = Color3.fromRGB(230, 150, 215), Second = Color3.fromRGB(120, 70, 150), Light = Color3.fromRGB(250, 228, 250) }, -- Kira (Killer Queen pink + dark purple)
	[25] = { Main = Color3.fromRGB(240, 120, 190), Second = Color3.fromRGB(150, 220, 240), Light = Color3.fromRGB(255, 226, 242) }, -- Josuke (Part 4: Crazy Diamond pink + pale blue)
	[23] = { Main = Color3.fromRGB(196, 206, 222), Second = Color3.fromRGB(110, 170, 230), Light = Color3.fromRGB(240, 246, 255) }, -- Polnareff (Silver Chariot)
	[22] = { Main = Color3.fromRGB(150, 80, 200), Second = Color3.fromRGB(255, 214, 80), Light = Color3.fromRGB(255, 246, 200) }, -- Joseph (Hermit Purple + Hamon gold)
	[21] = { Main = Color3.fromRGB(240, 196, 50), Second = Color3.fromRGB(60, 160, 110), Light = Color3.fromRGB(255, 244, 200) }, -- DIO (The World gold + green)
	[20] = { Main = Color3.fromRGB(130, 110, 220), Second = Color3.fromRGB(240, 196, 70), Light = Color3.fromRGB(230, 225, 255) }, -- Jotaro (Star Platinum violet + gold)
	[19] = { Main = Color3.fromRGB(230, 120, 170), Second = Color3.fromRGB(246, 204, 40), Light = Color3.fromRGB(255, 236, 220) }, -- Ringo (Mandom pink + watch-hand gold)
}

---------------------------------------------------------------------------
-- FINGER WHIRLS (Johnny's nail shots, from the art): blue rings spinning
-- round his fingertips while his hand is up, following the hand; on
-- Release(direction) they shoot out along the shot, spreading and fading.
---------------------------------------------------------------------------
local WHIRL = Color3.fromRGB(120, 200, 255)
local WHIRL_LIGHT = Color3.fromRGB(200, 236, 255)

-- Where his fingertips are, and the way they point (a CFrame whose
-- UpVector runs along the fingers).
local function fingertips(character)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local root = character:FindFirstChild("HumanoidRootPart")
	if hand then
		local down = -hand.CFrame.UpVector
		local tip = (hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.15, 0)).Position
		return CFrame.lookAt(tip, tip + down) * CFrame.Angles(-math.pi / 2, 0, 0)
	elseif root then
		local tip = (root.CFrame * CFrame.new(0.9, 0.55, -1.6)).Position
		return CFrame.lookAt(tip, tip + root.CFrame.LookVector) * CFrame.Angles(-math.pi / 2, 0, 0)
	end
	return nil
end
Common.fingertips = fingertips

function Common.fingerWhirl(character, duration, opts)
	opts = opts or {}
	local color, light = opts.Color or WHIRL, opts.Light or WHIRL_LIGHT
	local rings = {}
	local spec = { { 0.32, 0, 9 }, { 0.55, 0.14, -7 }, { 0.8, 0.28, 5 } } -- radius, along the fingers, spin speed
	for i, sp in ipairs(spec) do
		local ring = VFXLib.ring({ Radius = 0.05, Width = i == 1 and 0.12 or 0.09, Color = i % 2 == 1 and color or light, Transparency = 0.1, Segments = 14 })
		rings[i] = { Ring = ring, Radius = sp[1], Along = sp[2], Spin = sp[3], Angle = math.random() * math.pi * 2 }
	end
	local glow = VFXLib.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3), Color = light, Transparency = 0.3 })
	local handle = { Released = false }
	local start = os.clock()
	local last = start
	local job = VFXLib.animate(math.max(duration, 0.05) + 0.6, function()
		if handle.Released then
			return
		end
		local now = os.clock()
		local dt = now - last
		last = now
		local cf = character.Parent and fingertips(character)
		if not cf then
			return
		end
		local grow = math.min((now - start) / 0.15, 1)
		for i, r in ipairs(rings) do
			r.Angle = r.Angle + r.Spin * dt
			local wobble = math.sin(now * 11 + i) * 0.08
			local radius = r.Radius * grow * (1 + math.sin(now * 14 + i * 2) * 0.1)
			r.Ring:SetRadius(radius)
			r.Ring:SetCFrame(cf * CFrame.new(0, r.Along, 0) * CFrame.Angles(wobble, r.Angle, -wobble))
		end
		glow.CFrame = cf
		local pulse = 0.3 + math.abs(math.sin(now * 18)) * 0.25
		glow.Size = Vector3.new(pulse, pulse, pulse) * (1 + grow * 0.5)
	end)
	function handle:Release(direction)
		if self.Released then
			return
		end
		self.Released = true
		VFXLib.cancel(job)
		local cf = character.Parent and fingertips(character)
		glow:Destroy()
		if not cf then
			for _, r in ipairs(rings) do
				r.Ring:Destroy()
			end
			return
		end
		local dir = (direction and direction.Magnitude > 1e-3) and direction.Unit or cf.UpVector
		local from = cf.Position
		local axis = CFrame.lookAt(from, from + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
		-- The whirls fly out along the shot, spinning, spreading and fading.
		for i, r in ipairs(rings) do
			local base = r.Radius
			VFXLib.animate(0.32, function(a)
				r.Angle = r.Angle + r.Spin * 0.03
				r.Ring:SetRadius(base * (1 + a * (1.5 + i * 0.4)))
				r.Ring:SetCFrame(axis * CFrame.new(0, a * (2.5 + i * 1.6), 0) * CFrame.Angles(0, r.Angle, 0))
				r.Ring:SetTransparency(0.1 + 0.9 * a)
			end, function()
				r.Ring:Destroy()
			end)
		end
		VFXLib.flash(from, color, 4, 10, 0.1)
		VFXLib.burst(from, { Count = 8, Color = light, Speed = 12, Lifetime = 0.25 })
	end
	-- Never left behind if nobody releases it.
	task.delay(math.max(duration, 0.05) + 0.6, function()
		handle:Release(nil)
	end)
	return handle
end

function Common.palette(act)
	return Common.Palettes[act] or Common.Palettes[1]
end

function Common.rootOf(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

function Common.isLocal(character)
	return character ~= nil and character == localPlayer.Character
end

function Common.swipe(root, side, color, scale)
	scale = scale or 1
	local cf = root.CFrame * CFrame.new(side * 0.3, 0.3, -1.2) * CFrame.Angles(0, 0, side * 0.5)
	-- A thick coloured arc, a thin bright inner arc a beat later, and sparks
	-- flung off the tip of the swing.
	TuskVFX.CreateCrescent(cf, { Radius = 2.4 * scale, Width = 0.6 * scale, Color = color, Color2 = Color3.new(1, 1, 1), Sweep = side * 1.9, Duration = 0.2 })
	task.delay(0.03, function()
		if root.Parent then
			TuskVFX.CreateCrescent(cf * CFrame.new(0, 0, -0.3), { Radius = 1.8 * scale, Width = 0.18 * scale, Color = Color3.new(1, 1, 1), Color2 = color, Sweep = side * 2.1, Duration = 0.14 })
		end
	end)
	local tip = (root.CFrame * CFrame.new(-side * 1.6 * scale, 0.4, -2.2 * scale)).Position
	VFXLib.burst(tip, { Count = 5, Color = color, Speed = 18, Lifetime = 0.22, Spread = 50, Direction = root.CFrame.RightVector * -side, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }) })
end

---------------------------------------------------------------------------
-- Portals
---------------------------------------------------------------------------
-- A wormhole facing `lookAt`. Opens, holds `duration`, collapses.
function Common.portal(position, lookAt, radius, duration, palette, delay)
	palette = palette or Common.palette(2)
	local function open()
		local facing = (lookAt and (lookAt - position).Magnitude > 0.1) and CFrame.lookAt(position, lookAt) or CFrame.new(position)
		TuskVFX.CreateWormhole(facing, {
			Radius = radius or 2.5,
			Color = palette.Main,
			Color2 = palette.Second,
			OpenTime = 0.22,
			Duration = duration or 0.6,
			CloseTime = 0.2,
		})
		VFXLib.sound(sounds.Warning, position, 0.25, 1.6)
	end
	if delay and delay > 0 then
		task.delay(delay, open)
	else
		open()
	end
end

-- Golden ratio (Act 2): a Golden Rectangle with its spiral facing `lookAt`,
-- a spinning golden spiral in front and a soft gold flash. Same arguments
-- as Common.portal so the two can be swapped.
function Common.golden(position, lookAt, radius, duration, palette, delay)
	palette = palette or Common.palette(2)
	local function open()
		local facing = (lookAt and (lookAt - position).Magnitude > 0.1) and CFrame.lookAt(position, lookAt) or CFrame.new(position)
		local size = (radius or 2.5) * 1.1
		TuskVFX.CreateGoldenRectangle(facing, { Size = size, Duration = (duration or 0.6) + 0.25, Color = colors.Gold, Color2 = colors.GoldLight, Turn = math.pi * 0.4 })
		TuskVFX.CreateGoldenSpiral(facing * CFrame.new(0, 0, -0.1), { Size = size * 0.9, Duration = (duration or 0.6) + 0.2, Color = palette.Main, Color2 = colors.GoldLight, Width = 0.14 })
		VFXLib.flash(position, colors.Gold, 3, 10 + size * 2, 0.25)
		VFXLib.sound(sounds.Warning, position, 0.2, 1.8)
	end
	if delay and delay > 0 then
		task.delay(delay, open)
	else
		open()
	end
end

---------------------------------------------------------------------------
-- M1
---------------------------------------------------------------------------
local LUNGES = {
	CFrame.new(0.4, 0.6, -3),
	CFrame.new(-0.6, 0.4, -3.2),
	CFrame.new(0.9, 1, -2.4),
	CFrame.new(0, 1.4, -3.4),
}

function Common.m1(data, palette, opts)
	opts = opts or {}
	local character = data.Character
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local index = data.Index
	TuskAnimation.play(character, (opts.AnimPrefix or "M1_") .. index)
	VFXLib.sound(sounds.Swing, root, 0.5, (opts.Pitch or 1) * (0.95 + index * 0.06))
	TuskStand.action(character, "Lunge", { Target = LUNGES[index], Duration = index == 4 and 0.5 or 0.26 })
	Common.swipe(root, index % 2 == 1 and 1 or -1, index % 2 == 1 and palette.Main or palette.Light, opts.Scale)
	if data.Portal then
		-- Short portal (or golden rectangle) flash beside the strike.
		local pos = (root.CFrame * CFrame.new(index % 2 == 1 and 1.6 or -1.6, 1, -2.6)).Position
		local open = opts.Golden and Common.golden or Common.portal
		open(pos, (root.CFrame * CFrame.new(0, 1, -6)).Position, 1.1, 0.18, palette)
	end
	if (data.Repeat or 1) > 1 then
		for i = 2, data.Repeat do
			task.delay((i - 1) * 0.08, function()
				if root.Parent then
					Common.swipe(root, i % 2 == 0 and -1 or 1, palette.Light, opts.Scale)
					VFXLib.burst((root.CFrame * CFrame.new(0, 0.5, -3)).Position, { Count = 5, Color = palette.Main, Speed = 10, Lifetime = 0.2 })
				end
			end)
		end
	end
end

function Common.finisher(data, palette, opts)
	opts = opts or {}
	local character = data.Character
	local root = Common.rootOf(character)
	local pos = data.Position
	if data.Hit and Common.isLocal(character) then
		CameraFX.impactFrame(palette.Light)
	end
	TuskVFX.CreateRotationalShockwave(CFrame.new(pos - Vector3.new(0, 2.6, 0)), {
		Radius = data.Radius or 7,
		Layers = opts.Layers or 3,
		Color = palette.Main,
		Color2 = palette.Second,
		Ground = true,
		Particles = 1.5,
		Width = opts.Width or 0.5,
	})
	TuskVFX.CreateImpact(pos, root and -root.CFrame.LookVector or Vector3.new(0, 1, 0), { Size = opts.Size or 1.2, Radius = 3, Layers = 2, Color = palette.Light, Color2 = palette.Main, Ground = false })
	TuskVFX.CreateImpactStar(pos, { Size = 6 * (opts.Size or 1.2), Rays = 9, Color = palette.Main, Color2 = palette.Light, Duration = 0.3 })
	if data.Hit then
		TuskVFX.CreateGroundCracks(pos, { Radius = (data.Radius or 7) * 0.8, Color = palette.Main, Duration = 1.3 })
	end
	VFXLib.sound(sounds.Finisher, pos, 0.8, opts.Pitch or 1)
	CameraFX.shakeAt(pos, opts.Shake or 0.6, 50)
end

---------------------------------------------------------------------------
-- Evolution: Act N -> Act N+1
---------------------------------------------------------------------------
function Common.evolve(data)
	local character = data.Character
	local root = Common.rootOf(character)
	if not root then
		return
	end
	local palette = Common.palette(data.To)
	local ground = root.Position - Vector3.new(0, 2.9, 0)
	TuskVFX.CreateMagicCircle(CFrame.new(ground), { Radius = 9, Color = palette.Main, Color2 = palette.Light, Duration = 1.4, RotationSpeed = 2, Points = data.To + 4 })
	TuskVFX.CreateRotationalShockwave(CFrame.new(ground), { Radius = 16, Layers = 3, Color = palette.Main, Color2 = palette.Light, Ground = true, Particles = 2, Width = 0.7, Duration = 0.6 })
	VFXLib.burst(root.Position, { Count = 40, Color = palette.Light, Speed = 40, Lifetime = 0.6 })
	VFXLib.flash(root.Position, palette.Main, 9, 30, 0.6)
	TuskVFX.CreateEnergyPillar(ground, { Radius = 5, Height = 45, Color = palette.Light, Color2 = palette.Main, Duration = 0.6 })
	TuskVFX.CreateImpactStar(root.Position, { Size = 10, Rays = 10, Color = palette.Main, Color2 = palette.Light, Duration = 0.35 })
	VFXLib.sound(sounds.AwakeningBurst, root.Position, 0.9, 1 + data.To * 0.05)
	TuskStand.action(character, "Manifest", { Duration = 0.7 })
	if Common.isLocal(character) then
		CameraFX.speedLines(0.5, palette.Light)
		CameraFX.fovPunch(14, 0.6)
	end
end

---------------------------------------------------------------------------
-- Hold-charge visuals (shared driver)
---------------------------------------------------------------------------
--[[ Common.chargeDriver(act, move, makeEffect(character, root) -> effect,
     update(effect, progress, character), finish(effect, character)) ]]
function Common.chargeDriver(act, move, makeEffect, update, finish)
	local active = {}
	return function()
		local seen = {}
		for _, player in ipairs(Fighters.list()) do
			local character = player.Character
			local start = character and character:GetAttribute("TuskCharge")
			if start and character:GetAttribute("TuskAct") == act and character:GetAttribute("TuskChargeMove") == move then
				seen[character] = true
				local root = Common.rootOf(character)
				if not active[character] and root then
					active[character] = { Effect = makeEffect(character, root), Start = start }
				end
				local entry = active[character]
				if entry then
					update(entry.Effect, workspace:GetServerTimeNow() - start, character)
				end
			end
		end
		for character, entry in pairs(active) do
			if not seen[character] then
				active[character] = nil
				finish(entry.Effect, character)
			end
		end
	end
end

function Common.actName(act)
	local info = Registry.get(act)
	return info and info.Name or ("TUSK ACT " .. tostring(act))
end

return Common
```
