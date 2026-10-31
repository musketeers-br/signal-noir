# Tasks: Packaging, Installation and Cross-Install Validation

**Input**: Design documents from `specs/012-packaging-and-cross-install/`

**Prerequisites**: plan.md, spec.md, research.md, quickstart.md

**Tests**: TDD for the ObjectScript changes (`%UnitTest` via iris-agentic-dev). The packaging is
verified by building and running the image locally (research R1–R5).

**Open tasks**: T020 waits on 010. T021–T024 are steps for team members.

## Phase 1: Setup

- [X] T001 Remove the template's image-publishing workflows `.github/workflows/build-push-gcr.yaml` (Cloud Run deploy) and `.github/workflows/github-registry.yml` (ghcr.io push), and `runtests.yml`, which built the Dockerfile (FR-010)
- [X] T002 [P] Remove the template's `Dockerfile_mini`, `Dockerfile_less_image` and `iris.script`, which nothing on the install path uses
- [X] T003 [P] `.dockerignore`: exclude `.env*` (keep `.env.example`), `*.key`, `*-docker.tar.gz`, `.iris-agentic-dev.toml`, `node_modules`, the console build and the agent tooling (FR-005)

## Phase 2: Foundational (gate G1 wiring, same branch)

- [X] T004 Test first: `tests/SignalNoir/Tests/Interop/TestBootstrap.cls` `TestGateG1Wiring`, covering:
  - the background tasks are off without `SN_BACKGROUND_TASKS`;
  - `EnsureBackgroundTasks(1)` schedules one of each, as `_SYSTEM` and not suspended;
  - a suspended `%System` task is repaired;
  - `EnsureBackgroundTasks(0)` removes them.
- [X] T005 `src/SignalNoir/Tasks/Periodic.cls`: a base with `Ensure` / `Count` / `Remove`, `RunAsUser = _SYSTEM`, and the repair of existing tasks (research R4); `SweeperTask` extends it
- [X] T006 [P] `src/SignalNoir/Tasks/OriginFeedTask.cls`: `OriginFeed.Poll()` every minute
- [X] T007 `src/SignalNoir/Interop/Bootstrap.cls`: `EnsureBackgroundTasks(SN_BACKGROUND_TASKS = 1)`, its state in `^SignalNoir.Provider("backgroundTasks")`; `boot/%ZSTART.mac` registers the Simulator beside it (the product never references `SignalNoir.Sim`: `TestNoCrossReference`)
- [X] T008 [P] `.env.example`: provider, model and key placeholders, `SN_SIM_BASE_URL`, `SN_BACKGROUND_TASKS=1`, and the optional timings

## Phase 3: User Story 1 - Install from the README and reach the first Case (P1)

**Independent test**: build, run, smoke, open the console.

- [X] T009 [US1] `Dockerfile`: one `ARG IMAGE=signalnoir/iris-aihub:2026.3.0AI.154.0`, a pinned Node stage for the console, and an IRIS stage that copies `merge.cpf`, `boot/`, `src/`, `deploy/` and the console build (FR-001, FR-004)
- [X] T010 [US1] `deploy/install.script`: `LoadDir` twice, failing the build on any compile error; `%ZSTART` installed in `%SYS` (research R1)
- [X] T011 [US1] `docker-compose.yml`: one `iris` service with `build.args.IMAGE` (the fixed tag), `image: signalnoir/app:local`, `pull_policy: build`, `env_file: .env`, the CPF merge, `1972:1972` and `52773:52773`, a health check on 1972, and no mounts (FR-003)
- [X] T012 [US1] `scripts/smoke.sh`: waits for liveness; creates and emits `P5/P5-tune-01` on the Simulator; waits for the Case of that Order; prints the Case and its state; needs only sh and curl (FR-008)
- [X] T013 [US1] Build and run the image locally, recording the results in research R1–R4:
  - compile errors 0;
  - the console is served;
  - smoke PASS in 26 s, with the Case in `ReviewRequired` without a key.
- [X] T014 [US1] `README.md` in English, covering FR-009. The video, the DC profiles and the quick validation are marked pending. Only build 154 ARM64 with OpenAI `gpt-4o-mini` is announced as validated (FR-012)

## Phase 4: User Story 2 - Secrets stay out of everything (P1)

- [X] T015 [US2] `scripts/secret-scan.sh` (tracked secret files, key-shaped strings; allows the `sk-signalnoir-test-` fakes); clean on the repository
- [X] T016 [US2] With a fake key at runtime, search logs, image history and inspect, `messages.log`, the Case, the Timeline, `/health` and the IRISAPP globals: 0 hits; the Case reaches `ReviewRequired` with the provider failure (research R5)

## Phase 5: User Story 3 - Restart keeps the data, down resets the demo (P2)

- [X] T017 [US3] Restart and stop/start keep the Case and its Timeline; a recreated container starts with 0 Cases; README "Data and reset" (research R3)

## Phase 6: User Story 4 - CI checks without publishing (P2)

- [X] T018 [US4] `.github/workflows/ci.yml` with these jobs:
  - `secret-scan`;
  - `sim-captures` (002 G1 note 3);
  - `console` (Node 22.17.0: `npm ci`, `check`, `test`, `build`);
  - `core-tests` (`intersystems/iris-community:2026.2`, `tests/ci/core-tests.script`).
  `contracts.yml`, `objectscript-quality.yml` and `bump-module-version.yml` are kept. No job builds, runs or pushes an image of the EAP build (FR-010).
- [X] T019 [US4] Run locally what CI runs:
  - the core suite on 2026.2: 65/65, with 0 compile errors;
  - the console: 0 type errors, 46/46 tests;
  - the captures: 40, 0 failing;
  - the secret scan: clean.

## Phase 7: User Story 5 - Quick validation (P3)

- [ ] T020 [US5] **Waits on 010.** Quick validation command: a BenchmarkRun over 3 reference cases, ≤ 3 minutes, match or diverged with a reason per case; listed in the README (FR-011, SC-006)

## Phase 8: User Story 6 - Cross-install, video, submission (P3) — team members

- [ ] T021 [US6] On a machine without the dev container, `docker compose up -d` on the fixed ports, `docker compose ps` healthy, smoke PASS, an Approval kept through `restart` (research R3, "not verified here")
- [ ] T022 [US6] **Henrique**: cross-install on a clean x64 machine from the README alone, with his own key, first Case ≤ 15 min (SC-001); record the time and any README fix (which triggers a new cross-install)
- [ ] T023 [US6] **Team**: the video (≤ 5 min): demo script; decision, platform guarantee, dossier and resilience moments; synthetic and Replay labeled; its link in the README
- [ ] T024 [US6] **Team**: Open Exchange page → the public repository; contest entry verified; DC profiles in the README; published results match the benchmark report (after 010)

## Dependencies

- Phase 2 → US1, because the smoke needs the feed reader at start-up.
- US1 → US2, US3 (they run on the built image).
- US4 is independent.
- US5 needs 010. US6 needs US1–US4, and T024 needs 010.
