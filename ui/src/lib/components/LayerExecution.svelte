<script lang="ts">
	import type { CaseDetail } from '../api/types';
	import { brt } from '../format';
	import NotYet from './NotYet.svelte';

	let { detail }: { detail: CaseDetail } = $props();
</script>

<section class="layer" aria-labelledby="layer-execution">
	<h2 id="layer-execution" class="section-title">6 · Execution &amp; receipt</h2>
	{#if detail.executions.length === 0 && !detail.receipt}
		<NotYet />
	{/if}
	{#each detail.executions as ex (ex.executionId)}
		<div class="execution">
			<p><span class="mono">{ex.action}</span> · outcome <span class="mono">{ex.outcome}</span> · authorized {brt(ex.authorizedAt)} · key <span class="mono small">{ex.idempotencyKey}</span></p>
			{#if ex.revalidation}
				<table class="table">
					<caption class="small">Revalidation right before sending ({ex.revalidation.passed ? 'passed' : 'failed'})</caption>
					<thead><tr><th scope="col">Check</th><th scope="col">Expected</th><th scope="col">Observed</th><th scope="col">Result</th></tr></thead>
					<tbody>
						{#each ex.revalidation.checks as c, i (i)}
							<tr><td class="mono">{c.check}</td><td class="mono">{JSON.stringify(c.expected)}</td><td class="mono">{JSON.stringify(c.observed)}</td><td>{c.passed ? '✓ holds' : '✕ fails'}</td></tr>
						{/each}
					</tbody>
				</table>
			{/if}
			{#if ex.attempts.length}
				<ol class="small">
					{#each ex.attempts as at (at.attemptId)}
						<li>Attempt {at.n} · {brt(at.sentAt)} · {at.httpStatus ?? 'no status'} · <span class="mono">{at.responseClass ?? '—'}</span>{#if at.receiptId} · receipt <span class="mono">{at.receiptId}</span>{/if}</li>
					{/each}
				</ol>
			{/if}
			{#each ex.reconciliations ?? [] as r, i (i)}
				<p class="small">Reconciliation ({r.trigger}) {brt(r.at)}: {r.found ? `receipt ${r.receiptId} found` : 'no receipt found'}</p>
			{/each}
		</div>
	{/each}
	{#if detail.receipt}
		<p class="receipt">
			<span class="overline fact">FACT</span> Partner receipt <span class="mono">{detail.receipt.receiptId}</span> · {brt(detail.receipt.receivedAt)} · source <span class="mono">{detail.receipt.source}</span>
			{#if detail.receipt.source === 'prior_receipt'} · order <span class="mono">{detail.receipt.orderId}</span> · nothing was resent{/if}
		</p>
	{/if}
</section>
