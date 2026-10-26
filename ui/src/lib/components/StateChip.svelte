<script lang="ts">
	import type { CaseState, ExecutionOutcome } from '../api/types';
	import { stateCopy } from '../copy';

	let { state, outcome = null }: { state: CaseState; outcome?: ExecutionOutcome | null } = $props();
	const copy = $derived(stateCopy(state, outcome));
</script>

<span class="chip tone-{copy.tone}" data-state={state}><span aria-hidden="true">{copy.glyph}</span> {copy.label}</span>
