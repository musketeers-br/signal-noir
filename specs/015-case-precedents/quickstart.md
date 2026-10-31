# Quickstart: Case Precedents

Contract: [contracts/contract-change-015-precedents.md](./contracts/contract-change-015-precedents.md).
Model and config: [data-model.md](./data-model.md).

## Prerequisites

- The dev instance up (`signalnoir-iris`, build 154) and iris-agentic-dev configured
  (`.iris-agentic-dev.toml`, git-ignored).
- No embedding key needed: every scenario below except the last one runs in lexical mode.

## Tests (iris-agentic-dev)

Compile `src/` and run the 015 suites: `Core.TestPrecedentText`, `Core.TestLexicalVector`,
`Application.TestPrecedentIndex`, `Application.TestPrecedentSearch`,
`Application.TestPrecedentNeutrality`, `Api.TestPrecedentsApi`, plus the existing 003–009 suites
(nothing may regress, SC-002).

Expected:

| Scenario | Proves |
|---|---|
| Close one Case of each terminal state, one Benchmark Case, one Replay Case; run `IndexPending()` twice | one record per eligible Case, none for Benchmark/Replay (SC-004) |
| Order note with "ignore previous instructions…" | not in `rawText`, `factsJson` or any Timeline payload (SC-005) |
| Reference set of families, new Case per family, lexical mode, run twice | top-1 same family ≥ 90%, identical ranking both runs (SC-001) |
| Empty index / all below minimum / `rebuilding` flag / stale model only / embedder returning an error | the six distinct `status` values, Case read still OK (SC-007) |
| Same Cases with feature on and off (`TestPrecedentNeutrality`) | Proposals, verdicts, Approvals, executions, resolutions identical; Timelines differ only by `precedent_search` Annotations (SC-002) |
| Insert 1,000 synthetic records, search | under 1 s (SC-006) |
| Rebuild after switching model, kill midway, rebuild again | count = eligible Cases, no duplicates, no row of the old model (SC-008) |
| Default config and frozen-run config | `AgentEnabled()` = 0 (SC-010) |

## Live API

```sh
PORT=$(docker port signalnoir-iris 52773 | head -1 | cut -d: -f2)
curl -s "http://localhost:$PORT/signalnoir/api/v1/cases/<caseId>/precedents?k=5"
curl -s "http://localhost:$PORT/signalnoir/api/v1/cases/<caseId>/timeline" | grep precedent_search
uv run --with jsonschema --with pyyaml --with requests python tests/contract/validate_live.py --base "http://localhost:$PORT/signalnoir/api/v1"
python3 contracts/tools/validate_fixtures.py
```

Expected: `status` and `mode: lexical` in the answer; one `precedent_search` Annotation; a second
call within a minute answers `recorded: false` and adds no event.

## Rebuild

```sh
iris-agentic-dev exec 'Write ##class(SignalNoir.Application.PrecedentService).Rebuild().%ToJSON()'
```

## Console

`cd ui && npm test` (panel statuses, no pre-selection in the resolution form, axe light/dark), then
open `/signalnoir/`, open a `ReviewRequired` Case: "Similar resolved Cases" sits next to the
next-step box, labelled "Lexical similarity (no embedding provider)".

## Provider mode (needs a key, not part of CI)

Set `SN_EMBED_PROVIDER=openai`, `SN_EMBED_MODEL=text-embedding-3-small`, `SN_EMBED_API_KEY` in the
container environment, restart, run `Rebuild()`, and search again: `mode: provider`,
`model: text-embedding-3-small`, `dimension: 1536`. Record the result in research R3 before the README
claims provider mode works.
