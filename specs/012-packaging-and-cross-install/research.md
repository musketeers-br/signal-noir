# Research: Packaging, Installation and Cross-Install Validation

## Calendar-gate exception

None needed: the work is from 2026-10-29, after the gate.

## R1 — Compile at build without IPM

**Decision**: `deploy/install.script` runs `$system.OBJ.LoadDir(src, "ck-d", , 1)` twice. The
first pass settles the compile order. The second pass is the one checked: any error ends the
session with exit code 1, which fails `docker build`.

**Rationale**:
- the template's IPM install downloaded `latest` at build time, which is network-dependent and
  not pinned;
- the product has no IPM dependencies;
- `module.xml` stays for the Open Exchange listing.

**Verified**: on the local ARM64 build, `compile errors: 0`, and the image built in 26 s with the
base cached.

## R2 — Console in a pinned Node stage

**Decision**: `node:22.17.0-bookworm-slim` runs `npm ci` and `npm run build`. Its output
`ui/build/` is copied to `/home/irisowner/dev/ui/build/`, the default `SN_UI_PATH`, with no mount
in the submission.

**Verified**: `GET /signalnoir/ui/index.html` returns 200, and `/signalnoir/` redirects to the
console, from the image with nothing mounted.

## R3 — Compose and durability

**Decision**:
- one `iris` service with `build.args.IMAGE` set to the fixed tag, `image: signalnoir/app:local`
  and `pull_policy: build`, so compose never tries a registry for the product image;
- `env_file: .env` and the CPF merge file;
- ports `1972:1972` and `52773:52773`;
- a `bash /dev/tcp` health check on 1972;
- `restart: unless-stopped`;
- no volume and no bind mount.

**Verified**: on the image, run as `docker run` with the same settings and other host ports,
because the dev container holds 1972 and 52773:
- after the smoke Case, `restart` and `stop`/`start` kept the 1 Case and its 4 Timeline events;
- a recreated container started with 0 Cases;
- `docker compose config --quiet` accepts the file.

**Not verified here**: `docker compose up` itself on the fixed ports, which needs the dev
container stopped. An Approval surviving a restart was not checked either, because no Approval
exists without a key. Both are covered by the cross-install (T022).

## R4 — Background tasks created at start-up are suspended

**Finding**: on the image, the tasks that `Bootstrap.OnStart` (run from `%ZSTART`) registered
stayed at `Suspended=1` with `LastStarted=0`, and the Origin feed was never read. A task created
in that context runs as `%System`. After `RunAsUser = "_SYSTEM"` and `Resume`, the feed task ran
within the minute and the cursor moved.

**Decision**: `Tasks.Periodic` (the new base of `SweeperTask` and `OriginFeedTask`):
- sets `RunAsUser` from the `RunAsUser` parameter (`_SYSTEM`);
- on `Ensure()`, repairs an existing task of the class: sets its user and resumes it if suspended.

`TestBootstrap.TestGateG1Wiring` asserts `_SYSTEM:0` after `Ensure`, and repairs a task left
`%System` and suspended.

**Verified**: on the rebuilt image, the smoke Case opened 26 s after the instance was ready.

## R5 — Secrets

**Decision**:
- the key is only in `.env` or the environment;
- `.dockerignore` excludes `.env*` (except `.env.example`), `*.key`, `*-docker.tar.gz` and
  `.iris-agentic-dev.toml`;
- the build reads no key;
- CI runs `scripts/secret-scan.sh`, which fails on: a tracked `.env`, workspace config, license
  key or EAP archive; or a committed string shaped like an OpenAI, Anthropic, Google or AWS key.
  The tests' fake keys are named `sk-signalnoir-test-` and are allowed.

**Verified**: with a fake key passed at runtime, the key appeared 0 times in:
- `docker logs`, `docker history --no-trunc` and `docker image inspect`;
- `messages.log`;
- the Case detail, its Timeline and `/health`;
- 17.9 million global nodes of IRISAPP;
- the repository.

The Case ended in `ReviewRequired` with the provider failure as its reason.

## R6 — CI core tests on a public IRIS

**Decision**: `intersystems/iris-community:2026.2` with the repository mounted read-only.
`tests/ci/core-tests.script` loads `src` and `tests/SignalNoir/Tests/Core`, runs the Core suite,
and exits 1 on any failure or load error.

**Verified** (locally, the same image as `latest-cd`, 2026.2.0.221.0):
- the whole product compiles with 0 errors (no `%AI` class is needed to compile);
- the Core suite passes 65/65.

**Not viable**: `intersystems/iris-community:2025.1` refuses to start ("Community License
expired"). Community images carry a license with an end date, so the tag will need a bump when
2026.2's expires.

**Alternatives rejected**:
- the application and interop suites in CI: they need the Simulator, the AI Hub and the Task
  Manager, which belong to the build 154 image that CI must not use;
- `objectscriptquality` stays as the static-analysis job.

## R7 — Quick validation

**Decision**: deferred to 010. The quick validation is a BenchmarkRun over 3 reference cases,
scored against the reference answers (`POST /benchmark-runs`, `GET /benchmark-reports`), and the
runner and scoring are feature 010's. The README lists the command as *pending*. Nothing is
announced that does not exist yet.

## T022 — Cross-install, first attempt (2026-11-03 02:02 UTC)

Henrique has no second machine, so the cross-install ran on his Windows 11 x64 machine (Docker Desktop) as a
fresh clone of master `ded4ce6` from GitHub, in a new folder and compose project (`signalnoir-cross`), following
the README's Install section with his own OpenAI key (`gpt-4o-mini`), then `sh scripts/smoke.sh`:

| Step | Elapsed |
|---|---|
| `git clone` | 3 s |
| 1. `docker load` (x64 file) | 1 min 42 s |
| 2. retag, 3. `.env` | 1 min 43 s |
| 4. `docker compose build --no-cache` | 2 min 16 s |
| 5. `docker compose up -d`; `/health` alive, provider configured | 2 min 25 s |
| smoke: Order emitted, first Case open (`Investigating`) | **3 min 17 s** |

The Case then reached `PendingApproval` with the Agent's Proposal. SC-001 (first Case ≤ 15 min) holds with room.
This also verifies `docker compose up` on the fixed ports 1972 and 52773 (R3, "not verified here").

**Not a clean machine.** Docker already held the base image's layers, so `docker load` was faster than on a new
machine, and the build reused no project layer (`--no-cache`) but did not download what Docker had cached (the
Node image). The README's command is `docker compose build`; `--no-cache` only kept earlier builds out of it.

**README fixes found**, both on Windows:
1. The first clone, into a deep folder, failed with `Filename too long`: some paths under `_bmad-output/` exceed
   the 260-character limit. The README now says to clone to a short path or set `core.longpaths`.
2. `docker buildx use default` fails on Docker Desktop (`ERROR: run docker context use default`), whose context is
   `desktop-linux`. The build still worked, since that builder also uses the `docker` driver, but the step reads
   as broken. Step 4 is now `docker buildx use "$(docker context show)"`, which selects `default` on Linux and
   `desktop-linux` on Docker Desktop; checked on this machine.

These fixes trigger a new cross-install from the corrected README; T022 stays open until it passes. An Approval
kept through `restart` (T021) was not checked here.
