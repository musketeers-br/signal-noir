<script lang="ts">
	// Similar resolved Cases (feature 015). A similarity search over earlier Cases: information for the
	// Operator, never Evidence and never a decision, so nothing here feeds a form or a dialog. Fetched
	// once per Case; polls replace the detail but keep this component mounted, so it never refetches,
	// resets or takes focus. Every status has its own sentence (FR-011).
	import { getPrecedents } from '../api/client';
	import type { PrecedentSearch } from '../api/types';
	import { COPY } from '../copy';
	import { brt, span } from '../format';
	import StateChip from './StateChip.svelte';

	let { caseId }: { caseId: string } = $props();

	let search = $state<PrecedentSearch | null>(null);
	let failed = $state(false);
	let loadedFor = '';

	$effect(() => {
		const id = caseId;
		if (id === loadedFor) return;
		loadedFor = id;
		search = null;
		failed = false;
		getPrecedents(id).then((r) => {
			if (loadedFor !== id) return;
			if (r.ok) search = r.data;
			else failed = true;
		});
	});

	const modeLabel = $derived(search ? (search.mode === 'lexical' ? COPY.precedentsLexical : COPY.precedentsProvider(search.model)) : '');
	const message = $derived.by(() => {
		if (failed) return COPY.precedentsFailed;
		if (!search) return COPY.precedentsLoading;
		if (search.status === 'results') return `${search.items.length} similar resolved ${search.items.length === 1 ? 'Case' : 'Cases'} found.`;
		const base = COPY.precedentsStatus[search.status] ?? search.status;
		return search.reason ? `${base} ${COPY.precedentsReason[search.reason] ?? ''}`.trim() : base;
	});
	const pct = (n: number) => `${Math.round(n * 100)}%`;
</script>

<section class="precedents" aria-labelledby="precedents-title-{caseId}" data-testid="precedents">
	<h3 id="precedents-title-{caseId}">{COPY.precedentsTitle}</h3>
	<p class="small muted">{COPY.precedentsNotice}{#if modeLabel} <span class="tag tag-muted" data-testid="precedents-mode">{modeLabel}</span>{/if}</p>
	<p class="small" role="status" aria-live="polite" data-testid="precedents-status" data-status={failed ? 'failed' : (search?.status ?? 'loading')}>{message}</p>
	{#if search?.status === 'results'}
		<ol class="precedent-list">
			{#each search.items as p (p.caseId)}
				<li class="precedent" data-final={p.finalState}>
					<a href="#/cases/{p.caseId}"><span class="mono">{p.orderId}</span> <span class="mono small muted">{p.caseId}</span></a>
					<StateChip state={p.finalState} />
					<span class="small">{p.action ? p.action : 'No action'} · {p.description}</span>
					<span class="small muted">partner <span class="mono">{p.partnerId}</span> · closed {brt(p.closedAt)} · took {span('1970-01-01T00:00:00Z', new Date(p.durationSeconds * 1000).toISOString())}</span>
					<span class="small">similarity <strong>{pct(p.similarity)}</strong></span>
					<span><span class="tag">{COPY.synthetic}</span>{#if p.replay}<span class="tag tag-replay">{COPY.replay}</span>{/if}</span>
				</li>
			{/each}
		</ol>
	{/if}
</section>

<style>
	.precedents {
		margin-top: var(--sp-3);
	}
	.precedent-list {
		list-style: none;
		padding: 0;
		margin: 0;
		display: grid;
		gap: var(--sp-2);
	}
	.precedent {
		display: flex;
		flex-wrap: wrap;
		gap: 4px var(--sp-2);
		align-items: baseline;
		padding: var(--sp-2) var(--sp-3);
		border-radius: var(--r-md);
		background: var(--surface-inset);
	}
</style>
