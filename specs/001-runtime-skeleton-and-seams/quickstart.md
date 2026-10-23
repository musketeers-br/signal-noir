# Quickstart: runtime skeleton and shared seams (feature 001)

A run guide to prove the walking skeleton end to end. It assumes the build 154 container is
running and that development goes through iris-agentic-dev.

## Prerequisites

- Docker with the build 154 image loaded and retagged (see `docs/ai-hub-start.md`).
- The container up, reachable at `1972` (superserver) and `52773` (web).
- iris-agentic-dev configured for the instance (`IRIS_HOST`, `IRIS_WEB_PORT`, `IRIS_USERNAME`,
  `IRIS_PASSWORD`, `IRIS_NAMESPACE=IRISAPP`).
- Namespace `IRISAPP` with Interoperability enabled (verify per research.md D2).

## 1. Build and load the module

Load the `signalnoir` IPM module (sources under `src/`, tests under `tests/`) and compile. From
the repository root, through iris-agentic-dev:

```text
# load + compile the module sources
# (exact command is the implementation's; the module name is "signalnoir")
```

Expected: module loads, `SignalNoir.*` classes compile, no errors.

## 2. Install the startup routine

Install `boot/%ZSTART.mac` into the `%SYS` namespace and confirm it is picked up:

```text
# zn "%SYS"; load boot/%ZSTART.mac; compile
```

Expected: `^%ZSTART` exists in `%SYS` and `Config.Startup` reports `SystemStart=1` (already the
default).

## 3. Start with a valid key

Set `SN_AI_PROVIDER`, `SN_AI_MODEL`, `SN_AI_API_KEY` in the container environment and restart the
instance so `SYSTEM^%ZSTART` runs. Then read health:

```bash
curl -s http://localhost:52773/signalnoir/api/v1/health
```

Expected: `status=ready`, `liveness=alive`, `provider.configured=true`.

## 4. Start without a key

Remove `SN_AI_API_KEY` and restart. Read health again.

Expected: `status=degraded`, `provider.configured=false`, and `reason` naming the unavailable
provider. The process stays up.

## 5. Accept, read, restart

1. Accept one synthetic Order through the Production Business Service (or the `CaseCommands`
   seam in the automated test).
2. Read it back:

   ```bash
   curl -s http://localhost:52773/signalnoir/api/v1/cases
   curl -s http://localhost:52773/signalnoir/api/v1/cases/<caseId>
   ```

   Expected: the Case is present with `synthetic=true` and a non-empty timeline.
3. Without a key, the Case ends in `ReviewRequired` with a reason naming the provider.
4. Restart the instance and read the Case again.

   Expected: same state, same `caseVersion`, same timeline, unchanged.

## 6. Run the automated tests

Run the `%UnitTest` suites for this feature through iris-agentic-dev, then the smoke test.

Expected: the Core, Application, Api and Interop suites pass, and the smoke test exercises
start → accept → read → restart → provider-unavailable.

## 7. Prove the seam for a consumer

Compile a trivial consumer that imports only `docs/seams.md` ports/DTOs and the fakes under
`tests/SignalNoir/Tests/Fakes`.

Expected: it compiles and its tests pass without editing any file of feature 001, and the fakes
are absent from the runtime resource.

## Reference

- Seam contract: [contracts/seams.md](./contracts/seams.md) → published as `docs/seams.md`.
- Health contract change: [contracts/contract-change-001-health.md](./contracts/contract-change-001-health.md).
- Data model: [data-model.md](./data-model.md).
- Platform research and verification log: [research.md](./research.md).
