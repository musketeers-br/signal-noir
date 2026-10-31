<script lang="ts">
	// The console: top bar, hash routes (#/cases, #/cases/<id>), polling every 1.5 s, toasts.
	// Route changes move focus to the main region and announce the page title.
	import { onDestroy, onMount, tick } from 'svelte';
	import { COPY } from '../copy';
	import { CaseDetailState } from '../stores/caseDetail.svelte';
	import { CaseListState } from '../stores/cases.svelte';
	import { nameProblem, operator } from '../stores/operator.svelte';
	import CaseDetail from './CaseDetail.svelte';
	import CaseList from './CaseList.svelte';
	import ConnectionNote from './ConnectionNote.svelte';
	import ThemeToggle from './ThemeToggle.svelte';
	import Toasts from './Toasts.svelte';
	import { theme } from '../stores/theme.svelte';

	let { pollMs = 1500 }: { pollMs?: number } = $props();

	const list = new CaseListState();
	let detail = $state<CaseDetailState | null>(null);
	let main: HTMLElement;
	let timer: ReturnType<typeof setInterval> | undefined;
	let polling = false;
	let stopTheme: (() => void) | undefined;

	function route(): { view: 'list' } | { view: 'case'; caseId: string } {
		const m = /^#\/cases\/([^/?#]+)/.exec(location.hash);
		return m ? { view: 'case', caseId: decodeURIComponent(m[1]) } : { view: 'list' };
	}

	async function go() {
		const r = route();
		if (r.view === 'case') {
			detail = new CaseDetailState(r.caseId);
			await detail.refresh();
			document.title = detail.detail ? `Case ${detail.detail.orderId} · Signal Noir` : 'Case not found · Signal Noir';
		} else {
			detail = null;
			await list.load();
			document.title = 'Cases · Signal Noir';
		}
		await tick();
		main?.focus();
	}

	/** One poll of whatever is on screen. Exposed for tests through the polling interval. */
	export async function poll() {
		if (polling) return;
		polling = true;
		try {
			if (detail) await detail.refresh();
			else await list.poll();
		} finally {
			polling = false;
		}
	}

	/** In-app links (#/...) are ours. SvelteKit's router would otherwise take them with
	 *  history.pushState, which fires no hashchange: the URL changed and the view did not.
	 *  Runs in the capture phase, before the router; modified clicks stay with the browser. */
	function onLinkClick(e: MouseEvent) {
		if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
		const a = (e.target as Element | null)?.closest?.('a[href^="#/"]');
		if (!a || a.getAttribute('target')) return;
		e.preventDefault();
		const href = a.getAttribute('href')!;
		if (location.hash === href) go();
		else location.hash = href;
	}

	onMount(() => {
		stopTheme = theme.listen();
		if (!location.hash) location.hash = '#/cases';
		window.addEventListener('hashchange', go);
		document.addEventListener('click', onLinkClick, true);
		go();
		timer = setInterval(poll, pollMs);
	});

	onDestroy(() => {
		if (typeof window !== 'undefined') {
			window.removeEventListener('hashchange', go);
			document.removeEventListener('click', onLinkClick, true);
		}
		clearInterval(timer);
		stopTheme?.();
	});

	const problem = $derived(nameProblem(operator.name));
</script>

<div class="shell">
<header class="topbar">
	<a class="wordmark" href="#/cases">Signal Noir</a>
	<nav class="rail-nav" aria-label="Main"><a href="#/cases" aria-current="page">Cases</a></nav>
	<label class="name-field">Acting as (declared name)
		<input type="text" value={operator.name} oninput={(e) => operator.set((e.currentTarget as HTMLInputElement).value)} aria-invalid={problem === 'colon'} autocomplete="name" />
	</label>
	{#if problem === 'colon'}<span class="inline-error small" role="alert">{COPY.nameNoColon}</span>{/if}
	<span class="badge-synthetic">{COPY.syntheticData}</span>
	<ThemeToggle />
	<ConnectionNote />
</header>
<main bind:this={main} tabindex="-1" class="main">
	{#if detail}
		<CaseDetail view={detail} />
	{:else}
		<CaseList {list} />
	{/if}
</main>
</div>
<Toasts />
