<script lang="ts">
	import '../lib/styles/tokens.css';
	import '../lib/styles/base.css';
	import { afterNavigate, onNavigate, refreshAll } from '$app/navigation';
	import AppShell from '../lib/components/AppShell.svelte';
	import Button from '../lib/components/Button.svelte';
	import Toaster from '../lib/components/Toaster.svelte';
	import { session } from '../lib/session.svelte';
	import { viewTransitionOnNavigate } from '../lib/view-transition';

	let { children } = $props();

	onNavigate(viewTransitionOnNavigate);

	afterNavigate((navigation) => {
		if (navigation.type === 'enter') return;
		const main = document.getElementById('conteudo');
		const active = document.activeElement;
		if (!main || (active && active !== document.body && main.contains(active))) return;
		main.focus();
	});
</script>

<svelte:head>
	{#if session.status === 'error' && session.error}
		<title>Erro — Bindr</title>
	{/if}
</svelte:head>

{#if session.status === 'ready'}
	<AppShell {children} />
{:else if session.status === 'error' && session.error}
	<main id="conteudo" tabindex="-1">
		<h1>Erro</h1>
		<p role="alert">{session.error.message}</p>
		<form
			onsubmit={(event) => {
				event.preventDefault();
				refreshAll();
			}}
		>
			<Button>Tentar novamente</Button>
		</form>
	</main>
{:else}
	<p role="status">Carregando…</p>
{/if}

<Toaster />
