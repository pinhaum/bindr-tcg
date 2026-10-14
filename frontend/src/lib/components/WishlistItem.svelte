<script lang="ts">
	import { cardDetailHref } from '../cards/url';
	import { copies } from '../format';

	interface Props {
		cardNumber: string;
		cardName: string;
		variantCode: string;
		targetQuantity: number;
		ownedQuantity: number;
		pending?: boolean;
		onremove: () => void;
	}

	let {
		cardNumber,
		cardName,
		variantCode,
		targetQuantity,
		ownedQuantity,
		pending = false,
		onremove
	}: Props = $props();

	let button: HTMLButtonElement | undefined = $state();

	const missing = $derived(Math.max(targetQuantity - ownedQuantity, 0));
	const fulfilled = $derived(missing === 0);
	const status = $derived(fulfilled ? 'Atendido' : `Faltam ${missing}`);

	export function focus() {
		button?.focus();
	}
</script>

<div class="item">
	<div class="identity">
		<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por cardDetailHref -->
		<a href={cardDetailHref(cardNumber)}>{cardName} <code>{variantCode}</code></a>
	</div>
	<p class="quantity">{ownedQuantity} de {copies(targetQuantity)}</p>
	<p class={['status', { fulfilled }]}>{status}</p>
	<button
		bind:this={button}
		type="button"
		disabled={pending}
		aria-label="Remover {cardName} {variantCode} da lista de desejos ({fulfilled
			? 'atendido'
			: `faltam ${missing}`})"
		onclick={onremove}
	>
		Remover
	</button>
</div>

<style>
	.item {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-2) var(--space-3);
	}

	.identity {
		display: flex;
		flex-wrap: wrap;
		align-items: baseline;
		gap: var(--space-2);
		flex: 1 1 auto;
	}

	.quantity,
	.status {
		margin: 0;
	}

	.status {
		color: var(--ink-muted);
	}

	.status.fulfilled {
		color: var(--ink);
		font-weight: 600;
	}

	button {
		min-block-size: var(--touch-target);
		min-inline-size: var(--touch-target);
		padding-inline: var(--space-3);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
		background: transparent;
		color: var(--ink);
		font: inherit;
		font-weight: 600;
		cursor: pointer;
	}

	button:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
</style>
