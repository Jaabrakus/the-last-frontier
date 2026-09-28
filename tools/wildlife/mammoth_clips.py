"""The woolly mammoth's own clips, made in Blender on the model's rig, and the mammoth exported with them as a glTF.

    Blender -b Mammoth.blend --python tools/wildlife/mammoth_clips.py -- <out.glb>

Mammoth.blend is Riley Kuhlman's source file from "Low Poly Ice Age" (CC0; assets/wildlife/ice_age/SOURCE.md), kept
outside the project. It is opened, the clips are added, and the whole mammoth (mesh, rig, the three clips it came with
and the new ones) is written to <out.glb>; the .blend itself is not saved. All at the file's 24 fps.

Its weak points (user 2026-09-27: "we need weak point animations if they shoot the behind the leg it falls on one
knee"), for each leg (front and hind, left and right):
    Kneel<Front|Hind>_<L|R>   the leg buckles and the mammoth goes down on it (front: onto that knee, the body pitched
                              forward and rolled toward it; hind: onto that hock, the rump sunk on that side); the
                              last frame is the pose it holds while down
    Rise<Front|Hind>_<L|R>    it gathers itself and heaves back up to standing
Its attacks (user 2026-09-27: "they will attack us charge at us and swing there trunk to get us to back away", "do a
ground stomp"):
    TrunkSwing_<L|R>          it coils the trunk away, then sweeps it hard to that side at chest height, the head and
                              the body turning into it (the blow lands about frames 14-20)
    Stomp                     it rears up on its hind legs, the trunk raised, and slams its forefeet down (frame 23)
Its turns (user 2026-09-27: "lets do the mammoth add turns into blender for them"):
    Turn_<L|R>                a quarter turn on the spot (90 degrees, left: counterclockwise from above), each foot
                              stepping round three times in turn (the lead forefoot, the hind foot across, the other
                              forefoot, the other hind foot) while the rest stay planted. The body's own turn is NOT in
                              the clip: the game turns the animal by turn_angle() (TURN_EASE) over the clip, so the
                              feet planted in the clip's frame counter-turn and stay put on the ground
Its meals (user 2026-09-27: "eating and drinking clips as well"), the feet planted, each starting and ending at rest:
    Eat                       the trunk reaches forward and down to the ground, curls round a bundle, lifts it up
                              under the head to the mouth, holds (chewing: the head bobs), and hangs again
    Browse                    (user 2026-09-27: "eating uses trunk to pick up grass and leaves from tress and ground")
                              the head up, the trunk reached up and forward into a tree's leaves, it grips and tugs a
                              mouthful free (frame 22: the game sheds leaves there), brings it down to the mouth, chews
    Drink                     the head lowered, the trunk down into the water, a long draw, then curled up into the
                              mouth, the head tipped back, and two squirts of water blown in (frames 56, 64: the game
                              sprays there), and down again
Its death (user 2026-09-27: "for the mammoth we have to chop it in pieces when we skin it and butcher it"):
    Die_<L|R>                 its forelegs give, it rolls over onto that side and lies there, the upper legs sagging
                              onto the lower (the last frame is the carcass's pose)
For the butchering the mesh's faces are parted into their own materials, so the game can take a piece away or show it
skinned: the tusks Tusk_L / Tusk_R (from Tusks), the hide of each flank Hide_L / Hide_R (from Wool).
The body is moved at the hips (the rig's root, spine.004); the feet stay planted where they stood (IK to their ankles,
the feet keep their rest turn) unless the clip moves them (a buckled leg's ankle to the ground, its foot folded back; the
forefeet lifted in the stomp). The neck and the trunk are turned about world axes. The constraints are baked into plain
keys on every bone and removed.
The rig: Z up, the mammoth facing -Y, its left (.L) at +X.
"""

import math
import sys

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

FPS = 24
ROOT = "spine.004"
# per leg: the IK chain's lower bone (its tail is the ankle), the foot bone
LEGS = {
    "Front_L": ("front_shin.L", "front_foot.L"),
    "Front_R": ("front_shin.R", "front_foot.R"),
    "Hind_L": ("shin.L", "foot.L"),
    "Hind_R": ("shin.R", "foot.R"),
}
X = Vector((1.0, 0.0, 0.0))
Y = Vector((0.0, 1.0, 0.0))
Z = Vector((0.0, 0.0, 1.0))
# the fold of a buckled foot: turned back (toward +Y) about X, flat under the leg
FOOT_FOLD = math.radians(82.0)

# The going down: (frame, how far down 0..1) - the leg gives, the body drops fast, the knee strikes, a bounce, settled.
KNEEL_KEYS = [(0, 0.0), (3, 0.1), (11, 1.06), (14, 0.94), (18, 1.0), (22, 1.0)]
# The getting up: gathers (a little lower), heaves up, stands.
RISE_KEYS = [(0, 1.0), (8, 1.05), (26, 0.4), (38, 0.06), (44, 0.0)]
# The foot folds a little ahead of the drop and unfolds before the stand.
FOLD_LEAD = 1.25
# The trunk swing: (frame, the swing: -1 coiled away .. 0 rest .. 1 swept through to the side).
SWING_KEYS = [(0, 0.0), (9, -0.75), (12, -0.6), (15, 0.45), (17, 1.0), (21, 1.08), (27, 0.55), (34, 0.0)]
# The stomp: (frame, the rear: 1 reared up .. 0 standing .. below 0 the forefeet driven down past standing).
STOMP_KEYS = [(0, 0.0), (6, 0.45), (13, 1.0), (16, 1.05), (21, -0.2), (23, -0.28), (26, -0.05), (30, 0.04), (36, 0.0)]


def design(leg: str) -> dict:
    """The down pose of `leg`: the hips' drop (m) and turn (pitch about X, roll about Y, radians), and where the
    buckled leg's ankle goes (armature space)."""
    s = 1.0 if leg.endswith("_L") else -1.0
    if leg.startswith("Front"):
        return {"drop": 0.12, "pitch": math.radians(13.0), "roll": s * math.radians(7.0),
                "ankle": Vector((0.62 * s, -1.02, 0.14))}
    return {"drop": 0.82, "pitch": math.radians(-16.0), "roll": s * math.radians(8.0),
            "ankle": Vector((0.8 * s, 1.72, 0.13))}


def root_matrix(arm, drop: float, pitch: float, roll: float, yaw: float = 0.0) -> Matrix:
    """The root bone's armature-space matrix: turned about its head (pitch about X, roll about Y, yaw about Z), dropped."""
    bone = arm.data.bones[ROOT]
    pivot = bone.head_local.copy()
    rot = Euler((pitch, roll, yaw), "XYZ").to_matrix().to_4x4()
    turn = Matrix.Translation(pivot) @ rot @ Matrix.Translation(-pivot)
    return Matrix.Translation(Vector((0.0, 0.0, -drop))) @ turn @ bone.matrix_local


class Rig:
    """One clip being made: an action on the armature, an IK target at every ankle and a turn target for every foot
    (planted at rest unless a pose moves them), keyed pose by pose, then baked."""

    def __init__(self, arm, name: str, planted: bool = True):
        self.arm = arm
        self.name = name
        self.act = bpy.data.actions.new(name)
        arm.animation_data_create()
        arm.animation_data.action = self.act
        for pb in arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
            pb.location = (0.0, 0.0, 0.0)
            pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
            pb.scale = (1.0, 1.0, 1.0)
        self.made = []
        self.legs = {}
        for lg, (shin, foot) in (LEGS.items() if planted else []):
            ankle = arm.data.bones[shin].tail_local.copy()
            ik_t = bpy.data.objects.new("ik_" + lg, None)
            bpy.context.scene.collection.objects.link(ik_t)
            ik_t.location = ankle
            rot_t = bpy.data.objects.new("rot_" + lg, None)
            bpy.context.scene.collection.objects.link(rot_t)
            rot_t.rotation_mode = "QUATERNION"
            rest_q = arm.data.bones[foot].matrix_local.to_quaternion()
            rot_t.rotation_quaternion = rest_q
            self.made += [ik_t, rot_t]
            c = arm.pose.bones[shin].constraints.new("IK")
            c.target = ik_t
            c.chain_count = 2
            c.use_stretch = False
            cr = arm.pose.bones[foot].constraints.new("COPY_ROTATION")
            cr.target = rot_t
            cr.target_space = "WORLD"
            cr.owner_space = "WORLD"
            self.legs[lg] = (ik_t, rot_t, ankle, rest_q)
        self.last = 0

    def key(self, f: int, root: Matrix, ankles: dict = None, feet: dict = None, turns: dict = None) -> None:
        """The pose at frame f: the root's armature-space matrix; ankles {leg: armature-space point} and feet {leg: world
        turn} moved from rest (the rest planted); turns {bone: world-axis quaternion} for the neck and trunk bones."""
        ankles = ankles or {}
        feet = feet or {}
        turns = turns or {}
        bpy.context.scene.frame_set(f)
        pr = self.arm.pose.bones[ROOT]
        pr.matrix = root
        pr.keyframe_insert("location", frame=f)
        pr.keyframe_insert("rotation_quaternion", frame=f)
        for lg, (ik_t, rot_t, ankle, rest_q) in self.legs.items():
            ik_t.location = ankles.get(lg, ankle)
            ik_t.keyframe_insert("location", frame=f)
            rot_t.rotation_quaternion = feet.get(lg, rest_q)
            rot_t.keyframe_insert("rotation_quaternion", frame=f)
        for bn, q in turns.items():
            pb = self.arm.pose.bones[bn]
            rest = self.arm.data.bones[bn].matrix_local.to_quaternion()
            pb.rotation_quaternion = rest.inverted() @ q @ rest
            pb.keyframe_insert("rotation_quaternion", frame=f)
        self.last = max(self.last, f)

    def bake(self) -> None:
        arm = self.arm
        bpy.context.scene.frame_start = 0
        bpy.context.scene.frame_end = self.last
        bpy.context.view_layer.objects.active = arm
        for o in bpy.context.view_layer.objects:
            o.select_set(o == arm)
        bpy.ops.object.mode_set(mode="POSE")
        bpy.ops.nla.bake(frame_start=0, frame_end=self.last, only_selected=False, visual_keying=True,
                         clear_constraints=True, use_current_action=True, bake_types={"POSE"})
        bpy.ops.object.mode_set(mode="OBJECT")
        for o in self.made:
            helper = o.animation_data.action if o.animation_data else None
            bpy.data.objects.remove(o, do_unlink=True)
            if helper is not None:
                bpy.data.actions.remove(helper)
        self.act.use_fake_user = True
        report(arm, self.name, self.last)


def make_kneel(arm, name: str, leg: str, keys: list, fold_lead: float) -> None:
    d = design(leg)
    rig = Rig(arm, name)
    _ik, _rot, ankle0, rest_q = rig.legs[leg]
    fold_q = Quaternion(X, FOOT_FOLD) @ rest_q
    for f, amount in keys:
        a = max(0.0, min(1.0, amount))
        fa = max(0.0, min(1.0, amount * fold_lead))
        rig.key(f, root_matrix(arm, d["drop"] * amount, d["pitch"] * amount, d["roll"] * amount),
                ankles={leg: ankle0.lerp(d["ankle"], a)}, feet={leg: rest_q.slerp(fold_q, fa)})
    rig.bake()


def make_swing(arm, side: str) -> None:
    """The trunk swept to `side` ("L": the mammoth's left, +X): coiled the other way first; the trunk's tip lags the base
    (a whip); the head and the body turn into the blow, the feet planted."""
    s = 1.0 if side == "L" else -1.0
    rig = Rig(arm, "TrunkSwing_" + side)
    prev = 0.0
    for f, p in SWING_KEYS:
        tip = 0.5 * (p + prev)
        prev = p
        # a hanging trunk swung to +X turns about -Y (a pendulum about the forward axis at its base)
        turns = {
            "Bone": Quaternion(Y, -s * math.radians(48.0) * p) @ Quaternion(X, -math.radians(12.0) * abs(p)),
            "Bone.001": Quaternion(Y, -s * math.radians(22.0) * tip) @ Quaternion(X, -math.radians(14.0) * abs(tip)),
            "Bone.002": Quaternion(Y, -s * math.radians(18.0) * tip),
            "spine.010": Quaternion(Z, s * math.radians(11.0) * p) @ Quaternion(X, math.radians(5.0) * abs(p)),
            "spine.011": Quaternion(Z, s * math.radians(13.0) * p) @ Quaternion(X, math.radians(7.0) * max(p, 0.0)),
        }
        rig.key(f, root_matrix(arm, 0.04 * abs(p), 0.0, s * math.radians(4.0) * p, s * math.radians(7.0) * p),
                turns=turns)
    rig.bake()


def make_stomp(arm) -> None:
    """Rears up on the hind legs (the hips the pivot, the hind feet planted), the forefeet lifted and the trunk raised,
    then slams the forefeet down a little ahead of where they stood, the head down."""
    rig = Rig(arm, "Stomp")
    fl = rig.legs["Front_L"][2]
    fr = rig.legs["Front_R"][2]
    lift = Vector((0.0, -0.45, 1.25))
    ahead = Vector((0.0, -0.22, 0.0))
    for f, r in STOMP_KEYS:
        up = max(r, 0.0)
        down = max(-r, 0.0) / 0.28
        # lifted as it rears; from the slam on, set down a little ahead; back where they stood at the end
        off = lift * min(up, 1.0)
        if 21 <= f < STOMP_KEYS[-1][0]:
            off += ahead
        turns = {
            # (at the slam the trunk curls forward, clear of the ground the head is driven toward)
            "Bone": Quaternion(X, -math.radians(70.0) * up - math.radians(24.0) * min(down, 1.0)),
            "Bone.001": Quaternion(X, -math.radians(32.0) * up - math.radians(16.0) * min(down, 1.0)),
            "Bone.002": Quaternion(X, -math.radians(25.0) * up),
            "spine.011": Quaternion(X, -math.radians(15.0) * up + math.radians(4.0) * min(down, 1.0)),
        }
        rig.key(f, root_matrix(arm, 0.1 * up, -math.radians(26.0) * r, 0.0),
                ankles={"Front_L": fl + off, "Front_R": fr + off}, turns=turns)
    rig.bake()


# The death: (frame, how far over 0..1) - the forelegs give, it goes over, a bounce, lying.
DIE_KEYS = [(0, 0.0), (6, 0.12), (14, 0.45), (20, 1.03), (24, 0.96), (30, 1.0)]


# The turn: its length, the rounds of steps (each foot steps once a round), a step's length (s), the lift of a stepping
# foot (m), the order the feet step in for a left turn (a right turn mirrors it).
TURN_S = 3.6
TURN_ROUNDS = 3
TURN_STEP_S = 0.5
TURN_LIFT = 0.3
TURN_ORDER_L = ["Front_L", "Hind_R", "Front_R", "Hind_L"]


def turn_angle(u: float, total: float) -> float:
    """The body's turn at `u` (0..1 of the clip) of a turn of `total` radians: at rest at both ends (the game uses the
    same curve, StandInGiant.turn_angle)."""
    return total * (u - math.sin(2.0 * math.pi * u) / (2.0 * math.pi))


def make_turn(arm, side: str) -> None:
    """A quarter turn on the spot to `side` about the rig's origin (the middle of the animal on the ground). In the clip's
    frame (the body's, turning with it) a foot planted at world angle phi sits at its rest place turned by phi - theta(t);
    a step carries it on to the next round's angle with a lift; at the end every foot is at rest again."""
    s = 1.0 if side == "L" else -1.0
    total = s * math.radians(90.0)
    rig = Rig(arm, "Turn_" + side)
    frames = int(round(TURN_S * FPS))
    order = TURN_ORDER_L if side == "L" else [lg.replace("_L", "_X").replace("_R", "_L").replace("_X", "_R") for lg in TURN_ORDER_L]
    round_s = TURN_S / TURN_ROUNDS
    gap = (round_s - 0.1 - TURN_STEP_S) / 3.0
    windows = {lg: [] for lg in LEGS}
    for r in range(TURN_ROUNDS):
        for i, lg in enumerate(order):
            ts = r * round_s + 0.05 + i * gap
            windows[lg].append((ts, ts + TURN_STEP_S, total * (r + 1) / TURN_ROUNDS))
    for f in list(range(0, frames, 2)) + [frames]:
        t = f / FPS
        th = turn_angle(f / frames, total)
        ankles = {}
        feet = {}
        lifting = 0.0
        for lg in LEGS:
            phi = 0.0
            lift = 0.0
            for ts, te, land in windows[lg]:
                if t >= te:
                    phi = land
                    continue
                if t > ts:
                    u = (t - ts) / (te - ts)
                    e = u * u * (3.0 - 2.0 * u)
                    phi = phi + (land - phi) * e
                    lift = TURN_LIFT * math.sin(math.pi * u)
                break
            _ik, _rot, ankle, rest_q = rig.legs[lg]
            turn = Quaternion(Z, phi - th)
            ankles[lg] = turn @ Vector((ankle.x, ankle.y, ankle.z)) + Vector((0.0, 0.0, lift))
            feet[lg] = turn @ rest_q
            lifting = max(lifting, lift)
        # the head leads into the turn; the body dips a little as a foot comes up
        head = s * math.radians(10.0) * math.sin(math.pi * f / frames)
        turns = {"spine.010": Quaternion(Z, head * 0.5), "spine.011": Quaternion(Z, head * 0.5)}
        rig.key(f, root_matrix(arm, 0.05 * lifting / TURN_LIFT, 0.0, 0.0), ankles=ankles, feet=feet, turns=turns)
    rig.bake()


# A meal's poses: (frame, reach 0..1: the trunk forward and down to the ground, curl 0..1: rolled up to the mouth,
# nod: the head down, degrees).
EAT_KEYS = [(0, 0.0, 0.0, 0.0), (10, 1.0, 0.0, 10.0), (15, 1.05, 0.15, 12.0), (19, 0.9, 0.3, 10.0), (30, 0.2, 1.0, -4.0),
            (34, 0.2, 1.0, 0.0), (38, 0.2, 1.0, -4.0), (42, 0.2, 1.0, 0.0), (52, 0.0, 0.0, 0.0)]
# Drinking (user 2026-09-27: "they use there trunk to blow water into there mouths"): the trunk down in the water, a
# long draw, curled up into the mouth with the head tipped back, two squirts (the trunk pushed in: frames 56 and 64,
# DRINK_SQUIRTS), and down again.
DRINK_KEYS = [(0, 0.0, 0.0, 0.0), (12, 1.1, 0.0, 18.0), (18, 1.2, 0.05, 20.0), (36, 1.2, 0.08, 20.0), (40, 1.1, 0.2, 18.0),
              (52, 0.2, 1.02, -9.0), (56, 0.2, 1.14, -13.0), (60, 0.2, 1.0, -14.0), (64, 0.2, 1.14, -15.0),
              (68, 0.2, 1.0, -12.0), (82, 0.0, 0.0, 0.0)]
DRINK_SQUIRTS = [56, 64]
# Browsing: (frame, up 0..1: the trunk raised forward into the leaves, curl 0..1: to the mouth, nod, grip 0..1: the
# tip curled round a spray of leaves).
BROWSE_KEYS = [(0, 0.0, 0.0, 0.0, 0.0), (14, 1.0, 0.0, -16.0, 0.0), (18, 1.05, 0.0, -18.0, 0.6), (22, 0.9, 0.0, -12.0, 1.0),
               (26, 0.95, 0.0, -14.0, 1.0), (40, 0.1, 1.0, -4.0, 0.3), (44, 0.1, 1.0, 0.0, 0.3), (48, 0.1, 1.0, -4.0, 0.3),
               (52, 0.1, 1.0, 0.0, 0.3), (62, 0.0, 0.0, 0.0, 0.0)]
BROWSE_TUG = 22


def make_browse(arm) -> None:
    """The trunk up into a tree's leaves, a tug, and down to the mouth (the U of make_meal)."""
    rig = Rig(arm, "Browse")
    for f, up, curl, nod, grip in BROWSE_KEYS:
        turns = {
            "Bone": Quaternion(X, -math.radians(112.0) * up - math.radians(45.0) * curl),
            "Bone.001": Quaternion(X, -math.radians(18.0) * up + math.radians(100.0) * curl + math.radians(25.0) * grip),
            "Bone.002": Quaternion(X, -math.radians(8.0) * up + math.radians(95.0) * curl + math.radians(55.0) * grip),
            "spine.010": Quaternion(X, math.radians(nod * 0.4)),
            "spine.011": Quaternion(X, math.radians(nod * 0.6)),
        }
        # (the body stays down: raised, the forefeet would lose the ground)
        rig.key(f, root_matrix(arm, 0.02 * up, 0.0, 0.0), turns=turns)
    rig.bake()


def make_meal(arm, name: str, keys: list) -> None:
    """The trunk to the ground and up to the mouth (Eat, Drink): reach swings its base forward and straightens it down;
    curl rolls its lower lengths back and up under the chin; the head nods."""
    rig = Rig(arm, name)
    for f, reach, curl, nod in keys:
        turns = {
            # (nodding swings a hanging trunk back: its base swung forward the more for it; curled, the trunk makes a U:
            # its base forward, its lower lengths folded back and up to the mouth under its root)
            "Bone": Quaternion(X, -math.radians(24.0 + nod * 1.3) * reach - math.radians(45.0) * curl),
            "Bone.001": Quaternion(X, math.radians(100.0) * curl),
            "Bone.002": Quaternion(X, math.radians(10.0) * reach + math.radians(95.0) * curl),
            "spine.010": Quaternion(X, math.radians(nod * 0.4)),
            "spine.011": Quaternion(X, math.radians(nod * 0.6)),
        }
        rig.key(f, root_matrix(arm, 0.04 * reach, math.radians(2.0) * reach, 0.0), turns=turns)
    rig.bake()


def make_die(arm, side: str) -> None:
    """Onto its `side` ("L": its left, +X, down): rolled 86 degrees about its length at the hips and dropped till the
    flank lies on the ground; the legs go with the body (no planting), the upper ones sagging onto the lower."""
    s = 1.0 if side == "L" else -1.0
    rig = Rig(arm, "Die_" + side, planted=False)
    upper = ["front_thigh.R", "thigh.R"] if side == "L" else ["front_thigh.L", "thigh.L"]
    for f, a in DIE_KEYS:
        sag = min(a * 4.0, 1.0)
        turns = {bn: Quaternion(Y, -s * math.radians(38.0) * max(a, 0.0)) for bn in upper}
        turns["spine.011"] = Quaternion(X, math.radians(18.0) * max(a, 0.0))
        rig.key(f, root_matrix(arm, 0.3 * sag * (1.0 - a) + 1.62 * a, math.radians(8.0) * sag * (1.0 - a * 0.6),
                               s * math.radians(86.0) * a), turns=turns)
    rig.bake()


def part_faces() -> None:
    """The tusks into Tusk_L / Tusk_R and each flank's hide into Hide_L / Hide_R (copies of Tusks and Wool: the look is
    the same till the game changes them)."""
    mesh_obj = next(o for o in bpy.data.objects if o.type == "MESH")
    me = mesh_obj.data
    names = [m.name for m in me.materials]
    wool = names.index("Wool")
    tusks = names.index("Tusks")
    new = {}
    for nm, src in [("Tusk_L", tusks), ("Tusk_R", tusks), ("Hide_L", wool), ("Hide_R", wool)]:
        m = me.materials[src].copy()
        m.name = nm
        me.materials.append(m)
        new[nm] = len(me.materials) - 1
    count = {k: 0 for k in new}
    for poly in me.polygons:
        c = poly.center
        if poly.material_index == tusks:
            nm = "Tusk_L" if c.x > 0.0 else "Tusk_R"
        elif poly.material_index == wool and abs(c.x) > 0.5 and -1.5 < c.y < 2.2 and 1.3 < c.z < 3.8:
            nm = "Hide_L" if c.x > 0.0 else "Hide_R"
        else:
            continue
        poly.material_index = new[nm]
        count[nm] += 1
    print("PARTS", count)


def report(arm, name: str, last: int) -> None:
    """How far each ankle is from its rest at the last frame (a planted one: none), and its height."""
    bpy.context.scene.frame_set(last)
    bpy.context.view_layer.update()
    out = []
    for lg, (shin, _foot) in LEGS.items():
        rest = arm.data.bones[shin].tail_local
        now = arm.pose.bones[shin].tail
        out.append("%s %.3f z %.2f" % (lg, (now - rest).length, now.z))
    print("CLIP %s (%d frames): ankles from rest %s" % (name, last, ", ".join(out)))


def peak(arm, name: str, frame: int) -> None:
    """Where the trunk's tip and the forefeet are at `frame` of clip `name` (armature space)."""
    arm.animation_data.action = bpy.data.actions[name]
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    tip = arm.pose.bones["Bone.002"].tail
    fl = arm.pose.bones["front_shin.L"].tail
    print("PEAK %s f%d: trunk tip %s, front L ankle %s" % (name, frame, tuple(round(v, 2) for v in tip),
                                                         tuple(round(v, 2) for v in fl)))


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[0] if argv else "/tmp/mammoth.glb"
    bpy.context.scene.render.fps = FPS
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for a in bpy.data.actions:
        a.use_fake_user = True
    for leg in LEGS:
        make_kneel(arm, "Kneel" + leg, leg, KNEEL_KEYS, FOLD_LEAD)
        make_kneel(arm, "Rise" + leg, leg, RISE_KEYS, 1.0)
    make_swing(arm, "L")
    make_swing(arm, "R")
    make_stomp(arm)
    make_die(arm, "L")
    make_die(arm, "R")
    make_turn(arm, "L")
    make_turn(arm, "R")
    make_meal(arm, "Eat", EAT_KEYS)
    make_meal(arm, "Drink", DRINK_KEYS)
    make_browse(arm)
    part_faces()
    for nm, f in [("TrunkSwing_L", 0), ("TrunkSwing_L", 9), ("TrunkSwing_L", 17), ("TrunkSwing_R", 17), ("Stomp", 16),
                  ("Stomp", 23), ("Eat", 0), ("Eat", 15), ("Eat", 34), ("Drink", 24), ("Drink", 56), ("Drink", 60),
                  ("Browse", 18), ("Browse", 22), ("Browse", 44)]:
        peak(arm, nm, f)
    # (no action left on the rig: the exporter writes every action, the active one would be skipped)
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True,
                              export_animation_mode="ACTIONS", export_apply=False, export_yup=True)
    print("EXPORTED", out, "actions", [a.name for a in bpy.data.actions])


main()
