<script lang="ts">
	import { replaceState } from '$app/navigation';
	import { page } from '$app/state';
	import { untrack } from 'svelte';
	import { api } from '../../../lib/api/index';
	import { createCardDetailLoader } from '../../../lib/cards/card-detail.svelte';
	import { pickFeatured } from '../../../lib/cards/featured';
	import { markCard, signalArrivalWhen } from '../../../lib/cards/morph.svelte';
	import { cardDetailHref } from '../../../lib/cards/url';
	import Button from '../../../lib/components/Button.svelte';
	import CardFields from '../../../lib/components/CardFields.svelte';
	import CardHeader from '../../../lib/components/CardHeader.svelte';
	import VariantRow from '../../../lib/components/VariantRow.svelte';
	import { appPath } from '../../../lib/navigation/nav-entries';
	import { session } from '../../../lib/session.svelte';
	import { shell, wide } from '../../../lib/shell.svelte';

	const loader = createCardDetailLoader(api);

	const result = $derived(loader.state.result);
	const error = $derived(loader.state.error);
	const notFound = $derived(loader.state.notFound);
	const signedIn = $derived(session.user !== null);

	// Variante escolhida pelo clique vale só para a resposta em que foi feita.
	let chosen = $state<{ seq: number; code: string } | null>(null);
	const wanted = $derived(
		chosen && chosen.seq === loader.state.seq ? chosen.code : page.url.searchParams.get('variant')
	);
	const featured = $derived(result ? pickFeatured(result.variants, wanted) : null);

	let displayedByVariant = $state<Record<string, number>>({});
	const owned = $derived(
		featured ? (displayedByVariant[featured.variant_code] ?? featured.owned_quantity ?? 0) : 0
	);

	// Troca de carta, de sessão e resposta nova recriam as linhas, e com elas as filas de posse.
	const detailKey = $derived(
		`${page.params.card_number}|${session.user?.email ?? ''}|${loader.state.seq}`
	);

	const title = $derived(
		notFound !== null
			? 'Carta não encontrada — Bindr'
			: !error && result
				? `${result.name} (${result.card_number}) — Bindr`
				: 'Carta — Bindr'
	);

	$effect(() => {
		void session.user?.email;
		const cardNumber = page.params.card_number;
		if (!cardNumber) return;
		untrack(() => loader.load(cardNumber, page.url.searchParams.get('variant') ?? undefined));
	});

	$effect(() => {
		if (result) markCard(result.card_number);
	});

	// A View Transition só captura o estado novo com a arte do cabeçalho no DOM.
	signalArrivalWhen(() => !!result && !error && notFound === null && !loader.state.skeleton);

	$effect.pre(() => {
		void detailKey;
		displayedByVariant = {};
	});

	$effect(() => {
		if (!wide.current) return;
		shell.aside = back;
		return () => {
			shell.aside = null;
		};
	});

	function select(variantCode: string) {
		if (!result) return;
		chosen = { seq: loader.state.seq, code: variantCode };
		// eslint-disable-next-line svelte/no-navigation-without-resolve -- cardDetailHref parte de appPath
		replaceState(cardDetailHref(result.card_number, variantCode), {});
	}

	function retry(event: SubmitEvent) {
		event.preventDefault();
		loader.retry();
	}
</script>

<svelte:head><title>{title}</title></svelte:head>

{#snippet back()}
	<!-- eslint-disable-next-line svelte/no-navigation-without-resolve -- appPath parte de resolve('/') -->
	<a class="back" href={appPath('')}>Voltar ao catálogo</a>
{/snippet}

{#if !wide.current}
	{@render back()}
{/if}

<section class="detail" aria-busy={loader.state.skeleton}>
	{#if loader.state.skeleton}
		<p class="visually-hidden">Carregando carta…</p>
		<div class="skeleton" aria-hidden="true"></div>
	{:else if notFound !== null}
		<h1>{notFound}</h1>
	{:else if error}
		<form class="message" onsubmit={retry}>
			<p role="alert">{error.message}</p>
			<Button>Tentar novamente</Button>
		</form>
	{:else if result}
		{#key detailKey}
			<CardHeader card={result} {featured} {owned} {signedIn} />
			<CardFields card={result} />
			{#if result.variants.length > 0}
				<section class="variants">
					<h2>Variantes na pasta</h2>
					<ul>
						{#each result.variants as variant (variant.variant_code)}
							<VariantRow
								card={result}
								{variant}
								featured={variant.variant_code === featured?.variant_code}
								{signedIn}
								onSelect={select}
								bind:displayed={displayedByVariant[variant.variant_code]}
							/>
						{/each}
					</ul>
				</section>
			{/if}
		{/key}
	{/if}
</section>

<style>
	.back {
		display: inline-flex;
		align-items: center;
		box-sizing: border-box;
		min-block-size: var(--touch-target);
		padding-inline: var(--space-3);
		border: 1px solid var(--border-strong);
		border-radius: var(--radius-sm);
		color: var(--ink);
		font-weight: 600;
		text-decoration: none;
	}

	.detail {
		display: flex;
		flex-direction: column;
		gap: var(--space-4);
		margin-block-start: var(--space-3);
	}

	h1 {
		margin: 0;
	}

	.message {
		display: flex;
		flex-direction: column;
		align-items: flex-start;
		gap: var(--space-2);
	}

	.message p {
		margin: 0;
	}

	.skeleton {
		block-size: 12rem;
		border-radius: var(--radius-md);
		background: var(--surface-sunken);
	}

	.variants h2 {
		margin: 0 0 var(--space-2);
	}

	.variants ul {
		margin: 0;
		padding: 0;
	}
</style>
