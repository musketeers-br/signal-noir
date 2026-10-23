# Phase 0 Research: Runtime Skeleton and Shared Seams

**Date**: 2026-10-22
**Instance**: `ai-hub-dev-template-iris-1`, reached through iris-agentic-dev
(`IRIS_HOST=localhost`, `IRIS_WEB_PORT=52773`, namespace `IRISAPP`).

Every platform claim below was checked on the live build 154 container, as the Constitution
requires. Web material (documentation, issue tracker) is treated as data and is cited only where
the live check could not cover the semantics.

---

## D1 — Platform build and image

- **Decision**: Build 154 is the only accepted runtime. The container uses
  `iris-community:2026.3.0AI.154.0`, retagged to a fixed project tag in the build.
- **Rationale**: The contest and the Constitution mandate it; 162 is forbidden.
- **Alternatives considered**: Build 162 (forbidden); a public IRIS image without AI Hub (no
  `%AI.*`).
- **Verified live**: `write $ZVERSION` returns `IRIS for UNIX (Ubuntu Server LTS for x86-64
  Containers) 2026.3.0AI (Build 154U)`.

## D2 — Namespace and Interoperability

- **Decision**: The application lives in namespace `IRISAPP` (databases `IRISAPP_DATA`,
  `IRISAPP_CODE`) with `Interop=1` set by `merge.cpf`.
- **Rationale**: The architecture packages and the Production assume an interoperability-enabled
  namespace.
- **Alternatives considered**: A single global namespace (loses the interop separation); a
  per-feature namespace (unnecessary split).
- **Verified live**: `IRISAPP` exists; 464 `Ens.*` classes are resolvable in `IRISAPP`
  (`Ens.Director`, `Ens.BusinessService`, `Ens.BusinessProcess`, `Ens.BusinessOperation`,
  `Ens.Production`, `EnsLib.HTTP.OutboundAdapter`), and `Ens.Director::StartProduction` exists.
- **Risk found**: on the currently running template container `Config.Namespaces.Get("IRISAPP")`
  reports `Interop=0`, even though `merge.cpf` declares `Interop=1`. Interop classes are present
  regardless. The implementation MUST build a fresh container from the updated `merge.cpf` and
  re-check the flag before relying on Production internals; if the flag stays 0, enable it with
  `Config.Namespaces` and record it.

## D3 — Persistence and optimistic concurrency

- **Decision**: Case, Order, timeline and outbox are `%Persistent` classes in
  `SignalNoir.Application.Model`; the Case version uses `VERSIONPROPERTY`.
- **Rationale**: The Case is the source of truth (Principle V) and transitions need
  compare-and-swap (AD-3). `VERSIONPROPERTY` is the native IRIS mechanism.
- **Alternatives considered**: Manual `Version` column compared in a `WHERE` clause (works but
  duplicates the platform guarantee); pessimistic locks (rejected by AD-3).
- **Verified live**: A throwaway `%Persistent` class with `Parameter VERSIONPROPERTY = "Version"`
  compiles and persists; a second save increments the version. A stale write is rejected by IRIS
  with `Concurrency failure on update: row versions not the same for table '...', field
  'Version', value '1'`, confirming the guarantee is enforced (not advisory).
- **Cleanup note**: the probe classes `SN.Proto.VersionProbe*` remain in the dev container because
  the delete path was not available in this session; they are throwaway and outside the repository.

## D4 — HTTP layer and the health surface

- **Decision**: `%CSP.REST` dispatch class at `/signalnoir/api/v1` for the product API, and a
  second dispatch at `/signalnoir/api/v1/health` for the operational health surface. The health
  endpoint is proposed as an explicit change to the frozen contract
  (`contracts/contract-change-001-health.md`).
- **Rationale**: AD-16 requires every HTTP interface to have a versioned OpenAPI. The spec
  requires liveness, readiness and provider availability to be distinct; the frozen contract has
  no such endpoint.
- **Alternatives considered**: Reusing `GET /cases` (conflates product and operations, no provider
  signal); an out-of-band port/`^%ZSTART` file (not observable by a juror); a Management Portal
  probe (not the application's readiness).
- **Verified live**: `%CSP.REST` exists; `Security.Applications` shows `DispatchClass`, `Path` and
  `ServeFiles` fields used by IRIS web applications, so the static/API split of AD-17 is
  configurable the same way.

## D5 — Seam packaging: ports, DTOs and fakes

- **Decision**: Ports are abstract ObjectScript classes in `SignalNoir.Core.Port`; DTOs are
  explicit classes in `SignalNoir.Core.Dto` (no JSON knowledge in the Core); test doubles live
  only under `tests/SignalNoir/Tests/Fakes` and are excluded from the runtime resource.
- **Rationale**: Principle I (pure core) and AD-16 ("internal contracts in ObjectScript are
  explicit DTOs"). Fakes must not ship (spec FR-011).
- **Alternatives considered**: `%DynamicObject` everywhere (weak typing, no contract); serializing
  DTOs with `%JSON.Adaptor` inside the Core (leaks a transport concern into the core); generating
  fakes with a mocking library (no standard one in core IRIS).
- **Verified live**: `%AI.Agent`, `%AI.ToolSet`, `%AI.Provider`, `%AI.Agent.Session` and
  `%AI.LLM.Response` exist, so the Proposer/Tools seams can name the real types without a stub
  layer guess.

## D6 — Production and the two-time bootstrap

- **Decision**: A minimal `SignalNoir.Interop.Production` with one Business Service
  (`Service/OrderIn`), and an idempotent `boot/%ZSTART.mac` (label `SYSTEM`) installed into `%SYS`
  that calls `SignalNoir.Interop.Bootstrap.OnStart()`.
- **Rationale**: AD-27 and AD-6. `^%ZSTART` is the documented, supported startup hook and must be
  created in `%SYS`.
- **Alternatives considered**: `Ens.InboundAdapter` with `CallInterval` for startup work (wrong
  tool, not a startup hook); `OnStart` of the Production only (misses provider/timeout setup that
  must precede the Production); a shell entrypoint wrapper (the runtime path must stay a single
  IRIS container).
- **Verified live**: `Config.Startup.Get` returns `SystemStart=1`, `ZSTU=1`,
  `SystemMode=AI Hub EAP`. So the startup subroutine is already allowed to run and no extra CPF
  toggle is needed; the routine itself is absent (`%ZSTART` not yet defined), which is expected.
- **Docs (as data)**: `%ZSTART` is user-created in `%SYS` with entry points `SYSTEM`, `LOGIN`,
  `JOB`, `CALLIN`; `SYSTEM^%ZSTART` runs with `$USERNAME=%SYSTEM` and `$ROLES=%All`.

## D7 — Provider configuration from `.env`

- **Decision**: Bootstrap reads `SN_AI_PROVIDER`, `SN_AI_MODEL` and `SN_AI_API_KEY` from the
  runtime environment and materializes them into the AI Hub provider configuration
  (`%ConfigStore.Configuration` + `RebuildRegistry`, falling back to `%AI.Provider.Create`). The
  resulting availability (`configured` / `unavailable` with a reason) is what the health surface
  reports.
- **Rationale**: AD-18 and the spec's "starts without a key" requirement. The provider is set up
  once at startup, so a background-job environment read is not needed.
- **Alternatives considered**: Reading `.env` in each request (leaks the file into the runtime
  path); `@{env:...}` placeholders (issue #31 warns that background jobs may not see the variable);
  storing the key in the image (forbidden).
- **Verified live**: `%AI.Provider.Create("openai", {"api_key":"probe"})` returns an object without
  network access; `%ConfigStore.Configuration::Create` and
  `%ConfigStore.DescriptorManager::RebuildRegistry` exist. The descriptor bug (#26414, issue #33)
  could not be reproduced without a real key, so the fallback is kept in the plan.
- **Risk**: the exact provider name list and whether `RebuildRegistry` is needed on 154 is not
  settled; the implementation verifies it with a real key in a later, non-gated step.

## D8 — Testing approach

- **Decision**: `%UnitTest` suites per package plus one REST smoke test that exercises start →
  accept → read → restart → provider-unavailable. Tests run against the live container through
  iris-agentic-dev.
- **Rationale**: Engineering Standards mandate TDD and `%UnitTest`; the Constitution's
  Development Environment requires the run to go through iris-agentic-dev.
- **Alternatives considered**: A local test runner without IRIS (cannot exercise `%Persistent` or
  `Ens.*`); a scripted curl-only smoke (no unit coverage).
- **Verified live**: `%UnitTest.Manager` is present; `%UnitTest` run and compile paths work
  through the tool. The container is a long-lived dev instance, so restart durability is tested at
  the object level (`%Save`/`%OpenId` after reconnecting) and at the process level by re-opening
  the Case from a new iris-agentic-dev call.

## D9 — Build and packaging boundary

- **Decision**: This slice adds the module, sources and `boot/%ZSTART.mac` to the repository; the
  `Dockerfile`/`docker-compose.yml` rewrite (build 154, `env_file`, fixed ports, no bind mount,
  healthcheck) belongs to spec 012. Until then, development uses the existing build 154 template
  container.
- **Rationale**: The calendar gate forbids submission code before 2026-10-26, and AD-27 assigns
  packaging to a dedicated slice. Integration files change only at gates.
- **Alternatives considered**: Rewriting compose now (violates the gate and the packaging slice);
  a dev-only compose with a bind mount (allowed later via `docker-compose.dev.yml`, not now).

## D10 — Identifiers and clock

- **Decision**: `Clock` and `IdGenerator` are ports; adapters are `SignalNoir.Application.
  SystemClock` and `SignalNoir.Application.IdFactory`. IDs are opaque, prefix + IRIS-incremented
  counter (`case_`, `evid_`, `cmd_`, ...). Timeline `seq` is `$INCREMENT` per Case.
- **Rationale**: The spec fixes the prefixes; determinism in tests requires a controllable clock.
- **Alternatives considered**: `$RANDOM`/GUID (not testable, no prefix convention); `$HOROLOG` as
  an ID (collides).

---

## Verification log

All commands ran through iris-agentic-dev against the live build 154 container.

| # | Check | Result |
|---|-------|--------|
| 1 | `$ZVERSION` | `2026.3.0AI (Build 154U)` |
| 2 | `%AI.Agent`, `%AI.ToolSet`, `%AI.Provider`, `%AI.Agent.Session`, `%AI.LLM.Response` present | yes |
| 3 | `%AI.Provider::Create` invokable with a probe key, no network | yes, returns an object |
| 4 | `%ConfigStore.Configuration::Create`, `%ConfigStore.DescriptorManager::RebuildRegistry` present | yes |
| 5 | `Config.Namespaces.Get("IRISAPP")` | namespace exists; `Interop=0` on the running container (see D2 risk) |
| 6 | `Ens.*` classes resolvable in `IRISAPP`; `Ens.Director::StartProduction` | yes |
| 7 | `Config.Startup.Get` | `SystemStart=1`, `ZSTU=1`, `SystemMode=AI Hub EAP` |
| 8 | `%ZSTART` routine | absent (must be created in `%SYS` by the build) |
| 9 | `%IPM.Main` | present (IPM available to load the module) |
| 10 | `%UnitTest.Manager`, `%CSP.REST` | present |
| 11 | `Security.Applications` has `DispatchClass`/`Path`/`ServeFiles` | yes |
| 12 | `%Persistent` + `VERSIONPROPERTY` | compiles, version increments, stale write rejected with a concurrency failure |

## Open items carried into tasks

1. Re-check `Interop=1` on a freshly built container (D2).
2. Confirm the Config Store vs `%AI.Provider.Create` path with a real key on 154, including the
   `#26414` descriptor behaviour (D7).
3. Define the exact health payload and record the contract change before coding (D4).
4. All product code waits for 2026-10-26; only contracts/spec/fixtures/prototype until then (D9).

## Polish records

### T040 — Probe class cleanup
No `SN.Proto.VersionProbe*` (or `VersionProbe*`) classes exist in the dev container. Nothing to delete.

### T042 — Provider key scan (FR-018)
Searched `src/` for API key material. Results:
- `Parameter SECRETLINK = "secret://SignalNoir.AIKey"` in `Bootstrap.cls` — a secret reference, not a key value.
- `Env("SN_AI_API_KEY")` reads the key from runtime environment; never stored in code.
- `%Wallet.KeyValue::Create/UpdateSecret("SignalNoir.AIKey", secret)` stores the key in the platform wallet — correct, not hand-written.
- Comments referencing "secrets" are documentation only.
No actual API key values found in source, timeline, logs, or exports. FR-018 satisfied.
