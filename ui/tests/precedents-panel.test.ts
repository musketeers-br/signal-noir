import { render, screen } from '@testing-library/svelte';
import { afterEach, describe, expect, it } from 'vitest';
import { fixture } from '../src/lib/api/fixtures';
import type { PrecedentSearch } from '../src/lib/api/types';
import CaseDetail from '../src/lib/components/CaseDetail.svelte';
import { CaseDetailState } from '../src/lib/stores/caseDetail.svelte';
import { operator } from '../src/lib/stores/operator.svelte';
import { violations } from './a11y';
import { server, until } from './helpers';

// 015 T016/T018 - Similar resolved Cases: honest statuses, never a decision
afterEach(() => delete document.documentElement.dataset.theme);

async function open(id: string, s = server()) {
	operator.set('Carla');
	const view = new CaseDetailState(id);
	await view.refresh();
	const r = render(CaseDetail, { view });
	await until(() => screen.queryByTestId('precedents-status')?.dataset.status !== 'loading');
	return { s, view, ...r };
}

const status = () => screen.getByTestId('precedents-status');
const precedentCalls = (s: ReturnType<typeof server>) => s.calls.filter((c) => c.path.includes('/precedents')).length;

describe('similar resolved cases', () => {
	it('lists precedents with their action, outcome, similarity and a link, labelled lexical and not Evidence', async () => {
		const { container } = await open('case_9f3a1c');
		const panel = screen.getByTestId('precedents');
		expect(panel.textContent).toContain('Similar resolved Cases');
		expect(panel.textContent).toContain('Not Evidence about this Case');
		expect(screen.getByTestId('precedents-mode').textContent).toBe('Lexical similarity (no embedding provider)');
		expect(status().textContent).toBe('3 similar resolved Cases found.');
		const items = panel.querySelectorAll('li.precedent');
		expect(items.length).toBe(3);
		expect(items[0].querySelector('a')!.getAttribute('href')).toBe('#/cases/case_000118');
		expect(items[0].textContent).toContain('APPLY_APPROVED_MAPPING');
		expect(items[0].textContent).toContain('90%');
		expect(items[1].textContent).toContain('No action');
		for (const item of items) expect(item.textContent).toContain('SYNTHETIC');
		// a Failed or Cancelled precedent is shown with its outcome, never as a success
		expect(panel.querySelector('li[data-final="Failed"] .chip')!.className).toContain('tone-danger');
		expect(panel.querySelector('li[data-final="Cancelled"] .chip')!.className).toContain('tone-muted');
		expect(await violations(container)).toEqual([]);
	});

	const cases: [string, string][] = [
		['precedents.200.no-precedents.json', 'No precedents yet.'],
		['precedents.200.nothing-similar.json', 'Nothing similar enough'],
		['precedents.200.rebuilding.json', 'being rebuilt'],
		['precedents.200.needs-rebuild.json', 'needs a rebuild'],
		['precedents.200.unavailable.json', 'Search unavailable. The embedding provider did not answer.']
	];
	for (const [file, text] of cases) {
		it(`says so plainly: ${file}`, async () => {
			const s = server();
			s.precedents = file;
			await open('case_9f3a1c', s);
			expect(status().textContent).toContain(text);
			expect(document.querySelectorAll('li.precedent').length).toBe(0);
		});
	}

	it('distinct sentences for each status', () => {
		const texts = new Set(cases.map(([file]) => fixture<PrecedentSearch>(file).status));
		expect(texts.size).toBe(cases.length);
	});

	it('a provider mode names its model', async () => {
		const s = server();
		const body = fixture<PrecedentSearch>('precedents.200.results.json');
		body.mode = 'provider';
		body.model = 'text-embedding-3-small';
		s.next('GET', '/precedents', 200, body);
		await open('case_9f3a1c', s);
		expect(screen.getByTestId('precedents-mode').textContent).toBe('Semantic similarity (text-embedding-3-small)');
	});

	it('a failed request says so and the case still opens', async () => {
		const t = server();
		t.failNext('GET', '/precedents');
		await open('case_7d22e0', t);
		expect(status().textContent).toContain('Search unavailable: the server did not answer');
		expect(document.querySelector('.case-detail')).not.toBeNull();
	});

	it('is fetched once per case; polls do not refetch or reset it', async () => {
		const { s, view } = await open('case_9f3a1c');
		expect(precedentCalls(s)).toBe(1);
		await view.refresh();
		await view.refresh();
		expect(precedentCalls(s)).toBe(1);
		expect(document.querySelectorAll('li.precedent').length).toBe(3);
	});

	it('sits in the dossier next to the next step while in review, and pre-selects nothing', async () => {
		await open('case_a37b5d');
		const dossier = document.getElementById('dossier')!;
		const panel = dossier.querySelector('[data-testid="precedents"]')!;
		expect(panel).not.toBeNull();
		expect(panel.previousElementSibling!.className).toContain('next-step');
		expect(document.querySelectorAll('[data-testid="precedents"]').length).toBe(1);
		const form = document.querySelector('form.resolution')!;
		for (const input of form.querySelectorAll('input[type="radio"]')) expect((input as HTMLInputElement).checked).toBe(false);
	});

	for (const mode of ['light', 'dark'] as const) {
		it(`is clean in the ${mode} theme`, async () => {
			document.documentElement.dataset.theme = mode;
			const { container } = await open('case_a37b5d');
			expect(await violations(container)).toEqual([]);
		});
	}
});
