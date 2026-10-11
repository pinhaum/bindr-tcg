<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { tick, untrack } from 'svelte';
	import { api } from '../lib/api/index';
	import type { CatalogCard, CatalogMeta } from '../lib/api/types';
	import { createCatalogLoader } from '../lib/catalog/catalog.svelte';
	import { clearHref, filterChips, searchHref } from '../lib/catalog/url';
	import ActiveFilters from '../lib/components/ActiveFilters.svelte';
	import Button from '../lib/components/Button.svelte';
	import CardTile from '../lib/components/CardTile.svelte';
	import CardTileSkeleton from '../lib/components/CardTileSkeleton.svelte';
	import CatalogPagination from '../lib/components/CatalogPagination.svelte';
	import CatalogSearch from '../lib/components/CatalogSearch.svelte';
	import CatalogStatus, { statusSentence } from '../lib/components/CatalogStatus.svelte';
	import { appPath } from '../lib/navigation/nav-entries';
	import { safeReturnTo } from '../lib/navigation/return-to';
	import { session } from '../lib/session.svelte';

	const SKELETON_TILES = Array.from({ length: 10 }, (_, index) => index);

	const loader = createCatalogLoader((path) => api.getEnvelope<CatalogCard[], CatalogMeta>(path));

	const result = $derived(loader.state.result);
	const error = $derived(loader.state.error);
	const filters = $derived(result?.meta.active_filters ?? {});
	const chips = $derived(filterChips(filters));
	const hasCards = $derived((result?.data.length ?? 0) > 0);
	const clearLink = $derived(clearHref(filters));
	const signInHref = $derived(
		session.user
			? undefined
			: `${appPath('/entrar')}?return_to=${encodeURIComponent(safeReturnTo(page.url.pathname + page.url.search))}`
	);

	let announcement = $state('');

	const announcementText = () =>
		error
			? error.message
			: result
				? statusSentence(result.meta.total_count, chips.length)
				: '';

	$effect(() => {
		void session.user?.email;
		const search = page.url.search;
		untrack(() => loader.load(search));
	});

	$effect(() => {
		if (loader.state.seq === 0) return;
		const text = untrack(announcementText);
		let current = true;
		announcement = '';
		tick().then(() => {
			if (current) announcement = text;
		});
		return () => {
			current = false;
		};
	});

	function search(term: string) {
		// eslint-disable-next-line svelte/no-navigation-without-resolve -- searchHref parte de appPath
		void goto(searchHref(filters, term), { reset: false });
	}

	function retry(event: SubmitEvent) {
		event.preventDefault();
		loader.retry();
	}
</script>

<svelte:head><title>Catálogo — Bindr</title></svelte:head>

<h1>Catálogo</h1>

<div class="toolbar">
	<CatalogSearch value={filters.q ?? ''} onsearch={search} />
	{#if result && !error}
		<CatalogStatus
			total={result.meta.total_count}
			chipCount={chips.length}
			clearHref={chips.length > 0 && hasCards ? clearLink : undefined}
			{signInHref}
		/>
	{/if}
</div>

<ActiveFilters {chips} onremove={() => {}} />

<section aria-busy={loader.state.skeleton}>
	{#if loader.state.skeleton}
		<p class="visually-hidden">Carregando cartas…</p>
		<ul class="grid">
			{#each SKELETON_TILES as tile (tile)}
				<CardTileSkeleton />
			{/each}
		</ul>
	{:else if error}
		<form class="message" onsubmit={retry}>
			<p>{error.message}</p>
			<Button>Tentar novamente</Button>
		</form>
	{:else if result && !hasCards}
		<div class="message">
			<p>
				{#if filters.q}
					Nenhuma carta encontrada para <strong>{filters.q}</strong>.
				{:else}
					Nenhuma carta corresponde aos filtros aplicados.
				{/if}
			</p>
			{#if chips.length > 0}
				<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- clearHref parte de appPath -->
				<a href={clearLink} data-sveltekit-reset="false">Limpar filtros</a>
			{/if}
		</div>
		<CatalogPagination meta={result.meta} onpage={() => {}} />
	{:else if result}
		<ul class="grid">
			{#each result.data as card (card.card_number)}
				<CardTile {card} signedIn={session.user !== null} />
			{/each}
		</ul>
		<CatalogPagination meta={result.meta} onpage={() => {}} />
	{/if}
</section>

<p class="visually-hidden" role="status">{announcement}</p>

<style>
	.toolbar {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		margin-block-end: var(--space-3);
	}

	section {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		margin-block-start: var(--space-3);
	}

	.grid {
		display: grid;
		grid-template-columns: repeat(2, minmax(0, 1fr));
		gap: var(--space-3);
		margin: 0;
		padding: 0;
		list-style: none;
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

	.message a {
		display: inline-flex;
		align-items: center;
		min-block-size: var(--touch-target);
		color: var(--accent);
	}

	@media (min-width: 64rem) {
		.toolbar {
			flex-direction: row;
			align-items: flex-end;
			justify-content: space-between;
		}

		.grid {
			grid-template-columns: repeat(5, minmax(0, 1fr));
		}
	}
</style>
