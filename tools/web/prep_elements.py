"""The web snapshot's elements cut to the ones the public build plays (the owner, 2026-10-16: "maybe just keep it high quality with
fire and earth"): the elements' lists in the snapshot's scripts are narrowed, so every card, opponent chip, quick-match draw and
bot lineup of the browser game offers only those (the desktop game, which builds from the project itself, keeps all four).
Run by tools/web/prep_snapshot.sh on the snapshot, never the project:
    python3 -I tools/web/prep_elements.py <snapshot dir> [earth,fire]
The list in order: the project's own (earth, water, fire, air) filtered, so the cards keep their usual order.
"""
import os
import re
import sys

snap = sys.argv[1]
keep = (sys.argv[2] if len(sys.argv) > 2 else os.environ.get("WEB_ELEMENTS", "earth,fire")).split(",")
ALL = ["earth", "water", "fire", "air"]
want = [e for e in ALL if e in keep]
if not want:
    raise SystemExit("no element kept")
lit = "[" + ", ".join('"%s"' % e for e in want) + "]"
FILES = ["scripts/bending/bending.gd", "scripts/ui/advancement/advancement_data.gd", "scripts/ring/ring_moves.gd"]
pat = re.compile(r'^const ELEMENTS := \["earth", "water", "fire", "air"\]\s*$', re.M)
for f in FILES:
    p = os.path.join(snap, f)
    s = open(p).read()
    n = len(pat.findall(s))
    if n != 1:
        raise SystemExit("%s: expected one ELEMENTS list, found %d" % (f, n))
    open(p, "w").write(pat.sub("const ELEMENTS := " + lit, s))
    print("WEB ELEMENTS", f, "->", lit)
