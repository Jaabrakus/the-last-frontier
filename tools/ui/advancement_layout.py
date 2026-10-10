"""The Character Advancement window's lattice (artifacts/ui_audit/advancement/plan.md section 2): lays every element's
two trees out on a grid and writes the pins the window places its nodes by, data/ui/advancement_layout.json.

  python3 -I tools/ui/advancement_layout.py            # (re)write the file: keeps hand-tuned pins of ids still present
  python3 -I tools/ui/advancement_layout.py --reset    # every pin back to the algorithm's place
  python3 -I tools/ui/advancement_layout.py --check    # exit 1 when the file's "generated" block is stale
  python3 -I tools/ui/advancement_layout.py --png DIR  # also a proof picture per element (PIL), for judging by eye

The same algorithm runs in scripts/ui/advancement/advancement_layout.gd (AdvancementLayout.algorithm) as the fallback for
an unpinned id, and tests/ui/test_advancement.gd holds the two to the same numbers (the file's "generated" block), so keep
them identical. The algorithm:
  lines    one per (chip, move, mode); every skill set node in one "set" line; every passive in one "passive" line; the
           new skills of a key's empty tap twice in one (chip, "slot") line; a node with no mode joins its move's first
           line in the same tree (or makes its own). Line order: chip order (advancement.json tree.chip_order), then the
           move's place on its key (moves.json elements: first move, then the tap twice), then its mode's place
           (moves.json modes, then world_modes), then data order; a slot line after its key's move lines.
  tiers    0 the root (the move you have: "root:<move>/<mode>"; the passive line's is the element's passive,
           "root:passive/<id>"; slot and set lines have none), then advancement.json tree.tiers by kind; a band keeps
           only the tiers it uses (empty tiers compress).
  choices  inside one tier of one line, all twists, all new skills, all passives and any excludes pair become one entry
           (the window's octagon): "choice:<first member id>", members in data order.
  bands    a line's width is its widest tier; lines go left to right in bands no wider than the tree (left_width,
           right_width): the fewest bands, then the lowest total rows, then the most even widths. Each band is centred
           on the tree's width; band_gap rows between bands.
  places   col = the line's x + (width - entries) / 2 + index; row = the band's top + the tier's index in the band.
  links    every entry of a tier to every entry of the line's next tier (never across lines).
Visible nodes: ring mode hides world-only nodes and the ring-illegal number swaps (switches.hide_world_only_in_ring) and
keeps held nodes when switches.show_held; world mode shows every node (held ones by show_held).
"""
import json
import math
import sys
from pathlib import Path

F = Path(__file__).resolve().parents[2]
TREE = F / 'data/sway/skill_tree.json'
MOVES = F / 'data/sway/moves.json'
UI = F / 'data/ui/advancement.json'
OUT = F / 'data/ui/advancement_layout.json'
ELEMENTS = ['earth', 'water', 'fire', 'air']
SIDES = ['left', 'right']


def load():
    return (json.loads(TREE.read_text()), json.loads(MOVES.read_text()), json.loads(UI.read_text()))


def element_nodes(tree, el):
    out = []
    for b in tree['elements'][el]['branches']:
        for n in b['nodes']:
            out.append(n)
    return out


def eff_chip(n):
    if n['kind'] == 'skill_set':
        return 'set'
    if n['kind'] == 'passive':
        return 'passive'
    return str(n.get('chip') or 'passive')


def side_of(ui, n):
    return 'left' if eff_chip(n) in ui['tree']['left_chips'] else 'right'


def visible(ui, n, mode):
    sw = ui['switches']
    if n['kind'] == 'world_only':
        return mode == 'world'
    if n.get('held'):
        return bool(sw.get('show_held', True))
    if mode == 'ring' and n.get('ring_legal', True) is False:
        return not bool(sw.get('hide_world_only_in_ring', True))
    return True


def key_moves(moves, el, chip):
    """The moves on chip `chip` for element `el`, in key order (first move, then the tap twice)."""
    if chip in ('1', '2', '3', '4', '5'):
        keys = moves.get('elements', {}).get(el, [])
        i = int(chip) - 1
        if 0 <= i < len(keys):
            k = keys[i]
            return list(k) if isinstance(k, list) else [k]
        return []
    if chip == 'LMB':
        j = moves.get('jabs', {}).get(el)
        return [j[0]] if isinstance(j, list) and j else []
    if chip == 'E':
        g = moves.get('guards', {}).get(el)
        return [g[0]] if isinstance(g, list) and g else []
    return []


def mode_index(moves, move, mode):
    m = moves.get('moves', {}).get(move, {})
    ms = m.get('modes') or []
    if mode in ms:
        return ms.index(mode)
    wm = m.get('world_modes') or []
    if mode in wm:
        return 50 + wm.index(mode)
    return 99


def structure(tree, moves, ui, el, side, mode):
    """Lines, tiers and entries (no places): {'lines': [...], 'order': {id: data index}}."""
    T = ui['tree']
    tiers = T['tiers']
    choice_kinds = T['choice_kinds']
    chip_order = T['chip_order']
    nodes = [n for n in element_nodes(tree, el) if side_of(ui, n) == side and visible(ui, n, mode)]
    order = {n['id']: i for i, n in enumerate(element_nodes(tree, el))}
    lines = {}

    def line_of(n):
        k = n['kind']
        if k == 'skill_set':
            return ('set', '', '')
        if k == 'passive':
            return ('passive', '', '')
        if k == 'new_skill':
            return (eff_chip(n), 'slot', '')
        return (eff_chip(n), str(n.get('extends_move') or ''), str(n.get('mode') or ''))

    def sort_key(lk):
        chip, move, md = lk
        ci = chip_order.index(chip) if chip in chip_order else len(chip_order)
        first = min(order[n['id']] for n in lines[lk])
        if chip in ('set', 'passive'):
            return (ci, 0, 0, 0, first)
        if move == 'slot':
            return (ci, 1, 0, 0, first)
        km = key_moves(moves, el, chip)
        mi = km.index(move) if move in km else 9
        return (ci, 0, mi, mode_index(moves, move, md) if md else 0, first)

    later = []
    for n in nodes:
        lk = line_of(n)
        if lk[0] not in ('set', 'passive') and lk[1] != 'slot' and lk[2] == '':
            later.append(n)
            continue
        lines.setdefault(lk, []).append(n)
    for n in later:
        lk = line_of(n)
        cands = sorted([q for q in lines if q[0] == lk[0] and q[1] == lk[1] and q[1] != 'slot'], key=sort_key)
        lines.setdefault(cands[0] if cands else lk, []).append(n)

    passive_id = str(tree['elements'][el].get('passive') or '')
    out = []
    for lk in sorted(lines, key=sort_key):
        chip, move, md = lk
        by_tier = {}
        for n in sorted(lines[lk], key=lambda n: order[n['id']]):
            by_tier.setdefault(int(tiers.get(n['kind'], 1)), []).append(n)
        entries = {}
        if chip == 'passive':
            entries[0] = [{'key': 'root:passive/' + passive_id, 'type': 'root', 'ids': [], 'move': '', 'mode': '', 'passive': passive_id}]
        elif chip != 'set' and move != 'slot':
            entries[0] = [{'key': 'root:%s/%s' % (move, md), 'type': 'root', 'ids': [], 'move': move, 'mode': md}]
        for t in sorted(by_tier):
            if t == 0 and t in entries:
                raise SystemExit('a node at tier 0 under a root: ' + by_tier[t][0]['id'])
            ns = by_tier[t]
            parent = {n['id']: n['id'] for n in ns}

            def find(a):
                while parent[a] != a:
                    a = parent[a]
                return a

            def union(a, b):
                ra, rb = find(a), find(b)
                if ra == rb:
                    return
                # the root is the member first in data order
                if order[ra] <= order[rb]:
                    parent[rb] = ra
                else:
                    parent[ra] = rb

            for ck in choice_kinds:
                same = [n['id'] for n in ns if n['kind'] == ck]
                for x in same[1:]:
                    union(same[0], x)
            ids = set(parent)
            for n in ns:
                for x in n.get('excludes') or []:
                    if x in ids:
                        union(n['id'], x)
            groups = {}
            for n in ns:
                groups.setdefault(find(n['id']), []).append(n['id'])
            ents = []
            for r in sorted(groups, key=lambda r: min(order[i] for i in groups[r])):
                mem = sorted(groups[r], key=lambda i: order[i])
                if len(mem) == 1:
                    ents.append({'key': mem[0], 'type': 'node', 'ids': mem})
                else:
                    ents.append({'key': 'choice:' + mem[0], 'type': 'choice', 'ids': mem})
            entries[t] = ents
        width = max(len(v) for v in entries.values())
        out.append({'chip': chip, 'move': move, 'mode': md, 'entries': entries, 'width': width})
    return {'lines': out, 'order': order}


def partitions(n, b):
    """Every split of n lines into b contiguous non-empty bands, as lists of break indices, in lexicographic order."""
    if b == 1:
        yield []
        return

    def rec(start, left):
        if left == 0:
            yield []
            return
        for i in range(start, n - left + 1):
            for rest in rec(i + 1, left - 1):
                yield [i] + rest

    for br in rec(1, b - 1):
        yield br


def bands_of(lines, W, L, zone):
    """The lines' bands. Every split of the lines (in order) into bands no wider than W slots is scored: one whose
    height fits the zone at the nominal pitch beats any that does not; among those that fit, the fewest bands holding a
    single line (a lone line reads as stranded: the plan's layout proofs), then the shape (widest band by total height,
    in pixels at the nominal pitch) nearest the zone's own shape (by ratio), then the fewest bands; among those that do
    not fit, the shortest. Ties keep the first split in order (fewer bands first, then the break indices in lexicographic
    order). Both implementations compute the scores with the same operations in the same order, so they tie alike."""
    n = len(lines)
    if n == 0:
        return []
    gap = float(L['band_gap'])
    icon, px, py = float(L['icon']), float(L['pitch_x']), float(L['pitch_y'])
    zw, zh = float(zone[2]), float(zone[3]) - float(L.get('top_pad', 0))
    best, best_score = None, None
    for b in range(1, n + 1):
        for br in partitions(n, b):
            cuts = [0] + br + [n]
            groups = [list(range(cuts[i], cuts[i + 1])) for i in range(b)]
            ok, rows, widest, lone = True, 0, 0, 0
            for g in groups:
                w = sum(lines[i]['width'] for i in g)
                if w > W and len(g) > 1:
                    ok = False
                    break
                ts = set()
                for i in g:
                    ts |= set(lines[i]['entries'].keys())
                rows += len(ts)
                widest = max(widest, w)
                if len(g) == 1 and b > 1:
                    lone += 1
            if not ok:
                continue
            span = rows - 1 + gap * (b - 1)
            cw = (widest - 1) * px + icon
            ch = span * py + icon
            fits = ch <= zh + 1e-6
            if fits:
                score = (0, lone, abs(math.log((cw / ch) / (zw / zh))), b)
            else:
                score = (1, 0, span, b)
            if best_score is None or score < best_score:
                best, best_score = groups, score
    return best


def algorithm(tree, moves, ui, el, side, mode):
    """{'places': {key: [col, row]}, 'items': [...], 'links': [[a, b]], 'bands': [...]} on the slot grid."""
    L = ui['layout']
    W = int(L['left_width'] if side == 'left' else L['right_width'])
    gap = float(L['band_gap'])
    st = structure(tree, moves, ui, el, side, mode)
    lines = st['lines']
    bands = bands_of(lines, W, L, L['zones'][side])
    places, items, links, band_info = {}, [], [], []
    top = 0.0
    for bi, g in enumerate(bands or []):
        tiers = sorted(set().union(*[set(lines[i]['entries'].keys()) for i in g]))
        tier_row = {t: j for j, t in enumerate(tiers)}
        bw = sum(lines[i]['width'] for i in g)
        x = (W - bw) / 2.0
        for i in g:
            ln = lines[i]
            for t in sorted(ln['entries']):
                ents = ln['entries'][t]
                for k, e in enumerate(ents):
                    col = x + (ln['width'] - len(ents)) / 2.0 + k
                    row = top + tier_row[t]
                    places[e['key']] = [round(col, 3), round(row, 3)]
                    items.append(dict(e, line=i, tier=t, band=bi, chip=ln['chip'], col=round(col, 3), row=round(row, 3)))
            ts = sorted(ln['entries'])
            for a, b in zip(ts, ts[1:]):
                for ea in ln['entries'][a]:
                    for eb in ln['entries'][b]:
                        links.append([ea['key'], eb['key']])
            x += ln['width']
        band_info.append({'lines': g, 'top': round(top, 3), 'rows': len(tiers), 'tiers': tiers, 'width': bw})
        top += len(tiers) + gap
    return {'places': places, 'items': items, 'links': links, 'bands': band_info, 'width': W}


def pins_of(alg):
    """Pins keyed by node id (each member of a choice at the choice's place) and root key."""
    out = {}
    for it in alg['items']:
        if it['type'] == 'root':
            out[it['key']] = [it['col'], it['row']]
        else:
            for i in it['ids']:
                out[i] = [it['col'], it['row']]
    return out


def to_px(ui, side, places):
    """Slot centres in zone pixels (the window's rule, AdvancementLayout.place: the grid centred in the zone, its pitch
    filling the zone between min_pitch_* and max_pitch_*, fill_margin [side, top, bottom] kept clear)."""
    L = ui['layout']
    zx, zy, zw, zh = L['zones'][side]
    icon, px, py = float(L['icon']), float(L['pitch_x']), float(L['pitch_y'])
    if not places:
        return {}, (px, py), (0.0, 0.0)
    fm = L.get('fill_margin') or [0, 0, 0]
    m_side, m_top, m_bottom = float(fm[0]), float(fm[1]), float(fm[2])
    cs = [p[0] for p in places.values()]
    rs = [p[1] for p in places.values()]
    c0, c1, r0, r1 = min(cs), max(cs), min(rs), max(rs)
    top = float(L.get('top_pad', 0))
    avail_w = zw - 2 * m_side
    avail_h = zh - top - m_top - m_bottom
    if r1 > r0:
        py = min(max((avail_h - icon) / (r1 - r0), float(L['min_pitch_y'])), float(L.get('max_pitch_y', 1000)))
    if c1 > c0:
        px = min(max((avail_w - icon) / (c1 - c0), float(L['min_pitch_x'])), float(L.get('max_pitch_x', 1000)))
        if r1 > r0:
            px = max(min(px, py * float(L.get('max_aspect', 1000.0))), float(L['min_pitch_x']))
    cw = (c1 - c0) * px + icon
    ch = (r1 - r0) * py + icon
    ox = (zw - cw) / 2.0 + icon / 2.0 - c0 * px
    oy = top + m_top + (avail_h - ch) / 2.0 + icon / 2.0 - r0 * py
    return {k: (ox + c * px, oy + r * py) for k, (c, r) in places.items()}, (px, py), (cw, ch)


def fmt(doc):
    """The file: one pin per line, so a hand-tuned diff reads."""
    def pins_block(p, ind):
        s = '{\n'
        els = list(p.keys())
        for ei, el in enumerate(els):
            s += ind + '  "%s": {\n' % el
            for si, side in enumerate(SIDES):
                s += ind + '    "%s": {\n' % side
                ks = list(p[el][side].keys())
                for ki, k in enumerate(ks):
                    c, r = p[el][side][k]
                    s += ind + '      %s: [%s, %s]%s\n' % (json.dumps(k), _num(c), _num(r), ',' if ki < len(ks) - 1 else '')
                s += ind + '    }%s\n' % (',' if si < len(SIDES) - 1 else '')
            s += ind + '  }%s\n' % (',' if ei < len(els) - 1 else '')
        return s + ind + '}'
    s = '{\n'
    s += '  "format": %s,\n' % json.dumps(doc['format'])
    s += '  "version": %d,\n' % doc['version']
    s += '  "_doc": %s,\n' % json.dumps(doc['_doc'], indent=4, ensure_ascii=False).replace('\n]', '\n  ]')
    s += '  "source": %s,\n' % json.dumps(doc['source'])
    s += '  "pins": ' + pins_block(doc['pins'], '  ') + ',\n'
    s += '  "generated": ' + pins_block(doc['generated'], '  ') + '\n'
    return s + '}\n'


def _num(v):
    v = round(float(v), 3)
    return str(int(v)) if v == int(v) else repr(v)


DOC = [
    "Where the Character Advancement window puts each node of each element's two trees in ring mode "
    "(AdvancementLayout.place). Written by tools/ui/advancement_layout.py from data/sway/skill_tree.json, moves.json and "
    "data/ui/advancement.json; then hand-tuned by eye in 'pins' (re-running the tool keeps a tuned pin while its id is "
    "still in the tree, adds new ids at the algorithm's place and drops gone ones; --reset puts every pin back).",
    "pins.<element>.<left|right>: {node id or root:<move>/<mode> (root:passive/<id> for the passive line): [col, row]} on "
    "the slot grid (a col is about layout.pitch_x pixels, a row about layout.pitch_y; halves are the lattice's diamonds). The "
    "members of a choice share one place (the first member's is used). The window centres the pinned grid in its zone and "
    "spreads its pitch to fill it (layout.min_pitch_* to max_pitch_*, fill_margin kept clear).",
    "generated: the algorithm's own places, untouched by hand: tests/ui/test_advancement.gd checks the GDScript algorithm "
    "gives the same numbers, and that every ring-visible node has a pin; re-run the tool when the tree changes.",
]


def build(reset=False):
    tree, moves, ui = load()
    old = {}
    if OUT.exists() and not reset:
        try:
            old = json.loads(OUT.read_text()).get('pins', {})
        except Exception:
            old = {}
    gen, pins, report = {}, {}, []
    for el in ELEMENTS:
        gen[el], pins[el] = {}, {}
        for side in SIDES:
            alg = algorithm(tree, moves, ui, el, side, 'ring')
            g = pins_of(alg)
            gen[el][side] = g
            kept = (old.get(el) or {}).get(side) or {}
            pins[el][side] = {k: (kept[k] if k in kept else v) for k, v in g.items()}
            report.append((el, side, alg))
    doc = {'format': 'tidebreak-advancement-layout', 'version': 1, '_doc': DOC,
           'source': {'tree_version': tree.get('version', 1), 'by': 'tools/ui/advancement_layout.py'},
           'pins': pins, 'generated': gen}
    return doc, report, ui


def proof_png(ui, report, tree, outdir, pins=None):
    """A proof picture per element, for judging the lattice by eye (not the window's art): each tree at the window's
    zone, placed by the pins when given (else the algorithm); gold roots with their key, circles (number trades), squares
    (twists, techniques, new skills, sets) with a kind letter, octagons with arrow tabs (choices: the member count), held
    nodes grey with '?', the links, the first-win gate on the first row and the lessons gate on the first twist row."""
    from PIL import Image, ImageDraw, ImageFont
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    L = ui['layout']
    icon = float(L['icon'])
    r = icon / 2
    nodes = {n['id']: n for el in ELEMENTS for n in element_nodes(tree, el)}
    shapes = ui['tree']['shapes']
    badge = ui['words']['key_badges']
    letter = {'enhance': 'E', 'synergy': 'Sy', 'passive': 'P', 'variation': 'T', 'mastery': 'Q', 'new_skill': 'N',
              'skill_set': 'S', 'world_only': 'W'}
    styles = json.loads((F / 'data/bending/fighting_styles.json').read_text())
    canon = {}
    for sid, st in styles['styles'].items():
        if st.get('canon'):
            canon[st['element']] = st['label']
    try:
        f_big = ImageFont.load_default(size=24)
        f_mid = ImageFont.load_default(size=15)
        f_small = ImageFont.load_default(size=12)
    except TypeError:
        f_big = f_mid = f_small = ImageFont.load_default()
    gold, green, grey, ink = (201, 162, 39), (62, 224, 62), (125, 135, 148), (233, 227, 207)
    by_el = {}
    for el, side, alg in report:
        by_el.setdefault(el, {})[side] = alg
    paths = []
    for el, sides in by_el.items():
        im = Image.new('RGB', (1600, 900), (20, 24, 32))
        d = ImageDraw.Draw(im)
        d.rectangle([40, 40, 1560, 820], outline=(168, 132, 74), width=2)
        d.text((800, 52), 'layout proof: %s (tools/ui/advancement_layout.py; not the window art)' % el, fill=(255, 209, 0), font=f_mid, anchor='mt')
        for side, alg in sides.items():
            zx, zy, zw, zh = L['zones'][side]
            d.rectangle([zx, zy, zx + zw, zy + zh], outline=(48, 54, 66))
            places = dict(alg['places'])
            if pins:
                pn = pins.get(el, {}).get(side, {})
                for it in alg['items']:
                    k = it['key'] if it['type'] == 'root' else it['ids'][0]
                    if k in pn:
                        places[it['key']] = pn[k]
            pts, pitch, size = to_px(ui, side, places)
            P = {k: (zx + x, zy + y) for k, (x, y) in pts.items()}
            title = canon.get(el, '').upper() if side == 'left' else str(tree['skill_sets'][tree['elements'][el]['skill_set']]['name']).upper()
            d.text((zx + zw / 2, 92), title, fill=(241, 237, 226), font=f_big, anchor='mm')
            d.text((zx + zw / 2, 118), '%d slots, %d bands, pitch %.0fx%.0f' % (len(alg['items']), len(alg['bands']), pitch[0], pitch[1]),
                   fill=(154, 148, 134), font=f_small, anchor='mm')
            for a, b in alg['links']:
                (ax, ay), (bx, by) = P[a], P[b]
                d.line([ax, ay + r, bx, by - r - 4], fill=(138, 143, 153), width=2)
                d.polygon([(bx, by - r), (bx - 4, by - r - 7), (bx + 4, by - r - 7)], fill=(138, 143, 153))
            band0 = [it for it in alg['items'] if it['band'] == 0]
            if band0:
                x0 = min(P[it['key']][0] for it in band0) - r - 12
                y_first = min(P[it['key']][1] for it in band0)
                tw = [P[it['key']][1] for it in band0 if it['tier'] >= 2]
                for y, num in ((y_first, '1'), (min(tw) if tw else None, '4')):
                    if y is None:
                        continue
                    d.line([x0, y, x0 + 8, y], fill=(196, 106, 60), width=2)
                    d.rectangle([x0 - 12, y - 6, x0 - 3, y + 5], fill=(196, 106, 60))
                    d.text((x0 - 16, y), num, fill=(226, 138, 92), font=f_mid, anchor='rm')
            for it in alg['items']:
                x, y = P[it['key']]
                if it['type'] == 'root':
                    d.rectangle([x - r, y - r, x + r, y + r], fill=(70, 58, 30), outline=gold, width=3)
                    d.text((x, y), badge.get(it['chip'], it['chip']), fill=(255, 230, 150), font=f_mid, anchor='mm')
                elif it['type'] == 'choice':
                    k = r * 1.08
                    poly = [(x + k * c, y + k * s) for c, s in [(-.42, -1), (.42, -1), (1, -.42), (1, .42), (.42, 1), (-.42, 1), (-1, .42), (-1, -.42)]]
                    d.polygon(poly, fill=(40, 48, 60), outline=green, width=3)
                    d.polygon([(x - r - 10, y), (x - r - 3, y - 6), (x - r - 3, y + 6)], fill=(255, 209, 0))
                    d.polygon([(x + r + 10, y), (x + r + 3, y - 6), (x + r + 3, y + 6)], fill=(255, 209, 0))
                    d.text((x, y), '%d' % len(it['ids']), fill=ink, font=f_mid, anchor='mm')
                else:
                    n = nodes[it['ids'][0]]
                    col = grey if n.get('held') else green
                    if shapes.get(n['kind']) == 'circle':
                        d.ellipse([x - r, y - r, x + r, y + r], fill=(40, 48, 60), outline=col, width=3)
                    else:
                        d.rectangle([x - r, y - r, x + r, y + r], fill=(40, 48, 60), outline=col, width=3)
                    d.text((x, y), '?' if n.get('held') else letter.get(n['kind'], '?'), fill=ink if not n.get('held') else grey, font=f_mid, anchor='mm')
        legend = ('gold square: a move you have (its key)   circle: enhance E / synergy Sy / passive P   square: twist T / '
                  'technique Q / new skill N / skill set S   octagon: a choice (members)   grey ?: held   orange: the gates')
        d.text((800, 790), legend, fill=(154, 148, 134), font=f_small, anchor='mm')
        p = outdir / ('advancement_layout_%s.png' % el)
        im.save(p)
        paths.append(str(p))
    return paths


def main(argv):
    reset = '--reset' in argv
    doc, report, ui = build(reset)
    text = fmt(doc)
    if '--check' in argv:
        cur = json.loads(OUT.read_text()) if OUT.exists() else {}
        stale = cur.get('generated') != json.loads(text)['generated']
        print('advancement_layout.json is %s' % ('STALE: re-run tools/ui/advancement_layout.py' if stale else 'current'))
        return 1 if stale else 0
    OUT.write_text(text)
    for el, side, alg in report:
        pts, pitch, size = to_px(ui, side, alg['places'])
        zone = ui['layout']['zones'][side]
        fits = size[0] <= zone[2] + 0.01 and size[1] <= zone[3] + 0.01
        print('%-5s %-5s %2d lines %d bands widths %-12s rows %-10s pitch %3.0fx%3.0f  %3dx%3d px in %dx%d %s' % (
            el, side, sum(len(b['lines']) for b in alg['bands']), len(alg['bands']),
            ','.join(str(b['width']) for b in alg['bands']), ','.join(str(b['rows']) for b in alg['bands']),
            pitch[0], pitch[1], size[0], size[1], zone[2], zone[3], 'ok' if fits else 'DOES NOT FIT'))
    if '--png' in argv:
        i = argv.index('--png')
        tree, _moves, _ui = load()
        for p in proof_png(ui, report, tree, argv[i + 1], doc['pins']):
            print('PNG', p)
    print('wrote', OUT)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
