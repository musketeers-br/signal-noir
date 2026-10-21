'use strict';
/*
 * Signal Noir prototype: operator UI. Talks only to the mock API in engine.js, the same way the
 * real SPA will talk to /signalnoir/api/v1 (hash routing, 1.5 s polling, AD-17).
 */
(function () {
  const E = window.SN_ENGINE;
  const FX = window.SN_FIXTURES;
  const POLL_MS = 1500;

  const $ = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));
  const esc = s => String(s === undefined || s === null ? '' : s).replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));

  const ui = { filter: 'needs', listSig: '', detailSig: '', panelSig: '', logSig: '', detail: null, timeline: [], sinceSeq: 0, timelineCase: null, logPolling: false, operator: '' };
  try { ui.operator = localStorage.getItem('sn-proto-operator') || ''; } catch (e) { /* storage unavailable */ }

  // ---------------------------------------------------------------- vocabulary
  const STATE = {
    Open: { tone: 'info', icon: '○', label: 'Open' },
    Investigating: { tone: 'info', icon: '◔', label: 'Investigating' },
    DecisionProposed: { tone: 'info', icon: '◑', label: 'Decision proposed' },
    PendingApproval: { tone: 'warn', icon: '!', label: 'Needs approval' },
    Approved: { tone: 'info', icon: '✓', label: 'Approved' },
    Rejected: { tone: 'warn', icon: '✕', label: 'Denied' },
    Executing: { tone: 'info', icon: '↗', label: 'Executing' },
    Held: { tone: 'hold', icon: '❙❙', label: 'On hold' },
    ReviewRequired: { tone: 'warn', icon: '?', label: 'Review required' },
    Resolved: { tone: 'ok', icon: '✓', label: 'Resolved' },
    ResolvedByPriorReceipt: { tone: 'ok', icon: '✓✓', label: 'Already delivered' },
    Cancelled: { tone: 'muted', icon: '∅', label: 'Cancelled' },
    Failed: { tone: 'danger', icon: '✕', label: 'Failed' }
  };
  const UNCERTAIN = { tone: 'violet', icon: '≈', label: 'Outcome unknown' };

  const SOURCE = {
    'tool.partner_failure_history': 'Partner failure history', 'tool.policies': 'Policies', 'tool.partner_health': 'Partner health',
    'tool.mapping_catalog': 'Mapping catalog', 'tool.receipts_and_orders_by_patient': 'Receipts & orders by patient',
    'tool.origin_order_status': 'Order status at origin', 'tool.order_timeline': 'Order timeline',
    'system.exception': 'Exception', 'system.revalidation': 'Revalidation', 'system.reconciliation': 'Reconciliation',
    'operator.denial_reason': 'Denial reason', 'operator.note': 'Operator note'
  };

  const ACTION_TEXT = {
    RETRY: 'Resend the order unchanged',
    APPLY_APPROVED_MAPPING: 'Apply an approved code mapping, then resend',
    HOLD: 'Hold the case; send nothing',
    REQUEST_REVIEW: 'Stop automation and ask a person'
  };

  const CONFIDENCE = { ALTA: 'High', MEDIA: 'Medium', BAIXA: 'Low' };

  const DOSSIER_REASON = {
    provider_unavailable: 'LLM provider unavailable', ambiguous_identity: 'Ambiguous patient identity', review_requested: 'Review requested',
    second_denial: 'Denied twice', budget_exceeded: 'Investigation budget exceeded', invalid_agent_response: 'Invalid agent response',
    agent_refusal: 'Agent refused', investigation_interrupted: 'Investigation interrupted', validator_blocked: 'Blocked by the validator',
    missing_evidence: 'Missing evidence', low_confidence: 'Low confidence', prior_receipt_unconfirmed: 'Prior receipt not confirmed'
  };

  function isUncertain(c) {
    const ex = c.executions && c.executions[c.executions.length - 1];
    return c.state === 'Executing' && ex && ex.outcome === 'reconciling';
  }
  function stateOf(c) { return isUncertain(c) ? UNCERTAIN : (STATE[c.state] || { tone: 'muted', icon: '·', label: c.state }); }
  function chip(c) {
    const s = stateOf(c);
    return '<span class="chip tone-' + s.tone + '" title="state: ' + esc(c.state) + '"><span aria-hidden="true">' + s.icon + '</span> ' + esc(s.label) + '</span>';
  }

  // ---------------------------------------------------------------- formatting
  const BRT = 3 * 3600 * 1000;
  function clock(isoStr) { return isoStr ? new Date(Date.parse(isoStr) - BRT).toISOString().slice(11, 19) : '—'; }
  function age(ms) {
    if (ms < 60000) return Math.max(0, Math.round(ms / 1000)) + ' s';
    if (ms < 3600000) return Math.floor(ms / 60000) + ' min';
    const h = Math.floor(ms / 3600000);
    return h + ' h ' + String(Math.floor((ms % 3600000) / 60000)).padStart(2, '0') + ' min';
  }
  function countdown(ms) {
    if (ms <= 0) return 'expired';
    const s = Math.floor(ms / 1000);
    return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
  }
  function actor(a) {
    if (!a) return '';
    if (a.indexOf('operator:') === 0) return esc(a.slice(9)) + ' <span class="muted">(operator, declared)</span>';
    return esc(a);
  }
  function partner(id) { return esc(FX.REF.partners[id] || id); }
  function scalar(v) {
    if (v === null || v === undefined) return '<span class="muted">null</span>';
    if (typeof v === 'object') return '<code>' + esc(JSON.stringify(v)) + '</code>';
    return esc(v);
  }
  function kv(obj) {
    if (obj === null || typeof obj !== 'object') return '<p>' + scalar(obj) + '</p>';
    return '<dl class="kv">' + Object.keys(obj).map(key => {
      const v = obj[key];
      let out;
      if (Array.isArray(v) && v.length && typeof v[0] === 'object') {
        out = '<ul class="plain">' + v.map(item => '<li>' + Object.keys(item).map(x => '<span class="kvk">' + esc(x) + '</span> ' + scalar(item[x])).join(' · ') + '</li>').join('') + '</ul>';
      } else if (Array.isArray(v)) {
        out = v.length ? v.map(scalar).join(', ') : '<span class="muted">none</span>';
      } else out = scalar(v);
      return '<dt>' + esc(key) + '</dt><dd>' + out + '</dd>';
    }).join('') + '</dl>';
  }
  function raw(key, label, obj) {
    return '<details class="raw" data-key="' + esc(key) + '"><summary>' + esc(label) + '</summary><pre>' + esc(JSON.stringify(obj, null, 2)) + '</pre></details>';
  }
  function evChip(c, id) {
    const e = c.evidence.find(x => x.evidenceId === id);
    const label = e ? (SOURCE[e.source] || e.source) : id;
    return '<button type="button" class="evchip" data-ev="' + esc(id) + '" title="' + esc(id) + '">' + esc(label) + '</button>';
  }

  // ---------------------------------------------------------------- toasts & log
  function toast(text, tone) {
    const t = document.createElement('div');
    t.className = 'toast tone-' + (tone || 'info');
    t.textContent = text;
    $('#toasts').appendChild(t);
    setTimeout(() => t.remove(), 6500);
  }

  function renderLog() {
    const entries = E.S.log.filter(x => ui.logPolling || !x.quiet);
    const sig = entries.length + ':' + (entries.length ? entries[entries.length - 1].at + entries[entries.length - 1].path : '') + ui.logPolling;
    if (sig === ui.logSig) return;
    ui.logSig = sig;
    $('#log-list').innerHTML = entries.slice(-60).reverse().map((x, i) =>
      '<details class="log-row"><summary><span class="mono">' + clock(x.at) + '</span> <b class="mono">' + x.method + '</b> <span class="mono path">' + esc(x.path) + '</span> <span class="status s' + String(x.status)[0] + '">' + x.status + '</span></summary>' +
      (x.req ? '<p class="small muted">Request</p><pre>' + esc(JSON.stringify(x.req, null, 2)) + '</pre>' : '') +
      '<p class="small muted">Response</p><pre>' + esc(JSON.stringify(x.body, null, 2).slice(0, 4000)) + '</pre></details>').join('') ||
      '<p class="muted small">No calls yet. Polling GETs are hidden unless you include them.</p>';
  }

  // ---------------------------------------------------------------- routing
  function route() {
    const h = location.hash || '#/cases';
    let m = h.match(/^#\/cases\/(case_[A-Za-z0-9_-]+)$/);
    if (m) return { name: 'case', id: m[1] };
    if (h === '#/benchmark') return { name: 'benchmark' };
    return { name: 'list' };
  }

  function onRoute() {
    ui.listSig = ''; ui.detailSig = ''; ui.panelSig = '';
    $$('.nav a').forEach(a => a.setAttribute('aria-current', String((a.getAttribute('href') === '#/benchmark') === (route().name === 'benchmark'))));
    render(true);
    $('#view').focus({ preventScroll: true });
    window.scrollTo(0, 0);
  }

  // ---------------------------------------------------------------- render loop
  function render(force) {
    const r = route();
    if (r.name === 'list') renderList(force);
    else if (r.name === 'case') renderCase(r.id, force);
    else if (r.name === 'benchmark') renderBenchmark(force);
    renderPanel();
    renderLog();
    $('#clock').textContent = clock(E.iso(E.now())) + ' BRT';
  }

  // ---------------------------------------------------------------- list
  const FILTERS = [
    ['needs', 'Needs you', c => c.state === 'PendingApproval' || c.state === 'ReviewRequired'],
    ['active', 'Active', c => E.TERMINAL.indexOf(c.state) < 0],
    ['closed', 'Closed', c => E.TERMINAL.indexOf(c.state) >= 0],
    ['all', 'All', () => true]
  ];

  function renderList(force) {
    const page = E.api.listCases(!ui.logPolling).body;
    const now = Date.parse(page.serverTime);
    const sig = ui.filter + '|' + page.items.map(i => i.caseId + i.state + i.lastEventSeq).join(',');
    if (!force && sig === ui.listSig) {
      $$('[data-age]').forEach(el => { el.textContent = age(now - Date.parse(el.getAttribute('data-age'))); });
      $$('[data-deadline]').forEach(el => { el.textContent = countdown(Date.parse(el.getAttribute('data-deadline')) - now); });
      return;
    }
    const flash = new Set();
    if (ui.listSig) {
      const before = ui.listSig.split('|')[1] || '';
      page.items.forEach(i => { if (before.indexOf(i.caseId + i.state + i.lastEventSeq) < 0) flash.add(i.caseId); });
    }
    ui.listSig = sig;
    const f = FILTERS.find(x => x[0] === ui.filter);
    const items = page.items.filter(f[2]);
    const counts = FILTERS.map(x => page.items.filter(x[2]).length);
    $('#view').innerHTML =
      '<div class="page-head"><div><h1>Cases</h1><p class="lead">Every interrupted order becomes a case. The agent investigates and proposes; you approve; the system re-checks and sends once.</p></div></div>' +
      '<div class="filters" role="group" aria-label="Filter cases">' + FILTERS.map((x, i) => '<button type="button" class="btn" data-filter="' + x[0] + '" aria-pressed="' + (x[0] === ui.filter) + '">' + x[1] + ' <span class="count">' + counts[i] + '</span></button>').join('') + '</div>' +
      (items.length ? '<ul class="case-list">' + items.map(i => {
        const s = { state: i.state, executions: [] };
        return '<li><a class="case-row' + (flash.has(i.caseId) ? ' flash' : '') + '" href="#/cases/' + esc(i.caseId) + '">' +
          '<span class="cr-state">' + chip(s) + '</span>' +
          '<span class="cr-main"><b>' + esc(i.orderId) + '</b> <span class="muted mono small">' + esc(i.caseId) + '</span><br><span class="small">' + esc(i.lastExceptionSummary) + '</span></span>' +
          '<span class="cr-partner small">' + partner(i.partnerId) + '</span>' +
          '<span class="cr-prop small">' + (i.currentProposal ? '<code>' + esc(i.currentProposal.action) + '</code><br><span class="muted">confidence ' + esc(CONFIDENCE[i.currentProposal.confidence]) + '</span>' : '<span class="muted">no proposal yet</span>') + '</span>' +
          '<span class="cr-age small"><span class="muted">age</span> <span data-age="' + esc(i.createdAt) + '">' + age(now - Date.parse(i.createdAt)) + '</span>' +
          (i.pendingApproval ? '<br><b class="warn-text">waiting for you</b>' : '') + '</span>' +
          '<span class="cr-tags"><span class="tag">SYNTHETIC</span></span></a></li>';
      }).join('') + '</ul>' : '<div class="empty"><p><b>Nothing here.</b> ' + (ui.filter === 'needs' ? 'No case needs a decision from you right now.' : 'No cases match this filter.') + '</p><p class="small muted">Use <b>Scenarios</b> to start one.</p></div>');
  }

  // ---------------------------------------------------------------- case detail
  function bannerFor(c) {
    const p = c.proposals.find(x => x.proposalId === c.currentProposalId);
    const ex = c.executions[c.executions.length - 1];
    switch (true) {
      case isUncertain(c): return ['violet', 'The outcome is unknown. The partner may already have this order. New sends are blocked, even from a new proposal, until reconciliation finds or rules out a receipt.', ''];
      case c.state === 'Open': return ['info', 'Exception recorded. The investigation starts shortly.', ''];
      case c.state === 'Investigating': return ['info', 'The agent is investigating with read-only tools. Nothing is sent while this runs.', ''];
      case c.state === 'DecisionProposed': return ['info', 'A proposal exists. The validator is checking it.', ''];
      case c.state === 'PendingApproval': return ['warn', 'Waiting for your approval. Nothing is sent until you approve this exact version.', p ? '<button type="button" class="btn primary" data-act="open-approve" data-fk="approve">Review &amp; approve…</button>' : ''];
      case c.state === 'Approved': return ['info', 'Approved. Preconditions are re-checked right before sending.', ''];
      case c.state === 'Executing': return ['info', 'Sending to the partner with idempotency key ' + (ex ? ex.idempotencyKey : '') + '.', ''];
      case c.state === 'Held': return ['hold', 'On hold. ' + (ex && ex.revalidation && !ex.revalidation.passed ? 'A precondition failed right before sending, so nothing was sent. ' : '') + 'The case is re-investigated when the condition clears, and any new action needs a new approval.', ''];
      case c.state === 'ReviewRequired': return ['warn', 'Automation stopped. The review dossier below explains why and what to check next.', '<button type="button" class="btn primary" data-act="goto-dossier" data-fk="goto-dossier">Go to dossier</button>'];
      case c.state === 'Rejected': return ['warn', 'You denied the proposal. One more investigation runs with your reason as evidence.', ''];
      case c.state === 'Resolved': return ['ok', 'Resolved. Partner receipt ' + (c.receipt ? c.receipt.receiptId : '') + ' confirms delivery' + (c.receipt && c.receipt.source === 'reconciliation' ? ', found by reconciliation without resending' : '') + '.', ''];
      case c.state === 'ResolvedByPriorReceipt': return ['ok', 'Already delivered. The validator confirmed an earlier receipt for the same real order. Nothing was resent.', ''];
      case c.state === 'Cancelled': return ['muted', 'Cancelled. No effect was sent to the partner.', ''];
      default: return ['danger', 'Failed.', ''];
    }
  }

  function section(n, id, title, sub, body) {
    return '<section class="layer" id="' + id + '" aria-labelledby="' + id + '-h"><h2 id="' + id + '-h"><span class="layer-n">' + n + '</span> ' + title + '</h2>' + (sub ? '<p class="layer-sub">' + sub + '</p>' : '') + body + '</section>';
  }
  const notYet = text => '<p class="empty-inline">' + esc(text || 'Not yet. The case has not reached this step.') + '</p>';

  function layerFailure(c) {
    const s = c.order.snapshot;
    return '<div class="grid2">' +
      '<div class="card"><h3>Order <span class="tag">SYNTHETIC</span></h3><dl class="kv">' +
      '<dt>Order</dt><dd><b>' + esc(s.orderId) + '</b></dd>' +
      '<dt>Patient</dt><dd>' + esc(s.patient.name) + ' <span class="muted mono small">' + esc(s.patient.id) + '</span></dd>' +
      '<dt>Exam</dt><dd><code>' + esc(s.exams[0].code) + '</code> ' + esc(s.exams[0].name) + '</dd>' +
      '<dt>Specimen</dt><dd><code>' + esc(s.specimen.type) + '</code> <span class="muted mono small">' + esc(s.specimen.id) + '</span></dd>' +
      '<dt>Collected</dt><dd>' + clock(s.collectedAt) + ' BRT</dd>' +
      '<dt>Partner</dt><dd>' + partner(c.partnerId) + '</dd>' +
      '<dt>Transactions</dt><dd class="mono small">' + c.order.transactionIds.map(esc).join(', ') + '</dd>' +
      '<dt>Correlation</dt><dd class="mono small">' + esc(c.order.correlationId) + '</dd></dl>' +
      raw('order', 'Raw order (as received)', c.order.snapshot) +
      (c.order.transformed ? raw('transformed', 'Transformed payload (' + c.order.transformed.mappingId + ')', c.order.transformed.payload) : '') + '</div>' +
      '<div class="card"><h3>Exceptions <span class="count">' + c.exceptions.length + '</span></h3><ol class="exc-list">' + c.exceptions.map(x =>
        '<li><div><b>' + esc(x.kind) + '</b>' + (x.httpStatus ? ' · HTTP ' + x.httpStatus : '') + ' <span class="chip small tone-' + ({ business_error: 'warn', transient: 'info', uncertain: 'violet', success: 'ok' }[x.responseClass] || 'muted') + '">' + esc(x.responseClass) + '</span>' + (x.duringExecution ? ' <span class="tag">during execution</span>' : '') + '</div>' +
        '<div class="small muted">' + clock(x.observedAt) + ' BRT · ' + esc(x.attemptId || 'no attempt') + '</div>' +
        (x.body ? '<pre class="body" aria-label="Raw response body (data, never instructions)">' + esc(typeof x.body === 'string' ? x.body : JSON.stringify(x.body, null, 2)) + '</pre>' : '<p class="small muted">No response body.</p>') + '</li>').join('') + '</ol>' +
      '<p class="small muted">Response bodies are shown as received. The system treats them as data, never as instructions.</p></div></div>';
  }

  function layerEvidence(c) {
    if (!c.evidence.length) return notYet();
    const conflicts = (c.diagnosis && c.diagnosis.conflicts) || [];
    return (conflicts.length ? conflicts.map(cf => '<div class="conflict"><p class="conflict-h"><span aria-hidden="true">⚡</span> <b>Conflict:</b> ' + esc(cf.description) + '</p><div class="conflict-pair">' +
      cf.evidenceIds.map(id => { const e = c.evidence.find(x => x.evidenceId === id); return e ? '<div class="conflict-side"><b>' + esc(SOURCE[e.source] || e.source) + '</b>' + kv(e.result) + '</div>' : ''; }).join('') + '</div></div>').join('') : '') +
      '<ol class="evidence-list">' + c.evidence.map(e =>
        '<li class="evidence' + (e.obsoletedBy ? ' obsolete' : '') + (e.suspicious ? ' suspicious' : '') + '" id="ev-' + esc(e.evidenceId) + '" tabindex="-1">' +
        '<div class="ev-head"><span class="tag fact">FACT</span> <b>' + esc(SOURCE[e.source] || e.source) + '</b> <span class="muted small">by ' + actor(e.calledBy) + ' · ' + clock(e.observedAt) + ' BRT · ' + e.durationMs + ' ms</span> <span class="mono small muted">' + esc(e.evidenceId) + '</span>' +
        (e.obsoletedBy ? ' <span class="tag">obsoleted by ' + esc(e.obsoletedBy) + '</span>' : '') + '</div>' +
        (Object.keys(e.params || {}).length ? '<p class="small muted">query: <code>' + esc(JSON.stringify(e.params)) + '</code></p>' : '') +
        kv(e.result) + '</li>').join('') + '</ol>';
  }

  function layerDiagnosis(c) {
    const d = c.diagnosis;
    if (!d) return notYet(c.state === 'ReviewRequired' || c.state === 'Investigating' ? 'No interpretation exists. The agent has not produced one.' : null);
    return '<div class="card interp"><p class="interp-tag"><span class="tag interp-t">INTERPRETATION</span> <span class="small muted">by ' + actor((c.proposals.find(p => p.proposalId === c.currentProposalId) || {}).author) + '. Each claim links to the evidence that supports it.</span></p>' +
      '<p class="diag-summary">' + esc(d.summary) + '</p>' +
      '<h3 class="h-small">Claims</h3><ul class="claims">' + d.claims.map(cl => '<li>' + esc(cl.text) + ' <span class="chips">' + cl.evidenceIds.map(id => evChip(c, id)).join('') + '</span></li>').join('') + '</ul>' +
      (d.hypotheses.length ? '<h3 class="h-small">Hypotheses</h3><ul class="hyps">' + d.hypotheses.map(h => '<li class="hyp ' + h.status + '"><span class="tag ' + (h.status === 'chosen' ? 'ok' : 'gray') + '">' + (h.status === 'chosen' ? 'chosen' : 'discarded') + '</span> ' + esc(h.text) + (h.reason ? '<br><span class="small muted">Why: ' + esc(h.reason) + '</span>' : '') + ' <span class="chips">' + (h.evidenceIds || []).map(id => evChip(c, id)).join('') + '</span></li>').join('') + '</ul>' : '') + '</div>';
  }

  function effectText(c, p) {
    if (p.action === 'APPLY_APPROVED_MAPPING') {
      const m = FX.REF.mappings.find(x => x.mappingId === p.params.mappingId) || {};
      return 'Change exam code <code>' + esc(m.sourceCode) + '</code> → <code>' + esc(m.targetCode) + '</code> using <code>' + esc(p.params.mappingId) + '</code> v' + esc(p.params.mappingVersion) + ', then resend ' + esc(c.orderId) + ' to ' + partner(c.partnerId) + '.';
    }
    if (p.action === 'RETRY') return 'Resend ' + esc(c.orderId) + ' unchanged to ' + partner(c.partnerId) + '.';
    if (p.action === 'HOLD') return 'Hold the case. Nothing is sent.';
    return p.priorReceiptCandidate ? 'No send. The validator checks prior receipt ' + esc(p.priorReceiptCandidate.receiptId) + ' (order ' + esc(p.priorReceiptCandidate.orderId) + ').' : 'Stop automation and prepare a review dossier. Nothing is sent.';
  }

  function proposalCard(c, p, isCurrent) {
    const v = p.validatorVerdict;
    const m = p.metrics || {};
    return '<div class="card proposal' + (isCurrent ? '' : ' old') + '">' +
      '<div class="prop-head"><div><span class="muted small">Action</span><div class="action-name"><code>' + esc(p.action) + '</code></div><div>' + esc(ACTION_TEXT[p.action]) + '</div></div>' +
      '<div class="prop-meta"><span class="conf conf-' + esc(p.confidence) + '">Confidence: <b>' + esc(CONFIDENCE[p.confidence]) + '</b></span><span class="small muted">scope ' + esc(p.scope) + '</span><span class="mono small">' + esc(p.proposalId) + '</span><span class="small muted">by ' + actor(p.author) + '</span></div></div>' +
      '<p class="effect"><b>Effect if executed:</b> ' + effectText(c, p) + '</p>' +
      (Object.keys(p.params).length ? '<p class="small">Parameters: <code>' + esc(JSON.stringify(p.params)) + '</code></p>' : '') +
      (p.preconditions.length ? '<h3 class="h-small">Re-checked right before sending</h3><ul class="plain small">' + p.preconditions.map(x => '<li><code>' + esc(x.check) + '</code> = ' + scalar(x.expected) + '</li>').join('') + '</ul>' : '') +
      (v ? '<p class="verdict v-' + esc(v.verdict) + '"><b>Validator:</b> ' + esc(v.verdict) + (v.requiresApproval ? ' · approval required' : ' · no approval needed') + ' <span class="small muted">' + v.reasons.map(esc).join(', ') + '</span></p>' : '<p class="verdict">Validator: pending</p>') +
      '<details class="raw" data-key="pm-' + esc(p.proposalId) + '"><summary>Versions &amp; metrics <span class="tag gray">illustrative</span></summary><dl class="kv small">' +
      '<dt>Provider / model</dt><dd>' + scalar(p.versions.provider) + ' / ' + scalar(p.versions.model) + '</dd><dt>Prompt</dt><dd>' + scalar(p.versions.prompt) + '</dd><dt>Policy / mapping</dt><dd>' + esc(p.versions.policy) + ' / ' + esc(p.versions.mapping) + '</dd>' +
      '<dt>Duration</dt><dd>' + (m.durationMs / 1000).toFixed(1) + ' s</dd><dt>Tool calls</dt><dd>' + m.toolCalls + '</dd><dt>Tokens in / out</dt><dd>' + m.tokensIn + ' / ' + m.tokensOut + '</dd><dt>Estimated cost</dt><dd>US$ ' + Number(m.estCostUsd).toFixed(3) + '</dd></dl></details>' +
      (!isCurrent && p.supersededBy ? '<p class="small muted">Superseded by ' + esc(p.supersededBy) + '.</p>' : '') + '</div>';
  }

  function layerProposal(c) {
    const cur = c.proposals.find(p => p.proposalId === c.currentProposalId);
    if (!cur) return notYet(c.state === 'ReviewRequired' ? 'No proposal. See the dossier.' : null);
    const old = c.proposals.filter(p => p.proposalId !== c.currentProposalId);
    return proposalCard(c, cur, true) +
      (c.state === 'PendingApproval' ? '<p class="cta-row"><button type="button" class="btn primary" data-act="open-approve" data-fk="approve2">Review &amp; approve…</button></p>' : '') +
      (old.length ? '<details class="raw" data-key="oldprops"><summary>Earlier versions (' + old.length + ')</summary>' + old.map(p => proposalCard(c, p, false)).join('') + '</details>' : '');
  }

  function layerApproval(c, now) {
    if (!c.approvals.length) return notYet(c.state === 'PendingApproval' ? 'No decision yet. Waiting for you.' : null);
    return '<ul class="plain">' + c.approvals.map(a => '<li class="card approval"><b>' + (a.decision === 'approved' ? 'Approved' : 'Denied') + '</b> by ' + actor(a.by) + ' at ' + clock(a.at) + ' BRT · <span class="mono small">' + esc(a.proposalId) + '</span>' +
      (a.status ? ' <span class="tag ' + (a.status === 'valid' ? 'ok' : 'gray') + '">' + esc(a.status) + '</span>' : '') +
      (a.status === 'valid' && a.expiresAt ? ' <span class="small">expires in <b data-deadline="' + esc(a.expiresAt) + '">' + countdown(Date.parse(a.expiresAt) - now) + '</b></span>' : '') +
      (a.reason ? '<br><span class="small">Reason: ' + esc(a.reason) + '</span>' : '') + '</li>').join('') + '</ul>';
  }

  function layerExecution(c) {
    if (!c.executions.length && !c.receipt) return notYet(c.state === 'Held' || c.state === 'Cancelled' ? 'No execution.' : null);
    return c.executions.map(ex => '<div class="card exec"><div class="exec-head"><b>Execution</b> <span class="mono small">' + esc(ex.executionId) + '</span> <span class="chip small tone-' + ({ resolved: 'ok', reconciling: 'violet', held: 'hold', cancelled: 'muted', failed: 'danger', in_progress: 'info' }[ex.outcome]) + '">' + esc(ex.outcome) + '</span></div>' +
      '<p class="small">Idempotency key <code>' + esc(ex.idempotencyKey) + '</code>: the partner applies at most one effect per key. Authorized ' + clock(ex.authorizedAt) + ' BRT.</p>' +
      (ex.revalidation ? '<h3 class="h-small">Revalidation ' + (ex.revalidation.passed ? '<span class="tag ok">passed</span>' : '<span class="tag danger">blocked the send</span>') + '</h3><table class="checks"><thead><tr><th>Check</th><th>Expected</th><th>Observed</th><th>Result</th></tr></thead><tbody>' +
        ex.revalidation.checks.map(x => '<tr class="' + (x.passed ? '' : 'bad') + '"><td><code>' + esc(x.check) + '</code></td><td>' + scalar(x.expected) + '</td><td>' + scalar(x.observed) + '</td><td>' + (x.passed ? '✓ holds' : '✕ fails') + '</td></tr>').join('') + '</tbody></table>' : '') +
      (ex.attempts.length ? '<h3 class="h-small">Attempts</h3><ul class="plain small">' + ex.attempts.map(a => '<li>#' + a.n + ' <span class="mono">' + esc(a.transactionId) + '</span> sent ' + clock(a.sentAt) + ' · ' + (a.completedAt ? (a.httpStatus ? 'HTTP ' + a.httpStatus + ' ' : '') + '<b>' + esc(a.responseClass) + '</b>' : '<b>waiting for response…</b>') + (a.bodyExcerpt ? '<br><span class="muted">' + esc(a.bodyExcerpt) + '</span>' : '') + '</li>').join('') + '</ul>' : '') +
      (ex.reconciliations.length ? '<h3 class="h-small">Reconciliation</h3><ul class="plain small">' + ex.reconciliations.map(r => '<li>' + clock(r.at) + ' · by ' + esc(r.queriedBy) + ' · ' + (r.found ? 'receipt <b>' + esc(r.receiptId) + '</b> found' : 'no receipt') + ' ' + evChip(c, r.evidenceId) + '</li>').join('') + '</ul>' : '') + '</div>').join('') +
      (c.receipt ? '<div class="card receipt"><h3>Receipt <span class="mono">' + esc(c.receipt.receiptId) + '</span></h3><dl class="kv small"><dt>Source</dt><dd>' + esc(c.receipt.source) + '</dd><dt>Order</dt><dd>' + esc(c.receipt.orderId) + '</dd><dt>Key</dt><dd class="mono">' + esc(c.receipt.idempotencyKey) + '</dd><dt>Received</dt><dd>' + clock(c.receipt.receivedAt) + ' BRT</dd>' +
        (c.receipt.equivalenceConfirmed !== null ? '<dt>Equivalence key</dt><dd>' + (c.receipt.equivalenceConfirmed ? 'confirmed by the validator' : 'not confirmed') + '</dd>' : '') + '</dl></div>' : '');
  }

  function dossierBlock(c) {
    const d = c.dossier;
    if (!d) return '';
    const live = c.state === 'ReviewRequired';
    const unknowns = (E.S.cases.get(c.caseId) || {})._unknowns || [];
    return '<section class="dossier" id="dossier" aria-labelledby="dossier-h" tabindex="-1"><h2 id="dossier-h">Review dossier' + (live ? '' : ' <span class="tag gray">closed</span>') + '</h2>' +
      '<p class="dossier-reason"><b>Why automation stopped:</b> ' + esc(d.reasonText) + ' <span class="tag">' + esc(DOSSIER_REASON[d.reason] || d.reason) + '</span></p>' +
      '<div class="grid2">' +
      '<div><h3 class="h-small">What was checked</h3><p class="chips">' + (d.relevantEvidenceIds || []).map(id => evChip(c, id)).join('') + '</p>' +
      '<h3 class="h-small">Hypotheses</h3>' + ((d.hypotheses || []).length ? '<ul class="hyps">' + d.hypotheses.map(h => '<li><span class="tag ' + (h.status === 'chosen' ? 'ok' : 'gray') + '">' + esc(h.status) + '</span> ' + esc(h.text) + (h.reason ? '<br><span class="small muted">Why: ' + esc(h.reason) + '</span>' : '') + '</li>').join('') + '</ul>' : '<p class="small muted">None. No interpretation was produced.</p>') + '</div>' +
      '<div><h3 class="h-small">What we don\'t know</h3>' + (unknowns.length ? '<ul class="unknowns">' + unknowns.map(u => '<li>' + esc(u) + '</li>').join('') + '</ul>' : '<p class="small muted">Nothing flagged.</p>') +
      '<p class="small muted">Missing information is listed here. It is not a negative conclusion.</p></div></div>' +
      ((d.collidingRecords || []).length ? '<h3 class="h-small">Colliding records</h3><div class="table-wrap"><table class="checks"><thead><tr><th>Record</th>' + Object.keys(d.collidingRecords[0].fields).map(f => '<th>' + esc(f) + '</th>').join('') + '</tr></thead><tbody>' +
        d.collidingRecords.map(r => '<tr><td class="mono">' + esc(r.recordRef) + '</td>' + Object.keys(r.fields).map(f => '<td class="' + (r.divergentFields.indexOf(f) >= 0 ? 'diverge' : '') + '">' + esc(r.fields[f]) + (r.divergentFields.indexOf(f) >= 0 ? ' <span class="sr">differs</span><span aria-hidden="true"> ≠</span>' : '') + '</td>').join('') + '</tr>').join('') + '</tbody></table></div>' : '') +
      ((d.unconfirmedCandidates || []).length ? '<h3 class="h-small">Unconfirmed prior receipts</h3><ul class="plain">' + d.unconfirmedCandidates.map(u => '<li>' + esc(u.receiptId) + ' / ' + esc(u.orderId) + ': mismatched ' + u.mismatchedFields.map(esc).join(', ') + '</li>').join('') + '</ul>' : '') +
      '<div class="next-step"><b>Suggested next step</b><p>' + esc(d.suggestedNextStep) + '</p></div>' +
      (live ? resolveForm(c) : '') + '</section>';
  }

  function resolveForm(c) {
    const code = c.order.snapshot.exams[0].code;
    const maps = FX.REF.mappings.filter(m => m.sourceCode === code);
    return '<form class="resolve" id="resolve-form" novalidate><fieldset><legend>Resolve this case</legend>' +
      '<p class="small muted">Your choice goes through the same validator as the agent\'s proposals. Free editing of the payload is not available.</p>' +
      '<div class="radios">' +
      (maps.length ? '<label><input type="radio" name="kind" value="APPLY_APPROVED_MAPPING" id="rk-map"> Apply approved mapping</label> <select id="rk-mapping" aria-label="Mapping">' + maps.map(m => '<option value="' + esc(m.mappingId) + '|' + esc(m.mappingVersion) + '">' + esc(m.mappingId) + ' v' + esc(m.mappingVersion) + ': ' + esc(m.sourceCode) + ' → ' + esc(m.targetCode) + (m.conditions.specimenType ? ' (only if specimen = ' + esc(m.conditions.specimenType) + ')' : '') + '</option>').join('') + '</select>' : '') +
      '<label><input type="radio" name="kind" value="RETRY" id="rk-retry"> Retry unchanged</label>' +
      '<label><input type="radio" name="kind" value="HOLD" id="rk-hold"> Hold</label>' +
      '<label><input type="radio" name="kind" value="cancel" id="rk-cancel"> Cancel the case</label></div>' +
      '<label class="field">Reason or note <span class="muted small">(required to cancel)</span><textarea id="rk-note" rows="2"></textarea></label>' +
      '<label class="field">Your name <span class="muted small">(declared, not authenticated)</span><input id="rk-operator" autocomplete="name" value="' + esc(ui.operator) + '"></label>' +
      '<button type="submit" class="btn primary" data-fk="resolve-submit">Submit to validator</button>' +
      '<div id="resolve-result" role="alert"></div></fieldset></form>';
  }

  function timelineBlock() {
    const evs = ui.timeline.slice().reverse();
    return '<aside class="timeline" aria-labelledby="tl-h"><h2 id="tl-h">Timeline <span class="count">' + ui.timeline.length + '</span></h2><p class="small muted">Append-only. Newest first.</p><ol class="tl">' + evs.map(e =>
      '<li class="tl-' + esc(e.type) + '"><span class="tl-seq mono">#' + e.seq + '</span><span class="tl-time mono">' + clock(e.at) + '</span><span class="tl-type">' + esc(e.type) + '</span><span class="tl-actor small">' + actor(e.actor) + '</span><span class="tl-text small">' + esc(evSummary(e)) + '</span></li>').join('') + '</ol></aside>';
  }

  function evSummary(e) {
    const p = e.payload || {};
    switch (e.type) {
      case 'CaseOpened': return 'order ' + p.orderId;
      case 'ExceptionRecorded': return p.summary || p.kind;
      case 'StateChanged': return p.from + ' → ' + p.to + (p.reason ? ' · ' + p.reason : '');
      case 'ToolCalled': return SOURCE[p.source] || p.source;
      case 'ProposalCreated': return p.action + ' · confidence ' + (CONFIDENCE[p.confidence] || p.confidence);
      case 'ValidatorVerdict': return p.verdict + (p.reasons ? ' · ' + p.reasons.join(', ') : '');
      case 'ApprovalRecorded': return p.decision + (p.reason ? ' · ' + p.reason : '');
      case 'ApprovalExpired': return 'approval expired';
      case 'ExecutionAuthorized': return 'key ' + p.idempotencyKey;
      case 'RevalidationPerformed': return p.passed ? 'all preconditions hold' : 'failed: ' + (p.failed || []).join(', ');
      case 'AttemptRecorded': return '#' + p.n + ' ' + (p.httpStatus ? 'HTTP ' + p.httpStatus + ' ' : '') + p.responseClass;
      case 'ReconciliationPerformed': return p.found ? 'receipt ' + p.receiptId + ' found' : 'no receipt found';
      case 'ReceiptRecorded': return p.receiptId + ' (' + p.source + ')';
      case 'ReassessmentPerformed': return (p.cleared ? 'cleared' : 'still blocked') + ' · ' + JSON.stringify(p.observed);
      case 'DossierCreated': return DOSSIER_REASON[p.reason] || p.reason;
      case 'OperatorResolution': return p.kind + (p.action ? ' · ' + p.action : '') + (p.reason ? ' · ' + p.reason : '');
      case 'CommandDiscarded': return p.command + ' discarded · ' + p.reason;
      case 'EvidenceObsoleted': return p.evidenceId + ' → ' + p.obsoletedBy;
      case 'Annotation': return p.text;
      default: return '';
    }
  }

  function captureForm() {
    const vals = {};
    $$('#view input, #view select, #view textarea').forEach(el => { if (el.id) vals[el.id] = el.type === 'radio' || el.type === 'checkbox' ? el.checked : el.value; });
    const focus = document.activeElement && (document.activeElement.id || document.activeElement.getAttribute('data-fk'));
    const open = $$('#view details[data-key]').filter(d => d.open).map(d => d.getAttribute('data-key'));
    return { vals, focus, open, result: ($('#resolve-result') || {}).innerHTML };
  }
  function restoreForm(st) {
    Object.keys(st.vals).forEach(id => { const el = document.getElementById(id); if (el) { if (el.type === 'radio' || el.type === 'checkbox') el.checked = st.vals[id]; else el.value = st.vals[id]; } });
    st.open.forEach(key => { const d = $('#view details[data-key="' + key + '"]'); if (d) d.open = true; });
    if (st.result && $('#resolve-result')) $('#resolve-result').innerHTML = st.result;
    if (st.focus) { const el = document.getElementById(st.focus) || $('[data-fk="' + st.focus + '"]'); if (el) el.focus({ preventScroll: true }); }
  }

  function renderCase(id, force) {
    const res = E.api.getCase(id, !ui.logPolling);
    if (res.status !== 200) { $('#view').innerHTML = '<p class="empty"><b>Case not found.</b> <a href="#/cases">Back to cases</a></p>'; ui.detail = null; return; }
    const c = res.body;
    if (ui.timelineCase !== id || c.lastEventSeq < ui.sinceSeq) { ui.timeline = []; ui.sinceSeq = 0; ui.timelineCase = id; force = true; }
    const tl = E.api.getTimeline(id, ui.sinceSeq, !ui.logPolling).body;
    ui.timeline = ui.timeline.concat(tl.events);
    ui.sinceSeq = tl.nextSinceSeq;
    ui.detail = c;
    const now = Date.parse(c.serverTime);
    const sig = c.caseVersion + ':' + c.lastEventSeq;
    if (!force && sig === ui.detailSig) {
      $$('[data-deadline]').forEach(el => { el.textContent = countdown(Date.parse(el.getAttribute('data-deadline')) - now); });
      $$('[data-age]').forEach(el => { el.textContent = age(now - Date.parse(el.getAttribute('data-age'))); });
      return;
    }
    const st = captureForm();
    ui.detailSig = sig;
    const b = bannerFor(c);
    const s = stateOf(c);
    $('#view').innerHTML =
      '<nav class="crumbs" aria-label="Breadcrumb"><a href="#/cases">← Cases</a></nav>' +
      '<header class="case-head"><div><h1>Order ' + esc(c.orderId) + ' <span class="mono small muted">' + esc(c.caseId) + '</span></h1>' +
      '<p class="small muted">' + partner(c.partnerId) + ' · opened ' + clock(c.createdAt) + ' BRT · age <span data-age="' + esc(c.createdAt) + '">' + age(now - Date.parse(c.createdAt)) + '</span> · <span class="mono">caseVersion ' + c.caseVersion + '</span> · <span class="mono">state ' + esc(c.state) + '</span></p></div>' +
      '<div class="head-tags">' + chip(c) + ' <span class="tag">SYNTHETIC</span>' + (c.labels.replay ? ' <span class="tag">REPLAY</span>' : '') + ' <a class="btn small-btn" href="#" data-act="trace" title="' + esc(c.visualTraceUrl) + '">Visual Trace ↗</a></div></header>' +
      '<div class="banner tone-' + b[0] + '" role="status"><span class="banner-icon" aria-hidden="true">' + s.icon + '</span><p>' + esc(b[1]) + '</p>' + b[2] + '</div>' +
      (c.dossier && c.state === 'ReviewRequired' ? dossierBlock(c) : '') +
      '<div class="detail-grid"><div class="layers">' +
      section(1, 'l-failure', 'What failed', 'The order as received and every exception, raw.', layerFailure(c)) +
      section(2, 'l-evidence', 'Evidence', 'Observed facts from read-only tools and system checks. Nothing here is interpretation.', layerEvidence(c)) +
      section(3, 'l-diagnosis', 'Diagnosis', 'Interpretation of the evidence, kept separate from the facts.', layerDiagnosis(c)) +
      section(4, 'l-proposal', 'Proposal', 'One action from the closed catalog, checked by the validator.', layerProposal(c)) +
      section(5, 'l-approval', 'Approval', 'A human decision on one exact proposal version.', layerApproval(c, now)) +
      section(6, 'l-execution', 'Execution &amp; receipt', 'Revalidation, attempts, reconciliation and the partner receipt.', layerExecution(c)) +
      (c.dossier && c.state !== 'ReviewRequired' ? dossierBlock(c) : '') +
      '</div>' + timelineBlock() + '</div>' +
      '<p class="footnote small muted">Metrics marked "illustrative" are made up. All data is synthetic.</p>';
    restoreForm(st);
  }

  // ---------------------------------------------------------------- approval dialog
  function openApprove() {
    const c = ui.detail;
    const p = c && c.proposals.find(x => x.proposalId === c.currentProposalId);
    if (!p || c.state !== 'PendingApproval') return;
    const snapshot = { caseId: c.caseId, proposalId: p.proposalId, caseVersion: c.caseVersion };
    const dlg = $('#approve-dialog');
    let diff = '<p class="small">Payload unchanged.</p>';
    if (p.action === 'APPLY_APPROVED_MAPPING') {
      const m = FX.REF.mappings.find(x => x.mappingId === p.params.mappingId) || {};
      diff = '<table class="checks"><thead><tr><th>Field</th><th>Now</th><th>After approval</th></tr></thead><tbody><tr class="changed"><td><code>exams[0].code</code></td><td><code>' + esc(m.sourceCode) + '</code></td><td><code>' + esc(m.targetCode) + '</code></td></tr><tr><td><code>specimen.type</code></td><td colspan="2"><code>' + esc(c.order.snapshot.specimen.type) + '</code> (unchanged; ' + (m.conditions && m.conditions.specimenType ? 'mapping requires ' + esc(m.conditions.specimenType) : 'mapping has no condition') + ')</td></tr><tr><td colspan="3" class="small muted">All other fields unchanged.</td></tr></tbody></table>';
    }
    $('#approve-body').innerHTML =
      '<p class="eyebrow">You are deciding on exactly this</p>' +
      '<p class="effect big"><code>' + esc(p.action) + '</code>: ' + effectText(c, p) + '</p>' + diff +
      '<dl class="kv small"><dt>Proposal</dt><dd class="mono">' + esc(p.proposalId) + '</dd><dt>Case version</dt><dd class="mono">' + c.caseVersion + '</dd><dt>Confidence</dt><dd>' + esc(CONFIDENCE[p.confidence]) + '</dd><dt>Destination</dt><dd>' + partner(c.partnerId) + '</dd></dl>' +
      (p.preconditions.length ? '<p class="small"><b>Re-checked right before sending:</b> ' + p.preconditions.map(x => '<code>' + esc(x.check) + '</code>').join(', ') + ', <code>APPROVAL_VALID</code>. If any fails, nothing is sent.</p>' : '') +
      '<p class="small">Your approval is valid for 15 min. Approving twice never sends twice.</p>' +
      '<label class="field">Your name <span class="muted small">(declared, not authenticated)</span><input id="ap-operator" autocomplete="name" value="' + esc(ui.operator) + '"></label>' +
      '<div id="ap-deny" hidden><label class="field">Reason for denying <span class="muted small">(required, becomes evidence)</span><textarea id="ap-reason" rows="2"></textarea></label></div>' +
      '<div id="ap-error" role="alert"></div>';
    dlg._snapshot = snapshot;
    dlg._mode = 'approve';
    $('#ap-approve').hidden = false; $('#ap-approve').disabled = false;
    $('#ap-deny-toggle').hidden = false; $('#ap-deny-confirm').hidden = true;
    dlg.showModal();
    E.hook(c.caseId, 'onDialogOpen');
  }

  function submitDecision(decision) {
    const dlg = $('#approve-dialog');
    const s = dlg._snapshot;
    const name = $('#ap-operator').value.trim();
    const errBox = $('#ap-error');
    if (!name || name.indexOf(':') >= 0) { errBox.innerHTML = '<p class="err">Enter your name (no colon). It is recorded as the author of this decision.</p>'; $('#ap-operator').focus(); return; }
    const body = { decision, operator: name, expectedCaseVersion: s.caseVersion };
    if (decision === 'denied') body.reason = $('#ap-reason').value;
    setOperator(name);
    $('#ap-approve').disabled = true;
    const r = E.api.decide(s.caseId, s.proposalId, body);
    if (r.status === 201) {
      dlg.close();
      toast(decision === 'approved' ? 'Approved ' + s.proposalId + '. Preconditions are re-checked before sending.' : 'Denied. A new investigation will use your reason.', 'ok');
      render(true);
    } else if (r.status === 200 && r.body.idempotentReplay) {
      dlg.close();
      toast('Already approved by ' + r.body.approval.by.replace('operator:', '') + '. No new effect.', 'info');
      render(true);
    } else if (r.status === 409 && r.body.error.code === 'STALE_VERSION') {
      errBox.innerHTML = '<div class="err"><p><b>This proposal changed while you were reviewing it. Nothing was approved.</b></p><p class="small">Server: 409 STALE_VERSION. Current proposal is ' + esc(r.body.error.details.currentProposalId) + ' at case version ' + esc(r.body.error.details.caseVersion) + '.</p><button type="button" class="btn primary" id="ap-reload">Review the new version</button></div>';
      $('#ap-approve').hidden = true; $('#ap-deny-toggle').hidden = true; $('#ap-deny-confirm').hidden = true;
      $('#ap-reload').addEventListener('click', () => { dlg.close(); render(true); openApprove(); });
      $('#ap-reload').focus();
    } else {
      $('#ap-approve').disabled = false;
      errBox.innerHTML = '<p class="err"><b>Not recorded.</b> ' + esc(r.status + ' ' + r.body.error.code + ': ' + r.body.error.message) + '</p>';
    }
  }

  // ---------------------------------------------------------------- resolution
  function submitResolve(ev) {
    ev.preventDefault();
    const c = ui.detail;
    const kind = ($('#resolve-form input[name=kind]:checked') || {}).value;
    const box = $('#resolve-result');
    const name = $('#rk-operator').value.trim();
    const note = $('#rk-note').value.trim();
    if (!kind) { box.innerHTML = '<p class="err">Choose an option.</p>'; return; }
    if (!name || name.indexOf(':') >= 0) { box.innerHTML = '<p class="err">Enter your name (no colon).</p>'; $('#rk-operator').focus(); return; }
    setOperator(name);
    let body;
    if (kind === 'cancel') body = { kind: 'cancel', operator: name, expectedCaseVersion: c.caseVersion, reason: note };
    else {
      const params = {};
      if (kind === 'APPLY_APPROVED_MAPPING') { const v = $('#rk-mapping').value.split('|'); params.mappingId = v[0]; params.mappingVersion = v[1]; }
      if (kind === 'HOLD' && note) params.reason = note;
      body = { kind: 'action', operator: name, expectedCaseVersion: c.caseVersion, action: kind, params, note };
    }
    const r = E.api.resolve(c.caseId, body);
    if (r.status === 201) { toast(kind === 'cancel' ? 'Case cancelled.' : 'Accepted by the validator. ' + (kind === 'HOLD' ? 'Case on hold.' : 'Approved by you; execution follows.'), 'ok'); render(true); return; }
    if (r.status === 422) {
      const v = r.body.error.details.verdict;
      box.innerHTML = '<div class="err"><p><b>The validator blocked this. Nothing was executed.</b></p><p class="small">' + v.reasons.map(x => '<code>' + esc(x) + '</code> ' + esc(REASON_TEXT[x] || '')).join('<br>') + '</p></div>';
      return;
    }
    box.innerHTML = '<p class="err"><b>Not recorded.</b> ' + esc(r.status + ' ' + r.body.error.code + ': ' + r.body.error.message) + '</p>';
  }
  const REASON_TEXT = {
    MAPPING_CONDITION_MISMATCH: 'The mapping condition does not match this order (specimen type).',
    MAPPING_UNKNOWN: 'The mapping is not in the approved catalog.',
    MAPPING_VERSION_MISMATCH: 'The mapping version is not the approved one.',
    MAPPING_SOURCE_CODE_MISMATCH: 'The mapping does not translate this order\'s code.',
    POLICY_CODE_DISCONTINUED: 'Policy says this code is discontinued, so a retry would fail again.',
    IDENTITY_UNRESOLVED: 'Patient identity is ambiguous. Confirm it at the origin first; hold or cancel are allowed.',
    ALREADY_IN_REVIEW: 'The case is already in review.'
  };

  // ---------------------------------------------------------------- benchmark
  function renderBenchmark(force) {
    if (!force) return;
    const B = FX.BENCH;
    const fams = ['P5', 'P8b', 'clean'];
    const row = r => '<tr><td>' + esc(r.mode === 'agent' ? 'Rules + Agent' : 'Rules') + '</td><td>' + r.runs + '</td><td><b>' + r.correct + '</b></td><td>' + r.safe_review + '</td><td>' + r.unnecessary_review + '</td><td>' + r.incorrect + '</td><td>' + r.p50s + ' / ' + r.p95s + ' s</td><td>' + r.toolCalls + '</td><td>' + (r.costUsd ? 'US$ ' + r.costUsd.toFixed(3) : '—') + '</td></tr>';
    $('#view').innerHTML =
      '<div class="page-head"><div><h1>Benchmark</h1><p class="lead">Rules versus Rules + Agent on the same scenarios, with the same tools and protections. Ties and losses are published as they are.</p></div></div>' +
      '<div class="banner tone-warn" role="note"><span class="banner-icon" aria-hidden="true">!</span><p><b>' + esc(B.note) + '</b> This page only tests the layout of the report.</p></div>' +
      '<div class="card"><h2 class="h2-card">Frozen before the test</h2><p class="small">' + Object.keys(B.frozen).map(k => esc(k) + ' <code>' + esc(B.frozen[k]) + '</code>').join(' · ') + '</p><p class="small muted">' + esc(B.design) + '. Repetitions measure instability; they are not independent cases.</p></div>' +
      '<section class="layer"><h2><span class="layer-n">A</span> Agent decision</h2><p class="layer-sub">Counts out of runs per family and mode. Test set only. A blocked wrong proposal counts as incorrect for the proposer, not as an effect.</p>' +
      fams.map(f => {
        const rows = B.decision.filter(r => r.family === f);
        const delta = rows[1].correct - rows[0].correct;
        return '<div class="card"><h3>' + esc(f === 'clean' ? 'Clean controls' : f) + ' <span class="tag ' + (delta > 0 ? 'ok' : delta < 0 ? 'danger' : 'gray') + '">' + (delta > 0 ? 'agent +' + delta : delta < 0 ? 'agent ' + delta : 'tie') + '</span></h3><div class="table-wrap"><table class="checks"><thead><tr><th>Mode</th><th>Runs</th><th>Correct</th><th>Safe review</th><th>Unnecessary review</th><th>Incorrect</th><th>p50 / p95</th><th>Tool calls</th><th>Cost / case</th></tr></thead><tbody>' + rows.map(row).join('') + '</tbody></table></div></div>';
      }).join('') + '</section>' +
      '<section class="layer"><h2><span class="layer-n">B</span> Platform guarantees</h2><p class="layer-sub">Pass/fail for any proposer. Not counted as agent merit.</p><ul class="plain">' +
      B.guarantees.map(g => '<li class="card guarantee"><span class="tag ' + (g.result === 'pass' ? 'ok' : 'danger') + '">' + esc(g.result) + '</span> ' + esc(g.check) + '</li>').join('') + '</ul></section>' +
      '<p class="small"><a href="#" data-act="noop">Export raw results (JSON)</a> <span class="muted">is not implemented in the prototype.</span></p>';
  }

  // ---------------------------------------------------------------- scenario panel
  function renderPanel() {
    const r = route();
    const c = r.name === 'case' ? E.S.cases.get(r.id) : null;
    const acts = c ? E.scenarioActions(c.caseId) : [];
    const canReplay = c && !!E.S.lastDecision[c.caseId];
    const sig = (c ? c.caseId + c.state + c.lastEventSeq : r.name) + '|' + Array.from(E.S.cases.keys()).join(',') + acts.map(a => a.enabled).join(',') + canReplay;
    if (sig === ui.panelSig) return;
    ui.panelSig = sig;
    const tiers = [['core', 'Core story'], ['ui', 'UI guarantee'], ['guarantee', 'Platform guarantees'], ['conditional', 'Conditional']];
    $('#panel-body').innerHTML =
      (c ? '<div class="panel-case"><h3>This case</h3>' +
        (acts.length ? acts.map(a => '<button type="button" class="btn block" data-scn-action="' + esc(a.id) + '"' + (a.enabled ? '' : ' disabled') + '>' + esc(a.label) + '</button>').join('') : '') +
        '<button type="button" class="btn block" data-act="replay"' + (canReplay ? '' : ' disabled') + '>Send the same approval again (second tab)</button>' +
        '<p class="small muted">Disabled buttons become available when the case reaches the right state.</p></div>' : '') +
      tiers.map(t => '<h3 class="panel-tier">' + t[1] + '</h3>' + E.scenarios.filter(s => s.tier === t[0]).map(s => {
        const running = Array.from(E.S.cases.values()).find(x => x._scenario === s.id);
        return '<div class="scn"><p class="scn-title"><b>' + esc(s.title) + '</b> <span class="tag gray">' + esc(s.family) + '</span></p><p class="small">' + esc(s.summary) + '</p><p class="small muted"><b>Expect:</b> ' + esc(s.expect) + '</p>' +
          '<div class="scn-btns"><button type="button" class="btn primary small-btn" data-run="' + esc(s.id) + '">' + (running ? 'Restart' : 'Run') + '</button>' + (running ? ' <a class="btn small-btn" href="#/cases/' + esc(running.caseId) + '">Open</a>' : '') + '</div></div>';
      }).join('')).join('') +
      '<hr><button type="button" class="btn block" data-act="reset">Reset the whole prototype</button>';
  }

  // ---------------------------------------------------------------- events
  function setOperator(name) {
    ui.operator = name;
    $('#operator').value = name;
    try { localStorage.setItem('sn-proto-operator', name); } catch (e) { /* ignore */ }
  }

  document.addEventListener('click', ev => {
    const t = ev.target.closest('[data-filter],[data-act],[data-ev],[data-run],[data-scn-action]');
    if (!t) return;
    if (t.hasAttribute('data-filter')) { ui.filter = t.getAttribute('data-filter'); render(true); return; }
    if (t.hasAttribute('data-ev')) {
      const el = document.getElementById('ev-' + t.getAttribute('data-ev'));
      if (el) { el.scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'center' }); el.classList.remove('hl'); void el.offsetWidth; el.classList.add('hl'); el.focus({ preventScroll: true }); }
      return;
    }
    if (t.hasAttribute('data-run')) {
      const id = E.runScenario(t.getAttribute('data-run'));
      ui.panelSig = '';
      if (location.hash === '#/cases/' + id) onRoute(); else location.hash = '#/cases/' + id;
      if (matchMedia('(max-width: 900px)').matches) togglePanel(false);
      return;
    }
    if (t.hasAttribute('data-scn-action')) {
      const msg = E.runAction(route().id, t.getAttribute('data-scn-action'));
      toast(msg, 'info'); render(true); return;
    }
    const act = t.getAttribute('data-act');
    if (act === 'open-approve') openApprove();
    else if (act === 'trace') { ev.preventDefault(); toast('The real UI opens the Visual Trace session in IRIS: ' + (ui.detail ? ui.detail.visualTraceUrl : ''), 'info'); }
    else if (act === 'noop') ev.preventDefault();
    else if (act === 'goto-dossier') { const d = $('#dossier'); if (d) { d.scrollIntoView({ block: 'start' }); d.focus({ preventScroll: true }); } }
    else if (act === 'reset') { E.reset(); ui.timelineCase = null; ui.panelSig = ''; location.hash = '#/cases'; onRoute(); toast('Prototype reset.', 'info'); }
    else if (act === 'replay') {
      const r = E.api.replayLastDecision(route().id);
      if (!r) return;
      toast(r.status === 200 && r.body.idempotentReplay ? '200 · idempotentReplay: true. The existing approval came back; no new execution.' : r.status + ' ' + (r.body.error ? r.body.error.code : ''), 'info');
      render(true);
    }
  });

  document.addEventListener('submit', ev => { if (ev.target.id === 'resolve-form') submitResolve(ev); });

  function togglePanel(force) {
    const p = $('#panel');
    const open = typeof force === 'boolean' ? force : p.hidden;
    p.hidden = !open;
    $('#panel-toggle').setAttribute('aria-expanded', String(open));
    document.body.classList.toggle('panel-open', open);
    if (open) { ui.panelSig = ''; renderPanel(); }
  }

  function init() {
    E.reset();
    $('#operator').value = ui.operator;
    $('#operator').addEventListener('change', e => setOperator(e.target.value.trim()));
    $('#panel-toggle').addEventListener('click', () => togglePanel());
    $('#panel-close').addEventListener('click', () => { togglePanel(false); $('#panel-toggle').focus(); });
    $('#log-toggle').addEventListener('click', () => { const l = $('#apilog'); l.hidden = !l.hidden; $('#log-toggle').setAttribute('aria-expanded', String(!l.hidden)); ui.logSig = ''; renderLog(); });
    $('#log-polling').addEventListener('change', e => { ui.logPolling = e.target.checked; ui.logSig = ''; renderLog(); });
    $('#ap-approve').addEventListener('click', () => submitDecision('approved'));
    $('#ap-deny-toggle').addEventListener('click', () => { $('#ap-deny').hidden = false; $('#ap-deny-toggle').hidden = true; $('#ap-deny-confirm').hidden = false; $('#ap-approve').hidden = true; $('#ap-reason').focus(); });
    $('#ap-deny-confirm').addEventListener('click', () => submitDecision('denied'));
    $('#ap-cancel').addEventListener('click', () => $('#approve-dialog').close());
    window.addEventListener('hashchange', onRoute);
    if (matchMedia('(min-width: 1200px)').matches) togglePanel(true);
    onRoute();
    setInterval(E.tick, E.TICK_MS);
    setInterval(() => render(false), POLL_MS);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();
