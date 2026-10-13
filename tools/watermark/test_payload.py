"""Focused format tests; model/codec verification is recorded with exported media."""
import importlib.util
import hashlib
import struct
import zlib
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("pixel_watermark", Path(__file__).with_name("pixel_watermark.py"))
engine = importlib.util.module_from_spec(spec)
spec.loader.exec_module(engine)


class PixelPayloadTests(unittest.TestCase):
    identifier = "34c32632-111f-4fd5-8020-0c2ea7e476ff"

    def test_wire_identity_and_round_trip(self):
        raw = engine.payload(self.identifier)
        self.assertEqual(raw[:24].hex(), "5442573234c32632111f4fd580200c2ea7e476ff0f000000")
        self.assertEqual(len(raw), 32)
        self.assertEqual(engine.unpack_payload(raw), self.identifier)
        self.assertEqual(engine.payload("urn:uuid:" + self.identifier), raw)
        decoded = engine.decode_payload(raw)
        self.assertEqual(decoded["payload_version"], "TBW2")
        self.assertEqual(decoded["policy_state"], "deny")
        self.assertEqual(decoded["policy"]["flags"], 15)
        self.assertEqual(decoded["policy"]["instruction"], "Do not copy, redistribute, train AI on, or use this content with AI.")

    def test_every_single_bit_corruption_is_rejected(self):
        raw = engine.payload(self.identifier)
        for bit in range(256):
            corrupt = bytearray(raw)
            corrupt[bit // 8] ^= 1 << (bit % 8)
            self.assertIsNone(engine.unpack_payload(bytes(corrupt)), bit)

    def test_unmarked_constants_and_truncation_are_rejected(self):
        for raw in (bytes(32), b"\xff" * 32, engine.payload(self.identifier)[:31], b""):
            self.assertIsNone(engine.unpack_payload(raw))

    def test_legacy_is_identified_but_policy_unknown(self):
        raw = engine.payload(self.identifier, version="TBW1")
        self.assertEqual(raw[:4], b"TBW1")
        decoded = engine.decode_payload(raw)
        self.assertEqual(decoded["asset_id"], self.identifier)
        self.assertEqual(decoded["payload_version"], "TBW1")
        self.assertEqual(decoded["policy_state"], "unknown")
        self.assertIsNone(decoded["policy"])

    def test_each_flag_and_zero_policy_have_explicit_semantics(self):
        for flags in range(16):
            decoded = engine.decode_payload(engine.payload(self.identifier, flags))
            policy = decoded["policy"]
            self.assertEqual(policy["deny_copying"], bool(flags & 1))
            self.assertEqual(policy["deny_ai_training"], bool(flags & 2))
            self.assertEqual(policy["deny_ai_inference"], bool(flags & 4))
            self.assertEqual(policy["deny_redistribution"], bool(flags & 8))
            self.assertEqual(decoded["policy_state"], "deny" if flags else "unknown")

    def test_unknown_flags_and_reserved_data_rejected_even_with_valid_checksums(self):
        for position, value in ((20, 16), (21, 1), (22, 1), (23, 1)):
            head = bytearray(engine.payload(self.identifier)[:24])
            head[position] = value
            body = bytes(head) + struct.pack(">I", zlib.crc32(head))
            raw = body + hashlib.sha256(body).digest()[:4]
            self.assertIsNone(engine.decode_payload(raw))


if __name__ == "__main__":
    unittest.main()
