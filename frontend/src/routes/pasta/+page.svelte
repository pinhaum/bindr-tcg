<script lang="ts">
	import { page } from '$app/state';
	import { api } from '../../lib/api/index';
	import { createLoader } from '../../lib/api/loader.svelte';
	import type { ProgressPayload } from '../../lib/api/types';
	import Button from '../../lib/components/Button.svelte';
	import DeckShortfall from '../../lib/components/DeckShortfall.svelte';
	import PastaSummary from '../../lib/components/PastaSummary.svelte';
	import SetProgressRow from '../../lib/components/SetProgressRow.svelte';
	import { appPath } from '../../lib/navigation/nav-entries';
	import { whenSignedIn } from '../../lib/navigation/when-signed-in.svelte';
	import { useAside, wide } from '../../lib/shell.svelte';

	const ORDERS = [
		{ order: 'recent', label: 'Recentes' },
		{ order: 'code', label: 'Por código' }
	] as const;

	const loader = createLoader((key) => api.get<ProgressPayload>(key));

	const result = $derived(loader.state.result);
	const error = $derived(loader.state.error);

	whenSignedIn(() => {
		const order = page.url.searchParams.get('order');
		return order === null ? '/api/progress' : `/api/progress?order=${encodeURIComponent(order)}`;
	}, loader.load);

	useAside(addCards);

	function retry(event: SubmitEvent) {
		event.preventDefault();
		loader.retry();
	}
</script>

<svelte:head><title>Minha pasta — Bindr</title></svelte:head>

{#snippet addCards()}
	<div class={['add', { side: wide.current }]}>
		<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href parte de appPath -->
		<a href={appPath('')}>{wide.current ? 'Adicionar cartas' : 'Adicionar cartas à pasta'}</a>
	</div>
{/snippet}

<h1>Minha pasta</h1>

<section aria-busy={loader.state.slow} class={{ reserve: !wide.current }}>
	{#if loader.state.slow}
		<p class="visually-hidden">Carregando pasta…</p>
	{/if}
	{#if error}
		<form class="message" onsubmit={retry}>
			<p>{error.message}</p>
			<Button>Tentar novamente</Button>
		</form>
	{:else if result}
		<PastaSummary summary={result.summary} />

		<h2 id="progresso-por-set">Progresso por set</h2>
		<ul class="orders" aria-label="Ordenar sets">
			{#each ORDERS as { order, label } (order)}
				<li>
					<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href parte de appPath -->
					<a href={appPath(`/pasta?order=${order}`)} data-sveltekit-reset="false" aria-current={result.order === order ? 'page' : undefined}>{label}</a>
				</li>
			{/each}
		</ul>
		<ul class="sets" aria-labelledby="progresso-por-set">
			{#each result.sets as set (set.code)}
				<li><SetProgressRow {set} /></li>
			{/each}
		</ul>
	{/if}

	<DeckShortfall />

	{#if result && !error}
		<ul class="actions" aria-label="Ações da pasta">
			<li>
				<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- endpoint HTML fora da SPA -->
				<a href="/collection/export" data-sveltekit-reload>Baixar minha coleção (CSV)</a>
			</li>
			<li>
				<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href parte de appPath -->
				<a href={appPath('/pasta/desejos')}>Lista de desejos</a>
			</li>
			<li>
				<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href parte de appPath -->
				<a href={appPath('/pasta/importar')}>Importar coleção</a>
			</li>
		</ul>
	{/if}
</section>

{#if !wide.current}
	{@render addCards()}
{/if}

<style>
	section {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		margin-block-start: var(--space-3);
	}

	section.reserve {
		padding-block-end: calc(var(--touch-target) + var(--space-4));
	}

	h2 {
		margin: 0;
	}

	ul {
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.orders,
	.actions {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}

	.orders a,
	.actions a {
		display: inline-flex;
		align-items: center;
		min-block-size: var(--touch-target);
		padding-inline: var(--space-2);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
		color: var(--ink);
		text-decoration: none;
	}

	.orders a[aria-current='page'] {
		background: var(--accent);
		border-color: var(--accent);
		color: var(--on-accent);
	}

	.sets {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.message {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: var(--space-2);
	}

	.message p {
		margin: 0;
	}

	.add a {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		min-block-size: var(--touch-target);
		padding-inline: var(--space-3);
		border-radius: var(--radius-md);
		background: var(--accent);
		color: var(--on-accent);
		font-weight: 600;
		text-decoration: none;
	}

	.add:not(.side) {
		position: fixed;
		inset-inline: var(--space-3);
		inset-block-end: calc(var(--nav-height) + env(safe-area-inset-bottom) + var(--space-2));
		z-index: var(--z-nav);
		display: flex;
	}

	.add:not(.side) a {
		flex: 1;
	}

	.add.side {
		padding-block-start: var(--space-3);
		border-block-start: 1px solid var(--border);
	}
</style>
