# Quickstart: Correction 009b

## Tests

Through iris-agentic-dev (see 003 quickstart): `Core.TestActionCatalog`,
`Application.TestInvestigation`, `Api.TestResolutionApi`, then the full suite.

```sh
cd ui && npm test
```

## Live check

```sh
PORT=$(docker port signalnoir-iris 52773 | head -1 | cut -d: -f2)
curl -s "http://localhost:$PORT/signalnoir/api/v1/reference/action-catalog"
uv run --with jsonschema --with pyyaml --with requests python tests/contract/validate_live.py --base "http://localhost:$PORT/signalnoir/api/v1"
```

| Check | Expect |
|---|---|
| catalog | `requiresApproval` equals `externalEffect` for all four Actions |
| a P5 investigation | Case in `ReviewRequired`; its `ValidatorVerdict` says `requiresApproval: false` |
| contract | all responses conform |
