import { render, screen } from '@testing-library/svelte';
import { describe, expect, it } from 'vitest';
import { fixture } from '../src/lib/api/fixtures';
import type { CaseDetail } from '../src/lib/api/types';
import StateBanner from '../src/lib/components/StateBanner.svelte';
import StateChip from '../src/lib/components/StateChip.svelte';
import { ALL_STATES, stateCopy } from '../src/lib/copy';

// T023 - US5: distinct, honest copy per state
describe('state banner and chip', () => {
	it('renders each state with its copy, glyph + label, and at most one primary action', () => {
		const base = fixture<CaseDetail>('case.pending-approval.p5-p8b.json');
		for (const state of ALL_STATES) {
			const { unmount } = render(StateBanner, { detail: { ...base, state, executions: [] }, onApprove: () => {}, onDossier: () => {} });
			const banner = screen.getByTestId('state-banner');
			expect(banner.textContent).toContain(stateCopy(state).banner);
			expect(banner.querySelectorAll('button').length).toBeLessThanOrEqual(1);
			unmount();
		}
	});

	it('offers no approval without a current proposal to approve', () => {
		const d = fixture<CaseDetail>('case.pending-approval.p5-p8b.json');
		render(StateBanner, { detail: { ...d, currentProposalId: null }, onApprove: () => {} });
		expect(screen.getByTestId('state-banner').querySelector('button')).toBeNull();
	});

	it('Executing with an unknown outcome has its own banner and chip', () => {
		const d = fixture<CaseDetail>('case.executing.outcome-unknown.json');
		render(StateBanner, { detail: d });
		expect(screen.getByTestId('state-banner').textContent).toContain('The partner may already have this order. New sends are blocked');
		render(StateChip, { state: 'Executing', outcome: 'reconciling' });
		expect(screen.getByText('Outcome unknown')).toBeInTheDocument();
	});
});
