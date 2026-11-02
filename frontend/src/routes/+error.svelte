<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';

	const title = $derived(page.status === 404 ? 'Página não encontrada' : 'Algo deu errado');
</script>

<svelte:head><title>{title} — Bindr</title></svelte:head>

<h1>{title}</h1>
<p><a href={resolve('/')}>Ir para o catálogo</a></p>
