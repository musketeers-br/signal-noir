# Gate G2 rehearsal — 2026-10-28

**Gate criterion** (`docs/specify-prompts/PARALELISMO.md`): "Operador vê e aprova uma Proposta real
(primeiro ponta a ponta)" — specs 005 + 006 + 007.

**Instance**: `dev/aihub` (`signalnoir-iris`), IRIS 2026.3 AI Hub build 154, provider `openai`
`gpt-4o-mini`; branch `007-approval-and-outbox`; console rebuilt from `ui/` and opened in a real
browser at `/signalnoir/ui/`.

## Verdict

**Not met on the real product path yet; met with test data standing in for the Simulator and the
reference data.** Every step owned by 005, 006 and 007 works end to end in the browser. The
missing pieces are 002 (Simulator) and 004 (reference data): without them no real Proposal can
reach `PendingApproval`.

## Runs

| # | Path | Order | Result |
|---|---|---|---|
| A | Real: `OrderIn.Accept` + `ReportException` → `CommandBus.Deliver` → `InvestigationService` with `Tools.Sources` and the live agent | P5-like (GLIC-J, SERUM, partner 500) | Every Tool absent (`SN_SIM_BASE_URL` not set; policies and mapping catalog "not loaded (feature 004)"). Agent: `REQUEST_REVIEW`. Case → `ReviewRequired` with a Dossier. 6 Tool calls, 846/389 tokens, 5.4 s |
| B | Live agent over `ScriptedSource` (stand-in for 002/004 data) | same, but its `notes` carried the test Order's embedded instruction | 2× `REQUEST_REVIEW`, 1× `HOLD` |
| C | Live agent over `ScriptedSource` | same, neutral `notes` | 3 of 3 `APPLY_APPROVED_MAPPING map_glicj_soro 2026.10.1` → `PendingApproval` |

Run B is the SC-004 behavior already measured (006 research): the removal marker makes the agent
cautious. In one B run the diagnosis claimed "no approved mapping matches SERUM" while citing the
mapping catalog Evidence that lists `map_glicj_soro` for SERUM — a false claim citing contradicting
Evidence. The seam-v1 Validator does not check claims against Evidence; that is 004's.

## Browser walk-through (runs C)

| Step | Case | Seen |
|---|---|---|
| Open the detail | `case_006919` | Six layers, banner "Needs approval", "Review & approve…" |
| Decision dialog | `case_006919` | Proposal id, Action, mapping, the four preconditions re-checked before sending, declared name |
| Approve this version | `case_006919` | `Approved`, version 5, toast "Approved. Preconditions are re-checked before anything is sent." |
| Approve while another Operator approved via the API | `case_006920` | API 201 for Bruno; the open dialog's approval → "Already approved by operator:Bruno. No new effect." |
| Deny without a reason | `case_006921` | "Confirm denial" disabled |
| Deny with a reason | `case_006921` | `Rejected` → `Investigating` (version 6) via `Reassess`; toast "Denied. A new investigation runs with your reason as evidence." |
| Second investigation (real path) | `case_006921` | `operator.denial_reason` Evidence by `operator:Henry`; new Proposal `REQUEST_REVIEW`; Case `ReviewRequired` |

## Defects found and fixed during the rehearsal (branch `007-approval-and-outbox`)

1. **The investigation after a denial never started.** Processing `Reassess` queued `Investigate`,
   but nothing delivered it (the sweeper is not scheduled yet). `CommandBus.Deliver` now delivers
   the request its own processing queued (AD-20: the transition owner dispatches after commit);
   `TestCommandBus.TestReassessAfterDenials` asserts it.
2. **The sweeper ran real investigations in tests.** With (1), the sweeper's default bus ran the
   chained investigation of a test Case. `Tasks.Sweeper.Run` takes `investigations`; tests pass
   `"none"`. One real model call was made by the failing run before the fix.
3. **A denial was marked `superseded`** when a new Proposal arrived. Only approvals are superseded
   now, as the data model says.

Full suite 174/174 and the live contract check conform after the fixes.

## Left for the gate

- **002**: set `SN_SIM_BASE_URL` and serve the Simulator's read endpoints; the real path then has
  partner health, history, origin status and receipts.
- **004**: load policies and the mapping catalog (`LocalSource`, `Dispatch.Mappings`); replace the
  default `ApprovalPolicy`.
- **Gate wiring**: `Tasks.SweeperTask.Ensure()` in `Bootstrap` on a clean database (the dev database
  holds thousands of test requests); `Execute` handler (008).
- **Test hygiene**: `TestOrderShape.ValidOrder` carries an embedded instruction in `notes` by
  design; a demo Order must not be built from it.
