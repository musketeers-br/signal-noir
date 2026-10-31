# Feature Specification: Case Precedents (Vector Search)

**Feature Branch**: `015-case-precedents`

**Created**: 2026-10-31

**Status**: Draft

**Input**: User request to add vector search (RAG) to the project. Plan and rationale:
[`docs/planning/2026-10-31-status-prazo-e-vector-search.md`](../../docs/planning/2026-10-31-status-prazo-e-vector-search.md),
section 5. Full description: `docs/specify-prompts/015-case-precedents.txt`.

## Context

Every closed Case is a small lesson: what failed, which Action was chosen, and how it ended. Today
that lesson is lost to the next Operator who meets a similar failure. This feature keeps the closed
Cases as **precedents** and, when the Operator looks at a Case, shows the most similar ones already
resolved: what failed, which Action settled it, and the outcome. The similarity is computed with
IRIS vector search over a short description of each Case.

Precedents are **information for the Operator, not Evidence and not a decision**. They never enter the
Validator, never count towards the minimum Evidence of a Proposal, never become a claim of a
Diagnosis, and never fill in a resolution. Approval, execution and the closed Action catalog stay
exactly as they are (Constitution II, III, IV, VII).

The feature is useful on its own for the Operator (stories 1 to 4). A second, optional use lets the
Agent look up precedents as a read-only Tool (story 6); it is off by default and off in the frozen
reference run, so the Benchmark stays honest (Constitution VIII).

All data is synthetic and labelled so. UI copy is English.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See similar Cases already resolved (Priority: P1)

An Operator opens a Case, most often one in `ReviewRequired`, and sees a section "Similar resolved
Cases". It lists up to five precedents ordered by similarity. Each shows the Case and Order
identifiers, partner, how it failed, the Action that settled it (or that it was cancelled), the final
state, how long it took, a similarity score, and a link to that Case. The section says plainly that it
is a similarity search over earlier Cases, not Evidence about this one.

**Why this priority**: It is the visible value of the feature. Without it nothing else matters.

**Independent Test**: Close a set of Cases from known families, open a new Case of one family, and
check that the precedents listed are the closed Cases of the same family, closest first, with their
Action and outcome.

**Acceptance Scenarios**:

1. **Given** closed Cases of several failure families, **When** the Operator opens a new Case of one
   family, **Then** the top precedents are closed Cases of that family, ordered by similarity, and
   none of them is the open Case itself.
2. **Given** a precedent shown, **When** the Operator follows its link, **Then** the console opens that
   Case.
3. **Given** a Case in `ReviewRequired`, **When** its Dossier is shown, **Then** the precedents are in
   the Dossier next to the next-step box, not in the list of Evidence.
4. **Given** any precedent, **When** shown, **Then** it carries the `SYNTHETIC` label, and `REPLAY` when
   it came from a replay (see story 2 on whether those are kept).
5. **Given** a precedent that ended `Failed` or `Cancelled`, **When** shown, **Then** its final state is
   visible and is not styled as a success.

---

### User Story 2 - Closed Cases become precedents by themselves (Priority: P1)

When a Case reaches a final state (`Resolved`, `ResolvedByPriorReceipt`, `Cancelled` or `Failed`), it is
added to the precedents once, without anyone doing anything. What is kept is a short description built
only from structured facts of the Case: partner, exam code, exception class, the Action and its
outcome, and the final state. Free text from the Order, from the partner or from the Agent is **never**
part of it. Cases from the Benchmark and from Replay are not added by default, so measurements and
demos do not teach the live system.

**Why this priority**: Without a stream of precedents there is nothing to search.

**Independent Test**: Close one Case of each final state, a Benchmark Case and a Replay Case, and check
which ones appear as precedents, once each.

**Acceptance Scenarios**:

1. **Given** a Case that reaches a final state, **When** the transition is recorded, **Then** exactly one
   precedent exists for it, however many times the event is delivered.
2. **Given** a Case that is not final, **When** looked for among the precedents, **Then** it is absent.
3. **Given** a Case from a Benchmark run or a Replay, **When** it reaches a final state, **Then** it is
   not added, and the Timeline of the Benchmark is unchanged.
4. **Given** an Order whose note contains instructions or odd text, **When** its Case is added, **Then**
   the stored description contains none of that text.
5. **Given** a failure to add the precedent (no embedding available, index down), **When** the Case
   closes, **Then** the Case still closes normally, and the precedent is queued to be added later.

---

### User Story 3 - Honest when it cannot search (Priority: P1)

The section never invents results. It says exactly which of these is true: there are no precedents yet,
none is similar enough, the search is running in **lexical mode** (a simple word-based similarity
because no embedding provider is available), the index is being rebuilt, or the search is unavailable
with its reason. Without any provider key the application still starts, the Case flow is unaffected,
and the section explains the mode it is in.

**Why this priority**: The product's promise is honesty. A confident list built from nothing would
break it.

**Independent Test**: Run each situation (empty index, nothing similar, no key, provider error, index
rebuilding) and check the distinct message and that no Case flow changes.

**Acceptance Scenarios**:

1. **Given** no closed Case, **When** the section is shown, **Then** it says "No precedents yet".
2. **Given** precedents whose best similarity is below the minimum, **When** shown, **Then** it says
   "Nothing similar enough" and lists none.
3. **Given** no embedding provider key, **When** a precedent is added or searched, **Then** the lexical
   mode is used and the section is labelled "Lexical similarity (no embedding provider)".
4. **Given** the provider fails or times out, **When** the Operator opens a Case, **Then** the Case
   opens normally and the section shows "Search unavailable" with the reason.
5. **Given** the index is being rebuilt, **When** the section is shown, **Then** it says so and shows
   no stale results as current.

---

### User Story 4 - Precedents never decide (Priority: P2)

Whatever the search returns, the system decides exactly as before. A Proposal, a Validator verdict, an
Approval and a resolution are identical with the feature on and with it off. A precedent cannot be
cited as Evidence, cannot make a claim of a Diagnosis, cannot satisfy the minimum Evidence rule,
cannot pre-select an Action in the resolution form, and is never sent to the Approval dialog as a
reason.

**Why this priority**: This is what keeps a useful hint from becoming a back door.

**Independent Test**: Run the same Cases with the feature enabled and disabled and compare Proposals,
verdicts and Timelines (apart from the retrieval record).

**Acceptance Scenarios**:

1. **Given** the same Case run with and without precedents, **When** the Proposals are compared,
   **Then** they are identical.
2. **Given** a Case with no Evidence of its own and many precedents, **When** the Validator runs,
   **Then** it still blocks for minimum Evidence.
3. **Given** the resolution form, **When** opened on a Case with precedents, **Then** nothing is
   pre-selected from them.
4. **Given** the contract, **When** the Evidence of a Case is read, **Then** it holds no precedent.

---

### User Story 5 - Every search leaves a trace (Priority: P2)

Each search is recorded in the Case's Timeline: when, who or what asked (the console or the Agent), how
many results, which precedents, the mode (provider or lexical), the embedding model and the time it took.
The Operator can see that a search happened and what it returned. This record is what makes a GenAI
step traceable in the same place as the rest of the Case.

**Why this priority**: It gives the audit trail and supports the community idea DPI-I-689
(Interoperability as a traceability tool for GenAI pipelines that use IRIS Vector Search).

**Independent Test**: Open a Case twice and check that two search records exist with the right fields
and no raw description text.

**Acceptance Scenarios**:

1. **Given** the section opens, **When** a search runs, **Then** one Timeline event records mode, model,
   result count, precedent identifiers and duration.
2. **Given** a search that fails, **When** recorded, **Then** the event carries the failure reason and no
   results.
3. **Given** any search event, **When** read, **Then** it contains no key and no free text of an Order.
4. **Given** the same Case opened several times in a minute, **When** recorded, **Then** repeated opens
   do not flood the Timeline (at most one event per minute per Case and requester).

---

### User Story 6 - The Agent may look up precedents, when enabled (Priority: P3, optional)

When explicitly enabled, the Agent has one more read-only Tool, "find precedents". Its answer is
labelled as a similarity result, not as a fact about the Case, and it can neither close the minimum
Evidence rule nor be cited as a claim. It is **off by default** and **off in the frozen reference
run**. The Benchmark report states whether it was on, and may include a variant "with precedents" as a
clearly separate result.

**Why this priority**: It is the RAG use of the feature, but it touches the Agent and the Benchmark, so
it comes after the safe parts and can be cut without losing the rest.

**Independent Test**: Run the same Cases with the Tool off and on and compare, checking that the
default configuration and the frozen setup have it off and that the report says so.

**Acceptance Scenarios**:

1. **Given** the default configuration, **When** the Agent investigates, **Then** the Tool is not
   offered.
2. **Given** the Tool enabled, **When** the Agent calls it, **Then** the answer is marked as precedents
   by similarity and excludes the Case itself and any Case of the same Benchmark run.
3. **Given** the frozen reference-run setup, **When** inspected, **Then** the Tool is off and the report
   says so.
4. **Given** the Tool enabled, **When** the Proposal is built, **Then** a precedent is never listed among
   its Evidence references.

---

### User Story 7 - Rebuild the index when the model changes (Priority: P3)

An administrator can rebuild all precedents with a command, for example after changing the embedding
model. Records keep the model they were built with, results never mix two models, and while a rebuild
runs the section says so. After it, every closed Case that should be a precedent is one, once.

**Why this priority**: A vector index tied to a model needs a way to change models without corruption.

**Independent Test**: Index with one model, switch, rebuild, and check that every precedent now carries the
new model and that searches never mixed the two.

**Acceptance Scenarios**:

1. **Given** precedents built with model A and a configuration for model B, **When** a search runs
   before the rebuild, **Then** it uses only records of the configured model or reports that the index
   needs a rebuild.
2. **Given** a rebuild, **When** it finishes, **Then** the number of precedents equals the number of
   eligible closed Cases, each once.
3. **Given** a rebuild interrupted midway, **When** it is started again, **Then** it completes without
   duplicates.

---

### Edge Cases

- A Case closes twice in the event stream (redelivery): still one precedent.
- A Case is reopened or corrected after closing: its precedent is replaced, not duplicated.
- Two Cases are nearly identical: both are listed, the more recent one first when similarity ties.
- The configured embedding dimension differs from the stored one: the search reports "needs rebuild".
- A very long exception message: the stored description is limited and the cut is marked.
- The Case being viewed is itself a precedent (it is closed): it never appears in its own list.
- The provider key is removed after precedents were built with it: existing precedents stay searchable
  by their own model only; new ones use lexical mode, and the section shows the mixed state as
  "needs rebuild".
- Time zones: ages and durations follow the BRT display rule of 005.
- A huge number of precedents: the search stays within its time goal and returns the same top results.

## Requirements *(mandatory)*

### Functional Requirements

**Building precedents**

- **FR-001**: When a Case enters `Resolved`, `ResolvedByPriorReceipt`, `Cancelled` or `Failed`, the
  system MUST record one precedent for it, once, however often the event is delivered. A Case that is not
  in a final state MUST NOT have a precedent.
- **FR-002**: A precedent MUST keep: the Case and Order identifiers, partner, exam code, exception class,
  the Action taken (or none), the final state, the time to close, a short description, the raw text the
  vector was built from, the similarity vector, the model and mode that produced it, its dimension, and
  when it was indexed.
- **FR-003**: The description MUST be built only from structured fields of the Case. Free text from an
  Order, a partner, an Operator note or the Agent MUST NOT be included, and Evidence marked as suspicious
  MUST NOT be used.
- **FR-004**: Cases that come from a Benchmark run or from Replay MUST NOT become precedents by default.
  A configuration MAY allow Replay Cases for demonstrations; Benchmark Cases MUST NOT be allowed.
- **FR-005**: A failure to build or store a precedent MUST NOT block, delay or change the closing of the
  Case. The precedent MUST be retried until it exists (Constitution VII).

**Searching**

- **FR-006**: For a Case, the system MUST return up to a requested number of precedents (default 5, at
  most 10) ordered by similarity, then by recency. The Case itself MUST NOT be returned.
- **FR-007**: A result below the minimum similarity MUST NOT be returned. The minimum MUST be configurable
  and shown in the answer.
- **FR-008**: Each result MUST give the precedent's Case, Order, partner, failure description, Action,
  final state, time to close, labels and similarity, and MUST NOT give the raw vector.
- **FR-009**: The search MUST use only records built with the configured model and dimension. If none match
  and others exist, it MUST say the index needs a rebuild instead of mixing models.
- **FR-010**: The search MUST work without an embedding provider, in a clearly labelled **lexical mode**,
  and MUST say which mode answered. Lexical results MUST NOT be presented as semantic.
- **FR-011**: The answer MUST distinguish: no precedents yet, nothing similar enough, lexical mode,
  rebuilding, needs rebuild, and unavailable with a reason.

**Honesty and boundaries**

- **FR-012**: Precedents MUST NOT be Evidence, MUST NOT be returned in a Case's Evidence, MUST NOT count
  towards the minimum Evidence, MUST NOT be a claim or hypothesis of a Diagnosis, MUST NOT be input to the
  Validator, MUST NOT pre-select or pre-fill a resolution, and MUST NOT appear as a reason in an Approval.
- **FR-013**: With the feature enabled or disabled, the Proposals, verdicts, Approvals, executions and
  resolutions for the same Cases MUST be identical.
- **FR-014**: A search MUST NOT write to a Case other than its search record, MUST NOT send anything to a
  partner, and MUST NOT call the Simulator.
- **FR-015**: No key, secret or free text of an Order MAY appear in a precedent, a search record, a log or
  an export. Data is synthetic and labelled.

**Trace**

- **FR-016**: Each search MUST add one event to the Case's Timeline with: the requester (console or
  Agent), time, mode, model, result count, precedent identifiers, duration, and the reason when it failed.
  Repeated opens of the same Case by the same requester MUST NOT write more than one event per minute.

**Console**

- **FR-017**: The console MUST show "Similar resolved Cases" in the Review Dossier (next to the next-step
  box) and in the detail of any Case, with the distinct messages of FR-011, the mode, and the statement
  that it is a similarity search and not Evidence. It MUST follow the visual system of 014 and the
  accessibility rules of 005 (keyboard, glyph and label for state, polite status messages).
- **FR-018**: The section MUST NOT change what else the console shows or sends, MUST NOT steal focus when it
  loads, and a poll MUST NOT reset it.

**Maintenance**

- **FR-019**: An administrator MUST be able to rebuild all precedents from the closed Cases, idempotently
  and resumably, with no duplicates, and the rebuild MUST be visible as a state to searches.

**Optional Agent Tool (story 6)**

- **FR-020**: An Agent Tool "find precedents" MAY exist. It MUST be read-only, MUST be off by default and
  off in the frozen reference-run setup, MUST mark its answer as similarity results, MUST exclude the Case
  itself and the Cases of the same Benchmark run, and MUST NOT be accepted as Evidence in a Proposal.
- **FR-021**: When the Tool is on in any Benchmark run, the report MUST say so, and results MUST be
  published as a separate variant, never mixed into the frozen result.

### Key Entities

- **Precedent**: one closed Case seen as a lesson: identifiers, structured facts, the Action and final
  state, a short description, its raw text, a similarity vector, the model, mode and dimension, and the
  indexing time. One per eligible Case.
- **PrecedentMatch**: one result of a search: a Precedent's public fields and a similarity. Never carries the vector.
- **PrecedentSearchRecord**: one Timeline event of a search (requester, mode, model, count, identifiers,
  duration, reason).
- **IndexState**: the model, dimension and mode the index is built with, the count of precedents and
  whether a rebuild is running.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the reference set of closed Cases with known families, the top precedent of a new Case
  belongs to its own family in at least 90% of Cases, in lexical mode, and the same set gives the same
  ranking on every run.
- **SC-002**: With the feature on versus off, Proposals, verdicts, Approvals, executions and resolutions
  are identical for 100% of the reference Cases.
- **SC-003**: With no embedding provider key, the application starts, every Case flow completes as before,
  and the section is shown in lexical mode in 100% of the tests.
- **SC-004**: 100% of Cases that reach a final state have exactly one precedent after processing, and
  Benchmark Cases have none.
- **SC-005**: No precedent, search record, log or export contains a key or free text of an Order, in 100% of
  the tests.
- **SC-006**: A search over 1,000 precedents answers in under 1 second on the reference instance.
- **SC-007**: Each of the six situations of FR-011 shows its own message in 100% of the tests, and a
  failure of the search never prevents a Case from opening.
- **SC-008**: After a rebuild, the number of precedents equals the number of eligible closed Cases, with no
  duplicates, including after an interrupted rebuild.
- **SC-009**: Automated accessibility checks report no WCAG 2.2 AA violation on the Dossier and the Case
  detail with the section, in light and dark.
- **SC-010**: The frozen reference-run setup has the Agent Tool off in 100% of the checks, and the report
  states it.

## Assumptions

- Terminal states are those of the contract: `Resolved`, `ResolvedByPriorReceipt`, `Cancelled`, `Failed`.
  `Failed` and `Cancelled` are kept because a precedent that did not work is useful to the Operator, and
  they are shown with their outcome.
- The vector search uses IRIS vector search (similarity over a stored vector, with an index suited to
  nearest-neighbour queries). The embedding comes from a configured provider or, without one, from the
  lexical mode. The AI Hub providers are OpenAI, Anthropic, Gemini and Bedrock, and Anthropic offers no
  embeddings, so the embedding provider is configured **separately** from the Agent's provider.
- The Operator-facing search is a **new observable operation** of the product API (for example, the
  precedents of a Case). The contract is frozen, so this needs a contract-change feature before the console
  can call it; the spec does not decide its exact shape.
- The reference scenario produces enough closed Cases of each family to seed the index. A small set of
  synthetic closed Cases MAY be loaded to demonstrate the feature, and is labelled synthetic.
- Minimum similarity, default and maximum result counts, and the once-per-minute record limit are
  configuration with the defaults stated here, not constants of the behavior.
- Retrieval only. No text is generated from the precedents in this feature; a summary or explanation
  written by a model is out of scope.
- The Benchmark remains defined by 010. This feature only constrains it (FR-020 and FR-021); it does not
  change its scoring.
- Times are shown in BRT and copy is in English, as in 005 and 014.
- This feature supports the community idea DPI-I-689 ("Use InterSystems Interoperability as a traceability
  tool for GenAI LLM pipelines", status Community Opportunity) through the search record of FR-016; whether the
  contest counts it is not confirmed by the organizers.
