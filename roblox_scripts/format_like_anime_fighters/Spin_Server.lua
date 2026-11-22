--[[
	Spin_Server  (Script)
	PUT IT IN: ServerScriptService

	Spin Battlegrounds server: Golden Spin, Tusk Act 1, Tusk Sneak, combat,
	cooldowns, projectiles, NPCs, Studio practice dummies, and the SBR map
	(built automatically when the server starts).

	Needs these ModuleScripts in ReplicatedStorage: SpinConfig, TuskConfig.
	Works with the LocalScript Spin_Client in StarterPlayerScripts.

	MAP SETTINGS (change here):
]]
local BUILD_MAP_ON_START = true -- false = don't build the SBR map
local MAP_ORIGIN = Vector3.new(0, 0, 0) -- move the map away from an existing one, e.g. Vector3.new(1500, 0, 0)

local __modules = {}
local __loaded = {}
local function __hasModule(name)
	return __modules[name] ~= nil
end
local function __require(name)
	local value = __loaded[name]
	if value == nil then
		local loader = __modules[name]
		assert(loader, "[Spin] missing bundled module: " .. tostring(name))
		value = loader()
		__loaded[name] = value
	end
	return value
end

-- ======================================================================
-- MODULE: CombatAdapter
-- ======================================================================
__modules["CombatAdapter"] = function()
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

local Net = __require("Net")
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
end

-- ======================================================================
-- MODULE: CooldownService
-- ======================================================================
__modules["CooldownService"] = function()
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
end

-- ======================================================================
-- MODULE: Maid
-- ======================================================================
__modules["Maid"] = function()
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
end

-- ======================================================================
-- MODULE: NPCService
-- ======================================================================
__modules["NPCService"] = function()
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

local Net = __require("Net")

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
end

-- ======================================================================
-- MODULE: NailModel
-- ======================================================================
__modules["NailModel"] = function()
--[[
	NailModel  (ReplicatedStorage.SpinShared.NailModel)

	Procedural fingernail-bullet used by every Tusk nail attack: a metal
	shaft, a flat head at the back and a tapered tip at the front.
	The nail points down its Core's LookVector (-Z).

	NailModel.build(length) -> Model (PrimaryPart = "Core")
	  Core attachments: "Tip" (front), "Tail" (back), "Center".
]]

local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

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
end

-- ======================================================================
-- MODULE: Net
-- ======================================================================
__modules["Net"] = function()
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
end

-- ======================================================================
-- MODULE: ProjectileService
-- ======================================================================
__modules["ProjectileService"] = function()
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

local Net = __require("Net")
local Adapter = __require("CombatAdapter")

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
end

-- ======================================================================
-- MODULE: SBRMapBuilder
-- ======================================================================
__modules["SBRMapBuilder"] = function()
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
end

-- ======================================================================
-- MODULE: SpinService
-- ======================================================================
__modules["SpinService"] = function()
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

local Shared = nil -- (bundled: modules are inlined)
local SpinConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("SpinConfig"))
local Net = __require("Net")
local Adapter = __require("CombatAdapter")
local Cooldowns = __require("CooldownService")
local Projectiles = __require("ProjectileService")

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
end

-- ======================================================================
-- MODULE: SteelBallModel
-- ======================================================================
__modules["SteelBallModel"] = function()
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

local SpinConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("SpinConfig"))

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
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
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
end

-- ======================================================================
-- MODULE: TestDummies
-- ======================================================================
__modules["TestDummies"] = function()
--[[
	TestDummies  (ServerScriptService.SpinServer.TestDummies)
	Studio-only practice targets so Spin can be tested solo.
	Never runs in a live server (guarded by RunService:IsStudio()).
	Turn off with SpinConfig.Debug.SpawnTestDummies = false.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SpinConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("SpinConfig"))

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
end

-- ======================================================================
-- MODULE: TuskAct1
-- ======================================================================
__modules["TuskAct1"] = function()
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

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

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
end

-- ======================================================================
-- MODULE: TuskActRegistry
-- ======================================================================
__modules["TuskActRegistry"] = function()
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
end

-- ======================================================================
-- MODULE: TuskHitbox
-- ======================================================================
__modules["TuskHitbox"] = function()
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
end

-- ======================================================================
-- MODULE: TuskService
-- ======================================================================
__modules["TuskService"] = function()
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

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Registry = __require("TuskActRegistry")
local Net = __require("Net")
local Adapter = __require("CombatAdapter")
local Cooldowns = __require("CooldownService")
local Projectiles = __require("ProjectileService")
local Hitbox = __require("TuskHitbox")

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
	for act in pairs(Registry.Acts) do
		if Registry.isImplemented(act) and __hasModule("TuskAct" .. act) then
			actModules[act] = __require("TuskAct" .. act)
		end
	end
	Sneak = __require("TuskSneakService")
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
end

-- ======================================================================
-- MODULE: TuskSneakService
-- ======================================================================
__modules["TuskSneakService"] = function()
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

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Adapter = __require("CombatAdapter")
local Cooldowns = __require("CooldownService")
local Hitbox = __require("TuskHitbox")

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
end

-- ======================================================================
-- MODULE: TuskStandModels
-- ======================================================================
__modules["TuskStandModels"] = function()
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

local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

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
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
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
end

-- ======================================================================
-- MODULE: VFXQuality
-- ======================================================================
__modules["VFXQuality"] = function()
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
end

-- ======================================================================
-- MODULE: WreckingBallModel
-- ======================================================================
__modules["WreckingBallModel"] = function()
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
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
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
end

-- ======================================================================
-- START
-- ======================================================================
local ProjectileService = __require("ProjectileService")
local SpinService = __require("SpinService")
local TuskService = __require("TuskService")
local NPCService = __require("NPCService")
local TestDummies = __require("TestDummies")

ProjectileService.MaxActivePerPlayer = 12
SpinService.init()
TuskService.init()
if BUILD_MAP_ON_START and not workspace:FindFirstChild("SBRMap") then
	local ok, err = pcall(function()
		__require("SBRMapBuilder").Build({ Origin = MAP_ORIGIN })
	end)
	if not ok then
		warn("[Spin] Map build failed: " .. tostring(err))
	end
end
NPCService.init()
TestDummies.init()
print("[Spin] Server ready")
