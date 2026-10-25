<script lang="ts">
	import type { Labels } from '../api/types';
	import { COPY } from '../copy';

	let { labels }: { labels: Labels } = $props();
</script>

<span class="tag">{COPY.synthetic}</span>{#if labels?.replay}<span class="tag tag-replay">{COPY.replay}</span>{/if}
