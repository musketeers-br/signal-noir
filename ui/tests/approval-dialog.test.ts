import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { fixture } from '../src/lib/api/fixtures';
import type { CaseDetail as Detail } from '../src/lib/api/types';
import CaseDetail from '../src/lib/components/CaseDetail.svelte';
import { CaseDetailState } from '../src/lib/stores/caseDetail.svelte';
import { operator } from '../src/lib/stores/operator.svelte';
import { toasts } from '../src/lib/stores/toasts.svelte';
import { violations } from './a11y';
import { flush, server, until } from './helpers';

async function openDialog(caseId = 'case_9f3a1c') {
	const s = server();
	operator.set('Carla');
	const view = new CaseDetailState(caseId);
	await view.refresh();
	const r = render(CaseDetail, { view });
	const trigger = screen.getByTestId('state-banner').querySelector('button')!;
	await userEvent.click(trigger);
	await flush();
	return { s, view, trigger, ...r };
}

const decisionCalls = (s: ReturnType<typeof server>) => s.calls.filter((c) => c.method === 'POST');

// T018 - US3: approve or deny one exact version
describe('approval dialog', () => {
	it('sends the proposalId and caseVersion frozen at open, even after a poll changed the case', async () => {
		const { s, view } = await openDialog();
		const changed = fixture<Detail>('case.pending-approval.p5-p8b.json');
		changed.caseVersion = 9;
		changed.currentProposalId = 'prop_9f3a1c_v2';
		s.setDetail(changed);
		await view.refresh();
		await flush();
		await userEvent.click(screen.getByRole('button', { name: 'Approve this version' }));
		await flush();
		const call = decisionCalls(s)[0];
		expect(call.path).toBe('/cases/case_9f3a1c/proposals/prop_9f3a1c_v1/decision');
		expect(call.body).toEqual({ decision: 'approved', operator: 'Carla', expectedCaseVersion: 4 });
	});

	it('201 closes the dialog, toasts what happens next and returns focus', async () => {
		const { trigger } = await openDialog();
		await userEvent.click(screen.getByRole('button', { name: 'Approve this version' }));
		await until(() => !document.querySelector('dialog'));
		expect(toasts.items[0].text).toBe('Approved. Preconditions are re-checked before anything is sent.');
		expect(toasts.items[0].tone).toBe('success');
		expect(document.activeElement).toBe(trigger);
	});

	it('200 replay says already approved, no new effect, not styled as success', async () => {
		const { s } = await openDialog();
		s.next('POST', '/decision', 200, fixture('decision.200.idempotent-replay.json'));
		await userEvent.click(screen.getByRole('button', { name: 'Approve this version' }));
		await until(() => toasts.items.length > 0);
		expect(toasts.items[0].text).toMatch(/^Already approved by .+\. No new effect\.$/);
		expect(toasts.items[0].tone).toBe('muted');
	});

	it('409 stale keeps the dialog open, records nothing, hides Approve/Deny and offers the new version', async () => {
		const { s } = await openDialog();
		s.next('POST', '/decision', 409, fixture('decision.409.stale-version.json'));
		await userEvent.click(screen.getByRole('button', { name: 'Approve this version' }));
		await flush();
		expect(document.querySelector('dialog')).not.toBeNull();
		expect(screen.getByRole('alert').textContent).toContain('Nothing was recorded.');
		expect(screen.queryByRole('button', { name: 'Approve this version' })).toBeNull();
		expect(screen.queryByRole('button', { name: 'Deny…' })).toBeNull();
		const changed = fixture<Detail>('case.pending-approval.p5-p8b.json');
		changed.caseVersion = 9;
		s.setDetail(changed);
		await userEvent.click(screen.getByRole('button', { name: 'Review the new version' }));
		await flush();
		await userEvent.click(screen.getByRole('button', { name: 'Approve this version' }));
		await flush();
		expect((decisionCalls(s).at(-1)!.body as { expectedCaseVersion: number }).expectedCaseVersion).toBe(9);
	});

	it('409 invalid transition keeps the dialog open with the new state', async () => {
		const { s } = await openDialog();
		s.next('POST', '/decision', 409, fixture('decision.409.invalid-transition.json'));
		await userEvent.click(screen.getByRole('button', { name: 'Approve this version' }));
		await flush();
		expect(screen.getByRole('alert').textContent).toBe('This case is now ReviewRequired. Nothing was recorded.');
		expect(screen.getByRole('button', { name: 'Close and see the case' })).toBeInTheDocument();
	});

	it('network error assumes nothing and keeps Approve disabled until the next poll', async () => {
		const { s, view } = await openDialog();
		s.failNext('POST', '/decision');
		await userEvent.click(screen.getByRole('button', { name: 'Approve this version' }));
		await flush();
		expect(screen.getByRole('alert').textContent).toContain('may not have reached the server');
		expect(screen.getByRole('button', { name: 'Approve this version' })).toBeDisabled();
		expect(toasts.items).toHaveLength(0);
		await view.refresh();
		await flush();
		expect(screen.getByRole('button', { name: 'Approve this version' })).toBeEnabled();
	});

	it('Approve is disabled while the request is in flight', async () => {
		const { s } = await openDialog();
		let release!: () => void;
		const original = s.request.bind(s);
		s.request = (m, p, b) => (m === 'POST' ? new Promise((r) => (release = () => r(original(m, p, b)))) : original(m, p, b));
		await userEvent.click(screen.getByRole('button', { name: 'Approve this version' }));
		expect(screen.getByRole('button', { name: 'Approve this version' })).toBeDisabled();
		release();
		await until(() => !document.querySelector('dialog'));
	});

	it('Deny is separate and needs a reason, which is sent', async () => {
		const { s } = await openDialog();
		await userEvent.click(screen.getByRole('button', { name: 'Deny…' }));
		await userEvent.click(screen.getByRole('button', { name: 'Confirm denial' }));
		expect(screen.getByRole('alert').textContent).toContain('A denial needs a reason');
		expect(decisionCalls(s)).toHaveLength(0);
		await userEvent.type(screen.getByTestId('deny-reason'), 'The order is plasma, not serum.');
		await userEvent.click(screen.getByRole('button', { name: 'Confirm denial' }));
		await flush();
		expect(decisionCalls(s)[0].body).toEqual({ decision: 'denied', operator: 'Carla', expectedCaseVersion: 4, reason: 'The order is plasma, not serum.' });
	});

	it('names the effect and passes the accessibility checks; Esc closes', async () => {
		const { container } = await openDialog();
		await until(() => (screen.getByTestId('effect').textContent ?? '').includes('→'));
		expect(screen.getByTestId('effect').textContent).toContain('Change exam code GLIC-J → GLIC-S');
		expect(await violations(container.ownerDocument.body)).toEqual([]);
		await userEvent.keyboard('{Escape}');
		await until(() => !document.querySelector('dialog'));
	});
});
