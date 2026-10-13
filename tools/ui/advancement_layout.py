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


# --- the diamond lattice (the pins; 2026-10-10 repair of the critic's "sparse lattice") -----------------------------------
#
# The reference packs its talents on a diamond lattice: every other row is offset by half a column, each pick sits
# diagonally under the one before it, and the shut rows lie below one gate line. The pins are packed that way:
#   points   a point is (x, row) with x in half columns and x + row even (so a row's neighbours are 2 apart and the next
#            row's are 1 to the side: the diamonds). A pin's col is x / 2.
#   shapes   each line keeps its tiers on consecutive rows; a tier of k entries spans 2(k-1) half columns, centred under
#            the tier before it, stepping half a column aside when the row's parity asks (so a chain of one-pick tiers
#            zig-zags, as the reference's do).
#   sections the tiers before a line's first gated tier (switches.full_lessons_kinds: twists, techniques, new skills,
#            sets) go ABOVE the gate row, the rest below it, so one gate line tells the truth: every pick under it waits
#            for the Full lessons, none above it does.
#   packing  above the gate, lines go in chip order to the topmost row, then the column, where they fit (no two points
#            of a row closer than 2) at the least penalty (links crossing links, passing over another plate or running flatter than a diagonal; each line tries its flat shape and, where a tier fans out, a tall one); then
#            lines that continue below sink to the gate row while that costs nothing; below the gate each line's rest
#            goes as near under its parents as the penalty allows.
#   width    every width from layout.lattice.<side>_widths is packed; the least penalty wins, then the shape nearest the
#            zone's (at lattice.half_px x row_px), then the narrower.

def _lattice_shape(ln, ts, tall=False):
    """[(row, x, key)] of one line's tiers `ts` from row 0, x >= 0, x + row even. `tall`: a tier whose links to the tier
    before would run flatter than a diagonal (three picks under one, or one under three: a fan) drops as many rows as it
    spreads, centred straight under the tier before, so every link is a diagonal or a straight drop (2026-10-10 pass 2,
    the critic's "fan from the '1' spike root")."""
    pts = []
    prev_c = 0
    prev_k = 0
    step = -1
    row = 0
    for j, t in enumerate(ts):
        ents = ln['entries'][t]
        k = len(ents)
        spread = (prev_k - 1) + (k - 1) if j else 0
        if tall and j and spread >= 2:
            # dy = spread keeps the parity with the same centre (spread and k - prev_k have one parity)
            row += spread
            want = prev_c
            start = want - (k - 1)
        else:
            row += 1 if j else 0
            want = prev_c
            if (want - (k - 1) - row) % 2:
                step = -step
                want += step
            start = want - (k - 1)
        for i, e in enumerate(ents):
            pts.append((row, start + 2 * i, e['key']))
        prev_c = want
        prev_k = k
    mn = min(x for _, x, _ in pts)
    if mn % 2:
        mn -= 1
    return [(j, x - mn, k) for j, x, k in pts]


def _lattice_shapes(ln, ts):
    """The line's shapes to try: the flat one and, when it differs, the tall one."""
    a = _lattice_shape(ln, ts)
    b = _lattice_shape(ln, ts, tall=True)
    return [a] if a == b else [a, b]


def _lattice_free(occ, pts, r0, x0, W, own=()):
    for j, x, k in pts:
        X, R = x + x0, j + r0
        if X < 0 or X > W or (X + R) % 2:
            return False
        for ox, ok in occ.get(R, ()):
            if ok not in own and abs(ox - X) < 2:
                return False
    return True


def _lattice_put(occ, pts, r0, x0):
    for j, x, k in pts:
        occ.setdefault(j + r0, []).append((x + x0, k))
    return {k: (x + x0, j + r0) for j, x, k in pts}


def _seg_cross(a, b, c, d):
    if a in (c, d) or b in (c, d):
        return False

    def o(p, q, r):
        v = (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
        return (v > 1e-9) - (v < -1e-9)
    return o(a, b, c) * o(a, b, d) < 0 and o(c, d, a) * o(c, d, b) < 0


def _lattice_penalty(P, links, hx, vy, icon):
    """2 per pair of links that cross, 1 per plate a link passes over (closer than 0.62 icon to its middle part), 1 per
    link flatter than a diagonal (it runs across its neighbours' links: the critic's "fan")."""
    segs = [((P[a][0] * hx, P[a][1] * vy), (P[b][0] * hx, P[b][1] * vy), a, b) for a, b in links if a in P and b in P]
    n = 0
    for a, b in links:
        if a in P and b in P and abs(P[b][0] - P[a][0]) > abs(P[b][1] - P[a][1]):
            n += 1
    for i in range(len(segs)):
        for j in range(i + 1, len(segs)):
            if _seg_cross(segs[i][0], segs[i][1], segs[j][0], segs[j][1]):
                n += 2
    for (ax, ay), (bx, by), ka, kb in segs:
        dx, dy = bx - ax, by - ay
        l2 = dx * dx + dy * dy
        for k, (x, y) in P.items():
            if k in (ka, kb) or l2 == 0:
                continue
            px, py = x * hx, y * vy
            t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / l2))
            if 0.02 < t < 0.98 and math.hypot(px - (ax + t * dx), py - (ay + t * dy)) < icon * 0.62:
                n += 1
    return n


def _links_of_lines(lines):
    out = []
    for ln in lines:
        ts = sorted(ln['entries'])
        for a, b in zip(ts, ts[1:]):
            for ea in ln['entries'][a]:
                for eb in ln['entries'][b]:
                    out.append((ea['key'], eb['key']))
    return out


def _lattice_pack(lines, W, gated, hx, vy, icon):
    links = _links_of_lines(lines)
    pen = lambda P: _lattice_penalty(P, links, hx, vy, icon)  # noqa: E731
    occ, P, uppers, lowers = {}, {}, [], []
    for li, ln in enumerate(lines):
        ts = sorted(ln['entries'])
        cut = 0
        while cut < len(ts) and (gated is None or not any(gated(e) for e in ln['entries'][ts[cut]])):
            cut += 1
        if cut:
            first, best, base = None, None, pen(P)
            for si, pts in enumerate(_lattice_shapes(ln, ts[:cut])):
                for r0 in range(0, 80):
                    if first is not None and r0 > first + 1:
                        break
                    for x0 in range(0, W + 1):
                        if _lattice_free(occ, pts, r0, x0, W):
                            if first is None:
                                first = r0
                            Q = dict(P)
                            Q.update({k: (x + x0, j + r0) for j, x, k in pts})
                            sc = (pen(Q) - base, r0, x0, si)
                            if best is None or sc < best[0]:
                                best = (sc, r0, x0, pts)
            pts = best[3]
            P.update(_lattice_put(occ, pts, best[1], best[2]))
            uppers.append((li, pts, best[1], best[2]))
        if cut < len(ts):
            lowers.append((li, ts[cut:], ts[:cut]))
    gate = (max(occ) + 1) if occ else 0
    # lines that go on below the gate sink toward it (an even step keeps the parity) while that costs nothing
    for li, pts, r0, x0 in reversed(uppers):
        if not any(lw[0] == li for lw in lowers):
            continue
        keys = {k for _, _, k in pts}
        h = max(j for j, _, _ in pts) + 1
        best, base = r0, pen(P)
        for nr in range(r0 + 2, gate - h + 1, 2):
            if not _lattice_free(occ, pts, nr, x0, W, own=keys):
                break
            Q = dict(P)
            Q.update({k: (x + x0, j + nr) for j, x, k in pts})
            if pen(Q) <= base:
                best = nr
        if best != r0:
            for r in occ:
                occ[r] = [p for p in occ[r] if p[1] not in keys]
            P.update(_lattice_put(occ, pts, best, x0))
    for li, ts, upts in lowers:
        ln = lines[li]
        parents = [P[e['key']] for e in ln['entries'][upts[-1]]] if upts else []
        best, base = None, pen(P)
        for si, pts in enumerate(_lattice_shapes(ln, ts)):
            for r0 in range(gate, gate + 16):
                for x0 in range(0, W + 1):
                    if not _lattice_free(occ, pts, r0, x0, W):
                        continue
                    Q = dict(P)
                    Q.update({k: (x + x0, j + r0) for j, x, k in pts})
                    dist = 0.0
                    for p in parents:
                        for e in ln['entries'][ts[0]]:
                            c = Q[e['key']]
                            dist += abs(p[0] - c[0]) * hx + (c[1] - p[1]) * vy
                    sc = (pen(Q) - base, r0 - gate > 1, round(dist, 3), r0, x0, si)
                    if best is None or sc < best[0]:
                        best = (sc, r0, x0, pts)
        pts = best[3]
        P.update(_lattice_put(occ, pts, best[1], best[2]))
    return P, gate, pen(P)


def lattice(tree, moves, ui, el, side, mode='ring'):
    """{'places': {key: [col, row]}, 'gate_row': row or -1, 'width': half columns, 'penalty': n} (see the notes above)."""
    L = ui['layout']
    lat = L.get('lattice') or {}
    widths = lat.get(side + '_widths') or ([6, 13] if side == 'left' else [4, 10])
    hx, vy = float(lat.get('half_px', 34)), float(lat.get('row_px', 64))
    icon = float(lat.get('icon', L['icon']))
    zone = L['zones'][side]
    zw, zh = float(zone[2]), float(zone[3])
    kinds = set(ui['switches'].get('full_lessons_kinds') or [])
    nodes = {n['id']: n for n in element_nodes(tree, el)}

    def gated(e):
        return e['type'] != 'root' and nodes[e['ids'][0]]['kind'] in kinds

    lines = structure(tree, moves, ui, el, side, mode)['lines']
    sections = bool(lat.get('sections', False))

    def score(order, W):
        ls = [lines[i] for i in order]
        P, gate, pen = _lattice_pack(ls, W, gated if sections else None, hx, vy, icon)
        xs = [x for x, _ in P.values()]
        ys = [y for _, y in P.values()]
        cw = (max(xs) - min(xs)) * hx + icon
        ch = (max(ys) - min(ys)) * vy + icon
        # the share of the box's lattice points in use (a ragged tail or a hole reads as sparse)
        points = sum(1 for r in range(min(ys), max(ys) + 1) for x in range(min(xs), max(xs) + 1) if (x + r) % 2 == 0)
        fill = len(P) / float(max(points, 1))
        inv = sum(1 for a in range(len(order)) for b in range(a + 1, len(order)) if order[a] > order[b])
        sc = (pen, round(abs(math.log((cw / ch) / (zw / zh))) + 1.5 * (1.0 - fill) + 0.01 * inv, 6), W, tuple(order))
        return sc, P, gate, pen

    best = None
    for W in range(int(widths[0]), int(widths[1]) + 1):
        # the lines in chip order, then better orders found by swapping two lines while that improves the score (a line
        # may leave its chip order to fill a hole: the roots carry their key, so the tree still reads)
        order = list(range(len(lines)))
        cur = score(order, W)
        grew = True
        while grew:
            grew = False
            for a in range(len(order)):
                for b in range(a + 1, len(order)):
                    o2 = order[:]
                    o2[a], o2[b] = o2[b], o2[a]
                    s2 = score(o2, W)
                    if s2[0] < cur[0]:
                        order, cur, grew = o2, s2, True
        if best is None or cur[0] < best[0]:
            best = (cur[0], W, cur[1], cur[2], cur[3])
    _, W, P, gate, pen = best
    x0 = min(x for x, _ in P.values())
    x0 -= x0 % 2
    has_gated = sections and any(gated(e) for ln in lines for es in ln['entries'].values() for e in es)
    return {'places': {k: [(x - x0) / 2.0, float(y)] for k, (x, y) in P.items()}, 'gate_row': gate if has_gated else -1,
            'width': W, 'penalty': pen, 'links': _links_of_lines(lines)}


def lattice_pins(lat, lines_items):
    """Pins keyed by node id (each member of a choice at the choice's place) and root key, from lattice places."""
    out = {}
    for it in lines_items:
        p = lat['places'][it['key']]
        if it['type'] == 'root':
            out[it['key']] = p
        else:
            for i in it['ids']:
                out[i] = p
    return out


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
    "the diamond lattice (version 2, the tool's lattice(): a col is layout.pitch_x pixels, a row layout.pitch_y; a row's "
    "cols are whole on even rows and halves on odd ones, so each pick sits diagonally under the one before it; the gated "
    "kinds sit below one gate row). The members of a choice share one place (the first member's is used). The window "
    "centres the pinned grid in its zone and spreads its pitch to fill it (layout.min_pitch_* to max_pitch_*, fill_margin "
    "kept clear). A hand-tuned pin must keep the lattice's rule (tests/ui/test_advancement.gd checks it).",
    "generated: the band algorithm's own places (the GDScript fallback for an unpinned id and world mode), untouched by "
    "hand: tests/ui/test_advancement.gd checks the GDScript algorithm gives the same numbers, and that every ring-visible "
    "node has a pin; re-run the tool when the tree changes.",
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
            lat = lattice(tree, moves, ui, el, side, 'ring')
            seed = lattice_pins(lat, alg['items'])
            alg['lattice'] = lat
            kept = (old.get(el) or {}).get(side) or {}
            pins[el][side] = {k: (kept[k] if k in kept else v) for k, v in seed.items()}
            report.append((el, side, alg))
    doc = {'format': 'tidebreak-advancement-layout', 'version': 2, '_doc': DOC,
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
        lat = alg['lattice']
        lp, lpitch, lsize = to_px(ui, side, lat['places'])
        lfits = lsize[0] <= zone[2] + 0.01 and lsize[1] <= zone[3] + 0.01
        print('      lattice (the pins): width %d half columns, %d rows, gate row %d, penalty %d, pitch %3.0fx%3.0f  %3dx%3d px %s' % (
            lat['width'], int(max(p[1] for p in lat['places'].values())) + 1, lat['gate_row'], lat['penalty'],
            lpitch[0], lpitch[1], lsize[0], lsize[1], 'ok' if lfits else 'DOES NOT FIT'))
    if '--png' in argv:
        i = argv.index('--png')
        tree, _moves, _ui = load()
        for p in proof_png(ui, report, tree, argv[i + 1], doc['pins']):
            print('PNG', p)
    print('wrote', OUT)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
