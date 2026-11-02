#!/usr/bin/env python3
"""Recompute the agent-decision part of a Benchmark report from its raw rows.

An implementation of contracts/scoring.md "Statistics" that shares no code with the
ObjectScript one (SignalNoir.Core.Benchmark.Stats). A report is reproducible when both
agree with the numbers it publishes (feature 010, FR-022).

    python -I scripts/benchmark/recompute.py REPORT.json      # check a report
    python -I scripts/benchmark/recompute.py --emit CASES.json   # print the rows for a cases file

Standard library only. Exit status 0 when the report matches its raw rows, 1 when it does not,
2 on a usage or format error.
"""
import json
import math
import sys

OUTCOMES = ("correct", "safe_review", "unnecessary_review", "incorrect")
SCORED_FAMILIES = ("clean", "P5", "P8", "P9")
EPSILON = 1e-9


def counted(case):
    """A row takes part in the agent decision metrics (scoring.md Step 0 and the family list)."""
    return (
        case.get("countsInMetrics") is True
        and not case.get("replay")
        and not case.get("touchedByPerson")
        and case.get("family") in SCORED_FAMILIES
    )


def nearest_rank(values, p):
    """Nearest-rank percentile: sort ascending, take the value at index ceil(p/100 * n), 1-based."""
    ordered = sorted(values)
    return ordered[max(1, math.ceil(p * len(ordered) / 100.0)) - 1]


def span(values):
    return {"min": min(values), "max": max(values)}


def per_repetition(rows):
    """One repetition of one group: counts, denominators and the per-Case measures."""
    n = len(rows)
    counts = {name: 0 for name in OUTCOMES}
    not_decided = 0
    for row in rows:
        if row.get("outcome") in counts:
            counts[row["outcome"]] += 1
        else:
            not_decided += 1
    decided = n - not_decided
    latency = [r["latencyMs"] for r in rows if r.get("latencyMs") is not None]
    calls = [r["toolCalls"] for r in rows if r.get("toolCalls") is not None]
    cost = [r["estCostUsd"] for r in rows if r.get("estCostUsd") is not None]
    return {
        "n": n,
        "decided": decided,
        "counts": dict(counts, notDecided=not_decided),
        "withND": {k: counts[k] / n for k in OUTCOMES},
        "withoutND": {k: (counts[k] / decided if decided else None) for k in OUTCOMES},
        "p50": nearest_rank(latency, 50) if latency else None,
        "p95": nearest_rank(latency, 95) if latency else None,
        "calls": (sum(calls) / len(calls)) if calls else None,
        "cost": (sum(cost) / len(cost)) if cost else None,
        "blocked": sum(int(r.get("blockedWrongProposals") or 0) for r in rows),
        "wrong": sum(1 for r in rows if r.get("wrongEffect")),
    }


def range_of(reps, getter):
    values = [getter(r) for r in reps]
    if any(v is None for v in values):
        return None
    return span(values)


def rows_of(cases, mode):
    """The agentDecision rows for a list of case rows, one per (family, subtype, set, mode)."""
    groups = {}
    for case in cases:
        if counted(case):
            key = (case["family"], case.get("subtype", ""), case["set"])
            groups.setdefault(key, []).append(case)
    out = []
    for (family, subtype, cset), members in sorted(groups.items()):
        by_rep = {}
        for member in members:
            by_rep.setdefault(member["repetition"], []).append(member)
        reps = [per_repetition(by_rep[r]) for r in sorted(by_rep)]
        variants = {m["variant"] for m in members}
        row = {
            "family": family,
            "subtype": subtype,
            "set": cset,
            "mode": mode,
            "variantCount": len(variants),
            "repetitionsCovered": len(reps),
            "outcomes": {k: range_of(reps, lambda r, k=k: r["withND"][k]) for k in OUTCOMES},
            "outcomesWithoutNotDecided": {k: range_of(reps, lambda r, k=k: r["withoutND"][k]) for k in OUTCOMES},
            "counts": {k: range_of(reps, lambda r, k=k: r["counts"][k]) for k in OUTCOMES + ("notDecided",)},
            "denominator": {
                "withNotDecided": range_of(reps, lambda r: r["n"]),
                "withoutNotDecided": range_of(reps, lambda r: r["decided"]),
            },
            "latencyMsP50": range_of(reps, lambda r: r["p50"]),
            "latencyMsP95": range_of(reps, lambda r: r["p95"]),
            "toolCallsPerCase": range_of(reps, lambda r: r["calls"]),
            "estCostUsdPerCase": range_of(reps, lambda r: r["cost"]),
            "blockedWrongProposals": range_of(reps, lambda r: r["blocked"]),
            "wrongEffects": range_of(reps, lambda r: r["wrong"]),
            "note": None,
        }
        if any(r["n"] < 20 for r in reps):
            row["note"] = "p95 is the maximum of a repetition when it has fewer than 20 Cases"
        out.append(row)
    return out


def differences(published, computed, path=""):
    """Every place where two JSON values differ (numbers within EPSILON), as readable lines."""
    found = []
    if isinstance(published, dict) and isinstance(computed, dict):
        for key in sorted(set(published) | set(computed)):
            if key not in published:
                found.append(f"{path}/{key}: missing from the report")
            elif key not in computed:
                found.append(f"{path}/{key}: not produced by the recomputation")
            else:
                found.extend(differences(published[key], computed[key], f"{path}/{key}"))
    elif isinstance(published, list) and isinstance(computed, list):
        if len(published) != len(computed):
            found.append(f"{path}: {len(published)} rows published, {len(computed)} recomputed")
        for i, (a, b) in enumerate(zip(published, computed)):
            found.extend(differences(a, b, f"{path}[{i}]"))
    elif isinstance(published, (int, float)) and isinstance(computed, (int, float)) and not isinstance(published, bool):
        if abs(published - computed) > EPSILON:
            found.append(f"{path}: published {published}, recomputed {computed}")
    elif published != computed:
        found.append(f"{path}: published {published!r}, recomputed {computed!r}")
    return found


def sort_key(row):
    return (row["family"], row.get("subtype", ""), row["set"], row["mode"])


def check(report):
    published = sorted(report.get("agentDecision", []), key=sort_key)
    computed = rows_of(report["cases"], report["mode"])
    return differences(published, computed)


def main(argv):
    if len(argv) == 3 and argv[1] == "--emit":
        with open(argv[2], encoding="utf-8") as handle:
            raw = json.load(handle)
        print(json.dumps(rows_of(raw["cases"], raw["mode"]), indent=1, sort_keys=True))
        return 0
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        with open(argv[1], encoding="utf-8") as handle:
            report = json.load(handle)
        problems = check(report)
    except (OSError, ValueError, KeyError) as error:
        print(f"cannot read the report: {error}", file=sys.stderr)
        return 2
    if problems:
        print("the report does not match its raw rows:")
        for line in problems:
            print("  " + line)
        return 1
    print("report matches raw data")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
