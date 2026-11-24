--[[
	HorseModel  (ReplicatedStorage.SpinShared.HorseModel)

	A blocky racehorse for the Steel Ball Run, built from parts (no uploads):
	a long body, an arched neck with a mane, a head with a white blaze, ears
	and a dark muzzle, a swishing tail, four legs with white socks and
	hooves, and full tack: a red saddle blanket, a brown saddle with a horn,
	stirrups and reins.

	HorseModel.build(coat, mane, opts) -> model (PrimaryPart "Body", facing
	-Z, body centre at the origin, hooves 3.85 studs below it, the top of
	the saddle SaddleTop above it). opts (all optional):
	  Width     body width (default 1.9: slim, so a rider's legs go round it)
	  Blanket   saddle blanket colour      Saddle  saddle / tack colour
	  Material  coat material (e.g. Metal for the Golden Steed)
	  Socks     sock colour (false: no socks)
	The server builds race and ride horses; the shop builds a preview. Every limb is
	joined to the body with a Weld; clients animate the gallop by changing
	those welds' C0 (RaceClient). Each animated part carries attributes:
	  Joint (Vector3, where it pivots on the body) and Drop (studs from the
	  pivot down to the part's centre).
]]

local HorseModel = {}
HorseModel.HoofDepth = 3.85 -- studs from the body centre down to the ground
HorseModel.SaddleTop = 1.37 -- studs from the body centre up to the top of the saddle

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

function HorseModel.build(coat, mane, opts)
	opts = opts or {}
	coat = coat or Color3.fromRGB(120, 76, 44)
	mane = mane or Color3.fromRGB(40, 26, 18)
	local W = opts.Width or 1.9
	local k = W / 2.2 -- how much narrower than the old 2.2-wide body
	local shade = coat:Lerp(Color3.new(0, 0, 0), 0.2)
	local white = opts.SockColor or (typeof(opts.Socks) == "Color3" and opts.Socks) or Color3.fromRGB(240, 238, 232)
	local sockStyle = opts.SockStyle or (opts.Socks == false and "None" or "Two")
	local marking = opts.Marking or "Blaze"
	local hoof = Color3.fromRGB(46, 40, 36)
	local leather = opts.Saddle or Color3.fromRGB(96, 58, 32)
	local leatherMaterial = opts.SaddleMaterial
	local blanket = opts.Blanket or Color3.fromRGB(170, 40, 40)
	local metal = Color3.fromRGB(180, 182, 188)
	local coatMaterial = opts.Material

	local model = Instance.new("Model")
	model.Name = "Horse"
	local body = part(model, "Body", Vector3.new(W, 2.0, 5.0), coat, coatMaterial)
	body.CFrame = CFrame.new()
	model.PrimaryPart = body
	-- Rounded barrel: chest and rump blocks, a belly.
	weld(model, body, "Chest", Vector3.new(W + 0.1, 2.1, 1.2), coat, CFrame.new(0, 0.05, -2.3))
	weld(model, body, "Rump", Vector3.new(W + 0.1, 2.1, 1.3), coat, CFrame.new(0, 0.12, 2.2))
	weld(model, body, "Belly", Vector3.new(W - 0.3, 0.4, 3.8), shade, CFrame.new(0, -1.05, 0))
	if coatMaterial then
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") and p ~= body then
				p.Material = coatMaterial
			end
		end
	end

	-- Neck (arched forward), mane along its top, head.
	local neck = jointed(model, body, "Neck", Vector3.new(1.1, 2.6, 1.3), coat, Vector3.new(0, 0.6, -2.6), -1.1, -0.55)
	weld(model, neck, "Mane", Vector3.new(0.35, 2.6, 0.5), mane, CFrame.new(0, 0.05, 0.6))
	local head = weld(model, neck, "Head", Vector3.new(1.0, 1.0, 2.1), coat, CFrame.new(0, 1.35, -0.75) * CFrame.Angles(-0.35, 0, 0))
	weld(model, head, "Muzzle", Vector3.new(0.92, 0.75, 0.6), shade, CFrame.new(0, -0.12, -1.2))
	-- Face marking.
	local faceWhite = Color3.fromRGB(240, 238, 232)
	if marking == "Blaze" then
		weld(model, head, "Blaze", Vector3.new(0.3, 0.06, 1.6), faceWhite, CFrame.new(0, 0.52, -0.3))
	elseif marking == "Star" then
		weld(model, head, "Star", Vector3.new(0.32, 0.06, 0.32), faceWhite, CFrame.new(0, 0.52, 0.2) * CFrame.Angles(0, math.pi / 4, 0))
	elseif marking == "Stripe" then
		weld(model, head, "Stripe", Vector3.new(0.14, 0.06, 1.7), faceWhite, CFrame.new(0, 0.52, -0.35))
	elseif marking == "Bald" then
		weld(model, head, "BaldFace", Vector3.new(0.8, 0.06, 1.9), faceWhite, CFrame.new(0, 0.52, -0.3))
		weld(model, head, "BaldMuzzle", Vector3.new(0.94, 0.4, 0.62), faceWhite, CFrame.new(0, 0.12, -1.2))
	end
	weld(model, head, "Forelock", Vector3.new(0.5, 0.2, 0.5), mane, CFrame.new(0, 0.6, 0.45))
	for _, side in ipairs({ -1, 1 }) do
		weld(model, head, "Ear", Vector3.new(0.2, 0.5, 0.22), coat, CFrame.new(side * 0.32, 0.72, 0.75) * CFrame.Angles(0, 0, side * -0.2))
		weld(model, head, "Eye", Vector3.new(0.06, 0.16, 0.16), Color3.fromRGB(20, 16, 14), CFrame.new(side * 0.51, 0.18, -0.1))
		weld(model, head, "Nostril", Vector3.new(0.06, 0.12, 0.12), Color3.fromRGB(30, 22, 18), CFrame.new(side * 0.47, -0.2, -1.42))
		-- Bridle straps.
		weld(model, head, "Bridle", Vector3.new(0.04, 0.9, 0.08), leather, CFrame.new(side * 0.52, 0.1, 0.1), leatherMaterial)
	end
	weld(model, head, "Noseband", Vector3.new(1.0, 0.1, 0.1), leather, CFrame.new(0, -0.05, -0.85), leatherMaterial)

	-- Tail.
	local tail = jointed(model, body, "Tail", Vector3.new(0.5, 2.3, 0.5), mane, Vector3.new(0, 0.7, 2.85), 1.1, -0.55)
	weld(model, tail, "TailTip", Vector3.new(0.6, 0.6, 0.6), mane, CFrame.new(0, -1.2, 0.05))

	-- Legs: thigh-to-hoof, socks by style, hooves.
	local socksOn = {
		None = {},
		Two = { LegFL = true, LegBR = true },
		Front = { LegFL = true, LegFR = true },
		Back = { LegBL = true, LegBR = true },
		Four = { LegFL = true, LegFR = true, LegBL = true, LegBR = true },
	}
	local on = socksOn[sockStyle] or socksOn.Two
	local legs = {
		{ "LegFL", Vector3.new(-0.6 * k, -0.75, -1.9) },
		{ "LegFR", Vector3.new(0.6 * k, -0.75, -1.9) },
		{ "LegBL", Vector3.new(-0.6 * k, -0.75, 1.9) },
		{ "LegBR", Vector3.new(0.6 * k, -0.75, 1.9) },
	}
	for _, l in ipairs(legs) do
		local leg = jointed(model, body, l[1], Vector3.new(0.55, 2.8, 0.6), coat, l[2], 1.4, 0)
		weld(model, leg, "Thigh", Vector3.new(0.7, 1.0, 0.75), coat, CFrame.new(0, 0.85, 0))
		if on[l[1]] then
			weld(model, leg, "Sock", Vector3.new(0.6, 0.7, 0.65), white, CFrame.new(0, -0.95, 0))
		end
		weld(model, leg, "Hoof", Vector3.new(0.62, 0.32, 0.7), hoof, CFrame.new(0, -1.5, -0.04))
	end

	-- Tack: blanket, saddle with a horn, stirrups, reins.
	weld(model, body, "Blanket", Vector3.new(W + 0.2, 0.14, 2.3), blanket, CFrame.new(0, 1.04, -0.1))
	weld(model, body, "BlanketEdge", Vector3.new(W + 0.3, 0.6, 0.1), blanket:Lerp(Color3.new(1, 1, 1), 0.2), CFrame.new(0, 0.8, -1.25))
	for _, side in ipairs({ -1, 1 }) do
		weld(model, body, "BlanketSide", Vector3.new(0.1, 0.8, 2.2), blanket, CFrame.new(side * (W / 2 + 0.06), 0.6, -0.1))
	end
	weld(model, body, "Saddle", Vector3.new(W - 0.4, 0.3, 1.7), leather, CFrame.new(0, 1.22, -0.1), leatherMaterial)
	weld(model, body, "Cantle", Vector3.new(1.4, 0.35, 0.25), leather, CFrame.new(0, 1.45, 0.65), leatherMaterial)
	weld(model, body, "Horn", Vector3.new(0.25, 0.45, 0.25), leather, CFrame.new(0, 1.55, -0.8), leatherMaterial)
	for _, side in ipairs({ -1, 1 }) do
		weld(model, body, "Strap", Vector3.new(0.05, 1.3, 0.12), leather, CFrame.new(side * (W / 2 + 0.13), 0.55, -0.1), leatherMaterial)
		weld(model, body, "Stirrup", Vector3.new(0.12, 0.12, 0.5), metal, CFrame.new(side * (W / 2 + 0.16), -0.15, -0.1), Enum.Material.Metal)
		weld(model, body, "Rein", Vector3.new(0.05, 0.05, 3.4), leather, CFrame.new(side * 0.45, 2.0, -2.4) * CFrame.Angles(0.33, 0, 0))
	end
	return model
end

-- The horse a stable selection describes (used by the server and the shop's
-- preview, so they always match). cat = TuskConfig.Horses; sel = { Coat,
-- Mane, Blanket, Saddle, Marking, Socks }.
-- Returns coat colour, mane colour, opts for HorseModel.build.
local function pick(list, id)
	for _, item in ipairs(list or {}) do
		if item.Id == id then
			return item
		end
	end
	return (list or {})[1]
end

-- A player's stable selection, from their attributes (HorseCoat, HorseMane,
-- HorseBlanket, HorseSaddle, HorseMarking, HorseSocks).
function HorseModel.selectionOf(player)
	return {
		Coat = player and player:GetAttribute("HorseCoat"),
		Mane = player and player:GetAttribute("HorseMane"),
		Blanket = player and player:GetAttribute("HorseBlanket"),
		Saddle = player and player:GetAttribute("HorseSaddle"),
		Marking = player and player:GetAttribute("HorseMarking"),
		Socks = player and player:GetAttribute("HorseSocks"),
	}
end

function HorseModel.lookFrom(cat, sel)
	cat, sel = cat or {}, sel or {}
	local coat = pick(cat.Coats, sel.Coat) or {}
	local maneItem = pick(cat.Manes, sel.Mane)
	local blanket = pick(cat.Blankets, sel.Blanket)
	local saddle = pick(cat.Saddles, sel.Saddle)
	local marking = pick(cat.Markings, sel.Marking)
	local socks = pick(cat.Socks, sel.Socks)
	local mane = (maneItem and maneItem.Color) or coat.Mane
	local opts = {
		Width = 1.9,
		Material = coat.Material and Enum.Material[coat.Material] or nil,
		Blanket = blanket and blanket.Color,
		Saddle = saddle and saddle.Color,
		SaddleMaterial = saddle and saddle.Material and Enum.Material[saddle.Material] or nil,
		Marking = marking and marking.Style or "Blaze",
		SockStyle = coat.Socks == false and (socks and socks.Style == "Two" and "None" or (socks and socks.Style)) or (socks and socks.Style or "Two"),
	}
	return coat.Body, mane, opts
end

return HorseModel
