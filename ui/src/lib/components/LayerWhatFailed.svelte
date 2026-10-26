<script lang="ts">
	import type { CaseDetail } from '../api/types';
	import { brt } from '../format';

	let { detail }: { detail: CaseDetail } = $props();
	const key = $derived(detail.order?.equivalenceKey);
</script>

<section class="layer" aria-labelledby="layer-failed">
	<h2 id="layer-failed" class="section-title">1 · What failed</h2>
	<ol class="exceptions">
		{#each detail.exceptions as ex, i (ex.exceptionId)}
			<li>
				<span class="overline fact">FACT</span>
				<strong>Attempt {i + 1}</strong> · <span class="mono">{ex.kind}</span>{#if ex.httpStatus} · HTTP {ex.httpStatus}{/if}
				{#if ex.responseClass} · classed <span class="mono">{ex.responseClass}</span>{/if}
				<span class="muted small"> · {brt(ex.observedAt)}</span>
				{#if ex.duringExecution}<span class="tag tag-muted">during execution</span>{/if}
				{#if ex.body !== null && ex.body !== undefined}
					<pre class="raw">{typeof ex.body === 'string' ? ex.body : JSON.stringify(ex.body, null, 2)}</pre>
				{/if}
			</li>
		{/each}
	</ol>
	{#if detail.order}
		<p class="small">
			Order <span class="mono">{detail.order.orderId}</span> · correlation <span class="mono">{detail.order.correlationId}</span>
			· transactions <span class="mono">{detail.order.transactionIds.join(', ')}</span>
		</p>
		{#if key}
			<p class="small muted">Equivalence key: patient <span class="mono">{key.patientId}</span>, exams <span class="mono">{key.examCodes.join(', ')}</span>, collected {brt(key.collectedAt)}, specimen <span class="mono">{key.specimenId}</span></p>
		{/if}
	{/if}
</section>
