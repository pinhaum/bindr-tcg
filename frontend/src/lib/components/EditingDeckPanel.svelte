<script lang="ts">
	import { tick } from 'svelte';
	import { api } from '../api';
	import { ApiError } from '../api/errors';
	import type { EditingDeck } from '../api/types';
	import type { OwnershipOp } from '../cards/ownership-queue.svelte';
	import { deckApiPath, deckCardApiPath, deckHref } from '../decks/url';
	import { copies } from '../format';
	import { notifyError, notifySuccess } from '../toasts.svelte';
	import Button from './Button.svelte';
	import QuantityStepper from './QuantityStepper.svelte';

	interface Props {
		deck: EditingDeck;
		cardNumber: string;
		name: string;
		cardType: string;
	}

	const UNEXPECTED_ERROR = 'Algo deu errado. Tente novamente.';

	let { deck, cardNumber, name, cardType }: Props = $props();

	let promoted = $state(false);
	let pending = $state(false);
	let leaderButton: HTMLButtonElement | undefined = $state();

	const isLeaderCard = $derived(cardType === 'leader');
	const isCurrentLeader = $derived(deck.is_leader || promoted);

	const send = (op: OwnershipOp) =>
		api.post<{ quantity: number }>(deckCardApiPath(deck.id, cardNumber, op)).then((r) => r.quantity);

	async function useAsLeader(event: SubmitEvent) {
		event.preventDefault();
		if (pending) return;
		pending = true;
		try {
			await api.put(deckApiPath(deck.id, 'leader'), { card_number: cardNumber });
			promoted = true;
			notifySuccess(`${cardNumber} é o Leader do deck “${deck.name}”.`);
		} catch (error) {
			notifyError(error instanceof ApiError ? error.message : UNEXPECTED_ERROR);
		} finally {
			pending = false;
		}
		if (promoted) {
			await tick();
			leaderButton?.focus();
		}
	}
</script>

<section class="deck-panel" aria-labelledby="deck-panel-title">
	<h2 id="deck-panel-title">Deck em edição</h2>
	<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- deckHref parte de resolve('/') -->
	<p>As cartas vão para o deck <a href={deckHref(deck.id)}>{deck.name}</a></p>

	{#if !isLeaderCard}
		<QuantityStepper
			confirmed={deck.quantity}
			{send}
			decrementLabel="Remover uma cópia de {name} do deck {deck.name}"
			incrementLabel="Adicionar uma cópia de {name} ao deck {deck.name}"
			refusedMessage="{cardNumber} não está no deck “{deck.name}”."
			quantityText={(quantity) => `${copies(quantity)} de ${name} no deck`}
			settledText={(quantity) => `${copies(quantity)} de ${name} no deck`}
		/>
	{:else if isCurrentLeader}
		<button bind:this={leaderButton} type="button" class="current" aria-disabled="true">
			{name} é o Leader deste deck
		</button>
	{:else}
		<form onsubmit={useAsLeader}>
			<Button {pending}>
				<span aria-hidden="true">Usar como Leader</span>
				<span class="visually-hidden">Usar {name} como Leader do deck {deck.name}</span>
			</Button>
		</form>
	{/if}
</section>

<style>
	.deck-panel {
		display: grid;
		gap: var(--space-2);
	}

	h2,
	p {
		margin: 0;
	}

	.current {
		justify-self: start;
		min-block-size: var(--touch-target);
		min-inline-size: var(--touch-target);
		padding-inline: var(--space-3);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
		background: transparent;
		color: var(--ink);
		font: inherit;
		font-weight: 600;
		opacity: 0.8;
		cursor: default;
	}
</style>
