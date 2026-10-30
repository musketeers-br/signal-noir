# Data Model: Correction 009b

No persisted shape changes. One rule changes value:

| Action | externalEffect | requiresApproval (before) | requiresApproval (after) |
|---|---|---|---|
| `RETRY` | true | true | true |
| `APPLY_APPROVED_MAPPING` | true | true | true |
| `HOLD` | false | false | false |
| `REQUEST_REVIEW` | false | **true** | **false** |

Readers: `ActionCatalogEntry.requiresApproval` (catalog endpoint, console mock) and
`ValidatorVerdict.requiresApproval` (recorded on `ProposalRecord.verdictJson` and in the
`ValidatorVerdict` event). Earlier recorded verdicts are history and are not rewritten.
