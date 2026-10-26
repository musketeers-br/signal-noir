import { render, screen, within } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { fixture } from '../src/lib/api/fixtures';
import type { CaseDetail as Detail } from '../src/lib/api/types';
import CaseDetail from '../src/lib/components/CaseDetail.svelte';
import { CaseDetailState } from '../src/lib/stores/caseDetail.svelte';
import { violations } from './a11y';
import { server } from './helpers';

async function open(id: string) {
	const view = new CaseDetailState(id);
	await view.refresh();
	return { view, ...render(CaseDetail, { view }) };
}

// T015 - US2: read a Case in layers and follow the Evidence
describe('case detail', () => {
	it('shows one banner, six layers and the timeline for a case waiting for approval', async () => {
		server();
		const { container } = await open('case_9f3a1c');
		const banners = screen.getAllByTestId('state-banner');
		expect(banners).toHaveLength(1);
		expect(banners[0]).toHaveAttribute('role', 'status');
		expect(banners[0].textContent).toContain('Nothing is sent until you approve this exact version.');
		for (const title of ['1 · What failed', '2 · Evidence', '3 · Diagnosis', '4 · Proposal', '5 · Approval', '6 · Execution & receipt', 'Timeline']) {
			expect(screen.getByRole('heading', { name: title })).toBeInTheDocument();
		}
		expect(screen.getAllByText('SYNTHETIC').length).toBeGreaterThan(0);
		expect(await violations(container)).toEqual([]);
	});

	it('a claim reference moves focus to its evidence card', async () => {
		server();
		await open('case_9f3a1c');
		const chip = screen.getAllByRole('button', { name: 'Go to evidence evid_9f3a1c_08' })[0];
		await userEvent.click(chip);
		expect(document.activeElement).toBe(document.getElementById('ev-evid_9f3a1c_08'));
	});

	it('marks conflicting evidence side by side, and keeps obsoleted evidence', async () => {
		const s = server();
		const d = fixture<Detail>('case.pending-approval.p5-p8b.json');
		d.evidence[0].obsoletedBy = d.evidence[1].evidenceId;
		s.setDetail(d);
		await open('case_9f3a1c');
		const group = screen.getByRole('group', { name: 'Conflicting evidence' });
		expect(group.textContent).toContain('The HTTP 500 suggests a server fault, but partner health is UP.');
		expect(group.querySelector('#ev-evid_9f3a1c_04')).not.toBeNull();
		expect(group.querySelector('#ev-evid_9f3a1c_06')).not.toBeNull();
		expect(document.getElementById(`ev-${d.evidence[0].evidenceId}`)!.textContent).toContain('Obsoleted by');
	});

	it('shows only the current proposal and collapses earlier versions', async () => {
		server();
		await open('case_51b0e2');
		const toggle = screen.getByRole('button', { name: 'Earlier versions (1)' });
		expect(toggle).toHaveAttribute('aria-expanded', 'false');
		expect(document.querySelectorAll('[data-proposal-id]')).toHaveLength(1);
		expect(document.querySelector('[data-proposal-id]')!.getAttribute('data-proposal-id')).toBe('prop_51b0e2_v2');
		await userEvent.click(toggle);
		expect(screen.getByText('prop_51b0e2_v1')).toBeInTheDocument();
	});

	it('shows metrics and attempts, and honest empty states', async () => {
		server();
		await open('case_9f3a1c');
		const metrics = screen.getByLabelText('Investigation metrics');
		for (const label of ['Model', 'Provider', 'Duration', 'Tool calls', 'Attempts', 'Estimated cost']) expect(within(metrics).getByText(label)).toBeInTheDocument();
		expect(within(metrics).getByText('8.4 s')).toBeInTheDocument();
		expect(screen.getAllByText('Not yet. The case has not reached this step.').length).toBeGreaterThan(0);
	});

	it('says no interpretation exists when there is no diagnosis', async () => {
		server();
		await open('case_a37b5d');
		expect(screen.getAllByText('No interpretation exists. The agent has not produced one.').length).toBeGreaterThan(0);
	});

	it('unknown case: not found with a link back', async () => {
		server();
		await open('case_nope0000');
		expect(screen.getByRole('heading', { name: 'Case not found.' })).toBeInTheDocument();
		expect(screen.getByRole('link', { name: 'Back to cases' })).toHaveAttribute('href', '#/cases');
	});
});
