<script lang="ts">
	import { page } from '$app/state';
	import { api } from '../api';
	import type { DetailVariant, OwnershipResult } from '../api/types';
	import type { OwnershipOp } from '../cards/ownership-queue.svelte';
	import { cardDetailHref, variantApiPath } from '../cards/url';
	import { formatObservedDate, formatPrice } from '../format';
	import { appPath } from '../navigation/nav-entries';
	import { safeReturnTo } from '../navigation/return-to';
	import { isPlainClick } from '../plain-click';
	import OwnershipStepper from './OwnershipStepper.svelte';
	import WishlistForm from './WishlistForm.svelte';

	interface Props {
		card: { card_number: string; name: string };
		variant: DetailVariant;
		featured: boolean;
		signedIn: boolean;
		onSelect: (variantCode: string) => void;
		displayed?: number;
	}

	const ART_LABELS: Record<string, string> = { base: 'arte base', parallel: 'parallel' };

	let { card, variant, featured, signedIn, onSelect, displayed = $bindable() }: Props = $props();

	let failedUrl = $state<string | null>(null);
	const showImage = $derived(variant.image_url !== null && variant.image_url !== failedUrl);

	const kindText = $derived(
		variant.rarity ? `${variant.rarity} · ${ART_LABELS[variant.art_kind] ?? 'alternativa'}` : null
	);
	const loginHref = $derived(
		`${appPath('/entrar')}?return_to=${encodeURIComponent(safeReturnTo(page.url.pathname + page.url.search))}`
	);

	function select(event: MouseEvent) {
		if (!isPlainClick(event)) return;
		event.preventDefault();
		onSelect(variant.variant_code);
	}

	const send = (op: OwnershipOp) =>
		api
			.post<OwnershipResult>(variantApiPath(card.card_number, variant.variant_code, op))
			.then((result) => result.owned_quantity);
</script>

<li class="row">
	<!-- eslint-disable svelte/no-navigation-without-resolve -- href já vem de resolve('/') em nav-entries -->
	<a
		class="thumb"
		href={cardDetailHref(card.card_number, variant.variant_code)}
		aria-label="Mostrar {variant.variant_code} na imagem principal"
		aria-current={featured ? 'true' : undefined}
		data-sveltekit-reload="off"
		onclick={select}
	>
		<span class="placeholder" aria-hidden="true">
			<span class="placeholder-name">{card.name}</span>
			<span class="placeholder-number">{card.card_number}</span>
		</span>
		{#if showImage}
			<img
				class="image"
				src={variant.image_url}
				alt=""
				loading="lazy"
				onerror={() => (failedUrl = variant.image_url)}
			/>
		{/if}
	</a>
	<!-- eslint-enable svelte/no-navigation-without-resolve -->

	<div class="info">
		<p class="code"><code>{variant.variant_code}</code></p>
		{#if kindText}<p class="meta">{kindText}</p>{/if}
		<p class="meta">{variant.set.name} ({variant.set.code})</p>
		{#if !variant.in_source}<p class="meta">fora da fonte</p>{/if}
		<p class="price">
			{#if variant.price}
				<strong>{formatPrice(variant.price.amount, variant.price.currency)}</strong>
				<span class="meta">TCGplayer · market · {formatObservedDate(variant.price.observed_at)}</span>
			{:else}
				<span class="meta">Sem preço</span>
			{/if}
		</p>
	</div>

	<div class="actions">
		{#if signedIn}
			<OwnershipStepper
				name={card.name}
				variantCode={variant.variant_code}
				confirmed={variant.owned_quantity ?? 0}
				{send}
				bind:displayed
			/>
			<WishlistForm
				cardNumber={card.card_number}
				cardName={card.name}
				variantCode={variant.variant_code}
				target={variant.wishlist_target}
			/>
		{:else}
			<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- loginHref parte de appPath -->
			<a class="login" href={loginHref}>Entrar para registrar posse</a>
		{/if}
	</div>
</li>

<style>
	.row {
		display: grid;
		grid-template-columns: 5rem 1fr;
		gap: var(--space-2) var(--space-3);
		align-items: start;
		padding-block: var(--space-3);
		border-block-end: 1px solid var(--border);
		list-style: none;
	}

	.thumb {
		position: relative;
		display: block;
		aspect-ratio: 5 / 7;
		overflow: hidden;
		border-radius: var(--radius-sm);
		background: var(--surface-sunken);
		color: inherit;
	}

	.thumb[aria-current='true'] {
		outline: 2px solid var(--ink);
		outline-offset: 2px;
	}

	.thumb[aria-current='true']:focus-visible {
		outline-color: var(--accent);
		outline-offset: var(--space-2);
	}

	.image,
	.placeholder {
		position: absolute;
		inset: 0;
		inline-size: 100%;
		block-size: 100%;
	}

	.image {
		object-fit: cover;
	}

	.placeholder {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		box-sizing: border-box;
		padding: var(--space-1);
		text-align: center;
		font-size: var(--caption-size);
		line-height: var(--caption-line-height);
	}

	.placeholder-name {
		font-weight: var(--body-strong-weight);
		overflow-wrap: anywhere;
	}

	.placeholder-number {
		color: var(--ink-muted);
	}

	.info p {
		margin: 0;
	}

	.meta {
		color: var(--ink-muted);
		font-size: var(--caption-size);
		line-height: var(--caption-line-height);
	}

	.price {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-1) var(--space-2);
		align-items: baseline;
		margin-block-start: var(--space-1);
	}

	.actions {
		grid-column: 1 / -1;
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-2) var(--space-4);
	}

	.login {
		display: inline-flex;
		align-items: center;
		min-block-size: var(--touch-target);
		color: var(--ink);
	}
</style>
