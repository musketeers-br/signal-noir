<script lang="ts">
	import type { CaseDetail } from '../api/types';
	import { COPY } from '../copy';
	import DiagnosisView from './DiagnosisView.svelte';

	let { detail }: { detail: CaseDetail } = $props();
</script>

<section class="layer" aria-labelledby="layer-diagnosis">
	<h2 id="layer-diagnosis" class="section-title">3 · Diagnosis</h2>
	{#if detail.diagnosis}
		<DiagnosisView diagnosis={detail.diagnosis} />
	{:else}
		<p class="not-yet">{COPY.noDiagnosis}</p>
	{/if}
</section>
