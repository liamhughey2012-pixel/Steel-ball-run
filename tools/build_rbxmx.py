"""Builds drag-and-drop Roblox model files (install/*.rbxmx) from src/.

Run from the repo root:  python3 tools/build_rbxmx.py
Each .rbxmx goes into one Roblox service (see Second Brain.html).
"""
import os, itertools
from xml.sax.saxutils import escape

ref = itertools.count(1)

def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"

def item(cls, name, source=None, children=()):
    props = f'<string name="Name">{escape(name)}</string>'
    if source is not None:
        props += f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
    kids = "".join(children)
    return f'<Item class="{cls}" referent="RBX{next(ref)}"><Properties>{props}</Properties>{kids}</Item>'

def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()

def folder_children(path):
    out = []
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if entry.startswith("init."):
            continue
        if os.path.isdir(full):
            out.append(item("Folder", entry, children=folder_children(full)))
        elif entry.endswith(".lua"):
            out.append(item("ModuleScript", entry[:-4], read(full)))
    return out

def root(path, name):
    for init, cls in (("init.server.lua", "Script"), ("init.client.lua", "LocalScript"), ("init.lua", "ModuleScript")):
        if os.path.exists(os.path.join(path, init)):
            return item(cls, name, read(os.path.join(path, init)), folder_children(path))
    return item("Folder", name, children=folder_children(path))

HEADER = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
          'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
          'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">')

os.makedirs("install", exist_ok=True)
for src, name in (("src/shared", "SpinShared"), ("src/server", "SpinServer"), ("src/client", "SpinClient"), ("src/tools", "SpinTools")):
    with open(f"install/{name}.rbxmx", "w", encoding="utf-8") as f:
        f.write(HEADER + root(src, name) + "</roblox>")
    print("wrote", f"install/{name}.rbxmx")
