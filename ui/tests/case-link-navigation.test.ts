import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import Shell from '../src/lib/components/Shell.svelte';
import { flush, server, until } from './helpers';

// Clicking a case in the list opens it. In the built console SvelteKit's router took over hash
// links with history.pushState, which fires no hashchange, so the URL changed and the list stayed.
// The Shell now owns in-app links (#/...), so these tests click instead of setting location.hash.
async function list() {
	server();
	location.hash = '#/cases';
	render(Shell, { pollMs: 3_600_000 });
	await until(() => document.querySelector('[data-case-id="case_9f3a1c"]') !== null);
}

/** Dispatches a click like a browser would and reports whether the Shell took it over. */
function click(el: Element, init: MouseEventInit = {}): boolean {
	const e = new MouseEvent('click', { bubbles: true, cancelable: true, button: 0, ...init });
	el.dispatchEvent(e);
	return e.defaultPrevented;
}

describe('in-app links', () => {
	it('a click on a case row opens the case, and Back to cases returns to the list', async () => {
		await list();
		const user = userEvent.setup();
		await user.click(document.querySelector('[data-case-id="case_9f3a1c"]')!);
		await until(() => screen.queryByTestId('state-banner') !== null);
		expect(location.hash).toBe('#/cases/case_9f3a1c');

		await user.click(screen.getAllByRole('link', { name: /Back to cases/ })[0]);
		await until(() => screen.queryByRole('heading', { name: 'Cases' }) !== null);
		expect(location.hash).toBe('#/cases');
		await flush();
	});

	it('the Shell handles the click before any other router can push the URL', async () => {
		await list();
		expect(click(document.querySelector('[data-case-id="case_9f3a1c"]')!)).toBe(true);
		await until(() => screen.queryByTestId('state-banner') !== null);
	});

	it('leaves modified clicks to the browser (new tab, new window)', async () => {
		await list();
		const row = document.querySelector('[data-case-id="case_9f3a1c"]')!;
		for (const mod of [{ metaKey: true }, { ctrlKey: true }, { shiftKey: true }, { button: 1 }]) {
			expect(click(row, mod)).toBe(false);
		}
		await flush();
	});
});
