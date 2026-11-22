from lupa import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute(open("robloxmock.lua").read())
lua.globals().SRC=open("/home/user/liamhughey2012-pixel/steel-ball-run/src/server/GyroOutfit.lua").read()
lua.execute("""
local Outfit = load(SRC)()
local char = Instance.new("Model")
local skin = Color3.fromRGB(234, 190, 150)
local purple, pants = Color3.fromRGB(102, 64, 150), Color3.fromRGB(70, 46, 110)
local function p(name, size, pos, color)
  local x = Instance.new("Part"); x.Name = name; x.Size = size; x.CFrame = CFrame.new(pos); x.Color = color; x.Parent = char; return x
end
p("Head", Vector3.new(1.2,1.2,1.2), Vector3.new(0,5.3,0), skin)
p("UpperTorso", Vector3.new(2,1.6,1), Vector3.new(0,3.95,0), purple)
p("LowerTorso", Vector3.new(2,0.4,1), Vector3.new(0,2.95,0), purple)
for _, s in ipairs({-1, 1}) do
  local side = s < 0 and "Left" or "Right"
  p(side.."UpperArm", Vector3.new(1,1.2,1), Vector3.new(s*1.5,4.15,0), purple)
  p(side.."LowerArm", Vector3.new(1,1.1,1), Vector3.new(s*1.5,3.0,0), purple)
  p(side.."Hand", Vector3.new(1,0.3,1), Vector3.new(s*1.5,2.3,0), skin)
  p(side.."UpperLeg", Vector3.new(1,1.2,1), Vector3.new(s*0.5,2.15,0), pants)
  p(side.."LowerLeg", Vector3.new(1,1.15,1), Vector3.new(s*0.5,0.95,0), pants)
  p(side.."Foot", Vector3.new(1,0.3,1), Vector3.new(s*0.5,0.2,0), pants)
end
Outfit.apply(char)
""")
open("gyro.txt","w").write(lua.eval("dumpParts()"))
