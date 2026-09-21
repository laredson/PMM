#!/usr/bin/env python3
from __future__ import annotations
import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT=Path(__file__).with_name("verify_translation.py")
SPEC=importlib.util.spec_from_file_location("verify_translation",SCRIPT)
assert SPEC and SPEC.loader
MODULE=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

class VerifyTranslationTests(unittest.TestCase):
    def test_integrated_repository(self)->None:
        report=MODULE.verify(Path(__file__).resolve().parents[4])
        self.assertTrue(report["ok"])
        self.assertEqual(report["registeredLanguages"],30)
        self.assertEqual(len(report["enabledLanguages"]),23)
        self.assertEqual(report["canonicalKeyCount"],1292)
        self.assertEqual(report["spanishCompatibilityExtraKeys"],58)
    def test_placeholder_counter_preserves_format(self)->None:
        self.assertEqual(MODULE.placeholders("{0} / {1:N2} / {0}"),{"{0}":2,"{1:N2}":1})
    def test_duplicate_json_keys_are_rejected(self)->None:
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/"duplicate.json"
            path.write_text('{"a":1,"a":2}',encoding="utf-8")
            with self.assertRaises(MODULE.VerificationError):
                MODULE.load_json(path)

if __name__=="__main__":
    unittest.main()
