import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it } from 'vitest';
import initScript from '../static/theme-init.js?raw';
import ThemeToggle from '../src/lib/components/ThemeToggle.svelte';
import { COPY } from '../src/lib/copy';
import { THEME_KEY, ThemeState, theme } from '../src/lib/stores/theme.svelte';

// T008 - US2: light and dark, chosen by the Operator
type Listener = (e: { matches: boolean }) => void;

function stubSystem(dark: boolean) {
	const listeners = new Set<Listener>();
	let matches = dark;
	window.matchMedia = ((q: string) => ({
		get matches() { return matches; },
		media: q,
		addEventListener: (_: string, l: Listener) => listeners.add(l),
		removeEventListener: (_: string, l: Listener) => listeners.delete(l),
		addListener() {}, removeListener() {}, onchange: null, dispatchEvent: () => false
	})) as unknown as typeof window.matchMedia;
	return (next: boolean) => {
		matches = next;
		listeners.forEach((l) => l({ matches: next }));
	};
}

afterEach(() => {
	delete document.documentElement.dataset.theme;
	theme.choice = null;
});

describe('theme store', () => {
	it('follows the system when nothing is stored and leaves data-theme unset', () => {
		stubSystem(true);
		const t = new ThemeState();
		t.listen();
		expect(t.choice).toBeNull();
		expect(t.effective).toBe('dark');
		expect(document.documentElement.dataset.theme).toBeUndefined();
		t.listen()();
	});

	it('toggle picks the opposite of what is shown, remembers it and sets data-theme', () => {
		stubSystem(false);
		const t = new ThemeState();
		t.toggle();
		expect(t.effective).toBe('dark');
		expect(localStorage.getItem(THEME_KEY)).toBe('dark');
		expect(document.documentElement.dataset.theme).toBe('dark');
		t.toggle();
		expect(t.effective).toBe('light');
		expect(localStorage.getItem(THEME_KEY)).toBe('light');
	});

	it('a stored choice wins over the system, and an unknown stored value is ignored', () => {
		stubSystem(true);
		localStorage.setItem(THEME_KEY, 'light');
		expect(new ThemeState().effective).toBe('light');
		localStorage.setItem(THEME_KEY, 'banana');
		const t = new ThemeState();
		expect(t.choice).toBeNull();
		expect(t.effective).toBe('dark');
	});

	it('keeps working for the session when storage throws', () => {
		stubSystem(false);
		const get = Storage.prototype.getItem;
		const set = Storage.prototype.setItem;
		Storage.prototype.getItem = () => { throw new Error('blocked'); };
		Storage.prototype.setItem = () => { throw new Error('blocked'); };
		try {
			const t = new ThemeState();
			expect(t.choice).toBeNull();
			t.toggle();
			expect(t.effective).toBe('dark');
			expect(document.documentElement.dataset.theme).toBe('dark');
		} finally {
			Storage.prototype.getItem = get;
			Storage.prototype.setItem = set;
		}
	});

	it('follows a live system change only while there is no choice', () => {
		const change = stubSystem(false);
		const t = new ThemeState();
		t.listen();
		change(true);
		expect(t.effective).toBe('dark');
		t.toggle();
		expect(t.effective).toBe('light');
		change(false);
		change(true);
		expect(t.effective).toBe('light');
		t.listen()();
	});
});

describe('theme toggle', () => {
	it('names the theme it switches to and is operable by keyboard', async () => {
		stubSystem(false);
		theme.system = 'light';
		render(ThemeToggle);
		const btn = screen.getByRole('button', { name: COPY.themeToDark });
		btn.focus();
		await userEvent.keyboard('{Enter}');
		expect(screen.getByRole('button', { name: COPY.themeToLight })).toBe(btn);
		expect(btn).toHaveFocus();
		await userEvent.keyboard(' ');
		expect(screen.getByRole('button', { name: COPY.themeToDark })).toBe(btn);
	});
});

describe('theme-init.js (before first paint)', () => {
	const run = () => new Function(initScript)();
	it('applies only light or dark', () => {
		localStorage.setItem(THEME_KEY, 'dark');
		run();
		expect(document.documentElement.getAttribute('data-theme')).toBe('dark');
		document.documentElement.removeAttribute('data-theme');
		localStorage.setItem(THEME_KEY, 'light');
		run();
		expect(document.documentElement.getAttribute('data-theme')).toBe('light');
	});
	it('leaves the attribute unset for nothing, junk, or blocked storage', () => {
		run();
		expect(document.documentElement.hasAttribute('data-theme')).toBe(false);
		localStorage.setItem(THEME_KEY, 'banana');
		run();
		expect(document.documentElement.hasAttribute('data-theme')).toBe(false);
		const get = Storage.prototype.getItem;
		Storage.prototype.getItem = () => { throw new Error('blocked'); };
		try { run(); } finally { Storage.prototype.getItem = get; }
		expect(document.documentElement.hasAttribute('data-theme')).toBe(false);
	});
});
