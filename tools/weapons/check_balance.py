#!/usr/bin/env python3
"""Frontier weapon balance check: flies data/weapons/ballistics.json with the game's own integration.

    python3 tools/weapons/check_balance.py              # check the ladder, the bands and the expect blocks
    python3 tools/weapons/check_balance.py --write      # regenerate every generated "expect" field
    python3 tools/weapons/check_balance.py --samples 2000   # faster, noisier Monte Carlo

Each row's "set" (plus "family") becomes a range_sim.py override on top of the weapon's script
values (the over-under starts from the Musket's values while its own script does not exist), and
is flown with range_sim.load_game / evaluate_game: the per-tick integration of Projectile and
ThrownProjectile, the port of Weapon.ballistic_dir, and Weapon.apply_spread's cone. Added here
(weapons_balance_design.md Appendix A):

  * the firearm snap cone: a port of Weapon.tick + Firearm's AIMING/HANGFIRE order (A.3), from a
    settled carry, LMB pressed on tick 1 and released on tick 2;
  * the game-exact torso one-shot distance: bisection on the zeroed flat shot, scored with the
    speed after the tick that crosses the target (as Projectile scores it; A.1);
  * the tomahawk stick windows for the default and every preset: a port of
    ThrowableTomahawk.spin_for + ThrownProjectile.predict_impact and the SPINNING step (A.2).

Checks (exit status 1 on any failure):
  1. strict ladder order by max carry, by standing settled D50 and by best-stance D50 ("ladder");
  2. every row inside its research band (expect.band);
  3. the pistol is deadly close but not a marksman's gun (one-shot >= 20 m, D50 below the bow's,
     best stance <= 30.5 m and below the bow's best);
  4. the over-under is a step below the musket (0.8-0.95 x max carry and settled D50);
  5. the brace floor: no long gun's crouched + RMB cone below 0.32 deg (Graz machine rest);
  6. without --write: the stored expect values match the fresh run (ranges 1 %, D50 6 %, one-shot 2 %).

Keys that are not generated here (expect.band, the over-under's second-shot figures) are preserved.
No Godot needed; tests/weapons/test_range_ladder.gd flies the same numbers through the game.
"""
import argparse
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, "..", ".."))
BALANCE = os.path.join(PROJECT, "data", "weapons", "ballistics.json")
sys.path.insert(0, HERE)
import range_sim as rs  # noqa: E402

HP = 100.0                  # dummies and the enemy baseline
LONG_GUN_BRACE_FLOOR = 0.32  # deg; Graz machine rest on the game's cone model (design 1.4 rule 4)
FALLBACK_CLASS = {"OverUnderMusket": "Musket"}   # until scripts/weapons/over_under.gd exists
# ThrownProjectile SPINNING: |Edge - COM| of the tomahawk model (weapon_models_throwables.gd).
TOMAHAWK_EDGE = (0.0, 0.3875, -0.124)
TOMAHAWK_COM = (0.0, 0.3192, -0.0134)
EDGE_WINDOW_DEG = 50.0      # ThrowableTomahawk._configure_projectile
STICK_SPEED = 5.0
BOARD_H = 3.2               # test board (tests/throwables/harness.gd _board), centred on the launch height


def num_set(row):
    return {k: v for k, v in row.get("set", {}).items()
            if isinstance(v, (int, float)) and not isinstance(v, bool)}


def row_values(scripts, row):
    """Script values of the row's class after construction, with the row's set on top."""
    cls = row["class"]
    base = cls if cls in scripts else FALLBACK_CLASS.get(cls)
    vals = dict(rs.resolve(scripts, base)[0]) if base in scripts else {}
    vals.update(row.get("set", {}))
    return vals


# --- Firearm timing: the snap cone (Appendix A.3) -------------------------------------------

def firearm_timing(v, dt):
    """Tick port of Weapon.tick + Firearm._tick from a settled carry (aim 0), standing still.
    Returns the cone at the discharge for: snap (LMB tick 1, released tick 2), release at full aim,
    and a release 0.4 s after full aim; with the press-to-discharge times."""
    base = float(v["spread_base"])
    unaimed = float(v.get("spread_unaimed", 3.0))
    aim_in = max(float(v.get("aim_in_time", 0.3)), 0.01)
    ready = float(v.get("ready_aim", 0.85))
    hang = float(v.get("hang_fire", 0.09))
    resp = float(v.get("spread_response", 12.0))
    ease = 1.0 - math.exp(-resp * dt)

    def run(release_after_full):
        aim, bloom = 0.0, 0.0
        spread = base + unaimed          # settled at the carry: target at aim 0
        state, queued, timer = "READY", False, 0.0
        full_tick = None
        for tick in range(1, 2000):
            held = tick == 1 if release_after_full is None else (
                full_tick is None or (tick - full_tick) * dt < release_after_full)
            # _tick
            if state == "READY":
                if tick == 1:
                    state, queued = "AIMING", False
            elif state == "AIMING":
                if not held:
                    queued = True
                if queued and aim >= ready:
                    state, timer = "HANGFIRE", hang
            elif state == "HANGFIRE":
                timer -= dt
                if timer <= 0.0:
                    return spread, (tick - 1) * dt
            # aim, bloom, spread
            aim = min(aim + dt / aim_in, 1.0)
            if full_tick is None and aim >= 1.0:
                full_tick = tick
            bloom = max(bloom - dt * 5.0, 0.0)
            spread += (base + unaimed * (1.0 - aim) ** 2 + bloom - spread) * ease
        return spread, None

    snap = run(None)
    full = run(0.0)
    held = run(0.4)
    return {"snap_cone_deg": snap[0], "snap_time_s": snap[1], "full_aim_cone_deg": full[0],
            "full_aim_time_s": full[1], "settled_cone_deg": held[0], "settled_time_s": held[1]}


# --- One-shot distance (Appendix A.1) --------------------------------------------------------

def one_shot(m, dt, reach):
    """Largest d at which the zeroed full-power flat shot still does >= HP to the torso."""
    if m["damage"] < HP:
        return None, "never"

    def dmg(d):
        th, ok = rs.game_ballistic_theta(d, 0.0, m["zero_speed"], m["gravity"], m["drag"], dt, m["drag_q"])
        if not ok:
            return 0.0
        f = rs.fly_to(d, th, m["speed"], m["gravity"], m["drag"], dt, m["drag_q"])
        if not f["reached"] or f["speed"] < m["min_damage_speed"]:
            return 0.0
        return m["damage"] * min(max(f["speed"] / m["speed"], 0.35), 1.0)

    if dmg(reach) >= HP:
        return reach, "reach"
    lo, hi = 1.0, reach
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        lo, hi = (mid, hi) if dmg(mid) >= HP else (lo, mid)
    return lo, "falloff"


# --- Tomahawk stick windows (Appendix A.2) ---------------------------------------------------

def _round_half_away(x):
    return math.floor(x + 0.5) if x >= 0 else -math.floor(-x + 0.5)


def tomahawk_result(v, dt, d, launch_h=rs.LAUNCH_H):
    """Full-power throw at a vertical wooden board whose face is `d` m ahead, aimed at launch
    height, no spread. Returns (result, turns) with result "stick", "haft" or "short"."""
    speed = float(v["max_speed"])
    g = float(v["flight_gravity"])
    drag = float(v["flight_drag"])
    mpt = float(v.get("metres_per_turn", 4.2))
    assist = float(v.get("spin_assist", 1.0))
    ar = v.get("assist_range", [2.5, 15.0])
    reach = math.dist(TOMAHAWK_EDGE, TOMAHAWK_COM)
    th, _ok = rs.game_ballistic_theta(d, 0.0, speed, g, drag, dt)
    vx0, vy0 = math.cos(th) * speed, math.sin(th) * speed
    k = max(1.0 - drag * dt, 0.0)
    top = BOARD_H * 0.5

    # ThrowableTomahawk.spin_for -> ThrownProjectile.predict_impact (point ray from the COM).
    natural = 2.0 * math.pi * speed / mpt
    spin = natural
    if assist > 0.0:
        x = y = t = 0.0
        vx, vy = vx0, vy0
        hit = None
        while t < 4.0:
            vy -= g * dt
            vx, vy = vx * k, vy * k
            nx, ny = x + vx * dt, y + vy * dt
            if nx >= d:
                f = (d - x) / (nx - x)
                hy = y + (ny - y) * f
                if -launch_h <= hy <= top:
                    hit = (t + dt * f, d, hy)
                    break
            if ny <= -launch_h:
                f = (-launch_h - y) / (ny - y)
                hit = (t + dt * f, x + (nx - x) * f, -launch_h)
                break
            x, y, t = nx, ny, t + dt
        if hit:
            t_hit, hx, hy = hit
            dist = math.hypot(hx, hy)
            if t_hit >= 0.05 and ar[0] <= dist <= ar[1]:
                turns = max(_round_half_away(natural * t_hit / (2.0 * math.pi)), 1.0)
                spin = natural + (2.0 * math.pi * turns / t_hit - natural) * min(max(assist, 0.0), 1.0)

    # ThrownProjectile._physics_process, SPINNING: gravity, drag, then a ray from the COM to
    # COM + step + dir * min(reach, 0.25); the rotation follows each completed move.
    x = y = 0.0
    vx, vy = vx0, vy0
    for i in range(1, 4000):
        vy -= g * dt
        vx, vy = vx * k, vy * k
        sp = math.hypot(vx, vy)
        ux, uy = vx / sp, vy / sp
        lead = min(reach, 0.25)
        tx, ty = x + vx * dt + ux * lead, y + vy * dt + uy * lead
        if tx >= d:
            f = (d - x) / (tx - x)
            hy = y + (ty - y) * f
            if -launch_h <= hy <= top:
                a = math.fmod(spin * dt * (i - 1), 2.0 * math.pi)
                ang = math.degrees(min(a, 2.0 * math.pi - a))
                turns = spin * dt * (i - 1) / (2.0 * math.pi)
                return ("stick" if ang <= EDGE_WINDOW_DEG and sp >= STICK_SPEED else "haft"), turns
        if ty <= -launch_h:
            return "short", None
        x, y = x + vx * dt, y + vy * dt
    return "short", None


def tomahawk_windows(v, dt, d_from=2.0, d_to=None, step=0.05):
    """Runs of equal results over the sweep: {"stick": [[a, b], ...], "haft": [...], "reach": d}."""
    d_to = d_to or 30.0
    runs = {"stick": [], "haft": []}
    cur, start, prev_d, last_reach = None, None, None, None
    n = int(round((d_to - d_from) / step))
    for i in range(n + 1):
        d = round(d_from + i * step, 3)
        res, _turns = tomahawk_result(v, dt, d)
        if res == "short":
            break
        last_reach = d
        if res != cur:
            if cur is not None:
                runs[cur].append([start, prev_d])
            cur, start = res, d
        prev_d = d
    if cur is not None:
        runs[cur].append([start, prev_d])
    runs["last_board_hit_m"] = last_reach
    return runs


# --- The run ---------------------------------------------------------------------------------

def run(doc, samples):
    rs.SAMPLES["n"] = samples
    scripts = rs.read_scripts(PROJECT)
    rows = doc["weapons"]
    overrides, full_vals = {}, {}
    for key, row in rows.items():
        vals = row_values(scripts, row)
        full_vals[key] = vals
        ov = num_set(row)
        if key not in rs.GAME_WEAPONS:
            ov = {k: val for k, val in vals.items() if isinstance(val, (int, float)) and not isinstance(val, bool)}
            ov["family"] = row["family"]
        overrides[key] = ov
    _params, models, rate = rs.load_game(PROJECT, overrides)
    if int(doc.get("physics_ticks_per_second", rate)) != rate:
        print("WARNING: ballistics.json physics rate %s != project %d" % (doc.get("physics_ticks_per_second"), rate))
    dt = 1.0 / rate
    timing = {}
    for key, m in models.items():
        if m["family"] == "firearm":
            timing[key] = firearm_timing(full_vals[key], dt)
            m["spread"]["snap"] = timing[key]["snap_cone_deg"]
    res = rs.evaluate_game(models, dt, np.random.default_rng(rs.SEED))
    out = {}
    for key, m in models.items():
        r = res[key]
        sp = r["spread"]
        fam = m["family"]
        best_stance = "crouch_steady" if fam == "firearm" else "crouch"
        if fam != "firearm" and abs(m["spread"]["crouch"] - m["spread"]["stand"]) < 1e-9:
            best_stance = "stand"      # crouch_mult 1.0: identical cone, quote the standing run
        e = {
            "max_range_m": r["max_range"]["max_range_m"],
            "best_elevation_deg": round(r["max_range"]["elevation_deg"], 2),
            "flight_time_s": r["max_range"]["flight_time_s"],
            "quick_max_range_m": r["max_range_quick"]["max_range_m"] if fam != "firearm" else None,
            "flat_reach_m": r["flat_reach_m"],
            "cone_deg": {"stand": round(m["spread"]["stand"], 4), "best": round(sp[best_stance]["cone_deg"], 4)},
            "d100_m": sp["stand"]["d100_m"],
            "d50_m": sp["stand"]["d50_m"],
            "d50_best_m": sp[best_stance]["d50_m"],
            "best_stance": best_stance,
            "man_d50_m": sp["stand"]["man_d50_m"],
            "p_hit_disc": sp["stand"]["p_hit_disc"],
        }
        if fam == "firearm":
            t = timing[key]
            e["cone_deg"]["snap"] = round(t["snap_cone_deg"], 4)
            e["cone_deg"]["full_aim"] = round(t["full_aim_cone_deg"], 4)
            e["cone_deg"]["settled"] = round(t["settled_cone_deg"], 4)
            e["snap_time_s"] = round(t["snap_time_s"], 3)
            e["settled_time_s"] = round(t["settled_time_s"], 3)
            e["d50_snap_m"] = sp["snap"]["d50_m"]
            e["p_hit_disc_snap"] = sp["snap"]["p_hit_disc"]
            e["d50_rmb_m"] = sp["stand_steady"]["d50_m"]
        os_d, os_why = one_shot(m, dt, r["flat_reach_m"])
        e["one_shot_torso_m"] = round(os_d, 1) if os_d is not None else None
        e["one_shot_limit"] = os_why
        if key == "tomahawk":
            v = dict(full_vals[key])
            w = tomahawk_windows(v, dt, d_to=r["flat_reach_m"] + 0.5)
            e["stick_windows_m"] = w["stick"]
            e["haft_windows_m"] = w["haft"]
            e["presets"] = {}
            for pname, pdef in doc.get("presets", {}).items():
                if key in pdef:
                    pv = dict(v)
                    pv.update(pdef[key])
                    pw = tomahawk_windows(pv, dt, d_to=r["flat_reach_m"] + 0.5)
                    e["presets"][pname] = {"stick_windows_m": pw["stick"], "haft_windows_m": pw["haft"]}
        out[key] = {k: val for k, val in e.items() if val is not None}
    return out, models, dt


# --- Checks ------------------------------------------------------------------------------------

def checks(doc, gen, models):
    fails = []

    def expect(cond, msg):
        print(("  ok   " if cond else "  FAIL ") + msg)
        if not cond:
            fails.append(msg)

    def val(key, field):
        x = gen[key].get(field)
        return float(x) if isinstance(x, (int, float)) else float("inf")

    lad = doc["ladder"]
    for name, field in (("max_range", "max_range_m"), ("effective", "d50_m"), ("best", "d50_best_m")):
        order = lad[name]
        vals = [val(k, field) for k in order]
        ok = all(a < b for a, b in zip(vals, vals[1:]))
        expect(ok, "ladder %-9s strict: %s" % (name, "  <  ".join("%s %.1f" % (k, v) for k, v in zip(order, vals))))
    for key, row in doc["weapons"].items():
        band = row.get("expect", {}).get("band", {})
        for field, (lo, hi) in band.items():
            x = val(key, field)
            expect(lo <= x <= hi, "%s %s %.1f inside the research band [%s, %s]" % (key, field, x, lo, hi))
    if "pistol" in gen and "bow" in gen:
        p, b = gen["pistol"], gen["bow"]
        expect(val("pistol", "one_shot_torso_m") >= 20.0, "pistol one-shots a torso to %.1f m (>= 20)" % val("pistol", "one_shot_torso_m"))
        expect(val("pistol", "d50_m") < val("bow", "d50_m"), "pistol standing D50 %.1f < bow %.1f" % (val("pistol", "d50_m"), val("bow", "d50_m")))
        expect(val("pistol", "d50_best_m") <= 30.5 and val("pistol", "d50_best_m") < val("bow", "d50_best_m"),
               "pistol best-stance D50 %.1f <= 30.5 and < bow best %.1f" % (val("pistol", "d50_best_m"), val("bow", "d50_best_m")))
    if "over_under" in gen and "musket" in gen:
        for field in ("max_range_m", "d50_m"):
            r = val("over_under", field) / val("musket", field)
            expect(0.8 <= r <= 0.95, "over-under %s is %.3f x the musket's (0.8-0.95)" % (field, r))
    for key, row in doc["weapons"].items():
        if row.get("slot") == "long" and models[key]["family"] == "firearm":
            c = models[key]["spread"]["crouch_steady"]
            expect(c >= LONG_GUN_BRACE_FLOOR - 1e-9, "%s crouched + RMB cone %.4f deg >= the %.2f deg brace floor" % (key, c, LONG_GUN_BRACE_FLOOR))
    return fails


def compare(doc, gen):
    """Stored expect vs this run."""
    fails = []
    tol = {"max_range_m": 0.01, "flat_reach_m": 0.01, "d50_m": 0.06, "d50_best_m": 0.06, "d50_snap_m": 0.06,
           "one_shot_torso_m": 0.02, "flight_time_s": 0.02}
    for key, e in gen.items():
        old = doc["weapons"][key].get("expect", {})
        for field, rel in tol.items():
            if field not in e:
                continue
            if field not in old:
                fails.append("%s.expect.%s missing (run --write)" % (key, field))
                continue
            a, b = old[field], e[field]
            if isinstance(a, (int, float)) and isinstance(b, (int, float)):
                if abs(a - b) > rel * max(abs(b), 1e-9):
                    fails.append("%s.expect.%s stored %s, now %s" % (key, field, a, b))
            elif a != b:
                fails.append("%s.expect.%s stored %s, now %s" % (key, field, a, b))
        if key == "tomahawk" and old.get("stick_windows_m") != e.get("stick_windows_m"):
            fails.append("tomahawk.expect.stick_windows_m stored %s, now %s" % (old.get("stick_windows_m"), e.get("stick_windows_m")))
    for f in fails:
        print("  FAIL " + f)
    if not fails:
        print("  ok   stored expect blocks match this run")
    return fails


# --- JSON writing (compact scalars and short containers, like the hand-written file) ----------

def _small(x):
    """Scalars and flat lists of scalars: packed several to a line."""
    if isinstance(x, list):
        return all(not isinstance(y, (dict, list)) for y in x)
    return not isinstance(x, dict)


def _pack(parts, indent, width):
    lines, cur = [], ""
    for p in parts:
        if cur and len(cur) + 2 + len(p) + indent > width:
            lines.append(cur + ",")
            cur = p
        else:
            cur = cur + ", " + p if cur else p
    lines.append(cur)
    return ("\n" + " " * indent).join(lines)


def dumps(o, indent=0, width=110):
    flat = json.dumps(o, ensure_ascii=False)
    if not isinstance(o, (dict, list)) or len(flat) + indent <= width:
        return flat
    pad, inner = " " * indent, " " * (indent + 2)
    if isinstance(o, list):
        if all(_small(x) for x in o):
            return "[\n" + inner + _pack([json.dumps(x, ensure_ascii=False) for x in o], indent + 2, width) + "\n" + pad + "]"
        return "[\n" + ",\n".join(inner + dumps(x, indent + 2, width) for x in o) + "\n" + pad + "]"
    if all(_small(v) for v in o.values()) and all(len(json.dumps(v)) < 40 for v in o.values()):
        parts = [json.dumps(k) + ": " + json.dumps(v, ensure_ascii=False) for k, v in o.items()]
        return "{\n" + inner + _pack(parts, indent + 2, width) + "\n" + pad + "}"
    return "{\n" + ",\n".join(inner + json.dumps(k) + ": " + dumps(v, indent + 2, width) for k, v in o.items()) + "\n" + pad + "}"


def write(doc, gen):
    for key, e in gen.items():
        row = doc["weapons"][key]
        old = row.get("expect", {})
        new = dict(e)
        for k, v in old.items():        # keep what is not generated here (band, second-shot figures)
            if k not in new:
                new[k] = v
        row["expect"] = new
    with open(BALANCE, "w", encoding="utf-8") as fh:
        fh.write(dumps(doc) + "\n")
    print("wrote %s" % os.path.relpath(BALANCE, PROJECT))


def table(gen, order):
    cols = ["max_range_m", "best_elevation_deg", "flight_time_s", "flat_reach_m", "d100_m", "d50_m", "d50_snap_m",
            "d50_best_m", "man_d50_m", "one_shot_torso_m"]
    print("%-11s" % "weapon" + "".join("%12s" % c.replace("_m", "").replace("_deg", "").replace("_s", "") for c in cols))
    for k in order:
        e = gen[k]
        print("%-11s" % k + "".join("%12s" % (e.get(c, "-") if not isinstance(e.get(c), float) else "%.1f" % e[c]) for c in cols))
    for k in order:
        print("  %-10s p(disc) %s" % (k, gen[k]["p_hit_disc"]))
    if "tomahawk" in gen:
        print("  tomahawk stick %s  haft %s" % (gen["tomahawk"]["stick_windows_m"], gen["tomahawk"]["haft_windows_m"]))
        for p, w in gen["tomahawk"].get("presets", {}).items():
            print("  tomahawk [%s] stick %s  haft %s" % (p, w["stick_windows_m"], w["haft_windows_m"]))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--write", action="store_true", help="regenerate the expect blocks in ballistics.json")
    ap.add_argument("--samples", type=int, default=6000, help="Monte Carlo samples per distance (default 6000)")
    args = ap.parse_args()
    with open(BALANCE, encoding="utf-8") as fh:
        doc = json.load(fh)
    if doc.get("schema") != "frontier.weapons.ballistics/1":
        print("FAIL: unknown schema %s" % doc.get("schema"))
        return 1
    gen, models, _dt = run(doc, args.samples)
    table(gen, doc["ladder"]["max_range"])
    fails = checks(doc, gen, models)
    if args.write:
        write(doc, gen)
    else:
        fails += compare(doc, gen)
    print("CHECK BALANCE %s" % ("PASSED" if not fails else "FAILED (%d)" % len(fails)))
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
