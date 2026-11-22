import sys
from lupa import LuaRuntime
act=int(sys.argv[1]); out=sys.argv[2]
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute(open("robloxmock.lua").read())
src="/home/user/liamhughey2012-pixel/steel-ball-run/src/shared/"
# load TuskConfig + TuskStandModels with a fake `script`
lua.execute("""
TuskConfigSrc, ModelsSrc = ...
""") if False else None
cfg=open(src+"TuskConfig.lua").read()
mdl=open(src+"TuskStandModels.lua").read()
lua.globals().CFG_SRC=cfg; lua.globals().MDL_SRC=mdl
lua.execute("""
local TuskConfig = load(CFG_SRC)()
local env = setmetatable({}, {__index=_G})
env.script = { Parent = { TuskConfig = "CFG", FindFirstChild = function() return nil end } }
env.require = function(x) return TuskConfig end
local chunk = load(MDL_SRC, "models", "t", env)
Models = chunk()
""")
lua.execute(f"local m, rig = Models.build({act}, 1)")
open(out,"w").write(lua.eval("dumpParts()"))
