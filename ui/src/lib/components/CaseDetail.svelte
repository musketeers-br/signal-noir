<script lang="ts">
	// One case: banner, dossier (first while in review, last and collapsed once closed), the six
	// layers and the timeline. The detail is replaced by polls; everything the Operator is doing
	// (dialog, form values, open sections, focus) lives in child components that stay mounted.
	import { tick } from 'svelte';
	import { COPY } from '../copy';
	import type { CaseDetailState } from '../stores/caseDetail.svelte';
	import ApprovalDialog from './ApprovalDialog.svelte';
	import Dossier from './Dossier.svelte';
	import Labels from './Labels.svelte';
	import LayerApproval from './LayerApproval.svelte';
	import LayerDiagnosis from './LayerDiagnosis.svelte';
	import LayerEvidence from './LayerEvidence.svelte';
	import LayerExecution from './LayerExecution.svelte';
	import LayerProposal from './LayerProposal.svelte';
	import LayerWhatFailed from './LayerWhatFailed.svelte';
	import PrecedentsPanel from './PrecedentsPanel.svelte';
	import StateBanner from './StateBanner.svelte';
	import Timeline from './Timeline.svelte';

	let { view }: { view: CaseDetailState } = $props();

	let dialogOpen = $state(false);
	let trigger: HTMLElement | null = null;
	const d = $derived(view.detail);
	const terminal = $derived(d ? ['Resolved', 'ResolvedByPriorReceipt', 'Cancelled', 'Failed'].includes(d.state) : false);

	function openDialog(e?: MouseEvent) {
		trigger = (e?.currentTarget as HTMLElement) ?? (document.activeElement as HTMLElement);
		dialogOpen = true;
	}

	async function closeDialog() {
		dialogOpen = false;
		await tick();
		trigger?.focus();
	}

	async function toDossier() {
		await tick();
		document.getElementById('dossier')?.focus();
	}

	const refresh = () => view.refresh();
</script>

{#if view.notFound}
	<section aria-labelledby="nf-title">
		<h1 id="nf-title" class="page-title">{COPY.caseNotFound}</h1>
		<a href="#/cases" class="back-link">{COPY.backToCases}</a>
	</section>
{:else if d}
	<article class="case-detail" aria-labelledby="case-title">
		<header class="case-header">
			<a href="#/cases" class="small">← {COPY.backToCases}</a>
			<h1 id="case-title" class="page-title">Case <span class="mono">{d.orderId}</span></h1>
			<p class="small muted">
				<span class="mono">{d.caseId}</span> · partner <span class="mono">{d.partnerId}</span> · version {d.caseVersion}
				{#if d.proposerMode} · mode <span class="mono">{d.proposerMode}</span>{/if}
				<Labels labels={d.labels} />
				{#if d.visualTraceUrl}· <a href={d.visualTraceUrl} target="_blank" rel="noopener">Visual Trace</a>{/if}
			</p>
		</header>
		<StateBanner detail={d} onApprove={openDialog} onDossier={toDossier} />
		<div class="detail-grid">
			<div class="layers">
				{#if d.dossier && !terminal}<Dossier detail={d} onRefresh={refresh} />{/if}
				<LayerWhatFailed detail={d} />
				<LayerEvidence detail={d} />
				<LayerDiagnosis detail={d} />
				<LayerProposal detail={d} onApprove={openDialog} />
				<LayerApproval detail={d} />
				<LayerExecution detail={d} />
				<!-- in review the Dossier shows them next to the next step (015) -->
				{#if !(d.dossier && !terminal)}<section class="layer" aria-label="Similar resolved Cases"><PrecedentsPanel caseId={d.caseId} /></section>{/if}
				{#if d.dossier && terminal}<Dossier detail={d} collapsed onRefresh={refresh} />{/if}
			</div>
			<Timeline events={view.events} />
		</div>
	</article>
	{#if dialogOpen}
		<ApprovalDialog detail={d} onClose={closeDialog} onRefresh={refresh} />
	{/if}
{:else if view.error}
	<p class="inline-error" role="alert">The case could not be loaded: {view.error}</p>
{:else}
	<p class="muted">Loading case…</p>
{/if}
