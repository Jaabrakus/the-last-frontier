#!/usr/bin/env python3
"""Self-test of the text guard (text_guard.py, guard_terms.json):

    python3 tools/thuyvan/test_text_guard.py

The phrase lists catch what they must (later books' terms, the show's words, a claim in the game's own voice) and let
the ordinary words through (a stern bend, a river bend, a tax seal, a sealed packet). Ends with unittest's OK or FAILED.
"""

import io
import json
import os
import shutil
import sys
import tempfile
import unicodedata
import unittest
from contextlib import redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import text_guard as tg  # noqa: E402

TERMS = tg.load_terms()


def lists(text, voice=None, tags=(), book=1, kind="text"):
    return [h[0] for h in tg.check_item(tg.Item(text, "t", kind=kind, voice=voice, tags=tags, book=book), TERMS)]


def terms(text, **kw):
    return [h[1] for h in tg.check_item(tg.Item(text, "t", **kw), TERMS)]


class FalsePositives(unittest.TestCase):
    """Ordinary words the old blunt word list would have caught."""

    def test_bends(self):
        self.assertEqual(lists("Lean on the oar for the stern bend."), [])
        self.assertEqual(lists("Past the river bend the ferry waits."), [])
        self.assertEqual(lists("The path bends twice above the gorge."), [])
        self.assertEqual(lists("Bend the knees, not the back."), [])

    def test_documentary_seals(self):
        self.assertEqual(lists("The clerk stamps the tax seal on every sack."), [])
        self.assertEqual(lists("A sealed packet went downriver with the dispatch boat."), [])
        self.assertEqual(lists("She kept the sealed report under her mat."), [])
        self.assertEqual(lists("Tonight's tale: Salt Under the Seal."), [])
        self.assertEqual(lists("Cửu Giang's seal hangs over the court box."), [])
        self.assertEqual(lists("The seal on the court box is Cửu Giang's."), [])

    def test_lowercase_hollow_and_binding(self):
        self.assertEqual(lists("A hollow log makes a fine drum."), [])
        self.assertEqual(lists("The contract is binding on both houses."), [])

    def test_bend_as_a_key_or_id(self):
        self.assertEqual(lists("bend", kind="key"), [])
        self.assertEqual(lists("res://data/bending/schemes.json"), [])


class Catches(unittest.TestCase):

    def test_show_words(self):
        self.assertIn("show_words", lists("Every bender in the city came to watch."))
        self.assertIn("show_words", lists("Waterbending is taught at the lock."))
        self.assertIn("show_words", lists("A pro-bending match."))
        self.assertIn("show_words", lists("The Avatar returns."))
        self.assertIn("show_words", lists("She learned the Water Whip."))
        self.assertIn("show_words", lists("He redirected lightning at the gate."))
        self.assertIn("show_words", lists("The Fire Nation's fleet."))
        self.assertIn("show_words", lists("Seismic sense reads the ground."))

    def test_book_gated(self):
        self.assertIn("book_gated", lists("They say the Hollow Tide is rising."))
        self.assertIn("book_gated", lists("the Ninth River"))
        self.assertIn("book_gated", lists("Memory is a river, the old song says."))
        self.assertIn("book_gated", lists("Sông Kỳ runs under all of them."))
        self.assertIn("book_gated", lists("Below the Convergence floor."))
        self.assertIn("book_gated", lists("The First Binding held."))
        self.assertIn("book_gated", lists("The Hollowing took him."))
        self.assertIn("book_gated", lists("the seal of the rivers"))
        self.assertIn("book_gated", lists("Break the seal and the water moves."))
        self.assertIn("book_gated", lists("A containment site."))
        self.assertIn("book_gated", lists("Liên Khởi answered."))
        self.assertIn("book_gated", lists("The Quiet Woman waits by the door."))

    def test_book_gate_opens_in_its_book(self):
        self.assertIn("book_gated", lists("the Hollow Tide", book=2))
        self.assertEqual(lists("the Hollow Tide", book=3), [])
        self.assertIn("book_gated", lists("the Ninth River", book=4))
        self.assertEqual(lists("the Ninth River", book=5), [])

    def test_decomposed_text_still_matches(self):
        nfd = unicodedata.normalize("NFD", "Sông Kỳ")
        got = lists(nfd)
        self.assertIn("nfc", got)
        self.assertIn("book_gated", got)


class Voices(unittest.TestCase):

    def test_pirates_claim_only(self):
        self.assertIn("claim_only", lists("Pirates burned the dig."))
        self.assertIn("claim_only", lists("Pirates burned the dig.", voice="npc"))
        self.assertIn("claim_only", lists("Pirates burned the dig.", voice="narration"))
        self.assertEqual(lists("Pirates burned the dig. No one lived.", voice="notice"), [])
        self.assertEqual(lists("The pirates will be hunted down.", voice="imperial"), [])

    def test_lantern_child_only_as_a_tale(self):
        self.assertEqual(lists("Grandmother told of the Lantern Child at the shrine door.", voice="npc", tags=["tale"]), [])
        self.assertIn("book_gated", lists("Grandmother told of the Lantern Child.", voice="npc"))
        self.assertIn("book_gated", lists("The Lantern Child appears.", voice="narration", tags=["tale"]))
        self.assertEqual(lists("The Lantern Child appears.", book=2), [])


class KeysAndIds(unittest.TestCase):

    def test_forbidden_keys(self):
        self.assertIn("keys", lists("author_truth", kind="key"))
        self.assertIn("keys", lists("hidden_matter", kind="key"))
        self.assertIn("keys", lists("evidence", kind="key"))
        self.assertIn("keys", lists("reveal_guard", kind="key"))
        self.assertEqual(lists("reveal_book", kind="key"), [])

    def test_forbidden_id_words(self):
        self.assertIn("ids", lists("hollow_faction"))
        self.assertIn("ids", lists("river_seal", kind="key"))
        self.assertIn("ids", lists("convergence_floor"))
        self.assertEqual(lists("da_trang"), [])


class Files(unittest.TestCase):

    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="text_guard_test_")

    def tearDown(self):
        shutil.rmtree(self.dir)

    def _write(self, name, text):
        path = os.path.join(self.dir, name)
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        return path

    def _run(self, *args):
        buf = io.StringIO()
        with redirect_stdout(buf):
            code = tg.main(list(args))
        return code, buf.getvalue()

    def test_json_rows_and_voices(self):
        data = {"rows": [
            {"id": "a", "reveal_book": 3, "line": {"text": "The Hollow Tide is named at last.", "voice": "narration"}},
            {"id": "b", "line": {"text": "Pirates, the notice says.", "voice": "notice"}},
            {"id": "c", "line": {"text": "Pirates did it.", "voice": "npc"}},
        ]}
        path = self._write("rows.json", json.dumps(data, ensure_ascii=False))
        items, err = tg.file_items(path)
        self.assertIsNone(err)
        hits = [(it.where, h[0]) for it in items for h in tg.check_item(it, TERMS)]
        self.assertEqual(hits, [("$.rows[2].line.text", "claim_only")])

    def test_gdscript_literals(self):
        src = (
            '# The Hollow Tide in a comment is not text.\n'
            'const A := "the river bend"\n'
            'var b := &"bender_node"\n'
            'func f():\n'
            '\tprint("a bender\\n" + \'the Ninth River\')\n'
            '\tvar c := """\n'
            'Waterbending lesson\n'
            '"""\n'
        )
        path = self._write("x.gd", src)
        items, _ = tg.file_items(path)
        got = sorted((it.where, h[0]) for it in items for h in tg.check_item(it, TERMS))
        self.assertEqual(got, [("5", "book_gated"), ("5", "show_words"), ("6", "show_words")])

    def test_scene_text(self):
        path = self._write("x.tscn", '[node name="L" type="Label"]\ntext = "A bending lesson"\n'
                                     '[ext_resource path="res://data/bending/x.json"]\n')
        items, _ = tg.file_items(path)
        got = [h[0] for it in items for h in tg.check_item(it, TERMS)]
        self.assertEqual(got, ["show_words"])

    def test_strict_fails_and_report_only_does_not(self):
        path = self._write("bad.json", json.dumps({"line": {"text": "the bender", "voice": "ui"}}))
        code, out = self._run(path)
        self.assertEqual(code, 1)
        self.assertIn("TEXT GUARD FAILED", out)
        code, out = self._run(path, "--report-only")
        self.assertEqual(code, 0)
        self.assertIn("report only: 1 hits (show_words 1)", out)

    def test_legacy_paths(self):
        self.assertTrue(tg.is_legacy("data/story/two_fires.json"))
        self.assertTrue(tg.is_legacy("scripts/ui/hud.gd"))
        self.assertTrue(tg.is_legacy("data/ring"))
        self.assertFalse(tg.is_legacy("data/thuyvan/peoples.json"))
        self.assertFalse(tg.is_legacy("data/storyteller/x.json"))

    def test_shipped_data_passes(self):
        code, out = self._run(os.path.join(tg.REPO, "data", "thuyvan"))
        self.assertEqual(code, 0, out)


if __name__ == "__main__":
    unittest.main(verbosity=2)
