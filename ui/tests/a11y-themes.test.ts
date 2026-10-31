import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it } from 'vitest';
import CaseDetail from '../src/lib/components/CaseDetail.svelte';
import CaseList from '../src/lib/components/CaseList.svelte';
import Shell from '../src/lib/components/Shell.svelte';
import StateChip from '../src/lib/components/StateChip.svelte';
import { ALL_STATES, stateCopy } from '../src/lib/copy';
import { CaseDetailState } from '../src/lib/stores/caseDetail.svelte';
import { CaseListState } from '../src/lib/stores/cases.svelte';
import { operator } from '../src/lib/stores/operator.svelte';
import { violations } from './a11y';
import { flush, server, until } from './helpers';

// T013/T014 - US3: meaning survives the makeover, in both themes
afterEach(() => delete document.documentElement.dataset.theme);

for (const mode of ['light', 'dark'] as const) {
	describe(`accessibility in the ${mode} theme`, () => {
		const setTheme = () => { document.documentElement.dataset.theme = mode; };

		it('list rows carry SYNTHETIC and the page is clean', async () => {
			setTheme();
			server();
			const list = new CaseListState();
			await list.load();
			const { container } = render(CaseList, { list });
			for (const row of screen.getAllByRole('listitem')) expect(row.textContent).toContain('SYNTHETIC');
			expect(await violations(container)).toEqual([]);
		});

		it('a Case detail is clean', async () => {
			setTheme();
			server();
			const view = new CaseDetailState('case_9f3a1c');
			await view.refresh();
			const { container } = render(CaseDetail, { view });
			expect(container.textContent).toContain('SYNTHETIC');
			expect(await violations(container)).toEqual([]);
		});

		it('the approval dialog is clean', async () => {
			setTheme();
			server();
			operator.set('Carla');
			const view = new CaseDetailState('case_9f3a1c');
			await view.refresh();
			const { container } = render(CaseDetail, { view });
			await userEvent.click(screen.getByTestId('state-banner').querySelector('button')!);
			await flush();
			expect(await violations(container)).toEqual([]);
		});

		it('a Review Dossier is clean', async () => {
			setTheme();
			server();
			operator.set('Carla');
			const view = new CaseDetailState('case_0b6f19');
			await view.refresh();
			const { container } = render(CaseDetail, { view });
			await until(() => document.querySelectorAll('input[name="resolution"]').length > 0);
			expect(await violations(container)).toEqual([]);
		});

		it('the shell (top bar or rail, theme switch, name field) is clean', async () => {
			setTheme();
			server();
			const { container } = render(Shell, { pollMs: 3_600_000 });
			await flush();
			expect(await violations(container)).toEqual([]);
		});
	});
}

describe('meaning without color or depth', () => {
	it('every state and Outcome unknown has a glyph and a label', () => {
		for (const s of ALL_STATES) {
			const c = stateCopy(s);
			expect(c.glyph.trim()).not.toBe('');
			expect(c.label.trim()).not.toBe('');
		}
		const unknown = stateCopy('Executing', 'reconciling');
		expect(unknown.label).toBe('Outcome unknown');
		expect(unknown.glyph).not.toBe(stateCopy('Resolved').glyph);
	});

	it('the chip prints the glyph and the label as text', () => {
		render(StateChip, { state: 'PendingApproval' });
		const chip = document.querySelector('.chip')!;
		const c = stateCopy('PendingApproval');
		expect(chip.textContent).toContain(c.glyph);
		expect(chip.textContent).toContain(c.label);
	});

	it('waiting, review and uncertain outcome stay distinct', () => {
		const labels = [stateCopy('PendingApproval').label, stateCopy('ReviewRequired').label, stateCopy('Executing', 'reconciling').label];
		expect(new Set(labels).size).toBe(3);
	});
});
