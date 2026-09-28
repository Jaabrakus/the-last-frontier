# Foliage card atlas generator (package C). Blender 5.2, background:
#
#   Blender -b --factory-startup -P tools/environment/vegetation/build_atlas.py -- [only=pine_a,...]
#       [res=512] [samples=32] [work=<dir>]
#
# Builds each spray (twigs + needles or leaves) as real geometry, then renders it top-down with
# an orthographic camera into <work>/<tile>_albedo.png (emission = colour * local AO, sRGB) and
# <work>/<tile>_normal.png (camera-facing normal, raw). assemble_atlas.py packs the tiles into
# assets/environment/vegetation/foliage/foliage_{albedo,normal}.png (4 x 4 tiles of 512 px).
#
# Tile frame: the card is the XY plane, spray base at the bottom centre of the tile, growing
# toward +Y (image up). Tile size in metres = TILES[name]["size"]. The tree generator
# (build_trees.py) reads the same table from foliage_tiles.json.
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bcommon import *
from bcommon import _nodes

A = args()
RES = int(A.get('res', '512'))
SAMPLES = int(A.get('samples', '32'))
WORK = A.get('work', '/tmp/frontier_veg_atlas')
ONLY = A.get('only', '').split(',') if A.get('only') else []

# name: tile index in the 4x4 atlas, size (m), kind, seed
TILES = {
    'pine_a':    dict(index=0, size=1.10, kind='pine', seed=11),
    'pine_b':    dict(index=1, size=1.10, kind='pine', seed=12),
    'hemlock_a': dict(index=2, size=0.80, kind='hemlock', seed=21),
    'hemlock_b': dict(index=3, size=0.80, kind='hemlock', seed=22),
    'oak_a':     dict(index=4, size=0.95, kind='oak', seed=31),
    'oak_b':     dict(index=5, size=0.95, kind='oak', seed=32),
    'maple_a':   dict(index=6, size=0.90, kind='maple', seed=41),
    'maple_b':   dict(index=7, size=0.90, kind='maple', seed=42),
    'birch_a':   dict(index=8, size=0.70, kind='birch', seed=51),
    'birch_b':   dict(index=9, size=0.70, kind='birch', seed=52),
    'hazel_a':   dict(index=10, size=0.75, kind='hazel', seed=61),
    'hazel_b':   dict(index=11, size=0.75, kind='hazel', seed=62),
    'maple_red': dict(index=12, size=0.90, kind='maple_red', seed=43),
    'deadtwig':  dict(index=13, size=1.00, kind='dead', seed=71),
    'fir_side':  dict(index=14, size=1.40, kind='fir_side', seed=81),
    'shrub04':   dict(index=15, size=0.62, kind='shrub04', seed=91),
}


def srgb(c):
    """sRGB triple -> linear (the attribute colours are emitted as linear)."""
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def jitter_col(rng, c, hue=0.03, val=0.12, sat=0.1):
    import colorsys
    h, s, v = colorsys.rgb_to_hsv(*c)
    h = (h + rng.uniform(-hue, hue)) % 1.0
    s = min(1, max(0, s * (1 + rng.uniform(-sat, sat))))
    v = min(1, max(0, v * (1 + rng.uniform(-val, val))))
    return colorsys.hsv_to_rgb(h, s, v)


# --- geometry builders --------------------------------------------------------------------------

class Builder:
    """Accumulates geometry for one tile in a single bmesh with a colour attribute and a
    leaf-local UV map (x across the blade -1..1, y along 0..1; 0,0 on twigs/needles)."""

    def __init__(self, name):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new('leafcol')
        self.uv = self.bm.loops.layers.uv.new('leafuv')
        self.name = name

    def face(self, pts, colors, uvs=None):
        vs = [self.bm.verts.new(p) for p in pts]
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f.smooth = True
        for i, l in enumerate(f.loops):
            c = colors[i] if isinstance(colors, list) else colors
            l[self.col] = (c[0], c[1], c[2], 1.0)
            l[self.uv].uv = uvs[i] if uvs else (0.0, 0.0)
        return f

    def tube(self, path, radii, color, sides=5, color_tip=None):
        """Swept tube along a list of points."""
        rings = []
        n = len(path)
        for i, p in enumerate(path):
            p = Vector(p)
            if i < n - 1:
                t = (Vector(path[i + 1]) - p).normalized()
            else:
                t = (p - Vector(path[i - 1])).normalized()
            a = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            u = t.cross(a).normalized()
            v = t.cross(u).normalized()
            r = radii[i]
            rings.append([p + (u * math.cos(k * 2 * math.pi / sides) + v * math.sin(k * 2 * math.pi / sides)) * r for k in range(sides)])
        for i in range(n - 1):
            f = i / max(1, n - 2)
            c = color if color_tip is None else tuple(color[k] * (1 - f) + color_tip[k] * f for k in range(3))
            for k in range(sides):
                k2 = (k + 1) % sides
                self.face([rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]], c)

    def needle(self, base, direction, length, width, color, color_tip, bend=Vector((0, 0, 0)), segs=3):
        """Needle as a 3-sided tapered prism, slightly curved by `bend`."""
        d = Vector(direction).normalized()
        a = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        u = d.cross(a).normalized()
        v = d.cross(u).normalized()
        pts = []
        for i in range(segs + 1):
            t = i / segs
            pts.append(Vector(base) + d * length * t + bend * (t * t) * length)
        rings = []
        for i, p in enumerate(pts):
            w = width * (1 - 0.75 * (i / segs) ** 1.5)
            rings.append([p + (u * math.cos(k * 2.094) + v * math.sin(k * 2.094)) * w * 0.5 for k in range(3)])
        for i in range(segs):
            f = (i + 0.5) / segs
            c = tuple(color[k] * (1 - f) + color_tip[k] * f for k in range(3))
            for k in range(3):
                k2 = (k + 1) % 3
                self.face([rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]], c)

    def leaf(self, base, direction, normal, outline, length, color, fold=0.25, curl=0.15, rng=None):
        """Flat leaf from a half-outline [(t along, w across)], folded along the midrib (V) and
        curled along its length. direction = midrib, normal = blade normal (toward the camera)."""
        d = Vector(direction).normalized()
        n = Vector(normal)
        n = (n - d * n.dot(d)).normalized()
        s = d.cross(n).normalized()           # across the blade
        def P(t, w):
            # Curl: the tip droops away from the normal; fold: halves rise along the normal.
            along = d * (t * length) - n * (curl * length * t * t)
            return Vector(base) + along + s * (w * length) + n * (abs(w) * length * fold)
        right = [(t, w) for (t, w) in outline]
        mid = [(t, 0.0) for (t, w) in outline]
        halves = [(1.0, right), (-1.0, right)]
        for sign, pts in halves:
            poly = [P(t, 0.0) for (t, w) in mid] + [P(t, sign * w) for (t, w) in reversed(pts)]
            uvs = [(0.0, t) for (t, w) in mid] + [(sign * (w / 0.5), t) for (t, w) in reversed(pts)]
            poly2, uv2 = [], []
            for p, u in zip(poly, uvs):
                if not poly2 or (p - poly2[-1]).length > 1e-6:
                    poly2.append(p)
                    uv2.append(u)
            if sign < 0:
                poly2.reverse()
                uv2.reverse()
            self.face(poly2, color, uv2)

    def build(self):
        ob = mesh_object(self.name, self.bm)
        return ob


def curve_path(start, direction, length, steps, bend, rng, wobble=0.04):
    pts = [Vector(start)]
    d = Vector(direction).normalized()
    for i in range(steps):
        d = (d + Vector(bend) * (1.0 / steps) + Vector((rng.uniform(-wobble, wobble), rng.uniform(-wobble, wobble), rng.uniform(-wobble, wobble) * 0.5))).normalized()
        pts.append(pts[-1] + d * (length / steps))
    return pts


def rot_z(v, ang):
    c, s = math.cos(ang), math.sin(ang)
    return Vector((v.x * c - v.y * s, v.x * s + v.y * c, v.z))


def point_on(path, t):
    """Point and tangent at fraction t along a polyline."""
    segs = [(path[i + 1] - path[i]).length for i in range(len(path) - 1)]
    total = sum(segs)
    target = t * total
    acc = 0.0
    for i, L in enumerate(segs):
        if acc + L >= target or i == len(segs) - 1:
            f = (target - acc) / max(L, 1e-9)
            return path[i].lerp(path[i + 1], min(max(f, 0), 1)), (path[i + 1] - path[i]).normalized()
        acc += L
    return path[-1], (path[-1] - path[-2]).normalized()


def twig_system(rng, S, n_side, side_len, main_len=0.86, angle=(35, 60), curve=0.15, flat=0.1):
    """Main twig from the tile base upward plus alternating side twigs. Returns list of paths
    with (path, order)."""
    base = Vector((0, 0.02 * S, 0))
    main = curve_path(base, (rng.uniform(-0.08, 0.08), 1, 0), main_len * S, 10,
                      (rng.uniform(-curve, curve), 0, rng.uniform(-flat, flat)), rng, 0.03)
    paths = [(main, 0)]
    for i in range(n_side):
        t = 0.18 + 0.7 * (i + rng.uniform(0.0, 0.6)) / n_side
        p, tan = point_on(main, t)
        side = 1 if i % 2 == 0 else -1
        ang = math.radians(rng.uniform(*angle)) * side
        dvec = rot_z(tan, ang)
        dvec.z += rng.uniform(-flat, flat)
        L = side_len * S * rng.uniform(0.7, 1.15) * (1.0 - 0.45 * t)
        sp = curve_path(p, dvec, L, 6, (0, 0.25, rng.uniform(-flat, flat)), rng, 0.04)
        paths.append((sp, 1))
    return paths


# --- species sprays -------------------------------------------------------------------------------

def spray_pine(b, rng, S, variant=0):
    twig_col = srgb((0.36, 0.30, 0.20))
    if variant == 0:
        paths = twig_system(rng, S, n_side=rng.choice([5, 6]), side_len=0.46, angle=(28, 55))
    else:   # fewer, longer, more upright twigs; heavier tufts
        paths = twig_system(rng, S, n_side=4, side_len=0.55, angle=(18, 38), curve=0.25)
    for path, order in paths:
        b.tube(path, [0.006 * (1 - 0.5 * i / len(path)) * (1.4 if order == 0 else 1.0) for i in range(len(path))], twig_col, 5)
    base_col = (0.30, 0.43, 0.36)          # white pine: soft blue-green (sRGB)
    for path, order in paths:
        L = sum((path[i + 1] - path[i]).length for i in range(len(path) - 1))
        n_fasc = int(L / 0.0055)
        for k in range(n_fasc):
            t = k / n_fasc
            # Needles along the distal 70 %, densest in the last third (tufted tips).
            if t < 0.22 or rng.random() > (0.3 + 0.7 * t ** 1.3):
                continue
            p, tan = point_on(path, t)
            az = rng.uniform(0, 2 * math.pi)
            for j in range(5):
                a2 = az + j * 2 * math.pi / 5 + rng.uniform(-0.3, 0.3)
                elev = math.radians(rng.uniform(18, 48))
                a_ = Vector((0, 0, 1)) if abs(tan.z) < 0.9 else Vector((1, 0, 0))
                u = tan.cross(a_).normalized()
                v = tan.cross(u).normalized()
                radial = u * math.cos(a2) + v * math.sin(a2)
                # Flatten the tuft toward the card plane (seen from above).
                radial.z *= 0.45
                d = (tan * math.cos(elev) + radial * math.sin(elev)).normalized()
                length = rng.uniform(0.085, 0.13) * (0.8 + 0.3 * t) * (1.0 if variant == 0 else 1.12)
                c = jitter_col(rng, base_col, 0.02, 0.18, 0.12)
                tip = tuple(min(1, x * 1.12) for x in c)
                b.needle(p, d, length, 0.0036, srgb(c), srgb(tip), bend=Vector((0, 0, -0.08)) + tan * 0.05)


def spray_hemlock(b, rng, S):
    twig_col = srgb((0.40, 0.31, 0.21))
    base = Vector((0, 0.02 * S, 0))
    main = curve_path(base, (rng.uniform(-0.05, 0.05), 1, 0), 0.9 * S, 12, (rng.uniform(-0.1, 0.1), 0, -0.05), rng, 0.02)
    paths = [(main, 0)]
    n_side = rng.choice([12, 13, 14])
    for i in range(n_side):
        t = 0.08 + 0.85 * (i + rng.uniform(0, 0.5)) / n_side
        p, tan = point_on(main, t)
        side = 1 if i % 2 == 0 else -1
        dvec = rot_z(tan, math.radians(rng.uniform(40, 62)) * side)
        L = 0.42 * S * (1.0 - 0.72 * t) * rng.uniform(0.85, 1.1)
        sp = curve_path(p, dvec, L, 5, (0, 0.2, -0.02), rng, 0.02)
        paths.append((sp, 1))
        # Tertiary sprays on the longer laterals.
        if L > 0.08:
            nt = 6 if L > 0.2 else 4
            for j in range(nt):
                t2 = 0.15 + 0.7 * j / nt
                p2, tan2 = point_on(sp, t2)
                s2 = 1 if j % 2 == 0 else -1
                d2 = rot_z(tan2, math.radians(50) * s2)
                sp2 = curve_path(p2, d2, L * 0.35 * (1 - t2 * 0.5), 3, (0, 0, 0), rng, 0.02)
                paths.append((sp2, 2))
    for path, order in paths:
        b.tube(path, [0.0026 * (1.7 if order == 0 else 1.0) * (1 - 0.5 * i / len(path)) for i in range(len(path))], twig_col, 4)
    base_col = (0.17, 0.31, 0.19)          # hemlock: dark glossy green
    for path, order in paths:
        L = sum((path[i + 1] - path[i]).length for i in range(len(path) - 1))
        n = int(L / 0.0032)
        for k in range(n):
            t = k / max(1, n)
            p, tan = point_on(path, t)
            side = 1 if k % 2 == 0 else -1
            # Two-ranked, flat: needles in the spray plane, perpendicular-ish to the twig.
            d = rot_z(tan, math.radians(rng.uniform(62, 88)) * side)
            d.z += rng.uniform(-0.12, 0.12)
            length = rng.uniform(0.014, 0.02) * (0.75 + 0.35 * (1 - abs(t - 0.5)))
            c = jitter_col(rng, base_col, 0.02, 0.15, 0.1)
            tip = tuple(min(1, x * 1.18) for x in c)
            b.needle(p, d, length, 0.0038, srgb(c), srgb(tip), segs=2)
            if rng.random() < 0.3:        # a few short needles lying on top of the twig
                d2 = (tan * 0.7 + Vector((0, 0, 0.3)) + rot_z(tan, 1.57 * side) * 0.3).normalized()
                b.needle(p, d2, length * 0.7, 0.003, srgb(c), srgb(tip), segs=2)


def outline_oak(rng):
    # Red oak: 7-9 bristle-tipped lobes, deep sinuses.
    pts = [(0.0, 0.02)]
    lobes = rng.choice([3, 4])
    for i in range(lobes):
        t0 = 0.12 + 0.72 * i / lobes
        t1 = 0.12 + 0.72 * (i + 1) / lobes
        env = math.sin(math.pi * (0.15 + 0.8 * (t0 + t1) / 2)) * 0.42
        pts.append((t0 + 0.02, 0.08 + 0.03 * rng.random()))                # sinus
        pts.append(((t0 + t1) / 2 - 0.03, env * 0.75))
        pts.append(((t0 + t1) / 2 + 0.02, env * 1.02))                    # lobe tip
        pts.append((t1 - 0.02, env * 0.55))
    pts.append((0.88, 0.1))
    pts.append((0.94, 0.16))
    pts.append((1.0, 0.0))
    return pts


def outline_maple(rng):
    # Sugar maple, palmate: expressed along the midrib as (t, w) is poor; use polar outline.
    return None


def polar_maple(rng, n=90):
    # Sugar maple: 5 broad lobes (3 main + 2 small basal), rounded sinuses, a few teeth.
    lobes = [(90, 1.0, 42), (35, 0.86, 38), (145, 0.86, 38), (-15, 0.5, 30), (195, 0.5, 30)]
    pts = []
    for i in range(n):
        th = -90 + 360.0 * i / n
        r = 0.3
        for (ang, L, wdeg) in lobes:
            d = (th - ang + 540) % 360 - 180
            k = max(0.0, math.cos(math.radians(d) * 90.0 / wdeg)) if abs(d) < wdeg else 0.0
            tooth = 1.0 + 0.06 * max(0.0, math.cos(math.radians(d) * 12))
            r = max(r, (0.3 + (L - 0.3) * k ** 0.7) * tooth)
        if -115 < th < -65:            # petiole notch at the base
            r *= 0.3 + 0.7 * min(1, abs(th + 90) / 25)
        r *= 1 + rng.uniform(-0.03, 0.03)
        pts.append((th, r * 0.62))
    return pts


def outline_birch(rng):
    pts = []
    n = 26
    for i in range(n + 1):
        t = i / n
        w = 0.36 * math.sin(math.pi * min(1, t * 1.05)) ** 0.8 * (1 - 0.35 * t)
        if 0.1 < t < 0.95:
            w *= 1 + (0.08 if i % 2 else -0.04) + (0.05 if i % 4 == 1 else 0)
        pts.append((t, max(w, 0.0)))
    return pts


def outline_hazel(rng):
    pts = []
    n = 30
    for i in range(n + 1):
        t = i / n
        w = 0.5 * math.sin(math.pi * min(1, t * 1.0)) ** 0.6 * (1 - 0.25 * t)
        if t < 0.12:
            w *= 0.6 + 3.0 * t            # cordate base
        if 0.12 < t < 0.95:
            w *= 1 + (0.06 if i % 2 else -0.03)
        pts.append((t, max(w, 0.0)))
    return pts


def leaf_polar(b, base, direction, normal, polar, size, color, fold, rng):
    """Palmate leaf: fan of wedges from the petiole point, folded slightly per lobe."""
    d = Vector(direction).normalized()
    n = Vector(normal)
    n = (n - d * n.dot(d)).normalized()
    s = d.cross(n).normalized()
    centre = Vector(base) + d * size * 0.18
    pts = []
    uvs = []
    for th, r in polar:
        a = math.radians(th)
        # th measured from the midrib direction (90 deg = along d)
        x = math.cos(a) * r
        y = math.sin(a) * r
        p = centre + s * (x * size) + d * (y * size) + n * (fold * size * (abs(x) * 0.25 + 0.08 * (x * x + y * y)))
        pts.append(p)
        uvs.append((x, y))
    c = centre + n * 0.0
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        b.face([c, pts[i], pts[j]], color, [(0.0, 0.0), uvs[i], uvs[j]])


def spray_broadleaf(b, rng, S, kind):
    if kind == 'oak':
        twig_col, base_col, n_side, leaf_len, per_node = srgb((0.36, 0.31, 0.25)), (0.34, 0.42, 0.20), 3, (0.12, 0.17), (4, 7)
    elif kind in ('maple', 'maple_red'):
        twig_col, base_col, n_side, leaf_len, per_node = srgb((0.40, 0.33, 0.25)), (0.34, 0.45, 0.19), 3, (0.10, 0.14), (2, 3)
    elif kind == 'birch':
        twig_col, base_col, n_side, leaf_len, per_node = srgb((0.30, 0.22, 0.18)), (0.46, 0.55, 0.24), 5, (0.055, 0.08), (2, 2)
    else:  # hazel
        twig_col, base_col, n_side, leaf_len, per_node = srgb((0.42, 0.34, 0.26)), (0.36, 0.46, 0.22), 3, (0.08, 0.11), (1, 2)
    paths = twig_system(rng, S, n_side=n_side, side_len=0.5, angle=(30, 55), curve=0.2)
    for path, order in paths:
        b.tube(path, [0.0065 * (1.5 if order == 0 else 1.0) * (1 - 0.5 * i / len(path)) for i in range(len(path))], twig_col, 5)
    for path, order in paths:
        L = sum((path[i + 1] - path[i]).length for i in range(len(path) - 1))
        if kind == 'oak':
            # Oak: leaves clustered at the twig tips (whorl-like clusters).
            nodes = [0.55, 0.8, 1.0] if order == 0 else [0.65, 1.0]
        else:
            step = 0.065 if kind != 'birch' else 0.045
            nodes = [min(1.0, x * step / L) for x in range(1, int(L / step) + 1)]
            nodes = [t for t in nodes if t > 0.12]
        for t in nodes:
            p, tan = point_on(path, t)
            count = rng.randint(*per_node) if kind == 'oak' else rng.randint(*per_node)
            for j in range(count):
                side = 1 if (j + int(t * 97)) % 2 == 0 else -1
                ang = math.radians(rng.uniform(25, 80) if kind != 'oak' else rng.uniform(-70, 70) + (0 if j == 0 else 180 * (j % 2)))
                d = rot_z(tan, ang * (side if kind != 'oak' else 1))
                d.z += rng.uniform(-0.25, 0.25)
                d.normalize()
                petiole = rng.uniform(0.01, 0.03) if kind != 'maple' else rng.uniform(0.03, 0.06)
                lp = p + d * petiole
                b.tube([p, lp], [0.0018, 0.0015], twig_col, 3)
                normal = Vector((rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45), 1.0)).normalized()
                if kind == 'maple_red':
                    c = jitter_col(rng, (0.62, 0.20, 0.10) if rng.random() < 0.65 else (0.55, 0.38, 0.14), 0.03, 0.15, 0.1)
                else:
                    c = jitter_col(rng, base_col, 0.035, 0.16, 0.12)
                    if rng.random() < 0.06:        # a late-summer yellowing / damaged leaf
                        c = jitter_col(rng, (0.52, 0.48, 0.22), 0.03, 0.1, 0.1)
                length = rng.uniform(*leaf_len)
                if kind in ('maple', 'maple_red'):
                    leaf_polar(b, lp, d, normal, polar_maple(rng), length, srgb(c), 0.15, rng)
                else:
                    outline = {'oak': outline_oak, 'birch': outline_birch, 'hazel': outline_hazel}[kind](rng)
                    b.leaf(lp, d, normal, outline, length, srgb(c), fold=0.18, curl=rng.uniform(0.05, 0.2), rng=rng)


def spray_dead(b, rng, S):
    # Dead lower branch of a white pine: grey, brittle, a few brown needles left.
    col = srgb((0.42, 0.39, 0.35))
    paths = twig_system(rng, S, n_side=5, side_len=0.45, angle=(35, 70), curve=0.3)
    for path, order in paths:
        b.tube(path, [0.012 * (1.6 if order == 0 else 1.0) * (1 - 0.6 * i / len(path)) for i in range(len(path))], col, 5)
        for q in range(2):
            t = rng.uniform(0.3, 0.9)
            p, tan = point_on(path, t)
            d = rot_z(tan, rng.uniform(-1.2, 1.2))
            sp = curve_path(p, d, rng.uniform(0.05, 0.14), 3, (0, 0, 0), rng, 0.1)
            b.tube(sp, [0.006, 0.0045, 0.003, 0.002], col, 3)
    brown = (0.46, 0.33, 0.18)
    for path, order in paths:
        for k in range(10):
            if rng.random() < 0.5:
                continue
            p, tan = point_on(path, rng.uniform(0.6, 1.0))
            for j in range(5):
                d = (tan + Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), rng.uniform(-0.3, 0.3)))).normalized()
                c = jitter_col(rng, brown, 0.02, 0.2, 0.1)
                b.needle(p, d, rng.uniform(0.07, 0.11), 0.0022, srgb(c), srgb(c))


def spray_fern(b, rng, S):
    # Bracken / lady-fern style frond seen from above (used by the procedural undergrowth
    # cards if the Poly Haven fern is not used).
    col = (0.36, 0.48, 0.20)
    rachis = curve_path(Vector((0, 0.02 * S, 0)), (0, 1, 0), 0.92 * S, 14, (0.1, 0, -0.1), rng, 0.02)
    b.tube(rachis, [0.004 * (1 - 0.6 * i / len(rachis)) for i in range(len(rachis))], srgb((0.45, 0.42, 0.22)), 4)
    n = 13
    for i in range(n):
        t = 0.08 + 0.9 * i / n
        p, tan = point_on(rachis, t)
        for side in (-1, 1):
            d = rot_z(tan, math.radians(72) * side)
            L = 0.25 * S * math.sin(math.pi * min(1, (t - 0.05) * 1.05)) ** 0.7 + 0.01
            pts = []
            m = 12
            for k in range(m + 1):
                tt = k / m
                w = 0.11 * (1 - tt) + 0.015
                # pinnule lobes
                w *= 0.5 + 0.8 * abs(math.sin(tt * math.pi * 7))
                pts.append((tt, w))
            c = jitter_col(rng, col, 0.02, 0.12, 0.08)
            normal = Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 1))
            b.leaf(p, d, normal, pts, L, srgb(c), fold=0.1, curl=0.15, rng=rng)


def fir_side(tile):
    # Whole fir sapling (Poly Haven fir_sapling "c", 0.74 m) rendered from the side as a sapling
    # card; its own diffuse textures, local AO.
    objs = import_gltf(os.path.join(POLYHAVEN, 'models', 'fir_sapling', 'fir_sapling_2k.gltf'))
    tw = emission_image_material('fir_tw', os.path.join(POLYHAVEN, 'models/fir_sapling/textures/fir_sapling_twigs_diff_2k.jpg'), ao_distance=0.03)
    br = emission_image_material('fir_br', os.path.join(POLYHAVEN, 'models/fir_sapling/textures/fir_sapling_branches_diff_2k.jpg'))
    keep = None
    for o in objs:
        if o.type != 'MESH':
            continue
        if o.name.endswith('_a'):
            keep = o
        else:
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        for i, m in enumerate(o.data.materials):
            o.data.materials[i] = tw if 'twig' in m.name else br
    # Stand it in the tile frame: base at the tile's bottom centre, up = +Y, seen from -Z.
    keep.location = (0, 0, 0)
    keep.rotation_mode = 'XYZ'          # the glTF importer leaves objects in quaternion mode
    keep.rotation_euler = (math.radians(-90), 0, 0)
    keep.scale = (1.0, 1.0, 1.0)
    bpy.context.view_layer.update()
    return [keep]


def shrub04_tile(tile):
    # Poly Haven shrub_04 sprig (recovered alpha, make_textures.py) seen from above, base at the
    # bottom of the tile, growing up the image.
    objs = import_gltf(os.path.join(POLYHAVEN, 'models', 'shrub_04', 'shrub_04_2k.gltf'))
    mat = bpy.data.materials.new('shrub04')
    nt, out = _nodes(mat)
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(os.path.join(ENV, 'props', 'shrub_04', 'shrub_04_albedo_1k.png'))
    tex.image.alpha_mode = 'STRAIGHT'
    ao = nt.nodes.new('ShaderNodeAmbientOcclusion')
    ao.only_local = True
    ao.samples = 16
    ao.inputs['Distance'].default_value = 0.02
    nt.links.new(tex.outputs['Color'], ao.inputs['Color'])
    em = nt.nodes.new('ShaderNodeEmission')
    nt.links.new(ao.outputs['Color'], em.inputs['Color'])
    tr = nt.nodes.new('ShaderNodeBsdfTransparent')
    gt = nt.nodes.new('ShaderNodeMath')
    gt.operation = 'GREATER_THAN'
    gt.inputs[1].default_value = 0.5
    nt.links.new(tex.outputs['Alpha'], gt.inputs[0])
    mix = nt.nodes.new('ShaderNodeMixShader')
    nt.links.new(gt.outputs[0], mix.inputs['Fac'])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs['Surface'])
    keep = []
    for o in objs:
        if o.type != 'MESH':
            continue
        o.data.materials.clear()
        o.data.materials.append(mat)
        o.location = (0, 0, 0)
        o.rotation_mode = 'XYZ'
        o.rotation_euler = (0, 0, math.radians(-90))
        o.scale = (1.0, 1.0, 1.0)
        keep.append(o)
    bpy.context.view_layer.update()
    # Shift so the sprig's base (its +X end before the rotation) sits at the tile's bottom centre.
    ys = [(o.matrix_world @ Vector(c)).y for o in keep for c in o.bound_box]
    for o in keep:
        o.location.y -= min(ys) - 0.01
    return keep


def build_tile(name, t):
    rng = random.Random(t['seed'])
    S = t['size']
    kind = t['kind']
    if kind == 'fir_side':
        return fir_side(t), None
    if kind == 'shrub04':
        return shrub04_tile(t), None
    b = Builder(name)
    if kind == 'pine':
        spray_pine(b, rng, S, 0 if name.endswith('_a') else 1)
    elif kind == 'hemlock':
        spray_hemlock(b, rng, S)
    elif kind in ('oak', 'maple', 'maple_red', 'birch', 'hazel'):
        spray_broadleaf(b, rng, S, kind)
    elif kind == 'dead':
        spray_dead(b, rng, S)
    elif kind == 'fern':
        spray_fern(b, rng, S)
    ob = b.build()
    return [ob], kind


def leaf_detail(nt, col):
    """Veins and slight mottling on leaves using the leaf-local UV (x across, y along)."""
    uvn = nt.nodes.new('ShaderNodeUVMap')
    uvn.uv_map = 'leafuv'
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(uvn.outputs['UV'], sep.inputs[0])
    ax = nt.nodes.new('ShaderNodeMath'); ax.operation = 'ABSOLUTE'
    nt.links.new(sep.outputs['X'], ax.inputs[0])
    # midrib: 1 near x = 0 (only on blades: y > 0)
    mid = nt.nodes.new('ShaderNodeMapRange')
    mid.inputs['From Min'].default_value = 0.0
    mid.inputs['From Max'].default_value = 0.05
    mid.inputs['To Min'].default_value = 1.0
    mid.inputs['To Max'].default_value = 0.0
    nt.links.new(ax.outputs[0], mid.inputs['Value'])
    # lateral veins: fract(y*9 - |x|*3) thin lines
    lat = nt.nodes.new('ShaderNodeMath'); lat.operation = 'MULTIPLY_ADD'
    nt.links.new(sep.outputs['Y'], lat.inputs[0]); lat.inputs[1].default_value = 9.0
    neg = nt.nodes.new('ShaderNodeMath'); neg.operation = 'MULTIPLY'
    nt.links.new(ax.outputs[0], neg.inputs[0]); neg.inputs[1].default_value = -3.0
    nt.links.new(neg.outputs[0], lat.inputs[2])
    fr = nt.nodes.new('ShaderNodeMath'); fr.operation = 'FRACT'
    nt.links.new(lat.outputs[0], fr.inputs[0])
    ln = nt.nodes.new('ShaderNodeMapRange')
    ln.inputs['From Min'].default_value = 0.0
    ln.inputs['From Max'].default_value = 0.12
    ln.inputs['To Min'].default_value = 1.0
    ln.inputs['To Max'].default_value = 0.0
    nt.links.new(fr.outputs[0], ln.inputs['Value'])
    veins = nt.nodes.new('ShaderNodeMath'); veins.operation = 'MAXIMUM'
    nt.links.new(mid.outputs[0], veins.inputs[0])
    lw = nt.nodes.new('ShaderNodeMath'); lw.operation = 'MULTIPLY'
    nt.links.new(ln.outputs[0], lw.inputs[0]); lw.inputs[1].default_value = 0.5
    nt.links.new(lw.outputs[0], veins.inputs[1])
    # Only on blades (uv.y > 0.001): twigs and needles have uv (0,0).
    isb = nt.nodes.new('ShaderNodeMath'); isb.operation = 'GREATER_THAN'
    nt.links.new(sep.outputs['Y'], isb.inputs[0]); isb.inputs[1].default_value = 0.001
    vm = nt.nodes.new('ShaderNodeMath'); vm.operation = 'MULTIPLY'
    nt.links.new(veins.outputs[0], vm.inputs[0]); nt.links.new(isb.outputs[0], vm.inputs[1])
    # Veins: lighter, yellower.
    mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'SCREEN'
    fac = nt.nodes.new('ShaderNodeMath'); fac.operation = 'MULTIPLY'
    nt.links.new(vm.outputs[0], fac.inputs[0]); fac.inputs[1].default_value = 0.22
    nt.links.new(fac.outputs[0], mix.inputs['Factor'])
    nt.links.new(col, mix.inputs['A'])
    mix.inputs['B'].default_value = (0.55, 0.55, 0.2, 1)
    # Mottling: noise darkens / lightens a little.
    noise = nt.nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 180.0
    nt.links.new
    mr = nt.nodes.new('ShaderNodeMapRange')
    mr.inputs['To Min'].default_value = 0.88
    mr.inputs['To Max'].default_value = 1.08
    nt.links.new(noise.outputs['Fac'], mr.inputs['Value'])
    mul = nt.nodes.new('ShaderNodeMix'); mul.data_type = 'RGBA'; mul.blend_type = 'MULTIPLY'
    mul.inputs['Factor'].default_value = 1.0
    nt.links.new(mix.outputs['Result'], mul.inputs['A'])
    comb = nt.nodes.new('ShaderNodeCombineColor')
    for i in range(3):
        nt.links.new(mr.outputs['Result'], comb.inputs[i])
    nt.links.new(comb.outputs['Color'], mul.inputs['B'])
    return mul.outputs['Result']


def render_tile(name, t):
    reset()
    objs, kind = build_tile(name, t)
    S = t['size']
    if kind is not None:
        mat = emission_attr_material('alb_' + name, 'leafcol', ao_distance={'pine': 0.02, 'hemlock': 0.01, 'dead': 0.02}.get(kind, 0.04),
                                     detail=leaf_detail if kind not in ('pine', 'hemlock', 'dead') else None)
        for o in objs:
            set_material(o, mat)
    setup_render(RES, RES, SAMPLES, raw=False)
    ortho_camera((0, S * 0.5, 0), S, S, direction=(0, 0, -1), up=(0, 1, 0))
    render_to(os.path.join(WORK, name + '_albedo.png'))
    if t['kind'] == 'shrub04':
        nm = normal_material('NormalAlpha', alpha_image=os.path.join(ENV, 'props', 'shrub_04', 'shrub_04_albedo_1k.png'))
        for o in objs:
            set_material(o, nm)
    else:
        nm = normal_material()
        bpy.context.view_layer.material_override = nm
    setup_render(RES, RES, SAMPLES, raw=True)
    render_to(os.path.join(WORK, name + '_normal.png'))
    bpy.context.view_layer.material_override = None


if __name__ == '__main__':
    os.makedirs(WORK, exist_ok=True)
    for name, t in TILES.items():
        if ONLY and name not in ONLY:
            continue
        render_tile(name, t)
        print('TILE DONE', name)
    meta = {k: dict(index=v['index'], size=v['size'], kind=v['kind']) for k, v in TILES.items()}
    with open(os.path.join(WORK, 'tiles.json'), 'w') as f:
        json.dump(meta, f, indent=1)
    print('ATLAS TILES DONE')
