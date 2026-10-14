"""Which R1 landmarks fall inside each vista camera's frame (Godot axes: x east, y up, z south; yaw 0 = looking -Z north,
positive yaw turns toward -X west, as Godot's rotation.y). Uses the T4 bake for ground heights."""
import math
import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from sample_heights import h  # noqa: E402  (prints its own table first)

PTS = {
    "village": (0, -1248), "clan_house": (60, -1330), "rope_rite_cliff": (-150, -1450), "village_paddies": (80, -1150),
    "waystones A1": (-832, -1400), "two_heights": (-832, -460), "shrine": (100, -500), "silent_reach": (830, -1300),
    "cordon": (800, -1080), "gallery_mouth": (955, -1250), "burial_cairns": (700, -1580), "survey_camp": (650, -1000),
    "rope_bridge_mid": (814, -1215), "torrent_fall_300": (300, -385), "torrent_fall_-200": (-200, -410),
    "torrent_fall_-600": (-600, -445), "torrent_join": (760, -350), "ferry": (780, -150), "north_pass": (-832, -1664),
    "C1 north end": (900, -1664),
}
CAMS = {
    "V1": dict(pos=(938, None, -1250), eye=14.0, target=(330, -1150)),
    "V2": dict(pos=(120, None, -520), eye=10.0, target=(-832, -470)),
    "V3": dict(pos=(825, 194.0, -1205), eye=0.0, target=(860, -1560)),
}
VFOV = 50.0
ASPECT = 16 / 9
HF = math.degrees(2 * math.atan(math.tan(math.radians(VFOV / 2)) * ASPECT))
print("HFOV %.1f" % HF)
for n, c in CAMS.items():
    x, fy, z = c["pos"]
    gy = h(x, z)
    y = fy if fy is not None else gy + c["eye"]
    tx, tz = c["target"]
    ty = h(tx, tz)
    yaw = math.degrees(math.atan2(-(tx - x), -(tz - z)))
    dist = math.hypot(tx - x, tz - z)
    pitch = math.degrees(math.atan2(ty - y, dist))
    print("\n%s pos (%.0f, %.1f, %.0f) ground %.1f  target (%d, %.1f, %d)  yaw %.1f  pitch %.1f  dist %.0f" % (
        n, x, y, z, gy, tx, ty, tz, yaw, pitch, dist))
    for p, (px, pz) in PTS.items():
        py = h(px, pz)
        if py is None:
            continue
        b = math.degrees(math.atan2(-(px - x), -(pz - z)))
        d = (b - yaw + 180) % 360 - 180
        e = math.degrees(math.atan2(py - y, math.hypot(px - x, pz - z)))
        inside = abs(d) <= HF / 2
        if inside: print("  %-18s rel %+6.1f deg  elev %+5.1f  dist %5.0f m  %s" % (
            p, d, e, math.hypot(px - x, pz - z), "IN" if inside else "--"))
