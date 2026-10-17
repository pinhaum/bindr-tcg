<script lang="ts">
	import { page } from '$app/state';
	import { ApiError } from '../../../lib/api/errors';
	import { api } from '../../../lib/api/index';
	import { createLoader } from '../../../lib/api/loader.svelte';
	import type { DeckLine, DeckPayload } from '../../../lib/api/types';
	import { cardDetailHref } from '../../../lib/cards/url';
	import Button from '../../../lib/components/Button.svelte';
	import DeckNotFound from '../../../lib/components/DeckNotFound.svelte';
	import { groupEntries, groupLabel, missingSentence, statusLabel } from '../../../lib/decks/labels';
	import { deckApiPath, deckHref } from '../../../lib/decks/url';
	import { appPath } from '../../../lib/navigation/nav-entries';
	import { whenSignedIn } from '../../../lib/navigation/when-signed-in.svelte';

	const loader = createLoader((key) => api.get<DeckPayload>(key));

	const id = $derived(Number(page.params.id));
	const error = $derived(loader.state.error);
	const notFound = $derived(error?.code === 'not_found' ? error : null);
	// Enquanto a resposta do id atual não chega, o deck de outro id não aparece.
	const deck = $derived(loader.state.result?.id === id ? loader.state.result : null);

	// `seq` da resposta em que "Editar este deck" deu certo; uma resposta nova volta à verdade do servidor.
	let selectedAt = $state<number | null>(null);
	let selecting = $state(false);
	let selectError = $state<string | null>(null);
	const editing = $derived(deck !== null && (deck.editing || selectedAt === loader.state.seq));

	whenSignedIn(
		() => (Number.isNaN(id) ? null : deckApiPath(id)),
		(key) => {
			selectError = null;
			loader.load(key);
		}
	);

	function retry(event: SubmitEvent) {
		event.preventDefault();
		loader.retry();
	}

	async function select(event: SubmitEvent) {
		event.preventDefault();
		if (selecting || !deck) return;
		const forSeq = loader.state.seq;
		selecting = true;
		selectError = null;
		try {
			await api.post(deckApiPath(deck.id, 'select'), {});
			selectedAt = forSeq;
		} catch (failure) {
			if (!(failure instanceof ApiError)) throw failure;
			selectError = failure.message;
		} finally {
			selecting = false;
		}
	}

	const title = $derived(
		notFound ? 'Deck não encontrado — Bindr' : deck ? `${deck.name} — Bindr` : 'Deck — Bindr'
	);
</script>

{#snippet counts(line: DeckLine)}
	<span class="counts">pedida {line.required}, possuída {line.owned}, falta {line.missing}</span>
{/snippet}

<svelte:head><title>{title}</title></svelte:head>

{#if notFound}
	<DeckNotFound message={notFound.message} />
{:else}
	<div class="deck" aria-busy={loader.state.slow}>
		{#if loader.state.slow && !deck}
			<p class="visually-hidden">Carregando deck…</p>
		{/if}

		{#if error}
			<form class="message" onsubmit={retry}>
				<p>{error.message}</p>
				<Button>Tentar novamente</Button>
			</form>
		{:else if deck}
			<h1>{deck.name}</h1>

			{#if editing}
				<p class="editing">Em edição</p>
			{:else}
				<form onsubmit={select}>
					<Button pending={selecting}>Editar este deck</Button>
				</form>
			{/if}
			<p role="status">
				{#if selectedAt === loader.state.seq}Agora as cartas vão para o deck “{deck.name}”.{/if}
			</p>
			{#if selectError}
				<p role="alert">{selectError}</p>
			{/if}

			<section aria-labelledby="deck-status-title">
				<h2 id="deck-status-title">Status: {statusLabel(deck.status)}</h2>
				{#if deck.status !== 'valid'}
					<ul>
						{#each deck.reasons as reason (reason)}
							<li>{reason}</li>
						{/each}
					</ul>
				{/if}
				{#each deck.warnings as rule (rule)}
					<div class="warning">
						<p><strong>Este Leader tem regra de montagem própria, não verificada</strong></p>
						<blockquote><p>{rule}</p></blockquote>
					</div>
				{/each}
				<p>A lista de banidas não é verificada</p>
			</section>

			<section aria-labelledby="deck-shortfall-title">
				<h2 id="deck-shortfall-title">Na sua pasta</h2>
				<p>{missingSentence(deck)}</p>
			</section>

			<section aria-labelledby="deck-leader-title">
				<h2 id="deck-leader-title">Leader</h2>
				{#if deck.leader}
					<p class="entry">
						<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por cardDetailHref -->
						<a href={cardDetailHref(deck.leader.card_number)}
							>{deck.leader.name} ({deck.leader.card_number})</a
						>
						{#if !deck.leader.in_source}<span>carta fora da fonte</span>{/if}
						{@render counts(deck.leader)}
					</p>
				{:else}
					<p>Sem Leader</p>
				{/if}
			</section>

			<section aria-labelledby="deck-main-title">
				<h2 id="deck-main-title">Deck principal: {deck.main_total} / 50</h2>
				{#each groupEntries(deck.entries) as group (group.cardType)}
					<section class="group">
						<h3>{groupLabel(group.cardType)}</h3>
						<ul>
							{#each group.entries as entry (entry.card_number)}
								<li class="entry">
									<span class="quantity">{entry.quantity}×</span>
									<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por cardDetailHref -->
									<a href={cardDetailHref(entry.card_number)}>{entry.name} ({entry.card_number})</a>
									{#if entry.cost !== null}<span>custo {entry.cost}</span>{/if}
									{#if !entry.in_source}<span>carta fora da fonte</span>{/if}
									{@render counts(entry)}
								</li>
							{/each}
						</ul>
					</section>
				{/each}
			</section>

			<p class="actions">
				<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- arquivo do Rails fora da SPA, com recarga -->
				<a href="/decks/{deck.id}.txt" data-sveltekit-reload>Exportar lista</a>
				<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por deckHref -->
				<a href={deckHref(deck.id, 'renomear')}>Renomear</a>
				<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por deckHref -->
				<a href={deckHref(deck.id, 'excluir')}>Excluir</a>
				<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por appPath -->
				<a href={appPath('/baralhos')}>Voltar aos baralhos</a>
			</p>
		{/if}
	</div>
{/if}

<style>
	.deck {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	h1,
	h2,
	h3,
	p,
	ul,
	blockquote {
		margin: 0;
	}

	ul {
		padding: 0;
		list-style: none;
	}

	section {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
	}

	.entry {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-1) var(--space-2);
		align-items: baseline;
	}

	.counts,
	.quantity {
		color: var(--ink-muted);
	}

	.warning {
		padding: var(--space-2);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-3);
	}

	.actions a {
		display: inline-flex;
		align-items: center;
		min-block-size: var(--touch-target);
		color: var(--ink);
	}

	.message {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: var(--space-2);
	}
</style>
