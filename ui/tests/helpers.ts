import { setTransport } from '../src/lib/api/client';
import { FixtureServer } from '../src/lib/api/fixtures';
import { connection } from '../src/lib/stores/connection.svelte';
import { toasts } from '../src/lib/stores/toasts.svelte';

export function server(): FixtureServer {
	const s = new FixtureServer();
	setTransport(s);
	connection.ok();
	toasts.clear();
	return s;
}

export const flush = () => new Promise((r) => setTimeout(r, 0));

export async function until(check: () => boolean, ms = 2000): Promise<void> {
	const start = Date.now();
	while (!check()) {
		if (Date.now() - start > ms) throw new Error('condition not met in time');
		await new Promise((r) => setTimeout(r, 10));
	}
}
