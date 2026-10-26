<script lang="ts">
	import { COPY } from '../copy';
	import { connection } from '../stores/connection.svelte';
</script>

{#if connection.stale}
	<p class="connection-note" role="status">{COPY.connectionLost}</p>
{/if}
