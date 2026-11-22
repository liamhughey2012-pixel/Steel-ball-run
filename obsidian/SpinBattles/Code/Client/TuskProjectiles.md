---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient"
updated: 2026-11-22
---
# TuskProjectiles

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| **Exact name** | `TuskProjectiles` (capitals matter) |

**What it does:** Draws every server "TuskNail" projectile (ProjectileService events on SpinFX). Position follows the server's straight-line path using server time, so all clients agree. Looks depend on Visual.Act / Visual.Style:

## How to add it
1. In Studio's Explorer, find **SpinClient** (StarterPlayer › StarterPlayerScripts › SpinClient).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **TuskProjectiles**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskProjectiles  (StarterPlayerScripts.SpinClient.TuskProjectiles)

	Draws every server "TuskNail" projectile (ProjectileService events on
	SpinFX). Position follows the server's straight-line path using server
	time, so all clients agree. Looks depend on Visual.Act / Visual.Style:

	  Style "M1"       short quick nail
	  Style "Shot"     cyan helix, thin blue trail, launch streak
	  Style "Barrage"  smaller nails, muzzle flash per nail
	  Style "Spinning" bigger with charge, 1-3 rotation rings, golden-blue at full
	  Awakened         extra ring, brighter trails
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)
local CameraFX = require(script.Parent.CameraFX)
local TuskVFX = require(script.Parent.TuskVFX)

local TuskProjectiles = {}
local colors = TuskConfig.Colors
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

local active = {}

local function styleFor(visual)
	local style = visual.Style or "Shot"
	local charge = visual.Charge or 0
	local awakened = visual.Awakened == true
	local s = {
		Scale = 1,
		Rings = 0,
		RingColor = colors.Cyan,
		Color = colors.Blue,
		Color2 = colors.Cyan,
		TrailColor = colors.Blue,
		Helix = 2,
		SpinSpeed = 32,
		ImpactSize = 0.8,
		ImpactLayers = 1,
		Afterimages = false,
	}
	if style == "M1" then
		s.Scale = 0.75
		s.Helix = 1
		s.ImpactSize = 0.6
	elseif style == "Barrage" then
		s.Scale = 0.8
		s.Helix = 1
		s.ImpactSize = 0.6
	elseif style == "Spinning" then
		s.Scale = 1 + charge * 0.7
		s.Rings = 1 + math.floor(charge * 2 + 0.01)
		s.SpinSpeed = 40 + charge * 30
		s.ImpactSize = 1 + charge * 1.2
		s.ImpactLayers = 2 + math.floor(charge + 0.01)
		s.Afterimages = charge > 0.5
		if charge >= 1 then
			-- Full charge: golden-blue identity.
			s.RingColor = colors.Gold
			s.Color2 = colors.Gold
			s.TrailColor = colors.GoldLight
		end
	end
	if awakened then
		s.Rings = s.Rings + 1
		s.Color2 = colors.Ice
		s.ImpactSize = s.ImpactSize * 1.15
	end
	return s, style, charge
end

local function onSpawn(data)
	local s, style, charge = styleFor(data.Visual or {})
	local visual = TuskVFX.CreateNailProjectile(s)
	local entry = {
		Id = data.Id,
		Visual = visual,
		Style = style,
		StyleData = s,
		Charge = charge,
		Origin = data.Origin,
		Direction = data.Direction,
		Speed = data.Speed,
		Range = data.Range,
		ServerTime = data.ServerTime,
		Expire = os.clock() + data.Range / data.Speed + 1.5,
	}
	active[data.Id] = entry

	-- Launch: muzzle flash, small ring, streak (projectile acceleration feel).
	local axis = CFrame.lookAt(data.Origin, data.Origin + data.Direction) * CFrame.Angles(math.pi / 2, 0, 0)
	VFXLib.burst(data.Origin, { Count = style == "Barrage" and 5 or 9, Color = s.Color2, Speed = 18, Spread = 22, Direction = data.Direction, Lifetime = 0.2 })
	VFXLib.shockwave(axis, { StartRadius = 0.2, Radius = 1.2 * s.Scale, Width = 0.12, Duration = 0.18, Color = s.Color2 })
	VFXLib.sound(sounds.NailFire, data.Origin, style == "Barrage" and 0.4 or 0.6, style == "Barrage" and 1.2 + math.random() * 0.15 or 1)
	if style == "Spinning" and charge >= 1 then
		VFXLib.flash(data.Origin, colors.Gold, 6, 18, 0.3)
		if data.OwnerId == localPlayer.UserId then
			CameraFX.speedLines(0.25, colors.Ice)
		end
	end
end

local function onEnd(data)
	local entry = active[data.Id]
	if entry then
		active[data.Id] = nil
		entry.Visual:Destroy()
	end
	local s, style, charge = styleFor(data.Visual or {})
	local color = (style == "Spinning" and charge >= 1) and colors.Gold or colors.Cyan
	TuskVFX.CreateImpact(data.Position, data.Normal, {
		Size = s.ImpactSize,
		Layers = s.ImpactLayers,
		Radius = style == "Spinning" and 5 or 3.5,
		Color = color,
		Color2 = colors.Ice,
		Sound = sounds.NailImpact,
		Pitch = style == "Barrage" and 1.25 or 1,
	})
	if style == "Spinning" then
		TuskVFX.CreateDistortion(data.Position, { Radius = 2 + charge * 3 })
		CameraFX.shakeAt(data.Position, 0.3 + charge * 0.5, 70)
		if charge >= 1 and data.HitCharacter and data.OwnerId == localPlayer.UserId then
			CameraFX.impactFrame(colors.Ice)
		end
	else
		CameraFX.shakeAt(data.Position, 0.15, 40)
	end
end

function TuskProjectiles.init()
	local FX = Net.get("SpinFX")
	FX.OnClientEvent:Connect(function(name, data)
		if name == "Hit" and typeof(data) == "table" and typeof(data.Source) == "string" and string.sub(data.Source, 1, 4) == "Tusk" then
			VFXLib.sound(sounds.Hit, data.Position, 0.6, 0.95 + math.random() * 0.1)
			return
		end
		if typeof(data) ~= "table" or data.Kind ~= "TuskNail" then
			return
		end
		if name == "ProjectileSpawn" then
			onSpawn(data)
		elseif name == "ProjectileEnd" then
			onEnd(data)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local serverNow = workspace:GetServerTimeNow()
		for id, entry in pairs(active) do
			local distance = math.min(entry.Speed * (serverNow - entry.ServerTime), entry.Range)
			local pos = entry.Origin + entry.Direction * distance
			entry.Visual:Step(CFrame.lookAt(pos, pos + entry.Direction), dt)
			if now > entry.Expire then
				active[id] = nil
				entry.Visual:Destroy()
			end
		end
	end)
end

return TuskProjectiles
```
