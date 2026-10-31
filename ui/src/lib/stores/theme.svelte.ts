// The console theme: the system preference unless the Operator chose one with the switch.
// The choice ('light' | 'dark') is kept in the browser; anything else stored is ignored.
// static/theme-init.js applies the same rule before first paint.
export type Theme = 'light' | 'dark';
export const THEME_KEY = 'signalnoir.theme';
const QUERY = '(prefers-color-scheme: dark)';

function load(): Theme | null {
	try {
		const v = localStorage.getItem(THEME_KEY);
		return v === 'light' || v === 'dark' ? v : null;
	} catch {
		return null;
	}
}

function systemTheme(): Theme {
	try {
		return window.matchMedia(QUERY).matches ? 'dark' : 'light';
	} catch {
		return 'light';
	}
}

export class ThemeState {
	choice = $state<Theme | null>(load());
	system = $state<Theme>(systemTheme());
	private stop: (() => void) | undefined;

	get effective(): Theme {
		return this.choice ?? this.system;
	}

	/** Follow the system live while there is no choice. Safe to call more than once. */
	listen(): () => void {
		if (this.stop) return this.stop;
		let mq: MediaQueryList | undefined;
		const onChange = (e: MediaQueryListEvent) => {
			this.system = e.matches ? 'dark' : 'light';
			this.apply();
		};
		try {
			mq = window.matchMedia(QUERY);
			mq.addEventListener('change', onChange);
		} catch {
			mq = undefined;
		}
		this.system = systemTheme();
		this.apply();
		this.stop = () => {
			mq?.removeEventListener('change', onChange);
			this.stop = undefined;
		};
		return this.stop;
	}

	/** Switch to the opposite of what is shown now, and remember it. */
	toggle(): void {
		this.choice = this.effective === 'dark' ? 'light' : 'dark';
		try {
			localStorage.setItem(THEME_KEY, this.choice);
		} catch {
			// storage blocked: the theme holds for this session only
		}
		this.apply();
	}

	/** data-theme is set only when the Operator chose; absent means "follow the system". */
	apply(): void {
		const root = document.documentElement;
		if (this.choice) root.dataset.theme = this.choice;
		else delete root.dataset.theme;
	}
}

export const theme = new ThemeState();
