"""Procedural player body + 18th-century frontier outfit for the Actor_B rig.

Run headless on a COPY of the Actor_B rig library (the script never saves the
opened file and refuses to run on the original):

  cp .../source/blender_libraries/Actor_B_001.blend /tmp/rig_copy.blend
  Blender -b /tmp/rig_copy.blend --python tools/character/build_body.py -- \
      [--out assets/character/actor_b_body.glb] [--previews DIR] [--save-blend FILE]

or simply `tools/character/build_body.sh [--previews DIR]`, which makes the
copy in a temp dir first.

What it does
------------
1. Poses the rig in the bind pose `null-add` (the game's additive identity,
   appended read-only from Actor_B_021.blend). Unkeyed channels stay at the
   rig rest, exactly as Godot's deterministic mixer evaluates the clip.
   Its joint positions equal the rig rest (0.0 mm on the body bones), but
   the bone ORIENTATIONS are those of the animation data (up to 180 deg away
   from the rest), which is what the skin must be bound to.
2. Builds every mesh as a signed-distance field shaped around the posed joint
   positions (smooth unions of round cones / ellipsoids / boxes), polygonised
   with surface nets (OpenVDB voxel remesh where sheets touch), projected
   back onto the exact surface, QEM-decimated and then isotropically remeshed
   toward a sizing field (fine where visible, e.g. face and hands; coarse where
   hidden under clothing) so joints get even triangles that bend cleanly:
     Body   one smooth-shaded skin mesh (head, neck, mitten hands with thumbs,
            feet), of which only the visible skin is kept (head, neck, hands)
     Face   eyes (sclera, iris cap, upper and lower lids), brows, lips
     Hair   hair cap + a slim queue, ribbon wrap with two tails lying on it
     Clothes linen shirt (stock, sleeves, cuffs), waistcoat + buttons,
            hunting frock (shoulder cape, turned cuffs, mid-thigh length, open
            front, flat split back skirt with side pleats), buckskin breeches
            with a fall front, wool leggings with side flaps and garters,
            buckled shoes
     Gear   leather belt + buckle, crossed straps, shot pouch, powder horn
     Hat    felt tricorn
3. Weights (max 4 per vertex, normalised) go to the main deform bones of the
   `root` hierarchy (pelvis, legs, spine, neck, heada/headb, clavicles, arms,
   palm, finger chains) and to 21 rig helper bones that the clips never animate
   and the game drives at runtime (HELPERS; CharacterBodyMesh in
   scripts/player/character_body.gd): upper-arm swing/twist bones and a
   half-swing armpit bone, forearm roll bones, coat-skirt panel bones and a hair
   queue pendulum. Body weights: per body region, inverse distance to
   joint-to-child-joint segments (NOT Blender bone tails: in this rig the
   edit-bone tails do not follow the limbs), knee and elbow re-split by a plane
   through the joint, then smoothed over the mesh. Clothing copies the weights of
   the nearest body point, except the coat skirt (pelvis -> skirt panel helpers by
   height and angle), hat/eyes (rigid headb), hair queue (pendulum), garters
   (rigid shin), brass fittings (rigid per piece), horn/pouch (rigid pelvis) and
   belt/straps (the coat's weights at the centre line of the band, averaged along
   it, spine chain on two bones: the leather never changes width). The torso parts
   of coat, waistcoat and shirt copy from the body's torso/neck only, never from
   the arms that hang next to the ribs in the A-pose (torso_from_torso), and the
   inner layers under the coat
   then take the coat's weights where it covers them (follow_coat). Last, the
   shoulder / elbow weights of every layer are spread over the twist helpers by
   position (helper_weights).
   Hidden surfaces are then deleted (skin under the clothes, shirt and waistcoat
   under the coat) and the coat gets vertex-colour shading (coat_shading).
4. Exports a glb (+Y up) containing an armature "Actor_B" whose REST POSE IS
   THE null-add BIND POSE (all 291 bones, same names/hierarchy), so the glTF
   inverse bind matrices are inverse(null-add global) in Godot space, i.e.
   exactly the binds from the probe (bind_pose_util.gd `make_skin`). Mesh
   vertices are in skeleton space (Godot: Y up, facing +Z).

Godot side: scripts/player/character_body.gd (CharacterBodyMesh.attach) puts the
meshes under the game's Actor_B Skeleton3D, rebuilds the Skin from the null-add
clip (bind = G_nulladd[name].orthonormalized().affine_inverse(), see the sidecar
json) and drives the helper bones every frame. The binds never use the rest, so
they are valid for any rest.

Previews: `--previews DIR` renders the bind pose (front/side/back) and a few
game clips. For clips, a second copy of the export rig follows the original
rig bone-by-bone (Copy Transforms, world space) and unkeyed channels are
pre-set to their null-add values, which reproduces what Godot does after the
rest change. The helper bones are set by drive_helpers(), a Python twin of the
game's driver (previews only; the game uses CharacterBodyMesh). Its results for a
few reference poses go into the sidecar json ("driver_reference"), and
tools/character/check_body_attach.gd checks that the game's driver gives the same.

Provenance: the skeleton, bone names and bind pose come from the Actor_B rig.
The body and clothing geometry are generated here.

The generic code moved to tools/character/lib (lib v1) without changes; the output
of this script is unchanged.
"""

import argparse
import json
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

# The generic code (SDF, remeshing, rig, body shape, weights, helper-bone table and its
# Python twin, previews) lives in tools/character/lib, shared with the customizer's
# generators (build_character.py). This file keeps the legacy outfit of actor_b_body.glb.
from lib.body_shapes import *  # noqa: E402,F401,F403
from lib.body_shapes import forearm_param as _forearm_param  # noqa: E402
from lib.helpers import *  # noqa: E402,F401,F403
from lib.preview import *  # noqa: E402,F401,F403
from lib.remesh import *  # noqa: E402,F401,F403
from lib.remesh import _perp  # noqa: E402
from lib.rig import *  # noqa: E402,F401,F403
from lib.sdf import *  # noqa: E402,F401,F403
from lib.sdf import set_log_tag  # noqa: E402
from lib.weights import *  # noqa: E402,F401,F403

set_log_tag("build_body")


# ===========================================================================
# Outfit shapes (18th-century frontier ranger)
# ===========================================================================


# front opening half-width of the coat (z -> |x|); below the belt the skirts part
COAT_OPEN_Z = [0.40, 0.47, 0.62, 0.80, 0.90, 0.95, 1.05, 1.18, 1.26, 1.34, 1.50]
COAT_OPEN_W = [0.135, 0.125, 0.10, 0.065, 0.040, 0.028, 0.030, 0.042, 0.050, 0.060, 0.07]
# skirt cross-section by height: an ellipse in front, flattening toward a superellipse
# (exponent SKIRT_BACK_N at the hem) across the back, so the back reads as one flat
# panel with square hem corners; A-line: the hem is ~6 cm wider than the seat.
# Mid-thigh hunting-frock length (the hem 8 cm above the knee-length coat of before):
# less mass to hang in a squat.
SKIRT_Z = [0.51, 0.60, 0.75, 0.85, 0.93, 0.99]
SKIRT_A = [0.246, 0.236, 0.212, 0.190, 0.162, 0.150]
SKIRT_B = [0.182, 0.174, 0.155, 0.142, 0.118, 0.110]
SKIRT_C = [0.008, 0.009, 0.010, 0.012, 0.006, 0.004]
SKIRT_BACK_N = 3.2
# Side pleats of the skirt (period frock coats are pleated at the hips): folds between
# these angles from the front centre (deg), count, depth (m, half peak-to-valley), from
# below the hip to the hem. They give the tails cloth structure instead of a smooth bag.
SKIRT_PLEATS = (96.0, 134.0, 3, 0.0042)     # depth < half the shell: the lining never pokes out
SKIRT_HEM, SKIRT_TOP = 0.525, 0.975
SKIRT_FRONT_RISE = 0.06      # front hem 6 cm above the back (skirt_hem_z)
SKIRT_VENT_TOP = 0.80        # the back vent splits the skirt below this height
BELT_Z = (0.922, 0.962)


def skirt_form():
    def f(X, Y, Z):
        a = np.interp(Z, SKIRT_Z, SKIRT_A)
        b = np.interp(Z, SKIRT_Z, SKIRT_B)
        c = np.interp(Z, SKIRT_Z, SKIRT_C)
        n = 2.0 + (SKIRT_BACK_N - 2.0) * smoothstep(0.86, 0.62, Z) * (Y > c)
        r = (np.abs(X / a) ** n + np.abs((Y - c) / b) ** n) ** (1.0 / n)
        return (r - 1.0) * np.minimum(a, b) - skirt_pleat(X, Y, Z)
    return Fn(f, (-0.27, -0.21, SKIRT_HEM - 0.05), (0.27, 0.21, SKIRT_TOP + 0.05))


def skirt_pleat(X, Y, Z):
    """Outward offset (m) of the skirt surface from the side pleats (SKIRT_PLEATS):
    ridges and valleys around the body, fading in below the hip."""
    a0, a1, count, depth = SKIRT_PLEATS
    c = np.interp(Z, SKIRT_Z, SKIRT_C)
    ang = np.degrees(np.arctan2(np.abs(X), -(Y - c)))
    w = smoothstep(a0 - 8.0, a0 + 2.0, ang) * (1 - smoothstep(a1 - 2.0, a1 + 8.0, ang)) * smoothstep(0.83, 0.70, Z)
    return depth * w * np.cos((ang - a0) / (a1 - a0) * count * 2.0 * np.pi)


def coat_front_opening():
    def f(X, Y, Z):
        w = np.interp(Z, COAT_OPEN_Z, COAT_OPEN_W)
        return np.maximum(np.abs(X) - w, Y + 0.02)
    return Fn(f, (-0.3, -0.4, 0.3), (0.3, -0.02, 1.6))


def coat_back_split():
    def f(X, Y, Z):
        w = 0.004 + 0.002 * smoothstep(SKIRT_HEM + 0.10, SKIRT_HEM, Z)     # a narrow, straight vent
        return np.maximum(np.maximum(np.abs(X) - w, 0.02 - Y), Z - SKIRT_VENT_TOP)
    return Fn(f, (-0.1, 0.02, 0.3), (0.1, 0.4, SKIRT_VENT_TOP))


def skirt_slab():
    """Height range of the skirt shell: from the sloped hem (skirt_hem_z) to 0.90."""
    def f(X, Y, Z):
        return np.maximum(skirt_hem_z(X, Y) - Z, Z - 0.90)
    return Fn(f, (-2, -2, SKIRT_HEM), (2, 2, 0.90))


def neck_hole(K, r):
    nk, ha = K["neck"], K["heada"]
    return RoundCone(v3(0, nk[1] + 0.012, nk[2] - 0.07), v3(0, ha[1] + 0.012, ha[2] + 0.12), 0.049 + r, 0.049 + r)


def coat_torso_shapes(K):
    """The torso the coat is cut around: torso_shapes(smooth) with the anatomy bridged,
    so the wool hangs over it instead of shrink-wrapping pectorals, shoulder blades, lats
    and the spine groove: a fuller chest plate and back plate over the ribcage, blended
    with a wide radius."""
    sb, sd = K["spineb"], K["spined"]
    chest = Ellipsoid(v3(0, sd[1] - 0.030, sd[2] - 0.035), (0.134, 0.062, 0.125))     # over the pectorals
    back = Ellipsoid(v3(0, sd[1] + 0.028, sd[2] - 0.015), (0.142, 0.080, 0.175))      # ribcage to shoulder blades
    waist = Ellipsoid(v3(0, sb[1] + 0.027, sb[2] - 0.005), (0.128, 0.090, 0.125))     # less taper under the ribs
    return Union([torso_shapes(K, smooth=True), Union([chest, back, waist], k=0.06)], k=0.05)


def coat_torso_form(K, off):
    """Solid coat body: torso offset (no neck tube) plus a hip filler that
    merges with the top of the skirt, so no thin air gaps remain."""
    torso = Inter(Offset(coat_torso_shapes(K), off), zslab(0.88, 1.40))
    filler = Inter(Offset(skirt_form(), 0.0033), zslab(0.88, SKIRT_TOP))     # inside the skirt wall: no coincident faces
    return Union([torso, filler], k=0.012)


COAT_OFF, SLEEVE_OFF, CAPE_OFF = 0.015, 0.012, 0.023
# Coat sleeve end and turned-back cuff (fraction of elbow -> wrist), and the end of the
# shirt sleeve: about 2.5 cm of linen shows at the wrist.
SLEEVE_END, CUFF_T0, SHIRT_END = 0.82, 0.645, 0.935
CAPE_Z = 1.168                # lower edge of the shoulder cape


def coat_node(K):
    torso = coat_torso_form(K, COAT_OFF)
    sleeves = []
    for s in (1, -1):
        t, E, fa, L = forearm_t(K, s)
        arm = arm_shapes(K, s)
        sleeve = Inter(Offset(arm, SLEEVE_OFF), cut_plane(E + fa * SLEEVE_END * L, -fa))
        cuff = Inter(Offset(arm, SLEEVE_OFF + 0.009), Fn(lambda X, Y, Z, t=t: np.maximum(CUFF_T0 - t(X, Y, Z), t(X, Y, Z) - SLEEVE_END - 0.012) * L,
                                                        *_arm_box(K, s)))
        sleeves.append(Union([sleeve, cuff], k=0.004))
    body = SymUnion(torso, sleeves[0], sleeves[1], k=0.03)
    skirt = Inter(Onion(skirt_form(), 0.0045), skirt_slab())
    # short shoulder cape over the coat: a straight edge (CAPE_Z) that is rounded and
    # blended into the coat, so the remesher has no thin step to zigzag along (it read as a
    # torn seam); coat_shading darkens a band at the edge instead
    cape = Inter(Inter(cape_base(K), Fn(lambda X, Y, Z: CAPE_Z - Z, (-0.3, -0.3, CAPE_Z - 0.03), (0.3, 0.3, 1.5)), k=0.006),
                 zslab(1.10, 1.40))
    collar = Inter(Offset(neck_shape(K), 0.021), zslab(1.27, 1.345))
    coat = Union([Union([body, cape], k=0.008), skirt, collar], k=0.0)
    return Sub(Sub(Sub(coat, coat_front_opening()), coat_back_split()), neck_hole(K, 0.008))


def cape_base(K):
    return Offset(SymUnion(coat_torso_shapes(K), _deltoid(K, 1), _deltoid(K, -1), k=0.04), CAPE_OFF)


def _deltoid(K, s):
    S = K.side("shoulder", s)
    return Sphere(S + v3(s * 0.007, 0.002, 0.004), 0.042)


def _arm_box(K, s):
    pts = np.array([K.side(n, s) for n in ("shoulder", "elbow", "wrist", "palm")])
    return pts.min(0) - 0.08, pts.max(0) + 0.08


def cloth_torso(K):
    """Torso + neck base shape for the shirt (the neck part becomes the stock)."""
    return Union([torso_shapes(K, smooth=True), neck_shape(K)], k=0.05)


def shirt_node(K):
    torso = Inter(Offset(cloth_torso(K), 0.005), zslab(1.02, 1.352))
    sleeves = []
    for s in (1, -1):
        t, E, fa, L = forearm_t(K, s)
        W = K.side("wrist", s)
        r = lambda X, Y, Z, t=t: 0.006 + 0.0035 * smoothstep(0.75, 0.93, t(X, Y, Z))
        sl = Inter(Offset(arm_shapes(K, s), r, r_max=0.0095), cut_plane(E + fa * SHIRT_END * L, -fa))
        sleeves.append(sl)
    return SymUnion(torso, sleeves[0], sleeves[1], k=0.02)


def waistcoat_node(K):
    base = Offset(torso_shapes(K, smooth=True), 0.010)

    def hem(X, Y, Z):
        return (0.905 + 0.22 * Y) - Z
    wc = Inter(Inter(base, Fn(hem, (-0.3, -0.3, 0.85), (0.3, 0.3, 1.45))), zslab(0.85, 1.36))
    wc = Inter(wc, xband(0.138))

    def v_neck(X, Y, Z):
        w = 0.004 + np.maximum(Z - 1.16, 0.0) * 0.40
        return np.maximum(np.maximum(np.abs(X) - w, 1.16 - Z), Y + 0.01)
    wc = Sub(wc, Fn(v_neck, (-0.2, -0.3, 1.1), (0.2, -0.01, 1.5)))
    return Sub(wc, neck_hole(K, 0.004))


def breeches_node(K, body):
    """Buckskin breeches with a plain fall front: the groin is bridged by a smooth panel
    between the thighs (no anatomy shows through), a little fuller at the seat."""
    hc = (K["l_upper_leg"] + mirror_x(K["l_upper_leg"])) * 0.5
    fall = Ellipsoid(hc + v3(0, -0.028, -0.065), (0.080, 0.045, 0.080))     # front flush with the thighs
    seat = Ellipsoid(hc + v3(0, 0.050, -0.040), (0.130, 0.070, 0.090))
    base = Union([body, Union([fall, seat], k=0.02)], k=0.025)
    return Inter(Inter(Offset(base, 0.010), zslab(0.43, 1.0)), xband(0.26))


def legging_radius(X, Y, Z):
    return np.interp(Z, [0.07, 0.14, 0.40, 0.55, 0.64], [0.018, 0.013, 0.014, 0.017, 0.019])


def leggings_node(K, body):
    leg = Inter(Inter(Offset(body, legging_radius, r_max=0.019), zslab(0.075, 0.625)), xband(0.26))
    flaps = []
    for s in (1, -1):
        H, Kn, A = K.side("upper_leg", s), K.side("knee", s), K.side("ankle", s)
        out = v3(s, 0, 0)
        up_axis = nrm(Kn - H)
        lo_axis = nrm(A - Kn)
        R1 = frame_from(up_axis, out)
        R2 = frame_from(lo_axis, out)
        flaps.append(Union([
            RoundBox(lerp(Kn, H, 0.25) + out * 0.078 + v3(0, 0.004, 0), (0.022, 0.0028, 0.085), 0.0025, R1),
            RoundBox(lerp(Kn, A, 0.47) + out * 0.058 + v3(0, 0.008, 0), (0.020, 0.0028, 0.205), 0.0025, R2),
        ], k=0.01))
    return SymUnion(leg, flaps[0], flaps[1], k=0.008)


GARTER_Z = (0.396, 0.416)     # 5-7 cm below the knee joint (z 0.468): rigid on the shin


def garters_node(K, body):
    """Below-knee garter bands, close over the leggings (offset 18.5 mm vs about 14),
    with a small knot and two short ties lying along the outer side of the leg."""
    band = Inter(Inter(Offset(body, 0.0185), zslab(*GARTER_Z)), xband(0.26))
    ties = []
    zc = 0.5 * (GARTER_Z[0] + GARTER_Z[1])
    for s in (1, -1):
        kn = K.side("knee", s)
        base = surface_point(band, v3(s * 0.30, kn[1] - 0.004, zc), v3(-s, 0, 0), 0.0, 0.30 - abs(kn[0]))
        base = base + v3(s * 0.002, 0, 0)
        ties.append(Union([Sphere(base, 0.0065),
                           RoundCone(base, base + v3(s * 0.001, -0.006, -0.030), 0.0034, 0.0026),
                           RoundCone(base, base + v3(s * 0.001, 0.007, -0.026), 0.0034, 0.0026)], k=0.003))
    return SymUnion(band, ties[0], ties[1], k=0.003)


def shoes_node(K):
    feet = [Offset(foot_shapes(K, s), 0.0072) for s in (1, -1)]
    tongue = []
    for s in (1, -1):
        A, B = K.side("ankle", s), K.side("ball", s)
        c = v3(A[0], A[1] - 0.052, 0.085)
        tongue.append(RoundBox(c, (0.026, 0.006, 0.022), 0.005, frame_from(v3(0, -0.45, 1), v3(1, 0, 0))))
    shoes = Union([Union([f, t], k=0.012) for f, t in zip(feet, tongue)], k=0)
    return Inter(shoes, zslab(0.0, 0.092))


def belt_node(K):
    return Inter(Onion(Offset(coat_torso_form(K, COAT_OFF), 0.0055), 0.003), zslab(*BELT_Z))


def strap_plane(s):
    """(point, unit normal) of the mid plane of the s-side strap."""
    p0 = v3(s * 0.085, 0.02, 1.345)
    p1 = v3(-s * 0.20, 0.005, 0.915)
    return p0, nrm(np.cross(p1 - p0, v3(0, 1, 0)))


STRAP_OFF, STRAP_WIDTH = 0.0068, 0.013
_STRAP_PATHS = {}


def strap_path(K, s, n=56):
    """Centre line of the s-side strap: the loop where its mid plane (strap_plane) meets
    the strap's mid surface around the torso, as n points."""
    if s not in _STRAP_PATHS:
        form = Offset(coat_torso_form(K, COAT_OFF), STRAP_OFF)
        p0, n_ = strap_plane(s)
        p1 = v3(-s * 0.20, 0.005, 0.915)
        a = nrm(np.cross(v3(0, 1, 0), n_))                     # in the plane, across the torso
        c0 = 0.5 * (p0 + p1) * v3(1, 0, 1)
        pts = []
        for th in np.linspace(0.0, 2 * np.pi, n, endpoint=False):
            d = a * math.cos(th) + v3(0, 1, 0) * math.sin(th)
            pts.append(surface_point(form, c0 + d * 0.45, -d, 0.0, 0.45))
        _STRAP_PATHS[s] = np.array(pts)
    return _STRAP_PATHS[s]


def strap_node(K, s, width=STRAP_WIDTH):
    """Strap from the s-side shoulder across the body to the opposite hip, front and back
    (over the coat): the part of a thin shell over the coat within `width` of the strap's
    centre line, so it keeps its width where it wraps round the side of the torso (a slab
    through the torso made wide flaps there)."""
    P = strap_path(K, s)
    tube = Union([RoundCone(P[i], P[(i + 1) % len(P)], width, width) for i in range(len(P))], k=0.0)
    form = Offset(coat_torso_form(K, COAT_OFF), STRAP_OFF)
    return Inter(Inter(Onion(form, 0.003), tube), zslab(0.93, 1.45))


def pouch_node(K):
    c = v3(0.203, 0.030, 0.878)
    R = frame_from(v3(0, 0.25, 1), v3(1, -0.12, 0))      # local x ~ outward, z ~ up
    body = RoundBox(c, (0.014, 0.060, 0.050), 0.009, R)
    flap = RoundBox(c + R @ v3(0.013, 0, 0.018), (0.0035, 0.063, 0.036), 0.003, R)
    strap_loop = RoundBox(c + R @ v3(-0.004, 0, 0.058), (0.004, 0.012, 0.022), 0.002, R)
    return Union([body, flap, strap_loop], k=0.003)


def horn_node(K):
    """Curved powder horn on the right hip (quadratic Bezier): wide base with
    the wooden plug toward the back, spout forward."""
    P0, P1, P2 = v3(-0.207, 0.085, 0.905), v3(-0.222, 0.000, 0.866), v3(-0.200, -0.070, 0.900)
    radii = [0.027, 0.026, 0.023, 0.019, 0.015, 0.011, 0.008, 0.0055]
    pts = [(1 - t) ** 2 * P0 + 2 * (1 - t) * t * P1 + t ** 2 * P2 for t in np.linspace(0, 1, len(radii))]
    segs = [RoundCone(pts[i], pts[i + 1], radii[i], radii[i + 1]) for i in range(len(pts) - 1)]
    return Union(segs, k=0.004), pts, radii


def hair_node(K):
    hb = K["headb"]
    cran = Ellipsoid(hb + v3(0, -0.027, 0.061), (0.074, 0.098, 0.092))
    n = nrm(v3(0, 0.13, 0.18))
    p0 = v3(0, -0.108, 1.528)

    def region(X, Y, Z):
        return -((Y - p0[1]) * n[1] + (Z - p0[2]) * n[2])
    cap = Inter(Offset(cran, 0.0075), Fn(region, (-0.2, -0.3, 1.3), (0.2, 0.3, 1.7)), k=0.004)
    ears = Union([Sphere(v3(s * 0.075, hb[1] + 0.004, hb[2] + 0.018), 0.026) for s in (1, -1)], 0)
    cap = Sub(cap, ears, k=0.006)
    # queue: hair gathered at the nape (QUEUE_PTS[0], inside the cap) into a slim, even tail
    # (2.9 -> 2.1 cm thick, 14 cm below the ribbon) with a blunt end; no knot
    q = [v3(*p) for p in QUEUE_PTS]
    queue = Union([RoundCone(q[0], q[1], 0.017, 0.0145), RoundCone(q[1], q[2], 0.0145, 0.0135),
                   RoundCone(q[2], q[3], 0.0135, 0.0105)], k=0.006)
    return Union([cap, queue], k=0.015)


# Queue axis (Blender space): in the hair at the nape, the ribbon wrap, middle, blunt end.
QUEUE_PTS = [(0.0, 0.030, 1.462), (0.0, 0.072, 1.428), (0.0, 0.093, 1.365), (0.0, 0.114, 1.304)]   # the end clears the cape


def ribbon_node(K):
    """A flat ribbon wrapped round the queue at the nape and two short tails lying on the
    back of the queue, curved to its surface (no loose loops, knots or flat plates that
    read as dots or a clip)."""
    q1, q2 = v3(*QUEUE_PTS[1]), v3(*QUEUE_PTS[2])
    ax = nrm(q2 - q1)                                        # down the queue
    c = q1 + ax * 0.004
    back = nrm(np.cross(v3(1, 0, 0), ax))                   # the queue's back (away from the neck)
    if back[1] < 0:
        back = -back
    side = np.cross(ax, back)

    def f(X, Y, Z):
        px, py, pz = X - c[0], Y - c[1], Z - c[2]
        t = px * ax[0] + py * ax[1] + pz * ax[2]
        bx = px * back[0] + py * back[1] + pz * back[2]
        sx = px * side[0] + py * side[1] + pz * side[2]
        r = np.sqrt(bx * bx + sx * sx)
        wrap = np.maximum(np.abs(r - 0.0152) - 0.0016, np.abs(t) - 0.0065)
        ang = np.arctan2(sx, bx)                            # 0 at the back
        out = wrap
        for sgn, length in ((1.0, 0.042), (-1.0, 0.035)):
            half = 0.20 - 0.10 * smoothstep(0.0, length, t)  # tapering tail (rad)
            tail = np.maximum.reduce([np.abs(r - 0.0150) - 0.0012, (np.abs(ang - sgn * 0.22) - half) * 0.015,
                                      0.004 - t, t - length])
            out = np.minimum(out, tail)
        return out
    return Fn(f, c - 0.05, c + 0.05)


def tricorn(prims, mi_felt, mi_trim, center, tilt_deg, crown_a, crown_b, crown_h, brim_r=0.176,
            chord=0.104, fold_deg=78.0, segs=64, rings=7, thick=0.0045):
    """Felt tricorn: an elliptical crown and a round brim folded up along
    three chords (front point forward = -Y)."""
    bm = prims.bm
    rot = Matrix.Rotation(math.radians(tilt_deg), 4, "X")    # front edge down
    C = Vector(center)
    normals = [v3(0, 1, 0), v3(math.sin(math.radians(120)), -0.5, 0), v3(-math.sin(math.radians(120)), -0.5, 0)]
    fa = math.radians(fold_deg)

    def fold(px, py):
        p = v3(px, py, 0.0)
        ups = [0.0]
        for n in normals:
            o = p[0] * n[0] + p[1] * n[1] - chord
            if o > 0:
                p = p - n * o * (1 - math.cos(fa))
                ups.append(o * math.sin(fa))
        ups.sort()
        up = ups[-1] + 0.35 * ups[-2] if len(ups) > 2 else ups[-1]   # corners: soft point, no spike
        return v3(p[0], p[1], up)

    def xf(p):
        return C + rot @ Vector(p)

    # brim (top surface), then solidify downward
    grid = []
    for i in range(rings + 1):
        row = []
        for j in range(segs):
            th = 2 * math.pi * j / segs
            ca, sa = math.cos(th), math.sin(th)
            r_in_x, r_in_y = crown_a * ca, crown_b * sa
            r_in = math.hypot(r_in_x, r_in_y)
            r = r_in + (brim_r - r_in) * (i / rings)
            px, py = ca * r, sa * r
            row.append(bm.verts.new(xf(fold(px, py))))
        grid.append(row)
    brim_faces = []
    for i in range(rings):
        for j in range(segs):
            a, b = grid[i][j], grid[i][(j + 1) % segs]
            c, d = grid[i + 1][(j + 1) % segs], grid[i + 1][j]
            brim_faces.append(bm.faces.new((a, d, c, b)))
    # crown: elliptical wall + slightly domed top
    wall = []
    hs = [0.0, 0.35, 0.7, 1.0]
    for k, hh in enumerate(hs):
        row = []
        for j in range(segs):
            th = 2 * math.pi * j / segs
            bulge = 1.0 + 0.04 * math.sin(math.pi * hh)
            row.append(bm.verts.new(xf((crown_a * bulge * math.cos(th), crown_b * bulge * math.sin(th), crown_h * hh))))
        wall.append(row)
    crown_faces = []
    for k in range(len(hs) - 1):
        for j in range(segs):
            a, b = wall[k][j], wall[k][(j + 1) % segs]
            c, d = wall[k + 1][(j + 1) % segs], wall[k + 1][j]
            crown_faces.append(bm.faces.new((a, b, c, d)))
    # rounded top edge, then a low dome (no flat top-hat edge)
    prev = wall[-1]
    for sc, dz in ((0.955, 0.0048), (0.86, 0.0088), (0.66, 0.0118), (0.38, 0.0132)):
        ring = []
        for j in range(segs):
            th = 2 * math.pi * j / segs
            ring.append(bm.verts.new(xf((crown_a * sc * math.cos(th), crown_b * sc * math.sin(th), crown_h + dz))))
        for j in range(segs):
            crown_faces.append(bm.faces.new((prev[j], prev[(j + 1) % segs], ring[(j + 1) % segs], ring[j])))
        prev = ring
    apex = bm.verts.new(xf((0, 0, crown_h + 0.0138)))
    for j in range(segs):
        crown_faces.append(bm.faces.new((prev[j], prev[(j + 1) % segs], apex)))
    # close the crown bottom (hidden inside the head/hair)
    bottom = bm.verts.new(xf((0, 0, 0.004)))
    for j in range(segs):
        crown_faces.append(bm.faces.new((wall[0][(j + 1) % segs], wall[0][j], bottom)))
    res = bmesh.ops.solidify(bm, geom=brim_faces, thickness=thick)
    for f in brim_faces + crown_faces + [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]:
        f.material_index = mi_felt
        f.smooth = True
    # trim tape along the brim edge = outer ring faces of both sides
    edge_verts = set(grid[-1])
    for f in bm.faces:
        if f.material_index == mi_felt and sum(1 for v in f.verts if v in edge_verts) >= 2:
            f.material_index = mi_trim
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    # cockade position on the outer face of the left-front wall
    n = normals[1]
    p = fold(*(n[:2] * (chord + 0.032)))
    out = np.array(rot.to_3x3() @ Vector(n * math.sin(fa) - v3(0, 0, 1) * math.cos(fa)))
    return np.array(xf(p)) + out * 0.004, out


# ===========================================================================
# Assembly
# ===========================================================================
PALETTE = {
    "skin": ("#d6a487", 0.6, 0.0), "lips": ("#b26a5c", 0.5, 0.0), "sclera": ("#d6cdbd", 0.3, 0.0),
    "iris": ("#3a2618", 0.25, 0.0), "hair": ("#4a2a1a", 0.7, 0.0), "ribbon": ("#2e1d14", 0.6, 0.0),
    "linen": ("#cbc1aa", 0.9, 0.0), "waistcoat": ("#6d2b22", 0.85, 0.0), "coat": ("#3e4a2d", 0.9, 0.0),
    "breeches": ("#6f5a40", 0.85, 0.0), "leggings": ("#4a5142", 0.95, 0.0), "garter": ("#5e2a22", 0.8, 0.0),
    "shoe": ("#2d2019", 0.55, 0.0), "brass": ("#b3903f", 0.35, 0.9), "belt": ("#5b3b24", 0.6, 0.0),
    "strap": ("#6b4a2f", 0.65, 0.0), "pouch": ("#70502f", 0.65, 0.0), "horn": ("#7a6442", 0.6, 0.0),
    "wood": ("#5e3e25", 0.6, 0.0), "horn_tip": ("#2b2119", 0.5, 0.0), "felt": ("#2a2420", 0.95, 0.0),
    "hat_tape": ("#16120f", 0.6, 0.0),
}


def materials():
    return {k: material(k, *v) for k, v in PALETTE.items()}


def build_outfit(K, body, M, h):
    """Returns {object name: object}. Every mesh is in the bind (null-add) pose."""
    out = {}
    t_start = time.time()

    # ---- face details ------------------------------------------------------
    fp = Prims()
    for s in (1, -1):
        c = eye_center(K, s)
        fp.sphere(c, (EYE_R,) * 3, mi=0, segs=12, rings=8)
        # iris: a cap hugging the eyeball (44 deg ~ 17 mm wide), no floating disc edge
        fp.cap(c, EYE_R + 0.0003, v3(0, -1, 0), 44.0, mi=1, segs=16, rings=3)
        # lids: the upper one covers the top of the iris, the lower one its bottom edge,
        # so no ring of white shows around it (the startled look)
        fp.cap(c, EYE_R + 0.0010, v3(0, -math.sin(math.radians(22)), math.cos(math.radians(22))), 42.0,
               mi=3, segs=14, rings=4)
        fp.cap(c, EYE_R + 0.0009, v3(0, -math.sin(math.radians(22)), -math.cos(math.radians(22))), 38.0,
               mi=3, segs=14, rings=3)
    lips = (K["lip_upper_center"] + K["lip_lower_center"]) * 0.5
    lp = surface_point(body, lips + v3(0, -0.05, 0), v3(0, 1, 0), 0.0, 0.08)
    fp.sphere(lp + v3(0, 0.0026, 0), (0.0150, 0.0028, 0.0048), mi=2, segs=14, rings=6)
    face = fp.to_object("Face", [M["sclera"], M["iris"], M["lips"], M["skin"]])
    brows = sdf_object("Brows", brows_node(K, body), 0.0008, 160, M["hair"])
    out["Face"] = join([face, brows], "Face")

    # ---- hair ----------------------------------------------------------------
    hair = sdf_object("Hair", hair_node(K), h, 1400, M["hair"],
                      sizing=lambda P: np.where(P[:, 2] > 1.56, 0.022, 0.012))
    ribbon = sdf_object("Ribbon", ribbon_node(K), 0.0008, 300, M["ribbon"], symmetric=False)
    out["Hair"] = join([hair, ribbon], "Hair")

    # ---- clothes -------------------------------------------------------------
    # Sizing: target edge length where the surface can be seen, coarse where it
    # is hidden inside the body or under an outer garment (occluders).
    def hidden_sizing(L_vis, L_hid, occluders, margin=0.0015):
        def fn(P):
            vis = L_vis(P) if callable(L_vis) else np.full(len(P), L_vis)
            occ = np.min([peval(o, P) for o in occluders], axis=0)
            return np.where(occ < -margin, L_hid, vis)
        return fn

    coat_n, wc_n, shirt_n = coat_node(K), waistcoat_node(K), shirt_node(K)
    legg_n, shoes_n = leggings_node(K, body), shoes_node(K)
    coat_solid = SymUnion(coat_torso_form(K, COAT_OFF), *[Offset(arm_shapes(K, s), SLEEVE_OFF) for s in (1, -1)], k=0.03)

    sform, fopen, bsplit = skirt_form(), coat_front_opening(), coat_back_split()

    def coat_vis(P):
        inner = (peval(sform, P) < 0) & (P[:, 2] < 0.89)
        L = np.where(inner, 0.040, 0.030)                                                # skirt lining side
        pleat = (np.abs(skirt_pleat(P[:, 0], P[:, 1], P[:, 2])) > 0.0) & (P[:, 2] < 0.84)
        L = np.where(pleat, np.where(inner, 0.024, 0.015), L)                            # pleats
        L = np.where(np.abs(P[:, 0]) > 0.27, 0.016, L)                                   # cuffs
        L = np.where(P[:, 2] > 1.26, 0.014, L)                                           # collar
        ang = np.arctan2(P[:, 1], P[:, 0])
        rim = np.minimum.reduce([np.abs(P[:, 2] - skirt_hem_z(P[:, 0], P[:, 1])), np.abs(peval(fopen, P)), np.abs(peval(bsplit, P)),
                                 np.where(P[:, 2] > 1.10, np.abs(CAPE_Z - P[:, 2]), 1.0)])
        return 0.013 + (L - 0.013) * smoothstep(0.004, 0.025, rim)
    coat = sdf_object("Coat", coat_n, 0.0025, 4800, M["coat"],
                      sizing=hidden_sizing(coat_vis, 0.042, [body, wc_n]), feature_deg=32.0, iters=22, sharp_deg=55)
    waist = sdf_object("Waistcoat", wc_n, 0.003, 1000, M["waistcoat"],
                       sizing=hidden_sizing(0.017, 0.036, [body, coat_solid]), feature_deg=35.0, sharp_deg=55)
    shirt = sdf_object("Shirt", shirt_n, 0.003, 1600, M["linen"],
                       sizing=hidden_sizing(lambda P: np.where(P[:, 2] > 1.27, 0.010, 0.013), 0.036, [body, wc_n, coat_solid]),
                       feature_deg=35.0, sharp_deg=55)
    breeches = sdf_object("Breeches", breeches_node(K, body), 0.0032, 1400, M["breeches"],
                          sizing=hidden_sizing(0.024, 0.036, [body, legg_n]), feature_deg=35.0)
    leggings = sdf_object("Leggings", legg_n, 0.003, 2000, M["leggings"],
                          sizing=hidden_sizing(lambda P: np.where(P[:, 2] < 0.10, 0.014, 0.027), 0.036, [body, shoes_n]),
                          feature_deg=35.0, iters=22, sharp_deg=55)
    garters = sdf_object("Garters", garters_node(K, body), 0.002, 450, M["garter"], sharp_deg=45)
    shoes = sdf_object("Shoes", shoes_n, 0.0025, 1200, M["shoe"], sizing=hidden_sizing(0.015, 0.03, [body]),
                       feature_deg=35.0, sharp_deg=55)
    # waistcoat buttons + shoe buckles
    bp = Prims()
    for z in np.linspace(0.935, 1.135, 7):
        p = surface_point(wc_n, v3(-0.006, -0.25, z), v3(0, 1, 0), 0.0, 0.25)
        n = sdf_normal(wc_n, p)
        bp.sphere(p + n * 0.0015, (0.0055, 0.0055, 0.0028), frame_from(n, v3(1, 0, 0)), mi=0, segs=10, rings=5)
    for s in (1, -1):
        A = K.side("ankle", s)
        p = surface_point(shoes_n, v3(A[0], A[1] - 0.075, 0.2), v3(0, 0, -1), 0.0, 0.2)
        n = sdf_normal(shoes_n, p)
        R = frame_from(n, v3(1, 0, 0))
        bp.frame(p + n * 0.002, R, 0.034, 0.026, 0.005, 0.003, mi=0)
    bits = bp.to_object("Fittings", [M["brass"]])
    out["Clothes"] = join([coat, waist, shirt, breeches, leggings, garters, shoes, bits], "Clothes")

    # ---- gear ----------------------------------------------------------------
    # small rigid-ish accessories: plain QEM keeps their crisp edges
    belt = sdf_object("Belt", belt_node(K), 0.0022, 480, M["belt"], sharp_deg=45)
    straps = [sdf_object("Strap_" + sd, strap_node(K, s), 0.0016, 400, M["strap"], symmetric=False, sharp_deg=45)
              for s, sd in ((1, "l"), (-1, "r"))]
    pouch = sdf_object("Pouch", pouch_node(K), 0.002, 380, M["pouch"], symmetric=False, sharp_deg=50)
    hn, hpts, hrad = horn_node(K)
    horn = sdf_object("Horn", hn, 0.002, 420, M["horn"], symmetric=False)
    gp = Prims()
    bn = belt_node(K)
    p = surface_point(bn, v3(0, -0.3, sum(BELT_Z) / 2), v3(0, 1, 0), 0.0, 0.3)
    gp.frame(p + v3(0, -0.003, 0), frame_from(v3(0, -1, 0), v3(1, 0, 0)), 0.052, 0.050, 0.007, 0.004, mi=0)
    d0 = nrm(hpts[0] - hpts[1])
    gp.cylinder(hpts[0] + d0 * 0.004, d0, hrad[0] * 0.93, 0.014, mi=1)                        # wooden base plug
    gp.sphere(hpts[0] + d0 * 0.012, (0.006, 0.006, 0.006), mi=1, segs=10, rings=6)            # plug knob
    d1 = nrm(hpts[-1] - hpts[-2])
    gp.cylinder(hpts[-1] + d1 * 0.004, d1, hrad[-1] * 1.05, 0.016, mi=2, r2=hrad[-1] * 0.7)   # spout stopper
    fit = gp.to_object("GearFittings", [M["brass"], M["wood"], M["horn_tip"]])
    out["Gear"] = join([belt] + straps + [pouch, horn, fit], "Gear")

    # ---- hat -----------------------------------------------------------------
    hb = K["headb"]
    hp = Prims()
    center = hb + v3(0, -0.028, 0.104)
    pc, pn = tricorn(hp, 0, 1, center, tilt_deg=-7.0, crown_a=0.079, crown_b=0.101, crown_h=0.060,
                     segs=34, rings=5)
    hp.cylinder(pc + pn * 0.002, pn, 0.021, 0.004, mi=1, segs=20)                              # cockade
    hp.sphere(pc + pn * 0.005, (0.006, 0.006, 0.004), frame_from(pn, _perp(pn)), mi=2, segs=10, rings=6)
    out["Hat"] = hp.to_object("Hat", [M["felt"], M["hat_tape"], M["brass"]])
    set_sharp(out["Hat"], 60)
    log("outfit built in %.1fs" % (time.time() - t_start))
    return out


# Garment torso parts copy weights from the torso (and neck) of the body only. In the
# A-pose bind the arms hang close to the ribs, so the nearest body point of a side-chest
# vertex of the coat is often on the upper arm; those vertices then followed the arm and
# opened a gap (waistcoat and skin showing through the coat) whenever the arms came up.
# Sleeve vertices (closer to the arm shape than to the torso shape) keep the nearest
# body point, with a short blend at the armhole; below TORSO_Z (hips, skirt, breeches)
# nothing changes.
TORSO_LAYERS = ("coat", "waistcoat", "linen")
TORSO_Z = (0.98, 1.04)


def torso_from_torso(ob, W, body_ob, Wb, body_lab, labels, K):
    masks, _, _, names = material_masks(ob)
    V = mesh_arrays(ob)
    sel = np.zeros(len(V), bool)
    for n in TORSO_LAYERS:
        sel |= masks.get(n, np.zeros(len(V), bool))
    sel &= V[:, 2] > TORSO_Z[0]
    idx = np.nonzero(sel)[0]
    P = V[idx]
    sleeve = sleeve_factor(P, K)
    sleeve[masks.get("waistcoat", np.zeros(len(V), bool))[idx]] = 0.0     # sleeveless
    t = (1.0 - sleeve) * smoothstep(TORSO_Z[0], TORSO_Z[1], P[:, 2])
    me = body_ob.data
    me.calc_loop_triangles()
    tris = np.array([tt.vertices[:] for tt in me.loop_triangles], int)
    keep = np.isin(body_lab, [labels.index("torso"), labels.index("neck")])
    Wt, _ = transfer_from_tris(mesh_arrays(body_ob), tris[keep[tris].all(1)], Wb, P)
    W = W.copy()
    W[idx] = W[idx] * (1.0 - t[:, None]) + Wt * t[:, None]
    log("  garment torso from body torso: %d verts, %d fully, %d blended" % (len(idx), (t > 0.99).sum(), ((t > 0.01) & (t <= 0.99)).sum()))
    return W


# Inner garment layers that take the weights of the coat where the coat covers them,
# so they move with it (else the waistcoat pokes through the coat's side chest when the
# arms come up: the coat there follows the shoulder more than the body under it does).
# Full coat weights within LAYER_NEAR of the coat surface, own weights beyond LAYER_FAR,
# and never at the collar / stock (above LAYER_TOP_Z), which must follow the neck.
LAYER_FOLLOW = ("waistcoat", "linen")
LAYER_NEAR, LAYER_FAR = 0.02, 0.05
LAYER_TOP_Z = (1.24, 1.30)


def follow_coat(ob, W, K):
    masks, tris, tmat, names = material_masks(ob)
    if "coat" not in names:
        return W
    V = mesh_arrays(ob)
    none = np.zeros(len(V), bool)
    # Match parts: torso parts copy from the coat's torso, sleeves from its sleeves
    # (the sleeveless waistcoat only from the torso, so its armhole stays on the body).
    sl = sleeve_factor(V, K)
    sl[masks.get("waistcoat", none)] = 0.0
    coat_tris = tris[tmat == names.index("coat")]
    on_sleeve = sl >= 0.5
    parts = [coat_tris[(~on_sleeve[coat_tris]).all(1)], coat_tris[on_sleeve[coat_tris].all(1)]]
    sel = none.copy()
    for n in LAYER_FOLLOW:
        sel |= masks.get(n, none)
    # waistcoat buttons (brass above the knees) sit on the waistcoat: same treatment
    sel |= masks.get("brass", none) & (V[:, 2] > 0.5)
    sel &= ~masks["coat"]
    idx = np.nonzero(sel)[0]
    Wt, dt = transfer_from_tris(V, parts[0], W, V[idx])
    Ws, ds = transfer_from_tris(V, parts[1], W, V[idx])
    u = sl[idx][:, None]
    Wc = Wt * (1 - u) + Ws * u
    dist = dt * (1 - u[:, 0]) + ds * u[:, 0]
    t = smoothstep(LAYER_FAR, LAYER_NEAR, dist) * smoothstep(LAYER_TOP_Z[1], LAYER_TOP_Z[0], V[idx, 2])
    W = W.copy()
    W[idx] = W[idx] * (1 - t[:, None]) + Wc * t[:, None]
    log("  layers follow coat: %d verts, %d fully (t > 0.99), %d partly" % (len(idx), (t > 0.99).sum(), ((t > 0.01) & (t <= 0.99)).sum()))
    return W


# Upper arm: the shoulder's weight is spread along the arm (t = 0 at the shoulder joint,
# 1 at the elbow) over swing-only -> 1/3 -> 2/3 -> full twist. Forearm: the elbow's
# weight over 0 -> 30 -> 60 -> 90 % of the wrist roll (t = 0 elbow, 1 wrist).
UA_KNOTS, UA_BONES = [0.15, 0.42, 0.68, 0.92], ["shoulder_twist_b", "shoulder_twist_c", "shoulder_twist_d", "shoulder"]
FA_KNOTS, FA_BONES = [0.12, 0.38, 0.64, 0.90], ["elbow", "forarm_twist_a", "forarm_twist_b", "forarm_twist_c"]


def skirt_hem_z(X, Y):
    """Hem height of the coat skirt: the front rises SKIRT_FRONT_RISE above the back so
    the front panels end above the knee (they follow the thigh when it comes up)."""
    ang = np.degrees(np.arctan2(np.abs(X), -Y))           # 0 = front centre, 180 = back
    return SKIRT_HEM + SKIRT_FRONT_RISE * (1 - smoothstep(50.0, 130.0, ang))


def body_hidden(V, lab, labels, K):
    """Skin that the clothes always cover: everything except the head, the neck above
    the bottom of the stock, the hands and the last quarter of the forearms (inside the
    shirt cuffs). Nothing under the clothes can then poke through them."""
    L = np.array(labels)[lab]
    keep = (L == "head") | ((L == "neck") & (V[:, 2] > 1.27)) | (L == "hand_l") | (L == "hand_r")
    for s, sd in ((1, "l"), (-1, "r")):
        t, _ = _forearm_param(V, K, s)
        keep |= (L == "arm_" + sd) & (t > SLEEVE_END + 0.03)
    return ~keep


def clothes_hidden(ob, K):
    """Shirt and waistcoat parts the coat always covers. The shirt stays at the stock (|x| < 8.5 cm),
    in the front V and from the middle of the forearm (cuffs); the waistcoat only in
    the coat's front opening (+5.5 cm). This also removes any waistcoat / linen that
    could show through the coat at the side chest or the armpit."""
    masks, _, _, _ = material_masks(ob)
    V = mesh_arrays(ob)
    X, Y, Z = V[:, 0], V[:, 1], V[:, 2]
    none = np.zeros(len(V), bool)
    sleeve = none.copy()
    for s in (1, -1):
        t, d = _forearm_param(V, K, s)
        sleeve |= (np.sign(X) == s) & (t > SLEEVE_END - 0.12) & (d < 0.08)
    stock = (Z > 1.24) & (np.abs(X) < 0.085)
    shirt_keep = stock | ((Y < -0.03) & (np.abs(X) < 0.11) & (Z > 1.0)) | sleeve
    wc_keep = (Y < 0.0) & (np.abs(X) < np.interp(Z, COAT_OPEN_Z, COAT_OPEN_W) + 0.055)
    return (masks.get("linen", none) & ~shirt_keep) | (masks.get("waistcoat", none) & ~wc_keep)


def coat_shading(ob, K):
    """Per-vertex albedo multiplier (exported as COLOR_0; Godot multiplies the albedo by
    it) that gives the coat some structure from the gameplay camera: darker skirt lining,
    a darker band toward the hem, dark back-vent edges and centre-back seam, slightly
    darker turned cuffs. Every other garment stays white (unchanged)."""
    masks, _, _, _ = material_masks(ob)
    V = mesh_arrays(ob)
    X, Y, Z = V[:, 0], V[:, 1], V[:, 2]
    c = np.ones(len(V))
    coat = masks.get("coat", np.zeros(len(V), bool))
    skirt = coat & (Z < 0.90)
    c[skirt] *= 1 - 0.30 * (1 - smoothstep(0.0, 0.10, Z[skirt] - skirt_hem_z(X[skirt], Y[skirt])))
    lining = skirt & (peval(skirt_form(), V) < -0.0015)
    c[lining] *= 0.70
    # pleat valleys in shade
    a0, a1, count, depth = SKIRT_PLEATS
    pl = skirt_pleat(X[skirt], Y[skirt], Z[skirt]) / depth
    c[skirt] *= 1 - 0.16 * np.clip(-pl, 0.0, 1.0)
    back = coat & (Y > 0.02)
    vent = back & (Z < SKIRT_VENT_TOP + 0.01)
    c[vent] *= 0.75 + 0.25 * smoothstep(0.010, 0.035, np.abs(X[vent]))
    seam = back & (Z >= SKIRT_VENT_TOP + 0.01) & (Z < 1.30)
    c[seam] *= 0.80 + 0.20 * smoothstep(0.008, 0.03, np.abs(X[seam]))
    # the shoulder cape's lower edge: a narrow dark band (its shadow line), so the edge
    # reads as a deliberate cape and not as a seam or a tear
    near = coat & (np.abs(Z - CAPE_Z) < 0.02)
    near[near] &= peval(cape_base(K), V[near]) < 0.010
    c[near] *= 1 - 0.30 * (1 - smoothstep(0.0, 0.011, np.abs(Z[near] - (CAPE_Z - 0.003))))
    for s in (1, -1):
        t, d = _forearm_param(V, K, s)
        cuff = coat & (np.sign(X) == s) & (d < 0.09)
        c[cuff] *= 1 - 0.14 * smoothstep(CUFF_T0 - 0.05, CUFF_T0 + 0.01, t[cuff]) * (1 - smoothstep(SLEEVE_END, SLEEVE_END + 0.04, t[cuff]))
    me = ob.data
    attr = me.color_attributes.get("Color") or me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    rgba = np.repeat(c[:, None], 4, 1)
    rgba[:, 3] = 1.0
    attr.data.foreach_set("color", rgba.astype(np.float32).ravel())
    me.color_attributes.active_color = attr
    return c


def delete_hidden(ob, W, hidden):
    """Deletes the faces whose vertices are all `hidden` (and then loose vertices);
    returns the weights of the remaining vertices."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    lay = bm.verts.layers.int.new("orig")
    for v in bm.verts:
        v[lay] = v.index
    bm.verts.ensure_lookup_table()
    dead = [f for f in bm.faces if all(hidden[v.index] for v in f.verts)]
    bmesh.ops.delete(bm, geom=dead, context="FACES_ONLY")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    keep = np.array([v[lay] for v in bm.verts], int)
    bm.verts.layers.int.remove(lay)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return W[keep], len(dead)


def band_centres(ob, K):
    """Per Gear vertex: the point on the centre line of its leather band (belt: mid
    height; straps: the strap's mid plane), or the vertex itself for other parts; and the
    band of each vertex (0 none, 1 belt, 2 / 3 the left / right strap)."""
    masks, _, _, _ = material_masks(ob)
    V = mesh_arrays(ob)
    C = V.copy()
    band = np.zeros(len(V), int)
    none = np.zeros(len(V), bool)
    belt = masks.get("belt", none)
    C[belt, 2] = 0.5 * (BELT_Z[0] + BELT_Z[1])
    band[belt] = 1
    strap = masks.get("strap", none)
    if strap.any():
        # the nearest point of the nearer strap's centre line
        Vs = V[strap]
        best = np.full(len(Vs), np.inf)
        for k, s in enumerate((1, -1)):
            P = strap_path(K, s)
            for i in range(len(P)):
                a, b = P[i], P[(i + 1) % len(P)]
                ab = b - a
                t = np.clip(((Vs - a) @ ab) / max(ab @ ab, 1e-12), 0.0, 1.0)
                q = a + t[:, None] * ab
                d = np.linalg.norm(Vs - q, axis=1)
                m = d < best
                best[m] = d[m]
                idx = np.nonzero(strap)[0][m]
                C[idx] = q[m]
                band[idx] = 2 + k
    return C, band


def outfit_weights(objs, body_ob, Wb, bones, K, body_lab=None, labels=None):
    bi = {b: i for i, b in enumerate(bones)}
    sform = skirt_form()
    result = {}
    for name, ob in objs.items():
        if name == "Body":
            continue
        V = mesh_arrays(ob)
        if name in ("Hat", "Face"):
            W = np.zeros((len(V), len(bones)))
            W[:, bi["headb"]] = 1.0
        else:
            W = transfer_weights(body_ob, Wb, ob)
        if name == "Clothes" and body_lab is not None:
            W = torso_from_torso(ob, W, body_ob, Wb, body_lab, labels, K)
        if name == "Clothes":
            # coat skirt: pelvis at the waist, then the driven skirt panel helpers
            cmask, _, _, _ = material_masks(ob)
            skirt = (np.abs(peval(sform, V)) < 0.02) & (V[:, 2] < 0.93) & cmask.get("coat", np.zeros(len(V), bool))
            t = smoothstep(0.93, 0.87, V[:, 2])
            Ws = skirt_weights(V, bones)
            W[skirt] = (W[skirt] * (1 - t[skirt, None]) + Ws[skirt] * t[skirt, None])
            W = follow_coat(ob, W, K)
        if name == "Gear" and "Clothes" in result:
            # straps and belt lie on the coat: they take the (final) weights of the coat,
            # so they stay on it when the arms raise the side chest. Each vertex takes the
            # coat's weights at the CENTRE LINE of its band (the belt's mid height, the
            # strap's mid plane) and not at its own position, so every cross-section of
            # the leather moves as one piece: the band can bend with the coat but never
            # change its width (the coat's weights change fast across the waist in a
            # crouch, which stretched the belt 3x).
            co = objs["Clothes"]
            _, ctris, ctmat, cnames = material_masks(co)
            coat_tris = ctris[ctmat == cnames.index("coat")]
            C, band = band_centres(ob, K)
            W, _ = transfer_from_tris(mesh_arrays(co), coat_tris, result["Clothes"], C)
            # ... except the skirt and leg bones: the belt and the strap ends at the hip
            # stay on the torso like stiff leather (else they fold with the thighs)
            legs = [bi[sd + "_" + n] for sd in "lr" for n in
                    ("upper_leg", "knee", "upper_leg_front_helper", "upper_leg_thigh_helper", "upper_leg_rear_helper")]
            gone = W[:, legs].sum(1)
            W[:, legs] = 0.0
            W[:, bi["pelvis"]] += gone
            W /= np.maximum(W.sum(1, keepdims=True), 1e-12)
            W = band_smooth(W, C, band)
        elif name == "Gear":
            # (no coat) straps and belt follow the torso only (no arm/leg bones)
            torso_cols = [bi[b] for b in ("pelvis", "spinea", "spineb", "spinec", "spined", "l_clavicle", "r_clavicle")]
            keep = np.zeros(len(bones), bool)
            keep[torso_cols] = True
            W[:, ~keep] = 0.0
            W /= np.maximum(W.sum(1, keepdims=True), 1e-12)
        if name == "Gear":
            # powder horn and shot pouch hang rigidly from the pelvis (their own parts only:
            # the belt next to the pouch's loop keeps its band weights)
            hn, _, _ = horn_node(K)
            gm, _, _, _ = material_masks(ob)
            own = np.zeros(len(V), bool)
            for n in ("pouch", "horn", "wood", "horn_tip", "brass"):
                own |= gm.get(n, np.zeros(len(V), bool))
            rigid = own & ((peval(pouch_node(K), V) < 0.006) | (peval(hn, V) < 0.02))
            W[rigid] = 0.0
            W[rigid, bi["pelvis"]] = 1.0
        if name == "Hair":
            # cap: body weights smoothed (no fraying at the nape); queue behind the head
            # and the ribbon bow: z-based head -> neck field; the ribbon gets one uniform
            # weight (the queue's at the knot), so the bow moves rigidly
            E = mesh_adjacency(ob)
            W = smooth_weights(W, E, 6, 0.5)
            hb = K["headb"]
            queue = (V[:, 1] > hb[1] + 0.045) & (V[:, 2] < 1.47)
            u = smoothstep(hb[1] + 0.045, hb[1] + 0.065, V[:, 1]) * queue
            Wq = queue_weights(V, bones)
            W = W * (1 - u[:, None]) + Wq * u[:, None]
            # the queue below the ribbon wrap, and the ribbon: the pendulum helper
            a, b = v3(*QUEUE_PTS[1]), v3(*QUEUE_PTS[3])
            inq = (seg_dist(V, a, b) < 0.026) & (V[:, 1] > 0.050)
            pq = smoothstep(a[2] + 0.022, a[2] + 0.002, V[:, 2]) * inq      # a soft root above the wrap
            W = W * (1 - pq[:, None])
            W[:, bi[QUEUE_HELPER]] += pq
            masks, _, _, _ = material_masks(ob)
            rib = masks.get("ribbon", np.zeros(len(V), bool))
            W[rib] = 0.0
            W[rib, bi[QUEUE_HELPER]] = 1.0
        if name not in ("Hat", "Face", "Gear"):
            W = helper_weights(V, W, bones, K)
        E = mesh_adjacency(ob)
        if name == "Gear" and "Clothes" in result:
            # leather bands: already smooth along the band (band_smooth); the spine chain
            # goes to its two bones around the mean BEFORE the 4-influence limit, which would
            # otherwise drop different small chain weights on neighbouring vertices
            W = limit_normalize(chain_weights(W, band > 0, bones))
        else:
            W = limit_normalize(smooth_weights(W, E, 1, 0.3))
        if name in ("Clothes", "Gear"):
            # brass fittings (buttons, buckles) are rigid: one weight per piece
            masks, _, _, _ = material_masks(ob)
            W = rigid_islands(W, E, masks.get("brass", np.zeros(len(V), bool)))
        if name == "Clothes":
            # garters (band, knot and ties) rigid on the shin: the band sits 5-7 cm below
            # the knee, where the leggings are fully on the knee bone too
            masks, _, _, _ = material_masks(ob)
            g = masks.get("garter", np.zeros(len(V), bool))
            W[g] = 0.0
            W[g & (V[:, 0] >= 0), bi["l_knee"]] = 1.0
            W[g & (V[:, 0] < 0), bi["r_knee"]] = 1.0
        result[name] = W
    return result


# ===========================================================================
# Main
# ===========================================================================
def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="build_body.py")
    ap.add_argument("--out", default=os.path.join(FRONTIER, "assets", "character", "actor_b_body.glb"))
    ap.add_argument("--previews", default="", help="directory for preview PNGs (optional)")
    ap.add_argument("--save-blend", default="", help="also save the built scene here (never the source)")
    ap.add_argument("--grid", type=float, default=0.003, help="SDF sampling step (m)")
    ap.add_argument("--stage", default="all", choices=["body", "all"])
    ap.add_argument("--no-export", action="store_true")
    ap.add_argument("--no-poses", action="store_true", help="skip the animated preview renders")
    return ap.parse_args(argv)


def main():
    args = parse_args()
    guard_source()
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    assert rig.matrix_world.is_identity, "rig object transform must be identity"
    missing = load_actions(BIND_LIB, [BIND_ACTION])
    if missing:
        raise SystemExit("bind action not found: %s" % missing)
    G, base = bind_pose(rig)
    K = Skel(G)
    log("bind pose %s: heada z=%.3f, l_shoulder %s" % (BIND_ACTION, K["heada"][2], np.round(K["l_shoulder"], 3)))

    # ---- geometry
    groups = body_groups(K)
    body = body_node(groups)
    M = materials()
    body_ob = sdf_object("Body", body, args.grid, 10000, M["skin"], sizing=body_sizing(K))
    objs = {"Body": body_ob}
    if args.stage != "body":
        objs.update(build_outfit(K, body, M, args.grid))

    # ---- weights
    order = [b.name for b in rig.data.bones]
    segs = deform_segments(K)
    helpers = set(helper_bones())
    missing = helpers - set(order)
    if missing:
        raise SystemExit("rig lacks helper bones %s" % sorted(missing))
    bones = [n for n in order if n in segs or n in helpers]
    Wb, lab, labels = body_weights(body_ob, K, groups, bones)
    Wall = {"Body": helper_weights(mesh_arrays(body_ob), Wb, bones, K)}
    Wall.update(outfit_weights(objs, body_ob, Wb, bones, K, lab, labels))

    # ---- hidden surfaces: skin under the clothes, shirt and waistcoat under the coat
    if "Clothes" in objs:
        Wall["Body"], nb = delete_hidden(body_ob, Wall["Body"], body_hidden(mesh_arrays(body_ob), lab, labels, K))
        Wall["Clothes"], nc = delete_hidden(objs["Clothes"], Wall["Clothes"], clothes_hidden(objs["Clothes"], K))
        log("hidden surfaces removed: body %d tris, shirt/waistcoat %d tris" % (nb, nc))
        sh = coat_shading(objs["Clothes"], K)
        log("coat shading: min %.2f, %d darkened verts" % (sh.min(), (sh < 0.99).sum()))

    # ---- bind rig (rest = null-add), skinning
    bind_rig, err, rot = build_bind_rig(rig, G)
    log("bind rig: %d bones, rest vs null-add max %.2e m / %.4f deg" % (len(bind_rig.data.bones), err, rot))
    used_all = set()
    stats = {}
    for n, o in objs.items():
        used = write_groups(o, Wall[n], bones)
        used_all.update(used)
        o.parent = bind_rig
        mod = o.modifiers.new("Armature", "ARMATURE")
        mod.object = bind_rig
        mod.use_deform_preserve_volume = False
        W = Wall[n]
        stats[n] = {"tris": tri_count(o), "verts": len(o.data.vertices), "materials": [m.name for m in o.data.materials],
                    "bones": used, "max_influences": int((W > 0).sum(1).max()),
                    "non_manifold_edges": check_manifold(o)}
    for b in bind_rig.data.bones:
        b.use_deform = b.name in used_all
    total = sum(s["tris"] for s in stats.values())
    for n, s in stats.items():
        log("  %-8s %6d tris %6d verts  %2d bones  max %d influences  non-manifold %d"
            % (n, s["tris"], s["verts"], len(s["bones"]), s["max_influences"], s["non_manifold_edges"]))
    log("TOTAL %d tris, %d deform bones used" % (total, len(used_all)))

    # ---- export
    if not args.no_export:
        export_glb(bind_rig, list(objs.values()), args.out)
        used_sorted = [b for b in order if b in used_all]
        info = {
            "generator": "tools/character/build_body.py",
            "blender": bpy.app.version_string,
            "glb": os.path.basename(args.out),
            "bind_clip": "actor_b/" + BIND_ACTION,
            "bind_note": ("Armature rest in the glb == null-add pose evaluated on the Actor_B rig (unkeyed channels at rig rest). "
                          "glTF inverse binds are therefore inverse(null-add global); they do not depend on the Skeleton3D rest."),
            "space": "Godot skeleton space: +Y up, character faces +Z (Blender (x, y, z) -> (x, z, -y)).",
            "objects": stats,
            "total_tris": total,
            "deform_bones": used_sorted,
            "helpers": {"table": HELPERS,
                        "skirt": {"hems_godot": [list(h) for h in SKIRT_HEMS_GODOT],
                                  "gravity_max_deg": SKIRT_GRAVITY_MAX_DEG, "front_gain": list(SKIRT_FRONT_GAIN),
                                  "rear_clear_deg": SKIRT_REAR_CLEAR_DEG, "rear_abd": SKIRT_REAR_ABD,
                                  "side_clear_deg": SKIRT_SIDE_CLEAR_DEG, "side_gravity": SKIRT_SIDE_GRAVITY,
                                  "floor_margin": SKIRT_FLOOR_MARGIN, "floor_max_deg": SKIRT_FLOOR_MAX_DEG,
                                  "floor_tilt_deg": list(SKIRT_FLOOR_TILT_DEG),
                                  "feet": SKIRT_FEET},
                        "queue": {"bone": QUEUE_HELPER, "gravity": QUEUE_GRAVITY, "side_max_deg": QUEUE_SIDE_MAX_DEG,
                                  "root_godot": [QUEUE_ROOT[0], QUEUE_ROOT[2], -QUEUE_ROOT[1]]},
                        "upper_arm_twist_center_deg": UPPER_ARM_TWIST_CENTER_DEG,
                        "forearm_twist_center_deg": FOREARM_TWIST_CENTER_DEG,
                        "note": ("Procedural helper bones driven at runtime by scripts/player/character_body.gd "
                                 "(CharacterBodyMesh.HELPERS must match this table).")},
            "driver_reference": driver_reference(rig, base, G),
            "bind_global_godot": {b: xf12(godot_xf(G[b])) for b in used_sorted},
            "inverse_bind_godot": {b: xf12(np.linalg.inv(godot_xf(G[b]))) for b in used_sorted},
            "transform_format": "12 floats: basis x, y, z columns, then origin",
            "provenance": ("Skeleton, bone names and bind pose: Actor_B rig. "
                           "Mesh geometry: generated procedurally by this script."),
        }
        with open(os.path.splitext(args.out)[0] + ".json", "w") as f:
            json.dump(info, f, indent=1)
        log("exported %s (%.0f KB)" % (args.out, os.path.getsize(args.out) / 1024))

    # ---- previews
    if args.previews:
        P = args.previews
        os.makedirs(P, exist_ok=True)
        rig.hide_render = True
        bind_rig.hide_render = True
        co = setup_preview_scene()
        shots = [render_view(co, os.path.join(P, "bind_%s.png" % v), v, center=(0, 0, 0.84), scale=1.9)
                 for v in ("front", "side", "back", "front34")]
        contact_sheet(shots, os.path.join(P, "bind_sheet.png"), 4)
        det = [render_view(co, os.path.join(P, "detail_head.png"), "front34", center=(0, -0.02, 1.49), scale=0.36, res=(600, 600)),
               render_view(co, os.path.join(P, "detail_head_side.png"), "side", center=(0, 0, 1.47), scale=0.36, res=(600, 600)),
               render_view(co, os.path.join(P, "detail_hand.png"), "front34", center=tuple(K.side("palm", 1)), scale=0.26, res=(600, 600)),
               render_view(co, os.path.join(P, "detail_hip.png"), "rside", center=(-0.12, 0, 0.88), scale=0.42, res=(600, 600))]
        contact_sheet(det, os.path.join(P, "detail_sheet.png"), 4)
        if not args.no_poses:
            ps = posed_previews(rig, bind_rig, base, P, co, G)
            if ps:
                contact_sheet(ps, os.path.join(P, "pose_sheet.png"), 6)
    if args.save_blend:
        dst = os.path.realpath(args.save_blend)
        if dst == os.path.realpath(SOURCE_RIG_FILE) or dst.startswith(os.path.realpath(PROJECT) + os.sep):
            raise SystemExit("refusing to save into external animation source")
        bpy.ops.wm.save_as_mainfile(filepath=dst, copy=True)
    log("done")


if __name__ == "__main__":
    main()
