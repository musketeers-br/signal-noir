# Feature Specification: Benchmark and Reference Run

**Feature Branch**: `010-benchmark-and-reference-run`

**Created**: 2026-10-31

**Status**: Draft

**Input**: User description: the full text of `docs/specify-prompts/010-benchmark-and-reference-run.txt` (the
reproducible Benchmark and the reference run), read under the Constitution and the rules of
`docs/specify-prompts/PARALELISMO.md`.

## User Scenarios & Testing *(mandatory)*

A Benchmark is the instrument that tests the thesis of Signal Noir: whether an Agent that reads the same
Tools and faces the same protections as a deterministic Rules Mode resolves failed Orders better. Its users
are the team that runs it, the reviewer who checks that it was not bent in the Agent's favour, and a juror
who reproduces it with their own key. Every story below is observable from a report or from a Case, and
each can be demonstrated without the stories that follow it.

### User Story 1 - A run in one mode over a scenario set (Priority: P1)

A team member starts a BenchmarkRun in one mode (rules or agent) over a set of scenarios. The Simulator
creates the scenario instances tagged with the run, every Case that opens from them carries the run's mode,
the run advances to a final state, and a report is available. An Order without a valid run keeps working as
before: the Agent is its mode and no benchmark flag is set.

**Why this priority**: Nothing else exists without a run that opens real Cases in a known mode. It also
protects the normal product: a Case outside a run must never be treated as a benchmark Case.

**Independent Test**: Create a run in rules mode over a few variants and read its progress until it ends;
then submit an Order with no run and with an unknown run, and read the mode and flags of their Cases.

**Acceptance Scenarios**:

1. **Given** a created run in rules mode over a set of variants, **When** it runs, **Then** each Case opened
   from its scenarios has the run's mode and benchmark flags, and the run reports the Cases planned, opened
   and ended until it is completed.
2. **Given** an Order with no run identifier, **When** its Case opens, **Then** its mode is agent and no
   benchmark flag is set.
3. **Given** an Order whose run identifier names no run, or a run that is not running, **When** its Case
   opens, **Then** the Case is treated exactly as in scenario 2.
4. **Given** the same run request repeated with the same seed, **When** both finish, **Then** each (variant,
   repetition) saw the same sequence of Simulator responses.
5. **Given** a run is running, **When** another run is requested, **Then** the request is refused with a
   visible conflict and the first run is unaffected.

---

### User Story 2 - Outcomes classified honestly (Priority: P1)

For each Case of a run, the evaluator compares what the system did with the answer key declared for that
variant and assigns exactly one of four outcomes: correct, safe review, unnecessary review or incorrect. The
comparison uses the Action and its parameters, and keeps apart a wrong Proposal that the Validator blocked
from a wrong effect that was executed.

**Why this priority**: The classification is the measurement. A score that treats a blocked mistake like an
executed one, or any review like a good outcome, would flatter the Agent.

**Independent Test**: Run Cases whose final states are known (a right Mapping, a wrong Mapping blocked by
the Validator, a needed review, an unneeded review) and check the outcome and the counts of each.

**Acceptance Scenarios**:

1. **Given** a variant whose answer key accepts one Action with given parameters, **When** the Case ends with
   that Action and those parameters, **Then** the outcome is correct.
2. **Given** the same variant, **When** the Case ends with the right Action and wrong parameters (for example
   the serum Mapping for a plasma Order), **Then** the outcome is not correct.
3. **Given** a variant whose answer key says review is the right answer, **When** the Case ends in review,
   **Then** the outcome is safe review.
4. **Given** a variant whose answer key accepts an Action, **When** the Case ends in review, **Then** the
   outcome is unnecessary review, and it is counted apart from safe review.
5. **Given** a Proposal that is wrong and that the Validator blocks, **When** the Case is scored, **Then** the
   report counts it as a proposer error caught by the protection, separately from a wrong effect that was
   sent to the Partner; the two are never added into one number.
6. **Given** a Case that did not reach any decision because the provider was unavailable or the run failed,
   **When** the report is built, **Then** it is listed apart, not scored as a decision, and the report shows
   the denominators with and without it.

---

### User Story 3 - Automatic Approval only inside a run (Priority: P1)

Inside a BenchmarkRun, the process that opens and drives the Case gives the Approval the Operator would give,
so a run can complete without a person. That Approval carries the actor `benchmark`, is labelled automatic,
names its run, and exists nowhere else. The runner that observes the run never approves.

**Why this priority**: It is the one place where Principle IV is relaxed, and only for measurement. If it
leaks outside a run, the product acts without a human.

**Independent Test**: Try the `benchmark` actor on a Case that belongs to a run and on a Case that does not;
check the Approval record and the runner's own actions.

**Acceptance Scenarios**:

1. **Given** a Case of a run with an accepted Proposal that needs Approval, **When** the Case reaches
   approval, **Then** an Approval by `benchmark` is recorded, labelled automatic, with the run identifier.
2. **Given** a Case that belongs to no run, **When** an Approval by `benchmark` is attempted through any
   path, **Then** it is refused and nothing is recorded as approved.
3. **Given** a running run, **When** its runner observes the Cases, **Then** it issues no Approval and
   changes no Case.
4. **Given** an automatic Approval, **When** the Execution is about to send, **Then** the same revalidation
   of the Approval and of the preconditions applies as for a human Approval.
5. **Given** a Case of a run whose Proposal does not need Approval (a hold), **When** it is accepted,
   **Then** no Approval is recorded.

---

### User Story 4 - A two-part report and a side-by-side comparison (Priority: P1)

When a run ends, its report has two parts that are never mixed. The first, agent decision, scores Cases by
core family and by mode. The second, platform guarantees, says pass or fail for what the platform promises
whoever proposes. For two runs over the same scenarios, one in rules mode and one in agent mode, a
comparative report places them side by side.

**Why this priority**: The report is the product of the feature, and the separation is what keeps platform
merit from being claimed as Agent merit.

**Independent Test**: Run rules and agent over the same scenario set, then read each report and the
comparison.

**Acceptance Scenarios**:

1. **Given** a completed run, **When** its report is read, **Then** the agent decision part gives, for each
   core family (P5 and P8b) and each mode, the counts and proportions of correct, safe review, unnecessary
   review and incorrect, the p50 and p95 latency, the tool calls per Case and the estimated cost per Case.
2. **Given** clean scenarios in the run, **When** the report is read, **Then** they appear as controls and
   not in the score of a family.
3. **Given** a completed run, **When** its report is read, **Then** the platform guarantees part gives pass
   or fail for P3, idempotency, timeout, restart, repeated approval and late worker, each with its evidence
   (for example duplicate Receipts, invalid Actions executed, executions with a stale precondition), and no
   comparative score.
4. **Given** two completed runs, one in rules mode and one in agent mode, over the same scenario set,
   **When** the comparative report is read, **Then** the two are placed side by side by mode.
5. **Given** runs over different scenario sets, or a run in replay mode, **When** a comparison is requested,
   **Then** it is refused with the reason.
6. **Given** a run that has not ended, **When** its report is requested, **Then** the answer says it is not
   ready, and no partial report is presented as final.
7. **Given** the P9 family is not part of the run, **When** the report is read, **Then** P9 does not appear;
   if it is part of the run, it appears as its own family and never inside P5 or P8b.

---

### User Story 5 - A frozen setup, separate sets and independent hands (Priority: P2)

Before the reserved test runs, the prompt, model, rules baseline, policies, fixtures and evaluator are frozen
in one record. Tuning and test variants are kept apart and only the test variants count in a result. The
person who wrote the rules baseline did not prepare the reserved cases or the answer key, and the report says
who held each role and how the baseline and the evaluator were reviewed: by another member, by their author,
or by an automated reviewer (Constitution 2.0.0, Principle VIII).

**Why this priority**: Without it the numbers can be right and still not mean anything: a setup tuned on the
test, or a baseline weakened or written by the person who wrote the key, cannot support the thesis.

**Independent Test**: Freeze a setup, change one frozen input, run, and read the run's status and report;
read the report metadata for a run whose answer key and baseline are held by one person, and for one whose
baseline was reviewed by its own author.

**Acceptance Scenarios**:

1. **Given** a freeze record that names the prompt, model, baseline, policies, fixtures and evaluator,
   **When** a reference run starts, **Then** the run records the freeze it ran under, and the report shows it.
2. **Given** a frozen input that differs from the freeze record when the run starts, **When** the run is
   created for the reference purpose, **Then** it is marked development, it cannot be published as the
   reference result, and the report says which input differs.
3. **Given** test results were used to adjust the prompt, the rules or the policies, **When** the team
   declares the set as used, **Then** that set is marked as development data and a new reserved test is
   required before a reference result can be published.
4. **Given** a report, **When** its metadata is read, **Then** it names who prepared the reserved cases and
   the answer key, who wrote the rules baseline, and who reviewed the baseline and the evaluator, with the
   commit and date of the review and whether it was done by another member, by its author or by an
   automated reviewer.
5. **Given** the same person preparing the answer key and writing the baseline of the same family, **When**
   the reference run is requested, **Then** it is refused or marked development, with the reason.
6. **Given** the tuning set and the test set of a family, **When** results are read, **Then** only the test
   set counts as a result, and tuning results appear separately, labelled development.
7. **Given** a review of the baseline or of the evaluator that is missing, incomplete or done by its author,
   **When** the reference run is requested, **Then** it is not marked development for that reason, and the
   report shows the status of that review.

---

### User Story 6 - The reference run (Priority: P2)

The team publishes a reference run with a fixed provider and model: families P5 and P8b, five test variants
per family, three repetitions of each, which is thirty Agent investigations, plus the clean controls and the
case that ends in a Dossier. Each metric is a range over the repetitions, and the raw data is published well
enough for anyone to recompute the report.

**Why this priority**: It is the published claim of the project, and a juror reproduces it.

**Independent Test**: Run the reference purpose and count the investigations; recompute the report from the
raw data and compare.

**Acceptance Scenarios**:

1. **Given** a reference run with five test variants in each of P5 and P8b and three repetitions, **When** it
   ends, **Then** thirty Agent investigations were run, plus the clean controls and the Dossier case.
2. **Given** the report of the reference run, **When** a metric is read, **Then** it is a range (lowest and
   highest over the three repetitions), with its count and denominator.
3. **Given** the three repetitions of one variant, **When** the denominators are read, **Then** the variant
   counts once as a case; the repetitions only supply the range.
4. **Given** the published raw data, **When** someone recalculates the counts, proportions, latency and cost,
   **Then** they obtain the numbers of the report.
5. **Given** a juror who runs the same scenarios with another provider or model, **When** they read their
   report, **Then** it says that the provider or model differs from the reference.
6. **Given** a reference run that failed before ending, **When** results are looked for, **Then** none is
   offered as a reference result.

---

### User Story 7 - A recorded response never counts as a real run (Priority: P2)

A response that was recorded and is played back (Replay) exists only to reproduce the reference result for
the quick validation and as the fallback of the demonstration video. A Replay Case is labelled and left out
of every metric.

**Why this priority**: It keeps the demonstration honest, and it is a rule of the Constitution.

**Independent Test**: Run a replay Case next to real ones and read the report and the Case.

**Acceptance Scenarios**:

1. **Given** a Case played from a recorded response, **When** it is shown anywhere, **Then** it is labelled
   as replay.
2. **Given** a report over real and replay Cases, **When** the numbers are read, **Then** the replay Cases
   are in no count, no denominator, no latency and no cost.
3. **Given** a request to compare a replay run with other runs, **When** it is made, **Then** it is refused.
4. **Given** the application has an interface, **When** a user looks for a way to start a replay run there,
   **Then** there is none.

---

### User Story 8 - Quick validation in three minutes (Priority: P2)

One command runs three reference Cases (a clean one, a P5 or P8b one, and one that ends in a Dossier),
compares each outcome with the reference result that was recorded, and says for each "matches the reference"
or "diverged", with the reason. It finishes within three minutes. If P9 is included, it replaces the clean
case.

**Why this priority**: It is how a juror, with their own key, checks that the installation works and that
their result is in line with the published one, in a time they will accept.

**Independent Test**: Run the command on a clean installation and time it; run it again with a different
model and read the divergence reasons.

**Acceptance Scenarios**:

1. **Given** the recorded reference and an installed application, **When** the command runs, **Then** it
   reports three Cases, each as matches or diverged, and finishes in at most three minutes.
2. **Given** a Case whose outcome differs from the reference, **When** the result is read, **Then** the
   reason is stated (for example a different Action, a different final state, or a provider or model that
   differs from the reference).
3. **Given** the three Cases, **When** they are read, **Then** one is a clean control, one is a P5 or P8b
   Case and one ends in a Dossier.
4. **Given** the quick validation, **When** it runs, **Then** it creates a run of the quick-validation
   purpose, which is never mixed into the reference or benchmark results.

---

### Edge Cases

- A run requests a variant or family that does not exist, or an empty scenario set: refused before anything
  starts, with the reason.
- A reference run that asks for tuning variants, or a mix of tuning and test variants: refused or marked
  development; a reference result comes from test variants only.
- The provider becomes unavailable during an agent run: the affected Cases are listed as not decided, not
  scored, and the run is flagged; they are never turned into "safe review".
- A run fails or is abandoned halfway: its state is failed with a reason, and no partial result is published
  as a reference.
- Fewer than k repetitions complete for a variant: the range says how many repetitions it covers; it is not
  presented as a three-run range.
- Repetitions share a variant: a variant's repetitions never add to the number of independent cases.
- A Case of a run ends in review because the Validator or a precondition stopped it: it is scored against the
  answer key like any other review (safe or unnecessary), and the reason is kept.
- A wrong effect and a wrong blocked Proposal for the same Case (a blocked Proposal followed by another that
  is executed): the Case is scored by its final effect, and the blocked Proposal is counted as a proposer
  error.
- The same Order is delivered twice inside a run: only one effect is allowed; the duplicate shows in the
  platform guarantees, not in the agent score.
- The Operator acts on a Case of a run while it runs: the Case is marked as touched by a person and is out of
  the agent decision metrics.
- Two runs are started at once: the second is refused while the first runs.
- A frozen input changes between the creation of the run and its start: the run is marked development.
- An evaluator or rule changed after the test results were seen: the set is development data, and the report
  of any later run over it says so.

## Requirements *(mandatory)*

### Functional Requirements

**Runs and modes**

- **FR-001**: The system MUST let a team member create a BenchmarkRun with a run identifier, a mode (rules,
  agent or replay), a purpose (benchmark, reference or quick validation), a provider and model (ignored in
  rules mode), a scenario selection, a number of repetitions, a base seed, and the policy and Mapping
  versions to use (the versions in force when omitted), and MUST start it.
- **FR-002**: A run MUST move through created, running and then completed or failed, and MUST report its
  progress as Cases planned, opened and ended (terminal or in review).
- **FR-003**: The Order envelope MUST carry only the run identifier. When a Case opens, the application MUST
  copy the run's mode and flags to it. Without a valid run identifier (absent, unknown, or naming a run that
  is not running), the Case MUST have mode agent and no benchmark flag.
- **FR-004**: Each (variant, repetition) MUST derive its own seed deterministically from the base seed, and
  the same seed MUST produce the same sequence of Simulator responses.
- **FR-005**: While a run is running, a new run MUST be refused with a visible conflict.
- **FR-006**: A run MUST validate its Cases against the policy and Mapping versions it pinned, from the start
  of the Case to its end.
- **FR-007**: The Benchmark runner MUST create the scenario instances in the Simulator through its contract,
  tagged with the run identifier, and MUST only observe: it MUST NOT approve, change a Case or write a
  Proposal.

**Automatic Approval**

- **FR-008**: Automatic Approval MUST exist only for Cases that belong to a running BenchmarkRun. It MUST be
  emitted by the process that opens and drives the Case, MUST carry the actor `benchmark`, MUST be labelled
  automatic, and MUST name the run.
- **FR-009**: An Approval by the actor `benchmark` for a Case outside a run MUST be refused through every
  path, and nothing MUST be recorded as approved.
- **FR-010**: An automatic Approval MUST be subject to the same Validator, the same deadline and the same
  revalidation before the effect as a human Approval.

**Rules baseline**

- **FR-011**: Rules and Agent MUST use the same Tools, the same Evidence, the same Validator and the same
  protections and budgets.
- **FR-012**: The rules baseline MUST be the strongest deterministic baseline the team can write. Its rules
  for each family MUST be documented, versioned and published together with the answer key of that family.
- **FR-013**: For each family, the baseline MUST be written by a team member who did not prepare that
  family's reserved cases or answer key and did not read them before the freeze. Its review MAY be done by
  any team member, its author included, or by an automated reviewer; it MUST be recorded with its author,
  reviewer, commit and date, and it MUST NOT block the freeze or the run (Constitution 2.0.0, Principle VIII).

**Answer key and scoring**

- **FR-014**: Each variant MUST declare its answer key before it runs: the acceptable Actions with their
  parameters and the acceptable final states, including the cases where review is the right answer.
- **FR-015**: The evaluator MUST classify every scored Case into exactly one of: correct, safe review,
  unnecessary review, incorrect. The classification MUST consider the Action and its parameters.
- **FR-016**: The evaluator MUST keep apart a wrong Proposal blocked by the Validator (a proposer error and a
  success of the protection) from a wrong effect executed, and a needed review from an unneeded one.
- **FR-017**: A Case that reached no decision for a reason outside the decision (provider unavailable, run
  failed) MUST be reported apart, MUST NOT be scored as a decision, and MUST be flagged on the run.
- **FR-018**: A Case that a person acted on during the run MUST be marked and left out of the agent decision
  metrics.

**Reports**

- **FR-019**: A completed run MUST have a report in two parts. The agent decision part MUST give, for each
  core family (P5 and P8b) and each mode, the counts and proportions of each outcome, the p50 and p95
  latency, the tool calls per Case and the estimated cost per Case. Clean scenarios MUST appear as controls.
  P9 MUST appear as its own family only if it is part of the run.
- **FR-020**: The platform guarantees part MUST give pass or fail for P3, idempotency, timeout, restart,
  repeated approval and late worker, each with its evidence, and MUST NOT give a comparative score.
- **FR-021**: The system MUST produce a comparative report for two or more completed runs over the same
  scenario set, side by side by mode, and MUST refuse runs over different sets and runs in replay mode.
- **FR-022**: A report MUST include the counts, the denominators, the dispersion over the repetitions, the
  latency, the cost, and the per-Case raw data enough to recalculate every number in it.
- **FR-023**: A report MUST state its provider and model, the policy, Mapping, prompt, baseline and
  evaluator versions, the variant set (tuning or test), the purpose, the freeze it ran under and the
  independence metadata. It MUST warn when the provider or model differs from the reference run.
- **FR-024**: A report for a run that has not ended MUST NOT be presented as final.

**Frozen setup and independence**

- **FR-025**: Tuning variants and test variants MUST be kept apart, and only test variants MUST count in a
  result. Tuning results MUST appear separately, labelled development.
- **FR-026**: Before the reserved test, the prompt, model, baseline, policies, fixtures and evaluator MUST be
  frozen in one record, and a run for the reference purpose MUST record the freeze it ran under.
- **FR-027**: A run whose frozen inputs differ from the freeze record, or over a set whose results were used
  to adjust the solution, MUST be marked development, MUST NOT be publishable as the reference result, and
  its report MUST say why. A new reserved test MUST then be required.
- **FR-028**: Repetitions MUST NOT count as independent cases. A variant counts once in every denominator;
  the repetitions supply only the range.
- **FR-029**: The preparation of the reserved cases and the answer key and the writing of the rules baseline
  MUST be held by different team members. The report metadata MUST state who held each role and how the
  baseline and the evaluator were reviewed: by another member, by their author (self), by an automated
  reviewer, incomplete or missing. A run that cannot show the separation of key and baseline MUST NOT be
  published as the reference; the status of a review is shown and never prevents publication.

**Reference run, Replay and quick validation**

- **FR-030**: The reference run MUST cover P5 and P8b with five test variants per family and three
  repetitions (thirty Agent investigations), plus the clean controls and the Dossier case, with a provider and
  model fixed, and MUST report each metric as a range over the repetitions.
- **FR-031**: A Replay Case MUST be labelled as replay everywhere it is shown, MUST be excluded from every
  metric, and MUST NOT be reachable through a replay mode in the interface.
- **FR-032**: Replay MUST exist only to record and reproduce the reference result for the quick validation
  and as the fallback of the demonstration video.
- **FR-033**: One command MUST run three reference Cases (one clean, one P5 or P8b, one that ends in a
  Dossier; P9 replaces the clean one if included), MUST finish within three minutes, and MUST report for each
  Case "matches the reference" or "diverged" with the reason.
- **FR-034**: A quick validation run MUST have its own purpose and MUST NOT be mixed into benchmark or
  reference results.
- **FR-035**: All data in runs, Cases and reports MUST be synthetic and MUST be labelled so, and no secret
  MUST appear in any report or raw data.

### Key Entities

- **BenchmarkRun**: one execution over a scenario selection in one mode, with a purpose, a provider and
  model, a number of repetitions, a base seed, pinned policy and Mapping versions, a status and a progress.
- **Scenario selection**: a family and, optionally, explicit variants and a variant set (tuning or test).
- **Answer key**: for a variant, the acceptable Actions with parameters and the acceptable final states,
  declared before the run and held by a team member other than the baseline's author.
- **Outcome**: the classification of a scored Case: correct, safe review, unnecessary review or incorrect;
  with the separate counts of a blocked wrong Proposal and of a wrong effect.
- **Freeze record**: the single record of the prompt, model, baseline, policies, fixtures and evaluator fixed
  before the reserved test.
- **Review record**: the review of the baseline and of the evaluator, with its author, reviewer, commit and
  date, and whether an automated reviewer did it.
- **Report**: the agent decision part and the platform guarantees part of one run, with its metadata and raw
  data; and the comparative report over runs.
- **Reference result**: the recorded outcome of the reference run's cases, against which the quick
  validation compares.
- **Replay Case**: a Case played from a recorded response; labelled and outside every metric.
- **Benchmark Approval**: the automatic Approval, actor `benchmark`, labelled automatic and bound to a run.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For one scenario set, a rules run and an agent run each produce a report, and the comparative
  report shows both side by side, with no manual step between the runs and the comparison.
- **SC-002**: A reference run covers exactly 5 variants × 2 families × 3 repetitions = 30 Agent
  investigations, plus the controls and the Dossier case, and every metric of the report is a range over the
  3 repetitions.
- **SC-003**: Someone who did not run the benchmark recomputes every count, proportion, latency and cost of
  the report from the published raw data and obtains 100% of the published numbers.
- **SC-004**: Across all reports, 0 Replay Cases and 0 repetitions counted as independent cases appear in a
  denominator.
- **SC-005**: 100% of attempts to approve as `benchmark` outside a run are refused, and 100% of the Approvals
  inside a run are labelled automatic and name their run.
- **SC-006**: The quick validation finishes in at most 3 minutes and states, for each of its 3 Cases,
  "matches the reference" or "diverged" with a reason.
- **SC-007**: 100% of runs whose frozen inputs differ from the freeze record, or whose set was used for
  tuning, are marked development and cannot be published as the reference result.
- **SC-008**: In every report, wrong Proposals blocked by the Validator and wrong effects executed are
  separate counts, needed and unneeded reviews are separate counts, and the four outcome categories add up to
  the number of scored Cases.
- **SC-009**: In every report, the platform guarantees part has no comparative score and no Agent-merit
  figure, and the agent decision part contains no figure that a guarantee of the platform produced.
- **SC-010**: The report of a run whose provider or model differs from the reference says so in 100% of
  cases.

## Assumptions

- The product API contract already names this feature's surface (benchmark runs, their reports, and the
  comparative report), and it is frozen: nothing here adds a field, state, Action or error code. A need the
  contract does not meet (a freeze record, the review record, the independence metadata, a way to declare a
  set as used) is recorded as a contract change before it is built.
- A comparison of rules and agent is two runs read together (the open question API-Q1 of the contract is
  taken in its proposed form). The "single command" of the README creates the two runs and reads the
  comparison.
- A valid run identifier is one that names a run in the running state. A second run cannot start while one is
  running (the open question API-Q10 is taken in its proposed form: refuse).
- P9 is not part of the first reference run: it is conditional (spec 011). If it is included, it is its own
  family and it replaces the clean Case in the quick validation.
- The rules baseline is the existing deterministic proposer, improved by its author before the reference run.
  This feature does not write it; it requires it to be published, versioned, reviewed (by any member or an
  automated reviewer, the review shown in the report) and frozen. The synonyms of reference data in the baseline's Mapping rule are a dependency of that work.
- The roles of the independence rule follow `docs/specify-prompts/PARALELISMO.md`: the reserved cases and the
  answer key for P5 and P8b are prepared by Henrique, the rules baseline is written by Henry, and the review
  of the baseline and of the evaluator is planned for José in the last wave. Under Constitution 2.0.0 the
  review does not block the freeze or the run; whoever does it is recorded with its commit and date.
  Henry, author of the Agent, does not see the reserved variants before the freeze.
- Latency is measured from the Exception to the validated Proposal, as the Case already records it. Cost is
  the estimate the Agent records per Case, and is zero in rules mode.
- The Simulator provides tuning and test variants for P5 and P8, at least five test variants per family, with
  at least one Partner and one wording pattern absent from the tuning set, plus a clean family and a scenario
  that ends in a Dossier. This feature consumes them and does not change them.
- The recorded reference result for the quick validation is produced by the reference run and stored with
  the published report. The recording is a Replay in the sense of FR-031: it never counts as a real run.
- The Agent cannot be run without a configured provider; a run in agent mode without one is refused at
  creation, not started and left half-done.
- The reference run must exist before the functional freeze of 2026-11-05. The order is: baseline and
  evaluator ready, one freeze commit, reference run, report with the independence metadata. A review done
  before the report is built appears in it; a review never holds back the freeze or the run.
- Out of scope: the Simulator implementation, the Agent implementation, the console, the submission
  packaging.
