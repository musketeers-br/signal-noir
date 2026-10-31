<script lang="ts">
	import { onMount } from 'svelte';
	import type { CaseDetail } from '../api/types';
	import { brt } from '../format';
	import { COPY } from '../copy';
	import DiagnosisView from './DiagnosisView.svelte';
	import EvidenceChip from './EvidenceChip.svelte';
	import PrecedentsPanel from './PrecedentsPanel.svelte';
	import ResolutionForm from './ResolutionForm.svelte';

	let { detail, collapsed = false, onRefresh }: { detail: CaseDetail; collapsed?: boolean; onRefresh: () => Promise<void> } = $props();
	let open = $state(true);
	onMount(() => (open = !collapsed));
	const d = $derived(detail.dossier!);
</script>

<section id="dossier" class="dossier" tabindex="-1" aria-labelledby="dossier-title">
	<h2 id="dossier-title" class="section-title">Review dossier</h2>
	{#if collapsed}
		<button type="button" class="btn btn-secondary btn-small" aria-expanded={open} onclick={() => (open = !open)}>{open ? 'Hide dossier' : 'Show dossier'}</button>
	{/if}
	{#if open}
		<p><strong>Why automation stopped:</strong> {d.reasonText} <span class="mono small muted">({d.reason})</span></p>
		<p class="small muted">Created {brt(d.createdAt)}</p>

		<h3>Partial diagnosis</h3>
		{#if d.partialDiagnosis}<DiagnosisView diagnosis={d.partialDiagnosis} />{:else}<p class="not-yet">{COPY.noDiagnosis}</p>{/if}

		{#if d.hypotheses?.length}
			<h3>Hypotheses</h3>
			<ul>{#each d.hypotheses as h, i (i)}<li>{h.status === 'chosen' ? '✓' : '✕'} {h.text}{#if h.reason}<span class="muted"> — {h.reason}</span>{/if}</li>{/each}</ul>
		{/if}

		{#if d.relevantEvidenceIds?.length}
			<h3>What was checked</h3>
			<p>{#each d.relevantEvidenceIds as id (id)}<EvidenceChip {id} /> {/each}</p>
		{/if}

		{#if d.conflicts?.length}
			<h3>Conflicts</h3>
			<ul>{#each d.conflicts as c, i (i)}<li><span aria-hidden="true">⇄</span> {c.description} {#each c.evidenceIds as id (id)}<EvidenceChip {id} /> {/each}</li>{/each}</ul>
		{/if}

		{#if d.collidingRecords?.length}
			<h3>Colliding records</h3>
			{#each d.collidingRecords as r (r.recordRef)}
				<table class="table">
					<caption class="small mono">{r.recordRef}{#if r.source} · {r.source}{/if}</caption>
					<tbody>
						{#each Object.entries(r.fields) as [k, v] (k)}
							<tr class:divergent={r.divergentFields.includes(k)}>
								<th scope="row" class="mono">{k}</th>
								<td class="mono">{String(v)}</td>
								<td>{#if r.divergentFields.includes(k)}<span title="diverges">≠ diverges</span>{/if}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			{/each}
		{/if}

		{#if d.unconfirmedCandidates?.length}
			<h3>Unconfirmed prior receipts</h3>
			<ul>{#each d.unconfirmedCandidates as c (c.receiptId)}<li><span class="mono">{c.receiptId}</span> (order <span class="mono">{c.orderId}</span>) · mismatched: <span class="mono">{c.mismatchedFields.join(', ')}</span></li>{/each}</ul>
		{/if}

		<h3>What we don't know</h3>
		<p class="small muted">{COPY.unknownsNote}</p>
		{#if d.unknowns?.length}
			<ul data-testid="unknowns">{#each d.unknowns as u, i (i)}<li>{#if u.topic}<span class="tag tag-muted">{u.topic}</span> {/if}{u.text}</li>{/each}</ul>
		{:else}
			<p data-testid="unknowns">{COPY.nothingFlagged}</p>
		{/if}

		<div class="next-step"><strong>Suggested next step:</strong> {d.suggestedNextStep}</div>

		{#if !collapsed}<PrecedentsPanel caseId={detail.caseId} />{/if}

		{#if detail.state === 'ReviewRequired'}
			<ResolutionForm {detail} {onRefresh} />
		{/if}
	{/if}
</section>
