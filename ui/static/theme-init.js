// Applies the Operator's remembered theme before first paint (feature 014, FR-005).
// Same rule as src/lib/stores/theme.svelte.ts: only 'light' or 'dark' count; otherwise follow the system.
(function () {
	try {
		var v = localStorage.getItem('signalnoir.theme');
		if (v === 'light' || v === 'dark') document.documentElement.setAttribute('data-theme', v);
	} catch (e) {
		// storage blocked: follow the system
	}
})();
