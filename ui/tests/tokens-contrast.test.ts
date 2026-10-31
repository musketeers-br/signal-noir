import css from '../src/styles/tokens.css?raw';
import { describe, expect, it } from 'vitest';

// jsdom cannot compute contrast, so the token pairs of contracts/design-tokens.md are proved here.
const root = css.slice(0, css.indexOf('@supports'));

type Rgb = [number, number, number];
const tokens: Record<string, { light: Rgb; dark: Rgb }> = {};

function hex(s: string): Rgb {
	const h = s.trim().replace('#', '');
	return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16)) as Rgb;
}
for (const m of root.matchAll(/--([a-z-]+):\s*light-dark\(\s*(#[0-9a-f]{6}),\s*(#[0-9a-f]{6})\s*\);/g)) {
	tokens[m[1]] = { light: hex(m[2]), dark: hex(m[3]) };
}

function lum([r, g, b]: Rgb): number {
	const f = (v: number) => {
		const c = v / 255;
		return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
	};
	return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
}
function ratio(a: Rgb, b: Rgb): number {
	const [hi, lo] = [lum(a), lum(b)].sort((x, y) => y - x);
	return (hi + 0.05) / (lo + 0.05);
}

const SURFACES = ['paper', 'surface', 'surface-raised', 'surface-inset', 'glass-solid'];
const ROLES = ['accent', 'fact', 'interpretation', 'attention', 'hold', 'success', 'danger'];
const pairs: [string, string, number][] = [];
for (const s of SURFACES) pairs.push(['ink', s, 4.5], ['ink-muted', s, 4.5]);
for (const r of ROLES) pairs.push([r, `${r}-soft`, 4.5], [r, 'surface', 4.5]);
pairs.push(['accent-ink', 'accent', 4.5], ['danger-ink', 'danger', 4.5]);
for (const s of ['surface', 'paper']) pairs.push(['line-strong', s, 3], ['focus', s, 3]);

describe('design token contrast (feature 014, FR-016)', () => {
	it('parses the themed tokens', () => {
		expect(Object.keys(tokens).length).toBeGreaterThan(20);
	});
	for (const theme of ['light', 'dark'] as const) {
		for (const [fg, bg, min] of pairs) {
			it(`${theme}: --${fg} on --${bg} >= ${min}`, () => {
				expect(tokens[fg], `--${fg} is a themed token`).toBeDefined();
				expect(tokens[bg], `--${bg} is a themed token`).toBeDefined();
				const r = ratio(tokens[fg][theme], tokens[bg][theme]);
				expect(r, `${theme} --${fg} on --${bg}: ${r.toFixed(2)}`).toBeGreaterThanOrEqual(min);
			});
		}
	}
});
