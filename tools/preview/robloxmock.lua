-- Minimal Roblox math + Instance mock for running model builders outside Studio.
local V = {}
V.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X*t.X + t.Y*t.Y + t.Z*t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X*t.X + t.Y*t.Y + t.Z*t.Z); if m == 0 then return t end return Vector3.new(t.X/m, t.Y/m, t.Z/m) end
	return V[k]
end
Vector3 = {}
function Vector3.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end
V.__add = function(a, b) return Vector3.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
V.__sub = function(a, b) return Vector3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
V.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then return Vector3.new(a*b.X, a*b.Y, a*b.Z) end
	if type(b) == "number" then return Vector3.new(a.X*b, a.Y*b, a.Z*b) end
	return Vector3.new(a.X*b.X, a.Y*b.Y, a.Z*b.Z)
end
V.__div = function(a, b) if type(b) == "number" then return Vector3.new(a.X/b, a.Y/b, a.Z/b) end return Vector3.new(a.X/b.X, a.Y/b.Y, a.Z/b.Z) end
V.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
function V.Dot(a, b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end
function V.Cross(a, b) return Vector3.new(a.Y*b.Z - a.Z*b.Y, a.Z*b.X - a.X*b.Z, a.X*b.Y - a.Y*b.X) end
function V.Lerp(a, b, t) return a + (b - a) * t end

-- CFrame: position p + rotation columns r (right), u (up), b (back = -look)
local C = {}
C.__index = function(t, k)
	if k == "Position" or k == "p" then return t.pos end
	if k == "X" then return t.pos.X end
	if k == "Y" then return t.pos.Y end
	if k == "Z" then return t.pos.Z end
	if k == "RightVector" then return t.r end
	if k == "UpVector" then return t.u end
	if k == "LookVector" then return -t.b end
	return C[k]
end
CFrame = {}
local function mk(pos, r, u, b) return setmetatable({ pos = pos, r = r, u = u, b = b }, C) end
function CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	if type(x) == "table" and y == nil then return mk(x, Vector3.new(1,0,0), Vector3.new(0,1,0), Vector3.new(0,0,1)) end
	if type(x) == "table" and type(y) == "table" then return CFrame.lookAt(x, y) end
	if r00 then return mk(Vector3.new(x,y,z), Vector3.new(r00,r10,r20), Vector3.new(r01,r11,r21), Vector3.new(r02,r12,r22)) end
	return mk(Vector3.new(x or 0, y or 0, z or 0), Vector3.new(1,0,0), Vector3.new(0,1,0), Vector3.new(0,0,1))
end
local function rotX(a) local c, s = math.cos(a), math.sin(a) return mk(Vector3.new(), Vector3.new(1,0,0), Vector3.new(0,c,s), Vector3.new(0,-s,c)) end
local function rotY(a) local c, s = math.cos(a), math.sin(a) return mk(Vector3.new(), Vector3.new(c,0,-s), Vector3.new(0,1,0), Vector3.new(s,0,c)) end
local function rotZ(a) local c, s = math.cos(a), math.sin(a) return mk(Vector3.new(), Vector3.new(c,s,0), Vector3.new(-s,c,0), Vector3.new(0,0,1)) end
function CFrame.Angles(x, y, z) return rotX(x) * rotY(y) * rotZ(z) end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromMatrix(pos, vx, vy, vz)
	vz = vz or vx:Cross(vy).Unit
	return mk(pos, vx, vy, vz)
end
function CFrame.lookAt(at, target, up)
	up = up or Vector3.new(0, 1, 0)
	local look = (target - at).Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then right = look:Cross(Vector3.new(0, 0, 1)) end
	right = right.Unit
	local u = right:Cross(look).Unit
	return mk(at, right, u, -look)
end
function C.VectorToWorldSpace(cf, v) return cf.r * v.X + cf.u * v.Y + cf.b * v.Z end
function C.PointToWorldSpace(cf, v) return cf.pos + cf:VectorToWorldSpace(v) end
C.__mul = function(a, b)
	if getmetatable(b) == V then return a:PointToWorldSpace(b) end
	return mk(a:PointToWorldSpace(b.pos), a:VectorToWorldSpace(b.r), a:VectorToWorldSpace(b.u), a:VectorToWorldSpace(b.b))
end
C.__add = function(a, v) return mk(a.pos + v, a.r, a.u, a.b) end
C.__sub = function(a, v) return mk(a.pos - v, a.r, a.u, a.b) end
function C.Inverse(cf)
	local r, u, b = cf.r, cf.u, cf.b
	local rot = mk(Vector3.new(), Vector3.new(r.X, u.X, b.X), Vector3.new(r.Y, u.Y, b.Y), Vector3.new(r.Z, u.Z, b.Z))
	return mk(-rot:VectorToWorldSpace(cf.pos), rot.r, rot.u, rot.b)
end

Color3 = {}
function Color3.new(r, g, b) return { R = r, G = g, B = b, __c3 = true } end
function Color3.fromRGB(r, g, b) return Color3.new(r/255, g/255, b/255) end

local function anyEnum() return setmetatable({}, { __index = function(t, k) local v = setmetatable({ Name = k }, { __index = function(t2, k2) return { Name = k2 } end }); rawset(t, k, v); return v end }) end
Enum = anyEnum()

ALL_PARTS = {}
local Inst = {}
Inst.__index = function(t, k)
	if Inst[k] then return Inst[k] end
	if k == "Position" then local cf = rawget(t, "CFrame"); return cf and cf.pos end
	return nil
end
function Inst.GetDescendants(self)
	local out = {}
	local function walk(o) for _, c in ipairs(o._children) do table.insert(out, c); walk(c) end end
	walk(self)
	return out
end
function Inst.GetChildren(self) return self._children end
function Inst.IsA(self, cls)
	if cls == "BasePart" then return self.ClassName == "Part" or self.ClassName == "WedgePart" end
	if cls == "LuaSourceContainer" then return false end
	return self.ClassName == cls
end
function Inst.FindFirstChild(self, n) for _, c in ipairs(self._children) do if c.Name == n then return c end end end
function Inst.Destroy(self) end
function Inst.Clone(self) return self end
Inst.__newindex = function(t, k, v)
	if k == "Parent" then
		local old = rawget(t, "_parent")
		rawset(t, "_parent", v)
		if v then table.insert(v._children, t) end
		return
	end
	rawset(t, k, v)
end
Instance = {}
function Instance.new(cls)
	local o = setmetatable({ ClassName = cls, Name = cls, _children = {}, Size = Vector3.new(4, 1, 2), CFrame = CFrame.new(), Transparency = 0 }, Inst)
	if cls == "Part" or cls == "WedgePart" then table.insert(ALL_PARTS, o) end
	return o
end
game = { GetService = function() return { FindFirstChild = function() return nil end } end }

function dumpParts()
	local out = {}
	for _, p in ipairs(ALL_PARTS) do
		if p._parent and (rawget(p, "Transparency") or 0) < 1 then
			local mesh = false
			for _, c in ipairs(p._children) do if c.ClassName == "SpecialMesh" then mesh = true end end
			local shape = p.Shape and p.Shape.Name or "Block"
			if p.ClassName == "WedgePart" then shape = "Wedge" end
			if mesh then shape = "Ellipsoid" end
			local cf = p.CFrame
			local col = p.Color or Color3.new(0.6, 0.6, 0.6)
			table.insert(out, string.format("%s %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %s",
				shape, p.Size.X, p.Size.Y, p.Size.Z, cf.pos.X, cf.pos.Y, cf.pos.Z,
				cf.r.X, cf.r.Y, cf.r.Z, cf.u.X, cf.u.Y, cf.u.Z, cf.b.X, cf.b.Y, cf.b.Z,
				col.R, col.G, col.B, (p.Material and p.Material.Name) or "SmoothPlastic"))
		end
	end
	return table.concat(out, "\n")
end
ColorSequence = { new = function(...) return { ... } end }
NumberSequence = { new = function(...) return { ... } end }
NumberSequenceKeypoint = { new = function(...) return { ... } end }
NumberRange = { new = function(...) return { ... } end }
Vector2 = { new = function(x, y) return { X = x, Y = y } end }
