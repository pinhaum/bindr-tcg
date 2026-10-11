<script lang="ts">
	import { goto } from '$app/navigation';
	import { api } from '../../../lib/api/index';
	import type { DeckPayload } from '../../../lib/api/types';
	import DeckNameForm from '../../../lib/components/DeckNameForm.svelte';
	import { deckHref } from '../../../lib/decks/url';
	import { notifySuccess } from '../../../lib/toasts.svelte';

	async function create(name: string) {
		const deck = await api.post<DeckPayload>('/api/decks', { name });
		await goto(deckHref(deck.id)); // eslint-disable-line svelte/no-navigation-without-resolve
		notifySuccess('Deck criado.');
	}
</script>

<svelte:head><title>Novo deck — Bindr</title></svelte:head>

<h1>Novo deck</h1>

<DeckNameForm submit={create}>Criar deck</DeckNameForm>
