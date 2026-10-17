<script lang="ts">
	import { api } from '../../lib/api/index';
	import { createLoader } from '../../lib/api/loader.svelte';
	import type { DeckSummary } from '../../lib/api/types';
	import Button from '../../lib/components/Button.svelte';
	import { statusLabel } from '../../lib/decks/labels';
	import { deckHref } from '../../lib/decks/url';
	import { appPath } from '../../lib/navigation/nav-entries';
	import { whenSignedIn } from '../../lib/navigation/when-signed-in.svelte';

	const KEY = '/api/decks';

	const loader = createLoader((key) => api.get<DeckSummary[]>(key));

	const decks = $derived(loader.state.result);
	const error = $derived(loader.state.error);

	whenSignedIn(() => KEY, loader.load);

	function retry(event: SubmitEvent) {
		event.preventDefault();
		loader.retry();
	}
</script>

<svelte:head><title>Baralhos — Bindr</title></svelte:head>

<h1>Baralhos</h1>

<section aria-busy={loader.state.slow}>
	{#if loader.state.slow}
		<p class="visually-hidden">Carregando baralhos…</p>
	{/if}

	<ul class="actions" aria-label="Ações dos baralhos">
		<li>
			<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por appPath -->
			<a href={appPath('/baralhos/novo')}>Novo deck</a>
		</li>
		<li>
			<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por appPath -->
			<a href={appPath('/baralhos/importar')}>Importar lista</a>
		</li>
	</ul>

	{#if error}
		<form class="message" onsubmit={retry}>
			<p>{error.message}</p>
			<Button>Tentar novamente</Button>
		</form>
	{:else if decks}
		{#if decks.length === 0}
			<p>Você ainda não tem decks.</p>
		{:else}
			<ul class="decks">
				{#each decks as deck (deck.id)}
					<li>
						<h2>
							<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por deckHref -->
							<a href={deckHref(deck.id)}>{deck.name}</a>
						</h2>
						<dl>
							<div>
								<dt>Leader</dt>
								<dd>{deck.leader ? `${deck.leader.name} (${deck.leader.card_number})` : 'Sem Leader'}</dd>
							</div>
							<div>
								<dt>Cartas</dt>
								<dd>{deck.main_total} / 50</dd>
							</div>
							<div>
								<dt>Status</dt>
								<dd>{statusLabel(deck.status)}</dd>
							</div>
						</dl>
					</li>
				{/each}
			</ul>
		{/if}
	{/if}
</section>

<style>
	section {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		margin-block-start: var(--space-3);
	}

	p,
	h2,
	dl,
	dd {
		margin: 0;
	}

	ul {
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-2);
	}

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

	.decks {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
	}

	.decks li {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		padding: var(--space-3);
		border: 1px solid var(--border);
		border-radius: var(--radius-md);
	}

	dl {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-1) var(--space-3);
	}

	dt {
		color: var(--ink-muted);
		font-size: 0.875rem;
	}

	.message {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: var(--space-2);
	}
</style>
