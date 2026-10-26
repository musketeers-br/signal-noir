<script lang="ts">
	import { COPY } from '../copy';
	import { FILTERS, type CaseListState, type Filter } from '../stores/cases.svelte';
	import CaseRow from './CaseRow.svelte';

	let { list }: { list: CaseListState } = $props();

	const announcement = $derived(list.changed.length ? `${list.changed.length} case${list.changed.length > 1 ? 's' : ''} changed.` : '');

	function choose(f: Filter) {
		if (f !== list.filter) list.load(f);
	}
</script>

<section aria-labelledby="cases-title">
	<h1 id="cases-title" class="page-title">Cases</h1>
	<div class="filters" role="group" aria-label="Filter cases">
		{#each FILTERS as f (f.id)}
			<button type="button" class="btn btn-secondary" aria-pressed={list.filter === f.id} onclick={() => choose(f.id)}>{f.label}</button>
		{/each}
	</div>
	<p class="visually-hidden" aria-live="polite">{announcement}</p>
	{#if list.error && !list.loaded}
		<p class="inline-error" role="alert">The case list could not be loaded: {list.error}</p>
	{:else if list.loaded && list.rows.length === 0}
		<p class="empty">{list.filter === 'needs-you' ? COPY.emptyNeedsYou : COPY.emptyList}</p>
	{:else}
		<ul class="case-list" aria-label="Cases">
			{#each list.rows as row (row.caseId)}
				<CaseRow {row} serverTime={list.serverTime} changed={list.changed.includes(row.caseId)} />
			{/each}
		</ul>
	{/if}
	{#if list.nextCursor}
		<button type="button" class="btn btn-secondary" onclick={() => list.older()}>Load older cases</button>
	{/if}
</section>
