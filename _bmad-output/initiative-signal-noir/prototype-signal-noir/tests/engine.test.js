// Engine smoke test (no browser): node tests/engine.test.js .
const fs = require('fs'), path = require('path'), vm = require('vm');
const dir = process.argv[2];
const ctx = { window: {}, console };
vm.createContext(ctx);
for (const f of ['fixtures.js', 'engine.js']) vm.runInContext(fs.readFileSync(path.join(dir, f), 'utf8'), ctx, { filename: f });
const E = ctx.window.SN_ENGINE;
let fails = 0;
const ok = (cond, msg) => { console.log((cond ? 'ok   ' : 'FAIL ') + msg); if (!cond) fails++; };
const st = id => E.S.cases.get(id).state;
const until = (id, pred, max = 120) => { for (let i = 0; i < max; i++) { if (pred(E.S.cases.get(id))) return true; E.tick(); } return pred(E.S.cases.get(id)); };
const approveBody = (id, extra) => { const c = E.S.cases.get(id); return E.api.decide(id, c.currentProposalId, Object.assign({ decision: 'approved', operator: 'Henrique', expectedCaseVersion: c.caseVersion }, extra)); };

E.reset();
ok(E.api.listCases().body.items.length === 4, 'seeded 4 cases');
ok(st('case_2a90b4') === 'Resolved', 'history case Resolved');

// P5/P8b
ok(until('case_9f3a1c', c => c.state === 'PendingApproval'), 'p5 reaches PendingApproval');
let c = E.S.cases.get('case_9f3a1c');
ok(c.proposals[0].params.mappingId === 'map_glicj_soro', 'p5 proposes soro mapping');
ok(c.diagnosis.claims.every(cl => cl.evidenceIds.every(e => c.evidence.some(x => x.evidenceId === e))), 'p5 claims reference existing evidence');
ok(E.api.decide('case_9f3a1c', c.currentProposalId, { decision: 'approved', operator: 'a:b', expectedCaseVersion: c.caseVersion }).status === 400, 'operator with colon → 400');
let r = approveBody('case_9f3a1c');
ok(r.status === 201 && !r.body.idempotentReplay, 'approve → 201');
r = E.api.replayLastDecision('case_9f3a1c');
ok(r.status === 200 && r.body.idempotentReplay === true, 'replay approval → 200 idempotentReplay');
ok(until('case_9f3a1c', c => c.state === 'Resolved'), 'p5 Resolved');
c = E.S.cases.get('case_9f3a1c');
ok(c.executions.length === 1 && c.executions[0].attempts.length === 1, 'exactly one execution and one attempt');
ok(c.order.transformed && c.order.transformed.payload.exams[0].code === 'GLIC-S', 'payload transformed to GLIC-S');
r = E.api.replayLastDecision('case_9f3a1c');
ok(r.status === 200 && E.S.cases.get('case_9f3a1c').executions.length === 1, 'replay after resolve: no new execution');

// stale
E.runScenario('stale');
ok(until('case_51b0e2', c => c.state === 'PendingApproval'), 'stale reaches PendingApproval');
c = E.S.cases.get('case_51b0e2');
const oldProp = c.currentProposalId, oldVer = c.caseVersion;
E.hook('case_51b0e2', 'onDialogOpen');
ok(until('case_51b0e2', c => c.currentProposalId !== oldProp && c.state === 'PendingApproval'), 'stale: new proposal version pending');
r = E.api.decide('case_51b0e2', oldProp, { decision: 'approved', operator: 'Henrique', expectedCaseVersion: oldVer });
ok(r.status === 409 && r.body.error.code === 'STALE_VERSION', 'old version → 409 STALE_VERSION');
ok(E.S.cases.get('case_51b0e2').approvals.length === 0, 'nothing approved after 409');
ok(E.S.cases.get('case_51b0e2').evidence.some(e => e.obsoletedBy), 'old catalog evidence obsoleted');
r = approveBody('case_51b0e2');
ok(r.status === 201, 'approve new version → 201');
ok(until('case_51b0e2', c => c.state === 'Resolved'), 'stale Resolved');

// P3 held
E.runScenario('p3-held');
ok(until('case_7d22e0', c => c.state === 'PendingApproval'), 'p3-held PendingApproval');
approveBody('case_7d22e0');
ok(until('case_7d22e0', c => c.state === 'Held'), 'p3-held → Held');
c = E.S.cases.get('case_7d22e0');
ok(c.executions[0].attempts.length === 0, 'Held: no attempt sent');
ok(until('case_7d22e0', c => c.state === 'PendingApproval'), 'p3-held re-investigated → PendingApproval');
ok(E.S.cases.get('case_7d22e0').proposals.length === 2, 'p3-held: new proposal version');
approveBody('case_7d22e0');
ok(until('case_7d22e0', c => c.state === 'Resolved'), 'p3-held Resolved after second approval');

// P3 cancel
E.runScenario('p3-cancel');
until('case_c4e1a9', c => c.state === 'PendingApproval');
approveBody('case_c4e1a9');
ok(until('case_c4e1a9', c => c.state === 'Cancelled'), 'p3-cancel → Cancelled');
ok(E.S.cases.get('case_c4e1a9').executions[0].attempts.length === 0, 'Cancelled: nothing sent');

// lost response
E.runScenario('lost-response');
until('case_e8a0f4', c => c.state === 'PendingApproval');
approveBody('case_e8a0f4');
ok(until('case_e8a0f4', c => c.executions.length && c.executions[0].outcome === 'reconciling'), 'lost-response: outcome unknown');
let acts = E.scenarioActions('case_e8a0f4');
ok(acts.every(a => a.enabled), 'uncertain actions enabled');
E.runAction('case_e8a0f4', 'new-proposal');
ok(E.api.listCases().body.items.find(i => i.caseId === 'case_e8a0f4').executionOutcome === 'reconciling', 'draft.2: list shows executionOutcome reconciling');
E.runAction('case_e8a0f4', 'restart');
ok(E.S.cases.get('case_e8a0f4').executions[0].leaseGeneration === 2, 'draft.2: restart bumps leaseGeneration to 2');
ok(E.S.cases.get('case_e8a0f4')._timeline.some(e => e.type === 'CommandDiscarded'), 'new proposal discarded');
ok(until('case_e8a0f4', c => c.state === 'Resolved'), 'lost-response Resolved by reconciliation');
c = E.S.cases.get('case_e8a0f4');
ok(c.receipt.source === 'reconciliation' && c.executions[0].attempts.length === 1, 'receipt via reconciliation, single attempt');

// provider down
ok(until('case_a37b5d', c => c.state === 'ReviewRequired'), 'provider-down → ReviewRequired');
c = E.S.cases.get('case_a37b5d');
ok(c.dossier.reason === 'provider_unavailable' && c.proposals.length === 0, 'dossier provider_unavailable, no proposal');
ok(E.api.getCase('case_a37b5d').body.dossier.unknowns.length === 2 && E.api.getCase('case_a37b5d').body.dossier.unknowns[0].topic === 'diagnosis', 'draft.2: dossier.unknowns exposed by the API');
r = E.api.resolve('case_a37b5d', { kind: 'action', operator: 'Henrique', expectedCaseVersion: c.caseVersion, action: 'APPLY_APPROVED_MAPPING', params: { mappingId: 'map_glicj_soro', mappingVersion: '2026.10.1' } });
ok(r.status === 422 && r.body.error.details.verdict.reasons.includes('MAPPING_CONDITION_MISMATCH'), 'wrong mapping → 422 MAPPING_CONDITION_MISMATCH');
r = E.api.resolve('case_a37b5d', { kind: 'action', operator: 'Henrique', expectedCaseVersion: c.caseVersion, action: 'RETRY', params: {} });
ok(r.status === 422 && r.body.error.details.verdict.reasons.includes('POLICY_CODE_DISCONTINUED'), 'retry → 422 POLICY_CODE_DISCONTINUED');
r = E.api.resolve('case_a37b5d', { kind: 'action', operator: 'Henrique', expectedCaseVersion: c.caseVersion, action: 'APPLY_APPROVED_MAPPING', params: { mappingId: 'map_glicj_plasma', mappingVersion: '2026.10.1' } });
ok(r.status === 201, 'right mapping → 201');
ok(until('case_a37b5d', c => c.state === 'Resolved'), 'provider-down Resolved by operator');

// ambiguous
ok(until('case_0b6f19', c => c.state === 'ReviewRequired'), 'ambiguous → ReviewRequired');
c = E.S.cases.get('case_0b6f19');
ok(c.dossier.collidingRecords.length === 2, 'dossier has 2 colliding records');
r = E.api.resolve('case_0b6f19', { kind: 'action', operator: 'Henrique', expectedCaseVersion: c.caseVersion, action: 'RETRY', params: {} });
ok(r.status === 422 && r.body.error.details.verdict.reasons.includes('IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION') && r.body.error.details.verdict.verdict === 'review', 'retry on ambiguous → 422 IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION (a review)');
r = E.api.resolve('case_0b6f19', { kind: 'cancel', operator: 'Henrique', expectedCaseVersion: c.caseVersion, reason: '' });
ok(r.status === 400, 'cancel without reason → 400');
r = E.api.resolve('case_0b6f19', { kind: 'cancel', operator: 'Henrique', expectedCaseVersion: c.caseVersion, reason: 'Origin will resend with the confirmed patient' });
ok(r.status === 201 && st('case_0b6f19') === 'Cancelled', 'cancel → Cancelled');

// P9
E.runScenario('p9');
ok(until('case_d91c07', c => c.state === 'ResolvedByPriorReceipt'), 'p9 → ResolvedByPriorReceipt');
c = E.S.cases.get('case_d91c07');
ok(c.executions.length === 0 && c.receipt.source === 'prior_receipt' && c.receipt.equivalenceConfirmed === true, 'p9: no execution, prior receipt confirmed');

// denial path (twice)
E.runScenario('p3-cancel');
until('case_c4e1a9', c => c.state === 'PendingApproval');
c = E.S.cases.get('case_c4e1a9');
r = E.api.decide('case_c4e1a9', c.currentProposalId, { decision: 'denied', operator: 'Henrique', expectedCaseVersion: c.caseVersion });
ok(r.status === 400, 'deny without reason → 400');
r = E.api.decide('case_c4e1a9', c.currentProposalId, { decision: 'denied', operator: 'Henrique', expectedCaseVersion: c.caseVersion, reason: 'Partner B is in a maintenance window per phone call' });
ok(r.status === 201 && st('case_c4e1a9') === 'Rejected', 'deny → Rejected');
ok(until('case_c4e1a9', c => c.state === 'ReviewRequired'), 'after denial → ReviewRequired with dossier');
ok(E.S.cases.get('case_c4e1a9').dossier.reason === 'review_requested', 'dossier review_requested');

// timeline integrity: seq strictly increasing and every StateChanged chain consistent
for (const [id, cc] of E.S.cases) {
  const seqs = cc._timeline.map(e => e.seq);
  ok(seqs.every((s, i) => s === i + 1), id + ': timeline seq 1..n');
  const sc = cc._timeline.filter(e => e.type === 'StateChanged');
  ok(sc.every((e, i) => i === 0 || e.payload.from === sc[i - 1].payload.to), id + ': state chain consistent');
  const v = E.api.getCase(id).body;
  ok(!JSON.stringify(v).includes('"_'), id + ': no internal fields leak');
}
console.log(fails ? fails + ' FAILED' : 'ALL PASSED');
process.exit(fails ? 1 : 0);
