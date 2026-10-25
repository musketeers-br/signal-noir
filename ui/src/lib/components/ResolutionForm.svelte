<script lang="ts">
	// Resolves a review with a catalog Action and its allowed parameters, or a cancellation.
	// There is no free payload field (Constitution III, FR-012).
	import { onMount } from 'svelte';
	import { actionCatalog, mappings as loadMappings, resolve } from '../api/client';
	import type { Outcome } from '../api/outcome';
	import type { Action, ApprovedMapping, CaseDetail, ReviewResolutionResult } from '../api/types';
	import { COPY, reasonText } from '../copy';
	import { nameProblem, operator } from '../stores/operator.svelte';
	import { toasts } from '../stores/toasts.svelte';

	let { detail, onRefresh }: { detail: CaseDetail; onRefresh: () => Promise<void> } = $props();

	interface Option {
		id: string;
		label: string;
		action: Action | 'CANCEL';
		params: Record<string, string>;
	}

	let options = $state<Option[]>([]);
	let choice = $state('');
	let note = $state('');
	let cancelReason = $state('');
	let inFlight = $state(false);
	let fieldError = $state('');
	let outcome = $state<Outcome<ReviewResolutionResult> | null>(null);

	const selected = $derived(options.find((o) => o.id === choice) ?? null);

	function examCodes(): string[] {
		const exams = (detail.order?.snapshot?.exams ?? []) as { code?: string }[];
		return exams.map((e) => e.code ?? '').filter(Boolean);
	}

	onMount(async () => {
		const catalog = await actionCatalog();
		const allowed = new Set<Action>(catalog.ok ? catalog.data.items.map((i) => i.action) : []);
		const opts: Option[] = [];
		if (allowed.has('APPLY_APPROVED_MAPPING')) {
			const seen = new Set<string>();
			for (const code of examCodes()) {
				const r = await loadMappings(code);
				if (!r.ok) continue;
				for (const m of r.data.items as ApprovedMapping[]) {
					const id = `map:${m.mappingId}:${m.mappingVersion}`;
					if (seen.has(id)) continue;
					seen.add(id);
					const cond = Object.entries(m.conditions ?? {}).map(([k, v]) => `${k}=${v}`).join(', ');
					opts.push({ id, label: `Apply ${m.mappingId} (${m.sourceCode} → ${m.targetCode}${cond ? `, when ${cond}` : ''})`, action: 'APPLY_APPROVED_MAPPING', params: { mappingId: m.mappingId, mappingVersion: m.mappingVersion } });
				}
			}
		}
		if (allowed.has('RETRY')) opts.push({ id: 'RETRY', label: 'Retry: resend unchanged', action: 'RETRY', params: {} });
		if (allowed.has('HOLD')) opts.push({ id: 'HOLD', label: 'Hold: send nothing for now', action: 'HOLD', params: {} });
		opts.push({ id: 'CANCEL', label: 'Cancel the case: no effect is sent', action: 'CANCEL', params: {} });
		options = opts;
	});

	async function submit(e: SubmitEvent) {
		e.preventDefault();
		fieldError = '';
		const problem = nameProblem(operator.name);
		if (problem) {
			fieldError = problem === 'colon' ? COPY.nameNoColon : COPY.nameRequired;
			return;
		}
		if (!selected) {
			fieldError = 'Choose an action or cancel.';
			return;
		}
		if (selected.action === 'CANCEL' && !cancelReason.trim()) {
			fieldError = COPY.reasonRequiredCancel;
			return;
		}
		inFlight = true;
		const base = { operator: operator.name.trim(), expectedCaseVersion: detail.caseVersion };
		const body =
			selected.action === 'CANCEL'
				? { kind: 'cancel' as const, ...base, reason: cancelReason.trim() }
				: { kind: 'action' as const, ...base, action: selected.action, params: selected.params, ...(note.trim() ? { note: note.trim() } : {}) };
		const result = await resolve(detail.caseId, body);
		inFlight = false;
		outcome = result;
		if (result.kind === 'created') {
			toasts.push(selected.action === 'CANCEL' ? COPY.cancelledToast : COPY.resolvedToast, 'success');
			choice = '';
			note = '';
			cancelReason = '';
			await onRefresh();
		} else if (result.kind === 'badRequest') {
			fieldError = result.message;
		}
	}
</script>

<form class="resolution" onsubmit={submit} aria-labelledby="resolution-title">
	<h3 id="resolution-title">Resolve this review</h3>
	<fieldset>
		<legend>Choose one action from the catalog</legend>
		{#each options as o (o.id)}
			<label class="option"><input type="radio" name="resolution" value={o.id} bind:group={choice} /> {o.label}</label>
		{/each}
	</fieldset>
	{#if selected?.action === 'CANCEL'}
		<label class="field">Reason for cancelling<textarea bind:value={cancelReason} rows="2" data-testid="cancel-reason"></textarea></label>
	{:else if selected}
		<label class="field">Note (optional, recorded with your decision)<input type="text" bind:value={note} data-testid="resolution-note" /></label>
	{/if}

	{#if fieldError}<p class="inline-error" role="alert">{fieldError}</p>{/if}
	{#if outcome?.kind === 'blocked'}
		<div class="inline-error" role="alert" data-testid="validator-reasons">
			<p><strong>{COPY.blocked}</strong></p>
			<ul>{#each outcome.reasons as code (code)}<li><span class="mono">{code}</span>: {reasonText(code)}</li>{/each}</ul>
		</div>
	{:else if outcome?.kind === 'stale'}
		<p class="inline-error" role="alert">{COPY.stale}</p>
	{:else if outcome?.kind === 'invalidTransition'}
		<p class="inline-error" role="alert">{COPY.invalidTransition(String(outcome.details.state ?? 'in another state'))}</p>
	{:else if outcome?.kind === 'network'}
		<p class="inline-error" role="alert">{COPY.network}</p>
	{:else if outcome?.kind === 'invalidActor' || outcome?.kind === 'server' || outcome?.kind === 'notFound'}
		<p class="inline-error" role="alert">{outcome.kind === 'invalidActor' ? COPY.invalidActor : outcome.kind === 'notFound' ? COPY.caseNotFound : COPY.server}</p>
	{/if}

	<button type="submit" class="btn btn-primary" disabled={inFlight}>Submit resolution</button>
</form>
