<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { untrack } from 'svelte';
	import { api } from '../../../../lib/api/index';
	import { ApiError } from '../../../../lib/api/errors';
	import { createLoader } from '../../../../lib/api/loader.svelte';
	import type { DeckPayload } from '../../../../lib/api/types';
	import Button from '../../../../lib/components/Button.svelte';
	import DeckNotFound from '../../../../lib/components/DeckNotFound.svelte';
	import { deckApiPath, deckHref } from '../../../../lib/decks/url';
	import { appPath } from '../../../../lib/navigation/nav-entries';
	import { session } from '../../../../lib/session.svelte';
	import { notifyError, notifySuccess } from '../../../../lib/toasts.svelte';

	const loader = createLoader((key) => api.get<DeckPayload>(key));

	const id = $derived(Number(page.params.id));
	const error = $derived(loader.state.error);
	const notFound = $derived(error?.code === 'not_found' ? error : null);
	const deck = $derived(loader.state.result?.id === id ? loader.state.result : null);

	let pending = $state(false);

	$effect(() => {
		if (!session.user || Number.isNaN(id)) return;
		void session.user.email;
		const key = deckApiPath(id);
		untrack(() => loader.load(key));
	});

	function retry(event: SubmitEvent) {
		event.preventDefault();
		loader.retry();
	}

	async function remove(event: SubmitEvent) {
		event.preventDefault();
		if (pending || !deck) return;
		pending = true;
		const { name } = deck;
		try {
			await api.delete(deckApiPath(id));
		} catch (failure) {
			if (!(failure instanceof ApiError)) throw failure;
			notifyError(failure.message);
			return;
		} finally {
			pending = false;
		}
		await goto(appPath('/baralhos')); // eslint-disable-line svelte/no-navigation-without-resolve
		notifySuccess(`Deck “${name}” excluído.`);
	}
</script>

<svelte:head><title>{notFound ? 'Deck não encontrado — Bindr' : 'Excluir deck — Bindr'}</title></svelte:head>

{#if notFound}
	<DeckNotFound message={notFound.message} />
{:else if error}
	<h1>Excluir deck</h1>
	<form onsubmit={retry}>
		<p>{error.message}</p>
		<Button>Tentar novamente</Button>
	</form>
{:else if deck}
	<h1>Excluir o deck “{deck.name}”?</h1>
	<p>O deck e as cartas dele somem. Sua coleção e sua wishlist não mudam.</p>
	<form onsubmit={remove}>
		<Button {pending}>Excluir deck</Button>
		<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href já vem resolvido por deckHref -->
		<a href={deckHref(deck.id)}>Cancelar</a>
	</form>
{:else}
	<h1>Excluir deck</h1>
	{#if loader.state.slow}
		<p class="visually-hidden">Carregando deck…</p>
	{/if}
{/if}
