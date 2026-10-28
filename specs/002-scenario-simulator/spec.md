# Feature Specification: Scenario Simulator

**Feature Branch**: `002-scenario-simulator`

**Created**: 2026-10-23

**Status**: Draft

**Input**: User description: "Scenario Simulator. It is an external system reached only over HTTP. The contract is contracts/openapi-sim.yaml." (full description: `docs/specify-prompts/002-scenario-simulator.txt`)

## Context

The Scenario Simulator is the external world Signal Noir works against: a simulated Origin that
emits synthetic lab Orders, and a simulated Partner that receives them, answers according to a
scripted scenario, keeps Receipts and reports its own health and history. It is a separate bounded
context reached **only over HTTP**, under the normative contract `contracts/openapi-sim.yaml`. No
part of the product references its internals (Constitution, Principle I).

Its consumers are:

- **The Production's inbound entry**, which reads Orders from the Origin feed.
- **The Execution path**, which delivers Orders to the Partner (one call per Attempt) and reconciles
  uncertain outcomes by searching Receipts.
- **The Agent's and Rules Mode's read-only evidence Tools**, which read health, history, Receipts,
  Origin status and recent Orders.
- **The Benchmark runner**, which creates scenario instances from a seed, emits their Orders and,
  for demos and manual tests, injects world-change events.

All data is synthetic. The Simulator owns no Policies, no Mapping catalog and no answer key.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deterministic scenario instance emits Orders (Priority: P1)

The Benchmark runner (or a developer) creates an isolated scenario instance from a family, a
variant and a seed, then asks the simulated Origin to emit that instance's Orders. The Orders appear
in the Origin feed, bound to the instance, and their status can be read at the Origin. Creating the
same family, variant and seed again reproduces the same sequence.

**Why this priority**: It is the first step of the tracer path (an Order leaves the Simulator and
becomes a Case). Without reproducible, isolated instances no other scenario, test or Benchmark
repetition is meaningful.

**Independent Test**: Create an instance from a seed, emit its Orders, read the feed; create a
second instance with the same family, variant and seed and compare. Create a third instance from a
different variant concurrently and check that nothing is shared.

**Acceptance Scenarios**:

1. **Given** a known family, variant and seed, **When** an instance is created, **Then** a new
   scenarioInstanceId is returned with status `created` and no Order is emitted yet.
2. **Given** a created instance, **When** emission is requested, **Then** the variant's Orders are
   published in the Origin feed, each carrying the scenarioInstanceId, the runId (or null) and the
   repetition, and the instance status becomes `emitted`.
3. **Given** an instance that already emitted, **When** emission is requested again, **Then** the
   same emissions are returned and no new Order enters the feed.
4. **Given** two instances created with the same family, variant and seed, **When** both emit,
   **Then** their sequences of Orders and of scripted responses match, while their orderIds do not
   overlap.
5. **Given** two instances created concurrently, **When** both emit and receive deliveries, **Then**
   their orderId namespaces, Receipts, health, history and Origin status never mix.
6. **Given** an unknown family or variant, **When** an instance is requested, **Then** the request
   is refused as not found and no instance exists.

---

### User Story 2 - Partner answers deliveries per scenario and deduplicates atomically (Priority: P1)

The Execution path delivers an Order to the Partner with an idempotency key and a transaction
identifier. The Partner answers exactly as the instance's scenario dictates: success with a valid
Receipt, business error, transient error, or an uncertain outcome (timeout, 5xx without a body, 200
without a valid Receipt). Before applying the script, the Partner deduplicates: the same key with
the same payload returns the original Receipt; the same key with an incompatible payload is
rejected.

**Why this priority**: Delivery with a valid Receipt closes the tracer path, and atomic
deduplication is the Partner-side half of "effects at most once" (Principle VI). Every failure
family the product must classify comes through this behavior.

**Independent Test**: For each family, deliver the instance's Order attempt by attempt and compare
each response with the sequence the catalog declares for that variant; then repeat a delivery with
the same key and payload, and once with the same key and a different payload.

**Acceptance Scenarios**:

1. **Given** a `clean.success` instance, **When** its Order is delivered, **Then** the Partner
   returns a valid Receipt whose orderId and idempotency key match the request, and the Receipt is
   recorded.
2. **Given** a delivered key with a recorded Receipt, **When** the same key and payload are
   delivered again, **Then** the original Receipt is returned, marked as a replay, and no new effect
   is recorded.
3. **Given** a delivered key, **When** the same key arrives with a different Order payload, **Then**
   the request is rejected with 422 `IDEMPOTENCY_KEY_REUSED` and no effect is recorded.
4. **Given** a key that already has a Receipt and a script that would now fail, **When** the same
   key and payload are delivered, **Then** the original Receipt is returned (deduplication takes
   precedence over the script).
5. **Given** concurrent deliveries of the same key and payload, **When** they race, **Then** exactly
   one Receipt exists and every caller receives that same Receipt.
6. **Given** a P5 instance, **When** its Order is delivered, **Then** the Partner answers a 500 that
   hides a business validation error, or a 200 with a free-text rejection and no valid Receipt, in
   the PT/EN wording the variant declares.
7. **Given** a P1 instance, **When** the first Attempt is made, **Then** no response arrives before
   the client's timeout; **When** the second Attempt is made, **Then** a 500 with a semantic
   validation error is returned.
8. **Given** a P8b instance, **When** an Order is delivered before a Mapping, or with a Mapping
   whose context (specimen type or unit) does not match, **Then** a business rejection citing the
   code or the incompatibility is returned; **When** delivered with the correct Mapping, **Then** a
   valid Receipt is returned.
9. **Given** a `clean.partner_unavailable` instance, **When** delivered before the script's
   recovery point, **Then** a sincere 503 unavailable is returned.
10. **Given** a `P5.injection` variant, **When** its Order is delivered, **Then** the response
    carries the same outcome as the base variant plus an embedded instruction in the body.

---

### User Story 3 - Receipts can be found after a lost response (Priority: P2)

The Partner can accept an Order and lose the response, so the caller sees an uncertain outcome
while a valid Receipt exists. Reconciliation and evidence Tools find Receipts by idempotency key, by
orderId, or by synthetic patient within an instance. Each result carries the Receipt fields and the
raw Order snapshot exactly as delivered, never a ready-made equivalence key.

**Why this priority**: Reconciliation after an uncertain outcome is how the product proves it never
resends a delivered effect. It depends on Story 2 for deliveries to exist.

**Independent Test**: Deliver the Order of an `idempotency.lost_receipt` instance, observe the
uncertain outcome on the caller side, then search Receipts by orderId and by idempotency key.

**Acceptance Scenarios**:

1. **Given** an `idempotency.lost_receipt` instance, **When** its Order is delivered, **Then** the
   Receipt is recorded and the response is delayed beyond the client's timeout.
2. **Given** that lost response, **When** Receipts are searched by orderId, **Then** the Receipt is
   found together with the raw Order snapshot.
3. **Given** a search with no idempotency key, no orderId and no patient, **When** it is made,
   **Then** it is refused as an invalid request.
4. **Given** a search by patient without a scenarioInstanceId, **When** it is made, **Then** it is
   refused as an invalid request.
5. **Given** a search that matches nothing, **When** it is made, **Then** an empty result is
   returned, never "not found".
6. **Given** any Receipt or Order returned by the Simulator, **When** its fields are inspected,
   **Then** no equivalence key is present; only the raw snapshot is.

---

### User Story 4 - Partner and Origin evidence can contradict superficial signals (Priority: P2)

Evidence Tools read what the Partner says about itself (health), what actually happened (recent
history with a window summary), the status of an Order at the Origin and the recent Orders of a
synthetic patient. These signals answer per instance and can contradict each other, for example
health `UP` while every recent call timed out.

**Why this priority**: The Agent's value is measured on families where a superficial signal lies
(P5, P8a). The evidence must make that contradiction observable without ever explaining it.

**Independent Test**: For a P8a instance, deliver until a timeout, then read health and history for
the same instance and compare.

**Acceptance Scenarios**:

1. **Given** a P8a instance after deliveries that timed out, **When** health is read, **Then** it
   says `UP`; **When** history is read, **Then** the window shows the timeouts and a matching error
   rate.
2. **Given** history entries, **When** they are read, **Then** each entry carries its time, outcome
   and raw message, and the window summary counts total, delivered, errors and timeouts.
3. **Given** a history read filtered by orderId, **When** it is made, **Then** only that Order's
   entries are returned.
4. **Given** an Order emitted by an instance, **When** its Origin status is read, **Then** it is
   `active` unless it was cancelled at the Origin.
5. **Given** a synthetic patient within an instance, **When** recent Origin Orders are searched,
   **Then** raw snapshots are returned, newest first.
6. **Given** an unknown partner or instance, **When** health or history is read, **Then** the
   request is refused as not found.

---

### User Story 5 - The world changes between Approval and Execution (Priority: P2)

To exercise Revalidation (P3), the world of an instance can change after the Operator approved and
before the effect is sent: the Partner degrades, a maintenance window starts, or the Order is
cancelled at the Origin. The change comes either from an explicit event or from a trigger declared
in the variant's script, and it is visible in health, history and Origin status before the next
delivery.

**Why this priority**: P3 is a platform guarantee the Benchmark reports separately. It depends on
Stories 1, 2 and 4 being observable.

**Independent Test**: Create a P3 instance, read health (healthy), inject `PARTNER_DEGRADES`, read
health again and deliver.

**Acceptance Scenarios**:

1. **Given** a P3 instance, **When** `PARTNER_DEGRADES` is injected, **Then** health and history
   reflect the degradation before the next delivery, and the next delivery fails as the script
   declares.
2. **Given** a P3 instance, **When** `MAINTENANCE_STARTS` is injected, **Then** health announces an
   active maintenance window with its start and end.
3. **Given** an emitted Order, **When** `ORDER_CANCELLED_AT_ORIGIN` is injected for it, **Then** its
   Origin status becomes `cancelled` with the change time and reason.
4. **Given** `ORDER_CANCELLED_AT_ORIGIN` without an orderId, **When** it is injected, **Then** it is
   refused as an invalid request.
5. **Given** a P3 variant with a scripted trigger, **When** the triggering read happens, **Then** the
   world changes without any explicit event call.
6. **Given** an applied event, **When** the instance is read, **Then** its phase and the list of
   applied events show the change.

---

### User Story 6 - The answer key never leaks (Priority: P2)

The expected outcome of each variant (the answer key) belongs to the Benchmark evaluator only. No
Simulator endpoint, response, log line or catalog entry exposes it, so neither the Agent nor Rules
Mode can read the answer through evidence.

**Why this priority**: A leaked answer key invalidates every Benchmark result (Principle VIII).

**Independent Test**: Instantiate every variant of the catalog, exercise every endpoint, and search
all responses for answer-key content.

**Acceptance Scenarios**:

1. **Given** every catalog variant, **When** every endpoint is probed, **Then** no response contains
   the expected Action, its parameters, the expected final state or the expected classification.
2. **Given** the scenario catalog, **When** it is listed, **Then** it declares families, variants,
   sets, partner, language and scripted responses, but no answer key, Policy or Mapping.
3. **Given** the catalog filtered by set, **When** `tuning` or `test` is requested, **Then** only the
   variants of that set are listed.

---

### User Story 7 - Prior-receipt data for P9 (Priority: P3)

For the conditional P9 family, emitting an instance seeds a prior delivery of the same real Order
under another transaction identifier and another orderId, with its Receipt recorded a few minutes
before the resend. Only the resend enters the feed. The original can be found by Receipt search and
by the patient's recent Origin Orders. The product behavior on P9 is out of scope here.

**Why this priority**: P9 is conditional; the data must exist so the product feature (011) can be
decided and tested without changing the Simulator.

**Independent Test**: Emit a P9 instance, read the feed, then search Receipts and Origin Orders by
the patient.

**Acceptance Scenarios**:

1. **Given** a P9 instance, **When** it emits, **Then** only the resend appears in the feed, and a
   prior Receipt for the original exists with a receipt time before the resend.
2. **Given** the resend's patient, **When** Receipts and Origin Orders are searched within the
   instance, **Then** the original Order's raw snapshot is found under its own orderId and
   transaction identifier.
3. **Given** a P9 resend, **When** it is delivered, **Then** the Partner accepts it with a valid
   Receipt (the duplicate is what the Benchmark measures).

---

### Edge Cases

- A delivery names an unknown partner or an unknown scenarioInstanceId: refused as not found, with
  no effect.
- A delivery is malformed (missing key, key shorter than the minimum, missing Order): refused as an
  invalid request, with no effect and no history entry claiming a delivery.
- Payload comparison for deduplication ignores key order and ignores the transaction identifier;
  every other difference in the Order makes the payload incompatible.
- The `mappingRef` of a delivery is informative only and does not change the deduplication rule.
- A delayed response (timeout, lost response) under a reduced time scale still exceeds the client's
  timeout, so the caller always observes the uncertain outcome the script declares.
- A 5xx without a body and a 200 without a valid Receipt are produced as scripted; the Simulator
  never "helps" by attaching a Receipt that the script does not record.
- Raw Order snapshots may carry unordered and mixed-case codes and non-UTC offsets on purpose; the
  Simulator preserves them unchanged. Times the Simulator itself generates are always UTC.
- Free-text fields (Order notes, response bodies, log messages, health messages) may contain
  embedded instructions; they are served as data, unchanged.
- `ORDER_CANCELLED_AT_ORIGIN` names an orderId that does not belong to the instance: refused, and
  no other instance changes. An event never affects any instance but the one it names.
- The feed is read with an `afterSeq` beyond the last item: an empty page is returned and `lastSeq`
  equals the requested value.
- Recovery scenarios that the product drives on its own side (restart during Executing, repeated
  command, late worker) use the existing variants; the Simulator only has to keep answering by its
  deduplication and script rules across those repetitions.

## Requirements *(mandatory)*

### Functional Requirements

**Boundary**

- **FR-001**: The Simulator MUST be reachable only through the HTTP interface of
  `contracts/openapi-sim.yaml` and MUST implement it without adding, removing or renaming
  endpoints, fields, enumerations or error codes. A needed difference MUST become a contract-change
  proposal.
- **FR-002**: The Simulator MUST own no Policies, no Mapping catalog and no answer key, and MUST
  serve only synthetic data marked as synthetic.
- **FR-003**: Errors of the Simulator's own interface MUST use the contract's error envelope with
  the codes `INVALID_REQUEST`, `NOT_FOUND` and `IDEMPOTENCY_KEY_REUSED`. Partner delivery responses
  other than key reuse and invalid or unknown requests MUST follow the scenario script, not the
  envelope.

**Scenario instances and determinism**

- **FR-004**: The Simulator MUST create an isolated scenario instance from family, variant and seed,
  with optional runId, repetition (default 1) and time scale (default 1). Creating an instance MUST
  NOT emit Orders.
- **FR-005**: All Partner, Receipt, health, history, Origin and event state MUST belong to exactly
  one scenario instance. There MUST be no global active scenario.
- **FR-006**: The same family, variant and seed MUST produce the same sequence of Orders (content
  and order) and the same sequence of scripted responses per Attempt.
- **FR-007**: Every orderId MUST be unique per scenario instance and repetition and MUST never repeat
  across instances or runs, including instances created from the same seed.
- **FR-008**: Each repetition of a variant MUST be its own instance; two instances, concurrent or
  not, MUST never share IDs or state.
- **FR-009**: The scenario catalog MUST list every instantiable variant with its family, subtype,
  stable variant identifier, set (`tuning` or `test`), partner, language and declared script, and
  MUST be filterable by family and by set.

**Origin**

- **FR-010**: Emission MUST publish the variant's Orders in the Origin feed, each bound to its
  scenarioInstanceId, runId and repetition, with a transaction identifier and emission time.
- **FR-011**: Emission MUST be idempotent per instance: a repeated request returns the same
  emissions and publishes nothing new.
- **FR-012**: The Origin feed MUST be ordered by a monotonic sequence, MUST be readable after a given
  sequence, and its items MUST never change after publication.
- **FR-013**: The Simulator MUST expose each Order's Origin status (`active` or `cancelled`) with its
  change time and, when cancelled, the reason.
- **FR-014**: The Simulator MUST list the recent Origin Orders of a synthetic patient within one
  instance, as raw snapshots, newest first.

**Partner delivery**

- **FR-015**: Each delivery MUST be treated as one Attempt and answered according to the instance's
  script for that Attempt, covering success with a valid Receipt, business error, transient error
  and uncertain outcomes (timeout, 5xx without a body, 200 without a valid Receipt).
- **FR-016**: Deduplication MUST be atomic and MUST take precedence over the script: the same key
  with the same payload returns the original Receipt, flagged as a replay, with no new effect; the
  same key with an incompatible payload MUST be rejected with 422 `IDEMPOTENCY_KEY_REUSED` and no
  effect.
- **FR-017**: Payload equality for deduplication MUST compare the Order object deeply, ignoring key
  order, and MUST ignore the transaction identifier and the informative `mappingRef`.
- **FR-018**: A Receipt MUST be recorded only when the script says the Partner accepted the Order,
  and a recorded Receipt MUST carry receiptId, orderId, idempotency key, receipt time and partner
  matching the delivery.
- **FR-019**: The Partner MUST be able to accept an Order, record its Receipt and lose the response
  by delaying it beyond the client's timeout.
- **FR-020**: Scripted delays MUST be scaled by the instance's time scale and MUST still exceed the
  client's timeout when the script declares a timeout or a lost response.
- **FR-021**: Response bodies MUST support PT, EN and mixed wording, MAY misstate the cause (a 500
  that is really a business validation error), and MAY carry embedded instructions, exactly as the
  variant declares.

**Receipts and evidence**

- **FR-022**: Receipt search MUST accept idempotency key, orderId and synthetic patient, combined as
  AND, MUST require at least one of them, MUST require a scenarioInstanceId when searching by
  patient, MUST return an empty list (never "not found") when nothing matches, and MUST sort by
  receipt time, newest first.
- **FR-023**: Every Receipt returned MUST include the raw Order snapshot of the delivery that
  produced it, and no endpoint MUST ever return a ready-made equivalence key.
- **FR-024**: A single Receipt MUST be readable by its receiptId.
- **FR-025**: Partner health MUST report what the Partner declares about itself (`UP`, `DEGRADED`,
  `DOWN`, message and announced maintenance window) per instance, independently of what the history
  shows.
- **FR-026**: Partner history MUST report recent entries per instance (time, orderId, transaction
  identifier, key, HTTP status or none on timeout, outcome, latency, raw message), newest first,
  optionally filtered by orderId and by start of window, with a window summary of total, delivered,
  errors, timeouts and error rate.

**World changes**

- **FR-027**: The Simulator MUST apply the events `PARTNER_DEGRADES`, `PARTNER_RECOVERS`,
  `MAINTENANCE_STARTS`, `MAINTENANCE_ENDS` and `ORDER_CANCELLED_AT_ORIGIN` to one instance, and
  `ORDER_CANCELLED_AT_ORIGIN` MUST require an orderId of that instance.
- **FR-028**: P3 variants MUST be able to declare scripted triggers that change the world without an
  explicit event call, so that the change can happen between Approval and Revalidation in Benchmark
  Mode.
- **FR-029**: After an event, health, history, Origin status and the next delivery MUST reflect the
  change, and the instance MUST show its current phase and the applied events.

**Answer-key isolation**

- **FR-030**: No endpoint, response body, header, log line, health message or catalog entry MUST
  expose the expected outcome of a variant (expected Action, parameters, final state or
  classification).

**Families**

- **FR-031**: The catalog MUST provide variants for: clean (success, sincere unavailable, unknown
  code with a single approved mapping, already processed with the same orderId, ambiguous
  identity); P5 (lying 500, 200 with a free-text rejection, injection, varied PT/EN wording); P1
  (timeout combined with a semantic cause); P8a (health `UP` with timing-out calls); P8b (two
  approved mappings for the same code distinguishable only by specimen type or unit); P3 (Partner
  fails again, maintenance window, cancelled at Origin); idempotency (lost receipt, restart during
  Executing, repeated approval); and P9 data (prior receipt under another transaction identifier
  and orderId).
- **FR-032**: The core Benchmark families P5 and P8b MUST each have separate `tuning` and `test`
  variants, with at least 5 `test` variants per family at the freeze. Clean controls, the Dossier
  case and the platform-guarantee families (P3, idempotency) are run from pinned `tuning` variants
  and are not scored as test-set results.
- **FR-033**: For P9, emission MUST seed the original Order in the Origin history and its Receipt at
  the Partner with a receipt time a few minutes before the resend, and MUST put only the resend in
  the feed.

**Verification**

- **FR-034**: A contract test suite MUST exercise every operation of `contracts/openapi-sim.yaml`
  and validate every response against its schema; the feature is not done until it passes.

### Key Entities

- **Scenario Variant**: a catalog entry: family, subtype, stable identifier, set (tuning/test),
  partner, language and the declared script of responses per Attempt and of triggers. It carries no
  answer key.
- **Scenario Instance**: one isolated run of a variant from a seed, with optional runId and
  repetition, a time scale, a status (`created`, `emitted`), a current phase, applied events and the
  orderIds it emitted. Owns all the state below.
- **Synthetic Order**: the raw Order as the Origin emitted it: orderId, partner, origin unit,
  patient, exams, specimen (type, unit, collection time), request time, notes and the synthetic
  flag. Immutable once emitted.
- **Order Envelope**: a feed item: sequence, instance, runId, repetition, transaction identifier,
  emission time and the Order.
- **Origin Order Status**: whether an Order is active or cancelled at the Origin, since when and why.
- **Delivery (Attempt)**: one call to the Partner with idempotency key, transaction identifier,
  instance, runId, Order and optional mapping reference.
- **Receipt**: the Partner's proof of acceptance: receiptId, orderId, idempotency key, receipt time,
  partner, plus the instance, transaction identifier and raw Order snapshot of the delivery.
- **Partner Health**: what the Partner declares: status, message, announced maintenance window and
  check time, per instance.
- **Partner Log Entry / History**: what actually happened per delivery, and the window summary.
- **Scenario Event**: a world change applied to one instance.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For every catalog variant, creating two instances with the same family, variant and
  seed and driving them through the same calls yields identical Order sequences and identical
  scripted responses in 100% of comparisons.
- **SC-002**: Across all instances created during a full reference run (at least 30 agent
  investigations plus controls, each repetition its own instance), zero orderIds repeat.
- **SC-003**: Two instances driven concurrently show zero shared IDs and zero cross-instance
  effects on Receipts, health, history or Origin status.
- **SC-004**: Under concurrent repeated deliveries of the same key and payload, exactly one Receipt
  exists in 100% of trials; every reuse of a key with a different payload is refused with no effect.
- **SC-005**: In 100% of lost-response trials, the Receipt is found by orderId and by idempotency
  key after the caller observed the uncertain outcome.
- **SC-006**: A probe of every endpoint for every variant finds zero occurrences of answer-key
  content.
- **SC-007**: After any injected or scripted world change, the next health, history or Origin read
  reflects it in 100% of trials.
- **SC-008**: With a reduced time scale, a timeout-family variant completes its scripted Attempts
  fast enough that a 3-case quick validation can finish in 3 minutes or less.
- **SC-009**: The contract test suite covers 100% of the operations of `contracts/openapi-sim.yaml`
  and passes.

## Assumptions

- **Determinism vs. unique IDs**: "same Order IDs for the same seed" means the same per-instance
  sequence of Orders; the full orderId is namespaced by the instance (as in the contract example
  `ORD-sci_01HZX-0001`), so two instances from one seed match in sequence and content but never
  share an orderId.
- **Origin delivery is pull**: the Production reads `GET /origin/feed` by polling, as the contract
  adopts (SIM-Q1). The Simulator never pushes Orders.
- **Maintenance window**: the Partner announces it through health and the `MAINTENANCE_STARTS`
  event; whether it blocks a send is a product Policy decision (SIM-Q2).
- **P3 in Benchmark Mode**: P3 variants carry scripted triggers (for example, on a Revalidation-time
  read of health or Origin status); the explicit event endpoint serves demos and manual tests
  (SIM-Q3). The exact trigger is fixed in the variant script during planning, with Henry and José.
- **422 class**: how the product classifies a key-reuse 422 is the Core's decision (SIM-Q4); the
  Simulator only rejects with no effect.
- **Time scale**: scripted delays use `max(client timeout + margin, nominal delay × timeScale)`, so
  a timeout remains a timeout under acceleration (SIM-Q5). The client timeout value is confirmed in
  planning.
- **Identifiers**: scenario instances use the `sci_` prefix; receiptId, orderId and transaction
  identifiers are opaque (SIM-Q6). Patient searches are scoped by instance (SIM-Q7).
- **P9 prior receipt**: seeded about 3 minutes before the resend (SIM-Q8).
- **Recovery variants**: restart during Executing, repeated command and late worker are exercised by
  the product against existing variants (`idempotency.*`, `clean.success`); no new catalog subtype
  is added, since the contract enumeration is closed.
- **Answer key location**: the answer key for each variant lives in Benchmark-side fixtures owned
  by the team member who prepares the reserved cases (Principle VIII), outside the Simulator's
  reachable data.
- **Simulator fixtures**: `contracts/fixtures/` currently covers only the product API; Simulator
  contract-test fixtures are produced by this feature.
- **Calendar gate**: until 2026-10-26 only this specification, its plan, tasks, contract notes and
  fixtures are produced; no submission code.

## Dependencies

- `contracts/openapi-sim.yaml` (frozen, normative).
- `docs/seams.md` v1: the `PartnerClient` and `Tools` ports are the product side of this boundary;
  this feature does not change them.
- Consumers that rely on this feature: 003 (inbound feed), 006 (evidence Tools), 008 (delivery and
  Reconciliation), 010 (instances, seeds, sets), 011 (P9 data).

## Out of Scope

The Agent, Case state, the operator console, Benchmark scoring, publishing the answer key, and the
product's behavior on P9.
