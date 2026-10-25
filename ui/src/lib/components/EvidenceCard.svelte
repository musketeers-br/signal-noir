<script lang="ts">
	import type { Evidence } from '../api/types';
	import { brt, ms } from '../format';

	let { ev }: { ev: Evidence } = $props();

	function entries(value: unknown): [string, string][] {
		if (value === null || value === undefined) return [['result', 'null']];
		if (typeof value !== 'object') return [['result', String(value)]];
		return Object.entries(value as Record<string, unknown>).map(([k, v]) => [k, typeof v === 'object' && v !== null ? JSON.stringify(v) : String(v)]);
	}
</script>

<article id="ev-{ev.evidenceId}" class="evidence-card" class:obsolete={!!ev.obsoletedBy} tabindex="-1" aria-labelledby="ev-title-{ev.evidenceId}">
	<header class="ev-head">
		<span class="overline fact">FACT</span>
		<h4 id="ev-title-{ev.evidenceId}" class="mono">{ev.source}</h4>
		<span class="mono small muted">{ev.evidenceId}</span>
		{#if ev.suspicious}<span class="tag tag-danger">Embedded instruction blocked</span>{/if}
		{#if ev.obsoletedBy}<span class="tag tag-muted">Obsoleted by <span class="mono">{ev.obsoletedBy}</span></span>{/if}
	</header>
	<p class="small muted">{brt(ev.observedAt)} · {ms(ev.durationMs)}{#if ev.calledBy} · called by {ev.calledBy}{/if}</p>
	{#if ev.params && Object.keys(ev.params).length}
		<p class="small"><span class="muted">Query</span> <code>{JSON.stringify(ev.params)}</code></p>
	{/if}
	<dl class="kv">
		{#each entries(ev.result) as [k, v] (k)}
			<dt class="mono">{k}</dt>
			<dd class="mono">{v}</dd>
		{/each}
	</dl>
	{#if ev.suspiciousExcerpts?.length}
		<p class="small">Treated as data, never as an instruction:</p>
		<ul class="small mono">{#each ev.suspiciousExcerpts as x, i (i)}<li>{x}</li>{/each}</ul>
	{/if}
</article>
