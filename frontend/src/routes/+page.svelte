<script lang="ts">
	import { appPath } from '../lib/navigation/nav-entries';
	import { session } from '../lib/session.svelte';
</script>

<svelte:head><title>Bindr</title></svelte:head>

<h1>Bindr</h1>

{#if session.user}
	<p>{session.user.email}</p>
{:else}
	<p>Entre ou crie uma conta para acompanhar sua coleção.</p>
	<ul>
		<li>
			<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- appPath parte de resolve('/') -->
			<a href={appPath('/entrar')}>Entrar</a>
		</li>
		<li>
			<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- appPath parte de resolve('/') -->
			<a href={appPath('/criar-conta')}>Criar conta</a>
		</li>
	</ul>
{/if}

<style>
	ul {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
		margin: 0;
		padding: 0;
		list-style: none;
	}

	a {
		display: inline-flex;
		align-items: center;
		min-block-size: var(--touch-target);
		padding-inline: var(--space-3);
	}
</style>
