"""Writes data/thuyvan_art/body_kits.json: the proposed body-kit data (format "thuyvan.body_kits", version 1, in the
style of data/customizer/world_peoples.json) for the Godot lane's BodyExtensions. Bones in Godot skeleton space
(female base, stature 1.0, +Z forward), from skeleton.py's tables; the pose-layer idle targets from pose.py.

    python3 write_body_kits.py [OUT]
"""

import json
import math
import os
import sys

sys.dont_write_bytecode = True
import numpy as np  # noqa: E402

from skeleton import FLOODBORN_MARKERS, FLOODBORN_TAIL, FLOODBORN_TAIL_TIP, b2g, moc_tinh_bones, FRONTIER  # noqa: E402

R = lambda v: [round(float(x), 4) for x in v]  # noqa: E731


def tail_targets(pitches, yaws):
    return [[round(p, 1), round(y, 1)] for p, y in zip(pitches, yaws)]


def main(out):
    fb_bones = [{"name": n, "parent": p, "head": list(h), "len": L} for n, p, h, L in FLOODBORN_TAIL]
    fb_bones += [{"name": n, "parent": p, "head": list(h), "len": 0.0, "deform": False} for n, p, h, _ in FLOODBORN_MARKERS]
    mt_bones = []
    for n, p, h, t, d in moc_tinh_bones():
        mt_bones.append({"name": n, "parent": p, "head": R(b2g(h)), "len": round(float(np.linalg.norm(t - h)), 4)})
    data = {
        "format": "thuyvan.body_kits", "version": 1,
        "note": "The non-human body kits (bodies_design.md 2.2): extension bones, springs, pose layer, posture, "
                "proportion, creator rows, the face/skin/hair maps and clearance. Visual only: nothing here changes "
                "speed, aim, the capsule or the camera (plan 3.4 item 32). PROPOSAL from the grey-box pass "
                "(tools/thuyvan_art/bodies); the Godot lane reads it when BodyExtensions exists. Bones are Godot "
                "skeleton space at null-add, female base, stature 1.0 (+Z forward); kit glbs list the 291 Actor_B "
                "bones in rig order, then these in table order.",
        "kits": [
            {"id": "floodborn", "people": "P04", "body": "res://assets/thuyvan/bodies/floodborn_greybox.glb",
             "head": "own", "status": "grey-box, awaiting the owner's silhouette pick",
             "bones": fb_bones, "tail_tip": list(FLOODBORN_TAIL_TIP),
             "springs": {"tail": {"bones": [b[0] for b in FLOODBORN_TAIL], "stiffness": [60, 14], "damping": [9, 4],
                                  "gravity": 0.6, "idiom": "character_body.gd SKIRT_CLOSED_SPRING / _soft"},
                         "crest": {"helper": "QUEUE_HELPER", "idiom": "character_body.gd _queue"}},
             "pose_layer": {
                 "note": "Per-state tail TARGETS as [pitch below horizontal, yaw toward +X] in degrees per bone; the springs move about them.",
                 "idle": tail_targets([52, 50, 44, 30, 6, 0, -2, -3], [0, 0, 3, 7, 11, 14, 16, 18]),
                 "idle_alt_side": "mirror yaw every idle cycle",
                 "walk": {"lift_from": "tail_03", "sway_deg": [6, 10], "phase": "opposite pelvis yaw"},
                 "run": tail_targets([34, 26, 16, 8, 2, -2, -5, -8], [0] * 8),
                 "crouch": "lifted, curled to the free side", "sit": "out to the free side along the ground",
                 "lie": "flat in line with the body", "climb": "hangs, pushed off the wall plane",
                 "springs_per_state": {"idle": [40, 10], "walk": [60, 12], "run": [90, 14], "crouch": [60, 12],
                                       "sit": [30, 12], "lie": [20, 12], "climb": [25, 6]}},
             "posture": {"spine_lean_deg": 8, "neck_counter_deg": -5, "head_counter_deg": -3, "clavicle_fwd_deg": 3,
                         "arm_abduct_deg": 4, "legs": "never touched"},
             "proportion": "floodborn_A",
             "variants": {"A": "Mooring Guard (base)", "B": "Reed Runner -> the Snout length / Build ranges",
                          "C": "Old River Bull -> the Build range and an elder option"},
             "rows": ["face", "skin", "crest", "crest_color", "eyes", "markings", "scars", "jewel_ears", "jewel_snout",
                      "jewel_neck", "jewel_hands", "tattoos"],
             "face_map": {
                 "fb_snout_length": {"face_nose_length": 0.6, "face_length": 0.4, "face_prognathism": 0.5},
                 "fb_snout_width": {"face_nose_width": 0.5, "face_jaw_width": 0.5, "face_breadth": 0.3},
                 "fb_snout_depth": {"face_midface": 0.5, "face_chin_height": 0.4},
                 "fb_nasal_boss": {"face_nose_tip": 0.6, "face_nose_hump": 0.4, "face_nose_upturn": 0.3},
                 "fb_brow_boss": {"face_brow_ridge": 0.8, "face_eye_depth": 0.3},
                 "fb_eye_size": {"face_lid_crease": -0.3, "face_eye_depth": -0.4, "face_under_eye": -0.2},
                 "fb_eye_tilt": {"face_eye_tilt": 1.0, "face_epicanthus": 0.3},
                 "fb_jowl": {"face_cheek_fullness": 0.7, "face_cheekbones": 0.3, "face_jaw_angle": -0.3},
                 "fb_jaw_depth": {"face_chin_projection": 0.5, "face_chin_width": 0.4, "face_lips_lower": 0.3},
                 "fb_teeth_show": {"face_lips_upper": -0.4, "face_mouth_width": 0.6},
                 "fb_ear_slit": {"face_ears": 1.0}},
             "skin_map": {"melanin": "dorsal value, light olive-tan .. near-black olive",
                          "undertone": {"warm": "bronze-olive", "neutral": "olive-grey", "cool": "teal-grey", "olive": "green-olive"},
                          "haemoglobin": "redness of the mouth lining and fresh scars", "freckles": "spot density"},
             "hide": {"ventral": ["#d9cfb0", "#b9ad8a"], "dorsal": ["#2f3b2c", "#3e4f3a", "#5b6b4a"], "teal_cast": "#3e5a52",
                      "seams": "#1e2620", "eyes": "#e0b030", "claws_teeth": "#cfc4a6", "claw_tips": "#3a3128",
                      "quills": "#1e211d", "lambert_wrap": 0.3, "roughness": 0.75, "wet_roughness": 0.25, "wet_specular": 0.5},
             "hair_map": {"bare_ridge": ["cropped", "shaved", "cornrows", "natural short"],
                          "short_quill_row": ["other short styles"], "quill_mane": ["long loose (default)"],
                          "bound_quills": ["queue", "club", "chonmage"], "braided_quill_ropes": ["braids", "bags"],
                          "crest_knot": ["bun", "topknot"]},
             "hide_regions": ["tail_root", "tail", "snout", "crest"],
             "clearance": {"snout_probe_m": 0.55, "tail_near_camera_fade_m": 0.9, "chest_depth_extra": 0.05,
                           "crest_top_m": {"type2": 1.66, "type1_stature_1.07": 1.78}}},
            {"id": "moc_tinh", "people": "P07", "body": "res://assets/thuyvan/bodies/moc_tinh_greybox.glb",
             "head": "makehuman", "status": "grey-box, awaiting the owner's silhouette pick",
             "bones": mt_bones,
             "springs": {"crown": {"bones": "crown_*", "stiffness": [70, 30], "damping": [10, 6], "wind": "world foliage wind"},
                         "vines": {"bones": "vine_*", "stiffness": [25, 8], "damping": [6, 3], "gravity": 1.0}},
             "pose_layer": {"idle": {"vines": "hang", "crown": "rest"}, "idle_rate": 0.7,
                            "rooted": "roots_grip rises over 3 s standing still, released on the first step"},
             "proportion": {"form": "moc_tinh", "limb_thickness": 0.82, "forearm_len": 1.05, "shin_len": 1.05,
                            "pelvis_chest_x": 0.9, "height_max": 1.02},
             "variants": {"A": "Grove-Tender (base)", "B": "Sapling Spire -> the Crown row's capped branches",
                          "C": "Moss-Cloak -> the Crown row's umbrella and the Moss row"},
             "rows": ["face", "skin", "hair_style", "hair_color", "eyes", "eyebrows", "markings", "tattoos", "crown",
                      "bloom", "bark_grain", "moss"],
             "skin_map": {"melanin": ["#a8a690", "#3a3226"], "undertone": {"warm": "red-brown", "neutral": "grey",
                                                                           "cool": "blue-grey", "olive": "green"},
                          "haemoglobin": "amber sap glints (emission, off by default)", "freckles": "lichen spots"},
             "hair_map": {"black": "dark root", "brown": "bark fibre", "fair": "dry grass", "red": "autumn", "grey": "lichen"},
             "parts": {"bark": 6000, "roots": 1500, "crown": 2500, "vines": 1500},
             "hide_regions": ["crown", "roots_l", "roots_r", "vines"],
             "clearance": {"crown_cap_player_m": 0.22, "crown_cap_npc_m": 0.45, "crown_ceiling_probe": True,
                           "root_overhang_m": 0.12}},
        ],
    }
    os.makedirs(os.path.dirname(out), exist_ok=True)
    json.dump(data, open(out, "w"), indent=1, ensure_ascii=False)
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(FRONTIER, "data", "thuyvan_art", "body_kits.json"))
