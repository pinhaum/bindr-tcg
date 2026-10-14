<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { api } from '../../../../lib/api/index';
	import { createLoader } from '../../../../lib/api/loader.svelte';
	import type { DeckPayload } from '../../../../lib/api/types';
	import Button from '../../../../lib/components/Button.svelte';
	import DeckNameForm from '../../../../lib/components/DeckNameForm.svelte';
	import DeckNotFound from '../../../../lib/components/DeckNotFound.svelte';
	import { deckApiPath, deckHref } from '../../../../lib/decks/url';
	import { whenSignedIn } from '../../../../lib/navigation/when-signed-in.svelte';
	import { notifySuccess } from '../../../../lib/toasts.svelte';

	const loader = createLoader((key) => api.get<DeckPayload>(key));

	const id = $derived(Number(page.params.id));
	const error = $derived(loader.state.error);
	const notFound = $derived(error?.code === 'not_found' ? error : null);
	const deck = $derived(loader.state.result?.id === id ? loader.state.result : null);

	whenSignedIn(() => (Number.isNaN(id) ? null : deckApiPath(id)), loader.load);

	function retry(event: SubmitEvent) {
		event.preventDefault();
		loader.retry();
	}

	async function rename(name: string) {
		await api.patch<DeckPayload>(deckApiPath(id), { name });
		await goto(deckHref(id)); // eslint-disable-line svelte/no-navigation-without-resolve
		notifySuccess('Deck renomeado.');
	}
</script>

<svelte:head><title>{notFound ? 'Deck não encontrado — Bindr' : 'Renomear deck — Bindr'}</title></svelte:head>

{#if notFound}
	<DeckNotFound message={notFound.message} />
{:else}
	<h1>Renomear deck</h1>

	{#if error}
		<form onsubmit={retry}>
			<p>{error.message}</p>
			<Button>Tentar novamente</Button>
		</form>
	{:else if deck}
		<DeckNameForm initialName={deck.name} submit={rename}>Renomear deck</DeckNameForm>
	{:else if loader.state.slow}
		<p class="visually-hidden">Carregando deck…</p>
	{/if}
{/if}
