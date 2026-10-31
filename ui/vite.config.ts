import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vitest/config';

/** Static SPA served by IRIS at /signalnoir/ui/ (AD-17): hash router, one index.html. */
export default defineConfig(({ mode }) => ({
	plugins: [
		sveltekit({
			adapter: adapter({ pages: 'build', assets: 'build', strict: true }),
			router: { type: 'hash' },
			// served by IRIS at a fixed path (AD-17); hash routing keeps deep links on index.html
			paths: { base: '/signalnoir/ui', relative: false }
		})
	],
	server: { fs: { allow: ['..'] } },
	resolve: mode === 'test' ? { conditions: ['browser'] } : undefined,
	test: {
		environment: 'jsdom',
		include: ['tests/**/*.test.ts'],
		setupFiles: ['tests/setup.ts'],
		// the token tests read the stylesheets as text; vitest empties CSS unless asked
		css: { include: [/src\/.*\.css/] }
	}
}));
