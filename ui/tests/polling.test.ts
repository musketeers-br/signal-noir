import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { fixture } from '../src/lib/api/fixtures';
import type { CaseDetail as Detail } from '../src/lib/api/types';
import CaseDetail from '../src/lib/components/CaseDetail.svelte';
import ConnectionNote from '../src/lib/components/ConnectionNote.svelte';
import { CaseDetailState } from '../src/lib/stores/caseDetail.svelte';
import { connection } from '../src/lib/stores/connection.svelte';
import { operator } from '../src/lib/stores/operator.svelte';
import { flush, server, until } from './helpers';

// T025 - US6: polling that respects the Operator
describe('polling', () => {
	it('keeps focus and typed text in the dialog across polls with changes', async () => {
		const s = server();
		operator.set('Carla');
		const view = new CaseDetailState('case_9f3a1c');
		await view.refresh();
		render(CaseDetail, { view });
		await userEvent.click(screen.getByTestId('state-banner').querySelector('button')!);
		await userEvent.click(screen.getByRole('button', { name: 'Deny…' }));
		const reason = screen.getByTestId('deny-reason') as HTMLTextAreaElement;
		await userEvent.type(reason, 'plasma, not serum');
		for (let v = 5; v <= 7; v++) {
			const d = fixture<Detail>('case.pending-approval.p5-p8b.json');
			d.caseVersion = v;
			d.lastEventAt = `2026-10-29T13:0${v}:00Z`;
			s.setDetail(d);
			await view.refresh();
			await flush();
		}
		expect(document.activeElement).toBe(screen.getByTestId('deny-reason'));
		expect((screen.getByTestId('deny-reason') as HTMLTextAreaElement).value).toBe('plasma, not serum');
	});

	it('keeps expanded sections and inline errors across polls', async () => {
		const s = server();
		operator.set('Carla');
		const view = new CaseDetailState('case_51b0e2');
		await view.refresh();
		render(CaseDetail, { view });
		await userEvent.click(screen.getByRole('button', { name: 'Earlier versions (1)' }));
		await userEvent.click(screen.getByTestId('state-banner').querySelector('button')!);
		s.next('POST', '/decision', 409, fixture('decision.409.stale-version.json'));
		await userEvent.click(screen.getByRole('button', { name: 'Approve this version' }));
		await flush();
		const d = fixture<Detail>('case.pending-approval.superseded.json');
		d.lastEventSeq += 1;
		s.setDetail(d);
		await view.refresh();
		await flush();
		expect(screen.getByRole('button', { name: 'Earlier versions (1)' })).toHaveAttribute('aria-expanded', 'true');
		expect(screen.getByRole('alert').textContent).toContain('Nothing was recorded.');
	});

	it('a failing poll shows a persistent retrying note until a poll succeeds', async () => {
		const s = server();
		const view = new CaseDetailState('case_9f3a1c');
		await view.refresh();
		render(ConnectionNote);
		s.failNext('GET', '/cases/case_9f3a1c');
		await view.refresh();
		await flush();
		expect(connection.stale).toBe(true);
		expect(screen.getByRole('status').textContent).toBe('Connection lost, retrying. Data on screen may be stale.');
		s.failNext('GET', '/cases/case_9f3a1c');
		await view.refresh();
		await flush();
		expect(screen.getByRole('status')).toBeInTheDocument();
		await view.refresh();
		await until(() => !connection.stale);
		expect(screen.queryByRole('status')).toBeNull();
		expect(view.detail?.caseId).toBe('case_9f3a1c');
	});
});
