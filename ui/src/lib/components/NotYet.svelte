<script lang="ts">
	import { COPY } from '../copy';
	let { text = COPY.notYet }: { text?: string } = $props();
</script>

<p class="not-yet">{text}</p>
