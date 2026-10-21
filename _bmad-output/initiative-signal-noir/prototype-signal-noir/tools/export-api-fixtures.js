// Exports deterministic API fixtures from the prototype engine into contracts/fixtures/.
// Usage (from the repo root): node _bmad-output/initiative-signal-noir/prototype-signal-noir/tools/export-api-fixtures.js contracts/fixtures
// Every file is a real response of the mock API at a known state; manifest.json maps it to the
// operation and the contract schema it must satisfy (checked by contracts/tools/validate_fixtures.py).
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const out = process.argv[2];
if (!out) { console.error('usage: export-api-fixtures.js <out dir>'); process.exit(2); }
const proto = path.join(__dirname, '..');
const ctx = { window: {}, console };
vm.createContext(ctx);
for (const f of ['fixtures.js', 'engine.js']) vm.runInContext(fs.readFileSync(path.join(proto, f), 'utf8'), ctx, { filename: f });
const E = ctx.window.SN_ENGINE;

const manifest = [];
fs.mkdirSync(out, { recursive: true });
fs.readdirSync(out).filter(f => f.endsWith('.json')).forEach(f => fs.unlinkSync(path.join(out, f)));

function save(file, operation, res, schema, description) {
  fs.writeFileSync(path.join(out, file), JSON.stringify(res.body, null, 2) + '\n');
  manifest.push({ file, operation, status: res.status, schema, description });
}
const until = (id, pred, max = 200) => { for (let i = 0; i < max; i++) { const c = E.S.cases.get(id); if (c && pred(c)) return; E.tick(); } throw new Error('state not reached for ' + id); };
const cur = id => E.S.cases.get(id);
const approve = (id, extra) => E.api.decide(id, cur(id).currentProposalId, Object.assign({ decision: 'approved', operator: 'Carla', expectedCaseVersion: cur(id).caseVersion }, extra));

E.reset();

// Seeded cases settle: P5/P8b waits for approval, the two dossier cases reach ReviewRequired.
until('case_9f3a1c', c => c.state === 'PendingApproval');
until('case_a37b5d', c => c.state === 'ReviewRequired');
until('case_0b6f19', c => c.state === 'ReviewRequired');
save('cases.list.needs-you.json', 'GET /cases', E.api.listCases(), 'CaseListPage', 'List with one case waiting for approval, two in review and one resolved.');
save('case.pending-approval.p5-p8b.json', 'GET /cases/{caseId}', E.api.getCase('case_9f3a1c'), 'CaseDetail', 'P5/P8b: lying 500, two approved mappings, proposal APPLY_APPROVED_MAPPING waiting for approval.');
save('timeline.full.p5-p8b.json', 'GET /cases/{caseId}/timeline', E.api.getTimeline('case_9f3a1c', 0), 'TimelinePage', 'Full timeline from sinceSeq=0 up to PendingApproval.');
const seq = cur('case_9f3a1c').lastEventSeq;

save('decision.201.approved.json', 'POST /cases/{caseId}/proposals/{proposalId}/decision', approve('case_9f3a1c'), 'ProposalDecisionResult', 'Approval recorded; case moves to Approved.');
save('decision.200.idempotent-replay.json', 'POST /cases/{caseId}/proposals/{proposalId}/decision', E.api.replayLastDecision('case_9f3a1c'), 'ProposalDecisionResult', 'Same proposal approved again: existing approval, idempotentReplay true, no new effect.');
until('case_9f3a1c', c => c.state === 'Resolved');
save('timeline.incremental.p5-p8b.json', 'GET /cases/{caseId}/timeline', E.api.getTimeline('case_9f3a1c', seq), 'TimelinePage', 'Incremental page (sinceSeq) from PendingApproval to Resolved.');
save('case.resolved.p5-p8b.json', 'GET /cases/{caseId}', E.api.getCase('case_9f3a1c'), 'CaseDetail', 'Resolved: revalidation passed, mapping applied, one attempt, partner receipt.');

// Stale version.
E.runScenario('stale');
until('case_51b0e2', c => c.state === 'PendingApproval');
const oldProp = cur('case_51b0e2').currentProposalId, oldVer = cur('case_51b0e2').caseVersion;
E.hook('case_51b0e2', 'onDialogOpen');
until('case_51b0e2', c => c.currentProposalId !== oldProp && c.state === 'PendingApproval');
save('decision.409.stale-version.json', 'POST /cases/{caseId}/proposals/{proposalId}/decision', E.api.decide('case_51b0e2', oldProp, { decision: 'approved', operator: 'Carla', expectedCaseVersion: oldVer }), 'ErrorEnvelope', 'Proposal superseded while the dialog was open: nothing approved.');
save('case.pending-approval.superseded.json', 'GET /cases/{caseId}', E.api.getCase('case_51b0e2'), 'CaseDetail', 'Case with an obsoleted evidence and an earlier, superseded proposal.');

// Validation and transition errors.
save('decision.400.denial-without-reason.json', 'POST /cases/{caseId}/proposals/{proposalId}/decision', E.api.decide('case_51b0e2', cur('case_51b0e2').currentProposalId, { decision: 'denied', operator: 'Carla', expectedCaseVersion: cur('case_51b0e2').caseVersion }), 'ErrorEnvelope', 'Denial without reason.');
save('decision.409.invalid-transition.json', 'POST /cases/{caseId}/proposals/{proposalId}/decision', E.api.decide('case_0b6f19', cur('case_0b6f19').currentProposalId, { decision: 'approved', operator: 'Carla', expectedCaseVersion: cur('case_0b6f19').caseVersion }), 'ErrorEnvelope', 'Deciding on a case that is not in PendingApproval.');
save('case.404.json', 'GET /cases/{caseId}', E.api.getCase('case_missing'), 'ErrorEnvelope', 'Unknown case.');

// Denial path.
E.runScenario('p3-cancel');
until('case_c4e1a9', c => c.state === 'PendingApproval');
save('decision.201.denied.json', 'POST /cases/{caseId}/proposals/{proposalId}/decision', E.api.decide('case_c4e1a9', cur('case_c4e1a9').currentProposalId, { decision: 'denied', operator: 'Carla', expectedCaseVersion: cur('case_c4e1a9').caseVersion, reason: 'Partner B announced a maintenance window by phone.' }), 'ProposalDecisionResult', 'Denial recorded; the reason becomes evidence for one more investigation.');
until('case_c4e1a9', c => c.state === 'ReviewRequired');
save('case.review.after-denial.json', 'GET /cases/{caseId}', E.api.getCase('case_c4e1a9'), 'CaseDetail', 'After a denial the agent requests review: dossier review_requested.');

// P3: held after a failed revalidation.
E.runScenario('p3-held');
until('case_7d22e0', c => c.state === 'PendingApproval');
approve('case_7d22e0');
until('case_7d22e0', c => c.state === 'Held');
save('case.held.p3.json', 'GET /cases/{caseId}', E.api.getCase('case_7d22e0'), 'CaseDetail', 'P3: revalidation failed PARTNER_HEALTHY_WINDOW before sending; nothing sent.');

// Lost response: outcome unknown.
E.runScenario('lost-response');
until('case_e8a0f4', c => c.state === 'PendingApproval');
approve('case_e8a0f4');
until('case_e8a0f4', c => c.executions.length && c.executions[0].outcome === 'reconciling');
E.runAction('case_e8a0f4', 'new-proposal');
save('case.executing.outcome-unknown.json', 'GET /cases/{caseId}', E.api.getCase('case_e8a0f4'), 'CaseDetail', 'Timeout after send: execution reconciling, new proposal discarded.');
save('cases.list.outcome-unknown.json', 'GET /cases', E.api.listCases(), 'CaseListPage', 'List including a case whose executionOutcome is reconciling.');
until('case_e8a0f4', c => c.state === 'Resolved');
save('case.resolved.by-reconciliation.json', 'GET /cases/{caseId}', E.api.getCase('case_e8a0f4'), 'CaseDetail', 'Receipt found by reconciliation; no resend.');

// Dossiers and operator resolution.
save('case.review.provider-unavailable.json', 'GET /cases/{caseId}', E.api.getCase('case_a37b5d'), 'CaseDetail', 'Provider unavailable: dossier with unknowns and no diagnosis.');
const pd = cur('case_a37b5d');
save('resolution.422.validator-blocked.json', 'POST /cases/{caseId}/resolution', E.api.resolve('case_a37b5d', { kind: 'action', operator: 'Carla', expectedCaseVersion: pd.caseVersion, action: 'APPLY_APPROVED_MAPPING', params: { mappingId: 'map_glicj_soro', mappingVersion: '2026.10.1' } }), 'ErrorEnvelope', 'Operator picks a mapping whose condition does not match: validator blocks.');
save('resolution.201.action.json', 'POST /cases/{caseId}/resolution', E.api.resolve('case_a37b5d', { kind: 'action', operator: 'Carla', expectedCaseVersion: pd.caseVersion, action: 'APPLY_APPROVED_MAPPING', params: { mappingId: 'map_glicj_plasma', mappingVersion: '2026.10.1' }, note: 'Specimen is PLASMA.' }), 'ReviewResolutionResult', 'Operator mapping accepted by the validator and approved by the same operator.');
save('case.review.ambiguous-identity.json', 'GET /cases/{caseId}', E.api.getCase('case_0b6f19'), 'CaseDetail', 'Ambiguous identity: colliding records with divergent fields.');
save('resolution.201.cancel.json', 'POST /cases/{caseId}/resolution', E.api.resolve('case_0b6f19', { kind: 'cancel', operator: 'Carla', expectedCaseVersion: cur('case_0b6f19').caseVersion, reason: 'Origin will resend with the confirmed patient.' }), 'ReviewResolutionResult', 'Case cancelled from the dossier.');

// P9 (conditional).
E.runScenario('p9');
until('case_d91c07', c => c.state === 'ResolvedByPriorReceipt');
save('case.resolved-by-prior-receipt.p9.json', 'GET /cases/{caseId}', E.api.getCase('case_d91c07'), 'CaseDetail', 'P9: prior receipt confirmed by the validator; no execution.');

// Reference data.
const mappings = E.S.cases && window_mappings();
function window_mappings() { return ctx.window.SN_FIXTURES.REF.mappings; }
fs.writeFileSync(path.join(out, 'reference.mappings.json'), JSON.stringify({ mappingVersion: '2026.10.1', items: mappings, serverTime: E.iso(E.now()) }, null, 2) + '\n');
manifest.push({ file: 'reference.mappings.json', operation: 'GET /reference/mappings', status: 200, schema: '#/paths/~1reference~1mappings/get/responses/200/content/application~1json/schema', description: 'Approved mappings used by the prototype scenarios.' });

fs.writeFileSync(path.join(out, 'manifest.json'), JSON.stringify({
  contract: 'contracts/openapi-signalnoir.yaml',
  generatedBy: '_bmad-output/initiative-signal-noir/prototype-signal-noir/tools/export-api-fixtures.js',
  note: 'Synthetic data only. Deterministic: re-running the exporter produces the same files.',
  fixtures: manifest
}, null, 2) + '\n');
console.log('wrote ' + (manifest.length) + ' fixtures to ' + out);
