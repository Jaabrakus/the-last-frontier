"""Import rebuilt Spellbreak Cascade effects into the game (res://assets/fx/spellbreak/).

  python3 -I tools/fx/import_spellbreak_fx.py [EFFECT_ID ...] [--element earth|water|fire|air|all]
                                              [--src artifacts/spellbreak_fx] [--dst assets/fx/spellbreak] [--dry-run]
  python3 -I tools/fx/import_spellbreak_fx.py --status [--dst assets/fx/spellbreak]

EFFECT_ID is the source package path, e.g. g3/Content/VFX/Character/Fire/Fireball_Base_Projectile01_FxP
(the runtime's stable id), or #N for row N of the browser's specs/index.json.
--element reads artifacts/spellbreak_fx/bending_fx_map.json and imports the FIRST pick of every final row
(elements.<el>.final[*].picks[0]) and records each row's move / role / slot as a use of that effect.

For each effect it copies, from the Spellbreak FX browser (artifacts/spellbreak_fx, a separate Godot project):
  specs/<id>.json                    the runtime spec (tools/reference_animation/fx_spec.py), unchanged
  materials.json                     only the materials / meshes entries the effect's ENABLED emitters use
                                     (the same lookup as CascadeMaterials.material_record), merged
  assets/<package path>.png|.gltf    a shared pool mirroring the source package tree (/Game/, /Engine/ dropped):
                                     every texture the used materials name (parameters + fixed graph textures)
                                     and every particle mesh (+ its .bin buffers)
  index.json                         effect id -> spec, uses (element / move / role), materials, textures, meshes
  SOURCE.md                          one provenance row per effect (appended once) and a rewritten section listing
                                     the effects that use files from MarketplaceAssets/ packs (third-party, inside
                                     the client)
and writes a Godot .import for each new texture: VRAM compressed (S3TC/DXT, as the source game shipped them; the
browser's lossless import would take ~6x the video memory) with mipmaps and no 3D detection, plus each texture's
alpha flag in materials.json `texture_alpha` (what the browser read from the lossless image; CascadeMaterials uses
it because a compressed image cannot answer). Idempotent: running it again changes nothing
unless the source changed. Then run Godot's import (tools/loop/godot_run.sh --headless --path . --import).

--status (read only; needs no source folder) prints, for every imported effect, what the game's data really does with it:
"wired" (the element, move key and role of every entry of data/bending/sb_fx/<element>.json that names it), "unwired" (a row the
tuners left out, with why) or "not referenced", next to the browser-map picks that SOURCE.md's "Map pick (provenance)" column records
(bending_fx_map.json's first picks, which the tuners replaced in places). A markdown table: paste it into SOURCE.md's wiring
column.

Source: Spellbreak (Proletariat), community Windows client; see SOURCE.md next to the imported files.
"""
import argparse
import json
import shutil
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC_DEFAULT = ROOT / "artifacts" / "spellbreak_fx"
DST_DEFAULT = ROOT / "assets" / "fx" / "spellbreak"
ELEMENTS = ["earth", "water", "fire", "air"]

TEXTURE_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""

SOURCE_HEADER = """# Spellbreak effects imported into Tidebreak

Everything under `assets/fx/spellbreak/` is taken from **Spellbreak** by **Proletariat Inc.** (Unreal Engine 4.22
Cascade particle systems, their textures, particle meshes and material parameter values), extracted from the
community Windows client. It is third-party content, not Tidebreak's own art. Keep this attribution with it.

- **Source archive:** the verified full-client backup `spellbreak-client-source.zip` (sha256 82a604de...439d), now
  on the external drive "The one" (`/Volumes/The one/Frontier_offload/Spellbreak_source_backup/`); see
  `docs/claude_fx_handoff.md` ("Source folder retirement / full backup").
- **Conversion:** `tools/reference_animation/extract_fx_closure_from_zip.py` (package closure),
  `fx_spec.py` (one runtime spec per particle system, the source's own baked distribution tables),
  `fx_materials.py` (material instances resolved through their parent chains),
  `artifacts/spellbreak_fx/tools/export_assets.py` (UE Viewer export: textures as PNG, meshes as glTF).
  Copied here by `tools/fx/import_spellbreak_fx.py`; files are unchanged copies of the browser's exports.
- **What is authored here (not Spellbreak's):** the shader math in `shaders/cascade/` and the family mappings in
  `data/fx/cascade_families/` (the cooked material graphs were stripped; see `artifacts/spellbreak_fx/README.md`),
  and the Cascade runtime `scripts/fx/cascade/`.
- **Licence:** the owner's note in `animations/SOURCE.md` (section "Elemental presentation polish (2026-10-08)",
  last line, "Spellbreak licence (2026-10-08)") records that Proletariat licensed all Spellbreak assets for use in
  Tidebreak, including public release. That note's pointer to the written grant still reads "[where you keep it]":
  the grant's location is not recorded in the repository yet. This file records attribution; it is not itself a
  licence.

## Imported effects

One row per effect (source package = the runtime id used by `SpellFx.spawn`). Files: the effect's spec in
`specs/<id>.json`; its textures and meshes are in the shared pool `assets/` (paths mirror the source packages) and
listed per effect in `index.json`.

| Effect id (source package) | Source | Map pick (provenance: bending_fx_map.json first picks, not what the game wires: `--status`) | Textures | Meshes | Imported |
| --- | --- | --- | --- | --- | --- |
"""


THIRD_BEGIN = "<!-- third-party-packs: begin (rewritten by tools/fx/import_spellbreak_fx.py) -->"
THIRD_END = "<!-- third-party-packs: end -->"


def third_party_section(idx: dict) -> str:
    """Files the client keeps under MarketplaceAssets/<pack>/ (Unreal Marketplace packs inside Spellbreak): which effects
    use them. Rewritten on every run between the markers, placed before "## Imported effects"."""
    packs = {}
    for eid, row in idx["effects"].items():
        for f in row.get("textures", []) + row.get("meshes", []):
            parts = f.split("/")
            if len(parts) > 2 and parts[1] == "MarketplaceAssets":
                rec = packs.setdefault(parts[2], {"effects": set(), "files": set()})
                rec["effects"].add(eid)
                rec["files"].add(f)
    out = [THIRD_BEGIN, "## Third-party packs inside the Spellbreak client", ""]
    out.append("The client keeps some files under `MarketplaceAssets/<pack>/`. The folder name suggests content from "
               "Unreal Engine Marketplace packs by third-party authors rather than Proletariat's own art; the repository "
               "does not record their authors or terms, nor whether the Spellbreak licence noted in `animations/SOURCE.md` "
               "covers redistributing them. Check before a public release.")
    out.append("")
    if not packs:
        out.append("None of the imported effects uses such files.")
    else:
        out.append("| Pack | Effects using it | Files |")
        out.append("| --- | --- | --- |")
        for pack in sorted(packs):
            rec = packs[pack]
            effects = ", ".join(f"`{e.rsplit('/', 1)[-1]}`" for e in sorted(rec["effects"]))
            out.append(f"| `{pack}` | {effects} | {len(rec['files'])} textures/meshes (`assets/MarketplaceAssets/{pack}/`) |")
    out.append(THIRD_END)
    return "\n".join(out) + "\n\n"


def with_third_party(text: str, idx: dict) -> str:
    section = third_party_section(idx)
    if THIRD_BEGIN in text and THIRD_END in text:
        a = text.index(THIRD_BEGIN)
        b = text.index(THIRD_END) + len(THIRD_END)
        while b < len(text) and text[b] == "\n":
            b += 1
        return text[:a] + section + text[b:]
    at = text.find("## Imported effects")
    return text[:at] + section + text[at:] if at >= 0 else text + "\n" + section


def rel_from_pkg(pkg: str) -> str:
    """'/Game/VFX/X' -> 'VFX/X', '/Engine/EngineMeshes/Y' -> 'EngineMeshes/Y' (CascadeMaterials.res_path)."""
    if pkg.startswith("/Game/"):
        return pkg[6:]
    if pkg.startswith("/Engine/"):
        return pkg[8:]
    return pkg.lstrip("/")


def material_names(spec: dict, meshes: dict) -> list:
    """Material names each enabled emitter renders with (CascadeMaterials.material_record)."""
    out = []
    for e in spec.get("emitters", []):
        if not e.get("enabled"):
            continue
        name = str(e.get("material") or "")
        if e.get("type") == "mesh" and not e.get("override_material", True):
            for p in meshes.get(str(e.get("mesh") or ""), {}).get("materials", []):
                if p:
                    name = str(p).rsplit("/", 1)[-1]
                    break
        for m in e.get("modules", []):
            if m.get("class") == "MeshMaterial" and m.get("enabled") and isinstance(m.get("MeshMaterials"), list) \
                    and m["MeshMaterials"]:
                first = m["MeshMaterials"][0]
                if isinstance(first, dict) and "import" in first:
                    name = str(first["import"])
        if name and name not in out:
            out.append(name)
    return out


# ---- which textures the runtime actually reads (a replica of CascadeMaterials' lookups; the runtime test
# tests/fx/test_cascade_runtime.gd checks that every texture it asks for was copied unless the browser lacks it too)

# CascadeMaterials.FAMILIES (built-in fireball families): root -> (shader key, texture uniform name lists)
BUILTIN_FAMILY_TEXTURES = {
    "/Game/VFX/Character/Trails/M_f_FireBeam": ("fireball_head", [["RGB Texture", "MaskTextureUses Packed AlphaChannel"],
                                                                  ["Noise Texture 1", "Noise Texture 2"]]),
    "/Game/VFX/Character/PowerSurge/PowerSurge_Glow01_FxM": ("fireball_core_flames", [["MaskTexture"], ["DistortionNormalMap"]]),
    "/Game/VFX/Character/Trails/Fire_MaskedEmissive_RT_FxM": ("fireball_trail", [
        ["RGB Texture", "MaskTextureUses Packed AlphaChannel"], ["Erosion Texture"], ["Noise Texture"]]),
    "/Game/VFX/Materials/M_f_ParticleBasicErodeDistort": ("fireball_wisp", [["Opacity mask"], ["Normal"]]),
    "/Game/VFX/Materials/M_SimpleGlow": ("impact_glow", []),
    "/Game/VFX/Materials/M_SimpleFresnelBall": ("impact_fresnel_ball", []),
    "/Game/VFX/Materials/M_FlowMapTest": ("impact_smoke", [["Opacity"], ["Erosion"], ["Flow A"]]),
    "/Game/VFX/Character/Skills/M_SphereErosion_SoftEdge": ("impact_sphere_shock", []),
}
# CascadeMaterials.FAMILY_FIXED: shader key -> graph texture file names
FAMILY_FIXED = {"impact_smoke": ["T_f_SphereNormalFlow"], "impact_sphere_shock": ["T_f_DistortionNoise_Large"]}
# CascadeMaterials._uber name lists
UBER_PACKED = ["MaskTextureUses Packed AlphaChannel", "RGB Texture"]
UBER_COLOUR = ["Albedo", "DIffuseTexture", "Base Texture", "BaseTex", "Color Texture", "Main_Texture", "Texture", "Texture 1",
               "Texture Parameter"]
UBER_MASK = ["MaskTexture", "Opacity mask", "Opacity Mask", "Masks", "Mask Tex", "Mask Texture", "Mask_Texture", "Particle Mask",
             "SubUV texture", "SuBUVTexture", "Lightning Bolt", "Main Shape", "Opacity", "Base Alpha", "BubblesTexture"]
UBER_EROSION = ["Erosion Texture", "AlphaErosion", "Erosion Mask", "ErosionTexture", "Erosion", "Gradient Erode", "Detail Erosion"]
UBER_NORMAL = ["DistortionNormalMap", "Normal", "NormalMap", "2D_NormalMap", "Normal Map"]
UBER_NOISE = ["NoiseTexture", "Noise Texture 1", "Noise Texture", "Noise 1", "Distort_Texture", "DisplacementNoiseTexture"]
UBER_EMISSIVE = ["EmissiveTexture", "Emissive Texture"]


def load_families(dirs: list) -> dict:
    """root -> family record (CascadeMaterials.reload_families: built-ins, then the JSON files in name order)."""
    fams = {root: {"shader": key, "u": {f"_b{i}": ["t", names] for i, names in enumerate(lists)}}
            for root, (key, lists) in BUILTIN_FAMILY_TEXTURES.items()}
    for d in dirs:
        if d.is_dir():
            for f in sorted(d.glob("*.json")):
                j = json.loads(f.read_text())
                for r in j.get("roots", []):
                    fams[str(r)] = j
            break
    return fams


def runtime_textures(rec: dict, fams: dict, exists) -> list:
    """Texture packages CascadeMaterials builds `rec`'s material from (every texture it loads and keeps)."""
    if not rec:
        return []
    params = rec.get("textures") or {}
    fixed = [str(p) for p in (rec.get("fixed_textures") or [])]
    out = []

    def add(p):
        if p and p not in out:
            out.append(p)

    def named(names):
        for n in names:
            p = params.get(n)
            if p and exists(p):
                return p
        return None

    fam = fams.get(str(rec.get("root", "")))
    if fam:
        for src in fam["u"].values():
            kind = src[0]
            if kind in ("t", "has"):
                add(named(src[1]))
            elif kind == "t_fixed":
                for p in fixed:
                    if p.rsplit("/", 1)[-1] in src[1] and exists(p):
                        add(p)
                        break
        names = FAMILY_FIXED.get(fam["shader"], [])
        for p in fixed:
            if p.rsplit("/", 1)[-1] in names and exists(p):
                add(p)
        return out
    packed = named(UBER_PACKED)
    if packed:
        add(packed)
    else:
        colour, mask = named(UBER_COLOUR), named(UBER_MASK)
        add(colour)
        add(mask)
        if not colour and not mask:   # _no_param_textures
            c = m = None
            for p in fixed:
                n = p.rsplit("/", 1)[-1].lower()
                if "normal" in n or "raom" in n or n.endswith("_n") or not exists(p):
                    continue
                if c is None and ("albedo" in n or "diffuse" in n or "color" in n or "_d" in n):
                    c = p
                elif m is None and "noise" not in n:
                    m = p
            add(c if c else m)
    add(named(UBER_EROSION))
    add(named(UBER_NOISE) or named(UBER_NORMAL))
    add(named(UBER_EMISSIVE))
    return out


def has_alpha(png: Path) -> bool:
    """Godot's Image.detect_alpha() != ALPHA_NONE on the lossless PNG (CascadeMaterials._has_alpha): some texel's
    alpha is below 255. Reads the PNG itself (standard library only, so `python3 -I` works): colour types without an
    alpha channel answer from their tRNS chunk; grey+alpha / RGBA are unfiltered on the alpha bytes alone (PNG filters
    work per byte lane, so the alpha lane never depends on the colour lanes)."""
    import struct
    import zlib
    data = png.read_bytes()
    pos, idat, ihdr, trns = 8, [], None, None
    while pos < len(data):
        n, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if kind == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", body)
        elif kind == b"tRNS":
            trns = body
        elif kind == b"IDAT":
            idat.append(body)
        pos += 12 + n
    w, h, depth, ctype, _c, _f, interlace = ihdr
    if ctype in (0, 2):
        return trns is not None
    if ctype == 3:
        return trns is not None and min(trns) < 255
    if depth != 8 or interlace:
        return True   # (not in this source: 16-bit or interlaced alpha; treated as alpha)
    bpp = 4 if ctype == 6 else 2
    raw = zlib.decompress(b"".join(idat))
    stride = w * bpp
    prev = bytearray(stride)
    for y in range(h):
        row_start = y * (stride + 1)
        ft = raw[row_start]
        line = raw[row_start + 1:row_start + 1 + stride]
        cur = bytearray(line)
        if ft != 0:
            a = bpp - 1
            for x in range(a, stride, bpp):
                left = cur[x - bpp] if x >= bpp else 0
                up = prev[x]
                if ft == 1:
                    cur[x] = (line[x] + left) & 255
                elif ft == 2:
                    cur[x] = (line[x] + up) & 255
                elif ft == 3:
                    cur[x] = (line[x] + ((left + up) >> 1)) & 255
                else:
                    ul = prev[x - bpp] if x >= bpp else 0
                    p = left + up - ul
                    pa, pb, pc = abs(p - left), abs(p - up), abs(p - ul)
                    pr = left if (pa <= pb and pa <= pc) else (up if pb <= pc else ul)
                    cur[x] = (line[x] + pr) & 255
        if min(cur[bpp - 1::bpp]) < 255:
            return True
        prev = cur
    return False


def mesh_names(spec: dict) -> list:
    out = []
    for e in spec.get("emitters", []):
        if e.get("enabled") and e.get("type") == "mesh" and e.get("mesh"):
            if e["mesh"] not in out:
                out.append(e["mesh"])
    return out


def copy_if_changed(src: Path, dst: Path, dry: bool) -> bool:
    if dst.exists() and dst.stat().st_size == src.stat().st_size and dst.read_bytes() == src.read_bytes():
        return False
    if not dry:
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
    return True


def write_if_changed(path: Path, text: str, dry: bool) -> bool:
    if path.exists() and path.read_text(encoding="utf-8") == text:
        return False
    if not dry:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    return True


def resolve_ids(args, src: Path):
    """-> (ordered ids, uses: id -> [use dicts])"""
    ids, uses = [], {}
    index = None
    for raw in args.ids:
        if raw.startswith("#"):
            if index is None:
                index = json.loads((src / "specs" / "index.json").read_text())["systems"]
            raw = index[int(raw[1:])]["package"]
        raw = raw.removesuffix(".json")
        if raw not in ids:
            ids.append(raw)
    if args.element:
        fx_map = json.loads((src / "bending_fx_map.json").read_text())
        els = ELEMENTS if args.element == "all" else [args.element]
        for el in els:
            for row in fx_map["elements"][el]["final"]:
                picks = row.get("picks") or []
                if not picks:
                    continue
                pid = picks[0]["package"]
                if pid not in ids:
                    ids.append(pid)
                use = {"element": el, "move_id": row.get("move_id", ""), "role": row.get("role", ""),
                       "slot": row.get("slot", ""), "source_index": picks[0].get("index")}
                if use not in uses.setdefault(pid, []):
                    uses[pid].append(use)
    return ids, uses


def wiring_of(effect_ids: list) -> dict:
    """effect id -> "wired (...)" / "unwired (...)" / "not referenced", read from data/bending/sb_fx/<element>.json."""
    wired, unwired = {}, {}
    for el in ELEMENTS:
        f = ROOT / "data" / "bending" / "sb_fx" / f"{el}.json"
        if not f.exists():
            continue
        doc = json.loads(f.read_text())
        for key, roles in doc.get("moves", {}).items():
            for role, e in roles.items():
                if isinstance(e, dict) and e.get("effect"):
                    wired.setdefault(e["effect"], []).append(f"{el} {key} {role}")
        for u in doc.get("unwired", []):
            unwired.setdefault(u.get("effect"), []).append(f"{el} {u.get('key', '')} {u.get('role', '')}: {u.get('why', '')}")
    out = {}
    for eid in effect_ids:
        if eid in wired:
            out[eid] = "wired (" + "; ".join(sorted(set(wired[eid]))) + ")"
        elif eid in unwired:
            out[eid] = "unwired (" + " | ".join(unwired[eid]) + ")"
        else:
            out[eid] = "not referenced"
    return out


def print_status(dst: Path) -> int:
    idx = json.loads((dst / "index.json").read_text())["effects"]
    wiring = wiring_of(list(idx))
    counts = {"wired": 0, "unwired": 0, "not referenced": 0}
    print("| Effect | Wiring (data/bending/sb_fx) | Map pick (provenance) |")
    print("| --- | --- | --- |")
    for eid, row in idx.items():
        w = wiring[eid].replace("|", "/")
        counts[w.split(" (")[0]] += 1
        picks = "; ".join(sorted({f"{u['element']} {u['move_id']}: {u['role']}" for u in row.get("uses", [])})) or "-"
        print(f"| `{eid}` | {w} | {picks.replace('|', '/')} |")
    print(f"\n{len(idx)} effects: {counts['wired']} wired, {counts['unwired']} unwired, {counts['not referenced']} not referenced",
          file=sys.stderr)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("ids", nargs="*", help="effect ids (source package paths) or #N (browser index row)")
    ap.add_argument("--element", choices=ELEMENTS + ["all"], help="first picks of bending_fx_map.json's final rows")
    ap.add_argument("--src", default=str(SRC_DEFAULT))
    ap.add_argument("--dst", default=str(DST_DEFAULT))
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--status", action="store_true", help="print each imported effect's real wiring (read only)")
    args = ap.parse_args()
    src, dst, dry = Path(args.src), Path(args.dst), args.dry_run
    if args.status:
        return print_status(dst)
    if not args.ids and not args.element:
        ap.error("give effect ids or --element")
    ids, uses = resolve_ids(args, src)

    mats_all = json.loads((src / "materials.json").read_text())
    materials, meshes = mats_all["materials"], mats_all["meshes"]
    index_rows = {}
    for row in json.loads((src / "specs" / "index.json").read_text())["systems"]:
        index_rows[row["package"]] = len(index_rows)

    fams = load_families([ROOT / "data" / "fx" / "cascade_families", src / "families"])

    def exists(pkg: str) -> bool:
        return (src / "assets" / (rel_from_pkg(pkg) + ".png")).exists()

    sub_path = dst / "materials.json"
    sub = json.loads(sub_path.read_text()) if sub_path.exists() else {"materials": {}, "meshes": {}}
    sub.setdefault("texture_alpha", {})
    idx_path = dst / "index.json"
    idx = json.loads(idx_path.read_text()) if idx_path.exists() else {
        "format": "tidebreak-spellbreak-fx-import", "version": 1,
        "source": "Spellbreak (Proletariat): artifacts/spellbreak_fx (see SOURCE.md)", "effects": {}}

    changed = {"specs": 0, "textures": 0, "meshes": 0, "imports": 0}
    missing = []
    new_rows = []
    for eid in ids:
        spec_src = src / "specs" / (eid + ".json")
        if not spec_src.exists():
            print(f"MISSING spec {eid}", file=sys.stderr)
            missing.append(eid)
            continue
        spec = json.loads(spec_src.read_text())
        if copy_if_changed(spec_src, dst / "specs" / (eid + ".json"), dry):
            changed["specs"] += 1
        mat_names = material_names(spec, meshes)
        mesh_list = mesh_names(spec)
        tex_pkgs = []
        for mn in mat_names:
            rec = materials.get(mn)
            if rec is None:
                print(f"  {eid}: material {mn} not in materials.json (runtime falls back to the uber shader)")
                continue
            sub["materials"][mn] = rec
            for p in runtime_textures(rec, fams, exists):
                if p not in tex_pkgs:
                    tex_pkgs.append(p)
        tex_files, mesh_files = [], []
        for p in tex_pkgs:
            rel = rel_from_pkg(p) + ".png"
            s = src / "assets" / rel
            d = dst / "assets" / rel
            if copy_if_changed(s, d, dry):
                changed["textures"] += 1
            if p not in sub["texture_alpha"]:
                sub["texture_alpha"][p] = has_alpha(s)
            imp = Path(str(d) + ".import")
            if not imp.exists():
                if not dry:
                    imp.write_text(TEXTURE_IMPORT, encoding="utf-8")
                changed["imports"] += 1
            tex_files.append("assets/" + rel)
        for mn in mesh_list:
            rec = meshes.get(mn)
            if rec is None:
                print(f"  {eid}: mesh {mn} not in materials.json (runtime draws a sphere, as the browser)")
                continue
            sub["meshes"][mn] = rec
            # a mesh emitter with override_material false renders with the mesh's own first material
            rel = rel_from_pkg(rec.get("package", "")) + ".gltf"
            s = src / "assets" / rel
            if not s.exists():
                print(f"  {eid}: mesh {mn} has no exported glTF (runtime draws a sphere, as the browser)")
                continue
            d = dst / "assets" / rel
            if copy_if_changed(s, d, dry):
                changed["meshes"] += 1
            gl = json.loads(s.read_text())
            for b in gl.get("buffers", []) + gl.get("images", []):
                uri = b.get("uri", "")
                if uri and not uri.startswith("data:"):
                    copy_if_changed(s.parent / uri, d.parent / uri, dry)
            mesh_files.append("assets/" + rel)
        row = idx["effects"].get(eid, {})
        is_new = not row
        row.update({
            "spec": "specs/" + eid + ".json",
            "source_index": index_rows.get(eid),
            "source": "Spellbreak (Proletariat)",
            "materials": mat_names,
            "textures": tex_files,
            "meshes": mesh_files,
        })
        merged = row.get("uses", [])
        for u in uses.get(eid, []):
            if u not in merged:
                merged.append(u)
        row["uses"] = merged
        idx["effects"][eid] = row
        if is_new:
            new_rows.append(eid)
        print(f"{eid}: {len(mat_names)} materials, {len(tex_files)} textures, {len(mesh_files)} meshes")

    idx["effects"] = dict(sorted(idx["effects"].items()))
    sub["materials"] = dict(sorted(sub["materials"].items()))
    sub["meshes"] = dict(sorted(sub["meshes"].items()))
    sub["texture_alpha"] = dict(sorted(sub["texture_alpha"].items()))
    write_if_changed(sub_path, json.dumps(sub, indent=1, sort_keys=False) + "\n", dry)
    write_if_changed(idx_path, json.dumps(idx, indent=1) + "\n", dry)

    # SOURCE.md: header once, then one row per effect not yet listed
    src_md = dst / "SOURCE.md"
    text = src_md.read_text(encoding="utf-8") if src_md.exists() else SOURCE_HEADER
    today = date.today().isoformat()
    for eid in ids:
        if eid in missing or f"| `{eid}` |" in text:
            continue
        row = idx["effects"][eid]
        used = "; ".join(sorted({f"{u['element']} {u['move_id']}: {u['role']}" for u in row.get("uses", [])})) or "-"
        used = used.replace("|", "/")
        text += (f"| `{eid}` | Spellbreak (Proletariat), community Windows client, browser row {row.get('source_index')}"
                 f" | {used} | {len(row['textures'])} | {len(row['meshes'])} | {today} |\n")
    text = with_third_party(text, idx)
    write_if_changed(src_md, text, dry)

    tex_bytes = sum((dst / t).stat().st_size for r in idx["effects"].values() for t in set(r["textures"])
                    if (dst / t).exists()) if not dry else 0
    print(f"effects {len(ids)} ({len(new_rows)} new, {len(missing)} missing); copied specs {changed['specs']}, "
          f"textures {changed['textures']}, meshes {changed['meshes']}; new .import files {changed['imports']}"
          + ("" if dry else f"; pool png bytes (per-effect sum) {tex_bytes}"))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
