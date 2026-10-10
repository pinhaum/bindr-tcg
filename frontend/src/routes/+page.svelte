<script lang="ts">
	import { appPath } from '../lib/navigation/nav-entries';
	import { session } from '../lib/session.svelte';
</script>

<h1>Bindr</h1>

{#if session.user}
	<p>{session.user.email}</p>
{:else}
	<p>Entre ou crie uma conta para acompanhar sua coleção.</p>
	<p>
		<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- appPath parte de resolve('/') -->
		<a href={appPath('/entrar')}>Entrar</a>
		<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- appPath parte de resolve('/') -->
		<a href={appPath('/criar-conta')}>Criar conta</a>
	</p>
{/if}
