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
	import Toasts from './Toasts.svelte';

	let { pollMs = 1500 }: { pollMs?: number } = $props();

	const list = new CaseListState();
	let detail = $state<CaseDetailState | null>(null);
	let main: HTMLElement;
	let timer: ReturnType<typeof setInterval> | undefined;
	let polling = false;

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

	onMount(() => {
		if (!location.hash) location.hash = '#/cases';
		window.addEventListener('hashchange', go);
		go();
		timer = setInterval(poll, pollMs);
	});

	onDestroy(() => {
		if (typeof window !== 'undefined') window.removeEventListener('hashchange', go);
		clearInterval(timer);
	});

	const problem = $derived(nameProblem(operator.name));
</script>

<header class="topbar">
	<a class="wordmark" href="#/cases">Signal Noir</a>
	<nav aria-label="Main"><a href="#/cases">Cases</a></nav>
	<label class="name-field">Acting as (declared name)
		<input type="text" value={operator.name} oninput={(e) => operator.set((e.currentTarget as HTMLInputElement).value)} aria-invalid={problem === 'colon'} autocomplete="name" />
	</label>
	{#if problem === 'colon'}<span class="inline-error small" role="alert">{COPY.nameNoColon}</span>{/if}
	<span class="badge-synthetic">{COPY.syntheticData}</span>
	<ConnectionNote />
</header>
<main bind:this={main} tabindex="-1" class="main">
	{#if detail}
		<CaseDetail view={detail} />
	{:else}
		<CaseList {list} />
	{/if}
</main>
<Toasts />
