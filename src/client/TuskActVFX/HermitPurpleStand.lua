--[[
	TuskActVFX.HermitPurpleStand  (StarterPlayerScripts.SpinClient.TuskActVFX.HermitPurpleStand)

	HERMIT PURPLE (Joseph Joestar): not a figure but thorny purple VINES.
	Fixed to Joseph's right side (Attached: no float, no lag): three vines
	spiral up round his right arm, thorns sticking out all along them, and a
	few loose tendrils curl off at the top and bottom. Purple aura.
	Registered by JosephVFX; the vines that lash out in his moves are drawn
	by JosephVFX itself.
]]

local HermitPurpleStand = {}

local VINE = Color3.fromRGB(140, 70, 190)
local VINE_DARK = Color3.fromRGB(96, 40, 140)
local THORN = Color3.fromRGB(196, 150, 236)

HermitPurpleStand.Aura = Color3.fromRGB(170, 100, 230)
HermitPurpleStand.AuraLight = Color3.fromRGB(230, 200, 255)
-- Round his right arm (from the root).
HermitPurpleStand.Offset = CFrame.new(1.5, 0.45, 0)
HermitPurpleStand.Attached = true

local function newPart(model, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	p.Parent = model
	return p
end

local function weld(model, parent, name, size, color, cf, material)
	local p = newPart(model, name, size, color, material)
	local w = Instance.new("Weld")
	w.Part0 = parent
	w.Part1 = p
	w.C0 = cf
	w.Parent = p
	p.CFrame = parent.CFrame * cf
	return p
end

-- A vine segment from a to b with a thorn or two.
local function segment(model, body, a, b, d, color, thorns)
	local len = (b - a).Magnitude
	if len < 1e-3 then
		return
	end
	local mid = (a + b) / 2
	local seg = weld(model, body, "Vine", Vector3.new(len + d * 0.5, d, d), color, CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0))
	seg.Shape = Enum.PartType.Cylinder
	if thorns then
		-- A thorn sticking out sideways from the middle.
		local out = (b - a):Cross(Vector3.new(0, 1, 0))
		out = out.Magnitude > 1e-3 and out.Unit or Vector3.new(1, 0, 0)
		local tip = mid + out * d * 1.4
		weld(model, body, "Thorn", Vector3.new(d * 0.35, d * 0.35, d * 1.2), THORN, CFrame.lookAt(mid + out * d * 0.6, tip))
	end
end

function HermitPurpleStand.build(scale)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "HermitPurple"
	local rig = { Joints = {} }
	local body = newPart(model, "Body", Vector3.new(0.3, 0.3, 0.3), VINE)
	body.Transparency = 1
	body.Anchored = true
	body.Massless = false
	body.CFrame = CFrame.new()
	model.PrimaryPart = body
	rig.Body = body

	-- Three vines spiralling up round his arm.
	local d = 0.16 * s
	local height, radius, turns = 2.6 * s, 0.68 * s, 2.2
	for v = 0, 2 do
		local last
		local steps = 22
		for k = 0, steps do
			local f = k / steps
			local a = (v / 3 + f * turns) * math.pi * 2
			local r = radius * (1 + math.sin(f * math.pi * 3 + v) * 0.08)
			local p = Vector3.new(math.cos(a) * r, -height / 2 + f * height, math.sin(a) * r)
			if last then
				segment(model, body, last, p, d, v == 1 and VINE_DARK or VINE, k % 2 == 0)
			end
			last = p
		end
	end
	-- Loose tendrils curling off the top and bottom.
	local tendrils = {
		{ Vector3.new(0.4, 1.3, 0.2), Vector3.new(0.9, 1.9, 0.5), Vector3.new(1.2, 2.3, 0.2), Vector3.new(1.0, 2.6, -0.2) },
		{ Vector3.new(-0.3, 1.3, -0.4), Vector3.new(-0.5, 2.0, -0.9), Vector3.new(-0.2, 2.4, -1.2) },
		{ Vector3.new(0.5, -1.3, -0.3), Vector3.new(0.9, -1.8, -0.8), Vector3.new(0.7, -2.2, -1.2), Vector3.new(0.3, -2.1, -1.4) },
		{ Vector3.new(-0.4, -1.3, 0.4), Vector3.new(-0.9, -1.6, 0.9), Vector3.new(-1.2, -1.3, 1.2) },
	}
	for _, t in ipairs(tendrils) do
		for k = 1, #t - 1 do
			segment(model, body, t[k] * s, t[k + 1] * s, d * (1 - k * 0.15), VINE, true)
		end
		local tip = weld(model, body, "Tip", Vector3.new(d, d, d), THORN, CFrame.new(t[#t] * s))
		tip.Shape = Enum.PartType.Ball
	end
	local point = Instance.new("Attachment")
	point.Name = "NailPoint"
	point.Position = Vector3.new(0, -height / 2, -0.3)
	point.Parent = body
	rig.NailPoint = point
	return model, rig
end

return HermitPurpleStand
