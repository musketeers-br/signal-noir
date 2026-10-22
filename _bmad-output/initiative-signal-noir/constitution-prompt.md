# Prompt para `/speckit-constitution` — Signal Noir

Cole o bloco abaixo como argumento de `/speckit-constitution`.

---

```text
Ratify the first Constitution of Signal Noir (version 1.0.0, ratified 2026-10-22), replacing the
template in .specify/memory/constitution.md. Write it in English. Use
/Users/henryhamon/workstation/sentai-task/.specify/memory/constitution.md as the model for tone and
structure: Sync Impact Report as an HTML comment at the top; a short product statement; numbered
Core Principles, each with normative MUST/MUST NOT rules and a **Rationale** paragraph; then
Engineering Standards, Development Environment, Workflow and Governance. Keep principles about
properties of the system, not about how they are built — except for the constraints listed under
"Platform Constraints", which are imposed by the contest and are therefore constitutional.

Sources to read before writing (they are the ground truth; do not invent rules they do not support):
- _bmad-output/initiative-signal-noir/initiative-signal-noir.md (R1–R50, Constraints, Boundaries)
- _bmad-output/initiative-signal-noir/architecture-signal-noir/architecture-signal-noir.md (AD-1–AD-28)
- _bmad-output/initiative-signal-noir/prd-signal-noir/prd-signal-noir.md (§3 Glossary) and addendum.md
- _bmad-output/initiative-signal-noir/reconcile-fontes-2026-10-20.md (the 19/10 notebook prevails)
- contracts/ (HTTP contracts are normative, AD-16)
Use the project's domain vocabulary (Order, Case, Proposal, Approval, Execution, Receipt, Evidence,
Validator, Review Dossier, Rules Mode, Benchmark, Partner, Simulator), with the PRD glossary as the
definition. Do not copy architecture details (class names, package names, HTTP paths) into the
principles; cite the governing AD numbers in the rationale instead.

## Product statement
Signal Noir turns an interoperability failure into a verifiable operational decision. When a
synthetic lab Order fails in an IRIS Production, the system opens a Case; an AI Hub Agent
investigates with read-only Tools and proposes an Action from a closed catalog; the application
validates it, asks for human Approval, revalidates, executes idempotently and confirms the outcome.
When there is no safe decision, the Operator receives a useful Review Dossier.

## Core Principles (write one section each)

I. Pure Core, Production as Shell — Domain rules (state machine, actor table, Validator,
   equivalence key, idempotency key, Partner-response classifier, closed vocabularies) live in a
   core with no I/O and no dependency on the Production, the API, the UI or the Simulator.
   Dependencies point inward. Other layers call the core and MUST NOT reimplement it. The Simulator
   is an external system reachable only over its HTTP contract. (AD-1, AD-13)

II. Closed Action Catalog and a Read-Only Agent — The system executes only the declared Actions
   (RETRY, APPLY_APPROVED_MAPPING, HOLD, REQUEST_REVIEW); new Actions enter only through the normal
   change process. The Agent has read-only Tools, never writes, and its budget and context are
   enforced server-side. Order contents, Partner responses and logs are data, never instructions;
   embedded-instruction attempts are recorded and blocked. No code supplied at runtime is executed.
   APPLY_APPROVED_MAPPING applies only an existing, versioned mapping. (R12–R14, R19–R20, AD-10, AD-11)

III. One Validator, Blind to Origin — Every Proposal and every Case closure — from the Agent, Rules
   Mode, the Operator or the Benchmark — passes through the same deterministic Validator. No origin
   gets a shortcut, and no free editing of payloads exists. (R18, R31, AD-9, AD-12)

IV. Human Authority over Effects — Effects that require Approval do not happen without a recorded
   Approval of an immutable Proposal (Action, parameters, transformed payload, relevant versions).
   An Approval has a deadline and is revalidated immediately before the send; an expired or
   materially incompatible Approval never executes. Concurrent Approvals yield one effective
   authorization. Automatic Approval exists only inside the Benchmark. (R21–R23, R27, AD-19, AD-24)

V. The Case Is the Source of Truth — The persisted Case is the truth about a resolution; Production
   messages are transport. Every mutation goes through a single command path; state, timeline event
   and outbox commit together in a short transaction with no external I/O; concurrency is optimistic
   (compare-and-swap) and a stale writer loses visibly. The Timeline is append-only and terminal
   states never reopen implicitly. Human waiting is persisted, never a blocked job. (R8–R11, R28,
   AD-2–AD-4, AD-20)

VI. Effects at Most Once — Internal work, the authorized execution and the business effect have
   separate identities. Authorization is persisted before the effect. An uncertain outcome blocks
   every new send — including one from a new Proposal — until Reconciliation. Lost responses,
   repeated clicks, restarts, repeated commands and late workers MUST NOT duplicate an effect.
   (R24–R29, AD-5, AD-14, AD-21, AD-22)

VII. Honest Outcomes, Errors as Values — Predictable failures cross layers as explicit values; a
   server refusal is never shown as success; partial outcomes stay partial. Observed fact and
   diagnosis are distinguishable; absence of information is distinct from a negative conclusion.
   The Review Dossier never invents a query or an Evidence. A late Agent answer never changes a
   closed Investigation. (R15, R30, R33–R34)

VIII. Honest Measurement — The Agent's gain over Rules Mode is a measured hypothesis, not a target.
   Rules and Agent share the same Tools and protections; the baseline is never weakened; prompt,
   model, baseline, policies, fixtures and evaluator are frozen before the test; ties and losses
   are published with raw data; Replay never counts as a real run; tuning on the test set turns it
   into development data. Platform guarantees (P3, recovery) are never credited to the Agent.
   (R3, R6, R42–R46, AD-23)

IX. Verifiable Increments — Each unit of work delivers behavior observable end to end (tracer
   path: Simulator → Case and validated Proposal → UI Approval → Execution and Receipt → Benchmark)
   and carries the automated test that proves it. No slicing by technical layer. Dependencies
   between units are declared explicitly.

## Platform Constraints (constitutional because the contest imposes them)
- Target platform: InterSystems IRIS with AI Hub EAP build 154 (%AI.Agent, %AI.ToolSet,
  %AI.Provider). Build 162 is not accepted. No EAP image, or derivative, is pushed to any registry.
- All data is synthetic and labeled as such; no clinical decisions.
- Secrets enter only at runtime (.env) and never appear in code, events, logs, exports or images;
  without a valid key the app starts and reports unavailability.
- Every other technology choice (UI framework, build tooling, versions) belongs to the Plan and
  MUST be justified against the principles there.

## Engineering Standards
SOLID; Clean/Hexagonal Architecture as the operational form of Principle I; TDD (failing test
first; %UnitTest covers the core); Errors as Values; Separation of Concerns; YAGNI; HTTP
contract-first and internal code-first (contracts change by explicit proposal, never silently);
Reproducibility: another team member installs and runs the smoke test following only the README.

## Development Environment — iris-agentic-dev (MANDATORY)
Write this as its own section with normative rules:
- All interaction of coding agents and developers with the live IRIS instance during development
  MUST go through iris-agentic-dev (MCP server or CLI): compiling classes (`compile`), loading and
  reading class documents (`doc`), running ObjectScript (`exec`), SQL (`query`) and %UnitTest
  suites. Ad-hoc alternatives (pasting into the IRIS terminal, editing the database directly) are
  not an accepted way to produce or verify work.
- A task touching ObjectScript is done only when its classes compile and its tests pass on the live
  instance through iris-agentic-dev, and the Plan/research cites that verification. Claims about
  platform behavior (AI Hub APIs, Production behavior, build-154 quirks) MUST be verified against
  the live instance with iris-agentic-dev, not assumed from documentation.
- iris-agentic-dev is a development tool, never a runtime dependency: it MUST NOT be shipped in the
  image, required by the README install path, or exposed to the product Agent. In particular, the
  IAD AI Hub ToolSet (contrib/aihub/IAD.ToolSet.xml) MUST NOT be attached to Signal Noir's Agent —
  it carries write capabilities that would break Principle II.
- Its workspace config (.iris-agentic-dev.toml) holds credentials and MUST be git-ignored; the
  repository is public. Connection settings come from IRIS_HOST, IRIS_WEB_PORT, IRIS_USERNAME,
  IRIS_PASSWORD and IRIS_NAMESPACE.
- The official InterSystems skill pack (`iris-agentic-dev skill install`) is the reference for
  ObjectScript/IRIS idioms used by coding agents.

## Workflow
Constitution → Spec (user-observable behavior, no implementation) → Plan (technology decisions,
justified; verification via iris-agentic-dev recorded) → Tasks (verifiable increments, explicit
dependencies) → Implementation (TDD) → Tests (must pass on the live instance before merge) →
Review (diff against Constitution, Spec, Plan and tests). Add the calendar gate: no submission
code before 2026-10-26; before that date only contracts, specification, fixtures and the throwaway
prototype (which is never copied into the submission).

## Governance
Same semantic-versioning rules as the reference (MAJOR/MINOR/PATCH). Every amendment records its
rationale in the Sync Impact Report and updates dependent templates and docs in the same change.
A permanent architectural change (a new layer, a new Action, a change in how Approval or Execution
work, a change of target platform build) obliges a Constitution review. Amendments require review
by at least one other team member (Henry, José Roberto, Henrique). Where sources diverge, the
19/10 decision notebook prevails over the 18/10 PRD until the PRD is updated.

After writing, check .specify/templates/plan-template.md, spec-template.md and tasks-template.md
for consistency (the plan template's Constitution Check must list these principles and the
iris-agentic-dev verification gate), add `.iris-agentic-dev.toml` to .gitignore, and report the
result in the Sync Impact Report.
```
