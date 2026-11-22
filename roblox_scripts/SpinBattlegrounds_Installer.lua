--[[
	SPIN BATTLEGROUNDS INSTALLER
	Creates every script (Golden Spin, Tusk Act 1, Tusk Sneak, NPCs, map builder)
	in the right place with the right name. Running it again replaces the old
	versions, so use it for every update.

	OPTION A: plugin (recommended, a reusable button)
	  1. In Studio: Plugins tab > Plugins Folder (opens a folder on your PC).
	  2. Put this file in that folder. Restart Studio.
	  3. Open your place. Plugins tab > "Spin Battlegrounds" toolbar:
	       [Install Scripts]  creates or updates all scripts
	       [Build Map]        builds the SBR map once
	  4. If Studio asks to allow script injection, click Allow.
	  5. File > Save.

	OPTION B: one time, without a plugin
	  View > Command Bar, paste this whole file, press Enter. Then build the map:
	    require(game.ServerStorage.SpinTools.SBRMapBuilder).Build()
	  File > Save.
]]

local SCRIPTS = {
	{ Service = "ReplicatedStorage", Path = "SpinShared", Class = "Folder", Source = nil },
	{ Service = "ReplicatedStorage", Path = "SpinShared/Maid", Class = "ModuleScript", Source = [=[
--[[
	Maid  (ReplicatedStorage.SpinShared.Maid)
	Tracks connections, instances and cleanup functions so effects always end.
]]

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(task)
	table.insert(self._tasks, task)
	return task
end

function Maid:Clean()
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		local t = tasks[i]
		local kind = typeof(t)
		if kind == "RBXScriptConnection" then
			t:Disconnect()
		elseif kind == "Instance" then
			t:Destroy()
		elseif kind == "function" then
			local ok, err = pcall(t)
			if not ok then
				warn("[Maid] cleanup error:", err)
			end
		elseif kind == "table" and t.Destroy then
			t:Destroy()
		end
	end
end

Maid.Destroy = Maid.Clean

return Maid
]=] },
	{ Service = "ReplicatedStorage", Path = "SpinShared/NailModel", Class = "ModuleScript", Source = [=[
--[[
	NailModel  (ReplicatedStorage.SpinShared.NailModel)

	Procedural fingernail-bullet used by every Tusk nail attack: a metal
	shaft, a flat head at the back and a tapered tip at the front.
	The nail points down its Core's LookVector (-Z).

	NailModel.build(length) -> Model (PrimaryPart = "Core")
	  Core attachments: "Tip" (front), "Tail" (back), "Center".
]]

local TuskConfig = require(script.Parent.TuskConfig)

local NailModel = {}

local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = model
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

function NailModel.build(length)
	length = length or 1.3
	local metal = TuskConfig.Colors.Metal
	local model = Instance.new("Model")
	model.Name = "TuskNail"

	-- Shaft: Cylinder axis is X, so turn it to run along Z.
	local core = part(model, {
		Name = "Core",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length * 0.7, length * 0.085, length * 0.085),
		Color = metal,
		Reflectance = 0.25,
		Massless = false,
	})
	core.CFrame = CFrame.Angles(0, math.pi / 2, 0)
	-- Pivot frame faces -Z, so Model:PivotTo(cf) points the tip down cf.LookVector.
	core.PivotOffset = CFrame.Angles(0, -math.pi / 2, 0)
	model.PrimaryPart = core

	local head = part(model, {
		Name = "Head",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length * 0.05, length * 0.24, length * 0.24),
		Color = metal:Lerp(Color3.new(1, 1, 1), 0.2),
		Reflectance = 0.3,
	})
	head.CFrame = CFrame.new(0, 0, length * 0.36) * CFrame.Angles(0, math.pi / 2, 0)
	weld(core, head)

	local tip = part(model, {
		Name = "Tip",
		Size = Vector3.new(length * 0.085, length * 0.085, length * 0.36),
		Color = metal:Lerp(Color3.new(1, 1, 1), 0.35),
		Reflectance = 0.35,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = tip
	tip.CFrame = CFrame.new(0, 0, -length * 0.35)
	weld(core, tip)

	-- Attachments are placed in the core's (rotated) local space:
	-- the core's local X axis runs along world Z here.
	local function att(name, z)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = Vector3.new(-z, 0, 0)
		a.Parent = core
		return a
	end
	att("Tip", -length * 0.5)
	att("Tail", length * 0.4)
	att("Center", 0)

	return model
end

return NailModel
]=] },
	{ Service = "ReplicatedStorage", Path = "SpinShared/Net", Class = "ModuleScript", Source = [=[
--[[
	Net  (ReplicatedStorage.SpinShared.Net)

	Creates (server) or waits for (client) the RemoteEvents used by the
	Spin system. All remotes live in ReplicatedStorage.SpinRemotes.

	SpinRequest : client -> server  ("Start" | "Release", aimDirection | "Cancel")
	SpinFX      : server -> client  (eventName, payloadTable)
	              Also carries shared events: ProjectileSpawn/End, Hit, Damage.
	TuskRequest : client -> server  (action, ...)  see TuskService
	TuskFX      : server -> client  (eventName, payloadTable)
	WorldFX     : server -> client  map / NPC events (NPCSay)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES = { "SpinRequest", "SpinFX", "TuskRequest", "TuskFX", "WorldFX" }

local Net = {}
local folder

local function getFolder()
	if folder then
		return folder
	end
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild("SpinRemotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "SpinRemotes"
			folder.Parent = ReplicatedStorage
		end
		for _, name in ipairs(REMOTES) do
			if not folder:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild("SpinRemotes")
	end
	return folder
end

function Net.get(name)
	return getFolder():WaitForChild(name)
end

return Net
]=] },
	{ Service = "ReplicatedStorage", Path = "SpinShared/SpinConfig", Class = "ModuleScript", Source = [=[
--[[
	SpinConfig  (ReplicatedStorage.SpinShared.SpinConfig)

	Every tunable value for the Golden Spin / Steel Ball system.
	The server reads this for damage, timing and validation; the client reads
	it for the charge meter and visuals. Change numbers here, not in code.

	Future Spin-based characters can copy this table and pass their own
	config to SpinService.registerKit(...).
]]

local SpinConfig = {}

SpinConfig.Input = {
	ActionName = "SpinCharge",
	Keyboard = Enum.KeyCode.R,
	Gamepad = Enum.KeyCode.ButtonR2,
	MobileButtonTitle = "SPIN",
	MobileButtonPosition = UDim2.new(1, -175, 1, -175),
}

SpinConfig.Charge = {
	MaxHoldTime = 3.0, -- auto-release after holding this long
	WalkSpeedMultiplier = 0.5, -- movement slow while charging (counterplay)
	CancelCooldown = 0.75, -- cooldown if the charge is interrupted

	-- PERFECT SPIN: release between Start and Start + Duration (seconds of charge).
	PerfectWindowStart = 1.35,
	PerfectWindowDuration = 0.22,
	ServerTimingTolerance = 0.05, -- extra slack each side for network jitter

	-- Holding past the perfect window drops the throw back to this level,
	-- so the reward comes from timing, not from holding forever.
	OverchargeLevel = 2,
}

--[[
	Levels: ChargeTime = seconds of charge needed to reach the level.
	Level 3 can only be reached inside the Perfect window.
]]
SpinConfig.Levels = {
	{
		Name = "QUICK SPIN",
		ChargeTime = 0,
		Damage = 7,
		Speed = 120,
		Radius = 1.1,
		Range = 150,
		Knockback = 14,
		Stun = 0.2,
		Cooldown = 2.5,
		BallScale = 1.0,
		Rings = 1,
		TrailWidth = 0.6,
		ShockwaveRadius = 6,
		CameraShake = 0.15,
	},
	{
		Name = "POWER SPIN",
		ChargeTime = 0.6,
		Damage = 13,
		Speed = 135,
		Radius = 1.4,
		Range = 180,
		Knockback = 32,
		Stun = 0.4,
		Cooldown = 4.5,
		BallScale = 1.25,
		Rings = 2,
		TrailWidth = 1.0,
		ShockwaveRadius = 10,
		CameraShake = 0.3,
	},
	{
		Name = "PERFECT SPIN",
		ChargeTime = 1.35, -- keep equal to Charge.PerfectWindowStart
		Damage = 22,
		Speed = 165,
		Radius = 1.9,
		Range = 220,
		Knockback = 55,
		Stun = 0.65,
		Cooldown = 7,
		BallScale = 1.6,
		Rings = 3,
		TrailWidth = 1.6,
		ShockwaveRadius = 16,
		CameraShake = 0.6,
	},
}

SpinConfig.Projectile = {
	MaxActivePerPlayer = 4,
	-- Offset from HumanoidRootPart where the throw starts (right hand side).
	SpawnOffset = CFrame.new(1, 0.8, -1.5),
	MaxAimPitch = 0.75, -- clamp of the aim direction's Y component
}

SpinConfig.Colors = {
	-- Steel Ball (green, from the owner's reference art)
	Ball = Color3.fromRGB(66, 142, 30),
	BallDark = Color3.fromRGB(18, 56, 12),
	BallLight = Color3.fromRGB(196, 236, 92),
	-- Rotation lines drawn around the spinning ball (pink-white in the art)
	SpinLine = Color3.fromRGB(255, 205, 225),
	SpinGlow = Color3.fromRGB(170, 255, 120),
	-- Golden Spin energy (Perfect Spin, shockwaves)
	Gold = Color3.fromRGB(255, 196, 56),
	GoldLight = Color3.fromRGB(255, 238, 160),
	Orange = Color3.fromRGB(255, 130, 30),
	Perfect = Color3.fromRGB(255, 250, 210),
}

--[[
	Sounds: upload the files from /assets/audio (Creator Hub > Asset Manager >
	Import) and paste the ids here as "rbxassetid://123...". Empty = silent.
]]
SpinConfig.Sounds = {
	Charge = "", -- spin_charge.ogg (loop)
	LevelUp = "", -- spin_levelup.ogg
	Perfect = "", -- spin_perfect.ogg
	Release = "", -- spin_release.ogg
	Impact = "", -- spin_impact.ogg
}

SpinConfig.Debug = {
	SpawnTestDummies = true, -- only ever runs inside Roblox Studio
	DummyCount = 3,
	DummyRespawnTime = 3,
}

-- Returns level index (1..3) and whether it was a Perfect release.
function SpinConfig.getLevel(chargeTime, tolerance)
	tolerance = tolerance or 0
	local c = SpinConfig.Charge
	local windowStart = c.PerfectWindowStart - tolerance
	local windowEnd = c.PerfectWindowStart + c.PerfectWindowDuration + tolerance
	if chargeTime >= windowStart and chargeTime <= windowEnd then
		return 3, true
	elseif chargeTime > windowEnd then
		return c.OverchargeLevel, false
	elseif chargeTime >= SpinConfig.Levels[2].ChargeTime then
		return 2, false
	end
	return 1, false
end

return SpinConfig
]=] },
	{ Service = "ReplicatedStorage", Path = "SpinShared/SteelBallModel", Class = "ModuleScript", Source = [=[
--[[
	SteelBallModel  (ReplicatedStorage.SpinShared.SteelBallModel)

	Procedurally builds the Steel Ball from the owner's reference images:
	a glossy green metal sphere with raised hexagon panels (dark outer edge
	plus a bright inner edge, so they read as raised plates), round
	panels, and curved parallel grooves sweeping around the surface.

	SteelBallModel.build(diameter, detailed) -> Model (PrimaryPart = "Core")
	  detailed = false (Low quality) keeps only the hexagon outer edges.

	All parts are visual only: no collision, no queries, no touch events,
	massless, and welded to the Core. Anchor the Core to move it with
	PivotTo, or weld the Core to a hand.

	Swapping in a real mesh later: put a Model named "SteelBall" (with a
	PrimaryPart) in ReplicatedStorage.SpinShared.Assets and build() will
	clone and resize it instead of generating one.
]]

local SpinConfig = require(script.Parent.SpinConfig)

local SteelBallModel = {}

-- Panel layout (unit directions on the ball, angular radius in radians).
-- Kept as data so the look can be tuned without touching the builder.
SteelBallModel.Layout = {
	Hexagons = {
		{ Dir = Vector3.new(-0.45, 0.35, 0.82), Radius = 0.55, Spin = 0.2 },
		{ Dir = Vector3.new(0.6, -0.2, -0.77), Radius = 0.5, Spin = 0.5 },
		{ Dir = Vector3.new(-0.3, -0.85, -0.4), Radius = 0.45, Spin = 0.0 },
	},
	Circles = {
		{ Dir = Vector3.new(0.45, -0.4, 0.8), Radius = 0.3 },
		{ Dir = Vector3.new(0.2, 0.85, -0.45), Radius = 0.35 },
	},
	-- Grooves: arcs of a circle around Axis at angular radius Radius,
	-- from angle From to To (radians).
	Grooves = {
		{ Axis = Vector3.new(0.95, 0.25, 0.15), Radius = 0.5, From = -1.2, To = 1.3 },
		{ Axis = Vector3.new(0.95, 0.25, 0.15), Radius = 0.78, From = -1.0, To = 1.1 },
		{ Axis = Vector3.new(-0.75, 0.15, -0.6), Radius = 0.6, From = 0.6, To = 3.2 },
	},
}

local function visualPart(props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function weld(core, part)
	local w = Instance.new("WeldConstraint")
	w.Part0 = core
	w.Part1 = part
	w.Parent = part
end

-- Two unit vectors perpendicular to dir.
local function basis(dir)
	local helper = math.abs(dir.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local u = dir:Cross(helper).Unit
	local v = dir:Cross(u).Unit
	return u, v
end

-- Point on the unit sphere at angular distance `radius` from `center`, around angle `theta`.
local function around(center, radius, theta)
	local u, v = basis(center)
	return (center * math.cos(radius) + (u * math.cos(theta) + v * math.sin(theta)) * math.sin(radius)).Unit
end

local function fromOverride(diameter)
	local assets = script.Parent:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("SteelBall")
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		local clone = custom:Clone()
		local size = clone:GetExtentsSize()
		local largest = math.max(size.X, size.Y, size.Z)
		if largest > 0 then
			clone:ScaleTo(clone:GetScale() * diameter / largest)
		end
		clone.PrimaryPart.Name = "Core"
		return clone
	end
	return nil
end

function SteelBallModel.build(diameter, detailed)
	diameter = diameter or 1
	if detailed == nil then
		detailed = true
	end

	local override = fromOverride(diameter)
	if override then
		return override
	end

	local colors = SpinConfig.Colors
	local r = diameter / 2

	local model = Instance.new("Model")
	model.Name = "SteelBall"

	local core = visualPart({
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		Color = colors.Ball,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.18,
		Massless = false,
	})
	core.CFrame = CFrame.new()
	core.Parent = model
	model.PrimaryPart = core

	-- Attachments other systems hook effects onto.
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = core
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, r * 0.9, 0)
	top.Parent = core
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -r * 0.9, 0)
	bottom.Parent = core

	-- One straight raised line between two directions on the surface.
	local function line(a, b, width, color, name)
		local lift = r * 1.012
		local pa, pb = a * lift, b * lift
		local mid = (pa + pb) / 2
		local seg = visualPart({
			Name = name,
			Size = Vector3.new(width, width * 0.5, (pb - pa).Magnitude + width * 0.6),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Reflectance = 0.1,
		})
		seg.CFrame = CFrame.lookAt(mid, pb, mid.Unit)
		seg.Parent = model
		weld(core, seg)
	end

	local function polygon(dirCenter, radius, sides, spin, width, color, name)
		local c = dirCenter.Unit
		for i = 0, sides - 1 do
			local a = around(c, radius, spin + i / sides * math.pi * 2)
			local b = around(c, radius, spin + (i + 1) / sides * math.pi * 2)
			line(a, b, width, color, name)
		end
	end

	local layout = SteelBallModel.Layout

	-- Hexagon plates: dark outer edge, bright inner edge.
	for _, hex in ipairs(layout.Hexagons) do
		polygon(hex.Dir, hex.Radius, 6, hex.Spin, diameter * 0.04, colors.BallDark, "HexEdge")
		if detailed then
			polygon(hex.Dir, hex.Radius * 0.84, 6, hex.Spin, diameter * 0.025, colors.BallLight, "HexHighlight")
		end
	end

	if detailed then
		-- Round panels.
		for _, circle in ipairs(layout.Circles) do
			polygon(circle.Dir, circle.Radius, 10, 0, diameter * 0.035, colors.BallDark, "RoundPanel")
		end
		-- Curved grooves.
		for _, groove in ipairs(layout.Grooves) do
			local axis = groove.Axis.Unit
			local steps = 6
			for i = 0, steps - 1 do
				local t0 = groove.From + (groove.To - groove.From) * i / steps
				local t1 = groove.From + (groove.To - groove.From) * (i + 1) / steps
				line(around(axis, groove.Radius, t0), around(axis, groove.Radius, t1), diameter * 0.03, colors.BallDark, "Groove")
			end
		end
	end

	return model
end

return SteelBallModel
]=] },
	{ Service = "ReplicatedStorage", Path = "SpinShared/TuskActRegistry", Class = "ModuleScript", Source = [=[
--[[
	TuskActRegistry  (ReplicatedStorage.SpinShared.TuskActRegistry)

	The list of Tusk Acts: names, slot labels, themes and whether each
	Act is implemented. The server refuses to equip an Act whose
	Implemented flag is false, and the menu shows it as IN DEVELOPMENT
	(locked, not a fake button).

	To add an Act: create ServerScriptService.SpinServer.TuskActs.TuskActN,
	add its client choreography in SpinClient.TuskActVFX.ActN, then set
	Implemented = true here.
]]

local TuskActRegistry = {}

TuskActRegistry.Acts = {
	[1] = {
		Name = "TUSK ACT 1",
		Tagline = "The beginning of Spin",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(90, 230, 255), Secondary = Color3.fromRGB(40, 120, 255) },
		M1 = "NAIL COMBO",
		Abilities = { "NAIL SHOT", "NAIL BARRAGE", "SPINNING NAIL" },
		AbilityKinds = { "Press", "Press", "Hold" }, -- Hold = charge on press, fire on release
		Ultimate = "TUSK AWAKENING",
	},
	[2] = {
		Name = "TUSK ACT 2",
		Tagline = "Wormhole combat",
		Implemented = false,
		Theme = { Primary = Color3.fromRGB(70, 200, 255), Secondary = Color3.fromRGB(30, 80, 220) },
		M1 = "DIMENSIONAL COMBO",
		Abilities = { "WORMHOLE NAIL", "UNDERGROUND PURSUIT", "NAIL DIMENSION" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "DIMENSIONAL STORM",
	},
	[3] = {
		Name = "TUSK ACT 3",
		Tagline = "Master of spatial movement",
		Implemented = false,
		Theme = { Primary = Color3.fromRGB(60, 140, 255), Secondary = Color3.fromRGB(20, 40, 160) },
		M1 = "WORMHOLE STRIKES",
		Abilities = { "DIMENSIONAL STEP", "SPATIAL PURSUIT", "DIMENSIONAL BREAK" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "INFINITE DIMENSION",
	},
	[4] = {
		Name = "TUSK ACT 4",
		Tagline = "Infinite Rotation",
		Implemented = false,
		Theme = { Primary = Color3.fromRGB(255, 200, 70), Secondary = Color3.fromRGB(20, 40, 160) },
		M1 = "INFINITE BARRAGE",
		Abilities = { "GOLDEN SPIN NAIL", "INFINITE ROTATION", "GOLDEN PURSUIT" },
		AbilityKinds = { "Press", "Hold", "Press" },
		Ultimate = "INFINITE ROTATION",
	},
}

function TuskActRegistry.get(act)
	return TuskActRegistry.Acts[act]
end

function TuskActRegistry.isImplemented(act)
	local info = TuskActRegistry.Acts[act]
	return info ~= nil and info.Implemented == true
end

return TuskActRegistry
]=] },
	{ Service = "ReplicatedStorage", Path = "SpinShared/TuskConfig", Class = "ModuleScript", Source = [=[
--[[
	TuskConfig  (ReplicatedStorage.SpinShared.TuskConfig)

	Every tunable number for Tusk. The server uses it for damage, timing,
	ranges and validation; the client uses it for UI and visuals.
	Balance changes go here, never in ability code.
]]

local TuskConfig = {}

---------------------------------------------------------------------------
-- Controls (PC / controller). Mobile uses the on-screen HUD buttons.
---------------------------------------------------------------------------
TuskConfig.Keys = {
	M1 = { Keyboard = Enum.UserInputType.MouseButton1, Gamepad = Enum.KeyCode.ButtonR1 },
	Ability1 = { Keyboard = Enum.KeyCode.One, Gamepad = Enum.KeyCode.ButtonX },
	Ability2 = { Keyboard = Enum.KeyCode.Two, Gamepad = Enum.KeyCode.ButtonY },
	Ability3 = { Keyboard = Enum.KeyCode.Three, Gamepad = Enum.KeyCode.ButtonB },
	Ultimate = { Keyboard = Enum.KeyCode.G, Gamepad = Enum.KeyCode.DPadUp },
	Sneak = { Keyboard = Enum.KeyCode.C, Gamepad = Enum.KeyCode.ButtonL1 },
	ActMenu = { Keyboard = Enum.KeyCode.T, Gamepad = Enum.KeyCode.DPadDown },
}

---------------------------------------------------------------------------
-- Act selection / progression
---------------------------------------------------------------------------
TuskConfig.Progression = {
	-- "Menu":   any implemented Act can be picked from the Act menu (T).
	-- "Unlock": only Acts that IsUnlocked(player, act) approves.
	--           Point IsUnlocked at your existing unlock / quest system.
	Mode = "Menu",
	DefaultAct = 1,
	AutoEquip = true, -- players spawn as Tusk (set false if your game picks movesets elsewhere)
	ShowSelectionMenu = true,
	IsUnlocked = nil, -- function(player, actNumber) -> boolean
	SwitchCooldown = 3, -- seconds between Act switches
}

---------------------------------------------------------------------------
-- Ultimate meter (shared by every Act)
---------------------------------------------------------------------------
TuskConfig.Ultimate = {
	MaxMeter = 100,
	GainPerDamage = 1.6, -- meter gained per point of damage dealt with Tusk
	StudioStartFull = true, -- Studio only: start full so ultimates can be tested
}

---------------------------------------------------------------------------
-- Tusk Sneak (shared by every Act)
---------------------------------------------------------------------------
TuskConfig.Sneak = {
	WalkSpeedMultiplier = 0.45,
	MaxDuration = 8, -- auto-exit after this long
	Cooldown = 4, -- after leaving sneak
	CameraDrop = 1.4, -- studs the camera lowers
	Attack = { -- press M1 while sneaking
		Cooldown = 12,
		FailCooldown = 2, -- no valid target found
		Range = 35,
		ConeDegrees = 75, -- target must be within this cone in front
		BurrowTime = 0.7, -- time underground before emerging
		WarningTime = 0.45, -- the target sees a warning this long before emergence
		EmergeDistance = 3.5, -- studs behind the target
		MaxTargetDrift = 14, -- if the target ran further than this, the attack whiffs
		HitRadius = 7,
		Damage = 12,
		Stun = 0.6,
		Knockback = 18,
		Launch = 38, -- upward velocity
	},
}

---------------------------------------------------------------------------
-- ACT 1 — the beginning of Spin
---------------------------------------------------------------------------
TuskConfig.Act1 = {
	M1 = {
		Interval = 0.3, -- min time between hits
		ResetAfter = 1.1, -- combo resets after this long without hitting
		EndLag = 0.9, -- recovery after the 4th hit
		Windup = 0.11, -- hitbox delay after the swing starts
		HitboxSize = Vector3.new(5, 5, 5.5),
		HitboxForward = 3.2,
		MaxTargets = 3,
		Hits = {
			{ Name = "Tusk Jab", Damage = 3, Stun = 0.45, Knockback = 3 },
			{ Name = "Nail Strike", Damage = 3.5, Stun = 0.45, Knockback = 4 },
			{ Name = "Spinning Assist", Damage = 3, Stun = 0.45, Knockback = 5, Projectile = { Speed = 160, Radius = 0.9, Range = 22 } },
			{ Name = "Shock Finisher", Damage = 6, Stun = 0.5, Knockback = 42, Launch = 10, ShockwaveRadius = 7 },
		},
	},
	NailShot = {
		Cooldown = 4,
		Startup = 0.18,
		Damage = 8,
		Speed = 150,
		Radius = 0.7,
		Range = 160,
		Stun = 0.35,
		Knockback = 10,
	},
	NailBarrage = {
		Cooldown = 9,
		Startup = 0.15,
		Count = 5,
		Interval = 0.09,
		SpreadDegrees = 7,
		Damage = 3,
		Speed = 170,
		Radius = 0.6,
		Range = 140,
		Stun = 0.25,
		Knockback = 4,
	},
	SpinningNail = {
		Cooldown = 10,
		FullChargeAt = 1.2, -- seconds to full charge (golden-blue trail)
		MaxHold = 3, -- auto-release
		WalkSpeedMultiplier = 0.6,
		MinDamage = 8,
		MaxDamage = 19,
		MinSpeed = 120,
		MaxSpeed = 190,
		MinRadius = 0.8,
		MaxRadius = 1.6,
		Range = 200,
		Stun = 0.55,
		Knockback = 38,
	},
	Ultimate = { -- TUSK AWAKENING
		Windup = 1.7, -- cinematic buildup (armored, can't be stunned)
		Radius = 18,
		Damage = 15,
		Stun = 0.6,
		Knockback = 55,
		Launch = 25,
		Duration = 20, -- Awakened state length
		CooldownMultiplier = 0.6, -- ability cooldowns while Awakened
		DamageMultiplier = 1.25, -- nail damage while Awakened
	},
}

---------------------------------------------------------------------------
-- Sound ids. Upload assets/audio/tusk_*.ogg (Creator Hub > Asset Manager)
-- and paste "rbxassetid://..." here. Empty string = silent.
---------------------------------------------------------------------------
TuskConfig.Sounds = {
	Swing = "", -- tusk_swing.ogg
	Hit = "", -- tusk_hit.ogg
	Finisher = "", -- tusk_finisher.ogg
	NailFire = "", -- tusk_nail_fire.ogg
	NailImpact = "", -- tusk_nail_impact.ogg
	ChargeLoop = "", -- tusk_charge_loop.ogg
	ChargeFull = "", -- tusk_charge_full.ogg
	AwakeningBuild = "", -- tusk_awakening_build.ogg
	AwakeningBurst = "", -- tusk_awakening_burst.ogg
	SneakIn = "", -- tusk_sneak_in.ogg
	Burrow = "", -- tusk_burrow.ogg
	Warning = "", -- tusk_warning.ogg
	Emerge = "", -- tusk_emerge.ogg
}

---------------------------------------------------------------------------
-- Optional uploaded animations. Leave "" to use the built-in procedural
-- poses. Paste an id to have that move play your real animation instead.
---------------------------------------------------------------------------
TuskConfig.AnimationIds = {
	Idle = "", -- replaces the character's idle while Tusk is equipped
	Walk = "",
	Run = "",
	Sneak = "",
	M1_1 = "",
	M1_2 = "",
	M1_3 = "",
	M1_4 = "",
	NailShot = "",
	NailBarrage = "",
	SpinningNailCharge = "",
	SpinningNailRelease = "",
	Awakening = "",
	Burrow = "",
	Emerge = "",
}

TuskConfig.Colors = {
	Cyan = Color3.fromRGB(90, 230, 255),
	Blue = Color3.fromRGB(40, 120, 255),
	DeepBlue = Color3.fromRGB(20, 40, 160),
	Ice = Color3.fromRGB(210, 250, 255),
	Gold = Color3.fromRGB(255, 200, 70),
	GoldLight = Color3.fromRGB(255, 240, 170),
	Pink = Color3.fromRGB(236, 110, 196),
	PinkDark = Color3.fromRGB(170, 52, 132),
	Star = Color3.fromRGB(255, 196, 60),
	Heart = Color3.fromRGB(196, 40, 98),
	Metal = Color3.fromRGB(170, 175, 185),
}

return TuskConfig
]=] },
	{ Service = "ReplicatedStorage", Path = "SpinShared/TuskStandModels", Class = "ModuleScript", Source = [=[
--[[
	TuskStandModels  (ReplicatedStorage.SpinShared.TuskStandModels)

	Builds the Tusk Stand for each Act. Built on each client (visual only),
	so Stands never cost server physics or replication.

	TuskStandModels.build(act, scale) -> model, rig
	  rig.Body           root part of the Stand (anchored by the caller)
	  rig.Joints[name]   = { Weld = Weld, Base = CFrame } for animated pieces
	                       (EarL, EarR, Leg1..Leg4). Animate with
	                       Weld.C0 = Base * rotation.
	  rig.NailPoint      Attachment where Tusk's nail energy gathers

	Act 1 (from the owner's reference): small pink egg-shaped body covered
	in gold stars, floppy ears, a big forehead star with a gold pin running
	to a yellow beak, heavy-lidded eyes and four thin legs ending in hearts.

	Using your own model instead: put a Model named "TuskAct1" (PrimaryPart
	set) in ReplicatedStorage.SpinShared.Assets. It is cloned and resized,
	and gets the same idle motion (ears and legs only animate on the
	built-in model).
]]

local TuskConfig = require(script.Parent.TuskConfig)

local TuskStandModels = {}

local colors = TuskConfig.Colors

local function part(model, props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "Ellipsoid" then
			p[k] = v
		end
	end
	if props.Ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere -- fits the part size, so any Size = ellipsoid
		mesh.Parent = p
	end
	p.Parent = model
	return p
end

-- Weld `p` to `body` at local CFrame `cf` (C0 can be animated later).
local function attach(body, p, cf)
	local w = Instance.new("Weld")
	w.Part0 = body
	w.Part1 = p
	w.C0 = cf
	w.Parent = p
	p.CFrame = body.CFrame * cf
	return w
end

local function override(act, scale)
	local assets = script.Parent:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("TuskAct" .. act)
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		local clone = custom:Clone()
		local size = clone:GetExtentsSize()
		local largest = math.max(size.X, size.Y, size.Z)
		if largest > 0 then
			clone:ScaleTo(clone:GetScale() * (2.4 * scale) / largest)
		end
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
				d.Anchored = d == clone.PrimaryPart
			end
		end
		local point = Instance.new("Attachment")
		point.Name = "NailPoint"
		point.Position = Vector3.new(0, 0, -size.Z * 0.5)
		point.Parent = clone.PrimaryPart
		return clone, { Body = clone.PrimaryPart, Joints = {}, NailPoint = point }
	end
	return nil
end

-- Five-point star made of five thin spikes, laid on the surface facing `normal`.
local function star(model, body, center, normal, size, color)
	local up = math.abs(normal.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local base = CFrame.lookAt(center, center + normal, up)
	for i = 0, 4 do
		local spike = part(model, {
			Name = "StarSpike",
			Size = Vector3.new(size * 0.28, size * 0.55, size * 0.04),
			Color = color,
			Ellipsoid = true,
		})
		local cf = base * CFrame.Angles(0, 0, i * math.pi * 2 / 5) * CFrame.new(0, size * 0.22, 0)
		attach(body, spike, cf)
	end
end

local function buildAct1(scale)
	local s = scale
	local model = Instance.new("Model")
	model.Name = "TuskAct1"

	local body = part(model, {
		Name = "Body",
		Size = Vector3.new(1.35, 1.8, 1.25) * s,
		Color = colors.Pink,
		Ellipsoid = true,
		Massless = false,
	})
	body.CFrame = CFrame.new()
	body.Anchored = true
	model.PrimaryPart = body

	local rig = { Body = body, Joints = {} }

	-- Shading belly (darker lower half reads as volume from a distance).
	local belly = part(model, { Name = "Belly", Size = Vector3.new(1.2, 1.1, 1.15) * s, Color = colors.PinkDark, Ellipsoid = true })
	attach(body, belly, CFrame.new(0, -0.35 * s, 0.04 * s))

	-- Eyes: white balls, black pupils, heavy tilted brows (grumpy look).
	for _, side in ipairs({ -1, 1 }) do
		local eye = part(model, { Name = "Eye", Size = Vector3.new(0.32, 0.32, 0.22) * s, Color = Color3.new(1, 1, 1), Ellipsoid = true })
		attach(body, eye, CFrame.new(side * 0.26 * s, 0.12 * s, -0.55 * s))
		local pupil = part(model, { Name = "Pupil", Size = Vector3.new(0.13, 0.13, 0.06) * s, Color = Color3.fromRGB(20, 10, 20), Ellipsoid = true })
		attach(body, pupil, CFrame.new(side * 0.25 * s, 0.1 * s, -0.66 * s))
		local brow = part(model, { Name = "Brow", Size = Vector3.new(0.4, 0.1, 0.12) * s, Color = colors.PinkDark })
		attach(body, brow, CFrame.new(side * 0.26 * s, 0.3 * s, -0.58 * s) * CFrame.Angles(0, 0, side * -0.35))
	end

	-- Beak: elongated yellow ellipsoid pointing forward and down.
	local beak = part(model, { Name = "Beak", Size = Vector3.new(0.2, 0.2, 0.55) * s, Color = colors.Star, Ellipsoid = true })
	attach(body, beak, CFrame.new(0.05 * s, -0.12 * s, -0.75 * s) * CFrame.Angles(-0.55, 0.15, 0))

	-- Forehead star and the gold pin running from it to the beak.
	local starCenter = Vector3.new(-0.18 * s, 0.62 * s, -0.42 * s)
	star(model, body, starCenter, Vector3.new(-0.2, 0.55, -0.8).Unit, 0.5 * s, colors.Star)
	local beakTip = Vector3.new(0.12 * s, -0.32 * s, -0.95 * s)
	local pinLength = (beakTip - starCenter).Magnitude
	local pin = part(model, {
		Name = "Pin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(pinLength, 0.035 * s, 0.035 * s),
		Color = colors.Gold,
		Material = Enum.Material.Metal,
		Reflectance = 0.3,
	})
	-- Cylinder axis is X: build a frame whose RightVector runs star -> beak.
	local mid = (starCenter + beakTip) / 2
	attach(body, pin, CFrame.lookAt(mid, beakTip) * CFrame.Angles(0, math.pi / 2, 0))

	-- Small gold stars scattered over the body.
	local starSpots = {
		Vector3.new(0.55, 0.45, -0.2), Vector3.new(0.6, -0.1, 0.1), Vector3.new(-0.6, 0.0, 0.15),
		Vector3.new(-0.45, -0.55, -0.3), Vector3.new(0.35, -0.6, -0.4), Vector3.new(0.1, 0.75, 0.35),
		Vector3.new(-0.3, 0.4, 0.55), Vector3.new(0.4, 0.1, 0.55), Vector3.new(0.0, -0.75, 0.3),
	}
	for _, spot in ipairs(starSpots) do
		local n = Vector3.new(spot.X / 0.675, spot.Y / 0.9, spot.Z / 0.625).Unit
		local surface = Vector3.new(n.X * 0.675, n.Y * 0.9, n.Z * 0.625) * s * 1.01
		star(model, body, surface, n, 0.22 * s, colors.Star)
	end

	-- Floppy ears (animated).
	local ears = {
		{ Name = "EarL", Base = CFrame.new(-0.45 * s, 0.75 * s, 0) * CFrame.Angles(0, 0, 0.9), Size = Vector3.new(0.38, 1.25, 0.12) },
		{ Name = "EarR", Base = CFrame.new(0.5 * s, 0.65 * s, 0.05 * s) * CFrame.Angles(0.2, 0, -1.35), Size = Vector3.new(0.34, 1.1, 0.12) },
	}
	for _, e in ipairs(ears) do
		local ear = part(model, { Name = e.Name, Size = e.Size * s, Color = colors.Pink, Ellipsoid = true })
		local inner = part(model, { Name = e.Name .. "Inner", Size = e.Size * s * Vector3.new(0.55, 0.75, 0.5), Color = colors.PinkDark, Ellipsoid = true })
		local offset = CFrame.new(0, e.Size.Y * s * 0.45, 0)
		local w = attach(body, ear, e.Base * offset)
		attach(ear, inner, CFrame.new(0, 0, -0.03 * s))
		rig.Joints[e.Name] = { Weld = w, Base = e.Base, Offset = offset }
	end

	-- Little fin spikes around the silhouette.
	local fins = {
		CFrame.new(-0.62 * s, 0.25 * s, 0) * CFrame.Angles(0, 0, 1.2),
		CFrame.new(0.66 * s, 0.2 * s, -0.1 * s) * CFrame.Angles(0, 0, -1.3),
		CFrame.new(-0.55 * s, -0.4 * s, 0) * CFrame.Angles(0, 0, 2.0),
		CFrame.new(0.58 * s, -0.45 * s, 0) * CFrame.Angles(0, 0, -2.1),
	}
	for _, cf in ipairs(fins) do
		local fin = part(model, { Name = "Fin", Size = Vector3.new(0.16, 0.42, 0.08) * s, Color = colors.Pink, Ellipsoid = true })
		attach(body, fin, cf * CFrame.new(0, 0.18 * s, 0))
	end

	-- Four thin legs ending in hearts (animated swing).
	for i = 1, 4 do
		local x = (-1.5 + (i - 1)) * 0.22 * s
		local base = CFrame.new(x, -0.78 * s, (i % 2 == 0 and 0.12 or -0.1) * s)
		local legLength = (0.55 + (i % 2) * 0.12) * s
		local leg = part(model, {
			Name = "Leg" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(legLength, 0.05 * s, 0.05 * s),
			Color = colors.Pink,
		})
		-- Cylinder axis is X; rotate so it hangs down from the joint.
		local offset = CFrame.new(0, -legLength / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local w = attach(body, leg, base * offset)
		rig.Joints["Leg" .. i] = { Weld = w, Base = base, Offset = offset }

		-- Heart foot: two lobes and a point, attached to the leg's bottom end.
		local footCF = CFrame.new(-legLength / 2 - 0.12 * s, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2)
		for _, side in ipairs({ -1, 1 }) do
			local lobe = part(model, { Name = "HeartLobe", Size = Vector3.new(0.2, 0.2, 0.1) * s, Color = colors.Heart, Ellipsoid = true })
			attach(leg, lobe, footCF * CFrame.new(side * 0.075 * s, 0.03 * s, 0))
		end
		local point = part(model, { Name = "HeartPoint", Size = Vector3.new(0.2, 0.2, 0.1) * s, Color = colors.Heart, Ellipsoid = true })
		attach(leg, point, footCF * CFrame.new(0, -0.08 * s, 0) * CFrame.Angles(0, 0, math.pi / 4))
	end

	local nailPoint = Instance.new("Attachment")
	nailPoint.Name = "NailPoint"
	nailPoint.Position = Vector3.new(0, -0.1 * s, -0.9 * s)
	nailPoint.Parent = body
	rig.NailPoint = nailPoint

	return model, rig
end

local builders = {
	[1] = buildAct1,
}

function TuskStandModels.build(act, scale)
	scale = scale or 1
	local model, rig = override(act, scale)
	if model then
		return model, rig
	end
	local builder = builders[act]
	if not builder then
		return nil
	end
	return builder(scale)
end

return TuskStandModels
]=] },
	{ Service = "ReplicatedStorage", Path = "SpinShared/VFXQuality", Class = "ModuleScript", Source = [=[
--[[
	VFXQuality  (ReplicatedStorage.SpinShared.VFXQuality)

	Per-player visual quality. Purely client-side: it never changes gameplay.
	Every effect asks VFXQuality.get() before spawning detail.
]]

local VFXQuality = {}

VFXQuality.Presets = {
	Low = {
		Particles = 0.3, -- multiplier on particle counts
		RingSegments = 12, -- beam segments per energy ring
		Grooves = false, -- steel ball surface grooves
		Afterimages = false,
		ScreenEffects = false, -- speed lines, FOV punch
		ImpactFrames = false,
		Lights = false,
		MaxActiveEffects = 12,
		ShakeScale = 0.6,
	},
	Medium = {
		Particles = 0.65,
		RingSegments = 18,
		Grooves = true,
		Afterimages = false,
		ScreenEffects = true,
		ImpactFrames = false,
		Lights = true,
		MaxActiveEffects = 24,
		ShakeScale = 1,
	},
	High = {
		Particles = 1,
		RingSegments = 28,
		Grooves = true,
		Afterimages = true,
		ScreenEffects = true,
		ImpactFrames = true,
		Lights = true,
		MaxActiveEffects = 40,
		ShakeScale = 1,
	},
}

VFXQuality.Order = { "Low", "Medium", "High" }

local current = "Medium"
local changed = Instance.new("BindableEvent")
VFXQuality.Changed = changed.Event

function VFXQuality.get()
	return VFXQuality.Presets[current], current
end

function VFXQuality.set(name)
	if VFXQuality.Presets[name] and name ~= current then
		current = name
		changed:Fire(name)
	end
end

function VFXQuality.cycle()
	for i, name in ipairs(VFXQuality.Order) do
		if name == current then
			VFXQuality.set(VFXQuality.Order[i % #VFXQuality.Order + 1])
			return current
		end
	end
	return current
end

return VFXQuality
]=] },
	{ Service = "ReplicatedStorage", Path = "SpinShared/WreckingBallModel", Class = "ModuleScript", Source = [=[
--[[
	WreckingBallModel  (ReplicatedStorage.SpinShared.WreckingBallModel)

	Procedurally builds a Wrecking Ball from the owner's reference image:
	a glossy orange metal sphere, ten raised gold studs sitting in darker
	gold collars, and a dark seam groove wrapping around the surface.
	Not used yet: kept for the Wrecking Ball phase.

	WreckingBallModel.build(diameter, withGrooves) -> Model (PrimaryPart = "Core")

	All parts are visual only: no collision, no queries, no touch events,
	massless, and welded to the Core. Anchor the Core to move it with
	PivotTo, or weld the Core to a hand.

	Swapping in a real mesh later: put a Model named "WreckingBall" (with a
	PrimaryPart) in ReplicatedStorage.SpinShared.Assets and build() will
	clone it instead of generating one.
]]

local WreckingBallModel = {}

WreckingBallModel.Colors = {
	Ball = Color3.fromRGB(226, 96, 24),
	BallDark = Color3.fromRGB(150, 52, 12),
	Stud = Color3.fromRGB(255, 205, 70),
}

local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))
local STUD_COUNT = 10
local SEAM_SEGMENTS = 22

local function visualPart(props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function weld(core, part)
	local w = Instance.new("WeldConstraint")
	w.Part0 = core
	w.Part1 = part
	w.Parent = part
end

local function fromOverride(diameter)
	local assets = script.Parent:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("WreckingBall")
	if custom and custom:IsA("Model") and custom.PrimaryPart then
		local clone = custom:Clone()
		local size = clone:GetExtentsSize()
		local largest = math.max(size.X, size.Y, size.Z)
		if largest > 0 then
			clone:ScaleTo(clone:GetScale() * diameter / largest)
		end
		clone.PrimaryPart.Name = "Core"
		return clone
	end
	return nil
end

function WreckingBallModel.build(diameter, withGrooves)
	diameter = diameter or 1
	if withGrooves == nil then
		withGrooves = true
	end

	local override = fromOverride(diameter)
	if override then
		return override
	end

	local colors = WreckingBallModel.Colors
	local r = diameter / 2

	local model = Instance.new("Model")
	model.Name = "WreckingBall"

	local core = visualPart({
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		Color = colors.Ball,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.2,
		Massless = false,
	})
	core.CFrame = CFrame.new()
	core.Parent = model
	model.PrimaryPart = core

	-- Attachments other systems hook effects onto.
	local center = Instance.new("Attachment")
	center.Name = "Center"
	center.Parent = core
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, r * 0.9, 0)
	top.Parent = core
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -r * 0.9, 0)
	bottom.Parent = core

	-- Gold studs on a Fibonacci sphere so they spread evenly.
	for i = 0, STUD_COUNT - 1 do
		local y = 1 - (i + 0.5) / STUD_COUNT * 2
		local ring = math.sqrt(1 - y * y)
		local theta = i * GOLDEN_ANGLE
		local dir = Vector3.new(math.cos(theta) * ring, y, math.sin(theta) * ring)
		local up = math.abs(dir.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)

		local collar = visualPart({
			Name = "StudCollar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(diameter * 0.05, diameter * 0.2, diameter * 0.2),
			Color = colors.BallDark:Lerp(colors.Stud, 0.35),
			Material = Enum.Material.Metal,
			Reflectance = 0.1,
		})
		-- Cylinder axis is X, so point RightVector along the surface normal.
		local right = dir
		local back = right:Cross(up).Unit
		local realUp = back:Cross(right).Unit
		collar.CFrame = CFrame.fromMatrix(dir * r * 0.985, right, realUp)
		collar.Parent = model
		weld(core, collar)

		local stud = visualPart({
			Name = "Stud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(diameter * 0.15, diameter * 0.15, diameter * 0.15),
			Color = colors.Stud,
			Material = Enum.Material.Metal,
			Reflectance = 0.35,
		})
		stud.CFrame = CFrame.new(dir * r * 1.01)
		stud.Parent = model
		weld(core, stud)
	end

	-- Seam groove: a wave wrapping the ball like a tennis-ball seam.
	if withGrooves then
		local function seamPoint(t)
			local lon = t * math.pi * 2
			local lat = 0.55 * math.sin(2 * lon)
			return Vector3.new(math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon)) * r * 1.003
		end
		for i = 0, SEAM_SEGMENTS - 1 do
			local a = seamPoint(i / SEAM_SEGMENTS)
			local b = seamPoint((i + 1) / SEAM_SEGMENTS)
			local mid = (a + b) / 2
			local len = (b - a).Magnitude
			local seg = visualPart({
				Name = "Groove",
				Size = Vector3.new(diameter * 0.035, diameter * 0.012, len * 1.08),
				Color = colors.BallDark,
				Material = Enum.Material.SmoothPlastic,
			})
			seg.CFrame = CFrame.lookAt(mid, b, mid.Unit)
			seg.Parent = model
			weld(core, seg)
		end
	end

	-- Everything was laid out around the origin; move the model as one piece from here on.
	return model
end

return WreckingBallModel
]=] },
	{ Service = "ServerScriptService", Path = "SpinServer", Class = "Script", Source = [=[
--[[
	SpinServer  (ServerScriptService.SpinServer — Script)
	Boots every server system: Golden Spin, Tusk, NPCs and Studio test dummies.
]]

local ProjectileService = require(script.ProjectileService)
local SpinService = require(script.SpinService)
local TuskService = require(script.TuskService)
local NPCService = require(script.NPCService)
local TestDummies = require(script.TestDummies)

-- Shared projectile budget (Tusk's barrage fires several nails at once).
ProjectileService.MaxActivePerPlayer = 12

SpinService.init()
TuskService.init()
NPCService.init()
TestDummies.init()
]=] },
	{ Service = "ServerScriptService", Path = "SpinServer/CombatAdapter", Class = "ModuleScript", Source = [=[
--[[
	CombatAdapter  (ServerScriptService.SpinServer.CombatAdapter)

	THE ONE PLACE the Spin system touches combat. If SPIN BATTLEGROUNDS
	already has a combat framework (damage, stun, block), plug it into the
	Hooks table below instead of letting this file use its defaults. That
	way there is never a second, competing combat system.

	Example (in your own server code, before players join):
		local Adapter = require(ServerScriptService.SpinServer.CombatAdapter)
		Adapter.Hooks.ApplyDamage = function(attacker, humanoid, amount, info)
			YourCombat.Damage(attacker, humanoid, amount)
		end
		Adapter.Hooks.IsBlocking = function(character)
			return YourCombat.IsBlocking(character)
		end
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Net = require(game:GetService("ReplicatedStorage").SpinShared.Net)
local FX = Net.get("SpinFX")

local Adapter = {}

Adapter.Settings = {
	FriendlyFire = false, -- same-Team players can't hit each other
	BlockAttribute = "Blocking", -- character attribute your block sets
	BlockDamageMultiplier = 0.35,
	BlockKnockbackMultiplier = 0.3,
	IFrameAttribute = "IFrames", -- character attribute = invulnerable (dashes etc.)
	ArmorAttribute = "Armored", -- character attribute = takes damage but no stun/knockback (ult wind-ups)
	MaxKnockback = 90, -- hard cap so no move can fling players across the map
	MaxStun = 1.0, -- hard cap on any single stun
	StunAttribute = "Stunned",
	StunWalkSpeedMultiplier = 0.15,
	StunImmunityAfter = 0.5, -- seconds after a stun ends where no new stun applies
	KnockbackDuration = 0.18,
}

-- Optional overrides. Leave nil to use the defaults in this file.
Adapter.Hooks = {
	ApplyDamage = nil, -- function(attackerPlayer, humanoid, amount, info)
	ApplyStun = nil, -- function(humanoid, duration) -> applied:boolean
	IsBlocking = nil, -- function(character) -> boolean
	CanAct = nil, -- function(player) -> boolean (extra checks: ragdoll, menus...)
	CanBeHit = nil, -- function(attackerPlayer, targetCharacter) -> boolean
}

local moveMods = setmetatable({}, { __mode = "k" }) -- humanoid -> { mods = {}, product = 1 }
local stunState = setmetatable({}, { __mode = "k" }) -- humanoid -> { token, immuneUntil }

function Adapter.getAlive(player)
	local character = player and player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end
	return character, humanoid, root
end

function Adapter.isStunned(character)
	return character:GetAttribute(Adapter.Settings.StunAttribute) == true
end

function Adapter.canAct(player)
	local character = Adapter.getAlive(player)
	if not character then
		return false
	end
	if Adapter.isStunned(character) then
		return false
	end
	if Adapter.Hooks.CanAct and not Adapter.Hooks.CanAct(player) then
		return false
	end
	return true
end

function Adapter.canBeHit(attackerPlayer, targetCharacter)
	if not targetCharacter or (attackerPlayer and targetCharacter == attackerPlayer.Character) then
		return false
	end
	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	if targetCharacter:GetAttribute(Adapter.Settings.IFrameAttribute) == true then
		return false
	end
	if targetCharacter:FindFirstChildOfClass("ForceField") then
		return false
	end
	if not Adapter.Settings.FriendlyFire and attackerPlayer then
		local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
		if targetPlayer and not attackerPlayer.Neutral and not targetPlayer.Neutral and targetPlayer.Team == attackerPlayer.Team then
			return false
		end
	end
	if Adapter.Hooks.CanBeHit and not Adapter.Hooks.CanBeHit(attackerPlayer, targetCharacter) then
		return false
	end
	return true
end

-- Stackable walk-speed multipliers keyed by source ("SpinCharge", "Stun"...).
function Adapter.setMoveModifier(humanoid, key, multiplier)
	local state = moveMods[humanoid]
	if not state then
		state = { mods = {}, product = 1 }
		moveMods[humanoid] = state
	end
	local base = humanoid.WalkSpeed / state.product
	state.mods[key] = multiplier
	local product = 1
	for _, m in pairs(state.mods) do
		product = product * m
	end
	state.product = product
	humanoid.WalkSpeed = base * product
end

function Adapter.isBlocking(character)
	if Adapter.Hooks.IsBlocking then
		return Adapter.Hooks.IsBlocking(character) == true
	end
	return character:GetAttribute(Adapter.Settings.BlockAttribute) == true
end

function Adapter.applyStun(humanoid, duration)
	duration = math.min(duration, Adapter.Settings.MaxStun)
	if duration <= 0 then
		return false
	end
	if humanoid.Parent and humanoid.Parent:GetAttribute(Adapter.Settings.ArmorAttribute) == true then
		return false
	end
	if Adapter.Hooks.ApplyStun then
		return Adapter.Hooks.ApplyStun(humanoid, duration)
	end
	local character = humanoid.Parent
	local state = stunState[humanoid] or { token = 0, immuneUntil = 0 }
	stunState[humanoid] = state
	local now = os.clock()
	if now < state.immuneUntil and not Adapter.isStunned(character) then
		return false -- anti stun-lock
	end
	state.token = state.token + 1
	local token = state.token
	character:SetAttribute(Adapter.Settings.StunAttribute, true)
	Adapter.setMoveModifier(humanoid, "Stun", Adapter.Settings.StunWalkSpeedMultiplier)
	task.delay(duration, function()
		if state.token ~= token or not humanoid.Parent then
			return
		end
		character:SetAttribute(Adapter.Settings.StunAttribute, nil)
		Adapter.setMoveModifier(humanoid, "Stun", nil)
		state.immuneUntil = os.clock() + Adapter.Settings.StunImmunityAfter
	end)
	return true
end

function Adapter.applyKnockback(character, direction, strength, upward)
	local root = character:FindFirstChild("HumanoidRootPart")
	strength = math.min(strength or 0, Adapter.Settings.MaxKnockback)
	upward = upward or strength * 0.3
	if not root or (strength <= 0 and upward <= 0) then
		return
	end
	if character:GetAttribute(Adapter.Settings.ArmorAttribute) == true then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		flat = -root.CFrame.LookVector
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "SpinKnockback"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = flat.Unit * strength + Vector3.new(0, math.min(upward, Adapter.Settings.MaxKnockback), 0)
	velocity.Parent = attachment
	Debris:AddItem(attachment, Adapter.Settings.KnockbackDuration)
end

--[[
	dealHit: the only entry point for Spin damage. Server only.
	info = { Damage, Stun, Knockback, Launch?, Direction, Position, Level, Perfect, Source }
	Returns: hit:boolean, damageDealt:number
]]
function Adapter.dealHit(attackerPlayer, targetCharacter, info)
	if not Adapter.canBeHit(attackerPlayer, targetCharacter) then
		return false
	end
	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	local blocked = Adapter.isBlocking(targetCharacter)
	local s = Adapter.Settings

	local damage = info.Damage * (blocked and s.BlockDamageMultiplier or 1)
	local knockback = info.Knockback * (blocked and s.BlockKnockbackMultiplier or 1)

	if Adapter.Hooks.ApplyDamage then
		Adapter.Hooks.ApplyDamage(attackerPlayer, humanoid, damage, info)
	else
		humanoid:TakeDamage(damage)
	end
	if not blocked then
		Adapter.applyStun(humanoid, info.Stun or 0)
	end
	local launch = info.Launch and info.Launch * (blocked and s.BlockKnockbackMultiplier or 1) or nil
	Adapter.applyKnockback(targetCharacter, info.Direction, knockback, launch)

	FX:FireAllClients("Hit", {
		Position = info.Position,
		Level = info.Level,
		Perfect = info.Perfect,
		Blocked = blocked,
		Victim = targetCharacter,
		Source = info.Source,
		AttackerId = attackerPlayer and attackerPlayer.UserId or 0,
	})
	if attackerPlayer then
		FX:FireClient(attackerPlayer, "Damage", {
			Position = info.Position,
			Amount = math.floor(damage + 0.5),
			Blocked = blocked,
			Perfect = info.Perfect,
		})
	end
	return true, damage
end

return Adapter
]=] },
	{ Service = "ServerScriptService", Path = "SpinServer/CooldownService", Class = "ModuleScript", Source = [=[
--[[
	CooldownService  (ServerScriptService.SpinServer.CooldownService)
	Server-owned cooldowns. Clients only ever display what the server says.
	Reusable by any ability: CooldownService.start(player, "AbilityKey", seconds)
]]

local Players = game:GetService("Players")

local CooldownService = {}
local readyAt = {} -- [player] = { [key] = os.clock() time when ready }

function CooldownService.remaining(player, key)
	local list = readyAt[player]
	local t = list and list[key]
	if not t then
		return 0
	end
	return math.max(0, t - os.clock())
end

function CooldownService.isReady(player, key)
	return CooldownService.remaining(player, key) <= 0
end

function CooldownService.start(player, key, duration)
	local list = readyAt[player]
	if not list then
		list = {}
		readyAt[player] = list
	end
	list[key] = os.clock() + duration
end

function CooldownService.reset(player, key)
	if readyAt[player] then
		readyAt[player][key] = nil
	end
end

Players.PlayerRemoving:Connect(function(player)
	readyAt[player] = nil
end)

return CooldownService
]=] },
	{ Service = "ServerScriptService", Path = "SpinServer/NPCService", Class = "ModuleScript", Source = [=[
--[[
	NPCService  (ServerScriptService.SpinServer.NPCService)

	Turns the markers in workspace.SBRMap.NPCSpawns (made by SBRMapBuilder)
	into living NPCs:
	  * R15 characters with role-based outfits colours and a name tag
	  * "Talk" ProximityPrompt: cycles through that NPC's lines
	  * Racers jog the track waypoints; others wander near home
	  * occasional ambient lines to nearby players
	  * respawn if they fall out of the world
	NPCs carry the IFrames attribute, so no attack can hurt them, and an
	"NPC" attribute so other systems can recognise them.
	Does nothing if the map isn't in the place.
]]

local Players = game:GetService("Players")

local Net = require(game:GetService("ReplicatedStorage").SpinShared.Net)

local NPCService = {}

local ROLE_STYLE = {
	Announcer = { Torso = Color3.fromRGB(150, 30, 40), Legs = Color3.fromRGB(40, 35, 30), Speed = 0 },
	Official = { Torso = Color3.fromRGB(40, 50, 80), Legs = Color3.fromRGB(30, 30, 35), Speed = 8 },
	Racer = { Torso = Color3.fromRGB(70, 120, 170), Legs = Color3.fromRGB(110, 80, 50), Speed = 16 },
	Guard = { Torso = Color3.fromRGB(110, 80, 50), Legs = Color3.fromRGB(50, 40, 30), Speed = 9 },
	Spectator = { Torso = Color3.fromRGB(160, 140, 100), Legs = Color3.fromRGB(80, 60, 45), Speed = 7 },
}
local SKIN = { Color3.fromRGB(234, 184, 146), Color3.fromRGB(204, 142, 105), Color3.fromRGB(160, 105, 75), Color3.fromRGB(110, 70, 50) }

local npcs = {}
local WorldFX

local function splitLines(s)
	local lines = {}
	for line in string.gmatch(s or "", "[^|]+") do
		table.insert(lines, line)
	end
	return lines
end

local function say(npc, line, toPlayer)
	local payload = { NPC = npc.Model, Text = line }
	if toPlayer then
		WorldFX:FireClient(toPlayer, "NPCSay", payload)
	else
		WorldFX:FireAllClients("NPCSay", payload)
	end
end

local function spawnNPC(marker, waypoints, index)
	local role = marker:GetAttribute("Role") or "Spectator"
	local style = ROLE_STYLE[role] or ROLE_STYLE.Spectator
	local description = Instance.new("HumanoidDescription")
	local skin = SKIN[(index % #SKIN) + 1]
	description.HeadColor = skin
	description.LeftArmColor = style.Torso
	description.RightArmColor = style.Torso
	description.TorsoColor = style.Torso
	description.LeftLegColor = style.Legs
	description.RightLegColor = style.Legs
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[NPCService] could not create NPC:", model)
		return nil
	end
	local displayName = marker:GetAttribute("DisplayName") or marker.Name
	model.Name = displayName
	model:SetAttribute("NPC", true)
	model:SetAttribute("IFrames", true)
	model:SetAttribute("Role", role)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = displayName
	humanoid.NameDisplayDistance = 40
	humanoid.WalkSpeed = style.Speed
	humanoid.BreakJointsOnDeath = false
	local home = marker.Position + Vector3.new(0, 3, 0)
	model:PivotTo(CFrame.new(home) * CFrame.Angles(0, math.rad(index * 47), 0))
	model.Parent = marker.Parent.Parent:FindFirstChild("NPCs") or marker.Parent.Parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = displayName
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = model:WaitForChild("HumanoidRootPart")

	local npc = {
		Model = model,
		Humanoid = humanoid,
		Marker = marker,
		Home = home,
		Role = role,
		Wander = marker:GetAttribute("WanderRadius") or 0,
		Lines = splitLines(marker:GetAttribute("Lines")),
		LineIndex = 0,
		NextMove = os.clock() + math.random() * 4,
		Waypoint = 1,
		Waypoints = waypoints,
		Index = index,
		Talking = 0,
	}
	prompt.Triggered:Connect(function(player)
		if #npc.Lines == 0 then
			return
		end
		npc.LineIndex = npc.LineIndex % #npc.Lines + 1
		npc.Talking = os.clock() + 4
		humanoid:MoveTo(model.HumanoidRootPart.Position) -- stop and chat
		local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if playerRoot then
			local pos = model.HumanoidRootPart.Position
			model:PivotTo(CFrame.lookAt(pos, Vector3.new(playerRoot.Position.X, pos.Y, playerRoot.Position.Z)))
		end
		say(npc, npc.Lines[npc.LineIndex], nil)
	end)
	return npc
end

local function think(npc, now)
	local model = npc.Model
	local root = model.Parent and model:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if root.Position.Y < -60 then
		model:PivotTo(CFrame.new(npc.Home)) -- fell out of the world
		return
	end
	if now < npc.Talking or now < npc.NextMove then
		return
	end
	if npc.Role == "Racer" and #npc.Waypoints > 0 then
		local wp = npc.Waypoints[npc.Waypoint]
		npc.Humanoid:MoveTo(wp.Position + Vector3.new(npc.Index % 2 == 0 and 3 or -3, 0, 0))
		if (root.Position - wp.Position).Magnitude < 8 then
			npc.Waypoint = npc.Waypoint % #npc.Waypoints + 1
		end
		npc.NextMove = now + 0.5
	elseif npc.Wander > 0 then
		local angle = math.random() * math.pi * 2
		local dist = math.random() * npc.Wander
		npc.Humanoid:MoveTo(npc.Home + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist))
		npc.NextMove = now + 4 + math.random() * 5
	else
		npc.NextMove = now + 10
	end
end

-- Ambient line from an NPC close to a player, every so often.
local function ambientChatter()
	local candidates = {}
	for _, npc in ipairs(npcs) do
		local root = npc.Model:FindFirstChild("HumanoidRootPart")
		if root and #npc.Lines > 0 then
			for _, player in ipairs(Players:GetPlayers()) do
				local pr = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if pr and (pr.Position - root.Position).Magnitude < 45 then
					table.insert(candidates, npc)
					break
				end
			end
		end
	end
	if #candidates > 0 then
		local npc = candidates[math.random(1, #candidates)]
		say(npc, npc.Lines[math.random(1, #npc.Lines)], nil)
	end
end

function NPCService.init()
	WorldFX = Net.get("WorldFX")
	task.spawn(function()
		local map = workspace:FindFirstChild("SBRMap") or workspace:WaitForChild("SBRMap", 10)
		local spawns = map and map:FindFirstChild("NPCSpawns")
		if not spawns then
			return -- no map in this place: nothing to do
		end
		local container = Instance.new("Folder")
		container.Name = "NPCs"
		container.Parent = map
		local waypoints = {}
		local wpFolder = map:FindFirstChild("RacerWaypoints")
		if wpFolder then
			waypoints = wpFolder:GetChildren()
			table.sort(waypoints, function(a, b)
				return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
			end)
		end
		for i, marker in ipairs(spawns:GetChildren()) do
			local npc = spawnNPC(marker, waypoints, i)
			if npc then
				table.insert(npcs, npc)
			end
		end
		-- One shared low-frequency loop for all NPC brains (no per-NPC Heartbeat).
		local nextChatter = os.clock() + 20
		while true do
			local now = os.clock()
			for _, npc in ipairs(npcs) do
				think(npc, now)
			end
			if now >= nextChatter then
				nextChatter = now + 20 + math.random() * 20
				ambientChatter()
			end
			task.wait(0.5)
		end
	end)
end

return NPCService
]=] },
	{ Service = "ServerScriptService", Path = "SpinServer/ProjectileService", Class = "ModuleScript", Source = [=[
--[[
	ProjectileService  (ServerScriptService.SpinServer.ProjectileService)

	Server-simulated projectiles. The server owns position, collision and
	hits; clients only draw a matching visual (told via SpinFX
	"ProjectileSpawn" / "ProjectileEnd"). No physics parts are created on
	the server, so many projectiles at once stay cheap.

	Reusable for nails, wrecking balls, etc.:
		ProjectileService.fire(owner, {
			Kind = "SteelBall", Origin = Vector3, Direction = unit Vector3,
			Speed = 120, Radius = 1, Range = 150,
			Visual = { ...any data the client effect needs... },
			OnHit = function(targetCharacter, position, projectile) end,
		})
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Net = require(game:GetService("ReplicatedStorage").SpinShared.Net)
local Adapter = require(script.Parent.CombatAdapter)

local FX = Net.get("SpinFX")

local ProjectileService = {}
ProjectileService.MaxActivePerPlayer = 4

local active = {}
local countByPlayer = {}
local nextId = 0

local function characterFromPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function finish(p, position, normal, hitCharacter)
	if not active[p.Id] then
		return
	end
	active[p.Id] = nil
	if p.Owner then
		countByPlayer[p.Owner] = math.max(0, (countByPlayer[p.Owner] or 1) - 1)
	end
	if hitCharacter and p.OnHit then
		local ok, err = pcall(p.OnHit, hitCharacter, position, p)
		if not ok then
			warn("[ProjectileService] OnHit error:", err)
		end
	end
	FX:FireAllClients("ProjectileEnd", {
		Id = p.Id,
		Kind = p.Kind,
		Position = position,
		Normal = normal or Vector3.new(0, 1, 0),
		HitCharacter = hitCharacter ~= nil,
		OwnerId = p.OwnerId,
		Visual = p.Visual,
	})
end

local function ignore(p, instance)
	local list = p.Params.FilterDescendantsInstances
	table.insert(list, instance)
	p.Params.FilterDescendantsInstances = list
end

-- Point-blank check: Spherecast misses parts already inside the start sphere.
local function overlapAtStart(p)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = p.Params.FilterDescendantsInstances
	for _, part in ipairs(workspace:GetPartBoundsInRadius(p.Position, p.Radius, overlap)) do
		local character = characterFromPart(part)
		if character and Adapter.canBeHit(p.Owner, character) then
			return character, part.Position
		end
	end
	return nil
end

function ProjectileService.activeCount(player)
	return countByPlayer[player] or 0
end

function ProjectileService.fire(owner, spec)
	if owner and ProjectileService.activeCount(owner) >= ProjectileService.MaxActivePerPlayer then
		return nil
	end
	nextId = nextId + 1

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local filter = {}
	if owner and owner.Character then
		table.insert(filter, owner.Character)
	end
	params.FilterDescendantsInstances = filter

	local p = {
		Id = nextId,
		Owner = owner,
		OwnerId = owner and owner.UserId or 0,
		Kind = spec.Kind or "Projectile",
		Position = spec.Origin,
		Direction = spec.Direction.Unit,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Traveled = 0,
		Params = params,
		OnHit = spec.OnHit,
		Visual = spec.Visual or {},
	}
	active[p.Id] = p
	if owner then
		countByPlayer[owner] = (countByPlayer[owner] or 0) + 1
	end

	FX:FireAllClients("ProjectileSpawn", {
		Id = p.Id,
		Kind = p.Kind,
		Origin = p.Position,
		Direction = p.Direction,
		Speed = p.Speed,
		Range = p.Range,
		OwnerId = owner and owner.UserId or 0,
		ServerTime = workspace:GetServerTimeNow(),
		Visual = p.Visual,
	})

	local character, position = overlapAtStart(p)
	if character then
		finish(p, position, nil, character)
	end
	return p.Id
end

RunService.Heartbeat:Connect(function(dt)
	for _, p in pairs(active) do
		local step = math.min(p.Speed * dt, p.Range - p.Traveled)
		if step <= 0.01 then
			finish(p, p.Position, nil, nil)
		else
			local result = workspace:Spherecast(p.Position, p.Radius, p.Direction * step, p.Params)
			if result then
				local character = characterFromPart(result.Instance)
				if character then
					if Adapter.canBeHit(p.Owner, character) then
						finish(p, result.Position, result.Normal, character)
					else
						ignore(p, character) -- ally / i-frames / dead: pass through
					end
				else
					finish(p, result.Position, result.Normal, nil) -- wall / ground
				end
			else
				p.Position = p.Position + p.Direction * step
				p.Traveled = p.Traveled + step
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	countByPlayer[player] = nil
	for _, p in pairs(active) do
		if p.Owner == player then
			p.Owner = nil
			p.OnHit = nil
			finish(p, p.Position, nil, nil)
		end
	end
end)

return ProjectileService
]=] },
	{ Service = "ServerScriptService", Path = "SpinServer/SpinService", Class = "ModuleScript", Source = [=[
--[[
	SpinService  (ServerScriptService.SpinServer.SpinService)

	Server authority for the charge-based Golden Spin throw.

	Flow:
	  client "Start"            -> validate, mark charging, slow the player,
	                               set character attribute SpinChargeStart
	                               (every client reads it to draw the charge)
	  client "Release", aimDir  -> server measures charge time itself,
	                               picks the level, starts the cooldown,
	                               fires a server projectile
	  "Cancel" / stun / death   -> charge ends, short cooldown

	The client never sends damage, level, position or timing. It only sends
	"I pressed" / "I let go" and an aim direction, which is sanitised.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").SpinShared
local SpinConfig = require(Shared.SpinConfig)
local Net = require(Shared.Net)
local Adapter = require(script.Parent.CombatAdapter)
local Cooldowns = require(script.Parent.CooldownService)
local Projectiles = require(script.Parent.ProjectileService)

local Request = Net.get("SpinRequest")
local FX = Net.get("SpinFX")

local SpinService = {}

local COOLDOWN_KEY = "GoldenSpin"
local RATE_LIMIT = 10 -- requests per second per player

local states = {} -- [player] = { Charging, Start, Token, Humanoid, Character }
local rate = {} -- [player] = { WindowStart, Count }

local function rateLimited(player)
	local r = rate[player]
	local now = os.clock()
	if not r or now - r.WindowStart >= 1 then
		rate[player] = { WindowStart = now, Count = 1 }
		return false
	end
	r.Count = r.Count + 1
	return r.Count > RATE_LIMIT
end

local function tell(player, status, data)
	data = data or {}
	data.Status = status
	FX:FireClient(player, "SpinState", data)
end

local function sanitizeAim(aim, root)
	local fallback = root.CFrame.LookVector
	if typeof(aim) ~= "Vector3" then
		return fallback
	end
	if aim.X ~= aim.X or aim.Y ~= aim.Y or aim.Z ~= aim.Z then
		return fallback -- NaN
	end
	if aim.Magnitude < 1e-3 or aim.Magnitude > 1e4 then
		return fallback
	end
	local unit = aim.Unit
	local maxPitch = SpinConfig.Projectile.MaxAimPitch
	local y = math.clamp(unit.Y, -maxPitch, maxPitch)
	local flat = Vector3.new(unit.X, 0, unit.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(fallback.X, 0, fallback.Z)
	end
	flat = flat.Unit * math.sqrt(1 - y * y)
	return Vector3.new(flat.X, y, flat.Z).Unit
end

-- Throw origin is computed by the server and line-of-sight checked, so a
-- player standing against a wall can't spawn the ball on the other side.
local function throwOrigin(character, root)
	local desired = (root.CFrame * SpinConfig.Projectile.SpawnOffset).Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local offset = desired - root.Position
	if workspace:Raycast(root.Position, offset, params) then
		return root.Position
	end
	return desired
end

local function endCharge(player)
	local state = states[player]
	if not state then
		return nil
	end
	states[player] = nil
	if state.Humanoid and state.Humanoid.Parent then
		Adapter.setMoveModifier(state.Humanoid, "SpinCharge", nil)
	end
	if state.Character and state.Character.Parent then
		state.Character:SetAttribute("SpinChargeStart", nil)
	end
	return state
end

function SpinService.cancel(player, reason)
	local state = endCharge(player)
	if state then
		Cooldowns.start(player, COOLDOWN_KEY, SpinConfig.Charge.CancelCooldown)
		tell(player, "Cancelled", { Reason = reason, Cooldown = SpinConfig.Charge.CancelCooldown })
	end
end

function SpinService.start(player)
	if states[player] then
		return
	end
	if not Adapter.canAct(player) then
		tell(player, "Denied", { Reason = "Stunned" })
		return
	end
	local remaining = Cooldowns.remaining(player, COOLDOWN_KEY)
	if remaining > 0 then
		tell(player, "Denied", { Reason = "Cooldown", Remaining = remaining })
		return
	end
	local character, humanoid = Adapter.getAlive(player)

	local token = {}
	states[player] = {
		Start = os.clock(),
		Token = token,
		Humanoid = humanoid,
		Character = character,
	}
	Adapter.setMoveModifier(humanoid, "SpinCharge", SpinConfig.Charge.WalkSpeedMultiplier)
	character:SetAttribute("SpinChargeStart", workspace:GetServerTimeNow())
	tell(player, "Charging")

	-- Getting stunned while charging interrupts it: that's the counterplay.
	local stunConn
	stunConn = character:GetAttributeChangedSignal(Adapter.Settings.StunAttribute):Connect(function()
		if Adapter.isStunned(character) and states[player] and states[player].Token == token then
			SpinService.cancel(player, "Interrupted")
		end
		if not states[player] or states[player].Token ~= token then
			stunConn:Disconnect()
		end
	end)

	task.delay(SpinConfig.Charge.MaxHoldTime, function()
		local state = states[player]
		if state and state.Token == token then
			SpinService.release(player, nil) -- auto-release forward
		end
		if stunConn.Connected then
			stunConn:Disconnect()
		end
	end)
end

function SpinService.release(player, aim)
	local state = states[player]
	if not state then
		return
	end
	local chargeTime = os.clock() - state.Start
	endCharge(player)

	if not Adapter.canAct(player) then
		return
	end
	local character, _, root = Adapter.getAlive(player)

	local levelIndex, perfect = SpinConfig.getLevel(chargeTime, SpinConfig.Charge.ServerTimingTolerance)
	local level = SpinConfig.Levels[levelIndex]
	local direction = sanitizeAim(aim, root)
	local origin = throwOrigin(character, root)

	Cooldowns.start(player, COOLDOWN_KEY, level.Cooldown)

	local id = Projectiles.fire(player, {
		Kind = "SteelBall",
		Origin = origin,
		Direction = direction,
		Speed = level.Speed,
		Radius = level.Radius,
		Range = level.Range,
		Visual = { Level = levelIndex, Perfect = perfect },
		OnHit = function(target, position)
			Adapter.dealHit(player, target, {
				Damage = level.Damage,
				Stun = level.Stun,
				Knockback = level.Knockback,
				Direction = direction,
				Position = position,
				Level = levelIndex,
				Perfect = perfect,
				Source = "GoldenSpin",
			})
		end,
	})

	FX:FireAllClients("SpinRelease", {
		Character = character,
		Origin = origin,
		Direction = direction,
		Level = levelIndex,
		Perfect = perfect,
	})
	tell(player, "Released", {
		Level = levelIndex,
		Perfect = perfect,
		Cooldown = level.Cooldown,
		Fired = id ~= nil,
	})
end

function SpinService.init()
	Request.OnServerEvent:Connect(function(player, action, aim)
		if rateLimited(player) then
			return
		end
		if action == "Start" then
			SpinService.start(player)
		elseif action == "Release" then
			SpinService.release(player, aim)
		elseif action == "Cancel" then
			SpinService.cancel(player, "Manual")
		end
	end)

	local function onCharacter(player, character)
		endCharge(player)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				endCharge(player)
			end)
		end
	end

	local function onPlayer(player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		endCharge(player)
		rate[player] = nil
	end)
end

return SpinService
]=] },
	{ Service = "ServerScriptService", Path = "SpinServer/TestDummies", Class = "ModuleScript", Source = [=[
--[[
	TestDummies  (ServerScriptService.SpinServer.TestDummies)
	Studio-only practice targets so Spin can be tested solo.
	Never runs in a live server (guarded by RunService:IsStudio()).
	Turn off with SpinConfig.Debug.SpawnTestDummies = false.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SpinConfig = require(game:GetService("ReplicatedStorage").SpinShared.SpinConfig)

local TestDummies = {}

local function findSpawn()
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.CFrame
	end
	return CFrame.new(0, 5, 0)
end

local function spawnDummy(folder, cframe, index)
	local ok, dummy = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not dummy then
		warn("[TestDummies] could not create dummy:", dummy)
		return
	end
	dummy.Name = "SpinDummy" .. index
	dummy:PivotTo(cframe)
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.MaxHealth = 150
	humanoid.Health = 150
	dummy.Parent = folder
	humanoid.Died:Connect(function()
		task.wait(SpinConfig.Debug.DummyRespawnTime)
		dummy:Destroy()
		spawnDummy(folder, cframe, index)
	end)
end

function TestDummies.init()
	if not RunService:IsStudio() or not SpinConfig.Debug.SpawnTestDummies then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "SpinTestDummies"
	folder.Parent = workspace
	local base = findSpawn()
	for i = 1, SpinConfig.Debug.DummyCount do
		local offset = CFrame.new((i - (SpinConfig.Debug.DummyCount + 1) / 2) * 8, 3, -30 - i * 6)
		spawnDummy(folder, base * offset * CFrame.Angles(0, math.pi, 0), i)
	end
end

return TestDummies
]=] },
	{ Service = "ServerScriptService", Path = "SpinServer/TuskActs", Class = "Folder", Source = nil },
	{ Service = "ServerScriptService", Path = "SpinServer/TuskActs/TuskAct1", Class = "ModuleScript", Source = [=[
--[[
	TuskAct1  (ServerScriptService.SpinServer.TuskActs.TuskAct1)

	Server logic for Tusk Act 1, "the beginning of Spin".
	  M1        NAIL COMBO: jab, nail strike, spinning nail assist, shock finisher
	  Ability 1 NAIL SHOT: one spinning nail
	  Ability 2 NAIL BARRAGE: five nails fanned out
	  Ability 3 SPINNING NAIL: hold to charge, release (golden-blue at full charge)
	  Ultimate  TUSK AWAKENING: armored cinematic burst, then 20 s Awakened
	            (faster cooldowns, stronger nails)

	Every number is in TuskConfig.Act1. All hits go through S.hit()
	(CombatAdapter), all timing and cooldowns live here on the server.
	Visual events are sent with S.fx(); clients choreograph them in
	SpinClient.TuskActVFX.Act1.
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)

local Act1 = {}
local cfg = TuskConfig.Act1

local HAND_OFFSET = CFrame.new(0.9, 0.55, -1.5) -- right-hand fingertip area

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function nailDamage(state, base)
	return state.Awakened and base * cfg.Ultimate.DamageMultiplier or base
end

local function cooldown(state, base)
	return state.Awakened and base * cfg.Ultimate.CooldownMultiplier or base
end

---------------------------------------------------------------------------
-- M1: NAIL COMBO
---------------------------------------------------------------------------
function Act1.M1(S, player, state, aim)
	local m = cfg.M1
	if S.isBusy(state) or state.Charging then
		return
	end
	local now = os.clock()
	if now - state.LastM1 > m.ResetAfter then
		state.Combo = 0
	end
	local index = state.Combo + 1
	state.Combo = index >= 4 and 0 or index
	state.LastM1 = now
	S.lock(state, index == 4 and m.EndLag or m.Interval)

	local character, _, root = alive(S, player)
	local hit = m.Hits[index]
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("M1", { Character = character, Act = 1, Index = index })

	task.delay(m.Windup, function()
		-- Getting stunned during the wind-up cancels the hit (trades are fair).
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		if hit.Projectile then
			local p = hit.Projectile
			S.fireNail(player, state, {
				Origin = S.origin(char, r, HAND_OFFSET),
				Direction = direction,
				Speed = p.Speed,
				Radius = p.Radius,
				Range = p.Range,
				Style = "M1",
				OnHit = function(target, position)
					S.hit(player, target, {
						Damage = hit.Damage,
						Stun = hit.Stun,
						Knockback = hit.Knockback,
						Direction = direction,
						Position = position,
						Source = "TuskM1",
					})
				end,
			})
			return
		end

		local boxCF = r.CFrame * CFrame.new(0, 0, -m.HitboxForward)
		local targets = S.Hitbox.inBox(char, boxCF, m.HitboxSize, m.MaxTargets)
		local landed = false
		for _, target in ipairs(targets) do
			local targetRoot = target:FindFirstChild("HumanoidRootPart")
			if targetRoot and S.Hitbox.lineOfSight(r.Position, targetRoot.Position, { char, target }) then
				local ok = S.hit(player, target, {
					Damage = hit.Damage,
					Stun = hit.Stun,
					Knockback = hit.Knockback,
					Launch = hit.Launch,
					Direction = targetRoot.Position - r.Position,
					Position = targetRoot.Position,
					Source = "TuskM1",
				})
				landed = landed or ok
			end
		end
		if index == 4 then
			S.fx("M1Finisher", { Character = char, Act = 1, Position = boxCF.Position, Radius = hit.ShockwaveRadius, Hit = landed })
		end
	end)
end

---------------------------------------------------------------------------
-- Abilities
---------------------------------------------------------------------------
local function nailShot(S, player, state, aim)
	local c = cfg.NailShot
	if S.isBusy(state) or state.Charging or not S.cooldownReady(player, state, "NailShot", 1) then
		return
	end
	S.startCooldown(player, state, "NailShot", cooldown(state, c.Cooldown), 1)
	S.lock(state, c.Startup + 0.2)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 1, Move = "NailShot", Phase = "Startup", Direction = direction, Startup = c.Startup })

	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		S.fireNail(player, state, {
			Origin = S.origin(char, r, HAND_OFFSET),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Shot",
			OnHit = function(target, position)
				S.hit(player, target, {
					Damage = nailDamage(state, c.Damage),
					Stun = c.Stun,
					Knockback = c.Knockback,
					Direction = direction,
					Position = position,
					Source = "TuskNailShot",
				})
			end,
		})
	end)
end

-- Fixed fan pattern (not random) so the barrage is readable and dodgeable.
local BARRAGE_PATTERN = { { 0, 0 }, { -1, 0.3 }, { 1, -0.2 }, { -0.5, -0.4 }, { 0.6, 0.5 }, { 0, 0.2 }, { -1, -0.3 } }

local function nailBarrage(S, player, state, aim)
	local c = cfg.NailBarrage
	if S.isBusy(state) or state.Charging or not S.cooldownReady(player, state, "NailBarrage", 2) then
		return
	end
	S.startCooldown(player, state, "NailBarrage", cooldown(state, c.Cooldown), 2)
	S.lock(state, c.Startup + c.Count * c.Interval + 0.15)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 1, Move = "NailBarrage", Phase = "Startup", Direction = direction, Startup = c.Startup, Count = c.Count, Interval = c.Interval })

	for i = 1, c.Count do
		task.delay(c.Startup + (i - 1) * c.Interval, function()
			if not S.stillValid(player, state, life) then
				return
			end
			local char, _, r = alive(S, player)
			local pattern = BARRAGE_PATTERN[(i - 1) % #BARRAGE_PATTERN + 1]
			local spread = math.rad(c.SpreadDegrees)
			local look = CFrame.lookAt(Vector3.new(), direction)
			local dir = (look * CFrame.Angles(pattern[2] * spread * 0.5, pattern[1] * spread, 0)).LookVector
			S.fireNail(player, state, {
				Origin = S.origin(char, r, HAND_OFFSET),
				Direction = dir,
				Speed = c.Speed,
				Radius = c.Radius,
				Range = c.Range,
				Style = "Barrage",
				OnHit = function(target, position)
					S.hit(player, target, {
						Damage = nailDamage(state, c.Damage),
						Stun = c.Stun,
						Knockback = c.Knockback,
						Direction = dir,
						Position = position,
						Source = "TuskNailBarrage",
					})
				end,
			})
		end)
	end
end

local function spinningNailRelease(S, player, state, aim)
	local c = cfg.SpinningNail
	local charge = S.endCharge(player, state)
	if not charge or charge.Move ~= "SpinningNail" then
		return
	end
	local character, _, root = alive(S, player)
	if not character then
		return
	end
	local t = math.clamp((os.clock() - charge.Start) / c.FullChargeAt, 0, 1)
	local full = t >= 1
	local direction = S.aim(aim, root)
	local function lerp(a, b)
		return a + (b - a) * t
	end
	S.startCooldown(player, state, "SpinningNail", cooldown(state, c.Cooldown), 3)
	S.lock(state, 0.3)
	S.fx("Ability", { Character = character, Act = 1, Move = "SpinningNail", Phase = "Release", Charge = t, Full = full, Direction = direction })
	S.fireNail(player, state, {
		Origin = S.origin(character, root, HAND_OFFSET),
		Direction = direction,
		Speed = lerp(c.MinSpeed, c.MaxSpeed),
		Radius = lerp(c.MinRadius, c.MaxRadius),
		Range = c.Range,
		Style = "Spinning",
		Charge = t,
		OnHit = function(target, position)
			S.hit(player, target, {
				Damage = nailDamage(state, lerp(c.MinDamage, c.MaxDamage)),
				Stun = c.Stun * (0.5 + t * 0.5),
				Knockback = c.Knockback * (0.4 + t * 0.6),
				Direction = direction,
				Position = position,
				Source = "TuskSpinningNail",
			})
		end,
	})
end

local function spinningNailPress(S, player, state)
	local c = cfg.SpinningNail
	if S.isBusy(state) or state.Charging or not S.cooldownReady(player, state, "SpinningNail", 3) then
		return
	end
	local charge = S.beginCharge(player, state, "SpinningNail", 3, c.WalkSpeedMultiplier)
	local token = charge.Token
	task.delay(c.MaxHold, function()
		if state.Charging and state.Charging.Token == token then
			spinningNailRelease(S, player, state, nil) -- auto-release forward
		end
	end)
end

function Act1.Ability(S, player, state, slot, phase, aim)
	if slot == 1 and phase == "Press" then
		nailShot(S, player, state, aim)
	elseif slot == 2 and phase == "Press" then
		nailBarrage(S, player, state, aim)
	elseif slot == 3 then
		if phase == "Press" then
			spinningNailPress(S, player, state)
		else
			spinningNailRelease(S, player, state, aim)
		end
	end
end

function Act1.CancelCharge(S, player, state)
	local charge = S.endCharge(player, state)
	if charge then
		S.startCooldown(player, state, charge.Move, 1.5, charge.Slot)
		S.fx("Ability", { Character = state.Character, Act = 1, Move = charge.Move, Phase = "Cancel" })
	end
end

---------------------------------------------------------------------------
-- Ultimate: TUSK AWAKENING
---------------------------------------------------------------------------
local function endAwakening(S, player, state)
	state.Awakened = false
	state.AwakenToken = nil
	if state.Character then
		state.Character:SetAttribute("TuskAwakened", nil)
	end
	S.tell(player, "AwakenEnded", {})
end

function Act1.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging or state.Awakened then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.4)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = 1, Phase = "Start", Windup = u.Windup })

	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if not S.stillValid(player, state, life, true) then
			return
		end
		local char, _, root = alive(S, player)
		for _, target in ipairs(S.Hitbox.inRadius(char, root.Position, u.Radius, 8)) do
			local targetRoot = target:FindFirstChild("HumanoidRootPart")
			if targetRoot and S.Hitbox.lineOfSight(root.Position, targetRoot.Position, { char, target }) then
				S.hit(player, target, {
					Damage = u.Damage,
					Stun = u.Stun,
					Knockback = u.Knockback,
					Launch = u.Launch,
					Direction = targetRoot.Position - root.Position,
					Position = targetRoot.Position,
					Source = "TuskAwakening",
				})
			end
		end
		S.fx("Ultimate", { Character = char, Act = 1, Phase = "Burst", Position = root.Position, Radius = u.Radius })

		state.Awakened = true
		local token = {}
		state.AwakenToken = token
		char:SetAttribute("TuskAwakened", true)
		S.tell(player, "Awakened", { Duration = u.Duration })
		task.delay(u.Duration, function()
			if state.AwakenToken == token then
				endAwakening(S, player, state)
			end
		end)
	end)
end

function Act1.Cleanup(S, player, state)
	if state.Charging then
		S.endCharge(player, state)
	end
	if state.Awakened then
		endAwakening(S, player, state)
	end
end

return Act1
]=] },
	{ Service = "ServerScriptService", Path = "SpinServer/TuskHitbox", Class = "ModuleScript", Source = [=[
--[[
	TuskHitbox  (ServerScriptService.SpinServer.TuskHitbox)
	Server-side spatial queries for melee and area attacks.
	Returns unique characters (models with a Humanoid), nearest first.
]]

local TuskHitbox = {}

local function characterFromPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end
TuskHitbox.characterFromPart = characterFromPart

local function collect(parts, attacker, origin, max)
	local seen, list = {}, {}
	for _, part in ipairs(parts) do
		local character = characterFromPart(part)
		if character and character ~= attacker and not seen[character] then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart")
			if humanoid and root and humanoid.Health > 0 then
				seen[character] = true
				table.insert(list, { Character = character, Distance = (root.Position - origin).Magnitude })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Distance < b.Distance
	end)
	local out = {}
	for i = 1, math.min(#list, max or #list) do
		out[i] = list[i].Character
	end
	return out
end

local function overlapParams(attacker)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = attacker and { attacker } or {}
	return params
end

function TuskHitbox.inBox(attacker, cframe, size, max)
	local parts = workspace:GetPartBoundsInBox(cframe, size, overlapParams(attacker))
	return collect(parts, attacker, cframe.Position, max)
end

function TuskHitbox.inRadius(attacker, position, radius, max)
	local parts = workspace:GetPartBoundsInRadius(position, radius, overlapParams(attacker))
	return collect(parts, attacker, position, max)
end

-- True if nothing but characters blocks the line between the two points.
function TuskHitbox.lineOfSight(fromPos, toPos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	params.IgnoreWater = true
	local offset = toPos - fromPos
	local result = workspace:Raycast(fromPos, offset, params)
	if not result then
		return true
	end
	return characterFromPart(result.Instance) ~= nil
end

return TuskHitbox
]=] },
	{ Service = "ServerScriptService", Path = "SpinServer/TuskService", Class = "ModuleScript", Source = [=[
--[[
	TuskService  (ServerScriptService.SpinServer.TuskService)

	Server brain for Tusk (the "TuskController" of the design doc):
	  * equips / switches Acts (validated against TuskActRegistry and
	    TuskConfig.Progression)
	  * routes every TuskRequest to the active Act module or TuskSneakService
	  * owns per-player state, action locks, cooldowns, the ultimate meter
	  * gives Act modules safe helpers: hit(), fireNail(), aim(), origin()...

	Request protocol (client -> server, TuskRequest:FireServer):
	  "Select", act          equip Act n (0 = unequip)
	  "M1", aim              basic attack (sneak attack while sneaking)
	  "Ability", slot, phase, aim   slot 1..3, phase "Press" | "Release"
	  "Ultimate", aim
	  "Sneak", on

	Attributes it sets (replicated; clients render from them):
	  Player.TuskUlt (0..Max)  Character.TuskAct  Character.TuskCharge
	  Character.TuskAwakened   Character.Armored  (Sneak ones: see TuskSneakService)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local Net = require(Shared.Net)
local Adapter = require(script.Parent.CombatAdapter)
local Cooldowns = require(script.Parent.CooldownService)
local Projectiles = require(script.Parent.ProjectileService)
local Hitbox = require(script.Parent.TuskHitbox)

local Request = Net.get("TuskRequest")
local FX = Net.get("TuskFX")

local TuskService = {}
TuskService.Hitbox = Hitbox
TuskService.Adapter = Adapter

local states = {} -- [player] = state
local rate = {}
local actModules = {}
local Sneak -- set in init (circular dependency)

local RATE_LIMIT = 24 -- requests per second

---------------------------------------------------------------------------
-- Helpers for Act modules
---------------------------------------------------------------------------
function TuskService.getState(player)
	return states[player]
end

function TuskService.fx(name, data)
	FX:FireAllClients(name, data)
end

function TuskService.tell(player, kind, data)
	data = data or {}
	data.Kind = kind
	FX:FireClient(player, "TuskState", data)
end

function TuskService.isBusy(state)
	return os.clock() < state.LockUntil
end

function TuskService.lock(state, seconds)
	state.LockUntil = math.max(state.LockUntil, os.clock() + seconds)
end

local function cooldownKey(state, name)
	return "Tusk" .. state.Act .. "_" .. name
end

-- Returns true if ready; otherwise tells the client how long is left.
function TuskService.cooldownReady(player, state, name, slot)
	local remaining = Cooldowns.remaining(player, cooldownKey(state, name))
	if remaining > 0 then
		TuskService.tell(player, "Denied", { Reason = "Cooldown", Slot = slot, Remaining = remaining })
		return false
	end
	return true
end

function TuskService.startCooldown(player, state, name, seconds, slot)
	Cooldowns.start(player, cooldownKey(state, name), seconds)
	TuskService.tell(player, "Cooldown", { Slot = slot, Duration = seconds })
end

-- A token that changes on death / Act switch, so delayed actions can
-- check they still belong to the same "life".
function TuskService.stillValid(player, state, life, allowStunned)
	if states[player] ~= state or state.Life ~= life then
		return false
	end
	if allowStunned then
		return Adapter.getAlive(player) ~= nil
	end
	return Adapter.canAct(player)
end

function TuskService.aim(aim, root)
	local fallback = root.CFrame.LookVector
	if typeof(aim) ~= "Vector3" or aim ~= aim or aim.Magnitude < 1e-3 or aim.Magnitude > 1e4 then
		return fallback
	end
	if aim.X ~= aim.X or aim.Y ~= aim.Y or aim.Z ~= aim.Z then
		return fallback
	end
	local unit = aim.Unit
	local y = math.clamp(unit.Y, -0.8, 0.8)
	local flat = Vector3.new(unit.X, 0, unit.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(fallback.X, 0, fallback.Z)
	end
	flat = flat.Unit * math.sqrt(1 - y * y)
	return Vector3.new(flat.X, y, flat.Z).Unit
end

-- Spawn point for attacks, pulled back to the root if a wall is in the way.
function TuskService.origin(character, root, offset)
	local desired = (root.CFrame * offset).Position
	if Hitbox.lineOfSight(root.Position, desired, { character }) then
		return desired
	end
	return root.Position
end

function TuskService.addUlt(player, amount)
	local max = TuskConfig.Ultimate.MaxMeter
	local current = player:GetAttribute("TuskUlt") or 0
	player:SetAttribute("TuskUlt", math.clamp(current + amount, 0, max))
end

function TuskService.spendUlt(player)
	local max = TuskConfig.Ultimate.MaxMeter
	if (player:GetAttribute("TuskUlt") or 0) < max then
		TuskService.tell(player, "Denied", { Reason = "UltNotReady" })
		return false
	end
	player:SetAttribute("TuskUlt", 0)
	return true
end

-- All Tusk damage goes through here: CombatAdapter + ultimate meter.
function TuskService.hit(player, targetCharacter, info)
	local ok, damage = Adapter.dealHit(player, targetCharacter, info)
	if ok then
		TuskService.addUlt(player, (damage or 0) * TuskConfig.Ultimate.GainPerDamage)
	end
	return ok
end

-- Server projectile with a Tusk nail visual.
function TuskService.fireNail(player, state, spec)
	return Projectiles.fire(player, {
		Kind = "TuskNail",
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius,
		Range = spec.Range,
		Visual = {
			Act = state.Act,
			Style = spec.Style or "Shot",
			Charge = spec.Charge or 0,
			Awakened = state.Awakened == true,
		},
		OnHit = spec.OnHit,
	})
end

-- Charge helpers (hold abilities): sets the replicated TuskCharge attribute.
function TuskService.beginCharge(player, state, move, slot, multiplier)
	local character, humanoid = Adapter.getAlive(player)
	state.Charging = { Move = move, Slot = slot, Start = os.clock(), Token = {} }
	Adapter.setMoveModifier(humanoid, "TuskCharge", multiplier or 1)
	character:SetAttribute("TuskCharge", workspace:GetServerTimeNow())
	character:SetAttribute("TuskChargeMove", move)
	return state.Charging
end

function TuskService.endCharge(player, state)
	local charge = state.Charging
	state.Charging = nil
	local character = state.Character
	if character then
		character:SetAttribute("TuskCharge", nil)
		character:SetAttribute("TuskChargeMove", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Adapter.setMoveModifier(humanoid, "TuskCharge", nil)
		end
	end
	return charge
end

---------------------------------------------------------------------------
-- Equip / switch
---------------------------------------------------------------------------
local function cleanupAct(player, state)
	state.Life = state.Life + 1
	local module = state.Act and actModules[state.Act]
	if module and module.Cleanup then
		pcall(module.Cleanup, TuskService, player, state)
	end
	TuskService.endCharge(player, state)
	if Sneak then
		Sneak.exit(player, state, false)
	end
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute("TuskAwakened", nil)
	end
	state.Awakened = false
	state.Combo = 0
	state.LockUntil = 0
end

local function isUnlocked(player, act)
	local p = TuskConfig.Progression
	if p.Mode == "Unlock" then
		return p.IsUnlocked ~= nil and p.IsUnlocked(player, act) == true
	end
	return true
end

function TuskService.select(player, act)
	if typeof(act) ~= "number" or act ~= math.floor(act) then
		return
	end
	local state = states[player]
	if not state then
		return
	end
	if act == 0 then
		cleanupAct(player, state)
		state.Act = nil
		if state.Character then
			state.Character:SetAttribute("TuskAct", nil)
		end
		TuskService.tell(player, "Equipped", { Act = 0 })
		return
	end
	if not Registry.isImplemented(act) or not actModules[act] then
		TuskService.tell(player, "Denied", { Reason = "NotAvailable" })
		return
	end
	if not isUnlocked(player, act) then
		TuskService.tell(player, "Denied", { Reason = "Locked" })
		return
	end
	if state.Act == act then
		return
	end
	if os.clock() - state.LastSwitch < TuskConfig.Progression.SwitchCooldown or TuskService.isBusy(state) then
		TuskService.tell(player, "Denied", { Reason = "SwitchCooldown" })
		return
	end
	cleanupAct(player, state)
	state.Act = act
	state.LastSwitch = os.clock()
	player:SetAttribute("TuskSelectedAct", act)
	if state.Character then
		state.Character:SetAttribute("TuskAct", act)
	end
	TuskService.tell(player, "Equipped", { Act = act })
end

---------------------------------------------------------------------------
-- Request routing
---------------------------------------------------------------------------
local function rateLimited(player)
	local r = rate[player]
	local now = os.clock()
	if not r or now - r.Start >= 1 then
		rate[player] = { Start = now, Count = 1 }
		return false
	end
	r.Count = r.Count + 1
	return r.Count > RATE_LIMIT
end

local function onRequest(player, action, a, b, c)
	if rateLimited(player) or typeof(action) ~= "string" then
		return
	end
	if action == "Select" then
		TuskService.select(player, a)
		return
	end
	local state = states[player]
	if not state or not state.Act or not state.Character then
		return
	end
	local module = actModules[state.Act]

	if action == "Sneak" then
		Sneak.toggle(player, state, a == true)
		return
	end
	if state.Burrowed then
		return
	end

	-- Releasing a held ability is allowed even mid-lock; everything else needs a free player.
	if action == "Ability" and b == "Release" then
		if typeof(a) == "number" and module.Ability then
			module.Ability(TuskService, player, state, a, "Release", c)
		end
		return
	end
	if not Adapter.canAct(player) then
		return
	end

	if action == "M1" then
		if state.Sneaking then
			Sneak.attack(player, state)
		else
			module.M1(TuskService, player, state, a)
		end
	elseif action == "Ability" then
		if typeof(a) ~= "number" or (a ~= 1 and a ~= 2 and a ~= 3) then
			return
		end
		if state.Sneaking then
			Sneak.exit(player, state, true)
		end
		module.Ability(TuskService, player, state, a, "Press", c)
	elseif action == "Ultimate" then
		if state.Sneaking then
			Sneak.exit(player, state, true)
		end
		module.Ultimate(TuskService, player, state, a)
	end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local function onCharacter(player, character)
	local state = states[player]
	if not state then
		return
	end
	cleanupAct(player, state)
	state.Character = character
	state.Burrowed = false
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or states[player] ~= state or state.Character ~= character then
		return
	end
	if state.Act then
		character:SetAttribute("TuskAct", state.Act)
	end
	humanoid.Died:Connect(function()
		if state.Character == character then
			cleanupAct(player, state)
		end
	end)
	-- Getting stunned interrupts charges and breaks sneak (counterplay).
	character:GetAttributeChangedSignal(Adapter.Settings.StunAttribute):Connect(function()
		if not Adapter.isStunned(character) or state.Character ~= character then
			return
		end
		if state.Charging then
			local module = state.Act and actModules[state.Act]
			if module and module.CancelCharge then
				module.CancelCharge(TuskService, player, state)
			else
				TuskService.endCharge(player, state)
			end
			TuskService.tell(player, "Interrupted", {})
		end
		if state.Sneaking then
			Sneak.exit(player, state, true)
		end
	end)
end

local function onPlayer(player)
	states[player] = {
		Act = nil,
		Character = nil,
		Life = 0,
		Combo = 0,
		LastM1 = 0,
		LockUntil = 0,
		LastSwitch = -math.huge,
		Charging = nil,
		Sneaking = false,
		Burrowed = false,
		Awakened = false,
	}
	player:SetAttribute("TuskUlt", (RunService:IsStudio() and TuskConfig.Ultimate.StudioStartFull) and TuskConfig.Ultimate.MaxMeter or 0)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	if TuskConfig.Progression.AutoEquip then
		task.defer(TuskService.select, player, TuskConfig.Progression.DefaultAct)
	end
end

function TuskService.init()
	local actsFolder = script.Parent:WaitForChild("TuskActs")
	for act in pairs(Registry.Acts) do
		local moduleScript = actsFolder:FindFirstChild("TuskAct" .. act)
		if moduleScript and Registry.isImplemented(act) then
			actModules[act] = require(moduleScript)
		end
	end
	Sneak = require(script.Parent.TuskSneakService)
	Sneak.init(TuskService)

	Request.OnServerEvent:Connect(onRequest)
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		if state then
			cleanupAct(player, state)
		end
		states[player] = nil
		rate[player] = nil
	end)
end

return TuskService
]=] },
	{ Service = "ServerScriptService", Path = "SpinServer/TuskSneakService", Class = "ModuleScript", Source = [=[
--[[
	TuskSneakService  (ServerScriptService.SpinServer.TuskSneakService)

	Tusk Sneak (every Act): a crouched, slowed stalking state, plus the
	Sneak Attack (M1 while sneaking):
	  1. Tusk sinks into the ground (Burrow): invisible and briefly untargetable
	  2. a distortion warning appears under the target (WarningTime before emergence)
	  3. Tusk emerges behind the target at a server-validated safe spot
	  4. surprise hit + launch, finished with a blue shockwave

	Counterplay: the warning is visible and audible, a target that moves
	MaxTargetDrift studs away is missed, getting hit breaks sneak, and both
	sneak and the attack have cooldowns.

	Character attributes: TuskSneaking, TuskBurrowed.
]]

local Shared = game:GetService("ReplicatedStorage").SpinShared
local TuskConfig = require(Shared.TuskConfig)
local Adapter = require(script.Parent.CombatAdapter)
local Cooldowns = require(script.Parent.CooldownService)
local Hitbox = require(script.Parent.TuskHitbox)

local TuskSneakService = {}
local S -- TuskService

local cfg = TuskConfig.Sneak

function TuskSneakService.init(service)
	S = service
end

function TuskSneakService.exit(player, state, applyCooldown)
	if not state.Sneaking then
		return
	end
	state.Sneaking = false
	state.SneakToken = nil
	local character = state.Character
	if character then
		character:SetAttribute("TuskSneaking", nil)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Adapter.setMoveModifier(humanoid, "TuskSneak", nil)
		end
	end
	if applyCooldown then
		Cooldowns.start(player, "TuskSneak", cfg.Cooldown)
		S.tell(player, "SneakCooldown", { Duration = cfg.Cooldown })
	end
end

function TuskSneakService.toggle(player, state, on)
	if not on then
		TuskSneakService.exit(player, state, true)
		return
	end
	if state.Sneaking or state.Charging or S.isBusy(state) or not Adapter.canAct(player) then
		return
	end
	local remaining = Cooldowns.remaining(player, "TuskSneak")
	if remaining > 0 then
		S.tell(player, "Denied", { Reason = "SneakCooldown", Remaining = remaining })
		return
	end
	local character, humanoid = Adapter.getAlive(player)
	state.Sneaking = true
	local token = {}
	state.SneakToken = token
	character:SetAttribute("TuskSneaking", true)
	Adapter.setMoveModifier(humanoid, "TuskSneak", cfg.WalkSpeedMultiplier)
	task.delay(cfg.MaxDuration, function()
		if state.SneakToken == token then
			TuskSneakService.exit(player, state, true)
		end
	end)
end

-- Nearest enemy in front, in range, with line of sight.
local function findTarget(character, root)
	local best, bestDistance
	local cosLimit = math.cos(math.rad(cfg.Attack.ConeDegrees / 2))
	for _, target in ipairs(Hitbox.inRadius(character, root.Position, cfg.Attack.Range)) do
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if targetRoot and Adapter.canBeHit(nil, target) then
			local offset = targetRoot.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			if flat.Magnitude > 0.1 and flat.Unit:Dot(look.Unit) >= cosLimit then
				if Hitbox.lineOfSight(root.Position, targetRoot.Position, { character, target }) then
					if not bestDistance or offset.Magnitude < bestDistance then
						best, bestDistance = target, offset.Magnitude
					end
				end
			end
		end
	end
	return best
end

-- Safe emergence point near the target: behind first, then the sides, then in front.
-- Must have clear line of sight from the target, solid ground below and free space.
local function emergePoint(attacker, target)
	local targetRoot = target.HumanoidRootPart
	local d = cfg.Attack.EmergeDistance
	local candidates = {
		targetRoot.CFrame * CFrame.new(0, 0, d),
		targetRoot.CFrame * CFrame.new(d, 0, 0),
		targetRoot.CFrame * CFrame.new(-d, 0, 0),
		targetRoot.CFrame * CFrame.new(0, 0, -d),
	}
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { attacker, target }
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { attacker, target }
	for _, cf in ipairs(candidates) do
		local pos = cf.Position
		if Hitbox.lineOfSight(targetRoot.Position, pos, { attacker, target }) then
			local ground = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), rayParams)
			if ground then
				local standPos = ground.Position + Vector3.new(0, 3, 0)
				local blocking = workspace:GetPartBoundsInBox(CFrame.new(standPos), Vector3.new(2, 4.5, 2), overlap)
				local solid = false
				for _, part in ipairs(blocking) do
					if part.CanCollide then
						solid = true
						break
					end
				end
				if not solid then
					return standPos
				end
			end
		end
	end
	return nil
end

function TuskSneakService.attack(player, state)
	local a = cfg.Attack
	if S.isBusy(state) or state.Charging then
		return
	end
	local remaining = Cooldowns.remaining(player, "TuskSneakAttack")
	if remaining > 0 then
		S.tell(player, "Denied", { Reason = "SneakAttackCooldown", Remaining = remaining })
		return
	end
	local character, _, root = Adapter.getAlive(player)
	local target = findTarget(character, root)
	if not target then
		Cooldowns.start(player, "TuskSneakAttack", a.FailCooldown)
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end

	TuskSneakService.exit(player, state, true)
	Cooldowns.start(player, "TuskSneakAttack", a.Cooldown)
	S.tell(player, "SneakAttackCooldown", { Duration = a.Cooldown })
	S.lock(state, a.BurrowTime + 0.45)

	local life = state.Life
	local startPos = root.Position
	local targetStart = target.HumanoidRootPart.Position
	state.Burrowed = true
	character:SetAttribute("TuskBurrowed", true)
	character:SetAttribute(Adapter.Settings.IFrameAttribute, true)
	-- Anchor in place while underground so the hidden body can't wander.
	root.Anchored = true

	S.fx("SneakAttack", { Phase = "Burrow", Character = character, Position = startPos - Vector3.new(0, 2.8, 0), Target = target })

	local function surface()
		state.Burrowed = false
		if character.Parent then
			character:SetAttribute("TuskBurrowed", nil)
			character:SetAttribute(Adapter.Settings.IFrameAttribute, nil)
			if root.Parent then
				root.Anchored = false
			end
		end
	end

	task.delay(a.BurrowTime - a.WarningTime, function()
		if state.Life ~= life or not target.Parent then
			return
		end
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			S.fx("SneakAttack", { Phase = "Warning", Character = character, Target = target, Position = targetRoot.Position - Vector3.new(0, 2.8, 0), Duration = a.WarningTime })
		end
	end)

	task.delay(a.BurrowTime, function()
		if state.Life ~= life or not Adapter.getAlive(player) then
			surface()
			return
		end
		local targetRoot = target.Parent and target:FindFirstChild("HumanoidRootPart")
		local valid = targetRoot
			and Adapter.canBeHit(player, target)
			and (targetRoot.Position - targetStart).Magnitude <= a.MaxTargetDrift
			and (targetRoot.Position - startPos).Magnitude <= a.Range * 1.4
		local pos = valid and emergePoint(character, target) or nil

		surface()
		if not pos then
			-- Whiff: surface where we went under.
			S.fx("SneakAttack", { Phase = "Emerge", Character = character, Position = startPos - Vector3.new(0, 2.8, 0), Hit = false })
			return
		end
		local facing = Vector3.new(targetRoot.Position.X, pos.Y, targetRoot.Position.Z)
		character:PivotTo(CFrame.lookAt(pos, facing))
		S.fx("SneakAttack", { Phase = "Emerge", Character = character, Position = pos - Vector3.new(0, 2.8, 0), Hit = true })

		local hitAny = false
		for _, victim in ipairs(Hitbox.inRadius(character, pos, a.HitRadius, 3)) do
			local victimRoot = victim:FindFirstChild("HumanoidRootPart")
			if victimRoot and Hitbox.lineOfSight(pos, victimRoot.Position, { character, victim }) then
				local hit = S.hit(player, victim, {
					Damage = a.Damage,
					Stun = a.Stun,
					Knockback = a.Knockback,
					Launch = a.Launch,
					Direction = victimRoot.Position - pos,
					Position = victimRoot.Position,
					Source = "TuskSneakAttack",
				})
				hitAny = hitAny or hit
			end
		end
		S.fx("SneakAttack", { Phase = "Shockwave", Character = character, Position = pos - Vector3.new(0, 2.8, 0), Hit = hitAny })
	end)
end

return TuskSneakService
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient", Class = "LocalScript", Source = [=[
--[[
	SpinClient  (StarterPlayer.StarterPlayerScripts.SpinClient — LocalScript)
	Boots every client system: Golden Spin, Tusk, NPC bubbles and map ambience.
]]

local SpinMeter = require(script.UI.SpinMeter)
local SpinVFX = require(script.SpinVFX)
local SpinController = require(script.SpinController)
local TuskStand = require(script.TuskStand)
local TuskProjectiles = require(script.TuskProjectiles)
local TuskSneakController = require(script.TuskSneakController)
local TuskController = require(script.TuskController)
local WorldClient = require(script.WorldClient)

SpinMeter.init()
SpinVFX.init()
SpinController.init()
TuskStand.init()
TuskProjectiles.init()
TuskSneakController.init()
TuskController.init()
WorldClient.init()
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/CameraFX", Class = "ModuleScript", Source = [=[
--[[
	CameraFX  (StarterPlayerScripts.SpinClient.CameraFX)
	Screen-space feedback: camera shake, FOV punch, anime speed lines and
	short impact frames. All of it respects VFXQuality and cleans up.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local VFXQuality = require(Shared.VFXQuality)
local VFXLib = require(script.Parent.VFXLib)

local CameraFX = {}

local player = Players.LocalPlayer
local shakes = {}
local fovOffset = 0
local appliedFov = 0

RunService:BindToRenderStep("SpinCameraFX", Enum.RenderPriority.Camera.Value + 1, function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	local offset = Vector3.new()
	for i = #shakes, 1, -1 do
		local s = shakes[i]
		local a = (now - s.Start) / s.Duration
		if a >= 1 then
			table.remove(shakes, i)
		else
			local strength = s.Intensity * (1 - a) * (1 - a)
			local t = now * 32
			offset = offset
				+ Vector3.new(
					math.noise(t, s.Seed) * strength,
					math.noise(s.Seed, t) * strength,
					math.noise(t, t + s.Seed) * strength * 0.5
				)
		end
	end
	if offset.Magnitude > 0 then
		camera.CFrame = camera.CFrame * CFrame.new(offset) * CFrame.Angles(0, 0, offset.X * 0.02)
	end
	-- Apply FOV punch as a delta so other systems that set FOV still work.
	if fovOffset ~= appliedFov then
		camera.FieldOfView = camera.FieldOfView + (fovOffset - appliedFov)
		appliedFov = fovOffset
	end
end)

function CameraFX.shake(intensity, duration)
	intensity = intensity * VFXQuality.get().ShakeScale
	if intensity <= 0 then
		return
	end
	table.insert(shakes, { Start = os.clock(), Duration = duration or 0.35, Intensity = intensity, Seed = math.random() * 100 })
end

-- Shake scaled by distance from the camera.
function CameraFX.shakeAt(position, intensity, radius)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local d = (camera.CFrame.Position - position).Magnitude
	local falloff = math.clamp(1 - d / (radius or 80), 0, 1)
	if falloff > 0 then
		CameraFX.shake(intensity * falloff, 0.35)
	end
end

local fovJob
function CameraFX.fovPunch(amount, duration)
	if not VFXQuality.get().ScreenEffects then
		return
	end
	VFXLib.cancel(fovJob)
	fovJob = VFXLib.animate(duration or 0.35, function(a)
		fovOffset = amount * (1 - VFXLib.easeOut(a))
	end, function()
		fovOffset = 0
	end)
end

-- Held FOV offset (e.g. slight zoom while charging). nil clears.
function CameraFX.setFovHold(amount)
	if not VFXQuality.get().ScreenEffects then
		amount = 0
	end
	VFXLib.cancel(fovJob)
	fovJob = nil
	fovOffset = amount or 0
end

local function screenGui(name)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function CameraFX.speedLines(duration, color)
	if not VFXQuality.get().ScreenEffects then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local edge = math.sqrt(viewport.X * viewport.X + viewport.Y * viewport.Y) / 2
	local gui = screenGui("SpinSpeedLines")
	local lines = {}
	local count = VFXLib.particleCount(28)
	for i = 1, count do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = color or Color3.new(1, 1, 1)
		line.Parent = gui
		lines[i] = {
			Frame = line,
			Angle = (i / count) * math.pi * 2 + math.random() * 0.15,
			Inner = edge * (0.45 + math.random() * 0.25), -- where the line starts
			Thickness = math.random(1, 3),
		}
	end
	VFXLib.animate(duration or 0.3, function(a)
		for _, l in ipairs(lines) do
			-- Each line runs from its inner radius out past the screen edge,
			-- creeping inward slightly as the effect plays.
			local inner = l.Inner * (1 - 0.15 * a)
			local length = edge * 1.05 - inner
			local mid = inner + length / 2
			l.Frame.Size = UDim2.fromOffset(length, l.Thickness)
			l.Frame.Position = UDim2.new(0.5, math.cos(l.Angle) * mid, 0.5, math.sin(l.Angle) * mid)
			l.Frame.Rotation = math.deg(l.Angle)
			l.Frame.BackgroundTransparency = math.min(1, 0.2 + a * 0.8 + math.random() * 0.15)
		end
	end, function()
		gui:Destroy()
	end)
end

-- Two-frame high-contrast flash. Brief and subtle (photosensitivity-safe).
function CameraFX.impactFrame(tint)
	if not VFXQuality.get().ImpactFrames then
		return
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SpinImpactFrame"
	cc.Contrast = 0.6
	cc.Saturation = -0.6
	cc.TintColor = tint or Color3.new(1, 0.95, 0.8)
	cc.Brightness = 0.08
	cc.Parent = Lighting
	VFXLib.animate(0.12, function(a)
		cc.Contrast = 0.6 * (1 - a)
		cc.Saturation = -0.6 * (1 - a)
		cc.Brightness = 0.08 * (1 - a)
	end, function()
		cc:Destroy()
	end)
end

return CameraFX
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/JointCache", Class = "ModuleScript", Source = [=[
--[[
	JointCache  (StarterPlayerScripts.SpinClient.JointCache)
	Remembers each Motor6D's original C0 the first time any pose system
	touches it, so Spin poses and Tusk poses can both restore the true
	rest pose instead of each other's leftovers.
]]

local JointCache = {}
local originals = setmetatable({}, { __mode = "k" })

function JointCache.original(motor)
	local c0 = originals[motor]
	if not c0 then
		c0 = motor.C0
		originals[motor] = c0
	end
	return c0
end

return JointCache
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/ProceduralPose", Class = "ModuleScript", Source = [=[
--[[
	ProceduralPose  (StarterPlayerScripts.SpinClient.ProceduralPose)

	Animation-free arm posing for the Spin throw: tweens the right shoulder
	Motor6D's C0 on top of whatever Animator is playing, then restores it.
	Works on R15 and R6. C0 edits made on a client do not replicate, so
	SpinVFX calls this on EVERY client for EVERY charging character (driven
	by the replicated SpinChargeStart attribute). Everyone sees the pose.

	When real animations are uploaded, set ProceduralPose.Enabled = false
	and play the Animation tracks from SpinController instead.

	Pitch angles (degrees, rotation about the shoulder's side axis):
	  0 = arm down, 90 = arm straight forward, 180 = arm straight up.
]]

local ProceduralPose = {}

ProceduralPose.Enabled = true
ProceduralPose.Poses = {
	Charge = { Pitch = 195, Roll = -12 }, -- wound up over the shoulder, behind the head
	Throw = { Pitch = 80, Roll = 0 }, -- whipped forward at release
}

local jobs = setmetatable({}, { __mode = "k" })

local VFXLib = require(script.Parent.VFXLib)
local JointCache = require(script.Parent.JointCache)

local function getShoulder(character)
	local upper = character:FindFirstChild("RightUpperArm")
	if upper then
		return upper:FindFirstChild("RightShoulder"), "R15"
	end
	local torso = character:FindFirstChild("Torso")
	if torso then
		return torso:FindFirstChild("Right Shoulder"), "R6"
	end
	return nil
end

local function poseOffset(rig, pose)
	local pitch = math.rad(pose.Pitch)
	local roll = math.rad(pose.Roll or 0)
	if rig == "R15" then
		return CFrame.Angles(pitch, 0, roll)
	end
	-- R6 shoulder C0 is rotated so its local Z is the torso's side axis.
	return CFrame.Angles(roll, 0, pitch)
end

local function tweenC0(motor, target, duration)
	VFXLib.cancel(jobs[motor])
	local from = motor.C0
	jobs[motor] = VFXLib.animate(duration, function(a)
		if motor.Parent then
			motor.C0 = from:Lerp(target, VFXLib.easeOut(a))
		end
	end)
end

function ProceduralPose.play(character, poseName, duration)
	if not ProceduralPose.Enabled or not character then
		return
	end
	local motor, rig = getShoulder(character)
	local pose = ProceduralPose.Poses[poseName]
	if not motor or not pose then
		return
	end
	tweenC0(motor, JointCache.original(motor) * poseOffset(rig, pose), duration or 0.15)
end

function ProceduralPose.reset(character, duration)
	if not character then
		return
	end
	local motor = getShoulder(character)
	if motor then
		tweenC0(motor, JointCache.original(motor), duration or 0.25)
	end
end

-- Hand part the held ball is welded to, plus the grip offset.
function ProceduralPose.getHand(character)
	local hand = character:FindFirstChild("RightHand")
	if hand then
		return hand, CFrame.new(0, -0.45, -0.1)
	end
	local arm = character:FindFirstChild("Right Arm")
	if arm then
		return arm, CFrame.new(0, -1.1, -0.1)
	end
	return nil
end

return ProceduralPose
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/SpinController", Class = "ModuleScript", Source = [=[
--[[
	SpinController  (StarterPlayerScripts.SpinClient.SpinController)

	Local input for the Golden Spin. Hold to charge, release to throw.
	  PC:         hold R (aims at the mouse)
	  Controller: hold RT (aims where the camera looks)
	  Mobile:     hold the on-screen SPIN button (aims where the camera looks)

	Sends only "Start", "Release" + aim direction, or "Cancel".
	The server decides everything else and answers with SpinState.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local SpinConfig = require(Shared.SpinConfig)
local Net = require(Shared.Net)
local CameraFX = require(script.Parent.CameraFX)
local VFXLib = require(script.Parent.VFXLib)
local SpinMeter = require(script.Parent.UI.SpinMeter)

local SpinController = {}

local player = Players.LocalPlayer
local Request
local charging = false
local chargeStart = 0

local function aliveCharacter()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return character, root
	end
	return nil
end

local function usesCameraAim()
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Touch or string.find(last.Name, "Gamepad") ~= nil
end

local function aimDirection()
	local character, root = aliveCharacter()
	local camera = workspace.CurrentCamera
	if not character or not camera then
		return nil
	end
	local origin = (root.CFrame * SpinConfig.Projectile.SpawnOffset).Position
	if usesCameraAim() then
		return camera.CFrame.LookVector
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, VFXLib.Folder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local target = hit and hit.Position or (ray.Origin + ray.Direction * 600)
	local direction = target - origin
	if direction.Magnitude < 1 then
		return root.CFrame.LookVector
	end
	return direction.Unit
end

local function stopLocal()
	charging = false
	SpinMeter.hideCharge()
	CameraFX.setFovHold(0)
end

local function begin()
	if charging or not aliveCharacter() then
		return
	end
	charging = true
	chargeStart = os.clock()
	Request:FireServer("Start")
	SpinMeter.showCharge()
	CameraFX.setFovHold(-3)
end

local function finish()
	if not charging then
		return
	end
	stopLocal()
	Request:FireServer("Release", aimDirection())
end

local function cancel()
	if not charging then
		return
	end
	stopLocal()
	Request:FireServer("Cancel")
end

local function onState(data)
	local status = data.Status
	if status == "Denied" then
		stopLocal()
		if data.Reason == "Cooldown" then
			SpinMeter.flashDenied(string.format("COOLDOWN %.1fs", data.Remaining or 0))
		else
			SpinMeter.flashDenied("STUNNED")
		end
	elseif status == "Cancelled" then
		stopLocal()
		if data.Reason == "Interrupted" then
			SpinMeter.flashDenied("INTERRUPTED!")
		end
		SpinMeter.startCooldown(data.Cooldown or 0)
	elseif status == "Released" then
		if charging then
			stopLocal() -- server auto-released at max hold
		end
		local level = SpinConfig.Levels[data.Level]
		if data.Perfect then
			SpinMeter.popup("PERFECT SPIN!", SpinConfig.Colors.Perfect, true)
		else
			SpinMeter.popup(level.Name, SpinConfig.Colors.GoldLight, false)
		end
		SpinMeter.startCooldown(data.Cooldown or 0)
	end
end

function SpinController.init()
	Request = Net.get("SpinRequest")
	local FX = Net.get("SpinFX")
	FX.OnClientEvent:Connect(function(name, data)
		if name == "SpinState" then
			onState(data)
		end
	end)

	local input = SpinConfig.Input
	ContextActionService:BindAction(input.ActionName, function(_, state)
		if state == Enum.UserInputState.Begin then
			begin()
		elseif state == Enum.UserInputState.End then
			finish()
		elseif state == Enum.UserInputState.Cancel then
			cancel()
		end
		return Enum.ContextActionResult.Sink
	end, true, input.Keyboard, input.Gamepad)
	ContextActionService:SetTitle(input.ActionName, input.MobileButtonTitle)
	ContextActionService:SetPosition(input.ActionName, input.MobileButtonPosition)

	RunService.RenderStepped:Connect(function()
		if charging then
			SpinMeter.updateCharge(os.clock() - chargeStart)
		end
	end)

	player.CharacterAdded:Connect(function()
		stopLocal()
	end)
end

return SpinController
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/SpinVFX", Class = "ModuleScript", Source = [=[
--[[
	SpinVFX  (StarterPlayerScripts.SpinClient.SpinVFX)

	Draws everything the Golden Spin does, for every player, on every client:
	  * Charge: Steel Ball spinning in the hand, golden rings that multiply
	    per level, rising particles, ground dust, perfect-window flash
	  * Release: muzzle shockwave, throw pose
	  * Projectile: spinning ball, tilted rotating rings, spiral + streak
	    trails, afterimages (High)
	  * Impact / Hit: layered shockwaves, sparks, dust, light, shake,
	    impact frame on Perfect, floating damage numbers for the attacker

	Visual only. The server decides every hit and every number.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local SpinConfig = require(Shared.SpinConfig)
local VFXQuality = require(Shared.VFXQuality)
local SteelBallModel = require(Shared.SteelBallModel)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)
local CameraFX = require(script.Parent.CameraFX)
local ProceduralPose = require(script.Parent.ProceduralPose)

local SpinVFX = {}

local localPlayer = Players.LocalPlayer
local colors = SpinConfig.Colors
local sounds = SpinConfig.Sounds

local chargeStates = {} -- [character] = state
local projectiles = {} -- [id] = visual
local ballPool = {}

---------------------------------------------------------------------------
-- Ball pool (projectile balls are reused instead of rebuilt every throw)
---------------------------------------------------------------------------
local function takeBall(scale)
	local ball = table.remove(ballPool)
	if not ball then
		ball = SteelBallModel.build(1, VFXQuality.get().Grooves)
		local core = ball.PrimaryPart
		core.Anchored = true
		-- Spiral trail: attachments rotate with the ball, so the ribbon twists.
		local trail = Instance.new("Trail")
		trail.Name = "SpiralTrail"
		trail.Attachment0 = core:FindFirstChild("TrailTop")
		trail.Attachment1 = core:FindFirstChild("TrailBottom")
		trail.Color = ColorSequence.new(colors.SpinLine, colors.SpinGlow)
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.Lifetime = 0.18
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		trail.FaceCamera = false
		trail.Parent = core
	end
	ball:ScaleTo(scale)
	return ball
end

local function returnBall(ball)
	ball.Parent = nil
	if #ballPool < 8 then
		table.insert(ballPool, ball)
	else
		ball:Destroy()
	end
end

VFXQuality.Changed:Connect(function()
	for _, ball in ipairs(ballPool) do
		ball:Destroy()
	end
	ballPool = {}
end)

---------------------------------------------------------------------------
-- Charge visuals
---------------------------------------------------------------------------
local function createCharge(character)
	local hand, grip = ProceduralPose.getHand(character)
	if not hand then
		return nil
	end
	local quality = VFXQuality.get()
	local ball = SteelBallModel.build(1, quality.Grooves)
	local core = ball.PrimaryPart
	core.Anchored = false
	ball:PivotTo(hand.CFrame * grip)
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = core
	weld.C0 = grip
	weld.Parent = core
	ball.Parent = VFXLib.Folder

	local rings = {}
	for i = 1, 3 do
		rings[i] = VFXLib.ring({
			Radius = 0.75 + i * 0.28,
			Width = 0.1,
			Color = colors.SpinLine,
			Transparency = 1,
		})
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Sparkle
	emitter.Color = ColorSequence.new(colors.SpinGlow, colors.GoldLight)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 6, 0)
	emitter.Rate = 0
	emitter.Parent = core:FindFirstChild("Center") or core

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = colors.Gold
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = character
	highlight.Parent = VFXLib.Folder

	ProceduralPose.play(character, "Charge", 0.18)

	return {
		Character = character,
		Ball = ball,
		Core = core,
		Weld = weld,
		Grip = grip,
		Rings = rings,
		Emitter = emitter,
		Highlight = highlight,
		Sound = VFXLib.sound(sounds.Charge, core, 0.45, 0.8, true),
		Angle = 0,
		Level = 0,
		InPerfect = false,
		NextDust = 0,
	}
end

local function destroyCharge(state, released)
	state.Ball:Destroy()
	for _, ring in ipairs(state.Rings) do
		ring:Destroy()
	end
	state.Highlight:Destroy()
	if state.Sound then
		state.Sound:Destroy()
	end
	if not released then
		ProceduralPose.reset(state.Character, 0.25)
	end
end

local function updateCharge(state, startTime, dt, now)
	local chargeTime = workspace:GetServerTimeNow() - startTime
	local level, perfect = SpinConfig.getLevel(chargeTime)
	local quality = VFXQuality.get()
	local core = state.Core

	-- Ball spin speeds up with each level.
	state.Angle = state.Angle + dt * (10 + level * 7)
	state.Weld.C0 = state.Grip * CFrame.Angles(state.Angle, state.Angle * 0.35, 0)

	-- Rings: one per level, each on its own tilted, precessing axis.
	local center = core.Position
	for i, ring in ipairs(state.Rings) do
		if i <= level then
			local tilt = 0.5 + i * 0.7
			ring:SetCFrame(CFrame.new(center) * CFrame.Angles(tilt + now * 0.8 * i, now * (3 + i), tilt * 0.5))
			ring:SetTransparency(perfect and 0 or 0.25)
			ring:SetWidth(perfect and 0.18 or 0.1)
			ring:SetColor(perfect and colors.Gold or colors.SpinLine)
		else
			ring:SetTransparency(1)
		end
	end

	state.Emitter.Rate = (perfect and 60 or level * 14) * quality.Particles
	if state.Sound then
		state.Sound.PlaybackSpeed = 0.8 + math.min(chargeTime, 2) * 0.3
	end

	-- Level up pulse.
	if level > state.Level then
		if state.Level > 0 then
			VFXLib.shockwave(CFrame.new(center), { Radius = 3 + level, Width = 0.2, Duration = 0.3, Color = colors.Gold })
			VFXLib.burst(center, { Count = 10 * level, Color = colors.GoldLight, Speed = 10, Lifetime = 0.4, Size = NumberSequence.new(0.25, 0) })
			VFXLib.sound(sounds.LevelUp, core, 0.5, 0.9 + level * 0.15)
		end
	end
	state.Level = level

	-- Perfect window: bright outline flash + chime.
	if perfect and not state.InPerfect then
		state.Highlight.OutlineTransparency = 0
		VFXLib.burst(center, { Count = 24, Color = colors.Perfect, Speed = 16, Lifetime = 0.35 })
		VFXLib.flash(center, colors.GoldLight, 5, 14, 0.25)
		VFXLib.sound(sounds.Perfect, core, 0.7, 1)
	elseif not perfect and state.InPerfect then
		state.Highlight.OutlineTransparency = 1
	end
	state.InPerfect = perfect

	-- Ground dust swirl at Power level and above.
	if level >= 2 and now >= state.NextDust then
		state.NextDust = now + 0.3
		local root = state.Character:FindFirstChild("HumanoidRootPart")
		if root then
			VFXLib.shockwave(CFrame.new(root.Position - Vector3.new(0, 2.8, 0)), {
				StartRadius = 1.5,
				Radius = 5 + level,
				Width = 0.25,
				Duration = 0.5,
				Color = colors.Gold,
				Spin = 2,
			})
		end
	end
end

local function chargeLoop(dt)
	local now = os.clock()
	local seen = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local startTime = character and character:GetAttribute("SpinChargeStart")
		if startTime then
			seen[character] = true
			local state = chargeStates[character]
			if not state then
				state = createCharge(character)
				chargeStates[character] = state
			end
			if state then
				updateCharge(state, startTime, dt, now)
			end
		end
	end
	for character, state in pairs(chargeStates) do
		if not seen[character] then
			chargeStates[character] = nil
			destroyCharge(state, state.Released)
		end
	end
end

---------------------------------------------------------------------------
-- Release / projectile / impact
---------------------------------------------------------------------------
local function ringAxisAlong(position, direction)
	-- Ring axis (UpVector) along the travel direction.
	return CFrame.lookAt(position, position + direction) * CFrame.Angles(math.pi / 2, 0, 0)
end

local function onRelease(data)
	local character = data.Character
	local state = character and chargeStates[character]
	if state then
		state.Released = true
	end
	if character then
		ProceduralPose.play(character, "Throw", 0.06)
		task.delay(0.3, function()
			ProceduralPose.reset(character, 0.3)
		end)
	end

	local level = SpinConfig.Levels[data.Level]
	local axis = ringAxisAlong(data.Origin, data.Direction)
	VFXLib.shockwave(axis, { Radius = 2 + data.Level * 1.5, Width = 0.35, Duration = 0.3, Color = colors.Gold })
	VFXLib.burst(data.Origin, {
		Count = 12 * data.Level,
		Color = colors.Gold,
		Speed = 25,
		Spread = 25,
		Direction = data.Direction,
		Lifetime = 0.35,
	})
	VFXLib.sound(sounds.Release, data.Origin, 0.7, 1.15 - data.Level * 0.1)

	if data.Perfect then
		for i = 1, 3 do
			task.delay(i * 0.04, function()
				VFXLib.shockwave(axis * CFrame.new(0, -i * 1.2, 0), {
					Radius = 3 + i * 1.5,
					Width = 0.3,
					Duration = 0.35,
					Color = colors.Perfect,
				})
			end)
		end
		VFXLib.flash(data.Origin, colors.GoldLight, 8, 24, 0.35)
	end

	if character and character == localPlayer.Character then
		CameraFX.shake(level.CameraShake * 0.6, 0.25)
		if data.Perfect then
			CameraFX.speedLines(0.35, colors.GoldLight)
			CameraFX.fovPunch(10, 0.4)
		else
			CameraFX.fovPunch(3 + data.Level * 2, 0.3)
		end
	end
end

local function spawnProjectile(data)
	local visualData = data.Visual or {}
	local levelIndex = visualData.Level or 1
	local level = SpinConfig.Levels[levelIndex]
	local perfect = visualData.Perfect == true

	local ball = takeBall(level.BallScale)
	local core = ball.PrimaryPart
	local start = CFrame.lookAt(data.Origin, data.Origin + data.Direction)
	ball:PivotTo(start)
	ball.Parent = VFXLib.Folder
	local spiral = core:FindFirstChild("SpiralTrail")
	if spiral then
		spiral:Clear()
	end

	-- Flat golden streak trail on a carrier that doesn't spin.
	local carrier = VFXLib.anchor(start)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-level.TrailWidth / 2, 0, 0)
	a0.Parent = carrier
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(level.TrailWidth / 2, 0, 0)
	a1.Parent = carrier
	local streak = Instance.new("Trail")
	streak.Attachment0 = a0
	streak.Attachment1 = a1
	streak.Color = ColorSequence.new(perfect and colors.Perfect or colors.GoldLight, colors.Gold)
	streak.LightEmission = 1
	streak.LightInfluence = 0
	streak.Lifetime = 0.25 + levelIndex * 0.08
	streak.WidthScale = NumberSequence.new(1, 0)
	streak.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	streak.FaceCamera = true
	streak.Parent = carrier

	local rings = {}
	for i = 1, level.Rings do
		rings[i] = VFXLib.ring({
			Radius = level.BallScale * 0.7 + i * 0.25,
			Width = 0.12 + (perfect and 0.06 or 0),
			Color = perfect and colors.Gold or colors.SpinLine,
		})
	end

	local visual = {
		Id = data.Id,
		Ball = ball,
		Core = core,
		Carrier = carrier,
		Streak = streak,
		Rings = rings,
		Origin = data.Origin,
		Direction = data.Direction,
		Speed = data.Speed,
		Range = data.Range,
		ServerTime = data.ServerTime,
		Level = levelIndex,
		Perfect = perfect,
		Spin = 0,
		NextGhost = 0,
		Expire = os.clock() + data.Range / data.Speed + 1.5,
	}
	projectiles[data.Id] = visual
end

local function removeProjectile(visual)
	projectiles[visual.Id] = nil
	returnBall(visual.Ball)
	for _, ring in ipairs(visual.Rings) do
		ring:Destroy()
	end
	visual.Streak.Enabled = false -- let the streak fade out on its own
	game:GetService("Debris"):AddItem(visual.Carrier, visual.Streak.Lifetime + 0.1)
end

local function projectileLoop(dt)
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for _, v in pairs(projectiles) do
		local distance = math.min(v.Speed * (serverNow - v.ServerTime), v.Range)
		local position = v.Origin + v.Direction * distance
		v.Spin = v.Spin + dt * (18 + v.Level * 6)
		local facing = CFrame.lookAt(position, position + v.Direction)
		v.Ball:PivotTo(facing * CFrame.Angles(-v.Spin, 0, v.Spin * 0.15))
		v.Carrier.CFrame = facing
		for i, ring in ipairs(v.Rings) do
			local tilt = 0.35 * i
			ring:SetCFrame(ringAxisAlong(position, v.Direction) * CFrame.Angles(tilt * math.sin(now * 6 + i), v.Spin * (0.4 + i * 0.2), tilt))
		end
		if now >= v.NextGhost then
			v.NextGhost = now + 0.05
			VFXLib.afterimage(v.Core.CFrame, SpinConfig.Levels[v.Level].BallScale, v.Perfect and colors.Perfect or colors.Gold)
		end
		if now > v.Expire then
			removeProjectile(v) -- safety: server end event never arrived
		end
	end
end

local function impact(position, normal, levelIndex, perfect, ownerIsLocal)
	local level = SpinConfig.Levels[levelIndex]
	local axis = CFrame.lookAt(position, position + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
	local color = perfect and colors.Perfect or colors.Gold

	for i = 1, levelIndex do
		task.delay((i - 1) * 0.05, function()
			VFXLib.shockwave(axis, {
				Radius = level.ShockwaveRadius * (1 - (i - 1) * 0.28),
				Width = 0.5 + levelIndex * 0.15,
				Duration = 0.4 + i * 0.05,
				Color = i == 1 and color or colors.Orange,
				Spin = 1.5 * i,
			})
		end)
	end
	if normal.Y > 0.5 then
		VFXLib.groundDisc(position, normal, { Radius = level.ShockwaveRadius * 0.6, Color = colors.Gold, Duration = 0.35 })
	end
	VFXLib.burst(position, { Count = 18 * levelIndex, Color = colors.GoldLight, Speed = 30, Lifetime = 0.5 })
	-- Metal sparks that fall with gravity.
	VFXLib.burst(position, {
		Count = 14 * levelIndex,
		Color = colors.Orange,
		Speed = 45,
		Lifetime = 0.6,
		Drag = 1,
		Acceleration = Vector3.new(0, -70, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) }),
		Direction = normal,
		Spread = 70,
	})
	-- Desert dust.
	VFXLib.burst(position, {
		Count = 6 * levelIndex,
		Texture = VFXLib.Textures.Smoke,
		Color = Color3.fromRGB(196, 168, 120),
		LightEmission = 0,
		Speed = 8,
		Lifetime = 1.1,
		Drag = 3,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) }),
		TransparencySeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
	})
	VFXLib.flash(position, colors.Gold, 3 + levelIndex * 2, 12 + levelIndex * 6, 0.35)
	VFXLib.sound(sounds.Impact, position, 0.6 + levelIndex * 0.15, 1.1 - levelIndex * 0.1)
	CameraFX.shakeAt(position, level.CameraShake * 2, 60 + levelIndex * 20)
	if perfect and ownerIsLocal then
		CameraFX.impactFrame(colors.GoldLight)
	end
end

local function endProjectile(data)
	local visual = projectiles[data.Id]
	local levelIndex = (data.Visual and data.Visual.Level) or (visual and visual.Level) or 1
	local perfect = data.Visual and data.Visual.Perfect == true
	if visual then
		visual.Ball:PivotTo(CFrame.new(data.Position))
		removeProjectile(visual)
	end
	-- Impact frame only for the thrower, and only when the ball hit someone.
	local ownerIsLocal = data.HitCharacter and data.OwnerId == localPlayer.UserId
	impact(data.Position, data.Normal, levelIndex, perfect, ownerIsLocal)
end

local function onHit(data)
	if not data.Victim then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Adornee = data.Victim
	highlight.FillColor = data.Blocked and Color3.fromRGB(140, 200, 255) or Color3.new(1, 1, 1)
	highlight.OutlineColor = data.Blocked and Color3.fromRGB(80, 160, 255) or colors.Gold
	highlight.FillTransparency = 0.3
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = VFXLib.Folder
	VFXLib.animate(0.18, function(a)
		highlight.FillTransparency = 0.3 + 0.7 * a
		highlight.OutlineTransparency = a
	end, function()
		highlight:Destroy()
	end)
	if data.Blocked then
		VFXLib.burst(data.Position, { Count = 12, Color = Color3.fromRGB(150, 210, 255), Speed = 25, Lifetime = 0.3 })
	end
	if localPlayer.Character and data.Victim == localPlayer.Character then
		CameraFX.shake(0.4 + (data.Level or 1) * 0.2, 0.3)
		if data.Perfect then
			CameraFX.impactFrame(colors.GoldLight)
		end
	end
end

-- Floating damage number, only for the attacker.
local function onDamage(data)
	local carrier = VFXLib.anchor(CFrame.new(data.Position + Vector3.new(math.random() - 0.5, 2, math.random() - 0.5)), 1.2)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 60)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = carrier
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = data.Blocked and ("BLOCKED " .. data.Amount) or (tostring(data.Amount) .. (data.Perfect and "!" or ""))
	label.TextColor3 = data.Blocked and Color3.fromRGB(170, 200, 230) or (data.Perfect and colors.Perfect or colors.Gold)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(60, 25, 0)
	label.Parent = billboard
	local start = carrier.Position
	VFXLib.animate(1, function(a)
		carrier.Position = start + Vector3.new(0, a * 3, 0)
		label.TextTransparency = math.max(0, (a - 0.6) / 0.4)
		label.TextStrokeTransparency = label.TextTransparency
		local pop = a < 0.1 and (1 + (0.1 - a) * 4) or 1
		billboard.Size = UDim2.fromOffset(160 * pop * (data.Perfect and 1.3 or 1), 60 * pop * (data.Perfect and 1.3 or 1))
	end)
end

function SpinVFX.init()
	local FX = Net.get("SpinFX")
	FX.OnClientEvent:Connect(function(name, data)
		if name == "SpinRelease" then
			onRelease(data)
		elseif name == "ProjectileSpawn" and data.Kind == "SteelBall" then
			spawnProjectile(data)
		elseif name == "ProjectileEnd" and data.Kind == "SteelBall" then
			endProjectile(data)
		elseif name == "Hit" then
			onHit(data)
		elseif name == "Damage" then
			onDamage(data)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		chargeLoop(dt)
		projectileLoop(dt)
	end)
end

return SpinVFX
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/TuskActVFX", Class = "Folder", Source = nil },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/TuskActVFX/Act1", Class = "ModuleScript", Source = [=[
--[[
	TuskActVFX.Act1  (StarterPlayerScripts.SpinClient.TuskActVFX.Act1)

	Client choreography for Tusk Act 1: poses, Stand motion, effects and
	sounds for each server event. Visual only.

	Every major move follows: startup -> anticipation -> impact frame ->
	primary shockwave -> secondary particles -> recovery.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local VFXLib = require(script.Parent.Parent.VFXLib)
local CameraFX = require(script.Parent.Parent.CameraFX)
local TuskVFX = require(script.Parent.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.Parent.TuskAnimation)
local TuskStand = require(script.Parent.Parent.TuskStand)

local Act1 = {}
local colors = TuskConfig.Colors
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

local function rootOf(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isLocal(character)
	return character ~= nil and character == localPlayer.Character
end

-- Swipe arc in front of the character (a quick curved ring segment).
local function swipe(root, side, color)
	if not VFXLib.acquire() then
		return
	end
	local cf = root.CFrame * CFrame.new(side * 0.4, 0.3, -2.4) * CFrame.Angles(0, 0, side * 0.5)
	local ring = VFXLib.ring({ CFrame = cf, Radius = 1.6, Width = 0.22, Color = color, Segments = 10, Transparency = 0.1 })
	VFXLib.animate(0.16, function(a)
		ring:SetCFrame(cf * CFrame.Angles(0, side * (-1.2 + a * 2.4), 0))
		ring:SetRadius(1.6 + a * 0.8)
		ring:SetTransparency(0.1 + a * 0.9)
	end, function()
		ring:Destroy()
		VFXLib.release()
	end)
end

---------------------------------------------------------------------------
-- M1
---------------------------------------------------------------------------
local function onM1(data)
	local character = data.Character
	local root = rootOf(character)
	if not root then
		return
	end
	local index = data.Index
	TuskAnimation.play(character, "M1_" .. index)
	VFXLib.sound(sounds.Swing, root, 0.5, 0.95 + index * 0.06)
	if index == 1 then
		TuskStand.action(character, "Lunge", { Target = CFrame.new(0.4, 0.6, -3), Duration = 0.26 })
		swipe(root, 1, colors.Cyan)
	elseif index == 2 then
		TuskStand.action(character, "Lunge", { Target = CFrame.new(-0.6, 0.4, -3.2), Duration = 0.26 })
		swipe(root, -1, colors.Ice)
		-- Nail glint on the strike.
		VFXLib.burst((root.CFrame * CFrame.new(0, 0.4, -2.6)).Position, { Count = 6, Color = colors.Ice, Speed = 10, Lifetime = 0.2 })
	elseif index == 3 then
		TuskStand.action(character, "Lunge", { Target = CFrame.new(0.9, 1, -2.4), Duration = 0.3 })
	elseif index == 4 then
		TuskStand.action(character, "Lunge", { Target = CFrame.new(0, 1.4, -3.4), Duration = 0.5 })
		-- Anticipation: energy gathers above the fist during the wind-up.
		local gatherAt = (root.CFrame * CFrame.new(0.8, 2.2, -0.6)).Position
		VFXLib.burst(gatherAt, { Count = 8, Color = colors.Cyan, Speed = 4, Lifetime = 0.15 })
	end
end

local function onM1Finisher(data)
	local character = data.Character
	local root = rootOf(character)
	local pos = data.Position
	local ground = pos - Vector3.new(0, 2.6, 0)
	if data.Hit and isLocal(character) then
		CameraFX.impactFrame(colors.Ice)
	end
	TuskVFX.CreateRotationalShockwave(CFrame.new(ground), { Radius = data.Radius or 7, Layers = 3, Color = colors.Cyan, Color2 = colors.Blue, Ground = true, Particles = 1.5, Width = 0.5 })
	TuskVFX.CreateImpact(pos, root and -root.CFrame.LookVector or Vector3.new(0, 1, 0), { Size = 1.2, Radius = 3, Layers = 2, Color = colors.Ice, Color2 = colors.Cyan, Ground = false })
	VFXLib.sound(sounds.Finisher, pos, 0.8, 1)
	CameraFX.shakeAt(pos, 0.6, 50)
end

---------------------------------------------------------------------------
-- Abilities
---------------------------------------------------------------------------
local function onAbility(data)
	local character = data.Character
	local root = rootOf(character)
	if not root then
		return
	end
	if data.Move == "NailShot" and data.Phase == "Startup" then
		TuskAnimation.play(character, "NailShot")
		TuskStand.action(character, "Lunge", { Target = CFrame.new(1.4, 0.8, -1.2), Duration = data.Startup + 0.25 })
		-- Anticipation: a small spinning charge at the fingertip.
		local charge = TuskVFX.CreateEnergyCharge({
			Follow = function()
				return root.Parent and root.CFrame * CFrame.new(0.9, 0.55, -1.6) or nil
			end,
			Color = colors.Cyan,
			Color2 = colors.Ice,
			MaxRadius = 0.5,
			Duration = data.Startup,
			Rings = 1,
			Particles = 0.5,
		})
		task.delay(data.Startup, function()
			charge:Release(data.Direction)
		end)
	elseif data.Move == "NailBarrage" and data.Phase == "Startup" then
		TuskAnimation.play(character, "NailBarrage")
		TuskStand.action(character, "Lunge", { Target = CFrame.new(1.6, 1.2, -1), Duration = data.Startup + data.Count * data.Interval + 0.2 })
		VFXLib.burst((root.CFrame * CFrame.new(0.9, 0.55, -1.6)).Position, { Count = 10, Color = colors.Cyan, Speed = 6, Lifetime = 0.2 })
	elseif data.Move == "SpinningNail" then
		if data.Phase == "Release" then
			TuskAnimation.stopHold(character, "ChargeNail")
			TuskAnimation.play(character, "SpinningNailRelease")
			if isLocal(character) then
				CameraFX.fovPunch(data.Full and 9 or 4, 0.35)
				CameraFX.shake(data.Full and 0.5 or 0.2, 0.25)
			end
		elseif data.Phase == "Cancel" then
			TuskAnimation.stopHold(character, "ChargeNail")
		end
	end
end

---------------------------------------------------------------------------
-- Hold charge visuals (driven by the replicated TuskCharge attribute)
---------------------------------------------------------------------------
local charges = {} -- [character] = { Effect, Full, Sound }

local function updateCharges()
	local seen = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local start = character and character:GetAttribute("TuskCharge")
		if start and character:GetAttribute("TuskAct") == 1 and character:GetAttribute("TuskChargeMove") == "SpinningNail" then
			seen[character] = true
			local root = rootOf(character)
			local c = charges[character]
			if not c and root then
				TuskAnimation.hold(character, "ChargeNail")
				local effect = TuskVFX.CreateEnergyCharge({
					Follow = function()
						return root.Parent and root.CFrame * CFrame.new(0, 0.6, -1.7) or nil
					end,
					Color = colors.Cyan,
					Color2 = colors.Ice,
					MaxRadius = 1.1,
					Rings = 3,
					Manual = true,
				})
				c = { Effect = effect, Full = false, Sound = VFXLib.sound(sounds.ChargeLoop, root, 0.4, 0.8, true) }
				charges[character] = c
			end
			if c then
				local p = math.clamp((workspace:GetServerTimeNow() - start) / TuskConfig.Act1.SpinningNail.FullChargeAt, 0, 1)
				c.Effect:SetProgress(p)
				if c.Sound then
					c.Sound.PlaybackSpeed = 0.8 + p * 0.6
				end
				if p >= 1 and not c.Full then
					-- Full charge: rings turn golden-blue, flash, chime.
					c.Full = true
					for i, ring in ipairs(c.Effect.Rings) do
						ring:SetColor(i == 1 and colors.Gold or colors.Cyan)
					end
					local pos = root.CFrame * CFrame.new(0, 0.6, -1.7)
					VFXLib.burst(pos.Position, { Count = 16, Color = colors.Gold, Speed = 12, Lifetime = 0.3 })
					VFXLib.flash(pos.Position, colors.Gold, 5, 12, 0.25)
					VFXLib.sound(sounds.ChargeFull, root, 0.7, 1)
				end
			end
		end
	end
	for character, c in pairs(charges) do
		if not seen[character] then
			charges[character] = nil
			if c.Full or (c.Effect.Progress or 0) > 0.05 then
				local dir = rootOf(character) and rootOf(character).CFrame.LookVector
				c.Effect:Release(dir)
			else
				c.Effect:Destroy()
			end
			if c.Sound then
				c.Sound:Destroy()
			end
			TuskAnimation.stopHold(character, "ChargeNail")
		end
	end
end

---------------------------------------------------------------------------
-- Awakened aura (driven by the TuskAwakened attribute)
---------------------------------------------------------------------------
local auras = {}

local function updateAuras()
	local seen = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character:GetAttribute("TuskAwakened") and character:GetAttribute("TuskAct") == 1 then
			seen[character] = true
			if not auras[character] then
				auras[character] = TuskVFX.CreateGoldenAura(character, { Color = colors.Cyan, Color2 = colors.Blue, Rings = 2 })
			end
		end
	end
	for character, aura in pairs(auras) do
		if not seen[character] then
			auras[character] = nil
			aura:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- Ultimate: TUSK AWAKENING
---------------------------------------------------------------------------
local function onUltimate(data)
	local character = data.Character
	local root = rootOf(character)
	if not root then
		return
	end
	if data.Phase == "Start" then
		TuskAnimation.play(character, "Awakening")
		VFXLib.sound(sounds.AwakeningBuild, root, 0.8, 1)
		TuskVFX.CreateTuskTransformation(character, {
			Duration = data.Windup,
			Color = colors.Cyan,
			Color2 = colors.Blue,
			OnManifest = function()
				TuskStand.action(character, "Manifest", { Duration = 0.6 })
			end,
		})
		if isLocal(character) then
			-- Camera transition: slow push-in during the buildup.
			CameraFX.setFovHold(-12)
			task.delay(data.Windup, function()
				CameraFX.setFovHold(0)
				CameraFX.fovPunch(16, 0.6)
			end)
		end
	elseif data.Phase == "Burst" then
		VFXLib.sound(sounds.AwakeningBurst, data.Position, 1, 1)
		CameraFX.shakeAt(data.Position, 1.2, 90)
		if isLocal(character) then
			CameraFX.speedLines(0.5, colors.Ice)
			CameraFX.impactFrame(colors.Ice)
		end
	end
end

function Act1.handle(name, data)
	if name == "M1" then
		onM1(data)
	elseif name == "M1Finisher" then
		onM1Finisher(data)
	elseif name == "Ability" then
		onAbility(data)
	elseif name == "Ultimate" then
		onUltimate(data)
	end
end

function Act1.step()
	updateCharges()
	updateAuras()
end

return Act1
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/TuskAnimation", Class = "ModuleScript", Source = [=[
--[[
	TuskAnimation  (StarterPlayerScripts.SpinClient.TuskAnimation)
	("TuskAnimationController" in the design doc)

	Plays Tusk character animations on ANY character, on every client.
	Two layers per character:
	  * Hold   : a sustained pose (Sneak, Charge) until stopped
	  * Action : a short keyframed move (M1 hits, Nail Shot...) that plays
	             on top, then blends back to the Hold pose or rest

	Default = procedural poses built from Motor6D C0 offsets (no uploads
	needed, works on R15 and R6). If TuskConfig.AnimationIds[name] holds
	an uploaded animation id, that real animation plays instead.

	Pose values: degrees {X, Y, Z} rotation in the parent part's space,
	optional 4th value = vertical offset in studs.
	  Arms:  +X raises the arm forward.   Waist: -X bends forward.
	  Hips:  +X lifts the thigh forward.   Knees: -X bends the knee.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local VFXLib = require(script.Parent.VFXLib)
local JointCache = require(script.Parent.JointCache)

local TuskAnimation = {}

local JOINTS = {
	R15 = {
		RightArm = { "RightUpperArm", "RightShoulder" },
		LeftArm = { "LeftUpperArm", "LeftShoulder" },
		Waist = { "UpperTorso", "Waist" },
		Neck = { "Head", "Neck" },
		Root = { "LowerTorso", "Root" },
		RightHip = { "RightUpperLeg", "RightHip" },
		LeftHip = { "LeftUpperLeg", "LeftHip" },
		RightKnee = { "RightLowerLeg", "RightKnee" },
		LeftKnee = { "LeftLowerLeg", "LeftKnee" },
	},
	R6 = {
		RightArm = { "Torso", "Right Shoulder" },
		LeftArm = { "Torso", "Left Shoulder" },
		Neck = { "Torso", "Neck" },
		Root = { "HumanoidRootPart", "RootJoint" },
		RightHip = { "Torso", "Right Hip" },
		LeftHip = { "Torso", "Left Hip" },
	},
}

TuskAnimation.Poses = {
	Rest = {},
	Point = { RightArm = { 92, 0, 0 }, LeftArm = { 15, 0, -10 }, Waist = { 0, -18, 0 } },
	PointRecoil = { RightArm = { 110, 0, 0 }, Waist = { 6, -14, 0 } },
	Jab = { RightArm = { 88, 0, 12 }, Waist = { 0, -28, 0 }, LeftArm = { 30, 0, -20 } },
	JabLeft = { LeftArm = { 88, 0, -12 }, Waist = { 0, 28, 0 }, RightArm = { 30, 0, 20 } },
	SpinPoke = { RightArm = { 100, 25, 0 }, Waist = { -10, -24, 0 }, LeftArm = { 20, 0, -30 } },
	SlamWindup = { RightArm = { 165, 0, 10 }, LeftArm = { 40, 0, -30 }, Waist = { 12, 15, 0 } },
	Slam = { RightArm = { 55, 0, 0 }, LeftArm = { 20, 0, -20 }, Waist = { -22, -10, 0 } },
	ChargeNail = { RightArm = { 75, 0, 28 }, LeftArm = { 75, 0, -28 }, Waist = { -8, 0, 0 } },
	BarrageA = { RightArm = { 95, 4, 0 }, LeftArm = { 60, 0, -20 }, Waist = { 0, -14, 0 } },
	BarrageB = { RightArm = { 88, -4, 0 }, LeftArm = { 60, 0, -20 }, Waist = { 0, -18, 0 } },
	AwakenCrouch = { RightArm = { 30, 0, 40 }, LeftArm = { 30, 0, -40 }, Waist = { -25, 0, 0 }, Neck = { -15, 0, 0 } },
	AwakenRise = { RightArm = { 130, 0, 35 }, LeftArm = { 130, 0, -35 }, Waist = { 14, 0, 0 }, Neck = { 22, 0, 0 } },
	Sneak = {
		Root = { 0, 0, 0, -0.65 },
		Waist = { -26, 0, 0 },
		Neck = { 22, 0, 0 },
		RightHip = { 50, 0, 0 },
		LeftHip = { 50, 0, 0 },
		RightKnee = { -85, 0, 0 },
		LeftKnee = { -85, 0, 0 },
		RightArm = { 25, 0, 8 },
		LeftArm = { 25, 0, -8 },
	},
	Emerge = { RightArm = { 150, 0, 15 }, LeftArm = { 40, 0, -40 }, Waist = { 15, 0, 0 } },
}

--[[
	Action sequences: list of keyframes { Time, Pose, (optional) Ease }.
	The last keyframe's Time is the length; after it the joints blend back.
]]
TuskAnimation.Actions = {
	M1_1 = { { 0, "Rest" }, { 0.07, "Jab" }, { 0.22, "Jab" } },
	M1_2 = { { 0, "Rest" }, { 0.07, "JabLeft" }, { 0.22, "JabLeft" } },
	M1_3 = { { 0, "Rest" }, { 0.08, "SpinPoke" }, { 0.25, "SpinPoke" } },
	M1_4 = { { 0, "Rest" }, { 0.12, "SlamWindup" }, { 0.2, "Slam" }, { 0.5, "Slam" } },
	NailShot = { { 0, "Rest" }, { 0.12, "Point" }, { 0.2, "PointRecoil" }, { 0.45, "Point" } },
	NailBarrage = {
		{ 0, "Rest" }, { 0.12, "BarrageA" }, { 0.21, "BarrageB" }, { 0.3, "BarrageA" },
		{ 0.39, "BarrageB" }, { 0.48, "BarrageA" }, { 0.57, "BarrageB" }, { 0.8, "BarrageB" },
	},
	SpinningNailRelease = { { 0, "ChargeNail" }, { 0.06, "PointRecoil" }, { 0.4, "Point" } },
	Awakening = { { 0, "Rest" }, { 0.35, "AwakenCrouch" }, { 1.2, "AwakenCrouch" }, { 1.45, "AwakenRise" }, { 2.2, "AwakenRise" } },
	Emerge = { { 0, "Sneak" }, { 0.12, "Emerge" }, { 0.5, "Emerge" } },
}

local states = setmetatable({}, { __mode = "k" }) -- character -> { Hold, ActionJob, Tracks }

local function rigOf(character)
	if character:FindFirstChild("UpperTorso") then
		return "R15"
	elseif character:FindFirstChild("Torso") then
		return "R6"
	end
	return nil
end

local function motorsOf(character)
	local rig = rigOf(character)
	if not rig then
		return {}
	end
	local motors = {}
	for name, path in pairs(JOINTS[rig]) do
		local holder = character:FindFirstChild(path[1])
		local motor = holder and holder:FindFirstChild(path[2])
		if motor and motor:IsA("Motor6D") then
			motors[name] = motor
		end
	end
	return motors
end

-- C0 for a pose value (rotation applied in the parent part's space, about the joint).
local function poseC0(motor, value)
	local base = JointCache.original(motor)
	if not value then
		return base
	end
	local rotation = CFrame.Angles(math.rad(value[1]), math.rad(value[2]), math.rad(value[3]))
	local position = base.Position + Vector3.new(0, value[4] or 0, 0)
	return CFrame.new(position) * rotation * (base - base.Position)
end

local function resolvePose(pose)
	if typeof(pose) == "string" then
		return TuskAnimation.Poses[pose] or {}
	end
	return pose or {}
end

local function getState(character)
	local s = states[character]
	if not s then
		s = { Hold = nil, Action = nil, Tracks = {} }
		states[character] = s
	end
	return s
end

local function animator(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

-- Real uploaded animation, if one is configured for this name.
local function playTrack(character, name, looped)
	local id = TuskConfig.AnimationIds[name]
	if not id or id == "" then
		return nil
	end
	local a = animator(character)
	if not a then
		return nil
	end
	local s = getState(character)
	local track = s.Tracks[name]
	if not track then
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, loaded = pcall(function()
			return a:LoadAnimation(anim)
		end)
		if not ok then
			return nil
		end
		track = loaded
		track.Priority = Enum.AnimationPriority.Action
		s.Tracks[name] = track
	end
	track.Looped = looped == true
	track:Play(0.1)
	return track
end

-- Blend every joint toward a target pose over `duration`.
local function blendTo(character, pose, duration)
	local motors = motorsOf(character)
	local from, to = {}, {}
	for name, motor in pairs(motors) do
		from[name] = motor.C0
		to[name] = poseC0(motor, pose[name])
	end
	return VFXLib.animate(duration, function(a)
		local e = VFXLib.easeOut(a)
		for name, motor in pairs(motors) do
			if motor.Parent then
				motor.C0 = from[name]:Lerp(to[name], e)
			end
		end
	end)
end

function TuskAnimation.play(character, name)
	if not character then
		return
	end
	if playTrack(character, name, false) then
		return
	end
	local frames = TuskAnimation.Actions[name]
	if not frames then
		return
	end
	local s = getState(character)
	VFXLib.cancel(s.Action)
	local motors = motorsOf(character)
	local holdPose = resolvePose(s.Hold)
	local length = frames[#frames][1]
	-- Precompute C0 targets per keyframe; frame 1 starts from the current pose.
	local keys = {}
	for i, frame in ipairs(frames) do
		local pose = resolvePose(frame[2])
		local c0s = {}
		for jointName, motor in pairs(motors) do
			if i == 1 then
				c0s[jointName] = motor.C0
			else
				c0s[jointName] = poseC0(motor, pose[jointName] or holdPose[jointName])
			end
		end
		keys[i] = { Time = frame[1], C0 = c0s }
	end
	local job
	job = VFXLib.animate(length, function(a)
		local t = a * length
		local k = 1
		while k < #keys and keys[k + 1].Time < t do
			k = k + 1
		end
		local current = keys[k]
		local nextKey = keys[math.min(k + 1, #keys)]
		local span = math.max(nextKey.Time - current.Time, 1e-3)
		local local01 = math.clamp((t - current.Time) / span, 0, 1)
		local e = VFXLib.easeOut(local01)
		for jointName, motor in pairs(motors) do
			if motor.Parent then
				motor.C0 = current.C0[jointName]:Lerp(nextKey.C0[jointName], e)
			end
		end
	end, function()
		if s.Action == job then
			s.Action = nil
			blendTo(character, resolvePose(s.Hold), 0.2)
		end
	end)
	s.Action = job
end

-- Sustained pose (e.g. "Sneak", "ChargeNail"). stopHold() releases it.
function TuskAnimation.hold(character, poseName)
	if not character then
		return
	end
	local s = getState(character)
	if s.Hold == poseName then
		return
	end
	s.Hold = poseName
	local track = playTrack(character, poseName, true)
	if track then
		return
	end
	if not s.Action then
		blendTo(character, resolvePose(poseName), 0.2)
	end
end

function TuskAnimation.stopHold(character, poseName)
	if not character then
		return
	end
	local s = getState(character)
	if poseName and s.Hold ~= poseName then
		return
	end
	local track = s.Hold and s.Tracks[s.Hold]
	if track then
		track:Stop(0.15)
	end
	s.Hold = nil
	if not s.Action then
		blendTo(character, {}, 0.25)
	end
end

-- Swap the local character's idle/walk/run animations while Tusk is equipped
-- (only if ids are configured). Restores the originals on unequip.
local savedAnimate = {}
function TuskAnimation.applyLocomotion(character, enabled)
	local animate = character and character:FindFirstChild("Animate")
	if not animate then
		return
	end
	local map = { idle = "Idle", walk = "Walk", run = "Run" }
	for folderName, key in pairs(map) do
		local id = TuskConfig.AnimationIds[key]
		local folder = animate:FindFirstChild(folderName)
		if folder and id and id ~= "" then
			for _, anim in ipairs(folder:GetChildren()) do
				if anim:IsA("Animation") then
					if enabled then
						savedAnimate[anim] = savedAnimate[anim] or anim.AnimationId
						anim.AnimationId = id
					elseif savedAnimate[anim] then
						anim.AnimationId = savedAnimate[anim]
					end
				end
			end
		end
	end
end

Players.LocalPlayer.CharacterRemoving:Connect(function(character)
	states[character] = nil
end)

return TuskAnimation
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/TuskController", Class = "ModuleScript", Source = [=[
--[[
	TuskController  (StarterPlayerScripts.SpinClient.TuskController)
	("TuskAbilityController" in the design doc)

	Local input for Tusk, and the router for Tusk visual events.
	  PC:         M1 = left click (hold to keep attacking), 1 / 2 / 3 = abilities,
	              G = ultimate, C = sneak, T = Act menu
	  Controller: RB, X / Y / B, D-pad up, LB, D-pad down
	  Mobile:     HUD buttons (slots, ultimate bar, sneak chip) + on-screen M1

	Sends only intents + aim direction. The server validates everything.
	Inputs are bound only while the local character has Tusk equipped, so
	other movesets keep their keys.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)
local TuskAnimation = require(script.Parent.TuskAnimation)
local TuskSneakController = require(script.Parent.TuskSneakController)
local TuskUI = require(script.Parent.UI.TuskUI)

local TuskController = {}

local player = Players.LocalPlayer
local Request
local actVFX = {}
local bound = false
local m1Held = false
local nextM1 = 0

local function aim()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return nil
	end
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch or string.find(last.Name, "Gamepad") then
		return camera.CFrame.LookVector
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, VFXLib.Folder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	local target = hit and hit.Position or ray.Origin + ray.Direction * 600
	local origin = (root.CFrame * CFrame.new(0.9, 0.55, -1.5)).Position
	local dir = target - origin
	return dir.Magnitude > 1 and dir.Unit or root.CFrame.LookVector
end

local function currentAct()
	local character = player.Character
	return character and character:GetAttribute("TuskAct")
end

function TuskController.ability(slot, began)
	local act = currentAct()
	local info = act and Registry.get(act)
	if not info then
		return
	end
	local kind = info.AbilityKinds[slot]
	if began then
		Request:FireServer("Ability", slot, "Press", aim())
	elseif kind == "Hold" then
		Request:FireServer("Ability", slot, "Release", aim())
	end
end

function TuskController.ultimate()
	Request:FireServer("Ultimate", aim())
end

function TuskController.toggleSneak()
	local character = player.Character
	local sneaking = character and character:GetAttribute("TuskSneaking") == true
	Request:FireServer("Sneak", not sneaking)
end

function TuskController.select(act)
	Request:FireServer("Select", act)
end

local function m1()
	Request:FireServer("M1", aim())
end

local ACTIONS = {
	TuskM1 = function(state)
		if state == Enum.UserInputState.Begin then
			m1Held = true
			nextM1 = 0
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			m1Held = false
		end
	end,
	TuskAbility1 = function(state)
		TuskController.ability(1, state == Enum.UserInputState.Begin)
	end,
	TuskAbility2 = function(state)
		TuskController.ability(2, state == Enum.UserInputState.Begin)
	end,
	TuskAbility3 = function(state)
		TuskController.ability(3, state == Enum.UserInputState.Begin)
	end,
	TuskUltimate = function(state)
		if state == Enum.UserInputState.Begin then
			TuskController.ultimate()
		end
	end,
	TuskSneak = function(state)
		if state == Enum.UserInputState.Begin then
			TuskController.toggleSneak()
		end
	end,
}

local KEYMAP = {
	TuskM1 = "M1",
	TuskAbility1 = "Ability1",
	TuskAbility2 = "Ability2",
	TuskAbility3 = "Ability3",
	TuskUltimate = "Ultimate",
	TuskSneak = "Sneak",
}

local function bindAll()
	if bound then
		return
	end
	bound = true
	for actionName, handler in pairs(ACTIONS) do
		local keys = TuskConfig.Keys[KEYMAP[actionName]]
		ContextActionService:BindAction(actionName, function(_, state)
			if state == Enum.UserInputState.End and actionName ~= "TuskM1" and not string.find(actionName, "Ability") then
				return Enum.ContextActionResult.Sink
			end
			handler(state)
			return Enum.ContextActionResult.Sink
		end, actionName == "TuskM1", keys.Keyboard, keys.Gamepad)
	end
	ContextActionService:SetTitle("TuskM1", "M1")
	ContextActionService:SetPosition("TuskM1", UDim2.new(1, -95, 1, -95))
	TuskAnimation.applyLocomotion(player.Character, true)
end

local function unbindAll()
	if not bound then
		return
	end
	bound = false
	m1Held = false
	for actionName in pairs(ACTIONS) do
		ContextActionService:UnbindAction(actionName)
	end
	TuskAnimation.applyLocomotion(player.Character, false)
end

function TuskController.init()
	Request = Net.get("TuskRequest")
	local FX = Net.get("TuskFX")

	local actsFolder = script.Parent:WaitForChild("TuskActVFX")
	for act in pairs(Registry.Acts) do
		local m = actsFolder:FindFirstChild("Act" .. act)
		if m then
			actVFX[act] = require(m)
		end
	end

	TuskUI.init({
		Ability = TuskController.ability,
		Ultimate = TuskController.ultimate,
		Sneak = TuskController.toggleSneak,
		Select = TuskController.select,
	})

	FX.OnClientEvent:Connect(function(name, data)
		if typeof(data) ~= "table" then
			return
		end
		if name == "TuskState" then
			TuskUI.onState(data)
		elseif name == "SneakAttack" then
			TuskSneakController.handle(name, data)
		else
			local m = actVFX[data.Act]
			if m then
				m.handle(name, data)
			end
		end
	end)

	-- Act menu key works whether or not Tusk is equipped.
	ContextActionService:BindAction("TuskActMenu", function(_, state)
		if state == Enum.UserInputState.Begin and TuskConfig.Progression.ShowSelectionMenu then
			TuskUI.toggleMenu()
		end
		return Enum.ContextActionResult.Sink
	end, false, TuskConfig.Keys.ActMenu.Keyboard, TuskConfig.Keys.ActMenu.Gamepad)

	RunService.RenderStepped:Connect(function()
		local act = currentAct()
		if act and not bound then
			bindAll()
		elseif not act and bound then
			unbindAll()
		end
		if m1Held and bound and os.clock() >= nextM1 then
			nextM1 = os.clock() + 0.12
			m1()
		end
		for _, m in pairs(actVFX) do
			if m.step then
				m.step()
			end
		end
		TuskUI.step(act)
	end)

	player.CharacterAdded:Connect(function()
		bound = false
		m1Held = false
	end)
end

return TuskController
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/TuskProjectiles", Class = "ModuleScript", Source = [=[
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
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/TuskSneakController", Class = "ModuleScript", Source = [=[
--[[
	TuskSneakController  (StarterPlayerScripts.SpinClient.TuskSneakController)

	Client side of Tusk Sneak and the Sneak Attack, for every Act.
	  Everyone sees: crouch pose, blue ground particles, ground ripples,
	                 burrow crack, the moving underground trail, the warning
	                 under the target, emergence and shockwave.
	  Local player:  lowered camera, slight zoom, blue screen-edge vignette
	                 (the HUD chip lives in TuskUI).
	Server state comes from the TuskSneaking / TuskBurrowed attributes and
	"SneakAttack" TuskFX events.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local VFXQuality = require(Shared.VFXQuality)
local VFXLib = require(script.Parent.VFXLib)
local CameraFX = require(script.Parent.CameraFX)
local TuskVFX = require(script.Parent.TuskVFX)
local TuskAnimation = require(script.Parent.TuskAnimation)
local TuskStand = require(script.Parent.TuskStand)

local TuskSneakController = {}
local colors = TuskConfig.Colors
local sounds = TuskConfig.Sounds
local localPlayer = Players.LocalPlayer

local sneakers = {} -- [character] = { Emitter, Attachment, NextRipple }
local hidden = {} -- [character] = true while burrowed
local vignette

local function setHidden(character, hide)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hide and 1 or 0
		end
	end
end

local function startSneakFX(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	TuskAnimation.hold(character, "Sneak")
	local attachment = Instance.new("Attachment")
	attachment.Name = "TuskSneakFX"
	attachment.Position = Vector3.new(0, -2.7, 0)
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Sparkle
	emitter.Color = ColorSequence.new(colors.Cyan, colors.Blue)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(0.5, 2)
	emitter.SpreadAngle = Vector2.new(80, 80)
	emitter.Acceleration = Vector3.new(0, 1.5, 0)
	emitter.Rate = 14 * VFXQuality.get().Particles
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = attachment
	VFXLib.sound(sounds.SneakIn, root, 0.4, 1)
	return { Attachment = attachment, NextRipple = 0 }
end

local function stopSneakFX(character, fx)
	if fx.Attachment then
		fx.Attachment:Destroy()
	end
	TuskAnimation.stopHold(character, "Sneak")
end

-- Local-only camera and screen treatment.
local function setLocalSneak(on)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		TweenService:Create(humanoid, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			CameraOffset = on and Vector3.new(0, -TuskConfig.Sneak.CameraDrop, 0) or Vector3.new(),
		}):Play()
	end
	CameraFX.setFovHold(on and -5 or 0)
	if vignette then
		TweenService:Create(vignette, TweenInfo.new(0.3), { ImageTransparency = on and 0.35 or 1 }):Play()
	end
end

local function buildVignette()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TuskSneakVignette"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	-- Four edge gradients instead of an uploaded vignette image.
	local holder = Instance.new("ImageLabel")
	holder.BackgroundTransparency = 1
	holder.ImageTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	for _, side in ipairs({ { 0, 0.5, 90 }, { 1, 0.5, 270 }, { 0.5, 0, 180 }, { 0.5, 1, 0 } }) do
		local edge = Instance.new("Frame")
		edge.AnchorPoint = Vector2.new(side[1], side[2])
		edge.Position = UDim2.fromScale(side[1], side[2])
		edge.Size = (side[3] == 90 or side[3] == 270) and UDim2.fromScale(0.18, 1) or UDim2.fromScale(1, 0.18)
		edge.BorderSizePixel = 0
		edge.BackgroundColor3 = colors.DeepBlue
		edge.BackgroundTransparency = 1
		edge.Parent = holder
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = side[3]
		gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		gradient.Parent = edge
	end
	vignette = holder
	-- Drive the edge frames from the holder's ImageTransparency.
	holder:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
		for _, edge in ipairs(holder:GetChildren()) do
			if edge:IsA("Frame") then
				edge.BackgroundTransparency = holder.ImageTransparency
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Sneak Attack choreography
---------------------------------------------------------------------------
local function groundCrack(position, color, radius)
	TuskVFX.CreateRotationalShockwave(CFrame.new(position), { Radius = radius, Layers = 2, Color = color, Color2 = colors.DeepBlue, Ground = true, Particles = 0.6, Width = 0.3 })
	VFXLib.burst(position, {
		Count = 8,
		Texture = VFXLib.Textures.Smoke,
		Color = Color3.fromRGB(180, 160, 120),
		LightEmission = 0,
		Speed = 5,
		Lifetime = 0.9,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3) }),
		TransparencySeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
	})
end

-- Moving underground indicator: a ripple ring travelling under the ground.
local function undergroundTrail(from, target, duration)
	local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
	if not targetRoot or not VFXLib.acquire() then
		return
	end
	local ring = VFXLib.ring({ Radius = 1.4, Width = 0.25, Color = colors.Cyan, Segments = 14, Transparency = 0.2 })
	local nextPuff = 0
	VFXLib.animate(duration, function(a)
		local to = targetRoot.Parent and (targetRoot.Position - Vector3.new(0, 2.8, 0)) or from
		local pos = from:Lerp(to, VFXLib.easeInOut(a))
		ring:SetCFrame(CFrame.new(pos + Vector3.new(0, 0.1, 0)))
		ring:SetRadius(1.2 + math.sin(a * 30) * 0.25)
		if os.clock() > nextPuff then
			nextPuff = os.clock() + 0.07
			VFXLib.burst(pos, { Count = 3, Color = colors.Cyan, Speed = 6, Spread = 25, Direction = Vector3.new(0, 1, 0), Lifetime = 0.4 })
		end
	end, function()
		ring:Destroy()
		VFXLib.release()
	end)
end

local function onSneakAttack(data)
	local character = data.Character
	if data.Phase == "Burrow" then
		local burrow = TuskConfig.Sneak.Attack.BurrowTime
		groundCrack(data.Position, colors.Cyan, 5)
		VFXLib.sound(sounds.Burrow, data.Position, 0.7, 1)
		undergroundTrail(data.Position, data.Target, burrow)
	elseif data.Phase == "Warning" then
		-- Clear warning under the target: pulsing ring, distortion, alarm sound.
		local target = data.Target
		local isTarget = target == localPlayer.Character
		local wormhole = TuskVFX.CreateWormhole(CFrame.new(data.Position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(-math.pi / 2, 0, 0), {
			Radius = 2.2,
			Color = colors.Cyan,
			Color2 = colors.DeepBlue,
			OpenTime = 0.15,
			Duration = data.Duration,
			CloseTime = 0.1,
		})
		TuskVFX.CreateSpinRing({ CFrame = CFrame.new(data.Position + Vector3.new(0, 0.15, 0)), Radius = 3.5, Width = 0.35, Color = Color3.fromRGB(255, 80, 80), RotationSpeed = 6, Duration = data.Duration + 0.1 })
		VFXLib.sound(sounds.Warning, data.Position, isTarget and 0.9 or 0.5, 1)
		if isTarget then
			CameraFX.shake(0.25, data.Duration)
		end
		task.delay(data.Duration + 0.3, function()
			TuskVFX.CleanupEffect(wormhole)
		end)
	elseif data.Phase == "Emerge" then
		if character then
			TuskAnimation.play(character, "Emerge")
			TuskStand.action(character, "Emerge", { Duration = 0.35 })
		end
		VFXLib.burst(data.Position, { Count = 24, Color = colors.Ice, Speed = 30, Spread = 30, Direction = Vector3.new(0, 1, 0), Lifetime = 0.5 })
		VFXLib.sound(sounds.Emerge, data.Position, 0.8, 1)
		groundCrack(data.Position, colors.Ice, 4)
	elseif data.Phase == "Shockwave" then
		TuskVFX.CreateRotationalShockwave(CFrame.new(data.Position), { Radius = 12, Layers = 3, Color = colors.Cyan, Color2 = colors.Blue, Ground = true, Particles = 1.5, Width = 0.6 })
		TuskVFX.CreateDistortion(data.Position + Vector3.new(0, 2, 0), { Radius = 5 })
		CameraFX.shakeAt(data.Position, 0.8, 60)
		if data.Hit and character == localPlayer.Character then
			CameraFX.impactFrame(colors.Ice)
			CameraFX.speedLines(0.3, colors.Ice)
		end
	end
end

function TuskSneakController.handle(name, data)
	if name == "SneakAttack" then
		onSneakAttack(data)
	end
end

function TuskSneakController.init()
	buildVignette()
	local localSneaking = false
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local seenSneak, seenHidden = {}, {}
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character then
				if character:GetAttribute("TuskSneaking") then
					seenSneak[character] = true
					local fx = sneakers[character]
					if not fx then
						fx = startSneakFX(character)
						sneakers[character] = fx or {}
					end
					-- Subtle ground ripple every so often.
					if fx and fx.Attachment and now >= fx.NextRipple then
						fx.NextRipple = now + 0.8
						VFXLib.shockwave(CFrame.new(fx.Attachment.WorldPosition), { StartRadius = 0.8, Radius = 3, Width = 0.12, Duration = 0.6, Color = colors.Cyan })
					end
				end
				if character:GetAttribute("TuskBurrowed") then
					seenHidden[character] = true
					if not hidden[character] then
						hidden[character] = true
						setHidden(character, true)
					end
				end
			end
		end
		for character, fx in pairs(sneakers) do
			if not seenSneak[character] then
				sneakers[character] = nil
				stopSneakFX(character, fx)
			end
		end
		for character in pairs(hidden) do
			if not seenHidden[character] then
				hidden[character] = nil
				if character.Parent then
					setHidden(character, false)
				end
			end
		end
		local mine = localPlayer.Character and localPlayer.Character:GetAttribute("TuskSneaking") == true
		if mine ~= localSneaking then
			localSneaking = mine
			setLocalSneak(mine)
		end
	end)
end

return TuskSneakController
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/TuskStand", Class = "ModuleScript", Source = [=[
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
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local TuskStandModels = require(Shared.TuskStandModels)
local VFXLib = require(script.Parent.VFXLib)

local TuskStand = {}

local IDLE_OFFSET = CFrame.new(1.9, 1.5, 1.7)
local SNEAK_OFFSET = CFrame.new(1.5, -1.4, 1.2)

local stands = {} -- [character] = stand

local function setVisible(stand, visible)
	if stand.Visible == visible then
		return
	end
	stand.Visible = visible
	for part, original in pairs(stand.Transparency) do
		part.Transparency = visible and original or 1
	end
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
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = TuskConfig.Colors.Cyan
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
	model.Parent = VFXLib.Folder
	local root = character:FindFirstChild("HumanoidRootPart")
	local start = root and root.CFrame * IDLE_OFFSET or CFrame.new()
	model:PivotTo(start)
	return {
		Act = act,
		Character = character,
		Model = model,
		Rig = rig,
		Highlight = highlight,
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
	stand.Highlight.OutlineTransparency = awakened and 0.1 or (stand.Action and stand.Action.Kind == "Manifest" and stand.Highlight.OutlineTransparency or 1)

	local velocity = root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local localVel = root.CFrame:VectorToObjectSpace(flat)
	local lean = math.clamp(-localVel.Z / 40, -0.4, 0.4) -- lean forward when running

	local bob = math.sin(t * 2.2) * (sneaking and 0.08 or 0.22)
	local offset = (sneaking and SNEAK_OFFSET or IDLE_OFFSET) * CFrame.new(0, bob, 0)
	local desired = root.CFrame * offset * CFrame.Angles(-lean, math.sin(t * 0.9) * 0.12, math.sin(t * 1.3) * 0.08)
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
	if joints.EarL then
		local flap = math.sin(t * 3.1) * 0.18 + lean * 0.5
		joints.EarL.Weld.C0 = joints.EarL.Base * CFrame.Angles(0, 0, flap) * joints.EarL.Offset
		joints.EarR.Weld.C0 = joints.EarR.Base * CFrame.Angles(0, 0, -flap) * joints.EarR.Offset
	end
	for i = 1, 4 do
		local leg = joints["Leg" .. i]
		if leg then
			local swing = math.sin(t * 3.6 + i * 1.3) * 0.28 + lean * 1.2
			leg.Weld.C0 = leg.Base * CFrame.Angles(swing, 0, math.sin(t * 2 + i) * 0.1) * leg.Offset
		end
	end
end

function TuskStand.init()
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local seen = {}
		for _, player in ipairs(Players:GetPlayers()) do
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
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/TuskVFX", Class = "ModuleScript", Source = [=[
--[[
	TuskVFX  (StarterPlayerScripts.SpinClient.TuskVFX)

	Reusable procedural VFX framework for every Tusk Act (built on VFXLib).
	Every function takes an options table; common options:
	  Duration, Radius/Size, Color, Color2, RotationSpeed (rad/s),
	  Particles (count multiplier), Transparency, Width
	Quality comes from VFXQuality automatically (segments, particles,
	optional layers). Every effect returns a handle with :Destroy() and
	cleans itself up when its Duration ends.

	  CreateSpinRing(opts)                 rotating energy ring (follows a target)
	  CreateMagicCircle(cframe, opts)      layered rings + star polygon
	  CreateEnergyCharge(opts)             growing core, accelerating rings, inward particles
	  CreateNailProjectile(opts)           nail + helix energy trails + optional rings
	  CreateRotationalShockwave(cf, opts)  layered spinning rings, ground disc, particles
	  CreateWormhole(cframe, opts)         opening, concentric rings, distorted interior, collapse
	  CreateGoldenAura(character, opts)    outline, orbiting rings, rising particles
	  CreateDistortion(position, opts)     refractive heat-haze sphere (High quality)
	  CreateImpact(position, normal, opts) staged impact: flash, shockwave, sparks, dust
	  CreateTuskTransformation(character, opts)  cinematic Act transformation
	  CleanupEffect(handle)
]]

local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local VFXQuality = require(Shared.VFXQuality)
local NailModel = require(Shared.NailModel)
local VFXLib = require(script.Parent.VFXLib)

local TuskVFX = {}
local colors = TuskConfig.Colors
local LONG = 1e6 -- "until destroyed"

local function q()
	return VFXQuality.get()
end

function TuskVFX.CleanupEffect(handle)
	if handle and handle.Destroy then
		pcall(handle.Destroy, handle)
	end
end

local function fadeAlpha(a, fadeIn, fadeOut)
	if a < fadeIn then
		return 1 - a / fadeIn
	elseif a > 1 - fadeOut then
		return (a - (1 - fadeOut)) / fadeOut
	end
	return 0
end

---------------------------------------------------------------------------
-- Spin ring
---------------------------------------------------------------------------
function TuskVFX.CreateSpinRing(opts)
	local ring = VFXLib.ring({
		CFrame = opts.CFrame or CFrame.new(),
		Radius = opts.Radius or 2,
		Width = opts.Width or 0.15,
		Color = opts.Color or colors.Cyan,
		Transparency = 1,
		Segments = opts.Segments,
	})
	local handle = { Ring = ring, Angle = opts.StartAngle or 0, Speed = opts.RotationSpeed or 4, Alive = true }
	local baseT = opts.Transparency or 0.1
	local duration = opts.Duration
	handle.Job = VFXLib.animate(duration or LONG, function(a, dt)
		handle.Angle = handle.Angle + handle.Speed * (dt or 0)
		local base = opts.Follow and opts.Follow() or opts.CFrame
		if base then
			ring:SetCFrame(base * (opts.Tilt or CFrame.new()) * CFrame.Angles(0, handle.Angle, 0))
		end
		local fade = duration and fadeAlpha(a, 0.12, 0.3) or math.max(0, 1 - (a * LONG) / 0.15)
		ring:SetTransparency(baseT + (1 - baseT) * fade)
	end, function()
		handle.Alive = false
		ring:Destroy()
	end)
	function handle:SetRadius(r)
		ring:SetRadius(r)
	end
	function handle:SetColor(c)
		ring:SetColor(c)
	end
	function handle:SetWidth(w)
		ring:SetWidth(w)
	end
	function handle:Destroy()
		VFXLib.cancel(self.Job)
	end
	return handle
end

---------------------------------------------------------------------------
-- Magic circle: outer ring, inner ring and a star polygon of beams
---------------------------------------------------------------------------
function TuskVFX.CreateMagicCircle(cframe, opts)
	opts = opts or {}
	local radius = opts.Radius or 6
	local color = opts.Color or colors.Cyan
	local duration = opts.Duration or 2
	local points = opts.Points or 6
	local carrier = VFXLib.anchor(cframe)
	local attachments = {}
	for i = 1, points do
		local a = Instance.new("Attachment")
		a.Parent = carrier
		attachments[i] = a
	end
	local beams = {}
	local skip = points == 6 and 2 or 2
	for i = 1, points do
		local b = Instance.new("Beam")
		b.Attachment0 = attachments[i]
		b.Attachment1 = attachments[(i - 1 + skip) % points + 1]
		b.Color = ColorSequence.new(opts.Color2 or color)
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Width0 = opts.Width or 0.18
		b.Width1 = opts.Width or 0.18
		b.FaceCamera = true
		b.Segments = 1
		b.Parent = carrier
		beams[i] = b
	end
	local outer = TuskVFX.CreateSpinRing({ CFrame = cframe, Radius = radius, Width = 0.25, Color = color, RotationSpeed = opts.RotationSpeed or 1, Duration = duration })
	local inner = TuskVFX.CreateSpinRing({ CFrame = cframe, Radius = radius * 0.72, Width = 0.15, Color = opts.Color2 or color, RotationSpeed = -(opts.RotationSpeed or 1) * 1.6, Duration = duration })
	local handle = { Outer = outer, Inner = inner }
	local angle = 0
	handle.Job = VFXLib.animate(duration, function(a, dt)
		angle = angle + (opts.RotationSpeed or 1) * 0.7 * (dt or 0)
		local open = VFXLib.easeOut(math.min(a / 0.2, 1))
		local r = radius * 0.7 * open
		for i, att in ipairs(attachments) do
			local th = angle + (i - 1) / points * math.pi * 2
			att.Position = Vector3.new(math.cos(th) * r, 0.02, math.sin(th) * r)
		end
		outer:SetRadius(radius * open)
		inner:SetRadius(radius * 0.72 * open)
		local fade = fadeAlpha(a, 0.1, 0.25)
		local seq = NumberSequence.new(0.1 + 0.9 * fade)
		for _, b in ipairs(beams) do
			b.Transparency = seq
		end
	end, function()
		carrier:Destroy()
	end)
	function handle:Destroy()
		VFXLib.cancel(self.Job)
		outer:Destroy()
		inner:Destroy()
	end
	return handle
end

---------------------------------------------------------------------------
-- Energy charge: core sphere + accelerating rings + particles pulled inward
---------------------------------------------------------------------------
function TuskVFX.CreateEnergyCharge(opts)
	local color = opts.Color or colors.Cyan
	local color2 = opts.Color2 or colors.Ice
	local maxRadius = opts.MaxRadius or 1.4
	local ringCount = math.min(opts.Rings or 3, 3)
	local follow = opts.Follow
	local handle = { Progress = 0, Rings = {} }

	local core = VFXLib.part({ Shape = Enum.PartType.Ball, Color = color2, Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 0.15 })
	local light
	if q().Lights then
		light = Instance.new("PointLight")
		light.Color = color
		light.Range = 8
		light.Brightness = 0
		light.Shadows = false
		light.Parent = core
	end

	-- Shell emitter: particles spawn on a sphere surface and fly inward.
	local shell = VFXLib.part({ Shape = Enum.PartType.Ball, Transparency = 1, Size = Vector3.new(maxRadius * 3, maxRadius * 3, maxRadius * 3) })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Sparkle
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Color = ColorSequence.new(color2, color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0), NumberSequenceKeypoint.new(1, 0.4) })
	emitter.Lifetime = NumberRange.new(0.35, 0.45)
	emitter.Speed = NumberRange.new(maxRadius * 3.2, maxRadius * 3.6)
	emitter.Rate = 0
	emitter.Parent = shell

	for i = 1, ringCount do
		handle.Rings[i] = TuskVFX.CreateSpinRing({
			Follow = function()
				return core.CFrame
			end,
			Tilt = CFrame.Angles(0.6 * i, 0, 0.9 * i),
			Radius = 0.1,
			Width = 0.08,
			Color = i == 1 and color2 or color,
			RotationSpeed = 3 + i * 1.5,
			Transparency = 0.15,
		})
	end

	local duration = opts.Duration or 1.2
	local manual = opts.Manual == true
	handle.Job = VFXLib.animate(LONG, function(a, dt)
		local cf = follow and follow() or opts.CFrame
		if not cf then
			return
		end
		local elapsed = a * LONG
		if not manual then
			handle.Progress = math.min(elapsed / duration, 1)
		end
		local p = handle.Progress
		local pulse = 1 + math.sin(elapsed * 18) * 0.06 * p
		local coreSize = (0.25 + p * maxRadius * 0.6) * pulse
		core.CFrame = cf
		core.Size = Vector3.new(coreSize, coreSize, coreSize)
		shell.CFrame = cf
		emitter.Rate = (10 + p * 50) * q().Particles * (opts.Particles or 1)
		if light then
			light.Brightness = 1 + p * 3
		end
		for i, ring in ipairs(handle.Rings) do
			ring.Speed = (3 + i * 1.5) * (1 + p * 3) -- rings accelerate as energy builds
			ring:SetRadius(0.3 + p * maxRadius * (0.55 + i * 0.22))
		end
		if handle.OnStep then
			handle.OnStep(p, cf)
		end
	end, function()
		core:Destroy()
		shell:Destroy()
		for _, ring in ipairs(handle.Rings) do
			ring:Destroy()
		end
	end)

	function handle:SetProgress(p)
		self.Progress = math.clamp(p, 0, 1)
	end
	function handle:Destroy()
		VFXLib.cancel(self.Job)
	end
	-- Bright flash + outward burst, then cleanup.
	function handle:Release(direction)
		local pos = core.Position
		VFXLib.burst(pos, { Count = 20, Color = color2, Speed = 22, Lifetime = 0.35, Direction = direction, Spread = direction and 35 or 180 })
		VFXLib.flash(pos, color, 6, 14, 0.25)
		local flash = VFXLib.part({ Shape = Enum.PartType.Ball, Color = colors.Ice, Size = core.Size, CFrame = core.CFrame, Transparency = 0 })
		local s0 = core.Size.X
		VFXLib.animate(0.15, function(a)
			local s = s0 * (1 + a * 2.5)
			flash.Size = Vector3.new(s, s, s)
			flash.Transparency = a
		end, function()
			flash:Destroy()
		end)
		self:Destroy()
	end
	return handle
end

---------------------------------------------------------------------------
-- Nail projectile visual (pooled nails)
---------------------------------------------------------------------------
local nailPool = {}

local function takeNail(scale)
	local nail = table.remove(nailPool)
	if not nail then
		nail = NailModel.build(1.3)
		nail.PrimaryPart.Anchored = true
	end
	nail:ScaleTo(scale)
	return nail
end

local function returnNail(nail)
	nail.Parent = nil
	if #nailPool < 16 then
		table.insert(nailPool, nail)
	else
		nail:Destroy()
	end
end

local function trailBetween(parent, a0, a1, color, color2, lifetime, transparency)
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = ColorSequence.new(color, color2 or color)
	t.LightEmission = 1
	t.LightInfluence = 0
	t.Lifetime = lifetime
	t.FaceCamera = true
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, transparency or 0), NumberSequenceKeypoint.new(1, 1) })
	t.WidthScale = NumberSequence.new(1, 0.2)
	t.Parent = parent
	return t
end

--[[
	opts: Scale, Color, Color2 (helix), TrailColor, Rings (0..3), RingColor,
	      HelixRadius, Helix (strand count), Afterimages, SpinSpeed
	visual:Step(cframe, dt)  visual:Destroy()
]]
function TuskVFX.CreateNailProjectile(opts)
	local scale = opts.Scale or 1
	local nail = takeNail(scale)
	nail.Parent = VFXLib.Folder

	-- Carrier rotates around the flight axis; attachments on it draw helix trails.
	local carrier = VFXLib.anchor(CFrame.new())
	local trails = {}
	local helixRadius = (opts.HelixRadius or 0.35) * scale
	local strands = opts.Helix or 2
	for i = 1, strands do
		local th = (i - 1) / strands * math.pi * 2
		local dir = Vector3.new(math.cos(th), math.sin(th), 0)
		local a0 = Instance.new("Attachment")
		a0.Position = dir * helixRadius
		a0.Parent = carrier
		local a1 = Instance.new("Attachment")
		a1.Position = dir * (helixRadius + 0.08 * scale)
		a1.Parent = carrier
		table.insert(trails, trailBetween(carrier, a0, a1, opts.Color2 or colors.Cyan, opts.Color or colors.Blue, 0.22, 0.05))
	end
	-- Thin core trail straight behind the nail.
	local c0 = Instance.new("Attachment")
	c0.Position = Vector3.new(0, 0.05 * scale, 0)
	c0.Parent = carrier
	local c1 = Instance.new("Attachment")
	c1.Position = Vector3.new(0, -0.05 * scale, 0)
	c1.Parent = carrier
	table.insert(trails, trailBetween(carrier, c0, c1, opts.TrailColor or colors.Blue, colors.DeepBlue, 0.35 * (opts.TrailLength or 1), 0))

	local rings = {}
	for i = 1, (opts.Rings or 0) do
		rings[i] = VFXLib.ring({ Radius = (0.35 + i * 0.22) * scale, Width = 0.08 * scale, Color = opts.RingColor or colors.Cyan, Transparency = 0.1 })
	end

	local visual = { Spin = 0, NextGhost = 0, Alive = true }
	function visual:Step(cframe, dt)
		self.Spin = self.Spin + (dt or 0) * (opts.SpinSpeed or 30)
		nail:PivotTo(cframe * CFrame.Angles(0, 0, self.Spin))
		carrier.CFrame = cframe * CFrame.new(0, 0, 0.5 * scale) * CFrame.Angles(0, 0, self.Spin * 0.5)
		for i, ring in ipairs(rings) do
			local tilt = 0.4 * i
			ring:SetCFrame(cframe * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.Angles(tilt * math.sin(self.Spin * 0.2 + i), self.Spin * (0.3 + i * 0.15), tilt))
		end
		if opts.Afterimages and q().Afterimages and os.clock() >= self.NextGhost then
			self.NextGhost = os.clock() + 0.045
			VFXLib.afterimage(cframe, 0.35 * scale, opts.RingColor or colors.Cyan)
		end
	end
	function visual:Destroy()
		if not self.Alive then
			return
		end
		self.Alive = false
		returnNail(nail)
		for _, ring in ipairs(rings) do
			ring:Destroy()
		end
		for _, t in ipairs(trails) do
			t.Enabled = false
		end
		Debris:AddItem(carrier, 0.5)
	end
	return visual
end

---------------------------------------------------------------------------
-- Rotational shockwave
---------------------------------------------------------------------------
--[[ cf: UpVector = shockwave axis. opts: Radius, Color, Color2, Layers,
     Duration, Spin, Ground (disc), Particles, Width ]]
function TuskVFX.CreateRotationalShockwave(cf, opts)
	opts = opts or {}
	local layers = opts.Layers or 2
	if q().RingSegments <= 12 then
		layers = math.min(layers, 2)
	end
	local radius = opts.Radius or 8
	for i = 1, layers do
		task.delay((i - 1) * (opts.Stagger or 0.045), function()
			VFXLib.shockwave(cf * CFrame.Angles(0, i * 0.7, 0), {
				StartRadius = radius * 0.1,
				Radius = radius * (1 - (i - 1) * 0.22),
				Width = (opts.Width or 0.5) * (1 - (i - 1) * 0.2),
				Duration = (opts.Duration or 0.45) + i * 0.05,
				Color = (i % 2 == 1) and (opts.Color or colors.Cyan) or (opts.Color2 or colors.Blue),
				Spin = (opts.Spin or 2) * (i % 2 == 1 and 1 or -1),
			})
		end)
	end
	if opts.Ground then
		VFXLib.groundDisc(cf.Position, cf.UpVector, { Radius = radius * 0.6, Color = opts.Color2 or opts.Color or colors.Cyan, Duration = opts.Duration or 0.4 })
	end
	if (opts.Particles or 1) > 0 then
		VFXLib.burst(cf.Position, {
			Count = 16 * (opts.Particles or 1),
			Color = opts.Color or colors.Cyan,
			Speed = radius * 3,
			Lifetime = 0.45,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }),
		})
	end
end

---------------------------------------------------------------------------
-- Distortion (refraction haze). Glass refracts on higher graphics levels.
---------------------------------------------------------------------------
function TuskVFX.CreateDistortion(position, opts)
	opts = opts or {}
	if not q().ImpactFrames or not VFXLib.acquire() then
		return
	end
	local radius = opts.Radius or 4
	local sphere = VFXLib.part({
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Glass,
		Color = opts.Color or colors.Ice,
		Transparency = 0.6,
		Size = Vector3.new(0.5, 0.5, 0.5),
		CFrame = CFrame.new(position),
	})
	VFXLib.animate(opts.Duration or 0.35, function(a)
		local d = 0.5 + radius * 2 * VFXLib.easeOut(a)
		sphere.Size = Vector3.new(d, d, d)
		sphere.Transparency = 0.6 + 0.4 * a
	end, function()
		sphere:Destroy()
		VFXLib.release()
	end)
end

---------------------------------------------------------------------------
-- Staged impact: flash -> primary shockwave -> sparks -> dust (recovery)
---------------------------------------------------------------------------
function TuskVFX.CreateImpact(position, normal, opts)
	opts = opts or {}
	normal = normal or Vector3.new(0, 1, 0)
	local color = opts.Color or colors.Cyan
	local size = opts.Size or 1
	-- 1. impact flash
	local flash = VFXLib.part({ Shape = Enum.PartType.Ball, Color = colors.Ice, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(position) })
	VFXLib.animate(0.12, function(a)
		local d = 0.5 + 3 * size * a
		flash.Size = Vector3.new(d, d, d)
		flash.Transparency = a
	end, function()
		flash:Destroy()
	end)
	VFXLib.flash(position, color, 3 + size * 2, 10 + size * 6, 0.3)
	-- 2. primary shockwave around the surface normal
	local axis = CFrame.lookAt(position, position + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
	TuskVFX.CreateRotationalShockwave(axis, {
		Radius = (opts.Radius or 4) * size,
		Layers = opts.Layers or 2,
		Color = color,
		Color2 = opts.Color2 or colors.Blue,
		Ground = normal.Y > 0.6 and opts.Ground ~= false,
		Particles = 0,
		Width = 0.3 * size,
	})
	-- 3. secondary sparks
	VFXLib.burst(position, {
		Count = math.floor(12 * size),
		Color = opts.Color2 or colors.Ice,
		Speed = 30 * size,
		Lifetime = 0.4,
		Drag = 2,
		Acceleration = Vector3.new(0, -40, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) }),
		Direction = normal,
		Spread = 70,
	})
	-- 4. recovery dust
	if normal.Y > 0.6 then
		VFXLib.burst(position, {
			Count = math.floor(4 * size),
			Texture = VFXLib.Textures.Smoke,
			Color = Color3.fromRGB(196, 170, 125),
			LightEmission = 0,
			Speed = 6,
			Lifetime = 1,
			Drag = 3,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5 * size), NumberSequenceKeypoint.new(1, 4 * size) }),
			TransparencySeq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		})
	end
	if opts.Sound then
		VFXLib.sound(opts.Sound, position, 0.6, opts.Pitch or 1)
	end
end

---------------------------------------------------------------------------
-- Wormhole portal
---------------------------------------------------------------------------
--[[ cframe: portal faces cframe.LookVector. opts: Radius, Color, Color2,
     Duration (hold time), OpenTime, CloseTime.  handle:Close() ]]
function TuskVFX.CreateWormhole(cframe, opts)
	opts = opts or {}
	local radius = opts.Radius or 3
	local color = opts.Color or colors.Cyan
	local color2 = opts.Color2 or colors.DeepBlue
	local openTime = opts.OpenTime or 0.25
	local closeTime = opts.CloseTime or 0.22
	-- Ring axis must be the portal facing: rotate so the ring's Up = LookVector.
	local axis = cframe * CFrame.Angles(math.pi / 2, 0, 0)

	local handle = { Scale = 0, Closing = false }
	local rings = {}
	local ringDefs = { { 1, 3, 0.22 }, { 0.82, -4.5, 0.14 }, { 0.62, 6, 0.1 } }
	for i, def in ipairs(ringDefs) do
		if i < 3 or q().RingSegments > 12 then
			rings[i] = TuskVFX.CreateSpinRing({ CFrame = axis, Radius = 0.1, Width = def[3], Color = i == 1 and color or colors.Ice, RotationSpeed = def[2], Transparency = 0.05 })
		end
	end
	-- Distorted interior: ForceField material shimmers; dark core gives depth.
	local interior = VFXLib.part({
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.ForceField,
		Color = color,
		Transparency = 0,
		Size = Vector3.new(0.05, 0.1, 0.1),
	})
	local core = VFXLib.part({
		Shape = Enum.PartType.Cylinder,
		Color = color2,
		Transparency = 0.15,
		Size = Vector3.new(0.04, 0.1, 0.1),
	})
	-- Cylinder axis is X; turn it to face the portal direction.
	local discCF = cframe * CFrame.Angles(0, math.pi / 2, 0)
	interior.CFrame = discCF
	core.CFrame = discCF * CFrame.new(0.05, 0, 0)

	-- Particles pulled inward from the rim.
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Sparkle
	emitter.Shape = Enum.ParticleEmitterShape.Cylinder
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.Color = ColorSequence.new(colors.Ice, color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.3, 0.4)
	emitter.Speed = NumberRange.new(radius * 2.5, radius * 3)
	emitter.Rate = 30 * q().Particles
	emitter.Parent = interior

	local light
	if q().Lights then
		light = Instance.new("PointLight")
		light.Color = color
		light.Range = radius * 4
		light.Brightness = 3
		light.Shadows = false
		light.Parent = core
	end

	local function apply(s)
		for i, def in ipairs(ringDefs) do
			if rings[i] then
				rings[i]:SetRadius(math.max(radius * def[1] * s, 0.05))
			end
		end
		local d = math.max(radius * 1.8 * s, 0.1)
		interior.Size = Vector3.new(0.05, d, d)
		core.Size = Vector3.new(0.04, d * 0.75, d * 0.75)
	end
	apply(0)

	handle.Job = VFXLib.animate(LONG, function(a)
		local t = a * LONG
		if not handle.Closing then
			-- Overshoot ease on open, gentle breathing while held.
			local o = math.min(t / openTime, 1)
			local s = o < 1 and (1 - (1 - o) ^ 3) * (1 + 0.15 * math.sin(o * math.pi)) or 1 + math.sin(t * 6) * 0.03
			apply(s)
		end
	end, function()
		for _, ring in pairs(rings) do
			ring:Destroy()
		end
		interior:Destroy()
		core:Destroy()
	end)

	function handle:Close()
		if self.Closing then
			return
		end
		self.Closing = true
		emitter.Rate = 0
		local pos = cframe.Position
		VFXLib.animate(closeTime, function(a)
			apply(1 - VFXLib.easeInOut(a))
			if light then
				light.Brightness = 3 + a * 4
			end
		end, function()
			VFXLib.burst(pos, { Count = 14, Color = colors.Ice, Speed = 14, Lifetime = 0.3 })
			VFXLib.cancel(self.Job)
		end)
	end
	function handle:Destroy()
		VFXLib.cancel(self.Job)
	end
	if opts.Duration then
		task.delay(openTime + opts.Duration, function()
			handle:Close()
		end)
	end
	return handle
end

---------------------------------------------------------------------------
-- Aura (gold for Act 4; cyan/blue for Act 1 Awakened)
---------------------------------------------------------------------------
function TuskVFX.CreateGoldenAura(character, opts)
	opts = opts or {}
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return { Destroy = function() end }
	end
	local color = opts.Color or colors.Gold
	local color2 = opts.Color2 or colors.DeepBlue
	local handle = { Rings = {} }

	local highlight = Instance.new("Highlight")
	highlight.Adornee = character
	highlight.FillColor = color
	highlight.FillTransparency = 0.85
	highlight.OutlineColor = color
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = VFXLib.Folder

	local attachment = Instance.new("Attachment")
	attachment.Name = "TuskAura"
	attachment.Position = Vector3.new(0, -1, 0)
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Sparkle
	emitter.Color = ColorSequence.new(color, color2)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Acceleration = Vector3.new(0, 4, 0)
	emitter.Rate = 18 * q().Particles * (opts.Particles or 1)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = attachment

	for i = 1, (opts.Rings or 2) do
		handle.Rings[i] = TuskVFX.CreateSpinRing({
			Follow = function()
				return root.Parent and root.CFrame * CFrame.new(0, -2.6 + i * 1.2, 0) or nil
			end,
			Tilt = CFrame.Angles(0.25 * (i % 2 == 0 and 1 or -1), 0, 0.15),
			Radius = 2.4 - i * 0.3,
			Width = 0.12,
			Color = i % 2 == 1 and color or color2,
			RotationSpeed = (2.5 + i) * (i % 2 == 0 and -1 or 1),
			Transparency = 0.25,
		})
	end
	function handle:Destroy()
		highlight:Destroy()
		attachment:Destroy()
		for _, ring in ipairs(self.Rings) do
			ring:Destroy()
		end
	end
	return handle
end

---------------------------------------------------------------------------
-- Cinematic transformation (used by Act ultimates)
---------------------------------------------------------------------------
--[[ opts: Duration, Color, Color2, OnManifest() called at ~55%,
     OnBurst() called at the end. ]]
function TuskVFX.CreateTuskTransformation(character, opts)
	opts = opts or {}
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local duration = opts.Duration or 1.7
	local color = opts.Color or colors.Cyan
	local color2 = opts.Color2 or colors.Blue
	local groundCF = CFrame.new(root.Position - Vector3.new(0, 2.9, 0))

	-- Stage 1: layered magic circles open at the feet.
	TuskVFX.CreateMagicCircle(groundCF, { Radius = 7, Color = color, Color2 = colors.Ice, Duration = duration + 0.4, RotationSpeed = 1.2, Points = 6 })
	if q().RingSegments > 12 then
		TuskVFX.CreateMagicCircle(groundCF * CFrame.new(0, 0.05, 0), { Radius = 4.2, Color = color2, Duration = duration + 0.4, RotationSpeed = -2, Points = 5 })
	end

	-- Stage 2: rising energy column.
	local column = VFXLib.part({ Shape = Enum.PartType.Cylinder, Transparency = 1, Size = Vector3.new(0.1, 6, 6), CFrame = groundCF * CFrame.Angles(0, 0, math.pi / 2) })
	local rise = Instance.new("ParticleEmitter")
	rise.Texture = VFXLib.Textures.Sparkle
	rise.Shape = Enum.ParticleEmitterShape.Disc
	rise.Color = ColorSequence.new(colors.Ice, color)
	rise.LightEmission = 1
	rise.LightInfluence = 0
	rise.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	rise.Lifetime = NumberRange.new(0.6, 1)
	rise.Speed = NumberRange.new(8, 14)
	rise.EmissionDirection = Enum.NormalId.Right -- cylinder X axis = world up here
	rise.Rate = 40 * q().Particles
	rise.Parent = column
	Debris:AddItem(column, duration + 1.2)

	-- Stage 3: energy gathers at the chest.
	local charge = TuskVFX.CreateEnergyCharge({
		Follow = function()
			return root.Parent and root.CFrame * CFrame.new(0, 1, -1.2) or nil
		end,
		Color = color,
		Color2 = colors.Ice,
		MaxRadius = 1.6,
		Duration = duration * 0.9,
		Rings = 3,
	})

	task.delay(duration * 0.55, function()
		if opts.OnManifest then
			opts.OnManifest()
		end
	end)
	task.delay(duration, function()
		rise.Rate = 0
		charge:Release()
		-- Stage 4: burst
		TuskVFX.CreateRotationalShockwave(groundCF, { Radius = 20, Layers = 3, Color = color, Color2 = colors.Ice, Ground = true, Particles = 2, Width = 0.8, Duration = 0.6 })
		TuskVFX.CreateDistortion(root.Position, { Radius = 8, Duration = 0.4 })
		VFXLib.burst(root.Position, { Count = 40, Color = colors.Ice, Speed = 50, Lifetime = 0.6 })
		VFXLib.flash(root.Position, color, 10, 40, 0.5)
		if opts.OnBurst then
			opts.OnBurst()
		end
	end)
end

return TuskVFX
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/UI", Class = "Folder", Source = nil },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/UI/SpinMeter", Class = "ModuleScript", Source = [=[
--[[
	SpinMeter  (StarterPlayerScripts.SpinClient.UI.SpinMeter)

	Golden Spin HUD:
	  * charge bar with Power tick, gold PERFECT zone and overcharge zone
	  * live level name ("QUICK SPIN" / "POWER SPIN" / "PERFECT SPIN")
	  * cooldown bar + key hint (R / RT / hidden on touch)
	  * centre-screen popup on release ("PERFECT SPIN!")
	  * VFX quality toggle (top right)
	Built in code so it can be dropped into any place. Later phases will
	merge this into the full ability-slot HUD.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local SpinConfig = require(Shared.SpinConfig)
local VFXQuality = require(Shared.VFXQuality)
local VFXLib = require(script.Parent.Parent.VFXLib)

local SpinMeter = {}

local colors = SpinConfig.Colors
local charge = SpinConfig.Charge
local MAX_T = charge.PerfectWindowStart + charge.PerfectWindowDuration + 0.6
local DARK = Color3.fromRGB(22, 16, 10)
local FONT = Enum.Font.GothamBlack

local gui, chargeFrame, fill, levelLabel, cooldownFill, cooldownLabel, keyHint, popupLabel, popupScale
local cooldownJob, popupJob, chargeFadeJob

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = colors.GoldLight
	l.TextStrokeTransparency = 0.4
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function keyText()
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return ""
	end
	if string.find(last.Name, "Gamepad") then
		return "RT"
	end
	return SpinConfig.Input.Keyboard.Name
end

function SpinMeter.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = Instance.new("ScreenGui")
	gui.Name = "SpinHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Bottom-centre panel.
	local panel = Instance.new("Frame")
	panel.Name = "SpinPanel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -24)
	panel.Size = UDim2.fromOffset(320, 58)
	panel.BackgroundTransparency = 1
	panel.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(320, 58)
	sizeLimit.Parent = panel

	-- Charge bar (hidden until charging).
	chargeFrame = Instance.new("Frame")
	chargeFrame.Name = "Charge"
	chargeFrame.Size = UDim2.new(1, 0, 0, 16)
	chargeFrame.BackgroundColor3 = DARK
	chargeFrame.BackgroundTransparency = 0.15
	chargeFrame.Visible = false
	chargeFrame.Parent = panel
	corner(chargeFrame, 8)
	stroke(chargeFrame, colors.Gold, 2)

	local function zone(name, from, to, color, transparency)
		local z = Instance.new("Frame")
		z.Name = name
		z.BorderSizePixel = 0
		z.Position = UDim2.fromScale(from / MAX_T, 0)
		z.Size = UDim2.fromScale((to - from) / MAX_T, 1)
		z.BackgroundColor3 = color
		z.BackgroundTransparency = transparency
		z.ZIndex = 1
		z.Parent = chargeFrame
		return z
	end
	local windowEnd = charge.PerfectWindowStart + charge.PerfectWindowDuration
	zone("PerfectZone", charge.PerfectWindowStart, windowEnd, colors.Perfect, 0.35)
	zone("Overcharge", windowEnd, MAX_T, Color3.fromRGB(120, 30, 20), 0.55)
	zone("PowerTick", SpinConfig.Levels[2].ChargeTime, SpinConfig.Levels[2].ChargeTime + 0.025, colors.GoldLight, 0.2)

	fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = colors.Orange
	fill.ZIndex = 2
	fill.Parent = chargeFrame
	corner(fill, 8)

	levelLabel = label(chargeFrame, {
		Name = "Level",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -2),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 18,
		Text = "",
	})

	-- Cooldown row.
	local row = Instance.new("Frame")
	row.Name = "Cooldown"
	row.Position = UDim2.new(0, 0, 1, -22)
	row.Size = UDim2.new(1, 0, 0, 22)
	row.BackgroundColor3 = DARK
	row.BackgroundTransparency = 0.25
	row.Parent = panel
	corner(row, 6)
	stroke(row, colors.BallDark, 1.5)

	cooldownFill = Instance.new("Frame")
	cooldownFill.BorderSizePixel = 0
	cooldownFill.BackgroundColor3 = colors.Gold
	cooldownFill.BackgroundTransparency = 0.6
	cooldownFill.Size = UDim2.fromScale(0, 1)
	cooldownFill.Parent = row
	corner(cooldownFill, 6)

	keyHint = label(row, {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(0, 40, 1, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = keyText(),
	})
	label(row, {
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "GOLDEN SPIN",
	})
	cooldownLabel = label(row, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "READY",
	})

	UserInputService.LastInputTypeChanged:Connect(function()
		keyHint.Text = keyText()
	end)

	-- Centre popup.
	popupLabel = label(gui, {
		Name = "Popup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(500, 70),
		Font = Enum.Font.Bangers,
		TextSize = 56,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",
	})
	popupScale = Instance.new("UIScale")
	popupScale.Parent = popupLabel

	-- VFX quality toggle (top right, small).
	local qualityButton = Instance.new("TextButton")
	qualityButton.Name = "VFXQuality"
	qualityButton.AnchorPoint = Vector2.new(1, 0)
	qualityButton.Position = UDim2.new(1, -12, 0, 12)
	qualityButton.Size = UDim2.fromOffset(130, 28)
	qualityButton.BackgroundColor3 = DARK
	qualityButton.BackgroundTransparency = 0.2
	qualityButton.Font = FONT
	qualityButton.TextSize = 13
	qualityButton.TextColor3 = colors.GoldLight
	qualityButton.Parent = gui
	corner(qualityButton, 6)
	stroke(qualityButton, colors.Gold, 1.5)
	local function refresh()
		local _, name = VFXQuality.get()
		qualityButton.Text = "VFX: " .. string.upper(name)
	end
	refresh()
	qualityButton.Activated:Connect(function()
		VFXQuality.cycle()
	end)
	VFXQuality.Changed:Connect(refresh)

	-- Touch devices start on Low to protect frame rate; players can raise it.
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		VFXQuality.set("Low")
	end
end

function SpinMeter.showCharge()
	VFXLib.cancel(chargeFadeJob)
	chargeFrame.Visible = true
	chargeFrame.BackgroundTransparency = 0.15
	fill.Size = UDim2.fromScale(0, 1)
end

function SpinMeter.updateCharge(chargeTime)
	local level, perfect = SpinConfig.getLevel(chargeTime)
	local windowEnd = charge.PerfectWindowStart + charge.PerfectWindowDuration
	local over = chargeTime > windowEnd
	fill.Size = UDim2.fromScale(math.clamp(chargeTime / MAX_T, 0, 1), 1)
	if perfect then
		fill.BackgroundColor3 = colors.Perfect
		levelLabel.Text = "PERFECT SPIN — RELEASE!"
		levelLabel.TextColor3 = colors.Perfect
	elseif over then
		fill.BackgroundColor3 = Color3.fromRGB(170, 80, 40)
		levelLabel.Text = "OVERCHARGED"
		levelLabel.TextColor3 = Color3.fromRGB(230, 120, 90)
	else
		fill.BackgroundColor3 = level == 2 and colors.Gold or colors.Orange
		levelLabel.Text = SpinConfig.Levels[level].Name
		levelLabel.TextColor3 = colors.GoldLight
	end
end

function SpinMeter.hideCharge()
	VFXLib.cancel(chargeFadeJob)
	chargeFadeJob = VFXLib.animate(0.15, function(a)
		chargeFrame.BackgroundTransparency = 0.15 + a * 0.85
	end, function()
		chargeFrame.Visible = false
		levelLabel.Text = ""
	end)
end

function SpinMeter.startCooldown(seconds)
	VFXLib.cancel(cooldownJob)
	if seconds <= 0 then
		cooldownFill.Size = UDim2.fromScale(0, 1)
		cooldownLabel.Text = "READY"
		return
	end
	cooldownJob = VFXLib.animate(seconds, function(a)
		cooldownFill.Size = UDim2.fromScale(1 - a, 1)
		cooldownLabel.Text = string.format("%.1fs", seconds * (1 - a))
	end, function()
		cooldownFill.Size = UDim2.fromScale(0, 1)
		cooldownLabel.Text = "READY"
	end)
end

function SpinMeter.popup(text, color, big)
	VFXLib.cancel(popupJob)
	popupLabel.Text = text
	popupLabel.TextColor3 = color or colors.GoldLight
	local peak = big and 1.25 or 0.9
	popupJob = VFXLib.animate(big and 1.1 or 0.8, function(a)
		if a < 0.12 then
			popupScale.Scale = peak * (1.6 - a / 0.12 * 0.6)
		else
			popupScale.Scale = peak
		end
		local fade = math.clamp((a - 0.65) / 0.35, 0, 1)
		popupLabel.TextTransparency = fade
		popupLabel.TextStrokeTransparency = math.max(fade, 0.2)
	end, function()
		popupLabel.TextTransparency = 1
		popupLabel.TextStrokeTransparency = 1
	end)
end

function SpinMeter.flashDenied(text)
	SpinMeter.popup(text, Color3.fromRGB(230, 120, 90), false)
end

return SpinMeter
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/UI/TuskUI", Class = "ModuleScript", Source = [=[
--[[
	TuskUI  (StarterPlayerScripts.SpinClient.UI.TuskUI)
	("TuskUIController" in the design doc)

	JoJo-style Tusk HUD (only visible while Tusk is equipped):
	  * Act name + tagline
	  * three ability slots: key, name, cooldown sweep (tap/click = use; mobile-friendly)
	  * ultimate meter + "READY" prompt (tap/click = use)
	  * sneak chip (tap = toggle) + sneak attack hint
	  * combo counter, transformation banner, Awakened timer, short toasts
	Act menu (T / MOVESET button): one card per Act. Unfinished Acts are shown
	locked as IN DEVELOPMENT, never as working buttons.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Registry = require(Shared.TuskActRegistry)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.Parent.VFXLib)

local TuskUI = {}

local player = Players.LocalPlayer
local colors = TuskConfig.Colors
local DARK = Color3.fromRGB(12, 16, 28)
local FONT = Enum.Font.GothamBlack
local TITLE_FONT = Enum.Font.Bangers

local callbacks
local gui, hud, actLabel, taglineLabel, ultFill, ultLabel, sneakChip, sneakHint, comboLabel, toastLabel, banner, bannerSub, awakenBar, awakenFill
local slots = {}
local menu
local shownAct
local combo = { Count = 0, Last = 0 }
local jobs = {}

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
end

local function stroke(p, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = colors.Ice
	l.TextStrokeTransparency = 0.5
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function keyName(slotKey)
	local keys = TuskConfig.Keys[slotKey]
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return ""
	end
	if string.find(last.Name, "Gamepad") then
		return keys.Gamepad.Name:gsub("Button", "")
	end
	local k = keys.Keyboard
	local names = { One = "1", Two = "2", Three = "3" }
	return names[k.Name] or k.Name
end

local function animateJob(key, duration, step, done)
	VFXLib.cancel(jobs[key])
	jobs[key] = VFXLib.animate(duration, step, done)
end

function TuskUI.toast(message, color)
	toastLabel.Text = message
	toastLabel.TextColor3 = color or Color3.fromRGB(255, 140, 120)
	animateJob("toast", 1.2, function(a)
		toastLabel.TextTransparency = a < 0.7 and 0 or (a - 0.7) / 0.3
		toastLabel.TextStrokeTransparency = math.max(0.4, toastLabel.TextTransparency)
	end)
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function buildSlot(index, parent)
	local button = Instance.new("TextButton")
	button.Name = "Slot" .. index
	button.Size = UDim2.new(1 / 3, -6, 1, 0)
	button.BackgroundColor3 = DARK
	button.BackgroundTransparency = 0.15
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = parent
	corner(button, 8)
	local edge = stroke(button, colors.Cyan, 2)

	local key = text(button, { Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(30, 16), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = colors.Cyan })
	local name = text(button, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -8, 0, 28), TextSize = 13, TextWrapped = true, Text = "" })
	local overlay = Instance.new("Frame")
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.AnchorPoint = Vector2.new(0, 1)
	overlay.Position = UDim2.fromScale(0, 1)
	overlay.Size = UDim2.fromScale(1, 0)
	overlay.ZIndex = 2
	overlay.Parent = button
	corner(overlay, 8)
	local timer = text(button, { Size = UDim2.fromScale(1, 1), TextSize = 22, Text = "", ZIndex = 3 })

	-- Press / release (works for mouse and touch; hold abilities charge while held).
	button.MouseButton1Down:Connect(function()
		callbacks.Ability(index, true)
	end)
	button.MouseButton1Up:Connect(function()
		callbacks.Ability(index, false)
	end)

	slots[index] = { Button = button, Key = key, Name = name, Overlay = overlay, Timer = timer, Edge = edge }
end

local function buildMenu()
	menu = Instance.new("Frame")
	menu.Name = "ActMenu"
	menu.AnchorPoint = Vector2.new(0.5, 0.5)
	menu.Position = UDim2.fromScale(0.5, 0.5)
	menu.Size = UDim2.new(0.9, 0, 0, 330)
	menu.BackgroundColor3 = DARK
	menu.BackgroundTransparency = 0.05
	menu.Visible = false
	menu.ZIndex = 20
	menu.Parent = gui
	corner(menu, 12)
	stroke(menu, colors.Cyan, 2)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(860, 330)
	limit.Parent = menu

	text(menu, { Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -80, 0, 36), Font = TITLE_FONT, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Left, Text = "TUSK — CHOOSE YOUR ACT", ZIndex = 21 })
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(32, 32)
	close.BackgroundColor3 = Color3.fromRGB(40, 50, 80)
	close.Font = FONT
	close.Text = "X"
	close.TextSize = 16
	close.TextColor3 = colors.Ice
	close.ZIndex = 21
	close.Parent = menu
	corner(close, 6)
	close.Activated:Connect(function()
		menu.Visible = false
	end)

	local row = Instance.new("ScrollingFrame")
	row.Position = UDim2.fromOffset(14, 56)
	row.Size = UDim2.new(1, -28, 1, -70)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ScrollingDirection = Enum.ScrollingDirection.X
	row.AutomaticCanvasSize = Enum.AutomaticSize.X
	row.CanvasSize = UDim2.new()
	row.ScrollBarThickness = 4
	row.ZIndex = 21
	row.Parent = menu
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.Parent = row

	for act = 1, 4 do
		local info = Registry.get(act)
		local ready = Registry.isImplemented(act)
		local card = Instance.new("Frame")
		card.Size = UDim2.fromOffset(196, 250)
		card.BackgroundColor3 = Color3.fromRGB(20, 28, 48)
		card.BackgroundTransparency = ready and 0 or 0.4
		card.ZIndex = 22
		card.Parent = row
		corner(card, 10)
		stroke(card, ready and info.Theme.Primary or Color3.fromRGB(70, 80, 100), 2)
		text(card, { Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 30), Font = TITLE_FONT, TextSize = 28, TextColor3 = ready and info.Theme.Primary or Color3.fromRGB(130, 140, 160), TextXAlignment = Enum.TextXAlignment.Left, Text = info.Name, ZIndex = 23 })
		text(card, { Position = UDim2.fromOffset(10, 38), Size = UDim2.new(1, -20, 0, 16), TextSize = 12, TextColor3 = Color3.fromRGB(170, 185, 210), TextXAlignment = Enum.TextXAlignment.Left, Text = info.Tagline, ZIndex = 23 })
		local moves = "M1  " .. info.M1 .. "\n1  " .. info.Abilities[1] .. "\n2  " .. info.Abilities[2] .. "\n3  " .. info.Abilities[3] .. "\nULT  " .. info.Ultimate
		text(card, { Position = UDim2.fromOffset(10, 62), Size = UDim2.new(1, -20, 0, 120), TextSize = 12, TextColor3 = Color3.fromRGB(210, 220, 240), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Text = moves, ZIndex = 23 })
		if ready then
			local pick = Instance.new("TextButton")
			pick.AnchorPoint = Vector2.new(0.5, 1)
			pick.Position = UDim2.new(0.5, 0, 1, -10)
			pick.Size = UDim2.new(1, -20, 0, 36)
			pick.BackgroundColor3 = info.Theme.Secondary
			pick.Font = FONT
			pick.TextSize = 15
			pick.TextColor3 = Color3.new(1, 1, 1)
			pick.Text = "SELECT"
			pick.ZIndex = 23
			pick.Parent = card
			corner(pick, 8)
			pick.Activated:Connect(function()
				callbacks.Select(act)
				menu.Visible = false
			end)
		else
			text(card, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 36), TextSize = 13, TextColor3 = Color3.fromRGB(150, 160, 180), Text = "IN DEVELOPMENT", ZIndex = 23 })
		end
	end
end

function TuskUI.init(cb)
	callbacks = cb
	gui = Instance.new("ScreenGui")
	gui.Name = "TuskHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	hud = Instance.new("Frame")
	hud.Name = "HUD"
	hud.AnchorPoint = Vector2.new(0.5, 1)
	hud.Position = UDim2.new(0.5, 0, 1, -92) -- sits above the Golden Spin panel
	hud.Size = UDim2.new(0.92, 0, 0, 150)
	hud.BackgroundTransparency = 1
	hud.Visible = false
	hud.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 150)
	limit.Parent = hud

	actLabel = text(hud, { Size = UDim2.new(1, 0, 0, 30), Font = TITLE_FONT, TextSize = 30, TextColor3 = colors.Cyan, TextXAlignment = Enum.TextXAlignment.Left, Text = "" })
	taglineLabel = text(hud, { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextColor3 = Color3.fromRGB(170, 200, 230), TextXAlignment = Enum.TextXAlignment.Left, Text = "" })

	local slotRow = Instance.new("Frame")
	slotRow.Position = UDim2.fromOffset(0, 46)
	slotRow.Size = UDim2.new(1, 0, 0, 62)
	slotRow.BackgroundTransparency = 1
	slotRow.Parent = hud
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 9)
	layout.Parent = slotRow
	for i = 1, 3 do
		buildSlot(i, slotRow)
	end

	-- Ultimate bar (also a button).
	local ult = Instance.new("TextButton")
	ult.Name = "Ultimate"
	ult.Position = UDim2.fromOffset(0, 114)
	ult.Size = UDim2.new(1, -96, 0, 26)
	ult.BackgroundColor3 = DARK
	ult.BackgroundTransparency = 0.15
	ult.AutoButtonColor = false
	ult.Text = ""
	ult.Parent = hud
	corner(ult, 8)
	stroke(ult, colors.Blue, 2)
	ultFill = Instance.new("Frame")
	ultFill.BorderSizePixel = 0
	ultFill.BackgroundColor3 = colors.Blue
	ultFill.Size = UDim2.fromScale(0, 1)
	ultFill.Parent = ult
	corner(ultFill, 8)
	ultLabel = text(ult, { Size = UDim2.fromScale(1, 1), TextSize = 13, Text = "", ZIndex = 2 })
	ult.Activated:Connect(function()
		callbacks.Ultimate()
	end)

	-- Sneak chip (also a button).
	sneakChip = Instance.new("TextButton")
	sneakChip.Name = "Sneak"
	sneakChip.AnchorPoint = Vector2.new(1, 0)
	sneakChip.Position = UDim2.new(1, 0, 0, 114)
	sneakChip.Size = UDim2.fromOffset(88, 26)
	sneakChip.BackgroundColor3 = DARK
	sneakChip.BackgroundTransparency = 0.15
	sneakChip.Font = FONT
	sneakChip.TextSize = 13
	sneakChip.TextColor3 = Color3.fromRGB(150, 170, 200)
	sneakChip.Text = "SNEAK"
	sneakChip.Parent = hud
	corner(sneakChip, 8)
	stroke(sneakChip, Color3.fromRGB(60, 80, 120), 2)
	sneakChip.Activated:Connect(function()
		callbacks.Sneak()
	end)
	sneakHint = text(hud, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(200, 18), TextSize = 12, TextColor3 = colors.Cyan, TextXAlignment = Enum.TextXAlignment.Right, Text = "", Visible = false })

	-- Combo counter (right side of the screen).
	comboLabel = text(gui, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.42, 0), Size = UDim2.fromOffset(220, 60), Font = TITLE_FONT, TextSize = 48, TextColor3 = colors.Ice, TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })

	toastLabel = text(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -250), Size = UDim2.fromOffset(400, 26), TextSize = 18, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })

	-- Transformation banner.
	banner = text(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromOffset(700, 80), Font = TITLE_FONT, TextSize = 72, TextColor3 = colors.Cyan, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })
	bannerSub = text(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromOffset(500, 24), TextSize = 16, TextTransparency = 1, TextStrokeTransparency = 1, Text = "" })
	bannerSub.Position = UDim2.new(0.5, 0, 0.25, 48)

	awakenBar = Instance.new("Frame")
	awakenBar.AnchorPoint = Vector2.new(0.5, 1)
	awakenBar.Position = UDim2.new(0.5, 0, 1, -248)
	awakenBar.Size = UDim2.fromOffset(240, 6)
	awakenBar.BackgroundColor3 = DARK
	awakenBar.Visible = false
	awakenBar.Parent = gui
	corner(awakenBar, 3)
	awakenFill = Instance.new("Frame")
	awakenFill.BorderSizePixel = 0
	awakenFill.BackgroundColor3 = colors.Cyan
	awakenFill.Size = UDim2.fromScale(1, 1)
	awakenFill.Parent = awakenBar
	corner(awakenFill, 3)

	-- MOVESET button (opens the Act menu), under the VFX quality button.
	if TuskConfig.Progression.ShowSelectionMenu then
		local moveset = Instance.new("TextButton")
		moveset.AnchorPoint = Vector2.new(1, 0)
		moveset.Position = UDim2.new(1, -12, 0, 46)
		moveset.Size = UDim2.fromOffset(130, 28)
		moveset.BackgroundColor3 = DARK
		moveset.BackgroundTransparency = 0.2
		moveset.Font = FONT
		moveset.TextSize = 13
		moveset.TextColor3 = colors.Ice
		moveset.Text = "TUSK ACTS (T)"
		moveset.Parent = gui
		corner(moveset, 6)
		stroke(moveset, colors.Cyan, 1.5)
		moveset.Activated:Connect(TuskUI.toggleMenu)
		buildMenu()
	end

	-- Combo counter feeds on the attacker-only Damage event.
	Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
		if name ~= "Damage" or not hud.Visible then
			return
		end
		local now = os.clock()
		combo.Count = (now - combo.Last < 1.6) and combo.Count + 1 or 1
		combo.Last = now
		if combo.Count >= 2 then
			comboLabel.Text = combo.Count .. " HITS"
			animateJob("combo", 1.6, function(a)
				comboLabel.TextTransparency = a < 0.75 and 0 or (a - 0.75) / 0.25
				comboLabel.TextStrokeTransparency = math.max(0.3, comboLabel.TextTransparency)
				comboLabel.Rotation = a < 0.08 and (0.08 - a) * 60 or 0
			end)
		end
	end)
end

function TuskUI.toggleMenu()
	if menu then
		menu.Visible = not menu.Visible
	end
end

---------------------------------------------------------------------------
-- Per-frame refresh and server messages
---------------------------------------------------------------------------
local function refreshAct(act)
	shownAct = act
	hud.Visible = act ~= nil
	if not act then
		return
	end
	local info = Registry.get(act)
	actLabel.Text = info.Name
	actLabel.TextColor3 = info.Theme.Primary
	taglineLabel.Text = info.Tagline:upper()
	for i, slot in ipairs(slots) do
		slot.Name.Text = info.Abilities[i]
		slot.Edge.Color = info.Theme.Primary
	end
end

function TuskUI.step(act)
	if act ~= shownAct then
		refreshAct(act)
	end
	if not act then
		return
	end
	for i, slot in ipairs(slots) do
		slot.Key.Text = keyName("Ability" .. i)
	end
	local max = TuskConfig.Ultimate.MaxMeter
	local meter = player:GetAttribute("TuskUlt") or 0
	local ready = meter >= max
	ultFill.Size = UDim2.fromScale(math.clamp(meter / max, 0, 1), 1)
	local info = Registry.get(act)
	local key = keyName("Ultimate")
	if ready then
		local pulse = (math.sin(os.clock() * 6) + 1) / 2
		ultFill.BackgroundColor3 = colors.Blue:Lerp(colors.Cyan, pulse)
		ultLabel.Text = (key ~= "" and ("[" .. key .. "] ") or "") .. info.Ultimate .. " READY"
	else
		ultFill.BackgroundColor3 = colors.Blue
		ultLabel.Text = info.Ultimate .. "  " .. math.floor(meter / max * 100) .. "%"
	end
	local character = player.Character
	local sneaking = character and character:GetAttribute("TuskSneaking") == true
	sneakChip.TextColor3 = sneaking and DARK or Color3.fromRGB(150, 170, 200)
	sneakChip.BackgroundColor3 = sneaking and colors.Cyan or DARK
	sneakHint.Visible = sneaking
	sneakHint.Text = "M1 / TAP: SNEAK ATTACK"
end

local function cooldown(slot, duration)
	local s = slots[slot]
	if not s then
		return
	end
	animateJob("slot" .. slot, duration, function(a)
		s.Overlay.Size = UDim2.fromScale(1, 1 - a)
		s.Timer.Text = string.format("%.1f", duration * (1 - a))
	end, function()
		s.Overlay.Size = UDim2.fromScale(1, 0)
		s.Timer.Text = ""
		-- Ready flash.
		VFXLib.animate(0.25, function(a)
			s.Button.BackgroundColor3 = colors.Cyan:Lerp(DARK, a)
		end)
	end)
end

local DENY_TEXT = {
	Cooldown = "ON COOLDOWN",
	UltNotReady = "ULTIMATE NOT READY",
	NotAvailable = "THAT ACT IS IN DEVELOPMENT",
	Locked = "ACT LOCKED",
	SwitchCooldown = "WAIT BEFORE SWITCHING ACTS",
	SneakCooldown = "SNEAK ON COOLDOWN",
	SneakAttackCooldown = "SNEAK ATTACK ON COOLDOWN",
	NoTarget = "NO TARGET IN FRONT",
}

function TuskUI.onState(data)
	local kind = data.Kind
	if kind == "Cooldown" then
		cooldown(data.Slot, data.Duration)
	elseif kind == "Denied" then
		local msg = DENY_TEXT[data.Reason] or "CAN'T DO THAT"
		if data.Remaining then
			msg = msg .. string.format("  %.1fs", data.Remaining)
		end
		TuskUI.toast(msg)
	elseif kind == "Interrupted" then
		TuskUI.toast("INTERRUPTED!")
	elseif kind == "SneakAttackCooldown" then
		sneakChip.Text = "SNEAK"
	elseif kind == "Awakened" then
		local info = shownAct and Registry.get(shownAct)
		banner.Text = info and info.Ultimate or "AWAKENED"
		bannerSub.Text = "ABILITIES EMPOWERED"
		animateJob("banner", 1.8, function(a)
			local slide = a < 0.12 and (1 - a / 0.12) or 0
			banner.Position = UDim2.new(0.5, slide * 200, 0.25, 0)
			local fade = a < 0.75 and 0 or (a - 0.75) / 0.25
			banner.TextTransparency = fade
			banner.TextStrokeTransparency = math.max(0.2, fade)
			bannerSub.TextTransparency = fade
			bannerSub.TextStrokeTransparency = math.max(0.4, fade)
		end)
		awakenBar.Visible = true
		animateJob("awaken", data.Duration, function(a)
			awakenFill.Size = UDim2.fromScale(1 - a, 1)
		end, function()
			awakenBar.Visible = false
		end)
	elseif kind == "AwakenEnded" then
		VFXLib.cancel(jobs.awaken)
		awakenBar.Visible = false
	elseif kind == "Equipped" then
		if data.Act and data.Act > 0 then
			TuskUI.toast(Registry.get(data.Act).Name .. " EQUIPPED", colors.Cyan)
		end
	end
end

return TuskUI
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/VFXLib", Class = "ModuleScript", Source = [=[
--[[
	VFXLib  (StarterPlayerScripts.SpinClient.VFXLib)

	Reusable procedural VFX building blocks. Built for Spin first, and meant
	to be reused by Tusk nails, wormholes and Wrecking Balls later.

	Rules every effect follows:
	  * lives in workspace.SpinClientFX (client-only, never replicated)
	  * has a fixed duration and destroys itself (animate() + Debris)
	  * reads VFXQuality for particle counts / detail
	  * skips optional detail when too many effects are already active
]]

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local VFXQuality = require(Shared.VFXQuality)

local VFXLib = {}

VFXLib.Textures = {
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
}

local folder = workspace:FindFirstChild("SpinClientFX")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "SpinClientFX"
	folder.Parent = workspace
end
VFXLib.Folder = folder

---------------------------------------------------------------------------
-- Frame scheduler: one RenderStepped connection drives every animation.
---------------------------------------------------------------------------
local jobs = {}

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for i = #jobs, 1, -1 do
		local job = jobs[i]
		local alpha = (now - job.Start) / job.Duration
		if job.Cancelled or alpha >= 1 then
			table.remove(jobs, i)
			if not job.Cancelled then
				local ok, err = pcall(job.Step, 1, dt)
				if not ok then
					warn("[VFXLib] step error:", err)
				end
			end
			if job.Done then
				pcall(job.Done)
			end
		else
			local ok, err = pcall(job.Step, alpha, dt)
			if not ok then
				warn("[VFXLib] step error:", err)
				job.Cancelled = true
			end
		end
	end
end)

-- step(alpha 0..1, dt); done() always runs exactly once, even if cancelled.
function VFXLib.animate(duration, step, done)
	local job = { Start = os.clock(), Duration = math.max(duration, 1e-3), Step = step, Done = done }
	table.insert(jobs, job)
	return job
end

function VFXLib.cancel(job)
	if job then
		job.Cancelled = true
	end
end

function VFXLib.easeOut(a)
	return 1 - (1 - a) * (1 - a) * (1 - a)
end

function VFXLib.easeInOut(a)
	return a < 0.5 and 4 * a * a * a or 1 - ((-2 * a + 2) ^ 3) / 2
end

---------------------------------------------------------------------------
-- Effect budget
---------------------------------------------------------------------------
local activeEffects = 0

-- Returns true if an optional effect may spawn; call VFXLib.release() after.
function VFXLib.acquire()
	if activeEffects >= VFXQuality.get().MaxActiveEffects then
		return false
	end
	activeEffects = activeEffects + 1
	return true
end

function VFXLib.release()
	activeEffects = math.max(0, activeEffects - 1)
end

function VFXLib.particleCount(n)
	return math.max(1, math.floor(n * VFXQuality.get().Particles + 0.5))
end

---------------------------------------------------------------------------
-- Primitives
---------------------------------------------------------------------------
function VFXLib.part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	if not p.Parent then
		p.Parent = folder
	end
	return p
end

-- Invisible anchored carrier for attachments, emitters and lights.
function VFXLib.anchor(cframe, lifetime)
	local p = VFXLib.part({ Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1), CFrame = cframe })
	if lifetime then
		Debris:AddItem(p, lifetime)
	end
	return p
end

--[[
	Energy ring made of straight Beams between attachments on a circle.
	Ring lies in the carrier part's local XZ plane (axis = local Y).
	ring:SetRadius(r), ring:SetWidth(w), ring:SetTransparency(t),
	ring:SetCFrame(cf), ring:Destroy()
]]
function VFXLib.ring(opts)
	local segments = opts.Segments or VFXQuality.get().RingSegments
	local carrier = VFXLib.anchor(opts.CFrame or CFrame.new())
	local attachments = {}
	local beams = {}
	for i = 1, segments do
		local a = Instance.new("Attachment")
		a.Parent = carrier
		attachments[i] = a
	end
	local color = ColorSequence.new(opts.Color or Color3.new(1, 0.8, 0.3))
	for i = 1, segments do
		local b = Instance.new("Beam")
		b.Attachment0 = attachments[i]
		b.Attachment1 = attachments[i % segments + 1]
		b.Color = color
		b.LightEmission = opts.LightEmission or 1
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Segments = 1
		b.Width0 = opts.Width or 0.3
		b.Width1 = opts.Width or 0.3
		b.Transparency = NumberSequence.new(opts.Transparency or 0)
		b.Parent = carrier
		beams[i] = b
	end

	local ring = { Part = carrier, Radius = opts.Radius or 2 }
	function ring:SetRadius(r)
		self.Radius = r
		for i, a in ipairs(attachments) do
			local theta = (i - 1) / segments * math.pi * 2
			a.Position = Vector3.new(math.cos(theta) * r, 0, math.sin(theta) * r)
		end
	end
	function ring:SetWidth(w)
		for _, b in ipairs(beams) do
			b.Width0 = w
			b.Width1 = w
		end
	end
	function ring:SetTransparency(t)
		local seq = NumberSequence.new(math.clamp(t, 0, 1))
		for _, b in ipairs(beams) do
			b.Transparency = seq
		end
	end
	function ring:SetColor(c)
		local seq = ColorSequence.new(c)
		for _, b in ipairs(beams) do
			b.Color = seq
		end
	end
	function ring:SetCFrame(cf)
		carrier.CFrame = cf
	end
	function ring:Destroy()
		carrier:Destroy()
	end
	ring:SetRadius(ring.Radius)
	return ring
end

-- Expanding, fading ring (shockwave). axisCFrame: ring axis = its UpVector.
function VFXLib.shockwave(axisCFrame, opts)
	if not VFXLib.acquire() then
		return
	end
	local ring = VFXLib.ring({
		CFrame = axisCFrame,
		Radius = opts.StartRadius or 0.5,
		Width = opts.Width or 0.6,
		Color = opts.Color,
	})
	local maxRadius = opts.Radius or 10
	local width = opts.Width or 0.6
	local spin = opts.Spin or 0
	VFXLib.animate(opts.Duration or 0.45, function(a)
		local e = VFXLib.easeOut(a)
		ring:SetRadius((opts.StartRadius or 0.5) + (maxRadius - (opts.StartRadius or 0.5)) * e)
		ring:SetWidth(width * (1 - a * 0.7))
		ring:SetTransparency(a ^ 1.6)
		if spin ~= 0 then
			ring:SetCFrame(axisCFrame * CFrame.Angles(0, spin * e, 0))
		end
	end, function()
		ring:Destroy()
		VFXLib.release()
	end)
end

-- Flat neon disc that expands along the ground.
function VFXLib.groundDisc(position, normal, opts)
	if not VFXLib.acquire() then
		return
	end
	local radius = opts.Radius or 8
	-- Cylinder axis is X: point it along the surface normal.
	local up = math.abs(normal.Y) > 0.95 and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
	local right = normal.Unit
	local back = right:Cross(up).Unit
	local cf = CFrame.fromMatrix(position + normal * 0.05, right, back:Cross(right).Unit)
	local disc = VFXLib.part({
		Shape = Enum.PartType.Cylinder,
		Color = opts.Color or Color3.new(1, 0.8, 0.3),
		Transparency = 0.25,
		CFrame = cf,
		Size = Vector3.new(0.1, 0.5, 0.5),
	})
	VFXLib.animate(opts.Duration or 0.4, function(a)
		local d = 0.5 + radius * 2 * VFXLib.easeOut(a)
		disc.Size = Vector3.new(0.08, d, d)
		disc.Transparency = 0.25 + 0.75 * a
	end, function()
		disc:Destroy()
		VFXLib.release()
	end)
end

-- One-shot particle burst.
function VFXLib.burst(position, opts)
	local carrier = VFXLib.anchor(CFrame.new(position), (opts.Lifetime or 0.6) + 0.5)
	local e = Instance.new("ParticleEmitter")
	e.Texture = opts.Texture or VFXLib.Textures.Sparkle
	e.Color = ColorSequence.new(opts.Color or Color3.new(1, 0.85, 0.4))
	e.LightEmission = opts.LightEmission or 1
	e.LightInfluence = 0
	e.Size = opts.Size or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = opts.TransparencySeq or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new((opts.Lifetime or 0.6) * 0.5, opts.Lifetime or 0.6)
	e.Speed = NumberRange.new((opts.Speed or 20) * 0.5, opts.Speed or 20)
	e.SpreadAngle = Vector2.new(opts.Spread or 180, opts.Spread or 180)
	e.Drag = opts.Drag or 4
	e.Acceleration = opts.Acceleration or Vector3.new(0, 0, 0)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.Rate = 0
	if opts.Direction then
		e.EmissionDirection = Enum.NormalId.Top
		carrier.CFrame = CFrame.lookAt(position, position + opts.Direction) * CFrame.Angles(-math.pi / 2, 0, 0)
	end
	e.Parent = carrier
	e:Emit(VFXLib.particleCount(opts.Count or 20))
	return carrier
end

-- Short point-light flash.
function VFXLib.flash(position, color, brightness, range, duration)
	if not VFXQuality.get().Lights then
		return
	end
	local carrier = VFXLib.anchor(CFrame.new(position))
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 16
	light.Brightness = brightness or 4
	light.Shadows = false
	light.Parent = carrier
	VFXLib.animate(duration or 0.3, function(a)
		light.Brightness = (brightness or 4) * (1 - a)
	end, function()
		carrier:Destroy()
	end)
end

-- Fading ghost copy of a sphere (afterimage), High quality only.
function VFXLib.afterimage(cframe, size, color)
	if not VFXQuality.get().Afterimages or not VFXLib.acquire() then
		return
	end
	local ghost = VFXLib.part({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		CFrame = cframe,
		Color = color,
		Transparency = 0.55,
	})
	VFXLib.animate(0.18, function(a)
		ghost.Transparency = 0.55 + 0.45 * a
		local s = size * (1 + a * 0.3)
		ghost.Size = Vector3.new(s, s, s)
	end, function()
		ghost:Destroy()
		VFXLib.release()
	end)
end

---------------------------------------------------------------------------
-- Sound
---------------------------------------------------------------------------
function VFXLib.sound(soundId, parentOrPosition, volume, pitch, looped)
	if not soundId or soundId == "" then
		return nil
	end
	local parent = parentOrPosition
	if typeof(parentOrPosition) == "Vector3" then
		parent = VFXLib.anchor(CFrame.new(parentOrPosition), 6)
	end
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	s.Looped = looped == true
	s.RollOffMaxDistance = 220
	s.Parent = parent or folder
	s:Play()
	if not s.Looped then
		Debris:AddItem(s, 6)
	end
	return s
end

return VFXLib
]=] },
	{ Service = "StarterPlayerScripts", Path = "SpinClient/WorldClient", Class = "ModuleScript", Source = [=[
--[[
	WorldClient  (StarterPlayerScripts.SpinClient.WorldClient)
	Client side of the SBR map:
	  * NPC speech bubbles (from NPCService "NPCSay"), shown within 60 studs
	  * drifting desert dust around the camera when the SBRMap is present
	    (particle count follows VFXQuality)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local VFXQuality = require(Shared.VFXQuality)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)

local WorldClient = {}
local bubbles = {} -- [npc model] = BillboardGui

local function showBubble(npc, text)
	local head = npc and npc:FindFirstChild("Head")
	local camera = workspace.CurrentCamera
	if not head or not camera or (camera.CFrame.Position - head.Position).Magnitude > 60 then
		return
	end
	if bubbles[npc] then
		bubbles[npc]:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(260, 70)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local frame = Instance.new("TextLabel")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(250, 240, 220)
	frame.TextColor3 = Color3.fromRGB(40, 25, 15)
	frame.Font = Enum.Font.GothamMedium
	frame.TextWrapped = true
	frame.TextSize = 15
	frame.Text = text
	frame.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = frame
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(120, 80, 40)
	s.Thickness = 2
	s.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = frame
	bubbles[npc] = gui
	VFXLib.animate(4.5, function(a)
		local fade = a > 0.85 and (a - 0.85) / 0.15 or 0
		frame.BackgroundTransparency = fade
		frame.TextTransparency = fade
		s.Transparency = fade
	end, function()
		if bubbles[npc] == gui then
			bubbles[npc] = nil
		end
		gui:Destroy()
	end)
end

local function startDust()
	local carrier = VFXLib.anchor(CFrame.new())
	carrier.Size = Vector3.new(80, 20, 80)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = VFXLib.Textures.Smoke
	emitter.Color = ColorSequence.new(Color3.fromRGB(220, 195, 150))
	emitter.LightInfluence = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.88), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(5, 8)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.EmissionDirection = Enum.NormalId.Right -- drift with the wind
	emitter.Acceleration = Vector3.new(2, 0, 0)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Parent = carrier
	local function rate()
		emitter.Rate = 6 * VFXQuality.get().Particles
	end
	rate()
	VFXQuality.Changed:Connect(rate)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera then
			local p = camera.CFrame.Position
			carrier.CFrame = CFrame.new(p.X, math.max(p.Y - 4, 4), p.Z)
		end
	end)
end

function WorldClient.init()
	Net.get("WorldFX").OnClientEvent:Connect(function(name, data)
		if name == "NPCSay" and typeof(data) == "table" then
			showBubble(data.NPC, tostring(data.Text))
		end
	end)
	task.spawn(function()
		if workspace:WaitForChild("SBRMap", 15) then
			startDust()
		end
	end)
end

return WorldClient
]=] },
	{ Service = "ServerStorage", Path = "SpinTools", Class = "Folder", Source = nil },
	{ Service = "ServerStorage", Path = "SpinTools/SBRMapBuilder", Class = "ModuleScript", Source = [=[
--[[
	SBRMapBuilder  (ServerStorage.SpinTools.SBRMapBuilder — ModuleScript)

	One-time Studio tool that builds an original Steel Ball Run-style
	western map into your place as normal, editable parts + terrain:

	  * race grounds: dirt track, rail fences, START/GOAL arch, flags
	  * mission church at the end of the track
	  * racers' tent camp with covered wagons
	  * western town (saloon, store, sheriff, hotel, bank, stables,
	    post office, blacksmith) with an entrance banner arch
	  * Race Headquarters building on the hill
	  * desert: sand terrain, mountain ring, rocks, cacti, grass patches
	  * desert lighting, atmosphere, clouds, spawn point
	  * NPC spawn markers (NPCService turns them into NPCs at runtime)

	HOW TO RUN (Studio, edit mode):
	  View > Command Bar, paste and press Enter:
	    require(game.ServerStorage.SpinTools.SBRMapBuilder).Build()
	  Options:
	    .Build({ Origin = Vector3.new(0, 0, 0), Terrain = true, Lighting = true, Seed = 7 })
	  Running it again replaces the previous "SBRMap" model (terrain is
	  re-filled in the map area only). Tip: try it in a new Baseplate place
	  first, or pass an Origin away from your existing map.
	  Then File > Save.
]]

local Lighting = game:GetService("Lighting")

local SBRMapBuilder = {}

local C = {
	Stucco = Color3.fromRGB(214, 198, 170),
	StuccoDark = Color3.fromRGB(176, 158, 128),
	Wood = Color3.fromRGB(122, 84, 52),
	WoodDark = Color3.fromRGB(84, 56, 34),
	WoodLight = Color3.fromRGB(160, 118, 76),
	Canvas = Color3.fromRGB(232, 226, 210),
	Red = Color3.fromRGB(176, 40, 36),
	White = Color3.fromRGB(240, 236, 228),
	Brick = Color3.fromRGB(150, 70, 56),
	Roof = Color3.fromRGB(96, 40, 44),
	Window = Color3.fromRGB(40, 36, 44),
	Green = Color3.fromRGB(70, 120, 50),
	Cactus = Color3.fromRGB(80, 120, 60),
	Gold = Color3.fromRGB(220, 170, 60),
}

local FLAG_PALETTES = {
	{ Color3.fromRGB(200, 30, 40), Color3.fromRGB(245, 245, 240) },
	{ Color3.fromRGB(30, 60, 150), Color3.fromRGB(245, 245, 240), Color3.fromRGB(200, 30, 40) },
	{ Color3.fromRGB(20, 120, 60), Color3.fromRGB(250, 210, 40) },
	{ Color3.fromRGB(245, 245, 240), Color3.fromRGB(30, 110, 60) },
	{ Color3.fromRGB(20, 20, 20), Color3.fromRGB(250, 200, 30), Color3.fromRGB(200, 30, 40) },
	{ Color3.fromRGB(30, 80, 170), Color3.fromRGB(250, 210, 40) },
	{ Color3.fromRGB(200, 30, 40), Color3.fromRGB(30, 60, 150) },
}

local root, origin, rng

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or root
	return f
end

local function block(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(origin) * cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function cylinder(parent, name, length, diameter, cf, color, material)
	-- Cylinder axis is X; callers pass cf with the axis already rotated as needed.
	return block(parent, name, Vector3.new(length, diameter, diameter), cf, color, material, { Shape = Enum.PartType.Cylinder })
end

local function upright(x, y, z)
	return CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2)
end

local function sign(part, face, text, textColor, bg, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bg or part.Color
	label.BackgroundTransparency = bg and 0 or 1
	label.Font = font or Enum.Font.Fondamento
	label.TextScaled = true
	label.TextColor3 = textColor or Color3.fromRGB(30, 20, 10)
	label.Text = text
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = label
	return gui
end

local function stripedPole(parent, x, z, height)
	local segments = 8
	local seg = height / segments
	for i = 0, segments - 1 do
		cylinder(parent, "PoleStripe", seg, 1.2, upright(x, seg * (i + 0.5), z), i % 2 == 0 and C.Red or C.White)
	end
	block(parent, "PoleCap", Vector3.new(1.5, 1.5, 1.5), CFrame.new(x, height + 0.6, z), C.Gold, Enum.Material.Metal, { Shape = Enum.PartType.Ball })
end

local function flag(parent, x, z, height, palette, yaw)
	cylinder(parent, "FlagPole", height, 0.35, upright(x, height / 2, z), C.WoodLight, Enum.Material.Wood)
	local stripes = #palette
	local w, h = 5, 3.2
	for i, color in ipairs(palette) do
		local stripeH = h / stripes
		block(parent, "Flag", Vector3.new(w, stripeH, 0.12),
			CFrame.new(x, height - 0.4 - stripeH * (i - 0.5), z) * CFrame.Angles(0, yaw or 0, 0) * CFrame.new(w / 2 + 0.2, 0, 0),
			color, Enum.Material.Fabric)
	end
end

local function tent(parent, x, z, yaw, scale)
	scale = scale or 1
	-- A block rotated 45 degrees and sunk halfway reads as an A-frame tent.
	local s = 6 * scale
	block(parent, "Tent", Vector3.new(s, s, 9 * scale),
		CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.pi / 4),
		C.Canvas, Enum.Material.Fabric)
	block(parent, "TentDoor", Vector3.new(1.6 * scale, 2.2 * scale, 0.1),
		CFrame.new(x, 1.1 * scale, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -4.5 * scale - 0.06),
		C.WoodDark, Enum.Material.Fabric)
end

local function wagon(parent, x, z, yaw)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local function at(cf)
		return base * cf
	end
	local model = Instance.new("Model")
	model.Name = "CoveredWagon"
	model.Parent = parent
	block(model, "Bed", Vector3.new(4.4, 1.6, 9), at(CFrame.new(0, 2.6, 0)), C.Wood, Enum.Material.WoodPlanks)
	-- Canvas: long cylinder along Z, lower half hidden inside the bed.
	block(model, "Canvas", Vector3.new(8.6, 4.6, 4.6), at(CFrame.new(0, 3.3, 0) * CFrame.Angles(0, math.pi / 2, 0)), C.Canvas, Enum.Material.Fabric, { Shape = Enum.PartType.Cylinder })
	for _, wz in ipairs({ -3, 3 }) do
		for _, wx in ipairs({ -2.5, 2.5 }) do
			local d = wz > 0 and 3.6 or 3
			block(model, "Wheel", Vector3.new(0.4, d, d), at(CFrame.new(wx, d / 2, wz)), C.WoodDark, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
		end
	end
	block(model, "Tongue", Vector3.new(0.4, 0.4, 5), at(CFrame.new(0, 1.6, -7) * CFrame.Angles(0.15, 0, 0)), C.WoodDark, Enum.Material.Wood)
end

local function fenceLine(parent, x, z0, z1)
	local step = 8
	local count = math.floor(math.abs(z1 - z0) / step)
	local dir = z1 > z0 and 1 or -1
	for i = 0, count do
		local z = z0 + i * step * dir
		block(parent, "FencePost", Vector3.new(0.6, 3.4, 0.6), CFrame.new(x, 1.7, z), C.WoodDark, Enum.Material.Wood)
	end
	local length = count * step
	local mid = z0 + dir * length / 2
	for _, y in ipairs({ 1.4, 2.8 }) do
		block(parent, "FenceRail", Vector3.new(0.35, 0.35, length), CFrame.new(x, y, mid), C.WoodLight, Enum.Material.Wood)
	end
end

local function windowRow(parent, cf, count, spacing, size)
	for i = 1, count do
		local offset = (i - (count + 1) / 2) * spacing
		block(parent, "Window", size, cf * CFrame.new(offset, 0, 0), C.Window, Enum.Material.Glass, { Transparency = 0.1 })
	end
end

---------------------------------------------------------------------------
-- Sections
---------------------------------------------------------------------------
local function buildTerrain()
	local terrain = workspace.Terrain
	local o = origin
	terrain:FillBlock(CFrame.new(o + Vector3.new(0, -8, 0)), Vector3.new(1400, 16, 1400), Enum.Material.Sand)
	-- Race track strip and town street (hard-packed ground).
	terrain:FillBlock(CFrame.new(o + Vector3.new(0, -0.6, -50)), Vector3.new(26, 1.2, 420), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(o + Vector3.new(260, -0.6, -40)), Vector3.new(30, 1.2, 240), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(o + Vector3.new(130, -0.6, 100)), Vector3.new(260, 1.2, 18), Enum.Material.Ground)
	-- Grass around the town and headquarters hill.
	for _ = 1, 26 do
		local p = o + Vector3.new(rng:NextNumber(180, 360), -0.8, rng:NextNumber(-220, 120))
		terrain:FillCylinder(CFrame.new(p), 1, rng:NextNumber(6, 18), Enum.Material.Grass)
	end
	-- Headquarters hill.
	terrain:FillBall(o + Vector3.new(260, -70, -265), 90, Enum.Material.Grass)
	-- Mountain ring.
	for i = 1, 30 do
		local angle = (i / 30) * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local dist = rng:NextNumber(520, 620)
		local radius = rng:NextNumber(70, 130)
		local p = o + Vector3.new(math.cos(angle) * dist, -radius * 0.45, math.sin(angle) * dist)
		terrain:FillBall(p, radius, i % 3 == 0 and Enum.Material.Rock or Enum.Material.Sandstone)
	end
	-- Rocks scattered in the desert.
	for _ = 1, 60 do
		local p = o + Vector3.new(rng:NextNumber(-450, 450), 0, rng:NextNumber(-450, 450))
		if math.abs(p.X - o.X) > 30 or math.abs(p.Z - o.Z + 50) > 220 then
			terrain:FillBall(p, rng:NextNumber(2, 6), Enum.Material.Sandstone)
		end
	end
end

local function buildLighting()
	Lighting.ClockTime = 14.6
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(110, 96, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 135, 115)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	local function ensure(class, name)
		local existing = Lighting:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
		local inst = Instance.new(class)
		inst.Name = name
		inst.Parent = Lighting
		return inst
	end
	local atmosphere = ensure("Atmosphere", "SBRAtmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(230, 205, 170)
	atmosphere.Decay = Color3.fromRGB(190, 150, 110)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.6
	local cc = ensure("ColorCorrectionEffect", "SBRWarmth")
	cc.TintColor = Color3.fromRGB(255, 244, 228)
	cc.Saturation = 0.05
	cc.Contrast = 0.06
	local rays = ensure("SunRaysEffect", "SBRSunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	local bloom = ensure("BloomEffect", "SBRBloom")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.6
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = workspace.Terrain
end

local function buildRaceGrounds()
	local f = folder("RaceGrounds")
	fenceLine(f, -14, 140, -250)
	fenceLine(f, 14, 140, -250)

	-- START / GOAL arch.
	local archZ = 110
	stripedPole(f, -16, archZ, 22)
	stripedPole(f, 16, archZ, 22)
	local bannerPart = block(f, "RaceBanner", Vector3.new(30, 6, 0.4), CFrame.new(0, 18, archZ), C.White, Enum.Material.Fabric)
	sign(bannerPart, Enum.NormalId.Front, "★ STEEL BALL RUN ★  START", C.Red, C.White, Enum.Font.Fondamento)
	sign(bannerPart, Enum.NormalId.Back, "★ STEEL BALL RUN ★  GOAL", C.Red, C.White, Enum.Font.Fondamento)
	for _, x in ipairs({ -12.5, 12.5 }) do
		block(f, "BannerStripe", Vector3.new(1, 6, 0.45), CFrame.new(x, 18, archZ), C.Red, Enum.Material.Fabric)
	end

	-- Flags lining the track.
	for i = 0, 11 do
		local z = 120 - i * 32
		flag(f, -22, z, 16, FLAG_PALETTES[(i % #FLAG_PALETTES) + 1], math.pi)
		flag(f, 22, z - 16, 16, FLAG_PALETTES[((i + 3) % #FLAG_PALETTES) + 1], 0)
	end

	-- Spectator stand near the start.
	for row = 0, 3 do
		block(f, "Bleacher", Vector3.new(4, 1, 40), CFrame.new(-30 - row * 4, 1 + row * 1.6, 70), C.WoodLight, Enum.Material.WoodPlanks)
	end
	block(f, "BleacherRoof", Vector3.new(20, 0.6, 44), CFrame.new(-36, 11, 70) * CFrame.Angles(0, 0, -0.12), C.Red, Enum.Material.Fabric)
	for _, z in ipairs({ 50, 90 }) do
		cylinder(f, "BleacherPost", 10, 0.6, upright(-27, 5, z), C.WoodDark, Enum.Material.Wood)
		cylinder(f, "BleacherPost", 12, 0.6, upright(-45, 6, z), C.WoodDark, Enum.Material.Wood)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SBRSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(origin + Vector3.new(0, 0.5, 150))
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Color = C.WoodLight
	spawn.Duration = 0
	spawn.Parent = f
end

local function buildChurch()
	local f = folder("MissionChurch")
	local z = -300
	block(f, "Nave", Vector3.new(36, 24, 60), CFrame.new(0, 12, z - 20), C.Stucco, Enum.Material.Limestone)
	block(f, "NaveRoof", Vector3.new(38, 2, 62), CFrame.new(0, 25, z - 20), C.StuccoDark, Enum.Material.Limestone)
	local facade = block(f, "Facade", Vector3.new(40, 30, 3), CFrame.new(0, 15, z + 11), C.Stucco, Enum.Material.Limestone)
	block(f, "FacadeGable", Vector3.new(16, 8, 3), CFrame.new(0, 33, z + 11), C.Stucco, Enum.Material.Limestone)
	block(f, "Doorway", Vector3.new(9, 13, 0.4), CFrame.new(0, 6.5, z + 12.6), C.WoodDark, Enum.Material.Wood)
	block(f, "DoorArch", Vector3.new(9, 9, 0.5), CFrame.new(0, 13, z + 12.5) * CFrame.Angles(0, math.pi / 2, 0), C.WoodDark, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
	windowRow(f, CFrame.new(0, 22, z + 12.6), 3, 6, Vector3.new(2, 4, 0.3))
	for _, x in ipairs({ -22, 22 }) do
		block(f, "BellTower", Vector3.new(12, 44, 12), CFrame.new(x, 22, z + 8), C.Stucco, Enum.Material.Limestone)
		block(f, "BellLoft", Vector3.new(9, 8, 9), CFrame.new(x, 48, z + 8), C.StuccoDark, Enum.Material.Limestone)
		block(f, "BellOpening", Vector3.new(4, 5, 9.2), CFrame.new(x, 48, z + 8), C.Window, Enum.Material.SmoothPlastic)
		block(f, "TowerDome", Vector3.new(8, 8, 8), CFrame.new(x, 52, z + 8), C.StuccoDark, Enum.Material.Limestone, { Shape = Enum.PartType.Ball })
		block(f, "CrossV", Vector3.new(0.5, 4, 0.5), CFrame.new(x, 58, z + 8), C.WoodDark, Enum.Material.Wood)
		block(f, "CrossH", Vector3.new(2.2, 0.5, 0.5), CFrame.new(x, 58.6, z + 8), C.WoodDark, Enum.Material.Wood)
		windowRow(f, CFrame.new(x, 30, z + 14.1), 1, 0, Vector3.new(2.2, 4, 0.3))
	end
	block(f, "Dome", Vector3.new(20, 20, 20), CFrame.new(0, 26, z - 26), C.StuccoDark, Enum.Material.Limestone, { Shape = Enum.PartType.Ball })
	block(f, "DomeLantern", Vector3.new(3, 5, 3), CFrame.new(0, 37, z - 26), C.Stucco, Enum.Material.Limestone)
	-- Courtyard wall with gate.
	for _, x in ipairs({ -32, 32 }) do
		block(f, "CourtWall", Vector3.new(20, 8, 2), CFrame.new(x, 4, z + 24), C.Brick, Enum.Material.Brick)
	end
	for _, x in ipairs({ -22, 22 }) do
		block(f, "CourtWallSide", Vector3.new(2, 8, 14), CFrame.new(x * 1.92, 4, z + 17), C.Brick, Enum.Material.Brick)
	end
end

local function buildCamp()
	local f = folder("TentCamp")
	for side = -1, 1, 2 do
		for i = 0, 13 do
			for j = 0, 2 do
				local x = side * (40 + j * 24 + rng:NextNumber(-4, 4))
				local z = 40 - i * 18 + rng:NextNumber(-4, 4)
				if rng:NextNumber() < 0.68 then
					tent(f, x, z, rng:NextNumber(-0.4, 0.4) + (side > 0 and math.pi / 2 or -math.pi / 2), rng:NextNumber(0.85, 1.15))
				elseif rng:NextNumber() < 0.6 then
					wagon(f, x, z, rng:NextNumber(0, math.pi * 2))
				end
			end
		end
	end
	-- Campfires.
	for _ = 1, 8 do
		local x = (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(45, 100)
		local z = rng:NextNumber(-200, 50)
		local fire = block(f, "Campfire", Vector3.new(2.4, 0.6, 2.4), CFrame.new(x, 0.3, z), C.WoodDark, Enum.Material.Wood)
		local emitter = Instance.new("Fire")
		emitter.Size = 4
		emitter.Heat = 6
		emitter.Parent = fire
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 160, 80)
		light.Range = 14
		light.Brightness = 1.5
		light.Parent = fire
	end
end

local TOWN_BUILDINGS = { "SALOON", "GENERAL STORE", "SHERIFF", "HOTEL", "BANK", "STABLES", "POST OFFICE", "BLACKSMITH" }

local function westernBuilding(parent, name, cf, width, depth, height, color)
	local model = Instance.new("Model")
	model.Name = name:gsub(" ", "")
	model.Parent = parent
	local function at(offset)
		return cf * offset
	end
	block(model, "Body", Vector3.new(width, height, depth), at(CFrame.new(0, height / 2, depth / 2)), color, Enum.Material.WoodPlanks)
	block(model, "Roof", Vector3.new(width + 1, 1, depth + 1), at(CFrame.new(0, height + 0.5, depth / 2)), C.Roof, Enum.Material.WoodPlanks)
	-- False front, taller than the building (classic western look).
	local front = block(model, "FalseFront", Vector3.new(width + 1, height + 6, 1), at(CFrame.new(0, (height + 6) / 2, -0.5)), color, Enum.Material.WoodPlanks)
	local board = block(model, "SignBoard", Vector3.new(width - 2, 3.2, 0.3), at(CFrame.new(0, height + 2.5, -1.15)), C.WoodDark, Enum.Material.Wood)
	sign(board, Enum.NormalId.Front, name, Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	-- Door, windows, porch.
	block(model, "Door", Vector3.new(3.2, 6.5, 0.3), at(CFrame.new(0, 3.25, -1.1)), C.WoodDark, Enum.Material.Wood)
	windowRow(model, at(CFrame.new(0, 4, -1.1)), 2, width * 0.55, Vector3.new(3, 3.6, 0.2))
	windowRow(model, at(CFrame.new(0, height - 3, -1.1)), 3, width * 0.28, Vector3.new(2.4, 3, 0.2))
	block(model, "PorchFloor", Vector3.new(width + 1, 0.6, 6), at(CFrame.new(0, 0.3, -4)), C.WoodLight, Enum.Material.WoodPlanks)
	block(model, "PorchRoof", Vector3.new(width + 1, 0.5, 6.5), at(CFrame.new(0, 8.6, -4) * CFrame.Angles(-0.12, 0, 0)), C.Roof, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -width / 2, 0, width / 2 }) do
		block(model, "PorchPost", Vector3.new(0.5, 8, 0.5), at(CFrame.new(x, 4.3, -6.8)), C.WoodDark, Enum.Material.Wood)
	end
	return model
end

local function buildTown()
	local f = folder("WesternTown")
	local streetX = 260
	local colors = { C.Wood, C.WoodLight, Color3.fromRGB(150, 90, 70), Color3.fromRGB(120, 110, 90), C.Brick }
	for i, name in ipairs(TOWN_BUILDINGS) do
		local side = (i % 2 == 1) and -1 or 1
		local row = math.floor((i - 1) / 2)
		local z = 40 - row * 34
		local x = streetX + side * 24
		-- Front faces the street.
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, side * math.pi / 2, 0)
		westernBuilding(f, name, cf, 18, 20, 12 + (i % 3) * 2, colors[(i % #colors) + 1])
	end
	-- Entrance arch banner.
	for _, x in ipairs({ streetX - 15, streetX + 15 }) do
		block(f, "ArchPost", Vector3.new(1.4, 20, 1.4), CFrame.new(x, 10, 90), C.WoodDark, Enum.Material.Wood)
	end
	block(f, "ArchBeam", Vector3.new(34, 1.4, 1.4), CFrame.new(streetX, 19.5, 90), C.WoodDark, Enum.Material.Wood)
	local banner = block(f, "TownBanner", Vector3.new(26, 5, 0.3), CFrame.new(streetX, 15.5, 90), Color3.fromRGB(150, 175, 90), Enum.Material.Fabric)
	sign(banner, Enum.NormalId.Front, "★ STEEL BALL RUN RACE ★", Color3.fromRGB(25, 25, 20), nil, Enum.Font.Fondamento)
	sign(banner, Enum.NormalId.Back, "★ STEEL BALL RUN RACE ★", Color3.fromRGB(25, 25, 20), nil, Enum.Font.Fondamento)
	-- Props: barrels, crates, troughs, hitching rails, lamp posts.
	for i = 1, 14 do
		local side = i % 2 == 0 and -1 or 1
		local z = 50 - i * 12
		local x = streetX + side * rng:NextNumber(11, 13)
		local roll = rng:NextNumber()
		if roll < 0.35 then
			block(f, "Barrel", Vector3.new(3, 2.4, 2.4), upright(x, 1.5, z), C.Wood, Enum.Material.Wood, { Shape = Enum.PartType.Cylinder })
		elseif roll < 0.6 then
			block(f, "Crate", Vector3.new(2.6, 2.6, 2.6), CFrame.new(x, 1.3, z) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), C.WoodLight, Enum.Material.WoodPlanks)
		elseif roll < 0.8 then
			block(f, "Trough", Vector3.new(2, 1.6, 6), CFrame.new(x, 0.8, z), C.WoodDark, Enum.Material.Wood)
			block(f, "TroughWater", Vector3.new(1.6, 0.2, 5.6), CFrame.new(x, 1.5, z), Color3.fromRGB(70, 110, 130), Enum.Material.Glass, { Transparency = 0.3 })
		else
			block(f, "HitchRail", Vector3.new(0.4, 0.4, 7), CFrame.new(x, 2.8, z), C.WoodDark, Enum.Material.Wood)
			block(f, "HitchPost", Vector3.new(0.4, 3, 0.4), CFrame.new(x, 1.5, z - 3.3), C.WoodDark, Enum.Material.Wood)
			block(f, "HitchPost", Vector3.new(0.4, 3, 0.4), CFrame.new(x, 1.5, z + 3.3), C.WoodDark, Enum.Material.Wood)
		end
	end
	for i = 0, 4 do
		for _, side in ipairs({ -1, 1 }) do
			local x, z = streetX + side * 14, 60 - i * 34
			block(f, "LampPost", Vector3.new(0.4, 10, 0.4), CFrame.new(x, 5, z), Color3.fromRGB(40, 40, 40), Enum.Material.Metal)
			local lamp = block(f, "Lamp", Vector3.new(1, 1.4, 1), CFrame.new(x, 10.4, z), Color3.fromRGB(255, 220, 150), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Range = 16
			light.Brightness = 0.8
			light.Color = Color3.fromRGB(255, 200, 130)
			light.Parent = lamp
		end
	end
end

local function buildHeadquarters()
	local f = folder("RaceHeadquarters")
	local base = CFrame.new(260, 18, -270)
	local function at(cf)
		return base * cf
	end
	block(f, "Foundation", Vector3.new(96, 24, 36), at(CFrame.new(0, -12, 0)), Color3.fromRGB(150, 140, 120), Enum.Material.Cobblestone)
	block(f, "Main", Vector3.new(90, 22, 30), at(CFrame.new(0, 11, 0)), C.Brick, Enum.Material.Brick)
	block(f, "Roof", Vector3.new(92, 3, 32), at(CFrame.new(0, 23.5, 0)), C.Roof, Enum.Material.Slate)
	for _, y in ipairs({ 6, 16 }) do
		windowRow(f, at(CFrame.new(0, y, 15.1)), 11, 7.6, Vector3.new(2.6, 5, 0.3))
	end
	for _, x in ipairs({ -36, 0, 36 }) do
		local h = x == 0 and 18 or 12
		block(f, "Tower", Vector3.new(10, h, 10), at(CFrame.new(x, 22 + h / 2, 2)), C.Brick, Enum.Material.Brick)
		block(f, "Spire", Vector3.new(7, 9, 7), at(CFrame.new(x, 22 + h + 3, 2) * CFrame.Angles(0, math.pi / 4, 0)), C.Roof, Enum.Material.Slate)
		block(f, "SpireTip", Vector3.new(3, 6, 3), at(CFrame.new(x, 22 + h + 9, 2) * CFrame.Angles(0, math.pi / 4, 0)), C.Roof, Enum.Material.Slate)
		block(f, "SpirePole", Vector3.new(0.3, 4, 0.3), at(CFrame.new(x, 22 + h + 13.5, 2)), C.WoodDark, Enum.Material.Wood)
		block(f, "SpireFlag", Vector3.new(2.6, 1.6, 0.1), at(CFrame.new(x + 1.4, 22 + h + 14.6, 2)), Color3.fromRGB(110, 190, 120), Enum.Material.Fabric)
	end
	local billboard = block(f, "RaceSign", Vector3.new(40, 16, 1), at(CFrame.new(0, 2, 34)), C.Red, Enum.Material.WoodPlanks)
	sign(billboard, Enum.NormalId.Front, "STEEL BALL RUN\nRACE HEADQUARTERS", Color3.fromRGB(240, 200, 120), nil, Enum.Font.Fondamento)
	for _, x in ipairs({ -16, 16 }) do
		block(f, "SignLeg", Vector3.new(1, 12, 1), at(CFrame.new(x, -6, 34.8)), C.WoodDark, Enum.Material.Wood)
	end
end

local function cactus(parent, x, z)
	local h = rng:NextNumber(7, 14)
	cylinder(parent, "CactusTrunk", h, 1.6, upright(x, h / 2, z), C.Cactus, Enum.Material.Grass)
	local arms = rng:NextInteger(0, 2)
	for i = 1, arms do
		local side = i == 1 and 1 or -1
		local armY = h * rng:NextNumber(0.4, 0.65)
		local armH = rng:NextNumber(2.5, 4.5)
		block(parent, "CactusArm", Vector3.new(2.2, 1.1, 1.1), CFrame.new(x + side * 1.3, armY, z), C.Cactus, Enum.Material.Grass)
		cylinder(parent, "CactusArm", armH, 1.1, upright(x + side * 2.2, armY + armH / 2, z), C.Cactus, Enum.Material.Grass)
	end
end

local function buildDesert()
	local f = folder("Desert")
	for _ = 1, 55 do
		local x, z = rng:NextNumber(-450, 450), rng:NextNumber(-450, 450)
		local nearTrack = math.abs(x) < 130 and z > -330 and z < 160
		local nearTown = x > 170 and x < 350 and z > -320 and z < 130
		if not nearTrack and not nearTown then
			cactus(f, x, z)
		end
	end
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-450, 450), rng:NextNumber(-450, 450)
		if math.abs(x) > 120 then
			local s = rng:NextNumber(2, 4)
			block(f, "Bush", Vector3.new(s, s * 0.7, s), CFrame.new(x, s * 0.25, z), Color3.fromRGB(110, 120, 70), Enum.Material.Grass, { Shape = Enum.PartType.Ball })
		end
	end
	-- Large sandstone blocks.
	for _ = 1, 14 do
		local x, z = rng:NextNumber(-400, 400), rng:NextNumber(-400, 400)
		if math.abs(x) > 140 and not (x > 170 and x < 350) then
			local s = rng:NextNumber(5, 10)
			block(f, "Boulder", Vector3.new(s, s * 0.8, s * 1.1), CFrame.new(x, s * 0.3, z) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6), rng:NextNumber(-0.2, 0.2)), Color3.fromRGB(196, 160, 118), Enum.Material.Sandstone)
		end
	end
end

-- NPC markers: NPCService (runtime) spawns a character at each.
local NPCS = {
	{ "Race Announcer", "Announcer", Vector3.new(-6, 0, 118), 0, "Welcome, riders! The greatest horse race in history starts right here!|Six thousand kilometers of desert, mountains and rivers. Only one can win.|Keep your Spin steady and your eyes on the trail!" },
	{ "Race Official", "Official", Vector3.new(10, 0, 100), 0, "Racers, line up behind the start banner.|No shortcuts through the town, I'm watching you.|Checkpoints are marked with flags. Don't miss one!" },
	{ "Rival Racer", "Racer", Vector3.new(-8, 0, 60), 0, "Think you can keep up? Ha!|I've trained for this race my whole life.|See you at the goal... if you make it." },
	{ "Rookie Racer", "Racer", Vector3.new(8, 0, 20), 0, "My first race! I'm so nervous...|Do you know how to do that spinning thing?|I heard someone can fire their fingernails. Scary!" },
	{ "Camp Cook", "Spectator", Vector3.new(-60, 0, -20), 12, "Beans again tonight, folks.|Eat up, the desert won't wait for you.|Stay away from the cactus juice." },
	{ "Wagon Driver", "Spectator", Vector3.new(70, 0, -80), 14, "These wheels have crossed three states already.|Need a ride? Sorry, wagons are for supplies only.|Dust storm's coming, I can feel it." },
	{ "Sheriff", "Guard", Vector3.new(272, 0, 6), 6, "No fighting on Main Street. Take it outside of town.|I've got my eye on you, stranger.|Strange powers in this race. Strange times." },
	{ "Saloon Owner", "Spectator", Vector3.new(248, 0, 40), 6, "Welcome to the saloon, partner!|Racers drink free... water, that is.|Heard the favourite spins steel balls. Odd fellow." },
	{ "Shopkeeper", "Spectator", Vector3.new(272, 0, 40), 6, "Ropes, canteens, horseshoes, all here.|Prices doubled for the race. Supply and demand!|Come back when you've got more coin." },
	{ "Townsfolk", "Spectator", Vector3.new(260, 0, -40), 30, "The racers came through town at dawn!|My money's on the cowboy with the blue scarf.|Did you see that flash of light out by the church?" },
	{ "Priest", "Spectator", Vector3.new(0, 0, -270), 10, "Peace be with you, traveller.|This mission has stood for a hundred years.|Many racers rest here before the long road." },
	{ "Headquarters Clerk", "Official", Vector3.new(260, 18, -228), 8, "Registration is closed, I'm afraid.|The sponsors are watching every rider closely.|Prize money is fifty million dollars. Can you believe it?" },
}

local function buildNPCMarkers()
	local f = folder("NPCSpawns")
	for _, def in ipairs(NPCS) do
		local marker = block(f, def[1]:gsub(" ", ""), Vector3.new(2, 1, 2), CFrame.new(def[3] + Vector3.new(0, 0.5, 0)), Color3.fromRGB(80, 200, 255), Enum.Material.Neon, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		marker:SetAttribute("DisplayName", def[1])
		marker:SetAttribute("Role", def[2])
		marker:SetAttribute("WanderRadius", def[4])
		marker:SetAttribute("Lines", def[5])
	end
	-- Waypoints racers jog between (along the track).
	local wp = folder("RacerWaypoints")
	for i, z in ipairs({ 100, 0, -100, -200, -100, 0 }) do
		local p = block(wp, "Waypoint" .. i, Vector3.new(1, 1, 1), CFrame.new((i % 2 == 0) and 5 or -5, 0.5, z), Color3.new(1, 1, 1), Enum.Material.Neon, {
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		p:SetAttribute("Order", i)
	end
end

---------------------------------------------------------------------------
function SBRMapBuilder.Build(options)
	options = options or {}
	origin = options.Origin or Vector3.new(0, 0, 0)
	rng = Random.new(options.Seed or 7)

	local old = workspace:FindFirstChild("SBRMap")
	if old then
		old:Destroy()
	end
	root = Instance.new("Model")
	root.Name = "SBRMap"
	root:SetAttribute("Origin", origin)

	if options.Terrain ~= false then
		buildTerrain()
	end
	if options.Lighting ~= false then
		buildLighting()
	end
	buildRaceGrounds()
	buildChurch()
	buildCamp()
	buildTown()
	buildHeadquarters()
	buildDesert()
	buildNPCMarkers()
	root.Parent = workspace

	local count = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			count = count + 1
		end
	end
	print(("[SBRMapBuilder] Built SBRMap with %d parts at %s. Remember File > Save."):format(count, tostring(origin)))
	return root
end

return SBRMapBuilder
]=] },
}

local ROOT_NAMES = { "SpinShared", "SpinServer", "SpinClient", "SpinTools" }

local function service(name)
	if name == "StarterPlayerScripts" then
		return game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
	end
	return game:GetService(name)
end

local function install()
	local ChangeHistoryService = game:GetService("ChangeHistoryService")
	pcall(function()
		ChangeHistoryService:SetWaypoint("Before Spin Battlegrounds install")
	end)

	-- Remove old versions so updates never leave stale scripts behind.
	local roots = {
		{ "ReplicatedStorage", "SpinShared" },
		{ "ServerScriptService", "SpinServer" },
		{ "StarterPlayerScripts", "SpinClient" },
		{ "ServerStorage", "SpinTools" },
	}
	for _, r in ipairs(roots) do
		local old = service(r[1]):FindFirstChild(r[2])
		if old then
			old:Destroy()
		end
	end

	local created = 0
	for _, entry in ipairs(SCRIPTS) do
		local parent = service(entry.Service)
		local parts = string.split(entry.Path, "/")
		for i = 1, #parts - 1 do
			parent = parent:FindFirstChild(parts[i])
			assert(parent, "Installer: missing parent for " .. entry.Path)
		end
		local object = Instance.new(entry.Class)
		object.Name = parts[#parts]
		if entry.Source then
			object.Source = entry.Source
		end
		object.Parent = parent
		created = created + 1
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("Installed Spin Battlegrounds")
	end)
	print(("[Spin Battlegrounds] Installed %d objects. Now build the map (once) and File > Save."):format(created))
	return created
end

local function buildMap()
	local tools = game:GetService("ServerStorage"):FindFirstChild("SpinTools")
	local builder = tools and tools:FindFirstChild("SBRMapBuilder")
	if not builder then
		warn("[Spin Battlegrounds] Install the scripts first.")
		return
	end
	require(builder).Build()
end

if plugin then
	local toolbar = plugin:CreateToolbar("Spin Battlegrounds")
	local installButton = toolbar:CreateButton("Install Scripts", "Create or update every Spin Battlegrounds script", "")
	local mapButton = toolbar:CreateButton("Build Map", "Build the Steel Ball Run map (once)", "")
	installButton.ClickableWhenViewportHidden = true
	mapButton.ClickableWhenViewportHidden = true
	installButton.Click:Connect(function()
		local ok, err = pcall(install)
		if not ok then
			warn("[Spin Battlegrounds] Install failed: " .. tostring(err))
		end
	end)
	mapButton.Click:Connect(function()
		local ok, err = pcall(buildMap)
		if not ok then
			warn("[Spin Battlegrounds] Map build failed: " .. tostring(err))
		end
	end)
else
	install()
end
