---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient"
updated: 2026-11-22
---
# TuskStand

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| **Exact name** | `TuskStand` (capitals matter) |

**What it does:** Builds and animates the Tusk Stand for every player whose character has the TuskAct attribute. Purely client-side: each client draws all Stands locally, so they cost no server physics or network traffic.

## How to add it
1. In Studio's Explorer, find **SpinClient** (StarterPlayer › StarterPlayerScripts › SpinClient).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **TuskStand**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	TuskStand  (StarterPlayerScripts.SpinClient.TuskStand)

	Builds and animates the Tusk Stand for every player whose character
	has the TuskAct attribute. Purely client-side: each client draws all
	Stands locally, so they cost no server physics or network traffic.

	Idle: floats behind the right shoulder, bobbing, ears flapping, heart
	feet swinging, leaning with the player's movement. Sneak: drops low.
	Actions (called by Act choreography):
	  TuskStand.action(character, "Lunge", { Target = CFrame (root-local), Duration })
	  TuskStand.action(character, "Manifest")  scale-in flash
	  TuskStand.action(character, "Emerge")    rise up out of the ground
	TuskStand.nailPoint(character) -> world CFrame where nail energy gathers
]]

local Players = game:GetService("Players")
local Fighters = require(script.Parent.Fighters)
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local VFXQuality = require(Shared.VFXQuality)
local TuskStandModels = require(Shared.TuskStandModels)
local VFXLib = require(script.Parent.VFXLib)

local TuskStand = {}

-- Where each Act's Stand floats (bigger Acts float further back).
local IDLE_OFFSETS = {
	[1] = CFrame.new(1.9, 1.5, 1.7),
	[2] = CFrame.new(2.1, 1.6, 2),
	[3] = CFrame.new(2.4, 1.2, 2.8),
	[4] = CFrame.new(2.6, 1.8, 3.4),
}
local IDLE_OFFSET = IDLE_OFFSETS[1]
local SNEAK_OFFSET = CFrame.new(1.5, -1.4, 1.2)

local stands = {} -- [character] = stand

-- Pink Spin energy aura around every Tusk Stand.
local AURA = Color3.fromRGB(255, 105, 205)
local AURA_LIGHT = Color3.fromRGB(255, 195, 238)

local function addAura(model, rig)
	local body = rig and rig.Body or model.PrimaryPart
	if not body then
		return nil
	end
	local quality = VFXQuality.get()
	local boxCF, size = model:GetBoundingBox()
	-- Invisible shell around the whole Stand that the aura particles come from.
	local shell = Instance.new("Part")
	shell.Name = "TuskAuraShell"
	shell.Transparency = 1
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.Massless = true
	shell.Anchored = false
	shell.Size = size * 0.9
	shell.CFrame = boxCF
	local weld = Instance.new("Weld")
	weld.Part0 = body
	weld.Part1 = shell
	weld.C0 = body.CFrame:ToObjectSpace(boxCF)
	weld.Parent = shell
	shell.Parent = model
	local emitters = {}
	-- Soft pink energy rising off the body.
	local glow = Instance.new("ParticleEmitter")
	glow.Texture = VFXLib.Textures.Smoke
	glow.Color = ColorSequence.new(AURA, AURA_LIGHT)
	glow.LightEmission = 1
	glow.LightInfluence = 0
	glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
	glow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.72), NumberSequenceKeypoint.new(1, 1) })
	glow.Lifetime = NumberRange.new(0.6, 1)
	glow.Speed = NumberRange.new(1, 2.5)
	glow.Acceleration = Vector3.new(0, 3, 0)
	glow.RotSpeed = NumberRange.new(-60, 60)
	glow.Rate = 14 * quality.Particles
	glow.Shape = Enum.ParticleEmitterShape.Box
	glow.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	glow.EmissionDirection = Enum.NormalId.Top
	glow.Parent = shell
	table.insert(emitters, glow)
	-- Little pink sparks orbiting out of it.
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = VFXLib.Textures.Sparkle
	sparks.Color = ColorSequence.new(AURA_LIGHT, AURA)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.Speed = NumberRange.new(1.5, 3.5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rate = 12 * quality.Particles
	sparks.Shape = Enum.ParticleEmitterShape.Box
	sparks.Parent = shell
	table.insert(emitters, sparks)
	local light
	if quality.Lights then
		light = Instance.new("PointLight")
		light.Color = AURA
		light.Range = 9
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = body
	end
	return { Emitters = emitters, Light = light }
end

local function setVisible(stand, visible)
	if stand.Visible == visible then
		return
	end
	stand.Visible = visible
	for part, original in pairs(stand.Transparency) do
		part.Transparency = visible and original or 1
	end
	if stand.Aura then
		for _, e in ipairs(stand.Aura.Emitters) do
			e.Enabled = visible
		end
		if stand.Aura.Light then
			stand.Aura.Light.Enabled = visible
		end
	end
	stand.Highlight.Enabled = visible
end

local function build(character, act)
	local model, rig = TuskStandModels.build(act, 1)
	if not model then
		return nil
	end
	local transparency = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			transparency[d] = d.Transparency
		end
	end
	local aura = addAura(model, rig)
	-- Pink aura glow + outline (pulses in update); flashes brighter on Manifest.
	local highlight = Instance.new("Highlight")
	highlight.FillColor = AURA
	highlight.FillTransparency = 0.85
	highlight.OutlineColor = AURA
	highlight.OutlineTransparency = 0.4
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
	model.Parent = VFXLib.Folder
	local root = character:FindFirstChild("HumanoidRootPart")
	local start = root and root.CFrame * (IDLE_OFFSETS[act] or IDLE_OFFSET) or CFrame.new()
	model:PivotTo(start)
	return {
		Act = act,
		Character = character,
		Model = model,
		Rig = rig,
		Highlight = highlight,
		Aura = aura,
		Transparency = transparency,
		Visible = true,
		CF = start,
		Action = nil,
		Phase = math.random() * 10,
	}
end

local function destroy(stand)
	stand.Model:Destroy()
end

function TuskStand.get(character)
	return stands[character]
end

function TuskStand.action(character, kind, data)
	local stand = stands[character]
	if not stand then
		return
	end
	stand.Action = { Kind = kind, Start = os.clock(), Duration = (data and data.Duration) or 0.4, Data = data or {} }
	if kind == "Manifest" then
		stand.Highlight.OutlineTransparency = 0
		VFXLib.animate(0.6, function(a)
			stand.Highlight.OutlineTransparency = a
		end)
	end
end

function TuskStand.nailPoint(character)
	local stand = stands[character]
	if stand and stand.Rig.NailPoint then
		return stand.Rig.NailPoint.WorldCFrame
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.CFrame * CFrame.new(1, 1, -1.5) or CFrame.new()
end

local function update(stand, root, dt, now)
	local character = stand.Character
	local t = now + stand.Phase
	local sneaking = character:GetAttribute("TuskSneaking") == true
	local burrowed = character:GetAttribute("TuskBurrowed") == true
	local awakened = character:GetAttribute("TuskAwakened") == true

	setVisible(stand, not burrowed)
	-- Pink aura: the glow and outline breathe; Awakened = strong outline; Manifest = flash.
	local pulse = (math.sin(t * 3) + 1) / 2
	stand.Highlight.FillTransparency = 0.88 - pulse * 0.06
	stand.Highlight.OutlineTransparency = awakened and 0.05 or (stand.Action and stand.Action.Kind == "Manifest" and stand.Highlight.OutlineTransparency or (0.45 - pulse * 0.2))

	local velocity = root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local localVel = root.CFrame:VectorToObjectSpace(flat)
	local lean = math.clamp(-localVel.Z / 40, -0.4, 0.4) -- lean forward when running

	local bob = math.sin(t * 2.2) * (sneaking and 0.08 or 0.22)
	local offset = (sneaking and SNEAK_OFFSET or (IDLE_OFFSETS[stand.Act] or IDLE_OFFSET)) * CFrame.new(0, bob, 0)
	local desired = root.CFrame * offset * CFrame.Angles(-lean, math.sin(t * 0.9) * 0.12, math.sin(t * 1.3) * 0.08)
	if stand.Act == 1 and not sneaking then
		-- Act 1 is small and restless: quick bounces plus a wandering drift.
		local bounce = math.abs(math.sin(t * 4.2)) * 0.28
		local driftX = math.noise(t * 0.9, stand.Phase) * 0.6
		local driftZ = math.noise(stand.Phase, t * 0.8) * 0.45
		local wobble = math.noise(t * 1.7, stand.Phase + 3) * 0.35
		desired = desired * CFrame.new(driftX, bounce, driftZ) * CFrame.Angles(0, wobble, wobble * 0.4)
	end
	local snap = 12

	local action = stand.Action
	if action then
		local a = (now - action.Start) / action.Duration
		if a >= 1 then
			stand.Action = nil
		elseif action.Kind == "Lunge" then
			-- Out fast, hold, return.
			local target = root.CFrame * (action.Data.Target or CFrame.new(0.6, 0.8, -3.2))
			local out = a < 0.35 and VFXLib.easeOut(a / 0.35) or (a < 0.6 and 1 or 1 - VFXLib.easeInOut((a - 0.6) / 0.4))
			desired = desired:Lerp(target, out)
			snap = 30
		elseif action.Kind == "Manifest" then
			local s = VFXLib.easeOut(math.min(a / 0.5, 1))
			desired = desired * CFrame.new(0, (1 - s) * -1.5, 0) * CFrame.Angles(0, (1 - s) * math.pi * 2, 0)
			snap = 40
		elseif action.Kind == "Emerge" then
			local s = VFXLib.easeOut(a)
			desired = root.CFrame * CFrame.new(1.2, -3 + s * 4.2, -1.2) * CFrame.Angles(0, s * math.pi * 2, 0)
			snap = 60
		end
	end

	stand.CF = stand.CF:Lerp(desired, 1 - math.exp(-dt * snap))
	stand.Model:PivotTo(stand.CF)

	-- Secondary motion on the built-in model.
	local joints = stand.Rig.Joints
	-- Head: curious little tilts and glances (Act 1 mascot).
	if joints.Head then
		local yaw = math.noise(t * 0.7, stand.Phase + 7) * 0.7
		local tilt = math.noise(stand.Phase + 11, t * 0.9) * 0.3
		local nod = math.sin(t * 2.6) * 0.06
		joints.Head.Weld.C0 = joints.Head.Base * CFrame.Angles(nod, yaw, tilt) * joints.Head.Offset
	end
	if joints.EarL then
		local flap = math.sin(t * 3.1) * 0.18 + lean * 0.5
		joints.EarL.Weld.C0 = joints.EarL.Base * CFrame.Angles(0, 0, flap) * joints.EarL.Offset
		joints.EarR.Weld.C0 = joints.EarR.Base * CFrame.Angles(0, 0, -flap) * joints.EarR.Offset
	end
	-- Arms: idle sway; thrown forward during a Lunge (punch / nail fire).
	local punching = stand.Action and stand.Action.Kind == "Lunge"
	local punchA = 0
	if punching then
		local a = (now - stand.Action.Start) / stand.Action.Duration
		punchA = a < 0.3 and a / 0.3 or math.max(0, 1 - (a - 0.3) / 0.7)
	end
	if joints.ArmR then
		local sway = math.sin(t * 2) * 0.12
		joints.ArmR.Weld.C0 = joints.ArmR.Base * CFrame.Angles(sway + punchA * 1.7, 0, -punchA * 0.2) * joints.ArmR.Offset
		joints.ArmL.Weld.C0 = joints.ArmL.Base * CFrame.Angles(-sway + punchA * 0.6, 0, punchA * 0.3) * joints.ArmL.Offset
	end
	for i = 1, 4 do
		local leg = joints["Leg" .. i]
		if leg then
			local swing = math.sin(t * 3.6 + i * 1.3) * 0.28 + lean * 1.2
			leg.Weld.C0 = leg.Base * CFrame.Angles(swing, 0, math.sin(t * 2 + i) * 0.1) * leg.Offset
		end
	end
end

-- Rebuild every Stand (e.g. when a custom model finishes loading).
function TuskStand.rebuildAll()
	for character, stand in pairs(stands) do
		stands[character] = nil
		if stand then
			destroy(stand)
		end
	end
end

function TuskStand.init()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local function watch(folder)
		folder.ChildAdded:Connect(TuskStand.rebuildAll)
		folder.ChildRemoved:Connect(TuskStand.rebuildAll)
	end
	local existing = ReplicatedStorage:FindFirstChild("SpinAssets")
	if existing then
		watch(existing)
	end
	ReplicatedStorage.ChildAdded:Connect(function(child)
		if child.Name == "SpinAssets" then
			watch(child)
			TuskStand.rebuildAll()
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local seen = {}
		for _, player in ipairs(Fighters.list()) do
			local character = player.Character
			local act = character and character:GetAttribute("TuskAct")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if act and root and humanoid and humanoid.Health > 0 then
				seen[character] = true
				local stand = stands[character]
				if stand and stand.Act ~= act then
					destroy(stand)
					stand = nil
				end
				if not stand then
					stand = build(character, act)
					stands[character] = stand
					if stand then
						TuskStand.action(character, "Manifest", { Duration = 0.6 })
					end
				end
				if stand then
					update(stand, root, dt, now)
				end
			end
		end
		for character, stand in pairs(stands) do
			if not seen[character] then
				stands[character] = nil
				if stand then
					destroy(stand)
				end
			end
		end
	end)
end

return TuskStand
```
