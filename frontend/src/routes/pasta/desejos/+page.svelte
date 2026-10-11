<script lang="ts">
	import { tick, untrack } from 'svelte';
	import { SvelteSet } from 'svelte/reactivity';
	import { ApiError } from '../../../lib/api/errors';
	import { api } from '../../../lib/api/index';
	import { createLoader } from '../../../lib/api/loader.svelte';
	import type { WishlistEntry } from '../../../lib/api/types';
	import Button from '../../../lib/components/Button.svelte';
	import WishlistItem from '../../../lib/components/WishlistItem.svelte';
	import { variantApiPath } from '../../../lib/cards/url';
	import { appPath } from '../../../lib/navigation/nav-entries';
	import { session } from '../../../lib/session.svelte';
	import { notifyError, notifySuccess } from '../../../lib/toasts.svelte';

	const loader = createLoader(() => api.get<{ data: WishlistEntry[] }>('/api/wishlist'));

	const key = (entry: WishlistEntry) => `${entry.card_number}|${entry.variant_code}`;

	let items: WishlistEntry[] = $state([]);
	let heading: HTMLHeadingElement | undefined = $state();
	const removing = new SvelteSet<string>();
	const refs: Record<string, { focus(): void } | null> = $state({});

	const loaded = $derived(loader.state.result !== null);
	const error = $derived(loader.state.error);

	$effect(() => {
		if (!session.user) return;
		void session.user.email;
		untrack(() => loader.load('/api/wishlist'));
	});

	$effect(() => {
		void loader.state.seq;
		const result = untrack(() => loader.state.result);
		if (result) items = result.data;
	});

	function retry(event: SubmitEvent) {
		event.preventDefault();
		loader.retry();
	}

	let alive = true;
	$effect(() => () => {
		alive = false;
	});

	const focusLost = () => !document.activeElement || document.activeElement === document.body;

	async function remove(entry: WishlistEntry) {
		const id = key(entry);
		if (removing.has(id)) return;
		removing.add(id);
		try {
			await api.delete(variantApiPath(entry.card_number, entry.variant_code, 'wishlist'));
			const index = items.findIndex((item) => key(item) === id);
			const neighbour = index < 0 ? undefined : (items[index + 1] ?? items[index - 1]);
			items = items.filter((item) => key(item) !== id);
			await tick();
			if (!alive) return;
			if (index >= 0 && focusLost()) {
				if (neighbour) refs[key(neighbour)]?.focus();
				else heading?.focus();
			}
			notifySuccess('Item removido da lista de desejos.');
		} catch (cause) {
			if (!(cause instanceof ApiError)) throw cause;
			removing.delete(id);
			await tick();
			if (alive && focusLost()) refs[id]?.focus();
			if (cause.status !== 401 && cause.code !== 'session_changed') notifyError(cause.message);
		} finally {
			removing.delete(id);
		}
	}
</script>

<svelte:head><title>Lista de desejos — Bindr</title></svelte:head>

<h1 tabindex="-1" bind:this={heading}>Lista de desejos</h1>

<section aria-busy={loader.state.slow}>
	{#if loader.state.slow}
		<p class="visually-hidden">Carregando lista de desejos…</p>
	{/if}
	{#if error}
		<form class="message" onsubmit={retry}>
			<p>{error.message}</p>
			<Button>Tentar novamente</Button>
		</form>
	{:else if loaded}
		{#if items.length === 0}
			<p>Você ainda não marcou nenhuma carta como desejada.</p>
			<p>
				Abra o detalhe de uma carta no <!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- href parte de appPath --><a
					href={appPath('')}>catálogo</a
				> e escolha a impressão que quer adquirir.
			</p>
		{:else}
			<p>{items.length === 1 ? '1 item' : `${items.length} itens`}</p>
			<ul>
				{#each items as entry (key(entry))}
					<li>
						<WishlistItem
							bind:this={refs[key(entry)]}
							cardNumber={entry.card_number}
							cardName={entry.card_name}
							variantCode={entry.variant_code}
							targetQuantity={entry.target_quantity}
							ownedQuantity={entry.owned_quantity}
							pending={removing.has(key(entry))}
							onremove={() => remove(entry)}
						/>
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

	p {
		margin: 0;
	}

	ul {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.message {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: var(--space-2);
	}
</style>
