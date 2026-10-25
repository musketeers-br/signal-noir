import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import Shell from '../src/lib/components/Shell.svelte';
import { toasts } from '../src/lib/stores/toasts.svelte';
import { flush, server, until } from './helpers';

// T020 - US3 / SC-001: the approval journey with the keyboard only
describe('keyboard journey', () => {
	it('name → needs-you row → case → Review & approve → approve → back to the list', async () => {
		const s = server();
		location.hash = '#/cases';
		render(Shell, { pollMs: 3_600_000 });
		await until(() => document.querySelector('[data-case-id="case_9f3a1c"]') !== null);
		const user = userEvent.setup();

		// from the top of the page: wordmark, Cases, then the declared-name field
		(document.activeElement as HTMLElement | null)?.blur();
		await user.tab();
		await user.tab();
		await user.tab();
		expect(document.activeElement).toBe(screen.getByLabelText('Acting as (declared name)'));
		await user.keyboard('Carla');

		const row = document.querySelector('[data-case-id="case_9f3a1c"]') as HTMLAnchorElement;
		row.focus();
		await user.keyboard('{Enter}');
		location.hash = '#/cases/case_9f3a1c'; // jsdom does not follow hash links on Enter
		await until(() => screen.queryByTestId('state-banner') !== null);
		expect(document.activeElement).toBe(document.querySelector('main'));

		await until(() => screen.queryAllByRole('button', { name: 'Review & approve…' }).length > 0);
		const approveTrigger = screen.getAllByRole('button', { name: 'Review & approve…' })[0];
		approveTrigger.focus();
		await user.keyboard('{Enter}');
		await until(() => document.querySelector('dialog') !== null);
		expect(document.activeElement).toBe(screen.getByLabelText('Your name (declared, not authenticated)'));

		await user.tab();
		expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Approve this version' }));
		await user.keyboard('{Enter}');
		await until(() => document.querySelector('dialog') === null);
		expect(toasts.items[0].text).toContain('Approved.');
		expect(document.activeElement).toBe(approveTrigger);
		expect(s.calls.find((c) => c.method === 'POST')!.body).toMatchObject({ operator: 'Carla', expectedCaseVersion: 4 });

		const back = screen.getAllByRole('link', { name: /Back to cases/ })[0];
		back.focus();
		location.hash = '#/cases';
		await until(() => screen.queryByRole('heading', { name: 'Cases' }) !== null);
		await flush();
	});
});
