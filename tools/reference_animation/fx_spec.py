"""Batch: decoded ParticleSystem packages -> Godot-lab runtime specs.

  python3 -I fx_spec.py DECODED_ROOT OUT_DIR [--only SUBSTRING]

For each decoded package whose export class is ParticleSystem: resolve emitters
and LOD 0 modules (build_fx_recipe.recipe), flatten UAssetAPI properties, keep
every distribution's baked lookup table, and write OUT_DIR/<package path>.json.
OUT_DIR/index.json summarises emitters, materials, meshes and module classes.
Values stay in UE units/axes; disabled emitters and modules are kept and flagged.
"""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from build_fx_recipe import recipe


imports = []
exports = []

def ref(i):
    if not isinstance(i, int) or i == 0:
        return None
    if i < 0:
        imp = imports[-i - 1]
        outer = imp.get("OuterIndex", 0)
        pkg = ref(outer) if outer else None
        return {"import": imp["ObjectName"], "class": imp["ClassName"], "pkg": pkg if isinstance(pkg, str) else (pkg or {}).get("import")}
    ex = exports[i - 1]
    return {"export": i, "name": ex["ObjectName"]}


def val(p):
    t = p.get("$type", "")
    v = p.get("Value")
    if "ObjectPropertyData" in t:
        return ref(v)
    if "BytePropertyData" in t:
        return p.get("EnumValue") if p.get("ByteType") == "FName" else v
    if isinstance(v, list):
        if "ArrayPropertyData" in t:
            return [val(x) for x in v]
        return props(v)
    if t.endswith("VectorPropertyData, UAssetAPI") or "Vector" in t and isinstance(v, dict):
        return v
    return v


def props(lst):
    out = {}
    for p in lst or []:
        if not isinstance(p, dict) or "Name" not in p:
            continue
        out[p["Name"]] = val(p)
    return out


def export_props(idx):
    ex = exports[idx - 1]
    return props(ex.get("Data"))


def resolve(o, depth=0):
    """Inline exported distribution objects."""
    if depth > 6:
        return o
    if isinstance(o, dict):
        if "export" in o and len(o) == 2:
            ex = exports[o["export"] - 1]
            ci = ex.get("ClassIndex", 0)
            cls = ref(ci)
            d = {"__class": (cls or {}).get("import"), "__name": ex["ObjectName"]}
            d.update(resolve(export_props(o["export"]), depth + 1))
            return d
        return {k: resolve(v, depth + 1) for k, v in o.items()}
    if isinstance(o, list):
        return [resolve(x, depth + 1) for x in o]
    return o


def module(m):
    if not m:
        return None
    d = {"__class": m["class"], "__name": m["name"]}
    d.update(resolve(props(m["properties"])))
    return d


def emitter_flat(e):
    out = {"name": e["name"], "props": resolve(props(e["properties"])), "lods": []}
    for lod in e["lods"][:1]:
        out["lods"].append({
            "required": module(lod.get("required")),
            "spawn": module(lod.get("spawn")),
            "type_data": module(lod.get("type_data")),
            "modules": [module(m) for m in lod.get("modules", [])],
        })
    out["props"].pop("LODLevels", None)
    return out


def flatten(src):
    global imports, exports
    imports, exports = src["imports"], src["exports"]
    res = {"emitters": [emitter_flat(e) for e in src["emitters"]], "system": None}
    for ex in exports:
        cls = ref(ex.get("ClassIndex", 0))
        if cls and cls.get("import") == "ParticleSystem":
            p = props(ex.get("Data"))
            p.pop("Emitters", None)
            res["system"] = resolve(p)
    return res


def num(x):
    if isinstance(x, str) and x in ("+0", "-0"):
        return 0.0
    return x


def vec(o):
    """FVector / FVector2D wrappers -> list."""
    while isinstance(o, dict) and len(o) == 1 and isinstance(next(iter(o.values())), dict):
        o = next(iter(o.values()))
    if isinstance(o, dict) and "X" in o:
        return [num(o[k]) for k in ("X", "Y", "Z") if k in o]
    return o


def table(o):
    """A RawDistribution* struct -> {op,n,stride,sub,ts,tb,v}."""
    if not isinstance(o, dict):
        return None
    t = o.get("Table")
    if isinstance(t, dict) and "Values" in t:
        stride = t.get("EntryStride", 1)
        op = t.get("Op", 1)
        return {"op": op, "n": t.get("EntryCount", 1), "stride": stride,
                "sub": t.get("SubEntryStride") or (stride // 2 if op in (2, 3) else stride),
                "ts": num(t.get("TimeScale", 0.0)) or 0.0, "tb": num(t.get("TimeBias", 0.0)) or 0.0,
                "v": [num(x) for x in t["Values"]]}
    d = o.get("Distribution")
    if isinstance(d, dict):
        c = d.get("__class")
        if c == "DistributionFloatConstant":
            return {"op": 1, "n": 1, "stride": 1, "sub": 1, "ts": 0.0, "tb": 0.0, "v": [num(d.get("Constant", 0.0))]}
        if c == "DistributionFloatUniform":
            return {"op": 2, "n": 1, "stride": 2, "sub": 1, "ts": 0.0, "tb": 0.0, "v": [num(d.get("Min", 0.0)), num(d.get("Max", 0.0))]}
        if c == "DistributionFloatConstantCurve":
            pts = d.get("ConstantCurve", {}).get("Points", [])
            return {"op": 1, "n": 1, "stride": 1, "sub": 1, "ts": 0.0, "tb": 0.0, "v": [num(pts[0]["OutVal"]) if pts else 0.0], "curve": True}
    return None


def ref_name(o):
    return o.get("import") if isinstance(o, dict) else None


def emitter(e, system):
    lod = e["lods"][0]
    req = lod["required"] or {}
    spawn = lod["spawn"] or {}
    td = lod["type_data"]
    out = {
        "system": system,
        "name": e["name"],
        "enabled": req.get("bEnabled", True) is not False,
        "render_mode": e["props"].get("EmitterRenderMode", "ERM_Normal"),
        "material": ref_name(req.get("Material")),
        "local_space": bool(req.get("bUseLocalSpace", False)),
        "origin": vec(req.get("EmitterOrigin")) or [0.0, 0.0, 0.0],
        "alignment": req.get("ScreenAlignment", "PSA_Square"),
        "sort": req.get("SortMode", "PSORTMODE_None"),
        "duration": num(req.get("EmitterDuration", 1.0)),
        "duration_low": num(req.get("EmitterDurationLow", 0.0)),
        "loops": req.get("EmitterLoops", 0),
        "delay": num(req.get("EmitterDelay", 0.0)),
        "delay_low": num(req.get("EmitterDelayLow", 0.0)),
        "delay_first_only": bool(req.get("bDelayFirstLoopOnly", False)),
        "kill_on_deactivate": bool(req.get("bKillOnDeactivate", False)),
        "kill_on_completed": bool(req.get("bKillOnCompleted", False)),
        "subuv": [req.get("SubImages_Horizontal", 1), req.get("SubImages_Vertical", 1)],
        "subuv_method": req.get("InterpolationMethod", "PSUVIM_None"),
        "random_image_time": num(req.get("RandomImageTime", 1.0)),
        "max_draw": req.get("MaxDrawCount", -1),
        "uv_flip": req.get("UVFlippingMode", "EParticleUVFlipMode::None"),
        "legacy_spawn": bool(e["props"].get("bUseLegacySpawningBehavior", False)),
        "rate": table(spawn.get("Rate")),
        "rate_scale": table(spawn.get("RateScale")),
        "bursts": [{"count": b.get("Count", 0), "low": b.get("CountLow", -1), "time": num(b.get("Time", 0.0))} for b in spawn.get("BurstList", [])],
        "burst_scale": table(spawn.get("BurstScale")),
        "type": "sprite",
        "modules": [],
    }
    if td:
        c = td["__class"]
        out["type_data_class"] = c
        out["type_data_raw"] = compact({k: v for k, v in td.items() if not k.startswith("__")})
        if c == "ParticleModuleTypeDataGpu":
            out["type"] = "sprite"
            out["gpu"] = True
        elif c == "ParticleModuleTypeDataBeam2":
            out["type"] = "beam"
        elif c == "ParticleModuleTypeDataAnimTrail":
            out["type"] = "anim_trail"
        if c == "ParticleModuleTypeDataMesh":
            out["type"] = "mesh"
            out["mesh"] = ref_name(td.get("Mesh"))
            out["mesh_alignment"] = td.get("MeshAlignment", "PSMA_MeshFaceCameraWithRoll")
            out["override_material"] = bool(td.get("bOverrideMaterial", False))
            out["axis_lock"] = td.get("AxisLockOption", "EPAL_NONE")
            out["camera_facing"] = bool(td.get("bCameraFacing", False))
        elif c == "ParticleModuleTypeDataRibbon":
            out["type"] = "ribbon"
            out["ribbon"] = {"tiling": num(td.get("TilingDistance", 0.0)),
                             "tess_step": num(td.get("DistanceTessellationStepSize", 15.0)),
                             "spawn_initial": bool(td.get("bSpawnInitialParticle", False)),
                             "max_trails": td.get("MaxTrailCount", 1),
                             "max_particles": td.get("MaxParticleInTrailCount", 500),
                             "render_axis": td.get("RenderAxis", "Trails_CameraUp")}
    for m in lod["modules"]:
        if not m:
            continue
        rec = {"class": m["__class"].replace("ParticleModule", ""), "enabled": m.get("bEnabled", True) is not False}
        for k, v in m.items():
            if k.startswith("__") or k in ("bEnabled",):
                continue
            t = table(v) if isinstance(v, dict) else None
            if t is not None:
                rec[k] = t
            elif k == "DynamicParams":
                rec[k] = [{"name": p["ParamName"], "value": table(p["ParamValue"]) or table({"Table": p["ParamValue"]}) if isinstance(p.get("ParamValue"), dict) else None,
                           "method": p.get("ValueMethod")} for p in v]
            else:
                rec[k] = vec(v) if isinstance(v, dict) else num(v)
        out["modules"].append(rec)
    return out


def fix_dynamic(rec):
    # ParamValue already compacted by table() when it carries "Table"; flattened form puts op/n directly.
    for p in rec.get("DynamicParams", []):
        if p["value"] is None:
            p["value"] = {"op": 1, "n": 1, "stride": 1, "sub": 1, "ts": 0.0, "tb": 0.0, "v": [1.0]}


def compact(o):
    if isinstance(o, dict):
        t = table(o)
        if t is not None and ("Table" in o or "Distribution" in o):
            return t
        v = vec(o)
        if isinstance(v, list):
            return v
        return {k: compact(x) for k, x in o.items() if k not in ("LODValidity",)}
    if isinstance(o, list):
        return [compact(x) for x in o]
    return num(o)


def build_spec(decoded_path, rel):
    src = recipe(decoded_path)
    flat = flatten(src)
    ems = []
    for e in flat["emitters"]:
        if not e["lods"] or not e["lods"][0]["required"]:
            continue
        em = emitter(e, "main")
        for m in em["modules"]:
            fix_dynamic(m)
        em["required_raw"] = compact({k: v for k, v in e["lods"][0]["required"].items() if not k.startswith("__")})
        ems.append(em)
    sysd = flat.get("system") or {}
    return {"package": rel, "system": compact(sysd), "emitters": ems}


def is_particle_system(path):
    with open(path) as f:
        head = f.read(200000)
    return '"ParticleSystem"' in head


def main():
    root, out = Path(sys.argv[1]), Path(sys.argv[2])
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    out.mkdir(parents=True, exist_ok=True)
    index, failures = [], []
    for p in sorted(root.rglob("*.json")):
        rel = str(p.relative_to(root).with_suffix(""))
        if only and only not in rel:
            continue
        if p.name == "decode_report.json" or not is_particle_system(p):
            continue
        try:
            d = json.load(open(p))
            if not any(i.get("ObjectName") == "ParticleSystem" and i.get("ClassName") == "Class" for i in d.get("Imports", [])):
                continue
            sp = build_spec(p, rel)
        except AssertionError:
            continue
        except Exception as ex:
            failures.append({"package": rel, "error": repr(ex)[:300]})
            continue
        dest = out / (rel + ".json")
        dest.parent.mkdir(parents=True, exist_ok=True)
        json.dump(sp, open(dest, "w"))
        index.append({"package": rel, "emitters": [
            {"name": e["name"], "enabled": e["enabled"], "type": e["type"], "material": e["material"], "mesh": e.get("mesh"),
             "modules": [m["class"] + ("" if m["enabled"] else "(off)") for m in e["modules"]]} for e in sp["emitters"]]})
    json.dump({"systems": index, "failures": failures}, open(out / "index.json", "w"), indent=1)
    print(f"{len(index)} systems, {len(failures)} failures")
    for f in failures[:10]:
        print(f)


if __name__ == "__main__":
    main()
