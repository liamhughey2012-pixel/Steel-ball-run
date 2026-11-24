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
-- Projectile clock: server projectiles can be paused (The World's time
-- stop). Every projectile visual asks flight(id, serverTime) how long it has
-- been flying instead of (now - serverTime), and adds held(id) to its expiry.
---------------------------------------------------------------------------
local clocks = {} -- [projectile id] = { Frozen = flight seconds } or { Base, At }

function VFXLib.flight(id, serverTime)
	local now = workspace:GetServerTimeNow()
	local c = id and clocks[id]
	if not c then
		return now - (serverTime or now)
	end
	if c.Frozen then
		return c.Frozen
	end
	return c.Base + (now - c.At)
end

-- Seconds this projectile has spent paused (push its expiry back by this).
function VFXLib.held(id, serverTime)
	local c = id and clocks[id]
	if not c then
		return 0
	end
	local now = workspace:GetServerTimeNow()
	return math.max(0, (now - (c.Spawned or serverTime or now)) - VFXLib.flight(id, serverTime))
end

do
	local ok, Net = pcall(function()
		return require(Shared.Net)
	end)
	if ok and Net and Net.get then
		Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
			if typeof(data) ~= "table" then
				return
			end
			if name == "ProjectileFreeze" then
				for i, id in ipairs(data.Ids or {}) do
					clocks[id] = { Frozen = data.Flights and data.Flights[i] or 0, Spawned = data.Spawned and data.Spawned[i] }
				end
			elseif name == "ProjectileResume" then
				for i, id in ipairs(data.Ids or {}) do
					local c = clocks[id]
					clocks[id] = { Base = data.Flights and data.Flights[i] or 0, At = workspace:GetServerTimeNow(), Spawned = c and c.Spawned or (data.Spawned and data.Spawned[i]) }
				end
			elseif name == "ProjectileEnd" and data.Id then
				-- (Ended a moment later, so the visual's last step still uses it.)
				local id = data.Id
				task.delay(0.5, function()
					clocks[id] = nil
				end)
			end
		end)
	end
end

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
