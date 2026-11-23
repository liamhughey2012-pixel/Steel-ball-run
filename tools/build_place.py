"""Builds ready-to-open Roblox files from the split scripts in
roblox_scripts/format_like_anime_fighters (run tools/build_bundles.py first):

  install/SpinBattlegrounds.rbxlx       a whole place with everything already installed
                                        (Studio: File > Open from File)
  install/Add_To_ServerScriptService.rbxmx     for an existing place: right-click the
  install/Add_To_ReplicatedStorage.rbxmx       service named in the file name >
  install/Add_To_StarterPlayerScripts.rbxmx    Insert from File
"""
import os, itertools
from xml.sax.saxutils import escape

ref = itertools.count(1)
SRC = "roblox_scripts/format_like_anime_fighters"

def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"

def item(cls, name, source=None, children=()):
    props = f'<string name="Name">{escape(name)}</string>'
    if source is not None:
        props += f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
    return f'<Item class="{cls}" referent="RBX{next(ref)}"><Properties>{props}</Properties>{"".join(children)}</Item>'

def read(name):
    with open(os.path.join(SRC, name), encoding="utf-8") as f:
        return f.read()

chars = sorted(os.listdir(os.path.join(SRC, "characters")))
def packs(side):
    return [item("ModuleScript", f[:-4], read("characters/" + f)) for f in chars if f.endswith(f"_{side}.lua")]

def server_items():
    return [item("Script", "Spin_Server", read("Spin_Server.lua")), item("Folder", "SpinCharacters", children=packs("Server"))]

def replicated_items():
    return [item("ModuleScript", "SpinConfig", read("SpinConfig.lua")), item("ModuleScript", "TuskConfig", read("TuskConfig.lua")),
            item("Folder", "SpinCharacters", children=packs("Client"))]

def client_items():
    return [item("LocalScript", "Spin_Client", read("Spin_Client.lua"))]

HEADER = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
          'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
          'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">')

os.makedirs("install", exist_ok=True)
place = (HEADER
    + item("Workspace", "Workspace")
    + item("ReplicatedStorage", "ReplicatedStorage", children=replicated_items())
    + item("ServerScriptService", "ServerScriptService", children=server_items())
    + item("StarterPlayer", "StarterPlayer", children=[item("StarterPlayerScripts", "StarterPlayerScripts", children=client_items())])
    + "</roblox>")
with open("install/SpinBattlegrounds.rbxlx", "w", encoding="utf-8") as f:
    f.write(place)
for name, items in (("ServerScriptService", server_items()), ("ReplicatedStorage", replicated_items()), ("StarterPlayerScripts", client_items())):
    with open(f"install/Add_To_{name}.rbxmx", "w", encoding="utf-8") as f:
        f.write(HEADER + "".join(items) + "</roblox>")
for f in sorted(os.listdir("install")):
    if f.startswith(("SpinBattlegrounds.", "Add_To_")):
        print(f, os.path.getsize(os.path.join("install", f)) // 1024, "KB")
