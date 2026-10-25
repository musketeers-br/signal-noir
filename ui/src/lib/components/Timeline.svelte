<script lang="ts">
	import type { TimelineEvent } from '../api/types';
	import { brt } from '../format';

	let { events }: { events: TimelineEvent[] } = $props();
	const newestFirst = $derived([...events].sort((a, b) => b.seq - a.seq));

	function summary(e: TimelineEvent): string {
		const p = e.payload ?? {};
		if (e.type === 'StateChanged' && p.from) return `${p.from} → ${p.to}${p.reason ? ` · ${p.reason}` : ''}`;
		if (typeof p.reason === 'string') return p.reason;
		if (typeof p.kind === 'string') return p.kind;
		return e.refId ?? '';
	}
</script>

<section class="timeline" aria-labelledby="timeline-title">
	<h2 id="timeline-title" class="section-title">Timeline</h2>
	<ol reversed>
		{#each newestFirst as e (e.seq)}
			<li><span class="mono small muted">#{e.seq}</span> <strong>{e.type}</strong> · <span class="small">{e.actor}</span><br /><span class="small muted">{brt(e.at)}</span> <span class="small">{summary(e)}</span></li>
		{/each}
	</ol>
</section>
