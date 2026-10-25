// One open case: its detail and its timeline, read incrementally by sinceSeq. The timeline is
// reloaded in full if lastEventSeq goes backwards (case recreated).
import { getCase, getTimeline } from '../api/client';
import type { CaseDetail, TimelineEvent } from '../api/types';
import { connection } from './connection.svelte';

export class CaseDetailState {
	caseId: string;
	detail = $state<CaseDetail | null>(null);
	events = $state<TimelineEvent[]>([]);
	notFound = $state(false);
	error = $state('');
	private lastSeq = 0;

	constructor(caseId: string) {
		this.caseId = caseId;
	}

	async refresh(): Promise<void> {
		const r = await getCase(this.caseId);
		if (!r.ok) {
			if (r.status === 0) connection.failed();
			else if (r.status === 404) this.notFound = true;
			else this.error = r.message;
			return;
		}
		connection.ok();
		this.notFound = false;
		this.error = '';
		const d = r.data;
		if (d.lastEventSeq < this.lastSeq) {
			this.lastSeq = 0;
			this.events = [];
		}
		this.detail = d;
		if (d.lastEventSeq > this.lastSeq) await this.timeline();
	}

	private async timeline(): Promise<void> {
		for (let guard = 0; guard < 20; guard++) {
			const t = await getTimeline(this.caseId, this.lastSeq);
			if (!t.ok) {
				if (t.status === 0) connection.failed();
				return;
			}
			const known = new Set(this.events.map((e) => e.seq));
			const fresh = t.data.events.filter((e) => !known.has(e.seq));
			if (fresh.length) this.events = [...this.events, ...fresh].sort((a, b) => a.seq - b.seq);
			this.lastSeq = Math.max(this.lastSeq, t.data.nextSinceSeq);
			if (!t.data.hasMore) return;
		}
	}
}
