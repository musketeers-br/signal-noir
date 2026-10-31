import { describe, expect, it } from 'vitest';

// T031 - US5: the fallbacks ship. jsdom cannot run media queries, so this checks the CSS text;
// the behavior itself is checked in a real browser (quickstart steps 5 and 7).
const sheets = import.meta.glob('../src/styles/*.css', { query: '?raw', import: 'default', eager: true }) as Record<string, string>;
const css = Object.values(sheets).join('\n');
const block = (head: string) => {
	const i = css.indexOf(head);
	return i < 0 ? '' : css.slice(i, i + 900);
};

describe('visual fallbacks', () => {
	it('glass becomes opaque without blur and under reduced transparency', () => {
		expect(block('@supports not ((backdrop-filter')).toContain('--glass-solid');
		expect(block('@media (prefers-reduced-transparency: reduce)')).toContain('--glass-solid');
	});
	it('reduced motion removes animation, transition and smooth scroll', () => {
		const b = block('@media (prefers-reduced-motion: reduce)');
		for (const k of ['animation: none', 'transition: none', 'scroll-behavior: auto']) expect(b).toContain(k);
	});
	it('forced colors drops shadows and keeps borders and focus', () => {
		const b = block('@media (forced-colors: active)');
		expect(b).toContain('box-shadow: none');
		expect(b).toContain('border: 1px solid CanvasText');
		expect(b).toContain(':focus-visible');
	});
	it('more contrast strengthens lines', () => {
		expect(block('@media (prefers-contrast: more)')).toContain('--line-strong');
	});
	it('print has no glass and hides the floating chrome', () => {
		const b = css.slice(css.indexOf('@media print', css.indexOf('.topbar .rail-nav') - 40));
		expect(b).toContain('backdrop-filter: none');
		expect(b).toContain('.toasts');
	});
	it('an old browser without light-dark() still gets the light tokens', () => {
		expect(block('@supports not (color: light-dark')).toContain('--paper: #ece5d8');
	});
	it('uses the three layout bands of 005', () => {
		for (const q of ['(min-width: 1100px)', '(max-width: 1099px)', '(max-width: 639px)']) expect(css).toContain(q);
	});
});
