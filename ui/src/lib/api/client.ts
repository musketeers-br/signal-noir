// Typed calls of the operations the console uses (contracts/openapi-signalnoir.yaml).
import { toOutcome, type Outcome } from './outcome';
import { NetworkError, fetchTransport, type Answer, type Transport } from './transport';
import type {
	ActionCatalogEntry,
	ApprovedMapping,
	CaseDetail,
	CaseListPage,
	ProposalDecisionResult,
	ReviewResolutionResult,
	TimelinePage
} from './types';

let transport: Transport = fetchTransport();

export function setTransport(t: Transport): void {
	transport = t;
}

export type Read<T> = { ok: true; data: T } | { ok: false; status: number; message: string } | { ok: false; status: 0; message: 'network' };

async function read<T>(path: string): Promise<Read<T>> {
	let answer: Answer;
	try {
		answer = await transport.request('GET', path);
	} catch (e) {
		if (e instanceof NetworkError) return { ok: false, status: 0, message: 'network' };
		throw e;
	}
	if (answer.status === 200) return { ok: true, data: answer.body as T };
	const message = (answer.body as { error?: { message?: string } })?.error?.message ?? `HTTP ${answer.status}`;
	return { ok: false, status: answer.status, message };
}

async function command<T>(path: string, body: unknown): Promise<Outcome<T>> {
	try {
		return toOutcome<T>(await transport.request('POST', path, body));
	} catch (e) {
		if (e instanceof NetworkError) return toOutcome<T>('network');
		throw e;
	}
}

export interface ListQuery {
	cursor?: string | null;
	direction?: 'older' | 'newer';
	limit?: number;
	states?: string[];
	status?: 'open' | 'terminal' | 'all';
}

export function listCases(q: ListQuery = {}): Promise<Read<CaseListPage>> {
	const p = new URLSearchParams();
	if (q.cursor) p.set('cursor', q.cursor);
	if (q.direction) p.set('direction', q.direction);
	if (q.limit) p.set('limit', String(q.limit));
	for (const s of q.states ?? []) p.append('state', s);
	if (q.status && q.status !== 'all') p.set('status', q.status);
	const qs = p.toString();
	return read<CaseListPage>(`/cases${qs ? `?${qs}` : ''}`);
}

export function getCase(caseId: string): Promise<Read<CaseDetail>> {
	return read<CaseDetail>(`/cases/${encodeURIComponent(caseId)}`);
}

export function getTimeline(caseId: string, sinceSeq = 0): Promise<Read<TimelinePage>> {
	return read<TimelinePage>(`/cases/${encodeURIComponent(caseId)}/timeline?sinceSeq=${sinceSeq}`);
}

export interface DecisionRequest {
	decision: 'approved' | 'denied';
	operator: string;
	expectedCaseVersion: number;
	reason?: string;
}

export function decide(caseId: string, proposalId: string, body: DecisionRequest): Promise<Outcome<ProposalDecisionResult>> {
	return command(`/cases/${encodeURIComponent(caseId)}/proposals/${encodeURIComponent(proposalId)}/decision`, body);
}

export type ResolutionRequest =
	| { kind: 'action'; operator: string; expectedCaseVersion: number; action: string; params: Record<string, string>; note?: string }
	| { kind: 'cancel'; operator: string; expectedCaseVersion: number; reason: string };

export function resolve(caseId: string, body: ResolutionRequest): Promise<Outcome<ReviewResolutionResult>> {
	return command(`/cases/${encodeURIComponent(caseId)}/resolution`, body);
}

export function mappings(sourceCode?: string): Promise<Read<{ mappingVersion: string; items: ApprovedMapping[] }>> {
	return read(`/reference/mappings${sourceCode ? `?sourceCode=${encodeURIComponent(sourceCode)}` : ''}`);
}

export function actionCatalog(): Promise<Read<{ items: ActionCatalogEntry[] }>> {
	return read('/reference/action-catalog');
}
