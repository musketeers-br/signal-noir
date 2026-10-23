# Feature Specification: Runtime Skeleton and Shared Seams

**Feature Branch**: `001-runtime-skeleton-and-seams`

**Created**: 2026-10-22

**Status**: Draft

**Input**: User description: `docs/specify-prompts/001-runtime-skeleton-and-seams.txt`

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Start honestly and report readiness (Priority: P1)

A developer starts a fresh checkout with the documented command and reads the health
surface. With a valid provider configuration, the application reports that it is ready and
that the provider is configured. Without a valid provider key, the application still
starts, reports the provider as unavailable, and keeps running. An Order that needs the
provider ends in `ReviewRequired` with an explicit "provider unavailable" reason.

**Why this priority**: The first observable value is a runtime that starts, tells the truth
about its readiness, and degrades instead of crashing. Everything else is built on this
surface.

**Independent Test**: Start with a valid configuration and read health; then start with no
key, submit one Order and read the resulting Case. Both paths are testable without any
other feature.

**Acceptance Scenarios**:

1. **Given** a valid provider configuration, **When** the developer starts the application
   and reads health, **Then** the response says the application is ready and the provider
   is configured.
2. **Given** no valid provider key, **When** the developer starts the application, **Then**
   the application is up, reports the provider as unavailable, and does not crash.
3. **Given** no valid provider key, **When** an Order that needs the provider is
   processed, **Then** the Order becomes a Case in `ReviewRequired` whose reason explicitly
   names the unavailable provider.

---

### User Story 2 - Accept, persist and reload a synthetic Order (Priority: P1)

A synthetic Order is accepted, persisted as a Case, and read back through the API with its
synthetic label. After the application restarts, the same Case and its timeline are still
there, unchanged.

**Why this priority**: A persisted Case is the source of truth. If it cannot survive a
restart, no later investigation, approval or resolution can be trusted.

**Independent Test**: Accept one synthetic Order, read the Case and timeline, restart the
application, and read them again. The comparison is the test.

**Acceptance Scenarios**:

1. **Given** a synthetic Order, **When** it is accepted, **Then** a Case is readable
   through the API and carries the synthetic label.
2. **Given** an accepted Case, **When** the application restarts, **Then** the Case and its
   timeline are unchanged.
3. **Given** an accepted Case, **When** it is read, **Then** its timeline contains the
   events that produced its current state, in order.

---

### User Story 3 - Build another feature against the published seam (Priority: P2)

A second feature team writes a trivial consumer that imports only the published seam
contract and its test doubles. The consumer compiles and its tests pass without editing the
files of this feature.

**Why this priority**: The seam is what lets the remaining features proceed in parallel.
The slice is only complete when another team can depend on it without waiting for the whole
product.

**Independent Test**: Compile and test the trivial consumer using only the seam contract
and the fakes for the ports.

**Acceptance Scenarios**:

1. **Given** the published seam contract, **When** a consumer imports it, **Then** the
   consumer compiles without touching this feature's files.
2. **Given** the fakes for every port, **When** the consumer runs its tests, **Then** the
   tests pass without a live provider.
3. **Given** a run of the shipped application, **Then** the fakes are not part of the
   runtime dependency set.

---

### User Story 4 - Prove the skeleton with the test harness (Priority: P2)

The project's test harness runs the unit tests on the supported AI Hub build 154 runtime
container and includes one smoke test that proves the walking skeleton end to end.

**Why this priority**: A skeleton without an automated proof is only a claim. The harness is
the evidence that the slice works and stays working.

**Independent Test**: Run the harness on a clean environment; the smoke test and the
seam-contract tests pass.

**Acceptance Scenarios**:

1. **Given** a clean environment, **When** the harness runs, **Then** the smoke test and the
   seam-contract tests pass.
2. **Given** the smoke test, **When** it runs, **Then** it covers start, accept, read,
   restart, and the provider-unavailable path.

---

### Edge Cases

- A provider key is present but rejected: the application MUST stay up and report the
  provider as unavailable, exactly as when no key is configured.
- The application restarts while a Case is in `ReviewRequired`: the state, reason and
  timeline MUST survive unchanged.
- An Order cannot be accepted: the failure MUST cross the boundary as an explicit result,
  never as a success and never as a crash.
- A consumer needs a field or operation the seam does not expose: that MUST become an
  explicit contract change, never a silent edit to the published contract.
- The fakes are accidentally configured in a deployed runtime: the deployment MUST not
  depend on them, and their presence MUST be detectable as an invalid configuration.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The application MUST start from a fresh checkout using the documented command
  and MUST expose a health surface.
- **FR-002**: With a valid provider configuration, the health surface MUST report the
  application as ready and the provider as configured.
- **FR-003**: Without a valid provider key, the application MUST start, MUST report the
  provider as unavailable, and MUST NOT crash.
- **FR-004**: Without a valid provider key, a Case that needs the provider MUST end in
  `ReviewRequired` with an explicit "provider unavailable" reason.
- **FR-005**: The application MUST accept a synthetic Order and persist it as a Case.
- **FR-006**: Every Case and every Case summary read through the API MUST carry the
  synthetic label.
- **FR-007**: A persisted Case MUST be readable through the API together with its timeline.
- **FR-008**: A restart MUST preserve every persisted Case and its timeline unchanged.
- **FR-009**: The application MUST publish a stable internal seam contract in
  `docs/seams.md` that includes:
  - opaque identifiers with the `case_`, `prop_`, `appr_`, `exec_`, `evid_`, `cmd_` and
    `run_` prefixes;
  - the error envelope `{error:{code,message,details}}` with the closed error-code
    vocabulary of the frozen HTTP contract;
  - the timeline event `{seq,at,type,actor,refId,payload}`;
  - the DTOs for Order, Case, CaseSummary, Evidence, Proposal, ValidatorVerdict, Approval,
    Execution, Receipt and Dossier;
  - the ports `CaseCommands`, `CaseQueries`, `Validator`, `Proposer`, `Tools`,
    `PartnerClient`, `Clock` and `IdGenerator`.
- **FR-010**: The seam contract MUST include test doubles (fakes) for every port, usable
  without a live provider.
- **FR-011**: The fakes MUST NOT be a runtime dependency of the shipped application.
- **FR-012**: A consumer MUST be able to compile and test against the published seam
  contract and its fakes without modifying this feature's files.
- **FR-013**: The test harness MUST run the project's unit tests on the supported AI Hub
  build 154 runtime container and MUST include one smoke test that proves the walking
  skeleton.
- **FR-014**: The smoke test MUST exercise start, accept, read, restart and the
  provider-unavailable path.
- **FR-015**: A missing or invalid provider key MUST NOT prevent startup.
- **FR-016**: Predictable failures MUST cross layer boundaries as explicit result values;
  a refusal or a partial outcome MUST NOT be reported as success.
- **FR-017**: Observed fact, diagnosis and absence of information MUST remain
  distinguishable in every Case and timeline entry.
- **FR-018**: No secret, credential or provider key MAY appear in a Case, timeline, log or
  export.
- **FR-019**: The runtime MUST NOT depend on development-only tooling, including
  `iris-agentic-dev`.
- **FR-020**: The application MUST keep liveness, readiness and provider availability as
  distinct reported conditions.

### Key Entities *(include if feature involves data)*

- **Order**: The synthetic external request that enters the system. It is read-only input
  and is not owned by this feature.
- **Case**: The persisted source of truth for a resolution. It carries an opaque
  `case_` identifier, the synthetic label, a state from the closed vocabulary, a version
  and its timeline.
- **Timeline Event**: An append-only record `{seq,at,type,actor,refId,payload}` describing a
  fact that happened to a Case.
- **Seam DTOs**: Order, Case, CaseSummary, Evidence, Proposal, ValidatorVerdict, Approval,
  Execution, Receipt and Dossier, as published in `docs/seams.md`.
- **Seam Ports**: CaseCommands, CaseQueries, Validator, Proposer, Tools, PartnerClient,
  Clock and IdGenerator, each with a test double that is not shipped at runtime.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A second feature team compiles and tests a consumer against `docs/seams.md`
  with **zero** edits to this feature's files.
- **SC-002**: In **100%** of starts with a valid configuration, the health surface reports
  ready and the provider as configured.
- **SC-003**: In **100%** of starts without a valid key, the application stays up, reports
  the provider as unavailable, and no Order crashes the runtime.
- **SC-004**: After a restart, **100%** of accepted Cases and their timelines are identical
  to the pre-restart read.
- **SC-005**: The harness smoke test and the seam-contract tests pass on a clean
  environment with **zero** failures.
- **SC-006**: A search of Cases, timelines, logs and exports finds **zero** occurrences of
  a provider key or credential.
- **SC-007**: A missing or invalid key blocks startup **zero** times.

## Out of Scope

- Real agent calls and any provider interaction beyond availability reporting.
- Simulator scenarios beyond the one synthetic Order used by the smoke test.
- The operator console, the Review Dossier workflow and the benchmark.
- Execution semantics, Approvals, Receipts and Partner effects.
- Authentication and multi-user operation.

## Assumptions

- The supported runtime is the local AI Hub build 154 container required by the
  Constitution; build 162 is not used.
- "Restart" means the documented restart that preserves persisted data; a destructive reset
  recreates the demo state and is documented separately.
- All data is synthetic and carries the synthetic label.
- The frozen HTTP contracts in `contracts/` are read-only; a needed field or error code
  that is missing becomes an explicit contract change.
- The exact shape and transport of the health surface are a Plan decision; this
  specification requires only that liveness, readiness and provider availability are
  distinct and observable.
- Failures are returned as values, not raised across the core boundary.
- The fakes exist only for tests and for consumers' tests, never for a deployed runtime.
