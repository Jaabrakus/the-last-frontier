# Tree generator (package C). Blender 5.2, background:
#
#   Blender -b --factory-startup -P tools/environment/vegetation/build_trees.py -- \
#       [only=white_pine,hemlock,...] [preview=<png>] [export=1]
#
# Builds every species in SPECIES as 3 variants x 3 LODs (+ two shadow proxies for the canopy
# trees, only ever rendered into shadow maps: LOD3 = trunk and ~50 big alpha cards for near shadows,
# LOD4 = an opaque convex crown blob of ~60 triangles for far shadows) from a procedural skeleton:
# swept bark tubes (bark UVs tile around and along) plus alpha cards for the foliage, whose UVs
# point into the foliage atlas (assets/environment/vegetation/foliage/foliage_tiles.json).
# One mesh per variant and LOD, one surface: the Godot tree shader tells bark from foliage by
# COLOR.a. Per vertex:
#   COLOR  r = baked ambient occlusion (crown depth / under-crown trunk), g = outer-crown factor,
#          b = per-card / per-branch random, a = 1 foliage, 0 bark
#   UV     bark: (around * repeats, along / 1.5 m); foliage: atlas tile rect
#   UV2    x = metres from the limb's attachment on the trunk (branch wind), y = limb phase 0..1
#   NORMAL bark: radial; foliage: card normal bent toward the crown's ellipsoid normal (the
#          crown shades as a volume instead of as flat cards)
# Output: assets/environment/vegetation/trees/<species>.glb with objects <species>_v<k>_lod<n>
# (Blender Z-up is exported as Godot's Y-up; the tree base is at the origin, 0.6 m of trunk
# below it so trees can stand on slopes). The triangle counts are printed and checked against
# the budgets in the look-dev spec (section 7.1).
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bcommon import *

A = args()
ONLY = A.get('only', '').split(',') if A.get('only') else []
OUT_DIR = os.path.join(ENV, 'vegetation', 'trees')
TILES = json.load(open(os.path.join(ENV, 'vegetation', 'foliage', 'foliage_tiles.json')))['tiles']
UP = Vector((0, 0, 1))


# --- skeleton -------------------------------------------------------------------------------------

class Branch:
    __slots__ = ('pts', 'radii', 'level', 'attach', 'phase', 'rand', 'dead')

    def __init__(self, pts, radii, level, attach=0.0, phase=0.0, rand=0.5, dead=False):
        self.pts = pts
        self.radii = radii
        self.level = level
        self.attach = attach        # metres from the limb's attachment at the start of this branch
        self.phase = phase
        self.rand = rand
        self.dead = dead

    def length(self):
        return sum((self.pts[i + 1] - self.pts[i]).length for i in range(len(self.pts) - 1))

    def at(self, t):
        """Point, tangent, radius and distance-from-start at fraction t of the length."""
        segs = [(self.pts[i + 1] - self.pts[i]).length for i in range(len(self.pts) - 1)]
        total = sum(segs)
        target = t * total
        acc = 0.0
        for i, L in enumerate(segs):
            if acc + L >= target or i == len(segs) - 1:
                f = min(max((target - acc) / max(L, 1e-9), 0.0), 1.0)
                p = self.pts[i].lerp(self.pts[i + 1], f)
                r = self.radii[i] * (1 - f) + self.radii[i + 1] * f
                return p, (self.pts[i + 1] - self.pts[i]).normalized(), r, target
            acc += L
        return self.pts[-1], (self.pts[-1] - self.pts[-2]).normalized(), self.radii[-1], total


class Site:
    """A foliage card: base position, growth direction (card up), face normal, tile, size."""
    __slots__ = ('p', 'd', 'n', 'tile', 'size', 'attach', 'phase', 'rand')

    def __init__(self, p, d, n, tile, size, attach, phase, rand):
        self.p, self.d, self.n, self.tile, self.size = p, d, n, tile, size
        self.attach, self.phase, self.rand = attach, phase, rand


def perp(v):
    a = UP if abs(v.z) < 0.95 else Vector((1, 0, 0))
    return v.cross(a).normalized()


def rotate(v, axis, ang):
    return (Matrix.Rotation(ang, 3, axis) @ v)


def grow(start, direction, length, r0, r1, steps, rng, gravity=0.0, up=0.0, wobble=0.05, droop_tip=0.0,
         twist_axis=None):
    """Polyline from start along direction; gravity bends down (+ up bends up) progressively;
    droop_tip bends the last third down."""
    pts = [Vector(start)]
    d = Vector(direction).normalized()
    radii = [r0]
    seg = length / steps
    for i in range(steps):
        f = (i + 1) / steps
        bend = Vector((0, 0, up - gravity)) * (1.0 / steps) * 2.0
        if droop_tip and f > 0.6:
            bend += Vector((0, 0, -droop_tip)) * (1.0 / steps) * 3.0
        d = (d + bend + Vector((rng.uniform(-wobble, wobble), rng.uniform(-wobble, wobble), rng.uniform(-wobble, wobble) * 0.6))).normalized()
        pts.append(pts[-1] + d * seg)
        radii.append(r0 + (r1 - r0) * f ** 0.9)
    return pts, radii


class Tree:
    def __init__(self, name, rng):
        self.name = name
        self.rng = rng
        self.branches = []
        self.sites = []
        self.bark = 'hardwood'


def trunk(tree, height, r_base, steps, lean=0.0, wobble=0.012, top_droop=0.0, base=(0, 0, 0), direction=None):
    rng = tree.rng
    d0 = direction if direction is not None else Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0)).normalized() * lean + UP
    pts, radii = [Vector(base) + Vector((0, 0, -0.6))], [r_base * 1.25]
    d = Vector(d0).normalized()
    seg = height / steps
    p = Vector(base)
    pts.append(p.copy())
    radii.append(r_base * 1.25)
    for i in range(steps):
        f = (i + 1) / steps
        if top_droop and f > 0.85:
            d = (d + Vector((top_droop, 0, 0)) * 0.5).normalized()
        d = (d + Vector((rng.uniform(-wobble, wobble), rng.uniform(-wobble, wobble), 0))).normalized()
        p = p + d * seg
        pts.append(p.copy())
        # Root flare in the first metre, then a slow taper.
        z = f * height
        flare = 1.0 + 0.3 * max(0.0, 1.0 - z / 1.0) ** 2
        radii.append(max(r_base * (1.0 - 0.92 * f ** 1.1) * flare, 0.015))
    radii[1] = r_base * 1.3
    b = Branch(pts, radii, 0, 0.0, rng.random(), rng.random())
    tree.branches.append(b)
    return b


def add_sites_along(tree, br, tile, size, t0, spacing, orient, rng, jitter=0.25, size_var=0.2, count_scale=1.0):
    """Foliage cards along branch br from fraction t0 to the tip."""
    L = br.length()
    n = max(1, int(L * (1 - t0) / spacing * count_scale))
    for i in range(n):
        t = t0 + (1 - t0) * (i + rng.uniform(0.2, 0.8)) / n
        p, tan, r, dist = br.at(min(t, 1.0))
        if p.z < 0.35:              # drooping low branches: no cards in the ground
            continue
        d, nrm = orient(p, tan, t, rng)
        if (p + d * size).z < 0.1:
            d = (d + UP * 0.6).normalized()
            nrm = (nrm - d * nrm.dot(d)).normalized()
        s = size * rng.uniform(1 - size_var, 1 + size_var)
        tree.sites.append(Site(p - d * 0.06 * s, d, nrm, tile, s, br.attach + dist, br.phase, rng.random()))


def tip_cluster(tree, br, tiles, size, rng, count=3):
    """A rosette of cards around a branch tip, rolled to different angles, so the tuft has
    volume from every side."""
    p, tan, r, dist = br.at(0.92)
    if p.z < 0.5:
        return
    d0 = Vector((tan.x, tan.y, tan.z * 0.5)).normalized()
    for k in range(count):
        roll = math.radians(-60 + 120 * (k + rng.uniform(0.2, 0.8)) / count)
        side = d0.cross(UP)
        side = side.normalized() if side.length > 1e-4 else perp(d0)
        n = side.cross(d0).normalized()
        if n.z < 0:
            n = -n
        d = rotate(d0, UP, math.radians(rng.uniform(-30, 30)))
        n = rotate(rotate(n, d0, roll), UP, 0)
        n = (n - d * n.dot(d)).normalized()
        s = size * rng.uniform(0.85, 1.1)
        tree.sites.append(Site(p - d * 0.45 * s, d, n, rng.choice(tiles), s, br.attach + dist, br.phase, rng.random()))


def horizontal_card(p, tan, t, rng, droop=0.25, roll_max=55, flat_share=0.4):
    """Conifer spray: grows along the branch (slightly out and down), face mostly up."""
    d = Vector((tan.x, tan.y, tan.z * 0.5 - droop * t)).normalized()
    side = d.cross(UP)
    if side.length < 1e-4:
        side = perp(d)
    side.normalize()
    n = side.cross(d).normalized()          # face normal, roughly up
    if n.z < 0:
        n = -n
    roll = 0.0 if rng.random() < flat_share else math.radians(rng.uniform(20, roll_max)) * (1 if rng.random() < 0.5 else -1)
    n = rotate(n, d, roll)
    yaw = math.radians(rng.uniform(-25, 25))
    d = rotate(d, UP, yaw)
    n = rotate(n, UP, yaw)
    return d, n


def outward_card(center):
    def f(p, tan, t, rng):
        out = (p - center)
        out.z *= 0.6
        out = out.normalized() if out.length > 1e-3 else UP.copy()
        d = (tan * 0.6 + out * 0.4 + Vector((0, 0, rng.uniform(-0.2, 0.3)))).normalized()
        n = out - d * out.dot(d)
        if n.length < 1e-3:
            n = perp(d)
        n.normalize()
        n = rotate(n, d, math.radians(rng.uniform(-45, 45)))
        n = (n + UP * 0.35).normalized()
        n = (n - d * n.dot(d)).normalized()
        return d, n
    return f


# --- species ------------------------------------------------------------------------------------

def white_pine(tree, v):
    rng = tree.rng
    tree.bark = 'conifer'
    H = rng.uniform(21, 24)
    tr = trunk(tree, H, rng.uniform(0.3, 0.36), 16, lean=0.03, wobble=0.01)
    crown_base = H * (0.42 if v != 2 else 0.25)       # variant 2: edge tree, lower crown
    z = crown_base
    whorl = 0
    while z < H - 0.6:
        rel = (z - crown_base) / (H - crown_base)
        k = rng.choice([3, 4, 4, 5])
        rot0 = rng.uniform(0, 2 * math.pi)
        for j in range(k):
            if rng.random() < 0.22 + 0.25 * (1 - rel):   # irregular: many whorls incomplete
                continue
            az = rot0 + j * 2 * math.pi / k + rng.uniform(-0.3, 0.3)
            p, tan, r_t, _ = tr.at(z / H)
            L = (1.2 + 5.0 * (1 - rel) ** 0.75) * rng.uniform(0.7, 1.15)
            if rel > 0.85:
                L *= 0.6
            # Flagging: longer branches toward the east (+x) near the top.
            if rel > 0.55:
                L *= 1.0 + 0.35 * max(0.0, math.cos(az))
            dirv = Vector((math.cos(az), math.sin(az), math.tan(math.radians(rng.uniform(-8, 14)))))
            pts, radii = grow(p, dirv, L, min(r_t * 0.55, 0.11), 0.012, 6, rng, gravity=0.12, up=0.18, wobble=0.07)
            b = Branch(pts, radii, 1, 0.0, rng.random(), rng.random())
            tree.branches.append(b)
            # Secondary: flat sprays alternating left and right in the horizontal plane.
            nsub = int(L / 0.34)
            for s in range(nsub):
                t = 0.18 + 0.78 * (s + rng.uniform(0, 0.6)) / max(nsub, 1)
                p2, tan2, r2, dist = b.at(t)
                side = 1 if s % 2 == 0 else -1
                d2 = rotate(tan2, UP, math.radians(rng.uniform(40, 70)) * side)
                d2.z = rng.uniform(-0.05, 0.15)
                L2 = (L * (1 - t) * 0.5 + 0.45) * rng.uniform(0.75, 1.1)
                pts2, radii2 = grow(p2, d2, L2, max(r2 * 0.5, 0.008), 0.005, 3, rng, gravity=0.05, up=0.1, wobble=0.08)
                b2 = Branch(pts2, radii2, 2, dist, b.phase, rng.random())
                tree.branches.append(b2)
                add_sites_along(tree, b2, 'pine_a' if rng.random() < 0.5 else 'pine_b', 1.3, 0.05, 0.26,
                                lambda p_, t_, u_, r_: horizontal_card(p_, t_, u_, r_, 0.12, 70, 0.25), rng)
                tip_cluster(tree, b2, ['pine_a', 'pine_b'], 1.3, rng, 2)
            add_sites_along(tree, b, 'pine_b', 1.3, 0.35, 0.3,
                            lambda p_, t_, u_, r_: horizontal_card(p_, t_, u_, r_, 0.1, 65, 0.25), rng)
            tip_cluster(tree, b, ['pine_a', 'pine_b'], 1.4, rng, 3)
        whorl += 1
        z += rng.uniform(0.75, 1.15) * (0.85 if rel > 0.7 else 1.0)
    # Leader tuft.
    p, tan, r, _ = tr.at(1.0)
    for j in range(4):
        d = (UP * 1.0 + Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0))).normalized()
        tree.sites.append(Site(p - d * 0.4, d, perp(d), 'pine_a', 1.1, 0.0, tr.phase, rng.random()))
    # Dead stubs below the live crown (self-pruned lower branches).
    for i in range(rng.randint(6, 10)):
        z = rng.uniform(H * 0.14, crown_base)
        p, tan, r_t, _ = tr.at(z / H)
        az = rng.uniform(0, 2 * math.pi)
        dirv = Vector((math.cos(az), math.sin(az), rng.uniform(-0.15, 0.05)))
        L = rng.uniform(0.6, 1.8)
        pts, radii = grow(p, dirv, L, 0.035, 0.008, 3, rng, gravity=0.1, wobble=0.12)
        b = Branch(pts, radii, 1, 0.0, rng.random(), rng.random(), dead=True)
        tree.branches.append(b)
        if rng.random() < 0.6:
            add_sites_along(tree, b, 'deadtwig', 1.0, 0.3, 0.8,
                            lambda p_, t_, u_, r_: horizontal_card(p_, t_, u_, r_, 0.1, 70, 0.2), rng)


def hemlock(tree, v):
    rng = tree.rng
    tree.bark = 'conifer'
    H = rng.uniform(16, 19)
    tr = trunk(tree, H, rng.uniform(0.26, 0.32), 14, lean=0.02, wobble=0.012, top_droop=0.25)
    crown_base = H * (0.28 if v != 2 else 0.06)       # variant 2: edge tree, branches to the ground
    z = crown_base
    while z < H - 0.35:
        rel = (z - crown_base) / (H - crown_base)
        for j in range(rng.choice([2, 2, 3])):
            az = rng.uniform(0, 2 * math.pi)
            p, tan, r_t, _ = tr.at(z / H)
            L = (0.5 + 4.2 * (1 - rel) ** 0.95) * rng.uniform(0.8, 1.1)
            dirv = Vector((math.cos(az), math.sin(az), math.tan(math.radians(rng.uniform(-22, -5)))))
            pts, radii = grow(p, dirv, L, min(r_t * 0.45, 0.08), 0.008, 5, rng, gravity=0.1, wobble=0.05, droop_tip=0.35)
            b = Branch(pts, radii, 1, 0.0, rng.random(), rng.random())
            tree.branches.append(b)
            nsub = int(L / 0.3)
            for s in range(nsub):
                t = 0.15 + 0.8 * (s + rng.uniform(0, 0.5)) / max(nsub, 1)
                p2, tan2, r2, dist = b.at(t)
                side = 1 if s % 2 == 0 else -1
                d2 = rotate(tan2, UP, math.radians(rng.uniform(45, 65)) * side)
                d2.z -= 0.15
                L2 = (L * (1 - t) * 0.5 + 0.2) * rng.uniform(0.75, 1.1)
                pts2, radii2 = grow(p2, d2, L2, max(r2 * 0.5, 0.006), 0.004, 3, rng, gravity=0.12, wobble=0.06, droop_tip=0.3)
                b2 = Branch(pts2, radii2, 2, dist, b.phase, rng.random())
                tree.branches.append(b2)
                add_sites_along(tree, b2, 'hemlock_a' if rng.random() < 0.5 else 'hemlock_b', 1.0, 0.05, 0.24,
                                lambda p_, t_, u_, r_: horizontal_card(p_, t_, u_, r_, 0.35, 60, 0.35), rng, size_var=0.15)
                if rng.random() < 0.5:
                    tip_cluster(tree, b2, ['hemlock_a', 'hemlock_b'], 1.0, rng, 2)
            add_sites_along(tree, b, 'hemlock_a', 1.0, 0.35, 0.3,
                            lambda p_, t_, u_, r_: horizontal_card(p_, t_, u_, r_, 0.4, 55, 0.4), rng)
            tip_cluster(tree, b, ['hemlock_a', 'hemlock_b'], 1.05, rng, 3)
        z += rng.uniform(0.32, 0.5)
    p, tan, r, _ = tr.at(1.0)
    for j in range(3):
        d = (tan + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), -0.2))).normalized()
        tree.sites.append(Site(p - d * 0.3, d, perp(d), 'hemlock_b', 0.8, 0.0, tr.phase, rng.random()))


def broadleaf(tree, v, kind):
    """Oak / maple: trunk to a fork, a leader plus 3-5 spreading limbs, two more branch orders and
    leaf-spray clusters along the twigs that fill a dome (oak) or an oval (maple) crown."""
    rng = tree.rng
    tree.bark = 'hardwood'
    if kind == 'oak':
        H = rng.uniform(18.5, 21.5)
        fork = H * rng.uniform(0.3, 0.38)
        n_limbs = rng.choice([3, 4, 4])
        limb_ang = (38, 62)
        limb_len = (0.62, 0.8)
        tiles = ['oak_a', 'oak_b']
        tile_size = 1.2
        r0 = rng.uniform(0.34, 0.4)
        wob = 0.11
        twig_sp = 0.3
    else:
        H = rng.uniform(16.5, 19.5)
        fork = H * rng.uniform(0.26, 0.32)
        n_limbs = rng.choice([3, 3, 4])
        limb_ang = (22, 40)
        limb_len = (0.7, 0.85)
        tiles = ['maple_a', 'maple_b']
        tile_size = 1.15
        r0 = rng.uniform(0.28, 0.33)
        wob = 0.07
        twig_sp = 0.28
    tr = trunk(tree, fork + 1.0, r0, 7, lean=0.03, wobble=0.02)
    tr.radii = [max(r, r0 * 0.6) for r in tr.radii]
    crown_c = Vector((0, 0, fork + (H - fork) * 0.55))
    limbs = []
    rot0 = rng.uniform(0, 2 * math.pi)
    # Leader.
    pts, radii = grow(Vector((0, 0, fork + 0.6)), Vector((rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), 1)),
                      (H - fork) * 0.82, r0 * 0.55, 0.03, 7, rng, up=0.05, wobble=wob * 0.7)
    lead = Branch(pts, radii, 1, 0.0, rng.random(), rng.random())
    tree.branches.append(lead)
    limbs.append(lead)
    for j in range(n_limbs):
        az = rot0 + j * 2 * math.pi / n_limbs + rng.uniform(-0.35, 0.35)
        el = math.radians(90 - rng.uniform(*limb_ang))
        dirv = Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))
        L = (H - fork) * rng.uniform(*limb_len)
        start = Vector((0, 0, fork + rng.uniform(-0.4, 0.8)))
        pts, radii = grow(start, dirv, L, r0 * rng.uniform(0.48, 0.58), 0.03, 7, rng,
                          gravity=0.06 if kind == 'oak' else 0.0, up=0.1, wobble=wob)
        b = Branch(pts, radii, 1, 0.0, rng.random(), rng.random())
        tree.branches.append(b)
        limbs.append(b)
    if kind == 'oak':
        for j in range(rng.randint(1, 2)):
            az = rng.uniform(0, 2 * math.pi)
            z = fork * rng.uniform(0.78, 0.95)
            dirv = Vector((math.cos(az), math.sin(az), 0.4)).normalized()
            pts, radii = grow(Vector((0, 0, z)), dirv, (H - fork) * 0.6, r0 * 0.34, 0.025, 6, rng, gravity=0.1, up=0.1, wobble=0.1)
            b = Branch(pts, radii, 1, 0.0, rng.random(), rng.random())
            tree.branches.append(b)
            limbs.append(b)
    orient = outward_card(crown_c)
    for b in limbs:
        L = b.length()
        nsub = int(L / 0.75) + 2
        for s_ in range(nsub):
            t = 0.18 + 0.8 * (s_ + rng.uniform(0, 0.6)) / nsub
            p2, tan2, r2, dist = b.at(t)
            out = p2 - crown_c
            out.z *= 0.3
            out = out.normalized() if out.length > 1e-3 else perp(tan2)
            side = rotate(perp(tan2), tan2, rng.uniform(0, 2 * math.pi))
            d2 = (tan2 * 0.45 + side * 0.6 + out * 0.45).normalized()
            d2.z += 0.12 if kind == 'maple' else 0.02
            L2 = (L * (1 - t) * 0.55 + 1.6) * rng.uniform(0.75, 1.1)
            pts2, radii2 = grow(p2, d2, L2, max(r2 * 0.55, 0.02), 0.012, 4, rng, gravity=0.07, up=0.08, wobble=0.12)
            b2 = Branch(pts2, radii2, 2, dist, b.phase, rng.random())
            tree.branches.append(b2)
            n3 = max(2, int(L2 / 0.38))
            for q in range(n3):
                t3 = 0.2 + 0.78 * (q + rng.uniform(0, 0.7)) / n3
                p3, tan3, r3, dist3 = b2.at(t3)
                side3 = rotate(perp(tan3), tan3, rng.uniform(0, 2 * math.pi))
                d3 = (tan3 * 0.5 + side3 * 0.65).normalized()
                d3.z += 0.1
                L3 = rng.uniform(0.6, 1.2) * (1 - 0.35 * t3)
                pts3, radii3 = grow(p3, d3, L3, max(r3 * 0.5, 0.008), 0.005, 2, rng, gravity=0.1, wobble=0.15)
                b3 = Branch(pts3, radii3, 3, dist + dist3, b.phase, rng.random())
                tree.branches.append(b3)
                add_sites_along(tree, b3, rng.choice(tiles), tile_size, 0.0, twig_sp, orient, rng)
                if rng.random() < 0.6:
                    tip_cluster(tree, b3, tiles, tile_size, rng, 2)
            add_sites_along(tree, b2, rng.choice(tiles), tile_size, 0.55, 0.4, orient, rng)
        add_sites_along(tree, b, rng.choice(tiles), tile_size, 0.8, 0.5, orient, rng)


def birch(tree, v):
    rng = tree.rng
    tree.bark = 'birch'
    H = rng.uniform(12, 14.5)
    stems = [1, 3, 2][v % 3]
    crown_c = Vector((0, 0, H * 0.66))
    for sidx in range(stems):
        az = rng.uniform(0, 2 * math.pi) + sidx * 2 * math.pi / stems
        lean = 0.0 if stems == 1 else rng.uniform(0.07, 0.16)
        base = Vector((math.cos(az), math.sin(az), 0)) * (0.0 if stems == 1 else 0.14)
        dirv = (UP + Vector((math.cos(az), math.sin(az), 0)) * lean).normalized()
        h = H * (1.0 if sidx == 0 else rng.uniform(0.78, 0.92))
        tr = trunk(tree, h, rng.uniform(0.11, 0.14) if stems > 1 else rng.uniform(0.15, 0.19), 12, wobble=0.02,
                   base=base, direction=dirv)
        z0 = h * 0.34
        z = z0
        while z < h - 0.3:
            rel = (z - z0) / (h - z0)
            p, tan, r_t, _ = tr.at(z / h)
            az2 = rng.uniform(0, 2 * math.pi)
            el = math.radians(rng.uniform(30, 55))
            d = Vector((math.cos(az2) * math.cos(el), math.sin(az2) * math.cos(el), math.sin(el)))
            L = (1.0 + 3.4 * math.sin(math.pi * min(1.0, 0.2 + rel * 0.9)) ** 0.8) * rng.uniform(0.75, 1.1) * (0.8 if stems > 1 else 1.0)
            pts, radii = grow(p, d, L, min(r_t * 0.5, 0.05), 0.006, 5, rng, gravity=0.22, up=0.05, wobble=0.08, droop_tip=0.4)
            b = Branch(pts, radii, 1, 0.0, rng.random(), rng.random())
            tree.branches.append(b)
            nt = int(L / 0.3) + 1
            for q in range(nt):
                t2 = 0.25 + 0.72 * (q + rng.uniform(0, 0.6)) / nt
                p2, tan2, r2, dist = b.at(t2)
                side = rotate(perp(tan2), tan2, rng.uniform(0, 2 * math.pi))
                d2 = (tan2 * 0.4 + side * 0.6 + Vector((0, 0, -0.3))).normalized()
                pts2, radii2 = grow(p2, d2, rng.uniform(0.6, 1.2), 0.006, 0.003, 3, rng, gravity=0.35, wobble=0.1)
                b2 = Branch(pts2, radii2, 2, dist, b.phase, rng.random())
                tree.branches.append(b2)
                add_sites_along(tree, b2, rng.choice(['birch_a', 'birch_b']), 0.85, 0.0, 0.24, outward_card(crown_c), rng)
            add_sites_along(tree, b, rng.choice(['birch_a', 'birch_b']), 0.85, 0.45, 0.3, outward_card(crown_c), rng)
            z += rng.uniform(0.3, 0.5)
        p, tan, r, _ = tr.at(1.0)
        for j in range(3):
            d = (tan + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 0))).normalized()
            tree.sites.append(Site(p - d * 0.3, d, perp(d), 'birch_a', 0.85, 0.0, tr.phase, rng.random()))


def sapling(tree, v, kind):
    """Young regrowth 2-4.5 m: a simplified tree of the given species."""
    rng = tree.rng
    if kind in ('pine', 'hemlock'):
        tree.bark = 'conifer'
        H = rng.uniform(2.6, 3.6) if kind == 'pine' else rng.uniform(2.0, 2.8)
        tr = trunk(tree, H, 0.045, 6, lean=0.04, wobble=0.03)
        z = 0.25
        tiles = ['pine_a', 'pine_b'] if kind == 'pine' else ['hemlock_a', 'hemlock_b']
        size = 1.0 if kind == 'pine' else 0.8
        droop = 0.1 if kind == 'pine' else 0.3
        while z < H - 0.2:
            rel = z / H
            for j in range(rng.choice([3, 4]) if kind == 'pine' else rng.choice([2, 3])):
                az = rng.uniform(0, 2 * math.pi)
                p, tan, r_t, _ = tr.at(rel)
                L = (0.3 + 1.1 * (1 - rel)) * rng.uniform(0.8, 1.1)
                dirv = Vector((math.cos(az), math.sin(az), 0.25 if kind == 'pine' else -0.1))
                pts, radii = grow(p, dirv, L, 0.015, 0.004, 3, rng, gravity=0.05, up=0.1)
                b = Branch(pts, radii, 1, 0.0, rng.random(), rng.random())
                tree.branches.append(b)
                add_sites_along(tree, b, rng.choice(tiles), size * 0.75, 0.0, 0.14,
                                lambda p_, t_, u_, r_: horizontal_card(p_, t_, u_, r_, droop, 65, 0.3), rng)
                tip_cluster(tree, b, tiles, size * 0.75, rng, 2)
            z += rng.uniform(0.35, 0.55) if kind == 'pine' else rng.uniform(0.22, 0.32)
        p, tan, r, _ = tr.at(1.0)
        for k in range(3):
            n = rotate(Vector((1, 0, 0)), UP, k * math.pi / 3)
            tree.sites.append(Site(p - UP * 0.35, UP.copy(), n, tiles[0], size * 0.65, 0.0, tr.phase, rng.random()))
    else:
        tree.bark = 'birch' if kind == 'birch' else 'hardwood'
        H = rng.uniform(2.8, 4.2)
        tr = trunk(tree, H, 0.04, 6, lean=0.06, wobble=0.04)
        crown_c = Vector((0, 0, H * 0.62))
        tiles = {'maple': ['maple_a', 'maple_b'], 'birch': ['birch_a', 'birch_b'], 'hazel': ['hazel_a', 'hazel_b']}[kind]
        size = TILES[tiles[0]]['size']
        z = H * 0.25
        while z < H - 0.2:
            p, tan, r_t, _ = tr.at(z / H)
            az = rng.uniform(0, 2 * math.pi)
            dirv = Vector((math.cos(az), math.sin(az), 0.9))
            L = rng.uniform(0.7, 1.4) * (1.15 - z / H)
            pts, radii = grow(p, dirv, L, 0.014, 0.004, 3, rng, gravity=0.12 if kind == 'birch' else 0.06, wobble=0.1)
            b = Branch(pts, radii, 1, 0.0, rng.random(), rng.random())
            tree.branches.append(b)
            add_sites_along(tree, b, rng.choice(tiles), size * 0.8, 0.05, 0.13, outward_card(crown_c), rng)
            tip_cluster(tree, b, tiles, size * 0.8, rng, 2)
            z += rng.uniform(0.18, 0.3)
        p, tan, r, _ = tr.at(1.0)
        for k in range(3):
            n = rotate(Vector((1, 0, 0)), UP, k * math.pi / 3)
            tree.sites.append(Site(p - UP * 0.3, UP.copy(), n, tiles[0], size * 0.8, 0.0, tr.phase, rng.random()))


def shrub(tree, v):
    """Hazel / viburnum clump: 7-11 arching stems from one root, leafy from 0.3 m up."""
    rng = tree.rng
    tree.bark = 'hardwood'
    H = rng.uniform(1.7, 2.5)
    crown_c = Vector((0, 0, H * 0.55))
    for s_ in range(rng.randint(7, 11)):
        az = rng.uniform(0, 2 * math.pi)
        lean = rng.uniform(0.2, 0.7)
        d = (UP + Vector((math.cos(az), math.sin(az), 0)) * lean).normalized()
        base = Vector((math.cos(az), math.sin(az), 0)) * rng.uniform(0.0, 0.3)
        pts, radii = grow(base - UP * 0.2, d, H * rng.uniform(0.75, 1.15), 0.02, 0.005, 5, rng, gravity=0.14, wobble=0.07)
        b = Branch(pts, radii, 1, 0.0, rng.random(), rng.random())
        tree.branches.append(b)
        # Variant 2 mixes in the Poly Haven shrub_04 sprig (atlas tile 15, narrower leaves).
        tiles = ['hazel_a', 'hazel_b'] if v != 2 else ['shrub04', 'hazel_b']
        add_sites_along(tree, b, rng.choice(tiles), 0.8, 0.15, 0.12, outward_card(crown_c), rng, size_var=0.2)
        tip_cluster(tree, b, tiles, 0.8, rng, 3)


SPECIES = {
    # name: builder, variants, LOD triangle budgets, card LOD target fractions
    'white_pine': dict(build=white_pine, budget=(8000, 2500, 800, 200), lod_cards=(1.0, 0.3, 0.09)),
    'hemlock': dict(build=hemlock, budget=(7000, 2000, 700, 200), lod_cards=(1.0, 0.28, 0.09)),
    'oak': dict(build=lambda t, v: broadleaf(t, v, 'oak'), budget=(10000, 3000, 900, 220), lod_cards=(1.0, 0.3, 0.09)),
    'maple': dict(build=lambda t, v: broadleaf(t, v, 'maple'), budget=(9000, 2500, 800, 200), lod_cards=(1.0, 0.28, 0.09)),
    'birch': dict(build=birch, budget=(5000, 1500, 500, 150), lod_cards=(1.0, 0.3, 0.1)),
    'sapling_pine': dict(build=lambda t, v: sapling(t, v, 'pine'), budget=(2000, 400, 0, 0), lod_cards=(1.0, 0.25, 0)),
    'sapling_hemlock': dict(build=lambda t, v: sapling(t, v, 'hemlock'), budget=(2000, 400, 0, 0), lod_cards=(1.0, 0.25, 0)),
    'sapling_maple': dict(build=lambda t, v: sapling(t, v, 'maple'), budget=(2000, 400, 0, 0), lod_cards=(1.0, 0.25, 0)),
    'sapling_birch': dict(build=lambda t, v: sapling(t, v, 'birch'), budget=(2000, 400, 0, 0), lod_cards=(1.0, 0.25, 0)),
    'shrub_hazel': dict(build=shrub, budget=(3000, 800, 0, 0), lod_cards=(1.0, 0.3, 0)),
}
CLUMP_OF = {'pine_a': 'pine_clump', 'pine_b': 'pine_clump', 'hemlock_a': 'hemlock_clump', 'hemlock_b': 'hemlock_clump_b',
            'oak_a': 'oak_clump', 'oak_b': 'oak_clump', 'maple_a': 'maple_clump', 'maple_b': 'maple_clump',
            'maple_red': 'maple_red_clump', 'birch_a': 'birch_clump', 'birch_b': 'birch_clump',
            'hazel_a': 'hazel_clump', 'hazel_b': 'hazel_clump', 'deadtwig': 'deadtwig', 'fir_side': 'fir_side',
            'shrub04': 'hazel_clump'}


# --- meshing -------------------------------------------------------------------------------------

class MeshData:
    def __init__(self):
        self.v, self.n, self.uv, self.uv2, self.col, self.tris = [], [], [], [], [], []

    def add(self, p, n, uv, uv2, col):
        self.v.append(p)
        self.n.append(n)
        self.uv.append(uv)
        self.uv2.append(uv2)
        self.col.append(col)
        return len(self.v) - 1


def crown_frame(tree):
    pts = [s.p + s.d * s.size * 0.5 for s in tree.sites if s.tile != 'deadtwig']
    if not pts:
        return Vector((0, 0, 1)), Vector((1, 1, 1)), 0.0, 1.0
    c = sum(pts, Vector()) / len(pts)
    ex = []
    for k in range(3):
        vals = sorted(abs(p[k] - c[k]) for p in pts)
        ex.append(max(vals[int(len(vals) * 0.9)] * 1.1, 0.3))
    zs = [p.z for p in pts]
    return c, Vector(ex), min(zs), max(zs)


def ellipsoid(p, c, r):
    q = Vector(((p.x - c.x) / r.x, (p.y - c.y) / r.y, (p.z - c.z) / r.z))
    d = q.length
    n = Vector(((p.x - c.x) / (r.x * r.x), (p.y - c.y) / (r.y * r.y), (p.z - c.z) / (r.z * r.z)))
    return d, (n.normalized() if n.length > 1e-6 else UP.copy())


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def tube_mesh(md, br, sides, ring_step, bark_tile, crown, tree, trunk_ao=True):
    c, r, zmin, zmax = crown
    pts = br.pts
    n = len(pts)
    idx_rows = []
    # Parallel-transport frame.
    t0 = (pts[1] - pts[0]).normalized()
    u = perp(t0)
    length_acc = 0.0
    use = list(range(0, n, ring_step))
    if use[-1] != n - 1:
        use.append(n - 1)
    prev_t = t0
    last_i = 0
    circumference = 2 * math.pi * max(br.radii[0], 0.01)
    reps = max(1, round(circumference / (1.1 if tree.bark != 'birch' else 0.9)))
    for i in use:
        if i > 0:
            length_acc += sum((pts[k + 1] - pts[k]).length for k in range(last_i, i))
        last_i = i
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        # Transport u from prev_t to t.
        axis = prev_t.cross(t)
        if axis.length > 1e-6:
            ang = math.asin(min(1.0, axis.length))
            u = rotate(u, axis.normalized(), ang)
        u = (u - t * u.dot(t)).normalized()
        w = t.cross(u).normalized()
        prev_t = t
        rad = br.radii[i]
        row = []
        p = pts[i]
        # AO: trunk under the crown and near the ground is darker.
        if br.level == 0:
            ao = 0.8 - 0.3 * smooth(zmin - 2.0, zmin + 1.0, p.z) * (1 if trunk_ao else 0)
            ao *= 0.85 + 0.15 * smooth(0.0, 1.5, p.z)
        else:
            d, _ = ellipsoid(p, c, r)
            ao = 0.45 + 0.4 * smooth(0.2, 1.0, d)
        if br.dead:
            ao *= 0.9
        wind_x = br.attach + length_acc if br.level > 0 else 0.0
        for k in range(sides + 1):
            a = 2 * math.pi * k / sides
            nrm = u * math.cos(a) + w * math.sin(a)
            v = p + nrm * rad
            uvx = reps * k / sides
            uvy = -length_acc / bark_tile
            row.append(md.add(v, nrm, (uvx, uvy), (wind_x, br.phase), (ao, 0.0, br.rand, 0.0)))
        idx_rows.append(row)
    for a_, b_ in zip(idx_rows[:-1], idx_rows[1:]):
        for k in range(sides):
            md.tris.append((a_[k], a_[k + 1], b_[k + 1]))
            md.tris.append((a_[k], b_[k + 1], b_[k]))


CARD_TRIS = 4      # hexagonal cutout cards (foliage_tiles.json "hull"): 4 triangles each


def card_mesh(md, s, crown, normal_bend=0.62, ao_lift=0.0):
    c, r, zmin, zmax = crown
    t = TILES[s.tile]
    ux, uy, uw, uh = t['uv']
    inset = 1.5 / 2048.0
    d = s.d.normalized()
    n = (s.n - d * s.n.dot(d)).normalized()
    right = d.cross(n).normalized()
    corners = [tuple(q) for q in t.get('hull', [[0, 0], [1, 0], [1, 1], [0, 1]])]
    ids = []
    for cu, cv in corners:
        p = s.p + right * ((cu - 0.5) * s.size) + d * (cv * s.size)
        dist, en = ellipsoid(p, c, r)
        nc = n if n.dot(en) >= 0 else -n
        nv = (nc * (1 - normal_bend) + en * normal_bend + UP * 0.12).normalized()
        ao = 0.32 + 0.68 * smooth(0.15, 1.0, dist)
        ao *= 0.88 + 0.12 * smooth(zmin, zmax, p.z)
        ao = 1.0 - (1.0 - ao) * (1.0 - ao_lift)
        outer = smooth(0.55, 1.05, dist) * (0.6 + 0.4 * max(0.0, en.z))
        u = ux + inset + (uw - 2 * inset) * cu
        vimg = uy + inset + (uh - 2 * inset) * (1 - cv)
        ids.append(md.add(p, nv, (u, 1.0 - vimg), (s.attach + cv * s.size * 0.8, s.phase), (min(ao, 1.0), outer, s.rand, 1.0)))
    for i in range(1, len(ids) - 1):
        md.tris.append((ids[0], ids[i], ids[i + 1]))


def reduce_sites(sites, target, clump=True, rng=None, area_factor=0.72):
    """Voxel-cluster the foliage cards down to about `target`, enlarging the survivors so the crown
    keeps its coverage; switch them to the clump tiles."""
    if target >= len(sites):
        return list(sites)
    if target <= 0:
        return []
    lo, hi = 0.05, 20.0
    best = None
    for _ in range(30):
        g = (lo + hi) / 2
        cells = {}
        for s in sites:
            q = s.p + s.d * s.size * 0.4
            key = (int(math.floor(q.x / g)), int(math.floor(q.y / g)), int(math.floor(q.z / g)))
            cells.setdefault(key, []).append(s)
        if len(cells) > target:
            lo = g
        else:
            hi = g
            best = cells
        if best is not None and abs(len(best) - target) < max(3, target * 0.03):
            break
    if best is None:
        best = cells
    out = []
    for key, group in sorted(best.items()):
        area = sum(s.size * s.size for s in group)
        # The member nearest the group's centre keeps its orientation.
        cen = sum((s.p for s in group), Vector()) / len(group)
        s0 = min(group, key=lambda s: (s.p - cen).length)
        tile = CLUMP_OF.get(s0.tile, s0.tile) if clump else s0.tile
        size = min(math.sqrt(area) * area_factor, s0.size * 2.6)
        size = max(size, s0.size)
        out.append(Site(s0.p, s0.d, s0.n, tile, size, s0.attach, s0.phase, s0.rand))
    return out


def build_lod(tree, lod, spec):
    md = MeshData()
    crown = crown_frame(tree)
    bark_tile = 1.5 if tree.bark != 'birch' else 2.0
    for br in tree.branches:
        if lod == 0:
            if br.level == 0:
                sides, step = (10 if br.radii[0] > 0.12 else 7), 1
            elif br.level == 1:
                if br.radii[0] > 0.07:
                    sides, step = 5, 1
                elif br.radii[0] > 0.03:
                    sides, step = 4, 2
                else:
                    sides, step = 3, 2
            elif br.level == 2:
                if br.radii[0] < 0.028:
                    continue
                sides, step = 3, 3
            else:
                continue
        elif lod == 1:
            if br.level == 0:
                sides, step = (6 if br.radii[0] > 0.1 else 5), 2
            elif br.level == 1 and br.radii[0] > 0.035 and not br.dead:
                sides, step = 3, 3
            else:
                continue
        elif lod == 2:
            if br.level == 0:
                sides, step = 4, 4
            elif br.level == 1 and br.radii[0] > 0.09:
                sides, step = 3, 7
            else:
                continue
        else:
            # LOD3: shadow proxy (never drawn, only casts): the trunk and big clump cards.
            if br.level == 0:
                sides, step = 3, 6
            else:
                continue
        tube_mesh(md, br, sides, step, bark_tile, crown, tree)
    bark_tris = len(md.tris)
    budget = spec['budget'][lod]
    card_budget = max(0, (budget - bark_tris) // CARD_TRIS)
    if lod == 0:
        sites = tree.sites
        if len(sites) > card_budget:
            sites = reduce_sites(sites, card_budget, clump=False, area_factor=0.8)
    else:
        target = card_budget
        sites = reduce_sites(tree.sites, target, clump=True, area_factor=[0.0, 0.55, 0.65, 0.75][lod])
    # Slightly lighter baked AO on the far LODs (their merged cards lose the small gaps); with the
    # clump compositing fixed, LOD0 / LOD1 / LOD2 match within ~2 % in the lineup (veg_shots.gd).
    ao_lift = 0.0 if lod == 0 else 0.4
    for s in sites:
        card_mesh(md, s, crown, ao_lift=ao_lift)
    return md, bark_tris, len(sites)


def blob_proxy(tree, target_tris=34):
    """LOD4: an opaque shadow blob -- the convex hull of the crown's cards, pulled 12 % toward the
    crown centre (a real crown lets some light through), decimated to ~target_tris, plus a
    4-sided trunk. Rendered only into shadow maps beyond the alpha-tested proxy's range: no
    alpha test, so it is cheap to rasterise into the large far cascades."""
    md = MeshData()
    c, r, zmin, zmax = crown_frame(tree)
    pts = []
    for s in tree.sites:
        if s.tile == 'deadtwig':
            continue
        for f in (0.2, 0.7):
            pts.append(s.p + s.d * s.size * f)
    if len(pts) < 8:
        return md
    bm = bmesh.new()
    for q in pts:
        bm.verts.new(c + (q - c) * 0.88)
    bmesh.ops.convex_hull(bm, input=bm.verts)
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    me = bpy.data.meshes.new('blob_tmp')
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new('blob_tmp', me)
    link(ob)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    if tris > target_tris:
        m = ob.modifiers.new('dec', 'DECIMATE')
        m.decimate_type = 'COLLAPSE'
        m.ratio = target_tris / tris
        m.use_collapse_triangulate = True
        for o in bpy.context.scene.objects:
            o.select_set(False)
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=m.name)
    me = ob.data
    base = len(md.v)
    for v in me.vertices:
        md.add(Vector(v.co), Vector(v.normal), (0.0, 0.0), (0.0, 0.0), (1.0, 0.0, 0.0, 0.0))
    for poly in me.polygons:
        vs = list(poly.vertices)
        for i in range(1, len(vs) - 1):
            md.tris.append((base + vs[0], base + vs[i], base + vs[i + 1]))
    bpy.data.objects.remove(ob, do_unlink=True)
    # Trunk up to the crown.
    for br in tree.branches:
        if br.level == 0:
            tube_mesh(md, br, 4, 6, 1.5, (c, r, zmin, zmax), tree)
    return md


def to_object(name, md):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in md.v], [], md.tris)
    me.update()
    uv0 = me.uv_layers.new(name='UVMap')
    uv1 = me.uv_layers.new(name='UV2')
    li = [0] * len(me.loops)
    me.loops.foreach_get('vertex_index', li)
    flat0, flat1 = [], []
    for vi in li:
        flat0.extend(md.uv[vi])
        flat1.extend(md.uv2[vi])
    uv0.data.foreach_set('uv', flat0)
    uv1.data.foreach_set('uv', flat1)
    ca = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
    flatc = []
    for c in md.col:
        flatc.extend(c)
    ca.data.foreach_set('color', flatc)
    me.color_attributes.active_color = ca
    me.normals_split_custom_set_from_vertices([tuple(n) for n in md.n])
    ob = bpy.data.objects.new(name, me)
    link(ob)
    return ob


def tree_info(tree):
    """Placement metadata for the Godot scatter (Godot Y-up metres, unscaled tree)."""
    c, r, zmin, zmax = crown_frame(tree)
    trunks = [b for b in tree.branches if b.level == 0]
    top = max(max(p.z for p in b.pts) for b in tree.branches)
    top = max(top, zmax + 0.3)
    r12 = 0.0
    spread = 0.0
    for tb in trunks:
        for i in range(len(tb.pts) - 1):
            if tb.pts[i].z <= 1.2 <= tb.pts[i + 1].z:
                f = (1.2 - tb.pts[i].z) / max(tb.pts[i + 1].z - tb.pts[i].z, 1e-6)
                r12 = max(r12, tb.radii[i] * (1 - f) + tb.radii[i + 1] * f)
                spread = max(spread, math.hypot(tb.pts[i].x, tb.pts[i].y))
    fork = min(zmin, 8.0)
    return dict(height=round(top, 2), crown_center=[round(c.x, 2), round(c.z, 2), round(-c.y, 2)],
                crown_radius=round(max(r.x, r.y), 2), crown_half_height=round(r.z, 2),
                crown_bottom=round(zmin, 2), crown_top=round(zmax, 2),
                trunk_radius=round(r12 + spread, 3), collider_height=round(max(fork, 3.3), 2),
                bark=tree.bark, cards=len(tree.sites))


def build_species(name, spec, report):
    objs = []
    for v in range(3):
        rng = random.Random(hash_seed(name, v))
        tree = Tree(name, rng)
        spec['build'](tree, v)
        info = tree_info(tree)
        info['name'] = '%s_v%d' % (name, v)
        info['lod_tris'] = []
        report.append(info)
        for lod in range(5):
            if lod == 4:
                if spec['budget'][3] <= 0:
                    continue
                md = blob_proxy(tree)
                bark_tris, ncards = 0, 0
            elif spec['budget'][lod] <= 0:
                continue
            else:
                md, bark_tris, ncards = build_lod(tree, lod, spec)
            ob = to_object('%s_v%d_lod%d' % (name, v, lod), md)
            objs.append(ob)
            tris = len(md.tris)
            zs = [p.z for p in md.v]
            xs = [math.hypot(p.x, p.y) for p in md.v]
            info['lod_tris'].append(tris)
            info.setdefault('lod_radius', []).append(round(max(xs), 2))
            info.setdefault('lod_height', []).append(round(max(zs), 2))
            bud = spec["budget"][lod] if lod < 4 else 50
            print('%-24s tris=%6d (bark %5d, cards %5d of %5d)  budget %6d  h=%.1f r=%.1f %s' % (
                ob.name, tris, bark_tris, ncards, len(tree.sites), bud, max(zs), max(xs),
                'OVER' if tris > bud * 1.05 else ''))
    return objs


def hash_seed(name, v):
    h = 1776
    for ch in name:
        h = (h * 131 + ord(ch)) % 2147483647
    return h * 7 + v


def export(objs, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_materials='NONE',
                              export_vertex_color='ACTIVE', export_all_vertex_colors=False,
                              export_normals=True, export_texcoords=True, export_tangents=False,
                              export_yup=True, export_apply=False)
    print('exported', os.path.relpath(path, FRONTIER))


def preview(objs, path):
    """Quick look-dev render in Blender: every object in a row, sun + sky, the real textures."""
    sc = bpy.context.scene
    fol = os.path.join(ENV, 'vegetation', 'foliage')
    bark_dir = os.path.join(ENV, 'vegetation', 'bark')
    mats = {}
    def mat_for(kind):
        if kind in mats:
            return mats[kind]
        m = bpy.data.materials.new('prev_' + kind)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes['Principled BSDF']
        attr = nt.nodes.new('ShaderNodeVertexColor')
        attr.layer_name = 'Col'
        sep = nt.nodes.new('ShaderNodeSeparateColor')
        nt.links.new(attr.outputs['Color'], sep.inputs[0])
        t_leaf = nt.nodes.new('ShaderNodeTexImage')
        t_leaf.image = bpy.data.images.load(os.path.join(fol, 'foliage_albedo.png'), check_existing=True)
        uvn = nt.nodes.new('ShaderNodeUVMap')
        uvn.uv_map = 'UVMap'
        nt.links.new(uvn.outputs['UV'], t_leaf.inputs['Vector'])
        t_bark = nt.nodes.new('ShaderNodeTexImage')
        bark_file = {'conifer': 'bark_conifer_albedo_2k.png', 'hardwood': 'bark_hardwood_albedo_2k.png', 'birch': 'birch_albedo_1k.png'}[kind]
        t_bark.image = bpy.data.images.load(os.path.join(bark_dir, bark_file), check_existing=True)
        nt.links.new(uvn.outputs['UV'], t_bark.inputs['Vector'])
        mix = nt.nodes.new('ShaderNodeMix')
        mix.data_type = 'RGBA'
        nt.links.new(sep.outputs['Alpha'] if 'Alpha' in sep.outputs else attr.outputs['Alpha'], mix.inputs['Factor'])
        nt.links.new(attr.outputs['Alpha'], mix.inputs['Factor'])
        nt.links.new(t_bark.outputs['Color'], mix.inputs['A'])
        nt.links.new(t_leaf.outputs['Color'], mix.inputs['B'])
        # AO multiply
        mul = nt.nodes.new('ShaderNodeMix')
        mul.data_type = 'RGBA'
        mul.blend_type = 'MULTIPLY'
        mul.inputs['Factor'].default_value = 1.0
        nt.links.new(mix.outputs['Result'], mul.inputs['A'])
        comb = nt.nodes.new('ShaderNodeCombineColor')
        for i in range(3):
            nt.links.new(sep.outputs['Red'], comb.inputs[i])
        nt.links.new(comb.outputs['Color'], mul.inputs['B'])
        nt.links.new(mul.outputs['Result'], bsdf.inputs['Base Color'])
        # alpha: leaf alpha where foliage, 1 on bark; hard clip at 0.5
        amix = nt.nodes.new('ShaderNodeMix')
        amix.data_type = 'FLOAT'
        nt.links.new(attr.outputs['Alpha'], amix.inputs['Factor'])
        amix.inputs['A'].default_value = 1.0
        nt.links.new(t_leaf.outputs['Alpha'], amix.inputs['B'])
        clip = nt.nodes.new('ShaderNodeMath')
        clip.operation = 'GREATER_THAN'
        clip.inputs[1].default_value = 0.45
        nt.links.new(amix.outputs['Result'], clip.inputs[0])
        nt.links.new(clip.outputs[0], bsdf.inputs['Alpha'])
        bsdf.inputs['Roughness'].default_value = 0.8
        mats[kind] = m
        return m
    x = 0.0
    maxh = 1.0
    for o in objs:
        kind = 'conifer' if any(k in o.name for k in ('pine', 'hemlock')) else ('birch' if 'birch' in o.name else 'hardwood')
        o.data.materials.clear()
        o.data.materials.append(mat_for(kind))
        w = max(math.hypot(v.co.x, v.co.y) for v in o.data.vertices)
        maxh = max(maxh, max(v.co.z for v in o.data.vertices))
        o.location = (x + w, 0, 0)
        x += 2 * w + 1.0
    sun = bpy.data.lights.new('sun', 'SUN')
    sun.energy = 3.0
    sun.color = (1.0, 0.85, 0.65)
    so = bpy.data.objects.new('sun', sun)
    so.rotation_euler = (math.radians(65), 0, math.radians(-40))
    link(so)
    world = bpy.data.worlds.new('w')
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[0].default_value = (0.45, 0.55, 0.7, 1)
    world.node_tree.nodes['Background'].inputs[1].default_value = 0.8
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 24
    sc.cycles.use_denoising = False
    sc.render.film_transparent = False
    width = x
    sc.render.resolution_x = 2400
    sc.render.resolution_y = int(2400 * (maxh * 1.1) / width) + 40
    sc.view_settings.view_transform = 'AgX'
    ortho_camera((width / 2, 0, maxh * 0.5), width, maxh * 1.1, direction=(0, 1, -0.05), up=(0, 0, 1), dist=200)
    render_to(path)


if __name__ == '__main__':
    reset()
    report = []
    all_objs = []
    for name, spec in SPECIES.items():
        if ONLY and name not in ONLY:
            continue
        objs = build_species(name, spec, report)
        all_objs += objs
        if A.get('export', '1') == '1':
            export(objs, os.path.join(OUT_DIR, name + '.glb'))
    if A.get('export', '1') == '1':
        path = os.path.join(OUT_DIR, 'trees.json')
        old = json.load(open(path)) if os.path.exists(path) else []
        names = {r['name'] for r in report}
        merged = [r for r in old if r['name'] not in names] + report
        merged.sort(key=lambda r: r['name'])
        with open(path, 'w') as f:
            json.dump(merged, f, indent=1)
    if A.get('preview'):
        preview(all_objs, A['preview'])
    print('TREES DONE')
