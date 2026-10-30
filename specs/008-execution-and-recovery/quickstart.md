# Quickstart: Safe Execution and Recovery

## Prerequisites

- Container `signalnoir-iris` (AI Hub build 154) up, the repo mounted at `/home/irisowner/dev`.
- The Simulator served at `/sim/api/v1` (`##class(SignalNoir.Sim.Setup).EnsureWebApplication()`).

## Run

1. Compile `src` and `tests` with iris-agentic-dev (twice, for the compile order).
2. Run the unit suites:
   - `SignalNoir/Tests/Core`, for `TestResponseClass`, `TestEffectKey` and `TestExecutionPolicy`;
   - `SignalNoir/Tests/Application`.
3. Run the live recovery suite, `SignalNoir/Tests/Recovery`. It sets
   a client timeout of 3 s (`Tests.Sim.ClientTimeout.Set(3)`) and creates instances with
   `timeScale = 0.01`.
4. Run the live contract check: `python3 tests/contract/validate_live.py`.

## Expected

- **Approved resend on a `clean` instance**: `Resolved`, one Receipt copy (`delivery`), and the
  Partner holds 1 Receipt for the Order.
- **`P3` degrade, maintenance or cancel event after approval**: `Held`, `Held` or `Cancelled`;
  0 attempts; the Partner holds 0 Receipts.
- **`idempotency.lost_receipt`**: attempt 1 uncertain, then a reconciliation finds the Receipt;
  `Resolved` with source `reconciliation`; 1 Receipt.
- **`idempotency.restart_during_executing`**: the lease expires, the sweeper asks for
  reconciliation, the generation becomes 2, and the Case ends `Resolved`; 1 Receipt.
- **Repeated click and repeated `Execute`**: 1 approval, 1 execution, 1 Receipt.
- **Recovery suite**: 0 duplicate Receipts.
