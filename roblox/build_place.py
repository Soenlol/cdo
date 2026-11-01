#!/usr/bin/env python3
"""Assemble les scripts de src/ en un fichier de place Roblox (.rbxlx) ouvrable dans Roblox Studio.

Même arborescence que default.project.json (Rojo) :
  ReplicatedStorage/Rallye        <- src/shared (+ dossier Client <- src/client)
  ServerScriptService             <- src/server
  StarterPlayer/StarterPlayerScripts <- src/player

Usage : python3 build_place.py  ->  build/PistePoussiere.rbxlx
"""
import os
import itertools
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, "src")
OUT = os.path.join(ROOT, "build", "PistePoussiere.rbxlx")

_ids = itertools.count(1)


def ref():
    return "RBX%08X" % next(_ids)


def cdata(text):
    # ']]>' ne peut pas apparaître dans une section CDATA : on la coupe
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, children=(), source=None, extra=""):
    props = '<string name="Name">%s</string>' % escape(name)
    if source is not None:
        props += '<ProtectedString name="Source">%s</ProtectedString>' % cdata(source)
    props += extra
    return '<Item class="%s" referent="%s"><Properties>%s</Properties>%s</Item>' % (
        cls, ref(), props, "".join(children))


def script_item(path):
    base = os.path.basename(path)
    with open(path, encoding="utf-8") as f:
        src = f.read()
    if base.endswith(".server.lua"):
        return item("Script", base[: -len(".server.lua")], source=src)
    if base.endswith(".client.lua"):
        return item("LocalScript", base[: -len(".client.lua")], source=src)
    return item("ModuleScript", base[: -len(".lua")], source=src)


def dir_children(path):
    out = []
    for name in sorted(os.listdir(path)):
        full = os.path.join(path, name)
        if os.path.isdir(full):
            out.append(item("Folder", name, dir_children(full)))
        elif name.endswith(".lua"):
            out.append(script_item(full))
    return out


def build():
    rallye = item("Folder", "Rallye", dir_children(os.path.join(SRC, "shared")) +
                  [item("Folder", "Client", dir_children(os.path.join(SRC, "client")))])
    services = [
        item("Workspace", "Workspace", extra='<float name="Gravity">29.43</float>'),
        item("ReplicatedStorage", "ReplicatedStorage", [rallye]),
        item("ServerScriptService", "ServerScriptService", dir_children(os.path.join(SRC, "server"))),
        item("StarterPlayer", "StarterPlayer", [
            item("StarterPlayerScripts", "StarterPlayerScripts", dir_children(os.path.join(SRC, "player")))
        ]),
    ]
    xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
           'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
           + "".join(services) + "</roblox>")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print("écrit :", OUT, "(%d octets)" % len(xml.encode("utf-8")))


if __name__ == "__main__":
    build()
