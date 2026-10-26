<script lang="ts">
	import Shell from '../lib/components/Shell.svelte';
	import { setTransport } from '../lib/api/client';
	import { fetchTransport } from '../lib/api/transport';

	// `npm run dev:mock` answers from contracts/fixtures instead of the IRIS API.
	let ready = $state(false);
	if (import.meta.env.VITE_SN_MOCK) {
		import('../lib/api/fixtures').then(({ FixtureServer }) => {
			setTransport(new FixtureServer());
			ready = true;
		});
	} else {
		setTransport(fetchTransport());
		ready = true;
	}
</script>

{#if ready}<Shell />{/if}
