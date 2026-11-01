import { render } from '@testing-library/svelte';
import { describe, expect, it } from 'vitest';
import CaseDetail from '../src/lib/components/CaseDetail.svelte';
import { CaseDetailState } from '../src/lib/stores/caseDetail.svelte';
import { server, until } from './helpers';

// 014 T030/T035/T038: findings of the real-browser pass (axe with contrast, 320 px reflow, print),
// pinned here so they do not come back. jsdom has no layout, so the CSS is checked as text.
const sheets = import.meta.glob('../src/styles/*.css', { query: '?raw', import: 'default', eager: true }) as Record<string, string>;
const css = Object.values(sheets).join('\n');
const rule = (selector: string) => {
	const i = css.indexOf(`${selector} {`);
	return i < 0 ? '' : css.slice(i, css.indexOf('}', i) + 1);
};

describe('real-browser findings', () => {
	it('grid columns can shrink below their content, so long identifiers wrap at 320 px', () => {
		expect(rule('.side-by-side')).toContain('minmax(0, 1fr)');
		expect(rule('.kv')).toContain('minmax(0, 1fr)');
		expect(css).toContain('.side-by-side, .kv { grid-template-columns: minmax(0, 1fr); }');
		expect(rule('.mono')).toContain('overflow-wrap: anywhere');
	});

	it('obsoleted Evidence keeps full contrast (no opacity); the dashed border and tag carry the meaning', () => {
		expect(rule('.evidence-card.obsolete')).not.toContain('opacity');
		expect(rule('.evidence-card.obsolete')).toContain('dashed');
	});

	it('print drops every shadow, buttons included', () => {
		const b = css.slice(css.indexOf('@media print'));
		expect(b).toContain('box-shadow: none !important');
	});

	it('a table that scrolls inside its box can be reached with the keyboard', async () => {
		server();
		const view = new CaseDetailState('case_7d22e0');
		await view.refresh();
		render(CaseDetail, { view });
		await until(() => document.querySelector('table.table') !== null);
		for (const t of document.querySelectorAll('table.table')) expect(t.getAttribute('tabindex')).toBe('0');
	});

	it('"Back to cases" on Case not found is a 44 px target like the header link', async () => {
		server();
		const view = new CaseDetailState('case_doesnotexist');
		await view.refresh();
		render(CaseDetail, { view });
		await until(() => document.querySelector('#nf-title') !== null);
		expect(document.querySelector('#nf-title + a')!.classList.contains('back-link')).toBe(true);
		expect(rule('.back-link')).toContain('min-height: var(--target)');
	});
});
