<script lang="ts">
	import type { CaseDetail } from '../api/types';
	import { stateCopy } from '../copy';

	let { detail, onApprove, onDossier }: { detail: CaseDetail; onApprove?: () => void; onDossier?: () => void } = $props();
	const latest = $derived(detail.executions.length ? detail.executions[detail.executions.length - 1].outcome : null);
	const copy = $derived(stateCopy(detail.state, latest));
</script>

<div class="banner tone-{copy.tone}" role="status" data-testid="state-banner">
	<p><span aria-hidden="true">{copy.glyph}</span> <strong>{copy.label}.</strong> {copy.banner}</p>
	{#if copy.action === 'approve' && onApprove && detail.currentProposalId}
		<button type="button" class="btn btn-primary" onclick={onApprove}>Review &amp; approve…</button>
	{:else if copy.action === 'dossier' && onDossier}
		<button type="button" class="btn btn-primary" onclick={onDossier}>Go to dossier</button>
	{/if}
</div>
