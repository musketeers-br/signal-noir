# Data Model: Agent Prompt v2

No persisted shape changes. Two values change meaning or content:

| Item | Where | Before | After |
|------|-------|--------|-------|
| Prompt version | `SignalNoir.Proposers.Agent.PROMPTVERSION`; recorded as `versions.prompt` on every Agent Proposal and in `details.promptVersion` of the Investigation | `agent-v1` | `agent-v2` |
| Agent instructions | `SignalNoir.Proposers.Agent` XData `SystemPrompt` | agent-v1 text | [contracts/agent-v2-instructions.md](./contracts/agent-v2-instructions.md) |

Evidence fields the instructions refer to (read-only, unchanged):

| Evidence source | Fields used |
|-----------------|-------------|
| `tool.receipts_and_orders_by_patient` | patient records (identity collision) |
| `tool.partner_health` | `status` (UP/DOWN), `maintenance.active` |
| `tool.partner_failure_history` | `window.total`, `window.timeouts`, `window.errors`, `items[].outcome` |
| `tool.policies` | `attempt.maxAttempts`, `maintenanceWindows` |
| `tool.mapping_catalog` | `items[]` (`mappingId`, `mappingVersion`, `sourceCode`, `conditions`), `synonyms` |
| `system.exception` | `kind`, `httpStatus` |
