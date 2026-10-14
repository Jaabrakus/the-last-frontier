"""Two review sketches for regions.md (planning only, not game art):
  regions_route_graph.png  the atlas as game regions joined by journeys (bible travel windows)
  r1_slice_layout.png      the first playable region, square by square
"""
from PIL import Image, ImageDraw, ImageFont
import math

OUT = "/private/tmp/claude-501/-Users-kiwimango-Downloads-Frontier/d8726f05-a14a-44ac-97c9-351a2e11c5c5/scratchpad/thuyvan_plan/"
FONT = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
PAPER = (241, 233, 214)
INK = (52, 44, 36)
RIVER = (70, 120, 170)
TRAIL = (140, 90, 50)
SEA = (40, 140, 140)
THRESH = (170, 50, 50)
GREY = (120, 120, 120)


def f(size):
    return ImageFont.truetype(FONT, size)


def dashed(d, a, b, col, w=3, dash=14, gap=9):
    ax, ay = a
    bx, by = b
    L = math.hypot(bx - ax, by - ay)
    n = int(L // (dash + gap)) + 1
    for i in range(n):
        s = i * (dash + gap) / L
        e = min((i * (dash + gap) + dash) / L, 1.0)
        d.line([(ax + (bx - ax) * s, ay + (by - ay) * s), (ax + (bx - ax) * e, ay + (by - ay) * e)], fill=col, width=w)


# ---------------------------------------------------------------- route graph
W, H = 1500, 1650
im = Image.new("RGB", (W, H), PAPER)
d = ImageDraw.Draw(im)
d.text((40, 25), "Thủy Vân as game regions — journeys between them (sketch)", font=f(38), fill=INK)
d.text((40, 75), "Positions are topology, not scale. Edge labels = bible travel windows (ordinary / disrupted). "
       "Inside a region you walk; between regions you take a journey.", font=f(20), fill=INK)

nodes = {
    "R4": (330, 260, "R4  Trường Sơn, the Endless Range", "L04 · Mountain Folk · Books I–V"),
    "R9": (150, 470, "R9  Lâm Uyên, the Verdant Deep", "L10 · Mộc Tinh · Books II–V"),
    "R1": (640, 420, "R1  Đá Trắng Reach & Two Heights", "L03 + L16 · FIRST REGION · Books I–IV"),
    "R5": (300, 690, "R5  Thạch Uyên, the Stone Valleys", "L05 · Stone Children · Books I–V"),
    "AR": (1080, 250, "Ancestor Roads (shrine houses)", "L11 · placed in several regions"),
    "R3": (870, 640, "R3  The Lock Road (five lock stages)", "L01 · journey + 2 stops · Books I–II"),
    "R2": (1000, 860, "R2  Vạn Thủy, Capital of the Waters", "L02 · Dragon-Sea · Books I–IV"),
    "R8": (560, 930, "R8  Ảo Thành, the City of Illusions", "L09 · Hồ Tinh · Books II–V"),
    "R7": (560, 1150, "R7  Vực Sen Sâu, the Deep Lotus Reaches", "L08 · Riverborn · Books II–V"),
    "R6": (330, 1360, "R6  Đồng Lau, the Reed Marches + Khar-Ul", "L06 + L07 · Floodborn · Books I–V"),
    "R10": (1180, 1200, "R10 Southern Delta Provinces + Ash Coast", "L12 + L13 · Books II–V"),
}
edges = [
    ("R1", "R3", "upstream cutter, 5 locks: 6–9 / 9–14 d", RIVER, False),
    ("R3", "R2", "(same river route)", RIVER, False),
    ("R1", "R4", "pass trails (inside R1's edge)", TRAIL, False),
    ("R1", "R5", "bridge road 1–2 / 3–5 d (+2 after Bk II)", TRAIL, False),
    ("R5", "R9", "forest path 4–6 / 7–10 d · grove leave + guide", TRAIL, True),
    ("R1", "AR", "shrine road 2–4 / 4–7 d", TRAIL, False),
    ("R2", "R8", "road + threshold 7–10 / 12–16 d · invitation", THRESH, True),
    ("R2", "R6", "downstream barge 4–6 / 6–9 d (back 7–10)", RIVER, False),
    ("R6", "R7", "pilot / controlled submersion 2–3 / 4–6 d", RIVER, True),
    ("R2", "R10", "coastal sailing 5–8 / 9–16 d · storms close", SEA, False),
]
for a, b, lab, col, dash in edges:
    ax, ay = nodes[a][0], nodes[a][1]
    bx, by = nodes[b][0], nodes[b][1]
    if dash:
        dashed(d, (ax, ay), (bx, by), col, 4)
    else:
        d.line([(ax, ay), (bx, by)], fill=col, width=5)
    mx, my = (ax + bx) / 2, (ay + by) / 2
    tw = d.textlength(lab, font=f(17))
    d.rectangle([mx - tw / 2 - 4, my - 12, mx + tw / 2 + 4, my + 12], fill=PAPER)
    d.text((mx - tw / 2, my - 11), lab, font=f(17), fill=col)

for k, (x, y, name, sub) in nodes.items():
    first = k == "R1"
    tw = max(d.textlength(name, font=f(21)), d.textlength(sub, font=f(16))) + 24
    box = [x - tw / 2, y - 34, x + tw / 2, y + 34]
    d.rounded_rectangle(box, 10, fill=(250, 245, 232) if not first else (255, 236, 200),
                        outline=(180, 60, 40) if first else INK, width=5 if first else 2)
    d.text((x - tw / 2 + 12, y - 28), name, font=f(21), fill=INK)
    d.text((x - tw / 2 + 12, y + 4), sub, font=f(16), fill=(90, 80, 70))

# Khar-Ul extra edge and the Buried Kingdom network
d.text((40, 1470), "Khar-Ul: guided shallow boat from the Reed Marches 1–2 / 2–4 d (no deep-draft access).", font=f(18), fill=RIVER)
d.text((40, 1500), "Buried Kingdom (L14): a gallery NETWORK under several works — first entrance in R1's gorge (opens Book II); "
       "interiors, not a region.", font=f(18), fill=GREY)
d.text((40, 1530), "The Convergence (L15): unnamed in Books I–III; not on the in-game map before Book IV–V. "
       "The Ninth River is never on the map before Book V.", font=f(18), fill=THRESH)
d.text((40, 1575), "Legend:  river/boat ", font=f(18), fill=INK)
d.line([(230, 1587), (290, 1587)], fill=RIVER, width=5)
d.text((300, 1575), " trail/road ", font=f(18), fill=INK)
d.line([(410, 1587), (470, 1587)], fill=TRAIL, width=5)
d.text((480, 1575), " sea ", font=f(18), fill=INK)
d.line([(530, 1587), (590, 1587)], fill=SEA, width=5)
d.text((600, 1575), " gated (permission / pilot / invitation) ", font=f(18), fill=INK)
dashed(d, (950, 1587), (1030, 1587), THRESH, 4)
im.save(OUT + "regions_route_graph.png")

# ---------------------------------------------------------------- R1 slice layout
S = 300           # px per 832 m square
OX, OY = 90, 170
cols, rows = 4, 3
W2, H2 = OX + cols * S + 520, OY + rows * S + 330
im = Image.new("RGB", (W2, H2), PAPER)
d = ImageDraw.Draw(im)
d.text((40, 25), "R1 — Đá Trắng Reach & Two Heights: the first playable region (sketch)", font=f(36), fill=INK)
d.text((40, 72), "Ten 832 m squares (~3.3 × 2.5 km). North is up. Grey squares = backdrop rim (baked low detail, not walkable far). "
       "Names in quotes are placeholders for the owner.", font=f(19), fill=INK)
d.text((40, 100), "Compression: the bible's 2–3-day pack trail Đá Trắng → Two Heights becomes ~2.5 km of switchbacks (≈15–20 min on foot).",
       font=f(19), fill=INK)

grid = [
    ["A1 high pass (Trường Sơn side)\nclan waystones · goat-pass watch", "B1 terraced slope\nMountain Folk village · clan house",
     "C1 GORGE: the Silent Reach\nanchor-gallery mouth · H19 cairns", "D1 rim: upper gorge\n(backdrop)"],
    ["A2 BRIDGE GORGE\nTwo Heights Bridge · torrent", "B2 pack-trail switchbacks\nhillside shrine · confluence",
     "C2 middle reach\nferry · fishing hamlet · rapids", "D2 rim: karst foothills\n(backdrop)"],
    ["A3 Stone height\nquarry hamlet · rain road · old quarry", "B3 foothill paddies\nmixed farms · herb gardens",
     "C3 \"the Fifth Lock\"\nlock · toll house · barge basin · market", "D3 river exit + first karst\njourney pier → Lock Road"],
]
rim = {(3, 0), (3, 1)}
for r in range(rows):
    for c in range(cols):
        x0, y0 = OX + c * S, OY + r * S
        fill = (225, 222, 214) if (c, r) in rim else (236, 228, 205)
        if (c, r) in ((2, 0), (0, 1), (2, 2)):
            fill = (246, 222, 190)
        d.rectangle([x0, y0, x0 + S, y0 + S], fill=fill, outline=(150, 140, 120), width=2)
        lines = grid[r][c].split("\n")
        d.text((x0 + 10, y0 + 8), lines[0], font=f(17), fill=INK)
        for i, ln in enumerate(lines[1:]):
            d.text((x0 + 10, y0 + 32 + i * 22), ln, font=f(15), fill=(90, 80, 70))

# Đá Trắng: from the north edge of C1 down through C2 to C3 then east out through D3
pts = []
for t in range(0, 101):
    u = t / 100.0
    y = OY + u * 3 * S * 0.86
    x = OX + 2.45 * S + 40 * math.sin(u * 9.0) + 20 * math.sin(u * 23)
    pts.append((x, y))
# bend east at the bottom to D3
last = pts[-1]
for t in range(1, 30):
    u = t / 29.0
    pts.append((last[0] + u * 1.45 * S, last[1] + 25 * math.sin(u * 3.1)))
d.line(pts, fill=RIVER, width=9)
# the Silent Reach (bounded stopped stretch) in C1
sr0, sr1 = 18, 32
d.line(pts[sr0:sr1], fill=(235, 240, 245), width=13)
d.line(pts[sr0:sr1], fill=(150, 175, 200), width=5)
# tributary torrent from A2 east through B2 to the confluence in C2
trib = []
for t in range(0, 61):
    u = t / 60.0
    trib.append((OX + 0.1 * S + u * 2.3 * S, OY + 1.45 * S + 30 * math.sin(u * 7) + u * 25))
d.line(trib, fill=RIVER, width=5)
# the bridge across the torrent in A2 (north-south)
bx = OX + 0.55 * S
by = OY + 1.45 * S + 30 * math.sin((0.45 / 2.3) * 7)
d.line([(bx, by - 70), (bx, by + 70)], fill=(120, 60, 40), width=11)
d.line([(bx - 14, by - 70), (bx + 14, by - 70)], fill=(120, 60, 40), width=5)
d.line([(bx - 14, by + 70), (bx + 14, by + 70)], fill=(120, 60, 40), width=5)
# pack trail switchbacks from C3/C2 up through B2 to A2's bridge and on north
trail = [(OX + 2.3 * S, OY + 2.55 * S), (OX + 1.9 * S, OY + 2.35 * S), (OX + 2.05 * S, OY + 2.1 * S),
         (OX + 1.6 * S, OY + 1.95 * S), (OX + 1.8 * S, OY + 1.7 * S), (OX + 1.3 * S, OY + 1.65 * S),
         (OX + 1.45 * S, OY + 1.35 * S), (OX + 0.9 * S, OY + 1.25 * S), (bx, by - 70), (OX + 0.5 * S, OY + 0.7 * S),
         (OX + 0.3 * S, OY + 0.25 * S)]
for i in range(len(trail) - 1):
    dashed(d, trail[i], trail[i + 1], TRAIL, 4, 10, 7)
dashed(d, (bx, by + 70), (OX + 0.5 * S, OY + 2.5 * S), TRAIL, 4, 10, 7)
# village trail to B1
dashed(d, (OX + 1.45 * S, OY + 1.35 * S), (OX + 1.5 * S, OY + 0.55 * S), TRAIL, 3, 8, 6)

# numbered landmarks
marks = [
    (1, pts[25][0] + 18, pts[25][1], "The Silent Reach — the bounded stretch that stops (Book I day 0)"),
    (2, pts[12][0] - 45, pts[12][1], "Anchor-gallery mouth in the gorge wall (sealed in Book I; opens Book II)"),
    (3, pts[36][0] + 22, pts[36][1] - 10, "H19 survey-violence cairns; burial-witness upper reach"),
    (4, bx + 22, by, "Two Heights Bridge — two maker signs on one pier"),
    (5, OX + 1.5 * S, OY + 0.5 * S, "Mountain Folk village, terraces, clan house"),
    (6, OX + 1.62 * S, OY + 1.42 * S, "Hillside shrine (an Ancestor-Bound house on the circuit)"),
    (7, OX + 0.45 * S, OY + 2.55 * S, "Stone quarry hamlet, retaining wall over the rain road"),
    (8, OX + 2.55 * S, OY + 1.55 * S, "Ferry crossing and fishing hamlet at the rapids"),
    (9, OX + 2.62 * S, OY + 2.55 * S, "\"The Fifth Lock\": lock, toll house, crossing station, market"),
    (10, OX + 2.85 * S, OY + 2.78 * S, "Tidebreak festival ring moored in the barge basin"),
    (11, OX + 2.75 * S, OY + 0.75 * S, "Imperial survey / excavation-permit camp"),
    (12, OX + 3.6 * S, OY + 2.45 * S, "Journey pier: river cutter down the Lock Road"),
]
for n, x, y, lab in marks:
    d.ellipse([x - 15, y - 15, x + 15, y + 15], fill=(180, 60, 40), outline=(255, 255, 255), width=2)
    tw = d.textlength(str(n), font=f(16))
    d.text((x - tw / 2, y - 10), str(n), font=f(16), fill=(255, 255, 255))
LX = OX + cols * S + 30
d.text((LX, OY - 5), "Landmarks", font=f(24), fill=INK)
for i, (n, x, y, lab) in enumerate(marks):
    yy = OY + 35 + i * 52
    d.ellipse([LX, yy, LX + 26, yy + 26], fill=(180, 60, 40))
    tw = d.textlength(str(n), font=f(15))
    d.text((LX + 13 - tw / 2, yy + 3), str(n), font=f(15), fill=(255, 255, 255))
    # wrap
    words, line, out = lab.split(), "", []
    for w_ in words:
        if d.textlength(line + " " + w_, font=f(16)) > 440:
            out.append(line)
            line = w_
        else:
            line = (line + " " + w_).strip()
    out.append(line)
    for j, ln in enumerate(out):
        d.text((LX + 36, yy + j * 20), ln, font=f(16), fill=INK)

YB = OY + rows * S + 25
d.text((40, YB), "Đá Trắng (blue) runs N→S through the C column, then E out of the region; the pale stretch in C1 is the Silent Reach.",
       font=f(18), fill=RIVER)
d.text((40, YB + 28), "Torrent (thin blue) from the bridge gorge joins it in C2. Brown dashes = the pack trail over Two Heights and on to the pass.",
       font=f(18), fill=TRAIL)
d.text((40, YB + 56), "Highlighted squares are the three hero squares to build first: C3 (lock town, the tutorial home for Dragon-Sea players),",
       font=f(18), fill=INK)
d.text((40, YB + 80), "C1 (the Silence), A2 (the bridge). Build order: C3 + C2 → C1 → B-column → A-column → rim.", font=f(18), fill=INK)
d.text((40, YB + 116), "Peoples on screen in Book I here: Mountain Folk, Stone Children, Dragon-Sea (toll, boats, soldiers), Ancestor-Bound (shrine),",
       font=f(18), fill=INK)
d.text((40, YB + 140), "Hồ Tinh in disguise (market brokerage). Riverborn are present as an ABSENCE (closed licences, missing guides);",
       font=f(18), fill=INK)
d.text((40, YB + 164), "Floodborn and Mộc Tinh are off-screen in the north in Book I (rumour; dying-wood glimpses) — canon-true, and it defers their rigs.",
       font=f(18), fill=INK)
d.text((40, YB + 200), "Canon cast who pass through R1 in Book I (never replaced by the player): Kha Vũ, Hạc, Nhạn, Tấn, Yên Dao, Bạc Sơn, Mẹ Lửa,",
       font=f(18), fill=(90, 80, 70))
d.text((40, YB + 224), "Dương Sắt, Lệ Thạch, General Trần Hổ, Linh Hải's relief convoy and Bảo, Vân Cổ at the midpoint, An Tâm's relief party; the White Stag.",
       font=f(18), fill=(90, 80, 70))
im.save(OUT + "r1_slice_layout.png")
print("ok")
