---
tags: [code, server]
type: ModuleScript
location: "ServerScriptService › SpinServer"
updated: 2026-11-22
---
# RaceService

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `ServerScriptService › SpinServer` |
| **Exact name** | `RaceService` (capitals matter) |

**What it does:** THE STEEL BALL RUN: a horse race round the map, every 10 minutes, and your own horse (M) to ride anywhere the rest of the time. ENTRY: every Race.Every seconds entry opens for EntryTime seconds. Everyone gets a banner with a JOIN button (or press E at the starting grid). The numbered gates go up round the course. START: riders line up 4 abreast inside the map's fenced race track, behind its START arch, on their own horse (coat and blanket from the STABLE) with its hooves on the ground, held for the countdown. NPC JOCKEYS (Race.NPCRacers) line up with them. THE RACE: down the track, out past its end, round the open desert to the east and back to the FINISH by the spawn, through the gates in order. You can fight, dash, block and use your Stand on horseback. Going down puts you out. Jockeys find their way with pathfinding (and hop free if they get stuck). PRIZES: Cash for the top 3 players (and a little for every finisher); a Saint's Corpse part appears at the finish for a winning player. Finishers keep their horse to ride on. YOUR HORSE (M): call it, ride it anywhere, press M again to get off (not during a race you're in; the race gives you yours). The rider sits exactly on the saddle: the horse is welded under their root with its hooves on the ground, and every client lifts the rider's body up onto the saddle (RideLift). HipHeight is never changed (that let Roblox's own HipHeight resets send horses floating off). Clients: RaceClient (HUD, beacon, gallop, M key). ReplicatedStorage attributes: SpinRacePhase, SpinRaceNext, SpinRaceEntryEnds, SpinRaceGoAt, SpinRaceStart. Remote: Net "Race" (client: "Join" / "Leave" / "Horse"). Numbers: TuskConfig.Race and TuskConfig.Horses.

## How to add it
1. In Studio's Explorer, find **SpinServer** (ServerScriptService › SpinServer).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **RaceService**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	RaceService  (ServerScriptService.SpinServer.RaceService)

	THE STEEL BALL RUN: a horse race round the map, every 10 minutes, and
	your own horse (M) to ride anywhere the rest of the time.
	  * ENTRY: every Race.Every seconds entry opens for EntryTime seconds.
	    Everyone gets a banner with a JOIN button (or press E at the
	    starting grid). The numbered gates go up round the course.
	  * START: riders line up 4 abreast inside the map's fenced race track,
	    behind its START arch, on their own horse (coat and blanket from the
	    STABLE) with its hooves on the ground, held for the countdown.
	    NPC JOCKEYS (Race.NPCRacers) line up with them.
	  * THE RACE: down the track, out past its end, round the open desert
	    to the east and back to the FINISH by the spawn, through the gates in
	    order. You can fight, dash, block and use your Stand on horseback.
	    Going down puts you out. Jockeys find their way with pathfinding (and
	    hop free if they get stuck).
	  * PRIZES: Cash for the top 3 players (and a little for every
	    finisher); a Saint's Corpse part appears at the finish for a winning
	    player. Finishers keep their horse to ride on.
	  * YOUR HORSE (M): call it, ride it anywhere, press M again to get off
	    (not during a race you're in; the race gives you yours).
	The rider sits exactly on the saddle: the horse is welded under their
	root with its hooves on the ground, and every client lifts the rider's
	body up onto the saddle (RideLift). HipHeight is never changed (that let
	Roblox's own HipHeight resets send horses floating off).
	Clients: RaceClient (HUD, beacon, gallop, M key). ReplicatedStorage
	attributes: SpinRacePhase, SpinRaceNext, SpinRaceEntryEnds, SpinRaceGoAt,
	SpinRaceStart. Remote: Net "Race" (client: "Join" / "Leave" / "Horse").
	Numbers: TuskConfig.Race and TuskConfig.Horses.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local PlayersService = Players

local Shared = ReplicatedStorage:WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Net = require(Shared.Net)
local Adapter = require(script.Parent.CombatAdapter)
local HorseModel = require(Shared.HorseModel)
local PathfindingService = game:GetService("PathfindingService")

local RaceService = {}
local cfg = TuskConfig.Race or {}
local Remote
local rng = Random.new()

local phase = nil -- nil (idle) | "Entry" | "Countdown" | "Racing"
local nextEntryAt = 0
local entryEnds = 0
local raceStart = 0
local winnerAt
local racers = {} -- [player] = { Next, Finished, Place, Time }
local finishOrder = {}
local course -- { Start = Vector3, StartFacing = Vector3, Gates = { Vector3 ... } }
local courseFolder
local startPrompt

local function now()
	return workspace:GetServerTimeNow()
end

local function setAttr(k, v)
	ReplicatedStorage:SetAttribute(k, v)
end

local function origin()
	local map = workspace:FindFirstChild("SBRMap")
	return map and map:GetAttribute("Origin") or Vector3.new()
end

-- The ground under a point (ignoring characters and the course itself).
local function groundAt(position)
	local ignore = { courseFolder }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	for _, m in ipairs(CollectionService:GetTagged("SpinFighter")) do
		table.insert(ignore, m)
	end
	for _, r in pairs(racers) do
		if r.Model then
			table.insert(ignore, r.Model)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), params)
	return hit and hit.Position or position
end

local function send(player, kind, data)
	if Remote then
		Remote:FireClient(player, kind, data or {})
	end
end

local function broadcast(kind, data)
	if Remote then
		Remote:FireAllClients(kind, data or {})
	end
end

local function pay(player, amount)
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash")
	if cash and amount > 0 then
		cash.Value = cash.Value + amount
	end
end

---------------------------------------------------------------------------
-- The course: numbered gates round the map, a start gate with the entry prompt
---------------------------------------------------------------------------
local WOOD = Color3.fromRGB(112, 74, 44)
local RED = Color3.fromRGB(176, 40, 36)
local CREAM = Color3.fromRGB(240, 228, 200)

local function block(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function bannerText(part, text, color, bg)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		gui.LightInfluence = 0.4
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = bg
		label.BackgroundTransparency = 0
		label.Font = Enum.Font.Bangers
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.5
		label.Parent = gui
		gui.Parent = part
	end
end

-- A gate across the course at `position`, facing along `facing`.
local function buildGate(parent, position, facing, text, kind)
	local width = cfg.GateWidth or 30
	local ground = groundAt(position)
	local cf = CFrame.lookAt(ground, ground + Vector3.new(facing.X, 0, facing.Z))
	local gate = Instance.new("Model")
	gate.Name = "Gate_" .. text
	local postColor = kind == "Finish" and Color3.fromRGB(30, 30, 30) or WOOD
	for _, side in ipairs({ -1, 1 }) do
		block(gate, "Post", Vector3.new(1.2, 16, 1.2), cf * CFrame.new(side * width / 2, 8, 0), postColor)
		block(gate, "PostCap", Vector3.new(1.8, 0.6, 1.8), cf * CFrame.new(side * width / 2, 16.2, 0), RED)
		-- A pennant on each post.
		block(gate, "Pennant", Vector3.new(0.1, 1.4, 2.4), cf * CFrame.new(side * width / 2, 17.4, 1.2), kind == "Finish" and Color3.new(1, 1, 1) or RED, Enum.Material.Fabric)
	end
	local banner = block(gate, "Banner", Vector3.new(width - 2, 3.4, 0.3), cf * CFrame.new(0, 13.5, 0), kind == "Finish" and Color3.new(1, 1, 1) or CREAM, Enum.Material.Fabric)
	if kind == "Finish" then
		-- Chequered.
		for i = 0, 13 do
			for j = 0, 1 do
				if (i + j) % 2 == 0 then
					block(gate, "Check", Vector3.new((width - 2) / 14, 1.7, 0.34), cf * CFrame.new(-(width - 2) / 2 + (i + 0.5) * (width - 2) / 14, 13.5 + (j - 0.5) * 1.7, 0), Color3.fromRGB(20, 20, 20), Enum.Material.Fabric)
				end
			end
		end
		local sign = block(gate, "Sign", Vector3.new(12, 3, 0.4), cf * CFrame.new(0, 17.2, 0), Color3.fromRGB(20, 20, 20))
		bannerText(sign, "FINISH", Color3.fromRGB(255, 220, 90), Color3.fromRGB(20, 20, 20))
	else
		bannerText(banner, text, RED, CREAM)
	end
	-- The line on the ground.
	block(gate, "Line", Vector3.new(width, 0.2, 1.2), cf * CFrame.new(0, 0.1, 0), kind == "Finish" and Color3.new(1, 1, 1) or CREAM, Enum.Material.SmoothPlastic)
	gate:SetAttribute("GateIndex", tonumber(text) or 0)
	gate.Parent = parent
	return gate, ground
end

-- The course gates (the start is the map's own fenced track and arch).
local function buildCourse()
	if courseFolder then
		courseFolder:Destroy()
	end
	courseFolder = Instance.new("Folder")
	courseFolder.Name = "SteelBallRunCourse"
	courseFolder.Parent = workspace
	local o = origin()
	local start = groundAt(o + (cfg.Start or Vector3.new(0, 0, 118)))
	local facing = cfg.StartFacing or Vector3.new(0, 0, -1)
	facing = Vector3.new(facing.X, 0, facing.Z).Unit
	local gates = {}
	local points = { start }
	for _, offset in ipairs(cfg.Checkpoints or {}) do
		table.insert(points, groundAt(o + offset))
	end
	for i = 2, #points do
		local isFinish = i == #points
		local _, ground = buildGate(courseFolder, points[i], points[i] - points[i - 1], isFinish and "FINISH" or tostring(i - 1), isFinish and "Finish" or "Gate")
		table.insert(gates, ground)
	end
	-- The starting grid: a painted line across the track, and the entry
	-- prompt on an invisible marker in the middle of it (nothing to bump into).
	local right = facing:Cross(Vector3.new(0, 1, 0)).Unit
	local lineCf = CFrame.lookAt(start, start + facing)
	block(courseFolder, "StartLine", Vector3.new(24, 0.2, 0.8), lineCf * CFrame.new(0, 0.1, 0), CREAM, Enum.Material.SmoothPlastic)
	local marker = block(courseFolder, "EntryMarker", Vector3.new(4, 4, 4), lineCf * CFrame.new(0, 3, 8), CREAM)
	marker.Transparency = 1
	startPrompt = Instance.new("ProximityPrompt")
	startPrompt.ActionText = "Enter the Race"
	startPrompt.ObjectText = "STEEL BALL RUN"
	startPrompt.HoldDuration = 0
	startPrompt.MaxActivationDistance = 16
	startPrompt.RequiresLineOfSight = false
	startPrompt.Enabled = phase == "Entry"
	startPrompt.Parent = marker
	startPrompt.Triggered:Connect(function(player)
		RaceService.join(player)
	end)
	course = { Start = start, StartFacing = facing, Right = right, Gates = gates }
	return course
end

---------------------------------------------------------------------------
-- Horses (players' own, race horses, jockeys')
---------------------------------------------------------------------------
local hcfg = TuskConfig.Horses or {}

local function catalogue(list, id)
	for _, item in ipairs(list or {}) do
		if item.Id == id then
			return item
		end
	end
	return (list or {})[1]
end

-- The horse a player set up in the stable.
local function lookFor(player)
	local coat = catalogue(hcfg.Coats, player and player:GetAttribute("HorseCoat"))
	local blanket = catalogue(hcfg.Blankets, player and player:GetAttribute("HorseBlanket"))
	local look = { Width = 1.9 }
	if coat then
		look.Body, look.Mane = coat.Body, coat.Mane
		look.Socks = coat.Socks
		look.Material = coat.Material and Enum.Material[coat.Material] or nil
	end
	if blanket then
		look.Blanket = blanket.Color
	end
	return look
end

local function randomLook()
	local coats = cfg.Coats or {}
	local c = coats[rng:NextInteger(1, math.max(#coats, 1))] or {}
	local blankets = hcfg.Blankets or {}
	local b = blankets[rng:NextInteger(1, math.max(#blankets, 1))]
	return { Body = c[1], Mane = c[2], Blanket = b and b.Color, Width = 1.9 }
end

-- Where the rider's seat is (the bottom of their hips), relative to the root,
-- in the rest pose: read from the root joint's C0 / C1 (positions replicated
-- from a player's client include their animation, e.g. the ride lift).
local function seatHeight(character, root)
	local hips = character:FindFirstChild("LowerTorso")
	local joint = hips and hips:FindFirstChild("Root")
	if not hips then
		local torso = character:FindFirstChild("Torso")
		hips = torso
		joint = root:FindFirstChild("RootJoint")
	end
	if hips and joint and joint:IsA("Motor6D") then
		local rest = joint.C0 * joint.C1:Inverse()
		return rest.Position.Y - hips.Size.Y / 2
	end
	if hips then
		return (root.CFrame:Inverse() * hips.Position).Y - hips.Size.Y / 2
	end
	return -1
end

-- Place the horse under a rider: welded to their root with its hooves on the
-- ground at the rider's normal height. The rider's HipHeight is NEVER
-- changed (Roblox can reset it, which made horses float away); instead the
-- clients lift the rider's body onto the saddle (RideLift, TuskAnimation).
-- Re-fitted whenever HipHeight changes.
local function fitHorse(character)
	local horse = character and character:FindFirstChild("RaceHorse")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local body = horse and horse.PrimaryPart
	local w = body and body:FindFirstChild("HorseWeld")
	if not w or not humanoid or not root then
		return
	end
	local bodyY = HorseModel.HoofDepth - (humanoid.HipHeight + root.Size.Y / 2)
	w.C0 = CFrame.new(0, bodyY, -0.4)
	horse:SetAttribute("BodyY", bodyY)
	local seat = character:GetAttribute("RideSeat") or -0.25
	character:SetAttribute("RideLift", math.max(0, bodyY + HorseModel.SaddleTop - seat))
end

local function mount(character, look, speed, kind)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local old = character:FindFirstChild("RaceHorse")
	if old then
		old:Destroy()
	end
	-- (An older version raised HipHeight: put it back if it's still raised.)
	local oldBase = character:GetAttribute("RaceHipBase")
	if oldBase then
		humanoid.HipHeight = oldBase
		character:SetAttribute("RaceHipBase", nil)
	end
	look = look or {}
	local horse = HorseModel.build(look.Body, look.Mane, { Width = look.Width or 1.9, Blanket = look.Blanket, Socks = look.Socks, Material = look.Material })
	horse.Name = "RaceHorse"
	for _, d in ipairs(horse:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	character:SetAttribute("RideSeat", seatHeight(character, root))
	local body = horse.PrimaryPart
	local w = Instance.new("Weld")
	w.Name = "HorseWeld"
	w.Part0 = root
	w.Part1 = body
	w.Parent = body
	horse.Parent = character
	fitHorse(character)
	body.CFrame = root.CFrame * w.C0
	if not character:GetAttribute("HorseFitHooked") then
		character:SetAttribute("HorseFitHooked", true)
		humanoid:GetPropertyChangedSignal("HipHeight"):Connect(function()
			fitHorse(character)
		end)
	end
	CollectionService:AddTag(horse, "SpinHorse")
	Adapter.setMoveModifier(humanoid, "Horse", speed or 3)
	character:SetAttribute("Riding", kind or "Ride")
	return horse
end

local function dismount(character)
	if not character then
		return
	end
	local horse = character:FindFirstChild("RaceHorse")
	if horse then
		horse:Destroy()
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local base = character:GetAttribute("RaceHipBase")
		if base then
			humanoid.HipHeight = base
		end
		Adapter.setMoveModifier(humanoid, "Horse", nil)
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and character:GetAttribute("RaceAnchored") then
		root.Anchored = false
	end
	character:SetAttribute("RaceAnchored", nil)
	character:SetAttribute("RaceHipBase", nil)
	character:SetAttribute("Riding", nil)
	character:SetAttribute("RideLift", nil)
end
RaceService.dismount = dismount

-- Put a (mounted) character standing on the ground at `position`, facing `facing`.
local function standAt(character, position, facing)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	local ground = groundAt(position)
	local at = ground + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 + 0.05, 0)
	character:PivotTo(CFrame.lookAt(at, at + facing))
end

-- M: call your horse / send it away.
function RaceService.toggleHorse(player)
	if hcfg.Enabled == false then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local r = racers[player]
	if r and not r.Finished and (phase == "Countdown" or phase == "Racing") then
		send(player, "Denied", { Reason = "You're racing!" })
		return
	end
	local t = now()
	if (player:GetAttribute("HorseReadyAt") or 0) > t then
		return
	end
	player:SetAttribute("HorseReadyAt", t + (hcfg.Cooldown or 2))
	if character:FindFirstChild("RaceHorse") then
		dismount(character)
		send(player, "Horse", { Riding = false })
	else
		if not Adapter.canAct(player) then
			return
		end
		mount(character, lookFor(player), hcfg.RideSpeed or 2.8, "Ride")
		send(player, "Horse", { Riding = true })
	end
end

-- The stable changed: re-saddle anyone riding their own horse.
function RaceService.refreshHorse(player)
	local character = player.Character
	if character and character:FindFirstChild("RaceHorse") then
		local kind = character:GetAttribute("Riding")
		mount(character, lookFor(player), kind == "Race" and (cfg.HorseSpeed or 3.2) or (hcfg.RideSpeed or 2.8), kind)
	end
end

---------------------------------------------------------------------------
-- Racers: players and NPC jockeys. racers[key] = r, where key is the Player
-- (or the jockey's record) and r = { Player?, Jockey?, Name, UserId, Next,
-- Finished, Place, Time }.
---------------------------------------------------------------------------
local function charOf(r)
	return r.Player and r.Player.Character or r.Model
end

local function racerCount(playersOnly)
	local n = 0
	for _, r in pairs(racers) do
		if not playersOnly or r.Player then
			n = n + 1
		end
	end
	return n
end

function RaceService.join(player)
	if phase ~= "Entry" or racers[player] then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	racers[player] = { Player = player, Name = player.DisplayName, UserId = player.UserId, Next = 1 }
	player:SetAttribute("RaceEntered", true)
	send(player, "Joined", { Ends = entryEnds })
	broadcast("Entrants", { Count = racerCount(true) })
end

local function out(key, reason)
	local r = racers[key]
	if not r then
		return
	end
	racers[key] = nil
	if r.Player then
		r.Player:SetAttribute("RaceEntered", nil)
		dismount(r.Player.Character)
		send(r.Player, "Out", { Reason = reason })
		broadcast("Entrants", { Count = racerCount(true) })
	elseif r.Model then
		local model = r.Model
		task.delay(3, function()
			model:Destroy()
		end)
	end
end

function RaceService.leave(player)
	local r = racers[player]
	if not r then
		return
	end
	if phase == "Entry" then
		out(player, "You left the race.")
	elseif not r.Finished then
		out(player, "You pulled out of the race.")
	end
end

---------------------------------------------------------------------------
-- NPC jockeys
---------------------------------------------------------------------------
local JOCKEY_SILKS = {
	Color3.fromRGB(200, 50, 50), Color3.fromRGB(50, 90, 200), Color3.fromRGB(240, 200, 60),
	Color3.fromRGB(60, 160, 90), Color3.fromRGB(150, 70, 170), Color3.fromRGB(240, 140, 50),
}

local function spawnJockey(index)
	local names = cfg.NPCNames or { "Jockey" }
	local name = names[((index - 1) % #names) + 1]
	local desc = Instance.new("HumanoidDescription")
	local silk = JOCKEY_SILKS[((index - 1) % #JOCKEY_SILKS) + 1]
	desc.HeadColor = Color3.fromRGB(226, 186, 150)
	desc.LeftArmColor = silk
	desc.RightArmColor = silk
	desc.TorsoColor = silk
	desc.LeftLegColor = Color3.fromRGB(235, 230, 220)
	desc.RightLegColor = Color3.fromRGB(235, 230, 220)
	local ok, model = pcall(function()
		return PlayersService:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return nil
	end
	model.Name = "Jockey: " .. name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = "Jockey: " .. name
	humanoid.MaxHealth = cfg.NPCHealth or 120
	humanoid.Health = humanoid.MaxHealth
	model:SetAttribute("RaceJockey", true)
	model.Parent = workspace
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root.SetNetworkOwner then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	local skill = cfg.NPCSkill or { 0.8, 0.95 }
	local r = { Jockey = true, Model = model, Name = "Jockey: " .. name, UserId = -500 - index, Next = 1, Skill = skill[1] + rng:NextNumber() * (skill[2] - skill[1]) }
	humanoid.Died:Connect(function()
		for key, rr in pairs(racers) do
			if rr == r then
				out(key, "down")
			end
		end
	end)
	return r
end

-- A jockey rides the course: pathfinding to each gate, hopping free if stuck.
local function runJockey(key, r)
	local model = r.Model
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end
	local path
	pcall(function()
		path = PathfindingService:CreatePath({ AgentRadius = 3, AgentHeight = 9, AgentCanJump = true, WaypointSpacing = 10 })
	end)
	local waypoints, wi, forGate
	local lastPos, lastProgress = root.Position, now()
	local function step()
		if phase ~= "Racing" or racers[key] ~= r or r.Finished or humanoid.Health <= 0 or not model.Parent then
			return
		end
		local gate = course.Gates[r.Next]
		if not gate then
			return
		end
		if forGate ~= r.Next then
			forGate = r.Next
			waypoints, wi = nil, 1
			if path then
				local ok = pcall(function()
					path:ComputeAsync(root.Position, gate)
				end)
				if ok and path.Status == Enum.PathStatus.Success then
					waypoints, wi = path:GetWaypoints(), 2
				end
			end
		end
		local target = gate
		if waypoints and waypoints[wi] then
			target = waypoints[wi].Position
			local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
			if flat.Magnitude < 7 then
				if waypoints[wi].Action == Enum.PathWaypointAction.Jump then
					humanoid.Jump = true
				end
				wi = wi + 1
				target = waypoints[wi] and waypoints[wi].Position or gate
			end
		end
		humanoid:MoveTo(target)
		-- Stuck? Jump; still stuck? Hop free towards the gate.
		if (root.Position - lastPos).Magnitude > 4 then
			lastPos, lastProgress = root.Position, now()
		elseif now() - lastProgress > 2 then
			humanoid.Jump = true
			if now() - lastProgress > 5 then
				local dir = Vector3.new(gate.X - root.Position.X, 0, gate.Z - root.Position.Z)
				dir = dir.Magnitude > 0.1 and dir.Unit or course.StartFacing
				standAt(model, root.Position + dir * 12, dir)
				lastPos, lastProgress = root.Position, now()
				forGate = nil
			end
		end
		task.delay(0.25, step)
	end
	step()
end

---------------------------------------------------------------------------
-- Entry, start, race, results
---------------------------------------------------------------------------
local function openEntry()
	phase = "Entry"
	racers, finishOrder, winnerAt = {}, {}, nil
	buildCourse()
	entryEnds = now() + (cfg.EntryTime or 45)
	nextEntryAt = now() + (cfg.Every or 600)
	if startPrompt then
		startPrompt.Enabled = true
	end
	setAttr("SpinRacePhase", "Entry")
	setAttr("SpinRaceEntryEnds", entryEnds)
	setAttr("SpinRaceNext", nextEntryAt)
	broadcast("EntryOpen", { Ends = entryEnds })
end

local function cleanup()
	for key, r in pairs(racers) do
		if r.Player then
			r.Player:SetAttribute("RaceEntered", nil)
			local character = r.Player.Character
			-- Riders keep their horse (now theirs to ride around).
			if character and character:FindFirstChild("RaceHorse") then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local root = character:FindFirstChild("HumanoidRootPart")
				if root and character:GetAttribute("RaceAnchored") then
					root.Anchored = false
					character:SetAttribute("RaceAnchored", nil)
				end
				if humanoid then
					Adapter.setMoveModifier(humanoid, "Horse", hcfg.RideSpeed or 2.8)
				end
				character:SetAttribute("Riding", "Ride")
			end
		elseif r.Model then
			local model = r.Model
			task.delay(2, function()
				model:Destroy()
			end)
		end
		racers[key] = nil
	end
	racers, finishOrder, winnerAt = {}, {}, nil
	phase = nil
	setAttr("SpinRacePhase", nil)
	setAttr("SpinRaceGoAt", nil)
	setAttr("SpinRaceStart", nil)
	if courseFolder then
		courseFolder:Destroy()
		courseFolder = nil
	end
	startPrompt = nil
end

local function startRace()
	if startPrompt then
		startPrompt.Enabled = false
	end
	-- Only riders still alive and in the game.
	for key, r in pairs(racers) do
		local player = r.Player
		local h = player and player.Parent and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not h or h.Health <= 0 then
			racers[key] = nil
			if player then
				player:SetAttribute("RaceEntered", nil)
			end
		end
	end
	if racerCount(true) == 0 then
		broadcast("Cancelled", { Reason = "Nobody entered the Steel Ball Run this time." })
		cleanup()
		return
	end
	-- NPC jockeys join the field.
	for i = 1, cfg.NPCRacers or 0 do
		local r = spawnJockey(i)
		if r then
			racers[r] = r
		end
	end
	phase = "Countdown"
	setAttr("SpinRacePhase", "Countdown")
	local goAt = now() + (cfg.Countdown or 4)
	setAttr("SpinRaceGoAt", goAt)
	-- Line everyone up inside the track, 4 abreast, on their horses, hooves on the ground.
	local list = {}
	for key, r in pairs(racers) do
		table.insert(list, { Key = key, R = r })
	end
	table.sort(list, function(a, b)
		return (a.R.Player and 0 or 1) < (b.R.Player and 0 or 1) -- players at the front
	end)
	local facing, right = course.StartFacing, course.Right
	local cols = cfg.GridColumns or 4
	for i, e in ipairs(list) do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local spot = course.Start - facing * (row * (cfg.GridRowGap or 7) + 3) + right * ((col - (cols - 1) / 2) * (cfg.GridSpacing or 4.5))
		local character = charOf(e.R)
		if character then
			local look = e.R.Player and lookFor(e.R.Player) or randomLook()
			mount(character, look, (cfg.HorseSpeed or 3.2) * (e.R.Skill or 1), "Race")
			standAt(character, spot, facing)
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				root.Anchored = true
				character:SetAttribute("RaceAnchored", true)
			end
		end
	end
	broadcast("Countdown", { GoAt = goAt, Riders = #list, Total = #course.Gates })
	task.delay(cfg.Countdown or 4, function()
		if phase ~= "Countdown" then
			return
		end
		phase = "Racing"
		raceStart = now()
		setAttr("SpinRacePhase", "Racing")
		setAttr("SpinRaceStart", raceStart)
		for key, r in pairs(racers) do
			local character = charOf(r)
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				root.Anchored = false
				character:SetAttribute("RaceAnchored", nil)
			end
			if r.Jockey then
				task.spawn(runJockey, key, r)
			end
		end
		broadcast("Go", { Total = #course.Gates })
	end)
end

local function endRace(reason)
	local results = {}
	for _, r in ipairs(finishOrder) do
		table.insert(results, { Name = r.Name, Place = r.Place, Time = r.Time, Jockey = r.Jockey })
	end
	broadcast("Results", { List = results, Reason = reason })
	cleanup()
end

local function finish(r)
	table.insert(finishOrder, r)
	r.Finished = true
	r.Place = #finishOrder
	r.Time = now() - raceStart
	local prize, partName = 0, nil
	if r.Player then
		-- Prizes go by place among the players.
		local playerPlace = 0
		for _, f in ipairs(finishOrder) do
			if f.Player then
				playerPlace = playerPlace + 1
			end
		end
		local prizes = cfg.Prizes or { 500, 250, 150 }
		prize = prizes[playerPlace] or cfg.FinishPrize or 50
		pay(r.Player, prize)
		if r.Place == 1 and cfg.WinnerCorpsePart ~= false then
			-- A Saint's Corpse part appears at the finish for the winner.
			local ok, C = pcall(function()
				return require(script.Parent.CorpseService)
			end)
			local root = r.Player.Character and r.Player.Character:FindFirstChild("HumanoidRootPart")
			if ok and C and C.summon and root then
				local _, name = C.summon(root.Position + course.StartFacing * 6)
				partName = name
			end
		end
		-- Finished: their horse is theirs to ride around now.
		local character = r.Player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and character:FindFirstChild("RaceHorse") then
			Adapter.setMoveModifier(humanoid, "Horse", hcfg.RideSpeed or 2.8)
			character:SetAttribute("Riding", "Ride")
		end
	end
	if r.Place == 1 then
		winnerAt = now()
	end
	broadcast("Finished", { Name = r.Name, UserId = r.UserId, Place = r.Place, Time = r.Time, Prize = prize, Part = partName, Jockey = r.Jockey })
end

local function standings()
	local list = {}
	for _, r in pairs(racers) do
		local character = charOf(r)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local gate = course.Gates[r.Next]
		local dist = (root and gate) and (Vector3.new(gate.X, 0, gate.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude or 1e6
		table.insert(list, { Name = r.Name, UserId = r.UserId, Next = r.Next, Place = r.Place, Dist = dist, Jockey = r.Jockey })
	end
	table.sort(list, function(a, b)
		if a.Place or b.Place then
			return (a.Place or 1e6) < (b.Place or 1e6)
		end
		if a.Next ~= b.Next then
			return a.Next > b.Next
		end
		return a.Dist < b.Dist
	end)
	local rows = {}
	for i, e in ipairs(list) do
		table.insert(rows, { Name = e.Name, UserId = e.UserId, Position = i, Next = e.Next, Finished = e.Place ~= nil, Dist = math.floor(e.Dist), Jockey = e.Jockey })
	end
	return rows
end

local lastStandings = 0
local function tick()
	local t = now()
	if not phase then
		if t >= nextEntryAt then
			openEntry()
		end
		return
	end
	if phase == "Entry" then
		if t >= entryEnds then
			startRace()
		end
		return
	end
	if phase ~= "Racing" then
		return
	end
	local total = #course.Gates
	local activePlayers = 0
	for key, r in pairs(racers) do
		if not r.Finished then
			local character = charOf(r)
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local gate = course.Gates[r.Next]
			if root and gate then
				if r.Player then
					activePlayers = activePlayers + 1
				end
				local d = (Vector3.new(gate.X, 0, gate.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
				if d <= (cfg.PassRadius or 20) and math.abs(root.Position.Y - gate.Y) < 40 then
					r.Next = r.Next + 1
					if r.Next > total then
						finish(r)
					elseif r.Player then
						send(r.Player, "Gate", { Index = r.Next - 1, Total = total })
					end
				end
			end
		end
	end
	if t - lastStandings >= 0.5 then
		lastStandings = t
		local list = standings()
		for _, r in pairs(racers) do
			if r.Player then
				send(r.Player, "Standings", { List = list, Total = total, Elapsed = t - raceStart })
			end
		end
	end
	-- Ends when no player is still racing, FinishGrace after the winner, or at the time limit.
	if activePlayers == 0 then
		endRace(#finishOrder > 0 and "Everyone's crossed the line." or "Nobody finished.")
	elseif winnerAt and t - winnerAt >= (cfg.FinishGrace or 25) then
		endRace("Time's up for the stragglers.")
	elseif t - raceStart >= (cfg.TimeLimit or 240) then
		endRace("Time's up.")
	end
end

function RaceService.init()
	if cfg.Enabled == false and hcfg.Enabled == false then
		return
	end
	Remote = Net.get("Race")
	Remote.OnServerEvent:Connect(function(player, action)
		if action == "Join" then
			RaceService.join(player)
		elseif action == "Leave" then
			RaceService.leave(player)
		elseif action == "Horse" then
			RaceService.toggleHorse(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		racers[player] = nil
	end)
	-- Going down (or resetting) puts you out of the race; the horse goes with the body.
	local function watchDeath(player, character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				local r = racers[player]
				if r and phase ~= "Entry" and not r.Finished then
					out(player, "You went down: out of the race.")
				end
			end)
		end
	end
	local function hook(player)
		player.CharacterAdded:Connect(function(c)
			task.spawn(watchDeath, player, c)
		end)
		if player.Character then
			task.spawn(watchDeath, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
	if cfg.Enabled == false then
		return -- horses only, no races
	end
	local first = RunService:IsStudio() and (cfg.StudioFirstAfter or 20) or (cfg.FirstAfter or 120)
	nextEntryAt = now() + first
	setAttr("SpinRaceNext", nextEntryAt)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc >= 0.1 then
			acc = 0
			tick()
		end
	end)
end

-- For tests / admin: open entry right now.
function RaceService.openNow()
	if not phase then
		openEntry()
	end
end

return RaceService
```
