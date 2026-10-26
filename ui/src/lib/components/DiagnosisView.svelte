<script lang="ts">
	import type { Diagnosis } from '../api/types';
	import EvidenceChip from './EvidenceChip.svelte';

	let { diagnosis }: { diagnosis: Diagnosis } = $props();
</script>

<div class="interpretation-card">
	<span class="overline interpretation">INTERPRETATION</span>
	<p>{diagnosis.summary}</p>
	<h4>Claims</h4>
	<ul class="claims">
		{#each diagnosis.claims as claim, i (i)}
			<li>{claim.text} {#each claim.evidenceIds as id (id)}<EvidenceChip {id} /> {/each}</li>
		{/each}
	</ul>
	{#if diagnosis.hypotheses?.length}
		<h4>Hypotheses</h4>
		<ul class="hypotheses">
			{#each diagnosis.hypotheses as h, i (i)}
				<li>
					<span class="tag {h.status === 'chosen' ? 'tag-success' : 'tag-muted'}">{h.status === 'chosen' ? '✓ chosen' : '✕ discarded'}</span>
					{h.text}
					{#if h.reason}<span class="muted"> — {h.reason}</span>{/if}
					{#each h.evidenceIds ?? [] as id (id)} <EvidenceChip {id} />{/each}
				</li>
			{/each}
		</ul>
	{/if}
</div>
