"""Builds COPY_PASTE_SCRIPTS.html and COPY_PASTE_SCRIPTS.md: every script
with its name, object type, exact Studio location and full code, in the
order to create them."""
import os, html

ROOTS = [
    ("src/shared", "ReplicatedStorage", "SpinShared", "Folder"),
    ("src/server", "ServerScriptService", "SpinServer", "Script"),
    ("src/client", "StarterPlayer › StarterPlayerScripts", "SpinClient", "LocalScript"),
    ("src/tools", "ServerStorage", "SpinTools", "Folder"),
]

steps = []  # dicts: kind, name, location, code

def walk(path, location):
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if entry.startswith("init."):
            continue
        if os.path.isdir(full):
            steps.append({"kind": "Folder", "name": entry, "location": location, "code": None})
            walk(full, location + " › " + entry)
        elif entry.endswith(".lua"):
            steps.append({"kind": "ModuleScript", "name": entry[:-4], "location": location, "code": open(full).read()})

for src, service, name, kind in ROOTS:
    init = None
    for f, k in (("init.server.lua", "Script"), ("init.client.lua", "LocalScript")):
        if os.path.exists(os.path.join(src, f)):
            init = open(os.path.join(src, f)).read()
    steps.append({"kind": kind, "name": name, "location": service, "code": init})
    walk(src, service + " › " + name)

# ---------- Markdown ----------
md = ["# Spin Battlegrounds: copy-paste scripts\n",
      "Create each object **in this order**, with the exact name and type shown, then paste the code into it.",
      "Right-click the location in Explorer › Insert Object › pick the type › rename it.",
      "Names must match exactly (capital letters too).\n"]
for i, s in enumerate(steps, 1):
    md.append(f"## {i}. {s['name']}  ({s['kind']})")
    md.append(f"**Put it in:** `{s['location']}`\n")
    if s["code"] is None:
        md.append("_Empty folder: nothing to paste._\n")
    else:
        md.append("```lua\n" + s["code"].rstrip() + "\n```\n")
open("COPY_PASTE_SCRIPTS.md", "w").write("\n".join(md))

# ---------- HTML ----------
cards = []
for i, s in enumerate(steps, 1):
    badge = {"Script": "server", "LocalScript": "client", "ModuleScript": "module", "Folder": "folder"}[s["kind"]]
    body = ('<p class="empty">Empty folder: nothing to paste.</p>' if s["code"] is None else
            f'<button class="copy" data-i="{i}">Copy code</button>'
            f'<details><summary>Show code ({s["code"].count(chr(10)) + 1} lines)</summary>'
            f'<pre id="c{i}">{html.escape(s["code"])}</pre></details>')
    cards.append(f'''<section class="card" id="s{i}">
<div class="head"><span class="num">{i}</span><div><h2>{html.escape(s["name"])} <span class="badge {badge}">{s["kind"]}</span></h2>
<p class="loc">Put it in: <b>{html.escape(s["location"])}</b></p></div></div>{body}</section>''')

page = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Spin Scripts</title><style>
:root{{--bg:#0f1420;--panel:#171e2e;--ink:#e8eefc;--muted:#9aa8c4;--line:#2a3550;--accent:#5ad8ff;--code:#0b0f18}}
@media (prefers-color-scheme: light){{:root:not([data-theme="dark"]){{--bg:#f4f6fb;--panel:#fff;--ink:#1a2233;--muted:#5d6a85;--line:#dde3ef;--accent:#0a7fb0;--code:#f1f4f9}}}}
:root[data-theme="light"]{{--bg:#f4f6fb;--panel:#fff;--ink:#1a2233;--muted:#5d6a85;--line:#dde3ef;--accent:#0a7fb0;--code:#f1f4f9}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,Segoe UI,sans-serif}}
main{{max-width:980px;margin:0 auto;padding:24px 16px}}h1{{margin:0 0 6px}}.lead{{color:var(--muted)}}
.card{{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:14px 16px;margin:12px 0}}
.head{{display:flex;gap:12px;align-items:flex-start}}.num{{min-width:34px;height:34px;border-radius:50%;background:var(--accent);color:#06121c;font-weight:800;display:grid;place-items:center}}
h2{{margin:0;font-size:18px}}.loc{{margin:2px 0 8px;color:var(--muted)}}.loc b{{color:var(--ink)}}
.badge{{font-size:11px;padding:2px 8px;border-radius:99px;vertical-align:middle;font-weight:700}}
.server{{background:#3b82f6;color:#fff}}.client{{background:#10b981;color:#fff}}.module{{background:#8b5cf6;color:#fff}}.folder{{background:#f59e0b;color:#1a1000}}
.copy{{background:var(--accent);color:#06121c;border:0;border-radius:8px;padding:8px 14px;font-weight:700;cursor:pointer}}
.copy.done{{background:#10b981;color:#fff}}details{{margin-top:8px}}summary{{cursor:pointer;color:var(--muted)}}
pre{{background:var(--code);border:1px solid var(--line);border-radius:8px;padding:12px;overflow:auto;max-height:420px;font:12.5px/1.45 ui-monospace,Consolas,monospace}}
.empty{{color:var(--muted);margin:0}}.card,.head>div{{min-width:0;overflow-wrap:anywhere}}pre{{max-width:100%}}code{{word-break:break-all}}.tip{{border-left:4px solid var(--accent);background:var(--panel);padding:10px 14px;border-radius:0 10px 10px 0}}
</style></head><body><main>
<h1>Spin Battlegrounds: copy-paste scripts</h1>
<p class="lead">{len(steps)} steps. Create each object <b>in this order</b>, with the exact name and type, then press <b>Copy code</b> and paste it into the script.</p>
<div class="tip">How: right-click the place in Explorer › <b>Insert Object</b> › choose the type › rename it exactly. Scripts that go "inside" another script: right-click that script and insert there. <b>Folder</b> steps have no code.</div>
{"".join(cards)}
<div class="tip">Last step, to build the map: View › Command Bar, paste <code>require(game.ServerStorage.SpinTools.SBRMapBuilder).Build()</code>, press Enter, then File › Save.</div>
</main><script>
document.querySelectorAll(".copy").forEach(function(b){{b.addEventListener("click",function(){{
var t=document.getElementById("c"+b.dataset.i).textContent;
function ok(){{b.textContent="Copied!";b.classList.add("done");setTimeout(function(){{b.textContent="Copy code";b.classList.remove("done")}},1500)}}
if(navigator.clipboard){{navigator.clipboard.writeText(t).then(ok,function(){{fallback(t);ok()}})}}else{{fallback(t);ok()}}
}})}});
function fallback(t){{var a=document.createElement("textarea");a.value=t;document.body.appendChild(a);a.select();try{{document.execCommand("copy")}}catch(e){{}}a.remove()}}
</script></body></html>'''
open("COPY_PASTE_SCRIPTS.html", "w").write(page)
print(len(steps), "steps")
for i, s in enumerate(steps, 1):
    print(f"{i:2}. {s['kind']:<12} {s['name']:<22} -> {s['location']}")
