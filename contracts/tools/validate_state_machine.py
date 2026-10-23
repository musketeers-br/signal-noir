"""Validate contracts/case-state-machine.yaml, the normative Case state machine (story 2.2 / B01).

Usage (from the repo root):
    uv run --with pyyaml python contracts/tools/validate_state_machine.py [--file PATH] [--spec PATH]

The table is checked against contracts/openapi-signalnoir.yaml (CaseState, Actor,
TimelineEventType) and against the human-readable table of specs/001-case-state-machine/spec.md,
so the two forms cannot drift. Exit code 1 when any rule fails. Rules are numbered as in
specs/001-case-state-machine/research.md (R2).
"""

import argparse
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_TABLE = ROOT / "contracts" / "case-state-machine.yaml"
DEFAULT_SPEC = ROOT / "specs" / "001-case-state-machine" / "spec.md"
DEFAULT_OPENAPI = ROOT / "contracts" / "openapi-signalnoir.yaml"

COMMANDS = {"Investigate", "Execute", "Reconcile", "Expire", "Reassess", "Resume", "decideProposal", "resolveReview"}
REFUSAL_CODES = ["INVALID_TRANSITION", "INVALID_ACTOR", "STALE_VERSION", "APPROVAL_EXPIRED"]
PROPOSERS = {"agent", "rules", "replay"}
# Rows each restricted actor may own (spec FR-013 and FR-017).
ACTOR_SCOPE = {"benchmark": {"T12"}, "sweeper": {"T06", "T18"}}
PROPOSER_SCOPE = {"T04"}
ID_PATTERN = re.compile(r"^T\d{2}$")
SPEC_ROW = re.compile(r"^\| (T\d{2}) \|")
SPEC_TRACE_ROW = re.compile(r"^\| (UJ-\d) ([^:|]+):")
TRACE_REF = re.compile(r"\b(T\d{2}|FR-\d{3})\b")
BACKTICK = re.compile(r"`([^`]+)`")
DOSSIER_REASON = re.compile(r"reason(?:=| ∈ )([^\"]+)")
DECISION_IDS = [f"D{n}" for n in range(1, 6)]
TERMINAL_ATTACHMENTS = {"Annotation", "CommandDiscarded"}
TERMINAL_KINDS = ["receipt_corrected", "receipt_missing", "new_episode_opened"]


def load_openapi(path):
    schemas = yaml.safe_load(Path(path).read_text(encoding="utf-8"))["components"]["schemas"]
    return {
        "states": list(schemas["CaseState"]["enum"]),
        "events": set(schemas["TimelineEventType"]["enum"]),
        "actor": re.compile(schemas["Actor"]["pattern"]),
        "dossierReasons": set(schemas["Dossier"]["properties"]["reason"]["enum"]),
    }


def normalize_actor(actor):
    return "operator:*" if actor.startswith("operator:") else actor


def parse_spec_transitions(path):
    """Rows of the normative table in spec.md: {id: (from, to, {actors})}."""
    rows = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        match = SPEC_ROW.match(line)
        if not match:
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        source, _, target = cells[1].partition("→")
        source = BACKTICK.findall(source)
        target = BACKTICK.findall(target)
        actors = {normalize_actor(a) for a in BACKTICK.findall(cells[3])}
        rows[match.group(1)] = (source[0] if source else None, target[0] if target else None, actors)
    return rows


def parse_spec_trace(path):
    """Rows of the "Journey trace" table in spec.md: {(journey, step): {refs}}."""
    steps = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        match = SPEC_TRACE_ROW.match(line)
        if match:
            refs_cell = line.strip().strip("|").split("|")[1]
            steps[(match.group(1), match.group(2).strip())] = set(TRACE_REF.findall(refs_cell))
    return steps


def actor_is_valid(actor, pattern):
    return bool(pattern.match("operator:x" if actor == "operator:*" else actor))


# ---------- rules ----------

def rule_states(table, api, errors):
    """Rule 1: the states are exactly CaseState."""
    names = [s["name"] for s in table.get("states", [])]
    missing = [s for s in api["states"] if s not in names]
    extra = [s for s in names if s not in api["states"]]
    if missing or extra:
        errors.append(f"states differ from CaseState: missing={missing} extra={extra}")


def rule_rows(table, api, errors):
    """Rule 3: every transition is complete and uses closed vocabularies; ids are sequential."""
    states = {s["name"] for s in table.get("states", [])}
    ids = []
    for row in table.get("transitions", []):
        tid = row.get("id", "?")
        ids.append(tid)
        if not ID_PATTERN.match(str(tid)):
            errors.append(f"{tid}: id must match T\\d{{2}}")
        for side in ("from", "to"):
            value = row.get(side)
            if value is not None and value not in states:
                errors.append(f"{tid}: {side} {value} is not a declared state")
        if row.get("to") is None:
            errors.append(f"{tid}: missing to")
        actors = row.get("actors") or []
        if not actors:
            errors.append(f"{tid}: no actors")
        for actor in actors:
            if not actor_is_valid(actor, api["actor"]):
                errors.append(f"{tid}: actor {actor} does not match Actor")
        if not row.get("preconditions"):
            errors.append(f"{tid}: no preconditions")
        for event in row.get("events") or []:
            if event == "StateChanged":
                errors.append(f"{tid}: StateChanged is implicit and must not be listed")
            elif event not in api["events"]:
                errors.append(f"{tid}: event {event} not in TimelineEventType")
        follow = row.get("followUp")
        if not isinstance(follow, dict):
            errors.append(f"{tid}: no followUp")
            follow = {}
        commands = list(follow.get("outbox") or [])
        if row.get("command") is not None:
            commands.append(row["command"])
        for command in commands:
            if command not in COMMANDS:
                errors.append(f"{tid}: command {command} not allowed")
    expected = [f"T{n:02d}" for n in range(1, len(ids) + 1)]
    if ids != expected:
        errors.append(f"transition ids must be sequential from T01: got {ids}")


def rule_spec_parity(table, spec_rows, errors):
    """Rule 6: same ids, from/to and actors as the table in spec.md."""
    yaml_rows = {r.get("id"): r for r in table.get("transitions", [])}
    for tid in sorted(set(spec_rows) - set(yaml_rows)):
        errors.append(f"{tid}: in spec.md but missing from the table")
    for tid in sorted(set(yaml_rows) - set(spec_rows)):
        errors.append(f"{tid}: transition not in spec.md")
    for tid in sorted(set(yaml_rows) & set(spec_rows)):
        source, target, actors = spec_rows[tid]
        row = yaml_rows[tid]
        if (row.get("from"), row.get("to")) != (source, target):
            errors.append(f"{tid}: from/to {row.get('from')} → {row.get('to')} differ from spec.md {source} → {target}")
        if {normalize_actor(a) for a in row.get("actors") or []} != actors:
            errors.append(f"{tid}: actors differ from spec.md: {sorted(row.get('actors') or [])} vs {sorted(actors)}")


def rule_coverage(table, errors):
    """Rule 2: non-terminal states have an entry and an exit; terminal states have no exit."""
    rows = table.get("transitions", [])
    sources = {r.get("from") for r in rows}
    targets = {r.get("to") for r in rows}
    for state in table.get("states", []):
        name = state["name"]
        if state.get("class") == "terminal":
            if name in sources:
                errors.append(f"{name}: terminal state has an exit")
            if name not in targets:
                errors.append(f"{name}: terminal state has no entry")
            continue
        if name not in sources:
            errors.append(f"{name}: non-terminal state has no exit")
        if name not in targets:
            errors.append(f"{name}: non-terminal state has no entry")
    for row in rows:
        if row.get("from") is None and row.get("to") != "Open":
            errors.append(f"{row.get('id')}: creation rows must lead to Open")


def rule_trace(table, spec_trace, errors):
    """Rule 5: journeyTrace cites existing ids and matches the "Journey trace" table of spec.md."""
    ids = {r.get("id") for r in table.get("transitions", [])}
    seen = {}
    for step in table.get("journeyTrace", []):
        journey, name = step.get("journey"), str(step.get("step"))
        refs = step.get("refs") or []
        for ref in refs:
            if not (ref in ids or re.fullmatch(r"FR-\d{3}", str(ref))):
                errors.append(f"journeyTrace {journey}: unknown ref {ref}")
        seen[(journey, name)] = set(refs)
    for key in spec_trace.keys() - seen.keys():
        errors.append(f'journeyTrace {key[0]}: missing step "{key[1]}"')
    for key in seen.keys() - spec_trace.keys():
        errors.append(f'journeyTrace {key[0]}: step "{key[1]}" not in spec.md')
    for key in seen.keys() & spec_trace.keys():
        if seen[key] != spec_trace[key]:
            errors.append(f'journeyTrace {key[0]} "{key[1]}": refs {sorted(seen[key])} differ from spec.md {sorted(spec_trace[key])}')


def precondition_key(row):
    return frozenset((p.get("check"), repr(p.get("expected"))) for p in row.get("preconditions") or [])


def rule_owners(table, errors):
    """Rule 4: one owner per transition (review H-1) and restricted actors stay in their rows."""
    by_pair = {}
    for row in table.get("transitions", []):
        by_pair.setdefault((row.get("from"), row.get("to")), []).append(row)
        tid = row.get("id")
        actors = set(row.get("actors") or [])
        for actor, allowed in ACTOR_SCOPE.items():
            if actor in actors and tid not in allowed:
                errors.append(f"{tid}: actor {actor} only allowed in {', '.join(sorted(allowed))}")
        if actors & PROPOSERS and tid not in PROPOSER_SCOPE:
            errors.append(f"{tid}: proposer actors only allowed in {', '.join(sorted(PROPOSER_SCOPE))}")
    for (source, target), rows in by_pair.items():
        for i, first in enumerate(rows):
            for second in rows[i + 1:]:
                if precondition_key(first) == precondition_key(second):
                    errors.append(f"{source or '—'} → {target}: rows {first.get('id')}, {second.get('id')} "
                                  "not distinguishable by preconditions")


def resolve(value, parameters):
    """Precondition values may name a parameter (e.g. maxDenials)."""
    return parameters.get(value, value) if isinstance(value, str) else value


def rule_single_owners(table, errors):
    """Expiration, Held and ReviewRequired each have one owner (spec FR-007, FR-009, FR-010)."""
    rows = table.get("transitions", [])
    parameters = table.get("parameters") or {}
    for row in rows:
        tid = row.get("id")
        if row.get("command") == "Expire" and row.get("actors") != ["sweeper"]:
            errors.append(f"{tid}: expiration must be owned by sweeper only")
        if row.get("from") == "ReviewRequired" and row.get("actors") != ["operator:*"]:
            errors.append(f"{tid}: ReviewRequired exits only by operator")
    reassess = sorted(r.get("id") for r in rows if r.get("from") == "Held" and r.get("command") == "Reassess")
    for row in rows:
        if row.get("from") == "Held" and row.get("id") not in reassess:
            errors.append(f"Held: only exit allowed is {', '.join(reassess) or 'a Reassess row'} "
                          f"(command Reassess), found {row.get('id')}")
    for row in rows:
        if (row.get("from"), row.get("to")) != ("Rejected", "ReviewRequired"):
            continue
        for pre in row.get("preconditions") or []:
            if pre.get("check") == "denialCount" and resolve(pre.get("expected"), parameters) != parameters.get("maxDenials"):
                errors.append(f"{row.get('id')}: denialCount must equal parameters.maxDenials")


def rule_decisions(table, errors):
    """D1–D5: all present, forbidden pairs absent, and D1's single Exception-triggered origin."""
    decisions = table.get("decisions") or []
    ids = [d.get("id") for d in decisions]
    if ids != DECISION_IDS:
        errors.append(f"decisions: ids must be {DECISION_IDS}, got {ids}")
    contradictions = sorted(d.get("contradiction") for d in decisions if d.get("contradiction") is not None)
    if contradictions != list(range(1, len(decisions) + 1)):
        errors.append(f"decisions: each contradiction 1..{len(decisions)} must be resolved once, got {contradictions}")
    for decision in decisions:
        for field in ("rule", "reason", "replaces"):
            if not decision.get(field):
                errors.append(f"decisions {decision.get('id')}: missing {field}")
    rows = table.get("transitions", [])
    pairs = {(r.get("from"), r.get("to")): r.get("id") for r in rows}
    for decision in decisions:
        for source, target in decision.get("forbids") or []:
            if (source, target) in pairs:
                errors.append(f"{source} → {target} is forbidden by {decision.get('id')} (row {pairs[(source, target)]})")
        allowed = decision.get("exceptionTriggersOnlyFrom")
        if allowed is None:
            continue
        for row in rows:
            triggered = any(p.get("check") == "newException" for p in row.get("preconditions") or [])
            if triggered and row.get("from") not in allowed:
                errors.append(f"{row.get('id')}: only rows from {', '.join(allowed)} may be triggered by a new Exception "
                              f"({decision.get('id')})")


def rule_outcomes(table, errors):
    """Review and uncertainty rows: Dossier on entering ReviewRequired; revalidation exits send nothing."""
    for row in table.get("transitions", []):
        tid = row.get("id")
        if row.get("to") == "ReviewRequired":
            if "DossierCreated" not in (row.get("events") or []) or not (row.get("followUp") or {}).get("dossier"):
                errors.append(f"{tid}: rows into ReviewRequired must emit DossierCreated and set followUp.dossier")
        if any(p.get("check") == "revalidationFailed" for p in row.get("preconditions") or []):
            checks = {p.get("check") for p in row.get("preconditions") or []}
            if "noAttemptSent" not in checks:
                errors.append(f"{tid}: revalidation exits require noAttemptSent")
            if not any("authorization voided" in e for e in row.get("effectsOnRecords") or []):
                errors.append(f"{tid}: revalidation exits must void the recorded authorization")


def rule_contract_changes(table, api, errors):
    """Values the OpenAPI does not have yet are allowed only when marked pendingContractChange."""
    for row in table.get("transitions", []):
        for effect in row.get("effectsOnRecords") or []:
            for match in DOSSIER_REASON.finditer(effect):
                reasons = [r.split("(")[0].strip() for r in match.group(1).split(",")]
                for reason in filter(None, reasons):
                    if reason not in api["dossierReasons"] and row.get("pendingContractChange") != "2.5":
                        errors.append(f"{row.get('id')}: Dossier reason {reason} not in the contract; "
                                      "mark the row pendingContractChange: \"2.5\"")


def pending_contract_changes(table):
    """Elements marked pendingContractChange, for the report handed to story 2.5."""
    marked = []
    for section in ("transitions", "attachments", "refusals"):
        for item in table.get(section) or []:
            if item.get("pendingContractChange"):
                name = item.get("id") or item.get("event") or item.get("code")
                marked.append(f"{name} {item.get('contractChanges') or []}")
    return marked


def rule_attachments(table, api, errors):
    """Attachments use known events and states; terminal states only take the D5/T02 annotations."""
    states = {s["name"]: s.get("class") for s in table.get("states", [])}
    terminals = {name for name, cls in states.items() if cls == "terminal"}
    for attachment in table.get("attachments") or []:
        event = attachment.get("event")
        if event not in api["events"]:
            errors.append(f"attachment {event}: not in TimelineEventType")
        listed = attachment.get("states") or []
        expanded = set(states) if "*" in listed else set(listed)
        for state in expanded - set(states):
            errors.append(f"{event}: unknown state {state}")
        in_terminal = sorted(expanded & terminals)
        if not in_terminal:
            continue
        if event not in TERMINAL_ATTACHMENTS:
            for state in in_terminal:
                errors.append(f"{event}: not accepted in terminal state {state}")
        elif event == "Annotation":
            kinds = attachment.get("terminalKinds")
            if kinds is None or not set(kinds) <= set(TERMINAL_KINDS):
                errors.append(f"Annotation: terminal states only accept {', '.join(TERMINAL_KINDS)}; got {kinds}")


def rule_refusals(table, errors):
    """Refusals: the four codes, each recorded as CommandDiscarded and never changing state."""
    refusals = table.get("refusals") or []
    codes = [r.get("code") for r in refusals]
    if sorted(codes) != sorted(REFUSAL_CODES):
        errors.append(f"refusals: codes must be exactly {REFUSAL_CODES}, got {codes}")
    for refusal in refusals:
        code = refusal.get("code")
        if refusal.get("records") != "CommandDiscarded":
            errors.append(f"refusals {code}: must be recorded as CommandDiscarded")
        if refusal.get("changesState") is not False:
            errors.append(f"refusals {code}: must not change state")
        if not refusal.get("when"):
            errors.append(f"refusals {code}: missing when")


def validate(table_path=DEFAULT_TABLE, spec_path=DEFAULT_SPEC, openapi_path=DEFAULT_OPENAPI):
    """Return the list of rule violations; empty when the table is valid."""
    try:
        table = yaml.safe_load(Path(table_path).read_text(encoding="utf-8")) or {}
    except (OSError, yaml.YAMLError) as exc:
        return [f"cannot read {table_path}: {exc}"]
    api = load_openapi(openapi_path)
    errors = []
    rule_states(table, api, errors)
    rule_coverage(table, errors)
    rule_rows(table, api, errors)
    rule_owners(table, errors)
    rule_single_owners(table, errors)
    rule_refusals(table, errors)
    rule_attachments(table, api, errors)
    rule_decisions(table, errors)
    rule_outcomes(table, errors)
    rule_contract_changes(table, api, errors)
    rule_trace(table, parse_spec_trace(spec_path), errors)
    rule_spec_parity(table, parse_spec_transitions(spec_path), errors)
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--file", type=Path, default=DEFAULT_TABLE)
    parser.add_argument("--spec", type=Path, default=DEFAULT_SPEC)
    args = parser.parse_args()
    errors = validate(args.file, args.spec, DEFAULT_OPENAPI)
    for err in errors:
        print(f"FAIL {err}")
    if not errors:
        print(f"ok   {args.file}")
    table = yaml.safe_load(Path(args.file).read_text(encoding="utf-8")) or {}
    marked = pending_contract_changes(table)
    if marked:
        print("\npending contract changes (2.5):")
        for item in marked:
            print(f"  - {item}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
