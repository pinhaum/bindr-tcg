<script lang="ts">
	import type { CatalogCard } from '../api/types';
	import { cardDetailHref } from '../cards/url';
	import { isMarked, markCard, morphName } from '../cards/morph.svelte';
	import { copies } from '../format';
	import { isPlainClick } from '../plain-click';

	interface Props {
		card: CatalogCard;
		signedIn: boolean;
	}

	let { card, signedIn }: Props = $props();

	const imageUrl = $derived(card.variants[0]?.image_url ?? null);
	const quantity = $derived(card.variants.reduce((sum, v) => sum + (v.owned_quantity ?? 0), 0));
	const transitionName = $derived(isMarked(card.card_number) ? morphName(card.card_number) : undefined);
	const rarity = $derived(
		card.variants.length > 1 ? `${card.variants.length} impressões` : (card.variants[0]?.rarity ?? '')
	);

	function onclick(event: MouseEvent) {
		if (isPlainClick(event)) markCard(card.card_number);
	}
</script>

<li class="tile">
	<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por cardDetailHref -->
	<a class="link" href={cardDetailHref(card.card_number)} {onclick}>
		<div class="art" style:view-transition-name={transitionName}>
			<div class="placeholder" aria-hidden="true">
				<span class="placeholder-name">{card.name}</span>
				<span class="placeholder-number">{card.card_number}</span>
			</div>

			{#if imageUrl}
				<img class="image" src={imageUrl} alt="" loading="lazy" />
			{/if}
		</div>

		<span class="name">{card.name}</span>
		<span class="number-line">
			<span class="number">{card.card_number}</span>
			<span class="rarity">{rarity}</span>
		</span>

		{#if signedIn && quantity > 0}
			<span class="badge" role="img" aria-label={copies(quantity)}>
				{quantity}
			</span>
		{/if}
	</a>
</li>

<style>
	.tile {
		max-inline-size: 100%;
		padding: var(--space-3);
		background-color: var(--surface-raised);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
		list-style: none;
	}

	.link {
		position: relative;
		display: flex;
		flex-direction: column;
		gap: var(--space-1);
		color: inherit;
		text-decoration: none;
	}

	.art {
		position: relative;
		aspect-ratio: 5 / 7;
		overflow: hidden;
		border-radius: var(--radius-md);
		background: var(--surface-sunken);
	}

	.image,
	.placeholder {
		position: absolute;
		inset: 0;
		inline-size: 100%;
		block-size: 100%;
		max-inline-size: 100%;
	}

	.image {
		object-fit: cover;
	}

	.placeholder {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: var(--space-1);
		padding: var(--space-2);
		box-sizing: border-box;
		text-align: center;
		font-size: var(--caption-size);
		line-height: var(--caption-line-height);
		background-color: var(--surface-sunken);
	}

	.placeholder-number {
		font-variant-numeric: tabular-nums;
		color: var(--ink-muted);
	}

	.placeholder-name {
		font-weight: var(--body-strong-weight);
		overflow-wrap: anywhere;
	}

	.name {
		display: block;
		font-size: var(--body-strong-size);
		line-height: var(--body-strong-line-height);
		font-weight: var(--body-strong-weight);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.number-line {
		display: flex;
		flex-wrap: nowrap;
		align-items: center;
		gap: var(--space-2);
	}

	.number {
		font-family: var(--font-mono);
		font-size: var(--code-size);
		line-height: var(--code-line-height);
		font-weight: var(--code-weight);
		color: var(--ink-muted);
		white-space: nowrap;
	}

	.rarity {
		min-inline-size: 0;
		font-size: var(--caption-size);
		line-height: var(--caption-line-height);
		color: var(--ink-muted);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.badge {
		position: absolute;
		inset-block-start: var(--space-2);
		inset-inline-end: var(--space-2);
		display: flex;
		align-items: center;
		justify-content: center;
		box-sizing: border-box;
		min-inline-size: var(--space-4);
		block-size: var(--space-4);
		padding-inline: var(--space-2);
		border-radius: var(--radius-full);
		background-color: var(--accent);
		color: var(--on-accent);
		font-size: var(--caption-size);
		line-height: var(--caption-line-height);
		font-weight: var(--body-strong-weight);
	}
</style>
