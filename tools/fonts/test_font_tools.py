#!/usr/bin/env python3
"""Self-test of the font tools and of UiFonts' lists against this Mac's font files:

    python3 tools/fonts/test_font_tools.py

The 134 letters, the sfnt reader on known fonts, UiFonts' macOS names all complete (and the two left out not in the
lists), the theme listing the same names, and its line spacing and UiFonts.LINE_GAP_EM covering the proof's measured
tone-mark overshoot. The tests that read font files skip off macOS. Ends with unittest's OK or FAILED.
"""

import math
import os
import re
import sys
import unicodedata
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import font_cmap_check as cc  # noqa: E402

REPO = cc.REPO
GLYPH_TEST = os.path.join(REPO, "tests", "thuyvan", "test_vietnamese_glyphs.gd")
THEME = os.path.join(REPO, "assets", "ui", "thuyvan_theme.tres")
SUPP = "/System/Library/Fonts/Supplemental"
MAC = sys.platform == "darwin" and os.path.isdir(SUPP)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def gd_const_string(src, name):
    """A GDScript string const, joining "a" \\ + "b" continuations."""
    m = re.search(r"^const %s := (.*?)\n(?=\S)" % name, src, re.S | re.M)
    return "".join(re.findall(r'"([^"]*)"', m.group(1)))


def gd_const_dict(src, name):
    m = re.search(r"^const %s := \{(.*?)\}" % name, src, re.S | re.M)
    return {k: float(v) for k, v in re.findall(r'"(\w+)":\s*([0-9.]+)', m.group(1))}


def theme_values():
    src = read(THEME)
    subs = {}
    for sid, body in re.findall(r'\[sub_resource type="SystemFont" id="(\w+)"\]\n(.*?)(?=\n\[|\Z)', src, re.S):
        subs[sid] = re.findall(r'"([^"]+)"', re.search(r"font_names = PackedStringArray\((.*?)\)", body).group(1))
    res = dict(re.findall(r"^(\S+) = (.+)$", src.split("[resource]")[1], re.M))

    def font(key):
        return subs[re.search(r'SubResource\("(\w+)"\)', res[key]).group(1)]

    return {
        "sans": (font("default_font"), int(res["default_font_size"]), int(res["Label/constants/line_spacing"])),
        "serif": (font("TitleLabel/fonts/font"), int(res["TitleLabel/font_sizes/font_size"]),
                  int(res["TitleLabel/constants/line_spacing"])),
        "mono": (font("MonoLabel/fonts/font"), int(res["MonoLabel/font_sizes/font_size"]),
                 int(res["MonoLabel/constants/line_spacing"])),
    }


class Letters(unittest.TestCase):
    def test_134(self):
        s = cc.vietnamese_letters()
        self.assertEqual(len(s), 134)
        self.assertEqual(len(set(s)), 134)
        self.assertTrue(all(ord(c) > 127 for c in s))
        self.assertTrue(all(unicodedata.normalize("NFC", c) == c for c in s))
        for c in "đĐơƠưƯẶặỄễỹỴ":
            self.assertIn(c, s)

    def test_glyph_test_matches(self):
        src = read(GLYPH_TEST)
        self.assertEqual(gd_const_string(src, "LETTERS"), cc.vietnamese_letters())
        self.assertEqual(gd_const_string(src, "PUNCT"), cc.PUNCT)

    def test_data_chars(self):
        d = cc.data_chars()
        for c in "ĐơưạảĐ§":
            self.assertIn(c, d)
        self.assertFalse(any(ord(c) < 0x20 for c in d))


@unittest.skipUnless(MAC, "reads macOS font files")
class Reader(unittest.TestCase):
    def test_arial_complete(self):
        faces = cc.read_faces(os.path.join(SUPP, "Arial.ttf"))
        self.assertEqual(len(faces), 1)
        self.assertEqual(faces[0].family, "Arial")
        self.assertEqual(faces[0].missing(cc.vietnamese_letters()), [])

    def test_collection_faces(self):
        faces = cc.read_faces(os.path.join(SUPP, "Baskerville.ttc"))
        self.assertGreaterEqual(len(faces), 4)
        self.assertEqual({f.family for f in faces}, {"Baskerville"})
        self.assertIn(700, {f.weight for f in faces})

    def test_menlo_short(self):
        faces = cc.read_faces("/System/Library/Fonts/Menlo.ttc")
        self.assertIn("ả", faces[0].missing(cc.vietnamese_letters()))
        self.assertNotIn("a", faces[0].missing("a"))

    def test_not_a_font(self):
        self.assertEqual(cc.read_faces(GLYPH_TEST), [])


class Lists(unittest.TestCase):
    def setUp(self):
        self.lists = cc.ui_font_lists()

    def test_roles(self):
        self.assertEqual(set(self.lists), {"serif", "sans", "mono"})
        self.assertEqual(self.lists["serif"][:3], ["Baskerville", "Georgia", "Times New Roman"])
        self.assertEqual(self.lists["sans"][:3], ["Avenir Next", "Helvetica Neue", "Arial"])
        for role, generic in (("serif", "serif"), ("sans", "sans-serif"), ("mono", "monospace")):
            self.assertEqual(self.lists[role][-1], generic)

    def test_left_out(self):
        every = sum(self.lists.values(), [])
        for name in ("Hoefler Text", "Menlo", "PT Mono", "Andale Mono", "Palatino"):
            self.assertNotIn(name, every)

    @unittest.skipUnless(MAC, "reads macOS font files")
    def test_installed_names_complete(self):
        fams = cc.installed()
        sets = {"vietnamese": cc.vietnamese_letters(), "punct": cc.PUNCT, "data": cc.data_chars()}
        checked = 0
        for role, names in self.lists.items():
            first = [n for n in names if n in fams]
            self.assertTrue(first, role)
            for n in first:
                miss, _, _ = cc.check_family(fams[n], sets)
                self.assertFalse(any(miss.values()), "%s %s: %s" % (role, n, miss))
                checked += 1
        self.assertGreaterEqual(checked, 8)

    @unittest.skipUnless(MAC, "reads macOS font files")
    def test_strict_exit(self):
        import contextlib
        import io
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(cc.main(["--strict"]), 0)


class Theme(unittest.TestCase):
    def test_same_names(self):
        lists = cc.ui_font_lists()
        for role, (names, _, _) in theme_values().items():
            self.assertEqual(names, lists[role], role)

    def test_line_spacing(self):
        gap = gd_const_dict(read(cc.UI_FONTS), "LINE_GAP_EM")
        for role, (_, size, spacing) in theme_values().items():
            self.assertGreaterEqual(spacing, math.ceil(gap[role] * size), role)

    @unittest.skipUnless(MAC, "reads macOS font files")
    def test_gap_covers_measured_overshoot(self):
        import font_proof as fp
        gap = gd_const_dict(read(cc.UI_FONTS), "LINE_GAP_EM")
        fams = cc.installed()
        for role, name in fp.SHOWN:
            if role not in gap or name not in fams:
                continue
            for size in fp.SIZES:
                _, asc, desc, top, bot = fp.measure(fp.pick_face(fams[name]), size)
                self.assertLessEqual(max(top - asc, bot - desc), math.ceil(gap[role] * size),
                                     "%s %s %dpx" % (role, name, size))


if __name__ == "__main__":
    unittest.main()
