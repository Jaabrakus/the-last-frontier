#!/usr/bin/env python3
"""Which of the computer's fonts can write Vietnamese: the cmap check behind UiFonts' lists (scripts/thuyvan/ui_fonts.gd).

    python3 tools/fonts/font_cmap_check.py [--json out.json] [--strict] [--font path ...]

Reads every font file in the macOS font folders (and any --font file) with a small sfnt reader of its own (fontTools is
not installed here, and nothing is downloaded), and checks each face's cmap for:

    vietnamese  the 134 precomposed Vietnamese letters, both cases, all tones (đ and Đ among them)
    punct       the punctuation the game's text uses (curly quotes, dashes, ellipsis, middle dot, section sign)
    data        every character in data/thuyvan/*.json (keys and values)

A family passes when every face UiFonts can pick (weights 400-700, upright and italic) covers all three; faces outside
that range that fall short are named (Avenir Next Heavy, Helvetica Neue Thin Italic). The report lists each role's
candidates in UiFonts' order,
then a survey of other installed families. --strict exits 1 when a named font in ui_fonts.gd's lists is installed here
but fails. Only this Mac's fonts are checked: Windows and Linux (the lists' tails) are unverified.
"""

import argparse
import glob
import json
import os
import re
import struct
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
DATA = os.path.join(REPO, "data", "thuyvan")
UI_FONTS = os.path.join(REPO, "scripts", "thuyvan", "ui_fonts.gd")
FONT_DIRS = [
    "/System/Library/Fonts",
    "/System/Library/Fonts/Supplemental",
    "/Library/Fonts",
    os.path.expanduser("~/Library/Fonts"),
]
## The candidates per role, in the order tried. Hoefler Text and Menlo are here to show why they are left out.
CANDIDATES = {
    "serif": ["Baskerville", "Georgia", "Times New Roman", "Hoefler Text", "Times"],
    "sans": ["Avenir Next", "Helvetica Neue", "Arial", "Helvetica"],
    "mono": ["Courier New", "PT Mono", "Andale Mono", "Menlo", "Monaco", "Courier"],
}
## Other families worth knowing about (the survey at the end of the report).
SURVEY = ["Palatino", "Charter", "Iowan Old Style", "Cochin", "Didot", "New York", "Optima", "Avenir", "Gill Sans",
          "Verdana", "Tahoma", "Trebuchet MS", "Lucida Grande", "Arial Unicode MS", "Geneva"]
## Generic names SystemFont maps to the platform's default; not checked.
GENERIC = {"serif", "sans-serif", "monospace", "cursive", "fantasy"}
## The weights UiFonts asks for (SystemFont picks the nearest face).
WEIGHTS = (400, 700)

VOWELS = "aăâeêioôơuưy"
TONES = ["", "̀", "́", "̉", "̃", "̣"]  # level, huyền, sắc, hỏi, ngã, nặng
PUNCT = "‘’“”–—…·§"


def vietnamese_letters():
    """The 134 precomposed letters: 12 vowels x 6 tones minus the 6 plain ASCII ones, plus đ, in both cases."""
    out = []
    for case in (str.lower, str.upper):
        for v in VOWELS:
            for t in TONES:
                c = unicodedata.normalize("NFC", case(v) + t)
                assert len(c) == 1, c
                if ord(c) > 127:
                    out.append(c)
        out.append(case("đ"))
    return "".join(out)


def data_chars(data_dir=DATA):
    """Every printable character in the canon files' keys and string values."""
    chars = set()

    def walk(v):
        if isinstance(v, str):
            chars.update(v)
        elif isinstance(v, dict):
            for k, x in v.items():
                chars.update(k)
                walk(x)
        elif isinstance(v, list):
            for x in v:
                walk(x)

    for path in sorted(glob.glob(os.path.join(data_dir, "*.json"))):
        with open(path, encoding="utf-8") as f:
            walk(json.load(f))
    return "".join(sorted(c for c in chars if ord(c) >= 0x20))


# --- the sfnt reader -------------------------------------------------------------------------------------------------

class Face:
    def __init__(self, path, index):
        self.path = path
        self.index = index
        self.family = ""
        self.style = ""
        self.full = ""
        self.weight = 400
        self.ascent = 0
        self.descent = 0
        self.upem = 1000
        self.cmap = set()

    def missing(self, chars):
        return [c for c in chars if ord(c) not in self.cmap]


def _offsets(buf):
    if buf[:4] == b"ttcf":
        n = struct.unpack(">I", buf[8:12])[0]
        return list(struct.unpack(">%dI" % n, buf[12:12 + 4 * n]))
    return [0]


def _tables(buf, off):
    num = struct.unpack(">H", buf[off + 4:off + 6])[0]
    out = {}
    for i in range(num):
        rec = off + 12 + 16 * i
        tag = buf[rec:rec + 4].decode("latin-1")
        t_off, t_len = struct.unpack(">II", buf[rec + 8:rec + 16])
        out[tag] = (t_off, t_len)
    return out


def _names(buf, off):
    fmt, count, str_off = struct.unpack(">HHH", buf[off:off + 6])
    best = {}
    for i in range(count):
        rec = off + 6 + 12 * i
        pid, eid, lid, nid, length, s_off = struct.unpack(">HHHHHH", buf[rec:rec + 12])
        raw = buf[off + str_off + s_off:off + str_off + s_off + length]
        if pid == 3 and lid == 0x409:
            rank, text = 0, raw.decode("utf-16-be", "replace")
        elif pid == 1 and lid == 0:
            rank, text = 1, raw.decode("mac_roman", "replace")
        elif pid in (0, 3):
            rank, text = 2, raw.decode("utf-16-be", "replace")
        else:
            continue
        if nid not in best or rank < best[nid][0]:
            best[nid] = (rank, text)
    return {k: v[1] for k, v in best.items()}


def _cmap4(buf, off):
    seg2 = struct.unpack(">H", buf[off + 6:off + 8])[0]
    n = seg2 // 2
    ends = struct.unpack(">%dH" % n, buf[off + 14:off + 14 + seg2])
    starts = struct.unpack(">%dH" % n, buf[off + 16 + seg2:off + 16 + 2 * seg2])
    deltas = struct.unpack(">%dh" % n, buf[off + 16 + 2 * seg2:off + 16 + 3 * seg2])
    ro_at = off + 16 + 3 * seg2
    ranges = struct.unpack(">%dH" % n, buf[ro_at:ro_at + seg2])
    out = set()
    for i in range(n):
        for c in range(starts[i], ends[i] + 1):
            if c == 0xFFFF:
                continue
            if ranges[i] == 0:
                g = (c + deltas[i]) & 0xFFFF
            else:
                at = ro_at + 2 * i + ranges[i] + 2 * (c - starts[i])
                g = struct.unpack(">H", buf[at:at + 2])[0]
                if g:
                    g = (g + deltas[i]) & 0xFFFF
            if g:
                out.add(c)
    return out


def _cmap12(buf, off):
    n = struct.unpack(">I", buf[off + 12:off + 16])[0]
    out = set()
    for i in range(n):
        s, e, g = struct.unpack(">III", buf[off + 16 + 12 * i:off + 28 + 12 * i])
        for c in range(s, e + 1):
            if g + (c - s):
                out.add(c)
    return out


def _cmap(buf, off):
    num = struct.unpack(">H", buf[off + 2:off + 4])[0]
    subs = []
    for i in range(num):
        pid, eid, s_off = struct.unpack(">HHI", buf[off + 4 + 8 * i:off + 12 + 8 * i])
        fmt = struct.unpack(">H", buf[off + s_off:off + s_off + 2])[0]
        subs.append((pid, eid, fmt, off + s_off))
    # Prefer a full-Unicode table, then a BMP one.
    for want in ((3, 10, 12), (0, 4, 12), (0, 6, 12), (0, 3, 12), (3, 1, 4), (0, 3, 4), (0, 1, 4), (0, 0, 4)):
        for pid, eid, fmt, at in subs:
            if (pid, eid, fmt) == want:
                return _cmap12(buf, at) if fmt == 12 else _cmap4(buf, at)
    for pid, eid, fmt, at in subs:
        if pid in (0, 3) and fmt in (4, 12):
            return _cmap12(buf, at) if fmt == 12 else _cmap4(buf, at)
    return set()


def read_faces(path):
    """Every face in a .ttf, .otf or .ttc ([] if the file is not an sfnt font)."""
    try:
        with open(path, "rb") as f:
            buf = f.read()
    except OSError:
        return []
    if buf[:4] not in (b"\x00\x01\x00\x00", b"OTTO", b"true", b"ttcf"):
        return []
    faces = []
    for i, off in enumerate(_offsets(buf)):
        try:
            tables = _tables(buf, off)
            face = Face(path, i)
            if "name" in tables:
                names = _names(buf, tables["name"][0])
                face.family = names.get(16) or names.get(1, "")
                face.style = names.get(17) or names.get(2, "")
                face.full = names.get(4, "")
            if "OS/2" in tables:
                o = tables["OS/2"][0]
                face.weight = struct.unpack(">H", buf[o + 4:o + 6])[0]
            if "head" in tables:
                face.upem = struct.unpack(">H", buf[tables["head"][0] + 18:tables["head"][0] + 20])[0]
            if "hhea" in tables:
                h = tables["hhea"][0]
                face.ascent, face.descent = struct.unpack(">hh", buf[h + 4:h + 8])
            if "cmap" in tables:
                face.cmap = _cmap(buf, tables["cmap"][0])
            faces.append(face)
        except (struct.error, IndexError):
            continue
    return faces


def installed(extra=()):
    """family name -> [Face], from the font folders and any extra files."""
    paths = []
    for d in FONT_DIRS:
        for ext in ("ttf", "otf", "ttc", "TTF", "OTF", "TTC"):
            paths += glob.glob(os.path.join(d, "*." + ext))
    paths += list(extra)
    fams = {}
    for p in sorted(set(paths)):
        for face in read_faces(p):
            if face.family:
                fams.setdefault(face.family, []).append(face)
    return fams


def check_family(faces, sets):
    """{set name: sorted missing chars over the faces UiFonts can pick}, per face {name: missing count}, and the
    faces outside that range that fall short."""
    missing = {name: set() for name in sets}
    per_face = {}
    outside = []
    for face in faces:
        n = 0
        # An ornament or symbol face (no "a") is never picked for text.
        used = WEIGHTS[0] <= face.weight <= WEIGHTS[1] and ord("a") in face.cmap
        for name, chars in sets.items():
            m = face.missing(chars)
            if used:
                missing[name].update(m)
            n += len(m)
        label = "%s (%s)" % (face.full or face.family, face.weight)
        per_face[label] = n
        if n and not used:
            outside.append(label)
    return {k: "".join(sorted(v)) for k, v in missing.items()}, per_face, outside


def ui_font_lists(path=UI_FONTS):
    """UiFonts' SERIF, SANS and MONO lists, read from the GDScript source ({} if the file is missing)."""
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        src = f.read()
    out = {}
    for role in ("serif", "sans", "mono"):
        m = re.search(r"^const %s\s*:=\s*\[(.*?)\]" % role.upper(), src, re.S | re.M)
        if m:
            out[role] = re.findall(r'"([^"]+)"', m.group(1))
    return out


def report(fams, sets, out=None):
    out = out or sys.stdout
    results = {}

    def row(name):
        faces = fams.get(name)
        if not faces:
            print("  %-18s  not installed here" % name, file=out)
            results[name] = None
            return
        miss, per_face, outside = check_family(faces, sets)
        ok = not any(miss.values())
        results[name] = {"ok": ok, "faces": len(faces), "missing": miss, "per_face": per_face, "outside": outside,
                         "files": sorted({os.path.basename(f.path) for f in faces})}
        bits = ", ".join("%s %d" % (k, len(v)) for k, v in miss.items() if v)
        print("  %-18s  %-4s  %2d faces  %s" % (name, "OK" if ok else "FAIL", len(faces),
                                                  ("missing: " + bits) if bits else "complete"), file=out)
        for k, v in miss.items():
            if v:
                print("      %-10s %s" % (k, v[:80] + (" ..." if len(v) > 80 else "")), file=out)
        if outside:
            print("      not used, incomplete: %s" % ", ".join(outside), file=out)

    print("Vietnamese cmap check: %d letters, %d punctuation, %d data characters"
          % tuple(len(sets[k]) for k in ("vietnamese", "punct", "data")), file=out)
    for role, names in CANDIDATES.items():
        print("\n%s" % role, file=out)
        for n in names:
            row(n)
    print("\nsurvey", file=out)
    for n in SURVEY:
        row(n)
    return results


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--json", help="write the results here as JSON")
    ap.add_argument("--strict", action="store_true", help="exit 1 if an installed font named in ui_fonts.gd fails")
    ap.add_argument("--font", action="append", default=[], help="also check this font file (its family joins in)")
    args = ap.parse_args(argv)
    letters = vietnamese_letters()
    assert len(letters) == 134, len(letters)
    sets = {"vietnamese": letters, "punct": PUNCT, "data": data_chars()}
    fams = installed(args.font)
    for p in args.font:
        for face in read_faces(p):
            if face.family not in CANDIDATES["serif"] + CANDIDATES["sans"] + CANDIDATES["mono"] + SURVEY:
                SURVEY.insert(0, face.family)
    results = report(fams, sets)
    bad = []
    lists = ui_font_lists()
    if lists:
        print("\nui_fonts.gd's lists on this machine", file=sys.stdout)
        for role, names in lists.items():
            marks = []
            for n in names:
                if n in GENERIC:
                    marks.append(n + " (generic)")
                    continue
                faces = fams.get(n)
                if not faces:
                    marks.append(n + " (not here: unverified)")
                    continue
                miss, _, _ = check_family(faces, sets)
                ok = not any(miss.values())
                marks.append(n + (" OK" if ok else " FAIL"))
                if not ok:
                    bad.append("%s: %s" % (role, n))
            print("  %-6s %s" % (role, ", ".join(marks)))
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump({"sets": sets, "families": results, "ui_fonts": lists, "bad": bad}, f, ensure_ascii=False,
                      indent=1)
    if bad:
        print("\nCMAP CHECK: %d font(s) in ui_fonts.gd fail here: %s" % (len(bad), ", ".join(bad)))
    else:
        print("\nCMAP CHECK PASSED")
    return 1 if (bad and args.strict) else 0


if __name__ == "__main__":
    sys.exit(main())
