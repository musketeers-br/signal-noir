'use strict';
/*
 * Signal Noir prototype: in-memory mock of /signalnoir/api/v1 plus a deterministic scenario engine.
 * No DOM, no network, no persistence. Responses follow contracts/openapi-signalnoir.yaml.
 * Time is virtual: it starts at 2026-10-29T13:00:00Z and moves 1 s per tick.
 */
window.SN_ENGINE = (function () {
  const FX = window.SN_FIXTURES;
  const T0 = Date.parse('2026-10-29T13:00:00Z');
  const TICK_MS = 1000;
  const APPROVAL_TTL_MS = 15 * 60 * 1000;
  const BASE = '/signalnoir/api/v1';
  const TERMINAL = ['Resolved', 'ResolvedByPriorReceipt', 'Cancelled', 'Failed'];
  const ACTIONS = FX.REF.actionCatalog.map(a => a.action);

  const iso = ms => new Date(ms).toISOString().replace(/\.\d{3}Z$/, 'Z');
  const view = o => JSON.parse(JSON.stringify(o, (key, v) => (key.charAt(0) === '_' ? undefined : v)));
  const pad = n => String(n).padStart(2, '0');

  const S = { now: T0, cases: new Map(), log: [], cmd: 0, lastDecision: {} };

  // ------------------------------------------------------------------ case primitives
  function nid(c, prefix) { c._n += 1; return prefix + c._short + '_' + pad(c._n); }

  function event(c, type, actor, refId, payload) {
    c._seq += 1;
    const ev = { seq: c._seq, at: iso(S.now), type, actor, refId: refId || null, payload: payload || {} };
    c._timeline.push(ev);
    c.lastEventSeq = c._seq;
    c.lastEventAt = ev.at;
    c.updatedAt = ev.at;
    return ev;
  }

  function transition(c, to, actor, reason) {
    const from = c.state;
    c.state = to;
    c.caseVersion += 1;
    event(c, 'StateChanged', actor, null, { from, to, reason: reason || null });
  }

  function newCase(o) {
    const short = o.caseId.slice(5);
    const c = {
      caseId: o.caseId, orderId: o.order.orderId, partnerId: o.partnerId, state: 'Open',
      labels: { synthetic: true, replay: false }, proposerMode: o.proposerMode || 'agent', benchmark: null,
      createdAt: iso(S.now), lastEventAt: iso(S.now), updatedAt: iso(S.now),
      caseVersion: 1, lastEventSeq: 0,
      order: {
        orderId: o.order.orderId, correlationId: 'corr_' + short, transactionIds: [o.order.transactionId],
        snapshot: o.order, equivalenceKey: o.equivalenceKey, transformed: null
      },
      visualTraceUrl: '/csp/signalnoir/EnsPortal.VisualTrace.zen?SESSIONID=' + (40000 + parseInt(short.slice(0, 4), 16) % 9000),
      exceptions: [], evidence: [], diagnosis: null, currentProposalId: null, proposals: [], approvals: [],
      denialCount: 0, executions: [], receipt: null, dossier: null,
      metrics: {
        provider: null, model: null, promptVersion: null, policyVersion: '2026.10.1', mappingVersion: '2026.10.1',
        investigationDurationMs: 0, toolCalls: 0, tokensIn: 0, tokensOut: 0, estCostUsd: 0, attempts: 0,
        exceptionToValidatedProposalMs: null, approvalToEffectMs: null
      },
      _short: short, _seq: 0, _n: 0, _attemptN: 0, _timeline: [], _script: [], _flags: {}, _lastExceptionSummary: ''
    };
    S.cases.set(c.caseId, c);
    event(c, 'CaseOpened', 'system', null, { orderId: c.orderId, partnerId: c.partnerId });
    return c;
  }

  function evidence(c, e) {
    const id = nid(c, 'evid_');
    c.evidence.push({
      evidenceId: id, source: e.source, calledBy: e.calledBy || 'agent', params: e.params || {}, result: e.result,
      observedAt: iso(S.now), durationMs: e.durationMs || 180 + (c._n * 37) % 400,
      suspicious: !!e.suspicious, suspiciousExcerpts: e.suspiciousExcerpts || [], obsoletedBy: null
    });
    if (e.source.indexOf('tool.') === 0) {
      c.metrics.toolCalls += 1;
      event(c, 'ToolCalled', e.calledBy || 'agent', id, { source: e.source, params: e.params || {} });
    }
    return id;
  }

  function exception(c, x) {
    let attemptId = null;
    if (x.attempt) { c._attemptN += 1; c.metrics.attempts += 1; attemptId = 'att_' + c._short + '_' + c._attemptN; }
    const ex = {
      exceptionId: nid(c, 'exc_'), kind: x.kind, httpStatus: x.httpStatus, body: x.body,
      responseClass: x.responseClass, observedAt: iso(S.now), attemptId, duringExecution: !!x.duringExecution
    };
    c.exceptions.push(ex);
    c._lastExceptionSummary = x.summary || x.kind;
    event(c, 'ExceptionRecorded', 'system', ex.exceptionId, { kind: x.kind, httpStatus: x.httpStatus, summary: x.summary || null });
    const evidenceId = evidence(c, { source: 'system.exception', calledBy: 'system', params: { exceptionId: ex.exceptionId }, result: { kind: x.kind, httpStatus: x.httpStatus, responseClass: x.responseClass, body: x.body } });
    return { exceptionId: ex.exceptionId, evidenceId };
  }

  function currentProposal(c) { return c.proposals.find(p => p.proposalId === c.currentProposalId) || null; }

  function propose(c, p) {
    const n = c.proposals.length + 1;
    const id = 'prop_' + c._short + '_v' + n;
    c.proposals.forEach(old => { if (old.current) { old.current = false; old.supersededBy = id; } });
    const author = p.author || 'agent';
    const prop = {
      proposalId: id, author, createdAt: iso(S.now), current: true, supersededBy: null,
      diagnosis: p.diagnosis, action: p.action, params: p.params || {}, scope: 'single_case', confidence: p.confidence,
      preconditions: p.preconditions || [], priorReceiptCandidate: p.priorReceiptCandidate || null,
      versions: author === 'agent' ? p.versions : { policy: '2026.10.1', mapping: '2026.10.1', prompt: null, model: null, provider: null },
      metrics: author === 'agent' ? p.metrics : { durationMs: 40, toolCalls: (p.metrics || {}).toolCalls || 0, tokensIn: 0, tokensOut: 0, estCostUsd: 0 },
      validatorVerdict: null
    };
    c.proposals.push(prop);
    c.currentProposalId = id;
    c.diagnosis = p.diagnosis;
    if (author === 'agent' && p.metrics) {
      const m = c.metrics;
      m.provider = p.versions.provider; m.model = p.versions.model; m.promptVersion = p.versions.prompt;
      m.investigationDurationMs += p.metrics.durationMs; m.tokensIn += p.metrics.tokensIn; m.tokensOut += p.metrics.tokensOut;
      m.estCostUsd = Math.round((m.estCostUsd + p.metrics.estCostUsd) * 1000) / 1000;
    }
    event(c, 'ProposalCreated', author, id, { action: p.action, confidence: p.confidence });
    return prop;
  }

  function verdict(c, prop, v) {
    prop.validatorVerdict = { verdict: v.verdict, reasons: v.reasons, requiresApproval: v.requiresApproval, at: iso(S.now) };
    if (v.verdict !== 'blocked' && c.metrics.exceptionToValidatedProposalMs === null && c.exceptions.length) {
      c.metrics.exceptionToValidatedProposalMs = S.now - Date.parse(c.exceptions[0].observedAt);
    }
    event(c, 'ValidatorVerdict', 'system', prop.proposalId, { verdict: v.verdict, reasons: v.reasons, requiresApproval: v.requiresApproval });
  }

  function approve(c, by, proposalId) {
    const appr = {
      approvalId: nid(c, 'appr_'), proposalId: proposalId || c.currentProposalId, decision: 'approved', by,
      at: iso(S.now), expiresAt: iso(S.now + APPROVAL_TTL_MS), status: 'valid', reason: null
    };
    c.approvals.push(appr);
    event(c, 'ApprovalRecorded', by, appr.approvalId, { decision: 'approved', proposalId: appr.proposalId });
    transition(c, 'Approved', by, 'approved by ' + by.replace('operator:', ''));
    return appr;
  }

  function authorize(c) {
    const prop = currentProposal(c);
    const appr = c.approvals.filter(a => a.proposalId === prop.proposalId && a.decision === 'approved' && a.status === 'valid').pop() || null;
    if (appr) appr.status = 'consumed';
    const ex = {
      executionId: nid(c, 'exec_'), approvalId: appr ? appr.approvalId : null, proposalId: prop.proposalId, action: prop.action,
      idempotencyKey: 'idem_' + c.orderId + '_' + prop.action.toLowerCase() + '_' + prop.proposalId.split('_').pop(),
      authorizedAt: iso(S.now), stepLeaseUntil: iso(S.now + 30000), leaseGeneration: 1, revalidation: null, reconciliations: [], attempts: [],
      outcome: 'in_progress', completedAt: null
    };
    c.executions.push(ex);
    event(c, 'ExecutionAuthorized', 'system', ex.executionId, { idempotencyKey: ex.idempotencyKey, approvalId: ex.approvalId });
    return ex;
  }

  function lastExec(c) { return c.executions[c.executions.length - 1]; }

  function checks(c, overrides) {
    const prop = currentProposal(c);
    const list = prop.preconditions.map(p => ({ check: p.check, expected: p.expected, observed: p.expected, passed: true }));
    list.push({ check: 'APPROVAL_VALID', expected: true, observed: true, passed: true });
    Object.keys(overrides || {}).forEach(k => {
      const item = list.find(x => x.check === k);
      if (item) Object.assign(item, overrides[k]);
    });
    return list;
  }

  function revalidate(c, ex, list, failState) {
    const passed = list.every(x => x.passed);
    const evidenceId = evidence(c, { source: 'system.revalidation', calledBy: 'system', params: { executionId: ex.executionId }, result: { passed, failed: list.filter(x => !x.passed).map(x => x.check) } });
    list.forEach(x => { if (!x.passed) x.evidenceId = evidenceId; });
    ex.revalidation = { passed, checks: list, at: iso(S.now), resultingState: passed ? 'Executing' : failState };
    event(c, 'RevalidationPerformed', 'system', ex.executionId, { passed, failed: list.filter(x => !x.passed).map(x => x.check) });
    return passed;
  }

  function applyTransform(c) {
    const prop = currentProposal(c);
    if (prop.action !== 'APPLY_APPROVED_MAPPING') return;
    const m = FX.REF.mappings.find(x => x.mappingId === prop.params.mappingId);
    const payload = JSON.parse(JSON.stringify(c.order.snapshot));
    payload.exams[0].code = m.targetCode;
    c.order.transformed = { payload, mappingId: m.mappingId, mappingVersion: prop.params.mappingVersion, proposalId: prop.proposalId };
  }

  function attempt(c, ex, a) {
    c._attemptN += 1;
    c.metrics.attempts += 1;
    const tx = 'TX-' + c.orderId.slice(4) + '-' + c._attemptN;
    c.order.transactionIds.push(tx);
    const at = {
      attemptId: 'att_' + c._short + '_' + c._attemptN, n: c._attemptN, transactionId: tx, sentAt: iso(S.now),
      completedAt: a.pending ? null : iso(S.now), httpStatus: a.pending ? null : a.httpStatus,
      bodyExcerpt: a.bodyExcerpt || '', receiptId: a.receiptId || null
    };
    if (!a.pending) at.responseClass = a.responseClass;
    ex.attempts.push(at);
    event(c, 'AttemptRecorded', 'system', at.attemptId, { n: at.n, httpStatus: at.httpStatus, responseClass: a.pending ? 'pending' : a.responseClass, idempotencyKey: ex.idempotencyKey });
    if (a.receiptId) {
      const appr = c.approvals.filter(x => x.decision === 'approved').pop();
      if (appr) c.metrics.approvalToEffectMs = S.now - Date.parse(appr.at);
    }
    return at;
  }

  function completeAttempt(c, ex, a) {
    const at = ex.attempts[ex.attempts.length - 1];
    Object.assign(at, { completedAt: iso(S.now), httpStatus: a.httpStatus, responseClass: a.responseClass, bodyExcerpt: a.bodyExcerpt || '', receiptId: a.receiptId || null });
    event(c, 'AttemptRecorded', 'system', at.attemptId, { n: at.n, httpStatus: a.httpStatus, responseClass: a.responseClass, completed: true });
  }

  function reconcile(c, ex, r) {
    const evidenceId = evidence(c, { source: 'system.reconciliation', calledBy: 'system', params: { queriedBy: r.queriedBy, key: ex.idempotencyKey }, result: { found: r.found, receiptId: r.receiptId || null } });
    ex.reconciliations.push({ at: iso(S.now), trigger: r.trigger, queriedBy: r.queriedBy, found: r.found, receiptId: r.receiptId || null, evidenceId });
    event(c, 'ReconciliationPerformed', 'system', ex.executionId, { found: r.found, receiptId: r.receiptId || null, trigger: r.trigger });
  }

  function receipt(c, r) {
    const ex = lastExec(c);
    c.receipt = {
      receiptId: r.receiptId, orderId: r.orderId || c.orderId, idempotencyKey: r.idempotencyKey || (ex ? ex.idempotencyKey : 'idem_prior_' + r.receiptId),
      receivedAt: r.receivedAt || iso(S.now), partnerId: c.partnerId, source: r.source,
      orderSnapshotMinimal: { orderId: r.orderId || c.orderId, examCodes: c.order.equivalenceKey.examCodes },
      equivalenceConfirmed: r.equivalenceConfirmed === undefined ? null : r.equivalenceConfirmed,
      externalRef: 'partner:' + r.receiptId, annotations: []
    };
    event(c, 'ReceiptRecorded', 'system', r.receiptId, { receiptId: r.receiptId, source: r.source, orderId: c.receipt.orderId });
  }

  function dossier(c, d) {
    c.dossier = Object.assign({ createdAt: iso(S.now), unknowns: [] }, d);
    event(c, 'DossierCreated', 'system', null, { reason: d.reason });
  }

  // ------------------------------------------------------------------ script helpers
  const step = (wait, run) => ({ wait, run });

  function schedule(c, steps) { c._script.push.apply(c._script, steps); }

  function instant(c, steps) {
    steps.forEach(s => { S.now += (s.wait || 0) * TICK_MS; s.run(c); });
  }

  function at(offsetSec, fn) {
    const saved = S.now;
    S.now = T0 - offsetSec * 1000;
    try { return fn(); } finally { S.now = saved; }
  }

  function investigation(c, ids, spec) {
    const steps = [step(1, cc => transition(cc, 'Investigating', 'system', spec.reason || 'exception recorded'))];
    (spec.tools || []).forEach(t => steps.push(step(2, cc => { ids[t.key] = evidence(cc, t); })));
    if (spec.proposal) {
      steps.push(step(2, cc => {
        const p = spec.proposal(ids, cc);
        if (spec.author) p.author = spec.author;
        const prop = propose(cc, p);
        transition(cc, 'DecisionProposed', prop.author, 'proposal ' + prop.proposalId);
      }));
      steps.push(step(1, cc => {
        verdict(cc, currentProposal(cc), spec.verdict);
        transition(cc, spec.next, 'system', 'validator: ' + spec.verdict.verdict);
        if (spec.then) spec.then(cc, ids);
      }));
    }
    return steps;
  }

  function executeSuccess(c, o) {
    return [
      step(1, cc => { authorize(cc); transition(cc, 'Executing', 'system', 'execution authorized'); }),
      step(2, cc => revalidate(cc, lastExec(cc), checks(cc))),
      step(1, cc => {
        applyTransform(cc);
        attempt(cc, lastExec(cc), { httpStatus: 200, responseClass: 'success', bodyExcerpt: '{"status":"ACCEPTED","receiptId":"' + o.receiptId + '"}', receiptId: o.receiptId });
      }),
      step(1, cc => {
        const ex = lastExec(cc);
        receipt(cc, { receiptId: o.receiptId, source: 'delivery' });
        ex.outcome = 'resolved';
        ex.completedAt = iso(S.now);
        transition(cc, 'Resolved', 'system', 'receipt ' + o.receiptId + ' recorded');
      })
    ];
  }

  const approvedCount = c => c.approvals.filter(a => a.decision === 'approved').length;

  const k = {
    T0, iso, now: () => S.now, step, schedule, instant, at, investigation, executeSuccess, approvedCount,
    newCase, event, transition, evidence, exception, propose, verdict, approve, authorize, lastExec, checks,
    revalidate, applyTransform, attempt, completeAttempt, reconcile, receipt, dossier, currentProposal
  };

  // ------------------------------------------------------------------ engine
  function scenarioOf(c) { return FX.SCENARIOS.find(s => s.id === c._scenario) || {}; }

  function runScript(c) {
    const q = c._script;
    while (q.length) {
      const s = q[0];
      if (s.wait > 0) { s.wait -= 1; return; }
      q.shift();
      s.run(c);
    }
  }

  function tick() {
    S.now += TICK_MS;
    S.cases.forEach(c => {
      c.approvals.forEach(a => {
        if (a.status === 'valid' && a.expiresAt && Date.parse(a.expiresAt) <= S.now) {
          a.status = 'expired';
          event(c, 'ApprovalExpired', 'sweeper', a.approvalId, { approvalId: a.approvalId });
        }
      });
      runScript(c);
    });
  }

  function runScenario(id) {
    const sc = FX.SCENARIOS.find(s => s.id === id);
    S.cases.forEach((c, key) => { if (c._scenario === id) S.cases.delete(key); });
    const c = sc.build(k);
    c._scenario = id;
    return c.caseId;
  }

  function reset() {
    S.now = T0;
    S.cases.clear();
    S.log.length = 0;
    S.lastDecision = {};
    FX.SCENARIOS.filter(s => s.seed).forEach(s => runScenario(s.id));
  }

  function hook(caseId, name) {
    const c = S.cases.get(caseId);
    const sc = c && scenarioOf(c);
    if (sc && sc[name]) schedule(c, sc[name](k, c));
  }

  function scenarioActions(caseId) {
    const c = S.cases.get(caseId);
    if (!c) return [];
    const sc = scenarioOf(c);
    return (sc.actions || []).map(a => ({ id: a.id, label: a.label, enabled: a.when(c) }));
  }

  function runAction(caseId, actionId) {
    const c = S.cases.get(caseId);
    const sc = scenarioOf(c);
    const a = (sc.actions || []).find(x => x.id === actionId);
    return a && a.when(c) ? a.run(k, c, sc) : 'Not available in the current state.';
  }

  // ------------------------------------------------------------------ mock HTTP API
  function err(code, message, details) { return { error: { code, message, details: details || {} } }; }
  function versioning(c) { return { caseVersion: c.caseVersion, lastEventSeq: c.lastEventSeq, serverTime: iso(S.now) }; }
  function caseRef(c) { return Object.assign({ caseId: c.caseId, state: c.state }, versioning(c)); }

  function respond(method, path, req, status, body, quiet) {
    S.log.push({ at: iso(S.now), method, path: BASE + path, req: req === undefined ? null : JSON.parse(JSON.stringify(req)), status, body, quiet: !!quiet });
    if (S.log.length > 300) S.log.shift();
    return { status, body: JSON.parse(JSON.stringify(body)) };
  }

  function summary(c) {
    const p = currentProposal(c);
    const appr = p && c.approvals.filter(a => a.proposalId === p.proposalId && a.status === 'valid').pop();
    return {
      caseId: c.caseId, orderId: c.orderId, partnerId: c.partnerId, state: c.state, labels: c.labels,
      proposerMode: c.proposerMode, benchmark: null, createdAt: c.createdAt, lastEventAt: c.lastEventAt,
      caseVersion: c.caseVersion, lastEventSeq: c.lastEventSeq, serverTime: iso(S.now),
      pendingApproval: c.state === 'PendingApproval',
      approvalDeadline: appr ? appr.expiresAt : null,
      currentProposal: p ? { proposalId: p.proposalId, action: p.action, confidence: p.confidence } : null,
      exceptionCount: c.exceptions.length,
      lastExceptionSummary: c._lastExceptionSummary,
      executionOutcome: c.executions.length ? c.executions[c.executions.length - 1].outcome : null
    };
  }

  function validName(name) { return typeof name === 'string' && name.trim().length > 0 && name.length <= 64 && name.indexOf(':') < 0; }

  function validateOperatorAction(c, action, params) {
    const reasons = [];
    const snap = c.order.snapshot;
    if (ACTIONS.indexOf(action) < 0) reasons.push('ACTION_NOT_IN_CATALOG');
    if (action === 'REQUEST_REVIEW') reasons.push('ALREADY_IN_REVIEW');
    if (action === 'APPLY_APPROVED_MAPPING') {
      const m = FX.REF.mappings.find(x => x.mappingId === (params || {}).mappingId);
      if (!m) reasons.push('MAPPING_UNKNOWN');
      else {
        if (m.mappingVersion !== params.mappingVersion) reasons.push('MAPPING_VERSION_MISMATCH');
        if (m.sourceCode !== snap.exams[0].code) reasons.push('MAPPING_SOURCE_CODE_MISMATCH');
        if (m.conditions.specimenType && m.conditions.specimenType !== snap.specimen.type) reasons.push('MAPPING_CONDITION_MISMATCH');
      }
    }
    if (action === 'RETRY' && c._flags.retryWouldFail) reasons.push('POLICY_CODE_DISCONTINUED');
    if (c._flags.identityAmbiguous && (action === 'RETRY' || action === 'APPLY_APPROVED_MAPPING')) reasons.push('IDENTITY_UNRESOLVED');
    return {
      verdict: reasons.length ? 'blocked' : 'accepted',
      reasons: reasons.length ? reasons : ['ACTION_IN_CATALOG', 'PARAMS_VALID'],
      requiresApproval: action === 'RETRY' || action === 'APPLY_APPROVED_MAPPING',
      at: iso(S.now)
    };
  }

  function scheduleAfterDenial(c, operator, reason) {
    const ids = {};
    schedule(c, [
      step(1, cc => {
        transition(cc, 'Investigating', 'system', 'new investigation with the denial reason as evidence');
        ids.denial = evidence(cc, { source: 'operator.denial_reason', calledBy: operator, params: {}, result: { reason } });
      }),
      step(2, cc => {
        const all = cc.evidence.filter(e => !e.obsoletedBy).map(e => e.evidenceId);
        if (cc.denialCount >= 2) {
          transition(cc, 'ReviewRequired', 'system', 'second denial');
          dossier(cc, { reason: 'second_denial', reasonText: 'The operator denied two proposals for this case.', partialDiagnosis: cc.diagnosis, hypotheses: (cc.diagnosis || {}).hypotheses || [], relevantEvidenceIds: all, conflicts: [], collidingRecords: [], unconfirmedCandidates: [], suggestedNextStep: 'Choose a catalog action below, or cancel the case.' });
          return;
        }
        const prop = propose(cc, {
          action: 'REQUEST_REVIEW', params: { reason: 'operator denied the previous proposal' }, confidence: 'MEDIA',
          diagnosis: { summary: 'After the denial, no other catalog action is supported by the evidence.', claims: [{ text: 'The operator denied the previous proposal: "' + reason + '".', evidenceIds: [ids.denial] }], hypotheses: [], conflicts: [] },
          preconditions: [], versions: (currentProposal(cc) || {}).versions, metrics: { durationMs: 3100, toolCalls: 0, tokensIn: 1900, tokensOut: 260, estCostUsd: 0.003 }
        });
        transition(cc, 'DecisionProposed', 'agent', 'proposal ' + prop.proposalId);
        verdict(cc, prop, { verdict: 'accepted', reasons: ['REVIEW_ALWAYS_ACCEPTED'], requiresApproval: false });
        transition(cc, 'ReviewRequired', 'system', 'agent requested review');
        dossier(cc, { reason: 'review_requested', reasonText: 'After your denial the agent found no other action the evidence supports.', partialDiagnosis: cc.diagnosis, hypotheses: [], relevantEvidenceIds: all, conflicts: [], collidingRecords: [], unconfirmedCandidates: [], suggestedNextStep: 'Choose a catalog action below, or cancel the case.' });
      })
    ]);
  }

  const api = {
    listCases(quiet) {
      const items = Array.from(S.cases.values())
        .sort((a, b) => (a.lastEventAt < b.lastEventAt ? 1 : a.lastEventAt > b.lastEventAt ? -1 : a.caseId < b.caseId ? 1 : -1))
        .map(summary);
      const head = items[0] ? items[0].lastEventAt + '|' + items[0].caseId : '';
      return respond('GET', '/cases', undefined, 200, { items, nextCursor: null, headCursor: head, serverTime: iso(S.now) }, quiet);
    },

    getCase(caseId, quiet) {
      const c = S.cases.get(caseId);
      if (!c) return respond('GET', '/cases/' + caseId, undefined, 404, err('NOT_FOUND', 'Case not found'), quiet);
      return respond('GET', '/cases/' + caseId, undefined, 200, Object.assign(view(c), { serverTime: iso(S.now) }), quiet);
    },

    getTimeline(caseId, sinceSeq, quiet) {
      const c = S.cases.get(caseId);
      const path = '/cases/' + caseId + '/timeline?sinceSeq=' + sinceSeq;
      if (!c) return respond('GET', path, undefined, 404, err('NOT_FOUND', 'Case not found'), quiet);
      const events = c._timeline.filter(e => e.seq > sinceSeq);
      return respond('GET', path, undefined, 200, Object.assign({ caseId: c.caseId, state: c.state, events, hasMore: false, nextSinceSeq: c.lastEventSeq }, versioning(c)), quiet);
    },

    decide(caseId, proposalId, body) {
      const path = '/cases/' + caseId + '/proposals/' + proposalId + '/decision';
      const c = S.cases.get(caseId);
      if (!c) return respond('POST', path, body, 404, err('NOT_FOUND', 'Case not found'));
      const b = body || {};
      if (['approved', 'denied'].indexOf(b.decision) < 0 || !validName(b.operator) || !Number.isInteger(b.expectedCaseVersion)) {
        return respond('POST', path, body, 400, err('VALIDATION_FAILED', 'decision, operator (no ":") and expectedCaseVersion are required'));
      }
      if (b.decision === 'denied' && !(b.reason && b.reason.trim())) {
        return respond('POST', path, body, 400, err('VALIDATION_FAILED', 'A denial requires a reason; it becomes evidence for the next investigation'));
      }
      const existing = c.approvals.find(a => a.proposalId === proposalId && a.decision === 'approved');
      if (existing && b.decision === 'approved') {
        return respond('POST', path, body, 200, { approval: existing, idempotentReplay: true, case: caseRef(c) });
      }
      if (c.state !== 'PendingApproval') {
        return respond('POST', path, body, 409, err('INVALID_TRANSITION', 'Case is ' + c.state + ', not PendingApproval', caseRef(c)));
      }
      if (proposalId !== c.currentProposalId || b.expectedCaseVersion !== c.caseVersion) {
        return respond('POST', path, body, 409, err('STALE_VERSION', 'The current proposal or case version changed since you loaded it', Object.assign({ currentProposalId: c.currentProposalId }, caseRef(c))));
      }
      const by = 'operator:' + b.operator.trim();
      S.lastDecision[caseId] = { proposalId, body: JSON.parse(JSON.stringify(b)) };
      S.cmd += 1;
      const commandId = 'cmd_' + c._short + '_' + pad(S.cmd);
      let appr;
      if (b.decision === 'approved') {
        appr = approve(c, by, proposalId);
        const sc = scenarioOf(c);
        if (sc.onApproved) schedule(c, sc.onApproved(k, c, appr));
      } else {
        appr = { approvalId: nid(c, 'appr_'), proposalId, decision: 'denied', by, at: iso(S.now), expiresAt: null, reason: b.reason.trim() };
        c.approvals.push(appr);
        c.denialCount += 1;
        event(c, 'ApprovalRecorded', by, appr.approvalId, { decision: 'denied', proposalId, reason: appr.reason });
        transition(c, 'Rejected', by, 'denied: ' + appr.reason);
        scheduleAfterDenial(c, by, appr.reason);
      }
      return respond('POST', path, body, 201, { approval: appr, idempotentReplay: false, case: Object.assign(caseRef(c), { commandId }) });
    },

    replayLastDecision(caseId) {
      const d = S.lastDecision[caseId];
      if (!d) return null;
      return api.decide(caseId, d.proposalId, d.body);
    },

    resolve(caseId, body) {
      const path = '/cases/' + caseId + '/resolution';
      const c = S.cases.get(caseId);
      if (!c) return respond('POST', path, body, 404, err('NOT_FOUND', 'Case not found'));
      const b = body || {};
      if (['action', 'cancel'].indexOf(b.kind) < 0 || !validName(b.operator) || !Number.isInteger(b.expectedCaseVersion)) {
        return respond('POST', path, body, 400, err('VALIDATION_FAILED', 'kind, operator (no ":") and expectedCaseVersion are required'));
      }
      if (b.kind === 'cancel' && !(b.reason && b.reason.trim())) {
        return respond('POST', path, body, 400, err('VALIDATION_FAILED', 'Cancelling requires a reason'));
      }
      if (c.state !== 'ReviewRequired') return respond('POST', path, body, 409, err('INVALID_TRANSITION', 'Case is ' + c.state + ', not ReviewRequired', caseRef(c)));
      if (b.expectedCaseVersion !== c.caseVersion) return respond('POST', path, body, 409, err('STALE_VERSION', 'The case changed since you loaded it', caseRef(c)));
      const by = 'operator:' + b.operator.trim();

      if (b.kind === 'cancel') {
        event(c, 'OperatorResolution', by, null, { kind: 'cancel', reason: b.reason.trim() });
        transition(c, 'Cancelled', by, 'cancelled: ' + b.reason.trim());
        return respond('POST', path, body, 201, { kind: 'cancel', proposal: null, approval: null, case: caseRef(c) });
      }

      const v = validateOperatorAction(c, b.action, b.params || {});
      const firstEvidence = (c.dossier && c.dossier.relevantEvidenceIds && c.dossier.relevantEvidenceIds[0]) || (c.evidence[0] || {}).evidenceId;
      if (v.verdict === 'blocked') {
        event(c, 'ValidatorVerdict', 'system', null, { verdict: 'blocked', reasons: v.reasons, requiresApproval: v.requiresApproval, author: by, action: b.action });
        return respond('POST', path, body, 422, err('VALIDATION_FAILED', 'The validator blocked the operator proposal', { verdict: v, caseVersion: c.caseVersion, lastEventSeq: c.lastEventSeq, serverTime: iso(S.now) }));
      }
      const prop = propose(c, {
        author: by, action: b.action, params: b.params || {}, confidence: 'ALTA',
        diagnosis: Object.assign({ summary: 'Operator decision from the review dossier.', claims: [{ text: b.note && b.note.trim() ? b.note.trim() : 'Chosen by the operator after reviewing the dossier.', evidenceIds: [firstEvidence] }], hypotheses: [], conflicts: [] }),
        preconditions: b.action === 'APPLY_APPROVED_MAPPING' ? [{ check: 'MAPPING_VERSION_UNCHANGED', expected: b.params.mappingVersion }, { check: 'ORDER_ACTIVE_AT_ORIGIN', expected: true }] : [{ check: 'ORDER_ACTIVE_AT_ORIGIN', expected: true }]
      });
      verdict(c, prop, v);
      event(c, 'OperatorResolution', by, prop.proposalId, { kind: 'action', action: b.action, params: b.params || {} });
      let approval = null;
      if (b.action === 'HOLD') {
        transition(c, 'Held', by, 'held by operator' + (b.params && b.params.reason ? ': ' + b.params.reason : ''));
      } else {
        approval = approve(c, by, prop.proposalId);
        const sc = scenarioOf(c);
        schedule(c, sc.onOperatorAction ? sc.onOperatorAction(k, c) : executeSuccess(c, { receiptId: 'RCP-' + (88300 + c._n) }));
      }
      return respond('POST', path, body, 201, { kind: 'action', proposal: view(prop), approval, case: caseRef(c) });
    }
  };

  return {
    T0, TICK_MS, APPROVAL_TTL_MS, BASE, TERMINAL, S, k, api, tick, reset, runScenario, hook,
    scenarioActions, runAction, scenarios: FX.SCENARIOS, now: () => S.now, iso
  };
})();
