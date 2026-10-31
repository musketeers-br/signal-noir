import { describe, expect, it } from 'vitest';

// SC-006: colors, shadows, radii and font stacks are defined once, in tokens.css.
const all = import.meta.glob('../src/**/*.{css,svelte,html}', { query: '?raw', import: 'default', eager: true }) as Record<string, string>;
const files = Object.entries(all).filter(([f]) => !f.endsWith('styles/tokens.css'));

const RULES: [string, RegExp][] = [
	['hex color', /#[0-9a-fA-F]{3,8}\b(?![0-9a-fA-F-])/],
	['rgb/hsl color', /\b(?:rgba?|hsla?)\(/],
	['literal shadow', /box-shadow:\s*(?!var\(|none|inherit)\S[^;]*\d+px/],
	['literal radius', /border-radius:\s*[^;]*\d+px/],
	['literal font stack', /font-family:\s*(?!var\(|inherit)\S/]
];

describe('token audit', () => {
	it('scans the styles and components', () => {
		expect(files.length).toBeGreaterThan(20);
		// guard against vitest emptying the stylesheets, which would make the audit pass for nothing
		for (const [f, src] of files) if (f.endsWith('.css')) expect(src.length, f).toBeGreaterThan(0);
	});
	it('has no literal colors, shadows, radii or font stacks outside tokens.css', () => {
		const found: string[] = [];
		for (const [f, src] of files) {
			const lines = src.split('\n');
			lines.forEach((line, i) => {
				// `#/cases` hash links and anchors are not colors
				const text = line.replace(/href="#[^"]*"|'#\/[^']*'|"#\/[^"]*"|`#\/[^`]*`/g, '');
				for (const [name, re] of RULES) if (re.test(text)) found.push(`${f}:${i + 1} ${name}: ${line.trim()}`);
			});
		}
		expect(found).toEqual([]);
	});
});
