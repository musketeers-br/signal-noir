# Quickstart: Review Dossier and Operator Resolution

## Tests

Compile and run the suites through iris-agentic-dev (see 003 quickstart). 009 suites:
`Core.TestDossierBuilder`, `Core.TestResolutionShape`, `Core.TestActionCatalog`,
`Application.TestDossier`, `Application.TestResolution`, `Api.TestResolutionApi`.

## Live API

```sh
PORT=$(docker port congenial-waffle-iris-1 52773 | head -1 | cut -d: -f2)
curl -s "http://localhost:$PORT/signalnoir/api/v1/reference/action-catalog"
curl -s -X POST "http://localhost:$PORT/signalnoir/api/v1/cases/<caseId>/resolution" \
  -H 'Content-Type: application/json' \
  -d '{"kind":"cancel","operator":"Carla","expectedCaseVersion":2,"reason":"duplicate"}'
uv run --with jsonschema --with pyyaml --with requests python tests/contract/validate_live.py --base "http://localhost:$PORT/signalnoir/api/v1"
```

## Console

Open `/signalnoir/`, filter Needs you, open a `ReviewRequired` Case: the Dossier is first; resolve
or cancel from its form.
