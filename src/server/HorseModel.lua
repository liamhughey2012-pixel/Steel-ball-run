--[[
	HorseModel  (ServerScriptService.SpinServer.HorseModel)

	A blocky racehorse for the Steel Ball Run, built from parts (no uploads):
	a long body, an arched neck with a mane, a head with a white blaze, ears
	and a dark muzzle, a swishing tail, four legs with white socks and
	hooves, and full tack: a red saddle blanket, a brown saddle with a horn,
	stirrups and reins.

	HorseModel.build(coat, mane) -> model (PrimaryPart "Body", facing -Z,
	body centre at the origin, hooves 3.85 studs below it). Every limb is
	joined to the body with a Weld; clients animate the gallop by changing
	those welds' C0 (RaceClient). Each animated part carries attributes:
	  Joint (Vector3, where it pivots on the body) and Drop (studs from the
	  pivot down to the part's centre).
]]

local HorseModel = {}
HorseModel.HoofDepth = 3.85 -- studs from the body centre down to the ground

local function part(model, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.Anchored = false
	p.Parent = model
	return p
end

local function weld(model, parent, name, size, color, cf, material)
	local p = part(model, name, size, color, material)
	local w = Instance.new("Weld")
	w.Name = name .. "Weld"
	w.Part0 = parent
	w.Part1 = p
	w.C0 = cf
	w.Parent = p
	p.CFrame = parent.CFrame * cf
	return p, w
end

-- A part that swings round a joint on the body (legs, tail, neck).
local function jointed(model, body, name, size, color, joint, drop, angle)
	local p, w = weld(model, body, name, size, color, CFrame.new(joint) * CFrame.Angles(angle or 0, 0, 0) * CFrame.new(0, -drop, 0))
	p:SetAttribute("Joint", joint)
	p:SetAttribute("Drop", drop)
	p:SetAttribute("Rest", angle or 0)
	return p, w
end

function HorseModel.build(coat, mane)
	coat = coat or Color3.fromRGB(120, 76, 44)
	mane = mane or Color3.fromRGB(40, 26, 18)
	local shade = coat:Lerp(Color3.new(0, 0, 0), 0.2)
	local white = Color3.fromRGB(240, 238, 232)
	local hoof = Color3.fromRGB(46, 40, 36)
	local leather = Color3.fromRGB(96, 58, 32)
	local blanket = Color3.fromRGB(170, 40, 40)
	local metal = Color3.fromRGB(180, 182, 188)

	local model = Instance.new("Model")
	model.Name = "Horse"
	local body = part(model, "Body", Vector3.new(2.2, 2.0, 5.0), coat)
	body.CFrame = CFrame.new()
	model.PrimaryPart = body
	-- Rounded barrel: chest and rump blocks, a belly.
	weld(model, body, "Chest", Vector3.new(2.3, 2.1, 1.2), coat, CFrame.new(0, 0.05, -2.3))
	weld(model, body, "Rump", Vector3.new(2.3, 2.1, 1.3), coat, CFrame.new(0, 0.12, 2.2))
	weld(model, body, "Belly", Vector3.new(1.9, 0.4, 3.8), shade, CFrame.new(0, -1.05, 0))

	-- Neck (arched forward), mane along its top, head with a blaze and muzzle.
	local neck = jointed(model, body, "Neck", Vector3.new(1.1, 2.6, 1.3), coat, Vector3.new(0, 0.6, -2.6), -1.1, -0.55)
	weld(model, neck, "Mane", Vector3.new(0.35, 2.6, 0.5), mane, CFrame.new(0, 0.05, 0.6))
	local head = weld(model, neck, "Head", Vector3.new(1.0, 1.0, 2.1), coat, CFrame.new(0, 1.35, -0.75) * CFrame.Angles(-0.35, 0, 0))
	weld(model, head, "Muzzle", Vector3.new(0.92, 0.75, 0.6), shade, CFrame.new(0, -0.12, -1.2))
	weld(model, head, "Blaze", Vector3.new(0.3, 0.06, 1.6), white, CFrame.new(0, 0.52, -0.3))
	weld(model, head, "Forelock", Vector3.new(0.5, 0.2, 0.5), mane, CFrame.new(0, 0.6, 0.45))
	for _, side in ipairs({ -1, 1 }) do
		weld(model, head, "Ear", Vector3.new(0.2, 0.5, 0.22), coat, CFrame.new(side * 0.32, 0.72, 0.75) * CFrame.Angles(0, 0, side * -0.2))
		weld(model, head, "Eye", Vector3.new(0.06, 0.16, 0.16), Color3.fromRGB(20, 16, 14), CFrame.new(side * 0.51, 0.18, -0.1))
		weld(model, head, "Nostril", Vector3.new(0.06, 0.12, 0.12), Color3.fromRGB(30, 22, 18), CFrame.new(side * 0.47, -0.2, -1.42))
		-- Bridle straps.
		weld(model, head, "Bridle", Vector3.new(0.04, 0.9, 0.08), leather, CFrame.new(side * 0.52, 0.1, 0.1))
	end
	weld(model, head, "Noseband", Vector3.new(1.0, 0.1, 0.1), leather, CFrame.new(0, -0.05, -0.85))

	-- Tail.
	local tail = jointed(model, body, "Tail", Vector3.new(0.5, 2.3, 0.5), mane, Vector3.new(0, 0.7, 2.85), 1.1, -0.55)
	weld(model, tail, "TailTip", Vector3.new(0.6, 0.6, 0.6), mane, CFrame.new(0, -1.2, 0.05))

	-- Legs: thigh-to-hoof, white socks on two of them, dark hooves.
	local legs = {
		{ "LegFL", Vector3.new(-0.6, -0.75, -1.9), true },
		{ "LegFR", Vector3.new(0.6, -0.75, -1.9), false },
		{ "LegBL", Vector3.new(-0.6, -0.75, 1.9), false },
		{ "LegBR", Vector3.new(0.6, -0.75, 1.9), true },
	}
	for _, l in ipairs(legs) do
		local leg = jointed(model, body, l[1], Vector3.new(0.55, 2.8, 0.6), coat, l[2], 1.4, 0)
		weld(model, leg, "Thigh", Vector3.new(0.7, 1.0, 0.75), coat, CFrame.new(0, 0.85, 0))
		if l[3] then
			weld(model, leg, "Sock", Vector3.new(0.6, 0.7, 0.65), white, CFrame.new(0, -0.95, 0))
		end
		weld(model, leg, "Hoof", Vector3.new(0.62, 0.32, 0.7), hoof, CFrame.new(0, -1.5, -0.04))
	end

	-- Tack: blanket, saddle with a horn, stirrups, reins.
	weld(model, body, "Blanket", Vector3.new(2.4, 0.14, 2.3), blanket, CFrame.new(0, 1.04, -0.1))
	weld(model, body, "BlanketEdge", Vector3.new(2.5, 0.6, 0.1), blanket:Lerp(Color3.new(1, 1, 1), 0.2), CFrame.new(0, 0.8, -1.25))
	weld(model, body, "Saddle", Vector3.new(1.7, 0.3, 1.7), leather, CFrame.new(0, 1.22, -0.1))
	weld(model, body, "Cantle", Vector3.new(1.4, 0.35, 0.25), leather, CFrame.new(0, 1.45, 0.65))
	weld(model, body, "Horn", Vector3.new(0.25, 0.45, 0.25), leather, CFrame.new(0, 1.55, -0.8))
	for _, side in ipairs({ -1, 1 }) do
		weld(model, body, "Strap", Vector3.new(0.05, 1.3, 0.12), leather, CFrame.new(side * 1.12, 0.55, -0.1))
		weld(model, body, "Stirrup", Vector3.new(0.12, 0.12, 0.5), metal, CFrame.new(side * 1.15, -0.15, -0.1), Enum.Material.Metal)
		weld(model, body, "Rein", Vector3.new(0.05, 0.05, 3.4), leather, CFrame.new(side * 0.45, 2.0, -2.4) * CFrame.Angles(0.33, 0, 0))
	end
	return model
end

return HorseModel
