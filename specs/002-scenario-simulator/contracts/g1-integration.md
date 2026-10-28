# Gate G1 integration notes for feature 002

For the gate integrator. Nothing here was applied in the feature branch (integration files and
001's bootstrap are edited only at the gate).

1. **Register the Simulator at start.** Add to `SignalNoir.Interop.Bootstrap.OnStart`:
   `Do ##class(SignalNoir.Sim.Setup).EnsureWebApplication()`. It is idempotent and leaves an
   existing registration of the same dispatcher alone.
2. **Point the product's Tools at it.** Set `SN_SIM_BASE_URL=http://localhost:52773/sim/api/v1` in
   `.env.example` and the dev kit. `SignalNoir.Tools.SimulatorSource.Base()` reads the variable and,
   when it is unset, the instance setting `^SignalNoir.Config("simBaseUrl")`; the dev container was
   switched on that way on 2026-10-28 (recreating it would wipe its database).
3. **CI (optional, with the workflow owner).** Run
   `uv run --with jsonschema --with pyyaml python tests/sim-contract/validate_sim_captures.py` on the
   committed captures in `.github/workflows/contracts.yml`.
4. **Origin feed reader — done (2026-10-28, Henry), product code outside 002's write zone.**
   `SignalNoir.Interop.Service.OriginFeed.Poll()` reads the feed after its cursor, accepts each
   Order through `OrderIn.Accept`, makes the first delivery to the Partner (FR-2, one Attempt with a
   key stable per Order), reports the Exception when no valid Receipt comes back (FR-3) and delivers
   the Case's `Investigate` request. Tests: `SignalNoir.Tests.Interop.TestOriginFeed`. At the gate:
   schedule `Poll()` (the inbound Business Service's polling in the Production) and call
   `SkipToHead()` once on an instance whose feed already holds test items.
   Verified live: a P8b Order went from the Simulator's feed to a Case opened by the Partner's 500,
   and the agent's Tools read health, history, Origin status and receipts from the Simulator. The
   mapping catalog and the policies are still absent until 004 loads the reference data, so the
   agent cannot propose a mapping yet (it proposed `HOLD`).
5. **Confirm with 006/008.**
   - P3 triggers fire on the 2nd read of health or Origin status (research D12); confirm the count
     against the product's evidence and revalidation reads.
   - `SN_PARTNER_TIMEOUT_SECONDS` is the single source of the client timeout (research D6). The
     Partner holds a scripted timeout for `max(clientTimeout + 5 s, 90 s × timeScale)`, measured at
     65.0 s with the default 60 s; for SC-008's 3-minute quick validation, the product must run with
     a short client timeout, since the floor follows it.
