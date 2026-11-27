"""Builds the Second Brain web page from the Obsidian vault (obsidian/SpinBattles).

Output: second_brain_page/
  index.html   the page (Home note inlined so it shows at once)
  notes.json   every note rendered to HTML (fetched by the page)
  assets/      the vault's preview images
Run from the repo root:  python3 tools/build_second_brain_page.py
Needs the 'markdown' package (pip install markdown).
"""
import html, json, os, re, shutil

import markdown

VAULT = "obsidian/SpinBattles"
OUT = "second_brain_page"
ORDER = ["Home", "Project", "Install", "Characters", "Systems", "World", "Assets", "Log", "Code"]


def slug(title):
    s = re.sub(r"[^A-Za-z0-9]+", "-", title).strip("-").lower()
    return s or "note"


def read_notes():
    notes = []
    for dp, _, fs in os.walk(VAULT):
        for f in sorted(fs):
            if not f.endswith(".md"):
                continue
            path = os.path.join(dp, f)
            rel = os.path.relpath(path, VAULT)
            parts = rel.split(os.sep)
            folder = "Home" if len(parts) == 1 else parts[0]
            sub = parts[1] if len(parts) > 2 else ""
            notes.append({"path": path, "title": f[:-3], "folder": folder, "sub": sub, "raw": open(path, encoding="utf-8").read()})
    return notes


def frontmatter(raw):
    meta = {}
    if raw.startswith("---"):
        end = raw.find("\n---", 3)
        if end != -1:
            for line in raw[3:end].strip().splitlines():
                if ":" in line:
                    k, v = line.split(":", 1)
                    meta[k.strip()] = v.strip()
            raw = raw[end + 4:]
    return meta, raw.lstrip("\n")


def main():
    notes = read_notes()
    by_title = {}
    for n in notes:
        n["id"] = slug(n["title"])
        by_title[n["title"].lower()] = n
    # Unique ids.
    seen = {}
    for n in notes:
        if n["id"] in seen:
            n["id"] = n["id"] + "-" + slug(n["folder"])
        seen[n["id"]] = True

    md = markdown.Markdown(extensions=["tables", "fenced_code", "sane_lists"])
    links_in = {n["id"]: set() for n in notes}

    for n in notes:
        meta, body = frontmatter(n["raw"])
        n["updated"] = meta.get("updated", "")
        n["tags"] = meta.get("tags", "").strip("[]")
        # Drop a leading "# Title" (the page shows its own).
        body = re.sub(r"\A# .*\n", "", body)
        def convert(body):
            # Image embeds ![[file.png]].
            body = re.sub(r"!\[\[([^\]|]+?\.(?:png|jpg|jpeg|gif))(?:\|[^\]]*)?\]\]", lambda m: '<img class="shot" alt="%s" src="assets/%s" loading="lazy">' % (html.escape(m.group(1)), m.group(1).replace(" ", "%20")), body)

            def wiki(m):
                target, alias = m.group(1), m.group(2)
                t = by_title.get(target.strip().lower())
                label = html.escape(alias or target)
                if t:
                    links_in[t["id"]].add(n["id"])
                    return '<a class="wl" href="#%s">%s</a>' % (t["id"], label)
                return '<span class="wl missing">%s</span>' % label

            body = re.sub(r"\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|([^\]]+))?\]\]", wiki, body)
            # Task boxes.
            body = re.sub(r"^(\s*)- \[ \] ", r"\1- ☐ ", body, flags=re.M)
            body = re.sub(r"^(\s*)- \[x\] ", r"\1- ☑ ", body, flags=re.M | re.I)
            return body

        # Only convert links outside code (Lua's --[[ ]] comments look like links).
        pieces = re.split(r"(```.*?```|`[^`\n]*`)", body, flags=re.S)
        for i in range(0, len(pieces), 2):
            pieces[i] = convert(pieces[i])
        body = "".join(pieces)
        md.reset()
        n["html"] = md.convert(body)
        n["text"] = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", n["html"])).lower()[:4000]

    for n in notes:
        n["from"] = sorted(links_in[n["id"]])

    folder_rank = {f: i for i, f in enumerate(ORDER)}
    notes.sort(key=lambda n: (folder_rank.get(n["folder"], 99), n["sub"], n["title"].lower()))
    data = [{k: n[k] for k in ("id", "title", "folder", "sub", "updated", "tags", "html", "text", "from")} for n in notes]

    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(os.path.join(OUT, "assets"))
    for f in os.listdir(os.path.join(VAULT, "Assets")):
        if f.lower().endswith((".png", ".jpg", ".jpeg", ".gif")):
            shutil.copy(os.path.join(VAULT, "Assets", f), os.path.join(OUT, "assets", f))
    with open(os.path.join(OUT, "notes.json"), "w", encoding="utf-8") as fh:
        fh.write("[\n" + ",\n".join(json.dumps(d, ensure_ascii=False) for d in data) + "\n]\n")

    home = next(d for d in data if d["folder"] == "Home")
    nav = [{k: d[k] for k in ("id", "title", "folder", "sub")} for d in data]
    page = open("tools/second_brain_page_template.html", encoding="utf-8").read()
    page = page.replace("__NAV__", json.dumps(nav, ensure_ascii=False))
    page = page.replace("__HOME_ID__", home["id"])
    page = page.replace("__HOME_HTML__", home["html"])
    page = page.replace("__HOME_UPDATED__", html.escape(home["updated"]))
    page = page.replace("__COUNT__", str(len(data)))
    with open(os.path.join(OUT, "index.html"), "w", encoding="utf-8") as fh:
        fh.write(page)
    print(len(data), "notes;", len(os.listdir(os.path.join(OUT, "assets"))), "images")


if __name__ == "__main__":
    main()
