<script lang="ts">
	import type { CardDetailPayload, DetailVariant } from '../api/types';
	import { isMarked, morphName } from '../cards/morph.svelte';
	import { copies } from '../format';
	import { wide } from '../shell.svelte';
	import CardArt from './CardArt.svelte';

	interface Props {
		card: CardDetailPayload;
		featured: DetailVariant | null;
		owned: number;
		signedIn: boolean;
	}

	let { card, featured, owned, signedIn }: Props = $props();

	const typeLabel = $derived(card.card_type.charAt(0).toUpperCase() + card.card_type.slice(1));
	const showCounter = $derived(
		wide.current && card.card_type === 'character' && card.counter !== null
	);
	const imageUrl = $derived(featured?.image_url ?? null);
	const alt = $derived(featured ? `${card.name} ${featured.variant_code}` : card.name);
	const transitionName = $derived(isMarked(card.card_number) ? morphName(card.card_number) : undefined);
	const showBadge = $derived(signedIn && owned > 0);
</script>

{#snippet art(name?: string)}
	<CardArt
		name={card.name}
		cardNumber={card.card_number}
		{imageUrl}
		{alt}
		transitionName={name}
	/>
{/snippet}

{#snippet badge()}
	{#if showBadge}
		<span class="badge" role="img" aria-label={copies(owned)}>{owned}</span>
	{/if}
{/snippet}

<header class={['header', { wide: wide.current }]}>
	{#if wide.current}
		<div class="media">
			{@render art(transitionName)}
			{@render badge()}
		</div>
	{/if}

	<div class="info">
		<div class="title-row">
			{#if !wide.current}
				<div class="thumb">
					{@render art(transitionName)}
					{@render badge()}
				</div>
			{/if}
			<h1>{card.name}</h1>
		</div>

		<ul class="chips">
			<li class="chip">{typeLabel}</li>
			{#if featured?.rarity}<li class="chip">{featured.rarity}</li>{/if}
			{#each card.colors as color (color)}
				<li class="chip">{color}</li>
			{/each}
			{#if showCounter}<li class="chip">Counter {card.counter}</li>{/if}
		</ul>

		{#if featured}
			<p class="set">{featured.set.name} · {featured.set.code}</p>
			{#if !featured.in_source}<p class="status">Variante fora da fonte</p>{/if}
			{#if featured.illustrator}<p class="illustrator">Ilustração: {featured.illustrator}</p>{/if}
		{:else}
			<p class="set">{card.card_number}</p>
		{/if}

		{#if !wide.current}
			<details class="expand">
				<summary>Ver imagem maior</summary>
				{@render art()}
			</details>
		{/if}
	</div>
</header>

<style>
	.header {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.header.wide {
		flex-direction: row;
		align-items: flex-start;
		gap: var(--space-4);
	}

	.media {
		position: relative;
		flex: 0 0 40%;
		max-inline-size: 24rem;
	}

	.info {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		min-inline-size: 0;
	}

	.title-row {
		display: flex;
		align-items: flex-start;
		gap: var(--space-3);
	}

	.thumb {
		position: relative;
		flex: 0 0 5rem;
	}

	h1 {
		margin: 0;
		font-size: var(--display-size);
		line-height: var(--display-line-height);
		font-weight: var(--display-weight);
		overflow-wrap: anywhere;
	}

	.chips {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-1);
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.chip {
		padding: var(--space-1) var(--space-2);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
		font-size: var(--caption-size);
		line-height: var(--caption-line-height);
	}

	.set,
	.status,
	.illustrator {
		margin: 0;
	}

	.set,
	.illustrator {
		color: var(--ink-muted);
	}

	.status {
		font-weight: var(--body-strong-weight);
	}

	.expand summary {
		display: flex;
		align-items: center;
		min-block-size: var(--touch-target);
		cursor: pointer;
	}

	.badge {
		position: absolute;
		inset-block-start: var(--space-1);
		inset-inline-end: var(--space-1);
		min-inline-size: var(--space-4);
		padding-inline: var(--space-1);
		border-radius: var(--radius-full);
		background: var(--accent);
		color: var(--on-accent);
		font-size: var(--caption-size);
		line-height: var(--space-4);
		font-weight: var(--body-strong-weight);
		font-variant-numeric: tabular-nums;
		text-align: center;
	}
</style>
