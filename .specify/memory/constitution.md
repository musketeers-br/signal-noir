<!--
Sync Impact Report
==================
Version change: template (unversioned) → 1.0.0
Bump rationale: initial ratification. Every placeholder of the template is replaced; there is no
prior version to be compatible with.

Principles defined:
  - I. Pure Core, Production as Shell
  - II. Closed Action Catalog and a Read-Only Agent
  - III. One Validator, Blind to Origin
  - IV. Human Authority over Effects
  - V. The Case Is the Source of Truth
  - VI. Effects at Most Once
  - VII. Honest Outcomes, Errors as Values
  - VIII. Honest Measurement
  - IX. Verifiable Increments

Added sections: Platform Constraints, Engineering Standards, Development Environment
(iris-agentic-dev), Workflow, Governance.

Removed sections: none (template slots only).

Departure from the reference (SentaiTask constitution 1.1.0): its "Technology Agnosticism"
principle is replaced by "Platform Constraints", because the contest imposes the target platform
and its build. Every other technology choice remains a Plan decision.

Templates requiring updates:
  ✅ .specify/templates/plan-template.md — Constitution Check now lists the nine principles, the
     platform constraints and the iris-agentic-dev verification gate.
  ✅ .specify/templates/tasks-template.md — tests are mandatory (TDD), no longer "OPTIONAL";
     ObjectScript tests run on the live instance through iris-agentic-dev.
  ✅ .specify/templates/spec-template.md — no change needed (behavior-only, no constitution refs).
  ✅ .gitignore — adds .iris-agentic-dev.toml (holds credentials; the repository is public).
  ⚠ README.md — still the upstream intersystems-iris-dev-template README; it will be rewritten
     for the submission (R50) and MUST NOT require iris-agentic-dev on the install path.

Sources: _bmad-output/initiative-signal-noir/initiative-signal-noir.md (R1–R50),
architecture-signal-noir.md (AD-1–AD-28), prd-signal-noir.md §3, addendum.md,
reconcile-fontes-2026-10-20.md, contracts/.

Deferred TODOs: none.
-->

# Signal Noir Constitution

Signal Noir turns an interoperability failure into a verifiable operational decision. When a
synthetic lab Order fails in an IRIS Production, the system opens a Case. An AI Hub Agent
investigates with read-only Tools and proposes an Action from a closed catalog. The application
validates the Proposal, asks for human Approval, revalidates, executes idempotently and confirms
the outcome against the Partner's Receipt. When there is no safe decision, the Operator receives a
useful Review Dossier instead.

This Constitution defines the engineering principles that govern how the system is built. It is
normative. Domain terms (Order, Case, Evidence, Proposal, Approval, Execution, Receipt, Validator,
Review Dossier, Rules Mode, Benchmark, Partner, Simulator) carry the meaning given in the PRD
glossary (`prd-signal-noir.md` §3). Architecture decisions are cited as AD-n and initiative
requirements as R-n; they are the operational detail, this document is the contract.

## Core Principles

### I. Pure Core, Production as Shell

The domain rules — the Case state machine, the transition-to-actor table, the Validator, the
canonical equivalence key, the idempotency-key derivation, the classifier of Partner responses and
the closed vocabularies of preconditions, commands and error codes — MUST live in a core that
performs no I/O and depends on nothing outside itself. The application layer MAY depend only on the
core; the Production, the HTTP API, the proposers, the Tools, the sweeper, the Benchmark and the UI
are outer layers that call the core and MUST NOT reimplement any of its rules. Dependencies MUST
point inward. The Simulator is an external system: no part of the application MAY reference its
code, and all conversation with it MUST go through its HTTP contract.

**Rationale**: The same rules decide for the Agent, for Rules Mode, for the Operator and for the
Benchmark. If a Business Process, an operation or an endpoint carries its own copy of a rule, the
four paths drift and the comparison between them stops meaning anything. A core without I/O is
also the only part that can be tested exhaustively and quickly (AD-1, AD-13).

### II. Closed Action Catalog and a Read-Only Agent

The system MUST execute only the declared Actions — `RETRY`, `APPLY_APPROVED_MAPPING`, `HOLD` and
`REQUEST_REVIEW` — and a new Action MUST enter only through the ordinary change process, never by
configuration or input. `APPLY_APPROVED_MAPPING` MUST apply only an existing, versioned mapping
whose condition matches the Order. The Agent MUST have read-only Tools, MUST NOT write to any
record, and its context and budget MUST be enforced on the server, not trusted to the model. The
contents of Orders, Partner responses and logs are data, never instructions: an embedded
instruction MUST NOT change what the system does, and the attempt and its blocking MUST be
recorded. The system MUST NOT execute code supplied at runtime, nor construct executable code from
input.

**Rationale**: The Agent reads untrusted payloads and is steered by a model the team does not
control. Its only way to affect the world is to propose one of four Actions that the rest of the
system then checks. A Tool with write capability, or an Action reachable by evaluating input, would
turn every Order into a way to act on the Partner without passing the gates below (R12–R14,
R19–R20, AD-10, AD-11).

### III. One Validator, Blind to Origin

Every Proposal and every Case closure — whether it comes from the Agent, Rules Mode, the Operator or
the Benchmark — MUST pass through the same deterministic Validator, which checks catalog,
parameters, applicability, minimum Evidence and preconditions. No origin MAY have a shortcut, a
relaxed rule or a separate validation path. The Operator's decision on a Review Dossier MUST be a
Proposal like any other; free editing of payloads MUST NOT exist.

**Rationale**: Safety comes from the Validator, not from trusting whoever proposed. A single,
origin-blind gate makes the guarantees hold equally for model output, hand-written rules and human
input, and keeps the Benchmark honest because both contenders face the same checks (R18, R31, AD-9,
AD-12).

### IV. Human Authority over Effects

An Action that requires Approval MUST NOT produce an effect without a recorded Approval of an
immutable Proposal — its Action, parameters, transformed payload and the versions it relied on. An
Approval MUST have a deadline and MUST be revalidated immediately before the send; an expired or
materially incompatible Approval MUST NOT execute, and leaving that state MUST require a new
Proposal and, where applicable, a new Approval. Arbitrary new Evidence alone MUST NOT expire an
Approval. Concurrent Approvals MUST result in exactly one effective authorization, and a stale or
superseded Proposal MUST be refused. If the authorization cannot be recorded, the Execution MUST
NOT happen. Automatic Approval MUST exist only inside the Benchmark.

**Rationale**: The Operator approves a specific change, not an intention. Binding Approval to an
immutable Proposal and re-checking it just before the send prevents the system from executing
something the Operator did not see, or something that stopped being true in between — the P3
family exists to prove this (R21–R23, R27, AD-19, AD-24).

### V. The Case Is the Source of Truth

The persisted Case MUST be the truth about a resolution; Production messages and sessions are
transport. Every mutation of an Order, a Case or its child records MUST go through the single
command path of the application layer. A state transition MUST commit its new state, its Timeline
event and its outbox entries together, in a short transaction that performs no external I/O.
Concurrency MUST be optimistic: a writer whose expected version, state or target no longer holds
MUST lose visibly, never silently. The Timeline MUST be append-only. Evidence, Diagnosis, Proposal,
Approval, Execution and Receipt MUST be separate, linked records. Terminal states MUST NOT reopen
implicitly — a new episode creates a related Case. Human waiting MUST be persisted state, never a
blocked job; an Approval produces new work through the outbox.

**Rationale**: Restarts, redelivery and late workers are normal, not exceptional. A single owner of
the truth, written through one path with compare-and-swap, is what lets every step re-read the
Case and refuse to act on a decision that has since changed (R8–R11, R28, AD-2–AD-4, AD-20).

### VI. Effects at Most Once

Internal work, the authorized execution and the business effect on the Partner MUST carry separate
identities, and the identity of the effect MUST NOT depend on the Proposal alone. The authorization
MUST be persisted before the effect is attempted. The Partner MUST deduplicate atomically on key
and payload: the same key with the same payload returns the original Receipt; the same key with an
incompatible payload is rejected. Only a valid Receipt counts as success. An uncertain outcome MUST
block every new send for that effect — including one from a new Proposal — until Reconciliation
settles it. A lease MUST carry owner and generation, so a late worker cannot overwrite a later
execution. Lost responses, repeated clicks, restarts, repeated commands and late workers MUST NOT
duplicate an effect, and the recovery suite MUST exercise each of them.

**Rationale**: The worst outcome for an operator is not a failed resend but a duplicated one sent
on stale context. Separate identities, persist-before-effect and "uncertain blocks everything"
make duplicate effects impossible by construction instead of unlikely by timing (R24–R29, AD-5,
AD-14, AD-21, AD-22).

### VII. Honest Outcomes, Errors as Values

Predictable failures — a rejected input, a validator verdict, a denied or conflicting command, a
provider failure, a partial run — MUST cross layer boundaries as explicit result values; exceptions
MUST stay at the infrastructure edge where they originate and MUST NOT be control flow across the
core. A refusal from the server MUST NEVER be presented as success, and a partial outcome MUST stay
partial. Observed fact MUST be distinguishable from diagnosis, and absence of information MUST be
distinguishable from a negative conclusion. Waiting, review and uncertainty MUST be reported as
distinct conditions. The Review Dossier MUST NOT contain a query or an Evidence that did not
happen. A late answer from the Agent MUST NOT change an Investigation that has already closed.

**Rationale**: When the system cannot decide safely, its value is the truth it hands the Operator.
Encoding failure as a value forces each layer to account for it, and keeping fact, diagnosis and
ignorance apart is what makes a Dossier actionable instead of plausible (R15, R30, R33–R34).

### VIII. Honest Measurement

The Agent's gain over Rules Mode is a hypothesis to be measured, not a target to be met. Rules and
Agent MUST use the same Tools and protections, and the baseline MUST NOT be weakened. Prompt, model,
baseline, policies, fixtures and evaluator MUST be frozen before the reserved test runs. Scoring
MUST consider Action and parameters, and MUST separate needed from unneeded review and a blocked
wrong Proposal from a wrong effect. Results — ties and losses included — MUST be published with
counts, denominators, dispersion, latency, cost and raw data; repetitions MUST NOT count as
independent cases. A recorded response (Replay) MUST NOT count as a real run. Tuning the solution
on test results turns that set into development data and a new reserved test becomes required.
Guarantees delivered by the platform (P3, recovery) MUST be reported as platform guarantees, never
as merit of the Agent. Preparation of reserved cases, the baseline and the evaluator review MUST be
held by different team members.

**Rationale**: A contest rewards claims; this project only makes claims it can reproduce. Freezing
the setup, sharing the protections and publishing every outcome is what keeps the Benchmark from
becoming a demo of a chosen result (R3, R6, R42–R46, AD-23).

### IX. Verifiable Increments

Every unit of work MUST deliver behavior that can be observed end to end and MUST carry the
automated test that demonstrates it. Work MUST NOT be divided by technical layer — no unit whose
deliverable is "the persistence for X", "the endpoint for Y" or "the screen for Z" in isolation.
The tracer path — an Order leaves the Simulator, becomes a Case and a validated Proposal, is
approved in the UI, is executed with Revalidation and a Receipt, and enters the reference
Benchmark run — MUST be the first end-to-end slice, and later slices extend it. When one unit
depends on another, the dependency MUST be declared explicitly.

**Rationale**: With a two-week build window, a layer that merges green but does nothing visible is
schedule risk disguised as progress. Slicing by observable behavior makes every milestone checkable
against the cut table of the initiative.

## Platform Constraints

These constraints are constitutional because the contest imposes them; they are not technology
preferences.

- The target platform MUST be InterSystems IRIS with AI Hub EAP build 154 (`%AI.Agent`,
  `%AI.ToolSet`, `%AI.Provider`), invoked from inside the Production. Build 162 MUST NOT be used.
- No EAP image, nor any image derived from one, MAY be pushed to any registry.
- All data MUST be synthetic and labeled as such in every Case and export. The system MUST NOT make
  clinical decisions.
- Secrets MUST enter only at runtime and MUST NOT appear in code, Timeline events, logs, exports or
  images. Without a valid key the application MUST start and report the unavailability.
- Only the demonstrated scope MAY be announced; an untested platform or provider MUST NOT be
  announced as validated.
- Every other technology choice — UI framework, build tooling, versions, persistence layout — MUST
  be made in the Plan and justified there against the principles above.

## Engineering Standards

Compliance is a review gate; each Plan MUST show how its approach satisfies them.

- **SOLID.** Design and refactor toward single responsibility, open/closed, Liskov substitution,
  interface segregation and dependency inversion. Deviations MUST be justified in the Plan.
- **Clean / Hexagonal Architecture.** Ports owned by the inner layers, adapters at the edge. This is
  the operational form of Principle I.
- **Test-Driven Development.** A failing automated test MUST exist before the code that makes it
  pass. `%UnitTest` covers the core; the Benchmark is the integration test; the quick validation is
  the smoke test.
- **Errors as Values.** Per Principle VII.
- **Separation of Concerns.** Each module MUST have one reason to change; business facts go to the
  Timeline, technical errors to the platform log.
- **YAGNI.** Abstractions and extension points MUST be introduced when a concrete second use
  appears, not in anticipation of one.
- **Contract-first HTTP, code-first internals.** The HTTP contracts in `contracts/` are normative.
  A divergence MUST become an explicit contract-change proposal, never a silent adjustment.
- **Reproducibility.** Another team member MUST be able to install and run the smoke test following
  only the README, with their own key. A fix that affects installation MUST trigger a new
  cross-install validation.

## Development Environment — iris-agentic-dev

- All interaction of developers and coding agents with the live IRIS instance during development
  MUST go through iris-agentic-dev (its MCP server or its CLI): compiling classes (`compile`),
  reading and writing class documents (`doc`), running ObjectScript (`exec`), running SQL (`query`)
  and running `%UnitTest` suites. Pasting code into an IRIS terminal or editing the database
  directly is not an accepted way to produce or verify work.
- A task that touches ObjectScript is done only when its classes compile and its tests pass on the
  live instance through iris-agentic-dev, and the Plan or research records that verification.
- Claims about platform behavior — AI Hub APIs, Production behavior, quirks of build 154 — MUST be
  verified against the live instance with iris-agentic-dev before a Plan relies on them; they MUST
  NOT be assumed from documentation alone.
- iris-agentic-dev is a development tool, never a runtime dependency. It MUST NOT be shipped in the
  image, required on the README install path, or exposed to the product Agent. In particular, the
  iris-agentic-dev AI Hub ToolSet (`contrib/aihub/IAD.ToolSet.xml`) MUST NOT be attached to Signal
  Noir's Agent: it carries write capabilities that would break Principle II.
- Its workspace configuration (`.iris-agentic-dev.toml`) holds credentials and MUST be git-ignored;
  the repository is public. Connection settings come from `IRIS_HOST`, `IRIS_WEB_PORT`,
  `IRIS_USERNAME`, `IRIS_PASSWORD` and `IRIS_NAMESPACE`.
- The official InterSystems skill pack (`iris-agentic-dev skill install`) is the reference for the
  ObjectScript and IRIS idioms used by coding agents.

## Workflow

Every change to product behavior MUST proceed in this order:

1. **Constitution** — read; any conflict with it blocks the work until the Constitution is amended
   or the work is redesigned.
2. **Spec** — describe the change in terms of user-observable behavior, free of implementation
   choices.
3. **Plan** — resolve the technology decisions the Spec omits, justified against the principles,
   and record what was verified on the live instance with iris-agentic-dev.
4. **Tasks** — decompose into verifiable increments per Principle IX, with dependencies explicit.
5. **Implementation** — build task by task, following TDD.
6. **Tests** — automated tests MUST pass on the live instance before merge and MUST cover the
   observable behavior each task delivers.
7. **Review** — the diff MUST be reviewed against this Constitution, the Spec, the Plan and the
   tests before it ships.

Calendar gate: no submission code MAY be written before 2026-10-26. Before that date only
contracts, specification, fixtures and the throwaway prototype are allowed, and the prototype MUST
NOT be copied into the submission.

## Governance

This Constitution supersedes ad-hoc practice. Amendments follow semantic versioning:

- **MAJOR**: A principle is removed, or its meaning is redefined incompatibly.
- **MINOR**: A new principle or section is added, or an existing one is materially expanded.
- **PATCH**: Wording is clarified or non-semantic refinements are made without changing what the
  principles require.

Every amendment MUST record its rationale in the Sync Impact Report at the top of this document and
MUST update dependent artifacts (templates, guides and documentation that reference the changed
rules) in the same change. Amendments require review by at least one other team member (Henry, José
Roberto, Henrique). Any permanent architectural change — a new layer, a new Action, a change in how
Approval or Execution works, a change of target platform build — obliges a review of this
Constitution, whether or not it ends in an amendment. Where the sources diverge, the 2026-10-19
decision notebook prevails over the 2026-10-18 PRD until the PRD is updated.

**Version**: 1.0.0 | **Ratified**: 2026-10-22 | **Last Amended**: 2026-10-22
