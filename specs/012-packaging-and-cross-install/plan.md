# Implementation Plan: Packaging, Installation and Cross-Install Validation

**Branch**: `g1-wiring-and-012` | **Date**: 2026-10-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/012-packaging-and-cross-install/spec.md`

## Summary

The submission is a local image built on the fixed base tag, a one-service compose file and an
English README. The root `Dockerfile` has two stages:
- a pinned Node stage builds the console;
- the IRIS stage compiles the product with `$system.OBJ.LoadDir` (no IPM, no network) and
  installs the start-up hook.

`docker-compose.yml` runs it with `env_file: .env`, fixed ports, a health check on 1972, and no
mounts. `scripts/smoke.sh` proves the install path end to end, using only sh and curl. CI replaces
the template's image publishing with four checks:
- the contract checks;
- the console checks;
- a secret scan;
- the core unit tests on a public IRIS image.

The gate G1 wiring (same branch) supplies what the smoke needs at start-up: the Simulator's API,
and the feed reader and sweeper when `SN_BACKGROUND_TASKS=1`.

## Technical Context

**Language/Version**:
- Dockerfile and compose, for Docker Engine with the compose plugin.
- POSIX sh.
- ObjectScript on IRIS 2026.3 AI Hub build 154.
- Node 22.17.0 for the console build.

**Primary Dependencies**: the base image `signalnoir/iris-aihub:2026.3.0AI.154.0`, loaded
locally; `node:22.17.0-bookworm-slim` (public); `intersystems/iris-community:2026.2` (public,
CI only).

**Storage**: the container's writable layer (AD-27). No volume.

**Testing**:
- `%UnitTest` via iris-agentic-dev for the Bootstrap and task changes.
- The image built and run locally on ARM64, checking: smoke, restart, stop/start, recreate,
  and the key search.
- The CI script run locally against the public image.

**Target Platform**: ARM64 (validated here); x64 by the cross-install.

**Constraints**:
- no registry pull of the base, and nothing pushed;
- no secret at build time;
- no iris-agentic-dev in the image;
- first Case within 15 minutes.

## Constitution Check

- [x] **Platform Constraints**:
  - build 154 only, never pushed;
  - secrets only at runtime (`.env`, verified by search, research R5);
  - without a key the app starts and reports it (verified);
  - only the tested platform and provider are announced (README "Validated").
- [x] **Reproducibility**: the README is the install path. The cross-install (T022) is the gate.
  A fix to the install path triggers a new one.
- [x] **iris-agentic-dev**:
  - it is used to compile and test the ObjectScript changes;
  - it is not in the image, not on the install path, and not exposed to the Agent;
  - the dev kit stays separate (`dev/aihub`).
- [x] **Contract-first HTTP**: the smoke uses only `openapi-signalnoir.yaml` (`/health`, `/cases`)
  and `openapi-sim.yaml` (`/scenarios`, `/emissions`). No endpoint is added.
- [x] **YAGNI**:
  - no IPM install at build (one `LoadDir`);
  - no volume;
  - no quick-validation code until 010 defines the runner.
- [x] **TDD**: the task repair (research R4) began as a failing assertion in
  `TestBootstrap.TestGateG1Wiring`.
- [x] **Calendar gate**: after 2026-10-26.

## Project Structure

```text
Dockerfile                    # submission image (replaces the template's)
docker-compose.yml            # submission compose (replaces the template's)
.dockerignore                 # keeps .env, keys, archives and tooling out of the context
.env.example                  # placeholders (gate G1 + this feature)
deploy/install.script         # build-time compile and hook install
scripts/smoke.sh              # first-Case check
scripts/secret-scan.sh        # CI and local secret scan
tests/ci/core-tests.script    # core tests on a public IRIS (CI)
.github/workflows/ci.yml      # secret scan, console, core tests
README.md                     # English install and product guide
src/SignalNoir/Tasks/Periodic.cls   # task base: runs as _SYSTEM, repairs suspended tasks
```

Removed:
- the template's `Dockerfile_mini`, `Dockerfile_less_image` and `iris.script`;
- the workflows `build-push-gcr.yaml` (Cloud Run deploy), `github-registry.yml` (pushes to
  ghcr.io) and `runtests.yml` (built the Dockerfile, now on a private base).

## Complexity Tracking

| Deviation | Why | Simpler alternative rejected |
|---|---|---|
| Task `RunAsUser = _SYSTEM` | A task created by `%ZSTART` runs as `%System`, and the Task Manager suspends it without running it (R4) | Creating the task at build time: the setting `SN_BACKGROUND_TASKS` is runtime-only, and the dev database must stay off |
