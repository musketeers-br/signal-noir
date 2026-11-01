import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

// 010 T065 - FR-031: the console has no way to start a replay run. Replay exists only to reproduce the
// reference result for the quick validation and as the fallback of the demonstration video, so no
// screen creates a BenchmarkRun at all, and none offers 'replay' as a mode to choose.
const SRC = join(__dirname, '..', 'src');

function sources(dir: string): string[] {
	return readdirSync(dir).flatMap((name) => {
		const path = join(dir, name);
		if (statSync(path).isDirectory()) return sources(path);
		return /\.(ts|js|svelte)$/.test(name) ? [path] : [];
	});
}

describe('replay', () => {
	const files = sources(SRC);

	it('is not started from anywhere in the console', () => {
		expect(files.length).toBeGreaterThan(10);
		const offenders = files.filter((f) => /benchmark-runs|createBenchmarkRun/.test(readFileSync(f, 'utf8')));
		expect(offenders).toEqual([]);
	});

	it('is not offered as a choice', () => {
		const offenders = files.filter((f) => {
			const text = readFileSync(f, 'utf8');
			return /<option[^>]*value=["']replay["']/.test(text) || /<input[^>]*value=["']replay["']/.test(text) || /mode:\s*['"]replay['"]/.test(text);
		});
		expect(offenders).toEqual([]);
	});

	it('is only ever read: the Case type may carry the mode, nothing sets it', () => {
		const types = readFileSync(join(SRC, 'lib', 'api', 'types.ts'), 'utf8');
		expect(types).toMatch(/proposerMode\?: 'agent' \| 'rules' \| 'replay'/);
	});
});
