<script lang="ts">
	import type { CaseDetail, Proposal } from '../api/types';
	import { money, ms } from '../format';
	import NotYet from './NotYet.svelte';

	let { detail, onApprove }: { detail: CaseDetail; onApprove?: () => void } = $props();

	const current = $derived(detail.proposals.find((p) => p.proposalId === detail.currentProposalId) ?? null);
	const earlier = $derived(detail.proposals.filter((p) => p.proposalId !== detail.currentProposalId));
	let showEarlier = $state(false);
	let showVersions = $state(false);

	function params(p: Proposal): string {
		const entries = Object.entries(p.params ?? {});
		return entries.length ? entries.map(([k, v]) => `${k}=${v}`).join(', ') : 'none';
	}
</script>

<section class="layer" aria-labelledby="layer-proposal">
	<h2 id="layer-proposal" class="section-title">4 · Proposal</h2>
	{#if !current}
		<NotYet />
	{:else}
		<div class="proposal-card" data-proposal-id={current.proposalId}>
			<p class="action-name mono">{current.action}</p>
			<dl class="kv">
				<dt>Parameters</dt><dd class="mono">{params(current)}</dd>
				<dt>Scope</dt><dd class="mono">{current.scope}</dd>
				<dt>Confidence</dt><dd>{current.confidence}</dd>
				<dt>Author</dt><dd class="mono">{current.author}</dd>
				<dt>Proposal</dt><dd class="mono">{current.proposalId}</dd>
			</dl>
			{#if current.preconditions?.length}
				<h4>Preconditions that must still hold</h4>
				<ul class="small">{#each current.preconditions as pc, i (i)}<li><span class="mono">{pc.check}</span> = <span class="mono">{JSON.stringify(pc.expected)}</span></li>{/each}</ul>
			{/if}
			{#if current.validatorVerdict}
				<p class="small">Validator: <span class="mono">{current.validatorVerdict.verdict}</span>{#if current.validatorVerdict.reasons.length} · <span class="mono">{current.validatorVerdict.reasons.join(', ')}</span>{/if}</p>
			{/if}
			<button type="button" class="btn btn-secondary btn-small" aria-expanded={showVersions} onclick={() => (showVersions = !showVersions)}>Versions and metrics</button>
			{#if showVersions}
				<dl class="kv small" data-testid="proposal-metrics">
					<dt>Model</dt><dd class="mono">{current.versions.model ?? detail.metrics?.model ?? '—'}</dd>
					<dt>Provider</dt><dd class="mono">{current.versions.provider ?? detail.metrics?.provider ?? '—'}</dd>
					<dt>Prompt</dt><dd class="mono">{current.versions.prompt ?? detail.metrics?.promptVersion ?? '—'}</dd>
					<dt>Policy / mapping</dt><dd class="mono">{current.versions.policy} / {current.versions.mapping}</dd>
				</dl>
			{/if}
			{#if detail.state === 'PendingApproval' && onApprove}
				<button type="button" class="btn btn-primary" onclick={onApprove}>Review &amp; approve…</button>
			{/if}
		</div>
		{#if earlier.length}
			<button type="button" class="btn btn-secondary btn-small" aria-expanded={showEarlier} onclick={() => (showEarlier = !showEarlier)}>Earlier versions ({earlier.length})</button>
			{#if showEarlier}
				<ul class="earlier">{#each earlier as p (p.proposalId)}<li class="small"><span class="mono">{p.proposalId}</span> · <span class="mono">{p.action}</span> · {p.confidence}{#if p.supersededBy} · superseded by <span class="mono">{p.supersededBy}</span>{/if}</li>{/each}</ul>
			{/if}
		{/if}
	{/if}
	<dl class="kv small metrics" aria-label="Investigation metrics">
		<dt>Model</dt><dd class="mono">{detail.metrics?.model ?? '—'}</dd>
		<dt>Provider</dt><dd class="mono">{detail.metrics?.provider ?? '—'}</dd>
		<dt>Duration</dt><dd>{ms(detail.metrics?.investigationDurationMs)}</dd>
		<dt>Tool calls</dt><dd>{detail.metrics?.toolCalls ?? '—'}</dd>
		<dt>Attempts</dt><dd>{detail.metrics?.attempts ?? '—'}</dd>
		<dt>Estimated cost</dt><dd>{money(detail.metrics?.estCostUsd)}</dd>
	</dl>
</section>
