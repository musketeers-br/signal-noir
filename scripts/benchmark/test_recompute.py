#!/usr/bin/env python3
"""Tests of recompute.py on the golden raw rows (feature 010, T045).

    python -I scripts/benchmark/test_recompute.py

The golden files are tests/benchmark/golden/cases.json (raw rows) and stats.json (the rows
the ObjectScript Stats class is also tested against).
"""
import copy
import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

import recompute  # noqa: E402


def load(name):
    with open(os.path.join(ROOT, "tests", "benchmark", "golden", name), encoding="utf-8") as handle:
        return json.load(handle)


class Recompute(unittest.TestCase):
    def setUp(self):
        self.raw = load("cases.json")
        self.expected = load("stats.json")

    def report(self):
        return {"mode": self.raw["mode"], "cases": self.raw["cases"], "agentDecision": copy.deepcopy(self.expected)}

    def test_the_golden_report_matches_its_rows(self):
        self.assertEqual(recompute.check(self.report()), [])

    def test_a_changed_number_is_found(self):
        report = self.report()
        report["agentDecision"][0]["latencyMsP50"]["max"] += 1
        problems = recompute.check(report)
        self.assertEqual(len(problems), 1)
        self.assertIn("latencyMsP50", problems[0])

    def test_a_changed_raw_row_is_found(self):
        report = self.report()
        report["cases"][0]["outcome"] = "incorrect"
        self.assertTrue(recompute.check(report))

    def test_a_missing_group_is_found(self):
        report = self.report()
        del report["agentDecision"][0]
        self.assertTrue(any("rows published" in line for line in recompute.check(report)))

    def test_nearest_rank(self):
        self.assertEqual(recompute.nearest_rank([5, 1, 3, 2, 4], 50), 3)
        self.assertEqual(recompute.nearest_rank([5, 1, 3, 2, 4], 95), 5)
        self.assertEqual(recompute.nearest_rank(list(range(1, 21)), 95), 19)
        self.assertEqual(recompute.nearest_rank([7], 95), 7)

    def test_replay_touched_and_platform_rows_do_not_count(self):
        groups = {(r["family"], r["subtype"], r["set"]): r for r in self.expected}
        p5 = groups[("P5", "P5", "test")]
        self.assertEqual(p5["variantCount"], 5, "a variant counts once")
        self.assertEqual(p5["denominator"]["withNotDecided"], {"min": 5, "max": 5})
        self.assertNotIn(("P3", "P3.maintenance_window", "test"), groups, "platform families are not agent-decision rows")

    def test_a_not_decided_case_changes_the_denominator_not_the_counts_of_outcomes(self):
        p8 = {(r["family"], r["subtype"], r["set"]): r for r in self.expected}[("P8", "P8b", "test")]
        self.assertEqual(p8["counts"]["notDecided"], {"min": 0, "max": 1})
        self.assertEqual(p8["denominator"]["withoutNotDecided"], {"min": 4, "max": 5})
        self.assertEqual(p8["denominator"]["withNotDecided"], {"min": 5, "max": 5})

    def test_a_group_with_fewer_repetitions_says_so(self):
        clean = {(r["family"], r["subtype"], r["set"]): r for r in self.expected}[("clean", "clean.ambiguous_identity", "test")]
        self.assertEqual(clean["repetitionsCovered"], 2)

    def test_tuning_is_its_own_group(self):
        keys = {(r["family"], r["set"]) for r in self.expected}
        self.assertIn(("P5", "tuning"), keys)
        self.assertIn(("P5", "test"), keys)


if __name__ == "__main__":
    unittest.main(verbosity=2)
