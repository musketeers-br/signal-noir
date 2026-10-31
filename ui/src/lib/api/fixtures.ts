// A fake server that answers the console's contract operations from contracts/fixtures/**.
// It powers the tests and `npm run dev:mock`. Fixtures are read, never edited. Tests can script
// the next answer to an operation (status + body) or make it fail with no answer.
import { ACTIONS, type CaseDetail, type CaseListPage, type CaseSummary, type TimelinePage } from './types';
import { NetworkError, type Answer, type Transport } from './transport';

const files = import.meta.glob('../../../../contracts/fixtures/*.json', { eager: true, import: 'default' }) as Record<string, unknown>;

export function fixture<T = unknown>(name: string): T {
	const key = Object.keys(files).find((k) => k.endsWith(`/${name}`));
	if (!key) throw new Error(`fixture not found: ${name}`);
	return structuredClone(files[key]) as T;
}

/** The detail served by default for a caseId (the earliest state of each story). */
const DEFAULT_DETAIL: Record<string, string> = {
	case_9f3a1c: 'case.pending-approval.p5-p8b.json',
	case_51b0e2: 'case.pending-approval.superseded.json',
	case_7d22e0: 'case.held.p3.json',
	case_e8a0f4: 'case.executing.outcome-unknown.json',
	case_d91c07: 'case.resolved-by-prior-receipt.p9.json',
	case_c4e1a9: 'case.review.after-denial.json',
	case_0b6f19: 'case.review.ambiguous-identity.json',
	case_a37b5d: 'case.review.provider-unavailable.json'
};

const TERMINAL = ['Resolved', 'ResolvedByPriorReceipt', 'Cancelled', 'Failed'];

interface Scripted {
	method: string;
	match: string;
	answer: Answer | 'network';
}

export interface Call {
	method: string;
	path: string;
	body?: unknown;
}

export class FixtureServer implements Transport {
	private scripted: Scripted[] = [];
	private details = new Map<string, CaseDetail>();
	readonly calls: Call[] = [];
	/** Cases returned to a `direction=newer` poll (none by default). */
	newer: CaseSummary[] = [];
	/** Fixture served to GET /cases/{id}/precedents (015). */
	precedents = 'precedents.200.results.json';

	constructor() {
		for (const [id, file] of Object.entries(DEFAULT_DETAIL)) this.details.set(id, fixture<CaseDetail>(file));
	}

	/** The next request whose path contains `match` gets this answer. */
	next(method: 'GET' | 'POST', match: string, status: number, body: unknown): void {
		this.scripted.push({ method, match, answer: { status, body } });
	}

	/** The next request whose path contains `match` gets no answer. */
	failNext(method: 'GET' | 'POST', match: string): void {
		this.scripted.push({ method, match, answer: 'network' });
	}

	/** Replace what GET /cases/{id} returns from now on. */
	setDetail(detail: CaseDetail): void {
		this.details.set(detail.caseId, detail);
	}

	detail(caseId: string): CaseDetail | undefined {
		return this.details.get(caseId);
	}

	async request(method: 'GET' | 'POST', path: string, body?: unknown): Promise<Answer> {
		this.calls.push({ method, path, body });
		const i = this.scripted.findIndex((s) => s.method === method && path.includes(s.match));
		if (i >= 0) {
			const [s] = this.scripted.splice(i, 1);
			if (s.answer === 'network') throw new NetworkError();
			return structuredClone(s.answer);
		}
		return this.route(method, path, body);
	}

	private route(method: string, path: string, body?: unknown): Answer {
		const url = new URL(path, 'http://fixture');
		const parts = url.pathname.split('/').filter(Boolean);
		if (method === 'GET' && parts[0] === 'cases' && parts.length === 1) return this.list(url.searchParams);
		if (method === 'GET' && parts[0] === 'cases' && parts.length === 2) {
			const d = this.details.get(parts[1]);
			return d ? { status: 200, body: structuredClone(d) } : { status: 404, body: fixture('case.404.json') };
		}
		if (method === 'GET' && parts[0] === 'cases' && parts[2] === 'precedents') {
			if (!this.details.has(parts[1])) return { status: 404, body: fixture('case.404.json') };
			const body = fixture<{ caseId: string }>(this.precedents);
			body.caseId = parts[1];
			return { status: 200, body };
		}
		if (method === 'GET' && parts[0] === 'cases' && parts[2] === 'timeline') return this.timeline(parts[1], Number(url.searchParams.get('sinceSeq') ?? 0));
		if (method === 'POST' && parts[2] === 'proposals' && parts[4] === 'decision') {
			const decision = (body as { decision?: string })?.decision;
			return { status: 201, body: fixture(decision === 'denied' ? 'decision.201.denied.json' : 'decision.201.approved.json') };
		}
		if (method === 'POST' && parts[2] === 'resolution') {
			const kind = (body as { kind?: string })?.kind;
			return { status: 201, body: fixture(kind === 'cancel' ? 'resolution.201.cancel.json' : 'resolution.201.action.json') };
		}
		if (method === 'GET' && path.startsWith('/reference/mappings')) {
			const all = fixture<{ mappingVersion: string; items: { sourceCode: string }[]; serverTime: string }>('reference.mappings.json');
			const code = url.searchParams.get('sourceCode');
			if (code) all.items = all.items.filter((m) => m.sourceCode === code);
			return { status: 200, body: all };
		}
		if (method === 'GET' && path.startsWith('/reference/action-catalog')) {
			return {
				status: 200,
				body: {
					items: ACTIONS.map((action) => {
						const externalEffect = action === 'RETRY' || action === 'APPLY_APPROVED_MAPPING';
						// only an Action with an external effect needs Approval (R19, FR-16)
						return {
							action,
							externalEffect,
							requiresApproval: externalEffect,
							paramsSchema: action === 'APPLY_APPROVED_MAPPING' ? { required: ['mappingId', 'mappingVersion'] } : {},
							requiredEvidence: []
						};
					}),
					serverTime: '2026-10-29T13:00:00Z'
				}
			};
		}
		return { status: 404, body: fixture('case.404.json') };
	}

	private list(q: URLSearchParams): Answer {
		const a = fixture<CaseListPage>('cases.list.needs-you.json');
		const b = fixture<CaseListPage>('cases.list.outcome-unknown.json');
		if (q.get('direction') === 'newer') {
			const items = this.newer;
			this.newer = [];
			return { status: 200, body: { items, nextCursor: null, headCursor: items.length ? `head-${items.length}-${Date.now()}` : a.headCursor, serverTime: a.serverTime } };
		}
		const seen = new Set<string>();
		let items = [...a.items, ...b.items].filter((c) => (seen.has(c.caseId) ? false : (seen.add(c.caseId), true)));
		const states = q.getAll('state');
		if (states.length) items = items.filter((c) => states.includes(c.state));
		const status = q.get('status');
		if (status === 'open') items = items.filter((c) => !TERMINAL.includes(c.state));
		if (status === 'terminal') items = items.filter((c) => TERMINAL.includes(c.state));
		items.sort((x, y) => (x.lastEventAt < y.lastEventAt ? 1 : x.lastEventAt > y.lastEventAt ? -1 : 0));
		return { status: 200, body: { items, nextCursor: null, headCursor: a.headCursor, serverTime: a.serverTime } };
	}

	private timeline(caseId: string, sinceSeq: number): Answer {
		const full = fixture<TimelinePage>('timeline.full.p5-p8b.json');
		const d = this.details.get(caseId);
		if (!d) return { status: 404, body: fixture('case.404.json') };
		const events = caseId === full.caseId ? full.events.filter((e) => e.seq > sinceSeq && e.seq <= d.lastEventSeq) : [];
		const last = events.length ? events[events.length - 1].seq : sinceSeq;
		return { status: 200, body: { caseId, state: d.state, events, hasMore: false, nextSinceSeq: last, caseVersion: d.caseVersion, lastEventSeq: d.lastEventSeq, serverTime: d.serverTime } };
	}
}
