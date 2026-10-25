<script lang="ts">
	import type { CaseSummary } from '../api/types';
	import { age, remaining } from '../format';
	import Labels from './Labels.svelte';
	import StateChip from './StateChip.svelte';

	let { row, serverTime, changed = false }: { row: CaseSummary; serverTime: string; changed?: boolean } = $props();
</script>

<li class="case-row" class:changed>
	<a class="case-link" href="#/cases/{row.caseId}" data-case-id={row.caseId}>
		<span class="cell cell-id"><span class="mono">{row.orderId}</span><span class="muted mono small">{row.caseId}</span></span>
		<span class="cell"><StateChip state={row.state} outcome={row.executionOutcome} /></span>
		<span class="cell cell-partner muted">{row.partnerId}</span>
		<span class="cell small">
			{#if row.currentProposal}<span class="mono">{row.currentProposal.action}</span> · {row.currentProposal.confidence}{:else}<span class="muted">No proposal</span>{/if}
		</span>
		<span class="cell small muted">{row.lastExceptionSummary ?? ''}</span>
		<span class="cell small">
			Age {age(row.createdAt, serverTime || row.serverTime)}
			{#if row.approvalDeadline}<br /><span class="attention">Approval {remaining(row.approvalDeadline, serverTime || row.serverTime)}</span>{/if}
		</span>
		<span class="cell cell-labels"><Labels labels={row.labels} /></span>
	</a>
</li>
