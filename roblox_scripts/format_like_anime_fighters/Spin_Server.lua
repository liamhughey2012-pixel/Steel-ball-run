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
	if p.OnEnd then
		local ok, err = pcall(p.OnEnd, position, normal or Vector3.new(0, 1, 0), hitCharacter, p)
		if not ok then
			warn("[ProjectileService] OnEnd error:", err)
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
		OnEnd = spec.OnEnd, -- function(position, normal, hitCharacter, projectile): always called once
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
			p.OnEnd = nil
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

---------------------------------------------------------------------------
-- MAP UPGRADE: props
---------------------------------------------------------------------------
local CollectionService = game:GetService("CollectionService")

local function model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function ellipsoid(parent, name, size, cf, color, material)
	local p = block(parent, name, size, cf, color, material or Enum.Material.SmoothPlastic)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function small(p)
	p.CastShadow = false
	return p
end

local HORSE_COATS = {
	Color3.fromRGB(110, 70, 40), Color3.fromRGB(60, 40, 30), Color3.fromRGB(200, 190, 175),
	Color3.fromRGB(150, 100, 60), Color3.fromRGB(35, 30, 30), Color3.fromRGB(170, 120, 80),
}

-- A standing horse (about 6 studs tall) with saddle and blanket.
local function horse(parent, cf, coat)
	local m = model(parent, "Horse")
	local mane = Color3.fromRGB(40, 28, 20)
	local function at(offset)
		return cf * offset
	end
	ellipsoid(m, "Body", Vector3.new(2.4, 2.4, 5), at(CFrame.new(0, 4, 0)), coat)
	ellipsoid(m, "Chest", Vector3.new(2.2, 2.4, 2.2), at(CFrame.new(0, 4.1, -1.9)), coat)
	block(m, "Neck", Vector3.new(1.1, 2.8, 1.4), at(CFrame.new(0, 5.6, -2.7) * CFrame.Angles(-0.55, 0, 0)), coat)
	ellipsoid(m, "Head", Vector3.new(1.1, 1.2, 2.4), at(CFrame.new(0, 6.6, -3.9) * CFrame.Angles(0.5, 0, 0)), coat)
	ellipsoid(m, "Muzzle", Vector3.new(0.9, 0.8, 0.9), at(CFrame.new(0, 6.0, -4.8)), coat:Lerp(Color3.new(0, 0, 0), 0.25))
	for _, side in ipairs({ -1, 1 }) do
		small(block(m, "Ear", Vector3.new(0.2, 0.5, 0.2), at(CFrame.new(side * 0.3, 7.5, -3.4)), coat))
		small(ellipsoid(m, "Eye", Vector3.new(0.15, 0.2, 0.2), at(CFrame.new(side * 0.52, 6.9, -4.1)), Color3.new(0.05, 0.05, 0.05)))
	end
	small(block(m, "Mane", Vector3.new(0.3, 2.8, 0.5), at(CFrame.new(0, 6.0, -2.4) * CFrame.Angles(-0.55, 0, 0)), mane))
	ellipsoid(m, "Tail", Vector3.new(0.5, 2.6, 0.6), at(CFrame.new(0, 3.6, 2.7) * CFrame.Angles(0.35, 0, 0)), mane)
	for _, x in ipairs({ -0.7, 0.7 }) do
		for _, z in ipairs({ -1.8, 1.8 }) do
			local leg = block(m, "Leg", Vector3.new(0.5, 3.2, 0.55), at(CFrame.new(x, 1.6, z)), coat)
			small(block(m, "Hoof", Vector3.new(0.6, 0.35, 0.65), at(CFrame.new(x, 0.18, z)), Color3.fromRGB(30, 25, 20)))
			leg.CastShadow = true
		end
	end
	block(m, "Saddle", Vector3.new(1.6, 0.4, 1.8), at(CFrame.new(0, 5.3, -0.3)), Color3.fromRGB(90, 50, 25), Enum.Material.Leather)
	block(m, "Blanket", Vector3.new(2.6, 0.15, 2.2), at(CFrame.new(0, 5.15, -0.3)), Color3.fromRGB(170, 40, 40), Enum.Material.Fabric)
	return m
end

local function hayBale(parent, x, z, yaw)
	local p = block(parent, "HayBale", Vector3.new(3, 2.4, 2.4), CFrame.new(x, 1.2, z) * CFrame.Angles(0, yaw or 0, 0), Color3.fromRGB(214, 180, 90), Enum.Material.Grass, { Shape = Enum.PartType.Cylinder })
	return p
end

local function stables(parent, x, z, yaw)
	local m = model(parent, "Stables")
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local function at(offset)
		return base * offset
	end
	block(m, "Floor", Vector3.new(30, 0.4, 12), at(CFrame.new(0, 0.2, 0)), C.WoodLight, Enum.Material.WoodPlanks)
	block(m, "BackWall", Vector3.new(30, 9, 0.6), at(CFrame.new(0, 4.5, 6)), C.Wood, Enum.Material.WoodPlanks)
	block(m, "Roof", Vector3.new(32, 0.6, 14), at(CFrame.new(0, 9.4, 0) * CFrame.Angles(0.18, 0, 0)), C.Roof, Enum.Material.WoodPlanks)
	for i = 0, 4 do
		local px = -15 + i * 7.5
		block(m, "Post", Vector3.new(0.6, 9, 0.6), at(CFrame.new(px, 4.5, -6)), C.WoodDark, Enum.Material.Wood)
		block(m, "Divider", Vector3.new(0.4, 4, 10), at(CFrame.new(px, 2.2, 0.5)), C.Wood, Enum.Material.WoodPlanks)
	end
	local sign1 = block(m, "Sign", Vector3.new(10, 2, 0.3), at(CFrame.new(0, 10.4, -6.4)), C.WoodDark, Enum.Material.Wood)
	sign(sign1, Enum.NormalId.Front, "RACE STABLES", Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	for i = 0, 3 do
		horse(m, at(CFrame.new(-11.25 + i * 7.5, 0.4, 0.5) * CFrame.Angles(0, math.pi, 0)), HORSE_COATS[i % #HORSE_COATS + 1])
	end
	local hay = at(CFrame.new(18, 0, -2))
	hayBale(m, hay.X, hay.Z, 0.3)
	return m
end

-- Rope between two points with small hanging pieces (pennants or light bulbs).
local function hangingLine(parent, a, b, count, kind)
	local m = model(parent, kind == "lights" and "StringLights" or "Pennants")
	local sag = (b - a).Magnitude * 0.06
	local function pointAt(t)
		return a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * sag, 0)
	end
	local anchorA = small(block(m, "RopeA", Vector3.new(0.2, 0.2, 0.2), CFrame.new(a), Color3.new(0, 0, 0), nil, { Transparency = 1, CanCollide = false }))
	local anchorB = small(block(m, "RopeB", Vector3.new(0.2, 0.2, 0.2), CFrame.new(b), Color3.new(0, 0, 0), nil, { Transparency = 1, CanCollide = false }))
	-- block() already offsets by origin; the attachments sit at the parts' centres.
	local a0 = Instance.new("Attachment")
	a0.Parent = anchorA
	local a1 = Instance.new("Attachment")
	a1.Parent = anchorB
	local rope = Instance.new("Beam")
	rope.Attachment0 = a0
	rope.Attachment1 = a1
	rope.Width0 = 0.08
	rope.Width1 = 0.08
	rope.Color = ColorSequence.new(Color3.fromRGB(50, 40, 30))
	rope.CurveSize0 = -sag * 1.3
	rope.CurveSize1 = sag * 1.3
	rope.Parent = anchorA
	for i = 1, count do
		local t = i / (count + 1)
		local p = pointAt(t)
		if kind == "lights" then
			local bulb = small(block(m, "Bulb", Vector3.new(0.45, 0.6, 0.45), CFrame.new(p - Vector3.new(0, 0.35, 0)), Color3.fromRGB(255, 215, 140), Enum.Material.Neon, { Shape = Enum.PartType.Ball, CanCollide = false }))
			if i % 3 == 0 then
				local light = Instance.new("PointLight")
				light.Range = 10
				light.Brightness = 0.6
				light.Color = Color3.fromRGB(255, 200, 130)
				light.Parent = bulb
			end
		else
			local palette = FLAG_PALETTES[(i % #FLAG_PALETTES) + 1]
			local dir = (b - a).Unit
			small(block(m, "Pennant", Vector3.new(0.05, 1.2, 1.2), CFrame.lookAt(p, p + dir) * CFrame.new(0, -0.6, 0) * CFrame.Angles(math.pi / 4, 0, 0), palette[1], Enum.Material.Fabric, { CanCollide = false }))
		end
	end
	return m
end

local function palm(parent, x, z)
	local m = model(parent, "PalmTree")
	local lean = rng:NextNumber(-0.25, 0.25)
	local y, px = 0, x
	local segments = 6
	for i = 1, segments do
		local h = 2.6
		cylinder(m, "Trunk", h, 1.3 - i * 0.08, CFrame.new(px, y + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2 + lean), Color3.fromRGB(130, 100, 70), Enum.Material.Wood)
		y = y + h * 0.97
		px = px - math.sin(lean) * h
	end
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		local leaf = small(block(m, "Leaf", Vector3.new(1.2, 0.15, 7), CFrame.new(px, y + 0.4, z) * CFrame.Angles(0, angle, 0) * CFrame.Angles(0.45, 0, 0) * CFrame.new(0, 0, -3.3), Color3.fromRGB(70, 130, 50), Enum.Material.Grass))
		leaf.CastShadow = true
	end
	for i = 1, 3 do
		small(block(m, "Coconut", Vector3.new(0.8, 0.8, 0.8), CFrame.new(px + math.cos(i * 2) * 0.6, y - 0.3, z + math.sin(i * 2) * 0.6), Color3.fromRGB(90, 60, 30), Enum.Material.Wood, { Shape = Enum.PartType.Ball }))
	end
end

local function deadTree(parent, x, z)
	local m = model(parent, "DeadTree")
	local h = rng:NextNumber(6, 11)
	local bark = Color3.fromRGB(95, 75, 60)
	cylinder(m, "Trunk", h, 0.9, upright(x, h / 2, z), bark, Enum.Material.Wood)
	for i = 1, 4 do
		local y = h * rng:NextNumber(0.45, 0.95)
		local yaw = rng:NextNumber(0, math.pi * 2)
		local len = rng:NextNumber(2.5, 4.5)
		small(block(m, "Branch", Vector3.new(0.35, 0.35, len), CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0.7, 0, 0) * CFrame.new(0, 0, -len / 2), bark, Enum.Material.Wood))
	end
end

local function skull(parent, x, z)
	local m = model(parent, "CattleSkull")
	local bone = Color3.fromRGB(235, 228, 210)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local base = CFrame.new(x, 0.4, z) * CFrame.Angles(0, yaw, 0)
	small(block(m, "Skull", Vector3.new(1, 0.7, 1.6), base, bone))
	small(block(m, "HornL", Vector3.new(1.6, 0.25, 0.25), base * CFrame.new(-1, 0.2, -0.3) * CFrame.Angles(0, 0, 0.4), bone))
	small(block(m, "HornR", Vector3.new(1.6, 0.25, 0.25), base * CFrame.new(1, 0.2, -0.3) * CFrame.Angles(0, 0, -0.4), bone))
end

local function waterTower(parent, x, z)
	local m = model(parent, "WaterTower")
	for _, dx in ipairs({ -3, 3 }) do
		for _, dz in ipairs({ -3, 3 }) do
			block(m, "Leg", Vector3.new(0.8, 18, 0.8), CFrame.new(x + dx, 9, z + dz) * CFrame.Angles(dz * 0.015, 0, -dx * 0.015), C.WoodDark, Enum.Material.Wood)
		end
	end
	block(m, "Brace", Vector3.new(8.5, 0.4, 0.4), CFrame.new(x, 8, z - 3), C.WoodDark, Enum.Material.Wood)
	block(m, "Brace", Vector3.new(8.5, 0.4, 0.4), CFrame.new(x, 8, z + 3), C.WoodDark, Enum.Material.Wood)
	cylinder(m, "Tank", 9, 10, upright(x, 22.5, z), C.Wood, Enum.Material.WoodPlanks)
	for _, y in ipairs({ 19.5, 25.5 }) do
		cylinder(m, "Band", 0.4, 10.2, upright(x, y, z), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
	end
	block(m, "Roof", Vector3.new(11, 4, 11), CFrame.new(x, 28.5, z), C.Roof, Enum.Material.WoodPlanks, { Shape = Enum.PartType.Ball })
	small(block(m, "Spout", Vector3.new(0.6, 0.6, 5), CFrame.new(x, 18.5, z - 6) * CFrame.Angles(0.4, 0, 0), Color3.fromRGB(60, 60, 65), Enum.Material.Metal))
end

-- Windmill: the rotor hub is tagged "SpinWindmill"; clients spin it.
local function windmill(parent, x, z)
	local m = model(parent, "Windmill")
	local h = 24
	for _, d in ipairs({ { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } }) do
		block(m, "Leg", Vector3.new(0.5, h, 0.5), CFrame.new(x + d[1] * 0.75, h / 2, z + d[2] * 0.75) * CFrame.Angles(d[2] * 0.06, 0, -d[1] * 0.06), Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
	end
	for y = 4, h - 2, 5 do
		block(m, "Rung", Vector3.new(3.4 - y * 0.06, 0.3, 0.3), CFrame.new(x, y, z - 1.6 + y * 0.03), Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
	end
	local hub = block(m, "Hub", Vector3.new(1.4, 1.4, 1.4), CFrame.new(x, h + 1, z - 1.5), Color3.fromRGB(70, 70, 75), Enum.Material.Metal, { Shape = Enum.PartType.Ball })
	CollectionService:AddTag(hub, "SpinWindmill")
	for i = 1, 12 do
		local blade = block(m, "Blade", Vector3.new(0.9, 4.5, 0.1), CFrame.new(), Color3.fromRGB(200, 195, 185), Enum.Material.Metal)
		-- hub.CFrame is already in world space, so set the blade directly.
		blade.CFrame = hub.CFrame * CFrame.Angles(0, 0, i / 12 * math.pi * 2) * CFrame.new(0, 3, -0.3) * CFrame.Angles(0, 0.35, 0)
		blade.Anchored = false
		blade.CastShadow = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = hub
		w.Part1 = blade
		w.Parent = blade
	end
	local vane = block(m, "Vane", Vector3.new(0.1, 3, 5), CFrame.new(x, h + 1, z + 2), Color3.fromRGB(200, 60, 50), Enum.Material.Metal)
	vane.CastShadow = false
end

local function telegraphLine(parent, points)
	local m = model(parent, "TelegraphLine")
	local tops = {}
	for i, p in ipairs(points) do
		cylinder(m, "Pole", 16, 0.6, upright(p.X, 8, p.Z), C.WoodDark, Enum.Material.Wood)
		local bar = block(m, "Crossbar", Vector3.new(4, 0.4, 0.4), CFrame.new(p.X, 15, p.Z), C.WoodDark, Enum.Material.Wood)
		tops[i] = bar
	end
	for i = 1, #tops - 1 do
		for _, side in ipairs({ -1.6, 1.6 }) do
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(side, 0.3, 0)
			a0.Parent = tops[i]
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(side, 0.3, 0)
			a1.Parent = tops[i + 1]
			local wire = Instance.new("Beam")
			wire.Attachment0 = a0
			wire.Attachment1 = a1
			wire.Width0 = 0.06
			wire.Width1 = 0.06
			wire.Color = ColorSequence.new(Color3.fromRGB(30, 30, 30))
			wire.CurveSize0 = -1.5
			wire.CurveSize1 = 1.5
			wire.Parent = tops[i]
		end
	end
end

local function railway(parent, x, z0, z1)
	local m = model(parent, "Railway")
	local length = z1 - z0
	for _, dx in ipairs({ -2.4, 2.4 }) do
		local segments = math.ceil(length / 200)
		for i = 0, segments - 1 do
			local a = z0 + i * 200
			local b = math.min(z1, a + 200)
			block(m, "Rail", Vector3.new(0.3, 0.4, b - a), CFrame.new(x + dx, 0.6, (a + b) / 2), Color3.fromRGB(80, 75, 70), Enum.Material.Metal)
		end
	end
	for z = z0, z1, 4 do
		small(block(m, "Sleeper", Vector3.new(7, 0.35, 1), CFrame.new(x, 0.25, z), Color3.fromRGB(85, 60, 40), Enum.Material.Wood))
	end
end

local function locomotive(parent, x, z)
	local m = model(parent, "SteamTrain")
	local black = Color3.fromRGB(30, 30, 34)
	local red = Color3.fromRGB(150, 30, 30)
	local function at(dz, y)
		return CFrame.new(x, y, z + dz)
	end
	block(m, "Frame", Vector3.new(6, 1, 26), at(0, 2.2), black, Enum.Material.Metal)
	block(m, "Boiler", Vector3.new(16, 5, 5), at(-4, 5.2) * CFrame.Angles(0, math.pi / 2, 0), black, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	block(m, "SmokeBox", Vector3.new(1, 5.4, 5.4), at(-12.2, 5.2) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(50, 50, 55), Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	local stack = cylinder(m, "Smokestack", 4, 1.8, CFrame.new(x, 9.4, z - 10.5) * CFrame.Angles(0, 0, math.pi / 2), black, Enum.Material.Metal)
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(200, 200, 200)
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 6
	smoke.Size = 3
	smoke.Parent = stack
	block(m, "Dome", Vector3.new(2, 2, 2), at(-4, 8), Color3.fromRGB(190, 150, 60), Enum.Material.Metal, { Shape = Enum.PartType.Ball })
	block(m, "Cab", Vector3.new(6, 6, 6), at(7, 6), red, Enum.Material.WoodPlanks)
	block(m, "CabRoof", Vector3.new(7, 0.5, 7), at(7, 9.2), black, Enum.Material.Metal)
	windowRow(m, at(7, 6.5) * CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, -3.05), 1, 0, Vector3.new(2.5, 2, 0.2))
	block(m, "Cowcatcher", Vector3.new(5.5, 2, 3), at(-14, 1.6) * CFrame.Angles(0.5, 0, 0), red, Enum.Material.Metal)
	local lamp = small(block(m, "Headlamp", Vector3.new(1.2, 1.2, 1), at(-12.9, 7), Color3.fromRGB(255, 240, 190), Enum.Material.Neon))
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Range = 40
	light.Brightness = 2
	light.Parent = lamp
	for _, dz in ipairs({ -9, -5, -1, 3 }) do
		for _, dx in ipairs({ -3.1, 3.1 }) do
			local d = dz > -6 and 4 or 2.6
			block(m, "Wheel", Vector3.new(0.5, d, d), at(dz, d / 2 + 0.6) * CFrame.new(dx, 0, 0), red, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
		end
	end
	-- Two passenger coaches.
	for i = 1, 2 do
		local cz = 13 + i * 18
		block(m, "Coach", Vector3.new(6, 6, 16), at(cz, 5), Color3.fromRGB(110, 60, 40), Enum.Material.WoodPlanks)
		block(m, "CoachRoof", Vector3.new(6.6, 0.8, 16.6), at(cz, 8.4), Color3.fromRGB(60, 55, 50), Enum.Material.Metal)
		windowRow(m, at(cz, 5.8) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, -3.05), 5, 3, Vector3.new(1.8, 1.8, 0.2))
		windowRow(m, at(cz, 5.8) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(0, 0, -3.05), 5, 3, Vector3.new(1.8, 1.8, 0.2))
		for _, wz in ipairs({ -5, 5 }) do
			for _, dx in ipairs({ -3.1, 3.1 }) do
				block(m, "Wheel", Vector3.new(0.5, 2.4, 2.4), at(cz + wz, 1.8) * CFrame.new(dx, 0, 0), black, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
			end
		end
	end
end

local function station(parent, x, z)
	local m = model(parent, "TrainStation")
	block(m, "Platform", Vector3.new(10, 1.6, 60), CFrame.new(x, 0.8, z), Color3.fromRGB(150, 130, 105), Enum.Material.WoodPlanks)
	block(m, "Building", Vector3.new(14, 11, 24), CFrame.new(x - 12, 5.5, z), Color3.fromRGB(170, 120, 80), Enum.Material.WoodPlanks)
	block(m, "Roof", Vector3.new(16, 1, 26), CFrame.new(x - 12, 11.5, z) * CFrame.Angles(0, 0, 0.12), C.Roof, Enum.Material.WoodPlanks)
	local board = block(m, "StationSign", Vector3.new(0.4, 3, 16), CFrame.new(x - 4.8, 8.5, z), C.WoodDark, Enum.Material.Wood)
	sign(board, Enum.NormalId.Right, "DESERT JUNCTION", Color3.fromRGB(245, 225, 175), nil, Enum.Font.Fondamento)
	windowRow(m, CFrame.new(x - 4.95, 4.5, z) * CFrame.Angles(0, math.pi / 2, 0), 4, 5, Vector3.new(2.2, 3.2, 0.2))
	block(m, "Canopy", Vector3.new(10, 0.5, 50), CFrame.new(x, 10, z) * CFrame.Angles(0, 0, -0.08), Color3.fromRGB(120, 40, 40), Enum.Material.WoodPlanks)
	for dz = -22, 22, 11 do
		block(m, "CanopyPost", Vector3.new(0.5, 8.6, 0.5), CFrame.new(x + 4, 5.9, z + dz), C.WoodDark, Enum.Material.Wood)
		small(block(m, "Bench", Vector3.new(1.4, 0.4, 5), CFrame.new(x - 3, 2.4, z + dz + 5), C.WoodLight, Enum.Material.WoodPlanks))
	end
	small(block(m, "Clock", Vector3.new(0.3, 2.4, 2.4), CFrame.new(x - 4.7, 12.5, z), Color3.fromRGB(240, 235, 220), nil, { Shape = Enum.PartType.Cylinder }))
end

local function mine(parent, center)
	local m = model(parent, "OldMine")
	local dir = Vector3.new(-center.X, 0, -center.Z).Unit
	local entrance = center + dir * 58
	-- Faces back into the hill: the tunnel opening is on the local +Z side.
	local base = CFrame.lookAt(Vector3.new(entrance.X, 0, entrance.Z), Vector3.new(entrance.X, 0, entrance.Z) + dir)
	local function at(offset)
		return base * offset
	end
	block(m, "TunnelDark", Vector3.new(10, 10, 6), at(CFrame.new(0, 5, 3)), Color3.fromRGB(10, 8, 6), Enum.Material.SmoothPlastic)
	for _, x in ipairs({ -5.5, 5.5 }) do
		block(m, "Timber", Vector3.new(1.2, 12, 1.2), at(CFrame.new(x, 6, 0)), C.WoodDark, Enum.Material.Wood)
	end
	block(m, "Lintel", Vector3.new(13, 1.4, 1.4), at(CFrame.new(0, 12, 0)), C.WoodDark, Enum.Material.Wood)
	local board = block(m, "MineSign", Vector3.new(8, 2, 0.3), at(CFrame.new(0, 14, -0.4)), C.Wood, Enum.Material.Wood)
	sign(board, Enum.NormalId.Front, "SILVER MINE · KEEP OUT", Color3.fromRGB(240, 220, 170), nil, Enum.Font.Fondamento)
	for _, x in ipairs({ -1.6, 1.6 }) do
		block(m, "MineRail", Vector3.new(0.3, 0.3, 26), at(CFrame.new(x, 0.4, -10)), Color3.fromRGB(80, 75, 70), Enum.Material.Metal)
	end
	for zz = 0, 22, 3 do
		small(block(m, "Sleeper", Vector3.new(4.6, 0.3, 0.8), at(CFrame.new(0, 0.2, -zz)), Color3.fromRGB(85, 60, 40), Enum.Material.Wood))
	end
	block(m, "OreCart", Vector3.new(3.6, 2.4, 4.4), at(CFrame.new(0, 2.1, -9)), Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
	for i = 1, 5 do
		small(block(m, "Ore", Vector3.new(1.1, 1.1, 1.1), at(CFrame.new(rng:NextNumber(-1, 1), 3.4, -9 + rng:NextNumber(-1.4, 1.4))), Color3.fromRGB(160, 165, 175), Enum.Material.Slate, { Shape = Enum.PartType.Ball }))
	end
	for _, x in ipairs({ -5.5, 5.5 }) do
		local lantern = small(block(m, "Lantern", Vector3.new(0.7, 1, 0.7), at(CFrame.new(x, 9, -0.9)), Color3.fromRGB(255, 190, 100), Enum.Material.Neon))
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 180, 90)
		light.Range = 14
		light.Brightness = 1.2
		light.Parent = lantern
	end
end

local function rockArch(parent, x, z)
	local m = model(parent, "RockArch")
	local stone = Color3.fromRGB(190, 120, 80)
	block(m, "PillarL", Vector3.new(8, 26, 9), CFrame.new(x - 14, 13, z) * CFrame.Angles(0, 0, 0.08), stone, Enum.Material.Sandstone)
	block(m, "PillarR", Vector3.new(8, 24, 9), CFrame.new(x + 14, 12, z) * CFrame.Angles(0, 0, -0.08), stone, Enum.Material.Sandstone)
	block(m, "Span", Vector3.new(38, 7, 8), CFrame.new(x, 27, z) * CFrame.Angles(0, 0, 0.03), stone, Enum.Material.Sandstone)
end

local function well(parent, x, z)
	local m = model(parent, "Well")
	cylinder(m, "WellRing", 3, 5, upright(x, 1.5, z), Color3.fromRGB(150, 140, 125), Enum.Material.Cobblestone)
	cylinder(m, "WellWater", 0.2, 4.2, upright(x, 2.5, z), Color3.fromRGB(60, 100, 120), Enum.Material.Glass)
	for _, dx in ipairs({ -2.2, 2.2 }) do
		block(m, "Post", Vector3.new(0.5, 6, 0.5), CFrame.new(x + dx, 4, z), C.WoodDark, Enum.Material.Wood)
	end
	block(m, "Roof", Vector3.new(6, 0.5, 4), CFrame.new(x, 7.2, z), C.Roof, Enum.Material.WoodPlanks)
	small(block(m, "Bucket", Vector3.new(0.9, 0.9, 0.9), CFrame.new(x, 4.5, z), C.Wood, Enum.Material.Wood))
end

local function wantedBoard(parent, x, z, yaw)
	local m = model(parent, "WantedBoard")
	local board = block(m, "Board", Vector3.new(6, 4, 0.3), CFrame.new(x, 4, z) * CFrame.Angles(0, yaw, 0), C.Wood, Enum.Material.WoodPlanks)
	for _, dx in ipairs({ -2.6, 2.6 }) do
		block(m, "Leg", Vector3.new(0.4, 6, 0.4), CFrame.new(x, 3, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(dx, 0, 0.3), C.WoodDark, Enum.Material.Wood)
	end
	for i, text in ipairs({ "WANTED\nGYRO", "WANTED\nDIO", "REWARD\n$5000" }) do
		local poster = small(block(m, "Poster", Vector3.new(1.6, 2.2, 0.05), CFrame.new(x, 4.1, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(-2 + (i - 1) * 2, 0, -0.18), Color3.fromRGB(230, 210, 170), Enum.Material.Fabric))
		sign(poster, Enum.NormalId.Front, text, Color3.fromRGB(60, 30, 15), nil, Enum.Font.Fondamento)
	end
end

local function boardwalk(parent, x, z0, z1)
	block(parent, "Boardwalk", Vector3.new(5, 0.6, math.abs(z1 - z0)), CFrame.new(x, 0.3, (z0 + z1) / 2), C.WoodLight, Enum.Material.WoodPlanks)
end

local function scoreboard(parent, x, z, yaw)
	local m = model(parent, "Scoreboard")
	local board = block(m, "Board", Vector3.new(20, 10, 0.6), CFrame.new(x, 12, z) * CFrame.Angles(0, yaw, 0), Color3.fromRGB(30, 40, 30), Enum.Material.WoodPlanks)
	sign(board, Enum.NormalId.Front, "STAGE 1 — SAN DIEGO BEACH\n1. ???   2. ???   3. ???\n6,000 KM TO NEW YORK", Color3.fromRGB(240, 235, 200), nil, Enum.Font.Fondamento)
	for _, dx in ipairs({ -8, 8 }) do
		block(m, "Leg", Vector3.new(0.8, 12, 0.8), CFrame.new(x, 6, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(dx, 0, 0.6), C.WoodDark, Enum.Material.Wood)
	end
	block(m, "Trim", Vector3.new(21, 1, 1), CFrame.new(x, 17.4, z) * CFrame.Angles(0, yaw, 0), C.Gold, Enum.Material.Metal)
end

---------------------------------------------------------------------------
-- MAP UPGRADE: sections
---------------------------------------------------------------------------
local function buildLandforms()
	local terrain = workspace.Terrain
	local o = origin
	-- Rolling dunes in the open desert.
	for _ = 1, 45 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(230, 470)
		local p = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local inTown = p.X > 170 and p.X < 470 and p.Z > -340 and p.Z < 140
		if not inTown then
			local r = rng:NextNumber(18, 45)
			terrain:FillBall(o + p - Vector3.new(0, r * 0.78, 0), r, Enum.Material.Sand)
		end
	end
	-- Layered mesas (stratified sandstone and rock).
	local mesas = { Vector3.new(-380, 0, 60), Vector3.new(-300, 0, -250), Vector3.new(120, 0, -430), Vector3.new(-120, 0, 400), Vector3.new(330, 0, 380), Vector3.new(-430, 0, 300) }
	for i, p in ipairs(mesas) do
		local radius = 30 + (i % 3) * 10
		local height = 0
		local layers = { Enum.Material.Sandstone, Enum.Material.Rock, Enum.Material.Sandstone, Enum.Material.Slate }
		for l = 1, 4 do
			local h = rng:NextNumber(10, 16)
			local r = radius * (1 - (l - 1) * 0.12)
			terrain:FillCylinder(CFrame.new(o + p + Vector3.new(0, height + h / 2, 0)), h, r, layers[l])
			height = height + h
		end
	end
	-- Oasis: pond, grass ring, palms.
	local oasis = Vector3.new(-280, 0, 200)
	terrain:FillCylinder(CFrame.new(o + oasis + Vector3.new(0, -0.5, 0)), 2, 34, Enum.Material.Grass)
	terrain:FillCylinder(CFrame.new(o + oasis + Vector3.new(0, -2, 0)), 4, 20, Enum.Material.Water)
	-- Mine hill.
	terrain:FillBall(o + Vector3.new(-360, -30, -380), 70, Enum.Material.Rock)
	-- Roads (hard-packed ground).
	terrain:FillBlock(CFrame.new(o + Vector3.new(350, -0.6, 0)), Vector3.new(180, 1.2, 16), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(o + Vector3.new(-140, -0.6, 150)), Vector3.new(280, 1.2, 14), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(o + Vector3.new(-170, -0.6, -340)) * CFrame.Angles(0, 0.75, 0), Vector3.new(14, 1.2, 240), Enum.Material.Ground)
	return oasis
end

local function buildUpgrades()
	local f = folder("Upgrades")
	local oasis = buildLandforms()

	-- Race grounds: stables, horses, pennants, lights, scoreboard, hay.
	stables(f, -80, 125, -math.pi / 2)
	for i = 0, 3 do
		horse(f, CFrame.new(26 + (i % 2) * 4, 0, 130 - i * 6) * CFrame.Angles(0, math.pi / 2 + rng:NextNumber(-0.3, 0.3), 0), HORSE_COATS[(i + 2) % #HORSE_COATS + 1])
	end
	for i = 0, 10 do
		local z = 120 - i * 32
		hangingLine(f, Vector3.new(-22, 14.5, z), Vector3.new(-22, 14.5, z - 32), 7, "pennants")
		hangingLine(f, Vector3.new(22, 13.5, z - 16), Vector3.new(22, 13.5, z - 48), 8, "lights")
	end
	hangingLine(f, Vector3.new(-16, 21, 110), Vector3.new(16, 21, 110), 10, "lights")
	scoreboard(f, 44, 118, -math.pi / 2)
	for i = 1, 10 do
		hayBale(f, rng:NextNumber(-18, -12) * (i % 2 == 0 and 1 or -1), 100 - i * 30, rng:NextNumber(0, 3))
	end

	-- Town extras: boardwalks, well, wanted board, water tower, windmill.
	boardwalk(f, 260 - 14.5, -110, 60)
	boardwalk(f, 260 + 14.5, -110, 60)
	well(f, 260, -70)
	wantedBoard(f, 248, 80, math.pi / 2)
	waterTower(f, 300, 70)
	windmill(f, 315, 115)

	-- Railway, station and steam train.
	railway(f, 440, -600, 600)
	station(f, 432, 0)
	locomotive(f, 440, -20)
	waterTower(f, 420, 50)

	-- Telegraph line: race start -> town -> station.
	local poles = {}
	for x = 30, 250, 40 do
		table.insert(poles, Vector3.new(x, 0, 92))
	end
	for x = 290, 410, 40 do
		table.insert(poles, Vector3.new(x, 0, -10))
	end
	telegraphLine(f, poles)

	-- Oasis palms, mine, rock arch, desert details.
	for i = 1, 9 do
		local angle = i / 9 * math.pi * 2
		palm(f, oasis.X + math.cos(angle) * rng:NextNumber(23, 30), oasis.Z + math.sin(angle) * rng:NextNumber(23, 30))
	end
	mine(f, Vector3.new(-360, 0, -380))
	rockArch(f, -150, -440)
	for _ = 1, 22 do
		local x, z = rng:NextNumber(-460, 460), rng:NextNumber(-460, 460)
		if math.abs(x) > 140 and not (x > 170 and x < 470) then
			if rng:NextNumber() < 0.5 then
				deadTree(f, x, z)
			else
				skull(f, x, z)
			end
		end
	end
	-- Wrecked wagon out in the desert.
	wagon(f, -200, -120, 0.7)
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
	{ "Stable Hand", "Spectator", Vector3.new(-66, 0, 112), 8, "Easy, easy... these horses are nervous before a race.|A good horse is worth more than gold out here.|Feed them, water them, never rush them." },
	{ "Station Master", "Official", Vector3.new(425, 1.6, 10), 10, "Next train to the east leaves at sundown.|Racers ride horses, not trains. Rules are rules!|The telegraph says the leaders passed Arizona already." },
	{ "Old Miner", "Spectator", Vector3.new(-320, 0, -335), 6, "Silver? Nah, the mine's been empty for years.|I heard strange spinning sounds down there last night.|Don't go in without a lantern." },
	{ "Oasis Traveller", "Spectator", Vector3.new(-262, 0, 178), 10, "Fresh water! First I've seen in two days.|Rest here before you cross the dunes.|The mesas make good landmarks. Don't get lost." },
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
	buildUpgrades()
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
-- MODULE: StandAssetLoader
-- ======================================================================
__modules["StandAssetLoader"] = function()
--[[
	StandAssetLoader  (ServerScriptService.SpinServer.StandAssetLoader)

	Loads the Stand models listed in TuskConfig.StandModels (by asset id)
	into ReplicatedStorage.SpinAssets as "TuskAct1", "TuskAct2"...
	Every client then uses that model instead of the built-in one.

	Safety: every Script, LocalScript and ModuleScript inside a loaded
	model is deleted before anyone can see it (free models sometimes hide
	harmful scripts).

	If Roblox refuses to load an asset (InsertService can only load models
	your account owns, or free models depending on Roblox's rules), the
	Output says so. Then insert the model yourself: Toolbox > search the id
	> drag it into ReplicatedStorage > put it in a Folder named SpinAssets
	> rename it TuskAct1.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local StandAssetLoader = {}

local function assetsFolder()
	local folder = ReplicatedStorage:FindFirstChild("SpinAssets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SpinAssets"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local function sanitize(model)
	local removed = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
			removed = removed + 1
		end
	end
	return removed
end

local function load(act, entry)
	local name = "TuskAct" .. act
	local folder = assetsFolder()
	if folder:FindFirstChild(name) then
		return -- already placed by hand: keep it
	end
	local ok, container = pcall(function()
		return InsertService:LoadAsset(entry.AssetId)
	end)
	if not ok or not container then
		warn(("[Spin] Could not load Stand model %d for Act %d (%s). Insert it by hand: Toolbox > drag into ReplicatedStorage.SpinAssets > rename %s."):format(entry.AssetId, act, tostring(container), name))
		return
	end
	local model = container:FindFirstChildWhichIsA("Model", true) or container
	local removed = sanitize(model)
	model.Name = name
	if not model:IsA("Model") then
		local wrapper = Instance.new("Model")
		for _, child in ipairs(model:GetChildren()) do
			child.Parent = wrapper
		end
		model = wrapper
		model.Name = name
	end
	model.Parent = folder
	container:Destroy()
	print(("[Spin] Loaded Stand model %d as %s%s"):format(entry.AssetId, name, removed > 0 and (" (removed " .. removed .. " scripts for safety)") or ""))
end

function StandAssetLoader.init()
	for act, entry in pairs(TuskConfig.StandModels or {}) do
		if entry.AssetId and entry.AssetId ~= 0 then
			task.spawn(load, act, entry)
		end
	end
end

return StandAssetLoader
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
	  Ultimate  TUSK AWAKENING: armored cinematic burst, then evolves to Act 2
	            (in Menu mode: 20 s Awakened buff instead)

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

		if TuskConfig.Progression.Mode == "Awaken" then
			S.finishUltimate(player, state) -- awakens Tusk to Act 2
			return
		end
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
-- MODULE: TuskAct2
-- ======================================================================
__modules["TuskAct2"] = function()
--[[
	TuskAct2  (ServerScriptService.SpinServer.TuskActs.TuskAct2)

	Tusk Act 2: wormhole combat.
	  M1        DIMENSIONAL COMBO: Tusk-assisted hits, portal flashes, dimensional finisher
	  Ability 1 WORMHOLE NAIL: nail opens a wormhole where it lands; a second nail
	            bursts out of an exit portal behind the nearest enemy
	  Ability 2 UNDERGROUND PURSUIT: burrow, travel under the ground, emerge behind the target
	  Ability 3 NAIL DIMENSION: three portals around the target fire converging nails,
	            then a dimensional shockwave
	  Ultimate  DIMENSIONAL STORM: six portals rain nail waves, giant blue burst,
	            then Tusk evolves to Act 3
	Numbers: TuskConfig.Act2.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")
local Sneak = __require("TuskSneakService")

local Act2 = {}
local cfg = TuskConfig.Act2

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Act2.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 2)
end

local function wormholeNail(S, player, state, aim)
	local c = cfg.WormholeNail
	if not ready(S, player, state, "WormholeNail", 1) then
		return
	end
	S.startCooldown(player, state, "WormholeNail", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.2)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 2, Move = "WormholeNail", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		Moves.nail(S, player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Wormhole",
			Damage = c.Damage,
			Stun = c.Stun,
			Knockback = c.Knockback,
			Source = "TuskWormholeNail",
			OnEnd = function(position, normal)
				-- Entrance wormhole where the nail landed.
				S.fx("Portal", { Act = 2, Position = position + normal * 0.5, LookAt = position + normal * 5, Radius = 2.4, Duration = c.ExitDelay + 0.35 })
				-- Exit portal behind the nearest enemy near the impact.
				local victims = S.Hitbox.inRadius(char, position, c.ExitSearch, 1)
				local victim = victims[1]
				local vr = victim and victim:FindFirstChild("HumanoidRootPart")
				if not vr then
					return
				end
				local exitPos = (vr.CFrame * CFrame.new(0, 1.5, 6)).Position
				if not S.Hitbox.lineOfSight(vr.Position, exitPos, { char, victim }) then
					exitPos = vr.Position + Vector3.new(0, 7, 0)
				end
				S.fx("Portal", { Act = 2, Position = exitPos, LookAt = vr.Position, Radius = 2.2, Duration = c.ExitDelay + 0.45 })
				task.delay(c.ExitDelay, function()
					if state.Life ~= life or not vr.Parent then
						return
					end
					local dir = (vr.Position - exitPos)
					if dir.Magnitude < 0.5 then
						return
					end
					Moves.nail(S, player, state, {
						Origin = exitPos,
						Direction = dir.Unit,
						Speed = c.Speed,
						Radius = c.Radius,
						Range = dir.Magnitude + 6,
						Style = "Wormhole",
						Damage = c.ExitDamage,
						Stun = c.Stun,
						Knockback = c.Knockback,
						Source = "TuskWormholeNail",
					})
				end)
			end,
		})
	end)
end

local function undergroundPursuit(S, player, state, aim)
	local c = cfg.UndergroundPursuit
	if not ready(S, player, state, "UndergroundPursuit", 2) then
		return
	end
	local character, _, root = alive(S, player)
	local target = Moves.findTarget(S, character, root, c.Range, c.ConeDegrees, S.aim(aim, root))
	if not target then
		S.startCooldown(player, state, "UndergroundPursuit", 1.5, 2)
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	S.startCooldown(player, state, "UndergroundPursuit", c.Cooldown, 2)
	Sneak.burrowStrike(player, state, target, {
		Range = c.Range,
		BurrowTime = c.BurrowTime,
		WarningTime = c.WarningTime,
		EmergeDistance = 3.5,
		MaxTargetDrift = 16,
		HitRadius = c.HitRadius,
		Damage = c.Damage,
		Stun = c.Stun,
		Knockback = c.Knockback,
		Launch = c.Launch,
	}, "TuskUndergroundPursuit")
end

-- Portals around a point fire converging nails, then a shockwave.
local function nailDimension(S, player, state, aim)
	local c = cfg.NailDimension
	if not ready(S, player, state, "NailDimension", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local target = Moves.findTarget(S, character, root, c.Range, c.ConeDegrees, direction)
	local center
	if target then
		center = target.HumanoidRootPart.Position
	else
		center = Moves.groundBelow(root.Position + Moves.flat(direction) * 35, { character }) + Vector3.new(0, 3, 0)
	end
	S.startCooldown(player, state, "NailDimension", c.Cooldown, 3)
	S.lock(state, 0.6)
	local yaw = math.atan2(direction.Z, direction.X)
	local portals = Moves.ring(center, c.Portals, c.PortalRadius, yaw, 4, 8)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 2, Move = "NailDimension", Phase = "Open", Portals = portals, Center = center, OpenTime = c.OpenTime })
	task.delay(c.OpenTime, function()
		if state.Life ~= life then
			return
		end
		local aimAt = (target and target.Parent and target:FindFirstChild("HumanoidRootPart")) and target.HumanoidRootPart.Position or center
		for _, pos in ipairs(portals) do
			local dir = aimAt - pos
			Moves.nail(S, player, state, {
				Origin = pos,
				Direction = dir.Unit,
				Speed = c.Speed,
				Radius = 0.8,
				Range = dir.Magnitude + 8,
				Style = "Portal",
				Damage = c.Damage,
				Stun = c.Stun,
				Knockback = c.Knockback,
				Source = "TuskNailDimension",
			})
		end
		local travel = (portals[1] - aimAt).Magnitude / c.Speed
		task.delay(travel + 0.05, function()
			if state.Life ~= life then
				return
			end
			Moves.aoe(S, player, aimAt, c.FinalRadius, { Damage = c.FinalDamage, Stun = 0.3, Knockback = 20, Launch = 12, Source = "TuskNailDimension" }, 5)
			S.fx("AbilityImpact", { Act = 2, Move = "NailDimension", Position = aimAt, Radius = c.FinalRadius })
		end)
	end)
end

function Act2.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		wormholeNail(S, player, state, aim)
	elseif slot == 2 then
		undergroundPursuit(S, player, state, aim)
	elseif slot == 3 then
		nailDimension(S, player, state, aim)
	end
end

-- DIMENSIONAL STORM
function Act2.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local life = state.Life
	local total = u.Windup + u.Waves * u.WaveInterval + 0.5
	S.lock(state, total)
	character:SetAttribute("Armored", true)
	local center = root.Position
	local portals = Moves.ring(center, u.Portals, u.Radius * 0.55, math.random() * math.pi * 2, 7, 11)
	S.fx("Ultimate", { Character = character, Act = 2, Phase = "Start", Windup = u.Windup, Portals = portals, Center = center })

	local function finish()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
	end
	for wave = 1, u.Waves do
		task.delay(u.Windup + (wave - 1) * u.WaveInterval, function()
			if state.Life ~= life then
				return
			end
			local targets = S.Hitbox.inRadius(character, center, u.Radius, 8)
			for i, pos in ipairs(portals) do
				local t = targets[(i + wave) % math.max(#targets, 1) + 1]
				local tr = t and t:FindFirstChild("HumanoidRootPart")
				local aimAt = tr and tr.Position or (center + Vector3.new(math.random(-12, 12), -2, math.random(-12, 12)))
				local dir = aimAt - pos
				Moves.nail(S, player, state, {
					Origin = pos,
					Direction = dir.Unit,
					Speed = u.NailSpeed,
					Radius = 0.8,
					Range = dir.Magnitude + 10,
					Style = "Portal",
					Damage = u.NailDamage,
					Stun = 0.3,
					Knockback = 4,
					Source = "TuskDimensionalStorm",
				})
			end
		end)
	end
	task.delay(total - 0.4, function()
		finish()
		if state.Life ~= life or not alive(S, player) then
			return
		end
		Moves.aoe(S, player, center, u.BurstRadius, { Damage = u.BurstDamage, Stun = u.Stun, Knockback = u.Knockback, Launch = u.Launch, Source = "TuskDimensionalStorm" }, 8)
		S.fx("Ultimate", { Character = character, Act = 2, Phase = "Burst", Position = center, Radius = u.BurstRadius })
		task.delay(0.35, function()
			if state.Life == life then
				S.finishUltimate(player, state) -- evolves to Act 3
			end
		end)
	end)
	task.delay(total + 1, finish)
end

function Act2.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
	end
end

return Act2
end

-- ======================================================================
-- MODULE: TuskAct3
-- ======================================================================
__modules["TuskAct3"] = function()
--[[
	TuskAct3  (ServerScriptService.SpinServer.TuskActs.TuskAct3)

	Tusk Act 3: master of spatial movement.
	  M1        WORMHOLE STRIKES: fast combo with portal flashes, portal uppercut finisher
	  Ability 1 DIMENSIONAL STEP: short validated portal teleport (entrance + exit portals)
	  Ability 2 SPATIAL PURSUIT: four portals around the target fire nails one after
	            another, each re-aimed at where the target is now
	  Ability 3 DIMENSIONAL BREAK: energy gathers, a large portal opens, a long
	            dimensional shockwave tears forward
	  Ultimate  INFINITE DIMENSION: layered portals around the battlefield, a giant
	            dimensional collapse, then Tusk evolves to Act 4
	Numbers: TuskConfig.Act3.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Act3 = {}
local cfg = TuskConfig.Act3

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Act3.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 3)
end

local function dimensionalStep(S, player, state, aim)
	local c = cfg.DimensionalStep
	if not ready(S, player, state, "DimensionalStep", 1) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local destination = Moves.safeStep(character, root, direction, c.Distance)
	if not destination then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "DimensionalStep", c.Cooldown, 1)
	S.lock(state, 0.25)
	local from = root.Position
	character:SetAttribute(S.Adapter.Settings.IFrameAttribute, true)
	character:PivotTo(CFrame.lookAt(destination, destination + direction))
	S.fx("Ability", { Character = character, Act = 3, Move = "DimensionalStep", From = from, To = destination, Direction = direction })
	task.delay(c.IFrames, function()
		if character.Parent then
			character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
		end
	end)
end

local function spatialPursuit(S, player, state, aim)
	local c = cfg.SpatialPursuit
	if not ready(S, player, state, "SpatialPursuit", 2) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local target = Moves.findTarget(S, character, root, c.Range, c.ConeDegrees, direction)
	if not target then
		S.startCooldown(player, state, "SpatialPursuit", 1.5, 2)
		S.tell(player, "Denied", { Reason = "NoTarget" })
		return
	end
	S.startCooldown(player, state, "SpatialPursuit", c.Cooldown, 2)
	S.lock(state, 0.5)
	local tr = target.HumanoidRootPart
	local portals = Moves.ring(tr.Position, c.Portals, c.PortalRadius, math.random() * math.pi * 2, 3, 7)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 3, Move = "SpatialPursuit", Phase = "Open", Portals = portals, Target = target, OpenTime = c.OpenTime, Stagger = c.Stagger })
	for i, pos in ipairs(portals) do
		task.delay(c.OpenTime + (i - 1) * c.Stagger, function()
			if state.Life ~= life or not tr.Parent then
				return
			end
			local dir = tr.Position - pos -- re-aimed at the target's current position
			Moves.nail(S, player, state, {
				Origin = pos,
				Direction = dir.Unit,
				Speed = c.Speed,
				Radius = 0.8,
				Range = dir.Magnitude + 10,
				Style = "Portal",
				Damage = c.Damage,
				Stun = c.Stun,
				Knockback = c.Knockback,
				Source = "TuskSpatialPursuit",
			})
		end)
	end
end

local function dimensionalBreak(S, player, state, aim)
	local c = cfg.DimensionalBreak
	if not ready(S, player, state, "DimensionalBreak", 3) then
		return
	end
	S.startCooldown(player, state, "DimensionalBreak", c.Cooldown, 3)
	S.lock(state, c.Charge + 0.5)
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 3, Move = "DimensionalBreak", Phase = "Charge", Charge = c.Charge, Direction = direction })
	task.delay(c.Charge, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local _, _, r = alive(S, player)
		local origin = r.Position
		local cf = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -(c.Length / 2 + 1))
		Moves.boxHit(S, player, cf, Vector3.new(c.Width, 9, c.Length), { Damage = c.Damage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = direction, Source = "TuskDimensionalBreak" }, 6)
		S.fx("Ability", { Character = character, Act = 3, Move = "DimensionalBreak", Phase = "Release", Origin = origin, Direction = direction, Length = c.Length, Width = c.Width })
	end)
end

function Act3.Ability(S, player, state, slot, phase, aim)
	if phase ~= "Press" then
		return
	end
	if slot == 1 then
		dimensionalStep(S, player, state, aim)
	elseif slot == 2 then
		spatialPursuit(S, player, state, aim)
	elseif slot == 3 then
		dimensionalBreak(S, player, state, aim)
	end
end

-- INFINITE DIMENSION
function Act3.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local life = state.Life
	S.lock(state, u.Windup + 0.6)
	character:SetAttribute("Armored", true)
	local center = root.Position
	local inner = Moves.ring(center, u.Portals / 2, u.Radius * 0.45, 0, 5, 9)
	local outer = Moves.ring(center, u.Portals / 2, u.Radius * 0.85, math.pi / (u.Portals / 2), 10, 14)
	local portals = {}
	for _, p in ipairs(inner) do
		table.insert(portals, p)
	end
	for _, p in ipairs(outer) do
		table.insert(portals, p)
	end
	S.fx("Ultimate", { Character = character, Act = 3, Phase = "Start", Windup = u.Windup, Portals = portals, Center = center, Radius = u.Radius })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		Moves.aoe(S, player, center, u.Radius, { Damage = u.Damage, Stun = u.Stun, Knockback = u.Knockback, Launch = u.Launch, Source = "TuskInfiniteDimension" }, 10)
		S.fx("Ultimate", { Character = character, Act = 3, Phase = "Burst", Position = center, Radius = u.Radius })
		task.delay(0.4, function()
			if state.Life == life then
				S.finishUltimate(player, state) -- evolves to Act 4
			end
		end)
	end)
end

function Act3.Cleanup(S, player, state)
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
	end
end

return Act3
end

-- ======================================================================
-- MODULE: TuskAct4
-- ======================================================================
__modules["TuskAct4"] = function()
--[[
	TuskAct4  (ServerScriptService.SpinServer.TuskActs.TuskAct4)

	Tusk Act 4: Infinite Rotation. Gold and deep blue, heavy and majestic.
	  M1        INFINITE BARRAGE: heavy punch, golden spin strike, rapid Stand
	            triple-hit, massive golden rotational finisher (area)
	  Ability 1 GOLDEN SPIN NAIL: big rotating projectile, golden impact blast
	  Ability 2 INFINITE ROTATION (hold): 3 charge stages, bigger projectile and
	            blast per stage
	  Ability 3 GOLDEN PURSUIT: golden rush to the first enemy ahead, rotational
	            strikes, huge golden shockwave
	  Ultimate  INFINITE ROTATION: 10-step cinematic, giant golden rotational
	            projectile, battlefield-wide golden shockwave (final form)
	Numbers: TuskConfig.Act4.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))
local Moves = __require("TuskMoves")

local Act4 = {}
local cfg = TuskConfig.Act4

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function ready(S, player, state, name, slot)
	return not S.isBusy(state) and not state.Charging and S.cooldownReady(player, state, name, slot)
end

function Act4.M1(S, player, state, aim)
	Moves.m1(S, player, state, aim, cfg.M1, 4)
end

-- Projectile with an area blast where it lands (direct target excluded from the blast).
local function blastNail(S, player, state, spec, blastRadius, blastDamage, source)
	local directHit = {}
	local base = spec.OnHit
	spec.OnEnd = function(position, _, hitCharacter)
		if hitCharacter then
			directHit[hitCharacter] = true
		end
		Moves.aoe(S, player, position, blastRadius, { Damage = blastDamage, Stun = 0.35, Knockback = 25, Launch = 10, Source = source }, 6, directHit)
	end
	return Moves.nail(S, player, state, spec), base
end

local function goldenSpinNail(S, player, state, aim)
	local c = cfg.GoldenSpinNail
	if not ready(S, player, state, "GoldenSpinNail", 1) then
		return
	end
	S.startCooldown(player, state, "GoldenSpinNail", c.Cooldown, 1)
	S.lock(state, c.Startup + 0.25)
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("Ability", { Character = character, Act = 4, Move = "GoldenSpinNail", Phase = "Startup", Startup = c.Startup, Direction = direction })
	task.delay(c.Startup, function()
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		blastNail(S, player, state, {
			Origin = S.origin(char, r, Moves.HAND),
			Direction = direction,
			Speed = c.Speed,
			Radius = c.Radius,
			Range = c.Range,
			Style = "Golden",
			Damage = c.Damage,
			Stun = c.Stun,
			Knockback = c.Knockback,
			Source = "TuskGoldenSpinNail",
		}, c.ImpactRadius, c.ImpactDamage, "TuskGoldenSpinNail")
	end)
end

local function infiniteRotationRelease(S, player, state, aim)
	local c = cfg.InfiniteRotation
	local charge = S.endCharge(player, state)
	if not charge or charge.Move ~= "InfiniteRotation" then
		return
	end
	local character, _, root = alive(S, player)
	if not character then
		return
	end
	local held = os.clock() - charge.Start
	local stage = 1
	for i, t in ipairs(c.Stages) do
		if held >= t then
			stage = i
		end
	end
	local direction = S.aim(aim, root)
	S.startCooldown(player, state, "InfiniteRotation", c.Cooldown, 2)
	S.lock(state, 0.4)
	S.fx("Ability", { Character = character, Act = 4, Move = "InfiniteRotation", Phase = "Release", Stage = stage, Direction = direction })
	blastNail(S, player, state, {
		Origin = S.origin(character, root, CFrame.new(0, 1.2, -2.5)),
		Direction = direction,
		Speed = c.Speed[stage],
		Radius = c.Radius[stage],
		Range = c.Range,
		Style = "Rotation",
		Charge = stage / 3,
		Damage = c.Damage[stage],
		Stun = c.Stun,
		Knockback = c.Knockback * (0.5 + stage / 6),
		Source = "TuskInfiniteRotation",
	}, c.ImpactRadius[stage], c.ImpactDamage[stage], "TuskInfiniteRotation")
end

local function infiniteRotationPress(S, player, state)
	local c = cfg.InfiniteRotation
	if not ready(S, player, state, "InfiniteRotation", 2) then
		return
	end
	local charge = S.beginCharge(player, state, "InfiniteRotation", 2, c.WalkSpeedMultiplier)
	local token = charge.Token
	task.delay(c.MaxHold, function()
		if state.Charging and state.Charging.Token == token then
			infiniteRotationRelease(S, player, state, nil)
		end
	end)
end

local function goldenPursuit(S, player, state, aim)
	local c = cfg.GoldenPursuit
	if not ready(S, player, state, "GoldenPursuit", 3) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = Moves.flat(S.aim(aim, root))
	-- Stop just short of the first enemy along the rush line.
	local distance = c.Distance
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, c.Distance + 4, 8)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr then
			local offset = tr.Position - root.Position
			local along = offset:Dot(direction)
			local side = (offset - direction * along).Magnitude
			if along > 0 and side < 5 and along - 3 < distance then
				distance = math.max(along - 3, 3)
			end
		end
	end
	local destination = Moves.safeStep(character, root, direction, distance)
	if not destination then
		S.tell(player, "Denied", { Reason = "Blocked" })
		return
	end
	S.startCooldown(player, state, "GoldenPursuit", c.Cooldown, 3)
	local gather = 0.2
	S.lock(state, gather + c.Hits * c.HitInterval + 0.45)
	local life = state.Life
	local from = root.Position
	S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Gather", Direction = direction })
	task.delay(gather, function()
		if not S.stillValid(player, state, life) then
			return
		end
		character:SetAttribute(S.Adapter.Settings.IFrameAttribute, true)
		character:PivotTo(CFrame.lookAt(destination, destination + direction))
		S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Dash", From = from, To = destination })
		task.delay(0.15, function()
			if character.Parent then
				character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
			end
		end)
		local front = destination + direction * 3
		for i = 1, c.Hits do
			task.delay(i * c.HitInterval, function()
				if state.Life ~= life then
					return
				end
				Moves.aoe(S, player, front, 6, { Damage = c.HitDamage, Stun = 0.4, Knockback = 3, Direction = direction, Source = "TuskGoldenPursuit" }, 3)
				S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Hit", Position = front, Index = i })
			end)
		end
		task.delay((c.Hits + 1) * c.HitInterval, function()
			if state.Life ~= life then
				return
			end
			Moves.aoe(S, player, front, c.FinalRadius, { Damage = c.FinalDamage, Stun = c.Stun, Knockback = c.Knockback, Launch = c.Launch, Direction = direction, Source = "TuskGoldenPursuit" }, 6)
			S.fx("Ability", { Character = character, Act = 4, Move = "GoldenPursuit", Phase = "Final", Position = front, Radius = c.FinalRadius })
		end)
	end)
end

function Act4.Ability(S, player, state, slot, phase, aim)
	if slot == 1 and phase == "Press" then
		goldenSpinNail(S, player, state, aim)
	elseif slot == 2 then
		if phase == "Press" then
			infiniteRotationPress(S, player, state)
		else
			infiniteRotationRelease(S, player, state, aim)
		end
	elseif slot == 3 and phase == "Press" then
		goldenPursuit(S, player, state, aim)
	end
end

function Act4.CancelCharge(S, player, state)
	local charge = S.endCharge(player, state)
	if charge then
		S.startCooldown(player, state, charge.Move, 2, charge.Slot)
		S.fx("Ability", { Character = state.Character, Act = 4, Move = charge.Move, Phase = "Cancel" })
	end
end

-- INFINITE ROTATION (ultimate)
function Act4.Ultimate(S, player, state, aim)
	local u = cfg.Ultimate
	if S.isBusy(state) or state.Charging then
		return
	end
	if not S.spendUlt(player) then
		return
	end
	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.lock(state, u.Windup + 0.6)
	character:SetAttribute("Armored", true)
	S.fx("Ultimate", { Character = character, Act = 4, Phase = "Start", Windup = u.Windup, Direction = direction })
	task.delay(u.Windup, function()
		if character.Parent then
			character:SetAttribute("Armored", nil)
		end
		if state.Life ~= life or not alive(S, player) then
			return
		end
		local _, _, r = alive(S, player)
		S.fx("Ultimate", { Character = character, Act = 4, Phase = "Release", Position = r.Position, Direction = direction })
		blastNail(S, player, state, {
			Origin = S.origin(character, r, CFrame.new(0, 2, -4)),
			Direction = direction,
			Speed = u.Speed,
			Radius = u.ProjectileRadius,
			Range = u.Range,
			Style = "InfiniteUlt",
			Charge = 1,
			Damage = u.Damage,
			Stun = u.Stun,
			Knockback = u.Knockback,
			Launch = u.Launch,
			Source = "TuskInfiniteRotationUlt",
		}, u.BlastRadius, u.BlastDamage, "TuskInfiniteRotationUlt")
		S.finishUltimate(player, state) -- final form: no evolution (Studio refills the meter)
	end)
end

function Act4.Cleanup(S, player, state)
	if state.Charging then
		S.endCharge(player, state)
	end
	if state.Character then
		state.Character:SetAttribute("Armored", nil)
		state.Character:SetAttribute(S.Adapter.Settings.IFrameAttribute, nil)
	end
end

return Act4
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
		Next = 2, -- the ultimate awakens Tusk to this Act
	},
	[2] = {
		Name = "TUSK ACT 2",
		Tagline = "Wormhole combat",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(70, 200, 255), Secondary = Color3.fromRGB(30, 80, 220) },
		M1 = "DIMENSIONAL COMBO",
		Abilities = { "WORMHOLE NAIL", "UNDERGROUND PURSUIT", "NAIL DIMENSION" },
		AbilityKinds = { "Press", "Press", "Press" },
		Next = 3,
		Ultimate = "DIMENSIONAL STORM",
	},
	[3] = {
		Name = "TUSK ACT 3",
		Tagline = "Master of spatial movement",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(60, 140, 255), Secondary = Color3.fromRGB(20, 40, 160) },
		M1 = "WORMHOLE STRIKES",
		Abilities = { "DIMENSIONAL STEP", "SPATIAL PURSUIT", "DIMENSIONAL BREAK" },
		AbilityKinds = { "Press", "Press", "Press" },
		Ultimate = "INFINITE DIMENSION",
		Next = 4,
	},
	[4] = {
		Name = "TUSK ACT 4",
		Tagline = "Infinite Rotation",
		Implemented = true,
		Theme = { Primary = Color3.fromRGB(255, 200, 70), Secondary = Color3.fromRGB(20, 40, 160) },
		M1 = "INFINITE BARRAGE",
		Abilities = { "GOLDEN SPIN NAIL", "INFINITE ROTATION", "GOLDEN PURSUIT" },
		AbilityKinds = { "Press", "Hold", "Press" },
		Ultimate = "INFINITE ROTATION",
		Next = nil, -- final form
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
-- MODULE: TuskMoves
-- ======================================================================
__modules["TuskMoves"] = function()
--[[
	TuskMoves  (ServerScriptService.SpinServer.TuskMoves)

	Shared server building blocks for every Tusk Act, so each Act module
	only describes what makes it different:
	  m1(...)          generic 4-hit combo (portals, multi-hits, AoE finisher, nail hits)
	  findTarget(...)  nearest valid enemy in a cone with line of sight
	  aoe(...)         radius hit with line-of-sight checks
	  boxHit(...)      oriented box hit
	  safeStep(...)    validated short teleport / dash destination
	  nail(...)        fire a nail with standard damage handling
	All damage still goes through TuskService.hit -> CombatAdapter.
]]

local Shared = nil -- (bundled: modules are inlined)
local TuskConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("TuskConfig"))

local TuskMoves = {}
TuskMoves.HAND = CFrame.new(0.9, 0.55, -1.5)

local function alive(S, player)
	return S.Adapter.getAlive(player)
end

local function flat(v)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 1e-3 and f.Unit or Vector3.new(0, 0, -1)
end
TuskMoves.flat = flat

---------------------------------------------------------------------------
-- Targeting and area damage
---------------------------------------------------------------------------
function TuskMoves.findTarget(S, character, root, range, coneDegrees, direction)
	local look = flat(direction or root.CFrame.LookVector)
	local cosLimit = math.cos(math.rad((coneDegrees or 360) / 2))
	local best, bestDistance
	for _, target in ipairs(S.Hitbox.inRadius(character, root.Position, range)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and S.Adapter.canBeHit(nil, target) then
			local offset = tr.Position - root.Position
			local f = Vector3.new(offset.X, 0, offset.Z)
			if f.Magnitude < 0.5 or f.Unit:Dot(look) >= cosLimit then
				if S.Hitbox.lineOfSight(root.Position, tr.Position, { character, target }) then
					if not bestDistance or offset.Magnitude < bestDistance then
						best, bestDistance = target, offset.Magnitude
					end
				end
			end
		end
	end
	return best
end

-- Damage everyone in a radius (line of sight from `center`). Returns hit count.
function TuskMoves.aoe(S, player, center, radius, info, maxTargets, exclude)
	local character = player.Character
	local count = 0
	for _, target in ipairs(S.Hitbox.inRadius(character, center, radius, maxTargets or 8)) do
		if not (exclude and exclude[target]) then
			local tr = target:FindFirstChild("HumanoidRootPart")
			if tr and S.Hitbox.lineOfSight(center, tr.Position, { character, target }) then
				local hitInfo = table.clone(info)
				hitInfo.Direction = info.Direction or (tr.Position - center)
				hitInfo.Position = tr.Position
				if S.hit(player, target, hitInfo) then
					count = count + 1
				end
			end
		end
	end
	return count
end

function TuskMoves.boxHit(S, player, cframe, size, info, maxTargets)
	local character, _, root = alive(S, player)
	local count, hitSet = 0, {}
	if not character then
		return 0, hitSet
	end
	for _, target in ipairs(S.Hitbox.inBox(character, cframe, size, maxTargets or 3)) do
		local tr = target:FindFirstChild("HumanoidRootPart")
		if tr and S.Hitbox.lineOfSight(root.Position, tr.Position, { character, target }) then
			local hitInfo = table.clone(info)
			hitInfo.Direction = info.Direction or (tr.Position - root.Position)
			hitInfo.Position = tr.Position
			if S.hit(player, target, hitInfo) then
				count = count + 1
				hitSet[target] = true
			end
		end
	end
	return count, hitSet
end

---------------------------------------------------------------------------
-- Movement
---------------------------------------------------------------------------
-- Validated destination for a short teleport/dash along a flat direction.
-- Stops before walls, needs ground below, and free space to stand in.
function TuskMoves.safeStep(character, root, direction, distance)
	local dir = flat(direction)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild("SpinClientFX") }
	local wall = workspace:Raycast(root.Position, dir * distance, params)
	local travel = wall and (wall.Distance - 2.5) or distance
	if travel < 3 then
		return nil
	end
	local groundHere = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	local height = groundHere and (root.Position.Y - groundHere.Position.Y) or 3
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	-- Walk back from the furthest point until a valid spot is found.
	local d = travel
	while d >= 3 do
		local probe = root.Position + dir * d
		local ground = workspace:Raycast(probe + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), params)
		if ground then
			local stand = Vector3.new(probe.X, ground.Position.Y + height, probe.Z)
			local blocked = false
			for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(stand), Vector3.new(2, 4.5, 2), overlap)) do
				if part.CanCollide then
					blocked = true
					break
				end
			end
			if not blocked then
				return stand
			end
		end
		d = d - 2
	end
	return nil
end

function TuskMoves.groundBelow(position, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	local hit = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return hit and hit.Position or position
end

---------------------------------------------------------------------------
-- Nails
---------------------------------------------------------------------------
--[[ spec: Origin, Direction, Speed, Radius, Range, Style, Charge,
          Damage, Stun, Knockback, Launch, Source, OnEnd ]]
function TuskMoves.nail(S, player, state, spec)
	return S.fireNail(player, state, {
		Origin = spec.Origin,
		Direction = spec.Direction,
		Speed = spec.Speed,
		Radius = spec.Radius or 0.7,
		Range = spec.Range,
		Style = spec.Style,
		Charge = spec.Charge,
		OnHit = function(target, position)
			S.hit(player, target, {
				Damage = spec.Damage,
				Stun = spec.Stun,
				Knockback = spec.Knockback,
				Launch = spec.Launch,
				Direction = spec.Direction,
				Position = position,
				Source = spec.Source or "TuskNail",
			})
		end,
		OnEnd = spec.OnEnd,
	})
end

---------------------------------------------------------------------------
-- Generic M1 combo
---------------------------------------------------------------------------
--[[ m1cfg.Hits[i] fields: Damage, Stun, Knockback, Launch,
     Portal (cosmetic), Repeat + RepeatInterval (multi-hit), AoeRadius
     (finisher hits a radius instead of the box), ShockwaveRadius (visual),
     Projectile = { Speed, Radius, Range } (nail instead of melee) ]]
function TuskMoves.m1(S, player, state, aim, m1cfg, act)
	if S.isBusy(state) or state.Charging then
		return
	end
	local now = os.clock()
	if now - state.LastM1 > m1cfg.ResetAfter then
		state.Combo = 0
	end
	local index = state.Combo + 1
	state.Combo = index >= 4 and 0 or index
	state.LastM1 = now
	local hit = m1cfg.Hits[index]
	local repeatTime = (hit.Repeat or 1) > 1 and (hit.Repeat - 1) * (hit.RepeatInterval or 0.08) or 0
	S.lock(state, (index == 4 and m1cfg.EndLag or m1cfg.Interval) + repeatTime)

	local character, _, root = alive(S, player)
	local direction = S.aim(aim, root)
	local life = state.Life
	S.fx("M1", { Character = character, Act = act, Index = index, Portal = hit.Portal == true, Repeat = hit.Repeat })

	local function strike(isLast)
		if not S.stillValid(player, state, life) then
			return
		end
		local char, _, r = alive(S, player)
		if hit.Projectile then
			TuskMoves.nail(S, player, state, {
				Origin = S.origin(char, r, TuskMoves.HAND),
				Direction = direction,
				Speed = hit.Projectile.Speed,
				Radius = hit.Projectile.Radius,
				Range = hit.Projectile.Range,
				Style = "M1",
				Damage = hit.Damage,
				Stun = hit.Stun,
				Knockback = hit.Knockback,
				Source = "TuskM1",
			})
			return
		end
		local boxCF = r.CFrame * CFrame.new(0, 0, -m1cfg.HitboxForward)
		local info = { Damage = hit.Damage, Stun = hit.Stun, Knockback = hit.Knockback, Launch = hit.Launch, Source = "TuskM1" }
		local landed
		if hit.AoeRadius and isLast then
			landed = TuskMoves.aoe(S, player, boxCF.Position, hit.AoeRadius, info, 5) > 0
		else
			landed = TuskMoves.boxHit(S, player, boxCF, m1cfg.HitboxSize, info, m1cfg.MaxTargets) > 0
		end
		if index == 4 and isLast then
			S.fx("M1Finisher", { Character = char, Act = act, Position = boxCF.Position, Radius = hit.ShockwaveRadius or 7, Hit = landed })
		end
	end

	local count = hit.Repeat or 1
	for i = 1, count do
		task.delay(m1cfg.Windup + (i - 1) * (hit.RepeatInterval or 0.08), function()
			strike(i == count)
		end)
	end
end

-- Ring of points around a center (portal placement shared by server and client payloads).
function TuskMoves.ring(center, count, radius, yaw, heightA, heightB)
	local points = {}
	for i = 1, count do
		local angle = (yaw or 0) + (i - 1) / count * math.pi * 2
		local h = (i % 2 == 0) and (heightB or 6) or (heightA or 4)
		table.insert(points, center + Vector3.new(math.cos(angle) * radius, h, math.sin(angle) * radius))
	end
	return points
end

TuskMoves.Config = TuskConfig
return TuskMoves
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
			Stage = spec.Stage,
		},
		OnHit = spec.OnHit,
		OnEnd = spec.OnEnd,
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
	if p.Mode == "Awaken" then
		-- Acts are reached through ultimates; the menu is a Studio testing aid only.
		return RunService:IsStudio() and p.StudioMenu == true
	end
	if p.Mode == "Unlock" then
		return p.IsUnlocked ~= nil and p.IsUnlocked(player, act) == true
	end
	return true
end

function TuskService.select(player, act, internal)
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
	if not internal and not isUnlocked(player, act) then
		TuskService.tell(player, "Denied", { Reason = "Locked" })
		return
	end
	if state.Act == act then
		return
	end
	if not internal and (os.clock() - state.LastSwitch < TuskConfig.Progression.SwitchCooldown or TuskService.isBusy(state)) then
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

-- Awakening: move straight to another Act (no menu rules, no switch cooldown).
function TuskService.evolve(player, state, toAct)
	if not Registry.isImplemented(toAct) or not actModules[toAct] then
		return
	end
	local from = state.Act
	cleanupAct(player, state)
	state.Act = toAct
	player:SetAttribute("TuskSelectedAct", toAct)
	if state.Character then
		state.Character:SetAttribute("TuskAct", toAct)
	end
	TuskService.fx("Evolve", { Character = state.Character, From = from, To = toAct })
	TuskService.tell(player, "Evolved", { Act = toAct })
end

-- Called by every Act's ultimate when its attack has finished.
function TuskService.finishUltimate(player, state)
	local info = Registry.get(state.Act)
	if TuskConfig.Progression.Mode == "Awaken" and info and info.Next then
		TuskService.evolve(player, state, info.Next)
	end
	if RunService:IsStudio() and TuskConfig.Ultimate.StudioRefill then
		player:SetAttribute("TuskUlt", TuskConfig.Ultimate.MaxMeter)
	end
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
	if action == "Character" then
		-- Character dropdown: Johnny Joestar = Tusk (starts at Act 1).
		local st = states[player]
		if a == "Johnny" and st and not st.Act then
			TuskService.select(player, TuskConfig.Progression.DefaultAct, true)
		end
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
	local progression = TuskConfig.Progression
	if state.Act and progression.Mode == "Awaken" and progression.ResetOnDeath then
		state.Act = progression.DefaultAct -- back to Act 1 after dying
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
		task.defer(TuskService.select, player, TuskConfig.Progression.DefaultAct, true)
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
local function findTarget(character, root, range, coneDegrees)
	range = range or cfg.Attack.Range
	coneDegrees = coneDegrees or cfg.Attack.ConeDegrees
	local best, bestDistance
	local cosLimit = math.cos(math.rad(coneDegrees / 2))
	for _, target in ipairs(Hitbox.inRadius(character, root.Position, range)) do
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
TuskSneakService.findTarget = findTarget

local function emergePoint(attacker, target, distance)
	local targetRoot = target.HumanoidRootPart
	local d = distance or cfg.Attack.EmergeDistance
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
	TuskSneakService.burrowStrike(player, state, target, a, "TuskSneakAttack")
end

--[[
	Burrow -> warning -> emerge behind the target -> hit + shockwave.
	Shared by the Sneak Attack and Act 2's Underground Pursuit.
	a = { BurrowTime, WarningTime, EmergeDistance, MaxTargetDrift, Range,
	      HitRadius, Damage, Stun, Knockback, Launch }
]]
function TuskSneakService.burrowStrike(player, state, target, a, source)
	local character, _, root = Adapter.getAlive(player)
	if not character then
		return
	end
	a = setmetatable(table.clone(a), { __index = cfg.Attack })
	S.lock(state, a.BurrowTime + 0.45)

	local life = state.Life
	local startPos = root.Position
	local targetStart = target.HumanoidRootPart.Position
	state.Burrowed = true
	character:SetAttribute("TuskBurrowed", true)
	character:SetAttribute(Adapter.Settings.IFrameAttribute, true)
	-- Anchor in place while underground so the hidden body can't wander.
	root.Anchored = true

	S.fx("SneakAttack", { Phase = "Burrow", Character = character, Position = startPos - Vector3.new(0, 2.8, 0), Target = target, BurrowTime = a.BurrowTime })

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
		local pos = valid and emergePoint(character, target, a.EmergeDistance) or nil

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
					Source = source or "TuskSneakAttack",
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

	Using your own model instead: set its asset id in TuskConfig.StandModels
	(StandAssetLoader loads it into ReplicatedStorage.SpinAssets), or put a
	Model named "TuskAct1" in ReplicatedStorage.SpinAssets by hand. It is
	cloned, cleaned of scripts, welded, resized to the configured Height and
	gets the same floating motion (ears/legs only animate on built-in models).
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

-- Custom Stand model: ReplicatedStorage.SpinAssets.TuskActN (loaded by
-- StandAssetLoader or placed by hand) or SpinShared.Assets.TuskActN.
local function findCustom(act)
	local name = "TuskAct" .. act
	local rs = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
	local custom = rs and rs:FindFirstChild(name)
	if not custom then
		local assets = game:GetService("ReplicatedStorage"):FindFirstChild("SpinAssets")
		custom = assets and assets:FindFirstChild(name)
	end
	return custom
end

local function override(act, scale)
	local custom = findCustom(act)
	if not custom then
		return nil
	end
	local clone = custom:Clone()
	if not clone:IsA("Model") then
		local wrapper = Instance.new("Model")
		clone.Parent = wrapper
		clone = wrapper
	end
	-- Safety + visual-only: no scripts, no collisions, no sounds playing.
	local parts = {}
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.Anchored = false
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		return nil
	end
	-- Root = the PrimaryPart, or the biggest part.
	local root = clone.PrimaryPart
	if not root or not root:IsDescendantOf(clone) then
		root = parts[1]
		for _, p in ipairs(parts) do
			if p.Size.Magnitude > root.Size.Magnitude then
				root = p
			end
		end
		clone.PrimaryPart = root
	end
	-- Weld every loose part to the root so the model moves as one piece.
	for _, p in ipairs(parts) do
		if p ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
		end
	end
	root.Anchored = true

	-- Size and facing from TuskConfig.StandModels.
	local settings = TuskConfig.StandModels and TuskConfig.StandModels[act] or {}
	local extents = clone:GetExtentsSize()
	local height = (settings.Height or 3) * scale
	if extents.Y > 0 then
		clone:ScaleTo(clone:GetScale() * height / extents.Y)
	end
	local rot = settings.Rotation or Vector3.new()
	local boxCF = clone:GetBoundingBox()
	-- Pivot at the model's centre, facing -Z, plus the configured rotation.
	clone.WorldPivot = CFrame.new(boxCF.Position) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))

	local point = Instance.new("Attachment")
	point.Name = "NailPoint"
	point.Parent = root
	point.WorldPosition = boxCF.Position + Vector3.new(0, 0, -clone:GetExtentsSize().Z * 0.5)
	return clone, { Body = root, Joints = {}, NailPoint = point, Custom = true }
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

---------------------------------------------------------------------------
-- ACT 2: Act 1 grown up. Bigger, magenta, a crest of spikes, two small arms.
---------------------------------------------------------------------------
local function limb(model, parent, rig, name, base, length, thickness, color, handColor)
	local arm = part(model, { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, thickness, thickness), Color = color })
	-- Cylinder axis is X; hang it down from the joint.
	local offset = CFrame.new(0, -length / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local w = attach(parent, arm, base * offset)
	rig.Joints[name] = { Weld = w, Base = base, Offset = offset }
	local hand = part(model, { Name = name .. "Hand", Size = Vector3.new(thickness * 1.6, thickness * 1.6, thickness * 1.6), Color = handColor or color, Ellipsoid = true })
	attach(arm, hand, CFrame.new(-length / 2 - thickness * 0.4, 0, 0))
	return arm, hand
end

local function buildAct2(scale)
	local s = scale * 1.25
	local model, rig = buildAct1(s)
	model.Name = "TuskAct2"
	-- (Color3 values can't be table keys, so compare directly.)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Color == colors.Pink then
				d.Color = Color3.fromRGB(214, 84, 196)
			elseif d.Color == colors.PinkDark then
				d.Color = Color3.fromRGB(118, 40, 150)
			end
		end
	end
	local body = rig.Body
	-- Crest of three spikes.
	for i = -1, 1 do
		local spike = part(model, { Name = "Crest", Size = Vector3.new(0.14, 0.7 - math.abs(i) * 0.2, 0.3) * s, Color = Color3.fromRGB(240, 200, 255), Ellipsoid = true })
		attach(body, spike, CFrame.new(i * 0.22 * s, 0.95 * s, 0.1 * s) * CFrame.Angles(0, 0, -i * 0.4))
	end
	-- Glowing chest star.
	local core = part(model, { Name = "Core", Size = Vector3.new(0.3, 0.3, 0.08) * s, Color = colors.Cyan, Material = Enum.Material.Neon, Ellipsoid = true })
	attach(body, core, CFrame.new(0, -0.35 * s, -0.62 * s))
	-- Arms.
	limb(model, body, rig, "ArmL", CFrame.new(-0.62 * s, -0.05 * s, -0.1 * s) * CFrame.Angles(0, 0, -0.5), 0.6 * s, 0.13 * s, Color3.fromRGB(214, 84, 196), colors.Star)
	local _, hand = limb(model, body, rig, "ArmR", CFrame.new(0.62 * s, -0.05 * s, -0.1 * s) * CFrame.Angles(0, 0, 0.5), 0.6 * s, 0.13 * s, Color3.fromRGB(214, 84, 196), colors.Star)
	rig.NailPoint.Parent = hand
	rig.NailPoint.Position = Vector3.new()
	return model, rig
end

---------------------------------------------------------------------------
-- Humanoid Stands (Act 3, Act 4)
---------------------------------------------------------------------------
local function buildHumanoid(name, scale, look)
	local s = scale
	local model = Instance.new("Model")
	model.Name = name
	local rig = { Joints = {} }

	local torso = part(model, { Name = "Body", Size = look.Torso * s, Color = look.Body, Ellipsoid = true, Massless = false })
	torso.CFrame = CFrame.new()
	torso.Anchored = true
	model.PrimaryPart = torso
	rig.Body = torso
	local ty = look.Torso.Y * s / 2

	-- Chest trim and star.
	local plate = part(model, { Name = "Chest", Size = Vector3.new(look.Torso.X * 0.75, look.Torso.Y * 0.45, 0.12) * s, Color = look.Trim, Material = look.TrimMaterial or Enum.Material.SmoothPlastic, Ellipsoid = true })
	attach(torso, plate, CFrame.new(0, ty * 0.3, -look.Torso.Z * s * 0.44))
	star(model, torso, Vector3.new(0, ty * 0.3, -look.Torso.Z * s * 0.52), Vector3.new(0, 0, -1), 0.55 * s, look.Star)

	-- Head with eyes, forehead star and the gold pin.
	local head = part(model, { Name = "Head", Size = look.Head * s, Color = look.HeadColor or look.Body, Ellipsoid = true })
	attach(torso, head, CFrame.new(0, ty + look.Head.Y * s * 0.45, -0.05 * s))
	local hy = look.Head.Y * s
	for _, side in ipairs({ -1, 1 }) do
		local eye = part(model, { Name = "Eye", Size = Vector3.new(0.22, 0.14, 0.08) * s, Color = look.Eye, Material = Enum.Material.Neon, Ellipsoid = true })
		attach(head, eye, CFrame.new(side * 0.2 * s, 0.02 * s, -look.Head.Z * s * 0.47) * CFrame.Angles(0, 0, side * -0.25))
	end
	star(model, head, Vector3.new(0, hy * 0.32, -look.Head.Z * s * 0.42), Vector3.new(0, 0.5, -1).Unit, 0.4 * s, look.Star)
	-- Head fins (animated like Act 1's ears).
	for _, e in ipairs({ { "EarL", -1 }, { "EarR", 1 } }) do
		local base = CFrame.new(e[2] * look.Head.X * s * 0.45, hy * 0.25, 0.05 * s) * CFrame.Angles(0, 0, -e[2] * 1.1)
		local fin = part(model, { Name = e[1], Size = Vector3.new(0.22, 0.8, 0.08) * s, Color = look.Trim, Ellipsoid = true })
		local offset = CFrame.new(0, 0.35 * s, 0)
		local w = attach(head, fin, base * offset)
		rig.Joints[e[1]] = { Weld = w, Base = base, Offset = offset }
	end

	-- Shoulders and arms.
	for _, a in ipairs({ { "ArmL", -1 }, { "ArmR", 1 } }) do
		local shoulderPos = CFrame.new(a[2] * (look.Torso.X * s * 0.5 + 0.1 * s), ty * 0.7, 0)
		local pad = part(model, { Name = "Shoulder", Size = Vector3.new(0.6, 0.5, 0.6) * s * look.ArmThickness * 3, Color = look.Trim, Material = look.TrimMaterial or Enum.Material.SmoothPlastic, Ellipsoid = true })
		attach(torso, pad, shoulderPos)
		local _, hand = limb(model, torso, rig, a[1], shoulderPos * CFrame.Angles(0, 0, a[2] * 0.15), look.ArmLength * s, look.ArmThickness * s, look.Body, look.Trim)
		if a[1] == "ArmR" then
			local point = Instance.new("Attachment")
			point.Name = "NailPoint"
			point.Parent = hand
			rig.NailPoint = point
		end
	end

	-- Lower body: legs (Act 4) or a swirling tail (Act 3).
	if look.Legs then
		for i, side in ipairs({ -1, 1 }) do
			local base = CFrame.new(side * look.Torso.X * s * 0.25, -ty * 0.85, 0)
			limb(model, torso, rig, "Leg" .. i, base, look.LegLength * s, look.ArmThickness * 1.3 * s, look.Body, look.Trim)
		end
	else
		local y = -ty * 0.9
		for i = 1, 4 do
			local size = Vector3.new(look.Torso.X * (0.8 - i * 0.16), 0.9, look.Torso.Z * (0.8 - i * 0.16)) * s
			local seg = part(model, { Name = "Tail", Size = size, Color = i % 2 == 0 and look.Trim or look.Body, Ellipsoid = true })
			attach(torso, seg, CFrame.new(math.sin(i * 1.3) * 0.25 * s, y, math.cos(i * 1.3) * 0.2 * s) * CFrame.Angles(0, i * 0.6, 0.15 * i))
			y = y - 0.55 * s
		end
	end

	-- Scattered stars on the torso.
	for _, spot in ipairs({ Vector3.new(0.45, -0.3, -0.35), Vector3.new(-0.45, 0.1, -0.35), Vector3.new(0.3, 0.4, 0.4), Vector3.new(-0.35, -0.4, 0.4) }) do
		star(model, torso, Vector3.new(spot.X * look.Torso.X, spot.Y * look.Torso.Y, spot.Z * look.Torso.Z) * s * 1.05, Vector3.new(spot.X, 0, spot.Z).Unit, 0.22 * s, look.Star)
	end
	return model, rig
end

local function buildAct3(scale)
	return buildHumanoid("TuskAct3", scale, {
		Torso = Vector3.new(1.3, 1.7, 0.9),
		Head = Vector3.new(0.95, 1.05, 0.95),
		Body = Color3.fromRGB(196, 96, 190),
		HeadColor = Color3.fromRGB(236, 170, 220),
		Trim = Color3.fromRGB(40, 50, 130),
		Star = colors.Star,
		Eye = Color3.fromRGB(120, 200, 255),
		ArmLength = 1.1,
		ArmThickness = 0.2,
		Legs = false,
	})
end

local function buildAct4(scale)
	return buildHumanoid("TuskAct4", scale * 1.15, {
		Torso = Vector3.new(1.8, 2.1, 1.1),
		Head = Vector3.new(1, 1.1, 1),
		Body = Color3.fromRGB(70, 56, 150),
		HeadColor = Color3.fromRGB(200, 120, 210),
		Trim = colors.Gold,
		TrimMaterial = Enum.Material.Metal,
		Star = colors.GoldLight,
		Eye = Color3.fromRGB(110, 230, 255),
		ArmLength = 1.4,
		ArmThickness = 0.3,
		Legs = true,
		LegLength = 1.6,
	})
end

local builders = {
	[1] = buildAct1,
	[2] = buildAct2,
	[3] = buildAct3,
	[4] = buildAct4,
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
__require("StandAssetLoader").init()

ProjectileService.MaxActivePerPlayer = 20
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
