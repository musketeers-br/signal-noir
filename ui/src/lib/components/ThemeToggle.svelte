<script lang="ts">
	import { COPY } from '../copy';
	import { theme } from '../stores/theme.svelte';

	const label = $derived(theme.effective === 'dark' ? COPY.themeToLight : COPY.themeToDark);
</script>

<button type="button" class="btn theme-toggle" aria-label={label} title={label} onclick={() => theme.toggle()}>
	{#if theme.effective === 'dark'}
		<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4" /><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" /></svg>
	{:else}
		<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 14.5A8 8 0 019.5 4 8 8 0 1020 14.5z" /></svg>
	{/if}
</button>
