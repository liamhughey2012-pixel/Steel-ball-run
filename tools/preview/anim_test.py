from lupa import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute(open("robloxmock.lua").read())
src="/home/user/liamhughey2012-pixel/steel-ball-run/src/"
for k,v in {"CFG":"shared/TuskConfig.lua","VQ":"shared/VFXQuality.lua","VFX":"client/VFXLib.lua","JC":"client/JointCache.lua","ANIM":"client/TuskAnimation.lua"}.items():
    lua.globals()[k]=open(src+v).read()
out=lua.execute("""
CLOCK = 0
warn = function(...) print("WARN", ...) end
os.clock = function() return CLOCK end
local steps = {}
local function signal() return { Connect = function(_, f) table.insert(steps, f); return { Disconnect = function() end } end } end
Instance_new_orig = Instance.new
local function inst(name) local f = Instance.new("Folder"); f.Name = name; return f end
workspace = inst("Workspace")
local services = {
  RunService = { RenderStepped = signal(), Heartbeat = signal(), BindToRenderStep = function() end },
  Players = { LocalPlayer = { CharacterRemoving = signal() } },
  Debris = { AddItem = function() end },
}
local shared = inst("SpinShared")
services.ReplicatedStorage = { WaitForChild = function() return shared end }
game = { GetService = function(_, n) return services[n] end }
function Inst.WaitForChild(self, n) return self:FindFirstChild(n) end
local loaded = {}
local function load_module(name, code, scriptParent)
  local env = setmetatable({}, { __index = _G })
  env.script = { Parent = scriptParent }
  env.require = function(x) return loaded[x.Name or x] end
  local fn = assert(load(code, name, "t", env))
  loaded[name] = fn()
  return loaded[name]
end
-- module "instances" the code requires by name
local function m(name) return { Name = name } end
shared.TuskConfig = m("TuskConfig"); shared.VFXQuality = m("VFXQuality")
local clientFolder = { VFXLib = m("VFXLib"), JointCache = m("JointCache") }
load_module("TuskConfig", CFG, shared)
load_module("VFXQuality", VQ, shared)
load_module("VFXLib", VFX, clientFolder)
load_module("JointCache", JC, clientFolder)
local Anim = load_module("TuskAnimation", ANIM, clientFolder)

-- R15-ish character with Motor6Ds
local char = Instance.new("Model")
local function part(name) local p = Instance.new("Part"); p.Name = name; p.Parent = char; return p end
local function motor(holder, name, c0)
  local mm = Instance.new("Motor6D"); mm.Name = name; mm.C0 = c0; mm.Parent = holder; return mm
end
part("UpperTorso"); part("LowerTorso"); part("Head"); part("HumanoidRootPart")
local ra = part("RightUpperArm"); local la = part("LeftUpperArm")
local rl = part("RightUpperLeg"); local ll = part("LeftUpperLeg")
local rk = part("RightLowerLeg"); local lk = part("LeftLowerLeg")
local shoulder = motor(ra, "RightShoulder", CFrame.new(1, 0.56, 0))
motor(la, "LeftShoulder", CFrame.new(-1, 0.56, 0))
local waist = motor(char:FindFirstChild("UpperTorso"), "Waist", CFrame.new(0, 0.2, 0))
local root = motor(char:FindFirstChild("LowerTorso"), "Root", CFrame.new(0, -1, 0))
motor(char:FindFirstChild("Head"), "Neck", CFrame.new(0, 0.8, 0))
local hip = motor(rl, "RightHip", CFrame.new(0.5, -0.2, 0))
motor(ll, "LeftHip", CFrame.new(-0.5, -0.2, 0))
motor(rk, "RightKnee", CFrame.new(0, -0.4, 0)); motor(lk, "LeftKnee", CFrame.new(0, -0.4, 0))
function Inst.IsA(self, cls)
  if cls == "BasePart" then return self.ClassName == "Part" end
  return self.ClassName == cls
end

local function look(mm) local c = mm.C0; return string.format("look=(%.2f,%.2f,%.2f) up=(%.2f,%.2f,%.2f) y=%.2f", -c.b.X, -c.b.Y, -c.b.Z, c.u.X, c.u.Y, c.u.Z, c.pos.Y) end
local log = {}
local function run(seconds)
  local t = 0
  while t < seconds do
    CLOCK = CLOCK + 1/60; t = t + 1/60
    for _, f in ipairs(steps) do f(1/60) end
  end
end
print("steps connected:", #steps)
local h = char:FindFirstChild("RightUpperArm"); print("holder", h and h.Name, "motor", h and h:FindFirstChild("RightShoulder"), h and h:FindFirstChild("RightShoulder") and h:FindFirstChild("RightShoulder"):IsA("Motor6D"))
print("rig UpperTorso:", char:FindFirstChild("UpperTorso"))
Anim.play(char, "G_M1_3")    -- Gyro front kick
run(0.12)
table.insert(log, "kick @0.12s  hip " .. look(hip) .. " | root " .. look(root))
run(0.4)
table.insert(log, "kick done    hip " .. look(hip))
Anim.play(char, "GyroThrow")
run(0.14)
table.insert(log, "pitch back   shoulder " .. look(shoulder) .. " | waist " .. look(waist))
run(0.1)
table.insert(log, "pitch release shoulder " .. look(shoulder))
run(0.6)
table.insert(log, "after        shoulder " .. look(shoulder))
Anim.hold(char, "GyroIdle")
run(0.3)
table.insert(log, "idle hold    shoulder " .. look(shoulder))
return table.concat(log, "\\n")
""")
print(out)
