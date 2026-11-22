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
blk=open(src+"Blockify.lua").read()
lua.globals().CFG_SRC=cfg; lua.globals().MDL_SRC=mdl; lua.globals().BLK_SRC=blk
lua.execute("""
local TuskConfig = load(CFG_SRC)()
local env = setmetatable({}, {__index=_G})
local Blockify = load(BLK_SRC)()
env.script = { Parent = { TuskConfig = "CFG", Blockify = "BLK", FindFirstChild = function() return nil end } }
env.require = function(x) if x == "BLK" then return Blockify end return TuskConfig end
local chunk = load(MDL_SRC, "models", "t", env)
Models = chunk()
""")
lua.execute(f"local m, rig = Models.build({act}, 1)")
open(out,"w").write(lua.eval("dumpParts()"))
