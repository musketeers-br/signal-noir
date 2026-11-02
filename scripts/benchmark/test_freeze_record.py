#!/usr/bin/env python3
"""Tests of freeze_record.py in a throwaway git repository (feature 010, T056).

    python -I scripts/benchmark/test_freeze_record.py

The record it writes must be the one check-freeze.sh accepts, and must stop matching when a
frozen file changes.
"""
import datetime
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

import freeze_record  # noqa: E402

PLACEHOLDER = """Class SignalNoir.Benchmark.Data.Freeze Extends SignalNoir.Benchmark.Data.Base
{

/// The freeze record.
XData Record [ MimeType = application/json ]
{
{
  "freezeId": "",
  "files": []
}
}

}
"""


def inputs():
    return {field: f"{field}-value" for field in freeze_record.FIELDS}


class FreezeRecord(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.mkdtemp()
        self.git("init", "-q", ".")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "user.name", "test")
        os.makedirs(os.path.join(self.work, "src", "SignalNoir", "Benchmark", "Data"))
        os.makedirs(os.path.join(self.work, "src", "x"))
        self.put(freeze_record.RECORD, PLACEHOLDER)
        self.put("src/x/a.cls", "one\n")
        self.put("src/x/b.cls", "two\n")
        self.git("add", ".")
        self.git("commit", "-q", "-m", "base")
        self.files = ["src/x/a.cls", "src/x/b.cls"]

    def tearDown(self):
        shutil.rmtree(self.work, ignore_errors=True)

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.work, capture_output=True, text=True, check=True).stdout.strip()

    def put(self, path, text):
        with open(os.path.join(self.work, path), "w", encoding="utf-8", newline="") as handle:
            handle.write(text)

    def check(self):
        script = os.path.join(ROOT, "scripts", "benchmark", "check-freeze.sh")
        return subprocess.run(["sh", script], cwd=self.work, capture_output=True, text=True)

    def freeze(self):
        when = datetime.datetime(2026, 11, 5, 12, 0, tzinfo=datetime.timezone.utc)
        record = freeze_record.build(inputs(), "freeze-test", self.files, self.work, now=when)
        freeze_record.write(os.path.join(self.work, freeze_record.RECORD), record)
        return record

    def test_the_record_names_every_input_and_file(self):
        record = self.freeze()
        self.assertEqual(record["freezeId"], "freeze-test")
        self.assertEqual(record["commit"], self.git("rev-parse", "HEAD"))
        self.assertEqual(record["frozenAt"], "2026-11-05T12:00:00Z")
        for field in freeze_record.FIELDS:
            self.assertEqual(record[field], f"{field}-value")
        self.assertEqual([f["path"] for f in record["files"]], self.files)
        self.assertEqual(record["files"][0]["blob"], self.git("hash-object", "--", "src/x/a.cls"))

    def test_check_freeze_accepts_what_was_written(self):
        self.freeze()
        done = self.check()
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        self.assertIn("all 2 frozen files match the freeze freeze-test", done.stdout)

    def test_check_freeze_fails_when_a_frozen_file_changes(self):
        self.freeze()
        self.put("src/x/b.cls", "changed\n")
        done = self.check()
        self.assertEqual(done.returncode, 1, done.stdout + done.stderr)
        self.assertIn("CHANGED  src/x/b.cls", done.stdout)

    def test_the_rest_of_the_class_is_kept(self):
        self.freeze()
        text = open(os.path.join(self.work, freeze_record.RECORD), encoding="utf-8").read()
        self.assertTrue(text.startswith("Class SignalNoir.Benchmark.Data.Freeze"))
        self.assertIn("/// The freeze record.", text)
        self.assertTrue(text.rstrip().endswith("}\n\n}") or text.rstrip().endswith("}"))

    def test_the_line_iris_prints_is_read(self):
        line = "FREEZE-INPUTS " + json.dumps(inputs())
        self.assertEqual(freeze_record.read_inputs("noise\n" + line + "\n"), inputs())

    def test_a_refusal_from_iris_is_a_refusal(self):
        with self.assertRaises(freeze_record.Refused) as caught:
            freeze_record.read_inputs("FREEZE-REFUSED the reserved set is not ready: P5-test-00 is a placeholder")
        self.assertIn("P5-test-00 is a placeholder", str(caught.exception))

    def test_an_empty_input_is_refused(self):
        bad = inputs()
        bad["answerKeyDigest"] = ""
        with self.assertRaises(freeze_record.Refused) as caught:
            freeze_record.read_inputs(json.dumps(bad))
        self.assertIn("answerKeyDigest", str(caught.exception))

    def test_a_missing_frozen_file_is_refused(self):
        with self.assertRaises(freeze_record.Refused) as caught:
            freeze_record.build(inputs(), "freeze-test", self.files + ["src/x/none.cls"], self.work)
        self.assertIn("src/x/none.cls", str(caught.exception))

    def test_every_frozen_file_of_the_repository_exists_or_is_a_reserved_file(self):
        reserved = {"src/SignalNoir/Sim/Catalog/CleanTest.cls", "src/SignalNoir/Benchmark/Data/AnswerKeyTest.cls"}
        for path in freeze_record.FROZEN:
            if path in reserved:
                continue
            self.assertTrue(os.path.isfile(os.path.join(ROOT, path)), path)


if __name__ == "__main__":
    unittest.main()
