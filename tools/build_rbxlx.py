"""Pack game/src into a Roblox place file (game/PopBalloonRNG.rbxlx) and a
Rojo-style sourcemap.json (used by luau-lsp for type checking).

Layout follows game/default.project.json:
  src/shared -> ReplicatedStorage.Shared
  src/server -> ServerScriptService.Server
  src/client -> StarterPlayer.StarterPlayerScripts.Client
  *.server.luau = Script, *.client.luau = LocalScript, *.luau = ModuleScript
"""
import json
import os
from xml.sax.saxutils import escape

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game")
ROOT = os.path.normpath(ROOT)

MAPPING = [
    # (service class, [folder chain], src dir)
    ("ReplicatedStorage", ["Shared"], "src/shared"),
    ("ServerScriptService", ["Server"], "src/server"),
    ("StarterPlayer", ["StarterPlayerScripts", "Client"], "src/client"),
]

_ref = 0


def ref():
    global _ref
    _ref += 1
    return f"RBX{_ref:08X}"


def script_class(fname):
    if fname.endswith(".server.luau"):
        return "Script", fname[: -len(".server.luau")]
    if fname.endswith(".client.luau"):
        return "LocalScript", fname[: -len(".client.luau")]
    return "ModuleScript", fname[: -len(".luau")]


def item(cls, name, children="", source=None):
    props = f'<string name="Name">{escape(name)}</string>'
    if source is not None:
        assert "]]>" not in source
        props += f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>'
    return f'<Item class="{cls}" referent="{ref()}"><Properties>{props}</Properties>{children}</Item>\n'


def scripts_in(src_dir):
    out_xml, out_map = "", []
    for fname in sorted(os.listdir(os.path.join(ROOT, src_dir))):
        if not fname.endswith(".luau"):
            continue
        cls, name = script_class(fname)
        rel = f"{src_dir}/{fname}"
        with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
            out_xml += item(cls, name, source=f.read())
        out_map.append({"name": name, "className": cls, "filePaths": [rel]})
    return out_xml, out_map


def main():
    services = {}
    smap_services = {}
    for service, chain, src in MAPPING:
        xml, children = scripts_in(src)
        node_map = {"name": chain[-1], "className": "Folder", "children": children}
        # wrap in the folder chain (innermost is a Folder, outer ones are real containers)
        inner = item("Folder", chain[-1], xml)
        for container in reversed(chain[:-1]):
            inner = item(container, container, inner)
            node_map = {"name": container, "className": container, "children": [node_map]}
        services.setdefault(service, "")
        services[service] += inner
        smap_services.setdefault(service, []).append(node_map)

    body = item("Workspace", "Workspace")
    for service, inner in services.items():
        body += item(service, service, inner)
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
           + body + "</roblox>\n")
    out = os.path.join(ROOT, "PopBalloonRNG.rbxlx")
    with open(out, "w", encoding="utf-8") as f:
        f.write(xml)

    smap = {"name": "PopBalloonRNG", "className": "DataModel", "children": [
        {"name": s, "className": s, "children": c} for s, c in smap_services.items()]}
    with open(os.path.join(ROOT, "sourcemap.json"), "w") as f:
        json.dump(smap, f, indent=1)
    print("wrote", out)


if __name__ == "__main__":
    main()
