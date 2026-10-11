<script lang="ts">
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import type { ActiveFilters } from '../api/types';
	import { ensureFilterOptions, filterOptions, retryFilterOptions } from '../catalog/filter-options.svelte';
	import { FILTER_LABELS, setHref, toggleHref } from '../catalog/url';
	import Button from './Button.svelte';
	import FilterChip from './FilterChip.svelte';

	interface Props {
		filters: ActiveFilters;
		signedIn: boolean;
	}

	let { filters, signedIn }: Props = $props();

	const KEEP = '__keep__';

	const capitalize = (value: string) => value.charAt(0).toUpperCase() + value.slice(1).toLowerCase();
	const asIs = (value: string) => value;

	const groups = $derived([
		{ key: 'colors', swatch: true, show: asIs, values: filterOptions.value?.colors },
		{ key: 'card_types', swatch: false, show: capitalize, values: filterOptions.value?.card_types },
		{ key: 'rarities', swatch: false, show: asIs, values: filterOptions.value?.rarities }
	] as const);

	const ownedChips = [
		{ value: 'owned', label: 'Tenho' },
		{ value: 'missing', label: 'Não tenho' }
	] as const;

	const activeSets = $derived(filters.sets ?? []);
	const multipleSets = $derived(activeSets.length > 1);
	let chosenSet = $derived(multipleSets ? KEEP : (activeSets[0] ?? ''));

	const unknownSet = $derived(
		!multipleSets &&
			activeSets[0] &&
			!filterOptions.value?.sets.some((set) => set.code === activeSets[0])
			? activeSets[0]
			: null
	);

	onMount(ensureFilterOptions);

	function applySet(event: SubmitEvent) {
		event.preventDefault();
		// eslint-disable-next-line svelte/no-navigation-without-resolve -- setHref já devolve o caminho resolvido
		void goto(setHref(filters, chosenSet === KEEP ? null : chosenSet), { reset: false });
	}

	function retry(event: SubmitEvent) {
		event.preventDefault();
		retryFilterOptions();
	}
</script>

<div class="panel">
	{#if filterOptions.error}
		<form class="failure" onsubmit={retry}>
			<p role="alert">{filterOptions.error.message}</p>
			<Button variant="secondary">Tentar novamente</Button>
		</form>
	{:else if !filterOptions.value}
		<p role="status">Carregando filtros…</p>
	{:else}
		{#each groups as { key, swatch, show, values } (key)}
			<div role="group" aria-labelledby="filter-{key}" class="group">
				<h3 id="filter-{key}">{FILTER_LABELS[key]}</h3>
				<div class="chips">
					{#each values ?? [] as value (value)}
						<FilterChip
							href={toggleHref(filters, key, value)}
							label={show(value)}
							active={(filters[key] ?? []).includes(value)}
							{swatch}
							removeName="Remover filtro {FILTER_LABELS[key]}: {show(value)}"
						/>
					{/each}
				</div>
			</div>
		{/each}

		<form class="group" onsubmit={applySet}>
			<label for="filter-set">Set</label>
			<div class="row">
				<select id="filter-set" bind:value={chosenSet}>
					{#if multipleSets}
						<option value={KEEP}>{activeSets.length} sets selecionados</option>
					{/if}
					<option value="">Todos os sets</option>
					{#if unknownSet}
						<option value={unknownSet}>{unknownSet}</option>
					{/if}
					{#each filterOptions.value.sets as set (set.code)}
						<option value={set.code}>{set.name}</option>
					{/each}
				</select>
				<Button>Aplicar</Button>
			</div>
		</form>

		{#if signedIn}
			<div role="group" aria-labelledby="filter-owned" class="group">
				<h3 id="filter-owned">{FILTER_LABELS.owned}</h3>
				<div class="chips">
					<FilterChip
						href={toggleHref(filters, 'owned', 'all')}
						label="Todas"
						active={false}
						current={!filters.owned}
					/>
					{#each ownedChips as { value, label } (value)}
						<FilterChip
							href={toggleHref(filters, 'owned', value)}
							{label}
							active={filters.owned === value}
							removeName="Remover filtro {FILTER_LABELS.owned}: {label}"
						/>
					{/each}
				</div>
			</div>
		{/if}
	{/if}
</div>

<style>
	.panel {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
	}

	.group {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		margin: 0;
		padding: 0;
		border: 0;
	}

	h3 {
		margin: 0;
		color: var(--ink);
		font-size: inherit;
		font-weight: 600;
	}

	label {
		color: var(--ink);
		font-weight: 600;
	}

	.chips,
	.row {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}

	.row {
		flex-wrap: nowrap;
	}

	select {
		box-sizing: border-box;
		flex: 1;
		min-inline-size: 0;
		min-block-size: var(--touch-target);
		padding-inline: var(--space-3);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
		background: var(--surface-sunken);
		color: var(--ink);
		font: inherit;
	}

	.failure {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: var(--space-2);
	}

	.failure p {
		margin: 0;
	}
</style>
