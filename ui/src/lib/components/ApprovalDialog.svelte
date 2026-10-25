<script lang="ts">
	// Decides on one exact Proposal version. proposalId and caseVersion are frozen when the dialog
	// opens and sent unchanged; polls never alter them (FR-009). Every answer has its own treatment.
	import { onMount } from 'svelte';
	import { decide, mappings as loadMappings } from '../api/client';
	import type { Outcome } from '../api/outcome';
	import type { ApprovedMapping, CaseDetail, ProposalDecisionResult } from '../api/types';
	import { COPY } from '../copy';
	import { effectText } from '../effect';
	import { nameProblem, operator } from '../stores/operator.svelte';
	import { toasts } from '../stores/toasts.svelte';

	let { detail, onClose, onRefresh }: { detail: CaseDetail; onClose: () => void; onRefresh: () => Promise<void> } = $props();

	let dialog: HTMLDialogElement;
	let nameInput: HTMLInputElement;
	// frozen at open
	let frozenProposalId = $state('');
	let frozenVersion = $state(0);
	let frozenProposal = $state<CaseDetail['proposals'][number] | null>(null);
	let maps = $state<ApprovedMapping[]>([]);
	let mode = $state<'approve' | 'deny'>('approve');
	let reason = $state('');
	let inFlight = $state(false);
	let outcome = $state<Outcome<ProposalDecisionResult> | null>(null);
	let fieldError = $state('');
	let detailAtNetworkError = $state<CaseDetail | null>(null);

	const waitingForPoll = $derived(detailAtNetworkError !== null && detail === detailAtNetworkError);
	const locked = $derived(outcome?.kind === 'stale' || outcome?.kind === 'invalidTransition');

	function freeze() {
		frozenProposalId = detail.currentProposalId ?? '';
		frozenVersion = detail.caseVersion;
		frozenProposal = detail.proposals.find((p) => p.proposalId === frozenProposalId) ?? null;
	}

	onMount(() => {
		freeze();
		dialog.showModal();
		nameInput?.focus();
		loadMappings().then((r) => {
			if (r.ok) maps = r.data.items;
		});
	});

	function close() {
		if (dialog?.open) dialog.close();
		onClose();
	}

	async function send(decision: 'approved' | 'denied') {
		fieldError = '';
		const problem = nameProblem(operator.name);
		if (problem) {
			fieldError = problem === 'colon' ? COPY.nameNoColon : COPY.nameRequired;
			return;
		}
		if (decision === 'denied' && !reason.trim()) {
			fieldError = COPY.reasonRequiredDeny;
			return;
		}
		inFlight = true;
		outcome = null;
		const body = { decision, operator: operator.name.trim(), expectedCaseVersion: frozenVersion, ...(decision === 'denied' ? { reason: reason.trim() } : {}) };
		const result = await decide(detail.caseId, frozenProposalId, body);
		inFlight = false;
		outcome = result;
		if (result.kind === 'created') {
			toasts.push(decision === 'approved' ? COPY.approvedToast : COPY.deniedToast, 'success');
			close();
			await onRefresh();
		} else if (result.kind === 'replay') {
			toasts.push(COPY.replayToast(result.body.approval.by), 'muted');
			close();
			await onRefresh();
		} else if (result.kind === 'network') {
			detailAtNetworkError = detail;
		} else if (result.kind === 'badRequest') {
			fieldError = result.message;
		}
	}

	async function reviewNewVersion() {
		await onRefresh();
		outcome = null;
		reason = '';
		mode = 'approve';
		freeze();
	}
</script>

<dialog bind:this={dialog} class="dialog" aria-labelledby="approval-title" oncancel={(e) => { e.preventDefault(); close(); }} onkeydown={(e) => { if (e.key === 'Escape') { e.preventDefault(); close(); } }}>
	<h2 id="approval-title" class="section-title">Decide on proposal <span class="mono">{frozenProposalId}</span></h2>
	<p class="small muted">Case <span class="mono">{detail.caseId}</span> at version {frozenVersion} · <span class="tag">{COPY.synthetic}</span></p>
	{#if frozenProposal}
		<p class="action-name mono">{frozenProposal.action}</p>
		<p data-testid="effect">{effectText(frozenProposal, detail, maps)}</p>
		{#if frozenProposal.preconditions.length}
			<p class="small">Re-checked right before sending: {frozenProposal.preconditions.map((p) => p.check).join(', ')}.</p>
		{/if}
	{/if}

	<label class="field">Your name (declared, not authenticated)
		<input bind:this={nameInput} type="text" value={operator.name} oninput={(e) => operator.set((e.currentTarget as HTMLInputElement).value)} autocomplete="name" />
	</label>

	{#if mode === 'deny'}
		<label class="field">Reason for denying (becomes evidence)
			<textarea bind:value={reason} rows="3" data-testid="deny-reason"></textarea>
		</label>
	{/if}

	{#if fieldError}<p class="inline-error" role="alert">{fieldError}</p>{/if}

	{#if outcome?.kind === 'stale'}
		<div class="inline-error" role="alert"><p>{COPY.stale}</p></div>
		<button type="button" class="btn btn-primary" onclick={reviewNewVersion}>{COPY.reviewNewVersion}</button>
	{:else if outcome?.kind === 'invalidTransition'}
		<div class="inline-error" role="alert"><p>{COPY.invalidTransition(String(outcome.details.state ?? 'in another state'))}</p></div>
	{:else if outcome?.kind === 'invalidActor'}
		<p class="inline-error" role="alert">{COPY.invalidActor}</p>
	{:else if outcome?.kind === 'notFound'}
		<p class="inline-error" role="alert">{COPY.caseNotFound} <a href="#/cases">{COPY.backToCases}</a></p>
	{:else if outcome?.kind === 'network'}
		<p class="inline-error" role="alert">{COPY.network}</p>
	{:else if outcome?.kind === 'server'}
		<p class="inline-error" role="alert">{COPY.server}</p>
	{/if}

	<div class="dialog-actions">
		{#if !locked}
			{#if mode === 'approve'}
				<button type="button" class="btn btn-primary" disabled={inFlight || waitingForPoll} onclick={() => send('approved')}>Approve this version</button>
				<button type="button" class="btn btn-secondary" disabled={inFlight} onclick={() => { mode = 'deny'; fieldError = ''; }}>Deny…</button>
			{:else}
				<button type="button" class="btn btn-danger" disabled={inFlight || waitingForPoll} onclick={() => send('denied')}>Confirm denial</button>
				<button type="button" class="btn btn-secondary" disabled={inFlight} onclick={() => { mode = 'approve'; fieldError = ''; }}>Back</button>
			{/if}
		{/if}
		<button type="button" class="btn btn-secondary" onclick={close}>{outcome?.kind === 'invalidTransition' ? 'Close and see the case' : 'Close'}</button>
	</div>
</dialog>
