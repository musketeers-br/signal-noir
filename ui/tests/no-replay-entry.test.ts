import { describe, expect, it } from 'vitest';

// 010 T065 - FR-031: the console has no way to start a replay run. Replay exists only to reproduce the
// reference result for the quick validation and as the fallback of the demonstration video, so no
// screen creates a BenchmarkRun at all, and none offers 'replay' as a mode to choose.
const sources = import.meta.glob('../src/**/*.{ts,js,svelte}', { query: '?raw', import: 'default', eager: true }) as Record<string, string>;

describe('replay', () => {
	const files = Object.entries(sources);

	it('is not started from anywhere in the console', () => {
		expect(files.length).toBeGreaterThan(10);
		const offenders = files.filter(([, text]) => /benchmark-runs|createBenchmarkRun/.test(text)).map(([path]) => path);
		expect(offenders).toEqual([]);
	});

	it('is not offered as a choice', () => {
		const offenders = files
			.filter(([, text]) => /<option[^>]*value=["']replay["']/.test(text) || /<input[^>]*value=["']replay["']/.test(text) || /mode:\s*['"]replay['"]/.test(text))
			.map(([path]) => path);
		expect(offenders).toEqual([]);
	});

	it('is only ever read: the Case type may carry the mode, nothing sets it', () => {
		expect(sources['../src/lib/api/types.ts']).toMatch(/proposerMode\?: 'agent' \| 'rules' \| 'replay'/);
	});
});
