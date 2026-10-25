// The case list: one filter at a time, a first page, older pages on request (no infinite
// scroll), and polling for newer changes with the contract cursor. Rows are merged by caseId so
// existing rows (and focus on them) survive a poll.
import { listCases, type ListQuery } from '../api/client';
import type { CaseSummary } from '../api/types';
import { connection } from './connection.svelte';

export type Filter = 'needs-you' | 'active' | 'closed' | 'all';

export const FILTERS: { id: Filter; label: string }[] = [
	{ id: 'needs-you', label: 'Needs you' },
	{ id: 'active', label: 'Active' },
	{ id: 'closed', label: 'Closed' },
	{ id: 'all', label: 'All' }
];

export function filterQuery(f: Filter): ListQuery {
	if (f === 'needs-you') return { states: ['PendingApproval', 'ReviewRequired'] };
	if (f === 'active') return { status: 'open' };
	if (f === 'closed') return { status: 'terminal' };
	return {};
}

function matches(f: Filter, c: CaseSummary): boolean {
	const terminal = ['Resolved', 'ResolvedByPriorReceipt', 'Cancelled', 'Failed'].includes(c.state);
	if (f === 'needs-you') return c.state === 'PendingApproval' || c.state === 'ReviewRequired';
	if (f === 'active') return !terminal;
	if (f === 'closed') return terminal;
	return true;
}

export class CaseListState {
	filter = $state<Filter>('needs-you');
	rows = $state<CaseSummary[]>([]);
	loaded = $state(false);
	error = $state('');
	nextCursor = $state<string | null>(null);
	serverTime = $state('');
	/** caseIds changed by the last poll (announced once) */
	changed = $state<string[]>([]);
	private headCursor = '';

	async load(filter: Filter = this.filter): Promise<void> {
		this.filter = filter;
		const r = await listCases({ ...filterQuery(filter), limit: 50 });
		if (!r.ok) {
			if (r.status === 0) connection.failed();
			this.error = r.message;
			return;
		}
		connection.ok();
		this.error = '';
		this.rows = r.data.items;
		this.nextCursor = r.data.nextCursor ?? null;
		this.headCursor = r.data.headCursor;
		this.serverTime = r.data.serverTime;
		this.loaded = true;
		this.changed = [];
	}

	async older(): Promise<void> {
		if (!this.nextCursor) return;
		const r = await listCases({ ...filterQuery(this.filter), cursor: this.nextCursor, direction: 'older', limit: 50 });
		if (!r.ok) {
			if (r.status === 0) connection.failed();
			return;
		}
		connection.ok();
		const known = new Set(this.rows.map((c) => c.caseId));
		this.rows = [...this.rows, ...r.data.items.filter((c) => !known.has(c.caseId))];
		this.nextCursor = r.data.nextCursor ?? null;
	}

	/** Poll: ask for what changed since the head cursor and merge it in place. */
	async poll(): Promise<void> {
		if (!this.loaded) return this.load();
		const r = await listCases({ ...filterQuery(this.filter), cursor: this.headCursor, direction: 'newer', limit: 200 });
		if (!r.ok) {
			if (r.status === 0) connection.failed();
			return;
		}
		connection.ok();
		this.serverTime = r.data.serverTime;
		if (r.data.headCursor) this.headCursor = r.data.headCursor;
		if (!r.data.items.length) {
			this.changed = [];
			return;
		}
		const rows = [...this.rows];
		const changed: string[] = [];
		for (const c of r.data.items) {
			const i = rows.findIndex((x) => x.caseId === c.caseId);
			if (!matches(this.filter, c)) {
				if (i >= 0) rows.splice(i, 1);
				continue;
			}
			if (i >= 0) rows[i] = c;
			else rows.unshift(c);
			changed.push(c.caseId);
		}
		rows.sort((a, b) => (a.lastEventAt < b.lastEventAt ? 1 : a.lastEventAt > b.lastEventAt ? -1 : a.caseId < b.caseId ? 1 : -1));
		this.rows = rows;
		this.changed = changed;
	}
}
