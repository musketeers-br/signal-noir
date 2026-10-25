<script lang="ts">
	import { toasts } from '../stores/toasts.svelte';
</script>

<div class="toasts" aria-live="polite">
	{#each toasts.items as t (t.id)}
		<div class="toast tone-{t.tone}" data-tone={t.tone}>{t.text} <button type="button" class="btn-link" onclick={() => toasts.dismiss(t.id)} aria-label="Dismiss">×</button></div>
	{/each}
</div>
