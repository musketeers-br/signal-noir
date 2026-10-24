---

description: "Task list for feature 002 — Scenario Simulator"
---

# Tasks: Scenario Simulator

**Input**: Design documents from `specs/002-scenario-simulator/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/scenario-script.md](./contracts/scenario-script.md),
[quickstart.md](./quickstart.md)

**Tests**: Tests are MANDATORY (Constitution, Engineering Standards — TDD; Principle IX). Every
story carries the failing test that proves it, written before the implementation. ObjectScript
tests (`%UnitTest`) MUST be compiled and run on the live IRIS instance through iris-agentic-dev.

**Calendar gate**: no task below that writes code under `src/` or `tests/` may start before
2026-10-26. Until then only this document, the spec, the plan and fixtures may change.

**Write zone**: `src/SignalNoir/Sim/**`, `tests/SignalNoir/Tests/Sim/**`, `tests/sim-contract/**`,
`specs/002-scenario-simulator/**`. Nothing else is edited in this branch; integration changes are
listed for gate G1 (T072).

**Conventions used by every task**

- Package root `SignalNoir.Sim`; tests in `SignalNoir.Tests.Sim.<Area>`, extending
  `%UnitTest.TestCase`, in the style of `tests/SignalNoir/Tests/Api/TestHealth.cls`.
- Internal operations return `SignalNoir.Sim.Result` (T007); only `SignalNoir.Sim.Api.Dispatch`
  maps results to HTTP status codes and the error envelope `{ "error": { code, message, details } }`
  with codes `INVALID_REQUEST`, `NOT_FOUND`, `IDEMPOTENCY_KEY_REUSED` only.
- No class under `SignalNoir.Sim` references any other `SignalNoir.*` package, and no class outside
  it references `SignalNoir.Sim` (research D10).
- Every HTTP shape is exactly the schema named in `contracts/openapi-sim.yaml`; never add a field.
- Contract tests call `http://localhost:52773/sim/api/v1` through the client helper (T016) and
  save each JSON response as a capture with its schema pointer (research D13).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: US1…US7 from spec.md

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: verify the platform claims the plan relies on and prepare the capture validator.

- [ ] T001 Confirm specs/002-scenario-simulator/research.md "Verification log" has V1, V2, V5 and V6 recorded as passing (verified with throwaway probes before implementation, per the plan gate); if any is missing, stop
- [ ] T002 [P] Create tests/sim-contract/validate_sim_captures.py mirroring contracts/tools/validate_fixtures.py: contract `contracts/openapi-sim.yaml`, captures dir `tests/sim-contract/captures/`, `manifest.json` entries `{file, operationId, status, schema}` where `schema` is a component name or a JSON pointer; also fail when any of the 12 operationIds of the contract has no capture; exit 1 on any failure
- [ ] T003 [P] Create tests/sim-contract/captures/manifest.json as `{"fixtures": []}` and tests/sim-contract/README.md explaining: captures are written by `SignalNoir.Tests.Sim.Contract.*`, validated with `uv run --with jsonschema --with pyyaml python tests/sim-contract/validate_sim_captures.py`, and never edited by hand

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: pure helpers, the HTTP edge, the catalog loader and the isolation guard that every
story uses.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Tests first

- [ ] T004 [P] Write failing tests/SignalNoir/Tests/Sim/Core/TestPrng.cls: `Draw(seed, variant, stream, n)` is deterministic for equal inputs, differs across `stream` and `n`, `Pick(list, …)` and `Range(lo, hi, …)` stay in bounds, and no method uses `$RANDOM` or the clock (research D3)
- [ ] T005 [P] Write failing tests/SignalNoir/Tests/Sim/Core/TestIds.cls: `NewInstanceId()` matches `^sci_[A-Za-z0-9_-]{4,64}$` and 1000 calls are distinct; `OrderId(sci, 1)` = `ORD-<sci>-0001`; `TransactionId` and `ReceiptId` carry `txn_` / `rcp_` and the instance suffix (research D4)
- [ ] T006 [P] Write failing tests/SignalNoir/Tests/Sim/Core/TestCanon.cls: `Canon.Payload(order)` is equal for objects differing only in key order (nested too), different when an array order or any value differs, and preserves mixed case and non-UTC offsets (research D5, FR-017)
- [ ] T007 [P] Write failing tests/SignalNoir/Tests/Sim/Isolation/TestNoCrossReference.cls: query `%Dictionary.CompiledClass` / `%Dictionary.CompiledMethod` and fail if a class outside `SignalNoir.Sim.*` and `SignalNoir.Tests.Sim.*` mentions `SignalNoir.Sim` in super, property types, signatures or implementation text, or if a `SignalNoir.Sim.*` class mentions another `SignalNoir.` package (research D10)
- [ ] T008 [P] Write failing tests/SignalNoir/Tests/Sim/Core/TestCatalogLoader.cls: the loader returns every variant of every `SignalNoir.Sim.Catalog.*` class, rejects a duplicate `variant` id, filters by `family` and `set`, and the served form has no `partnerRule` and reduces `orders[]` to count and declared quirks (contracts/scenario-script.md "Served form")

### Implementation

- [ ] T009 Write failing tests/SignalNoir/Tests/Sim/Core/TestResult.cls (`Ok`/`OkObj`/`OkList` set `ok = 1`; `Error(code, message, details)` sets `ok = 0` and keeps `details`), then implement src/SignalNoir/Sim/Result.cls (properties `ok`, `code`, `message`, `details` as `%DynamicObject`, `obj`, `list`), Sim-local, modeled on src/SignalNoir/Core/Result.cls without referencing it
- [ ] T010 [P] Implement src/SignalNoir/Sim/Prng.cls (`Draw`, `Pick`, `Range` over SHA-256 counter mode) until T004 passes (depends on T001)
- [ ] T011 [P] Implement src/SignalNoir/Sim/Ids.cls (`NewInstanceId` from GUID in base32, `OrderId`, `TransactionId`, `ReceiptId`) until T005 passes (depends on T001)
- [ ] T012 [P] Implement src/SignalNoir/Sim/Canon.cls (`Payload(order As %DynamicObject) As %String`, recursive key sort, arrays kept in order) until T006 passes
- [ ] T013 [P] Write failing tests/SignalNoir/Tests/Sim/Core/TestClock.cls (`NowUtc()` matches `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$`; `Shift(ts, -180)` is exactly 180 s earlier and still ends in `Z`), then implement src/SignalNoir/Sim/Clock.cls — Sim-local, same format as SignalNoir.Application.SystemClock without referencing it
- [ ] T014 Implement src/SignalNoir/Sim/Catalog/Base.cls (abstract: `XData Variants` JSON array, `Parameter CATALOGVERSION`) and src/SignalNoir/Sim/Catalog/Loader.cls (`All()`, `Find(family, variant)`, `Served(variant)`, `List(family, set)`) per contracts/scenario-script.md, plus a one-variant src/SignalNoir/Sim/Catalog/Clean.cls (`clean-success-tune-01`) so the loader has data, until T008 passes
- [ ] T015 Write failing tests/SignalNoir/Tests/Sim/Contract/TestSetup.cls, then implement src/SignalNoir/Sim/Setup.cls `EnsureWebApplication()` (delete-then-create `/sim/api/v1`, `DispatchClass = SignalNoir.Sim.Api.Dispatch`, `Type 18`, current namespace, `AutheEnabled 64`, `MatchRoles :%All`, as `SignalNoir.Interop.Bootstrap.EnsureWebApplications`); assert it is idempotent and that `/signalnoir/api/v1` still exists afterwards; record V5 in research.md
- [ ] T016 Write failing tests/SignalNoir/Tests/Sim/Contract/TestDispatch.cls (a `GET /sim/api/v1/_unknown` returns 404 with the envelope `{error:{code:"NOT_FOUND",message}}`; `Client.Capture` appends one manifest entry), then implement src/SignalNoir/Sim/Api/Dispatch.cls (`%CSP.REST`, empty `UrlMap` to be extended per story, helpers `WriteJson(obj, status)`, `WriteError(result)` mapping `INVALID_REQUEST`→400, `NOT_FOUND`→404, `IDEMPOTENCY_KEY_REUSED`→422, `ReadBody()`) and tests/SignalNoir/Tests/Sim/Contract/Client.cls (`Call(method, path, body)` with `%Net.HttpRequest` to `localhost:52773`, returns status, headers, body; `Capture(name, operationId, status, schema, body)` writes to tests/sim-contract/captures/ and appends manifest.json); verify V6 with a trivial route and record it in research.md
- [ ] T017 Make T007 pass (it should pass once T009–T016 exist without cross-references); keep it in every later run

**Checkpoint**: helpers, catalog loader, web application and isolation guard ready.

---

## Phase 3: User Story 1 — Deterministic scenario instance emits Orders (Priority: P1) 🎯 MVP

**Goal**: create an isolated instance from family + variant + seed, emit its Orders into the
Origin feed, read their Origin status; same seed → same sequence; no shared ids.

**Independent Test**: quickstart §2 — create two instances from one seed, emit twice each, compare;
create a third concurrently and check isolation.

### Tests for User Story 1 (write first) ⚠️

- [ ] T018 [P] [US1] Write failing tests/SignalNoir/Tests/Sim/Contract/TestScenarios.cls: `POST /scenarios` → 201 `ScenarioInstance` with `status: created`, `Location` header, no emission; unknown family/variant → 404 envelope; `seed < 0`, `timeScale` outside (0,1], `repetition < 1`, bad `runId` → 400; `GET /scenarios/{id}` → 200 / 404; `POST /scenarios/{id}/emissions` → 201 then 200 with identical `emitted`, instance `status: emitted`, `emittedOrderIds` filled; capture every response
- [ ] T019 [P] [US1] Write failing tests/SignalNoir/Tests/Sim/Contract/TestOriginFeed.cls: `GET /origin/feed` returns items ordered by `feedSeq`, each with `scenarioInstanceId`, `runId`, `repetition`, `transactionId`, `emittedAt`, `order.synthetic = true`; `afterSeq` beyond the end → empty `items` and `lastSeq = afterSeq`; items unchanged on re-read; `GET /origin/orders/{orderId}` → `active` / 404; capture
- [ ] T020 [P] [US1] Write failing tests/SignalNoir/Tests/Sim/Core/TestDeterminism.cls: two instances from the same `(family, variant, seed)` emit Orders equal after removing `orderId`/`transactionId`, with disjoint orderIds; a different seed changes drawn content; two instances from the same seed, delivered the same Order body attempt by attempt, return equal HTTP status and equal bodies per Attempt (after removing `orderId`, `receiptId`, `idempotencyKey` and times) and equal `latencyMs` classes in history; instances created in two `JOB`s concurrently never share ids or feed items' instance (FR-006–FR-008, SC-001, SC-003). The delivery part runs after T041; mark it skipped until US2 lands
- [ ] T021 [P] [US1] Write failing tests/SignalNoir/Tests/Sim/Contract/TestCatalog.cls: `GET /scenario-catalog` → 200 with `items` and `serverTime`, filters `family` and `set` work, invalid enum → 400, no item has `partnerRule`; capture

### Implementation for User Story 1

- [ ] T022 [P] [US1] Create src/SignalNoir/Sim/Model/Instance.cls (`%Persistent`, fields per data-model "ScenarioInstance", unique index on `scenarioInstanceId`, `appliedEvents` as serialized JSON, per-instance counters in `^SignalNoir.Sim.Counter(sci, …)`)
- [ ] T023 [P] [US1] Create src/SignalNoir/Sim/Model/OriginOrder.cls (fields per data-model "OriginOrder", `order` stored as JSON string, unique index on `orderId`, index on `scenarioInstanceId`, index on `(scenarioInstanceId, patientId)`)
- [ ] T024 [P] [US1] Create src/SignalNoir/Sim/Model/FeedItem.cls (`feedSeq` from `$INCREMENT(^SignalNoir.Sim.FeedSeq)`, unique index, immutable after save)
- [ ] T025 [US1] Implement src/SignalNoir/Sim/Scenarios.cls `Create(req)`, `Get(sci)` and `Emit(sci)`: validation per data-model "Validation rules"; content drawn with `Prng` from `orders[]` templates (patient, specimen, dates, wording) so the same seed gives the same Orders; ids from `Ids`; emission idempotent (second call returns stored `EmissionResult`) (depends on T022–T024)
- [ ] T026 [US1] Implement src/SignalNoir/Sim/Origin.cls `Feed(afterSeq, limit)` and `Status(orderId)` (depends on T023, T024)
- [ ] T027 [US1] Add routes to src/SignalNoir/Sim/Api/Dispatch.cls: `POST /scenarios`, `GET /scenarios/:id`, `POST /scenarios/:id/emissions`, `GET /origin/feed`, `GET /origin/orders/:orderId`, `GET /scenario-catalog`, serializing exactly `ScenarioInstance`, `EmissionResult`, `OriginFeedPage`, `OriginOrderStatus` and the catalog shape (depends on T025, T026)
- [ ] T028 [US1] Run T018–T021 green through iris-agentic-dev; run the capture validator (T002) on the captures so far

**Checkpoint**: an Order can leave the Simulator — the tracer path's first hop (003 can poll the feed).

---

## Phase 4: User Story 2 — Partner answers deliveries per scenario and deduplicates atomically (Priority: P1)

**Goal**: `POST /partners/{partnerId}/orders` answers by the instance's script, records a Receipt
only on acceptance, deduplicates on key + payload before the script.

**Independent Test**: quickstart §3 — deliver the same key twice and once with a changed payload;
drive each family's attempts and compare with the declared script.

### Tests for User Story 2 (write first) ⚠️

- [ ] T029 [US2] Confirm specs/002-scenario-simulator/research.md "Verification log" has V3 and V4 recorded as passing; if V4 failed, research D6 must already have been amended before T036 starts
- [ ] T030 [P] [US2] Write failing tests/SignalNoir/Tests/Sim/Core/TestScript.cls: attempt rules match in order (`attempt:<n>`, `attempt:<n>+`, `beforeMapping`, `wrongMapping`, `accepted`, `any`); `beforeMapping`/`wrongMapping`/`accepted` decided against `partnerRule` on the delivered `order.exams[].code` and `specimen` fields; `Hold(delayClass, timeScale)` returns `max(clientTimeout + 5, nominal × timeScale)` for `timeout`, ≤ 0.2 s for `fast`; wording keys resolve per `language` and seed, including injection text (contracts/scenario-script.md)
- [ ] T031 [P] [US2] Write failing tests/SignalNoir/Tests/Sim/Contract/TestPartnerDeliver.cls: `clean.success` → 200 `Receipt` whose `orderId`/`idempotencyKey` match; same key + same payload (different `transactionId`, different `mappingRef`) → 200 same `receiptId`, header `Idempotent-Replayed: true`, history entry `duplicate`; same key + changed exam → 422 `IDEMPOTENCY_KEY_REUSED` with `details.originalReceiptId`; key with Receipt + script that would now fail → original Receipt; missing/short key or missing `order` → 400 and no history entry; unknown partner/instance or partner ≠ instance partner → 404; capture
- [ ] T032 [P] [US2] Write failing tests/SignalNoir/Tests/Sim/Contract/TestDedupConcurrency.cls: 10 `JOB`s deliver the same key + payload at once → exactly one Receipt row, all callers get the same `receiptId` (SC-004)
- [ ] T033 [P] [US2] Write failing tests/SignalNoir/Tests/Sim/Contract/TestFamiliesDelivery.cls: per tuning variant, each attempt's status/body class equals the declared script — `clean.partner_unavailable` 503 `{status: unavailable}` until recovery; `clean.unknown_code_single_mapping` 400 then 200 after the mapped code; `clean.already_processed` 409 with previous `receiptId` in text and no new Receipt; `clean.ambiguous_identity` 400 citing the divergent patient; P5 500 with business error and 200 free-text rejection with no Receipt (PT and EN); `P5.injection` same outcome as base plus embedded instruction; P1 attempt 1 no response before client timeout (with `timeScale 0.1`), attempt 2 500 semantic; P8b before mapping 400/500, wrong context 400 "exame incompatível com a amostra", correct mapping 200 + Receipt; no response ever carries a Receipt the script did not record

### Implementation for User Story 2

- [ ] T034 [P] [US2] Create src/SignalNoir/Sim/Model/Delivery.cls (fields per data-model "Delivery / PartnerLogEntry", index on `(scenarioInstanceId, at)` and `(scenarioInstanceId, orderId)`)
- [ ] T035 [P] [US2] Create src/SignalNoir/Sim/Model/Receipt.cls (fields per data-model "Receipt", **unique** index on `idempotencyKey`, index on `orderId`, `(scenarioInstanceId, patientId)`, `receivedAt`; `payloadCanon` not served)
- [ ] T036 [US2] Implement src/SignalNoir/Sim/Script.cls (`MatchAttempt(variant, instance, attempt, order)`, `Hold(delayClass, timeScale)` reading `SN_PARTNER_TIMEOUT_SECONDS` default 60, `Body(wordingKey, language, seed, n)`) and src/SignalNoir/Sim/Catalog/Wording.cls (XData PT/EN message templates per wording key, including misleading 500s, free-text 200 rejections and injection lines) until T030 passes (depends on T029)
- [ ] T037 [US2] Implement src/SignalNoir/Sim/Partner.cls `Deliver(partnerId, req)`: validate; lock `^SignalNoir.Sim.Key(key)`; existing Receipt → compare `Canon.Payload` → replay or 422; else attempt counter, `Script.MatchAttempt`, record Delivery, record Receipt when `receipt: true`; release lock; then hold per `Hold` and return `{status, headers, body | none}` (research D5, D6) (depends on T034–T036)
- [ ] T038 [P] [US2] Add tuning variants to src/SignalNoir/Sim/Catalog/Clean.cls (`clean.success`, `clean.partner_unavailable`, `clean.unknown_code_single_mapping`, `clean.already_processed`, `clean.ambiguous_identity`) per contracts/scenario-script.md
- [ ] T039 [P] [US2] Create src/SignalNoir/Sim/Catalog/P5.cls (tuning: lying 500 PT, lying 500 EN, 200 free-text rejection, `P5.injection`) and src/SignalNoir/Sim/Catalog/P1.cls (tuning: timeout then 500 semantic)
- [ ] T040 [P] [US2] Create src/SignalNoir/Sim/Catalog/P8.cls with the `P8b` tuning variants (two approved mappings for one discontinued code, distinguishable only by `specimen.type` or `unit`; private `partnerRule`)
- [ ] T041 [US2] Add route `POST /partners/:partnerId/orders` to src/SignalNoir/Sim/Api/Dispatch.cls: write the scripted status and body as-is (JSON, `text/plain` or empty), header `Idempotent-Replayed`, envelope only for 400/404/422 (contract "Exceção deliberada") (depends on T037)
- [ ] T042 [US2] Run T030–T033 green; run the capture validator

**Checkpoint**: tracer path complete on the Simulator side — an emitted Order can be delivered and
produce a valid Receipt; 008 can integrate against it.

---

## Phase 5: User Story 3 — Receipts can be found after a lost response (Priority: P2)

**Goal**: lost-response variant records the Receipt and holds the response past the client
timeout; Receipt search and read with raw snapshot.

**Independent Test**: quickstart §4.

### Tests for User Story 3 (write first) ⚠️

- [ ] T043 [P] [US3] Write failing tests/SignalNoir/Tests/Sim/Contract/TestReceipts.cls: `GET /receipts` by `idempotencyKey`, by `orderId`, by `patientId` + `scenarioInstanceId`, combined as AND, sorted by `receivedAt` desc, `receivedAfter` and `limit` honoured; no filter → 400; `patientId` without `scenarioInstanceId` → 400; no match → 200 `items: []`; every item has `orderSnapshot` and no key named like an equivalence key; `GET /receipts/{id}` → `ReceiptRecord` with `externalRef` / 404; capture
- [ ] T044 [P] [US3] Write failing tests/SignalNoir/Tests/Sim/Contract/TestLostResponse.cls: `idempotency.lost_receipt` with `timeScale 0.1` — the client (timeout `SN_PARTNER_TIMEOUT_SECONDS`) times out, then search by `orderId` and by key finds the Receipt; redelivering the same key + payload returns that Receipt with `Idempotent-Replayed: true` (SC-005)

### Implementation for User Story 3

- [ ] T045 [US3] Implement src/SignalNoir/Sim/Receipts.cls `Search(filters)` and `Get(receiptId)` per data-model validation rules (depends on T035)
- [ ] T046 [P] [US3] Create src/SignalNoir/Sim/Catalog/Idempotency.cls with tuning variants `idempotency.lost_receipt` (`receipt: true, lose: true`), `idempotency.restart_during_executing` (slow accept so the product can restart mid-call) and `idempotency.repeated_approval` (accept once; duplicates replay)
- [ ] T047 [US3] Add routes `GET /receipts` and `GET /receipts/:receiptId` to src/SignalNoir/Sim/Api/Dispatch.cls serializing `ReceiptSearchResult` and `ReceiptRecord` (depends on T045)
- [ ] T048 [US3] Run T043–T044 green; run the capture validator

**Checkpoint**: Reconciliation (008) has what it needs.

---

## Phase 6: User Story 4 — Partner and Origin evidence can contradict superficial signals (Priority: P2)

**Goal**: per-instance health (what the Partner says), history with window summary (what
happened), recent Origin Orders by patient.

**Independent Test**: quickstart §5.

### Tests for User Story 4 (write first) ⚠️

- [ ] T049 [P] [US4] Write failing tests/SignalNoir/Tests/Sim/Contract/TestPartnerEvidence.cls: `GET /partners/{p}/health?scenarioInstanceId=` → `PartnerHealth` with the script's initial status; P8a after timed-out deliveries → health `UP`, history window `timeouts ≥ 1`, `errorRate = (errors + timeouts) / total`; entries newest first with `httpStatus: null` on timeout; `orderId` and `since` filters; default window 5 min; missing `scenarioInstanceId` → 400; unknown partner/instance → 404; capture
- [ ] T050 [P] [US4] Write failing tests/SignalNoir/Tests/Sim/Contract/TestOriginOrders.cls: `GET /origin/orders?patientId=&scenarioInstanceId=` returns raw snapshots newest first, only of that instance, `emittedAfter` and `limit` honoured, missing params → 400; capture

### Implementation for User Story 4

- [ ] T051 [P] [US4] Create src/SignalNoir/Sim/Model/PartnerState.cls (one per instance, fields per data-model "PartnerState"); initialize it from `script.health` in `Scenarios.Create` (src/SignalNoir/Sim/Scenarios.cls)
- [ ] T052 [US4] Implement `Health(partnerId, sci)` and `History(partnerId, sci, orderId, since, limit)` in src/SignalNoir/Sim/Partner.cls, and `SearchByPatient(sci, patientId, emittedAfter, limit)` in src/SignalNoir/Sim/Origin.cls (depends on T051)
- [ ] T053 [P] [US4] Add the `P8a` tuning variant to src/SignalNoir/Sim/Catalog/P8.cls (health `UP`, every attempt `delay: timeout`, no Receipt)
- [ ] T054 [US4] Add routes `GET /partners/:partnerId/health`, `GET /partners/:partnerId/history`, `GET /origin/orders` to src/SignalNoir/Sim/Api/Dispatch.cls (route order: `/origin/orders` before `/origin/orders/:orderId`) (depends on T052)
- [ ] T055 [US4] Run T049–T050 green; run the capture validator

**Checkpoint**: evidence Tools (006) can be built against real responses.

---

## Phase 7: User Story 5 — The world changes between Approval and Execution (Priority: P2)

**Goal**: explicit events and scripted read/attempt triggers change health, history, Origin status
and next deliveries of one instance.

**Independent Test**: quickstart §6.

### Tests for User Story 5 (write first) ⚠️

- [ ] T056 [P] [US5] Write failing tests/SignalNoir/Tests/Sim/Contract/TestEvents.cls: `POST /scenarios/{id}/events` → 202 `ScenarioInstance` with updated `phase` and `appliedEvents`; `PARTNER_DEGRADES` → next health `DEGRADED`, history (read before any new delivery) contains the variant's `afterEvent` entries with no `orderId` and a window `errorRate > 0`, and next delivery per `afterEvent:` rule (503/timeout); `MAINTENANCE_STARTS` → health `maintenance.active` with `startsAt`/`endsAt`; `ORDER_CANCELLED_AT_ORIGIN` → Origin status `cancelled` with `statusChangedAt` and `reason`; without `orderId`, or with an orderId of another instance → 400; unknown instance → 404; another instance is unchanged; capture
- [ ] T057 [P] [US5] Write failing tests/SignalNoir/Tests/Sim/Contract/TestTriggers.cls: a P3 variant with `on: read:health, nth: 2` changes the world on the 2nd health read without any event call; `read:originStatus` and `attempt` triggers likewise; each trigger fires once (SC-007)

### Implementation for User Story 5

- [ ] T058 [P] [US5] Create src/SignalNoir/Sim/Model/Event.cls (fields per data-model "ScenarioEvent")
- [ ] T059 [US5] Implement `ApplyEvent(sci, req, source)` in src/SignalNoir/Sim/Scenarios.cls per the data-model event-effect table, appending `script.afterEvent.<TYPE>.history` entries as Delivery records with empty order fields, and trigger evaluation in src/SignalNoir/Sim/Script.cls (`OnRead(sci, resource)`, `OnAttempt(sci, n)`) called from `Partner.Health`, `Partner.History`, `Origin.Status` and `Partner.Deliver` with per-instance read counters (depends on T058)
- [ ] T060 [P] [US5] Create src/SignalNoir/Sim/Catalog/P3.cls with tuning variants `P3.partner_fails_again`, `P3.maintenance_window`, `P3.cancelled_at_origin`, each with a `read:health`/`read:originStatus` `nth: 2` trigger (research D12); `P3.partner_fails_again` and `P3.maintenance_window` declare `afterEvent` health and history
- [ ] T061 [US5] Add route `POST /scenarios/:id/events` to src/SignalNoir/Sim/Api/Dispatch.cls (depends on T059)
- [ ] T062 [US5] Run T056–T057 green; run the capture validator

**Checkpoint**: P3 Revalidation (008) can be exercised in Benchmark Mode and in demos.

---

## Phase 8: User Story 6 — The answer key never leaks (Priority: P2)

**Goal**: prove no endpoint exposes answer-key content or private acceptance rules; tuning/test
sets separated.

**Independent Test**: quickstart §7.

### Tests for User Story 6 (write first) ⚠️

- [ ] T063 [P] [US6] Write failing tests/SignalNoir/Tests/Sim/Isolation/TestAnswerKeyLeak.cls: for every catalog variant, create an instance, emit, drive every attempt rule, read health, history, receipts, Origin status/orders, instance and catalog; assert no response body, header or log message contains any `partnerRule` value, nor any of the strings `expectedAction`, `expectedParams`, `expectedState`, `expectedClass`, `answerKey`, `gabarito` (SC-006, FR-030)
- [ ] T064 [P] [US6] Write failing tests/SignalNoir/Tests/Sim/Core/TestCatalogCoverage.cls: every subtype of the contract's `ScenarioVariant.subtype` enum has ≥ 1 `tuning` variant; every variant id is unique; `test` variants exist only in `*Test` classes; a check `FreezeReady()` reports whether P5 and P8b have ≥ 5 `test` variants each (FR-031, FR-032 — P5 and P8b only) — reported, not asserted, until the freeze

### Implementation for User Story 6

- [ ] T065 [P] [US6] Create src/SignalNoir/Sim/Catalog/P5Test.cls and src/SignalNoir/Sim/Catalog/P8Test.cls with one placeholder `test` variant each (shape only; real reserved variants are committed at the freeze by the reserved-case holder, research D9)
- [ ] T066 [US6] Fix any leak found by T063 (most likely in `Catalog.Loader.Served` or in wording text) and run T063–T064 green

**Checkpoint**: the Simulator is safe to use for the Benchmark (010).

---

## Phase 9: User Story 7 — Prior-receipt data for P9 (Priority: P3)

**Goal**: P9 emission seeds the original Order and its Receipt (≈ 3 min earlier) and publishes only
the resend.

**Independent Test**: quickstart §8.

### Tests for User Story 7 (write first) ⚠️

- [ ] T067 [P] [US7] Write failing tests/SignalNoir/Tests/Sim/Contract/TestPriorReceipt.cls: emitting a P9 instance publishes one feed item (the resend); the original has another `orderId` and `transactionId`, `inFeed = false`, is listed by `GET /origin/orders?patientId=` and its Receipt by `GET /receipts?patientId=&scenarioInstanceId=` with `receivedAt` ≈ emission − 3 min; delivering the resend → 200 + new Receipt; no response carries an equivalence key; capture

### Implementation for User Story 7

- [ ] T068 [US7] Create src/SignalNoir/Sim/Catalog/P9.cls (tuning variant with `orders[]` declaring a `priorOf` original per contracts/scenario-script.md) and extend `Emit` in src/SignalNoir/Sim/Scenarios.cls to seed the original OriginOrder (`inFeed = false`) and its Receipt with `receivedAt = Clock.Shift(emittedAt, receivedAtOffsetSeconds)` (research SIM-Q8); run T067 green

**Checkpoint**: 011 can be decided and tested without changing the Simulator.

---

## Phase 10: Polish & Cross-Cutting Concerns

- [ ] T069 Run every `SignalNoir.Tests.Sim.*` suite through iris-agentic-dev and the capture validator; confirm all 12 operationIds are captured (SC-009); commit the captures under tests/sim-contract/captures/
- [ ] T070 Walk specs/002-scenario-simulator/quickstart.md end to end, including the SC-008 timing check, and record measured holds and results in research.md "Verification log"
- [ ] T071 Update specs/002-scenario-simulator/plan.md: turn the iris-agentic-dev gate to pass citing V1–V6, or list what failed
- [ ] T072 [P] Write specs/002-scenario-simulator/contracts/g1-integration.md for the gate integrator: (1) add `Do ##class(SignalNoir.Sim.Setup).EnsureWebApplication()` to `SignalNoir.Interop.Bootstrap.OnStart`; (2) optionally add `tests/sim-contract/validate_sim_captures.py` to `.github/workflows/contracts.yml`; (3) confirm with 006/008 the P3 trigger read count (research D12) and that `SN_PARTNER_TIMEOUT_SECONDS` is the single client-timeout source (research D6)
- [ ] T073 [P] Review the diff against the Constitution, spec, plan and tests (Workflow step 7): no file outside the write zone changed; `contracts/openapi-sim.yaml` untouched; no `$RANDOM`; no reference across the Sim boundary

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: none; T001 must finish before T010/T011.
- **Foundational (Phase 2)**: after Setup; blocks every story.
- **US1 (Phase 3)**: after Foundational. MVP.
- **US2 (Phase 4)**: after US1 (needs instances and emitted Orders to deliver).
- **US3 (Phase 5)**: after US2 (needs deliveries and the Receipt model).
- **US4 (Phase 6)**: after US2 (history is built from deliveries); independent of US3.
- **US5 (Phase 7)**: after US4 (events change health/history) — triggers hook into US2/US4 reads.
- **US6 (Phase 8)**: after US1–US5 (scans every endpoint and variant); T064 can start after US1.
- **US7 (Phase 9)**: after US3 and US4 (needs receipt and patient searches).
- **Polish (Phase 10)**: after all stories.

```text
Setup → Foundational → US1 → US2 ─┬─> US3 ─┬─> US7 ──┐
                                  └─> US4 ─┴─> US5 ──┴─> US6 → Polish
```

### Cross-feature

- 003 can start polling after the US1 checkpoint; 006 Tools after US4; 008 after US2 + US3 (+ US5
  for P3); 010 after US6; 011 after US7.
- Shared file: `src/SignalNoir/Sim/Api/Dispatch.cls` is extended in every story (T027, T041, T047,
  T054, T061) — never in parallel.

### Within each story

Tests first and failing → models → services → routes → green run + capture validation.

## Parallel Examples

```text
# Foundational tests together:
T004 TestPrng · T005 TestIds · T006 TestCanon · T007 TestNoCrossReference · T008 TestCatalogLoader

# US1 tests, then models:
T018 TestScenarios · T019 TestOriginFeed · T020 TestDeterminism · T021 TestCatalog
T022 Instance · T023 OriginOrder · T024 FeedItem

# US2 catalogs while Partner.Deliver is written:
T038 Clean · T039 P5 + P1 · T040 P8b

# After US2, US3 and US4 can proceed side by side:
T043–T047 (Receipts)  ||  T049–T054 (Evidence)
```

## Implementation Strategy

### MVP first

1. Setup + Foundational.
2. US1 → validate quickstart §2 → 003 can consume the feed.
3. US2 → validate quickstart §3 → the tracer path's Simulator side is complete (G1 needs this).

### Incremental delivery

US3 and US4 next (Reconciliation and evidence for 006/008), then US5 (P3), US6 (leak proof
before any Benchmark run), US7 (P9 data, conditional consumer).

### Reserved-set freeze (outside this task list)

The reserved `test` variants for P5 and P8b are written by the reserved-case holder in
`P5Test.cls` / `P8Test.cls` and committed in one freeze commit before the reserved run (research
D9); `TestCatalogCoverage.FreezeReady()` must then report ready.

## Notes

- [P] = different files, no dependency on an incomplete task.
- Commit after each task or logical group; stop at any checkpoint to validate the story alone.
- A divergence from `contracts/openapi-sim.yaml` stops the task and becomes a contract-change
  proposal; never adjust the contract or a capture by hand.
