<script lang="ts">
	import '../lib/styles/tokens.css';
	import '../lib/styles/base.css';
	import { onNavigate, refreshAll } from '$app/navigation';
	import Toaster from '../lib/components/Toaster.svelte';
	import { session } from '../lib/session.svelte';
	import { viewTransitionOnNavigate } from '../lib/view-transition';

	let { children } = $props();

	onNavigate(viewTransitionOnNavigate);
</script>

{#if session.status === 'ready'}
	{@render children()}
{:else if session.status === 'error' && session.error}
	<main>
		<p>{session.error.message}</p>
		<button type="button" onclick={() => refreshAll()}>Tentar novamente</button>
	</main>
{/if}

<Toaster />
