"""Resolve every material used by the particle specs into flat parameter sets.

  python3 -I fx_materials.py DECODED_ROOT SPECS_DIR OUT.json

For each MaterialInstanceConstant / Material referenced by an emitter (Required
material, MeshMaterial modules, and a mesh's own StaticMaterials when the emitter
does not override them): walk Parent links to the root Material, then merge
parameter values -- the most-derived override wins, root expression DefaultValues
fill the rest. Records BlendMode / ShadingModel / TwoSided (BasePropertyOverrides
honoured), static switches, the root material's expression classes and the
material functions it calls. Parameter names are kept verbatim.
"""
import json
import sys
from pathlib import Path
from collections import Counter

ROOT = None
_cache = {}


def num(x):
    if isinstance(x, str) and x in ("+0", "-0"):
        return 0.0
    return x


def load(pkg_path):
    """pkg_path like /Game/VFX/Materials/M_X -> decoded json (or None)."""
    if pkg_path in _cache:
        return _cache[pkg_path]
    if pkg_path.startswith("/Game/"):
        rel = "g3/Content/" + pkg_path[len("/Game/"):]
    elif pkg_path.startswith("/Engine/"):
        rel = "Engine/Content/" + pkg_path[len("/Engine/"):]
    else:
        rel = pkg_path
    f = ROOT / (rel + ".json")
    d = json.loads(f.read_text()) if f.exists() else None
    _cache[pkg_path] = d
    return d


def imp_path(d, idx):
    """import index -> (object name, package path)."""
    if not idx or idx >= 0:
        return None, None
    imp = d["Imports"][-idx - 1]
    outer = imp.get("OuterIndex", 0)
    pkg = d["Imports"][-outer - 1]["ObjectName"] if outer and outer < 0 else None
    return imp["ObjectName"], pkg


def class_of(d, e):
    c = e.get("ClassIndex", 0)
    return d["Imports"][-c - 1]["ObjectName"] if c < 0 else None


def val(d, p):
    t = p.get("$type", "")
    v = p.get("Value")
    if "ObjectPropertyData" in t:
        if isinstance(v, int) and v < 0:
            name, pkg = imp_path(d, v)
            return {"object": name, "package": pkg}
        if isinstance(v, int) and v > 0:
            return {"export": d["Exports"][v - 1]["ObjectName"]}
        return None
    if p.get("EnumValue"):
        return p["EnumValue"]
    if isinstance(v, dict) and "R" in v:
        return [num(v[k]) for k in "RGBA"]
    if isinstance(v, list):
        if "ArrayPropertyData" in t:
            return [val(d, x) for x in v]
        return {x.get("Name"): val(d, x) for x in v if isinstance(x, dict)}
    return num(v)


def main_export(d, name):
    for e in d["Exports"]:
        if e["ObjectName"] == name:
            return e
    return d["Exports"][0]


def resolve(pkg_path):
    d = load(pkg_path)
    if d is None:
        return None
    name = pkg_path.rsplit("/", 1)[-1]
    e = main_export(d, name)
    cls = class_of(d, e)
    data = {p["Name"]: p for p in e.get("Data") or []}
    out = {"package": pkg_path, "class": cls, "chain": [pkg_path], "scalars": {}, "vectors": {}, "textures": {},
           "switches": {}, "blend_mode": None, "shading_model": None, "two_sided": None}
    if cls == "Material":
        out["blend_mode"] = val(d, data["BlendMode"]) if "BlendMode" in data else "BLEND_Opaque"
        out["shading_model"] = val(d, data["ShadingModel"]) if "ShadingModel" in data else "MSM_DefaultLit"
        out["two_sided"] = bool(data["TwoSided"]["Value"]) if "TwoSided" in data else False
        exprs, funcs = Counter(), set()
        for x in d["Exports"]:
            xc = class_of(d, x) or ""
            if not xc.startswith("MaterialExpression"):
                continue
            exprs[xc.replace("MaterialExpression", "")] += 1
            xd = {p["Name"]: p for p in x.get("Data") or []}
            pname = val(d, xd["ParameterName"]) if "ParameterName" in xd else None
            if xc == "MaterialExpressionMaterialFunctionCall" and "MaterialFunction" in xd:
                f = val(d, xd["MaterialFunction"])
                if f:
                    funcs.add(f.get("object"))
            if not pname:
                continue
            if xc.endswith("ScalarParameter"):
                out["scalars"].setdefault(pname, num(val(d, xd["DefaultValue"])) if "DefaultValue" in xd else 0.0)
            elif xc.endswith("VectorParameter"):
                out["vectors"].setdefault(pname, val(d, xd["DefaultValue"]) if "DefaultValue" in xd else [0, 0, 0, 0])
            elif "Texture" in xc and "Parameter" in xc:
                t = val(d, xd["Texture"]) if "Texture" in xd else None
                out["textures"].setdefault(pname, (t or {}).get("package"))
            elif "StaticSwitch" in xc or "StaticBool" in xc:
                out["switches"].setdefault(pname, bool(val(d, xd["DefaultValue"])) if "DefaultValue" in xd else False)
        # non-parameter texture samples (fixed textures inside the graph)
        fixed = []
        for x in d["Exports"]:
            xc = class_of(d, x) or ""
            if xc in ("MaterialExpressionTextureSample", "MaterialExpressionTextureObject"):
                xd = {p["Name"]: p for p in x.get("Data") or []}
                t = val(d, xd["Texture"]) if "Texture" in xd else None
                if t:
                    fixed.append(t.get("package"))
        out["fixed_textures"] = fixed
        out["expressions"] = dict(exprs)
        out["functions"] = sorted(f for f in funcs if f)
        out["root"] = pkg_path
        return out
    # MaterialInstance*
    parent = val(d, data["Parent"]) if "Parent" in data else None
    base = resolve(parent["package"]) if parent and parent.get("package") else None
    if base is None:
        out["root"] = None
        out["missing_parent"] = parent
        base = dict(out)
    out.update({k: base.get(k) for k in ("blend_mode", "shading_model", "two_sided", "root", "expressions", "functions", "fixed_textures")})
    out["chain"] = [pkg_path] + base.get("chain", [])
    out["scalars"] = dict(base.get("scalars", {}))
    out["vectors"] = dict(base.get("vectors", {}))
    out["textures"] = dict(base.get("textures", {}))
    out["switches"] = dict(base.get("switches", {}))
    for key, field in (("ScalarParameterValues", "scalars"), ("VectorParameterValues", "vectors"), ("TextureParameterValues", "textures")):
        if key not in data:
            continue
        for item in val(d, data[key]) or []:
            if not isinstance(item, dict):
                continue
            pname = (item.get("ParameterInfo") or {}).get("Name")
            v = item.get("ParameterValue")
            if field == "textures":
                v = (v or {}).get("package") if isinstance(v, dict) else v
            if pname is not None:
                out[field][pname] = v
    if "StaticParameters" in data:
        sp = val(d, data["StaticParameters"]) or {}
        for item in sp.get("StaticSwitchParameters") or []:
            if isinstance(item, dict) and item.get("bOverride", True):
                out["switches"][(item.get("ParameterInfo") or {}).get("Name")] = bool(item.get("Value"))
    if "BasePropertyOverrides" in data:
        bo = val(d, data["BasePropertyOverrides"]) or {}
        if bo.get("bOverride_BlendMode") or "BlendMode" in bo:
            out["blend_mode"] = bo.get("BlendMode", out["blend_mode"])
        if bo.get("bOverride_ShadingModel") or "ShadingModel" in bo:
            out["shading_model"] = bo.get("ShadingModel", out["shading_model"])
        if bo.get("bOverride_TwoSided") or "TwoSided" in bo:
            out["two_sided"] = bool(bo.get("TwoSided", out["two_sided"]))
    return out


def mesh_materials(pkg_path):
    d = load(pkg_path)
    if d is None:
        return []
    name = pkg_path.rsplit("/", 1)[-1]
    e = main_export(d, name)
    data = {p["Name"]: p for p in e.get("Data") or []}
    out = []
    for item in (val(d, data["StaticMaterials"]) if "StaticMaterials" in data else []) or []:
        if isinstance(item, dict):
            mi = item.get("MaterialInterface")
            out.append(mi.get("package") if isinstance(mi, dict) else None)
    return out


def main():
    global ROOT
    ROOT = Path(sys.argv[1])
    specs = Path(sys.argv[2])
    used, mesh_pkgs = {}, {}
    for f in specs.rglob("*.json"):
        if f.name == "index.json":
            continue
        sp = json.loads(f.read_text())
        for e in sp["emitters"]:
            mat = (e.get("required_raw") or {}).get("Material")
            if isinstance(mat, dict) and mat.get("pkg"):
                used[mat["pkg"]] = mat.get("import")
            if e["type"] == "mesh" and e.get("mesh"):
                td = e.get("type_data_raw") or {}
                mp = (td.get("Mesh") or {}).get("pkg") if isinstance(td.get("Mesh"), dict) else None
                if mp:
                    mesh_pkgs[mp] = e["mesh"]
            for m in e["modules"]:
                if m["class"] == "MeshMaterial":
                    for mm in m.get("MeshMaterials") or []:
                        if isinstance(mm, dict) and mm.get("pkg"):
                            used[mm["pkg"]] = mm.get("import")
    meshes = {}
    for mp, name in mesh_pkgs.items():
        mats = mesh_materials(mp)
        meshes[name] = {"package": mp, "materials": mats}
        for m in mats:
            if m:
                used[m] = m.rsplit("/", 1)[-1]
    mats, missing = {}, []
    for pkg, name in sorted(used.items()):
        r = resolve(pkg)
        if r is None:
            missing.append(pkg)
            continue
        mats[pkg.rsplit("/", 1)[-1]] = r
    roots = Counter(m.get("root") for m in mats.values())
    textures = sorted({t for m in mats.values() for t in list(m["textures"].values()) + (m.get("fixed_textures") or []) if t})
    json.dump({"materials": mats, "meshes": meshes, "missing": missing, "root_usage": roots.most_common(),
               "textures": textures}, open(sys.argv[3], "w"), indent=1)
    print(f"{len(mats)} materials resolved, {len(missing)} missing, {len(roots)} root materials, {len(textures)} textures, {len(meshes)} meshes")
    for r, c in roots.most_common(40):
        print(f"  {c:4d}  {r}")


if __name__ == "__main__":
    main()
