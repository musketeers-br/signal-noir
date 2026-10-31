# Feature Specification: Packaging, Installation and Cross-Install Validation

**Feature Branch**: `g1-wiring-and-012` (shared with the gate G1 wiring, by Henry's choice on
2026-10-29: one branch, commits split by file)

**Created**: 2026-10-29

**Status**: Partially implemented. The repository side is done. Four parts wait on other work:
the quick validation needs 010; the cross-install, the video and the contest submission are steps
for team members (see tasks.md).

**Input**: `docs/specify-prompts/012-packaging-and-cross-install.txt`

## Context

Signal Noir runs on a pre-release platform image that is not in any public registry. The operator
downloads it from the EAP portal, loads it into the local Docker engine, and builds the product on
top of it. Everything the person installing needs is in the README: no front-end toolchain, no
developer tooling, and no access to a private registry. The key of the AI provider enters only
when the container starts.

Already in place before this feature:
- the start-up hook, which registers the APIs, the console and the Simulator, and reports the
  provider (001, gate G1);
- the background tasks, which read the Origin feed and sweep pending work when
  `SN_BACKGROUND_TASKS=1` (gate G1);
- the built console served as static files (005);
- the dev environment on build 154 (`dev/aihub`), which stays for development only.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Install from the README and reach the first Case (Priority: P1)

A person who did not write the README installs Signal Noir on a clean machine. They load the
build 154 image, retag it, copy the environment template, add their own key, build and start.
A smoke check sends one synthetic Order through the Simulator and reaches the first Case.

**Why this priority**: the contest is judged on a clean install. Nothing else matters if it fails.

**Independent Test**: on a machine with only Docker and the build 154 file, follow the README from
top to bottom and run the smoke check.

**Acceptance Scenarios**:

1. **Given** the build 154 file of the machine's architecture, **When** the operator loads it and
   retags it to `signalnoir/iris-aihub:2026.3.0AI.154.0`, **Then** the build uses that tag, never
   contacts `docker.iscinternal.com`, and the same tag appears in the README, the Dockerfile and
   the compose file.
2. **Given** the image is built, **When** `docker compose up -d` runs, **Then** one `iris` service
   starts on host ports 1972 and 52773, becomes healthy, and the health endpoint answers.
3. **Given** the application is up, **When** the smoke check runs, **Then** it reports the first
   Case within 15 minutes of starting the install, with its state.
4. **Given** a machine without Node, **When** the console is opened, **Then** the static front end
   comes from the image and loads.

---

### User Story 2 - Secrets stay out of everything (Priority: P1)

The key enters only at runtime, through `.env` or the environment. Without a key the application
still starts and says why the provider is unavailable.

**Why this priority**: the repository is public and the image is local. A leaked key is the worst
failure of the submission.

**Independent Test**: build and start with a key, then search the image layers, the build history,
the repository, the logs and an exported Case for it.

**Acceptance Scenarios**:

1. **Given** a key in `.env`, **When** the image is built, **Then** no build argument, layer or
   history entry holds it.
2. **Given** a running application with a key, **When** the logs, the Timeline and the Case detail
   are searched, **Then** the key appears nowhere.
3. **Given** no key, **When** the application starts, **Then** it is up, the health surface reports
   the provider unavailable with a reason, and a Case that needs the provider ends in
   `ReviewRequired` with that reason.
4. **Given** the repository, **When** it is searched, **Then** only `.env.example`, with
   placeholders, declares the variables, and `.env` is ignored.

---

### User Story 3 - Restart keeps the data, down resets the demo (Priority: P2)

Data lives in the container's writable layer. The README states exactly what survives.

**Why this priority**: an operator who restarts during the demo must not lose the Case under
review. An operator who wants a clean demo must know how to get one.

**Independent Test**: create a Case with an Approval, then run restart, stop/start and down/up,
checking the Case each time.

**Acceptance Scenarios**:

1. **Given** a Case with an Approval and a Timeline, **When** `docker compose restart` or
   `stop` then `start` runs, **Then** the Case, its Approval and its Timeline are unchanged.
2. **Given** the same Case, **When** `docker compose down` then `up` runs, **Then** the Case is
   gone and the demo starts empty, as the README says.
3. **Given** the compose file, **When** it is read, **Then** it declares no named volume and no
   bind mount.

---

### User Story 4 - CI checks without publishing (Priority: P2)

CI runs static checks and the core unit tests, and never builds, runs, publishes or deploys an
image of the private build.

**Why this priority**: the upstream template shipped workflows that publish and deploy images.
Publishing an image derived from the EAP build is forbidden.

**Independent Test**: read every workflow; run the core test job against a public IRIS image.

**Acceptance Scenarios**:

1. **Given** the workflows, **When** they are read, **Then** none pushes, publishes or deploys an
   image, and none references the build 154 tag.
2. **Given** a push, **When** CI runs, **Then** it lints the contracts, checks the console (type
   check, unit tests, build), and runs the core unit tests on a public IRIS image.
3. **Given** a commit that adds a file holding something shaped like a provider key, **When** CI
   runs, **Then** the check fails.

---

### User Story 5 - Quick validation (Priority: P3)

One command runs 3 reference cases in at most 3 minutes and reports, per case, match or diverged
with a reason.

**Why this priority**: it is the evaluator's first check after the smoke, but it needs the
benchmark runner and scoring of feature 010, which is not built yet.

**Independent Test**: run the command on a fresh install and time it.

**Acceptance Scenarios**:

1. **Given** a running application, **When** the quick validation runs, **Then** it runs 3
   reference cases, finishes within 3 minutes, and prints match or diverged with a reason per case.

---

### User Story 6 - Cross-install, video and submission (Priority: P3)

Steps for team members, which no code can do:
- **Cross-install**: Henrique, who did not write the README, installs on a clean machine with his
  own key and reaches the first Case within 15 minutes.
- **Video**: at most 5 minutes. It follows the demo script, covers the decision,
  platform-guarantee, dossier and resilience moments, and labels the synthetic data and Replay.
- **Submission**: the Open Exchange page points to the public repository, the contest entry is
  verified, and only the tested platforms and providers are announced as validated.

**Acceptance Scenarios**:

1. **Given** the README, **When** a different team member installs from it alone, **Then** the
   smoke check passes, and any fix to the install path triggers a new cross-install.
2. **Given** the video, **When** it is watched, **Then** it is at most 5 minutes and matches the
   delivered version.

### Edge Cases

- The person installing used a buildx `docker-container` driver: the build cannot see the local
  image and tries to pull from the internal registry. The README names the symptom and the fix
  (`docker buildx use default`).
- The person loaded build 162: the README says only build 154 is accepted; the fixed tag names 154.
- The `.env` file is missing: compose refuses to start and names the file; the README says to copy
  `.env.example` first.
- Port 1972 or 52773 is taken on the host: the start fails visibly; the README names the ports.
- The provider key is invalid: the application starts and Cases end in review with the reason,
  as with no key.
- The smoke check runs before the first feed poll: it waits, polling, up to its limit, and then
  reports the elapsed time and the Simulator Order it was waiting for.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The image MUST be built from the base tag `signalnoir/iris-aihub:2026.3.0AI.154.0`,
  given through a single build argument whose default is that tag. The same string MUST appear in
  the README and the compose file.
- **FR-002**: The build MUST NOT pull the base image from any registry. The README MUST tell the
  operator to use the default Docker builder.
- **FR-003**: The compose file MUST start one service, `iris`, with: `env_file: .env`; the CPF
  merge file; host ports `1972:1972` and `52773:52773`; a health check on 1972; and no bind mount
  and no named volume.
- **FR-004**: The image MUST contain the compiled product, the start-up hook and the built
  console, at a path outside any mount. The console MUST be built in a separate build stage with a
  pinned Node version.
- **FR-005**: The image MUST NOT contain developer tooling (iris-agentic-dev), tests, license keys,
  the EAP archive or any secret.
- **FR-006**: Secrets MUST enter only at runtime, through `.env` or the environment. They MUST be
  declared with placeholders in `.env.example` and never committed. Without a valid key, the
  application MUST start and report the provider unavailable.
- **FR-007**: Data MUST survive `restart` and `stop`/`start`. `down` MUST remove it, and the
  README MUST say so.
- **FR-008**: A smoke check MUST:
  - send one synthetic Order through the Simulator;
  - wait for the background feed reader to open its Case;
  - report the Case and its state, or fail with the elapsed time.
  It MUST need only a shell and curl on the host.
- **FR-009**: The README MUST be in English and cover:
  - the controlled EAP download, the `docker load` of the x64 and ARM64 files, and the retag;
  - the image and build;
  - the supported providers and the key variables;
  - the start, smoke, quick validation and benchmark commands;
  - how the product works, the video link and the team's profiles;
  - the limitations (synthetic data, Replay) and the reset behavior.
  An item whose content does not exist yet (video link, benchmark results) MUST be marked as
  pending, never invented.
- **FR-010**: No workflow MAY push, publish or deploy an image, or reference the build 154 image.
  CI MUST run the contract checks, the console checks, a secret scan and the core unit tests on a
  public IRIS image.
- **FR-011**: The quick validation command MUST run 3 reference cases in at most 3 minutes and
  report match or diverged with a reason per case. It depends on feature 010.
- **FR-012**: Only tested platforms and providers MAY be announced as validated in the README and
  the submission.

### Key Entities

- **Base image**: build 154 of IRIS with AI Hub, loaded locally under the fixed tag.
- **Product image**: the base plus the compiled product and the console; local only, never pushed.
- **Environment file**: the runtime settings and the key; git-ignored. Its template is versioned.
- **Smoke check**: the first-Case check of the install path.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A team member who did not write the README installs and passes the smoke check
  using only the README, within 15 minutes.
- **SC-002**: The fixed tag is identical in the README, the Dockerfile and the compose file, and
  the build makes no request to any registry for the base image.
- **SC-003**: Zero occurrences of the key in the image, its history, the repository, the logs and
  the Case detail.
- **SC-004**: Restart and stop/start keep 100% of the Cases, Approvals and Timeline events; down
  then up starts with zero Cases.
- **SC-005**: Zero workflows publish, push or deploy an image.
- **SC-006**: The quick validation finishes 3 cases within 3 minutes (after 010).

## Assumptions

- The person installing has Docker with the compose plugin, the build 154 file of their
  architecture, and their own provider key.
- The Simulator runs inside the same instance and is reached over HTTP at
  `http://localhost:52773/sim/api/v1`.
- Without a provider, the Case of the smoke check still opens, in `ReviewRequired`. The smoke
  check passes on the first Case whatever its state. The first Case with a real Proposal needs
  a key.
- Feature 004 (validated Proposals) and feature 010 (benchmark) merge later. The README links
  their commands once they exist.
- Durability through restart is the contract (AD-27). There is no named volume.
