--[[
	HitFX  (StarterPlayerScripts.SpinClient.HitFX)
	Feedback for every hit in the game (any character):
	  * victim flash (white, or blue when blocked) + camera shake for the victim
	  * floating damage numbers for the attacker
	Driven by the shared "Hit" / "Damage" events from CombatAdapter.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SpinShared")
local Net = require(Shared.Net)
local VFXLib = require(script.Parent.VFXLib)
local CameraFX = require(script.Parent.CameraFX)

local TuskVFX = require(script.Parent.TuskVFX)

local HitFX = {}
local localPlayer = Players.LocalPlayer
local colors = {
	Gold = Color3.fromRGB(255, 196, 56),
	Perfect = Color3.fromRGB(255, 250, 210),
	GoldLight = Color3.fromRGB(255, 238, 160),
}

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
	-- Starburst coloured by who landed it: cyan for Johnny, green for Gyro, blue for Diego, bamboo green for Pork Pie Hat Kid.
	local source = tostring(data.Source or "")
	local starColor = Color3.fromRGB(90, 230, 255)
	if source:sub(1, 4) == "Gyro" then
		starColor = Color3.fromRGB(120, 225, 95)
	elseif source:sub(1, 4) == "Kira" then
		starColor = Color3.fromRGB(255, 160, 80)
	elseif source:sub(1, 7) == "Josuke4" then
		starColor = Color3.fromRGB(255, 130, 200)
	elseif source:sub(1, 7) == "Requiem" then
		starColor = Color3.fromRGB(190, 160, 255)
	elseif source:sub(1, 9) == "Polnareff" then
		starColor = Color3.fromRGB(220, 232, 250)
	elseif source:sub(1, 6) == "Joseph" then
		starColor = Color3.fromRGB(255, 214, 80)
	elseif source:sub(1, 3) == "Dio" then
		starColor = Color3.fromRGB(255, 210, 70)
	elseif source:sub(1, 6) == "Jotaro" then
		starColor = Color3.fromRGB(170, 150, 255)
	elseif source:sub(1, 5) == "Ringo" then
		starColor = Color3.fromRGB(246, 204, 40)
	elseif source:sub(1, 7) == "JohnRod" then
		starColor = Color3.fromRGB(220, 230, 250)
	elseif source:sub(1, 5) == "Jodio" then
		starColor = Color3.fromRGB(110, 190, 250)
	elseif source:sub(1, 5) == "Tooru" then
		starColor = Color3.fromRGB(240, 196, 60)
	elseif source:sub(1, 6) == "Josuke" then
		starColor = Color3.fromRGB(120, 190, 240)
	elseif source:sub(1, 7) == "DiegoAU" then
		starColor = Color3.fromRGB(236, 196, 70)
	elseif source:sub(1, 5) == "Diego" then
		starColor = Color3.fromRGB(60, 120, 255)
	elseif source:sub(1, 7) == "PorkPie" then
		starColor = Color3.fromRGB(165, 215, 80)
	elseif source:sub(1, 7) == "Sandman" then
		starColor = Color3.fromRGB(245, 185, 80)
	elseif source:sub(1, 11) == "MountainTim" then
		starColor = Color3.fromRGB(214, 156, 84)
	elseif source:sub(1, 8) == "HotPants" then
		starColor = Color3.fromRGB(242, 140, 172)
	elseif source:sub(1, 9) == "Blackmore" then
		starColor = Color3.fromRGB(110, 180, 255)
	elseif source:sub(1, 9) == "Valentine" then
		starColor = Color3.fromRGB(120, 170, 255)
	elseif source:sub(1, 3) == "Axl" then
		starColor = Color3.fromRGB(214, 60, 70)
	end
	if data.Perfect then
		starColor = colors.Gold
	end
	if data.Position and not data.Blocked then
		TuskVFX.CreateImpactStar(data.Position, { Size = 2.2 + (data.Level or 1) * 0.9, Rays = 6 + (data.Level or 1), Color = starColor, Color2 = Color3.new(1, 1, 1), Duration = 0.18 + (data.Level or 1) * 0.03 })
		-- Sparks thrown away from the attacker, a quick shock ring, a white pop.
		local away
		local attacker = data.AttackerId and Players:GetPlayerByUserId(data.AttackerId)
		local ar = attacker and attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
		if ar then
			local d = data.Position - ar.Position
			away = d.Magnitude > 0.1 and d.Unit or nil
		end
		VFXLib.burst(data.Position, { Count = 10, Color = starColor, Speed = 34, Lifetime = 0.28, Spread = away and 40 or 180, Direction = away, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) }) })
		VFXLib.burst(data.Position, { Count = 4, Color = Color3.new(1, 1, 1), Speed = 6, Lifetime = 0.12, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) }) })
		local look = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or data.Position + Vector3.new(0, 0, 1)
		TuskVFX.CreateRotationalShockwave(CFrame.lookAt(data.Position, look) * CFrame.Angles(math.pi / 2, 0, 0), { Radius = 2.6, Layers = 1, Color = starColor, Color2 = Color3.new(1, 1, 1), Particles = 0, Width = 0.12, Duration = 0.18 })
		-- Your own hits kick the camera a little.
		if data.AttackerId == localPlayer.UserId then
			CameraFX.shake(0.12 + (data.Level or 1) * 0.05, 0.12)
		end
	end
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
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.Rotation = (math.random() - 0.5) * 16
	label.Text = data.Blocked and ("BLOCKED " .. data.Amount) or (tostring(data.Amount) .. (data.Perfect and "!" or ""))
	label.TextColor3 = data.Blocked and Color3.fromRGB(170, 200, 230) or (data.Perfect and colors.Perfect or colors.Gold)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(60, 25, 0)
	label.Parent = billboard
	local start = carrier.Position
	local drift = Vector3.new((math.random() - 0.5) * 2, 0, (math.random() - 0.5) * 2)
	-- Bigger hits get bigger, redder numbers.
	local amount = tonumber(data.Amount) or 0
	local big = math.clamp((amount - 4) / 10, 0, 1)
	if not data.Blocked and not data.Perfect then
		label.TextColor3 = colors.Gold:Lerp(Color3.fromRGB(255, 80, 60), big)
	end
	local scale = 1 + big * 0.6
	VFXLib.animate(1, function(a)
		carrier.Position = start + drift * a + Vector3.new(0, a * 3 - a * a * 1.2, 0)
		label.TextTransparency = math.max(0, (a - 0.6) / 0.4)
		label.TextStrokeTransparency = label.TextTransparency
		local pop = a < 0.1 and (1 + (0.1 - a) * 4) or 1
		billboard.Size = UDim2.fromOffset(160 * pop * scale * (data.Perfect and 1.3 or 1), 60 * pop * scale * (data.Perfect and 1.3 or 1))
	end)
end

function HitFX.init()
	Net.get("SpinFX").OnClientEvent:Connect(function(name, data)
		if name == "Hit" then
			onHit(data)
		elseif name == "Damage" then
			onDamage(data)
		end
	end)
end

return HitFX
