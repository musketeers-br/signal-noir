<script lang="ts">
	import type { CaseDetail, Evidence } from '../api/types';
	import EvidenceCard from './EvidenceCard.svelte';
	import NotYet from './NotYet.svelte';

	let { detail }: { detail: CaseDetail } = $props();

	const conflicts = $derived([...(detail.diagnosis?.conflicts ?? []), ...(detail.dossier?.conflicts ?? [])]);
	const byId = $derived(new Map(detail.evidence.map((e) => [e.evidenceId, e])));
	const inConflict = $derived(new Set(conflicts.flatMap((c) => c.evidenceIds)));
	const rest = $derived(detail.evidence.filter((e) => !inConflict.has(e.evidenceId)));

	function pick(ids: string[]): Evidence[] {
		return ids.map((id) => byId.get(id)).filter((e): e is Evidence => !!e);
	}
</script>

<section class="layer" aria-labelledby="layer-evidence">
	<h2 id="layer-evidence" class="section-title">2 · Evidence</h2>
	<p class="small muted">Read-only. What the tools observed, by value.</p>
	{#if detail.evidence.length === 0}
		<NotYet />
	{:else}
		{#each conflicts as c, i (i)}
			<div class="conflict" role="group" aria-label="Conflicting evidence">
				<p class="conflict-head"><span aria-hidden="true">⇄</span> <strong>Conflict</strong>: {c.description}</p>
				<div class="side-by-side">
					{#each pick(c.evidenceIds) as ev (ev.evidenceId)}<EvidenceCard {ev} />{/each}
				</div>
			</div>
		{/each}
		{#each rest as ev (ev.evidenceId)}<EvidenceCard {ev} />{/each}
	{/if}
</section>
