"""The arena look board (the owner, 2026-10-16: "we can build a new and better arena with a headless blender"; "we don't
need the tree bark we can just build our own"): the Tidebreak ring built in Blender from data/ring/ring.json's own numbers
(the stock 1v1 ring: the 14 x 34 m deck, its 3 m stone face on piers, the tank 10 m round it with the water 6 m down, the
walk, the six tiers of stands, the end walls and their gates), dressed four ways and rendered headless (Eevee) for the owner
to pick from. Nothing third party: every material is Blender's own procedural nodes (brick, noise, voronoi), every prop a
primitive of this file. The rules' geometry is kept exactly (the deck's size, the lips, the water's level), so whichever
look wins can be exported for the game with the colliders RingArena already makes.

The looks (docs/tidebreak/team_formats_and_arenas.md "The look": original, Breath-of-the-Wild-like in spirit, water below
for the ring-outs):
  ruin      a plateau ruin over a lake (earth): sandstone slabs, mossy broken columns, terraced stone stands, a broken arch
  harbour   a harbour dock (water; the Treasure Planet 70/30 flavour): a timber deck on tarred pilings, masts and sailcloth
            awnings, lanterns, a ship's hull for each end wall, evening light
  crater    a crater rim over a crater lake (fire): basalt, glowing seams on the plinth, braziers on the pier heads, dusk
  cliff     a cliff-top over the sea (air): pale wind-worn stone, prayer-flag bunting, floating keelstone rocks, pines, haze

  Blender -b --factory-startup --python tools/environment/arena/arena_board.py -- --out <dir> [--looks ruin,harbour,crater,cliff]
      [--px 1600x900] [--samples 32] [--sheet]
  (through the slotted lock: zsh tools/loop/blender_run.sh -b --factory-startup --python ...)
Writes <dir>/<look>_wide.png (the broadcast's establishing view from over a corner) and <dir>/<look>_deck.png (low over the
deck, for the materials), and with --sheet <dir>/board.png, the eight side by side. Blender 5.2.
"""
import argparse
import math
import os
import random
import sys

import bpy
from mathutils import Vector

# ---------------------------------------------------------------- the ring's numbers (data/ring/ring.json, stock 1v1)
DECK_W = 14.0          # across (Blender Y)
DECK_L = 34.0          # along (Blender X: side 0 at -X, side 1 at +X)
NEUTRAL = 4.0
ZONE = 5.0
ZONES = 3
FACE_DEPTH = 3.0       # the deck's stone face down from its top
TANK_MARGIN = 10.0
WATER_Y = -6.0
FLOOR_Y = -9.0
TANK_WALL = 0.8
COPING_W = 0.25
COPING_PROUD = 0.04
PIER_EVERY = 4.25
PIER_W = 1.1
PIER_INSET = 1.2
LANTERN_POST_H = 1.7
LANTERN_OUT = 0.45
PLAZA_SIDE = 3.0
PLAZA_END = 4.0
TIERS = 6
TIER_D = 0.9
TIER_H = 0.5
BACK_H = 1.4
END_WALL_H = 4.6
END_WALL_T = 1.0

HALF_L = HALF_W = TANK_X = TANK_Y = WALK_Y = STANDS_Y1 = END_X = 0.0


def configure(w=14.0, l=34.0, zone=5.0, neutral=4.0, water_y=-2.0, floor_y=-5.0, face=1.9):
    """The deck's size and the water's depth under it (a format's: ring.json formats, modes.zones) and every number derived."""
    global DECK_W, DECK_L, ZONE, NEUTRAL, WATER_Y, FLOOR_Y, FACE_DEPTH
    global HALF_L, HALF_W, TANK_X, TANK_Y, WALK_Y, STANDS_Y1, END_X
    DECK_W, DECK_L, ZONE, NEUTRAL = w, l, zone, neutral
    WATER_Y, FLOOR_Y, FACE_DEPTH = water_y, floor_y, face
    HALF_L = DECK_L * 0.5
    HALF_W = DECK_W * 0.5
    TANK_X = HALF_L + TANK_MARGIN
    TANK_Y = HALF_W + TANK_MARGIN
    WALK_Y = TANK_Y + TANK_WALL + PLAZA_SIDE
    STANDS_Y1 = WALK_Y + TIERS * TIER_D
    END_X = TANK_X + TANK_WALL + PLAZA_END


configure()

R = random.Random(1778)
TILE_M = 4.0           # a baked texture tile covers this many metres (arena_build.py): the slab sizes divide it
## The variant's own (main sets them): the deck's shape ("rect" the rules' rectangle, "oval" an ellipse of the same length and
## width) and how far the water lies under it (the owner, 2026-10-16: "closer to the water maybe a oval shape").
SHAPE = "rect"


def inside(x, y, margin=0.0):
    """Whether (x, y) lies on the deck's top: within the rectangle, or the ellipse of the same half lengths (less margin)."""
    if SHAPE != "oval":
        return abs(x) <= HALF_L - margin and abs(y) <= HALF_W - margin
    a, b = HALF_L - margin, HALF_W - margin
    return (x / a) ** 2 + (y / b) ** 2 <= 1.0


def argv():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--out", required=True)
    p.add_argument("--looks", default="all")
    p.add_argument("--px", default="1600x900")
    p.add_argument("--samples", type=int, default=32)
    p.add_argument("--sheet", action="store_true")
    return p.parse_args(a)


# ---------------------------------------------------------------- meshes: boxes and quads gathered into one object a material
class Part:
    """Boxes, quads and cylinders gathered into one mesh with a per-face `tint` colour (the slab-to-slab spread the deck's
    looks ask for: ring.json looks.jitter), committed as one object with one material."""

    def __init__(self, name, mat, export=True):
        self.name = name
        self.mat = mat
        self.export = export
        self.v = []
        self.f = []
        self.c = []

    def _face(self, idx, tint):
        self.f.append(idx)
        self.c.append(tint)

    def box(self, ctr, size, tint=(1, 1, 1), rot_z=0.0):
        cx, cy, cz = ctr
        sx, sy, sz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
        c, s = math.cos(rot_z), math.sin(rot_z)
        base = len(self.v)
        for dx, dy, dz in [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]:
            x, y = dx * sx, dy * sy
            self.v.append((cx + x * c - y * s, cy + x * s + y * c, cz + dz * sz))
        for q in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
            self._face(tuple(base + i for i in q), tint)

    def quad(self, p0, p1, p2, p3, tint=(1, 1, 1)):
        base = len(self.v)
        self.v.extend([tuple(p0), tuple(p1), tuple(p2), tuple(p3)])
        self._face((base, base + 1, base + 2, base + 3), tint)

    def cylinder(self, ctr, r, h, n=12, tint=(1, 1, 1), r_top=None, z0=None):
        cx, cy, cz = ctr
        zb = cz if z0 is None else z0
        zt = zb + h
        rt = r if r_top is None else r_top
        base = len(self.v)
        for i in range(n):
            a = math.tau * i / n
            self.v.append((cx + r * math.cos(a), cy + r * math.sin(a), zb))
        for i in range(n):
            a = math.tau * i / n
            self.v.append((cx + rt * math.cos(a), cy + rt * math.sin(a), zt))
        for i in range(n):
            j = (i + 1) % n
            self._face((base + i, base + j, base + n + j, base + n + i), tint)
        self._face(tuple(base + n + i for i in range(n)), tint)
        self._face(tuple(base + i for i in reversed(range(n))), tint)

    def ellipse_prism(self, a, b, z0, h, n=72, tint=(1, 1, 1)):
        base = len(self.v)
        for i in range(n):
            t = math.tau * i / n
            self.v.append((a * math.cos(t), b * math.sin(t), z0))
        for i in range(n):
            t = math.tau * i / n
            self.v.append((a * math.cos(t), b * math.sin(t), z0 + h))
        for i in range(n):
            j = (i + 1) % n
            self._face((base + i, base + j, base + n + j, base + n + i), tint)
        self._face(tuple(base + n + i for i in range(n)), tint)
        self._face(tuple(base + i for i in reversed(range(n))), tint)

    def ellipse_ring(self, a, b, w, z0, h, n=72, tint=(1, 1, 1)):
        """A flat ring w wide inside the ellipse (a, b), h thick from z0."""
        for z, up in ((z0, False), (z0 + h, True)):
            base = len(self.v)
            for i in range(n):
                t = math.tau * i / n
                self.v.append((a * math.cos(t), b * math.sin(t), z))
                self.v.append(((a - w) * math.cos(t), (b - w) * math.sin(t), z))
            for i in range(n):
                j = (i + 1) % n
                q = (base + 2 * i, base + 2 * j, base + 2 * j + 1, base + 2 * i + 1)
                self._face(q if up else tuple(reversed(q)), tint)
        # the outer and inner faces
        base = len(self.v)
        for i in range(n):
            t = math.tau * i / n
            self.v.append((a * math.cos(t), b * math.sin(t), z0))
            self.v.append((a * math.cos(t), b * math.sin(t), z0 + h))
        for i in range(n):
            j = (i + 1) % n
            self._face((base + 2 * i, base + 2 * j, base + 2 * j + 1, base + 2 * i + 1), tint)

    def commit(self, scene):
        if not self.f:
            return None
        me = bpy.data.meshes.new(self.name)
        me.from_pydata(self.v, [], self.f)
        me.update()
        col = me.color_attributes.new(name="tint", type="FLOAT_COLOR", domain="CORNER")
        for poly, tint in zip(me.polygons, self.c):
            for li in poly.loop_indices:
                col.data[li].color = (tint[0], tint[1], tint[2], 1.0)
        me.materials.append(self.mat)
        # the UVs: each face projected along its own axis, TILE_M metres a tile (the baked textures' tile)
        uv = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            n = poly.normal
            ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
            for li in poly.loop_indices:
                p = me.vertices[me.loops[li].vertex_index].co
                if az >= ax and az >= ay:
                    u, v = p.x, p.y
                elif ax >= ay:
                    u, v = p.y, p.z
                else:
                    u, v = p.x, p.z
                uv.data[li].uv = (u / TILE_M, v / TILE_M)
        ob = bpy.data.objects.new(self.name, me)
        ob["export"] = self.export
        scene.collection.objects.link(ob)
        return ob


def jit(k):
    return 1.0 + R.uniform(-k, k)


def tint(rgb, k=0.0):
    j = jit(k)
    return (rgb[0] * j, rgb[1] * j, rgb[2] * j)


# ---------------------------------------------------------------- materials: Blender's own nodes, nothing loaded
def _nodes(mat):
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return nt, bsdf


def _coords(nt, wall=False, scale=1.0):
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.name = "coords_map"
    mp.inputs["Scale"].default_value = (scale, scale, scale)
    if wall:
        mp.inputs["Rotation"].default_value = (math.radians(90.0), 0.0, 0.0)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    return mp.outputs["Vector"]


def _tinted(nt, color_socket):
    """`color_socket` x the mesh's `tint` attribute."""
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "tint"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(color_socket, mix.inputs[6])
    nt.links.new(at.outputs["Color"], mix.inputs[7])
    return mix.outputs[2]


def stone(name, rgb, slab=(1.0, 1.0), mortar=0.03, rough=0.85, wall=False, noise=0.35, bump=0.45, emit=None):
    """Cut stone: a brick pattern of slabs (slab m wide and tall) with a dark joint, noise over the tone, a bumped face."""
    mat = bpy.data.materials.new(name)
    nt, bsdf = _nodes(mat)
    vec = _coords(nt, wall)
    br = nt.nodes.new("ShaderNodeTexBrick")
    br.offset = 0.5
    br.inputs["Scale"].default_value = 1.0
    br.inputs["Brick Width"].default_value = slab[0]
    br.inputs["Row Height"].default_value = slab[1]
    br.inputs["Mortar Size"].default_value = mortar
    br.inputs["Mortar Smooth"].default_value = 0.4
    br.inputs["Bias"].default_value = 0.0
    br.inputs["Color1"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    br.inputs["Color2"].default_value = (rgb[0] * 0.86, rgb[1] * 0.86, rgb[2] * 0.86, 1.0)
    br.inputs["Mortar"].default_value = (rgb[0] * 0.35, rgb[1] * 0.35, rgb[2] * 0.33, 1.0)
    nt.links.new(vec, br.inputs["Vector"])
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 3.5
    nz.inputs["Detail"].default_value = 6.0
    nz.inputs["Roughness"].default_value = 0.6
    nt.links.new(vec, nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (1.0 - noise, 1.0 - noise, 1.0 - noise, 1.0)
    ramp.color_ramp.elements[1].color = (1.0 + noise * 0.6, 1.0 + noise * 0.6, 1.0 + noise * 0.6, 1.0)
    nt.links.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(br.outputs["Color"], mix.inputs[6])
    nt.links.new(ramp.outputs["Color"], mix.inputs[7])
    nt.links.new(_tinted(nt, mix.outputs[2]), bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = bump
    bp.inputs["Distance"].default_value = 0.08
    nt.links.new(nz.outputs["Fac"], bp.inputs["Height"])
    nt.links.new(br.outputs["Fac"], bp.inputs["Normal"]) if False else None
    nt.links.new(bp.outputs["Normal"], bsdf.inputs["Normal"])
    if emit is not None:
        # (glowing seams: the joints lit, the slabs dark; crater's plinth)
        inv = nt.nodes.new("ShaderNodeMath")
        inv.operation = "SUBTRACT"
        inv.inputs[0].default_value = 1.0
        nt.links.new(br.outputs["Fac"], inv.inputs[1])
        # (only some joints glow: the noise picks them, so the seams read as cracks of heat, not a grid)
        gate = nt.nodes.new("ShaderNodeMath")
        gate.operation = "GREATER_THAN"
        gate.inputs[1].default_value = 0.56
        nt.links.new(nz.outputs["Fac"], gate.inputs[0])
        both = nt.nodes.new("ShaderNodeMath")
        both.operation = "MULTIPLY"
        nt.links.new(inv.outputs["Value"], both.inputs[0])
        nt.links.new(gate.outputs["Value"], both.inputs[1])
        bsdf.inputs["Emission Color"].default_value = (emit[0], emit[1], emit[2], 1.0)
        nt.links.new(both.outputs["Value"], bsdf.inputs["Emission Strength"])
    return mat


def earth(name, rgb, rough=0.95, scale=2.0, grit=0.3, bump=0.5):
    """Packed earth, sand or ash: no joints, a coarse and a fine noise over the tone, a gritty bump."""
    mat = bpy.data.materials.new(name)
    nt, bsdf = _nodes(mat)
    vec = _coords(nt)
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale
    nz.inputs["Detail"].default_value = 8.0
    nz.inputs["Roughness"].default_value = 0.7
    nt.links.new(vec, nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (rgb[0] * (1.0 - grit), rgb[1] * (1.0 - grit), rgb[2] * (1.0 - grit), 1.0)
    ramp.color_ramp.elements[1].color = (rgb[0] * (1.0 + grit * 0.5), rgb[1] * (1.0 + grit * 0.5), rgb[2] * (1.0 + grit * 0.5), 1.0)
    nt.links.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    vr = nt.nodes.new("ShaderNodeTexVoronoi")
    vr.inputs["Scale"].default_value = 18.0
    nt.links.new(vec, vr.inputs["Vector"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 0.25
    nt.links.new(ramp.outputs["Color"], mix.inputs[6])
    nt.links.new(vr.outputs["Color"], mix.inputs[7])
    nt.links.new(_tinted(nt, mix.outputs[2]), bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = bump
    bp.inputs["Distance"].default_value = 0.05
    nt.links.new(vr.outputs["Distance"], bp.inputs["Height"])
    nt.links.new(bp.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def planks(name, rgb, w=0.24, length=3.5, along_x=False, rough=0.7, wall=False):
    """Boards: a brick pattern of planks w wide and `length` long with staggered joints, a wood-grain noise along them."""
    mat = bpy.data.materials.new(name)
    nt, bsdf = _nodes(mat)
    vec = _coords(nt, wall)
    br = nt.nodes.new("ShaderNodeTexBrick")
    br.offset = 0.5
    br.inputs["Scale"].default_value = 1.0
    if along_x:
        br.inputs["Brick Width"].default_value = length
        br.inputs["Row Height"].default_value = w
        vin = vec
    else:
        # (the planks run across: the pattern turned a quarter)
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Rotation"].default_value = (0.0, 0.0, math.radians(90.0))
        nt.links.new(vec, mp.inputs["Vector"])
        vin = mp.outputs["Vector"]
        br.inputs["Brick Width"].default_value = length
        br.inputs["Row Height"].default_value = w
    br.inputs["Mortar Size"].default_value = 0.012
    br.inputs["Mortar Smooth"].default_value = 0.2
    br.inputs["Color1"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    br.inputs["Color2"].default_value = (rgb[0] * 0.8, rgb[1] * 0.8, rgb[2] * 0.78, 1.0)
    br.inputs["Mortar"].default_value = (rgb[0] * 0.3, rgb[1] * 0.28, rgb[2] * 0.25, 1.0)
    nt.links.new(vin, br.inputs["Vector"])
    gr = nt.nodes.new("ShaderNodeTexWave")
    gr.wave_type = "BANDS"
    gr.bands_direction = "X" if along_x else "Y"
    gr.inputs["Scale"].default_value = 18.0
    gr.inputs["Distortion"].default_value = 2.2
    gr.inputs["Detail"].default_value = 3.0
    nt.links.new(vec, gr.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.82, 0.8, 0.78, 1.0)
    ramp.color_ramp.elements[1].color = (1.08, 1.06, 1.04, 1.0)
    nt.links.new(gr.outputs["Fac"], ramp.inputs["Fac"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(br.outputs["Color"], mix.inputs[6])
    nt.links.new(ramp.outputs["Color"], mix.inputs[7])
    nt.links.new(_tinted(nt, mix.outputs[2]), bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = 0.25
    bp.inputs["Distance"].default_value = 0.03
    nt.links.new(gr.outputs["Fac"], bp.inputs["Height"])
    nt.links.new(bp.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def plain(name, rgb, rough=0.6, metallic=0.0, emit=None, emit_k=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    nt, bsdf = _nodes(mat)
    rgb4 = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Base Color"].default_value = rgb4
    nt.links.new(_tinted(nt, bsdf.inputs["Base Color"].links[0].from_socket if bsdf.inputs["Base Color"].links else _const(nt, rgb4)),
                 bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    if emit is not None:
        bsdf.inputs["Emission Color"].default_value = (emit[0], emit[1], emit[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit_k
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        try:
            mat.surface_render_method = "BLENDED"
        except Exception:
            mat.blend_method = "BLEND"
    return mat


def _const(nt, rgb4):
    n = nt.nodes.new("ShaderNodeRGB")
    n.outputs[0].default_value = rgb4
    return n.outputs[0]


def water(name, deep, shallow, rough=0.06, glow=None):
    """The tank's water: a glossy sheet, its tone between deep and shallow by a slow noise, waves bumped in."""
    mat = bpy.data.materials.new(name)
    nt, bsdf = _nodes(mat)
    vec = _coords(nt)
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 0.35
    nz.inputs["Detail"].default_value = 4.0
    nt.links.new(vec, nz.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (deep[0], deep[1], deep[2], 1.0)
    ramp.color_ramp.elements[1].color = (shallow[0], shallow[1], shallow[2], 1.0)
    nt.links.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Coat Weight"].default_value = 1.0
    wv = nt.nodes.new("ShaderNodeTexNoise")
    wv.inputs["Scale"].default_value = 2.2
    wv.inputs["Detail"].default_value = 7.0
    wv.inputs["Roughness"].default_value = 0.55
    nt.links.new(vec, wv.inputs["Vector"])
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = 0.12
    bp.inputs["Distance"].default_value = 0.05
    nt.links.new(wv.outputs["Fac"], bp.inputs["Height"])
    nt.links.new(bp.outputs["Normal"], bsdf.inputs["Normal"])
    if glow is not None:
        bsdf.inputs["Emission Color"].default_value = (glow[0], glow[1], glow[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = 0.25
    return mat


def cloth(name, rgb, stripe=None, rough=0.9):
    mat = bpy.data.materials.new(name)
    nt, bsdf = _nodes(mat)
    if stripe is None:
        nt.links.new(_tinted(nt, _const(nt, (rgb[0], rgb[1], rgb[2], 1.0))), bsdf.inputs["Base Color"])
    else:
        vec = _coords(nt)
        wv = nt.nodes.new("ShaderNodeTexWave")
        wv.wave_type = "BANDS"
        wv.bands_direction = "X"
        wv.wave_profile = "SAW"
        wv.inputs["Scale"].default_value = 1.6
        wv.inputs["Distortion"].default_value = 0.0
        nt.links.new(vec, wv.inputs["Vector"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        ramp.color_ramp.elements[0].color = (rgb[0], rgb[1], rgb[2], 1.0)
        ramp.color_ramp.elements[1].position = 0.5
        ramp.color_ramp.elements[1].color = (stripe[0], stripe[1], stripe[2], 1.0)
        nt.links.new(wv.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    mat.use_backface_culling = False
    return mat


# ---------------------------------------------------------------- the world and the light
def sky(scene, elevation_deg, rotation_deg, sun_rgb, sun_k, strength=1.0, turbidity=2.5, tint=None):
    """Blender's own sky (the Preetham model: the sun's height and the air's turbidity make the hour) as the world's light,
    with a sun lamp from the same direction for the shadows."""
    w = bpy.data.worlds.new("Sky")
    scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = strength
    st = nt.nodes.new("ShaderNodeTexSky")
    el = math.radians(elevation_deg)
    ro = math.radians(rotation_deg)
    d = Vector((-math.sin(ro) * math.cos(el), math.cos(ro) * math.cos(el), math.sin(el)))
    try:
        st.sky_type = "PREETHAM"
        st.sun_direction = d
        st.turbidity = turbidity
        st.ground_albedo = 0.25
    except Exception as e:
        print("sky texture:", e)
    if tint is None:
        nt.links.new(st.outputs["Color"], bg.inputs["Color"])
    else:
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        nt.links.new(st.outputs["Color"], mix.inputs[6])
        mix.inputs[7].default_value = (tint[0], tint[1], tint[2], 1.0)
        nt.links.new(mix.outputs[2], bg.inputs["Color"])
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = sun_k
    sun.color = sun_rgb
    sun.angle = math.radians(1.5 if elevation_deg > 20.0 else 3.0)
    sun.use_shadow = True
    so = bpy.data.objects.new("Sun", sun)
    scene.collection.objects.link(so)
    so.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    return so


def point_light(scene, at, rgb, k, radius=0.3):
    l = bpy.data.lights.new("Lamp", "POINT")
    l.energy = k
    l.color = rgb
    l.shadow_soft_size = radius
    l.use_shadow = False
    o = bpy.data.objects.new("Lamp", l)
    o.location = at
    scene.collection.objects.link(o)
    return o


# ---------------------------------------------------------------- the ring itself (the rules' geometry)
def zone_rects():
    """[(name, x0, x1)] along the deck: the neutral strip, then zone 1..3 of each side."""
    out = [("neutral", -NEUTRAL * 0.5, NEUTRAL * 0.5)]
    for k in range(1, ZONES + 1):
        a = NEUTRAL * 0.5 + (k - 1) * ZONE
        out.append(("s1_z%d" % k, a, a + ZONE))
        out.append(("s0_z%d" % k, -a - ZONE, -a))
    return out


def deck(scene, mats, jitter=0.07, slab=1.0, plank_w=0.24, boards=True):
    """The deck top laid zone by zone (the zone change is the line: ring.json looks), as slabs or planks a little uneven."""
    for name, x0, x1 in zone_rects():
        zk = "neutral" if name == "neutral" else "zone_%s" % name[-1]
        mat, kind = mats[zk]
        part = Part("deck_" + name, mat)
        if kind in ("stone", "earth", "cobble") or not boards:
            sl = {"stone": slab, "earth": 0.5, "cobble": 0.5}.get(kind, slab)
            gap = {"stone": 0.012, "earth": 0.0, "cobble": 0.006}.get(kind, 0.012)
            n_x = max(1, round((x1 - x0) / sl))
            n_y = max(1, round(DECK_W / sl))
            sx = (x1 - x0) / n_x
            sy = DECK_W / n_y
            for i in range(n_x):
                for j in range(n_y):
                    cx = x0 + (i + 0.5) * sx
                    cy = -HALF_W + (j + 0.5) * sy
                    if not inside(cx, cy):
                        continue
                    h = 0.1 + R.uniform(-0.008, 0.012) * (0.4 if kind == "earth" else 1.0)
                    part.box((cx, cy, -0.05 + (h - 0.1) * 0.5), (sx - gap, sy - gap, h), tint((1, 1, 1), jitter if kind != "earth" else jitter * 0.4))
        else:
            along_x = kind == "boards_x"
            if along_x:
                # planks running along the deck, in rows across it
                n_rows = max(1, round(DECK_W / plank_w))
                pw = DECK_W / n_rows
                for j in range(n_rows):
                    cy = -HALF_W + (j + 0.5) * pw
                    x = x0 - R.uniform(0.0, 2.5)
                    while x < x1:
                        ln = R.uniform(2.0, 3.0)
                        a, b = max(x, x0), min(x + ln, x1)
                        if b - a > 0.05 and inside((a + b) * 0.5, cy):
                            part.box(((a + b) * 0.5, cy, -0.05), (b - a - 0.01, pw - 0.012, 0.1 + R.uniform(-0.006, 0.006)), tint((1, 1, 1), jitter))
                        x += ln
            else:
                n_cols = max(1, round((x1 - x0) / plank_w))
                pw = (x1 - x0) / n_cols
                for i in range(n_cols):
                    cx = x0 + (i + 0.5) * pw
                    y = -HALF_W - R.uniform(0.0, 3.0)
                    while y < HALF_W:
                        ln = R.uniform(3.0, 4.0)
                        a, b = max(y, -HALF_W), min(y + ln, HALF_W)
                        if b - a > 0.05 and inside(cx, (a + b) * 0.5):
                            part.box((cx, (a + b) * 0.5, -0.05), (pw - 0.012, b - a - 0.01, 0.1 + R.uniform(-0.006, 0.006)), tint((1, 1, 1), jitter))
                        y += ln
        part.commit(scene)


def plinth(scene, mat, mat_pier, pilings=False):
    """The deck's stone face, 3 m down from its top on every side, and the piers under it to the tank's floor."""
    p = Part("face", mat)
    if SHAPE == "oval":
        p.ellipse_prism(HALF_L + 0.01, HALF_W + 0.01, -0.1 - FACE_DEPTH, FACE_DEPTH, tint=(1, 1, 1))
    else:
        p.box((0, 0, -0.1 - FACE_DEPTH * 0.5), (DECK_L + 0.02, DECK_W + 0.02, FACE_DEPTH), (1, 1, 1))
    p.commit(scene)
    q = Part("piers", mat_pier)
    n = int((DECK_L - 2 * PIER_INSET) / PIER_EVERY)
    xs = [-HALF_L + PIER_INSET + PIER_W * 0.5 + i * PIER_EVERY for i in range(n + 1)]
    h = FACE_DEPTH + 0.1
    for x in xs:
        for y in (-HALF_W + PIER_INSET, HALF_W - PIER_INSET):
            if not inside(x, y, 0.6):
                continue
            if pilings:
                for dx, dy in [(-0.35, -0.35), (0.35, -0.35), (-0.35, 0.35), (0.35, 0.35)]:
                    q.cylinder((x + dx, y + dy, FLOOR_Y), 0.22, -FLOOR_Y - h, n=10, tint=tint((1, 1, 1), 0.08))
            else:
                q.box((x, y, (FLOOR_Y - h) * 0.5), (PIER_W, PIER_W, -FLOOR_Y - h + 0.05), tint((1, 1, 1), 0.05))
    q.commit(scene)
    return xs


GRATE_W = 1.0          # along the deck
GRATE_L = 2.0          # across it
GRATE_Z = (4.0, -4.0)


def grates(scene, mat_iron, mat_well):
    """The iron grates over wells on each zone line of each side (ring.json grates: a waterbender draws water there), two a
    line at GRATE_Z: the one deck feature every look keeps, as the rules read it."""
    g = Part("grates", mat_iron)
    w = Part("wells", mat_well)
    for k in range(ZONES):
        s = NEUTRAL * 0.5 + k * ZONE
        for sx in (-1, 1):
            for y in GRATE_Z:
                x = sx * s
                w.box((x, y, -0.4), (GRATE_W + 0.2, GRATE_L + 0.2, 0.7), (1, 1, 1))
                # the bars: along the long way, a frame round them
                g.box((x, y, -0.02), (GRATE_W + 0.16, 0.08, 0.06))
                g.box((x, y + GRATE_L * 0.5, -0.02), (GRATE_W + 0.16, 0.08, 0.06))
                g.box((x, y - GRATE_L * 0.5, -0.02), (GRATE_W + 0.16, 0.08, 0.06))
                g.box((x - GRATE_W * 0.5, y, -0.02), (0.08, GRATE_L + 0.08, 0.06))
                g.box((x + GRATE_W * 0.5, y, -0.02), (0.08, GRATE_L + 0.08, 0.06))
                n = 7
                for i in range(1, n):
                    g.box((x - GRATE_W * 0.5 + i * GRATE_W / n, y, -0.02), (0.04, GRATE_L, 0.05))
    g.commit(scene)
    w.commit(scene)


def curtain(scene, mat, up=3.0):
    """The stock ring's edge: a curtain of water falling from a rim channel `up` m over the deck, round the tank's inner edge,
    down to the water (touching it is out: ring.json modes.stock.curtain). A translucent sheet here."""
    c = Part("curtain", mat, export=False)
    x, y = TANK_X, TANK_Y
    zt, zb = up, WATER_Y + 0.2
    c.quad((-x, -y, zt), (x, -y, zt), (x, -y, zb), (-x, -y, zb))
    c.quad((x, y, zt), (-x, y, zt), (-x, y, zb), (x, y, zb))
    c.quad((x, -y, zt), (x, y, zt), (x, y, zb), (x, -y, zb))
    c.quad((-x, y, zt), (-x, -y, zt), (-x, -y, zb), (-x, y, zb))
    c.commit(scene)
    r = Part("rim", mat)
    r.box((0, -y, zt + 0.15), (2 * x + 0.3, 0.6, 0.3), (0.8, 0.85, 0.9))
    r.box((0, y, zt + 0.15), (2 * x + 0.3, 0.6, 0.3), (0.8, 0.85, 0.9))
    r.box((x, 0, zt + 0.15), (0.6, 2 * y + 0.3, 0.3), (0.8, 0.85, 0.9))
    r.box((-x, 0, zt + 0.15), (0.6, 2 * y + 0.3, 0.3), (0.8, 0.85, 0.9))
    r.commit(scene)


def falling_water(name, rgb, alpha=0.4):
    """The curtain's sheet: streaks of a wave texture falling, see-through."""
    mat = bpy.data.materials.new(name)
    nt, bsdf = _nodes(mat)
    vec = _coords(nt)
    wv = nt.nodes.new("ShaderNodeTexWave")
    wv.wave_type = "BANDS"
    wv.bands_direction = "Z"
    wv.inputs["Scale"].default_value = 0.6
    wv.inputs["Distortion"].default_value = 6.0
    wv.inputs["Detail"].default_value = 4.0
    nt.links.new(vec, wv.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (rgb[0] * 0.7, rgb[1] * 0.75, rgb[2] * 0.8, 1.0)
    ramp.color_ramp.elements[1].color = (0.95, 0.97, 1.0, 1.0)
    nt.links.new(wv.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.25
    bsdf.inputs["Alpha"].default_value = alpha
    try:
        mat.surface_render_method = "BLENDED"
    except Exception:
        mat.blend_method = "BLEND"
    mat.use_backface_culling = False
    return mat


def coping(scene, mat):
    c = Part("coping", mat)
    w = COPING_W
    z = COPING_PROUD * 0.5
    t = 0.1 + COPING_PROUD
    if SHAPE == "oval":
        c.ellipse_ring(HALF_L, HALF_W, w, z - 0.05 + 0.02 - t * 0.5, t)
        c.commit(scene)
        return
    c.box((0, HALF_W - w * 0.5, z - 0.05 + 0.02), (DECK_L, w, t), (1, 1, 1))
    c.box((0, -HALF_W + w * 0.5, z - 0.05 + 0.02), (DECK_L, w, t), (1, 1, 1))
    c.box((HALF_L - w * 0.5, 0, z - 0.05 + 0.02), (w, DECK_W, t), (1, 1, 1))
    c.box((-HALF_L + w * 0.5, 0, z - 0.05 + 0.02), (w, DECK_W, t), (1, 1, 1))
    c.commit(scene)


def tank(scene, mat_wall, mat_floor, mat_water, cliff=False):
    """The tank: its floor, its walls up to the walk, the water WATER_Y down."""
    t = Part("tank", mat_wall)
    tw = TANK_WALL
    ox, oy = TANK_X + tw, TANK_Y + tw
    hz = -FLOOR_Y
    t.box((0, oy - tw * 0.5, FLOOR_Y + hz * 0.5), (2 * ox, tw, hz), (1, 1, 1))
    t.box((0, -oy + tw * 0.5, FLOOR_Y + hz * 0.5), (2 * ox, tw, hz), (1, 1, 1))
    t.box((ox - tw * 0.5, 0, FLOOR_Y + hz * 0.5), (tw, 2 * oy, hz), (1, 1, 1))
    t.box((-ox + tw * 0.5, 0, FLOOR_Y + hz * 0.5), (tw, 2 * oy, hz), (1, 1, 1))
    if cliff:
        # (a rough rock face inside the walls: the tank as a cove)
        for i in range(60):
            a = R.uniform(0, math.tau)
            x = R.choice([-1, 1]) * R.uniform(HALF_L + 3.0, TANK_X - 0.6) if R.random() < 0.5 else R.uniform(-TANK_X + 0.6, TANK_X - 0.6)
            y = R.uniform(-TANK_Y + 0.6, TANK_Y - 0.6) if abs(x) > HALF_L + 3.0 else R.choice([-1, 1]) * R.uniform(HALF_W + 3.0, TANK_Y - 0.6)
            t.box((x, y, FLOOR_Y + R.uniform(0.5, 2.5)), (R.uniform(1.0, 2.6), R.uniform(1.0, 2.6), R.uniform(1.0, 4.0)), tint((1, 1, 1), 0.1), rot_z=a)
    t.commit(scene)
    f = Part("floor", mat_floor)
    f.box((0, 0, FLOOR_Y - 0.25), (2 * ox, 2 * oy, 0.5), (1, 1, 1))
    f.commit(scene)
    w = Part("water", mat_water, export=False)
    w.quad((-TANK_X, -TANK_Y, WATER_Y), (TANK_X, -TANK_Y, WATER_Y), (TANK_X, TANK_Y, WATER_Y), (-TANK_X, TANK_Y, WATER_Y))
    w.commit(scene)


def surround(scene, mat_walk, mat_tier, mat_back, mat_end, grass=None):
    """The flagged walk at the deck's height round the tank, the tiers of stands along both long sides, a wall across each end."""
    s = Part("walk", mat_walk)
    ox = TANK_X + TANK_WALL
    oy = TANK_Y + TANK_WALL
    # the long walks and the end walks, 0.5 m thick with their top at the deck's height
    s.box((0, oy + PLAZA_SIDE * 0.5, -0.25), (2 * END_X, PLAZA_SIDE, 0.5), (1, 1, 1))
    s.box((0, -oy - PLAZA_SIDE * 0.5, -0.25), (2 * END_X, PLAZA_SIDE, 0.5), (1, 1, 1))
    s.box((ox + PLAZA_END * 0.5, 0, -0.25), (PLAZA_END, 2 * oy, 0.5), (1, 1, 1))
    s.box((-ox - PLAZA_END * 0.5, 0, -0.25), (PLAZA_END, 2 * oy, 0.5), (1, 1, 1))
    # the ground under everything, down to the tank floor's level outside the tank
    s.box((0, 0, FLOOR_Y - 0.5), (2 * END_X + 2 * END_WALL_T + 40.0, 2 * STANDS_Y1 + 40.0, 0.2), tint((0.7, 0.7, 0.7), 0.0))
    s.commit(scene)
    t = Part("tiers", mat_tier)
    for i in range(TIERS):
        y0 = WALK_Y + i * TIER_D
        z = i * TIER_H
        t.box((0, y0 + TIER_D * 0.5, z + TIER_H * 0.5), (2 * END_X, TIER_D, TIER_H + 0.02), tint((1, 1, 1), 0.03))
        t.box((0, -y0 - TIER_D * 0.5, z + TIER_H * 0.5), (2 * END_X, TIER_D, TIER_H + 0.02), tint((1, 1, 1), 0.03))
        # (the tiers' fill below, so nothing is hollow from the walk)
        t.box((0, y0 + TIER_D * 0.5, z * 0.5 - 0.25), (2 * END_X, TIER_D, z + 0.5), (1, 1, 1))
        t.box((0, -y0 - TIER_D * 0.5, z * 0.5 - 0.25), (2 * END_X, TIER_D, z + 0.5), (1, 1, 1))
    t.commit(scene)
    b = Part("back", mat_back)
    zt = TIERS * TIER_H
    b.box((0, STANDS_Y1 + 0.3, zt + BACK_H * 0.5), (2 * END_X, 0.6, BACK_H), (1, 1, 1))
    b.box((0, -STANDS_Y1 - 0.3, zt + BACK_H * 0.5), (2 * END_X, 0.6, BACK_H), (1, 1, 1))
    b.box((0, STANDS_Y1 + 0.3, zt * 0.5), (2 * END_X, 0.6, zt), (1, 1, 1))
    b.box((0, -STANDS_Y1 - 0.3, zt * 0.5), (2 * END_X, 0.6, zt), (1, 1, 1))
    b.commit(scene)
    if grass is not None:
        g = Part("grass", grass)
        g.box((0, STANDS_Y1 + 6.0, 0.6), (2 * END_X + 2 * END_WALL_T, 11.0, 1.2), (1, 1, 1))
        g.box((0, -STANDS_Y1 - 6.0, 0.6), (2 * END_X + 2 * END_WALL_T, 11.0, 1.2), (1, 1, 1))
        g.commit(scene)
    e = Part("end_walls", mat_end)
    for sx in (-1, 1):
        x = sx * (END_X + END_WALL_T * 0.5)
        yw = STANDS_Y1 + 0.6
        # the wall, with the gate's tunnel cut out of its middle
        gw, gh = 4.2, 3.6
        e.box((x, (yw + gw * 0.5) * 0.5, END_WALL_H * 0.5), (END_WALL_T, yw - gw * 0.5, END_WALL_H), (1, 1, 1))
        e.box((x, -(yw + gw * 0.5) * 0.5, END_WALL_H * 0.5), (END_WALL_T, yw - gw * 0.5, END_WALL_H), (1, 1, 1))
        e.box((x, 0, gh + (END_WALL_H - gh) * 0.5), (END_WALL_T, gw, END_WALL_H - gh), (1, 1, 1))
        # two towers either side of the gate
        for sy in (-1, 1):
            e.box((x, sy * (gw * 0.5 + 1.3), (END_WALL_H + 2.2) * 0.5), (END_WALL_T + 1.6, 2.6, END_WALL_H + 2.2), tint((1, 1, 1), 0.03))
    e.commit(scene)


def lanterns(scene, mat_post, mat_glow, pier_xs, lit, rgb=(1.0, 0.7, 0.38), brazier=False):
    """Lantern posts on the pier heads just outside the lip (ring.json lanterns), lit at night."""
    p = Part("lantern_posts", mat_post, export=brazier)
    g = Part("lantern_glow", mat_glow, export=brazier)
    spots = []
    if SHAPE == "oval":
        n = 2 * len(pier_xs)
        for i in range(n):
            t = math.tau * (i + 0.5) / n
            spots.append(((HALF_L + LANTERN_OUT) * math.cos(t), (HALF_W + LANTERN_OUT) * math.sin(t)))
    else:
        for x in pier_xs:
            for sy in (-1, 1):
                spots.append((x, sy * (HALF_W + LANTERN_OUT)))
    for x, y in spots:
        if True:
            if brazier:
                p.cylinder((x, y, -FACE_DEPTH - 0.1), 0.45, FACE_DEPTH + 0.1 + 0.6, n=8)
                p.cylinder((x, y, 0.6), 0.55, 0.5, n=10, r_top=0.7)
                g.cylinder((x, y, 1.05), 0.42, 0.9, n=8, r_top=0.05)
                if lit:
                    point_light(scene, (x, y, 1.6), rgb, 400.0, 0.4)
            else:
                p.cylinder((x, y, -FACE_DEPTH - 0.1), 0.18, FACE_DEPTH + 0.1 + LANTERN_POST_H, n=8)
                p.box((x, y, LANTERN_POST_H + 0.25), (0.5, 0.5, 0.08))
                g.box((x, y, LANTERN_POST_H + 0.0), (0.34, 0.34, 0.42))
                if lit:
                    point_light(scene, (x, y, LANTERN_POST_H), rgb, 180.0, 0.25)
    p.commit(scene)
    g.commit(scene)


# ---------------------------------------------------------------- the four looks' own props
def columns(scene, mat, mossy=None):
    """Ruined columns along the walks and the stands' back: broken at random heights, a capital on the whole ones."""
    c = Part("columns", mat)
    places = []
    ox = TANK_X + TANK_WALL + 1.2
    for x in range(-18, 19, 9):
        for sy in (-1, 1):
            places.append((x, sy * (TANK_Y + TANK_WALL + 1.0), 0.0))
    for sx in (-1, 1):
        for y in (-9.0, 9.0):
            places.append((sx * (ox + 1.0), y, 0.0))
    for i, (x, y, z) in enumerate(places):
        h = R.choice([5.5, 6.0, 2.2, 3.4, 6.0, 1.6])
        c.cylinder((x, y, z), 0.5, 0.35, n=8, tint=tint((1, 1, 1), 0.05))
        c.cylinder((x, y, z + 0.35), 0.42, h, n=10, tint=tint((1, 1, 1), 0.05), r_top=0.4 if h > 5.0 else R.uniform(0.3, 0.42))
        if h > 5.0:
            c.box((x, y, z + 0.35 + h + 0.2), (1.2, 1.2, 0.4), tint((1, 1, 1), 0.04))
    c.commit(scene)
    if mossy is not None:
        m = Part("moss", mossy)
        for i in range(40):
            x = R.uniform(-END_X, END_X)
            y = R.choice([-1, 1]) * R.uniform(TANK_Y + TANK_WALL, WALK_Y - 0.3)
            m.box((x, y, 0.01), (R.uniform(0.8, 2.4), R.uniform(0.6, 1.6), 0.02), tint((1, 1, 1), 0.15), rot_z=R.uniform(0, 3.0))
        for i in range(14):
            x = R.uniform(-HALF_L + 1.0, HALF_L - 1.0)
            y = R.choice([-1, 1]) * R.uniform(HALF_W - 1.4, HALF_W - 0.4)
            m.box((x, y, 0.05), (R.uniform(0.3, 0.9), R.uniform(0.25, 0.6), 0.015), tint((1, 1, 1), 0.15), rot_z=R.uniform(0, 3.0))
        m.commit(scene)


def lily_pads(scene, mat):
    l = Part("lilies", mat)
    for i in range(70):
        x = R.uniform(-TANK_X + 1.0, TANK_X - 1.0)
        y = R.choice([-1, 1]) * R.uniform(HALF_W + 1.5, TANK_Y - 1.0) if abs(x) < HALF_L else R.uniform(-TANK_Y + 1.0, TANK_Y - 1.0)
        l.cylinder((x, y, WATER_Y + 0.01), R.uniform(0.3, 0.7), 0.02, n=9, tint=tint((1, 1, 1), 0.12))
    l.commit(scene)


def broken_arches(scene, mat):
    a = Part("arches", mat)
    for sx in (-1, 1):
        x = sx * (END_X + END_WALL_T * 0.5)
        for sy in (-1, 1):
            a.cylinder((x, sy * 2.6, END_WALL_H), 0.5, 2.4, n=8)
        a.box((x, 1.6, END_WALL_H + 2.6), (1.2, 2.4, 0.5))
        a.box((x, -2.0, END_WALL_H + 2.6), (1.2, 1.4, 0.5))
    a.commit(scene)


def masts_and_sails(scene, mat_mast, mat_sail, mat_rope):
    """Masts behind the stands' back with sailcloth awnings slung over the top tiers, stays to the walk."""
    m = Part("masts", mat_mast)
    s = Part("sails", mat_sail)
    r = Part("stays", mat_rope)
    zt = TIERS * TIER_H + BACK_H
    for x in range(-20, 21, 10):
        for sy in (-1, 1):
            y = sy * (STANDS_Y1 + 1.4)
            m.cylinder((x, y, 0.0), 0.22, zt + 7.0, n=8, r_top=0.14)
            m.box((x, y, zt + 7.2), (0.3, 4.0, 0.18), rot_z=0.0)
            # the awning: a sheet from the mast's yard down over the stands toward the walk
            y1 = sy * (WALK_Y + 1.0)
            for k in range(2):
                dx = (k - 0.5) * 9.4
                s.quad((x + dx - 4.6, y, zt + 6.6), (x + dx + 4.6, y, zt + 6.6), (x + dx + 4.2, y1, zt + 2.2), (x + dx - 4.2, y1, zt + 2.2),
                       tint((1, 1, 1), 0.04))
            r.cylinder((x, y, 0.3), 0.025, 1.0, n=5)
    m.commit(scene)
    s.commit(scene)
    r.commit(scene)


def bollards_and_barrels(scene, mat_iron, mat_wood):
    b = Part("bollards", mat_iron)
    w = Part("barrels", mat_wood)
    for x in range(-24, 25, 6):
        for sy in (-1, 1):
            b.cylinder((x, sy * (TANK_Y + TANK_WALL + 0.5), 0.0), 0.2, 0.6, n=8, r_top=0.25)
    for i in range(16):
        x = R.uniform(-END_X + 1.0, END_X - 1.0)
        y = R.choice([-1, 1]) * R.uniform(TANK_Y + TANK_WALL + 1.2, WALK_Y - 0.5)
        w.cylinder((x, y, 0.0), 0.36, 0.9, n=10, tint=tint((1, 1, 1), 0.08))
    b.commit(scene)
    w.commit(scene)


def hull_ends(scene, mat_hull, mat_rail):
    """A ship's hull section for each end wall: the strakes stepping out over the gate, a rail along the top."""
    h = Part("hulls", mat_hull)
    r = Part("hull_rails", mat_rail)
    for sx in (-1, 1):
        x = sx * (END_X + END_WALL_T * 0.5)
        yw = STANDS_Y1 + 0.6
        for i in range(7):
            z = 0.6 + i * 0.75
            out = 0.55 + i * 0.22
            h.box((x + sx * out * 0.5, 0, z), (END_WALL_T + out, 2 * yw + 2.0, 0.78), tint((1, 1, 1), 0.06))
        z = 0.6 + 7 * 0.75
        for y in range(-int(yw), int(yw) + 1, 2):
            r.cylinder((x + sx * 1.6, y, z), 0.06, 1.1, n=6)
        r.box((x + sx * 1.6, 0, z + 1.1), (0.14, 2 * yw + 2.0, 0.12))
    h.commit(scene)
    r.commit(scene)


def basalt_cliffs(scene, mat):
    """Basalt columns clustered along the outside of the end walls and behind the stands: the crater's rim."""
    b = Part("basalt", mat)
    for i in range(140):
        side = R.random()
        if side < 0.5:
            x = R.choice([-1, 1]) * R.uniform(END_X + END_WALL_T + 0.5, END_X + 9.0)
            y = R.uniform(-STANDS_Y1 - 4.0, STANDS_Y1 + 4.0)
        else:
            x = R.uniform(-END_X - 8.0, END_X + 8.0)
            y = R.choice([-1, 1]) * R.uniform(STANDS_Y1 + 1.0, STANDS_Y1 + 9.0)
        h = R.uniform(2.0, 9.0)
        b.cylinder((x, y, -0.5), R.uniform(0.5, 1.1), h, n=6, tint=tint((1, 1, 1), 0.12))
    b.commit(scene)


def lava_pools(scene, mat):
    p = Part("lava", mat)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((sx * (TANK_X - 4.0), sy * (TANK_Y - 3.5), FLOOR_Y + 0.05), (5.0, 4.0, 0.1))
    p.commit(scene)


def bunting(scene, mats, poles_mat, height=9.0):
    """Prayer-flag strings between tall poles at the walk's four corners, crossing high over the tank's corners."""
    p = Part("poles", poles_mat)
    parts = [Part("flags_%d" % i, m) for i, m in enumerate(mats)]
    ox = END_X - 1.0
    oy = WALK_Y - 0.6
    corners = [(-ox, -oy), (ox, -oy), (ox, oy), (-ox, oy)]
    for x, y in corners:
        p.cylinder((x, y, 0.0), 0.12, height, n=6, r_top=0.08)
    mid = [(0.0, 0.0, height - 2.0)]
    strings = []
    for (x0, y0) in corners:
        strings.append(((x0, y0, height - 0.2), (0.0, 0.0, height + 1.0)))
    strings.append(((-ox, -oy, height - 0.2), (ox, -oy, height - 0.2)))
    strings.append(((-ox, oy, height - 0.2), (ox, oy, height - 0.2)))
    for a, b in strings:
        a, b = Vector(a), Vector(b)
        n = int((b - a).length / 1.1)
        for i in range(n):
            t = (i + 0.5) / n
            sag = 1.6 * math.sin(math.pi * t)
            c = a.lerp(b, t)
            c.z -= sag
            d = (b - a).normalized()
            w = Vector((0, 0, -1))
            k = parts[i % len(parts)]
            k.quad((c - d * 0.3), (c + d * 0.3), (c + d * 0.3 + w * 0.5), (c - d * 0.3 + w * 0.5), tint((1, 1, 1), 0.06))
    p.commit(scene)
    for k in parts:
        k.commit(scene)
    # the string itself
    s = Part("strings", poles_mat)
    for a, b in strings:
        a, b = Vector(a), Vector(b)
        n = 24
        for i in range(n):
            t0, t1 = i / n, (i + 1) / n
            c0, c1 = a.lerp(b, t0), a.lerp(b, t1)
            c0.z -= 1.6 * math.sin(math.pi * t0)
            c1.z -= 1.6 * math.sin(math.pi * t1)
            m = (c0 + c1) * 0.5
            s.box((m.x, m.y, m.z), ((c1 - c0).length, 0.03, 0.03), rot_z=math.atan2(c1.y - c0.y, c1.x - c0.x))
    s.commit(scene)


def floating_rocks(scene, mat_rock, mat_glow):
    r = Part("keelstones", mat_rock)
    g = Part("keel_glow", mat_glow)
    for i in range(10):
        x = R.uniform(-END_X - 6.0, END_X + 6.0)
        y = R.choice([-1, 1]) * R.uniform(STANDS_Y1 + 4.0, STANDS_Y1 + 16.0)
        z = R.uniform(5.0, 13.0)
        sz = R.uniform(1.4, 3.4)
        r.box((x, y, z), (sz, sz * R.uniform(0.7, 1.2), sz * R.uniform(0.6, 0.9)), tint((1, 1, 1), 0.08), rot_z=R.uniform(0, 3.0))
        r.box((x, y, z - sz * 0.45), (sz * 0.6, sz * 0.6, sz * 0.5), tint((1, 1, 1), 0.08), rot_z=R.uniform(0, 3.0))
        g.box((x, y, z - sz * 0.72), (sz * 0.5, sz * 0.5, 0.12), (1, 1, 1))
    r.commit(scene)
    g.commit(scene)


def pines(scene, mat_trunk, mat_leaf):
    t = Part("trunks", mat_trunk)
    l = Part("needles", mat_leaf)
    for i in range(26):
        x = R.choice([-1, 1]) * R.uniform(END_X + 3.0, END_X + 16.0)
        y = R.uniform(-STANDS_Y1 - 6.0, STANDS_Y1 + 6.0)
        h = R.uniform(5.0, 10.0)
        lean = R.uniform(0.0, 0.5)
        t.cylinder((x, y, 0.0), 0.28, h * 0.45, n=6, r_top=0.2)
        for k in range(3):
            z = h * (0.3 + 0.2 * k)
            l.cylinder((x + lean * k, y, z), (1.9 - 0.4 * k) * h / 7.0, h * 0.26, n=7, r_top=0.05, tint=tint((1, 1, 1), 0.1))
    t.commit(scene)
    l.commit(scene)


# ---------------------------------------------------------------- the looks
def look_ruin(scene):
    mats = {
        "neutral": (earth("packed_earth", (0.6, 0.46, 0.32)), "earth"),
        "zone_1": (stone("sandstone", (0.86, 0.68, 0.5), (1.0, 1.0)), "stone"),
        "zone_2": (earth("red_clay", (0.58, 0.34, 0.22), grit=0.25), "earth"),
        "zone_3": (stone("slate", (0.42, 0.5, 0.58), (1.0, 1.0)), "stone"),
    }
    deck(scene, mats)
    face = stone("face_blocks", (0.72, 0.64, 0.52), (1.333, 0.8), mortar=0.045, wall=True)
    xs = plinth(scene, face, stone("pier_blocks", (0.62, 0.58, 0.5), (1.0, 0.8), wall=True))
    coping(scene, plain("coping", (0.89, 0.87, 0.8), rough=0.7))
    grates(scene, plain("iron_r", (0.16, 0.15, 0.14), rough=0.55, metallic=0.5), plain("well_r", (0.05, 0.08, 0.08)))
    tank(scene, stone("tank_wall", (0.5, 0.52, 0.5), (1.333, 0.8), wall=True), stone("tank_floor", (0.3, 0.33, 0.3), (1.333, 1.333)),
         water("lake", (0.03, 0.12, 0.11), (0.16, 0.36, 0.3), rough=0.08))
    curtain(scene, falling_water("mist", (0.75, 0.85, 0.85), alpha=0.16))
    surround(scene, stone("flags", (0.7, 0.65, 0.55), (1.333, 1.333), mortar=0.035), stone("tiers", (0.66, 0.6, 0.5), (1.333, 0.5), wall=True),
             stone("back", (0.66, 0.62, 0.52), (1.333, 0.667), wall=True), stone("end_wall", (0.6, 0.54, 0.44), (1.6, 0.7), mortar=0.05, wall=True),
             grass=plain("grass", (0.3, 0.46, 0.2), rough=1.0))
    lanterns(scene, plain("post", (0.3, 0.26, 0.22)), plain("lamp", (0.9, 0.8, 0.6), emit=(1.0, 0.75, 0.4), emit_k=2.0), xs, lit=False)
    columns(scene, stone("column", (0.68, 0.62, 0.5), (1.0, 1.0), mortar=0.03, wall=True), mossy=plain("moss", (0.26, 0.42, 0.18), rough=1.0))
    lily_pads(scene, plain("lily", (0.22, 0.42, 0.2), rough=0.8))
    broken_arches(scene, stone("arch", (0.7, 0.65, 0.54), (1.0, 0.667), wall=True))
    sky(scene, 48.0, 150.0, (1.0, 0.94, 0.84), 5.5, strength=0.45, turbidity=2.0)


def look_harbour(scene):
    mats = {
        "neutral": (earth("wet_sand", (0.72, 0.64, 0.48), grit=0.2), "earth"),
        "zone_1": (stone("cobbles", (0.5, 0.48, 0.44), (0.5, 0.5), mortar=0.05), "cobble"),
        "zone_2": (earth("dark_sand", (0.4, 0.36, 0.3), grit=0.3), "earth"),
        "zone_3": (stone("wet_flags", (0.3, 0.32, 0.33), (1.0, 1.0), rough=0.5), "stone"),
    }
    deck(scene, mats)
    xs = plinth(scene, planks("hull_face", (0.3, 0.24, 0.18), w=0.3, length=4.0, along_x=True, wall=True),
                plain("piling", (0.16, 0.13, 0.1), rough=0.9), pilings=True)
    coping(scene, planks("rail", (0.58, 0.46, 0.3), w=0.25, length=3.0, along_x=True))
    grates(scene, plain("iron_h", (0.14, 0.13, 0.12), rough=0.55, metallic=0.5), plain("well_h", (0.03, 0.06, 0.06)))
    tank(scene, stone("quay", (0.42, 0.44, 0.42), (1.4, 0.6), wall=True), stone("harbour_floor", (0.2, 0.22, 0.2), (1.0, 1.0)),
         water("harbour", (0.02, 0.07, 0.08), (0.08, 0.22, 0.22), rough=0.05))
    curtain(scene, falling_water("spray", (0.6, 0.72, 0.72), alpha=0.14))
    surround(scene, planks("quay_boards", (0.5, 0.42, 0.32), w=0.3, length=3.0, along_x=True), planks("tier_boards", (0.52, 0.42, 0.3), w=0.3, length=3.0, along_x=True, wall=True),
             planks("back_boards", (0.36, 0.3, 0.24), w=0.3, length=3.0, along_x=True, wall=True), planks("hull_wall", (0.26, 0.2, 0.15), w=0.35, length=4.0, along_x=False, wall=True))
    lanterns(scene, plain("post_h", (0.2, 0.17, 0.14)), plain("lamp_h", (1.0, 0.85, 0.6), emit=(1.0, 0.7, 0.35), emit_k=12.0), xs, lit=True)
    masts_and_sails(scene, plain("mast", (0.34, 0.27, 0.2), rough=0.8), cloth("sailcloth", (0.86, 0.8, 0.68), stripe=(0.62, 0.22, 0.18)), plain("rope", (0.5, 0.42, 0.3)))
    bollards_and_barrels(scene, plain("iron", (0.12, 0.12, 0.13), rough=0.5, metallic=0.6), planks("barrel", (0.44, 0.33, 0.22), w=0.12, length=0.9, along_x=False, wall=True))
    hull_ends(scene, planks("hull_strakes", (0.22, 0.17, 0.13), w=0.75, length=5.0, along_x=False, wall=True), plain("hull_rail", (0.5, 0.4, 0.28)))
    sky(scene, 7.0, 250.0, (1.0, 0.62, 0.36), 3.6, strength=0.5, turbidity=4.5)


def look_crater(scene):
    mats = {
        "neutral": (earth("ash", (0.4, 0.37, 0.35), grit=0.3), "earth"),
        "zone_1": (stone("basalt_warm", (0.32, 0.26, 0.22), (1.0, 1.0), mortar=0.04), "stone"),
        "zone_2": (earth("cinder", (0.22, 0.15, 0.12), grit=0.4), "earth"),
        "zone_3": (stone("basalt_dark", (0.14, 0.13, 0.13), (1.0, 1.0), mortar=0.04), "stone"),
    }
    deck(scene, mats, jitter=0.1)
    face = stone("face_seams", (0.14, 0.13, 0.13), (1.333, 0.667), mortar=0.06, wall=True, emit=(0.5, 0.14, 0.02))
    xs = plinth(scene, face, stone("pier_basalt", (0.16, 0.15, 0.15), (0.667, 0.667), wall=True))
    coping(scene, plain("coping_c", (0.5, 0.46, 0.42), rough=0.7))
    grates(scene, plain("iron_c", (0.2, 0.17, 0.15), rough=0.5, metallic=0.5), plain("well_c", (0.3, 0.08, 0.02), emit=(1.0, 0.3, 0.05), emit_k=3.0))
    tank(scene, stone("crater_wall", (0.17, 0.15, 0.14), (1.333, 1.0), wall=True), stone("crater_floor", (0.12, 0.1, 0.09), (1.0, 1.0)),
         water("crater_lake", (0.05, 0.03, 0.03), (0.3, 0.12, 0.06), rough=0.04, glow=(0.9, 0.3, 0.08)), cliff=True)
    curtain(scene, falling_water("steam", (0.5, 0.42, 0.4), alpha=0.16))
    surround(scene, stone("rim_flags", (0.3, 0.28, 0.27), (1.333, 1.333), mortar=0.04), stone("rim_tiers", (0.22, 0.2, 0.19), (1.333, 0.5), wall=True),
             stone("rim_back", (0.18, 0.17, 0.16), (1.333, 0.667), wall=True), stone("rim_end", (0.2, 0.18, 0.17), (1.6, 0.7), mortar=0.05, wall=True))
    lanterns(scene, plain("brazier", (0.14, 0.12, 0.11), metallic=0.4), plain("flame", (0.9, 0.4, 0.08), emit=(0.9, 0.3, 0.04), emit_k=2.5), xs, lit=True,
             rgb=(1.0, 0.45, 0.15), brazier=True)
    basalt_cliffs(scene, stone("basalt_rim", (0.15, 0.14, 0.14), (0.667, 0.667), wall=True))
    lava_pools(scene, plain("lava", (1.0, 0.3, 0.05), emit=(1.0, 0.28, 0.04), emit_k=8.0))
    sky(scene, 3.0, 110.0, (1.0, 0.45, 0.25), 2.2, strength=0.4, turbidity=7.0, tint=(1.0, 0.5, 0.45))


def look_cliff(scene):
    mats = {
        "neutral": (earth("chalk_earth", (0.78, 0.74, 0.62), grit=0.2), "earth"),
        "zone_1": (stone("limestone", (0.84, 0.82, 0.74), (1.0, 1.0), mortar=0.03), "stone"),
        "zone_2": (earth("turf", (0.46, 0.54, 0.3), grit=0.3), "earth"),
        "zone_3": (stone("grey_slate", (0.46, 0.52, 0.58), (1.0, 1.0)), "stone"),
    }
    deck(scene, mats)
    xs = plinth(scene, stone("cliff_face", (0.72, 0.7, 0.64), (1.333, 0.8), mortar=0.05, wall=True), stone("cliff_pier", (0.6, 0.58, 0.54), (1.0, 0.8), wall=True))
    coping(scene, plain("coping_w", (0.93, 0.92, 0.88), rough=0.7))
    grates(scene, plain("iron_w", (0.22, 0.22, 0.22), rough=0.55, metallic=0.5), plain("well_w", (0.04, 0.1, 0.12)))
    tank(scene, stone("cove_rock", (0.46, 0.46, 0.44), (2.0, 1.0), mortar=0.06, wall=True, noise=0.4), stone("sea_floor", (0.3, 0.34, 0.34), (1.0, 1.0)),
         water("sea", (0.04, 0.2, 0.28), (0.3, 0.62, 0.66), rough=0.06), cliff=True)
    curtain(scene, falling_water("sea_mist", (0.8, 0.9, 0.95), alpha=0.13))
    surround(scene, stone("pale_flags", (0.74, 0.72, 0.64), (1.333, 1.333), mortar=0.035), stone("pale_tiers", (0.7, 0.68, 0.6), (1.333, 0.5), wall=True),
             stone("pale_back", (0.7, 0.68, 0.62), (1.333, 0.667), wall=True), stone("pale_end", (0.74, 0.72, 0.64), (1.6, 0.7), mortar=0.05, wall=True),
             grass=plain("thin_grass", (0.42, 0.5, 0.28), rough=1.0))
    lanterns(scene, plain("post_w", (0.36, 0.34, 0.3)), plain("lamp_w", (0.95, 0.95, 0.9), emit=(0.8, 0.9, 1.0), emit_k=1.5), xs, lit=False)
    bunting(scene, [cloth("flag_blue", (0.2, 0.42, 0.8)), cloth("flag_white", (0.92, 0.92, 0.9)), cloth("flag_red", (0.8, 0.2, 0.16)),
                    cloth("flag_green", (0.2, 0.6, 0.3)), cloth("flag_yellow", (0.9, 0.75, 0.2))], plain("pole", (0.3, 0.28, 0.24)))
    floating_rocks(scene, stone("keelstone", (0.5, 0.5, 0.48), (0.8, 0.8), wall=True), plain("keel_glow", (0.6, 0.9, 1.0), emit=(0.5, 0.85, 1.0), emit_k=6.0))
    pines(scene, plain("trunk", (0.3, 0.22, 0.16)), plain("needles", (0.16, 0.34, 0.22), rough=1.0))
    sky(scene, 55.0, 215.0, (1.0, 0.98, 0.95), 5.0, strength=0.5, turbidity=1.8)


LOOKS = {"ruin": look_ruin, "harbour": look_harbour, "crater": look_crater, "cliff": look_cliff}


# ---------------------------------------------------------------- the scene, the cameras, the renders
def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras, bpy.data.worlds, bpy.data.images):
        for d in list(coll):
            if d.users == 0:
                coll.remove(d)


def camera(scene, at, look, lens=32.0):
    cam = bpy.data.cameras.new("Cam")
    cam.lens = lens
    cam.clip_end = 600.0
    o = bpy.data.objects.new("Cam", cam)
    o.location = at
    d = Vector(look) - Vector(at)
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(o)
    scene.camera = o
    return o


def setup_render(scene, px, samples):
    scene.render.engine = "BLENDER_EEVEE"
    w, h = [int(v) for v in px.split("x")]
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    scene.render.resolution_percentage = 100
    ev = scene.eevee
    ev.taa_render_samples = samples
    for k, v in [("use_shadows", True), ("use_raytracing", True), ("use_volumetric_shadows", False)]:
        try:
            setattr(ev, k, v)
        except Exception:
            pass
    try:
        ev.ray_tracing_options.resolution_scale = "2"
    except Exception:
        pass
    for vt, look in (("Filmic", "Medium High Contrast"), ("AgX", "AgX - Medium High Contrast")):
        try:
            scene.view_settings.view_transform = vt
            scene.view_settings.look = look
            break
        except Exception:
            continue
    scene.view_settings.exposure = -0.35
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False


def render(scene, path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("WROTE", path)


def sheet(out, looks):
    """The renders on one board (a look's wide view, then its deck), through Blender's own image buffers."""
    import numpy as np
    tiles = []
    for lk in looks:
        for view in ("wide", "deck"):
            p = os.path.join(out, "%s_%s.png" % (lk, view))
            if os.path.exists(p):
                im = bpy.data.images.load(p)
                w, h = im.size
                a = np.array(im.pixels[:]).reshape(h, w, 4)
                tiles.append((lk, view, a[::-1]))
    if not tiles:
        return
    h, w = tiles[0][2].shape[0], tiles[0][2].shape[1]
    cols = 2
    rows = (len(tiles) + 1) // 2
    board = np.zeros((rows * h, cols * w, 4), dtype=np.float32)
    board[:, :, 3] = 1.0
    for i, (lk, view, a) in enumerate(tiles):
        r, c = i // cols, i % cols
        board[r * h:(r + 1) * h, c * w:(c + 1) * w] = a
    img = bpy.data.images.new("board", cols * w, rows * h, alpha=True)
    img.pixels = board[::-1].ravel().tolist()
    img.filepath_raw = os.path.join(out, "board.png")
    img.file_format = "PNG"
    img.save()
    print("WROTE", img.filepath_raw)


VARIANTS = [
    ("oval_ruin", "ruin", "oval"), ("oval_harbour", "harbour", "oval"), ("oval_crater", "crater", "oval"),
    ("oval_cliff", "cliff", "oval"), ("rect_ruin", "ruin", "rect"),
]


def main():
    global SHAPE, FACE_DEPTH, WATER_Y, FLOOR_Y
    a = argv()
    os.makedirs(a.out, exist_ok=True)
    want = [s.strip() for s in a.looks.split(",")]
    done = []
    for name, lk, shape in VARIANTS:
        if a.looks != "all" and name not in want and lk not in want:
            continue
        R.seed(1778)
        clear()
        SHAPE = shape
        # (the owner, 2026-10-16: "closer to the water": the deck 2 m over it, its face that deep, the tank's floor 3 m under)
        FACE_DEPTH = 1.9
        WATER_Y = -2.0
        FLOOR_Y = -5.0
        scene = bpy.context.scene
        setup_render(scene, a.px, a.samples)
        LOOKS[lk](scene)
        print("BUILT", name, len(bpy.data.objects), "objects")
        camera(scene, (44.0, -36.0, 24.0), (2.0, 2.0, -1.0), lens=30.0)
        render(scene, os.path.join(a.out, "%s_wide.png" % name))
        if shape == "oval":
            camera(scene, (-21.0, -11.0, 4.2), (6.0, 1.0, 0.2), lens=35.0)
            render(scene, os.path.join(a.out, "%s_deck.png" % name))
        done.append(name)
    if a.sheet:
        sheet(a.out, done)


if __name__ == "__main__":
    main()
