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

async function open(id: string, s = server()) {
	operator.set('Carla');
	const view = new CaseDetailState(id);
	await view.refresh();
	const r = render(CaseDetail, { view });
	await until(() => document.querySelectorAll('input[name="resolution"]').length > 0 || !view.detail?.dossier || view.detail.state !== 'ReviewRequired');
	return { s, view, ...r };
}

const firstSection = () => document.querySelector('.layers')!.firstElementChild!;

// T021 - US4: resolve a Review Dossier
describe('review dossier', () => {
	it('sits first while in review, with every section and an honest unknowns list', async () => {
		const { container } = await open('case_0b6f19');
		expect(firstSection().id).toBe('dossier');
		const d = screen.getByRole('region', { name: 'Review dossier' });
		expect(d.textContent).toContain('Two patient records match this order.');
		expect(d.textContent).toContain('Colliding records');
		expect(d.querySelectorAll('tr.divergent').length).toBeGreaterThan(0);
		expect(d.textContent).toContain('≠ diverges');
		expect(screen.getByTestId('unknowns').textContent).toContain('No evidence says which of the two records is the right patient.');
		expect(d.textContent).toContain('Suggested next step');
		expect(await violations(container)).toEqual([]);
	});

	it('an empty unknowns list says Nothing flagged', async () => {
		const s = server();
		const d = fixture<Detail>('case.review.after-denial.json');
		d.dossier!.unknowns = [];
		s.setDetail(d);
		await open('case_c4e1a9', s);
		expect(screen.getByTestId('unknowns').textContent).toBe('Nothing flagged.');
	});

	it('offers only catalog actions and reference mappings; no free payload field', async () => {
		await open('case_a37b5d');
		const labels = [...document.querySelectorAll('label.option')].map((l) => l.textContent!.trim());
		expect(labels.some((l) => l.startsWith('Apply map_glicj_plasma'))).toBe(true);
		expect(labels.some((l) => l.startsWith('Apply map_glicj_soro'))).toBe(true);
		expect(labels).toContain('Retry: resend unchanged');
		expect(labels).toContain('Hold: send nothing for now');
		expect(labels).toContain('Cancel the case: no effect is sent');
		const form = document.querySelector('form.resolution')!;
		expect(form.querySelectorAll('textarea').length).toBe(0);
		for (const input of form.querySelectorAll('input')) expect(input.getAttribute('name') === 'resolution' || input.getAttribute('data-testid') === 'resolution-note').toBe(true);
	});

	it('a 422 shows the validator reasons inline and keeps the form values', async () => {
		const { s } = await open('case_a37b5d');
		s.next('POST', '/resolution', 422, fixture('resolution.422.validator-blocked.json'));
		const option = [...document.querySelectorAll<HTMLInputElement>('input[name="resolution"]')].find((i) => i.value.startsWith('map:map_glicj_plasma'))!;
		await userEvent.click(option);
		await userEvent.type(screen.getByTestId('resolution-note'), 'confirmed by phone');
		await userEvent.click(screen.getByRole('button', { name: 'Submit resolution' }));
		await flush();
		const reasons = screen.getByTestId('validator-reasons');
		expect(reasons.textContent).toContain('The validator blocked this. Nothing was executed.');
		expect(reasons.textContent).toContain('MAPPING_CONDITION_MISMATCH');
		expect(option.checked).toBe(true);
		expect((screen.getByTestId('resolution-note') as HTMLInputElement).value).toBe('confirmed by phone');
		expect(s.calls.filter((c) => c.method === 'POST')[0].body).toEqual({ kind: 'action', operator: 'Carla', expectedCaseVersion: 3, action: 'APPLY_APPROVED_MAPPING', params: { mappingId: 'map_glicj_plasma', mappingVersion: '2026.10.1' }, note: 'confirmed by phone' });
	});

	it('cancel needs a reason; 201 resets and toasts', async () => {
		const { s } = await open('case_a37b5d');
		const cancel = [...document.querySelectorAll<HTMLInputElement>('input[name="resolution"]')].find((i) => i.value === 'CANCEL')!;
		await userEvent.click(cancel);
		await userEvent.click(screen.getByRole('button', { name: 'Submit resolution' }));
		expect(screen.getByRole('alert').textContent).toBe('Cancelling needs a reason.');
		expect(s.calls.filter((c) => c.method === 'POST')).toHaveLength(0);
		await userEvent.type(screen.getByTestId('cancel-reason'), 'duplicate confirmed with the unit');
		await userEvent.click(screen.getByRole('button', { name: 'Submit resolution' }));
		await until(() => toasts.items.length > 0);
		expect(toasts.items[0].text).toBe('Case cancelled. No effect was sent.');
		expect(s.calls.filter((c) => c.method === 'POST')[0].body).toEqual({ kind: 'cancel', operator: 'Carla', expectedCaseVersion: 3, reason: 'duplicate confirmed with the unit' });
	});

	it('once closed, the dossier is last and collapsed', async () => {
		const s = server();
		const d = fixture<Detail>('case.review.ambiguous-identity.json');
		d.state = 'Cancelled';
		s.setDetail(d);
		await open('case_0b6f19', s);
		const layers = document.querySelector('.layers')!;
		expect(layers.lastElementChild!.id).toBe('dossier');
		expect(screen.getByRole('button', { name: 'Show dossier' })).toHaveAttribute('aria-expanded', 'false');
		expect(document.querySelector('form.resolution')).toBeNull();
	});
});
