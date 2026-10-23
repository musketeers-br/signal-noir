"""Regenerate the negative cases of validate_state_machine.py.

Usage (from the repo root):
    uv run --with pyyaml python contracts/tools/tests/state_machine/generate_cases.py

Each case is a copy of a source table (_base.yaml or contracts/case-state-machine.yaml) with one
change, written next to this script, and listed in cases.json with the error text the validator
must report. Run it after editing the real table or the spec, then run
contracts/tools/test_validate_state_machine.py. To add a case, add an entry to CASES here first and
watch the test fail before changing the validator (TDD).
"""

import copy
import json
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = HERE / "_base.yaml"
REAL = ROOT / "contracts" / "case-state-machine.yaml"
SPEC = ROOT / "specs" / "001-case-state-machine" / "spec.md"

EMPTY_FOLLOW_UP = {"outbox": [], "inProcess": None, "dossier": False, "terminal": False}


def row(doc, tid):
    return next(r for r in doc["transitions"] if r["id"] == tid)


def attachment(doc, event):
    return next(a for a in doc["attachments"] if a["event"] == event)


def extra_row(doc, source, target, command=None, preconditions=None, events=()):
    doc["transitions"].append({
        "id": "T30", "from": source, "to": target, "trigger": "forbidden shortcut", "command": command,
        "actors": ["system"], "preconditions": preconditions or [{"check": "state", "expected": source}],
        "events": list(events), "followUp": dict(EMPTY_FOLLOW_UP),
    })


def drop_row(doc, tid):
    doc["transitions"] = [r for r in doc["transitions"] if r["id"] != tid]


# ---------- mutations ----------

def states_missing_failed(doc):
    doc["states"] = [s for s in doc["states"] if s["name"] != "Failed"]


def transition_without_precondition(doc):
    row(doc, "T03")["preconditions"] = []


def unknown_event(doc):
    row(doc, "T01")["events"] = ["ApprovalTimedOut"]


def unknown_command(doc):
    row(doc, "T03")["followUp"]["outbox"] = ["Investigar"]


def spec_parity_actor(doc):
    row(doc, "T03")["actors"] = ["sweeper"]


def trace_unknown_ref(doc):
    doc["journeyTrace"] = [{"journey": "UJ-1", "step": "step 5", "refs": ["T99"], "actors": ["operator:*"]}]


def trace_missing_step(doc):
    doc["journeyTrace"] = [s for s in doc["journeyTrace"] if (s["journey"], s["step"]) != ("UJ-2", "step 5 (variant)")]


def benchmark_outside_t12(doc):
    row(doc, "T11")["actors"] = ["operator:*", "benchmark"]


def proposer_outside_t04(doc):
    row(doc, "T14")["actors"] = ["agent"]


def duplicate_owner(doc):
    row(doc, "T20")["preconditions"] = copy.deepcopy(row(doc, "T19")["preconditions"])
    row(doc, "T20")["actors"] = ["sweeper"]


def refusal_changes_state(doc):
    next(r for r in doc["refusals"] if r["code"] == "INVALID_ACTOR")["changesState"] = True


def expire_by_system(doc):
    row(doc, "T18")["actors"] = ["system"]


def denials_param_mismatch(doc):
    doc["parameters"]["maxDenials"] = 3
    for pre in row(doc, "T15")["preconditions"]:
        if pre["check"] == "denialCount":
            pre["expected"] = 2


def review_auto_exit(doc):
    row(doc, "T29")["actors"] = ["system"]


def t26_without_dossier(doc):
    row(doc, "T26")["events"] = ["ReconciliationPerformed"]
    row(doc, "T26")["followUp"]["dossier"] = False


def revalidation_after_attempt(doc):
    r = row(doc, "T19")
    r["preconditions"] = [p for p in r["preconditions"] if p["check"] != "noAttemptSent"]


def unmarked_contract_change(doc):
    row(doc, "T26").pop("pendingContractChange")
    row(doc, "T26").pop("contractChanges")


def exception_trigger_elsewhere(doc):
    row(doc, "T27")["preconditions"].append({"check": "newException", "expected": True})


def terminal_annotation_kind(doc):
    attachment(doc, "Annotation")["terminalKinds"].append("note")


def terminal_attachment(doc):
    attachment(doc, "ExceptionRecorded")["states"].append("Resolved")


# (file, source, expected error text, note, mutation[, spec copy])
CASES = [
    ("states-missing-failed.yaml", BASE, "states differ from CaseState", "state Failed removed", states_missing_failed),
    ("transition-without-precondition.yaml", BASE, "T03: no preconditions", "T03 has no preconditions",
     transition_without_precondition),
    ("unknown-event.yaml", BASE, "T01: event ApprovalTimedOut not in TimelineEventType",
     "T01 emits an event outside TimelineEventType", unknown_event),
    ("unknown-command.yaml", BASE, "T03: command Investigar not allowed", "T03 outbox command outside the closed set",
     unknown_command),
    ("spec-parity-actor.yaml", BASE, "T03: actors differ from spec.md", "T03 actor differs from the spec table",
     spec_parity_actor),
    ("id-gap.yaml", BASE, "transition ids must be sequential", "T02 removed, ids T01, T03",
     lambda d: drop_row(d, "T02")),
    ("trace-unknown-ref.yaml", REAL, "journeyTrace UJ-1: unknown ref T99", "UJ-1 step cites a transition that does not exist",
     trace_unknown_ref),
    ("trace-missing-step.yaml", REAL, 'journeyTrace UJ-2: missing step "step 5 (variant)"',
     "UJ-2 trace without its cancelled-at-origin variant", trace_missing_step),
    ("state-no-exit.yaml", REAL, "Held: non-terminal state has no exit", "T27 removed, Held has no exit",
     lambda d: drop_row(d, "T27")),
    ("open-to-executing.yaml", REAL, "T30: transition not in spec.md", "extra row Open → Executing",
     lambda d: extra_row(d, "Open", "Executing", "Execute", events=["ExecutionAuthorized"])),
    ("benchmark-outside-t12.yaml", REAL, "T11: actor benchmark only allowed in T12", "benchmark may approve through T11",
     benchmark_outside_t12),
    ("proposer-outside-t04.yaml", REAL, "T14: proposer actors only allowed in T04",
     "a proposer performs Rejected → Investigating", proposer_outside_t04),
    ("duplicate-owner.yaml", REAL, "Executing → Held: rows T19, T20 not distinguishable by preconditions",
     "T19 and T20 share preconditions with different owners", duplicate_owner),
    ("refusal-changes-state.yaml", REAL, "refusals INVALID_ACTOR: must not change state", "a refusal that changes state",
     refusal_changes_state),
    ("expire-by-system.yaml", REAL, "T18: expiration must be owned by sweeper only", "expiration owned by system",
     expire_by_system, "spec-expire-by-system.md"),
    ("held-extra-exit.yaml", REAL, "Held: only exit allowed is T27", "extra exit Held → PendingApproval",
     lambda d: extra_row(d, "Held", "PendingApproval")),
    ("denials-param-mismatch.yaml", REAL, "T15: denialCount must equal parameters.maxDenials",
     "maxDenials 3 while T15 hard-codes 2", denials_param_mismatch),
    ("review-auto-exit.yaml", REAL, "T29: ReviewRequired exits only by operator",
     "ReviewRequired → Cancelled performed by system", review_auto_exit),
    ("executing-to-pending.yaml", REAL, "Executing → PendingApproval is forbidden by D3",
     "Executing → PendingApproval, forbidden by D3",
     lambda d: extra_row(d, "Executing", "PendingApproval",
                         preconditions=[{"check": "revalidationFailed", "expected": "APPROVAL_VALID"}],
                         events=["RevalidationPerformed"])),
    ("t26-without-dossier.yaml", REAL, "T26: rows into ReviewRequired must emit DossierCreated",
     "T26 reaches ReviewRequired without a Dossier", t26_without_dossier),
    ("revalidation-after-attempt.yaml", REAL, "T19: revalidation exits require noAttemptSent",
     "T19 may fire after an Attempt was sent", revalidation_after_attempt),
    ("unmarked-contract-change.yaml", REAL, "T26: Dossier reason outcome_unknown not in the contract",
     "T26 uses outcome_unknown without pendingContractChange", unmarked_contract_change),
    ("exception-trigger-elsewhere.yaml", REAL,
     "T27: only rows from PendingApproval may be triggered by a new Exception (D1)",
     "Held → Investigating triggered by a new Exception", exception_trigger_elsewhere),
    ("failed-reopens.yaml", REAL, "Failed: terminal state has an exit", "Failed → Investigating reopens a terminal Case",
     lambda d: extra_row(d, "Failed", "Investigating", "Investigate")),
    ("terminal-annotation-kind.yaml", REAL,
     "Annotation: terminal states only accept receipt_corrected, receipt_missing, new_episode_opened",
     "terminal Cases accept free notes", terminal_annotation_kind),
    ("terminal-attachment.yaml", REAL, "ExceptionRecorded: not accepted in terminal state Resolved",
     "a new Exception attached to a Resolved Case", terminal_attachment),
]


def write_spec_expire_by_system():
    """Spec copy where T18 is owned by system, so spec parity does not mask the single-owner rule."""
    lines = SPEC.read_text(encoding="utf-8").splitlines(keepends=True)
    changed = [l.replace("| `sweeper` |", "| `system` |", 1) if l.startswith("| T18 |") else l for l in lines]
    if changed == lines:
        raise SystemExit("spec.md: T18 row with actor `sweeper` not found")
    header = "<!-- Generated by generate_cases.py: copy of specs/001-case-state-machine/spec.md with T18 owned by system. -->\n"
    (HERE / "spec-expire-by-system.md").write_text(header + "".join(changed), encoding="utf-8")


def main():
    sources = {path: yaml.safe_load(path.read_text(encoding="utf-8")) for path in (BASE, REAL)}
    entries = []
    for file, source, expect, note, mutate, *spec in CASES:
        doc = copy.deepcopy(sources[source])
        mutate(doc)
        text = f"# Negative case (generated by generate_cases.py): {note}\n"
        text += yaml.safe_dump(doc, sort_keys=False, allow_unicode=True, width=110)
        (HERE / file).write_text(text, encoding="utf-8")
        entry = {"file": file, "expect": expect}
        if spec:
            entry["spec"] = spec[0]
        entries.append(entry)
    write_spec_expire_by_system()
    (HERE / "cases.json").write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{len(entries)} cases written")


if __name__ == "__main__":
    main()
