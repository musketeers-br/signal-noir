<script lang="ts">
	// Moves focus to the evidence card; never opens a modal (UX spine).
	let { id }: { id: string } = $props();

	function jump() {
		const card = document.getElementById(`ev-${id}`);
		if (!card) return;
		const reduce = typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches;
		card.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'center' });
		card.focus();
		card.classList.add('highlight');
		setTimeout(() => card.classList.remove('highlight'), 1600);
	}
</script>

<button type="button" class="ev-chip mono" onclick={jump} aria-label="Go to evidence {id}">{id}</button>
