---
tags: [code, client]
type: ModuleScript
location: "StarterPlayer › StarterPlayerScripts › SpinClient"
updated: 2026-11-22
---
# RequiemClient

| | |
|---|---|
| **Type** | ModuleScript |
| **Put it in** | `StarterPlayer › StarterPlayerScripts › SpinClient` |
| **Exact name** | `RequiemClient` (capitals matter) |

**What it does:** Client side of THE REQUIEM ARROW (server: ArrowService). when one turns up: a wooden sign drops in at the top of everyone's screen ("A REQUIEM ARROW HAS APPEARED · SOMEWHERE IN THE DESERT") and a letterboxed title card. Where it is is never shown. when someone takes it, everyone hears who POLNAREFF: an arrow streaks down out of the sky into Silver Chariot, a dark violet burst, "SILVER CHARIOT REQUIEM" anyone else: "THE ARROW'S BLESSING", and a gold glint round them for as long as it lasts (everyone can see it)

## How to add it
1. In Studio's Explorer, find **SpinClient** (StarterPlayer › StarterPlayerScripts › SpinClient).
2. Right-click it › **Insert Object** › **ModuleScript**.
3. Rename it to **RequiemClient**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
--[[
	RequiemClient  (StarterPlayerScripts.SpinClient.RequiemClient)

	Client side of THE REQUIEM ARROW (server: ArrowService).
	  * when one turns up: a wooden sign drops in at the top of everyone's
	    screen ("A REQUIEM ARROW HAS APPEARED · SOMEWHERE IN THE DESERT")
	    and a letterboxed title card. Where it is is never shown.
	  * when someone takes it, everyone hears who
	  * POLNAREFF: an arrow streaks down out of the sky into Silver Chariot,
	    a dark violet burst, "SILVER CHARIOT REQUIEM"
	  * anyone else: "THE ARROW'S BLESSING", and a gold glint round them
	    for as long as it lasts (everyone can see it)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local TuskConfig = require(Shared.TuskConfig)
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)
local CameraFX = require(script.Parent.CameraFX)
local TuskVFX = require(script.Parent.TuskVFX)
local Fighters = require(script.Parent.Fighters)
local Cinematic = require(script.Parent.Cinematic)
local UITheme = require(script.Parent.UI.UITheme)
local C = UITheme.C

local RequiemClient = {}
local player = Players.LocalPlayer
local VIOLET = Color3.fromRGB(170, 120, 240)
local GOLD = Color3.fromRGB(255, 214, 110)

local gui, sign, signTitle, signSub
local signToken = 0

local function buildUI()
	gui = UITheme.new("ScreenGui", { Name = "SpinRequiem", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 12 }, player:WaitForChild("PlayerGui"))
	sign = UITheme.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -120), Size = UDim2.fromOffset(460, 70), Visible = false }, gui)
	UITheme.wood(sign, { Planks = 2, Border = 4, Brackets = true, BracketSize = 12 })
	UITheme.new("UISizeConstraint", { MaxSize = Vector2.new(460, 70) }, sign)
	signTitle = UITheme.label(sign, { Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 36), Text = "", Font = UITheme.Font.Title, TextColor3 = VIOLET, TextStrokeTransparency = 0.3, TextStrokeColor3 = C.WOOD_EDGE, ZIndex = 4 })
	signSub = UITheme.label(sign, { Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 18), Text = "", Font = UITheme.Font.Body, TextColor3 = C.PAPER, ZIndex = 4 })
end

-- A sign drops in at the top of the screen for a few seconds.
local function announce(title, sub, color, hold)
	if not sign then
		return
	end
	signToken = signToken + 1
	local token = signToken
	signTitle.Text = title
	signTitle.TextColor3 = color or VIOLET
	signSub.Text = sub or ""
	sign.Visible = true
	sign.Position = UDim2.new(0.5, 0, 0, -120)
	TweenService:Create(sign, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 58) }):Play()
	task.delay(hold or 6, function()
		if signToken == token then
			TweenService:Create(sign, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -120) }):Play()
			task.delay(0.35, function()
				if signToken == token then
					sign.Visible = false
				end
			end)
		end
	end)
end
RequiemClient.announce = announce

-- An arrow streaks down out of the sky into Silver Chariot.
local function pierce(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local function standPoint()
		local r = character:FindFirstChild("HumanoidRootPart")
		return r and (r.CFrame * CFrame.new(2.2, 2, 2.6)).Position or root.Position
	end
	local from = standPoint() + Vector3.new(-30, 60, -20)
	local shaft = VFXLib.part({ Size = Vector3.new(0.2, 0.2, 3.4), Color = Color3.fromRGB(120, 82, 46), Material = Enum.Material.Wood, Transparency = 0 })
	local head = VFXLib.part({ Size = Vector3.new(0.6, 0.6, 0.15), Color = Color3.fromRGB(214, 170, 64), Material = Enum.Material.Metal, Transparency = 0 })
	local trail = VFXLib.part({ Size = Vector3.new(0.3, 0.3, 8), Color = VIOLET, Transparency = 0.4 })
	VFXLib.animate(0.8, function(a)
		local to = standPoint()
		local e = a * a
		local p = from:Lerp(to, e)
		local dir = (to - from).Unit
		local cf = CFrame.lookAt(p, p + dir)
		shaft.CFrame = cf * CFrame.new(0, 0, 1.7)
		head.CFrame = cf * CFrame.Angles(0, 0, math.pi / 4)
		trail.CFrame = cf * CFrame.new(0, 0, 6)
	end, function()
		shaft:Destroy()
		head:Destroy()
		trail:Destroy()
		local at = standPoint()
		VFXLib.flash(at, VIOLET, 10, 40, 0.4)
		TuskVFX.CreateRotationalShockwave(CFrame.new(at - Vector3.new(0, 3, 0)), { Radius = 16, Layers = 3, Color = VIOLET, Color2 = GOLD, Ground = true, Particles = 2, Width = 0.6 })
		TuskVFX.CreateImpactStar(at, { Size = 8, Rays = 10, Color = VIOLET, Color2 = Color3.new(1, 1, 1), Duration = 0.4 })
		VFXLib.burst(at, { Count = 40, Color = Color3.fromRGB(60, 40, 90), Speed = 24, Lifetime = 1.0 })
		local r = character:FindFirstChild("HumanoidRootPart")
		local mine = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if r and mine and (mine.Position - r.Position).Magnitude < 80 then
			CameraFX.shake(1, 0.5)
		end
	end)
end

local function onEvent(data)
	local phase = data.Phase
	local mine = data.Player == player.UserId
	if phase == "Spawned" then
		announce("A REQUIEM ARROW HAS APPEARED", "SOMEWHERE IN THE DESERT · IT'S ON THE BOUNTY BOARD", VIOLET, 8)
		Cinematic.title("SOMETHING HAS APPEARED", "THE REQUIEM ARROW", VIOLET, "SOMEWHERE IN THE DESERT", 2.4)
	elseif phase == "Vanished" then
		announce("THE ARROW HAS VANISHED", "ANOTHER ONE WILL TURN UP...", C.PAPER, 4)
	elseif phase == "Requiem" then
		local stand = tostring(data.Stand or "SILVER CHARIOT")
		local becomes = tostring(data.Becomes or "SILVER CHARIOT REQUIEM")
		announce(string.upper(tostring(data.Name)) .. " TOOK THE ARROW", stand .. " HAS BECOME " .. becomes, VIOLET, 7)
		if typeof(data.Character) == "Instance" then
			pierce(data.Character)
		end
		-- (Giorno's own transformation is a full cutscene, in GERVFX.)
		if mine and data.Who ~= "Giorno" then
			task.delay(0.8, function()
				Cinematic.title("THE ARROW PIERCES SILVER CHARIOT", "SILVER CHARIOT REQUIEM", VIOLET, "UNTIL YOU GO DOWN", 3)
				TuskVFX.ScreenTint(1.5, { Tint = Color3.fromRGB(160, 120, 220), Brightness = -0.25, Saturation = -0.4, Contrast = 0.2, Release = 0.1, FadeOut = 0.6 })
			end)
		end
	elseif phase == "Blessing" then
		announce(string.upper(tostring(data.Name)) .. " TOOK THE ARROW", "THE ARROW'S BLESSING", GOLD, 6)
		if typeof(data.Character) == "Instance" then
			local r = data.Character:FindFirstChild("HumanoidRootPart")
			if r then
				VFXLib.flash(r.Position, GOLD, 6, 20, 0.3)
				TuskVFX.CreateRotationalShockwave(CFrame.new(r.Position - Vector3.new(0, 2.5, 0)), { Radius = 8, Layers = 2, Color = GOLD, Color2 = VIOLET, Ground = true, Particles = 1, Width = 0.4 })
			end
		end
		if mine then
			Cinematic.title("THE REQUIEM ARROW", "BLESSED", GOLD, "HIT HARDER · TAKE LESS · FASTER · " .. tostring(data.Time or 90) .. " S", 2.6)
		end
	elseif phase == "BlessingOver" and mine then
		announce("THE BLESSING HAS FADED", "", C.PAPER, 3)
	end
end

-- The blessing: a gold glint round whoever has it.
local nextGlint = 0
local function step()
	local t = os.clock()
	if t < nextGlint then
		return
	end
	nextGlint = t + 0.25
	local now = workspace:GetServerTimeNow()
	for _, f in ipairs(Fighters.list()) do
		local character = f.Character
		local r = character and character:FindFirstChild("HumanoidRootPart")
		if r and (character:GetAttribute("ArrowBlessUntil") or 0) > now then
			VFXLib.burst(r.Position + Vector3.new((math.random() - 0.5) * 2, math.random() * 3 - 1, (math.random() - 0.5) * 2), { Count = 2, Color = GOLD, Speed = 2, Lifetime = 0.5 })
		end
	end
end

function RequiemClient.init()
	if (TuskConfig.RequiemArrow or {}).Enabled == false then
		return
	end
	buildUI()
	Net.get("WorldFX").OnClientEvent:Connect(function(name, data)
		if name == "RequiemArrow" and typeof(data) == "table" then
			onEvent(data)
		end
	end)
	game:GetService("RunService").RenderStepped:Connect(step)
end

return RequiemClient
```
