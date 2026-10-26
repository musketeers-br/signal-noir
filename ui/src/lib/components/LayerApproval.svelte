<script lang="ts">
	import type { CaseDetail } from '../api/types';
	import { brt } from '../format';
	import NotYet from './NotYet.svelte';

	let { detail }: { detail: CaseDetail } = $props();
</script>

<section class="layer" aria-labelledby="layer-approval">
	<h2 id="layer-approval" class="section-title">5 · Approval</h2>
	{#if detail.approvals.length === 0}
		<NotYet />
	{:else}
		<ul>
			{#each detail.approvals as a (a.approvalId)}
				<li>
					<span class="tag {a.decision === 'approved' ? 'tag-success' : 'tag-attention'}">{a.decision === 'approved' ? '✓ approved' : '✕ denied'}</span>
					by <strong>{a.by}</strong> <span class="muted">(declared name)</span> · {brt(a.at)} · proposal <span class="mono">{a.proposalId}</span>
					{#if a.expiresAt} · valid until {brt(a.expiresAt)}{/if}
					{#if a.status} · <span class="mono">{a.status}</span>{/if}
					{#if a.reason}<br /><span class="small">Reason: {a.reason}</span>{/if}
				</li>
			{/each}
		</ul>
	{/if}
</section>
