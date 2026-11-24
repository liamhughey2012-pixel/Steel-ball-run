"""Builds ready-to-insert Roblox model files from the paste format
(roblox_scripts/format_like_anime_fighters), so nothing has to be pasted:

  roblox_scripts/Insert_into_ServerScriptService.rbxmx
      Spin_Server (Script) + SpinCore folder (SpinCore_Server_N) + SpinCharacters folder (<Name>_Server)
  roblox_scripts/Insert_into_ReplicatedStorage.rbxmx
      TuskConfig, SpinConfig + SpinCore folder (SpinCore_Client_N) + SpinCharacters folder (<Name>_Client)
  roblox_scripts/Insert_into_StarterPlayerScripts.rbxmx
      Spin_Client (LocalScript)

In Studio: right-click the service > Insert from File... > pick the file.
Run after tools/build_bundles.py:  python3 tools/build_paste_models.py
"""
import os, glob, itertools
from xml.sax.saxutils import escape

SRC = "roblox_scripts/format_like_anime_fighters"
OUT = "roblox_scripts"
ref = itertools.count(1)

def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"

def item(cls, name, source=None, children=()):
    props = f'<string name="Name">{escape(name)}</string>'
    if source is not None:
        props += f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
    return f'<Item class="{cls}" referent="RBX{next(ref)}"><Properties>{props}</Properties>{"".join(children)}</Item>'

def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()

def modules(pattern):
    out = []
    for path in sorted(glob.glob(pattern), key=lambda p: (len(p), p)):
        out.append(item("ModuleScript", os.path.basename(path)[:-4], read(path)))
    return out

HEADER = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
          'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
          'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">')

def write(name, items):
    path = f"{OUT}/{name}.rbxmx"
    with open(path, "w", encoding="utf-8") as f:
        f.write(HEADER + "".join(items) + "</roblox>")
    print("wrote", path, os.path.getsize(path) // 1024, "KB")

write("Insert_into_ServerScriptService", [
    item("Script", "Spin_Server", read(f"{SRC}/Spin_Server.lua")),
    item("Folder", "SpinCore", children=modules(f"{SRC}/core/SpinCore_Server_*.lua")),
    item("Folder", "SpinCharacters", children=modules(f"{SRC}/characters/*_Server.lua")),
])
write("Insert_into_ReplicatedStorage", [
    item("ModuleScript", "TuskConfig", read(f"{SRC}/TuskConfig.lua")),
    item("ModuleScript", "SpinConfig", read(f"{SRC}/SpinConfig.lua")),
    item("Folder", "SpinCore", children=modules(f"{SRC}/core/SpinCore_Client_*.lua")),
    item("Folder", "SpinCharacters", children=modules(f"{SRC}/characters/*_Client.lua")),
])
write("Insert_into_StarterPlayerScripts", [
    item("LocalScript", "Spin_Client", read(f"{SRC}/Spin_Client.lua")),
])
