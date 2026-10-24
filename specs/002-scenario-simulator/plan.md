# Implementation Plan: Scenario Simulator

**Branch**: `002-scenario-simulator` | **Date**: 2026-10-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-scenario-simulator/spec.md`

## Summary

Build the external world Signal Noir works against: a simulated Origin that emits deterministic
synthetic Orders per scenario instance, and a simulated Partner that answers deliveries by a
declarative script, deduplicates atomically, keeps Receipts with the raw Order snapshot, reports
health and history that can contradict each other, and accepts world-change events. The
technical approach is a `SignalNoir.Sim` package inside the same IPM module and IRIS container,
served by its own `%CSP.REST` application at `/sim/api/v1` that implements
`contracts/openapi-sim.yaml` one to one, with its own globals, a hash-based counter-mode PRNG for
determinism, a lock-guarded deduplication step, and scenario variants as versioned XData
fixtures whose private acceptance rules are never served. No product package references it.

## Technical Context

**Language/Version**: ObjectScript on InterSystems IRIS 2026.3.0AI build 154 (verified live in
001-V1).

**Primary Dependencies**: `%CSP.REST` (HTTP edge), `%Persistent` (state), `%DynamicObject` /
`%DynamicArray` (JSON), `$SYSTEM.Encryption.SHAHash` (PRNG, V1), `$SYSTEM.Util.CreateGUID` (ids,
V2), `Security.Applications` (web app, 001-V11), `%Net.HttpRequest` (contract tests), `%UnitTest`.
Host-side: Python `jsonschema` + `pyyaml` via `uv` for capture validation (as
`contracts/tools/validate_fixtures.py`). No new runtime dependency.

**Storage**: IRIS globals in `IRISAPP_DATA` through `%Persistent` classes of `SignalNoir.Sim.Model`
(own globals `^SignalNoir.Sim.*`), plus `$INCREMENT` counters. Data lives in the container
writable layer like the rest of the app (012).

**Testing**: `%UnitTest` suites `SignalNoir.Tests.Sim.*` run through iris-agentic-dev on the live
instance; contract captures validated against `contracts/openapi-sim.yaml` on the host (research
D13). TDD per Constitution.

**Target Platform**: the single `iris` container (build 154), web port `52773`.

**Project Type**: single IRIS/IPM project; this feature adds one bounded-context package and its
HTTP application.

**Performance Goals**: `fast` responses ≤ 200 ms; 10 concurrent identical deliveries resolve to
one Receipt; with `timeScale ≤ 0.1`, non-timeout variants complete a full script in seconds so the
3-case quick validation fits in 3 min (SC-008).

**Constraints**: implement `contracts/openapi-sim.yaml` without change (FR-001); no product
package references `SignalNoir.Sim` and it references none (Principle I, D10); answer key and
`partnerRule` never served (FR-030); scripted timeouts always exceed the client timeout (D6);
calendar gate — no code before 2026-10-26; integration files (`module.xml`, compose, workflows,
README) and 001's `Bootstrap.cls` untouched until G1.

**Scale/Scope**: 12 HTTP operations; 7 families / 17 subtypes; ≥ 1 tuning variant per subtype; ≥ 5
reserved test variants each for P5 and P8b at freeze; reference run ≈ 30 agent investigations +
controls → ~40 instances per run.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Pure Core** — the Simulator is an external bounded context reached only over HTTP; it
  contains no product rule (classification, equivalence key, idempotency-key derivation stay in
  `SignalNoir.Core`); an isolation test fails on any cross-reference (D10).
- [x] **II. Closed Action Catalog / Read-Only Agent** — no Action is defined or executed here;
  embedded instructions in bodies, notes and logs are served as data and never interpreted; no
  runtime code execution (scripts are declarative data, D7).
- [x] **III. One Validator** — N/A: the Simulator validates no Proposal; it owns no Policy or
  Mapping (FR-002).
- [x] **IV. Human Authority** — N/A for approvals; the Simulator supports P3 by changing the world
  after Approval (events and read triggers, D12) without knowing about Approval.
- [x] **V. Case as Source of Truth** — N/A: no Case state here; the Receipt here is the Partner's
  canonical Receipt (AD-14), of which the Case keeps an audit copy.
- [x] **VI. Effects at Most Once** — atomic Partner-side deduplication on key + payload with the
  original Receipt returned and 422 on reuse (D5); lost response, repeated approval, restart and
  late-worker variants provided for the recovery suite.
- [x] **VII. Honest Outcomes** — internal operations return `SignalNoir.Sim.Result` values; the
  Simulator never fakes a Receipt the script did not record; history distinguishes timeout from
  error.
- [x] **VIII. Honest Measurement** — answer key absent from the Simulator; private acceptance rules
  never served (D8); tuning and reserved test variants separated, reserved set committed at freeze
  by its holder (D9); every repetition is its own instance.
- [x] **IX. Verifiable Increments** — sliced by the spec's 7 observable stories, each with
  contract tests; the first slice (instance + emission + success delivery) feeds the tracer path;
  dependencies explicit below.
- [x] **Platform Constraints** — build 154, synthetic data (`synthetic: true` on every Order), no
  secrets involved, no image published.
- [ ] **iris-agentic-dev** — **blocking before /speckit-implement**. Reused claims are
  001-verified (`%CSP.REST`, `Security.Applications`, `%Persistent`, `%UnitTest`). New claims V1–V6
  (research.md) MUST be verified with throwaway probes through iris-agentic-dev and logged in
  research.md "Verification log" before any task runs; probes are not submission code and are
  deleted after the check. The gate turns to pass only when V1–V6 are logged; a failed V4 reopens
  research D6 before tasks proceed. The runtime does not depend on iris-agentic-dev.

### Post-design re-check (after Phase 1)

Re-evaluated after research.md, data-model.md, contracts/scenario-script.md and quickstart.md:
gates I–IX and Platform remain pass; the iris-agentic-dev gate stays **blocking until V1–V6 are
logged**.
No change to a frozen input is proposed: SIM-Q1…Q8 are resolved inside the existing contract.
The one unresolved cross-feature value — the read count at which a P3 trigger fires (D12) — is
per-variant data, to be confirmed with 006 and 008 at G1.

## Project Structure

### Documentation (this feature)

```text
specs/002-scenario-simulator/
├── plan.md               # This file
├── research.md           # Phase 0: decisions D1–D14, SIM-Q resolutions, verification backlog
├── data-model.md         # Phase 1: entities, transitions, request validation
├── quickstart.md         # Phase 1: validation guide
├── contracts/
│   └── scenario-script.md   # Internal contract: variant/script format, private partnerRule
├── checklists/
│   └── requirements.md
└── tasks.md              # Phase 2 (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
src/SignalNoir/Sim/
├── Api/
│   └── Dispatch.cls          # %CSP.REST /sim/api/v1 — the 12 contract operations, error envelope
├── Setup.cls                 # EnsureWebApplication() — idempotent, called by tests now, by Bootstrap at G1
├── Result.cls                # Sim-local result value (no dependency on SignalNoir.Core)
├── Prng.cls                  # Counter-mode SHA-256 draws (D3)
├── Ids.cls                   # sci_/ORD-/txn_/rcp_ generation (D4)
├── Canon.cls                 # Canonical payload for deduplication (D5) — not the equivalence key
├── Catalog/
│   ├── Loader.cls            # Reads XData variants, serves public form (D7, D8)
│   ├── Clean.cls  P1.cls  P3.cls  P5.cls  P8.cls  P9.cls  Idempotency.cls   # tuning variants
│   └── P5Test.cls  P8Test.cls                                                  # reserved set (shape only until freeze, D9)
├── Script.cls                # Attempt matching, delays, triggers
├── Scenarios.cls             # create / read / emit / events
├── Partner.cls               # deliver (dedup + script), health, history
├── Origin.cls                # feed, status, recent orders by patient
├── Receipts.cls              # search, read
└── Model/
    ├── Instance.cls  OriginOrder.cls  FeedItem.cls  Delivery.cls
    ├── Receipt.cls   PartnerState.cls  Event.cls
tests/SignalNoir/Tests/Sim/
├── Core/                     # Prng, Ids, Canon, Script, Catalog (no HTTP)
├── Contract/                 # one class per tag: Scenarios, Origin, Partner, Receipts
└── Isolation/                # cross-reference test, answer-key leak scan
tests/sim-contract/
├── captures/                 # JSON responses written by the contract suite + manifest.json
└── validate_sim_captures.py  # validates captures against contracts/openapi-sim.yaml
```

**Structure Decision**: one bounded-context package `SignalNoir.Sim` under the existing
`src/SignalNoir` tree, as the architecture's minimal tree prescribes (`Sim/`). It is covered by
the existing `SignalNoir.PKG` resource, so `module.xml` does not change. Tests follow 001's
`tests/SignalNoir/Tests/<Area>` layout. The write zone of this feature is exactly
`src/SignalNoir/Sim/**`, `tests/SignalNoir/Tests/Sim/**`, `tests/sim-contract/**` and
`specs/002-scenario-simulator/**`.

## Dependencies and integration

- **Consumes**: `contracts/openapi-sim.yaml` (frozen). No dependency on any product package.
- **Consumed by**: 003 (feed polling), 006 (evidence Tools over HTTP), 008 (delivery,
  Reconciliation, P3 Revalidation reads), 010 (instances, seeds, sets), 011 (P9 data).
- **Gate G1 integration changes** (applied by the integrator, not in this branch):
  1. `SignalNoir.Interop.Bootstrap.OnStart` calls `##class(SignalNoir.Sim.Setup).EnsureWebApplication()`.
  2. CI (`.github/workflows/contracts.yml`) runs `tests/sim-contract/validate_sim_captures.py` on
     committed captures, if the workflow owner agrees.
- **To confirm at G1**: P3 trigger read count (D12) with 006/008; `SN_PARTNER_TIMEOUT_SECONDS` stays
  the single source of the client timeout (D6) with 008.

## Complexity Tracking

> No Constitution principle is violated. Deviations from the default that need a note:

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Sim-local `Result` type instead of `SignalNoir.Core.Result` | The Simulator must not reference product code (Principle I, D10) | Reusing the Core type couples an external system to the product and breaks the isolation test |
| Private `partnerRule` alongside the served script | P8b and unknown-code variants need a Partner acceptance rule that implies the right Mapping | Serving it leaks answer-key content (FR-030); no script at all contradicts the contract's catalog |
| Python capture validator outside `contracts/tools/` | Simulator captures are produced by this feature's tests; `contracts/fixtures/**` is a frozen input | Writing into `contracts/fixtures/` would edit a frozen input |
| iris-agentic-dev gate blocking until V1–V6 are logged | The planning session had no iris-agentic-dev access | Verifying through `docker exec` is not an accepted path (Constitution, Development Environment) |
