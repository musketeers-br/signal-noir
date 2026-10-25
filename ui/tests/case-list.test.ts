import { render, screen, within } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { fixture } from '../src/lib/api/fixtures';
import type { CaseListPage } from '../src/lib/api/types';
import CaseList from '../src/lib/components/CaseList.svelte';
import { CaseListState } from '../src/lib/stores/cases.svelte';
import { violations } from './a11y';
import { flush, server } from './helpers';

// T012 - US1: see which Cases need me, live
describe('case list', () => {
	it('opens on Needs you with the contract filter and labelled rows', async () => {
		const s = server();
		const list = new CaseListState();
		await list.load();
		const { container } = render(CaseList, { list });
		expect(s.calls[0].path).toBe('/cases?limit=50&state=PendingApproval&state=ReviewRequired');
		expect(screen.getByRole('button', { name: 'Needs you' })).toHaveAttribute('aria-pressed', 'true');
		const rows = screen.getAllByRole('listitem');
		expect(rows.length).toBeGreaterThan(0);
		for (const row of rows) {
			const text = row.textContent ?? '';
			expect(text).toMatch(/Needs approval|Review required/);
			expect(text).toContain('SYNTHETIC');
		}
		const first = within(rows[0]);
		expect(first.getByText(/Age /)).toBeInTheDocument();
		expect(await violations(container)).toEqual([]);
	});

	it('shows Outcome unknown for Executing + reconciling, and the other filters map to status', async () => {
		const s = server();
		const list = new CaseListState();
		render(CaseList, { list });
		await list.load('active');
		await flush();
		expect(s.calls.at(-1)!.path).toBe('/cases?limit=50&status=open');
		expect(screen.getByText('Outcome unknown')).toBeInTheDocument();
		await userEvent.click(screen.getByRole('button', { name: 'Closed' }));
		await flush();
		expect(s.calls.at(-1)!.path).toBe('/cases?limit=50&status=terminal');
		await userEvent.click(screen.getByRole('button', { name: 'All' }));
		await flush();
		expect(s.calls.at(-1)!.path).toBe('/cases?limit=50');
	});

	it('a poll merges a new and a changed case in place, without remounting rows', async () => {
		const s = server();
		const list = new CaseListState();
		await list.load();
		render(CaseList, { list });
		const before = document.querySelector('[data-case-id="case_0b6f19"]');
		const page = fixture<CaseListPage>('cases.list.needs-you.json');
		const changed = { ...page.items.find((c) => c.caseId === 'case_a37b5d')!, state: 'PendingApproval' as const, lastEventAt: '2026-10-29T14:00:00Z' };
		const fresh = { ...changed, caseId: 'case_new001', orderId: 'ORD-NEW', lastEventAt: '2026-10-29T14:01:00Z' };
		s.newer = [changed, fresh];
		await list.poll();
		await flush();
		expect(s.calls.at(-1)!.path).toContain('direction=newer');
		expect(document.querySelector('[data-case-id="case_new001"]')).not.toBeNull();
		expect(document.querySelector('[data-case-id="case_a37b5d"]')!.textContent).toContain('Needs approval');
		expect(document.querySelector('[data-case-id="case_0b6f19"]')).toBe(before);
		expect(screen.getByText('2 cases changed.')).toBeInTheDocument();
	});

	it('pages back with the cursor on request, and says when Needs you is empty', async () => {
		const s = server();
		const page = fixture<CaseListPage>('cases.list.needs-you.json');
		s.next('GET', '/cases?limit=50', 200, { ...page, nextCursor: 'cur-older-1' });
		const list = new CaseListState();
		await list.load();
		render(CaseList, { list });
		s.next('GET', 'direction=older', 200, { items: [{ ...page.items[0], caseId: 'case_old0001', orderId: 'ORD-OLD' }], nextCursor: null, headCursor: 'x', serverTime: page.serverTime });
		await userEvent.click(screen.getByRole('button', { name: 'Load older cases' }));
		await flush();
		expect(s.calls.at(-1)!.path).toContain('cursor=cur-older-1');
		expect(document.querySelector('[data-case-id="case_old0001"]')).not.toBeNull();
		expect(screen.queryByRole('button', { name: 'Load older cases' })).toBeNull();

		s.next('GET', '/cases?limit=50', 200, { items: [], nextCursor: null, headCursor: 'h', serverTime: page.serverTime });
		await list.load('needs-you');
		await flush();
		expect(screen.getByText('No case needs a decision from you right now.')).toBeInTheDocument();
	});
});
