<script lang="ts">
	import { appPath } from '../navigation/nav-entries';

	let { message }: { message: string } = $props();
</script>

<svelte:head><title>Deck não encontrado — Bindr</title></svelte:head>

<h1>{message}</h1>
<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- appPath parte de resolve('/') -->
<a class="back" href={appPath('/baralhos')}>Voltar aos baralhos</a>

<style>
	h1 {
		margin: 0 0 var(--space-3);
	}

	.back {
		display: inline-flex;
		align-items: center;
		box-sizing: border-box;
		min-block-size: var(--touch-target);
		padding-inline: var(--space-3);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
		color: var(--ink);
		font-weight: 600;
		text-decoration: none;
	}
</style>
