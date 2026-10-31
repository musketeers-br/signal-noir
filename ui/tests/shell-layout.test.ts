import { render, screen, within } from '@testing-library/svelte';
import { describe, expect, it } from 'vitest';
import Shell from '../src/lib/components/Shell.svelte';
import { flush, server } from './helpers';

// T025 - US4: structure of the shell (jsdom has no layout; widths are checked in the quickstart)
describe('shell', () => {
	it('lists Cases only in the main navigation and links to no screen that does not exist', async () => {
		server();
		render(Shell, { pollMs: 3_600_000 });
		await flush();
		const nav = screen.getByRole('navigation', { name: 'Main' });
		const links = within(nav).getAllByRole('link');
		expect(links.map((l) => l.textContent)).toEqual(['Cases']);
		for (const word of ['Orders', 'Partners', 'Outbox', 'Benchmark']) expect(screen.queryByText(word)).toBeNull();
	});

	it('keeps the theme switch, the declared-name field and the SYNTHETIC badge in the shell', async () => {
		server();
		render(Shell, { pollMs: 3_600_000 });
		await flush();
		expect(screen.getByRole('button', { name: /Switch to (dark|light) theme/ })).toBeInTheDocument();
		expect(screen.getByLabelText(/Acting as/)).toBeInTheDocument();
		expect(screen.getAllByText('SYNTHETIC DATA').length).toBeGreaterThan(0);
	});

	it('moves focus to the main region on load', async () => {
		server();
		render(Shell, { pollMs: 3_600_000 });
		await flush();
		await flush();
		expect(screen.getByRole('main')).toHaveFocus();
	});
});
