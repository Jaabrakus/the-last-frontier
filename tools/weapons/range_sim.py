#!/usr/bin/env python3
"""Frontier range calculator: the game's own ballistics, a real-world reference, and a fit.

    python3 tools/weapons/range_sim.py                 # tables for the current game values
    python3 tools/weapons/range_sim.py --write         # also write data/weapons/range_research.json
    python3 tools/weapons/range_sim.py --override f.json   # evaluate other numbers
    python3 tools/weapons/range_sim.py --weapon musket --json   # one weapon, JSON to stdout

What it does
  1. Reads the CURRENT weapon numbers straight from scripts/weapons/*.gd (the `var x := v`
     defaults and the `x = v` lines in `_init`, walking the `extends` chain the way the
     constructors run), so the report cannot drift from the code. The physics rate comes
     from project.godot. `--override` merges a JSON {weapon: {property: value}} on top (a
     candidate balance file); an entry with a "family" key adds a new weapon (e.g. an
     over-under barrel: {"family": "firearm", "muzzle_speed": ..., "ball_drag": ..., ...}).
  2. Flies them with the game's exact integration (Projectile._physics_process,
     ThrownProjectile._physics_process, Weapon._height_at): per tick
         v.y -= g*dt;  v *= max(1 - drag*dt, 0);  p += v*dt      (dt = 1/physics rate)
     and aims with an exact port of Weapon.ballistic_dir (Newton on the elevation, 8
     iterations, clamp +-1.4 rad, straight line when out of reach). Spread is
     Weapon.apply_spread: miss radius r = tan(cone) * randf() with a uniform angle.
     An optional quadratic term `drag_quadratic` (per metre; v /= 1 + k*|v|*dt after the
     linear step) models the proposed Projectile hook; it is 0 for every current weapon.
  3. Reports per weapon: max range from 1.4 m (and whether Projectile.max_life cuts it), the
     zeroed full-power shot at 5..500 m (elevation, flight time, impact speed, damage after
     the speed falloff), and the hit chance on a 0.5 m disc and on a 0.5 x 1.8 m man box per
     stance (Monte Carlo of real trajectories), with D100 (every shot hits) and D50.
  4. Flies the same weapons with a real-world reference model (quadratic drag; Mach-dependent
     sphere drag for lead balls) and validates it against Robins (1742), the Graz tests
     (Krenn et al. 1995), the 1841 Royal Engineers test, Ishi's flight shot and the M67 throw.
  5. Fits candidate game numbers for the ladder targets in range_research_input.json: with
     the current linear drag (works today) and with the quadratic hook. Candidates are a
     starting point for the balance step; nothing is applied.

No Godot needed. tests/weapons/range_crosscheck.gd compares this port with the real
Weapon.ballistic_dir and with the live property values.
"""
import argparse
import json
import math
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.normpath(os.path.join(HERE, "..", ".."))
INPUT = os.path.join(HERE, "range_research_input.json")
OUTPUT = os.path.join(PROJECT, "data", "weapons", "range_research.json")

LAUNCH_H = 1.4
DISC_R = 0.25
MAN_W, MAN_H = 0.5, 1.8
DISTANCES = [5, 10, 15, 20, 25, 30, 40, 50, 75, 100, 150, 200, 300, 500]
REPORT_DISTANCES = [10, 20, 50, 100]
HIT_GRID = [2, 3, 4, 5, 6, 8, 10, 12, 15, 18, 20, 25, 30, 35, 40, 50, 60, 75, 90, 100, 125, 150,
            175, 200, 250, 300, 400, 500, 650, 800]
SAMPLES = {"n": 6000}
SEED = 1750

# Which script each game weapon is, and how its shot is built.
GAME_WEAPONS = {
    "tomahawk": {"class": "ThrowableTomahawk", "family": "throwable"},
    "spear": {"class": "ThrowableSpear", "family": "throwable"},
    "atlatl": {"class": "ThrowableAtlatl", "family": "throwable"},
    "bow": {"class": "Bow", "family": "bow"},
    "pistol": {"class": "FlintlockPistol", "family": "firearm"},
    "musket": {"class": "Musket", "family": "firearm"},
}
ORDER = ["tomahawk", "spear", "atlatl", "bow", "pistol", "musket", "rifle"]


def ordered(keys):
    keys = list(keys)
    return [k for k in ORDER if k in keys] + [k for k in keys if k not in ORDER]


# --- Reading the GDScript sources ---------------------------------------------------------

NUM = r"[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?"
RE_CLASS = re.compile(r"^class_name\s+(\w+)", re.M)
RE_EXTENDS = re.compile(r"^extends\s+(\w+)", re.M)
RE_VAR = re.compile(r"^(?:@export\w*(?:\([^)]*\))?\s+)?(?:static\s+)?var\s+(\w+)\s*(?::\s*[\w\[\]]+\s*)?:?=\s*("
                    + NUM + r"|true|false)\s*(?:#.*)?$", re.M)
RE_ASSIGN = re.compile(r"^\t(\w+)\s*=\s*(" + NUM + r"|true|false)\s*(?:#.*)?$")


def _num(s):
    if s in ("true", "false"):
        return s == "true"
    return float(s)


def _init_body(src):
    m = re.search(r"^func _init\(\)\s*(?:->\s*void)?\s*:\s*$", src, re.M)
    if not m:
        return []
    lines = []
    for line in src[m.end():].splitlines()[1:]:
        if line and not line[0].isspace():
            break
        lines.append(line)
    return lines


def read_scripts(root):
    """{class_name: {"extends", "defaults", "init": [(name, value)], "file"}} for scripts/weapons."""
    out = {}
    for dirpath, _dirs, files in os.walk(os.path.join(root, "scripts", "weapons")):
        for f in sorted(files):
            if not f.endswith(".gd"):
                continue
            path = os.path.join(dirpath, f)
            with open(path, encoding="utf-8") as fh:
                src = fh.read()
            cm = RE_CLASS.search(src)
            if not cm:
                continue
            em = RE_EXTENDS.search(src)
            init = []
            for line in _init_body(src):
                am = RE_ASSIGN.match(line)
                if am:
                    init.append((am.group(1), _num(am.group(2))))
            out[cm.group(1)] = {"extends": em.group(1) if em else None,
                                "defaults": {k: _num(v) for k, v in RE_VAR.findall(src)},
                                "init": init, "file": os.path.relpath(path, root)}
    return out


def resolve(scripts, cls):
    """Property values after construction: class defaults root->leaf, then _init root->leaf
    (every subclass _init in scripts/weapons calls super() first)."""
    chain = []
    c = cls
    while c in scripts:
        chain.append(c)
        c = scripts[c]["extends"]
    chain.reverse()
    vals = {}
    for c in chain:
        vals.update(scripts[c]["defaults"])
    for c in chain:
        for k, v in scripts[c]["init"]:
            vals[k] = v
    return vals, [scripts[c]["file"] for c in chain]


def physics_rate(root):
    try:
        with open(os.path.join(root, "project.godot"), encoding="utf-8") as fh:
            m = re.search(r"physics_ticks_per_second\s*=\s*(\d+)", fh.read())
            if m:
                return int(m.group(1))
    except OSError:
        pass
    return 60


def godot_ease(x, c):
    """@GlobalScope.ease() for c > 0 (the only case the weapons use)."""
    x = min(max(x, 0.0), 1.0)
    if c <= 0:
        return 0.0
    if c < 1.0:
        return 1.0 - (1.0 - x) ** (1.0 / c)
    return x ** c


def _lerp(a, b, t):
    return a + (b - a) * t


def shot_model(key, vals, projectile_vals):
    """Everything the calculator needs about one weapon, from its resolved properties."""
    fam = GAME_WEAPONS[key]["family"] if key in GAME_WEAPONS else vals.get("family", "firearm")
    m = {"key": key, "family": fam, "drag_q": float(vals.get("drag_quadratic", 0.0))}
    if fam == "firearm":
        m.update(speed=vals["muzzle_speed"], quick_speed=vals["muzzle_speed"],
                 gravity=vals.get("ball_gravity", 9.8), drag=vals.get("ball_drag", 0.35),
                 zero_speed=vals["muzzle_speed"], damage=vals["damage"], quick_damage=vals["damage"],
                 max_life=projectile_vals.get("max_life", 20.0),
                 min_damage_speed=projectile_vals.get("min_damage_speed", 15.0))
    elif fam == "bow":
        cq = vals["min_draw"] / vals["draw_time"]
        m.update(speed=vals["max_arrow_speed"],
                 quick_speed=_lerp(vals["min_arrow_speed"], vals["max_arrow_speed"], godot_ease(cq, 0.6)),
                 gravity=vals["arrow_gravity"], drag=vals.get("arrow_drag", 0.0),
                 zero_speed=vals["max_arrow_speed"], damage=vals["max_damage"],
                 quick_damage=_lerp(vals["min_damage"], vals["max_damage"], godot_ease(cq, 0.6)),
                 max_life=projectile_vals.get("max_life", 20.0),
                 min_damage_speed=projectile_vals.get("min_damage_speed", 15.0),
                 quick_extra_spread=vals["spread_undercharge"] * (1 - cq) ** 2)
    else:  # throwable
        cq = vals["min_windup"] / vals["windup_time"]
        m.update(speed=vals["max_speed"],
                 quick_speed=_lerp(vals["min_speed"], vals["max_speed"], godot_ease(cq, 0.7)),
                 gravity=vals["flight_gravity"], drag=vals["flight_drag"], zero_speed=vals["max_speed"],
                 damage=vals["max_damage"],
                 quick_damage=_lerp(vals["min_damage"], vals["max_damage"], godot_ease(cq, 0.6)),
                 max_life=None, min_damage_speed=vals.get("min_damage_speed", 5.0),
                 quick_extra_spread=vals["spread_undercharge"] * (1 - cq) ** 2)
    base = vals["spread_base"]
    crouch = vals.get("crouch_mult", 0.65)
    steady = vals.get("aim_mult", 1.0) if fam == "firearm" else 1.0   # only Firearm has RMB steady aim
    m["spread"] = {"stand": base, "crouch": base * crouch}
    if fam == "firearm":
        m["spread"]["stand_steady"] = base * steady
        m["spread"]["crouch_steady"] = base * crouch * steady
    m["spread_move_deg"] = vals.get("spread_move")
    m["spread_air_deg"] = vals.get("spread_air")
    return m


def load_game(root, overrides=None):
    scripts = read_scripts(root)
    proj = resolve(scripts, "Projectile")[0] if "Projectile" in scripts else {}
    thrown = resolve(scripts, "ThrownProjectile")[0] if "ThrownProjectile" in scripts else {}
    params, models = {}, {}
    for key, info in GAME_WEAPONS.items():
        if info["class"] not in scripts:
            continue
        vals, files = resolve(scripts, info["class"])
        if info["family"] == "throwable":
            vals.setdefault("min_damage_speed", thrown.get("min_damage_speed", 5.0))
        if overrides and key in overrides:
            vals.update(overrides[key])
        params[key] = {"class": info["class"], "files": files, "values": vals}
        models[key] = shot_model(key, vals, proj)
    for key, vals in (overrides or {}).items():
        if key not in models and isinstance(vals, dict) and "family" in vals:
            params[key] = {"class": None, "files": [], "values": vals}
            models[key] = shot_model(key, vals, proj)
    return params, models, physics_rate(root)


# --- The game's integration -----------------------------------------------------------------

def _drag_step(vx, vy, drag, drag_q, dt):
    k = max(1.0 - drag * dt, 0.0)
    vx *= k
    vy *= k
    if drag_q > 0.0:
        s = 1.0 + drag_q * math.hypot(vx, vy) * dt
        vx /= s
        vy /= s
    return vx, vy


def game_height_at(dist, theta, speed, g, drag, dt, drag_q=0.0):
    """Exact port of Weapon._height_at (None for NAN)."""
    vx = math.cos(theta) * speed
    vy = math.sin(theta) * speed
    x = y = 0.0
    for _ in range(6000):
        vy -= g * dt
        vx, vy = _drag_step(vx, vy, drag, drag_q, dt)
        nx = x + vx * dt
        ny = y + vy * dt
        if nx >= dist:
            return y + (ny - y) * (dist - x) / (nx - x)
        x, y = nx, ny
        if vx < 0.5:
            break
    return None


def game_ballistic_theta(dist, dy, speed, g, drag, dt, drag_q=0.0):
    """Exact port of Weapon.ballistic_dir as an elevation angle -> (theta, reached).
    reached False: the game falls back to the straight line (target out of reach)."""
    straight = math.atan2(dy, dist)
    if dist < 1.0 or (g <= 0.0 and drag <= 0.0 and drag_q <= 0.0):
        return straight, True
    theta = straight
    for _ in range(8):
        h = game_height_at(dist, theta, speed, g, drag, dt, drag_q)
        if h is None:
            break
        miss = h - dy
        if abs(miss) < 0.002:
            break
        h2 = game_height_at(dist, theta + 0.001, speed, g, drag, dt, drag_q)
        if h2 is None:
            break
        slope = (h2 - dy - miss) / 0.001
        if abs(slope) < 1e-6:
            break
        theta = min(max(theta - miss / slope, -1.4), 1.4)
    if game_height_at(dist, theta, speed, g, drag, dt, drag_q) is None:
        return straight, False
    return theta, True


H3_CLAMP = 1.55          # hook H3: the Newton clamp widened from 1.4 rad
H3_STEEPEST = 1.5608     # BallisticsUtil.STEEPEST
_carry_cache = {}


def _h3_carry(theta, speed, g, drag, dt, drag_q=0.0):
    """Port of BallisticsUtil._carry."""
    vx, vy = math.cos(theta) * speed, math.sin(theta) * speed
    x = y = 0.0
    for _ in range(12000):
        vy -= g * dt
        vx, vy = _drag_step(vx, vy, drag, drag_q, dt)
        ny = y + vy * dt
        if ny < 0.0 and vy < 0.0:
            return x + vx * dt * y / (y - ny)
        x += vx * dt
        y = ny
    return x


def h3_max_carry_elevation(speed, g, drag, dt, drag_q=0.0):
    """Port of BallisticsUtil.max_carry_elevation (golden section, 28 steps on [0, 1.3])."""
    key = (speed, g, drag, dt, drag_q)
    if key not in _carry_cache:
        a, b = 0.0, 1.3
        for _ in range(28):
            c = b - 0.618034 * (b - a)
            d = a + 0.618034 * (b - a)
            if _h3_carry(c, speed, g, drag, dt, drag_q) > _h3_carry(d, speed, g, drag, dt, drag_q):
                b = d
            else:
                a = c
        _carry_cache[key] = (a + b) * 0.5
    return _carry_cache[key]


def _h3_h_or_low(dist, dy, theta, speed, g, drag, dt, drag_q=0.0):
    """Port of BallisticsUtil._h_or_low (-inf: passes below)."""
    vx, vy = math.cos(theta) * speed, math.sin(theta) * speed
    x = y = 0.0
    for _ in range(6000):
        vy -= g * dt
        vx, vy = _drag_step(vx, vy, drag, drag_q, dt)
        nx, ny = x + vx * dt, y + vy * dt
        if nx >= dist:
            return y + (ny - y) * (dist - x) / (nx - x)
        x, y = nx, ny
        if vx < 0.5 or (vy <= 0.0 and y < dy):
            break
    return -math.inf


def h3_fallback_elevation(dist, dy, theta, speed, g, drag, dt, drag_q=0.0):
    """Port of BallisticsUtil.fallback_elevation."""
    hi = theta
    above = _h3_h_or_low(dist, dy, theta, speed, g, drag, dt, drag_q) > dy
    if not above and dy < 0.0:
        for probe in (0.0, -1.4):
            if _h3_h_or_low(dist, dy, probe, speed, g, drag, dt, drag_q) > dy:
                above, hi = True, probe
                break
    if above:
        lo = -H3_STEEPEST
        for _ in range(30):
            mid = (lo + hi) * 0.5
            if _h3_h_or_low(dist, dy, mid, speed, g, drag, dt, drag_q) < dy:
                lo = mid
            else:
                hi = mid
        return (lo + hi) * 0.5
    return max(h3_max_carry_elevation(speed, g, drag, dt, drag_q), math.atan2(dy, dist))


def game_ballistic_theta_h3(dist, dy, speed, g, drag, dt, drag_q=0.0):
    """Port of Weapon.ballistic_dir with hook H3 in (Newton clamp +-1.55 rad, and
    BallisticsUtil.fallback_elevation when the solve misses) -> (theta, reached)."""
    straight = math.atan2(dy, dist)
    if dist < 1.0 or (g <= 0.0 and drag <= 0.0 and drag_q <= 0.0):
        return straight, True
    theta = straight
    for _ in range(8):
        h = game_height_at(dist, theta, speed, g, drag, dt, drag_q)
        if h is None:
            break
        miss = h - dy
        if abs(miss) < 0.002:
            break
        h2 = game_height_at(dist, theta + 0.001, speed, g, drag, dt, drag_q)
        if h2 is None:
            break
        slope = (h2 - dy - miss) / 0.001
        if abs(slope) < 1e-6:
            break
        theta = min(max(theta - miss / slope, -H3_CLAMP), H3_CLAMP)
    h = game_height_at(dist, theta, speed, g, drag, dt, drag_q)
    if h is None or abs(h - dy) > 0.05:
        return h3_fallback_elevation(dist, dy, theta, speed, g, drag, dt, drag_q), False
    return theta, True


def fly_to(dist, theta, speed, g, drag, dt, drag_q=0.0, max_t=60.0):
    """One projectile, stepped like Projectile._physics_process, until it crosses x = dist
    (-> time, height, speed there) or lands (y = -LAUNCH_H)."""
    vx, vy = math.cos(theta) * speed, math.sin(theta) * speed
    x = y = t = 0.0
    for _ in range(int(max_t / dt)):
        vy -= g * dt
        vx, vy = _drag_step(vx, vy, drag, drag_q, dt)
        nx, ny = x + vx * dt, y + vy * dt
        if nx >= dist:
            f = (dist - x) / (nx - x)
            return {"reached": True, "t": t + f * dt, "y": y + (ny - y) * f, "speed": math.hypot(vx, vy)}
        if ny <= -LAUNCH_H:
            f = (-LAUNCH_H - y) / (ny - y)
            return {"reached": False, "t": t + f * dt, "land_x": x + (nx - x) * f, "speed": math.hypot(vx, vy)}
        x, y, t = nx, ny, t + dt
    return {"reached": False, "t": t, "land_x": x, "speed": math.hypot(vx, vy)}


def game_max_range(speed, g, drag, dt, max_life=None, drag_q=0.0):
    """Best carry on flat ground from LAUNCH_H (vectorised over elevations 0-70 deg)."""
    thetas = np.radians(np.arange(0.0, 70.01, 0.25))
    vx = np.cos(thetas) * speed
    vy = np.sin(thetas) * speed
    x = np.zeros_like(thetas)
    y = np.zeros_like(thetas)
    land = np.full_like(thetas, np.nan)
    tland = np.full_like(thetas, np.nan)
    k = max(1.0 - drag * dt, 0.0)
    t = 0.0
    for _ in range(int(120.0 / dt)):
        vy = vy - g * dt
        vx = vx * k
        vy = vy * k
        if drag_q > 0.0:
            s = 1.0 + drag_q * np.hypot(vx, vy) * dt
            vx = vx / s
            vy = vy / s
        nx = x + vx * dt
        ny = y + vy * dt
        hit = np.isnan(land) & (ny <= -LAUNCH_H)
        if hit.any():
            f = (-LAUNCH_H - y[hit]) / (ny[hit] - y[hit])
            land[hit] = x[hit] + (nx[hit] - x[hit]) * f
            tland[hit] = t + f * dt
        x, y, t = nx, ny, t + dt
        if not np.isnan(land).any():
            break
    i = int(np.nanargmax(land))
    res = {"max_range_m": round(float(land[i]), 1), "elevation_deg": float(np.degrees(thetas[i])),
           "flight_time_s": round(float(tland[i]), 2)}
    if max_life is not None and tland[i] > max_life:
        j = int(np.nanargmax(np.where(tland <= max_life, land, np.nan)))
        res["max_life_s"] = max_life
        res["max_range_within_life_m"] = round(float(land[j]), 1)
        res["note"] = "Projectile.max_life frees the shot in mid-air before the longest carry lands"
    return res


def zeroed_shots(m, dt, distances=DISTANCES):
    """The full-power shot aimed at a point at launch height `d` metres away."""
    rows = []
    for d in distances:
        theta, reached = game_ballistic_theta(d, 0.0, m["zero_speed"], m["gravity"], m["drag"], dt, m["drag_q"])
        f = fly_to(d, theta, m["speed"], m["gravity"], m["drag"], dt, m["drag_q"])
        row = {"distance_m": d, "elevation_deg": round(math.degrees(theta), 3),
               "reachable": bool(reached and f["reached"])}
        if f["reached"]:
            ratio = f["speed"] / m["speed"]
            row.update(flight_time_s=round(f["t"], 4), impact_speed_mps=round(f["speed"], 2),
                       speed_ratio=round(ratio, 3), miss_m=round(f["y"], 3),
                       damage=round(m["damage"] * min(max(ratio, 0.35), 1.0), 1)
                       if f["speed"] >= m["min_damage_speed"] else 0.0)
            if m.get("max_life") and f["t"] > m["max_life"]:
                row["reachable"] = False
                row["note"] = "freed by max_life before arrival"
        else:
            row["lands_at_m"] = round(f["land_x"], 2)
            if not reached:
                row["note"] = "out of reach: ballistic_dir falls back to the straight line"
            else:
                # _height_at does not stop at the ground, so Newton can end on an angle that "reaches"
                # the distance far below the target; ballistic_dir returns it without checking the miss.
                h = game_height_at(d, theta, m["zero_speed"], m["gravity"], m["drag"], dt, m["drag_q"])
                row["note"] = ("out of reach: Newton did not converge and ballistic_dir returns its last "
                               "iterate (%.1f deg, miss %.1f m)" % (math.degrees(theta), h if h is not None else float("nan")))
                row["unconverged"] = True
        rows.append(row)
    return rows


def mc_hit_rates(m, dt, cone_deg, distances, rng, samples=None):
    """Monte Carlo of Weapon.apply_spread around the zeroed full-power shot, flying every sample
    with the game integration. {d: (p_disc, p_man)} for each reachable d."""
    samples = samples or SAMPLES["n"]
    out = {}
    tc = math.tan(math.radians(cone_deg))
    for d in distances:
        theta, reached = game_ballistic_theta(d, 0.0, m["zero_speed"], m["gravity"], m["drag"], dt, m["drag_q"])
        if not reached:
            continue
        centre = fly_to(d, theta, m["speed"], m["gravity"], m["drag"], dt, m["drag_q"])
        if not centre["reached"] or abs(centre["y"]) > 0.05:
            continue
        if m.get("max_life") and centre["t"] > m["max_life"]:
            continue
        # Aim frame as in apply_spread: side = dir x UP, up = side x dir.
        fwd = np.array([math.cos(theta), math.sin(theta), 0.0])
        side = np.cross(fwd, [0.0, 1.0, 0.0])
        side /= np.linalg.norm(side)
        up = np.cross(side, fwd)
        up /= np.linalg.norm(up)
        r = tc * rng.random(samples)
        phi = rng.random(samples) * 2 * math.pi
        dirs = fwd[None, :] + side[None, :] * (np.cos(phi) * r)[:, None] + up[None, :] * (np.sin(phi) * r)[:, None]
        dirs /= np.linalg.norm(dirs, axis=1)[:, None]
        v = dirs * m["speed"]
        p = np.zeros_like(v)
        done = np.zeros(samples, bool)
        hy = np.full(samples, 1e9)
        hz = np.zeros(samples)
        k = max(1.0 - m["drag"] * dt, 0.0)
        for _ in range(int(max(centre["t"] * 3.0, 1.0) / dt) + 10):
            v[:, 1] -= m["gravity"] * dt
            v *= k
            if m["drag_q"] > 0.0:
                v /= (1.0 + m["drag_q"] * np.linalg.norm(v, axis=1) * dt)[:, None]
            n = p + v * dt
            cross = (~done) & (n[:, 0] >= d)
            if cross.any():
                f = (d - p[cross, 0]) / (n[cross, 0] - p[cross, 0])
                hy[cross] = p[cross, 1] + (n[cross, 1] - p[cross, 1]) * f
                hz[cross] = p[cross, 2] + (n[cross, 2] - p[cross, 2]) * f
                done |= cross
            done |= (~done) & (n[:, 1] <= -LAUNCH_H)     # grounded short: stays a miss
            p = n
            if done.all():
                break
        disc = (hy ** 2 + hz ** 2) <= DISC_R ** 2
        man = (np.abs(hz) <= MAN_W / 2) & (np.abs(hy) <= MAN_H / 2)
        out[d] = (float(disc.mean()), float(man.mean()))
    return out


def _crossing(rates, idx, level):
    """First distance where the hit rate falls below `level` (linear interpolation); None if never."""
    prev = None
    for d in sorted(rates):
        p = rates[d][idx]
        if p < level:
            if prev is None:
                return float(d)
            d0, p0 = prev
            return float(d0 + (d - d0) * (p0 - level) / (p0 - p)) if p0 != p else float(d)
        prev = (d, p)
    return None


def spread_report(m, dt, rng):
    out = {}
    reach = m.get("_reach_m")
    grid = [d for d in HIT_GRID if reach is None or d <= reach * 1.02]
    for stance, cone in m["spread"].items():
        tc = math.tan(math.radians(cone))
        rates = mc_hit_rates(m, dt, cone, grid, rng)
        rec = {"cone_deg": round(cone, 4), "cone_mrad": round(math.radians(cone) * 1000, 2),
               "analytic_d100_m": round(DISC_R / tc, 1), "analytic_d50_m": round(2 * DISC_R / tc, 1)}
        beyond = ">%.0f" % reach if reach else "beyond reach"    # never fell that low inside the flat reach
        for name, idx, level in (("d100_m", 0, 0.995), ("d50_m", 0, 0.5), ("man_d50_m", 1, 0.5)):
            c = _crossing(rates, idx, level)
            rec[name] = round(c, 1) if c is not None else beyond
        rec["p_hit_disc"] = {str(d): round(p[0], 3) for d, p in rates.items() if d in (5, 10, 20, 30, 50, 100, 200, 300)}
        rec["p_hit_man"] = {str(d): round(p[1], 3) for d, p in rates.items() if d in (5, 10, 20, 30, 50, 100, 200, 300)}
        out[stance] = rec
    return out


def flat_reach(m, dt, upper):
    """Farthest point at launch height the zeroed full-power shot can land on (bisection)."""
    lo, hi = 1.0, upper + 5.0
    for _ in range(30):
        mid = 0.5 * (lo + hi)
        th, ok = game_ballistic_theta(mid, 0.0, m["zero_speed"], m["gravity"], m["drag"], dt, m["drag_q"])
        good = False
        if ok:
            f = fly_to(mid, th, m["speed"], m["gravity"], m["drag"], dt, m["drag_q"])
            good = f["reached"] and abs(f["y"]) < 0.05 and not (m.get("max_life") and f["t"] > m["max_life"])
        lo, hi = (mid, hi) if good else (lo, mid)
    return lo


def evaluate_game(models, dt, rng):
    res = {}
    for key in ordered(models):
        m = models[key]
        mr = game_max_range(m["speed"], m["gravity"], m["drag"], dt, m.get("max_life"), m["drag_q"])
        mq = game_max_range(m["quick_speed"], m["gravity"], m["drag"], dt, m.get("max_life"), m["drag_q"])
        m["_reach_m"] = flat_reach(m, dt, mr.get("max_range_within_life_m", mr["max_range_m"]))
        res[key] = {
            "launch": {"full_mps": round(m["speed"], 2), "quick_mps": round(m["quick_speed"], 2),
                       "gravity": m["gravity"], "drag_per_s": m["drag"], "drag_quadratic_per_m": m["drag_q"],
                       "zero_speed_mps": m["zero_speed"], "damage_full": m["damage"],
                       "damage_quick": round(m["quick_damage"], 1),
                       "quick_extra_spread_deg": round(m.get("quick_extra_spread", 0.0), 3)},
            "max_range": mr,
            "max_range_quick": mq,
            "flat_reach_m": round(m["_reach_m"], 1),
            "zeroed_shots": zeroed_shots(m, dt),
            "spread": spread_report(m, dt, rng),
            "spread_move_deg": m.get("spread_move_deg"),
            "spread_air_deg": m.get("spread_air_deg"),
        }
    return res


# --- Real-world reference model ---------------------------------------------------------------

RHO = 1.2
SOUND = 340.0
G = 9.81
# Round-ball drag coefficient against Mach, approximated from the Miller & Bailey (1979) curves
# for small spheres (Re ~1e5-1e6): ~0.5 subsonic, rising through the transonic to ~1.0.
SPHERE_CD = [(0.0, 0.47), (0.4, 0.49), (0.5, 0.50), (0.6, 0.53), (0.7, 0.58), (0.8, 0.66), (0.9, 0.78),
             (1.0, 0.89), (1.1, 0.96), (1.2, 0.99), (1.4, 1.01), (1.6, 1.01), (2.0, 0.99)]


def sphere_cd(mach):
    return float(np.interp(mach, [a for a, _ in SPHERE_CD], [b for _, b in SPHERE_CD]))


class RefBody:
    def __init__(self, mass, diameter=None, drag_area=None, sphere=False, cd_scale=1.0):
        self.mass = mass
        self.sphere = sphere
        self.area = math.pi * diameter ** 2 / 4 if diameter else None
        self.drag_area = drag_area
        self.cd_scale = cd_scale

    def k(self, v):
        """Quadratic drag constant (1/m): a_drag = -k |v| v."""
        if self.sphere:
            return RHO * sphere_cd(v / SOUND) * self.cd_scale * self.area / (2 * self.mass)
        return RHO * self.drag_area / (2 * self.mass)


def make_body(spec, cd_scale=None):
    return RefBody(spec["mass_kg"], spec.get("diameter_m"), spec.get("drag_area_m2"), spec.get("sphere", False),
                   cd_scale if cd_scale is not None else spec.get("cd_scale", 1.0))


def ref_fly(body, v0, theta, stop_x=None, dt=0.0005, max_t=120.0, h0=LAUNCH_H):
    """Midpoint (RK2) flight. Stops at x = stop_x (speed/time/height there) or at the ground."""
    x = y = t = 0.0
    vx, vy = v0 * math.cos(theta), v0 * math.sin(theta)

    def acc(vx_, vy_):
        v = math.hypot(vx_, vy_)
        kk = body.k(v)
        return -kk * v * vx_, -G - kk * v * vy_

    while t < max_t:
        ax, ay = acc(vx, vy)
        mvx, mvy = vx + ax * dt / 2, vy + ay * dt / 2
        ax2, ay2 = acc(mvx, mvy)
        nx, ny = x + mvx * dt, y + mvy * dt
        nvx, nvy = vx + ax2 * dt, vy + ay2 * dt
        if stop_x is not None and nx >= stop_x:
            f = (stop_x - x) / (nx - x)
            return {"reached": True, "t": t + f * dt, "y": y + (ny - y) * f,
                    "speed": math.hypot(vx + (nvx - vx) * f, vy + (nvy - vy) * f)}
        if ny <= -h0:
            f = (-h0 - y) / (ny - y)
            return {"reached": False, "t": t + f * dt, "land_x": x + (nx - x) * f, "speed": math.hypot(nvx, nvy)}
        x, y, vx, vy, t = nx, ny, nvx, nvy, t + dt
    return {"reached": False, "t": t, "land_x": x, "speed": math.hypot(vx, vy)}


def ref_max_range(body, v0, h0=LAUNCH_H):
    best = (0.0, 0.0)
    for deg in np.arange(5.0, 50.01, 1.0):
        lx = ref_fly(body, v0, math.radians(deg), dt=0.002, h0=h0)["land_x"]
        if lx > best[0]:
            best = (lx, deg)
    lo, hi = max(best[1] - 1.0, 0.5), best[1] + 1.0
    for _ in range(16):
        a = lo + (hi - lo) / 3
        b = hi - (hi - lo) / 3
        if ref_fly(body, v0, math.radians(a), dt=0.001, h0=h0)["land_x"] < ref_fly(body, v0, math.radians(b), dt=0.001, h0=h0)["land_x"]:
            lo = a
        else:
            hi = b
    deg = 0.5 * (lo + hi)
    f = ref_fly(body, v0, math.radians(deg), dt=0.001, h0=h0)
    return {"max_range_m": round(f["land_x"], 1), "elevation_deg": round(deg, 2), "flight_time_s": round(f["t"], 2)}


def ref_zeroed(body, v0, d):
    """Low-arc elevation that lands the shot at launch height at distance d (None: out of reach)."""
    def miss(th):
        f = ref_fly(body, v0, th, stop_x=d, dt=0.001)
        return f["y"] if f["reached"] else None
    lo, hi = -0.05, None
    for deg in np.arange(0.25, 45.01, 0.25):
        mm = miss(math.radians(deg))
        if mm is not None and mm >= 0:
            hi = math.radians(deg)
            break
        if mm is not None:
            lo = math.radians(deg)
    if hi is None:
        return None
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        mm = miss(mid)
        lo, hi = (mid, hi) if (mm is None or mm < 0) else (lo, mid)
    th = 0.5 * (lo + hi)
    f = ref_fly(body, v0, th, stop_x=d, dt=0.0005)
    return {"elevation_deg": round(math.degrees(th), 3), "flight_time_s": round(f["t"], 4),
            "impact_speed_mps": round(f["speed"], 1), "speed_ratio": round(f["speed"] / v0, 3),
            "energy_ratio": round((f["speed"] / v0) ** 2, 3)}


def evaluate_reference(inp):
    out = {}
    for key in ORDER:
        spec = inp["reference_bodies"].get(key)
        if not spec:
            continue
        body = make_body(spec)
        rows = []
        for v0 in spec["speeds_mps"]:
            mr = ref_max_range(body, v0)
            shots = {}
            for d in REPORT_DISTANCES + [30, 150, 200, 300]:
                if d <= mr["max_range_m"] * 0.98:
                    z = ref_zeroed(body, v0, d)
                    if z:
                        shots[str(d)] = z
            rows.append({"v0_mps": v0, "max_range": mr, "zeroed": shots, "k_per_m_at_v0": round(body.k(v0), 5)})
        out[key] = {"body": spec, "by_speed": rows}
    return out


def validate_reference(inp):
    val = inp["validation"]
    out = {}
    for scale in (1.0, 1.25):
        tag = "cd_x%.2f" % scale
        s = val["robins_1742"]
        body = RefBody(s["mass_kg"], s["diameter_m"], sphere=True, cd_scale=scale)
        pred = {dist: round(ref_fly(body, s["v_at_7_6m"], 0.0, stop_x=float(dist) - 7.62, dt=0.0001, h0=10.0)["speed"], 1)
                for dist in s["measured"]}
        out.setdefault("robins_1742_downrange", {"measured_mps": s["measured"], "source": s["source"]})[tag] = {
            "predicted_mps": pred,
            "max_error_pct": round(max(abs(pred[d] - s["measured"][d]) / s["measured"][d] * 100 for d in pred), 1)}
        s = val["graz_decel"]
        body = RefBody(s["mass_kg"], s["diameter_m"], sphere=True, cd_scale=scale)
        f = ref_fly(body, s["v0"], 0.0, stop_x=24.0, dt=0.0001, h0=10.0)
        out.setdefault("graz_first_24m", {"measured_mps_per_m": s["measured_mps_per_m_first_24m"], "source": s["source"]})[tag] = \
            round((s["v0"] - f["speed"]) / 24.0, 2)
        for name in ("bess_1841_max", "robins_half_mile"):
            s = val[name]
            body = RefBody(s["mass_kg"], s["diameter_m"], sphere=True, cd_scale=scale)
            v0s = s["v0"] if isinstance(s["v0"], list) else [s["v0"]]
            out.setdefault(name, {"measured_max_m": s["measured_max_m"], "note": s.get("note", ""), "source": s["source"]})[tag] = \
                {str(v): ref_max_range(body, v)["max_range_m"] for v in v0s}
    s = val["ishi_flight"]
    body = RefBody(s["mass_kg"], drag_area=s["drag_area_m2"])
    out["ishi_flight"] = {"predicted_max_m": {str(v): ref_max_range(body, v, h0=1.5)["max_range_m"] for v in s["v0"]},
                          "measured_max_m": s["measured_max_m"], "note": s["note"], "source": s["source"]}
    s = val["grenade_m67"]
    body = RefBody(s["mass_kg"], drag_area=s["drag_area_m2"])
    out["grenade_m67"] = {"predicted_max_m": {str(v): ref_max_range(body, v, h0=1.8)["max_range_m"] for v in s["v0"]},
                          "measured_m": s["measured_m"], "note": s["note"], "source": s["source"]}
    return out


# --- Fitting candidate game numbers ------------------------------------------------------------

def _solve_drag(v0, want, dt, quadratic=False):
    """Linear drag (per s) or quadratic drag (per m) that makes the game's max range `want`."""
    def rng_for(x):
        return game_max_range(v0, 9.8, 0.0 if quadratic else x, dt, drag_q=x if quadratic else 0.0)["max_range_m"]
    if rng_for(0.0) <= want:
        return 0.0
    lo, hi = 0.0, (0.05 if quadratic else 5.0)
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        lo, hi = (mid, hi) if rng_for(mid) > want else (lo, mid)
    return 0.5 * (lo + hi)


def fit_candidates(inp, models, dt, quadratic=False):
    """Per ladder weapon: g = 9.8, the target launch speed, the drag that puts the max range in
    the middle of the target band, cone = atan(0.5 / D50), and the steady/crouch multiplier from
    steady_d50."""
    out = {}
    for key in ORDER:
        tgt = inp["ladder_targets"].get(key)
        if not tgt:
            continue
        v0 = float(tgt["launch_mps"])
        want = sum(tgt["max_range_m"]) / 2.0
        note = None
        if key == "bow" and not quadratic:
            # Bow._fire and TrajectoryPreview pass a hard-coded 0.0 drag, so a parameter-only fit
            # keeps drag 0 and lowers the arrow speed until the vacuum range is the target.
            lo, hi = 5.0, v0
            for _ in range(40):
                mid = 0.5 * (lo + hi)
                lo, hi = (mid, hi) if game_max_range(mid, 9.8, 0.0, dt)["max_range_m"] < want else (lo, mid)
            v0, drag = round(0.5 * (lo + hi), 2), 0.0
            note = ("parameter-only: drag stays 0 (hard-coded in Bow._fire and TrajectoryPreview), so the "
                    "full-draw speed is lowered to %.1f m/s (inside the 40-50 m/s research band); with an "
                    "arrow_drag property the target speed %s m/s and drag %.4f/s give the same reach"
                    % (v0, tgt["launch_mps"], _solve_drag(float(tgt["launch_mps"]), want, dt)))
        else:
            drag = _solve_drag(v0, want, dt, quadratic)
        cone = math.degrees(math.atan(2 * DISC_R / tgt["d50_m"]))
        steady_cone = math.degrees(math.atan(2 * DISC_R / tgt["steady_d50_m"]))
        rec = {"launch_mps": v0, "gravity": 9.8,
               "drag_per_s": 0.0 if quadratic else round(drag, 4),
               "drag_quadratic_per_m": round(drag, 6) if quadratic else 0.0,
               "spread_base_deg": round(cone, 3), "steady_or_crouch_mult": round(steady_cone / cone, 3)}
        if note:
            rec["note"] = note
        cur = models.get(key)
        if cur:
            rec["current"] = {"launch_mps": cur["speed"], "gravity": cur["gravity"], "drag_per_s": cur["drag"],
                              "spread_base_deg": cur["spread"]["stand"]}
        out[key] = rec
    return out


def candidate_models(cands, models):
    out = {}
    for key, c in cands.items():
        base = dict(models.get(key) or {"key": key, "family": "firearm", "damage": 100.0, "quick_damage": 100.0,
                                        "min_damage_speed": 15.0, "max_life": 20.0})
        base.update(speed=c["launch_mps"], quick_speed=min(base.get("quick_speed", c["launch_mps"]), c["launch_mps"]),
                    gravity=c["gravity"], drag=c["drag_per_s"], drag_q=c["drag_quadratic_per_m"],
                    zero_speed=c["launch_mps"])
        s = c["spread_base_deg"]
        base["spread"] = {"stand": s, "steady": s * c["steady_or_crouch_mult"]}
        out[key] = base
    return out


def compare_decay(cand_eval, ref):
    """Impact-speed ratio and flight time at 20/50/100 m: candidate game model vs the reference
    physics at the reference speed closest to the candidate launch speed."""
    out = {}
    for key, e in cand_eval.items():
        r = (ref or {}).get(key)
        if not r:
            continue
        v0 = e["launch"]["full_mps"]
        row = min(r["by_speed"], key=lambda x: abs(x["v0_mps"] - v0))
        cmp = {}
        for d in (20, 50, 100):
            z = next((x for x in e["zeroed_shots"] if x["distance_m"] == d), None)
            rz = row["zeroed"].get(str(d))
            if z and z["reachable"] and rz:
                cmp[str(d)] = {"game_speed_ratio": z["speed_ratio"], "reference_speed_ratio": rz["speed_ratio"],
                               "game_time_s": z["flight_time_s"], "reference_time_s": rz["flight_time_s"]}
        out[key] = {"reference_v0": row["v0_mps"], "at": cmp}
    return out


# --- Cross-check cases for the Godot test ----------------------------------------------------------

def crosscheck_cases(models, dt):
    cases = []
    for key in ordered(models):
        m = models[key]
        for d, dy in ((10.0, 0.0), (20.0, -1.0), (50.0, 0.5), (100.0, 0.0), (300.0, 2.0)):
            th, ok = game_ballistic_theta(d, dy, m["zero_speed"], m["gravity"], m["drag"], dt)
            th3, _ok3 = game_ballistic_theta_h3(d, dy, m["zero_speed"], m["gravity"], m["drag"], dt)
            cases.append({"weapon": key, "dist": d, "dy": dy, "speed": m["zero_speed"], "gravity": m["gravity"],
                          "drag": m["drag"], "theta_rad": round(th, 7), "reached": ok,
                          "theta_h3_rad": round(th3, 7)})
    return cases


# --- Output ---------------------------------------------------------------------------------------

def fmt(v, nd=0):
    if v is None:
        return "-"
    return f"{v:.{nd}f}" if isinstance(v, (int, float)) else str(v)


def md_game(game, title):
    L = [f"#### {title}: launch, reach and hits\n",
         "| weapon | full / quick m/s | g | drag | max range m (elev, time) | flat reach m | stance: cone deg -> D100 / D50 m on the 0.5 m disc (D50 man box) |",
         "|---|---|---|---|---|---|---|"]
    for key, r in game.items():
        mr = r["max_range"]
        mx = f"{mr['max_range_m']:.0f} ({mr['elevation_deg']:.1f} deg, {mr['flight_time_s']:.1f} s)"
        if "max_range_within_life_m" in mr:
            mx += f"; {mr['max_range_within_life_m']:.0f} before max_life"
        drag = f"{r['launch']['drag_per_s']}/s" + (f" + {r['launch']['drag_quadratic_per_m']}/m q" if r['launch']['drag_quadratic_per_m'] else "")
        sp = "; ".join(f"{st} {s['cone_deg']:.3g} -> {fmt(s['d100_m'])} / {fmt(s['d50_m'])} ({fmt(s['man_d50_m'])})"
                       for st, s in r["spread"].items())
        L.append(f"| {key} | {r['launch']['full_mps']:.0f} / {r['launch']['quick_mps']:.1f} | {r['launch']['gravity']} | "
                 f"{drag} | {mx} | {r['flat_reach_m']:.0f} | {sp} |")
    L += [f"\n#### {title}: zeroed full-power shot at 10 / 20 / 50 / 100 m (flight time, impact speed, damage, elevation)\n",
          "| weapon | 10 m | 20 m | 50 m | 100 m |", "|---|---|---|---|---|"]
    for key, r in game.items():
        cells = []
        for d in REPORT_DISTANCES:
            row = next(x for x in r["zeroed_shots"] if x["distance_m"] == d)
            if row["reachable"]:
                cells.append(f"{row['flight_time_s']:.2f} s, {row['impact_speed_mps']:.0f} m/s, {row['damage']:.0f} dmg ({row['elevation_deg']:.1f} deg)")
            elif row.get("unconverged"):
                cells.append(f"out of reach: leaves at {row['elevation_deg']:.0f} deg, lands {row['lands_at_m']:.0f} m")
            else:
                cells.append("out of reach" + (f" (straight-line throw lands {row['lands_at_m']:.0f} m)" if "lands_at_m" in row else ""))
        L.append(f"| {key} | " + " | ".join(cells) + " |")
    return "\n".join(L)


def md_reference(ref, val):
    L = ["#### Reference physics (quadratic drag): max range and the zeroed shot (flight time, impact speed)\n",
         "| weapon | v0 m/s | k /m at v0 | max range m (elev) | 10 m | 20 m | 50 m | 100 m |",
         "|---|---|---|---|---|---|---|---|"]
    for key, r in ref.items():
        for row in r["by_speed"]:
            cells = []
            for d in REPORT_DISTANCES:
                z = row["zeroed"].get(str(d))
                cells.append(f"{z['flight_time_s']:.2f} s, {z['impact_speed_mps']:.0f} m/s" if z else "out of reach")
            mr = row["max_range"]
            L.append(f"| {key} | {row['v0_mps']} | {row['k_per_m_at_v0']} | {mr['max_range_m']:.0f} ({mr['elevation_deg']:.0f} deg) | "
                     + " | ".join(cells) + " |")
    if val:
        L.append("\n#### Reference model validation\n")
        for k, v in val.items():
            L.append(f"- {k}: {json.dumps(v)}")
    return "\n".join(L)


def md_candidates(cands, cand_eval, title):
    L = [f"#### {title}\n",
         "| weapon | launch m/s | drag | max range m | spread_base deg | steady/crouch mult | D100 / D50 m (MC) | flight s to 10 / 20 / 50 / 100 m |",
         "|---|---|---|---|---|---|---|---|"]
    for key, c in cands.items():
        e = cand_eval[key]
        s = e["spread"]["stand"]
        ts = []
        for d in REPORT_DISTANCES:
            row = next(x for x in e["zeroed_shots"] if x["distance_m"] == d)
            ts.append(f"{row['flight_time_s']:.2f}" if row["reachable"] else "-")
        drag = f"{c['drag_quadratic_per_m']}/m" if c["drag_quadratic_per_m"] else f"{c['drag_per_s']}/s"
        L.append(f"| {key} | {c['launch_mps']:.0f} | {drag} | {e['max_range']['max_range_m']:.0f} | {c['spread_base_deg']} | "
                 f"{c['steady_or_crouch_mult']} | {fmt(s['d100_m'], 1)} / {fmt(s['d50_m'], 1)} | {' / '.join(ts)} |")
    return "\n".join(L)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=PROJECT)
    ap.add_argument("--override", help="JSON {weapon: {property: value}} merged over the script values")
    ap.add_argument("--weapon", help="only this weapon")
    ap.add_argument("--json", action="store_true", help="print the game evaluation as JSON")
    ap.add_argument("--no-reference", action="store_true", help="skip the (slower, ~1 min) reference model")
    ap.add_argument("--write", action="store_true", help="write data/weapons/range_research.json")
    ap.add_argument("--samples", type=int, default=SAMPLES["n"], help="Monte Carlo samples per distance")
    args = ap.parse_args()
    SAMPLES["n"] = args.samples

    overrides = None
    if args.override:
        with open(args.override, encoding="utf-8") as fh:
            overrides = json.load(fh)
    params, models, rate = load_game(args.root, overrides)
    dt = 1.0 / rate
    if args.weapon:
        models = {args.weapon: models[args.weapon]}
    game = evaluate_game(models, dt, np.random.default_rng(SEED))
    if args.json:
        print(json.dumps({"physics_ticks_per_second": rate, "game": game}, indent=1))
        return
    print(md_game(game, "Game (current values)" if not overrides else "Game (with overrides)"))
    if args.weapon:
        return

    with open(INPUT, encoding="utf-8") as fh:
        inp = json.load(fh)
    ref = val = None
    if not args.no_reference:
        ref = evaluate_reference(inp)
        val = validate_reference(inp)
        print("\n" + md_reference(ref, val))
    lin = fit_candidates(inp, models, dt)
    lin_eval = evaluate_game(candidate_models(lin, models), dt, np.random.default_rng(SEED))
    quad = fit_candidates(inp, models, dt, quadratic=True)
    quad_eval = evaluate_game(candidate_models(quad, models), dt, np.random.default_rng(SEED))
    print("\n" + md_candidates(lin, lin_eval, "Candidate A: linear drag (parameter changes only), g = 9.8"))
    print("\n" + md_candidates(quad, quad_eval, "Candidate B: with the quadratic drag hook, g = 9.8"))
    dec_a = compare_decay(lin_eval, ref) if ref else None
    dec_b = compare_decay(quad_eval, ref) if ref else None
    if dec_a:
        print("\n#### Impact speed / launch speed at 20 / 50 / 100 m: candidate A | candidate B | reference physics\n")
        print("| weapon | 20 m | 50 m | 100 m |\n|---|---|---|---|")
        for key in dec_a:
            cells = []
            for d in ("20", "50", "100"):
                a = dec_a[key]["at"].get(d)
                b = (dec_b or {}).get(key, {}).get("at", {}).get(d)
                cells.append(f"{a['game_speed_ratio']:.2f} / {b['game_speed_ratio']:.2f} / {a['reference_speed_ratio']:.2f}"
                             if a and b else "-")
            print(f"| {key} | " + " | ".join(cells) + " |")

    if args.write:
        doc = dict(inp)
        doc["schema"] = "frontier.range_research.v1"
        doc["generated_by"] = ("tools/weapons/range_sim.py --write (inputs: tools/weapons/range_research_input.json "
                               "+ scripts/weapons/*.gd)")
        doc["physics_ticks_per_second"] = rate
        doc["game_params"] = {k: {"class": p["class"], "files": p["files"],
                                  "values": {n: v for n, v in p["values"].items() if isinstance(v, (int, float, bool))}}
                              for k, p in params.items()}
        doc["game_current"] = game
        doc["reference_physics"] = ref
        doc["reference_validation"] = val
        doc["candidates"] = {
            "about": "Numbers that meet ladder_targets in the game's model. NOT applied; the balance step decides.",
            "A_linear": {"hook": "none: parameter changes only", "params": lin, "evaluation": lin_eval,
                         "decay_vs_reference": dec_a},
            "B_quadratic": {"hook": ("Projectile._physics_process, Weapon._height_at, TrajectoryPreview/ThrowableArc, "
                                     "ThrownProjectile (+ predict_impact): after the linear step, "
                                     "velocity /= 1.0 + drag_quadratic * velocity.length() * delta"),
                            "params": quad, "evaluation": quad_eval, "decay_vs_reference": dec_b},
        }
        doc["crosscheck"] = crosscheck_cases({k: v for k, v in models.items() if k in GAME_WEAPONS}, dt)
        os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
        with open(OUTPUT, "w", encoding="utf-8") as fh:
            json.dump(doc, fh, indent=1)
            fh.write("\n")
        print(f"\nwrote {os.path.relpath(OUTPUT, args.root)}", file=sys.stderr)


if __name__ == "__main__":
    main()
