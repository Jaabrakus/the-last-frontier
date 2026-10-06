import os

HERE = os.path.dirname(os.path.abspath(__file__))
banner = {
    "story.md": "3.1 (story) and section 2",
    "arts.md": "3.2 (arts and Tidebreak) and section 2",
    "regions.md": "3.3 (map, data and art sources), the R1 grid in section 4 Phase 3, and section 2",
    "peoples.md": "3.4 (peoples), Phase 4, and section 2",
    "inventory.md": "3.3 item 26 and sections 2 and 5",
}
for f, where in banner.items():
    p = os.path.join(HERE, f)
    s = open(p, encoding="utf-8").read()
    if s.startswith("> **Superseded in part"):
        continue
    b = ("> **Superseded in part (revision 2, 2026-10-05).** `plan.md` overrides this part wherever they differ; see "
         f"plan.md {where}. Builders take canon from plan.md section 3 and from `data/thuyvan`, never by copying text "
         "from this file.\n\n")
    open(p, "w", encoding="utf-8").write(b + s)
print("ok")
