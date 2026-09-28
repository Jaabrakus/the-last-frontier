"""Procedural 18th-century arrow: wooden shaft, iron trade point bound with
sinew, three barred turkey-feather vanes, painted cresting and a self nock.

Run headless (factory scene):
  Blender -b --factory-startup --python tools/models/arrow.py -- \
      [--out assets/weapons/arrow.glb] [--renders DIR] [--blend FILE.blend]

Conventions (Godot / glTF axes), matching scripts/weapons/projectile.gd:
  * origin = the very tip of the iron point
  * forward (flight direction) = -Z, the shaft runs back along +Z to the nock
    end at z = +0.72
  * up = +Y; the point's blade and the nock slot lie in the vertical (YZ)
    plane, so the nock takes a vertical bow string; the cock feather points
    to -X (away from the bow for a right-handed archer), the two hen
    feathers at +/-60 degrees from +X
  * no Muzzle node (projectiles do not need one)

Blender works Z-up and the glTF exporter maps Blender (x, y, z) to glTF
(x, z, -y), so everything here is built through G(s, gx, gy): s is the
distance back from the tip (= Godot z), gx/gy are Godot x/y.

Output is a single mesh "Arrow" with two materials (one textured atlas for
wood/sinew/feathers/paint, one iron) so a quiver of stuck arrows stays cheap.
"""

import argparse
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

# --------------------------------------------------------------------------
# Dimensions (metres)
# --------------------------------------------------------------------------
LENGTH = 0.72            # tip to nock end, same as the placeholder in projectile.gd
BLADE_LEN = 0.040        # iron trade point, tip to shoulders
BLADE_HALF_W = 0.0098    # half width across the shoulders (~2 cm point)
BLADE_HALF_T = 0.0009    # half thickness at the centre ridge
TANG_HALF_W = 0.0026
TANG_END = BLADE_LEN + 0.010
SHAFT_FRONT = BLADE_LEN + 0.004
NOCK_SLOT = 0.712        # bottom of the nock slot
SIDES = 8                # shaft / binding cross-section

# Shaft radius profile (s, r): tapered where it is slotted for the point,
# fullest a little forward of centre, slimmer toward the nock.
SHAFT_PROFILE = [(SHAFT_FRONT, 0.0034), (0.074, 0.0040), (0.300, 0.0044),
                 (NOCK_SLOT, 0.0038), (LENGTH, 0.0037)]
# Loft rings (extra rings bound the painted cresting bands).
SHAFT_RINGS = [SHAFT_FRONT, 0.074, 0.300, 0.494, 0.500, 0.522, 0.528, NOCK_SLOT]
# Cresting: (s0, s1, paint) between those rings.
BANDS = [(0.494, 0.500, "black"), (0.500, 0.522, "red"), (0.522, 0.528, "black")]

FLETCH = (0.548, 0.692)  # vane start/end along the shaft
FLETCH_H = [(0.00, 0.0010), (0.06, 0.0055), (0.15, 0.0095), (0.30, 0.0125),
            (0.50, 0.0140), (0.70, 0.0145), (0.85, 0.0140), (0.95, 0.0120),
            (1.00, 0.0015)]
FLETCH_HMAX = 0.0145
# Cock feather to -X (180 deg), hens at +/-60 deg.
FEATHER_ANGLES = [180.0, 60.0, -60.0]

# Sinew bindings: rings of (s, extra radius over the shaft) or absolute r.
BINDINGS = [
    [(BLADE_LEN + 0.001, None, 0.0029), (0.047, None, 0.0045),
     (0.066, None, 0.0046), (0.072, 0.0002, None)],                 # point
    [(0.540, 0.0002, None), (0.543, 0.0007, None),
     (0.557, 0.0007, None), (0.560, 0.0002, None)],                 # fletch front
    [(0.684, 0.0002, None), (0.687, 0.0008, None),
     (0.705, 0.0008, None), (0.708, 0.0002, None)],                 # fletch rear / nock
]

# Atlas layout (UV space, v up):  feathers v 0.5-1, wood v 0.25-0.5,
# sinew u 0-0.5 / red u 0.5-0.75 / black u 0.75-1 in v 0-0.25.
ATLAS_W, ATLAS_H = 256, 128
UV_FEATHER = (0.01, 0.99, 0.515, 0.985)
UV_WOOD = (0.01, 0.99, 0.265, 0.485)
UV_SINEW = (0.015, 0.485, 0.015, 0.235)
UV_PAINT = {"red": (0.515, 0.735, 0.015, 0.235), "black": (0.765, 0.985, 0.015, 0.235)}

MAT_ATLAS, MAT_IRON = 0, 1


def G(s, gx, gy):
    """Godot-space point (x=gx, y=gy, z=s) expressed in Blender coordinates."""
    return Vector((gx, -s, gy))


def lerp(a, b, t):
    return a + (b - a) * t


def interp(table, x):
    if x <= table[0][0]:
        return table[0][1]
    for (x0, y0), (x1, y1) in zip(table, table[1:]):
        if x <= x1:
            return lerp(y0, y1, (x - x0) / (x1 - x0))
    return table[-1][1]


def shaft_r(s):
    return interp(SHAFT_PROFILE, s)


def ring_dir(j, phase=math.radians(22.5)):
    a = phase + 2.0 * math.pi * j / SIDES
    return math.cos(a), math.sin(a)


# --------------------------------------------------------------------------
# Mesh building
# --------------------------------------------------------------------------
class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def v(self, co):
        return self.bm.verts.new(co)

    def face(self, verts, uvs, mat, smooth, out):
        """Add a face whose normal points along `out` (a Blender-space vector)."""
        n = Vector()
        for i, a in enumerate(verts):
            b = verts[(i + 1) % len(verts)]
            n.x += (a.co.y - b.co.y) * (a.co.z + b.co.z)
            n.y += (a.co.z - b.co.z) * (a.co.x + b.co.x)
            n.z += (a.co.x - b.co.x) * (a.co.y + b.co.y)
        if n.dot(out) < 0.0:
            verts = list(reversed(verts))
            uvs = list(reversed(uvs))
        f = self.bm.faces.new(verts)
        f.material_index = mat
        f.smooth = smooth
        for loop, t in zip(f.loops, uvs):
            loop[self.uv].uv = t
        return f

    def sharp(self, a, b):
        e = self.bm.edges.get((a, b))
        if e:
            e.smooth = False

    def loft(self, rings, uv_rect, mat, uv_for_segment=None):
        """Closed tube along the shaft. rings = [(s, r)]; returns vertex rings."""
        vr = []
        for s, r in rings:
            vr.append([self.v(G(s, r * c, r * sn)) for c, sn in (ring_dir(j) for j in range(SIDES))])
        s_min, s_max = rings[0][0], rings[-1][0]
        for i in range(len(rings) - 1):
            s0, s1 = rings[i][0], rings[i + 1][0]
            if uv_for_segment:
                # Caller supplies this segment's exact UV rect.
                ua, ub, v0, v1 = uv_for_segment(s0, s1)
            else:
                u0, u1, v0, v1 = uv_rect
                ua = lerp(u0, u1, (s0 - s_min) / (s_max - s_min))
                ub = lerp(u0, u1, (s1 - s_min) / (s_max - s_min))
            for j in range(SIDES):
                k = (j + 1) % SIDES
                va = lerp(v0, v1, j / SIDES)
                vb = lerp(v0, v1, (j + 1) / SIDES)
                c, sn = ring_dir(j + 0.5)
                self.face([vr[i][j], vr[i][k], vr[i + 1][k], vr[i + 1][j]],
                          [(ua, va), (ua, vb), (ub, vb), (ub, va)],
                          mat, True, G(0, c, sn))
        return vr


def build_shaft(b):
    rings = [(s, shaft_r(s)) for s in SHAFT_RINGS]

    def seg_uv(s0, s1):
        for a0, a1, paint in BANDS:
            if abs(s0 - a0) < 1e-6 and abs(s1 - a1) < 1e-6:
                return UV_PAINT[paint]
        return UV_WOOD

    # Wood UVs run along the whole shaft so the grain is continuous.
    def uv_for(s0, s1):
        rect = seg_uv(s0, s1)
        if rect is UV_WOOD:
            u0, u1, v0, v1 = UV_WOOD
            return (lerp(u0, u1, s0 / LENGTH), lerp(u0, u1, s1 / LENGTH), v0, v1)
        return rect

    vr = b.loft(rings, UV_WOOD, MAT_ATLAS, uv_for)

    # Front cap (inside the point binding, around the tang).
    front = vr[0]
    cu = lerp(UV_WOOD[0], UV_WOOD[1], 0.03)
    cv = 0.5 * (UV_WOOD[2] + UV_WOOD[3])
    b.face(front, [(cu + 0.004 * ring_dir(j)[0], cv + 0.01 * ring_dir(j)[1]) for j in range(SIDES)],
           MAT_ATLAS, False, G(-1, 0, 0) - G(0, 0, 0))
    for j in range(SIDES):
        b.sharp(front[j], front[(j + 1) % SIDES])

    # Self nock: two prongs either side of a vertical slot.
    last = vr[-1]
    r_end = shaft_r(LENGTH) * 0.95
    back = G(1, 0, 0) - G(0, 0, 0)
    ue = lerp(UV_WOOD[0], UV_WOOD[1], 1.0)
    us = lerp(UV_WOOD[0], UV_WOOD[1], NOCK_SLOT / LENGTH)
    v0, v1 = UV_WOOD[2], UV_WOOD[3]
    # Slot bottom: the flat top/bottom edge verts of the octagon (j=1,2,5,6).
    slot = [last[1], last[2], last[5], last[6]]
    b.face(slot, [(us, v0), (us, v0 + 0.02), (us + 0.004, v0 + 0.02), (us + 0.004, v0)],
           MAT_ATLAS, False, back)
    for prong, inner_dir in (([6, 7, 0, 1], -1.0), ([2, 3, 4, 5], 1.0)):
        end = {}
        for j in prong:
            c, sn = ring_dir(j)
            end[j] = b.v(G(LENGTH, r_end * c, r_end * sn))
        for a, c_ in zip(prong, prong[1:]):
            va = lerp(v0, v1, a / SIDES)
            vb = lerp(v0, v1, (a + 1) / SIDES)
            cc, ss = ring_dir(a + 0.5)
            b.face([last[a], last[c_], end[c_], end[a]],
                   [(us, va), (us, vb), (ue, vb), (ue, va)], MAT_ATLAS, True, G(0, cc, ss))
        a, z = prong[-1], prong[0]
        inner = G(0, inner_dir, 0) - G(0, 0, 0)
        b.face([last[a], last[z], end[z], end[a]],
               [(us, v0), (us, v0 + 0.02), (ue, v0 + 0.02), (ue, v0)], MAT_ATLAS, False, inner)
        b.face([end[j] for j in prong],
               [(ue - 0.004, v0 + 0.005 * i) for i in range(4)], MAT_ATLAS, False, back)
        for j in prong:
            b.sharp(end[j], end[prong[(prong.index(j) + 1) % 4]])
        b.sharp(last[a], last[z])
        b.sharp(last[a], end[a])
        b.sharp(last[z], end[z])
    for x, y in ((1, 2), (5, 6)):
        b.sharp(last[x], last[y])


def build_point(b):
    """Flat iron trade point, diamond section, with a tang into the shaft slot."""
    fr = [0.0, 0.10, 0.24, 0.40, 0.57, 0.75, 0.90, 1.0]
    samples = [(BLADE_LEN * f, BLADE_HALF_W * f ** 0.85) for f in fr]
    samples.append((BLADE_LEN + 0.0006, TANG_HALF_W))        # shoulders cut in to the tang
    samples.append((TANG_END, TANG_HALF_W * 0.85))
    tip = b.v(G(0, 0, 0))
    ridge_p, ridge_n, up, lo = [tip], [tip], [tip], [tip]
    for s, w in samples[1:]:
        t = BLADE_HALF_T * min(1.0, s / (0.3 * BLADE_LEN))
        ridge_p.append(b.v(G(s, t, 0)))
        ridge_n.append(b.v(G(s, -t, 0)))
        up.append(b.v(G(s, 0, w)))
        lo.append(b.v(G(s, 0, -w)))

    def uv(s, y):
        return (0.5 + y * 20.0, 0.5 - s * 10.0)

    ys = [0.0] + [w for _, w in samples[1:]]
    ss = [s for s, _ in samples]
    for i in range(len(samples) - 1):
        for ridge, side in ((ridge_p, 1.0), (ridge_n, -1.0)):
            for edge, sy in ((up, 1.0), (lo, -1.0)):
                out = Vector((side * 1.0, 0.0, sy * 1.0))   # Blender: x side, z up/down
                if i == 0:
                    b.face([tip, ridge[1], edge[1]],
                           [uv(0, 0), uv(ss[1], 0), uv(ss[1], sy * ys[1])], MAT_IRON, False, out)
                else:
                    b.face([ridge[i], ridge[i + 1], edge[i + 1], edge[i]],
                           [uv(ss[i], 0), uv(ss[i + 1], 0), uv(ss[i + 1], sy * ys[i + 1]),
                            uv(ss[i], sy * ys[i])], MAT_IRON, False, out)
    n = len(samples) - 1
    b.face([ridge_p[n], up[n], ridge_n[n], lo[n]],
           [uv(TANG_END, 0), uv(TANG_END, 0.002), uv(TANG_END, 0), uv(TANG_END, -0.002)],
           MAT_IRON, False, G(1, 0, 0) - G(0, 0, 0))


def build_bindings(b):
    for spec in BINDINGS:
        rings = []
        for s, extra, absolute in spec:
            rings.append((s, absolute if absolute is not None else shaft_r(s) + extra))
        length = rings[-1][0] - rings[0][0]
        u0, u1, v0, v1 = UV_SINEW
        rect = (u0, u0 + (u1 - u0) * min(1.0, length / 0.03), v0, v1)
        b.loft(rings, rect, MAT_ATLAS)


def build_feathers(b):
    cols = 9
    rows = 3
    for k, deg in enumerate(FEATHER_ANGLES):
        a = math.radians(deg)
        er = (math.cos(a), math.sin(a))
        et = (-math.sin(a), math.cos(a))
        u_off = 0.02 + 0.12 * k
        grid = []
        uvs = []
        for i in range(cols):
            u = i / (cols - 1)
            s = lerp(FLETCH[0], FLETCH[1], u)
            h = interp(FLETCH_H, u)
            rb = shaft_r(s) + 0.0002
            col, coluv = [], []
            for r in range(rows):
                f = r / (rows - 1)
                rad = rb + h * f
                # Natural cup of the vane plus a slight helical set.
                off = 0.0010 * f * f * (h / FLETCH_HMAX) + 0.0010 * (u - 0.5) * f
                gx = er[0] * rad + et[0] * off
                gy = er[1] * rad + et[1] * off
                col.append(b.v(G(s, gx, gy)))
                fu0, fu1, fv0, fv1 = UV_FEATHER
                coluv.append((lerp(fu0, fu1, u_off + u * 0.7), lerp(fv0, fv1, f * h / FLETCH_HMAX)))
            grid.append(col)
            uvs.append(coluv)
        side = G(0, et[0], et[1]) - G(0, 0, 0)
        for i in range(cols - 1):
            for r in range(rows - 1):
                b.face([grid[i][r], grid[i + 1][r], grid[i + 1][r + 1], grid[i][r + 1]],
                       [uvs[i][r], uvs[i + 1][r], uvs[i + 1][r + 1], uvs[i][r + 1]],
                       MAT_ATLAS, True, side)


# --------------------------------------------------------------------------
# Materials and atlas texture
# --------------------------------------------------------------------------
def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def mix(c0, c1, t):
    return tuple(lerp(x, y, t) for x, y in zip(c0, c1))


def _hash(ix, iy, seed):
    n = (ix * 374761393 + iy * 668265263 + seed * 144269504) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def vnoise(x, y, seed=0):
    """Smooth value noise in 0..1."""
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b_ = _hash(ix, iy, seed), _hash(ix + 1, iy, seed)
    c, d = _hash(ix, iy + 1, seed), _hash(ix + 1, iy + 1, seed)
    return lerp(lerp(a, b_, sx), lerp(c, d, sx), sy)


def make_atlas():
    W, H = ATLAS_W, ATLAS_H
    rnd = random.Random(1757)
    px = [0.0] * (W * H * 4)
    buff = (0.72, 0.64, 0.50)
    cream = (0.86, 0.81, 0.70)
    dark = (0.19, 0.14, 0.095)
    quill = (0.86, 0.82, 0.72)
    wood = (0.62, 0.46, 0.29)
    sinew = (0.78, 0.68, 0.50)
    red = (0.55, 0.17, 0.09)
    black = (0.07, 0.06, 0.05)
    row_noise = [rnd.uniform(-1, 1) for _ in range(H)]
    for y in range(H):
        for x in range(W):
            n = rnd.uniform(-0.03, 0.03)
            if y >= H // 2:                        # wild turkey wing feather
                fu = x / W
                fv = (y - H // 2) / (H // 2)
                # Dark brown vane crossed by narrow, irregular buff bars that
                # slant back along the barbs.
                warp = 0.45 * (vnoise(fu * 9.0, fv * 3.0, 1) - 0.5)
                p = fu * 12.0 + fv * 1.1 + warp
                bar_i = math.floor(p)
                fr = p - bar_i
                width = 0.26 + 0.14 * _hash(bar_i, 0, 3)
                light_amt = smoothstep(0.0, 0.07, fr) * (1.0 - smoothstep(width, width + 0.08, fr))
                light = mix(buff, cream, vnoise(fu * 25.0, fv * 6.0, 5))
                c_dark = tuple(ch * (0.75 + 0.5 * vnoise(fu * 22.0, fv * 7.0, 4)) for ch in dark)
                c = mix(c_dark, light, light_amt * (0.75 + 0.25 * vnoise(fu * 40.0, fv * 9.0, 2)))
                # Barbs sweep back from the quill.
                barb = 0.92 + 0.08 * math.sin(2 * math.pi * (fu * 90.0 - fv * 22.0))
                c = tuple(ch * barb for ch in c)
                c = mix(quill, c, smoothstep(0.03, 0.09, fv))
                c = tuple(ch * (1.0 - 0.12 * smoothstep(0.85, 1.0, fv)) for ch in c)
            elif y >= H // 4:                      # wood grain along u
                fu = x / W
                fv = (y - H // 4) / (H // 4)
                g = 0.5 + 0.5 * math.sin(2 * math.pi * (fv * 6.0 + 0.35 * math.sin(fu * 17.0)))
                streak = 0.04 * row_noise[y] * math.sin(fu * 41.0 + y)
                c = tuple(ch * (0.86 + 0.14 * g + streak) for ch in wood)
            else:
                fu = x / W
                if fu < 0.5:                       # sinew wraps across u
                    w = 0.5 + 0.5 * math.cos(2 * math.pi * (x + 0.2 * y) / 4.0)
                    c = tuple(ch * (0.80 + 0.20 * w) for ch in sinew)
                elif fu < 0.75:
                    c = red
                else:
                    c = black
            i = (y * W + x) * 4
            px[i] = max(0.0, min(1.0, c[0] + n))
            px[i + 1] = max(0.0, min(1.0, c[1] + n))
            px[i + 2] = max(0.0, min(1.0, c[2] + n))
            px[i + 3] = 1.0
    img = bpy.data.images.new("arrow_atlas", W, H, alpha=False)
    img.pixels.foreach_set(px)
    img.update()
    return img


def principled(name, color=None, metallic=0.0, roughness=0.6, image=None, double_sided=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if color:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    if image:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.interpolation = "Linear"
        tex.location = (-400, 200)
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    m.use_backface_culling = not double_sided
    return m


# --------------------------------------------------------------------------
# Assembly / export
# --------------------------------------------------------------------------
def build_arrow(scratch_png=None):
    b = Builder()
    build_point(b)
    build_shaft(b)
    build_bindings(b)
    build_feathers(b)
    mesh = bpy.data.meshes.new("Arrow")
    b.bm.to_mesh(mesh)
    b.bm.free()
    mesh.validate()

    img = make_atlas()
    if scratch_png:
        img.filepath_raw = scratch_png
        img.file_format = "PNG"
        img.save()
        img.source = "FILE"
        img.reload()
    img.pack()
    # Feathers are single planes, so the atlas material is double sided.
    atlas = principled("ArrowAtlas", roughness=0.72, image=img, double_sided=True)
    # Blackened, hand-forged iron: darker and rougher than bright steel.
    iron = principled("ArrowIron", color=(0.20, 0.19, 0.18), metallic=0.7, roughness=0.5)
    mesh.materials.append(atlas)
    mesh.materials.append(iron)

    obj = bpy.data.objects.new("Arrow", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def export_glb(obj, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_texcoords=True, export_normals=True,
        export_materials="EXPORT", export_image_format="AUTO",
        export_cameras=False, export_lights=False, export_extras=False)


# --------------------------------------------------------------------------
# Preview renders
# --------------------------------------------------------------------------
def _box(name, center, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.data.materials.append(mat)
    return o


def _text(body, loc, size, mat, rot=(math.radians(90), 0.0, math.radians(90))):
    cu = bpy.data.curves.new("txt_" + body, "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = "CENTER"
    o = bpy.data.objects.new("txt_" + body, cu)
    o.location = loc
    o.rotation_euler = rot
    o.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(o)
    return o


def _camera(name, loc, target, ortho=None, lens=50.0):
    cd = bpy.data.cameras.new(name)
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.lens = lens
    cd.clip_start = 0.005
    o = bpy.data.objects.new(name, cd)
    o.location = loc
    d = Vector(target) - Vector(loc)
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(o)
    return o


def render_previews(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene
    try:
        sc.render.engine = "BLENDER_EEVEE"
    except TypeError:
        sc.render.engine = "BLENDER_WORKBENCH"
    try:
        sc.eevee.taa_render_samples = 64
    except AttributeError:
        pass
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = False

    world = bpy.data.worlds.new("PreviewWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.62, 0.64, 0.67, 1.0)
    bg.inputs["Strength"].default_value = 0.9
    sc.world = world

    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.2
    sun.angle = math.radians(8)
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(40), math.radians(-25), math.radians(35))
    sc.collection.objects.link(so)

    white = principled("ScaleWhite", color=(0.9, 0.9, 0.9), roughness=0.9)
    black = principled("ScaleBlack", color=(0.02, 0.02, 0.02), roughness=0.9)

    # 10 cm scale bar under the arrow (side view reads it in ortho).
    zb = -0.045
    for i in range(8):
        _box("bar%d" % i, (0.0, -(i + 0.5) * 0.1, zb), (0.002, 0.1, 0.006), black if i % 2 == 0 else white)
    for i in range(9):
        _text("%d" % (i * 10), (0.0, -i * 0.1, zb - 0.022), 0.016, black)
    _text("cm from tip (10 cm blocks)", (0.0, -0.40, zb - 0.045), 0.016, black)
    # 1 cm ruler near the point for the close-ups.
    for i in range(8):
        _box("cm%d" % i, (0.0, -(i + 0.5) * 0.01, -0.016), (0.0012, 0.01, 0.0018),
             black if i % 2 == 0 else white)
    _text("1 cm blocks", (0.0, -0.04, -0.023), 0.004, black)

    # Floor with 10 cm checkers for the perspective views.
    floor_m = bpy.data.materials.new("Floor")
    floor_m.use_nodes = True
    nt = floor_m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    chk = nt.nodes.new("ShaderNodeTexChecker")
    chk.inputs["Scale"].default_value = 10.0  # squares of 1/scale = 0.1 m in object space
    chk.inputs["Color1"].default_value = (0.55, 0.55, 0.55, 1)
    chk.inputs["Color2"].default_value = (0.45, 0.45, 0.45, 1)
    nt.links.new(tc.outputs["Object"], chk.inputs["Vector"])
    nt.links.new(chk.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.9
    bpy.ops.mesh.primitive_plane_add(size=2.0, location=(0, 0, -0.09))
    floor = bpy.context.active_object
    floor.data.materials.append(floor_m)

    shots = [
        ("arrow_side", _camera("cam_side", (1.0, -0.39, -0.03), (0, -0.39, -0.03), ortho=0.90), (2000, 560), True),
        ("arrow_3q", _camera("cam_3q", (0.55, 0.30, 0.34), (0, -0.33, -0.01), lens=50), (1600, 900), False),
        ("arrow_point_detail", _camera("cam_pt", (0.075, 0.055, 0.045), (0, -0.035, -0.004), lens=50),
         (1400, 900), False),
        ("arrow_fletch_detail", _camera("cam_fl", (0.13, -0.86, 0.075), (0, -0.63, 0.0), lens=50),
         (1600, 900), False),
        ("arrow_rear", _camera("cam_rear", (0.0, -1.0, 0.0), (0, 0, 0), ortho=0.05), (900, 900), True),
        ("arrow_side_fletch", _camera("cam_sf", (0.3, -0.63, 0.0), (0, -0.63, 0.0), ortho=0.19),
         (1600, 700), True),
    ]
    for name, cam, (w, h), hide_floor in shots:
        floor.hide_render = hide_floor
        sc.camera = cam
        sc.render.resolution_x = w
        sc.render.resolution_y = h
        sc.render.filepath = os.path.join(out_dir, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("RENDERED", sc.render.filepath)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
    project = os.path.abspath(os.path.join(here, "..", ".."))
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(project, "assets", "weapons", "arrow.glb"))
    ap.add_argument("--renders", default=None)
    ap.add_argument("--blend", default=None)
    ap.add_argument("--atlas-png", default=None, help="also write the atlas texture here")
    args = ap.parse_args(argv)

    # Start from an empty scene.
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)

    obj = build_arrow(args.atlas_png)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print("ARROW TRIS", tris, "VERTS", len(obj.data.vertices))
    export_glb(obj, args.out)
    print("EXPORTED", args.out)
    if args.blend:
        bpy.ops.wm.save_as_mainfile(filepath=args.blend)
    if args.renders:
        render_previews(args.renders)


if __name__ == "__main__":
    main()
