"""Adds Code/ notes to the SpinBattles vault: one note per Roblox script
(location, type, purpose, full code) plus a 'Where To Put Code' guide."""
import os, re, shutil

VAULT = "obsidian/SpinBattles"
ROOTS = [
    ("src/shared", "ReplicatedStorage", "SpinShared", "Folder", "Shared"),
    ("src/server", "ServerScriptService", "SpinServer", "Script", "Server"),
    ("src/client", "StarterPlayer › StarterPlayerScripts", "SpinClient", "LocalScript", "Client"),
    ("src/tools", "ServerStorage", "SpinTools", "Folder", "Tools"),
]

def purpose(code):
    m = re.search(r"--\[\[(.*?)\]\]", code, re.S)
    if not m:
        return ""
    lines = [l.strip() for l in m.group(1).strip().splitlines()]
    body = []
    for l in lines[1:]:  # first line is "Name (location)"
        if not l and body:
            break
        if l:
            body.append(l[2:] if l.startswith("* ") else l)
    return " ".join(body)

entries = []
for src, service, root, rootKind, group in ROOTS:
    for dp, _, fs in os.walk(src):
        for f in sorted(fs):
            if not f.endswith(".lua"):
                continue
            code = open(os.path.join(dp, f)).read()
            rel = os.path.relpath(dp, src)
            if f.startswith("init."):
                name, kind, parent = root, rootKind, service
            else:
                name, kind = f[:-4], "ModuleScript"
                parent = service + " › " + root + ("" if rel == "." else " › " + rel.replace("/", " › "))
            entries.append(dict(name=name, kind=kind, parent=parent, group=group, code=code, purpose=purpose(code)))

code_dir = os.path.join(VAULT, "Code")
shutil.rmtree(code_dir, ignore_errors=True)
for group in ("Shared", "Server", "Client", "Tools"):
    os.makedirs(os.path.join(code_dir, group))

for e in entries:
    note = f"""---
tags: [code, {e['group'].lower()}]
type: {e['kind']}
location: "{e['parent']}"
updated: 2026-11-22
---
# {e['name']}

| | |
|---|---|
| **Type** | {e['kind']} |
| **Put it in** | `{e['parent']}` |
| **Exact name** | `{e['name']}` (capitals matter) |

**What it does:** {e['purpose'] or 'See the comment at the top of the code.'}

## How to add it
1. In Studio's Explorer, find **{e['parent'].split(' › ')[-1]}** ({e['parent']}).
2. Right-click it › **Insert Object** › **{e['kind']}**.
3. Rename it to **{e['name']}**.
4. Open it, select all (Ctrl+A), and paste the code below over it.

Back to [[Where To Put Code]]

## Code
```lua
{e['code'].rstrip()}
```
"""
    open(os.path.join(code_dir, e["group"], e["name"] + ".md"), "w").write(note)

# Guide note
def table(group):
    rows = ["| # | Script | Type | Put it in |", "|---|---|---|---|"]
    for i, e in enumerate([x for x in entries if x["group"] == group], 1):
        rows.append(f"| {i} | [[{e['name']}]] | {e['kind']} | `{e['parent']}` |")
    return "\n".join(rows)

guide = f"""---
tags: [install, code]
updated: 2026-11-22
---
# Where To Put Code

Every script in Spin Battlegrounds, and exactly where it goes in Roblox Studio. Click a script name to open its note with the full code.

## The rules
1. **Make the containers first**, before any ModuleScripts:
   - Folder `SpinShared` in **ReplicatedStorage**
   - Script `SpinServer` in **ServerScriptService**
   - LocalScript `SpinClient` in **StarterPlayer › StarterPlayerScripts**
   - Folder `SpinTools` in **ServerStorage**
2. **Names must match exactly**, capitals included. The scripts find each other by name.
3. **"Inside a script"** means right-click that Script or LocalScript itself and insert there.
4. Three extra folders go inside the scripts:
   - `SpinServer › TuskActs` (Folder)
   - `SpinClient › TuskActVFX` (Folder)
   - `SpinClient › UI` (Folder)
5. Paste everything **before** pressing Play, or the Output window will show "is not a valid member" errors.
6. To update a script later: open it, Ctrl+A, and paste the new code over it. The name doesn't change.

## What a Studio Explorer should look like
```
ReplicatedStorage
└─ SpinShared                 Folder
   └─ (10 ModuleScripts)
ServerScriptService
└─ SpinServer                 Script
   ├─ (9 ModuleScripts)
   └─ TuskActs                Folder
      └─ TuskAct1             ModuleScript
StarterPlayer
└─ StarterPlayerScripts
   └─ SpinClient              LocalScript
      ├─ (13 ModuleScripts)
      ├─ TuskActVFX           Folder
      │  └─ Act1              ModuleScript
      └─ UI                   Folder
         ├─ SpinMeter         ModuleScript
         └─ TuskUI            ModuleScript
ServerStorage
└─ SpinTools                  Folder
   └─ SBRMapBuilder           ModuleScript
```

## Shared: ReplicatedStorage › SpinShared
Used by both the server and players.
{table("Shared")}

## Server: ServerScriptService › SpinServer
Damage, cooldowns, projectiles, Tusk, Sneak, NPCs. Players can't see or change these.
{table("Server")}

## Client: StarterPlayer › StarterPlayerScripts › SpinClient
Controls, effects, the Tusk Stand, HUD, NPC speech bubbles.
{table("Client")}

## Tools: ServerStorage › SpinTools
Only used in Studio, to build the map once.
{table("Tools")}

After everything is in: build the map from View › Command Bar with `require(game.ServerStorage.SpinTools.SBRMapBuilder).Build()`, then File › Save. See [[Install Steps]].

## Adding new code later
Every new update will say which scripts are **new** and which are **changed**:
- **New script:** create it in the place shown in its note.
- **Changed script:** open it, Ctrl+A, paste the new version.
- **Asset ids** (sounds, animations) go in [[SpinConfig]] and [[TuskConfig]], not in new scripts.
"""
open(os.path.join(VAULT, "Install", "Where To Put Code.md"), "w").write(guide)

# Link from Home
home_path = os.path.join(VAULT, "00 Home.md")
home = open(home_path).read()
if "[[Where To Put Code]]" not in home:
    home = home.replace("- [[Where Every File Goes]] · [[Install Steps]]",
                        "- **[[Where To Put Code]]** (every script, its location and its code)\n- [[Where Every File Goes]] · [[Install Steps]]")
    open(home_path, "w").write(home)
print(len(entries), "code notes")
