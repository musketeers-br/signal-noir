'use strict';
/*
 * Signal Noir prototype: synthetic reference data and scenario scripts.
 * Field names, enums and ID prefixes follow contracts/openapi-signalnoir.yaml.
 * Every patient, order, receipt and number here is synthetic. Metrics are illustrative.
 * Throwaway preparation material (epic-prototipo-solucao): never copy into ui/.
 */
window.SN_FIXTURES = (function () {
  const REF = {
    partners: {
      'lab-partner-a': 'Partner A · reference lab',
      'lab-partner-b': 'Partner B · regional lab'
    },
    mappings: [
      { mappingId: 'map_glicj_plasma', mappingVersion: '2026.10.1', sourceCode: 'GLIC-J', targetCode: 'GLIC-P', conditions: { specimenType: 'PLASMA' } },
      { mappingId: 'map_glicj_soro', mappingVersion: '2026.10.1', sourceCode: 'GLIC-J', targetCode: 'GLIC-S', conditions: { specimenType: 'SERUM' } },
      { mappingId: 'map_hba1c_legacy', mappingVersion: '2026.10.1', sourceCode: 'HBA1C-L', targetCode: 'HBA1C', conditions: {} },
      { mappingId: 'map_tsh_legacy', mappingVersion: '2026.10.1', sourceCode: 'TSH-OLD', targetCode: 'TSH', conditions: {} }
    ],
    actionCatalog: [
      { action: 'RETRY', externalEffect: true, requiresApproval: true, params: [] },
      { action: 'APPLY_APPROVED_MAPPING', externalEffect: true, requiresApproval: true, params: ['mappingId', 'mappingVersion'] },
      { action: 'HOLD', externalEffect: false, requiresApproval: false, params: ['reason?'] },
      { action: 'REQUEST_REVIEW', externalEffect: false, requiresApproval: false, params: ['reason?'] }
    ]
  };

  const AGENT_VERSIONS = {
    policy: '2026.10.1', mapping: '2026.10.1', prompt: 'investigate-v0.3',
    model: 'reference-model (picked in B02)', provider: 'reference-provider (picked in B02)'
  };

  function order(o) {
    return {
      orderId: o.orderId,
      transactionId: o.tx,
      patient: { id: o.patientId, name: o.patientName || 'Synthetic Patient ' + o.patientId.slice(-3), birthDate: o.birthDate || '1980-01-01' },
      exams: [{ code: o.code, name: o.examName }],
      specimen: { id: o.specimenId, type: o.specimenType },
      collectedAt: o.collectedAt,
      orderingUnit: o.unit || 'UNIT-NORTH'
    };
  }
  function eqKey(o) {
    return { patientId: o.patientId, examCodes: [o.code], collectedAt: o.collectedAt, specimenId: o.specimenId };
  }
  function newOrderCase(k, caseId, partnerId, o, extra) {
    return k.newCase(Object.assign({ caseId, partnerId, order: order(o), equivalenceKey: eqKey(o) }, extra || {}));
  }

  const BODY_GLICJ = { error: 'VALIDATION_ERROR', message: 'Exam code GLIC-J is discontinued since 2026-10-01. Use the replacement code.' };

  // ---------------------------------------------------------------------------------------------
  const SCENARIOS = [
    {
      id: 'p5-p8b', tier: 'core', family: 'P5 + P8b',
      title: 'A lying 500 and two approved mappings',
      summary: 'HTTP 500 hides a business validation error. Two approved mappings exist, and only the specimen type tells them apart.',
      expect: 'The agent proposes map_glicj_soro. You approve, revalidation passes, the receipt arrives and the case ends Resolved.',
      seed: true,
      build(k) {
        const o = { orderId: 'ORD-24117', tx: 'TX-50117', patientId: 'SYN-PAT-0042', code: 'GLIC-J', examName: 'Fasting glucose', specimenId: 'SPC-7781', specimenType: 'SERUM', collectedAt: '2026-10-29T11:40:00Z' };
        const c = newOrderCase(k, 'case_9f3a1c', 'lab-partner-a', o);
        const ids = {};
        ids.timeout = k.exception(c, { kind: 'timeout', httpStatus: null, body: null, responseClass: 'transient', attempt: true, summary: 'Attempt 1 timed out' }).evidenceId;
        ids.e500 = k.exception(c, { kind: 'http_error', httpStatus: 500, body: BODY_GLICJ, responseClass: 'business_error', attempt: true, summary: 'Attempt 2 · HTTP 500 with a validation body' }).evidenceId;
        k.schedule(c, k.investigation(c, ids, {
          tools: [
            { key: 'history', source: 'tool.partner_failure_history', params: { orderId: o.orderId, partnerId: 'lab-partner-a', windowMin: 60 }, result: { orderFailures: [{ attempt: 1, kind: 'timeout' }, { attempt: 2, httpStatus: 500, bodyExcerpt: 'Exam code GLIC-J is discontinued…' }], partnerErrorRate1h: 0.012 } },
            { key: 'health', source: 'tool.partner_health', params: { partnerId: 'lab-partner-a' }, result: { status: 'UP', errorRate5m: 0.01, p95LatencyMs: 420, maintenanceWindow: null } },
            { key: 'policy', source: 'tool.policies', params: { topic: 'code_substitution', code: 'GLIC-J' }, result: { policyId: 'POL-CODE-SUBST', version: '2026.10.1', rule: 'GLIC-J discontinued on 2026-10-01. Replace it through an approved mapping chosen by specimen type.' } },
            { key: 'catalog', source: 'tool.mapping_catalog', params: { fromCode: 'GLIC-J' }, result: { catalogVersion: '2026.10.1', mappings: [REF.mappings[0], REF.mappings[1]] } }
          ],
          proposal: () => ({
            action: 'APPLY_APPROVED_MAPPING', params: { mappingId: 'map_glicj_soro', mappingVersion: '2026.10.1' }, confidence: 'ALTA',
            diagnosis: {
              summary: 'Discontinued exam code. The HTTP 500 is a business validation error, not an outage. The earlier timeout was transient.',
              claims: [
                { text: 'The 500 body reports a validation error for GLIC-J, not unavailability.', evidenceIds: [ids.e500] },
                { text: 'The partner is healthy: UP, with 1% errors in the last 5 minutes.', evidenceIds: [ids.health] },
                { text: 'Policy replaces GLIC-J through an approved mapping chosen by specimen type.', evidenceIds: [ids.policy] },
                { text: 'Two approved mappings exist. The order specimen is SERUM, which matches only map_glicj_soro.', evidenceIds: [ids.catalog] }
              ],
              hypotheses: [
                { text: 'Discontinued code: apply the mapping whose condition matches the order.', status: 'chosen', evidenceIds: [ids.e500, ids.policy, ids.catalog] },
                { text: 'Partner is unstable: RETRY.', status: 'discarded', reason: 'The partner is UP and the body states a validation error, so a retry would fail again.', evidenceIds: [ids.e500, ids.health] },
                { text: 'Apply the first catalog mapping (map_glicj_plasma).', status: 'discarded', reason: 'Its condition requires PLASMA, but this order is SERUM.', evidenceIds: [ids.catalog] }
              ],
              conflicts: [{ evidenceIds: [ids.e500, ids.health], description: 'The HTTP 500 suggests a server fault, but partner health is UP.' }]
            },
            preconditions: [
              { check: 'MAPPING_VERSION_UNCHANGED', expected: '2026.10.1' },
              { check: 'ORDER_ACTIVE_AT_ORIGIN', expected: true },
              { check: 'PARTNER_HEALTHY_WINDOW', expected: { maxErrorRate5m: 0.05 } },
              { check: 'POLICY_VERSION_UNCHANGED', expected: 'POL-CODE-SUBST@2026.10.1' }
            ],
            versions: AGENT_VERSIONS,
            metrics: { durationMs: 8400, toolCalls: 4, tokensIn: 5120, tokensOut: 610, estCostUsd: 0.011 }
          }),
          verdict: { verdict: 'accepted', reasons: ['ACTION_IN_CATALOG', 'PARAMS_VALID', 'MAPPING_CONDITION_MATCHES', 'REQUIRED_EVIDENCE_PRESENT'], requiresApproval: true },
          next: 'PendingApproval'
        }));
        return c;
      },
      onApproved: (k, c) => k.executeSuccess(c, { receiptId: 'RCP-88231' })
    },

    {
      id: 'stale', tier: 'ui', family: 'UI guarantee',
      title: 'The proposal changes while you review it',
      summary: 'Open "Review & approve". A few seconds later the mapping catalog moves to 2026.10.2 and the agent issues a new proposal version.',
      expect: 'Approving the old version returns 409 STALE_VERSION. Nothing is approved, and the UI asks you to review the new version.',
      build(k) {
        const o = { orderId: 'ORD-24130', tx: 'TX-50130', patientId: 'SYN-PAT-0051', code: 'HBA1C-L', examName: 'Glycated hemoglobin (legacy code)', specimenId: 'SPC-7790', specimenType: 'WHOLE_BLOOD', collectedAt: '2026-10-29T11:52:00Z' };
        const c = newOrderCase(k, 'case_51b0e2', 'lab-partner-a', o);
        const ids = {};
        ids.e422 = k.exception(c, { kind: 'business_rejection', httpStatus: 422, body: { error: 'UNKNOWN_CODE', message: 'HBA1C-L is not a valid exam code' }, responseClass: 'business_error', attempt: true, summary: 'Attempt 1 · HTTP 422 unknown code' }).evidenceId;
        k.schedule(c, k.investigation(c, ids, {
          tools: [
            { key: 'policy', source: 'tool.policies', params: { topic: 'code_substitution', code: 'HBA1C-L' }, result: { policyId: 'POL-CODE-SUBST', version: '2026.10.1', rule: 'Legacy codes are translated through the approved mapping catalog.' } },
            { key: 'catalog', source: 'tool.mapping_catalog', params: { fromCode: 'HBA1C-L' }, result: { catalogVersion: '2026.10.1', mappings: [REF.mappings[2]] } }
          ],
          proposal: () => mappingProposal(ids, 'map_hba1c_legacy', '2026.10.1', 'HBA1C-L'),
          verdict: { verdict: 'accepted', reasons: ['ACTION_IN_CATALOG', 'PARAMS_VALID', 'REQUIRED_EVIDENCE_PRESENT'], requiresApproval: true },
          next: 'PendingApproval'
        }));
        return c;
      },
      onDialogOpen(k, c) {
        if (c._flags.superseded) return [];
        c._flags.superseded = true;
        const ids = {};
        return [k.step(4, cc => {
          const old = cc.evidence.find(e => e.source === 'tool.mapping_catalog' && !e.obsoletedBy);
          ids.catalog2 = k.evidence(cc, { source: 'tool.mapping_catalog', calledBy: 'system', params: { fromCode: 'HBA1C-L' }, result: { catalogVersion: '2026.10.2', mappings: [Object.assign({}, REF.mappings[2], { mappingVersion: '2026.10.2' })], change: 'Condition text clarified; translation unchanged.' } });
          if (old) { old.obsoletedBy = ids.catalog2; k.event(cc, 'EvidenceObsoleted', 'system', old.evidenceId, { evidenceId: old.evidenceId, obsoletedBy: ids.catalog2 }); }
          ids.e422 = cc.evidence.find(e => e.source === 'system.exception').evidenceId;
          ids.policy = cc.evidence.find(e => e.source === 'tool.policies').evidenceId;
          ids.catalog = ids.catalog2;
        })].concat(k.investigation(c, ids, {
          reason: 'mapping catalog changed to 2026.10.2 while pending approval',
          tools: [],
          proposal: () => mappingProposal(ids, 'map_hba1c_legacy', '2026.10.2', 'HBA1C-L'),
          verdict: { verdict: 'accepted', reasons: ['ACTION_IN_CATALOG', 'PARAMS_VALID', 'REQUIRED_EVIDENCE_PRESENT'], requiresApproval: true },
          next: 'PendingApproval'
        }));
      },
      onApproved: (k, c) => k.executeSuccess(c, { receiptId: 'RCP-88236' }),
      actions: [{ id: 'supersede', label: 'Change the mapping catalog now', when: c => c.state === 'PendingApproval' && !c._flags.superseded, run: (k, c, scenario) => { k.schedule(c, scenario.onDialogOpen(k, c)); return 'The catalog will move to 2026.10.2 in a few seconds.'; } }]
    },

    {
      id: 'p3-held', tier: 'guarantee', family: 'P3',
      title: 'The partner degrades after approval',
      summary: 'A sincere 503. The agent proposes RETRY. Between your approval and the send, the partner error rate jumps to 38%.',
      expect: 'Revalidation blocks the send and the case goes to Held. When the partner recovers, a new investigation runs and a new approval is required.',
      build(k) {
        const o = { orderId: 'ORD-24151', tx: 'TX-50151', patientId: 'SYN-PAT-0063', code: 'CREA', examName: 'Creatinine', specimenId: 'SPC-7802', specimenType: 'SERUM', collectedAt: '2026-10-29T12:05:00Z' };
        const c = newOrderCase(k, 'case_7d22e0', 'lab-partner-b', o);
        const ids = {};
        ids.e503 = k.exception(c, { kind: 'http_error', httpStatus: 503, body: { status: 'SERVICE_UNAVAILABLE', retryAfterSec: 60 }, responseClass: 'transient', attempt: true, summary: 'Attempt 1 · HTTP 503' }).evidenceId;
        k.schedule(c, k.investigation(c, ids, retrySpec(ids, { errorRate5m: 0.02 })));
        return c;
      },
      onApproved(k, c) {
        if (k.approvedCount(c) > 1) return k.executeSuccess(c, { receiptId: 'RCP-88260' });
        const ids = {};
        return [
          k.step(1, cc => { k.authorize(cc); k.transition(cc, 'Executing', 'system', 'execution authorized'); }),
          k.step(2, cc => {
            const ex = k.lastExec(cc);
            k.revalidate(cc, ex, k.checks(cc, { PARTNER_HEALTHY_WINDOW: { observed: { errorRate5m: 0.38 }, passed: false } }), 'Held');
            ex.outcome = 'held'; ex.completedAt = k.iso(k.now());
            k.transition(cc, 'Held', 'system', 'revalidation failed: partner error rate 38% (limit 5%); nothing was sent');
          }),
          k.step(4, cc => k.event(cc, 'ReassessmentPerformed', 'sweeper', null, { condition: 'PARTNER_HEALTHY_WINDOW', observed: { errorRate5m: 0.31 }, cleared: false })),
          k.step(4, cc => k.event(cc, 'ReassessmentPerformed', 'sweeper', null, { condition: 'PARTNER_HEALTHY_WINDOW', observed: { errorRate5m: 0.12 }, cleared: false })),
          k.step(4, cc => {
            k.event(cc, 'ReassessmentPerformed', 'sweeper', null, { condition: 'PARTNER_HEALTHY_WINDOW', observed: { errorRate5m: 0.02 }, cleared: true });
            ['e503', 'policy'].forEach(key => { ids[key] = (cc.evidence.find(e => e.source === (key === 'e503' ? 'system.exception' : 'tool.policies')) || {}).evidenceId; });
            ids.history = (cc.evidence.find(e => e.source === 'tool.partner_failure_history') || {}).evidenceId;
          })
        ].concat(k.investigation(c, ids, Object.assign(retrySpec(ids, { errorRate5m: 0.02 }, true), { reason: 'hold condition cleared; new investigation' })));
      }
    },

    {
      id: 'p3-cancel', tier: 'guarantee', family: 'P3',
      title: 'The order is cancelled at the origin after approval',
      summary: 'Same RETRY path. Between your approval and the send, the origin cancels the order.',
      expect: 'Revalidation sees ORDER_ACTIVE_AT_ORIGIN = false. The case ends Cancelled and nothing is sent.',
      build(k) {
        const o = { orderId: 'ORD-24166', tx: 'TX-50166', patientId: 'SYN-PAT-0071', code: 'K', examName: 'Potassium', specimenId: 'SPC-7815', specimenType: 'SERUM', collectedAt: '2026-10-29T12:10:00Z' };
        const c = newOrderCase(k, 'case_c4e1a9', 'lab-partner-b', o);
        const ids = {};
        ids.e503 = k.exception(c, { kind: 'http_error', httpStatus: 503, body: { status: 'SERVICE_UNAVAILABLE', retryAfterSec: 30 }, responseClass: 'transient', attempt: true, summary: 'Attempt 1 · HTTP 503' }).evidenceId;
        k.schedule(c, k.investigation(c, ids, retrySpec(ids, { errorRate5m: 0.01 })));
        return c;
      },
      onApproved: (k, c) => [
        k.step(1, cc => { k.authorize(cc); k.transition(cc, 'Executing', 'system', 'execution authorized'); }),
        k.step(2, cc => {
          const ex = k.lastExec(cc);
          k.revalidate(cc, ex, k.checks(cc, { ORDER_ACTIVE_AT_ORIGIN: { observed: false, passed: false } }), 'Cancelled');
          ex.outcome = 'cancelled'; ex.completedAt = k.iso(k.now());
          k.transition(cc, 'Cancelled', 'system', 'revalidation: order cancelled at origin; nothing was sent');
        })
      ]
    },

    {
      id: 'lost-response', tier: 'guarantee', family: 'Recovery',
      title: 'The partner accepts but the response is lost',
      summary: 'After approval the send times out. The partner may or may not have the order.',
      expect: 'The case shows "outcome unknown" and blocks any new send, even from a new proposal. Reconciliation then finds the receipt and the case resolves without resending.',
      build(k) {
        const o = { orderId: 'ORD-24172', tx: 'TX-50172', patientId: 'SYN-PAT-0080', code: 'TSH-OLD', examName: 'Thyroid-stimulating hormone (legacy code)', specimenId: 'SPC-7821', specimenType: 'SERUM', collectedAt: '2026-10-29T12:14:00Z' };
        const c = newOrderCase(k, 'case_e8a0f4', 'lab-partner-a', o);
        const ids = {};
        ids.e422 = k.exception(c, { kind: 'business_rejection', httpStatus: 422, body: { error: 'UNKNOWN_CODE', message: 'TSH-OLD is not a valid exam code' }, responseClass: 'business_error', attempt: true, summary: 'Attempt 1 · HTTP 422 unknown code' }).evidenceId;
        k.schedule(c, k.investigation(c, ids, {
          tools: [
            { key: 'policy', source: 'tool.policies', params: { topic: 'code_substitution', code: 'TSH-OLD' }, result: { policyId: 'POL-CODE-SUBST', version: '2026.10.1', rule: 'Legacy codes are translated through the approved mapping catalog.' } },
            { key: 'catalog', source: 'tool.mapping_catalog', params: { fromCode: 'TSH-OLD' }, result: { catalogVersion: '2026.10.1', mappings: [REF.mappings[3]] } }
          ],
          proposal: () => mappingProposal(ids, 'map_tsh_legacy', '2026.10.1', 'TSH-OLD'),
          verdict: { verdict: 'accepted', reasons: ['ACTION_IN_CATALOG', 'PARAMS_VALID', 'REQUIRED_EVIDENCE_PRESENT'], requiresApproval: true },
          next: 'PendingApproval'
        }));
        return c;
      },
      onApproved: (k, c) => [
        k.step(1, cc => { k.authorize(cc); k.transition(cc, 'Executing', 'system', 'execution authorized'); }),
        k.step(2, cc => k.revalidate(cc, k.lastExec(cc), k.checks(cc))),
        k.step(1, cc => { k.applyTransform(cc); k.attempt(cc, k.lastExec(cc), { pending: true }); }),
        k.step(6, cc => {
          const ex = k.lastExec(cc);
          k.completeAttempt(cc, ex, { httpStatus: null, responseClass: 'uncertain', bodyExcerpt: 'No response within 10 s. The partner may have accepted the order.' });
          ex.outcome = 'reconciling';
          k.exception(cc, { kind: 'timeout', httpStatus: null, body: null, responseClass: 'uncertain', duringExecution: true, summary: 'Timeout after send: outcome unknown' });
        }),
        k.step(10, cc => k.reconcile(cc, k.lastExec(cc), { trigger: 'timeout', queriedBy: 'idempotencyKey', found: true, receiptId: 'RCP-88241' })),
        k.step(1, cc => {
          const ex = k.lastExec(cc);
          k.receipt(cc, { receiptId: 'RCP-88241', source: 'reconciliation' });
          ex.outcome = 'resolved'; ex.completedAt = k.iso(k.now());
          k.transition(cc, 'Resolved', 'system', 'receipt found by reconciliation; no resend');
        })
      ],
      actions: [
        { id: 'new-proposal', label: 'Try to send again with a new proposal', when: c => isUncertain(c),
          run: (k, c) => { k.event(c, 'CommandDiscarded', 'rules', null, { command: 'ProposeAction', action: 'RETRY', reason: 'EXECUTION_OUTCOME_UNKNOWN', executionId: k.lastExec(c).executionId }); return 'Blocked: the previous effect is still unknown. CommandDiscarded was recorded and nothing was sent.'; } },
        { id: 'restart', label: 'Restart the Production now', when: c => isUncertain(c),
          run: (k, c) => { const ex = k.lastExec(c); ex.leaseGeneration += 1; ex.stepLeaseUntil = k.iso(k.now() + 30000); k.event(c, 'Annotation', 'system', ex.executionId, { text: 'Production restarted. Reconciliation resumed from the outbox under lease generation ' + ex.leaseGeneration + '; a late worker from an earlier generation cannot overwrite it.' }); return 'Restart simulated. Lease generation is now ' + ex.leaseGeneration + '; reconciliation continues from durable state.'; } }
      ]
    },

    {
      id: 'provider-down', tier: 'core', family: 'P13',
      title: 'The LLM provider is unavailable',
      summary: 'The case needs a mapping, but the provider call fails with 401. Evidence was pre-collected deterministically, so it still exists.',
      expect: 'ReviewRequired with a dossier that states the reason and separates what was checked from what is unknown. Resolving with the wrong mapping is blocked by the validator.',
      seed: true,
      build(k) {
        const o = { orderId: 'ORD-24188', tx: 'TX-50188', patientId: 'SYN-PAT-0094', code: 'GLIC-J', examName: 'Fasting glucose', specimenId: 'SPC-7833', specimenType: 'PLASMA', collectedAt: '2026-10-29T12:20:00Z' };
        const c = newOrderCase(k, 'case_a37b5d', 'lab-partner-a', o);
        c._flags.retryWouldFail = true;
        const ids = {};
        ids.e500 = k.exception(c, { kind: 'http_error', httpStatus: 500, body: BODY_GLICJ, responseClass: 'business_error', attempt: true, summary: 'Attempt 1 · HTTP 500 with a validation body' }).evidenceId;
        const pre = [
          { key: 'policy', source: 'tool.policies', calledBy: 'system', params: { topic: 'code_substitution', code: 'GLIC-J' }, result: { policyId: 'POL-CODE-SUBST', version: '2026.10.1', rule: 'GLIC-J discontinued on 2026-10-01. Replace it through an approved mapping chosen by specimen type.' } },
          { key: 'catalog', source: 'tool.mapping_catalog', calledBy: 'system', params: { fromCode: 'GLIC-J' }, result: { catalogVersion: '2026.10.1', mappings: [REF.mappings[0], REF.mappings[1]] } },
          { key: 'health', source: 'tool.partner_health', calledBy: 'system', params: { partnerId: 'lab-partner-a' }, result: { status: 'UP', errorRate5m: 0.01, p95LatencyMs: 410, maintenanceWindow: null } }
        ];
        k.schedule(c, [k.step(1, cc => k.transition(cc, 'Investigating', 'system', 'exception recorded; pre-collecting evidence'))]
          .concat(pre.map(t => k.step(1, cc => { ids[t.key] = k.evidence(cc, t); })))
          .concat([
            k.step(3, cc => k.event(cc, 'Annotation', 'system', null, { text: 'Provider call failed: HTTP 401 invalid_api_key. No proposal was produced.' })),
            k.step(1, cc => {
              k.transition(cc, 'ReviewRequired', 'system', 'provider unavailable');
              k.dossier(cc, {
                reason: 'provider_unavailable',
                reasonText: 'The LLM provider rejected the call (HTTP 401, invalid key). Automation stopped before any proposal.',
                partialDiagnosis: null, hypotheses: [],
                relevantEvidenceIds: [ids.e500, ids.policy, ids.catalog, ids.health],
                conflicts: [], collidingRecords: [], unconfirmedCandidates: [],
                unknowns: [
                  { topic: 'diagnosis', text: 'No diagnosis: the agent never ran, so no interpretation of this evidence exists.' },
                  { topic: 'partner_acceptance', text: 'No mapped order has been sent to the partner yet, so its acceptance is untested.' }
                ],
                suggestedNextStep: 'Check the provider key in .env. To resolve now, compare the order specimen type with the conditions of the approved mappings in the catalog evidence.'
              });
            })
          ]));
        return c;
      },
      onOperatorAction: (k, c) => k.executeSuccess(c, { receiptId: 'RCP-88252' })
    },

    {
      id: 'ambiguous', tier: 'core', family: 'P13',
      title: 'Ambiguous patient identity',
      summary: 'The partner rejects the order because two synthetic patients match it. The agent cannot decide safely.',
      expect: 'ReviewRequired with the colliding records and their divergent fields. A resend is blocked by the validator until identity is confirmed; hold or cancel are allowed.',
      seed: true,
      build(k) {
        const o = { orderId: 'ORD-24195', tx: 'TX-50195', patientId: 'SYN-PAT-0107', patientName: 'Synthetic Patient 107', birthDate: '1979-03-14', code: 'CBC', examName: 'Complete blood count', specimenId: 'SPC-7840', specimenType: 'WHOLE_BLOOD', collectedAt: '2026-10-29T12:24:00Z' };
        const c = newOrderCase(k, 'case_0b6f19', 'lab-partner-a', o);
        c._flags.identityAmbiguous = true;
        const ids = {};
        ids.e422 = k.exception(c, { kind: 'business_rejection', httpStatus: 422, body: { error: 'PATIENT_IDENTITY', message: 'Two patients match the demographic key of this order' }, responseClass: 'business_error', attempt: true, summary: 'Attempt 1 · HTTP 422 identity' }).evidenceId;
        const records = [
          { recordRef: 'SYN-PAT-0107', source: 'origin MPI (synthetic)', fields: { name: 'Synthetic Patient 107', birthDate: '1979-03-14', sex: 'F', mrn: 'MRN-0107' }, divergentFields: ['birthDate', 'mrn'] },
          { recordRef: 'SYN-PAT-0170', source: 'origin MPI (synthetic)', fields: { name: 'Synthetic Patient 107', birthDate: '1979-04-13', sex: 'F', mrn: 'MRN-0170' }, divergentFields: ['birthDate', 'mrn'] }
        ];
        k.schedule(c, k.investigation(c, ids, {
          tools: [
            { key: 'search', source: 'tool.receipts_and_orders_by_patient', params: { name: 'Synthetic Patient 107', windowDays: 30 }, result: { matches: records.map(r => r.fields), receipts: [] } },
            { key: 'origin', source: 'tool.origin_order_status', params: { orderId: o.orderId }, result: { status: 'ACTIVE', patientRef: 'SYN-PAT-0107', note: 'Origin record was merged on 2026-10-20 (synthetic).' } }
          ],
          proposal: () => ({
            action: 'REQUEST_REVIEW', params: { reason: 'ambiguous identity' }, confidence: 'BAIXA',
            diagnosis: {
              summary: 'The partner sees two patients matching this order. The origin points to one record, but a recent merge makes that unreliable.',
              claims: [
                { text: 'The partner rejected the order for patient identity, not for the exam.', evidenceIds: [ids.e422] },
                { text: 'Two synthetic records share the name and differ in birth date and MRN.', evidenceIds: [ids.search] },
                { text: 'The origin record was merged recently, so its patient reference may be stale.', evidenceIds: [ids.origin] }
              ],
              hypotheses: [
                { text: 'Resend with the origin patient reference.', status: 'discarded', reason: 'The origin record was merged recently, and nothing confirms it.', evidenceIds: [ids.origin] },
                { text: 'Pick the most recent record.', status: 'discarded', reason: 'No evidence ties the order to either record.', evidenceIds: [ids.search] }
              ],
              conflicts: [{ evidenceIds: [ids.search, ids.origin], description: 'The origin names SYN-PAT-0107, while the partner finds two candidates.' }]
            },
            preconditions: [], versions: AGENT_VERSIONS,
            metrics: { durationMs: 6900, toolCalls: 2, tokensIn: 3880, tokensOut: 540, estCostUsd: 0.008 }
          }),
          verdict: { verdict: 'accepted', reasons: ['REVIEW_ALWAYS_ACCEPTED', 'IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION'], requiresApproval: false },
          next: 'ReviewRequired',
          then: cc => k.dossier(cc, {
            reason: 'ambiguous_identity',
            reasonText: 'Two patient records match this order. The system never acts automatically on ambiguous identity.',
            partialDiagnosis: cc.diagnosis,
            hypotheses: cc.diagnosis.hypotheses,
            relevantEvidenceIds: [ids.e422, ids.search, ids.origin],
            conflicts: cc.diagnosis.conflicts,
            collidingRecords: records,
            unconfirmedCandidates: [],
            unknowns: [{ topic: 'identity', text: 'No evidence says which of the two records is the right patient.', relatedEvidenceIds: [ids.search, ids.origin] }],
            suggestedNextStep: 'Confirm the patient with the ordering unit (UNIT-NORTH). Then cancel this case and let the origin resend with the confirmed patient, or hold it while you wait.'
          })
        }));
        return c;
      }
    },

    {
      id: 'p9', tier: 'conditional', family: 'P9 (conditional)',
      title: 'The "failed" order was already delivered',
      summary: 'A clean-looking timeout. The agent does not stop at "RETRY": it searches recent orders for the same synthetic patient and finds a receipt from 3 minutes earlier, sent under another transaction ID.',
      expect: 'The validator confirms the equivalence key and the case ends ResolvedByPriorReceipt with no execution. P9 is conditional in the plan.',
      build(k) {
        const o = { orderId: 'ORD-24203', tx: 'TX-50203', patientId: 'SYN-PAT-0118', code: 'LIPID', examName: 'Lipid panel', specimenId: 'SPC-7851', specimenType: 'SERUM', collectedAt: '2026-10-29T12:31:00Z' };
        const c = newOrderCase(k, 'case_d91c07', 'lab-partner-a', o);
        const ids = {};
        ids.timeout = k.exception(c, { kind: 'timeout', httpStatus: null, body: null, responseClass: 'transient', attempt: true, summary: 'Attempt 1 timed out' }).evidenceId;
        k.schedule(c, k.investigation(c, ids, {
          tools: [
            { key: 'health', source: 'tool.partner_health', params: { partnerId: 'lab-partner-a' }, result: { status: 'UP', errorRate5m: 0.0, p95LatencyMs: 380, maintenanceWindow: null } },
            { key: 'origin', source: 'tool.origin_order_status', params: { orderId: o.orderId }, result: { status: 'ACTIVE', resentFrom: null } },
            { key: 'search', source: 'tool.receipts_and_orders_by_patient', params: { patientId: o.patientId, windowMin: 30 }, result: { orders: [{ orderId: 'ORD-24199', transactionId: 'TX-50199', examCodes: ['LIPID'], specimenId: 'SPC-7851', collectedAt: '2026-10-29T12:31:00Z' }], receipts: [{ receiptId: 'RCP-88120', orderId: 'ORD-24199', receivedAt: '2026-10-29T12:57:00Z' }] } }
          ],
          proposal: () => ({
            action: 'REQUEST_REVIEW', params: { reason: 'prior receipt candidate; validator confirms equivalence' }, confidence: 'ALTA',
            priorReceiptCandidate: { receiptId: 'RCP-88120', orderId: 'ORD-24199' },
            diagnosis: {
              summary: 'The order was already delivered: the origin resent it as ORD-24199 under another transaction ID, and the partner issued receipt RCP-88120 3 minutes earlier.',
              claims: [
                { text: 'The partner is healthy, so the timeout alone does not justify a resend.', evidenceIds: [ids.health] },
                { text: 'ORD-24199 has the same patient, exam, specimen and collection time.', evidenceIds: [ids.search] },
                { text: 'ORD-24199 already has receipt RCP-88120.', evidenceIds: [ids.search] }
              ],
              hypotheses: [
                { text: 'Prior delivery under another identifier.', status: 'chosen', evidenceIds: [ids.search] },
                { text: 'Code valid and partner stable: RETRY.', status: 'discarded', reason: 'A retry would duplicate an order that was already delivered.', evidenceIds: [ids.search, ids.health] }
              ],
              conflicts: []
            },
            preconditions: [], versions: AGENT_VERSIONS,
            metrics: { durationMs: 9700, toolCalls: 3, tokensIn: 4410, tokensOut: 590, estCostUsd: 0.010 }
          }),
          verdict: { verdict: 'prior_receipt_confirmed', reasons: ['EQUIVALENCE_KEY_MATCH'], requiresApproval: false },
          next: 'ResolvedByPriorReceipt',
          then: cc => k.receipt(cc, { receiptId: 'RCP-88120', orderId: 'ORD-24199', source: 'prior_receipt', equivalenceConfirmed: true, receivedAt: '2026-10-29T12:57:00Z' })
        }));
        return c;
      }
    },

    {
      id: 'history', tier: 'static', family: 'clean',
      title: 'Resolved earlier today (clean, rules)',
      summary: 'Static history: a sincere 503 handled by the rules proposer and approved by Carla.',
      expect: 'Shows what a closed case looks like.',
      seed: true, hidden: true,
      build(k) {
        const o = { orderId: 'ORD-24098', tx: 'TX-50098', patientId: 'SYN-PAT-0031', code: 'NA', examName: 'Sodium', specimenId: 'SPC-7760', specimenType: 'SERUM', collectedAt: '2026-10-29T11:10:00Z' };
        return k.at(2400, () => {
          const c = newOrderCase(k, 'case_2a90b4', 'lab-partner-b', o, { proposerMode: 'rules' });
          const ids = {};
          ids.e503 = k.exception(c, { kind: 'http_error', httpStatus: 503, body: { status: 'SERVICE_UNAVAILABLE' }, responseClass: 'transient', attempt: true, summary: 'Attempt 1 · HTTP 503' }).evidenceId;
          k.instant(c, k.investigation(c, ids, Object.assign(retrySpec(ids, { errorRate5m: 0.0 }), { author: 'rules' })));
          k.approve(c, 'operator:Carla');
          k.instant(c, k.executeSuccess(c, { receiptId: 'RCP-88104' }));
          return c;
        });
      }
    }
  ];

  function isUncertain(c) {
    const ex = c.executions[c.executions.length - 1];
    return c.state === 'Executing' && !!ex && ex.outcome === 'reconciling';
  }

  function mappingProposal(ids, mappingId, version, code) {
    return {
      action: 'APPLY_APPROVED_MAPPING', params: { mappingId, mappingVersion: version }, confidence: 'ALTA',
      diagnosis: {
        summary: 'Legacy exam code ' + code + '. The catalog has a single unconditional approved mapping for it.',
        claims: [
          { text: 'The partner rejected ' + code + ' as an unknown code.', evidenceIds: [ids.e422] },
          { text: 'Policy routes legacy codes through the approved mapping catalog.', evidenceIds: [ids.policy] },
          { text: 'Catalog ' + version + ' has ' + mappingId + ' with no conditions.', evidenceIds: [ids.catalog] }
        ],
        hypotheses: [{ text: 'RETRY as is.', status: 'discarded', reason: 'An unknown code is rejected again on every retry.', evidenceIds: [ids.e422] }],
        conflicts: []
      },
      preconditions: [{ check: 'MAPPING_VERSION_UNCHANGED', expected: version }, { check: 'ORDER_ACTIVE_AT_ORIGIN', expected: true }],
      versions: Object.assign({}, AGENT_VERSIONS, { mapping: version }),
      metrics: { durationMs: 5200, toolCalls: 2, tokensIn: 3010, tokensOut: 470, estCostUsd: 0.006 }
    };
  }

  function retrySpec(ids, health, second) {
    return {
      tools: [
        { key: 'history', source: 'tool.partner_failure_history', params: { partnerId: 'lab-partner-b', windowMin: 60 }, result: { partnerErrorRate1h: 0.04, lastIncident: '2026-10-29T12:40:00Z' } },
        { key: 'health', source: 'tool.partner_health', params: { partnerId: 'lab-partner-b' }, result: Object.assign({ status: 'UP', p95LatencyMs: 610, maintenanceWindow: null }, health) },
        { key: 'policy', source: 'tool.policies', params: { topic: 'retry' }, result: { policyId: 'POL-RETRY', version: '2026.10.1', maxAttempts: 5, backoff: 'exponential' } }
      ],
      proposal: () => ({
        action: 'RETRY', params: {}, confidence: second ? 'ALTA' : 'MEDIA',
        diagnosis: {
          summary: second ? 'The partner recovered. The original 503 was a sincere outage, and the retry budget allows another attempt.' : 'A sincere outage. The 503 carries no business error, the partner is back UP, and the retry budget allows another attempt.',
          claims: [
            { text: 'HTTP 503 with no business error in the body.', evidenceIds: [ids.e503] },
            { text: 'Partner health is UP now.', evidenceIds: [ids.health] },
            { text: 'The retry policy allows up to 5 attempts.', evidenceIds: [ids.policy] }
          ],
          hypotheses: [{ text: 'Transient unavailability: RETRY.', status: 'chosen', evidenceIds: [ids.e503, ids.health] }],
          conflicts: []
        },
        preconditions: [
          { check: 'PARTNER_HEALTHY_WINDOW', expected: { maxErrorRate5m: 0.05 } },
          { check: 'ORDER_ACTIVE_AT_ORIGIN', expected: true },
          { check: 'POLICY_VERSION_UNCHANGED', expected: 'POL-RETRY@2026.10.1' }
        ],
        versions: AGENT_VERSIONS,
        metrics: { durationMs: 4600, toolCalls: 3, tokensIn: 2950, tokensOut: 420, estCostUsd: 0.005 }
      }),
      verdict: { verdict: 'accepted', reasons: ['ACTION_IN_CATALOG', 'RETRY_BUDGET_AVAILABLE', 'REQUIRED_EVIDENCE_PRESENT'], requiresApproval: true },
      next: 'PendingApproval'
    };
  }

  // Layout data for the benchmark page. NOT measured: every number here is made up.
  const BENCH = {
    runId: 'run_layout_only',
    note: 'Layout data, not measured. Real numbers come from the Reference Run (B12).',
    frozen: { prompt: 'investigate-v0.3', baseline: 'rules-0.2', policies: '2026.10.1', fixtures: 'fx-0.4', evaluator: 'eval-0.2', model: 'reference-model (B02)' },
    design: '2 families × 5 test variants × 3 repetitions = 30 agent investigations, plus tuning runs (not reported) and clean controls',
    decision: [
      { family: 'P5', mode: 'rules', runs: 15, correct: 6, safe_review: 6, unnecessary_review: 0, incorrect: 3, p50s: 0.2, p95s: 0.4, toolCalls: 3.0, costUsd: 0 },
      { family: 'P5', mode: 'agent', runs: 15, correct: 12, safe_review: 2, unnecessary_review: 1, incorrect: 0, p50s: 8.1, p95s: 13.9, toolCalls: 4.2, costUsd: 0.011 },
      { family: 'P8b', mode: 'rules', runs: 15, correct: 9, safe_review: 6, unnecessary_review: 0, incorrect: 0, p50s: 0.2, p95s: 0.3, toolCalls: 4.0, costUsd: 0 },
      { family: 'P8b', mode: 'agent', runs: 15, correct: 9, safe_review: 3, unnecessary_review: 2, incorrect: 1, p50s: 9.4, p95s: 16.2, toolCalls: 4.6, costUsd: 0.013 },
      { family: 'clean', mode: 'rules', runs: 9, correct: 9, safe_review: 0, unnecessary_review: 0, incorrect: 0, p50s: 0.1, p95s: 0.2, toolCalls: 2.0, costUsd: 0 },
      { family: 'clean', mode: 'agent', runs: 9, correct: 9, safe_review: 0, unnecessary_review: 0, incorrect: 0, p50s: 6.2, p95s: 9.0, toolCalls: 3.1, costUsd: 0.007 }
    ],
    guarantees: [
      { check: 'Two concurrent approvals → one effective authorization', result: 'pass' },
      { check: 'Response lost after acceptance → receipt recovered, no resend', result: 'pass' },
      { check: 'Restart during execution → reconciliation preserved', result: 'pass' },
      { check: 'Repeated command and late worker → no overwrite', result: 'pass' },
      { check: 'Blocking precondition before send (P3) → no effect', result: 'pass' },
      { check: 'Unknown outcome blocks any new send', result: 'pass' },
      { check: 'Wrong proposal blocked by the validator (proposer error, platform success)', result: 'pass' }
    ]
  };

  return { REF, SCENARIOS, BENCH };
})();
