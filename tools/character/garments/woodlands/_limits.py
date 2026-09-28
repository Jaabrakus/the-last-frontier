"""Deform limits of the Eastern Woodlands garments (pure Python: read by the generators and by
_set_catalog.py). check_body_deform.gd reads them from each catalog fragment
("deform_limits": {surface: [collapse share, flip share, stretch share, max edge ratio]}).

Method (the legacy clothes and the body use it too): scan both fits (sex 0 and 1) over the
44 gameplay clips x 8 samples, take the worse fit, add 25 % and never go below the
check's DEFAULT_LIMIT [0.01, 0.01, 0.01, 4.0]. SCANS records the measured values (percent,
percent, percent, ratio) with the date; garments that pass the default keep it.
"""

DEFAULT_LIMIT = [0.01, 0.01, 0.01, 4.0]

# id -> (collapse %, flip %, stretch %, max edge), worse of the two fits
SCANS = {
    # 2026-09-24 scans (both fits, worse one). Where they come from (per-triangle dumps):
    "ew_leggings_m": (1.82, 2.53, 0.40, 3.17),     # knee pit and hip crease in crouches
    "ew_breechcloth": (7.26, 10.03, 5.26, 2.64),   # flaps: pelvis -> skirt-panel fold at the hip crease (crouch)
    "ew_shirt_linen": (7.43, 11.62, 6.81, 13.07),  # tails' fold at the hip crease; armpit with the arms overhead
    "ew_shirt_ruffled": (5.62, 8.79, 5.15, 13.07),  # as the plain shirt
    "ew_shift_f": (7.91, 13.68, 9.80, 10.10),      # as the shirts, longer tails
    "ew_wrap_skirt_f": (4.80, 11.01, 17.87, 5.23),  # closed skirt on rigid hip panels: legs apart stretch it
    "ew_matchcoat": (8.33, 14.52, 15.82, 14.70),   # lower wrap as the skirt; shoulder cap with the arm overhead
    "ew_sash": (5.29, 5.75, 1.84, 2.82),           # the hanging ends' fold at the hip crease
}
# For comparison: the legacy coat's limits are [0.072, 0.125, 0.23, 27.0] and the bare skin's
# torso_upper [0.0655, 0.0925, 0.167, 40.8] (check_body_deform.gd).


def limits_for(gid):
    s = SCANS.get(gid)
    if s is None:
        return list(DEFAULT_LIMIT)
    c, f, st, e = s
    up = lambda v, d: max(d, round(v * 1.25 / 100.0 + 0.00049, 3))
    return [up(c, DEFAULT_LIMIT[0]), up(f, DEFAULT_LIMIT[1]), up(st, DEFAULT_LIMIT[2]),
            max(DEFAULT_LIMIT[3], round(e * 1.25 + 0.049, 1))]
