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
	-- Tell OnEnd why it stopped: hit a character, hit a wall/ground, or ran out of range.
	p.HitWall = hitCharacter == nil and normal ~= nil
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

---------------------------------------------------------------------------
-- Stopped time (The World): a zone where projectiles hang in the air. Other
-- people's projectiles stop the moment they're inside; the zone owner's own
-- stop once they've flown OwnFreezeAfter studs. They all fly on when the
-- zone ends. Clients are told ("ProjectileFreeze" / "ProjectileResume") with
-- each projectile's flight time so the visuals stop and restart in step.
---------------------------------------------------------------------------
ProjectileService.OwnFreezeAfter = 5
local zones = {} -- [token] = { Center, Radius, Owner }

local function flightOf(p)
	return p.Traveled / math.max(p.Speed, 1e-3)
end

local function inZone(p)
	for token, z in pairs(zones) do
		if (p.Position - z.Center).Magnitude <= z.Radius and (p.Owner ~= z.Owner or p.Traveled >= ProjectileService.OwnFreezeAfter) then
			return token
		end
	end
	return nil
end

local function freeze(list, token)
	local ids, flights, spawned = {}, {}, {}
	for _, p in ipairs(list) do
		p.FrozenBy = token
		table.insert(ids, p.Id)
		table.insert(flights, flightOf(p))
		table.insert(spawned, p.SpawnedAt)
	end
	if #ids > 0 then
		FX:FireAllClients("ProjectileFreeze", { Ids = ids, Flights = flights, Spawned = spawned })
	end
end

function ProjectileService.stopTime(token, center, radius, owner)
	zones[token] = { Center = center, Radius = radius, Owner = owner }
	local list = {}
	for _, p in pairs(active) do
		if not p.FrozenBy and inZone(p) == token then
			table.insert(list, p)
		end
	end
	freeze(list, token)
end

function ProjectileService.resumeTime(token)
	zones[token] = nil
	local ids, flights, spawned = {}, {}, {}
	for _, p in pairs(active) do
		if p.FrozenBy == token then
			p.FrozenBy = nil
			table.insert(ids, p.Id)
			table.insert(flights, flightOf(p))
			table.insert(spawned, p.SpawnedAt)
		end
	end
	if #ids > 0 then
		FX:FireAllClients("ProjectileResume", { Ids = ids, Flights = flights, Spawned = spawned })
	end
end

function ProjectileService.isTimeStopped(position)
	for _, z in pairs(zones) do
		if (position - z.Center).Magnitude <= z.Radius then
			return true
		end
	end
	return false
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
		-- (projectile.HitWall is true when it stopped on a wall / the ground)
		Visual = spec.Visual or {},
		SpawnedAt = workspace:GetServerTimeNow(),
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
		ServerTime = p.SpawnedAt,
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
		if p.FrozenBy then
			continue -- hanging in stopped time
		end
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
				if next(zones) then
					local token = inZone(p)
					if token then
						freeze({ p }, token)
					end
				end
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
