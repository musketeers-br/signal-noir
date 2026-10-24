# Phase 0 Research: Scenario Simulator

**Date**: 2026-10-23
**Inputs**: [spec.md](./spec.md), `contracts/openapi-sim.yaml` (frozen), `docs/seams.md` v1,
architecture AD-13, AD-14, AD-16, AD-21, AD-22, AD-25, AD-26, and the 001 research
(`specs/001-runtime-skeleton-and-seams/research.md`).

Platform facts already verified live by 001 through iris-agentic-dev are reused and cited as
"001-Vn". New platform claims this plan relies on are listed in **Verification backlog** and MUST
be checked through iris-agentic-dev, with throwaway probes, before `/speckit-implement` starts
(iris-agentic-dev was not reachable from the planning session).

---

## D1 — Where the Simulator runs

- **Decision**: `SignalNoir.Sim` is a package of the same IPM module, served in the same IRIS
  container and namespace (`IRISAPP`) by its own `%CSP.REST` web application at `/sim/api/v1`.
  Its persistent state lives in its own globals (`^SignalNoir.Sim.*`), separate from the product.
- **Rationale**: AD-13 and the architecture network note put the Simulator in the same container
  but reachable only over HTTP. The module resource `SignalNoir.PKG` already includes the
  sub-package, so `module.xml` does not change. A separate web application gives the HTTP
  boundary the contract describes (`servers: /sim/api/v1`).
- **Alternatives considered**: a separate container (adds a service to the runtime path that 012
  forbids: one `iris` service); a separate namespace (more bootstrap, no benefit for an external
  system that already talks only HTTP); a separate IPM module (more packaging for no new
  guarantee; the isolation is enforced by a test instead, see D10).
- **Relies on**: 001-V10 (`%CSP.REST` present), 001-V11 (`Security.Applications` create).

## D2 — Registering `/sim/api/v1`

- **Decision**: `SignalNoir.Sim.Setup.EnsureWebApplication()` registers the web application
  idempotently (delete-then-create, as `SignalNoir.Interop.Bootstrap.EnsureWebApplications` does
  for the product API). Tests call it directly. The one-line call from the product bootstrap is an
  **integration change applied at gate G1**, not edited in this feature's branch.
- **Rationale**: `Bootstrap.cls` belongs to 001's write zone; the parallelism rules forbid editing
  integration points outside the gate. The Simulator owning its own setup keeps it self-contained.
- **Alternatives considered**: a `<CSPApplication>` in `module.xml` (integration file, same gate
  rule, and the product API does not use that path today).

## D3 — Determinism without a seedable RNG

- **Decision**: All variability is derived in counter mode from a hash:
  `draw(seed, variant, stream, n) = first 8 bytes of SHA-256(seed | variant | stream | n)` as an
  unsigned integer. Streams are named (`order`, `wording`, `latency`, `patient`). No call to
  `$RANDOM`, no dependence on wall-clock time for content.
- **Rationale**: `$RANDOM` cannot be seeded. A stateless hash gives the same value for the same
  inputs on every run and every instance, which is what FR-006 needs, and lets any value be
  recomputed in a test without replaying the whole sequence.
- **Alternatives considered**: a hand-written LCG with stored state (state must be persisted per
  instance and replayed in order); precomputed tables per seed (does not scale to arbitrary seeds).
- **Verification backlog**: V1 (`$SYSTEM.Encryption.SHAHash(256, …)` on build 154).

## D4 — Identifiers

- **Decision**:
  - `scenarioInstanceId = "sci_" _ <22 chars base32 of a GUID>`; never derived from the seed.
  - `orderId = "ORD-" _ scenarioInstanceId _ "-" _ <4-digit ordinal>`; the ordinal is the position
    in the variant's emission script.
  - `transactionId = "txn_" _ <instance suffix> _ "_" _ <ordinal>` for Origin emissions; delivery
    transaction ids are the caller's.
  - `receiptId = "rcp_" _ <instance suffix> _ "_" _ <per-instance counter>`.
- **Rationale**: Resolves the spec assumption "same sequence, never the same orderId": the ordinal
  and content repeat for a seed, the namespace never does. A GUID survives `docker compose down`
  (which wipes data and would reset a counter), so ids never repeat across runs (FR-007, SC-002).
  Matches the contract examples (`ORD-sci_01HZX-0001`, `rcp_`) and SIM-Q6.
- **Alternatives considered**: a global counter (repeats after a reset); hash of seed + time
  (collisions in fast loops, and leaks timing into content).
- **Verification backlog**: V2 (`$SYSTEM.Util.CreateGUID()` on build 154).

## D5 — Atomic deduplication

- **Decision**: A delivery takes an exclusive lock on `^SignalNoir.Sim.Key(idempotencyKey)` for
  the whole decide-and-record step. Inside the lock: if a Receipt exists for the key, compare the
  stored canonical payload with the incoming one; equal → return the original Receipt with
  `Idempotent-Replayed: true`; different → 422 `IDEMPOTENCY_KEY_REUSED`. If no Receipt exists,
  apply the script and, when the script records a Receipt, persist it (with a unique index on
  `idempotencyKey`) before releasing the lock. Scripted delays happen **after** the lock is
  released and after the Receipt is committed.
- **Payload canonical form**: the `order` object serialized with keys sorted recursively, arrays in
  their original order; `transactionId` and `mappingRef` are excluded (FR-017).
- **Key scope**: global. The Core derives the key from `orderId` (AD-21), and `orderId` is globally
  unique (D4), so a global scope never conflates instances.
- **Rationale**: Principle VI requires the Partner side to deduplicate atomically; the lock
  serializes concurrent identical deliveries (SC-004), and the unique index is a second guard if a
  lock is ever lost. Releasing the lock before the delay keeps a lost-response delivery from
  blocking a later reconciliation read.
- **Alternatives considered**: unique index only (two racers both run the script before one fails
  the insert, so a script with side effects on history would double-log); optimistic retry (more
  complex, same result).
- **Verification backlog**: V3 (lock + unique index behaviour under two concurrent CSP requests).

## D6 — Holding a response (timeouts and lost responses)

- **Decision**: A scripted delay is `max(clientTimeout + margin, nominalDelay × timeScale)`, with
  `clientTimeout` read from `SN_PARTNER_TIMEOUT_SECONDS` (default 60, the same variable and default
  as `SignalNoir.Interop.Bootstrap.PARTNERTIMEOUTSECONDS`) and `margin = 5 s`. The request process
  `Hang`s for the delay, then writes the scripted body if the connection is still open. For
  `timeout` the script records no Receipt; for `lost_receipt` the Receipt is committed before the
  hang (D5).
- **Rationale**: The caller must always observe the uncertain outcome the script declares (FR-020),
  even under a reduced time scale (SIM-Q5). Reading the same environment variable keeps the
  Simulator and the Execution BO consistent without the Simulator referencing product code.
- **Risk**: the web gateway in front of `52773` has its own server response timeout. If it is
  shorter than `clientTimeout + margin`, the caller sees a gateway 5xx instead of a timeout. Both
  are `uncertain`, but history would then claim `timeout` for what the client saw as 5xx.
- **Verification backlog**: V4 (gateway response timeout on build 154 and whether `Hang` in a
  `%CSP.REST` method past it yields a timeout at the client). If the gateway is shorter, the
  setup sets the `/sim/api/v1` application's timeout above `clientTimeout + margin`, or the plan
  records a contract-change note.
- **Alternatives considered**: closing the socket without a response (cannot be done portably from
  `%CSP.REST`); asking the client to use a shorter timeout for the Simulator (couples the product
  to the Simulator).

## D7 — Catalog and scripts as versioned fixtures

- **Decision**: Each family is a class `SignalNoir.Sim.Catalog.<Family>` holding its variants as
  JSON in `XData`, with a `CATALOGVERSION` parameter. A loader reads them into memory on demand;
  nothing is loaded from the file system at runtime. The script format is defined in
  [contracts/scenario-script.md](./contracts/scenario-script.md).
- **Rationale**: The scripts compile with the module, so the image needs no extra copy step
  (Dockerfile is an integration file) and every change is versioned in git. AD-26 asks for
  versioned reference data; XData is the IRIS idiom for that.
- **Alternatives considered**: JSON files under `fixtures/scenarios/` (needs a Dockerfile or
  `module.xml` change and a runtime path); globals seeded by a loader (state, not code; harder to
  review).

## D8 — What the catalog serves, and the answer key

- **Decision**: `GET /scenario-catalog` serves `family`, `subtype`, `variant`, `set`, `partnerId`,
  `language`, `description` and `script` = the **public** part of the script only: the attempt
  sequence as response classes the Partner emits (`status`, wording key, delay class) and the
  trigger list. The Partner's private acceptance rule (for example "accepts `GLI-02` only when
  `specimen.type = plasma`", used by P8b and the clean unknown-code variant) is held in a
  `partnerRule` section that is **never serialized** by any endpoint. The answer key (expected
  Action, parameters, final state, classification) does not exist in the Simulator at all; it is
  Benchmark data (spec 010).
- **Rationale**: The acceptance rule implies the correct Mapping parameter, which is answer-key
  content (FR-030). Keeping it private, plus a leak test that scans every response for the private
  values, makes SC-006 checkable.
- **Alternatives considered**: no `script` at all in the catalog (the contract says the catalog
  declares the response sequence; the Bench and tests need it); serving the whole script (leaks).

## D9 — Tuning and reserved test variants

- **Decision**: Tuning variants live in the catalog classes from the start. Reserved `test`
  variants (≥ 5 each for P5 and P8b, FR-032) are written by the holder of the reserved cases
  (Henrique, Principle VIII) in a separate class per family, `SignalNoir.Sim.Catalog.<Family>Test`,
  and are committed only at the freeze that precedes the reserved run. Until then the test classes
  contain only the shape (one placeholder variant used by contract tests).
- **Rationale**: The repository is public and the Agent author must not tune on the reserved set.
  Separate classes make the freeze a single, reviewable commit.
- **Alternatives considered**: keeping test variants outside git (not reproducible, violates the
  publish-raw-data rule after the run).

## D10 — Enforcing "reached only over HTTP"

- **Decision**: A `%UnitTest` queries `%Dictionary.CompiledClass` and fails if any class outside
  `SignalNoir.Sim.*` and `SignalNoir.Tests.Sim.*` references `SignalNoir.Sim` (superclass, property
  type, method signature or code text). `SignalNoir.Sim` itself references no product package.
- **Rationale**: Principle I makes this a rule; a test makes it a gate instead of a convention.
- **Alternatives considered**: a separate IPM module (heavier, still needs a test for code text).

## D11 — HTTP surface and errors

- **Decision**: `SignalNoir.Sim.Api.Dispatch` (`%CSP.REST`) maps the 12 operations of the contract
  one to one. Interface errors use the contract envelope with `INVALID_REQUEST`, `NOT_FOUND`,
  `IDEMPOTENCY_KEY_REUSED`. Partner delivery bodies are written exactly as the script declares,
  including no body, `text/plain`, and PT/EN text with embedded instructions. Simulator-generated
  times are UTC with `Z`, formatted as `SignalNoir.Application.SystemClock` does (re-implemented
  locally, not referenced). The Simulator's internal operations return
  `SignalNoir.Sim.Result` values; only the HTTP edge turns them into status codes (Principle VII).
- **Rationale**: Contract-first (AD-16). The Simulator keeps its own result type so it does not
  depend on `SignalNoir.Core.Result` (D10).

## D12 — World-change events and scripted triggers (SIM-Q3)

- **Decision**: An instance has a `phase` and an append-only list of applied events. Events come
  from `POST /scenarios/{id}/events` or from a script trigger. Supported trigger conditions:
  `onRead` of `health`, `history` or `originStatus` with an `nth` count, and `onAttempt` with an
  attempt number. The default P3 trigger is **the 2nd read of `/health` or of
  `/origin/orders/{orderId}` for the instance** — the first read is the Investigation's evidence,
  the second is Revalidation.
- **Rationale**: In Benchmark Mode the Bench cannot call the event endpoint between Approval and
  Revalidation (SIM-Q3); a read-count trigger fires at Revalidation without the Simulator knowing
  about Approval.
- **Open dependency**: the "2nd read" convention depends on how many evidence reads the product
  does before Approval (specs 006, 008). It is a per-variant value in the script, so a change does
  not touch code. **To be confirmed with Henry (006) and José (008) at G1.**

## D13 — Contract tests

- **Decision**: A `%UnitTest` suite `SignalNoir.Tests.Sim.Contract` calls every operation over
  HTTP (`%Net.HttpRequest` to `localhost:52773/sim/api/v1`), asserts the behavior, and writes each
  JSON response to `tests/sim-contract/captures/` with a manifest entry naming the contract schema.
  `tests/sim-contract/validate_sim_captures.py` validates the captures against
  `contracts/openapi-sim.yaml` as JSON Schema 2020-12, mirroring
  `contracts/tools/validate_fixtures.py`.
- **Rationale**: ObjectScript has no JSON Schema validator; the team already validates fixtures
  with Python `jsonschema` through `uv`. Captures also become the Simulator fixture set the spec
  assumes (other features can develop their Tools against them).
- **Alternatives considered**: Embedded Python with `jsonschema` inside IRIS (adds a runtime
  package to the image); hand-written field checks only (misses schema drift).

## D14 — Concurrency and isolation of instances

- **Decision**: Every persistent record carries `scenarioInstanceId` and every read filters by it;
  the feed is the only cross-instance list, as the contract states, and its items carry the
  instance. `feedSeq` is a `$INCREMENT` on one global. Per-instance counters (`attempt`, `read
  counts`, `receipt` ordinal) are `$INCREMENT`s under `^SignalNoir.Sim.Instance(id, …)`.
- **Rationale**: FR-005 and FR-008; `$INCREMENT` is atomic without a lock.

---

## Resolution of the contract's open questions

| Id | Resolution in this plan |
|----|-------------------------|
| SIM-Q1 | Pull feed `GET /origin/feed?afterSeq=` (D11). Confirmed by contract; 003 consumes it. |
| SIM-Q2 | Partner announces maintenance in `/health` and via `MAINTENANCE_STARTS`; policy is product data. |
| SIM-Q3 | Read-count triggers per variant (D12); explicit endpoint for demo/manual. |
| SIM-Q4 | Simulator rejects with 422 and no effect; classification is the Core's (008). |
| SIM-Q5 | `max(clientTimeout + 5 s, nominal × timeScale)`, `clientTimeout` from `SN_PARTNER_TIMEOUT_SECONDS` (D6). |
| SIM-Q6 | Prefixes per D4. |
| SIM-Q7 | Patient searches require `scenarioInstanceId`. |
| SIM-Q8 | P9 emission seeds the original Receipt at `emission − 3 min` and the original in Origin history. |

None of these resolutions changes `contracts/openapi-sim.yaml`; all fit inside it.

## Verification backlog (iris-agentic-dev, before dependent tasks)

| # | Claim | Needed by |
|---|-------|-----------|
| V1 | `$SYSTEM.Encryption.SHAHash(256, s)` available and stable on build 154 | D3 |
| V2 | `$SYSTEM.Util.CreateGUID()` available on build 154 | D4 |
| V3 | Exclusive `Lock` + unique index serialize two concurrent `%CSP.REST` requests for the same key | D5 |
| V4 | Web gateway server response timeout on `52773`; a `Hang` past `SN_PARTNER_TIMEOUT_SECONDS + 5` is seen by `%Net.HttpRequest` / `EnsLib.HTTP.OutboundAdapter` as a timeout, not a 5xx | D6 |
| V5 | `Security.Applications.Create("/sim/api/v1", …)` coexists with `/signalnoir/api/v1` | D2 |
| V6 | `%Net.HttpRequest` from a `%UnitTest` to `localhost:52773` reaches the web application inside the container | D13 |

Each result is recorded in this file under "Verification log" when run.

## Verification log

_Empty — to be filled with throwaway probes through iris-agentic-dev before `/speckit-implement`
(probes are verification, not submission code, and are deleted after the check)._
