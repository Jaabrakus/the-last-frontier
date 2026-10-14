#!/usr/bin/env python3
"""WaterNetwork's maths in numpy (the twin of scripts/world/water/water_network.gd), over data/world/maps/r1/water.json
(build_water_json.py). For the region baker's carving (T4), the plots (plot_network.py) and the parity fixture the
GDScript test reads. Every query takes scalars or arrays of x and z (broadcast together) and returns arrays.

    from water_net import WaterNet
    net = WaterNet.load()                 # data/world/maps/r1/water.json, milestone M1, state S0, day 0
    net.set_milestone("M2")               # the lock step and the M2 pounds live (carving wants them all)
    net.surface_at(x, z)                  # the water's surface, NO_WATER (-inf) where there is none
    net.bed_at(x, z)                      # the bed a carve should reach (nan where there is no water)

  channel_at(x, z)          {"channel": id ("" none), "index" (-1 none), "s", "offset", "half_width"} (offset + on the right bank
                            looking downstream; a channel's water is |offset| <= half_width, past its ends none)
  surface_at, depth_at(x, z, ground), current_at -> (cx, cz) m/s, flow_scale_at, is_under_water(x, y, z)
  set_state(state) / set_reach_flow(reach_id, scale): flow x scale inside a reach, eased back to 1 over ease_m past its
                            ends
  pound_level_at(pound_id, day): a pound's level by bible days since the river stopped (its curve; flat without one)
  as_world_river_block(channel_id): the z-monotonic channel as WorldRiver nodes ({} for the torrent)
Where things overlap: an active pound wins, then the channels in rank order (the joined one first). A joining
channel's level eases onto the joined one's over its mouth (mouth_m outside the joined one's water).
"""
import json
import math
import os

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
WATER = os.path.join(ROOT, "data", "world", "maps", "r1", "water.json")
NO_WATER = -math.inf
BUCKET_M = 32.0


def _smooth01(u):
    u = np.clip(u, 0.0, 1.0)
    return u * u * (3.0 - 2.0 * u)


class _Channel:
    def __init__(self, d, reach_r):
        self.d = d
        self.id = d["id"]
        self.rank = int(d["rank"])
        n = np.asarray(d["nodes"], dtype=np.float64)
        self.s, self.x, self.z, self.hw, self.level, self.bed_depth, self.speed = (n[:, k] for k in range(7))
        self.exponent = float(d.get("bed", {}).get("exponent", 2.0))
        self.reaches = d.get("reaches", [])
        self.steps = d.get("steps", [])
        self.milestone = d.get("milestone", "M0")
        self.join = None                      # (into _Channel, mouth_m), set by WaterNet
        self.R = float(self.hw.max()) + reach_r
        self.buckets = {}
        for i in range(len(self.s) - 1):
            x0, x1 = sorted((self.x[i], self.x[i + 1]))
            z0, z1 = sorted((self.z[i], self.z[i + 1]))
            for cx in range(int(math.floor((x0 - self.R) / BUCKET_M)), int(math.floor((x1 + self.R) / BUCKET_M)) + 1):
                for cz in range(int(math.floor((z0 - self.R) / BUCKET_M)), int(math.floor((z1 + self.R) / BUCKET_M)) + 1):
                    self.buckets.setdefault((cx, cz), []).append(i)

    def locate(self, x, z):
        """Nearest centre-line point of every (x, z): segment i, t (0..1), signed offset, s, half_width, and `near`
        (inside the channel's bucket reach and not past either end; elsewhere the rest is meaningless)."""
        x = np.asarray(x, dtype=np.float64)
        z = np.asarray(z, dtype=np.float64)
        n = x.size
        if n == 0:
            e = np.zeros(x.shape)
            return {"seg": e.astype(np.int64), "t": e, "offset": e, "s": e, "half_width": e, "near": e.astype(bool)}
        xf, zf = x.ravel(), z.ravel()
        seg = np.zeros(n, dtype=np.int64)
        tt = np.zeros(n)
        off = np.full(n, np.inf)
        near = np.zeros(n, dtype=bool)
        cx = np.floor(xf / BUCKET_M).astype(np.int64)
        cz = np.floor(zf / BUCKET_M).astype(np.int64)
        keys = cx * 1000003 + cz
        order = np.argsort(keys, kind="stable")
        ks = keys[order]
        starts = np.flatnonzero(np.r_[True, ks[1:] != ks[:-1]])
        ends = np.r_[starts[1:], n]
        last = len(self.s) - 2
        for a, b in zip(starts, ends):
            idx = order[a:b]
            segs = self.buckets.get((int(cx[idx[0]]), int(cz[idx[0]])))
            if not segs:
                continue
            sg = np.asarray(segs)
            ax, az = self.x[sg][None, :], self.z[sg][None, :]
            dx, dz = self.x[sg + 1][None, :] - ax, self.z[sg + 1][None, :] - az
            L2 = dx * dx + dz * dz
            px, pz = xf[idx][:, None], zf[idx][:, None]
            traw = ((px - ax) * dx + (pz - az) * dz) / L2
            t = np.clip(traw, 0.0, 1.0)
            qx, qz = ax + t * dx, az + t * dz
            d2 = (px - qx) ** 2 + (pz - qz) ** 2
            k = np.argmin(d2, axis=1)                    # the first of equals: the lowest segment, as the GDScript
            rows = np.arange(len(idx))
            i = sg[k]
            tk = t[rows, k]
            trk = traw[rows, k]
            L = np.sqrt(L2[0, k])
            side = (px[:, 0] - qx[rows, k]) * (-dz[0, k] / L) + (pz[:, 0] - qz[rows, k]) * (dx[0, k] / L)
            dist = np.sqrt(d2[rows, k])
            seg[idx] = i
            tt[idx] = tk
            off[idx] = np.where(side >= 0.0, dist, -dist)
            near[idx] = ~(((i == 0) & (trk < 0.0)) | ((i == last) & (trk > 1.0)))
        s = self.s[seg] + tt * (self.s[seg + 1] - self.s[seg])
        hw = self.hw[seg] + tt * (self.hw[seg + 1] - self.hw[seg])
        shp = x.shape
        return {"seg": seg.reshape(shp), "t": tt.reshape(shp), "offset": off.reshape(shp), "s": s.reshape(shp),
                "half_width": hw.reshape(shp), "near": near.reshape(shp)}

    def field(self, arr, seg, t):
        return arr[seg] + t * (arr[seg + 1] - arr[seg])

    def at_s(self, arr, s):
        return np.interp(s, self.s, arr)


class WaterNet:
    def __init__(self, data):
        self.data = data
        self.milestones = data.get("milestones", ["M0", "M1", "M2"])
        mouth = max([float(j.get("mouth_m", 0.0)) for j in data.get("junctions", [])] + [0.0])
        self.channels = sorted((_Channel(c, mouth + 2.0) for c in data["channels"]), key=lambda c: c.rank)
        self.by_id = {c.id: c for c in self.channels}
        for j in data.get("junctions", []):
            self.by_id[j["channel"]].join = (self.by_id[j["into"]], float(j["mouth_m"]))
        self.pounds = data.get("pounds", [])
        self.pound_by_id = {p["id"]: p for p in self.pounds}
        self.curves = data.get("curves", {})
        self.reach_scale = {}
        self.milestone = 1
        self.day = 0.0
        self.set_state("S0")

    @classmethod
    def load(cls, path=WATER):
        with open(path, encoding="utf-8") as fh:
            return cls(json.load(fh))

    # --- world state ---------------------------------------------------------------------------------------------

    def set_milestone(self, m):
        self.milestone = self.milestones.index(m)

    def _live(self, m):
        return self.milestones.index(m) <= self.milestone

    def set_state(self, state):
        for c in self.channels:
            for r in c.reaches:
                self.reach_scale[r["id"]] = float(r.get("scale_by_state", {}).get(state, 1.0))

    def set_reach_flow(self, reach_id, scale):
        self.reach_scale[reach_id] = float(scale)

    def set_day(self, day):
        self.day = float(day)

    def pound_level_at(self, pound_id, day):
        p = self.pound_by_id[pound_id]
        lv = float(p["level"])
        cv = self.curves.get(p.get("curve", ""), None)
        if cv is None:
            return np.full(np.shape(day), lv) if np.ndim(day) else lv
        n = np.asarray(cv["nodes"], dtype=np.float64)
        d = np.maximum(np.asarray(day, dtype=np.float64), 0.0)
        out = lv + np.interp(d, n[:, 0], n[:, 1])
        return out if np.ndim(day) else float(out)

    # --- along a channel -----------------------------------------------------------------------------------------

    def flow_factor(self, ch, s):
        f = np.ones_like(np.asarray(s, dtype=np.float64))
        for r in ch.reaches:
            d = np.maximum(np.maximum(r["s_from"] - s, s - r["s_to"]), 0.0)
            ease = max(float(r["ease_m"]), 1e-6)
            w = 1.0 - _smooth01(d / ease)
            f = f * (1.0 + (self.reach_scale.get(r["id"], 1.0) - 1.0) * w)
        return f

    def channel_level(self, ch, seg, t, s):
        lv = ch.field(ch.level, seg, t)
        for st in ch.steps:
            if self._live(st.get("milestone", "M2")):
                lv = np.where((s >= st["s_upper"]) & (s < st["s_lower"]), st["level_upper"], lv)
        return lv

    def level_at_s(self, channel_id, s):
        ch = self.by_id[channel_id]
        s = np.asarray(s, dtype=np.float64)
        seg = np.clip(np.searchsorted(ch.s, s, side="right") - 1, 0, len(ch.s) - 2)
        t = np.clip((s - ch.s[seg]) / (ch.s[seg + 1] - ch.s[seg]), 0.0, 1.0)
        return self.channel_level(ch, seg, t, s)

    # --- queries -------------------------------------------------------------------------------------------------

    def _pound_mask(self, p, x, z):
        poly = p["polygon"]
        inside = np.zeros(np.broadcast(x, z).shape, dtype=bool)
        n = len(poly)
        for k in range(n):
            ax, az = poly[k]
            bx, bz = poly[(k + 1) % n]
            cross = ((az > z) != (bz > z))
            xi = ax + (z - az) * (bx - ax) / ((bz - az) if bz != az else 1e-12)
            inside ^= cross & (x < xi)
        return inside

    def _resolve(self, x, z):
        """Per point: which body (pound index, or channel), its level, and the channel location."""
        x, z = np.broadcast_arrays(np.asarray(x, dtype=np.float64), np.asarray(z, dtype=np.float64))
        shp = x.shape
        surf = np.full(shp, NO_WATER)
        pound = np.full(shp, -1, dtype=np.int64)
        chan = np.full(shp, -1, dtype=np.int64)
        done = np.zeros(shp, dtype=bool)
        for k, p in enumerate(self.pounds):
            if not self._live(p.get("milestone", "M1")):
                continue
            m = self._pound_mask(p, x, z) & ~done
            surf[m] = self.pound_level_at(p["id"], self.day)
            pound[m] = k
            done |= m
        locs = {}
        for ci, ch in enumerate(self.channels):
            if not self._live(ch.milestone):
                continue
            loc = ch.locate(x, z)
            locs[ci] = loc
            inside = loc["near"] & (np.abs(loc["offset"]) <= loc["half_width"])
            m = inside & ~done & (chan < 0)
            chan[m] = ci
            if not m.any():
                continue
            lv = self.channel_level(ch, loc["seg"][m], loc["t"][m], loc["s"][m])
            if ch.join is not None and self._live(ch.join[0].milestone):
                into, mouth = ch.join
                li = into.locate(x[m], z[m])
                dbank = np.abs(li["offset"]) - li["half_width"]
                w = np.where(li["near"], 1.0 - _smooth01(dbank / mouth), 0.0)
                lv_into = self.channel_level(into, li["seg"], li["t"], li["s"])
                lv = lv + (lv_into - lv) * w
            surf[m] = lv
        return x, z, surf, pound, chan, locs

    def channel_at(self, x, z):
        x, z, _, _, chan, locs = self._resolve_channels_only(x, z)
        s = np.full(x.shape, np.nan)
        off = np.full(x.shape, np.nan)
        hw = np.full(x.shape, np.nan)
        for ci, loc in locs.items():
            m = chan == ci
            s[m], off[m], hw[m] = loc["s"][m], loc["offset"][m], loc["half_width"][m]
        ids = np.array([c.id for c in self.channels] + [""], dtype=object)[chan]
        return {"channel": ids, "index": chan, "s": s, "offset": off, "half_width": hw}

    def _resolve_channels_only(self, x, z):
        x, z = np.broadcast_arrays(np.asarray(x, dtype=np.float64), np.asarray(z, dtype=np.float64))
        chan = np.full(x.shape, -1, dtype=np.int64)
        locs = {}
        for ci, ch in enumerate(self.channels):
            if not self._live(ch.milestone):
                continue
            loc = ch.locate(x, z)
            locs[ci] = loc
            m = loc["near"] & (np.abs(loc["offset"]) <= loc["half_width"]) & (chan < 0)
            chan[m] = ci
        return x, z, None, None, chan, locs

    def surface_at(self, x, z):
        return self._resolve(x, z)[2]

    def depth_at(self, x, z, ground):
        x, z, surf, _, _, _ = self._resolve(x, z)
        g = np.asarray(ground(x, z), dtype=np.float64)
        return np.where(np.isfinite(surf), np.maximum(surf - g, 0.0), 0.0)

    def is_under_water(self, x, y, z):
        return np.asarray(y, dtype=np.float64) < self.surface_at(x, z)

    def flow_scale_at(self, x, z):
        """1 where the water runs as ever, the reach's scale (0: still) inside a reach, eased between; 0 on a pound or
        where there is no water."""
        x, z, _, pound, chan, locs = self._resolve(x, z)
        out = np.zeros(x.shape)
        for ci, loc in locs.items():
            m = (chan == ci) & (pound < 0)
            out[m] = self.flow_factor(self.channels[ci], loc["s"][m])
        return out

    def current_at(self, x, z):
        """(cx, cz) m/s: along the channel's centre line, its speed there x the reach's flow; 0 on a pound."""
        x, z, _, pound, chan, locs = self._resolve(x, z)
        cx = np.zeros(x.shape)
        cz = np.zeros(x.shape)
        for ci, loc in locs.items():
            ch = self.channels[ci]
            m = (chan == ci) & (pound < 0)
            seg, t = loc["seg"][m], loc["t"][m]
            dx, dz = ch.x[seg + 1] - ch.x[seg], ch.z[seg + 1] - ch.z[seg]
            L = np.sqrt(dx * dx + dz * dz)
            v = ch.field(ch.speed, seg, t) * self.flow_factor(ch, loc["s"][m])
            cx[m], cz[m] = dx / L * v, dz / L * v
        return cx, cz

    def bed_at(self, x, z):
        """The bed under the water a carve should reach: a pound's flat bed, or the channel's cross-section under its
        level (the step's held level aside); nan where there is no water."""
        x, z, surf, pound, chan, locs = self._resolve(x, z)
        out = np.full(x.shape, np.nan)
        for k, p in enumerate(self.pounds):
            out[pound == k] = float(p["bed"])
        for ci, loc in locs.items():
            ch = self.channels[ci]
            m = (chan == ci) & (pound < 0)
            seg, t = loc["seg"][m], loc["t"][m]
            lv = ch.field(ch.level, seg, t)
            if ch.join is not None:
                # the mouth's eased level, as the surface has it (no step on a joining channel)
                lv = np.minimum(lv, surf[m])
            u = np.minimum(np.abs(loc["offset"][m]) / loc["half_width"][m], 1.0)
            out[m] = lv - ch.field(ch.bed_depth, seg, t) * (1.0 - u ** ch.exponent)
        return out

    # --- for WorldRiver (Phase 3 M0) -----------------------------------------------------------------------------

    def as_world_river_block(self, channel_id):
        ch = self.by_id.get(channel_id)
        if ch is None or not ch.d.get("z_monotonic", False):
            return {}
        return {
            "channel": ch.id,
            "nodes": [[float(a), float(b), float(c), float(d)] for a, b, c, d in zip(ch.z, ch.x, ch.level, ch.hw)],
            "node_fields": ["z", "x", "level", "half_width"],
            "bank": float(ch.hw.max()),
            "reaches": [{"id": r["id"], "z_from": r["z_from"], "z_to": r["z_to"], "ease_m": r["ease_m"],
                         "scale_by_state": dict(r["scale_by_state"])} for r in ch.reaches],
            "rapids": [],
        }


def world_river_eval(block, z):
    """What WorldRiver's node extension would read off a block: x(z) and level(z), linear between nodes."""
    n = np.asarray(block["nodes"], dtype=np.float64)
    return np.interp(z, n[:, 0], n[:, 1]), np.interp(z, n[:, 0], n[:, 2])
