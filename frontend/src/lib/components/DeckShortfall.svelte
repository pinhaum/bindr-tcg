<script lang="ts">
	import { untrack } from 'svelte';
	import { api } from '../api/index';
	import { createLoader } from '../api/loader.svelte';
	import type { ShortfallCard } from '../api/types';
	import { cardDetailHref } from '../cards/url';
	import { deckHref } from '../decks/url';
	import Button from './Button.svelte';

	const loader = createLoader((key) => api.get<ShortfallCard[]>(key));

	const cards = $derived(loader.state.result ?? []);
	const error = $derived(loader.state.error);

	$effect(() => {
		untrack(() => loader.load('/api/decks/shortfall'));
	});

	function retry(event: SubmitEvent) {
		event.preventDefault();
		loader.retry();
	}
</script>

{#if error}
	<form class="message" onsubmit={retry}>
		<p>{error.message}</p>
		<Button>Tentar novamente</Button>
	</form>
{:else if cards.length > 0}
	<section aria-labelledby="deck-shortfall-title">
		<h2 id="deck-shortfall-title">Faltando para os baralhos</h2>
		<ul>
			{#each cards as card (card.card_number)}
				<li>
					<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por cardDetailHref -->
					<a href={cardDetailHref(card.card_number)}>{card.name}</a>
					<code>{card.card_number}</code>
					<span>{card.missing === 1 ? 'falta 1' : `faltam ${card.missing}`}</span>
					<span>
						Em
						{#each card.decks as deck, index (deck.id)}
							{index > 0 ? ', ' : ''}<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por deckHref --><a
								href={deckHref(deck.id)}>{deck.name}</a
							>{/each}
					</span>
				</li>
			{/each}
		</ul>
	</section>
{/if}

<style>
	section,
	.message {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	h2,
	p {
		margin: 0;
	}

	ul {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		margin: 0;
		padding: 0;
		list-style: none;
	}

	li {
		display: flex;
		flex-wrap: wrap;
		align-items: baseline;
		gap: var(--space-1) var(--space-2);
	}

	.message {
		align-items: flex-start;
	}
</style>
