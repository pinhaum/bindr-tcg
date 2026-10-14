<script lang="ts">
	import { goto } from '$app/navigation';
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
	import EditingDeckPanel from '../../../lib/components/EditingDeckPanel.svelte';
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
	let chosen = $state<{ seq: number; card: string; code: string } | null>(null);
	const wanted = $derived(
		chosen && chosen.seq === loader.state.seq && chosen.card === page.params.card_number
			? chosen.code
			: page.url.searchParams.get('variant')
	);

	// Sessão cuja consulta gerou o `result` atual; até a resposta da sessão atual chegar, a posse é de outra.
	let requested = $state<{ email: string; seq: number } | null>(null);
	let lastAnswered = $state<string | null>(null);
	const answeredEmail = $derived(
		requested && loader.state.seq > requested.seq ? requested.email : lastAnswered
	);
	const staleOwnership = $derived(
		session.user !== null && answeredEmail !== null && answeredEmail !== session.user.email
	);
	const featured = $derived(result ? pickFeatured(result.variants, wanted) : null);

	// Troca de carta, de sessão ou resposta nova recomeça os valores exibidos pelos steppers.
	const displayedByVariant = $derived.by(() => {
		void detailKey;
		const fresh = $state<Record<string, number>>({});
		return fresh;
	});
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

	// Valor primitivo: o `goto` da troca de variante renova `page.params` sem mudar a carta.
	const cardNumber = $derived(page.params.card_number);

	$effect(() => {
		void session.user?.email;
		const email = session.user?.email ?? '';
		if (!cardNumber) return;
		untrack(() => {
			lastAnswered = answeredEmail;
			requested = { email, seq: loader.state.seq };
			loader.load(cardNumber, wanted ?? undefined);
		});
	});

	$effect(() => {
		if (result) markCard(result.card_number);
	});

	// A View Transition só captura o estado novo com a arte do cabeçalho no DOM.
	signalArrivalWhen(() => !!result && !error && notFound === null && !loader.state.skeleton);

	$effect(() => {
		if (!wide.current) return;
		shell.aside = back;
		return () => {
			shell.aside = null;
		};
	});

	function select(variantCode: string) {
		if (!result) return;
		chosen = { seq: loader.state.seq, card: result.card_number, code: variantCode };
		// Navegação de verdade na mesma rota: `replaceState` é rasa e deixa `page.url` com a variante antiga.
		// eslint-disable-next-line svelte/no-navigation-without-resolve -- cardDetailHref parte de appPath
		void goto(cardDetailHref(result.card_number, variantCode), { replace: true, reset: false });
	}

	function retry(event: SubmitEvent) {
		event.preventDefault();
		const cardNumber = page.params.card_number;
		if (cardNumber) loader.load(cardNumber, wanted ?? undefined);
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

<section class="detail" aria-busy={loader.state.skeleton || (!!result && staleOwnership)}>
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
	{:else if result && staleOwnership}
		<p class="visually-hidden">Carregando carta…</p>
		<div class="skeleton" aria-hidden="true"></div>
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
			{#if signedIn && result.editing_deck}
				<EditingDeckPanel
					deck={result.editing_deck}
					cardNumber={result.card_number}
					name={result.name}
					cardType={result.card_type}
				/>
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
